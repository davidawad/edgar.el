# Structured fixture sources

These are unmodified documents published in SEC EDGAR's Archives:

- `schedule-13g-gme-xml.xml` — [Schedule 13G accession 0002063571-25-000002](https://www.sec.gov/Archives/edgar/data/1326380/000206357125000002/primary_doc.xml) (GameStop; 2025-04-02).
- `schedule-13d-taskus-a.xml` — [Schedule 13D/A accession 0001635999-25-000007](https://www.sec.gov/Archives/edgar/data/1829864/000163599925000007/primary_doc.xml) (TaskUs; 2025-08-26).
- `nport-p-eagle.xml` — [NPORT-P accession 0000850027-26-000015](https://www.sec.gov/Archives/edgar/data/850027/000085002726000015/primary_doc.xml).
- `n-mfp3-northwestern-mutual.xml` — [N-MFP3 accession 0000742212-26-000029](https://www.sec.gov/Archives/edgar/data/742212/000074221226000029/primary_doc.xml).
- `n-cen-alps.xml` — [N-CEN accession 0001049169-26-001803](https://www.sec.gov/Archives/edgar/data/915802/000104916926001803/primary_doc.xml).
- `n-px-a4-wealth.xml` — [N-PX accession 0002033987-26-000005](https://www.sec.gov/Archives/edgar/data/2033987/000203398726000005/primary_doc.xml).
- `abs-ee-bank5-sample.xml` — [EX-102 in ABS-EE accession 0001539497-26-002177](https://www.sec.gov/Archives/edgar/data/1547361/000153949726002177/exh_102.xml); its XML namespace identifies the CMBS schema.
- `n-csrs-360-funds.htm.gz` — compressed primary N-CSRS from [accession 0001999371-26-012055](https://www.sec.gov/Archives/edgar/data/1319067/000199937126012055/mcgxx-ncsrs_060426.htm).
- `n-vp-american-separate-2.htm.gz` — compressed primary N-VP from [accession 0001193125-26-163027](https://www.sec.gov/Archives/edgar/data/909758/000119312526163027/d123038dnvp.htm).
- `n-vpfs-alger.htm.gz` — compressed primary N-VPFS from [accession 0000847554-26-000007](https://www.sec.gov/Archives/edgar/data/847554/000084755426000007/algerseparateaccountaafs.htm).
- `10-d-ms-c21.htm.gz` — compressed primary 10-D from [accession 0001888524-26-012144](https://www.sec.gov/Archives/edgar/data/1631406/000188852426012144/msc15c21_10d-202606.htm).
- `abs-15g-tesla-energy.htm.gz` — compressed primary ABS-15G from [accession 0001193125-26-219735](https://www.sec.gov/Archives/edgar/data/2037778/000119312526219735/d108502dabs15g.htm).
- `structured/ncsr-sample.htm.gz` — compressed primary document from [N-CSR accession 0000030146-26-000114](https://www.sec.gov/Archives/edgar/data/737520/000003014626000114/output.htm), used to test the generic Item section API.
- `ma-i-ey-2026.xml` — [MA-I accession 0001617793-26-000005](https://www.sec.gov/Archives/edgar/data/1617793/000161779326000005/primary_doc.xml).
- `ta-2-edward-jones-2026.xml` — [TA-2 accession 0000810417-26-000002](https://www.sec.gov/Archives/edgar/data/810417/000081041726000002/primary_doc.xml).
- `upload-irenic-2026.txt` — [UPLOAD accession 0000000000-26-003277](https://www.sec.gov/Archives/edgar/data/2122505/000000000026003277/filename2.txt), the SEC-provided text extract of the staff letter.
- `40-app-m3sixty.htm.gz` — compressed [40-APP accession 0001999371-26-010840](https://www.sec.gov/Archives/edgar/data/1319067/000199937126010840/m3sixty-40app_051526.htm).
- `485bpos-geme.htm.gz` — compressed [485BPOS accession 0001999371-26-009141](https://www.sec.gov/Archives/edgar/data/1969674/000199937126009141/geme-485bpos_042726.htm).
- `497-1290.htm.gz` — compressed [497 accession 0001193125-26-147484](https://www.sec.gov/Archives/edgar/data/1605941/000119312526147484/d64604d497.htm).
- `497j-360.htm.gz` — compressed [497J accession 0001999371-26-007585](https://www.sec.gov/Archives/edgar/data/1319067/000199937126007585/income-497j_040226.htm).

The corresponding reviewed golden values and strings live in `test/golden/`.
Reviewed generic-structure expectations live in `test/expect/`; typed
accessor goldens live in `test/golden/`.
