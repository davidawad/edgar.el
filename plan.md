# edgar-form-coverage-w00.22: advance G10 coverage

## Goal
Add real SEC-backed L1 fixture and reviewed expectation coverage for additional G10 HTML layouts through the generic document structure API.

## Plan
- [x] Inspect branch, tracker, current G10 registry, and available fixtures.
- [x] Claim/comment the bead without closing partial acceptance.
- [x] Select and record distinct high-volume G10 SEC filings with provenance.
- [x] Add expectations/tests and promote only evidenced forms to L1.
- [x] Regenerate coverage docs and inspect snapshot diffs.
- [x] Format, run focused ERT, offline coverage, full checks, and diff check.
- [x] Review, sync exact bead evidence, and commit.

## Progress log
- 2026-10-03 01:59 CDT — Branch `ntm-g12-codex` is at `060ba62`, directly ahead of integration `4a7dbc1`; only the untracked plan existed. Current G10 coverage is 2/40 forms and 6,605/24,427 Q2 filings.
- 2026-10-03 01:59 CDT — Claimed w00.22 with explicit tracker override because its G7 dependency is stale for this user-directed independent increment; corrected the initial volume typo in a follow-up comment.
- 2026-10-03 02:11 CDT — Added reviewed 40-APP, 485BPOS, 497, and 497J fixtures/snapshots plus generic structure tests; focused ERT and offline coverage pass. G10 is 6/40 forms and 17,231/24,427 filings at L1.
- 2026-10-03 02:17 CDT — Full `eask run script check` passes 194 tests (193 expected, one intentional live skip), coverage, lint, and compilation; review router assigned Tier 0, so deterministic gates are sufficient.
- 2026-10-03 02:22 CDT — Committed the validated increment as `c085964`; posted the commit and remaining-acceptance evidence to w00.22 without closing it.

## Learnings / blockers
- Existing G10 fixtures cover only 497K and N-1A.
- Full acceptance requires all 40 forms at L1, so this increment must leave the bead open.
- Root integration changed the generic heading recognizer to exclude colon-terminated labels and salutations. The 497J fixture has no recognized heading and belongs on the paragraph-inspection path; 485BPOS and 497 retain named-section assertions.

## Integration regression fix
- [x] Reproduce the failure against the integrated parser.
- [x] Identify the 497J salutation as a no-heading layout.
- [x] Run focused ERT against the slice and integrated parser.
- [x] Run coverage/docs/diff gates, record evidence, and commit.

- 2026-10-03 02:38 CDT — Corrected the 497J expectation to the no-heading paragraph path. Slice ERT passed 35/35 offline tests plus one live skip; the same focused test passed against integrated `src/edgar.el`; coverage/docs/diff gates passed. Filed and completed child regression bead w00.22.1.
- 2026-10-03 02:41 CDT — Committed the correction as `8c97b97`; w00.22 remains open and in progress.

## Second G10 fixture batch (w00.22.2)
- [x] Confirm branch, current G10 L0 set, tracker state, and recorder tooling.
- [x] Record and verify 5–8 disjoint real SEC fixtures.
- [x] Add generic structure expectations, snapshots, and per-filing goldens.
- [x] Promote only evidenced forms and regenerate coverage docs.
- [x] Run focused ERT, coverage/docs/diff gates, review, and commit.

- 2026-10-03 02:52 CDT — Opened child w00.22.2 for a seven-form high-volume L0 batch targeting 497VPU, 485BXT, 497VPI, 24F-2NT, 485APOS, 40-17G, and S-6.
- 2026-10-02 22:09 CDT — Added checksum-verified SEC fixtures, reviewed structure/coarse expectations, and six HTML goldens. Focused ERT, 51 golden tests, offline coverage/docs, diff check, and the full 207-test gate pass. G10 is 13/40 forms and 23,346/24,427 filings at L1; deterministic review routed Tier 0.

## Remaining G10 forms (w00.22.3–w00.22.6)
- [x] Batch .3: record, test, document, and commit 487/497AD/497VPSUB/486APOS/486BPOS/486BXT/DEL AM.
- [x] Batch .4: record, test, document, and commit 40-17F1/40-17F2/40-24B2/40-33/40-6B/40-8F-2/MSD.
- [x] Batch .5: record, test, document, and commit APP NTC/APP ORDR/APP WD/APP WDG/CT ORDER.
- [x] Batch .6: record, test, document, and commit N-14/N-14 8C/N-2/N-2 POSASR/N-2ASR/N-2MEF/N-4/N-6.
- [x] Post exact final coverage evidence while leaving parent w00.22 open.

- 2026-10-02 22:43 CDT — Confirmed clean committed lane at 295e725 and opened four child batches for the 27 remaining G10 forms.
- 2026-10-02 22:52 CDT — Batch .3 added seven checksum-verified SEC HTML fixtures, snapshots, generic structure assertions, and goldens. Focused ERT 95 expected/1 live skip, golden ERT 58/58, coverage/docs/diff gates pass; G10 is 20/40 and 23,797/24,427 at L1.
- 2026-10-02 23:09 CDT — Batch .4 added seven checksum-verified SEC HTML/text fixtures, six rendered snapshots and goldens, and generic structure assertions including plain-text loading. Focused ERT passed 182 expected/1 live skip; coverage/docs/diff gates pass. G10 is 27/40 and 24,003/24,427 at L1; deterministic review routed Tier 0.
- 2026-10-02 23:19 CDT — Batch .5 added five checksum-verified application/order fixtures. Four SEC filings are PDF-only and exercise their exact complete-submission text; APP WD has a reviewed HTML snapshot and golden. Focused ERT passed 185 expected/1 live skip; coverage/docs/diff gates pass. G10 is 32/40 and 24,202/24,427 at L1; deterministic review routed Tier 0.
- 2026-10-02 23:34 CDT — Batch .6 added eight checksum-verified SEC HTML fixtures, reviewed snapshots/goldens, and generic structure assertions for the remaining registration forms. Focused ERT passed 202 expected/1 live skip; coverage/docs/diff gates pass. G10 is 40/40 and 24,427/24,427 at L1; deterministic review routed Tier 0.
- 2026-10-02 23:37 CDT — Committed batch .6 as 24f371f. Full package gate passed 254 expected tests/1 live skip, lint, coverage, and byte compilation. Parent w00.22 remains open for L2 acceptance only.
