# G9 periodic/event coverage batch

## Goal
Add real SEC fixture, expectation, golden, and generic structure coverage for the highest-volume uncovered G9 forms in this worktree.

## Plan
- [ ] Rank uncovered G9 registry rows, excluding forms already handled in prior G9 commits.
- [ ] Verify candidate SEC filings and supported source documents.
- [ ] Add a tightly scoped fixture/test batch with generic APIs only.
- [ ] Run focused ERT, offline docs/coverage gates, and diff check.
- [ ] Commit the scoped changes and record evidence.

## Progress log
- 2026-10-03 — Started in `luna-g9periodic-21-fresh`; initial tree is clean at 0527d40.

## Learnings / blockers
- Do not modify bead storage or any other worktree.
