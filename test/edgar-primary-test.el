;;; edgar-primary-test.el --- Primary-document and interactive tests for edgar.el -*- lexical-binding: t; -*-

;;; Commentary:

;; Primary-document and interactive tests for edgar.el.
;; Shares helpers with `edgar-test-support'.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'subr-x)
(require 'edgar-test-support)

(ert-deftest edgar-g12-uuencoded-pdf-sources-match-reviewed-snapshots
    ()
  "Real G12 complete-submission PDFs decode and match direct SEC sources."
  (dolist (expected
           (edgar-fixtures-read
            (edgar-fixtures-path "expect/g12-pdf-structures.eld")))
    (let* ((slug (plist-get expected :slug))
           (filing (edgar-fixtures-filing slug))
           (submission-filing
            (edgar-test--g12-submission-filing filing))
           (submission (edgar-fixtures-submission slug))
           (pdf (edgar-fixtures-primary slug)))
      (cl-letf (((symbol-function 'edgar--fetch)
                 (lambda (url)
                   (if (string-suffix-p ".txt" url)
                       submission
                     pdf))))
        (let* ((primary (edgar-primary-document submission-filing))
               (submission-tree
                (edgar-document-structure submission-filing))
               (direct-tree (edgar-document-structure filing))
               (info (edgar-form-info (plist-get filing :form))))
          (should (eq (plist-get info :level) 'L1))
          (should (eq (plist-get info :backend) 'pdf))
          (should (eq (plist-get primary :format) 'pdf-uuencoded))
          (should (equal (edgar--document-pdf-bytes primary) pdf))
          (should
           (equal
            (plist-get expected :submission-snapshot)
            (edgar-test--document-snapshot
             submission-filing submission-tree)))
          (should
           (equal
            (plist-get expected :direct-snapshot)
            (edgar-test--document-snapshot filing direct-tree)))
          (dolist (tree (list submission-tree direct-tree))
            (dolist (name
                     (plist-get
                      (plist-get expected :direct-snapshot)
                      :named-section-head))
              (let ((section (edgar-structure-section tree name)))
                (should section)
                (should
                 (> (length (plist-get section :body))
                    (length name)))))))))))

(ert-deftest
    edgar-g12-paper-controls-document-unavailable-report-bodies
    ()
  "Recorded SEC paper notices have L1 snapshots; original reports are absent."
  (dolist (expected
           (edgar-fixtures-read
            (edgar-fixtures-path "expect/g12-paper-structures.eld")))
    (let* ((slug (plist-get expected :slug))
           (per-filing-expected
            (edgar-fixtures-read
             (edgar-fixtures-path (format "expect/%s.eld" slug))))
           (filing (edgar-fixtures-filing slug))
           (submission-filing
            (edgar-test--g12-submission-filing filing))
           (submission (edgar-fixtures-submission slug))
           (paper (edgar-fixtures-paper slug)))
      (cl-letf (((symbol-function 'edgar--fetch)
                 (lambda (_) submission)))
        (let* ((primary (edgar-primary-document submission-filing))
               (tree (edgar-document-structure submission-filing))
               (text (edgar-structure-text tree))
               (rendered-text (edgar-text submission-filing))
               (info (edgar-form-info (plist-get filing :form))))
          (should (equal expected per-filing-expected))
          (should (eq (plist-get info :level) 'L1))
          (should (eq (plist-get info :backend) 'text))
          (should (string-match-p "original report body is absent"
                                  (plist-get info :notes)))
          (should (equal (plist-get primary :sequence) "1"))
          (should
           (equal
            (plist-get primary :description)
            "AUTO-GENERATED PAPER DOCUMENT"))
          (should
           (string-match-p
            "generated as part of a paper submission" text))
          (should
           (string-match-p
            (regexp-quote (plist-get expected :control-number)) text))
          (should
           (equal
            (plist-get expected :paper-sha256)
            (secure-hash 'sha256 paper)))
          (should
           (equal
            (plist-get expected :document-snapshot)
            (edgar-test--document-snapshot
             submission-filing tree)))
          (should
           (equal
            (plist-get expected :edgar-text-snapshot)
            (list
             :text-length (length rendered-text)
             :text-sha256
             (secure-hash 'sha256 rendered-text)))))))))

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
             (metadata (plist-get tree :primary-document))
             (document-text (edgar-structure-text tree)))
        (should (eq (plist-get tree :format) 'text))
        (should (equal (plist-get metadata :type) "TEXT-EXTRACT"))
        (should (equal (plist-get metadata :sequence) "2"))
        (should
         (equal (plist-get metadata :filename) "filename2.txt"))
        (should (eq (plist-get metadata :format) 'text))
        (dolist (marker (plist-get expected :markers))
          (should (string-match-p marker document-text)))
        (should (> (length (edgar-structure-paragraphs tree)) 2))
        (should
         (equal
          (plist-get expected :document-snapshot)
          (edgar-test--document-snapshot filing tree)))))))

(ert-deftest edgar-g12-paper-source-limits-remain-visible ()
  "G12 paper notices are L1 while original report bodies remain absent."
  (dolist (form '("ADV-H-T" "G-FIN"))
    (let ((info (edgar-form-info form)))
      (should (eq (plist-get info :level) 'L1))
      (should (stringp (plist-get info :notes)))
      (should-not (string-empty-p (plist-get info :notes))))))

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

(ert-deftest edgar-html-url-can-contain-an-sgml-primary-wrapper ()
  "Select the form-matching primary from a wrapped document at an HTML URL."
  (let*
      ((filing
        '(:form
          "15-12G"
          :accn "0000000000-26-000003"
          :cik 3
          :doc "MainDocument.htm"
          :url "https://example.invalid/MainDocument.htm"))
       (submission
        (concat
         "<DOCUMENT><TYPE>EX-99\n<FILENAME>exhibit.htm\n<TEXT>"
         "<html><body><p>Unrelated exhibit text.</p></body></html>"
         "</TEXT></DOCUMENT>"
         "<DOCUMENT><TYPE>15-12G\n<FILENAME>MainDocument.htm\n<TEXT>"
         "<html><body><h1>Form 15-12G</h1>"
         "<p>Primary filing text.</p></body></html>"
         "</TEXT></DOCUMENT>")))
    (cl-letf (((symbol-function 'edgar--fetch)
               (lambda (_) submission)))
      (let* ((text (edgar-text filing))
             (tree (edgar-document-structure filing))
             (primary
              (plist-get
               (plist-get
                (plist-get tree :metadata)
                :primary-document)
               :name)))
        (should (string-match-p "Primary filing text" text))
        (should-not (string-match-p "<html>" text))
        (should-not (string-match-p "Unrelated exhibit text" text))
        (should (eq (plist-get tree :format) 'html))
        (should (equal primary "MainDocument.htm"))
        (should
         (equal
          (plist-get
           (plist-get (plist-get tree :metadata) :primary-document)
           :type)
          "15-12G"))
        (should
         (string-match-p
          "Primary filing text" (edgar-structure-text tree)))
        (should-not
         (string-match-p
          "Unrelated exhibit text" (edgar-structure-text tree)))))))

(ert-deftest edgar-document-structure-supports-xml-and-plain-text ()
  (let ((xml-filing
         '(:form
           "TEST-XML"
           :accn "0000000000-26-000001"
           :cik 1
           :doc "report.xml"
           :url "https://example.invalid/report.xml"))
        (text-filing
         '(:form
           "TEST-TEXT"
           :accn "0000000000-26-000002"
           :cik 2
           :doc "complete.txt"
           :url "https://example.invalid/complete.txt")))
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
        (should
         (equal
          (plist-get (plist-get xml :metadata) :accn)
          "0000000000-26-000001"))
        (should
         (equal
          (plist-get
           (plist-get (plist-get xml :metadata) :primary-document)
           :name)
          "report.xml"))
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

(ert-deftest edgar-structure-section-scopes-linked-html-target-paragraphs ()
  "Contents links resolve named anchors to scoped generic paragraphs."
  (let* ((html
          (concat
           "<html><body><nav><p><a href='#risk'>Risk Factors</a></p>"
           "<p><a href='#liquidity'>Liquidity</a></p></nav>"
           "<a id='risk'></a><p>Risk Factors</p><p>Risk detail.</p>"
           "<a id='liquidity'></a><p>Liquidity</p>"
           "<p>Liquidity detail.</p></body></html>"))
         (filing '(:url "https://example.invalid/report.htm")))
    (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) html)))
      (let* ((tree (edgar-document-structure filing))
             (section (edgar-structure-section tree "Risk Factors")))
        (should section)
        (should
         (equal (edgar-structure-paragraphs section) '("Risk detail.")))
        (should-not
         (member "Liquidity detail."
                 (edgar-structure-paragraphs section)))))))

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
          (mapcar #'car (edgar-sections text)) '("I.1" "I.2" "I.3")))
        (let ((document (edgar-primary-document filing)))
          (should (equal (plist-get document :type) "10-K"))
          (should (equal (plist-get document :sequence) "1"))
          (should-not (plist-get document :filename))
          (should
           (equal (plist-get document :description) "FORM 10-K"))
          (should (eq (plist-get document :format) 'text))
          (should
           (string-match-p
            "ITEM 1\\.  BUSINESS" (plist-get document :content))))))))

(ert-deftest edgar-primary-document-identifies-uuencoded-pdf ()
  "Complete-submission metadata identifies a uuencoded PDF primary."
  (let*
      ((filing
        '(:form "NRSRO-CE" :url "https://example.invalid/filing.txt"))
       (submission
        (concat
         "<DOCUMENT>\n<TYPE>NRSRO-CE\n<SEQUENCE>1\n"
         "<FILENAME>notice.pdf\n<TEXT>\n<PDF> begin 644 notice.pdf\n"
         "M)5!$1BTQ\n</TEXT>\n</DOCUMENT>")))
    (cl-letf (((symbol-function 'edgar--fetch)
               (lambda (_) submission)))
      (let ((document (edgar-primary-document filing)))
        (should (eq (plist-get document :format) 'pdf-uuencoded))
        (should (equal (plist-get document :filename) "notice.pdf"))
        (should (equal (plist-get document :sequence) "1"))
        (should (equal (plist-get document :type) "NRSRO-CE"))))))

(ert-deftest edgar-primary-document-identifies-direct-pdf ()
  "Direct PDF metadata remains readable without parsing its body."
  (let ((filing
         '(:form
           "NRSRO-CE"
           :doc "notice.pdf"
           :url "https://example.invalid/notice.pdf")))
    (cl-letf (((symbol-function 'edgar--fetch)
               (lambda (_) "%PDF-1.7\nnot extracted")))
      (let ((document (edgar-primary-document filing)))
        (should (eq (plist-get document :format) 'pdf))
        (should (equal (plist-get document :filename) "notice.pdf"))
        (should
         (equal
          (plist-get document :content)
          "%PDF-1.7\nnot extracted"))))))

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

(provide 'edgar-primary-test)

;;; edgar-primary-test.el ends here
