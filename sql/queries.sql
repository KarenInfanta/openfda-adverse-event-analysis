-- openFDA adverse event analysis: analytical queries (MySQL 8.0+)
-- Counting unit: one report = one safetyreportid. Not patients.
-- Counts use COUNT(DISTINCT safetyreportid) wherever tables are joined.
-- Results describe a sample of up to 100 reports per day for January 2024 (not random).
USE openfda_faers;

-- Q1 GROUP BY and CASE: reports by age group
SELECT
    age_group,
    COUNT(*) AS n_reports,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM reports), 1) AS pct_of_all_reports
FROM reports
GROUP BY age_group
ORDER BY CASE age_group
             WHEN '0-17' THEN 1 WHEN '18-44' THEN 2 WHEN '45-64' THEN 3
             WHEN '65-74' THEN 4 WHEN '75+' THEN 5 ELSE 6 END;

-- Q2 GROUP BY with conditional CASE counts: seriousness flags by age group
SELECT
    age_group,
    COUNT(*) AS n_reports,
    SUM(CASE WHEN is_serious = 1 THEN 1 ELSE 0 END) AS n_serious,
    ROUND(100.0 * SUM(CASE WHEN is_serious = 1 THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_serious,
    SUM(CASE WHEN flag_death = 1 THEN 1 ELSE 0 END) AS n_death_flag,
    ROUND(100.0 * SUM(CASE WHEN flag_death = 1 THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_death_flag
FROM reports
GROUP BY age_group
ORDER BY CASE age_group
             WHEN '0-17' THEN 1 WHEN '18-44' THEN 2 WHEN '45-64' THEN 3
             WHEN '65-74' THEN 4 WHEN '75+' THEN 5 ELSE 6 END;

-- Q3 JOIN: top 10 drugs listed as suspect, with death-flag counts
SELECT
    d.drug_name_std,
    COUNT(DISTINCT d.safetyreportid) AS n_reports,
    ROUND(100.0 * COUNT(DISTINCT d.safetyreportid)
          / (SELECT COUNT(DISTINCT safetyreportid) FROM report_drugs WHERE is_suspect = 1), 1)
          AS pct_of_reports_with_suspect_drug,
    COUNT(DISTINCT CASE WHEN r.flag_death = 1 THEN d.safetyreportid END) AS n_with_death_flag,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN r.flag_death = 1 THEN d.safetyreportid END)
          / COUNT(DISTINCT d.safetyreportid), 1) AS pct_with_death_flag
FROM report_drugs d
JOIN reports r ON r.safetyreportid = d.safetyreportid
WHERE d.is_suspect = 1
GROUP BY d.drug_name_std
ORDER BY n_reports DESC, d.drug_name_std
LIMIT 10;

-- Q4 LEFT JOIN and CASE: the DEATH reaction term versus the death seriousness flag
SELECT
    CASE WHEN r.flag_death = 1 THEN 'death flag' ELSE 'no death flag' END AS death_flag,
    CASE WHEN x.safetyreportid IS NOT NULL THEN 'DEATH term' ELSE 'no DEATH term' END AS death_term,
    COUNT(*) AS n_reports
FROM reports r
LEFT JOIN report_reactions x
       ON x.safetyreportid = r.safetyreportid AND x.reaction_pt = 'DEATH'
GROUP BY 1, 2
ORDER BY 1, 2;

-- Q5 Double-counting demonstration: joining drugs to reactions multiplies rows
SELECT
    COUNT(*) AS joined_rows,
    COUNT(DISTINCT d.safetyreportid) AS distinct_reports,
    ROUND(COUNT(*) / COUNT(DISTINCT d.safetyreportid), 1) AS rows_per_report
FROM report_drugs d
JOIN report_reactions x ON x.safetyreportid = d.safetyreportid
WHERE d.drug_name_std = 'LEUPROLIDE ACETATE';

-- Q6 CTEs and ROW_NUMBER: each top-10 suspect drug's three most frequent reaction terms
WITH top_drugs AS (
    SELECT drug_name_std, COUNT(DISTINCT safetyreportid) AS n_drug_reports
    FROM report_drugs
    WHERE is_suspect = 1
    GROUP BY drug_name_std
    ORDER BY n_drug_reports DESC, drug_name_std
    LIMIT 10
),
pair_counts AS (
    SELECT t.drug_name_std, t.n_drug_reports, x.reaction_pt,
           COUNT(DISTINCT d.safetyreportid) AS n_reports
    FROM top_drugs t
    JOIN report_drugs d ON d.drug_name_std = t.drug_name_std AND d.is_suspect = 1
    JOIN report_reactions x ON x.safetyreportid = d.safetyreportid
    GROUP BY t.drug_name_std, t.n_drug_reports, x.reaction_pt
),
ranked AS (
    SELECT drug_name_std, n_drug_reports, reaction_pt, n_reports,
           ROW_NUMBER() OVER (PARTITION BY drug_name_std
                              ORDER BY n_reports DESC, reaction_pt) AS rnk
    FROM pair_counts
)
SELECT drug_name_std, rnk, reaction_pt, n_reports, n_drug_reports,
       ROUND(100.0 * n_reports / n_drug_reports, 1) AS pct_of_drug_reports
FROM ranked
WHERE rnk <= 3
ORDER BY n_drug_reports DESC, drug_name_std, rnk;

-- Q7 CTE, LAG and a moving average: monthly reports received (true counts), 2024 and 2025
WITH monthly AS (
    SELECT DATE_SUB(report_date, INTERVAL DAYOFMONTH(report_date) - 1 DAY) AS report_month,
           SUM(reports) AS n_reports
    FROM daily_report_counts
    GROUP BY report_month
),
with_window AS (
    SELECT report_month, n_reports,
           LAG(n_reports, 12) OVER (ORDER BY report_month) AS same_month_prev_year,
           AVG(n_reports) OVER (ORDER BY report_month
                                ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS avg_last_3_months
    FROM monthly
)
SELECT report_month, n_reports, same_month_prev_year,
       ROUND(100.0 * (n_reports - same_month_prev_year) / same_month_prev_year, 1) AS pct_change_vs_prev_year,
       ROUND(avg_last_3_months, 0) AS avg_last_3_months
FROM with_window
WHERE report_month >= '2024-01-01'
ORDER BY report_month;

-- Q8 CTEs and DENSE_RANK: most frequent suspect drugs within each age group (ties share a rank)
WITH age_totals AS (
    SELECT age_group, COUNT(*) AS n_group_reports
    FROM reports
    GROUP BY age_group
),
drug_by_age AS (
    SELECT r.age_group, d.drug_name_std, COUNT(DISTINCT r.safetyreportid) AS n_reports
    FROM reports r
    JOIN report_drugs d ON d.safetyreportid = r.safetyreportid AND d.is_suspect = 1
    WHERE r.age_group <> 'Not recorded'
    GROUP BY r.age_group, d.drug_name_std
),
ranked AS (
    SELECT age_group, drug_name_std, n_reports,
           DENSE_RANK() OVER (PARTITION BY age_group ORDER BY n_reports DESC) AS rnk
    FROM drug_by_age
)
SELECT k.age_group, k.rnk, k.drug_name_std, k.n_reports, a.n_group_reports,
       ROUND(100.0 * k.n_reports / a.n_group_reports, 1) AS pct_of_age_group_reports
FROM ranked k
JOIN age_totals a ON a.age_group = k.age_group
WHERE k.rnk <= 3
ORDER BY CASE k.age_group
             WHEN '0-17' THEN 1 WHEN '18-44' THEN 2 WHEN '45-64' THEN 3
             WHEN '65-74' THEN 4 ELSE 5 END,
         k.rnk, k.drug_name_std;

-- Q9 CTE with an EXISTS subquery: death-flag share by age group, with and without reports listing fentanyl as suspect
WITH flagged AS (
    SELECT r.age_group, r.flag_death,
           CASE WHEN EXISTS (SELECT 1 FROM report_drugs d
                             WHERE d.safetyreportid = r.safetyreportid
                               AND d.drug_name_std = 'FENTANYL' AND d.is_suspect = 1)
                THEN 1 ELSE 0 END AS fentanyl_suspect
    FROM reports r
)
SELECT age_group,
       COUNT(*) AS n_reports,
       SUM(flag_death) AS n_death_flag,
       ROUND(100.0 * SUM(flag_death) / COUNT(*), 1) AS pct_death_flag,
       SUM(fentanyl_suspect) AS n_fentanyl_suspect,
       SUM(CASE WHEN fentanyl_suspect = 0 THEN 1 ELSE 0 END) AS n_reports_excl_fentanyl,
       SUM(CASE WHEN fentanyl_suspect = 0 THEN flag_death ELSE 0 END) AS n_death_flag_excl_fentanyl,
       ROUND(100.0 * SUM(CASE WHEN fentanyl_suspect = 0 THEN flag_death ELSE 0 END)
             / NULLIF(SUM(CASE WHEN fentanyl_suspect = 0 THEN 1 ELSE 0 END), 0), 1) AS pct_death_flag_excl_fentanyl
FROM flagged
GROUP BY age_group
ORDER BY CASE age_group WHEN '0-17' THEN 1 WHEN '18-44' THEN 2 WHEN '45-64' THEN 3
                        WHEN '65-74' THEN 4 WHEN '75+' THEN 5 ELSE 6 END;

-- Q10 CTE with EXISTS subqueries: fentanyl-suspect reports by DRUG ABUSE term and death flag
WITH fentanyl_reports AS (
    SELECT r.safetyreportid, r.flag_death,
           CASE WHEN EXISTS (SELECT 1 FROM report_reactions x
                             WHERE x.safetyreportid = r.safetyreportid
                               AND x.reaction_pt = 'DRUG ABUSE')
                THEN 1 ELSE 0 END AS has_drug_abuse_term
    FROM reports r
    WHERE EXISTS (SELECT 1 FROM report_drugs d
                  WHERE d.safetyreportid = r.safetyreportid
                    AND d.drug_name_std = 'FENTANYL' AND d.is_suspect = 1)
)
SELECT has_drug_abuse_term, flag_death AS has_death_flag, COUNT(*) AS n_reports
FROM fentanyl_reports
GROUP BY has_drug_abuse_term, flag_death
ORDER BY has_drug_abuse_term, flag_death;
