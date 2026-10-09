;;; edgar-13f-test.el --- Form 13F corpus and scale tests -*- lexical-binding: t; -*-

;;; Code:

(require 'cl-lib)
(require 'ert)
(require 'edgar-13f)

(defconst edgar-13f-test--directory
  (file-name-directory (or load-file-name buffer-file-name))
  "Directory containing Form 13F tests and fixtures.")

(defun edgar-13f-test--read (directory slug)
  "Read SLUG.eld under DIRECTORY in the test tree."
  (with-temp-buffer
    (insert-file-contents
     (expand-file-name (concat directory "/" slug ".eld")
                       edgar-13f-test--directory))
    (read (current-buffer))))

(defun edgar-13f-test--xml (slug)
  "Return recorded informationTable XML for SLUG."
  (with-temp-buffer
    (insert-file-contents
     (expand-file-name (concat "fixtures/" slug ".xml")
                       edgar-13f-test--directory))
    (buffer-string)))

(defun edgar-13f-test--holdings (slug)
  "Return typed holdings from the recorded fixture SLUG."
  (let ((filing (edgar-13f-test--read "fixtures" slug))
        (xml (edgar-13f-test--xml slug)))
    (cl-letf (((symbol-function 'edgar--fetch)
               (lambda (url)
                 (should (equal url (plist-get filing :info-url)))
                 xml)))
      (edgar-13f-holdings filing))))

(defun edgar-13f-test--snapshot (holdings)
  "Return a stable full-table summary of HOLDINGS."
  (list
   :count (length holdings)
   :sha256 (secure-hash 'sha256 (prin1-to-string holdings))
   :first (car holdings)))

(defun edgar-13f-test--large-table (count)
  "Return an information table with COUNT copies of a real BlackRock row."
  ;; BlackRock Finance, Inc., 2024-Q2, accession 0001086364-24-008417.
  ;; The SEC source has 48,161 rows; repeating its first row keeps this scale
  ;; regression compact in Git while preserving the filed XML layout.
  (let
      ((row
        "<infoTable><nameOfIssuer>1 800 FLOWERS COM INC</nameOfIssuer><titleOfClass>CL A</titleOfClass><cusip>68243Q106</cusip><value>3426648</value><shrsOrPrnAmt><sshPrnamt>359942</sshPrnamt><sshPrnamtType>SH</sshPrnamtType></shrsOrPrnAmt><investmentDiscretion>SOLE</investmentDiscretion><otherManager>2</otherManager><votingAuthority><Sole>235261</Sole><Shared>0</Shared><None>124681</None></votingAuthority></infoTable>"))
    (with-temp-buffer
      (insert
       "<?xml version=\"1.0\"?><informationTable xmlns=\"http://www.sec.gov/edgar/document/thirteenf/informationtable\">")
      (dotimes (_ count)
        (insert row))
      (insert "</informationTable>")
      (buffer-string))))

(ert-deftest edgar-13f-scion-holdings-match-typed-golden ()
  "Match every holding in a third genuine 13F-HR filer."
  (let ((holdings (edgar-13f-test--holdings "13f-hr-scion")))
    (should
     (equal
      (edgar-13f-test--snapshot holdings)
      (edgar-13f-test--read "golden-fields" "13f-hr-scion")))
    (should
     (seq-some (lambda (row) (plist-get row :put-call)) holdings))))

(ert-deftest edgar-13f-hr-fixtures-cover-three-distinct-filers ()
  "Keep three distinct genuine filer CIKs in the 13F-HR corpus."
  (let* ((slugs
          '("13f-hr-brk-b" "13f-hr-water-island" "13f-hr-scion"))
         (filings
          (mapcar
           (lambda (slug)
             (edgar-13f-test--read "fixtures" slug))
           slugs))
         (ciks
          (mapcar (lambda (filing) (plist-get filing :cik)) filings)))
    (should
     (seq-every-p
      (lambda (filing)
        (equal (plist-get filing :form) "13F-HR"))
      filings))
    (should (= (length (delete-dups ciks)) 3))))

(ert-deftest edgar-13f-holdings-handles-five-digit-table ()
  "Parse more than 10,000 holdings without truncating the result."
  (let*
      ((count 10001)
       (xml (edgar-13f-test--large-table count))
       (url
        "https://www.sec.gov/Archives/edgar/data/1364742/000108636424008417/form13fInfoTable.xml")
       (filing
        (list
         :accn "0001086364-24-008417"
         :form "13F-HR"
         :filed "2024-08-13"
         :report "2024-06-30"
         :cik 1364742
         :info-url url))
       holdings)
    (should (> (string-bytes xml) 4000000))
    (cl-letf (((symbol-function 'edgar--fetch)
               (lambda (requested)
                 (should (equal requested url))
                 xml)))
      (setq holdings (edgar-13f-holdings filing)))
    (should (= (length holdings) count))
    (should
     (equal
      (car holdings)
      '(:issuer
        "1 800 FLOWERS COM INC"
        :class "CL A"
        :cusip "68243Q106"
        :value "3426648"
        :value-unit usd
        :value-usd 3426648
        :shares "359942"
        :share-type "SH"
        :put-call nil
        :discretion "SOLE"
        :other-manager "2"
        :voting
        (:sole "235261" :shared "0" :none "124681"))))
    (should (equal (car holdings) (car (last holdings))))))

(provide 'edgar-13f-test)
;;; edgar-13f-test.el ends here
