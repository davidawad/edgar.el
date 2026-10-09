;;; edgar-golden-test-support.el --- Shared helpers for edgar-golden-test -*- lexical-binding: t; -*-

;;; Commentary:

;; Helpers and fixtures shared by `edgar-golden-test' and its companion test files.

;;; Code:

(require 'ert)

(add-to-list
 'load-path
 (file-name-directory (or load-file-name buffer-file-name)))

(require 'edgar-fixtures)

(defun edgar-golden-test--bodies (slug)
  "Alist of (KEY . normalized body) for fixture SLUG."
  (mapcar
   (lambda (s) (cons (car s) (edgar-fixtures-norm (cdr s))))
   (edgar-sections (edgar-fixtures-text slug))))

(defun edgar-golden-test--check-section (slug key strings bodies)
  "Assert STRINGS from SLUG's section KEY are in it and in no other of BODIES."
  (let ((body (cdr (assoc key bodies))))
    (unless body
      (ert-fail
       (format "%s: section %s no longer found (have %s)"
               slug
               key
               (mapconcat #'car bodies " "))))
    (dolist (str strings)
      (unless (string-search str body)
        (ert-fail
         (format "%s: %S missing from section %s" slug str key)))
      (dolist (other bodies)
        (when (and (not (equal (car other) key))
                   (string-search str (cdr other)))
          (ert-fail
           (format "%s: %S from section %s also appears in %s"
                   slug str key (car other))))))))

(defun edgar-golden-test--run (slug)
  "Check fixture SLUG against its golden strings."
  (let* ((golden
          (edgar-fixtures-read
           (edgar-fixtures-path (concat "golden/" slug ".eld"))))
         (bodies (edgar-golden-test--bodies slug))
         (norm (edgar-fixtures-norm (edgar-fixtures-text slug))))
    (dolist (entry (plist-get golden :sections))
      (edgar-golden-test--check-section
       slug (car entry) (cdr entry) bodies))
    ;; Every section the parser finds must have golden coverage.
    (dolist (b bodies)
      (unless (assoc (car b) (plist-get golden :sections))
        (ert-fail
         (format "%s: section %s has no golden strings"
                 slug
                 (car b)))))
    (dolist (str (plist-get golden :text))
      (unless (string-search str norm)
        (ert-fail
         (format "%s: whole-text string %S missing" slug str))))
    (should
     (or (plist-get golden :sections) (plist-get golden :text)))))

(defun edgar-golden-test--check-named-section-fixtures (form heading slugs)
  "Check FORM filings in SLUGS expose HEADING using its reviewed goldens."
  (let ((goldens
         (edgar-fixtures-read
          (edgar-fixtures-path "golden-named-sections.eld"))))
    (dolist (slug slugs)
      (let* ((filing (edgar-fixtures-filing slug))
             (html (edgar-fixtures-html slug))
             (golden
              (seq-find
               (lambda (entry)
                 (and (equal (car entry) slug)
                      (equal (cadr entry) heading)))
               goldens)))
        (should (equal (plist-get filing :form) form))
        (should golden)
        (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) html)))
          (let ((body (edgar-section filing heading)))
            (should (stringp body))
            (should
             (string-match-p
              (regexp-quote (downcase (nth 2 golden)))
              (downcase (edgar-fixtures-norm body))))))))))

(provide 'edgar-golden-test-support)

;;; edgar-golden-test-support.el ends here
