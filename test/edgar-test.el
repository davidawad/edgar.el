;;; edgar-test.el --- tests for edgar.el -*- lexical-binding: t; -*-

(require 'ert)
(require 'json)

;; Coverage (undercover.el, pack-mandated).  Must run before the source loads.
(setq load-prefer-newer t)
(when (require 'undercover nil t)
  (undercover "src/*.el" (:report-format 'text) (:send-report nil)))

(require 'edgar)

(defconst edgar-test--dir
  (file-name-directory (or load-file-name buffer-file-name))
  "Directory containing the EDGAR tests.")

(defun edgar-test--fixture-json (name)
  "Return recorded JSON fixture NAME as a plist."
  (with-temp-buffer
    (let ((auto-compression-mode t))
      (insert-file-contents
       (expand-file-name (concat "fixtures/" name) edgar-test--dir)))
    (json-parse-buffer :object-type 'plist :array-type 'list)))

(defconst edgar-test--submissions
  '(:filings
    (:recent
     (:accessionNumber
      ("0000320193-25-000079"
       "0000320193-25-000050"
       "0000320193-24-000123")
      :form ("10-K" "8-K" "10-K")
      :filingDate
      ("2025-10-31" "2025-08-01" "2024-11-01")
      :reportDate
      ("2025-09-27" "2025-07-30" "2024-09-28")
      :primaryDocument
      ("aapl-20250927.htm" "x8k.htm" "aapl-20240928.htm")))))

(defconst edgar-test--html
  (concat
   "<html><body>"
   "<p>Item 1. Business</p><p>Item 1A. Risk Factors</p><p>Item 2. Properties</p>"
   "<p>Item 1. Business</p><p>We sell phones and many other things.</p>"
   "<p>Item 1A. Risk Factors</p><p>There are risks galore here and there.</p>"
   "<p>Item 2. Properties</p><p>Buildings.</p>"
   "</body></html>"))

(defmacro edgar-test--with-sec (&rest body)
  "Run BODY with the SEC transport stubbed with canned data."
  (declare (indent 0))
  `(cl-letf (((symbol-function 'xbrl-cik)
              (lambda (_) "CIK0000320193"))
             ((symbol-function 'xbrl--get)
              (lambda (_) edgar-test--submissions))
             ((symbol-function 'edgar--fetch)
              (lambda (_) edgar-test--html)))
     ,@body))

(ert-deftest edgar-sections-picks-longest ()
  (let* ((text
          (concat
           "Item 1.\nItem 1A.\nItem 2.\n"
           "Item 1. Business\nwe sell phones and many other things\n"
           "Item 1A. Risk Factors\nrisks galore here and there\n"
           "Item 2. Properties\nbuildings\n"))
         (s (edgar-sections text)))
    (should (equal (mapcar #'car s) '("1" "1A" "2")))
    (should (string-match-p "phones" (cdr (assoc "1" s))))
    (should (string-match-p "risks galore" (cdr (assoc "1A" s))))))

(defconst edgar-test--10q
  (concat
   "PART I\nFINANCIAL INFORMATION\nItem 1. Financial Statements\n"
   "balance sheet and many other statements here\n"
   "Item 2. Management's Discussion\nsales rose a lot this quarter\n"
   "see Item 1A of this report for risks\n"
   "PART II\nOTHER INFORMATION\nItem 1. Legal Proceedings\nnone\n"
   "Item 2. Unregistered Sales\nnone sold\n"))

(ert-deftest edgar-sections-qualify-by-part ()
  (let ((s (edgar-sections edgar-test--10q)))
    (should (equal (mapcar #'car s) '("I.1" "I.2" "II.1" "II.2")))
    (should (string-match-p "balance sheet" (cdr (assoc "I.1" s))))
    (should
     (string-match-p "Legal Proceedings" (cdr (assoc "II.1" s))))
    ;; Part II heading ends Part I Item 2; a wrapped cross-reference does not.
    (should (string-match-p "see Item 1A" (cdr (assoc "I.2" s))))
    (should-not
     (string-match-p "OTHER INFORMATION" (cdr (assoc "I.2" s))))))

(ert-deftest edgar-sections-ignore-repeated-page-headers ()
  (let ((s
         (edgar-sections
          (concat
           "PART I\nItem 1. Financial Statements\npage one text\n"
           "PART I\nItem 1. Financial Statements\npage two text\n"
           "Item 2. MD&A\nanalysis\n"))))
    (should (equal (mapcar #'car s) '("I.1" "I.2")))
    (should (string-match-p "page one" (cdr (assoc "I.1" s))))
    (should (string-match-p "page two" (cdr (assoc "I.1" s))))))

(ert-deftest edgar-sections-dotted-8k-items ()
  (let
      ((s
        (edgar-sections
         "Item 2.02 Results of Operations\nrevenue\nItem 9.01 Exhibits\n(d) list\n")))
    (should (equal (mapcar #'car s) '("2.02" "9.01")))))

(ert-deftest edgar-sections-none-without-items ()
  (should-not
   (edgar-sections "SCHEDULE 13G\nNo item headings here at all.\n")))

(ert-deftest edgar-section-resolves-bare-and-ambiguous ()
  (cl-letf (((symbol-function 'edgar-text)
             (lambda (_) edgar-test--10q)))
    (should
     (string-match-p "balance sheet" (edgar-section nil "I.1")))
    (should (string-match-p "Legal" (edgar-section nil "ii.1")))
    (should-error (edgar-section nil "1") :type 'user-error)
    (should-not (edgar-section nil "9"))))

(ert-deftest edgar-section-bare-unique ()
  (cl-letf
      (((symbol-function 'edgar-text)
        (lambda (_)
          "PART II\nItem 7. MD&A\ntext\nPART III\nItem 10. Directors\nx\n")))
    (should (string-match-p "MD&A" (edgar-section nil "7")))
    (should (string-match-p "Directors" (edgar-section nil "10")))))

(ert-deftest edgar-key-ordering ()
  (should (edgar--key< "I.2" "II.1"))
  (should (edgar--key< "II.1" "II.1A"))
  (should (edgar--key< "2.02" "9.01"))
  (should-not (edgar--key< "III.1" "II.9")))

(ert-deftest edgar-item-ordering ()
  (should (edgar--item< "1" "1A"))
  (should (edgar--item< "1A" "2"))
  (should (edgar--item< "7" "10"))
  (should-not (edgar--item< "10" "7")))

(ert-deftest edgar-filings-parses-and-filters ()
  (edgar-test--with-sec
    (let ((all (edgar-filings "AAPL"))
          (k (edgar-filings "AAPL" "10-K")))
      (should (= (length all) 3))
      (should
       (equal
        (mapcar (lambda (f) (plist-get f :form)) k) '("10-K" "10-K")))
      (should
       (equal
        (plist-get (car k) :url)
        "https://www.sec.gov/Archives/edgar/data/320193/000032019325000079/aapl-20250927.htm")))))

(ert-deftest edgar-filings-loads-recorded-history ()
  (let ((recent (edgar-test--fixture-json "submissions-aapl.json.gz"))
        (history
         (edgar-test--fixture-json "submissions-aapl-001.json.gz"))
        requests)
    (cl-letf (((symbol-function 'xbrl-cik)
               (lambda (_) "CIK0000320193"))
              ((symbol-function 'xbrl--get)
               (lambda (url)
                 (push url requests)
                 (cond
                  ((string-suffix-p "/CIK0000320193.json" url)
                   recent)
                  ((string-suffix-p
                    "/CIK0000320193-submissions-001.json" url)
                   history)
                  (t
                   (error "Unexpected URL: %s" url))))))
      (let ((filings
             (edgar-filings "AAPL" "10-K" :since "2014-01-01")))
        (should (= (length requests) 2))
        (should (equal (plist-get (car filings) :filed) "2025-10-31"))
        (should
         (equal
          (plist-get
           (cl-find-if
            (lambda (filing)
              (equal (plist-get filing :filed) "2014-10-27"))
            filings)
           :form)
          "10-K"))))))

(ert-deftest edgar-filings-unbounded-stays-recent-only ()
  (let ((recent (edgar-test--fixture-json "submissions-aapl.json.gz"))
        requests)
    (cl-letf (((symbol-function 'xbrl-cik)
               (lambda (_) "CIK0000320193"))
              ((symbol-function 'xbrl--get)
               (lambda (url)
                 (push url requests)
                 (if (string-suffix-p "/CIK0000320193.json" url)
                     recent
                   (error
                    "Unbounded call fetched history: %s" url)))))
      (let ((filings (edgar-filings "AAPL" "10-K")))
        (should (= (length requests) 1))
        (should-not
         (cl-find-if
          (lambda (filing)
            (equal (plist-get filing :filed) "2014-10-27"))
          filings))))))

(ert-deftest edgar-filings-date-bounds-are-inclusive ()
  (let ((recent (edgar-test--fixture-json "submissions-aapl.json.gz"))
        (history
         (edgar-test--fixture-json "submissions-aapl-001.json.gz")))
    (cl-letf (((symbol-function 'xbrl-cik)
               (lambda (_) "CIK0000320193"))
              ((symbol-function 'xbrl--get)
               (lambda (url)
                 (if (string-suffix-p "-submissions-001.json" url)
                     history
                   recent))))
      (let ((filings
             (edgar-filings
              "AAPL"
              "10-K"
              :since "2013-10-30"
              :until "2014-10-27")))
        (should
         (equal
          (mapcar
           (lambda (filing) (plist-get filing :filed)) filings)
          '("2014-10-27" "2013-10-30")))))))

(ert-deftest edgar-filings-skips-history-before-since ()
  (let ((recent (edgar-test--fixture-json "submissions-aapl.json.gz"))
        requests)
    (cl-letf (((symbol-function 'xbrl-cik)
               (lambda (_) "CIK0000320193"))
              ((symbol-function 'xbrl--get)
               (lambda (url)
                 (push url requests)
                 (if (string-suffix-p "/CIK0000320193.json" url)
                     recent
                   (error "History page should not be fetched")))))
      (edgar-filings "AAPL" "10-K" :since "2016-01-01")
      (should (= (length requests) 1)))))

(ert-deftest edgar-filings-fetches-only-overlapping-history-pages ()
  (let* ((submissions (copy-tree edgar-test--submissions))
         (history
          '(:accessionNumber
            ("0000320193-14-000001")
            :form ("10-K")
            :filingDate ("2014-10-27")
            :reportDate ("2014-09-27")
            :primaryDocument ("aapl-20140927.htm")))
         requests)
    (plist-put
     (plist-get submissions :filings)
     :files
     '((:name
        "older.json"
        :filingFrom "1994-01-01"
        :filingTo "2009-12-31")
       (:name
        "matching.json"
        :filingFrom "2010-01-01"
        :filingTo "2015-12-31")))
    (cl-letf (((symbol-function 'xbrl-cik)
               (lambda (_) "CIK0000320193"))
              ((symbol-function 'xbrl--get)
               (lambda (url)
                 (push url requests)
                 (cond
                  ((string-suffix-p "/CIK0000320193.json" url)
                   submissions)
                  ((string-suffix-p "/matching.json" url)
                   history)
                  (t
                   (error "Non-overlapping page fetched: %s" url))))))
      (let ((filings
             (edgar-filings
              "AAPL"
              "10-K"
              :since "2014-01-01"
              :until "2014-12-31")))
        (should (= (length requests) 2))
        (should
         (equal
          (mapcar
           (lambda (filing) (plist-get filing :filed)) filings)
          '("2014-10-27")))))))

(ert-deftest edgar-unique-filings-deduplicates-accessions ()
  (let ((a '(:accn "a" :filed "2025-01-01"))
        (b '(:accn "b" :filed "2024-01-01"))
        (duplicate '(:accn "a" :filed "2023-01-01")))
    (should
     (equal
      (edgar--unique-filings (list a b duplicate)) (list a b)))))

(ert-deftest edgar-latest-is-newest ()
  (edgar-test--with-sec
    (should
     (equal
      (plist-get (edgar-latest "AAPL" "10-K") :filed) "2025-10-31"))
    (should-not (edgar-latest "AAPL" "S-1"))))

(ert-deftest edgar-text-and-section-from-html ()
  (edgar-test--with-sec
    (let ((f (edgar-latest "AAPL" "10-K")))
      (should (string-match-p "phones" (edgar-text f)))
      (should (string-match-p "risks galore" (edgar-section f "1a")))
      (should-not (edgar-section f "99")))))

(ert-deftest edgar-open-renders-buffer ()
  (edgar-test--with-sec
    (edgar-open (edgar-latest "AAPL" "10-K"))
    (with-current-buffer "*edgar: 0000320193-25-000079*"
      (should (string-match-p "Risk Factors" (buffer-string)))
      (should buffer-read-only))
    (kill-buffer "*edgar: 0000320193-25-000079*")))

(ert-deftest edgar-read-signals-when-none ()
  (edgar-test--with-sec
    (should-error (edgar-read "AAPL" "S-1") :type 'user-error)))

(ert-deftest edgar-list-renders-rows ()
  (edgar-test--with-sec
    (edgar-list "AAPL" "10-K")
    (with-current-buffer "*edgar: AAPL*"
      (should (string-match-p "2025-10-31" (buffer-string)))
      (should (string-match-p "2024-11-01" (buffer-string))))
    (kill-buffer "*edgar: AAPL*")))

(ert-deftest edgar-fetch-rejects-non-200 ()
  (cl-letf (((symbol-function 'url-retrieve-synchronously)
             (lambda (&rest _)
               (let ((b (generate-new-buffer " *edgar-fake*")))
                 (with-current-buffer b
                   (insert "HTTP/1.1 404 Not Found\r\n\r\n"))
                 b))))
    (should-error (edgar--fetch "https://example.invalid/x"))))

(ert-deftest edgar-fetch-decodes-body ()
  (cl-letf (((symbol-function 'url-retrieve-synchronously)
             (lambda (&rest _)
               (let ((b (generate-new-buffer " *edgar-fake*")))
                 (with-current-buffer b
                   (set-buffer-multibyte nil)
                   (insert
                    "HTTP/1.1 200 OK\r\nX: y\r\n\r\ncaf\303\251"))
                 b))))
    (should
     (equal (edgar--fetch "https://example.invalid/x") "café"))))

(ert-deftest edgar-live-10k ()
  :tags
  '(network)
  (skip-unless (getenv "XBRL_LIVE"))
  (let* ((f (edgar-latest "AAPL" "10-K"))
         (s (edgar-section f "1A")))
    (should (equal (plist-get f :form) "10-K"))
    (should (> (length s) 5000))))

(provide 'edgar-test)
;;; edgar-test.el ends here
