-- ==============================================================================
-- 10_no_literal_NA_after_casting.sql
-- Purpose:
--   Ensure the literal string 'NA' is not leaking through after ingestion + casting.
--
-- Pass condition:
--   Query returns 0 rows.
-- ==============================================================================

WITH na_violations AS (

    -- ----------------------------
    -- encounters TEMP VIEW
    -- ----------------------------
    SELECT
        'encounters' AS table_name
        ,'patient_id' AS column_name
        ,COUNT(*) AS na_row_count
    FROM encounters
    WHERE LOWER(TRIM(CAST(patient_id AS VARCHAR))) = 'na'

    UNION ALL
    SELECT
        'encounters'
        ,'encounter_id'
        ,COUNT(*)
    FROM encounters
    WHERE LOWER(TRIM(CAST(encounter_id AS VARCHAR))) = 'na'

    UNION ALL
    SELECT
        'encounters'
        ,'encounter_code'
        ,COUNT(*)
    FROM encounters
    WHERE encounter_code IS NOT NULL
        AND LOWER(TRIM(CAST(encounter_code AS VARCHAR))) = 'na'

    UNION ALL
    SELECT
        'encounters'
        ,'encounter_description'
        ,COUNT(*)
    FROM encounters
    WHERE encounter_description IS NOT NULL
        AND LOWER(TRIM(CAST(encounter_description AS VARCHAR))) = 'na'

    UNION ALL
    SELECT
        'encounters'
        ,'encounter_start_timestamp'
        ,COUNT(*)
    FROM encounters
    WHERE encounter_start_timestamp IS NOT NULL
        AND LOWER(TRIM(CAST(encounter_start_timestamp AS VARCHAR))) = 'na'

    UNION ALL
    SELECT
        'encounters'
        ,'encounter_stop_timestamp'
        ,COUNT(*)
    FROM encounters
    WHERE encounter_stop_timestamp IS NOT NULL
        AND LOWER(TRIM(CAST(encounter_stop_timestamp AS VARCHAR))) = 'na'

    UNION ALL
    SELECT
        'encounters'
        ,'encounter_reason'
        ,COUNT(*)
    FROM encounters
    WHERE encounter_reason IS NOT NULL
        AND LOWER(TRIM(CAST(encounter_reason AS VARCHAR))) = 'na'

    -- ----------------------------
    -- medications TEMP VIEW
    -- ----------------------------
    UNION ALL
    SELECT
        'medications'
        ,'patient_id'
        ,COUNT(*)
    FROM medications
    WHERE LOWER(TRIM(CAST(patient_id AS VARCHAR))) = 'na'

    UNION ALL
    SELECT
        'medications'
        ,'encounter_id'
        ,COUNT(*)
    FROM medications
    WHERE LOWER(TRIM(CAST(encounter_id AS VARCHAR))) = 'na'

    UNION ALL
    SELECT
        'medications'
        ,'medication_code'
        ,COUNT(*)
    FROM medications
    WHERE medication_code IS NOT NULL
        AND LOWER(TRIM(CAST(medication_code AS VARCHAR))) = 'na'

    UNION ALL
    SELECT
        'medications'
        ,'medication_description'
        ,COUNT(*)
    FROM medications
    WHERE medication_description IS NOT NULL
        AND LOWER(TRIM(CAST(medication_description AS VARCHAR))) = 'na'

    UNION ALL
    SELECT
        'medications'
        ,'medication_start_date'
        ,COUNT(*)
    FROM medications
    WHERE medication_start_date IS NOT NULL
        AND LOWER(TRIM(CAST(medication_start_date AS VARCHAR))) = 'na'

    UNION ALL
    SELECT
        'medications'
        ,'medication_stop_date'
        ,COUNT(*)
    FROM medications
    WHERE medication_stop_date IS NOT NULL
        AND LOWER(TRIM(CAST(medication_stop_date AS VARCHAR))) = 'na'


    -- ----------------------------
    -- patients TEMP VIEW
    -- ----------------------------
    UNION ALL
    SELECT
        'patients'
        ,'patient_id'
        ,COUNT(*)
    FROM patients
    WHERE LOWER(TRIM(CAST(patient_id AS VARCHAR))) = 'na'

    UNION ALL
    SELECT
        'patients'
        ,'birthdate'
        ,COUNT(*)
    FROM patients
    WHERE LOWER(TRIM(CAST(birthdate AS VARCHAR))) = 'na'	

    UNION ALL
    SELECT
        'patients'
        ,'deathdate'
        ,COUNT(*)
    FROM patients
    WHERE LOWER(TRIM(CAST(deathdate AS VARCHAR))) = 'na'

    -- ----------------------------
    -- overdose_cohort TEMP VIEW (if present in session)
    -- ----------------------------
    UNION ALL
    SELECT
        'overdose_cohort'
        ,'patient_id'
        ,COUNT(*)
    FROM overdose_cohort
    WHERE LOWER(TRIM(CAST(patient_id AS VARCHAR))) = 'na'

    UNION ALL
    SELECT
        'overdose_cohort'
        ,'encounter_id'
        ,COUNT(*)
    FROM overdose_cohort
    WHERE LOWER(TRIM(CAST(encounter_id AS VARCHAR))) = 'na'

)

SELECT
    table_name
    ,column_name
    ,na_row_count
FROM na_violations
WHERE na_row_count > 0
ORDER BY
    na_row_count DESC
    ,table_name
    ,column_name
;
