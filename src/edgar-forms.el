;;; edgar-forms.el --- EDGAR form registry -*- lexical-binding: t; -*-

;;; Commentary:

;; Registry of the base forms observed in the 2026 Q2 SEC full index.
;; Every row has family, backend, level, sections-or-fields, volume, notes.

;;; Code:

(defconst edgar-forms--registry
  (let ((table (make-hash-table :test 'equal)))
    (puthash
     "1"
     (list
      :family "G11 Reg CF & Reg A"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 163
      :notes nil)
     table)
    (puthash
     "1-A"
     (list
      :family "G11 Reg CF & Reg A"
      :backend 'xml
      :level 'L1
      :sections-or-fields nil
      :volume 100
      :notes nil)
     table)
    (puthash
     "1-A POS"
     (list
      :family "G11 Reg CF & Reg A"
      :backend 'xml
      :level 'L1
      :sections-or-fields nil
      :volume 38
      :notes nil)
     table)
    (puthash
     "1-A-W"
     (list
      :family "G11 Reg CF & Reg A"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 7
      :notes nil)
     table)
    (puthash
     "1-K"
     (list
      :family "G11 Reg CF & Reg A"
      :backend 'xml
      :level 'L1
      :sections-or-fields nil
      :volume 422
      :notes nil)
     table)
    (puthash
     "1-SA"
     (list
      :family "G11 Reg CF & Reg A"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 18
      :notes nil)
     table)
    (puthash
     "1-U"
     (list
      :family "G11 Reg CF & Reg A"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 676
      :notes nil)
     table)
    (puthash
     "1-Z"
     (list
      :family "G11 Reg CF & Reg A"
      :backend 'xml
      :level 'L1
      :sections-or-fields nil
      :volume 286
      :notes nil)
     table)
    (puthash
     "10-12B"
     (list
      :family "G7 Prospectuses & registration"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 17
      :notes nil)
     table)
    (puthash
     "10-12G"
     (list
      :family "G7 Prospectuses & registration"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 40
      :notes nil)
     table)
    (puthash
     "10-D"
     (list
      :family "G6 Asset-backed"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 2804
      :notes nil)
     table)
    (puthash
     "10-K"
     (list
      :family "G9 Periodic & event narrative"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 994
      :notes nil)
     table)
    (puthash
     "10-KT"
     (list
      :family "G9 Periodic & event narrative"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 3
      :notes nil)
     table)
    (puthash
     "10-Q"
     (list
      :family "G9 Periodic & event narrative"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 5526
      :notes nil)
     table)
    (puthash
     "11-K"
     (list
      :family "G9 Periodic & event narrative"
      :backend 'html
      :level 'L2
      :sections-or-fields '(named-signatures)
      :volume 755
      :notes nil)
     table)
    (puthash
     "13F-HR"
     (list
      :family "G4 13F holdings"
      :backend 'xml
      :level 'L2
      :sections-or-fields
      '(issuer class cusip value shares put-call discretion voting)
      :volume 9625
      :notes nil)
     table)
    (puthash
     "13F-NT"
     (list
      :family "G4 13F holdings"
      :backend 'xml
      :level 'L2
      :sections-or-fields '(report-period manager other-managers signature)
      :volume 2008
      :notes nil)
     table)
    (puthash
     "144"
     (list
      :family "G2 Notice of sale / Reg D"
      :backend 'xml
      :level 'L2
      :sections-or-fields
      '(issuer-name
        seller-name
        securities-class-title
        units-to-be-sold
        aggregate-market-value
        approximate-sale-date
        broker-name)
      :volume 19526
      :notes nil)
     table)
    (puthash
     "15-12G"
     (list
      :family "G9 Periodic & event narrative"
      :backend 'html
      :level 'L1
      :sections-or-fields '(generic-document-elements)
      :volume 103
      :notes nil)
     table)
    (puthash
     "15-15D"
     (list
      :family "G9 Periodic & event narrative"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 46
      :notes nil)
     table)
    (puthash
     "15F-12B"
     (list
      :family "G9 Periodic & event narrative"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 3
      :notes nil)
     table)
    (puthash
     "15F-12G"
     (list
      :family "G9 Periodic & event narrative"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 1
      :notes nil)
     table)
    (puthash
     "18-K"
     (list
      :family "G9 Periodic & event narrative"
      :backend 'html
      :level 'L1
      :sections-or-fields '(generic-document-elements)
      :volume 40
      :notes nil)
     table)
    (puthash
     "20-F"
     (list
      :family "G9 Periodic & event narrative"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 584
      :notes nil)
     table)
    (puthash
     "20FR12B"
     (list
      :family "G7 Prospectuses & registration"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 8
      :notes nil)
     table)
    (puthash
     "20FR12G"
     (list
      :family "G7 Prospectuses & registration"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 2
      :notes nil)
     table)
    (puthash
     "24F-2NT"
     (list
      :family "G10 Investment-company registration"
      :backend 'xml
      :level 'L1
      :sections-or-fields nil
      :volume 839
      :notes nil)
     table)
    (puthash
     "25"
     (list
      :family "G9 Periodic & event narrative"
      :backend 'html
      :level 'L1
      :sections-or-fields '(generic-document-elements)
      :volume 33
      :notes nil)
     table)
    (puthash
     "25-NSE"
     (list
      :family "G9 Periodic & event narrative"
      :backend 'xml
      :level 'L1
      :sections-or-fields '(generic-document-elements)
      :volume 490
      :notes nil)
     table)
    (puthash
     "253G1"
     (list
      :family "G11 Reg CF & Reg A"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 6
      :notes nil)
     table)
    (puthash
     "253G2"
     (list
      :family "G11 Reg CF & Reg A"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 66
      :notes nil)
     table)
    (puthash
     "3"
     (list
      :family "G1 Ownership"
      :backend 'xml
      :level 'L2
      :sections-or-fields nil
      :volume 11502
      :notes nil)
     table)
    (puthash
     "305B2"
     (list
      :family "G13 Tail"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 42
      :notes nil)
     table)
    (puthash
     "4"
     (list
      :family "G1 Ownership"
      :backend 'xml
      :level 'L2
      :sections-or-fields nil
      :volume 104601
      :notes nil)
     table)
    (puthash
     "40-17F1"
     (list
      :family "G10 Investment-company registration"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 30
      :notes nil)
     table)
    (puthash
     "40-17F2"
     (list
      :family "G10 Investment-company registration"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 134
      :notes nil)
     table)
    (puthash
     "40-17G"
     (list
      :family "G10 Investment-company registration"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 434
      :notes nil)
     table)
    (puthash
     "40-24B2"
     (list
      :family "G10 Investment-company registration"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 13
      :notes nil)
     table)
    (puthash
     "40-33"
     (list
      :family "G10 Investment-company registration"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 8
      :notes nil)
     table)
    (puthash
     "40-6B"
     (list
      :family "G10 Investment-company registration"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 17
      :notes nil)
     table)
    (puthash
     "40-8F-2"
     (list
      :family "G10 Investment-company registration"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 2
      :notes nil)
     table)
    (puthash
     "40-APP"
     (list
      :family "G10 Investment-company registration"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 1909
      :notes nil)
     table)
    (puthash
     "40-F"
     (list
      :family "G9 Periodic & event narrative"
      :backend 'html
      :level 'L2
      :sections-or-fields '(named-signatures)
      :volume 23
      :notes nil)
     table)
    (puthash
     "40FR12B"
     (list
      :family "G7 Prospectuses & registration"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 7
      :notes nil)
     table)
    (puthash
     "40FR12G"
     (list
      :family "G7 Prospectuses & registration"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 2
      :notes nil)
     table)
    (puthash
     "424B1"
     (list
      :family "G7 Prospectuses & registration"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 4
      :notes nil)
     table)
    (puthash
     "424B2"
     (list
      :family "G7 Prospectuses & registration"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 49609
      :notes nil)
     table)
    (puthash
     "424B3"
     (list
      :family "G7 Prospectuses & registration"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 2607
      :notes nil)
     table)
    (puthash
     "424B4"
     (list
      :family "G7 Prospectuses & registration"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 170
      :notes nil)
     table)
    (puthash
     "424B5"
     (list
      :family "G7 Prospectuses & registration"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 968
      :notes nil)
     table)
    (puthash
     "424B7"
     (list
      :family "G7 Prospectuses & registration"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 69
      :notes nil)
     table)
    (puthash
     "424B8"
     (list
      :family "G7 Prospectuses & registration"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 52
      :notes nil)
     table)
    (puthash
     "424H"
     (list
      :family "G7 Prospectuses & registration"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 81
      :notes nil)
     table)
    (puthash
     "424I"
     (list
      :family "G7 Prospectuses & registration"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 10
      :notes nil)
     table)
    (puthash
     "425"
     (list
      :family "G8 Proxy & M&A"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 1546
      :notes nil)
     table)
    (puthash
     "485APOS"
     (list
      :family "G10 Investment-company registration"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 511
      :notes nil)
     table)
    (puthash
     "485BPOS"
     (list
      :family "G10 Investment-company registration"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 2352
      :notes nil)
     table)
    (puthash
     "485BXT"
     (list
      :family "G10 Investment-company registration"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 1286
      :notes nil)
     table)
    (puthash
     "486APOS"
     (list
      :family "G10 Investment-company registration"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 18
      :notes nil)
     table)
    (puthash
     "486BPOS"
     (list
      :family "G10 Investment-company registration"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 83
      :notes nil)
     table)
    (puthash
     "486BXT"
     (list
      :family "G10 Investment-company registration"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 8
      :notes nil)
     table)
    (puthash
     "487"
     (list
      :family "G10 Investment-company registration"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 229
      :notes nil)
     table)
    (puthash
     "497"
     (list
      :family "G10 Investment-company registration"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 4175
      :notes nil)
     table)
    (puthash
     "497AD"
     (list
      :family "G10 Investment-company registration"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 95
      :notes nil)
     table)
    (puthash
     "497J"
     (list
      :family "G10 Investment-company registration"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 2190
      :notes nil)
     table)
    (puthash
     "497K"
     (list
      :family "G10 Investment-company registration"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 6592
      :notes nil)
     table)
    (puthash
     "497VPI"
     (list
      :family "G10 Investment-company registration"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 912
      :notes nil)
     table)
    (puthash
     "497VPSUB"
     (list
      :family "G10 Investment-company registration"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 2
      :notes nil)
     table)
    (puthash
     "497VPU"
     (list
      :family "G10 Investment-company registration"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 1800
      :notes nil)
     table)
    (puthash
     "5"
     (list
      :family "G1 Ownership"
      :backend 'xml
      :level 'L2
      :sections-or-fields
      '(issuer reporting-owners holdings footnotes signature)
      :volume 122
      :notes nil)
     table)
    (puthash
     "6-K"
     (list
      :family "G9 Periodic & event narrative"
      :backend 'html
      :level 'L2
      :sections-or-fields '(named-signatures)
      :volume 7640
      :notes nil)
     table)
    (puthash
     "6B NTC"
     (list
      :family "G9 Periodic & event narrative"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 2
      :notes nil)
     table)
    (puthash
     "6B ORDR"
     (list
      :family "G9 Periodic & event narrative"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 1
      :notes nil)
     table)
    (puthash
     "8-A12B"
     (list
      :family "G7 Prospectuses & registration"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 494
      :notes nil)
     table)
    (puthash
     "8-A12G"
     (list
      :family "G7 Prospectuses & registration"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 15
      :notes nil)
     table)
    (puthash
     "8-K"
     (list
      :family "G9 Periodic & event narrative"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 18664
      :notes nil)
     table)
    (puthash
     "8-K12B"
     (list
      :family "G9 Periodic & event narrative"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 4
      :notes nil)
     table)
    (puthash
     "ABS-15G"
     (list
      :family "G6 Asset-backed"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 529
      :notes nil)
     table)
    (puthash
     "ABS-EE"
     (list
      :family "G6 Asset-backed"
      :backend 'xml
      :level 'L2
      :sections-or-fields '(asset-class assets asset-number property-name)
      :volume 2381
      :notes nil)
     table)
    (puthash
     "ADV-H-T"
     (list
      :family "G12 Broker-dealer, market structure, staff"
      :backend 'xml
      :level 'L0
      :sections-or-fields nil
      :volume 3
      :notes nil)
     table)
    (puthash
     "ANNLRPT"
     (list
      :family "G9 Periodic & event narrative"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 4
      :notes nil)
     table)
    (puthash
     "APP NTC"
     (list
      :family "G10 Investment-company registration"
      :backend 'pdf
      :level 'L1
      :sections-or-fields nil
      :volume 65
      :notes nil)
     table)
    (puthash
     "APP ORDR"
     (list
      :family "G10 Investment-company registration"
      :backend 'pdf
      :level 'L1
      :sections-or-fields nil
      :volume 63
      :notes nil)
     table)
    (puthash
     "APP WD"
     (list
      :family "G10 Investment-company registration"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 47
      :notes nil)
     table)
    (puthash
     "APP WDG"
     (list
      :family "G10 Investment-company registration"
      :backend 'pdf
      :level 'L1
      :sections-or-fields nil
      :volume 13
      :notes nil)
     table)
    (puthash
     "ARS"
     (list
      :family "G8 Proxy & M&A"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 1883
      :notes nil)
     table)
    (puthash
     "ATS-N"
     (list
      :family "G12 Broker-dealer, market structure, staff"
      :backend 'xml
      :level 'L0
      :sections-or-fields nil
      :volume 1
      :notes nil)
     table)
    (puthash
     "ATS-N/CA"
     (list
      :family "G12 Broker-dealer, market structure, staff"
      :backend 'xml
      :level 'L0
      :sections-or-fields nil
      :volume 4
      :notes nil)
     table)
    (puthash
     "ATS-N/MA"
     (list
      :family "G12 Broker-dealer, market structure, staff"
      :backend 'xml
      :level 'L0
      :sections-or-fields nil
      :volume 22
      :notes nil)
     table)
    (puthash
     "ATS-N/OFA"
     (list
      :family "G12 Broker-dealer, market structure, staff"
      :backend 'xml
      :level 'L0
      :sections-or-fields nil
      :volume 1
      :notes nil)
     table)
    (puthash
     "ATS-N/UA"
     (list
      :family "G12 Broker-dealer, market structure, staff"
      :backend 'xml
      :level 'L0
      :sections-or-fields nil
      :volume 33
      :notes nil)
     table)
    (puthash
     "AW"
     (list
      :family "G7 Prospectuses & registration"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 48
      :notes nil)
     table)
    (puthash
     "C"
     (list
      :family "G11 Reg CF & Reg A"
      :backend 'xml
      :level 'L2
      :sections-or-fields '(issuer offering financials signature)
      :volume 500
      :notes nil)
     table)
    (puthash
     "C-AR"
     (list
      :family "G11 Reg CF & Reg A"
      :backend 'xml
      :level 'L2
      :sections-or-fields '(issuer period annual-report signature)
      :volume 549
      :notes nil)
     table)
    (puthash
     "C-AR-W"
     (list
      :family "G11 Reg CF & Reg A"
      :backend 'xml
      :level 'L1
      :sections-or-fields nil
      :volume 2
      :notes nil)
     table)
    (puthash
     "C-TR"
     (list
      :family "G11 Reg CF & Reg A"
      :backend 'xml
      :level 'L1
      :sections-or-fields nil
      :volume 89
      :notes nil)
     table)
    (puthash
     "C-TR-W"
     (list
      :family "G11 Reg CF & Reg A"
      :backend 'xml
      :level 'L1
      :sections-or-fields nil
      :volume 4
      :notes nil)
     table)
    (puthash
     "C-U"
     (list
      :family "G11 Reg CF & Reg A"
      :backend 'xml
      :level 'L1
      :sections-or-fields nil
      :volume 163
      :notes nil)
     table)
    (puthash
     "C-W"
     (list
      :family "G11 Reg CF & Reg A"
      :backend 'xml
      :level 'L1
      :sections-or-fields nil
      :volume 17
      :notes nil)
     table)
    (puthash
     "CB"
     (list
      :family "G8 Proxy & M&A"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 46
      :notes nil)
     table)
    (puthash
     "CERT"
     (list
      :family "G9 Periodic & event narrative"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 440
      :notes nil)
     table)
    (puthash
     "CFPORTAL"
     (list
      :family "G12 Broker-dealer, market structure, staff"
      :backend 'xml
      :level 'L0
      :sections-or-fields nil
      :volume 9
      :notes nil)
     table)
    (puthash
     "CFPORTAL-W"
     (list
      :family "G12 Broker-dealer, market structure, staff"
      :backend 'xml
      :level 'L0
      :sections-or-fields nil
      :volume 1
      :notes nil)
     table)
    (puthash
     "CORRESP"
     (list
      :family "G12 Broker-dealer, market structure, staff"
      :backend 'text
      :level 'L1
      :sections-or-fields nil
      :volume 687
      :notes nil)
     table)
    (puthash
     "CT ORDER"
     (list
      :family "G10 Investment-company registration"
      :backend 'pdf
      :level 'L1
      :sections-or-fields nil
      :volume 11
      :notes nil)
     table)
    (puthash
     "D"
     (list
      :family "G2 Notice of sale / Reg D"
      :backend 'xml
      :level 'L0
      :sections-or-fields nil
      :volume 16851
      :notes nil)
     table)
    (puthash
     "DEF 14A"
     (list
      :family "G8 Proxy & M&A"
      :backend 'html
      :level 'L2
      :sections-or-fields nil
      :volume 2694
      :notes nil)
     table)
    (puthash
     "DEF 14C"
     (list
      :family "G8 Proxy & M&A"
      :backend 'html
      :level 'L2
      :sections-or-fields nil
      :volume 89
      :notes nil)
     table)
    (puthash
     "DEFA14A"
     (list
      :family "G8 Proxy & M&A"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 3042
      :notes nil)
     table)
    (puthash
     "DEFA14C"
     (list
      :family "G8 Proxy & M&A"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 1
      :notes nil)
     table)
    (puthash
     "DEFC14A"
     (list
      :family "G8 Proxy & M&A"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 52
      :notes nil)
     table)
    (puthash
     "DEFM14A"
     (list
      :family "G8 Proxy & M&A"
      :backend 'html
      :level 'L2
      :sections-or-fields nil
      :volume 67
      :notes nil)
     table)
    (puthash
     "DEFM14C"
     (list
      :family "G8 Proxy & M&A"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 4
      :notes nil)
     table)
    (puthash
     "DEFR14A"
     (list
      :family "G8 Proxy & M&A"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 47
      :notes nil)
     table)
    (puthash
     "DEFR14C"
     (list
      :family "G8 Proxy & M&A"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 2
      :notes nil)
     table)
    (puthash
     "DEL AM"
     (list
      :family "G10 Investment-company registration"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 16
      :notes nil)
     table)
    (puthash
     "DFAN14A"
     (list
      :family "G8 Proxy & M&A"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 338
      :notes nil)
     table)
    (puthash
     "DFRN14A"
     (list
      :family "G8 Proxy & M&A"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 10
      :notes nil)
     table)
    (puthash
     "DOS"
     (list
      :family "G7 Prospectuses & registration"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 7
      :notes nil)
     table)
    (puthash
     "DOSLTR"
     (list
      :family "G7 Prospectuses & registration"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 1
      :notes nil)
     table)
    (puthash
     "DRS"
     (list
      :family "G7 Prospectuses & registration"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 343
      :notes nil)
     table)
    (puthash
     "DRSLTR"
     (list
      :family "G7 Prospectuses & registration"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 4
      :notes nil)
     table)
    (puthash
     "DSTRBRPT"
     (list
      :family "G9 Periodic & event narrative"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 24
      :notes nil)
     table)
    (puthash
     "EFFECT"
     (list
      :family "G7 Prospectuses & registration"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 1165
      :notes nil)
     table)
    (puthash
     "F-1"
     (list
      :family "G7 Prospectuses & registration"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 215
      :notes nil)
     table)
    (puthash
     "F-10"
     (list
      :family "G7 Prospectuses & registration"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 14
      :notes nil)
     table)
    (puthash
     "F-10EF"
     (list
      :family "G7 Prospectuses & registration"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 1
      :notes nil)
     table)
    (puthash
     "F-10POS"
     (list
      :family "G7 Prospectuses & registration"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 30
      :notes nil)
     table)
    (puthash
     "F-1MEF"
     (list
      :family "G7 Prospectuses & registration"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 3
      :notes nil)
     table)
    (puthash
     "F-3"
     (list
      :family "G7 Prospectuses & registration"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 109
      :notes nil)
     table)
    (puthash
     "F-3ASR"
     (list
      :family "G7 Prospectuses & registration"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 25
      :notes nil)
     table)
    (puthash
     "F-3MEF"
     (list
      :family "G7 Prospectuses & registration"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 1
      :notes nil)
     table)
    (puthash
     "F-4"
     (list
      :family "G7 Prospectuses & registration"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 61
      :notes nil)
     table)
    (puthash
     "F-6"
     (list
      :family "G7 Prospectuses & registration"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 44
      :notes nil)
     table)
    (puthash
     "F-6 POS"
     (list
      :family "G7 Prospectuses & registration"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 100
      :notes nil)
     table)
    (puthash
     "F-6EF"
     (list
      :family "G7 Prospectuses & registration"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 246
      :notes nil)
     table)
    (puthash
     "F-N"
     (list
      :family "G7 Prospectuses & registration"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 1
      :notes nil)
     table)
    (puthash
     "F-X"
     (list
      :family "G7 Prospectuses & registration"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 54
      :notes nil)
     table)
    (puthash
     "FWP"
     (list
      :family "G7 Prospectuses & registration"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 6481
      :notes nil)
     table)
    (puthash
     "G-FIN"
     (list
      :family "G12 Broker-dealer, market structure, staff"
      :backend 'xml
      :level 'L0
      :sections-or-fields nil
      :volume 8
      :notes nil)
     table)
    (puthash
     "IRANNOTICE"
     (list
      :family "G9 Periodic & event narrative"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 42
      :notes nil)
     table)
    (puthash
     "MA"
     (list
      :family "G12 Broker-dealer, market structure, staff"
      :backend 'xml
      :level 'L0
      :sections-or-fields nil
      :volume 55
      :notes nil)
     table)
    (puthash
     "MA-A"
     (list
      :family "G12 Broker-dealer, market structure, staff"
      :backend 'xml
      :level 'L0
      :sections-or-fields nil
      :volume 25
      :notes nil)
     table)
    (puthash
     "MA-I"
     (list
      :family "G12 Broker-dealer, market structure, staff"
      :backend 'xml
      :level 'L1
      :sections-or-fields nil
      :volume 388
      :notes nil)
     table)
    (puthash
     "MA-W"
     (list
      :family "G12 Broker-dealer, market structure, staff"
      :backend 'xml
      :level 'L0
      :sections-or-fields nil
      :volume 2
      :notes nil)
     table)
    (puthash
     "MSD"
     (list
      :family "G10 Investment-company registration"
      :backend 'text
      :level 'L1
      :sections-or-fields nil
      :volume 2
      :notes nil)
     table)
    (puthash
     "N-14"
     (list
      :family "G10 Investment-company registration"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 30
      :notes nil)
     table)
    (puthash
     "N-14 8C"
     (list
      :family "G10 Investment-company registration"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 15
      :notes nil)
     table)
    (puthash
     "N-1A"
     (list
      :family "G10 Investment-company registration"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 13
      :notes nil)
     table)
    (puthash
     "N-2"
     (list
      :family "G10 Investment-company registration"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 149
      :notes nil)
     table)
    (puthash
     "N-2 POSASR"
     (list
      :family "G10 Investment-company registration"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 1
      :notes nil)
     table)
    (puthash
     "N-23C-2"
     (list
      :family "G5 Fund periodic reports"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 31
      :notes nil)
     table)
    (puthash
     "N-23C3A"
     (list
      :family "G5 Fund periodic reports"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 168
      :notes nil)
     table)
    (puthash
     "N-23C3B"
     (list
      :family "G5 Fund periodic reports"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 1
      :notes nil)
     table)
    (puthash
     "N-2ASR"
     (list
      :family "G10 Investment-company registration"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 9
      :notes nil)
     table)
    (puthash
     "N-2MEF"
     (list
      :family "G10 Investment-company registration"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 1
      :notes nil)
     table)
    (puthash
     "N-30B-2"
     (list
      :family "G5 Fund periodic reports"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 27
      :notes nil)
     table)
    (puthash
     "N-30D"
     (list
      :family "G5 Fund periodic reports"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 2
      :notes nil)
     table)
    (puthash
     "N-4"
     (list
      :family "G10 Investment-company registration"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 15
      :notes nil)
     table)
    (puthash
     "N-54A"
     (list
      :family "G5 Fund periodic reports"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 4
      :notes nil)
     table)
    (puthash
     "N-54C"
     (list
      :family "G5 Fund periodic reports"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 3
      :notes nil)
     table)
    (puthash
     "N-6"
     (list
      :family "G10 Investment-company registration"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 5
      :notes nil)
     table)
    (puthash
     "N-6F"
     (list
      :family "G5 Fund periodic reports"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 2
      :notes nil)
     table)
    (puthash
     "N-8A"
     (list
      :family "G5 Fund periodic reports"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 28
      :notes nil)
     table)
    (puthash
     "N-8F"
     (list
      :family "G5 Fund periodic reports"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 20
      :notes nil)
     table)
    (puthash
     "N-8F NTC"
     (list
      :family "G5 Fund periodic reports"
      :backend 'pdf
      :level 'L1
      :sections-or-fields nil
      :volume 18
      :notes nil)
     table)
    (puthash
     "N-8F ORDR"
     (list
      :family "G5 Fund periodic reports"
      :backend 'pdf
      :level 'L1
      :sections-or-fields nil
      :volume 10
      :notes nil)
     table)
    (puthash
     "N-CEN"
     (list
      :family "G5 Fund periodic reports"
      :backend 'xml
      :level 'L2
      :sections-or-fields '(registrant-name cik report-date)
      :volume 489
      :notes nil)
     table)
    (puthash
     "N-CSR"
     (list
      :family "G5 Fund periodic reports"
      :backend 'html
      :level 'L1
      :sections-or-fields '(item-sections)
      :volume 573
      :notes nil)
     table)
    (puthash
     "N-CSRS"
     (list
      :family "G5 Fund periodic reports"
      :backend 'html
      :level 'L1
      :sections-or-fields '(item-sections)
      :volume 831
      :notes nil)
     table)
    (puthash
     "N-MFP3"
     (list
      :family "G5 Fund periodic reports"
      :backend 'xml
      :level 'L2
      :sections-or-fields '(registrant-name cik report-date holdings)
      :volume 993
      :notes nil)
     table)
    (puthash
     "N-PX"
     (list
      :family "G5 Fund periodic reports"
      :backend 'xml
      :level 'L1
      :sections-or-fields nil
      :volume 71
      :notes nil)
     table)
    (puthash
     "N-VP"
     (list
      :family "G5 Fund periodic reports"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 726
      :notes nil)
     table)
    (puthash
     "N-VPFS"
     (list
      :family "G5 Fund periodic reports"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 652
      :notes nil)
     table)
    (puthash
     "NPORT-P"
     (list
      :family "G5 Fund periodic reports"
      :backend 'xml
      :level 'L2
      :sections-or-fields
      '(registrant-name cik report-date net-assets holdings)
      :volume 14407
      :notes nil)
     table)
    (puthash
     "NRSRO-CE"
     (list
      :family "G12 Broker-dealer, market structure, staff"
      :backend 'xml
      :level 'L0
      :sections-or-fields nil
      :volume 1
      :notes nil)
     table)
    (puthash
     "NRSRO-UPD"
     (list
      :family "G12 Broker-dealer, market structure, staff"
      :backend 'xml
      :level 'L0
      :sections-or-fields nil
      :volume 8
      :notes nil)
     table)
    (puthash
     "NT 10-K"
     (list
      :family "G9 Periodic & event narrative"
      :backend 'html
      :level 'L1
      :sections-or-fields '(generic-document-elements)
      :volume 194
      :notes nil)
     table)
    (puthash
     "NT 10-Q"
     (list
      :family "G9 Periodic & event narrative"
      :backend 'html
      :level 'L1
      :sections-or-fields '(generic-document-elements)
      :volume 331
      :notes nil)
     table)
    (puthash
     "NT 11-K"
     (list
      :family "G9 Periodic & event narrative"
      :backend 'html
      :level 'L1
      :sections-or-fields '(generic-document-elements)
      :volume 16
      :notes nil)
     table)
    (puthash
     "NT 20-F"
     (list
      :family "G9 Periodic & event narrative"
      :backend 'html
      :level 'L1
      :sections-or-fields '(generic-document-elements)
      :volume 104
      :notes nil)
     table)
    (puthash
     "NT N-CEN"
     (list
      :family "G5 Fund periodic reports"
      :backend 'xml
      :level 'L1
      :sections-or-fields '(registrant-name cik report-date)
      :volume 12
      :notes nil)
     table)
    (puthash
     "NT NPORT-P"
     (list
      :family "G5 Fund periodic reports"
      :backend 'xml
      :level 'L1
      :sections-or-fields
      '(registrant-name cik report-date net-assets holdings)
      :volume 9
      :notes nil)
     table)
    (puthash
     "NT-NCEN"
     (list
      :family "G5 Fund periodic reports"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 7
      :notes nil)
     table)
    (puthash
     "NT-NCSR"
     (list
      :family "G5 Fund periodic reports"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 11
      :notes nil)
     table)
    (puthash
     "NTFNCSR"
     (list
      :family "G5 Fund periodic reports"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 1
      :notes nil)
     table)
    (puthash
     "POS 8C"
     (list
      :family "G13 Tail"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 4
      :notes nil)
     table)
    (puthash
     "POS AM"
     (list
      :family "G7 Prospectuses & registration"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 308
      :notes nil)
     table)
    (puthash
     "POS AMI"
     (list
      :family "G7 Prospectuses & registration"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 50
      :notes nil)
     table)
    (puthash
     "POS EX"
     (list
      :family "G7 Prospectuses & registration"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 135
      :notes nil)
     table)
    (puthash
     "POSASR"
     (list
      :family "G7 Prospectuses & registration"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 47
      :notes nil)
     table)
    (puthash
     "PRE 14A"
     (list
      :family "G8 Proxy & M&A"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 480
      :notes nil)
     table)
    (puthash
     "PRE 14C"
     (list
      :family "G8 Proxy & M&A"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 63
      :notes nil)
     table)
    (puthash
     "PREC14A"
     (list
      :family "G8 Proxy & M&A"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 43
      :notes nil)
     table)
    (puthash
     "PREM14A"
     (list
      :family "G8 Proxy & M&A"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 39
      :notes nil)
     table)
    (puthash
     "PREM14C"
     (list
      :family "G8 Proxy & M&A"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 3
      :notes nil)
     table)
    (puthash
     "PREN14A"
     (list
      :family "G8 Proxy & M&A"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 2
      :notes nil)
     table)
    (puthash
     "PRER14A"
     (list
      :family "G8 Proxy & M&A"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 44
      :notes nil)
     table)
    (puthash
     "PRER14C"
     (list
      :family "G8 Proxy & M&A"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 3
      :notes nil)
     table)
    (puthash
     "PRRN14A"
     (list
      :family "G8 Proxy & M&A"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 26
      :notes nil)
     table)
    (puthash
     "PX14A6G"
     (list
      :family "G8 Proxy & M&A"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 92
      :notes nil)
     table)
    (puthash
     "QRTLYRPT"
     (list
      :family "G9 Periodic & event narrative"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 5
      :notes nil)
     table)
    (puthash
     "QUALIF"
     (list
      :family "G11 Reg CF & Reg A"
      :backend 'xml
      :level 'L1
      :sections-or-fields nil
      :volume 53
      :notes nil)
     table)
    (puthash
     "REVOKED"
     (list
      :family "G9 Periodic & event narrative"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 26
      :notes nil)
     table)
    (puthash
     "RW"
     (list
      :family "G7 Prospectuses & registration"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 95
      :notes nil)
     table)
    (puthash
     "S-1"
     (list
      :family "G7 Prospectuses & registration"
      :backend 'html
      :level 'L2
      :sections-or-fields '(prospectus-summary part-ii-items)
      :volume 718
      :notes nil)
     table)
    (puthash
     "S-11"
     (list
      :family "G7 Prospectuses & registration"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 14
      :notes nil)
     table)
    (puthash
     "S-1MEF"
     (list
      :family "G7 Prospectuses & registration"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 36
      :notes nil)
     table)
    (puthash
     "S-3"
     (list
      :family "G7 Prospectuses & registration"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 308
      :notes nil)
     table)
    (puthash
     "S-3ASR"
     (list
      :family "G7 Prospectuses & registration"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 357
      :notes nil)
     table)
    (puthash
     "S-3D"
     (list
      :family "G7 Prospectuses & registration"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 1
      :notes nil)
     table)
    (puthash
     "S-3DPOS"
     (list
      :family "G7 Prospectuses & registration"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 5
      :notes nil)
     table)
    (puthash
     "S-3MEF"
     (list
      :family "G7 Prospectuses & registration"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 4
      :notes nil)
     table)
    (puthash
     "S-4"
     (list
      :family "G7 Prospectuses & registration"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 227
      :notes nil)
     table)
    (puthash
     "S-6"
     (list
      :family "G10 Investment-company registration"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 333
      :notes nil)
     table)
    (puthash
     "S-8"
     (list
      :family "G7 Prospectuses & registration"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 850
      :notes nil)
     table)
    (puthash
     "S-8 POS"
     (list
      :family "G7 Prospectuses & registration"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 607
      :notes nil)
     table)
    (puthash
     "S-B"
     (list
      :family "G7 Prospectuses & registration"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 10
      :notes nil)
     table)
    (puthash
     "SBSE"
     (list
      :family "G12 Broker-dealer, market structure, staff"
      :backend 'xml
      :level 'L0
      :sections-or-fields nil
      :volume 3
      :notes nil)
     table)
    (puthash
     "SBSE-A"
     (list
      :family "G12 Broker-dealer, market structure, staff"
      :backend 'xml
      :level 'L0
      :sections-or-fields nil
      :volume 33
      :notes nil)
     table)
    (puthash
     "SBSE-C"
     (list
      :family "G12 Broker-dealer, market structure, staff"
      :backend 'xml
      :level 'L0
      :sections-or-fields nil
      :volume 1
      :notes nil)
     table)
    (puthash
     "SC 13D"
     (list
      :family "G3 Beneficial ownership 13D/13G"
      :backend 'xml
      :level 'L0
      :sections-or-fields nil
      :volume 19
      :notes nil)
     table)
    (puthash
     "SC 13E3"
     (list
      :family "G3 Beneficial ownership 13D/13G"
      :backend 'xml
      :level 'L0
      :sections-or-fields nil
      :volume 47
      :notes nil)
     table)
    (puthash
     "SC 14D9"
     (list
      :family "G8 Proxy & M&A"
      :backend 'html
      :level 'L2
      :sections-or-fields nil
      :volume 64
      :notes nil)
     table)
    (puthash
     "SC 14F1"
     (list
      :family "G3 Beneficial ownership 13D/13G"
      :backend 'xml
      :level 'L0
      :sections-or-fields nil
      :volume 6
      :notes nil)
     table)
    (puthash
     "SC 14N"
     (list
      :family "G8 Proxy & M&A"
      :backend 'html
      :level 'L1
      :sections-or-fields nil
      :volume 2
      :notes nil)
     table)
    (puthash
     "SC TO-C"
     (list
      :family "G8 Proxy & M&A"
      :backend 'html
      :level 'L2
      :sections-or-fields nil
      :volume 50
      :notes nil)
     table)
    (puthash
     "SC TO-I"
     (list
      :family "G8 Proxy & M&A"
      :backend 'html
      :level 'L2
      :sections-or-fields nil
      :volume 336
      :notes nil)
     table)
    (puthash
     "SC TO-T"
     (list
      :family "G8 Proxy & M&A"
      :backend 'html
      :level 'L2
      :sections-or-fields nil
      :volume 140
      :notes nil)
     table)
    (puthash
     "SC14D1F"
     (list
      :family "G8 Proxy & M&A"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 8
      :notes nil)
     table)
    (puthash
     "SC14D9C"
     (list
      :family "G8 Proxy & M&A"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 28
      :notes nil)
     table)
    (puthash
     "SCHEDULE 13D"
     (list
      :family "G3 Beneficial ownership 13D/13G"
      :backend 'xml
      :level 'L2
      :sections-or-fields '(cover-page reporting-persons item-4-purpose)
      :volume 2688
      :notes nil)
     table)
    (puthash
     "SCHEDULE 13G"
     (list
      :family "G3 Beneficial ownership 13D/13G"
      :backend 'xml
      :level 'L2
      :sections-or-fields '(cover-page reporting-persons item-4-ownership)
      :volume 16008
      :notes nil)
     table)
    (puthash
     "SD"
     (list
      :family "G9 Periodic & event narrative"
      :backend 'html
      :level 'L2
      :sections-or-fields '(item-sections)
      :volume 1005
      :notes nil)
     table)
    (puthash
     "SEC STAFF ACTIO"
     (list
      :family "G12 Broker-dealer, market structure, staff"
      :backend 'text
      :level 'L0
      :sections-or-fields nil
      :volume 59
      :notes nil)
     table)
    (puthash
     "SEC STAFF LETTE"
     (list
      :family "G12 Broker-dealer, market structure, staff"
      :backend 'text
      :level 'L0
      :sections-or-fields nil
      :volume 2
      :notes nil)
     table)
    (puthash
     "SF-1"
     (list
      :family "G7 Prospectuses & registration"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 4
      :notes nil)
     table)
    (puthash
     "SF-3"
     (list
      :family "G7 Prospectuses & registration"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 5
      :notes nil)
     table)
    (puthash
     "SP 15D2"
     (list
      :family "G9 Periodic & event narrative"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 2
      :notes nil)
     table)
    (puthash
     "SUPPL"
     (list
      :family "G7 Prospectuses & registration"
      :backend 'html
      :level 'L0
      :sections-or-fields nil
      :volume 33
      :notes nil)
     table)
    (puthash
     "TA-1"
     (list
      :family "G12 Broker-dealer, market structure, staff"
      :backend 'xml
      :level 'L0
      :sections-or-fields nil
      :volume 44
      :notes nil)
     table)
    (puthash
     "TA-2"
     (list
      :family "G12 Broker-dealer, market structure, staff"
      :backend 'xml
      :level 'L1
      :sections-or-fields nil
      :volume 48
      :notes nil)
     table)
    (puthash
     "TA-W"
     (list
      :family "G12 Broker-dealer, market structure, staff"
      :backend 'xml
      :level 'L0
      :sections-or-fields nil
      :volume 2
      :notes nil)
     table)
    (puthash
     "UPLOAD"
     (list
      :family "G12 Broker-dealer, market structure, staff"
      :backend 'text
      :level 'L1
      :sections-or-fields nil
      :volume 464
      :notes nil)
     table)
    (puthash
     "X-17A-5"
     (list
      :family "G12 Broker-dealer, market structure, staff"
      :backend 'xml
      :level 'L1
      :sections-or-fields nil
      :volume 673
      :notes nil)
     table)
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
