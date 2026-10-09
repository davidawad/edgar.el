;;; edgar-offerings-test.el --- Tests for structured offering accessors -*- lexical-binding: t; -*-

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'edgar-offerings)
(require 'edgar-forms)
(require 'edgar-fixtures)

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

(defun edgar-offerings-test--filing (slug form)
  "Return source metadata for fixture SLUG."
  (let ((filing
         (edgar-offerings-test--read
          (expand-file-name (concat "fixtures/" slug ".eld")
                            edgar-offerings-test--directory))))
    (plist-put filing :form form)))

(defun edgar-offerings-test--golden (slug)
  "Read field golden values for SLUG."
  (edgar-offerings-test--read
   (expand-file-name (concat "golden-fields/" slug ".eld")
                     edgar-offerings-test--directory)))

(defun edgar-offerings-test--expect (slug)
  "Read the compact expectation for SLUG."
  (edgar-offerings-test--read
   (expand-file-name (concat "expect/" slug ".eld")
                     edgar-offerings-test--directory)))

(defun edgar-offerings-test--read-fields (slug form parse)
  "Parse fixture SLUG with PARSE and return its typed fields."
  (let ((filing (edgar-offerings-test--filing slug form)))
    (cl-letf (((symbol-function 'edgar--fetch)
               (lambda (url)
                 (should
                  (equal
                   url (edgar-xml--raw-url (plist-get filing :url))))
                 (edgar-offerings-test--fixture slug))))
      (funcall parse filing))))

(ert-deftest
    edgar-g11-required-forms-have-sec-fixtures-and-expectations
    ()
  "Every required G11 form has an SEC fixture and reviewed expectation."
  (dolist (case
           '(("1" "form-1-nasdaq-ise" ".pdf" "1/A")
             ("C" "c-airthium" ".xml")
             ("C-AR" "c-ar-qnetic" ".xml")
             ("C-U" "c-u-same-same" ".xml")
             ("C-TR" "c-tr-pegasus" ".xml")
             ("1-A" "1-a-newport" ".xml")
             ("1-K" "1-k-firstvitals" ".xml")
             ("1-U" "1-u-masterworks-vault18" ".htm.gz")
             ("1-SA" "1-sa-fig-publishing" ".htm.gz")
             ("1-Z" "1-z-masterworks-289" ".xml")))
    (let* ((form (nth 0 case))
           (slug (nth 1 case))
           (extension (nth 2 case))
           (actual-forms
            (or (and (nth 3 case) (list (nth 3 case))) (list form)))
           (metadata
            (edgar-offerings-test--read
             (expand-file-name (concat "fixtures/" slug ".eld")
                               edgar-offerings-test--directory)))
           (primary
            (expand-file-name (concat "fixtures/" slug extension)
                              edgar-offerings-test--directory))
           (expect
            (expand-file-name (concat "expect/" slug ".eld")
                              edgar-offerings-test--directory)))
      (should (member (plist-get metadata :form) actual-forms))
      (should (stringp (plist-get metadata :accn)))
      (should (numberp (plist-get metadata :cik)))
      (should
       (string-match-p
        "\\`https://www\\.sec\\.gov/Archives/edgar/"
        (or (plist-get metadata :url) "")))
      (should (file-exists-p primary))
      (should (file-exists-p expect))
      (when (equal form "1")
        (should (eq (plist-get (edgar-form-info form) :level) 'L1))
        (should
         (file-exists-p
          (expand-file-name "golden/form-1-nasdaq-ise.eld"
                            edgar-offerings-test--directory))))
      (when (member form '("C" "C-AR"))
        (should
         (file-exists-p
          (expand-file-name (concat "golden-fields/" slug ".eld")
                            edgar-offerings-test--directory)))))))

(ert-deftest edgar-g11-form-1-has-generic-pdf-text ()
  "The SEC Form 1/A PDF exposes its body through generic `edgar-text'."
  (let* ((text (edgar-fixtures-text "form-1-nasdaq-ise"))
         (normalized (edgar-fixtures-norm text)))
    (should (> (length text) 1000))
    (dolist
        (phrase
         '("APPLICATION FOR, AND AMENDMENTS TO APPLICATION FOR,"
           "REGISTRATION AS A NATIONAL SECURITIES EXCHANGE OR EXEMPTION"
           "Pursuant to Rule 6a-2(a), the Exchange is hereby filing"
           "Tower Principal Markets LLC"))
      (should (string-match-p (regexp-quote phrase) normalized)))))

(defun edgar-offerings-test--form-144-fields (value)
  "Return VALUE's typed Form 144 fields as a plist."
  (list
   :issuer-cik (edgar-form-144-issuer-cik value)
   :issuer-name (edgar-form-144-issuer-name value)
   :seller-name (edgar-form-144-seller-name value)
   :securities-class-title (edgar-form-144-securities-class-title value)
   :units-to-be-sold (edgar-form-144-units-to-be-sold value)
   :aggregate-market-value (edgar-form-144-aggregate-market-value value)
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
   :non-accredited-investor-count (edgar-form-d-non-accredited-investor-count value)
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

(defun edgar-offerings-test--form-c-fields (value)
  "Return VALUE's typed Form C fields as a plist."
  (list
   :issuer-cik (edgar-form-c-issuer-cik value)
   :issuer-name (edgar-form-c-issuer-name value)
   :issuer-website (edgar-form-c-issuer-website value)
   :co-issuer-names (edgar-form-c-co-issuer-names value)
   :intermediary-name (edgar-form-c-intermediary-name value)
   :security-type (edgar-form-c-security-type value)
   :securities-offered (edgar-form-c-securities-offered value)
   :price (edgar-form-c-price value)
   :offering-amount (edgar-form-c-offering-amount value)
   :maximum-offering-amount (edgar-form-c-maximum-offering-amount value)
   :deadline (edgar-form-c-deadline value)
   :current-employees (edgar-form-c-current-employees value)
   :total-assets-current (edgar-form-c-total-assets-current value)
   :total-assets-prior (edgar-form-c-total-assets-prior value)
   :revenue-current (edgar-form-c-revenue-current value)
   :revenue-prior (edgar-form-c-revenue-prior value)
   :net-income-current (edgar-form-c-net-income-current value)
   :net-income-prior (edgar-form-c-net-income-prior value)
   :signatures (edgar-form-c-signatures value)))

(defun edgar-offerings-test--generic-fields (slug form tags)
  "Return generic XML TAG values for recorded SLUG and FORM."
  (let* ((filing (edgar-offerings-test--filing slug form))
         (xml (edgar-offerings-test--fixture slug)))
    (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) xml)))
      (let ((tree (edgar-document-structure filing)))
        (mapcar
         (lambda (tag)
           (let ((nodes (edgar-structure-nodes tree tag)))
             (cons tag (mapcar #'edgar-structure-text nodes))))
         tags)))))

(defun edgar-offerings-test--normalize-text (text)
  "Collapse whitespace in rendered filing TEXT."
  (string-trim (replace-regexp-in-string "[ \t\n ]+" " " text)))

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
        (list
         :form "144"
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

(ert-deftest edgar-form-d-506b-exemption-matches-real-filing-golden ()
  "Form D preserves the SEC's Rule 506(b) exemption code."
  (let ((value
         (edgar-offerings-test--read-fields
          "form-d-506b" "D" #'edgar-form-d)))
    (should (edgar-form-d-p value))
    (should
     (equal
      (edgar-offerings-test--form-d-fields value)
      (edgar-offerings-test--golden "form-d-506b")))
    (should
     (equal (edgar-form-d-federal-exemptions value) '("06b")))))

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

(ert-deftest
    edgar-form-d-older-schema-vintage-keeps-optional-fields-nil
    ()
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

(ert-deftest edgar-form-c-accessors-match-golden-values ()
  "Typed accessors match filed values across three Form C filers."
  (dolist (slug '("c-airthium" "c-sapor" "c-string-cubed"))
    (let* ((filing (edgar-offerings-test--filing slug "C"))
           (value
            (edgar-offerings-test--read-fields
             slug "C" #'edgar-form-c))
           (fields (edgar-offerings-test--form-c-fields value))
           (expect
            (list :form "C"
                  :accn (plist-get filing :accn)
                  :issuer (edgar-form-c-issuer-name value)
                  :offering-amount (edgar-form-c-offering-amount value)
                  :deadline (edgar-form-c-deadline value))))
      (should (edgar-form-c-p value))
      (should (equal fields (edgar-offerings-test--golden slug)))
      (should (equal expect (edgar-offerings-test--expect slug))))))

(ert-deftest edgar-form-c-is-nil-for-other-forms ()
  "Form C projection does not accept a different form code."
  (should-not
   (edgar-offerings-test--read-fields
    "c-airthium" "C-U" #'edgar-form-c)))

(ert-deftest edgar-g11-xml-primary-fields-match-expectations ()
  "Generic XML accessors preserve primary fields for SEC-backed G11 filings."
  (dolist (case
           '(("1-a-newport" "1-A" "issuerName" "submissionType")
             ("1-a-pos-iron-bridge" "1-A POS" "issuerName" "offeringFileNumber")
             ("c-ar-w-cybr" "C-AR-W" "nameOfIssuer" "submissionType")
             ("c-tr-pegasus" "C-TR" "nameOfIssuer" "submissionType")
             ("c-tr-w-contractor-plus" "C-TR-W" "nameOfIssuer" "submissionType")
             ("c-w-rentberry" "C-W" "nameOfIssuer" "submissionType")
             ("qualif-bio-path" "QUALIF" "entityName" "schemaVersion")))
    (let* ((slug (nth 0 case))
           (form (nth 1 case))
           (tags (list (nth 2 case) (nth 3 case))))
      (should
       (equal (edgar-offerings-test--generic-fields slug form tags)
              (plist-get (edgar-offerings-test--read
                          (expand-file-name (concat "expect/" slug ".eld")
                                            edgar-offerings-test--directory))
                         :fields))))))

(ert-deftest edgar-form-1-k-header-and-narrative-are-readable-offline ()
  "Read Form 1-K XML header and the filing's SEC narrative document."
  (let* ((slug "1-k-firstvitals")
         (filing (edgar-offerings-test--filing slug "1-K"))
         (expected
          (edgar-offerings-test--read
           (expand-file-name "expect/1-k-firstvitals.eld"
                             edgar-offerings-test--directory)))
         (narrative (copy-sequence filing))
         (html (with-temp-buffer
                 (let ((auto-compression-mode t))
                   (insert-file-contents
                    (expand-file-name
                     (concat "fixtures/" slug ".html.gz")
                     edgar-offerings-test--directory)))
                 (buffer-string))))
    (should
     (equal
      (edgar-offerings-test--generic-fields
       slug "1-K" '("submissionType" "issuerName" "reportingPeriod"))
      (plist-get expected :fields)))
    (setf (plist-get narrative :url) (plist-get filing :narrative-url))
    (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) html)))
      (should
       (string-match-p
        (plist-get expected :narrative-marker)
        (upcase (edgar-text narrative)))))))

(ert-deftest edgar-form-1-z-primary-fields-match-expectation ()
  "Generic XML accessors preserve Form 1-Z termination fields."
  (should
   (equal
    (edgar-offerings-test--generic-fields
     "1-z-masterworks-289" "1-Z"
     '("submissionType" "issuerName" "date"))
    (plist-get
     (edgar-offerings-test--read
      (expand-file-name
       "expect/1-z-masterworks-289.eld"
       edgar-offerings-test--directory))
     :fields))))

(ert-deftest edgar-form-c-generic-text-and-tree-access ()
  "Generic APIs retain Form C text and nested XML values offline."
  (let* ((slug "c-airthium")
         (filing (edgar-offerings-test--filing slug "C"))
         (xml (edgar-offerings-test--fixture slug)))
    (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) xml)))
      (let ((text
             (edgar-offerings-test--normalize-text
              (edgar-text filing))))
        (should (string-match-p "Airthium Inc\\." text))
        (should (string-match-p "50000\\.00" text))))
    (should
     (equal
      (edgar-offerings-test--generic-fields
       slug "C" '("nameofissuer" "offeringamount" "deadlinedate"))
      '(("nameofissuer" "Airthium Inc.")
        ("offeringamount" "50000.00")
        ("deadlinedate" "04-30-2027"))))))

(ert-deftest edgar-form-c-u-generic-values-match-golden ()
  "Form C-U remains accessible through generic text and XML tree APIs."
  (let* ((slug "c-u-same-same")
         (filing (edgar-offerings-test--filing slug "C-U"))
         (xml (edgar-offerings-test--fixture slug))
         (golden
          (edgar-offerings-test--read
           (expand-file-name (concat "expect/" slug ".eld")
                             edgar-offerings-test--directory))))
    (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) xml)))
      (let ((text
             (edgar-offerings-test--normalize-text
              (edgar-text filing))))
        (should
         (string-match-p
          (regexp-quote (plist-get golden :progress-update)) text))
        (should
         (string-match-p
          (regexp-quote (plist-get golden :issuer)) text))))
    (let ((fields
           (edgar-offerings-test--generic-fields
            slug "C-U"
            '("nameofissuer"
              "progressupdate"
              "offeringamount"
              "maximumofferingamount"
              "deadlinedate"))))
      (should
       (equal
        (list
         :form "C-U"
         :accn (plist-get filing :accn)
         :issuer (car (cdr (assoc "nameofissuer" fields)))
         :progress-update (car (cdr (assoc "progressupdate" fields)))
         :offering-amount (car (cdr (assoc "offeringamount" fields)))
         :maximum-offering-amount
         (car (cdr (assoc "maximumofferingamount" fields)))
         :deadline (car (cdr (assoc "deadlinedate" fields))))
        golden)))))

(provide 'edgar-offerings-test)
;;; edgar-offerings-test.el ends here
