# edgar.el task runner.  `test-gate` is the gate the land queue runs.
# xbrl.el is a private sibling checkout; point XBRL_DIR at it elsewhere.

xbrl := env("XBRL_DIR", home_dir() / "code/Personal/emacs/xbrl.el")

# Offline ERT suite (the one network test needs XBRL_LIVE=1).
test-gate:
    #!/usr/bin/env bash
    set -euo pipefail
    args=()
    for f in test/*-test.el; do args+=(-l "$f"); done
    emacs -Q --batch -L . -L test -L tools -L "{{xbrl}}" "${args[@]}" -f ert-run-tests-batch-and-exit
