;;; edgar-funds-test.el --- Fund XML parser tests -*- lexical-binding: t; -*-

;;; Code:

(require 'ert)
(require 'edgar-funds)

(defconst edgar-funds-test--directory
  (file-name-directory (or load-file-name buffer-file-name)))

(defun edgar-funds-test--xml (slug)
  "Read recorded SEC XML fixture SLUG."
  (with-temp-buffer
    (insert-file-contents
     (expand-file-name (concat "fixtures/" slug ".xml")
                       edgar-funds-test--directory))
    (buffer-string)))

(defun edgar-funds-test--golden (form)
  "Return hand-checked golden fields for FORM."
  (with-temp-buffer
    (insert-file-contents
     (expand-file-name "golden/fund-structured.eld"
                       edgar-funds-test--directory))
    (cdr (assoc form (read (current-buffer))))))

(defun edgar-funds-test--ncsr-html ()
  "Read the real, compressed N-CSR primary document fixture."
  (with-temp-buffer
    (let ((coding-system-for-read 'utf-8)
          (auto-compression-mode t))
      (insert-file-contents
       (expand-file-name "fixtures/structured/ncsr-sample.htm.gz"
                         edgar-funds-test--directory)))
    (buffer-string)))

(defun edgar-funds-test--ncsr-golden ()
  "Read expected values for the N-CSR section fixture."
  (with-temp-buffer
    (insert-file-contents
     (expand-file-name "golden/ncsr-sample.eld"
                       edgar-funds-test--directory))
    (read (current-buffer))))

(defun edgar-funds-test--report (form slug)
  "Parse recorded filing SLUG as FORM without network access."
  (cl-letf (((symbol-function 'edgar--fetch)
             (lambda (_url) (edgar-funds-test--xml slug))))
    (edgar-fund-report
     (list :form form
           :url (concat "https://www.sec.gov/Archives/edgar/data/fixture/"
                        "primary_doc.xml")))))

(ert-deftest edgar-fund-report-nport-holdings-match-golden-data ()
  "N-PORT-P accessors expose registrant totals and ordered holdings."
  (let* ((expected (edgar-funds-test--golden "NPORT-P"))
         (report (edgar-funds-test--report "NPORT-P" "nport-p-eagle")))
    (should (edgar-fund-report-p report))
    (should (equal (edgar-fund-report-form report) "NPORT-P"))
    (should (equal (edgar-fund-report-registrant-name report)
                   (plist-get expected :registrant-name)))
    (should (equal (edgar-fund-report-cik report) (plist-get expected :cik)))
    (should (equal (edgar-fund-report-report-date report)
                   (plist-get expected :report-date)))
    (should (equal (edgar-fund-report-net-assets report)
                   (plist-get expected :net-assets)))
    (should (= (length (edgar-fund-report-holdings report))
               (plist-get expected :holding-count)))
    (let ((first (car (edgar-fund-report-holdings report))))
      (should (equal (edgar-funds--value first '(name))
                     (plist-get expected :first-holding-name)))
      (should (equal (edgar-funds--value first '(cusip))
                     (plist-get expected :first-holding-cusip)))
      (should (equal (edgar-funds--value first '(valUSD))
                     (plist-get expected :first-holding-value))))))

(ert-deftest edgar-fund-report-n-mfp3-preserves-large-holding-list ()
  "N-MFP3 exposes the full schedule without dropping repeated securities."
  (let* ((expected (edgar-funds-test--golden "N-MFP3"))
         (report
         (edgar-funds-test--report
          "N-MFP3" "n-mfp3-northwestern-mutual")))
    (should (edgar-fund-report-p report))
    (should (equal (edgar-fund-report-registrant-name report)
                   (plist-get expected :registrant-name)))
    (should (equal (edgar-fund-report-cik report) (plist-get expected :cik)))
    (should (equal (edgar-fund-report-report-date report)
                   (plist-get expected :report-date)))
    (should (= (length (edgar-fund-report-holdings report))
               (plist-get expected :holding-count)))
    (should (edgar-fund-report-tree report))))

(ert-deftest edgar-fund-report-n-cen-reads-attribute-date ()
  "N-CEN accessors retain the report-period XML attribute."
  (let* ((expected (edgar-funds-test--golden "N-CEN"))
         (report (edgar-funds-test--report "N-CEN" "n-cen-alps")))
    (should (edgar-fund-report-p report))
    (should (equal (edgar-fund-report-registrant-name report)
                   (plist-get expected :registrant-name)))
    (should (equal (edgar-fund-report-cik report) (plist-get expected :cik)))
    (should (equal (edgar-fund-report-report-date report)
                   (plist-get expected :report-date)))
    (should-not (edgar-fund-report-holdings report))))

(ert-deftest edgar-fund-report-rejects-unsupported-form ()
  "A parsed XML document with an unsupported submission type returns nil."
  (cl-letf (((symbol-function 'edgar--fetch)
             (lambda (_url) (edgar-funds-test--xml "144-aapl"))))
    (should-not
     (edgar-fund-report
      '(:form "N-PX"
        :url "https://www.sec.gov/Archives/edgar/data/fixture/doc.xml")))))

(ert-deftest edgar-fund-sections-reads-real-n-csr-item-section ()
  "The section API extracts Item sections from a recorded N-CSR."
  (let ((html (edgar-funds-test--ncsr-html))
        (expected (edgar-funds-test--ncsr-golden)))
    (cl-letf (((symbol-function 'edgar--fetch) (lambda (_url) html)))
      (let* ((filing
              '(:form "N-CSR"
                :url "https://www.sec.gov/Archives/edgar/data/737520/000003014626000114/output.htm"))
             (sections (edgar-fund-sections filing))
             (item (cdr (assoc (plist-get expected :section) sections))))
        (should item)
        (should (string-match-p (plist-get expected :contains) item))))))

(provide 'edgar-funds-test)
;;; edgar-funds-test.el ends here
