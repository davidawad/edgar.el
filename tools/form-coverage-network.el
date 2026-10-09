;;; form-coverage-network.el --- Check current SEC forms -*- lexical-binding: t; -*-

;;; Commentary:

;; Opt-in network entry point for `eask run script coverage-network'.

;;; Code:

(let ((root
       (expand-file-name ".."
                         (file-name-directory
                          (or load-file-name buffer-file-name)))))
  (add-to-list 'load-path root)
  (add-to-list 'load-path (expand-file-name "tools" root))
  (require 'edgar-form-coverage)
  (edgar-coverage-network-run))

;;; form-coverage-network.el ends here
