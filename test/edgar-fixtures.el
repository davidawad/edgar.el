;;; edgar-fixtures.el --- load recorded SEC filings for tests -*- lexical-binding: t; -*-

;; Shared by test/edgar-expect-test.el, test/edgar-golden-test.el and
;; tools/make-golden.el.  A fixture is a recorded real filing:
;; test/fixtures/<slug>.eld (the filing plist) + <slug>.htm.gz (its primary
;; document).  Everything here is offline.

(require 'cl-lib)
(require 'subr-x)
(require 'edgar)

(defconst edgar-fixtures--test-dir
  (file-name-directory (or load-file-name buffer-file-name))
  "The test/ directory.")

(defun edgar-fixtures-path (rel)
  "Absolute path of REL under test/."
  (expand-file-name rel edgar-fixtures--test-dir))

(defun edgar-fixtures-slugs ()
  "Slugs of every recorded fixture, sorted."
  (sort (mapcar
         #'file-name-sans-extension
         (directory-files (edgar-fixtures-path "fixtures")
                          nil
                          "\\.eld\\'"))
        #'string<))

(defun edgar-fixtures-read (file)
  "Read the Lisp object in FILE."
  (with-temp-buffer
    (insert-file-contents file)
    (read (current-buffer))))

(defun edgar-fixtures-filing (slug)
  "The filing plist recorded for SLUG."
  (edgar-fixtures-read
   (edgar-fixtures-path (concat "fixtures/" slug ".eld"))))

(defun edgar-fixtures-html (slug)
  "Decompressed primary document of SLUG."
  (with-temp-buffer
    (let ((coding-system-for-read 'utf-8)
          (auto-compression-mode t))
      (insert-file-contents
       (edgar-fixtures-path (concat "fixtures/" slug ".htm.gz"))))
    (buffer-string)))

(defun edgar-fixtures-text (slug)
  "SLUG's filing rendered by `edgar-text', fully offline."
  (let ((html (edgar-fixtures-html slug)))
    (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) html)))
      (edgar-text (edgar-fixtures-filing slug)))))

(defun edgar-fixtures-norm (s)
  "S with every whitespace run, Unicode spaces included, collapsed to one space."
  (string-trim
   (replace-regexp-in-string
    "[ \t\n\r ]+"
    " "
    (replace-regexp-in-string "[ -​  　]" " " s t t))))

(provide 'edgar-fixtures)
;;; edgar-fixtures.el ends here
