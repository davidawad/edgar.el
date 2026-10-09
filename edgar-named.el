;;; edgar-named.el --- Named-section extraction for edgar.el -*- lexical-binding: t; -*-

;; Package-Requires: ((emacs "29.1") (xbrl "0.1.0"))

;;; Commentary:

;; Named-section extraction for edgar.el.
;; Part of `edgar'; see edgar.el for the overview.

;;; Code:

(require 'edgar-core)
(require 'cl-lib)
(require 'subr-x)

(defvar edgar--part-re)
(defvar edgar--item-re)

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

(provide 'edgar-named)
;;; edgar-named.el ends here
