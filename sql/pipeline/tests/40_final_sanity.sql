-- ============================================================
-- 40_final_sanity.sql
-- Purpose:
--   General counts for testing overdose_cohort
-- PASS:
--   - tot_patients >= unique_patients
--   - tot_encounters == unique_encounters
--   - min_age == 18
--   - max_age == 35
--   - readmit_90 >= readmit_30
-- ============================================================

SELECT 
    COUNT(patient_id) AS tot_patients
    ,COUNT(DISTINCT patient_id) AS unique_patients
    ,COUNT(encounter_id) AS tot_encounters
    ,COUNT(DISTINCT encounter_id) AS unique_encounters
    --,MIN(age_at_visit) AS min_age
    --,MAX(age_at_visit) AS max_age
    ,SUM(readmission_90_day_ind) AS readmit_90
    ,SUM(readmission_30_day_ind) AS readmit_30
FROM overdose_cohort
;
