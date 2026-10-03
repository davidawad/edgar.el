;;; edgar-form-coverage.el --- Validate EDGAR form coverage -*- lexical-binding: t; -*-

;;; Commentary:

;; Offline validation and reporting for the form registry.  The committed
;; 2026 Q2 form-count snapshot is the baseline used by the normal test gate.
;; The network entry point separately checks the latest completed SEC
;; full-index quarter for newly observed, unregistered forms.

;;; Code:

(require 'cl-lib)
(require 'seq)
(require 'subr-x)
(require 'edgar-forms)

(defconst edgar-coverage--root
  (expand-file-name ".."
                    (file-name-directory
                     (or load-file-name buffer-file-name)))
  "Repository root used to locate committed coverage data.")

(defvar edgar-coverage-snapshot-file
  (expand-file-name "test/form-survey-2026-q2.txt"
                    edgar-coverage--root)
  "Committed SEC form-count snapshot used by the offline gate.")

(defvar edgar-coverage-fixture-directory
  (expand-file-name "test/fixtures" edgar-coverage--root)
  "Directory containing recorded filing metadata and primary documents.")

(defvar edgar-coverage-expect-directory
  (expand-file-name "test/expect" edgar-coverage--root)
  "Directory containing structure expectations for recorded filings.")

(defvar edgar-coverage-golden-directory
  (expand-file-name "test/golden" edgar-coverage--root)
  "Directory containing golden values for L2 filings.")

(defvar edgar-coverage-field-golden-directory
  (expand-file-name "test/golden-fields" edgar-coverage--root)
  "Directory containing typed field goldens for XML L2 filings.")

(defun edgar-coverage--base-form (form)
  "Return the base form name for FORM."
  (replace-regexp-in-string "/A\\'" "" form))

(defun edgar-coverage-read-snapshot (&optional file)
  "Read form counts from snapshot FILE into a base-form hash table.
Each value is a plist with `:volume' and `:raw-forms' entries."
  (let ((data (make-hash-table :test #'equal))
        (path (or file edgar-coverage-snapshot-file))
        saw-row)
    (with-temp-buffer
      (insert-file-contents path)
      (goto-char (point-min))
      (while (not (eobp))
        (let ((line
               (string-trim
                (buffer-substring-no-properties
                 (line-beginning-position) (line-end-position)))))
          (when (string-match
                 "\\`\\([0-9]+\\)[[:space:]]+\\(.+\\)\\'" line)
            (let* ((volume-text (match-string 1 line))
                   (form-text (match-string 2 line))
                   (volume (string-to-number volume-text))
                   (raw-form (string-trim form-text))
                   (base-form (edgar-coverage--base-form raw-form))
                   (old (gethash base-form data)))
              (setq saw-row t)
              (puthash
               base-form
               (list
                :volume (+ volume (or (plist-get old :volume) 0))
                :raw-forms
                (cons raw-form (plist-get old :raw-forms)))
               data))))
        (forward-line 1)))
    (unless saw-row
      (error "No form-count rows found in %s" path))
    data))

(defun edgar-coverage--read-object (file)
  "Read and return the first Lisp object in FILE."
  (with-temp-buffer
    (insert-file-contents file)
    (read (current-buffer))))

(defun edgar-coverage--registry-rows (registry)
  "Return sorted (FORM . INFO) rows from REGISTRY."
  (let (rows)
    (maphash
     (lambda (form info) (push (cons form info) rows)) registry)
    (sort rows
          (lambda (left right) (string< (car left) (car right))))))

(defun edgar-coverage--unknown-form-problems (forms registry source)
  "Return problems for FORMS absent from REGISTRY, naming SOURCE."
  (let (problems)
    (maphash
     (lambda (base entry)
       (unless (gethash base registry)
         (push (format "%s: unknown EDGAR form %s (raw: %s)"
                       source base
                       (mapconcat
                        #'identity
                        (delete-dups
                         (sort (copy-sequence
                                (plist-get entry :raw-forms))
                               #'string<))
                        ", "))
               problems)))
     forms)
    (nreverse problems)))

(defun edgar-coverage--fixture-records (registry fixture-directory)
  "Return (RECORDS . PROBLEMS) from FIXTURE-DIRECTORY for REGISTRY.
Each record is a (BASE-FORM . SLUG) pair."
  (let (records
        problems)
    (if (not (file-directory-p fixture-directory))
        (push (format "Fixture directory does not exist: %s"
                      fixture-directory)
              problems)
      (dolist (file (directory-files fixture-directory t "\\.eld\\'"))
        (condition-case err
            (let* ((filing (edgar-coverage--read-object file))
                   (form (plist-get filing :form))
                   (base
                    (and (stringp form)
                         (edgar-coverage--base-form form)))
                   (slug (file-name-base file)))
              (cond
               ((not base)
                (push (format "%s: fixture has no form name" slug)
                      problems))
               ((gethash base registry)
                (push (cons base slug) records))))
          (error
           (push (format "%s: unreadable fixture metadata: %s"
                         (file-name-nondirectory file)
                         (error-message-string err))
                 problems)))))
    (cons records (nreverse problems))))

(defun edgar-coverage--primary-suffixes (backend)
  "Return accepted primary-document suffixes for BACKEND."
  (pcase backend
    ('html '(".htm.gz" ".htm"))
    ('xml '(".xml" ".xml.gz"))
    ('text '(".txt" ".txt.gz"))
    ('pdf '(".pdf"))))

(defun edgar-coverage--primary-artifact-p
    (slug backend fixture-directory)
  "Return non-nil when SLUG has a BACKEND primary in FIXTURE-DIRECTORY."
  (seq-some
   (lambda (suffix)
     (file-exists-p
      (expand-file-name (concat slug suffix) fixture-directory)))
   (edgar-coverage--primary-suffixes backend)))

(defun edgar-coverage--any-primary-artifact-p (slug fixture-directory)
  "Return non-nil when SLUG has an XML, HTML, text, or PDF primary."
  (seq-some
   (lambda (backend)
     (edgar-coverage--primary-artifact-p
      slug backend fixture-directory))
   '(xml html text pdf)))

(defun edgar-coverage--xml-field-golden-p
    (slug fixture-directory field-golden-directory)
  "Return non-nil when XML primary SLUG has a field golden."
  (and (edgar-coverage--primary-artifact-p
        slug 'xml fixture-directory)
       (file-exists-p
        (expand-file-name (concat slug ".eld") field-golden-directory))))

(defun edgar-coverage--artifact-problems
    (registry
     records fixture-directory expect-directory golden-directory
     field-golden-directory)
  "Return missing-artifact problems for REGISTRY and fixture RECORDS.
FIXTURE-DIRECTORY, EXPECT-DIRECTORY, and GOLDEN-DIRECTORY contain the
three artifact classes checked for L1 and L2 forms."
  (let (problems)
    (dolist (row (edgar-coverage--registry-rows registry))
      (let* ((form (car row))
             (info (cdr row))
             (backend (plist-get info :backend))
             (level (plist-get info :level))
             (xml-l2-p (and (eq backend 'xml) (eq level 'L2)))
             (slugs
              (mapcar
               #'cdr
               (seq-filter
                (lambda (record)
                  (equal form (car record)))
                records)))
             (has-xml-field-golden
              (and xml-l2-p
                   (seq-some
                    (lambda (slug)
                      (edgar-coverage--xml-field-golden-p
                       slug fixture-directory field-golden-directory))
                    slugs))))
        (unless (memq level '(L0 L1 L2))
          (push (format "%s: invalid coverage level %S" form level)
                problems))
        (when (memq level '(L1 L2))
          (unless slugs
            (push (format "%s: %s form has no recorded fixture"
                          form
                          level)
                  problems))
          (dolist (slug slugs)
            (unless (if xml-l2-p
                        (edgar-coverage--any-primary-artifact-p
                         slug fixture-directory)
                      (edgar-coverage--primary-artifact-p
                       slug backend fixture-directory))
              (push (if xml-l2-p
                        (format
                         "%s: fixture %s lacks an accepted primary document"
                         form slug)
                      (format
                       "%s: fixture %s lacks its %s primary document"
                       form slug (upcase (format "%s" backend))))
                    problems))
            (unless (file-exists-p
                     (expand-file-name (concat slug ".eld")
                                       expect-directory))
              (push (format "%s: fixture %s lacks an expect snapshot"
                            form
                            slug)
                    problems))
            (when (and (eq level 'L2) (not xml-l2-p)
                       (not
                        (file-exists-p
                         (expand-file-name (concat slug ".eld")
                                           golden-directory))))
              (push (format "%s: L2 fixture %s lacks golden values"
                            form slug)
                    problems)))
          (when (and xml-l2-p (not has-xml-field-golden))
            (push (format
                   "%s: L2 XML form needs an XML primary with field golden values"
                   form)
                  problems)))))
    (nreverse problems)))

(cl-defun
 edgar-coverage-problems
 (&key
  (registry edgar-forms--registry)
  (snapshot-file edgar-coverage-snapshot-file)
  (fixture-directory edgar-coverage-fixture-directory)
 (expect-directory edgar-coverage-expect-directory)
  (golden-directory edgar-coverage-golden-directory)
  (field-golden-directory edgar-coverage-field-golden-directory))
 "Return all offline coverage problems for the supplied data paths.
REGISTRY is checked against SNAPSHOT-FILE.  L1 forms require a fixture
and expect snapshot; L2 forms additionally require golden values."
 (let* ((snapshot (edgar-coverage-read-snapshot snapshot-file))
        (fixture-result
         (edgar-coverage--fixture-records registry fixture-directory))
        (records (car fixture-result))
        (problems
         (append
          (edgar-coverage--unknown-form-problems
           snapshot registry "Q2 2026 snapshot")
          (cdr fixture-result))))
   (maphash
    (lambda (form entry)
      (let ((info (gethash form registry)))
        (when (and info
                   (/=
                    (plist-get entry :volume)
                    (plist-get info :volume)))
          (push (format
                 "%s: registry volume %d differs from snapshot %d"
                 form
                 (plist-get info :volume)
                 (plist-get entry :volume))
                problems))))
    snapshot)
   (append
    (nreverse problems)
    (edgar-coverage--artifact-problems
     registry
     records
     fixture-directory
     expect-directory
     golden-directory
     field-golden-directory))))

(defun edgar-coverage--total-volume (registry)
  "Return the total filing volume recorded in REGISTRY."
  (let ((total 0))
    (maphash
     (lambda (_form info)
       (setq total (+ total (plist-get info :volume))))
     registry)
    total))

(defun edgar-coverage-print-report (&optional registry)
  "Print the form-by-level-and-volume matrix for REGISTRY."
  (let* ((table (or registry edgar-forms--registry))
         (total (edgar-coverage--total-volume table))
         (rows
          (sort (edgar-coverage--registry-rows table)
                (lambda (left right)
                  (let ((left-volume (plist-get (cdr left) :volume))
                        (right-volume
                         (plist-get (cdr right) :volume)))
                    (if (= left-volume right-volume)
                        (string< (car left) (car right))
                      (> left-volume right-volume))))))
         (form-width
          (max 4
               (apply #'max
                      (mapcar
                       (lambda (row) (length (car row))) rows)))))
    (princ
     (format "EDGAR form coverage: %d forms, %d Q2 2026 filings\n"
             (hash-table-count table) total))
    (princ
     (format (format "%%-%ds  %%-5s  %%8s  %%7s  %%s\n" form-width)
             "FORM" "LEVEL" "VOLUME" "SHARE" "FAMILY"))
    (dolist (row rows)
      (let* ((form (car row))
             (info (cdr row))
             (volume (plist-get info :volume)))
        (princ
         (format (format "%%-%ds  %%-5s  %%8d  %%6.2f%%%%  %%s\n"
                         form-width)
                 form (symbol-name (plist-get info :level)) volume
                 (if (zerop total)
                     0.0
                   (* 100.0 (/ (float volume) total)))
                 (plist-get info :family)))))
    (princ "\nLEVEL  FORMS    VOLUME    SHARE\n")
    (dolist (level '(L0 L1 L2))
      (let ((forms 0)
            (volume 0))
        (maphash
         (lambda (_form info)
           (when (eq level (plist-get info :level))
             (setq
              forms (1+ forms)
              volume (+ volume (plist-get info :volume)))))
         table)
        (princ
         (format "%-5s  %5d  %8d  %6.2f%%\n"
                 level forms volume
                 (if (zerop total)
                     0.0
                   (* 100.0 (/ (float volume) total)))))))))

(defun edgar-coverage-run ()
  "Run the offline gate and print its coverage matrix."
  (let ((problems (edgar-coverage-problems)))
    (when problems
      (error
       "EDGAR form coverage failed:\n%s"
       (mapconcat (lambda (problem) (concat "- " problem)) problems
                  "\n")))
    (edgar-coverage-print-report)
    (princ "\nOffline form coverage gate passed.\n")))

(defun edgar-coverage-latest-completed-quarter (&optional time)
  "Return (YEAR . QUARTER) for the latest quarter completed by TIME."
  (let* ((decoded (decode-time (or time (current-time)) t))
         (year (decoded-time-year decoded))
         (current-quarter
          (1+ (/ (1- (decoded-time-month decoded)) 3))))
    (if (= current-quarter 1)
        (cons (1- year) 4)
      (cons year (1- current-quarter)))))

(defun edgar-coverage--fetch-url (url)
  "Return the response body fetched from URL."
  (require 'url)
  (require 'url-http)
  (let* ((user-agent
          (or
           (getenv "EDGAR_UA")
           "edgar.el form coverage (set EDGAR_UA to name + email)"))
         (url-request-extra-headers `(("User-Agent" . ,user-agent)))
         (buffer (url-retrieve-synchronously url t t 60)))
    (unless buffer
      (error "SEC full-index request failed: %s" url))
    (with-current-buffer buffer
      (unwind-protect
          (progn
            (goto-char
             (or (and (boundp 'url-http-end-of-headers)
                      url-http-end-of-headers)
                 (point-min)))
            (buffer-substring-no-properties (point) (point-max)))
        (kill-buffer buffer)))))

(defun edgar-coverage-parse-full-index (text)
  "Parse SEC full-index form.idx TEXT into base-form coverage data."
  (let ((data (make-hash-table :test #'equal))
        found-divider)
    (with-temp-buffer
      (insert text)
      (goto-char (point-min))
      (when (re-search-forward "^-+\\s-*$" nil t)
        (setq found-divider t)
        (forward-line 1)
        (while (not (eobp))
          (let* ((start (line-beginning-position))
                 (end (line-end-position))
                 (form
                  (string-trim
                   (buffer-substring-no-properties
                    start (min end (+ start 17))))))
            (unless (string-empty-p form)
              (let* ((base (edgar-coverage--base-form form))
                     (old (gethash base data)))
                (puthash
                 base
                 (list
                  :volume (1+ (or (plist-get old :volume) 0))
                  :raw-forms (cons form (plist-get old :raw-forms)))
                 data))))
          (forward-line 1))))
    (unless found-divider
      (error "SEC full index has no header divider"))
    data))

(cl-defun
 edgar-coverage-network-run
 (&key
  (registry edgar-forms--registry)
  (snapshot-file edgar-coverage-snapshot-file)
  (fetcher #'edgar-coverage--fetch-url)
  year
  quarter)
 "Check the latest completed SEC full index against REGISTRY.
SNAPSHOT-FILE supplies the committed Q2 baseline used to report newly
observed forms.  FETCHER retrieves the index.  YEAR and QUARTER override
the default latest-completed-quarter selection."
 (let*
     ((latest (edgar-coverage-latest-completed-quarter))
      (target-year
       (or year
           (and (getenv "EDGAR_COVERAGE_YEAR")
                (string-to-number (getenv "EDGAR_COVERAGE_YEAR")))
           (car latest)))
      (target-quarter
       (or quarter
           (and (getenv "EDGAR_COVERAGE_QUARTER")
                (string-to-number
                 (replace-regexp-in-string
                  "\\`QTR" "" (getenv "EDGAR_COVERAGE_QUARTER"))))
           (cdr latest)))
      (url
       (format
        "https://www.sec.gov/Archives/edgar/full-index/%d/QTR%d/form.idx"
        target-year target-quarter))
      (forms (edgar-coverage-parse-full-index (funcall fetcher url)))
      (baseline (edgar-coverage-read-snapshot snapshot-file))
      (problems
       (edgar-coverage--unknown-form-problems
        forms
        registry
        (format "%d Q%d SEC full index" target-year target-quarter)))
      new-forms)
   (when problems
     (error
      "EDGAR network form coverage failed:\n%s"
      (mapconcat (lambda (problem) (concat "- " problem)) problems
                 "\n")))
   (maphash
    (lambda (form _entry)
      (unless (gethash form baseline)
        (push form new-forms)))
    forms)
   (princ
    (format "Checked %s: %d registered base forms observed.\n"
            url
            (hash-table-count forms)))
   (if new-forms
       (princ
        (format "Registered forms new since Q2 2026: %s\n"
                (mapconcat #'identity (sort new-forms #'string<)
                           ", ")))
     (princ
      "No base forms new since the committed Q2 2026 snapshot.\n"))
   (princ "Network form coverage gate passed.\n")))

(provide 'edgar-form-coverage)

;;; edgar-form-coverage.el ends here
