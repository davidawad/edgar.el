;;; edgar-xml-test.el --- Tests for raw XML filing support -*- lexical-binding: t; -*-

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'edgar-fixtures)
(require 'edgar-xml)
(require 'edgar-13f)

(defconst edgar-xml-test--directory
  (file-name-directory (or load-file-name buffer-file-name))
  "Directory containing XML parser tests.")

(defun edgar-xml-test--fixture (slug)
  "Return XML text from the recorded fixture named SLUG."
  (with-temp-buffer
    (insert-file-contents
     (expand-file-name (concat "fixtures/" slug ".xml")
                       edgar-xml-test--directory))
    (buffer-string)))

(defun edgar-xml-test--parse (slug)
  "Parse recorded XML fixture SLUG without network access."
  (let ((xml (edgar-xml-test--fixture slug)))
    (with-temp-buffer
      (insert xml)
      (libxml-parse-xml-region (point-min) (point-max)))))

(defun edgar-xml-test--expect (slug)
  "Return the expectation recorded for XML fixture SLUG."
  (with-temp-buffer
    (insert-file-contents
     (expand-file-name (concat "expect/" slug ".eld")
                       edgar-xml-test--directory))
    (read (current-buffer))))

(defun edgar-xml-test--projected-value (projected path)
  "Return the projected XML value at element-name PATH."
  (let ((node projected))
    (dolist (key path)
      (setq node
            (if (eq key (car-safe node))
                (cdr node)
              (cdr (assq key node)))))
    node))

(ert-deftest edgar-xml-parses-form-4-fixture ()
  "Parse the recorded Form 4 ownership document."
  (let ((tree (edgar-xml-test--parse "4-aapl")))
    (should (eq (car tree) 'ownershipDocument))
    (should (assoc 'issuer (edgar-xml-project tree)))))

(ert-deftest edgar-xml-parses-form-144-fixture ()
  "Parse the recorded Form 144 submission with a default namespace."
  (let ((tree (edgar-xml-test--parse "144-aapl")))
    (should (eq (car tree) 'edgarSubmission))
    (should (assoc 'headerData (edgar-xml-project tree)))))

(ert-deftest edgar-xml-projects-n-px-notice-report ()
  "Project identifying fields from a recorded N-PX notice filing."
  (let* ((tree (edgar-xml-test--parse "n-px-a4-wealth"))
         (projected (edgar-xml-project tree))
         (header (cdr (assq 'headerData (cdr projected))))
         (filer (cdr (assq 'filerInfo header)))
         (form-data (cdr (assq 'formData (cdr projected))))
         (cover (cdr (assq 'coverPage form-data)))
         (reporting-person (cdr (assq 'reportingPerson cover)))
         (report (cdr (assq 'reportInfo cover))))
    (should
     (equal
      (list
       :root (car tree)
       :submission-type (cdr (assq 'submissionType header))
       :period (cdr (assq 'periodOfReport filer))
       :reporting-person (cdr (assq 'name reporting-person))
       :report-type (cdr (assq 'reportType report)))
      (edgar-xml-test--expect "n-px-a4-wealth")))))

(ert-deftest edgar-text-renders-n-px-xml-primary ()
  "Render the recorded N-PX XML primary through the L1 text API."
  (let ((expect (edgar-xml-test--expect "n-px-a4-wealth"))
        (xml (edgar-xml-test--fixture "n-px-a4-wealth")))
    (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) xml)))
      (let ((text
             (edgar-text
              (list :url "https://example.test/primary_doc.xml"))))
        (should
         (string-search (plist-get expect :submission-type) text))
        (should
         (string-search (plist-get expect :reporting-person) text))
        (should
         (string-search (plist-get expect :report-type) text))))))

(ert-deftest edgar-25-nse-generic-xml-elements-match-expectation ()
  "A real Form 25-NSE exposes its filing data through generic XML paths."
  (let* ((filing (edgar-fixtures-filing "25-nse-nrx"))
         (xml (edgar-xml-test--fixture "25-nse-nrx"))
         (expect
          (edgar-fixtures-read
           (edgar-fixtures-path "expect/25-nse-nrx.eld"))))
    (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) xml)))
      (let ((tree (edgar-document-structure filing)))
        (should
         (eq (plist-get tree :format) (plist-get expect :format)))
        (dolist (entry (plist-get expect :sections))
          (should
           (equal
            (plist-get
             (edgar-structure-section tree (car entry))
             :body)
            (cadr entry))))))))

(ert-deftest edgar-xml-g9-reg-a-fixtures-match-reviewed-snapshots ()
  "Read current and older structured Form 1-K and 1-Z primary documents."
  (dolist (slug
           '("index-1-k-2026-q3"
             "index-1-k-2023-q3"
             "index-1-z-2026-q3"
             "index-1-z-2023-q3"))
    (let* ((filing (edgar-fixtures-filing slug))
           (xml (edgar-xml-test--fixture slug))
           (expected (edgar-xml-test--expect slug)))
      (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) xml)))
        (let*
            ((tree (edgar-xml filing))
             (projected (edgar-xml-project tree))
             (form-type (plist-get expected :submission-type))
             (issuer-path
              (if (equal form-type "1-K")
                  '(edgarSubmission formData item1Info issuerName)
                '(edgarSubmission formData item1 issuerName)))
             (summary-path
              (if (equal form-type "1-K")
                  '(edgarSubmission formData summaryInfo)
                '(edgarSubmission formData summaryInfoOffering)))
             (actual
              (list
               :submission-type
               (edgar-xml-test--projected-value
                projected
                '(edgarSubmission headerData submissionType))
               :issuer-name
               (edgar-xml-test--projected-value projected issuer-path)
               :reporting-period
               (edgar-xml-test--projected-value
                projected
                '(edgarSubmission
                  headerData filerInfo reportingPeriod))
               :offering-qualification-date
               (edgar-xml-test--projected-value
                projected
                (append summary-path '(offeringQualificationDate)))
               :offering-securities-sold
               (edgar-xml-test--projected-value
                projected
                (append summary-path '(offeringSecuritiesSold))))))
          (should (eq (car tree) 'edgarSubmission))
          (should (equal actual expected))
          (should
           (string-search
            (plist-get expected :issuer-name)
            (replace-regexp-in-string
             "[ \t\n\r]+" " " (edgar-text filing)))))))))

(ert-deftest edgar-text-renders-not-timely-fund-xml-primaries ()
  "Render recorded NT N-CEN and NT NPORT-P XML through the L1 text API."
  (dolist (case
           '(("nt-n-cen-brown"
              "N-CEN"
              "BROWN CAPITAL MANAGEMENT MUTUAL FUNDS")
             ("nt-nport-p-archer" "NPORT-P" "Archer Growth ETF")))
    (let ((xml (edgar-xml-test--fixture (car case))))
      (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) xml)))
        (let ((text
               (replace-regexp-in-string
                "[ \t\n\r]+" " "
                (edgar-text
                 '(:url "https://example.test/primary_doc.xml")))))
          (should (string-search (cadr case) text))
          (should (string-search (caddr case) text)))))))

(ert-deftest edgar-xml-project-normalizes-prefixed-namespaces ()
  "Project namespace-prefixed elements using their local names."
  (should
   (equal
    (edgar-xml-project
     '(root nil (ns2:issuerName nil "Example")))
    '(root (issuerName . "Example")))))

(ert-deftest edgar-xml-returns-nil-for-non-xml-primary-document ()
  "Do not fetch or parse a filing whose primary document is HTML."
  (should-not
   (edgar-xml '(:url "https://www.sec.gov/Archives/example.htm"))))

(ert-deftest edgar-xml-fetches-raw-xsl-document ()
  "Fetch the raw XML URL after removing the XSL path segment."
  (let ((requested nil)
        (xml (edgar-xml-test--fixture "4-aapl")))
    (cl-letf (((symbol-function 'edgar--fetch)
               (lambda (url)
                 (setq requested url)
                 xml)))
      (should
       (eq
        (car
         (edgar-xml
          '(:url "https://example.test/xslF345X06/form4.xml")))
        'ownershipDocument))
      (should (equal requested "https://example.test/form4.xml")))))

(defun edgar-xml-test--13f-fixture (slug)
  "Return the recorded informationTable XML for 13F fixture SLUG."
  (edgar-xml-test--fixture slug))

(defun edgar-xml-test--13f-metadata (slug)
  "Return fixture metadata for 13F SLUG."
  (with-temp-buffer
    (insert-file-contents
     (expand-file-name (concat "fixtures/" slug ".eld")
                       edgar-xml-test--directory))
    (read (current-buffer))))

(defun edgar-xml-test--13f-golden (slug)
  "Return the typed holdings golden for 13F fixture SLUG."
  (with-temp-buffer
    (insert-file-contents
     (expand-file-name (concat "golden-fields/" slug ".eld")
                       edgar-xml-test--directory))
    (read (current-buffer))))

(defun edgar-xml-test--13f-snapshot (holdings)
  "Return a stable summary of all 13F HOLDINGS."
  (list
   :count (length holdings)
   :sha256 (secure-hash 'sha256 (prin1-to-string holdings))
   :first (car holdings)))

(defun edgar-xml-test--13f-recorded-holdings (slug)
  "Return typed holdings from the recorded 13F fixture SLUG."
  (let ((metadata (edgar-xml-test--13f-metadata slug))
        (fixture (edgar-xml-test--13f-fixture slug)))
    (cl-letf (((symbol-function 'edgar--fetch)
               (lambda (url)
                 (should (equal url (plist-get metadata :info-url)))
                 fixture)))
      (edgar-13f-holdings metadata))))

(defun edgar-xml-test--13f-notice-snapshot (notice)
  "Return all typed fields from 13F NOTICE as a stable plist."
  (list
   :submission-type (edgar-13f-notice-submission-type notice)
   :report-period (edgar-13f-notice-report-period notice)
   :amendment-p (edgar-13f-notice-amendment-p notice)
   :manager-cik (edgar-13f-notice-manager-cik notice)
   :manager-name (edgar-13f-notice-manager-name notice)
   :manager-address (edgar-13f-notice-manager-address notice)
   :report-type (edgar-13f-notice-report-type notice)
   :form-13f-file-number (edgar-13f-notice-form-13f-file-number notice)
   :crd-number (edgar-13f-notice-crd-number notice)
   :sec-file-number (edgar-13f-notice-sec-file-number notice)
   :other-managers (edgar-13f-notice-other-managers notice)
   :signature (edgar-13f-notice-signature notice)))

(ert-deftest
    edgar-13f-holdings-match-recorded-tables-and-value-vintages
    ()
  "Match every recorded holding across filers and dollar-reporting vintages."
  (dolist (case
           '(("13f-hr-brk-b" . "usd")
             ("13f-hr-brk-b-prior" . "thousands")
             ("13f-hr-water-island" . "usd")))
    (let* ((slug (car case))
           (holdings (edgar-xml-test--13f-recorded-holdings slug)))
      (should
       (equal
        (edgar-xml-test--13f-snapshot holdings)
        (edgar-xml-test--13f-golden slug)))
      (should
       (eq
        (plist-get (car holdings) :value-unit)
        (intern (cdr case)))))))

(ert-deftest
    edgar-13f-water-island-preserves-option-and-principal-rows
    ()
  "Preserve optional put/call values and principal-amount security rows."
  (let ((holdings
         (edgar-xml-test--13f-recorded-holdings
          "13f-hr-water-island")))
    (should
     (equal
      (seq-find
       (lambda (holding) (plist-get holding :put-call)) holdings)
      '(:issuer
        "APOGEE THERAPEUTICS INC"
        :class "Equity Put"
        :cusip "03770N951"
        :value "2322775"
        :value-unit usd
        :value-usd 2322775
        :shares "17500"
        :share-type "SH"
        :put-call "Put"
        :discretion "SOLE"
        :other-manager nil
        :voting (:sole "17500" :shared "0" :none "0"))))
    (should
     (equal
      (seq-find
       (lambda (holding)
         (equal (plist-get holding :share-type) "PRN"))
       holdings)
      '(:issuer
        "BENTLEY SYS INC"
        :class "Convertible Bond"
        :cusip "08265TAD1"
        :value "4803323"
        :value-unit usd
        :value-usd 4803323
        :shares "5000000"
        :share-type "PRN"
        :put-call nil
        :discretion "SOLE"
        :other-manager nil
        :voting
        (:sole "5000000" :shared "0" :none "0"))))))

(ert-deftest edgar-13f-notice-matches-recorded-managers-and-signature
    ()
  "Match all typed fields from a recorded 13F-NT with three managers."
  (let* ((slug "13f-nt-newfound")
         (metadata (edgar-xml-test--13f-metadata slug))
         (fixture (edgar-xml-test--13f-fixture slug))
         notice)
    (cl-letf (((symbol-function 'edgar--fetch)
               (lambda (url)
                 (should
                  (equal
                   url
                   (edgar-xml--raw-url (plist-get metadata :url))))
                 fixture)))
      (setq notice (edgar-13f-notice metadata)))
    (should (edgar-13f-notice-p notice))
    (should
     (equal
      (edgar-xml-test--13f-notice-snapshot notice)
      (edgar-xml-test--13f-golden slug)))))

(ert-deftest edgar-13f-notice-layouts-match-distinct-filer-goldens ()
  "Parse two additional 13F-NT filer layouts against typed field goldens."
  (dolist (slug '("13f-nt-rwc" "13f-nt-attucks"))
    (let* ((metadata (edgar-xml-test--13f-metadata slug))
           (fixture (edgar-xml-test--13f-fixture slug))
           notice
           snapshot)
      (cl-letf (((symbol-function 'edgar--fetch)
                 (lambda (url)
                   (should
                    (equal url
                           (edgar-xml--raw-url
                            (plist-get metadata :url))))
                   fixture)))
        (setq notice (edgar-13f-notice metadata)))
      (setq snapshot (edgar-xml-test--13f-notice-snapshot notice))
      (should (edgar-13f-notice-p notice))
      (should (equal snapshot (edgar-xml-test--13f-golden slug)))
      (should
       (equal
        (list :submission-type (plist-get snapshot :submission-type)
              :report-period (plist-get snapshot :report-period)
              :manager-name (plist-get snapshot :manager-name)
              :other-manager-count (length (plist-get snapshot :other-managers))
              :signature-name (plist-get (plist-get snapshot :signature) :name))
        (edgar-xml-test--expect slug))))))

(ert-deftest edgar-13f-fixtures-cover-three-distinct-filers ()
  "Keep the recorded 13F regression corpus at three distinct filer CIKs."
  (let ((ciks
         (mapcar
          (lambda (slug)
            (plist-get (edgar-xml-test--13f-metadata slug) :cik))
          '("13f-hr-brk-b" "13f-hr-water-island" "13f-nt-newfound"))))
    (should (= (length (delete-dups ciks)) 3))))

(ert-deftest edgar-13f-holdings-ignore-notice-filings-without-fetching
    ()
  "Do not seek a nonexistent information table for 13F-NT filings."
  (cl-letf (((symbol-function 'edgar--fetch)
             (lambda (&rest _)
               (ert-fail "13F-NT holdings must not fetch"))))
    (should-not
     (edgar-13f-holdings
      (edgar-xml-test--13f-metadata "13f-nt-newfound")))))

(ert-deftest
    edgar-13f-notice-ignores-holdings-filings-without-fetching
    ()
  "Do not fetch notice XML for 13F-HR filings."
  (cl-letf (((symbol-function 'edgar--fetch)
             (lambda (&rest _)
               (ert-fail "13F-HR notice must not fetch"))))
    (should-not
     (edgar-13f-notice
      (edgar-xml-test--13f-metadata "13f-hr-water-island")))))

(ert-deftest edgar-13f-finds-information-table-in-accession-index ()
  "Resolve the separate table XML using the SEC accession index."
  (let*
      ((metadata (edgar-xml-test--13f-metadata "13f-hr-brk-b"))
       (index
        "{\"directory\":{\"item\":[{\"name\":\"primary_doc.xml\",\"type\":\"XML\"},{\"name\":\"56757.xml\",\"type\":\"INFORMATION TABLE\"}]}}")
       (requests nil))
    (cl-letf (((symbol-function 'edgar--fetch)
               (lambda (url)
                 (push url requests)
                 (if (string-suffix-p "/index.json" url)
                     index
                   (edgar-xml-test--13f-fixture "13f-hr-brk-b")))))
      (let ((filing
             (plist-put (copy-sequence metadata) :info-url nil)))
        (should (= (length (edgar-13f-holdings filing)) 89)))
      (should
       (equal
        (nreverse requests)
        '("https://www.sec.gov/Archives/edgar/data/1067983/000119312526352200/index.json"
          "https://www.sec.gov/Archives/edgar/data/1067983/000119312526352200/56757.xml"))))))

(provide 'edgar-xml-test)
;;; edgar-xml-test.el ends here
