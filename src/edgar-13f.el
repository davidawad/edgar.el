;;; edgar-13f.el --- Read 13F holdings as data -*- lexical-binding: t; -*-

;; Copyright (C) 2026

;; Author: David Awad
;; Keywords: finance, tools

;;; Commentary:

;; Read Form 13F-HR holdings from the separate information-table XML document.
;; `edgar-13f-holding-value' is normalized to dollars: filings before 2023
;; report the source value in thousands of dollars.

;;; Code:

(require 'cl-lib)
(require 'edgar-docs)
(require 'edgar-xml)
(require 'seq)
(require 'subr-x)

(cl-defstruct edgar-13f-holding
  "A normalized row from a Form 13F information table."
  issuer
  class
  cusip
  value
  shares
  share-type
  put-call
  discretion
  other-manager
  voting-sole
  voting-shared
  voting-none)

(defun edgar-13f--local-name (node)
  "Return NODE's element local name."
  (and (consp node) (edgar-xml--local-name (car node))))

(defun edgar-13f--children (node name)
  "Return direct children of NODE with local name NAME."
  (seq-filter
   (lambda (child) (eq (edgar-13f--local-name child) name))
   (edgar-xml--children node)))

(defun edgar-13f--child (node name)
  "Return NODE's first direct child named NAME."
  (car (edgar-13f--children node name)))

(defun edgar-13f--value (node path)
  "Return string value at PATH under NODE, or nil when absent."
  (let ((element
         (seq-reduce
          (lambda (parent name)
            (edgar-13f--child parent name))
          path node)))
    (when element
      (let ((value (edgar-xml--project-value element)))
        (and (stringp value)
             (not (string-empty-p value))
             value)))))

(defun edgar-13f--integer (value)
  "Return integer VALUE or nil when VALUE is not an unsigned integer."
  (when (and value (string-match-p "\\`[0-9]+\\'" value))
    (string-to-number value)))

(defun edgar-13f--information-document (filing)
  "Find FILING's separate information-table XML document."
  (let* ((documents (edgar-documents filing))
         (xml-docs
          (seq-filter
           (lambda (document)
             (let ((name (plist-get document :name)))
               (and (stringp name)
                    (string-match-p "\\.xml\\'" name)
                    (not (equal (downcase name) "primary_doc.xml")))))
           documents))
         (named
          (seq-filter
           (lambda (document)
             (string-match-p
              "\\(?:13f.*info.*table\\|info.*table\\)"
              (downcase (plist-get document :name))))
           xml-docs)))
    (cond
     ((= (length named) 1) (car named))
     ((> (length named) 1)
      (error "EDGAR: multiple 13F information-table XML documents"))
     ((= (length xml-docs) 1) (car xml-docs))
     ((null xml-docs)
      (error "EDGAR: no information-table XML document in filing"))
     (t (error "EDGAR: ambiguous information-table XML documents")))))

(defun edgar-13f--tree-root (document)
  "Return DOCUMENT's informationTable element."
  (let* ((tree (edgar-xml document))
         (root
          (if (eq (edgar-13f--local-name tree) 'top)
              (car (edgar-13f--children tree 'informationTable))
            tree)))
    (unless (eq (edgar-13f--local-name root) 'informationTable)
      (error "EDGAR: expected 13F informationTable XML"))
    root))

(defun edgar-13f--value-scale (filing)
  "Return dollar scale for FILING's reported 13F values."
  (let ((filed (plist-get filing :filed)))
    (unless (and (stringp filed)
                 (string-match-p "\\`[0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}\\'"
                                 filed))
      (error "EDGAR: Form 13F filing needs an ISO :filed date"))
    (if (string< filed "2023-01-01") 1000 1)))

(defun edgar-13f--holding (node scale)
  "Project XML holding NODE to a typed holding, applying dollar SCALE."
  (let ((reported-value
         (edgar-13f--integer (edgar-13f--value node '(value))))
        (shares
         (edgar-13f--integer
          (edgar-13f--value node '(shrsOrPrnAmt sshPrnamt))))
        (voting (edgar-13f--child node 'votingAuthority)))
    (make-edgar-13f-holding
     :issuer (edgar-13f--value node '(nameOfIssuer))
     :class (edgar-13f--value node '(titleOfClass))
     :cusip (edgar-13f--value node '(cusip))
     :value (and reported-value (* scale reported-value))
     :shares shares
     :share-type (edgar-13f--value node '(shrsOrPrnAmt sshPrnamtType))
     :put-call (edgar-13f--value node '(putCall))
     :discretion (edgar-13f--value node '(investmentDiscretion))
     :other-manager (edgar-13f--value node '(otherManager))
     :voting-sole (edgar-13f--integer
                   (edgar-13f--value voting '(Sole)))
     :voting-shared (edgar-13f--integer
                     (edgar-13f--value voting '(Shared)))
     :voting-none (edgar-13f--integer
                   (edgar-13f--value voting '(None))))))

(defun edgar-13f-holdings (filing)
  "Return typed holdings from Form 13F-HR FILING.
The information table is fetched separately from the cover-page XML.  Values
are normalized to dollars; older filings reported them in thousands.  The
return value is a list of `edgar-13f-holding' structs in source order."
  (when (equal (plist-get filing :form) "13F-HR")
    (let* ((document (edgar-13f--information-document filing))
           (tree (edgar-13f--tree-root document))
           (scale (edgar-13f--value-scale filing)))
      (mapcar
       (lambda (row) (edgar-13f--holding row scale))
       (edgar-13f--children tree 'infoTable)))))

(provide 'edgar-13f)
;;; edgar-13f.el ends here
