(defsystem :petalisp
  :description "Elegant High Performance Computing"
  :author "Marco Heisig <marco.heisig@fau.de>"
  :license "AGPLv3"
  :class :package-inferred-system
  :depends-on ("petalisp/core/api")
  :in-order-to ((test-op (test-op :petalisp-test-suite))))

(register-system-packages "closer-mop" '(:closer-common-lisp))
