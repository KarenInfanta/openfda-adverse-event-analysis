# Limitations

## The data: what adverse-event reports can and cannot show

> Reports in FAERS and openFDA do **not** establish that a drug caused a reaction, may be incomplete or duplicated, and **cannot** be used to calculate how often an event occurs.

- **No causation.** A report records that a drug and an event were reported together. openFDA states that no individual drug is linked to an individual reaction, so when a report lists several drugs and several reactions the data cannot show which drug is responsible for which reaction.
- **No incidence or risk.** There is no count of how many people used each drug, so report counts cannot be turned into rates. Widely used products appear more often simply because more people use them.
- **Voluntary and uneven reporting.** Not every event is reported, and reporting is shaped by factors such as publicity, regulation and how long a product has been on the market. The data are unvalidated, and openFDA says they should not be used for medical-care decisions.
- **Quality of fields.** Drug names are not systematically normalised and can contain misspellings or free text. Drug roles (suspect, concomitant) are reported, not validated.
- **Versions and duplicates.** openFDA shows only the latest version of a report. The same case could still appear under different report numbers if it reached FDA through different routes; this dataset cannot show how often.
- **Refreshes.** openFDA updates quarterly and may lag by three months or more, so counts for recent periods can change.

## This project's sample

- **Small and not random.** 3,100 of 106,399 January 2024 reports (2.9%): up to 100 per day in API order. Results describe this sample, not all of FAERS.
- **One month for report content.** Drug, reaction, age, sex and seriousness results come from January 2024 only. Rankings could differ in other months.
- **Volume trend.** The 2021-2025 counts use the API's own totals, but they count reports by first-received date, not events. Reporting rules, batch submissions and processing can all change them. Three days in July 2021 hold 26.7% of that month's reports (43,642 of 163,162), and the cause is unknown.

## Missing and uncertain values in the sample

- Age is missing in 1,276 reports (41.2%) and sex in 441 (14.2%). Reports without an age differ from those with one (for example 11.3% versus 17.8% carry the death flag), so the missingness is not random.
- 5,338 of 9,335 reaction entries (57.2%) have an unknown or unrecorded outcome.
- 14 reports (0.5%) list no suspect drug.
- Drug names: 161 of 11,856 drug entries (1.4%) use reporter free text, the longest name value is 355 characters, and only the first generic name is kept for combination products. The same drug may still appear under more than one name.
- Reaction terms use British English MedDRA wording (for example "diarrhoea"). They are not grouped into higher-level categories.

## Choices made by this project

- Age groups, the one-category-per-report outcome priority order, and the "product use" grouping of reaction terms are our own definitions and are incomplete. For example, "wrong technique in product usage process" is arguably also a product-use term.
- A drug is counted as suspect if it is listed as suspect at least once in a report; 31 report-drug pairs are listed as both suspect and concomitant.
- Seriousness flags overlap (571 reports carry two or more), so "one category per report" and "every flag counted" give different counts. Both are shown and labelled.
- The DEATH reaction term (219 reports) and the death seriousness flag (468 reports) are different fields. For fentanyl, no report lists the DEATH term although 71 carry the flag.

## Interpretation limits

- **Small counts.** Each drug in the drug-by-reaction results has 62-167 sampled reports, so cells with 1-3 reports are unstable.
- **Overlap between drugs.** Nine reports list two or more of the top-10 drugs and appear under each.
- **Drug mix confounds group comparisons.** Fentanyl reports (87.3% in the 45-64 group) change that group's death-flag share from 20.9% to 11.2% when removed. Only fentanyl was tested; other drug-mix effects, such as in the 75+ group, were not.
- **Clusters are unexplained.** 69 of 79 fentanyl-suspect reports carry both the DRUG ABUSE term and the death flag. The sample cannot say why, and the pattern describes this type of report, not fentanyl use in general.
- **Sensitivity checks are stress tests.** Removing follow-up reports or reports with duplicate identifiers is not deduplication, and it removes most reports for some drugs.
- **Counts are reports, not patients.**

## What this project does not do

- Establish or test causal relationships.
- Estimate incidence, prevalence or risk.
- Rank drugs by danger or compare drug safety.
- Give clinical, regulatory or treatment recommendations.
- Replace validated pharmacovigilance methods or expert review.

## Technical limits

- Developed and run in Google Colab with MySQL 8.0 installed inside the session; not tested elsewhere.
- Package versions are not yet pinned (see `requirements.txt`).
- A clean end-to-end re-run check is still to be completed.
