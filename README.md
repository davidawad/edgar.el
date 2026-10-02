# edgar.el

Read SEC EDGAR filings in Emacs. Depends on [xbrl.el](../xbrl.el) for facts.

    (setq xbrl-user-agent "Your Name you@example.com") ; SEC requires this
    (edgar-filings "AAPL" "10-K")                       ; filing plists, newest first
    (edgar-filings "AAPL" "10-K" :since "2010-01-01")  ; bounded filing history
    (edgar-section (edgar-latest "AAPL" "10-K") "1A")   ; Risk Factors as a string
    (edgar-section (edgar-latest "GME" "10-Q") "II.1A") ; Part II Item 1A of a 10-Q
    M-x edgar-list    ; browse a ticker's filings, RET opens one
    M-x edgar-read    ; open the latest 10-K / 10-Q / 8-K
    (edgar-documents filing)                    ; list filing documents
    (edgar-exhibit filing "EX-99.1")            ; exhibit as plain text
    (edgar-index-filings 2026 2 "10-K")         ; every filer, including /A
    (edgar-daily-index-filings "2026-09-30" "4")

`edgar-index-filings` reads a quarterly SEC form index; the daily variant reads
one filing day's index.  Results are newest first and add `:company` to the
usual filing plist.  A base-form filter includes its `/A` amendments, while an
explicit `/A` filter selects amendments only.  Because form indexes identify
complete submissions rather than primary documents, their `:doc` and `:url`
point to the filing's `.txt` submission.

With no date bounds, `edgar-filings` returns only the SEC's recent filings.
Supplying an inclusive `:since` or `:until` bound lazily merges only history
pages whose date range overlaps the request.

## Sections

`edgar-sections` splits a filing at its `Item` headings. Keys are the item
number (`1A`, `2.02`), prefixed with the Part when the filing has Parts, so a
10-Q's Part I Item 2 (MD&A) is `I.2` and Part II Item 2 (equity sales) is
`II.2`. `edgar-section` also accepts a bare number when it is unambiguous
(`"7"` for a 10-K's MD&A) and signals an error listing the candidates when it
is not (`"1"` in a 10-Q).

## Form coverage

`edgar-forms.el` is the single-source registry for all 245 base forms in the
2026 Q2 SEC index. Every row is L0 and records its family, backend, empty
section/field metadata, Q2 volume, and notes. `edgar-form-info` accepts
amendment names such as `"10-K/A"`; `edgar-forms-by-family` returns the rows
for a family. The registry tests validate the offline index snapshot.

EDGAR has hundreds of form types; these are the main periodic, current,
ownership and offering ones, not all of them. Each is tested against a
recorded real filing of the latest vintage AND the oldest one in the SEC's
`recent` window (layouts drift, e.g. 2013 10-Qs), offline, three ways:
structure snapshots (`test/expect/`), verbatim golden strings pinned to
specific sections (`test/golden/`, which must appear in that section and in no
other, and every parsed section must have some), and hand-checked facts
(`test/golden-facts.eld`).

| Form | Sections | Notes |
|---|---|---|
| 10-K, 10-K/A | Part-qualified items | 10-K/A shows only the Items it amends |
| 10-Q | `I.1`-`I.4`, `II.1`-`II.6` | |
| 8-K | `2.02`, `9.01` ... | dotted items |
| 20-F | Part-qualified items | heading-only table-of-contents residue is dropped |
| S-1 | `II.13`-`II.17` | Part I is the prospectus, no Items |
| Schedule 13G | `1`-`10` | legacy `SC 13G`/`SC 13G/A` text filings: little or no Item structure |
| 40-F, 6-K, DEF 14A, 11-K, 4, 13F-HR, 144 | none | whole text via `edgar-text` |

## Tests

    eask run script check                 # lint + all tests + coverage + compile
    eask run script expect-update         # re-snapshot after an INTENDED change; review `git diff test/expect/`
    eask run script golden-update         # regenerate golden strings; review `git diff test/golden/`
    emacs -Q --batch -L ../xbrl.el/src -L src -l tools/record-fixtures.el   # record missing latest fixtures (network)
    emacs -Q --batch -L ../xbrl.el/src -L src -l tools/record-prior.el      # record the older twin of each (network)
