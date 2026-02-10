WITH expected AS (
	SELECT COUNT(*) AS expected_count
	FROM encounters
	INNER JOIN patients
		ON patients.id = encounters.patient
	WHERE 1 = 1
		AND encounters.reasondescription = 'Drug overdose'
		AND encounters.start > DATE '1999-07-15'
		AND DATE_DIFF('year', patients.birthdate, encounters.start) BETWEEN 18 AND 35
)
,actual AS (
	SELECT COUNT(*) AS actual_count
	FROM drug_overdose_cohort
)
SELECT
	expected.expected_count
	,actual.actual_count
FROM expected
CROSS JOIN actual
WHERE expected.expected_count <> actual.actual_count;
