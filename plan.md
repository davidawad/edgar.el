# edgar-form-coverage-w00.15: complete Schedule 13D/13G coverage

## Goal
Add distinct real SEC 13D/13G filer and layout coverage with typed XML fields and generic/legacy section access.

## Plan
- [x] Audit existing G3 accessors, fixtures, goldens, and acceptance evidence.
- [x] Assign `.15` in the canonical bead database and reserve exact code paths.
- [x] Record the missing distinct SEC filer/layout fixture.
- [x] Add typed and section/generic golden regressions.
- [ ] Update coverage docs only where measured claims change.
- [ ] Run focused ERT, offline docs/coverage gates, and `git diff --check`.
- [ ] Record bead evidence, commit, and leave the bead open.

## Progress log
- 2026-10-02 22:15 CDT — Created isolated `ntm-g3-codex` worktree at integration commit `251fd70` and began the G3 audit.
- 2026-10-02 22:55 CDT — Recorded Viking Holdings legacy `SC 13D` accession `0001193125-24-268950`; Items 1–7 and Item 4 golden pass, ownership/schedule ERT is 16/16, and the distinct-CIK regression covers GameStop, TaskUs, and Viking.

## Learnings / blockers
- Existing integration has real XML GameStop Schedule 13G and TaskUs Schedule 13D/A plus legacy GameStop SC 13G/A; distinct-filer/layout acceptance still needs auditing.
- Canonical status transition is blocked by dependency `.10`; user-authorized work continues with `.15` assigned to CopperBay and left open.
- Another agent currently reserves four shared registry/docs/invariant paths; requested coordinated release before editing them.
