-- ============================================================
-- 20_build_cohort.sql
-- Purpose:
--   Build an analysis-ready cohort of drug overdose hospital encounters.
--
-- Cohort criteria:
--   - encounters.reasondescription = 'Drug overdose'
--   - encounter start date > 1999-07-15
--   - age at encounter between 18 and 35 (inclusive)
--
-- Metrics produced (one row per patient_id + encounter_id):
--   - death_at_visit_ind
--   - count_current_meds
--   - current_opioid_ind
--   - readmission_90_day_ind
--   - readmission_30_day_ind
--   - first_readmission_date
--
-- Output:
--   Final SELECT returning the cohort at patient_id + encounter_id grain
--
-- Notes:
--   - Requires 10_normalize_sources.sql to be executed first
--     (encounters, medications, patients TEMP VIEWs must exist)
-- ============================================================

-- Define qualifying_encounters
--   - filter encounters to drug overdose + date threshold
CREATE OR REPLACE TEMP VIEW overdose_cohort AS

WITH qualifying_encounters AS (
    SELECT
        encounters.patient AS patient_id
        ,encounters.id AS encounter_id
        ,encounters.start_timestamp AS hospital_encounter_timestamp
        ,encounters.stop_timestamp AS encounter_end_timestamp
        ,encounters.description
    FROM encounters
    WHERE 1 = 1
        AND encounters.reasondescription = 'Drug overdose'
        AND encounters.start_timestamp > TIMESTAMP '1999-07-15'
    --    AND encounters.stop_timestamp is null
)

-- Define cohort
--   - join patients
--   - compute age_at_visit
--   - apply age filter
,cohort AS (
    SELECT
        qualifying_encounters.patient_id
        ,qualifying_encounters.encounter_id
        ,qualifying_encounters.hospital_encounter_timestamp
        ,qualifying_encounters.encounter_end_timestamp
        
        -- this previous calculation is incorrect as it only give full-year date differences and will result in inaccurate ages        
        -- ,DATE_DIFF(
        --     'year'
        --     , patients.birthdate
        --     ,qualifying_encounters.hospital_encounter_timestamp
        --     ) 
        --     AS age_at_visit

        ,(
            EXTRACT(YEAR FROM qualifying_encounters.hospital_encounter_timestamp)
            - EXTRACT(YEAR FROM patients.birthdate)
            - CASE
                WHEN
                    EXTRACT(MONTH FROM qualifying_encounters.hospital_encounter_timestamp)
                        < EXTRACT(MONTH FROM patients.birthdate)
                    OR (
                        EXTRACT(MONTH FROM qualifying_encounters.hospital_encounter_timestamp)
                            = EXTRACT(MONTH FROM patients.birthdate)
                        AND EXTRACT(DAY FROM qualifying_encounters.hospital_encounter_timestamp)
                            < EXTRACT(DAY FROM patients.birthdate)
                    )
                THEN 1
                ELSE 0
            END
        ) AS age_at_visit

        ,patients.birthdate
        ,patients.deathdate
        ,qualifying_encounters.description

    FROM qualifying_encounters
    INNER JOIN patients
        ON patients.id = qualifying_encounters.patient_id
    WHERE 1 = 1
        -- old age filer, do not use:
        -- AND DATE_DIFF('year', patients.birthdate, qualifying_encounters.hospital_encounter_timestamp) BETWEEN 18 AND 35
        AND (
            EXTRACT(YEAR FROM qualifying_encounters.hospital_encounter_timestamp)
            - EXTRACT(YEAR FROM patients.birthdate)
            - CASE
                WHEN
                    EXTRACT(MONTH FROM qualifying_encounters.hospital_encounter_timestamp) < EXTRACT(MONTH FROM patients.birthdate)
                    OR (
                        EXTRACT(MONTH FROM qualifying_encounters.hospital_encounter_timestamp) = EXTRACT(MONTH FROM patients.birthdate)
                        AND EXTRACT(DAY FROM qualifying_encounters.hospital_encounter_timestamp) < EXTRACT(DAY FROM patients.birthdate)
                    )
                THEN 1
                ELSE 0
                END
        ) BETWEEN 18 AND 35

)

-- Define current_meds
--   - medications active at encounter start
,current_meds AS (
    SELECT
        cohort.patient_id
        ,cohort.encounter_id
        ,cohort.hospital_encounter_timestamp
        ,medications.code AS medication_code
        ,medications.description AS medication_description
        ,medications.start AS medication_start_date
        ,medications.stop AS medication_stop_date
    FROM medications
    INNER JOIN cohort
        ON medications.patient = cohort.patient_id
    WHERE 1 = 1
        AND medications.start < cohort.hospital_encounter_timestamp
        AND (
            medications.stop IS NULL
        OR  medications.stop >= cohort.hospital_encounter_timestamp
    )
)
-- meds count per encounter
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
--   - subset of current_meds matching opioid tokens
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
-- opioid flag per encounter
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
-- Define readmissions
--   - first overdose readmission within 90 days
,readmissions AS (
    SELECT
        first_encounter.patient_id
        ,first_encounter.encounter_id AS first_encounter_id
        ,first_encounter.hospital_encounter_timestamp AS first_encounter_timestamp
        ,MIN(readmit.hospital_encounter_timestamp) AS first_readmission_timestamp
    FROM cohort first_encounter
     INNER JOIN cohort readmit
         ON first_encounter.patient_id = readmit.patient_id
        AND readmit.hospital_encounter_timestamp > first_encounter.encounter_end_timestamp
        AND readmit.hospital_encounter_timestamp
            <= CAST(first_encounter.encounter_end_timestamp + INTERVAL '90 days' AS TIMESTAMP)
    GROUP BY
        first_encounter.patient_id
        ,first_encounter.encounter_id
        ,first_encounter.hospital_encounter_timestamp
)
-- select count(*), count(distinct first_encounter_id) from readmissions;
-- select * from readmissions;


-- Final normalization (as CTE)
--   - aggregate to one row per patient_id + encounter_id
--   - compute indicator and count columns
,cohort_final AS (
    
    SELECT
        cohort.patient_id
        ,cohort.encounter_id
        ,cohort.hospital_encounter_timestamp
        ,cohort.encounter_end_timestamp
        ,cohort.age_at_visit
        
        ,CASE
            WHEN cohort.deathdate IS NULL THEN 0
            WHEN cohort.deathdate BETWEEN cohort.hospital_encounter_timestamp AND cohort.encounter_end_timestamp THEN 1
            WHEN cohort.deathdate = CAST(cohort.encounter_end_timestamp AS DATE) THEN 1
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
                <= CAST(cohort.hospital_encounter_timestamp + INTERVAL '30 days' AS TIMESTAMP)
            THEN 1
            ELSE 0
        END AS readmission_30_day_ind

        ,CASE
            WHEN readmissions.first_readmission_timestamp IS NULL THEN NULL
            ELSE readmissions.first_readmission_timestamp
        END AS first_readmission_timestamp

        ,cohort.description

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

    -- GROUP BY 
    --     cohort.patient_id
    --     ,cohort.encounter_id
    --     ,cohort.hospital_encounter_date
    --     ,cohort.hospital_encounter_timestamp
    --     ,cohort.age_at_visit
    --     ,cohort.deathdate
    --     ,cohort.hospital_encounter_timestamp
    --     ,current_opioids.opioid_code
    --     ,readmissions.first_readmission_timestamp
    
    ORDER BY
        cohort.hospital_encounter_timestamp ASC
    )

-- Final SELECT that defines TEMP VIEW cohort_output
-- (the TEMP VIEW is created by the CREATE OR REPLACE statement above)
SELECT * FROM cohort_final;


-- ------------------------------------------------------------------
-- Interactive inspection
-- ------------------------------------------------------------------
-- SELECT count(*) FROM overdose_cohort;
