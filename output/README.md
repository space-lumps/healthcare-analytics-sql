# output/ directory

This folder contains generated results from the pipeline.

## Committed files
- `overdose_cohort.csv` → main cohort output (final result of the pipeline)

## Ignored / local files (not committed to the repository)

These are generated or temporary files created during local runs, testing, or CI execution:

- `inferred_types_snapshot.csv` → temporary snapshot from type inference testing
- `readmissions_arg_min_output.csv` → local comparison output from manual DuckDB ARG_MIN vs window function test
- `readmissions_rn_output.csv` → local comparison output from manual DuckDB ARG_MIN vs window function test
- `test_output.log` → aggregated output from DuckDB test execution in CI (uploaded as artifact)

All temporary/testing files are listed in .gitignore and not committed.