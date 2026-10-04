;;; record-fixtures.el --- record real SEC filings as offline test fixtures -*- lexical-binding: t; -*-

;; Run manually (network):
;;   emacs -Q --batch -L ../xbrl.el -L . -l tools/record-fixtures.el
;; Writes test/fixtures/<slug>.htm.gz (the filing's primary document) and
;; <slug>.eld (the filing plist) for each form in `edgar-record-forms', using
;; the first candidate ticker whose latest filing of that form is under
;; `edgar-record-max-bytes'.  Existing fixtures are kept: delete a pair to
;; re-record it.

;;; Code:

(require 'edgar)

(defvar edgar-record-max-bytes 1800000
  "Skip filings whose primary document is larger than this.")

(defvar edgar-record-forms
  '(("10-K" "GME" "F" "KO" "AAPL")
    ("10-K/A"
     "TSLA"
     "NFLX"
     "F"
     "GM"
     "T"
     "WBD"
     "PARA"
     "INTC"
     "BA"
     "UAL"
     "AAL"
     "DAL"
     "GME")
    ("10-Q" "GME" "F" "KO" "AAPL")
    ("8-K" "AAPL" "GME" "F")
    ("20-F" "TSM" "BABA" "SONY" "NVO" "BHP" "TM")
    ("40-F" "SHOP" "TD" "RY" "ENB" "BMO" "BNS" "CNQ")
    ("6-K" "TSM" "BABA" "SONY" "NVO")
    ("S-1"
     "COIN"
     "ABNB"
     "RIVN"
     "RDDT"
     "CART"
     "ARM"
     "KVYO"
     "CAVA"
     "BIRK"
     "ONON"
     "DUOL"
     "RBLX"
     "SNOW"
     "ASAN")
    ("DEF 14A" "GME" "F" "KO" "AAPL")
    ("11-K"
     "KO"
     "F"
     "GME"
     "AAPL"
     "T"
     "UPS"
     "CAT"
     "DE"
     "HD"
     "WMT"
     "TGT"
     "PG"
     "JNJ"
     "MMM")
    ("4" "AAPL" "GME" "F")
    ("13F-HR" "BRK-B")
    ("SCHEDULE 13G" "GME" "AAPL" "F" "KO")
    ("144" "AAPL" "GME" "F"))
  "Alist of (FORM . CANDIDATE-TICKERS), tried in order.")

(defun edgar-record--slug (form ticker)
  (concat
   (downcase
    (replace-regexp-in-string "[^A-Za-z0-9]+" "-" (remove ?/ form)))
   "-" (downcase ticker)))

(defun edgar-record--dir ()
  (expand-file-name "../test/fixtures/"
                    (file-name-directory
                     (or load-file-name buffer-file-name))))

(defun edgar-record--have (form)
  "Non-nil if a fixture for FORM already exists."
  (directory-files (edgar-record--dir)
                   nil
                   (concat
                    "\\`"
                    (regexp-quote (edgar-record--slug form ""))
                    ".*\\.eld\\'")))

(defun edgar-record--try (form ticker)
  "Record FORM for TICKER; return the slug, or nil if unsuitable."
  (condition-case err
      (let ((f (edgar-latest ticker form)))
        (sleep-for 0.25)
        (when f
          (let ((html (edgar-html f)))
            (sleep-for 0.25)
            (if (> (length html) edgar-record-max-bytes)
                (progn
                  (message "  %s %s too big (%d)"
                           form
                           ticker
                           (length html))
                  nil)
              (let* ((slug (edgar-record--slug form ticker))
                     (base
                      (expand-file-name slug (edgar-record--dir)))
                     (coding-system-for-write 'utf-8))
                (with-temp-file (concat base ".htm")
                  (insert html))
                (call-process "gzip"
                              nil
                              nil
                              nil
                              "-9"
                              "-f"
                              (concat base ".htm"))
                (with-temp-file (concat base ".eld")
                  (let ((print-length nil)
                        (print-level nil))
                    (prin1 (plist-put
                            (copy-sequence f)
                            :ticker ticker)
                           (current-buffer))))
                (message "  recorded %s (%d bytes html)"
                         slug
                         (length html))
                slug)))))
    (error
     (message "  %s %s: %s" form ticker (error-message-string err))
     nil)))

(make-directory (edgar-record--dir) t)
(dolist (spec edgar-record-forms)
  (let ((form (car spec)))
    (if (edgar-record--have form)
        (message "%s: already recorded" form)
      (message "%s:" form)
      (or (seq-some
           (lambda (tk) (edgar-record--try form tk)) (cdr spec))
          (message "  !! no candidate worked for %s" form)))))
(message "done")
