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
XML uses `.xml` or `.xml.gz`, and text uses `.txt` or `.txt.gz`.
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
| `1-A` | G11 Reg CF & Reg A | xml | L0 | `(edgar-form-info "1-A")` |
| `1-A POS` | G11 Reg CF & Reg A | xml | L0 | `(edgar-form-info "1-A POS")` |
| `1-A-W` | G11 Reg CF & Reg A | xml | L0 | `(edgar-form-info "1-A-W")` |
| `1-K` | G9 Periodic & event narrative | html | L0 | `(edgar-form-info "1-K")` |
| `1-SA` | G9 Periodic & event narrative | html | L0 | `(edgar-form-info "1-SA")` |
| `1-U` | G9 Periodic & event narrative | html | L0 | `(edgar-form-info "1-U")` |
| `1-Z` | G9 Periodic & event narrative | html | L0 | `(edgar-form-info "1-Z")` |
| `10-12B` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "10-12B")` |
| `10-12G` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "10-12G")` |
| `10-D` | G6 Asset-backed | xml | L0 | `(edgar-form-info "10-D")` |
| `10-K` | G9 Periodic & event narrative | html | L0 | `(edgar-form-info "10-K")` |
| `10-KT` | G9 Periodic & event narrative | html | L0 | `(edgar-form-info "10-KT")` |
| `10-Q` | G9 Periodic & event narrative | html | L0 | `(edgar-form-info "10-Q")` |
| `11-K` | G9 Periodic & event narrative | html | L2 | `(edgar-structure-headings (edgar-document-structure filing))` |
| `13F-HR` | G4 13F holdings | xml | L2 | `(edgar-13f-holdings filing)` |
| `13F-NT` | G4 13F holdings | xml | L0 | `(edgar-form-info "13F-NT")` |
| `144` | G2 Notice of sale / Reg D | xml | L2 | `(edgar-xml filing)` |
| `15-12G` | G9 Periodic & event narrative | html | L0 | `(edgar-form-info "15-12G")` |
| `15-15D` | G9 Periodic & event narrative | html | L0 | `(edgar-form-info "15-15D")` |
| `15F-12B` | G9 Periodic & event narrative | html | L0 | `(edgar-form-info "15F-12B")` |
| `15F-12G` | G9 Periodic & event narrative | html | L0 | `(edgar-form-info "15F-12G")` |
| `18-K` | G9 Periodic & event narrative | html | L0 | `(edgar-form-info "18-K")` |
| `20-F` | G9 Periodic & event narrative | html | L0 | `(edgar-form-info "20-F")` |
| `20FR12B` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "20FR12B")` |
| `20FR12G` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "20FR12G")` |
| `24F-2NT` | G10 Investment-company registration | html | L0 | `(edgar-form-info "24F-2NT")` |
| `25` | G9 Periodic & event narrative | html | L0 | `(edgar-form-info "25")` |
| `25-NSE` | G9 Periodic & event narrative | html | L0 | `(edgar-form-info "25-NSE")` |
| `253G1` | G11 Reg CF & Reg A | xml | L0 | `(edgar-form-info "253G1")` |
| `253G2` | G11 Reg CF & Reg A | xml | L0 | `(edgar-form-info "253G2")` |
| `3` | G1 Ownership | xml | L2 | `(edgar-xml filing)` |
| `305B2` | G13 Tail | html | L0 | `(edgar-form-info "305B2")` |
| `4` | G1 Ownership | xml | L2 | `(edgar-xml filing)` |
| `40-17F1` | G10 Investment-company registration | html | L0 | `(edgar-form-info "40-17F1")` |
| `40-17F2` | G10 Investment-company registration | html | L0 | `(edgar-form-info "40-17F2")` |
| `40-17G` | G10 Investment-company registration | html | L0 | `(edgar-form-info "40-17G")` |
| `40-24B2` | G10 Investment-company registration | html | L0 | `(edgar-form-info "40-24B2")` |
| `40-33` | G10 Investment-company registration | html | L0 | `(edgar-form-info "40-33")` |
| `40-6B` | G10 Investment-company registration | html | L0 | `(edgar-form-info "40-6B")` |
| `40-8F-2` | G10 Investment-company registration | html | L0 | `(edgar-form-info "40-8F-2")` |
| `40-APP` | G10 Investment-company registration | html | L0 | `(edgar-form-info "40-APP")` |
| `40-F` | G9 Periodic & event narrative | html | L2 | `(edgar-structure-headings (edgar-document-structure filing))` |
| `40FR12B` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "40FR12B")` |
| `40FR12G` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "40FR12G")` |
| `424B1` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "424B1")` |
| `424B2` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "424B2")` |
| `424B3` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "424B3")` |
| `424B4` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "424B4")` |
| `424B5` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "424B5")` |
| `424B7` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "424B7")` |
| `424B8` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "424B8")` |
| `424H` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "424H")` |
| `424I` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "424I")` |
| `425` | G8 Proxy & M&A | html | L0 | `(edgar-form-info "425")` |
| `485APOS` | G10 Investment-company registration | html | L0 | `(edgar-form-info "485APOS")` |
| `485BPOS` | G10 Investment-company registration | html | L0 | `(edgar-form-info "485BPOS")` |
| `485BXT` | G10 Investment-company registration | html | L0 | `(edgar-form-info "485BXT")` |
| `486APOS` | G10 Investment-company registration | html | L0 | `(edgar-form-info "486APOS")` |
| `486BPOS` | G10 Investment-company registration | html | L0 | `(edgar-form-info "486BPOS")` |
| `486BXT` | G10 Investment-company registration | html | L0 | `(edgar-form-info "486BXT")` |
| `487` | G10 Investment-company registration | html | L0 | `(edgar-form-info "487")` |
| `497` | G10 Investment-company registration | html | L0 | `(edgar-form-info "497")` |
| `497AD` | G10 Investment-company registration | html | L0 | `(edgar-form-info "497AD")` |
| `497J` | G10 Investment-company registration | html | L0 | `(edgar-form-info "497J")` |
| `497K` | G10 Investment-company registration | html | L1 | `(edgar-text filing)` |
| `497VPI` | G10 Investment-company registration | html | L0 | `(edgar-form-info "497VPI")` |
| `497VPSUB` | G10 Investment-company registration | html | L0 | `(edgar-form-info "497VPSUB")` |
| `497VPU` | G10 Investment-company registration | html | L0 | `(edgar-form-info "497VPU")` |
| `5` | G1 Ownership | xml | L0 | `(edgar-form-info "5")` |
| `6-K` | G9 Periodic & event narrative | html | L2 | `(edgar-structure-headings (edgar-document-structure filing))` |
| `6B NTC` | G9 Periodic & event narrative | html | L0 | `(edgar-form-info "6B NTC")` |
| `6B ORDR` | G9 Periodic & event narrative | html | L0 | `(edgar-form-info "6B ORDR")` |
| `8-A12B` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "8-A12B")` |
| `8-A12G` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "8-A12G")` |
| `8-K` | G9 Periodic & event narrative | html | L0 | `(edgar-form-info "8-K")` |
| `8-K12B` | G9 Periodic & event narrative | html | L0 | `(edgar-form-info "8-K12B")` |
| `ABS-15G` | G6 Asset-backed | xml | L0 | `(edgar-form-info "ABS-15G")` |
| `ABS-EE` | G6 Asset-backed | xml | L2 | `(edgar-xml filing)` |
| `ADV-H-T` | G12 Broker-dealer, market structure, staff | xml | L0 | `(edgar-form-info "ADV-H-T")` |
| `ANNLRPT` | G9 Periodic & event narrative | html | L0 | `(edgar-form-info "ANNLRPT")` |
| `APP NTC` | G10 Investment-company registration | html | L0 | `(edgar-form-info "APP NTC")` |
| `APP ORDR` | G10 Investment-company registration | html | L0 | `(edgar-form-info "APP ORDR")` |
| `APP WD` | G10 Investment-company registration | html | L0 | `(edgar-form-info "APP WD")` |
| `APP WDG` | G10 Investment-company registration | html | L0 | `(edgar-form-info "APP WDG")` |
| `ARS` | G8 Proxy & M&A | html | L0 | `(edgar-form-info "ARS")` |
| `ATS-N` | G12 Broker-dealer, market structure, staff | xml | L0 | `(edgar-form-info "ATS-N")` |
| `ATS-N/CA` | G12 Broker-dealer, market structure, staff | xml | L0 | `(edgar-form-info "ATS-N/CA")` |
| `ATS-N/MA` | G12 Broker-dealer, market structure, staff | xml | L0 | `(edgar-form-info "ATS-N/MA")` |
| `ATS-N/OFA` | G12 Broker-dealer, market structure, staff | xml | L0 | `(edgar-form-info "ATS-N/OFA")` |
| `ATS-N/UA` | G12 Broker-dealer, market structure, staff | xml | L0 | `(edgar-form-info "ATS-N/UA")` |
| `AW` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "AW")` |
| `C` | G11 Reg CF & Reg A | xml | L0 | `(edgar-form-info "C")` |
| `C-AR` | G11 Reg CF & Reg A | xml | L2 | `(edgar-xml filing)` |
| `C-AR-W` | G11 Reg CF & Reg A | xml | L0 | `(edgar-form-info "C-AR-W")` |
| `C-TR` | G11 Reg CF & Reg A | xml | L0 | `(edgar-form-info "C-TR")` |
| `C-TR-W` | G11 Reg CF & Reg A | xml | L0 | `(edgar-form-info "C-TR-W")` |
| `C-U` | G11 Reg CF & Reg A | xml | L0 | `(edgar-form-info "C-U")` |
| `C-W` | G11 Reg CF & Reg A | xml | L0 | `(edgar-form-info "C-W")` |
| `CB` | G8 Proxy & M&A | html | L0 | `(edgar-form-info "CB")` |
| `CERT` | G9 Periodic & event narrative | html | L0 | `(edgar-form-info "CERT")` |
| `CFPORTAL` | G12 Broker-dealer, market structure, staff | xml | L0 | `(edgar-form-info "CFPORTAL")` |
| `CFPORTAL-W` | G12 Broker-dealer, market structure, staff | xml | L0 | `(edgar-form-info "CFPORTAL-W")` |
| `CORRESP` | G12 Broker-dealer, market structure, staff | text | L1 | `(edgar-text filing)` |
| `CT ORDER` | G10 Investment-company registration | html | L0 | `(edgar-form-info "CT ORDER")` |
| `D` | G2 Notice of sale / Reg D | xml | L0 | `(edgar-form-info "D")` |
| `DEF 14A` | G8 Proxy & M&A | html | L0 | `(edgar-form-info "DEF 14A")` |
| `DEF 14C` | G8 Proxy & M&A | html | L0 | `(edgar-form-info "DEF 14C")` |
| `DEFA14A` | G8 Proxy & M&A | html | L0 | `(edgar-form-info "DEFA14A")` |
| `DEFA14C` | G8 Proxy & M&A | html | L0 | `(edgar-form-info "DEFA14C")` |
| `DEFC14A` | G8 Proxy & M&A | html | L0 | `(edgar-form-info "DEFC14A")` |
| `DEFM14A` | G8 Proxy & M&A | html | L0 | `(edgar-form-info "DEFM14A")` |
| `DEFM14C` | G8 Proxy & M&A | html | L0 | `(edgar-form-info "DEFM14C")` |
| `DEFR14A` | G8 Proxy & M&A | html | L0 | `(edgar-form-info "DEFR14A")` |
| `DEFR14C` | G8 Proxy & M&A | html | L0 | `(edgar-form-info "DEFR14C")` |
| `DEL AM` | G10 Investment-company registration | html | L0 | `(edgar-form-info "DEL AM")` |
| `DFAN14A` | G8 Proxy & M&A | html | L0 | `(edgar-form-info "DFAN14A")` |
| `DFRN14A` | G8 Proxy & M&A | html | L0 | `(edgar-form-info "DFRN14A")` |
| `DOS` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "DOS")` |
| `DOSLTR` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "DOSLTR")` |
| `DRS` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "DRS")` |
| `DRSLTR` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "DRSLTR")` |
| `DSTRBRPT` | G9 Periodic & event narrative | html | L0 | `(edgar-form-info "DSTRBRPT")` |
| `EFFECT` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "EFFECT")` |
| `F-1` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "F-1")` |
| `F-10` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "F-10")` |
| `F-10EF` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "F-10EF")` |
| `F-10POS` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "F-10POS")` |
| `F-1MEF` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "F-1MEF")` |
| `F-3` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "F-3")` |
| `F-3ASR` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "F-3ASR")` |
| `F-3MEF` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "F-3MEF")` |
| `F-4` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "F-4")` |
| `F-6` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "F-6")` |
| `F-6 POS` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "F-6 POS")` |
| `F-6EF` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "F-6EF")` |
| `F-N` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "F-N")` |
| `F-X` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "F-X")` |
| `FWP` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "FWP")` |
| `G-FIN` | G12 Broker-dealer, market structure, staff | xml | L0 | `(edgar-form-info "G-FIN")` |
| `IRANNOTICE` | G9 Periodic & event narrative | html | L0 | `(edgar-form-info "IRANNOTICE")` |
| `MA` | G12 Broker-dealer, market structure, staff | xml | L0 | `(edgar-form-info "MA")` |
| `MA-A` | G12 Broker-dealer, market structure, staff | xml | L0 | `(edgar-form-info "MA-A")` |
| `MA-I` | G12 Broker-dealer, market structure, staff | xml | L0 | `(edgar-form-info "MA-I")` |
| `MA-W` | G12 Broker-dealer, market structure, staff | xml | L0 | `(edgar-form-info "MA-W")` |
| `MSD` | G10 Investment-company registration | html | L0 | `(edgar-form-info "MSD")` |
| `N-14` | G10 Investment-company registration | html | L0 | `(edgar-form-info "N-14")` |
| `N-14 8C` | G10 Investment-company registration | html | L0 | `(edgar-form-info "N-14 8C")` |
| `N-1A` | G10 Investment-company registration | html | L1 | `(edgar-text filing)` |
| `N-2` | G10 Investment-company registration | html | L0 | `(edgar-form-info "N-2")` |
| `N-2 POSASR` | G10 Investment-company registration | html | L0 | `(edgar-form-info "N-2 POSASR")` |
| `N-23C-2` | G5 Fund periodic reports | xml | L0 | `(edgar-form-info "N-23C-2")` |
| `N-23C3A` | G5 Fund periodic reports | xml | L0 | `(edgar-form-info "N-23C3A")` |
| `N-23C3B` | G5 Fund periodic reports | xml | L0 | `(edgar-form-info "N-23C3B")` |
| `N-2ASR` | G10 Investment-company registration | html | L0 | `(edgar-form-info "N-2ASR")` |
| `N-2MEF` | G10 Investment-company registration | html | L0 | `(edgar-form-info "N-2MEF")` |
| `N-30B-2` | G5 Fund periodic reports | xml | L0 | `(edgar-form-info "N-30B-2")` |
| `N-30D` | G5 Fund periodic reports | xml | L0 | `(edgar-form-info "N-30D")` |
| `N-4` | G10 Investment-company registration | html | L0 | `(edgar-form-info "N-4")` |
| `N-54A` | G5 Fund periodic reports | xml | L0 | `(edgar-form-info "N-54A")` |
| `N-54C` | G5 Fund periodic reports | xml | L0 | `(edgar-form-info "N-54C")` |
| `N-6` | G10 Investment-company registration | html | L0 | `(edgar-form-info "N-6")` |
| `N-6F` | G5 Fund periodic reports | xml | L0 | `(edgar-form-info "N-6F")` |
| `N-8A` | G5 Fund periodic reports | xml | L0 | `(edgar-form-info "N-8A")` |
| `N-8F` | G5 Fund periodic reports | xml | L0 | `(edgar-form-info "N-8F")` |
| `N-8F NTC` | G5 Fund periodic reports | xml | L0 | `(edgar-form-info "N-8F NTC")` |
| `N-8F ORDR` | G5 Fund periodic reports | xml | L0 | `(edgar-form-info "N-8F ORDR")` |
| `N-CEN` | G5 Fund periodic reports | xml | L2 | `(edgar-xml filing)` |
| `N-CSR` | G5 Fund periodic reports | html | L1 | `(edgar-text filing)` |
| `N-CSRS` | G5 Fund periodic reports | xml | L0 | `(edgar-form-info "N-CSRS")` |
| `N-MFP3` | G5 Fund periodic reports | xml | L2 | `(edgar-xml filing)` |
| `N-PX` | G5 Fund periodic reports | xml | L0 | `(edgar-form-info "N-PX")` |
| `N-VP` | G5 Fund periodic reports | xml | L0 | `(edgar-form-info "N-VP")` |
| `N-VPFS` | G5 Fund periodic reports | xml | L0 | `(edgar-form-info "N-VPFS")` |
| `NPORT-P` | G5 Fund periodic reports | xml | L2 | `(edgar-xml filing)` |
| `NRSRO-CE` | G12 Broker-dealer, market structure, staff | xml | L0 | `(edgar-form-info "NRSRO-CE")` |
| `NRSRO-UPD` | G12 Broker-dealer, market structure, staff | xml | L0 | `(edgar-form-info "NRSRO-UPD")` |
| `NT 10-K` | G9 Periodic & event narrative | html | L0 | `(edgar-form-info "NT 10-K")` |
| `NT 10-Q` | G9 Periodic & event narrative | html | L0 | `(edgar-form-info "NT 10-Q")` |
| `NT 11-K` | G9 Periodic & event narrative | html | L0 | `(edgar-form-info "NT 11-K")` |
| `NT 20-F` | G9 Periodic & event narrative | html | L0 | `(edgar-form-info "NT 20-F")` |
| `NT N-CEN` | G5 Fund periodic reports | xml | L0 | `(edgar-form-info "NT N-CEN")` |
| `NT NPORT-P` | G5 Fund periodic reports | xml | L0 | `(edgar-form-info "NT NPORT-P")` |
| `NT-NCEN` | G5 Fund periodic reports | xml | L0 | `(edgar-form-info "NT-NCEN")` |
| `NT-NCSR` | G5 Fund periodic reports | xml | L0 | `(edgar-form-info "NT-NCSR")` |
| `NTFNCSR` | G5 Fund periodic reports | xml | L0 | `(edgar-form-info "NTFNCSR")` |
| `POS 8C` | G13 Tail | html | L0 | `(edgar-form-info "POS 8C")` |
| `POS AM` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "POS AM")` |
| `POS AMI` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "POS AMI")` |
| `POS EX` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "POS EX")` |
| `POSASR` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "POSASR")` |
| `PRE 14A` | G8 Proxy & M&A | html | L0 | `(edgar-form-info "PRE 14A")` |
| `PRE 14C` | G8 Proxy & M&A | html | L0 | `(edgar-form-info "PRE 14C")` |
| `PREC14A` | G8 Proxy & M&A | html | L0 | `(edgar-form-info "PREC14A")` |
| `PREM14A` | G8 Proxy & M&A | html | L0 | `(edgar-form-info "PREM14A")` |
| `PREM14C` | G8 Proxy & M&A | html | L0 | `(edgar-form-info "PREM14C")` |
| `PREN14A` | G8 Proxy & M&A | html | L0 | `(edgar-form-info "PREN14A")` |
| `PRER14A` | G8 Proxy & M&A | html | L0 | `(edgar-form-info "PRER14A")` |
| `PRER14C` | G8 Proxy & M&A | html | L0 | `(edgar-form-info "PRER14C")` |
| `PRRN14A` | G8 Proxy & M&A | html | L0 | `(edgar-form-info "PRRN14A")` |
| `PX14A6G` | G8 Proxy & M&A | html | L0 | `(edgar-form-info "PX14A6G")` |
| `QRTLYRPT` | G9 Periodic & event narrative | html | L0 | `(edgar-form-info "QRTLYRPT")` |
| `QUALIF` | G11 Reg CF & Reg A | xml | L0 | `(edgar-form-info "QUALIF")` |
| `REVOKED` | G9 Periodic & event narrative | html | L0 | `(edgar-form-info "REVOKED")` |
| `RW` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "RW")` |
| `S-1` | G7 Prospectuses & registration | html | L2 | `(edgar-structure-headings (edgar-document-structure filing))` |
| `S-11` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "S-11")` |
| `S-1MEF` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "S-1MEF")` |
| `S-3` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "S-3")` |
| `S-3ASR` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "S-3ASR")` |
| `S-3D` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "S-3D")` |
| `S-3DPOS` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "S-3DPOS")` |
| `S-3MEF` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "S-3MEF")` |
| `S-4` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "S-4")` |
| `S-6` | G10 Investment-company registration | html | L0 | `(edgar-form-info "S-6")` |
| `S-8` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "S-8")` |
| `S-8 POS` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "S-8 POS")` |
| `S-B` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "S-B")` |
| `SBSE` | G12 Broker-dealer, market structure, staff | xml | L0 | `(edgar-form-info "SBSE")` |
| `SBSE-A` | G12 Broker-dealer, market structure, staff | xml | L0 | `(edgar-form-info "SBSE-A")` |
| `SBSE-C` | G12 Broker-dealer, market structure, staff | xml | L0 | `(edgar-form-info "SBSE-C")` |
| `SC 13D` | G3 Beneficial ownership 13D/13G | xml | L0 | `(edgar-form-info "SC 13D")` |
| `SC 13E3` | G3 Beneficial ownership 13D/13G | xml | L0 | `(edgar-form-info "SC 13E3")` |
| `SC 14D9` | G8 Proxy & M&A | html | L0 | `(edgar-form-info "SC 14D9")` |
| `SC 14F1` | G3 Beneficial ownership 13D/13G | xml | L0 | `(edgar-form-info "SC 14F1")` |
| `SC 14N` | G8 Proxy & M&A | html | L0 | `(edgar-form-info "SC 14N")` |
| `SC TO-C` | G8 Proxy & M&A | html | L0 | `(edgar-form-info "SC TO-C")` |
| `SC TO-I` | G8 Proxy & M&A | html | L0 | `(edgar-form-info "SC TO-I")` |
| `SC TO-T` | G8 Proxy & M&A | html | L0 | `(edgar-form-info "SC TO-T")` |
| `SC14D1F` | G8 Proxy & M&A | html | L0 | `(edgar-form-info "SC14D1F")` |
| `SC14D9C` | G8 Proxy & M&A | html | L0 | `(edgar-form-info "SC14D9C")` |
| `SCHEDULE 13D` | G3 Beneficial ownership 13D/13G | xml | L0 | `(edgar-form-info "SCHEDULE 13D")` |
| `SCHEDULE 13G` | G3 Beneficial ownership 13D/13G | xml | L0 | `(edgar-form-info "SCHEDULE 13G")` |
| `SD` | G9 Periodic & event narrative | html | L0 | `(edgar-form-info "SD")` |
| `SEC STAFF ACTIO` | G12 Broker-dealer, market structure, staff | text | L0 | `(edgar-form-info "SEC STAFF ACTIO")` |
| `SEC STAFF LETTE` | G12 Broker-dealer, market structure, staff | text | L0 | `(edgar-form-info "SEC STAFF LETTE")` |
| `SF-1` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "SF-1")` |
| `SF-3` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "SF-3")` |
| `SP 15D2` | G9 Periodic & event narrative | html | L0 | `(edgar-form-info "SP 15D2")` |
| `SUPPL` | G7 Prospectuses & registration | html | L0 | `(edgar-form-info "SUPPL")` |
| `TA-1` | G12 Broker-dealer, market structure, staff | xml | L0 | `(edgar-form-info "TA-1")` |
| `TA-2` | G12 Broker-dealer, market structure, staff | xml | L0 | `(edgar-form-info "TA-2")` |
| `TA-W` | G12 Broker-dealer, market structure, staff | xml | L0 | `(edgar-form-info "TA-W")` |
| `UPLOAD` | G12 Broker-dealer, market structure, staff | text | L0 | `(edgar-form-info "UPLOAD")` |
| `X-17A-5` | G12 Broker-dealer, market structure, staff | xml | L1 | `(edgar-text filing)` |
<!-- END GENERATED FORM COVERAGE -->

## Families (Q2 2026 volume; family rules are a first-pass grouping)

| Family | Filings | Share | Base forms | Backend | Biggest members |
|---|---:|---:|---:|---|---|
| G1 Ownership | 116,225 | 32.9% | 3 | XML | 4 (104,601), 3, 5 |
| G7 Prospectuses & registration | 66,922 | 18.9% | 58 | HTML | 424B2 (49,609), FWP, 424B3, EFFECT, 424B5, S-8 |
| G9 Periodic & event narrative | 38,507 | 10.9% | 34 | HTML | 8-K, 6-K, 10-Q, SD, 10-K, 11-K |
| G2 Notice of sale / Reg D | 36,377 | 10.3% | 2 | XML | 144 (19,526), D (16,851) |
| G10 Investment-company registration | 24,427 | 6.9% | 40 | HTML | 497K, 497, 485BPOS, 40-APP |
| G5 Fund periodic reports | 19,096 | 5.4% | 25 | XML | NPORT-P (14,407), N-MFP3, N-CSRS, N-CSR |
| G3 Beneficial ownership 13D/13G | 18,768 | 5.3% | 5 | XML | SCHEDULE 13G (16,008), 13D |
| G4 13F holdings | 11,633 | 3.3% | 2 | XML | 13F-HR, 13F-NT |
| G8 Proxy & M&A | 11,244 | 3.2% | 31 | HTML | DEFA14A, DEF 14A, ARS, 425 |
| G6 Asset-backed | 5,714 | 1.6% | 3 | XML | 10-D, ABS-EE, ABS-15G |
| G12 Broker-dealer, staff, market structure | 2,577 | 0.7% | 26 | mixed | CORRESP, X-17A-5, UPLOAD, MA-I |
| G11 Reg CF & Reg A | 1,757 | 0.5% | 14 | XML/HTML | C-AR, C, C-U, 1-A |
| G13 Tail | 46 | 0.0% | 2 | HTML | 305B2, POS 8C |

## Current implementation state

The per-form table above is generated from the registry and is authoritative
for the current declared level. Level labels are claims about implemented
support; fixture coverage is separately checked by `eask run script coverage`.
Do not infer that all forms are parsed from the fact that all 245 appear in the
catalog.

## Gaps that are not about a specific form

Implemented whole-library capabilities: raw-XML access, multi-document filings
(exhibits), quarterly/daily enumeration across all filers, and a cache plus rate
limiter.  Remaining gaps tracked as beads: history past the SEC's ~1000-filing
`recent` window, amendment handling, legacy text-only filings, inline-XBRL facts
(in xbrl.el), and testing each form on more than one filer.

Work is tracked in `.beads/` (`br ready`, `br list`).
