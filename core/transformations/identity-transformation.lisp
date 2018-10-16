;;;; © 2016-2018 Marco Heisig - licensed under AGPLv3, see the file COPYING     -*- coding: utf-8 -*-

(in-package :petalisp)

(defclass identity-transformation (invertible-transformation)
  ((%dimension :initarg :dimension
               :reader input-dimension
               :reader output-dimension
               :type (integer 0 *))))

(define-class-predicate identity-transformation :hyphenate t)

(defmethod transform ((sequence sequence) (operator identity-transformation))
  sequence)

(defmethod transformation-equal
    ((transformation-1 identity-transformation)
     (transformation-2 identity-transformation))
  (= (input-dimension transformation-1)
     (input-dimension transformation-2)))

(defmethod compose-transformations
    ((g identity-transformation) (f transformation))
  f)

(defmethod compose-transformations
    ((g transformation) (f identity-transformation))
  g)

(defmethod invert-transformation
    ((transformation identity-transformation))
  transformation)

(defmethod enlarge-transformation
    ((transformation identity-transformation) scale offset)
  (assert (zerop offset))
  (assert (= 1 scale))
  (identity-transformation (1+ (input-dimension transformation))))

(defmethod map-transformation-outputs
    ((transformation identity-transformation) (function function) &key from-end)
  (if (not from-end)
      (loop for index below (input-dimension transformation) do
        (funcall function index index 1 0))
      (loop for index downfrom (1- (input-dimension transformation)) to 0 do
        (funcall function index index 1 0))))
