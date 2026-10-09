;;; edgar-index.el --- Enumerate EDGAR filings across all filers -*- lexical-binding: t; -*-

;; Version: 0.1.0
;; Keywords: finance, tools, hypermedia

;;; Commentary:

;; Read the SEC's quarterly and daily form indexes.  Unlike company
;; submissions, these indexes cover every filer, including entities without
;; ticker symbols.
;;
;;   (edgar-index-filings 2026 2 "10-K")
;;   (edgar-daily-index-filings "2026-09-30" "4")

;;; Code:

(require 'cl-lib)
(require 'edgar-http)
(require 'subr-x)
(require 'time-date)
(require 'xbrl)

(defconst edgar-index--archives-base "https://www.sec.gov/Archives/"
  "Base URL for SEC archive paths from form indexes.")

(defun edgar-index--fetch (url)
  "Return the decoded contents of index URL."
  (edgar-http-get url xbrl-user-agent))

(defun edgar-index--quarter-number (quarter)
  "Return QUARTER as an integer from 1 through 4."
  (let ((number
         (cond
          ((integerp quarter)
           quarter)
          ((and (stringp quarter)
                (string-match
                 "\\`QTR\\([1-4]\\)\\'" (upcase quarter)))
           (string-to-number (match-string 1 (upcase quarter)))))))
    (unless (and number (<= 1 number) (<= number 4))
      (user-error "EDGAR index: invalid quarter %S" quarter))
    number))

(defun edgar-index--date-components (date)
  "Return (YEAR MONTH DAY) parsed from ISO DATE.
Signal `user-error' unless DATE is a real calendar date."
  (unless
      (and
       (stringp date)
       (string-match
        "\\`\\([0-9]\\{4\\}\\)-\\([0-9]\\{2\\}\\)-\\([0-9]\\{2\\}\\)\\'"
        date))
    (user-error "EDGAR index: invalid date %S" date))
  (let* ((year (string-to-number (match-string 1 date)))
         (month (string-to-number (match-string 2 date)))
         (day (string-to-number (match-string 3 date)))
         (normalized
          (condition-case nil
              (format-time-string "%Y-%m-%d"
                                  (encode-time 0 0 0 day month year t)
                                  t)
            (error
             nil))))
    (unless (equal normalized date)
      (user-error "EDGAR index: invalid date %S" date))
    (list year month day)))

(defun edgar-index--normalize-date (date)
  "Return index DATE in ISO format."
  (cond
   ((string-match-p
     "\\`[0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}\\'" date)
    date)
   ((string-match
     "\\`\\([0-9]\\{4\\}\\)\\([0-9]\\{2\\}\\)\\([0-9]\\{2\\}\\)\\'"
     date)
    (format "%s-%s-%s"
            (match-string 1 date)
            (match-string 2 date)
            (match-string 3 date)))
   (t
    (error "EDGAR index: invalid filing date %S" date))))

(defun edgar-index--parse-row (line)
  "Parse one fixed-width SEC form-index LINE into a filing plist."
  (when (< (length line) 104)
    (error "EDGAR index: malformed row %S" line))
  (let* ((form (string-trim (substring line 0 17)))
         (company (string-trim (substring line 17 79)))
         (cik-string (string-trim (substring line 79 91)))
         (filed
          (edgar-index--normalize-date
           (string-trim (substring line 91 103))))
         (filename (string-trim (substring line 103)))
         accession)
    (unless
        (and
         (not (string-empty-p form))
         (string-match-p "\\`[0-9]+\\'" cik-string)
         (string-prefix-p "edgar/data/" filename)
         (string-match
          "/\\([0-9]\\{10\\}-[0-9]\\{2\\}-[0-9]\\{6\\}\\)\\.txt\\'"
          filename))
      (error "EDGAR index: malformed row %S" line))
    (setq accession (match-string 1 filename))
    (list
     :accn accession
     :form form
     :company company
     :filed filed
     :report ""
     :doc (file-name-nondirectory filename)
     :cik (string-to-number cik-string)
     :url (concat edgar-index--archives-base filename))))

(defun edgar-index--form-match-p (actual requested)
  "Return non-nil when ACTUAL matches REQUESTED.
A base REQUESTED form also matches its /A amendment; an explicit /A form
matches only that amendment."
  (or (null requested)
      (equal actual requested)
      (and (not (string-suffix-p "/A" requested))
           (equal actual (concat requested "/A")))))

(defun edgar-index--newer-p (left right)
  "Return non-nil when filing LEFT should sort before RIGHT."
  (let ((left-date (plist-get left :filed))
        (right-date (plist-get right :filed)))
    (or (string< right-date left-date)
        (and (equal left-date right-date)
             (string<
              (plist-get right :accn) (plist-get left :accn))))))

(defun edgar-index--parse (text &optional form)
  "Parse SEC form-index TEXT, optionally filtering by FORM.
Results are newest first.  A base FORM includes its /A amendment; passing an
explicit /A form selects amendments only."
  (let (rows)
    (with-temp-buffer
      (insert text)
      (goto-char (point-min))
      (unless (re-search-forward "^-\\{10,\\}[ \t]*\r?$" nil t)
        (error "EDGAR index: missing header separator"))
      (forward-line 1)
      (while (not (eobp))
        (let ((line
               (string-remove-suffix
                "\r"
                (buffer-substring-no-properties
                 (line-beginning-position) (line-end-position)))))
          (unless (string-blank-p line)
            (let ((filing (edgar-index--parse-row line)))
              (when (edgar-index--form-match-p
                     (plist-get filing :form) form)
                (push filing rows)))))
        (forward-line 1)))
    (sort rows #'edgar-index--newer-p)))

(defun edgar-index-filings (year quarter &optional form)
  "Return filings from YEAR and QUARTER across all SEC filers.
QUARTER is 1 through 4 or a string such as \"QTR2\".  FORM, when non-nil,
selects that base form and its /A amendments; an explicit /A form selects
only amendments.  Results are newest first.

Each result has :accn, :form, :company, :filed, :report, :doc, :cik, and
:url.  The index has no primary-document field, so :doc and :url identify
the filing's complete-submission .txt file."
  (unless (and (integerp year) (<= 1994 year))
    (user-error "EDGAR index: invalid year %S" year))
  (let* ((quarter-number (edgar-index--quarter-number quarter))
         (url
          (format "%sedgar/full-index/%d/QTR%d/form.gz"
                  edgar-index--archives-base
                  year
                  quarter-number)))
    (edgar-index--parse (edgar-index--fetch url) form)))

(defun edgar-daily-index-filings (date &optional form)
  "Return filings in the SEC daily form index for ISO DATE.
FORM filtering and result plists follow `edgar-index-filings'."
  (pcase-let* ((`(,year ,month ,_day)
                (edgar-index--date-components date))
               (quarter (1+ (/ (1- month) 3)))
               (compact-date (string-replace "-" "" date))
               (url
                (format "%sedgar/daily-index/%d/QTR%d/form.%s.idx"
                        edgar-index--archives-base
                        year
                        quarter
                        compact-date)))
    (edgar-index--parse (edgar-index--fetch url) form)))

(provide 'edgar-index)
;;; edgar-index.el ends here
