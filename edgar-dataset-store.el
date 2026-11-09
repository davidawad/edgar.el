;;; edgar-dataset-store.el --- Persisted data-set indexes and subprocess builds -*- lexical-binding: t; -*-

;;; Commentary:

;; The storage half of `edgar-dataset': indexes written under
;; `edgar-dataset-cache-directory' keyed by their source URLs, slice
;; files read back by byte range, builds run in a batch Emacs
;; subprocess, and `edgar-dataset-index-async', the load-or-build
;; driver shared by the Form 13F and N-PORT indexes.

;;; Code:

(require 'cl-lib)
(require 'subr-x)

(defvar edgar-dataset-cache-directory)
(defvar xbrl-user-agent)

(defconst edgar-dataset--result-marker "\n;;edgar-dataset-result\n"
  "Line that precedes the printed result of a batch subprocess.")

;;;; Persisted indexes

(defun edgar-dataset-index-directory (name urls &optional version)
  "Return the index directory for NAME built from source URLS.
VERSION distinguishes incompatible index layouts."
  (expand-file-name (format "index/%s-%s/"
                            name
                            (substring (secure-hash
                                        'sha1
                                        (prin1-to-string
                                         (cons version urls)))
                                       0 16))
                    edgar-dataset-cache-directory))

(defmacro edgar-dataset--with-print-settings (&rest body)
  "Run BODY with printer settings that make output readable."
  (declare (indent 0) (debug t))
  `(let ((print-length nil)
         (print-level nil)
         (print-circle nil)
         (print-escape-newlines t)
         (float-output-format nil))
     ,@body))

(defun edgar-dataset--write-buffer (file)
  "Write the current buffer atomically to FILE."
  (make-directory (file-name-directory file) t)
  (let ((partial (concat file ".part"))
        (coding-system-for-write 'utf-8-emacs-unix))
    (write-region (point-min) (point-max) partial nil 'silent)
    (rename-file partial file t)))

(defun edgar-dataset-write-object (file object)
  "Write OBJECT readably to FILE, replacing it atomically."
  (with-temp-buffer
    (edgar-dataset--with-print-settings
      (prin1 object (current-buffer)))
    (edgar-dataset--write-buffer file)))

(defun edgar-dataset-write-slices (file generator)
  "Write objects to FILE as separately readable slices.
GENERATOR is called with one argument, EMIT; calling (EMIT KEY OBJECT)
appends OBJECT.  Return a hash table from KEY to the (BEG . END) byte
range for `edgar-dataset-read-object'."
  (let ((bounds (make-hash-table :test #'equal)))
    (with-temp-buffer
      (edgar-dataset--with-print-settings
        (funcall generator
                 (lambda (key object)
                   (let ((beg (1- (position-bytes (point)))))
                     (prin1 object (current-buffer))
                     (insert "\n")
                     (puthash
                      key
                      (cons beg (1- (position-bytes (point))))
                      bounds)))))
      (edgar-dataset--write-buffer file))
    bounds))

(defun edgar-dataset-read-object (file &optional bounds)
  "Read the object stored in FILE, or only the slice BOUNDS of FILE.
BOUNDS is a (BEG . END) range from `edgar-dataset-write-slices'."
  (with-temp-buffer
    (let ((coding-system-for-read 'utf-8-emacs-unix))
      (insert-file-contents file nil (car bounds) (cdr bounds)))
    (goto-char (point-min))
    (read (current-buffer))))

;;;; Subprocess builds

(defun edgar-dataset-batch-run (function &rest args)
  "Print the result of FUNCTION applied to ARGS for `edgar-dataset-batch'.
Meant for `--eval' in a batch Emacs; exits with status 1 on error."
  (condition-case err
      (let ((result (apply function args)))
        (princ edgar-dataset--result-marker)
        (edgar-dataset--with-print-settings
          (prin1 result))
        (terpri)
        (kill-emacs 0))
    (error
     (princ
      (format "EDGAR dataset batch error: %s\n"
              (error-message-string err)))
     (kill-emacs 1))))

(defun edgar-dataset--batch-result (buffer)
  "Return the printed result in subprocess output BUFFER, or nil."
  (with-current-buffer buffer
    (goto-char (point-max))
    (when (search-backward edgar-dataset--result-marker nil t)
      (goto-char (match-end 0))
      (read (current-buffer)))))

(cl-defun
 edgar-dataset-batch
 (function args callback &key features variables name)
 "Call FUNCTION with ARGS in a batch Emacs and pass the result to CALLBACK.
FEATURES are required first; VARIABLES are symbols whose current values
are copied into the subprocess, along with `load-path'.  CALLBACK
receives (RESULT nil) on success and (nil ERROR-MESSAGE) on failure.
NAME names the process.  Return the process."
 (let* ((setup
         `(progn
            (setq load-path ',load-path)
            (require 'edgar-dataset)
            ,@
            (mapcar
             (lambda (var) `(setq ,var ',(symbol-value var)))
             (cons 'xbrl-user-agent variables))
            ,@
            (mapcar (lambda (feature) `(require ',feature)) features)
            (edgar-dataset-batch-run ',function
                                     ,@
                                     (mapcar
                                      (lambda (arg) `',arg) args))))
        (buffer
         (generate-new-buffer
          (format " *%s*" (or name "edgar-dataset-batch"))))
        (program
         (expand-file-name invocation-name invocation-directory)))
   (make-process
    :name (or name "edgar-dataset-batch")
    :buffer buffer
    :command
    (list
     program "-Q" "--batch" "--eval"
     (edgar-dataset--with-print-settings
       (prin1-to-string setup)))
    :connection-type 'pipe
    :noquery t
    :sentinel
    (lambda (process _event)
      (unless (process-live-p process)
        (let ((result
               (and (eq (process-exit-status process) 0)
                    (ignore-errors
                      (edgar-dataset--batch-result buffer)))))
          (if (and (eq (process-exit-status process) 0) result)
              (progn
                (kill-buffer buffer)
                (funcall callback result nil))
            (funcall callback
                     nil
                     (with-current-buffer buffer
                       (string-trim (buffer-string)))))))))))

(cl-defun
 edgar-dataset-index-async
 (callback &key directory build sources load features variables name)
 "Load the index in DIRECTORY or build it without blocking.
When DIRECTORY holds a summary.eld, call LOAD with DIRECTORY on a timer.
Otherwise call BUILD with SOURCES in a batch Emacs (see
`edgar-dataset-batch' for FEATURES, VARIABLES and NAME); BUILD returns
the index directory, which is passed to LOAD.  CALLBACK receives
\(INDEX nil) on success and (nil ERROR-MESSAGE) on failure.  Return the
subprocess, or nil when the cached index was loaded."
 (if (and directory
          (file-exists-p (expand-file-name "summary.eld" directory)))
     (progn
       (run-at-time
        0 nil
        (lambda () (funcall callback (funcall load directory) nil)))
       nil)
   (edgar-dataset-batch
    build (list sources)
    (lambda (result error)
      (if error
          (funcall callback nil error)
        (funcall callback (funcall load result) nil)))
    :features features
    :variables variables
    :name name)))

(provide 'edgar-dataset-store)
;;; edgar-dataset-store.el ends here
