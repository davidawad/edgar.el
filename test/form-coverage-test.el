;;; form-coverage-test.el --- Tests for the form coverage gate -*- lexical-binding: t; -*-

;;; Commentary:

;; Mutation checks for registry and fixture drift plus network-index parsing.

;;; Code:

(require 'ert)
(require 'cl-lib)

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
          (edgar-form-coverage-test--write
           (expand-file-name "test.eld"
                             fixtures)
           "(:form \"TEST-FORM\")\n")
          (edgar-form-coverage-test--write
           (expand-file-name "test.htm.gz" fixtures) "fixture")
          (edgar-form-coverage-test--write
           (expand-file-name "test.eld" expects) "(:ok t)\n")
          (edgar-form-coverage-test--write
           (expand-file-name "test.eld" goldens) "(:text (\"ok\"))\n")
          (delete-file (expand-file-name "test.eld" goldens))
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
