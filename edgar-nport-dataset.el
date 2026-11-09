;;; edgar-nport-dataset.el --- Holders and portfolios across all N-PORT funds -*- lexical-binding: t; -*-

;;; Commentary:

;; Answer "which funds hold security X" for any asset class (equities,
;; corporate, municipal and government bonds, asset-backed securities,
;; loans, derivatives) and "what does fund Y hold", across every
;; registered fund that files Form N-PORT, from the SEC Form N-PORT data
;; sets.  Money market funds file Form N-MFP instead and are not covered.
;;
;;   (edgar-nport-index-async (lambda (index _err) ...)) ; build without blocking
;;   (edgar-nport-holders "037833DX5")                   ; CUSIP, ISIN or ticker
;;   (edgar-nport-securities :query "APPLE" :asset-category "DBT" :top 10)
;;   (edgar-nport-funds "total stock market")
;;   (edgar-nport-portfolio "S000002848")                ; series id or CIK
;;
;; The index is built from the newest two data sets (see
;; `edgar-nport-dataset-build' for the rules) and cached on disk under
;; `edgar-dataset-cache-directory', keyed by the data-set URLs.  Values
;; are US dollars as filed; :pct-of-nav is the value over the fund's net
;; assets.  This file mirrors the shape of `edgar-13f-dataset': rows,
;; :counts by status, and :period / :prior-period.

;;; Code:

(require 'cl-lib)
(require 'edgar-dataset)
(require 'edgar-nport-dataset-index)
(require 'edgar-nport-dataset-rows)
(require 'seq)
(require 'subr-x)

(defcustom edgar-nport-dataset-page-url
  "https://www.sec.gov/data-research/sec-markets-data/form-n-port-data-sets"
  "SEC page that links the Form N-PORT data-set ZIPs."
  :type 'string
  :group 'edgar-dataset)

(defcustom edgar-nport-dataset-sources nil
  "Data-set ZIP URLs or files to index, newest first.
When nil, the newest two data sets on `edgar-nport-dataset-page-url'
are used."
  :type '(repeat string)
  :group 'edgar-dataset)

(defvar edgar-nport-dataset--index nil
  "The loaded index summary plist, or nil.")

;;;; Building and loading the index

(defun edgar-nport-dataset--sources ()
  "Return the data-set sources to index."
  (or edgar-nport-dataset-sources
      (edgar-dataset-latest-urls edgar-nport-dataset-page-url 2)))

(defun edgar-nport-dataset-build-latest (&optional sources)
  "Build the index for SOURCES or the current sources; return its directory."
  (edgar-nport-dataset-build
   (or sources (edgar-nport-dataset--sources))))

(defun edgar-nport-dataset--load (directory)
  "Load the index in DIRECTORY and make it current."
  (let* ((summary
          (edgar-dataset-read-object
           (expand-file-name "summary.eld" directory)))
         (funds (plist-get summary :funds))
         (series (make-hash-table :test #'equal))
         (ciks (make-hash-table))
         (attributes (make-hash-table))
         (buffer (get-buffer-create " *edgar-nport-securities*")))
    (seq-doseq (fund funds)
      (when (plist-get fund :series-id)
        (puthash (plist-get fund :series-id) fund series))
      (push fund (gethash (plist-get fund :registrant-cik) ciks)))
    (pcase-dolist (`(,code . ,strings)
                   (plist-get summary :attributes))
      (puthash code strings attributes))
    (with-current-buffer buffer
      (setq buffer-undo-list t)
      (erase-buffer)
      (set-buffer-multibyte nil)
      (insert-file-contents-literally
       (expand-file-name "securities.tsv" directory)))
    (setq edgar-nport-dataset--index
          (append
           (list
            :directory directory
            :buffer buffer
            :series-table series
            :cik-table ciks
            :attribute-table attributes)
           summary))))

(defun edgar-nport-index (&optional sources)
  "Build or load the Form N-PORT index for SOURCES synchronously; return it.
SOURCES default to `edgar-nport-dataset-sources' or the newest two data
sets.  A cold build blocks for minutes; prefer `edgar-nport-index-async'
interactively."
  (edgar-nport-dataset--load
   (edgar-nport-dataset-build-latest sources)))

(defun edgar-nport-index-async (callback &optional sources)
  "Build or load the Form N-PORT index without blocking, then call CALLBACK.
CALLBACK receives (INDEX nil) on success and (nil ERROR-MESSAGE) on
failure.  The build runs in a batch Emacs subprocess; a cached index for
explicit SOURCES (or `edgar-nport-dataset-sources') loads directly.
Return the subprocess, or nil when no subprocess was needed."
  (let ((sources (or sources edgar-nport-dataset-sources)))
    (edgar-dataset-index-async
     callback
     :directory
     (and sources (edgar-nport-dataset-index-directory sources))
     :build 'edgar-nport-dataset-build-latest
     :sources sources
     :load #'edgar-nport-dataset--load
     :features '(edgar-nport-dataset)
     :variables
     '(edgar-dataset-cache-directory
       edgar-unzip-program edgar-nport-dataset-page-url)
     :name "edgar-nport-index")))

(defun edgar-nport-dataset--current ()
  "Return the loaded index, loading or building it synchronously if needed."
  (let ((index edgar-nport-dataset--index))
    (if (and index (buffer-live-p (plist-get index :buffer)))
        index
      (edgar-nport-index))))

;;;; Public queries

(defun edgar-nport-holders (id)
  "Return every N-PORT fund holding security ID now or in the prior period.
ID is a CUSIP, an ISIN or a ticker as reported in the IDENTIFIERS table;
when several securities share it, the most widely held one is used.
Return nil for an unknown ID, else a plist with :period :prior-period
:cusip :isin :ticker :issuer :title :asset-category :issuer-category
:funds :prior-funds :change :value-usd :prior-value-usd :counts :rows.
Each row has :registrant-cik :series-id :fund-name :balance :units
:value-usd :pct-of-nav :asset-category :issuer-category :payoff-profile
:value-unconverted :prior-balance :prior-value-usd :status
:filed-current :report-date :accession.  Status is new, added, reduced,
unchanged, exited, or not-reported (held before, and the fund has no
report for the current period)."
  (let* ((index (edgar-nport-dataset--current))
         (pos
          (with-current-buffer (plist-get index :buffer)
            (edgar-nport-dataset--find id))))
    (when pos
      (let* ((security
              (with-current-buffer (plist-get index :buffer)
                (edgar-nport-dataset--line pos)))
             (funds (plist-get index :funds))
             (attributes (plist-get index :attribute-table))
             (rows
              (edgar-nport-dataset--by-value
               (mapcar
                (lambda (record)
                  (let ((fund (aref funds (aref record 0))))
                    (append
                     (list
                      :registrant-cik (plist-get fund :registrant-cik)
                      :series-id (plist-get fund :series-id)
                      :fund-name (plist-get fund :fund-name))
                     (edgar-nport-dataset--holding
                      record fund attributes)
                     (list
                      :report-date (plist-get fund :period)
                      :accession
                      (plist-get
                       (or (plist-get fund :filing)
                           (plist-get fund :prior-filing))
                       :accn)))))
                (edgar-nport-dataset--slice
                 index
                 "by-security.eld"
                 (plist-get security :slice))))))
        (append
         (list
          :period (plist-get index :period)
          :prior-period (plist-get index :prior-period))
         (edgar-nport-dataset--public security)
         (list
          :counts (edgar-nport-dataset--counts rows)
          :rows rows))))))

(defun edgar-nport-dataset--matches-p (security needle categories)
  "Return non-nil when SECURITY matches NEEDLE and CATEGORIES.
NEEDLE is upper case or nil: a CUSIP or ISIN prefix, the ticker, or an
issuer or title substring.  CATEGORIES is (ASSET ISSUER), each nil or
an upper-case category code."
  (and (or (null (car categories))
           (equal
            (car categories)
            (upcase (or (plist-get security :asset-category) ""))))
       (or (null (cadr categories))
           (equal
            (cadr categories)
            (upcase (or (plist-get security :issuer-category) ""))))
       (or (null needle)
           (string-prefix-p
            needle (or (plist-get security :cusip) ""))
           (string-prefix-p needle (or (plist-get security :isin) ""))
           (equal
            needle (upcase (or (plist-get security :ticker) "")))
           (string-search
            needle (upcase (or (plist-get security :issuer) "")))
           (string-search
            needle (upcase (or (plist-get security :title) ""))))))

(defun edgar-nport-dataset--next-candidate (needle)
  "Move to the next line that may match NEEDLE and return its start.
Without NEEDLE every line is a candidate.  Return nil at the end."
  (if needle
      (let ((case-fold-search t))
        (when (search-forward needle nil t)
          (prog1 (line-beginning-position)
            (forward-line 1))))
    (unless (eobp)
      (prog1 (point)
        (forward-line 1)))))

(defun edgar-nport-dataset--prefilter (needle)
  "Return the longest ASCII run of NEEDLE to search for, or nil.
The securities buffer holds raw UTF-8 bytes and case folding there only
covers ASCII, so non-ASCII text is matched after decoding a line."
  (and needle
       (car
        (sort (split-string needle "[^[:ascii:]]+" t)
              (lambda (a b) (> (length a) (length b)))))))

(defun edgar-nport-dataset--category-p (bol categories)
  "Return non-nil when the line at BOL matches CATEGORIES.
CATEGORIES is (ASSET ISSUER), each nil or an upper-case code."
  (cl-every
   (lambda (pair)
     (or (null (car pair))
         (let ((bounds (edgar-nport-dataset--field bol (cdr pair))))
           (string=
            (car pair)
            (upcase
             (buffer-substring-no-properties
              (car bounds) (cdr bounds)))))))
   (list (cons (car categories) 6) (cons (cadr categories) 7))))

(defun edgar-nport-dataset--line-key (bol sort)
  "Return the SORT key of the line at BOL from its numeric fields."
  (let ((funds (edgar-nport-dataset--field-number bol 8)))
    (pcase sort
      ('holders funds)
      ('change (- funds (edgar-nport-dataset--field-number bol 9)))
      ('drop (- (edgar-nport-dataset--field-number bol 9) funds))
      ('value (edgar-nport-dataset--field-number bol 10)))))

(defun edgar-nport-dataset--scan-lines (needle categories sort top)
  "Return line positions matching NEEDLE and CATEGORIES, best SORT first.
The current buffer is the securities buffer, ordered by fund count, so
for `holders' the scan stops after TOP matches."
  (let ((keyed nil)
        (found 0)
        (prefilter (edgar-nport-dataset--prefilter needle))
        bol)
    (goto-char (point-min))
    (while (and (setq bol
                      (edgar-nport-dataset--next-candidate prefilter))
                (not (and top (eq sort 'holders) (>= found top))))
      (when (and (edgar-nport-dataset--category-p bol categories)
                 (or (null needle)
                     (edgar-nport-dataset--matches-p
                      (edgar-nport-dataset--line bol) needle nil)))
        (setq found (1+ found))
        (push
         (cons (edgar-nport-dataset--line-key bol sort) bol) keyed))
      (goto-char bol)
      (forward-line 1))
    (mapcar
     #'cdr
     (if (eq sort 'holders)
         (nreverse keyed)
       (sort (nreverse keyed) (lambda (a b) (> (car a) (car b))))))))

(defun edgar-nport-dataset--sort-key (sort)
  "Return the key function for SORT over security plists."
  (pcase (or sort 'holders)
    ('holders (lambda (row) (plist-get row :funds)))
    ('change (lambda (row) (plist-get row :change)))
    ('drop (lambda (row) (- (plist-get row :change))))
    ('value (lambda (row) (plist-get row :value-usd)))
    (other (error "EDGAR N-PORT: unknown sort %s" other))))

(defun edgar-nport-dataset--public (security)
  "Return SECURITY without its internal :slice."
  (cl-loop
   for
   (key value)
   on
   security
   by
   #'cddr
   unless
   (eq key :slice)
   append
   (list key value)))

(cl-defun
 edgar-nport-securities
 (&key query asset-category issuer-category sort top)
 "Return securities held by N-PORT funds, with fund counts.
QUERY matches a CUSIP or ISIN prefix, a ticker, or an issuer or title
substring, case-insensitively.  ASSET-CATEGORY (ASSET_CAT, such as EC,
DBT, LON, ABS-MBS, DIR) and ISSUER-CATEGORY (ISSUER_TYPE, such as CORP,
MUN, UST) filter by code.  SORT is `holders' (default), `change', `drop'
or `value'; TOP limits rows.  Return (:period P :prior-period P :rows
ROWS); each row has :cusip :isin :ticker :issuer :title :asset-category
:issuer-category :funds :prior-funds :change :value-usd
:prior-value-usd."
 (let* ((index (edgar-nport-dataset--current))
        (sort (or sort 'holders))
        (key (edgar-nport-dataset--sort-key sort))
        (needle (and query (upcase (string-trim query))))
        (categories
         (list
          (and asset-category (upcase (format "%s" asset-category)))
          (and issuer-category
               (upcase (format "%s" issuer-category)))))
        (filtered (or needle (car categories) (cadr categories)))
        (precomputed
         (and (not filtered)
              top (<= top edgar-nport-dataset--top-count)
              (plist-get
               index
               (pcase sort
                 ('change :top-change)
                 ('drop :top-drop)
                 ('value :top-value)))))
        rows)
   (with-current-buffer (plist-get index :buffer)
     (let ((positions
            (or precomputed
                (edgar-nport-dataset--scan-lines
                 needle categories sort top))))
       (setq rows
             (mapcar
              (lambda (pos)
                (edgar-nport-dataset--public
                 (edgar-nport-dataset--line pos)))
              (if top
                  (seq-take positions top)
                positions)))))
   (setq rows
         (sort rows
               (lambda (a b) (> (funcall key a) (funcall key b)))))
   (list
    :period (plist-get index :period)
    :prior-period (plist-get index :prior-period)
    :rows
    (if top
        (seq-take rows top)
      rows))))

(cl-defun
 edgar-nport-funds (query &key top)
 "Return N-PORT funds whose series or registrant name matches QUERY.
QUERY is matched case-insensitively as a substring; a series id (such
as S000002848) or a numeric CIK matches exactly.  Largest net assets
first; TOP limits the result.  Each element has :registrant-cik
:registrant-name :series-id :fund-name :net-assets :holdings :period."
 (let* ((index (edgar-nport-dataset--current))
        (needle (upcase (string-trim query)))
        (cik
         (and (string-match-p "\\`[0-9]+\\'" needle)
              (string-to-number needle)))
        rows)
   (seq-doseq (fund (plist-get index :funds))
     (when (or (eql cik (plist-get fund :registrant-cik))
               (equal needle (plist-get fund :series-id))
               (string-search
                needle (upcase (or (plist-get fund :fund-name) "")))
               (string-search
                needle
                (upcase (or (plist-get fund :registrant-name) ""))))
       (push (list
              :registrant-cik (plist-get fund :registrant-cik)
              :registrant-name (plist-get fund :registrant-name)
              :series-id (plist-get fund :series-id)
              :fund-name (plist-get fund :fund-name)
              :net-assets (plist-get fund :net-assets)
              :holdings (plist-get fund :holdings)
              :period (plist-get fund :period))
             rows)))
   (setq rows
         (sort rows
               (lambda (a b)
                 (> (or (plist-get a :net-assets) 0)
                    (or (plist-get b :net-assets) 0)))))
   (if top
       (seq-take rows top)
     rows)))

(defun edgar-nport-dataset--resolve-fund (index series-or-cik)
  "Return the fund plist of INDEX named by SERIES-OR-CIK, or nil.
A CIK with several series signals a `user-error' listing them."
  (let ((text
         (and (stringp series-or-cik)
              (upcase (string-trim series-or-cik)))))
    (if (and text (string-match-p "\\`S[0-9]+\\'" text))
        (gethash text (plist-get index :series-table))
      (let* ((cik
              (if text
                  (string-to-number text)
                series-or-cik))
             (funds (gethash cik (plist-get index :cik-table))))
        (if (cdr funds)
            (user-error
             "EDGAR N-PORT: CIK %s files for %d series; pass one of %s"
             cik (length funds)
             (string-join (mapcar
                           (lambda (fund)
                             (plist-get fund :series-id))
                           funds)
                          ", "))
          (car funds))))))

(defun edgar-nport-portfolio (series-or-cik)
  "Return the N-PORT portfolio of a fund, or nil when it is unknown.
SERIES-OR-CIK is a series id such as \"S000002848\", or the CIK (number
or string) of a registrant that files for a single fund.  The plist has
:registrant-cik :registrant-name :series-id :fund-name :period
:prior-period :report-date :prior-report-date :accession :filing
:prior-filing :net-assets :prior-net-assets :holdings :prior-holdings
:value-usd :prior-value-usd :counts :rows.  :filing is a filing plist
for `edgar-fund-report'.  Each row has :cusip :isin :ticker :issuer
:title plus the holding fields of `edgar-nport-holders'.  Counts
reconcile: new+added+reduced+unchanged equals :holdings and
added+reduced+unchanged+exited+not-reported equals :prior-holdings."
  (let* ((index (edgar-nport-dataset--current))
         (fund
          (edgar-nport-dataset--resolve-fund index series-or-cik)))
    (when fund
      (let* ((attributes (plist-get index :attribute-table))
             (entries
              (edgar-nport-dataset--slice
               index "by-fund.eld"
               (gethash
                (plist-get fund :index)
                (plist-get index :fund-slices))))
             (rows
              (with-current-buffer (plist-get index :buffer)
                (mapcar
                 (lambda (entry)
                   (let ((security
                          (edgar-nport-dataset--line (car entry))))
                     (append
                      (list
                       :cusip (plist-get security :cusip)
                       :isin (plist-get security :isin)
                       :ticker (plist-get security :ticker)
                       :issuer (plist-get security :issuer)
                       :title (plist-get security :title))
                      (edgar-nport-dataset--holding
                       (cdr entry) fund attributes))))
                 entries))))
        (append
         (list
          :period (plist-get index :period)
          :prior-period (plist-get index :prior-period)
          :accession (plist-get (plist-get fund :filing) :accn))
         (cl-loop
          for key in
          '(:registrant-cik
            :registrant-name
            :series-id
            :fund-name
            :report-date
            :prior-report-date
            :filing
            :prior-filing
            :net-assets
            :prior-net-assets
            :holdings
            :prior-holdings
            :value-usd
            :prior-value-usd)
          append (list key (plist-get fund key)))
         (list
          :counts (edgar-nport-dataset--counts rows)
          :rows (edgar-nport-dataset--by-value rows)))))))

(provide 'edgar-nport-dataset)
;;; edgar-nport-dataset.el ends here
