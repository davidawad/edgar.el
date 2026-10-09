;;; edgar-content.el --- Filing content access for edgar.el -*- lexical-binding: t; -*-

;; Package-Requires: ((emacs "29.1") (xbrl "0.1.0"))

;;; Commentary:

;; Filing content access for edgar.el.
;; Part of `edgar'; see edgar.el for the overview.

;;; Code:

(require 'edgar-core)
(require 'shr)
(require 'dom)
(require 'cl-lib)
(require 'subr-x)

(declare-function edgar-xml--raw-url "edgar-xml" (url))

(defun edgar-html (filing)
  "Raw body of FILING's primary document.
PDF bodies are returned as unibyte strings."
  (edgar--fetch (plist-get filing :url)))

(defun edgar-facts (filing)
  "Return FILING's Inline XBRL facts, including context and unit metadata.
Non-iXBRL filings return nil."
  (xbrl-inline-facts (edgar-html filing)))

(defun edgar--submission-documents (submission)
  "Return the DOCUMENT bodies in SGML SUBMISSION, in source order."
  (let (documents)
    (with-temp-buffer
      (insert submission)
      (goto-char (point-min))
      (while (search-forward "<DOCUMENT>" nil t)
        (let ((start (point)))
          (when (search-forward "</DOCUMENT>" nil t)
            (push (buffer-substring-no-properties
                   start (match-beginning 0))
                  documents)))))
    (nreverse documents)))

(defun edgar--submission-document-tag (document tag)
  "Return the header value for TAG in SGML DOCUMENT, or nil."
  (let* ((case-fold-search t)
         (text-start (string-match "<TEXT>" document))
         (header
          (substring document 0 (or text-start (length document))))
         (pattern (format "<%s>[ \t]*\\([^\r\n]+\\)" tag)))
    (when (string-match pattern header)
      (string-trim (match-string 1 header)))))

(defun edgar--source-format (name content)
  "Return a generic source format for NAME and CONTENT."
  (let ((case-fold-search t)
        (prefix
         (downcase (substring content 0 (min 100 (length content))))))
    (cond
     ((or (string-prefix-p "<pdf>" (string-trim-left prefix))
          (string-prefix-p "begin 644 " (string-trim-left prefix)))
      'pdf-uuencoded)
     ((or (and name (string-match-p "\\.pdf\\'" name))
          (string-prefix-p "%pdf-" (string-trim-left prefix)))
      'pdf)
     ((or (and name (string-match-p "\\.xml\\'" name))
          (string-prefix-p "<?xml" (string-trim-left prefix)))
      'xml)
     ((or (and name (string-match-p "\\.html?\\'" name))
          (string-match-p
           "\\`[ \t\r\n]*\\(?:<!doctype html\\|<html\\)" prefix))
      'html)
     (t
      'text))))

(defun edgar--pdf-text (pdf)
  "Render unibyte PDF body PDF as text with `edgar-pdftotext-program'."
  (let ((program (executable-find edgar-pdftotext-program))
        (output (generate-new-buffer " *edgar-pdftotext*")))
    (unless program
      (kill-buffer output)
      (user-error "PDF filing requires the %s program"
                  edgar-pdftotext-program))
    (unwind-protect
        (with-temp-buffer
          (set-buffer-multibyte nil)
          (insert pdf)
          (let ((coding-system-for-read 'utf-8-unix)
                (coding-system-for-write 'no-conversion))
            (let ((status
                   (call-process-region
                    (point-min) (point-max) program
                    nil output nil "-layout" "-" "-")))
              (unless (and (integerp status) (zerop status))
                (error "%s failed with status %s" program status))))
          (with-current-buffer output
            (buffer-string)))
      (when (buffer-live-p output)
        (kill-buffer output)))))

(defun edgar--uuencoded-pdf-normalize (content)
  "Restore SEC-trimmed row padding in UUENCODED PDF CONTENT."
  (let ((started nil) (finished nil) lines)
    (dolist (line (split-string content "\r?\n" nil))
      (cond
       ((and (not started) (string-match-p "\\`begin [0-7]+ " line))
        (setq started t) (push line lines))
       ((and started (equal line "end"))
        (setq finished t) (push line lines))
       ((and started (not finished) (string-empty-p line))
        (push "`" lines))
       ((and started (not finished))
        (let* ((count (logand (- (aref line 0) 32) 63))
               (expected (+ 1 (* 4 (/ (+ count 2) 3)))))
          (push (concat line (make-string (max 0 (- expected (length line))) ?\s))
                lines)))
       (t (push line lines))))
    (unless (and started finished)
      (error "EDGAR: malformed UUENCODED PDF primary document"))
    (mapconcat #'identity (nreverse lines) "\n")))

(defun edgar--uuencoded-pdf-bytes (content)
  "Decode UUENCODED PDF CONTENT into unibyte bytes."
  (let ((program (executable-find edgar-uudecode-program))
        (output (generate-new-buffer " *edgar-uudecode*")))
    (unless program
      (kill-buffer output)
      (user-error "PDF submission requires the %s program" edgar-uudecode-program))
    (with-current-buffer output (set-buffer-multibyte nil))
    (unwind-protect
        (with-temp-buffer
          (insert (edgar--uuencoded-pdf-normalize content))
          (let ((coding-system-for-read 'no-conversion)
                (coding-system-for-write 'no-conversion))
            (let ((status (call-process-region
                           (point-min) (point-max) program nil output nil "-p")))
              (unless (and (integerp status) (zerop status))
                (error "%s failed with status %s" edgar-uudecode-program status))))
          (with-current-buffer output (buffer-string)))
      (when (buffer-live-p output) (kill-buffer output)))))

(defun edgar--document-pdf-bytes (document)
  "Return DOCUMENT's PDF bytes, decoding SEC uuencoded bodies as needed."
  (let ((content (plist-get document :content)))
    (if (eq (plist-get document :format) 'pdf-uuencoded)
        (edgar--uuencoded-pdf-bytes content)
      content)))

(defun edgar--submission-primary-info (submission filing)
  "Return generic metadata and content for FILING's primary document."
  (let* ((case-fold-search t)
         (form (edgar--base-form (or (plist-get filing :form) "")))
         (documents (edgar--submission-documents submission))
         (primary
          (or (seq-find
               (lambda (document)
                 (equal
                  form
                  (edgar--base-form
                   (or
                    (edgar--submission-document-tag document "TYPE")
                    ""))))
               documents)
              (car documents))))
    (if (null primary)
        (list
         :type form
         :sequence nil
         :name (plist-get filing :doc)
         :description nil
         :format
         (edgar--source-format (plist-get filing :doc) submission)
         :content submission)
      (let* ((name
              (edgar--submission-document-tag primary "FILENAME"))
             (text-start (string-match "<TEXT>[ \t\r\n]*" primary))
             (content-start (and text-start (match-end 0)))
             (content-end
              (and content-start
                   (string-match "</TEXT>" primary content-start)))
             (content
              (if content-start
                  (substring primary
                             content-start
                             (or content-end (length primary)))
                primary)))
        (list
         :type
         (or (edgar--submission-document-tag primary "TYPE") form)
         :sequence (edgar--submission-document-tag primary "SEQUENCE")
         :name name
         :description
         (edgar--submission-document-tag primary "DESCRIPTION")
         :format (edgar--source-format name content)
         :content (string-trim content))))))

(defun edgar--submission-primary-document (submission filing)
  "Return FILING's primary content from EDGAR SGML SUBMISSION."
  (plist-get
   (edgar--submission-primary-info submission filing)
   :content))

(defun edgar--primary-document-metadata (document)
  "Return DOCUMENT metadata without its raw content."
  (list :type (plist-get document :type)
        :sequence (plist-get document :sequence)
        :filename (or (plist-get document :filename)
                      (plist-get document :name))
        :description (plist-get document :description)
        :format (plist-get document :format)))

(defun edgar-primary-document (filing)
  "Return FILING's generic primary-document metadata and raw content.
Metadata includes :type, :sequence, :filename, :description, and :format."
  (let* ((url (plist-get filing :url))
         (source-url
          (if (and (stringp url)
                   (string-match-p "\\.xml\\(?:\\?\\|\\'\\)" url))
              (progn
                (require 'edgar-xml)
                (or (edgar-xml--raw-url url) url))
            url))
         (source (edgar--fetch source-url))
         (submission
          (or (and (stringp url)
                   (string-match-p "\\.txt\\(?:\\?\\|\\'\\)" url))
              (edgar--sgml-submission-p source)))
         (document
          (if submission
              (edgar--submission-primary-info source filing)
            (list :type (plist-get filing :form)
                  :sequence nil
                  :name (or (plist-get filing :doc)
                            (and (stringp url)
                                 (file-name-nondirectory url)))
                  :description nil
                  :format (edgar--source-format
                           (plist-get filing :doc) source)
                  :content source))))
    (append (edgar--primary-document-metadata document)
            (list :content (plist-get document :content)))))

(defun edgar--sgml-submission-p (content)
  "Return non-nil when CONTENT begins with an EDGAR SGML document wrapper."
  (and (stringp content)
       (string-match-p "\\`[ \t\r\n]*<DOCUMENT>" content)))

(defun edgar--legacy-text (text)
  "Render old SEC SGML TEXT to readable text, preserving line boundaries."
  (if (string-match-p "<[Hh][Tt][Mm][Ll]\\(?:[ \t\r\n/>]\\)" text)
      (with-temp-buffer
        (insert text)
        (let ((dom
               (libxml-parse-html-region (point-min) (point-max))))
          (erase-buffer)
          (let ((shr-inhibit-images t)
                (shr-use-fonts nil)
                (shr-width 100))
            (shr-insert-document dom)))
        (buffer-substring-no-properties (point-min) (point-max)))
    (let ((plain
           (replace-regexp-in-string
            "</?\\(?:PAGE\\|TABLE\\|CAPTION\\|S\\|C\\)>" "\n" text
            t)))
      (replace-regexp-in-string
       "\\n[ \t]*\\n[ \t]*\\n+" "\n\n" plain))))

(defun edgar-text (filing)
  "FILING rendered to plain text (what `shr' would display)."
  (let* ((url (plist-get filing :url))
         (pdf-url-p
          (and (stringp url)
               (string-match-p "\\.pdf\\(?:\\?\\|\\'\\)" url)))
         (source (edgar-html filing))
         (submission-p
          (or (and (stringp url)
                   (string-match-p "\\.txt\\(?:\\?\\|\\'\\)" url))
              (edgar--sgml-submission-p source)))
         (primary
          (and submission-p
               (edgar--submission-primary-info source filing)))
         (format
          (if primary
              (plist-get primary :format)
            (cond
             (pdf-url-p 'pdf)
             ((and (stringp url)
                   (string-match-p "\\.txt\\(?:\\?\\|\\'\\)" url))
              'text)
             (t 'html))))
         (text (if primary (plist-get primary :content) source)))
    (when (memq format '(pdf pdf-uuencoded))
      (setq text (edgar--pdf-text
                  (edgar--document-pdf-bytes
                   (list :format format :content text)))
            format 'text))
    (if (eq format 'text)
        (edgar--legacy-text text)
      (with-temp-buffer
        (insert text)
        (let ((dom
               (libxml-parse-html-region (point-min) (point-max))))
          (erase-buffer)
          (let ((shr-inhibit-images t)
                (shr-use-fonts nil)
                (shr-width 100))
            (shr-insert-document dom)))
        (buffer-substring-no-properties (point-min) (point-max))))))

(provide 'edgar-content)
;;; edgar-content.el ends here
