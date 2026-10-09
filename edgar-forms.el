;;; edgar-forms.el --- EDGAR form registry -*- lexical-binding: t; -*-

;;; Commentary:

;; Registry of the base forms observed in the 2026 Q2 SEC full index.
;; Every row has family, backend, level, sections-or-fields, volume, notes.

;; The rows live in `edgar-forms-filers', `edgar-forms-registration' and
;; `edgar-forms-periodic', grouped by form family.

;;; Code:

(require 'edgar-forms-filers)
(require 'edgar-forms-registration)
(require 'edgar-forms-periodic)

(defconst edgar-forms--registry
  (let ((table (make-hash-table :test 'equal))
        (rows (append edgar-forms-filers-rows
                      edgar-forms-registration-rows
                      edgar-forms-periodic-rows)))
    (pcase-dolist (`(,form ,family ,backend ,level ,sections ,volume ,notes)
                   (sort (copy-sequence rows)
                         (lambda (a b) (string< (car a) (car b)))))
      (puthash
       form
       (list
        :family family
        :backend backend
        :level level
        :sections-or-fields sections
        :volume volume
        :notes notes)
       table))
    table)
  "Registry mapping every observed base form to its coverage metadata.")

(defun edgar-form-info (form)
  "Return the registry plist for FORM, resolving amendments to their base form.
Signal `error` with FORM when it is not in the registry."
  (let* ((base (replace-regexp-in-string "/A\\'" "" form))
         (info (gethash base edgar-forms--registry)))
    (or info (error "Unknown EDGAR form: %s" form))))

(defun edgar-forms-by-family (family)
  "Return registry rows in FAMILY as (FORM . INFO) pairs."
  (let (forms)
    (maphash
     (lambda (form info)
       (when (equal family (plist-get info :family))
         (push (cons form info) forms)))
     edgar-forms--registry)
    (nreverse forms)))

(provide 'edgar-forms)

;;; edgar-forms.el ends here
