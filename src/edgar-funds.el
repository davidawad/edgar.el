;;; edgar-funds.el --- Typed accessors for fund filings -*- lexical-binding: t; -*-

;; Copyright (C) 2026

;;; Commentary:

;; Common, lossless projections for N-PORT-P, N-MFP3, and N-CEN.  The SEC
;; documents can contain many repeated holding records; parsing is done once
;; and values are kept as source strings so callers retain exact precision.

;;; Code:

(require 'cl-lib)
(require 'edgar-xml)
(require 'seq)

(cl-defstruct edgar-fund-report
  "Common typed fields and lossless form data for a fund report."
  form registrant-name cik report-date net-assets holdings data tree)

(defun edgar-fund-sections (filing)
  "Return the generic Item/Part sections found in narrative FILING text.
This delegates to the same section API used for other EDGAR reports."
  (edgar-sections (edgar-text filing)))

(defun edgar-funds--value (node path)
  "Return the text value at PATH in projected XML NODE, or nil.
PATH is a list of local element-name symbols."
  (let ((value
         (seq-reduce
          (lambda (parent name)
            (let ((entry (and (listp parent) (assq name parent))))
              (and entry (cdr entry))))
          path
          node)))
    (if (stringp value)
        (and (not (string-empty-p value)) value)
      value)))

(defun edgar-funds--many (node name)
  "Return all projected child values of NODE named NAME."
  (mapcar #'cdr
          (seq-filter (lambda (entry) (eq (car entry) name)) node)))

(defun edgar-funds--xml-attribute (tree path attribute)
  "Return ATTRIBUTE from the XML element at PATH in TREE."
  (let ((node
         (seq-reduce
          (lambda (parent name)
            (seq-find
             (lambda (child) (eq (edgar-xml--local-name (car child)) name))
             (edgar-xml--children parent)))
          path
          tree)))
    (cdr (assq attribute (cadr node)))))

(defun edgar-funds--report-fields (form)
  "Return schema-specific paths for FORM."
  (pcase form
    ("NPORT-P"
     (list :name '(genInfo regName)
           :cik '(genInfo regCik)
           :date '(genInfo repPdDate)
           :assets '(fundInfo netAssets)
           :holdings '(invstOrSecs invstOrSec)))
    ("N-MFP3"
     (list :name '(generalInfo registrantFullName)
           :cik '(generalInfo cik)
           :date '(generalInfo reportDate)
           :assets nil
           :holdings '(scheduleOfPortfolioSecuritiesInfo)))
    ("N-CEN"
     (list :name '(registrantInfo registrantFullName)
           :cik '(registrantInfo registrantCik)
           :date '(generalInfo reportEndingPeriod)
           :assets nil
           :holdings nil))))

(defun edgar-fund-report (filing)
  "Return typed fund-report data for FILING, or nil for unsupported XML.
Supported forms are NPORT-P, N-MFP3, and N-CEN.  `data' retains the full
namespace-insensitive projected form data; `holdings' contains each repeated
holding record in source order where the form has such records.  The XML is
parsed once, so cost is linear in document size (N-MFP3 documents can be
large)."
  (let* ((tree (edgar-xml filing))
         (projected (and tree (edgar-xml-project tree)))
         (root-data (cdr projected))
         (form (edgar-funds--value root-data '(headerData submissionType)))
         (spec (and (member form '("NPORT-P" "N-MFP3" "N-CEN"))
                    (edgar-funds--report-fields form))))
    (when spec
      (let* ((data (edgar-funds--value root-data '(formData)))
             (holdings-path (plist-get spec :holdings))
             (holding-parent
              (and holdings-path
                   (let ((path (butlast holdings-path)))
                     (seq-reduce
                      (lambda (parent name)
                        (let ((entry (and (listp parent) (assq name parent))))
                          (and entry (cdr entry))))
                      path data)))))
        (make-edgar-fund-report
         :form form
         :registrant-name
         (edgar-funds--value data (plist-get spec :name))
         :cik (edgar-funds--value data (plist-get spec :cik))
         :report-date
         (or (edgar-funds--value data (plist-get spec :date))
             (and (equal form "N-CEN")
                  (edgar-funds--xml-attribute
                   tree '(formData generalInfo) 'reportEndingPeriod)))
         :net-assets (and (plist-get spec :assets)
                          (edgar-funds--value data (plist-get spec :assets)))
         :holdings (and holdings-path
                        (edgar-funds--many holding-parent
                                            (car (last holdings-path))))
         :data data
         :tree tree)))))

(provide 'edgar-funds)
;;; edgar-funds.el ends here
