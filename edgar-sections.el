;;; edgar-sections.el --- Item and Part section extraction for edgar.el -*- lexical-binding: t; -*-

;; Package-Requires: ((emacs "29.1") (xbrl "0.1.0"))

;;; Commentary:

;; Item and Part section extraction for edgar.el.
;; Part of `edgar'; see edgar.el for the overview.

;;; Code:

(require 'edgar-core)
(require 'edgar-content)
(require 'edgar-structure)
(require 'edgar-headings)
(require 'edgar-named)
(require 'cl-lib)
(require 'subr-x)

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

(provide 'edgar-sections)
;;; edgar-sections.el ends here
