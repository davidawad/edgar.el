# edgar-form-coverage-w00.17: G5 fund periodic coverage

## Goal
Broaden real SEC-backed G5 L1 coverage without disturbing integrated typed fund-report support.

## Plan
- [ ] Select 5-8 disjoint currently-L0 G5 forms from the Q2 snapshot.
- [ ] Record authoritative SEC primary documents and source metadata.
- [ ] Add generic HTML/XML L1 assertions, HTML goldens, registry levels, and generated docs.
- [ ] Run focused ERT, offline coverage gate, and `git diff --check`.
- [ ] Commit the scoped increment, record evidence, and leave the bead open.

## Progress log
- 2026-10-02 — Claimed `.17` on `ntm-g6-codex` at `0ac79f1`; starting from integrated N-CSR/N-CEN/N-MFP3/NPORT work.
- 2026-10-02 — Added verified Q2 SEC fixtures for N-CSRS, N-VP, N-VPFS, and N-PX; focused integration ERT 125/125 and full check 195 passed/1 live skipped.
- 2026-10-02 — Reopened `.17` at `672710e` for a second disjoint 5-8-form G5 L1 batch; bead must remain open.

## Learnings / blockers
- Seventeen low-volume G5 forms remain L0 (354 filings) before this batch.
