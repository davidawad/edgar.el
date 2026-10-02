;;; edgar-expect-test.el --- expect tests over recorded SEC filings -*- lexical-binding: t; -*-

;; One test per recorded filing in test/fixtures/ (see tools/record-fixtures.el).
;; Each replays the filing through `edgar-text' / `edgar-sections' offline and
;; compares a compact snapshot against test/expect/<slug>.eld.  A snapshot is
;; deliberately coarse -- section keys, log2 length buckets and the first words
;; of each body -- so it survives `shr' rendering drift but catches real
;; regressions (lost sections, merged Parts, wrong boundaries).
;;
;; Expectations are reviewed, not generated blindly: after an intended change,
;; run with EDGAR_EXPECT_UPDATE=1, then read `git diff test/expect/'.

(require 'ert)
(require 'cl-lib)
(require 'subr-x)
(require 'edgar)

(defconst edgar-expect--dir
  (file-name-directory (or load-file-name buffer-file-name)))

(defun edgar-expect--file (slug ext)
  "Path of SLUG's fixture (EXT \".eld\" / \".htm.gz\") or expectation."
  (expand-file-name (concat "fixtures/" slug ext) edgar-expect--dir))

(defun edgar-expect--expect-file (slug)
  "Path of SLUG's committed expectation."
  (expand-file-name (concat "expect/" slug ".eld") edgar-expect--dir))

(defun edgar-expect--slugs ()
  "Slugs of every rendered filing fixture."
  (seq-filter
   (lambda (slug)
     (file-exists-p (edgar-expect--file slug ".htm.gz")))
   (mapcar
    #'file-name-sans-extension
    (directory-files (expand-file-name "fixtures" edgar-expect--dir)
                     nil "\\.eld\\'"))))

(defun edgar-expect--read (file)
  "Read the Lisp object in FILE."
  (with-temp-buffer
    (insert-file-contents file)
    (read (current-buffer))))

(defun edgar-expect--html (slug)
  "Decompressed HTML of SLUG's fixture."
  (with-temp-buffer
    (let ((coding-system-for-read 'utf-8)
          (auto-compression-mode t))
      (insert-file-contents (edgar-expect--file slug ".htm.gz")))
    (buffer-string)))

(defun edgar-expect--bucket (n)
  "Log2 bucket of N."
  (if (< n 1)
      0
    (floor (log n 2))))

(defun edgar-expect--head (s n)
  "First N chars of S with whitespace collapsed."
  (let ((c
         (string-trim
          (replace-regexp-in-string "[ \t\n\u00a0]+" " " s))))
    (substring c 0 (min n (length c)))))

(defun edgar-expect--snapshot (filing text)
  "Coarse, render-stable summary of FILING's TEXT and sections."
  (list
   :form (plist-get filing :form)
   :text-bucket (edgar-expect--bucket (length text))
   :text-head (edgar-expect--head text 60)
   :sections
   (mapcar
    (lambda (s)
      (list
       (car s)
       (edgar-expect--bucket (length (cdr s)))
       (edgar-expect--head (cdr s) 50)))
    (edgar-sections text))))

;; Per-form facts that must hold whatever the snapshot says: a banner phrase
;; the rendered text must contain, and section keys that must be found.
(defconst edgar-expect--invariants
  '(("10-K" "annual report" ("I.1" "I.1A" "II.7" "II.8"))
    ("10-K/A" "amendment" nil)
    ("10-Q" "quarterly report" ("I.1" "I.2"))
    ("8-K" "current report" nil)
    ("20-F" "annual report" nil)
    ("40-F" "annual report" nil)
    ("6-K" "report of foreign private issuer" nil)
    ("S-1" "registration statement" nil)
    ("DEF 14A" "proxy statement" nil)
    ("11-K" "annual report" nil)
    ("4" "statement of changes in beneficial ownership" nil)
    ("13F-HR" "form 13f" nil)
    ("SCHEDULE 13G" "schedule 13g" nil)
    ("SC 13G" "schedule 13g" nil)
    ("SC 13G/A" "schedule 13g" nil)
    ("144" "notice of proposed sale" nil)))

(defun edgar-expect--check (slug)
  "Replay fixture SLUG and compare against its expectation."
  (let* ((filing
          (edgar-expect--read (edgar-expect--file slug ".eld")))
         (html (edgar-expect--html slug))
         (inv
          (assoc (plist-get filing :form) edgar-expect--invariants))
         text
         snap)
    (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) html)))
      (setq text (edgar-text filing)))
    (setq snap (edgar-expect--snapshot filing text))
    (should inv)
    (should
     (string-match-p
      "\\`https://www.sec.gov/Archives/edgar/data/[0-9]+/[0-9]+/"
      (plist-get filing :url)))
    (should
     (string-match-p
      (nth 1 inv)
      (replace-regexp-in-string "[ \t\n ]+" " " (downcase text))))
    (dolist (key (nth 2 inv))
      (should (assoc key (plist-get snap :sections))))
    (let ((file (edgar-expect--expect-file slug)))
      (cond
       ((getenv "EDGAR_EXPECT_UPDATE")
        (make-directory (file-name-directory file) t)
        (with-temp-file file
          (let ((print-length nil)
                (print-level nil))
            (pp snap (current-buffer)))))
       ((not (file-exists-p file))
        (ert-fail
         (format
          "No expectation for %s; run with EDGAR_EXPECT_UPDATE=1"
          slug)))
       (t
        (should (equal snap (edgar-expect--read file))))))))

(dolist (slug (edgar-expect--slugs))
  (let ((name (intern (concat "edgar-expect-" slug))))
    (ert-set-test
     name
     (make-ert-test
      :name name
      :body
      (let ((s slug))
        (lambda () (edgar-expect--check s)))))))

(provide 'edgar-expect-test)
;;; edgar-expect-test.el ends here
