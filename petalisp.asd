(defsystem :petalisp
  :description "Elegant High Performance Computing"
  :author "Marco Heisig <marco.heisig@fau.de>"
  :license "AGPLv3"

  :depends-on
  (:agnostic-lizard
   :alexandria
   :bordeaux-threads
   :closer-mop
   :fiveam
   :iterate
   :optima
   :trivial-garbage
   :uiop)

  :perform (test-op (o c) (uiop:symbol-call "PETALISP" "RUN-TEST-SUITE"))

  :components
  ((:module "code"
    :components
    ((:file "package")
     (:module "utilities" :depends-on ("package")
      :components
      ((:file "code-statistics")
       (:file "extended-euclid" :depends-on ("macros" "testing"))
       (:file "function-lambda-lists")
       (:file "generic-funcallable-objects")
       (:file "graphviz")
       (:file "iterate")
       (:file "macros")
       (:file "matrix" :depends-on ("macros" "testing"))
       (:file "memoization")
       (:file "miscellaneous" :depends-on ("macros" "testing"))
       (:file "queue")
       (:file "testing")))
     (:file "petalisp" :depends-on ("utilities"))
     (:module "transformations" :depends-on ("petalisp")
      :components
      ((:file "identity-transformation")
       (:file "affine-transformation" :depends-on ("identity-transformation"))
       (:file "classify-transformation" :depends-on ("affine-transformation"))))
     (:module "data-structures" :depends-on ("transformations")
      :components
      ((:file "range")
       (:file "strided-array-index-space" :depends-on ("range"))
       (:file "strided-array" :depends-on ("strided-array-index-space"))
       (:file "strided-array-constant" :depends-on ("strided-array"))
       (:file "visualization" :depends-on ("strided-array-constant"))))
     (:module "evaluator" :depends-on ("data-structures")
      :components
      ((:file "compiler")
       (:file "intermediate-result")
       (:file "kernelize" :depends-on ("kernel" "intermediate-result"))
       (:file "kernel")
       (:file "memory-pool" :depends-on ("intermediate-result"))
       (:file "scheduler" :depends-on ("kernelize" "memory-pool"))))
     (:file "api" :depends-on ("evaluator"))))))
