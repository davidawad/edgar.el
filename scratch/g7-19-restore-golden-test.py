from pathlib import Path
import subprocess

path = Path("test/edgar-golden-test.el")
base = subprocess.check_output(
    ["git", "show", "HEAD:test/edgar-golden-test.el"], text=True
)
old_comment = """;; appear in exactly the section it was taken from and in no other section --
;; so a shifted boundary, a merged Part or a lost section fails loudly -- and
;; the whole-text strings must still appear in the rendered filing.
"""
new_comment = """;; appear in exactly the section it was taken from and in no other section --
;; so a shifted boundary, a merged Part or a lost section fails loudly. A
;; section with no unique candidate still has an empty golden entry. The
;; whole-text strings must appear in the rendered filing.
"""
if base.count(old_comment) != 1:
    raise SystemExit("expected exactly one golden-test comment block")
base = base.replace(old_comment, new_comment)

test = '''(ert-deftest edgar-golden-g7-section-12-registration-generic-structure
    ()
  "Section 12 registration filings expose their generic document structure."
  (let
      ((markers
        '(("10-12B" "general form for registration of securities" "1")
          ("10-12G" "general form for registration of securities" "1")
          ("20FR12B"
           "registration statement pursuant to section 12"
           "I.1")
          ("20FR12G"
           "registration statement pursuant to section 12"
           "I.1")
          ("40FR12G"
           "registration statement pursuant to section 12 of the securities exchange act of 1934"
           nil))))
    (dolist (slug
             '("10-12b-middleby"
               "10-12b-kioni"
               "10-12b-mobility"
               "10-12g-biokey"
               "10-12g-feel-the-world"
               "10-12g-jlm-wnco"
               "20fr12b-clinuvel"
               "20fr12b-wise"
               "20fr12b-vicore"
               "20fr12g-chdgai"
               "20fr12g-greenbriar"
               "20fr12g-nec"
               "40fr12g-nuran"
               "40fr12g-bespoke"
               "40fr12g-cresco"))
      (let* ((filing (edgar-fixtures-filing slug))
             (entry (assoc (plist-get filing :form) markers))
             (html (edgar-fixtures-html slug))
             (marker (nth 1 entry))
             (filename (plist-get filing :doc))
             (item (nth 2 entry))
             tree
             primary
             body
             section)
        (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) html)))
          (setq
           tree (edgar-document-structure filing)
           primary (plist-get (plist-get tree :metadata) :primary-document)
           body (edgar-structure-section tree '("html" "body"))
           section (and item (edgar-section filing item))))
        (should (eq (plist-get tree :format) 'html))
        (should
         (equal (plist-get primary :type) (plist-get filing :form)))
        (should (equal (plist-get primary :filename) filename))
        (should (eq (plist-get primary :format) 'html))
        (should body)
        (should
         (string-search
          marker
          (downcase (edgar-fixtures-norm (plist-get body :body)))))
        (should (> (length (edgar-structure-text tree)) 0))
        (should (edgar-structure-nodes tree "body"))
        (when item
          (should section)
          (should (> (length section) 100)))))))

'''
anchor = "(ert-deftest edgar-golden-g7-s-8-pos-generic-item-access ()"
if base.count(anchor) != 1:
    raise SystemExit("expected exactly one insertion point")
base = base.replace(anchor, test + anchor)
path.write_text(base)
