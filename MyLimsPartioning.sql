-- ======================================================================
-- Complete PostgreSQL Schema for LIMS Database (Final Version)
--
-- This script sets up a comprehensive LIMS database, optimized for
-- genetics, bioinformatics, marine fisheries, biology, ecology, and
-- computational biology research. It incorporates advanced PostgreSQL
-- features, consistent naming conventions, and a streamlined audit trail.
--
-- Key Features:
-- - Strict snake_case naming for all identifiers.
-- - Centralized auditing via 'audit.log' table.
-- - Integrated PostGIS for spatial data in sampling.
-- - Centralized unit management via 'reference.units' table.
-- - Attachments stored as BYTEA.
-- - Minimal CHECK constraints ('sex' enum retained).
-- - Declarative partitioning for large tables ('lab.sampling', 'lab.samples').
-- - **NEW: lab.master_samples table for global sample_id uniqueness.**
-- - Full-text search with GIN indexes.
-- - Row-Level Security (RLS) for data access control.
-- - Comprehensive views for UI and reporting.
-- - **Deferred Foreign Key Constraints for all tables (Crucial Fix)**
--
-- To run this script:
-- 1. Connect to your PostgreSQL server (e.g., using psql or pgAdmin).
-- 2. Create a new, empty database (e.g., CREATE DATABASE my_new_lims_db;).
-- 3. Connect to this new database.
-- 4. Execute this entire script.
-- ======================================================================

-- ======================================================================
-- 0. Pre-Cleanup (Optional, but good for re-running during development)
--    Drops all schemas and extensions to ensure a clean slate.
--    DO NOT run this in a production database if other applications use these schemas/extensions.
-- ======================================================================

-- Drop all schemas (order matters for dependencies)
DROP SCHEMA IF EXISTS "lab" CASCADE;
DROP SCHEMA IF EXISTS "lims" CASCADE;
DROP SCHEMA IF EXISTS "reference" CASCADE;
DROP SCHEMA IF EXISTS "bioinformatics" CASCADE;
DROP SCHEMA IF EXISTS "audit" CASCADE;

-- Drop extensions (if no other databases use them)
DROP EXTENSION IF EXISTS "uuid-ossp";
DROP EXTENSION IF EXISTS pg_trgm;
DROP EXTENSION IF EXISTS postgres_fdw;
DROP EXTENSION IF EXISTS hstore;
DROP EXTENSION IF EXISTS tablefunc;
DROP EXTENSION IF EXISTS ltree;
DROP EXTENSION IF NOT EXISTS postgis;

-- ======================================================================
-- 1. Extensions
--    Enabling powerful built-in PostgreSQL functionalities.
-- ======================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS postgres_fdw;
CREATE EXTENSION IF NOT EXISTS hstore;
CREATE EXTENSION IF NOT EXISTS tablefunc;
CREATE EXTENSION IF NOT EXISTS ltree;
CREATE EXTENSION IF NOT EXISTS postgis; -- Crucial for spatial data

-- ======================================================================
-- 2. Schema Creation
-- ======================================================================

CREATE SCHEMA IF NOT EXISTS "lab";
CREATE SCHEMA IF NOT EXISTS "lims";
CREATE SCHEMA IF NOT EXISTS "reference";
CREATE SCHEMA IF NOT EXISTS "bioinformatics";
CREATE SCHEMA IF NOT EXISTS "audit";

-- ======================================================================
-- 3. Audit Log Table
--    This table will be the SOLE source of truth for all data modifications.
-- ======================================================================

CREATE TABLE IF NOT EXISTS "audit"."log" (
    "id" serial PRIMARY KEY,
    "schema_name" text NOT NULL,
    "table_name" text NOT NULL,
    "user_id" text,
    "action_timestamp" timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "action" text NOT NULL CHECK ("action" IN ('I', 'D', 'U')),
    "original_data" jsonb,
    "new_data" jsonb,
    "query_text" text
);

-- ======================================================================
-- 4. Reference Schema Tables
-- ======================================================================

CREATE TABLE IF NOT EXISTS "reference"."personal" (
    "person_id" text PRIMARY KEY,
    "full_name" text,
    "room" text,
    "telephone" text,
    "mail" text,
    "password_hash" text NOT NULL,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "reference"."status" (
    "status_id" text PRIMARY KEY,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "reference"."room" (
    "room_id" text PRIMARY KEY,
    "etage" text,
    "address" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "reference"."vessel" (
    "vessel_id" text PRIMARY KEY,
    "vessel_name" text,
    "belong_to" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "reference"."region" (
    "region_id" text PRIMARY KEY,
    "region_abrv" text UNIQUE NOT NULL,
    "country" text,
    "category" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "reference"."ecosystem" (
    "ecosystem_id" text PRIMARY KEY,
    "ecosystem_abrv" text UNIQUE NOT NULL,
    "country" text,
    "category" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "reference"."category" (
    "category_id" text PRIMARY KEY,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "reference"."samples_type" (
    "sample_type_id" text PRIMARY KEY,
    "sample_type_abrv" text UNIQUE NOT NULL,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "reference"."gene" (
    "gene_id" text PRIMARY KEY,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "reference"."taxon" (
    "taxon_id" text PRIMARY KEY,
    "taxon_parent" text, -- FK will be added later
    "de_name" text,
    "en_name" text,
    "rank" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
    "path" ltree
);

CREATE TABLE IF NOT EXISTS "reference"."species" (
    "species_id" text PRIMARY KEY, -- FK will be added later
    "de_name" text,
    "en_name" text,
    "max_length_mm" numeric,
    "max_age_years" numeric,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "reference"."units" (
    "unit_id" text PRIMARY KEY,
    "unit_name" text NOT NULL,
    "unit_abbreviation" text UNIQUE NOT NULL,
    "unit_type" text NOT NULL,
    "conversion_factor_to_base" numeric
);

-- ======================================================================
-- 5. Lims Schema Tables
-- ======================================================================

CREATE TABLE IF NOT EXISTS "lims"."external_contacts" (
    "contact_id" text PRIMARY KEY,
    "full_name" text NOT NULL,
    "organization" text,
    "telephone" text,
    "mail" text,
    "address" text,
    "password_hash" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "lims"."customers" (
    "customer_id" text PRIMARY KEY, -- Keeping as text as per your provided script
    "customer_name" text NOT NULL,
    "customer_abrv" text UNIQUE NOT NULL,
    "address" text NOT NULL,
    "mail" text NOT NULL,
    "phone" text NOT NULL,
    "password_hash" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "lims"."projects" (
    "project_id" text PRIMARY KEY,
    "title" text,
    "status_id" text, -- FK will be added later
    "pi_person_id" text, -- FK will be added later
    "funder" text,
    "customer_id" text, -- FK will be added later (matching lims.customers.customer_id type)
    "start_date" date,
    "end_date" date,
    "report_date" date,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "lims"."project_persons" (
    "project_id" text, -- FK will be added later
    "person_id" text, -- FK will be added later
    "role" text,
    PRIMARY KEY ("project_id", "person_id"),
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "lab"."storage" (
    "storage_id" text PRIMARY KEY,
    "room_id" text, -- FK will be added later
    "freezer" text,
    "etage" text,
    "temperature_c" numeric,
    "box" text,
    "box_size_x" numeric,
    "box_size_y" numeric,
    "storage_position_format" text,
    "project_id" text, -- FK will be added later
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "lims"."cruises" (
    "cruise_id" text PRIMARY KEY,
    "project_id" text NOT NULL, -- FK will be added later
    "vessel_id" text, -- FK will be added later
    "status_id" text DEFAULT 'Received' NOT NULL, -- FK will be added later
    "region_id" text, -- FK will be added later
    "ecosystem_id" text, -- FK will be added later
    "capitaine_contact_id" text, -- FK will be added later
    "chief_scientist_person_id" text, -- FK will be added later
    "start_date" date,
    "end_date" date,
    "together_with_contact_id" text, -- FK will be added later
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "lims"."workflows" (
    "workflow_id" text PRIMARY KEY,
    "workflow_name" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "lims"."permits" (
    "permit_id" text PRIMARY KEY,
    "permit_number" text,
    "issuing_authority" text,
    "valid_from" date,
    "valid_to" date,
    "reference" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "lims"."primers" (
    "primer_id" text PRIMARY KEY,
    "target_gene_id" text, -- FK will be added later
    "primer_sequence_fwd" text,
    "primer_sequence_rev" text,
    "probe" text,
    "reference" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "lims"."sop" (
    "sop_id" text PRIMARY KEY,
    "title" text,
    "sop_id_origin" text NOT NULL,
    "version" text NOT NULL,
    "author_person_id" text, -- FK will be added later
    "reviewer1_person_id" text, -- FK will be added later
    "reviewer2_person_id" text, -- FK will be added later
    "date_realise" date,
    "sop_protocol" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "lims"."workflow_steps" (
    "step_id" text PRIMARY KEY,
    "workflow_id" text NOT NULL, -- FK will be added later
    "step_number" integer NOT NULL,
    "step_name" text NOT NULL,
    "sop_id" text, -- FK will be added later
    "workflow_status_id" text DEFAULT 'Received' NOT NULL, -- FK will be added later
    "target_table_name" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
    UNIQUE ("workflow_id", "step_number")
);

CREATE TABLE IF NOT EXISTS "lims"."equipment" (
    "equipment_id" text PRIMARY KEY,
    "equipment_name" text,
    "room_id" text, -- FK will be added later
    "lot" text,
    "mobility" text,
    "date_maintenance" date,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "lims"."suppliers" (
    "supplier_id" text PRIMARY KEY,
    "supplier_name" text NOT NULL,
    "address" text,
    "contact_person" text,
    "phone" text,
    "mail" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "lims"."inventory_items" (
    "item_id" text PRIMARY KEY,
    "item_name" text NOT NULL,
    "category_id" text, -- FK will be added later
    "notes" text,
    "unit_id" text, -- FK will be added later
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "lims"."orders" (
    "fi_order_nr" text PRIMARY KEY,
    "item_id" text, -- FK will be added later
    "category_id" text, -- FK will be added later
    "order_date" date,
    "price" numeric,
    "quantity" numeric,
    "project_id" text, -- FK will be added later
    "supplier_id" text, -- FK will be added later
    "status_id" text, -- FK will be added later
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "lims"."reagents" (
    "reagent_id" text PRIMARY KEY,
    "reagent_complete_name" text NOT NULL,
    "category_id" text, -- FK will be added later
    "lot" text,
    "storage_id" text, -- FK will be added later
    "storage_position" numeric,
    "status_id" text, -- FK will be added later
    "reception_date" date,
    "expire_date" date,
    "order_id" text, -- FK will be added later
    "project_id" text, -- FK will be added later
    "quantity_available" numeric,
    "quantity_unit_id" text, -- FK will be added later
    "attachment" bytea,
    "attachment_link" text,
    "notes" text
);

CREATE TABLE IF NOT EXISTS "lims"."publication_type" (
    "publication_type_id" text PRIMARY KEY,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "lims"."publications" (
    "publication_id" text PRIMARY KEY,
    "publication_type_id" text, -- FK will be added later
    "project_id" text, -- FK will be added later
    "title" text NOT NULL,
    "journal" text,
    "volume" text,
    "issue" text,
    "pages" text,
    "doi" text UNIQUE,
    "date_publication" date,
    "date_submission" date,
    "first_author_person_id" text, -- FK will be added later
    "corresponding_author_person_id" text, -- FK will be added later
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

-- ======================================================================
-- 6. Lab Schema Tables
-- ======================================================================

CREATE TABLE IF NOT EXISTS "lab"."experiments" (
    "experiment_id" text PRIMARY KEY,
    "experiment_title" text,
    "aim" text,
    "method" text,
    "sop_id" text, -- FK will be added later
    "experiment_date" date,
    "person_id" text, -- FK will be added later
    "notes" text,
    "lab_book" text,
    "status_id" text, -- FK will be added later
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "lab"."experiments_projects" (
    "experiment_project_id" serial PRIMARY KEY,
    "experiment_id" text, -- FK will be added later
    "project_id" text, -- FK will be added later
    "link_date" date,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "lab"."protocol_runs" (
    "protocol_run_id" text PRIMARY KEY,
    "experiment_id" text, -- FK will be added later
    "sop_id" text, -- FK will be added later
    "protocol_text" text,
    "run_date" date NOT NULL,
    "person_id" text NOT NULL, -- FK will be added later
    "protocol_run_details" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

-- Parent table for partitioned sampling data
CREATE TABLE "lab"."sampling" (
    "sampling_id" text NOT NULL,
    "experiment_id" text, -- FK will be added later
    "project_id" text NOT NULL, -- FK will be added later
    "cruise_id" text, -- FK will be added later
    "region_id" text, -- FK will be added later
    "ecosystem_id" text, -- FK will be added later
    "vessel_id" text, -- FK will be added later
    "customer_id" text, -- FK will be added later
    "sampling_date" date NOT NULL, -- Partition key
    "geom" geometry(Point, 4326),
    "fishing_start_geom" geometry(Point, 4326),
    "fishing_end_geom" geometry(Point, 4326),
    "location_name" text,
    "depth_m" numeric,
    "start_at" time,
    "end_at" time,
    "temperature_atmospheric_c" numeric,
    "weather" text,
    "wind_speed" numeric,
    "wind_unit_id" text, -- FK will be added later
    "temperature_sampling_depth_c" numeric,
    "salinity" numeric,
    "salinity_unit_id" text, -- FK will be added later
    "pressure" numeric,
    "pressure_unit_id" text, -- FK will be added later
    "oxygen" numeric,
    "oxygen_unit_id" text, -- FK will be added later
    "conductivity" numeric,
    "conductivity_unit_id" text, -- FK will be added later
    "ph" numeric,
    "nitrate_mg_l" numeric,
    "phosphate_mg_l" numeric,
    "turbidity_ntu" numeric,
    "chlorophyll_a_ug_l" numeric,
    "current_speed_m_s" numeric,
    "current_direction_deg" numeric,
    "tide_stage" text,
    "light_par_umol_m2_s" numeric,
    "sea_state" text,
    "sample_volume_l" numeric,
    "sample_type_id" text, -- FK will be added later
    "preservative" text,
    "cloud_cover_percent" numeric,
    "rainfall_mm" numeric,
    "instrument_id" text,
    "calibration_date" date,
    "visibility_m" numeric,
    "fishing_date" date,
    "fishing_time_min" time,
    "fishing_method" text,
    "gear_type" text,
    "soak_time" numeric,
    "soak_time_unit_id" text, -- FK will be added later
    "trawl_speed" numeric,
    "trawl_speed_unit_id" text, -- FK will be added later
    "total_catch_quantity_kg" numeric,
    "total_catch_quantity_fish" numeric,
    "catch_notes" text,
    "operation_duration_min" numeric,
    "together_with_contact_id" text, -- FK will be added later
    "status_id" text DEFAULT 'Planned' NOT NULL, -- FK will be added later
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
) PARTITION BY RANGE ("sampling_date");

-- Primary key for partitioned table must include the partition key
ALTER TABLE "lab"."sampling" ADD PRIMARY KEY ("sampling_id", "sampling_date");

-- NEW: lab.master_samples table for global sample_id uniqueness
CREATE TABLE IF NOT EXISTS "lab"."master_samples" (
    "sample_id" text PRIMARY KEY,
    "created_at" timestamptz DEFAULT CURRENT_TIMESTAMP,
    "notes" text
);

-- Parent table for partitioned samples data
CREATE TABLE "lab"."samples" (
    "sample_id" text NOT NULL, -- FK to master_samples will be added later
    "external_name" text,
    "parent_sample_id" text, -- FK will be added later (to master_samples)
    "sampling_id" text,
    "sampling_date" date NOT NULL, -- Partition key
    "storage_id" text, -- FK will be added later
    "storage_position" text,
    "sampler_person_id" text, -- FK will be added later
    "receiver_person_id" text, -- FK will be added later
    "reception_date" date,
    "transport" text,
    "conservation_buffer" text,
    "sample_type_id" text NOT NULL, -- FK will be added later
    "sample_status_id" text DEFAULT 'Received' NOT NULL, -- FK will be added later
    "workflow_id" text, -- FK will be added later
    "step_id" text, -- FK will be added later
    "project_id" text, -- FK will be added later
    "customer_id" text, -- FK will be added later
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
    PRIMARY KEY ("sample_id", "sampling_date")
) PARTITION BY RANGE ("sampling_date");

CREATE TABLE IF NOT EXISTS "lab"."fishing" (
    "fishing_id" text PRIMARY KEY,
    "sampling_id" text NOT NULL,
    "sampling_date" date NOT NULL,
    "taxon_id" text, -- FK will be added later
    "catch_kg" numeric,
    "catch_fish" numeric,
    "customer_id" text, -- FK will be added later
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "lab"."storage_log" (
    "log_id" serial PRIMARY KEY,
    "sample_id" text NOT NULL,
    "sample_sampling_date" date NOT NULL,
    "storage_id" text NOT NULL, -- FK will be added later
    "person_id" text, -- FK will be added later
    "move_date" timestamptz DEFAULT CURRENT_TIMESTAMP,
    "status" text NOT NULL,
    "storage_position" text,
    "notes" text
);

CREATE TABLE IF NOT EXISTS "lab"."fish" (
    "sample_id" text PRIMARY KEY, -- This references master_samples.sample_id
    "parent_sample_id" text NOT NULL, -- FK will be added later (to master_samples)
    "experiment_id" text, -- FK will be added later
    "species_id" text NOT NULL, -- FK will be added later
    "total_length_mm" numeric,
    "fork_length_mm" numeric,
    "standard_length_mm" numeric,
    "weight_g" numeric,
    "sex" text,
    "maturity_stage" text,
    "stomach_contents" text,
    "disease_info" text,
    "tag_id" text,
    "storage_id" text, -- FK will be added later
    "storage_position" text,
    "project_id" text, -- FK will be added later
    "customer_id" text, -- FK will be added later
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);
ALTER TABLE "lab"."fish" ADD CONSTRAINT chk_fish_sex_enum CHECK ("sex" IN ('Male', 'Female', 'Undetermined', NULL));

CREATE TABLE IF NOT EXISTS "lab"."tissue" (
    "sample_id" text PRIMARY KEY, -- This references master_samples.sample_id
    "parent_sample_id" text NOT NULL, -- FK will be added later (to master_samples)
    "experiment_id" text, -- FK will be added later
    "weight_mg" numeric,
    "tissue_type" text,
    "preservation_method" text,
    "storage_id" text, -- FK will be added later
    "storage_position" text,
    "project_id" text, -- FK will be added later
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "lab"."otoliths" (
    "otolith_id" text PRIMARY KEY,
    "sample_id" text NOT NULL, -- FK will be added later (to master_samples)
    "reader_person_id" text NOT NULL, -- FK will be added later
    "side" text NOT NULL,
    "age_reading_years" numeric,
    "confidence" numeric,
    "reading_date" date,
    "project_id" text, -- FK will be added later
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
    UNIQUE ("sample_id", "reader_person_id", "side")
);

CREATE TABLE IF NOT EXISTS "lab"."dna" (
    "sample_id" text PRIMARY KEY, -- This references master_samples.sample_id
    "parent_sample_id" text NOT NULL, -- FK will be added later (to master_samples)
    "experiment_id" text, -- FK will be added later
    "volume_ul" numeric,
    "concentration_ng_ul" numeric,
    "a260_280" numeric,
    "a260_230" numeric,
    "extraction_method" text,
    "preservation_method" text,
    "extraction_date" date,
    "extraction_number" integer,
    "storage_id" text, -- FK will be added later
    "storage_position" text,
    "project_id" text, -- FK will be added later
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "lab"."rna" (
    "sample_id" text PRIMARY KEY, -- This references master_samples.sample_id
    "parent_sample_id" text NOT NULL, -- FK will be added later (to master_samples)
    "experiment_id" text, -- FK will be added later
    "volume_ul" numeric,
    "concentration_ng_ul" numeric,
    "a260_280" numeric,
    "a260_230" numeric,
    "extraction_method" text,
    "preservation_method" text,
    "extraction_date" date,
    "extraction_number" integer,
    "storage_id" text, -- FK will be added later
    "storage_position" text,
    "project_id" text, -- FK will be added later
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "lab"."sediments" (
    "sample_id" text PRIMARY KEY, -- This references master_samples.sample_id
    "parent_sample_id" text NOT NULL, -- FK will be added later (to master_samples)
    "experiment_id" text, -- FK will be added later
    "project_id" text, -- FK will be added later
    "volume" numeric,
    "volume_unit_id" text, -- FK will be added later
    "depth_m" numeric,
    "sampling_method" text,
    "conservation_buffer" text,
    "storage_id" text, -- FK will be added later
    "storage_position" text,
    "external_name" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "lab"."water" (
    "sample_id" text PRIMARY KEY, -- This references master_samples.sample_id
    "parent_sample_id" text NOT NULL, -- FK will be added later (to master_samples)
    "experiment_id" text, -- FK will be added later
    "volume_l" numeric,
    "filter" text,
    "filter_pore_size_um" numeric,
    "depth_m" numeric,
    "sampling_method" text,
    "conservation_buffer" text,
    "storage_id" text, -- FK will be added later
    "storage_position" text,
    "notes" text,
    "project_id" text, -- FK will be added later
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "lab"."experiments_samples" (
    "experiment_id" text NOT NULL, -- FK will be added later
    "sample_id" text NOT NULL, -- FK will be added later (to master_samples)
    "notes" text,
    PRIMARY KEY ("experiment_id", "sample_id")
);

CREATE TABLE IF NOT EXISTS "lab"."dissections" (
    "dissection_id" text PRIMARY KEY,
    "sample_id" text NOT NULL, -- FK will be added later (to master_samples)
    "person_id" text NOT NULL, -- FK will be added later
    "dissection_date" date NOT NULL,
    "stomach_contents_jsonb" jsonb,
    "gonad_weight_g" numeric,
    "liver_weight_g" numeric,
    "notes" text,
    "status_id" text, -- FK will be added later
    "created_at" timestamptz DEFAULT CURRENT_TIMESTAMP,
    "attachment" bytea,
    "attachment_link" text,
    CONSTRAINT "dissection_unique" UNIQUE ("sample_id", "person_id", "dissection_date")
);

CREATE TABLE IF NOT EXISTS "lab"."extraction" (
    "extraction_id" text PRIMARY KEY,
    "experiment_id" text, -- FK will be added later
    "sample_id" text, -- FK will be added later (to master_samples)
    "parent_sample_id" text NOT NULL, -- FK will be added later (to master_samples)
    "sample_type_id" text NOT NULL, -- FK will be added later
    "extracted_dna_sample_id" text, -- FK will be added later (to master_samples)
    "extracted_rna_sample_id" text, -- FK will be added later (to master_samples)
    "extraction_date" date,
    "person_id" text NOT NULL, -- FK will be added later
    "kit" text,
    "elution_volume_ul" numeric,
    "yield_qubit_ng_ul" numeric,
    "yield_nanodrop_ng_ul" numeric,
    "a260_280" numeric,
    "a260_230" numeric,
    "extraction_blank_id" text,
    "notes" text,
    "status_id" text, -- FK will be added later
    "storage_id" text, -- FK will be added later
    "storage_position" text,
    "project_id" text, -- FK will be added later
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "lab"."nanodrop" (
    "nanodrop_id" text PRIMARY KEY,
    "experiment_id" text, -- FK will be added later
    "sample_id" text, -- FK will be added later (to master_samples)
    "nanodrop_concentration" numeric,
    "concentration_unit_id" text, -- FK will be added later
    "a260" numeric,
    "a260_280" numeric,
    "a260_280_note" text,
    "a260_230" numeric,
    "a260_230_note" text,
    "measurement_date" date,
    "elution_volume_ul" numeric,
    "person_id" text, -- FK will be added later
    "notes" text,
    "status_id" text, -- FK will be added later
    "attachment" bytea,
    "attachment_link" text,
    "storage_id" text, -- FK will be added later
    "storage_position" text,
    "project_id" text, -- FK will be added later
    "result_date" timestamptz,
    "nanodrop_total_dna_ug" numeric GENERATED ALWAYS AS (("elution_volume_ul" * "nanodrop_concentration") / 1000) STORED
);

CREATE TABLE IF NOT EXISTS "lab"."qubit" (
    "qubit_id" text PRIMARY KEY,
    "sample_id" text, -- FK will be added later (to master_samples)
    "experiment_id" text, -- FK will be added later
    "run_id" text,
    "assay_kit" text,
    "measurement_date" date,
    "qubit_tube_conc" numeric,
    "tube_unit_id" text, -- FK will be added later
    "qubit_original_sample_conc" numeric,
    "original_sample_unit_id" text, -- FK will be added later
    "sample_volume_ul" numeric,
    "elution_volume_ul" numeric,
    "person_id" text, -- FK will be added later
    "notes" text,
    "status_id" text, -- FK will be added later
    "storage_id" text, -- FK will be added later
    "storage_position" text,
    "project_id" text, -- FK will be added later
    "attachment" bytea,
    "attachment_link" text,
    "qubit_total_dna_ug" numeric GENERATED ALWAYS AS (("elution_volume_ul" * "qubit_original_sample_conc") / 1000) STORED
);

CREATE TABLE IF NOT EXISTS "lab"."tapestation" (
    "tapestation_id" text PRIMARY KEY,
    "experiment_id" text, -- FK will be added later
    "position" text,
    "measurement_date" date,
    "kit" text,
    "person_id" text, -- FK will be added later
    "notes" text,
    "sample_id" text, -- FK will be added later (to master_samples)
    "storage_id" text, -- FK will be added later
    "storage_position" text,
    "status_id" text, -- FK will be added later
    "project_id" text, -- FK will be added later
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "lab"."pcr" (
    "pcr_id" text PRIMARY KEY,
    "experiment_id" text, -- FK will be added later
    "sample_id" text, -- FK will be added later (to master_samples)
    "position" text,
    "primer_id" text, -- FK will be added later
    "pcr_blank_id" text,
    "pcr_date" date,
    "person_id" text, -- FK will be added later
    "kit" text,
    "storage_id" text, -- FK will be added later
    "storage_position" text,
    "status_id" text, -- FK will be added later
    "notes" text,
    "project_id" text, -- FK will be added later
    "attachment" bytea,
    "attachment_link" text,
    "volume_reaction_ul" numeric
);

CREATE TABLE IF NOT EXISTS "lab"."gelelectrophoresis" (
    "gelelectrophoresis_id" text PRIMARY KEY,
    "experiment_id" text, -- FK will be added later
    "sample_id" text, -- FK will be added later (to master_samples)
    "position" text,
    "ladder" text,
    "voltage" numeric,
    "band_size_bp" integer,
    "gel_type" text,
    "run_time_minutes" numeric,
    "run_date" date,
    "person_id" text, -- FK will be added later
    "storage_id" text, -- FK will be added later
    "storage_position" text,
    "project_id" text, -- FK will be added later
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "lab"."qpcr" (
    "qpcr_id" text PRIMARY KEY,
    "experiment_id" text, -- FK will be added later
    "sample_id" text, -- FK will be added later (to master_samples)
    "position" text,
    "qpcr_date" date,
    "person_id" text, -- FK will be added later
    "primer_id" text, -- FK will be added later
    "ct_value" numeric,
    "inhibitor_test_result" text,
    "pcr_blank_id" text,
    "kit" text,
    "volume_ul" numeric,
    "storage_id" text, -- FK will be added later
    "storage_position" text,
    "status_id" text, -- FK will be added later
    "project_id" text, -- FK will be added later
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "lab"."library" (
    "library_id" text PRIMARY KEY,
    "experiment_id" text, -- FK will be added later
    "sample_id" text NOT NULL, -- FK will be added later (to master_samples)
    "library_name" text,
    "prep_date" date,
    "person_id" text, -- FK will be added later
    "library_prep_kit" text,
    "index_sequence" text,
    "read_length_bp" integer,
    "storage_id" text, -- FK will be added later
    "storage_position" text,
    "project_id" text, -- FK will be added later
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "lab"."sequencing" (
    "sequencing_id" text PRIMARY KEY,
    "experiment_id" text, -- FK will be added later
    "library_id" text, -- FK will be added later
    "sample_id" text NOT NULL, -- FK will be added later (to master_samples)
    "sequencing_date" date,
    "person_id" text, -- FK will be added later
    "sequencer" text,
    "flow_cell_id" text,
    "library_prep_kit" text,
    "index_sequence" text,
    "read_length_bp" integer,
    "total_reads" bigint,
    "raw_data_path" text,
    "genbank_accession_number" text,
    "status_id" text, -- FK will be added later
    "storage_id" text, -- FK will be added later
    "storage_position" text,
    "project_id" text, -- FK will be added later
    "attachment" bytea,
    "attachment_link" text,
    "notes" text
);

CREATE TABLE IF NOT EXISTS "lab"."datasets" (
    "dataset_id" text PRIMARY KEY,
    "source_type" text,
    "ecosystem_id" text, -- FK will be added later
    "region_id" text, -- FK will be added later
    "customer_id" text, -- FK will be added later
    "stored_location_id" text, -- FK will be added later
    "reception_date" date,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
    "storage_path" text
);

-- ======================================================================
-- 7. Bioinformatics Schema Tables
-- ======================================================================

CREATE TABLE IF NOT EXISTS "bioinformatics"."reference_databases" (
    "db_id" text PRIMARY KEY,
    "db_name" text NOT NULL,
    "db_version" text,
    "notes" text,
    "url" text,
    "last_updated_date" date,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "bioinformatics"."analysis_pipelines" (
    "pipeline_id" text PRIMARY KEY,
    "pipeline_name" text NOT NULL,
    "version" text NOT NULL,
    "repository_link" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "bioinformatics"."analysis_runs" (
    "run_id" text PRIMARY KEY,
    "pipeline_id" text NOT NULL, -- FK will be added later
    "sequencing_id" text NOT NULL, -- FK will be added later
    "person_id" text NOT NULL, -- FK will be added later
    "run_date" timestamptz DEFAULT CURRENT_TIMESTAMP,
    "parameters_jsonb" jsonb,
    "reference_db_id" text, -- FK will be added later
    "clustering_threshold" numeric,
    "final_output_path" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "bioinformatics"."edna_assignments" (
    "assignment_id" text PRIMARY KEY,
    "run_id" text NOT NULL, -- FK will be added later
    "sample_id" text NOT NULL, -- FK will be added later (to master_samples)
    "taxon_id" text NOT NULL, -- FK will be added later
    "read_count" integer,
    "confidence" numeric,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

-- ======================================================================
-- 8. Sequences for ID Generation
-- ======================================================================

CREATE SEQUENCE IF NOT EXISTS "lims"."customer_id_seq" START 1;
CREATE SEQUENCE IF NOT EXISTS "lims"."publication_serial_seq" START 1;
CREATE SEQUENCE IF NOT EXISTS "lab"."fishing_serial_seq" START 1;
CREATE SEQUENCE IF NOT EXISTS "lab"."fish_child_serial_seq" START 1;
CREATE SEQUENCE IF NOT EXISTS "lab"."tissue_child_serial_seq" START 1;
CREATE SEQUENCE IF NOT EXISTS "lab"."dna_child_serial_seq" START 1;
CREATE SEQUENCE IF NOT EXISTS "lab"."rna_child_serial_seq" START 1;
CREATE SEQUENCE IF NOT EXISTS "lab"."sediments_child_serial_seq" START 1;
CREATE SEQUENCE IF NOT EXISTS "lab"."water_child_serial_seq" START 1;
CREATE SEQUENCE IF NOT EXISTS "lab"."otolith_serial_seq" START 1;
CREATE SEQUENCE IF NOT EXISTS "lab"."dissection_serial_seq" START 1;
CREATE SEQUENCE IF NOT EXISTS "lab"."extraction_serial_seq" START 1;
CREATE SEQUENCE IF NOT EXISTS "lab"."nanodrop_serial_seq" START 1;
CREATE SEQUENCE IF NOT EXISTS "lab"."qubit_serial_seq" START 1;
CREATE SEQUENCE IF NOT EXISTS "lab"."tapestation_serial_seq" START 1;
CREATE SEQUENCE IF NOT EXISTS "lab"."pcr_serial_seq" START 1;
CREATE SEQUENCE IF NOT EXISTS "lab"."gelelectrophoresis_serial_seq" START 1;
CREATE SEQUENCE IF NOT EXISTS "lab"."qpcr_serial_seq" START 1;
CREATE SEQUENCE IF NOT EXISTS "lab"."library_serial_seq" START 1;
CREATE SEQUENCE IF NOT EXISTS "lab"."sequencing_serial_seq" START 1;
CREATE SEQUENCE IF NOT EXISTS "lab"."dataset_serial_seq" START 1;
CREATE SEQUENCE IF NOT EXISTS "bioinformatics"."pipeline_serial_seq" START 1;
CREATE SEQUENCE IF NOT EXISTS "bioinformatics"."analysis_runs_serial_seq" START 1;
CREATE SEQUENCE IF NOT EXISTS "bioinformatics"."edna_assignments_serial_seq" START 1;
CREATE SEQUENCE IF NOT EXISTS "lab"."protocol_run_serial_seq" START 1;

-- ======================================================================
-- 9. Functions
-- ======================================================================

-- Audit Function: Reads LIMS user from session variable
CREATE OR REPLACE FUNCTION "audit"."if_modified_func"()
RETURNS TRIGGER AS $$
DECLARE
    audit_row "audit"."log";
BEGIN
    IF (TG_OP = 'UPDATE') THEN
        audit_row.action = 'U';
        audit_row.original_data = to_jsonb(OLD);
        audit_row.new_data = to_jsonb(NEW);
    ELSIF (TG_OP = 'DELETE') THEN
        audit_row.action = 'D';
        audit_row.original_data = to_jsonb(OLD);
    ELSIF (TG_OP = 'INSERT') THEN
        audit_row.action = 'I';
        audit_row.new_data = to_jsonb(NEW);
    END IF;

    audit_row.schema_name = TG_TABLE_SCHEMA::TEXT;
    audit_row.table_name = TG_TABLE_NAME::TEXT;
    audit_row.user_id = current_setting('lims.current_person_id', true);
    audit_row.query_text = current_query();

    INSERT INTO "audit"."log" VALUES (DEFAULT, audit_row.schema_name, audit_row.table_name, audit_row.user_id,
                                    DEFAULT, audit_row.action, audit_row.original_data, audit_row.new_data, audit_row.query_text);

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate customer_id
CREATE OR REPLACE FUNCTION "lims".generate_customer_id()
RETURNS TRIGGER AS $$
BEGIN
    NEW.customer_id := 'K' || LPAD(NEXTVAL('"lims"."customer_id_seq"')::TEXT, 6, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate publication_id
CREATE OR REPLACE FUNCTION "lims".generate_publication_id()
RETURNS TRIGGER AS $$
DECLARE
    pub_type_abrv text;
    pub_year text;
    next_serial integer;
    id_prefix text;
BEGIN
    pub_year := TO_CHAR(COALESCE(NEW.date_publication, CURRENT_DATE), 'YY');
    SELECT publication_type_id INTO pub_type_abrv FROM "lims"."publication_type" WHERE publication_type_id = NEW.publication_type_id;
    
    IF pub_type_abrv IS NULL THEN
        RAISE EXCEPTION 'Cannot generate publication_id: publication_type_id "%" not found in "lims"."publication_type".', NEW.publication_type_id;
    END IF;

    id_prefix := pub_type_abrv || pub_year;

    SELECT MAX(SUBSTRING("publication_id" FROM LENGTH(id_prefix) + 1)::INTEGER)
    INTO next_serial
    FROM "lims"."publications"
    WHERE "publication_id" ILIKE id_prefix || '%';

    IF next_serial IS NULL THEN
        next_serial := 1;
    ELSE
        next_serial := next_serial + 1;
    END IF;

    NEW.publication_id := id_prefix || LPAD(next_serial::TEXT, 4, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate sop_id
CREATE OR REPLACE FUNCTION "lims".generate_sop_id()
RETURNS TRIGGER AS $$
BEGIN
    NEW.sop_id := NEW.sop_id_origin || '_v' || REPLACE(NEW.version, '.', '');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate workflow_step_id
CREATE OR REPLACE FUNCTION "lims".generate_workflow_step_id()
RETURNS TRIGGER AS $$
BEGIN
    NEW.step_id := NEW.workflow_id || '_' || NEW.step_number::TEXT || '_' || REPLACE(NEW.step_name, ' ', '_');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to Generate Sampling ID
CREATE OR REPLACE FUNCTION "lab".generate_sampling_id()
RETURNS TRIGGER AS $$
DECLARE
    sampling_year text;
    ecosystem_abrv text;
    region_abrv text;
    customer_abrv text;
    id_prefix text;
    next_serial integer;
BEGIN
    sampling_year := TO_CHAR(COALESCE(NEW.sampling_date, CURRENT_DATE), 'YY');

    SELECT COALESCE(e.ecosystem_abrv, '-') INTO ecosystem_abrv
    FROM "reference"."ecosystem" e
    WHERE e.ecosystem_id = NEW.ecosystem_id;

    SELECT COALESCE(r.region_abrv, '-') INTO region_abrv
    FROM "reference"."region" r
    WHERE r.region_id = NEW.region_id;

    IF ecosystem_abrv != '-' OR region_abrv != '-' THEN
        id_prefix := sampling_year || ecosystem_abrv || region_abrv;
    ELSE
        SELECT COALESCE(c.customer_abrv, '-') INTO customer_abrv
        FROM "lims"."customers" c
        WHERE c.customer_id = NEW.customer_id;

        IF customer_abrv != '-' THEN
            id_prefix := sampling_year || customer_abrv;
        ELSE
            RAISE EXCEPTION 'Cannot generate sampling_id: Missing ecosystem_id, region_id, and customer_id.';
        END IF;
    END IF;

    SELECT MAX(SUBSTRING("sampling_id" FROM LENGTH(id_prefix) + 1)::INTEGER)
    INTO next_serial
    FROM "lab"."sampling"
    WHERE "sampling_id" ILIKE id_prefix || '%';

    IF next_serial IS NULL THEN
        next_serial := 1;
    ELSE
        next_serial := next_serial + 1;
    END IF;

    NEW.sampling_id := id_prefix || LPAD(next_serial::TEXT, 4, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to Generate Fishing ID
CREATE OR REPLACE FUNCTION "lab".generate_fishing_id()
RETURNS TRIGGER AS $$
BEGIN
    NEW.fishing_id := NEW.sampling_id || '_' || LPAD(NEXTVAL('lab.fishing_serial_seq')::TEXT, 4, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to Generate Sample ID (Now also inserts into master_samples)
CREATE OR REPLACE FUNCTION "lab".generate_sample_id()
RETURNS TRIGGER AS $$
DECLARE
    sample_type_abrv text;
    sampling_year text;
    ecosystem_abrv text;
    region_abrv text;
    customer_abrv text;
    id_prefix text;
    next_serial integer;
    temp_sampling_id_exists text;
    temp_sampling_date_exists date;
BEGIN
    SELECT sample_type_abrv INTO sample_type_abrv
    FROM "reference"."samples_type" st
    WHERE st.sample_type_id = NEW.sample_type_id;

    sampling_year := TO_CHAR(COALESCE(NEW.sampling_date, NEW.reception_date, CURRENT_DATE), 'YY');

    IF NEW.sampling_id IS NOT NULL AND NEW.sampling_date IS NOT NULL THEN
        SELECT samp.sampling_id, samp.sampling_date INTO temp_sampling_id_exists, temp_sampling_date_exists
        FROM "lab"."sampling" samp
        WHERE samp.sampling_id = NEW.sampling_id AND samp.sampling_date = NEW.sampling_date;

        IF temp_sampling_id_exists IS NOT NULL THEN
            SELECT
                COALESCE(e.ecosystem_abrv, '-'),
                COALESCE(r.region_abrv, '-')
            INTO
                ecosystem_abrv,
                region_abrv
            FROM
                "lab"."sampling" samp_inner
            LEFT JOIN
                "reference"."ecosystem" e ON samp_inner.ecosystem_id = e.ecosystem_id
            LEFT JOIN
                "reference"."region" r ON samp_inner.region_id = r.region_id
            WHERE
                samp_inner.sampling_id = NEW.sampling_id AND samp_inner.sampling_date = NEW.sampling_date;
        ELSE
            RAISE WARNING 'Provided sampling_id % on date % for new sample does not exist in "lab"."sampling". Generating ID using customer or default abbreviations.', NEW.sampling_id, NEW.sampling_date;
            ecosystem_abrv := '-';
            region_abrv := '-';
            IF NEW.customer_id IS NOT NULL THEN
                SELECT COALESCE(c.customer_abrv, '-') INTO customer_abrv
                FROM "lims"."customers" c
                WHERE c.customer_id = NEW.customer_id;
            ELSE
                customer_abrv := '-';
            END IF;
        END IF;
    ELSE
        ecosystem_abrv := '-';
        region_abrv := '-';
        IF NEW.customer_id IS NOT NULL THEN
            SELECT COALESCE(c.customer_abrv, '-') INTO customer_abrv
            FROM "lims"."customers" c
            WHERE c.customer_id = NEW.customer_id;
        ELSE
            customer_abrv := '-';
        END IF;
    END IF;

    IF ecosystem_abrv != '-' OR region_abrv != '-' THEN
        id_prefix := sample_type_abrv || sampling_year || ecosystem_abrv || region_abrv;
    ELSIF customer_abrv != '-' THEN
        id_prefix := sample_type_abrv || sampling_year || customer_abrv;
    ELSE
        RAISE EXCEPTION 'Cannot generate sample_id: Missing sampling_id (or invalid), ecosystem_id, region_id, and customer_id.';
    END IF;

    -- Generate NEW.sample_id
    SELECT MAX(SUBSTRING("sample_id" FROM LENGTH(id_prefix) + 1)::INTEGER)
    INTO next_serial
    FROM "lab"."master_samples" -- Check master_samples for uniqueness
    WHERE "sample_id" ILIKE id_prefix || '%';

    IF next_serial IS NULL THEN
        next_serial := 1;
    ELSE
        next_serial := next_serial + 1;
    END IF;

    NEW.sample_id := id_prefix || LPAD(next_serial::TEXT, 4, '0');

    -- Insert into master_samples to ensure global uniqueness
    INSERT INTO "lab"."master_samples" ("sample_id") VALUES (NEW.sample_id);

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate child sample_id for Fish
CREATE OR REPLACE FUNCTION "lab".generate_fish_child_sample_id()
RETURNS TRIGGER AS $$
DECLARE
    parent_sample_id_exists text;
    fish_abrv text;
    next_serial integer;
    id_prefix text;
BEGIN
    SELECT sample_id INTO parent_sample_id_exists FROM "lab"."master_samples" WHERE sample_id = NEW.parent_sample_id;
    IF parent_sample_id_exists IS NULL THEN
        RAISE EXCEPTION 'Parent_sample_id % does not exist in "lab"."master_samples" table.', NEW.parent_sample_id;
    END IF;

    SELECT sample_type_abrv INTO fish_abrv FROM "reference"."samples_type" WHERE sample_type_id = 'Fish';

    id_prefix := NEW.parent_sample_id || LOWER(fish_abrv);

    SELECT MAX(SUBSTRING("sample_id" FROM LENGTH(id_prefix) + 1)::INTEGER)
    INTO next_serial
    FROM "lab"."master_samples"
    WHERE "sample_id" ILIKE id_prefix || '%';

    IF next_serial IS NULL THEN
        next_serial := 1;
    ELSE
        next_serial := next_serial + 1;
    END IF;

    NEW.sample_id := id_prefix || next_serial::TEXT;
    INSERT INTO "lab"."master_samples" ("sample_id") VALUES (NEW.sample_id); -- Insert into master
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate child sample_id for Tissue
CREATE OR REPLACE FUNCTION "lab".generate_tissue_child_sample_id()
RETURNS TRIGGER AS $$
DECLARE
    parent_sample_id_exists text;
    tissue_abrv text;
    next_serial integer;
    id_prefix text;
BEGIN
    SELECT sample_id INTO parent_sample_id_exists FROM "lab"."master_samples" WHERE sample_id = NEW.parent_sample_id;
    IF parent_sample_id_exists IS NULL THEN
        RAISE EXCEPTION 'Parent_sample_id % does not exist in "lab"."master_samples" table.', NEW.parent_sample_id;
    END IF;

    SELECT sample_type_abrv INTO tissue_abrv FROM "reference"."samples_type" WHERE sample_type_id = 'Tissue';

    id_prefix := NEW.parent_sample_id || LOWER(tissue_abrv);

    SELECT MAX(SUBSTRING("sample_id" FROM LENGTH(id_prefix) + 1)::INTEGER)
    INTO next_serial
    FROM "lab"."master_samples"
    WHERE "sample_id" ILIKE id_prefix || '%';

    IF next_serial IS NULL THEN
        next_serial := 1;
    ELSE
        next_serial := next_serial + 1;
    END IF;

    NEW.sample_id := id_prefix || next_serial::TEXT;
    INSERT INTO "lab"."master_samples" ("sample_id") VALUES (NEW.sample_id); -- Insert into master
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate child sample_id for DNA
CREATE OR REPLACE FUNCTION "lab".generate_dna_child_sample_id()
RETURNS TRIGGER AS $$
DECLARE
    parent_sample_id_exists text;
    dna_abrv text;
    next_serial integer;
    id_prefix text;
BEGIN
    SELECT sample_id INTO parent_sample_id_exists FROM "lab"."master_samples" WHERE sample_id = NEW.parent_sample_id;
    IF parent_sample_id_exists IS NULL THEN
        RAISE EXCEPTION 'Parent_sample_id % does not exist in "lab"."master_samples" table.', NEW.parent_sample_id;
    END IF;

    SELECT sample_type_abrv INTO dna_abrv FROM "reference"."samples_type" WHERE sample_type_id = 'DNA';

    id_prefix := NEW.parent_sample_id || LOWER(dna_abrv);

    SELECT MAX(SUBSTRING("sample_id" FROM LENGTH(id_prefix) + 1)::INTEGER)
    INTO next_serial
    FROM "lab"."master_samples"
    WHERE "sample_id" ILIKE id_prefix || '%';

    IF next_serial IS NULL THEN
        next_serial := 1;
    ELSE
        next_serial := next_serial + 1;
    END IF;

    NEW.sample_id := id_prefix || next_serial::TEXT;
    INSERT INTO "lab"."master_samples" ("sample_id") VALUES (NEW.sample_id); -- Insert into master
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate child sample_id for RNA
CREATE OR REPLACE FUNCTION "lab".generate_rna_child_sample_id()
RETURNS TRIGGER AS $$
DECLARE
    parent_sample_id_exists text;
    rna_abrv text;
    next_serial integer;
    id_prefix text;
BEGIN
    SELECT sample_id INTO parent_sample_id_exists FROM "lab"."master_samples" WHERE sample_id = NEW.parent_sample_id;
    IF parent_sample_id_exists IS NULL THEN
        RAISE EXCEPTION 'Parent_sample_id % does not exist in "lab"."master_samples" table.', NEW.parent_sample_id;
    END IF;

    SELECT sample_type_abrv INTO rna_abrv FROM "reference"."samples_type" WHERE sample_type_id = 'RNA';

    id_prefix := NEW.parent_sample_id || LOWER(rna_abrv);

    SELECT MAX(SUBSTRING("sample_id" FROM LENGTH(id_prefix) + 1)::INTEGER)
    INTO next_serial
    FROM "lab"."master_samples"
    WHERE "sample_id" ILIKE id_prefix || '%';

    IF next_serial IS NULL THEN
        next_serial := 1;
    ELSE
        next_serial := next_serial + 1;
    END IF;

    NEW.sample_id := id_prefix || next_serial::TEXT;
    INSERT INTO "lab"."master_samples" ("sample_id") VALUES (NEW.sample_id); -- Insert into master
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate child sample_id for Sediments
CREATE OR REPLACE FUNCTION "lab".generate_sediments_child_sample_id()
RETURNS TRIGGER AS $$
DECLARE
    parent_sample_id_exists text;
    sediments_abrv text;
    next_serial integer;
    id_prefix text;
BEGIN
    SELECT sample_id INTO parent_sample_id_exists FROM "lab"."master_samples" WHERE sample_id = NEW.parent_sample_id;
    IF parent_sample_id_exists IS NULL THEN
        RAISE EXCEPTION 'Parent_sample_id % does not exist in "lab"."master_samples" table.', NEW.parent_sample_id;
    END IF;

    SELECT sample_type_abrv INTO sediments_abrv FROM "reference"."samples_type" WHERE sample_type_id = 'Sediments';

    id_prefix := NEW.parent_sample_id || LOWER(sediments_abrv);

    SELECT MAX(SUBSTRING("sample_id" FROM LENGTH(id_prefix) + 1)::INTEGER)
    INTO next_serial
    FROM "lab"."master_samples"
    WHERE "sample_id" ILIKE id_prefix || '%';

    IF next_serial IS NULL THEN
        next_serial := 1;
    ELSE
        next_serial := next_serial + 1;
    END IF;

    NEW.sample_id := id_prefix || next_serial::TEXT;
    INSERT INTO "lab"."master_samples" ("sample_id") VALUES (NEW.sample_id); -- Insert into master
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate child sample_id for Water
CREATE OR REPLACE FUNCTION "lab".generate_water_child_sample_id()
RETURNS TRIGGER AS $$
DECLARE
    parent_sample_id_exists text;
    water_abrv text;
    next_serial integer;
    id_prefix text;
BEGIN
    SELECT sample_id INTO parent_sample_id_exists FROM "lab"."master_samples" WHERE sample_id = NEW.parent_sample_id;
    IF parent_sample_id_exists IS NULL THEN
        RAISE EXCEPTION 'Parent_sample_id % does not exist in "lab"."master_samples" table.', NEW.parent_sample_id;
    END IF;

    SELECT sample_type_abrv INTO water_abrv FROM "reference"."samples_type" WHERE sample_type_id = 'Water';

    id_prefix := NEW.parent_sample_id || LOWER(water_abrv);

    SELECT MAX(SUBSTRING("sample_id" FROM LENGTH(id_prefix) + 1)::INTEGER)
    INTO next_serial
    FROM "lab"."master_samples"
    WHERE "sample_id" ILIKE id_prefix || '%';

    IF next_serial IS NULL THEN
        next_serial := 1;
    ELSE
        next_serial := next_serial + 1;
    END IF;

    NEW.sample_id := id_prefix || next_serial::TEXT;
    INSERT INTO "lab"."master_samples" ("sample_id") VALUES (NEW.sample_id); -- Insert into master
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate otolith_id
CREATE OR REPLACE FUNCTION "lab".generate_otolith_id()
RETURNS TRIGGER AS $$
DECLARE
    parent_sample_id_exists text;
    otolith_abrv text := 'o';
    next_serial integer;
    id_prefix text;
BEGIN
    SELECT sample_id INTO parent_sample_id_exists FROM "lab"."master_samples" WHERE sample_id = NEW.sample_id;
    IF parent_sample_id_exists IS NULL THEN
        RAISE EXCEPTION 'Sample_id % does not exist in "lab"."master_samples" table.', NEW.sample_id;
    END IF;

    id_prefix := NEW.sample_id || LOWER(otolith_abrv);

    SELECT MAX(SUBSTRING("otolith_id" FROM LENGTH(id_prefix) + 1)::INTEGER)
    INTO next_serial
    FROM "lab"."otoliths"
    WHERE "otolith_id" ILIKE id_prefix || '%';

    IF next_serial IS NULL THEN
        next_serial := 1;
    ELSE
        next_serial := next_serial + 1;
    END IF;

    NEW.otolith_id := id_prefix || next_serial::TEXT;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate dissection_id
CREATE OR REPLACE FUNCTION "lab".generate_dissection_id()
RETURNS TRIGGER AS $$
DECLARE
    current_year text;
    next_serial integer;
    id_prefix text;
BEGIN
    current_year := TO_CHAR(COALESCE(NEW.dissection_date, CURRENT_DATE), 'YY');
    id_prefix := 'Dissection' || current_year;

    SELECT MAX(SUBSTRING("dissection_id" FROM LENGTH(id_prefix) + 1)::INTEGER)
    INTO next_serial
    FROM "lab"."dissections"
    WHERE "dissection_id" ILIKE id_prefix || '%';

    IF next_serial IS NULL THEN
        next_serial := 1;
    ELSE
        next_serial := next_serial + 1;
    END IF;

    NEW.dissection_id := id_prefix || LPAD(next_serial::TEXT, 5, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate extraction_id
CREATE OR REPLACE FUNCTION "lab".generate_extraction_id()
RETURNS TRIGGER AS $$
DECLARE
    current_year text;
    next_serial integer;
    id_prefix text;
BEGIN
    current_year := TO_CHAR(COALESCE(NEW.extraction_date, CURRENT_DATE), 'YY');
    id_prefix := 'Extraction' || current_year;

    SELECT MAX(SUBSTRING("extraction_id" FROM LENGTH(id_prefix) + 1)::INTEGER)
    INTO next_serial
    FROM "lab"."extraction"
    WHERE "extraction_id" ILIKE id_prefix || '%';

    IF next_serial IS NULL THEN
        next_serial := 1;
    ELSE
        next_serial := next_serial + 1;
    END IF;

    NEW.extraction_id := id_prefix || LPAD(next_serial::TEXT, 5, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate nanodrop_id
CREATE OR REPLACE FUNCTION "lab".generate_nanodrop_id()
RETURNS TRIGGER AS $$
DECLARE
    current_year text;
    next_serial integer;
    id_prefix text;
BEGIN
    current_year := TO_CHAR(COALESCE(NEW.measurement_date, CURRENT_DATE), 'YY');
    id_prefix := 'Nanodrop' || current_year;

    SELECT MAX(SUBSTRING("nanodrop_id" FROM LENGTH(id_prefix) + 1)::INTEGER)
    INTO next_serial
    FROM "lab"."nanodrop"
    WHERE "nanodrop_id" ILIKE id_prefix || '%';

    IF next_serial IS NULL THEN
        next_serial := 1;
    ELSE
        next_serial := next_serial + 1;
    END IF;

    NEW.nanodrop_id := id_prefix || LPAD(next_serial::TEXT, 4, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate qubit_id
CREATE OR REPLACE FUNCTION "lab".generate_qubit_id()
RETURNS TRIGGER AS $$
DECLARE
    current_year text;
    next_serial integer;
    id_prefix text;
BEGIN
    current_year := TO_CHAR(COALESCE(NEW.measurement_date, CURRENT_DATE), 'YY');
    id_prefix := 'Qubit' || current_year;

    SELECT MAX(SUBSTRING("qubit_id" FROM LENGTH(id_prefix) + 1)::INTEGER)
    INTO next_serial
    FROM "lab"."qubit"
    WHERE "qubit_id" ILIKE id_prefix || '%';

    IF next_serial IS NULL THEN
        next_serial := 1;
    ELSE
        next_serial := next_serial + 1;
    END IF;

    NEW.qubit_id := id_prefix || LPAD(next_serial::TEXT, 5, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate tapestation_id
CREATE OR REPLACE FUNCTION "lab".generate_tapestation_id()
RETURNS TRIGGER AS $$
DECLARE
    current_year text;
    next_serial integer;
    id_prefix text;
BEGIN
    current_year := TO_CHAR(COALESCE(NEW.measurement_date, CURRENT_DATE), 'YY');
    id_prefix := 'Tape' || current_year;

    SELECT MAX(SUBSTRING("tapestation_id" FROM LENGTH(id_prefix) + 1)::INTEGER)
    INTO next_serial
    FROM "lab"."tapestation"
    WHERE "tapestation_id" ILIKE id_prefix || '%';

    IF next_serial IS NULL THEN
        next_serial := 1;
    ELSE
        next_serial := next_serial + 1;
    END IF;

    NEW.tapestation_id := id_prefix || LPAD(next_serial::TEXT, 5, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate pcr_id
CREATE OR REPLACE FUNCTION "lab".generate_pcr_id()
RETURNS TRIGGER AS $$
DECLARE
    next_serial integer;
    id_prefix text;
BEGIN
    id_prefix := 'PCR_' || NEW.experiment_id || '_' || NEW.sample_id || '_';

    SELECT MAX(SUBSTRING("pcr_id" FROM LENGTH(id_prefix) + 1)::INTEGER)
    INTO next_serial
    FROM "lab"."pcr"
    WHERE "pcr_id" ILIKE id_prefix || '%';

    IF next_serial IS NULL THEN
        next_serial := 1;
    ELSE
        next_serial := next_serial + 1;
    END IF;

    NEW.pcr_id := id_prefix || LPAD(next_serial::TEXT, 3, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate gelelectrophoresis_id
CREATE OR REPLACE FUNCTION "lab".generate_gelelectrophoresis_id()
RETURNS TRIGGER AS $$
DECLARE
    next_serial integer;
    id_prefix text;
BEGIN
    id_prefix := 'GEL_' || NEW.experiment_id || '_' || NEW.sample_id || '_';

    SELECT MAX(SUBSTRING("gelelectrophoresis_id" FROM LENGTH(id_prefix) + 1)::INTEGER)
    INTO next_serial
    FROM "lab"."gelelectrophoresis"
    WHERE "gelelectrophoresis_id" ILIKE id_prefix || '%';

    IF next_serial IS NULL THEN
        next_serial := 1;
    ELSE
        next_serial := next_serial + 1;
    END IF;

    NEW.gelelectrophoresis_id := id_prefix || LPAD(next_serial::TEXT, 3, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate qpcr_id
CREATE OR REPLACE FUNCTION "lab".generate_qpcr_id()
RETURNS TRIGGER AS $$
DECLARE
    next_serial integer;
    id_prefix text;
BEGIN
    id_prefix := 'QPCR_' || NEW.experiment_id || '_' || NEW.sample_id || '_';

    SELECT MAX(SUBSTRING("qpcr_id" FROM LENGTH(id_prefix) + 1)::INTEGER)
    INTO next_serial
    FROM "lab"."qpcr"
    WHERE "qpcr_id" ILIKE id_prefix || '%';

    IF next_serial IS NULL THEN
        next_serial := 1;
    ELSE
        next_serial := next_serial + 1;
    END IF;

    NEW.qpcr_id := id_prefix || LPAD(next_serial::TEXT, 3, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate library_id
CREATE OR REPLACE FUNCTION "lab".generate_library_id()
RETURNS TRIGGER AS $$
DECLARE
    next_serial integer;
    id_prefix text;
BEGIN
    id_prefix := 'LIB_' || NEW.experiment_id || '_' || NEW.sample_id || '_';

    SELECT MAX(SUBSTRING("library_id" FROM LENGTH(id_prefix) + 1)::INTEGER)
    INTO next_serial
    FROM "lab"."library"
    WHERE "library_id" ILIKE id_prefix || '%';

    IF next_serial IS NULL THEN
        next_serial := 1;
    ELSE
        next_serial := next_serial + 1;
    END IF;

    NEW.library_id := id_prefix || LPAD(next_serial::TEXT, 3, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate sequencing_id
CREATE OR REPLACE FUNCTION "lab".generate_sequencing_id()
RETURNS TRIGGER AS $$
DECLARE
    next_serial integer;
    id_prefix text;
BEGIN
    id_prefix := 'SEQ_' || NEW.experiment_id || '_' || NEW.sample_id || '_';

    SELECT MAX(SUBSTRING("sequencing_id" FROM LENGTH(id_prefix) + 1)::INTEGER)
    INTO next_serial
    FROM "lab"."sequencing"
    WHERE "sequencing_id" ILIKE id_prefix || '%';

    IF next_serial IS NULL THEN
        next_serial := 1;
    ELSE
        next_serial := next_serial + 1;
    END IF;

    NEW.sequencing_id := id_prefix || LPAD(next_serial::TEXT, 3, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate dataset_id
CREATE OR REPLACE FUNCTION "lab".generate_dataset_id()
RETURNS TRIGGER AS $$
DECLARE
    current_year text;
    customer_abrv text := '-';
    ecosystem_abrv text := '-';
    region_abrv text := '-';
    dataset_abrv text;
    id_prefix text;
    next_serial integer;
BEGIN
    current_year := TO_CHAR(COALESCE(NEW.reception_date, CURRENT_DATE), 'YY');
    SELECT sample_type_abrv INTO dataset_abrv FROM "reference"."samples_type" WHERE sample_type_id = 'Dataset';

    IF NEW.customer_id IS NOT NULL THEN
        SELECT c.customer_abrv INTO customer_abrv
        FROM "lims"."customers" c
        WHERE c.customer_id = NEW.customer_id;
        id_prefix := dataset_abrv || current_year || customer_abrv;
    ELSE
        SELECT COALESCE(e.ecosystem_abrv, '-') INTO ecosystem_abrv
        FROM "reference"."ecosystem" e
        WHERE e.ecosystem_id = NEW.ecosystem_id;

        SELECT COALESCE(r.region_abrv, '-') INTO region_abrv
        FROM "reference"."region" r
        WHERE r.region_id = NEW.region_id;

        id_prefix := dataset_abrv || current_year || ecosystem_abrv || region_abrv;
    END IF;

    SELECT MAX(SUBSTRING("dataset_id" FROM LENGTH(id_prefix) + 1)::INTEGER)
    INTO next_serial
    FROM "lab"."datasets"
    WHERE "dataset_id" ILIKE id_prefix || '%';

    IF next_serial IS NULL THEN
        next_serial := 1;
    ELSE
        next_serial := next_serial + 1;
    END IF;

    NEW.dataset_id := id_prefix || LPAD(next_serial::TEXT, 4, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate pipeline_id
CREATE OR REPLACE FUNCTION "bioinformatics".generate_pipeline_id()
RETURNS TRIGGER AS $$
DECLARE
    current_year text;
    next_serial integer;
    id_prefix text;
BEGIN
    current_year := TO_CHAR(CURRENT_DATE, 'YY');
    id_prefix := current_year;

    SELECT MAX(SUBSTRING("pipeline_id" FROM LENGTH(id_prefix) + 1)::INTEGER)
    INTO next_serial
    FROM "bioinformatics"."analysis_pipelines"
    WHERE "pipeline_id" ILIKE id_prefix || '%';

    IF next_serial IS NULL THEN
        next_serial := 1;
    ELSE
        next_serial := next_serial + 1;
    END IF;

    NEW.pipeline_id := id_prefix || LPAD(next_serial::TEXT, 6, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate analysis_run_id
CREATE OR REPLACE FUNCTION "bioinformatics".generate_analysis_run_id()
RETURNS TRIGGER AS $$
DECLARE
    current_year text;
    next_serial integer;
    id_prefix text;
BEGIN
    current_year := TO_CHAR(COALESCE(NEW.run_date, CURRENT_TIMESTAMP), 'YY');
    id_prefix := current_year;

    SELECT MAX(SUBSTRING("run_id" FROM LENGTH(id_prefix) + 1)::INTEGER)
    INTO next_serial
    FROM "bioinformatics"."analysis_runs"
    WHERE "run_id" ILIKE id_prefix || '%';

    IF next_serial IS NULL THEN
        next_serial := 1;
    ELSE
        next_serial := next_serial + 1;
    END IF;

    NEW.run_id := id_prefix || LPAD(next_serial::TEXT, 6, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate edna_assignment_id
CREATE OR REPLACE FUNCTION "bioinformatics".generate_edna_assignment_id()
RETURNS TRIGGER AS $$
DECLARE
    current_year text;
    next_serial integer;
    id_prefix text;
BEGIN
    current_year := TO_CHAR(CURRENT_DATE, 'YY');
    id_prefix := current_year;

    SELECT MAX(SUBSTRING("assignment_id" FROM LENGTH(id_prefix) + 1)::INTEGER)
    INTO next_serial
    FROM "bioinformatics"."edna_assignments"
    WHERE "assignment_id" ILIKE id_prefix || '%';

    IF next_serial IS NULL THEN
        next_serial := 1;
    ELSE
        next_serial := next_serial + 1;
    END IF;

    NEW.assignment_id := id_prefix || LPAD(next_serial::TEXT, 6, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to update sample status in 'lab.samples'
CREATE OR REPLACE FUNCTION "lab".update_sample_status()
RETURNS TRIGGER AS $$
DECLARE
    new_status text := TG_ARGV[0];
    target_sample_id text;
    target_sample_sampling_date date;
BEGIN
    target_sample_id := NEW.sample_id;

    IF NEW.sampling_date IS NOT NULL THEN
        target_sample_sampling_date := NEW.sampling_date;
    ELSE
        SELECT s.sampling_date INTO target_sample_sampling_date
        FROM "lab"."samples" s
        WHERE s.sample_id = target_sample_id;

        IF target_sample_sampling_date IS NULL THEN
            RAISE WARNING 'Could not determine sampling_date for sample_id % to update status in lab.samples. Status not updated.', target_sample_id;
            RETURN NEW;
        END IF;
    END IF;

    IF target_sample_id IS NOT NULL AND target_sample_sampling_date IS NOT NULL THEN
        UPDATE "lab"."samples"
        SET "sample_status_id" = new_status
        WHERE "sample_id" = target_sample_id
          AND "sampling_date" = target_sample_sampling_date;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate protocol_run_id
CREATE OR REPLACE FUNCTION "lab".generate_protocol_run_id()
RETURNS TRIGGER AS $$
DECLARE
    experiment_title_part text;
    next_serial integer;
    id_prefix text;
BEGIN
    SELECT REPLACE(LOWER(e.experiment_title), ' ', '_') INTO experiment_title_part
    FROM "lab"."experiments" e
    WHERE e.experiment_id = NEW.experiment_id;

    IF experiment_title_part IS NULL THEN
        RAISE EXCEPTION 'Experiment ID % not found for protocol run ID generation.', NEW.experiment_id;
    END IF;

    id_prefix := experiment_title_part || '_p_';

    SELECT MAX(SUBSTRING("protocol_run_id" FROM LENGTH(id_prefix) + 1)::INTEGER)
    INTO next_serial
    FROM "lab"."protocol_runs"
    WHERE "protocol_run_id" ILIKE id_prefix || '%';

    IF next_serial IS NULL THEN
        next_serial := 1;
    ELSE
        next_serial := next_serial + 1;
    END IF;

    NEW.protocol_run_id := id_prefix || LPAD(next_serial::TEXT, 3, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to update ltree paths in reference.taxon
CREATE OR REPLACE FUNCTION "reference".update_taxon_ltree_paths()
RETURNS VOID AS $$
BEGIN
    WITH RECURSIVE taxon_paths AS (
        SELECT taxon_id, taxon_id::TEXT AS path
        FROM "reference"."taxon"
        WHERE taxon_parent IS NULL

        UNION ALL

        SELECT t.taxon_id, (p.path || '.' || t.taxon_id)
        FROM taxon_paths p
        JOIN "reference"."taxon" t ON t.taxon_parent = p.taxon_id
    )
    UPDATE "reference"."taxon" t
    SET path = tp.path::ltree
    FROM taxon_paths tp
    WHERE t.taxon_id = tp.taxon_id;
END;
$$ LANGUAGE plpgsql;

-- Function to check if the current user is part of a project (for RLS)
CREATE OR REPLACE FUNCTION "lims".is_member_of_project(p_project_id text)
RETURNS BOOLEAN AS $$
DECLARE
    current_person_id text := current_setting('lims.current_person_id', true);
BEGIN
    IF current_person_id IS NULL THEN
        RETURN FALSE;
    END IF;

    RETURN EXISTS (
        SELECT 1 FROM "lims"."projects" WHERE project_id = p_project_id AND pi_person_id = current_person_id
    ) OR EXISTS (
        SELECT 1 FROM "lims"."project_persons" WHERE project_id = p_project_id AND person_id = current_person_id
    );
END;
$$ LANGUAGE plpgsql STABLE;

-- Specific Full-Text Search Trigger Functions
CREATE OR REPLACE FUNCTION "lims".update_customer_search_vector_func()
RETURNS TRIGGER AS $$
BEGIN
    NEW.customer_search_vector =
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.customer_name, '')) ||
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.notes, ''));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "lab".update_sample_search_vector_func()
RETURNS TRIGGER AS $$
BEGIN
    NEW.sample_search_vector =
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.external_name, '')) ||
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.notes, ''));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "lims".update_sop_search_vector_func()
RETURNS TRIGGER AS $$
BEGIN
    NEW.sop_search_vector =
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.title, '')) ||
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.sop_protocol, '')) ||
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.notes, ''));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "lab".update_experiment_search_vector_func()
RETURNS TRIGGER AS $$
BEGIN
    NEW.experiment_search_vector =
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.experiment_title, '')) ||
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.aim, '')) ||
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.method, '')) ||
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.notes, ''));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to validate sample's sampling_date is within parent sampling record's dates
CREATE OR REPLACE FUNCTION "lab".validate_sample_sampling_date()
RETURNS TRIGGER AS $$
DECLARE
    sampling_event_date date;
BEGIN
    IF NEW.sampling_id IS NOT NULL THEN
        SELECT sampling_date INTO sampling_event_date
        FROM "lab"."sampling"
        WHERE sampling_id = NEW.sampling_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Referenced sampling_id % does not exist in "lab"."sampling".', NEW.sampling_id;
        END IF;

        IF NEW.sampling_date IS NOT NULL AND NEW.sampling_date != sampling_event_date THEN
            RAISE EXCEPTION 'Sample sampling_date (%) must match parent sampling event date (%).', NEW.sampling_date, sampling_event_date;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Helper function to create partitions dynamically for lab.sampling
CREATE OR REPLACE FUNCTION "lab".create_sampling_partition_if_not_exists()
RETURNS TRIGGER AS $$
DECLARE
    partition_date date;
    partition_name text;
    start_date date;
    end_date date;
BEGIN
    partition_date := NEW.sampling_date;
    IF partition_date IS NULL THEN
        RAISE EXCEPTION 'Cannot partition on NULL sampling_date. Please provide a sampling_date.';
    END IF;

    start_date := DATE_TRUNC('year', partition_date);
    end_date := DATE_TRUNC('year', partition_date) + INTERVAL '1 year';
    partition_name := 'sampling_y' || TO_CHAR(start_date, 'YYYY');

    EXECUTE 'CREATE TABLE IF NOT EXISTS "lab".' || quote_ident(partition_name) || ' PARTITION OF "lab"."sampling"
             FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Helper function for manual partition creation for lab.sampling
CREATE OR REPLACE FUNCTION "lab".create_sampling_partition_if_not_exists_manual(p_year integer)
RETURNS VOID AS $$
DECLARE
    start_date date;
    end_date date;
    partition_name text;
BEGIN
    start_date := MAKE_DATE(p_year, 1, 1);
    end_date := MAKE_DATE(p_year + 1, 1, 1);
    partition_name := 'sampling_y' || p_year;

    EXECUTE 'CREATE TABLE IF NOT EXISTS "lab".' || quote_ident(partition_name) || ' PARTITION OF "lab"."sampling"
             FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';
END;
$$ LANGUAGE plpgsql;

-- Helper function to create partitions dynamically for lab.samples
CREATE OR REPLACE FUNCTION "lab".create_samples_partition_if_not_exists()
RETURNS TRIGGER AS $$
DECLARE
    partition_date date;
    partition_name text;
    start_date date;
    end_date date;
BEGIN
    partition_date := NEW.sampling_date;
    IF partition_date IS NULL THEN
        RAISE EXCEPTION 'Cannot partition on NULL sampling_date for lab.samples. Please provide a sampling_date.';
    END IF;

    start_date := DATE_TRUNC('year', partition_date);
    end_date := DATE_TRUNC('year', partition_date) + INTERVAL '1 year';
    partition_name := 'samples_y' || TO_CHAR(start_date, 'YYYY');

    EXECUTE 'CREATE TABLE IF NOT EXISTS "lab".' || quote_ident(partition_name) || ' PARTITION OF "lab"."samples"
             FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Helper function for manual partition creation for lab.samples
CREATE OR REPLACE FUNCTION "lab".create_samples_partition_if_not_exists_manual(p_year integer)
RETURNS VOID AS $$
DECLARE
    start_date date;
    end_date date;
    partition_name text;
BEGIN
    start_date := MAKE_DATE(p_year, 1, 1);
    end_date := MAKE_DATE(p_year + 1, 1, 1);
    partition_name := 'samples_y' || p_year;

    EXECUTE 'CREATE TABLE IF NOT EXISTS "lab".' || quote_ident(partition_name) || ' PARTITION OF "lab"."samples"
             FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';
END;
$$ LANGUAGE plpgsql;

-- ======================================================================
-- 10. Triggers
-- ======================================================================

-- Audit Triggers (apply to all tables you want to audit)
CREATE TRIGGER audit_trigger_personal
AFTER INSERT OR UPDATE OR DELETE ON "reference"."personal"
FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_status
AFTER INSERT OR UPDATE OR DELETE ON "reference"."status"
FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_room
AFTER INSERT OR UPDATE OR DELETE ON "reference"."room"
FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_vessel
AFTER INSERT OR UPDATE OR DELETE ON "reference"."vessel"
FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_region
AFTER INSERT OR UPDATE OR DELETE ON "reference"."region"
FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_ecosystem
AFTER INSERT OR UPDATE OR DELETE ON "reference"."ecosystem"
FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_category
AFTER INSERT OR UPDATE OR DELETE ON "reference"."category"
FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_samples_type
AFTER INSERT OR UPDATE OR DELETE ON "reference"."samples_type"
FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_gene
AFTER INSERT OR UPDATE OR DELETE ON "reference"."gene"
FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_taxon
AFTER INSERT OR UPDATE OR DELETE ON "reference"."taxon"
FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_species
AFTER INSERT OR UPDATE OR DELETE ON "reference"."species"
FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_units
AFTER INSERT OR UPDATE OR DELETE ON "reference"."units"
FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_external_contacts
AFTER INSERT OR UPDATE OR DELETE ON "lims"."external_contacts"
FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_customers
AFTER INSERT OR UPDATE OR DELETE ON "lims"."customers"
FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_projects
AFTER INSERT OR UPDATE OR DELETE ON "lims"."projects"
FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_project_persons
AFTER INSERT OR UPDATE OR DELETE ON "lims"."project_persons"
FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_cruises
AFTER INSERT OR UPDATE OR DELETE ON "lims"."cruises"
FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_workflows
AFTER INSERT OR UPDATE OR DELETE ON "lims"."workflows"
FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_permits
AFTER INSERT OR UPDATE OR DELETE ON "lims"."permits"
FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_primers
AFTER INSERT OR UPDATE OR DELETE ON "lims"."primers"
FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_sop
AFTER INSERT OR UPDATE OR DELETE ON "lims"."sop"
FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_workflow_steps
AFTER INSERT OR UPDATE OR DELETE ON "lims"."workflow_steps"
FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_equipment
AFTER INSERT OR UPDATE OR DELETE ON "lims"."equipment"
FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_suppliers
AFTER INSERT OR UPDATE OR DELETE ON "lims"."suppliers"
FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_inventory_items
AFTER INSERT OR UPDATE OR DELETE ON "lims"."inventory_items"
FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_orders
AFTER INSERT OR UPDATE OR DELETE ON "lims"."orders"
FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_reagents
AFTER INSERT OR UPDATE OR DELETE ON "lims"."reagents"
FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_publications
AFTER INSERT OR UPDATE OR DELETE ON "lims"."publications"
FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_storage
AFTER INSERT OR UPDATE OR DELETE ON "lab"."storage"
FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_experiments
AFTER INSERT OR UPDATE OR DELETE ON "lab"."experiments"
FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_experiments_projects
AFTER INSERT OR UPDATE OR DELETE ON "lab"."experiments_projects"
FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_protocol_runs
AFTER INSERT OR UPDATE OR DELETE ON "lab"."protocol_runs"
FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_sampling
AFTER INSERT OR UPDATE OR DELETE ON "lab"."sampling"
FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_fishing
AFTER INSERT OR UPDATE OR DELETE ON "lab"."fishing"
FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_master_samples
AFTER INSERT OR UPDATE OR DELETE ON "lab"."master_samples"
FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_samples
AFTER INSERT OR UPDATE OR DELETE ON "lab"."samples"
FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_storage_log
AFTER INSERT OR UPDATE OR DELETE ON "lab"."storage_log"
FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_fish
AFTER INSERT OR UPDATE OR DELETE ON "lab"."fish"
FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_tissue
AFTER INSERT OR UPDATE OR DELETE ON "lab"."tissue"
FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_otoliths
AFTER INSERT OR UPDATE OR DELETE ON "lab"."otoliths"
FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_dna
AFTER INSERT OR UPDATE OR DELETE ON "lab"."dna"
FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_rna
AFTER INSERT OR UPDATE OR DELETE ON "lab"."rna"
FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_sediments
AFTER INSERT OR UPDATE OR DELETE ON "lab"."sediments"
FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_water
AFTER INSERT OR UPDATE OR DELETE ON "lab"."water"
FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_experiments_samples
AFTER INSERT OR UPDATE OR DELETE ON "lab"."experiments_samples"
FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_dissections
AFTER INSERT OR UPDATE OR DELETE ON "lab"."dissections"
FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_extraction
AFTER INSERT OR UPDATE OR DELETE ON "lab"."extraction"
FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_nanodrop
AFTER INSERT OR UPDATE OR DELETE ON "lab"."nanodrop"
FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_qubit
AFTER INSERT OR UPDATE OR DELETE ON "lab"."qubit"
FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_tapestation
AFTER INSERT OR UPDATE OR DELETE ON "lab"."tapestation"
FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_pcr
AFTER INSERT OR UPDATE OR DELETE ON "lab"."pcr"
FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_gelelectrophoresis
AFTER INSERT OR UPDATE OR DELETE ON "lab"."gelelectrophoresis"
FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_qpcr
AFTER INSERT OR UPDATE OR DELETE ON "lab"."qpcr"
FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_library
AFTER INSERT OR UPDATE OR DELETE ON "lab"."library"
FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_sequencing
AFTER INSERT OR UPDATE OR DELETE ON "lab"."sequencing"
FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_datasets
AFTER INSERT OR UPDATE OR DELETE ON "lab"."datasets"
FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_reference_databases
AFTER INSERT OR UPDATE OR DELETE ON "bioinformatics"."reference_databases"
FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_analysis_pipelines
AFTER INSERT OR UPDATE OR DELETE ON "bioinformatics"."analysis_pipelines"
FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_analysis_runs
AFTER INSERT OR UPDATE OR DELETE ON "bioinformatics"."analysis_runs"
FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_edna_assignments
AFTER INSERT OR UPDATE OR DELETE ON "bioinformatics"."edna_assignments"
FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();


-- Triggers for ID generation (BEFORE INSERT)
CREATE TRIGGER trg_generate_customer_id BEFORE INSERT ON "lims"."customers" FOR EACH ROW EXECUTE FUNCTION "lims".generate_customer_id();
CREATE TRIGGER trg_generate_publication_id BEFORE INSERT ON "lims"."publications" FOR EACH ROW EXECUTE FUNCTION "lims".generate_publication_id();
CREATE TRIGGER trg_generate_sop_id BEFORE INSERT ON "lims"."sop" FOR EACH ROW EXECUTE FUNCTION "lims".generate_sop_id();
CREATE TRIGGER trg_generate_workflow_step_id BEFORE INSERT ON "lims"."workflow_steps" FOR EACH ROW EXECUTE FUNCTION "lims".generate_workflow_step_id();
CREATE TRIGGER trg_generate_sampling_id BEFORE INSERT ON "lab"."sampling" FOR EACH ROW EXECUTE FUNCTION "lab".generate_sampling_id();
CREATE TRIGGER trg_generate_fishing_id BEFORE INSERT ON "lab"."fishing" FOR EACH ROW EXECUTE FUNCTION "lab".generate_fishing_id();
CREATE TRIGGER trg_generate_sample_id BEFORE INSERT ON "lab"."samples" FOR EACH ROW EXECUTE FUNCTION "lab".generate_sample_id(); -- This now inserts into master_samples too
CREATE TRIGGER trg_generate_fish_child_sample_id BEFORE INSERT ON "lab"."fish" FOR EACH ROW EXECUTE FUNCTION "lab".generate_fish_child_sample_id();
CREATE TRIGGER trg_generate_tissue_child_sample_id BEFORE INSERT ON "lab"."tissue" FOR EACH ROW EXECUTE FUNCTION "lab".generate_tissue_child_sample_id();
CREATE TRIGGER trg_generate_dna_child_sample_id BEFORE INSERT ON "lab"."dna" FOR EACH ROW EXECUTE FUNCTION "lab".generate_dna_child_sample_id();
CREATE TRIGGER trg_generate_rna_child_sample_id BEFORE INSERT ON "lab"."rna" FOR EACH ROW EXECUTE FUNCTION "lab".generate_rna_child_sample_id();
CREATE TRIGGER trg_generate_sediments_child_sample_id BEFORE INSERT ON "lab"."sediments" FOR EACH ROW EXECUTE FUNCTION "lab".generate_sediments_child_sample_id();
CREATE TRIGGER trg_generate_water_child_sample_id BEFORE INSERT ON "lab"."water" FOR EACH ROW EXECUTE FUNCTION "lab".generate_water_child_sample_id();
CREATE TRIGGER trg_generate_otolith_id BEFORE INSERT ON "lab"."otoliths" FOR EACH ROW EXECUTE FUNCTION "lab".generate_otolith_id();
CREATE TRIGGER trg_generate_dissection_id BEFORE INSERT ON "lab"."dissections" FOR EACH ROW EXECUTE FUNCTION "lab".generate_dissection_id();
CREATE TRIGGER trg_generate_extraction_id BEFORE INSERT ON "lab"."extraction" FOR EACH ROW EXECUTE FUNCTION "lab".generate_extraction_id();
CREATE TRIGGER trg_generate_nanodrop_id BEFORE INSERT ON "lab"."nanodrop" FOR EACH ROW EXECUTE FUNCTION "lab".generate_nanodrop_id();
CREATE TRIGGER trg_generate_qubit_id BEFORE INSERT ON "lab"."qubit" FOR EACH ROW EXECUTE FUNCTION "lab".generate_qubit_id();
CREATE TRIGGER trg_generate_tapestation_id BEFORE INSERT ON "lab"."tapestation" FOR EACH ROW EXECUTE FUNCTION "lab".generate_tapestation_id();
CREATE TRIGGER trg_generate_pcr_id BEFORE INSERT ON "lab"."pcr" FOR EACH ROW EXECUTE FUNCTION "lab".generate_pcr_id();
CREATE TRIGGER trg_generate_gelelectrophoresis_id BEFORE INSERT ON "lab"."gelelectrophoresis" FOR EACH ROW EXECUTE FUNCTION "lab".generate_gelelectrophoresis_id();
CREATE TRIGGER trg_generate_qpcr_id BEFORE INSERT ON "lab"."qpcr" FOR EACH ROW EXECUTE FUNCTION "lab".generate_qpcr_id();
CREATE TRIGGER trg_generate_library_id BEFORE INSERT ON "lab"."library" FOR EACH ROW EXECUTE FUNCTION "lab".generate_library_id();
CREATE TRIGGER trg_generate_sequencing_id BEFORE INSERT ON "lab"."sequencing" FOR EACH ROW EXECUTE FUNCTION "lab".generate_sequencing_id();
CREATE TRIGGER trg_generate_dataset_id BEFORE INSERT ON "lab"."datasets" FOR EACH ROW EXECUTE FUNCTION "lab".generate_dataset_id();
CREATE TRIGGER trg_generate_pipeline_id BEFORE INSERT ON "bioinformatics"."analysis_pipelines" FOR EACH ROW EXECUTE FUNCTION "bioinformatics".generate_pipeline_id();
CREATE TRIGGER trg_generate_analysis_run_id BEFORE INSERT ON "bioinformatics"."analysis_runs" FOR EACH ROW EXECUTE FUNCTION "bioinformatics".generate_analysis_run_id();
CREATE TRIGGER trg_generate_edna_assignment_id BEFORE INSERT ON "bioinformatics"."edna_assignments" FOR EACH ROW EXECUTE FUNCTION "bioinformatics".generate_edna_assignment_id();
CREATE TRIGGER trg_generate_protocol_run_id BEFORE INSERT ON "lab"."protocol_runs" FOR EACH ROW EXECUTE FUNCTION "lab".generate_protocol_run_id();


-- Triggers to update workflow status in lab.samples
-- These triggers must target lab.samples based on sample_id and sampling_date
CREATE TRIGGER trg_update_status_dissection AFTER INSERT ON "lab"."dissections" FOR EACH ROW EXECUTE PROCEDURE "lab".update_sample_status('Dissection');
CREATE TRIGGER trg_update_status_extraction AFTER INSERT ON "lab"."extraction" FOR EACH ROW EXECUTE PROCEDURE "lab".update_sample_status('Extracted');
CREATE TRIGGER trg_update_status_nanodrop AFTER INSERT ON "lab"."nanodrop" FOR EACH ROW EXECUTE PROCEDURE "lab".update_sample_status('Nanodrop QC');
CREATE TRIGGER trg_update_status_qubit AFTER INSERT ON "lab"."qubit" FOR EACH ROW EXECUTE PROCEDURE "lab".update_sample_status('Qubit QC');
CREATE TRIGGER trg_update_status_tapestation AFTER INSERT ON "lab"."tapestation" FOR EACH ROW EXECUTE PROCEDURE "lab".update_sample_status('Tapestation QC');
CREATE TRIGGER trg_update_status_pcr AFTER INSERT ON "lab"."pcr" FOR EACH ROW EXECUTE PROCEDURE "lab".update_sample_status('PCR Done');
CREATE TRIGGER trg_update_status_qpcr AFTER INSERT ON "lab"."qpcr" FOR EACH ROW EXECUTE PROCEDURE "lab".update_sample_status('qPCR Done');
CREATE TRIGGER trg_update_status_library AFTER INSERT ON "lab"."library" FOR EACH ROW EXECUTE PROCEDURE "lab".update_sample_status('Library Prep');
CREATE TRIGGER trg_update_status_sequencing AFTER INSERT ON "lab"."sequencing" FOR EACH ROW EXECUTE PROCEDURE "lab".update_sample_status('Sequencing Done');
CREATE TRIGGER trg_update_status_bioinformatics AFTER INSERT ON "bioinformatics"."analysis_runs" FOR EACH ROW EXECUTE PROCEDURE "lab".update_sample_status('Bioinformatics Done');

-- Trigger for sample date validation
CREATE TRIGGER trg_validate_sample_sampling_date
BEFORE INSERT OR UPDATE ON "lab"."samples"
FOR EACH ROW
EXECUTE FUNCTION "lab".validate_sample_sampling_date();

-- Triggers for automatic partition creation
CREATE TRIGGER trg_create_sampling_partition
BEFORE INSERT ON "lab"."sampling"
FOR EACH ROW
EXECUTE FUNCTION "lab".create_sampling_partition_if_not_exists();

CREATE TRIGGER trg_create_samples_partition
BEFORE INSERT ON "lab"."samples"
FOR EACH ROW
EXECUTE FUNCTION "lab".create_samples_partition_if_not_exists();

-- ======================================================================
-- 11. Indexes
-- ======================================================================

-- Reference Schema Indexes
CREATE INDEX IF NOT EXISTS idx_personal_full_name ON "reference"."personal" ("full_name");
CREATE INDEX IF NOT EXISTS idx_taxon_path_gist ON "reference"."taxon" USING GIST ("path");
CREATE INDEX IF NOT EXISTS idx_species_de_name ON "reference"."species" ("de_name");
CREATE INDEX IF NOT EXISTS idx_species_en_name ON "reference"."species" ("en_name");
CREATE INDEX IF NOT EXISTS idx_units_unit_type ON "reference"."units" ("unit_type");
CREATE INDEX IF NOT EXISTS idx_external_contacts_full_name ON "lims"."external_contacts" ("full_name");


-- Lims Schema Indexes
CREATE INDEX IF NOT EXISTS idx_customers_customer_name ON "lims"."customers" ("customer_name");
CREATE INDEX IF NOT EXISTS idx_customers_customer_abrv ON "lims"."customers" ("customer_abrv");
CREATE INDEX IF NOT EXISTS idx_projects_status_id ON "lims"."projects" ("status_id");
CREATE INDEX IF NOT EXISTS idx_projects_pi_person_id ON "lims"."projects" ("pi_person_id");
CREATE INDEX IF NOT EXISTS idx_projects_customer_id ON "lims"."projects" ("customer_id");
CREATE INDEX IF NOT EXISTS idx_cruises_project_id ON "lims"."cruises" ("project_id");
CREATE INDEX IF NOT EXISTS idx_cruises_region_id ON "lims"."cruises" ("region_id");
CREATE INDEX IF NOT EXISTS idx_cruises_ecosystem_id ON "lims"."cruises" ("ecosystem_id");
CREATE INDEX IF NOT EXISTS idx_cruises_capitaine_contact_id ON "lims"."cruises" ("capitaine_contact_id");
CREATE INDEX IF NOT EXISTS idx_cruises_together_with_contact_id ON "lims"."cruises" ("together_with_contact_id");
CREATE INDEX IF NOT EXISTS idx_workflow_steps_workflow_id ON "lims"."workflow_steps" ("workflow_id");
CREATE INDEX IF NOT EXISTS idx_sop_sop_id_origin ON "lims"."sop" ("sop_id_origin");
CREATE INDEX IF NOT EXISTS idx_primers_target_gene_id ON "lims"."primers" ("target_gene_id");
CREATE INDEX IF NOT EXISTS idx_equipment_room_id ON "lims"."equipment" ("room_id");
CREATE INDEX IF NOT EXISTS idx_suppliers_supplier_name ON "lims"."suppliers" ("supplier_name");
CREATE INDEX IF NOT EXISTS idx_inventory_items_category_id ON "lims"."inventory_items" ("category_id");
CREATE INDEX IF NOT EXISTS idx_orders_project_id ON "lims"."orders" ("project_id");
CREATE INDEX IF NOT EXISTS idx_orders_category_id ON "lims"."orders" ("category_id");
CREATE INDEX IF NOT EXISTS idx_orders_supplier_id ON "lims"."orders" ("supplier_id");
CREATE INDEX IF NOT EXISTS idx_orders_item_id ON "lims"."orders" ("item_id");
CREATE INDEX IF NOT EXISTS idx_reagents_category_id ON "lims"."reagents" ("category_id");
CREATE INDEX IF NOT EXISTS idx_reagents_storage_id ON "lims"."reagents" ("storage_id");
CREATE INDEX IF NOT EXISTS idx_reagents_expire_date ON "lims"."reagents" ("expire_date");
CREATE INDEX IF NOT EXISTS idx_publications_project_id ON "lims"."publications" ("project_id");
CREATE INDEX IF NOT EXISTS idx_publications_doi ON "lims"."publications" ("doi");


-- Lab Schema Indexes
CREATE INDEX IF NOT EXISTS idx_experiments_sop_id ON "lab"."experiments" ("sop_id");
CREATE INDEX IF NOT EXISTS idx_experiments_person_id ON "lab"."experiments" ("person_id");
CREATE INDEX IF NOT EXISTS idx_experiments_projects_experiment_id ON "lab"."experiments_projects" ("experiment_id");
CREATE INDEX IF NOT EXISTS idx_experiments_projects_project_id ON "lab"."experiments_projects" ("project_id");
CREATE INDEX IF NOT EXISTS idx_protocol_runs_experiment_id ON "lab"."protocol_runs" ("experiment_id");
CREATE INDEX IF NOT EXISTS idx_protocol_runs_sop_id ON "lab"."protocol_runs" ("sop_id");
CREATE INDEX IF NOT EXISTS idx_sampling_project_id ON "lab"."sampling" ("project_id");
CREATE INDEX IF NOT EXISTS idx_sampling_cruise_id ON "lab"."sampling" ("cruise_id");
CREATE INDEX IF NOT EXISTS idx_sampling_region_id ON "lab"."sampling" ("region_id");
CREATE INDEX IF NOT EXISTS idx_sampling_ecosystem_id ON "reference"."ecosystem" ("ecosystem_id"); -- Corrected from "reference"."ecosystem"
CREATE INDEX IF NOT EXISTS idx_sampling_customer_id ON "lims"."customers" ("customer_id"); -- Corrected from "lims"."customers"
CREATE INDEX IF NOT EXISTS idx_sampling_geom ON "lab"."sampling" USING GIST ("geom");
CREATE INDEX IF NOT EXISTS idx_sampling_fishing_start_geom ON "lab"."sampling" USING GIST ("fishing_start_geom");
CREATE INDEX IF NOT EXISTS idx_sampling_fishing_end_geom ON "lab"."sampling" USING GIST ("fishing_end_geom");
CREATE INDEX IF NOT EXISTS idx_fishing_sampling_id ON "lab"."fishing" ("sampling_id");
CREATE INDEX IF NOT EXISTS idx_fishing_taxon_id ON "lab"."fishing" ("taxon_id");
CREATE INDEX IF NOT EXISTS idx_samples_parent_sample_id ON "lab"."samples" ("parent_sample_id");
CREATE INDEX IF NOT EXISTS idx_samples_sample_type_id ON "lab"."samples" ("sample_type_id");
CREATE INDEX IF NOT EXISTS idx_samples_project_id ON "lab"."samples" ("project_id");
CREATE INDEX IF NOT EXISTS idx_samples_storage_position ON "lab"."samples" ("storage_position");
CREATE INDEX IF NOT EXISTS idx_storage_log_sample_id ON "lab"."storage_log" ("sample_id");
CREATE INDEX IF NOT EXISTS idx_fish_parent_sample_id ON "lab"."fish" ("parent_sample_id");
CREATE INDEX IF NOT EXISTS idx_fish_species_id ON "lab"."fish" ("species_id");
CREATE INDEX IF NOT EXISTS idx_tissue_parent_sample_id ON "lab"."tissue" ("parent_sample_id");
CREATE INDEX IF NOT EXISTS idx_dna_parent_sample_id ON "lab"."dna" ("parent_sample_id");
CREATE INDEX IF NOT EXISTS idx_rna_parent_sample_id ON "lab"."rna" ("parent_sample_id");
CREATE INDEX IF NOT EXISTS idx_sediments_parent_sample_id ON "lab"."sediments" ("parent_sample_id");
CREATE INDEX IF NOT EXISTS idx_water_parent_sample_id ON "lab"."water" ("parent_sample_id");
CREATE INDEX IF NOT EXISTS idx_otoliths_sample_id ON "lab"."otoliths" ("sample_id");
CREATE INDEX IF NOT EXISTS idx_extraction_sample_id ON "lab"."extraction" ("sample_id");
CREATE INDEX IF NOT EXISTS idx_nanodrop_sample_id ON "lab"."nanodrop" ("sample_id");
CREATE INDEX IF NOT EXISTS idx_qubit_sample_id ON "lab"."qubit" ("sample_id");
CREATE INDEX IF NOT EXISTS idx_tapestation_sample_id ON "lab"."tapestation" ("sample_id");
CREATE INDEX IF NOT EXISTS idx_pcr_sample_id ON "lab"."pcr" ("sample_id");
CREATE INDEX IF NOT EXISTS idx_gelelectrophoresis_sample_id ON "lab"."gelelectrophoresis" ("sample_id");
CREATE INDEX IF NOT EXISTS idx_qpcr_sample_id ON "lab"."qpcr" ("sample_id");
CREATE INDEX IF NOT EXISTS idx_library_sample_id ON "lab"."library" ("sample_id");
CREATE INDEX IF NOT EXISTS idx_sequencing_sample_id ON "lab"."sequencing" ("sample_id");
CREATE INDEX IF NOT EXISTS idx_sequencing_library_id ON "lab"."sequencing" ("library_id");
CREATE INDEX IF NOT EXISTS idx_datasets_customer_id ON "lab"."datasets" ("customer_id");
CREATE INDEX IF NOT EXISTS idx_datasets_ecosystem_id ON "lab"."datasets" ("ecosystem_id");
CREATE INDEX IF NOT EXISTS idx_datasets_region_id ON "lab"."datasets" ("region_id");


-- Bioinformatics Schema Indexes
CREATE INDEX IF NOT EXISTS idx_analysis_runs_pipeline_id ON "bioinformatics"."analysis_runs" ("pipeline_id");
CREATE INDEX IF NOT EXISTS idx_analysis_runs_sequencing_id ON "bioinformatics"."analysis_runs" ("sequencing_id");
CREATE INDEX IF NOT EXISTS idx_edna_assignments_run_id ON "bioinformatics"."edna_assignments" ("run_id");
CREATE INDEX IF NOT EXISTS idx_edna_assignments_sample_id ON "bioinformatics"."edna_assignments" ("sample_id");
CREATE INDEX IF NOT EXISTS idx_edna_assignments_taxon_id ON "bioinformatics"."edna_assignments" ("taxon_id");
CREATE INDEX IF NOT EXISTS idx_reference_databases_db_name ON "bioinformatics"."reference_databases" ("db_name");


-- Partial Index Example: Index only active projects
CREATE INDEX IF NOT EXISTS idx_projects_active ON "lims"."projects" ("project_id") WHERE status_id = 'Active';

-- Expression Index Example: Index on lowercased customer name for case-insensitive searches
CREATE INDEX IF NOT EXISTS idx_customers_lower_name ON "lims"."customers" (LOWER("customer_name"));

-- ======================================================================
-- 12. Full-Text Search Configuration
-- ======================================================================

-- Create a custom text search configuration for English with stemming.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_ts_config WHERE cfgname = 'lims_english') THEN
        CREATE TEXT SEARCH CONFIGURATION public.lims_english (PARSER = default);
        ALTER TEXT SEARCH CONFIGURATION public.lims_english
            ALTER MAPPING FOR asciiword, asciihword, hword, hword_asciipart, hword_part
            WITH english_stem;
    END IF;
END
$$;

-- Specific Full-Text Search Trigger Functions
CREATE OR REPLACE FUNCTION "lims".update_customer_search_vector_func()
RETURNS TRIGGER AS $$
BEGIN
    NEW.customer_search_vector =
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.customer_name, '')) ||
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.notes, ''));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "lab".update_sample_search_vector_func()
RETURNS TRIGGER AS $$
BEGIN
    NEW.sample_search_vector =
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.external_name, '')) ||
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.notes, ''));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "lims".update_sop_search_vector_func()
RETURNS TRIGGER AS $$
BEGIN
    NEW.sop_search_vector =
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.title, '')) ||
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.sop_protocol, '')) ||
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.notes, ''));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "lab".update_experiment_search_vector_func()
RETURNS TRIGGER AS $$
BEGIN
    NEW.experiment_search_vector =
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.experiment_title, '')) ||
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.aim, '')) ||
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.method, '')) ||
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.notes, ''));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- Add tsvector columns and GIN indexes
ALTER TABLE "lims"."customers" ADD COLUMN IF NOT EXISTS customer_search_vector TSVECTOR;
CREATE INDEX IF NOT EXISTS idx_customers_gin_search ON "lims"."customers" USING GIN (customer_search_vector);
CREATE TRIGGER trg_update_customer_search BEFORE INSERT OR UPDATE ON "lims"."customers" FOR EACH ROW EXECUTE FUNCTION "lims".update_customer_search_vector_func();

ALTER TABLE "lab"."samples" ADD COLUMN IF NOT EXISTS sample_search_vector TSVECTOR;
CREATE INDEX IF NOT EXISTS idx_samples_gin_search ON "lab"."samples" USING GIN (sample_search_vector);
CREATE TRIGGER trg_update_sample_search BEFORE INSERT OR UPDATE ON "lab"."samples" FOR EACH ROW EXECUTE FUNCTION "lab".update_sample_search_vector_func();

ALTER TABLE "lims"."sop" ADD COLUMN IF NOT EXISTS sop_search_vector TSVECTOR;
CREATE INDEX IF NOT EXISTS idx_sop_gin_search ON "lims"."sop" USING GIN (sop_search_vector);
CREATE TRIGGER trg_update_sop_search BEFORE INSERT OR UPDATE ON "lims"."sop" FOR EACH ROW EXECUTE FUNCTION "lims".update_sop_search_vector_func();

ALTER TABLE "lab"."experiments" ADD COLUMN IF NOT EXISTS experiment_search_vector TSVECTOR;
CREATE INDEX IF NOT EXISTS idx_experiments_gin_search ON "lab"."experiments" USING GIN (experiment_search_vector);
CREATE TRIGGER trg_update_experiment_search BEFORE INSERT OR UPDATE ON "lab"."experiments" FOR EACH ROW EXECUTE FUNCTION "lab".update_experiment_search_vector_func();


-- ======================================================================
-- 13. Views
-- ======================================================================

-- View: Complete_species_Taxon_View
CREATE OR REPLACE VIEW "reference"."complete_species_taxon_view" AS
SELECT
    t.taxon_id,
    t.de_name AS taxon_de_name,
    t.en_name AS taxon_en_name,
    t.rank,
    t.notes AS taxon_notes,
    s.species_id,
    s.de_name AS species_de_name,
    s.en_name AS species_en_name,
    s.max_length_mm,
    s.max_age_years,
    s.notes AS species_notes
FROM
    "reference"."taxon" t
LEFT JOIN
    "reference"."species" s ON t.taxon_id = s.species_id;

-- View: Detailed_Samples_View
CREATE OR REPLACE VIEW "lab"."detailed_samples_view" AS
SELECT
    s.sample_id,
    s.external_name,
    s.parent_sample_id,
    s.sampling_id,
    s.sampling_date,
    ST_X(samp.geom) AS sampling_lon,
    ST_Y(samp.geom) AS sampling_lat,
    samp.location_name AS sampling_location,
    samp.depth_m AS sampling_depth_m,
    s.storage_id,
    st.freezer AS storage_freezer,
    st.box AS storage_box,
    s.storage_position,
    s.sampler_person_id,
    s.receiver_person_id,
    s.reception_date,
    s.transport,
    s.conservation_buffer,
    s.sample_type_id,
    stype.sample_type_abrv,
    s.sample_status_id,
    s.workflow_id,
    s.step_id,
    s.project_id,
    p.title AS project_title,
    s.customer_id,
    c.customer_name,
    c.customer_abrv,
    s.notes,
    s.attachment,
    s.attachment_link
FROM
    "lab"."samples" s
LEFT JOIN
    "lab"."sampling" samp ON s.sampling_id = samp.sampling_id AND s.sampling_date = samp.sampling_date
LEFT JOIN
    "lab"."storage" st ON s.storage_id = st.storage_id
LEFT JOIN
    "lims"."projects" p ON s.project_id = p.project_id
LEFT JOIN
    "lims"."customers" c ON s.customer_id = c.customer_id
LEFT JOIN
    "reference"."samples_type" stype ON s.sample_type_id = stype.sample_type_id;

-- View: Project_Overview_View
CREATE OR REPLACE VIEW "lims"."project_overview_view" AS
SELECT
    p.project_id,
    p.title,
    p.status_id,
    p.pi_person_id,
    ref_p.full_name AS pi_full_name,
    p.funder,
    p.customer_id,
    c.customer_name,
    c.customer_abrv,
    p.start_date,
    p.end_date,
    p.report_date,
    p.notes
FROM
    "lims"."projects" p
LEFT JOIN
    "lims"."customers" c ON p.customer_id = c.customer_id
LEFT JOIN
    "reference"."personal" ref_p ON p.pi_person_id = ref_p.person_id;

-- View: Sample_Workflow_Progress_View
CREATE OR REPLACE VIEW "lab"."sample_workflow_progress_view" AS
SELECT
    s.sample_id,
    s.external_name,
    s.sample_type_id,
    s.sample_status_id AS current_status,
    s.workflow_id,
    ws.step_name AS current_workflow_step,
    ws.step_number,
    ws.workflow_status_id AS step_status
FROM
    "lab"."samples" s
LEFT JOIN
    "lims"."workflow_steps" ws ON s.workflow_id = ws.workflow_id AND s.step_id = ws.step_id;

-- View: Storage_Inventory_View
CREATE OR REPLACE VIEW "lab"."storage_inventory_view" AS
SELECT
    st.storage_id,
    st.room_id,
    r.address AS room_address,
    st.freezer,
    st.etage,
    st.temperature_c,
    st.box,
    st.box_size_x,
    st.box_size_y,
    st.storage_position_format,
    s.sample_id,
    s.external_name AS sample_external_name,
    s.sample_type_id,
    s.reception_date AS sample_reception_date,
    s.project_id
FROM
    "lab"."storage" st
LEFT JOIN
    "reference"."room" r ON st.room_id = r.room_id
LEFT JOIN
    "lab"."samples" s ON st.storage_id = s.storage_id;

-- View: Experiment_Summary_View
CREATE OR REPLACE VIEW "lab"."experiment_summary_view" AS
SELECT
    e.experiment_id,
    e.experiment_title,
    e.aim,
    e.method,
    e.sop_id,
    sop.title AS sop_title,
    e.experiment_date,
    e.person_id AS experiment_person_id,
    ref_p.full_name AS experiment_person_name,
    e.lab_book,
    e.status_id,
    COUNT(DISTINCT es.sample_id) AS number_of_samples,
    COUNT(DISTINCT ep.project_id) AS number_of_projects
FROM
    "lab"."experiments" e
LEFT JOIN
    "lims"."sop" sop ON e.sop_id = sop.sop_id
LEFT JOIN
    "reference"."personal" ref_p ON e.person_id = ref_p.person_id
LEFT JOIN
    "lab"."experiments_samples" es ON e.experiment_id = es.experiment_id
LEFT JOIN
    "lab"."experiments_projects" ep ON e.experiment_id = ep.experiment_id
GROUP BY
    e.experiment_id, e.experiment_title, e.aim, e.method, e.sop_id, sop.title,
    e.experiment_date, e.person_id, ref_p.full_name, e.lab_book, e.status_id;

-- View: Bioinformatics_Results_Summary (Updated for new schema)
CREATE OR REPLACE VIEW "bioinformatics"."analysis_results_summary" AS
SELECT
    ar.run_id,
    ar.run_date,
    ar.person_id,
    ref_p.full_name AS analyst_name,
    ap.pipeline_name,
    ap.version AS pipeline_version,
    ar.sequencing_id,
    s.sample_id,
    s.external_name AS sample_external_name,
    ea.taxon_id,
    t.en_name AS taxon_en_name,
    ea.read_count,
    ea.confidence,
    ar.notes AS run_notes,
    ea.notes AS assignment_notes,
    ar.clustering_threshold,
    ar.final_output_path,
    rdb.db_name AS reference_database_name,
    rdb.db_version AS bioinfo_database_version
FROM
    "bioinformatics"."edna_assignments" ea
JOIN
    "bioinformatics"."analysis_runs" ar ON ea.run_id = ar.run_id
JOIN
    "bioinformatics"."analysis_pipelines" ap ON ar.pipeline_id = ap.pipeline_id
JOIN
    "lab"."sequencing" seq ON ar.sequencing_id = seq.sequencing_id
JOIN
    "lab"."samples" s ON seq.sample_id = s.sample_id
LEFT JOIN
    "reference"."personal" ref_p ON ar.person_id = ref_p.person_id
LEFT JOIN
    "reference"."taxon" t ON ea.taxon_id = t.taxon_id
LEFT JOIN
    "bioinformatics"."reference_databases" rdb ON ar.reference_db_id = rdb.db_id;


-- View: Project_Financial_Summary_View
CREATE OR REPLACE VIEW "lims"."project_financial_summary_view" AS
SELECT
    p.project_id,
    p.title AS project_title,
    p.pi_person_id,
    pers.full_name AS pi_name,
    SUM(o.price) AS total_cost,
    COUNT(o.fi_order_nr) AS number_of_orders,
    MIN(o.order_date) AS first_order_date,
    MAX(o.order_date) AS last_order_date
FROM
    "lims"."projects" p
JOIN "lims"."orders" o ON p.project_id = o.project_id
LEFT JOIN "reference"."personal" pers ON p.pi_person_id = pers.person_id
GROUP BY
    p.project_id, p.title, p.pi_person_id, pers.full_name
ORDER BY
    total_cost DESC;

-- View: Full bioinformatics results, linking taxonomic assignments back to sampling event details.
CREATE OR REPLACE VIEW "bioinformatics"."full_analysis_results_view" AS
SELECT
    p.project_id,
    p.title AS project_title,
    samp.sampling_id,
    samp.sampling_date,
    samp.location_name AS sampling_location,
    s.sample_id,
    s.external_name,
    ar.run_id AS analysis_run_id,
    ap.pipeline_name,
    ap.version AS pipeline_version,
    t.taxon_id,
    t.en_name AS taxon_en_name,
    t.rank AS taxon_rank,
    ea.read_count,
    ea.confidence
FROM
    "bioinformatics"."edna_assignments" ea
JOIN "bioinformatics"."analysis_runs" ar ON ea.run_id = ar.run_id
JOIN "bioinformatics"."analysis_pipelines" ap ON ar.pipeline_id = ap.pipeline_id
JOIN "lab"."samples" s ON ea.sample_id = s.sample_id
JOIN "lab"."sampling" samp ON s.sampling_id = samp.sampling_id AND s.sampling_date = samp.sampling_date
JOIN "lims"."projects" p ON s.project_id = p.project_id
JOIN "reference"."taxon" t ON ea.taxon_id = t.taxon_id
ORDER BY
    p.project_id, samp.sampling_date, s.sample_id, ea.read_count DESC;

-- View: Storage occupancy, calculating the percentage of used slots in each box.
CREATE OR REPLACE VIEW "lab"."storage_occupancy_view" AS
WITH box_counts AS (
    SELECT
        storage_id,
        COUNT(sample_id) AS stored_samples
    FROM "lab"."samples"
    WHERE storage_id IS NOT NULL
    GROUP BY storage_id
)
SELECT
    st.storage_id,
    st.room_id,
    st.freezer,
    st.box,
    st.box_size_x * st.box_size_y AS box_capacity,
    COALESCE(bc.stored_samples, 0) AS occupied_slots,
    (COALESCE(bc.stored_samples, 0)::NUMERIC * 100 / (st.box_size_x * st.box_size_y))::NUMERIC(5,2) AS occupancy_percent
FROM
    "lab"."storage" st
LEFT JOIN box_counts bc ON st.storage_id = bc.storage_id
WHERE st.box_size_x > 0 AND st.box_size_y > 0
ORDER BY
    occupancy_percent DESC;

-- View: Comprehensive Project Summary
CREATE OR REPLACE VIEW "lims"."project_comprehensive_summary_view" AS
SELECT
    p.project_id,
    p.title AS project_title,
    stat.notes AS project_status,
    p.funder,
    p.start_date,
    p.end_date,
    COUNT(DISTINCT ep.experiment_id) AS number_of_experiments,
    COUNT(DISTINCT s.sample_id) AS number_of_samples,
    SUM(o.price) AS total_order_cost
FROM "lims"."projects" p
LEFT JOIN "reference"."status" stat ON p.status_id = stat.status_id
LEFT JOIN "lab"."experiments_projects" ep ON p.project_id = ep.project_id
LEFT JOIN "lab"."samples" s ON p.project_id = s.project_id
LEFT JOIN "lims"."orders" o ON p.project_id = o.project_id
GROUP BY
    p.project_id, p.title, stat.notes, p.funder, p.start_date, p.end_date
ORDER BY p.start_date DESC;

-- View: Experiment Progress Overview
CREATE OR REPLACE VIEW "lab"."experiment_progress_overview_view" AS
SELECT
    e.experiment_id,
    e.experiment_title,
    p.project_id,
    p.title AS project_title,
    stat.notes AS experiment_status,
    e.experiment_date AS experiment_start_date,
    pers.full_name AS experiment_lead,
    COUNT(DISTINCT es.sample_id) AS total_samples_in_experiment,
    COUNT(DISTINCT ext.sample_id) AS samples_extracted,
    COUNT(DISTINCT qu.sample_id) AS samples_qubit_qc,
    COUNT(DISTINCT lib.sample_id) AS samples_library_prepped,
    COUNT(DISTINCT seq.sample_id) AS samples_sequenced,
    COUNT(DISTINCT ar.run_id) AS samples_bioinformatics_done
FROM "lab"."experiments" e
LEFT JOIN "lab"."experiments_projects" ep ON e.experiment_id = ep.experiment_id
LEFT JOIN "lims"."projects" p ON ep.project_id = p.project_id
LEFT JOIN "reference"."status" stat ON e.status_id = stat.status_id
LEFT JOIN "reference"."personal" pers ON e.person_id = pers.person_id
LEFT JOIN "lab"."experiments_samples" es ON e.experiment_id = es.experiment_id
LEFT JOIN "lab"."extraction" ext ON es.sample_id = ext.sample_id
LEFT JOIN "lab"."qubit" qu ON es.sample_id = qu.sample_id
LEFT JOIN "lab"."library" lib ON es.sample_id = lib.sample_id
LEFT JOIN "lab"."sequencing" seq ON es.sample_id = seq.sample_id
LEFT JOIN "bioinformatics"."analysis_runs" ar ON seq.sequencing_id = ar.sequencing_id
GROUP BY
    e.experiment_id, e.experiment_title, p.project_id, p.title,
    stat.notes, e.experiment_date, pers.full_name
ORDER BY e.experiment_date DESC;

-- View: Reagent Status View
CREATE OR REPLACE VIEW "lims"."reagent_status_view" AS
SELECT
    r.reagent_complete_name,
    r.category_id,
    r.lot,
    r.storage_id,
    stat.notes AS current_status,
    r.reception_date,
    r.expire_date,
    CASE
        WHEN r.expire_date IS NULL THEN NULL
        ELSE (r.expire_date - CURRENT_DATE)
    END AS days_until_expiry,
    r.quantity_available,
    ru.unit_abbreviation AS quantity_unit
FROM "lims"."reagents" r
LEFT JOIN "reference"."status" stat ON r.status_id = stat.status_id
LEFT JOIN "reference"."units" ru ON r.quantity_unit_id = ru.unit_id
ORDER BY r.expire_date ASC;


-- View: The "Mega View" for complete sample tracking
CREATE OR REPLACE VIEW "lab"."sample_full_details_view" AS
SELECT
    -- Core Sample Info
    s.sample_id,
    s.external_name,
    s.project_id,
    p.title AS project_title,
    s.sample_type_id,
    stype.sample_type_abrv,
    s.sample_status_id,
    stat.notes AS sample_status_notes,
    s.parent_sample_id,

    -- Storage Info
    s.storage_id,
    stor.freezer AS storage_freezer,
    stor.box AS storage_box,
    s.storage_position,
    stor.room_id,
    r.address AS room_address,
    r.etage AS room_etage,

    -- Sampling Event Info
    samp.sampling_id AS sampling_event_id,
    samp.sampling_date AS sampling_event_date,
    ST_X(samp.geom) AS sampling_lon,
    ST_Y(samp.geom) AS sampling_lat,
    ST_X(samp.fishing_start_geom) AS fishing_start_lon,
    ST_Y(samp.fishing_start_geom) AS fishing_start_lat,
    ST_X(samp.fishing_end_geom) AS fishing_end_lon,
    ST_Y(samp.fishing_end_geom) AS fishing_end_lat,
    samp.location_name AS sampling_location,
    samp.depth_m AS sampling_depth_m,
    samp.temperature_atmospheric_c,
    samp.weather,
    samp.wind_speed,
    wu.unit_abbreviation AS wind_unit,
    samp.salinity,
    su.unit_abbreviation AS salinity_unit,
    samp.oxygen,
    ou.unit_abbreviation AS oxygen_unit,

    -- Fish Specifics
    f.species_id,
    taxon_sp.en_name AS species_en_name,
    f.total_length_mm,
    f.weight_g,
    f.sex,
    f.maturity_stage,
    f.stomach_contents,
    f.disease_info,
    f.tag_id,

    -- Tissue Specifics
    t.weight_mg AS tissue_weight_mg,
    t.tissue_type,
    t.preservation_method AS tissue_preservation_method,

    -- DNA Specifics
    dna.volume_ul AS dna_volume_ul,
    dna.concentration_ng_ul AS dna_concentration_ng_ul,
    dna.a260_280 AS dna_a260_280,
    dna.a260_230 AS dna_a260_230,
    dna.extraction_method AS dna_extraction_method,

    -- RNA Specifics
    rna.volume_ul AS rna_volume_ul,
    rna.concentration_ng_ul AS rna_concentration_ng_ul,
    rna.a260_280 AS rna_a260_280,
    rna.a260_230 AS rna_a260_230,
    rna.extraction_method AS rna_extraction_method,

    -- Sediments Specifics
    sed.volume AS sediment_volume,
    svu.unit_abbreviation AS sediment_volume_unit,
    sed.depth_m AS sediment_depth_m,
    sed.sampling_method AS sediment_sampling_method,

    -- Water Specifics
    wat.volume_l AS water_volume_l,
    wat.filter AS water_filter,
    wat.filter_pore_size_um AS water_filter_pore_size_um,
    wat.depth_m AS water_depth_m,

    -- Extraction Results
    ext.extraction_date,
    ext.kit AS extraction_kit,
    ext.elution_volume_ul AS extraction_elution_volume_ul,
    ext.yield_qubit_ng_ul,
    ext.yield_nanodrop_ng_ul,
    ext.a260_280 AS extraction_a260_280,
    ext.a260_230 AS extraction_a260_230,
    ext.extracted_dna_sample_id,
    ext.extracted_rna_sample_id,

    -- Nanodrop Results
    nd.nanodrop_concentration,
    ndcu.unit_abbreviation AS nanodrop_concentration_unit,
    nd.a260 AS nanodrop_a260,
    nd.a260_280 AS nanodrop_a260_280,
    nd.a260_230 AS nanodrop_a260_230,
    nd.nanodrop_total_dna_ug,

    -- Qubit Results
    qu.qubit_original_sample_conc,
    quosu.unit_abbreviation AS qubit_original_sample_unit,
    qu.qubit_total_dna_ug,

    -- PCR Results
    pcr.pcr_date,
    pcr.primer_id AS pcr_primer_id,
    pcr_primer.target_gene_id AS pcr_target_gene_id,
    pcr.volume_reaction_ul,

    -- qPCR Results
    qpcr.qpcr_date,
    qpcr.ct_value,
    qpcr.inhibitor_test_result,

    -- Library & Sequencing
    lib.library_id,
    lib.library_prep_kit,
    lib.index_sequence,
    lib.read_length_bp AS library_read_length_bp,
    seq.sequencing_id,
    seq.sequencer,
    seq.total_reads,
    seq.raw_data_path,
    seq.genbank_accession_number,

    -- Bioinformatics Results (from analysis_runs)
    ar.run_id AS analysis_run_id,
    ap.pipeline_name,
    ap.version AS pipeline_version,
    rdb.db_name AS bioinfo_reference_database,
    rdb.db_version AS bioinfo_database_version,
    ar.clustering_threshold,
    ar.final_output_path,
    ea.taxon_id AS edna_assigned_taxon_id,
    ea_taxon.en_name AS edna_assigned_taxon_name,
    ea.read_count AS edna_read_count,
    ea.confidence,

    -- Sampler/Receiver/Reception from samples table
    s.sampler_person_id,
    sampler_p.full_name AS sampler_full_name,
    s.receiver_person_id,
    receiver_p.full_name AS receiver_full_name,
    s.reception_date


FROM "lab"."samples" s
LEFT JOIN "reference"."status" stat ON s.sample_status_id = stat.status_id
LEFT JOIN "reference"."samples_type" stype ON s.sample_type_id = stype.sample_type_id
LEFT JOIN "lims"."projects" p ON s.project_id = p.project_id
LEFT JOIN "lab"."storage" stor ON s.storage_id = stor.storage_id
LEFT JOIN "reference"."room" r ON stor.room_id = r.room_id
LEFT JOIN "lab"."sampling" samp ON s.sampling_id = samp.sampling_id AND s.sampling_date = samp.sampling_date
LEFT JOIN "lab"."fish" f ON s.sample_id = f.sample_id
LEFT JOIN "reference"."taxon" taxon_sp ON f.species_id = taxon_sp.taxon_id
LEFT JOIN "lab"."tissue" t ON s.sample_id = t.sample_id
LEFT JOIN "lab"."dna" dna ON s.sample_id = dna.sample_id
LEFT JOIN "lab"."rna" rna ON s.sample_id = rna.sample_id
LEFT JOIN "lab"."sediments" sed ON s.sample_id = sed.sample_id
LEFT JOIN "lab"."water" wat ON s.sample_id = wat.sample_id
LEFT JOIN "lab"."extraction" ext ON s.sample_id = ext.sample_id
LEFT JOIN "lab"."nanodrop" nd ON s.sample_id = nd.sample_id
LEFT JOIN "reference"."units" ndcu ON nd.concentration_unit_id = ndcu.unit_id
LEFT JOIN "lab"."qubit" qu ON s.sample_id = qu.sample_id
LEFT JOIN "reference"."units" quosu ON qu.original_sample_unit_id = quosu.unit_id
LEFT JOIN "lab"."pcr" pcr ON s.sample_id = pcr.sample_id
LEFT JOIN "lims"."primers" pcr_primer ON pcr.primer_id = pcr_primer.primer_id
LEFT JOIN "lab"."qpcr" qpcr ON s.sample_id = qpcr.sample_id
LEFT JOIN "lab"."library" lib ON s.sample_id = lib.sample_id
LEFT JOIN "lab"."sequencing" seq ON s.sample_id = seq.sample_id
LEFT JOIN "bioinformatics"."analysis_runs" ar ON seq.sequencing_id = ar.sequencing_id
LEFT JOIN "bioinformatics"."analysis_pipelines" ap ON ar.pipeline_id = ap.pipeline_id
LEFT JOIN "bioinformatics"."reference_databases" rdb ON ar.reference_db_id = rdb.db_id
LEFT JOIN "bioinformatics"."edna_assignments" ea ON ar.run_id = ea.run_id AND s.sample_id = ea.sample_id
LEFT JOIN "reference"."taxon" ea_taxon ON ea.taxon_id = ea_taxon.taxon_id
LEFT JOIN "reference"."units" wu ON samp.wind_unit_id = wu.unit_id
LEFT JOIN "reference"."units" su ON samp.salinity_unit_id = su.unit_id
LEFT JOIN "reference"."units" ou ON samp.oxygen_unit_id = ou.unit_id
LEFT JOIN "reference"."units" svu ON sed.volume_unit_id = svu.unit_id
LEFT JOIN "reference"."personal" sampler_p ON s.sampler_person_id = sampler_p.person_id
LEFT JOIN "reference"."personal" receiver_p ON s.receiver_person_id = receiver_p.person_id;


-- View: Taxons View with Phylum to Species
CREATE OR REPLACE VIEW "reference"."taxon_hierarchy_view" AS
SELECT
    t.taxon_id,
    t.de_name,
    t.en_name,
    t.rank,
    t.path,
    l.ancestor_taxon_id AS phylum_id,
    phylum_taxon.en_name AS phylum_en_name,
    l2.ancestor_taxon_id AS class_id,
    class_taxon.en_name AS class_en_name,
    l3.ancestor_taxon_id AS order_id,
    order_taxon.en_name AS order_en_name,
    l4.ancestor_taxon_id AS family_id,
    family_taxon.en_name AS family_en_name,
    l5.ancestor_taxon_id AS genus_id,
    genus_taxon.en_name AS genus_en_name,
    s.species_id AS species_level_id,
    s.en_name AS species_level_en_name
FROM
    "reference"."taxon" t
LEFT JOIN
    "reference"."species" s ON t.taxon_id = s.species_id
LEFT JOIN LATERAL (
    SELECT taxon_id AS ancestor_taxon_id
    FROM "reference"."taxon"
    WHERE path @> t.path AND rank = 'phylum'
) l ON TRUE
LEFT JOIN "reference"."taxon" phylum_taxon ON l.ancestor_taxon_id = phylum_taxon.taxon_id
LEFT JOIN LATERAL (
    SELECT taxon_id AS ancestor_taxon_id
    FROM "reference"."taxon"
    WHERE path @> t.path AND rank = 'class'
) l2 ON TRUE
LEFT JOIN "reference"."taxon" class_taxon ON l2.ancestor_taxon_id = class_taxon.taxon_id
LEFT JOIN LATERAL (
    SELECT taxon_id AS ancestor_taxon_id
    FROM "reference"."taxon"
    WHERE path @> t.path AND rank = 'order'
) l3 ON TRUE
LEFT JOIN "reference"."taxon" order_taxon ON l3.ancestor_taxon_id = order_taxon.taxon_id
LEFT JOIN LATERAL (
    SELECT taxon_id AS ancestor_taxon_id
    FROM "reference"."taxon"
    WHERE path @> t.path AND rank = 'family'
) l4 ON TRUE
LEFT JOIN "reference"."taxon" family_taxon ON l4.ancestor_taxon_id = family_taxon.taxon_id
LEFT JOIN LATERAL (
    SELECT taxon_id AS ancestor_taxon_id
    FROM "reference"."taxon"
    WHERE path @> t.path AND rank = 'genus'
) l5 ON TRUE
LEFT JOIN "reference"."taxon" genus_taxon ON l5.ancestor_taxon_id = genus_taxon.taxon_id
ORDER BY t.path;


-- Materialized View Example: Monthly Sample Reception Summary
CREATE MATERIALIZED VIEW IF NOT EXISTS "lab"."monthly_sample_reception_mv" AS
SELECT
    TO_CHAR(reception_date, 'YYYY-MM') AS reception_month,
    sample_type_id,
    COUNT(sample_id) AS total_samples_received
FROM
    "lab"."samples"
WHERE
    reception_date IS NOT NULL
GROUP BY
    1, 2
ORDER BY
    1, 2
WITH DATA;

-- ======================================================================
-- 14. Initial Data Population (Example Data)
-- ======================================================================

INSERT INTO "reference"."status" ("status_id", "notes") VALUES
('Received', 'sample has been received in the lab'),
('Dissection', 'sample has been dissected'),
('Extracted', 'sample has been extracted'),
('Nanodrop QC', 'sample quality checked with Nanodrop'),
('Qubit QC', 'sample quality checked with Qubit'),
('Tapestation QC', 'sample quality checked with Tapestation'),
('PCR Done', 'PCR has been performed on the sample'),
('qPCR Done', 'qPCR has been performed on the sample'),
('Library Prep', 'Sequencing library has been prepared'),
('Sequencing Done', 'sample has been sequenced'),
('Bioinformatics Done', 'bioinformatics analysis is complete'),
('Unknown Step', 'An unknown step has occurred in the workflow')
ON CONFLICT ("status_id") DO NOTHING;

INSERT INTO "reference"."samples_type" ("sample_type_id", "sample_type_abrv", "notes") VALUES
('DNA', 'D', 'Deoxyribonucleic Acid sample'),
('RNA', 'R', 'Ribonucleic Acid sample'),
('Library', 'L', 'Sequencing Library sample'),
('Water', 'W', 'Water sample'),
('Sediments', 'S', 'Sediment sample'),
('Tissue', 'T', 'Tissue sample'),
('Fish', 'F', 'Fish sample'),
('Sequencing', 'Q', 'Sequencing run output'),
('Dataset', 'Z', 'Processed dataset'),
('Publication', 'PUB', 'Research Publication')
ON CONFLICT ("sample_type_id") DO NOTHING;


INSERT INTO "reference"."units" ("unit_id", "unit_name", "unit_abbreviation", "unit_type", "conversion_factor_to_base") VALUES
('mm', 'millimeter', 'mm', 'length', 0.001),
('g', 'gram', 'g', 'mass', 0.001),
('ul', 'microliter', 'µL', 'volume', 1e-6),
('ng_ul', 'nanogram per microliter', 'ng/µL', 'concentration', 1e-9),
('bp', 'base pair', 'bp', 'length', 1),
('km_h', 'kilometer per hour', 'km/h', 'speed', 0.277778),
('m_s', 'meter per second', 'm/s', 'speed', 1),
('PSU', 'Practical Salinity Unit', 'PSU', 'salinity', 1),
('ppt', 'parts per thousand', 'ppt', 'salinity', 1),
('dbar', 'decibar', 'dbar', 'pressure', 1),
('psi', 'pounds per square inch', 'psi', 'pressure', 0.0689476),
('kPa', 'kilopascal', 'kPa', 'pressure', 1000),
('mg_l', 'milligram per liter', 'mg/L', 'concentration', 1),
('umol_l', 'micromole per liter', 'µmol/L', 'concentration', 1),
('ntu', 'Nephelometric Turbidity Unit', 'NTU', 'turbidity', 1),
('ug_l', 'microgram per liter', 'µg/L', 'concentration', 1),
('deg', 'degree', 'deg', 'angle', 1),
('min', 'minute', 'min', 'time', 60),
('h', 'hour', 'h', 'time', 3600),
('c', 'Celsius', '°C', 'temperature', 1),
('l', 'liter', 'L', 'volume', 1),
('um', 'micrometer', 'µm', 'length', 1e-6),
('m', 'meter', 'm', 'length', 1)
ON CONFLICT ("unit_id") DO NOTHING;

-- Example: Add a system user for automated processes
INSERT INTO "reference"."personal" ("person_id", "full_name", "password_hash") VALUES
('system_user', 'System Automation', 'no_password_needed_for_system')
ON CONFLICT ("person_id") DO NOTHING;

-- ======================================================================
-- 15. Partitioning Setup
--     Call these functions to create partitions for specific years.
--     Automate this annually via a cron job or similar scheduler.
-- ======================================================================

-- Create initial partitions for current and next year for lab.sampling
DO $$
BEGIN
    PERFORM "lab".create_sampling_partition_if_not_exists_manual(EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER);
    PERFORM "lab".create_sampling_partition_if_not_exists_manual(EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER + 1);
END $$;

-- Create initial partitions for current and next year for lab.samples
DO $$
DECLARE
    current_year_int INTEGER := EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER;
    next_year_int INTEGER := current_year_int + 1;
    current_year_start_date TEXT := (current_year_int || '-01-01');
    current_year_end_date TEXT := ((current_year_int + 1) || '-01-01');
    next_year_start_date TEXT := (next_year_int || '-01-01');
    next_year_end_date TEXT := ((next_year_int + 1) || '-01-01');
BEGIN
    EXECUTE 'CREATE TABLE IF NOT EXISTS "lab".samples_y' || current_year_int || ' PARTITION OF "lab"."samples"
             FOR VALUES FROM (''' || current_year_start_date || ''') TO (''' || current_year_end_date || ''');';

    EXECUTE 'CREATE TABLE IF NOT EXISTS "lab".samples_y' || next_year_int || ' PARTITION OF "lab"."samples"
             FOR VALUES FROM (''' || next_year_start_date || ''') TO (''' || next_year_end_date || ''');';
END $$;

-- ======================================================================
-- 16. Row-Level Security (RLS) Policies
--     Enable RLS on tables and define policies.
--     Remember to set 'lims.current_person_id' in your application.
-- ======================================================================

ALTER TABLE "lims"."projects" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "lab"."samples" ENABLE ROW LEVEL SECURITY;

-- Policy 1: Users can see projects they are a member of.
CREATE POLICY project_membership_policy ON "lims"."projects"
FOR SELECT
USING ("lims".is_member_of_project(project_id));

-- Policy 2: Users can see samples belonging to projects they are a member of.
CREATE POLICY sample_project_membership_policy ON "lab"."samples"
FOR SELECT
USING ("lims".is_member_of_project(project_id));

-- ======================================================================
-- 17. Advanced JSONB and ltree Query Examples (for reference)
-- ======================================================================

-- Querying JSONB data from the Dissections table
-- SELECT dissection_id, sample_id, stomach_contents_jsonb
-- FROM "lab"."dissections"
-- WHERE stomach_contents_jsonb @> '[{"item": "shrimp"}]'::jsonb;

-- Update ltree paths (run after initial taxon data load)
-- SELECT "reference".update_taxon_ltree_paths();

-- Find all taxa belonging to the family 'Gadidae' (assuming 'Gadidae' is a taxon_id)
-- SELECT * FROM "reference"."taxon"
-- WHERE path <@ (SELECT path FROM "reference"."taxon" WHERE taxon_id = 'Gadidae');

-- Find the full lineage of 'Gadus morhua' (Atlantic Cod)
-- SELECT * FROM "reference"."taxon"
-- WHERE path @> (SELECT path FROM "reference"."taxon" WHERE taxon_id = 'Gadus morhua')
-- ORDER BY path;

-- ======================================================================
-- 18. Foreign Data Wrappers (FDW) Examples (for reference)
-- ======================================================================

-- Create a foreign server (example connecting to another PostgreSQL database)
-- CREATE SERVER IF NOT EXISTS foreign_lims_server
-- FOREIGN DATA WRAPPER postgres_fdw
-- OPTIONS (host 'foreign_host', port '5432', dbname 'foreign_lims_db');

-- Create user mapping for the foreign server
-- CREATE USER MAPPING IF NOT EXISTS FOR CURRENT_USER
-- SERVER foreign_lims_server
-- OPTIONS (user 'foreign_user', password 'foreign_password');

-- Create a foreign table (example: accessing a 'remote_projects' table on the foreign server)
-- CREATE FOREIGN TABLE IF NOT EXISTS "lims"."foreign_projects" (
--      "project_id" text NOT NULL,
--      "title" text,
--      "start_date" date,
--      "end_date" date
-- )
-- SERVER foreign_lims_server
-- OPTIONS (schema_name 'lims', table_name 'projects');

-- Example query on a foreign table
-- SELECT * FROM "lims"."foreign_projects" WHERE "title" LIKE '%External%';

-- ======================================================================
-- 19. Aggregates Examples (for reference)
-- ======================================================================

-- Total number of samples per sample type
-- SELECT
--      st.sample_type_id,
--      COUNT(s.sample_id) AS total_samples
-- FROM
--      "reference"."samples_type" st
-- LEFT JOIN
--      "lab"."samples" s ON st.sample_type_id = s.sample_type_id
-- GROUP BY
--      st.sample_type_id
-- ORDER BY
--      total_samples DESC;

-- Average DNA concentration per extraction method
-- SELECT
--      extraction_method,
--      AVG(concentration_ng_ul) AS average_concentration_ng_ul
-- FROM
--      "lab"."dna"
-- WHERE
--      concentration_ng_ul IS NOT NULL
-- GROUP BY
--      extraction_method
-- HAVING
--      COUNT(concentration_ng_ul) > 1
-- ORDER BY
--      average_concentration_ng_ul DESC;

-- Count of samples received per year
-- SELECT
--      EXTRACT(YEAR FROM reception_date) AS reception_year,
--      COUNT(sample_id) AS samples_received
-- FROM
--      "lab"."samples"
-- WHERE
--      reception_date IS NOT NULL
-- GROUP BY
--      reception_year
-- ORDER BY
--      reception_year;

-- Max and Min length of fish by species
-- SELECT
--      cs.species_en_name,
--      MAX(f.total_length_mm) AS max_length_mm,
--      MIN(f.total_length_mm) AS min_length_mm,
--      AVG(f.weight_g) AS avg_weight_g
-- FROM
--      "lab"."fish" f
-- JOIN
--      "reference"."complete_species_taxon_view" cs ON f.species_id = cs.species_id
-- GROUP BY
--      cs.species_en_name
-- ORDER BY
--      max_length_mm DESC;

-- ======================================================================
-- 20. Add Deferred Foreign Key Constraints and Unique Constraints
--     These must be added AFTER all tables, functions, triggers,
--     views, and initial partitions have been created.
-- ======================================================================

-- Reference Schema FKs
ALTER TABLE "reference"."taxon"
ADD CONSTRAINT "taxon_parent_fk" FOREIGN KEY ("taxon_parent")
REFERENCES "reference"."taxon"("taxon_id");

ALTER TABLE "reference"."species"
ADD CONSTRAINT "species_taxon_id_fk" FOREIGN KEY ("species_id")
REFERENCES "reference"."taxon"("taxon_id");

-- Lims Schema FKs
ALTER TABLE "lims"."projects"
ADD CONSTRAINT "projects_status_id_fk" FOREIGN KEY ("status_id")
REFERENCES "reference"."status"("status_id");

ALTER TABLE "lims"."projects"
ADD CONSTRAINT "projects_pi_person_id_fk" FOREIGN KEY ("pi_person_id")
REFERENCES "reference"."personal"("person_id");

ALTER TABLE "lims"."projects"
ADD CONSTRAINT "projects_customer_id_fk" FOREIGN KEY ("customer_id")
REFERENCES "lims"."customers"("customer_id");

ALTER TABLE "lims"."project_persons"
ADD CONSTRAINT "project_persons_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id") ON DELETE CASCADE;

ALTER TABLE "lims"."project_persons"
ADD CONSTRAINT "project_persons_person_id_fk" FOREIGN KEY ("person_id")
REFERENCES "reference"."personal"("person_id") ON DELETE CASCADE;

ALTER TABLE "lims"."cruises"
ADD CONSTRAINT "cruises_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id") ON DELETE CASCADE;

ALTER TABLE "lims"."cruises"
ADD CONSTRAINT "cruises_vessel_id_fk" FOREIGN KEY ("vessel_id")
REFERENCES "reference"."vessel"("vessel_id");

ALTER TABLE "lims"."cruises"
ADD CONSTRAINT "cruises_status_id_fk" FOREIGN KEY ("status_id")
REFERENCES "reference"."status"("status_id");

ALTER TABLE "lims"."cruises"
ADD CONSTRAINT "cruises_region_id_fk" FOREIGN KEY ("region_id")
REFERENCES "reference"."region"("region_id");

ALTER TABLE "lims"."cruises"
ADD CONSTRAINT "cruises_ecosystem_id_fk" FOREIGN KEY ("ecosystem_id")
REFERENCES "reference"."ecosystem"("ecosystem_id");

ALTER TABLE "lims"."cruises"
ADD CONSTRAINT "cruises_capitaine_contact_id_fk" FOREIGN KEY ("capitaine_contact_id")
REFERENCES "lims"."external_contacts"("contact_id");

ALTER TABLE "lims"."cruises"
ADD CONSTRAINT "cruises_chief_scientist_person_id_fk" FOREIGN KEY ("chief_scientist_person_id")
REFERENCES "reference"."personal"("person_id");

ALTER TABLE "lims"."cruises"
ADD CONSTRAINT "cruises_together_with_contact_id_fk" FOREIGN KEY ("together_with_contact_id")
REFERENCES "lims"."external_contacts"("contact_id");

ALTER TABLE "lims"."workflow_steps"
ADD CONSTRAINT "workflow_steps_workflow_id_fk" FOREIGN KEY ("workflow_id")
REFERENCES "lims"."workflows"("workflow_id") ON DELETE CASCADE;

ALTER TABLE "lims"."workflow_steps"
ADD CONSTRAINT "workflow_steps_sop_id_fk" FOREIGN KEY ("sop_id")
REFERENCES "lims"."sop"("sop_id");

ALTER TABLE "lims"."workflow_steps"
ADD CONSTRAINT "workflow_steps_workflow_status_id_fk" FOREIGN KEY ("workflow_status_id")
REFERENCES "reference"."status"("status_id");

ALTER TABLE "lims"."primers"
ADD CONSTRAINT "primers_target_gene_id_fk" FOREIGN KEY ("target_gene_id")
REFERENCES "reference"."gene"("gene_id");

ALTER TABLE "lims"."sop"
ADD CONSTRAINT "sop_author_person_id_fk" FOREIGN KEY ("author_person_id")
REFERENCES "reference"."personal"("person_id");

ALTER TABLE "lims"."sop"
ADD CONSTRAINT "sop_reviewer1_person_id_fk" FOREIGN KEY ("reviewer1_person_id")
REFERENCES "reference"."personal"("person_id");

ALTER TABLE "lims"."sop"
ADD CONSTRAINT "sop_reviewer2_person_id_fk" FOREIGN KEY ("reviewer2_person_id")
REFERENCES "reference"."personal"("person_id");

ALTER TABLE "lims"."equipment"
ADD CONSTRAINT "equipment_room_id_fk" FOREIGN KEY ("room_id")
REFERENCES "reference"."room"("room_id");

ALTER TABLE "lims"."inventory_items"
ADD CONSTRAINT "inventory_items_category_id_fk" FOREIGN KEY ("category_id")
REFERENCES "reference"."category"("category_id");

ALTER TABLE "lims"."inventory_items"
ADD CONSTRAINT "inventory_items_unit_id_fk" FOREIGN KEY ("unit_id")
REFERENCES "reference"."units"("unit_id");

ALTER TABLE "lims"."orders"
ADD CONSTRAINT "orders_item_id_fk" FOREIGN KEY ("item_id")
REFERENCES "lims"."inventory_items"("item_id");

ALTER TABLE "lims"."orders"
ADD CONSTRAINT "orders_category_id_fk" FOREIGN KEY ("category_id")
REFERENCES "reference"."category"("category_id");

ALTER TABLE "lims"."orders"
ADD CONSTRAINT "orders_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id");

ALTER TABLE "lims"."orders"
ADD CONSTRAINT "orders_supplier_id_fk" FOREIGN KEY ("supplier_id")
REFERENCES "lims"."suppliers"("supplier_id");

ALTER TABLE "lims"."orders"
ADD CONSTRAINT "orders_status_id_fk" FOREIGN KEY ("status_id")
REFERENCES "reference"."status"("status_id");

ALTER TABLE "lims"."reagents"
ADD CONSTRAINT "reagents_category_id_fk" FOREIGN KEY ("category_id")
REFERENCES "reference"."category"("category_id");

ALTER TABLE "lims"."reagents"
ADD CONSTRAINT "reagents_storage_id_fk" FOREIGN KEY ("storage_id")
REFERENCES "lab"."storage"("storage_id");

ALTER TABLE "lims"."reagents"
ADD CONSTRAINT "reagents_status_id_fk" FOREIGN KEY ("status_id")
REFERENCES "reference"."status"("status_id");

ALTER TABLE "lims"."reagents"
ADD CONSTRAINT "reagents_order_id_fk" FOREIGN KEY ("order_id")
REFERENCES "lims"."orders"("fi_order_nr");

ALTER TABLE "lims"."reagents"
ADD CONSTRAINT "reagents_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id");

ALTER TABLE "lims"."reagents"
ADD CONSTRAINT "reagents_quantity_unit_id_fk" FOREIGN KEY ("quantity_unit_id")
REFERENCES "reference"."units"("unit_id");

ALTER TABLE "lims"."publications"
ADD CONSTRAINT "publications_publication_type_id_fk" FOREIGN KEY ("publication_type_id")
REFERENCES "lims"."publication_type"("publication_type_id");

ALTER TABLE "lims"."publications"
ADD CONSTRAINT "publications_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id");

ALTER TABLE "lims"."publications"
ADD CONSTRAINT "publications_first_author_person_id_fk" FOREIGN KEY ("first_author_person_id")
REFERENCES "reference"."personal"("person_id");

ALTER TABLE "lims"."publications"
ADD CONSTRAINT "publications_corresponding_author_person_id_fk" FOREIGN KEY ("corresponding_author_person_id")
REFERENCES "reference"."personal"("person_id");

-- Lab Schema FKs
ALTER TABLE "lab"."storage"
ADD CONSTRAINT "storage_room_id_fk" FOREIGN KEY ("room_id")
REFERENCES "reference"."room"("room_id");

ALTER TABLE "lab"."storage"
ADD CONSTRAINT "storage_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id");

ALTER TABLE "lab"."experiments"
ADD CONSTRAINT "experiments_sop_id_fk" FOREIGN KEY ("sop_id")
REFERENCES "lims"."sop"("sop_id");

ALTER TABLE "lab"."experiments"
ADD CONSTRAINT "experiments_person_id_fk" FOREIGN KEY ("person_id")
REFERENCES "reference"."personal"("person_id");

ALTER TABLE "lab"."experiments"
ADD CONSTRAINT "experiments_status_id_fk" FOREIGN KEY ("status_id")
REFERENCES "reference"."status"("status_id");

ALTER TABLE "lab"."experiments_projects"
ADD CONSTRAINT "experiments_projects_experiment_id_fk" FOREIGN KEY ("experiment_id")
REFERENCES "lab"."experiments"("experiment_id");

ALTER TABLE "lab"."experiments_projects"
ADD CONSTRAINT "experiments_projects_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id");

ALTER TABLE "lab"."protocol_runs"
ADD CONSTRAINT "protocol_runs_experiment_id_fk" FOREIGN KEY ("experiment_id")
REFERENCES "lab"."experiments"("experiment_id");

ALTER TABLE "lab"."protocol_runs"
ADD CONSTRAINT "protocol_runs_sop_id_fk" FOREIGN KEY ("sop_id")
REFERENCES "lims"."sop"("sop_id");

ALTER TABLE "lab"."protocol_runs"
ADD CONSTRAINT "protocol_runs_person_id_fk" FOREIGN KEY ("person_id")
REFERENCES "reference"."personal"("person_id");

ALTER TABLE "lab"."sampling"
ADD CONSTRAINT "sampling_experiment_id_fk" FOREIGN KEY ("experiment_id")
REFERENCES "lab"."experiments"("experiment_id");

ALTER TABLE "lab"."sampling"
ADD CONSTRAINT "sampling_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id") ON DELETE CASCADE;

ALTER TABLE "lab"."sampling"
ADD CONSTRAINT "sampling_cruise_id_fk" FOREIGN KEY ("cruise_id")
REFERENCES "lims"."cruises"("cruise_id");

ALTER TABLE "lab"."sampling"
ADD CONSTRAINT "sampling_region_id_fk" FOREIGN KEY ("region_id")
REFERENCES "reference"."region"("region_id");

ALTER TABLE "lab"."sampling"
ADD CONSTRAINT "sampling_ecosystem_id_fk" FOREIGN KEY ("ecosystem_id")
REFERENCES "reference"."ecosystem"("ecosystem_id");

ALTER TABLE "lab"."sampling"
ADD CONSTRAINT "sampling_vessel_id_fk" FOREIGN KEY ("vessel_id")
REFERENCES "reference"."vessel"("vessel_id");

ALTER TABLE "lab"."sampling"
ADD CONSTRAINT "sampling_customer_id_fk" FOREIGN KEY ("customer_id")
REFERENCES "lims"."customers"("customer_id");

ALTER TABLE "lab"."sampling"
ADD CONSTRAINT "sampling_wind_unit_id_fk" FOREIGN KEY ("wind_unit_id")
REFERENCES "reference"."units"("unit_id");

ALTER TABLE "lab"."sampling"
ADD CONSTRAINT "sampling_salinity_unit_id_fk" FOREIGN KEY ("salinity_unit_id")
REFERENCES "reference"."units"("unit_id");

ALTER TABLE "lab"."sampling"
ADD CONSTRAINT "sampling_pressure_unit_id_fk" FOREIGN KEY ("pressure_unit_id")
REFERENCES "reference"."units"("unit_id");

ALTER TABLE "lab"."sampling"
ADD CONSTRAINT "sampling_oxygen_unit_id_fk" FOREIGN KEY ("oxygen_unit_id")
REFERENCES "reference"."units"("unit_id");

ALTER TABLE "lab"."sampling"
ADD CONSTRAINT "sampling_conductivity_unit_id_fk" FOREIGN KEY ("conductivity_unit_id")
REFERENCES "reference"."units"("unit_id");

ALTER TABLE "lab"."sampling"
ADD CONSTRAINT "sampling_sample_type_id_fk" FOREIGN KEY ("sample_type_id")
REFERENCES "reference"."samples_type"("sample_type_id");

ALTER TABLE "lab"."sampling"
ADD CONSTRAINT "sampling_soak_time_unit_id_fk" FOREIGN KEY ("soak_time_unit_id")
REFERENCES "reference"."units"("unit_id");

ALTER TABLE "lab"."sampling"
ADD CONSTRAINT "sampling_trawl_speed_unit_id_fk" FOREIGN KEY ("trawl_speed_unit_id")
REFERENCES "reference"."units"("unit_id");

ALTER TABLE "lab"."sampling"
ADD CONSTRAINT "sampling_together_with_contact_id_fk" FOREIGN KEY ("together_with_contact_id")
REFERENCES "lims"."external_contacts"("contact_id");

ALTER TABLE "lab"."sampling"
ADD CONSTRAINT "sampling_status_id_fk" FOREIGN KEY ("status_id")
REFERENCES "reference"."status"("status_id");

ALTER TABLE "lab"."fishing"
ADD CONSTRAINT "fishing_sampling_fk" FOREIGN KEY ("sampling_id", "sampling_date")
REFERENCES "lab"."sampling"("sampling_id", "sampling_date") ON DELETE CASCADE;

ALTER TABLE "lab"."fishing"
ADD CONSTRAINT "fishing_taxon_id_fk" FOREIGN KEY ("taxon_id")
REFERENCES "reference"."taxon"("taxon_id");

ALTER TABLE "lab"."fishing"
ADD CONSTRAINT "fishing_customer_id_fk" FOREIGN KEY ("customer_id")
REFERENCES "lims"."customers"("customer_id");

-- Lab.samples now references lab.master_samples
ALTER TABLE "lab"."samples"
ADD CONSTRAINT "samples_master_sample_id_fk" FOREIGN KEY ("sample_id")
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."samples"
ADD CONSTRAINT "samples_parent_sample_id_fk" FOREIGN KEY ("parent_sample_id")
REFERENCES "lab"."master_samples"("sample_id"); -- References master_samples

ALTER TABLE "lab"."samples"
ADD CONSTRAINT "samples_sampling_fk" FOREIGN KEY ("sampling_id", "sampling_date")
REFERENCES "lab"."sampling"("sampling_id", "sampling_date");

ALTER TABLE "lab"."samples"
ADD CONSTRAINT "samples_storage_id_fk" FOREIGN KEY ("storage_id")
REFERENCES "lab"."storage"("storage_id");

ALTER TABLE "lab"."samples"
ADD CONSTRAINT "samples_sampler_person_id_fk" FOREIGN KEY ("sampler_person_id")
REFERENCES "reference"."personal"("person_id");

ALTER TABLE "lab"."samples"
ADD CONSTRAINT "samples_receiver_person_id_fk" FOREIGN KEY ("receiver_person_id")
REFERENCES "reference"."personal"("person_id");

ALTER TABLE "lab"."samples"
ADD CONSTRAINT "samples_sample_type_id_fk" FOREIGN KEY ("sample_type_id")
REFERENCES "reference"."samples_type"("sample_type_id");

ALTER TABLE "lab"."samples"
ADD CONSTRAINT "samples_sample_status_id_fk" FOREIGN KEY ("sample_status_id")
REFERENCES "reference"."status"("status_id");

ALTER TABLE "lab"."samples"
ADD CONSTRAINT "samples_workflow_id_fk" FOREIGN KEY ("workflow_id")
REFERENCES "lims"."workflows"("workflow_id");

ALTER TABLE "lab"."samples"
ADD CONSTRAINT "samples_step_id_fk" FOREIGN KEY ("step_id")
REFERENCES "lims"."workflow_steps"("step_id");

ALTER TABLE "lab"."samples"
ADD CONSTRAINT "samples_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id");

ALTER TABLE "lab"."samples"
ADD CONSTRAINT "samples_customer_id_fk" FOREIGN KEY ("customer_id")
REFERENCES "lims"."customers"("customer_id");

ALTER TABLE "lab"."storage_log"
ADD CONSTRAINT "storage_log_sample_fk" FOREIGN KEY ("sample_id", "sample_sampling_date")
REFERENCES "lab"."samples"("sample_id", "sampling_date");

ALTER TABLE "lab"."storage_log"
ADD CONSTRAINT "storage_log_storage_id_fk" FOREIGN KEY ("storage_id")
REFERENCES "lab"."storage"("storage_id");

ALTER TABLE "lab"."storage_log"
ADD CONSTRAINT "storage_log_person_id_fk" FOREIGN KEY ("person_id")
REFERENCES "reference"."personal"("person_id");

ALTER TABLE "lab"."fish"
ADD CONSTRAINT "fish_sample_id_fk" FOREIGN KEY ("sample_id") -- PK is sample_id, now references master_samples
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."fish"
ADD CONSTRAINT "fish_parent_sample_id_fk" FOREIGN KEY ("parent_sample_id")
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."fish"
ADD CONSTRAINT "fish_experiment_id_fk" FOREIGN KEY ("experiment_id")
REFERENCES "lab"."experiments"("experiment_id");

ALTER TABLE "lab"."fish"
ADD CONSTRAINT "fish_species_id_fk" FOREIGN KEY ("species_id")
REFERENCES "reference"."species"("species_id");

ALTER TABLE "lab"."fish"
ADD CONSTRAINT "fish_storage_id_fk" FOREIGN KEY ("storage_id")
REFERENCES "lab"."storage"("storage_id");

ALTER TABLE "lab"."fish"
ADD CONSTRAINT "fish_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id");

ALTER TABLE "lab"."fish"
ADD CONSTRAINT "fish_customer_id_fk" FOREIGN KEY ("customer_id")
REFERENCES "lims"."customers"("customer_id");

ALTER TABLE "lab"."tissue"
ADD CONSTRAINT "tissue_sample_id_fk" FOREIGN KEY ("sample_id") -- PK is sample_id, now references master_samples
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."tissue"
ADD CONSTRAINT "tissue_parent_sample_id_fk" FOREIGN KEY ("parent_sample_id")
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."tissue"
ADD CONSTRAINT "tissue_experiment_id_fk" FOREIGN KEY ("experiment_id")
REFERENCES "lab"."experiments"("experiment_id");

ALTER TABLE "lab"."tissue"
ADD CONSTRAINT "tissue_storage_id_fk" FOREIGN KEY ("storage_id")
REFERENCES "lab"."storage"("storage_id");

ALTER TABLE "lab"."tissue"
ADD CONSTRAINT "tissue_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id");

ALTER TABLE "lab"."otoliths"
ADD CONSTRAINT "otoliths_sample_id_fk" FOREIGN KEY ("sample_id")
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."otoliths"
ADD CONSTRAINT "otoliths_reader_person_id_fk" FOREIGN KEY ("reader_person_id")
REFERENCES "reference"."personal"("person_id");

ALTER TABLE "lab"."otoliths"
ADD CONSTRAINT "otoliths_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id");

ALTER TABLE "lab"."dna"
ADD CONSTRAINT "dna_sample_id_fk" FOREIGN KEY ("sample_id") -- PK is sample_id, now references master_samples
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."dna"
ADD CONSTRAINT "dna_parent_sample_id_fk" FOREIGN KEY ("parent_sample_id")
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."dna"
ADD CONSTRAINT "dna_experiment_id_fk" FOREIGN KEY ("experiment_id")
REFERENCES "lab"."experiments"("experiment_id");

ALTER TABLE "lab"."dna"
ADD CONSTRAINT "dna_storage_id_fk" FOREIGN KEY ("storage_id")
REFERENCES "lab"."storage"("storage_id");

ALTER TABLE "lab"."dna"
ADD CONSTRAINT "dna_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id");

ALTER TABLE "lab"."rna"
ADD CONSTRAINT "rna_sample_id_fk" FOREIGN KEY ("sample_id") -- PK is sample_id, now references master_samples
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."rna"
ADD CONSTRAINT "rna_parent_sample_id_fk" FOREIGN KEY ("parent_sample_id")
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."rna"
ADD CONSTRAINT "rna_experiment_id_fk" FOREIGN KEY ("experiment_id")
REFERENCES "lab"."experiments"("experiment_id");

ALTER TABLE "lab"."rna"
ADD CONSTRAINT "rna_storage_id_fk" FOREIGN KEY ("storage_id")
REFERENCES "lab"."storage"("storage_id");

ALTER TABLE "lab"."rna"
ADD CONSTRAINT "rna_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id");

ALTER TABLE "lab"."sediments"
ADD CONSTRAINT "sediments_sample_id_fk" FOREIGN KEY ("sample_id") -- PK is sample_id, now references master_samples
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."sediments"
ADD CONSTRAINT "sediments_parent_sample_id_fk" FOREIGN KEY ("parent_sample_id")
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."sediments"
ADD CONSTRAINT "sediments_experiment_id_fk" FOREIGN KEY ("experiment_id")
REFERENCES "lab"."experiments"("experiment_id");

ALTER TABLE "lab"."sediments"
ADD CONSTRAINT "sediments_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id");

ALTER TABLE "lab"."sediments"
ADD CONSTRAINT "sediments_volume_unit_id_fk" FOREIGN KEY ("volume_unit_id")
REFERENCES "reference"."units"("unit_id");

ALTER TABLE "lab"."sediments"
ADD CONSTRAINT "sediments_storage_id_fk" FOREIGN KEY ("storage_id")
REFERENCES "lab"."storage"("storage_id");

ALTER TABLE "lab"."water"
ADD CONSTRAINT "water_sample_id_fk" FOREIGN KEY ("sample_id") -- PK is sample_id, now references master_samples
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."water"
ADD CONSTRAINT "water_parent_sample_id_fk" FOREIGN KEY ("parent_sample_id")
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."water"
ADD CONSTRAINT "water_experiment_id_fk" FOREIGN KEY ("experiment_id")
REFERENCES "lab"."experiments"("experiment_id");

ALTER TABLE "lab"."water"
ADD CONSTRAINT "water_storage_id_fk" FOREIGN KEY ("storage_id")
REFERENCES "lab"."storage"("storage_id");

ALTER TABLE "lab"."water"
ADD CONSTRAINT "water_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id");

ALTER TABLE "lab"."experiments_samples"
ADD CONSTRAINT "experiments_samples_experiment_id_fk" FOREIGN KEY ("experiment_id")
REFERENCES "lab"."experiments"("experiment_id");

ALTER TABLE "lab"."experiments_samples"
ADD CONSTRAINT "experiments_samples_sample_id_fk" FOREIGN KEY ("sample_id") -- References master_samples
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."dissections"
ADD CONSTRAINT "dissections_sample_id_fk" FOREIGN KEY ("sample_id") -- References master_samples
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."dissections"
ADD CONSTRAINT "dissections_person_id_fk" FOREIGN KEY ("person_id")
REFERENCES "reference"."personal"("person_id");

ALTER TABLE "lab"."dissections"
ADD CONSTRAINT "dissections_status_id_fk" FOREIGN KEY ("status_id")
REFERENCES "reference"."status"("status_id");

ALTER TABLE "lab"."extraction"
ADD CONSTRAINT "extraction_experiment_id_fk" FOREIGN KEY ("experiment_id")
REFERENCES "lab"."experiments"("experiment_id");

ALTER TABLE "lab"."extraction"
ADD CONSTRAINT "extraction_sample_id_fk" FOREIGN KEY ("sample_id") -- References master_samples
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."extraction"
ADD CONSTRAINT "extraction_parent_sample_id_fk" FOREIGN KEY ("parent_sample_id")
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."extraction"
ADD CONSTRAINT "extraction_sample_type_id_fk" FOREIGN KEY ("sample_type_id")
REFERENCES "reference"."samples_type"("sample_type_id");

ALTER TABLE "lab"."extraction"
ADD CONSTRAINT "extraction_extracted_dna_sample_id_fk" FOREIGN KEY ("extracted_dna_sample_id")
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."extraction"
ADD CONSTRAINT "extraction_extracted_rna_sample_id_fk" FOREIGN KEY ("extracted_rna_sample_id")
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."extraction"
ADD CONSTRAINT "extraction_person_id_fk" FOREIGN KEY ("person_id")
REFERENCES "reference"."personal"("person_id");

ALTER TABLE "lab"."extraction"
ADD CONSTRAINT "extraction_status_id_fk" FOREIGN KEY ("status_id")
REFERENCES "reference"."status"("status_id");

ALTER TABLE "lab"."extraction"
ADD CONSTRAINT "extraction_storage_id_fk" FOREIGN KEY ("storage_id")
REFERENCES "lab"."storage"("storage_id");

ALTER TABLE "lab"."extraction"
ADD CONSTRAINT "extraction_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id");

ALTER TABLE "lab"."nanodrop"
ADD CONSTRAINT "nanodrop_experiment_id_fk" FOREIGN KEY ("experiment_id")
REFERENCES "lab"."experiments"("experiment_id");

ALTER TABLE "lab"."nanodrop"
ADD CONSTRAINT "nanodrop_sample_id_fk" FOREIGN KEY ("sample_id") -- References master_samples
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."nanodrop"
ADD CONSTRAINT "nanodrop_concentration_unit_id_fk" FOREIGN KEY ("concentration_unit_id")
REFERENCES "reference"."units"("unit_id");

ALTER TABLE "lab"."nanodrop"
ADD CONSTRAINT "nanodrop_person_id_fk" FOREIGN KEY ("person_id")
REFERENCES "reference"."personal"("person_id");

ALTER TABLE "lab"."nanodrop"
ADD CONSTRAINT "nanodrop_status_id_fk" FOREIGN KEY ("status_id")
REFERENCES "reference"."status"("status_id");

ALTER TABLE "lab"."nanodrop"
ADD CONSTRAINT "nanodrop_storage_id_fk" FOREIGN KEY ("storage_id")
REFERENCES "lab"."storage"("storage_id");

ALTER TABLE "lab"."nanodrop"
ADD CONSTRAINT "nanodrop_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id");

ALTER TABLE "lab"."qubit"
ADD CONSTRAINT "qubit_sample_id_fk" FOREIGN KEY ("sample_id") -- References master_samples
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."qubit"
ADD CONSTRAINT "qubit_experiment_id_fk" FOREIGN KEY ("experiment_id")
REFERENCES "lab"."experiments"("experiment_id");

ALTER TABLE "lab"."qubit"
ADD CONSTRAINT "qubit_tube_unit_id_fk" FOREIGN KEY ("tube_unit_id")
REFERENCES "reference"."units"("unit_id");

ALTER TABLE "lab"."qubit"
ADD CONSTRAINT "qubit_original_sample_unit_id_fk" FOREIGN KEY ("original_sample_unit_id")
REFERENCES "reference"."units"("unit_id");

ALTER TABLE "lab"."qubit"
ADD CONSTRAINT "qubit_person_id_fk" FOREIGN KEY ("person_id")
REFERENCES "reference"."personal"("person_id");

ALTER TABLE "lab"."qubit"
ADD CONSTRAINT "qubit_status_id_fk" FOREIGN KEY ("status_id")
REFERENCES "reference"."status"("status_id");

ALTER TABLE "lab"."qubit"
ADD CONSTRAINT "qubit_storage_id_fk" FOREIGN KEY ("storage_id")
REFERENCES "lab"."storage"("storage_id");

ALTER TABLE "lab"."qubit"
ADD CONSTRAINT "qubit_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id");

ALTER TABLE "lab"."tapestation"
ADD CONSTRAINT "tapestation_experiment_id_fk" FOREIGN KEY ("experiment_id")
REFERENCES "lab"."experiments"("experiment_id");

ALTER TABLE "lab"."tapestation"
ADD CONSTRAINT "tapestation_person_id_fk" FOREIGN KEY ("person_id")
REFERENCES "reference"."personal"("person_id");

ALTER TABLE "lab"."tapestation"
ADD CONSTRAINT "tapestation_sample_id_fk" FOREIGN KEY ("sample_id") -- References master_samples
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."tapestation"
ADD CONSTRAINT "tapestation_storage_id_fk" FOREIGN KEY ("storage_id")
REFERENCES "lab"."storage"("storage_id");

ALTER TABLE "lab"."tapestation"
ADD CONSTRAINT "tapestation_status_id_fk" FOREIGN KEY ("status_id")
REFERENCES "reference"."status"("status_id");

ALTER TABLE "lab"."tapestation"
ADD CONSTRAINT "tapestation_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id");

ALTER TABLE "lab"."pcr"
ADD CONSTRAINT "pcr_experiment_id_fk" FOREIGN KEY ("experiment_id")
REFERENCES "lab"."experiments"("experiment_id");

ALTER TABLE "lab"."pcr"
ADD CONSTRAINT "pcr_sample_id_fk" FOREIGN KEY ("sample_id") -- References master_samples
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."pcr"
ADD CONSTRAINT "pcr_primer_id_fk" FOREIGN KEY ("primer_id")
REFERENCES "lims"."primers"("primer_id");

ALTER TABLE "lab"."pcr"
ADD CONSTRAINT "pcr_person_id_fk" FOREIGN KEY ("person_id")
REFERENCES "reference"."personal"("person_id");

ALTER TABLE "lab"."pcr"
ADD CONSTRAINT "pcr_storage_id_fk" FOREIGN KEY ("storage_id")
REFERENCES "lab"."storage"("storage_id");

ALTER TABLE "lab"."pcr"
ADD CONSTRAINT "pcr_status_id_fk" FOREIGN KEY ("status_id")
REFERENCES "reference"."status"("status_id");

ALTER TABLE "lab"."pcr"
ADD CONSTRAINT "pcr_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id");

ALTER TABLE "lab"."gelelectrophoresis"
ADD CONSTRAINT "gelelectrophoresis_experiment_id_fk" FOREIGN KEY ("experiment_id")
REFERENCES "lab"."experiments"("experiment_id");

ALTER TABLE "lab"."gelelectrophoresis"
ADD CONSTRAINT "gelelectrophoresis_sample_id_fk" FOREIGN KEY ("sample_id") -- References master_samples
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."gelelectrophoresis"
ADD CONSTRAINT "gelelectrophoresis_person_id_fk" FOREIGN KEY ("person_id")
REFERENCES "reference"."personal"("person_id");

ALTER TABLE "lab"."gelelectrophoresis"
ADD CONSTRAINT "gelelectrophoresis_storage_id_fk" FOREIGN KEY ("storage_id")
REFERENCES "lab"."storage"("storage_id");

ALTER TABLE "lab"."gelelectrophoresis"
ADD CONSTRAINT "gelelectrophoresis_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id");

ALTER TABLE "lab"."qpcr"
ADD CONSTRAINT "qpcr_experiment_id_fk" FOREIGN KEY ("experiment_id")
REFERENCES "lab"."experiments"("experiment_id");

ALTER TABLE "lab"."qpcr"
ADD CONSTRAINT "qpcr_sample_id_fk" FOREIGN KEY ("sample_id") -- References master_samples
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."qpcr"
ADD CONSTRAINT "qpcr_person_id_fk" FOREIGN KEY ("person_id")
REFERENCES "reference"."personal"("person_id");

ALTER TABLE "lab"."qpcr"
ADD CONSTRAINT "qpcr_primer_id_fk" FOREIGN KEY ("primer_id")
REFERENCES "lims"."primers"("primer_id");

ALTER TABLE "lab"."qpcr"
ADD CONSTRAINT "qpcr_storage_id_fk" FOREIGN KEY ("storage_id")
REFERENCES "lab"."storage"("storage_id");

ALTER TABLE "lab"."qpcr"
ADD CONSTRAINT "qpcr_status_id_fk" FOREIGN KEY ("status_id")
REFERENCES "reference"."status"("status_id");

ALTER TABLE "lab"."qpcr"
ADD CONSTRAINT "qpcr_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id");

ALTER TABLE "lab"."library"
ADD CONSTRAINT "library_experiment_id_fk" FOREIGN KEY ("experiment_id")
REFERENCES "lab"."experiments"("experiment_id");

ALTER TABLE "lab"."library"
ADD CONSTRAINT "library_sample_id_fk" FOREIGN KEY ("sample_id") -- References master_samples
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."library"
ADD CONSTRAINT "library_person_id_fk" FOREIGN KEY ("person_id")
REFERENCES "reference"."personal"("person_id");

ALTER TABLE "lab"."library"
ADD CONSTRAINT "library_storage_id_fk" FOREIGN KEY ("storage_id")
REFERENCES "lab"."storage"("storage_id");

ALTER TABLE "lab"."library"
ADD CONSTRAINT "library_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id");

ALTER TABLE "lab"."sequencing"
ADD CONSTRAINT "sequencing_experiment_id_fk" FOREIGN KEY ("experiment_id")
REFERENCES "lab"."experiments"("experiment_id");

ALTER TABLE "lab"."sequencing"
ADD CONSTRAINT "sequencing_library_id_fk" FOREIGN KEY ("library_id")
REFERENCES "lab"."library"("library_id");

ALTER TABLE "lab"."sequencing"
ADD CONSTRAINT "sequencing_sample_id_fk" FOREIGN KEY ("sample_id") -- References master_samples
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."sequencing"
ADD CONSTRAINT "sequencing_person_id_fk" FOREIGN KEY ("person_id")
REFERENCES "reference"."personal"("person_id");

ALTER TABLE "lab"."sequencing"
ADD CONSTRAINT "sequencing_status_id_fk" FOREIGN KEY ("status_id")
REFERENCES "reference"."status"("status_id");

ALTER TABLE "lab"."sequencing"
ADD CONSTRAINT "sequencing_storage_id_fk" FOREIGN KEY ("storage_id")
REFERENCES "lab"."storage"("storage_id");

ALTER TABLE "lab"."sequencing"
ADD CONSTRAINT "sequencing_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id");

ALTER TABLE "lab"."datasets"
ADD CONSTRAINT "datasets_ecosystem_id_fk" FOREIGN KEY ("ecosystem_id")
REFERENCES "reference"."ecosystem"("ecosystem_id");

ALTER TABLE "lab"."datasets"
ADD CONSTRAINT "datasets_region_id_fk" FOREIGN KEY ("region_id")
REFERENCES "reference"."region"("region_id");

ALTER TABLE "lab"."datasets"
ADD CONSTRAINT "datasets_customer_id_fk" FOREIGN KEY ("customer_id")
REFERENCES "lims"."customers"("customer_id");

ALTER TABLE "lab"."datasets"
ADD CONSTRAINT "datasets_stored_location_id_fk" FOREIGN KEY ("stored_location_id")
REFERENCES "lab"."storage"("storage_id");

-- Bioinformatics Schema FKs
ALTER TABLE "bioinformatics"."analysis_runs"
ADD CONSTRAINT "analysis_runs_pipeline_id_fk" FOREIGN KEY ("pipeline_id")
REFERENCES "bioinformatics"."analysis_pipelines"("pipeline_id");

ALTER TABLE "bioinformatics"."analysis_runs"
ADD CONSTRAINT "analysis_runs_sequencing_id_fk" FOREIGN KEY ("sequencing_id")
REFERENCES "lab"."sequencing"("sequencing_id");

ALTER TABLE "bioinformatics"."analysis_runs"
ADD CONSTRAINT "analysis_runs_person_id_fk" FOREIGN KEY ("person_id")
REFERENCES "reference"."personal"("person_id");

ALTER TABLE "bioinformatics"."analysis_runs"
ADD CONSTRAINT "analysis_runs_reference_db_id_fk" FOREIGN KEY ("reference_db_id")
REFERENCES "bioinformatics"."reference_databases"("db_id");

ALTER TABLE "bioinformatics"."edna_assignments"
ADD CONSTRAINT "edna_assignments_run_id_fk" FOREIGN KEY ("run_id")
REFERENCES "bioinformatics"."analysis_runs"("run_id");

ALTER TABLE "bioinformatics"."edna_assignments"
ADD CONSTRAINT "edna_assignments_sample_id_fk" FOREIGN KEY ("sample_id") -- References master_samples
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "bioinformatics"."edna_assignments"
ADD CONSTRAINT "edna_assignments_taxon_id_fk" FOREIGN KEY ("taxon_id")
REFERENCES "reference"."taxon"("taxon_id");
