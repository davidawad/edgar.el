(add-to-list 'load-path "/Users/david/projects/Personal/emacs/xbrl.el/src")
(add-to-list 'load-path "src")
(add-to-list 'load-path "test")
(require 'ert)
(require 'edgar-expect-test)
(require 'edgar-golden-test)
(require 'edgar-forms-test)
(load "form-coverage-test.el" nil t)
(let ((selected
       (if (getenv "EDGAR_EXPECT_UPDATE")
           '(edgar-expect-15-15d-plus-automation
             edgar-expect-irannotice-intel)
         '(edgar-expect-15-15d-plus-automation
           edgar-expect-irannotice-intel
           edgar-golden-15-15d-plus-automation
           edgar-golden-irannotice-intel
           edgar-golden-g9-generic-html-body-access
           edgar-forms-snapshot-resolves-to-registry
           edgar-forms-rows-have-valid-coverage-metadata
           edgar-forms-family-totals-match-coverage-doc
           edgar-form-coverage-offline-baseline-passes
           edgar-form-coverage-report-has-form-level-and-volume))))
  (ert-run-tests-batch-and-exit
   (regexp-opt (mapcar #'symbol-name selected))))
