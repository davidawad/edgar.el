# G7 .19 tranche: generic coverage for five registration forms

## Goal
Add real SEC fixtures, expectations, goldens, generic API assertions, and L2 coverage metadata for only 10-12B, 10-12G, 20FR12B, 20FR12G, and 40FR12G; leave .19 open.

## Plan
- [x] Record primary documents and filing metadata for the five forms.
- [x] Add source-grounded expectations, generated goldens, and generic structure assertions.
- [x] Update only the five registry rows and regenerate the coverage docs.
- [x] Run focused ERT and offline coverage/docs gates, review scope, and commit.
- [x] Verify .19 remains open; report commit and checks.

## Progress log
- 2026-10-03 — Previous G10 work committed as `aa56229861360e3da094ac92ba94ea0d91b21b82`; `.6zr` remains open. Existing scratch artifacts retained.
- 2026-10-03 — Verified `.19` is open and the five target forms are listed among its remaining G7 L0 rows. SEC Q2 2026 `form.idx` identifies all five base filings; selected Middleby Food Processing, BioKey (Cayman), Clinuvel Pharmaceuticals, ChdgAI Commodities, and Nuran Wireless.
- 2026-10-03 — Added three distinct SEC filers per target form, yielding 15 fixtures, expectations, and goldens; generic document-structure assertions cover all 15.
- 2026-10-03 — Focused expectation/golden selector passed 31/31. Offline coverage gate passed; coverage/docs ERT passed 21/21. No parser source changes.
- 2026-10-03 — Committed as `d0f93ce682954a32cff3e0bad7c4b6e87ac71286`; verified `.19` remains OPEN.

## Learnings / blockers
- Keep the change disjoint from `.6zr` and all other G7 rows; do not add form-specific parser behavior.
- Fixture recording should preserve the SEC primary document bytes, accession, filer, source URL, size, and SHA-256.
