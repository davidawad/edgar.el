;;; edgar-nport-dataset-rows.el --- Rows of the N-PORT index -*- lexical-binding: t; -*-

;;; Commentary:

;; Helpers behind `edgar-nport-dataset': parse securities.tsv lines,
;; turn fund records into holding plists with a status, and count them.

;;; Code:

(require 'cl-lib)
(require 'edgar-dataset)
(require 'subr-x)

(defconst edgar-nport-dataset--statuses
  '(new added reduced unchanged exited not-reported)
  "Holding statuses, in display order.")

;;;; Security lines

(defun edgar-nport-dataset--number (text)
  "Return the integer in TEXT."
  (string-to-number text))

(defun edgar-nport-dataset--field (bol n)
  "Return the bounds of field N (1 is the CUSIP) of the line at BOL.
The securities buffer is unibyte, so bounds are byte positions."
  (goto-char (1+ bol))
  (dotimes (_ (1- n))
    (skip-chars-forward "^\t\n")
    (forward-char 1))
  (cons
   (point)
   (progn
     (skip-chars-forward "^\t\n")
     (point))))

(defun edgar-nport-dataset--field-number (bol n)
  "Return field N of the line at BOL as a number."
  (let ((bounds (edgar-nport-dataset--field bol n)))
    (string-to-number
     (buffer-substring-no-properties (car bounds) (cdr bounds)))))

(defun edgar-nport-dataset--line (pos)
  "Return the security plist of the securities.tsv line at POS."
  (let* ((fields
          (split-string (buffer-substring-no-properties
                         (1+ pos)
                         (save-excursion
                           (goto-char pos)
                           (line-end-position)))
                        "\t"))
         (text
          (lambda (n)
            (let ((value (nth n fields)))
              (and value
                   (not (string-empty-p value))
                   (decode-coding-string value 'utf-8)))))
         (number (lambda (n) (string-to-number (nth n fields)))))
    (list
     :cusip (funcall text 0)
     :isin (funcall text 1)
     :ticker (funcall text 2)
     :issuer (funcall text 3)
     :title (funcall text 4)
     :asset-category (funcall text 5)
     :issuer-category (funcall text 6)
     :funds (funcall number 7)
     :prior-funds (funcall number 8)
     :change (- (funcall number 7) (funcall number 8))
     :value-usd (funcall number 9)
     :prior-value-usd (funcall number 10)
     :slice (cons (funcall number 11) (funcall number 12)))))

(defun edgar-nport-dataset--find (id)
  "Return the position of the most widely held security with ID, or nil.
ID matches the CUSIP, ISIN or ticker column, case-insensitively."
  (let ((needle
         (encode-coding-string
          (concat "\t" (upcase (string-trim id)) "\t") 'utf-8))
        (case-fold-search t)
        found)
    (goto-char (point-min))
    (while (and (not found) (search-forward needle nil t))
      (let ((bol (line-beginning-position)))
        (when (<= (cl-count
                   ?\t
                   (buffer-substring bol (match-beginning 0)))
                  2)
          (setq found bol))
        (goto-char (1- (point)))))
    found))

;;;; Holding rows

(defun edgar-nport-dataset--status
    (balance prior-balance filed-current)
  "Return the status of a holding of BALANCE now and PRIOR-BALANCE before.
FILED-CURRENT is non-nil when the fund has a current report; a prior
holding without one is `not-reported' rather than `exited'."
  (cond
   ((null prior-balance)
    'new)
   ((null balance)
    (if filed-current
        'exited
      'not-reported))
   ((> balance prior-balance)
    'added)
   ((< balance prior-balance)
    'reduced)
   (t
    'unchanged)))

(defun edgar-nport-dataset--holding (record fund attributes)
  "Return the holding plist of RECORD for FUND's plist.
ATTRIBUTES maps attribute codes to [UNIT PAYOFF ASSET ISSUER FLAG]."
  (let* ((balance (aref record 1))
         (value (aref record 2))
         (net-assets (plist-get fund :net-assets))
         (strings
          (gethash (or (aref record 5) (aref record 6)) attributes))
         (filed-current (and (plist-get fund :filing) t)))
    (list
     :balance balance
     :units (aref strings 0)
     :value-usd value
     :pct-of-nav
     (and value
          net-assets
          (/= net-assets 0)
          (/ (* 100.0 value) net-assets))
     :asset-category (aref strings 2)
     :issuer-category (aref strings 3)
     :payoff-profile (aref strings 1)
     :value-unconverted (aref strings 4)
     :prior-balance (aref record 3)
     :prior-value-usd (aref record 4)
     :status
     (edgar-nport-dataset--status
      balance (aref record 3) filed-current)
     :filed-current filed-current)))

(defun edgar-nport-dataset--by-value (rows)
  "Sort ROWS by current value, then exited rows by prior value."
  (sort rows
        (lambda (a b)
          (let ((va (plist-get a :value-usd))
                (vb (plist-get b :value-usd)))
            (cond
             ((and va vb)
              (> va vb))
             (va
              t)
             (vb
              nil)
             (t
              (> (or (plist-get a :prior-value-usd) 0)
                 (or (plist-get b :prior-value-usd) 0))))))))

(defun edgar-nport-dataset--counts (rows)
  "Return a plist counting ROWS per status."
  (cl-loop
   for status in edgar-nport-dataset--statuses append
   (list
    (intern (format ":%s" status))
    (cl-count
     status
     rows
     :key (lambda (row) (plist-get row :status))))))

(defun edgar-nport-dataset--slice (index file bounds)
  "Read the slice BOUNDS of FILE in INDEX's directory."
  (edgar-dataset-read-object
   (expand-file-name file (plist-get index :directory)) bounds))

(provide 'edgar-nport-dataset-rows)
;;; edgar-nport-dataset-rows.el ends here
