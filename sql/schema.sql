-- openFDA adverse event analysis: relational schema (MySQL 8.0+)
-- Counting unit everywhere: one report = one safetyreportid (not a patient).
-- Joins multiply rows, so always count with COUNT(DISTINCT safetyreportid).

CREATE DATABASE IF NOT EXISTS openfda_faers CHARACTER SET utf8mb4;
USE openfda_faers;

DROP TABLE IF EXISTS report_reactions;
DROP TABLE IF EXISTS report_drugs;
DROP TABLE IF EXISTS reports;
DROP TABLE IF EXISTS daily_report_counts;

-- reports: one row per report; report-level facts and report-level outcomes.
CREATE TABLE reports (
    safetyreportid          VARCHAR(20)  NOT NULL COMMENT 'FDA report id',
    receive_date            DATE         NOT NULL COMMENT 'date FDA first received the case (receivedate)',
    receipt_date            DATE         NULL     COMMENT 'date the latest version was received (receiptdate)',
    report_version          INT          NOT NULL COMMENT '1 = first report, above 1 = follow-up',
    age_years               DECIMAL(7,3) NULL     COMMENT 'patient age converted to years; NULL if not recorded',
    age_group               VARCHAR(20)  NOT NULL COMMENT 'our bins: 0-17, 18-44, 45-64, 65-74, 75+, Not recorded',
    sex                     VARCHAR(20)  NOT NULL COMMENT 'Male, Female, Unknown or Not recorded',
    is_serious              TINYINT(1)   NOT NULL COMMENT '1 = serious, 0 = not serious',
    flag_death              TINYINT(1)   NOT NULL,
    flag_life_threatening   TINYINT(1)   NOT NULL,
    flag_hospitalization    TINYINT(1)   NOT NULL,
    flag_disability         TINYINT(1)   NOT NULL,
    flag_congenital_anomaly TINYINT(1)   NOT NULL,
    flag_other_serious      TINYINT(1)   NOT NULL,
    report_outcome          VARCHAR(40)  NOT NULL COMMENT 'highest seriousness category per report (our priority order)',
    n_duplicate_ids         INT          NOT NULL COMMENT 'number of duplicate identifiers listed in the report',
    company_number          VARCHAR(100) NULL,
    primary_source_country  VARCHAR(20)  NULL,
    PRIMARY KEY (safetyreportid),
    KEY idx_reports_receive_date (receive_date),
    KEY idx_reports_outcome (report_outcome)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- report_drugs: one row per DISTINCT drug per report (repeated entries collapsed).
-- utf8mb4_bin makes name comparison exact, matching how Python counted unique names.
CREATE TABLE report_drugs (
    safetyreportid  VARCHAR(20)  NOT NULL,
    drug_name_std   VARCHAR(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL COMMENT 'standardised drug name (uppercase)',
    n_entries       INT          NOT NULL COMMENT 'how many times the drug was listed in the report',
    is_suspect      TINYINT(1)   NOT NULL,
    is_concomitant  TINYINT(1)   NOT NULL,
    is_interacting  TINYINT(1)   NOT NULL,
    PRIMARY KEY (safetyreportid, drug_name_std),
    KEY idx_report_drugs_name (drug_name_std),
    CONSTRAINT fk_report_drugs_report FOREIGN KEY (safetyreportid) REFERENCES reports (safetyreportid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- report_reactions: one row per DISTINCT reaction term per report.
CREATE TABLE report_reactions (
    safetyreportid  VARCHAR(20)  NOT NULL,
    reaction_pt     VARCHAR(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL COMMENT 'reaction term as reported (uppercase)',
    n_entries       INT          NOT NULL,
    any_fatal       TINYINT(1)   NOT NULL COMMENT '1 if any entry of this term has outcome Fatal',
    PRIMARY KEY (safetyreportid, reaction_pt),
    KEY idx_report_reactions_term (reaction_pt),
    CONSTRAINT fk_report_reactions_report FOREIGN KEY (safetyreportid) REFERENCES reports (safetyreportid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- daily_report_counts: true number of reports FDA received per day (API count endpoint).
CREATE TABLE daily_report_counts (
    report_date  DATE NOT NULL,
    reports      INT  NOT NULL,
    PRIMARY KEY (report_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
