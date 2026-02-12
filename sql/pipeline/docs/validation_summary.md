# Validation & QA Summary

## 1. Source Data Reconciliation
- Verified row counts between raw CSVs and normalized TEMP VIEWs
- Confirmed no unintended row loss during casting or null normalization
- Identified and deduplicated repeated encounter IDs

## 2. Grain Validation
- Confirmed final cohort grain is one row per patient_id + encounter_id
- Verified no duplicate keys in final output

## 3. Cohort Criteria Checks
- Confirmed encounters filtered to:
  - reasondescription = 'Drug overdose'
  - encounter start > 1999-07-15
  - age between 18–35 (inclusive)
- Recalculated age logic independently to confirm correctness

## 4. Metric Logic Validation
- COUNT_CURRENT_MEDS independently recomputed
- CURRENT_OPIOID_IND validated against keyword token list
- READMISSION_90_DAY_IND and READMISSION_30_DAY_IND validated using separate query logic

## 5. Null & Range Testing
- Verified no unexpected nulls in required fields
- Verified timestamps fall within realistic clinical ranges

All validation scripts are located in:
sql/pipeline/tests/
