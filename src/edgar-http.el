;;; edgar-http.el --- Throttled HTTP transport -*- lexical-binding: t; -*-

;;; Commentary:

;; Synchronous HTTP transport for SEC resources.  Archive documents are
;; cached by URL; metadata endpoints are always fetched again.

;;; Code:

(require 'url)
(require 'url-parse)
(require 'url-http)
(require 'url-util)
(require 'cl-lib)
(require 'subr-x)

(defgroup edgar-http nil
  "Throttled HTTP transport for EDGAR packages."
  :group 'url)

(defcustom edgar-http-cache-directory
  (expand-file-name "edgar-http-cache/" user-emacs-directory)
  "Directory used for cached SEC archive documents."
  :type 'directory
  :group 'edgar-http)

(defcustom edgar-http-requests-per-second 10
  "Maximum request rate for the shared SEC transport."
  :type 'number
  :group 'edgar-http)

(defcustom edgar-http-max-retries 3
  "Number of retries after retryable HTTP responses."
  :type 'integer
  :group 'edgar-http)

(defvar edgar-http--last-request-time nil
  "Time at which the preceding uncached request was started.")

(defun edgar-http--archive-document-p (url)
  "Return non-nil when URL identifies an immutable archive document."
  (let ((path (url-filename (url-generic-parse-url url))))
    (and (string-match-p "/Archives/edgar/data/" path)
         (not
          (member
           (file-name-nondirectory path)
           '("index.json" "index.htm" "index.html"))))))

(defun edgar-http--cache-file (url)
  "Return the cache filename for URL."
  (expand-file-name (concat (secure-hash 'sha256 url) ".html")
                    edgar-http-cache-directory))

(defun edgar-http--throttle ()
  "Wait as needed to respect `edgar-http-requests-per-second'."
  (let* ((interval
          (+ (/ 1.0 edgar-http-requests-per-second) 0.000001))
         (now (float-time))
         (wait
          (and edgar-http--last-request-time
               (- interval (- now edgar-http--last-request-time)))))
    (when (and wait (> wait 0))
      (sleep-for wait))
    (setq edgar-http--last-request-time (float-time))))

(defun edgar-http--retry-delay (headers attempt)
  "Return retry delay from HEADERS or exponential delay for ATTEMPT."
  (let ((retry-after
         (and headers (cdr (assoc-string "Retry-After" headers t)))))
    (or (and retry-after
             (if (string-match-p
                  "\\`[0-9]+\\(?:\\.[0-9]+\\)?\\'" retry-after)
                 (string-to-number retry-after)
               (let ((date
                      (ignore-errors
                        (date-to-time retry-after))))
                 (and date
                      (max 0 (- (float-time date) (float-time)))))))
        (expt 2 attempt))))

(defun edgar-http--response ()
  "Return (STATUS HEADERS BODY) for the current URL response buffer."
  (goto-char (point-min))
  (unless (looking-at "HTTP/[0-9.]+ \\([0-9]+\\)")
    (error "EDGAR HTTP: malformed response status"))
  (let ((status (string-to-number (match-string 1)))
        (headers nil))
    (forward-line 1)
    (while (and (not (eobp)) (not (looking-at "\r?$")))
      (when (looking-at "\\([^:]+\\):[ \t]*\\(.*\\)$")
        (push (cons
               (match-string-no-properties 1)
               (string-trim (match-string-no-properties 2)))
              headers))
      (forward-line 1))
    (goto-char (point-min))
    (unless (or (search-forward "\r\n\r\n" nil t)
                (search-forward "\n\n" nil t))
      (error "EDGAR HTTP: missing response body"))
    (let ((body (buffer-substring-no-properties (point) (point-max))))
      (when (equal
             (cdr (assoc-string "Content-Encoding" headers t)) "gzip")
        (with-temp-buffer
          (set-buffer-multibyte nil)
          (insert body)
          (zlib-decompress-region (point-min) (point-max))
          (setq body (buffer-string))))
      (list status headers (decode-coding-string body 'utf-8)))))

(defun edgar-http-get (url &optional user-agent)
  "Return URL's decoded body, using USER-AGENT for the request.
Requests are globally throttled.  HTTP 429 and 5xx responses are retried
with bounded exponential backoff, respecting a valid Retry-After header.
Successful immutable SEC archive documents are cached by URL.  Other
endpoints are never cached."
  (let* ((cacheable (edgar-http--archive-document-p url))
         (cache-file (and cacheable (edgar-http--cache-file url))))
    (or (and cache-file
             (file-readable-p cache-file)
             (with-temp-buffer
               (insert-file-contents cache-file)
               (buffer-string)))
        (let ((attempt 0)
              (body nil)
              (done nil))
          (while (not done)
            (edgar-http--throttle)
            (let* ((url-request-extra-headers
                    `(("User-Agent" . ,user-agent)
                      ("Accept-Encoding" . "gzip")))
                   (buffer (url-retrieve-synchronously url t t 60)))
              (unless buffer
                (error "EDGAR HTTP: no response from %s" url))
              (unwind-protect
                  (with-current-buffer buffer
                    (pcase-let ((`(,status ,headers ,response-body)
                                 (edgar-http--response)))
                      (cond
                       ((and (>= status 200) (< status 300))
                        (setq
                         body response-body
                         done t))
                       ((and (< attempt edgar-http-max-retries)
                             (or (= status 429)
                                 (and (>= status 500)
                                      (< status 600))))
                        (sleep-for
                         (edgar-http--retry-delay headers attempt))
                        (setq attempt (1+ attempt)))
                       (t
                        (error
                         "EDGAR HTTP: %s -> HTTP %s" url status)))))
                (when (buffer-live-p buffer)
                  (kill-buffer buffer)))))
          (when cache-file
            (make-directory edgar-http-cache-directory t)
            (with-temp-file cache-file
              (insert body)))
          body))))

(provide 'edgar-http)
;;; edgar-http.el ends here
