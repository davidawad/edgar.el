;;; edgar-test.el --- tests for edgar.el -*- lexical-binding: t; -*-

(require 'ert)
(require 'json)

(add-to-list
 'load-path
 (file-name-directory (or load-file-name buffer-file-name)))

;; Coverage (undercover.el, pack-mandated).  Must run before the source loads.
(setq load-prefer-newer t)
(when (require 'undercover nil t)
  (undercover "src/*.el" (:report-format 'text) (:send-report nil)))

(require 'edgar)
(require 'edgar-fixtures)

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

(ert-deftest edgar-sections-normalize-unicode-heading-spaces ()
  "Unicode spaces in Item headings do not make sections disappear."
  (let ((sections
         (edgar-sections
          "Item\u20091. Summary of the Offer\nImportant terms follow.\n")))
    (should (equal (mapcar #'car sections) '("1")))
    (should (string-match-p "Important terms" (cdar sections)))))

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
      (should
       (string-match-p
        "risks galore" (edgar-section f "Risk Factors")))
      (should-not (edgar-section f "99")))))

(ert-deftest
    edgar-named-sections-resolve-prospectus-and-proxy-fixtures
    ()
  "Named sections resolve across recorded prospectus and proxy filings."
  (dolist (entry
           '(("s-1-rivn" "Prospectus Summary" "Rivian")
             ("def-14a-gme"
              "Proxy Statement Summary"
              "PROXY STATEMENT")))
    (let* ((slug (nth 0 entry))
           (filing (edgar-fixtures-filing slug))
           (html (edgar-fixtures-html slug)))
      (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) html)))
        (let ((body (edgar-section filing (nth 1 entry))))
          (should (stringp body))
          (should
           (string-match-p (regexp-quote (nth 2 entry)) body)))))))

(ert-deftest edgar-sd-exposes-numbered-items-through-section-api ()
  "A real Form SD supports generic item-number section lookup."
  (let* ((filing (edgar-fixtures-filing "sd-apple"))
         (html (edgar-fixtures-html "sd-apple")))
    (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) html)))
      (let ((body (edgar-section filing "1.01")))
        (should (stringp body))
        (should (string-match-p "Conflict Minerals Disclosure" body))
        (should (string-match-p "Apple designs" body)))
      (should (assoc "2.01" (edgar-sections (edgar-text filing)))))))

(ert-deftest edgar-18k-generic-document-subtree-is-addressable ()
  "A real 18-K supports access to its body through generic element paths."
  (let* ((filing (edgar-fixtures-filing "18-k-chile"))
         (html (edgar-fixtures-html "18-k-chile")))
    (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) html)))
      (let ((body (edgar-section filing '("html" "body"))))
        (should (stringp body))
        (should (string-match-p "FORM 18-K" body))
        (should (string-match-p "In respect of each issue" body))))))

(ert-deftest edgar-named-section-extraction-matches-reviewed-goldens ()
  "Named section output stays pinned across distinct prospectus layouts."
  (let ((goldens
         (edgar-fixtures-read
          (edgar-fixtures-path "golden-named-sections.eld"))))
    (dolist (golden goldens)
      (let* ((slug (nth 0 golden))
             (name (nth 1 golden))
             (fragment (nth 2 golden))
             (filing (edgar-fixtures-filing slug))
             (html (edgar-fixtures-html slug)))
        (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) html)))
          (let ((body (edgar-section filing name)))
            (should (stringp body))
            (should
             (string-match-p (regexp-quote fragment) body))))))))

(ert-deftest edgar-g10-registration-fixtures-use-generic-section-api
    ()
  "Real G10 filings are readable and expose generic Item sections."
  (let* ((summary (edgar-fixtures-filing "497k-hennessy"))
         (summary-html (edgar-fixtures-html "497k-hennessy"))
         (registration (edgar-fixtures-filing "n-1a-americandrive"))
         (registration-html
          (edgar-fixtures-html "n-1a-americandrive")))
    (cl-letf (((symbol-function 'edgar--fetch)
               (lambda (_) summary-html)))
      (should
       (string-match-p
        "long-term capital appreciation"
        (downcase (edgar-text summary)))))
    (cl-letf (((symbol-function 'edgar--fetch)
               (lambda (_) registration-html)))
      (let ((body (edgar-section registration "28")))
        (should (stringp body))
        (should (string-match-p "exhibits" (downcase body)))))))

(ert-deftest edgar-g10-additional-layouts-use-generic-structure-api ()
  "Real G10 application, registration, supplement, and letter layouts work."
  (dolist (expected
           (edgar-fixtures-read
            (edgar-fixtures-path
             "expect/g10-additional-structures.eld")))
    (let* ((slug (plist-get expected :slug))
           (filing (edgar-fixtures-filing slug))
           (html (edgar-fixtures-html slug)))
      (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) html)))
        (let* ((tree (edgar-document-structure filing))
               (paragraphs (edgar-structure-paragraphs tree))
               (tables (edgar-structure-nodes tree "table"))
               (heading (plist-get expected :heading))
               (body (and heading (edgar-section filing heading))))
          (should (eq (plist-get tree :format) 'html))
          (should
           (>= (length paragraphs)
               (plist-get expected :min-paragraphs)))
          (should
           (>= (length tables) (plist-get expected :min-tables)))
          (should
           (seq-some
            (lambda (paragraph)
              (string-match-p
               (regexp-quote
                (edgar-fixtures-norm
                 (plist-get expected :paragraph-marker)))
               (edgar-fixtures-norm paragraph)))
            paragraphs))
          (when heading
            (should (stringp body))
            (should
             (string-match-p
              (regexp-quote
               (plist-get expected :body-marker))
              body))))))))

(ert-deftest edgar-g12-xml-fixtures-use-generic-tree-api ()
  "Real G12 XML filings work through the generic structure API."
  (dolist (slug
           '("x-17a-5-m-stevens"
             "ma-i-ey-2026"
             "ta-2-edward-jones-2026"))
    (let* ((filing (edgar-fixtures-filing slug))
           (xml
            (with-temp-buffer
              (insert-file-contents
               (edgar-fixtures-path (format "fixtures/%s.xml" slug)))
              (buffer-string)))
           (expected
            (edgar-fixtures-read
             (edgar-fixtures-path (format "expect/%s.eld" slug)))))
      (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) xml)))
        (let ((tree (edgar-document-structure filing)))
          (should (eq (plist-get tree :format) 'xml))
          (dolist (entry (plist-get expected :sections))
            (should
             (equal
              (plist-get
               (edgar-structure-section tree (car entry))
               :body)
              (cadr entry)))))))))

(ert-deftest
    edgar-g12-corresp-text-fixture-is-readable-through-generic-api
    ()
  "A CORRESP complete submission works through the generic text API."
  (let* ((filing (edgar-fixtures-filing "corresp-sce-2025"))
         (text
          (with-temp-buffer
            (insert-file-contents
             (edgar-fixtures-path "fixtures/corresp-sce-2025.txt"))
            (buffer-string)))
         (expected
          (edgar-fixtures-read
           (edgar-fixtures-path "expect/corresp-sce-2025.eld"))))
    (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) text)))
      (let* ((tree (edgar-document-structure filing))
             (document-text (edgar-structure-text tree)))
        (should (eq (plist-get tree :format) 'text))
        (dolist (marker (plist-get expected :markers))
          (should (string-match-p marker document-text)))
        (should (> (length (edgar-structure-paragraphs tree)) 1))
        (should (string-match-p "</HTML>" document-text))))))

(ert-deftest edgar-g12-upload-fixture-uses-generic-text-api ()
  "A real SEC UPLOAD text extract works through the generic structure API."
  (let* ((slug "upload-irenic-2026")
         (filing (edgar-fixtures-filing slug))
         (text
          (with-temp-buffer
            (insert-file-contents
             (edgar-fixtures-path (format "fixtures/%s.txt" slug)))
            (buffer-string)))
         (expected
          (edgar-fixtures-read
           (edgar-fixtures-path (format "expect/%s.eld" slug)))))
    (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) text)))
      (let* ((tree (edgar-document-structure filing))
             (document-text (edgar-structure-text tree)))
        (should (eq (plist-get tree :format) 'text))
        (dolist (marker (plist-get expected :markers))
          (should (string-match-p marker document-text)))
        (should (> (length (edgar-structure-paragraphs tree)) 2))))))

(ert-deftest
    edgar-document-structure-preserves-html-sections-and-paragraphs
    ()
  (let* ((html
          (concat
           "<html><body><section title='Financials'>"
           "<h2>Risk Factors</h2><p>Risks include liquidity.</p>"
           "<h3>Mitigation</h3><p>We monitor cash.</p>"
           "<h2>Cash</h2><p>Cash balance is stable.</p>"
           "</section></body></html>"))
         (filing '(:url "https://example.invalid/report.htm")))
    (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) html)))
      (let* ((tree (edgar-document-structure filing))
             (section (edgar-structure-section tree "Risk Factors")))
        (should (eq (plist-get tree :format) 'html))
        (should
         (equal
          (plist-get section :path) '("Financials" "Risk Factors")))
        (should
         (string-match-p
          "Risks include liquidity" (plist-get section :body)))
        (should
         (equal
          (plist-get
           (edgar-structure-section
            tree '("Financials" "Risk Factors"))
           :body)
          (plist-get section :body)))
        (should
         (string-match-p "Mitigation" (plist-get section :body)))
        (should-not
         (string-match-p "Cash balance" (plist-get section :body)))
        (should
         (equal
          (edgar-structure-paragraphs tree)
          '("Risks include liquidity."
            "We monitor cash."
            "Cash balance is stable.")))))))

(ert-deftest edgar-document-structure-supports-xml-and-plain-text ()
  (let ((xml-filing '(:url "https://example.invalid/report.xml"))
        (text-filing '(:url "https://example.invalid/complete.txt")))
    (cl-letf
        (((symbol-function 'edgar--fetch)
          (lambda (url)
            (if (string-suffix-p ".xml" url)
                "<report><RiskFactors><p>Risk data</p></RiskFactors></report>"
              "First paragraph.\n\nSecond paragraph."))))
      (let* ((xml (edgar-document-structure xml-filing))
             (risk (edgar-structure-section xml "RiskFactors"))
             (text (edgar-document-structure text-filing)))
        (should (eq (plist-get xml :format) 'xml))
        (should (equal (plist-get risk :body) "Risk data"))
        (should
         (equal
          (plist-get
           (edgar-structure-section xml '("report" "RiskFactors"))
           :body)
          "Risk data"))
        (should
         (equal (edgar-section xml-filing "RiskFactors") "Risk data"))
        (should
         (equal (edgar-structure-paragraphs xml) '("Risk data")))
        (should (eq (plist-get text :format) 'text))
        (should-not (edgar-structure-headings text))
        (should
         (equal
          (edgar-structure-paragraphs text)
          '("First paragraph." "Second paragraph.")))
        (should
         (equal
          (edgar-structure-text text)
          "First paragraph.\n\nSecond paragraph."))))))

(ert-deftest edgar-complete-submission-selects-primary-legacy-text ()
  (let* ((fixture-dir (expand-file-name "fixtures" edgar-test--dir))
         (fixture (expand-file-name "10-k-bd-1998.txt" fixture-dir))
         (filing
          (with-temp-buffer
            (insert-file-contents-literally
             (expand-file-name "10-k-bd-1998.eld" fixture-dir))
            (read (current-buffer))))
         (submission
          (with-temp-buffer
            (insert-file-contents-literally fixture)
            (buffer-string))))
    (cl-letf (((symbol-function 'edgar--fetch)
               (lambda (_) submission)))
      (let ((text (edgar-text filing)))
        (should (string-match-p "ITEM 1\\.  BUSINESS" text))
        (should-not (string-match-p "SEC-DOCUMENT" text))
        (should-not (string-match-p "EXHIBIT CONTENT" text))
        (should
         (string-match-p "manufacture and sale of a broad" text))
        (should
         (string-match-p "Franklin Lakes" (edgar-section filing "2")))
        (should
         (string-match-p
          "natural[[:space:]]+rubber latex"
          (edgar-section filing "3")))
        (should
         (equal
          (mapcar #'car (edgar-sections text))
          '("I.1" "I.2" "I.3")))))))

(ert-deftest
    edgar-named-sections-recognizes-generic-uppercase-headings
    ()
  (let*
      ((sections
        (edgar-named-sections
         "OVERVIEW\nA complete opening paragraph.\n\nRISK FACTORS\nSpecific risks follow.\nItem 1. Detail\nmore."))
       (overview (car sections))
       (risk (cadr sections)))
    (should
     (equal
      (mapcar
       (lambda (section) (plist-get section :name)) sections)
      '("OVERVIEW" "RISK FACTORS")))
    (should
     (string-match-p "opening paragraph" (plist-get overview :body)))
    (should (string-match-p "Specific risks" (plist-get risk :body)))
    (should-not (string-match-p "Item 1" (plist-get risk :body)))))

(ert-deftest
    edgar-structure-section-requires-path-for-duplicate-headings
    ()
  (let*
      ((html
        "<html><body><h2>Notes</h2><p>First.</p><h2>Notes</h2><p>Second.</p></body></html>")
       (tree
        (with-temp-buffer
          (insert html)
          (list
           :type 'document
           :format 'html
           :children
           (list
            (edgar--structure-node
             (libxml-parse-html-region (point-min) (point-max))))))))
    (should-error
     (edgar-structure-section tree "Notes")
     :type 'user-error)))

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
