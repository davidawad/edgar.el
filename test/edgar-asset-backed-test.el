;;; edgar-asset-backed-test.el --- ABS-EE parser tests -*- lexical-binding: t; -*-

;;; Code:

(require 'ert)
(require 'edgar-asset-backed)

(defconst edgar-asset-backed-test--directory
  (file-name-directory (or load-file-name buffer-file-name)))

(defun edgar-asset-backed-test--xml ()
  "Read the recorded EX-102 CMBS XML fixture."
  (with-temp-buffer
    (insert-file-contents
     (expand-file-name "fixtures/abs-ee-bank5-sample.xml"
                       edgar-asset-backed-test--directory))
    (buffer-string)))

(defun edgar-asset-backed-test--golden ()
  "Read expected values for the recorded CMBS EX-102 fixture."
  (let ((expected
         (with-temp-buffer
           (insert-file-contents
            (expand-file-name "expect/abs-ee-bank5-sample.eld"
                              edgar-asset-backed-test--directory))
           (read (current-buffer))))
        (golden
         (with-temp-buffer
           (insert-file-contents
            (expand-file-name "golden-fields/abs-ee-bank5-sample.eld"
                              edgar-asset-backed-test--directory))
           (read (current-buffer)))))
    (should (equal expected golden))
    expected))

(ert-deftest edgar-abs-ee-parses-recorded-cmbs-exhibit ()
  "The actual SEC CMBS EX-102 yields common fields and all source records."
  (cl-letf (((symbol-function 'edgar-documents)
             (lambda (_filing)
               '((:type "EX-102"
                  :url "https://www.sec.gov/Archives/edgar/data/fixture/exh_102.xml"))))
            ((symbol-function 'edgar--fetch)
             (lambda (_url) (edgar-asset-backed-test--xml))))
    (let* ((expected (edgar-asset-backed-test--golden))
           (parsed (edgar-abs-ee-asset-data '(:form "ABS-EE" :url "https://example.test/filing.htm")))
           (first (car (edgar-abs-ee-data-assets parsed))))
      (should (edgar-abs-ee-data-p parsed))
      (should (equal (edgar-abs-ee-data-asset-class parsed)
                     (plist-get expected :asset-class)))
      (should (= (length (edgar-abs-ee-data-assets parsed))
                 (plist-get expected :asset-count)))
      (should (equal (edgar-abs-ee-asset-asset-number first)
                     (plist-get expected :first-asset-number)))
      (should (equal (edgar-abs-ee-asset-asset-type-number first)
                     (plist-get expected :first-asset-type-number)))
      (should (equal (edgar-abs-ee-asset-property-name first)
                     (plist-get expected :first-property-name)))
      (should (equal (edgar-abs-ee-asset-property-state first)
                     (plist-get expected :first-property-state)))
      (should (equal (edgar-abs-ee-asset-original-loan-amount first)
                     (plist-get expected :first-original-loan-amount)))
      (should (equal (edgar-abs-ee-asset-current-balance first)
                     (plist-get expected :first-current-balance)))
      (should (consp (edgar-abs-ee-asset-source first)))
      (should (consp (edgar-abs-ee-data-tree parsed))))))

(ert-deftest edgar-abs-ee-returns-nil-without-ex-102 ()
  "Filings without an EX-102 do not produce asset data."
  (cl-letf (((symbol-function 'edgar-documents) (lambda (_filing) nil)))
    (should-not
     (edgar-abs-ee-asset-data '(:form "ABS-EE" :url "https://example.test/filing.htm")))))

(provide 'edgar-asset-backed-test)
;;; edgar-asset-backed-test.el ends here
