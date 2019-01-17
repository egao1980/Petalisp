;;;; © 2016-2019 Marco Heisig         - license: GNU AGPLv3 -*- coding: utf-8 -*-

(in-package :petalisp-api)

(defun free-variables (form &optional environment)
  (let (result)
    (agnostic-lizard:walk-form
     form environment
     :on-every-atom
     (lambda (form env)
       (prog1 form
         (when (and (symbolp form)
                    (not (find form (agnostic-lizard:metaenv-variable-like-entries env)
                               :key #'first)))
           (pushnew form result)))))
    result))

(defmacro τ (input-forms output-forms)
  (flet ((constraint (input-form)
           (etypecase input-form
             (integer input-form)
             (symbol nil)))
         (variable (input-form)
           (etypecase input-form
             (integer (gensym))
             (symbol input-form))))
    (let* ((input-mask
             (map 'vector #'constraint input-forms))
           (variables
             (map 'list #'variable input-forms)))
      `(make-transformation-from-function
        (lambda ,variables
          (declare (ignorable ,@variables))
          (values ,@output-forms))
        ,input-mask))))

(defun make-transformation-from-function
    (function &optional (input-mask nil input-mask-p))
  (let* ((input-rank
           (if input-mask-p
               (length input-mask)
               (petalisp-core::function-arity function)))
         (input-mask
           (if (not input-mask-p)
               (make-array input-rank :initial-element nil)
               (coerce input-mask 'simple-vector))))
    (assert (= input-rank (length input-mask)) ()
      "~@<Received the input constraints ~W of length ~D ~
          for a function with ~D arguments.~:@>"
      input-mask (length input-mask) input-rank)
    (let ((args (map 'list (lambda (constraint) (or constraint 0)) input-mask))
          ;; F is applied to many slightly different arguments, so we build a
          ;; vector pointing to the individual conses of ARGS for fast random
          ;; access.
          (arg-conses (make-array input-rank)))
      (loop for arg-cons on args
            for index from 0 do
              (setf (aref arg-conses index) arg-cons))
      ;; Initially x is the zero vector (except for input constraints, which
      ;; are ignored by A), so f(x) = Ax + b = b
      (let* ((offsets (multiple-value-call #'vector (apply function args)))
             (output-rank (length offsets))
             (output-mask (make-array output-rank :initial-element nil))
             (scalings (make-array output-rank :initial-element 0)))
        ;; Set one input at a time from zero to one (ignoring those with
        ;; constraints) and check how it changes the output.
        (loop for input-constraint across input-mask
              for arg-cons across arg-conses
              for column-index from 0
              when (not input-constraint) do
                (setf (car arg-cons) 1)
                ;; Find the row of A corresponding to the mutated input.
                ;; It is the only output that differs from b.
                (let ((outputs (multiple-value-call #'vector (apply function args))))
                  (loop for output across outputs
                        for offset across offsets
                        for row-index from 0
                        when (/= output offset) do
                          (setf (aref output-mask row-index) column-index)
                          (setf (aref scalings row-index) (- output offset))
                          (return)))
                ;; Restore the argument to zero.
                (setf (car arg-cons) 0))
        ;; Finally, check whether the derived transformation behaves like
        ;; the original function and signal an error if not.
        (let ((transformation
                (make-transformation
                 :input-rank input-rank
                 :output-rank output-rank
                 :input-mask input-mask
                 :offsets offsets
                 :scalings scalings
                 :output-mask output-mask)))
          (loop for arg-cons on args
                for input-constraint across input-mask
                when (not input-constraint) do
                  (setf (car arg-cons) 2))
          (assert (equalp (transform args transformation)
                          (multiple-value-list (apply function args)))
                  ()
                  "~@<The function ~W is not affine-linear.~:@>"
                  function)
          transformation)))))

(define-compiler-macro make-transformation-from-function
    (&whole whole &environment environment
            function &optional (input-mask nil input-mask-p))
  (if (or (not (constantp input-mask environment))
          (free-variables function))
      whole
      `(load-time-value
        (locally ;; avoid infinite compiler macro recursion
            (declare (notinline make-transformation-from-function))
          (make-transformation-from-function
           ,function
           ,@(when input-mask-p `(,input-mask))))))
  whole)
