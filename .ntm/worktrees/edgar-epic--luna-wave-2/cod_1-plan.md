# edgar-form-coverage-w00.21 — G9 continuation

## Goal
Complete the remaining G9 Reg A filing coverage in this worktree.

## Plan
- [ ] Check SEC index availability and record representative fixtures for 1-K, 1-SA, 1-U, and 1-Z.
- [ ] Align the four core G9 rows (10-K, 10-Q, 20-F, 8-K) with their existing fixture/golden coverage.
- [ ] Add reviewed section/body assertions and update coverage registry/docs.
- [ ] Run the required Eask checks and inspect all generated snapshots.
- [ ] Update the bead and commit code plus bead export.

## Progress log
- 2026-10-02 — Reconciled the clean integration HEAD and found these four G9 rows remain L0.

## Learnings / blockers
- Session archive lookup failed with lexical query fuel exhaustion; bead comments and current source are available.
