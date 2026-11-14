(require 'url)
(require 'url-http)
(let* ((url-request-extra-headers
        '(("User-Agent" . "David Awad david@awad.esq")
          ("Accept-Encoding" . "gzip")))
       (buffer
        (url-retrieve-synchronously
         "https://www.sec.gov/Archives/edgar/data/2131524/000135445726000761/BRVE_8A_Cert_2131524.pdf"
         t t 60)))
  (with-current-buffer buffer
    (let ((header-end
           (save-excursion
             (goto-char (point-min))
             (re-search-forward "\n\n" nil t)
             (point))))
      (princ
       (format "multibyte=%S coding=%S process=%S end=%S\n"
               (multibyte-string-p (buffer-string))
               buffer-file-coding-system
               (and (get-buffer-process buffer)
                    (process-coding-system (get-buffer-process buffer)))
               header-end))
      (princ
       (format "head=%S\n"
               (buffer-substring-no-properties
                (point-min) (min (point-max) (+ (point-min) 300)))))
      (when header-end
        (princ
         (format "body-codes=%S\n"
                 (mapcar #'identity
                         (string-to-list
                          (buffer-substring-no-properties
                           header-end (+ header-end 12))))))))
    (kill-buffer buffer)))
