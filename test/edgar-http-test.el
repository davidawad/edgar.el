;;; edgar-http-test.el --- Tests for EDGAR HTTP transport -*- lexical-binding: t; -*-

;;; Code:

(require 'ert)
(require 'edgar-http)

(defun edgar-http-test--response (status body &optional headers)
  "Return a response buffer with STATUS, BODY, and HEADERS."
  (let ((buffer (generate-new-buffer " *edgar-http-test*")))
    (with-current-buffer buffer
      (set-buffer-multibyte nil)
      (insert (format "HTTP/1.1 %s Test\r\n" status))
      (dolist (header headers)
        (insert (format "%s: %s\r\n" (car header) (cdr header))))
      (insert "\r\n" body))
    buffer))

(ert-deftest edgar-http-throttles-a-burst-of-50-requests ()
  (let ((now 0.0)
        (starts nil)
        (edgar-http--last-request-time nil)
        (edgar-http-requests-per-second 10)
        (edgar-http-cache-directory
         (make-temp-file "edgar-http-cache" t)))
    (unwind-protect
        (cl-letf (((symbol-function 'float-time)
                   (lambda (&optional _) now))
                  ((symbol-function 'sleep-for)
                   (lambda (seconds &optional _)
                     (setq now (+ now seconds))))
                  ((symbol-function 'url-retrieve-synchronously)
                   (lambda (&rest _)
                     (push now starts)
                     (edgar-http-test--response 200 "ok"))))
          (dotimes (i 50)
            (edgar-http-get (format "https://example.invalid/%s" i)))
          (let ((ordered (nreverse starts)))
            (should (= (length ordered) 50))
            (cl-loop
             for
             a
             in
             ordered
             for
             b
             in
             (cdr ordered)
             do
             (should (>= (- b a) 0.1)))))
      (delete-directory edgar-http-cache-directory t))))

(ert-deftest edgar-http-caches-archive-document-only ()
  (let ((edgar-http-cache-directory
         (make-temp-file "edgar-http-cache" t))
        (calls 0)
        (edgar-http--last-request-time nil))
    (unwind-protect
        (cl-letf (((symbol-function 'url-retrieve-synchronously)
                   (lambda (&rest _)
                     (setq calls (1+ calls))
                     (edgar-http-test--response 200 "filing"))))
          (let ((url
                 "https://www.sec.gov/Archives/edgar/data/1/a.htm"))
            (should (equal (edgar-http-get url) "filing"))
            (should (equal (edgar-http-get url) "filing"))
            (should (= calls 1)))
          (dotimes (_ 2)
            (edgar-http-get
             "https://data.sec.gov/submissions/CIK1.json"))
          (should (= calls 3)))
      (delete-directory edgar-http-cache-directory t))))

(ert-deftest edgar-http-retries-and-honours-retry-after ()
  (let ((calls 0)
        (delays nil)
        (edgar-http--last-request-time nil)
        (edgar-http-max-retries 2))
    (cl-letf (((symbol-function 'sleep-for)
               (lambda (seconds &optional _) (push seconds delays)))
              ((symbol-function 'url-retrieve-synchronously)
               (lambda (&rest _)
                 (setq calls (1+ calls))
                 (if (= calls 1)
                     (edgar-http-test--response 429 "slow"
                                                '(("Retry-After"
                                                   .
                                                   "3")))
                   (edgar-http-test--response 200 "ok")))))
      (should
       (equal (edgar-http-get "https://example.invalid/data") "ok"))
      (should (= calls 2))
      (should (memq 3 delays)))))

(ert-deftest edgar-http-sends-gzip-acceptance ()
  (let ((edgar-http--last-request-time nil)
        (accepted nil))
    (cl-letf (((symbol-function 'url-retrieve-synchronously)
               (lambda (&rest _)
                 (setq accepted
                       (assoc-string
                        "Accept-Encoding" url-request-extra-headers
                        t))
                 (edgar-http-test--response 200 "ok"))))
      (edgar-http-get "https://example.invalid/data")
      (should (equal (cdr accepted) "gzip")))))

(ert-deftest edgar-http-decompresses-gzip-response ()
  (let ((edgar-http--last-request-time nil)
        (payload
         (base64-decode-string
          "H4sIAAAAAAAC/0vOzy0oSi0uTk1RSMvMycxLBwAV67rDEQAAAA==")))
    (cl-letf (((symbol-function 'url-retrieve-synchronously)
               (lambda (&rest _)
                 (edgar-http-test--response 200 payload
                                            '(("Content-Encoding"
                                               .
                                               "gzip"))))))
      (should
       (equal
        (edgar-http-get "https://example.invalid/gzip")
        "compressed filing")))))

(provide 'edgar-http-test)
;;; edgar-http-test.el ends here
