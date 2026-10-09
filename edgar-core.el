;;; edgar-core.el --- Shared core of edgar.el: options, transport and filing lists -*- lexical-binding: t; -*-

;; Package-Requires: ((emacs "29.1") (xbrl "0.1.0"))

;;; Commentary:

;; Shared core of edgar.el: options, transport and filing lists.
;; Part of `edgar'; see edgar.el for the overview.

;;; Code:

(require 'xbrl)
(require 'edgar-forms)
(require 'edgar-http)
(require 'edgar-index)
(require 'cl-lib)
(require 'subr-x)
(require 'url)

(defgroup edgar nil
  "Read and navigate SEC EDGAR filings."
  :group 'applications)

(defcustom edgar-pdftotext-program "pdftotext"
  "Program used to render PDF primary documents as plain text."
  :type 'string
  :group 'edgar)

(defcustom edgar-uudecode-program "uudecode"
  "Program used to decode UUENCODED PDF primary documents."
  :type 'string
  :group 'edgar)

;;;; Transport

(defun edgar--fetch (url)
  "Return the body of URL as a decoded string."
  (edgar-http-get url xbrl-user-agent))

;;;; Filing lists

(defun edgar--date-in-range-p (date since until)
  "Return non-nil when DATE is between SINCE and UNTIL, inclusive."
  (and date
       (or (null since) (not (string< date since)))
       (or (null until) (not (string< until date)))))

(defun edgar--page-in-range-p (page since until)
  "Return non-nil when PAGE may contain filings between SINCE and UNTIL."
  (let ((from (plist-get page :filingFrom))
        (to (plist-get page :filingTo)))
    (and (or (null since) (null to) (not (string< to since)))
         (or (null until) (null from) (not (string< until from))))))

(defun edgar--filings-from-table (table cik form since until)
  "Convert column-oriented TABLE to filing plists for CIK.
Limit results to FORM and the inclusive SINCE and UNTIL filing dates."
  (cl-loop
   for
   accn
   in
   (plist-get table :accessionNumber)
   for
   frm
   in
   (plist-get table :form)
   for
   filed
   in
   (plist-get table :filingDate)
   for
   rep
   in
   (plist-get table :reportDate)
   for
   doc
   in
   (plist-get table :primaryDocument)
   when
   (and (or (null form) (equal frm form))
        (edgar--date-in-range-p filed since until))
   collect
   (list
    :accn accn
    :form frm
    :filed filed
    :report rep
    :doc doc
    :cik cik
    :url
    (format "https://www.sec.gov/Archives/edgar/data/%d/%s/%s"
            cik (replace-regexp-in-string "-" "" accn) doc))))

(defun edgar--unique-filings (filings)
  "Return FILINGS without duplicate accession numbers, preserving order."
  (let ((seen (make-hash-table :test #'equal))
        unique)
    (dolist (filing filings (nreverse unique))
      (let ((accn (plist-get filing :accn)))
        (unless (gethash accn seen)
          (puthash accn t seen)
          (push filing unique))))))

(defun edgar--base-form (form)
  "Return FORM with its optional `/A' amendment suffix removed."
  (string-remove-suffix "/A" form))

(defun edgar--amends-target (amendment originals)
  "Return the original filing amended by AMENDMENT from ORIGINALS, or nil."
  (let* ((base-form (edgar--base-form (plist-get amendment :form)))
         (report (plist-get amendment :report))
         (cik (plist-get amendment :cik))
         (filed (plist-get amendment :filed))
         (matches
          (seq-filter
           (lambda (original)
             (and (equal (plist-get original :form) base-form)
                  (equal (plist-get original :cik) cik)
                  (or (not
                       (and filed (plist-get original :filed)))
                      (not
                       (string< filed (plist-get original :filed))))
                  (or (string-empty-p (or report ""))
                      (equal report (plist-get original :report)))))
           originals)))
    (car
     (sort matches
           (lambda (left right)
             (string<
              (or (plist-get right :filed) "")
              (or (plist-get left :filed) "")))))))

(defun edgar--annotate-amendments (ticker form filings)
  "Add each `/A' entry's original accession in `:amends' to FILINGS.
Only exact `/A' queries are annotated.  TICKER and FORM identify the query."
  (if (not (and (stringp form) (string-suffix-p "/A" form) filings))
      filings
    (let* ((base-form (edgar--base-form form))
           (latest-filed (plist-get (car filings) :filed))
           (originals
            (edgar-filings ticker base-form :until latest-filed)))
      (mapcar
       (lambda (amendment)
         (let ((original (edgar--amends-target amendment originals)))
           (if original
               (plist-put
                (copy-sequence amendment)
                :amends (plist-get original :accn))
             amendment)))
       filings))))

(cl-defun
 edgar-filings (ticker &optional form &key since until)
 "Filings for TICKER as plists, newest first.
Each has :accn :form :filed :report :doc :cik :url.  FORM, if given,
filters on exact form type, e.g. \"10-K\".  SINCE and UNTIL are inclusive
filing-date bounds in YYYY-MM-DD form.  Historical submissions pages are
fetched only when their date range overlaps a supplied bound.  With neither
bound, return the SEC's recent filings only.  Exact `/A' form queries add
:amends with the matched original accession when one is found."
 (when (and since until (string< until since))
   (user-error "SINCE must not be later than UNTIL"))
 (let* ((cik (xbrl-cik ticker))
        (submissions-url "https://data.sec.gov/submissions/")
        (sub (xbrl--get (format "%s%s.json" submissions-url cik)))
        (filings (plist-get sub :filings))
        (recent (plist-get filings :recent))
        (n (string-to-number (substring cik 3)))
        (pages
         (when (or since until)
           (sort (cl-remove-if-not
                  (lambda (page)
                    (edgar--page-in-range-p page since until))
                  (copy-sequence (plist-get filings :files)))
                 (lambda (a b)
                   (string<
                    (or (plist-get b :filingTo) "")
                    (or (plist-get a :filingTo) ""))))))
        (result
         (edgar--filings-from-table recent n form since until)))
   (dolist (page pages)
     (setq result
           (nconc
            result
            (edgar--filings-from-table
             (xbrl--get
              (concat submissions-url (plist-get page :name)))
             n form since until))))
   (edgar--annotate-amendments
    ticker form (edgar--unique-filings result))))

(defun edgar-latest (ticker form)
  "Newest FORM filing for TICKER, or nil."
  (car (edgar-filings ticker form)))

(provide 'edgar-core)
;;; edgar-core.el ends here
