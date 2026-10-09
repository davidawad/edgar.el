;;; form-coverage-test-support.el --- Shared helpers for form-coverage-test -*- lexical-binding: t; -*-

;;; Commentary:

;; Helpers and fixtures shared by `form-coverage-test' and its companion test files.

;;; Code:

(require 'ert)

(require 'cl-lib)

(require 'edgar-index)

(defconst edgar-form-coverage-test--directory
  (file-name-directory (or load-file-name buffer-file-name)))

(add-to-list
 'load-path
 (expand-file-name "../tools" edgar-form-coverage-test--directory))

(require 'edgar-form-coverage)

(defun edgar-form-coverage-test--messages (problems)
  "Join PROBLEMS for readable assertions."
  (mapconcat #'identity problems "\n"))

(defun edgar-form-coverage-test--write (file contents)
  "Write CONTENTS to FILE, creating its directory."
  (make-directory (file-name-directory file) t)
  (with-temp-file file
    (insert contents)))

(defun edgar-form-coverage-test--seed-l2-artifacts (root backend count)
  "Create COUNT complete L2 test filings under ROOT for BACKEND."
  (let ((fixtures (expand-file-name "fixtures" root))
        (expects (expand-file-name "expect" root))
        (goldens (expand-file-name "golden" root))
        (field-goldens (expand-file-name "golden-fields" root)))
    (dotimes (index count)
      (let* ((number (1+ index))
             (slug (format "filer-%d" number))
             (primary-suffix (if (eq backend 'xml) ".xml" ".htm.gz"))
             (golden-dir (if (eq backend 'xml) field-goldens goldens)))
        (edgar-form-coverage-test--write
         (expand-file-name (concat slug ".eld") fixtures)
         (format "(:form \"TEST-FORM\" :cik %d)\n" (+ 1000 number)))
        (edgar-form-coverage-test--write
         (expand-file-name (concat slug primary-suffix) fixtures) "fixture")
        (edgar-form-coverage-test--write
         (expand-file-name (concat slug ".eld") expects) "(:ok t)\n")
        (edgar-form-coverage-test--write
         (expand-file-name (concat slug ".eld") golden-dir)
         "(:fields (value))\n")))))

(defun edgar-form-coverage-test--registry (level &optional backend)
  "Return a one-row test registry at LEVEL using BACKEND or HTML."
  (let ((registry (make-hash-table :test #'equal)))
    (puthash
     "TEST-FORM"
     (list
      :family "Test"
      :backend (or backend 'html)
      :level level
      :sections-or-fields nil
      :volume 1
      :notes nil)
     registry)
    registry))

(provide 'form-coverage-test-support)

;;; form-coverage-test-support.el ends here
