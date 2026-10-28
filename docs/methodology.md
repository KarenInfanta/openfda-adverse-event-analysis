# Methodology

This is a descriptive analysis. It does not test hypotheses about causes, estimate risk or rank drugs by danger. All numbers come from executed code.

## 1. Pipeline

```
openFDA API -> raw JSON (with provenance) -> extracted tables (reports, drugs, reactions)
            -> cleaned tables -> one-row-per-report-and-item tables
            -> exploratory analysis and charts (pandas) -> MySQL load, reconciliation, queries
```

## 2. Data collection (notebook 01)

- **Endpoint:** `https://api.fda.gov/drug/event.json`, searched with `receivedate:[start TO end]`.
- **Why a sample:** one month holds 106,399 reports. At roughly 24 KB per report in the sample, a full month would be about 2.5 GB, so the project samples, and states what that means.
- **Sampling design:** 31 daily windows (1-31 January 2024), up to 100 reports from each, 3,100 in total (2.9% of the month). The reports are the first the API returned for each day, so the sample is stratified by day and **not random**. Because of the daily cap, the sample cannot show report volume over time.
- **Pagination and limits:** `limit` and `skip` pages; openFDA caps `skip` at about 25,000, so larger pulls must be split by date range. The downloader pauses between requests, retries with backoff on HTTP 429 and 5xx errors, treats HTTP 404 as "no matches", and fails loudly on other errors. No API key was needed.
- **Observed behaviour:** a `count` request that also set `limit=1000` was rejected with HTTP 403 (`API_KEY_MISSING`), while the same request without `limit` returned every day. The project therefore omits `limit` from count requests.
- **Provenance:** the raw file records the date window, the per-day cap, the retrieval time and openFDA's "last updated" date. openFDA updates quarterly, so later runs may differ slightly.
- **True volumes:** report counts over time (2021-2025) come from the API's server-side `count=receivedate` aggregation (5 requests), not from the sample.
- **Versions:** openFDA returns only the latest version of each report and dates each case by when FDA first received it. A report whose `safetyreportversion` is above 1 is the latest version of an updated case.

## 3. Extraction

Each report contains nested lists of drugs and reactions. Extraction creates three tables linked by `safetyreportid`: reports (one row per report), drugs (one row per drug entry) and reactions (one row per reaction entry). They are deliberately not merged: one report can list many drugs and many reactions (up to 259 drug entries in one sampled report), and a merged table would multiply rows. Row counts were asserted after extraction: 3,100 reports, 11,856 drug entries, 9,335 reaction entries.

## 4. Cleaning (notebook 02)

| Step | Rule | What happened in the sample |
|---|---|---|
| Dates | Parsed as `YYYYMMDD` | 0 unparseable receive dates; range 2024-01-01 to 2024-01-31 |
| Age | Converted to years using the unit code; outside 0-120 set to missing | 1,824 reports have an age; 0 out of range; 0 ages without a unit; 1 unit without an age |
| Sex | Coded values mapped; absent = "Not recorded" | 441 not recorded; no unexpected codes |
| Seriousness | `serious` = 1 means serious; flags counted when equal to 1 | 0 reports marked not serious while carrying a seriousness flag |
| Report outcome | One category per report by a fixed priority order (death first) | 1,908 serious reports; 571 carry two or more flags |
| Drug name | First openFDA generic name, else active substance, else reported name | 9,582 of 11,856 entries from the generic name, 2,113 from the active substance, 161 from free text; 0 placeholder values |
| Repeats | Repeated drugs (or reaction terms) within one report collapsed to one row | 11,856 drug entries became 8,605 rows; 9,335 reaction entries became 9,217 rows |
| Drug role | A drug is suspect, concomitant or interacting if listed so at least once | 31 report-drug pairs are both suspect and concomitant |

The age-group bins, the report-outcome priority order and the product-use term grouping (off label use, drug ineffective, product dose omission issue, drug dose omission by device) are this project's own choices, not FDA definitions.

## 5. Duplicates and follow-ups

- Per the openFDA field reference, `duplicate` is 1 when earlier versions of a report were submitted to FDA (openFDA shows only the latest), and `reportduplicate` gives the organisation providing a duplicate or earlier version and its case identifier. In the sample, 897 reports (28.9%) are version 2 or later, 918 carry `duplicate = 1` and 915 list `reportduplicate` entries.
- Of 1,945 `reportduplicate` entries, 270 equal the report's own company number and 3 point to a different report in the sample. Three is a minimum: only matches inside the 3,100 sampled reports can be seen.
- **Decision:** all reports are kept. The counting unit is the report, never the patient. The same real-world case could still appear under different report numbers if it was submitted through different routes, and this dataset cannot show that.
- **Sensitivity checks:** the top-10 suspect-drug list was recomputed (a) on first-version reports only and (b) on reports with no duplicate identifiers. Nine and eight of the ten drugs remained, respectively. These are stress tests, not deduplication: for example, 97.1% of dupilumab and 97.3% of evolocumab reports list duplicate identifiers, so check (b) removes most of both drugs.

## 6. Counting rules

| Analysis | Counting unit | Denominator |
|---|---|---|
| Report volume over time | Reports received (API counts) | Not applicable |
| Top drugs | Unique reports listing the drug as suspect | 3,086 reports with at least one suspect drug |
| Top reactions | Unique reports listing the term | 3,100 reports |
| Age and sex | Reports | 3,100, with "Not recorded" shown |
| Report outcome | Reports, one category each | 3,100 |
| Seriousness flags | Reports carrying each flag (can overlap) | 3,100 |
| Reactions by drug | Unique reports listing both the drug as suspect and the term | The drug's own suspect reports (62-167) |

Because no reaction in a report is linked to a specific drug (openFDA states this), the drug-by-reaction results show terms **listed in the same report**, not reactions of that drug. A report that lists several of the top-10 drugs appears under each (9 reports).

## 7. SQL (notebook 04)

- **Schema:** `reports`, `report_drugs`, `report_reactions` and `daily_report_counts`, with primary and foreign keys. Drug and reaction names use a binary collation so comparisons are exact, matching how pandas counted unique names.
- **Reconciliation:** after loading, 12 checks compared the database with known pandas results (row counts, entries before collapsing, reports with a suspect drug, death-flag reports, reports with an age, one drug's report count, and API volume totals). All 12 passed before any query was run.
- **Queries:** ten queries (Q1-Q10) use GROUP BY, JOIN, LEFT JOIN, CASE, CTEs, EXISTS subqueries, ROW_NUMBER, DENSE_RANK, LAG and a moving average. All were executed. Where SQL and pandas answered the same question they agreed: Q6 matched the pandas top-3 table on all 30 rows, Q7 monthly totals matched the quarterly totals for all eight quarters of 2024-2025, and Q4 matched the 219 / 249 / 2,632 split.

## 8. Quality assurance and problems found

- Row-count assertions after extraction and after each collapse step; no duplicate keys in the final tables.
- Cross-checks: January 2024 volume from two different queries (106,399); quarterly totals equal yearly totals; seriousness counts sum to 3,100.
- **Problems found and fixed during development:**
  1. `reportduplicate` is a list in some reports and a single object in others. The first parsing code failed; a helper now normalises it, and an earlier per-report count that used `len()` on the wrong shape was recomputed.
  2. The API rejected `limit` on `count` requests (see section 2); the code was changed.
  3. A long footnote widened one saved chart; footnotes are now wrapped.
  4. An early heatmap chose its rows in a way that hid some drugs' most frequent terms; it was rebuilt with each drug's own top terms.

## 9. Reproducibility notes

Notebooks run top to bottom in Google Colab and read and write `My Drive/openfda-project/`. Results can change if openFDA has refreshed its data. A clean end-to-end re-run check is planned before the final release.
