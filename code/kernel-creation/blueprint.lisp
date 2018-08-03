;;;; © 2016-2018 Marco Heisig - licensed under AGPLv3, see the file COPYING     -*- coding: utf-8 -*-

(in-package :petalisp)

;;; The blueprint grammar:
;;;
;;; BLUEPRINT          := [:blueprint BOUNDS-INFORMATION ARRAY-INFORMATION BODY]
;;; BOUNDS-INFORMATION := array-index | [array-index array-index]
;;; ARRAY-INFORMATION  := atomic-type-specifier
;;; BODY               := [:store REFERENCE EXPRESSION]
;;; REFERENCE          := [:reference array-id INDEX-COMPUTATION]
;;; INDEX-COMPUTATION  := [scale offset index]
;;; EXPRESSION         := REFERENCE | CALL | REDUCTION
;;; CALL               := [function-symbol EXPRESSION*] | [:call function-id EXPRESSION*]
;;; REDUCTION          := [:reduce function function EXPRESSION]

(defun blueprint/reference (id transformation)
  (let (ulists)
    (dx-flet ((store-triple (output-index input-index scale offset)
                (declare (ignore output-index))
                (check-type input-index integer)
                (check-type scale integer)
                (check-type offset integer)
                (push (ucons:ulist input-index scale offset) ulists)))
      (map-transformation-outputs transformation #'store-triple))
    (ucons:ulist* :reference id
            (reduce (lambda (a b) (ucons:ucons b a))
                    ulists :initial-value nil))))

(defun blueprint/call (symbol-or-id input-blueprints)
  (ucons:ulist* :call symbol-or-id input-blueprints))

(defun blueprint/reduce (binary-operator unary-operator input)
  (ucons:ulist :reduce binary-operator unary-operator input))

(defun blueprint/store (place expression)
  (ucons:ulist :store place expression))

(defun blueprint/with-metadata (dimensions references body)
  (flet ((dimension-metadata (dimension)
           (if (<= dimension 8)
               dimension
               (let ((lb (floor (log dimension 2))))
                 (ucons:ulist (expt 2 lb) (expt (1+ lb) 2)))))
         (reference-metadata (reference)
           (atomic-type (element-type reference))))
    (ucons:ulist :blueprint
                 (ucons:map-ulist #'dimension-metadata dimensions)
                 (ucons:map-ulist #'reference-metadata references)
                 body)))


