# edgar-form-coverage-w00.16: expand 13F coverage

## Goal
Reach three distinct real SEC 13F filers, add typed 13F-NT data, and preserve offline regression coverage for varied 13F-HR layouts.

## Plan
- [x] Audit existing 13F implementation, fixtures, bead evidence, and SEC candidates.
- [x] Claim the bead and record the scoped increment.
- [x] Record Water Island 13F-HR and Newfound Research 13F-NT XML fixtures.
- [x] Add typed 13F-NT projection and focused three-filer regression tests.
- [x] Promote 13F-NT coverage and regenerate global coverage docs.
- [x] Run formatting, focused ERT, offline coverage, and diff checks.
- [x] Sync bead evidence, review, and commit.
- [x] Exercise five-digit 13F table parsing and commit the final `.16` increment.
- [x] Add a third distinct genuine 13F-HR filer with typed and generic goldens.

## Progress log
- 2026-10-02 21:05 CDT — Audited HEAD `2e5383f`: Berkshire has two vintages but is the only covered filer; 13F-NT remains L0.
- 2026-10-02 21:10 CDT — Verified SEC sources for Water Island Capital HR (option, equity, and PRN rows) and Newfound Research NT (three other managers); claimed `.16` as CopperBay.
- 2026-10-02 21:15 CDT — Three-filer typed regressions and generic text snapshots pass; G4 is 2/2 L2 for all 11,633 Q2 filings. Large-table behavior remains open.
- 2026-10-02 21:44 CDT — Verified BlackRock accession `0001086364-24-008417`: 48,161 rows, 22,149,413 bytes, SHA-256 `33de71702ec059597b80621049ad38511d5806ad548fccf5d76cf5673425fa83`; adding a 10,001-row regression from its first filed row without another fixture slug.
- 2026-10-02 21:46 CDT — Five-digit scale regression passes in 1.03 seconds; complete offline ERT is 199 passed, one expected live-network skip, zero failures; coverage and diff gates pass.
- 2026-10-02 22:02 CDT — Added Scion Asset Management accession `0001649339-25-000007` as the third distinct 13F-HR filer; typed, expect, and text goldens pass. Complete offline ERT is 203 passed, one expected live-network skip; G4 remains 11,633/11,633 L2.

## Learnings / blockers
- BlackRock's 22.1 MB table establishes the real scale; the regression repeats its first filed row 10,001 times so the parser-size acceptance is deterministic without repository bloat or another auto-registered fixture slug.
- No `.16` acceptance gap remains after the Scion 13F-HR diversity fixture; keep the bead open for review.
