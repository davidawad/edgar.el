;;; edgar-structure.el --- Generic document structure trees for edgar.el -*- lexical-binding: t; -*-

;; Package-Requires: ((emacs "29.1") (xbrl "0.1.0"))

;;; Commentary:

;; Generic document structure trees for edgar.el.
;; Part of `edgar'; see edgar.el for the overview.

;;; Code:

(require 'edgar-core)
(require 'edgar-content)
(require 'dom)
(require 'cl-lib)
(require 'subr-x)

(declare-function edgar-xml "edgar-xml" (filing))

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

(provide 'edgar-structure)
;;; edgar-structure.el ends here
