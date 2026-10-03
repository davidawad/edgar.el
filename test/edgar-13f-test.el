;;; edgar-13f-test.el --- Tests for Form 13F holdings -*- lexical-binding: t; -*-

;;; Code:

(require 'ert)
(require 'edgar-13f)

(defconst edgar-13f-test--directory
  (file-name-directory (or load-file-name buffer-file-name)))

(defun edgar-13f-test--read (file)
  "Read Lisp object from FILE."
  (with-temp-buffer
    (insert-file-contents file)
    (read (current-buffer))))

(defun edgar-13f-test--filing (slug)
  "Read fixture metadata for filing SLUG."
  (edgar-13f-test--read
   (expand-file-name (concat "fixtures/" slug ".eld")
                     edgar-13f-test--directory)))

(defun edgar-13f-test--xml (slug)
  "Read information-table XML fixture SLUG."
  (with-temp-buffer
    (insert-file-contents
     (expand-file-name (concat "fixtures/" slug ".xml")
                       edgar-13f-test--directory))
    (buffer-string)))

(defun edgar-13f-test--golden (slug)
  "Read typed field golden SLUG."
  (edgar-13f-test--read
   (expand-file-name (concat "golden-fields/" slug ".eld")
                     edgar-13f-test--directory)))

(defun edgar-13f-test--fields (holdings)
  "Return public fields for HOLDINGS as plists."
  (mapcar
   (lambda (holding)
     (list :issuer (edgar-13f-holding-issuer holding)
           :class (edgar-13f-holding-class holding)
           :cusip (edgar-13f-holding-cusip holding)
           :value (edgar-13f-holding-value holding)
           :shares (edgar-13f-holding-shares holding)
           :share-type (edgar-13f-holding-share-type holding)
           :put-call (edgar-13f-holding-put-call holding)
           :discretion (edgar-13f-holding-discretion holding)
           :other-manager (edgar-13f-holding-other-manager holding)
           :voting-sole (edgar-13f-holding-voting-sole holding)
           :voting-shared (edgar-13f-holding-voting-shared holding)
           :voting-none (edgar-13f-holding-voting-none holding)))
   holdings))

(defun edgar-13f-test--run (slug document-name)
  "Read holdings for SLUG, serving DOCUMENT-NAME from offline fixture."
  (let* ((filing (edgar-13f-test--filing slug))
         (index
          (format
           "{\"directory\":{\"item\":[{\"name\":\"%s\",\"size\":\"1\"}]}}"
           document-name)))
    (cl-letf (((symbol-function 'edgar--fetch)
               (lambda (url)
                 (if (string-suffix-p "/index.json" url)
                     index
                   (edgar-13f-test--xml slug)))))
      (edgar-13f-holdings filing))))

(ert-deftest edgar-13f-current-information-table-matches-golden ()
  "Read holdings from the separate current information-table XML."
  (should
   (equal (edgar-13f-test--fields
           (edgar-13f-test--run "13f-hr-brk-b" "56757.xml"))
          (edgar-13f-test--golden "13f-hr-brk-b"))))

(ert-deftest edgar-13f-older-values-are-scaled-from-thousands ()
  "Normalize pre-2023 reported thousands to dollars."
  (should
   (equal (edgar-13f-test--fields
           (edgar-13f-test--run
            "13f-hr-brk-b-prior" "form13fInfoTable.xml"))
          (edgar-13f-test--golden "13f-hr-brk-b-prior"))))

(ert-deftest edgar-13f-holdings-returns-nil-for-other-forms ()
  "Ignore non-13F-HR forms."
  (should-not (edgar-13f-holdings '(:form "13F-NT"))))

(ert-deftest edgar-13f-handles-ten-thousand-holdings ()
  "Parse a large information table without dropping rows."
  (let* ((row
          (concat
           "<infoTable><nameOfIssuer>Issuer</nameOfIssuer>"
           "<titleOfClass>COM</titleOfClass><cusip>000000000</cusip>"
           "<value>12</value><shrsOrPrnAmt><sshPrnamt>4</sshPrnamt>"
           "<sshPrnamtType>SH</sshPrnamtType></shrsOrPrnAmt>"
           "<investmentDiscretion>SOLE</investmentDiscretion>"
           "<votingAuthority><Sole>4</Sole><Shared>0</Shared>"
           "<None>0</None></votingAuthority></infoTable>"))
         (xml (concat
               "<informationTable>"
               (mapconcat (lambda (_) row) (number-sequence 1 10000) "")
               "</informationTable>"))
         (filing '(:form "13F-HR" :filed "2026-08-14"
                   :url "https://www.sec.gov/Archives/edgar/data/1/2/primary_doc.xml")))
    (cl-letf (((symbol-function 'edgar-documents)
               (lambda (_)
                 '((:name "56757.xml"
                    :url "https://www.sec.gov/Archives/edgar/data/1/2/56757.xml"))))
              ((symbol-function 'edgar--fetch) (lambda (_) xml)))
      (should (= 10000 (length (edgar-13f-holdings filing)))))))

(provide 'edgar-13f-test)
;;; edgar-13f-test.el ends here
