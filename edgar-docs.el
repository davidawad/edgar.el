;;; edgar-docs.el --- Read filing documents and exhibits -*- lexical-binding: t; -*-

;; Version: 0.1.0
;; Keywords: finance, tools, hypermedia

;;; Commentary:

;; List and read the exhibits filed alongside an EDGAR filing.
;;
;;   (edgar-documents filing)          ; document plists
;;   (edgar-exhibit filing "EX-99.1") ; exhibit text
;;   (edgar-sections (edgar-exhibit filing "EX-99.1"))
;;
;; Document plists contain :name, :type, :description, :size, and :url.
;; The SEC directory JSON has no exhibit labels or descriptions, so :type is
;; the inferred exhibit label (when recognizable) or file extension, and
;; :description is the SEC filename.

;;; Code:

(require 'edgar)
(require 'json)
(require 'subr-x)

(defun edgar-docs--base-url (filing)
  "Return the SEC filing directory URL for FILING."
  (let ((url (plist-get filing :url)))
    (unless (and (stringp url)
                 (string-match "\\`\\(.*\\)/[^/]+\\'" url))
      (error "EDGAR: filing has no valid :url"))
    (match-string 1 url)))

(defun edgar-docs--exhibit-type (name)
  "Infer an exhibit type from document NAME, or return its extension."
  (let ((case-fold-search t))
    (or (and (string-match "exhibit\\([0-9][0-9]\\)\\([0-9]\\)" name)
             (format "EX-%s.%s"
                     (match-string 1 name)
                     (match-string 2 name)))
        (and (string-match
              "ex[-_]?\\([0-9][0-9]?[a-z]?\\)[-_.]?\\([0-9]+\\)?"
              name)
             (format "EX-%s%s"
                     (match-string 1 name)
                     (if (match-string 2 name)
                         (concat "." (match-string 2 name))
                       "")))
        (and (string-match "\\.\\([^.]+\\)\\'" name)
             (upcase (match-string 1 name))))))

(defun edgar-documents (filing)
  "Return document plists listed for FILING by its SEC directory index.
Each plist has :name, :type, :description, :size, and :url."
  (let* ((base (edgar-docs--base-url filing))
         (data
          (json-parse-string (edgar--fetch
                              (concat base "/index.json"))
                             :object-type 'alist
                             :array-type 'list))
         (items (alist-get 'item (alist-get 'directory data))))
    (mapcar
     (lambda (item)
       (let ((name (alist-get 'name item)))
         (list
          :name name
          :type (edgar-docs--exhibit-type name)
          :description name
          :size
          (let ((size (alist-get 'size item)))
            (and (stringp size)
                 (not (string-empty-p size))
                 (string-to-number size)))
          :url (concat base "/" name))))
     items)))

(defun edgar-exhibit (filing exhibit-type)
  "Return plain text for EXHIBIT-TYPE attached to FILING.
EXHIBIT-TYPE is a label such as \"EX-99.1\".  Signal an error if no
matching document is present.  Pass the returned string to
`edgar-sections' to extract any Item headings."
  (let* ((doc
          (cl-find-if
           (lambda (item)
             (equal (upcase exhibit-type) (plist-get item :type)))
           (edgar-documents filing))))
    (unless doc
      (error "EDGAR: %s not found in filing" exhibit-type))
    (edgar-text
     (plist-put (copy-sequence filing) :url (plist-get doc :url)))))

(provide 'edgar-docs)
;;; edgar-docs.el ends here
