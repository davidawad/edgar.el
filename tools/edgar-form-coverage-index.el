;;; edgar-form-coverage-index.el --- SEC full-index checks for form coverage -*- lexical-binding: t; -*-

;;; Commentary:

;; Full-index parsing and the network entry point of the form coverage
;; gate.  Loaded by `edgar-form-coverage'.

;;; Code:

(require 'cl-lib)
(require 'subr-x)
(require 'edgar-forms)
(require 'url)

(defvar edgar-coverage-snapshot-file)

(declare-function edgar-coverage--base-form "edgar-form-coverage" (form))
(declare-function edgar-coverage-read-snapshot "edgar-form-coverage"
                  (&optional file))
(declare-function edgar-coverage--unknown-form-problems
                  "edgar-form-coverage" (forms registry source))

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


(provide 'edgar-form-coverage-index)

;;; edgar-form-coverage-index.el ends here
