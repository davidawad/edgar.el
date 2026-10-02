;;; edgar-index-test.el --- Tests for SEC filing indexes -*- lexical-binding: t; -*-

;;; Code:

(require 'ert)
(require 'edgar-index)

(defconst edgar-index-test--directory
  (file-name-directory (or load-file-name buffer-file-name))
  "Directory containing the EDGAR index tests.")

(defun edgar-index-test--fixture (name)
  "Return recorded form-index fixture NAME."
  (with-temp-buffer
    (insert-file-contents
     (expand-file-name (concat "fixtures/" name)
                       edgar-index-test--directory))
    (buffer-string)))

(ert-deftest edgar-index-parses-fixed-width-rows ()
  (let* ((rows
          (edgar-index--parse
           (edgar-index-test--fixture "form-index-2026-q2.idx")))
         (first (car rows)))
    (should (= (length rows) 6))
    (should (equal (plist-get first :form) "10-K"))
    (should
     (equal (plist-get first :company) "21Shares Polkadot ETF"))
    (should (= (plist-get first :cik) 2054247))
    (should (equal (plist-get first :filed) "2026-06-29"))
    (should (equal (plist-get first :report) ""))
    (should (equal (plist-get first :doc) "0001213900-26-073214.txt"))
    (should
     (equal
      (plist-get first :url)
      (concat
       "https://www.sec.gov/Archives/edgar/data/2054247/"
       "0001213900-26-073214.txt")))))

(ert-deftest edgar-index-base-form-includes-amendments ()
  (let ((text (edgar-index-test--fixture "form-index-2026-q2.idx")))
    (should (= (length (edgar-index--parse text "10-K")) 4))
    (should (= (length (edgar-index--parse text "10-K/A")) 2))
    (should (= (length (edgar-index--parse text "4")) 1))))

(ert-deftest edgar-index-filings-fetches-quarterly-gzip ()
  (let (requested)
    (cl-letf (((symbol-function 'edgar-index--fetch)
               (lambda (url)
                 (setq requested url)
                 (edgar-index-test--fixture
                  "form-index-2026-q2.idx"))))
      (let ((rows (edgar-index-filings 2026 "QTR2" "10-K")))
        (should (= (length rows) 4))
        (should
         (equal
          requested
          (concat
           "https://www.sec.gov/Archives/edgar/full-index/"
           "2026/QTR2/form.gz")))))))

(ert-deftest edgar-daily-index-normalizes-date ()
  (let (requested)
    (cl-letf (((symbol-function 'edgar-index--fetch)
               (lambda (url)
                 (setq requested url)
                 (edgar-index-test--fixture
                  "form-index-2026-09-30.idx"))))
      (let ((rows (edgar-daily-index-filings "2026-09-30" "1")))
        (should (= (length rows) 1))
        (should (equal (plist-get (car rows) :filed) "2026-09-30"))
        (should
         (equal
          requested
          (concat
           "https://www.sec.gov/Archives/edgar/daily-index/"
           "2026/QTR3/form.20260930.idx")))))))

(ert-deftest edgar-index-rejects-invalid-input ()
  (should-error (edgar-index-filings 2026 5) :type 'user-error)
  (should-error (edgar-index-filings 1993 1) :type 'user-error)
  (should-error
   (edgar-daily-index-filings "2026-02-30")
   :type 'user-error)
  (should-error (edgar-index--parse "no separator here")))

(provide 'edgar-index-test)
;;; edgar-index-test.el ends here
