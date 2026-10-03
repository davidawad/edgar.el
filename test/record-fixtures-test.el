;;; record-fixtures-test.el --- offline tests for the fixture recorder -*- lexical-binding: t; -*-

;;; Code:

(require 'ert)
(require 'edgar)
(load (expand-file-name "../tools/record-fixtures.el"
                        (file-name-directory
                         (or load-file-name buffer-file-name)))
      nil t)

(ert-deftest edgar-record-quarter-pairs-use-last-completed-quarter ()
  "Choose the same completed quarter three years earlier."
  (should
   (equal
    (edgar-record-quarter-pairs
     (encode-time 0 0 12 2 10 2026 t))
    '((2026 . 3) (2023 . 3))))
  (should
   (equal
    (edgar-record-quarter-pairs
     (encode-time 0 0 12 2 2 2026 t))
    '((2025 . 4) (2022 . 4))))
  (should
   (equal
    (edgar-record-quarter-pairs
     (encode-time 0 0 12 1 1 2026 t))
    '((2025 . 4) (2022 . 4)))))

(ert-deftest edgar-record-ranking-is-deterministic ()
  "Seeded ranking is stable regardless of index row order."
  (let* ((edgar-record-seed "offline-test")
         (filings
          (list
           '(:form "10-K" :accn "a")
           '(:form "10-K" :accn "b")
           '(:form "10-K" :accn "c")))
         (left
          (mapcar
           (lambda (filing) (plist-get filing :accn))
           (edgar-record--rank "10-K" "recent" filings)))
         (right
          (mapcar
           (lambda (filing) (plist-get filing :accn))
           (edgar-record--rank "10-K" "recent" (reverse filings)))))
    (should (equal left right))))

(ert-deftest edgar-record-prefers-mid-sized-capped-documents ()
  "Inspect a bounded candidate sample, skip oversized docs, prefer target size."
  (let* ((edgar-record-target-bytes 250)
         (edgar-record-max-bytes 800)
         (candidates
          (list
           (list '(:accn "a") nil 900)
           (list '(:accn "b") nil 240)
           (list '(:accn "c") nil 500)))
         (bounded
          (seq-filter
           (lambda (candidate)
             (edgar-record--suitable-item-p
              `((size . ,(number-to-string (nth 2 candidate))))))
           candidates))
         (ranked
          (edgar-record--prefer-candidates "10-K" "recent" bounded)))
    (should (= (length ranked) 2))
    (should (equal (plist-get (caar ranked) :accn) "b"))))

(ert-deftest
    edgar-record-primary-item-falls-back-to-submission-filename
    ()
  "Use the submission TYPE/FILENAME when directory item types are icons."
  (let* ((url "https://www.sec.gov/Archives/example/submission.txt")
         (filing (list :form "1-SA" :url url))
         (primary
          '((name . "port4_1sa.htm")
            (type . "text.gif")
            (size . "858822")))
         (items
          (list
           '((name . "submission.txt")
             (type . "text.gif")
             (size . "900000"))
           primary
           '((name . "primary_doc.xml")
             (type . "text.gif")
             (size . "1466")))))
    (cl-letf (((symbol-function 'edgar--fetch)
               (lambda (requested-url)
                 (should (equal requested-url url))
                 (concat
                  "<DOCUMENT>\n<TYPE>EX-99.1\n"
                  "<FILENAME>exhibit.htm\n</DOCUMENT>\n"
                  "<DOCUMENT>\n<TYPE>1-SA\n"
                  "<FILENAME>port4_1sa.htm\n</DOCUMENT>"))))
      (should
       (equal (edgar-record--primary-item filing items) primary)))))

(ert-deftest edgar-record-gzip-writer-produces-valid-stream ()
  "Write a non-empty, valid gzip fixture with deterministic metadata."
  (let ((raw (make-temp-file "edgar-record-raw-"))
        (compressed (make-temp-file "edgar-record-gzip-")))
    (unwind-protect
        (progn
          (with-temp-file raw
            (insert "<html><body>recorded filing</body></html>"))
          (edgar-record--gzip-file raw compressed)
          (should
           (> (file-attribute-size (file-attributes compressed)) 0))
          (should
           (zerop (call-process "gzip" nil nil nil "-t" compressed))))
      (delete-file raw)
      (delete-file compressed))))

(ert-deftest edgar-record-write-pair-stores-xml-and-primary-url ()
  "Store an XML primary as XML and replace the submission URL in metadata."
  (let*
      ((directory (make-temp-file "edgar-record-fixture-" t))
       (filing
        '(:accn
          "0000000001-26-000001"
          :form "1-K"
          :cik 1
          :doc "submission.txt"
          :url "https://www.sec.gov/submission.txt"))
       (item '((name . "primary_doc.xml") (size . "55")))
       (primary-url
        "https://www.sec.gov/Archives/edgar/data/1/000000000126000001/primary_doc.xml"))
    (unwind-protect
        (cl-letf (((symbol-function 'edgar-record--dir)
                   (lambda () directory))
                  ((symbol-function 'edgar--fetch)
                   (lambda (url)
                     (should (equal url primary-url))
                     "<edgarSubmission/>")))
          (should
           (edgar-record--write-pair
            "sample" filing item '(2026 . 3) "recent"))
          (should
           (file-exists-p (expand-file-name "sample.xml" directory)))
          (should-not
           (file-exists-p
            (expand-file-name "sample.htm.gz" directory)))
          (with-temp-buffer
            (insert-file-contents
             (expand-file-name "sample.eld" directory))
            (let ((metadata (read (current-buffer))))
              (should
               (equal (plist-get metadata :doc) "primary_doc.xml"))
              (should
               (equal (plist-get metadata :url) primary-url)))))
      (delete-directory directory t))))

(ert-deftest edgar-record-sample-reports-no-filing-offline ()
  "An empty sampled index is reported without any network request."
  (should
   (eq
    (edgar-record--sample-quarter
     "NEVER-FILED" "recent" '(2026 . 3) nil)
    :no-filing)))

(ert-deftest
    edgar-record-run-only-reports-forms-absent-from-both-quarters
    ()
  "A form present in either sampled quarter is not reported as absent."
  (cl-letf (((symbol-function 'edgar-index-filings)
             (lambda (&rest _) nil))
            ((symbol-function 'edgar-record--sample-quarter)
             (lambda (form vintage _quarter _filings)
               (if (and (equal form "10-K") (equal vintage "older"))
                   :existing
                 :no-filing))))
    (let* ((inhibit-message t)
           (result
            (edgar-record-fixtures-run '((2026 . 3) (2023 . 3))))
           (missing (plist-get result :no-filing)))
      (should-not (member "10-K" missing))
      (should (member "10-Q" missing)))))

(provide 'record-fixtures-test)
;;; record-fixtures-test.el ends here
