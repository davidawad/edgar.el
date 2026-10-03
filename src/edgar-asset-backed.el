;;; edgar-asset-backed.el --- Typed asset-backed XML accessors -*- lexical-binding: t; -*-

;; Copyright (C) 2026

;;; Commentary:

;; Parse the EX-102 asset-data XML attached to Form ABS-EE filings.  ABS-EE
;; schemas vary by asset class; this module exposes common identifiers and
;; preserves every field in each record for class-specific callers.

;;; Code:

(require 'cl-lib)
(require 'edgar-docs)
(require 'edgar-xml)
(require 'seq)

(cl-defstruct edgar-abs-ee-asset
  "Common typed fields for one ABS-EE asset record."
  asset-number asset-type-number property-name property-state
  original-loan-amount current-balance fields source)

(cl-defstruct edgar-abs-ee-data
  "Parsed EX-102 data and asset-class identifier."
  asset-class assets tree)

(defun edgar-asset-backed--value (node path)
  "Return text at PATH in projected XML NODE, or nil."
  (let ((value
         (seq-reduce
          (lambda (parent name)
            (let ((entry (and (listp parent) (assq name parent))))
              (and entry (cdr entry))))
          path
          node)))
    (and (stringp value) (not (string-empty-p value)) value)))

(defun edgar-asset-backed--asset-class (xml)
  "Return the asset-class component of XML's default namespace."
  (when (and (stringp xml)
             (string-match
              "xmlns=\"http://www\\.sec\\.gov/edgar/document/absee/\\([^/]+\\)/assetdata\""
              xml))
    (match-string 1 xml)))

(defun edgar-asset-backed--asset (fields source)
  "Make an asset record from projected FIELDS and XML SOURCE."
  (make-edgar-abs-ee-asset
   :asset-number (edgar-asset-backed--value fields '(assetNumber))
   :asset-type-number (edgar-asset-backed--value fields '(assetTypeNumber))
   :property-name (edgar-asset-backed--value fields '(property propertyName))
   :property-state (edgar-asset-backed--value fields '(property propertyState))
   :original-loan-amount
   (edgar-asset-backed--value fields '(originalLoanAmount))
   :current-balance
   (or (edgar-asset-backed--value fields '(reportPeriodEndActualBalanceAmount))
       (edgar-asset-backed--value fields '(scheduledPrincipalBalanceSecuritizationAmount)))
   :fields fields
   :source source))

(defun edgar-abs-ee-asset-data (filing)
  "Return typed ABS-EE EX-102 data attached to FILING, or nil if absent.
The filing directory must expose the exhibit in its SEC index.  Asset-class
fields are kept as strings; per-asset `fields' preserves the full record."
  (let* ((documents (edgar-documents filing))
         (exhibit
          (seq-find (lambda (doc) (equal "EX-102" (plist-get doc :type)))
                    documents))
         (xml
          (and exhibit (edgar--fetch (plist-get exhibit :url))))
         (tree
          (and xml
               (with-temp-buffer
                 (insert xml)
                 (libxml-parse-xml-region (point-min) (point-max)))))
         (projected (and tree (eq (edgar-xml--local-name (car tree)) 'assetData)
                         (edgar-xml-project tree))))
    (when projected
      (let* ((root-data (cdr projected))
             (projected-assets
              (edgar-asset-backed--many root-data 'assets))
             (raw-assets
              (seq-filter
               (lambda (node)
                 (eq (edgar-xml--local-name (car node)) 'assets))
               (edgar-xml--children tree)))
             (assets
              (cl-mapcar #'edgar-asset-backed--asset
                         projected-assets raw-assets)))
        (make-edgar-abs-ee-data
         :asset-class (edgar-asset-backed--asset-class xml)
         :assets assets
         :tree tree)))))

(defun edgar-asset-backed--many (node name)
  "Return all projected child values of NODE named NAME."
  (mapcar #'cdr
          (seq-filter (lambda (entry) (eq (car entry) name)) node)))

(provide 'edgar-asset-backed)
;;; edgar-asset-backed.el ends here
