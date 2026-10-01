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

(require 'xbrl)
(require 'shr)
(require 'dom)
(require 'cl-lib)
(require 'url)

;;;; Transport

(defun edgar--fetch (url)
  "Return the body of URL as a decoded string."
  (let ((url-request-extra-headers
         `(("User-Agent" . ,xbrl-user-agent)))
        (buf (url-retrieve-synchronously url t t 60)))
    (unless buf
      (error "EDGAR: no response from %s" url))
    (with-current-buffer buf
      (unwind-protect
          (progn
            (goto-char (point-min))
            (unless (looking-at "HTTP/[0-9.]+ 200")
              (error
               "EDGAR: %s -> %s"
               url
               (buffer-substring (point) (line-end-position))))
            (re-search-forward "\r?\n\r?\n")
            (decode-coding-string
             (buffer-substring-no-properties
              (point) (point-max))
             'utf-8))
        (kill-buffer buf)))))

;;;; Filing lists

(defun edgar-filings (ticker &optional form)
  "Recent filings for TICKER as plists, newest first.
Each has :accn :form :filed :report :doc :cik :url.  FORM, if given,
filters on exact form type, e.g. \"10-K\".  Covers the SEC's `recent'
window (about 1000 filings)."
  (let* ((cik (xbrl-cik ticker))
         (sub
          (xbrl--get
           (format "https://data.sec.gov/submissions/%s.json" cik)))
         (r (plist-get (plist-get sub :filings) :recent))
         (n (string-to-number (substring cik 3))))
    (cl-loop
     for
     accn
     in
     (plist-get r :accessionNumber)
     for
     frm
     in
     (plist-get r :form)
     for
     filed
     in
     (plist-get r :filingDate)
     for
     rep
     in
     (plist-get r :reportDate)
     for
     doc
     in
     (plist-get r :primaryDocument)
     when
     (or (null form) (equal frm form))
     collect
     (list
      :accn accn
      :form frm
      :filed filed
      :report rep
      :doc doc
      :cik n
      :url
      (format "https://www.sec.gov/Archives/edgar/data/%d/%s/%s"
              n (replace-regexp-in-string "-" "" accn) doc)))))

(defun edgar-latest (ticker form)
  "Newest FORM filing for TICKER, or nil."
  (car (edgar-filings ticker form)))

;;;; Content

(defun edgar-html (filing)
  "Raw HTML (iXBRL) of FILING's primary document."
  (edgar--fetch (plist-get filing :url)))

(defun edgar-text (filing)
  "FILING rendered to plain text (what `shr' would display)."
  (let ((html (edgar-html filing)))
    (with-temp-buffer
      (insert html)
      (let ((dom (libxml-parse-html-region (point-min) (point-max))))
        (erase-buffer)
        (let ((shr-inhibit-images t)
              (shr-use-fonts nil)
              (shr-width 100))
          (shr-insert-document dom)))
      (buffer-substring-no-properties (point-min) (point-max)))))

(defconst edgar--item-re "^[ \t]*Item[ \t ]+\\([0-9]+[A-C]?\\)\\.")

(defun edgar-sections (text)
  "Alist of (ITEM . BODY) from filing TEXT, e.g. (\"1A\" . \"Risk Factors...\").
The table of contents repeats every Item heading with no body, so for each
Item the occurrence with the longest body wins."
  (let (marks
        best)
    (with-temp-buffer
      (insert text)
      (goto-char (point-min))
      (while (re-search-forward edgar--item-re nil t)
        (push (cons
               (upcase (match-string 1)) (line-beginning-position))
              marks))
      (setq marks (nreverse marks))
      (cl-loop
       for
       (m . rest)
       on
       marks
       for
       end
       =
       (if rest
           (cdar rest)
         (point-max))
       for
       body
       =
       (buffer-substring-no-properties (cdr m) end)
       for
       old
       =
       (assoc (car m) best)
       when
       (or (null old) (> (length body) (length (cdr old))))
       do
       (setq best
             (cons
              (cons (car m) body) (assoc-delete-all (car m) best)))))
    (sort best (lambda (a b) (edgar--item< (car a) (car b))))))

(defun edgar--item< (a b)
  "Return non-nil if Item label A precedes B, numerically then by letter."
  (let ((na (string-to-number a))
        (nb (string-to-number b)))
    (or (< na nb) (and (= na nb) (string< a b)))))

(defun edgar-section (filing item)
  "Text of ITEM (e.g. \"1A\", \"7\") from FILING."
  (cdr (assoc (upcase item) (edgar-sections (edgar-text filing)))))

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
