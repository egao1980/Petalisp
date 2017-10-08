;;; © 2016-2017 Marco Heisig - licensed under AGPLv3, see the file COPYING

;;; Marco Heisig's Memoization Macros
;;;
;;; There are numerous libraries for memoization, but most of them succumb
;;; to the temptation to provide a wrapper for DEFUN as primary API. This
;;; has a number of drawbacks:
;;;
;;; - memoization of subexpressions requires toplevel helper functions
;;; - in particular combining memoization and generic functions is inconvenient
;;; - the memoization key cannot be specified directly
;;; - combining memoization with other DEFUN wrappers is difficult
;;;
;;; To address these problems, this library uses lexical memoization, i.e.
;;; WITH-something macros that memoize the result of evaluating their
;;; body. Furthermore, there are different macros for more or less
;;; fine-grained control over the memoization strategy.

(defvar *memoization-tables* (make-hash-table :test #'eq :weakness :key)
  "A mapping from packages to sets of of all implicitly created memoization
tables in that package.")

(defun package-memoization-tables (&optional (package *package*))
  "Return the set of memoization tables used by PACKAGE. The set is
represented as a NIL valued hash table whose (weak) keys are individual
memoization tables. This permits the garbage collector to reclaim unused
memoization tables, e.g. after the redefinition of a function."
  (or (gethash package *memoization-tables*)
      (setf (gethash package *memoization-tables*)
            (make-hash-table :test #'eq :weakness :key))))

(defun clear-memoization-tables (&optional (package *package*))
  "Clear all memoization tables in PACKAGE."
  (loop for memoization-table being each hash-key of (package-memoization-tables package)
        when (hash-table-p memoization-table)
          do (clrhash memoization-table)))

(defmacro with-memoization
    ((key test &optional (store-key nil store-key-p)) &body body)
  "Memoize the values of BODY. If KEY has the same value (with respect to
  TEST) as some previously computed key, then BODY is not evaluated and the
  values of the previous computation are returned.

  If the optional form STORE-KEY is supplied, it is evaluated after any
  evaluation of BODY and its value is used instead of KEY for storing the
  results. This way, KEY can be an object with dynamic extent (to avoid
  consing) and STORE-KEY can create a copy with indefinite extent when
  necessary."
  (assert (member test '(#'eq #'eql #'equal #'equalp eq eql equal equalp)
                  :test #'equal)
          (test)
          "TEST must be a function designator for one of the functions EQ, ~@
        EQL, EQUAL, or EQUALP.")
  (once-only (key)
    (with-gensyms (hash-table)
      `(with-hash-table-memoization (,key ,@(when store-key-p (list store-key)))
           (load-time-value
            (let ((,hash-table (make-hash-table :test ,test)))
              (setf (gethash ,hash-table (package-memoization-tables)) nil)
              ,hash-table))
         ,@body))))

(defmacro with-hash-table-memoization
    ((key &optional (store-key nil store-key-p)) hash-table &body body)
  "Memoize the values of BODY. If KEY is found in HASH-TABLE, BODY is not
  evaluated and the corresponding values are returned. Otherwise, BODY is
  evaluated and its values are first stored as the HASH-TABLE entry of KEY
  and then returned.

  If the optional form STORE-KEY is supplied, it is evaluated after any
  evaluation of BODY and its value is used instead of KEY for storing the
  results. This way, KEY can be an object with dynamic extent (to avoid
  consing) and STORE-KEY can create a copy with indefinite extent when
  necessary."
  (once-only (key hash-table)
    (with-gensyms (values-list)
      `(with-generic-memoization
           ((lambda ()
              (gethash ,key ,hash-table))
            (lambda (,values-list)
              (setf (gethash ,(if store-key-p store-key key) ,hash-table)
                    ,values-list)))
         ,@body))))

(defmacro with-generic-memoization
    ((lookup store) &body body)
  "Memoize the values of BODY.

  LOOKUP must be a function of zero arguments, returning two values:
  1. the potential values of the lookup
  2. a boolean whether values have been found

  STORE must be a function of one argument and with unspecified return
  value.

  This macro uses LOOKUP to determine whether memoized values exist. If so,
  these values are returned. Otherwise, BODY is evaluated and its values
  are first passed to STORE in some unspecified format and then returned."
  (once-only (lookup store)
    (with-gensyms (values-list present-p)
      `(multiple-value-bind (,values-list ,present-p) (funcall ,lookup)
         (if ,present-p
             (values-list ,values-list)
             (let ((,values-list (multiple-value-list (progn ,@body))))
               (funcall ,store ,values-list)
               (values-list ,values-list)))))))
