;;; edgar-offerings-test.el --- Tests for structured offering accessors -*- lexical-binding: t; -*-

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'edgar-offerings)

(defconst edgar-offerings-test--directory
  (file-name-directory (or load-file-name buffer-file-name)))

(defun edgar-offerings-test--read (file)
  "Read the Lisp object in FILE."
  (with-temp-buffer
    (insert-file-contents file)
    (read (current-buffer))))

(defun edgar-offerings-test--fixture (slug)
  "Read structured XML fixture SLUG."
  (with-temp-buffer
    (insert-file-contents
     (expand-file-name (concat "fixtures/" slug ".xml")
                       edgar-offerings-test--directory))
    (buffer-string)))

(defun edgar-offerings-test--filing (slug _form)
  "Return source metadata for fixture SLUG."
  (edgar-offerings-test--read
   (expand-file-name (concat "fixtures/" slug ".eld")
                     edgar-offerings-test--directory)))

(defun edgar-offerings-test--golden (slug)
  "Read field golden values for SLUG."
  (edgar-offerings-test--read
   (expand-file-name (concat "golden-fields/" slug ".eld")
                     edgar-offerings-test--directory)))

(defun edgar-offerings-test--read-fields (slug form parse)
  "Parse fixture SLUG with PARSE and return its typed fields."
  (let ((filing (edgar-offerings-test--filing slug form)))
    (cl-letf (((symbol-function 'edgar--fetch)
               (lambda (url)
                 (should
                  (equal url
                         (edgar-xml--raw-url (plist-get filing :url))))
                 (edgar-offerings-test--fixture slug))))
      (funcall parse filing))))

(defun edgar-offerings-test--form-144-fields (value)
  "Return VALUE's typed Form 144 fields as a plist."
  (list
   :issuer-cik (edgar-form-144-issuer-cik value)
   :issuer-name (edgar-form-144-issuer-name value)
   :seller-name (edgar-form-144-seller-name value)
   :securities-class-title (edgar-form-144-securities-class-title value)
   :units-to-be-sold (edgar-form-144-units-to-be-sold value)
   :aggregate-market-value
   (edgar-form-144-aggregate-market-value value)
   :approximate-sale-date (edgar-form-144-approximate-sale-date value)
   :broker-name (edgar-form-144-broker-name value)))

(defun edgar-offerings-test--form-d-fields (value)
  "Return VALUE's typed Form D fields as a plist."
  (list
   :submission-type (edgar-form-d-submission-type value)
   :issuer-name (edgar-form-d-issuer-name value)
   :federal-exemptions (edgar-form-d-federal-exemptions value)
   :total-offering-amount (edgar-form-d-total-offering-amount value)
   :total-amount-sold (edgar-form-d-total-amount-sold value)
   :total-remaining (edgar-form-d-total-remaining value)
   :investor-count (edgar-form-d-investor-count value)
   :non-accredited-investor-count
   (edgar-form-d-non-accredited-investor-count value)
   :sales-commissions (edgar-form-d-sales-commissions value)
   :finders-fees (edgar-form-d-finders-fees value)))

(defun edgar-offerings-test--form-c-ar-fields (value)
  "Return VALUE's typed Form C-AR fields as a plist."
  (list
   :issuer-cik (edgar-form-c-ar-issuer-cik value)
   :period (edgar-form-c-ar-period value)
   :issuer-name (edgar-form-c-ar-issuer-name value)
   :issuer-website (edgar-form-c-ar-issuer-website value)
   :co-issuer-name (edgar-form-c-ar-co-issuer-name value)
   :current-employees (edgar-form-c-ar-current-employees value)
   :total-assets-current (edgar-form-c-ar-total-assets-current value)
   :total-assets-prior (edgar-form-c-ar-total-assets-prior value)
   :cash-current (edgar-form-c-ar-cash-current value)
   :cash-prior (edgar-form-c-ar-cash-prior value)
   :revenue-current (edgar-form-c-ar-revenue-current value)
   :revenue-prior (edgar-form-c-ar-revenue-prior value)
   :net-income-current (edgar-form-c-ar-net-income-current value)
   :net-income-prior (edgar-form-c-ar-net-income-prior value)
   :signatures (edgar-form-c-ar-signatures value)))

(ert-deftest edgar-form-144-accessors-match-golden-values ()
  "Typed accessors expose key Form 144 fields from recorded XML."
  (let ((value
         (edgar-offerings-test--read-fields
          "144-aapl" "144" #'edgar-form-144)))
    (should (edgar-form-144-p value))
    (should
     (equal
      (edgar-offerings-test--form-144-fields value)
      (edgar-offerings-test--golden "144-aapl")))))

(ert-deftest edgar-form-144-parses-older-filing-vintage ()
  "Typed accessors retain values from the older recorded Form 144 layout."
  (let ((value
         (edgar-offerings-test--read-fields
          "144-aapl-prior" "144" #'edgar-form-144)))
    (should (edgar-form-144-p value))
    (should
     (equal
      (edgar-offerings-test--form-144-fields value)
      (edgar-offerings-test--golden "144-aapl-prior")))))

(ert-deftest edgar-form-144-additional-filers-match-golden-values ()
  "Parse Form 144 XML from distinct issuers and layouts."
  (dolist (slug '("144-amd" "144-jpm"))
    (let ((value
           (edgar-offerings-test--read-fields
            slug "144" #'edgar-form-144)))
      (should (edgar-form-144-p value))
      (should
       (equal
        (edgar-offerings-test--form-144-fields value)
        (edgar-offerings-test--golden slug)))
      (should
       (equal
        (list :form "144"
              :issuer-name (edgar-form-144-issuer-name value)
              :seller-name (edgar-form-144-seller-name value)
              :units-to-be-sold (edgar-form-144-units-to-be-sold value)
              :approximate-sale-date
              (edgar-form-144-approximate-sale-date value))
        (edgar-offerings-test--read
         (expand-file-name (concat "expect/" slug ".eld")
                           edgar-offerings-test--directory)))))))

(ert-deftest edgar-form-d-accessors-match-golden-values ()
  "Typed Form D accessors preserve amounts and return integer counts."
  (let ((value
         (edgar-offerings-test--read-fields
          "form-d-sample" "D" #'edgar-form-d)))
    (should (edgar-form-d-p value))
    (should
     (equal
      (edgar-offerings-test--form-d-fields value)
      (edgar-offerings-test--golden "form-d-sample")))))

(ert-deftest edgar-form-d-a-is-parsed-as-an-amendment ()
  "D/A is accepted and retains the filing's D/A submission type."
  (let ((value
         (edgar-offerings-test--read-fields
          "form-d-a-sample" "D/A" #'edgar-form-d)))
    (should (edgar-form-d-p value))
    (should
     (equal
      (edgar-offerings-test--form-d-fields value)
      (edgar-offerings-test--golden "form-d-a-sample")))))

(ert-deftest edgar-form-d-older-schema-vintage-keeps-optional-fields-nil ()
  "Old Form D schema data parses without invented optional values."
  (let ((value
         (edgar-offerings-test--read-fields
          "form-d-2008" "D" #'edgar-form-d)))
    (should (edgar-form-d-p value))
    (should
     (equal
      (edgar-offerings-test--form-d-fields value)
      (edgar-offerings-test--golden "form-d-2008")))))

(ert-deftest edgar-offering-accessors-return-nil-for-other-forms ()
  "Form-specific accessors return nil for a different XML submission."
  (let ((value
         (edgar-offerings-test--read-fields
          "form-d-sample" "D" #'edgar-form-144)))
    (should-not value)))

(ert-deftest edgar-form-c-ar-accessors-match-golden-values ()
  "Typed Form C-AR accessors match values from a genuine SEC XML filing."
  (let ((value
         (edgar-offerings-test--read-fields
          "c-ar-qnetic" "C-AR" #'edgar-form-c-ar)))
    (should (edgar-form-c-ar-p value))
    (should
     (equal
      (edgar-offerings-test--form-c-ar-fields value)
      (edgar-offerings-test--golden "c-ar-qnetic")))))

(ert-deftest edgar-form-c-ar-is-nil-for-other-forms ()
  "Form C-AR projection does not accept a different form code."
  (should-not
   (edgar-offerings-test--read-fields
    "c-ar-qnetic" "C" #'edgar-form-c-ar)))

(provide 'edgar-offerings-test)
;;; edgar-offerings-test.el ends here
