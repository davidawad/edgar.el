;;; g10-focused-test.el --- run the 11 scoped G10 expectations -*- lexical-binding: t; -*-

(add-to-list
 'load-path
 (expand-file-name "../test" (file-name-directory load-file-name)))
(require 'edgar-expect-test)

(ert-run-tests-batch-and-exit
 '(member edgar-expect-40-17f2-fundrise
          edgar-expect-40-24b2-hit-investment
          edgar-expect-40-33-180degree
          edgar-expect-40-8f-2-chesapeake
          edgar-expect-497j-360
          edgar-expect-app-ntc-advisors-preferred
          edgar-expect-app-ordr-great-elm
          edgar-expect-app-wd-guggenheim
          edgar-expect-app-wdg-peartree
          edgar-expect-ct-order-janus-henderson
          edgar-expect-del-am-jpmorgan))

;;; g10-focused-test.el ends here
