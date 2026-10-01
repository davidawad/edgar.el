;;; edgar-test.el --- tests for edgar.el -*- lexical-binding: t; -*-

(require 'ert)
(require 'edgar)

(ert-deftest edgar-sections-picks-longest ()
  (let* ((text (concat "Item 1.\nItem 1A.\nItem 2.\n"
                       "Item 1. Business\nwe sell phones and many other things\n"
                       "Item 1A. Risk Factors\nrisks galore here and there\n"
                       "Item 2. Properties\nbuildings\n"))
         (s (edgar-sections text)))
    (should (equal (mapcar #'car s) '("1" "1A" "2")))
    (should (string-match-p "phones" (cdr (assoc "1" s))))
    (should (string-match-p "risks galore" (cdr (assoc "1A" s))))))

(ert-deftest edgar-live-10k ()
  :tags '(network)
  (skip-unless (getenv "XBRL_LIVE"))
  (let* ((f (edgar-latest "AAPL" "10-K"))
         (s (edgar-section f "1A")))
    (should (equal (plist-get f :form) "10-K"))
    (should (> (length s) 5000))))

(provide 'edgar-test)
;;; edgar-test.el ends here
