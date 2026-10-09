;;; edgar-forms-periodic.el --- EDGAR form registry rows: periodic -*- lexical-binding: t; -*-

;;; Commentary:

;; Periodic/event narrative, broker-dealer and tail forms (G9, G12, G13).
;; Row shape: (FORM FAMILY BACKEND LEVEL SECTIONS-OR-FIELDS VOLUME NOTES).
;; Consumed by `edgar-forms'.

;;; Code:

(defconst edgar-forms-periodic-rows
  '(("10-K" "G9 Periodic & event narrative" html L2 (item-sections) 994 nil)
    ("10-KT" "G9 Periodic & event narrative" html L2 (item-sections) 3 nil)
    ("10-Q" "G9 Periodic & event narrative" html L2 (item-sections) 5526 nil)
    ("11-K" "G9 Periodic & event narrative" html L2 (named-signatures) 755 nil)
    ("15-12G" "G9 Periodic & event narrative" html L2 (generic-document-elements) 103 nil)
    ("15-15D" "G9 Periodic & event narrative" html L1 (generic-document-elements) 46 nil)
    ("15F-12B" "G9 Periodic & event narrative" html L1 nil 3 nil)
    ("15F-12G" "G9 Periodic & event narrative" html L1 nil 1 nil)
    ("18-K" "G9 Periodic & event narrative" html L2 (generic-document-elements) 40 nil)
    ("20-F" "G9 Periodic & event narrative" html L2 (item-sections) 584 nil)
    ("25" "G9 Periodic & event narrative" html L2 (generic-document-elements) 33 nil)
    ("25-NSE" "G9 Periodic & event narrative" xml L1 (generic-document-elements) 490 nil)
    ("305B2" "G13 Tail" html L1 nil 42 nil)
    ("40-F" "G9 Periodic & event narrative" html L2 (named-signatures) 23 nil)
    ("6-K" "G9 Periodic & event narrative" html L2 (named-signatures) 7640 nil)
    ("6B NTC" "G9 Periodic & event narrative" pdf L1 nil 2 nil)
    ("6B ORDR" "G9 Periodic & event narrative" pdf L1 nil 1 nil)
    ("8-K" "G9 Periodic & event narrative" html L2 (item-sections) 18664 nil)
    ("8-K12B" "G9 Periodic & event narrative" html L1 nil 4 nil)
    ("ADV-H-T" "G12 Broker-dealer, market structure, staff" text L1 nil 3 "Q2 2026 .paper notice cites DCPN 26007812; original report body is absent.")
    ("ANNLRPT" "G9 Periodic & event narrative" html L1 nil 4 nil)
    ("ATS-N" "G12 Broker-dealer, market structure, staff" xml L1 nil 1 nil)
    ("ATS-N/CA" "G12 Broker-dealer, market structure, staff" xml L1 nil 4 nil)
    ("ATS-N/MA" "G12 Broker-dealer, market structure, staff" xml L1 nil 22 nil)
    ("ATS-N/OFA" "G12 Broker-dealer, market structure, staff" xml L1 nil 1 nil)
    ("ATS-N/UA" "G12 Broker-dealer, market structure, staff" xml L1 nil 33 nil)
    ("CERT" "G9 Periodic & event narrative" pdf L1 (generic-document-elements) 440 nil)
    ("CFPORTAL" "G12 Broker-dealer, market structure, staff" xml L1 nil 9 nil)
    ("CFPORTAL-W" "G12 Broker-dealer, market structure, staff" xml L1 nil 1 nil)
    ("CORRESP" "G12 Broker-dealer, market structure, staff" text L1 nil 687 nil)
    ("DSTRBRPT" "G9 Periodic & event narrative" html L1 (generic-document-elements) 24 nil)
    ("G-FIN" "G12 Broker-dealer, market structure, staff" text L1 nil 8 "Q2 2026 .paper notice cites DCPN 26007830; original report body is absent.")
    ("IRANNOTICE" "G9 Periodic & event narrative" html L1 (generic-document-elements) 42 nil)
    ("MA" "G12 Broker-dealer, market structure, staff" xml L1 nil 55 nil)
    ("MA-A" "G12 Broker-dealer, market structure, staff" xml L1 nil 25 nil)
    ("MA-I" "G12 Broker-dealer, market structure, staff" xml L1 nil 388 nil)
    ("MA-W" "G12 Broker-dealer, market structure, staff" xml L1 nil 2 nil)
    ("NRSRO-CE" "G12 Broker-dealer, market structure, staff" pdf L1 (generic-document-elements) 1 "Q2 2026 PDF is readable through the generic primary-document and text APIs.")
    ("NRSRO-UPD" "G12 Broker-dealer, market structure, staff" pdf L1 (generic-document-elements) 8 "Q2 2026 PDF is readable through the generic primary-document and text APIs.")
    ("NT 10-K" "G9 Periodic & event narrative" html L2 (generic-document-elements) 194 nil)
    ("NT 10-Q" "G9 Periodic & event narrative" html L2 (generic-document-elements) 331 nil)
    ("NT 11-K" "G9 Periodic & event narrative" html L2 (generic-document-elements) 16 nil)
    ("NT 20-F" "G9 Periodic & event narrative" html L2 (generic-document-elements) 104 nil)
    ("POS 8C" "G13 Tail" html L1 nil 4 nil)
    ("QRTLYRPT" "G9 Periodic & event narrative" html L1 nil 5 nil)
    ("REVOKED" "G9 Periodic & event narrative" pdf L1 (generic-document-elements) 26 nil)
    ("SBSE" "G12 Broker-dealer, market structure, staff" xml L1 nil 3 nil)
    ("SBSE-A" "G12 Broker-dealer, market structure, staff" xml L1 nil 33 nil)
    ("SBSE-C" "G12 Broker-dealer, market structure, staff" xml L1 nil 1 nil)
    ("SD" "G9 Periodic & event narrative" html L2 (item-sections) 1005 nil)
    ("SEC STAFF ACTIO" "G12 Broker-dealer, market structure, staff" pdf L1 (generic-document-elements) 59 "Q2 2026 PDF is readable through the generic primary-document and text APIs.")
    ("SEC STAFF LETTE" "G12 Broker-dealer, market structure, staff" pdf L1 (generic-document-elements) 2 "Q2 2026 PDF is readable through the generic primary-document and text APIs.")
    ("SP 15D2" "G9 Periodic & event narrative" html L1 nil 2 nil)
    ("TA-1" "G12 Broker-dealer, market structure, staff" xml L1 nil 44 nil)
    ("TA-2" "G12 Broker-dealer, market structure, staff" xml L1 nil 48 nil)
    ("TA-W" "G12 Broker-dealer, market structure, staff" xml L1 nil 2 nil)
    ("UPLOAD" "G12 Broker-dealer, market structure, staff" text L1 nil 464 nil)
    ("X-17A-5" "G12 Broker-dealer, market structure, staff" xml L1 nil 673 nil))
  "Registry rows for one group of form families.")

(provide 'edgar-forms-periodic)

;;; edgar-forms-periodic.el ends here
