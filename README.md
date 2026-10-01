# edgar.el

Read SEC EDGAR filings in Emacs. Depends on [xbrl.el](../xbrl.el) for facts.

    (setq xbrl-user-agent "Your Name you@example.com") ; SEC requires this
    (edgar-filings "AAPL" "10-K")                       ; filing plists, newest first
    (edgar-section (edgar-latest "AAPL" "10-K") "1A")   ; Risk Factors as a string
    M-x edgar-list    ; browse a ticker's filings, RET opens one
    M-x edgar-read    ; open the latest 10-K / 10-Q / 8-K

Tests: `XBRL_LIVE=1 emacs -Q --batch -L src -L ../xbrl.el/src -l test/edgar-test.el -f ert-run-tests-batch-and-exit`
