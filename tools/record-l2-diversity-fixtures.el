;;; record-l2-diversity-fixtures.el --- record additional L2 filer fixtures -*- lexical-binding: t; -*-

;; Run with the package Emacs load path and a real `xbrl-user-agent'.

;;; Code:

(require 'record-fixtures)

(defconst edgar-record-l2-diversity-forms
  '("10-K" "10-KT" "10-Q" "15-12G" "18-K" "20-F" "25" "8-K"
    "NT 10-K" "NT 10-Q" "NT 11-K" "NT 20-F")
  "Forms whose current L2 fixture set needs more distinct filers.")

(defun edgar-record-l2-diversity--known-ciks (form)
  "Return CIKs already recorded for FORM."
  (let (ciks)
    (dolist (file (directory-files (edgar-record--dir) t "\\.eld\\'"))
      (condition-case nil
          (with-temp-buffer
            (insert-file-contents file)
            (let* ((metadata (read (current-buffer)))
                   (cik (plist-get metadata :cik)))
              (when (and (equal (plist-get metadata :form) form)
                         (integerp cik))
                (cl-pushnew cik ciks))))
        (error nil)))
    ciks))

(defun edgar-record-l2-diversity-fixtures-run ()
  "Record real SEC filings until each listed form has three distinct CIKs."
  (interactive)
  (let* ((edgar-record-candidate-limit 8)
         (quarters '((2026 . 2) (2026 . 1)))
         (all-filings nil))
    (dolist (quarter quarters)
      (let ((filings
             (edgar-index-filings (car quarter) (cdr quarter))))
        (setq all-filings (nconc all-filings filings))))
    (dolist (form edgar-record-l2-diversity-forms)
      (let ((known (edgar-record-l2-diversity--known-ciks form)))
        (while (< (length known) 3)
          (let* ((filings
                  (seq-filter
                   (lambda (filing)
                     (and (equal (plist-get filing :form) form)
                          (not (member (plist-get filing :cik) known))))
                   all-filings))
                 (edgar-record-candidate-limit
                  (if (equal form "20-F") 24 8))
                 (edgar-record-max-bytes
                  (if (equal form "20-F") (* 8 1024 1024)
                    edgar-record-max-bytes))
                 (edgar-record-max-gzip-bytes
                  (if (equal form "20-F") (* 3 1024 1024)
                    edgar-record-max-gzip-bytes))
                 (candidate
                  (car
                   (edgar-record--candidate-docs
                    form "diversity" filings))))
            (unless candidate
              (error "No suitable distinct SEC primary remains for %s" form))
            (let* ((filing (nth 0 candidate))
                   (cik (plist-get filing :cik))
                   (date (plist-get filing :filed))
                   (year (string-to-number (substring date 0 4)))
                   (month (string-to-number (substring date 5 7)))
                   (quarter-number (1+ (/ (1- month) 3)))
                   (quarter (cons year quarter-number))
                   (slug (format "diversity-%s-%d"
                                 (edgar-record--form-slug form) cik)))
              (unless (member quarter quarters)
                (error "Unexpected candidate quarter: %s" date))
              (unless
                  (edgar-record--write-pair
                   slug filing (nth 1 candidate) quarter "diversity")
                (error "Could not record %s CIK %s" form cik))
              (push cik known))))))
  (message "L2 diversity fixture recording complete")))

(provide 'record-l2-diversity-fixtures)
;;; record-l2-diversity-fixtures.el ends here
