;;; edgar-nport-dataset-build.el --- Build the cross-fund Form N-PORT index -*- lexical-binding: t; -*-

;;; Commentary:

;; Build the index behind `edgar-nport-dataset' from the SEC Form N-PORT
;; data sets.  Tables read (see the data-set readme, nport_readme.pdf):
;;
;; - SUBMISSION: ACCESSION_NUMBER, FILING_DATE, SUB_TYPE (NPORT-P,
;;   NPORT-P/A; NT NPORT-P notices carry no holdings), REPORT_DATE.
;; - REGISTRANT: CIK, REGISTRANT_NAME.
;; - FUND_REPORTED_INFO: SERIES_NAME, SERIES_ID, NET_ASSETS.
;; - FUND_REPORTED_HOLDING: ISSUER_NAME, ISSUER_TITLE, ISSUER_CUSIP,
;;   BALANCE, UNIT, CURRENCY_CODE, CURRENCY_VALUE, EXCHANGE_RATE,
;;   PAYOFF_PROFILE, ASSET_CAT, ISSUER_TYPE.
;; - IDENTIFIERS: IDENTIFIER_ISIN, IDENTIFIER_TICKER per HOLDING_ID.
;;
;; Rules:
;;
;; - Funds file monthly, but only the report for the last month of each
;;   fiscal quarter is made public, about 60 days later, so a data set
;;   mixes report months.  The newest data set's modal REPORT_DATE is the
;;   current period P; a fund's current report is its latest one dated in
;;   the month before P through the month after it, and its prior report
;;   its latest one dated three months earlier.
;; - A fund is a series (SERIES_ID), or the registrant CIK when a filing
;;   has no series.  Per fund and report month the latest filing wins, so
;;   an NPORT-P/A supersedes its NPORT-P.  Filings come from every data
;;   set given, so late filings count for their month.
;; - A security is its CUSIP, else its ISIN (a US or CA ISIN embeds the
;;   CUSIP), else its issuer name plus title.  Rows of one security in
;;   one fund report are summed.
;; - CURRENCY_VALUE is the value in US dollars (Form N-PORT Item C.2.c;
;;   EXCHANGE_RATE is units of CURRENCY_CODE per dollar).  Rows in a
;;   foreign currency without an exchange rate are flagged.

;;; Code:

(require 'cl-lib)
(require 'edgar-dataset)
(require 'seq)
(require 'subr-x)

(defconst edgar-nport-dataset-index-version 1
  "Layout version of the persisted Form N-PORT index.")

(defconst edgar-nport-dataset--fund-bits 17
  "Bits reserved for the fund index in a position key.")

(cl-defstruct
 (edgar-nport-dataset--filing
  (:constructor edgar-nport-dataset--filing-create) (:copier nil))
 "One N-PORT submission from SUBMISSION, REGISTRANT and FUND_REPORTED_INFO."
 accession
 filed
 form
 report
 month
 cik
 registrant
 series-id
 series-name
 net-assets
 fund)

(cl-defstruct
 (edgar-nport-dataset--state
  (:constructor edgar-nport-dataset--state-create) (:copier nil))
 "Accumulators while scanning FUND_REPORTED_HOLDING."
 (positions (make-hash-table :size 8000000))
 (cusip-ids (make-hash-table :size 800000))
 (isin-ids (make-hash-table :size 800000))
 (name-ids (make-hash-table :test #'equal :size 1000000))
 (strings (make-hash-table :size 4096))
 (categories (make-hash-table :test #'eq))
 (attributes (make-hash-table))
 (next-id 0)
 (securities (make-hash-table :size 2000000))
 (rows 0)
 (unconverted 0))

;;;; Months and periods

(defun edgar-nport-dataset--month (iso)
  "Return the month number of ISO date, counting months from year 0."
  (and iso
       (+ (* 12 (string-to-number (substring iso 0 4)))
          (1- (string-to-number (substring iso 5 7))))))

(defun edgar-nport-dataset-month-end (month)
  "Return the ISO date of the last day of MONTH, a month number."
  (let* ((year (/ month 12))
         (m (1+ (% month 12)))
         (days
          (if (= m 2)
              (if (and (= 0 (% year 4))
                       (or (/= 0 (% year 100)) (= 0 (% year 400))))
                  29
                28)
            (nth (1- m) '(31 28 31 30 31 30 31 31 30 31 30 31)))))
    (format "%04d-%02d-%02d" year m days)))

(defun edgar-nport-dataset--modal-report (filings)
  "Return the most common report date among FILINGS, later on a tie."
  (let ((counts (make-hash-table :test #'equal))
        best
        (best-count 0))
    (dolist (filing filings)
      (let ((report (edgar-nport-dataset--filing-report filing)))
        (when report
          (puthash report (1+ (gethash report counts 0)) counts))))
    (maphash
     (lambda (report count)
       (when (or (> count best-count)
                 (and (= count best-count) (string< best report)))
         (setq
          best report
          best-count count)))
     counts)
    best))

;;;; Filings

(defun edgar-nport-dataset--table (zip member columns)
  "Map ACCESSION_NUMBER to a list of COLUMNS fields of MEMBER of ZIP."
  (let ((table (make-hash-table :test #'equal :size 20000)))
    (edgar-dataset-map-rows
     zip member
     (lambda (row)
       (puthash
        (edgar-dataset-field row "ACCESSION_NUMBER")
        (mapcar
         (lambda (name) (edgar-dataset-field row name)) columns)
        table)))
    table))

(defun edgar-nport-dataset--read-filings (zip)
  "Return the NPORT-P and NPORT-P/A submissions of data-set ZIP."
  (let ((registrants
         (edgar-nport-dataset--table
          zip "REGISTRANT.tsv" '("CIK" "REGISTRANT_NAME")))
        (funds
         (edgar-nport-dataset--table
          zip
          "FUND_REPORTED_INFO.tsv"
          '("SERIES_NAME" "SERIES_ID" "NET_ASSETS")))
        filings)
    (edgar-dataset-map-rows
     zip "SUBMISSION.tsv"
     (lambda (row)
       (let* ((accession (edgar-dataset-field row "ACCESSION_NUMBER"))
              (form (edgar-dataset-field row "SUB_TYPE"))
              (report
               (edgar-dataset-iso-date
                (edgar-dataset-field row "REPORT_DATE")))
              (registrant (gethash accession registrants))
              (fund (gethash accession funds))
              (cik (string-to-number (or (car registrant) "0")))
              (series (nth 1 fund)))
         (when (and report
                    (> cik 0)
                    (member form '("NPORT-P" "NPORT-P/A")))
           (push (edgar-nport-dataset--filing-create
                  :accession accession
                  :filed
                  (edgar-dataset-iso-date
                   (edgar-dataset-field row "FILING_DATE"))
                  :form form
                  :report report
                  :month
                  (edgar-nport-dataset--month report)
                  :cik cik
                  :registrant
                  (nth 1 registrant)
                  :series-id series
                  :series-name (car fund)
                  :net-assets
                  (and (nth 2 fund)
                       (round (string-to-number (nth 2 fund))))
                  :fund
                  (or series (format "CIK%010d" cik)))
                 filings)))))
    (nreverse filings)))

(defun edgar-nport-dataset--later-p (a b)
  "Return non-nil when filing A supersedes filing B."
  (let ((fa (or (edgar-nport-dataset--filing-filed a) ""))
        (fb (or (edgar-nport-dataset--filing-filed b) "")))
    (or (string< fb fa)
        (and (string= fa fb)
             (string<
              (edgar-nport-dataset--filing-accession b)
              (edgar-nport-dataset--filing-accession a))))))

(defun edgar-nport-dataset-select (filings month)
  "Select each fund's current and prior report among FILINGS.
MONTH is the current period's month number.  Return a hash table from
fund key to (CURRENT . PRIOR) filings, either of which may be nil."
  (let ((latest (make-hash-table :test #'equal))
        (selected (make-hash-table :test #'equal)))
    (dolist (filing filings)
      (let* ((key
              (cons
               (edgar-nport-dataset--filing-fund filing)
               (edgar-nport-dataset--filing-month filing)))
             (best (gethash key latest)))
        (when (or (null best)
                  (edgar-nport-dataset--later-p filing best))
          (puthash key filing latest))))
    (maphash
     (lambda (key filing)
       (let* ((offset (- month (cdr key)))
              (slot
               (cond
                ((<= -1 offset 1)
                 'current)
                ((<= 2 offset 4)
                 'prior))))
         (when slot
           (let* ((cell
                   (or (gethash (car key) selected)
                       (puthash (car key) (cons nil nil) selected)))
                  (old
                   (if (eq slot 'current)
                       (car cell)
                     (cdr cell))))
             (when (or (null old)
                       (> (edgar-nport-dataset--filing-month filing)
                          (edgar-nport-dataset--filing-month old)))
               (if (eq slot 'current)
                   (setcar cell filing)
                 (setcdr cell filing)))))))
     latest)
    selected))

(defun edgar-nport-dataset--accessions (funds selected)
  "Map accession digits of SELECTED filings to FUND*2+PRIOR-BIT.
FUNDS is the vector of fund keys in index order."
  (let ((table (make-hash-table :size 40000)))
    (dotimes (fund (length funds))
      (let ((cell (gethash (aref funds fund) selected)))
        (cl-loop
         for
         filing
         in
         (list (car cell) (cdr cell))
         for
         bit
         from
         0
         when
         filing
         do
         (puthash
          (string-to-number
           (string-replace
            "-" "" (edgar-nport-dataset--filing-accession filing)))
          (+ (* 2 fund) bit) table))))
    table))

;;;; Identifiers

(defun edgar-nport-dataset-isin-string (code)
  "Return the twelve-character ISIN whose first eleven read as CODE.
The check digit is recomputed (Luhn over letters expanded to numbers)."
  (let* ((body (edgar-dataset-code-string code))
         (digits
          (mapconcat (lambda (c)
                       (number-to-string
                        (if (<= ?0 c ?9)
                            (- c ?0)
                          (- c 55))))
                     body
                     ""))
         (sum 0))
    (dotimes (i (length digits))
      (let ((d (- (aref digits (- (length digits) 1 i)) ?0)))
        (when (= 0 (% i 2))
          (setq d (* 2 d)))
        (setq sum (+ sum (/ d 10) (% d 10)))))
    (format "%s%d" body (% (- 10 (% sum 10)) 10))))

(defun edgar-nport-dataset--column-roles (spec)
  "Return a vector of roles for the current member's columns from SPEC.
SPEC is an alist of (COLUMN . ROLE); missing columns signal an error."
  (let ((roles (make-vector (length edgar-dataset-header) nil)))
    (pcase-dolist (`(,name . ,role) spec)
      (let ((index (edgar-dataset-column name)))
        (unless index
          (error "EDGAR N-PORT: missing column %s" name))
        (aset roles index role)))
    (let ((last (cl-position-if-not #'null roles :from-end t)))
      (seq-take roles (1+ last)))))

(defun edgar-nport-dataset--read-identifiers (zip strings)
  "Return (ISINS . TICKERS) tables keyed by HOLDING_ID from ZIP.
ISINS hold eleven-character ISIN codes; TICKERS hold strings shared
through STRINGS."
  (let ((isins (make-hash-table :size 5000000))
        (tickers (make-hash-table :size 1000000))
        roles)
    (edgar-dataset-map-lines
     zip "IDENTIFIERS.tsv"
     (lambda (_beg _end)
       (unless roles
         (setq roles
               (edgar-nport-dataset--column-roles
                '(("HOLDING_ID" . holding)
                  ("IDENTIFIER_ISIN" . isin)
                  ("IDENTIFIER_TICKER" . ticker)))))
       (let (holding)
         (dotimes (col (length roles))
           (pcase (aref roles col)
             ('holding (setq holding (edgar-dataset-read-integer)))
             ('isin
              (let ((isin (edgar-dataset-read-identifier 12 11)))
                (when (and isin holding)
                  (puthash holding isin isins))))
             ('ticker
              (let ((ticker (edgar-dataset-read-interned strings)))
                (when (and ticker holding (not (equal ticker "N/A")))
                  (puthash holding ticker tickers))))
             (_ (edgar-dataset-skip-fields 1)))))))
    (cons isins tickers)))

(provide 'edgar-nport-dataset-build)
;;; edgar-nport-dataset-build.el ends here
