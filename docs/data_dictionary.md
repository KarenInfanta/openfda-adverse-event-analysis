# Data dictionary

Source field meanings and code values were checked against the openFDA drug-event field reference (https://open.fda.gov/fields/drugevent.yaml) in October 2026. Derived fields are this project's own definitions.

## 1. Source fields used

| openFDA field | Meaning (per openFDA) | Used as |
|---|---|---|
| `safetyreportid` | Case report number identifying the report | Primary key; the counting unit |
| `safetyreportversion` | Version number of the report. openFDA returns only the latest version | `report_version` |
| `receivedate` | Date FDA first received the report | `receive_date`; time axis |
| `receiptdate` | Date FDA received the most recent information | `receipt_date` |
| `serious` | 1 = report was serious, 2 = not serious | `is_serious` |
| `seriousnessdeath`, `seriousnesslifethreatening`, `seriousnesshospitalization`, `seriousnessdisabling`, `seriousnesscongenitalanomali`, `seriousnessother` | 1 when that seriousness criterion applies; otherwise absent or 2 | `flag_*` columns |
| `patient.patientonsetage` | Age of the patient when the event first occurred | `age_years` (with the unit) |
| `patient.patientonsetageunit` | Unit of the age value | Used to convert to years |
| `patient.patientsex` | Sex of the patient | `sex` |
| `patient.drug[].medicinalproduct` | Drug name as reported; not systematically normalised, may contain misspellings or free text | Last-resort drug name |
| `patient.drug[].activesubstance.activesubstancename` | Active ingredient | Second-choice drug name |
| `patient.drug[].openfda.generic_name` | Generic name(s) added by openFDA | First-choice drug name (first value) |
| `patient.drug[].drugcharacterization` | Role of the drug as reported; not validated by FDA | `is_suspect`, `is_concomitant`, `is_interacting` |
| `patient.reaction[].reactionmeddrapt` | Reaction as a MedDRA preferred term (British English spelling) | `reaction_pt` |
| `patient.reaction[].reactionoutcome` | Outcome of the reaction at the last observation | `any_fatal`; outcome-quality checks |
| `companynumb` | Identifier assigned by the reporting company | `company_number` |
| `duplicate` | 1 when earlier versions of the report were submitted to FDA (openFDA shows only the latest) | Quality checks |
| `reportduplicate` | Organisation providing a duplicate or earlier version, and its case identifier. Can be a single object or a list | `n_duplicate_ids` |
| `primarysourcecountry` | Country of the primary reporter | `primary_source_country` |

Extracted but not analysed: `reporttype`, `patientagegroup`, `drugindication`, brand name.

## 2. Code values

| Field | Code | Meaning |
|---|---|---|
| `patientsex` | 0 / 1 / 2 | Unknown / Male / Female |
| `patientonsetageunit` | 800 / 801 / 802 / 803 / 804 / 805 | Decade / Year / Month / Week / Day / Hour |
| `drugcharacterization` | 1 / 2 / 3 | Suspect / Concomitant / Interacting |
| `reactionoutcome` | 1 / 2 / 3 / 4 / 5 / 6 | Recovered-resolved / Recovering-resolving / Not recovered-not resolved / Recovered-resolved with sequelae / Fatal / Unknown |
| `serious` | 1 / 2 | Serious / Not serious |

## 3. Derived rules

| Derived field | Rule |
|---|---|
| `age_years` | `patientonsetage` times a unit factor: decade x10, year x1, month /12, week /52.18, day /365.25, hour /8,766. Set to missing when the unit is absent or the result is outside 0-120 years |
| `age_group` | Our own bins: 0-17, 18-44, 45-64, 65-74, 75+; "Not recorded" when age is missing |
| `sex` | Male, Female, Unknown (code 0) or Not recorded (field absent) |
| `report_outcome` | One category per report, the highest that applies: Death > Life-threatening > Hospitalization > Disability > Congenital anomaly > Other serious. Then "Serious (type not specified)", "Not serious", "Not recorded" |
| `drug_name_std` | First openFDA generic name, else active substance, else reported product name; upper-cased, trimmed, repeated spaces collapsed; placeholder values such as UNKNOWN set to missing |
| `reaction_pt` | `reactionmeddrapt`, upper-cased and trimmed |
| `n_entries` | How many times the drug (or reaction term) was listed in the report before collapsing |
| `any_fatal` | 1 if any entry of that reaction term in that report has outcome Fatal |

## 4. Database tables (MySQL, `sql/schema.sql`)

**reports** - one row per report (3,100 rows in the sample)

| Column | Description |
|---|---|
| `safetyreportid` | Primary key |
| `receive_date`, `receipt_date` | Dates as above |
| `report_version` | 1 = first report, above 1 = follow-up |
| `age_years`, `age_group`, `sex` | Derived as above |
| `is_serious` | 1 or 0 |
| `flag_death`, `flag_life_threatening`, `flag_hospitalization`, `flag_disability`, `flag_congenital_anomaly`, `flag_other_serious` | 1 or 0 per seriousness criterion; a report can carry several |
| `report_outcome` | Highest seriousness category, as above |
| `n_duplicate_ids` | Number of `reportduplicate` entries |
| `company_number`, `primary_source_country` | As reported |

**report_drugs** - one row per distinct drug per report (8,605 rows)

| Column | Description |
|---|---|
| `safetyreportid`, `drug_name_std` | Composite primary key; foreign key to `reports` |
| `n_entries` | Times listed in the report |
| `is_suspect`, `is_concomitant`, `is_interacting` | 1 if listed in that role at least once; a drug can have more than one |

**report_reactions** - one row per distinct reaction term per report (9,217 rows)

| Column | Description |
|---|---|
| `safetyreportid`, `reaction_pt` | Composite primary key; foreign key to `reports` |
| `n_entries` | Times listed in the report |
| `any_fatal` | As above |

**daily_report_counts** - true number of reports FDA received per day, 2021-2025 (1,826 rows)

| Column | Description |
|---|---|
| `report_date` | Primary key |
| `reports` | Count from the API's `count` aggregation |

**Counting rule:** joins between `report_drugs` and `report_reactions` pair every drug in a report with every reaction in it, which means "listed in the same report", not "caused". Always count `COUNT(DISTINCT safetyreportid)`.
