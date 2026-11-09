;;; edgar-13f-dataset.el --- Holders and portfolios across all 13F filers -*- lexical-binding: t; -*-

;;; Commentary:

;; Answer "which managers hold security X" and "what does manager Y hold"
;; across every Form 13F filer, from the SEC Form 13F data sets.
;;
;;   (edgar-13f-index-async (lambda (index _err) ...)) ; build without blocking
;;   (edgar-13f-securities :query "NVIDIA" :sort 'holders :top 10)
;;   (edgar-13f-holders "67066G104")
;;   (edgar-13f-filers "bridgewater")
;;   (edgar-13f-portfolio 1350694)
;;
;; The index is built from the newest two data sets (see
;; `edgar-13f-dataset-build' for the rules) and cached on disk under
;; `edgar-dataset-cache-directory', keyed by the data-set URLs.  Holder
;; counts are distinct filer CIKs and exclude put/call rows, which are
;; returned separately under :options.  Values are USD; :value-suspect
;; marks filers that appear to report thousands, and :value-usd-adjusted
;; multiplies their values by 1000.

;;; Code:

(require 'cl-lib)
(require 'edgar-dataset)
(require 'edgar-13f-dataset-index)
(require 'seq)
(require 'subr-x)

(defcustom edgar-13f-dataset-page-url
  "https://www.sec.gov/data-research/sec-markets-data/form-13f-data-sets"
  "SEC page that links the Form 13F data-set ZIPs."
  :type 'string
  :group 'edgar-dataset)

(defcustom edgar-13f-dataset-sources nil
  "Data-set ZIP URLs or files to index, newest first.
When nil, the newest two data sets on `edgar-13f-dataset-page-url' are
used."
  :type '(repeat string)
  :group 'edgar-dataset)

(defvar edgar-13f-dataset--index nil
  "The loaded index summary plist, or nil.")

(defconst edgar-13f-dataset--statuses
  '(new added reduced unchanged exited)
  "Position statuses, in display order.")

;;;; Choosing and loading the index

(defun edgar-13f-dataset--end-date (url)
  "Return the last filing date covered by data-set URL, or nil."
  (let ((name (file-name-nondirectory url)))
    (cond
     ((string-match
       "-\\([0-9]\\{2\\}[a-z]\\{3\\}[0-9]\\{4\\}\\)_" name)
      (let ((text (match-string 1 name)))
        (edgar-13f-dataset-iso-date
         (format "%s-%s-%s"
                 (substring text 0 2)
                 (substring text 2 5)
                 (substring text 5)))))
     ((string-match "\\([0-9]\\{4\\}\\)q\\([1-4]\\)_" name)
      (format "%s-%s"
              (match-string 1 name)
              (nth
               (1- (string-to-number (match-string 2 name)))
               '("03-31" "06-30" "09-30" "12-31")))))))

(defun edgar-13f-dataset-latest-sources (&optional count)
  "Return the newest COUNT (default 2) data-set URLs, newest first."
  (let ((urls (edgar-dataset-zip-urls edgar-13f-dataset-page-url)))
    (seq-take (seq-sort-by
               (lambda (url)
                 (or (edgar-13f-dataset--end-date url) ""))
               (lambda (a b) (string< b a)) urls)
              (or count 2))))

(defun edgar-13f-dataset--sources ()
  "Return the data-set sources to index."
  (or edgar-13f-dataset-sources (edgar-13f-dataset-latest-sources)))

(defun edgar-13f-dataset-build-latest (&optional sources)
  "Build the index for SOURCES or the current sources; return its directory."
  (edgar-13f-dataset-build (or sources (edgar-13f-dataset--sources))))

(defun edgar-13f-dataset--load (directory)
  "Load the index summary in DIRECTORY and make it current."
  (let* ((summary
          (edgar-dataset-read-object
           (expand-file-name "summary.eld" directory)))
         (securities (plist-get summary :securities))
         (by-cusip
          (make-hash-table :test #'equal :size (length securities)))
         (by-cik
          (make-hash-table
           :size (length (plist-get summary :filers)))))
    (dotimes (id (length securities))
      (puthash (aref (aref securities id) 0) id by-cusip))
    (seq-doseq (filer (plist-get summary :filers))
      (puthash (plist-get filer :cik) filer by-cik))
    (setq edgar-13f-dataset--index
          (append
           (list
            :directory directory
            :cusip-ids by-cusip
            :filer-table by-cik)
           summary))))

(defun edgar-13f-index (&optional sources)
  "Build or load the Form 13F index for SOURCES synchronously; return it.
SOURCES default to `edgar-13f-dataset-sources' or the newest two data
sets.  A cold build blocks for minutes; prefer `edgar-13f-index-async'
interactively."
  (edgar-13f-dataset--load (edgar-13f-dataset-build-latest sources)))

(defun edgar-13f-index-async (callback &optional sources)
  "Build or load the Form 13F index without blocking, then call CALLBACK.
CALLBACK receives (INDEX nil) on success and (nil ERROR-MESSAGE) on
failure.  The build runs in a batch Emacs subprocess; a cached index for
explicit SOURCES (or `edgar-13f-dataset-sources') loads directly.
Return the subprocess, or nil when no subprocess was needed."
  (let* ((sources (or sources edgar-13f-dataset-sources))
         (directory
          (and sources (edgar-13f-dataset-index-directory sources))))
    (if (and directory
             (file-exists-p
              (expand-file-name "summary.eld" directory)))
        (progn
          (run-at-time
           0 nil
           (lambda ()
             (funcall callback
                      (edgar-13f-dataset--load directory)
                      nil)))
          nil)
      (edgar-dataset-batch
       'edgar-13f-dataset-build-latest (list sources)
       (lambda (result error)
         (if error
             (funcall callback nil error)
           (funcall callback (edgar-13f-dataset--load result) nil)))
       :features '(edgar-13f-dataset)
       :variables
       '(edgar-dataset-cache-directory
         edgar-unzip-program edgar-13f-dataset-page-url)
       :name "edgar-13f-index"))))

(defun edgar-13f-dataset--current ()
  "Return the loaded index, loading or building it synchronously if needed."
  (or edgar-13f-dataset--index (edgar-13f-index)))

(defun edgar-13f-dataset--slice (index kind key)
  "Read the KIND slice (cusip or cik) for KEY from INDEX, or nil."
  (let ((bounds
         (gethash
          key
          (plist-get
           index (if (eq kind 'cusip) :cusip-slices :cik-slices)))))
    (and bounds
         (edgar-dataset-read-object
          (expand-file-name (if (eq kind 'cusip)
                                "by-cusip.eld"
                              "by-cik.eld")
                            (plist-get index :directory))
          bounds))))

;;;; Rows

(defun edgar-13f-dataset--status (shares prior-shares)
  "Return the status of a position with SHARES now and PRIOR-SHARES before."
  (cond
   ((null prior-shares)
    'new)
   ((null shares)
    'exited)
   ((> shares prior-shares)
    'added)
   ((< shares prior-shares)
    'reduced)
   (t
    'unchanged)))

(defun edgar-13f-dataset--position (record filer)
  "Return the plist for holder RECORD of FILER's filer plist."
  (let* ((shares (aref record 2))
         (value (aref record 3))
         (prior-shares (aref record 4))
         (suspect (plist-get filer :value-suspect)))
    (list
     :shares shares
     :value-usd value
     :value-usd-adjusted
     (and value
          (if suspect
              (* 1000 value)
            value))
     :prior-shares prior-shares
     :prior-value-usd (aref record 5)
     :status (edgar-13f-dataset--status shares prior-shares)
     :value-suspect
     (and (or (and shares suspect)
              (and prior-shares
                   (plist-get filer :prior-value-suspect)))
          t)
     :put-call
     (pcase (aref record 1)
       (1 "Put")
       (2 "Call")))))

(defun edgar-13f-dataset--security-row (security)
  "Return the plist for SECURITY summary vector."
  (list
   :cusip (aref security 0)
   :issuer (aref security 1)
   :class (aref security 2)
   :holders (aref security 3)
   :prior-holders (aref security 4)
   :change (- (aref security 3) (aref security 4))
   :shares (aref security 5)
   :value-usd (aref security 6)
   :value-usd-adjusted (aref security 7)
   :value-suspect (aref security 8)
   :prior-shares (aref security 9)
   :prior-value-usd (aref security 10)))

(defun edgar-13f-dataset--by-value (rows)
  "Sort ROWS by current value, then exited rows by prior value."
  (sort rows
        (lambda (a b)
          (let ((va (plist-get a :value-usd))
                (vb (plist-get b :value-usd)))
            (cond
             ((and va vb)
              (> va vb))
             (va
              t)
             (vb
              nil)
             (t
              (> (or (plist-get a :prior-value-usd) 0)
                 (or (plist-get b :prior-value-usd) 0))))))))

(defun edgar-13f-dataset--counts (rows)
  "Return a plist counting ROWS per status."
  (cl-loop
   for status in edgar-13f-dataset--statuses append
   (list
    (intern (format ":%s" status))
    (cl-count
     status
     rows
     :key (lambda (row) (plist-get row :status))))))

(defun edgar-13f-dataset--split-options (rows)
  "Return (SHARE-ROWS . OPTION-ROWS) of ROWS."
  (let (shares
        options)
    (dolist (row rows)
      (if (plist-get row :put-call)
          (push row options)
        (push row shares)))
    (cons
     (edgar-13f-dataset--by-value shares)
     (edgar-13f-dataset--by-value options))))

;;;; Public queries

(cl-defun
 edgar-13f-securities (&key query sort top)
 "Return securities held by 13F filers, with holder counts.
QUERY matches a CUSIP prefix or an issuer substring, case-insensitively.
SORT is `holders' (default), `change', `drop' or `value'; TOP limits rows.
Return (:period P :prior-period P :rows ROWS); each row has :cusip
:issuer :class :holders :prior-holders :change :shares :value-usd
:value-usd-adjusted :value-suspect :prior-shares :prior-value-usd."
 (let* ((index (edgar-13f-dataset--current))
        (needle (and query (upcase query)))
        (rows nil))
   (seq-doseq (security (plist-get index :securities))
     (when (and (or (> (aref security 3) 0) (> (aref security 4) 0))
                (or (null needle)
                    (string-prefix-p needle (aref security 0))
                    (and (aref security 1)
                         (string-search
                          needle (upcase (aref security 1))))))
       (push (edgar-13f-dataset--security-row security) rows)))
   (let ((key
          (pcase (or sort 'holders)
            ('holders (lambda (row) (plist-get row :holders)))
            ('change (lambda (row) (plist-get row :change)))
            ('drop (lambda (row) (- (plist-get row :change))))
            ('value (lambda (row) (plist-get row :value-usd)))
            (other (error "EDGAR 13F: unknown sort %s" other)))))
     (setq rows
           (sort rows
                 (lambda (a b) (> (funcall key a) (funcall key b))))))
   (list
    :period (plist-get index :period)
    :prior-period (plist-get index :prior-period)
    :rows
    (if top
        (seq-take rows top)
      rows))))

(defun edgar-13f-holders (cusip)
  "Return every 13F filer holding CUSIP now or in the prior period.
Return a plist with :cusip :issuer :class :period :prior-period
:holders :prior-holders :shares :value-usd :value-usd-adjusted
:value-suspect :counts :rows :options, or nil for an unknown CUSIP.
Each row has :cik :name :shares :value-usd :value-usd-adjusted
:prior-shares :prior-value-usd :status :value-suspect :filed-current
:put-call; :filed-current is nil for an exited holder that has not
filed for the current period yet."
  (let* ((index (edgar-13f-dataset--current))
         (id (gethash (upcase cusip) (plist-get index :cusip-ids))))
    (when id
      (let* ((filers (plist-get index :filer-table))
             (period (plist-get index :period))
             (rows
              (mapcar
               (lambda (record)
                 (let ((filer (gethash (aref record 0) filers)))
                   (append
                    (list
                     :cik (aref record 0)
                     :name (plist-get filer :name))
                    (edgar-13f-dataset--position record filer)
                    (list
                     :filed-current
                     (equal (plist-get filer :period) period)))))
               (edgar-13f-dataset--slice index 'cusip id)))
             (split (edgar-13f-dataset--split-options rows))
             (summary
              (edgar-13f-dataset--security-row
               (aref (plist-get index :securities) id))))
        (append
         (list
          :period period
          :prior-period (plist-get index :prior-period))
         summary
         (list
          :counts (edgar-13f-dataset--counts (car split))
          :rows (car split)
          :options (cdr split)))))))

(cl-defun
 edgar-13f-filers (query &key top)
 "Return 13F filers matching QUERY by name, largest first.
A numeric QUERY also matches the CIK.  TOP limits the result.  Each
element has :cik :name :positions :value-usd :value-usd-adjusted
:value-suspect :period."
 (let* ((index (edgar-13f-dataset--current))
        (needle (upcase query))
        (cik
         (and (string-match-p "\\`[0-9]+\\'" query)
              (string-to-number query)))
        rows)
   (seq-doseq (filer (plist-get index :filers))
     (when (or (eql cik (plist-get filer :cik))
               (and (plist-get filer :name)
                    (string-search
                     needle (upcase (plist-get filer :name)))))
       (push
        (list
         :cik (plist-get filer :cik)
         :name (plist-get filer :name)
         :positions (plist-get filer :positions)
         :value-usd (plist-get filer :value-usd)
         :value-usd-adjusted (plist-get filer :value-usd-adjusted)
         :value-suspect (plist-get filer :value-suspect)
         :period (plist-get filer :period))
        rows)))
   (setq rows
         (sort rows
               (lambda (a b)
                 (> (plist-get a :value-usd)
                    (plist-get b :value-usd)))))
   (if top
       (seq-take rows top)
     rows)))

(defun edgar-13f-portfolio (cik)
  "Return the 13F portfolio of filer CIK (a number or string), or nil.
The plist has :cik :name :period :prior-period :accession :filing
:filings :prior-filings :positions :options :counts :current-positions
:prior-positions :value-usd :value-usd-adjusted :prior-value-usd
:value-suspect.  Each position has :cusip :issuer :class plus the
holder fields of `edgar-13f-holders'.  :filing is a filing plist for
`edgar-13f-holdings'.  Counts reconcile: new+added+reduced+unchanged
equals :current-positions and added+reduced+unchanged+exited equals
:prior-positions."
  (let* ((index (edgar-13f-dataset--current))
         (cik
          (if (stringp cik)
              (string-to-number cik)
            cik))
         (filer (gethash cik (plist-get index :filer-table))))
    (when filer
      (let* ((securities (plist-get index :securities))
             (rows
              (mapcar
               (lambda (entry)
                 (let ((security (aref securities (car entry))))
                   (append
                    (list
                     :cusip (aref security 0)
                     :issuer (aref security 1)
                     :class (aref security 2))
                    (edgar-13f-dataset--position (cdr entry) filer))))
               (edgar-13f-dataset--slice index 'cik cik)))
             (split (edgar-13f-dataset--split-options rows))
             (filings (plist-get filer :filings)))
        (list
         :cik cik
         :name (plist-get filer :name)
         :period (plist-get index :period)
         :prior-period (plist-get index :prior-period)
         :accession (plist-get (car filings) :accn)
         :filing (car filings)
         :filings filings
         :prior-filings (plist-get filer :prior-filings)
         :counts (edgar-13f-dataset--counts (car split))
         :current-positions (plist-get filer :positions)
         :prior-positions (plist-get filer :prior-positions)
         :value-usd (plist-get filer :value-usd)
         :value-usd-adjusted (plist-get filer :value-usd-adjusted)
         :prior-value-usd (plist-get filer :prior-value-usd)
         :value-suspect (plist-get filer :value-suspect)
         :positions (car split)
         :options (cdr split))))))

(provide 'edgar-13f-dataset)
;;; edgar-13f-dataset.el ends here
