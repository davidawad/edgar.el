;;; edgar-ownership-test.el --- Tests for ownership accessors -*- lexical-binding: t; -*-

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'edgar-ownership)

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
       (equal (edgar-ownership-issuer filing)
              '(:cik "0000320193" :name "Apple Inc." :ticker "AAPL")))
      (let ((owner (car (edgar-ownership-reporting-owners filing))))
        (should (equal (plist-get owner :name) "Khan Sabih"))
        (should (equal (plist-get owner :officer-title) "COO"))
        (should (plist-get owner :is-officer))
        (should-not (plist-get owner :is-director)))
      (let ((rows (edgar-form4-transactions filing)))
        (should (= (length rows) 2))
        (dolist (row rows)
          (should (eq (plist-get row :kind) 'derivative))
          (should (equal (plist-get row :code) "A"))
          (should (equal (plist-get row :shares) "47645"))
          (should (equal (plist-get row :price) "0.00"))
          (should (equal (plist-get row :acquired-disposed) "A"))
          (should (equal (plist-get row :shares-owned-following) "47645"))
          (should (equal (plist-get row :direct-indirect) "D"))
          (should (equal (length (plist-get row :footnotes)) 2)))
        (should (string-match-p "Each restricted stock unit"
                                (car (plist-get (car rows) :footnotes)))))
      (should-not (edgar-ownership-10b5-1-p filing))
      (should
       (equal (car (edgar-ownership-signatures filing))
              '(:name "/s/ Sam Whittington, Attorney-in-Fact for Sabih Khan"
                :date "2026-09-29"))))))

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

(provide 'edgar-ownership-test)
;;; edgar-ownership-test.el ends here
