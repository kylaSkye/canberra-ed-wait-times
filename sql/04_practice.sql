-- =============================================================
-- 04_practice.sql
-- Practice questions. Try writing each query yourself first,
-- then check against the hint. Use the v_ed view to start.
-- =============================================================

-- EASY ---------------------------------------------------------
-- P1. List every row for Canberra Hospital in June 2026.
--     Hint: WHERE hospital_name = ... AND month_start = '2026-06-01'

-- P2. What was the highest monthly median wait time ever recorded
--     at any location? Which hospital and month?
--     Hint: ORDER BY monthly_value DESC LIMIT 1

-- P3. How many rows are there for each measure?
--     Hint: GROUP BY measure

-- MEDIUM -------------------------------------------------------
-- P4. For each hospital, what is the average monthly % "did not wait"?
--     Which hospital loses more patients before they are seen?

-- P5. In how many months was the ACT median wait 30 minutes or more?

-- P6. For 2025-26, show the % seen on time for each triage category
--     side by side for both hospitals (one row per triage category).
--     Hint: copy the pivot pattern from Q2 in 03_analysis.sql

-- HARD ---------------------------------------------------------
-- P7. For each hospital, find the single month with the biggest jump
--     in median wait compared with the month before.
--     Hint: LAG() OVER (PARTITION BY hospital_name ORDER BY month_start)

-- P8. Rank the two hospitals each month on % seen on time. In how many
--     months did North Canberra Hospital come first?
--     Hint: RANK() OVER (PARTITION BY month_start ORDER BY ...)
