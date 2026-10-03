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
  "Path of SLUG's fixture with EXT or expectation."
  (expand-file-name (concat "fixtures/" slug ext) edgar-expect--dir))

(defun edgar-expect--primary-file (slug)
  "Path of SLUG's rendered primary fixture."
  (or (seq-find
       #'file-exists-p
       (mapcar
        (lambda (ext) (edgar-expect--file slug ext))
        '(".htm.gz" ".pdf")))
      (error "No rendered primary fixture for %s" slug)))

(defun edgar-expect--expect-file (slug)
  "Path of SLUG's committed expectation."
  (expand-file-name (concat "expect/" slug ".eld") edgar-expect--dir))

(defun edgar-expect--slugs ()
  "Slugs of every rendered filing fixture."
  (seq-filter
   (lambda (slug)
     (seq-some
      (lambda (ext) (file-exists-p (edgar-expect--file slug ext)))
      '(".htm.gz" ".pdf")))
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
  (edgar-expect--primary slug))

(defun edgar-expect--primary (slug)
  "Primary body of SLUG's fixture, preserving PDF bytes."
  (with-temp-buffer
    (let ((file (edgar-expect--primary-file slug)))
      (if (string-suffix-p ".pdf" file t)
          (progn
            (set-buffer-multibyte nil)
            (insert-file-contents-literally file))
        (let ((coding-system-for-read 'utf-8)
              (auto-compression-mode t))
          (insert-file-contents file))))
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
    ("10-D" "asset backed issuer" nil)
    ("8-K" "current report" nil)
    ("ABS-15G" "asset-backed securitizer report" nil)
    ("20-F" "annual report" nil)
    ("40-F" "annual report" nil)
    ("6-K" "report of foreign private issuer" nil)
    ("40-17G" "1290 funds 40-17g" nil)
    ("40-APP" "application for an order" nil)
    ("40-17F1" "northern lights fund trust" nil)
    ("40-6B" "robinhood" nil)
    ("485APOS"
     "post-effective amendment"
     ("28" "29" "30" "31" "32" "33" "34" "35"))
    ("486APOS" "post-effective amendment" nil)
    ("486BPOS" "form n-2" nil)
    ("485BPOS" "form n-1a" nil)
    ("485BXT" "form n-1a" nil)
    ("497" "supplement" nil)
    ("497AD" "powerlaw" nil)
    ("497J" "certification of no change" nil)
    ("497K" "summary prospectus" nil)
    ("497VPI" "income benefit supplement" nil)
    ("497VPU" "updating summary prospectus" nil)
    ("497VPSUB" "voya" nil)
    ("N-1A" "registration statement" nil)
    ("N-14" "nomura" nil)
    ("N-2" "form n-2" nil)
    ("487" "advisors disciplined trust 2360" nil)
    ("N-4" "form n-4" nil)
    ("N-6" "form n-6" nil)
    ("S-6" "form s-6" nil)
    ("S-3" "form s-3" nil)
    ("S-4" "registration statement" nil)
    ("424B2" "pricing supplement" nil)
    ("F-1" "registration statement" nil)
    ("424B3" "prospectus" nil)
    ("424B4" "prospectus" nil)
    ("424B5" "prospectus" nil)
    ("424B7" "watsco" nil)
    ("424B8" "nomura" nil)
    ("8-A12B" "amazon.com, inc." ("1" "2"))
    ("F-3" "registration statement" nil)
    ("S-8" "veralto" nil)
    ("S-8 POS" "exxonmobil holdings corp" ("II.3" "II.8"))
    ("FWP" "hsbc" nil)
    ("S-1" "registration statement" nil)
    ("10-KT" "keemo fashion" ("I.1" "I.1A"))
    ("8-K12B" "nova minerals" nil)
    ("QRTLYRPT" "african development bank" nil)
    ("SD" "specialized disclosure report" nil)
    ("15-12G" "apogee therapeutics" nil)
    ("NT 10-K" "digital brand media" nil)
    ("NT 10-Q" "digital brand media" nil)
    ("NT 11-K" "ori 401" nil)
    ("NT 20-F" "telekomunikasi" nil)
    ("18-K" "form 18-k" nil)
    ("25" "walmart inc" nil)
    ("40FR12B" "nuran wireless" nil)
    ("DEFA14A" "pra group, inc." nil)
    ("DEFA14C" "notice of internet availability" nil)
    ("DEFM14C" "schedule 14c information" nil)
    ("DEFR14C" "amendment no. 1" nil)
    ("POS 8C" "form n-2" nil)
    ("PREM14C" "schedule 14c information" nil)
    ("PREN14A" "preliminary proxy statement" nil)
    ("PRER14C" "schedule 14c information/amendment" nil)
    ("SC 14N" "schedule 14n" nil)
    ("DEF 14A" "proxy statement" nil)
    ("DEF 14C" "definitive information statement" nil)
    ("DEFM14A" "defm14a" nil)
    ("11-K" "annual report" nil)
    ("4" "statement of changes in beneficial ownership" nil)
    ("13F-HR" "form 13f" nil)
    ("13F-NT" "form 13f" nil)
    ("N-CSR" "separate N-CSR" ("2"))
    ("N-CSRS" "certified shareholder report" ("1" "7" "19"))
    ("N-23C-2" "notice of intention to redeem securities" nil)
    ("N-23C3A" "notification of repurchase offer" nil)
    ("N-23C3B" "axxes opportunistic credit fund" nil)
    ("N-30B-2" "first quarter report" nil)
    ("N-30D" "semi-annual report" nil)
    ("N-54A" "third point private capital partners" nil)
    ("N-54C" "nuveen churchill bdc v" nil)
    ("N-6F" "robinhood ventures fund ii" nil)
    ("N-8A" "notification of registration" nil)
    ("N-8F" "application for deregistration" nil)
    ("N-8F NTC" "notice of applications for deregistration" nil)
    ("N-8F ORDR" "applicant has ceased to be an investment company" nil)
    ("N-VP" "annual notice" nil)
    ("N-VPFS" "financial statements" nil)
    ("NT-NCEN" "notification of late filing" nil)
    ("NT-NCSR" "notification of late filing" nil)
    ("NTFNCSR" "notification of late filing" nil)
    ("SCHEDULE 13G" "schedule 13g" nil)
    ("SC 13G" "schedule 13g" nil)
    ("SC 13G/A" "schedule 13g" nil)
    ("SC TO-T" "schedule to" nil)
    ("SC TO-C" "tender offer statement on schedule to" nil)
    ("SC TO-I" "issuer tender offer statement" nil)
    ("SC 14D9" "schedule 14d-9" nil)
    ("1-K" "form 1-k" nil)
    ("1-SA" "semiannual report pursuant to regulation a" nil)
    ("1-U" "current report" nil)
    ("1-A-W" "withdrawal of offering statement" nil)
    ("253G1" "offering circular" nil)
    ("253G2" "offering circular supplement" nil)
    ("144" "notice of proposed sale" nil)))

(defun edgar-expect--check (slug)
  "Replay fixture SLUG and compare against its expectation."
  (let* ((filing
          (edgar-expect--read (edgar-expect--file slug ".eld")))
         (primary (edgar-expect--primary slug))
         (inv
          (assoc (plist-get filing :form) edgar-expect--invariants))
         text
         snap)
    (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) primary)))
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

(ert-deftest edgar-amendments-link-original-accession ()
  (let ((submissions
         '(:filings
           (:recent
            (:accessionNumber
             ("0001318605-26-053166" "0001318605-26-010001")
             :form ("10-K/A" "10-K")
             :filingDate ("2026-04-30" "2026-02-01")
             :reportDate ("2025-12-31" "2025-12-31")
             :primaryDocument ("amendment.htm" "original.htm"))))))
    (cl-letf (((symbol-function 'xbrl-cik)
               (lambda (_) "CIK0001318605"))
              ((symbol-function 'xbrl--get) (lambda (_) submissions)))
      (let ((amendment (car (edgar-filings "TSLA" "10-K/A"))))
        (should
         (equal
          (plist-get amendment :amends) "0001318605-26-010001"))))))

(ert-deftest edgar-effective-section-uses-amendment-then-original ()
  (let*
      ((original
        '(:accn
          "0001318605-26-010001"
          :form "10-K"
          :filed "2026-02-01"
          :report "2025-12-31"
          :cik 1318605
          :url "https://example.test/original"))
       (amendment
        (edgar-expect--read (edgar-expect--file "10-ka-tsla" ".eld")))
       (newer-amendment (copy-sequence amendment))
       (amendment-html (edgar-expect--html "10-ka-tsla"))
       (original-html
        "<html><body><p>Item 1. Business</p><p>Original business text.</p></body></html>"))
    (setf (plist-get amendment :amends) (plist-get original :accn))
    (setf
     (plist-get newer-amendment :accn) "0001318605-26-060001"
     (plist-get newer-amendment :filed) "2026-05-30"
     (plist-get newer-amendment :amends) (plist-get original :accn)
     (plist-get newer-amendment :url) "https://example.test/newer-amendment")
    (cl-letf (((symbol-function 'edgar-filings)
               (lambda (_ticker form &rest _bounds)
                 (if (equal form "10-K/A")
                     (list newer-amendment amendment)
                   (list original))))
              ((symbol-function 'edgar--fetch)
               (lambda (url)
                 (cond
                  ((equal url (plist-get amendment :url))
                   amendment-html)
                  ((equal url (plist-get newer-amendment :url))
                   "<html><body>Cover page only.</body></html>")
                  (t
                   original-html))))
              ((symbol-function 'edgar--fetch-xml)
               (lambda (&rest _) (error "Unexpected XML fetch"))))
      (should
       (string-match-p
        "Tesla"
        (or (edgar-effective-section "TSLA" "10-K" "III.10") "")))
      (should
       (string-match-p
        "Original business text"
        (or (edgar-effective-section "TSLA" "10-K" "1") ""))))))

(ert-deftest edgar-text-diff-returns-unified-diff ()
  (let ((diff (edgar-text-diff "before text\n" "after text\n")))
    (should (string-match-p "^-before text$" diff))
    (should (string-match-p "^+after text$" diff))
    (should (equal (edgar-text-diff "same\n" "same\n") ""))))

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
