;;; edgar-forms-filers.el --- EDGAR form registry rows: filers -*- lexical-binding: t; -*-

;;; Commentary:

;; Ownership, notice, 13F, asset-backed and fund periodic forms (G1-G6).
;; Row shape: (FORM FAMILY BACKEND LEVEL SECTIONS-OR-FIELDS VOLUME NOTES).
;; Consumed by `edgar-forms'.

;;; Code:

(defconst edgar-forms-filers-rows
  '(("10-D" "G6 Asset-backed" html L1 nil 2804 nil)
    ("13F-HR" "G4 13F holdings" xml L2 (issuer class cusip value shares put-call discretion voting) 9625 nil)
    ("13F-NT" "G4 13F holdings" xml L2 (report-period manager other-managers signature) 2008 nil)
    ("144" "G2 Notice of sale / Reg D" xml L2 (issuer-name seller-name securities-class-title units-to-be-sold aggregate-market-value approximate-sale-date broker-name) 19526 nil)
    ("3" "G1 Ownership" xml L2 nil 11502 nil)
    ("4" "G1 Ownership" xml L2 nil 104601 nil)
    ("5" "G1 Ownership" xml L2 (issuer reporting-owners holdings footnotes signature) 122 nil)
    ("ABS-15G" "G6 Asset-backed" html L1 nil 529 nil)
    ("ABS-EE" "G6 Asset-backed" xml L2 (asset-class assets asset-number property-name) 2381 nil)
    ("D" "G2 Notice of sale / Reg D" xml L2 (issuer-name federal-exemptions total-offering-amount total-amount-sold total-remaining investor-count non-accredited-investor-count sales-commissions finders-fees) 16851 nil)
    ("N-23C-2" "G5 Fund periodic reports" html L1 nil 31 nil)
    ("N-23C3A" "G5 Fund periodic reports" html L1 nil 168 nil)
    ("N-23C3B" "G5 Fund periodic reports" html L1 nil 1 nil)
    ("N-30B-2" "G5 Fund periodic reports" html L1 nil 27 nil)
    ("N-30D" "G5 Fund periodic reports" html L1 nil 2 nil)
    ("N-54A" "G5 Fund periodic reports" html L1 nil 4 nil)
    ("N-54C" "G5 Fund periodic reports" html L1 nil 3 nil)
    ("N-6F" "G5 Fund periodic reports" html L1 nil 2 nil)
    ("N-8A" "G5 Fund periodic reports" html L1 nil 28 nil)
    ("N-8F" "G5 Fund periodic reports" html L1 nil 20 nil)
    ("N-8F NTC" "G5 Fund periodic reports" pdf L1 nil 18 nil)
    ("N-8F ORDR" "G5 Fund periodic reports" pdf L1 nil 10 nil)
    ("N-CEN" "G5 Fund periodic reports" xml L2 (registrant-name cik report-date) 489 nil)
    ("N-CSR" "G5 Fund periodic reports" html L1 (item-sections) 573 nil)
    ("N-CSRS" "G5 Fund periodic reports" html L1 (item-sections) 831 nil)
    ("N-MFP3" "G5 Fund periodic reports" xml L2 (registrant-name cik report-date holdings) 993 nil)
    ("N-PX" "G5 Fund periodic reports" xml L1 nil 71 nil)
    ("N-VP" "G5 Fund periodic reports" html L1 nil 726 nil)
    ("N-VPFS" "G5 Fund periodic reports" html L1 nil 652 nil)
    ("NPORT-P" "G5 Fund periodic reports" xml L2 (registrant-name cik report-date net-assets holdings) 14407 nil)
    ("NT N-CEN" "G5 Fund periodic reports" xml L1 (registrant-name cik report-date) 12 nil)
    ("NT NPORT-P" "G5 Fund periodic reports" xml L1 (registrant-name cik report-date net-assets holdings) 9 nil)
    ("NT-NCEN" "G5 Fund periodic reports" html L1 nil 7 nil)
    ("NT-NCSR" "G5 Fund periodic reports" html L1 nil 11 nil)
    ("NTFNCSR" "G5 Fund periodic reports" html L1 nil 1 nil)
    ("SC 13D" "G3 Beneficial ownership 13D/13G" html L1 nil 19 nil)
    ("SC 13E3" "G3 Beneficial ownership 13D/13G" html L1 nil 47 nil)
    ("SC 14F1" "G3 Beneficial ownership 13D/13G" html L1 nil 6 nil)
    ("SCHEDULE 13D" "G3 Beneficial ownership 13D/13G" xml L2 (cover-page reporting-persons item-4-purpose) 2688 nil)
    ("SCHEDULE 13G" "G3 Beneficial ownership 13D/13G" xml L2 (cover-page reporting-persons item-4-ownership) 16008 nil))
  "Registry rows for one group of form families.")

(provide 'edgar-forms-filers)

;;; edgar-forms-filers.el ends here
