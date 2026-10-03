;;; edgar-l2-diversity-test.el --- distinct-filer L2 regression tests -*- lexical-binding: t; -*-

(require 'ert)
(require 'edgar-fixtures)
(require 'edgar-forms)
(require 'edgar-asset-backed)
(require 'edgar-offerings)

(defun edgar-l2-diversity-test--metadata (slug)
  "Return fixture metadata for SLUG."
  (edgar-fixtures-read
   (edgar-fixtures-path (concat "fixtures/" slug ".eld"))))

(defun edgar-l2-diversity-test--xml (slug)
  "Read XML fixture SLUG."
  (with-temp-buffer
    (insert-file-contents
     (edgar-fixtures-path (concat "fixtures/" slug ".xml")))
    (buffer-string)))

(defun edgar-l2-diversity-test--assert-golden (slug actual)
  "Compare ACTUAL with SLUG's field snapshot, or update it on request."
  (let ((file
         (edgar-fixtures-path
          (concat "golden-fields/l2-" slug ".eld"))))
    (if (getenv "EDGAR_L2_GOLDEN_UPDATE")
        (with-temp-file file
          (let ((print-length nil)
                (print-level nil))
            (pp actual (current-buffer))))
      (should (equal actual (edgar-fixtures-read file))))))

(defun edgar-l2-diversity-test--c-ar-fields (value)
  "Return selected typed C-AR fields from VALUE."
  (list
   :issuer-cik (edgar-form-c-ar-issuer-cik value)
   :period (edgar-form-c-ar-period value)
   :issuer-name (edgar-form-c-ar-issuer-name value)
   :issuer-website (edgar-form-c-ar-issuer-website value)
   :current-employees (edgar-form-c-ar-current-employees value)
   :total-assets-current (edgar-form-c-ar-total-assets-current value)
   :revenue-current (edgar-form-c-ar-revenue-current value)
   :net-income-current (edgar-form-c-ar-net-income-current value)))

(defun edgar-l2-diversity-test--abs-ee-fields (value)
  "Return common ABS-EE fields from VALUE."
  (let ((first (car (edgar-abs-ee-data-assets value))))
    (list
     :asset-class (edgar-abs-ee-data-asset-class value)
     :asset-count (length (edgar-abs-ee-data-assets value))
     :first-asset-number (edgar-abs-ee-asset-asset-number first)
     :first-asset-type-number (edgar-abs-ee-asset-asset-type-number first)
     :first-property-name (edgar-abs-ee-asset-property-name first)
     :first-property-state (edgar-abs-ee-asset-property-state first)
     :first-original-loan-amount (edgar-abs-ee-asset-original-loan-amount first)
     :first-current-balance (edgar-abs-ee-asset-current-balance first))))

(ert-deftest edgar-l2-diversity-has-three-filers-for-audited-l2-forms
    ()
  "Every registered L2 form has fixtures from three distinct filing CIKs."
  (let ((l2-forms nil)
        (ciks-by-form (make-hash-table :test #'equal)))
    (maphash
     (lambda (form info)
       (when (eq (plist-get info :level) 'L2)
         (push form l2-forms)))
     edgar-forms--registry)
    (dolist
        (file
         (directory-files
          (edgar-fixtures-path "fixtures/") t "\\.eld\\'"))
      (let* ((slug (file-name-base file))
             (filing (edgar-l2-diversity-test--metadata slug))
             (form (replace-regexp-in-string
                    "/A\\'" "" (plist-get filing :form))))
        (when (member form l2-forms)
          (cl-pushnew (plist-get filing :cik)
                      (gethash form ciks-by-form)
                      :test #'equal))))
    (dolist (form l2-forms)
      (let ((count (length (gethash form ciks-by-form))))
        (unless (>= count 3)
          (ert-fail
           (format "%s has %d distinct filer CIKs; 3 required"
                   form count)))))))

(ert-deftest
    edgar-l2-diversity-g8-tender-offers-have-three-distinct-filers
    ()
  "The recorded SC TO-T Item goldens cover three distinct filing CIKs."
  (let ((ciks
         (delete-dups
          (mapcar
           (lambda (slug)
             (plist-get
              (edgar-l2-diversity-test--metadata slug)
              :cik))
           '("sc-to-t-biontech"
             "sc-to-t-cidara"
             "sc-to-t-tubemogul")))))
    (should (= (length ciks) 3))))

(ert-deftest edgar-l2-diversity-g8-def14a-has-three-distinct-filers ()
  "The reviewed DEF 14A sections cover three distinct filing CIKs."
  (let ((ciks
         (delete-dups
          (mapcar
           (lambda (slug)
             (plist-get
              (edgar-l2-diversity-test--metadata slug)
              :cik))
           '("def-14a-gme"
             "def-14a-encore"
             "def-14a-venture-global")))))
    (should (= (length ciks) 3))))

(ert-deftest
    edgar-l2-diversity-g8-proxy-mna-fixtures-use-distinct-filers
    ()
  "The added DEF 14C, DEFM14A and Schedule TO filings have distinct CIKs."
  (let ((ciks
         (delete-dups
          (mapcar
           (lambda (slug)
             (plist-get
              (edgar-l2-diversity-test--metadata slug)
              :cik))
           '("def-14c-pmgc"
             "defm14a-matrixx"
             "sc-to-c-cresco"
             "sc-to-i-pamt")))))
    (should (= (length ciks) 4))))

(ert-deftest edgar-l2-diversity-abs-ee-accessors-match-filer-goldens
    ()
  "ABS-EE XML from three filers preserves common asset-data fields."
  (dolist (slug
           '("abs-ee-bank5-sample"
             "abs-ee-deutsche"
             "abs-ee-cd2017-cd3"))
    (let* ((filing (edgar-l2-diversity-test--metadata slug))
           (xml (edgar-l2-diversity-test--xml slug))
           (documents
            `((:type "EX-102" :url ,(plist-get filing :url)))))
      (cl-letf (((symbol-function 'edgar-documents)
                 (lambda (_) documents))
                ((symbol-function 'edgar--fetch) (lambda (_) xml)))
        (let ((value (edgar-abs-ee-asset-data filing)))
          (should (edgar-abs-ee-data-p value))
          (edgar-l2-diversity-test--assert-golden
           slug (edgar-l2-diversity-test--abs-ee-fields value)))))))

(ert-deftest edgar-l2-diversity-c-ar-accessors-match-filer-goldens ()
  "C-AR XML from three filers preserves typed annual-report fields."
  (dolist (slug '("c-ar-qnetic" "c-ar-diaspora" "c-ar-kronos"))
    (let* ((filing (edgar-l2-diversity-test--metadata slug))
           (xml (edgar-l2-diversity-test--xml slug)))
      (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) xml)))
        (let ((value (edgar-form-c-ar filing)))
          (should (edgar-form-c-ar-p value))
          (edgar-l2-diversity-test--assert-golden
           slug (edgar-l2-diversity-test--c-ar-fields value)))))))

(ert-deftest
    edgar-l2-diversity-additional-filers-render-signature-text
    ()
  "Rendered additional filer documents retain their signature text offline."
  (dolist
      (entry
       '(("11-k-ball"
          "pursuant to the requirements of the securities exchange act")
         ("11-k-campbell"
          "pursuant to the requirements of the securities exchange act")
         ("40-f-suncor" "the registrant certifies that it")
         ("40-f-cibc" "the registrant certifies that it")
         ("6-k-sony" "has duly caused this report to be signed")
         ("6-k-ryojobaba"
          "has duly caused this report to be signed")))
    (let* ((slug (car entry))
           (filing (edgar-l2-diversity-test--metadata slug))
           (html (edgar-fixtures-html slug)))
      (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) html)))
        (let ((text (edgar-text filing)))
          (should (stringp text))
          (should
           (string-match-p
            (regexp-quote (cadr entry))
            (replace-regexp-in-string
             "[ \t\n ]+" " " (downcase text)))))))))

(provide 'edgar-l2-diversity-test)
;;; edgar-l2-diversity-test.el ends here
