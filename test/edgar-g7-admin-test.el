;;; edgar-g7-admin-test.el --- G7 administrative filing coverage -*- lexical-binding: t; -*-

;;; Commentary:

;; Offline generic-reader regressions for real F-10/F-6 family, F-X, EFFECT,
;; AW, and RW primary documents.

;;; Code:

(require 'ert)
(require 'seq)
(require 'edgar)
(require 'edgar-fixtures)
(require 'edgar-forms)

(defconst edgar-g7-admin-test--fixtures
  '("index-f-10-2026-q2"
    "index-f-10ef-2026-q2"
    "index-f-10pos-2026-q2"
    "index-f-6-2026-q2"
    "index-f-6-pos-2026-q2"
    "index-f-6ef-2026-q2"
    "index-f-x-2026-q2"
    "index-effect-2026-q2"
    "index-aw-2026-q2"
    "index-rw-2026-q2")
  "Recorded G7 administrative filing fixtures.")

(defun edgar-g7-admin-test--primary-file (slug)
  "Return SLUG's recorded primary document file."
  (or (seq-find
       #'file-exists-p
       (mapcar
        (lambda (extension)
          (edgar-fixtures-path (concat "fixtures/" slug extension)))
        '(".htm.gz" ".xml")))
      (error "No primary document fixture for %s" slug)))

(defun edgar-g7-admin-test--primary (slug)
  "Return SLUG's primary document contents."
  (let ((file (edgar-g7-admin-test--primary-file slug)))
    (with-temp-buffer
      (let ((coding-system-for-read 'utf-8)
            (auto-compression-mode t))
        (insert-file-contents file))
      (buffer-string))))

(defun edgar-g7-admin-test--snapshot (filing text tree)
  "Return a whole-text and generic-document snapshot for FILING."
  (let* ((structure-text (edgar-structure-text tree))
         (normalized (edgar-fixtures-norm text))
         (root (car (plist-get tree :children))))
    (list
     :form (plist-get filing :form)
     :format (plist-get tree :format)
     :primary-document (plist-get tree :primary-document)
     :text-length (length text)
     :text-sha256 (secure-hash 'sha256 text)
     :text-head (substring normalized 0 (min 120 (length normalized)))
     :structure-text-length (length structure-text)
     :root-name (plist-get root :name)
     :root-child-names
     (mapcar
      (lambda (node) (plist-get node :name))
      (seq-take (seq-filter
                 (lambda (node)
                   (eq (plist-get node :type) 'element))
                 (plist-get root :children))
                8))
     :paragraph-count (length (edgar-structure-paragraphs tree))
     :heading-names
     (mapcar
      (lambda (heading) (plist-get heading :name))
      (seq-take (edgar-structure-headings tree) 5))
     :tag-counts
     (mapcar
      (lambda (name)
        (cons name (length (edgar-structure-nodes tree name))))
      '("html" "body" "p" "table" "h1" "h2" "h3")))))

(defun edgar-g7-admin-test--check (slug)
  "Check real source, generic readability, structure, and snapshot for SLUG."
  (let* ((filing (edgar-fixtures-filing slug))
         (source (edgar-g7-admin-test--primary slug))
         (expected
          (unless (getenv "EDGAR_G7_ADMIN_EXPECT_UPDATE")
            (edgar-fixtures-read
             (edgar-fixtures-path (concat "expect/" slug ".eld")))))
         (url (plist-get filing :url))
         (form (plist-get filing :form))
         (backend (plist-get (edgar-form-info form) :backend))
         text
         tree
         snapshot)
    (should
     (string-match-p
      "\\`https://www\\.sec\\.gov/Archives/edgar/data/[0-9]+/[0-9]+/"
      url))
    (should (equal (plist-get filing :sample-quarter) "2026-Q2"))
    (should (eq (plist-get (edgar-form-info form) :level) 'L1))
    (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) source)))
      (setq text (edgar-text filing))
      (setq tree (edgar-document-structure filing)))
    (should (stringp text))
    (should-not (string-empty-p (string-trim text)))
    (should (eq (plist-get tree :format) backend))
    (let* ((root (car (plist-get tree :children)))
           (root-name (plist-get root :name))
           (section (edgar-structure-section tree root-name)))
      (should (stringp (plist-get section :body)))
      (should-not
       (string-empty-p (string-trim (plist-get section :body)))))
    (setq snapshot (edgar-g7-admin-test--snapshot filing text tree))
    (if (getenv "EDGAR_G7_ADMIN_EXPECT_UPDATE")
        (with-temp-file (edgar-fixtures-path
                         (concat "expect/" slug ".eld"))
          (let ((print-length nil)
                (print-level nil))
            (pp snapshot (current-buffer))))
      (should (equal snapshot expected)))))

(ert-deftest edgar-g7-admin-real-primary-fixtures-read-generically ()
  "All assigned G7 administrative primary sources are generically readable."
  (dolist (slug edgar-g7-admin-test--fixtures)
    (edgar-g7-admin-test--check slug)))

(ert-deftest edgar-g7-admin-assigned-registry-rows-have-l1-fixtures ()
  "The assigned ten registered rows have L1 and matching source fixtures."
  (let ((forms
         '("F-10"
           "F-10EF"
           "F-10POS"
           "F-6"
           "F-6 POS"
           "F-6EF"
           "F-X"
           "EFFECT"
           "AW"
           "RW")))
    (should (= (length forms) (length edgar-g7-admin-test--fixtures)))
    (dolist (form forms)
      (let* ((info (edgar-form-info form))
             (slug
              (concat
               "index-"
               (downcase
                (replace-regexp-in-string "[^A-Za-z0-9]+" "-" form))
               "-2026-q2")))
        (should (eq (plist-get info :level) 'L1))
        (should
         (file-exists-p (edgar-g7-admin-test--primary-file slug)))
        (when (not (getenv "EDGAR_G7_ADMIN_EXPECT_UPDATE"))
          (should
           (file-exists-p
            (edgar-fixtures-path
             (concat "expect/" slug ".eld")))))))))

(provide 'edgar-g7-admin-test)
;;; edgar-g7-admin-test.el ends here
