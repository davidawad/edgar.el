(dolist (file '("src/edgar.el" "src/edgar-http.el"))
  (with-temp-buffer
    (insert-file-contents file)
    (condition-case err
        (check-parens)
      (error
       (princ
        (format "%s: %s at line %d column %d\n"
                file
                (error-message-string err)
                (line-number-at-pos)
                (current-column)))))))
