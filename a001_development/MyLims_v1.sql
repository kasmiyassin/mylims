-- =======================
-- 0. Pre-Cleanup
-- =======================
-- scheme
DROP SCHEMA IF EXISTS "reference" CASCADE;
DROP SCHEMA IF EXISTS "lab" CASCADE;
DROP SCHEMA IF EXISTS "lims" CASCADE;
DROP SCHEMA IF EXISTS "audit" CASCADE;

-- libraries
DROP EXTENSION IF EXISTS "uuid-ossp";
DROP EXTENSION IF EXISTS pg_trgm;
DROP EXTENSION IF EXISTS postgres_fdw;
DROP EXTENSION IF EXISTS hstore;
DROP EXTENSION IF EXISTS tablefunc;
DROP EXTENSION IF EXISTS ltree;

-- =======================
-- 1. Extensions
-- =======================

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

CREATE SCHEMA IF NOT EXISTS "reference";
CREATE SCHEMA IF NOT EXISTS "lab";
CREATE SCHEMA IF NOT EXISTS "lims";
CREATE SCHEMA IF NOT EXISTS "audit";
CREATE SCHEMA IF NOT EXISTS "bioinformatics";
CREATE SCHEMA IF NOT EXISTS "projects";
-- pojects tables
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
    "institute" text,
    "city" text,
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
    "country_parent_taxon" text,
    "rank" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "reference"."ecosystem" (
    "ecosystem_id" text PRIMARY KEY,
    "ecosystem_abrv" text UNIQUE NOT NULL,
    "ecosystem_type" text,
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
    "rank" text,
    "de_name" text,
    "en_name" text,
    "max_length_mm" numeric,
    "max_age_years" numeric,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
    "path" ltree
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

CREATE TABLE IF NOT EXISTS "lims"."personal" (
    "person_id" text PRIMARY KEY,
    "full_name" text,
    "room" text,
    "telephone" text,
    "mail" text,
    "password_hash" text NOT NULL,
    "status_id" text NOT NULL,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

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
    "project_abrv" text,
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

CREATE TABLE IF NOT EXISTS "lims"."batch" (
    "batch_id" text PRIMARY KEY,
    "batch_name" text,
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

CREATE TABLE IF NOT EXISTS "lims"."batch_steps" (
    "step_id" text PRIMARY KEY,
    "batch_id" text NOT NULL,
    "step_number" integer NOT NULL,
    "step_name" text NOT NULL,
    "sop_id" text,
    "status_id" text DEFAULT 'Received' NOT NULL,
    "target_table_name" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
    UNIQUE ("batch_id", "step_number")
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
    "method" text, -- short description only to make easy to upload Peggy Table
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
    "experiment_id" text NOT NULL,
    "project_id" text NOT NULL,
    "experiment_date" date NOT NULL, -- This is the missing column
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
    PRIMARY KEY ("experiment_id", "project_id", "experiment_date")
);

CREATE TABLE IF NOT EXISTS "lab"."experiments_samples" (
    "experiment_id" text NOT NULL,
    "sample_id" text NOT NULL,
    "notes" text,
    PRIMARY KEY ("experiment_id", "sample_id")
);


CREATE TABLE IF NOT EXISTS "lab"."master_samples" (
    "sample_id" text PRIMARY KEY,
    "created_at" timestamptz DEFAULT CURRENT_TIMESTAMP,
    "created_by" TEXT,
    "status_id" TEXT,
    "batch_id" TEXT,
    "step_id" TEXT,
    "notes" text
);


CREATE TABLE IF NOT EXISTS "lab"."protocol_runs" (
    "protocol_run_id" serial PRIMARY KEY,
    "experiment_id" text,
    "protocol_text" text,
    "person_id" text,
    "protocol_run_details" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE "lab"."sampling" (
    "sampling_id" text NOT NULL, -- 99WesHH999
    "sampling_date" date NOT NULL,
    "experiment_id" text,
    "project_id" text,
    "cruise_id" text,
    "region_id" text,
    "ecosystem_id" text,
    "vessel_id" text,
    "customer_id" integer,
    "geom" geometry(Point, 4326),
    "fishing_start_geom" geometry(Point, 4326),
    "fishing_end_geom" geometry(Point, 4326),
    "location_name" text,
    "depth_m" numeric,
    "start_at" time,
    "end_at" time,
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

ALTER TABLE "lab"."sampling" ADD PRIMARY KEY ("sampling_id","sampling_date");

CREATE TABLE IF NOT EXISTS "lab"."fishing" (
    "fishing_id" text NOT NULL, -- 99WesHH999_f9999
    "sampling_id" text NOT NULL,
    "sampling_date" date NOT NULL,
    "taxon_id" text,
    "catch_kg" numeric,
    "catch_fish" numeric,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
	PRIMARY KEY ("fishing_id","sampling_date")
) PARTITION BY RANGE ("sampling_date");

CREATE TABLE "lab"."sampling_abiotic_data" (
    "sampling_id" text NOT NULL,
    "sampling_date" date NOT NULL,
    "weather" text,
    "temperature_atmospheric_c" numeric,
    "temperature_sampling_depth_c" numeric,
    "wind_speed" numeric,
    "wind_unit_id" text,
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
    "cloud_cover_percent" numeric,
    "rainfall_mm" numeric,
    "instrument_id" text,
    "visibility_m" numeric,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
    PRIMARY KEY ("sampling_id","sampling_date")
) PARTITION BY RANGE ("sampling_date");


CREATE TABLE IF NOT EXISTS "lab"."storage_log" (
    "log_id" serial PRIMARY KEY,
    "sample_id" text NOT NULL,
    "sample_sampling_date" date NOT NULL,
    "storage_id" text NOT NULL,
    "person_id" text,
    "move_date" timestamptz DEFAULT CURRENT_TIMESTAMP,
    "status_id" text,
    "storage_position" text,
    "notes" text
);

CREATE TABLE "lab"."parental_samples" (
    "sample_id" text NOT NULL, -- S99Pprj_999
    "external_name" text,
    "parent_sample_id" text,
    "root_sample_id" text,
    "sample_type_id" text NOT NULL,
    "project_id" text,
    "customer_id" integer,
    "sampling_id" text,
    "sampling_date" date,
    "storage_id" text,
    "storage_position" text,
    "sampler_person_id" text,
    "receiver_person_id" text,
    "reception_date" date,
    "transport" text,
    "conservation" text,
    "status_id" text DEFAULT 'Received' NOT NULL,
    "batch_id" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
	"experiment_id" text,
    "experiment_date" date,
	PRIMARY KEY("sample_id","sampling_date")
) PARTITION BY RANGE ("sampling_date");



CREATE TABLE IF NOT EXISTS "lab"."fish" (
    "sample_id" text NOT NULL, -- S99Pprj_999f1
    "sampling_id" text NOT NULL,
    "sampling_date" date NOT NULL,
    "species_id" text NOT NULL,
    "preservation_method" text,
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
    "batch_id" text,
    "step_id" text,
    "customer_id" integer,
    "status_id" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
	"experiment_id" text,
    "experiment_date" date NOT NULL,
    PRIMARY KEY ("sample_id","sampling_date")
) PARTITION BY RANGE ("sampling_date");

ALTER TABLE "lab"."fish" ADD CONSTRAINT chk_fish_sex_enum CHECK ("sex" IN ('Male', 'Female', 'Undetermined', NULL));

CREATE TABLE IF NOT EXISTS "lab"."tissue" (
    "sample_id" text NOT NULL, -- S99Pprj_999t1
    "parent_sample_id" text,
    "experiment_id" text,
    "experiment_date" date NOT NULL,
    "weight_g" numeric,
    "tissue_type" text,
    "preservation_method" text,
    "storage_id" text,
    "storage_position" text,
    "project_id" text,
    "batch_id" text,
    "step_id" text,
    "status_id" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
	PRIMARY KEY ("sample_id","experiment_date")
) PARTITION BY RANGE ("experiment_date");



CREATE TABLE IF NOT EXISTS "lab"."otoliths" (
    "otolith_id" text NOT NULL, --- S99Pprj_999o1
    "sample_id" text NOT NULL,
    "experiment_id" text NOT NULL,
    "experiment_date" date NOT NULL,
    "reader_person_id" text NOT NULL,
    "side" text NOT NULL,
    "age_reading_years" numeric,
    "confidence" numeric,
    "project_id" text,
    "batch_id" text,
    "step_id" text,
    "status_id" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
) PARTITION BY RANGE ("experiment_date");

ALTER TABLE "lab"."otoliths" ADD PRIMARY KEY ("otolith_id", "reader_person_id","side","experiment_date");



CREATE TABLE IF NOT EXISTS "lab"."dna" (
    "sample_id" text NOT NULL, -- S99Pprj_999d1
    "experiment_id" text,
    "experiment_date" date NOT NULL,
    "project_id" text,
    "volume_ul" numeric,
    "concentration_ng_ul" numeric,
    "a260_280" numeric,
    "a260_230" numeric,
    "extraction_method" text,
    "preservation_method" text,
    "extraction_date" date,
    "extraction_number" integer,
    "kit" text,
    "elution_volume_ul" numeric,
    "yield_qubit_ng_ul" numeric,
    "yield_nanodrop_ng_ul" numeric,
    "extraction_blank_id" text,
    "storage_id" text,
    "storage_position" text,
    "batch_id" text,
    "step_id" text,
    "status_id" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
	PRIMARY KEY ("sample_id","experiment_date")
) PARTITION BY RANGE ("experiment_date");



CREATE TABLE IF NOT EXISTS "lab"."rna" (
    "sample_id" text NOT NULL, -- S99Pprj_999r1
    "experiment_id" text,
    "experiment_date" date NOT NULL,
    "project_id" text,
    "volume_ul" numeric,
    "concentration_ng_ul" numeric,
    "a260_280" numeric,
    "a260_230" numeric,
    "extraction_method" text,
    "preservation_method" text,
    "extraction_date" date,
    "extraction_number" integer,
    "kit" text,
    "elution_volume_ul" numeric,
    "yield_qubit_ng_ul" numeric,
    "yield_nanodrop_ng_ul" numeric,
    "extraction_blank_id" text,
    "storage_id" text,
    "storage_position" text,
    "batch_id" text,
    "step_id" text,
    "status_id" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
	PRIMARY KEY ("sample_id","experiment_date")
) PARTITION BY RANGE ("experiment_date");


CREATE TABLE IF NOT EXISTS "lab"."sediments" (
    "sample_id" text NOT NULL, -- S99Pprj_999s1
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
    "batch_id" text,
    "step_id" text,
    "status_id" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
	PRIMARY KEY ("sample_id","experiment_date")
) PARTITION BY RANGE ("experiment_date");

CREATE TABLE IF NOT EXISTS "lab"."water" (
    "sample_id" text NOT NULL, -- S99Pprj_999w1
    "parent_sample_id" text,
    "experiment_id" text,
    "experiment_date" date NOT NULL,
    "project_id" text,
    "volume_ul" numeric,
    "filter" text,
    "filter_pore_size_um" numeric,
    "depth_m" numeric,
    "sampling_method" text,
    "conservation_buffer" text,
    "storage_id" text,
    "storage_position" text,
    "batch_id" text,
    "step_id" text,
    "status_id" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
	PRIMARY KEY ("sample_id", "experiment_date")
) PARTITION BY RANGE ("experiment_date");

CREATE TABLE IF NOT EXISTS "lab"."dissections" (
    "dissection_id" text NOT NULL, -- S99Pprj_999f1_d1
    "sample_id" text NOT NULL,
    "person_id" text NOT NULL,
    "dissection_date" date NOT NULL,
    "project_id" text,
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
    PRIMARY KEY ("dissection_id","dissection_date")
) PARTITION BY RANGE ("dissection_date");



CREATE TABLE IF NOT EXISTS "lab"."nanodrop" (
    "nanopore_id" text NOT NULL, -- S99Pprj_999t1_n9
    "sample_id" text NOT NULL, -- S99Pprj_999t1
    "experiment_id" text,
    "experiment_date" date,
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
    PRIMARY KEY ("nanopore_id","measurement_date")
) PARTITION BY RANGE ("measurement_date");

CREATE TABLE IF NOT EXISTS "lab"."qubit" (
    "qubit_id" text NOT NULL, -- S99Pprj_999t1_q9
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
    PRIMARY KEY ("qubit_id","measurement_date")
) PARTITION BY RANGE ("measurement_date");

CREATE TABLE IF NOT EXISTS "lab"."tapestation" (
    "tapestation_id" text NOT NULL, -- S99Pprj_999t1_t9
    "sample_id" text,
    "experiment_id" text,
    "experiment_date" date,
    "position" text,
    "measurement_date" date NOT NULL,
    "kit" text,
    "person_id" text,
    "notes" text,
    "storage_id" text,
    "storage_position" text,
    "status_id" text,
    "project_id" text,
    "attachment" bytea,
    "attachment_link" text,
    PRIMARY KEY ("tapestation_id","measurement_date")
) PARTITION BY RANGE ("measurement_date");


CREATE TABLE IF NOT EXISTS "lab"."pcr" (
    "pcr_id" text NOT NULL,  -- S99Pprj_999p1
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
    PRIMARY KEY ("pcr_id","pcr_date")
) PARTITION BY RANGE ("pcr_date");

CREATE TABLE IF NOT EXISTS "lab"."gelelectrophoresis" (
    "gelelectrophoresis_id" text NOT NULL, -- S99Pprj_999p1_gel9
    "sample_id" text NOT NULL,
    "experiment_id" text,
    "experiment_date" date,
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
    "status_id" text,
    "project_id" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
    PRIMARY KEY ("gelelectrophoresis_id","run_date")
) PARTITION BY RANGE ("run_date");

CREATE TABLE IF NOT EXISTS "lab"."qpcr" (
    "experiment_id" text,
    "experiment_date" date,
    "sample_id" text NOT NULL,
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
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
    PRIMARY KEY ("sample_id", "qpcr_date")
) PARTITION BY RANGE ("qpcr_date");

CREATE TABLE IF NOT EXISTS "lab"."library" (
    "library_id" text NOT NULL, --S99prj-999l4
    "experiment_id" text,
    "experiment_date" date,
    "sample_id" text NOT NULL,
    "library_name" text,
    "prep_date" date NOT NULL,
    "person_id" text,
    "library_prep_kit" text,
    "index_sequence" text,
    "barcode_seq" text,
    "read_length_bp" integer,
    "storage_id" text,
    "storage_position" text,
    "status_id" text,
    "project_id" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
    PRIMARY KEY ("library_id","sample_id","prep_date")
) PARTITION BY RANGE ("prep_date");

CREATE TABLE IF NOT EXISTS "lab"."sequencing_run" (
    "sequencing_run_id" text NOT NULL,  --RS25-999
    "experiment_id" text,
    "experiment_date" date,
    "library_id" text,
    "prep_date" date,
    "sample_id" text,
    "sequencing_date" date NOT NULL,
    "person_id" text,
    "sequencer" text,
    "flow_cell_id" text,
    "library_prep_kit" text,
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
    PRIMARY KEY ("sequencing_run_id", "sequencing_date")
) PARTITION BY RANGE ("sequencing_date");

CREATE TABLE IF NOT EXISTS "lab"."Seq_dataset" (
    "data_seq_id" text NOT NULL,  --S99prj-999RS4
    "library_id" text,
    "sample_id" text,
    "sequencing_date" date NOT NULL,
    "sequencing_run_id" text,
    "sequencer" text,
    "index_sequence" text,
    "barcode" text,
    "read_length_bp" integer,
    "total_reads" bigint,
    "raw_data_path" text,
    "bank_accession_number" text,
    "status_id" text,
    "storage_id" text,
    "storage_position" text,
    "project_id" text,
    "attachment" bytea,
    "attachment_link" text,
    "notes" text,
    PRIMARY KEY ("data_seq_id", "sequencing_date")
) PARTITION BY RANGE ("sequencing_date");

CREATE TABLE IF NOT EXISTS "lab"."datasets" (
    "dataset_id" text NOT NULL,
    "sample_id" text,
    "source_type" text,
    "ecosystem_id" text,
    "experiment_id" text,
    "experiment_date" date NOT NULL,
    "region_id" text,
    "customer_id" integer,
    "stored_location_id" text,
    "reception_date" date NOT NULL,
    "status_id" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
    "storage_path" text,
    PRIMARY KEY ("dataset_id", "reception_date")
) PARTITION BY RANGE ("reception_date");

-- ======================================================================
-- 7. Bioinformatics Schema Tables
-- ======================================================================


CREATE TABLE IF NOT EXISTS "bioinformatics"."analysis_pipelines" (
    "pipeline_id" text PRIMARY KEY,
    "pipeline_name" text NOT NULL,
    "version" text NOT NULL,
    "repository_link" text,
	"experiment_id" text,
    "experiment_date" date,
    "status_id" text,
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
    "status_id" text,
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
    "status_id" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);



-- ======================================================================
-- 7. Schema Creation for 'projects'
-- New Tables for Wanderfische Project
-- ======================================================================

-- This table is designed to consolidate various fishing data inputs from different agencies.
-- It includes fields for standardized data, a JSONB column for original raw data,
-- and geographical coordinates with projection handling.
CREATE TABLE IF NOT EXISTS "projects"."ProjectWanderfische_FishingData" (
    "fishing_record_id" serial NOT NULL, 
    "agency_id" text NOT NULL, 
    "project_id" text NOT NULL, 
    "agency_record_id" text,    
    "record_date" date NOT NULL, 
    "record_time" time,
    "fishing_year" integer,

    -- Temporal details for fishing operation
    "fishing_start_time" time,
    "fishing_end_time" time,

    -- Location Information 
    "original_easting" numeric,
    "original_northing" numeric,
    "original_latitude" numeric,
    "original_longitude" numeric,
    "original_srid" integer, 
    "geom_4326" geometry(Point, 4326), 
    "location_description" text, 
    "water_body_name" text, 
    "water_body_code" text, 
    "water_body_type" text, 
    "catchment_area" text, 
    "district" text,  
    "water_depth_m" numeric, 

    -- Fishing Event Details
    "fishing_method" text, 
    "gear_type" text, 
    "fishing_length_m" numeric, 
    "fishing_area_sqm" numeric, 
    "average_width_m" numeric, 
    "total_catch_quantity_kg" numeric,
    "total_catch_quantity_fish" integer,

    -- Environmental Parameters (from sampling data, if available)
    "temperature_c" numeric,
    "salinity" numeric,
    "salinity_unit_id" text, 
    "oxygen" numeric,
    "oxygen_unit_id" text,  
    "ph" numeric,
    "turbidity_ntu" numeric,
    "weather_conditions" text,
    "wind_speed" numeric,
    "wind_unit_id" text,  

    "notes" text,
    "attachment" bytea,
    "attachment_link" text,

    "original_data_jsonb" jsonb, 

    "created_at" timestamptz DEFAULT CURRENT_TIMESTAMP,
    "created_by" text, 
    "last_modified_at" timestamptz DEFAULT CURRENT_TIMESTAMP,
    "last_modified_by" text, 

    PRIMARY KEY ("fishing_record_id", "record_date")
) PARTITION BY RANGE ("record_date");

-- Table for detailed fish catch information per fishing record
-- This allows for multiple species to be recorded per fishing event.
CREATE TABLE IF NOT EXISTS "projects"."ProjectWanderfische_FishCatch" (
    "fish_catch_id" serial PRIMARY KEY,
    "fishing_record_id" text NOT NULL, 
    "fishing_record_date" date NOT NULL, 
    "taxon_id" text,  
    "scientific_name_raw" text,  
    "german_name_raw" text,  
    "total_count" integer,
    "juvenile_count" integer,
    "praeadult_count" integer,
    "adult_count" integer,
    "individual_length_mm" numeric,
    "individual_weight_g" numeric,  
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
    "mail_id" serial PRIMARY KEY,
    "fishing_record_id" text, 
    "fishing_record_date" date,
    "sender_person_id" text, 
    "recipient_contact_id" text, 
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
    "conversation_id" serial PRIMARY KEY,
    "fishing_record_id" text,    
    "fishing_record_date" date,  
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
    "message_id" serial PRIMARY KEY,
    "conversation_id" text NOT NULL,  
    "sender_person_id" text,  
    "sender_contact_id" text,  
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




-- ======================================================================
-- 8. Sequences for ID Generation
-- ======================================================================
-- Note: It is safe to run these `CREATE SEQUENCE` statements multiple times.
-- They will only create a new sequence if one does not already exist.

CREATE SEQUENCE IF NOT EXISTS "lims"."publication_serial_seq" START 1;
CREATE SEQUENCE IF NOT EXISTS "lab"."fishing_serial_seq" START 1;
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
-- 9. Functions: ID Generation
-- ======================================================================

-- Function to generate IDs for `lims.publications`
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

    SELECT COALESCE(MAX(SUBSTRING("publication_id" FROM LENGTH(id_prefix) + 1)::INTEGER), 0)
    INTO next_serial
    FROM "lims"."publications"
    WHERE "publication_id" ILIKE id_prefix || '%';

    NEW.publication_id := id_prefix || LPAD((next_serial + 1)::TEXT, 3, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate IDs for `lims.sop`
CREATE OR REPLACE FUNCTION "lims".generate_sop_id()
RETURNS TRIGGER AS $$
BEGIN
    NEW.sop_id := NEW.sop_id_origin || '_v' || REPLACE(NEW.version, '.', '');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate IDs for `lims.batch_steps`
CREATE OR REPLACE FUNCTION "lims".generate_batch_step_id()
RETURNS TRIGGER AS $$
BEGIN
    NEW.step_id := NEW.batch_id || '_' || NEW.step_number::TEXT || '_' || REPLACE(NEW.step_name, ' ', '_');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate IDs for `lab.sampling`
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

    SELECT COALESCE(MAX(SUBSTRING("sampling_id" FROM LENGTH(id_prefix) + 1)::INTEGER), 0)
    INTO next_serial
    FROM "lab"."sampling"
    WHERE "sampling_id" ILIKE id_prefix || '%';

    NEW.sampling_id := id_prefix || LPAD((next_serial + 1)::TEXT, 3, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate IDs for `lab.fishing`
CREATE OR REPLACE FUNCTION "lab".generate_fishing_id()
RETURNS TRIGGER AS $$
DECLARE
    next_serial integer;
    id_prefix text;
BEGIN
    -- Prefix with the parent sampling_id
    id_prefix := NEW.sampling_id || '_f';

    SELECT COALESCE(MAX(SUBSTRING("fishing_id" FROM LENGTH(id_prefix) + 1)::INTEGER), 0)
    INTO next_serial
    FROM "lab"."fishing"
    WHERE "fishing_id" ILIKE id_prefix || '%';

    NEW.fishing_id := id_prefix || LPAD((next_serial + 1)::TEXT, 3, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate IDs for `lab.parental_samples` (Parental Samples)
-- Format: [SampleTypeAbbr][Year][ProjectAbbr]-[Serial] or [SampleTypeAbbr][Year][CustomerAbbr]-[Serial]
CREATE OR REPLACE FUNCTION "lab".generate_sample_id()
RETURNS TRIGGER AS $$
DECLARE
    sample_type_abrv text;
    project_or_customer_abrv text;
    current_year text;
    id_prefix text;
    next_serial integer;
BEGIN
    -- Get the sample type abbreviation
    SELECT sample_type_abrv INTO sample_type_abrv
    FROM "reference"."samples_type"
    WHERE sample_type_id = NEW.sample_type_id;

    IF sample_type_abrv IS NULL THEN
        RAISE EXCEPTION 'Sample type ID "%" not found in "reference"."samples_type".', NEW.sample_type_id;
    END IF;

    -- Get the project abbreviation if available, otherwise use customer abbreviation
    IF NEW.project_id IS NOT NULL THEN
        SELECT project_abrv INTO project_or_customer_abrv
        FROM "lims"."projects"
        WHERE project_id = NEW.project_id;
    ELSE
        SELECT customer_abrv INTO project_or_customer_abrv
        FROM "lims"."customers"
        WHERE customer_id = NEW.customer_id;
    END IF;

    IF project_or_customer_abrv IS NULL THEN
        RAISE EXCEPTION 'Cannot generate sample_id: Missing project_id and customer_id, or invalid IDs.';
    END IF;

    current_year := TO_CHAR(COALESCE(NEW.sampling_date, NEW.reception_date, CURRENT_DATE), 'YY');

    id_prefix := sample_type_abrv || current_year || project_or_customer_abrv;

    -- Find the next available serial number for the given prefix
    SELECT COALESCE(MAX(SUBSTRING("sample_id" FROM LENGTH(id_prefix) + 2)::INTEGER), 0)
    INTO next_serial
    FROM "lab"."parental_samples"
    WHERE "sample_id" ILIKE id_prefix || '-%';

    NEW.sample_id := id_prefix || '-' || LPAD((next_serial + 1)::TEXT, 3, '0');

    -- Insert into master_samples table to track all sample IDs
    INSERT INTO "lab"."master_samples" ("sample_id") VALUES (NEW.sample_id);

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate IDs for `lab.dissections`
-- Format: [sample_id]_d_[serial]
CREATE OR REPLACE FUNCTION "lab".generate_dissection_id()
RETURNS TRIGGER AS $$
DECLARE
    next_serial integer;
    id_prefix text;
BEGIN
    id_prefix := NEW.sample_id || '_d_';

    SELECT COALESCE(MAX(SUBSTRING("dissection_id" FROM LENGTH(id_prefix) + 1)::INTEGER), 0)
    INTO next_serial
    FROM "lab"."dissections"
    WHERE "dissection_id" ILIKE id_prefix || '%';

    NEW.dissection_id := id_prefix || (next_serial + 1)::TEXT;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate IDs for `lab.nanodrop`
-- Format: [sample_id]_n_[serial]
CREATE OR REPLACE FUNCTION "lab".generate_nanodrop_id()
RETURNS TRIGGER AS $$
DECLARE
    next_serial integer;
    id_prefix text;
BEGIN
    id_prefix := NEW.sample_id || '_n_';

    SELECT COALESCE(MAX(SUBSTRING("nanodrop_id" FROM LENGTH(id_prefix) + 1)::INTEGER), 0)
    INTO next_serial
    FROM "lab"."nanodrop"
    WHERE "nanodrop_id" ILIKE id_prefix || '%';

    NEW.nanodrop_id := id_prefix || (next_serial + 1)::TEXT;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate IDs for `lab.qubit`
-- Format: [sample_id]_q_[serial]
CREATE OR REPLACE FUNCTION "lab".generate_qubit_id()
RETURNS TRIGGER AS $$
DECLARE
    next_serial integer;
    id_prefix text;
BEGIN
    id_prefix := NEW.sample_id || '_q_';

    SELECT COALESCE(MAX(SUBSTRING("qubit_id" FROM LENGTH(id_prefix) + 1)::INTEGER), 0)
    INTO next_serial
    FROM "lab"."qubit"
    WHERE "qubit_id" ILIKE id_prefix || '%';

    NEW.qubit_id := id_prefix || (next_serial + 1)::TEXT;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate IDs for `lab.tapestation`
-- Format: [sample_id]_t_[serial]
CREATE OR REPLACE FUNCTION "lab".generate_tapestation_id()
RETURNS TRIGGER AS $$
DECLARE
    next_serial integer;
    id_prefix text;
BEGIN
    id_prefix := NEW.sample_id || '_t_';

    SELECT COALESCE(MAX(SUBSTRING("tapestation_id" FROM LENGTH(id_prefix) + 1)::INTEGER), 0)
    INTO next_serial
    FROM "lab"."tapestation"
    WHERE "tapestation_id" ILIKE id_prefix || '%';

    NEW.tapestation_id := id_prefix || (next_serial + 1)::TEXT;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate IDs for `lab.pcr`
CREATE OR REPLACE FUNCTION "lab".generate_pcr_id()
RETURNS TRIGGER AS $$
DECLARE
    next_serial integer;
    id_prefix text;
BEGIN
    id_prefix := 'PCR_' || NEW.sample_id || '_';

    SELECT COALESCE(MAX(SUBSTRING("pcr_id" FROM LENGTH(id_prefix) + 1)::INTEGER), 0)
    INTO next_serial
    FROM "lab"."pcr"
    WHERE "pcr_id" ILIKE id_prefix || '%';

    NEW.pcr_id := id_prefix || LPAD((next_serial + 1)::TEXT, 3, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate IDs for `lab.gelelectrophoresis`
-- Format: [sample_id]_g_[serial]
CREATE OR REPLACE FUNCTION "lab".generate_gelelectrophoresis_id()
RETURNS TRIGGER AS $$
DECLARE
    next_serial integer;
    id_prefix text;
BEGIN
    id_prefix := NEW.sample_id || '_g_';

    SELECT COALESCE(MAX(SUBSTRING("gelelectrophoresis_id" FROM LENGTH(id_prefix) + 1)::INTEGER), 0)
    INTO next_serial
    FROM "lab"."gelelectrophoresis"
    WHERE "gelelectrophoresis_id" ILIKE id_prefix || '%';

    NEW.gelelectrophoresis_id := id_prefix || (next_serial + 1)::TEXT;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate IDs for `lab.qpcr`
-- Format: [sample_id]_qp_[serial]
CREATE OR REPLACE FUNCTION "lab".generate_qpcr_id()
RETURNS TRIGGER AS $$
DECLARE
    next_serial integer;
    id_prefix text;
BEGIN
    id_prefix := NEW.sample_id || '_qp_';

    SELECT COALESCE(MAX(SUBSTRING("qpcr_id" FROM LENGTH(id_prefix) + 1)::INTEGER), 0)
    INTO next_serial
    FROM "lab"."qpcr"
    WHERE "qpcr_id" ILIKE id_prefix || '%';

    NEW.qpcr_id := id_prefix || (next_serial + 1)::TEXT;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate IDs for `lab.library`
-- Format: [experimentid]_lib_[serial]
CREATE OR REPLACE FUNCTION "lab".generate_library_id()
RETURNS TRIGGER AS $$
DECLARE
    next_serial integer;
    id_prefix text;
BEGIN
    id_prefix := NEW.experiment_id || '_lib_';

    SELECT COALESCE(MAX(SUBSTRING("library_id" FROM LENGTH(id_prefix) + 1)::INTEGER), 0)
    INTO next_serial
    FROM "lab"."library"
    WHERE "library_id" ILIKE id_prefix || '%';

    NEW.library_id := id_prefix || (next_serial + 1)::TEXT;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate IDs for `lab.sequencing`
-- Format: RS[YY]-[Serial]
CREATE OR REPLACE FUNCTION "lab".generate_sequencing_id()
RETURNS TRIGGER AS $$
DECLARE
    current_year text;
    next_serial integer;
    id_prefix text;
BEGIN
    current_year := TO_CHAR(COALESCE(NEW.sequencing_date, CURRENT_DATE), 'YY');
    id_prefix := 'RS' || current_year;

    SELECT COALESCE(MAX(SUBSTRING("sequencing_id" FROM LENGTH(id_prefix) + 2)::INTEGER), 0)
    INTO next_serial
    FROM "lab"."sequencing"
    WHERE "sequencing_id" ILIKE id_prefix || '-%';

    NEW.sequencing_id := id_prefix || '-' || LPAD((next_serial + 1)::TEXT, 3, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate IDs for `lab.datasets`
-- Format: DS[Year][ProjectAbbr]-[Serial]
CREATE OR REPLACE FUNCTION "lab".generate_dataset_id()
RETURNS TRIGGER AS $$
DECLARE
    current_year text;
    project_abrv text;
    id_prefix text;
    next_serial integer;
BEGIN
    current_year := TO_CHAR(COALESCE(NEW.reception_date, CURRENT_DATE), 'YY');

    -- Get project abbreviation from the projects table
    SELECT project_abrv INTO project_abrv
    FROM "lims"."projects"
    WHERE project_id = NEW.project_id;

    IF project_abrv IS NULL THEN
        RAISE EXCEPTION 'Project ID "%" not found in "lims"."projects" table for dataset ID generation.', NEW.project_id;
    END IF;

    id_prefix := 'DS' || current_year || project_abrv;

    SELECT COALESCE(MAX(SUBSTRING("dataset_id" FROM LENGTH(id_prefix) + 2)::INTEGER), 0)
    INTO next_serial
    FROM "lab"."datasets"
    WHERE "dataset_id" ILIKE id_prefix || '-%';

    NEW.dataset_id := id_prefix || '-' || LPAD((next_serial + 1)::TEXT, 3, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate IDs for `bioinformatics.analysis_pipelines`
CREATE OR REPLACE FUNCTION "bioinformatics".generate_pipeline_id()
RETURNS TRIGGER AS $$
DECLARE
    current_year text;
    next_serial integer;
    id_prefix text;
BEGIN
    current_year := TO_CHAR(CURRENT_DATE, 'YY');
    id_prefix := current_year;

    SELECT COALESCE(MAX(SUBSTRING("pipeline_id" FROM LENGTH(id_prefix) + 1)::INTEGER), 0)
    INTO next_serial
    FROM "bioinformatics"."analysis_pipelines"
    WHERE "pipeline_id" ILIKE id_prefix || '%';

    NEW.pipeline_id := id_prefix || LPAD((next_serial + 1)::TEXT, 3, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate IDs for `bioinformatics.analysis_runs`
CREATE OR REPLACE FUNCTION "bioinformatics".generate_analysis_run_id()
RETURNS TRIGGER AS $$
DECLARE
    current_year text;
    next_serial integer;
    id_prefix text;
BEGIN
    current_year := TO_CHAR(COALESCE(NEW.run_date, CURRENT_TIMESTAMP), 'YY');
    id_prefix := current_year;

    SELECT COALESCE(MAX(SUBSTRING("run_id" FROM LENGTH(id_prefix) + 1)::INTEGER), 0)
    INTO next_serial
    FROM "bioinformatics"."analysis_runs"
    WHERE "run_id" ILIKE id_prefix || '%';

    NEW.run_id := id_prefix || LPAD((next_serial + 1)::TEXT, 3, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate IDs for `bioinformatics.edna_assignments`
CREATE OR REPLACE FUNCTION "bioinformatics".generate_edna_assignment_id()
RETURNS TRIGGER AS $$
DECLARE
    current_year text;
    next_serial integer;
    id_prefix text;
BEGIN
    current_year := TO_CHAR(CURRENT_DATE, 'YY');
    id_prefix := current_year;

    SELECT COALESCE(MAX(SUBSTRING("assignment_id" FROM LENGTH(id_prefix) + 1)::INTEGER), 0)
    INTO next_serial
    FROM "bioinformatics"."edna_assignments"
    WHERE "assignment_id" ILIKE id_prefix || '%';

    NEW.assignment_id := id_prefix || LPAD((next_serial + 1)::TEXT, 3, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate IDs for `lab.protocol_runs`
-- Format: [experimentid]_p_[serial]
CREATE OR REPLACE FUNCTION "lab".generate_protocol_run_id()
RETURNS TRIGGER AS $$
DECLARE
    next_serial integer;
    id_prefix text;
BEGIN
    id_prefix := NEW.experiment_id || '_p_';

    SELECT COALESCE(MAX(SUBSTRING("protocol_run_id" FROM LENGTH(id_prefix) + 1)::INTEGER), 0)
    INTO next_serial
    FROM "lab"."protocol_runs"
    WHERE "protocol_run_id" ILIKE id_prefix || '%';

    NEW.protocol_run_id := id_prefix || (next_serial + 1)::TEXT;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate IDs for ProjectWanderfische_FishingData
CREATE OR REPLACE FUNCTION "projects".generate_ProjectWanderfische_FishingData_id()
RETURNS TRIGGER AS $$
DECLARE
    current_year text;
    next_serial integer;
    id_prefix text;
BEGIN
    current_year := TO_CHAR(COALESCE(NEW.record_date, CURRENT_DATE), 'YY');
    id_prefix := 'WF' || current_year || 'F'; -- WanderFische + Year + Fishing

    SELECT COALESCE(MAX(SUBSTRING("fishing_record_id" FROM LENGTH(id_prefix) + 1)::INTEGER), 0)
    INTO next_serial
    FROM "projects"."ProjectWanderfische_FishingData"
    WHERE "fishing_record_id" ILIKE id_prefix || '%';

    NEW.fishing_record_id := id_prefix || LPAD((next_serial + 1)::TEXT, 3, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate IDs for ProjectWanderfische_FishCatch
CREATE OR REPLACE FUNCTION "projects".generate_ProjectWanderfische_FishCatch_id()
RETURNS TRIGGER AS $$
DECLARE
    next_serial integer;
    id_prefix text;
BEGIN
    -- Prefix with the parent fishing_record_id for better traceability
    id_prefix := NEW.fishing_record_id || '_C'; -- Catch

    SELECT COALESCE(MAX(SUBSTRING("fish_catch_id" FROM LENGTH(id_prefix) + 1)::INTEGER), 0)
    INTO next_serial
    FROM "projects"."ProjectWanderfische_FishCatch"
    WHERE "fish_catch_id" ILIKE id_prefix || '%';

    NEW.fish_catch_id := id_prefix || LPAD((next_serial + 1)::TEXT, 3, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate IDs for ProjectWanderfische_Mail
CREATE OR REPLACE FUNCTION "projects".generate_ProjectWanderfische_Mail_id()
RETURNS TRIGGER AS $$
DECLARE
    current_year text;
    next_serial integer;
    id_prefix text;
BEGIN
    current_year := TO_CHAR(COALESCE(NEW.sent_at, CURRENT_TIMESTAMP), 'YY');
    id_prefix := 'WF' || current_year || 'M'; -- WanderFische + Year + Mail

    SELECT COALESCE(MAX(SUBSTRING("mail_id" FROM LENGTH(id_prefix) + 1)::INTEGER), 0)
    INTO next_serial
    FROM "projects"."ProjectWanderfische_Mail"
    WHERE "mail_id" ILIKE id_prefix || '%';

    NEW.mail_id := id_prefix || LPAD((next_serial + 1)::TEXT, 3, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate IDs for ProjectWanderfische_Conversation
CREATE OR REPLACE FUNCTION "projects".generate_ProjectWanderfische_Conversation_id()
RETURNS TRIGGER AS $$
DECLARE
    current_year text;
    next_serial integer;
    id_prefix text;
BEGIN
    current_year := TO_CHAR(COALESCE(NEW.started_at, CURRENT_TIMESTAMP), 'YY');
    id_prefix := 'WF' || current_year || 'CONV'; -- WanderFische + Year + Conversation

    SELECT COALESCE(MAX(SUBSTRING("conversation_id" FROM LENGTH(id_prefix) + 1)::INTEGER), 0)
    INTO next_serial
    FROM "projects"."ProjectWanderfische_Conversation"
    WHERE "conversation_id" ILIKE id_prefix || '%';

    NEW.conversation_id := id_prefix || LPAD((next_serial + 1)::TEXT, 3, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate IDs for ProjectWanderfische_ChatMessage
CREATE OR REPLACE FUNCTION "projects".generate_ProjectWanderfische_ChatMessage_id()
RETURNS TRIGGER AS $$
DECLARE
    next_serial integer;
    id_prefix text;
BEGIN
    -- Prefix with the parent conversation_id
    id_prefix := NEW.conversation_id || '_MSG'; -- Message

    SELECT COALESCE(MAX(SUBSTRING("message_id" FROM LENGTH(id_prefix) + 1)::INTEGER), 0)
    INTO next_serial
    FROM "projects"."ProjectWanderfische_ChatMessage"
    WHERE "message_id" ILIKE id_prefix || '%';

    NEW.message_id := id_prefix || LPAD((next_serial + 1)::TEXT, 3, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- ======================================================================
-- 10.Functions: Partitioning
-- ======================================================================

-- Function to create partitions for `lab.dna`
CREATE OR REPLACE FUNCTION "lab".create_dna_partition_if_not_exists()
RETURNS TRIGGER AS $$
DECLARE
    partition_date date;
    partition_name text;
    start_date date;
    end_date date;
BEGIN
    partition_date := NEW.experiment_date;
    IF partition_date IS NULL THEN
        RAISE EXCEPTION 'Cannot partition on NULL experiment_date for lab.dna. Please provide an experiment_date.';
    END IF;

    start_date := DATE_TRUNC('year', partition_date);
    end_date := DATE_TRUNC('year', partition_date) + INTERVAL '1 year';
    partition_name := 'dna_y' || TO_CHAR(start_date, 'YYYY');

    EXECUTE 'CREATE TABLE IF NOT EXISTS "lab".' || quote_ident(partition_name) || ' PARTITION OF "lab"."dna"
             FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to create partitions for `lab.fish`
CREATE OR REPLACE FUNCTION "lab".create_fish_partition_if_not_exists()
RETURNS TRIGGER AS $$
DECLARE
    partition_date date;
    partition_name text;
    start_date date;
    end_date date;
BEGIN
    partition_date := NEW.sampling_date;
    IF partition_date IS NULL THEN
        RAISE EXCEPTION 'Cannot partition on NULL sampling_date for lab.fish. Please provide a sampling_date.';
    END IF;

    start_date := DATE_TRUNC('year', partition_date);
    end_date := DATE_TRUNC('year', partition_date) + INTERVAL '1 year';
    partition_name := 'fish_y' || TO_CHAR(start_date, 'YYYY');

    EXECUTE 'CREATE TABLE IF NOT EXISTS "lab".' || quote_ident(partition_name) || ' PARTITION OF "lab"."fish"
             FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to create partitions for `lab.fishing`
CREATE OR REPLACE FUNCTION "lab".create_fishing_partition_if_not_exists()
RETURNS TRIGGER AS $$
DECLARE
    partition_date date;
    partition_name text;
    start_date date;
    end_date date;
BEGIN
    partition_date := NEW.sampling_date;
    IF partition_date IS NULL THEN
        RAISE EXCEPTION 'Cannot partition on NULL sampling_date for lab.fishing. Please provide a sampling_date.';
    END IF;

    start_date := DATE_TRUNC('year', partition_date);
    end_date := DATE_TRUNC('year', partition_date) + INTERVAL '1 year';
    partition_name := 'fishing_y' || TO_CHAR(start_date, 'YYYY');

    EXECUTE 'CREATE TABLE IF NOT EXISTS "lab".' || quote_ident(partition_name) || ' PARTITION OF "lab"."fishing"
             FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to create partitions for `lab.otoliths`
CREATE OR REPLACE FUNCTION "lab".create_otoliths_partition_if_not_exists()
RETURNS TRIGGER AS $$
DECLARE
    partition_date date;
    partition_name text;
    start_date date;
    end_date date;
BEGIN
    partition_date := NEW.experiment_date;
    IF partition_date IS NULL THEN
        RAISE EXCEPTION 'Cannot partition on NULL experiment_date for lab.otoliths. Please provide an experiment_date.';
    END IF;

    start_date := DATE_TRUNC('year', partition_date);
    end_date := DATE_TRUNC('year', partition_date) + INTERVAL '1 year';
    partition_name := 'otoliths_y' || TO_CHAR(start_date, 'YYYY');

    EXECUTE 'CREATE TABLE IF NOT EXISTS "lab".' || quote_ident(partition_name) || ' PARTITION OF "lab"."otoliths"
             FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to create partitions for `lab.rna`
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

-- Function to create partitions for `lab.sediments`
CREATE OR REPLACE FUNCTION "lab".create_sediments_partition_if_not_exists()
RETURNS TRIGGER AS $$
DECLARE
    partition_date date;
    partition_name text;
    start_date date;
    end_date date;
BEGIN
    partition_date := NEW.experiment_date;
    IF partition_date IS NULL THEN
        RAISE EXCEPTION 'Cannot partition on NULL experiment_date for lab.sediments. Please provide an experiment_date.';
    END IF;

    start_date := DATE_TRUNC('year', partition_date);
    end_date := DATE_TRUNC('year', partition_date) + INTERVAL '1 year';
    partition_name := 'sediments_y' || TO_CHAR(start_date, 'YYYY');

    EXECUTE 'CREATE TABLE IF NOT EXISTS "lab".' || quote_ident(partition_name) || ' PARTITION OF "lab"."sediments"
             FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to create partitions for `lab.tissue`
CREATE OR REPLACE FUNCTION "lab".create_tissue_partition_if_not_exists()
RETURNS TRIGGER AS $$
DECLARE
    partition_date date;
    partition_name text;
    start_date date;
    end_date date;
BEGIN
    partition_date := NEW.experiment_date;
    IF partition_date IS NULL THEN
        RAISE EXCEPTION 'Cannot partition on NULL experiment_date for lab.tissue. Please provide an experiment_date.';
    END IF;

    start_date := DATE_TRUNC('year', partition_date);
    end_date := DATE_TRUNC('year', partition_date) + INTERVAL '1 year';
    partition_name := 'tissue_y' || TO_CHAR(start_date, 'YYYY');

    EXECUTE 'CREATE TABLE IF NOT EXISTS "lab".' || quote_ident(partition_name) || ' PARTITION OF "lab"."tissue"
             FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to create partitions for `lab.water`
CREATE OR REPLACE FUNCTION "lab".create_water_partition_if_not_exists()
RETURNS TRIGGER AS $$
DECLARE
    partition_date date;
    partition_name text;
    start_date date;
    end_date date;
BEGIN
    partition_date := NEW.experiment_date;
    IF partition_date IS NULL THEN
        RAISE EXCEPTION 'Cannot partition on NULL experiment_date for lab.water. Please provide an experiment_date.';
    END IF;

    start_date := DATE_TRUNC('year', partition_date);
    end_date := DATE_TRUNC('year', partition_date) + INTERVAL '1 year';
    partition_name := 'water_y' || TO_CHAR(start_date, 'YYYY');

    EXECUTE 'CREATE TABLE IF NOT EXISTS "lab".' || quote_ident(partition_name) || ' PARTITION OF "lab"."water"
             FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to create partitions for `lab.parental_samples`
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
    partition_name := 'parentalsamples_y' || TO_CHAR(start_date, 'YYYY');

    EXECUTE 'CREATE TABLE IF NOT EXISTS "lab".' || quote_ident(partition_name) || ' PARTITION OF "lab"."parental_samples"
             FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to create partitions for `lab.experiments`
CREATE OR REPLACE FUNCTION "lab".create_experiments_partition_if_not_exists()
RETURNS TRIGGER AS $$
DECLARE
    partition_date date;
    partition_name text;
    start_date date;
    end_date date;
BEGIN
    partition_date := NEW.experiment_date;
    IF partition_date IS NULL THEN
        RAISE EXCEPTION 'Cannot partition on NULL experiment_date for lab.experiments. Please provide an experiment_date.';
    END IF;

    start_date := DATE_TRUNC('year', partition_date);
    end_date := DATE_TRUNC('year', partition_date) + INTERVAL '1 year';
    partition_name := 'experiments_y' || TO_CHAR(start_date, 'YYYY');

    EXECUTE 'CREATE TABLE IF NOT EXISTS "lab".' || quote_ident(partition_name) || ' PARTITION OF "lab"."experiments"
             FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to create partitions for `lab.dissections`
CREATE OR REPLACE FUNCTION "lab".create_dissections_partition_if_not_exists()
RETURNS TRIGGER AS $$
DECLARE
    partition_date date;
    partition_name text;
    start_date date;
    end_date date;
BEGIN
    partition_date := NEW.dissection_date;
    IF partition_date IS NULL THEN
        RAISE EXCEPTION 'Cannot partition on NULL dissection_date for lab.dissections. Please provide a dissection_date.';
    END IF;

    start_date := DATE_TRUNC('year', partition_date);
    end_date := DATE_TRUNC('year', partition_date) + INTERVAL '1 year';
    partition_name := 'dissections_y' || TO_CHAR(start_date, 'YYYY');

    EXECUTE 'CREATE TABLE IF NOT EXISTS "lab".' || quote_ident(partition_name) || ' PARTITION OF "lab"."dissections"
             FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to create partitions for `lab.extraction`
CREATE OR REPLACE FUNCTION "lab".create_extraction_partition_if_not_exists()
RETURNS TRIGGER AS $$
DECLARE
    partition_date date;
    partition_name text;
    start_date date;
    end_date date;
BEGIN
    partition_date := NEW.extraction_date;
    IF partition_date IS NULL THEN
        RAISE EXCEPTION 'Cannot partition on NULL extraction_date for lab.extraction. Please provide an extraction_date.';
    END IF;

    start_date := DATE_TRUNC('year', partition_date);
    end_date := DATE_TRUNC('year', partition_date) + INTERVAL '1 year';
    partition_name := 'extraction_y' || TO_CHAR(start_date, 'YYYY');

    EXECUTE 'CREATE TABLE IF NOT EXISTS "lab".' || quote_ident(partition_name) || ' PARTITION OF "lab"."extraction"
             FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- Function to create partitions for `lab.nanodrop`
CREATE OR REPLACE FUNCTION "lab".create_nanodrop_partition_if_not_exists()
RETURNS TRIGGER AS $$
DECLARE
    partition_date date;
    partition_name text;
    start_date date;
    end_date date;
BEGIN
    partition_date := NEW.measurement_date;
    IF partition_date IS NULL THEN
        RAISE EXCEPTION 'Cannot partition on NULL measurement_date for lab.nanodrop. Please provide a measurement_date.';
    END IF;

    start_date := DATE_TRUNC('year', partition_date);
    end_date := DATE_TRUNC('year', partition_date) + INTERVAL '1 year';
    partition_name := 'nanodrop_y' || TO_CHAR(start_date, 'YYYY');

    EXECUTE 'CREATE TABLE IF NOT EXISTS "lab".' || quote_ident(partition_name) || ' PARTITION OF "lab"."nanodrop"
             FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- Function to create partitions for `lab.qubit`
CREATE OR REPLACE FUNCTION "lab".create_qubit_partition_if_not_exists()
RETURNS TRIGGER AS $$
DECLARE
    partition_date date;
    partition_name text;
    start_date date;
    end_date date;
BEGIN
    partition_date := NEW.measurement_date;
    IF partition_date IS NULL THEN
        RAISE EXCEPTION 'Cannot partition on NULL measurement_date for lab.qubit. Please provide a measurement_date.';
    END IF;

    start_date := DATE_TRUNC('year', partition_date);
    end_date := DATE_TRUNC('year', partition_date) + INTERVAL '1 year';
    partition_name := 'qubit_y' || TO_CHAR(start_date, 'YYYY');

    EXECUTE 'CREATE TABLE IF NOT EXISTS "lab".' || quote_ident(partition_name) || ' PARTITION OF "lab"."qubit"
             FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- Function to create partitions for `lab.tapestation`
CREATE OR REPLACE FUNCTION "lab".create_tapestation_partition_if_not_exists()
RETURNS TRIGGER AS $$
DECLARE
    partition_date date;
    partition_name text;
    start_date date;
    end_date date;
BEGIN
    partition_date := NEW.measurement_date;
    IF partition_date IS NULL THEN
        RAISE EXCEPTION 'Cannot partition on NULL measurement_date for lab.tapestation. Please provide a measurement_date.';
    END IF;

    start_date := DATE_TRUNC('year', partition_date);
    end_date := DATE_TRUNC('year', partition_date) + INTERVAL '1 year';
    partition_name := 'tapestation_y' || TO_CHAR(start_date, 'YYYY');

    EXECUTE 'CREATE TABLE IF NOT EXISTS "lab".' || quote_ident(partition_name) || ' PARTITION OF "lab"."tapestation"
             FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- Function to create partitions for `lab.pcr`
CREATE OR REPLACE FUNCTION "lab".create_pcr_partition_if_not_exists()
RETURNS TRIGGER AS $$
DECLARE
    partition_date date;
    partition_name text;
    start_date date;
    end_date date;
BEGIN
    partition_date := NEW.pcr_date;
    IF partition_date IS NULL THEN
        RAISE EXCEPTION 'Cannot partition on NULL pcr_date for lab.pcr. Please provide a pcr_date.';
    END IF;

    start_date := DATE_TRUNC('year', partition_date);
    end_date := DATE_TRUNC('year', partition_date) + INTERVAL '1 year';
    partition_name := 'pcr_y' || TO_CHAR(start_date, 'YYYY');

    EXECUTE 'CREATE TABLE IF NOT EXISTS "lab".' || quote_ident(partition_name) || ' PARTITION OF "lab"."pcr"
             FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- Function to create partitions for `lab.gelelectrophoresis`
CREATE OR REPLACE FUNCTION "lab".create_gelelectrophoresis_partition_if_not_exists()
RETURNS TRIGGER AS $$
DECLARE
    partition_date date;
    partition_name text;
    start_date date;
    end_date date;
BEGIN
    partition_date := NEW.run_date;
    IF partition_date IS NULL THEN
        RAISE EXCEPTION 'Cannot partition on NULL run_date for lab.gelelectrophoresis. Please provide a run_date.';
    END IF;

    start_date := DATE_TRUNC('year', partition_date);
    end_date := DATE_TRUNC('year', partition_date) + INTERVAL '1 year';
    partition_name := 'gelelectrophoresis_y' || TO_CHAR(start_date, 'YYYY');

    EXECUTE 'CREATE TABLE IF NOT EXISTS "lab".' || quote_ident(partition_name) || ' PARTITION OF "lab"."gelelectrophoresis"
             FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- Function to create partitions for `lab.qpcr`
CREATE OR REPLACE FUNCTION "lab".create_qpcr_partition_if_not_exists()
RETURNS TRIGGER AS $$
DECLARE
    partition_date date;
    partition_name text;
    start_date date;
    end_date date;
BEGIN
    partition_date := NEW.qpcr_date;
    IF partition_date IS NULL THEN
        RAISE EXCEPTION 'Cannot partition on NULL qpcr_date for lab.qpcr. Please provide a qpcr_date.';
    END IF;

    start_date := DATE_TRUNC('year', partition_date);
    end_date := DATE_TRUNC('year', partition_date) + INTERVAL '1 year';
    partition_name := 'qpcr_y' || TO_CHAR(start_date, 'YYYY');

    EXECUTE 'CREATE TABLE IF NOT EXISTS "lab".' || quote_ident(partition_name) || ' PARTITION OF "lab"."qpcr"
             FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- Function to create partitions for `lab.library`
CREATE OR REPLACE FUNCTION "lab".create_library_partition_if_not_exists()
RETURNS TRIGGER AS $$
DECLARE
    partition_date date;
    partition_name text;
    start_date date;
    end_date date;
BEGIN
    partition_date := NEW.prep_date;
    IF partition_date IS NULL THEN
        RAISE EXCEPTION 'Cannot partition on NULL prep_date for lab.library. Please provide a prep_date.';
    END IF;

    start_date := DATE_TRUNC('year', partition_date);
    end_date := DATE_TRUNC('year', partition_date) + INTERVAL '1 year';
    partition_name := 'library_y' || TO_CHAR(start_date, 'YYYY');

    EXECUTE 'CREATE TABLE IF NOT EXISTS "lab".' || quote_ident(partition_name) || ' PARTITION OF "lab"."library"
             FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- Function to create partitions for `lab.sequencing`
CREATE OR REPLACE FUNCTION "lab".create_sequencing_partition_if_not_exists()
RETURNS TRIGGER AS $$
DECLARE
    partition_date date;
    partition_name text;
    start_date date;
    end_date date;
BEGIN
    partition_date := NEW.sequencing_date;
    IF partition_date IS NULL THEN
        RAISE EXCEPTION 'Cannot partition on NULL sequencing_date for lab.sequencing. Please provide a sequencing_date.';
    END IF;

    start_date := DATE_TRUNC('year', partition_date);
    end_date := DATE_TRUNC('year', partition_date) + INTERVAL '1 year';
    partition_name := 'sequencing_y' || TO_CHAR(start_date, 'YYYY');

    EXECUTE 'CREATE TABLE IF NOT EXISTS "lab".' || quote_ident(partition_name) || ' PARTITION OF "lab"."sequencing"
             FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- Function to create partitions for `lab.datasets`
CREATE OR REPLACE FUNCTION "lab".create_datasets_partition_if_not_exists()
RETURNS TRIGGER AS $$
DECLARE
    partition_date date;
    partition_name text;
    start_date date;
    end_date date;
BEGIN
    partition_date := NEW.reception_date;
    IF partition_date IS NULL THEN
        RAISE EXCEPTION 'Cannot partition on NULL reception_date for lab.datasets. Please provide a reception_date.';
    END IF;

    start_date := DATE_TRUNC('year', partition_date);
    end_date := DATE_TRUNC('year', partition_date) + INTERVAL '1 year';
    partition_name := 'datasets_y' || TO_CHAR(start_date, 'YYYY');

    EXECUTE 'CREATE TABLE IF NOT EXISTS "lab".' || quote_ident(partition_name) || ' PARTITION OF "lab"."datasets"
             FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- Function to create partitions for `bioinformatics.analysis_runs`
CREATE OR REPLACE FUNCTION "bioinformatics".create_analysis_runs_partition_if_not_exists()
RETURNS TRIGGER AS $$
DECLARE
    partition_date date;
    partition_name text;
    start_date date;
    end_date date;
BEGIN
    partition_date := NEW.run_date::date;
    IF partition_date IS NULL THEN
        RAISE EXCEPTION 'Cannot partition on NULL run_date for bioinformatics.analysis_runs. Please provide a run_date.';
    END IF;

    start_date := DATE_TRUNC('year', partition_date);
    end_date := DATE_TRUNC('year', partition_date) + INTERVAL '1 year';
    partition_name := 'analysis_runs_y' || TO_CHAR(start_date, 'YYYY');

    EXECUTE 'CREATE TABLE IF NOT EXISTS "bioinformatics".' || quote_ident(partition_name) || ' PARTITION OF "bioinformatics"."analysis_runs"
             FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- Functions to create partitions manually (for historical data loading, etc.)

CREATE OR REPLACE FUNCTION "lab".create_dna_partition_if_not_exists_manual(p_year integer)
RETURNS VOID AS $$
DECLARE
    start_date date;
    end_date date;
    partition_name text;
BEGIN
    start_date := MAKE_DATE(p_year, 1, 1);
    end_date := MAKE_DATE(p_year + 1, 1, 1);
    partition_name := 'dna_y' || p_year;

    EXECUTE 'CREATE TABLE IF NOT EXISTS "lab".' || quote_ident(partition_name) || ' PARTITION OF "lab"."dna"
             FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "lab".create_fish_partition_if_not_exists_manual(p_year integer)
RETURNS VOID AS $$
DECLARE
    start_date date;
    end_date date;
    partition_name text;
BEGIN
    start_date := MAKE_DATE(p_year, 1, 1);
    end_date := MAKE_DATE(p_year + 1, 1, 1);
    partition_name := 'fish_y' || TO_CHAR(start_date, 'YYYY');

    EXECUTE 'CREATE TABLE IF NOT EXISTS "lab".' || quote_ident(partition_name) || ' PARTITION OF "lab"."fish"
             FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "lab".create_fishing_partition_if_not_exists_manual(p_year integer)
RETURNS VOID AS $$
DECLARE
    start_date date;
    end_date date;
    partition_name text;
BEGIN
    start_date := MAKE_DATE(p_year, 1, 1);
    end_date := MAKE_DATE(p_year + 1, 1, 1);
    partition_name := 'fishing_y' || TO_CHAR(start_date, 'YYYY');

    EXECUTE 'CREATE TABLE IF NOT EXISTS "lab".' || quote_ident(partition_name) || ' PARTITION OF "lab"."fishing"
             FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "lab".create_otoliths_partition_if_not_exists_manual(p_year integer)
RETURNS VOID AS $$
DECLARE
    start_date date;
    end_date date;
    partition_name text;
BEGIN
    start_date := MAKE_DATE(p_year, 1, 1);
    end_date := MAKE_DATE(p_year + 1, 1, 1);
    partition_name := 'otoliths_y' || TO_CHAR(start_date, 'YYYY');

    EXECUTE 'CREATE TABLE IF NOT EXISTS "lab".' || quote_ident(partition_name) || ' PARTITION OF "lab"."otoliths"
             FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "lab".create_rna_partition_if_not_exists_manual(p_year integer)
RETURNS VOID AS $$
DECLARE
    start_date date;
    end_date date;
    partition_name text;
BEGIN
    start_date := MAKE_DATE(p_year, 1, 1);
    end_date := MAKE_DATE(p_year + 1, 1, 1);
    partition_name := 'rna_y' || TO_CHAR(start_date, 'YYYY');

    EXECUTE 'CREATE TABLE IF NOT EXISTS "lab".' || quote_ident(partition_name) || ' PARTITION OF "lab"."rna"
             FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "lab".create_sediments_partition_if_not_exists_manual(p_year integer)
RETURNS VOID AS $$
DECLARE
    start_date date;
    end_date date;
    partition_name text;
BEGIN
    start_date := MAKE_DATE(p_year, 1, 1);
    end_date := MAKE_DATE(p_year + 1, 1, 1);
    partition_name := 'sediments_y' || TO_CHAR(start_date, 'YYYY');

    EXECUTE 'CREATE TABLE IF NOT EXISTS "lab".' || quote_ident(partition_name) || ' PARTITION OF "lab"."sediments"
             FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "lab".create_tissue_partition_if_not_exists_manual(p_year integer)
RETURNS VOID AS $$
DECLARE
    start_date date;
    end_date date;
    partition_name text;
BEGIN
    start_date := MAKE_DATE(p_year, 1, 1);
    end_date := MAKE_DATE(p_year + 1, 1, 1);
    partition_name := 'tissue_y' || TO_CHAR(start_date, 'YYYY');

    EXECUTE 'CREATE TABLE IF NOT EXISTS "lab".' || quote_ident(partition_name) || ' PARTITION OF "lab"."tissue"
             FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "lab".create_water_partition_if_not_exists_manual(p_year integer)
RETURNS VOID AS $$
DECLARE
    start_date date;
    end_date date;
    partition_name text;
BEGIN
    start_date := MAKE_DATE(p_year, 1, 1);
    end_date := MAKE_DATE(p_year + 1, 1, 1);
    partition_name := 'water_y' || TO_CHAR(start_date, 'YYYY');

    EXECUTE 'CREATE TABLE IF NOT EXISTS "lab".' || quote_ident(partition_name) || ' PARTITION OF "lab"."water"
             FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "projects".create_ProjectWanderfische_FishingData_partition_if_not_exists_manual(p_year integer)
RETURNS VOID AS $$
DECLARE
    start_date date;
    end_date date;
    partition_name text;
BEGIN
    start_date := MAKE_DATE(p_year, 1, 1);
    end_date := MAKE_DATE(p_year + 1, 1, 1);
    partition_name := 'ProjectWanderfische_FishingData_y' || p_year;

    EXECUTE 'CREATE TABLE IF NOT EXISTS "projects".' || quote_ident(partition_name) || ' PARTITION OF "projects"."ProjectWanderfische_FishingData"
             FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "bioinformatics".create_analysis_runs_partition_if_not_exists_manual(p_year integer)
RETURNS VOID AS $$
DECLARE
    start_date date;
    end_date date;
    partition_name text;
BEGIN
    start_date := MAKE_DATE(p_year, 1, 1);
    end_date := MAKE_DATE(p_year + 1, 1, 1);
    partition_name := 'analysis_runs_y' || p_year;

    EXECUTE 'CREATE TABLE IF NOT EXISTS "bioinformatics".' || quote_ident(partition_name) || ' PARTITION OF "bioinformatics"."analysis_runs"
             FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';
END;
$$ LANGUAGE plpgsql;

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

CREATE OR REPLACE FUNCTION "lab".create_samples_partition_if_not_exists_manual(p_year integer)
RETURNS VOID AS $$
DECLARE
    start_date date;
    end_date date;
    partition_name text;
BEGIN
    start_date := MAKE_DATE(p_year, 1, 1);
    end_date := MAKE_DATE(p_year + 1, 1, 1);
    partition_name := 'parentalsamples_y' || p_year;

    EXECUTE 'CREATE TABLE IF NOT EXISTS "lab".' || quote_ident(partition_name) || ' PARTITION OF "lab"."parental_samples"
             FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "lab".create_experiments_partition_if_not_exists_manual(p_year integer)
RETURNS VOID AS $$
DECLARE
    start_date date;
    end_date date;
    partition_name text;
BEGIN
    start_date := MAKE_DATE(p_year, 1, 1);
    end_date := MAKE_DATE(p_year + 1, 1, 1);
    partition_name := 'experiments_y' || p_year;

    EXECUTE 'CREATE TABLE IF NOT EXISTS "lab".' || quote_ident(partition_name) || ' PARTITION OF "lab"."experiments"
             FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "lab".create_dissections_partition_if_not_exists_manual(p_year integer)
RETURNS VOID AS $$
DECLARE
    start_date date;
    end_date date;
    partition_name text;
BEGIN
    start_date := MAKE_DATE(p_year, 1, 1);
    end_date := MAKE_DATE(p_year + 1, 1, 1);
    partition_name := 'dissections_y' || p_year;

    EXECUTE 'CREATE TABLE IF NOT EXISTS "lab".' || quote_ident(partition_name) || ' PARTITION OF "lab"."dissections"
             FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "lab".create_extraction_partition_if_not_exists_manual(p_year integer)
RETURNS VOID AS $$
DECLARE
    start_date date;
    end_date date;
    partition_name text;
BEGIN
    start_date := MAKE_DATE(p_year, 1, 1);
    end_date := MAKE_DATE(p_year + 1, 1, 1);
    partition_name := 'extraction_y' || p_year;

    EXECUTE 'CREATE TABLE IF NOT EXISTS "lab".' || quote_ident(partition_name) || ' PARTITION OF "lab"."extraction"
             FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "lab".create_nanodrop_partition_if_not_exists_manual(p_year integer)
RETURNS VOID AS $$
DECLARE
    start_date date;
    end_date date;
    partition_name text;
BEGIN
    start_date := MAKE_DATE(p_year, 1, 1);
    end_date := MAKE_DATE(p_year + 1, 1, 1);
    partition_name := 'nanodrop_y' || p_year;

    EXECUTE 'CREATE TABLE IF NOT EXISTS "lab".' || quote_ident(partition_name) || ' PARTITION OF "lab"."nanodrop"
             FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "lab".create_qubit_partition_if_not_exists_manual(p_year integer)
RETURNS VOID AS $$
DECLARE
    start_date date;
    end_date date;
    partition_name text;
BEGIN
    start_date := MAKE_DATE(p_year, 1, 1);
    end_date := MAKE_DATE(p_year + 1, 1, 1);
    partition_name := 'qubit_y' || p_year;

    EXECUTE 'CREATE TABLE IF NOT EXISTS "lab".' || quote_ident(partition_name) || ' PARTITION OF "lab"."qubit"
             FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "lab".create_tapestation_partition_if_not_exists_manual(p_year integer)
RETURNS VOID AS $$
DECLARE
    start_date date;
    end_date date;
    partition_name text;
BEGIN
    start_date := MAKE_DATE(p_year, 1, 1);
    end_date := MAKE_DATE(p_year + 1, 1, 1);
    partition_name := 'tapestation_y' || p_year;

    EXECUTE 'CREATE TABLE IF NOT EXISTS "lab".' || quote_ident(partition_name) || ' PARTITION OF "lab"."tapestation"
             FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "lab".create_pcr_partition_if_not_exists_manual(p_year integer)
RETURNS VOID AS $$
DECLARE
    start_date date;
    end_date date;
    partition_name text;
BEGIN
    start_date := MAKE_DATE(p_year, 1, 1);
    end_date := MAKE_DATE(p_year + 1, 1, 1);
    partition_name := 'pcr_y' || p_year;

    EXECUTE 'CREATE TABLE IF NOT EXISTS "lab".' || quote_ident(partition_name) || ' PARTITION OF "lab"."pcr"
             FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "lab".create_gelelectrophoresis_partition_if_not_exists_manual(p_year integer)
RETURNS VOID AS $$
DECLARE
    start_date date;
    end_date date;
    partition_name text;
BEGIN
    start_date := MAKE_DATE(p_year, 1, 1);
    end_date := MAKE_DATE(p_year + 1, 1, 1);
    partition_name := 'gelelectrophoresis_y' || p_year;

    EXECUTE 'CREATE TABLE IF NOT EXISTS "lab".' || quote_ident(partition_name) || ' PARTITION OF "lab"."gelelectrophoresis"
             FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "lab".create_qpcr_partition_if_not_exists_manual(p_year integer)
RETURNS VOID AS $$
DECLARE
    start_date date;
    end_date date;
    partition_name text;
BEGIN
    start_date := MAKE_DATE(p_year, 1, 1);
    end_date := MAKE_DATE(p_year + 1, 1, 1);
    partition_name := 'qpcr_y' || p_year;

    EXECUTE 'CREATE TABLE IF NOT EXISTS "lab".' || quote_ident(partition_name) || ' PARTITION OF "lab"."qpcr"
             FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "lab".create_library_partition_if_not_exists_manual(p_year integer)
RETURNS VOID AS $$
DECLARE
    start_date date;
    end_date date;
    partition_name text;
BEGIN
    start_date := MAKE_DATE(p_year, 1, 1);
    end_date := MAKE_DATE(p_year + 1, 1, 1);
    partition_name := 'library_y' || p_year;

    EXECUTE 'CREATE TABLE IF NOT EXISTS "lab".' || quote_ident(partition_name) || ' PARTITION OF "lab"."library"
             FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "lab".create_sequencing_partition_if_not_exists_manual(p_year integer)
RETURNS VOID AS $$
DECLARE
    start_date date;
    end_date date;
    partition_name text;
BEGIN
    start_date := MAKE_DATE(p_year, 1, 1);
    end_date := MAKE_DATE(p_year + 1, 1, 1);
    partition_name := 'sequencing_y' || p_year;

    EXECUTE 'CREATE TABLE IF NOT EXISTS "lab".' || quote_ident(partition_name) || ' PARTITION OF "lab"."sequencing"
             FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "lab".create_datasets_partition_if_not_exists_manual(p_year integer)
RETURNS VOID AS $$
DECLARE
    start_date date;
    end_date date;
    partition_name text;
BEGIN
    start_date := MAKE_DATE(p_year, 1, 1);
    end_date := MAKE_DATE(p_year + 1, 1, 1);
    partition_name := 'datasets_y' || p_year;

    EXECUTE 'CREATE TABLE IF NOT EXISTS "lab".' || quote_ident(partition_name) || ' PARTITION OF "lab"."datasets"
             FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';
END;
$$ LANGUAGE plpgsql;


-- ======================================================================
-- 11.Functions: populate Functions
-- ======================================================================
-- Function to populate experiment_id and experiment_date for lab.fishing
CREATE OR REPLACE FUNCTION "lab".populate_fishing_experiment_data()
RETURNS TRIGGER AS $$
DECLARE
    exp_id text;
    exp_date date;
BEGIN
    -- Look up experiment_id and experiment_date from lab.sampling
    SELECT s.experiment_id, s.experiment_date
    INTO exp_id, exp_date
    FROM "lab"."sampling" s
    WHERE s.sampling_id = NEW.sampling_id;

    IF exp_id IS NULL OR exp_date IS NULL THEN
        RAISE EXCEPTION 'Could not find associated experiment_id or experiment_date for sampling_id % for fishing record. Ensure sampling data is complete.', NEW.sampling_id;
    END IF;

    NEW.experiment_id := exp_id;
    NEW.experiment_date := exp_date;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- Function to populate experiment_id and experiment_date for lab.otoliths
CREATE OR REPLACE FUNCTION "lab".populate_otoliths_experiment_data()
RETURNS TRIGGER AS $$
DECLARE
    exp_id text;
    exp_date date;
BEGIN
    -- Derive experiment_id and experiment_date by joining `lab.parental_samples`
    -- to `lab.sampling`, using their respective IDs.
    SELECT
        sa.experiment_id,
        sa.experiment_date
    INTO
        exp_id,
        exp_date
    FROM
        "lab"."parental_samples" s
    JOIN
        "lab"."sampling" sa ON s.sampling_id = sa.sampling_id
    WHERE
        s.sample_id = NEW.sample_id;

    IF exp_id IS NULL OR exp_date IS NULL THEN
        RAISE EXCEPTION 'Could not find associated experiment_id or experiment_date for sample_id % from sampling record for otolith record. Ensure sample and sampling data are complete.', NEW.sample_id;
    END IF;

    NEW.experiment_id := exp_id;
    NEW.experiment_date := exp_date;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- Function to transform coordinates to EPSG:4326 (WGS84)
-- This function will be called before inserting data into geom_4326
CREATE OR REPLACE FUNCTION "projects".transform_coordinates_to_wgs84(
    p_easting numeric,
    p_northing numeric,
    p_latitude numeric,
    p_longitude numeric,
    p_original_srid integer
)
RETURNS geometry(Point, 4326) AS $$
DECLARE
    transformed_geom geometry(Point, 4326);
    temp_geom geometry;
BEGIN
    IF p_original_srid IS NULL THEN
        IF p_latitude IS NOT NULL AND p_longitude IS NOT NULL THEN
            temp_geom := ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326);
        ELSIF p_easting IS NOT NULL AND p_northing IS NOT NULL THEN
            RAISE WARNING 'Cannot transform coordinates: original_srid is NULL for Easting/Northing input. Returning NULL.';
            RETURN NULL;
        ELSE
            RETURN NULL;
        END IF;
    ELSIF p_original_srid = 4326 THEN
        IF p_longitude IS NOT NULL AND p_latitude IS NOT NULL THEN
            temp_geom := ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326);
        ELSIF p_easting IS NOT NULL AND p_northing IS NOT NULL THEN
            temp_geom := ST_SetSRID(ST_MakePoint(p_easting, p_northing), 4326);
        ELSE
            RETURN NULL;
        END IF;
    ELSIF p_easting IS NOT NULL AND p_northing IS NOT NULL THEN
        BEGIN
            temp_geom := ST_Transform(ST_SetSRID(ST_MakePoint(p_easting, p_northing), p_original_srid), 4326);
        EXCEPTION
            WHEN SQLSTATE 'XX000' THEN
                RAISE WARNING 'SRID % is not defined or transformation failed for coordinates (%, %). Returning NULL.', p_original_srid, p_easting, p_northing;
                RETURN NULL;
        END;
    ELSE
        RAISE WARNING 'Incomplete coordinate data for transformation. Easting/Northing missing for SRID %.', p_original_srid;
        RETURN NULL;
    END IF;

    IF temp_geom IS NOT NULL AND (
        ST_X(temp_geom) IS NULL OR ST_X(temp_geom) = 'Infinity'::float8 OR ST_X(temp_geom) = '-Infinity'::float8 OR ST_X(temp_geom) = 'NaN'::float8 OR
        ST_Y(temp_geom) IS NULL OR ST_Y(temp_geom) = 'Infinity'::float8 OR ST_Y(temp_geom) = '-Infinity'::float8 OR ST_Y(temp_geom) = 'NaN'::float8
    ) THEN
        RAISE WARNING 'Transformed geometry contains invalid (Infinity/NaN) coordinates. Returning NULL.';
        RETURN NULL;
    END IF;

    IF ST_GeometryType(temp_geom) = 'ST_Point' THEN
        transformed_geom := temp_geom;
    ELSE
        RAISE WARNING 'Transformed geometry is not a POINT type. Returning NULL.';
        RETURN NULL;
    END IF;

    RETURN transformed_geom;
END;
$$ LANGUAGE plpgsql;



-- Trigger function to populate geom_4326 before insert/update on ProjectWanderfische_FishingData
CREATE OR REPLACE FUNCTION "projects".populate_fishing_geom_4326()
RETURNS TRIGGER AS $$
BEGIN
    NEW.geom_4326 := "projects".transform_coordinates_to_wgs84(
        NEW.original_easting,
        NEW.original_northing,
        NEW.original_latitude,
        NEW.original_longitude,
        NEW.original_srid
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- Generic audit function for tracking changes
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


-- Updates the status of a sample in the `master_samples` table when a downstream process is completed
CREATE OR REPLACE FUNCTION "lab".update_sample_status()
RETURNS TRIGGER AS $$
DECLARE
    new_status text := TG_ARGV[0];
    target_sample_id text;
BEGIN
    target_sample_id := NEW.sample_id;

    UPDATE "lab"."master_samples"
    SET "status_id" = new_status
    WHERE "sample_id" = target_sample_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Validates that a sample's sampling_date matches the parent sampling event
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

-- Updates the `ltree` path for a taxon record
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

-- Checks if a person is a member of a project for RLS
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

-- Functions for Full-Text Search (FTS)
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


-- ======================================================================
-- 12. Indexes
-- ======================================================================

-- Reference Schema
CREATE INDEX IF NOT EXISTS idx_personal_full_name ON "lims"."personal" ("full_name");
CREATE INDEX IF NOT EXISTS idx_taxon_path_gist ON "reference"."taxon" USING GIST ("path");
CREATE INDEX IF NOT EXISTS idx_units_unit_type ON "reference"."units" ("unit_type");

-- Lims Schema
CREATE INDEX IF NOT EXISTS idx_external_contacts_full_name ON "lims"."external_contacts" ("full_name");
CREATE INDEX IF NOT EXISTS idx_customers_customer_name ON "lims"."customers" ("customer_name");
CREATE INDEX IF NOT EXISTS idx_projects_status_id ON "lims"."projects" ("status_id");
CREATE INDEX IF NOT EXISTS idx_projects_pi_person_id ON "lims"."projects" ("pi_person_id");
CREATE INDEX IF NOT EXISTS idx_projects_customer_id ON "lims"."projects" ("customer_id");
CREATE INDEX IF NOT EXISTS idx_cruises_project_id ON "lims"."cruises" ("project_id");
CREATE INDEX IF NOT EXISTS idx_cruises_region_id ON "lims"."cruises" ("region_id");
CREATE INDEX IF NOT EXISTS idx_cruises_ecosystem_id ON "lims"."cruises" ("ecosystem_id");
CREATE INDEX IF NOT EXISTS idx_cruises_capitaine_contact_id ON "lims"."cruises" ("capitaine_contact_id");
CREATE INDEX IF NOT EXISTS idx_cruises_chief_scientist_person_id ON "lims"."cruises" ("chief_scientist_person_id");
CREATE INDEX IF NOT EXISTS idx_cruises_together_with_contact_id ON "lims"."cruises" ("together_with_contact_id");
CREATE INDEX IF NOT EXISTS idx_batch_steps_batch_id ON "lims"."batch_steps" ("batch_id");
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
CREATE INDEX IF NOT EXISTS idx_publications_doi_date ON "lims"."publications" ("doi", "date_publication");

-- Lab Schema
CREATE INDEX IF NOT EXISTS idx_experiments_sop_id ON "lab"."experiments" ("sop_id");
CREATE INDEX IF NOT EXISTS idx_experiments_person_id ON "lab"."experiments" ("person_id");
CREATE INDEX IF NOT EXISTS idx_experiments_projects_experiment_id ON "lab"."experiments_projects" ("experiment_id");
CREATE INDEX IF NOT EXISTS idx_experiments_projects_project_id ON "lab"."experiments_projects" ("project_id");
CREATE INDEX IF NOT EXISTS idx_protocol_runs_experiment_id ON "lab"."protocol_runs" ("experiment_id");
CREATE INDEX IF NOT EXISTS idx_sampling_project_id ON "lab"."sampling" ("project_id");
CREATE INDEX IF NOT EXISTS idx_sampling_cruise_id ON "lab"."sampling" ("cruise_id");
CREATE INDEX IF NOT EXISTS idx_sampling_region_id ON "lab"."sampling" ("region_id");
CREATE INDEX IF NOT EXISTS idx_sampling_ecosystem_id ON "lab"."sampling" ("ecosystem_id");
CREATE INDEX IF NOT EXISTS idx_sampling_customer_id ON "lab"."sampling" ("customer_id");
CREATE INDEX IF NOT EXISTS idx_sampling_geom ON "lab"."sampling" USING GIST ("geom");
CREATE INDEX IF NOT EXISTS idx_sampling_fishing_start_geom ON "lab"."sampling" USING GIST ("fishing_start_geom");
CREATE INDEX IF NOT EXISTS idx_sampling_fishing_end_geom ON "lab"."sampling" USING GIST ("fishing_end_geom");
CREATE INDEX IF NOT EXISTS idx_fishing_sampling_id_date ON "lab"."fishing" ("sampling_id", "sampling_date");
CREATE INDEX IF NOT EXISTS idx_fishing_taxon_id ON "lab"."fishing" ("taxon_id");
CREATE INDEX IF NOT EXISTS idx_parental_samples_parent_id ON "lab"."parental_samples" ("parent_sample_id");
CREATE INDEX IF NOT EXISTS idx_parental_samples_sample_type_id ON "lab"."parental_samples" ("sample_type_id");
CREATE INDEX IF NOT EXISTS idx_parental_samples_project_id ON "lab"."parental_samples" ("project_id");
CREATE INDEX IF NOT EXISTS idx_parental_samples_storage_id ON "lab"."parental_samples" ("storage_id");
CREATE INDEX IF NOT EXISTS idx_parental_samples_sampling_id_date ON "lab"."parental_samples" ("sampling_id", "sampling_date");
CREATE INDEX IF NOT EXISTS idx_storage_log_sample_id ON "lab"."storage_log" ("sample_id");

-- Lab Metadata tables (no new PKs, just FKs)
CREATE INDEX IF NOT EXISTS idx_fish_species_id ON "lab"."fish" ("species_id");
CREATE INDEX IF NOT EXISTS idx_fish_sampling_id_date ON "lab"."fish" ("sampling_id", "sampling_date");
CREATE INDEX IF NOT EXISTS idx_otoliths_sample_id ON "lab"."otoliths" ("sample_id");
CREATE INDEX IF NOT EXISTS idx_nanodrop_sample_id ON "lab"."nanodrop" ("sample_id");
CREATE INDEX IF NOT EXISTS idx_qubit_sample_id ON "lab"."qubit" ("sample_id");
CREATE INDEX IF NOT EXISTS idx_tapestation_sample_id ON "lab"."tapestation" ("sample_id");
CREATE INDEX IF NOT EXISTS idx_pcr_sample_id ON "lab"."pcr" ("sample_id");
CREATE INDEX IF NOT EXISTS idx_gelelectrophoresis_sample_id ON "lab"."gelelectrophoresis" ("sample_id");
CREATE INDEX IF NOT EXISTS idx_qpcr_sample_id ON "lab"."qpcr" ("sample_id");
CREATE INDEX IF NOT EXISTS idx_library_sample_id ON "lab"."library" ("sample_id");
CREATE INDEX IF NOT EXISTS idx_sequencing_sample_id ON "lab"."Seq_dataset" ("sample_id");
CREATE INDEX IF NOT EXISTS idx_sequencing_library_id ON "lab"."Seq_dataset" ("library_id");
CREATE INDEX IF NOT EXISTS idx_datasets_customer_id ON "lab"."datasets" ("customer_id");
CREATE INDEX IF NOT EXISTS idx_datasets_ecosystem_id ON "lab"."datasets" ("ecosystem_id");
CREATE INDEX IF NOT EXISTS idx_datasets_region_id ON "lab"."datasets" ("region_id");
CREATE INDEX IF NOT EXISTS idx_datasets_reception_date ON "lab"."datasets" ("reception_date");

-- Bioinformatics Schema
CREATE INDEX IF NOT EXISTS idx_analysis_runs_pipeline_id ON "bioinformatics"."analysis_runs" ("pipeline_id");
CREATE INDEX IF NOT EXISTS idx_analysis_runs_sequencing_id ON "bioinformatics"."analysis_runs" ("sequencing_id");
CREATE INDEX IF NOT EXISTS idx_edna_assignments_run_id_date ON "bioinformatics"."edna_assignments" ("run_id", "run_date");
CREATE INDEX IF NOT EXISTS idx_edna_assignments_sample_id ON "bioinformatics"."edna_assignments" ("sample_id");
CREATE INDEX IF NOT EXISTS idx_edna_assignments_taxon_id ON "bioinformatics"."edna_assignments" ("taxon_id");
CREATE INDEX IF NOT EXISTS idx_reference_databases_db_name ON "bioinformatics"."reference_databases" ("db_name");

-- Projects Schema
CREATE INDEX IF NOT EXISTS idx_ProjectWanderfische_FishingData_agency_id ON "projects"."ProjectWanderfische_FishingData" ("agency_id");
CREATE INDEX IF NOT EXISTS idx_ProjectWanderfische_FishingData_project_id ON "projects"."ProjectWanderfische_FishingData" ("project_id");
CREATE INDEX IF NOT EXISTS idx_ProjectWanderfische_FishingData_record_date ON "projects"."ProjectWanderfische_FishingData" ("record_date");
CREATE INDEX IF NOT EXISTS idx_ProjectWanderfische_FishingData_location_description ON "projects"."ProjectWanderfische_FishingData" ("location_description");
CREATE INDEX IF NOT EXISTS idx_ProjectWanderfische_FishingData_water_body_name ON "projects"."ProjectWanderfische_FishingData" ("water_body_name");
CREATE INDEX IF NOT EXISTS idx_ProjectWanderfische_FishingData_geom_4326 ON "projects"."ProjectWanderfische_FishingData" USING GIST ("geom_4326");
CREATE INDEX IF NOT EXISTS idx_ProjectWanderfische_FishingData_agency_record_id ON "projects"."ProjectWanderfische_FishingData" ("agency_record_id");
CREATE INDEX IF NOT EXISTS idx_ProjectWanderfische_FishCatch_fishing_record_id ON "projects"."ProjectWanderfische_FishCatch" ("fishing_record_id", "fishing_record_date");
CREATE INDEX IF NOT EXISTS idx_ProjectWanderfische_FishCatch_taxon_id ON "projects"."ProjectWanderfische_FishCatch" ("taxon_id");
CREATE INDEX IF NOT EXISTS idx_ProjectWanderfische_Mail_fishing_record_id ON "projects"."ProjectWanderfische_Mail" ("fishing_record_id", "fishing_record_date");
CREATE INDEX IF NOT EXISTS idx_ProjectWanderfische_Mail_sender_person_id ON "projects"."ProjectWanderfische_Mail" ("sender_person_id");
CREATE INDEX IF NOT EXISTS idx_ProjectWanderfische_Mail_recipient_contact_id ON "projects"."ProjectWanderfische_Mail" ("recipient_contact_id");
CREATE INDEX IF NOT EXISTS idx_ProjectWanderfische_Mail_sent_at ON "projects"."ProjectWanderfische_Mail" ("sent_at");
CREATE INDEX IF NOT EXISTS idx_ProjectWanderfische_Conversation_fishing_record_id ON "projects"."ProjectWanderfische_Conversation" ("fishing_record_id", "fishing_record_date");
CREATE INDEX IF NOT EXISTS idx_ProjectWanderfische_Conversation_topic ON "projects"."ProjectWanderfische_Conversation" ("topic");
CREATE INDEX IF NOT EXISTS idx_ProjectWanderfische_ChatMessage_conversation_id ON "projects"."ProjectWanderfische_ChatMessage" ("conversation_id");
CREATE INDEX IF NOT EXISTS idx_ProjectWanderfische_ChatMessage_sender_person_id ON "projects"."ProjectWanderfische_ChatMessage" ("sender_person_id");
CREATE INDEX IF NOT EXISTS idx_ProjectWanderfische_ChatMessage_sent_at ON "projects"."ProjectWanderfische_ChatMessage" ("sent_at");


-- ======================================================================
-- 13. Triggers
-- ======================================================================
DROP TRIGGER IF EXISTS trg_generate_publication_id ON "lims"."publications";
DROP TRIGGER IF EXISTS trg_generate_sop_id ON "lims"."sop";
DROP TRIGGER IF EXISTS trg_generate_batch_step_id ON "lims"."batch_steps";
DROP TRIGGER IF EXISTS trg_generate_sampling_id ON "lab"."sampling";
DROP TRIGGER IF EXISTS trg_generate_sample_id ON "lab"."parental_samples";
DROP TRIGGER IF EXISTS trg_generate_fishing_id ON "lab"."fishing";
DROP TRIGGER IF EXISTS trg_generate_dissection_id ON "lab"."dissections";
DROP TRIGGER IF EXISTS trg_generate_extraction_id ON "lab"."extraction";
DROP TRIGGER IF EXISTS trg_generate_nanodrop_id ON "lab"."nanodrop";
DROP TRIGGER IF EXISTS trg_generate_qubit_id ON "lab"."qubit";
DROP TRIGGER IF EXISTS trg_generate_tapestation_id ON "lab"."tapestation";
DROP TRIGGER IF EXISTS trg_generate_pcr_id ON "lab"."pcr";
DROP TRIGGER IF EXISTS trg_generate_gelelectrophoresis_id ON "lab"."gelelectrophoresis";
DROP TRIGGER IF EXISTS trg_generate_qpcr_id ON "lab"."qpcr";
DROP TRIGGER IF EXISTS trg_generate_library_id ON "lab"."library";
DROP TRIGGER IF EXISTS trg_generate_sequencing_id ON "lab"."sequencing";
DROP TRIGGER IF EXISTS trg_generate_dataset_id ON "lab"."datasets";
DROP TRIGGER IF EXISTS trg_generate_pipeline_id ON "bioinformatics"."analysis_pipelines";
DROP TRIGGER IF EXISTS trg_generate_analysis_run_id ON "bioinformatics"."analysis_runs";
DROP TRIGGER IF EXISTS trg_generate_edna_assignment_id ON "bioinformatics"."edna_assignments";
DROP TRIGGER IF EXISTS trg_generate_protocol_run_id ON "lab"."protocol_runs";
DROP TRIGGER IF EXISTS trg_generate_ProjectWanderfische_FishingData_id ON "projects"."ProjectWanderfische_FishingData";
DROP TRIGGER IF EXISTS trg_generate_ProjectWanderfische_FishCatch_id ON "projects"."ProjectWanderfische_FishCatch";
DROP TRIGGER IF EXISTS trg_generate_ProjectWanderfische_Mail_id ON "projects"."ProjectWanderfische_Mail";
DROP TRIGGER IF EXISTS trg_generate_ProjectWanderfische_Conversation_id ON "projects"."ProjectWanderfische_Conversation";
DROP TRIGGER IF EXISTS trg_generate_ProjectWanderfische_ChatMessage_id ON "projects"."ProjectWanderfische_ChatMessage";

DROP TRIGGER IF EXISTS trg_populate_fishing_experiment_data ON "lab"."fishing";
DROP TRIGGER IF EXISTS trg_populate_otoliths_experiment_data ON "lab"."otoliths";
DROP TRIGGER IF EXISTS trg_populate_fishing_geom_4326 ON "projects"."ProjectWanderfische_FishingData";

DROP TRIGGER IF EXISTS trg_update_status_dissection ON "lab"."dissections";
DROP TRIGGER IF EXISTS trg_update_status_extraction ON "lab"."extraction";
DROP TRIGGER IF EXISTS trg_update_status_nanodrop ON "lab"."nanodrop";
DROP TRIGGER IF EXISTS trg_update_status_qubit ON "lab"."qubit";
DROP TRIGGER IF EXISTS trg_update_status_tapestation ON "lab"."tapestation";
DROP TRIGGER IF EXISTS trg_update_status_pcr ON "lab"."pcr";
DROP TRIGGER IF EXISTS trg_update_status_qpcr ON "lab"."qpcr";
DROP TRIGGER IF EXISTS trg_update_status_library ON "lab"."library";
DROP TRIGGER IF EXISTS trg_update_status_sequencing ON "lab"."sequencing";
DROP TRIGGER IF EXISTS trg_update_status_bioinformatics ON "bioinformatics"."analysis_runs";

DROP TRIGGER IF EXISTS trg_validate_sample_sampling_date ON "lab"."parental_samples";
DROP TRIGGER IF EXISTS trg_create_sampling_partition ON "lab"."sampling";
DROP TRIGGER IF EXISTS trg_create_samples_partition ON "lab"."parental_samples";
DROP TRIGGER IF EXISTS trg_create_experiments_partition ON "lab"."experiments";
DROP TRIGGER IF EXISTS trg_create_dissections_partition ON "lab"."dissections";
DROP TRIGGER IF EXISTS trg_create_extraction_partition ON "lab"."extraction";
DROP TRIGGER IF EXISTS trg_create_nanodrop_partition ON "lab"."nanodrop";
DROP TRIGGER IF EXISTS trg_create_qubit_partition ON "lab"."qubit";
DROP TRIGGER IF EXISTS trg_create_tapestation_partition ON "lab"."tapestation";
DROP TRIGGER IF EXISTS trg_create_pcr_partition ON "lab"."pcr";
DROP TRIGGER IF EXISTS trg_create_gelelectrophoresis_partition ON "lab"."gelelectrophoresis";
DROP TRIGGER IF EXISTS trg_create_qpcr_partition ON "lab"."qpcr";
DROP TRIGGER IF EXISTS trg_create_library_partition ON "lab"."library";
DROP TRIGGER IF EXISTS trg_create_sequencing_partition ON "lab"."sequencing";
DROP TRIGGER IF EXISTS trg_create_datasets_partition ON "lab"."datasets";
DROP TRIGGER IF EXISTS trg_create_dna_partition ON "lab"."dna";
DROP TRIGGER IF EXISTS trg_create_fish_partition ON "lab"."fish";
DROP TRIGGER IF EXISTS trg_create_fishing_partition ON "lab"."fishing";
DROP TRIGGER IF EXISTS trg_create_otoliths_partition ON "lab"."otoliths";
DROP TRIGGER IF EXISTS trg_create_rna_partition ON "lab"."rna";
DROP TRIGGER IF EXISTS trg_create_sediments_partition ON "lab"."sediments";
DROP TRIGGER IF EXISTS trg_create_tissue_partition ON "lab"."tissue";
DROP TRIGGER IF EXISTS trg_create_water_partition ON "lab"."water";
DROP TRIGGER IF EXISTS trg_create_analysis_runs_partition ON "bioinformatics"."analysis_runs";

DROP TRIGGER IF EXISTS trg_update_customer_search ON "lims"."customers";
DROP TRIGGER IF EXISTS trg_update_sample_search ON "lab"."parental_samples";
DROP TRIGGER IF EXISTS trg_update_sop_search ON "lims"."sop";
DROP TRIGGER IF EXISTS trg_update_experiment_search ON "lab"."experiments";
DROP TRIGGER IF EXISTS trg_update_project_search ON "lims"."projects";

DROP TRIGGER IF EXISTS audit_trigger_personal ON "lims"."personal";
DROP TRIGGER IF EXISTS audit_trigger_status ON "reference"."status";
DROP TRIGGER IF EXISTS audit_trigger_room ON "reference"."room";
DROP TRIGGER IF EXISTS audit_trigger_vessel ON "reference"."vessel";
DROP TRIGGER IF EXISTS audit_trigger_region ON "reference"."region";
DROP TRIGGER IF EXISTS audit_trigger_ecosystem ON "reference"."ecosystem";
DROP TRIGGER IF EXISTS audit_trigger_category ON "reference"."category";
DROP TRIGGER IF EXISTS audit_trigger_samples_type ON "reference"."samples_type";
DROP TRIGGER IF EXISTS audit_trigger_gene ON "reference"."gene";
DROP TRIGGER IF EXISTS audit_trigger_taxon ON "reference"."taxon";
DROP TRIGGER IF EXISTS audit_trigger_units ON "reference"."units";
DROP TRIGGER IF EXISTS audit_trigger_external_contacts ON "lims"."external_contacts";
DROP TRIGGER IF EXISTS audit_trigger_customers ON "lims"."customers";
DROP TRIGGER IF EXISTS audit_trigger_projects ON "lims"."projects";
DROP TRIGGER IF EXISTS audit_trigger_project_persons ON "lims"."project_persons";
DROP TRIGGER IF EXISTS audit_trigger_cruises ON "lims"."cruises";
DROP TRIGGER IF EXISTS audit_trigger_batch ON "lims"."batch";
DROP TRIGGER IF EXISTS audit_trigger_permits ON "lims"."permits";
DROP TRIGGER IF EXISTS audit_trigger_primers ON "lims"."primers";
DROP TRIGGER IF EXISTS audit_trigger_sop ON "lims"."sop";
DROP TRIGGER IF EXISTS audit_trigger_batch_steps ON "lims"."batch_steps";
DROP TRIGGER IF EXISTS audit_trigger_equipment ON "lims"."equipment";
DROP TRIGGER IF EXISTS audit_trigger_suppliers ON "lims"."suppliers";
DROP TRIGGER IF EXISTS audit_trigger_inventory_items ON "lims"."inventory_items";
DROP TRIGGER IF EXISTS audit_trigger_orders ON "lims"."orders";
DROP TRIGGER IF EXISTS audit_trigger_reagents ON "lims"."reagents";
DROP TRIGGER IF EXISTS audit_trigger_publications ON "lims"."publications";
DROP TRIGGER IF EXISTS audit_trigger_storage ON "lab"."storage";
DROP TRIGGER IF EXISTS audit_trigger_experiments ON "lab"."experiments";
DROP TRIGGER IF EXISTS audit_trigger_experiments_projects ON "lab"."experiments_projects";
DROP TRIGGER IF EXISTS audit_trigger_protocol_runs ON "lab"."protocol_runs";
DROP TRIGGER IF EXISTS audit_trigger_sampling ON "lab"."sampling";
DROP TRIGGER IF EXISTS audit_trigger_master_samples ON "lab"."master_samples";
DROP TRIGGER IF EXISTS audit_trigger_parental_samples ON "lab"."parental_samples";
DROP TRIGGER IF EXISTS audit_trigger_storage_log ON "lab"."storage_log";
DROP TRIGGER IF EXISTS audit_trigger_fish ON "lab"."fish";
DROP TRIGGER IF EXISTS audit_trigger_tissue ON "lab"."tissue";
DROP TRIGGER IF EXISTS audit_trigger_otoliths ON "lab"."otoliths";
DROP TRIGGER IF EXISTS audit_trigger_dna ON "lab"."dna";
DROP TRIGGER IF EXISTS audit_trigger_rna ON "lab"."rna";
DROP TRIGGER IF EXISTS audit_trigger_sediments ON "lab"."sediments";
DROP TRIGGER IF EXISTS audit_trigger_water ON "lab"."water";
DROP TRIGGER IF EXISTS audit_trigger_experiments_samples ON "lab"."experiments_samples";
DROP TRIGGER IF EXISTS audit_trigger_dissections ON "lab"."dissections";
DROP TRIGGER IF EXISTS audit_trigger_extraction ON "lab"."extraction";
DROP TRIGGER IF EXISTS audit_trigger_nanodrop ON "lab"."nanodrop";
DROP TRIGGER IF EXISTS audit_trigger_qubit ON "lab"."qubit";
DROP TRIGGER IF EXISTS audit_trigger_tapestation ON "lab"."tapestation";
DROP TRIGGER IF EXISTS audit_trigger_pcr ON "lab"."pcr";
DROP TRIGGER IF EXISTS audit_trigger_gelelectrophoresis ON "lab"."gelelectrophoresis";
DROP TRIGGER IF EXISTS audit_trigger_qpcr ON "lab"."qpcr";
DROP TRIGGER IF EXISTS audit_trigger_library ON "lab"."library";
DROP TRIGGER IF EXISTS audit_trigger_sequencing ON "lab"."sequencing";
DROP TRIGGER IF EXISTS audit_trigger_datasets ON "lab"."datasets";
DROP TRIGGER IF EXISTS audit_trigger_reference_databases ON "bioinformatics"."reference_databases";
DROP TRIGGER IF EXISTS audit_trigger_analysis_pipelines ON "bioinformatics"."analysis_pipelines";
DROP TRIGGER IF EXISTS audit_trigger_analysis_runs ON "bioinformatics"."analysis_runs";
DROP TRIGGER IF EXISTS audit_trigger_edna_assignments ON "bioinformatics"."edna_assignments";
DROP TRIGGER IF EXISTS audit_trigger_ProjectWanderfische_FishingData ON "projects"."ProjectWanderfische_FishingData";
DROP TRIGGER IF EXISTS audit_trigger_ProjectWanderfische_FishCatch ON "projects"."ProjectWanderfische_FishCatch";
DROP TRIGGER IF EXISTS audit_trigger_ProjectWanderfische_Mail ON "projects"."ProjectWanderfische_Mail";
DROP TRIGGER IF EXISTS audit_trigger_ProjectWanderfische_Conversation ON "projects"."ProjectWanderfische_Conversation";
DROP TRIGGER IF EXISTS audit_trigger_ProjectWanderfische_ChatMessage ON "projects"."ProjectWanderfische_ChatMessage";

-- ID Generation Triggers
CREATE TRIGGER trg_generate_publication_id BEFORE INSERT ON "lims"."publications" FOR EACH ROW EXECUTE FUNCTION "lims".generate_publication_id();
CREATE TRIGGER trg_generate_sop_id BEFORE INSERT ON "lims"."sop" FOR EACH ROW EXECUTE FUNCTION "lims".generate_sop_id();
CREATE TRIGGER trg_generate_batch_step_id BEFORE INSERT ON "lims"."batch_steps" FOR EACH ROW EXECUTE FUNCTION "lims".generate_batch_step_id();
CREATE TRIGGER trg_generate_sampling_id BEFORE INSERT ON "lab"."sampling" FOR EACH ROW EXECUTE FUNCTION "lab".generate_sampling_id();
CREATE TRIGGER trg_generate_sample_id BEFORE INSERT ON "lab"."parental_samples" FOR EACH ROW EXECUTE FUNCTION "lab".generate_sample_id();
CREATE TRIGGER trg_generate_fishing_id BEFORE INSERT ON "lab"."fishing" FOR EACH ROW EXECUTE FUNCTION "lab".generate_fishing_id();
CREATE TRIGGER trg_generate_dissection_id BEFORE INSERT ON "lab"."dissections" FOR EACH ROW EXECUTE FUNCTION "lab".generate_dissection_id();
CREATE TRIGGER trg_generate_nanodrop_id BEFORE INSERT ON "lab"."nanodrop" FOR EACH ROW EXECUTE FUNCTION "lab".generate_nanodrop_id();
CREATE TRIGGER trg_generate_qubit_id BEFORE INSERT ON "lab"."qubit" FOR EACH ROW EXECUTE FUNCTION "lab".generate_qubit_id();
CREATE TRIGGER trg_generate_tapestation_id BEFORE INSERT ON "lab"."tapestation" FOR EACH ROW EXECUTE FUNCTION "lab".generate_tapestation_id();
CREATE TRIGGER trg_generate_pcr_id BEFORE INSERT ON "lab"."pcr" FOR EACH ROW EXECUTE FUNCTION "lab".generate_pcr_id();
CREATE TRIGGER trg_generate_gelelectrophoresis_id BEFORE INSERT ON "lab"."gelelectrophoresis" FOR EACH ROW EXECUTE FUNCTION "lab".generate_gelelectrophoresis_id();
CREATE TRIGGER trg_generate_qpcr_id BEFORE INSERT ON "lab"."qpcr" FOR EACH ROW EXECUTE FUNCTION "lab".generate_qpcr_id();
CREATE TRIGGER trg_generate_library_id BEFORE INSERT ON "lab"."library" FOR EACH ROW EXECUTE FUNCTION "lab".generate_library_id();
CREATE TRIGGER trg_generate_sequencing_id BEFORE INSERT ON "lab"."Seq_dataset" FOR EACH ROW EXECUTE FUNCTION "lab".generate_sequencing_id();
CREATE TRIGGER trg_generate_dataset_id BEFORE INSERT ON "lab"."datasets" FOR EACH ROW EXECUTE FUNCTION "lab".generate_dataset_id();
CREATE TRIGGER trg_generate_pipeline_id BEFORE INSERT ON "bioinformatics"."analysis_pipelines" FOR EACH ROW EXECUTE FUNCTION "bioinformatics".generate_pipeline_id();
CREATE TRIGGER trg_generate_analysis_run_id BEFORE INSERT ON "bioinformatics"."analysis_runs" FOR EACH ROW EXECUTE FUNCTION "bioinformatics".generate_analysis_run_id();
CREATE TRIGGER trg_generate_edna_assignment_id BEFORE INSERT ON "bioinformatics"."edna_assignments" FOR EACH ROW EXECUTE FUNCTION "bioinformatics".generate_edna_assignment_id();
CREATE TRIGGER trg_generate_protocol_run_id BEFORE INSERT ON "lab"."protocol_runs" FOR EACH ROW EXECUTE FUNCTION "lab".generate_protocol_run_id();
CREATE TRIGGER trg_generate_ProjectWanderfische_FishingData_id BEFORE INSERT ON "projects"."ProjectWanderfische_FishingData" FOR EACH ROW EXECUTE FUNCTION "projects".generate_ProjectWanderfische_FishingData_id();
CREATE TRIGGER trg_generate_ProjectWanderfische_FishCatch_id BEFORE INSERT ON "projects"."ProjectWanderfische_FishCatch" FOR EACH ROW EXECUTE FUNCTION "projects".generate_ProjectWanderfische_FishCatch_id();
CREATE TRIGGER trg_generate_ProjectWanderfische_Mail_id BEFORE INSERT ON "projects"."ProjectWanderfische_Mail" FOR EACH ROW EXECUTE FUNCTION "projects".generate_ProjectWanderfische_Mail_id();
CREATE TRIGGER trg_generate_ProjectWanderfische_Conversation_id BEFORE INSERT ON "projects"."ProjectWanderfische_Conversation" FOR EACH ROW EXECUTE FUNCTION "projects".generate_ProjectWanderfische_Conversation_id();
CREATE TRIGGER trg_generate_ProjectWanderfische_ChatMessage_id BEFORE INSERT ON "projects"."ProjectWanderfische_ChatMessage" FOR EACH ROW EXECUTE FUNCTION "projects".generate_ProjectWanderfische_ChatMessage_id();

-- Status Update Triggers
CREATE TRIGGER trg_update_status_dissection AFTER INSERT ON "lab"."dissections" FOR EACH ROW EXECUTE PROCEDURE "lab".update_sample_status('Dissection');
CREATE TRIGGER trg_update_status_nanodrop AFTER INSERT ON "lab"."nanodrop" FOR EACH ROW EXECUTE PROCEDURE "lab".update_sample_status('Nanodrop QC');
CREATE TRIGGER trg_update_status_qubit AFTER INSERT ON "lab"."qubit" FOR EACH ROW EXECUTE PROCEDURE "lab".update_sample_status('Qubit QC');
CREATE TRIGGER trg_update_status_tapestation AFTER INSERT ON "lab"."tapestation" FOR EACH ROW EXECUTE PROCEDURE "lab".update_sample_status('Tapestation QC');
CREATE TRIGGER trg_update_status_pcr AFTER INSERT ON "lab"."pcr" FOR EACH ROW EXECUTE PROCEDURE "lab".update_sample_status('PCR Done');
CREATE TRIGGER trg_update_status_qpcr AFTER INSERT ON "lab"."qpcr" FOR EACH ROW EXECUTE PROCEDURE "lab".update_sample_status('qPCR Done');
CREATE TRIGGER trg_update_status_library AFTER INSERT ON "lab"."library" FOR EACH ROW EXECUTE PROCEDURE "lab".update_sample_status('Library Prep');
CREATE TRIGGER trg_update_status_sequencing AFTER INSERT ON "lab"."Seq_dataset" FOR EACH ROW EXECUTE PROCEDURE "lab".update_sample_status('Sequencing Done');
CREATE TRIGGER trg_update_status_bioinformatics AFTER INSERT ON "bioinformatics"."analysis_runs" FOR EACH ROW EXECUTE PROCEDURE "lab".update_sample_status('Bioinformatics Done');

-- Validation and Partitioning Triggers
CREATE TRIGGER trg_validate_sample_sampling_date BEFORE INSERT OR UPDATE ON "lab"."parental_samples" FOR EACH ROW EXECUTE FUNCTION "lab".validate_sample_sampling_date();
CREATE TRIGGER trg_create_sampling_partition BEFORE INSERT ON "lab"."sampling" FOR EACH ROW EXECUTE FUNCTION "lab".create_sampling_partition_if_not_exists();
CREATE TRIGGER trg_create_samples_partition BEFORE INSERT ON "lab"."parental_samples" FOR EACH ROW EXECUTE FUNCTION "lab".create_samples_partition_if_not_exists();
CREATE TRIGGER trg_create_experiments_partition BEFORE INSERT ON "lab"."experiments" FOR EACH ROW EXECUTE FUNCTION "lab".create_experiments_partition_if_not_exists();
CREATE TRIGGER trg_create_dissections_partition BEFORE INSERT ON "lab"."dissections" FOR EACH ROW EXECUTE FUNCTION "lab".create_dissections_partition_if_not_exists();
CREATE TRIGGER trg_create_nanodrop_partition BEFORE INSERT ON "lab"."nanodrop" FOR EACH ROW EXECUTE FUNCTION "lab".create_nanodrop_partition_if_not_exists();
CREATE TRIGGER trg_create_qubit_partition BEFORE INSERT ON "lab"."qubit" FOR EACH ROW EXECUTE FUNCTION "lab".create_qubit_partition_if_not_exists();
CREATE TRIGGER trg_create_tapestation_partition BEFORE INSERT ON "lab"."tapestation" FOR EACH ROW EXECUTE FUNCTION "lab".create_tapestation_partition_if_not_exists();
CREATE TRIGGER trg_create_pcr_partition BEFORE INSERT ON "lab"."pcr" FOR EACH ROW EXECUTE FUNCTION "lab".create_pcr_partition_if_not_exists();
CREATE TRIGGER trg_create_gelelectrophoresis_partition BEFORE INSERT ON "lab"."gelelectrophoresis" FOR EACH ROW EXECUTE FUNCTION "lab".create_gelelectrophoresis_partition_if_not_exists();
CREATE TRIGGER trg_create_qpcr_partition BEFORE INSERT ON "lab"."qpcr" FOR EACH ROW EXECUTE FUNCTION "lab".create_qpcr_partition_if_not_exists();
CREATE TRIGGER trg_create_library_partition BEFORE INSERT ON "lab"."library" FOR EACH ROW EXECUTE FUNCTION "lab".create_library_partition_if_not_exists();
CREATE TRIGGER trg_create_sequencing_partition BEFORE INSERT ON "lab"."Seq_dataset" FOR EACH ROW EXECUTE FUNCTION "lab".create_sequencing_partition_if_not_exists();
CREATE TRIGGER trg_create_datasets_partition BEFORE INSERT ON "lab"."datasets" FOR EACH ROW EXECUTE FUNCTION "lab".create_datasets_partition_if_not_exists();
CREATE TRIGGER trg_create_dna_partition BEFORE INSERT ON "lab"."dna" FOR EACH ROW EXECUTE FUNCTION "lab".create_dna_partition_if_not_exists();
CREATE TRIGGER trg_create_fish_partition BEFORE INSERT ON "lab"."fish" FOR EACH ROW EXECUTE FUNCTION "lab".create_fish_partition_if_not_exists();
CREATE TRIGGER trg_create_fishing_partition BEFORE INSERT ON "lab"."fishing" FOR EACH ROW EXECUTE FUNCTION "lab".create_fishing_partition_if_not_exists();
CREATE TRIGGER trg_create_otoliths_partition BEFORE INSERT ON "lab"."otoliths" FOR EACH ROW EXECUTE FUNCTION "lab".create_otoliths_partition_if_not_exists();
CREATE TRIGGER trg_create_rna_partition BEFORE INSERT ON "lab"."rna" FOR EACH ROW EXECUTE FUNCTION "lab".create_rna_partition_if_not_exists();
CREATE TRIGGER trg_create_sediments_partition BEFORE INSERT ON "lab"."sediments" FOR EACH ROW EXECUTE FUNCTION "lab".create_sediments_partition_if_not_exists();
CREATE TRIGGER trg_create_tissue_partition BEFORE INSERT ON "lab"."tissue" FOR EACH ROW EXECUTE FUNCTION "lab".create_tissue_partition_if_not_exists();
CREATE TRIGGER trg_create_water_partition BEFORE INSERT ON "lab"."water" FOR EACH ROW EXECUTE FUNCTION "lab".create_water_partition_if_not_exists();
CREATE TRIGGER trg_create_analysis_runs_partition BEFORE INSERT ON "bioinformatics"."analysis_runs" FOR EACH ROW EXECUTE FUNCTION "bioinformatics".create_analysis_runs_partition_if_not_exists();


-- Audit Triggers
CREATE TRIGGER audit_trigger_personal AFTER INSERT OR UPDATE OR DELETE ON "lims"."personal" FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_status AFTER INSERT OR UPDATE OR DELETE ON "reference"."status" FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_room AFTER INSERT OR UPDATE OR DELETE ON "reference"."room" FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_vessel AFTER INSERT OR UPDATE OR DELETE ON "reference"."vessel" FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_region AFTER INSERT OR UPDATE OR DELETE ON "reference"."region" FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_ecosystem AFTER INSERT OR UPDATE OR DELETE ON "reference"."ecosystem" FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_category AFTER INSERT OR UPDATE OR DELETE ON "reference"."category" FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_samples_type AFTER INSERT OR UPDATE OR DELETE ON "reference"."samples_type" FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_gene AFTER INSERT OR UPDATE OR DELETE ON "reference"."gene" FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_taxon AFTER INSERT OR UPDATE OR DELETE ON "reference"."taxon" FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_units AFTER INSERT OR UPDATE OR DELETE ON "reference"."units" FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_external_contacts AFTER INSERT OR UPDATE OR DELETE ON "lims"."external_contacts" FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_customers AFTER INSERT OR UPDATE OR DELETE ON "lims"."customers" FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_projects AFTER INSERT OR UPDATE OR DELETE ON "lims"."projects" FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_project_persons AFTER INSERT OR UPDATE OR DELETE ON "lims"."project_persons" FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_cruises AFTER INSERT OR UPDATE OR DELETE ON "lims"."cruises" FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_batch AFTER INSERT OR UPDATE OR DELETE ON "lims"."batch" FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_permits AFTER INSERT OR UPDATE OR DELETE ON "lims"."permits" FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_primers AFTER INSERT OR UPDATE OR DELETE ON "lims"."primers" FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_sop AFTER INSERT OR UPDATE OR DELETE ON "lims"."sop" FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_batch_steps AFTER INSERT OR UPDATE OR DELETE ON "lims"."batch_steps" FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_equipment AFTER INSERT OR UPDATE OR DELETE ON "lims"."equipment" FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_suppliers AFTER INSERT OR UPDATE OR DELETE ON "lims"."suppliers" FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_inventory_items AFTER INSERT OR UPDATE OR DELETE ON "lims"."inventory_items" FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_orders AFTER INSERT OR UPDATE OR DELETE ON "lims"."orders" FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_reagents AFTER INSERT OR UPDATE OR DELETE ON "lims"."reagents" FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_publications AFTER INSERT OR UPDATE OR DELETE ON "lims"."publications" FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_storage AFTER INSERT OR UPDATE OR DELETE ON "lab"."storage" FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_experiments AFTER INSERT OR UPDATE OR DELETE ON "lab"."experiments" FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_experiments_projects AFTER INSERT OR UPDATE OR DELETE ON "lab"."experiments_projects" FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_protocol_runs AFTER INSERT OR UPDATE OR DELETE ON "lab"."protocol_runs" FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_sampling AFTER INSERT OR UPDATE OR DELETE ON "lab"."sampling" FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_master_samples AFTER INSERT OR UPDATE OR DELETE ON "lab"."master_samples" FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_parental_samples AFTER INSERT OR UPDATE OR DELETE ON "lab"."parental_samples" FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_storage_log AFTER INSERT OR UPDATE OR DELETE ON "lab"."storage_log" FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_fish AFTER INSERT OR UPDATE OR DELETE ON "lab"."fish" FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_tissue AFTER INSERT OR UPDATE OR DELETE ON "lab"."tissue" FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_otoliths AFTER INSERT OR UPDATE OR DELETE ON "lab"."otoliths" FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_dna AFTER INSERT OR UPDATE OR DELETE ON "lab"."dna" FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_rna AFTER INSERT OR UPDATE OR DELETE ON "lab"."rna" FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_sediments AFTER INSERT OR UPDATE OR DELETE ON "lab"."sediments" FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_water AFTER INSERT OR UPDATE OR DELETE ON "lab"."water" FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_experiments_samples AFTER INSERT OR UPDATE OR DELETE ON "lab"."experiments_samples" FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_dissections AFTER INSERT OR UPDATE OR DELETE ON "lab"."dissections" FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_nanodrop AFTER INSERT OR UPDATE OR DELETE ON "lab"."nanodrop" FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_qubit AFTER INSERT OR UPDATE OR DELETE ON "lab"."qubit" FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_tapestation AFTER INSERT OR UPDATE OR DELETE ON "lab"."tapestation" FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_pcr AFTER INSERT OR UPDATE OR DELETE ON "lab"."pcr" FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_gelelectrophoresis AFTER INSERT OR UPDATE OR DELETE ON "lab"."gelelectrophoresis" FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_qpcr AFTER INSERT OR UPDATE OR DELETE ON "lab"."qpcr" FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_library AFTER INSERT OR UPDATE OR DELETE ON "lab"."library" FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_sequencing AFTER INSERT OR UPDATE OR DELETE ON "lab"."Seq_dataset" FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_datasets AFTER INSERT OR UPDATE OR DELETE ON "lab"."datasets" FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_reference_databases AFTER INSERT OR UPDATE OR DELETE ON "bioinformatics"."reference_databases" FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_analysis_pipelines AFTER INSERT OR UPDATE OR DELETE ON "bioinformatics"."analysis_pipelines" FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_analysis_runs AFTER INSERT OR UPDATE OR DELETE ON "bioinformatics"."analysis_runs" FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_edna_assignments AFTER INSERT OR UPDATE OR DELETE ON "bioinformatics"."edna_assignments" FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_ProjectWanderfische_FishingData AFTER INSERT OR UPDATE OR DELETE ON "projects"."ProjectWanderfische_FishingData" FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_ProjectWanderfische_FishCatch AFTER INSERT OR UPDATE OR DELETE ON "projects"."ProjectWanderfische_FishCatch" FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_ProjectWanderfische_Mail AFTER INSERT OR UPDATE OR DELETE ON "projects"."ProjectWanderfische_Mail" FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_ProjectWanderfische_Conversation AFTER INSERT OR UPDATE OR DELETE ON "projects"."ProjectWanderfische_Conversation" FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_ProjectWanderfische_ChatMessage AFTER INSERT OR UPDATE OR DELETE ON "projects"."ProjectWanderfische_ChatMessage" FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();

-- ======================================================================
-- 14. Full-Text Search Configuration
-- ======================================================================

-- Create a custom text search configuration if it does not exist.
-- This configuration uses the standard English stemming dictionary.
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

DROP TRIGGER IF EXISTS trg_update_customer_search ON "lims"."customers";
DROP TRIGGER IF EXISTS trg_update_sample_search ON "lab"."parental_samples";
DROP TRIGGER IF EXISTS trg_update_sop_search ON "lims"."sop";
DROP TRIGGER IF EXISTS trg_update_experiment_search ON "lab"."experiments";
DROP TRIGGER IF EXISTS trg_update_project_search ON "lims"."projects";

DROP INDEX IF EXISTS idx_customers_gin_search;
DROP INDEX IF EXISTS idx_samples_gin_search;
DROP INDEX IF EXISTS idx_sop_gin_search;
DROP INDEX IF EXISTS idx_experiments_gin_search;
DROP INDEX IF EXISTS idx_projects_gin_search;

-- These functions concatenate relevant text fields for each table.

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

CREATE OR REPLACE FUNCTION "lims".update_project_search_vector_func()
RETURNS TRIGGER AS $$
BEGIN
    NEW.project_search_vector =
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.title, '')) ||
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.notes, ''));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- These columns are required for efficient full-text searching.

ALTER TABLE "lims"."customers" ADD COLUMN IF NOT EXISTS customer_search_vector TSVECTOR;
CREATE INDEX IF NOT EXISTS idx_customers_gin_search ON "lims"."customers" USING GIN (customer_search_vector);
CREATE TRIGGER trg_update_customer_search BEFORE INSERT OR UPDATE ON "lims"."customers" FOR EACH ROW EXECUTE FUNCTION "lims".update_customer_search_vector_func();

ALTER TABLE "lab"."parental_samples" ADD COLUMN IF NOT EXISTS sample_search_vector TSVECTOR;
CREATE INDEX IF NOT EXISTS idx_samples_gin_search ON "lab"."parental_samples" USING GIN (sample_search_vector);
CREATE TRIGGER trg_update_sample_search BEFORE INSERT OR UPDATE ON "lab"."parental_samples" FOR EACH ROW EXECUTE FUNCTION "lab".update_sample_search_vector_func();

ALTER TABLE "lims"."sop" ADD COLUMN IF NOT EXISTS sop_search_vector TSVECTOR;
CREATE INDEX IF NOT EXISTS idx_sop_gin_search ON "lims"."sop" USING GIN (sop_search_vector);
CREATE TRIGGER trg_update_sop_search BEFORE INSERT OR UPDATE ON "lims"."sop" FOR EACH ROW EXECUTE FUNCTION "lims".update_sop_search_vector_func();

ALTER TABLE "lab"."experiments" ADD COLUMN IF NOT EXISTS experiment_search_vector TSVECTOR;
CREATE INDEX IF NOT EXISTS idx_experiments_gin_search ON "lab"."experiments" USING GIN (experiment_search_vector);
CREATE TRIGGER trg_update_experiment_search BEFORE INSERT OR UPDATE ON "lab"."experiments" FOR EACH ROW EXECUTE FUNCTION "lab".update_experiment_search_vector_func();

ALTER TABLE "lims"."projects" ADD COLUMN IF NOT EXISTS project_search_vector TSVECTOR;
CREATE INDEX IF NOT EXISTS idx_projects_gin_search ON "lims"."projects" USING GIN (project_search_vector);
CREATE TRIGGER trg_update_project_search BEFORE INSERT OR UPDATE ON "lims"."projects" FOR EACH ROW EXECUTE FUNCTION "lims".update_project_search_vector_func();



-- Full-Text Search Indexes
CREATE INDEX IF NOT EXISTS idx_customers_gin_search ON "lims"."customers" USING GIN (customer_search_vector);
CREATE INDEX IF NOT EXISTS idx_samples_gin_search ON "lab"."parental_samples" USING GIN (sample_search_vector);
CREATE INDEX IF NOT EXISTS idx_sop_gin_search ON "lims"."sop" USING GIN (sop_search_vector);
CREATE INDEX IF NOT EXISTS idx_experiments_gin_search ON "lab"."experiments" USING GIN (experiment_search_vector);
CREATE INDEX IF NOT EXISTS idx_projects_gin_search ON "lims"."projects" USING GIN (project_search_vector);
-- FTS Triggers
CREATE TRIGGER trg_update_customer_search BEFORE INSERT OR UPDATE ON "lims"."customers" FOR EACH ROW EXECUTE FUNCTION "lims".update_customer_search_vector_func();
CREATE TRIGGER trg_update_sample_search BEFORE INSERT OR UPDATE ON "lab"."parental_samples" FOR EACH ROW EXECUTE FUNCTION "lab".update_sample_search_vector_func();
CREATE TRIGGER trg_update_sop_search BEFORE INSERT OR UPDATE ON "lims"."sop" FOR EACH ROW EXECUTE FUNCTION "lims".update_sop_search_vector_func();
CREATE TRIGGER trg_update_experiment_search BEFORE INSERT OR UPDATE ON "lab"."experiments" FOR EACH ROW EXECUTE FUNCTION "lab".update_experiment_search_vector_func();
CREATE TRIGGER trg_update_project_search BEFORE INSERT OR UPDATE ON "lims"."projects" FOR EACH ROW EXECUTE FUNCTION "lims".update_project_search_vector_func();

-- ======================================================================
-- 15. Views (Expanded for comprehensive coverage)
-- ======================================================================
-- ======================================================================
-- 1. Views
-- ======================================================================

-- View for a comprehensive overview of projects with all contact details.
CREATE OR REPLACE VIEW "lims"."projects_with_contact_details_view" AS
SELECT
    p.project_id,
    p.project_abrv,
    p.title,
    s.notes AS project_status,
    pers.full_name AS pi_full_name,
    p.funder,
    c.customer_name,
    c.customer_abrv,
    c.address AS customer_address,
    c.mail AS customer_mail,
    c.phone AS customer_phone,
    p.start_date,
    p.end_date,
    p.report_date,
    p.notes AS project_notes
FROM
    "lims"."projects" p
LEFT JOIN
    "reference"."status" s ON p.status_id = s.status_id
LEFT JOIN
    "lims"."personal" pers ON p.pi_person_id = pers.person_id
LEFT JOIN
    "lims"."customers" c ON p.customer_id = c.customer_id;

-- View to combine all relevant data from a sampling event, including geographic and environmental data.
CREATE OR REPLACE VIEW "lab"."full_sampling_data_view" AS
SELECT
    s.sampling_id,
    s.sampling_date,
    s.location_name,
    ST_X(s.geom) AS sampling_longitude,
    ST_Y(s.geom) AS sampling_latitude,
    ST_X(s.fishing_start_geom) AS fishing_start_longitude,
    ST_Y(s.fishing_start_geom) AS fishing_start_latitude,
    ST_X(s.fishing_end_geom) AS fishing_end_longitude,
    ST_Y(s.fishing_end_geom) AS fishing_end_latitude,
    s.depth_m,
    s.project_id,
    p.title AS project_title,
    p.project_abrv,
    s.cruise_id,
    c.vessel_id,
    v.vessel_name,
    s.region_id,
    r.region_abrv,
    s.ecosystem_id,
    e.ecosystem_type,
    s.status_id AS sampling_status,
    abiotic.weather,
    abiotic.temperature_atmospheric_c,
    abiotic.temperature_sampling_depth_c,
    abiotic.salinity,
    su.unit_abbreviation AS salinity_unit,
    abiotic.ph,
    abiotic.oxygen,
    ou.unit_abbreviation AS oxygen_unit,
    abiotic.notes AS abiotic_notes,
    s.notes AS sampling_notes
FROM
    "lab"."sampling" s
LEFT JOIN
    "lims"."projects" p ON s.project_id = p.project_id
LEFT JOIN
    "lims"."cruises" c ON s.cruise_id = c.cruise_id
LEFT JOIN
    "reference"."vessel" v ON c.vessel_id = v.vessel_id
LEFT JOIN
    "reference"."region" r ON s.region_id = r.region_id
LEFT JOIN
    "reference"."ecosystem" e ON s.ecosystem_id = e.ecosystem_id
LEFT JOIN
    "lab"."sampling_abiotic_data" abiotic ON s.sampling_id = abiotic.sampling_id AND s.sampling_date = abiotic.sampling_date
LEFT JOIN
    "reference"."units" su ON abiotic.salinity_unit_id = su.unit_id
LEFT JOIN
    "reference"."units" ou ON abiotic.oxygen_unit_id = ou.unit_id;

-- This is the most comprehensive view, combining all sample-related data.
CREATE OR REPLACE VIEW "lab"."comprehensive_sample_view" AS
SELECT
    -- Master Sample Details
    ms.sample_id AS master_sample_id,
    ps.external_name,
    ps.sample_type_id,
    st.sample_type_abrv,
    ps.status_id AS current_sample_status,
    ps.batch_id,
    ms.step_id,
    ps.notes AS sample_notes,

    -- Project & Customer Information
    ps.project_id,
    proj.title AS project_title,
    proj.funder AS project_funder,
    ps.customer_id,
    cust.customer_name,

    -- Parent & Root Sample
    ps.parent_sample_id,
    ps.root_sample_id,

    -- Sampling Event Details
    ps.sampling_id,
    ps.sampling_date,
    s.location_name AS sampling_location_name,
    ST_X(s.geom) AS sampling_longitude,
    ST_Y(s.geom) AS sampling_latitude,
    s.cruise_id,
    s.vessel_id,
    s.region_id,
    s.ecosystem_id,
    s.depth_m AS sampling_depth_m,

    -- Collection & Reception
    ps.sampler_person_id,
    sampler.full_name AS sampler_name,
    ps.receiver_person_id,
    receiver.full_name AS receiver_name,
    ps.reception_date,
    ps.transport,
    ps.conservation,

    -- Storage Information
    ps.storage_id,
    sl.move_date AS last_move_date,
    sl.person_id AS last_move_person_id,
    ps.storage_position,
    storage.freezer AS storage_freezer,
    storage.box AS storage_box,
    storage.temperature_c AS storage_temperature_c,
    room.room_id AS storage_room_id,
    room.etage AS storage_room_etage,

    -- Fish Details (if applicable)
    f.species_id,
    taxon_fish.en_name AS fish_species_name,
    f.total_length_mm,
    f.fork_length_mm,
    f.standard_length_mm,
    f.weight_g AS fish_weight_g,
    f.sex AS fish_sex,
    f.maturity_stage AS fish_maturity_stage,
    f.stomach_contents AS fish_stomach_contents,

    -- Tissue Details (if applicable)
    t.tissue_type,
    t.weight_g AS tissue_weight_g,
    t.preservation_method AS tissue_preservation_method,

    -- Otoliths Details (if applicable)
    o.otolith_id,
    o.side AS otolith_side,
    o.age_reading_years AS otolith_age,
    o.confidence AS otolith_confidence,
    reader.full_name AS otolith_reader_name,

    -- Dissection Details (if applicable)
    dis.dissection_id,
    dis.dissection_date,
    dis.person_id AS dissection_person_id,
    dis.stomach_contents_jsonb AS dissection_stomach_contents,
    dis.gonad_weight_g,
    dis.liver_weight_g,

    -- DNA Details (if applicable)
    dna.volume_ul AS dna_volume_ul,
    dna.concentration_ng_ul AS dna_concentration_ng_ul,
    dna.a260_280 AS dna_a260_280,
    dna.extraction_method AS dna_extraction_method,
    dna.extraction_date AS dna_extraction_date,
    dna.kit AS dna_extraction_kit,

    -- RNA Details (if applicable)
    rna.volume_ul AS rna_volume_ul,
    rna.concentration_ng_ul AS rna_concentration_ng_ul,
    rna.a260_280 AS rna_a260_280,
    rna.extraction_method AS rna_extraction_method,

    -- Qubit QC Details
    qu.qubit_id,
    qu.qubit_original_sample_conc,
    qu.measurement_date AS qubit_measurement_date,

    -- Nanodrop QC Details
    nd.nanopore_id,
    nd.nanodrop_concentration,
    nd.a260_280 AS nanodrop_a260_280,
    nd.nanodrop_total_dna_ug,

    -- Sequencing & Analysis
    lib.library_id,
    lib.library_prep_kit,
    lib.prep_date AS library_prep_date,
    sr.sequencing_run_id,
    sr.sequencer,
    sr.sequencing_date,
    sr.total_reads,
    sr.raw_data_path,
    ar.run_id AS analysis_run_id,
    ap.pipeline_name AS analysis_pipeline,
    rdb.db_name AS reference_database,
    ea.taxon_id AS assigned_edna_taxon_id,
    taxon_edna.en_name AS assigned_edna_taxon_name,
    ea.read_count AS edna_read_count,
    ea.confidence AS edna_confidence,

    -- All Experiment ID and Dates
    ps.experiment_id,
    ps.experiment_date
FROM
    "lab"."master_samples" ms
LEFT JOIN
    "lab"."parental_samples" ps ON ms.sample_id = ps.sample_id
LEFT JOIN
    "reference"."samples_type" st ON ps.sample_type_id = st.sample_type_id
LEFT JOIN
    "lims"."projects" proj ON ps.project_id = proj.project_id
LEFT JOIN
    "lims"."customers" cust ON ps.customer_id = cust.customer_id
LEFT JOIN
    "lab"."sampling" s ON ps.sampling_id = s.sampling_id AND ps.sampling_date = s.sampling_date
LEFT JOIN
    "lims"."personal" sampler ON ps.sampler_person_id = sampler.person_id
LEFT JOIN
    "lims"."personal" receiver ON ps.receiver_person_id = receiver.person_id
LEFT JOIN
    "lab"."storage_log" sl ON ms.sample_id = sl.sample_id
LEFT JOIN
    "lab"."storage" storage ON ps.storage_id = storage.storage_id
LEFT JOIN
    "reference"."room" room ON storage.room_id = room.room_id
LEFT JOIN
    "lab"."fish" f ON ps.sample_id = f.sample_id AND ps.sampling_date = f.sampling_date
LEFT JOIN
    "reference"."taxon" taxon_fish ON f.species_id = taxon_fish.taxon_id
LEFT JOIN
    "lab"."tissue" t ON ps.sample_id = t.sample_id AND ps.experiment_date = t.experiment_date
LEFT JOIN
    "lab"."otoliths" o ON ps.sample_id = o.sample_id AND ps.experiment_date = o.experiment_date
LEFT JOIN
    "lims"."personal" reader ON o.reader_person_id = reader.person_id
LEFT JOIN
    "lab"."dissections" dis ON ps.sample_id = dis.sample_id AND ps.experiment_date = dis.experiment_date
LEFT JOIN
    "lab"."dna" dna ON ps.sample_id = dna.sample_id AND ps.experiment_date = dna.experiment_date
LEFT JOIN
    "lab"."rna" rna ON ps.sample_id = rna.sample_id AND ps.experiment_date = rna.experiment_date
LEFT JOIN
    "lab"."qubit" qu ON ps.sample_id = qu.sample_id
LEFT JOIN
    "lab"."nanodrop" nd ON ps.sample_id = nd.sample_id
LEFT JOIN
    "lab"."library" lib ON ps.sample_id = lib.sample_id AND ps.experiment_date = lib.experiment_date
LEFT JOIN
    "lab"."sequencing_run" sr ON lib.library_id = sr.library_id AND lib.prep_date = sr.prep_date
LEFT JOIN
    "bioinformatics"."analysis_runs" ar ON sr.sequencing_run_id = ar.sequencing_id AND sr.sequencing_date = ar.sequencing_date
LEFT JOIN
    "bioinformatics"."analysis_pipelines" ap ON ar.pipeline_id = ap.pipeline_id
LEFT JOIN
    "bioinformatics"."reference_databases" rdb ON ar.reference_db_id = rdb.db_id
LEFT JOIN
    "bioinformatics"."edna_assignments" ea ON ps.sample_id = ea.sample_id
LEFT JOIN
    "reference"."taxon" taxon_edna ON ea.taxon_id = taxon_edna.taxon_id;

-- View for a comprehensive summary of project details and metrics
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
    COUNT(DISTINCT c.cruise_id) AS number_of_cruises,
    SUM(o.price) AS total_order_cost
FROM "lims"."projects" p
LEFT JOIN "reference"."status" stat ON p.status_id = stat.status_id
LEFT JOIN "lab"."experiments_projects" ep ON p.project_id = ep.project_id
LEFT JOIN "lab"."parental_samples" s ON p.project_id = s.project_id
LEFT JOIN "lims"."cruises" c ON p.project_id = c.project_id
LEFT JOIN "lims"."orders" o ON p.project_id = o.project_id
GROUP BY
    p.project_id, p.title, stat.notes, p.funder, p.start_date, p.end_date
ORDER BY p.start_date DESC;


-- View for tracking the progress of an experiment
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
    COUNT(DISTINCT dna.sample_id) AS samples_extracted,
    COUNT(DISTINCT qu.sample_id) AS samples_qubit_qc,
    COUNT(DISTINCT nd.sample_id) AS samples_nanodrop_qc,
    COUNT(DISTINCT tap.sample_id) AS samples_tapestation_qc,
    COUNT(DISTINCT pcr.sample_id) AS samples_pcr_done,
    COUNT(DISTINCT qpcr.sample_id) AS samples_qpcr_done,
    COUNT(DISTINCT lib.library_id) AS samples_library_prepped,
    COUNT(DISTINCT sr.sequencing_run_id) AS samples_sequenced,
    COUNT(DISTINCT ar.run_id) AS samples_bioinformatics_done
FROM "lab"."experiments" e
LEFT JOIN "lab"."experiments_projects" ep ON e.experiment_id = ep.experiment_id
LEFT JOIN "lims"."projects" p ON ep.project_id = p.project_id
LEFT JOIN "reference"."status" stat ON e.status_id = stat.status_id
LEFT JOIN "lims"."personal" pers ON e.person_id = pers.person_id
LEFT JOIN "lab"."experiments_samples" es ON e.experiment_id = es.experiment_id
LEFT JOIN "lab"."dna" dna ON es.sample_id = dna.sample_id
LEFT JOIN "lab"."qubit" qu ON es.sample_id = qu.sample_id
LEFT JOIN "lab"."nanodrop" nd ON es.sample_id = nd.sample_id
LEFT JOIN "lab"."tapestation" tap ON es.sample_id = tap.sample_id
LEFT JOIN "lab"."pcr" pcr ON es.sample_id = pcr.sample_id
LEFT JOIN "lab"."qpcr" qpcr ON es.sample_id = qpcr.sample_id
LEFT JOIN "lab"."library" lib ON es.sample_id = lib.sample_id
LEFT JOIN "lab"."sequencing_run" sr ON es.sample_id = sr.sample_id
LEFT JOIN "bioinformatics"."analysis_runs" ar ON sr.sequencing_run_id = ar.sequencing_id
GROUP BY
    e.experiment_id, e.experiment_title, p.project_id, p.title,
    stat.notes, e.experiment_date, pers.full_name
ORDER BY e.experiment_date DESC;

-- View to monitor reagent expiration status with more detail.
CREATE OR REPLACE VIEW "lims"."reagent_status_view" AS
SELECT
    r.reagent_id,
    r.reagent_complete_name,
    c.category_id,
    c.notes AS category_notes,
    r.lot,
    stat.notes AS current_status,
    r.reception_date,
    r.expire_date,
    CASE
        WHEN r.expire_date IS NULL THEN NULL
        ELSE (r.expire_date - CURRENT_DATE)
    END AS days_until_expiry,
    r.quantity_available,
    ru.unit_abbreviation AS quantity_unit,
    r.order_id,
    o.order_date,
    o.price AS order_price,
    supp.supplier_name
FROM
    "lims"."reagents" r
LEFT JOIN
    "reference"."status" stat ON r.status_id = stat.status_id
LEFT JOIN
    "reference"."units" ru ON r.quantity_unit_id = ru.unit_id
LEFT JOIN
    "reference"."category" c ON r.category_id = c.category_id
LEFT JOIN
    "lims"."orders" o ON r.order_id = o.fi_order_nr
LEFT JOIN
    "lims"."suppliers" supp ON o.supplier_id = supp.supplier_id
ORDER BY r.expire_date ASC;

-- View for tracking the movement of samples through storage.
CREATE OR REPLACE VIEW "lab"."storage_log_history_view" AS
SELECT
    sl.log_id,
    sl.sample_id,
    ps.external_name,
    sl.move_date,
    sl.person_id AS move_person_id,
    p.full_name AS move_person_name,
    sl.storage_id,
    storage.room_id,
    storage.freezer,
    storage.box,
    sl.storage_position,
    stat.notes AS move_status,
    sl.notes AS log_notes
FROM
    "lab"."storage_log" sl
LEFT JOIN
    "lab"."parental_samples" ps ON sl.sample_id = ps.sample_id
LEFT JOIN
    "lims"."personal" p ON sl.person_id = p.person_id
LEFT JOIN
    "lab"."storage" storage ON sl.storage_id = storage.storage_id
LEFT JOIN
    "reference"."status" stat ON sl.status_id = stat.status_id
ORDER BY
    sl.move_date DESC;

-- View for a summary of bioinformatics analysis results.
CREATE OR REPLACE VIEW "bioinformatics"."analysis_results_summary_view" AS
SELECT
    ar.run_id,
    ar.run_date,
    ar.person_id,
    pers.full_name AS analyst_name,
    ap.pipeline_name,
    ap.version AS pipeline_version,
    ar.sequencing_id,
    sr.sequencing_date,
    sr.sequencer,
    ar.reference_db_id,
    rdb.db_name AS reference_database_name,
    rdb.db_version AS bioinfo_database_version,
    ea.sample_id,
    ps.external_name AS sample_external_name,
    ea.taxon_id,
    t.en_name AS taxon_en_name,
    ea.read_count,
    ea.confidence,
    ar.notes AS run_notes,
    ea.notes AS assignment_notes
FROM
    "bioinformatics"."edna_assignments" ea
JOIN
    "bioinformatics"."analysis_runs" ar ON ea.run_id = ar.run_id
JOIN
    "bioinformatics"."analysis_pipelines" ap ON ar.pipeline_id = ap.pipeline_id
LEFT JOIN
    "lab"."sequencing_run" sr ON ar.sequencing_id = sr.sequencing_run_id AND ar.sequencing_date = sr.sequencing_date
LEFT JOIN
    "lab"."parental_samples" ps ON ea.sample_id = ps.sample_id
LEFT JOIN
    "lims"."personal" pers ON ar.person_id = pers.person_id
LEFT JOIN
    "reference"."taxon" t ON ea.taxon_id = t.taxon_id
LEFT JOIN
    "bioinformatics"."reference_databases" rdb ON ar.reference_db_id = rdb.db_id;

-- View to join all information related to a sequencing run.
CREATE OR REPLACE VIEW "lab"."full_sequencing_run_view" AS
SELECT
    sr.sequencing_run_id,
    sr.sequencing_date,
    sr.person_id,
    pers.full_name AS sequencer_person_name,
    sr.sequencer,
    sr.flow_cell_id,
    sr.library_id,
    lib.library_name,
    lib.library_prep_kit,
    sr.sample_id,
    ps.external_name AS sample_external_name,
    sr.read_length_bp,
    sr.total_reads,
    sr.raw_data_path,
    sr.genbank_accession_number,
    sr.project_id,
    p.title AS project_title,
    sr.status_id,
    sr.notes
FROM
    "lab"."sequencing_run" sr
LEFT JOIN
    "lims"."personal" pers ON sr.person_id = pers.person_id
LEFT JOIN
    "lab"."library" lib ON sr.library_id = lib.library_id
LEFT JOIN
    "lab"."parental_samples" ps ON sr.sample_id = ps.sample_id
LEFT JOIN
    "lims"."projects" p ON sr.project_id = p.project_id;



-- Materialized View for faster aggregation of monthly sample reception data
CREATE MATERIALIZED VIEW IF NOT EXISTS "lab"."monthly_sample_reception_mv" AS
SELECT
    TO_CHAR(reception_date, 'YYYY-MM') AS reception_month,
    sample_type_id,
    COUNT(sample_id) AS total_samples_received
FROM
    "lab"."parental_samples"
WHERE
    reception_date IS NOT NULL
GROUP BY
    1, 2
ORDER BY
    1, 2
WITH DATA;


-- ======================================================================
-- 16. Row-Level Security (RLS) Policies
-- ======================================================================

-- Enable Row-Level Security on all tables that require it.
ALTER TABLE "lims"."projects" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "lims"."project_persons" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "lims"."orders" ENABLE ROW LEVEL SECURITY;
ALTER TABLE TABLE "lims"."reagents" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "lims"."publications" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "lab"."parental_samples" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "lab"."experiments" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "lab"."experiments_projects" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "lab"."fishing" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "lab"."dissections" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "lab"."dna" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "lab"."rna" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "lab"."sediments" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "lab"."water" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "bioinformatics"."analysis_runs" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "bioinformatics"."edna_assignments" ENABLE ROW LEVEL SECURITY;

-- Policies for `lims.projects`
-- A PI or project team member can view their own project details.
CREATE POLICY project_membership_select_policy ON "lims"."projects"
FOR SELECT
USING ("lims".is_member_of_project("project_id"));

-- Only a PI can update their own project's core details.
CREATE POLICY project_pi_update_policy ON "lims"."projects"
FOR UPDATE
USING ("pi_person_id" = current_setting('lims.current_person_id', true));

-- Policies for `lims.project_persons`
-- Project members can view other members of their project.
CREATE POLICY project_persons_select_policy ON "lims"."project_persons"
FOR SELECT
USING ("lims".is_member_of_project("project_id"));

-- Only a project's PI can add or remove members.
CREATE POLICY project_persons_manage_policy ON "lims"."project_persons"
FOR ALL
USING ("lims".is_member_of_project("project_id"))
WITH CHECK ("lims".is_member_of_project("project_id"));

-- Policies for `lab.parental_samples` and derived data tables
-- All sample tables are linked to projects, so access is based on project membership.
CREATE POLICY samples_project_select_policy ON "lab"."parental_samples"
FOR SELECT
USING ("lims".is_member_of_project("project_id"));

CREATE POLICY samples_project_insert_policy ON "lab"."parental_samples"
FOR INSERT
WITH CHECK ("lims".is_member_of_project("project_id"));

CREATE POLICY samples_project_update_policy ON "lab"."parental_samples"
FOR UPDATE
USING ("lims".is_member_of_project("project_id"))
WITH CHECK ("lims".is_member_of_project("project_id"));

-- We'll apply a similar pattern to other lab data tables.
CREATE POLICY fish_project_select_policy ON "lab"."fish" FOR SELECT USING ("lims".is_member_of_project("project_id"));
CREATE POLICY tissue_project_select_policy ON "lab"."tissue" FOR SELECT USING ("lims".is_member_of_project("project_id"));
CREATE POLICY dna_project_select_policy ON "lab"."dna" FOR SELECT USING ("lims".is_member_of_project("project_id"));
CREATE POLICY rna_project_select_policy ON "lab"."rna" FOR SELECT USING ("lims".is_member_of_project("project_id"));
CREATE POLICY sediments_project_select_policy ON "lab"."sediments" FOR SELECT USING ("lims".is_member_of_project("project_id"));
CREATE POLICY water_project_select_policy ON "lab"."water" FOR SELECT USING ("lims".is_member_of_project("project_id"));
CREATE POLICY dissections_project_select_policy ON "lab"."dissections" FOR SELECT USING ("lims".is_member_of_project("project_id"));
CREATE POLICY experiments_project_select_policy ON "lab"."experiments" FOR SELECT USING ("lims".is_member_of_project("project_id"));
CREATE POLICY experiment_projects_select_policy ON "lab"."experiments_projects" FOR SELECT USING ("lims".is_member_of_project("project_id"));

-- Policies for `lims.orders` and `lims.reagents`
-- Users can only see orders and reagents related to their projects.
CREATE POLICY orders_project_select_policy ON "lims"."orders"
FOR SELECT
USING ("lims".is_member_of_project("project_id"));

CREATE POLICY reagents_project_select_policy ON "lims"."reagents"
FOR SELECT
USING ("lims".is_member_of_project("project_id"));

-- Policies for `bioinformatics` tables
-- Access to bioinformatics data is also controlled by project membership.
CREATE POLICY analysis_runs_project_select_policy ON "bioinformatics"."analysis_runs"
FOR SELECT
USING ("lims".is_member_of_project("project_id"));

CREATE POLICY edna_assignments_project_select_policy ON "bioinformatics"."edna_assignments"
FOR SELECT
USING ("lims".is_member_of_project("experiment_id"));

-- ======================================================================
-- 17. Advanced JSONB and ltree Query Examples
-- ======================================================================

-- ----------------------------------------------------------------------
-- JSONB Query Examples

-- 1. Querying raw data from `projects.ProjectWanderfische_FishingData`
SELECT
    "fishing_record_id",
    "agency_record_id",
    "original_data_jsonb" ->> 'Gewässername' AS "Gewässername",
    "original_data_jsonb" ->> 'Befischungsjahr' AS "Befischungsjahr"
FROM "projects"."ProjectWanderfische_FishingData"
WHERE
    "original_data_jsonb" ->> 'Gewässername' = 'Else';

-- 2. Searching for a specific key within the JSONB data
SELECT
    "fishing_record_id",
    "original_data_jsonb"
FROM "projects"."ProjectWanderfische_FishingData"
WHERE
    "original_data_jsonb" ? 'Gewässertyp';

-- 3. Searching for a nested key-value pair using the `@>` operator
SELECT
    "dissection_id",
    "sample_id",
    "stomach_contents_jsonb"
FROM "lab"."dissections"
WHERE
    "stomach_contents_jsonb" @> '[{"item": "shrimp"}]'::jsonb;

-- 4. Aggregating data from a JSONB array
SELECT
    "dissection_id",
    SUM((jsonb_array_elements("stomach_contents_jsonb")->>'quantity')::numeric) AS "total_item_quantity"
FROM "lab"."dissections"
WHERE
    "stomach_contents_jsonb" @> '[{"item": "fish"}]'::jsonb
GROUP BY "dissection_id";

-- ----------------------------------------------------------------------
-- ltree Query Examples

-- 1. Finding all descendants of a given taxon (e.g., all species under 'Gadus')
SELECT
    "taxon_id",
    "en_name"
FROM "reference"."taxon"
WHERE
    "path" <@ 'Gadus'::ltree;

-- 2. Finding the common ancestor of two taxa
SELECT lca('Gadus_morhua'::ltree, 'Salmo_salar'::ltree) AS "lowest_common_ancestor";

-- 3. Finding the full lineage of a specific species
-- The `<@` operator can find all ancestors of a given path.
SELECT
    "taxon_id",
    "en_name",
    "rank"
FROM "reference"."taxon"
WHERE
    'Animalia.Chordata.Actinopterygii.Gadiformes.Gadidae.Gadus.Gadus_morhua'::ltree <@ "path"
ORDER BY
    nlevel("path") ASC;
    
-- 4. Searching for all species at a specific rank under a higher-level taxon.
-- This query finds all genera under the order 'Gadiformes'.
SELECT
    "taxon_id",
    "en_name"
FROM "reference"."taxon"
WHERE
    "path" ~ 'Gadiformes.*{1}'::lquery AND rank = 'genus';


-- ======================================================================
-- 18. Add Foreign Key Constraints and Unique Constraints
-- ======================================================================

-- Drop existing constraints to prevent re-creation errors
ALTER TABLE IF EXISTS "reference"."taxon" DROP CONSTRAINT IF EXISTS "taxon_parent_fk";
ALTER TABLE IF EXISTS "lims"."projects" DROP CONSTRAINT IF EXISTS "projects_status_id_fk";
ALTER TABLE IF EXISTS "lims"."projects" DROP CONSTRAINT IF EXISTS "projects_pi_person_id_fk";
ALTER TABLE IF EXISTS "lims"."projects" DROP CONSTRAINT IF EXISTS "projects_customer_id_fk";
ALTER TABLE IF EXISTS "lims"."project_persons" DROP CONSTRAINT IF EXISTS "project_persons_project_id_fk";
ALTER TABLE IF EXISTS "lims"."project_persons" DROP CONSTRAINT IF EXISTS "project_persons_person_id_fk";
ALTER TABLE IF EXISTS "lims"."cruises" DROP CONSTRAINT IF EXISTS "cruises_project_id_fk";
ALTER TABLE IF EXISTS "lims"."cruises" DROP CONSTRAINT IF EXISTS "cruises_vessel_id_fk";
ALTER TABLE IF EXISTS "lims"."cruises" DROP CONSTRAINT IF EXISTS "cruises_status_id_fk";
ALTER TABLE IF EXISTS "lims"."cruises" DROP CONSTRAINT IF EXISTS "cruises_region_id_fk";
ALTER TABLE IF EXISTS "lims"."cruises" DROP CONSTRAINT IF EXISTS "cruises_ecosystem_id_fk";
ALTER TABLE IF EXISTS "lims"."cruises" DROP CONSTRAINT IF EXISTS "cruises_capitaine_contact_id_fk";
ALTER TABLE IF EXISTS "lims"."cruises" DROP CONSTRAINT IF EXISTS "cruises_chief_scientist_person_id_fk";
ALTER TABLE IF EXISTS "lims"."cruises" DROP CONSTRAINT IF EXISTS "cruises_together_with_contact_id_fk";
ALTER TABLE IF EXISTS "lims"."batch_steps" DROP CONSTRAINT IF EXISTS "batch_steps_batch_id_fk";
ALTER TABLE IF EXISTS "lims"."batch_steps" DROP CONSTRAINT IF EXISTS "batch_steps_sop_id_fk";
ALTER TABLE IF EXISTS "lims"."batch_steps" DROP CONSTRAINT IF EXISTS "batch_steps_status_id_fk";
ALTER TABLE IF EXISTS "lims"."primers" DROP CONSTRAINT IF EXISTS "primers_target_gene_id_fk";
ALTER TABLE IF EXISTS "lims"."sop" DROP CONSTRAINT IF EXISTS "sop_author_person_id_fk";
ALTER TABLE IF EXISTS "lims"."sop" DROP CONSTRAINT IF EXISTS "sop_reviewer1_person_id_fk";
ALTER TABLE IF EXISTS "lims"."sop" DROP CONSTRAINT IF EXISTS "sop_reviewer2_person_id_fk";
ALTER TABLE IF EXISTS "lims"."equipment" DROP CONSTRAINT IF EXISTS "equipment_room_id_fk";
ALTER TABLE IF EXISTS "lims"."inventory_items" DROP CONSTRAINT IF EXISTS "inventory_items_category_id_fk";
ALTER TABLE IF EXISTS "lims"."inventory_items" DROP CONSTRAINT IF EXISTS "inventory_items_unit_id_fk";
ALTER TABLE IF EXISTS "lims"."orders" DROP CONSTRAINT IF EXISTS "orders_item_id_fk";
ALTER TABLE IF EXISTS "lims"."orders" DROP CONSTRAINT IF EXISTS "orders_category_id_fk";
ALTER TABLE IF EXISTS "lims"."orders" DROP CONSTRAINT IF EXISTS "orders_project_id_fk";
ALTER TABLE IF EXISTS "lims"."orders" DROP CONSTRAINT IF EXISTS "orders_supplier_id_fk";
ALTER TABLE IF EXISTS "lims"."orders" DROP CONSTRAINT IF EXISTS "orders_status_id_fk";
ALTER TABLE IF EXISTS "lims"."reagents" DROP CONSTRAINT IF EXISTS "reagents_category_id_fk";
ALTER TABLE IF EXISTS "lims"."reagents" DROP CONSTRAINT IF EXISTS "reagents_storage_id_fk";
ALTER TABLE IF EXISTS "lims"."reagents" DROP CONSTRAINT IF EXISTS "reagents_status_id_fk";
ALTER TABLE IF EXISTS "lims"."reagents" DROP CONSTRAINT IF EXISTS "reagents_order_id_fk";
ALTER TABLE IF EXISTS "lims"."reagents" DROP CONSTRAINT IF EXISTS "reagents_project_id_fk";
ALTER TABLE IF EXISTS "lims"."reagents" DROP CONSTRAINT IF EXISTS "reagents_quantity_unit_id_fk";
ALTER TABLE IF EXISTS "lims"."publications" DROP CONSTRAINT IF EXISTS "publications_publication_type_id_fk";
ALTER TABLE IF EXISTS "lims"."publications" DROP CONSTRAINT IF EXISTS "publications_project_id_fk";
ALTER TABLE IF EXISTS "lims"."publications" DROP CONSTRAINT IF EXISTS "publications_first_author_person_id_fk";
ALTER TABLE IF EXISTS "lims"."publications" DROP CONSTRAINT IF EXISTS "publications_corresponding_author_person_id_fk";
ALTER TABLE IF EXISTS "lab"."storage" DROP CONSTRAINT IF EXISTS "storage_room_id_fk";
ALTER TABLE IF EXISTS "lab"."storage" DROP CONSTRAINT IF EXISTS "storage_project_id_fk";
ALTER TABLE IF EXISTS "lab"."experiments_projects" DROP CONSTRAINT IF EXISTS "experiments_projects_experiment_id_fk";
ALTER TABLE IF EXISTS "lab"."experiments_projects" DROP CONSTRAINT IF EXISTS "experiments_projects_project_id_fk";
ALTER TABLE IF EXISTS "lab"."protocol_runs" DROP CONSTRAINT IF EXISTS "protocol_runs_experiment_id_fk";
ALTER TABLE IF EXISTS "lab"."protocol_runs" DROP CONSTRAINT IF EXISTS "protocol_runs_person_id_fk";
ALTER TABLE IF EXISTS "lab"."sampling" DROP CONSTRAINT IF EXISTS "sampling_experiment_id_fk";
ALTER TABLE IF EXISTS "lab"."sampling" DROP CONSTRAINT IF EXISTS "sampling_project_id_fk";
ALTER TABLE IF EXISTS "lab"."sampling" DROP CONSTRAINT IF EXISTS "sampling_cruise_id_fk";
ALTER TABLE IF EXISTS "lab"."sampling" DROP CONSTRAINT IF EXISTS "sampling_region_id_fk";
ALTER TABLE IF EXISTS "lab"."sampling" DROP CONSTRAINT IF EXISTS "sampling_ecosystem_id_fk";
ALTER TABLE IF EXISTS "lab"."sampling" DROP CONSTRAINT IF EXISTS "sampling_vessel_id_fk";
ALTER TABLE IF EXISTS "lab"."sampling" DROP CONSTRAINT IF EXISTS "sampling_customer_id_fk";
ALTER TABLE IF EXISTS "lab"."sampling" DROP CONSTRAINT IF EXISTS "sampling_wind_unit_id_fk";
ALTER TABLE IF EXISTS "lab"."sampling" DROP CONSTRAINT IF EXISTS "sampling_salinity_unit_id_fk";
ALTER TABLE IF EXISTS "lab"."sampling" DROP CONSTRAINT IF EXISTS "sampling_pressure_unit_id_fk";
ALTER TABLE IF EXISTS "lab"."sampling" DROP CONSTRAINT IF EXISTS "sampling_oxygen_unit_id_fk";
ALTER TABLE IF EXISTS "lab"."sampling" DROP CONSTRAINT IF EXISTS "sampling_conductivity_unit_id_fk";
ALTER TABLE IF EXISTS "lab"."sampling" DROP CONSTRAINT IF EXISTS "sampling_soak_time_unit_id_fk";
ALTER TABLE IF EXISTS "lab"."sampling" DROP CONSTRAINT IF EXISTS "sampling_trawl_speed_unit_id_fk";
ALTER TABLE IF EXISTS "lab"."sampling" DROP CONSTRAINT IF EXISTS "sampling_together_with_contact_id_fk";
ALTER TABLE IF EXISTS "lab"."sampling" DROP CONSTRAINT IF EXISTS "sampling_status_id_fk";
ALTER TABLE IF EXISTS "lab"."fishing" DROP CONSTRAINT IF EXISTS "fishing_sampling_id_fk";
ALTER TABLE IF EXISTS "lab"."fishing" DROP CONSTRAINT IF EXISTS "fishing_taxon_id_fk";
ALTER TABLE IF EXISTS "lab"."fishing" DROP CONSTRAINT IF EXISTS "fishing_customer_id_fk";
ALTER TABLE IF EXISTS "lab"."parental_samples" DROP CONSTRAINT IF EXISTS "samples_master_sample_id_fk";
ALTER TABLE IF EXISTS "lab"."parental_samples" DROP CONSTRAINT IF EXISTS "samples_parent_sample_id_fk";
ALTER TABLE IF EXISTS "lab"."parental_samples" DROP CONSTRAINT IF EXISTS "samples_sampling_id_fk";
ALTER TABLE IF EXISTS "lab"."parental_samples" DROP CONSTRAINT IF EXISTS "samples_storage_id_fk";
ALTER TABLE IF EXISTS "lab"."parental_samples" DROP CONSTRAINT IF EXISTS "samples_sampler_person_id_fk";
ALTER TABLE IF EXISTS "lab"."parental_samples" DROP CONSTRAINT IF EXISTS "samples_receiver_person_id_fk";
ALTER TABLE IF EXISTS "lab"."parental_samples" DROP CONSTRAINT IF EXISTS "samples_sample_type_id_fk";
ALTER TABLE IF EXISTS "lab"."parental_samples" DROP CONSTRAINT IF EXISTS "samples_status_id_fk";
ALTER TABLE IF EXISTS "lab"."parental_samples" DROP CONSTRAINT IF EXISTS "samples_batch_id_fk";
ALTER TABLE IF EXISTS "lab"."parental_samples" DROP CONSTRAINT IF EXISTS "samples_step_id_fk";
ALTER TABLE IF EXISTS "lab"."parental_samples" DROP CONSTRAINT IF EXISTS "samples_project_id_fk";
ALTER TABLE IF EXISTS "lab"."parental_samples" DROP CONSTRAINT IF EXISTS "samples_customer_id_fk";
ALTER TABLE IF EXISTS "lab"."storage_log" DROP CONSTRAINT IF EXISTS "storage_log_sample_id_fk";
ALTER TABLE IF EXISTS "lab"."storage_log" DROP CONSTRAINT IF EXISTS "storage_log_storage_id_fk";
ALTER TABLE IF EXISTS "lab"."storage_log" DROP CONSTRAINT IF EXISTS "storage_log_person_id_fk";
ALTER TABLE IF EXISTS "lab"."fish" DROP CONSTRAINT IF EXISTS "fish_sample_id_fk";
ALTER TABLE IF EXISTS "lab"."fish" DROP CONSTRAINT IF EXISTS "fish_sampling_id_fk";
ALTER TABLE IF EXISTS "lab"."fish" DROP CONSTRAINT IF EXISTS "fish_species_id_fk";
ALTER TABLE IF EXISTS "lab"."fish" DROP CONSTRAINT IF EXISTS "fish_project_id_fk";
ALTER TABLE IF EXISTS "lab"."tissue" DROP CONSTRAINT IF EXISTS "tissue_sample_id_fk";
ALTER TABLE IF EXISTS "lab"."tissue" DROP CONSTRAINT IF EXISTS "tissue_parent_sample_id_fk";
ALTER TABLE IF EXISTS "lab"."tissue" DROP CONSTRAINT IF EXISTS "tissue_experiment_id_fk";
ALTER TABLE IF EXISTS "lab"."tissue" DROP CONSTRAINT IF EXISTS "tissue_project_id_fk";
ALTER TABLE IF EXISTS "lab"."otoliths" DROP CONSTRAINT IF EXISTS "otoliths_sample_id_fk";
ALTER TABLE IF EXISTS "lab"."otoliths" DROP CONSTRAINT IF EXISTS "otoliths_reader_person_id_fk";
ALTER TABLE IF EXISTS "lab"."otoliths" DROP CONSTRAINT IF EXISTS "otoliths_project_id_fk";
ALTER TABLE IF EXISTS "lab"."dna" DROP CONSTRAINT IF EXISTS "dna_sample_id_fk";
ALTER TABLE IF EXISTS "lab"."dna" DROP CONSTRAINT IF EXISTS "dna_parent_sample_id_fk";
ALTER TABLE IF EXISTS "lab"."dna" DROP CONSTRAINT IF EXISTS "dna_experiment_id_fk";
ALTER TABLE IF EXISTS "lab"."dna" DROP CONSTRAINT IF EXISTS "dna_project_id_fk";
ALTER TABLE IF EXISTS "lab"."rna" DROP CONSTRAINT IF EXISTS "rna_sample_id_fk";
ALTER TABLE IF EXISTS "lab"."rna" DROP CONSTRAINT IF EXISTS "rna_parent_sample_id_fk";
ALTER TABLE IF EXISTS "lab"."rna" DROP CONSTRAINT IF EXISTS "rna_experiment_id_fk";
ALTER TABLE IF EXISTS "lab"."rna" DROP CONSTRAINT IF EXISTS "rna_project_id_fk";
ALTER TABLE IF EXISTS "lab"."sediments" DROP CONSTRAINT IF EXISTS "sediments_sample_id_fk";
ALTER TABLE IF EXISTS "lab"."sediments" DROP CONSTRAINT IF EXISTS "sediments_parent_sample_id_fk";
ALTER TABLE IF EXISTS "lab"."sediments" DROP CONSTRAINT IF EXISTS "sediments_experiment_id_fk";
ALTER TABLE IF EXISTS "lab"."sediments" DROP CONSTRAINT IF EXISTS "sediments_project_id_fk";
ALTER TABLE IF EXISTS "lab"."water" DROP CONSTRAINT IF EXISTS "water_sample_id_fk";
ALTER TABLE IF EXISTS "lab"."water" DROP CONSTRAINT IF EXISTS "water_parent_sample_id_fk";
ALTER TABLE IF EXISTS "lab"."water" DROP CONSTRAINT IF EXISTS "water_experiment_id_fk";
ALTER TABLE IF EXISTS "lab"."water" DROP CONSTRAINT IF EXISTS "water_project_id_fk";
ALTER TABLE IF EXISTS "lab"."experiments_samples" DROP CONSTRAINT IF EXISTS "experiments_samples_experiment_id_fk";
ALTER TABLE IF EXISTS "lab"."experiments_samples" DROP CONSTRAINT IF EXISTS "experiments_samples_sample_id_fk";
ALTER TABLE IF EXISTS "lab"."dissections" DROP CONSTRAINT IF EXISTS "dissections_sample_id_fk";
ALTER TABLE IF EXISTS "lab"."dissections" DROP CONSTRAINT IF EXISTS "dissections_person_id_fk";
ALTER TABLE IF EXISTS "lab"."dissections" DROP CONSTRAINT IF EXISTS "dissections_status_id_fk";
ALTER TABLE IF EXISTS "lab"."nanodrop" DROP CONSTRAINT IF EXISTS "nanodrop_experiment_id_fk";
ALTER TABLE IF EXISTS "lab"."nanodrop" DROP CONSTRAINT IF EXISTS "nanodrop_sample_id_fk";
ALTER TABLE IF EXISTS "lab"."nanodrop" DROP CONSTRAINT IF EXISTS "nanodrop_concentration_unit_id_fk";
ALTER TABLE IF EXISTS "lab"."nanodrop" DROP CONSTRAINT IF EXISTS "nanodrop_person_id_fk";
ALTER TABLE IF EXISTS "lab"."nanodrop" DROP CONSTRAINT IF EXISTS "nanodrop_status_id_fk";
ALTER TABLE IF EXISTS "lab"."nanodrop" DROP CONSTRAINT IF EXISTS "nanodrop_storage_id_fk";
ALTER TABLE IF EXISTS "lab"."nanodrop" DROP CONSTRAINT IF EXISTS "nanodrop_project_id_fk";
ALTER TABLE IF EXISTS "lab"."qubit" DROP CONSTRAINT IF EXISTS "qubit_sample_id_fk";
ALTER TABLE IF EXISTS "lab"."qubit" DROP CONSTRAINT IF EXISTS "qubit_experiment_id_fk";
ALTER TABLE IF EXISTS "lab"."qubit" DROP CONSTRAINT IF EXISTS "qubit_tube_unit_id_fk";
ALTER TABLE IF EXISTS "lab"."qubit" DROP CONSTRAINT IF EXISTS "qubit_original_sample_unit_id_fk";
ALTER TABLE IF EXISTS "lab"."qubit" DROP CONSTRAINT IF EXISTS "qubit_person_id_fk";
ALTER TABLE IF EXISTS "lab"."qubit" DROP CONSTRAINT IF EXISTS "qubit_status_id_fk";
ALTER TABLE IF EXISTS "lab"."qubit" DROP CONSTRAINT IF EXISTS "qubit_storage_id_fk";
ALTER TABLE IF EXISTS "lab"."qubit" DROP CONSTRAINT IF EXISTS "qubit_project_id_fk";
ALTER TABLE IF EXISTS "lab"."tapestation" DROP CONSTRAINT IF EXISTS "tapestation_experiment_id_fk";
ALTER TABLE IF EXISTS "lab"."tapestation" DROP CONSTRAINT IF EXISTS "tapestation_person_id_fk";
ALTER TABLE IF EXISTS "lab"."tapestation" DROP CONSTRAINT IF EXISTS "tapestation_sample_id_fk";
ALTER TABLE IF EXISTS "lab"."tapestation" DROP CONSTRAINT IF EXISTS "tapestation_storage_id_fk";
ALTER TABLE IF EXISTS "lab"."tapestation" DROP CONSTRAINT IF EXISTS "tapestation_status_id_fk";
ALTER TABLE IF EXISTS "lab"."tapestation" DROP CONSTRAINT IF EXISTS "tapestation_project_id_fk";
ALTER TABLE IF EXISTS "lab"."pcr" DROP CONSTRAINT IF EXISTS "pcr_experiment_id_fk";
ALTER TABLE IF EXISTS "lab"."pcr" DROP CONSTRAINT IF EXISTS "pcr_sample_id_fk";
ALTER TABLE IF EXISTS "lab"."pcr" DROP CONSTRAINT IF EXISTS "pcr_primer_id_fk";
ALTER TABLE IF EXISTS "lab"."pcr" DROP CONSTRAINT IF EXISTS "pcr_person_id_fk";
ALTER TABLE IF EXISTS "lab"."pcr" DROP CONSTRAINT IF EXISTS "pcr_storage_id_fk";
ALTER TABLE IF EXISTS "lab"."pcr" DROP CONSTRAINT IF EXISTS "pcr_status_id_fk";
ALTER TABLE IF EXISTS "lab"."pcr" DROP CONSTRAINT IF EXISTS "pcr_project_id_fk";
ALTER TABLE IF EXISTS "lab"."gelelectrophoresis" DROP CONSTRAINT IF EXISTS "gelelectrophoresis_experiment_id_fk";
ALTER TABLE IF EXISTS "lab"."gelelectrophoresis" DROP CONSTRAINT IF EXISTS "gelelectrophoresis_sample_id_fk";
ALTER TABLE IF EXISTS "lab"."gelelectrophoresis" DROP CONSTRAINT IF EXISTS "gelelectrophoresis_person_id_fk";
ALTER TABLE IF EXISTS "lab"."gelelectrophoresis" DROP CONSTRAINT IF EXISTS "gelelectrophoresis_storage_id_fk";
ALTER TABLE IF EXISTS "lab"."gelelectrophoresis" DROP CONSTRAINT IF EXISTS "gelelectrophoresis_project_id_fk";
ALTER TABLE IF EXISTS "lab"."qpcr" DROP CONSTRAINT IF EXISTS "qpcr_experiment_id_fk";
ALTER TABLE IF EXISTS "lab"."qpcr" DROP CONSTRAINT IF EXISTS "qpcr_sample_id_fk";
ALTER TABLE IF EXISTS "lab"."qpcr" DROP CONSTRAINT IF EXISTS "qpcr_person_id_fk";
ALTER TABLE IF EXISTS "lab"."qpcr" DROP CONSTRAINT IF EXISTS "qpcr_primer_id_fk";
ALTER TABLE IF EXISTS "lab"."qpcr" DROP CONSTRAINT IF EXISTS "qpcr_storage_id_fk";
ALTER TABLE IF EXISTS "lab"."qpcr" DROP CONSTRAINT IF EXISTS "qpcr_status_id_fk";
ALTER TABLE IF EXISTS "lab"."qpcr" DROP CONSTRAINT IF EXISTS "qpcr_project_id_fk";
ALTER TABLE IF EXISTS "lab"."library" DROP CONSTRAINT IF EXISTS "library_experiment_id_fk";
ALTER TABLE IF EXISTS "lab"."library" DROP CONSTRAINT IF EXISTS "library_sample_id_fk";
ALTER TABLE IF EXISTS "lab"."library" DROP CONSTRAINT IF EXISTS "library_person_id_fk";
ALTER TABLE IF EXISTS "lab"."library" DROP CONSTRAINT IF EXISTS "library_storage_id_fk";
ALTER TABLE IF EXISTS "lab"."library" DROP CONSTRAINT IF EXISTS "library_project_id_fk";
ALTER TABLE IF EXISTS "lab"."sequencing_run" DROP CONSTRAINT IF EXISTS "sequencing_run_experiment_id_fk";
ALTER TABLE IF EXISTS "lab"."sequencing_run" DROP CONSTRAINT IF EXISTS "sequencing_run_library_id_fk";
ALTER TABLE IF EXISTS "lab"."sequencing_run" DROP CONSTRAINT IF EXISTS "sequencing_run_sample_id_fk";
ALTER TABLE IF EXISTS "lab"."sequencing_run" DROP CONSTRAINT IF EXISTS "sequencing_run_person_id_fk";
ALTER TABLE IF EXISTS "lab"."sequencing_run" DROP CONSTRAINT IF EXISTS "sequencing_run_status_id_fk";
ALTER TABLE IF EXISTS "lab"."sequencing_run" DROP CONSTRAINT IF EXISTS "sequencing_run_storage_id_fk";
ALTER TABLE IF EXISTS "lab"."sequencing_run" DROP CONSTRAINT IF EXISTS "sequencing_run_project_id_fk";
ALTER TABLE IF EXISTS "lab"."datasets" DROP CONSTRAINT IF EXISTS "datasets_ecosystem_id_fk";
ALTER TABLE IF EXISTS "lab"."datasets" DROP CONSTRAINT IF EXISTS "datasets_region_id_fk";
ALTER TABLE IF EXISTS "lab"."datasets" DROP CONSTRAINT IF EXISTS "datasets_customer_id_fk";
ALTER TABLE IF EXISTS "lab"."datasets" DROP CONSTRAINT IF EXISTS "datasets_stored_location_id_fk";
ALTER TABLE IF EXISTS "bioinformatics"."analysis_runs" DROP CONSTRAINT IF EXISTS "analysis_runs_pipeline_id_fk";
ALTER TABLE IF EXISTS "bioinformatics"."analysis_runs" DROP CONSTRAINT IF EXISTS "analysis_runs_sequencing_id_fk";
ALTER TABLE IF EXISTS "bioinformatics"."analysis_runs" DROP CONSTRAINT IF EXISTS "analysis_runs_person_id_fk";
ALTER TABLE IF EXISTS "bioinformatics"."analysis_runs" DROP CONSTRAINT IF EXISTS "analysis_runs_reference_db_id_fk";
ALTER TABLE IF EXISTS "bioinformatics"."edna_assignments" DROP CONSTRAINT IF EXISTS "edna_assignments_run_id_fk";
ALTER TABLE IF EXISTS "bioinformatics"."edna_assignments" DROP CONSTRAINT IF EXISTS "edna_assignments_sample_id_fk";
ALTER TABLE IF EXISTS "bioinformatics"."edna_assignments" DROP CONSTRAINT IF EXISTS "edna_assignments_taxon_id_fk";
ALTER TABLE IF EXISTS "projects"."ProjectWanderfische_FishingData" DROP CONSTRAINT IF EXISTS "fk_fishingdata_agency";
ALTER TABLE IF EXISTS "projects"."ProjectWanderfische_FishingData" DROP CONSTRAINT IF EXISTS "fk_fishingdata_project";
ALTER TABLE IF EXISTS "projects"."ProjectWanderfische_FishingData" DROP CONSTRAINT IF EXISTS "fk_fishingdata_salinity_unit";
ALTER TABLE IF EXISTS "projects"."ProjectWanderfische_FishingData" DROP CONSTRAINT IF EXISTS "fk_fishingdata_oxygen_unit";
ALTER TABLE IF EXISTS "projects"."ProjectWanderfische_FishingData" DROP CONSTRAINT IF EXISTS "fk_fishingdata_wind_unit";
ALTER TABLE IF EXISTS "projects"."ProjectWanderfische_FishingData" DROP CONSTRAINT IF EXISTS "fk_fishingdata_created_by";
ALTER TABLE IF EXISTS "projects"."ProjectWanderfische_FishingData" DROP CONSTRAINT IF EXISTS "fk_fishingdata_last_modified_by";
ALTER TABLE IF EXISTS "projects"."ProjectWanderfische_FishCatch" DROP CONSTRAINT IF EXISTS "fk_fishcatch_fishingdata";
ALTER TABLE IF EXISTS "projects"."ProjectWanderfische_FishCatch" DROP CONSTRAINT IF EXISTS "fk_fishcatch_taxon";
ALTER TABLE IF EXISTS "projects"."ProjectWanderfische_FishCatch" DROP CONSTRAINT IF EXISTS "fk_fishcatch_created_by";
ALTER TABLE IF EXISTS "projects"."ProjectWanderfische_FishCatch" DROP CONSTRAINT IF EXISTS "fk_fishcatch_last_modified_by";
ALTER TABLE IF EXISTS "projects"."ProjectWanderfische_Mail" DROP CONSTRAINT IF EXISTS "fk_mail_fishingdata";
ALTER TABLE IF EXISTS "projects"."ProjectWanderfische_Mail" DROP CONSTRAINT IF EXISTS "fk_mail_sender_person";
ALTER TABLE IF EXISTS "projects"."ProjectWanderfische_Mail" DROP CONSTRAINT IF EXISTS "fk_mail_recipient_contact";
ALTER TABLE IF EXISTS "projects"."ProjectWanderfische_Mail" DROP CONSTRAINT IF EXISTS "fk_mail_created_by";
ALTER TABLE IF EXISTS "projects"."ProjectWanderfische_Mail" DROP CONSTRAINT IF EXISTS "fk_mail_last_modified_by";
ALTER TABLE IF EXISTS "projects"."ProjectWanderfische_Conversation" DROP CONSTRAINT IF EXISTS "fk_conversation_fishingdata";
ALTER TABLE IF EXISTS "projects"."ProjectWanderfische_Conversation" DROP CONSTRAINT IF EXISTS "fk_conversation_created_by";
ALTER TABLE IF EXISTS "projects"."ProjectWanderfische_Conversation" DROP CONSTRAINT IF EXISTS "fk_conversation_last_modified_by";
ALTER TABLE IF EXISTS "projects"."ProjectWanderfische_ChatMessage" DROP CONSTRAINT IF EXISTS "fk_chatmessage_conversation";
ALTER TABLE IF EXISTS "projects"."ProjectWanderfische_ChatMessage" DROP CONSTRAINT IF EXISTS "fk_chatmessage_sender_person";
ALTER TABLE IF EXISTS "projects"."ProjectWanderfische_ChatMessage" DROP CONSTRAINT IF EXISTS "fk_chatmessage_sender_contact";
ALTER TABLE IF EXISTS "projects"."ProjectWanderfische_ChatMessage" DROP CONSTRAINT IF EXISTS "fk_chatmessage_created_by";
ALTER TABLE IF EXISTS "projects"."ProjectWanderfische_ChatMessage" DROP CONSTRAINT IF EXISTS "fk_chatmessage_last_modified_by";

-- Add foreign key constraints based on the updated schema
ALTER TABLE "reference"."taxon"
ADD CONSTRAINT "taxon_parent_fk" FOREIGN KEY ("taxon_parent")
REFERENCES "reference"."taxon"("taxon_id");

ALTER TABLE "lims"."projects"
ADD CONSTRAINT "projects_status_id_fk" FOREIGN KEY ("status_id")
REFERENCES "reference"."status"("status_id");

ALTER TABLE "lims"."projects"
ADD CONSTRAINT "projects_pi_person_id_fk" FOREIGN KEY ("pi_person_id")
REFERENCES "lims"."personal"("person_id");

ALTER TABLE "lims"."projects"
ADD CONSTRAINT "projects_customer_id_fk" FOREIGN KEY ("customer_id")
REFERENCES "lims"."customers"("customer_id");

ALTER TABLE "lims"."project_persons"
ADD CONSTRAINT "project_persons_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id") ON DELETE CASCADE;

ALTER TABLE "lims"."project_persons"
ADD CONSTRAINT "project_persons_person_id_fk" FOREIGN KEY ("person_id")
REFERENCES "lims"."personal"("person_id") ON DELETE CASCADE;

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
REFERENCES "lims"."personal"("person_id");

ALTER TABLE "lims"."cruises"
ADD CONSTRAINT "cruises_together_with_contact_id_fk" FOREIGN KEY ("together_with_contact_id")
REFERENCES "lims"."external_contacts"("contact_id");

ALTER TABLE "lims"."batch_steps"
ADD CONSTRAINT "batch_steps_batch_id_fk" FOREIGN KEY ("batch_id")
REFERENCES "lims"."batch"("batch_id") ON DELETE CASCADE;

ALTER TABLE "lims"."batch_steps"
ADD CONSTRAINT "batch_steps_sop_id_fk" FOREIGN KEY ("sop_id")
REFERENCES "lims"."sop"("sop_id");

ALTER TABLE "lims"."batch_steps"
ADD CONSTRAINT "batch_steps_status_id_fk" FOREIGN KEY ("status_id")
REFERENCES "reference"."status"("status_id");

ALTER TABLE "lims"."primers"
ADD CONSTRAINT "primers_target_gene_id_fk" FOREIGN KEY ("target_gene_id")
REFERENCES "reference"."gene"("gene_id");

ALTER TABLE "lims"."sop"
ADD CONSTRAINT "sop_author_person_id_fk" FOREIGN KEY ("author_person_id")
REFERENCES "lims"."personal"("person_id");

ALTER TABLE "lims"."sop"
ADD CONSTRAINT "sop_reviewer1_person_id_fk" FOREIGN KEY ("reviewer1_person_id")
REFERENCES "lims"."personal"("person_id");

ALTER TABLE "lims"."sop"
ADD CONSTRAINT "sop_reviewer2_person_id_fk" FOREIGN KEY ("reviewer2_person_id")
REFERENCES "lims"."personal"("person_id");

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
REFERENCES "lims"."personal"("person_id");

ALTER TABLE "lims"."publications"
ADD CONSTRAINT "publications_corresponding_author_person_id_fk" FOREIGN KEY ("corresponding_author_person_id")
REFERENCES "lims"."personal"("person_id");

ALTER TABLE "lab"."storage"
ADD CONSTRAINT "storage_room_id_fk" FOREIGN KEY ("room_id")
REFERENCES "reference"."room"("room_id");

ALTER TABLE "lab"."storage"
ADD CONSTRAINT "storage_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id");


-- 220.
-- Add the foreign key constraint referencing the composite key on lab.experiments
ALTER TABLE "lab"."experiments_projects"
ADD CONSTRAINT "experiments_projects_experiment_id_fk" FOREIGN KEY ("experiment_id", "experiment_date")
REFERENCES "lab"."experiments"("experiment_id", "experiment_date") ON DELETE CASCADE;
--  Re-add the foreign key for projects
ALTER TABLE "lab"."experiments_projects"
ADD CONSTRAINT "experiments_projects_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id") ON DELETE CASCADE;


ALTER TABLE "lab"."protocol_runs"
ADD CONSTRAINT "protocol_runs_experiment_id_fk" FOREIGN KEY ("experiment_id")
REFERENCES "lab"."experiments"("experiment_id");

ALTER TABLE "lab"."sampling"
ADD CONSTRAINT "sampling_experiment_id_fk" FOREIGN KEY ("experiment_id", "experiment_date")
REFERENCES "lab"."experiments"("experiment_id", "experiment_date");

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

-- Note: The following FK references a composite key to a partitioned table
ALTER TABLE "lab"."fishing"
ADD CONSTRAINT "fishing_sampling_id_fk" FOREIGN KEY ("sampling_id", "sampling_date")
REFERENCES "lab"."sampling"("sampling_id", "sampling_date") ON DELETE CASCADE;

ALTER TABLE "lab"."fishing"
ADD CONSTRAINT "fishing_taxon_id_fk" FOREIGN KEY ("taxon_id")
REFERENCES "reference"."taxon"("taxon_id");

ALTER TABLE "lab"."fishing"
ADD CONSTRAINT "fishing_customer_id_fk" FOREIGN KEY ("customer_id")
REFERENCES "lims"."customers"("customer_id");

ALTER TABLE "lab"."parental_samples"
ADD CONSTRAINT "samples_master_sample_id_fk" FOREIGN KEY ("sample_id")
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."parental_samples"
ADD CONSTRAINT "samples_parent_sample_id_fk" FOREIGN KEY ("parent_sample_id")
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."parental_samples"
ADD CONSTRAINT "samples_sampling_id_fk" FOREIGN KEY ("sampling_id", "sampling_date")
REFERENCES "lab"."sampling"("sampling_id", "sampling_date");

ALTER TABLE "lab"."parental_samples"
ADD CONSTRAINT "samples_storage_id_fk" FOREIGN KEY ("storage_id")
REFERENCES "lab"."storage"("storage_id");

ALTER TABLE "lab"."parental_samples"
ADD CONSTRAINT "samples_sampler_person_id_fk" FOREIGN KEY ("sampler_person_id")
REFERENCES "lims"."personal"("person_id");

ALTER TABLE "lab"."parental_samples"
ADD CONSTRAINT "samples_receiver_person_id_fk" FOREIGN KEY ("receiver_person_id")
REFERENCES "lims"."personal"("person_id");

ALTER TABLE "lab"."parental_samples"
ADD CONSTRAINT "samples_sample_type_id_fk" FOREIGN KEY ("sample_type_id")
REFERENCES "reference"."samples_type"("sample_type_id");

ALTER TABLE "lab"."parental_samples"
ADD CONSTRAINT "samples_status_id_fk" FOREIGN KEY ("status_id")
REFERENCES "reference"."status"("status_id");

ALTER TABLE "lab"."parental_samples"
ADD CONSTRAINT "samples_batch_id_fk" FOREIGN KEY ("batch_id")
REFERENCES "lims"."batch"("batch_id");

ALTER TABLE "lab"."parental_samples"
ADD CONSTRAINT "samples_step_id_fk" FOREIGN KEY ("step_id")
REFERENCES "lims"."batch_steps"("step_id");

ALTER TABLE "lab"."parental_samples"
ADD CONSTRAINT "samples_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id");

ALTER TABLE "lab"."parental_samples"
ADD CONSTRAINT "samples_customer_id_fk" FOREIGN KEY ("customer_id")
REFERENCES "lims"."customers"("customer_id");

ALTER TABLE "lab"."storage_log"
ADD CONSTRAINT "storage_log_sample_id_fk" FOREIGN KEY ("sample_id")
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."storage_log"
ADD CONSTRAINT "storage_log_storage_id_fk" FOREIGN KEY ("storage_id")
REFERENCES "lab"."storage"("storage_id");

ALTER TABLE "lab"."storage_log"
ADD CONSTRAINT "storage_log_person_id_fk" FOREIGN KEY ("person_id")
REFERENCES "lims"."personal"("person_id");

-- Note: The following FK references a composite key to a partitioned table
ALTER TABLE "lab"."fish"
ADD CONSTRAINT "fish_sampling_id_fk" FOREIGN KEY ("sampling_id", "sampling_date")
REFERENCES "lab"."sampling"("sampling_id", "sampling_date");

ALTER TABLE "lab"."fish"
ADD CONSTRAINT "fish_species_id_fk" FOREIGN KEY ("species_id")
REFERENCES "reference"."taxon"("taxon_id");

ALTER TABLE "lab"."fish"
ADD CONSTRAINT "fish_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id");

-- Note: The following FK references a composite key to a partitioned table
ALTER TABLE "lab"."tissue"
ADD CONSTRAINT "tissue_experiment_id_fk" FOREIGN KEY ("experiment_id", "experiment_date")
REFERENCES "lab"."experiments"("experiment_id", "experiment_date");

ALTER TABLE "lab"."tissue"
ADD CONSTRAINT "tissue_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id");

-- Note: The following FK references a composite key to a partitioned table
ALTER TABLE "lab"."otoliths"
ADD CONSTRAINT "otoliths_experiment_id_fk" FOREIGN KEY ("experiment_id", "experiment_date")
REFERENCES "lab"."experiments"("experiment_id", "experiment_date");

ALTER TABLE "lab"."otoliths"
ADD CONSTRAINT "otoliths_reader_person_id_fk" FOREIGN KEY ("reader_person_id")
REFERENCES "lims"."personal"("person_id");

ALTER TABLE "lab"."otoliths"
ADD CONSTRAINT "otoliths_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id");

-- Note: The following FK references a composite key to a partitioned table
ALTER TABLE "lab"."dna"
ADD CONSTRAINT "dna_experiment_id_fk" FOREIGN KEY ("experiment_id", "experiment_date")
REFERENCES "lab"."experiments"("experiment_id", "experiment_date");

ALTER TABLE "lab"."dna"
ADD CONSTRAINT "dna_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id");

-- Note: The following FK references a composite key to a partitioned table
ALTER TABLE "lab"."rna"
ADD CONSTRAINT "rna_experiment_id_fk" FOREIGN KEY ("experiment_id", "experiment_date")
REFERENCES "lab"."experiments"("experiment_id", "experiment_date");

ALTER TABLE "lab"."rna"
ADD CONSTRAINT "rna_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id");

-- Note: The following FK references a composite key to a partitioned table
ALTER TABLE "lab"."sediments"
ADD CONSTRAINT "sediments_experiment_id_fk" FOREIGN KEY ("experiment_id", "experiment_date")
REFERENCES "lab"."experiments"("experiment_id", "experiment_date");

ALTER TABLE "lab"."sediments"
ADD CONSTRAINT "sediments_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id");

-- Note: The following FK references a composite key to a partitioned table
ALTER TABLE "lab"."water"
ADD CONSTRAINT "water_experiment_id_fk" FOREIGN KEY ("experiment_id", "experiment_date")
REFERENCES "lab"."experiments"("experiment_id", "experiment_date");

ALTER TABLE "lab"."water"
ADD CONSTRAINT "water_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id");

-- Note: The following FK references a composite key to a partitioned table
ALTER TABLE "lab"."experiments_samples"
ADD CONSTRAINT "experiments_samples_experiment_id_fk" FOREIGN KEY ("experiment_id", "experiment_date")
REFERENCES "lab"."experiments"("experiment_id", "experiment_date") ON DELETE CASCADE;

ALTER TABLE "lab"."experiments_samples"
ADD CONSTRAINT "experiments_samples_sample_id_fk" FOREIGN KEY ("sample_id")
REFERENCES "lab"."master_samples"("sample_id") ON DELETE CASCADE;

-- Note: The following FK references a composite key to a partitioned table
ALTER TABLE "lab"."dissections"
ADD CONSTRAINT "dissections_experiment_id_fk" FOREIGN KEY ("experiment_id", "experiment_date")
REFERENCES "lab"."experiments"("experiment_id", "experiment_date");

ALTER TABLE "lab"."dissections"
ADD CONSTRAINT "dissections_person_id_fk" FOREIGN KEY ("person_id")
REFERENCES "lims"."personal"("person_id");

ALTER TABLE "lab"."dissections"
ADD CONSTRAINT "dissections_status_id_fk" FOREIGN KEY ("status_id")
REFERENCES "reference"."status"("status_id");

-- Note: The following FK references a composite key to a partitioned table
ALTER TABLE "lab"."nanodrop"
ADD CONSTRAINT "nanodrop_experiment_id_fk" FOREIGN KEY ("experiment_id", "experiment_date")
REFERENCES "lab"."experiments"("experiment_id", "experiment_date");

ALTER TABLE "lab"."nanodrop"
ADD CONSTRAINT "nanodrop_sample_id_fk" FOREIGN KEY ("sample_id")
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."nanodrop"
ADD CONSTRAINT "nanodrop_concentration_unit_id_fk" FOREIGN KEY ("concentration_unit_id")
REFERENCES "reference"."units"("unit_id");

ALTER TABLE "lab"."nanodrop"
ADD CONSTRAINT "nanodrop_person_id_fk" FOREIGN KEY ("person_id")
REFERENCES "lims"."personal"("person_id");

ALTER TABLE "lab"."nanodrop"
ADD CONSTRAINT "nanodrop_status_id_fk" FOREIGN KEY ("status_id")
REFERENCES "reference"."status"("status_id");

ALTER TABLE "lab"."nanodrop"
ADD CONSTRAINT "nanodrop_storage_id_fk" FOREIGN KEY ("storage_id")
REFERENCES "lab"."storage"("storage_id");

ALTER TABLE "lab"."nanodrop"
ADD CONSTRAINT "nanodrop_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id");

-- Note: The following FK references a composite key to a partitioned table
ALTER TABLE "lab"."qubit"
ADD CONSTRAINT "qubit_experiment_id_fk" FOREIGN KEY ("experiment_id", "experiment_date")
REFERENCES "lab"."experiments"("experiment_id", "experiment_date");

ALTER TABLE "lab"."qubit"
ADD CONSTRAINT "qubit_sample_id_fk" FOREIGN KEY ("sample_id")
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."qubit"
ADD CONSTRAINT "qubit_tube_unit_id_fk" FOREIGN KEY ("tube_unit_id")
REFERENCES "reference"."units"("unit_id");

ALTER TABLE "lab"."qubit"
ADD CONSTRAINT "qubit_original_sample_unit_id_fk" FOREIGN KEY ("original_sample_unit_id")
REFERENCES "reference"."units"("unit_id");

ALTER TABLE "lab"."qubit"
ADD CONSTRAINT "qubit_person_id_fk" FOREIGN KEY ("person_id")
REFERENCES "lims"."personal"("person_id");

ALTER TABLE "lab"."qubit"
ADD CONSTRAINT "qubit_status_id_fk" FOREIGN KEY ("status_id")
REFERENCES "reference"."status"("status_id");

ALTER TABLE "lab"."qubit"
ADD CONSTRAINT "qubit_storage_id_fk" FOREIGN KEY ("storage_id")
REFERENCES "lab"."storage"("storage_id");

ALTER TABLE "lab"."qubit"
ADD CONSTRAINT "qubit_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id");

-- Note: The following FK references a composite key to a partitioned table
ALTER TABLE "lab"."tapestation"
ADD CONSTRAINT "tapestation_experiment_id_fk" FOREIGN KEY ("experiment_id", "experiment_date")
REFERENCES "lab"."experiments"("experiment_id", "experiment_date");

ALTER TABLE "lab"."tapestation"
ADD CONSTRAINT "tapestation_person_id_fk" FOREIGN KEY ("person_id")
REFERENCES "lims"."personal"("person_id");

ALTER TABLE "lab"."tapestation"
ADD CONSTRAINT "tapestation_sample_id_fk" FOREIGN KEY ("sample_id")
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

-- Note: The following FK references a composite key to a partitioned table
ALTER TABLE "lab"."pcr"
ADD CONSTRAINT "pcr_experiment_id_fk" FOREIGN KEY ("experiment_id", "experiment_date")
REFERENCES "lab"."experiments"("experiment_id", "experiment_date");

ALTER TABLE "lab"."pcr"
ADD CONSTRAINT "pcr_sample_id_fk" FOREIGN KEY ("sample_id")
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."pcr"
ADD CONSTRAINT "pcr_primer_id_fk" FOREIGN KEY ("primer_id")
REFERENCES "lims"."primers"("primer_id");

ALTER TABLE "lab"."pcr"
ADD CONSTRAINT "pcr_person_id_fk" FOREIGN KEY ("person_id")
REFERENCES "lims"."personal"("person_id");

ALTER TABLE "lab"."pcr"
ADD CONSTRAINT "pcr_storage_id_fk" FOREIGN KEY ("storage_id")
REFERENCES "lab"."storage"("storage_id");

ALTER TABLE "lab"."pcr"
ADD CONSTRAINT "pcr_status_id_fk" FOREIGN KEY ("status_id")
REFERENCES "reference"."status"("status_id");

ALTER TABLE "lab"."pcr"
ADD CONSTRAINT "pcr_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id");

-- Note: The following FK references a composite key to a partitioned table
ALTER TABLE "lab"."gelelectrophoresis"
ADD CONSTRAINT "gelelectrophoresis_experiment_id_fk" FOREIGN KEY ("experiment_id", "experiment_date")
REFERENCES "lab"."experiments"("experiment_id", "experiment_date");

ALTER TABLE "lab"."gelelectrophoresis"
ADD CONSTRAINT "gelelectrophoresis_sample_id_fk" FOREIGN KEY ("sample_id")
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."gelelectrophoresis"
ADD CONSTRAINT "gelelectrophoresis_person_id_fk" FOREIGN KEY ("person_id")
REFERENCES "lims"."personal"("person_id");

ALTER TABLE "lab"."gelelectrophoresis"
ADD CONSTRAINT "gelelectrophoresis_storage_id_fk" FOREIGN KEY ("storage_id")
REFERENCES "lab"."storage"("storage_id");

ALTER TABLE "lab"."gelelectrophoresis"
ADD CONSTRAINT "gelelectrophoresis_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id");

-- Note: The following FK references a composite key to a partitioned table
ALTER TABLE "lab"."qpcr"
ADD CONSTRAINT "qpcr_experiment_id_fk" FOREIGN KEY ("experiment_id", "experiment_date")
REFERENCES "lab"."experiments"("experiment_id", "experiment_date");

ALTER TABLE "lab"."qpcr"
ADD CONSTRAINT "qpcr_sample_id_fk" FOREIGN KEY ("sample_id")
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."qpcr"
ADD CONSTRAINT "qpcr_person_id_fk" FOREIGN KEY ("person_id")
REFERENCES "lims"."personal"("person_id");

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

-- Note: The following FK references a composite key to a partitioned table
ALTER TABLE "lab"."library"
ADD CONSTRAINT "library_experiment_id_fk" FOREIGN KEY ("experiment_id", "experiment_date")
REFERENCES "lab"."experiments"("experiment_id", "experiment_date");

ALTER TABLE "lab"."library"
ADD CONSTRAINT "library_sample_id_fk" FOREIGN KEY ("sample_id")
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."library"
ADD CONSTRAINT "library_person_id_fk" FOREIGN KEY ("person_id")
REFERENCES "lims"."personal"("person_id");

ALTER TABLE "lab"."library"
ADD CONSTRAINT "library_storage_id_fk" FOREIGN KEY ("storage_id")
REFERENCES "lab"."storage"("storage_id");

ALTER TABLE "lab"."library"
ADD CONSTRAINT "library_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id");

-- Note: The following FKs reference composite keys to partitioned tables
ALTER TABLE "lab"."sequencing_run"
ADD CONSTRAINT "sequencing_run_experiment_id_fk" FOREIGN KEY ("experiment_id", "experiment_date")
REFERENCES "lab"."experiments"("experiment_id", "experiment_date");

ALTER TABLE "lab"."sequencing_run"
ADD CONSTRAINT "sequencing_run_library_id_fk" FOREIGN KEY ("library_id", "prep_date")
REFERENCES "lab"."library"("library_id", "prep_date");

ALTER TABLE "lab"."sequencing_run"
ADD CONSTRAINT "sequencing_run_sample_id_fk" FOREIGN KEY ("sample_id")
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."sequencing_run"
ADD CONSTRAINT "sequencing_run_person_id_fk" FOREIGN KEY ("person_id")
REFERENCES "lims"."personal"("person_id");

ALTER TABLE "lab"."sequencing_run"
ADD CONSTRAINT "sequencing_run_status_id_fk" FOREIGN KEY ("status_id")
REFERENCES "reference"."status"("status_id");

ALTER TABLE "lab"."sequencing_run"
ADD CONSTRAINT "sequencing_run_storage_id_fk" FOREIGN KEY ("storage_id")
REFERENCES "lab"."storage"("storage_id");

ALTER TABLE "lab"."sequencing_run"
ADD CONSTRAINT "sequencing_run_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id");

-- Note: The following FK references a composite key to a partitioned table
ALTER TABLE "lab"."datasets"
ADD CONSTRAINT "datasets_experiment_id_fk" FOREIGN KEY ("experiment_id", "experiment_date")
REFERENCES "lab"."experiments"("experiment_id", "experiment_date");

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

-- Note: The following FK references a composite key to a partitioned table
ALTER TABLE "bioinformatics"."analysis_runs"
ADD CONSTRAINT "analysis_runs_sequencing_id_fk" FOREIGN KEY ("sequencing_id", "sequencing_date")
REFERENCES "lab"."sequencing_run"("sequencing_run_id", "sequencing_date");

ALTER TABLE "bioinformatics"."analysis_runs"
ADD CONSTRAINT "analysis_runs_pipeline_id_fk" FOREIGN KEY ("pipeline_id")
REFERENCES "bioinformatics"."analysis_pipelines"("pipeline_id");

ALTER TABLE "bioinformatics"."analysis_runs"
ADD CONSTRAINT "analysis_runs_person_id_fk" FOREIGN KEY ("person_id")
REFERENCES "lims"."personal"("person_id");

ALTER TABLE "bioinformatics"."analysis_runs"
ADD CONSTRAINT "analysis_runs_reference_db_id_fk" FOREIGN KEY ("reference_db_id")
REFERENCES "bioinformatics"."reference_databases"("db_id");

-- Note: The following FK references a composite key to a partitioned table
ALTER TABLE "bioinformatics"."edna_assignments"
ADD CONSTRAINT "edna_assignments_run_id_fk" FOREIGN KEY ("run_id", "run_date")
REFERENCES "bioinformatics"."analysis_runs"("run_id", "run_date");

ALTER TABLE "bioinformatics"."edna_assignments"
ADD CONSTRAINT "edna_assignments_sample_id_fk" FOREIGN KEY ("sample_id")
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "bioinformatics"."edna_assignments"
ADD CONSTRAINT "edna_assignments_taxon_id_fk" FOREIGN KEY ("taxon_id")
REFERENCES "reference"."taxon"("taxon_id");

-- Note: The following FK references a composite key to a partitioned table
ALTER TABLE "projects"."ProjectWanderfische_FishingData"
ADD CONSTRAINT "fk_fishingdata_project" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id") ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE "projects"."ProjectWanderfische_FishingData"
ADD CONSTRAINT "fk_fishingdata_salinity_unit" FOREIGN KEY ("salinity_unit_id")
REFERENCES "reference"."units"("unit_id") ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE "projects"."ProjectWanderfische_FishingData"
ADD CONSTRAINT "fk_fishingdata_oxygen_unit" FOREIGN KEY ("oxygen_unit_id")
REFERENCES "reference"."units"("unit_id") ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE "projects"."ProjectWanderfische_FishingData"
ADD CONSTRAINT "fk_fishingdata_wind_unit" FOREIGN KEY ("wind_unit_id")
REFERENCES "reference"."units"("unit_id") ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE "projects"."ProjectWanderfische_FishingData"
ADD CONSTRAINT "fk_fishingdata_created_by" FOREIGN KEY ("created_by")
REFERENCES "lims"."personal"("person_id") ON UPDATE CASCADE ON DELETE SET NULL;

ALTER TABLE "projects"."ProjectWanderfische_FishingData"
ADD CONSTRAINT "fk_fishingdata_last_modified_by" FOREIGN KEY ("last_modified_by")
REFERENCES "lims"."personal"("person_id") ON UPDATE CASCADE ON DELETE SET NULL;

-- Note: The following FK references a composite key to a partitioned table
ALTER TABLE "projects"."ProjectWanderfische_FishCatch"
ADD CONSTRAINT "fk_fishcatch_fishingdata" FOREIGN KEY ("fishing_record_id", "fishing_record_date")
REFERENCES "projects"."ProjectWanderfische_FishingData"("fishing_record_id", "record_date") ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE "projects"."ProjectWanderfische_FishCatch"
ADD CONSTRAINT "fk_fishcatch_taxon" FOREIGN KEY ("taxon_id")
REFERENCES "reference"."taxon"("taxon_id") ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE "projects"."ProjectWanderfische_FishCatch"
ADD CONSTRAINT "fk_fishcatch_created_by" FOREIGN KEY ("created_by")
REFERENCES "lims"."personal"("person_id") ON UPDATE CASCADE ON DELETE SET NULL;

ALTER TABLE "projects"."ProjectWanderfische_FishCatch"
ADD CONSTRAINT "fk_fishcatch_last_modified_by" FOREIGN KEY ("last_modified_by")
REFERENCES "lims"."personal"("person_id") ON UPDATE CASCADE ON DELETE SET NULL;

-- Note: The following FK references a composite key to a partitioned table
ALTER TABLE "projects"."ProjectWanderfische_Mail"
ADD CONSTRAINT "fk_mail_fishingdata" FOREIGN KEY ("fishing_record_id", "fishing_record_date")
REFERENCES "projects"."ProjectWanderfische_FishingData"("fishing_record_id", "record_date") ON UPDATE CASCADE ON DELETE SET NULL;

ALTER TABLE "projects"."ProjectWanderfische_Mail"
ADD CONSTRAINT "fk_mail_sender_person" FOREIGN KEY ("sender_person_id")
REFERENCES "lims"."personal"("person_id") ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE "projects"."ProjectWanderfische_Mail"
ADD CONSTRAINT "fk_mail_recipient_contact" FOREIGN KEY ("recipient_contact_id")
REFERENCES "lims"."external_contacts"("contact_id") ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE "projects"."ProjectWanderfische_Mail"
ADD CONSTRAINT "fk_mail_created_by" FOREIGN KEY ("created_by")
REFERENCES "lims"."personal"("person_id") ON UPDATE CASCADE ON DELETE SET NULL;

ALTER TABLE "projects"."ProjectWanderfische_Mail"
ADD CONSTRAINT "fk_mail_last_modified_by" FOREIGN KEY ("last_modified_by")
REFERENCES "lims"."personal"("person_id") ON UPDATE CASCADE ON DELETE SET NULL;

-- Note: The following FK references a composite key to a partitioned table
ALTER TABLE "projects"."ProjectWanderfische_Conversation"
ADD CONSTRAINT "fk_conversation_fishingdata" FOREIGN KEY ("fishing_record_id", "fishing_record_date")
REFERENCES "projects"."ProjectWanderfische_FishingData"("fishing_record_id", "record_date") ON UPDATE CASCADE ON DELETE SET NULL;

ALTER TABLE "projects"."ProjectWanderfische_Conversation"
ADD CONSTRAINT "fk_conversation_created_by" FOREIGN KEY ("created_by")
REFERENCES "lims"."personal"("person_id") ON UPDATE CASCADE ON DELETE SET NULL;

ALTER TABLE "projects"."ProjectWanderfische_Conversation"
ADD CONSTRAINT "fk_conversation_last_modified_by" FOREIGN KEY ("last_modified_by")
REFERENCES "lims"."personal"("person_id") ON UPDATE CASCADE ON DELETE SET NULL;

ALTER TABLE "projects"."ProjectWanderfische_ChatMessage"
ADD CONSTRAINT "fk_chatmessage_conversation" FOREIGN KEY ("conversation_id")
REFERENCES "projects"."ProjectWanderfische_Conversation"("conversation_id") ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE "projects"."ProjectWanderfische_ChatMessage"
ADD CONSTRAINT "fk_chatmessage_sender_person" FOREIGN KEY ("sender_person_id")
REFERENCES "lims"."personal"("person_id") ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE "projects"."ProjectWanderfische_ChatMessage"
ADD CONSTRAINT "fk_chatmessage_sender_contact" FOREIGN KEY ("sender_contact_id")
REFERENCES "lims"."external_contacts"("contact_id") ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE "projects"."ProjectWanderfische_ChatMessage"
ADD CONSTRAINT "fk_chatmessage_created_by" FOREIGN KEY ("created_by")
REFERENCES "lims"."personal"("person_id") ON UPDATE CASCADE ON DELETE SET NULL;

ALTER TABLE "projects"."ProjectWanderfische_ChatMessage"
ADD CONSTRAINT "fk_chatmessage_last_modified_by" FOREIGN KEY ("last_modified_by")
REFERENCES "lims"."personal"("person_id") ON UPDATE CASCADE ON DELETE SET NULL;