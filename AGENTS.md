# AGENTS.md — edgar.el

Standalone, publishable Emacs package for reading SEC EDGAR filings: list a
company's filings, open a 10-K/10-Q in a buffer, and extract its Items as
plain strings (`edgar-section`) so Lisp can use them. Numeric XBRL facts are
NOT here — they live in the sibling package `xbrl.el` (`edgar.el` requires
it). Rule of thumb: `xbrl.el` never knows what a filing page is, `edgar.el`
never knows what a us-gaap concept is. Planned: iXBRL tag extraction goes in
`xbrl.el`, filing/corpus navigation stays here.

## For agents

- Read `README.md` first.
- Source is `src/edgar.el`; tests are ERT in `test/edgar-test.el`. Offline:
  `emacs -Q --batch -L src -L ../xbrl.el/src -l test/edgar-test.el -f
  ert-run-tests-batch-and-exit`. Network tests are skipped unless
  `XBRL_LIVE=1`; set `xbrl-user-agent` to a real name + email first (SEC
  requires it; keep under 10 req/s).
- `checkdoc-file` and `batch-byte-compile` (with `byte-compile-error-on-warn`)
  must be silent before any change lands. package-lint's only expected
  complaint is "xbrl is not installable" until `xbrl.el` is on an archive.
- `edgar-sections` picks, per Item, the occurrence with the longest body
  because the table of contents repeats every heading with no body. Verified
  against Apple's FY2025 10-K; check a second filer before changing it.
- Zero references to the owner's dotfiles are allowed here -- the repo must
  remain publishable as-is. THIS repo is canonical; dotfiles imports it via
  load-path (`config/terminal/emacs/`) and carries no copy of the source.
- Authorized: david, swe.
