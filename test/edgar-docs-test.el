;;; edgar-docs-test.el --- Tests for filing documents -*- lexical-binding: t; -*-

(require 'ert)
(require 'edgar-docs)
(require 'edgar-form-docs)

(ert-deftest edgar-form-docs-table-matches-registry ()
  (should (= (length (edgar-form-docs--rows)) 245))
  (should (string-match-p "| `10-K` |" (edgar-form-docs--table)))
  (should-not (edgar-form-docs-check)))

(defconst edgar-docs-test--filing
  '(:accn
    "0000320193-26-000018"
    :form "8-K"
    :cik 320193
    :url "https://www.sec.gov/Archives/edgar/data/320193/000032019326000018/aapl-20260730.htm")
  "Recorded Apple 8-K filing used by document tests.")

(defun edgar-docs-test--fixture (name)
  "Read fixture NAME from the test fixtures directory."
  (with-temp-buffer
    (insert-file-contents (expand-file-name name "test/fixtures"))
    (buffer-string)))

(ert-deftest edgar-documents-reads-index-json ()
  (let ((index (edgar-docs-test--fixture "8-k-aapl-index.json")))
    (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) index)))
      (let ((docs (edgar-documents edgar-docs-test--filing)))
        (should
         (cl-find-if
          (lambda (doc)
            (and (equal "EX-99.1" (plist-get doc :type))
                 (equal
                  "173484" (number-to-string (plist-get doc :size)))))
          docs))
        (should
         (equal
          "https://www.sec.gov/Archives/edgar/data/320193/000032019326000018/a8-kex991q3202606272026.htm"
          (plist-get
           (cl-find-if
            (lambda (doc)
              (equal
               "a8-kex991q3202606272026.htm" (plist-get doc :name)))
            docs)
           :url)))))))

(ert-deftest edgar-exhibit-reads-apple-press-release ()
  (let ((index (edgar-docs-test--fixture "8-k-aapl-index.json"))
        (html (edgar-docs-test--fixture "8-k-aapl-ex99-1.htm")))
    (cl-letf (((symbol-function 'edgar--fetch)
               (lambda (url)
                 (if (string-suffix-p "/index.json" url)
                     index
                   html))))
      (let ((text (edgar-exhibit edgar-docs-test--filing "EX-99.1")))
        (should (string-match-p "Apple" text))
        (should (string-match-p "financial results" text))))))

(ert-deftest edgar-40f-documents-and-exhibit-are-addressable ()
  "A foreign-issuer annual filing exposes arbitrary indexed exhibits."
  (let* ((filing
          '(:accn "0001594805-24-000007" :form "40-F" :cik 1594805
            :url "https://www.sec.gov/Archives/edgar/data/1594805/000159480524000007/shop-20231231.htm"))
         (index (edgar-docs-test--fixture "40-f-shop-index.json"))
         (html (edgar-docs-test--fixture "40-f-shop-ex23-1.html")))
    (cl-letf (((symbol-function 'edgar--fetch)
               (lambda (url)
                 (if (string-suffix-p "/index.json" url) index html))))
      (let ((docs (edgar-documents filing)))
        (should (cl-find-if (lambda (doc) (equal "EX-23.1" (plist-get doc :type))) docs)))
      (let ((text (edgar-exhibit filing "EX-23.1")))
        (should (string-match-p "Consent of Independent Registered Public Accounting Firm" text))
        (should (string-match-p "incorporation by reference" text))))))

(ert-deftest edgar-6k-documents-include-primary-document ()
  "A 6-K's filing directory is available through the shared document API."
  (let* ((filing
          '(:accn "0001046179-26-000660" :form "6-K" :cik 1046179
            :url "https://www.sec.gov/Archives/edgar/data/1046179/000104617926000660/tsm-monthend6kx20260924.htm"))
         (index (edgar-docs-test--fixture "6-k-tsm-index.json")))
    (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) index)))
      (let ((doc (cl-find-if
                  (lambda (item)
                    (equal "tsm-monthend6kx20260924.htm" (plist-get item :name)))
                  (edgar-documents filing))))
        (should (equal "tsm-monthend6kx20260924.htm" (plist-get doc :name)))
        (should (equal "HTM" (plist-get doc :type)))
        (should (equal
                 "https://www.sec.gov/Archives/edgar/data/1046179/000104617926000660/tsm-monthend6kx20260924.htm"
                 (plist-get doc :url)))))))

(provide 'edgar-docs-test)
;;; edgar-docs-test.el ends here
