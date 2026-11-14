(dolist (file '("src/edgar-http.el" "src/edgar.el"))
  (with-temp-buffer
    (insert-file-contents file)
    (dolist (line '(83 117 119 287 308 310))
      (goto-char (point-min))
      (forward-line (1- line))
      (princ (format "%s line %d depth=%d parse=%S\n"
                     file line (car (syntax-ppss)) (syntax-ppss))))))
