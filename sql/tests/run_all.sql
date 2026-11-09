\set ON_ERROR_STOP on
DROP SCHEMA IF EXISTS bi_foundation_test CASCADE;
CREATE SCHEMA bi_foundation_test;
SET search_path TO bi_foundation_test;
-- Exercise migration from the legacy physical fact table, then repeat DDL against the compatibility view.
CREATE TABLE f_avis(legacy_id INTEGER);
\ir ../create_tables.sql
\ir ../create_tables.sql
\ir fixtures.sql
SET app.batch_id='fixture-run-1';
SET app.effective_date='2020-01-01';
\ir ../load_data.sql
\ir assertions.sql
-- A second full load must preserve every count and all SCD versions.
SET app.batch_id='fixture-run-2';
\ir ../load_data.sql
\ir assertions.sql
\ir test_constraints.sql
\ir test_scd2.sql
DROP SCHEMA bi_foundation_test CASCADE;
\echo 'P0/P1 SQL test suite passed'
