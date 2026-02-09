-- ../02_base_cohort.sql must be run before this test to create TEMP VIEW cohort_output

WITH encounters_per_patient AS (
	SELECT
		patient_id
		,COUNT(DISTINCT encounter_id) AS encounter_count
	FROM cohort_output
	GROUP BY
		patient_id
)

SELECT
	encounter_count
	,COUNT(*) AS patient_count
FROM encounters_per_patient
GROUP BY
	encounter_count
ORDER BY
	encounter_count DESC
;