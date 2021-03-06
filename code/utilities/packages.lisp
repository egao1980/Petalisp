;;;; © 2016-2020 Marco Heisig         - license: GNU AGPLv3 -*- coding: utf-8 -*-

(cl:in-package #:common-lisp-user)

(defpackage #:petalisp.utilities
  (:use #:common-lisp)
  (:export

   ;; documentation.lisp
   #:document-compiler-macro
   #:document-compiler-macros
   #:document-function
   #:document-functions
   #:document-method-combination
   #:document-method-combinations
   #:document-setf-expander
   #:document-setf-expanders
   #:document-structure
   #:document-structures
   #:document-variable
   #:document-variables

   ;; extended-euclid.lisp
   #:extended-euclid

   ;; identical.lisp
   #:float-bits

   ;; identical.lisp
   #:identical

   ;; memoization.lisp
   #:with-memoization
   #:with-multiple-value-memoization
   #:with-hash-table-memoization
   #:with-multiple-value-hash-table-memoization
   #:with-vector-memoization
   #:with-multiple-value-vector-memoization

   ;; prime-factors.lisp
   #:prime-factors
   #:primep

   ;; with-collectors.lisp
   #:with-collectors))
