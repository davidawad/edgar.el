;;; form-coverage-artifact-test.el --- Artifact tests for the form coverage gate -*- lexical-binding: t; -*-

;;; Commentary:

;; Artifact tests for the form coverage gate.
;; Shares helpers with `form-coverage-test-support'.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'subr-x)
(require 'form-coverage-test-support)

(ert-deftest edgar-form-coverage-report-has-form-level-and-volume ()
  "The matrix reports form, level, volume, and share columns."
  (with-temp-buffer
    (let ((standard-output (current-buffer)))
      (edgar-coverage-print-report
       (edgar-form-coverage-test--registry 'L1)))
    (let ((report (buffer-string)))
      (should
       (string-match-p
        "FORM[[:space:]]+LEVEL[[:space:]]+VOLUME" report))
      (should
       (string-match-p "TEST-FORM[[:space:]]+L1[[:space:]]+1" report))
      (should (string-match-p "100\\.00%" report)))))

(ert-deftest edgar-form-coverage-network-index-mutation-names-form ()
  "A form added to a full-index response is reported by name."
  (let*
      ((text
        (concat
         "Form Type        Company Name\n"
         "------------------------------------------------------------\n"
         (format "%-17s%s\n" "4" "Known filer")
         (format "%-17s%s\n" "NETWORK-NEW" "New filer")))
       (forms (edgar-coverage-parse-full-index text))
       (messages
        (edgar-form-coverage-test--messages
         (edgar-coverage--unknown-form-problems
          forms edgar-forms--registry "test index"))))
    (should (string-match-p "NETWORK-NEW" messages))))

(ert-deftest edgar-form-coverage-latest-completed-quarter-rolls-year
    ()
  "The latest completed quarter rolls January into prior-year Q4."
  (should
   (equal
    (edgar-coverage-latest-completed-quarter
     (encode-time 0 0 12 15 1 2026 t))
    '(2025 . 4)))
  (should
   (equal
    (edgar-coverage-latest-completed-quarter
     (encode-time 0 0 12 2 10 2026 t))
    '(2026 . 3))))

(provide 'form-coverage-artifact-test)

;;; form-coverage-artifact-test.el ends here
