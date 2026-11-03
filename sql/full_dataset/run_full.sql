\set ON_ERROR_STOP on
\if :{?effective_date}
\else
\set effective_date 2026-11-03
\endif
SET app.batch_id TO 'olist-full-validation';
SET app.effective_date TO :'effective_date';
\ir ../load_data.sql
\ir assertions.sql