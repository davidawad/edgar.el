;;; edgar-test.el --- tests for edgar.el -*- lexical-binding: t; -*-

(require 'edgar-test-support)

(ert-deftest
    edgar-facts-exposes-inline-facts-from-the-primary-document
    ()
  (let*
      ((fixture
        (expand-file-name "fixtures/10-k-aapl.htm.gz"
                          edgar-test--dir))
       (filing
        '(:form
          "10-K"
          :accn "0000320193-25-000079"
          :url "https://www.sec.gov/Archives/edgar/data/320193/000032019325000079/aapl-20250927.htm")))
    (cl-letf (((symbol-function 'edgar-html)
               (lambda (_filing)
                 (with-temp-buffer
                   (let ((auto-compression-mode t))
                     (insert-file-contents fixture))
                   (buffer-string)))))
      (let
          ((revenue
            (seq-find
             (lambda (fact)
               (and
                (equal
                 (plist-get fact :name)
                 "us-gaap:RevenueFromContractWithCustomerExcludingAssessedTax")
                (equal
                 (plist-get
                  (plist-get fact :context)
                  :end)
                 "2025-09-27")
                (null
                 (plist-get (plist-get fact :context) :dimensions))))
             (edgar-facts filing))))
        (should revenue)
        (should (= (plist-get revenue :value) 416161000000))
        (should (equal (plist-get revenue :unit) "USD"))
        (should
         (equal
          (plist-get (plist-get revenue :context) :start)
          "2024-09-29"))))))

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

(ert-deftest edgar-sections-trim-terminal-line-breaks ()
  "Section bodies omit line breaks after the final filing text."
  (let* ((text
          (concat
           "Item 10. Certification\nBody text" (make-string 8 ?\n)))
         (body (cdr (assoc "10" (edgar-sections text)))))
    (should (equal body "Item 10. Certification\nBody text"))))

(ert-deftest edgar-sections-normalize-unicode-heading-spaces ()
  "Unicode spaces in Item headings do not make sections disappear."
  (let
      ((sections
        (edgar-sections
         "Item\u20091. Summary of the Offer\nImportant terms follow.\n")))
    (should (equal (mapcar #'car sections) '("1")))
    (should (string-match-p "Important terms" (cdar sections)))))

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

(ert-deftest edgar-sections-thin-space-headings ()
  "A 20-F may write ITEM, a U+2009 thin space, then the number."
  (let
      ((s
        (edgar-sections
         (concat
          "PART I\nITEM\u20091.IDENTITY OF DIRECTORS\nNot applicable.\n"
          "ITEM\u20093.KEY INFORMATION\nrisks galore here and there\n"))))
    (should (equal (mapcar #'car s) '("I.1" "I.3")))
    (should (string-match-p "risks galore" (cdr (assoc "I.3" s))))))

(ert-deftest edgar-sections-drop-wrapped-toc-without-part ()
  "A wrapped table-of-contents entry before the first Part is not a section."
  (let
      ((s
        (edgar-sections
         (concat
          "ITEM 7. MAJOR SHAREHOLDERS AND RELATED PARTY 55\nTRANSACTIONS\n"
          "ITEM 8. FINANCIAL INFORMATION 56\n"
          "PART I\n"
          "ITEM 7. MAJOR SHAREHOLDERS\nThe largest holder owns a lot.\n"
          "ITEM 8. FINANCIAL INFORMATION\nStatements are in Item 18.\n"))))
    (should (equal (mapcar #'car s) '("I.7" "I.8")))
    (should (string-match-p "largest holder" (cdr (assoc "I.7" s))))
    (should-not (assoc "7" s))))

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
      (should
       (string-match-p
        "risks galore" (edgar-section f "Risk Factors")))
      (should-not (edgar-section f "99")))))

(provide 'edgar-test)
;;; edgar-test.el ends here
