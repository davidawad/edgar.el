;;; edgar-13f.el --- Read Form 13F holdings tables -*- lexical-binding: t; -*-

;; Copyright (C) 2026

;;; Commentary:

;; Read the separate informationTable XML filed with a Form 13F-HR.

;;; Code:

(require 'cl-lib)
(require 'edgar)
(require 'edgar-xml)
(require 'json)
(require 'seq)
(require 'subr-x)

(cl-defstruct
 edgar-13f-notice
 "Typed values from a Form 13F notice filing."
 submission-type
 report-period
 amendment-p
 manager-cik
 manager-name
 manager-address
 report-type
 form-13f-file-number
 crd-number
 sec-file-number
 other-managers
 signature)

(defconst edgar-13f--dollar-vintage-date "2023-01-03"
  "Filing date on which Form 13F value reporting changed to dollars.")

(defun edgar-13f--base-url (filing)
  "Return the SEC accession directory URL for FILING."
  (let ((cik (plist-get filing :cik))
        (accession (plist-get filing :accn)))
    (unless (and cik accession)
      (error "EDGAR: Form 13F filing requires :cik and :accn"))
    (format "https://www.sec.gov/Archives/edgar/data/%d/%s"
            cik
            (replace-regexp-in-string "-" "" accession))))

(defun edgar-13f--information-table-url (filing)
  "Return the informationTable XML URL for FILING.
FILING may provide :info-url for offline fixtures and known document URLs."
  (or (plist-get filing :info-url)
      (let* ((data
              (json-parse-string (edgar--fetch
                                  (concat
                                   (edgar-13f--base-url filing)
                                   "/index.json"))
                                 :object-type 'alist
                                 :array-type 'list))
             (items (alist-get 'item (alist-get 'directory data)))
             (item
              (seq-some
               (lambda (candidate)
                 (let ((name (alist-get 'name candidate))
                       (type (alist-get 'type candidate)))
                   (and (stringp name)
                        (string-suffix-p ".xml" name t)
                        (or (equal type "INFORMATION TABLE")
                            (string-match-p
                             "information.?table" name))
                        candidate)))
               items)))
        (unless item
          (error
           "EDGAR: informationTable XML not found for %s"
           (plist-get filing :accn)))
        (concat
         (edgar-13f--base-url filing) "/" (alist-get 'name item)))))

(defun edgar-13f--node (value key)
  "Return the value for KEY in projected XML VALUE."
  (cdr (assq key value)))

(defun edgar-13f--nodes (value key)
  "Return every value for repeated KEY entries in projected XML VALUE."
  (mapcar
   #'cdr
   (seq-filter (lambda (entry) (eq (car-safe entry) key)) value)))

(defun edgar-13f--text (value key)
  "Return non-empty string KEY from projected XML VALUE."
  (let ((text (edgar-13f--node value key)))
    (and (stringp text) (not (string-empty-p text)) text)))

(defun edgar-13f--true-p (value)
  "Return non-nil when projected XML VALUE represents true."
  (and (stringp value) (member (downcase value) '("true" "1" "y")) t))

(defun edgar-13f--projected-root (filing)
  "Return FILING's projected edgarSubmission root, or nil."
  (let* ((tree (edgar-xml filing))
         (projected (and tree (edgar-xml-project tree))))
    (cond
     ((eq (car-safe projected) 'edgarSubmission)
      projected)
     ((eq (car-safe projected) 'top)
      (assq 'edgarSubmission (cdr projected))))))

(defun edgar-13f--address (value)
  "Return a normalized address plist from projected XML VALUE."
  (and value
       (list
        :street-1 (edgar-13f--text value 'street1)
        :street-2 (edgar-13f--text value 'street2)
        :city (edgar-13f--text value 'city)
        :state-or-country (edgar-13f--text value 'stateOrCountry)
        :zip (edgar-13f--text value 'zipCode))))

(defun edgar-13f--other-manager (value)
  "Return an other-manager plist from projected XML VALUE."
  (list
   :cik (edgar-13f--text value 'cik)
   :crd-number (edgar-13f--text value 'crdNumber)
   :sec-file-number (edgar-13f--text value 'secFileNumber)
   :name (edgar-13f--text value 'name)))

(defun edgar-13f--signature (value)
  "Return a signature plist from projected XML VALUE."
  (and value
       (list
        :name (edgar-13f--text value 'name)
        :title (edgar-13f--text value 'title)
        :phone (edgar-13f--text value 'phone)
        :signature (edgar-13f--text value 'signature)
        :city (edgar-13f--text value 'city)
        :state-or-country (edgar-13f--text value 'stateOrCountry)
        :date (edgar-13f--text value 'signatureDate))))

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
         (amount-number
          (and (stringp amount) (string-to-number amount)))
         (shares (edgar-13f--node row 'shrsOrPrnAmt))
         (voting (edgar-13f--node row 'votingAuthority)))
    (list
     :issuer (edgar-13f--node row 'nameOfIssuer)
     :class (edgar-13f--node row 'titleOfClass)
     :cusip (edgar-13f--node row 'cusip)
     :value amount
     :value-unit value-unit
     :value-usd
     (and amount-number
          (if (eq value-unit 'thousands)
              (* amount-number 1000)
            amount-number))
     :shares (edgar-13f--node shares 'sshPrnamt)
     :share-type (edgar-13f--node shares 'sshPrnamtType)
     :put-call (edgar-13f--node row 'putCall)
     :discretion (edgar-13f--node row 'investmentDiscretion)
     :other-manager (edgar-13f--node row 'otherManager)
     :voting
     (list
      :sole (edgar-13f--node voting 'Sole)
      :shared (edgar-13f--node voting 'Shared)
      :none (edgar-13f--node voting 'None)))))

(defun edgar-13f-holdings (filing)
  "Return normalized holdings from the separate informationTable of FILING.
Each holding includes issuer, class, CUSIP, reported value and unit, USD value,
shares, put/call, discretion, other manager, and voting authority.  Filing
values are in thousands before `edgar-13f--dollar-vintage-date' and dollars
from that date onward.  Return nil for forms other than 13F-HR variants."
  (when (member (plist-get filing :form) '("13F-HR" "13F-HR/A"))
    (let* ((filed (plist-get filing :filed))
           (value-unit
            (if (and filed
                     (not
                      (string< filed edgar-13f--dollar-vintage-date)))
                'usd
              'thousands))
           (url (edgar-13f--information-table-url filing))
           (tree
            (let ((xml (edgar--fetch url)))
              (with-temp-buffer
                (insert xml)
                (libxml-parse-xml-region (point-min) (point-max))))))
      (mapcar
       (lambda (row) (edgar-13f--holding row value-unit))
       (edgar-13f--rows tree)))))

(defun edgar-13f-notice (filing)
  "Return typed Form 13F notice data from FILING, or nil for another form.
The result includes the filing manager, repeated other managers, and signature.
Source strings are preserved exactly; absent optional values are nil."
  (when (member (plist-get filing :form) '("13F-NT" "13F-NT/A"))
    (let* ((root (edgar-13f--projected-root filing))
           (data (cdr root))
           (header (edgar-13f--node data 'headerData))
           (filer-info (edgar-13f--node header 'filerInfo))
           (submission-type (edgar-13f--text header 'submissionType)))
      (when (member submission-type '("13F-NT" "13F-NT/A"))
        (let* ((form-data (edgar-13f--node data 'formData))
               (cover (edgar-13f--node form-data 'coverPage))
               (manager (edgar-13f--node cover 'filingManager))
               (manager-cik
                (edgar-13f--node
                 (edgar-13f--node
                  (edgar-13f--node filer-info 'filer) 'credentials)
                 'cik))
               (other-info
                (edgar-13f--node cover 'otherManagersInfo)))
          (make-edgar-13f-notice
           :submission-type submission-type
           :report-period
           (edgar-13f--text cover 'reportCalendarOrQuarter)
           :amendment-p
           (edgar-13f--true-p (edgar-13f--text cover 'isAmendment))
           :manager-cik manager-cik
           :manager-name (edgar-13f--text manager 'name)
           :manager-address
           (edgar-13f--address (edgar-13f--node manager 'address))
           :report-type (edgar-13f--text cover 'reportType)
           :form-13f-file-number
           (edgar-13f--text cover 'form13FFileNumber)
           :crd-number (edgar-13f--text cover 'crdNumber)
           :sec-file-number
           (edgar-13f--text cover 'secFileNumber)
           :other-managers
           (mapcar
            #'edgar-13f--other-manager
            (edgar-13f--nodes other-info 'otherManager))
           :signature
           (edgar-13f--signature
            (edgar-13f--node form-data 'signatureBlock))))))))

(provide 'edgar-13f)
;;; edgar-13f.el ends here
