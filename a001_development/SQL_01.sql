-- ======================================================================
-- Complete PostgreSQL Schema for LIMS Database
-- ======================================================================

-- ======================================================================
-- 0. Pre-Cleanup
-- ======================================================================

DROP SCHEMA IF EXISTS "lab" CASCADE;
DROP SCHEMA IF EXISTS "lims" CASCADE;
DROP SCHEMA IF EXISTS "reference" CASCADE;
DROP SCHEMA IF EXISTS "bioinformatics" CASCADE;
DROP SCHEMA IF EXISTS "audit" CASCADE;

DROP EXTENSION IF EXISTS "uuid-ossp";
DROP EXTENSION IF EXISTS pg_trgm;
DROP EXTENSION IF EXISTS postgres_fdw;
DROP EXTENSION IF EXISTS hstore;
DROP EXTENSION IF EXISTS tablefunc;
DROP EXTENSION IF EXISTS ltree;
-- DROP EXTENSION IF NOT EXISTS postgis;

DROP TABLE IF EXISTS "projects"."ProjectWanderfische_ChatMessage" CASCADE;
DROP TABLE IF EXISTS "projects"."ProjectWanderfische_Conversation" CASCADE;
DROP TABLE IF EXISTS "projects"."ProjectWanderfische_Mail" CASCADE;
DROP TABLE IF EXISTS "projects"."ProjectWanderfische_FishCatch" CASCADE;
DROP TABLE IF EXISTS "projects"."ProjectWanderfische_FishingData" CASCADE;

DROP SEQUENCE IF EXISTS "projects"."ProjectWanderfische_FishingData_seq";
DROP SEQUENCE IF EXISTS "projects"."ProjectWanderfische_FishCatch_seq";
DROP SEQUENCE IF EXISTS "projects"."ProjectWanderfische_Mail_seq";
DROP SEQUENCE IF EXISTS "projects"."ProjectWanderfische_Conversation_seq";
DROP SEQUENCE IF EXISTS "projects"."ProjectWanderfische_ChatMessage_seq";

-- ======================================================================
-- 1. Extensions
-- ======================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS postgres_fdw;
CREATE EXTENSION IF NOT EXISTS hstore;
CREATE EXTENSION IF NOT EXISTS tablefunc;
CREATE EXTENSION IF NOT EXISTS ltree;
CREATE EXTENSION IF NOT EXISTS postgis;

-- ======================================================================
-- 2. Schema Creation
-- ======================================================================

CREATE SCHEMA IF NOT EXISTS "lab";
CREATE SCHEMA IF NOT EXISTS "lims";
CREATE SCHEMA IF NOT EXISTS "reference";
CREATE SCHEMA IF NOT EXISTS "bioinformatics";
CREATE SCHEMA IF NOT EXISTS "audit";
CREATE SCHEMA IF NOT EXISTS "projects";

-- ======================================================================
-- 3. Audit Log Table
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
    "taxon_parent" text,
    "de_name" text,
    "en_name" text,
    "rank" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
    "path" ltree
);

CREATE TABLE IF NOT EXISTS "reference"."species" (
    "species_id" text PRIMARY KEY,
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
    "customer_id" serial PRIMARY KEY,
    "customer_name" text NOT NULL,
    "customer_abrv" text UNIQUE NOT NULL,
    "address" text,
    "mail" text,
    "phone" text,
    "password_hash" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "lims"."projects" (
    "project_id" text PRIMARY KEY,
    "title" text,
    "status_id" text,
    "pi_person_id" text,
    "funder" text,
    "customer_id" integer,
    "start_date" date,
    "end_date" date,
    "report_date" date,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "lims"."project_persons" (
    "project_id" text,
    "person_id" text,
    "role" text,
    PRIMARY KEY ("project_id", "person_id"),
    "link_date" date,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "lab"."storage" (
    "storage_id" text PRIMARY KEY,
    "room_id" text,
    "freezer" text,
    "etage" text,
    "temperature_c" numeric,
    "box" text,
    "box_size_x" numeric,
    "box_size_y" numeric,
    "storage_position_format" text,
    "project_id" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "lims"."cruises" (
    "cruise_id" text PRIMARY KEY,
    "project_id" text,
    "vessel_id" text,
    "status_id" text DEFAULT 'Received' NOT NULL,
    "region_id" text,
    "ecosystem_id" text,
    "capitaine_contact_id" text,
    "chief_scientist_person_id" text,
    "start_date" date,
    "end_date" date,
    "together_with_contact_id" text,
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
    "target_gene_id" text,
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
    "author_person_id" text,
    "reviewer1_person_id" text,
    "reviewer2_person_id" text,
    "date_realise" date,
    "sop_protocol" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "lims"."workflow_steps" (
    "step_id" text PRIMARY KEY,
    "workflow_id" text NOT NULL,
    "step_number" integer NOT NULL,
    "step_name" text NOT NULL,
    "sop_id" text,
    "workflow_status_id" text DEFAULT 'Received' NOT NULL,
    "target_table_name" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
    UNIQUE ("workflow_id", "step_number")
);

CREATE TABLE IF NOT EXISTS "lims"."equipment" (
    "equipment_id" text PRIMARY KEY,
    "equipment_name" text,
    "room_id" text,
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
    "category_id" text,
    "notes" text,
    "unit_id" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "lims"."orders" (
    "fi_order_nr" text PRIMARY KEY,
    "item_id" text,
    "category_id" text,
    "order_date" date,
    "price" numeric,
    "quantity" numeric,
    "project_id" text,
    "supplier_id" text,
    "status_id" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "lims"."reagents" (
    "reagent_id" text PRIMARY KEY,
    "reagent_complete_name" text NOT NULL,
    "category_id" text,
    "lot" text,
    "storage_id" text,
    "storage_position" numeric,
    "status_id" text,
    "reception_date" date,
    "expire_date" date,
    "order_id" text,
    "project_id" text,
    "quantity_available" numeric,
    "quantity_unit_id" text,
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
    "publication_type_id" text,
    "project_id" text,
    "title" text NOT NULL,
    "journal" text,
    "volume" text,
    "issue" text,
    "pages" text,
    "doi" text,
    "date_publication" date,
    "date_submission" date,
    "first_author_person_id" text,
    "corresponding_author_person_id" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
    UNIQUE ("doi", "date_publication")
);

-- ======================================================================
-- 6. Lab Schema Tables
-- ======================================================================

CREATE TABLE IF NOT EXISTS "lab"."experiments" (
    "experiment_id" text NOT NULL,
    "experiment_title" text,
    "aim" text,
    "method" text,
    "sop_id" text,
    "experiment_date" date NOT NULL,
    "person_id" text,
    "notes" text,
    "lab_book" text,
    "status_id" text,
    "attachment" bytea,
    "attachment_link" text,
    PRIMARY KEY ("experiment_id", "experiment_date")
) PARTITION BY RANGE ("experiment_date");

CREATE TABLE IF NOT EXISTS "lab"."experiments_projects" (
    "experiment_project_id" serial PRIMARY KEY,
    "experiment_id" text NOT NULL,
    "experiment_date" date NOT NULL,
    "project_id" text,
    "link_date" date,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "lab"."protocol_runs" (
    "protocol_run_id" text PRIMARY KEY,
    "experiment_id" text NOT NULL,
    "experiment_date" date NOT NULL,
    "sop_id" text,
    "protocol_text" text,
    "run_date" date NOT NULL,
    "person_id" text NOT NULL,
    "protocol_run_details" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE "lab"."sampling" (
    "sampling_id" text NOT NULL,
    "experiment_id" text,
    "experiment_date" date,
    "project_id" text,
    "cruise_id" text,
    "region_id" text,
    "ecosystem_id" text,
    "vessel_id" text,
    "customer_id" integer,
    "sampling_date" date NOT NULL,
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
    "wind_unit_id" text,
    "temperature_sampling_depth_c" numeric,
    "salinity" numeric,
    "salinity_unit_id" text,
    "pressure" numeric,
    "pressure_unit_id" text,
    "oxygen" numeric,
    "oxygen_unit_id" text,
    "conductivity" numeric,
    "conductivity_unit_id" text,
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
    "sample_type_id" text,
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
    "soak_time_unit_id" text,
    "trawl_speed" numeric,
    "trawl_speed_unit_id" text,
    "total_catch_quantity_kg" numeric,
    "total_catch_quantity_fish" numeric,
    "catch_notes" text,
    "operation_duration_min" numeric,
    "together_with_contact_id" text,
    "status_id" text DEFAULT 'Planned' NOT NULL,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
) PARTITION BY RANGE ("sampling_date");

ALTER TABLE "lab"."sampling" ADD PRIMARY KEY ("sampling_id", "sampling_date");

CREATE TABLE IF NOT EXISTS "lab"."master_samples" (
    "sample_id" text PRIMARY KEY,
    "created_at" timestamptz DEFAULT CURRENT_TIMESTAMP,
    "notes" text
);

CREATE TABLE "lab"."parental_samples" (
    "sample_id" text NOT NULL,
    "external_name" text,
    "parent_sample_id" text,
    "sampling_id" text,
    "sampling_date" date,
    "storage_id" text,
    "storage_position" text,
    "sampler_person_id" text,
    "receiver_person_id" text,
    "reception_date" date,
    "transport" text,
    "conservation_buffer" text,
    "sample_type_id" text NOT NULL,
    "sample_status_id" text DEFAULT 'Received' NOT NULL,
    "workflow_id" text,
    "step_id" text,
    "project_id" text,
    "customer_id" integer,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
	"experiment_id" text,
    "experiment_date" date,
    PRIMARY KEY ("sample_id", "sampling_date")
) PARTITION BY RANGE ("sampling_date");

CREATE TABLE IF NOT EXISTS "lab"."fishing" (
    "fishing_id" text NOT NULL,
    "sampling_id" text NOT NULL,
    "sampling_date" date NOT NULL,
    "taxon_id" text,
    "catch_kg" numeric,
    "catch_fish" numeric,
    "customer_id" integer,
	"experiment_id" text,
    "experiment_date" date,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
	PRIMARY KEY ("fishing_id", "sampling_date")
) PARTITION BY RANGE ("sampling_date");


CREATE TABLE IF NOT EXISTS "lab"."storage_log" (
    "log_id" serial PRIMARY KEY,
    "sample_id" text NOT NULL,
    "sample_sampling_date" date NOT NULL,
    "storage_id" text NOT NULL,
    "person_id" text,
    "move_date" timestamptz DEFAULT CURRENT_TIMESTAMP,
    "status" text NOT NULL,
    "storage_position" text,
    "notes" text
);

CREATE TABLE IF NOT EXISTS "lab"."fish" (
    "sample_id" text NOT NULL,
    "parent_sample_id" text,
    -- Removed "experiment_id"
    "sampling_id" text NOT NULL, -- New column for sampling_id, now part of the conceptual PK
    "sampling_date" date NOT NULL, -- This is the new partitioning key
    -- Removed "experiment_date" as it's replaced by "sampling_date" conceptually for partitioning
    "species_id" text NOT NULL,
    "total_length_mm" numeric,
    "fork_length_mm" numeric,
    "standard_length_mm" numeric,
    "weight_g" numeric,
    "sex" text,
    "maturity_stage" text,
    "stomach_contents" text,
    "disease_info" text,
    "tag_id" text,
    "storage_id" text,
    "storage_position" text,
    "project_id" text,
    "customer_id" integer,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
	"experiment_id" text,
    "experiment_date" date NOT NULL,
    -- The primary key must include ALL partitioning columns, hence sampling_date is included.
    PRIMARY KEY ("sample_id", "sampling_date")
) PARTITION BY RANGE ("sampling_date"); -- Partition by sampling_date

ALTER TABLE "lab"."fish" ADD CONSTRAINT chk_fish_sex_enum CHECK ("sex" IN ('Male', 'Female', 'Undetermined', NULL));

CREATE TABLE IF NOT EXISTS "lab"."tissue" (
    "sample_id" text NOT NULL,
    "parent_sample_id" text,
    "experiment_id" text,
    "experiment_date" date NOT NULL,
    "weight_mg" numeric,
    "tissue_type" text,
    "preservation_method" text,
    "storage_id" text,
    "storage_position" text,
    "project_id" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
	PRIMARY KEY ("sample_id", "experiment_date")
) PARTITION BY RANGE ("experiment_date");



CREATE TABLE IF NOT EXISTS "lab"."otoliths" (
    "otolith_id" text NOT NULL,
    "sample_id" text NOT NULL,
    "experiment_id" text NOT NULL,
    "experiment_date" date NOT NULL,
    "reader_person_id" text NOT NULL,
    "side" text NOT NULL,
    "age_reading_years" numeric,
    "confidence" numeric,
    "project_id" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
) PARTITION BY RANGE ("experiment_date");

ALTER TABLE "lab"."otoliths" ADD PRIMARY KEY ("otolith_id", "experiment_date");

CREATE TABLE IF NOT EXISTS "lab"."dna" (
    "sample_id" text NOT NULL,
    "parent_sample_id" text,
    "experiment_id" text,
    "experiment_date" date NOT NULL,
    "volume_ul" numeric,
    "concentration_ng_ul" numeric,
    "a260_280" numeric,
    "a260_230" numeric,
    "extraction_method" text,
    "preservation_method" text,
    "extraction_date" date,
    "extraction_number" integer,
    "storage_id" text,
    "storage_position" text,
    "project_id" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
	PRIMARY KEY ("sample_id", "experiment_date")
) PARTITION BY RANGE ("experiment_date");



CREATE TABLE IF NOT EXISTS "lab"."rna" (
    "sample_id" text NOT NULL,
    "parent_sample_id" text,
    "experiment_id" text,
    "experiment_date" date NOT NULL,
    "volume_ul" numeric,
    "concentration_ng_ul" numeric,
    "a260_280" numeric,
    "a260_230" numeric,
    "extraction_method" text,
    "preservation_method" text,
    "extraction_date" date,
    "extraction_number" integer,
    "storage_id" text,
    "storage_position" text,
    "project_id" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
	PRIMARY KEY ("sample_id", "experiment_date")
) PARTITION BY RANGE ("experiment_date");


CREATE TABLE IF NOT EXISTS "lab"."sediments" (
    "sample_id" text NOT NULL,
    "parent_sample_id" text,
    "experiment_id" text,
    "experiment_date" date NOT NULL,
    "project_id" text,
    "volume" numeric,
    "volume_unit_id" text,
    "depth_m" numeric,
    "sampling_method" text,
    "conservation_buffer" text,
    "storage_id" text,
    "storage_position" text,
    "external_name" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
	PRIMARY KEY ("sample_id", "experiment_date")
) PARTITION BY RANGE ("experiment_date");

CREATE TABLE IF NOT EXISTS "lab"."water" (
    "sample_id" text NOT NULL,
    "parent_sample_id" text,
    "experiment_id" text,
    "experiment_date" date NOT NULL,
    "volume_l" numeric,
    "filter" text,
    "filter_pore_size_um" numeric,
    "depth_m" numeric,
    "sampling_method" text,
    "conservation_buffer" text,
    "storage_id" text,
    "storage_position" text,
    "notes" text,
    "project_id" text,
    "attachment" bytea,
    "attachment_link" text,
	PRIMARY KEY ("sample_id", "experiment_date")
) PARTITION BY RANGE ("experiment_date");

CREATE TABLE IF NOT EXISTS "lab"."experiments_samples" (
    "experiment_id" text NOT NULL,
    "experiment_date" date NOT NULL,
    "sample_id" text NOT NULL,
    "notes" text,
    PRIMARY KEY ("experiment_id", "sample_id", "experiment_date")
);

CREATE TABLE IF NOT EXISTS "lab"."dissections" (
    "dissection_id" text NOT NULL,
    "sample_id" text NOT NULL,
    "person_id" text NOT NULL,
    "dissection_date" date NOT NULL,
    "experiment_id" text,
    "experiment_date" date NOT NULL,
    "stomach_contents_jsonb" jsonb,
    "gonad_weight_g" numeric,
    "liver_weight_g" numeric,
    "notes" text,
    "status_id" text,
    "created_at" timestamptz DEFAULT CURRENT_TIMESTAMP,
    "attachment" bytea,
    "attachment_link" text,
    PRIMARY KEY ("dissection_id", "dissection_date")
) PARTITION BY RANGE ("dissection_date");

CREATE TABLE IF NOT EXISTS "lab"."extraction" (
    "extraction_id" text NOT NULL,
    "experiment_id" text,
    "experiment_date" date,
    "sample_id" text,
    "parent_sample_id" text,
    "sample_type_id" text NOT NULL,
    "extracted_dna_sample_id" text,
    "extracted_rna_sample_id" text,
    "extraction_date" date NOT NULL,
    "person_id" text NOT NULL,
    "kit" text,
    "elution_volume_ul" numeric,
    "yield_qubit_ng_ul" numeric,
    "yield_nanodrop_ng_ul" numeric,
    "a260_280" numeric,
    "a260_230" numeric,
    "extraction_blank_id" text,
    "notes" text,
    "status_id" text,
    "storage_id" text,
    "storage_position" text,
    "project_id" text,
    "attachment" bytea,
    "attachment_link" text,
    PRIMARY KEY ("extraction_id", "extraction_date")
) PARTITION BY RANGE ("extraction_date");

CREATE TABLE IF NOT EXISTS "lab"."nanodrop" (
    "nanodrop_id" text NOT NULL,
    "experiment_id" text,
    "experiment_date" date,
    "sample_id" text,
    "nanodrop_concentration" numeric,
    "concentration_unit_id" text,
    "a260" numeric,
    "a260_280" numeric,
    "a260_280_note" text,
    "a260_230" numeric,
    "a260_230_note" text,
    "measurement_date" date NOT NULL,
    "elution_volume_ul" numeric,
    "person_id" text,
    "notes" text,
    "status_id" text,
    "attachment" bytea,
    "attachment_link" text,
    "storage_id" text,
    "storage_position" text,
    "project_id" text,
    "result_date" timestamptz,
    "nanodrop_total_dna_ug" numeric GENERATED ALWAYS AS (("elution_volume_ul" * "nanodrop_concentration") / 1000) STORED,
    PRIMARY KEY ("nanodrop_id", "measurement_date")
) PARTITION BY RANGE ("measurement_date");

CREATE TABLE IF NOT EXISTS "lab"."qubit" (
    "qubit_id" text NOT NULL,
    "sample_id" text,
    "experiment_id" text,
    "experiment_date" date,
    "run_id" text,
    "assay_kit" text,
    "measurement_date" date NOT NULL,
    "qubit_tube_conc" numeric,
    "tube_unit_id" text,
    "qubit_original_sample_conc" numeric,
    "original_sample_unit_id" text,
    "sample_volume_ul" numeric,
    "elution_volume_ul" numeric,
    "person_id" text,
    "notes" text,
    "status_id" text,
    "storage_id" text,
    "storage_position" text,
    "project_id" text,
    "attachment" bytea,
    "attachment_link" text,
    "qubit_total_dna_ug" numeric GENERATED ALWAYS AS (("elution_volume_ul" * "qubit_original_sample_conc") / 1000) STORED,
    PRIMARY KEY ("qubit_id", "measurement_date")
) PARTITION BY RANGE ("measurement_date");

CREATE TABLE IF NOT EXISTS "lab"."tapestation" (
    "tapestation_id" text NOT NULL,
    "experiment_id" text,
    "experiment_date" date,
    "position" text,
    "measurement_date" date NOT NULL,
    "kit" text,
    "person_id" text,
    "notes" text,
    "sample_id" text,
    "storage_id" text,
    "storage_position" text,
    "status_id" text,
    "project_id" text,
    "attachment" bytea,
    "attachment_link" text,
    PRIMARY KEY ("tapestation_id", "measurement_date")
) PARTITION BY RANGE ("measurement_date");

CREATE TABLE IF NOT EXISTS "lab"."pcr" (
    "pcr_id" text NOT NULL,
    "experiment_id" text,
    "experiment_date" date,
    "sample_id" text,
    "position" text,
    "primer_id" text,
    "pcr_blank_id" text,
    "pcr_date" date NOT NULL,
    "person_id" text,
    "kit" text,
    "storage_id" text,
    "storage_position" text,
    "status_id" text,
    "notes" text,
    "project_id" text,
    "attachment" bytea,
    "attachment_link" text,
    "volume_reaction_ul" numeric,
    PRIMARY KEY ("pcr_id", "pcr_date")
) PARTITION BY RANGE ("pcr_date");

CREATE TABLE IF NOT EXISTS "lab"."gelelectrophoresis" (
    "gelelectrophoresis_id" text NOT NULL,
    "experiment_id" text,
    "experiment_date" date,
    "sample_id" text,
    "position" text,
    "ladder" text,
    "voltage" numeric,
    "band_size_bp" integer,
    "gel_type" text,
    "run_time_minutes" numeric,
    "run_date" date NOT NULL,
    "person_id" text,
    "storage_id" text,
    "storage_position" text,
    "project_id" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
    PRIMARY KEY ("gelelectrophoresis_id", "run_date")
) PARTITION BY RANGE ("run_date");

CREATE TABLE IF NOT EXISTS "lab"."qpcr" (
    "qpcr_id" text NOT NULL,
    "experiment_id" text,
    "experiment_date" date,
    "sample_id" text,
    "position" text,
    "qpcr_date" date NOT NULL,
    "person_id" text,
    "primer_id" text,
    "ct_value" numeric,
    "inhibitor_test_result" text,
    "pcr_blank_id" text,
    "kit" text,
    "volume_ul" numeric,
    "storage_id" text,
    "storage_position" text,
    "status_id" text,
    "project_id" text,
    "attachment" bytea,
    "attachment_link" text,
    PRIMARY KEY ("qpcr_id", "qpcr_date")
) PARTITION BY RANGE ("qpcr_date");

CREATE TABLE IF NOT EXISTS "lab"."library" (
    "library_id" text NOT NULL,
    "experiment_id" text,
    "experiment_date" date,
    "sample_id" text NOT NULL,
    "library_name" text,
    "prep_date" date NOT NULL,
    "person_id" text,
    "library_prep_kit" text,
    "index_sequence" text,
    "read_length_bp" integer,
    "storage_id" text,
    "storage_position" text,
    "project_id" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
    PRIMARY KEY ("library_id", "prep_date")
) PARTITION BY RANGE ("prep_date");

CREATE TABLE IF NOT EXISTS "lab"."sequencing" (
    "sequencing_id" text NOT NULL,
    "experiment_id" text,
    "experiment_date" date,
    "library_id" text,
    "prep_date" date,
    "sample_id" text NOT NULL,
    "sequencing_date" date NOT NULL,
    "person_id" text,
    "sequencer" text,
    "flow_cell_id" text,
    "library_prep_kit" text,
    "index_sequence" text,
    "read_length_bp" integer,
    "total_reads" bigint,
    "raw_data_path" text,
    "genbank_accession_number" text,
    "status_id" text,
    "storage_id" text,
    "storage_position" text,
    "project_id" text,
    "attachment" bytea,
    "attachment_link" text,
    "notes" text,
    PRIMARY KEY ("sequencing_id", "sequencing_date")
) PARTITION BY RANGE ("sequencing_date");

CREATE TABLE IF NOT EXISTS "lab"."datasets" (
    "dataset_id" text NOT NULL,
    "source_type" text,
    "ecosystem_id" text,
    "experiment_id" text,
    "experiment_date" date NOT NULL,
    "region_id" text,
    "customer_id" integer,
    "stored_location_id" text,
    "reception_date" date NOT NULL,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
    "storage_path" text,
    PRIMARY KEY ("dataset_id", "reception_date")
) PARTITION BY RANGE ("reception_date");

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
	"experiment_id" text,
    "experiment_date" date,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "bioinformatics"."analysis_pipelines" (
    "pipeline_id" text PRIMARY KEY,
    "pipeline_name" text NOT NULL,
    "version" text NOT NULL,
    "repository_link" text,
	"experiment_id" text,
    "experiment_date" date,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "bioinformatics"."analysis_runs" (
    "run_id" text NOT NULL,
    "pipeline_id" text NOT NULL,
    "sequencing_id" text NOT NULL,
    "sequencing_date" date NOT NULL,
    "person_id" text NOT NULL,
    "run_date" timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "parameters_jsonb" jsonb,
    "reference_db_id" text,
    "clustering_threshold" numeric,
    "final_output_path" text,
	"experiment_id" text,
    "experiment_date" date,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
    PRIMARY KEY ("run_id", "run_date")
) PARTITION BY RANGE ("run_date");

CREATE TABLE IF NOT EXISTS "bioinformatics"."edna_assignments" (
    "assignment_id" text PRIMARY KEY,
    "run_id" text NOT NULL,
    "run_date" date NOT NULL,
    "sample_id" text NOT NULL,
    "taxon_id" text NOT NULL,
    "read_count" integer,
    "confidence" numeric,
	"experiment_id" text,
    "experiment_date" date,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);



-- ======================================================================
-- Schema Creation for 'projects'
-- New Tables for Wanderfische Project
-- ======================================================================

-- Table for Universal Fishing Data
-- This table is designed to consolidate various fishing data inputs from different agencies.
-- It includes fields for standardized data, a JSONB column for original raw data,
-- and geographical coordinates with projection handling.
CREATE TABLE IF NOT EXISTS "projects"."ProjectWanderfische_FishingData" (
    "fishing_record_id" text NOT NULL, -- Part of composite PK, unique per year
    "agency_id" text NOT NULL, -- Link to lims.external_contacts for the agency
    "project_id" text NOT NULL, -- Link to lims.projects for the Wanderfische project
    "agency_record_id" text,    -- Original ID from the contributing agency
    "record_date" date NOT NULL, -- Partitioning key, part of composite PK
    "record_time" time,
    "fishing_year" integer,

    -- Temporal details for fishing operation
    "fishing_start_time" time,
    "fishing_end_time" time,

    -- Location Information (Original and Standardized)
    "original_easting" numeric,
    "original_northing" numeric,
    "original_latitude" numeric,
    "original_longitude" numeric,
    "original_srid" integer, -- SRID of the original coordinates (e.g., 25832 for UTM32N, 4326 for WGS84)
    "geom_4326" geometry(Point, 4326), -- Standardized WGS84 point using PostGIS

    "location_description" text, -- e.g., Messstellen_Bezeichnung, NAME_LAGE, Lagebeschreibung, Messstelle (kurz)
    "water_body_name" text,      -- e.g., Gewässername, Gewässer
    "water_body_code" text,      -- e.g., GWKZ, Wasserkörper Nr.
    "water_body_type" text,      -- e.g., 'river', 'lake', 'estuary', 'sea'
    "catchment_area" text,       -- e.g., 'Rhine', 'Elbe'
    "district" text,             -- e.g., Landkreis, Bearbeitungsgebiet
    "water_depth_m" numeric,     -- Depth at fishing location

    -- Fishing Event Details
    "fishing_method" text,       -- e.g., "watend/Boot", Art_Elektrobefischung, Methode
    "gear_type" text,            -- e.g., E-Gerät
    "fishing_length_m" numeric,  -- e.g., Abschnitts-länge, Befischungslaenge, Befischte Strecke [m]
    "fishing_area_sqm" numeric,  -- e.g., Befischte Fläche [m²]
    "average_width_m" numeric,   -- e.g., Breite, mittl. Breite in m
    "total_catch_quantity_kg" numeric,
    "total_catch_quantity_fish" integer,

    -- Environmental Parameters (from sampling data, if available)
    "temperature_c" numeric,
    "salinity" numeric,
    "salinity_unit_id" text,     -- FK to reference.units
    "oxygen" numeric,
    "oxygen_unit_id" text,       -- FK to reference.units
    "ph" numeric,
    "turbidity_ntu" numeric,
    "weather_conditions" text,
    "wind_speed" numeric,
    "wind_unit_id" text,         -- FK to reference.units

    "notes" text,
    "attachment" bytea,
    "attachment_link" text,

    "original_data_jsonb" jsonb, -- To store the complete original row data from the agency

    "created_at" timestamptz DEFAULT CURRENT_TIMESTAMP,
    "created_by" text,           -- Link to reference.personal
    "last_modified_at" timestamptz DEFAULT CURRENT_TIMESTAMP,
    "last_modified_by" text,      -- Link to reference.personal

    PRIMARY KEY ("fishing_record_id", "record_date") -- Composite Primary Key for partitioning
) PARTITION BY RANGE ("record_date");

-- Table for detailed fish catch information per fishing record
-- This allows for multiple species to be recorded per fishing event.
CREATE TABLE IF NOT EXISTS "projects"."ProjectWanderfische_FishCatch" (
    "fish_catch_id" text PRIMARY KEY,
    "fishing_record_id" text NOT NULL, -- FK to ProjectWanderfische_FishingData
    "fishing_record_date" date NOT NULL, -- Added for composite FK
    "taxon_id" text,                    -- FK to reference.taxon for standardized species
    "scientific_name_raw" text,         -- Original scientific name from agency
    "german_name_raw" text,             -- Original German name from agency
    "total_count" integer,
    "juvenile_count" integer,
    "praeadult_count" integer,
    "adult_count" integer,
    "individual_length_mm" numeric,     -- Length of an individual fish
    "individual_weight_g" numeric,      -- Weight of an individual fish
    "sex" text CHECK ("sex" IN ('Male', 'Female', 'Undetermined', NULL)),
    "maturity_stage" text,
    "condition_factor" numeric,
    "disease_info" text,
    "origin_type" text CHECK ("origin_type" IN ('Wild', 'Hatchery', 'Unknown', NULL)),
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
    "created_at" timestamptz DEFAULT CURRENT_TIMESTAMP,
    "created_by" text,
    "last_modified_at" timestamptz DEFAULT CURRENT_TIMESTAMP,
    "last_modified_by" text
);

-- Table for managing mail communications related to fishing records
CREATE TABLE IF NOT EXISTS "projects"."ProjectWanderfische_Mail" (
    "mail_id" text PRIMARY KEY,
    "fishing_record_id" text,           -- Optional FK to ProjectWanderfische_FishingData
    "fishing_record_date" date,         -- Added for composite FK
    "sender_person_id" text,            -- FK to reference.personal (internal sender)
    "recipient_contact_id" text,        -- FK to lims.external_contacts (external recipient)
    "subject" text NOT NULL,
    "body" text,
    "sent_at" timestamptz NOT NULL,
    "attachment" bytea,
    "attachment_link" text,
    "notes" text,
    "created_at" timestamptz DEFAULT CURRENT_TIMESTAMP,
    "created_by" text,
    "last_modified_at" timestamptz DEFAULT CURRENT_TIMESTAMP,
    "last_modified_by" text
);

-- Table for managing conversation threads related to fishing records
CREATE TABLE IF NOT EXISTS "projects"."ProjectWanderfische_Conversation" (
    "conversation_id" text PRIMARY KEY,
    "fishing_record_id" text,           -- Optional FK to ProjectWanderfische_FishingData
    "fishing_record_date" date,         -- Added for composite FK
    "topic" text NOT NULL,
    "started_at" timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "last_updated_at" timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "notes" text,
    "created_at" timestamptz DEFAULT CURRENT_TIMESTAMP,
    "created_by" text,
    "last_modified_at" timestamptz DEFAULT CURRENT_TIMESTAMP,
    "last_modified_by" text
);

-- Table for individual chat messages within a conversation thread
CREATE TABLE IF NOT EXISTS "projects"."ProjectWanderfische_ChatMessage" (
    "message_id" text PRIMARY KEY,
    "conversation_id" text NOT NULL,    -- FK to ProjectWanderfische_Conversation
    "sender_person_id" text,            -- FK to reference.personal (internal sender)
    "sender_contact_id" text,           -- FK to lims.external_contacts (external sender)
    "message_text" text NOT NULL,
    "sent_at" timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "attachment" bytea,
    "attachment_link" text,
    "notes" text,
    "created_at" timestamptz DEFAULT CURRENT_TIMESTAMP,
    "created_by" text,
    "last_modified_at" timestamptz DEFAULT CURRENT_TIMESTAMP,
    "last_modified_by" text
);

--  ====================================================
--  00. Functions
--  ========================================================

-- Function to populate experiment_id and experiment_date for lab.fishing
-- Derives data from lab.sampling based on sampling_id and sampling_date
CREATE OR REPLACE FUNCTION "lab".populate_fishing_experiment_data()
RETURNS TRIGGER AS $$
DECLARE
    exp_id text;
    exp_date date;
BEGIN
    -- Look up experiment_id and experiment_date from lab.sampling
    -- using the sampling_id and sampling_date present in the new fishing record.
    SELECT s.experiment_id, s.experiment_date
    INTO exp_id, exp_date
    FROM "lab"."sampling" s
    WHERE s.sampling_id = NEW.sampling_id AND s.sampling_date = NEW.sampling_date;

    -- Raise an exception if the associated experiment data cannot be found,
    -- as experiment_date is now NOT NULL for partitioning.
    IF exp_id IS NULL OR exp_date IS NULL THEN
        RAISE EXCEPTION 'Could not find associated experiment_id or experiment_date for sampling_id % on date % for fishing record. Ensure sampling data is complete.', NEW.sampling_id, NEW.sampling_date;
    END IF;

    -- Assign the retrieved experiment data to the new fishing record
    NEW.experiment_id := exp_id;
    NEW.experiment_date := exp_date;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- Function to populate experiment_id and experiment_date for lab.otoliths
-- Derives data from lab.samples and then lab.experiments
CREATE OR REPLACE FUNCTION "lab".populate_otoliths_experiment_data()
RETURNS TRIGGER AS $$
DECLARE
    exp_id text;
    exp_date date;
    -- Removed sample_exp_id, sample_exp_date as they tried to read non-existent columns from samples
BEGIN
    -- Derive experiment_id and experiment_date by joining lab.samples to lab.sampling,
    -- and then to lab.experiments.
    SELECT
        sa.experiment_id,
        sa.experiment_date
    INTO
        exp_id,
        exp_date
    FROM
        "lab"."parental_samples" s
    JOIN
        "lab"."sampling" sa ON s.sampling_id = sa.sampling_id AND s.sampling_date = sa.sampling_date
    WHERE
        s.sample_id = NEW.sample_id
        AND s.sampling_date IS NOT NULL; -- Ensure sampling_date is not null for the join

    -- Raise an exception if the associated experiment data cannot be found,
    -- as experiment_date is NOT NULL for partitioning.
    IF exp_id IS NULL OR exp_date IS NULL THEN
        RAISE EXCEPTION 'Could not find associated experiment_id or experiment_date for sample_id % from sampling record for otolith record. Ensure sample and sampling data are complete.', NEW.sample_id;
    END IF;

    -- Assign the retrieved experiment data to the new otolith record
    NEW.experiment_id := exp_id;
    NEW.experiment_date := exp_date;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "lab".create_dna_partition_if_not_exists_manual(p_year integer)
RETURNS VOID AS $$
DECLARE
    start_date date;
    end_date date;
    partition_name text;
BEGIN
    start_date := MAKE_DATE(p_year, 1, 1);
    end_date := MAKE_DATE(p_year + 1, 1, 1);
    partition_name := 'y' || p_year;

    EXECUTE 'CREATE TABLE IF NOT EXISTS "lab".' || quote_ident(partition_name) || ' PARTITION OF "lab"."dna"
             FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';
END;
$$ LANGUAGE plpgsql;


-- 
CREATE OR REPLACE FUNCTION "lab".create_sampling_partition_if_not_exists_manual (p_year integer)
RETURNS VOID AS $$
DECLARE
    start_date date;
    end_date date;
    partition_name text;
BEGIN
    start_date := MAKE_DATE(p_year, 1, 1);
    end_date := MAKE_DATE(p_year + 1, 1, 1);
    partition_name := 'y' || TO_CHAR(start_date, 'YYYY');

    EXECUTE 'CREATE TABLE IF NOT EXISTS "lab".' || quote_ident(partition_name) || ' PARTITION OF "lab"."fish"
             FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';
END;
$$ LANGUAGE plpgsql;





-- ===================================================================================================
-- Corrected Function for lab.dna partitions
CREATE OR REPLACE FUNCTION "lab".create_dna_partition_if_not_exists_manual (p_year integer)
RETURNS VOID AS $$
DECLARE
    start_date date;
    end_date date;
    partition_name text;
BEGIN
    start_date := MAKE_DATE(p_year, 1, 1);
    end_date := MAKE_DATE(p_year + 1, 1, 1);
    partition_name := 'dna_y' || p_year; -- Consistent naming convention

    EXECUTE 'CREATE TABLE IF NOT EXISTS "lab".' || quote_ident(partition_name) || ' PARTITION OF "lab"."dna"
             FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';
END;
$$ LANGUAGE plpgsql;

-- Corrected Function for lab.fish partitions
CREATE OR REPLACE FUNCTION "lab".create_fish_partition_if_not_exists_manual(p_year integer)
RETURNS VOID AS $$
DECLARE
    start_date date;
    end_date date;
    partition_name text;
BEGIN
    start_date := MAKE_DATE(p_year, 1, 1);
    end_date := MAKE_DATE(p_year + 1, 1, 1);
    partition_name := 'fish_y' || TO_CHAR(start_date, 'YYYY'); -- Consistent naming

    EXECUTE 'CREATE TABLE IF NOT EXISTS "lab".' || quote_ident(partition_name) || ' PARTITION OF "lab"."fish"
             FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';
END;
$$ LANGUAGE plpgsql;

-- Corrected Function for lab.fishing partitions
CREATE OR REPLACE FUNCTION "lab".create_fishing_partition_if_not_exists_manual (p_year integer)
RETURNS VOID AS $$
DECLARE
    start_date date;
    end_date date;
    partition_name text;
BEGIN
    start_date := MAKE_DATE(p_year, 1, 1);
    end_date := MAKE_DATE(p_year + 1, 1, 1);
    partition_name := 'fishing_y' || TO_CHAR(start_date, 'YYYY'); -- Consistent naming

    EXECUTE 'CREATE TABLE IF NOT EXISTS "lab".' || quote_ident(partition_name) || ' PARTITION OF "lab"."fishing"
             FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';
END;
$$ LANGUAGE plpgsql;

-- Corrected Function for lab.otoliths partitions
CREATE OR REPLACE FUNCTION "lab".create_otoliths_partition_if_not_exists_manual (p_year integer)
RETURNS VOID AS $$
DECLARE
    start_date date;
    end_date date;
    partition_name text;
BEGIN
    start_date := MAKE_DATE(p_year, 1, 1);
    end_date := MAKE_DATE(p_year + 1, 1, 1);
    partition_name := 'otoliths_y' || TO_CHAR(start_date, 'YYYY'); -- Consistent naming

    EXECUTE 'CREATE TABLE IF NOT EXISTS "lab".' || quote_ident(partition_name) || ' PARTITION OF "lab"."otoliths"
             FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';
END;
$$ LANGUAGE plpgsql;

-- Corrected Function for lab.rna partitions
CREATE OR REPLACE FUNCTION "lab".create_rna_partition_if_not_exists_manual (p_year integer)
RETURNS VOID AS $$
DECLARE
    start_date date;
    end_date date;
    partition_name text;
BEGIN
    start_date := MAKE_DATE(p_year, 1, 1);
    end_date := MAKE_DATE(p_year + 1, 1, 1);
    partition_name := 'rna_y' || TO_CHAR(start_date, 'YYYY'); -- Consistent naming

    EXECUTE 'CREATE TABLE IF NOT EXISTS "lab".' || quote_ident(partition_name) || ' PARTITION OF "lab"."rna"
             FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';
END;
$$ LANGUAGE plpgsql;

-- Corrected Function for lab.sediments partitions
CREATE OR REPLACE FUNCTION "lab".create_sediments_partition_if_not_exists_manual (p_year integer)
RETURNS VOID AS $$
DECLARE
    start_date date;
    end_date date;
    partition_name text;
BEGIN
    start_date := MAKE_DATE(p_year, 1, 1);
    end_date := MAKE_DATE(p_year + 1, 1, 1);
    partition_name := 'sediments_y' || TO_CHAR(start_date, 'YYYY'); -- Consistent naming

    EXECUTE 'CREATE TABLE IF NOT EXISTS "lab".' || quote_ident(partition_name) || ' PARTITION OF "lab"."sediments"
             FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';
END;
$$ LANGUAGE plpgsql;

-- Corrected Function for lab.tissue partitions
CREATE OR REPLACE FUNCTION "lab".create_tissue_partition_if_not_exists_manual (p_year integer)
RETURNS VOID AS $$
DECLARE
    start_date date;
    end_date date;
    partition_name text;
BEGIN
    start_date := MAKE_DATE(p_year, 1, 1);
    end_date := MAKE_DATE(p_year + 1, 1, 1);
    partition_name := 'tissue_y' || TO_CHAR(start_date, 'YYYY'); -- Consistent naming

    EXECUTE 'CREATE TABLE IF NOT EXISTS "lab".' || quote_ident(partition_name) || ' PARTITION OF "lab"."tissue"
             FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';
END;
$$ LANGUAGE plpgsql;

-- Corrected Function for lab.water partitions
CREATE OR REPLACE FUNCTION "lab".create_water_partition_if_not_exists_manual (p_year integer)
RETURNS VOID AS $$
DECLARE
    start_date date;
    end_date date;
    partition_name text;
BEGIN
    start_date := MAKE_DATE(p_year, 1, 1);
    end_date := MAKE_DATE(p_year + 1, 1, 1);
    partition_name := 'water_y' || TO_CHAR(start_date, 'YYYY'); -- Consistent naming

    EXECUTE 'CREATE TABLE IF NOT EXISTS "lab".' || quote_ident(partition_name) || ' PARTITION OF "lab"."water"
             FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';
END;
$$ LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION "lab".create_rna_partition_if_not_exists()
RETURNS TRIGGER AS $$
DECLARE
    partition_date date;
    partition_name text;
    start_date date;
    end_date date;
BEGIN
    partition_date := NEW.experiment_date;
    IF partition_date IS NULL THEN
        RAISE EXCEPTION 'Cannot partition on NULL experiment_date for lab.rna. Please provide an experiment_date.';
    END IF;

    start_date := DATE_TRUNC('year', partition_date);
    end_date := DATE_TRUNC('year', partition_date) + INTERVAL '1 year';
    partition_name := 'rna_y' || TO_CHAR(start_date, 'YYYY');

    EXECUTE 'CREATE TABLE IF NOT EXISTS "lab".' || quote_ident(partition_name) || ' PARTITION OF "lab"."rna"
             FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- And the trigger that uses it:
CREATE TRIGGER trg_create_rna_partition
BEFORE INSERT ON "lab"."rna"
FOR EACH ROW
EXECUTE FUNCTION "lab".create_rna_partition_if_not_exists();

-- ======================================================================
-- 8. Sequences for ID Generation
-- ======================================================================

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


CREATE SEQUENCE IF NOT EXISTS "projects"."ProjectWanderfische_FishingData_seq" START 1;
CREATE SEQUENCE IF NOT EXISTS "projects"."ProjectWanderfische_FishCatch_seq" START 1;
CREATE SEQUENCE IF NOT EXISTS "projects"."ProjectWanderfische_Mail_seq" START 1;
CREATE SEQUENCE IF NOT EXISTS "projects"."ProjectWanderfische_Conversation_seq" START 1;
CREATE SEQUENCE IF NOT EXISTS "projects"."ProjectWanderfische_ChatMessage_seq" START 1;

-- ======================================================================
--Functions for ID Generation and Coordinate Transformation
-- ======================================================================
