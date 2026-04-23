\set ON_ERROR_STOP on

\echo [master_setup] Applying schema...
\ir ../schema/01_tables.sql
\ir ../schema/02_constraints.sql
\ir ../schema/03_indexes.sql
\ir ../schema/04_views.sql

\echo [master_setup] Seeding data...
\ir ../seeding/01_plans.sql
\ir ../seeding/02_users.sql
\ir ../seeding/03_activity.sql

\echo [master_setup] Completed successfully.
