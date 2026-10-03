# Structured fixture sources

These are unmodified documents published in SEC EDGAR's Archives:

Foreign issuer exhibit access:

- `6-k-dxst-ex99-1.html` — EX-99.1 attached to Decent Holding Inc.'s 6-K ([accession 0001185185-26-003233](https://www.sec.gov/Archives/edgar/data/1958133/000118518526003233/dxstex99-1.htm); 2026-08-03). The filing directory is recorded in `6-k-dxst-index.json`.

Prospectus and registration samples used for generic named-section coverage:

- `s-3-indaptus.htm.gz` — S-3, Indaptus Therapeutics ([accession 0001641172-25-023490](https://www.sec.gov/Archives/edgar/data/1857044/000164117225023490/forms-3.htm); 2025-08-13).
- `s-3-maxcyte.htm.gz` — S-3, MaxCyte ([accession 0001193125-25-115950](https://www.sec.gov/Archives/edgar/data/1785530/000119312525115950/d809595ds3.htm); 2025-05-08).
- `424b2-barclays.htm.gz` — 424B2, Barclays Bank PLC ([accession 0001918704-25-014571](https://www.sec.gov/Archives/edgar/data/312070/000191870425014571/form424b2.htm); 2025-09-04).
- `424b2-hsbc.htm.gz` — 424B2, HSBC USA Inc. ([accession 0001104659-25-034612](https://www.sec.gov/Archives/edgar/data/83246/000110465925034612/tm2511073d92_424b2.htm); 2025-04-14).
- `f-3-bit-mining.htm.gz` — F-3, BIT Mining Ltd. ([accession 0001104659-25-049758](https://www.sec.gov/Archives/edgar/data/1517496/000110465925049758/tm2515245d1_f3.htm); 2025-05-16).
- `f-3-critical-metals.htm.gz` — F-3, Critical Metals Corp. ([accession 0001213900-25-027568](https://www.sec.gov/Archives/edgar/data/1951089/000121390025027568/ea0235868-f3_critical.htm); 2025-04-02).
- `f-1-verdera.htm.gz` — F-1, Verdera Energy Corp. ([accession 0001104659-26-052783](https://www.sec.gov/Archives/edgar/data/2111453/000110465926052783/tm267430d5_f-1.htm); 2026-04-30).
- `f-1-vision-marine.htm.gz` — F-1, Vision Marine Technologies Inc. ([accession 0001104659-25-118702](https://www.sec.gov/Archives/edgar/data/1813783/000110465925118702/tm2527757d2_f1.htm); 2025-12-05).
- `424b3-powerlaw.htm.gz` — 424B3, Powerlaw Corp. ([accession 0001213900-26-059594](https://www.sec.gov/Archives/edgar/data/2052053/000121390026059594/ea0290638-02_424b3.htm); 2026-05-20).
- `424b3-jpm.htm.gz` — 424B3, JPMorgan Chase Financial Co. LLC ([accession 0001213900-26-077845](https://www.sec.gov/Archives/edgar/data/1665650/000121390026077845/ea0297954-01_424b3.htm); 2026-07-14).
- `424b5-oneok.htm.gz` — 424B5, ONEOK Inc. ([accession 0001193125-26-332962](https://www.sec.gov/Archives/edgar/data/1039684/000119312526332962/d132069d424b5.htm); 2026-08-04).
- `424b5-idaho-power.htm.gz` — 424B5, Idaho Power Co. ([accession 0001193125-26-331165](https://www.sec.gov/Archives/edgar/data/49648/000119312526331165/d171114d424b5.htm); 2026-08-04).

The S-3 samples have table-of-contents-linked `Risk Factors` headings and
exercise the shared named-section accessor. The table-led 424B2 pricing
supplements do not expose heading nodes in these captured primary documents;
where inline structural cues permit, the shared named-section accessor can
still identify `Risk Factors`. All three expose the full HTML body through
generic section access. The S-8
Veralto sample exercises Part II Item access without a table of contents.

Proxy, merger, and tender-offer samples:

- `def-14c-pmgc.htm.gz` — PMGC Holdings definitive information statement ([DEF 14C accession 0001213900-25-080463](https://www.sec.gov/Archives/edgar/data/1840563/000121390025080463/0001213900-25-080463-index.htm); 2025-08-26).
- `defm14a-matrixx.htm.gz` — Sotherly Hotels merger proxy ([DEFM14A accession 0001193125-25-316771](https://www.sec.gov/Archives/edgar/data/1301236/000119312525316771/0001193125-25-316771-index.htm); 2025-12-12).
- `sc-to-i-pamt.htm.gz` — P.A.M. Transportation issuer tender offer ([SC TO-I accession 0001174947-25-000508](https://www.sec.gov/Archives/edgar/data/798287/000117494725000508/sctoi0425_pamt.htm); 2025-04-03).
- `sc-to-c-cresco.htm.gz` — Cresco Labs tender-offer communication ([SC TO-C accession 0001832928-25-000020](https://www.sec.gov/Archives/edgar/data/1832928/000183292825000020/august2025_scheduleto-c.htm); 2025-08-20).

The following Q2 2026 samples are listed in the [SEC quarterly master index](https://www.sec.gov/Archives/edgar/full-index/2026/QTR2/master.idx):

- `defa14c-graybar.htm.gz` — DEFA14C, Graybar Electric Co. ([accession 0000205402-26-000030](https://www.sec.gov/Archives/edgar/data/205402/000020540226000030/c402-20260428corresp.htm); 2026-04-28).
- `defm14c-olaplex.htm.gz` — DEFM14C, Olaplex Holdings ([accession 0001193125-26-202411](https://www.sec.gov/Archives/edgar/data/1868726/000119312526202411/d544500ddefm14c.htm); 2026-05-04).
- `defr14c-srx.htm.gz` — DEFR14C, SRX Global ([accession 0001493152-26-029896](https://www.sec.gov/Archives/edgar/data/1471727/000149315226029896/formdefr14c.htm); 2026-06-24).
- `pos-8c-monroe.htm.gz` — POS 8C, Monroe Capital ([accession 0001104659-26-040388](https://www.sec.gov/Archives/edgar/data/1512931/000110465926040388/tm2611196d1_pos8c.htm); 2026-04-07).
- `prem14c-emerald.htm.gz` — PREM14C, Emerald Holding ([accession 0001193125-26-259608](https://www.sec.gov/Archives/edgar/data/1579214/000119312526259608/d144230dprem14c.htm); 2026-06-05).
- `pren14a-fermi.htm.gz` — PREN14A, Fermi ([accession 0001213900-26-051939](https://www.sec.gov/Archives/edgar/data/2071778/000121390026051939/ea028836002-pren14a_fermi.htm); 2026-05-05).
- `prer14c-esg.htm.gz` — PRER14C, ESG Inc. ([accession 0001520138-26-000133](https://www.sec.gov/Archives/edgar/data/1883835/000152013826000133/esg-20260424_pre14c.htm); 2026-04-24).
- `sc-14n-first-trinity.htm.gz` — SC 14N, First Trinity Financial ([accession 0001437749-26-011911](https://www.sec.gov/Archives/edgar/data/1395585/000143774926011911/zge20260318_sc14n.htm); 2026-04-09).

- `schedule-13g-gme-xml.xml` — [Schedule 13G accession 0002063571-25-000002](https://www.sec.gov/Archives/edgar/data/1326380/000206357125000002/primary_doc.xml) (GameStop; 2025-04-02).
- `schedule-13d-taskus-a.xml` — [Schedule 13D/A accession 0001635999-25-000007](https://www.sec.gov/Archives/edgar/data/1829864/000163599925000007/primary_doc.xml) (TaskUs; 2025-08-26).
- `nport-p-eagle.xml` — [NPORT-P accession 0000850027-26-000015](https://www.sec.gov/Archives/edgar/data/850027/000085002726000015/primary_doc.xml).
- `n-mfp3-northwestern-mutual.xml` — [N-MFP3 accession 0000742212-26-000029](https://www.sec.gov/Archives/edgar/data/742212/000074221226000029/primary_doc.xml).
- `n-cen-alps.xml` — [N-CEN accession 0001049169-26-001803](https://www.sec.gov/Archives/edgar/data/915802/000104916926001803/primary_doc.xml).
- `n-px-a4-wealth.xml` — [N-PX accession 0002033987-26-000005](https://www.sec.gov/Archives/edgar/data/2033987/000203398726000005/primary_doc.xml).
- `nt-n-cen-brown.xml` — [NT N-CEN accession 0000869351-26-000048](https://www.sec.gov/Archives/edgar/data/869351/000086935126000048/primary_doc.xml); the primary's submission type is N-CEN.
- `nt-nport-p-archer.xml` — [NT NPORT-P accession 0000894189-26-014328](https://www.sec.gov/Archives/edgar/data/1477491/000089418926014328/primary_doc.xml); the primary's submission type is NPORT-P.
- `abs-ee-bank5-sample.xml` — [EX-102 in ABS-EE accession 0001539497-26-002177](https://www.sec.gov/Archives/edgar/data/1547361/000153949726002177/exh_102.xml); its XML namespace identifies the CMBS schema.
- `n-csrs-360-funds.htm.gz` — compressed primary N-CSRS from [accession 0001999371-26-012055](https://www.sec.gov/Archives/edgar/data/1319067/000199937126012055/mcgxx-ncsrs_060426.htm).
- `n-vp-american-separate-2.htm.gz` — compressed primary N-VP from [accession 0001193125-26-163027](https://www.sec.gov/Archives/edgar/data/909758/000119312526163027/d123038dnvp.htm).
- `n-vpfs-alger.htm.gz` — compressed primary N-VPFS from [accession 0000847554-26-000007](https://www.sec.gov/Archives/edgar/data/847554/000084755426000007/algerseparateaccountaafs.htm).
- `n-23c-2-ares.htm.gz` — compressed primary N-23C-2 from [accession 0001104659-26-074136](https://www.sec.gov/Archives/edgar/data/1515324/000110465926074136/tm2617761d1_n23c2.htm).
- `n-23c3a-1ws.htm.gz` — compressed primary N-23C3A from [accession 0001398344-26-010907](https://www.sec.gov/Archives/edgar/data/1748680/000139834426010907/fp0099402-1_n23c3a.htm).
- `n-30b-2-adams.htm.gz` — compressed primary N-30B-2 from [accession 0001104659-26-046892](https://www.sec.gov/Archives/edgar/data/2230/000110465926046892/tm268124-1_n30b2.htm).
- `n-8a-ab-tax-aware.htm.gz` — compressed primary N-8A from [accession 0001193125-26-228561](https://www.sec.gov/Archives/edgar/data/2132363/000119312526228561/d78843dn8a.htm).
- `n-8f-aam-alternatives.htm.gz` — compressed primary N-8F from [accession 0001213900-26-070526](https://www.sec.gov/Archives/edgar/data/2065443/000121390026070526/ea0295460-01_n8f.htm).
- `nt-ncsr-cpg-carlyle.htm.gz` — compressed primary NT-NCSR from [accession 0001398344-26-010691](https://www.sec.gov/Archives/edgar/data/1560916/000139834426010691/fp0098304-2_ntncsr.htm).
- `n-30d-spdr.htm.gz` — compressed primary N-30D from [accession 0001193125-26-290785](https://www.sec.gov/Archives/edgar/data/1041130/000119312526290785/d163486dn30d.htm).
- `nt-ncen-siren.htm.gz` — compressed primary NT-NCEN from [accession 0001398344-26-010849](https://www.sec.gov/Archives/edgar/data/1796383/000139834426010849/fp0099423-1_ntncen.htm).
- `ntfncsr-siren.htm.gz` — compressed primary NTFNCSR from [accession 0001398344-26-010772](https://www.sec.gov/Archives/edgar/data/1796383/000139834426010772/fp0099394-1_ntcsr.htm); its primary document type is NT-NCSR.
- `n-54a-third-point.htm.gz` — compressed primary N-54A from [accession 0001104659-26-040357](https://www.sec.gov/Archives/edgar/data/2025369/000110465926040357/tm2611086d1_n54a.htm).
- `n-54c-nuveen.htm.gz` — compressed primary N-54C from [accession 0002071136-26-000023](https://www.sec.gov/Archives/edgar/data/2071136/000207113626000023/bdcv-formnx54cmay2026.htm).
- `n-6f-robinhood.htm.gz` — compressed primary N-6F from [accession 0001628280-26-046265](https://www.sec.gov/Archives/edgar/data/2131040/000162828026046265/rviin-6f.htm).
- `n-23c3b-axxes.htm.gz` — compressed primary N-23C3B from [accession 0001580642-26-003231](https://www.sec.gov/Archives/edgar/data/2003867/000158064226003231/axxesopportunistic23c3.htm); its filer-supplied description says N-23C3A, but the SEC filing type and document type are N-23C3B.
- `n-8f-ntc-blackrock.pdf` — PDF primary N-8F NTC for BlackRock Collateral Trust from [accession 9999999997-26-000987](https://www.sec.gov/Archives/edgar/data/1671416/999999999726000987/filename1.pdf).
- `n-8f-ordr-blackrock.pdf` — PDF primary N-8F ORDR for BlackRock Collateral Trust from [accession 9999999997-26-001103](https://www.sec.gov/Archives/edgar/data/1671416/999999999726001103/filename1.pdf).
- `10-d-ms-c21.htm.gz` — compressed primary 10-D from [accession 0001888524-26-012144](https://www.sec.gov/Archives/edgar/data/1631406/000188852426012144/msc15c21_10d-202606.htm).
- `abs-15g-tesla-energy.htm.gz` — compressed primary ABS-15G from [accession 0001193125-26-219735](https://www.sec.gov/Archives/edgar/data/2037778/000119312526219735/d108502dabs15g.htm).
- `abs-ee-deutsche.xml` — [EX-102 in ABS-EE accession 0001539497-25-000961](https://www.sec.gov/Archives/edgar/data/1013454/000153949725000961/exh_102.xml).
- `abs-ee-cd2017-cd3.xml` — [EX-102 in ABS-EE accession 0001888524-25-016561](https://www.sec.gov/Archives/edgar/data/1693368/000188852425016561/exh_102.xml).
- `c-ar-diaspora.xml` — [C-AR accession 0002059521-25-000009](https://www.sec.gov/Archives/edgar/data/2059521/000205952125000009/primary_doc.xml).
- `c-ar-kronos.xml` — [C-AR accession 0001108248-25-000004](https://www.sec.gov/Archives/edgar/data/1108248/000110824825000004/primary_doc.xml).
- `structured/ncsr-sample.htm.gz` — compressed primary document from [N-CSR accession 0000030146-26-000114](https://www.sec.gov/Archives/edgar/data/737520/000003014626000114/output.htm), used to test the generic Item section API.
- `ma-i-ey-2026.xml` — [MA-I accession 0001617793-26-000005](https://www.sec.gov/Archives/edgar/data/1617793/000161779326000005/primary_doc.xml).
- `ta-2-edward-jones-2026.xml` — [TA-2 accession 0000810417-26-000002](https://www.sec.gov/Archives/edgar/data/810417/000081041726000002/primary_doc.xml).
- `upload-irenic-2026.txt` — [UPLOAD accession 0000000000-26-003277](https://www.sec.gov/Archives/edgar/data/2122505/000000000026003277/filename2.txt), the SEC-provided text extract of the staff letter.
- `40-app-m3sixty.htm.gz` — compressed [40-APP accession 0001999371-26-010840](https://www.sec.gov/Archives/edgar/data/1319067/000199937126010840/m3sixty-40app_051526.htm).
- `485bpos-geme.htm.gz` — compressed [485BPOS accession 0001999371-26-009141](https://www.sec.gov/Archives/edgar/data/1969674/000199937126009141/geme-485bpos_042726.htm).
- `497-1290.htm.gz` — compressed [497 accession 0001193125-26-147484](https://www.sec.gov/Archives/edgar/data/1605941/000119312526147484/d64604d497.htm).
- `497j-360.htm.gz` — compressed [497J accession 0001999371-26-007585](https://www.sec.gov/Archives/edgar/data/1319067/000199937126007585/income-497j_040226.htm).
- `24f-2nt-ab.xml` — [24F-2NT accession 0001193125-26-275392](https://www.sec.gov/Archives/edgar/data/81443/000119312526275392/primary_doc.xml).
- `40-17g-1290.htm.gz` — compressed [40-17G accession 0001193125-26-265192](https://www.sec.gov/Archives/edgar/data/1605941/000119312526265192/d56800d4017g.htm).
- `485apos-360.htm.gz` — compressed [485APOS accession 0001999371-26-013444](https://www.sec.gov/Archives/edgar/data/1319067/000199937126013444/m3sixty-485apos_062526.htm).
- `485bxt-ark.htm.gz` — compressed [485BXT accession 0001213900-26-041967](https://www.sec.gov/Archives/edgar/data/1579982/000121390026041967/ea0285627-01_485bxt.htm).
- `497vpi-allianz.htm.gz` — compressed [497VPI accession 0000072499-26-000023](https://www.sec.gov/Archives/edgar/data/72499/000007249926000023/iaincomeadvsupplement.htm).
- `497vpu-allianz-ny.htm.gz` — compressed [497VPU accession 0000080019-26-000008](https://www.sec.gov/Archives/edgar/data/80019/000008001926000008/iany497vpu.htm).
- `s-6-ft12946.htm.gz` — compressed [S-6 accession 0001445546-26-002415](https://www.sec.gov/Archives/edgar/data/2111250/000144554626002415/s-6.htm).

The corresponding reviewed golden values and strings live in `test/golden/`.
Reviewed generic-structure expectations live in `test/expect/`; typed
accessor goldens live in `test/golden/`.
