\set ON_ERROR_STOP on

\echo [master_all] Setup phase...
\ir ./master_setup.sql

\echo [master_all] Validation/query phase...
\ir ./master_validate.sql

\echo [master_all] Completed successfully.
