;;; edgar-13f-dataset-build.el --- Build the cross-filer Form 13F index -*- lexical-binding: t; -*-

;;; Commentary:

;; Build the index behind `edgar-13f-dataset' from the SEC Form 13F data
;; sets.  Rules:
;;
;; - The newest data set's modal PERIODOFREPORT is the current period;
;;   the calendar quarter before it is the prior period.  Filings of both
;;   periods are taken from every data set given, so late filings count.
;; - Per filer and period: the latest 13F-HR/A restatement, else the latest
;;   original 13F-HR, plus NEW HOLDINGS amendments filed after it.  13F-NT
;;   notices carry no holdings and are ignored.
;; - Values are dollars for filings since `edgar-13f--dollar-vintage-date'
;;   and thousands before it.  A filer whose implied prices mostly sit near
;;   1/1000 of each CUSIP's median is flagged as value-suspect; values are
;;   never rescaled silently.
;;
;; The index directory holds summary.eld (periods, securities, filers and
;; slice offsets), by-cusip.eld and by-cik.eld (one readable slice per
;; CUSIP and per filer CIK).

;;; Code:

(require 'cl-lib)
(require 'edgar-13f)
(require 'edgar-dataset)
(require 'seq)
(require 'subr-x)

(defconst edgar-13f-dataset-index-version 1
  "Layout version of the persisted Form 13F index.")

(defconst edgar-13f-dataset--suspect-band '(0.0003 . 0.003)
  "Range of price-to-median ratios read as values reported in thousands.")

(cl-defstruct
 (edgar-13f-dataset--filing
  (:constructor edgar-13f-dataset--filing-create) (:copier nil))
 "One 13F submission from SUBMISSION.tsv and COVERPAGE.tsv."
 accession
 filed
 form
 cik
 period
 kind
 name)

(cl-defstruct
 (edgar-13f-dataset--state
  (:constructor edgar-13f-dataset--state-create) (:copier nil))
 "Accumulators while scanning INFOTABLE.tsv."
 (positions (make-hash-table :size 4000000))
 (ids (make-hash-table :size 100000))
 (next-id 0)
 cusips
 (rows 0))

(defalias 'edgar-13f-dataset-iso-date #'edgar-dataset-iso-date
  "Convert an SEC data-set date such as 31-JUL-2026 to ISO form.")

(defun edgar-13f-dataset-prior-period (period)
  "Return the calendar quarter end before the quarter-end PERIOD."
  (let ((year (string-to-number (substring period 0 4)))
        (month (string-to-number (substring period 5 7))))
    (if (<= month 3)
        (format "%d-12-31" (1- year))
      (let ((prior (* 3 (/ (1- month) 3))))
        (format "%d-%02d-%s"
                year prior
                (if (= prior 3)
                    "31"
                  "30"))))))

(defun edgar-13f-dataset--kind (form amendment-type)
  "Return the holdings kind of FORM with cover-page AMENDMENT-TYPE."
  (cond
   ((not (member form '("13F-HR" "13F-HR/A")))
    nil)
   ((equal amendment-type "NEW HOLDINGS")
    'new-holdings)
   ((equal form "13F-HR/A")
    'restatement)
   (t
    'original)))

(defun edgar-13f-dataset--read-filings (zip)
  "Return the 13F submissions of data-set ZIP."
  (let ((covers (make-hash-table :test #'equal))
        filings)
    (edgar-dataset-map-rows
     zip "COVERPAGE.tsv"
     (lambda (row)
       (puthash
        (edgar-dataset-field row "ACCESSION_NUMBER")
        (cons
         (edgar-dataset-field row "AMENDMENTTYPE")
         (edgar-dataset-field row "FILINGMANAGER_NAME"))
        covers)))
    (edgar-dataset-map-rows
     zip "SUBMISSION.tsv"
     (lambda (row)
       (let* ((accession (edgar-dataset-field row "ACCESSION_NUMBER"))
              (form (edgar-dataset-field row "SUBMISSIONTYPE"))
              (cover (gethash accession covers)))
         (push (edgar-13f-dataset--filing-create
                :accession accession
                :filed
                (edgar-13f-dataset-iso-date
                 (edgar-dataset-field row "FILING_DATE"))
                :form form
                :cik
                (string-to-number (edgar-dataset-field row "CIK"))
                :period
                (edgar-13f-dataset-iso-date
                 (edgar-dataset-field row "PERIODOFREPORT"))
                :kind
                (edgar-13f-dataset--kind form (car cover))
                :name (cdr cover))
               filings))))
    (nreverse filings)))

(defun edgar-13f-dataset--modal-period (filings)
  "Return the most common period of report among FILINGS."
  (let ((counts (make-hash-table :test #'equal))
        best
        (best-count 0))
    (dolist (filing filings)
      (let ((period (edgar-13f-dataset--filing-period filing)))
        (when period
          (puthash period (1+ (gethash period counts 0)) counts))))
    (maphash
     (lambda (period count)
       (when (or (> count best-count)
                 (and (= count best-count) (string< best period)))
         (setq
          best period
          best-count count)))
     counts)
    best))

(defun edgar-13f-dataset--later-p (a b)
  "Return non-nil when filing A was filed after filing B."
  (let ((fa (edgar-13f-dataset--filing-filed a))
        (fb (edgar-13f-dataset--filing-filed b)))
    (or (string< fb fa)
        (and (string= fa fb)
             (string<
              (edgar-13f-dataset--filing-accession b)
              (edgar-13f-dataset--filing-accession a))))))

(defun edgar-13f-dataset--select-group (filings)
  "Return the FILINGS of one filer and period that define its holdings.
The base filing comes first."
  (let* ((of-kind
          (lambda (kind)
            (sort (seq-filter
                   (lambda (filing)
                     (eq
                      (edgar-13f-dataset--filing-kind filing) kind))
                   filings)
                  #'edgar-13f-dataset--later-p)))
         (base
          (car
           (or (funcall of-kind 'restatement)
               (funcall of-kind 'original))))
         (added (nreverse (funcall of-kind 'new-holdings))))
    (if base
        (cons
         base
         (seq-filter
          (lambda (filing)
            (edgar-13f-dataset--later-p filing base))
          added))
      added)))

(defun edgar-13f-dataset-select (filings periods)
  "Select holdings filings among FILINGS for each filer and one of PERIODS.
Return a hash table from (CIK . PERIOD) to the selected filings."
  (let ((groups (make-hash-table :test #'equal))
        (selected (make-hash-table :test #'equal)))
    (dolist (filing filings)
      (when (and (edgar-13f-dataset--filing-kind filing)
                 (member
                  (edgar-13f-dataset--filing-period filing) periods))
        (push filing
              (gethash
               (cons
                (edgar-13f-dataset--filing-cik filing)
                (edgar-13f-dataset--filing-period filing))
               groups))))
    (maphash
     (lambda (key group)
       (puthash key (edgar-13f-dataset--select-group group) selected))
     groups)
    selected))

(defun edgar-13f-dataset--accessions (selected period)
  "Map accession digits of SELECTED filings to [CIK PRIOR-BIT MULTIPLIER].
PRIOR-BIT is 0 for PERIOD and 1 for the prior period."
  (let ((table (make-hash-table :size 40000)))
    (maphash
     (lambda (key filings)
       (dolist (filing filings)
         (puthash
          (string-to-number
           (string-replace
            "-" "" (edgar-13f-dataset--filing-accession filing)))
          (vector
           (car key)
           (if (equal (cdr key) period)
               0
             1)
           (if (string<
                (edgar-13f-dataset--filing-filed filing)
                edgar-13f--dollar-vintage-date)
               1000
             1))
          table)))
     selected)
    table))

;;;; Scanning information tables

(defsubst edgar-13f-dataset--key (id cik put-call prior-bit)
  "Pack ID, CIK, PUT-CALL code and PRIOR-BIT into one fixnum key."
  (+ (ash id 35) (ash cik 3) (ash put-call 1) prior-bit))

(defun edgar-13f-dataset--roles ()
  "Return a vector of field roles for the INFOTABLE columns."
  (let ((roles (make-vector (length edgar-dataset-header) nil)))
    (pcase-dolist (`(,name . ,role)
                   '(("ACCESSION_NUMBER" . accession)
                     ("NAMEOFISSUER" . issuer)
                     ("TITLEOFCLASS" . class)
                     ("CUSIP" . cusip)
                     ("VALUE" . value)
                     ("SSHPRNAMT" . shares)
                     ("SSHPRNAMTTYPE" . type)
                     ("PUTCALL" . put-call)))
      (let ((index (edgar-dataset-column name)))
        (unless index
          (error "EDGAR 13F: INFOTABLE lacks column %s" name))
        (aset roles index role)))
    roles))

(defun edgar-13f-dataset--new-id (state code cusip issuer class)
  "Register security CODE with CUSIP, ISSUER and CLASS bounds in STATE."
  (let ((id (edgar-13f-dataset--state-next-id state)))
    (puthash code id (edgar-13f-dataset--state-ids state))
    (setf (edgar-13f-dataset--state-next-id state) (1+ id))
    (push (vector
           (save-excursion
             (goto-char cusip)
             (upcase (or (edgar-dataset-read-string) "")))
           (edgar-dataset-string issuer) (edgar-dataset-string class))
          (edgar-13f-dataset--state-cusips state))
    id))

(defun edgar-13f-dataset--add
    (state info code cusip issuer class amounts)
  "Add one INFOTABLE row to STATE.
INFO is the filing vector, CODE the CUSIP code, CUSIP, ISSUER and CLASS
field bounds, AMOUNTS a list (SHARES VALUE SH-P PUT-CALL)."
  (pcase-let* ((`(,shares ,value ,sh ,put-call) amounts)
               (id
                (or (gethash
                     code (edgar-13f-dataset--state-ids state))
                    (edgar-13f-dataset--new-id
                     state code cusip issuer class)))
               (key
                (edgar-13f-dataset--key
                 id (aref info 0) put-call (aref info 1)))
               (positions (edgar-13f-dataset--state-positions state))
               (cell (gethash key positions))
               (dollars (* (or value 0) (aref info 2))))
    (setf (edgar-13f-dataset--state-rows state)
          (1+ (edgar-13f-dataset--state-rows state)))
    (if cell
        (progn
          (aset cell 0 (+ (aref cell 0) (or shares 0)))
          (aset cell 1 (+ (aref cell 1) dollars))
          (when sh
            (aset cell 2 t)))
      (puthash key (vector (or shares 0) dollars sh) positions))))

(defun edgar-13f-dataset--scan (zip accessions state)
  "Add the INFOTABLE rows of ZIP whose filing is in ACCESSIONS to STATE."
  (let (roles)
    (edgar-dataset-map-lines
     zip "INFOTABLE.tsv"
     (lambda (_beg _end)
       (unless roles
         (setq roles (edgar-13f-dataset--roles)))
       (let ((col 0)
             (n (length roles))
             info
             code
             cusip
             issuer
             class
             shares
             value
             sh
             (put-call 0)
             (skip nil))
         (while (and (< col n) (not skip))
           (pcase (aref roles col)
             ('accession
              (setq info
                    (gethash (edgar-dataset-read-digits) accessions))
              (setq skip (null info)))
             ('issuer (setq issuer (edgar-dataset-field-bounds)))
             ('class (setq class (edgar-dataset-field-bounds)))
             ('cusip
              (setq
               cusip (point)
               code (edgar-dataset-read-code)))
             ('value (setq value (edgar-dataset-read-integer)))
             ('shares (setq shares (edgar-dataset-read-integer)))
             ('type
              (setq sh (memq (edgar-dataset-read-char) '(?S ?s))))
             ('put-call
              (setq put-call
                    (pcase (edgar-dataset-read-char)
                      ((or ?P ?p) 1)
                      ((or ?C ?c) 2)
                      (_ 0))))
             (_ (edgar-dataset-skip-fields 1)))
           (setq col (1+ col)))
         (when (and info code)
           (edgar-13f-dataset--add
            state
            info
            code
            cusip
            issuer
            class
            (list shares value (and sh t) put-call))))))))

(provide 'edgar-13f-dataset-build)
;;; edgar-13f-dataset-build.el ends here
