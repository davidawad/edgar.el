;;; edgar-nport-dataset-test.el --- Tests for the cross-fund N-PORT index -*- lexical-binding: t; -*-

;;; Commentary:

;; Hermetic tests over two tiny Form N-PORT data sets built from the TSVs
;; in test/fixtures/nport-dataset/{new,old}.  Current period 2026-06-30.
;; Funds: S000000001 Alpha Bond Fund (NPORT-P superseded by NPORT-P/A, a
;; January report outside both windows), S000000002 Beta Equity Index
;; (July and April reports), CIK 3 Gamma Closed-End Fund (no series; its
;; February report filed late, in the new data set), S000000004 Delta
;; Income Fund (prior only, so not-reported), S000000006 Alpha Muni Fund
;; (current only; same registrant as Alpha Bond), CIK 5 (NT NPORT-P only).

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'seq)
(require 'edgar-dataset-test)
(require 'edgar-nport-dataset)

(defvar edgar-nport-dataset-test--sources nil
  "Fixture data-set ZIPs, newest first, once built.")

(defun edgar-nport-dataset-test--sources ()
  "Return the fixture data-set ZIPs, newest first."
  (or edgar-nport-dataset-test--sources
      (setq edgar-nport-dataset-test--sources
            (list
             (edgar-dataset-test--zip "nport-dataset/new")
             (edgar-dataset-test--zip "nport-dataset/old")))))

(defmacro edgar-nport-dataset-test--with-index (&rest body)
  "Run BODY with the fixture index loaded."
  (declare (indent 0) (debug t))
  `(progn
     (skip-unless (edgar-dataset-test--tools-p))
     (let ((edgar-dataset-cache-directory edgar-dataset-test--cache)
           (edgar-nport-dataset--index nil))
       (edgar-nport-index (edgar-nport-dataset-test--sources))
       ,@body)))

(defun edgar-nport-dataset-test--row (rows key value)
  "Return the first of ROWS whose KEY is VALUE."
  (seq-find (lambda (row) (equal (plist-get row key) value)) rows))

(defun edgar-nport-dataset-test--reconciles-p (counts current prior)
  "Return non-nil when status COUNTS reconcile with CURRENT and PRIOR."
  (and (= current
          (+ (plist-get counts :new) (plist-get counts :added)
             (plist-get counts :reduced)
             (plist-get counts :unchanged)))
       (= prior
          (+ (plist-get counts :added) (plist-get counts :reduced)
             (plist-get counts :unchanged)
             (plist-get counts :exited)
             (plist-get counts :not-reported)))))

(ert-deftest edgar-nport-dataset-months-and-isins ()
  (should
   (equal
    (edgar-nport-dataset-month-end (+ (* 12 2026) 1)) "2026-02-28"))
  (should
   (equal
    (edgar-nport-dataset-month-end (+ (* 12 2024) 1)) "2024-02-29"))
  (should
   (equal (edgar-nport-dataset-month-end (* 12 2026)) "2026-01-31"))
  (should
   (equal
    (edgar-nport-dataset-isin-string
     (with-temp-buffer
       (insert "US037833100")
       (goto-char (point-min))
       (edgar-dataset-read-code)))
    "US0378331005")))

(ert-deftest edgar-nport-dataset-identifier-reader ()
  (with-temp-buffer
    (insert "037833DX5\tN/A\t000000000\t037833DX\tUS0378331005\t\n")
    (goto-char (point-min))
    (should (edgar-dataset-read-identifier 9))
    (should-not (edgar-dataset-read-identifier 9))
    (should-not (edgar-dataset-read-identifier 9))
    (should-not (edgar-dataset-read-identifier 9))
    (should
     (equal
      (edgar-nport-dataset-isin-string
       (edgar-dataset-read-identifier 12 11))
      "US0378331005"))
    (should-not (edgar-dataset-read-identifier 9))
    (should (eolp))))

(ert-deftest edgar-nport-dataset-amendment-supersedes ()
  "Per series and report month the latest filing (NPORT-P/A) wins."
  (edgar-nport-dataset-test--with-index
    (let* ((alpha (edgar-nport-portfolio "S000000001"))
           (apple
            (edgar-nport-dataset-test--row
             (plist-get alpha :rows)
             :cusip "037833DX5")))
      (should
       (equal (plist-get alpha :accession) "0000000001-26-000011"))
      (should
       (equal
        (plist-get (plist-get alpha :filing) :form) "NPORT-P/A"))
      (should
       (equal
        (plist-get (plist-get alpha :filing) :url)
        (concat
         "https://www.sec.gov/Archives/edgar/data/1/"
         "000000000126000011/primary_doc.xml")))
      ;; Two rows of the amendment are summed; the original's 5000 is gone.
      (should (= 1500 (plist-get apple :balance)))
      (should (= 1485 (plist-get apple :value-usd)))
      (should (equal (plist-get apple :units) "PA"))
      (should (< (abs (- 1.485 (plist-get apple :pct-of-nav))) 1e-9))
      ;; The January report is outside the prior window.
      (should (= 800 (plist-get apple :prior-balance)))
      (should (eq 'added (plist-get apple :status))))))

(ert-deftest edgar-nport-dataset-late-filing-counts-for-its-month ()
  (edgar-nport-dataset-test--with-index
    (let* ((holders (edgar-nport-holders "037833dx5"))
           (rows (plist-get holders :rows))
           (gamma
            (edgar-nport-dataset-test--row rows :registrant-cik 3)))
      (should (equal (plist-get holders :period) "2026-06-30"))
      (should (equal (plist-get holders :prior-period) "2026-03-31"))
      (should (equal (plist-get holders :issuer) "Apple Inc."))
      (should (equal (plist-get holders :asset-category) "DBT"))
      (should (equal (plist-get holders :issuer-category) "CORP"))
      (should-not (plist-get gamma :series-id))
      (should
       (equal (plist-get gamma :fund-name) "Gamma Closed-End Fund"))
      (should (= 100 (plist-get gamma :prior-balance)))
      (should (eq 'added (plist-get gamma :status)))
      (should (= 3 (plist-get holders :funds)))
      (should (= 4 (plist-get holders :prior-funds))))))

(ert-deftest edgar-nport-dataset-status-counts-reconcile ()
  (edgar-nport-dataset-test--with-index
    (let* ((holders (edgar-nport-holders "037833DX5"))
           (counts (plist-get holders :counts))
           (rows (plist-get holders :rows)))
      (should
       (equal
        counts
        '(:new
          1
          :added 2
          :reduced 0
          :unchanged 0
          :exited 1
          :not-reported 1)))
      (should
       (edgar-nport-dataset-test--reconciles-p
        counts
        (plist-get holders :funds)
        (plist-get holders :prior-funds)))
      (should
       (eq
        'exited
        (plist-get
         (edgar-nport-dataset-test--row rows :series-id "S000000002")
         :status)))
      (should
       (eq
        'not-reported
        (plist-get
         (edgar-nport-dataset-test--row rows :series-id "S000000004")
         :status)))
      (should
       (eq
        'new
        (plist-get
         (edgar-nport-dataset-test--row rows :series-id "S000000006")
         :status))))
    (let* ((alpha (edgar-nport-portfolio "s000000001"))
           (counts (plist-get alpha :counts)))
      (should
       (equal
        counts
        '(:new
          1
          :added 1
          :reduced 1
          :unchanged 1
          :exited 1
          :not-reported 0)))
      (should (= 4 (plist-get alpha :holdings)))
      (should (= 4 (plist-get alpha :prior-holdings)))
      (should
       (edgar-nport-dataset-test--reconciles-p
        counts
        (plist-get alpha :holdings)
        (plist-get alpha :prior-holdings)))
      (should (= 100000 (plist-get alpha :net-assets)))
      (should (= 90000 (plist-get alpha :prior-net-assets))))
    (let ((delta (edgar-nport-portfolio "S000000004")))
      (should-not (plist-get delta :filing))
      (should
       (equal
        (plist-get delta :counts)
        '(:new
          0
          :added 0
          :reduced 0
          :unchanged 0
          :exited 0
          :not-reported 1))))))

(ert-deftest edgar-nport-dataset-identifier-fallback ()
  "CUSIP, else ISIN (a US ISIN embeds the CUSIP), else issuer and title."
  (edgar-nport-dataset-test--with-index
    ;; No CUSIP in either quarter: matched by ISIN.
    (let* ((euro (edgar-nport-holders "XS1234567896"))
           (row (car (plist-get euro :rows))))
      (should-not (plist-get euro :cusip))
      (should (= 1 (plist-get euro :funds)))
      (should (eq 'reduced (plist-get row :status)))
      (should (= 300 (plist-get row :prior-balance)))
      ;; Foreign currency without an exchange rate is flagged.
      (should (plist-get row :value-unconverted)))
    ;; A US ISIN-only row and a CUSIP row are one security.
    (let ((apple (edgar-nport-holders "US0378331005")))
      (should (equal (plist-get apple :cusip) "037833100"))
      (should (= 2 (plist-get apple :funds)))
      (should
       (equal
        (plist-get
         (edgar-nport-holders "037833100")
         :isin)
        "US0378331005")))
    ;; Tickers from the IDENTIFIERS table.
    (let ((nvidia (edgar-nport-holders "nvda")))
      (should (equal (plist-get nvidia :cusip) "67066G104"))
      (should (equal (plist-get nvidia :ticker) "NVDA"))
      (should
       (eq
        'added (plist-get (car (plist-get nvidia :rows)) :status))))
    ;; No identifier at all: issuer plus title.
    (let ((forward
           (car
            (plist-get
             (edgar-nport-securities :query "eur/usd")
             :rows))))
      (should
       (equal (plist-get forward :title) "EUR/USD FWD 20260916"))
      (should (= 2 (plist-get forward :funds)))
      (should (equal (plist-get forward :asset-category) "DFE")))
    (should-not (edgar-nport-holders "N/A"))
    (should-not (edgar-nport-holders "999999999"))))

(ert-deftest edgar-nport-dataset-non-ascii-lines ()
  "Lines after a non-ASCII security are still found by byte position."
  (edgar-nport-dataset-test--with-index
    (let ((socgen (edgar-nport-holders "83368RBA9")))
      (should
       (equal (plist-get socgen :issuer) "Société Générale SA"))
      (should (= 2 (plist-get socgen :funds))))
    (let ((muni (edgar-nport-portfolio "S000000006")))
      (should
       (equal
        (sort (mapcar
               (lambda (row)
                 (plist-get row :cusip))
               (plist-get muni :rows))
              #'string<)
        '("037833DX5" "13063DGA0" "64966MAB5" "83368RBA9"))))
    (should
     (equal
      (plist-get
       (car
        (plist-get (edgar-nport-securities :query "générale") :rows))
       :cusip)
      "83368RBA9"))))

(ert-deftest edgar-nport-dataset-securities-sort-and-filter ()
  (edgar-nport-dataset-test--with-index
    (let ((rows (plist-get (edgar-nport-securities :top 2) :rows)))
      (should (equal (plist-get (car rows) :cusip) "037833DX5"))
      (should (= 2 (length rows))))
    (let ((munis
           (plist-get
            (edgar-nport-securities :issuer-category 'mun)
            :rows)))
      (should
       (equal
        (mapcar
         (lambda (row) (plist-get row :cusip)) munis)
        '("13063DGA0" "64966MAB5")))
      (should (= 2 (plist-get (car munis) :funds)))
      (should (= 1 (plist-get (car munis) :change))))
    (let ((equities
           (plist-get
            (edgar-nport-securities :asset-category "EC" :sort 'value)
            :rows)))
      (should (equal (plist-get (car equities) :cusip) "67066G104"))
      (should (= 3 (length equities))))
    (let ((drops
           (plist-get
            (edgar-nport-securities :sort 'drop :top 2)
            :rows)))
      (should
       (equal
        (sort (mapcar (lambda (row) (plist-get row :cusip)) drops)
              #'string<)
        '("037833DX5" "30231G102")))
      (should (= -1 (plist-get (car drops) :change))))
    (should
     (equal
      (plist-get
       (car
        (plist-get
         (edgar-nport-securities :sort 'value :top 1)
         :rows))
       :cusip)
      "67066G104"))
    (should
     (= 2
        (length
         (plist-get
          (edgar-nport-securities :query "apple" :top 2)
          :rows))))
    (should-error (edgar-nport-securities :sort 'bogus))))

(ert-deftest edgar-nport-dataset-fund-name-search ()
  (edgar-nport-dataset-test--with-index
    (let ((alpha (edgar-nport-funds "ALPHA")))
      (should
       (equal
        (mapcar
         (lambda (fund) (plist-get fund :series-id)) alpha)
        '("S000000001" "S000000006")))
      (should (= 100000 (plist-get (car alpha) :net-assets)))
      (should (= 4 (plist-get (car alpha) :holdings)))
      (should (equal (plist-get (car alpha) :period) "2026-06-30")))
    (should
     (equal
      (plist-get
       (car (edgar-nport-funds "delta income"))
       :period)
      "2026-03-31"))
    (should (= 1 (length (edgar-nport-funds "alpha" :top 1))))
    (should
     (equal
      (plist-get
       (car (edgar-nport-funds "3"))
       :fund-name)
      "Gamma Closed-End Fund"))
    (should
     (equal
      (plist-get
       (car (edgar-nport-funds "s000000002"))
       :fund-name)
      "Beta Equity Index"))
    (should-not (edgar-nport-funds "epsilon"))
    (should
     (equal
      (plist-get (edgar-nport-portfolio 3) :fund-name)
      "Gamma Closed-End Fund"))
    (should
     (equal
      (plist-get (edgar-nport-portfolio "0000000003") :holdings) 3))
    (should-error (edgar-nport-portfolio 1) :type 'user-error)
    (should-not (edgar-nport-portfolio "S000000099"))))

(ert-deftest edgar-nport-dataset-async-builds-in-subprocess ()
  (skip-unless (edgar-dataset-test--tools-p))
  (let* ((edgar-dataset-cache-directory
          (make-temp-file "edgar-nport-async-" t))
         (edgar-nport-dataset--index nil)
         (sources (edgar-nport-dataset-test--sources))
         (result :pending)
         (process
          (edgar-nport-index-async
           (lambda (index error)
             (setq result (or index error)))
           sources))
         (deadline (+ (float-time) 300)))
    (should (processp process))
    (while (and (eq result :pending) (< (float-time) deadline))
      (accept-process-output nil 0.2))
    (should (equal (plist-get result :period) "2026-06-30"))
    (should
     (= 3 (plist-get (edgar-nport-holders "037833DX5") :funds)))
    (setq result :pending)
    (should-not
     (edgar-nport-index-async
      (lambda (index _error) (setq result index)) sources))
    (while (eq result :pending)
      (accept-process-output nil 0.05))
    (should (equal (plist-get result :prior-period) "2026-03-31"))))

;; Live: downloads the newest two SEC data sets (~900 MB) and builds the
;; index.  Set XBRL_USER_AGENT or `xbrl-user-agent' to a real name + email.
(ert-deftest edgar-nport-dataset-live ()
  :tags
  '(network)
  (skip-unless (getenv "XBRL_LIVE"))
  (let*
      ((xbrl-user-agent
        (or (getenv "XBRL_USER_AGENT") xbrl-user-agent))
       (edgar-nport-dataset-sources nil)
       (edgar-nport-dataset--index nil)
       (index (edgar-nport-index))
       (apple-note (edgar-nport-holders "037833AL4")) ; AAPL 3.85% 2043
       (nvidia (edgar-nport-holders "67066G104"))
       (vanguard
        (edgar-nport-portfolio
         (plist-get
          (car
           (edgar-nport-funds "Vanguard Total Stock Market Index"))
          :series-id))))
    (should
     (string-match-p
      "\\`[0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}\\'"
      (plist-get index :period)))
    (should (> (plist-get apple-note :funds) 10))
    (should (> (plist-get nvidia :funds) 1000))
    (should
     (> (plist-get
         (car
          (plist-get
           (edgar-nport-securities :issuer-category "MUN" :top 1)
           :rows))
         :funds)
        0))
    (should (> (plist-get vanguard :holdings) 1000))
    (should
     (edgar-nport-dataset-test--reconciles-p
      (plist-get vanguard :counts)
      (plist-get vanguard :holdings)
      (plist-get vanguard :prior-holdings)))))

(provide 'edgar-nport-dataset-test)
;;; edgar-nport-dataset-test.el ends here
