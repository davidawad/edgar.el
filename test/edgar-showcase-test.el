;;; edgar-showcase-test.el --- AllianceBernstein 10-K: edgar.el composed with xbrl.el -*- lexical-binding: t; -*-

;; Offline tests behind docs/showcase.md.  The filing is the recorded real
;; AllianceBernstein L.P. (CIK 1109448) annual report for FY2025, trimmed to its first 1.8 MB (through Item 7; see
;; test/fixtures/NOTES.md): test/fixtures/10-k-ablp.{eld,htm.gz}.  The xbrl stub payloads are the
;; byte-for-byte SEC companyconcept responses
;; https://data.sec.gov/api/xbrl/companyconcept/CIK0001109448/us-gaap/<Concept>.json
;; recorded 2026-10-03 as test/fixtures/xbrl-ablp-<Concept>.json.

(require 'ert)
(require 'cl-lib)
(require 'subr-x)
(add-to-list
 'load-path
 (file-name-directory (or load-file-name buffer-file-name)))
(require 'edgar-fixtures)

(defvar edgar-showcase-test--memo nil
  "Plist cache of the expensive derivations (a 1.8 MB excerpt still renders slowly).")

(defun edgar-showcase-test--get (key)
  "Value for KEY (:text or :sections) of the AB fixture, computed once."
  (or (plist-get edgar-showcase-test--memo key)
      (let ((v
             (pcase key
               (:text (edgar-fixtures-text "10-k-ablp"))
               (:sections
                (edgar-sections (edgar-showcase-test--get :text))))))
        (setq edgar-showcase-test--memo
              (plist-put edgar-showcase-test--memo key v))
        v)))

(defun edgar-showcase-test--norm-section (key)
  "Whitespace-normalized body of AB section KEY."
  (edgar-fixtures-norm
   (cdr (assoc key (edgar-showcase-test--get :sections)))))

(defmacro edgar-showcase-test--with-stubbed-xbrl (&rest body)
  "Run BODY with `xbrl--get' serving the recorded AB companyconcept payloads."
  (declare (indent 0))
  `(cl-letf (((symbol-function 'xbrl-cik)
              (lambda (_) "CIK0001109448"))
             ((symbol-function 'xbrl--get)
              (lambda (url)
                (with-temp-buffer
                  (insert-file-contents
                   (edgar-fixtures-path
                    (format "fixtures/xbrl-ablp-%s.json"
                            (file-name-base url))))
                  (json-parse-buffer
                   :object-type 'plist
                   :array-type 'list
                   :null-object nil
                   :false-object nil)))))
     ,@body))

(defun edgar-showcase-test--year (concept year)
  "Annual 10-K value of us-gaap CONCEPT for the fiscal year ending in YEAR."
  (plist-get
   (seq-find
    (lambda (f)
      (string-prefix-p (format "%d" year) (plist-get f :end)))
    (xbrl-annual 1109448 concept))
   :val))

(ert-deftest edgar-showcase-10k-section-keys ()
  (should
   (equal
    (mapcar #'car (edgar-showcase-test--get :sections))
    '("I.1"
      "I.1A"
      "I.1B"
      "I.1C"
      "I.2"
      "I.3"
      "I.4"
      "II.5"
      "II.6"
      "II.7"
      "II.7A"
      "II.8"
      "II.9"
      "II.9A"
      "II.9B"
      "II.9C"
      "III.10"
      "III.11"
      "III.12"
      "III.13"
      "III.14"
      "IV.15"
      "IV.16"))))

(ert-deftest edgar-showcase-10k-real-headings ()
  "Item bodies start at the real heading and hold the real prose."
  (should
   (string-prefix-p
    "Item 1A. Risk Factors Please consider this section"
    (edgar-showcase-test--norm-section "I.1A")))
  (should
   (string-prefix-p
    "Item 7. Management’s Discussion and Analysis of Financial Condition"
    (edgar-showcase-test--norm-section "II.7")))
  (should
   (string-search
    "Our total Assets Under Management (\"AUM\") as of December 31, 2025 were $866.9 billion"
    (edgar-showcase-test--norm-section "II.7"))))

(ert-deftest edgar-showcase-10k-bare-item-lookup ()
  "A bare item number resolves to the real Part-qualified body."
  (let ((text (edgar-showcase-test--get :text))
        (filing (edgar-fixtures-filing "10-k-ablp")))
    (cl-letf (((symbol-function 'edgar-text) (lambda (_) text)))
      (should
       (equal
        (edgar-section filing "7")
        (cdr (assoc "II.7" (edgar-showcase-test--get :sections)))))
      (should (> (length (edgar-section filing "1A")) 10000)))))

(ert-deftest edgar-showcase-filing-metadata ()
  (let ((f (edgar-fixtures-filing "10-k-ablp")))
    (should (equal (plist-get f :form) "10-K"))
    (should (equal (plist-get f :report) "2025-12-31"))
    (should (= (plist-get f :cik) 1109448))))

(ert-deftest edgar-showcase-margin-from-facts-matches-mdna ()
  "Margins computed from xbrl.el facts equal those printed in Item 7."
  (edgar-showcase-test--with-stubbed-xbrl
    (let* ((mdna (edgar-showcase-test--norm-section "II.7"))
           (margin
            (lambda (year)
              (*
               100
               (/
                (float
                 (-
                  (edgar-showcase-test--year
                   "OperatingIncomeLoss" year)
                  (edgar-showcase-test--year
                   "NetIncomeLossAttributableToNoncontrollingInterest"
                   year)))
                (edgar-showcase-test--year
                 "RevenuesNetOfInterestExpense" year))))))
      (should
       (= (edgar-showcase-test--year
           "RevenuesNetOfInterestExpense" 2025)
          4530652000))
      (should (< 23.04 (funcall margin 2025) 23.05))
      ;; Item 7's table prints "Operating margin(1) 23.0 % 24.7 % 19.1 %".
      (should
       (string-search
        (format "Operating margin(1) %.1f %% %.1f %% %.1f %%"
                (funcall margin 2025)
                (funcall margin 2024)
                (funcall margin 2023))
        mdna))
      (should
       (string-search "Net revenues $ 4,530,652 $ 4,475,139" mdna)))))

(ert-deftest edgar-showcase-facts-join-filing-metadata ()
  "The newest fact comes from the recorded filing's own accession."
  (edgar-showcase-test--with-stubbed-xbrl
    (let ((filing (edgar-fixtures-filing "10-k-ablp"))
          (latest
           (car
            (last
             (xbrl-annual 1109448 "RevenuesNetOfInterestExpense")))))
      (should
       (equal (plist-get latest :end) (plist-get filing :report)))
      (should
       (equal (plist-get latest :accn) (plist-get filing :accn)))
      (should (equal (plist-get latest :unit) "USD")))))

(provide 'edgar-showcase-test)
;;; edgar-showcase-test.el ends here
