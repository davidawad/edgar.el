;;; edgar.el --- Read SEC EDGAR filings -*- lexical-binding: t; -*-

;; Version: 0.1.0
;; URL: https://github.com/davidawad/edgar.el
;; Package-Requires: ((emacs "29.1") (xbrl "0.1.0"))
;; Keywords: finance, tools, hypermedia

;;; Commentary:

;; Navigate EDGAR as a corpus: list a company's filings, open a 10-K in a
;; buffer, and pull out its Items as plain strings so Lisp can use them.
;; Numeric XBRL facts live in the sibling package `xbrl' (xbrl.el).
;;
;;   (edgar-filings "AAPL" "10-K")          ; list of filing plists
;;   (edgar-latest "AAPL" "10-K")           ; newest one
;;   (edgar-section (edgar-latest "AAPL" "10-K") "1A")  ; Risk Factors text
;;
;; Interactive: `edgar-list' (browse filings), `edgar-read' (open latest).
;; Uses `xbrl-user-agent' for the SEC-required User-Agent header.

;;; Code:

(require 'xbrl)
(require 'edgar-forms)
(require 'edgar-http)
(require 'edgar-index)
(require 'shr)
(require 'dom)
(require 'cl-lib)
(require 'subr-x)
(require 'url)

(declare-function edgar-xml "edgar-xml" (filing))
(defvar edgar--part-re)
(defvar edgar--item-re)

(defgroup edgar nil
  "Read and navigate SEC EDGAR filings."
  :group 'applications)

(defcustom edgar-pdftotext-program "pdftotext"
  "Program used to render PDF primary documents as plain text."
  :type 'string
  :group 'edgar)

(defcustom edgar-uudecode-program "uudecode"
  "Program used to decode UUENCODED PDF primary documents."
  :type 'string
  :group 'edgar)

;;;; Transport

(defun edgar--fetch (url)
  "Return the body of URL as a decoded string."
  (edgar-http-get url xbrl-user-agent))

;;;; Filing lists

(defun edgar--date-in-range-p (date since until)
  "Return non-nil when DATE is between SINCE and UNTIL, inclusive."
  (and date
       (or (null since) (not (string< date since)))
       (or (null until) (not (string< until date)))))

(defun edgar--page-in-range-p (page since until)
  "Return non-nil when PAGE may contain filings between SINCE and UNTIL."
  (let ((from (plist-get page :filingFrom))
        (to (plist-get page :filingTo)))
    (and (or (null since) (null to) (not (string< to since)))
         (or (null until) (null from) (not (string< until from))))))

(defun edgar--filings-from-table (table cik form since until)
  "Convert column-oriented TABLE to filing plists for CIK.
Limit results to FORM and the inclusive SINCE and UNTIL filing dates."
  (cl-loop
   for
   accn
   in
   (plist-get table :accessionNumber)
   for
   frm
   in
   (plist-get table :form)
   for
   filed
   in
   (plist-get table :filingDate)
   for
   rep
   in
   (plist-get table :reportDate)
   for
   doc
   in
   (plist-get table :primaryDocument)
   when
   (and (or (null form) (equal frm form))
        (edgar--date-in-range-p filed since until))
   collect
   (list
    :accn accn
    :form frm
    :filed filed
    :report rep
    :doc doc
    :cik cik
    :url
    (format "https://www.sec.gov/Archives/edgar/data/%d/%s/%s"
            cik (replace-regexp-in-string "-" "" accn) doc))))

(defun edgar--unique-filings (filings)
  "Return FILINGS without duplicate accession numbers, preserving order."
  (let ((seen (make-hash-table :test #'equal))
        unique)
    (dolist (filing filings (nreverse unique))
      (let ((accn (plist-get filing :accn)))
        (unless (gethash accn seen)
          (puthash accn t seen)
          (push filing unique))))))

(defun edgar--base-form (form)
  "Return FORM with its optional `/A' amendment suffix removed."
  (string-remove-suffix "/A" form))

(defun edgar--amends-target (amendment originals)
  "Return the original filing amended by AMENDMENT from ORIGINALS, or nil."
  (let* ((base-form (edgar--base-form (plist-get amendment :form)))
         (report (plist-get amendment :report))
         (cik (plist-get amendment :cik))
         (filed (plist-get amendment :filed))
         (matches
          (seq-filter
           (lambda (original)
             (and (equal (plist-get original :form) base-form)
                  (equal (plist-get original :cik) cik)
                  (or (not
                       (and filed (plist-get original :filed)))
                      (not
                       (string< filed (plist-get original :filed))))
                  (or (string-empty-p (or report ""))
                      (equal report (plist-get original :report)))))
           originals)))
    (car
     (sort matches
           (lambda (left right)
             (string<
              (or (plist-get right :filed) "")
              (or (plist-get left :filed) "")))))))

(defun edgar--annotate-amendments (ticker form filings)
  "Add each `/A' entry's original accession in `:amends' to FILINGS.
Only exact `/A' queries are annotated.  TICKER and FORM identify the query."
  (if (not (and (stringp form) (string-suffix-p "/A" form) filings))
      filings
    (let* ((base-form (edgar--base-form form))
           (latest-filed (plist-get (car filings) :filed))
           (originals
            (edgar-filings ticker base-form :until latest-filed)))
      (mapcar
       (lambda (amendment)
         (let ((original (edgar--amends-target amendment originals)))
           (if original
               (plist-put
                (copy-sequence amendment)
                :amends (plist-get original :accn))
             amendment)))
       filings))))

(cl-defun
 edgar-filings (ticker &optional form &key since until)
 "Filings for TICKER as plists, newest first.
Each has :accn :form :filed :report :doc :cik :url.  FORM, if given,
filters on exact form type, e.g. \"10-K\".  SINCE and UNTIL are inclusive
filing-date bounds in YYYY-MM-DD form.  Historical submissions pages are
fetched only when their date range overlaps a supplied bound.  With neither
bound, return the SEC's recent filings only.  Exact `/A' form queries add
:amends with the matched original accession when one is found."
 (when (and since until (string< until since))
   (user-error "SINCE must not be later than UNTIL"))
 (let* ((cik (xbrl-cik ticker))
        (submissions-url "https://data.sec.gov/submissions/")
        (sub (xbrl--get (format "%s%s.json" submissions-url cik)))
        (filings (plist-get sub :filings))
        (recent (plist-get filings :recent))
        (n (string-to-number (substring cik 3)))
        (pages
         (when (or since until)
           (sort (cl-remove-if-not
                  (lambda (page)
                    (edgar--page-in-range-p page since until))
                  (copy-sequence (plist-get filings :files)))
                 (lambda (a b)
                   (string<
                    (or (plist-get b :filingTo) "")
                    (or (plist-get a :filingTo) ""))))))
        (result
         (edgar--filings-from-table recent n form since until)))
   (dolist (page pages)
     (setq result
           (nconc
            result
            (edgar--filings-from-table
             (xbrl--get
              (concat submissions-url (plist-get page :name)))
             n form since until))))
   (edgar--annotate-amendments
    ticker form (edgar--unique-filings result))))

(defun edgar-latest (ticker form)
  "Newest FORM filing for TICKER, or nil."
  (car (edgar-filings ticker form)))

;;;; Content

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

(defun edgar--structure-node (node)
  "Convert libxml NODE to a uniform plist tree without discarding data."
  (cond
   ((stringp node)
    (list :type 'text :text node))
   ((and (consp node) (symbolp (car node)))
    (let* ((attributes (and (listp (cadr node)) (cadr node)))
           (children
            (if (or attributes (null (cadr node)))
                (cddr node)
              (cdr node))))
      (list
       :type 'element
       :name (downcase (symbol-name (car node)))
       :attributes attributes
       :children (mapcar #'edgar--structure-node children))))
   (t
    (list :type 'value :value node))))

(defun edgar--document-primary-metadata
    (filing format &optional primary)
  "Return generic source metadata for FILING and FORMAT.
PRIMARY, when non-nil, is the selected EDGAR submission document record."
  (let* ((url (plist-get filing :url))
         (primary-name
          (or (plist-get primary :name)
              (plist-get filing :doc)
              (and (stringp url)
                   (file-name-nondirectory
                    (url-filename (url-generic-parse-url url)))))))
    (list
     :form (plist-get filing :form)
     :accn (plist-get filing :accn)
     :cik (plist-get filing :cik)
     :filed (plist-get filing :filed)
     :report (plist-get filing :report)
     :url url
     :doc (plist-get filing :doc)
     :primary-document
     (list
      :name primary-name
      :filename primary-name
      :type
      (or (plist-get primary :type) (plist-get filing :form))
      :sequence (plist-get primary :sequence)
      :description (plist-get primary :description)
      :format (or (plist-get primary :format) format)
      :readable (if (plist-member primary :readable)
                    (plist-get primary :readable)
                  (or (not (eq format 'pdf))
                      (executable-find edgar-pdftotext-program)))))))

(defun edgar--document-structure-result
    (filing format children &optional text primary)
  "Build a generic document tree result for FILING and FORMAT."
  (let* ((metadata (edgar--document-primary-metadata filing format primary))
         (result
         (list
          :type 'document
          :format format
          :metadata metadata
          :primary-document (plist-get metadata :primary-document)
          :children children)))
    (when text
      (setq result (plist-put result :text text)))
    result))

(defun edgar--document-structure-from-content
    (filing format content primary)
  "Build FILING's generic tree from CONTENT in FORMAT."
  (pcase format
    ((or 'pdf 'pdf-uuencoded)
       (let* ((text (edgar--pdf-text
                     (edgar--document-pdf-bytes
                      (list :format format :content content))))
            (paragraphs
             (seq-remove
              #'string-empty-p
              (mapcar
               #'string-trim
               (split-string
                text "\\(?:\r?\n\\)[ \t]*\\(?:\r?\n\\)+")))))
       (edgar--document-structure-result
        filing 'pdf
        (mapcar
         (lambda (paragraph)
           (list :type 'paragraph :text paragraph))
         paragraphs)
        text primary)))
    ((or 'html 'xml)
     (with-temp-buffer
       (insert content)
       (edgar--document-structure-result
        filing
        format
        (list
         (edgar--structure-node
          (if (eq format 'xml)
              (libxml-parse-xml-region (point-min) (point-max))
            (libxml-parse-html-region (point-min) (point-max)))))
        nil
        primary)))
    (_
     (let* ((text (edgar--legacy-text content))
            (paragraphs
             (seq-remove
              #'string-empty-p
              (mapcar
               #'string-trim
               (split-string text
                             "\\(?:\r?\n\\)[ \t]*\\(?:\r?\n\\)+")))))
       (edgar--document-structure-result
        filing 'text
        (mapcar
         (lambda (paragraph)
           (list :type 'paragraph :text paragraph))
         paragraphs)
        text primary)))))

(defun edgar-document-structure (filing)
  "Return FILING as a generic, ordered document tree.
The root plist has :format, :metadata, and :children.  :metadata contains
filing identifiers and a :primary-document record with its name, type, format,
and readability.  Each element has :name, :attributes, and ordered :children;
text is retained in leaf plists.  HTML, XML, and text use the same
representation."
  (let ((url (plist-get filing :url)))
    (cond
     ((and (stringp url)
           (string-match-p "\\.xml\\(?:\\?\\|\\'\\)" url))
      (require 'edgar-xml)
      (let ((tree (edgar-xml filing))
            (primary (edgar-primary-document filing)))
        (edgar--document-structure-result
         filing 'xml
         (and tree (list (edgar--structure-node tree)))
         nil primary)))
     ((and (stringp url)
           (string-match-p "\\.pdf\\(?:\\?\\|\\'\\)" url))
      (edgar--document-structure-from-content
       filing 'pdf (edgar-html filing) nil))
     ((and (stringp url)
           (string-match-p "\\.txt\\(?:\\?\\|\\'\\)" url))
      (let* ((submission (edgar--fetch url))
             (primary
              (edgar--submission-primary-info submission filing)))
        (edgar--document-structure-from-content
         filing
         (plist-get primary :format)
         (plist-get primary :content)
         primary)))
     (t
      (let* ((html (edgar-html filing))
             (primary
              (and (edgar--sgml-submission-p html)
                   (edgar--submission-primary-info html filing))))
        (if primary
            (edgar--document-structure-from-content
             filing
             (plist-get primary :format)
             (plist-get primary :content) primary)
          (with-temp-buffer
            (insert html)
            (edgar--document-structure-result
             filing 'html
             (list
              (edgar--structure-node
               (libxml-parse-html-region
                (point-min) (point-max))))))))))))

(defun edgar-structure-text (node)
  "Return all text below NODE in document order."
  (pcase (plist-get node :type)
    ((or 'text 'paragraph) (plist-get node :text))
    ('document
     (or (plist-get node :text)
         (mapconcat #'edgar-structure-text (plist-get node :children)
                    "")))
    ('element
     (mapconcat #'edgar-structure-text (plist-get node :children) ""))
    (_ "")))

(defun edgar-structure-nodes (tree name)
  "Return all elements named NAME in TREE, in document order.
NAME is a tag or XML element name, compared without regard to case."
  (let ((wanted
         (if (symbolp name)
             (symbol-name name)
           name))
        out)
    (cl-labels
     ((walk
       (node)
       (when (and (eq (plist-get node :type) 'element)
                  (equal
                   (downcase (plist-get node :name))
                   (downcase wanted)))
         (push node out))
       (dolist (child (plist-get node :children))
         (walk child))))
     (walk tree))
    (nreverse out)))

(defun edgar-structure-nodes-at-path (tree path)
  "Return elements at PATH in TREE.
PATH is a list of tag names from an element below the document root."
  (let* ((children (plist-get tree :children))
         (root-name
          (and (= (length children) 1)
               (plist-get (car children) :name)))
         (first-name
          (and path
               (if (symbolp (car path))
                   (symbol-name (car path))
                 (car path))))
         (roots
          (if (and (equal (downcase (or root-name "")) "top")
                   (not (equal (downcase (or first-name "")) "top")))
              (plist-get (car children) :children)
            children))
         out)
    (cl-labels
     ((walk
       (nodes rest)
       (when rest
         (dolist (node nodes)
           (when (and (eq (plist-get node :type) 'element)
                      (equal
                       (downcase (plist-get node :name))
                       (downcase
                        (if (symbolp (car rest))
                            (symbol-name (car rest))
                          (car rest)))))
             (if (cdr rest)
                 (walk (plist-get node :children) (cdr rest))
               (push node out)))))))
     (walk roots path))
    (nreverse out)))

(defun edgar-structure-paragraph-nodes (tree-or-section)
  "Return paragraph nodes within TREE-OR-SECTION in document order.
TREE-OR-SECTION may be a document tree, an element node, or a result returned
by `edgar-structure-section' or `edgar-structure-headings'."
  (let* ((scope (or (plist-get tree-or-section :body-node)
                    tree-or-section))
         (elements (edgar-structure-nodes scope "p")))
    (if elements
        elements
      (let (out)
        (cl-labels
         ((walk
           (node)
           (when (eq (plist-get node :type) 'paragraph)
             (push node out))
           (dolist (child (plist-get node :children))
             (walk child))))
         (walk scope))
        (nreverse out)))))

(defun edgar--structure-paragraph-node-ranges (tree)
  "Return (START END NODE) entries for paragraph nodes in text TREE."
  (let ((text (edgar-structure-text tree))
        (offset 0)
        ranges)
    (dolist (node (edgar-structure-paragraph-nodes tree))
      (let ((node-text (edgar-structure-text node)))
        (when (and (stringp node-text)
                   (not (string-empty-p node-text))
                   (string-match (regexp-quote node-text) text offset))
          (let ((start (match-beginning 0))
                (end (match-end 0)))
            (push (list start end node) ranges)
            (setq offset end)))))
    (nreverse ranges)))

(defun edgar--structure-text-section-body-node (tree section)
  "Return a scoped paragraph tree for named text SECTION in TREE."
  (let* ((text (edgar-structure-text tree))
         (start (1- (plist-get section :position)))
         (end (+ start (length (plist-get section :body))))
         (heading-end (or (string-match "\n" text start)
                          (length text)))
         (nodes
          (mapcar
           (lambda (range) (nth 2 range))
           (seq-filter
            (lambda (range)
              (and (> (car range) heading-end)
                   (< (car range) end)))
            (edgar--structure-paragraph-node-ranges tree)))))
    (list :type 'document
          :format (plist-get tree :format)
          :children nodes)))

(defun edgar-structure-paragraphs (tree-or-section)
  "Return paragraph text in TREE-OR-SECTION, in document order.
TREE-OR-SECTION may be a document tree, an element node, or a named-section
result.  HTML/XML p elements are used when present; text and PDF trees use
their paragraph nodes."
  (mapcar #'edgar-structure-text
          (edgar-structure-paragraph-nodes tree-or-section)))

(defun edgar--structure-heading-level (node)
  "Return NODE's semantic heading level, or nil."
  (let ((name (plist-get node :name)))
    (cond
     ((and (eq (plist-get node :type) 'element)
           (string-match "\\`h\\([1-6]\\)\\'" name))
      (string-to-number (match-string 1 name)))
     ((and (equal name "section")
           (assoc 'title (plist-get node :attributes)))
      1)
     ((edgar--structure-heading-paragraph-p node)
      1))))

(defun edgar--structure-heading-paragraph-p (node)
  "Non-nil when paragraph NODE is a visually emphasized standalone heading."
  (when (and (eq (plist-get node :type) 'element)
             (equal (plist-get node :name) "p"))
    (let* ((case-fold-search nil)
           (attributes (plist-get node :attributes))
           (style (or (cdr (assq 'style attributes))
                      (cdr (assoc "style" attributes))
                      ""))
           (text (string-trim (edgar-structure-text node)))
           (emphasized
            (or (string-match-p
                 "font-weight[ \t]*:[ \t]*\\(?:bold\\|[6-9]00\\)"
                 (downcase style))
                (cl-some
                 (lambda (child)
                   (member (plist-get child :name) '("b" "strong")))
                 (plist-get node :children)))))
      (and emphasized
           (<= 3 (length text) 100)
           (string-match-p "[[:upper:]]" text)
           (or (not (string-match-p "[[:lower:]]" text))
               (edgar--title-case-heading-p text))
           (not (string-match-p "[.!?;:]" text))))))

(defun edgar--structure-body-after (siblings level)
  "Text in SIBLINGS following a heading at LEVEL, up to the next peer."
  (let ((done nil)
        chunks)
    (cl-labels
     ((collect
       (node)
       (unless done
         (let ((node-level (edgar--structure-heading-level node))
               (type (plist-get node :type)))
           (if (and node-level (<= node-level level))
               (setq done t)
             (if (memq type '(text paragraph))
                 (push (plist-get node :text) chunks)
               (dolist (child (plist-get node :children))
                 (collect child))))))))
     (dolist (sibling siblings)
       (collect sibling)))
    (mapconcat #'identity (nreverse chunks) "\n")))

(defun edgar--structure-body-node-after (siblings level)
  "Return a document node containing SIBLINGS up to peer heading LEVEL."
  (let ((done nil)
        children)
    (cl-labels
     ((prefix-node
       (node)
       (unless done
         (let ((node-level (edgar--structure-heading-level node))
               (node-children (plist-get node :children)))
           (if (and node-level (<= node-level level))
               (setq done t)
             (if node-children
                 (let ((copy (copy-sequence node))
                       copied-children)
                   (dolist (child node-children)
                     (unless done
                       (let ((copied (prefix-node child)))
                         (when copied
                           (push copied copied-children)))))
                   (plist-put copy :children (nreverse copied-children)))
               node))))))
     (dolist (sibling siblings)
       (unless done
         (let ((copied (prefix-node sibling)))
           (when copied
             (push copied children)))))
     (list :type 'document :children (nreverse children)))))

(defun edgar--structure-heading-walk (node siblings out)
  "Add headings from NODE and descendants to OUT, preserving source order.
SIBLINGS are NODE's sibling nodes; OUT is the accumulator."
  (when (eq (plist-get node :type) 'element)
    (let ((level (edgar--structure-heading-level node)))
      (when level
        (setcar
         out
         (cons
          (list
           :name
           (or (cdr (assoc 'title (plist-get node :attributes)))
               (string-trim (edgar-structure-text node)))
           :level level
           :node node
           :body-node
           (if (equal (plist-get node :name) "section")
               node
             (edgar--structure-body-node-after
              (cdr (memq node siblings)) level))
           :body
           (if (equal (plist-get node :name) "section")
               (edgar-structure-text node)
             (edgar--structure-body-after
              (cdr (memq node siblings)) level)))
          (car out))))))
  (dolist (child (plist-get node :children))
    (edgar--structure-heading-walk
     child (plist-get node :children) out)))

(defun edgar-structure-headings (tree)
  "Return headings in TREE as plists with :name, :level, :node, :body-node, :body.
HTML h1-h6, visually emphasized standalone paragraphs, and elements whose
local name is `section' with a title attribute are recognized generically,
independent of SEC form type.  Text and PDF trees use generic named headings;
:body-node scopes paragraph access to each heading's body."
  (let ((out (list nil))
        stack)
    (dolist (node (plist-get tree :children))
      (edgar--structure-heading-walk
       node (plist-get tree :children) out))
    (or
     (mapcar
      (lambda (heading)
        (let ((level (plist-get heading :level)))
          (while (and stack (>= (caar stack) level))
            (pop stack))
          (push (cons level heading) stack)
          (plist-put
           heading
           :path
           (mapcar
            (lambda (entry)
              (plist-get (cdr entry) :name))
            (reverse stack)))
          heading))
      (nreverse (car out)))
     (when (memq (plist-get tree :format) '(pdf pdf-uuencoded text))
       (mapcar
        (lambda (section)
          (list :name (plist-get section :name)
                :level 1 :node nil :body (plist-get section :body)
                :path (plist-get section :path)
                :body-node
                (edgar--structure-text-section-body-node tree section)))
        (edgar-named-sections (edgar-structure-text tree)))))))

(defun edgar--structure-linked-heading-section (tree name)
  "Return section NAME linked to a fragment target in HTML TREE.
This recognizes generic contents links and named anchors without depending
on SEC form type or filing-specific markup."
  (when (and (eq (plist-get tree :format) 'html) (stringp name))
    (let (links targets paragraphs)
      (with-temp-buffer
        (cl-labels
         ((walk
           (node)
           (pcase (plist-get node :type)
             ('text (insert (plist-get node :text)))
             ('paragraph (insert (plist-get node :text)))
             ('element
              (let* ((attrs (plist-get node :attributes))
                     (href (cdr (or (assq 'href attrs)
                                    (assoc "href" attrs))))
                     (id (cdr (or (assq 'id attrs)
                                  (assoc "id" attrs))))
                     (anchor (cdr (or (assq 'name attrs)
                                      (assoc "name" attrs))))
                     (start (point)))
                (when (and (stringp href)
                           (string-match "\\`#\\(.+\\)\\'" href))
                  (push (list (match-string 1 href)
                              (string-trim (edgar-structure-text node))
                              start)
                        links))
                (when (or id anchor)
                  (push (cons (or id anchor) start) targets))
                (dolist (child (plist-get node :children))
                  (walk child))
                (when (equal (plist-get node :name) "p")
                  (push (list node start (point)) paragraphs)))))))
         (dolist (child (plist-get tree :children))
           (walk child)))
        (let* ((target-ids (delete-dups (mapcar #'car links)))
               (positions
                (sort
                 (delq nil
                       (mapcar
                        (lambda (target)
                          (let ((entry (assoc target targets)))
                            (and entry (cons target (cdr entry)))))
                        target-ids))
                 (lambda (a b) (< (cdr a) (cdr b)))))
               (wanted
                (downcase
                 (string-trim
                  (edgar--normalize-section-whitespace name))))
               (matches
                (delete-dups
                 (mapcar #'car
                         (seq-filter
                          (lambda (link)
                            (and (member (car link) target-ids)
                                 (equal wanted
                                        (downcase
                                         (edgar--normalize-section-whitespace
                                          (cadr link))))))
                          links)))))
          (when (= (length matches) 1)
            (let* ((target (car matches))
                   (position (cdr (assoc target positions)))
                   (toc-targets
                    (mapcar #'car
                            (seq-filter
                             (lambda (link) (< (nth 2 link) position))
                             links)))
                   (next
                    (seq-find
                     (lambda (entry)
                       (and (> (cdr entry) position)
                            (member (car entry) toc-targets)))
                     positions))
                   (body-end (or (and next (cdr next)) (point-max)))
                   (body-paragraphs
                    (mapcar
                     #'car
                     (seq-filter
                      (lambda (entry)
                        (and (> (nth 2 entry) position)
                             (< (nth 1 entry) body-end)
                             (not
                              (equal
                               wanted
                               (downcase
                                (edgar--normalize-section-whitespace
                                 (string-trim
                                  (edgar-structure-text (car entry)))))))))
                      (nreverse paragraphs))))
                   (node
                    (seq-find
                     (lambda (candidate)
                       (let ((attrs (plist-get candidate :attributes)))
                         (equal target
                                (cdr (or (assq 'id attrs)
                                         (assq 'name attrs))))))
                     (edgar-structure-nodes tree "a"))))
              (list :name name :node node
                    :body (buffer-substring-no-properties
                           position body-end)
                    :body-node
                    (list :type 'document :format 'html
                          :children body-paragraphs)))))))))

(defun edgar-structure-section (tree name)
  "Return the unique named section or element NAME from TREE.
HTML semantic headings are matched by visible name, XML elements by element
name, and text/PDF headings by generic named-heading recognition.  NAME may be
a full path.  Return a plist with :name, :node, :body, and :body-node; pass the
 result or its :body-node to `edgar-structure-paragraph-nodes' or
 `edgar-structure-paragraphs' to query paragraphs within that section.
Signal `user-error' if multiple matches exist; return nil if absent."
  (let* ((path-p (listp name))
         (wanted-path
          (and path-p
               (mapcar
                (lambda (part)
                  (downcase
                   (string-trim
                    (edgar--normalize-section-whitespace
                     (if (symbolp part)
                         (symbol-name part)
                       part)))))
                name)))
         (wanted-name
          (and (not path-p)
               (downcase
                (string-trim
                 (edgar--normalize-section-whitespace name)))))
         (headings (edgar-structure-headings tree))
         (heading-hits
          (seq-filter
           (lambda (heading)
             (if path-p
                 (equal
                  wanted-path
                  (mapcar
                   (lambda (part)
                     (downcase (string-trim part)))
                   (plist-get heading :path)))
               (equal
                wanted-name
                (downcase
                 (string-trim
                  (edgar--normalize-section-whitespace
                   (plist-get heading :name)))))))
           headings))
         (nodes
          (if path-p
              (edgar-structure-nodes-at-path tree name)
            (edgar-structure-nodes tree name)))
         (node-hits
          (mapcar
           (lambda (node)
             (list
              :name (plist-get node :name)
              :level 0
              :node node
              :body-node node
              :path
              (or wanted-path (list wanted-name))
              :body (edgar-structure-text node)))
           nodes))
         (linked-hit (and (null heading-hits)
                          (edgar--structure-linked-heading-section tree name)))
         (hits (append heading-hits node-hits
                       (and linked-hit (list linked-hit)))))
    (pcase hits
      (`() nil)
      (`(,hit) hit)
      (_ (user-error "Section %s is ambiguous" name)))))

(defun edgar--title-case-heading-p (line)
  "Return non-nil if LINE resembles a standalone title-case heading."
  (let ((case-fold-search nil)
        (words (split-string line "[ \t]+" t))
        (small-words
         '("a"
           "an"
           "and"
           "as"
           "at"
           "by"
           "due"
           "for"
           "from"
           "in"
           "into"
           "of"
           "on"
           "or"
           "the"
           "to"
           "with"))
        has-capitalized-word)
    (and
     (<= 3 (length line) 100)
     (not (string-match-p "[.!?;]" line))
     ;; Table labels such as "Call Feature:" are not section headings.
     (not (string-suffix-p ":" line))
     (seq-every-p
      (lambda (word)
        (cond
         ((member (downcase word) small-words)
          t)
         ((string-match-p "\\`[[:upper:]]" word)
          (setq has-capitalized-word t))
         (t
          nil)))
      words)
     has-capitalized-word)))

(defun edgar--normalize-section-whitespace (text)
  "Normalize Unicode spacing characters in section names and headings."
  (replace-regexp-in-string
   "[\u00a0\u2000-\u200b\u202f\u205f\u3000]" " " text))

(defun edgar--title-case-section (text name)
  "Return exact title-case NAME in TEXT when it lacks blank-line spacing."
  (let ((normalized (edgar--normalize-section-whitespace text))
        positions)
    (with-temp-buffer
      (insert normalized)
      (goto-char (point-min))
      (while (not (eobp))
        (let ((line
               (string-trim
                (buffer-substring-no-properties
                 (line-beginning-position) (line-end-position)))))
          (when (and (string-equal (downcase line) (downcase name))
                     (edgar--title-case-heading-p line))
            (push (line-beginning-position) positions)))
        (forward-line 1)))
    (when positions
      (when (cdr positions)
        (user-error "Named section %s is ambiguous" name))
      (let* ((start (car positions))
             (next
              (seq-some
               (lambda (section)
                 (and (> (plist-get section :position) start)
                      (plist-get section :position)))
               (edgar-named-sections normalized))))
        (substring normalized
                   (1- start)
                   (1- (or next (1+ (length normalized)))))))))

(defun edgar-named-sections (text)
  "Return generic named section headings found in TEXT.
Each result is a plist with :name, :path, :body, and :position.  This
form-agnostic fallback recognizes standalone uppercase or title-case headings;
callers needing every source node should use `edgar-document-structure'."
  (let ((case-fold-search nil)
        marks)
    (with-temp-buffer
      (insert (edgar--normalize-section-whitespace text))
      (goto-char (point-min))
      (while (not (eobp))
        (let* ((start (line-beginning-position))
               (line
                (string-trim
                 (buffer-substring-no-properties
                  start (line-end-position))))
               (before-blank
                (or (= start (point-min))
                    (save-excursion
                      (forward-line -1)
                      (string-blank-p
                       (buffer-substring-no-properties
                        (line-beginning-position)
                        (line-end-position))))))
               (after-blank
                (save-excursion
                  (forward-line 1)
                  (or (eobp)
                      (string-blank-p
                       (buffer-substring-no-properties
                        (line-beginning-position)
                        (line-end-position))))))
               (named-p
                (and (or (and (<= 3 (length line) 100)
                              (string-match-p "[A-Z]" line)
                              (not (string-match-p "[a-z]" line)))
                         (edgar--title-case-heading-p line))
                     (not
                      (string-match-p
                       "\\`\\(?:ITEM\\|PART\\)\\_>" (upcase line)))
                     (or before-blank after-blank)))
               (boundary-p
                (or named-p
                    (save-excursion
                      (goto-char start)
                      (or (looking-at edgar--item-re)
                          (looking-at edgar--part-re))))))
          (when boundary-p
            (push (cons start (and named-p line)) marks)))
        (forward-line 1)))
    (setq marks (nreverse marks))
    (cl-loop
     for
     mark
     in
     marks
     for
     next
     =
     (cadr (member mark marks))
     for
     start
     =
     (car mark)
     for
     end
     =
     (or (car next) (1+ (length text)))
     for
     name
     =
     (cdr mark)
     when
     name
     collect
     (list
      :name name
      :path (list name)
      :position start
      :body (substring text (1- start) (1- end))))))

(defun edgar--item-title (body)
  "Return the printed title from an Item-section BODY, or nil."
  (when
      (string-match
       "^[ \t ]*\\(?:Item\\|ITEM\\)[ \t ]+[0-9]+\\(?:\\.[0-9]+\\)?[A-C]?\\(?:[.:][ \t ]*\\|[ \t ]+\\)\\(.+?\\)[ \t ]*$"
       body)
    (string-trim (match-string 1 body))))

(defconst edgar--part-re
  (concat
   "^[ \t\u00a0\u2000-\u200a]*\\(?:PART\\|Part\\)[ \t\u00a0\u2000-\u200a]+\\(IV\\|I\\{1,3\\}\\)"
   "\\(?:[ \t ]*$"
   "\\|[ \t ]*[.:—–\u0096\u0097-].\\{0,60\\}$"
   "\\|[ \t ]+[A-Z][A-Za-z ,&'’ -]\\{0,60\\}$\\)")
  "Match a Part heading line; group 1 is the Roman numeral.
A bare title after the numeral (\"PART I  FINANCIAL INFORMATION\") counts;
cross-references like \"Part I, Item 1A\" do not.")

(defconst edgar--item-re
  (concat
   "^[ \t\u00a0\u2000-\u200a]*\\(?:Item\\|ITEM\\)[ \t\u00a0\u2000-\u200a]+"
   "\\([0-9]+\\(?:\\.[0-9]+\\)?[A-C]?\\)"
   "\\(?:[.:]\\|[ \t ]*[—–\u0096\u0097-]\\|[ \t ]+[A-Z]\\|[ \t ]*$\\)")
  "Match an Item heading line; group 1 is the item number, e.g. 1A or 2.02.
Matched case-sensitively: a wrapped cross-reference such as \"Item 1A of
this report\" starts with lowercase and is not a heading.")

(defconst edgar--roman '(("I" . 1) ("II" . 2) ("III" . 3) ("IV" . 4)))

(defun edgar--matches (re text &optional reject)
  "Return (LINE-START . LABEL) for each match of RE in TEXT, in order.
Lines that also match the regexp REJECT are skipped."
  (with-temp-buffer
    (insert text)
    (goto-char (point-min))
    (let ((case-fold-search nil)
          out)
      (while (re-search-forward re nil t)
        (unless (and reject
                     (string-match-p
                      reject
                      (buffer-substring
                       (line-beginning-position)
                       (line-end-position))))
          (push (cons
                 (line-beginning-position) (upcase (match-string 1)))
                out)))
      (nreverse out))))

(defun edgar--runs (marks)
  "Keep only the first of consecutive entries that share a label.
MARKS is a list of (POSITION . LABEL).  Some filers repeat a running
header such as \"PART I\" or \"Item 1\" on every page;
those must not split the section they sit inside."
  (let (out)
    (dolist (m marks)
      (unless (equal (cdr m) (cdr (car out)))
        (push m out)))
    (nreverse out)))

(defun edgar--part-at (parts pos)
  "Roman numeral of the last Part heading in PARTS before POS, or nil."
  (cdr
   (car (last (seq-take-while (lambda (p) (< (car p) pos)) parts)))))

(defun edgar--key (item part)
  "Section key for ITEM within PART: \"II.1A\", or just \"1A\" with no PART."
  (if part
      (concat part "." item)
    item))

(defun edgar--split-key (key)
  "Return (PART-NUMBER . ITEM) for KEY; PART-NUMBER is 0 when KEY has no Part."
  (if (string-match "\\`\\(IV\\|I\\{1,3\\}\\)\\.\\(.+\\)\\'" key)
      (cons
       (cdr (assoc (match-string 1 key) edgar--roman))
       (match-string 2 key))
    (cons 0 key)))

(defun edgar--item< (a b)
  "Return non-nil if Item label A precedes B, numerically then by letter."
  (let ((na (string-to-number a))
        (nb (string-to-number b)))
    (or (< na nb) (and (= na nb) (string< a b)))))

(defun edgar--key< (a b)
  "Return non-nil if section key A precedes B (by Part, then by Item)."
  (let ((ka (edgar--split-key a))
        (kb (edgar--split-key b)))
    (or (< (car ka) (car kb))
        (and (= (car ka) (car kb))
             (edgar--item< (cdr ka) (cdr kb))))))

(defun edgar-sections (text)
  "Alist of (KEY . BODY) for the Items in filing TEXT, in filing order.
KEY is the item number (\"1A\", \"2.02\"), prefixed with the Part when the
filing has Parts: \"I.2\" and \"II.2\" are different sections of a 10-Q.
Forms without Item headings give nil.  The table of contents repeats every
heading with no body, so for each key the occurrence with the longest body
wins."
  (let* ((parse-text (edgar--normalize-section-whitespace text))
         (parts
          (edgar--runs
           (edgar--matches edgar--part-re parse-text "\\bItems?\\b")))
         (items
          (edgar--runs
           (mapcar
            (lambda (it)
              (cons
               (car it)
               (edgar--key (cdr it) (edgar--part-at parts (car it)))))
            (edgar--matches edgar--item-re parse-text))))
         (bounds (sort (mapcar #'car (append parts items)) #'<))
         (best (make-hash-table :test 'equal)))
    (dolist (it items)
      (let* ((start (car it))
             (end
              (or (seq-find (lambda (b) (> b start)) bounds)
                  (1+ (length text))))
             (key (cdr it))
             (body
              (string-trim-right
               (substring text (1- start) (1- end))
               "[\r\n]+"))
             (old (gethash key best)))
        (when (or (null old) (> (length body) (length old)))
          (puthash key body best))))
    (let (out)
      (maphash (lambda (k v) (push (cons k v) out)) best)
      (edgar--drop-residue
       (sort out (lambda (a b) (edgar--key< (car a) (car b))))))))

(defun edgar--heading-only-p (body)
  "Non-nil if BODY contains only a possibly wrapped Item heading.
Table-of-contents entries can wrap onto several lines and include a page
number at the end of any line."
  (let*
      ((lines
        (seq-remove #'string-blank-p (split-string body "\n")))
       (first (car lines))
       (rest
        (and
         first
         (string-match
          "\\`[ \t\u00a0\u2000-\u200a]*\\(?:Item\\|ITEM\\)[ \t\u00a0\u2000-\u200a]+[0-9.]+[A-C]?[.:]?[ \t\u00a0\u2000-\u200a]*\\(.*\\)"
          first)
         (cons (match-string 1 first) (cdr lines))))
       (title-lines
        (mapcar
         (lambda (line)
           (string-trim
            (replace-regexp-in-string
             "[ \t\u00a0]+[0-9]+[ \t\u00a0]*\\'" "" line)))
         rest)))
    (and title-lines
         (<= (length (mapconcat #'identity title-lines " ")) 250)
         (seq-every-p
          (lambda (line)
            (let ((line (string-remove-suffix "." line)))
              (edgar--title-case-heading-p line)))
          title-lines))))

(defun edgar--drop-residue (secs)
  "Remove from SECS the heading-only entries that duplicate another Part's item.
A 20-F table of contents without Part headings, for instance, leaves a
bare \"I.13\" next to the real \"II.13\".  An entry with no Part at all is
residue too when the same item exists under a Part: the table of contents
precedes the first Part heading, even when a wrapped line makes an entry
longer than a lone heading."
  (seq-remove
   (lambda (e)
     (and (or (edgar--heading-only-p (cdr e))
              (= 0 (car (edgar--split-key (car e)))))
          (seq-some
           (lambda (o)
             (and (not (eq o e))
                  (equal
                   (cdr (edgar--split-key (car o)))
                   (cdr (edgar--split-key (car e))))))
           secs)))
   secs))

(defun edgar-section (filing item)
  "Text of ITEM or named section from FILING.
Numeric Item keys such as \"1A\", \"7\", \"2.02\" and \"II.1\" retain
their existing behavior.  A named Item title or generic heading is also
accepted.  Ambiguous Item numbers or headings signal `user-error'; absent
names return nil.  ITEM may be a list path to disambiguate a structural
section.  For arbitrary data elements, use `edgar-document-structure' and
`edgar-structure-section'."
  (let ((url (plist-get filing :url)))
    (if (and (stringp url)
             (or (consp item)
                 (string-match-p "\\.xml\\(?:\\?\\|\\'\\)" url)))
        (let ((section
               (edgar-structure-section
                (edgar-document-structure filing) item)))
          (and section (plist-get section :body)))
      (let* ((text (edgar-text filing))
             (secs (edgar-sections text))
             (want (upcase item))
             (exact (assoc want secs)))
        (if exact
            (cdr exact)
          (let ((hits
                 (seq-filter
                  (lambda (s)
                    (string-match-p
                     (concat
                      "\\`\\(?:IV\\|I\\{1,3\\}\\)\\."
                      (regexp-quote want)
                      "\\'")
                     (car s)))
                  secs)))
            (cond
             ((null hits)
              (let ((item-hits
                     (seq-filter
                      (lambda (section)
                        (let ((title
                               (edgar--item-title (cdr section))))
                          (and title
                               (string-equal
                                (string-trim item) title))))
                      secs))
                    (named-hits
                     (seq-filter
                      (lambda (section)
                        (string-prefix-p
                         (downcase (string-trim item))
                         (downcase (plist-get section :name))))
                      (edgar-named-sections text))))
                (cond
                 ((cdr item-hits)
                  (user-error
                   "Section %s is ambiguous; use an Item key"
                   item))
                 (item-hits
                  (cdr (car item-hits)))
                 (named-hits
                  (plist-get
                   (car
                    (sort named-hits
                          (lambda (a b)
                            (> (length (plist-get a :body))
                               (length (plist-get b :body))))))
                   :body))
                 ((edgar--title-case-section text item))
                 ((not (stringp (plist-get filing :url)))
                  nil)
                 (t
                  (let ((section
                         (edgar-structure-section
                          (edgar-document-structure filing) item)))
                    (and section (plist-get section :body)))))))
             ((null (cdr hits))
              (cdr (car hits)))
             (t
              (user-error "Item %s is ambiguous; use one of %s"
                          want
                          (mapconcat #'car hits ", "))))))))))

(defun edgar-effective-section (ticker form key)
  "Return KEY from TICKER's latest FORM, applying the latest matching `/A'.
If no amendment to the latest original contains KEY, return its original
section.  KEY follows `edgar-section' (for example, \"III.10\")."
  (let* ((base-form (edgar--base-form form))
         (originals
          (sort (edgar-filings ticker base-form)
                #'(lambda (left right)
                    (string<
                     (or (plist-get right :filed) "")
                     (or (plist-get left :filed) "")))))
         (original (car originals))
         (original-accn (plist-get original :accn))
         (original-report (plist-get original :report))
         (amendments
          (sort (edgar-filings ticker (concat base-form "/A"))
                #'(lambda (left right)
                    (string<
                     (or (plist-get right :filed) "")
                     (or (plist-get left :filed) "")))))
         (related
          (seq-filter
           (lambda (amendment)
             (or (and original-accn
                      (equal
                       (plist-get amendment :amends) original-accn))
                 (and original-accn
                      (not (string-empty-p (or original-report "")))
                      (equal
                       (plist-get
                        amendment
                        :report)
                       original-report))))
           amendments))
         effective)
    (catch 'found
      (dolist (amendment related)
        (let ((section (edgar-section amendment key)))
          (when section
            (setq effective section)
            (throw 'found section)))))
    (or effective (and original (edgar-section original key)))))

(defun edgar-text-diff (before after)
  "Return a unified diff from text string BEFORE to text string AFTER.
Return an empty string when the texts are equal."
  (let ((before-file (make-temp-file "edgar-before-"))
        (after-file (make-temp-file "edgar-after-")))
    (unwind-protect
        (progn
          (with-temp-file before-file
            (set-buffer-file-coding-system 'utf-8-unix)
            (insert before))
          (with-temp-file after-file
            (set-buffer-file-coding-system 'utf-8-unix)
            (insert after))
          (with-temp-buffer
            (let ((status
                   (call-process "diff"
                                 nil
                                 t
                                 nil
                                 "-u"
                                 "-L"
                                 "before"
                                 before-file
                                 "-L"
                                 "after"
                                 after-file)))
              (unless (memq status '(0 1))
                (error "diff failed with status %s" status))
              (buffer-string))))
      (delete-file before-file)
      (delete-file after-file))))

;;;; Interactive

(defvar-local edgar--filing nil)

(define-derived-mode
 edgar-list-mode
 tabulated-list-mode
 "EDGAR"
 "Browse EDGAR filings.  RET opens the filing at point."
 (define-key edgar-list-mode-map (kbd "RET") #'edgar-list-open))

(defun edgar-list-open ()
  "Open the filing at point."
  (interactive)
  (edgar-open (tabulated-list-get-id)))

;;;###autoload
(defun edgar-list (ticker &optional form)
  "List TICKER's filings (optionally only FORM) in a browsable buffer."
  (interactive (list
                (xbrl--read-ticker)
                (let ((f (read-string "Form (blank = all): ")))
                  (unless (string-empty-p f)
                    f))))
  (let ((rows (edgar-filings ticker form)))
    (with-current-buffer (get-buffer-create
                          (format "*edgar: %s*" (upcase ticker)))
      (edgar-list-mode)
      (setq tabulated-list-format
            [("Filed" 12 t)
             ("Form" 8 t)
             ("Period" 12 t)
             ("Accession" 22 t)]
            tabulated-list-entries
            (mapcar
             (lambda (f)
               (list
                f
                (vector
                 (plist-get f :filed)
                 (plist-get f :form)
                 (or (plist-get f :report) "")
                 (plist-get f :accn))))
             rows))
      (tabulated-list-init-header)
      (tabulated-list-print)
      (pop-to-buffer (current-buffer)))))

(defun edgar-open (filing)
  "Render FILING in a read-only buffer."
  (let ((buf
         (get-buffer-create
          (format "*edgar: %s*" (plist-get filing :accn)))))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (edgar-text filing))
        (goto-char (point-min)))
      (special-mode)
      (setq edgar--filing filing))
    (pop-to-buffer buf)))

;;;###autoload
(defun edgar-read (ticker form)
  "Open the latest FORM filing for TICKER."
  (interactive (list
                (xbrl--read-ticker)
                (completing-read
                 "Form: " '("10-K" "10-Q" "8-K" "DEF 14A")
                 nil nil "10-K")))
  (edgar-open
   (or (edgar-latest ticker form)
       (user-error "No %s for %s" form ticker))))

(provide 'edgar)
;;; edgar.el ends here
