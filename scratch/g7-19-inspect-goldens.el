;;; g7-19-inspect-goldens.el --- inspect scoped golden mismatch -*- lexical-binding: t; -*-

(require 'edgar-golden-test)

(let* ((slug "20fr12b-wise")
       (bodies (edgar-golden-test--bodies slug))
       (golden (edgar-fixtures-read
                (edgar-fixtures-path (concat "golden/" slug ".eld")))))
  (message "parsed: %S" (mapcar (lambda (body) (car body)) bodies))
  (message "goldens: %S" (mapcar #'car (plist-get golden :sections)))
  (message "II.16 body: %S" (cdr (assoc "II.16" bodies)))
  (message "II.16A body: %S" (cdr (assoc "II.16A" bodies))))

(let* ((slug "10-12b-mobility")
       (filing (edgar-fixtures-filing slug))
       (html (edgar-fixtures-html slug))
       tree)
  (cl-letf (((symbol-function 'edgar--fetch) (lambda (_) html)))
    (setq tree (edgar-document-structure filing)))
  (message "Mobility paragraphs: %d p nodes: %d body length: %d"
           (length (edgar-structure-paragraphs tree))
           (length (edgar-structure-nodes tree "p"))
           (length (plist-get (edgar-structure-section tree '("html" "body")) :body))))
