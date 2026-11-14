#!/usr/bin/env python3
"""Inspect official SEC directory JSON for the selected G7 sample filings."""

import json
import time
import urllib.request


filings = [
    ("10-12B", "Kioni Holdings Ltd", "2011134", "000201113426000009", "kioni260505-1012b.htm"),
    ("10-12B", "Mobility Global Inc.", "2090312", "000110465926057155", "tm2528763-7_1012b.htm"),
    ("10-12G", "Feel The World, Inc.", "1690455", "000107997326000657", "ftw_1012g.htm"),
    ("10-12G", "JLM-WNCO Trust", "2127486", "000143774926011469", "jlmw20260406_1012g.htm"),
    ("20FR12B", "Wise Group plc", "2099039", "000119312526151439", "d19735d20fr12b.htm"),
    ("20FR12B", "Vicore Pharma Holding AB", "2124403", "000110465926065450", "tm269615-6_20fr12b.htm"),
    ("20FR12G", "Greenbriar Capital Corp.", "1570843", "000106299322001742", "form20fr12g.htm"),
    ("20FR12G", "NEC Corporation", "72127", "000119312520075601", "d856504d20fr12g.htm"),
    ("40FR12G", "U.S. filer 2020", "1834045", "000110465920130020", "tm2037002d1_40fr12g.htm"),
    ("40FR12G", "U.S. filer 2021", "1832928", "000119312521008131", "d945319d40fr12g.htm"),
]


for form, company, cik, accession, primary_name in filings:
    url = f"https://www.sec.gov/Archives/edgar/data/{cik}/{accession}/index.json"
    request = urllib.request.Request(
        url, headers={"User-Agent": "David Awad david@awad.esq"}
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        payload = json.load(response)
    items = payload["directory"]["item"]
    matches = [item for item in items if item.get("name") == primary_name]
    print(form, company, accession, matches)
    time.sleep(0.25)
