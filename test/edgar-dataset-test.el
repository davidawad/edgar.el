;;; edgar-dataset-test.el --- Tests for SEC bulk data-set plumbing -*- lexical-binding: t; -*-

;;; Commentary:

;; Hermetic tests for `edgar-dataset'.  Fixture ZIPs are assembled from the
;; TSVs under test/fixtures with the `zip' program; reading them needs
;; `edgar-unzip-program'.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'edgar-dataset)

(defconst edgar-dataset-test--directory
  (file-name-directory (or load-file-name buffer-file-name))
  "Directory containing the data-set tests.")

(defvar edgar-dataset-test--cache
  (make-temp-file "edgar-dataset-test-" t)
  "Scratch cache directory for these tests.")

(defun edgar-dataset-test--tools-p ()
  "Return non-nil when the zip and unzip programs are available."
  (and (executable-find "zip") (executable-find edgar-unzip-program)))

(defun edgar-dataset-test--zip (fixture)
  "Return a ZIP of the TSV files in test/fixtures/FIXTURE."
  (let ((source
         (expand-file-name (concat "fixtures/" fixture)
                           edgar-dataset-test--directory))
        (zip
         (expand-file-name (concat
                            (replace-regexp-in-string
                             "/" "-" fixture)
                            ".zip")
                           edgar-dataset-test--cache)))
    (unless (file-exists-p zip)
      (apply #'call-process
             "zip"
             nil
             nil
             nil
             "-q"
             "-j"
             zip
             (directory-files source t "\\.tsv\\'")))
    zip))

(defmacro edgar-dataset-test--with-zip (var &rest body)
  "Bind VAR to the 13F fixture ZIP of the newest data set and run BODY."
  (declare (indent 1) (debug t))
  `(progn
     (skip-unless (edgar-dataset-test--tools-p))
     (let ((edgar-dataset-cache-directory edgar-dataset-test--cache)
           (,var (edgar-dataset-test--zip "13f-dataset/new")))
       ,@body)))

(ert-deftest edgar-dataset-zip-urls-from-page ()
  (cl-letf (((symbol-function 'edgar-http-get)
             (lambda (url _agent)
               (should (equal url "https://www.sec.gov/data/page"))
               "<a href=\"/files/a/2026_new.zip\">x</a>
<a href=\"/files/a/2026_new.zip\">dup</a><a href=\"/files/readme.pdf\">r</a>
<a href=\"https://www.sec.gov/files/b/2025_old.zip\">y</a>")))
    (should
     (equal
      (edgar-dataset-zip-urls "https://www.sec.gov/data/page")
      '("https://www.sec.gov/files/a/2026_new.zip"
        "https://www.sec.gov/files/b/2025_old.zip")))))

(ert-deftest edgar-dataset-download-caches-by-url ()
  (let*
      ((edgar-dataset-cache-directory
        (make-temp-file "edgar-dl-" t))
       (calls 0)
       (url
        "https://www.sec.gov/files/x/01jun2026-31aug2026_form13f.zip"))
    (cl-letf
        (((symbol-function 'url-retrieve-synchronously)
          (lambda (&rest _)
            (cl-incf calls)
            (let ((buffer (generate-new-buffer " dl")))
              (with-current-buffer buffer
                (set-buffer-multibyte nil)
                (insert
                 "HTTP/1.1 200 OK\r\nContent-Type: zip\r\n\r\nPK\3\4"))
              buffer)))
         ((symbol-function 'edgar-http--throttle) #'ignore))
      (let ((file (edgar-dataset-download url)))
        (should
         (string-suffix-p "-01jun2026-31aug2026_form13f.zip" file))
        (should (equal (edgar-dataset-download url) file))
        (should (= calls 1))
        (with-temp-buffer
          (set-buffer-multibyte nil)
          (insert-file-contents-literally file)
          (should (equal (buffer-string) "PK\3\4")))))
    (let ((local (make-temp-file "edgar-local-" nil ".zip")))
      (should (equal (edgar-dataset-download local) local)))))

(ert-deftest edgar-dataset-download-rejects-http-errors ()
  (let ((edgar-dataset-cache-directory
         (make-temp-file "edgar-dl-" t)))
    (cl-letf (((symbol-function 'url-retrieve-synchronously)
               (lambda (&rest _)
                 (let ((buffer (generate-new-buffer " dl")))
                   (with-current-buffer buffer
                     (insert "HTTP/1.1 404 Not Found\r\n\r\nnope"))
                   buffer)))
              ((symbol-function 'edgar-http--throttle) #'ignore))
      (should-error
       (edgar-dataset-download "https://www.sec.gov/files/y.zip"))
      (should-not
       (file-exists-p
        (edgar-dataset-local-file
         "https://www.sec.gov/files/y.zip"))))))

(ert-deftest edgar-dataset-map-rows-reads-named-columns ()
  (edgar-dataset-test--with-zip zip
    (let (rows)
      (should
       (= 10
          (edgar-dataset-map-rows
           zip "COVERPAGE.tsv"
           (lambda (row)
             (push (list
                    (edgar-dataset-field row "ACCESSION_NUMBER")
                    (edgar-dataset-field row "AMENDMENTTYPE")
                    (edgar-dataset-field row "MISSING"))
                   rows)))))
      (should
       (equal (car (last rows)) '("0000000001-26-000001" nil nil)))
      (should (equal (nth 1 (nth 8 rows)) "NEW HOLDINGS")))
    (should-error (edgar-dataset-map-rows zip "NOPE.tsv" #'ignore))))

(ert-deftest edgar-dataset-cursor-helpers-read-fields ()
  (edgar-dataset-test--with-zip zip
    (let ((edgar-dataset-chunk-size 64)
          rows)
      (should
       (= 15
          (edgar-dataset-map-lines
           zip "INFOTABLE.tsv"
           (lambda (_beg _end)
             (push (list
                    (edgar-dataset-read-digits)
                    (edgar-dataset-read-integer)
                    (edgar-dataset-read-string)
                    (progn
                      (edgar-dataset-skip-fields 1)
                      (edgar-dataset-read-code))
                    (edgar-dataset-read-string)
                    (edgar-dataset-read-integer)
                    (progn
                      (edgar-dataset-skip-fields 2)
                      (edgar-dataset-read-char)))
                   rows)))))
      (should
       (equal
        (nth 5 rows)
        (list
         226000002 10 "YANKEE CO"
         (with-temp-buffer
           (insert "222222222")
           (goto-char (point-min))
           (edgar-dataset-read-code))
         nil 500 ?C)))
      (should
       (equal
        (car rows)
        (list
         426000001 15 "YANKEE CO" (nth 3 (nth 5 rows)) nil 1 nil))))))

(ert-deftest edgar-dataset-codes-fold-case-and-punctuation ()
  (let ((code
         (lambda (text)
           (with-temp-buffer
             (insert text "\tnext")
             (goto-char (point-min))
             (prog1 (edgar-dataset-read-code)
               (should (looking-at "next")))))))
    (should
     (equal (funcall code "67066g104") (funcall code "67066G104")))
    (should
     (equal (funcall code "67066-G10-4") (funcall code "67066G104")))
    (should-not
     (equal (funcall code "067066G10") (funcall code "67066G104")))
    (should (fixnump (funcall code "ZZZZZZZZZ")))
    (should-not (funcall code ""))))

(ert-deftest edgar-dataset-integer-helper-edges ()
  (with-temp-buffer
    (insert "-42\t12.75\t\tabc\n")
    (goto-char (point-min))
    (should (= -42 (edgar-dataset-read-integer)))
    (should (= 12 (edgar-dataset-read-integer)))
    (should-not (edgar-dataset-read-integer))
    (should-not (edgar-dataset-read-digits))
    (should (eolp))))

(ert-deftest edgar-dataset-slices-round-trip ()
  (let* ((directory
          (edgar-dataset-index-directory "test" '("a" "b") 1))
         (file
          (expand-file-name "slices.eld"
                            (make-temp-file "slices-" t)))
         (bounds
          (edgar-dataset-write-slices
           file
           (lambda (emit)
             (funcall emit 'one '(1 "Société Générale" [2 nil]))
             (funcall emit "two" "東京 \"quoted\"\nline")))))
    (should
     (string-match-p "/index/test-[0-9a-f]\\{16\\}/\\'" directory))
    (should-not
     (equal
      directory (edgar-dataset-index-directory "test" '("b" "a") 1)))
    (should
     (equal
      (edgar-dataset-read-object
       file (gethash "two" bounds))
      "東京 \"quoted\"\nline"))
    (should
     (equal
      (edgar-dataset-read-object
       file (gethash 'one bounds))
      '(1 "Société Générale" [2 nil])))
    (edgar-dataset-write-object file (list :a (make-vector 3 'x)))
    (should (equal (edgar-dataset-read-object file) '(:a [x x x])))))

(ert-deftest edgar-dataset-batch-calls-back ()
  (let ((result :pending)
        (failure :pending))
    (edgar-dataset-batch
     '+ '(1 2)
     (lambda (value error) (setq result (or value error))))
    (edgar-dataset-batch
     'car '(not-a-list)
     (lambda (value error) (setq failure (list value error))))
    (let ((deadline (+ (float-time) 120)))
      (while (and (or (eq result :pending) (eq failure :pending))
                  (< (float-time) deadline))
        (accept-process-output nil 0.1)))
    (should (equal result 3))
    (should-not (car failure))
    (should (string-match-p "batch error" (cadr failure)))))

(provide 'edgar-dataset-test)
;;; edgar-dataset-test.el ends here
