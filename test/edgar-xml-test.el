;;; edgar-xml-test.el --- Tests for raw XML filing support -*- lexical-binding: t; -*-

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'edgar-xml)

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

(provide 'edgar-xml-test)
;;; edgar-xml-test.el ends here
