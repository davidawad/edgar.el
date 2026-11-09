;;; edgar-dataset.el --- SEC bulk data sets: download, TSV rows, disk indexes -*- lexical-binding: t; -*-

;;; Commentary:

;; Generic plumbing for the SEC's quarterly bulk data sets (Form 13F,
;; N-PORT, ...): each is a ZIP of tab-separated tables.
;;
;; - `edgar-dataset-zip-urls' lists the ZIP links on a data-set page.
;; - `edgar-dataset-download' fetches a ZIP into
;;   `edgar-dataset-cache-directory' with `xbrl-user-agent'.
;; - `edgar-dataset-map-lines' extracts one TSV member with
;;   `edgar-unzip-program' and visits its rows chunk by chunk, so the
;;   member is never held in memory as one string.  The callback reads
;;   fields at point with the cursor helpers (`edgar-dataset-read-string',
;;   `edgar-dataset-read-integer', ...), which allocate nothing for
;;   numeric and code fields.  `edgar-dataset-map-rows' is the convenient
;;   variant that hands each row over as a vector of strings.
;; - `edgar-dataset-latest-urls' picks the newest data sets on a page by
;;   the coverage dates in their file names.
;; - edgar-dataset-store.el (loaded with this file) persists built indexes
;;   keyed by their source URLs, reads back single slices, and runs builds
;;   in a batch Emacs subprocess (`edgar-dataset-batch',
;;   `edgar-dataset-index-async'), so the caller never blocks.

;;; Code:

(require 'cl-lib)
(require 'edgar-dataset-store)
(require 'edgar-http)
(require 'seq)
(require 'subr-x)
(require 'url)
(require 'xbrl)

(defgroup edgar-dataset nil
  "SEC bulk data sets."
  :group 'edgar-http)

(defcustom edgar-dataset-cache-directory
  (expand-file-name "edgar-dataset-cache/" user-emacs-directory)
  "Directory holding downloaded SEC data-set ZIPs and built indexes."
  :type 'directory
  :group 'edgar-dataset)

(defcustom edgar-unzip-program "unzip"
  "Program used to extract members of SEC data-set ZIP files."
  :type 'string
  :group 'edgar-dataset)

(defcustom edgar-dataset-chunk-size (* 8 1024 1024)
  "Bytes of an extracted TSV member read into memory at a time."
  :type 'integer
  :group 'edgar-dataset)

(defvar edgar-dataset-header nil
  "Vector of column names of the TSV member being visited.")

(defvar edgar-dataset--header-index nil
  "Hash table from column name to index for `edgar-dataset-header'.")


;;;; Data-set pages and downloads

(defun edgar-dataset-zip-urls (page-url)
  "Return absolute ZIP URLs linked from the SEC data-set page PAGE-URL.
URLs keep the page's order, which lists the newest data set first."
  (let ((html (edgar-http-get page-url xbrl-user-agent))
        (start 0)
        urls)
    (while (string-match "href=\"\\([^\"]+\\.zip\\)\"" html start)
      (let ((link (match-string 1 html)))
        (setq start (match-end 0))
        (push (url-expand-file-name link page-url) urls)))
    (delete-dups (nreverse urls))))

(defun edgar-dataset-local-file (url)
  "Return the cache file name for data-set URL."
  (expand-file-name (concat
                     (substring (secure-hash 'sha1 url) 0 10) "-"
                     (file-name-nondirectory
                      (url-filename (url-generic-parse-url url))))
                    edgar-dataset-cache-directory))

(defun edgar-dataset--write-response (file)
  "Write the body of the current HTTP response buffer to FILE.
Signal an error unless the response status is 2xx."
  (set-buffer-multibyte nil)
  (goto-char (point-min))
  (unless (looking-at "HTTP/[0-9.]+ \\([0-9]+\\)")
    (error "EDGAR dataset: malformed response"))
  (let ((status (string-to-number (match-string 1))))
    (unless (and (>= status 200) (< status 300))
      (error "EDGAR dataset: HTTP %s" status)))
  (unless (re-search-forward "\r?\n\r?\n" nil t)
    (error "EDGAR dataset: missing response body"))
  (let ((coding-system-for-write 'no-conversion))
    (write-region (point) (point-max) file nil 'silent)))

(defun edgar-dataset-download (url)
  "Return a local file name holding the data set at URL.
An existing local file name is returned unchanged.  Otherwise the ZIP is
fetched once with `xbrl-user-agent' and kept in
`edgar-dataset-cache-directory'; published data sets never change."
  (if (file-exists-p url)
      (expand-file-name url)
    (let ((file (edgar-dataset-local-file url)))
      (unless (file-exists-p file)
        (make-directory edgar-dataset-cache-directory t)
        (edgar-http--throttle)
        (let* ((url-request-extra-headers
                `(("User-Agent" . ,xbrl-user-agent)))
               (buffer (url-retrieve-synchronously url t t 900))
               (partial (concat file ".part")))
          (unless buffer
            (error "EDGAR dataset: no response from %s" url))
          (unwind-protect
              (with-current-buffer buffer
                (edgar-dataset--write-response partial))
            (kill-buffer buffer))
          (rename-file partial file t)))
      file)))

;;;; Dates and data-set names

(defconst edgar-dataset--months
  '("JAN"
    "FEB"
    "MAR"
    "APR"
    "MAY"
    "JUN"
    "JUL"
    "AUG"
    "SEP"
    "OCT"
    "NOV"
    "DEC")
  "Month abbreviations used by SEC data-set dates.")

(defun edgar-dataset-iso-date (text)
  "Convert an SEC data-set date such as 31-JUL-2026 in TEXT to ISO form."
  (when
      (and
       text
       (string-match
        "\\`\\([0-9]\\{1,2\\}\\)-\\([A-Za-z]\\{3\\}\\)-\\([0-9]\\{4\\}\\)\\'"
        text))
    (let ((month
           (cl-position
            (upcase (match-string 2 text))
            edgar-dataset--months
            :test #'equal)))
      (and month
           (format "%s-%02d-%02d"
                   (match-string 3 text)
                   (1+ month)
                   (string-to-number (match-string 1 text)))))))

(defun edgar-dataset-end-date (url)
  "Return the last date covered by the data set named in URL, or nil.
Names end in a range such as 01jun2026-31aug2026_form13f.zip or a
quarter such as 2026q3_nport.zip."
  (let ((name (file-name-nondirectory url)))
    (cond
     ((string-match
       "-\\([0-9]\\{2\\}[a-z]\\{3\\}[0-9]\\{4\\}\\)_" name)
      (let ((text (match-string 1 name)))
        (edgar-dataset-iso-date
         (format "%s-%s-%s"
                 (substring text 0 2)
                 (substring text 2 5)
                 (substring text 5)))))
     ((string-match "\\([0-9]\\{4\\}\\)q\\([1-4]\\)_" name)
      (format "%s-%s"
              (match-string 1 name)
              (nth
               (1- (string-to-number (match-string 2 name)))
               '("03-31" "06-30" "09-30" "12-31")))))))

(defun edgar-dataset-latest-urls (page-url &optional count)
  "Return the newest COUNT (default 2) data-set URLs on PAGE-URL.
URLs are ordered newest first by `edgar-dataset-end-date'."
  (seq-take (seq-sort-by
             (lambda (url) (or (edgar-dataset-end-date url) ""))
             (lambda (a b) (string< b a))
             (edgar-dataset-zip-urls page-url))
            (or count 2)))

;;;; Reading TSV members

(defun edgar-dataset--extract (zip member)
  "Extract MEMBER of ZIP to a temporary file and return its name."
  (make-directory edgar-dataset-cache-directory t)
  (let ((file
         (make-temp-file (expand-file-name
                          "member-"
                          edgar-dataset-cache-directory)
                         nil ".tsv")))
    (unless (eql
             0
             (call-process edgar-unzip-program
                           nil
                           `(:file ,file)
                           nil
                           "-p"
                           (expand-file-name zip)
                           member))
      (delete-file file)
      (error
       "EDGAR dataset: %s could not extract %s from %s"
       edgar-unzip-program
       member
       zip))
    file))

(defun edgar-dataset--split-line (beg end)
  "Return the decoded tab-separated fields between BEG and END."
  (vconcat
   (mapcar
    (lambda (field) (decode-coding-string field 'utf-8))
    (split-string (buffer-substring-no-properties beg end) "\t"))))

(defun edgar-dataset--set-header (beg end)
  "Record the header line between BEG and END."
  (let ((columns (edgar-dataset--split-line beg end))
        (index (make-hash-table :test #'equal)))
    (dotimes (i (length columns))
      (puthash (string-trim (aref columns i)) i index))
    (setq
     edgar-dataset-header columns
     edgar-dataset--header-index index)))

(defun edgar-dataset-column (name)
  "Return the index of column NAME in the member being visited, or nil."
  (gethash name edgar-dataset--header-index))

(defun edgar-dataset--visit-file (file fn)
  "Call FN with BEG and END for every data line of the TSV FILE.
Return the number of data lines."
  (let ((size (file-attribute-size (file-attributes file)))
        (offset 0)
        (count 0)
        (header nil))
    (with-temp-buffer
      (set-buffer-multibyte nil)
      (while (< offset size)
        (let ((next (min size (+ offset edgar-dataset-chunk-size))))
          (goto-char (point-max))
          (insert-file-contents-literally file nil offset next)
          (setq offset next))
        (when (and (= offset size)
                   (> (buffer-size) 0)
                   (/= (char-before (point-max)) ?\n))
          (goto-char (point-max))
          (insert "\n"))
        (goto-char (point-min))
        (let ((consumed nil))
          (while (search-forward "\n" nil t)
            (let* ((next (point))
                   (beg (pos-bol 0))
                   (end
                    (if (eq (char-before (1- next)) ?\r)
                        (- next 2)
                      (1- next))))
              (cond
               ((not header)
                (edgar-dataset--set-header beg end)
                (setq header t))
               ((> end beg)
                (goto-char beg)
                (funcall fn beg end)
                (setq count (1+ count))))
              (goto-char next)
              (setq consumed next)))
          (when consumed
            (delete-region (point-min) consumed)))))
    count))

(defun edgar-dataset-map-lines (zip member fn)
  "Call FN for every data row of the TSV MEMBER of ZIP.
The member is extracted with `edgar-unzip-program' and read in chunks of
`edgar-dataset-chunk-size' bytes.  FN receives BEG and END of the row in
the current unibyte buffer, with point at BEG; read fields with the
cursor helpers.  `edgar-dataset-header' and `edgar-dataset-column'
describe the columns while FN runs.  Return the number of rows."
  (let ((file (edgar-dataset--extract zip member))
        (edgar-dataset-header nil)
        (edgar-dataset--header-index nil))
    (unwind-protect
        (edgar-dataset--visit-file file fn)
      (delete-file file))))

(defun edgar-dataset-map-rows (zip member fn)
  "Call FN with a vector of decoded field strings per row of MEMBER of ZIP.
Use `edgar-dataset-column' inside FN to find a column by name.
Return the number of rows."
  (edgar-dataset-map-lines
   zip member
   (lambda (beg end)
     (funcall fn (edgar-dataset--split-line beg end)))))

(defun edgar-dataset-field (row name)
  "Return field NAME of ROW from `edgar-dataset-map-rows', or nil.
Empty fields are returned as nil."
  (let* ((index (edgar-dataset-column name))
         (value (and index (< index (length row)) (aref row index))))
    (and value (not (string-empty-p value)) value)))

;;;; Cursor helpers: read the field at point, then move past its tab

(defsubst edgar-dataset--next-field ()
  "Move point past the tab that ends the current field."
  (when (eq (char-after) ?\t)
    (forward-char 1)))

(defun edgar-dataset-skip-fields (n)
  "Move point past N fields of the current row."
  (dotimes (_ n)
    (skip-chars-forward "^\t\n")
    (edgar-dataset--next-field)))

(defun edgar-dataset-field-bounds ()
  "Return (BEG . END) of the field at point and move past it."
  (let ((beg (point)))
    (skip-chars-forward "^\t\n")
    (prog1 (cons beg (point))
      (edgar-dataset--next-field))))

(defun edgar-dataset-string (bounds)
  "Return the decoded, trimmed string within BOUNDS, or nil when empty."
  (let ((text
         (string-trim
          (decode-coding-string
           (buffer-substring-no-properties (car bounds) (cdr bounds))
           'utf-8))))
    (and (not (string-empty-p text)) text)))

(defun edgar-dataset-read-string ()
  "Return the field at point as a string (nil when empty), moving past it."
  (edgar-dataset-string (edgar-dataset-field-bounds)))

(defun edgar-dataset-read-integer ()
  "Return the integer part of the numeric field at point, or nil.
A fractional part is dropped.  Point moves past the field."
  (let ((n 0)
        (sign 1)
        (digits nil)
        (c (char-after)))
    (when (eq c ?-)
      (setq sign -1)
      (forward-char 1)
      (setq c (char-after)))
    (while (and c (<= ?0 c ?9))
      (setq
       n (+ (* n 10) (- c ?0))
       digits t)
      (forward-char 1)
      (setq c (char-after)))
    (skip-chars-forward "^\t\n")
    (edgar-dataset--next-field)
    (and digits (* sign n))))

(defun edgar-dataset-read-digits ()
  "Return the digits of the field at point as one integer, or nil.
Non-digits such as the dashes of an accession number are skipped.
Point moves past the field."
  (let ((n 0)
        (digits nil)
        (c (char-after)))
    (while (and c (/= c ?\t) (/= c ?\n))
      (when (<= ?0 c ?9)
        (setq
         n (+ (* n 10) (- c ?0))
         digits t))
      (forward-char 1)
      (setq c (char-after)))
    (edgar-dataset--next-field)
    (and digits n)))

(defun edgar-dataset-read-code (&optional limit)
  "Return an integer code for the alphanumeric field at point, or nil.
Letters are case-folded and other characters skipped, so equal codes mean
equal identifiers; nine-character CUSIPs stay fixnums.  With LIMIT, only
the first LIMIT alphanumerics count (eleven keep an ISIN a fixnum).
Point moves past the field."
  (let ((n 0)
        (seen nil)
        (left (or limit most-positive-fixnum))
        (c (char-after)))
    (while (and c (/= c ?\t) (/= c ?\n) (> left 0))
      (let ((digit
             (cond
              ((<= ?0 c ?9)
               (- c 47))
              ((<= ?A c ?Z)
               (- c 54))
              ((<= ?a c ?z)
               (- c 86)))))
        (when digit
          (setq
           n (+ (* n 37) digit)
           seen t
           left (1- left))))
      (forward-char 1)
      (setq c (char-after)))
    (skip-chars-forward "^\t\n")
    (edgar-dataset--next-field)
    (and seen n)))

(defun edgar-dataset-read-identifier (length &optional limit)
  "Return the code of an identifier field at point, or nil.
The field must be exactly LENGTH letters and digits and not all zeros,
so placeholders such as N/A or 000000000 read as nil.  LIMIT is passed
to `edgar-dataset-read-code'.  Point moves past the field."
  (let* ((beg (point))
         (end
          (progn
            (skip-chars-forward "0-9A-Za-z")
            (point)))
         (valid
          (and (= (- end beg) length)
               (memq (char-after) '(?\t ?\n ?\r nil))
               (progn
                 (goto-char beg)
                 (skip-chars-forward "0")
                 (< (point) end)))))
    (goto-char beg)
    (if valid
        (edgar-dataset-read-code limit)
      (edgar-dataset-skip-fields 1)
      nil)))

(defun edgar-dataset-code-string (code)
  "Return the upper-case text that `edgar-dataset-read-code' read as CODE.
Characters it skipped, such as punctuation, are not restored."
  (let (chars)
    (while (> code 0)
      (let ((digit (% code 37)))
        (push (if (<= digit 10)
                  (+ digit 47)
                (+ digit 54))
              chars)
        (setq code (/ code 37))))
    (concat chars)))

(defun edgar-dataset-read-interned (table)
  "Return the field at point as a string shared through TABLE, or nil.
TABLE maps field codes to strings, so a repeated value such as a
category allocates once.  Point moves past the field."
  (let* ((beg (point))
         (code (edgar-dataset-read-code)))
    (and code
         (or (gethash code table)
             (puthash
              code
              (save-excursion
                (goto-char beg)
                (edgar-dataset-read-string))
              table)))))

(defun edgar-dataset-read-char ()
  "Return the first character of the field at point, or nil when empty.
Point moves past the field."
  (let ((c (char-after)))
    (skip-chars-forward "^\t\n")
    (edgar-dataset--next-field)
    (and c (/= c ?\t) (/= c ?\n) (/= c ?\r) c)))

(provide 'edgar-dataset)
;;; edgar-dataset.el ends here
