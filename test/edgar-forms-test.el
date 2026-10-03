;;; edgar-forms-test.el --- Tests for the form registry -*- lexical-binding: t; -*-

;;; Commentary:

;; Offline coverage checks for the Q2 2026 SEC form index snapshot.

;;; Code:

(require 'ert)
(require 'edgar-forms)

(defconst edgar-forms-test--snapshot
  (expand-file-name "form-survey-2026-q2.txt"
                    (file-name-directory
                     (or load-file-name buffer-file-name)))
  "Path to the recorded 2026 Q2 SEC form index counts.")

(defconst edgar-forms-test--family-counts
  '(("G1 Ownership" . 3)
    ("G2 Notice of sale / Reg D" . 2)
    ("G3 Beneficial ownership 13D/13G" . 5)
    ("G4 13F holdings" . 2)
    ("G5 Fund periodic reports" . 25)
    ("G6 Asset-backed" . 3)
    ("G7 Prospectuses & registration" . 58)
    ("G8 Proxy & M&A" . 31)
    ("G9 Periodic & event narrative" . 34)
    ("G10 Investment-company registration" . 40)
    ("G11 Reg CF & Reg A" . 14)
    ("G12 Broker-dealer, market structure, staff" . 26)
    ("G13 Tail" . 2))
  "Expected family counts documented in `docs/form-coverage.md'.")

(defun edgar-forms-test--snapshot-forms ()
  "Return base form names from the recorded index snapshot."
  (with-temp-buffer
    (insert-file-contents edgar-forms-test--snapshot)
    (let (forms)
      (while (re-search-forward
              "^[[:space:]]*[0-9]+[[:space:]]+\\(.+\\)$"
              nil t)
        (push (match-string 1) forms))
      (nreverse forms))))

(ert-deftest edgar-forms-snapshot-resolves-to-registry ()
  "Every raw form in the quarter snapshot resolves to its registry row."
  (dolist (form (edgar-forms-test--snapshot-forms))
    (should (edgar-form-info form)))
  (should (= (hash-table-count edgar-forms--registry) 245))
  (let ((volume 0))
    (maphash
     (lambda (_form info)
       (setq volume (+ volume (plist-get info :volume))))
     edgar-forms--registry)
    (should (= volume 353293))))

(ert-deftest edgar-forms-amendments-resolve-to-base ()
  "An amendment resolves to the same metadata as its base form."
  (should
   (equal (edgar-form-info "10-K/A") (edgar-form-info "10-K"))))

(ert-deftest edgar-forms-unknown-signals-with-form-name ()
  "Unknown forms fail with their name in the error."
  (let ((message
         (condition-case error-data
             (progn
               (edgar-form-info "NOT-A-REAL-FORM")
               "")
           (error
            (error-message-string error-data)))))
    (should (string-match-p "NOT-A-REAL-FORM" message))))

(ert-deftest edgar-forms-rows-have-valid-coverage-metadata ()
  "Every registry row has a valid backend, level, and Q2 volume."
  (maphash
   (lambda (_form info)
     (should (memq (plist-get info :backend) '(html xml text)))
     (should (memq (plist-get info :level) '(L0 L1 L2)))
     (should (numberp (plist-get info :volume))))
   edgar-forms--registry))

(ert-deftest edgar-forms-family-totals-match-coverage-doc ()
  "Family sizes match the checked summary in `docs/form-coverage.md'."
  (dolist (expected edgar-forms-test--family-counts)
    (should
     (= (length (edgar-forms-by-family (car expected)))
        (cdr expected)))))

(ert-deftest edgar-forms-g4-13f-variants-have-typed-coverage ()
  "Both base Form 13F variants expose recorded typed data."
  (dolist (form '("13F-HR" "13F-NT"))
    (should (eq (plist-get (edgar-form-info form) :level) 'L2))))

(ert-deftest edgar-forms-g8-proxy-and-tender-sections-have-golden-coverage ()
  "Proxy and tender sections with reviewed filing goldens are L2."
  (dolist (form '("DEF 14A" "SC TO-T" "SC 14D9"))
    (should (eq (plist-get (edgar-form-info form) :level) 'L2))))

(ert-deftest edgar-forms-g11-increment-levels-are-explicit ()
  "G11 records all but the unavailable Form 1 primary document."
  (let ((rows (edgar-forms-by-family "G11 Reg CF & Reg A"))
        (counts (list (cons 'L0 0) (cons 'L1 0) (cons 'L2 0))))
    (dolist (row rows)
      (let ((cell (assq (plist-get (cdr row) :level) counts)))
        (setcdr cell (1+ (cdr cell)))))
    (should (eq (plist-get (edgar-form-info "C") :level) 'L2))
    (should (eq (plist-get (edgar-form-info "C-AR") :level) 'L2))
    (should (eq (plist-get (edgar-form-info "C-U") :level) 'L1))
    (should (equal counts '((L0 . 1) (L1 . 11) (L2 . 2))))))

(provide 'edgar-forms-test)

;;; edgar-forms-test.el ends here
