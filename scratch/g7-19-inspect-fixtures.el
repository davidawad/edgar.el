(require 'edgar-fixtures)
(require 'seq)

(dolist (slug '("10-12b-middleby"
                "10-12g-biokey"
                "20fr12b-clinuvel"
                "20fr12g-chdgai"
                "40fr12g-nuran"))
  (let* ((filing (edgar-fixtures-filing slug))
         (text (edgar-fixtures-text slug))
         (html (edgar-fixtures-html slug))
         tree)
    (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) html)))
      (setq tree (edgar-document-structure filing)))
    (princ
     (format "\n%s %s\ntext-start: %s\nsections: %S\nheadings: %S\nparagraphs: %d\n"
             slug
             (plist-get filing :form)
             (substring (edgar-fixtures-norm text)
                        0 (min 600 (length (edgar-fixtures-norm text))))
             (mapcar #'car (edgar-sections text))
             (mapcar (lambda (heading)
                       (plist-get heading :title))
                     (seq-take (edgar-structure-headings tree) 20))
             (length (edgar-structure-paragraphs tree))))))
