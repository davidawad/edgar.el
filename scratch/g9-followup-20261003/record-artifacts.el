(add-to-list 'load-path "/Users/david/projects/Personal/emacs/xbrl.el/src")
(add-to-list 'load-path "src")
(add-to-list 'load-path "test")
(add-to-list 'load-path "tools")
(require 'edgar-expect-test)
(setenv "EDGAR_EXPECT_UPDATE" "1")
(dolist (slug '("cert-braveheart"
                "dstrbrpt-inter-american"
                "revoked-healing"))
  (edgar-expect--check slug)
  (princ (format "wrote expectation %s\n" slug)))
(setenv "EDGAR_EXPECT_UPDATE" nil)
(cl-letf (((symbol-function 'edgar-fixtures-slugs)
           (lambda ()
             '("cert-braveheart"
               "dstrbrpt-inter-american"
               "revoked-healing"))))
  (load (expand-file-name "tools/make-golden.el" default-directory) nil t))
