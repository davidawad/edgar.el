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
(require 'edgar-forms)
(require 'edgar-http)
(require 'edgar-index)
(require 'shr)
(require 'dom)
(require 'cl-lib)
(require 'url)

;;;; Transport

(defun edgar--fetch (url)
  "Return the body of URL as a decoded string."
  (edgar-http-get url xbrl-user-agent))

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

(defconst edgar--part-re
  (concat
   "^[ \t ]*\\(?:PART\\|Part\\)[ \t ]+\\(IV\\|I\\{1,3\\}\\)"
   "\\(?:[ \t ]*$"
   "\\|[ \t ]*[.:—–\u0096\u0097-].\\{0,60\\}$"
   "\\|[ \t ]+[A-Z][A-Za-z ,&'’ -]\\{0,60\\}$\\)")
  "Match a Part heading line; group 1 is the Roman numeral.
A bare title after the numeral (\"PART I  FINANCIAL INFORMATION\") counts;
cross-references like \"Part I, Item 1A\" do not.")

(defconst edgar--item-re
  (concat
   "^[ \t ]*\\(?:Item\\|ITEM\\)[ \t ]+"
   "\\([0-9]+\\(?:\\.[0-9]+\\)?[A-C]?\\)"
   "\\(?:[.:]\\|[ \t ]*[—–\u0096\u0097-]\\|[ \t ]+[A-Z]\\|[ \t ]*$\\)")
  "Match an Item heading line; group 1 is the item number, e.g. 1A or 2.02.
Matched case-sensitively: a wrapped cross-reference such as \"Item 1A of
this report\" starts with lowercase and is not a heading.")

(defconst edgar--roman '(("I" . 1) ("II" . 2) ("III" . 3) ("IV" . 4)))

(defun edgar--matches (re text &optional reject)
  "Return (LINE-START . LABEL) for each match of RE in TEXT, in order.
Lines that also match the regexp REJECT are skipped."
  (with-temp-buffer
    (insert text)
    (goto-char (point-min))
    (let ((case-fold-search nil)
          out)
      (while (re-search-forward re nil t)
        (unless (and reject
                     (string-match-p
                      reject
                      (buffer-substring
                       (line-beginning-position)
                       (line-end-position))))
          (push (cons
                 (line-beginning-position) (upcase (match-string 1)))
                out)))
      (nreverse out))))

(defun edgar--runs (marks)
  "Keep only the first of consecutive entries that share a label.
MARKS is a list of (POSITION . LABEL).  Some filers repeat a running
header such as \"PART I\" or \"Item 1\" on every page;
those must not split the section they sit inside."
  (let (out)
    (dolist (m marks)
      (unless (equal (cdr m) (cdr (car out)))
        (push m out)))
    (nreverse out)))

(defun edgar--part-at (parts pos)
  "Roman numeral of the last Part heading in PARTS before POS, or nil."
  (cdr
   (car (last (seq-take-while (lambda (p) (< (car p) pos)) parts)))))

(defun edgar--key (item part)
  "Section key for ITEM within PART: \"II.1A\", or just \"1A\" with no PART."
  (if part
      (concat part "." item)
    item))

(defun edgar--split-key (key)
  "Return (PART-NUMBER . ITEM) for KEY; PART-NUMBER is 0 when KEY has no Part."
  (if (string-match "\\`\\(IV\\|I\\{1,3\\}\\)\\.\\(.+\\)\\'" key)
      (cons
       (cdr (assoc (match-string 1 key) edgar--roman))
       (match-string 2 key))
    (cons 0 key)))

(defun edgar--item< (a b)
  "Return non-nil if Item label A precedes B, numerically then by letter."
  (let ((na (string-to-number a))
        (nb (string-to-number b)))
    (or (< na nb) (and (= na nb) (string< a b)))))

(defun edgar--key< (a b)
  "Return non-nil if section key A precedes B (by Part, then by Item)."
  (let ((ka (edgar--split-key a))
        (kb (edgar--split-key b)))
    (or (< (car ka) (car kb))
        (and (= (car ka) (car kb))
             (edgar--item< (cdr ka) (cdr kb))))))

(defun edgar-sections (text)
  "Alist of (KEY . BODY) for the Items in filing TEXT, in filing order.
KEY is the item number (\"1A\", \"2.02\"), prefixed with the Part when the
filing has Parts: \"I.2\" and \"II.2\" are different sections of a 10-Q.
Forms without Item headings give nil.  The table of contents repeats every
heading with no body, so for each key the occurrence with the longest body
wins."
  (let* ((parts
          (edgar--runs
           (edgar--matches edgar--part-re text "\\bItems?\\b")))
         (items
          (edgar--runs
           (mapcar
            (lambda (it)
              (cons
               (car it)
               (edgar--key (cdr it) (edgar--part-at parts (car it)))))
            (edgar--matches edgar--item-re text))))
         (bounds (sort (mapcar #'car (append parts items)) #'<))
         (best (make-hash-table :test 'equal)))
    (dolist (it items)
      (let* ((start (car it))
             (end
              (or (seq-find (lambda (b) (> b start)) bounds)
                  (1+ (length text))))
             (key (cdr it))
             (body (substring text (1- start) (1- end)))
             (old (gethash key best)))
        (when (or (null old) (> (length body) (length old)))
          (puthash key body best))))
    (let (out)
      (maphash (lambda (k v) (push (cons k v) out)) best)
      (edgar--drop-residue
       (sort out (lambda (a b) (edgar--key< (car a) (car b))))))))

(defun edgar--heading-only-p (body)
  "Non-nil if BODY is a lone heading line with no sentence after it.
That is what a table-of-contents entry leaves behind."
  (let
      ((rest
        (replace-regexp-in-string
         "\\`[ \t\n\u00a0]*\\(?:Item\\|ITEM\\)[ \t\u00a0]+[0-9.]+[A-C]?[.:]?"
         ""
         body)))
    (and (= 1
            (length
             (seq-remove #'string-blank-p (split-string body "\n"))))
         (not (string-match-p "[.!?]" rest)))))

(defun edgar--drop-residue (secs)
  "Remove from SECS the heading-only entries that duplicate another Part's item.
A 20-F table of contents without Part headings, for instance, leaves a
bare \"I.13\" next to the real \"II.13\"."
  (seq-remove
   (lambda (e)
     (and (edgar--heading-only-p (cdr e))
          (seq-some
           (lambda (o)
             (and (not (eq o e))
                  (equal
                   (cdr (edgar--split-key (car o)))
                   (cdr (edgar--split-key (car e))))))
           secs)))
   secs))

(defun edgar-section (filing item)
  "Text of ITEM from FILING, e.g. \"1A\", \"7\", \"2.02\" or \"II.1\".
A bare ITEM that exists in several Parts (10-Q Item 2) signals an error
listing the Part-qualified keys; unknown ITEM returns nil."
  (let* ((secs (edgar-sections (edgar-text filing)))
         (want (upcase item))
         (exact (assoc want secs)))
    (if exact
        (cdr exact)
      (let ((hits
             (seq-filter
              (lambda (s)
                (string-match-p
                 (concat
                  "\\`\\(?:IV\\|I\\{1,3\\}\\)\\."
                  (regexp-quote want)
                  "\\'")
                 (car s)))
              secs)))
        (cond
         ((null hits)
          nil)
         ((null (cdr hits))
          (cdr (car hits)))
         (t
          (user-error "Item %s is ambiguous; use one of %s"
                      want
                      (mapconcat #'car hits ", "))))))))

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
