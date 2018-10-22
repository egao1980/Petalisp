;;;; © 2016-2018 Marco Heisig - licensed under AGPLv3, see the file COPYING     -*- coding: utf-8 -*-

(in-package :petalisp-native-backend)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; From Translation Units to Code

(defun lambda-expression-from-translation-unit (translation-unit)
  `(lambda (ranges storages)
     (declare (simple-vector ranges storages))
     ;; Generate range bindings.
     (let ,(loop for basic-block = (initial-basic-block translation-unit)
                   then (successor basic-block)
                 until (not basic-block)
                 for index from 0 by 1
                 for offset from 0 by 3
                 collect `(,(start-variable index) (aref ranges ,(+ offset 0)))
                 collect `(,(step-variable index) (aref ranges ,(+ offset 1)))
                 collect `(,(end-variable index) (aref ranges ,(+ offset 2))))
       ;; Generate storage bindings
       (let ,(loop for index from 0
                   for storage-type in (storage-types translation-unit)
                   collect `(,(storage-variable index)
                             (the ,storage-type (aref storages ,index))))
         ,(translate-basic-block translation-unit)))))

(defun translate-instruction (instruction)
  ;; TODO
  (values))

(defgeneric translate-basic-block (basic-block))

(defmethod translate-basic-block ((basic-block basic-block))
  (mapc #'translate-instruction (instructions basic-block)))

(defmethod translate-basic-block ((loop-block loop-block))
  (mapc #'translate-instruction (instructions loop-block))
  (let* ((depth (depth loop-block))
         (start (start-variable depth))
         (step (step-variable depth))
         (end (end-variable depth))
         (i (index-variable depth))
         (type (if (fixnum-p loop-block) 'fixnum 'integer)))
    ))

(defmethod translate-basic-block ((reduction reduction))
  (mapc #'translate-instruction (instructions reduction))
  ;; TODO
  (values))
