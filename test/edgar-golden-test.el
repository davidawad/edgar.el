;;; edgar-golden-test.el --- hardcoded-string tests over recorded filings -*- lexical-binding: t; -*-

;; For every recorded filing, test/golden/<slug>.eld holds verbatim strings
;; taken from specific sections (see tools/make-golden.el).  Each must still
;; appear in exactly the section it was taken from and in no other section --
;; so a shifted boundary, a merged Part or a lost section fails loudly -- and
;; the whole-text strings must still appear in the rendered filing.
;; test/golden-facts.eld holds hand-checked facts with the same guarantee.

(require 'ert)
(add-to-list
 'load-path
 (file-name-directory (or load-file-name buffer-file-name)))
(require 'edgar-fixtures)

(defun edgar-golden-test--bodies (slug)
  "Alist of (KEY . normalized body) for fixture SLUG."
  (mapcar
   (lambda (s) (cons (car s) (edgar-fixtures-norm (cdr s))))
   (edgar-sections (edgar-fixtures-text slug))))

(defun edgar-golden-test--check-section (slug key strings bodies)
  "Assert STRINGS from SLUG's section KEY are in it and in no other of BODIES."
  (let ((body (cdr (assoc key bodies))))
    (unless body
      (ert-fail
       (format "%s: section %s no longer found (have %s)"
               slug
               key
               (mapconcat #'car bodies " "))))
    (dolist (str strings)
      (unless (string-search str body)
        (ert-fail
         (format "%s: %S missing from section %s" slug str key)))
      (dolist (other bodies)
        (when (and (not (equal (car other) key))
                   (string-search str (cdr other)))
          (ert-fail
           (format "%s: %S from section %s also appears in %s"
                   slug str key (car other))))))))

(defun edgar-golden-test--run (slug)
  "Check fixture SLUG against its golden strings."
  (let* ((golden
          (edgar-fixtures-read
           (edgar-fixtures-path (concat "golden/" slug ".eld"))))
         (bodies (edgar-golden-test--bodies slug))
         (norm (edgar-fixtures-norm (edgar-fixtures-text slug))))
    (dolist (entry (plist-get golden :sections))
      (edgar-golden-test--check-section
       slug (car entry) (cdr entry) bodies))
    ;; Every section the parser finds must have golden coverage.
    (dolist (b bodies)
      (unless (assoc (car b) (plist-get golden :sections))
        (ert-fail
         (format "%s: section %s has no golden strings"
                 slug
                 (car b)))))
    (dolist (str (plist-get golden :text))
      (unless (string-search str norm)
        (ert-fail
         (format "%s: whole-text string %S missing" slug str))))
    (should
     (or (plist-get golden :sections) (plist-get golden :text)))))

(dolist (slug (edgar-fixtures-slugs))
  (let ((name (intern (concat "edgar-golden-" slug)))
        (s slug))
    (ert-set-test
     name
     (make-ert-test
      :name name
      :body
      (lambda () (edgar-golden-test--run s))))))

;; Hand-checked facts: (SLUG SECTION-KEY-OR-nil STRING).  A nil key means
;; "somewhere in the filing".
(ert-deftest edgar-golden-hand-checked-facts ()
  (dolist (f
           (edgar-fixtures-read
            (edgar-fixtures-path "golden-facts.eld")))
    (let* ((slug (nth 0 f))
           (key (nth 1 f))
           (str (nth 2 f)))
      (if key
          (edgar-golden-test--check-section
           slug key (list str) (edgar-golden-test--bodies slug))
        (unless (string-search
                 str
                 (edgar-fixtures-norm (edgar-fixtures-text slug)))
          (ert-fail (format "%s: fact %S missing" slug str)))))))

(ert-deftest edgar-golden-g9-generic-named-signature-sections ()
  "Named section extraction reaches real G9 filings without form rules."
  (dolist
      (entry
       '(("11-k-ko" . "Pursuant to the requirements of the Securities Exchange Act")
         ("11-k-ko-prior" . "Pursuant to the requirements of the Securities Exchange Act")
         ("40-f-shop" . "the Registrant certifies that it")
         ("40-f-shop-prior" . "the Registrant certifies that it")
         ("6-k-tsm" . "Pursuant to the requirements of the Securities Exchange Act")
         ("6-k-tsm-prior" . "Pursuant to the requirements of the Securities Exchange Act")))
    (let* ((slug (car entry))
           (filing (edgar-fixtures-filing slug))
           (html (edgar-fixtures-html slug))
           section)
      (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) html)))
        (setq section (edgar-section filing "SIGNATURES")))
      (should section)
      (should
       (string-match-p
        (regexp-quote (cdr entry))
      (replace-regexp-in-string
         "[ \t\n ]+" " " (edgar-fixtures-norm section)))))))

(ert-deftest edgar-golden-g9-generic-html-body-access ()
  "Newly covered registration and NT forms expose their HTML body generically."
  (dolist
      (entry
       '(("15-12g-apogee" . "Apogee Therapeutics")
         ("nt-10k-dbmm" . "Digital Brand Media")
         ("nt-10q-dbmm" . "Digital Brand Media")
         ("nt-11k-oldrepublic" . "ori 401(k) savings")
         ("nt-20f-telkom" . "Telekomunikasi Indonesia")))
    (let* ((slug (car entry))
           (filing (edgar-fixtures-filing slug))
           (html (edgar-fixtures-html slug))
           body)
      (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) html)))
        (setq body (edgar-section filing '("html" "body"))))
      (should body)
      (should
       (string-match-p
        (regexp-quote (cdr entry))
        (edgar-fixtures-norm body))))))

(ert-deftest edgar-golden-g8-proxy-and-tender-sections ()
  "Proxy proposals and tender-offer Items resolve in real SEC filings."
  (dolist
      (entry
       '(("def-14a-gme" "PROPOSAL 1: ELECTION OF DIRECTORS"
          "proposal 1: election of directors")
         ("def-14a-gme" "PROPOSAL 2: ADVISORY VOTE ON EXECUTIVE COMPENSATION         20"
          "advisory vote on executive compensation")
         ("def-14a-gme-prior" "COMPENSATION DISCUSSION AND ANALYSIS"
          "compensation")))
    (let* ((slug (nth 0 entry))
           (filing (edgar-fixtures-filing slug))
           (html (edgar-fixtures-html slug)))
      (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) html)))
        (let ((body (edgar-section filing (nth 1 entry))))
          (should (stringp body))
          (should (string-match-p
                   (regexp-quote (nth 2 entry))
                   (downcase body)))))))
  (let* ((filing (edgar-fixtures-filing "sc-to-t-tubemogul"))
         (html (edgar-fixtures-html "sc-to-t-tubemogul")))
    (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) html)))
      (dolist (entry '(("1" "Summary Term Sheet")
                       ("4" "Terms of the Transaction")
                       ("8" "Interest in Securities of the Subject Company")))
        (let ((body (edgar-section filing (car entry))))
          (should (stringp body))
          (should (string-match-p (regexp-quote (cadr entry)) body)))))))

(ert-deftest edgar-golden-g8-normalizes-thin-space-item-headings ()
  "Real tender-offer Items separated by thin spaces remain addressable."
  (should
   (equal
    (mapcar #'car (edgar-sections (edgar-fixtures-text "sc-to-t-biontech")))
    (mapcar #'number-to-string (number-sequence 1 13)))))

(ert-deftest edgar-golden-g8-extracts-all-sc-14d9-items ()
  "A real Schedule 14D-9 exposes each numbered Item through the section API."
  (let ((filing (edgar-fixtures-filing "sc-14d9-cidara"))
        (html (edgar-fixtures-html "sc-14d9-cidara")))
    (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) html)))
      (should
       (equal
        (mapcar #'car (edgar-sections (edgar-text filing)))
        (mapcar #'number-to-string (number-sequence 1 9))))
      (dolist (entry
               '(("1" "Subject Company Information")
                 ("2" "Identity and Background of Filing Person")
                 ("3" "Past Contacts, Transactions, Negotiations and Agreements")
                 ("4" "The Solicitation or Recommendation")
                 ("5" "Person/Assets Retained, Employed, Compensated or Used")
                 ("6" "Interest in Securities of the Subject Company")
                 ("7" "Purposes of the Transaction and Plans or Proposals")
                 ("8" "Additional Information")
                 ("9" "Exhibits")))
        (let ((body (edgar-section filing (car entry))))
          (should (stringp body))
          (should (string-match-p
                   (regexp-quote (cadr entry))
                   (edgar-fixtures-norm body))))))))

(ert-deftest edgar-golden-g8-finds-def14a-security-ownership ()
  "Title-case filing headings without blank-line separators stay addressable."
  (let* ((filing (edgar-fixtures-filing "def-14a-gme"))
         (html (edgar-fixtures-html "def-14a-gme")))
    (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) html)))
      (let ((body (edgar-section filing "Security Ownership")))
        (should (stringp body))
        (should (string-match-p "beneficially owned" body))))))

(provide 'edgar-golden-test)
;;; edgar-golden-test.el ends here
