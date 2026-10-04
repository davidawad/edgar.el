# Fixture notes

All fixtures are real SEC bytes, public documents; nothing is hand-edited.

- `<slug>.htm.gz` / `<slug>.eld`: a filing's primary document and its filing
  plist, as recorded by `tools/record-fixtures.el` / `tools/record-prior.el`.
- `10-k-ablp.*` (AllianceBernstein L.P., CIK 1109448, FY2025 10-K) is the one
  trimmed fixture, **test-only**: the full document is 4.7 MB, over the 1.8 MB
  recording cap, and no AB 10-K in the SEC's recent window is smaller. It is
  the first 1,799,792 bytes of the document, cut after a closing `</div>`
  inside Item 7, so Items 7A onward have only their table-of-contents entries.
  Everything in it is verbatim.
- `xbrl-ablp-<Concept>.json`: complete, unmodified SEC companyconcept responses
  (`data.sec.gov/api/xbrl/companyconcept/CIK0001109448/us-gaap/<Concept>.json`,
  fetched 2026-10-03), served by the stubbed transport in
  `test/edgar-showcase-test.el`.
