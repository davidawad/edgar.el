;;; edgar-ownership-test.el --- Tests for ownership accessors -*- lexical-binding: t; -*-

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'edgar-ownership)
(require 'edgar-schedules)
(require 'edgar-fixtures)

(defconst edgar-ownership-test--directory
  (file-name-directory (or load-file-name buffer-file-name))
  "Directory containing ownership tests.")

(defun edgar-ownership-test--xml (text)
  "Parse XML TEXT into a libxml tree."
  (with-temp-buffer
    (insert text)
    (libxml-parse-xml-region (point-min) (point-max))))

(defun edgar-ownership-test--fixture (slug)
  "Parse recorded ownership XML fixture SLUG."
  (with-temp-buffer
    (insert-file-contents
     (expand-file-name (concat "fixtures/" slug ".xml")
                       edgar-ownership-test--directory))
    (libxml-parse-xml-region (point-min) (point-max))))

(defun edgar-ownership-test--golden (slug)
  "Read field golden values for ownership fixture SLUG."
  (with-temp-buffer
    (insert-file-contents
     (expand-file-name (concat "golden-fields/" slug ".eld")
                       edgar-ownership-test--directory))
    (read (current-buffer))))

(defun edgar-ownership-test--transaction (form code)
  "Return a small offline ownership XML tree for FORM and transaction CODE."
  (edgar-ownership-test--xml
   (format
    (concat "<ownershipDocument><documentType>%s</documentType>"
            "<nonDerivativeTable><nonDerivativeTransaction>"
            "<securityTitle><value>Common Stock</value></securityTitle>"
            "<transactionDate><value>2026-01-02</value></transactionDate>"
            "<transactionCoding><transactionCode>%s</transactionCode></transactionCoding>"
            "<transactionAmounts><transactionShares><value>25</value></transactionShares>"
            "<transactionPricePerShare><value>12.50</value></transactionPricePerShare>"
            "<transactionAcquiredDisposedCode><value>%s</value>"
            "</transactionAcquiredDisposedCode></transactionAmounts>"
            "<postTransactionAmounts><sharesOwnedFollowingTransaction>"
            "<value>125</value></sharesOwnedFollowingTransaction></postTransactionAmounts>"
            "<ownershipNature><directOrIndirectOwnership><value>D</value>"
            "</directOrIndirectOwnership></ownershipNature>"
            "</nonDerivativeTransaction></nonDerivativeTable></ownershipDocument>")
    form code (if (equal code "S") "D" "A"))))

(ert-deftest edgar-ownership-apple-form4-golden-values ()
  "Return the Apple Form 4's issuer, owner, RSUs, notes, and signature."
  (let ((filing '(:form "4"))
        (tree (edgar-ownership-test--fixture "4-aapl")))
    (cl-letf (((symbol-function 'edgar-xml) (lambda (_filing) tree)))
      (should
       (equal
        (list
         :issuer (edgar-ownership-issuer filing)
         :owner
         (let ((owner (car (edgar-ownership-reporting-owners filing))))
           (list :name (plist-get owner :name)
                 :officer-title (plist-get owner :officer-title)
                 :is-officer (plist-get owner :is-officer)
                 :is-director (plist-get owner :is-director)))
         :transactions
         (mapcar
          (lambda (row)
            (list :kind (plist-get row :kind)
                  :code (plist-get row :code)
                  :shares (plist-get row :shares)
                  :price (plist-get row :price)
                  :acquired-disposed (plist-get row :acquired-disposed)
                  :shares-owned-following
                  (plist-get row :shares-owned-following)
                  :direct-indirect (plist-get row :direct-indirect)
                  :footnote-count (length (plist-get row :footnotes))))
          (edgar-form4-transactions filing))
         :footnote-head
         (car (plist-get (car (edgar-form4-transactions filing)) :footnotes))
         :10b5-1 (edgar-ownership-10b5-1-p filing)
         :signature (car (edgar-ownership-signatures filing)))
        (edgar-ownership-test--golden "4-aapl"))))))

(ert-deftest edgar-ownership-transaction-golden-codes ()
  "Keep representative buy, sale, and option-exercise transaction values."
  (dolist (case '(("4" "P" "A") ("4" "S" "D") ("4" "M" "A")))
    (let* ((form (nth 0 case))
           (tree (edgar-ownership-test--transaction form (nth 1 case)))
           (filing (list :form form)))
      (cl-letf (((symbol-function 'edgar-xml) (lambda (_filing) tree)))
        (let ((row (car (edgar-ownership-transactions filing))))
          (should (equal (plist-get row :code) (nth 1 case)))
          (should (equal (plist-get row :date) "2026-01-02"))
          (should (equal (plist-get row :shares) "25"))
          (should (equal (plist-get row :price) "12.50"))
          (should (equal (plist-get row :acquired-disposed) (nth 2 case)))
          (should (equal (plist-get row :shares-owned-following) "125")))))))

(ert-deftest edgar-ownership-form3-and-form5-holdings ()
  "Return non-derivative and derivative holdings for Forms 3 and 5."
  (let ((tree
         (edgar-ownership-test--xml
          (concat
           "<ownershipDocument><schemaVersion>X0609</schemaVersion>"
           "<nonDerivativeTable><nonDerivativeHolding>"
           "<securityTitle><value>Common Stock</value></securityTitle>"
           "<postTransactionAmounts><sharesOwnedFollowingTransaction>"
           "<value>100</value></sharesOwnedFollowingTransaction></postTransactionAmounts>"
           "<ownershipNature><directOrIndirectOwnership><value>D</value>"
           "</directOrIndirectOwnership></ownershipNature>"
           "</nonDerivativeHolding></nonDerivativeTable>"
           "<derivativeTable><derivativeHolding>"
           "<securityTitle><value>Option</value></securityTitle>"
           "<underlyingSecurity><underlyingSecurityTitle><value>Common Stock</value>"
           "</underlyingSecurityTitle><underlyingSecurityShares><value>50</value>"
           "</underlyingSecurityShares></underlyingSecurity>"
           "<postTransactionAmounts><sharesOwnedFollowingTransaction>"
           "<value>50</value></sharesOwnedFollowingTransaction></postTransactionAmounts>"
           "<ownershipNature><directOrIndirectOwnership><value>I</value>"
           "</directOrIndirectOwnership><natureOfOwnership><value>By trust</value>"
           "</natureOfOwnership></ownershipNature></derivativeHolding></derivativeTable>"
           "<aff10b5One>true</aff10b5One></ownershipDocument>"))))
    (dolist (form '("3" "5"))
      (let ((filing (list :form form)))
        (cl-letf (((symbol-function 'edgar-xml) (lambda (_filing) tree)))
          (let ((holdings (if (equal form "3")
                              (edgar-form3-holdings filing)
                            (edgar-form5-holdings filing))))
            (should (= (length holdings) 2))
            (should (equal (plist-get (car holdings) :shares-owned-following)
                           "100"))
            (should (equal (plist-get (cadr holdings) :underlying-security-shares)
                           "50"))
            (should (equal (plist-get (cadr holdings) :nature-of-ownership)
                           "By trust")))
          (should (edgar-ownership-10b5-1-p filing)))))))

(ert-deftest edgar-ownership-form4-amendment-and-x0306-vintage ()
  "Accept Form 4/A and preserve support for the older X0306 schema."
  (let* ((xml
          (with-temp-buffer
            (insert-file-contents
             (expand-file-name "fixtures/4-aapl.xml"
                               edgar-ownership-test--directory))
            (replace-regexp-in-string "X0609" "X0306" (buffer-string))))
         (tree (edgar-ownership-test--xml xml))
         (filing '(:form "4/A")))
    (cl-letf (((symbol-function 'edgar-xml) (lambda (_filing) tree)))
      (should (= (length (edgar-form4-transactions filing)) 2))
      (should (equal (edgar-ownership--text
                      (edgar-ownership--child tree 'schemaVersion))
                     "X0306")))))

(defun edgar-ownership-test--schedule-xml (form)
  "Return a compact Schedule 13D/G XML tree for FORM."
  (edgar-ownership-test--xml
   (if (string-match-p "13G" form)
       (concat
        "<edgarSubmission xmlns='http://www.sec.gov/edgar/schedule13g'>"
        "<formData><coverPageHeader><issuerInfo>"
        "<issuerCik>0000000001</issuerCik><issuerName>Example Corp</issuerName>"
        "<issuerCusip>123456789</issuerCusip><issuerCusip>987654321</issuerCusip>"
        "</issuerInfo></coverPageHeader>"
        "<coverPageHeaderReportingPersonDetails><reportingCik>0000000002</reportingCik>"
        "<reportingPersonName>Example Fund</reportingPersonName>"
        "<reportingPersonBeneficiallyOwnedNumberOfShares><soleVotingPower>10</soleVotingPower>"
        "<sharedVotingPower>20</sharedVotingPower><soleDispositivePower>10</soleDispositivePower>"
        "<sharedDispositivePower>20</sharedDispositivePower>"
        "</reportingPersonBeneficiallyOwnedNumberOfShares>"
        "<reportingPersonBeneficiallyOwnedAggregateNumberOfShares>30</reportingPersonBeneficiallyOwnedAggregateNumberOfShares>"
        "<classPercent>5.5</classPercent><typeOfReportingPerson>IA</typeOfReportingPerson>"
        "</coverPageHeaderReportingPersonDetails><items><item4>"
        "<amountBeneficiallyOwned>30</amountBeneficiallyOwned><classPercent>5.5</classPercent>"
        "</item4></items></formData></edgarSubmission>")
     (concat
      "<edgarSubmission xmlns='http://www.sec.gov/edgar/schedule13d'>"
      "<formData><coverPageHeader><issuerInfo>"
      "<issuerCIK>0000000001</issuerCIK><issuerName>Example Corp</issuerName>"
      "<issuerCUSIP>123456789</issuerCUSIP></issuerInfo></coverPageHeader>"
      "<reportingPersons><reportingPersonInfo><reportingPersonCIK>0000000002</reportingPersonCIK>"
      "<reportingPersonName>Example Fund</reportingPersonName><soleVotingPower>10</soleVotingPower>"
      "<sharedVotingPower>20</sharedVotingPower><soleDispositivePower>10</soleDispositivePower>"
      "<sharedDispositivePower>20</sharedDispositivePower><aggregateAmountOwned>30</aggregateAmountOwned>"
      "<percentOfClass>5.5</percentOfClass><typeOfReportingPerson>IA</typeOfReportingPerson>"
      "</reportingPersonInfo></reportingPersons><items1To7><item4>"
      "<transactionPurpose>Seeking board representation.</transactionPurpose>"
      "</item4></items1To7></formData></edgarSubmission>"))))

(ert-deftest edgar-schedule-13g-cover-page-and-amendment-golden ()
  "Extract Schedule 13G cover values, including amendment forms."
  (let* ((filing '(:form "SCHEDULE 13G/A"))
         (tree (edgar-ownership-test--schedule-xml (plist-get filing :form))))
    (cl-letf (((symbol-function 'edgar-xml) (lambda (_filing) tree)))
      (let* ((cover (edgar-schedule-13d-g-cover-page filing))
             (issuer (plist-get cover :issuer))
             (person (car (plist-get cover :reporting-persons))))
        (should (edgar-schedules-structured-p filing))
        (should (equal (plist-get issuer :cik) "0000000001"))
        (should (equal (plist-get issuer :cusips)
                       '("123456789" "987654321")))
        (should (equal (plist-get person :name) "Example Fund"))
        (should (equal (plist-get person :shares) "30"))
        (should (equal (plist-get person :percent-of-class) "5.5"))
        (should (equal (plist-get person :type-of-reporting-person) "IA"))
        (should (equal (plist-get person :item-4-amount) "30"))
        (should (equal (plist-get person :item-4-percent) "5.5"))))))

(ert-deftest edgar-schedule-13d-purpose-xml-and-legacy ()
  "Read XML Item 4 purpose and reuse section parsing for legacy text."
  (let* ((xml-filing '(:form "SCHEDULE 13D/A"))
         (xml-tree (edgar-ownership-test--schedule-xml
                    (plist-get xml-filing :form))))
    (cl-letf (((symbol-function 'edgar-xml) (lambda (_filing) xml-tree)))
      (should (equal (edgar-schedule-13d-purpose-of-transaction xml-filing)
                     "Seeking board representation."))))
  (let ((legacy '(:form "SC 13D/A")))
    (cl-letf (((symbol-function 'edgar-section)
               (lambda (_filing item)
                 (and (equal item "4") "Legacy purpose section"))))
      (should (equal (edgar-schedule-13d-purpose-of-transaction legacy)
                     "Legacy purpose section")))))

(ert-deftest edgar-schedule-13g-legacy-fixture-remains-text-readable ()
  "Keep the recorded SC 13G/A text fixture available through legacy sections."
  (let* ((filing (edgar-fixtures-filing "sc-13ga-gme"))
         (text (edgar-fixtures-text "sc-13ga-gme")))
    (should (equal (plist-get filing :form) "SC 13G/A"))
    (should (string-match-p "CUSIP No. 36467W109" text))
    (should-not (edgar-schedules-structured-p filing))
    (should-not (edgar-schedule-13d-g-cover-page filing))
    (cl-letf (((symbol-function 'edgar-text) (lambda (_) "legacy body"))
              ((symbol-function 'edgar-sections)
               (lambda (text)
                 (should (equal text "legacy body"))
                 '(("4" . "ownership narrative")))))
      (should (equal (edgar-schedule-13d-g-legacy-sections filing)
                     '(("4" . "ownership narrative")))))))

(provide 'edgar-ownership-test)
;;; edgar-ownership-test.el ends here
