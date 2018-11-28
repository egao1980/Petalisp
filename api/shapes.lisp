;;;; © 2016-2018 Marco Heisig - licensed under AGPLv3, see the file COPYING     -*- coding: utf-8 -*-

(in-package :petalisp-api)

(defmacro ~ (&rest tilde-separated-range-designators)
  (let* ((range-designators
           (split-sequence:split-sequence '~ tilde-separated-range-designators)))
    `(make-shape
      ,@(loop for range-designator in range-designators
              collect `(range ,@range-designator)))))