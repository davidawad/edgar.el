;;; edgar-nport-dataset-scan.el --- Scan N-PORT holdings into positions -*- lexical-binding: t; -*-

;;; Commentary:

;; Read FUND_REPORTED_HOLDING rows of the selected filings into one
;; position per security, fund and period (see
;; `edgar-nport-dataset-build' for the rules).  A position key packs the
;; security id, fund index and period bit into one fixnum; its cell is
;; (BALANCE VALUE . ATTRIBUTES), where ATTRIBUTES is a fixnum naming the
;; shared unit, payoff, asset and issuer categories and the currency flag.

;;; Code:

(require 'cl-lib)
(require 'edgar-dataset)
(require 'edgar-nport-dataset-build)

(defconst edgar-nport-dataset--cusip-modulus (expt 37 9)
  "Codes of the last nine characters of an eleven-character ISIN code.")

(defconst edgar-nport-dataset--cusip-countries
  (mapcar
   (lambda (country)
     (with-temp-buffer
       (insert country)
       (goto-char (point-min))
       (edgar-dataset-read-code)))
   '("US" "CA"))
  "Codes of the ISIN countries whose national number is the CUSIP.")

;; Slots of the field vector filled per holding row.
(defconst edgar-nport-dataset--holding-columns
  '(("ACCESSION_NUMBER" . 0)
    ("HOLDING_ID" . 1)
    ("ISSUER_NAME" . 2)
    ("ISSUER_TITLE" . 3)
    ("ISSUER_CUSIP" . 4)
    ("BALANCE" . 5)
    ("UNIT" . 6)
    ("CURRENCY_CODE" . 7)
    ("CURRENCY_VALUE" . 8)
    ("EXCHANGE_RATE" . 9)
    ("PAYOFF_PROFILE" . 10)
    ("ASSET_CAT" . 11)
    ("ISSUER_TYPE" . 12))
  "FUND_REPORTED_HOLDING columns read, with their field-vector slots.")

(defun edgar-nport-dataset--category (state text)
  "Return the small index of category string TEXT in STATE (0 for nil)."
  (if (null text)
      0
    (let ((table (edgar-nport-dataset--state-categories state)))
      (or (gethash text table)
          (puthash text (1+ (hash-table-count table)) table)))))

(defun edgar-nport-dataset--attributes
    (state unit payoff asset issuer flag)
  "Return the attributes code of UNIT PAYOFF ASSET ISSUER and FLAG.
The code and its strings are registered in STATE."
  (let ((code
         (+ (* 2
               (+ (* 64
                     (+ (* 64
                           (+ (* 64
                                 (edgar-nport-dataset--category
                                  state unit))
                              (edgar-nport-dataset--category
                               state payoff)))
                        (edgar-nport-dataset--category state asset)))
                  (edgar-nport-dataset--category state issuer)))
            (if flag
                1
              0)))
        (table (edgar-nport-dataset--state-attributes state)))
    (unless (gethash code table)
      (puthash code (vector unit payoff asset issuer flag) table))
    code))

(defun edgar-nport-dataset--string-at (pos)
  "Return the decoded field string starting at POS, or nil."
  (save-excursion
    (goto-char pos)
    (edgar-dataset-read-string)))

(defun edgar-nport-dataset--name-key (fields)
  "Return the issuer-and-title key of the holding FIELDS."
  (upcase
   (concat
    (or (edgar-nport-dataset--string-at (aref fields 2)) "")
    "\t"
    (or (edgar-nport-dataset--string-at (aref fields 3)) ""))))

(defun edgar-nport-dataset--new-security (state fields ids name)
  "Register a security for holding FIELDS in STATE and return its id.
IDS is (CUSIP ISIN TICKER); NAME is the issuer-and-title key or nil."
  (let ((id (edgar-nport-dataset--state-next-id state))
        (cusip (car ids))
        (isin (nth 1 ids)))
    (setf (edgar-nport-dataset--state-next-id state) (1+ id))
    (puthash
     id
     (vector
      (and cusip (edgar-dataset-code-string cusip))
      (and isin (edgar-nport-dataset-isin-string isin))
      (nth 2 ids)
      (edgar-nport-dataset--string-at (aref fields 2))
      (edgar-nport-dataset--string-at (aref fields 3))
      (aref fields 11)
      (aref fields 12))
     (edgar-nport-dataset--state-securities state))
    (when name
      (puthash name id (edgar-nport-dataset--state-name-ids state)))
    id))

(defun edgar-nport-dataset--security (state fields ids)
  "Return the security id of holding FIELDS with IDS, registering it in STATE.
IDS is (CUSIP ISIN TICKER) with codes for CUSIP and ISIN."
  (let* ((cusip (car ids))
         (isin (nth 1 ids))
         (cusip-ids (edgar-nport-dataset--state-cusip-ids state))
         (isin-ids (edgar-nport-dataset--state-isin-ids state))
         (name
          (and (not cusip)
               (not isin)
               (edgar-nport-dataset--name-key fields)))
         (id
          (or (and cusip (gethash cusip cusip-ids))
              (and isin (gethash isin isin-ids))
              (and name
                   (gethash
                    name (edgar-nport-dataset--state-name-ids state)))
              (edgar-nport-dataset--new-security
               state fields ids name))))
    (when (and isin (not (gethash isin isin-ids)))
      (puthash isin id isin-ids))
    (when (and cusip (not (gethash cusip cusip-ids)))
      (puthash cusip id cusip-ids))
    (when (or isin (nth 2 ids))
      (let ((security
             (gethash
              id (edgar-nport-dataset--state-securities state))))
        (when (and isin (null (aref security 1)))
          (aset security 1 (edgar-nport-dataset-isin-string isin)))
        (when (null (aref security 2))
          (aset security 2 (nth 2 ids)))))
    id))

(defun edgar-nport-dataset--resolve-cusip (cusip isin)
  "Return CUSIP, or the CUSIP embedded in a US or CA ISIN code ISIN."
  (or cusip
      (and isin
           (memq
            (/ isin edgar-nport-dataset--cusip-modulus)
            edgar-nport-dataset--cusip-countries)
           (% isin edgar-nport-dataset--cusip-modulus))))

(defun edgar-nport-dataset--read-holding (roles accessions fields)
  "Fill FIELDS from the holding row at point by ROLES.
Return non-nil when the row belongs to a filing in ACCESSIONS; slot 0
then holds FUND*2+BIT.  Category fields hold their start position."
  (let ((n (length roles))
        (col 0))
    (fillarray fields nil)
    (while (< col n)
      (let ((slot (aref roles col)))
        (cond
         ((null slot)
          (edgar-dataset-skip-fields 1))
         ((= slot 0)
          (unless (aset
                   fields 0
                   (gethash (edgar-dataset-read-digits) accessions))
            (setq col n)))
         ((= slot 4)
          (aset fields 4 (edgar-dataset-read-identifier 9)))
         ((memq slot '(1 5 8))
          (aset fields slot (edgar-dataset-read-integer)))
         ((= slot 9)
          (aset fields 9 (edgar-dataset-read-char)))
         (t
          (aset fields slot (point))
          (edgar-dataset-skip-fields 1))))
      (setq col (1+ col)))
    (aref fields 0)))

(defun edgar-nport-dataset--add (state fields ids)
  "Add the holding FIELDS with IDS to STATE.
Slots 6, 7, 10, 11 and 12 must already hold interned strings."
  (let* ((id (edgar-nport-dataset--security state fields ids))
         (key
          (+ (ash id (1+ edgar-nport-dataset--fund-bits))
             (aref fields 0)))
         (positions (edgar-nport-dataset--state-positions state))
         (cell (gethash key positions))
         (balance (or (aref fields 5) 0))
         (value (or (aref fields 8) 0)))
    (if cell
        (progn
          (setcar cell (+ (car cell) balance))
          (setcar (cdr cell) (+ (cadr cell) value)))
      (let* ((currency (aref fields 7))
             (flag
              (and currency
                   (not (member currency '("USD" "N/A")))
                   (null (aref fields 9)))))
        (when flag
          (cl-incf (edgar-nport-dataset--state-unconverted state)))
        (puthash
         key
         (cons
          balance
          (cons
           value
           (edgar-nport-dataset--attributes
            state
            (aref fields 6)
            (aref fields 10)
            (aref fields 11)
            (aref fields 12)
            flag)))
         positions)))))

(defun edgar-nport-dataset--intern-slots (fields strings)
  "Replace the category positions in FIELDS by strings shared via STRINGS."
  (dolist (slot '(6 7 10 11 12))
    (let ((pos (aref fields slot)))
      (when pos
        (goto-char pos)
        (aset fields slot (edgar-dataset-read-interned strings))))))

(defun edgar-nport-dataset--scan (zip accessions state)
  "Add the FUND_REPORTED_HOLDING rows of ZIP in ACCESSIONS to STATE."
  (let* ((strings (edgar-nport-dataset--state-strings state))
         (ids (edgar-nport-dataset--read-identifiers zip strings))
         (isins (car ids))
         (tickers (cdr ids))
         (fields (make-vector 13 nil))
         roles)
    (edgar-dataset-map-lines
     zip "FUND_REPORTED_HOLDING.tsv"
     (lambda (_beg _end)
       (unless roles
         (setq roles
               (edgar-nport-dataset--column-roles
                edgar-nport-dataset--holding-columns)))
       (when (edgar-nport-dataset--read-holding
              roles accessions fields)
         (let* ((holding (aref fields 1))
                (isin (gethash holding isins)))
           (edgar-nport-dataset--intern-slots fields strings)
           (cl-incf (edgar-nport-dataset--state-rows state))
           (edgar-nport-dataset--add
            state fields
            (list
             (edgar-nport-dataset--resolve-cusip (aref fields 4) isin)
             isin
             (gethash holding tickers)))))))))

(provide 'edgar-nport-dataset-scan)
;;; edgar-nport-dataset-scan.el ends here
