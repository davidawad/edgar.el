;;; make-golden.el --- pick verbatim golden strings from recorded filings -*- lexical-binding: t; -*-

;; Run manually:
;;   emacs -Q --batch -L ../xbrl.el/src -L src -L test -l tools/make-golden.el
;; Writes test/golden/<slug>.eld for every fixture: for each section key a few
;; verbatim sentences that occur in THAT section and in no other, and for
;; the whole text a few more spread through the filing.  They are stored as
;; literals; test/edgar-golden-test.el re-checks them on every run, so a
;; moved section boundary or a lost section shows up as a failing string.
;; Re-running regenerates every file -- review `git diff test/golden/'.

;;; Code:

(require 'edgar-fixtures)

(defconst edgar-golden--per-section 3
  "Strings kept per section.")
(defconst edgar-golden--per-text 6
  "Whole-text strings kept per filing.")

(defun edgar-golden--sentences (norm)
  "Candidate sentences of the normalized text NORM, 40-150 chars."
  (let ((out nil)
        (start 0))
    (while (string-match "[.;:] " norm start)
      (let ((s
             (string-trim
              (substring norm start (1+ (match-beginning 0))))))
        (when (<= 40 (length s) 150)
          (push s out)))
      (setq start (match-end 0)))
    (nreverse out)))

(defun edgar-golden--digits (s)
  "Number of digit characters in S."
  (cl-count-if (lambda (c) (<= ?0 c ?9)) s))

(defun edgar-golden--order (cands)
  "Order CANDS: first, the most numeric one, last, then the rest."
  (when cands
    (let* ((first (car cands))
           (last (car (last cands)))
           (mid
            (cl-reduce
             (lambda (a b)
               (if (> (edgar-golden--digits b)
                      (edgar-golden--digits a))
                   b
                 a))
             (or (butlast (cdr cands)) (list first))))
           (rest
            (cl-set-difference
             cands
             (list first mid last)
             :test #'equal)))
      (cl-remove-duplicates
       (append (list first mid last) rest)
       :test #'equal
       :from-end t))))

(defun edgar-golden--unique-in (str key bodies)
  "Non-nil if STR occurs in KEY's body and in no other of BODIES (alist)."
  (and (string-search str (cdr (assoc key bodies)))
       (cl-notany
        (lambda (b)
          (and (not (equal (car b) key)) (string-search str (cdr b))))
        bodies)))

(defun edgar-golden--section (key bodies)
  "Golden strings for KEY, verbatim from its body in BODIES."
  (let* ((body (cdr (assoc key bodies)))
         (cands (edgar-golden--order (edgar-golden--sentences body)))
         (picked
          (seq-take (seq-filter
                     (lambda (s)
                       (edgar-golden--unique-in s key bodies))
                     cands)
                    edgar-golden--per-section)))
    (or
     picked
     ;; Tiny section: fall back to its opening words (heading included).
     (let ((s (substring body 0 (min 70 (length body)))))
       (when (and (>= (length s) 12)
                  (edgar-golden--unique-in s key bodies))
         (list s))))))

(defun edgar-golden--text (norm)
  "Whole-text golden strings spread through NORM, each occurring once."
  (let* ((cands (edgar-golden--sentences norm))
         (n (length cands))
         (picks nil))
    (when (> n 0)
      (dotimes (i edgar-golden--per-text)
        (let* ((target
                (floor
                 (* n
                    (+ 0.08
                       (* i
                          (/ 0.84
                             (max 1 (1- edgar-golden--per-text))))))))
               (window
                (seq-take (nthcdr (min target (1- n)) cands) 12))
               (best
                (cl-reduce
                 (lambda (a b)
                   (if (> (edgar-golden--digits b)
                          (edgar-golden--digits a))
                       b
                     a))
                 window))
               (count 0)
               (pos 0))
          (while (setq pos (string-search best norm pos))
            (cl-incf count)
            (cl-incf pos))
          (when (and best (= count 1))
            (cl-pushnew best picks :test #'equal)))))
    (nreverse picks)))

(defun edgar-golden--build (slug)
  "Golden plist for fixture SLUG."
  (let* ((text (edgar-fixtures-text slug))
         (norm (edgar-fixtures-norm text))
         (secs (edgar-sections text))
         (bodies
          (mapcar
           (lambda (s)
             (cons (car s) (edgar-fixtures-norm (cdr s))))
           secs)))
    (list
     :sections
     (delq
      nil
      (mapcar
       (lambda (b)
         (let ((g (edgar-golden--section (car b) bodies)))
           (and g (cons (car b) g))))
       bodies))
     :text (edgar-golden--text norm))))

(let ((dir (edgar-fixtures-path "golden/")))
  (make-directory dir t)
  (dolist (slug (edgar-fixtures-slugs))
    (let ((g (edgar-golden--build slug)))
      (with-temp-file (expand-file-name (concat slug ".eld") dir)
        (let ((print-length nil)
              (print-level nil)
              (print-escape-newlines t))
          (pp g (current-buffer))))
      (message
       "%-24s %2d sections, %2d section strings, %d text strings"
       slug (length (plist-get g :sections))
       (apply #'+
              (mapcar
               (lambda (s) (length (cdr s))) (plist-get g :sections)))
       (length (plist-get g :text))))))

;;; make-golden.el ends here
