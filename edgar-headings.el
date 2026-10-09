;;; edgar-headings.el --- Heading detection and structure sections for edgar.el -*- lexical-binding: t; -*-

;; Package-Requires: ((emacs "29.1") (xbrl "0.1.0"))

;;; Commentary:

;; Heading detection and structure sections for edgar.el.
;; Part of `edgar'; see edgar.el for the overview.

;;; Code:

(require 'edgar-core)
(require 'edgar-structure)
(require 'edgar-named)
(require 'dom)
(require 'cl-lib)
(require 'subr-x)

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

(provide 'edgar-headings)
;;; edgar-headings.el ends here
