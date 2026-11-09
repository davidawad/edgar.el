;;; edgar-nport-dataset-index.el --- Summarize and persist the N-PORT index -*- lexical-binding: t; -*-

;;; Commentary:

;; Last step of the Form N-PORT index build: merge each fund's current
;; and prior position per security and write the index directory read by
;; `edgar-nport-dataset':
;;
;; - summary.eld: periods, funds, attribute table, slice offsets, and the
;;   top securities by change, drop and value.
;; - securities.tsv: one line per security, most widely held first,
;;   addressed by byte position:
;;   TAB CUSIP ISIN TICKER ISSUER TITLE ASSET ISSUER-TYPE FUNDS
;;   PRIOR-FUNDS VALUE PRIOR-VALUE SLICE-BEG SLICE-END.  It is searched as
;;   text, so a lookup never reads every security into Lisp objects.
;; - by-security.eld and by-fund.eld: one readable slice per security and
;;   per fund.  A record is [FUND BALANCE VALUE PRIOR-BALANCE PRIOR-VALUE
;;   ATTRIBUTES PRIOR-ATTRIBUTES], nil where the fund reported nothing.
;;
;; `edgar-nport-dataset-build' is the entry point.

;;; Code:

(require 'cl-lib)
(require 'edgar-dataset)
(require 'edgar-nport-dataset-build)
(require 'edgar-nport-dataset-scan)
(require 'seq)

(defconst edgar-nport-dataset--top-count 1000
  "Securities precomputed per sort for unfiltered queries.")

(defun edgar-nport-dataset--buckets (state)
  "Return a vector from security id to the position keys of STATE."
  (let ((buckets
         (make-vector (edgar-nport-dataset--state-next-id state) nil))
        (shift (- (1+ edgar-nport-dataset--fund-bits))))
    (maphash
     (lambda (key _cell)
       (let ((id (ash key shift)))
         (aset buckets id (cons key (aref buckets id)))))
     (edgar-nport-dataset--state-positions state))
    buckets))

(defun edgar-nport-dataset--merge (keys positions)
  "Merge one security's position KEYS into fund records.
POSITIONS maps keys to cells."
  (let ((table (make-hash-table :size (max 8 (length keys))))
        (mask (1- (ash 1 (1+ edgar-nport-dataset--fund-bits))))
        records)
    (dolist (key keys)
      (let* ((info (logand key mask))
             (fund (ash info -1))
             (cell (gethash key positions))
             (slot
              (if (= 0 (logand info 1))
                  1
                3))
             (record (gethash fund table)))
        (unless record
          (setq record (make-vector 7 nil))
          (aset record 0 fund)
          (puthash fund record table)
          (push record records))
        (aset record slot (car cell))
        (aset record (1+ slot) (cadr cell))
        (aset record (+ 5 (/ slot 3)) (cddr cell))))
    records))

(defun edgar-nport-dataset--summarize (records totals)
  "Return [FUNDS PRIOR-FUNDS VALUE PRIOR-VALUE] for fund RECORDS.
Per-fund TOTALS [HOLDINGS VALUE PRIOR-HOLDINGS PRIOR-VALUE] are updated."
  (let ((summary (make-vector 4 0)))
    (dolist (record records)
      (let ((total (aref totals (aref record 0))))
        (dolist (offset '(0 1))
          (let ((value (aref record (+ 2 (* 2 offset)))))
            (when (aref record (1+ (* 2 offset)))
              (cl-incf (aref summary offset))
              (cl-incf (aref summary (+ 2 offset)) value)
              (cl-incf (aref total (* 2 offset)))
              (cl-incf (aref total (1+ (* 2 offset))) value))))))
    summary))

(defun edgar-nport-dataset--clean (text)
  "Return TEXT with tabs and newlines replaced by spaces, or empty."
  (if text
      (replace-regexp-in-string "[\t\n\r]" " " text t t)
    ""))

(defun edgar-nport-dataset--write-securities
    (file securities summaries slices)
  "Write securities.tsv FILE; return a vector from security id to position.
SECURITIES, SUMMARIES and SLICES are vectors indexed by security id."
  (let* ((count (length securities))
         (order (number-sequence 0 (1- count)))
         (positions (make-vector count nil)))
    (setq order
          (sort order
                (lambda (a b)
                  (let ((sa (aref summaries a))
                        (sb (aref summaries b)))
                    (or (> (aref sa 0) (aref sb 0))
                        (and (= (aref sa 0) (aref sb 0))
                             (> (aref sa 2) (aref sb 2))))))))
    (with-temp-buffer
      (dolist (id order)
        (let ((security (aref securities id))
              (summary (aref summaries id))
              (slice (aref slices id)))
          (aset positions id (position-bytes (point)))
          (insert
           "\t" (mapconcat #'edgar-nport-dataset--clean security "\t")
           (format "\t%d\t%d\t%d\t%d\t%d\t%d\n"
                   (aref summary 0)
                   (aref summary 1)
                   (aref summary 2)
                   (aref summary 3)
                   (car slice)
                   (cdr slice)))))
      (let ((coding-system-for-write 'utf-8-emacs-unix))
        (make-directory (file-name-directory file) t)
        (write-region (point-min) (point-max) file nil 'silent)))
    positions))

(defun edgar-nport-dataset--top (summaries positions key)
  "Return the positions of the top securities by KEY of SUMMARIES.
KEY maps a summary vector to a number; POSITIONS maps ids to positions."
  (let ((ids (number-sequence 0 (1- (length summaries)))))
    (mapcar
     (lambda (id) (aref positions id))
     (seq-take (sort ids
                     (lambda (a b)
                       (> (funcall key (aref summaries a))
                          (funcall key (aref summaries b)))))
               edgar-nport-dataset--top-count))))

(defun edgar-nport-dataset--filing-plist (filing)
  "Return an `edgar-fund-report'-compatible filing plist for FILING."
  (let ((accession (edgar-nport-dataset--filing-accession filing))
        (cik (edgar-nport-dataset--filing-cik filing)))
    (list
     :accn accession
     :form (edgar-nport-dataset--filing-form filing)
     :filed (edgar-nport-dataset--filing-filed filing)
     :report (edgar-nport-dataset--filing-report filing)
     :cik cik
     :doc "primary_doc.xml"
     :url
     (format
      "https://www.sec.gov/Archives/edgar/data/%d/%s/primary_doc.xml"
      cik (string-replace "-" "" accession)))))

(defun edgar-nport-dataset--funds (keys selected totals)
  "Return a vector of fund plists for fund KEYS.
SELECTED maps keys to (CURRENT . PRIOR) filings; TOTALS come from
`edgar-nport-dataset--summarize'."
  (let ((funds (make-vector (length keys) nil)))
    (dotimes (index (length keys))
      (let* ((cell (gethash (aref keys index) selected))
             (current (car cell))
             (prior (cdr cell))
             (latest (or current prior))
             (total (aref totals index)))
        (aset
         funds index
         (list
          :index index
          :registrant-cik (edgar-nport-dataset--filing-cik latest)
          :registrant-name (edgar-nport-dataset--filing-registrant latest)
          :series-id (edgar-nport-dataset--filing-series-id latest)
          :fund-name
          (or (edgar-nport-dataset--filing-series-name latest)
              (edgar-nport-dataset--filing-registrant latest))
          :period (edgar-nport-dataset--filing-report latest)
          :report-date
          (and current (edgar-nport-dataset--filing-report current))
          :prior-report-date
          (and prior (edgar-nport-dataset--filing-report prior))
          :net-assets
          (and current
               (edgar-nport-dataset--filing-net-assets current))
          :prior-net-assets
          (and prior (edgar-nport-dataset--filing-net-assets prior))
          :holdings (aref total 0)
          :value-usd (aref total 1)
          :prior-holdings (aref total 2)
          :prior-value-usd (aref total 3)
          :filing
          (and current (edgar-nport-dataset--filing-plist current))
          :prior-filing
          (and prior (edgar-nport-dataset--filing-plist prior))))))
    funds))

(defun edgar-nport-dataset--write (directory state context)
  "Write the index for STATE into DIRECTORY.
CONTEXT is a plist with :keys, :selected, :period, :prior-period,
:sources and :timings.  Return the summary plist."
  (let* ((keys (plist-get context :keys))
         (positions (edgar-nport-dataset--state-positions state))
         (buckets (edgar-nport-dataset--buckets state))
         (count (length buckets))
         (summaries (make-vector count nil))
         (totals
          (vconcat (mapcar (lambda (_) (make-vector 4 0)) keys)))
         (holdings (make-vector (length keys) nil))
         (slices
          (edgar-dataset-write-slices
           (expand-file-name "by-security.eld" directory)
           (lambda (emit)
             (dotimes (id count)
               (let ((records
                      (edgar-nport-dataset--merge
                       (aref buckets id) positions)))
                 (aset buckets id nil)
                 (aset
                  summaries id
                  (edgar-nport-dataset--summarize records totals))
                 (dolist (record records)
                   (push
                    (cons id record) (aref holdings (aref record 0))))
                 (funcall emit id records))))))
         (securities
          (let ((table (edgar-nport-dataset--state-securities state))
                (vector (make-vector count nil)))
            (maphash
             (lambda (id security) (aset vector id security)) table)
            vector))
         (lines
          (edgar-nport-dataset--write-securities
           (expand-file-name "securities.tsv" directory)
           securities
           summaries
           (vconcat
            (mapcar
             (lambda (id) (gethash id slices))
             (number-sequence 0 (1- count))))))
         (fund-slices
          (edgar-dataset-write-slices
           (expand-file-name "by-fund.eld" directory)
           (lambda (emit)
             (dotimes (fund (length holdings))
               (funcall emit
                        fund
                        (mapcar
                         (lambda (entry)
                           (cons
                            (aref lines (car entry)) (cdr entry)))
                         (aref holdings fund)))))))
         (attributes nil)
         (summary nil))
    (maphash
     (lambda (code strings)
       (push (cons code strings) attributes))
     (edgar-nport-dataset--state-attributes state))
    (setq
     summary
     (list
      :version edgar-nport-dataset-index-version
      :period (plist-get context :period)
      :prior-period (plist-get context :prior-period)
      :sources (plist-get context :sources)
      :rows (edgar-nport-dataset--state-rows state)
      :unconverted-rows (edgar-nport-dataset--state-unconverted state)
      :securities count
      :timings (plist-get context :timings)
      :funds
      (edgar-nport-dataset--funds
       keys
       (plist-get context :selected) totals)
      :fund-slices fund-slices
      :attributes attributes
      :top-change
      (edgar-nport-dataset--top
       summaries lines
       (lambda (s) (- (aref s 0) (aref s 1))))
      :top-drop
      (edgar-nport-dataset--top
       summaries lines
       (lambda (s) (- (aref s 1) (aref s 0))))
      :top-value
      (edgar-nport-dataset--top
       summaries lines (lambda (s) (aref s 2)))))
    (edgar-dataset-write-object
     (expand-file-name "summary.eld" directory) summary)
    summary))

(defun edgar-nport-dataset-index-directory (sources)
  "Return the index directory for data-set SOURCES."
  (edgar-dataset-index-directory
   "nport" sources edgar-nport-dataset-index-version))

(defun edgar-nport-dataset-build (sources)
  "Build the Form N-PORT index from SOURCES unless it is cached.
SOURCES are data-set ZIP URLs or files, newest first.  Return the index
directory, whose summary.eld is written last."
  (let ((directory (edgar-nport-dataset-index-directory sources)))
    (unless (file-exists-p (expand-file-name "summary.eld" directory))
      (let* ((gc-cons-threshold
              (max gc-cons-threshold (* 1024 1024 1024)))
             (clock (float-time))
             (timings nil)
             (lap
              (lambda (name)
                (push (cons name (- (float-time) clock)) timings)
                (setq clock (float-time))))
             (zips (mapcar #'edgar-dataset-download sources))
             (_ (funcall lap 'download))
             (filings
              (mapcar #'edgar-nport-dataset--read-filings zips))
             (period
              (edgar-nport-dataset--modal-report (car filings)))
             (month (edgar-nport-dataset--month period))
             (selected
              (edgar-nport-dataset-select
               (apply #'append filings) month))
             (keys
              (vconcat (sort (hash-table-keys selected) #'string<)))
             (accessions
              (edgar-nport-dataset--accessions keys selected))
             (state (edgar-nport-dataset--state-create)))
        (when (>= (length keys)
                  (ash 1 edgar-nport-dataset--fund-bits))
          (error "EDGAR N-PORT: too many funds (%d)" (length keys)))
        (funcall lap 'submissions)
        (dolist (zip zips)
          (edgar-nport-dataset--scan zip accessions state))
        (funcall lap 'holdings)
        (edgar-nport-dataset--write
         directory state
         (list
          :keys keys
          :selected selected
          :period period
          :prior-period
          (edgar-nport-dataset-month-end (- month 3))
          :sources sources
          :timings (reverse timings)))))
    directory))

(provide 'edgar-nport-dataset-index)
;;; edgar-nport-dataset-index.el ends here
