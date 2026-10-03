;;; edgar-offerings.el --- Typed accessors for EDGAR offering XML -*- lexical-binding: t; -*-

;; Copyright (C) 2026

;; Author: David Awad
;; Keywords: finance, tools

;;; Commentary:

;; Form-specific projections for Form 144, Forms D/D-A, Form C, and Form C-AR.
;; Monetary fields remain strings so decimal precision and values such as
;; "Indefinite" are preserved; count fields are integers.  Missing optional
;; XML fields are nil.

;;; Code:

(require 'cl-lib)
(require 'edgar-xml)
(require 'seq)
(require 'subr-x)

(cl-defstruct
 edgar-form-144
 "Typed Form 144 values from a structured filing."
 issuer-cik
 issuer-name
 seller-name
 securities-class-title
 units-to-be-sold
 aggregate-market-value
 approximate-sale-date
 broker-name)

(cl-defstruct
 edgar-form-d
 "Typed Form D or D/A values from a structured filing."
 submission-type
 issuer-name
 federal-exemptions
 total-offering-amount
 total-amount-sold
 total-remaining
 investor-count
 non-accredited-investor-count
 sales-commissions
 finders-fees)

(cl-defstruct
 edgar-form-c-ar
 "Typed values from a Regulation Crowdfunding annual report."
 issuer-cik
 period
 issuer-name
 issuer-website
 co-issuer-name
 current-employees
 total-assets-current
 total-assets-prior
 cash-current
 cash-prior
 revenue-current
 revenue-prior
 net-income-current
 net-income-prior
 signatures)

(cl-defstruct
 edgar-form-c
 "Typed values from a Regulation Crowdfunding offering statement."
 issuer-cik
 issuer-name
 issuer-website
 co-issuer-names
 intermediary-name
 security-type
 securities-offered
 price
 offering-amount
 maximum-offering-amount
 deadline
 current-employees
 total-assets-current
 total-assets-prior
 revenue-current
 revenue-prior
 net-income-current
 net-income-prior
 signatures)

(defun edgar-offerings--children-named (node name)
  "Return element children of NODE with local name NAME."
  (seq-filter
   (lambda (child)
     (eq (edgar-xml--local-name (car child)) name))
   (edgar-xml--children node)))

(defun edgar-offerings--path-node (node path)
  "Return the first descendant of NODE named by PATH, or nil.
PATH is a list of unqualified element-name symbols."
  (seq-reduce
   (lambda (parent name)
     (car (edgar-offerings--children-named parent name)))
   path node))

(defun edgar-offerings--value (node path)
  "Return the text at PATH below NODE, or nil when it is absent."
  (let ((element (edgar-offerings--path-node node path)))
    (when element
      (let ((value (edgar-xml--project-value element)))
        (and (stringp value) (not (string-empty-p value)) value)))))

(defun edgar-offerings--integer (value)
  "Parse integer VALUE, returning nil for absent or non-integer text."
  (when (and value (string-match-p "\\`[+-]?[0-9]+\\'" value))
    (string-to-number value)))

(defun edgar-offerings--xml-root (filing form-path forms)
  "Return FILING's XML root when its value at FORM-PATH is in FORMS."
  (let*
      ((document (edgar-xml filing))
       ;; libxml may wrap a document containing a leading comment in TOP.
       (tree
        (if (eq (edgar-xml--local-name (car-safe document)) 'top)
            (car
             (edgar-offerings--children-named
              document 'edgarSubmission))
          document)))
    (when (and (consp tree)
               (eq
                (edgar-xml--local-name (car tree)) 'edgarSubmission)
               (member (edgar-offerings--value tree form-path) forms))
      tree)))

(defun edgar-offerings--signatures (tree)
  "Return signature plists from Form C-family XML TREE."
  (let ((people
         (edgar-offerings--path-node
          tree '(formData signatureInfo signaturePersons))))
    (mapcar
     (lambda (person)
       (list
        :name (edgar-offerings--value person '(personSignature))
        :title (edgar-offerings--value person '(personTitle))
        :date (edgar-offerings--value person '(signatureDate))))
     (edgar-offerings--children-named people 'signaturePerson))))

(defun edgar-form-144 (filing)
  "Return typed Form 144 values from FILING, or nil for another document.
Missing optional fields are nil.  `aggregate-market-value' is the exact
source string; `units-to-be-sold' is an integer when the XML value is valid."
  (let ((tree
         (edgar-offerings--xml-root
          filing '(headerData submissionType) '("144" "144/A"))))
    (when tree
      (make-edgar-form-144
       :issuer-cik
       (edgar-offerings--value tree '(formData issuerInfo issuerCik))
       :issuer-name
       (edgar-offerings--value tree '(formData issuerInfo issuerName))
       :seller-name
       (edgar-offerings--value
        tree
        '(formData
          issuerInfo
          nameOfPersonForWhoseAccountTheSecuritiesAreToBeSold))
       :securities-class-title
       (edgar-offerings--value
        tree '(formData securitiesInformation securitiesClassTitle))
       :units-to-be-sold
       (edgar-offerings--integer
        (edgar-offerings--value
         tree '(formData securitiesInformation noOfUnitsSold)))
       :aggregate-market-value
       (edgar-offerings--value
        tree '(formData securitiesInformation aggregateMarketValue))
       :approximate-sale-date
       (edgar-offerings--value
        tree '(formData securitiesInformation approxSaleDate))
       :broker-name
       (edgar-offerings--value
        tree
        '(formData
          securitiesInformation brokerOrMarketmakerDetails name))))))

(defun edgar-form-d (filing)
  "Return typed Form D or D/A values from FILING, or nil for another document.
Amounts remain their exact source strings, including `Indefinite'.  Counts
are integers when the XML contains valid integer text."
  (let ((tree
         (edgar-offerings--xml-root
          filing '(submissionType) '("D" "D/A"))))
    (when tree
      (let* ((exemptions-node
              (edgar-offerings--path-node
               tree '(offeringData federalExemptionsExclusions)))
             (exemptions
              (when exemptions-node
                (mapcar
                 (lambda (item) (edgar-xml--project-value item))
                 (edgar-offerings--children-named
                  exemptions-node 'item)))))
        (make-edgar-form-d
         :submission-type
         (edgar-offerings--value tree '(submissionType))
         :issuer-name
         (edgar-offerings--value tree '(primaryIssuer entityName))
         :federal-exemptions exemptions
         :total-offering-amount
         (edgar-offerings--value
          tree
          '(offeringData offeringSalesAmounts totalOfferingAmount))
         :total-amount-sold
         (edgar-offerings--value
          tree '(offeringData offeringSalesAmounts totalAmountSold))
         :total-remaining
         (edgar-offerings--value
          tree '(offeringData offeringSalesAmounts totalRemaining))
         :investor-count
         (edgar-offerings--integer
          (edgar-offerings--value
           tree '(offeringData investors totalNumberAlreadyInvested)))
         :non-accredited-investor-count
         (edgar-offerings--integer
          (edgar-offerings--value
           tree
           '(offeringData investors numberNonAccreditedInvestors)))
         :sales-commissions
         (edgar-offerings--value
          tree
          '(offeringData
            salesCommissionsFindersFees
            salesCommissions
            dollarAmount))
         :finders-fees
         (edgar-offerings--value
          tree
          '(offeringData
            salesCommissionsFindersFees
            findersFees
            dollarAmount)))))))

(defun edgar-form-c (filing)
  "Return typed Form C values from FILING, or nil for another form.
Amounts and dates remain exact source strings.  Repeated co-issuers and
signature records are returned in filing order."
  (when (equal (plist-get filing :form) "C")
    (let ((tree
           (edgar-offerings--xml-root
            filing
            '(headerData submissionType) '("C"))))
      (when tree
        (let ((co-issuers
               (edgar-offerings--path-node
                tree '(formData issuerInformation coIssuers))))
          (make-edgar-form-c
           :issuer-cik
           (edgar-offerings--value
            tree
            '(headerData filerInfo filer filerCredentials filerCik))
           :issuer-name
           (edgar-offerings--value
            tree
            '(formData issuerInformation issuerInfo nameOfIssuer))
           :issuer-website
           (edgar-offerings--value
            tree
            '(formData issuerInformation issuerInfo issuerWebsite))
           :co-issuer-names
           (mapcar
            (lambda (issuer)
              (edgar-offerings--value issuer '(nameOfCoIssuer)))
            (edgar-offerings--children-named
             co-issuers 'coIssuerInfo))
           :intermediary-name
           (edgar-offerings--value
            tree '(formData issuerInformation companyName))
           :security-type
           (edgar-offerings--value
            tree '(formData offeringInformation securityOfferedType))
           :securities-offered
           (edgar-offerings--integer
            (edgar-offerings--value
             tree
             '(formData offeringInformation noOfSecurityOffered)))
           :price
           (edgar-offerings--value
            tree '(formData offeringInformation price))
           :offering-amount
           (edgar-offerings--value
            tree '(formData offeringInformation offeringAmount))
           :maximum-offering-amount
           (edgar-offerings--value
            tree
            '(formData offeringInformation maximumOfferingAmount))
           :deadline
           (edgar-offerings--value
            tree '(formData offeringInformation deadlineDate))
           :current-employees
           (edgar-offerings--value
            tree
            '(formData
              annualReportDisclosureRequirements currentEmployees))
           :total-assets-current
           (edgar-offerings--value
            tree
            '(formData
              annualReportDisclosureRequirements
              totalAssetMostRecentFiscalYear))
           :total-assets-prior
           (edgar-offerings--value
            tree
            '(formData
              annualReportDisclosureRequirements
              totalAssetPriorFiscalYear))
           :revenue-current
           (edgar-offerings--value
            tree
            '(formData
              annualReportDisclosureRequirements
              revenueMostRecentFiscalYear))
           :revenue-prior
           (edgar-offerings--value
            tree
            '(formData
              annualReportDisclosureRequirements
              revenuePriorFiscalYear))
           :net-income-current
           (edgar-offerings--value
            tree
            '(formData
              annualReportDisclosureRequirements
              netIncomeMostRecentFiscalYear))
           :net-income-prior
           (edgar-offerings--value
            tree
            '(formData
              annualReportDisclosureRequirements
              netIncomePriorFiscalYear))
           :signatures (edgar-offerings--signatures tree)))))))

(defun edgar-form-c-ar (filing)
  "Return typed Form C-AR values from FILING, or nil for another form.
Numeric and date values remain strings to preserve source formatting.
Repeated signature records are returned in filing order."
  (when (equal (plist-get filing :form) "C-AR")
    (let ((tree
           (edgar-offerings--xml-root
            filing
            '(headerData submissionType) '("C-AR"))))
      (when tree
        (make-edgar-form-c-ar
         :issuer-cik
         (edgar-offerings--value
          tree
          '(headerData filerInfo filer filerCredentials filerCik))
         :period
         (edgar-offerings--value tree '(headerData filerInfo period))
         :issuer-name
         (edgar-offerings--value
          tree '(formData issuerInformation issuerInfo nameOfIssuer))
         :issuer-website
         (edgar-offerings--value
          tree '(formData issuerInformation issuerInfo issuerWebsite))
         :co-issuer-name
         (edgar-offerings--value
          tree
          '(formData
            issuerInformation coIssuers coIssuerInfo nameOfCoIssuer))
         :current-employees
         (edgar-offerings--value
          tree
          '(formData
            annualReportDisclosureRequirements currentEmployees))
         :total-assets-current
         (edgar-offerings--value
          tree
          '(formData
            annualReportDisclosureRequirements
            totalAssetMostRecentFiscalYear))
         :total-assets-prior
         (edgar-offerings--value
          tree
          '(formData
            annualReportDisclosureRequirements
            totalAssetPriorFiscalYear))
         :cash-current
         (edgar-offerings--value
          tree
          '(formData
            annualReportDisclosureRequirements
            cashEquiMostRecentFiscalYear))
         :cash-prior
         (edgar-offerings--value
          tree
          '(formData
            annualReportDisclosureRequirements
            cashEquiPriorFiscalYear))
         :revenue-current
         (edgar-offerings--value
          tree
          '(formData
            annualReportDisclosureRequirements
            revenueMostRecentFiscalYear))
         :revenue-prior
         (edgar-offerings--value
          tree
          '(formData
            annualReportDisclosureRequirements
            revenuePriorFiscalYear))
         :net-income-current
         (edgar-offerings--value
          tree
          '(formData
            annualReportDisclosureRequirements
            netIncomeMostRecentFiscalYear))
         :net-income-prior
         (edgar-offerings--value
          tree
          '(formData
            annualReportDisclosureRequirements
            netIncomePriorFiscalYear))
         :signatures (edgar-offerings--signatures tree))))))

(provide 'edgar-offerings)
;;; edgar-offerings.el ends here
