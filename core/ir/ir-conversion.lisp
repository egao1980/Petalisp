;;;; © 2016-2018 Marco Heisig - licensed under AGPLv3, see the file COPYING     -*- coding: utf-8 -*-

(in-package :petalisp-ir)

;;; The purpose of IR conversion is to turn a data flow graph, whose nodes
;;; are strided arrays, into an analogous graph, whose nodes are buffers
;;; and kernels.  Kernels and buffers alternate, such that the inputs and
;;; outputs of a kernel are always buffers, and such that the inputs and
;;; outputs of a buffer are always kernels.
;;;
;;; The IR conversion algorithm proceeds along the following steps:
;;;
;;; 1. A hash table is created that maps certain strided arrays to buffers
;;;    of the same size and element type.  This table is constructed such
;;;    that any subgraph without these nodes is a tree and contains no
;;;    reduction nodes.
;;;
;;; 2. Each root of a subtree from step 1 is turned into one or more
;;;    kernels.  All fusion nodes in the tree are eliminated by choosing
;;;    the iteration space of the kernels appropriately.
;;;
;;; 3. All buffers are updated to contain a list of kernels that read to
;;;    them or write from them.

(defun ir-from-strided-arrays (strided-arrays backend)
  (let ((*buffer-table* (compute-buffer-table strided-arrays backend)))
    ;; Now create a list of kernels for each entry in the buffer table.
    (loop for root being each hash-key of *buffer-table* do
      (let ((kernels (compute-kernels root backend)))
        ;; Update the inputs and outputs of all buffers to match the inputs
        ;; and outputs of the corresponding kernels.
        (loop for kernel in kernels do
          (loop for load in (loads kernel) do
            (pushnew kernel (outputs (buffer load))))
          (loop for store in (stores kernel) do
            (pushnew kernel (inputs (buffer store))))
          (loop for reduction-store in (reduction-stores kernel) do
            (pushnew kernel (inputs (buffer reduction-store)))))))
    ;; Finally, return the buffers corresponding to the root nodes.
    (loop for strided-array in strided-arrays
          collect (gethash strided-array *buffer-table*))))

(defvar *kernel-root*)

(defvar *instruction-counter*)

(defun next-instruction-number ()
  (incf *instruction-counter*))

(defmethod compute-kernels :around ((root strided-array) (backend backend))
  (let ((*kernel-root* root))
    (call-next-method)))

(defgeneric compute-kernels (root backend))

;;; An immediate node has no kernels.
(defmethod compute-kernels ((root immediate) (backend backend))
  '())

;;; The goal is to convert a given subtree of a data flow graph to a list
;;; of kernels.  The subtree is delimited by nodes that have a
;;; corresponding entry in the buffer table.  By choosing the iteration
;;; space of our kernels appropriately, we can eliminate all fusion nodes
;;; in the subtree.
;;;
;;; The algorithm consists of two phases.  In the first phase, we compute a
;;; partitioning of the shape of the root into multiple iteration spaces.
;;; These spaces are chosen such that their union is the shape of the root,
;;; but such that each iteration space selects only a single input of each
;;; encountered fusion node.  In the second phase, each iteration space is
;;; used to create one kernel and its body.  The body of a kernel is an
;;; s-expression describing the interplay of applications, reductions and
;;; references.
(defmethod compute-kernels ((root strided-array) (backend backend))
  (let ((transformation (identity-transformation (dimension root))))
    (loop for iteration-space in (compute-iteration-spaces root)
          collect
          (let ((*instruction-counter* -1))
            (multiple-value-bind (value loads)
                (compute-kernel-body root iteration-space transformation)
              (make-kernel
               backend
               :iteration-space iteration-space
               :loads loads
               :reduction-stores '()
               :stores (list (make-instance 'store-instruction
                               :number (next-instruction-number)
                               :value value
                               :buffer (gethash root *buffer-table*)
                               :transformation transformation))))))))

;;; Reductions are exceptional in that iteration space has a higher
;;; dimension than the shape of the root node.
(defmethod compute-kernels ((root reduction) (backend backend))
  (let* ((reduction-range (reduction-range root))
         (outer-transformation (identity-transformation (dimension root)))
         (inner-transformation (enlarge-transformation
                                outer-transformation
                                (range-step reduction-range)
                                (range-start reduction-range)))
         (reduction-range (make-range 0 1 (1- (set-size reduction-range)))))
    (loop for iteration-space in (compute-iteration-spaces root)
          collect
          (let ((*instruction-counter* -1)
                (iteration-space (enlarge-shape iteration-space reduction-range)))
            (multiple-value-bind (value loads)
                (compute-kernel-body root iteration-space inner-transformation)
              (make-kernel
               backend
               :iteration-space iteration-space
               :loads loads
               :stores '()
               :reduction-stores
               (list
                (make-instance 'reduction-store-instruction
                  :number (next-instruction-number)
                  :value value
                  :buffer (gethash root *buffer-table*)
                  :transformation outer-transformation))))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Computing the Kernel Body

(defvar *loads*)

(defun compute-kernel-body (root iteration-space transformation)
  (let ((*loads* '()))
    (values
     (compute-value root iteration-space transformation)
     *loads*)))

;;; Return the 'value' of ROOT for a given point in the iteration space of
;;; the kernel, i.e., return a cons cell whose cdr is an instruction and
;;; whose car is an integer denoting which of the N values of the
;;; instructions is referenced.
(defgeneric compute-value (node iteration-space transformation))

;; Check whether we are dealing with a leaf, i.e., a node that has a
;; corresponding entry in the buffer table and is not the root node.  If
;; so, return a reference to that buffer.
(defmethod compute-value :around
    ((node strided-array)
     (iteration-space shape)
     (transformation transformation))
  ;; The root node has an entry in the buffer table, yet we do not want to
  ;; treat it as a leaf node.
  (if (eq node *kernel-root*)
      (call-next-method)
      (multiple-value-bind (buffer buffer-p)
          (gethash node *buffer-table*)
        (if (not buffer-p)
            (call-next-method)
            (let ((load (make-instance 'load-instruction
                          :number (next-instruction-number)
                          :transformation transformation
                          :buffer buffer)))
              (push load *loads*)
              (cons 0 load))))))

(defmethod compute-value
    ((application application)
     (iteration-space shape)
     (transformation transformation))
  (cons (value-n application)
        (make-instance 'call-instruction
          :operator (operator application)
          :arguments
          (loop for input in (inputs application)
                collect
                (compute-value input iteration-space transformation))
          :number (next-instruction-number))))

(defmethod compute-value
    ((reduction reduction)
     (iteration-space shape)
     (transformation transformation))
  (cons (value-n reduction)
        (make-instance 'reduce-instruction
          :operator (operator reduction)
          :arguments
          (loop for input in (inputs reduction)
                collect
                (compute-value input iteration-space transformation))
          :number (next-instruction-number))))

(defmethod compute-value
    ((reference reference)
     (iteration-space shape)
     (transformation transformation))
  (compute-value
   (input reference)
   (transform
    (set-intersection iteration-space (shape reference))
    (transformation reference))
   (compose-transformations (transformation reference) transformation)))

(defmethod compute-value
    ((fusion fusion)
     (iteration-space shape)
     (transformation transformation))
  (let ((input (find iteration-space (inputs fusion)
                     :key #'shape
                     :test #'set-intersectionp)))
    (compute-value
     input
     (set-intersection iteration-space (shape input))
     transformation)))

(defmethod compute-value
    ((strided-array strided-array)
     (iteration-space shape)
     (transformation transformation))
  (error "Can't compute the value of ~S" strided-array))