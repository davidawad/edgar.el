;;; edgar-structure-test.el --- Generic structure API tests for edgar.el -*- lexical-binding: t; -*-

;;; Commentary:

;; Generic structure API tests for edgar.el.
;; Shares helpers with `edgar-test-support'.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'subr-x)
(require 'edgar-test-support)

(ert-deftest edgar-8ka-generic-item-sections-are-addressable ()
  "A real 8-K/A exposes dotted Items through the generic section API."
  (let* ((filing (edgar-fixtures-filing "8ka-mdxg-2026"))
         (html (edgar-fixtures-html "8ka-mdxg-2026")))
    (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) html)))
      (dolist (entry
               '(("1.01"
                  .
                  "Entry into a Material Definitive Agreement")
                 ("7.01" . "Regulation FD Disclosure")
                 ("9.01" . "Financial Statements and Exhibits")))
        (let ((body (edgar-section filing (car entry))))
          (should (stringp body))
          (should
           (string-match-p (regexp-quote (cdr entry)) body)))))))

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
      (let* ((tree (edgar-document-structure filing))
             (primary (plist-get tree :primary-document))
             (body-section
              (edgar-structure-section tree '("html" "body")))
             (body (plist-get body-section :body)))
        (should (eq 'html (plist-get tree :format)))
        (should
         (string-match-p
          "FORM 18-K" (plist-get primary :description)))
        (should (stringp body))
        (should (string-match-p "ANNUAL REPORT" body))
        (should (string-match-p "In respect of each issue" body))
        (should-not (string-match-p "FORM 18-K" body))))))

(ert-deftest edgar-form25-generic-document-subtrees-are-addressable ()
  "A real Form 25 supports generic HTML body access."
  (let* ((filing (edgar-fixtures-filing "form25-walmart"))
         (html (edgar-fixtures-html "form25-walmart")))
    (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) html)))
      (let ((body (edgar-section filing '("html" "body"))))
        (should (stringp body))
        (should (string-match-p "Walmart Inc." body))
        (should (string-match-p "FORM 25" body))))))

(ert-deftest edgar-named-section-extraction-matches-reviewed-goldens
    ()
  "Named section output stays pinned across reviewed filing layouts."
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
             (string-match-p
              (regexp-quote (edgar-fixtures-norm fragment))
              (edgar-fixtures-norm body)))))))))

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

(ert-deftest edgar-g10-remaining-l0-filings-use-generic-structure-api
    ()
  "The remaining real G10 filings work through the generic structure API."
  (dolist (case
           '(("40-24b2-hit-investment" html)
             ("40-17f2-fundrise" html)
             ("40-33-180degree" html)
             ("40-8f-2-chesapeake" html)
             ("app-ntc-advisors-preferred" pdf)
             ("app-ordr-great-elm" pdf)
             ("app-wd-guggenheim" html)
             ("app-wdg-peartree" pdf)
             ("ct-order-janus-henderson" pdf)
             ("del-am-jpmorgan" html)
             ("n-2mef-ives-ultra" html)
             ("n-2-posasr-eagle-point" html)
             ("msd-state-street" text "9999999997-12-000716.paper")))
    (let* ((slug (car case))
           (format (cadr case))
           (filing (edgar-fixtures-filing slug))
           (expected-filename
            (or (nth 2 case) (plist-get filing :doc)))
           (source (edgar-fixtures-primary slug)))
      (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) source)))
        (let* ((info (edgar-form-info (plist-get filing :form)))
               (tree (edgar-document-structure filing))
               (primary (plist-get tree :primary-document))
               (paragraphs (edgar-structure-paragraphs tree))
               (text (edgar-structure-text tree)))
          (should (eq (plist-get info :level) 'L1))
          (should (eq (plist-get info :backend) format))
          (should (eq (plist-get tree :type) 'document))
          (should (eq (plist-get tree :format) format))
          (should (eq (plist-get primary :format) format))
          (should (plist-get primary :readable))
          (should
           (equal (plist-get primary :type) (plist-get filing :form)))
          (should
           (equal (plist-get primary :filename) expected-filename))
          (should (listp paragraphs))
          (should (seq-every-p #'stringp paragraphs))
          (should (> (length (string-trim text)) 0)))))))

(ert-deftest edgar-g10-second-batch-uses-generic-structure-api ()
  "Real G10 XML and rendered layouts work without form-specific switches."
  (dolist (expected
           (edgar-fixtures-read
            (edgar-fixtures-path
             "expect/g10-second-batch-structures.eld")))
    (let* ((slug (plist-get expected :slug))
           (format (plist-get expected :format))
           (filing (edgar-fixtures-filing slug))
           (per-filing-expected
            (and (eq format 'xml)
                 (edgar-fixtures-read
                  (edgar-fixtures-path
                   (format "expect/%s.eld" slug)))))
           (source
            (if (eq format 'xml)
                (with-temp-buffer
                  (insert-file-contents
                   (edgar-fixtures-path
                    (format "fixtures/%s.xml" slug)))
                  (buffer-string))
              (edgar-fixtures-html slug))))
      (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) source)))
        (let* ((tree (edgar-document-structure filing))
               (paragraphs (edgar-structure-paragraphs tree))
               (tables (edgar-structure-nodes tree "table"))
               (text
                (edgar-fixtures-norm (edgar-structure-text tree)))
               (section-name (plist-get expected :section))
               (section
                (and section-name
                     (edgar-section filing section-name)))
               (node-name (plist-get expected :node-name))
               (nodes
                (and node-name
                     (edgar-structure-nodes tree node-name))))
          (when per-filing-expected
            (should (equal (cddr expected) per-filing-expected)))
          (should (eq (plist-get tree :format) format))
          (should
           (>= (length paragraphs)
               (plist-get expected :min-paragraphs)))
          (should
           (>= (length tables) (plist-get expected :min-tables)))
          (should
           (string-match-p
            (regexp-quote (plist-get expected :text-marker)) text))
          (when section-name
            (should (stringp section))
            (should
             (string-match-p
              (regexp-quote
               (plist-get expected :body-marker))
              section)))
          (when node-name
            (should nodes)
            (should
             (seq-some
              (lambda (node)
                (string-match-p
                 (regexp-quote (plist-get expected :node-marker))
                 (edgar-structure-text node)))
              nodes))))))))

(ert-deftest edgar-sampled-filings-match-generic-structure-snapshots
    ()
  "Recorded sampled filings match their generic structure snapshots."
  (let ((expected
         (edgar-fixtures-read
          (edgar-fixtures-path
           "expect/sampled-filings-structures.eld"))))
    (should expected)
    (dolist (record expected)
      (let* ((slug (plist-get record :slug))
             (filing (edgar-fixtures-filing slug))
             (info (edgar-form-info (plist-get filing :form)))
             (primary (edgar-fixtures-primary slug)))
        (should (memq (plist-get info :level) '(L1 L2)))
        (cl-letf (((symbol-function 'edgar--fetch)
                   (lambda (_) primary)))
          (let* ((tree (edgar-document-structure filing))
                 (snapshot
                  (edgar-test--document-snapshot filing tree)))
            (should
             (equal
              snapshot (plist-get record :document-snapshot)))))))))

(ert-deftest edgar-g12-xml-fixtures-use-generic-tree-api ()
  "Real G12 XML filings work through the generic structure API."
  (dolist (slug
           '("x-17a-5-m-stevens"
             "ma-i-ey-2026"
             "ta-2-edward-jones-2026"
             "ats-n-2026-q2"
             "ats-n-ca-2026-q2"
             "ats-n-ma-2026-q2"
             "ats-n-ofa-2026-q2"
             "ats-n-ua-2026-q2"
             "cfportal-2026-q2"
             "cfportal-w-2026-q2"
             "ma-2026-q2"
             "ma-a-2026-q2"
             "ma-w-2026-q2"
             "sbse-2026-q2"
             "sbse-a-2026-q2"
             "sbse-c-2026-q2"
             "ta-1-2026-q2"
             "ta-w-2026-q2"))
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
          (should
           (equal
            (plist-get
             (plist-get tree :primary-document)
             :filename)
            (plist-get filing :doc)))
          (should
           (equal
            (plist-get
             (plist-get tree :primary-document)
             :format)
            'xml))
          (should
           (equal
            (plist-get
             (plist-get tree :primary-document)
             :type)
            (plist-get filing :form)))
          (if (plist-get expected :sections)
              (dolist (entry (plist-get expected :sections))
                (should
                 (equal
                  (plist-get
                   (edgar-structure-section tree (car entry))
                   :body)
                  (cadr entry)))
                (should
                 (equal
                  (edgar-section filing (car entry)) (cadr entry))))
            (should
             (equal
              expected
              (edgar-test--g12-xml-snapshot filing tree)))))))))

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
             (metadata (plist-get tree :primary-document))
             (document-text (edgar-structure-text tree))
             (rendered-text (edgar-text filing)))
        (should (eq (plist-get tree :format) 'html))
        (should (equal (plist-get metadata :type) "CORRESP"))
        (should (equal (plist-get metadata :sequence) "1"))
        (should
         (equal (plist-get metadata :filename) "filename1.htm"))
        (should (eq (plist-get metadata :format) 'html))
        (dolist (marker (plist-get expected :markers))
          (should (string-match-p marker rendered-text)))
        (should (> (length (edgar-structure-paragraphs tree)) 1))
        (should
         (string-match-p
          "Securities and Exchange Commission" document-text))
        (should-not (string-match-p "</HTML>" document-text))
        (should
         (string-match-p
          "Securities and Exchange Commission"
          (plist-get (edgar-structure-section tree "body") :body)))
        (should
         (equal
          (plist-get expected :document-snapshot)
          (edgar-test--document-snapshot filing tree)))))))

(ert-deftest edgar-pdf-primary-uses-generic-text-and-tree-api ()
  "A real SEC PDF primary is readable through the generic APIs."
  (let* ((slug "n-8f-ordr-blackrock")
         (filing (edgar-fixtures-filing slug))
         (pdf (edgar-fixtures-primary slug)))
    (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) pdf)))
      (let* ((text (edgar-text filing))
             (tree (edgar-document-structure filing))
             (primary
              (plist-get
               (plist-get (plist-get tree :metadata) :primary-document)
               :name)))
        (should (string-match-p "ORDER UNDER SECTION 8(f)" text))
        (should (equal primary "filename1.pdf"))
        (should (eq (plist-get tree :format) 'pdf))
        (should (> (length (edgar-structure-paragraphs tree)) 3))
        (should
         (string-match-p
          "applicant has ceased to be an investment company"
          (edgar-structure-text tree)))))))

(ert-deftest edgar-pdf-primary-requires-pdftotext ()
  "A missing PDF converter produces an actionable error."
  (let ((edgar-pdftotext-program "edgar-test-missing-pdftotext"))
    (should-error (edgar--pdf-text "%PDF") :type 'user-error)))

(ert-deftest edgar-uuencoded-pdf-requires-uudecode ()
  "A missing UU decoder produces an actionable error."
  (let ((edgar-uudecode-program "edgar-test-missing-uudecode"))
    (should-error
     (edgar--uuencoded-pdf-bytes "begin 644 file.pdf\n`\nend\n")
     :type 'user-error)))

(provide 'edgar-structure-test)

;;; edgar-structure-test.el ends here
