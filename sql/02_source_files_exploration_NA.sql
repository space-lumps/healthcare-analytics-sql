-----------------------------------------------------------------------
-- F) 'NA' (string) profiling
-----------------------------------------------------------------------
-- Goal: for each table, count values exactly equal to 'NA' (case-sensitive),
-- by column. Same shape as null profiling.
--
-- TODO: per-column 'NA' counts.
-- Notes:
-- - Only applies to VARCHAR columns; numeric/date columns may contain 'NA'
--   only if inferred as VARCHAR.

-----------------------------------------------------------------------
-- CREATE TEMP VIEWS WITH ALL COLUMNS CAST AS VARCHAR
-----------------------------------------------------------------------
CREATE OR REPLACE TEMP VIEW allergies_text AS
SELECT *
FROM read_csv('datasets/allergies.csv', ALL_VARCHAR = true);

CREATE OR REPLACE TEMP VIEW encounters_text AS
SELECT *
FROM read_csv('datasets/encounters.csv', ALL_VARCHAR = true);

CREATE OR REPLACE TEMP VIEW medications_text AS
SELECT *
FROM read_csv('datasets/medications.csv', ALL_VARCHAR = true);

CREATE OR REPLACE TEMP VIEW patients_text AS
SELECT *
FROM read_csv('datasets/patients.csv', ALL_VARCHAR = true);

CREATE OR REPLACE TEMP VIEW procedures_text AS
SELECT *
FROM read_csv('datasets/procedures.csv', ALL_VARCHAR = true);

-----------------------------------------------------------------------
-- ALLERGIES
-----------------------------------------------------------------------
SELECT
	'allergies' AS dataset
	, 'CODE' AS column_name
	, SUM(CASE WHEN "CODE" = 'NA' THEN 1 ELSE 0 END) AS na_count
FROM allergies_text

UNION ALL
SELECT
	'allergies'
	, 'DESCRIPTION'
	, SUM(CASE WHEN "DESCRIPTION" = 'NA' THEN 1 ELSE 0 END)
FROM allergies_text

UNION ALL
SELECT
	'allergies'
	, 'ENCOUNTER'
	, SUM(CASE WHEN "ENCOUNTER" = 'NA' THEN 1 ELSE 0 END)
FROM allergies_text

UNION ALL
SELECT
	'allergies'
	, 'PATIENT'
	, SUM(CASE WHEN "PATIENT" = 'NA' THEN 1 ELSE 0 END)
FROM allergies_text

UNION ALL
SELECT
	'allergies'
	, 'START'
	, SUM(CASE WHEN "START" = 'NA' THEN 1 ELSE 0 END)
FROM allergies_text

UNION ALL
SELECT
	'allergies'
	, 'STOP'
	, SUM(CASE WHEN "STOP" = 'NA' THEN 1 ELSE 0 END)
FROM allergies_text;
-----------------------------------------------------------------------
-- ENCOUNTERS
-----------------------------------------------------------------------
SELECT
	'encounters' AS dataset
	, 'CODE' AS column_name
	, SUM(CASE WHEN "CODE" = 'NA' THEN 1 ELSE 0 END) AS na_count
FROM encounters_text

UNION ALL
SELECT
	'encounters'
	, 'COST'
	, SUM(CASE WHEN "COST" = 'NA' THEN 1 ELSE 0 END)
FROM encounters_text

UNION ALL
SELECT
	'encounters'
	, 'DESCRIPTION'
	, SUM(CASE WHEN "DESCRIPTION" = 'NA' THEN 1 ELSE 0 END)
FROM encounters_text

UNION ALL
SELECT
	'encounters'
	, 'ENCOUNTERCLASS'
	, SUM(CASE WHEN "ENCOUNTERCLASS" = 'NA' THEN 1 ELSE 0 END)
FROM encounters_text

UNION ALL
SELECT
	'encounters'
	, 'Id'
	, SUM(CASE WHEN "Id" = 'NA' THEN 1 ELSE 0 END)
FROM encounters_text

UNION ALL
SELECT
	'encounters'
	, 'PATIENT'
	, SUM(CASE WHEN "PATIENT" = 'NA' THEN 1 ELSE 0 END)
FROM encounters_text

UNION ALL
SELECT
	'encounters'
	, 'PROVIDER'
	, SUM(CASE WHEN "PROVIDER" = 'NA' THEN 1 ELSE 0 END)
FROM encounters_text

UNION ALL
SELECT
	'encounters'
	, 'REASONCODE'
	, SUM(CASE WHEN "REASONCODE" = 'NA' THEN 1 ELSE 0 END)
FROM encounters_text

UNION ALL
SELECT
	'encounters'
	, 'REASONDESCRIPTION'
	, SUM(CASE WHEN "REASONDESCRIPTION" = 'NA' THEN 1 ELSE 0 END)
FROM encounters_text

UNION ALL
SELECT
	'encounters'
	, 'START'
	, SUM(CASE WHEN "START" = 'NA' THEN 1 ELSE 0 END)
FROM encounters_text

UNION ALL
SELECT
	'encounters'
	, 'STOP'
	, SUM(CASE WHEN "STOP" = 'NA' THEN 1 ELSE 0 END)
FROM encounters_text;

-----------------------------------------------------------------------
-- MEDICATIONS
-----------------------------------------------------------------------
SELECT
	'medications' AS dataset
	, 'CODE' AS column_name
	, SUM(CASE WHEN "CODE" = 'NA' THEN 1 ELSE 0 END) AS na_count
FROM medications_text

UNION ALL
SELECT
	'medications'
	, 'COST'
	, SUM(CASE WHEN "COST" = 'NA' THEN 1 ELSE 0 END)
FROM medications_text

UNION ALL
SELECT
	'medications'
	, 'DESCRIPTION'
	, SUM(CASE WHEN "DESCRIPTION" = 'NA' THEN 1 ELSE 0 END)
FROM medications_text

UNION ALL
SELECT
	'medications'
	, 'DISPENSES'
	, SUM(CASE WHEN "DISPENSES" = 'NA' THEN 1 ELSE 0 END)
FROM medications_text

UNION ALL
SELECT
	'medications'
	, 'ENCOUNTER'
	, SUM(CASE WHEN "ENCOUNTER" = 'NA' THEN 1 ELSE 0 END)
FROM medications_text

UNION ALL
SELECT
	'medications'
	, 'PATIENT'
	, SUM(CASE WHEN "PATIENT" = 'NA' THEN 1 ELSE 0 END)
FROM medications_text

UNION ALL
SELECT
	'medications'
	, 'REASONCODE'
	, SUM(CASE WHEN "REASONCODE" = 'NA' THEN 1 ELSE 0 END)
FROM medications_text

UNION ALL
SELECT
	'medications'
	, 'REASONDESCRIPTION'
	, SUM(CASE WHEN "REASONDESCRIPTION" = 'NA' THEN 1 ELSE 0 END)
FROM medications_text

UNION ALL
SELECT
	'medications'
	, 'START'
	, SUM(CASE WHEN "START" = 'NA' THEN 1 ELSE 0 END)
FROM medications_text

UNION ALL
SELECT
	'medications'
	, 'STOP'
	, SUM(CASE WHEN "STOP" = 'NA' THEN 1 ELSE 0 END)
FROM medications_text

UNION ALL
SELECT
	'medications'
	, 'TOTALCOST'
	, SUM(CASE WHEN "TOTALCOST" = 'NA' THEN 1 ELSE 0 END)
FROM medications_text;

-----------------------------------------------------------------------
-- PATIENTS
-----------------------------------------------------------------------
SELECT
	'patients' AS dataset
	, 'ADDRESS' AS column_name
	, SUM(CASE WHEN "ADDRESS" = 'NA' THEN 1 ELSE 0 END) AS na_count
FROM patients_text

UNION ALL
SELECT
	'patients'
	, 'BIRTHDATE'
	, SUM(CASE WHEN "BIRTHDATE" = 'NA' THEN 1 ELSE 0 END)
FROM patients_text

UNION ALL
SELECT
	'patients'
	, 'BIRTHPLACE'
	, SUM(CASE WHEN "BIRTHPLACE" = 'NA' THEN 1 ELSE 0 END)
FROM patients_text

UNION ALL
SELECT
	'patients'
	, 'CITY'
	, SUM(CASE WHEN "CITY" = 'NA' THEN 1 ELSE 0 END)
FROM patients_text

UNION ALL
SELECT
	'patients'
	, 'DEATHDATE'
	, SUM(CASE WHEN "DEATHDATE" = 'NA' THEN 1 ELSE 0 END)
FROM patients_text

UNION ALL
SELECT
	'patients'
	, 'DRIVERS'
	, SUM(CASE WHEN "DRIVERS" = 'NA' THEN 1 ELSE 0 END)
FROM patients_text

UNION ALL
SELECT
	'patients'
	, 'ETHNICITY'
	, SUM(CASE WHEN "ETHNICITY" = 'NA' THEN 1 ELSE 0 END)
FROM patients_text

UNION ALL
SELECT
	'patients'
	, 'FIRST'
	, SUM(CASE WHEN "FIRST" = 'NA' THEN 1 ELSE 0 END)
FROM patients_text

UNION ALL
SELECT
	'patients'
	, 'GENDER'
	, SUM(CASE WHEN "GENDER" = 'NA' THEN 1 ELSE 0 END)
FROM patients_text

UNION ALL
SELECT
	'patients'
	, 'Id'
	, SUM(CASE WHEN "Id" = 'NA' THEN 1 ELSE 0 END)
FROM patients_text

UNION ALL
SELECT
	'patients'
	, 'LAST'
	, SUM(CASE WHEN "LAST" = 'NA' THEN 1 ELSE 0 END)
FROM patients_text

UNION ALL
SELECT
	'patients'
	, 'MAIDEN'
	, SUM(CASE WHEN "MAIDEN" = 'NA' THEN 1 ELSE 0 END)
FROM patients_text

UNION ALL
SELECT
	'patients'
	, 'MARITAL'
	, SUM(CASE WHEN "MARITAL" = 'NA' THEN 1 ELSE 0 END)
FROM patients_text

UNION ALL
SELECT
	'patients'
	, 'PASSPORT'
	, SUM(CASE WHEN "PASSPORT" = 'NA' THEN 1 ELSE 0 END)
FROM patients_text

UNION ALL
SELECT
	'patients'
	, 'PREFIX'
	, SUM(CASE WHEN "PREFIX" = 'NA' THEN 1 ELSE 0 END)
FROM patients_text

UNION ALL
SELECT
	'patients'
	, 'RACE'
	, SUM(CASE WHEN "RACE" = 'NA' THEN 1 ELSE 0 END)
FROM patients_text

UNION ALL
SELECT
	'patients'
	, 'SSN'
	, SUM(CASE WHEN "SSN" = 'NA' THEN 1 ELSE 0 END)
FROM patients_text

UNION ALL
SELECT
	'patients'
	, 'STATE'
	, SUM(CASE WHEN "STATE" = 'NA' THEN 1 ELSE 0 END)
FROM patients_text

UNION ALL
SELECT
	'patients'
	, 'SUFFIX'
	, SUM(CASE WHEN "SUFFIX" = 'NA' THEN 1 ELSE 0 END)
FROM patients_text

UNION ALL
SELECT
	'patients'
	, 'ZIP'
	, SUM(CASE WHEN "ZIP" = 'NA' THEN 1 ELSE 0 END)
FROM patients_text;

-----------------------------------------------------------------------
-- PROCEDURES
-----------------------------------------------------------------------
SELECT
	'procedures' AS dataset
	, 'CODE.x' AS column_name
	, SUM(CASE WHEN "CODE.x" = 'NA' THEN 1 ELSE 0 END) AS na_count
FROM procedures_text

UNION ALL
SELECT
	'procedures'
	, 'COST.x'
	, SUM(CASE WHEN "COST.x" = 'NA' THEN 1 ELSE 0 END)
FROM procedures_text

UNION ALL
SELECT
	'procedures'
	, 'DATE'
	, SUM(CASE WHEN "DATE" = 'NA' THEN 1 ELSE 0 END)
FROM procedures_text

UNION ALL
SELECT
	'procedures'
	, 'DESCRIPTION.x'
	, SUM(CASE WHEN "DESCRIPTION.x" = 'NA' THEN 1 ELSE 0 END)
FROM procedures_text

UNION ALL
SELECT
	'procedures'
	, 'ENCOUNTER'
	, SUM(CASE WHEN "ENCOUNTER" = 'NA' THEN 1 ELSE 0 END)
FROM procedures_text

UNION ALL
SELECT
	'procedures'
	, 'PATIENT.x'
	, SUM(CASE WHEN "PATIENT.x" = 'NA' THEN 1 ELSE 0 END)
FROM procedures_text

UNION ALL
SELECT
	'procedures'
	, 'REASONCODE.x'
	, SUM(CASE WHEN "REASONCODE.x" = 'NA' THEN 1 ELSE 0 END)
FROM procedures_text

UNION ALL
SELECT
	'procedures'
	, 'REASONDESCRIPTION.x'
	, SUM(CASE WHEN "REASONDESCRIPTION.x" = 'NA' THEN 1 ELSE 0 END)
FROM procedures_text;

-----------------------------------------------------------------------
-- RESULTS: COLUMNS CONTAINING 'NA' and marked as 'needed' if used in final data analysis
-----------------------------------------------------------------------
-- allergies.stop -- needed
-- encounters.code -- needed
-- encounters.provider
-- encounters.reasoncode
-- encounters.reasondescription -- needed --note: inspect later, if this is a varchar column anyway, 'NA' is ok
-- medications.reasoncode
-- medications.reasondescription -- potentially needed; check if VARCHAR column anyway
-- medications.stop -- needed
-- patients.deathdate -- needed
-- procedures.reasoncode.x
-- procedures.reasondescription.x
