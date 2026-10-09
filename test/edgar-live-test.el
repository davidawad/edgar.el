;;; edgar-live-test.el --- Live network test for edgar.el -*- lexical-binding: t; -*-

;;; Commentary:

;; Live network test for edgar.el.
;; Shares helpers with `edgar-test-support'.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'subr-x)
(require 'edgar-test-support)

(ert-deftest edgar-live-10k ()
  :tags
  '(network)
  (skip-unless (getenv "XBRL_LIVE"))
  (let* ((f (edgar-latest "AAPL" "10-K"))
         (s (edgar-section f "1A")))
    (should (equal (plist-get f :form) "10-K"))
    (should (> (length s) 5000))))

(provide 'edgar-live-test)

;;; edgar-live-test.el ends here
