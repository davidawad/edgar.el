;;; edgar-fixtures.el --- load recorded SEC filings for tests -*- lexical-binding: t; -*-

;; Shared by test/edgar-expect-test.el, test/edgar-golden-test.el and
;; tools/make-golden.el.  A fixture is a recorded real filing:
;; test/fixtures/<slug>.eld (the filing plist) plus a recorded primary document.
;; Everything here is offline.

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
  "Slugs of every rendered filing fixture, sorted.
XML-only fixtures are exercised by form-specific tests."
  (sort (seq-filter
         (lambda (slug)
           (seq-some
            (lambda (suffix)
              (file-exists-p
               (edgar-fixtures-path
                (concat "fixtures/" slug suffix))))
            '(".htm.gz" ".pdf" ".txt")))
         (mapcar
          #'file-name-sans-extension
          (directory-files (edgar-fixtures-path "fixtures")
                           nil
                           "\\.eld\\'")))
        #'string<))

(defun edgar-fixtures--primary-file (slug)
  "Absolute path of SLUG's rendered primary fixture."
  (or (seq-find
       #'file-exists-p
       (mapcar
        (lambda (suffix)
          (edgar-fixtures-path (concat "fixtures/" slug suffix)))
        '(".htm.gz" ".pdf" ".txt")))
      (error "No rendered primary fixture for %s" slug)))

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
  (edgar-fixtures-primary slug))

(defun edgar-fixtures-primary (slug)
  "Primary document body of SLUG, preserving PDF bytes."
  (with-temp-buffer
    (let ((file (edgar-fixtures--primary-file slug)))
      (if (string-suffix-p ".pdf" file t)
          (progn
            (set-buffer-multibyte nil)
            (insert-file-contents-literally file))
        (let ((coding-system-for-read 'utf-8)
              (auto-compression-mode t))
          (insert-file-contents file))))
    (buffer-string)))

(defun edgar-fixtures-text (slug)
  "SLUG's filing rendered by `edgar-text', fully offline."
  (let ((primary (edgar-fixtures-primary slug)))
    (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) primary)))
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
