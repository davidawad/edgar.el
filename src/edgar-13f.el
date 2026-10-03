;;; edgar-13f.el --- Read Form 13F holdings tables -*- lexical-binding: t; -*-

;; Copyright (C) 2026

;;; Commentary:

;; Read the separate informationTable XML filed with a Form 13F-HR.

;;; Code:

(require 'edgar)
(require 'edgar-xml)
(require 'json)
(require 'seq)
(require 'subr-x)

(defconst edgar-13f--dollar-vintage-date "2023-01-03"
  "Filing date on which Form 13F value reporting changed to dollars.")

(defun edgar-13f--base-url (filing)
  "Return the SEC accession directory URL for FILING."
  (let ((cik (plist-get filing :cik))
        (accession (plist-get filing :accn)))
    (unless (and cik accession)
      (error "EDGAR: Form 13F filing requires :cik and :accn"))
    (format "https://www.sec.gov/Archives/edgar/data/%d/%s"
            cik (replace-regexp-in-string "-" "" accession))))

(defun edgar-13f--information-table-url (filing)
  "Return the informationTable XML URL for FILING.
FILING may provide :info-url for offline fixtures and known document URLs."
  (or (plist-get filing :info-url)
      (let* ((data (json-parse-string
                    (edgar--fetch
                     (concat (edgar-13f--base-url filing) "/index.json"))
                    :object-type 'alist :array-type 'list))
             (items (alist-get 'item (alist-get 'directory data)))
             (item
              (seq-some
               (lambda (candidate)
                 (let ((name (alist-get 'name candidate))
                       (type (alist-get 'type candidate)))
                   (and (stringp name) (string-suffix-p ".xml" name t)
                        (or (equal type "INFORMATION TABLE")
                            (string-match-p "information.?table" name))
                        candidate)))
               items)))
        (unless item
          (error "EDGAR: informationTable XML not found for %s"
                 (plist-get filing :accn)))
        (concat (edgar-13f--base-url filing) "/"
                (alist-get 'name item)))))

(defun edgar-13f--node (value key)
  "Return the value for KEY in projected XML VALUE."
  (cdr (assq key value)))

(defun edgar-13f--rows (tree)
  "Return projected informationTable rows from XML TREE."
  (let* ((projected (edgar-xml-project tree))
         (root (cdr projected)))
    (unless (eq (car projected) 'informationTable)
      (error "EDGAR: expected informationTable XML"))
    (seq-filter (lambda (entry) (eq (car entry) 'infoTable)) root)))

(defun edgar-13f--holding (row value-unit)
  "Convert projected 13F ROW into a normalized holding using VALUE-UNIT."
  (let* ((amount (edgar-13f--node row 'value))
         (amount-number (and (stringp amount) (string-to-number amount)))
         (shares (edgar-13f--node row 'shrsOrPrnAmt))
         (voting (edgar-13f--node row 'votingAuthority)))
    (list
     :issuer (edgar-13f--node row 'nameOfIssuer)
     :class (edgar-13f--node row 'titleOfClass)
     :cusip (edgar-13f--node row 'cusip)
     :value amount
     :value-unit value-unit
     :value-usd (and amount-number
                     (if (eq value-unit 'thousands)
                         (* amount-number 1000)
                       amount-number))
     :shares (edgar-13f--node shares 'sshPrnamt)
     :share-type (edgar-13f--node shares 'sshPrnamtType)
     :put-call (edgar-13f--node row 'putCall)
     :discretion (edgar-13f--node row 'investmentDiscretion)
     :other-manager (edgar-13f--node row 'otherManager)
     :voting (list :sole (edgar-13f--node voting 'Sole)
                   :shared (edgar-13f--node voting 'Shared)
                   :none (edgar-13f--node voting 'None)))))

(defun edgar-13f-holdings (filing)
  "Return normalized holdings from the separate informationTable of FILING.
Each holding includes issuer, class, CUSIP, reported value and unit, USD value,
shares, put/call, discretion, other manager, and voting authority.  Filing
values are in thousands before `edgar-13f--dollar-vintage-date' and dollars
from that date onward."
  (let* ((filed (plist-get filing :filed))
         (value-unit
          (if (and filed (not (string< filed edgar-13f--dollar-vintage-date)))
              'usd
            'thousands))
         (url (edgar-13f--information-table-url filing))
         (tree (let ((xml (edgar--fetch url)))
                 (with-temp-buffer
                   (insert xml)
                   (libxml-parse-xml-region (point-min) (point-max))))))
    (mapcar (lambda (row) (edgar-13f--holding row value-unit))
            (edgar-13f--rows tree))))

(provide 'edgar-13f)
;;; edgar-13f.el ends here
