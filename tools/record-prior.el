;;; record-prior.el --- record an OLDER filing per fixture -*- lexical-binding: t; -*-

;; Run manually (network), after tools/record-fixtures.el:
;;   emacs -Q --batch -L ../xbrl.el -L . -l tools/record-prior.el
;; For every test/fixtures/<slug>.eld (latest filing) without a <slug>-prior
;; twin, records the OLDEST filing of the same form and ticker still inside
;; the SEC's `recent' window (and under the size cap).  Layouts drift across
;; years, so older filings catch parser assumptions a current one never will.

;;; Code:

(require 'edgar)
(require 'seq)

(defvar edgar-prior-max-bytes 3000000
  "Skip filings whose primary document is larger than this.")

(defun edgar-prior--dir ()
  "Directory holding the fixtures."
  (expand-file-name "../test/fixtures/"
                    (file-name-directory
                     (or load-file-name buffer-file-name))))

(defun edgar-prior--read (file)
  "Read the Lisp object in FILE."
  (with-temp-buffer
    (insert-file-contents file)
    (read (current-buffer))))

(defun edgar-prior--save (slug filing html)
  "Write FILING and its HTML as fixture SLUG."
  (let ((base (expand-file-name slug (edgar-prior--dir)))
        (coding-system-for-write 'utf-8))
    (with-temp-file (concat base ".htm")
      (insert html))
    (call-process "gzip" nil nil nil "-9" "-f" (concat base ".htm"))
    (with-temp-file (concat base ".eld")
      (let ((print-length nil)
            (print-level nil))
        (prin1 filing (current-buffer))))))

(defun edgar-prior--record (slug latest)
  "Record the oldest usable filing for LATEST's form and ticker as SLUG-prior."
  (let* ((ticker (plist-get latest :ticker))
         (form (plist-get latest :form))
         (older
          (seq-remove
           (lambda (f)
             (equal (plist-get f :accn) (plist-get latest :accn)))
           (reverse (edgar-filings ticker form)))))
    (sleep-for 0.25)
    (catch 'done
      (dolist (f older)
        (let ((html
               (condition-case nil
                   (edgar-html f)
                 (error
                  nil))))
          (sleep-for 0.25)
          (when (and html (<= (length html) edgar-prior-max-bytes))
            (edgar-prior--save
             (concat slug "-prior")
             (plist-put (copy-sequence f) :ticker ticker) html)
            (message "  %s-prior: %s filed %s (%d bytes)"
                     slug
                     form
                     (plist-get f :filed)
                     (length html))
            (throw 'done t))))
      (message "  %s: no older filing available" slug))))

(dolist (file (directory-files (edgar-prior--dir) t "\\.eld\\'"))
  (let ((slug
         (file-name-sans-extension (file-name-nondirectory file))))
    (unless (or (string-suffix-p "-prior" slug)
                (file-exists-p
                 (expand-file-name (concat slug "-prior.eld")
                                   (edgar-prior--dir))))
      (edgar-prior--record slug (edgar-prior--read file)))))
(message "done")
