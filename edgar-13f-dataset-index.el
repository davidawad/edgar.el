;;; edgar-13f-dataset-index.el --- Summarize and persist the Form 13F index -*- lexical-binding: t; -*-

;;; Commentary:

;; Second half of the Form 13F index build: merge each filer's current
;; and prior position per CUSIP, flag value-suspect filers, and write the
;; index directory read by `edgar-13f-dataset'.  `edgar-13f-dataset-build'
;; is the entry point.

;;; Code:

(require 'cl-lib)
(require 'edgar-13f-dataset-build)
(require 'edgar-dataset)

(defsubst edgar-13f-dataset--key-cik (key)
  "Return the filer CIK packed in KEY."
  (logand (ash key -3) #xFFFFFFFF))

(defsubst edgar-13f-dataset--key-put-call (key)
  "Return the put/call code packed in KEY: 0 none, 1 put, 2 call."
  (logand (ash key -1) 3))

(defun edgar-13f-dataset--buckets (state)
  "Return a vector from security id to the position keys of STATE."
  (let ((buckets
         (make-vector (edgar-13f-dataset--state-next-id state) nil)))
    (maphash
     (lambda (key _cell)
       (let ((id (ash key -35)))
         (aset buckets id (cons key (aref buckets id)))))
     (edgar-13f-dataset--state-positions state))
    buckets))

(defun edgar-13f-dataset--price (key cell)
  "Return the implied share price of the share position KEY with CELL."
  (let ((shares (aref cell 0))
        (value (aref cell 1)))
    (and (= 0 (edgar-13f-dataset--key-put-call key))
         (aref cell 2)
         (> shares 0)
         (> value 0)
         (/ (float value) shares))))

(defun edgar-13f-dataset--median (prices)
  "Return the median of PRICES, or nil for fewer than three prices."
  (and (>= (length prices) 3)
       (nth (/ (length prices) 2) (sort prices #'<))))

(defun edgar-13f-dataset--vote (votes keys positions)
  "Add to VOTES each filer's price comparisons for one security's KEYS.
POSITIONS maps keys to cells."
  (let ((prices (vector nil nil)))
    (dolist (key keys)
      (let ((price
             (edgar-13f-dataset--price key (gethash key positions))))
        (when price
          (push price (aref prices (logand key 1))))))
    (let ((medians
           (vector
            (edgar-13f-dataset--median (aref prices 0))
            (edgar-13f-dataset--median (aref prices 1)))))
      (dolist (key keys)
        (let* ((bit (logand key 1))
               (median (aref medians bit))
               (price
                (and median
                     (edgar-13f-dataset--price
                      key (gethash key positions)))))
          (when price
            (let* ((voter
                    (+ (* 2 (edgar-13f-dataset--key-cik key)) bit))
                   (vote
                    (or (gethash voter votes)
                        (puthash voter (cons 0 0) votes)))
                   (ratio (/ price median)))
              (setcdr vote (1+ (cdr vote)))
              (when (< (car edgar-13f-dataset--suspect-band)
                       ratio
                       (cdr edgar-13f-dataset--suspect-band))
                (setcar vote (1+ (car vote)))))))))))

(defun edgar-13f-dataset--suspects (buckets positions)
  "Return a table of value-suspect filers from BUCKETS and POSITIONS.
Keys are 2*CIK for the current period and 2*CIK+1 for the prior one."
  (let ((votes (make-hash-table :size 40000))
        (suspects (make-hash-table)))
    (dotimes (id (length buckets))
      (edgar-13f-dataset--vote votes (aref buckets id) positions))
    (maphash
     (lambda (voter vote)
       (when (> (* 2 (car vote)) (cdr vote))
         (puthash voter t suspects)))
     votes)
    suspects))

(defun edgar-13f-dataset--merge (keys positions)
  "Merge one security's KEYS into records.
Each record is [CIK PUT-CALL SHARES VALUE PRIOR-SHARES PRIOR-VALUE], nil
where the filer reported nothing.  POSITIONS maps keys to cells."
  (let ((table (make-hash-table :size (max 8 (length keys))))
        records)
    (dolist (key keys)
      (let* ((cik (edgar-13f-dataset--key-cik key))
             (put-call (edgar-13f-dataset--key-put-call key))
             (merged (+ (* 4 cik) put-call))
             (cell (gethash key positions))
             (slot
              (if (= 0 (logand key 1))
                  2
                4))
             (record (gethash merged table)))
        (unless record
          (setq record (vector cik put-call nil nil nil nil))
          (puthash merged record table)
          (push record records))
        (aset record slot (aref cell 0))
        (aset record (1+ slot) (aref cell 1))))
    records))

(defun edgar-13f-dataset--add-total (totals cik offset value adjusted)
  "Count one position of CIK worth VALUE and ADJUSTED in TOTALS at OFFSET."
  (let ((total
         (or (gethash cik totals)
             (puthash cik (make-vector 6 0) totals))))
    (aset total offset (1+ (aref total offset)))
    (aset total (+ offset 1) (+ (aref total (+ offset 1)) value))
    (aset total (+ offset 2) (+ (aref total (+ offset 2)) adjusted))))

(defun edgar-13f-dataset--summarize (security records suspects totals)
  "Return the summary vector of SECURITY with holder RECORDS.
SUSPECTS flags filers; per-filer TOTALS are updated.  The vector is
[CUSIP ISSUER CLASS HOLDERS PRIOR-HOLDERS SHARES VALUE ADJUSTED SUSPECT
PRIOR-SHARES PRIOR-VALUE]; option rows are not counted."
  (let ((holders 0)
        (prior-holders 0)
        (shares 0)
        (value 0)
        (adjusted 0)
        (suspect nil)
        (prior-shares 0)
        (prior-value 0))
    (dolist (record records)
      (when (= 0 (aref record 1))
        (let* ((cik (aref record 0))
               (current (aref record 2))
               (prior (aref record 4)))
          (when current
            (let* ((dollars (aref record 3))
                   (flag (gethash (* 2 cik) suspects))
                   (fixed
                    (if flag
                        (* 1000 dollars)
                      dollars)))
              (cl-incf holders)
              (cl-incf shares current)
              (cl-incf value dollars)
              (cl-incf adjusted fixed)
              (when flag
                (setq suspect t))
              (edgar-13f-dataset--add-total
               totals cik 0 dollars fixed)))
          (when prior
            (let ((dollars (aref record 5)))
              (cl-incf prior-holders)
              (cl-incf prior-shares prior)
              (cl-incf prior-value dollars)
              (edgar-13f-dataset--add-total
               totals cik 3 dollars
               (if (gethash (1+ (* 2 cik)) suspects)
                   (* 1000 dollars)
                 dollars)))))))
    (setq suspect
          (and suspect
               (> adjusted 0)
               (> (/ (float (- adjusted value)) adjusted) 0.01)))
    (vector
     (aref security 0)
     (aref security 1)
     (aref security 2)
     holders
     prior-holders
     shares
     value
     adjusted
     suspect
     prior-shares
     prior-value)))

(defun edgar-13f-dataset--filing-plist (filing)
  "Return an `edgar-13f-holdings'-compatible plist for FILING."
  (list
   :accn (edgar-13f-dataset--filing-accession filing)
   :form (edgar-13f-dataset--filing-form filing)
   :filed (edgar-13f-dataset--filing-filed filing)
   :report (edgar-13f-dataset--filing-period filing)
   :cik (edgar-13f-dataset--filing-cik filing)))

(defun edgar-13f-dataset--filers
    (selected period prior suspects totals)
  "Return a vector of filer plists from SELECTED filings.
PERIOD and PRIOR are the periods; SUSPECTS and TOTALS come from the scan."
  (let ((ciks
         (delete-dups (mapcar #'car (hash-table-keys selected)))))
    (vconcat
     (mapcar
      (lambda (cik)
        (let* ((current (gethash (cons cik period) selected))
               (before (gethash (cons cik prior) selected))
               (total (or (gethash cik totals) (make-vector 6 0)))
               (name
                (seq-some
                 #'edgar-13f-dataset--filing-name
                 (append current before))))
          (list
           :cik cik
           :name name
           :period
           (if current
               period
             prior)
           :positions (aref total 0)
           :value-usd (aref total 1)
           :value-usd-adjusted (aref total 2)
           :value-suspect (and (gethash (* 2 cik) suspects) t)
           :prior-positions (aref total 3)
           :prior-value-usd (aref total 4)
           :prior-value-usd-adjusted (aref total 5)
           :prior-value-suspect (and (gethash (1+ (* 2 cik)) suspects) t)
           :filings (mapcar #'edgar-13f-dataset--filing-plist current)
           :prior-filings (mapcar #'edgar-13f-dataset--filing-plist before))))
      (sort ciks #'<)))))

(defun edgar-13f-dataset--write (directory state context)
  "Write the index for STATE into DIRECTORY.
CONTEXT is a plist with :selected, :period, :prior-period, :sources and
:timings.  Return the summary plist."
  (let* ((positions (edgar-13f-dataset--state-positions state))
         (buckets (edgar-13f-dataset--buckets state))
         (suspects (edgar-13f-dataset--suspects buckets positions))
         (cusips
          (vconcat
           (nreverse (edgar-13f-dataset--state-cusips state))))
         (securities (make-vector (length cusips) nil))
         (holdings (make-hash-table :size 20000))
         (totals (make-hash-table :size 20000))
         (cusip-slices
          (edgar-dataset-write-slices
           (expand-file-name "by-cusip.eld" directory)
           (lambda (emit)
             (dotimes (id (length cusips))
               (let ((records
                      (edgar-13f-dataset--merge
                       (aref buckets id) positions)))
                 (aset buckets id nil)
                 (aset
                  securities id
                  (edgar-13f-dataset--summarize
                   (aref cusips id) records suspects totals))
                 (dolist (record records)
                   (push (cons id record)
                         (gethash (aref record 0) holdings)))
                 (funcall emit id records))))))
         (cik-slices
          (edgar-dataset-write-slices
           (expand-file-name "by-cik.eld" directory)
           (lambda (emit) (maphash emit holdings))))
         (summary
          (list
           :version edgar-13f-dataset-index-version
           :period (plist-get context :period)
           :prior-period (plist-get context :prior-period)
           :sources (plist-get context :sources)
           :rows (edgar-13f-dataset--state-rows state)
           :timings (plist-get context :timings)
           :securities securities
           :filers
           (edgar-13f-dataset--filers
            (plist-get context :selected)
            (plist-get context :period)
            (plist-get context :prior-period) suspects totals)
           :cusip-slices cusip-slices
           :cik-slices cik-slices)))
    (edgar-dataset-write-object
     (expand-file-name "summary.eld" directory) summary)
    summary))

(defun edgar-13f-dataset-index-directory (sources)
  "Return the index directory for data-set SOURCES."
  (edgar-dataset-index-directory
   "form13f" sources edgar-13f-dataset-index-version))

(defun edgar-13f-dataset-build (sources)
  "Build the Form 13F index from SOURCES unless it is cached.
SOURCES are data-set ZIP URLs or files, newest first.  Return the index
directory, whose summary.eld is written last."
  (let* ((directory (edgar-13f-dataset-index-directory sources)))
    (unless (file-exists-p (expand-file-name "summary.eld" directory))
      (let* ((gc-cons-threshold
              (max gc-cons-threshold (* 512 1024 1024)))
             (clock (float-time))
             (timings nil)
             (lap
              (lambda (name)
                (push (cons name (- (float-time) clock)) timings)
                (setq clock (float-time))))
             (zips (mapcar #'edgar-dataset-download sources))
             (_ (funcall lap 'download))
             (filings (mapcar #'edgar-13f-dataset--read-filings zips))
             (period (edgar-13f-dataset--modal-period (car filings)))
             (prior (edgar-13f-dataset-prior-period period))
             (selected
              (edgar-13f-dataset-select
               (apply #'append filings) (list period prior)))
             (accessions
              (edgar-13f-dataset--accessions selected period))
             (state (edgar-13f-dataset--state-create)))
        (funcall lap 'submissions)
        (dolist (zip zips)
          (edgar-13f-dataset--scan zip accessions state))
        (funcall lap 'infotable)
        (edgar-13f-dataset--write
         directory state
         (list
          :selected selected
          :period period
          :prior-period prior
          :sources sources
          :timings (reverse timings)))))
    directory))

(provide 'edgar-13f-dataset-index)
;;; edgar-13f-dataset-index.el ends here
