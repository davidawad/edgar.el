;;; edgar-xml.el --- Read structured SEC filing XML -*- lexical-binding: t; -*-

;; Copyright (C) 2026

;; Author: David Awad
;; Keywords: finance, tools

;;; Commentary:

;; Parse the raw XML behind SEC XSL-rendered filing documents.  This module
;; returns the libxml tree and provides a small namespace-insensitive alist
;; projector; it does not impose form-specific interpretations.

;;; Code:

(require 'edgar)
(require 'seq)
(require 'subr-x)

(defun edgar-xml--raw-url (url)
  "Return the raw XML URL corresponding to XSL-rendered XML URL, or nil.
If URL does not name an XML document, return nil."
  (when (and (stringp url)
             (string-match-p "\\.xml\\(?:\\?\\|\\'\\)" url))
    (replace-regexp-in-string "/xsl[^/]+/" "/" url)))

(defun edgar-xml (filing)
  "Return the parsed XML tree for FILING, or nil if its primary doc is not XML.
For XSL-rendered XML filings, fetch the underlying raw XML document.  The
returned tree uses the representation produced by `libxml-parse-xml-region'."
  (let ((url (edgar-xml--raw-url (plist-get filing :url))))
    (when url
      (let ((xml (edgar--fetch url)))
        (with-temp-buffer
          (insert xml)
          (libxml-parse-xml-region (point-min) (point-max)))))))

(defun edgar-xml--local-name (name)
  "Return the namespace-independent local part of XML element NAME."
  (let ((string
         (if (symbolp name)
             (symbol-name name)
           name)))
    (intern (car (last (split-string string ":" t))))))

(defun edgar-xml--children (node)
  "Return the element children of XML NODE, ignoring text and comments."
  (seq-filter
   (lambda (part) (and (consp part) (symbolp (car part))))
   (cdr node)))

(defun edgar-xml--project-value (node)
  "Project XML NODE to a string or an alist of its child elements."
  (let ((children (edgar-xml--children node)))
    (if children
        (mapcar
         (lambda (child)
           (cons
            (edgar-xml--local-name (car child))
            (edgar-xml--project-value child)))
         children)
      (string-trim
       (mapconcat (lambda (part)
                    (if (stringp part)
                        part
                      ""))
                  (cdr node)
                  "")))))

(defun edgar-xml-project (tree)
  "Project XML TREE to a namespace-insensitive alist.
Element names are symbols, text-only elements become strings, and repeated
element names remain separate alist entries in document order."
  (unless (consp tree)
    (signal 'wrong-type-argument (list 'consp tree)))
  (cons
   (edgar-xml--local-name (car tree))
   (edgar-xml--project-value tree)))

(provide 'edgar-xml)
;;; edgar-xml.el ends here
