;;; edgar-golden-test.el --- hardcoded-string tests over recorded filings -*- lexical-binding: t; -*-

;; For each filing with a reviewed golden, test/golden/<slug>.eld holds
;; verbatim strings taken from specific sections (see tools/make-golden.el).
;; Each must still appear in exactly the section it was taken from and in no
;; other section -- so a shifted boundary, a merged Part or a lost section
;; fails loudly -- and the whole-text strings must still appear in the filing.
;; test/golden-facts.eld holds hand-checked facts with the same guarantee.

(require 'edgar-golden-test-support)

(dolist (slug (edgar-fixtures-slugs))
  (when (file-exists-p
         (edgar-fixtures-path (concat "golden/" slug ".eld")))
    (let ((name (intern (concat "edgar-golden-" slug)))
          (s slug))
      (ert-set-test
       name
       (make-ert-test
        :name name
        :body
        (lambda () (edgar-golden-test--run s)))))))

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

(ert-deftest edgar-golden-g10-497k-part-a-named-section-three-filers ()
  "497K summary prospectuses expose the same named expense section."
  (edgar-golden-test--check-named-section-fixtures
   "497K" "Annual Fund Operating Expenses"
   '("497k-hennessy"
     "diversity-497k-1100663"
     "diversity-497k-1174610")))

(ert-deftest edgar-golden-g10-n-1a-part-a-named-section-three-filers ()
  "N-1A Part A exposes Investment Objective across three registrants."
  (edgar-golden-test--check-named-section-fixtures
   "N-1A" "Investment Objective"
   '("n-1a-americandrive"
     "diversity-n-1a-2078265"
     "diversity-n-1a-2083193")))

(ert-deftest edgar-golden-g7-named-prospectus-sections ()
  "Major prospectus layouts expose named headings through the shared API."
  (dolist
      (entry
       '(("s-1-rivn" . "Rivian")
         ("s-3-autonomix" . "Autonomix")
         ("s-3-indaptus" . "Indaptus")
         ("s-3-maxcyte" . "Werewolf")
         ("f-1-fasttrack" . "Fast Track")
         ("f-1-verdera" . "Verdera")
         ("f-1-vision-marine" . "Vision Marine")
         ("f-3-ceragon" . "Ceragon")
         ("f-3-bit-mining" . "BIT Mining")
         ("f-3-critical-metals" . "Critical Metals")
         ("424b3-powerlaw" . "Powerlaw")
         ("424b1-nyseg" . "Recovery Bonds")
         ("424b1-millrose" . "Millrose")
         ("424b1-odyssey" . "Odyssey")
         ("f-4-china-auto" . "China Automotive")
         ("f-4-alibaba" . "Alibaba")
         ("f-4-aercap" . "AerCap")
         ("424b5-singularity" . "Singularity")
         ("424b5-oneok" . "ONEOK")
         ("424b5-idaho-power" . "Idaho Power")))
    (let* ((slug (car entry))
           (filing (edgar-fixtures-filing slug))
           (html (edgar-fixtures-html slug))
           section
           body)
      (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) html)))
        (setq section (edgar-section filing "Risk Factors"))
        (setq body (edgar-section filing '("html" "body"))))
      (should body)
      (when section
        (should (> (length section) 100))
        (should
         (string-match-p "RISK FACTORS"
                         (upcase (edgar-fixtures-norm section)))))
      (should (> (length body) 100)))))

(ert-deftest edgar-golden-g7-pricing-supplement-generic-access ()
  "Table-led 424B2 filings retain generic body access with or without headings."
  (dolist (slug '("424b2-jpm" "424b2-barclays" "424b2-hsbc"))
    (let* ((filing (edgar-fixtures-filing slug))
           (html (edgar-fixtures-html slug))
           risk-section
           body)
      (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) html)))
        (setq risk-section (edgar-section filing "Risk Factors"))
        (setq body (edgar-section filing '("html" "body"))))
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
  "S-8 filings expose Part II Items without a contents page."
  (dolist (slug '("s-8-veralto" "s-8-pos-exxonmobil"))
    (let* ((filing (edgar-fixtures-filing slug))
           (html (edgar-fixtures-html slug))
           tree
           text
           section)
      (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) html)))
        (setq tree (edgar-document-structure filing))
        (setq text (edgar-text filing))
        (setq section (edgar-section filing "II.8")))
      (should-not (string-match-p "TABLE OF CONTENTS" (upcase text)))
      (should section)
      (should
       (string-match-p
        "exhibits"
        (downcase (edgar-fixtures-norm section))))
      (when (equal slug "s-8-pos-exxonmobil")
        (let* ((headings (edgar-structure-headings tree))
               (signature
                (edgar-structure-section tree "SIGNATURES")))
          (should
           (seq-some
            (lambda (heading)
              (equal "SIGNATURES"
                     (upcase (plist-get heading :name))))
            headings))
          (should signature)
          (should
           (string-match-p
            "Pursuant to the requirements of the Securities Act"
            (edgar-fixtures-norm (plist-get signature :body)))))))))

(ert-deftest edgar-golden-g7-drs-toc-and-toc-less-structure ()
  "Draft registration filings expose shared named and tree structure."
  (dolist
      (entry
       '(("index-drs-2026-q2" nil)
         ("index-drs-2023-q2" t)
         ("index-drs-2025-q2" t)))
    (let* ((slug (car entry))
           (has-toc (cadr entry))
           (filing (edgar-fixtures-filing slug))
           (html (edgar-fixtures-html slug))
           tree
           named-section
           body-section)
      (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) html)))
        (setq tree (edgar-document-structure filing)
              named-section (edgar-section filing "Risk Factors")
              body-section
              (edgar-structure-section tree '("html" "body"))))
      (should
       (eq has-toc
           (and (string-match-p "TABLE OF CONTENTS" (upcase html)) t)))
      (should named-section)
      (should (> (length named-section) 100))
      (should
       (string-match-p
        "investing in our securities"
        (downcase (edgar-fixtures-norm named-section))))
      (should body-section)
      (should (> (length (plist-get body-section :body)) 1000))
      (should
       (string-match-p
        "investing in our securities"
        (downcase
         (edgar-fixtures-norm (plist-get body-section :body)))))
      (when has-toc
        (let ((tree-risk (edgar-structure-section tree "Risk Factors")))
          (should tree-risk)
          (should
           (string-match-p
            "investing in our securities"
            (downcase
             (edgar-fixtures-norm (plist-get tree-risk :body))))))))))

(ert-deftest edgar-golden-g7-toc-backed-risk-sections ()
  "S-3 prospectus Risk Factors resolve through named section access."
  (dolist (entry
           (edgar-fixtures-read
            (edgar-fixtures-path "golden/g7-prospectus-sections.eld")))
    (let* ((slug (nth 0 entry))
           (filing (edgar-fixtures-filing slug))
           (html (edgar-fixtures-html slug))
           (tree nil)
           (tree-section nil)
           section)
      (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) html)))
        (setq tree (edgar-document-structure filing)
              section (edgar-section filing (nth 1 entry))))
      (should (eq (plist-get (edgar-form-info "S-3") :level) 'L2))
      (if (equal slug "s-3-maxcyte")
          (should-error (edgar-structure-section tree (nth 1 entry))
                        :type 'user-error)
        (setq tree-section (edgar-structure-section tree (nth 1 entry)))
        (should tree-section)
        (should
         (string-search (nth 2 entry)
                        (edgar-fixtures-norm
                         (plist-get tree-section :body)))))
      (when (equal slug "s-3-autonomix")
        (should
         (seq-some
          (lambda (heading)
            (equal "RISK FACTORS" (upcase (plist-get heading :name))))
          (edgar-structure-headings tree))))
      (should section)
      (should
       (string-search (nth 2 entry)
                      (edgar-fixtures-norm section))))))

(ert-deftest edgar-golden-g7-prospectus-subfamilies-have-three-filer-goldens
    ()
  "Principal prospectus subfamilies retain reviewed goldens for three filers."
  (dolist (form '("S-1" "S-3" "S-4" "F-1" "F-3" "F-4"
                  "DRS" "424B1" "424B2" "424B3" "424B4" "424B5"))
    (let* ((slugs
            (seq-filter
             (lambda (slug)
               (equal form
                      (plist-get (edgar-fixtures-filing slug) :form)))
             (edgar-fixtures-slugs)))
           (ciks
            (delete-dups
             (mapcar
              (lambda (slug)
                (plist-get (edgar-fixtures-filing slug) :cik))
              slugs)))
           (goldens
            (mapcar
             (lambda (slug)
               (edgar-fixtures-read
                (edgar-fixtures-path
                 (concat "golden/" slug ".eld"))))
             slugs)))
      (should (>= (length ciks) 3))
      (should
       (seq-every-p
        (lambda (golden)
          (or (plist-get golden :sections)
              (plist-get golden :text)))
        goldens)))))

(ert-deftest edgar-golden-g7-html-linked-prospectus-heading ()
  "Generic HTML fragment links expose a named prospectus section in the tree."
  (let* ((entry
          (car (edgar-fixtures-read
                (edgar-fixtures-path "golden/g7-prospectus-linked-heading.eld"))))
         (slug (nth 0 entry))
         (name (nth 1 entry))
         (marker (nth 2 entry))
         (filing (edgar-fixtures-filing slug))
         (html (edgar-fixtures-html slug))
         tree
         tree-section
         filing-section)
    (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) html)))
      (setq tree (edgar-document-structure filing))
      (setq tree-section (edgar-structure-section tree name))
      (setq filing-section (edgar-section filing name)))
    (should tree-section)
    (should (> (length (plist-get tree-section :body)) 100))
    (should
     (string-search marker
                    (edgar-fixtures-norm (plist-get tree-section :body))))
    (should (string-search marker (edgar-fixtures-norm filing-section)))))

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

(provide 'edgar-golden-test)
;;; edgar-golden-test.el ends here
