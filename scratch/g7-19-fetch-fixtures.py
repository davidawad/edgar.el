#!/usr/bin/env python3
"""Record the assigned G7 primary documents from SEC Archives."""

import gzip
import hashlib
import time
import urllib.request
from pathlib import Path


root = Path(__file__).resolve().parents[1]
fixtures = root / "test" / "fixtures"
rows = [
    (
        "10-12b-middleby",
        "10-12B",
        "Middleby Food Processing, Inc.",
        "2088281",
        "0001193125-26-202395",
        "2026-05-04",
        "d14360d1012b.htm",
    ),
    (
        "10-12b-kioni",
        "10-12B",
        "Kioni Holdings Ltd",
        "2011134",
        "0002011134-26-000009",
        "2026-05-05",
        "kioni260505-1012b.htm",
    ),
    (
        "10-12b-mobility",
        "10-12B",
        "Mobility Global Inc.",
        "2090312",
        "0001104659-26-057155",
        "2026-05-07",
        "tm2528763-7_1012b.htm",
    ),
    (
        "10-12g-biokey",
        "10-12G",
        "BioKey (Cayman), Inc.",
        "2108359",
        "0001213900-26-061646",
        "2026-05-28",
        "ea0291546-1012g_biokey.htm",
    ),
    (
        "10-12g-feel-the-world",
        "10-12G",
        "Feel The World, Inc.",
        "1690455",
        "0001079973-26-000657",
        "2026-05-14",
        "ftw_1012g.htm",
    ),
    (
        "10-12g-jlm-wnco",
        "10-12G",
        "JLM-WNCO Trust",
        "2127486",
        "0001437749-26-011469",
        "2026-04-07",
        "jlmw20260406_1012g.htm",
    ),
    (
        "20fr12b-clinuvel",
        "20FR12B",
        "Clinuvel Pharmaceuticals Ltd",
        "1290877",
        "0001493152-26-028643",
        "2026-06-15",
        "form20fr12b.htm",
    ),
    (
        "20fr12b-wise",
        "20FR12B",
        "Wise Group plc",
        "2099039",
        "0001193125-26-151439",
        "2026-04-10",
        "d19735d20fr12b.htm",
    ),
    (
        "20fr12b-vicore",
        "20FR12B",
        "Vicore Pharma Holding AB",
        "2124403",
        "0001104659-26-065450",
        "2026-05-22",
        "tm269615-6_20fr12b.htm",
    ),
    (
        "20fr12g-chdgai",
        "20FR12G",
        "ChdgAI Commodities Ltd",
        "2130998",
        "0001493152-26-019982",
        "2026-04-30",
        "form20-fr12g.htm",
    ),
    (
        "20fr12g-greenbriar",
        "20FR12G",
        "Greenbriar Capital Corp.",
        "1570843",
        "0001062993-22-001742",
        "2022-01-28",
        "form20fr12g.htm",
    ),
    (
        "20fr12g-nec",
        "20FR12G",
        "NIPPON DENKI KABUSHIKI KAISHA",
        "72127",
        "0001193125-20-075601",
        "2020-03-17",
        "d856504d20fr12g.htm",
    ),
    (
        "40fr12g-nuran",
        "40FR12G",
        "Nuran Wireless Inc.",
        "1680637",
        "0001753926-26-001026",
        "2026-06-18",
        "g085768_40f.htm",
    ),
    (
        "40fr12g-bespoke",
        "40FR12G",
        "Bespoke Capital Acquisition Corp",
        "1834045",
        "0001104659-20-130020",
        "2020-11-27",
        "tm2037002d1_40fr12g.htm",
    ),
    (
        "40fr12g-cresco",
        "40FR12G",
        "Cresco Labs Inc.",
        "1832928",
        "0001193125-21-008131",
        "2021-01-13",
        "d945319d40fr12g.htm",
    ),
]


for slug, form, company, cik, accession, filed, document in rows:
    accession_path = accession.replace("-", "")
    url = (
        f"https://www.sec.gov/Archives/edgar/data/{cik}/"
        f"{accession_path}/{document}"
    )
    request = urllib.request.Request(
        url, headers={"User-Agent": "David Awad david@awad.esq"}
    )
    with urllib.request.urlopen(request, timeout=60) as response:
        content = response.read()
    digest = hashlib.sha256(content).hexdigest()
    compressed = gzip.compress(content, compresslevel=9, mtime=0)
    metadata = (
        f'(:accn "{accession}" :form "{form}" :company "{company}" '
        f':filed "{filed}" :report "" :doc "{document}" :cik {cik} '
        f':url "{url}" :size {len(content)} :sha256 "{digest}")\n'
    )
    (fixtures / f"{slug}.htm.gz").write_bytes(compressed)
    (fixtures / f"{slug}.eld").write_text(metadata, encoding="utf-8")
    print(
        f"{form} {company}: {len(content)} source bytes, "
        f"{len(compressed)} gzip bytes, sha256 {digest}, {url}"
    )
    time.sleep(0.25)
