;;; edgar-amendment-test.el --- Amendment and text-diff tests for edgar.el -*- lexical-binding: t; -*-

;;; Commentary:

;; Amendment and text-diff tests for edgar.el.
;; Shares helpers with `edgar-expect-test-support'.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'subr-x)
(require 'edgar-expect-test-support)

(ert-deftest edgar-amendments-link-original-accession ()
  (let ((submissions
         '(:filings
           (:recent
            (:accessionNumber
             ("0001318605-26-053166" "0001318605-26-010001")
             :form ("10-K/A" "10-K")
             :filingDate ("2026-04-30" "2026-02-01")
             :reportDate ("2025-12-31" "2025-12-31")
             :primaryDocument ("amendment.htm" "original.htm"))))))
    (cl-letf (((symbol-function 'xbrl-cik)
               (lambda (_) "CIK0001318605"))
              ((symbol-function 'xbrl--get) (lambda (_) submissions)))
      (let ((amendment (car (edgar-filings "TSLA" "10-K/A"))))
        (should
         (equal
          (plist-get amendment :amends) "0001318605-26-010001"))))))

(ert-deftest edgar-effective-section-uses-amendment-then-original ()
  (let*
      ((original
        '(:accn
          "0001318605-26-010001"
          :form "10-K"
          :filed "2026-02-01"
          :report "2025-12-31"
          :cik 1318605
          :url "https://example.test/original"))
       (amendment
        (edgar-expect--read (edgar-expect--file "10-ka-tsla" ".eld")))
       (newer-amendment (copy-sequence amendment))
       (amendment-html (edgar-expect--html "10-ka-tsla"))
       (original-html
        "<html><body><p>Item 1. Business</p><p>Original business text.</p></body></html>"))
    (setf (plist-get amendment :amends) (plist-get original :accn))
    (setf
     (plist-get newer-amendment :accn) "0001318605-26-060001"
     (plist-get newer-amendment :filed) "2026-05-30"
     (plist-get newer-amendment :amends) (plist-get original :accn)
     (plist-get newer-amendment :url) "https://example.test/newer-amendment")
    (cl-letf (((symbol-function 'edgar-filings)
               (lambda (_ticker form &rest _bounds)
                 (if (equal form "10-K/A")
                     (list newer-amendment amendment)
                   (list original))))
              ((symbol-function 'edgar--fetch)
               (lambda (url)
                 (cond
                  ((equal url (plist-get amendment :url))
                   amendment-html)
                  ((equal url (plist-get newer-amendment :url))
                   "<html><body>Cover page only.</body></html>")
                  (t
                   original-html))))
              ((symbol-function 'edgar--fetch-xml)
               (lambda (&rest _) (error "Unexpected XML fetch"))))
      (should
       (string-match-p
        "Tesla"
        (or (edgar-effective-section "TSLA" "10-K" "III.10") "")))
      (should
       (string-match-p
        "Original business text"
        (or (edgar-effective-section "TSLA" "10-K" "1") ""))))))

(ert-deftest edgar-text-diff-returns-unified-diff ()
  (let ((diff (edgar-text-diff "before text\n" "after text\n")))
    (should (string-match-p "^-before text$" diff))
    (should (string-match-p "^+after text$" diff))
    (should (equal (edgar-text-diff "same\n" "same\n") ""))))

(provide 'edgar-amendment-test)

;;; edgar-amendment-test.el ends here
