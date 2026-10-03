;;; record-fixtures.el --- record real SEC filings as offline test fixtures -*- lexical-binding: t; -*-

;; Run manually with the package's Emacs environment:
;;   eask emacs --batch -L tools -l tools/record-fixtures.el \
;;     -f edgar-record-fixtures-run
;; Records one recent and one 3+-year-old representative filing for every
;; registered form.  HTML files are gzip-compressed; XML and text files are
;; stored raw.  All artifacts are bounded by per-document and total budgets.

;;; Commentary:

;; The recorder samples SEC quarterly indexes, chooses capped primary
;; documents deterministically, and saves offline fixture pairs.

;;; Code:

(require 'edgar)
(require 'json)
(require 'seq)

(defconst edgar-record--fixture-directory
  (expand-file-name "../test/fixtures/"
                    (file-name-directory
                     (or load-file-name
                         buffer-file-name
                         default-directory)))
  "Directory that stores recorded fixtures.")

(defgroup edgar-record nil
  "Record deterministic fixtures from the SEC form index."
  :group 'edgar)

(defcustom edgar-record-seed "edgar-form-coverage-v1"
  "Seed used to choose stable candidates within each form and quarter."
  :type 'string)

(defcustom edgar-record-max-bytes 1800000
  "Largest uncompressed primary document to record."
  :type 'integer)

(defcustom edgar-record-max-gzip-bytes 524288
  "Largest compressed primary document to record."
  :type 'integer)

(defcustom edgar-record-total-budget-bytes (* 64 1024 1024)
  "Maximum combined size of all files under test/fixtures."
  :type 'integer)

(defcustom edgar-record-target-bytes 262144
  "Preferred uncompressed size when choosing among candidate filings."
  :type 'integer)

(defcustom edgar-record-candidate-limit 8
  "Maximum deterministically ranked filing directories inspected per form."
  :type 'integer)

(defcustom edgar-record-request-delay 0.25
  "Seconds to wait between SEC requests."
  :type 'number)

(defun edgar-record--dir ()
  "Return the path used for recorded fixtures."
  edgar-record--fixture-directory)

(defun edgar-record-quarter-pairs (&optional time)
  "Return (RECENT OLDER) quarter pairs for TIME, in UTC.
Each quarter is a cons of year and quarter number.  RECENT is the last
completed quarter; OLDER is the same quarter three years earlier."
  (let* ((date (decode-time (or time (current-time)) t))
         (year (decoded-time-year date))
         (quarter (1+ (/ (1- (decoded-time-month date)) 3))))
    (if (= quarter 1)
        (setq
         year (1- year)
         quarter 4)
      (setq quarter (1- quarter)))
    (list (cons year quarter) (cons (- year 3) quarter))))

(defun edgar-record--form-slug (form)
  "Return a stable filesystem slug for FORM."
  (downcase (replace-regexp-in-string "[^A-Za-z0-9]+" "-" form)))

(defun edgar-record--fixture-slug (form quarter)
  "Return FORM's fixture slug for QUARTER."
  (format "index-%s-%s"
          (edgar-record--form-slug form)
          (downcase (edgar-record--quarter-label quarter))))

(defun edgar-record--fixture-primary-file (slug form)
  "Return the path for SLUG's primary fixture based on FORM's backend."
  (concat
   (expand-file-name slug (edgar-record--dir))
   (pcase (plist-get (edgar-form-info form) :backend)
     ('html ".htm.gz")
     ('xml ".xml")
     ('text ".txt"))))

(defun edgar-record--backend-file-p (form name)
  "Return non-nil when NAME has FORM's registered backend extension."
  (let ((extension (downcase (or (file-name-extension name) ""))))
    (pcase (plist-get (edgar-form-info form) :backend)
      ('html (member extension '("htm" "html")))
      ('xml (equal extension "xml"))
      ('text (equal extension "txt")))))

(defun edgar-record--candidate-key (form vintage filing)
  "Hash key used to deterministically rank FILING for FORM and VINTAGE."
  (secure-hash
   'sha256
   (format "%s\0%s\0%s\0%s"
           edgar-record-seed
           form
           vintage
           (plist-get filing :accn))))

(defun edgar-record--rank (form vintage filings)
  "Return FILINGS in deterministic seeded order for FORM and VINTAGE."
  (sort (copy-sequence filings)
        (lambda (left right)
          (string<
           (edgar-record--candidate-key form vintage left)
           (edgar-record--candidate-key form vintage right)))))

(defun edgar-record--quarter-label (quarter)
  "Format QUARTER as YYYY-QN."
  (format "%d-Q%d" (car quarter) (cdr quarter)))

(defun edgar-record--index-url (filing)
  "Return the SEC directory index URL for FILING."
  (format "https://www.sec.gov/Archives/edgar/data/%d/%s/index.json"
          (plist-get filing :cik)
          (replace-regexp-in-string "-" "" (plist-get filing :accn))))

(defun edgar-record--directory-items (filing)
  "Fetch directory JSON items for FILING."
  (let* ((json (edgar--fetch (edgar-record--index-url filing)))
         (data
          (json-parse-string json
                             :object-type 'alist
                             :array-type 'list)))
    (sleep-for edgar-record-request-delay)
    (alist-get 'item (alist-get 'directory data))))

(defun edgar-record--submission-primary-name (filing)
  "Return the primary document filename from FILING's submission."
  (let* ((case-fold-search t)
         (form (edgar--base-form (or (plist-get filing :form) "")))
         (submission (edgar--fetch (plist-get filing :url)))
         (cursor 0)
         first-name
         primary-name)
    (while (and (not primary-name)
                (setq cursor
                      (string-match "<DOCUMENT>[ \t\r\n]*" submission
                                    cursor)))
      (let* ((document-start (match-end 0))
             (document-end
              (string-match "</DOCUMENT>" submission document-start)))
        (if (not document-end)
            (setq cursor nil)
          (let* ((text-start
                  (string-match "<TEXT>" submission document-start))
                 (header-end
                  (if (and text-start (< text-start document-end))
                      text-start
                    document-end))
                 (header
                  (substring submission document-start header-end))
                 (document-type
                  (when (string-match
                         "<TYPE>[ \t]*\\([^\r\n]+\\)" header)
                    (string-trim (match-string 1 header))))
                 (filename
                  (when (string-match
                         "<FILENAME>[ \t]*\\([^\r\n]+\\)" header)
                    (string-trim (match-string 1 header)))))
            (when filename
              (unless first-name
                (setq first-name filename))
              (when (and document-type
                         (equal
                          (edgar--base-form document-type) form))
                (setq primary-name filename)))
            (setq cursor (+ document-end (length "</DOCUMENT>")))))))
    (or primary-name first-name)))

(defun edgar-record--gzip-file (raw-file gzip-file)
  "Write a deterministic gzip of RAW-FILE to GZIP-FILE."
  (with-temp-buffer
    (set-buffer-multibyte nil)
    (let ((coding-system-for-write 'no-conversion))
      (unless (zerop
               (call-process "gzip" raw-file t nil "-n" "-9" "-c"))
        (error "Gzip failed for %s" raw-file))
      (write-region (point-min) (point-max) gzip-file nil 'silent))))

(defun edgar-record--primary-item (filing items)
  "Return FILING's primary document item from directory ITEMS.
Prefer an item whose SEC `type' matches the form; when that field only
contains an icon type, resolve the filename from the complete submission."
  (let* ((form (plist-get filing :form))
         (item
          (or (car
               (seq-filter
                (lambda (candidate)
                  (and (equal
                        (alist-get 'type candidate) form)
                       (edgar-record--backend-file-p
                        form (alist-get 'name candidate))))
                items))
              (let ((filename
                     (edgar-record--submission-primary-name filing)))
                (seq-find
                 (lambda (candidate)
                   (equal (alist-get 'name candidate) filename))
                 items))))
         (name (and item (alist-get 'name item))))
    (when (and name (edgar-record--backend-file-p form name))
      item)))

(defun edgar-record--item-size (item)
  "Return ITEM's SEC-reported size as an integer."
  (let ((size (alist-get 'size item)))
    (cond
     ((integerp size)
      size)
     ((and (stringp size) (string-match-p "\\`[0-9]+\\'" size))
      (string-to-number size))
     (t
      0))))

(defun edgar-record--suitable-item-p (item)
  "Return non-nil when ITEM has a valid size under the raw-file cap."
  (let ((size (edgar-record--item-size item)))
    (and (> size 0) (<= size edgar-record-max-bytes))))

(defun edgar-record--candidate-docs (form vintage filings)
  "Return suitable (FILING ITEM SIZE) candidates for FORM and VINTAGE.
FILINGS are the exact-form rows from the quarterly index."
  (let ((ranked (edgar-record--rank form vintage filings))
        candidates)
    (dolist (filing (seq-take ranked edgar-record-candidate-limit))
      (condition-case err
          (let* ((items (edgar-record--directory-items filing))
                 (item (edgar-record--primary-item filing items))
                 (size (and item (edgar-record--item-size item))))
            (when (and item (edgar-record--suitable-item-p item))
              (push (list filing item size) candidates)))
        (error
         (message "  %s %s directory: %s"
                  form
                  (plist-get filing :accn)
                  (error-message-string err)))))
    (edgar-record--prefer-candidates form vintage candidates)))

(defun edgar-record--prefer-candidates (form vintage candidates)
  "Sort CANDIDATES by size closeness and stable seeded tie-break.
FORM and VINTAGE identify the selection context."
  (sort candidates
        (lambda (left right)
          (let ((left-delta
                 (abs (- (nth 2 left) edgar-record-target-bytes)))
                (right-delta
                 (abs (- (nth 2 right) edgar-record-target-bytes))))
            (if (= left-delta right-delta)
                (string<
                 (edgar-record--candidate-key form vintage (car left))
                 (edgar-record--candidate-key
                  form vintage (car right)))
              (< left-delta right-delta))))))

(defun edgar-record--directory-size ()
  "Return combined byte size of regular files in the fixture directory."
  (if (not (file-directory-p (edgar-record--dir)))
      0
    (let ((files
           (directory-files-recursively (edgar-record--dir) "[^/]+")))
      (apply #'+
             (mapcar
              (lambda (file)
                (file-attribute-size (file-attributes file)))
              files)))))

(defun edgar-record--write-pair (slug filing item quarter vintage)
  "Fetch and save SLUG's primary document and metadata.
FILING and ITEM identify the SEC document; QUARTER and VINTAGE describe its
sampling period.  Return t on success, otherwise nil."
  (let* ((directory (edgar-record--dir))
         (form (plist-get filing :form))
         (backend (plist-get (edgar-form-info form) :backend))
         (base (expand-file-name slug directory))
         (primary-file (edgar-record--fixture-primary-file slug form))
         (metadata-file (concat base ".eld"))
         (doc-name (alist-get 'name item))
         (url
          (concat
           (string-remove-suffix
            "index.json" (edgar-record--index-url filing))
           doc-name))
         (content (edgar--fetch url))
         (raw-temp (make-temp-file "edgar-fixture-"))
         (gzip-temp (make-temp-file "edgar-fixture-gzip-"))
         (metadata-temp (make-temp-file "edgar-fixture-meta-"))
         (metadata (copy-sequence filing))
         ok)
    (setq metadata (plist-put metadata :doc doc-name))
    (setq metadata (plist-put metadata :url url))
    (setq metadata
          (plist-put metadata :size (edgar-record--item-size item)))
    (setq metadata (plist-put metadata :sample-vintage vintage))
    (setq metadata
          (plist-put
           metadata
           :sample-quarter (edgar-record--quarter-label quarter)))
    (setq metadata
          (plist-put metadata :sample-seed edgar-record-seed))
    (unwind-protect
        (progn
          (sleep-for edgar-record-request-delay)
          (if (> (string-bytes content) edgar-record-max-bytes)
              (message "  %s %s document exceeds raw size cap"
                       form
                       (plist-get filing :accn))
            (progn
              (with-temp-file raw-temp
                (set-buffer-file-coding-system 'utf-8-unix)
                (insert content))
              (with-temp-file metadata-temp
                (let ((print-length nil)
                      (print-level nil))
                  (prin1 metadata (current-buffer))
                  (insert "\n")))
              (when (eq backend 'html)
                (edgar-record--gzip-file raw-temp gzip-temp))
              (let* ((stored-temp
                      (if (eq backend 'html)
                          gzip-temp
                        raw-temp))
                     (stored-size
                      (file-attribute-size
                       (file-attributes stored-temp)))
                     (metadata-size
                      (file-attribute-size
                       (file-attributes metadata-temp))))
                (cond
                 ((and (eq backend 'html)
                       (> stored-size edgar-record-max-gzip-bytes))
                  (message
                   "  %s %s compressed document exceeds fixture cap"
                   form (plist-get filing :accn)))
                 ((> (+ (edgar-record--directory-size) stored-size
                        metadata-size)
                     edgar-record-total-budget-bytes)
                  (message "  Fixture budget reached before %s" slug))
                 (t
                  (make-directory directory t)
                  (if (eq backend 'html)
                      (rename-file gzip-temp primary-file t)
                    (copy-file raw-temp primary-file t))
                  (rename-file metadata-temp metadata-file t)
                  (setq ok t)
                  (message "  recorded %s (%d raw, %d stored bytes)"
                           slug
                           (string-bytes content)
                           stored-size))))))
          ok)
      (dolist (file (list raw-temp gzip-temp metadata-temp))
        (when (file-exists-p file)
          (delete-file file))))))

(defun edgar-record--sample-quarter
    (form vintage quarter index-filings)
  "Find and record FORM's best filing for VINTAGE and QUARTER.
Return :recorded, :existing, :no-filing, or :no-suitable.
INDEX-FILINGS is the cached result from `edgar-index-filings'."
  (let* ((slug (edgar-record--fixture-slug form quarter))
         (matches
          (seq-filter
           (lambda (filing)
             (equal (plist-get filing :form) form))
           index-filings)))
    (cond
     ((null matches)
      :no-filing)
     ((and (file-exists-p
            (expand-file-name (concat slug ".eld")
                              (edgar-record--dir)))
           (file-exists-p
            (edgar-record--fixture-primary-file slug form))
           :existing))
     ((>= (edgar-record--directory-size)
          edgar-record-total-budget-bytes)
      (message "  fixture budget exhausted before %s" slug)
      :no-suitable)
     (t
      (let ((candidates
             (edgar-record--candidate-docs form vintage matches)))
        (catch 'recorded
          (dolist (candidate candidates)
            (let ((filing (nth 0 candidate))
                  (item (nth 1 candidate)))
              (condition-case err
                  (when (edgar-record--write-pair
                         slug filing item quarter vintage)
                    (throw 'recorded :recorded))
                (error
                 (message "  %s %s download: %s"
                          form
                          (plist-get filing :accn)
                          (error-message-string err))))))
          :no-suitable))))))

(defun edgar-record-fixtures-run (&optional quarters)
  "Record registry fixtures from QUARTERS, or recent and older defaults.
Prints forms absent from both sampled quarterly indexes."
  (interactive)
  (let* ((pair (or quarters (edgar-record-quarter-pairs)))
         (recent (car pair))
         (older (cadr pair))
         (indexes
          (list
           (cons
            "recent" (edgar-index-filings (car recent) (cdr recent)))
           (cons
            "older" (edgar-index-filings (car older) (cdr older)))))
         (forms
          (sort (hash-table-keys edgar-forms--registry) #'string<))
         no-filing
         no-suitable)
    (make-directory (edgar-record--dir) t)
    (dolist (form forms)
      (message "%s:" form)
      (let ((found nil))
        (dolist (period indexes)
          (let* ((vintage (car period))
                 (quarter
                  (if (equal vintage "recent")
                      recent
                    older))
                 (all (cdr period))
                 (status
                  (edgar-record--sample-quarter
                   form vintage quarter all)))
            (unless (eq status :no-filing)
              (setq found t))
            (when (eq status :no-suitable)
              (push (cons form vintage) no-suitable))))
        (unless found
          (push form no-filing))))
    (message "No filings in sampled quarters (%s): %s"
             (mapconcat (lambda (quarter)
                          (edgar-record--quarter-label quarter))
                        (list recent older)
                        ", ")
             (if no-filing
                 (string-join (sort no-filing #'string<) ", ")
               "none"))
    (when no-suitable
      (message "Filings existed but no fixture fit caps: %s"
               (mapconcat (lambda (entry)
                            (format "%s/%s" (car entry) (cdr entry)))
                          (nreverse no-suitable)
                          ", ")))
    (message "Fixture directory: %s; total bytes: %d / %d"
             (edgar-record--dir)
             (edgar-record--directory-size)
             edgar-record-total-budget-bytes)
    (list
     :no-filing (nreverse no-filing)
     :no-suitable (nreverse no-suitable))))

(provide 'record-fixtures)
;;; record-fixtures.el ends here
