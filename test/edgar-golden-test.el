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
       '(("11-k-ko"
          .
          "Pursuant to the requirements of the Securities Exchange Act")
         ("11-k-ko-prior"
          .
          "Pursuant to the requirements of the Securities Exchange Act")
         ("40-f-shop" . "the Registrant certifies that it")
         ("40-f-shop-prior" . "the Registrant certifies that it")
         ("6-k-tsm"
          .
          "Pursuant to the requirements of the Securities Exchange Act")
         ("6-k-tsm-prior"
          .
          "Pursuant to the requirements of the Securities Exchange Act")))
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
  (dolist (entry
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
        (regexp-quote (cdr entry)) (edgar-fixtures-norm body))))))

(ert-deftest edgar-golden-g10-generic-html-body-access ()
  "New investment-company registration forms expose their HTML body."
  (dolist (entry
           '(("486apos-flat-rock" . "Flat Rock")
             ("40-24b2-hit-investment" . "Economic Impact of HIT-Financed Projects")
             ("486bpos-coller" . "Coller")
             ("487-adt2360" . "Advisors Disciplined Trust 2360")
             ("40-6b-robinhood" . "Robinhood")
             ("40-17f1-northern-lights" . "Northern Lights")
             ("40-17f2-fundrise" . "Fundrise Innovation Fund")
             ("40-33-180degree" . "180 Degree Capital")
             ("40-8f-2-chesapeake" . "Chesapeake Investors")
             ("del-am-jpmorgan" . "J.P. Morgan Exchange-Traded Fund Trust")
             ("486bxt-ark-venture" . "ARK Venture Fund")
             ("497ad-powerlaw" . "Powerlaw")
             ("n-4-2026" . "Form N-4")
             ("n-14-8c-acif" . "Alternative Credit Income Fund")
             ("n-2asr-blackrock" . "BlackRock Enhanced Large Cap Core Fund")
             ("n-2-posasr-eagle-point" . "Eagle Point Credit Company")
             ("n-6-pacific-select" . "Form N-6")
             ("n-2mef-ives-ultra" . "Ives Ultra AI Opportunities")
             ("app-wd-guggenheim" . "Guggenheim Strategic Opportunities Fund")
             ("n-2-buttonwood" . "Buttonwood")
             ("n-14-nomura" . "Nomura")
             ("497vpsub-voya" . "Voya")))
    (let* ((slug (car entry))
           (filing (edgar-fixtures-filing slug))
           (html (edgar-fixtures-html slug))
           body)
      (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) html)))
        (setq body (edgar-section filing '("html" "body"))))
      (should body)
      (should
       (string-match-p
        (regexp-quote (downcase (cdr entry)))
        (downcase (edgar-fixtures-norm body)))))))

(ert-deftest edgar-golden-g7-named-prospectus-sections ()
  "Major prospectus layouts expose named headings through the shared API."
  (dolist
      (entry
       '(("s-1-rivn" . "Rivian")
         ("s-3-autonomix" . "Autonomix")
         ("s-3-indaptus" . "Indaptus")
         ("s-3-maxcyte" . "MaxCyte")
         ("f-1-fasttrack" . "Fast Track")
         ("f-1-verdera" . "Verdera")
         ("f-1-vision-marine" . "Vision Marine")
         ("f-3-ceragon" . "Ceragon")
         ("f-3-bit-mining" . "BIT Mining")
         ("f-3-critical-metals" . "Critical Metals")
         ("424b3-powerlaw" . "Powerlaw")
         ("424b5-singularity" . "Singularity")
         ("424b5-oneok" . "ONEOK")
         ("424b5-idaho-power" . "Idaho Power")))
    (let* ((slug (car entry))
           (filing (edgar-fixtures-filing slug))
           (html (edgar-fixtures-html slug))
           tree
           section
           body)
      (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) html)))
        (setq tree (edgar-document-structure filing))
        (setq section (edgar-section filing "Risk Factors"))
        (setq body (edgar-section filing '("html" "body"))))
      (should body)
      (if section
          (progn
            (should (> (length section) 100))
            (should
             (string-match-p "RISK FACTORS"
                             (upcase (edgar-fixtures-norm section)))))
        (should-not (edgar-structure-headings tree))
        (should (> (length body) 100))))))

(ert-deftest edgar-golden-g7-pricing-supplement-generic-access ()
  "Table-led 424B2 filings retain generic body access when heading nodes are absent."
  (dolist (slug '("424b2-jpm" "424b2-barclays" "424b2-hsbc"))
    (let* ((filing (edgar-fixtures-filing slug))
           (html (edgar-fixtures-html slug))
           (tree nil)
           risk-section
           body)
      (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) html)))
        (setq tree (edgar-document-structure filing))
        (setq risk-section (edgar-section filing "Risk Factors"))
        (setq body (edgar-section filing '("html" "body"))))
      (should-not (edgar-structure-headings tree))
      (when risk-section
        (should (> (length risk-section) 100))
        (should
         (string-match-p "RISK FACTORS"
                         (upcase (edgar-fixtures-norm risk-section)))))
      (should body)
      (should
       (string-match-p "pricing supplement"
                       (downcase (edgar-fixtures-norm body)))))))

(ert-deftest edgar-golden-g7-toc-less-registration-items ()
  "S-8 registration statements expose Part II Items without a contents page."
  (let* ((slug "s-8-veralto")
         (filing (edgar-fixtures-filing slug))
         (html (edgar-fixtures-html slug))
         text
         section)
    (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) html)))
      (setq text (edgar-text filing))
      (setq section (edgar-section filing "II.8")))
    (should-not (string-match-p "TABLE OF CONTENTS" (upcase text)))
    (should section)
    (should
     (string-match-p
      "exhibits"
      (downcase (edgar-fixtures-norm section))))))

(ert-deftest edgar-golden-g7-toc-backed-risk-sections ()
  "S-3 prospectus Risk Factors resolve through TOC-backed named headings."
  (dolist (entry
           (edgar-fixtures-read
            (edgar-fixtures-path "golden/g7-prospectus-sections.eld")))
    (let* ((slug (nth 0 entry))
           (filing (edgar-fixtures-filing slug))
           (html (edgar-fixtures-html slug))
           section)
      (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) html)))
        (setq section (edgar-section filing (nth 1 entry))))
      (should section)
      (should
       (string-search (nth 2 entry)
                      (edgar-fixtures-norm section))))))

(ert-deftest edgar-golden-g7-8-a12b-generic-item-access ()
  "8-A12B registration documents expose generic numbered Item sections."
  (let* ((slug "8-a12b-amazon")
         (filing (edgar-fixtures-filing slug))
         (html (edgar-fixtures-html slug))
         section)
    (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) html)))
      (setq section (edgar-section filing "1")))
    (should section)
    (should
     (string-match-p "5.200% Notes due 2029"
                     (edgar-fixtures-norm section)))))

(ert-deftest edgar-golden-g7-s-8-pos-generic-item-access ()
  "S-8 POS post-effective amendments expose their Part II Items."
  (let* ((slug "s-8-pos-exxonmobil")
         (filing (edgar-fixtures-filing slug))
         (html (edgar-fixtures-html slug))
         section)
    (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) html)))
      (setq section (edgar-section filing "II.8")))
    (should section)
    (should (string-match-p "Exhibits" (edgar-fixtures-norm section)))))

(ert-deftest edgar-golden-g7-424b4-generic-body-access ()
  "424B4 prospectuses from distinct filers expose generic HTML body access."
  (dolist (slug '("424b4-rectitude" "424b4-impact-biomedical" "424b4-loar"))
    (let* ((filing (edgar-fixtures-filing slug))
           (html (edgar-fixtures-html slug))
           body)
      (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) html)))
        (setq body (edgar-section filing '("html" "body"))))
      (should body)
      (should (> (length body) 1000))
      (should (string-match-p "prospectus" (downcase body))))))

(ert-deftest edgar-golden-g8-proxy-and-tender-sections ()
  "Proxy proposals and tender-offer Items resolve in real SEC filings."
  (dolist
      (entry
       '(("def-14a-gme"
          "PROPOSAL 1: ELECTION OF DIRECTORS"
          "proposal 1: election of directors")
         ("def-14a-gme"
          "PROPOSAL 2: ADVISORY VOTE ON EXECUTIVE COMPENSATION         20"
          "advisory vote on executive compensation")
         ("def-14a-gme-prior"
          "COMPENSATION DISCUSSION AND ANALYSIS"
          "compensation")))
    (let* ((slug (nth 0 entry))
           (filing (edgar-fixtures-filing slug))
           (html (edgar-fixtures-html slug)))
      (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) html)))
        (let ((body (edgar-section filing (nth 1 entry))))
          (should (stringp body))
          (should
           (string-match-p
            (regexp-quote (nth 2 entry)) (downcase body)))))))
  (let* ((filing (edgar-fixtures-filing "sc-to-t-tubemogul"))
         (html (edgar-fixtures-html "sc-to-t-tubemogul")))
    (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) html)))
      (dolist (entry
               '(("1" "Summary Term Sheet")
                 ("4" "Terms of the Transaction")
                 ("8"
                  "Interest in Securities of the Subject Company")))
        (let ((body (edgar-section filing (car entry))))
          (should (stringp body))
          (should
           (string-match-p (regexp-quote (cadr entry)) body)))))))

(ert-deftest edgar-golden-g8-normalizes-thin-space-item-headings ()
  "Real tender-offer Items separated by thin spaces remain addressable."
  (should
   (equal
    (mapcar
     #'car (edgar-sections (edgar-fixtures-text "sc-to-t-biontech")))
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
      (dolist
          (entry
           '(("1" "Subject Company Information")
             ("2" "Identity and Background of Filing Person")
             ("3"
              "Past Contacts, Transactions, Negotiations and Agreements")
             ("4" "The Solicitation or Recommendation")
             ("5"
              "Person/Assets Retained, Employed, Compensated or Used")
             ("6" "Interest in Securities of the Subject Company")
             ("7"
              "Purposes of the Transaction and Plans or Proposals")
             ("8" "Additional Information") ("9" "Exhibits")))
        (let ((body (edgar-section filing (car entry))))
          (should (stringp body))
          (should
           (string-match-p
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

(ert-deftest
    edgar-golden-g8-def14a-proposals-compensation-and-ownership
    ()
  "Real DEF 14A filings expose proposals, compensation, and ownership sections."
  (dolist
      (entry
       '(("def-14a-encore" "Election of Directors" "THE BOARD")
         ("def-14a-encore"
          "Compensation Discussion and Analysis"
          "provides an overview of our executive compensation")
         ("def-14a-encore"
          "Security Ownership of Certain Beneficial Holders and Management"
          "beneficial ownership information of our Common Shares")
         ("def-14a-venture-global"
          "Management Proposals"
          "PROPOSAL 1")
         ("def-14a-venture-global"
          "COMPENSATION DISCUSSION AND ANALYSIS"
          "section is to provide information")
         ("def-14a-venture-global"
          "Security Ownership of Certain Beneficial Owners and Management"
          "beneficial ownership")))
    (let* ((slug (nth 0 entry))
           (filing (edgar-fixtures-filing slug))
           (html (edgar-fixtures-html slug)))
      (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) html)))
        (let ((body (edgar-section filing (nth 1 entry))))
          (should (stringp body))
          (should
           (string-match-p
            (regexp-quote (downcase (nth 2 entry)))
            (downcase (edgar-fixtures-norm body)))))))))

(ert-deftest
    edgar-golden-g8-other-proxy-and-tender-sections-are-addressable
    ()
  "Additional real proxy and tender forms use the shared section APIs."
  (let* ((filing (edgar-fixtures-filing "defm14a-matrixx"))
         (html (edgar-fixtures-html "defm14a-matrixx")))
    (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) html)))
      (let ((body
             (edgar-section filing "Recommendation of the Board")))
        (should (stringp body))
        (should (string-match-p "merger" (downcase body))))))
  (let* ((filing (edgar-fixtures-filing "def-14c-pmgc"))
         (html (edgar-fixtures-html "def-14c-pmgc")))
    (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) html)))
      (let* ((tree (edgar-document-structure filing))
             (body (edgar-section filing '("html" "body"))))
        (should (stringp body))
        (should (string-match-p "PMGC HOLDINGS INC." body))
        (should (> (length (edgar-structure-paragraphs tree)) 100)))))
  (let* ((filing (edgar-fixtures-filing "sc-to-i-pamt"))
         (html (edgar-fixtures-html "sc-to-i-pamt")))
    (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) html)))
      (should
       (equal
        (mapcar #'car (edgar-sections (edgar-text filing)))
        (mapcar #'number-to-string (number-sequence 1 13))))
      (dolist (entry
               '(("1" "Summary Term Sheet")
                 ("4" "Terms of the Transaction")
                 ("8" "Interest in Securities of the Subject Company")
                 ("13" "Information Required by Schedule 13E-3")))
        (should
         (string-match-p
          (regexp-quote (cadr entry))
          (edgar-section filing (car entry)))))))
  (let* ((filing (edgar-fixtures-filing "sc-to-c-cresco"))
         (html (edgar-fixtures-html "sc-to-c-cresco")))
    (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) html)))
      (should
       (string-match-p "Exhibits" (edgar-section filing "12"))))))

(provide 'edgar-golden-test)
;;; edgar-golden-test.el ends here
