#!/usr/bin/env python3
"""Resolve exact primary HTML filenames from SEC submissions."""

import re
import time
import urllib.request


filings = [
    ("10-12B", "Kioni Holdings Ltd", "2011134", "0002011134-26-000009"),
    ("10-12B", "Mobility Global Inc.", "2090312", "0001104659-26-057155"),
    ("10-12G", "Feel The World, Inc.", "1690455", "0001079973-26-000657"),
    ("10-12G", "JLM-WNCO Trust", "2127486", "0001437749-26-011469"),
    ("20FR12B", "Wise Group plc", "2099039", "0001193125-26-151439"),
    ("20FR12B", "Vicore Pharma Holding AB", "2124403", "0001104659-26-065450"),
]


def tag(document, name):
    match = re.search(rf"<{name}>\s*([^\r\n<]+)", document, re.IGNORECASE)
    return match.group(1).strip() if match else None


for form, company, cik, accession in filings:
    compact_accession = accession.replace("-", "")
    url = (
        f"https://www.sec.gov/Archives/edgar/data/{cik}/"
        f"{compact_accession}/{accession}.txt"
    )
    request = urllib.request.Request(
        url, headers={"User-Agent": "David Awad david@awad.esq"}
    )
    with urllib.request.urlopen(request, timeout=60) as response:
        submission = response.read().decode("utf-8", errors="replace")
    documents = re.findall(
        r"<DOCUMENT>(.*?)</DOCUMENT>", submission, re.IGNORECASE | re.DOTALL
    )
    matches = [
        (tag(document, "TYPE"), tag(document, "FILENAME"))
        for document in documents
        if tag(document, "TYPE") == form
    ]
    print(form, company, accession, matches[:3], "submission-bytes", len(submission))
    time.sleep(0.25)
