-- Write final output to .CSV file:
COPY (
    SELECT
        patient_id                      AS PATIENT_ID
        ,encounter_id                   AS ENCOUNTER_ID
        ,encounter_start_timestamp      AS HOSPITAL_ENCOUNTER_DATE
        ,age_at_visit                   AS AGE_AT_VISIT
        ,death_at_visit_ind             AS DEATH_AT_VISIT_IND
        ,count_current_meds             AS COUNT_CURRENT_MEDS
        ,current_opioid_ind             AS CURRENT_OPIOID_IND
        ,readmission_90_day_ind         AS READMISSION_90_DAY_IND
        ,readmission_30_day_ind         AS READMISSION_30_DAY_IND
        ,COALESCE(
            CAST(first_readmission_timestamp AS VARCHAR)
        ,'N/A'
        )                               
        ,first_readmission_timestamp    AS FIRST_READMISSION_DATE
    FROM overdose_cohort
) TO '../../output/overdose_cohort.csv'
WITH (
    HEADER
    ,OVERWRITE TRUE
);