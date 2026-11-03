-- =============================================================
-- 01_schema.sql
-- Creates the database tables.
--
-- Design:
--   raw_ed_performance  -> the CSV exactly as downloaded (staging)
--   hospitals           -> one row per location
--   measures            -> one row per performance measure
--   triage_categories   -> the 5 Australasian Triage Scale levels + "All"
--   ed_performance      -> the clean fact table (one row per
--                          hospital x measure x triage x month)
-- =============================================================

DROP TABLE IF EXISTS ed_performance;
DROP TABLE IF EXISTS triage_categories;
DROP TABLE IF EXISTS measures;
DROP TABLE IF EXISTS hospitals;
DROP TABLE IF EXISTS raw_ed_performance;

-- Staging table: every column is TEXT so nothing is lost on import.
CREATE TABLE raw_ed_performance (
    measure          TEXT,
    unit_of_measure  TEXT,
    location         TEXT,
    triage_category  TEXT,
    financial_year   TEXT,
    time_period      TEXT,
    monthly_outcome  TEXT,
    fytd_outcome     TEXT
);

CREATE TABLE hospitals (
    hospital_id    INTEGER PRIMARY KEY,
    hospital_name  TEXT NOT NULL UNIQUE,
    is_act_total   INTEGER NOT NULL DEFAULT 0   -- 1 = the whole-of-ACT figure
);

CREATE TABLE measures (
    measure_id    INTEGER PRIMARY KEY,
    measure_name  TEXT NOT NULL UNIQUE,
    short_name    TEXT NOT NULL UNIQUE,         -- easier to type in queries
    unit          TEXT NOT NULL,                -- 'Number' or 'Percentage'
    higher_is_better INTEGER NOT NULL           -- 1 = higher is better, 0 = lower is better
);

CREATE TABLE triage_categories (
    triage_id       INTEGER PRIMARY KEY,        -- 1 = most urgent ... 5 = least; 0 = All
    triage_name     TEXT NOT NULL UNIQUE,
    target_minutes  INTEGER,                    -- should be seen within this many minutes
    benchmark_pct   REAL                        -- national benchmark: % seen within target
);

CREATE TABLE ed_performance (
    hospital_id     INTEGER NOT NULL REFERENCES hospitals(hospital_id),
    measure_id      INTEGER NOT NULL REFERENCES measures(measure_id),
    triage_id       INTEGER NOT NULL REFERENCES triage_categories(triage_id),
    month_start     DATE    NOT NULL,           -- e.g. '2024-07-01'
    financial_year  TEXT    NOT NULL,           -- e.g. '2024-25'
    monthly_value   REAL,                       -- NULL when not published
    fytd_value      REAL,                       -- financial-year-to-date value
    PRIMARY KEY (hospital_id, measure_id, triage_id, month_start)
);
