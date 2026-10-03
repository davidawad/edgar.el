;;; form-coverage-test.el --- Tests for the form coverage gate -*- lexical-binding: t; -*-

;;; Commentary:

;; Mutation checks for registry and fixture drift plus network-index parsing.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'edgar-index)

(defconst edgar-form-coverage-test--directory
  (file-name-directory (or load-file-name buffer-file-name)))

(add-to-list
 'load-path
 (expand-file-name "../tools" edgar-form-coverage-test--directory))

(require 'edgar-form-coverage)

(defun edgar-form-coverage-test--messages (problems)
  "Join PROBLEMS for readable assertions."
  (mapconcat #'identity problems "\n"))

(defun edgar-form-coverage-test--write (file contents)
  "Write CONTENTS to FILE, creating its directory."
  (make-directory (file-name-directory file) t)
  (with-temp-file file
    (insert contents)))

(defun edgar-form-coverage-test--seed-l2-artifacts (root backend count)
  "Create COUNT complete L2 test filings under ROOT for BACKEND."
  (let ((fixtures (expand-file-name "fixtures" root))
        (expects (expand-file-name "expect" root))
        (goldens (expand-file-name "golden" root))
        (field-goldens (expand-file-name "golden-fields" root)))
    (dotimes (index count)
      (let* ((number (1+ index))
             (slug (format "filer-%d" number))
             (primary-suffix (if (eq backend 'xml) ".xml" ".htm.gz"))
             (golden-dir (if (eq backend 'xml) field-goldens goldens)))
        (edgar-form-coverage-test--write
         (expand-file-name (concat slug ".eld") fixtures)
         (format "(:form \"TEST-FORM\" :cik %d)\n" (+ 1000 number)))
        (edgar-form-coverage-test--write
         (expand-file-name (concat slug primary-suffix) fixtures) "fixture")
        (edgar-form-coverage-test--write
         (expand-file-name (concat slug ".eld") expects) "(:ok t)\n")
        (edgar-form-coverage-test--write
         (expand-file-name (concat slug ".eld") golden-dir)
         "(:fields (value))\n")))))

(defun edgar-form-coverage-test--registry (level &optional backend)
  "Return a one-row test registry at LEVEL using BACKEND or HTML."
  (let ((registry (make-hash-table :test #'equal)))
    (puthash
     "TEST-FORM"
     (list
      :family "Test"
      :backend (or backend 'html)
      :level level
      :sections-or-fields nil
      :volume 1
      :notes nil)
     registry)
    registry))

(ert-deftest edgar-form-coverage-offline-baseline-passes ()
  "The committed snapshot and registry satisfy the offline gate."
  (should-not (edgar-coverage-problems)))

(ert-deftest edgar-form-coverage-legacy-sc-13d-amendment-is-generic-l1 ()
  "A primary SC 13D/A body supplies the base SC 13D generic fixture."
  (let* ((info (edgar-form-info "SC 13D"))
         (filing
          (edgar-coverage--read-object
           (expand-file-name "sc-13d-000114036124012291.eld"
                             edgar-coverage-fixture-directory))))
    (should (eq (plist-get info :backend) 'html))
    (should (eq (plist-get info :level) 'L1))
    (should (equal (plist-get filing :form) "SC 13D/A"))
    (should (equal (edgar-coverage--base-form (plist-get filing :form))
                   "SC 13D"))
    (should (edgar-coverage--primary-artifact-p
             "sc-13d-000114036124012291"
             'html
             edgar-coverage-fixture-directory))
    (should
     (file-exists-p
      (expand-file-name "sc-13d-000114036124012291.eld"
                        edgar-coverage-expect-directory)))
    (should
     (file-exists-p
      (expand-file-name "sc-13d-000114036124012291.eld"
                        edgar-coverage-golden-directory)))))

(ert-deftest edgar-form-coverage-l2-requires-three-distinct-filers ()
  "An L2 form needs three distinct filer CIKs, not three filings."
  (let* ((root (make-temp-file "edgar-coverage-diversity-" t))
         (snapshot (expand-file-name "snapshot.txt" root)))
    (unwind-protect
        (progn
          (edgar-form-coverage-test--write snapshot "1 TEST-FORM\n")
          (edgar-form-coverage-test--seed-l2-artifacts root 'html 2)
          (let* ((fixtures (expand-file-name "fixtures" root))
                 (expects (expand-file-name "expect" root))
                 (goldens (expand-file-name "golden" root)))
            (edgar-form-coverage-test--write
             (expand-file-name "same-filer-prior.eld" fixtures)
             "(:form \"TEST-FORM\" :cik 1001)\n")
            (edgar-form-coverage-test--write
             (expand-file-name "same-filer-prior.htm.gz" fixtures)
             "fixture")
            (edgar-form-coverage-test--write
             (expand-file-name "same-filer-prior.eld" expects) "(:ok t)\n")
            (edgar-form-coverage-test--write
             (expand-file-name "same-filer-prior.eld" goldens)
             "(:text (\"ok\"))\n")
            (let ((messages
                   (edgar-form-coverage-test--messages
                    (edgar-coverage-problems
                     :registry (edgar-form-coverage-test--registry 'L2)
                     :snapshot-file snapshot
                     :fixture-directory fixtures
                     :expect-directory expects
                     :golden-directory goldens))))
              (should
               (string-match-p
                "2 distinct filer CIKs; 3 required" messages)))
            (edgar-form-coverage-test--seed-l2-artifacts root 'html 3)
            (should-not
             (edgar-coverage-problems
              :registry (edgar-form-coverage-test--registry 'L2)
              :snapshot-file snapshot
              :fixture-directory fixtures
              :expect-directory expects
              :golden-directory goldens))))
      (delete-directory root t))))

(ert-deftest edgar-form-coverage-reports-every-l2-diversity-gap ()
  "Report every L2 form below the distinct-filer minimum in one pass."
  (let* ((root (make-temp-file "edgar-coverage-all-gaps-" t))
         (registry (make-hash-table :test #'equal))
         (records nil))
    (unwind-protect
        (progn
          (dolist (form '("TEST-FORM-A" "TEST-FORM-B"))
            (puthash
             form
             (list :family "Test"
                   :backend 'html
                   :level 'L2
                   :sections-or-fields nil
                   :volume 1
                   :notes nil)
             registry)
            (let ((slug (downcase form)))
              (edgar-form-coverage-test--write
               (expand-file-name (concat slug ".eld") root)
               (format "(:form %S :cik %d)\n"
                       form (if (equal form "TEST-FORM-A") 1001 2001)))
              (push (cons form slug) records)))
          (let ((problems
                 (edgar-coverage--l2-diversity-problems
                  registry records root)))
            (should (= (length problems) 2))
            (should
             (member
              "TEST-FORM-A: L2 diversity has 1 distinct filer CIKs; 3 required"
              problems))
            (should
             (member
              "TEST-FORM-B: L2 diversity has 1 distinct filer CIKs; 3 required"
              problems))))
      (delete-directory root t))))

(ert-deftest edgar-form-coverage-excludes-partial-submission-excerpts ()
  "Partial SEC excerpts remain parser tests, not complete-form fixtures."
  (let* ((records-and-problems
          (edgar-coverage--fixture-records
           edgar-forms--registry edgar-coverage-fixture-directory))
         (records (car records-and-problems)))
    (should-not (member '("10-K" . "10-k-bd-1998") records))
    (should-not (cdr records-and-problems))
    (should-not (edgar-coverage-problems))))
(ert-deftest edgar-form-coverage-g9-primary-fixtures-are-not-l0 ()
  "A G9 form with a recorded primary document must not remain L0."
  (let* ((fixtures edgar-coverage-fixture-directory)
         (records
          (car (edgar-coverage--fixture-records
                edgar-forms--registry fixtures))))
    (dolist (record records)
      (let* ((form (car record))
             (slug (cdr record))
             (info (gethash form edgar-forms--registry)))
        (when (and (equal (plist-get info :family)
                          "G9 Periodic & event narrative")
                   (eq (plist-get info :level) 'L0)
                   (edgar-coverage--primary-artifact-p
                    slug (plist-get info :backend) fixtures))
          (ert-fail
           (format "%s has primary fixture %s but remains L0"
                   form slug)))))))

(ert-deftest edgar-form-coverage-index-samples-have-no-low-volume-l0-rows ()
  "Do not promote low-volume L0 forms absent from the recorded index samples."
  (let ((low-volume-l0 (make-hash-table :test #'equal))
        (q2
         (edgar-index--parse
          (with-temp-buffer
            (insert-file-contents
             (expand-file-name "fixtures/form-index-2026-q2.idx"
                               edgar-form-coverage-test--directory))
            (buffer-string))))
        (q3
         (edgar-index--parse
          (with-temp-buffer
            (insert-file-contents
             (expand-file-name "fixtures/form-index-2026-09-30.idx"
                               edgar-form-coverage-test--directory))
            (buffer-string)))))
    (maphash
     (lambda (form info)
       (when (and (eq (plist-get info :level) 'L0)
                  (<= (plist-get info :volume) 5))
         (puthash form t low-volume-l0)))
     edgar-forms--registry)
    (should-not
     (seq-some
      (lambda (filing)
        (gethash (plist-get filing :form) low-volume-l0))
      (append q2 q3)))))

(ert-deftest edgar-form-coverage-registry-row-removal-names-form ()
  "Removing a registry row fails with that form name."
  (let ((registry (copy-hash-table edgar-forms--registry)))
    (remhash "4" registry)
    (let ((messages
           (edgar-form-coverage-test--messages
            (edgar-coverage-problems :registry registry))))
      (should (string-match-p "unknown EDGAR form 4" messages)))))

(ert-deftest edgar-form-coverage-snapshot-mutation-names-unknown-form
    ()
  "A newly observed snapshot form fails with its name."
  (let ((snapshot (make-temp-file "edgar-coverage-snapshot-")))
    (unwind-protect
        (progn
          (with-temp-file snapshot
            (insert-file-contents edgar-coverage-snapshot-file)
            (goto-char (point-max))
            (insert "\n1 NEVER-SEEN-BEFORE\n"))
          (let ((messages
                 (edgar-form-coverage-test--messages
                  (edgar-coverage-problems :snapshot-file snapshot))))
            (should (string-match-p "NEVER-SEEN-BEFORE" messages))))
      (delete-file snapshot))))

(ert-deftest edgar-form-coverage-fixture-removal-names-l1-form ()
  "Removing an L1 fixture artifact fails with the form name."
  (let* ((root (make-temp-file "edgar-coverage-fixtures-" t))
         (fixtures (expand-file-name "fixtures" root))
         (expects (expand-file-name "expect" root))
         (goldens (expand-file-name "golden" root))
         (snapshot (expand-file-name "snapshot.txt" root))
         (metadata (expand-file-name "test.eld" fixtures))
         (primary (expand-file-name "test.htm.gz" fixtures)))
    (unwind-protect
        (progn
          (edgar-form-coverage-test--write snapshot "1 TEST-FORM\n")
          (edgar-form-coverage-test--write
           metadata "(:form \"TEST-FORM\")\n")
          (edgar-form-coverage-test--write primary "fixture")
          (edgar-form-coverage-test--write
           (expand-file-name "test.eld" expects) "(:ok t)\n")
          (make-directory goldens t)
          (should-not
           (edgar-coverage-problems
            :registry
            (edgar-form-coverage-test--registry 'L1)
            :snapshot-file snapshot
            :fixture-directory fixtures
            :expect-directory expects
            :golden-directory goldens))
          (delete-file primary)
          (let ((messages
                 (edgar-form-coverage-test--messages
                  (edgar-coverage-problems
                   :registry
                   (edgar-form-coverage-test--registry 'L1)
                   :snapshot-file snapshot
                   :fixture-directory fixtures
                   :expect-directory expects
                   :golden-directory goldens))))
            (should (string-match-p "TEST-FORM" messages))
            (should (string-match-p "primary document" messages))))
      (delete-directory root t))))

(ert-deftest edgar-form-coverage-skips-submission-excerpts ()
  "A supplemental complete-submission excerpt is not a primary fixture."
  (let* ((root (make-temp-file "edgar-coverage-excerpt-" t))
         (fixtures (expand-file-name "fixtures" root)))
    (unwind-protect
        (progn
          (make-directory fixtures t)
          (with-temp-file (expand-file-name "excerpt.eld" fixtures)
            (insert
             "(:form \"TEST-FORM\" :fixture-kind \"SEC complete-submission excerpt\")\n"))
          (let ((result
                 (edgar-coverage--fixture-records
                  (edgar-form-coverage-test--registry 'L2)
                  fixtures)))
            (should-not (car result))
            (should-not (cdr result))))
      (delete-directory root t))))

(ert-deftest edgar-form-coverage-xml-fixture-removal-names-l1-form ()
  "An XML L1 fixture passes, and removing it fails with the form name."
  (let* ((root (make-temp-file "edgar-coverage-xml-fixture-" t))
         (fixtures (expand-file-name "fixtures" root))
         (expects (expand-file-name "expect" root))
         (goldens (expand-file-name "golden" root))
         (snapshot (expand-file-name "snapshot.txt" root))
         (primary (expand-file-name "test.xml" fixtures)))
    (unwind-protect
        (progn
          (edgar-form-coverage-test--write snapshot "1 TEST-FORM\n")
          (edgar-form-coverage-test--write
           (expand-file-name "test.eld"
                             fixtures)
           "(:form \"TEST-FORM\")\n")
          (edgar-form-coverage-test--write primary "<fixture/>")
          (edgar-form-coverage-test--write
           (expand-file-name "test.eld" expects) "(:ok t)\n")
          (make-directory goldens t)
          (should-not
           (edgar-coverage-problems
            :registry
            (edgar-form-coverage-test--registry 'L1 'xml)
            :snapshot-file snapshot
            :fixture-directory fixtures
            :expect-directory expects
            :golden-directory goldens))
          (delete-file primary)
          (let ((messages
                 (edgar-form-coverage-test--messages
                  (edgar-coverage-problems
                   :registry
                   (edgar-form-coverage-test--registry 'L1 'xml)
                   :snapshot-file snapshot
                   :fixture-directory fixtures
                   :expect-directory expects
                   :golden-directory goldens))))
            (should (string-match-p "TEST-FORM" messages))
            (should
             (string-match-p "XML primary document" messages))))
      (delete-directory root t))))

(ert-deftest edgar-form-coverage-pdf-fixture-removal-names-l1-form ()
  "A PDF L1 fixture passes, and removing it fails with the form name."
  (let* ((root (make-temp-file "edgar-coverage-pdf-fixture-" t))
         (fixtures (expand-file-name "fixtures" root))
         (expects (expand-file-name "expect" root))
         (goldens (expand-file-name "golden" root))
         (snapshot (expand-file-name "snapshot.txt" root))
         (primary (expand-file-name "test.pdf" fixtures)))
    (unwind-protect
        (progn
          (edgar-form-coverage-test--write snapshot "1 TEST-FORM\n")
          (edgar-form-coverage-test--write
           (expand-file-name "test.eld" fixtures)
           "(:form \"TEST-FORM\")\n")
          (edgar-form-coverage-test--write primary "%PDF fixture")
          (edgar-form-coverage-test--write
           (expand-file-name "test.eld" expects) "(:ok t)\n")
          (make-directory goldens t)
          (should-not
           (edgar-coverage-problems
            :registry
            (edgar-form-coverage-test--registry 'L1 'pdf)
            :snapshot-file snapshot
            :fixture-directory fixtures
            :expect-directory expects
            :golden-directory goldens))
          (delete-file primary)
          (let ((messages
                 (edgar-form-coverage-test--messages
                  (edgar-coverage-problems
                   :registry
                   (edgar-form-coverage-test--registry 'L1 'pdf)
                   :snapshot-file snapshot
                   :fixture-directory fixtures
                   :expect-directory expects
                   :golden-directory goldens))))
            (should (string-match-p "TEST-FORM" messages))
            (should (string-match-p "PDF primary document" messages))))
      (delete-directory root t))))

(ert-deftest edgar-form-coverage-xml-l2-requires-field-golden ()
  "An XML L2 fixture uses the typed field-golden directory."
  (let* ((root (make-temp-file "edgar-coverage-xml-l2-" t))
         (fixtures (expand-file-name "fixtures" root))
         (expects (expand-file-name "expect" root))
         (goldens (expand-file-name "golden" root))
         (field-goldens (expand-file-name "golden-fields" root))
         (snapshot (expand-file-name "snapshot.txt" root))
         (primary (expand-file-name "filer-1.xml" fixtures))
         (golden (expand-file-name "filer-1.eld" field-goldens)))
    (unwind-protect
        (progn
          (edgar-form-coverage-test--write snapshot "1 TEST-FORM\n")
          (edgar-form-coverage-test--seed-l2-artifacts root 'xml 3)
          (delete-file
           (expand-file-name "filer-2.eld" field-goldens))
          (delete-file
           (expand-file-name "filer-3.eld" field-goldens))
          (should-not
           (edgar-coverage-problems
            :registry
            (edgar-form-coverage-test--registry 'L2 'xml)
            :snapshot-file snapshot
            :fixture-directory fixtures
            :expect-directory expects
            :golden-directory goldens
            :field-golden-directory field-goldens))
          (delete-file golden)
          (let ((messages
                 (edgar-form-coverage-test--messages
                  (edgar-coverage-problems
                   :registry
                   (edgar-form-coverage-test--registry 'L2 'xml)
                   :snapshot-file snapshot
                   :fixture-directory fixtures
                   :expect-directory expects
                   :golden-directory goldens
                   :field-golden-directory field-goldens))))
            (should (string-match-p "TEST-FORM" messages))
            (should (string-match-p "golden values" messages))))
      (delete-directory root t))))

(ert-deftest edgar-form-coverage-golden-removal-names-l2-form ()
  "Removing L2 golden values fails with the form name."
  (let* ((root (make-temp-file "edgar-coverage-golden-" t))
         (fixtures (expand-file-name "fixtures" root))
         (expects (expand-file-name "expect" root))
         (goldens (expand-file-name "golden" root))
         (snapshot (expand-file-name "snapshot.txt" root)))
    (unwind-protect
        (progn
          (edgar-form-coverage-test--write snapshot "1 TEST-FORM\n")
          (edgar-form-coverage-test--seed-l2-artifacts root 'html 3)
          (delete-file (expand-file-name "filer-1.eld" goldens))
          (let ((messages
                 (edgar-form-coverage-test--messages
                  (edgar-coverage-problems
                   :registry
                   (edgar-form-coverage-test--registry 'L2)
                   :snapshot-file snapshot
                   :fixture-directory fixtures
                   :expect-directory expects
                   :golden-directory goldens))))
            (should (string-match-p "TEST-FORM" messages))
            (should (string-match-p "golden values" messages))))
      (delete-directory root t))))

(ert-deftest edgar-form-coverage-report-has-form-level-and-volume ()
  "The matrix reports form, level, volume, and share columns."
  (with-temp-buffer
    (let ((standard-output (current-buffer)))
      (edgar-coverage-print-report
       (edgar-form-coverage-test--registry 'L1)))
    (let ((report (buffer-string)))
      (should
       (string-match-p
        "FORM[[:space:]]+LEVEL[[:space:]]+VOLUME" report))
      (should
       (string-match-p "TEST-FORM[[:space:]]+L1[[:space:]]+1" report))
      (should (string-match-p "100\\.00%" report)))))

(ert-deftest edgar-form-coverage-network-index-mutation-names-form ()
  "A form added to a full-index response is reported by name."
  (let*
      ((text
        (concat
         "Form Type        Company Name\n"
         "------------------------------------------------------------\n"
         (format "%-17s%s\n" "4" "Known filer")
         (format "%-17s%s\n" "NETWORK-NEW" "New filer")))
       (forms (edgar-coverage-parse-full-index text))
       (messages
        (edgar-form-coverage-test--messages
         (edgar-coverage--unknown-form-problems
          forms edgar-forms--registry "test index"))))
    (should (string-match-p "NETWORK-NEW" messages))))

(ert-deftest edgar-form-coverage-latest-completed-quarter-rolls-year
    ()
  "The latest completed quarter rolls January into prior-year Q4."
  (should
   (equal
    (edgar-coverage-latest-completed-quarter
     (encode-time 0 0 12 15 1 2026 t))
    '(2025 . 4)))
  (should
   (equal
    (edgar-coverage-latest-completed-quarter
     (encode-time 0 0 12 2 10 2026 t))
    '(2026 . 3))))

(provide 'edgar-form-coverage-test)

;;; form-coverage-test.el ends here
