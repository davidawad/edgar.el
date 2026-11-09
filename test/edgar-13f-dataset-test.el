;;; edgar-13f-dataset-test.el --- Tests for the cross-filer 13F index -*- lexical-binding: t; -*-

;;; Commentary:

;; Hermetic tests over two tiny Form 13F data sets built from the TSVs in
;; test/fixtures/13f-dataset/{new,old}.  Filers: 1 Alpha (original,
;; restatement and NEW HOLDINGS amendments), 2 Beta (two originals, a call
;; option), 3 Gamma (late prior-period filing), 4 Delta (values in
;; thousands), 5 Epsilon (13F-NT only), 6 Zeta (an older period), 7 Eta
;; (prior period only, so its position is not-reported).

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'seq)
(require 'edgar-dataset-test)
(require 'edgar-13f-dataset)

(defvar edgar-13f-dataset-test--sources nil
  "Fixture data-set ZIPs, newest first, once built.")

(defun edgar-13f-dataset-test--sources ()
  "Return the fixture data-set ZIPs, newest first."
  (or edgar-13f-dataset-test--sources
      (setq edgar-13f-dataset-test--sources
            (list
             (edgar-dataset-test--zip "13f-dataset/new")
             (edgar-dataset-test--zip "13f-dataset/old")))))

(defmacro edgar-13f-dataset-test--with-index (&rest body)
  "Run BODY with the fixture index loaded."
  (declare (indent 0) (debug t))
  `(progn
     (skip-unless (edgar-dataset-test--tools-p))
     (let ((edgar-dataset-cache-directory edgar-dataset-test--cache)
           (edgar-13f-dataset--index nil))
       (edgar-13f-index (edgar-13f-dataset-test--sources))
       ,@body)))

(defun edgar-13f-dataset-test--row (rows key value)
  "Return the first of ROWS whose KEY is VALUE."
  (seq-find (lambda (row) (equal (plist-get row key) value)) rows))

(ert-deftest edgar-13f-dataset-dates-and-periods ()
  (should
   (equal (edgar-13f-dataset-iso-date "31-JUL-2026") "2026-07-31"))
  (should
   (equal (edgar-13f-dataset-iso-date "1-mar-2026") "2026-03-01"))
  (should-not (edgar-13f-dataset-iso-date "2026-07-31"))
  (should
   (equal (edgar-13f-dataset-prior-period "2026-06-30") "2026-03-31"))
  (should
   (equal (edgar-13f-dataset-prior-period "2026-03-31") "2025-12-31"))
  (should
   (equal (edgar-13f-dataset-prior-period "2026-12-31") "2026-09-30"))
  (should
   (equal (edgar-13f-dataset-prior-period "2026-09-30") "2026-06-30"))
  (should
   (equal
    (edgar-13f-dataset--end-date
     "https://x/files/01jun2026-31aug2026_form13f.zip")
    "2026-08-31"))
  (should
   (equal
    (edgar-13f-dataset--end-date
     "https://x/2023q4_form13f.zip")
    "2023-12-31")))

(ert-deftest edgar-13f-dataset-latest-sources-sorts-by-coverage ()
  (cl-letf (((symbol-function 'edgar-dataset-zip-urls)
             (lambda (_page)
               '("https://x/2023q4_form13f.zip"
                 "https://x/01mar2026-31may2026_form13f.zip"
                 "https://x/01jun2026-31aug2026_form13f.zip"))))
    (should
     (equal
      (edgar-13f-dataset-latest-sources)
      '("https://x/01jun2026-31aug2026_form13f.zip"
        "https://x/01mar2026-31may2026_form13f.zip")))))

(ert-deftest edgar-13f-dataset-amendment-selection ()
  "Restatement replaces the original; only later NEW HOLDINGS add rows."
  (edgar-13f-dataset-test--with-index
    (let* ((portfolio (edgar-13f-portfolio 1))
           (accessions
            (mapcar
             (lambda (filing)
               (plist-get filing :accn))
             (plist-get portfolio :filings)))
           (positions (plist-get portfolio :positions)))
      (should
       (equal
        accessions '("0000000001-26-000003" "0000000001-26-000004")))
      (should
       (equal
        (plist-get portfolio :accession) "0000000001-26-000003"))
      (should
       (equal
        (plist-get (plist-get portfolio :filing) :form) "13F-HR/A"))
      (should
       (= 100
          (plist-get
           (edgar-13f-dataset-test--row positions :cusip "111111111")
           :shares)))
      (should
       (= 10
          (plist-get
           (edgar-13f-dataset-test--row positions :cusip "444444444")
           :shares)))
      ;; Two originals: the later one wins, and its rows are summed.
      (let ((beta (edgar-13f-portfolio "2")))
        (should
         (equal (plist-get beta :accession) "0000000002-26-000002"))
        (should
         (= 50 (plist-get (car (plist-get beta :positions)) :shares)))
        (should
         (eq
          'unchanged
          (plist-get (car (plist-get beta :positions)) :status))))
      ;; Notices and other periods carry no holdings.
      (should-not (edgar-13f-portfolio 5))
      (should-not (edgar-13f-portfolio 6)))))

(ert-deftest edgar-13f-dataset-late-filing-counts-for-its-period ()
  (edgar-13f-dataset-test--with-index
    (let* ((holders (edgar-13f-holders "111111111"))
           (gamma
            (edgar-13f-dataset-test--row
             (plist-get holders :rows)
             :cik 3)))
      (should (equal (plist-get holders :period) "2026-06-30"))
      (should (equal (plist-get holders :prior-period) "2026-03-31"))
      (should (= 4 (plist-get holders :holders)))
      (should (= 4 (plist-get holders :prior-holders)))
      (should (= 20 (plist-get gamma :prior-shares)))
      (should (eq 'added (plist-get gamma :status))))))

(ert-deftest edgar-13f-dataset-put-call-rows-are-not-holders ()
  (edgar-13f-dataset-test--with-index
    (let* ((holders (edgar-13f-holders "222222222"))
           (option (car (plist-get holders :options))))
      (should (= 3 (plist-get holders :holders)))
      (should (= 1 (plist-get holders :prior-holders)))
      (should-not
       (edgar-13f-dataset-test--row (plist-get holders :rows) :cik 2))
      (should (equal (plist-get option :put-call) "Call"))
      (should (= 2 (plist-get option :cik)))
      (should (eq 'new (plist-get option :status))))))

(ert-deftest edgar-13f-dataset-thousands-filer-is-suspect ()
  (edgar-13f-dataset-test--with-index
    (let* ((holders (edgar-13f-holders "111111111"))
           (delta
            (edgar-13f-dataset-test--row
             (plist-get holders :rows)
             :cik 4))
           (alpha
            (edgar-13f-dataset-test--row
             (plist-get holders :rows)
             :cik 1))
           (filer (car (edgar-13f-filers "delta"))))
      (should (plist-get delta :value-suspect))
      (should (= 4 (plist-get delta :value-usd)))
      (should (= 4000 (plist-get delta :value-usd-adjusted)))
      (should-not (plist-get alpha :value-suspect))
      ;; Delta moves the total by 3,996 of 22,000 adjusted: over 1%.
      (should (plist-get holders :value-suspect))
      (should (= 4 (plist-get holders :value-suspect-usd)))
      (should-not
       (plist-get (edgar-13f-holders "333333333") :value-suspect))
      (should
       (= 0
          (plist-get
           (edgar-13f-holders "333333333")
           :value-suspect-usd)))
      (should (= 18004 (plist-get holders :value-usd)))
      (should (= 22000 (plist-get holders :value-usd-adjusted)))
      (should (plist-get filer :value-suspect))
      (should (= 5 (plist-get filer :value-usd)))
      (should (= 5000 (plist-get filer :value-usd-adjusted)))
      (should-not
       (plist-get (car (edgar-13f-filers "alpha")) :value-suspect)))))

(ert-deftest edgar-13f-dataset-status-counts-reconcile ()
  (edgar-13f-dataset-test--with-index
    (dolist (cik '(1 2 3 4 7))
      (let* ((portfolio (edgar-13f-portfolio cik))
             (counts (plist-get portfolio :counts)))
        (should
         (= (+ (plist-get counts :new)
               (plist-get counts :added)
               (plist-get counts :reduced)
               (plist-get counts :unchanged))
            (plist-get portfolio :current-positions)))
        (should
         (= (+ (plist-get counts :added)
               (plist-get counts :reduced)
               (plist-get counts :unchanged)
               (plist-get counts :exited)
               (plist-get counts :not-reported))
            (plist-get portfolio :prior-positions)))))
    (let ((alpha (edgar-13f-portfolio 1)))
      (should
       (equal
        (plist-get alpha :counts)
        '(:new
          1
          :added 1
          :reduced 1
          :unchanged 1
          :exited 1
          :not-reported 0)))
      (should
       (eq
        'exited
        (plist-get
         (car (last (plist-get alpha :positions)))
         :status))))))

(ert-deftest edgar-13f-dataset-not-reported-is-not-exited ()
  "A prior holder with no current-period filing is `not-reported'."
  (edgar-13f-dataset-test--with-index
    (let* ((holders (edgar-13f-holders "555555555"))
           (rows (plist-get holders :rows))
           (eta (edgar-13f-dataset-test--row rows :cik 7))
           (alpha (edgar-13f-dataset-test--row rows :cik 1))
           (portfolio (edgar-13f-portfolio 7)))
      (should (= 2 (plist-get holders :prior-holders)))
      (should (eq 'not-reported (plist-get eta :status)))
      (should-not (plist-get eta :filed-current))
      (should (eq 'exited (plist-get alpha :status)))
      (should (plist-get alpha :filed-current))
      (should
       (equal
        (plist-get holders :counts)
        '(:new
          0
          :added 0
          :reduced 0
          :unchanged 0
          :exited 1
          :not-reported 1)))
      (should (= 0 (plist-get portfolio :current-positions)))
      (should
       (equal
        (plist-get (plist-get portfolio :counts) :not-reported) 1)))))

(ert-deftest edgar-13f-dataset-security-suspect-threshold ()
  "Suspect filers flag a security only when they move it over 1%."
  (let ((row
         (lambda (value adjusted)
           (edgar-13f-dataset--security-row
            (vector "1" "I" "C" 1 1 1 value adjusted nil 1 1)))))
    (should-not
     (plist-get (funcall row 1000000 1000999) :value-suspect))
    (should
     (= 1
        (plist-get (funcall row 1000000 1000999) :value-suspect-usd)))
    (should (plist-get (funcall row 1000000 1100899) :value-suspect))
    (should
     (= 101
        (plist-get (funcall row 1000000 1100899) :value-suspect-usd)))
    (should-not (plist-get (funcall row 0 0) :value-suspect))))

(ert-deftest edgar-13f-dataset-securities-sort-and-query ()
  (edgar-13f-dataset-test--with-index
    (let ((result (edgar-13f-securities)))
      (should (equal (plist-get result :period) "2026-06-30"))
      (should
       (equal
        (mapcar
         (lambda (row) (plist-get row :cusip))
         (seq-take (plist-get result :rows) 2))
        '("111111111" "222222222")))
      (should (= 5 (length (plist-get result :rows)))))
    (should
     (equal
      (plist-get
       (car
        (plist-get (edgar-13f-securities :sort 'drop :top 1) :rows))
       :cusip)
      "555555555"))
    (should
     (equal
      (plist-get
       (car
        (plist-get (edgar-13f-securities :sort 'change :top 1) :rows))
       :change)
      2))
    (should
     (equal
      (plist-get
       (car
        (plist-get (edgar-13f-securities :sort 'value :top 1) :rows))
       :cusip)
      "111111111"))
    (let ((rows
           (plist-get (edgar-13f-securities :query "yankee") :rows)))
      (should
       (equal
        (mapcar
         (lambda (row) (plist-get row :class)) rows)
        '("CL A"))))
    (should
     (= 1
        (length
         (plist-get (edgar-13f-securities :query "3333") :rows))))
    (should-error (edgar-13f-securities :sort 'alphabetical))))

(ert-deftest edgar-13f-dataset-filer-name-search ()
  (edgar-13f-dataset-test--with-index
    (should
     (equal
      (mapcar
       (lambda (row) (plist-get row :name))
       (edgar-13f-filers "PARTNERS"))
      '("Beta Partners LP")))
    (should
     (equal
      (plist-get (car (edgar-13f-filers "3")) :name)
      "Gamma Advisors Inc"))
    (should (= 2 (length (edgar-13f-filers "a" :top 2))))
    (should-not (edgar-13f-filers "Epsilon"))
    (let ((alpha (car (edgar-13f-filers "alpha"))))
      (should (= 4 (plist-get alpha :positions)))
      (should (= 21500 (plist-get alpha :value-usd)))
      (should (equal (plist-get alpha :period) "2026-06-30")))
    (should-not (edgar-13f-holders "999999999"))))

(ert-deftest edgar-13f-dataset-async-builds-in-subprocess ()
  (skip-unless (edgar-dataset-test--tools-p))
  (let* ((edgar-dataset-cache-directory
          (make-temp-file "edgar-13f-async-" t))
         (edgar-13f-dataset--index nil)
         (sources (edgar-13f-dataset-test--sources))
         (result :pending)
         (process
          (edgar-13f-index-async
           (lambda (index error)
             (setq result (or index error)))
           sources))
         (deadline (+ (float-time) 300)))
    (should (processp process))
    (while (and (eq result :pending) (< (float-time) deadline))
      (accept-process-output nil 0.2))
    (should (equal (plist-get result :period) "2026-06-30"))
    (should
     (= 4 (plist-get (edgar-13f-holders "111111111") :holders)))
    ;; Cached now: loads without a subprocess.
    (setq result :pending)
    (should-not
     (edgar-13f-index-async
      (lambda (index _error) (setq result index)) sources))
    (while (eq result :pending)
      (accept-process-output nil 0.05))
    (should (equal (plist-get result :prior-period) "2026-03-31"))))

;; Live: downloads the newest two SEC data sets (~200 MB) and builds the
;; index.  Set XBRL_USER_AGENT or `xbrl-user-agent' to a real name + email.
(ert-deftest edgar-13f-dataset-live ()
  :tags
  '(network)
  (skip-unless (getenv "XBRL_LIVE"))
  (let* ((xbrl-user-agent
          (or (getenv "XBRL_USER_AGENT") xbrl-user-agent))
         (edgar-13f-dataset-sources nil)
         (edgar-13f-dataset--index nil)
         (index (edgar-13f-index))
         (nvidia (edgar-13f-holders "67066G104"))
         (bridgewater (edgar-13f-portfolio 1350694))
         (counts (plist-get bridgewater :counts)))
    (should
     (string-match-p
      "\\`[0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}\\'"
      (plist-get index :period)))
    (should (> (plist-get nvidia :holders) 4000))
    (should (> (plist-get bridgewater :current-positions) 100))
    (should
     (= (+ (plist-get counts :new) (plist-get counts :added)
           (plist-get counts :reduced)
           (plist-get counts :unchanged))
        (plist-get bridgewater :current-positions)))
    (should
     (= (+ (plist-get counts :added)
           (plist-get counts :reduced)
           (plist-get counts :unchanged)
           (plist-get counts :exited)
           (plist-get counts :not-reported))
        (plist-get bridgewater :prior-positions)))))

(provide 'edgar-13f-dataset-test)
;;; edgar-13f-dataset-test.el ends here
