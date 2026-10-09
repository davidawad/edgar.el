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

(require 'edgar-expect-test-support)

(dolist (slug (edgar-expect--slugs))
  (let ((name (intern (concat "edgar-expect-" slug))))
    (ert-set-test
     name
     (make-ert-test
      :name name
      :body
      (let ((s slug))
        (lambda () (edgar-expect--check s)))))))

(ert-deftest edgar-expect-8ka-mdxg-2026-form-invariant ()
  "Check the exact 8-K/A form against its recorded MDXG filing."
  (let ((filing
         (edgar-expect--read (edgar-expect--file "8ka-mdxg-2026" ".eld"))))
    (should (equal (plist-get filing :form) "8-K/A"))
    (edgar-expect--check "8ka-mdxg-2026")))

(ert-deftest edgar-g7-owned-registrations-use-generic-document-trees ()
  "Read the assigned G7 registration fixtures through the shared tree API."
  (dolist
      (entry
       '(("index-424h-2026-q2" . html)
         ("index-424i-2026-q2" . html)
         ("index-8-a12g-2026-q2" . html)
         ("index-10-12b-2026-q2" . html)
         ("index-10-12g-2026-q2" . html)
         ("index-20fr12b-2026-q2" . html)
         ("index-20fr12g-2026-q2" . html)
         ("index-40fr12g-2026-q2" . html)
         ("index-aw-2026-q2" . html)
         ("index-effect-2026-q2" . xml)
         ("index-dos-2026-q2" . xml)
         ("index-dosltr-2026-q2" . text)
         ("index-drsltr-2026-q2" . html)
         ("index-f-1mef-2026-q2" . html)
         ("index-f-10-2026-q2" . html)
         ("index-f-10ef-2026-q2" . html)
         ("index-f-10pos-2026-q2" . html)
         ("index-f-3asr-2026-q2" . html)
         ("index-f-3mef-2026-q2" . html)
         ("index-f-n-2026-q2" . html)
         ("index-f-6-2026-q2" . html)
         ("index-f-6-pos-2026-q2" . html)
         ("index-f-6ef-2026-q2" . html)
         ("index-f-x-2026-q2" . html)
         ("index-pos-am-2026-q2" . html)
         ("index-pos-ami-2026-q2" . html)
         ("index-pos-ex-2026-q2" . html)
         ("index-posasr-2026-q2" . html)
         ("index-s-11-2026-q2" . html)
         ("index-s-1mef-2026-q2" . html)
         ("index-s-3asr-2026-q2" . html)
         ("index-s-3d-2026-q2" . html)
         ("index-s-3dpos-2026-q2" . html)
         ("index-s-3mef-2026-q2" . html)
         ("index-s-b-2026-q2" . html)
         ("index-sf-1-2026-q2" . html)
         ("index-sf-3-2026-q2" . html)
         ("index-suppl-2026-q2" . html)
         ("index-rw-2026-q2" . html)))
    (let* ((slug (car entry))
           (filing (edgar-expect--read (edgar-expect--file slug ".eld")))
           (primary (edgar-expect--primary slug))
           (invariant
            (assoc (plist-get filing :form) edgar-expect--invariants))
           tree)
      (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) primary)))
        (setq tree (edgar-document-structure filing)))
      (should (eq (plist-get tree :format) (cdr entry)))
      (should (plist-get tree :children))
      (should invariant)
      (should
       (string-match-p
        (replace-regexp-in-string
         "[ \t\n ]+" "" (nth 1 invariant))
        (replace-regexp-in-string
         "[ \t\n ]+" ""
         (downcase (edgar-structure-text tree)))))
      (when (eq (cdr entry) 'html)
        (should (edgar-structure-nodes tree "body"))))))

(provide 'edgar-expect-test)
;;; edgar-expect-test.el ends here
