# Form coverage survey

Goal: `edgar.el` reads every base EDGAR form type. This is the measured size of
that goal. Data: SEC full-index `form.idx`, 2026 Q2 (`tools/form-survey.sh`),
353,293 filings.

The machine-readable source of truth is `src/edgar-forms.el`. Its 245 base
form rows were seeded from the index snapshot in `test/form-survey-2026-q2.txt`;
`eask run script coverage` checks every snapshot form and volume against the
registry, validates the artifacts required by each L1/L2 row, and prints the
form-by-level-and-volume matrix. It runs offline inside `eask run script check`.
Primary artifacts follow the registered backend: HTML uses `.htm.gz` or `.htm`,
XML uses `.xml` or `.xml.gz`, text uses `.txt` or `.txt.gz`, and PDF uses
`.pdf` with Poppler's `pdftotext` executable.
Run `EDGAR_UA="Name email" tools/form-survey.sh` to refresh the snapshot and
registry when updating the measured quarter.

The opt-in `EDGAR_UA="Name email" eask run script coverage-network` fetches
the latest completed quarter's SEC `form.idx`, rejects unregistered forms by
name, and reports registered forms that are new relative to the committed Q2
snapshot. Override its target with `EDGAR_COVERAGE_YEAR` and
`EDGAR_COVERAGE_QUARTER` (for example, `2026` and `3`). Network access is never
part of the normal check.

- 342 distinct form types, 245 once amendments (`/A`) are folded into their base form.
- Volume is extremely concentrated: top 10 base forms = 76% of filings, top 30 = 92%,
  top 75 = 98.5%. 56 base forms had 5 or fewer filings that quarter; 17 had one.
- Many high-volume forms are XML underneath, not narrative. The SEC's HTML view of a
  Form 4 / 144 / 13F / 13G is an XSL rendering; dropping the `xsl.../` path segment of
  the primary-document URL yields the raw XML (verified for Form 4 and 144).

## Coverage levels

| Level | Meaning | Required of |
|---|---|---|
| L0 | Form is in the registry (name, family, backend, volume) | every base form |
| L1 | `edgar-text` reads it, one recorded fixture and expect snapshot | every base form |
| L2 | L1 plus golden strings for narrative forms or typed accessors + golden values for XML forms | families below, by volume |

## Per-form registry

This table is generated from `src/edgar-forms.el`. Regenerate with
`eask run script docs`; the offline coverage check fails if it becomes stale.

<!-- BEGIN GENERATED FORM COVERAGE -->
| Form | Family | Backend | Level | Example call |
|---|---|---|---|---|
| `1` | G11 Reg CF & Reg A | html | L0 | `(edgar-form-info "1")` |
| `1-A` | G11 Reg CF & Reg A | xml | L1 | `(edgar-text filing)` |
| `1-A POS` | G11 Reg CF & Reg A | xml | L1 | `(edgar-text filing)` |
| `1-A-W` | G11 Reg CF & Reg A | html | L1 | `(edgar-text filing)` |
| `1-K` | G11 Reg CF & Reg A | xml | L1 | `(edgar-text filing)` |
| `1-SA` | G11 Reg CF & Reg A | html | L1 | `(edgar-text filing)` |
| `1-U` | G11 Reg CF & Reg A | html | L1 | `(edgar-text filing)` |
| `1-Z` | G11 Reg CF & Reg A | xml | L1 | `(edgar-text filing)` |
| `10-12B` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "10-12B")` |
| `10-12G` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "10-12G")` |
| `10-D` | G6 Asset-backed | html | L1 | `(edgar-text filing)` |
| `10-K` | G9 Periodic & event narrative | html | L2 | `(edgar-structure-headings (edgar-document-structure filing))` |
| `10-KT` | G9 Periodic & event narrative | html | L2 | `(edgar-structure-headings (edgar-document-structure filing))` |
| `10-Q` | G9 Periodic & event narrative | html | L2 | `(edgar-structure-headings (edgar-document-structure filing))` |
| `11-K` | G9 Periodic & event narrative | html | L2 | `(edgar-structure-headings (edgar-document-structure filing))` |
| `13F-HR` | G4 13F holdings | xml | L2 | `(edgar-13f-holdings filing)` |
| `13F-NT` | G4 13F holdings | xml | L2 | `(edgar-13f-notice filing)` |
| `144` | G2 Notice of sale / Reg D | xml | L2 | `(edgar-form-144 filing)` |
| `15-12G` | G9 Periodic & event narrative | html | L2 | `(edgar-structure-headings (edgar-document-structure filing))` |
| `15-15D` | G9 Periodic & event narrative | html | L0 | `(edgar-form-info "15-15D")` |
| `15F-12B` | G9 Periodic & event narrative | html | L0 | `(edgar-form-info "15F-12B")` |
| `15F-12G` | G9 Periodic & event narrative | html | L0 | `(edgar-form-info "15F-12G")` |
| `18-K` | G9 Periodic & event narrative | html | L2 | `(edgar-structure-headings (edgar-document-structure filing))` |
| `20-F` | G9 Periodic & event narrative | html | L2 | `(edgar-structure-headings (edgar-document-structure filing))` |
| `20FR12B` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "20FR12B")` |
| `20FR12G` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "20FR12G")` |
| `24F-2NT` | G10 Investment-company registration | xml | L1 | `(edgar-text filing)` |
| `25` | G9 Periodic & event narrative | html | L2 | `(edgar-structure-headings (edgar-document-structure filing))` |
| `25-NSE` | G9 Periodic & event narrative | xml | L1 | `(edgar-text filing)` |
| `253G1` | G11 Reg CF & Reg A | html | L1 | `(edgar-text filing)` |
| `253G2` | G11 Reg CF & Reg A | html | L1 | `(edgar-text filing)` |
| `3` | G1 Ownership | xml | L2 | `(edgar-form3-holdings filing)` |
| `305B2` | G13 Tail | html | L0 | `(edgar-form-info "305B2")` |
| `4` | G1 Ownership | xml | L2 | `(edgar-form4-transactions filing)` |
| `40-17F1` | G10 Investment-company registration | html | L1 | `(edgar-text filing)` |
| `40-17F2` | G10 Investment-company registration | html | L1 | `(edgar-text filing)` |
| `40-17G` | G10 Investment-company registration | html | L1 | `(edgar-text filing)` |
| `40-24B2` | G10 Investment-company registration | html | L1 | `(edgar-text filing)` |
| `40-33` | G10 Investment-company registration | html | L1 | `(edgar-text filing)` |
| `40-6B` | G10 Investment-company registration | html | L1 | `(edgar-text filing)` |
| `40-8F-2` | G10 Investment-company registration | html | L1 | `(edgar-text filing)` |
| `40-APP` | G10 Investment-company registration | html | L1 | `(edgar-text filing)` |
| `40-F` | G9 Periodic & event narrative | html | L2 | `(edgar-structure-headings (edgar-document-structure filing))` |
| `40FR12B` | G7 Prospectuses & registration | html | L1 | `(edgar-text filing)` |
| `40FR12G` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "40FR12G")` |
| `424B1` | G7 Prospectuses & registration | html | L2 | `(edgar-structure-headings (edgar-document-structure filing))` |
| `424B2` | G7 Prospectuses & registration | html | L1 | `(edgar-text filing)` |
| `424B3` | G7 Prospectuses & registration | html | L1 | `(edgar-text filing)` |
| `424B4` | G7 Prospectuses & registration | html | L1 | `(edgar-text filing)` |
| `424B5` | G7 Prospectuses & registration | html | L1 | `(edgar-text filing)` |
| `424B7` | G7 Prospectuses & registration | html | L1 | `(edgar-text filing)` |
| `424B8` | G7 Prospectuses & registration | html | L1 | `(edgar-text filing)` |
| `424H` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "424H")` |
| `424I` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "424I")` |
| `425` | G8 Proxy & M&A | html | L1 | `(edgar-text filing)` |
| `485APOS` | G10 Investment-company registration | html | L1 | `(edgar-text filing)` |
| `485BPOS` | G10 Investment-company registration | html | L2 | `(edgar-structure-headings (edgar-document-structure filing))` |
| `485BXT` | G10 Investment-company registration | html | L1 | `(edgar-text filing)` |
| `486APOS` | G10 Investment-company registration | html | L1 | `(edgar-text filing)` |
| `486BPOS` | G10 Investment-company registration | html | L1 | `(edgar-text filing)` |
| `486BXT` | G10 Investment-company registration | html | L1 | `(edgar-text filing)` |
| `487` | G10 Investment-company registration | html | L1 | `(edgar-text filing)` |
| `497` | G10 Investment-company registration | html | L1 | `(edgar-text filing)` |
| `497AD` | G10 Investment-company registration | html | L1 | `(edgar-text filing)` |
| `497J` | G10 Investment-company registration | html | L1 | `(edgar-text filing)` |
| `497K` | G10 Investment-company registration | html | L2 | `(edgar-structure-headings (edgar-document-structure filing))` |
| `497VPI` | G10 Investment-company registration | html | L1 | `(edgar-text filing)` |
| `497VPSUB` | G10 Investment-company registration | html | L1 | `(edgar-text filing)` |
| `497VPU` | G10 Investment-company registration | html | L1 | `(edgar-text filing)` |
| `5` | G1 Ownership | xml | L2 | `(edgar-form5-holdings filing)` |
| `6-K` | G9 Periodic & event narrative | html | L2 | `(edgar-structure-headings (edgar-document-structure filing))` |
| `6B NTC` | G9 Periodic & event narrative | html | L0 | `(edgar-form-info "6B NTC")` |
| `6B ORDR` | G9 Periodic & event narrative | html | L0 | `(edgar-form-info "6B ORDR")` |
| `8-A12B` | G7 Prospectuses & registration | html | L1 | `(edgar-text filing)` |
| `8-A12G` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "8-A12G")` |
| `8-K` | G9 Periodic & event narrative | html | L2 | `(edgar-structure-headings (edgar-document-structure filing))` |
| `8-K12B` | G9 Periodic & event narrative | html | L1 | `(edgar-text filing)` |
| `ABS-15G` | G6 Asset-backed | html | L1 | `(edgar-text filing)` |
| `ABS-EE` | G6 Asset-backed | xml | L2 | `(edgar-xml filing)` |
| `ADV-H-T` | G12 Broker-dealer, market structure, staff | text | L0 | `(edgar-form-info "ADV-H-T")` |
| `ANNLRPT` | G9 Periodic & event narrative | html | L0 | `(edgar-form-info "ANNLRPT")` |
| `APP NTC` | G10 Investment-company registration | pdf | L1 | `(edgar-text filing)` |
| `APP ORDR` | G10 Investment-company registration | pdf | L1 | `(edgar-text filing)` |
| `APP WD` | G10 Investment-company registration | html | L1 | `(edgar-text filing)` |
| `APP WDG` | G10 Investment-company registration | pdf | L1 | `(edgar-text filing)` |
| `ARS` | G8 Proxy & M&A | pdf | L1 | `(edgar-text filing)` |
| `ATS-N` | G12 Broker-dealer, market structure, staff | xml | L1 | `(edgar-text filing)` |
| `ATS-N/CA` | G12 Broker-dealer, market structure, staff | xml | L1 | `(edgar-text filing)` |
| `ATS-N/MA` | G12 Broker-dealer, market structure, staff | xml | L1 | `(edgar-text filing)` |
| `ATS-N/OFA` | G12 Broker-dealer, market structure, staff | xml | L1 | `(edgar-text filing)` |
| `ATS-N/UA` | G12 Broker-dealer, market structure, staff | xml | L1 | `(edgar-text filing)` |
| `AW` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "AW")` |
| `C` | G11 Reg CF & Reg A | xml | L2 | `(edgar-xml filing)` |
| `C-AR` | G11 Reg CF & Reg A | xml | L2 | `(edgar-xml filing)` |
| `C-AR-W` | G11 Reg CF & Reg A | xml | L1 | `(edgar-text filing)` |
| `C-TR` | G11 Reg CF & Reg A | xml | L1 | `(edgar-text filing)` |
| `C-TR-W` | G11 Reg CF & Reg A | xml | L1 | `(edgar-text filing)` |
| `C-U` | G11 Reg CF & Reg A | xml | L1 | `(edgar-text filing)` |
| `C-W` | G11 Reg CF & Reg A | xml | L1 | `(edgar-text filing)` |
| `CB` | G8 Proxy & M&A | html | L1 | `(edgar-text filing)` |
| `CERT` | G9 Periodic & event narrative | html | L0 | `(edgar-form-info "CERT")` |
| `CFPORTAL` | G12 Broker-dealer, market structure, staff | xml | L1 | `(edgar-text filing)` |
| `CFPORTAL-W` | G12 Broker-dealer, market structure, staff | xml | L1 | `(edgar-text filing)` |
| `CORRESP` | G12 Broker-dealer, market structure, staff | text | L1 | `(edgar-text filing)` |
| `CT ORDER` | G10 Investment-company registration | pdf | L1 | `(edgar-text filing)` |
| `D` | G2 Notice of sale / Reg D | xml | L2 | `(edgar-form-d filing)` |
| `DEF 14A` | G8 Proxy & M&A | html | L2 | `(edgar-structure-headings (edgar-document-structure filing))` |
| `DEF 14C` | G8 Proxy & M&A | html | L2 | `(edgar-structure-headings (edgar-document-structure filing))` |
| `DEFA14A` | G8 Proxy & M&A | html | L1 | `(edgar-text filing)` |
| `DEFA14C` | G8 Proxy & M&A | html | L1 | `(edgar-text filing)` |
| `DEFC14A` | G8 Proxy & M&A | html | L1 | `(edgar-text filing)` |
| `DEFM14A` | G8 Proxy & M&A | html | L2 | `(edgar-structure-headings (edgar-document-structure filing))` |
| `DEFM14C` | G8 Proxy & M&A | html | L1 | `(edgar-text filing)` |
| `DEFR14A` | G8 Proxy & M&A | html | L1 | `(edgar-text filing)` |
| `DEFR14C` | G8 Proxy & M&A | html | L1 | `(edgar-text filing)` |
| `DEL AM` | G10 Investment-company registration | html | L1 | `(edgar-text filing)` |
| `DFAN14A` | G8 Proxy & M&A | html | L1 | `(edgar-text filing)` |
| `DFRN14A` | G8 Proxy & M&A | html | L1 | `(edgar-text filing)` |
| `DOS` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "DOS")` |
| `DOSLTR` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "DOSLTR")` |
| `DRS` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "DRS")` |
| `DRSLTR` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "DRSLTR")` |
| `DSTRBRPT` | G9 Periodic & event narrative | html | L0 | `(edgar-form-info "DSTRBRPT")` |
| `EFFECT` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "EFFECT")` |
| `F-1` | G7 Prospectuses & registration | html | L1 | `(edgar-text filing)` |
| `F-10` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "F-10")` |
| `F-10EF` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "F-10EF")` |
| `F-10POS` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "F-10POS")` |
| `F-1MEF` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "F-1MEF")` |
| `F-3` | G7 Prospectuses & registration | html | L1 | `(edgar-text filing)` |
| `F-3ASR` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "F-3ASR")` |
| `F-3MEF` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "F-3MEF")` |
| `F-4` | G7 Prospectuses & registration | html | L2 | `(edgar-structure-headings (edgar-document-structure filing))` |
| `F-6` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "F-6")` |
| `F-6 POS` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "F-6 POS")` |
| `F-6EF` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "F-6EF")` |
| `F-N` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "F-N")` |
| `F-X` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "F-X")` |
| `FWP` | G7 Prospectuses & registration | html | L1 | `(edgar-text filing)` |
| `G-FIN` | G12 Broker-dealer, market structure, staff | text | L0 | `(edgar-form-info "G-FIN")` |
| `IRANNOTICE` | G9 Periodic & event narrative | html | L0 | `(edgar-form-info "IRANNOTICE")` |
| `MA` | G12 Broker-dealer, market structure, staff | xml | L1 | `(edgar-text filing)` |
| `MA-A` | G12 Broker-dealer, market structure, staff | xml | L1 | `(edgar-text filing)` |
| `MA-I` | G12 Broker-dealer, market structure, staff | xml | L1 | `(edgar-text filing)` |
| `MA-W` | G12 Broker-dealer, market structure, staff | xml | L1 | `(edgar-text filing)` |
| `MSD` | G10 Investment-company registration | text | L1 | `(edgar-text filing)` |
| `N-14` | G10 Investment-company registration | html | L1 | `(edgar-text filing)` |
| `N-14 8C` | G10 Investment-company registration | html | L1 | `(edgar-text filing)` |
| `N-1A` | G10 Investment-company registration | html | L2 | `(edgar-structure-headings (edgar-document-structure filing))` |
| `N-2` | G10 Investment-company registration | html | L1 | `(edgar-text filing)` |
| `N-2 POSASR` | G10 Investment-company registration | html | L1 | `(edgar-text filing)` |
| `N-23C-2` | G5 Fund periodic reports | html | L1 | `(edgar-text filing)` |
| `N-23C3A` | G5 Fund periodic reports | html | L1 | `(edgar-text filing)` |
| `N-23C3B` | G5 Fund periodic reports | html | L1 | `(edgar-text filing)` |
| `N-2ASR` | G10 Investment-company registration | html | L1 | `(edgar-text filing)` |
| `N-2MEF` | G10 Investment-company registration | html | L1 | `(edgar-text filing)` |
| `N-30B-2` | G5 Fund periodic reports | html | L1 | `(edgar-text filing)` |
| `N-30D` | G5 Fund periodic reports | html | L1 | `(edgar-text filing)` |
| `N-4` | G10 Investment-company registration | html | L1 | `(edgar-text filing)` |
| `N-54A` | G5 Fund periodic reports | html | L1 | `(edgar-text filing)` |
| `N-54C` | G5 Fund periodic reports | html | L1 | `(edgar-text filing)` |
| `N-6` | G10 Investment-company registration | html | L1 | `(edgar-text filing)` |
| `N-6F` | G5 Fund periodic reports | html | L1 | `(edgar-text filing)` |
| `N-8A` | G5 Fund periodic reports | html | L1 | `(edgar-text filing)` |
| `N-8F` | G5 Fund periodic reports | html | L1 | `(edgar-text filing)` |
| `N-8F NTC` | G5 Fund periodic reports | pdf | L1 | `(edgar-text filing)` |
| `N-8F ORDR` | G5 Fund periodic reports | pdf | L1 | `(edgar-text filing)` |
| `N-CEN` | G5 Fund periodic reports | xml | L2 | `(edgar-xml filing)` |
| `N-CSR` | G5 Fund periodic reports | html | L1 | `(edgar-text filing)` |
| `N-CSRS` | G5 Fund periodic reports | html | L1 | `(edgar-text filing)` |
| `N-MFP3` | G5 Fund periodic reports | xml | L2 | `(edgar-xml filing)` |
| `N-PX` | G5 Fund periodic reports | xml | L1 | `(edgar-text filing)` |
| `N-VP` | G5 Fund periodic reports | html | L1 | `(edgar-text filing)` |
| `N-VPFS` | G5 Fund periodic reports | html | L1 | `(edgar-text filing)` |
| `NPORT-P` | G5 Fund periodic reports | xml | L2 | `(edgar-xml filing)` |
| `NRSRO-CE` | G12 Broker-dealer, market structure, staff | pdf | L1 | `(edgar-text filing)` |
| `NRSRO-UPD` | G12 Broker-dealer, market structure, staff | pdf | L1 | `(edgar-text filing)` |
| `NT 10-K` | G9 Periodic & event narrative | html | L2 | `(edgar-structure-headings (edgar-document-structure filing))` |
| `NT 10-Q` | G9 Periodic & event narrative | html | L2 | `(edgar-structure-headings (edgar-document-structure filing))` |
| `NT 11-K` | G9 Periodic & event narrative | html | L2 | `(edgar-structure-headings (edgar-document-structure filing))` |
| `NT 20-F` | G9 Periodic & event narrative | html | L2 | `(edgar-structure-headings (edgar-document-structure filing))` |
| `NT N-CEN` | G5 Fund periodic reports | xml | L1 | `(edgar-text filing)` |
| `NT NPORT-P` | G5 Fund periodic reports | xml | L1 | `(edgar-text filing)` |
| `NT-NCEN` | G5 Fund periodic reports | html | L1 | `(edgar-text filing)` |
| `NT-NCSR` | G5 Fund periodic reports | html | L1 | `(edgar-text filing)` |
| `NTFNCSR` | G5 Fund periodic reports | html | L1 | `(edgar-text filing)` |
| `POS 8C` | G13 Tail | html | L1 | `(edgar-text filing)` |
| `POS AM` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "POS AM")` |
| `POS AMI` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "POS AMI")` |
| `POS EX` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "POS EX")` |
| `POSASR` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "POSASR")` |
| `PRE 14A` | G8 Proxy & M&A | html | L1 | `(edgar-text filing)` |
| `PRE 14C` | G8 Proxy & M&A | html | L1 | `(edgar-text filing)` |
| `PREC14A` | G8 Proxy & M&A | html | L1 | `(edgar-text filing)` |
| `PREM14A` | G8 Proxy & M&A | html | L1 | `(edgar-text filing)` |
| `PREM14C` | G8 Proxy & M&A | html | L1 | `(edgar-text filing)` |
| `PREN14A` | G8 Proxy & M&A | html | L1 | `(edgar-text filing)` |
| `PRER14A` | G8 Proxy & M&A | html | L1 | `(edgar-text filing)` |
| `PRER14C` | G8 Proxy & M&A | html | L1 | `(edgar-text filing)` |
| `PRRN14A` | G8 Proxy & M&A | html | L1 | `(edgar-text filing)` |
| `PX14A6G` | G8 Proxy & M&A | html | L1 | `(edgar-text filing)` |
| `QRTLYRPT` | G9 Periodic & event narrative | html | L1 | `(edgar-text filing)` |
| `QUALIF` | G11 Reg CF & Reg A | xml | L1 | `(edgar-text filing)` |
| `REVOKED` | G9 Periodic & event narrative | html | L0 | `(edgar-form-info "REVOKED")` |
| `RW` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "RW")` |
| `S-1` | G7 Prospectuses & registration | html | L2 | `(edgar-structure-headings (edgar-document-structure filing))` |
| `S-11` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "S-11")` |
| `S-1MEF` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "S-1MEF")` |
| `S-3` | G7 Prospectuses & registration | html | L2 | `(edgar-section filing "Risk Factors")` |
| `S-3ASR` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "S-3ASR")` |
| `S-3D` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "S-3D")` |
| `S-3DPOS` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "S-3DPOS")` |
| `S-3MEF` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "S-3MEF")` |
| `S-4` | G7 Prospectuses & registration | html | L1 | `(edgar-text filing)` |
| `S-6` | G10 Investment-company registration | html | L1 | `(edgar-text filing)` |
| `S-8` | G7 Prospectuses & registration | html | L1 | `(edgar-text filing)` |
| `S-8 POS` | G7 Prospectuses & registration | html | L1 | `(edgar-text filing)` |
| `S-B` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "S-B")` |
| `SBSE` | G12 Broker-dealer, market structure, staff | xml | L1 | `(edgar-text filing)` |
| `SBSE-A` | G12 Broker-dealer, market structure, staff | xml | L1 | `(edgar-text filing)` |
| `SBSE-C` | G12 Broker-dealer, market structure, staff | xml | L1 | `(edgar-text filing)` |
| `SC 13D` | G3 Beneficial ownership 13D/13G | xml | L0 | `(edgar-form-info "SC 13D")` |
| `SC 13E3` | G3 Beneficial ownership 13D/13G | html | L1 | `(edgar-text filing)` |
| `SC 14D9` | G8 Proxy & M&A | html | L2 | `(edgar-structure-headings (edgar-document-structure filing))` |
| `SC 14F1` | G3 Beneficial ownership 13D/13G | html | L1 | `(edgar-text filing)` |
| `SC 14N` | G8 Proxy & M&A | html | L1 | `(edgar-text filing)` |
| `SC TO-C` | G8 Proxy & M&A | html | L2 | `(edgar-structure-headings (edgar-document-structure filing))` |
| `SC TO-I` | G8 Proxy & M&A | html | L2 | `(edgar-structure-headings (edgar-document-structure filing))` |
| `SC TO-T` | G8 Proxy & M&A | html | L2 | `(edgar-structure-headings (edgar-document-structure filing))` |
| `SC14D1F` | G8 Proxy & M&A | html | L1 | `(edgar-text filing)` |
| `SC14D9C` | G8 Proxy & M&A | html | L1 | `(edgar-text filing)` |
| `SCHEDULE 13D` | G3 Beneficial ownership 13D/13G | xml | L2 | `(edgar-schedule-13d-g-cover-page filing)` |
| `SCHEDULE 13G` | G3 Beneficial ownership 13D/13G | xml | L2 | `(edgar-schedule-13d-g-cover-page filing)` |
| `SD` | G9 Periodic & event narrative | html | L2 | `(edgar-structure-headings (edgar-document-structure filing))` |
| `SEC STAFF ACTIO` | G12 Broker-dealer, market structure, staff | pdf | L1 | `(edgar-text filing)` |
| `SEC STAFF LETTE` | G12 Broker-dealer, market structure, staff | pdf | L1 | `(edgar-text filing)` |
| `SF-1` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "SF-1")` |
| `SF-3` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "SF-3")` |
| `SP 15D2` | G9 Periodic & event narrative | html | L0 | `(edgar-form-info "SP 15D2")` |
| `SUPPL` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "SUPPL")` |
| `TA-1` | G12 Broker-dealer, market structure, staff | xml | L1 | `(edgar-text filing)` |
| `TA-2` | G12 Broker-dealer, market structure, staff | xml | L1 | `(edgar-text filing)` |
| `TA-W` | G12 Broker-dealer, market structure, staff | xml | L1 | `(edgar-text filing)` |
| `UPLOAD` | G12 Broker-dealer, market structure, staff | text | L1 | `(edgar-text filing)` |
| `X-17A-5` | G12 Broker-dealer, market structure, staff | xml | L1 | `(edgar-text filing)` |
<!-- END GENERATED FORM COVERAGE -->

## Families (Q2 2026 volume; family rules are a first-pass grouping)

| Family | Filings | Share | Base forms | Backend | Biggest members |
|---|---:|---:|---:|---|---|
| G1 Ownership | 116,225 | 32.9% | 3 | XML | 4 (104,601), 3, 5 |
| G7 Prospectuses & registration | 66,922 | 18.9% | 58 | HTML | 424B2 (49,609), FWP, 424B3, EFFECT, 424B5, S-8 |
| G9 Periodic & event narrative | 37,105 | 10.5% | 30 | HTML | 8-K, 6-K, 10-Q, SD, 10-K, 11-K |
| G2 Notice of sale / Reg D | 36,377 | 10.3% | 2 | XML | 144 (19,526), D (16,851) |
| G10 Investment-company registration | 24,427 | 6.9% | 40 | HTML | 497K, 497, 485BPOS, 40-APP |
| G5 Fund periodic reports | 19,096 | 5.4% | 25 | XML | NPORT-P (14,407), N-MFP3, N-CSRS, N-CSR |
| G3 Beneficial ownership 13D/13G | 18,768 | 5.3% | 5 | XML | SCHEDULE 13G (16,008), 13D |
| G4 13F holdings | 11,633 | 3.3% | 2 | XML | 13F-HR, 13F-NT |
| G8 Proxy & M&A | 11,244 | 3.2% | 31 | HTML | DEFA14A, DEF 14A, ARS, 425 |
| G6 Asset-backed | 5,714 | 1.6% | 3 | mixed | 10-D, ABS-EE, ABS-15G |
| G12 Broker-dealer, staff, market structure | 2,577 | 0.7% | 26 | mixed | CORRESP, X-17A-5, UPLOAD, MA-I |
| G11 Reg CF & Reg A | 3,159 | 0.9% | 18 | XML/HTML | 1-U, C-AR, C, 1-K, C-U, C-TR |
| G13 Tail | 46 | 0.0% | 2 | HTML | 305B2, POS 8C |

## Current implementation state

The per-form table above is generated from the registry and is authoritative
for the current declared level. Level labels are claims about implemented
support; fixture coverage is separately checked by `eask run script coverage`.
Do not infer that all forms are parsed from the fact that all 245 appear in the
catalog.

G12 has 24 of 26 base forms at L1: CORRESP, UPLOAD, X-17A-5, MA-I, TA-2,
ATS-N and its four variants, CFPORTAL and CFPORTAL-W, MA/MA-A/MA-W,
SBSE/SBSE-A/SBSE-C, TA-1/TA-W, NRSRO-CE, NRSRO-UPD, SEC STAFF ACTIO, and
SEC STAFF LETTE. They account for 2,566 of 2,577 G12 filings in the Q2
snapshot (99.6%). Generic primary-document metadata and structure APIs cover
HTML, XML, text, and PDF sources. Complete-submission PDF bodies are decoded
with `uudecode`; PDF text and paragraphs use `pdftotext`.

The two remaining L0 forms are ADV-H-T and G-FIN (11 Q2 filings combined).
Their public `.paper` controls and complete submissions contain only an
auto-generated paper notice with a document control number; the original
reports are absent from the SEC accession directories. The recorded files,
accessions, and exact notices are listed in [the G12 source evidence](../test/fixtures/structured-sources.md#g12-source-limitations).

G10 currently has 27 of 40 base forms at L1: 24F-2NT, 40-17F1, 40-17G,
40-6B, 40-APP, 485APOS, 485BPOS, 485BXT, 486APOS, 486BPOS, 486BXT, 487,
497, 497AD, 497J, 497K, 497VPI, 497VPSUB, 497VPU, N-14, N-14 8C, N-1A,
N-2, N-2ASR, N-4, N-6, and S-6. The remaining 13 forms are still L0.

All 25 G5 base forms are now L1 or L2, accounting for all 19,096 G5 filings in
the Q2 snapshot. N-8F NTC and N-8F ORDR use recorded PDF primaries and the
binary-safe `pdftotext` path; their complete submissions contain uuencoded PDF
payloads rather than an alternate readable document.

## Gaps that are not about a specific form

Implemented whole-library capabilities: raw-XML access, multi-document filings
(exhibits), quarterly/daily enumeration across all filers, and a cache plus rate
limiter.  Remaining gaps tracked as beads: history past the SEC's ~1000-filing
`recent` window, amendment handling, legacy text-only filings, inline-XBRL facts
(in xbrl.el), and testing each form on more than one filer.

The shared `edgar-documents` / `edgar-exhibit` API is also exercised on
recorded foreign-issuer filings: 6-K directory enumeration and a 40-F EX-23.1
exhibit text excerpt (Shopify, accession 0001594805-24-000007), plus EX-99.1
access on a distinct 6-K filer, Decent Holding Inc. (CIK 1958133, accession
0001185185-26-003233). These validate access to filing-level documents; they
do not imply that every G9 form's narrative layout has a dedicated parser.
Form SD is now L2 based on Apple's
2026-05-28 filing (accession 0001140361-26-023149), with generic item access
goldened for Items 1.01, 1.02, 2.01, and 3.01. Form 18-K has L2 generic HTML
structure and golden body-path coverage from the Republic of Chile filing
(accession 0001104659-25-094669, filed 2025-09-30); its numeric disclosure
prompts do not currently appear as parser-level item sections.

Form 25 has L2 generic HTML body access with golden strings, recorded from Walmart (accession
0000104169-25-000201, filed 2025-12-08). Form 25-NSE has L1 generic XML
structure access, recorded from NRX Pharmaceuticals (accession
0001354457-26-000493, filed 2026-05-22). These short delisting notifications
do not have form-specific item headings exposed by the section parser; their
L1/L2 levels measure generic primary-document readability and, for L2, golden
strings. Form 15-12G has L2 generic HTML body coverage with golden strings,
backed by Apogee Therapeutics (accession 0001140361-26-036410, filed
2026-09-14). NT 10-K, NT 10-Q, NT 11-K, and NT 20-F have L2 generic HTML body
coverage with golden strings
from Digital Brand Media (accessions 0001185185-18-002101 and
0001127475-17-000008), Old Republic (0000074260-26-000076), and PT
Telekomunikasi Indonesia (0001001807-26-000016), respectively. These are
Form 12b-25 notices; coverage means readable text and generic document paths,
not a form-specific extension-deadline or reason parser.

Forms 1-SA and 1-U have L2 HTML section goldens for current and older filings.
Forms 1-K and 1-Z use structured XML primaries; their L1 fixtures verify the
generic XML projection and readable text, without form-specific typed accessors.

Work is tracked in `.beads/` (`br ready`, `br list`).
