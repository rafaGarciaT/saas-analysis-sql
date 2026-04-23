\set ON_ERROR_STOP on

\echo [master_validate] Running data quality checks...
\ir ../tests/data_quality_checks.sql

\echo [master_validate] Running profitability query...
\ir ../queries/01_current_profitability.sql

\echo [master_validate] Completed.
