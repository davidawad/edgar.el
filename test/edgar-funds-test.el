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

(defun edgar-funds-test--golden (slug)
  "Return typed field golden for SLUG after matching its expect snapshot."
  (let ((expected
         (with-temp-buffer
           (insert-file-contents
            (expand-file-name (concat "expect/" slug ".eld")
                              edgar-funds-test--directory))
           (read (current-buffer))))
        (golden
         (with-temp-buffer
           (insert-file-contents
            (expand-file-name (concat "golden-fields/" slug ".eld")
                              edgar-funds-test--directory))
           (read (current-buffer)))))
    (should (equal expected golden))
    golden))

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

(defun edgar-funds-test--report-snapshot (form slug)
  "Return stable identifying and first-holding fields for SLUG."
  (let* ((report (edgar-funds-test--report form slug))
         (first (car (edgar-fund-report-holdings report))))
    (list :registrant-name (edgar-fund-report-registrant-name report)
          :cik (edgar-fund-report-cik report)
          :report-date (edgar-fund-report-report-date report)
          :net-assets (edgar-fund-report-net-assets report)
          :holding-count (length (edgar-fund-report-holdings report))
          :first-holding-name (edgar-funds--value first '(name))
          :first-holding-cusip (edgar-funds--value first '(cusip))
          :first-holding-value (edgar-funds--value first '(valUSD)))))

(ert-deftest edgar-fund-reports-match-distinct-filer-goldens ()
  "N-CEN, N-MFP3 and NPORT-P layouts match expectations from distinct filers."
  (dolist (case '( ("N-CEN" "n-cen-lincoln-funds")
                   ("N-CEN" "n-cen-yieldstreet")
                   ("N-MFP3" "n-mfp3-jnl-series")
                   ("N-MFP3" "n-mfp3-pace-select")
                   ("NPORT-P" "nport-p-senior-debt")
                   ("NPORT-P" "nport-p-american-century")))
    (let ((slug (cadr case)))
      (should (edgar-fund-report-p
               (edgar-funds-test--report (car case) slug)))
      (should (equal (edgar-funds-test--report-snapshot (car case) slug)
                     (edgar-funds-test--golden slug))))))

(ert-deftest edgar-fund-report-nport-holdings-match-golden-data ()
  "N-PORT-P accessors expose registrant totals and ordered holdings."
  (let* ((expected (edgar-funds-test--golden "nport-p-eagle"))
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
  (let* ((expected
          (edgar-funds-test--golden "n-mfp3-northwestern-mutual"))
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
  (let* ((expected (edgar-funds-test--golden "n-cen-alps"))
         (report (edgar-funds-test--report "N-CEN" "n-cen-alps")))
    (should (edgar-fund-report-p report))
    (should (equal (edgar-fund-report-registrant-name report)
                   (plist-get expected :registrant-name)))
    (should (equal (edgar-fund-report-cik report) (plist-get expected :cik)))
    (should (equal (edgar-fund-report-report-date report)
                   (plist-get expected :report-date)))
    (should-not (edgar-fund-report-holdings report))))

(ert-deftest edgar-fund-report-reads-not-timely-n-cen-primary ()
  "Read useful fields from a recorded NT N-CEN XML primary."
  (let* ((expected (edgar-funds-test--golden "nt-n-cen-brown"))
         (report
          (edgar-funds-test--report "NT N-CEN" "nt-n-cen-brown")))
    (should (edgar-fund-report-p report))
    (should (equal (edgar-fund-report-form report) "N-CEN"))
    (should (equal (edgar-fund-report-registrant-name report)
                   (plist-get expected :registrant-name)))
    (should (equal (edgar-fund-report-cik report)
                   (plist-get expected :cik)))
    (should (equal (edgar-fund-report-report-date report)
                   (plist-get expected :report-date)))
    (should-not (edgar-fund-report-holdings report))))

(ert-deftest edgar-fund-report-reads-not-timely-nport-primary ()
  "Read useful fields and every holding from a recorded NT NPORT-P primary."
  (let* ((expected (edgar-funds-test--golden "nt-nport-p-archer"))
         (report
          (edgar-funds-test--report
           "NT NPORT-P" "nt-nport-p-archer"))
         (first (car (edgar-fund-report-holdings report))))
    (should (edgar-fund-report-p report))
    (should (equal (edgar-fund-report-form report) "NPORT-P"))
    (should (equal (edgar-fund-report-registrant-name report)
                   (plist-get expected :registrant-name)))
    (should (equal (edgar-fund-report-cik report)
                   (plist-get expected :cik)))
    (should (equal (edgar-fund-report-report-date report)
                   (plist-get expected :report-date)))
    (should (equal (edgar-fund-report-net-assets report)
                   (plist-get expected :net-assets)))
    (should (= (length (edgar-fund-report-holdings report))
               (plist-get expected :holding-count)))
    (should (equal (edgar-funds--value first '(name))
                   (plist-get expected :first-holding-name)))
    (should (equal (edgar-funds--value first '(cusip))
                   (plist-get expected :first-holding-cusip)))
    (should (equal (edgar-funds--value first '(valUSD))
                   (plist-get expected :first-holding-value)))))

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
