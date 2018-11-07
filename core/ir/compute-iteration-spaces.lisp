;;;; © 2016-2018 Marco Heisig - licensed under AGPLv3, see the file COPYING     -*- coding: utf-8 -*-

(in-package :petalisp-ir)

(defvar *kernel-iteration-spaces*)

(defun compute-iteration-spaces (root)
  (let ((*kernel-iteration-spaces* '()))
    (compute-iteration-spaces-aux
     root
     root
     (array-shape root)
     (identity-transformation (rank root)))
    ;; The list of iteration spaces generated by COMPUTE-ITERATION-SPACES
    ;; may be empty if there are zero fusion nodes in the subtree.  In this
    ;; case, we return the shape of the root instead.
    (or *kernel-iteration-spaces*
        (list (array-shape root)))))

;;; Return a boolean indicating whether any of the inputs of NODE, or any
;;; of the inputs thereof, is a fusion node.  Furthermore, whenever NODE is
;;; a fusion node, push a new iteration space for each input that contains
;;; no further fusion nodes.
(defgeneric compute-iteration-spaces-aux
    (root node iteration-space transformation))

(defmethod compute-iteration-spaces-aux :around
    ((root strided-array)
     (node strided-array)
     (iteration-space shape)
     (transformation transformation))
  (if (eq root node)
      (call-next-method)
      (if (nth-value 1 (gethash node *buffer-table*))
          nil
          (call-next-method))))

(defmethod compute-iteration-spaces-aux
    ((root strided-array)
     (fusion fusion)
     (iteration-space shape)
     (transformation transformation))
  ;; Check whether any inputs are free of fusion nodes.  If so, push an
  ;; iteration space.
  (loop for input in (inputs fusion) do
    (let ((subspace (set-intersection iteration-space (array-shape input))))
      ;; If the input is unreachable, we do nothing.
      (unless (set-emptyp subspace)
        ;; If the input contains fusion nodes, we also do nothing.
        (unless (compute-iteration-spaces-aux root input subspace transformation)
          ;; We have an outer fusion.  This means we have to add a new
          ;; iteration space, which we obtain by projecting the current
          ;; iteration space to the coordinate system of the root.
          (push (transform subspace (invert-transformation transformation))
                *kernel-iteration-spaces*)))))
  t)

(defmethod compute-iteration-spaces-aux
    ((root strided-array)
     (reference reference)
     (iteration-space shape)
     (transformation transformation))
  (compute-iteration-spaces-aux
   root
   (input reference)
   (transform
    (set-intersection iteration-space (array-shape reference))
    (transformation reference))
   (compose-transformations (transformation reference) transformation)))

(defmethod compute-iteration-spaces-aux
    ((root strided-array)
     (reduction reduction)
     (iteration-space shape)
     (transformation transformation))
  (let* ((range (reduction-range reduction))
         (size (set-size range))
         (iteration-space
           (enlarge-shape
            iteration-space
            (make-range 0 1 (1- size))))
         (transformation
           (enlarge-transformation
            transformation
            (range-step range)
            (range-start range))))
    (loop for input in (inputs reduction)
            thereis
            (compute-iteration-spaces-aux root input iteration-space transformation))))

(defmethod compute-iteration-spaces-aux
    ((root strided-array)
     (application application)
     (iteration-space shape)
     (transformation transformation))
  (loop for input in (inputs application)
          thereis
          (compute-iteration-spaces-aux root input iteration-space transformation)))

(defmethod compute-iteration-spaces-aux
    ((root strided-array)
     (immediate immediate)
     (iteration-space shape)
     (transformation transformation))
  nil)
