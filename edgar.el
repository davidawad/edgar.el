;;; edgar.el --- Read SEC EDGAR filings -*- lexical-binding: t; -*-

;; Version: 0.1.0
;; URL: https://github.com/davidawad/edgar.el
;; Package-Requires: ((emacs "29.1") (xbrl "0.1.0"))
;; Keywords: finance, tools, hypermedia

;;; Commentary:

;; Navigate EDGAR as a corpus: list a company's filings, open a 10-K in a
;; buffer, and pull out its Items as plain strings so Lisp can use them.
;; Numeric XBRL facts live in the sibling package `xbrl' (xbrl.el).
;;
;;   (edgar-filings "AAPL" "10-K")          ; list of filing plists
;;   (edgar-latest "AAPL" "10-K")           ; newest one
;;   (edgar-section (edgar-latest "AAPL" "10-K") "1A")  ; Risk Factors text
;;
;; Interactive: `edgar-list' (browse filings), `edgar-read' (open latest).
;; Uses `xbrl-user-agent' for the SEC-required User-Agent header.

;;; Code:

(require 'edgar-core)
(require 'edgar-content)
(require 'edgar-structure)
(require 'edgar-headings)
(require 'edgar-named)
(require 'edgar-sections)
(require 'edgar-forms)
(require 'edgar-http)
(require 'edgar-index)
(require 'cl-lib)
(require 'subr-x)

;;;; Interactive

(defvar-local edgar--filing nil)

(define-derived-mode
 edgar-list-mode
 tabulated-list-mode
 "EDGAR"
 "Browse EDGAR filings.  RET opens the filing at point."
 (define-key edgar-list-mode-map (kbd "RET") #'edgar-list-open))

(defun edgar-list-open ()
  "Open the filing at point."
  (interactive)
  (edgar-open (tabulated-list-get-id)))

;;;###autoload
(defun edgar-list (ticker &optional form)
  "List TICKER's filings (optionally only FORM) in a browsable buffer."
  (interactive (list
                (xbrl--read-ticker)
                (let ((f (read-string "Form (blank = all): ")))
                  (unless (string-empty-p f)
                    f))))
  (let ((rows (edgar-filings ticker form)))
    (with-current-buffer (get-buffer-create
                          (format "*edgar: %s*" (upcase ticker)))
      (edgar-list-mode)
      (setq tabulated-list-format
            [("Filed" 12 t)
             ("Form" 8 t)
             ("Period" 12 t)
             ("Accession" 22 t)]
            tabulated-list-entries
            (mapcar
             (lambda (f)
               (list
                f
                (vector
                 (plist-get f :filed)
                 (plist-get f :form)
                 (or (plist-get f :report) "")
                 (plist-get f :accn))))
             rows))
      (tabulated-list-init-header)
      (tabulated-list-print)
      (pop-to-buffer (current-buffer)))))

(defun edgar-open (filing)
  "Render FILING in a read-only buffer."
  (let ((buf
         (get-buffer-create
          (format "*edgar: %s*" (plist-get filing :accn)))))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (edgar-text filing))
        (goto-char (point-min)))
      (special-mode)
      (setq edgar--filing filing))
    (pop-to-buffer buf)))

;;;###autoload
(defun edgar-read (ticker form)
  "Open the latest FORM filing for TICKER."
  (interactive (list
                (xbrl--read-ticker)
                (completing-read
                 "Form: " '("10-K" "10-Q" "8-K" "DEF 14A")
                 nil nil "10-K")))
  (edgar-open
   (or (edgar-latest ticker form)
       (user-error "No %s for %s" form ticker))))

(provide 'edgar)
;;; edgar.el ends here
