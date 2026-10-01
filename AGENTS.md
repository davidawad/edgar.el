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
- Tooling is the `swe-project-plugin-pack-elisp` cohort, declared in `Eask`
  (install once: `eask install-deps --dev`; needs `eask-cli` from brew).
  One command runs every gate: `eask run script check` (package-lint,
  checkdoc, relint, ERT with undercover coverage, byte-compile). Format with
  `eask format elisp-autofmt src/edgar.el test/edgar-test.el` BEFORE
  committing. Also installed, run by hand: propcheck (property tests),
  ecukes (e2e), codemetrics + cognitive-complexity (warn-only metrics).
- Source is `src/edgar.el`; tests are ERT in `test/edgar-test.el`. Almost all
  tests are hermetic (SEC transport stubbed, a fake filing in HTML); the one
  network test needs `XBRL_LIVE=1`. Set `xbrl-user-agent` to a real name +
  email first (SEC requires it; stay under 10 req/s). Coverage is ~79%.
- `edgar-sections` picks, per Item, the occurrence with the longest body
  because the table of contents repeats every heading with no body. Verified
  against Apple's FY2025 and Microsoft's FY2026 10-Ks; check a third filer
  before changing it.
- Git-source cohort deps in `Eask` are pinned to commit SHAs; `xbrl` comes
  from the private repo github.com/davidawad/xbrl.el.
- Zero references to the owner's dotfiles are allowed here -- the repo must
  remain publishable as-is. THIS repo is canonical; dotfiles imports it via
  load-path (`config/terminal/emacs/`) and carries no copy of the source.
- Authorized: david, swe.
