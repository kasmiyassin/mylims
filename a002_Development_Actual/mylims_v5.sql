-- -------------------------------------------------
-- Code for lims and ELN and booking system 
-- For genetic and fish biology lab
-- V4., 2025-12-20
-- -------------------------------------------------


-- =========================================
-- 1. EXTENSIONS
-- =========================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "postgres_fdw";
CREATE EXTENSION IF NOT EXISTS "hstore";
CREATE EXTENSION IF NOT EXISTS "tablefunc";
CREATE EXTENSION IF NOT EXISTS "ltree";
CREATE EXTENSION IF NOT EXISTS "postgis";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =========================================
-- 2. SCHEMA CREATION
-- =========================================
CREATE SCHEMA IF NOT EXISTS "reference";
CREATE SCHEMA IF NOT EXISTS "core";
CREATE SCHEMA IF NOT EXISTS "lims";
CREATE SCHEMA IF NOT EXISTS "field";
CREATE SCHEMA IF NOT EXISTS "bio_assets";
CREATE SCHEMA IF NOT EXISTS "biologyfish";
CREATE SCHEMA IF NOT EXISTS "moleculargenetics";
CREATE SCHEMA IF NOT EXISTS "bioinformatics";
CREATE SCHEMA IF NOT EXISTS "communications";
CREATE SCHEMA IF NOT EXISTS "eln";
CREATE SCHEMA IF NOT EXISTS "audit";

-- =========================================
-- 3. AUDIT SCHEMA
-- =========================================
CREATE TABLE IF NOT EXISTS "audit"."audit_log" (
    "id" bigserial PRIMARY KEY,
    "schema_name" text NOT NULL,
    "table_name" text NOT NULL,
    "user_db_name" text DEFAULT current_user,
    "logged_in_person_id" text,
    "action_timestamp" timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "action" text NOT NULL CHECK ("action" IN ('I', 'D', 'U', 'T')),
    "original_data" jsonb,
    "new_data" jsonb,
    "query_text" text
);

-- =========================================
-- 4. REFERENCE SCHEMA
-- =========================================
CREATE TABLE IF NOT EXISTS "reference"."status" (
    "status_id" text PRIMARY KEY,
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "reference"."category" (
    "category_id" text PRIMARY KEY,
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "reference"."sampling_type" (
    "sampling_type_id" text PRIMARY KEY,
    "abbreviation" text UNIQUE NOT NULL,
    "rank" text,
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "reference"."units" (
    "unit_id" text PRIMARY KEY,
    "unit_name" text NOT NULL,
    "unit_abbreviation" text UNIQUE NOT NULL,
    "unit_type" text NOT NULL,
    "parent_unit_id" text REFERENCES "reference"."units"("unit_id"),
    "conversion_factor" numeric,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "reference"."taxon" (
    "taxon_id" text PRIMARY KEY,
    "parent_taxon_id" text REFERENCES "reference"."taxon"("taxon_id"),
    "scientific_name" text,
    "common_name_en" text,
    "common_name_de" text,
    "common_name_de" text,
    -- "has_fork_length" boolean DEFAULT false
    -- "has_standard_length" boolean DEFAULT false
    -- "has_otoliths" boolean DEFAULT false
    -- "has_scales" boolean DEFAULT false
    -- "max_total_length_mm" integer,
    -- "max_fork_length_mm" integer
    -- "max_standard_length_mm" integer
    -- "max_weight_g" integer,

    -- "is_fish" boolean DEFAULT false -- I was thinking maybe if we also sample other organisms for isotopes in the Weser, we should prep the database also for that?
    -- "is_invertebrate" boolean DEFAULT false
    -- "is_plant" boolean DEFAULT false

    "rank" text,
    "path" ltree,
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "reference"."region" (
    "region_id" text PRIMARY KEY,
    "region_abrv" text UNIQUE NOT NULL,
    "parent_region" text,
    "tags" text,
    "notes" text,
    "path" ltree,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "reference"."ecosystem" (
    "ecosystem_id" text PRIMARY KEY,
    "ecosystem_abrv" text UNIQUE NOT NULL,
    "tags" text,
    "notes" text,
    "path" ltree,
    "attachment" bytea,
    "attachment_link" text
);


CREATE TABLE IF NOT EXISTS "reference"."genes" (
    "gene_id" text PRIMARY KEY,
    "gene_name" text,
    "description" text,
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "reference"."reference_databases" (
    "db_id" serial PRIMARY KEY,
    "db_name" text NOT NULL,
    "version" text,
    "url" text,
    "last_updated" date,
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);


-- =========================================
-- 5. CORE SCHEMA
-- =========================================
CREATE TABLE IF NOT EXISTS "core"."organizations" (
    "organization_id" text PRIMARY KEY,
    "name" text NOT NULL,
    "type" text CHECK (type IN ('Internal', 'Partner', 'Supplier', 'Customer')),
    "address" text,
    "contact_email" text,
    "contact_phone" text,
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "core"."persons" (
    "person_id" text PRIMARY KEY,
    "salutation" text,
    "first_name" text NOT NULL,
    "last_name" text NOT NULL,
    "email" text UNIQUE,
    "phone" text,
    "organization_id" text REFERENCES "core"."organizations"("organization_id"),
    "room" text,
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "core"."locations" (
    "build_id" text PRIMARY KEY,
    "parent_build_id" text REFERENCES "core"."locations"("build_id"),
    "name" text,
    "etage" text,
    "address" text,
    "institute" text,
    "city" text,
    "country" text,
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
    "path" ltree
);

CREATE TABLE IF NOT EXISTS "core"."equipments" (
    "equipment_id" text PRIMARY KEY,
    "name" text NOT NULL,
    "model" text,
    "serial_number" text,
    "manufacturer_id" text REFERENCES "core"."organizations"("organization_id"),
    "purchase_date" date,
    "room_id" text REFERENCES "core"."locations"("build_id"),
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);


CREATE TABLE IF NOT EXISTS "core"."vessel" (
    "vessel_id" text PRIMARY KEY,
    "vessel_name" text,
    "captain" text REFERENCES "core"."persons"("person_id"),
    "belong_to" text,
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

-- =========================================
-- 6. LIMS SCHEMA
-- =========================================
CREATE TABLE IF NOT EXISTS "lims"."projects" (
    "project_id" text PRIMARY KEY,
    "title" text NOT NULL,
    "acronym" text,
    "start_date" date,
    "end_date" date,
    "funding_source" text,
    "pi_person_id" text REFERENCES "core"."persons"("person_id"),
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "description" text,
    "report_date" date,
    "contact_finance" text,
    "contact_funder" text,
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "lims"."project_personal" (
    "project_id" text REFERENCES "lims"."projects"("project_id") ON DELETE CASCADE,
    "person_id" text REFERENCES "core"."persons"("person_id") ON DELETE CASCADE,
    "role" text,
    "start_date" date,
    "end_date" date,,
    PRIMARY KEY ("project_id", "person_id")
);

CREATE TABLE IF NOT EXISTS "lims"."permits" (
    "permit_id" text PRIMARY KEY,
    "permit_number" text,
    "issuing_authority" text,
    "valid_from" date,
    "valid_to" date,
    "reference" text,
    "project_id" text REFERENCES "lims"."projects"("project_id") ON DELETE CASCADE,
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "lims"."sop" (
    "sop_id" text PRIMARY KEY,
    "title" text NOT NULL,
    "version" text,
    "author_id" text REFERENCES "core"."persons"("person_id"),
    "reviewer1_person_id" text  REFERENCES "core"."persons"("person_id"),
    "reviewer2_person_id" text  REFERENCES "core"."persons"("person_id"),
    "content" text,
    "attachment" bytea,
    "attachment_link" text,
    "tags" text,
    "notes" text
);

CREATE TABLE IF NOT EXISTS "lims"."storage" (
    "storage_id" text PRIMARY KEY,
    "room_id" text REFERENCES "core"."locations"("build_id"),
    "parent_storage_id" text REFERENCES "lims"."storage"("storage_id"),
    "type" text, 
    "name" text,
    "capacity_slots" integer,
    "box_size_x" numeric,
    "box_size_y" numeric,
    "storage_position_format" text,
    "project_id" text REFERENCES "lims"."projects"("project_id"),
    "temperature_c" numeric,
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "lims"."reagents" (
    "reagent_id" text PRIMARY KEY,
    "name" text NOT NULL,
    "lot_number" text,
    "supplier_id" text REFERENCES "core"."organizations"("organization_id"),
    "catalog_number" text,
    "expiry_date" date,
    "storage_id" text REFERENCES "lims"."storage"("storage_id"),
    "quantity" numeric,
    "unit_id" text REFERENCES "reference"."units"("unit_id"),
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "lims"."experiments" (
    "experiment_id" text PRIMARY KEY,
    "title" text,
    "date" date NOT NULL DEFAULT CURRENT_DATE,
    "aim" text,
    "method" text,
    "sop_id" text REFERENCES "lims"."sop"("sop_id"),
    "person_id" text REFERENCES "core"."persons"("person_id"),
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "lims"."experiments_projects" (
    "experiment_id" text REFERENCES "lims"."experiments"("experiment_id"),
    "project_id" text REFERENCES "lims"."projects"("project_id"),
    PRIMARY KEY ("experiment_id", "project_id")
);

-- =========================================
-- 7. FIELD SCHEMA
-- =========================================
CREATE TABLE IF NOT EXISTS "field"."cruises" (
    "cruise_id" text PRIMARY KEY,
    "name" text,
    "vessel_id" text REFERENCES "core"."vessel"("vessel_id"),
    "start_date" date,
    "end_date" date,
    "chief_scientist_id" text REFERENCES "core"."persons"("person_id"),
    "captain_id" text REFERENCES "core"."persons"("person_id"),
    "project_id" text REFERENCES "lims"."projects"("project_id"),
    "region_id" text REFERENCES "reference"."region"("region_id"),
    "ecosystem_id" text REFERENCES "reference"."ecosystem"("ecosystem_id"),
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "tags" text,
    "notes" text
);

CREATE TABLE IF NOT EXISTS "field"."sampling_event" (
    "sampling_id" text PRIMARY KEY,
    "sampling_date" date NOT NULL,
    "External_sampling_id" text,
    "project_id" text REFERENCES "lims"."projects"("project_id"),
    "cruise_id" text REFERENCES "field"."cruises"("cruise_id"),
    "region_id" text REFERENCES "reference"."region"("region_id"),
    "ecosystem_id" text REFERENCES "reference"."ecosystem"("ecosystem_id"),
    "vessel_id" text REFERENCES "core"."vessel"("vessel_id"),
    "customer_id" integer REFERENCES "core"."organizations"("organization_id"),
    "experiment_id" text REFERENCES "lims"."experiments"("experiment_id"),
    "latitude" numeric,
    "longitude" numeric,
    "geography" geography(Point, 4326),
    "together_with_contact_id" text REFERENCES "core"."persons"("person_id"),
    "status_id" text DEFAULT 'Planned' NOT NULL REFERENCES "reference"."status"("status_id"),
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "field"."sampling_abiotic" (
    "sampling_id" text PRIMARY KEY REFERENCES "field"."sampling"("sampling_id"),
    "weather" text,
    "temperature_atmospheric_c" numeric,
    "temperature_sampling_depth_c" numeric,
    "wind_speed" numeric,
    "wind_unit_id" text REFERENCES "reference"."units"("unit_id"),
    "salinity" numeric,
    "salinity_unit_id" text REFERENCES "reference"."units"("unit_id"),
    "pressure" numeric,
    "pressure_unit_id" text REFERENCES "reference"."units"("unit_id"),
    "oxygen" numeric,
    "oxygen_unit_id" text REFERENCES "reference"."units"("unit_id"),
    "conductivity" numeric,
    "conductivity_unit_id" text REFERENCES "reference"."units"("unit_id"),
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
    "cloud_cover_percent" numeric,
    "rainfall_mm" numeric,
    "instrument_id" text,
    "visibility_m" numeric,
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
    "creation_date" timestamptz DEFAULT CURRENT_TIMESTAMP,
    "instrument_id" text REFERENCES "core"."equipments"("equipment_id"),
    "notes" text,
);

CREATE TABLE IF NOT EXISTS "field"."sampling_abiotic_v2" ( -- this how tthypically the table of abiotic should looks in sql
    "sampling_id" text REFERENCES "field"."sampling"("sampling_id"),
    "parameter" text NOT NULL,
    "value" numeric,
    "unit_id" text REFERENCES "reference"."units"("unit_id"),
    "instrument_id" text REFERENCES "core"."equipments"("equipment_id"),
    "notes" text,
    PRIMARY KEY ("sampling_id", "parameter")
);

CREATE TABLE IF NOT EXISTS "field"."fishing" (
    "sampling_id" text PRIMARY KEY REFERENCES "field"."sampling"("sampling_id"),
    "sampling_date" date,
    "latitude" numeric,
    "longitude" numeric,
    "fishing_geography" geography(Geography, 4326),
    "location_name" text,
    "depth_m" numeric,
    "start_time" time,
    "end_time" time,
    "fishing_time_min" time,
    "fishing_method" text,
    "gear_type" text,
    "soak_time" numeric,
    "soak_time_unit_id" text REFERENCES "reference"."units"("unit_id"),
    "trawl_speed" numeric,
    "trawl_speed_unit_id" text REFERENCES "reference"."units"("unit_id"),
    "total_catch_quantity_kg" numeric,
    "total_catch_quantity_fish" numeric,
    "catch_notes" text,
    "operation_duration_min" numeric,
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "field"."catch" (
    "catch_id" serial PRIMARY KEY,
    "sampling_id" text REFERENCES "field"."sampling"("sampling_id"),
    "total_catch_weight_kg" numeric,
    "taxon_id" text REFERENCES "reference"."taxon"("taxon_id"),
    "quantity_weight_kg" numeric,
    "quantity_count" integer,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

-- =========================================
-- 8. BIO_ASSETS SCHEMA
-- =========================================
CREATE TABLE IF NOT EXISTS "bio_assets"."samples_reservation" (
    "reservation_sample_id" text PRIMARY KEY,
    "sample_type_id" text NOT NULL REFERENCES "reference"."samples_type"("sample_type_id"),
    "project_id" text REFERENCES "lims"."projects"("project_id"),
    "sampling_id" text,
    "experiment_id" text REFERENCES "lims"."experiments"("experiment_id"),
    "planned_date" date,
    "transport" text,
    "conservation" text,
    "status_id" text REFERENCES "reference"."status"("status_id") DEFAULT 'Planned',
    "other_info" text,
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
    "actual_sample_id" text
);

CREATE TABLE IF NOT EXISTS "bio_assets"."samples_root" (
    "sample_id" text PRIMARY KEY,
    "sample_type_id" text REFERENCES "reference"."sampling_type"("sampling_type_id"),
    "external_id" text,
    "migfish_id" text,
    "parent_sample_id" text REFERENCES "bio_assets"."samples_root"("sample_id"),
    "sampling_id" text REFERENCES "field"."sampling"("sampling_id"),
    "experiment_id" text REFERENCES "lims"."experiments"("experiment_id"),
    "collection_date" date,
    "storage_id" text REFERENCES "lims"."storage"("storage_id"),
    "storage_position" text,
    "sampler_person_id" text,
    "receiver_person_id" text REFERENCES "lims"."personal"("person_id"),
    "reception_date" date,
    "transport" text,
    "conservation" text,
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "batch_id" text REFERENCES "eln"."batch"("batch_id"),
    "project_id" text REFERENCES "lims"."projects"("project_id"),
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
);

CREATE TABLE IF NOT EXISTS "lims"."experiments_samples" (
    "experiment_id" text REFERENCES "lims"."experiments"("experiment_id"),
    "sample_id" text REFERENCES "bio_assets"."samples_root"("sample_id"),
    PRIMARY KEY ("experiment_id", "sample_id")
);

CREATE TABLE IF NOT EXISTS "bio_assets"."organisms" (
    "sample_id" text PRIMARY KEY REFERENCES "bio_assets"."samples_root"("sample_id"),
    "taxon_id" text REFERENCES "reference"."taxon"("taxon_id"),
    "sex" text CHECK (sex IN ('Male', 'Female', 'Undetermined', 'Hermaphrodite')),
    "total_length_mm" integer, --I think all these should be integer, as we won´t measure/weigh a fish in micrometer or milligrams
    "fork_length_mm" integer,
    "standard_length_mm" integer,
    "weight_g" integer,
    "sex" text,
    "maturity_stage" text,
    "stomach_contents" text,
    "stomach_contents_jsonb" JSONB,
    "disease_info" JSONB,
    "tag_id" text,
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
    "creation_date" timestamptz DEFAULT CURRENT_TIMESTAMP,
);

CREATE TABLE IF NOT EXISTS "bio_assets"."tissue" (
    "sample_id" text PRIMARY KEY REFERENCES "bio_assets"."samples_root"("sample_id"),
    "tissue_type" text,
    "preservation_medium" text,
    "weight_mg" numeric,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "bio_assets"."nucleic_acid" ( --RNA or DNA
    "sample_id" text PRIMARY KEY REFERENCES "bio_assets"."samples_root"("sample_id"),
    "extraction_method" text,
    "concentration_ng_ul" numeric,
    "volume_ul" numeric,
    "a260_a280" numeric,
    "a260_280" numeric,
    "a260_230" numeric,
    "rin_score" numeric, -- RIN or DIN
    "extraction_method" text,
    "extraction_date" date,
    "extraction_number" integer,
    "kit" text,
    "elution_volume_ul" numeric,
    "yield_qubit_ng_ul" numeric,
    "yield_nanodrop_ng_ul" numeric,
    "extraction_blank_id" text,
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);


CREATE TABLE IF NOT EXISTS "bio_assets"."sediments" (
    "sample_id" text PRIMARY KEY REFERENCES "bio_assets"."samples_root"("sample_id"),
    "grain_size" text,
    "weight_mg" numeric,
    "depth_m" numeric,
    "sampling_method" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "bio_assets"."water" (
    "sample_id" text PRIMARY KEY REFERENCES "bio_assets"."samples_root"("sample_id"),
    "volume_filtered_ml" numeric,
    "filter_type" text,
    "pore_size_um" numeric,
    "depth_m" numeric,
    "sampling_method" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

-- =========================================
-- 9. BIOLOGYFISH SCHEMA
-- =========================================
CREATE TABLE IF NOT EXISTS "biologyfish"."otoliths" (
    "otolith_id" text PRIMARY KEY,
    "experiment_id" text REFERENCES "lims"."experiments"("experiment_id"),
    "sample_id" text REFERENCES "bio_assets"."organisms"("sample_id"),
    "age_read" integer,
    "read_by_person_id" text REFERENCES "core"."persons"("person_id"),
    "confidence_level" text,
    "image_path" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "biologyfish"."dissection" (
    "dissection_id" text PRIMARY KEY,
    "sample_id" text REFERENCES "bio_assets"."organisms"("sample_id"),
    "experiment_id" text REFERENCES "lims"."experiments"("experiment_id"),
    "date" date,
    "liver_weight_mg" numeric,
    "gonad_weight_mg" numeric,
    "stomach_content_weight_mg" numeric,
    "stomach_fullness_index" text,
    "stomach_contents_jsonb" JSONB,
    "parasite_observation" JSONB,
    "pathology_observation" JSONB,
    "person_id" text REFERENCES "core"."persons"("person_id"),
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "biologyfish"."tag_mark" (
    "tag_id" text PRIMARY KEY,
    "sample_id" text REFERENCES "bio_assets"."organisms"("sample_id"),
    "experiment_id" text REFERENCES "lims"."experiments"("experiment_id"),
    "date" date,
    "weight_mg" numeric,
    "total_length_mm" numeric,
    "model_type" text,
    "tag_id" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);



-- =========================================
-- 10. MOLECULARGENETICS SCHEMA
-- =========================================
CREATE TABLE IF NOT EXISTS "moleculargenetics"."nanodrop" (
    "measurement_id" serial PRIMARY KEY,
    "sample_id" text REFERENCES "bio_assets"."samples_root"("sample_id"),
    "experiment_id" text REFERENCES "lims"."experiments"("experiment_id"),
    "date" time,
    "concentration" numeric,
    "unit" text DEFAULT 'ng/ul',
    "a260" numeric,
    "a280" numeric,
    "a260_a280" numeric,
    "a260_a230" numeric,
    "notes" text
);

CREATE TABLE IF NOT EXISTS "moleculargenetics"."qubit" (
    "measurement_id" serial PRIMARY KEY,
    "sample_id" text REFERENCES "bio_assets"."samples_root"("sample_id"),
    "date" timestamptz DEFAULT CURRENT_TIMESTAMP,
    "concentration" numeric,
    "unit" text DEFAULT 'ng/ul',
    "assay_type" text,
    "notes" text
);

CREATE TABLE IF NOT EXISTS "moleculargenetics"."tapestation" (
    "measurement_id" serial PRIMARY KEY,
    "sample_id" text REFERENCES "bio_assets"."samples_root"("sample_id"),
    "date" timestamptz DEFAULT CURRENT_TIMESTAMP,
    "avg_size_bp" numeric,
    "concentration" numeric,
    "molarity" numeric,
    "notes" text
);

CREATE TABLE IF NOT EXISTS "moleculargenetics"."pcr" (
    "pcr_id" text PRIMARY KEY,
    "sample_id" text REFERENCES "bio_assets"."samples_root"("sample_id"),
    "experiment_id" text REFERENCES "lims"."experiments"("experiment_id"),
    "primer_fwd_id" text,
    "primer_rev_id" text,
    "polymerase" text,
    "cycles" integer,
    "annealing_temp_c" numeric,
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "notes" text
);

CREATE TABLE IF NOT EXISTS "moleculargenetics"."qpcr" (
    "qpcr_id" text PRIMARY KEY,
    "sample_id" text REFERENCES "bio_assets"."samples_root"("sample_id"),
    "experiment_id" text REFERENCES "lims"."experiments"("experiment_id"),
    "target_gene_id" text REFERENCES "reference"."genes"("gene_id"),
    "ct_value" numeric,
    "notes" text
);

CREATE TABLE IF NOT EXISTS "moleculargenetics"."gelelectrophoresis" (
    "gel_id" text PRIMARY KEY,
    "sample_id" text REFERENCES "bio_assets"."samples_root"("sample_id"),
    "experiment_id" text REFERENCES "lims"."experiments"("experiment_id"),
    "gel_percentage" numeric,
    "voltage" numeric,
    "run_time_min" integer,
    "band_size_bp" integer,
    "image_path" text,
    "notes" text
);

CREATE TABLE IF NOT EXISTS "moleculargenetics"."library" (
    "library_id" text PRIMARY KEY,
    "sample_id" text REFERENCES "bio_assets"."samples_root"("sample_id"),
    "experiment_id" text REFERENCES "lims"."experiments"("experiment_id"),
    "prep_kit" text,
    "index_i7" text,
    "index_i5" text,
    "avg_fragment_size" numeric,
    "molarity_nm" numeric,
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "notes" text
);

CREATE TABLE IF NOT EXISTS "moleculargenetics"."sequencing_flowcells" (
    "flowcell_id" text PRIMARY KEY,
    "type" text,
    "sequencer_id" text REFERENCES "core"."equipments"("equipment_id"),
    "run_date" date,
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "notes" text
);

CREATE TABLE IF NOT EXISTS "moleculargenetics"."sequencing" (
    "run_id" text PRIMARY KEY,
    "flowcell_id" text REFERENCES "moleculargenetics"."sequencing_flowcells"("flowcell_id"),
    "library_id" text REFERENCES "moleculargenetics"."library"("library_id"),
    "lane_number" integer,
    "raw_read_count" bigint,
    "raw_path" text,
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "notes" text
);

-- =========================================
-- 11. BIOINFORMATICS SCHEMA
-- =========================================
CREATE TABLE IF NOT EXISTS "bioinformatics"."pipelines" (
    "pipeline_id" text PRIMARY KEY,
    "name" text NOT NULL,
    "version" text,
    "repository_url" text,
    "parameters_json" jsonb,
    "notes" text
);

CREATE TABLE IF NOT EXISTS "bioinformatics"."seq_dataset" (
    "dataset_id" text PRIMARY KEY,
    "run_id" text REFERENCES "moleculargenetics"."sequencing"("run_id"),
    "file_path" text,
    "file_format" text CHECK (file_format IN ('FASTQ', 'FASTA', 'BAM', 'SAM')),
    "read_count_filtered" bigint,
    "quality_metrics_json" jsonb,
    "notes" text
);

CREATE TABLE IF NOT EXISTS "bioinformatics"."assignments" (
    "assignment_id" bigserial PRIMARY KEY,
    "dataset_id" text REFERENCES "bioinformatics"."seq_dataset"("dataset_id"),
    "pipeline_id" text REFERENCES "bioinformatics"."pipelines"("pipeline_id"),
    "taxon_id" text REFERENCES "reference"."taxon"("taxon_id"),
    "count" integer,
    "confidence" numeric,
    "otu_id" text,
    "notes" text
);

-- =========================================
-- 12. ELN SCHEMA
-- =========================================
CREATE TABLE IF NOT EXISTS "eln"."batch" (
    "batch_id" text PRIMARY KEY,
    "name" text,
    "description" text,
    "creation_date" date DEFAULT CURRENT_DATE,
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "notes" text
);

CREATE TABLE IF NOT EXISTS "eln"."bookable_resources" (
    "resource_id" text PRIMARY KEY,
    "equipment_id" text REFERENCES "core"."equipments"("equipment_id"),
    "name" text,
    "is_active" boolean DEFAULT true,
    "calendar_color" text,
    "notes" text
);

CREATE TABLE IF NOT EXISTS "eln"."bookings" (
    "booking_id" bigserial PRIMARY KEY,
    "resource_id" text REFERENCES "eln"."bookable_resources"("resource_id"),
    "person_id" text REFERENCES "core"."persons"("person_id"),
    "start_time" timestamptz NOT NULL,
    "end_time" timestamptz NOT NULL,
    "project_id" text REFERENCES "lims"."projects"("project_id"),
    "notes" text
);

CREATE TABLE IF NOT EXISTS "eln"."protocols" (
    "protocol_id" text PRIMARY KEY,
    "title" text NOT NULL,
    "author_id" text REFERENCES "core"."persons"("person_id"),
    "created_at" date DEFAULT CURRENT_DATE,
    "content_json" jsonb,
    "version" text,
    "notes" text
);

CREATE TABLE IF NOT EXISTS "eln"."protocols_run" (
    "run_id" text PRIMARY KEY,
    "protocol_id" text REFERENCES "eln"."protocols"("protocol_id"),
    "experiment_id" text REFERENCES "lims"."experiments"("experiment_id"),
    "person_id" text REFERENCES "core"."persons"("person_id"),
    "run_date" timestamptz DEFAULT CURRENT_TIMESTAMP,
    "data_json" jsonb,
    "notes" text
);

-- =========================================
-- 13. COMMUNICATIONS SCHEMA
-- =========================================
CREATE TABLE IF NOT EXISTS "communications"."projects_chat" (
    "message_id" bigserial PRIMARY KEY,
    "project_id" text REFERENCES "lims"."projects"("project_id"),
    "sender_id" text REFERENCES "core"."persons"("person_id"),
    "sent_at" timestamptz DEFAULT CURRENT_TIMESTAMP,
    "message_body" text,
    "attachment_path" text
);

CREATE TABLE IF NOT EXISTS "communications"."internal_plans" (
    "plan_id" text PRIMARY KEY,
    "title" text,
    "created_by" text REFERENCES "core"."persons"("person_id"),
    "deadline" date,
    "content" text,
    "status_id" text REFERENCES "reference"."status"("status_id")
);

CREATE TABLE IF NOT EXISTS "communications"."reports" (
    "report_id" text PRIMARY KEY,
    "project_id" text REFERENCES "lims"."projects"("project_id"),
    "title" text,
    "generated_by" text REFERENCES "core"."persons"("person_id"),
    "generation_date" date DEFAULT CURRENT_DATE,
    "file_path" text,
    "type" text
);
