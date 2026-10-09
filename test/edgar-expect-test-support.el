;;; edgar-expect-test-support.el --- Shared helpers for edgar-expect-test -*- lexical-binding: t; -*-

;;; Commentary:

;; Helpers and fixtures shared by `edgar-expect-test' and its companion test files.

;;; Code:

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
  "Path of SLUG's primary-document fixture."
  (or (seq-find
       #'file-exists-p
       (mapcar
        (lambda (ext) (edgar-expect--file slug ext))
        '(".htm.gz" ".pdf" ".xml" ".txt")))
      (error "No rendered primary fixture for %s" slug)))

(defun edgar-expect--expect-file (slug)
  "Path of SLUG's committed expectation."
  (expand-file-name (concat "expect/" slug ".eld") edgar-expect--dir))

(defun edgar-expect--slugs ()
  "Slugs of every primary-document filing fixture."
  (seq-filter
   (lambda (slug)
     (and
      (seq-some
       (lambda (ext)
         (file-exists-p (edgar-expect--file slug ext)))
       '(".htm.gz" ".pdf" ".xml" ".txt"))
      (let ((expect-file (edgar-expect--expect-file slug)))
        (and (file-exists-p expect-file)
             (not
              (equal
               (plist-get (edgar-expect--read
                           (edgar-expect--file slug ".eld"))
                          :fixture-kind)
               "SEC complete-submission excerpt"))
             (plist-member (edgar-expect--read expect-file)
                           :text-bucket)))))
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
  '(("10-12B" "general form for registration of securities" nil)
    ("10-12G" "general form for registration of securities" nil)
    ("10-K" "annual report" ("I.1" "I.1A" "II.7" "II.8"))
    ("10-K/A" "amendment" nil)
    ("10-Q" "quarterly report" ("I.1" "I.2"))
    ("10-D" "asset backed issuer" nil)
    ("8-K" "current report" nil)
    ("8-K/A" "current report" nil)
    ("ABS-15G" "asset-backed securitizer report" nil)
    ("15-15D" "plus automation, inc." nil)
    ("CERT" "new york stock exchange certifies its approval" nil)
    ("DSTRBRPT" "inter-american development bank" nil)
    ("IRANNOTICE" "intel corporation" nil)
    ("REVOKED" "the healing company inc." nil)
    ("20-F" "annual report" nil)
    ("40-F" "annual report" nil)
    ("6-K" "report of foreign private issuer" nil)
    ("AW" "ea series trust" nil)
    ("EFFECT" "park ha biological technology" nil)
    ("40-17G" "1290 funds 40-17g" nil)
    ("40-APP" "application for an order" nil)
    ("40-17F1" "northern lights fund trust" nil)
    ("40-17F2" "specified requirements" nil)
    ("40-24B2" "economic impact of hit-financed projects" nil)
    ("40-33" "180 degree capital" nil)
    ("40-8F-2" "chesapeake investors" nil)
    ("40-6B" "robinhood" nil)
    ("486BXT" "ark venture fund" nil)
    ("485APOS"
     "post-effective amendment"
     ("28" "29" "30" "31" "32" "33" "34" "35"))
    ("486APOS" "post-effective amendment" nil)
    ("486BPOS" "form n-2" nil)
    ("485BPOS" "form n-1a" nil)
    ("485BXT" "form n-1a" nil)
    ("497" "supplement" nil)
    ("497AD" "powerlaw" nil)
    ("497J" "rule 497" nil)
    ("497K" "summary prospectus" nil)
    ("497VPI" "income benefit supplement" nil)
    ("497VPU" "updating summary prospectus" nil)
    ("497VPSUB" "voya" nil)
    ("N-1A" "registration statement" nil)
    ("N-14" "nomura" nil)
    ("N-2" "form n-2" nil)
    ("487" "advisors disciplined trust 2360" nil)
    ("N-4" "form n-4" nil)
    ("N-14 8C" "alternative credit income fund" nil)
    ("N-2ASR" "blackrock enhanced large cap core fund" nil)
    ("N-6" "form n-6" nil)
    ("S-6" "form s-6" nil)
    ("APP NTC" "multi-class etf fund" nil)
    ("APP ORDR" "great elm capital corp." nil)
    ("APP WD" "guggenheim strategic opportunities fund" nil)
    ("APP WDG" "pear tree funds" nil)
    ("CT ORDER" "order granting confidential treatment" nil)
    ("DEL AM" "j.p. morgan exchange-traded fund trust" nil)
    ("S-3" "form s-3" nil)
    ("S-4" "registration statement" nil)
    ("424B2" "pricing supplement" nil)
    ("424B1" "prospectus" nil)
    ("424H" "424h table of contents" nil)
    ("424I" "rule 424" nil)
    ("8-A12G" "item 1. description of registrant" ("1" "2"))
    ("F-4" "registration statement" nil)
    ("F-10" "form f-10 registration statement" nil)
    ("F-10EF" "form f-10 registration statement" nil)
    ("F-10POS" "post-effective amendment" nil)
    ("F-6" "form f-6 registration statement" nil)
    ("F-6 POS" "post-effective amendment" nil)
    ("F-6EF" "form f-6 registration statement" nil)
    ("F-X" "form f-x appointment of agent" nil)
    ("F-1" "registration statement" nil)
    ("DRS" "prospectus" nil)
    ("DOS" "star gold corp." nil)
    ("DOSLTR" "crowdcasting inc." nil)
    ("DRSLTR" "document confidential treatment requested" nil)
    ("F-1MEF" "as filed with the u.s. securities and exchange commission on" nil)
    ("F-3ASR" "as filed with the u.s. securities and exchange commission on" ("II.8" "II.9" "II.10"))
    ("F-3MEF" "as filed with the securities and exchange commission on june" ("II.9"))
    ("F-N" "form f-n united states securities" nil)
    ("POS AM" "table of contents as filed" ("II.14" "II.17"))
    ("POS AMI" "as filed with the securities and exchange commission on april" ("5" "14"))
    ("POS EX" "as filed with the securities and exchange commission" ("II.13" "II.17"))
    ("POSASR" "table of contents as filed" ("II.8" "II.10"))
    ("S-11" "as filed with the securities and exchange commission on june" ("II.37"))
    ("S-1MEF" "as filed with the u.s. securities and exchange commission on" nil)
    ("S-3ASR" "table of contents as filed" ("II.14" "II.17"))
    ("S-3D" "s-3d as filed with the securities and exchange commission" ("II.14" "II.17"))
    ("S-3DPOS" "as filed with the securities and exchange commission on may" ("II.14" "II.17"))
    ("S-3MEF" "s-3mef as filed with the securities and exchange commission" nil)
    ("S-B" "table of contents as filed" nil)
    ("SF-1" "sf-1 table of contents" ("II.12" "II.15"))
    ("SF-3" "sf-3 table of contents" ("II.12" "II.15"))
    ("SUPPL" "suppl table of contents" nil)
    ("424B3" "prospectus" nil)
    ("424B4" "prospectus" nil)
    ("424B5" "prospectus" nil)
    ("424B7" "watsco" nil)
    ("424B8" "nomura" nil)
    ("8-A12B" "amazon.com, inc." ("1" "2"))
    ("F-3" "registration statement" nil)
    ("S-8" "veralto" nil)
    ("S-8 POS" "exxonmobil holdings corp" ("II.3" "II.8"))
    ("RW" "envoy technologies, inc." nil)
    ("FWP" "hsbc" nil)
    ("S-1" "registration statement" nil)
    ("10-KT" "transition report pursuant" ("I.1" "I.1A"))
    ("1-SA" "form 1-sa" nil)
    ("1-U" "form 1-u" nil)
    ("8-K12B" "nova minerals" nil)
    ("QRTLYRPT" "african development bank" nil)
    ("SD" "specialized disclosure report" nil)
    ("15-12G" "certification and notice of termination" nil)
    ("NT 10-K" "notification of late filing" nil)
    ("NT 10-Q" "notification of late filing" nil)
    ("NT 11-K" "notification of late filing" nil)
    ("NT 20-F" "notification of late filing" nil)
    ("NRSRO-CE/A" "moody's ratings" nil)
    ("NRSRO-UPD" "hr ratings llc" nil)
    ("SC14D9C" "securities and exchange commission" nil)
    ("N-2 POSASR" "eagle point" nil)
    ("N-2MEF" "securities and exchange commission" nil)
    ("18-K" "form 18-k" nil)
    ("ARS" "annual report" nil)
    ("CB" "form cb" nil)
    ("DEFC14A" "securities and exchange commission" nil)
    ("DEFR14A" "securities and exchange commission" nil)
    ("DFAN14A" "schedule 14a" nil)
    ("DFRN14A" "schedule 14a" nil)
    ("SC14D1F" "schedule 14d" nil)
    ("25" "notification of removal from listing" nil)
    ("40FR12B" "nuran wireless" nil)
    ("20FR12B" "form 20-f" nil)
    ("20FR12G" "form 20-f" nil)
    ("40FR12G" "form 40-f" nil)
    ("DEFA14A" "pra group, inc." nil)
    ("425" "pursuant to rule 425" nil)
    ("DEFA14C" "notice of internet availability" nil)
    ("DEFM14C" "schedule 14c information" nil)
    ("DEFR14C" "amendment no. 1" nil)
    ("POS 8C" "form n-2" nil)
    ("PREM14C" "schedule 14c information" nil)
    ("PRE 14A" "schedule 14a" nil)
    ("PREC14A" "schedule 14a" nil)
    ("PREM14A" "schedule 14a" nil)
    ("PRE 14C" "schedule 14c information statement" nil)
    ("PRER14A" "schedule 14a" nil)
    ("PRRN14A" "schedule 14a" nil)
    ("PX14A6G" "notice of exempt solicitation" nil)
    ("PREN14A" "preliminary proxy statement" nil)
    ("PRER14C" "schedule 14c information/amendment" nil)
    ("SC 14N" "schedule 14n" nil)
    ("DEF 14A" "proxy statement" nil)
    ("DEF 14C" "definitive information statement" nil)
    ("DEFM14A" "schedule 14a" nil)
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
    ("N-8F ORDR"
     "applicant has ceased to be an investment company"
     nil)
    ("N-VP" "annual notice" nil)
    ("N-VPFS" "financial statements" nil)
    ("NT-NCEN" "notification of late filing" nil)
    ("NT-NCSR" "notification of late filing" nil)
    ("NTFNCSR" "notification of late filing" nil)
    ("SCHEDULE 13G" "schedule 13g" nil)
    ("SC 13G" "schedule 13g" nil)
    ("SC 13G/A" "schedule 13g" nil)
    ("SC 13E3" "going private transaction" nil)
    ("SC 14F1" "schedule 14f-1" nil)
    ("SC 13D/A" "amendment no\\. 1 to schedule 13d" nil)
    ("SC TO-T" "schedule to" nil)
    ("SC TO-C" "tender offer statement on schedule to" nil)
    ("SC TO-I" "tender offer statement" nil)
    ("SC 14D9" "schedule 14d-9" nil)
    ("SEC STAFF ACTIO" "united states of america" nil)
    ("SEC STAFF LETTE" "mao shan huang holdings limited" nil)
    ("1-K" "form 1-k" nil)
    ("1-SA" "semiannual report pursuant to regulation a" nil)
    ("1-U" "current report" nil)
    ("1-A-W" "withdrawal of offering statement" nil)
    ("305B2" "statement of eligibility under" nil)
    ("15F-12B" "westpac banking corporation" nil)
    ("15F-12G" "red metal resources ltd" nil)
    ("6B NTC" "the goldman sachs group, inc." nil)
    ("6B ORDR" "order under sections 6(b) and 6(e)" nil)
    ("ANNLRPT/A" "asian development bank" nil)
    ("SP 15D2" "suncrete, inc." nil)
    ("253G1" "offering circular" nil)
    ("253G2" "offering circular supplement" nil)
    ("144" "notice of proposed sale" nil)))

(defun edgar-expect--check (slug)
  "Replay fixture SLUG and compare against its expectation."
  (let*
      ((filing
        (edgar-expect--read (edgar-expect--file slug ".eld")))
       (primary (edgar-expect--primary slug))
       ;; Exact amendment markers win; otherwise inherit the base form.
       (inv
        (or (assoc (plist-get filing :form) edgar-expect--invariants)
            (assoc
             (edgar--base-form (plist-get filing :form))
             edgar-expect--invariants)))
       text
       snap)
    (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) primary)))
      (setq text (edgar-text filing)))
    (setq snap (edgar-expect--snapshot filing text))
    (should
     (string-match-p
       "\\`https://www.sec.gov/Archives/edgar/\\(?:data/[0-9]+/[0-9-]+[/.]\\|vprr/[0-9]+/[0-9]+\\.pdf\\)"
      (plist-get filing :url)))
    ;; Hand-selected form sentinels are extra checks for forms where we have
    ;; them.  Every fixture still receives exact snapshot comparison below.
    (when inv
      (should
       (string-match-p
        (nth 1 inv)
        (replace-regexp-in-string "[ \t\n ]+" " " (downcase text))))
      (dolist (key (nth 2 inv))
        (should (assoc key (plist-get snap :sections)))))
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

(provide 'edgar-expect-test-support)

;;; edgar-expect-test-support.el ends here
