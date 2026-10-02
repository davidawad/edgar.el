;;; edgar-schedules.el --- Accessors for Schedule 13D and 13G -*- lexical-binding: t; -*-

;; Copyright (C) 2026

;; Author: David Awad
;; Keywords: finance, tools

;;; Commentary:

;; Typed cover-page accessors for structured Schedule 13D/G XML.  Legacy SC
;; 13D/G filings continue to use the generic `edgar-sections' interface.

;;; Code:

(require 'edgar-xml)
(require 'seq)
(require 'subr-x)

(defconst edgar-schedules--xml-forms
  '("SCHEDULE 13D" "SCHEDULE 13D/A" "SCHEDULE 13G" "SCHEDULE 13G/A")
  "Structured Schedule 13D/G filing forms.")

(defconst edgar-schedules--legacy-forms
  '("SC 13D" "SC 13D/A" "SC 13G" "SC 13G/A")
  "Legacy text Schedule 13D/G filing forms.")

(defun edgar-schedules--entries (node name)
  "Return child entries named NAME from projected XML NODE."
  (seq-filter (lambda (entry)
               (and (consp entry) (eq (car entry) name)))
              (cdr node)))

(defun edgar-schedules--first (node names)
  "Return first available child value from NODE among tag NAMES."
  (seq-some (lambda (name)
              (cdr (car (edgar-schedules--entries node name))))
            names))

(defun edgar-schedules--string (value)
  "Return string VALUE trimmed, or nil when it is empty or not a string."
  (when (stringp value)
    (let ((text (string-trim value)))
      (unless (string-empty-p text) text))))

(defun edgar-schedules--xml (filing)
  "Return projected XML for a structured Schedule 13D/G FILING, or nil."
  (when (member (plist-get filing :form) edgar-schedules--xml-forms)
    (let ((tree (edgar-xml filing)))
      (when (and (consp tree)
                 (eq (edgar-xml--local-name (car tree)) 'edgarSubmission))
        (edgar-xml-project tree)))))

(defun edgar-schedules-structured-p (filing)
  "Return non-nil when FILING contains structured Schedule 13D/G XML."
  (and (edgar-schedules--xml filing) t))

(defun edgar-schedule-13d-g-cover-page (filing)
  "Return structured Schedule 13D/G cover data from FILING.
The plist includes `:issuer' and `:reporting-persons'.  Share and percentage
values remain strings to preserve source formatting."
  (let* ((document (edgar-schedules--xml filing))
         (form-data (car (edgar-schedules--entries document 'formData)))
         (header (car (edgar-schedules--entries form-data 'coverPageHeader)))
         (issuer (car (edgar-schedules--entries header 'issuerInfo)))
         (reporting
          (or (edgar-schedules--entries form-data
                                        'coverPageHeaderReportingPersonDetails)
              (let* ((container
                      (car (edgar-schedules--entries form-data
                                                    'reportingPersons))))
                (edgar-schedules--entries container 'reportingPersonInfo))))
         (cusips (append (edgar-schedules--entries issuer 'issuerCusip)
                         (edgar-schedules--entries issuer 'issuerCUSIP)
                         (edgar-schedules--entries issuer 'issuerCusipNumber))))
    (when issuer
      (list
       :issuer
       (list :cik (edgar-schedules--string
                   (edgar-schedules--first issuer '(issuerCik issuerCIK)))
             :name (edgar-schedules--string
                    (edgar-schedules--first issuer '(issuerName)))
             :cusips
             (delq nil
                   (mapcar (lambda (entry)
                             (edgar-schedules--string (cdr entry)))
                           cusips)))
       :reporting-persons
       (mapcar
        (lambda (person)
          (let* ((shares
                  (or (car (edgar-schedules--entries
                            person 'reportingPersonBeneficiallyOwnedNumberOfShares))
                      person))
                 (items
                  (car (edgar-schedules--entries form-data 'items)))
                 (item4 (car (edgar-schedules--entries items 'item4))))
            (list
             :name (edgar-schedules--string
                    (edgar-schedules--first
                     person '(reportingPersonName)))
             :cik (edgar-schedules--string
                   (edgar-schedules--first person '(reportingCik
                                                     reportingPersonCIK)))
             :shares (edgar-schedules--string
                      (edgar-schedules--first
                       person '(reportingPersonBeneficiallyOwnedAggregateNumberOfShares
                                aggregateAmountOwned amountBeneficiallyOwned)))
             :percent-of-class
             (edgar-schedules--string
              (edgar-schedules--first person '(classPercent percentOfClass)))
             :type-of-reporting-person
             (edgar-schedules--string
              (edgar-schedules--first person '(typeOfReportingPerson)))
             :sole-voting-power
             (edgar-schedules--string
              (edgar-schedules--first
               shares '(soleVotingPower solePowerOrDirectToVote)))
             :shared-voting-power
             (edgar-schedules--string
              (edgar-schedules--first
               shares '(sharedVotingPower sharedPowerOrDirectToVote)))
             :sole-dispositive-power
             (edgar-schedules--string
              (edgar-schedules--first
               shares '(soleDispositivePower solePowerOrDirectToDispose)))
             :shared-dispositive-power
             (edgar-schedules--string
              (edgar-schedules--first
               shares '(sharedDispositivePower sharedPowerOrDirectToDispose)))
             :item-4-amount (edgar-schedules--string
                             (edgar-schedules--first item4
                                                     '(amountBeneficiallyOwned)))
             :item-4-percent (edgar-schedules--string
                              (edgar-schedules--first item4 '(classPercent))))))
        reporting)))))

(defun edgar-schedule-13d-purpose-of-transaction (filing)
  "Return Schedule 13D Item 4 purpose text from FILING.
For XML filings, return its `transactionPurpose' field; for legacy SC 13D
filings, reuse `edgar-section'.  Schedule 13G filings return nil."
  (let ((form (plist-get filing :form)))
    (cond
     ((member form '("SCHEDULE 13D" "SCHEDULE 13D/A"))
      (let* ((document (edgar-schedules--xml filing))
             (form-data (car (edgar-schedules--entries document 'formData)))
             (items (car (edgar-schedules--entries form-data 'items1To7)))
             (item4 (car (edgar-schedules--entries items 'item4))))
        (edgar-schedules--string
         (edgar-schedules--first item4 '(transactionPurpose)))))
     ((member form '("SC 13D" "SC 13D/A"))
      (edgar-section filing "4"))
     (t nil))))

(defun edgar-schedule-13d-g-legacy-sections (filing)
  "Return Item sections for legacy text Schedule 13D/G FILING, or nil."
  (when (member (plist-get filing :form) edgar-schedules--legacy-forms)
    (edgar-sections (edgar-text filing))))

(provide 'edgar-schedules)
;;; edgar-schedules.el ends here
