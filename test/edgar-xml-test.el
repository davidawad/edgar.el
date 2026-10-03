;;; edgar-xml-test.el --- Tests for raw XML filing support -*- lexical-binding: t; -*-

;;; Code:

(require 'ert)
(require 'cl-lib)
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
  (list :count (length holdings)
        :sha256 (secure-hash 'sha256 (prin1-to-string holdings))
        :first (car holdings)))

(ert-deftest edgar-13f-holdings-match-recorded-tables-and-value-vintages ()
  "Match every recorded Berkshire holding across dollar-reporting vintages."
  (dolist (case '(("13f-hr-brk-b" . "usd")
                  ("13f-hr-brk-b-prior" . "thousands")))
    (let* ((slug (car case))
           (metadata (edgar-xml-test--13f-metadata slug))
           (fixture (edgar-xml-test--13f-fixture slug))
           (holdings nil))
      (cl-letf (((symbol-function 'edgar--fetch)
                 (lambda (url)
                   (should (equal url (plist-get metadata :info-url)))
                   fixture)))
        (setq holdings (edgar-13f-holdings metadata)))
      (should (equal (edgar-xml-test--13f-snapshot holdings)
                     (edgar-xml-test--13f-golden slug)))
      (should (eq (plist-get (car holdings) :value-unit)
                  (intern (cdr case)))))))

(ert-deftest edgar-13f-finds-information-table-in-accession-index ()
  "Resolve the separate table XML using the SEC accession index."
  (let* ((metadata (edgar-xml-test--13f-metadata "13f-hr-brk-b"))
         (index "{\"directory\":{\"item\":[{\"name\":\"primary_doc.xml\",\"type\":\"XML\"},{\"name\":\"56757.xml\",\"type\":\"INFORMATION TABLE\"}]}}")
         (requests nil))
    (cl-letf (((symbol-function 'edgar--fetch)
               (lambda (url)
                 (push url requests)
                 (if (string-suffix-p "/index.json" url)
                     index
                   (edgar-xml-test--13f-fixture "13f-hr-brk-b")))))
      (let ((filing (plist-put (copy-sequence metadata) :info-url nil)))
        (should (= (length (edgar-13f-holdings filing)) 89)))
      (should (equal (nreverse requests)
                     '("https://www.sec.gov/Archives/edgar/data/1067983/000119312526352200/index.json"
                       "https://www.sec.gov/Archives/edgar/data/1067983/000119312526352200/56757.xml"))))))

(provide 'edgar-xml-test)
;;; edgar-xml-test.el ends here
