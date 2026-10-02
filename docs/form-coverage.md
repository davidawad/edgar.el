# Form coverage survey

Goal: `edgar.el` reads every base EDGAR form type. This is the measured size of
that goal. Data: SEC full-index `form.idx`, 2026 Q2 (`tools/form-survey.sh`),
353,293 filings.

The machine-readable source of truth is `src/edgar-forms.el`. Its 245 base
form rows were seeded from the index snapshot in `test/form-survey-2026-q2.txt`;
`test/edgar-forms-test.el` checks that snapshot and the family counts below.
Run `EDGAR_UA="Name email" tools/form-survey.sh` to refresh the snapshot and
registry when updating the measured quarter.

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
| L1 | `edgar-text` reads it, one recorded fixture, expect snapshot | every base form |
| L2 | Narrative forms: sections extracted + golden strings. XML forms: typed accessors + golden values | families below, by volume |

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

## Current state (L2 today)

L2: 10-K, 10-Q, 8-K, 20-F, S-1 (Part II), SCHEDULE 13G (HTML era) = 12.0% of filings.
L1 only: 40-F, 6-K, DEF 14A, 11-K, 4, 13F-HR, 144, SC 13G = 41.0% of filings (Forms 4
and 144 alone are 35%). Together 14 of 245 base forms and 53.0% of filings by volume.
Each has one latest and one oldest-in-window recorded filing, from a single filer.
Nothing here is XML-aware yet, so Forms 4/144/13F are readable but not queryable.

## Gaps that are not about a specific form

Implemented whole-library capabilities: raw-XML access, multi-document filings
(exhibits), quarterly/daily enumeration across all filers, and a cache plus rate
limiter.  Remaining gaps tracked as beads: history past the SEC's ~1000-filing
`recent` window, amendment handling, legacy text-only filings, inline-XBRL facts
(in xbrl.el), and testing each form on more than one filer.

Work is tracked in `.beads/` (`br ready`, `br list`).
