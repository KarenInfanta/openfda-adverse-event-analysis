# Findings and recommendations

> **Read this first.** These are descriptive results from spontaneous adverse-event reports.
> They do **not** show that any drug caused any reaction, they **cannot** be used to calculate
> how often an event occurs, and reports may be incomplete or duplicated. openFDA describes
> its results as unvalidated and not for use in medical-care decisions. Nothing in this
> project ranks drugs by danger or gives clinical advice.

## Data and counting unit

- **Source:** openFDA drug adverse-event API (FAERS data), reports first received 1-31 January 2024. openFDA reported its data as last updated on 2026-07-30 when the first request was made.
- **Sample:** 3,100 of the 106,399 reports received that month (2.9%): up to 100 reports per day, in the order the API returned them. The sample is stratified by day. It is **not random**.
- **True report volumes** (Finding 1) come from the API's server-side `count` aggregation, not from the sample.
- **Counting unit:** one report = one `safetyreportid`. Never patients. Drug and reaction counts use unique reports; repeated entries inside one report are collapsed (11,856 drug entries became 8,605 unique report-drug rows; 9,335 reaction entries became 9,217 unique report-reaction rows).
- **Provenance:** every number below comes from executed code in notebooks 02-04 and SQL queries Q1-Q10 run on MySQL 8.0. The database was reconciled against the pandas results before any query was run (12 of 12 load checks passed).

## Findings

**Finding 1 - Reports received per year fell, then levelled off (2021-2025).**
Yearly reports: 1,566,148 (2021), 1,523,664 (2022), 1,368,572 (2023), 1,319,106 (2024), 1,307,769 (2025), a 16.5% decrease. The largest step was 2022 to 2023 (-10.2%); 2024 to 2025 was -0.9%. Quarterly counts in 2024-2025 stayed between 319,214 and 339,468. Monthly counts ranged from 99,229 (June 2024) to 163,162 (July 2021). Three days (13-15 July 2021) account for 43,642 reports, 26.7% of that month.
*Limits:* counts are reports by first-received date, not patients or events. Reporting rules, batch submissions and FDA processing can all change counts; the cause of the decline cannot be determined from this data.

**Finding 2 - Drugs most often listed as suspect (sample).**
Leuprolide acetate appears as suspect in 167 of 3,086 sampled reports that name a suspect drug (5.4%), followed by dupilumab (137), adalimumab (131), evolocumab (113) and risankizumab-rzaa (110). Seven of the top ten stayed in the top ten when follow-up reports were removed and when reports listing duplicate identifiers were removed.
*Limits:* frequency reflects how widely a drug is used and how reports are submitted, not risk. 97.1% of dupilumab and 97.3% of evolocumab reports list duplicate identifiers, so that filter removes most of both drugs; it is not deduplication.

**Finding 3 - Reaction terms most often reported (sample).**
DEATH appears in 219 of 3,100 reports (7.1%), off label use in 211 (6.8%), drug ineffective in 154 (5.0%), fatigue in 107 (3.5%) and product dose omission issue in 103 (3.3%). Four of the top ten terms describe product use or effectiveness (our own grouping).
*Limits:* a report can list several terms; terms do not show causation.

**Finding 4 - Age and sex recorded in reports (sample).**
1,824 reports (58.8%) have a recorded age (median 61); among them 45-64 is the largest group (612, 33.6%) and 65+ makes up 761 (41.7%). Sex is recorded in 2,659 reports (85.8%): 1,399 female and 1,260 male (52.6% and 47.4% of those with a recorded sex).
*Limits:* shows who the reports are about, not who is at greater risk. Age groups are our own bins.

**Finding 5 - Seriousness recorded in reports (sample).**
1,908 reports (61.5%) are flagged serious. Highest category per report: other serious 829 (26.7%), hospitalization 537 (17.3%), death 468 (15.1%), life-threatening 53 (1.7%), disability 17, congenital anomaly 4. 571 reports carry two or more flags.
*Limits:* shares of sampled reports, not rates. The death flag (468 reports) and the DEATH reaction term (219 reports) are different fields.

**Finding 6 - Reaction terms differ sharply by suspect drug (sample).**
Within each drug's own reports: drug abuse in 70 of 79 fentanyl reports (89%); drug dose omission by device in 66 of 113 evolocumab reports (58%); hot flush in 33 of 167 leuprolide acetate reports (20%); haemoglobin decreased in 25 of 95 clozapine reports (26%); death in 22 of 71 venetoclax reports (31%); pruritus in 19 of 137 dupilumab reports (14%).
*Limits:* 62-167 reports per drug, so small cells are unstable. Nine reports list two or more of the ten drugs and appear under each. Do not compare percentages across drugs as a measure of risk.

**Finding 7 - Data-quality issues (sample).**

| Issue | Count | Out of | Share |
|---|---|---|---|
| Reports with no recorded age | 1,276 | 3,100 | 41.2% |
| Reports with no recorded sex | 441 | 3,100 | 14.2% |
| Reports with no suspect drug | 14 | 3,100 | 0.5% |
| Follow-up reports (version 2 or later) | 897 | 3,100 | 28.9% |
| Reports listing duplicate identifiers | 915 | 3,100 | 29.5% |
| Reports with no company number | 203 | 3,100 | 6.5% |
| Reports with two or more seriousness flags | 571 | 3,100 | 18.4% |
| Drug entries repeating a drug already in the report | 3,251 | 11,856 | 27.4% |
| Drug names taken from reporter free text | 161 | 11,856 | 1.4% |
| Reaction entries repeating a term already in the report | 118 | 9,335 | 1.3% |
| Reaction entries with outcome unknown or not recorded | 5,338 | 9,335 | 57.2% |

Of 1,945 duplicate-identifier entries, 270 were the report's own company number and only 3 pointed to a different report in the sample, so the flag mostly lists other organisations' identifiers for the same case. The longest drug-name value is 355 characters, so some entries are free text rather than a single drug name.

**Finding 8 - Seriousness by age group (SQL).**
Share flagged serious: 61.0% (0-17), 60.4% (18-44), 64.2% (45-64), 64.8% (65-74), 71.1% (75+). Death-flag share: 5.9%, 14.1%, 20.9%, 13.5%, 23.9%. Reports with no age: 56.8% serious and 11.3% death flag, versus 64.9% and 17.8% among reports with an age, so missing age is not random.
*Limits:* the 0-17 death-flag share rests on 7 reports. See Finding 11 for the effect of drug mix.

**Finding 9 - Death-flag share among the ten most frequent suspect drugs (SQL).**
Fentanyl 71 of 79 (89.9%), venetoclax 29 of 71 (40.8%), lenalidomide 11 of 62 (17.7%), adalimumab 17 of 131 (13.0%), leuprolide acetate 19 of 167 (11.4%), upadacitinib 9 of 88 (10.2%), risankizumab-rzaa 8 of 110 (7.3%), dupilumab 1 of 137 (0.7%), evolocumab 0 of 113, clozapine 0 of 95. None of the 79 fentanyl reports lists the DEATH term, although 71 carry the flag.
*Limits:* shares of sampled reports, not mortality or risk; the flag does not show that a drug caused a death.

**Finding 10 - Most frequent suspect drug differs by age group (SQL).**
Dupilumab in 0-17 (12 reports, 10.2% of the group), clozapine in 18-44 (32, 9.6%), fentanyl in 45-64 (69, 11.3%), evolocumab in 65-74 (34, 8.9%), leuprolide acetate in 75+ (51, 13.5%).
*Limits:* age is missing in 41.2% of reports; counts are small.

**Finding 11 - Drug mix can explain an apparent age pattern (SQL).**
69 of the 79 fentanyl-suspect reports (87.3%) fall in the 45-64 group. In that group the death-flag share is 20.9% (128 of 612); excluding the 69 fentanyl-suspect reports it is 11.2% (61 of 543). The other groups change little (18-44: 14.1% to 13.4%; 75+ unchanged at 23.9%). Among the 79 fentanyl-suspect reports, 69 carry both the DRUG ABUSE term and the death flag, 2 carry the flag without the term, 1 carries the term without the flag, and 7 carry neither.
*Limits:* only one drug was removed, so other drug-mix effects (including the 75+ group) were not tested. The fentanyl share describes this type of report in this sample, not fentanyl use in general. The sample cannot explain why these reports cluster.

## What these results support, and what they do not

| Supported | Not supported |
|---|---|
| Reports FDA received fell between 2021 and 2025 and were roughly flat in 2024-2025 | Fewer adverse events occurred |
| Which drugs and terms appear most often in this sample of reports | Which drugs are more dangerous |
| Reported content differs by drug and age group | Causes of any reaction or death |
| Many fields are incomplete, repeated or inconsistent, which changes the results | How common any event is |
| Death flag and DEATH term capture different information | Patient counts (the unit is a report) |

## Recommendations for analysts using these data

These are about analysis practice, not clinical decisions.

1. **Count unique reports and say so.** 27.4% of drug entries repeated a drug already in the same report. Joining drugs to reactions gave 475 rows for 168 leuprolide acetate reports (2.8 rows per report). Counting rows swaps the order of adalimumab (207 rows, 134 reports) and dupilumab (188 rows, 139 reports).
2. **State the denominator on every chart and show missing categories.** Age is missing in 41.2% of reports, and those reports differ from the rest.
3. **Keep report-level and reaction-level outcomes apart, and keep the death flag apart from the DEATH term.** 468 reports carry the flag, 219 the term; for fentanyl, 71 versus 0.
4. **Check drug mix before comparing groups.** Removing 69 fentanyl-suspect reports moved the 45-64 death-flag share from 20.9% to 11.2%.
5. **Separate product-use and device terms from clinical terms.** Four of the ten most frequent reaction terms, and evolocumab's top three, describe product handling.
6. **Standardise drug names and record the source of the name.** 80.8% of drug entries used openFDA's generic name, 17.8% the active substance and 1.4% reporter free text.
7. **Run sensitivity checks before publishing a ranking.** Two of the top ten left the list when reports listing duplicate identifiers were removed.
8. **Use the API's `count` aggregation for volumes and keep samples for content.** The 100-per-day cap flattens daily volumes.

## Future improvements

- Add further months, and test whether rankings and patterns repeat. Large bulk downloads should only follow a size estimate: this sample averaged roughly 24 KB per report, which suggests about 2.5 GB for one month.
- Check whether clusters such as the fentanyl reports concentrate on certain days or submitters.
- Improve drug-name normalisation, including combination products.
- Group reaction terms into documented categories.
- Move the cleaning steps into tested functions in `src/` so the whole analysis rebuilds from one script.
