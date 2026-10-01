# edgar.el

Read SEC EDGAR filings in Emacs. Depends on [xbrl.el](../xbrl.el) for facts.

    (setq xbrl-user-agent "Your Name you@example.com") ; SEC requires this
    (edgar-filings "AAPL" "10-K")                       ; filing plists, newest first
    (edgar-section (edgar-latest "AAPL" "10-K") "1A")   ; Risk Factors as a string
    (edgar-section (edgar-latest "GME" "10-Q") "II.1A") ; Part II Item 1A of a 10-Q
    M-x edgar-list    ; browse a ticker's filings, RET opens one
    M-x edgar-read    ; open the latest 10-K / 10-Q / 8-K

## Sections

`edgar-sections` splits a filing at its `Item` headings. Keys are the item
number (`1A`, `2.02`), prefixed with the Part when the filing has Parts, so a
10-Q's Part I Item 2 (MD&A) is `I.2` and Part II Item 2 (equity sales) is
`II.2`. `edgar-section` also accepts a bare number when it is unambiguous
(`"7"` for a 10-K's MD&A) and signals an error listing the candidates when it
is not (`"1"` in a 10-Q).

## Form coverage

Expect tests replay a recorded real filing of each type offline
(`test/fixtures/`, snapshots in `test/expect/`):

| Form | Sections | Notes |
|---|---|---|
| 10-K, 10-K/A | Part-qualified items | 10-K/A shows only the Items it amends |
| 10-Q | `I.1`-`I.4`, `II.1`-`II.6` | |
| 8-K | `2.02`, `9.01` ... | dotted items |
| 20-F | Part-qualified items | table-of-contents residue keys possible (known rough edge) |
| S-1 | `II.13`-`II.17` | Part I is the prospectus, no Items |
| Schedule 13G | `1`-`10` | |
| 40-F, 6-K, DEF 14A, 11-K, 4, 13F-HR, 144 | none | whole text via `edgar-text` |

## Tests

    eask run script check                 # lint + all tests + coverage + compile
    eask run script expect-update         # re-snapshot after an INTENDED change; review `git diff test/expect/`
    emacs -Q --batch -L ../xbrl.el/src -L src -l tools/record-fixtures.el   # record missing fixtures (network)
