;;; edgar-l2-diversity-test.el --- distinct-filer L2 regression tests -*- lexical-binding: t; -*-

(require 'ert)
(require 'edgar-fixtures)

(defun edgar-l2-diversity-test--metadata (slug)
  "Return fixture metadata for SLUG."
  (edgar-fixtures-read
   (edgar-fixtures-path (concat "fixtures/" slug ".eld"))))

(ert-deftest edgar-l2-diversity-has-three-filers-for-11k-40f-and-6k ()
  "Each under-covered L2 narrative form includes three SEC filers."
  (dolist (entry
           '(("11-K" "11-k-ko" "11-k-ball" "11-k-campbell")
             ("40-F" "40-f-shop" "40-f-suncor" "40-f-cibc")
             ("6-K" "6-k-tsm" "6-k-sony" "6-k-ryojobaba")))
    (let ((ciks
           (delete-dups
            (mapcar
             (lambda (slug)
               (plist-get (edgar-l2-diversity-test--metadata slug) :cik))
             (cdr entry)))))
      (should (= (length ciks) 3)))))

(ert-deftest edgar-l2-diversity-additional-filers-render-signature-text ()
  "Rendered additional filer documents retain their signature text offline."
  (dolist
      (entry
       '(("11-k-ball" "pursuant to the requirements of the securities exchange act")
         ("11-k-campbell" "pursuant to the requirements of the securities exchange act")
         ("40-f-suncor" "the registrant certifies that it")
         ("40-f-cibc" "the registrant certifies that it")
         ("6-k-sony" "has duly caused this report to be signed")
         ("6-k-ryojobaba" "has duly caused this report to be signed")))
    (let* ((slug (car entry))
           (filing (edgar-l2-diversity-test--metadata slug))
           (html (edgar-fixtures-html slug)))
      (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) html)))
        (let ((text (edgar-text filing)))
          (should (stringp text))
          (should
           (string-match-p
            (regexp-quote (cadr entry))
            (replace-regexp-in-string "[ \t\n ]+" " " (downcase text)))))))))

(provide 'edgar-l2-diversity-test)
;;; edgar-l2-diversity-test.el ends here
