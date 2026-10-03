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
    ("G9 Periodic & event narrative" . 30)
    ("G10 Investment-company registration" . 40)
    ("G11 Reg CF & Reg A" . 18)
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
     (should (memq (plist-get info :backend) '(html xml text pdf)))
     (should (memq (plist-get info :level) '(L0 L1 L2)))
     (should (numberp (plist-get info :volume))))
   edgar-forms--registry))

(ert-deftest edgar-forms-family-totals-match-coverage-doc ()
  "Family sizes match the checked summary in `docs/form-coverage.md'."
  (dolist (expected edgar-forms-test--family-counts)
    (should
     (= (length (edgar-forms-by-family (car expected)))
        (cdr expected)))))

(ert-deftest edgar-forms-g10-family-has-l1-and-named-section-coverage ()
  "Every G10 form is L1+ and the three reviewed forms retain L2 sections."
  (let ((rows (edgar-forms-by-family "G10 Investment-company registration"))
        l2-forms)
    (should (= (length rows) 40))
    (dolist (row rows)
      (let ((form (car row))
            (info (cdr row)))
        (should (memq (plist-get info :level) '(L1 L2)))
        (when (eq (plist-get info :level) 'L2)
          (push form l2-forms))))
    (should (equal (sort l2-forms #'string<)
                   '("485BPOS" "497K" "N-1A")))
    (should
     (equal
      (plist-get (edgar-form-info "497K") :sections-or-fields)
      '(summary-prospectus-named-sections)))
    (dolist (form '("485BPOS" "N-1A"))
      (should
       (equal
        (plist-get (edgar-form-info form) :sections-or-fields)
        '(investment-objective fees-and-expenses principal-risks))))))

(ert-deftest edgar-forms-g4-13f-variants-have-typed-coverage ()
  "Both base Form 13F variants expose recorded typed data."
  (dolist (form '("13F-HR" "13F-NT"))
    (should (eq (plist-get (edgar-form-info form) :level) 'L2))))

(ert-deftest edgar-forms-g3-remaining-proxy-filings-use-generic-html-l1 ()
  "SC 13E3 and SC 14F1 use the shared HTML text path without typed fields."
  (dolist (form '("SC 13E3" "SC 14F1"))
    (let ((info (edgar-form-info form)))
      (should (eq (plist-get info :backend) 'html))
      (should (eq (plist-get info :level) 'L1))
      (should-not (plist-get info :sections-or-fields)))))

(ert-deftest edgar-forms-g2-offerings-have-typed-golden-coverage ()
  "Forms 144 and D expose their reviewed typed-field goldens."
  (dolist (form '("144" "D"))
    (let ((info (edgar-form-info form)))
      (should (eq (plist-get info :level) 'L2))
      (should (plist-get info :sections-or-fields)))))

(ert-deftest edgar-forms-g9-recorded-narratives-have-golden-coverage
    ()
  "G9 narrative fixtures with reviewed goldens are marked L2."
  (dolist (form
           '("10-K"
             "10-KT"
             "10-Q"
             "20-F"
             "8-K"
             "11-K"
             "15-12G"
             "18-K"
             "25"
             "40-F"
             "6-K"
             "SD"
             "NT 10-K"
             "NT 10-Q"
             "NT 11-K"
             "NT 20-F"))
    (should (eq (plist-get (edgar-form-info form) :level) 'L2)))
  (dolist (form '("1-K" "1-Z"))
    (should (eq (plist-get (edgar-form-info form) :backend) 'xml))
    (should (eq (plist-get (edgar-form-info form) :level) 'L1))))

(ert-deftest edgar-forms-g11-reg-a-reports-remain-generic-l1 ()
  "Reg A XML/HTML reports stay at L1 until typed/named section goldens exist."
  (dolist (form '("1-K" "1-SA" "1-U" "1-Z"))
    (should (eq (plist-get (edgar-form-info form) :level) 'L1))))

(ert-deftest
    edgar-forms-g8-proxy-and-tender-sections-have-golden-coverage
    ()
  "Proxy and tender sections with reviewed filing goldens are L2."
  (dolist (form
           '("DEF 14A"
             "DEF 14C"
             "DEFM14A"
             "SC TO-C"
             "SC TO-I"
             "SC TO-T"
             "SC 14D9"))
    (should (eq (plist-get (edgar-form-info form) :level) 'L2))))

(ert-deftest edgar-forms-g8-additional-proxy-materials-have-generic-coverage
    ()
  "Recorded proxy communications and preliminary forms have generic text coverage."
  (dolist (form '("425" "DEFA14A" "PRE 14A" "PRE 14C" "PX14A6G"))
    (should (eq (plist-get (edgar-form-info form) :level) 'L1))))

(ert-deftest
    edgar-forms-g8-residual-proxy-materials-have-generic-coverage
    ()
  "Recorded residual G8 primary documents are available at generic L1."
  (dolist (form
           '("ARS"
             "CB"
             "DEFC14A"
             "DEFR14A"
             "DFAN14A"
             "DFRN14A"
             "PREC14A"
             "PREM14A"
             "PRER14A"
             "PRRN14A"
             "SC14D1F"
             "SC14D9C"))
    (should (eq (plist-get (edgar-form-info form) :level) 'L1)))
  (should (eq (plist-get (edgar-form-info "ARS") :backend) 'pdf)))

(ert-deftest edgar-forms-g9-high-volume-narratives-have-item-coverage ()
  "Core periodic and event reports expose generic Item sections."
  (dolist (form '("8-K" "10-K" "10-Q" "20-F"))
    (should (eq (plist-get (edgar-form-info form) :level) 'L2))))

(ert-deftest edgar-forms-g7-s3-has-generic-named-section-coverage ()
  "S-3 exposes generic named sections without form-specific fields."
  (let ((info (edgar-form-info "S-3")))
    (should (eq (plist-get info :level) 'L2))
    (should
     (equal
      (plist-get info :sections-or-fields)
      '(generic-named-sections)))))

(ert-deftest edgar-forms-g7-residual-registrations-have-generic-coverage ()
  "Remaining Exchange Act registration forms have recorded generic coverage."
  (dolist (form '("10-12B" "10-12G" "20FR12B" "20FR12G" "40FR12G"))
    (should (eq (plist-get (edgar-form-info form) :level) 'L1))))

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
    (should (equal counts '((L0 . 1) (L1 . 15) (L2 . 2))))))

(provide 'edgar-forms-test)

;;; edgar-forms-test.el ends here
