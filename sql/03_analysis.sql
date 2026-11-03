-- =============================================================
-- 03_analysis.sql
-- Policy questions about Canberra's emergency departments.
-- Each query starts with "-- name: <name>" so run_analysis.py can
-- run it and save the result to results/<name>.csv.
-- =============================================================


-- name: q1_yearly_overview
-- Q1. Is the ACT getting better or worse, year by year?
-- The June "financial-year-to-date" value is the full-year result.
-- Skills: WHERE on dates, conditional aggregation (pivot), ROUND
SELECT
    financial_year,
    MAX(CASE WHEN measure = 'median_wait_min'  THEN fytd_value END) AS median_wait_min,
    MAX(CASE WHEN measure = 'pct_on_time'      THEN fytd_value END) AS pct_seen_on_time,
    MAX(CASE WHEN measure = 'pct_4hr'          THEN fytd_value END) AS pct_left_within_4hr,
    MAX(CASE WHEN measure = 'pct_did_not_wait' THEN fytd_value END) AS pct_did_not_wait
FROM v_ed
WHERE hospital_name = 'ACT'
  AND triage_name   = 'All'
  AND strftime('%m', month_start) = '06'
GROUP BY financial_year
ORDER BY financial_year;


-- name: q2_hospital_comparison
-- Q2. Which hospital performs worse? (latest full year)
-- Skills: subquery, pivot by hospital, calculated difference
SELECT
    measure,
    MAX(CASE WHEN hospital_name = 'Canberra Hospital'       THEN fytd_value END) AS canberra_hospital,
    MAX(CASE WHEN hospital_name = 'North Canberra Hospital' THEN fytd_value END) AS north_canberra_hospital,
    ROUND(
        MAX(CASE WHEN hospital_name = 'Canberra Hospital'       THEN fytd_value END)
      - MAX(CASE WHEN hospital_name = 'North Canberra Hospital' THEN fytd_value END), 1
    ) AS difference
FROM v_ed
WHERE triage_name = 'All'
  AND month_start = (SELECT MAX(month_start) FROM ed_performance)
GROUP BY measure
ORDER BY measure;


-- name: q3_triage_vs_benchmark
-- Q3. Which triage categories miss the national benchmark, and by how much?
-- Uses the latest full year for the ACT.
-- Skills: JOIN to a lookup table, calculated gap, CASE label
SELECT
    triage_id,
    triage_name,
    benchmark_pct,
    fytd_value                                   AS actual_pct,
    ROUND(fytd_value - benchmark_pct, 1)         AS gap_pct_points,
    CASE WHEN fytd_value >= benchmark_pct THEN 'Met' ELSE 'Missed' END AS result
FROM v_ed
WHERE hospital_name = 'ACT'
  AND measure       = 'pct_on_time'
  AND triage_id    <> 0
  AND month_start   = (SELECT MAX(month_start) FROM ed_performance)
ORDER BY triage_id;


-- name: q4_months_meeting_benchmark
-- Q4. Out of every month on record, how often did each hospital meet the
-- benchmark for each triage category?
-- Skills: GROUP BY two columns, SUM(CASE ...) counting, percentage
SELECT
    hospital_name,
    triage_name,
    benchmark_pct,
    COUNT(monthly_value)                                             AS months_reported,
    SUM(CASE WHEN monthly_value >= benchmark_pct THEN 1 ELSE 0 END)  AS months_met,
    ROUND(100.0 * SUM(CASE WHEN monthly_value >= benchmark_pct THEN 1 ELSE 0 END)
          / COUNT(monthly_value), 0)                                 AS pct_months_met
FROM v_ed
WHERE measure     = 'pct_on_time'
  AND triage_id  <> 0
  AND hospital_name <> 'ACT'
GROUP BY hospital_name, triage_id
ORDER BY hospital_name, triage_id;


-- name: q5_worst_months
-- Q5. The 3 worst months for median wait time in each financial year (ACT).
-- Skills: window function RANK() OVER (PARTITION BY ...), CTE
WITH ranked AS (
    SELECT
        financial_year,
        month_start,
        monthly_value AS median_wait_min,
        RANK() OVER (PARTITION BY financial_year
                     ORDER BY monthly_value DESC) AS worst_rank
    FROM v_ed
    WHERE hospital_name = 'ACT'
      AND triage_name   = 'All'
      AND measure       = 'median_wait_min'
)
SELECT financial_year, worst_rank, month_start, median_wait_min
FROM ranked
WHERE worst_rank <= 3
ORDER BY financial_year, worst_rank;


-- name: q6_rolling_trend
-- Q6. Monthly trend with a 12-month rolling average and change vs the
-- same month last year (ACT, % seen on time).
-- Skills: AVG() OVER a sliding window, LAG()
SELECT
    month_start,
    monthly_value AS pct_on_time,
    ROUND(AVG(monthly_value) OVER (ORDER BY month_start
                                   ROWS BETWEEN 11 PRECEDING AND CURRENT ROW), 1)
        AS rolling_12m_avg,
    ROUND(monthly_value - LAG(monthly_value, 12) OVER (ORDER BY month_start), 1)
        AS change_vs_last_year
FROM v_ed
WHERE hospital_name = 'ACT'
  AND triage_name   = 'All'
  AND measure       = 'pct_on_time'
ORDER BY month_start;


-- name: q7_seasonality
-- Q7. Are some months of the year worse? (e.g. winter flu season)
-- Average across all years, ACT, all triage categories.
-- Skills: date functions, GROUP BY a derived column
SELECT
    strftime('%m', month_start)                                        AS month_num,
    ROUND(AVG(CASE WHEN measure = 'median_wait_min' THEN monthly_value END), 1) AS avg_median_wait_min,
    ROUND(AVG(CASE WHEN measure = 'pct_on_time'     THEN monthly_value END), 1) AS avg_pct_on_time,
    ROUND(AVG(CASE WHEN measure = 'pct_4hr'         THEN monthly_value END), 1) AS avg_pct_4hr
FROM v_ed
WHERE hospital_name = 'ACT'
  AND triage_name   = 'All'
GROUP BY month_num
ORDER BY avg_median_wait_min DESC;


-- name: q8_admitted_vs_not
-- Q8. Who gets stuck in the ED: patients being admitted to a ward, or
-- patients going home? (% leaving within 4 hours, full-year results)
-- Skills: pivot, filtering on a list with IN
SELECT
    hospital_name,
    financial_year,
    MAX(CASE WHEN measure = 'pct_4hr_admitted'     THEN fytd_value END) AS admitted_pct_4hr,
    MAX(CASE WHEN measure = 'pct_4hr_not_admitted' THEN fytd_value END) AS not_admitted_pct_4hr
FROM v_ed
WHERE triage_name = 'All'
  AND measure IN ('pct_4hr_admitted', 'pct_4hr_not_admitted')
  AND strftime('%m', month_start) = '06'
GROUP BY hospital_name, financial_year
ORDER BY hospital_name, financial_year;


-- name: q9_data_quality
-- Q9. Data quality check: which series have missing months or blank values?
-- (Always check this before trusting results.)
-- Skills: HAVING, COUNT(*) vs COUNT(column)
SELECT
    hospital_name,
    measure,
    triage_name,
    COUNT(*)              AS months_present,
    COUNT(monthly_value)  AS months_with_value,
    (SELECT COUNT(DISTINCT month_start) FROM ed_performance) AS months_expected
FROM v_ed
GROUP BY hospital_name, measure, triage_name
HAVING COUNT(monthly_value) < (SELECT COUNT(DISTINCT month_start) FROM ed_performance);
