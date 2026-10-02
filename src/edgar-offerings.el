;;; edgar-offerings.el --- Typed accessors for EDGAR offering XML -*- lexical-binding: t; -*-

;; Copyright (C) 2026

;; Author: David Awad
;; Keywords: finance, tools

;;; Commentary:

;; Form-specific projections for Form 144 and Forms D/D-A.  Monetary fields
;; remain strings so decimal precision and values such as "Indefinite" are
;; preserved; count fields are integers.  Missing optional XML fields are nil.

;;; Code:

(require 'cl-lib)
(require 'edgar-xml)
(require 'seq)
(require 'subr-x)

(cl-defstruct edgar-form-144
  "Typed Form 144 values from a structured filing."
  issuer-cik
  issuer-name
  seller-name
  securities-class-title
  units-to-be-sold
  aggregate-market-value
  approximate-sale-date
  broker-name)

(cl-defstruct edgar-form-d
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
   path
   node))

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
  (let* ((document (edgar-xml filing))
         ;; libxml may wrap a document containing a leading comment in TOP.
         (tree (if (eq (edgar-xml--local-name (car-safe document)) 'top)
                   (car (edgar-offerings--children-named document
                                                        'edgarSubmission))
                 document)))
    (when (and (consp tree)
               (eq (edgar-xml--local-name (car tree)) 'edgarSubmission)
               (member (edgar-offerings--value tree form-path) forms))
      tree)))

(defun edgar-form-144 (filing)
  "Return typed Form 144 values from FILING, or nil for another document.
Missing optional fields are nil.  `aggregate-market-value' is the exact
source string; `units-to-be-sold' is an integer when the XML value is valid."
  (let ((tree (edgar-offerings--xml-root
               filing '(headerData submissionType) '("144" "144/A"))))
    (when tree
      (make-edgar-form-144
       :issuer-cik
       (edgar-offerings--value
        tree '(formData issuerInfo issuerCik))
       :issuer-name
       (edgar-offerings--value
        tree '(formData issuerInfo issuerName))
       :seller-name
       (edgar-offerings--value
        tree '(formData issuerInfo
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
        tree '(formData securitiesInformation
               brokerOrMarketmakerDetails name))))))

(defun edgar-form-d (filing)
  "Return typed Form D or D/A values from FILING, or nil for another document.
Amounts remain their exact source strings, including `Indefinite'.  Counts
are integers when the XML contains valid integer text."
  (let ((tree (edgar-offerings--xml-root
               filing '(submissionType) '("D" "D/A"))))
    (when tree
      (let* ((exemptions-node
              (edgar-offerings--path-node
               tree '(offeringData federalExemptionsExclusions)))
             (exemptions
              (when exemptions-node
                (mapcar
                 (lambda (item)
                   (edgar-xml--project-value item))
                 (edgar-offerings--children-named exemptions-node 'item)))))
        (make-edgar-form-d
         :submission-type (edgar-offerings--value tree '(submissionType))
         :issuer-name (edgar-offerings--value tree '(primaryIssuer entityName))
         :federal-exemptions exemptions
         :total-offering-amount
         (edgar-offerings--value
          tree '(offeringData offeringSalesAmounts totalOfferingAmount))
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
           tree '(offeringData investors numberNonAccreditedInvestors)))
         :sales-commissions
         (edgar-offerings--value
          tree '(offeringData salesCommissionsFindersFees
                 salesCommissions dollarAmount))
         :finders-fees
         (edgar-offerings--value
          tree '(offeringData salesCommissionsFindersFees
                 findersFees dollarAmount)))))))

(provide 'edgar-offerings)
;;; edgar-offerings.el ends here
