-- =============================================================
-- 02_transform.sql
-- Cleans the raw staging data into the lookup + fact tables.
-- Skills shown: INSERT ... SELECT, DISTINCT, CASE, string
-- functions, JOINs, NULLIF.
-- =============================================================

-- 1. Hospitals -------------------------------------------------
INSERT INTO hospitals (hospital_name, is_act_total)
SELECT DISTINCT
    location,
    CASE WHEN location = 'ACT' THEN 1 ELSE 0 END
FROM raw_ed_performance
ORDER BY location;

-- 2. Measures --------------------------------------------------
INSERT INTO measures (measure_name, short_name, unit, higher_is_better)
SELECT DISTINCT
    measure,
    CASE measure
        WHEN 'Median waiting time to treatment (minutes) in emergency departments' THEN 'median_wait_min'
        WHEN 'Patients starting treatment on time'                     THEN 'pct_on_time'
        WHEN 'Patients leaving the ED within 4 hours'                  THEN 'pct_4hr'
        WHEN 'Patients leaving the ED within 4 hours - Admitted'       THEN 'pct_4hr_admitted'
        WHEN 'Patients leaving the ED within 4 hours - Not-admitted'   THEN 'pct_4hr_not_admitted'
        WHEN 'Patients who did not wait to be seen'                    THEN 'pct_did_not_wait'
    END,
    unit_of_measure,
    -- For wait times and "did not wait", a LOWER number is better
    CASE WHEN measure LIKE 'Median waiting%'
           OR measure LIKE '%did not wait%' THEN 0 ELSE 1 END
FROM raw_ed_performance;

-- 3. Triage categories (Australasian Triage Scale) -------------
-- Targets and benchmarks are the national ATS performance indicators
-- (Australasian College for Emergency Medicine).
INSERT INTO triage_categories (triage_id, triage_name, target_minutes, benchmark_pct) VALUES
    (0, 'All',           NULL, NULL),
    (1, 'Resuscitation',    0, 100),   -- seen immediately
    (2, 'Emergency',       10,  80),
    (3, 'Urgent',          30,  75),
    (4, 'Semi-urgent',     60,  70),
    (5, 'Non-urgent',     120,  70);

-- 4. Fact table ------------------------------------------------
-- 'Jul 2023' is turned into a real date '2023-07-01' so we can sort
-- and use date functions. Blank values become NULL (not 0!).
INSERT INTO ed_performance
    (hospital_id, measure_id, triage_id, month_start, financial_year,
     monthly_value, fytd_value)
SELECT
    h.hospital_id,
    m.measure_id,
    t.triage_id,
    substr(r.time_period, 5, 4) || '-' ||
        CASE substr(r.time_period, 1, 3)
            WHEN 'Jan' THEN '01' WHEN 'Feb' THEN '02' WHEN 'Mar' THEN '03'
            WHEN 'Apr' THEN '04' WHEN 'May' THEN '05' WHEN 'Jun' THEN '06'
            WHEN 'Jul' THEN '07' WHEN 'Aug' THEN '08' WHEN 'Sep' THEN '09'
            WHEN 'Oct' THEN '10' WHEN 'Nov' THEN '11' WHEN 'Dec' THEN '12'
        END || '-01',
    r.financial_year,
    CAST(NULLIF(r.monthly_outcome, '') AS REAL),
    CAST(NULLIF(r.fytd_outcome, '')    AS REAL)
FROM raw_ed_performance r
JOIN hospitals         h ON h.hospital_name = r.location
JOIN measures          m ON m.measure_name  = r.measure
JOIN triage_categories t ON t.triage_name   = r.triage_category;

-- Handy view: the fact table with readable names already joined in.
DROP VIEW IF EXISTS v_ed;
CREATE VIEW v_ed AS
SELECT
    h.hospital_name,
    m.short_name   AS measure,
    t.triage_id,
    t.triage_name,
    t.benchmark_pct,
    p.month_start,
    p.financial_year,
    p.monthly_value,
    p.fytd_value
FROM ed_performance p
JOIN hospitals         h USING (hospital_id)
JOIN measures          m USING (measure_id)
JOIN triage_categories t USING (triage_id);
