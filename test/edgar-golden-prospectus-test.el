;;; edgar-golden-prospectus-test.el --- Golden tests for G7/G8 filings -*- lexical-binding: t; -*-

;;; Commentary:

;; Golden tests for G7/G8 filings.
;; Shares helpers with `edgar-golden-test-support'.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'subr-x)
(require 'edgar-golden-test-support)

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

(ert-deftest edgar-golden-g7-s-4-generic-body-access ()
  "S-4 business-combination filings expose generic HTML body access."
  (dolist (slug '("s-4-comcast" "s-4-indivior" "s-4-olin"))
    (let* ((filing (edgar-fixtures-filing slug))
           (html (edgar-fixtures-html slug))
           body)
      (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) html)))
        (setq body (edgar-section filing '("html" "body"))))
      (should body)
      (should (> (length body) 1000))
      (should (string-match-p "registration statement" (downcase body))))))

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

(ert-deftest edgar-golden-g7-424b1-named-risk-sections ()
  "424B1 prospectuses expose linked Risk Factors sections generically."
  (dolist (slug '("424b1-nyseg" "424b1-millrose" "424b1-odyssey"))
    (let* ((filing (edgar-fixtures-filing slug))
           (html (edgar-fixtures-html slug))
           section
           body)
      (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) html)))
        (setq section (edgar-section filing "Risk Factors")
              body (edgar-section filing '("html" "body"))))
      (should section)
      (should (> (length section) 100))
      (should
       (string-match-p "risk factors"
                       (downcase (edgar-fixtures-norm section))))
      (should body)
      (should (> (length body) 1000)))))

(ert-deftest edgar-golden-g7-f4-named-risk-sections ()
  "F-4 merger registrations expose their linked Risk Factors generically."
  (dolist (slug '("f-4-china-auto" "f-4-alibaba" "f-4-aercap"))
    (let* ((filing (edgar-fixtures-filing slug))
           (html (edgar-fixtures-html slug))
           section
           body)
      (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) html)))
        (setq section (edgar-section filing "Risk Factors")
              body (edgar-section filing '("html" "body"))))
      (should section)
      (should (> (length section) 100))
      (should
       (string-match-p "risk factors"
                       (downcase (edgar-fixtures-norm section))))
      (should body)
      (should (> (length body) 1000)))))

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

(ert-deftest edgar-golden-g8-sc-14d9-items-have-per-filer-goldens ()
  "Three Schedule 14D-9 filers expose the same named Items."
  (dolist
      (entry
       '(("sc-14d9-cidara"
          ("1" "subject company information")
          ("4" "solicitation or recommendation")
          ("8" "additional information"))
         ("sc-14d9-nuvalent"
          ("1" "subject company information")
          ("4" "solicitation or recommendation")
          ("8" "additional information"))
         ("sc-14d9-open-lending"
          ("1" "subject company information")
          ("4" "solicitation or recommendation")
          ("8" "additional information"))))
    (let* ((slug (nth 0 entry))
           (filing (edgar-fixtures-filing slug))
           (html (edgar-fixtures-html slug)))
      (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) html)))
        (should
         (equal
          (mapcar #'car (edgar-sections (edgar-text filing)))
          (mapcar #'number-to-string (number-sequence 1 9))))
        (dolist (item (cdr entry))
          (let ((body (edgar-section filing (car item))))
            (should (stringp body))
            (should
             (string-match-p
              (regexp-quote (cadr item))
              (downcase (edgar-fixtures-norm body))))))))))

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

(ert-deftest edgar-golden-wrapped-toc-item-residue-is-dropped ()
  "A wrapped table-of-contents Item does not shadow its Part-qualified body."
  (let ((sections (edgar-sections
                   (edgar-fixtures-text "diversity-10-kt-720762"))))
    (should-not (assoc "5" sections))
    (should (assoc "II.5" sections))))

(provide 'edgar-golden-prospectus-test)

;;; edgar-golden-prospectus-test.el ends here
