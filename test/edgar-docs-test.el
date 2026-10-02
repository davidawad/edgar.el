;;; edgar-docs-test.el --- Tests for filing documents -*- lexical-binding: t; -*-

(require 'ert)
(require 'edgar-docs)

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

(provide 'edgar-docs-test)
;;; edgar-docs-test.el ends here
