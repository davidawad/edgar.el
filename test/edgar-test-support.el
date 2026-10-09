;;; edgar-test-support.el --- Shared helpers for edgar-test -*- lexical-binding: t; -*-

;;; Commentary:

;; Helpers and fixtures shared by `edgar-test' and its companion test files.

;;; Code:

(require 'ert)

(require 'json)

(add-to-list
 'load-path
 (file-name-directory (or load-file-name buffer-file-name)))

;; Coverage (undercover.el, pack-mandated).  Must run before the source loads.
(setq load-prefer-newer t)

(when (require 'undercover nil t)
  (undercover "edgar*.el" (:report-format 'text) (:send-report nil)))

(require 'edgar)

(require 'edgar-fixtures)

(defconst edgar-test--dir
  (file-name-directory (or load-file-name buffer-file-name))
  "Directory containing the EDGAR tests.")

(defun edgar-test--fixture-json (name)
  "Return recorded JSON fixture NAME as a plist."
  (with-temp-buffer
    (let ((auto-compression-mode t))
      (insert-file-contents
       (expand-file-name (concat "fixtures/" name) edgar-test--dir)))
    (json-parse-buffer :object-type 'plist :array-type 'list)))

(defconst edgar-test--submissions
  '(:filings
    (:recent
     (:accessionNumber
      ("0000320193-25-000079"
       "0000320193-25-000050"
       "0000320193-24-000123")
      :form ("10-K" "8-K" "10-K")
      :filingDate
      ("2025-10-31" "2025-08-01" "2024-11-01")
      :reportDate
      ("2025-09-27" "2025-07-30" "2024-09-28")
      :primaryDocument
      ("aapl-20250927.htm" "x8k.htm" "aapl-20240928.htm")))))

(defconst edgar-test--html
  (concat
   "<html><body>"
   "<p>Item 1. Business</p><p>Item 1A. Risk Factors</p><p>Item 2. Properties</p>"
   "<p>Item 1. Business</p><p>We sell phones and many other things.</p>"
   "<p>Item 1A. Risk Factors</p><p>There are risks galore here and there.</p>"
   "<p>Item 2. Properties</p><p>Buildings.</p>"
   "</body></html>"))

(defmacro edgar-test--with-sec (&rest body)
  "Run BODY with the SEC transport stubbed with canned data."
  (declare (indent 0))
  `(cl-letf (((symbol-function 'xbrl-cik)
              (lambda (_) "CIK0000320193"))
             ((symbol-function 'xbrl--get)
              (lambda (_) edgar-test--submissions))
             ((symbol-function 'edgar--fetch)
              (lambda (_) edgar-test--html)))
     ,@body))

(defconst edgar-test--10q
  (concat
   "PART I\nFINANCIAL INFORMATION\nItem 1. Financial Statements\n"
   "balance sheet and many other statements here\n"
   "Item 2. Management's Discussion\nsales rose a lot this quarter\n"
   "see Item 1A of this report for risks\n"
   "PART II\nOTHER INFORMATION\nItem 1. Legal Proceedings\nnone\n"
   "Item 2. Unregistered Sales\nnone sold\n"))

(defun edgar-test--g12-xml-snapshot (filing tree)
  "Return FILING and TREE's whole-text and generic-shape snapshot."
  (let* ((root (car (plist-get tree :children)))
         (text (edgar-structure-text tree))
         (normalized (edgar-fixtures-norm text))
         (elements
          (seq-filter
           (lambda (node)
             (eq (plist-get node :type) 'element))
           (plist-get root :children))))
    (list
     :form (plist-get filing :form)
     :text-length (length text)
     :text-sha256 (secure-hash 'sha256 text)
     :text-head (substring normalized 0 (min 100 (length normalized)))
     :structure
     (mapcar
      (lambda (node)
        (list
         (plist-get node :name)
         (mapcar
          (lambda (child) (plist-get child :name))
          (seq-filter
           (lambda (child) (eq (plist-get child :type) 'element))
           (plist-get node :children)))))
      elements))))

(defun edgar-test--document-snapshot (filing tree)
  "Return a whole-text and generic-shape snapshot for FILING and TREE."
  (let* ((text (edgar-structure-text tree))
         (headings (edgar-structure-headings tree)))
    (list
     :form (plist-get filing :form)
     :format (plist-get tree :format)
     :primary-document
     (edgar--primary-document-metadata
      (edgar-primary-document filing))
     :text-length (length text)
     :text-sha256 (secure-hash 'sha256 text)
     :paragraph-count (length (edgar-structure-paragraphs tree))
     :named-section-count (length headings)
     :named-section-head
     (mapcar
      (lambda (heading) (plist-get heading :name))
      (seq-take headings 3))
     :tag-counts
     (mapcar
      (lambda (name)
        (cons name (length (edgar-structure-nodes tree name))))
      '("html" "head" "body" "p" "table" "h1" "h2")))))

(defun edgar-test--g12-submission-filing (filing)
  "Return a copy of FILING pointing at its SEC complete-submission file."
  (plist-put
   (copy-sequence filing)
   :url
   (concat
    (file-name-directory (plist-get filing :url))
    (plist-get filing :accn)
    ".txt")))

(provide 'edgar-test-support)

;;; edgar-test-support.el ends here
