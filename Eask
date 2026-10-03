;; -*- mode: eask; lexical-binding: t -*-
;; Package manifest + dev tooling for edgar.el.  The development block is the
;; swe-project-plugin-pack-elisp tool cohort (formatter, linters, coverage,
;; property/e2e testing, complexity metrics).  Git-source deps are not on
;; MELPA and are pinned to a commit SHA (the pack's tools.json says so).

(package "edgar"
         "0.1.0"
         "Read SEC EDGAR filings")

(website-url "https://github.com/davidawad/edgar.el")
(keywords "finance" "tools" "hypermedia")

(package-file "src/edgar.el")
(files "src/*.el")

(script "test"
        "eask test ert test/edgar-test.el test/edgar-expect-test.el test/edgar-golden-test.el test/edgar-l2-diversity-test.el test/edgar-forms-test.el test/form-coverage-test.el test/edgar-xml-test.el test/edgar-ownership-test.el test/edgar-offerings-test.el test/edgar-funds-test.el test/edgar-asset-backed-test.el test/edgar-docs-test.el test/edgar-http-test.el test/edgar-index-test.el test/record-fixtures-test.el")
(script "record-fixtures"
        "eask emacs --batch -L tools -l tools/record-fixtures.el -f edgar-record-fixtures-run")
(script "coverage"
        "eask emacs --batch -l tools/form-coverage-check.el")
(script "coverage-network"
        "eask emacs --batch -l tools/form-coverage-network.el")
(script "docs"
        "eask emacs --batch -l tools/edgar-form-docs-update.el")
(script "check"
        "eask lint package && eask lint checkdoc && eask lint regexps && eask run script coverage && UNDERCOVER_FORCE=true eask test ert test/edgar-test.el test/edgar-expect-test.el test/edgar-golden-test.el test/edgar-l2-diversity-test.el test/edgar-forms-test.el test/form-coverage-test.el test/edgar-xml-test.el test/edgar-ownership-test.el test/edgar-offerings-test.el test/edgar-funds-test.el test/edgar-asset-backed-test.el test/edgar-docs-test.el test/edgar-http-test.el test/edgar-index-test.el test/record-fixtures-test.el && eask compile src/edgar.el src/edgar-forms.el src/edgar-xml.el src/edgar-ownership.el src/edgar-offerings.el src/edgar-funds.el src/edgar-asset-backed.el src/edgar-docs.el src/edgar-http.el src/edgar-index.el src/edgar-13f.el")
(script "expect-update"
        "EDGAR_EXPECT_UPDATE=1 eask test ert test/edgar-expect-test.el")
(script "golden-update" "eask emacs --script tools/make-golden.el")

(source 'gnu)
(source 'melpa)

(depends-on "emacs" "29.1")
;; Sibling package (private repo, not on any archive yet).
(depends-on "xbrl"
            :url "https://github.com/davidawad/xbrl.el"
            :fetcher 'git
            :files '("src/*.el"))

(development
 (depends-on "package-lint")
 (depends-on "relint")
 (depends-on "elisp-autofmt")
 (depends-on "undercover")
 (depends-on "ecukes")
 (depends-on "dash")
 (depends-on "propcheck"
             :url "https://github.com/Wilfred/propcheck"
             :fetcher 'git
             :commit "21075792c03a186bc89029871c6db119e6e13cf0")
 (depends-on "codemetrics"
             :url "https://github.com/emacs-vs/codemetrics"
             :fetcher 'git
             :commit "863a9ac167ecdf20f3730fd9d308d44314fce903")
 (depends-on "cognitive-complexity"
             :url "https://github.com/emacs-vs/cognitive-complexity"
             :fetcher 'git
             :commit "b45afe9bf65943f985b645cea514212dc734349b"))
