-- ============================================================
-- 20_build_cohort.sql
-- Purpose:
--   Build an analysis-ready cohort of drug overdose hospital encounters.
--
-- Cohort criteria:
--   - encounters.reasondescription = 'Drug overdose' (Validated in tests: no qualifying overdose encounters have NULL encounter_reason)
--   - encounter start date > 1999-07-15
--   - age at encounter between 18 and 35 (inclusive)
--
-- Metrics produced (one row per patient_id + encounter_id):
--   - death_at_visit_ind (0/1)
--   - count_current_meds (active at start of encounter)
--   - current_opioid_ind (0/1) (if any opioids active at start of encounter)
--   - readmission_90_day_ind + ensure readmissions after age 35 are counted (0/1)
--   - readmission_30_day_ind + ensure readmissions after age 35 are counted (0/1)
--   - first_readmission_date + ensure readmissions after age 35 are counted
--
-- Output:
--   Final SELECT returning the cohort at patient_id + encounter_id grain
--
-- Notes:
--   - Requires 10_normalize_sources.sql to be executed first
--     (encounters, medications, patients TEMP VIEWs must exist)
-- ============================================================

CREATE OR REPLACE TEMP VIEW overdose_cohort AS
-- Define qualifying_encounters: 1 row per encounter_id (after dedupe)
--   - filter encounters to drug overdose + date threshold
--   - these are not yet filtered by patient age
WITH qualifying_encounters AS (
    SELECT DISTINCT
        encounters.patient_id
        ,encounters.encounter_id
        ,encounters.encounter_start_timestamp
        ,encounters.encounter_stop_timestamp
        ,encounters.encounter_description
    FROM encounters
    WHERE 1 = 1
        AND encounters.encounter_reason = 'Drug overdose'
        AND encounters.encounter_start_timestamp >= TIMESTAMP '1999-07-16 00:00:00' -- AFTER 7/15
)
-- Define patient_age_at_visit: 1 row per patient_id + encounter_id
--   - join patients
--   - compute age_at_visit here so that the complex calculation can live in its own CTE and be used downstream
,patient_age_at_visit AS (
    SELECT
        qualifying_encounters.patient_id
        ,qualifying_encounters.encounter_id
        ,qualifying_encounters.encounter_start_timestamp
        ,qualifying_encounters.encounter_stop_timestamp
        -- do not use DATE_DIFF for age computations bc it does not have granularity down to the day and ages will be incorrect
        ,(
            EXTRACT(YEAR FROM qualifying_encounters.encounter_start_timestamp)
            - EXTRACT(YEAR FROM patients.birthdate)
            - CASE
                WHEN
                    EXTRACT(MONTH FROM qualifying_encounters.encounter_start_timestamp)
                        < EXTRACT(MONTH FROM patients.birthdate)
                    OR (
                        EXTRACT(MONTH FROM qualifying_encounters.encounter_start_timestamp)
                            = EXTRACT(MONTH FROM patients.birthdate)
                        AND EXTRACT(DAY FROM qualifying_encounters.encounter_start_timestamp)
                            < EXTRACT(DAY FROM patients.birthdate)
                    )
                THEN 1
                ELSE 0
            END
        ) AS age_at_visit
        
        ,patients.birthdate
        ,patients.deathdate
        ,qualifying_encounters.encounter_description

    FROM qualifying_encounters
    INNER JOIN patients
        ON patients.patient_id = qualifying_encounters.patient_id
   
)
-- Define all_patients: 1 row per patient_id + encounter_id (index encounters only)
--   - This returns all patients age 18 or above, which also appear in qualifying encounters
--   - Note: we only filter for age > 18, as we will need ages above the cohort age filter for readmissions (specifically age 36)
,all_patients AS (
    SELECT DISTINCT
        qualifying_encounters.patient_id
        ,qualifying_encounters.encounter_id
        ,qualifying_encounters.encounter_start_timestamp
        ,qualifying_encounters.encounter_stop_timestamp
        ,patient_age_at_visit.age_at_visit
        ,patient_age_at_visit.birthdate
        ,patient_age_at_visit.deathdate
        ,qualifying_encounters.encounter_description

    FROM qualifying_encounters
    INNER JOIN patient_age_at_visit
        ON qualifying_encounters.patient_id = patient_age_at_visit.patient_id
        AND qualifying_encounters.encounter_id = patient_age_at_visit.encounter_id

    WHERE 1 = 1
        AND patient_age_at_visit.age_at_visit >= 18
)
-- Define cohort: 1 row per patient_id + encounter_id (index encounters only)
--   - This includes all patients age 18-35 at time of first qualifying encounter
,cohort AS (
    SELECT
        all_patients.patient_id
        ,all_patients.encounter_id
        ,all_patients.encounter_start_timestamp
        ,all_patients.encounter_stop_timestamp
        ,all_patients.age_at_visit
        ,all_patients.birthdate
        ,all_patients.deathdate
        ,all_patients.encounter_description
    FROM all_patients
    WHERE 1=1
        AND all_patients.age_at_visit BETWEEN 18 AND 35
)
-- Define current_meds
--   - medications active at encounter start
,current_meds AS (
    SELECT
        cohort.patient_id
        ,cohort.encounter_id
        ,cohort.encounter_start_timestamp
        ,medications.medication_code
        ,medications.medication_description
        ,medications.medication_start_date
        ,medications.medication_stop_date
    FROM medications
    INNER JOIN cohort
        ON medications.patient_id = cohort.patient_id
    WHERE 1 = 1
        AND medications.medication_start_date < CAST(cohort.encounter_start_timestamp AS DATE)
        AND (
            medications.medication_stop_date IS NULL
        OR  medications.medication_stop_date >= CAST(cohort.encounter_start_timestamp AS DATE)
    )
)
-- Count of medications active at start of each specific encounter
,current_meds_agg AS (
    SELECT
        current_meds.patient_id
        ,current_meds.encounter_id
        ,COUNT(
            DISTINCT CAST(current_meds.medication_code AS VARCHAR)
            || '|' || CAST(current_meds.medication_start_date AS VARCHAR)
        ) AS count_current_meds
    FROM current_meds
    GROUP BY
        current_meds.patient_id
        ,current_meds.encounter_id
)
-- Define opioids_list
--   - keyword/token list for opioid identification
,opioids_list AS (
    SELECT *
    FROM (VALUES
        ('hydromorphone')
        ,('fentanyl')
        ,('oxycodone-acetaminophen')
    ) AS opioids(opioid_token)
)
-- Define current_opioids
--   - Subset of current_meds matching opioid tokens above
,current_opioids AS (
    SELECT DISTINCT
        current_meds.patient_id
        ,current_meds.encounter_id
        ,current_meds.medication_code AS opioid_code
        ,current_meds.medication_description
        ,current_meds.medication_start_date
        ,current_meds.medication_stop_date
    FROM current_meds 
    INNER JOIN opioids_list
        ON LOWER(current_meds.medication_description)
            LIKE '%' || opioids_list.opioid_token || '%'
)
-- Opioid flag per encounter
--   - Flags each patient only if one of the active meds at encounter start was an opioid (as defined in opioids_list)
,current_opioids_agg AS (
    SELECT
        current_opioids.patient_id
        ,current_opioids.encounter_id
        ,1 AS current_opioid_ind
    FROM current_opioids
    GROUP BY
        current_opioids.patient_id
        ,current_opioids.encounter_id
)

-- Define readmissions: 1 row per patient_id + first_encounter_id (index encounter grain)
--   -> Finds first overdose readmission within 90 days
--   - Join all_patients in readmissions in case a patient turned 36 after their first encounter
--   - Counts may exceed distinct patients when a patient has multiple qualifying index encounters
--   - DuckDB implementation uses ARG_MIN to return the encounter_id associated with the earliest readmission timestamp
--   - This syntax is more concise than sorting by row number (requires 2-3 CTEs) which would be necessary for other SQL engines
,readmissions AS (
	SELECT
		cohort.patient_id
		,cohort.encounter_id AS first_encounter_id
		,cohort.encounter_start_timestamp AS first_encounter_timestamp
		,ARG_MIN(all_patients.encounter_id, all_patients.encounter_start_timestamp) AS first_readmission_id
		,MIN(all_patients.encounter_start_timestamp) AS first_readmission_timestamp

		,cohort.age_at_visit AS first_encounter_age
		,ARG_MIN(all_patients.age_at_visit, all_patients.encounter_start_timestamp) AS first_readmission_age
		,MAX(all_patients.age_at_visit) AS last_readmission_age
	FROM cohort
	INNER JOIN all_patients
		ON all_patients.patient_id = cohort.patient_id
		AND all_patients.encounter_start_timestamp > cohort.encounter_stop_timestamp
		AND all_patients.encounter_start_timestamp <= cohort.encounter_stop_timestamp + INTERVAL '90 days'
	GROUP BY
		cohort.patient_id
		,cohort.encounter_id
		,cohort.encounter_start_timestamp
		,cohort.age_at_visit
)

-- Final normalization (as CTE)
--   - Aggregate to one row per patient_id + encounter_id
--   - Compute indicator and count columns
,cohort_final AS (
    
    SELECT
        cohort.patient_id
        ,cohort.encounter_id
        ,cohort.encounter_start_timestamp AS hospital_encounter_timestamp
        ,cohort.encounter_stop_timestamp
        ,cohort.age_at_visit
        
        ,CASE
            WHEN cohort.deathdate IS NULL THEN 0
            WHEN cohort.deathdate BETWEEN CAST(cohort.encounter_start_timestamp AS DATE) AND CAST(cohort.encounter_stop_timestamp AS DATE) THEN 1
            ELSE 0
        END AS death_at_visit_ind

        ,COALESCE(current_meds_agg.count_current_meds, 0) AS count_current_meds

        ,COALESCE(current_opioids_agg.current_opioid_ind, 0) AS current_opioid_ind

        ,CASE
            WHEN readmissions.first_readmission_timestamp IS NULL THEN 0
            ELSE 1
        END AS readmission_90_day_ind

        ,CASE
            WHEN readmissions.first_readmission_timestamp IS NULL THEN 0
            WHEN readmissions.first_readmission_timestamp
                <= CAST(cohort.encounter_start_timestamp + INTERVAL '30 days' AS TIMESTAMP)
            THEN 1
            ELSE 0
        END AS readmission_30_day_ind

        ,CASE
            WHEN readmissions.first_readmission_timestamp IS NULL THEN NULL
            ELSE readmissions.first_readmission_timestamp
        END AS first_readmission_timestamp

    FROM
        cohort
    -- edit to joins to properly deduplicate rather than exploding rows by directly joining current_meds and current_opioids
    LEFT JOIN current_meds_agg
        ON current_meds_agg.patient_id = cohort.patient_id
        AND current_meds_agg.encounter_id = cohort.encounter_id
    LEFT JOIN current_opioids_agg
        ON current_opioids_agg.patient_id = cohort.patient_id
        AND current_opioids_agg.encounter_id = cohort.encounter_id
    LEFT JOIN readmissions
        ON readmissions.patient_id = cohort.patient_id
        AND readmissions.first_encounter_id = cohort.encounter_id
)

-- Final SELECT that defines TEMP VIEW cohort_output
SELECT * FROM cohort_final;