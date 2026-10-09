;;; form-coverage-check.el --- Run offline form coverage -*- lexical-binding: t; -*-

;;; Commentary:

;; Batch entry point for `eask run script coverage'.

;;; Code:

(let ((root
       (expand-file-name ".."
                         (file-name-directory
                          (or load-file-name buffer-file-name)))))
  (add-to-list 'load-path root)
  (add-to-list 'load-path (expand-file-name "tools" root))
  (require 'edgar-form-coverage)
  (require 'edgar-form-docs)
  (edgar-form-docs-check)
  (edgar-coverage-run))

;;; form-coverage-check.el ends here
