-- ============================================================
-- 10_schema.sql
-- Purpose:
--   Sanity-check expected columns exist and are selectable.

-- PASS condition:
--   Queries run without error and return 0 failing rows.
-- ============================================================

-- 1) Column existence smoke test (will error if missing)
WITH _smoke AS (
    SELECT
        overdose_cohort.patient_id
        ,overdose_cohort.encounter_id
        ,overdose_cohort.encounter_start_timestamp
        ,overdose_cohort.age_at_visit
        ,overdose_cohort.death_at_visit_ind
        ,overdose_cohort.count_current_meds
        ,overdose_cohort.current_opioid_ind
        ,overdose_cohort.readmission_90_day_ind
        ,overdose_cohort.readmission_30_day_ind
        ,overdose_cohort.first_readmission_timestamp
    FROM overdose_cohort
    LIMIT 1
)
SELECT
    *
FROM _smoke
WHERE 1 = 0;
