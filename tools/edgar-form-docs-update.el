;;; edgar-form-docs-update.el --- Update generated form documentation -*- lexical-binding: t; -*-

(let ((root (expand-file-name ".."
                              (file-name-directory
                               (or load-file-name buffer-file-name)))))
  (add-to-list 'load-path (expand-file-name "src" root))
  (add-to-list 'load-path (expand-file-name "tools" root))
  (require 'edgar-form-docs)
  (edgar-form-docs-update))

;;; edgar-form-docs-update.el ends here
