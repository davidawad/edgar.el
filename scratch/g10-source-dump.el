;;; g10-source-dump.el --- inspect local G10 fixture text -*- lexical-binding: t; -*-

(add-to-list
 'load-path
 (expand-file-name "../test" (file-name-directory load-file-name)))
(require 'edgar-expect-test)

(dolist (slug
        '("40-17f2-fundrise"
          "40-24b2-hit-investment"
          "40-33-180degree"
          "40-8f-2-chesapeake"
          "497j-360"
          "app-ntc-advisors-preferred"
          "app-ordr-great-elm"
          "app-wd-guggenheim"
          "app-wdg-peartree"
          "ct-order-janus-henderson"
          "del-am-jpmorgan"))
  (let* ((filing (edgar-expect--read (edgar-expect--file slug ".eld")))
         (primary (edgar-expect--primary slug))
         text)
    (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) primary)))
      (setq text (edgar-text filing)))
    (princ (format "\n--- %s | %s ---\n%s\n"
                   slug
                   (plist-get filing :form)
                   (substring
                    (replace-regexp-in-string "[ \t\n]+" " " text)
                    0 400)))))

;;; g10-source-dump.el ends here
