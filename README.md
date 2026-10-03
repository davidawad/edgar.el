# edgar.el

Read SEC EDGAR filings in Emacs. Depends on [xbrl.el](../xbrl.el) for facts.

PDF primaries are rendered through Poppler's `pdftotext` executable. PDF
payloads embedded in complete submissions also require `uudecode`.
Customize `edgar-pdftotext-program` and `edgar-uudecode-program` when the
executables use other names.

    (setq xbrl-user-agent "Your Name you@example.com") ; SEC requires this
    (edgar-filings "AAPL" "10-K")                       ; filing plists, newest first
    (edgar-filings "AAPL" "10-K" :since "2010-01-01")  ; bounded filing history
    (edgar-section (edgar-latest "AAPL" "10-K") "1A")   ; Risk Factors as a string
    (edgar-facts (edgar-latest "AAPL" "10-K"))          ; Inline XBRL facts + contexts
    (edgar-section (edgar-latest "GME" "10-Q") "II.1A") ; Part II Item 1A of a 10-Q
    M-x edgar-list    ; browse a ticker's filings, RET opens one
    M-x edgar-read    ; open the latest 10-K / 10-Q / 8-K
    (edgar-documents filing)                    ; list filing documents
    (edgar-exhibit filing "EX-99.1")            ; exhibit as plain text
    (edgar-index-filings 2026 2 "10-K")         ; every filer, including /A
    (edgar-daily-index-filings "2026-09-30" "4")
    (edgar-form4-transactions (edgar-latest "AAPL" "4"))

`edgar-index-filings` reads a quarterly SEC form index; the daily variant reads
one filing day's index.  Results are newest first and add `:company` to the
usual filing plist.  A base-form filter includes its `/A` amendments, while an
explicit `/A` filter selects amendments only.  Because form indexes identify
complete submissions rather than primary documents, their `:doc` and `:url`
point to the filing's `.txt` submission. `edgar-text` and `edgar-section`
extract the matching primary document from those SGML wrappers and preserve
section boundaries in legacy plain-text filings.

`edgar-ownership.el` provides typed plists for Forms 3, 4, and 5:
`edgar-ownership-issuer`, `edgar-ownership-reporting-owners`,
`edgar-ownership-transactions`, `edgar-ownership-holdings`,
`edgar-ownership-footnotes`, `edgar-ownership-10b5-1-p`, and
`edgar-ownership-signatures`. Form-specific helpers
`edgar-form3-holdings`, `edgar-form4-transactions`, and
`edgar-form5-holdings` return nil for unrelated form types. Share, price, and
date values remain strings so the source precision is preserved; transaction
rows include their kind, ownership codes, and resolved footnote text.

`edgar-schedules.el` provides `edgar-schedule-13d-g-cover-page` for structured
Schedule 13D/G XML and `edgar-schedule-13d-purpose-of-transaction` for 13D Item
4. Values retain their source strings. Legacy `SC 13D`/`SC 13G` filings remain
available through `edgar-schedule-13d-g-legacy-sections` and the generic
`edgar-section` API.

`edgar-offerings.el` provides `edgar-form-c` for typed Regulation Crowdfunding
offering statements, including issuer, offering, deadline, financial, and
signature fields. `edgar-form-c-ar` provides annual-report fields. Other Form C
variants remain available through `edgar-text` and the generic document-tree
API.

`edgar-13f.el` provides `edgar-13f-holdings` for normalized 13F-HR information
table rows and `edgar-13f-notice` for typed 13F-NT manager, other-manager, and
signature data. Reported holding values retain their source unit and include a
normalized dollar value across the January 2023 reporting-unit change.

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

Named sections also work through `(edgar-section filing "Risk Factors")`,
which resolves an Item title or a standalone uppercase heading. For direct
access to the document structure, use the generic tree API:

    (let* ((filing (edgar-latest "AAPL" "10-K"))
           (tree (edgar-document-structure filing)))
      (edgar-structure-headings tree) ; names, levels, paths, and section bodies
      (edgar-structure-section tree '("Part I" "Risk Factors"))
      (edgar-structure-paragraphs tree)
      (edgar-structure-nodes tree "ix:nonfraction"))

HTML, XML, PDF, and plain-text submissions use one tree representation. PDF
documents expose their extracted paragraphs; element
names, attributes, child order, and text nodes are kept; individual form codes
do not select custom fields. `edgar-structure-section` accepts a visible
heading name or a full heading/tag path. Duplicate names signal an ambiguity
error that a path resolves. `edgar-structure-nodes-at-path` addresses nested
element paths, `edgar-structure-nodes` returns elements with a given tag, and
`edgar-structure-paragraphs` returns `p` elements or plain-text paragraphs.
`edgar-primary-document` returns the SEC document's `:type`, `:sequence`,
`:filename`, `:description`, `:format`, and raw `:content`; the tree keeps the
metadata under `:primary-document`. For XSL-rendered XML URLs it reads the raw
XML source. `:format` is one of `xml`, `html`, `text`, `pdf`, or
`pdf-uuencoded`. PDF submissions are decoded generically with `uudecode`, then
their text and paragraphs are exposed through the same structure and section
APIs using `pdftotext`.

`edgar-structure-headings` discovers HTML `h1`-`h6`, titled `section`
elements, and recognizable standalone headings in PDF/text output.
`edgar-section` also resolves existing Item headings. The plain-text heading
fallback is heuristic; unmarked headings in tables or filing-specific markup
remain available through the generic tree API. No form codes select custom
fields or heading catalogs.

The same tree API has recorded G12 coverage for CORRESP and UPLOAD text,
plus X-17A-5, MA-I, TA-2, ATS-N and its amendments, CFPORTAL, MA, SBSE, and
TA-1/TA-W XML. These are generic structure fixtures, not form-specific typed
accessors.

Recorded G10 layouts include 40-APP applications, 485BPOS registrations,
497 supplements, 497J certification letters, 497K summary prospectuses, and
N-1A registrations. They use the generic text, paragraph, table, and named
section interfaces without form-specific projections.

Additional G10 fixtures cover raw 24F-2NT XML, 40-17G fidelity-bond notices,
485APOS amendments, 485BXT delaying amendments, 497VPI/497VPU variable-product
updates, and S-6 unit-investment-trust registrations through the same generic
tree, element, paragraph, table, and Item-section interfaces.

## Form coverage

`edgar-forms.el` catalogs the 245 base forms in the 2026 Q2 SEC index.
Cataloging a form does not imply its filing body is parsed: the level records
what this package currently supports for each form. See the generated
[per-form coverage table](docs/form-coverage.md#per-form-registry) for the
current registry state. `edgar-form-info` accepts amendment names such as
`"10-K/A"`; `edgar-forms-by-family` returns the rows for a family. The offline
coverage gate checks registry metadata and recorded fixture artifacts.

| Form | Sections | Notes |
|---|---|---|
| 10-K, 10-K/A | Part-qualified items | 10-K/A shows only the Items it amends |
| 10-Q | `I.1`-`I.4`, `II.1`-`II.6` | |
| 8-K | `2.02`, `9.01` ... | dotted items |
| 20-F | Part-qualified items | heading-only table-of-contents residue is dropped |
| S-1 | `II.13`-`II.17` | Part I is the prospectus, no Items |
| S-3 | `Risk Factors` and other standalone prospectus headings | `edgar-section` |
| Schedule 13G | `1`-`10` | legacy `SC 13G`/`SC 13G/A` text filings: little or no Item structure |
| 40-F, 6-K, 11-K, 4, 13F-HR, 144 | none | whole text via `edgar-text` |
| DEF 14A | named proposals, compensation, and ownership headings | `edgar-section` |
| DEFM14A | named merger headings | `edgar-section` |
| DEF 14C | generic paragraphs and document paths | `edgar-document-structure` |
| SC TO-I, SC TO-T | Schedule TO Items | `edgar-section` |
| SC 14D9 | Schedule 14D-9 Items | `edgar-section` |
| SC TO-C | available Schedule TO-C Items and generic document paths | `edgar-section`, `edgar-document-structure` |

## Tests

    eask run script check                 # lint + all tests + coverage + compile
    eask run script expect-update         # re-snapshot after an INTENDED change; review `git diff test/expect/`
    eask run script golden-update         # regenerate golden strings; review `git diff test/golden/`
    emacs -Q --batch -L ../xbrl.el/src -L src -l tools/record-fixtures.el   # record missing latest fixtures (network)
    emacs -Q --batch -L ../xbrl.el/src -L src -l tools/record-prior.el      # record the older twin of each (network)
