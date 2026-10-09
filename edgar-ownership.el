;;; edgar-ownership.el --- Typed accessors for SEC ownership filings -*- lexical-binding: t; -*-

;; Copyright (C) 2026

;; Author: David Awad
;; Keywords: finance, tools

;;; Commentary:

;; Typed plist accessors for Forms 3, 4, and 5.  The generic XML interface
;; intentionally drops XML attributes; this module reads ownershipDocument
;; nodes directly so footnote identifiers remain available.

;;; Code:

(require 'edgar-xml)
(require 'seq)

(defun edgar-ownership--elements (node &optional name)
  "Return element children of NODE, optionally restricted to NAME."
  (seq-filter
   (lambda (child)
     (and (consp child)
          (symbolp (car child))
          (or (null name)
              (eq (edgar-xml--local-name (car child)) name))))
   (cdr node)))

(defun edgar-ownership--child (node name)
  "Return the first child element NAME of NODE."
  (car (edgar-ownership--elements node name)))

(defun edgar-ownership--text (node)
  "Return all text contained in NODE, in document order."
  (when node
    (let ((text
           (string-trim
            (mapconcat
             (lambda (part)
               (cond
                ((stringp part) part)
                ((and (consp part) (symbolp (car part)))
                 (or (edgar-ownership--text part) ""))
                (t "")))
             (cddr node) ""))))
      (unless (string-empty-p text) text))))

(defun edgar-ownership--value (node)
  "Return NODE's <value> text, or its direct text if there is no <value>."
  (when node
    (let ((value (edgar-ownership--child node 'value)))
      (edgar-ownership--text (or value node)))))

(defun edgar-ownership--bool (node)
  "Return NODE's boolean value as t, nil, or nil when absent."
  (let ((value (edgar-ownership--text node)))
    (and value
         (member (downcase value) '("true" "1" "y"))
         t)))

(defun edgar-ownership--attribute (node name)
  "Return attribute NAME from XML NODE."
  (alist-get name (cadr node)))

(defun edgar-ownership--walk (node name)
  "Return all descendants of NODE named NAME, in document order."
  (when (consp node)
    (append
     (and (eq (edgar-xml--local-name (car node)) name) (list node))
     (apply #'append
            (mapcar (lambda (child)
                      (edgar-ownership--walk child name))
                    (edgar-ownership--elements node))))))

(defun edgar-ownership--footnote-ids (node)
  "Return referenced footnote IDs in NODE, preserving first occurrence."
  (delete-dups
   (mapcar (lambda (reference)
             (edgar-ownership--attribute reference 'id))
           (edgar-ownership--walk node 'footnoteId))))

(defun edgar-ownership-document (filing)
  "Return FILING's ownershipDocument XML tree, or nil for other XML forms."
  (let ((tree (edgar-xml filing)))
    (and (consp tree)
         (eq (edgar-xml--local-name (car tree)) 'ownershipDocument)
         tree)))

(defun edgar-ownership-issuer (filing)
  "Return FILING's issuer as a plist with `:cik', `:name', and `:ticker'."
  (let* ((issuer (edgar-ownership--child
                  (edgar-ownership-document filing) 'issuer)))
    (when issuer
      (list :cik (edgar-ownership--text
                  (edgar-ownership--child issuer 'issuerCik))
            :name (edgar-ownership--text
                   (edgar-ownership--child issuer 'issuerName))
            :ticker (edgar-ownership--text
                     (edgar-ownership--child issuer 'issuerTradingSymbol))))))

(defun edgar-ownership-reporting-owners (filing)
  "Return FILING's reporting owners, including addresses and relationships."
  (let ((document (edgar-ownership-document filing)))
    (mapcar
     (lambda (owner)
       (let* ((id (edgar-ownership--child owner 'reportingOwnerId))
              (address (edgar-ownership--child owner 'reportingOwnerAddress))
              (relationship
               (edgar-ownership--child owner 'reportingOwnerRelationship)))
         (list
          :cik (edgar-ownership--text
                (edgar-ownership--child id 'rptOwnerCik))
          :name (edgar-ownership--text
                 (edgar-ownership--child id 'rptOwnerName))
          :address
          (and address
               (list :street-1 (edgar-ownership--text
                                (edgar-ownership--child address 'rptOwnerStreet1))
                     :street-2 (edgar-ownership--text
                                (edgar-ownership--child address 'rptOwnerStreet2))
                     :city (edgar-ownership--text
                            (edgar-ownership--child address 'rptOwnerCity))
                     :state (edgar-ownership--text
                             (edgar-ownership--child address 'rptOwnerState))
                     :zip (edgar-ownership--text
                           (edgar-ownership--child address 'rptOwnerZipCode))
                     :country (edgar-ownership--text
                               (or (edgar-ownership--child address
                                                           'rptOwnerCountry)
                                   (edgar-ownership--child address
                                    'rptOwnerStateDescription)))))
          :is-director (edgar-ownership--bool
                        (edgar-ownership--child relationship 'isDirector))
          :is-officer (edgar-ownership--bool
                       (edgar-ownership--child relationship 'isOfficer))
          :is-ten-percent-owner
          (edgar-ownership--bool
           (edgar-ownership--child relationship 'isTenPercentOwner))
          :is-other (edgar-ownership--bool
                     (edgar-ownership--child relationship 'isOther))
          :officer-title (edgar-ownership--text
                          (edgar-ownership--child relationship 'officerTitle))
          :other-text (edgar-ownership--text
                       (edgar-ownership--child relationship 'otherText)))))
     (edgar-ownership--elements document 'reportingOwner))))

(defun edgar-ownership-footnotes (filing)
  "Return FILING's footnotes as plists with `:id' and `:text'."
  (let ((footnotes
         (edgar-ownership--child
          (edgar-ownership-document filing) 'footnotes)))
    (mapcar
     (lambda (note)
       (list :id (edgar-ownership--attribute note 'id)
             :text (edgar-ownership--text note)))
     (edgar-ownership--elements footnotes 'footnote))))

(defun edgar-ownership--row (node kind footnotes)
  "Convert transaction or holding NODE of KIND to a typed plist.
FOOTNOTES maps referenced IDs to their text."
  (let* ((amounts (edgar-ownership--child node 'transactionAmounts))
         (post (edgar-ownership--child node 'postTransactionAmounts))
         (security (edgar-ownership--child node 'securityTitle))
         (coding (edgar-ownership--child node 'transactionCoding))
         (nature (edgar-ownership--child node 'ownershipNature))
         (underlying (edgar-ownership--child node 'underlyingSecurity))
         (ids (edgar-ownership--footnote-ids node)))
    (list
     :kind kind
     :security-title (edgar-ownership--value security)
     :date (edgar-ownership--value
            (edgar-ownership--child node 'transactionDate))
     :code (edgar-ownership--text
            (edgar-ownership--child coding 'transactionCode))
     :shares (edgar-ownership--value
              (edgar-ownership--child amounts 'transactionShares))
     :price (edgar-ownership--value
             (edgar-ownership--child amounts 'transactionPricePerShare))
     :acquired-disposed
     (edgar-ownership--value
      (edgar-ownership--child amounts 'transactionAcquiredDisposedCode))
     :shares-owned-following
     (edgar-ownership--value
      (edgar-ownership--child post 'sharesOwnedFollowingTransaction))
     :direct-indirect
     (edgar-ownership--value
      (edgar-ownership--child nature 'directOrIndirectOwnership))
     :nature-of-ownership
     (edgar-ownership--value
      (edgar-ownership--child nature 'natureOfOwnership))
     :exercise-price (edgar-ownership--value
                      (edgar-ownership--child node 'conversionOrExercisePrice))
     :exercise-date (edgar-ownership--value
                     (edgar-ownership--child node 'exerciseDate))
     :expiration-date (edgar-ownership--value
                       (edgar-ownership--child node 'expirationDate))
     :underlying-security-title
     (edgar-ownership--value
      (edgar-ownership--child underlying 'underlyingSecurityTitle))
     :underlying-security-shares
     (edgar-ownership--value
      (edgar-ownership--child underlying 'underlyingSecurityShares))
     :footnote-ids ids
     :footnotes (delq nil (mapcar (lambda (id) (cdr (assoc id footnotes))) ids)))))

(defun edgar-ownership--footnote-table (filing)
  "Return an alist mapping FILING footnote identifiers to text."
  (mapcar (lambda (note)
            (cons (plist-get note :id) (plist-get note :text)))
          (edgar-ownership-footnotes filing)))

(defun edgar-ownership-transactions (filing)
  "Return FILING's non-derivative and derivative transactions as plists."
  (let* ((document (edgar-ownership-document filing))
         (footnotes (edgar-ownership--footnote-table filing)))
    (when document
      (append
       (mapcar (lambda (row) (edgar-ownership--row row 'non-derivative footnotes))
               (edgar-ownership--walk document 'nonDerivativeTransaction))
       (mapcar (lambda (row) (edgar-ownership--row row 'derivative footnotes))
               (edgar-ownership--walk document 'derivativeTransaction))))))

(defun edgar-form4-transactions (filing)
  "Return Form 4 FILING's transaction rows as plists, or nil for other forms."
  (when (member (plist-get filing :form) '("4" "4/A"))
    (edgar-ownership-transactions filing)))

(defun edgar-ownership-holdings (filing)
  "Return FILING's non-derivative and derivative holdings as plists."
  (let* ((document (edgar-ownership-document filing))
         (footnotes (edgar-ownership--footnote-table filing)))
    (when document
      (append
       (mapcar (lambda (row) (edgar-ownership--row row 'non-derivative footnotes))
               (edgar-ownership--walk document 'nonDerivativeHolding))
       (mapcar (lambda (row) (edgar-ownership--row row 'derivative footnotes))
               (edgar-ownership--walk document 'derivativeHolding))))))

(defun edgar-form3-holdings (filing)
  "Return Form 3 FILING's holdings, or nil for other forms."
  (when (member (plist-get filing :form) '("3" "3/A"))
    (edgar-ownership-holdings filing)))

(defun edgar-form5-holdings (filing)
  "Return Form 5 FILING's holdings, or nil for other forms."
  (when (member (plist-get filing :form) '("5" "5/A"))
    (edgar-ownership-holdings filing)))

(defun edgar-ownership-10b5-1-p (filing)
  "Return non-nil if FILING declares an affirmative Rule 10b5-1 plan."
  (edgar-ownership--bool
   (edgar-ownership--child
    (edgar-ownership-document filing) 'aff10b5One)))

(defun edgar-ownership-signatures (filing)
  "Return FILING's owner signatures as plists with `:name' and `:date'."
  (let ((document (edgar-ownership-document filing)))
    (mapcar
     (lambda (signature)
       (list :name (edgar-ownership--text
                    (edgar-ownership--child signature 'signatureName))
             :date (edgar-ownership--text
                    (edgar-ownership--child signature 'signatureDate))))
     (edgar-ownership--elements document 'ownerSignature))))

(provide 'edgar-ownership)
;;; edgar-ownership.el ends here
