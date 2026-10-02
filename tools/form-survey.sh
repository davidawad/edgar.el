#!/usr/bin/env bash
# Count EDGAR filings by form type for one quarter, from SEC's form index.
#   tools/form-survey.sh [YEAR QTR]      default 2026 QTR2
# Prints "<count> <form>" sorted by count.  Amendments (/A) are separate rows;
# fold them yourself.  SEC asks for a descriptive User-Agent: set EDGAR_UA.
set -euo pipefail
year="${1:-2026}"
qtr="${2:-QTR2}"
ua="${EDGAR_UA:-edgar.el form-survey (set EDGAR_UA to name + email)}"
curl -fsS -A "$ua" "https://www.sec.gov/Archives/edgar/full-index/${year}/${qtr}/form.gz" |
  gunzip |
  awk 'NR>10 {print substr($0,1,17)}' | sed 's/ *$//' | sort | uniq -c | sort -rn
