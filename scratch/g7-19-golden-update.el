;;; g7-19-golden-update.el --- regenerate only assigned G7 goldens -*- lexical-binding: t; -*-

(require 'edgar-fixtures)

  (let ((slugs '("10-12b-middleby"
               "10-12b-kioni"
               "10-12b-mobility"
               "10-12g-biokey"
               "10-12g-feel-the-world"
               "10-12g-jlm-wnco"
               "20fr12b-clinuvel"
               "20fr12b-wise"
               "20fr12b-vicore"
               "20fr12g-chdgai"
               "20fr12g-greenbriar"
               "20fr12g-nec"
               "40fr12g-nuran"
               "40fr12g-bespoke"
               "40fr12g-cresco")))
  (cl-letf (((symbol-function 'edgar-fixtures-slugs)
             (lambda () slugs)))
    (load-file "tools/make-golden.el")))
