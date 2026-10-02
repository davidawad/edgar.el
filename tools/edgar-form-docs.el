;;; edgar-form-docs.el --- Generate per-form coverage reference -*- lexical-binding: t; -*-

;;; Commentary:

;; Keep the per-form documentation table synchronized with edgar-forms.el.

;;; Code:

(require 'edgar-forms)
(require 'subr-x)

(defconst edgar-form-docs--root
  (expand-file-name ".." (file-name-directory (or load-file-name buffer-file-name))))

(defconst edgar-form-docs--start "<!-- BEGIN GENERATED FORM COVERAGE -->")
(defconst edgar-form-docs--end "<!-- END GENERATED FORM COVERAGE -->")

(defun edgar-form-docs--rows ()
  "Return sorted markdown rows for the form registry."
  (let (forms)
    (maphash (lambda (form _info) (push form forms)) edgar-forms--registry)
    (mapcar
     (lambda (form)
       (let* ((info (edgar-form-info form))
              (example
               (pcase (plist-get info :level)
                 ('L0 (format "`(edgar-form-info \"%s\")`" form))
                 ('L1 "`(edgar-text filing)`")
                 (_ (pcase (plist-get info :backend)
                      ('xml "`(edgar-xml filing)`")
                      (_ "`(edgar-structure-headings (edgar-document-structure filing))`"))))))
         (format "| `%s` | %s | %s | %s | %s |"
                 form
                 (or (plist-get info :family) "")
                 (or (plist-get info :backend) "")
                 (or (plist-get info :level) "")
                 example)))
     (sort forms #'string<))))

(defun edgar-form-docs--table ()
  "Return the generated markdown table."
  (concat
   "| Form | Family | Backend | Level | Example call |\n"
   "|---|---|---|---|---|\n"
   (mapconcat #'identity (edgar-form-docs--rows) "\n")
   "\n"))

(defun edgar-form-docs--render (text)
  "Replace the generated block in TEXT, returning the updated text."
  (let ((start (string-match (regexp-quote edgar-form-docs--start) text))
        (end (string-match (regexp-quote edgar-form-docs--end) text)))
    (unless (and start end (< start end))
      (error "Form coverage document is missing generated-table markers"))
    (concat
     (substring text 0 (+ start (length edgar-form-docs--start)))
     "\n"
     (edgar-form-docs--table)
     (substring text end))))

(defun edgar-form-docs-update ()
  "Rewrite the generated table in `docs/form-coverage.md'."
  (let ((file (expand-file-name "docs/form-coverage.md" edgar-form-docs--root)))
    (with-temp-buffer
      (insert-file-contents file)
      (let ((rendered (edgar-form-docs--render (buffer-string))))
        (erase-buffer)
        (insert rendered)
        (write-region (point-min) (point-max) file)))))

(defun edgar-form-docs-check ()
  "Signal an error when the generated table is stale."
  (let* ((file (expand-file-name "docs/form-coverage.md" edgar-form-docs--root))
         (actual (with-temp-buffer
                   (insert-file-contents file)
                   (buffer-string)))
         (expected (edgar-form-docs--render actual)))
    (unless (equal actual expected)
      (error "docs/form-coverage.md per-form table is stale; run `eask run script docs'"))))

(provide 'edgar-form-docs)

;;; edgar-form-docs.el ends here
