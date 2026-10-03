# Structured fixture sources

These are unmodified XML documents published in SEC EDGAR's Archives:

- `nport-p-eagle.xml` — [NPORT-P accession 0000850027-26-000015](https://www.sec.gov/Archives/edgar/data/850027/000085002726000015/primary_doc.xml).
- `n-mfp3-northwestern-mutual.xml` — [N-MFP3 accession 0000742212-26-000029](https://www.sec.gov/Archives/edgar/data/742212/000074221226000029/primary_doc.xml).
- `n-cen-alps.xml` — [N-CEN accession 0001049169-26-001803](https://www.sec.gov/Archives/edgar/data/915802/000104916926001803/primary_doc.xml).
- `abs-ee-bank5-sample.xml` — [EX-102 in ABS-EE accession 0001539497-26-002177](https://www.sec.gov/Archives/edgar/data/1547361/000153949726002177/exh_102.xml); its XML namespace identifies the CMBS schema.
- `structured/ncsr-sample.htm.gz` — compressed primary document from [N-CSR accession 0000030146-26-000114](https://www.sec.gov/Archives/edgar/data/737520/000003014626000114/output.htm), used to test the generic Item section API.

The corresponding manually checked accessor values live in `test/golden/`.
