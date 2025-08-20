-- =======================
-- 0. Pre-Cleanup
-- =======================
DROP DATABASE IF EXISTS "MyLims";

DROP SCHEMA IF EXISTS "lab" CASCADE;
DROP SCHEMA IF EXISTS "lims" CASCADE;
DROP SCHEMA IF EXISTS "reference" CASCADE;
DROP SCHEMA IF EXISTS "bioinformatics" CASCADE;
DROP SCHEMA IF EXISTS "audit" CASCADE;

-- =======================
-- 1. Extensions
-- =======================
DROP EXTENSION IF EXISTS "uuid-ossp";
DROP EXTENSION IF EXISTS pg_trgm;
DROP EXTENSION IF EXISTS postgres_fdw;
DROP EXTENSION IF EXISTS hstore;
DROP EXTENSION IF EXISTS tablefunc;
DROP EXTENSION IF EXISTS ltree;
-- DROP EXTENSION IF NOT EXISTS postgis;

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS postgres_fdw;
CREATE EXTENSION IF NOT EXISTS hstore;
CREATE EXTENSION IF NOT EXISTS tablefunc;
CREATE EXTENSION IF NOT EXISTS ltree;
CREATE EXTENSION IF NOT EXISTS postgis;

-- =======================
-- 2. Schema Creation
-- =======================
CREATE SCHEMA IF NOT EXISTS "lab";
CREATE SCHEMA IF NOT EXISTS "lims";
CREATE SCHEMA IF NOT EXISTS "reference";
CREATE SCHEMA IF NOT EXISTS "bioinformatics";
CREATE SCHEMA IF NOT EXISTS "audit";
CREATE SCHEMA IF NOT EXISTS "projects";

-- =======================
-- 3. Audit Log Table
-- =======================

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

-- =======================
-- 4. Reference Schema Tables
-- =======================

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
    "country" text,
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
    "parent_region" text,
    "rank" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
    "path" ltree
);

CREATE TABLE IF NOT EXISTS "reference"."ecosystem" (
    "ecosystem_id" text PRIMARY KEY,
    "ecosystem_abrv" text UNIQUE NOT NULL,
    "country" text,
    "category" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
    "path" ltree
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
    "rank" text,
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
    "max_length_mm" numeric,
    "max_age_years" numeric,
    "rank" text,
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
    "parent_unit_id" text REFERENCES "reference"."units"("unit_id"),
    "conversion_factor_to_parent" numeric    
);

CREATE TABLE IF NOT EXISTS "reference"."reference_databases" (
    "db_id" serial PRIMARY KEY,
    "db_name" text NOT NULL,
    "db_version" text,
    "notes" text,
    "url" text,
    "path" text,
    "last_updated_date" date,
    "attachment" bytea,
    "attachment_link" text
);


-- ======================================================================
-- 5. Lims Schema Tables
-- ======================================================================

CREATE TABLE IF NOT EXISTS "lims"."personal" (
    "person_id" text PRIMARY KEY,
    "salutation" text,
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
    "salutation" text,
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
    "salutation" text,
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
    "contact_finance" text,
    "contact_funder" text,
    "description" text,
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
    "address" text,
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
    "project_id" text, --akronym
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
    "experiment_date" date NOT NULL,
    "aim" text,
    "method" text, -- short description only to make easy to upload Peggy Table
    "sop_id" text,
    "person_id" text,
    "notes" text,
    "lab_book" text,
    "status_id" text,
    "attachment" bytea,
    "attachment_link" text ,
    PRIMARY KEY ("experiment_id", "experiment_date")
) PARTITION BY RANGE ("experiment_date");

CREATE TABLE IF NOT EXISTS "lab"."experiments_projects" (
    "experiment_id" text NOT NULL,
    "experiment_date" date NOT NULL, 
    "project_id" text NOT NULL,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
    PRIMARY KEY ("experiment_id", "project_id", "experiment_date")
);

CREATE TABLE IF NOT EXISTS "lab"."experiments_samples" (
    "experiment_id" text NOT NULL,
    "experiment_date" date NOT NULL, 
    "sample_id" text NOT NULL,
    "sample_creation_date" date NOT NULL,
    "notes" text,
    PRIMARY KEY ("experiment_id", "experiment_date", "sample_id", "sample_creation_date")
);


CREATE TABLE IF NOT EXISTS "lab"."protocol_runs" (
    "protocol_run_id" serial PRIMARY KEY,
    "experiment_id" text NOT NULL,
    "experiment_date" date NOT NULL,
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
    "External_sampling_id" text,
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
    "done_by" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
	PRIMARY KEY ("fishing_id","sampling_date")
) PARTITION BY RANGE ("sampling_date");

CREATE TABLE IF NOT EXISTS "lab"."individual_catch_catch" (
    "individual_catch_id" serial NOT NULL, -- catch fish id fishing_id_if000
    "fishing_id" text NOT NULL,
    "sampling_date" date NOT NULL,
    "taxon_id" text NOT NULL,
    "SL_mm" numeric,
    "total_length_mm" numeric,
    "weight_g" numeric,
    "sex" text CHECK ("sex" IN ('Male', 'Female', 'Undetermined', NULL)),
    "maturity_stage" text,
    "done_by" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
    PRIMARY KEY ("individual_catch_id", "sampling_date")
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

CREATE TABLE "lab"."root_samples" (
    "sample_id" text NOT NULL, -- S99Pprj_999
    "sample_type_id" text NOT NULL,
    "external_name" text,
    "parent_sample_id" text,
    "root_sample_id" text,
    "project_id" text,
    "customer_id" integer,
    "sample_creation_date" date NOT NULL,
    "sampling_id" text,
    "sampling_date" date,
	"experiment_id" text,
    "experiment_date" date,
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
	PRIMARY KEY("sample_id","sample_creation_date")
) PARTITION BY RANGE ("sample_creation_date");



CREATE TABLE IF NOT EXISTS "lab"."fish" (
    "sample_id" text NOT NULL, -- S99Pprj_999f1
    "sample_creation_date" date NOT NULL,
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
    PRIMARY KEY ("sample_id","sample_creation_date")
) PARTITION BY RANGE ("sample_creation_date");

ALTER TABLE "lab"."fish" ADD CONSTRAINT chk_fish_sex_enum CHECK ("sex" IN ('Male', 'Female', 'Undetermined', NULL));

CREATE TABLE IF NOT EXISTS "lab"."tissue" (
    "sample_id" text NOT NULL, -- S99Pprj_999t1
    "sample_creation_date" date NOT NULL,
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
	PRIMARY KEY ("sample_id","sample_creation_date")
) PARTITION BY RANGE ("sample_creation_date");



CREATE TABLE IF NOT EXISTS "lab"."otoliths" (
    "otolith_id" text NOT NULL, --- S99Pprj_999o1
    "parent_sample_id" text,
    "root_sample_id" text,
    "sample_creation_date" date NOT NULL,
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
) PARTITION BY RANGE ("sample_creation_date");

ALTER TABLE "lab"."otoliths" ADD PRIMARY KEY ("otolith_id", "reader_person_id","side","sample_creation_date");



CREATE TABLE IF NOT EXISTS "lab"."dna" (
    "sample_id" text NOT NULL, -- S99Pprj_999d1
    "sample_creation_date" date NOT NULL,
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
	PRIMARY KEY ("sample_id","sample_creation_date")
) PARTITION BY RANGE ("sample_creation_date");



CREATE TABLE IF NOT EXISTS "lab"."rna" (
    "sample_id" text NOT NULL, -- S99Pprj_999r1
    "sample_creation_date" date NOT NULL,
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
	PRIMARY KEY ("sample_id","sample_creation_date")
) PARTITION BY RANGE ("sample_creation_date");


CREATE TABLE IF NOT EXISTS "lab"."sediments" (
    "sample_id" text NOT NULL, -- S99Pprj_999s1
    "sample_creation_date" date NOT NULL,
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
	PRIMARY KEY ("sample_id","sample_creation_date")
) PARTITION BY RANGE ("sample_creation_date");

CREATE TABLE IF NOT EXISTS "lab"."water" (
    "sample_id" text NOT NULL, -- S99Pprj_999w1
    "sample_creation_date" date NOT NULL,
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
	PRIMARY KEY ("sample_id", "sample_creation_date")
) PARTITION BY RANGE ("sample_creation_date");

CREATE TABLE IF NOT EXISTS "lab"."pcr" (
    "sample_id" text NOT NULL, -- S99Pprj_999w1
    "sample_creation_date" date NOT NULL,
    "position" text,
    "primer_id" text,
    "pcr_blank_id" text,
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
    PRIMARY KEY ("sample_id","sample_creation_date")
) PARTITION BY RANGE ("sample_creation_date");

-- --------------------
-- --------------------

CREATE TABLE IF NOT EXISTS "lab"."dissections" (
    "dissection_id" text NOT NULL, -- S99Pprj_999f1_d1
    "person_id" text NOT NULL,
    "sample_id" text NOT NULL,
    "sample_creation_date" date NOT NULL,
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
    PRIMARY KEY ("dissection_id","experiment_date")
) PARTITION BY RANGE ("experiment_date");


CREATE TABLE IF NOT EXISTS "lab"."nanodrop" (
    "nanopore_id" text NOT NULL, -- S99Pprj_999t1_n9
    "sample_id" text NOT NULL, 
    "sample_creation_date" date NOT NULL,
    "experiment_id" text,
    "experiment_date" date,
    "nanodrop_concentration" numeric,
    "concentration_unit_id" text,
    "a260" numeric,
    "a260_280" numeric,
    "a260_280_note" text,
    "a260_230" numeric,
    "a260_230_note" text,
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
    PRIMARY KEY ("nanopore_id","experiment_date")
) PARTITION BY RANGE ("experiment_date");

CREATE TABLE IF NOT EXISTS "lab"."qubit" (
    "qubit_id" text NOT NULL, -- S99Pprj_999t1_q9
    "sample_id" text,
    "sample_creation_date" date NOT NULL,
    "experiment_id" text,
    "experiment_date" date,
    "run_id" text,
    "assay_kit" text,
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
    PRIMARY KEY ("qubit_id","experiment_date")
) PARTITION BY RANGE ("experiment_date");

CREATE TABLE IF NOT EXISTS "lab"."tapestation" (
    "tapestation_id" text NOT NULL, -- S99Pprj_999t1_t9
    "sample_id" text,
    "sample_creation_date" date NOT NULL,
    "experiment_id" text,
    "experiment_date" date,
    "position" text,
    "kit" text,
    "person_id" text,
    "notes" text,
    "storage_id" text,
    "storage_position" text,
    "status_id" text,
    "project_id" text,
    "attachment" bytea,
    "attachment_link" text,
    PRIMARY KEY ("tapestation_id","experiment_date")
) PARTITION BY RANGE ("experiment_date");


CREATE TABLE IF NOT EXISTS "lab"."gelelectrophoresis" (
    "gelelectrophoresis_id" text NOT NULL, -- S99Pprj_999p1_gel9
    "sample_id" text NOT NULL,
    "sample_creation_date" date NOT NULL,
    "experiment_id" text,
    "experiment_date" date,
    "position" text,
    "ladder" text,
    "voltage" numeric,
    "band_size_bp" integer,
    "gel_type" text,
    "run_time_minutes" numeric,
    "person_id" text,
    "storage_id" text,
    "storage_position" text,
    "status_id" text,
    "project_id" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
    PRIMARY KEY ("gelelectrophoresis_id","experiment_date")
) PARTITION BY RANGE ("experiment_date");

CREATE TABLE IF NOT EXISTS "lab"."qpcr" (
    "experiment_id" text,
    "experiment_date" date,
    "sample_id" text NOT NULL,
    "sample_creation_date" date ,
    "position" text,
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
    PRIMARY KEY ("sample_id", "experiment_date")
) PARTITION BY RANGE ("experiment_date");

CREATE TABLE IF NOT EXISTS "lab"."library" (
    "library_id" text NOT NULL, --S99prj-999l4
    "experiment_id" text,
    "experiment_date" date,
    "sample_id" text NOT NULL,
    "sample_creation_date" date ,
    "library_name" text,
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
    PRIMARY KEY ("library_id","sample_id","experiment_date")
) PARTITION BY RANGE ("experiment_date");

CREATE TABLE IF NOT EXISTS "lab"."sequencing_run" (
    "sequencing_run_id" text NOT NULL,  --RS25-999
    "experiment_id" text,
    "experiment_date" date ,
    "library_id" text,
    "prep_date" date ,
    "sample_id" text,
    "sample_creation_date" date,
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
    PRIMARY KEY ("sequencing_run_id", "experiment_date")
) PARTITION BY RANGE ("experiment_date");

CREATE TABLE IF NOT EXISTS "lab"."Seq_dataset" (
    "data_seq_id" text NOT NULL,  --S99prj-999RS4
    "library_id" text ,
    "sample_id" text ,
    "sample_creation_date" date ,
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
    PRIMARY KEY ("data_seq_id", "experiment_date")
) PARTITION BY RANGE ("experiment_date");

CREATE TABLE IF NOT EXISTS "lab"."datasets" (
    "dataset_id" text NOT NULL,
    "sample_id" text,
    "sample_creation_date" date,
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
    PRIMARY KEY ("run_id", "experiment_date")
) PARTITION BY RANGE ("experiment_date");

CREATE TABLE IF NOT EXISTS "bioinformatics"."edna_assignments" (
    "assignment_id" text PRIMARY KEY,
    "run_id" text NOT NULL,
    "sample_id" text NOT NULL,
    "sample_creation_date" date NOT NULL,
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



-- F01. Function ids
-- Function to generate IDs for 'lims.publications'
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

-- Function to generate IDs for 'lims.sop'
CREATE OR REPLACE FUNCTION "lims".generate_sop_id()
RETURNS TRIGGER AS $$
BEGIN
    NEW.sop_id := NEW.sop_id_origin || '_v' || REPLACE(NEW.version, '.', '');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate IDs for 'lims.batch_steps'
CREATE OR REPLACE FUNCTION "lims".generate_batch_step_id()
RETURNS TRIGGER AS $$
BEGIN
    NEW.step_id := NEW.batch_id || '_' || NEW.step_number::TEXT || '_' || REPLACE(NEW.step_name, ' ', '_');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate IDs for 'lab.sampling'
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

-- Function to generate IDs for 'lab.fishing'
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

-- Function to generate IDs for 'lab.root_samples'
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

    current_year := TO_CHAR(COALESCE(NEW.sample_creation_date, CURRENT_DATE), 'YY');

    id_prefix := sample_type_abrv || current_year || project_or_customer_abrv;

    -- Find the next available serial number for the given prefix
    SELECT COALESCE(MAX(SUBSTRING("sample_id" FROM LENGTH(id_prefix) + 2)::INTEGER), 0)
    INTO next_serial
    FROM "lab"."root_samples"
    WHERE "sample_id" ILIKE id_prefix || '-%';

    NEW.sample_id := id_prefix || '-' || LPAD((next_serial + 1)::TEXT, 3, '0');

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- Function to generate IDs for 'lab.individual_catch_catch'
-- Format: [fishing_id]_if[serial]
CREATE OR REPLACE FUNCTION "lab".generate_individual_catch_id()
RETURNS TRIGGER AS $$
DECLARE
    next_serial integer;
    id_prefix text;
BEGIN
    id_prefix := NEW.fishing_id || '_if';

    SELECT COALESCE(MAX(SUBSTRING("individual_catch_id" FROM LENGTH(id_prefix) + 1)::INTEGER), 0)
    INTO next_serial
    FROM "lab"."individual_catch_catch"
    WHERE "individual_catch_id" ILIKE id_prefix || '%';

    NEW.individual_catch_id := id_prefix || LPAD((next_serial + 1)::TEXT, 3, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- Function to generate IDs for 'lab.otoliths'
-- Format: [parent_sample_id]_o_[serial]
CREATE OR REPLACE FUNCTION "lab".generate_otolith_id()
RETURNS TRIGGER AS $$
DECLARE
    next_serial integer;
    id_prefix text;
BEGIN
    id_prefix := NEW.parent_sample_id || '_o_';

    SELECT COALESCE(MAX(SUBSTRING("otolith_id" FROM LENGTH(id_prefix) + 1)::INTEGER), 0)
    INTO next_serial
    FROM "lab"."otoliths"
    WHERE "otolith_id" ILIKE id_prefix || '%';

    NEW.otolith_id := id_prefix || (next_serial + 1)::TEXT;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate IDs for 'lab.pcr'
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


-- Function to generate IDs for 'lab.protocol_runs'
-- Format: [experiment_id]_p_[serial]
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


-- Function to automatically copy experiment ID and date to junction table
CREATE OR REPLACE FUNCTION "lab".auto_insert_experiments_samples()
RETURNS TRIGGER AS $$
BEGIN
    -- Check if both experiment and sample IDs are present in the new row
    IF NEW.experiment_id IS NOT NULL AND NEW.sample_id IS NOT NULL THEN
        -- Insert the relationship into the junction table
        INSERT INTO "lab"."experiments_samples" ("experiment_id", "experiment_date", "sample_id", "sample_creation_date")
        VALUES (NEW.experiment_id, NEW.experiment_date, NEW.sample_id, NEW.sample_creation_date)
        ON CONFLICT ("experiment_id", "experiment_date", "sample_id", "sample_creation_date") DO NOTHING;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- Function to automatically fill date for protocol_runs
CREATE OR REPLACE FUNCTION "lab".set_experiment_date_for_protocol_runs()
RETURNS TRIGGER AS $$
BEGIN
    -- Look up the experiment date from the experiments table
    SELECT "experiment_date" INTO NEW.experiment_date
    FROM "lab"."experiments"
    WHERE "experiment_id" = NEW.experiment_id;

    -- Raise an error if the experiment ID is not found
    IF NEW.experiment_date IS NULL THEN
        RAISE EXCEPTION 'Experiment ID % not found in lab.experiments table.', NEW.experiment_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- Function to generate IDs for 'lab.dna', 'lab.rna', etc.
-- This function is reusable for any table with a sample_id
CREATE OR REPLACE FUNCTION "lab".generate_sample_product_id()
RETURNS TRIGGER AS $$
DECLARE
    product_prefix text;
    next_serial integer;
    sample_id_text text;
    table_name text;
BEGIN
    table_name := TG_TABLE_NAME;

    -- Determine the prefix based on the table name
    IF table_name = 'dna' THEN
        product_prefix := 'd';
    ELSIF table_name = 'rna' THEN
        product_prefix := 'r';
    ELSIF table_name = 'tissue' THEN
        product_prefix := 't';
    ELSIF table_name = 'water' THEN
        product_prefix := 'w';
    ELSIF table_name = 'sediments' THEN
        product_prefix := 's';
    ELSE
        RAISE EXCEPTION 'Unsupported table for this ID generation function: %', table_name;
    END IF;

    -- The prefix for the ID will be parent_sample_id + product_prefix
    sample_id_text := NEW.sample_id || '_' || product_prefix;

    -- Find the next available serial number for the given prefix
    EXECUTE format('SELECT COALESCE(MAX(SUBSTRING(%I FROM LENGTH(%L) + 1)::INTEGER), 0) FROM "lab".%I WHERE %I LIKE %L',
                   'sample_id', sample_id_text, table_name, 'sample_id', sample_id_text || '%') INTO next_serial;
                   
    NEW.sample_id := sample_id_text || (next_serial + 1)::TEXT;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to automatically fill 'sample_creation_date' from 'root_samples'
CREATE OR REPLACE FUNCTION "lab".set_sample_creation_date()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.sample_id IS NOT NULL THEN
        SELECT "sample_creation_date" INTO NEW.sample_creation_date
        FROM "lab"."root_samples"
        WHERE "sample_id" = NEW.sample_id;
        
        IF NEW.sample_creation_date IS NULL THEN
            RAISE EXCEPTION 'Sample ID % not found in lab.root_samples table.', NEW.sample_id;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;



-- F02. partition
























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
        "lab"."root_samples" s
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


-- Update the manual partition creation function for fishing
CREATE OR REPLACE FUNCTION "lab".create_fishing_partition_if_not_exists_manual (p_year integer)
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

    NEW.fishing_record_id := id_prefix || LPAD((next_serial + 1)::TEXT, 5, '0');
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

    NEW.mail_id := id_prefix || LPAD((next_serial + 1)::TEXT, 5, '0');
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

    NEW.conversation_id := id_prefix || LPAD((next_serial + 1)::TEXT, 5, '0');
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

    NEW.message_id := id_prefix || LPAD((next_serial + 1)::TEXT, 4, '0');
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
    temp_geom geometry; -- Use a temporary geometry to check before casting to Point, 4326
BEGIN
    IF p_original_srid IS NULL THEN
        -- If no SRID is provided, assume WGS84 if lat/lon are given
        IF p_latitude IS NOT NULL AND p_longitude IS NOT NULL THEN
            temp_geom := ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326);
        ELSIF p_easting IS NOT NULL AND p_northing IS NOT NULL THEN
            -- If only easting/northing and no SRID, raise a warning and return NULL
            RAISE WARNING 'Cannot transform coordinates: original_srid is NULL for Easting/Northing input. Returning NULL.';
            RETURN NULL;
        ELSE
            RETURN NULL; -- No coordinates provided
        END IF;
    ELSIF p_original_srid = 4326 THEN
        -- Already WGS84, just create the point
        IF p_longitude IS NOT NULL AND p_latitude IS NOT NULL THEN
            temp_geom := ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326);
        ELSIF p_easting IS NOT NULL AND p_northing IS NOT NULL THEN
            -- If 4326 is specified but coordinates are Easting/Northing, assume they are actually Lon/Lat for 4326
            -- This is a common mistake, so we try to interpret them as Lon/Lat for 4326
            temp_geom := ST_SetSRID(ST_MakePoint(p_easting, p_northing), 4326);
        ELSE
            RETURN NULL;
        END IF;
    ELSIF p_easting IS NOT NULL AND p_northing IS NOT NULL THEN
        -- Transform from other SRID to 4326
        BEGIN
            temp_geom := ST_Transform(ST_SetSRID(ST_MakePoint(p_easting, p_northing), p_original_srid), 4326);
        EXCEPTION
            WHEN SQLSTATE 'XX000' THEN -- Catch "Undefined spatial reference system" or similar
                RAISE WARNING 'SRID % is not defined or transformation failed for coordinates (%, %). Returning NULL.', p_original_srid, p_easting, p_northing;
                RETURN NULL;
        END;
    ELSE
        RAISE WARNING 'Incomplete coordinate data for transformation. Easting/Northing missing for SRID %.', p_original_srid;
        RETURN NULL;
    END IF;

    -- **Wichtige neue Prüfung:** Koordinaten auf Infinity/NaN prüfen
    IF temp_geom IS NOT NULL AND (
        ST_X(temp_geom) IS NULL OR ST_X(temp_geom) = 'Infinity'::float8 OR ST_X(temp_geom) = '-Infinity'::float8 OR ST_X(temp_geom) = 'NaN'::float8 OR
        ST_Y(temp_geom) IS NULL OR ST_Y(temp_geom) = 'Infinity'::float8 OR ST_Y(temp_geom) = '-Infinity'::float8 OR ST_Y(temp_geom) = 'NaN'::float8
    ) THEN
        RAISE WARNING 'Transformed geometry contains invalid (Infinity/NaN) coordinates. Returning NULL.';
        RETURN NULL;
    END IF;

    -- Nur zu geometry(Point, 4326) umwandeln, wenn es ein gültiger Punkt ist
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

-- Function for ProjectWanderfische_FishingData partitions
CREATE OR REPLACE FUNCTION "projects".create_ProjectWanderfische_FishingData_partition_if_not_exists()
RETURNS TRIGGER AS $$
DECLARE
    partition_date date;
    partition_name text;
    start_date date;
    end_date date;
BEGIN
    partition_date := NEW.record_date;
    IF partition_date IS NULL THEN
        RAISE EXCEPTION 'Cannot partition on NULL record_date for projects.ProjectWanderfische_FishingData. Please provide a record_date.';
    END IF;

    start_date := DATE_TRUNC('year', partition_date);
    end_date := DATE_TRUNC('year', partition_date) + INTERVAL '1 year';
    partition_name := 'ProjectWanderfische_FishingData_y' || TO_CHAR(start_date, 'YYYY');

    EXECUTE 'CREATE TABLE IF NOT EXISTS "projects".' || quote_ident(partition_name) || ' PARTITION OF "projects"."ProjectWanderfische_FishingData"
             FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Manual partition creation function for ProjectWanderfische_FishingData
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


-- ======================================================================
-- 9. Functions
-- ======================================================================

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

-- function
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

CREATE OR REPLACE FUNCTION "lims".generate_sop_id()
RETURNS TRIGGER AS $$
BEGIN
    NEW.sop_id := NEW.sop_id_origin || '_v' || REPLACE(NEW.version, '.', '');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "lims".generate_workflow_step_id()
RETURNS TRIGGER AS $$
BEGIN
    NEW.step_id := NEW.workflow_id || '_' || NEW.step_number::TEXT || '_' || REPLACE(NEW.step_name, ' ', '_');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

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

CREATE OR REPLACE FUNCTION "lab".generate_fishing_id()
RETURNS TRIGGER AS $$
BEGIN
    NEW.fishing_id := NEW.sampling_id || '_' || LPAD(NEXTVAL('lab.fishing_serial_seq')::TEXT, 4, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


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
    -- Explicitly qualify the column reference with the table alias 'st'
    SELECT st.sample_type_abrv INTO sample_type_abrv
    FROM "reference"."samples_type" st
    WHERE st.sample_type_id = NEW.sample_type_id;

    sampling_year := TO_CHAR(COALESCE(NEW.sampling_date, NEW.reception_date, CURRENT_DATE), 'YY');

    IF NEW.sampling_id IS NOT NULL AND NEW.sampling_date IS NOT NULL THEN
        SELECT samp.sampling_id, samp.sampling_date INTO temp_sampling_id_exists, temp_sampling_date_exists
        FROM "lab"."sampling" samp
        WHERE samp.sampling_id = NEW.sampling_id AND samp.sampling_date = NEW.sampling_date;

        IF temp_sampling_id_exists IS NULL THEN
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
        ELSE
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

    SELECT MAX(SUBSTRING("sample_id" FROM LENGTH(id_prefix) + 1)::INTEGER)
    INTO next_serial
    FROM "lab"."master_samples"
    WHERE "sample_id" ILIKE id_prefix || '%';

    IF next_serial IS NULL THEN
        next_serial := 1;
    ELSE
        next_serial := next_serial + 1;
    END IF;

    NEW.sample_id := id_prefix || LPAD(next_serial::TEXT, 4, '0');

    INSERT INTO "lab"."master_samples" ("sample_id") VALUES (NEW.sample_id);

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


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
    INSERT INTO "lab"."master_samples" ("sample_id") VALUES (NEW.sample_id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

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
    INSERT INTO "lab"."master_samples" ("sample_id") VALUES (NEW.sample_id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

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
    INSERT INTO "lab"."master_samples" ("sample_id") VALUES (NEW.sample_id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

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
    INSERT INTO "lab"."master_samples" ("sample_id") VALUES (NEW.sample_id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

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
    INSERT INTO "lab"."master_samples" ("sample_id") VALUES (NEW.sample_id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

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
    INSERT INTO "lab"."master_samples" ("sample_id") VALUES (NEW.sample_id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

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
        FROM "lab"."root_samples" s
        WHERE s.sample_id = target_sample_id;

        IF target_sample_sampling_date IS NULL THEN
            RAISE WARNING 'Could not determine sampling_date for sample_id % to update status in lab.samples. Status not updated.', target_sample_id;
            RETURN NEW;
        END IF;
    END IF;

    IF target_sample_id IS NOT NULL AND target_sample_sampling_date IS NOT NULL THEN
        UPDATE "lab"."root_samples"
        SET "status_id" = new_status
        WHERE "sample_id" = target_sample_id
          AND "sampling_date" = target_sample_sampling_date;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

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

    EXECUTE 'CREATE TABLE IF NOT EXISTS "lab".' || quote_ident(partition_name) || ' PARTITION OF "lab"."root_samples"
             FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';

    RETURN NEW;
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

    EXECUTE 'CREATE TABLE IF NOT EXISTS "lab".' || quote_ident(partition_name) || ' PARTITION OF "lab"."root_samples"
             FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';
END;
$$ LANGUAGE plpgsql;

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

-- Function for lab.dna partitions

CREATE OR REPLACE FUNCTION "lab".create_dna_partition_if_not_exists()
RETURNS TRIGGER AS $$
DECLARE
    partition_date date;
    partition_name text;
    start_date date;
    end_date date;
BEGIN
    partition_date := NEW.experiment_date::date;
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



-- Update the auto-partitioning function for fish to use sampling_date
CREATE OR REPLACE FUNCTION "lab".create_fish_partition_if_not_exists()
RETURNS TRIGGER AS $$
DECLARE
    partition_date date;
    partition_name text;
    start_date date;
    end_date date;
BEGIN
    partition_date := NEW.sampling_date; -- Changed to NEW.sampling_date
    IF partition_date IS NULL THEN
        RAISE EXCEPTION 'Cannot partition on NULL sampling_date for lab.fish. Please provide a sampling_date.';
    END IF;

    start_date := DATE_TRUNC('year', partition_date);
    end_date := DATE_TRUNC('year', partition_date) + INTERVAL '1 year';
    partition_name := 'fish_y' || TO_CHAR(start_date, 'YYYY'); -- Consistent naming

    EXECUTE 'CREATE TABLE IF NOT EXISTS "lab".' || quote_ident(partition_name) || ' PARTITION OF "lab"."fish"
             FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recreate triggers that were on lab.fish
CREATE TRIGGER trg_generate_fish_child_sample_id
BEFORE INSERT ON "lab"."fish"
FOR EACH ROW
EXECUTE FUNCTION "lab".generate_fish_child_sample_id();

CREATE TRIGGER trg_create_fish_partition
BEFORE INSERT ON "lab"."fish"
FOR EACH ROW
EXECUTE FUNCTION "lab".create_fish_partition_if_not_exists();

CREATE TRIGGER audit_trigger_fish
AFTER INSERT OR UPDATE OR DELETE ON "lab"."fish"
FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();

-- You'll also need to update the manual partition creation function for fish:
-- In your "9. Functions" section, ensure this is updated:
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




-- Function for lab.otoliths partitions
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


-- Function for lab.rna partitions
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

-- Function for lab.sediments partitions
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

-- Function for lab.tissue partitions
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

-- Function for lab.water partitions
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

-- ======================================================================
-- 11. Indexes
-- ======================================================================

CREATE INDEX IF NOT EXISTS idx_personal_full_name ON "reference"."personal" ("full_name");
CREATE INDEX IF NOT EXISTS idx_taxon_path_gist ON "reference"."taxon" USING GIST ("path");
CREATE INDEX IF NOT EXISTS idx_species_de_name ON "reference"."species" ("de_name");
CREATE INDEX IF NOT EXISTS idx_species_en_name ON "reference"."species" ("en_name");
CREATE INDEX IF NOT EXISTS idx_units_unit_type ON "reference"."units" ("unit_type");
CREATE INDEX IF NOT EXISTS idx_external_contacts_full_name ON "lims"."external_contacts" ("full_name");


CREATE INDEX IF NOT EXISTS idx_customers_customer_name ON "lims"."customers" ("customer_name");
CREATE INDEX IF NOT EXISTS idx_customers_customer_abrv ON "lims"."customers" ("customer_abrv");
CREATE INDEX IF NOT EXISTS idx_projects_status_id ON "lims"."projects" ("status_id");
CREATE INDEX IF NOT EXISTS idx_projects_pi_person_id ON "lims"."projects" ("pi_person_id");
CREATE INDEX IF NOT EXISTS idx_projects_customer_id ON "lims"."projects" ("customer_id");
CREATE INDEX IF NOT EXISTS idx_cruises_project_id ON "lims"."cruises" ("project_id");
CREATE INDEX IF NOT EXISTS idx_cruises_region_id ON "lims"."cruises" ("region_id");
CREATE INDEX IF NOT EXISTS idx_cruises_ecosystem_id ON "reference"."ecosystem" ("ecosystem_id");
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


CREATE INDEX IF NOT EXISTS idx_experiments_sop_id ON "lab"."experiments" ("sop_id");
CREATE INDEX IF NOT EXISTS idx_experiments_person_id ON "lab"."experiments" ("person_id");
CREATE INDEX IF NOT EXISTS idx_experiments_projects_experiment_id ON "lab"."experiments_projects" ("experiment_id");
CREATE INDEX IF NOT EXISTS idx_experiments_projects_project_id ON "lab"."experiments_projects" ("project_id");
CREATE INDEX IF NOT EXISTS idx_protocol_runs_experiment_id ON "lab"."protocol_runs" ("experiment_id");
CREATE INDEX IF NOT EXISTS idx_protocol_runs_sop_id ON "lab"."protocol_runs" ("sop_id");
CREATE INDEX IF NOT EXISTS idx_sampling_project_id ON "lab"."sampling" ("project_id");
CREATE INDEX IF NOT EXISTS idx_sampling_cruise_id ON "lab"."sampling" ("cruise_id");
CREATE INDEX IF NOT EXISTS idx_sampling_region_id ON "lab"."sampling" ("region_id");
CREATE INDEX IF NOT EXISTS idx_sampling_ecosystem_id ON "reference"."ecosystem" ("ecosystem_id");
CREATE INDEX IF NOT EXISTS idx_sampling_customer_id ON "lims"."customers" ("customer_id");
CREATE INDEX IF NOT EXISTS idx_sampling_geom ON "lab"."sampling" USING GIST ("geom");
CREATE INDEX IF NOT EXISTS idx_sampling_fishing_start_geom ON "lab"."sampling" USING GIST ("fishing_start_geom");
CREATE INDEX IF NOT EXISTS idx_sampling_fishing_end_geom ON "lab"."sampling" USING GIST ("fishing_end_geom");
CREATE INDEX IF NOT EXISTS idx_fishing_sampling_id ON "lab"."fishing" ("sampling_id", "sampling_date");
CREATE INDEX IF NOT EXISTS idx_fishing_taxon_id ON "lab"."fishing" ("taxon_id");
CREATE INDEX IF NOT EXISTS idx_samples_parent_sample_id ON "lab"."root_samples" ("parent_sample_id");
CREATE INDEX IF NOT EXISTS idx_samples_sample_type_id ON "lab"."root_samples" ("sample_type_id");
CREATE INDEX IF NOT EXISTS idx_samples_project_id ON "lab"."root_samples" ("project_id");
CREATE INDEX IF NOT EXISTS idx_samples_storage_position ON "lab"."root_samples" ("storage_position");
CREATE INDEX IF NOT EXISTS idx_storage_log_sample_id ON "lab"."storage_log" ("sample_id");
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
CREATE INDEX IF NOT EXISTS idx_fish_parent_sample_id ON "lab"."fish" ("parent_sample_id");
CREATE INDEX IF NOT EXISTS idx_fish_species_id ON "lab"."fish" ("species_id");
CREATE INDEX IF NOT EXISTS idx_fish_sampling_id ON "lab"."fish" ("sampling_id", "sampling_date"); -- Combined index for FK


CREATE INDEX IF NOT EXISTS idx_analysis_runs_pipeline_id ON "bioinformatics"."analysis_runs" ("pipeline_id");
CREATE INDEX IF NOT EXISTS idx_analysis_runs_sequencing_id ON "bioinformatics"."analysis_runs" ("sequencing_id");
CREATE INDEX IF NOT EXISTS idx_edna_assignments_run_id ON "bioinformatics"."edna_assignments" ("run_id");
CREATE INDEX IF NOT EXISTS idx_edna_assignments_sample_id ON "bioinformatics"."edna_assignments" ("sample_id");
CREATE INDEX IF NOT EXISTS idx_edna_assignments_taxon_id ON "bioinformatics"."edna_assignments" ("taxon_id");
CREATE INDEX IF NOT EXISTS idx_reference_databases_db_name ON "bioinformatics"."reference_databases" ("db_name");


CREATE INDEX IF NOT EXISTS idx_projects_active ON "lims"."projects" ("project_id") WHERE status_id = 'Active';

CREATE INDEX IF NOT EXISTS idx_customers_lower_name ON "lims"."customers" (LOWER("customer_name"));


-- Indexes for ProjectWanderfische_FishingData
CREATE INDEX IF NOT EXISTS idx_ProjectWanderfische_FishingData_agency_id ON "projects"."ProjectWanderfische_FishingData" ("agency_id");
CREATE INDEX IF NOT EXISTS idx_ProjectWanderfische_FishingData_project_id ON "projects"."ProjectWanderfische_FishingData" ("project_id");
CREATE INDEX IF NOT EXISTS idx_ProjectWanderfische_FishingData_record_date ON "projects"."ProjectWanderfische_FishingData" ("record_date");
CREATE INDEX IF NOT EXISTS idx_ProjectWanderfische_FishingData_location_description ON "projects"."ProjectWanderfische_FishingData" ("location_description");
CREATE INDEX IF NOT EXISTS idx_ProjectWanderfische_FishingData_water_body_name ON "projects"."ProjectWanderfische_FishingData" ("water_body_name");
CREATE INDEX IF NOT EXISTS idx_ProjectWanderfische_FishingData_geom_4326 ON "projects"."ProjectWanderfische_FishingData" USING GIST ("geom_4326");
CREATE INDEX IF NOT EXISTS idx_ProjectWanderfische_FishingData_agency_record_id ON "projects"."ProjectWanderfische_FishingData" ("agency_record_id");

-- Indexes for ProjectWanderfische_FishCatch
CREATE INDEX IF NOT EXISTS idx_ProjectWanderfische_FishCatch_fishing_record_id ON "projects"."ProjectWanderfische_FishCatch" ("fishing_record_id", "fishing_record_date");
CREATE INDEX IF NOT EXISTS idx_ProjectWanderfische_FishCatch_taxon_id ON "projects"."ProjectWanderfische_FishCatch" ("taxon_id");

-- Indexes for ProjectWanderfische_Mail
CREATE INDEX IF NOT EXISTS idx_ProjectWanderfische_Mail_fishing_record_id ON "projects"."ProjectWanderfische_Mail" ("fishing_record_id", "fishing_record_date");
CREATE INDEX IF NOT EXISTS idx_ProjectWanderfische_Mail_sender_person_id ON "projects"."ProjectWanderfische_Mail" ("sender_person_id");
CREATE INDEX IF NOT EXISTS idx_ProjectWanderfische_Mail_recipient_contact_id ON "projects"."ProjectWanderfische_Mail" ("recipient_contact_id");
CREATE INDEX IF NOT EXISTS idx_ProjectWanderfische_Mail_sent_at ON "projects"."ProjectWanderfische_Mail" ("sent_at");

-- Indexes for ProjectWanderfische_Conversation
CREATE INDEX IF NOT EXISTS idx_ProjectWanderfische_Conversation_fishing_record_id ON "projects"."ProjectWanderfische_Conversation" ("fishing_record_id", "fishing_record_date");
CREATE INDEX IF NOT EXISTS idx_ProjectWanderfische_Conversation_topic ON "projects"."ProjectWanderfische_Conversation" ("topic");

-- Indexes for ProjectWanderfische_ChatMessage
CREATE INDEX IF NOT EXISTS idx_ProjectWanderfische_ChatMessage_conversation_id ON "projects"."ProjectWanderfische_ChatMessage" ("conversation_id");
CREATE INDEX IF NOT EXISTS idx_ProjectWanderfische_ChatMessage_sender_person_id ON "projects"."ProjectWanderfische_ChatMessage" ("sender_person_id");
CREATE INDEX IF NOT EXISTS idx_ProjectWanderfische_ChatMessage_sent_at ON "projects"."ProjectWanderfische_ChatMessage" ("sent_at");


-- ======================================================================
-- 6. Triggers
-- ======================================================================

-- Audit triggers for new tables
CREATE TRIGGER audit_trigger_ProjectWanderfische_FishingData
AFTER INSERT OR UPDATE OR DELETE ON "projects"."ProjectWanderfische_FishingData"
FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();

CREATE TRIGGER audit_trigger_ProjectWanderfische_FishCatch
AFTER INSERT OR UPDATE OR DELETE ON "projects"."ProjectWanderfische_FishCatch"
FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();

CREATE TRIGGER audit_trigger_ProjectWanderfische_Mail
AFTER INSERT OR UPDATE OR DELETE ON "projects"."ProjectWanderfische_Mail"
FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();

CREATE TRIGGER audit_trigger_ProjectWanderfische_Conversation
AFTER INSERT OR UPDATE OR DELETE ON "projects"."ProjectWanderfische_Conversation"
FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();

CREATE TRIGGER audit_trigger_ProjectWanderfische_ChatMessage
AFTER INSERT OR UPDATE OR DELETE ON "projects"."ProjectWanderfische_ChatMessage"
FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();

-- ID generation triggers
CREATE TRIGGER trg_generate_ProjectWanderfische_FishingData_id
BEFORE INSERT ON "projects"."ProjectWanderfische_FishingData"
FOR EACH ROW EXECUTE FUNCTION "projects".generate_ProjectWanderfische_FishingData_id();

CREATE TRIGGER trg_generate_ProjectWanderfische_FishCatch_id
BEFORE INSERT ON "projects"."ProjectWanderfische_FishCatch"
FOR EACH ROW EXECUTE FUNCTION "projects".generate_ProjectWanderfische_FishCatch_id();

CREATE TRIGGER trg_generate_ProjectWanderfische_Mail_id
BEFORE INSERT ON "projects"."ProjectWanderfische_Mail"
FOR EACH ROW EXECUTE FUNCTION "projects".generate_ProjectWanderfische_Mail_id();

CREATE TRIGGER trg_generate_ProjectWanderfische_Conversation_id
BEFORE INSERT ON "projects"."ProjectWanderfische_Conversation"
FOR EACH ROW EXECUTE FUNCTION "projects".generate_ProjectWanderfische_Conversation_id();

CREATE TRIGGER trg_generate_ProjectWanderfische_ChatMessage_id
BEFORE INSERT ON "projects"."ProjectWanderfische_ChatMessage"
FOR EACH ROW EXECUTE FUNCTION "projects".generate_ProjectWanderfische_ChatMessage_id();

-- Coordinate transformation trigger
CREATE TRIGGER trg_populate_fishing_geom_4326
BEFORE INSERT OR UPDATE ON "projects"."ProjectWanderfische_FishingData"
FOR EACH ROW EXECUTE FUNCTION "projects".populate_fishing_geom_4326();

-- Partitioning trigger
CREATE TRIGGER trg_create_ProjectWanderfische_FishingData_partition
BEFORE INSERT ON "projects"."ProjectWanderfische_FishingData"
FOR EACH ROW EXECUTE FUNCTION "projects".create_ProjectWanderfische_FishingData_partition_if_not_exists();



-- ======================================================================
-- 10. Triggers
-- ======================================================================

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
CREATE TRIGGER audit_trigger_master_samples
AFTER INSERT OR UPDATE OR DELETE ON "lab"."master_samples"
FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_samples
AFTER INSERT OR UPDATE OR DELETE ON "lab"."root_samples"
FOR EACH ROW EXECUTE PROCEDURE "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_storage_log
AFTER INSERT OR UPDATE OR DELETE ON "lab"."storage_log"
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


-- Triggers for populating experiment_id and experiment_date for fishing and otoliths
CREATE TRIGGER trg_populate_fishing_experiment_data BEFORE INSERT ON "lab"."fishing" FOR EACH ROW EXECUTE FUNCTION "lab".populate_fishing_experiment_data();
CREATE TRIGGER trg_populate_otoliths_experiment_data BEFORE INSERT ON "lab"."otoliths" FOR EACH ROW EXECUTE FUNCTION "lab".populate_otoliths_experiment_data();

-- Triggers for ID generation
CREATE TRIGGER trg_generate_publication_id BEFORE INSERT ON "lims"."publications" FOR EACH ROW EXECUTE FUNCTION "lims".generate_publication_id();
CREATE TRIGGER trg_generate_sop_id BEFORE INSERT ON "lims"."sop" FOR EACH ROW EXECUTE FUNCTION "lims".generate_sop_id();
CREATE TRIGGER trg_generate_workflow_step_id BEFORE INSERT ON "lims"."workflow_steps" FOR EACH ROW EXECUTE FUNCTION "lims".generate_workflow_step_id();
CREATE TRIGGER trg_generate_sampling_id BEFORE INSERT ON "lab"."sampling" FOR EACH ROW EXECUTE FUNCTION "lab".generate_sampling_id();
CREATE TRIGGER trg_generate_sample_id BEFORE INSERT ON "lab"."root_samples" FOR EACH ROW EXECUTE FUNCTION "lab".generate_sample_id();
-- CREATE TRIGGER trg_generate_fish_child_sample_id BEFORE INSERT ON "lab"."fish" FOR EACH ROW EXECUTE FUNCTION "lab".generate_fish_child_sample_id();
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

CREATE TRIGGER trg_validate_sample_sampling_date
BEFORE INSERT OR UPDATE ON "lab"."root_samples"
FOR EACH ROW
EXECUTE FUNCTION "lab".validate_sample_sampling_date();

CREATE TRIGGER trg_create_sampling_partition
BEFORE INSERT ON "lab"."sampling"
FOR EACH ROW
EXECUTE FUNCTION "lab".create_sampling_partition_if_not_exists();

CREATE TRIGGER trg_create_samples_partition
BEFORE INSERT ON "lab"."root_samples"
FOR EACH ROW
EXECUTE FUNCTION "lab".create_samples_partition_if_not_exists();

CREATE TRIGGER trg_create_experiments_partition
BEFORE INSERT ON "lab"."experiments"
FOR EACH ROW
EXECUTE FUNCTION "lab".create_experiments_partition_if_not_exists();

CREATE TRIGGER trg_create_dissections_partition
BEFORE INSERT ON "lab"."dissections"
FOR EACH ROW
EXECUTE FUNCTION "lab".create_dissections_partition_if_not_exists();

CREATE TRIGGER trg_create_extraction_partition
BEFORE INSERT ON "lab"."extraction"
FOR EACH ROW
EXECUTE FUNCTION "lab".create_extraction_partition_if_not_exists();

CREATE TRIGGER trg_create_nanodrop_partition
BEFORE INSERT ON "lab"."nanodrop"
FOR EACH ROW
EXECUTE FUNCTION "lab".create_nanodrop_partition_if_not_exists();

CREATE TRIGGER trg_create_qubit_partition
BEFORE INSERT ON "lab"."qubit"
FOR EACH ROW
EXECUTE FUNCTION "lab".create_qubit_partition_if_not_exists();

CREATE TRIGGER trg_create_tapestation_partition
BEFORE INSERT ON "lab"."tapestation"
FOR EACH ROW
EXECUTE FUNCTION "lab".create_tapestation_partition_if_not_exists();

CREATE TRIGGER trg_create_pcr_partition
BEFORE INSERT ON "lab"."pcr"
FOR EACH ROW
EXECUTE FUNCTION "lab".create_pcr_partition_if_not_exists();

CREATE TRIGGER trg_create_gelelectrophoresis_partition
BEFORE INSERT ON "lab"."gelelectrophoresis"
FOR EACH ROW
EXECUTE FUNCTION "lab".create_gelelectrophoresis_partition_if_not_exists();

CREATE TRIGGER trg_create_qpcr_partition
BEFORE INSERT ON "lab"."qpcr"
FOR EACH ROW
EXECUTE FUNCTION "lab".create_qpcr_partition_if_not_exists();

CREATE TRIGGER trg_create_library_partition
BEFORE INSERT ON "lab"."library"
FOR EACH ROW
EXECUTE FUNCTION "lab".create_library_partition_if_not_exists();

CREATE TRIGGER trg_create_sequencing_partition
BEFORE INSERT ON "lab"."sequencing"
FOR EACH ROW
EXECUTE FUNCTION "lab".create_sequencing_partition_if_not_exists();

CREATE TRIGGER trg_create_datasets_partition
BEFORE INSERT ON "lab"."datasets"
FOR EACH ROW
EXECUTE FUNCTION "lab".create_datasets_partition_if_not_exists();

-- Triggers for creating partitions before data insertion
CREATE TRIGGER trg_create_dna_partition
BEFORE INSERT ON "lab"."dna"
FOR EACH ROW
EXECUTE FUNCTION "lab".create_dna_partition_if_not_exists();

-- CREATE TRIGGER trg_create_fish_partition BEFORE INSERT ON "lab"."fish" FOR EACH ROW EXECUTE FUNCTION "lab".create_fish_partition_if_not_exists();
-- Update the manual partition creation function for fishing

CREATE OR REPLACE FUNCTION "lab".create_fishing_partition_if_not_exists_manual (p_year integer)
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


CREATE TRIGGER trg_create_fishing_partition
BEFORE INSERT ON "lab"."fishing"
FOR EACH ROW EXECUTE FUNCTION "lab".create_fishing_partition_if_not_exists();

DO $$
DECLARE -- Re-declare variables here
    current_year_int INTEGER := EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER;
    next_year_int INTEGER := current_year_int + 1;
BEGIN
    PERFORM "lab".create_fishing_partition_if_not_exists_manual(current_year_int);
    PERFORM "lab".create_fishing_partition_if_not_exists_manual(next_year_int);
END $$;


CREATE TRIGGER trg_create_otoliths_partition
BEFORE INSERT ON "lab"."otoliths"
FOR EACH ROW
EXECUTE FUNCTION "lab".create_otoliths_partition_if_not_exists();

-- CREATE TRIGGER trg_create_rna_partition
-- BEFORE INSERT ON "lab"."rna"
-- FOR EACH ROW
-- EXECUTE FUNCTION "lab".create_rna_partition_if_not_exists();

CREATE TRIGGER trg_create_sediments_partition
BEFORE INSERT ON "lab"."sediments"
FOR EACH ROW
EXECUTE FUNCTION "lab".create_sediments_partition_if_not_exists();

CREATE TRIGGER trg_create_tissue_partition
BEFORE INSERT ON "lab"."tissue"
FOR EACH ROW
EXECUTE FUNCTION "lab".create_tissue_partition_if_not_exists();

CREATE TRIGGER trg_create_water_partition
BEFORE INSERT ON "lab"."water"
FOR EACH ROW
EXECUTE FUNCTION "lab".create_water_partition_if_not_exists();


CREATE TRIGGER trg_create_analysis_runs_partition
BEFORE INSERT ON "bioinformatics"."analysis_runs"
FOR EACH ROW
EXECUTE FUNCTION "bioinformatics".create_analysis_runs_partition_if_not_exists();

-- ======================================================================
-- 12. Full-Text Search Configuration
-- ======================================================================

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


ALTER TABLE "lims"."customers" ADD COLUMN IF NOT EXISTS customer_search_vector TSVECTOR;
CREATE INDEX IF NOT EXISTS idx_customers_gin_search ON "lims"."customers" USING GIN (customer_search_vector);
CREATE TRIGGER trg_update_customer_search BEFORE INSERT OR UPDATE ON "lims"."customers" FOR EACH ROW EXECUTE FUNCTION "lims".update_customer_search_vector_func();

ALTER TABLE "lab"."root_samples" ADD COLUMN IF NOT EXISTS sample_search_vector TSVECTOR;
CREATE INDEX IF NOT EXISTS idx_samples_gin_search ON "lab"."root_samples" USING GIN (sample_search_vector);
CREATE TRIGGER trg_update_sample_search BEFORE INSERT OR UPDATE ON "lab"."root_samples" FOR EACH ROW EXECUTE FUNCTION "lab".update_sample_search_vector_func();

ALTER TABLE "lims"."sop" ADD COLUMN IF NOT EXISTS sop_search_vector TSVECTOR;
CREATE INDEX IF NOT EXISTS idx_sop_gin_search ON "lims"."sop" USING GIN (sop_search_vector);
CREATE TRIGGER trg_update_sop_search BEFORE INSERT OR UPDATE ON "lims"."sop" FOR EACH ROW EXECUTE FUNCTION "lims".update_sop_search_vector_func();

ALTER TABLE "lab"."experiments" ADD COLUMN IF NOT EXISTS experiment_search_vector TSVECTOR;
CREATE INDEX IF NOT EXISTS idx_experiments_gin_search ON "lab"."experiments" USING GIN (experiment_search_vector);
CREATE TRIGGER trg_update_experiment_search BEFORE INSERT OR UPDATE ON "lab"."experiments" FOR EACH ROW EXECUTE FUNCTION "lab".update_experiment_search_vector_func();




-- -----------------------------------------------------------------------
-- Full-Text Search Configuration (always safe to run with IF NOT EXISTS)
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

--------------------------------------------------------------------------------
-- Drop existing triggers before recreating them to avoid "already exists" errors
--------------------------------------------------------------------------------

DROP TRIGGER IF EXISTS trg_update_customer_search ON "lims"."customers";
DROP TRIGGER IF EXISTS trg_update_sample_search ON "lab"."root_samples";
DROP TRIGGER IF EXISTS trg_update_sop_search ON "lims"."sop";
DROP TRIGGER IF EXISTS trg_update_experiment_search ON "lab"."experiments";
DROP TRIGGER IF EXISTS trg_update_project_search ON "lims"."projects"; -- Added this based on the last suggested fix for projects

--------------------------------------------------------------------------------
-- Recreate Functions for updating search vectors (safe to run with CREATE OR REPLACE)
--------------------------------------------------------------------------------

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

CREATE OR REPLACE FUNCTION "lims".update_project_search_vector_func() -- Ensure this function exists
RETURNS TRIGGER AS $$
BEGIN
    NEW.project_search_vector =
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.title, '')) ||
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.notes, ''));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------
-- Add search_vector columns and GIN indexes (safe to run with IF NOT EXISTS)
--------------------------------------------------------------------------------

ALTER TABLE "lims"."customers" ADD COLUMN IF NOT EXISTS customer_search_vector TSVECTOR;
CREATE INDEX IF NOT EXISTS idx_customers_gin_search ON "lims"."customers" USING GIN (customer_search_vector);
-- Create the trigger AFTER dropping it and recreating its function
CREATE TRIGGER trg_update_customer_search BEFORE INSERT OR UPDATE ON "lims"."customers" FOR EACH ROW EXECUTE FUNCTION "lims".update_customer_search_vector_func();

ALTER TABLE "lab"."root_samples" ADD COLUMN IF NOT EXISTS sample_search_vector TSVECTOR;
CREATE INDEX IF NOT EXISTS idx_samples_gin_search ON "lab"."root_samples" USING GIN (sample_search_vector);
CREATE TRIGGER trg_update_sample_search BEFORE INSERT OR UPDATE ON "lab"."root_samples" FOR EACH ROW EXECUTE FUNCTION "lab".update_sample_search_vector_func();

ALTER TABLE "lims"."sop" ADD COLUMN IF NOT EXISTS sop_search_vector TSVECTOR;
CREATE INDEX IF NOT EXISTS idx_sop_gin_search ON "lims"."sop" USING GIN (sop_search_vector);
CREATE TRIGGER trg_update_sop_search BEFORE INSERT OR UPDATE ON "lims"."sop" FOR EACH ROW EXECUTE FUNCTION "lims".update_sop_search_vector_func();

ALTER TABLE "lab"."experiments" ADD COLUMN IF NOT EXISTS experiment_search_vector TSVECTOR;
CREATE INDEX IF NOT EXISTS idx_experiments_gin_search ON "lab"."experiments" USING GIN (experiment_search_vector);
CREATE TRIGGER trg_update_experiment_search BEFORE INSERT OR UPDATE ON "lab"."experiments" FOR EACH ROW EXECUTE FUNCTION "lab".update_experiment_search_vector_func();

ALTER TABLE "lims"."projects" ADD COLUMN IF NOT EXISTS project_search_vector TSVECTOR; -- Ensure this column exists
CREATE INDEX IF NOT EXISTS idx_projects_gin_search ON "lims"."projects" USING GIN (project_search_vector);
CREATE TRIGGER trg_update_project_search BEFORE INSERT OR UPDATE ON "lims"."projects" FOR EACH ROW EXECUTE FUNCTION "lims".update_project_search_vector_func();
-- ======================================================================
-- 13. Views
-- ======================================================================

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

CREATE OR REPLACE VIEW "lab"."sample_workflow_progress_view" AS
SELECT
    s.sample_id,
    s.external_name,
    s.sample_type_id,
    s.status_id AS current_status,
    s.workflow_id,
    ws.step_name AS current_workflow_step,
    ws.step_number,
    ws.status_id AS step_status
FROM
    "lab"."root_samples" s
LEFT JOIN
    "lims"."workflow_steps" ws ON s.workflow_id = ws.workflow_id AND s.step_id = ws.step_id;

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
    "lab"."root_samples" s ON st.storage_id = s.storage_id;

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
    "lab"."root_samples" s ON seq.sample_id = s.sample_id
LEFT JOIN
    "reference"."personal" ref_p ON ar.person_id = ref_p.person_id
LEFT JOIN
    "reference"."taxon" t ON ea.taxon_id = t.taxon_id
LEFT JOIN
    "bioinformatics"."reference_databases" rdb ON ar.reference_db_id = rdb.db_id;


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
JOIN "lab"."root_samples" s ON ea.sample_id = s.sample_id
JOIN "lab"."sampling" samp ON s.sampling_id = samp.sampling_id AND s.sampling_date = samp.sampling_date
JOIN "lims"."projects" p ON s.project_id = p.project_id
JOIN "reference"."taxon" t ON ea.taxon_id = t.taxon_id
ORDER BY
    p.project_id, samp.sampling_date, s.sample_id, ea.read_count DESC;

CREATE OR REPLACE VIEW "lab"."storage_occupancy_view" AS
WITH box_counts AS (
    SELECT
        storage_id,
        COUNT(sample_id) AS stored_samples
    FROM "lab"."root_samples"
    WHERE storage_id IS NOT NULL
    GROUP BY storage_id
)
SELECT
    st.storage_id,
    st.room_id,
    st.freezer,
    st.etage,
    st.temperature_c,
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
LEFT JOIN "lab"."root_samples" s ON p.project_id = s.project_id
LEFT JOIN "lims"."orders" o ON p.project_id = o.project_id
GROUP BY
    p.project_id, p.title, stat.notes, p.funder, p.start_date, p.end_date
ORDER BY p.start_date DESC;

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


CREATE OR REPLACE VIEW "lab"."sample_full_details_view" AS
SELECT
    s.sample_id,
    s.external_name,
    s.project_id,
    p.title AS project_title,
    s.sample_type_id,
    stype.sample_type_abrv,
    s.status_id,
    stat.notes AS sample_status_notes,
    s.parent_sample_id,

    s.storage_id,
    stor.freezer AS storage_freezer,
    stor.box AS storage_box,
    s.storage_position,
    stor.room_id,
    r.address AS room_address,
    r.etage AS room_etage,

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

    f.species_id,
    taxon_sp.en_name AS species_en_name,
    f.total_length_mm,
    f.weight_g,
    f.sex,
    f.maturity_stage,
    f.stomach_contents,
    f.disease_info,
    f.tag_id,

    t.weight_mg AS tissue_weight_mg,
    t.tissue_type,
    t.preservation_method AS tissue_preservation_method,

    dna.volume_ul AS dna_volume_ul,
    dna.concentration_ng_ul AS dna_concentration_ng_ul,
    dna.a260_280 AS dna_a260_280,
    dna.a260_230 AS dna_a260_230,
    dna.extraction_method AS dna_extraction_method,

    rna.volume_ul AS rna_volume_ul,
    rna.concentration_ng_ul AS rna_concentration_ng_ul,
    rna.a260_280 AS rna_a260_280,
    rna.a260_230 AS rna_a260_230,
    rna.extraction_method AS rna_extraction_method,

    sed.volume AS sediment_volume,
    svu.unit_abbreviation AS sediment_volume_unit,
    sed.depth_m AS sediment_depth_m,
    sed.sampling_method AS sediment_sampling_method,

    wat.volume_l AS water_volume_l,
    wat.filter AS water_filter,
    wat.filter_pore_size_um AS water_filter_pore_size_um,
    wat.depth_m AS water_depth_m,

    ext.extraction_date,
    ext.kit AS extraction_kit,
    ext.elution_volume_ul AS extraction_elution_volume_ul,
    ext.yield_qubit_ng_ul,
    ext.yield_nanodrop_ng_ul,
    ext.a260_280 AS extraction_a260_280,
    ext.a260_230 AS extraction_a260_230,
    ext.extracted_dna_sample_id,
    ext.extracted_rna_sample_id,

    nd.nanodrop_concentration,
    ndcu.unit_abbreviation AS nanodrop_concentration_unit,
    nd.a260 AS nanodrop_a260,
    nd.a260_280 AS nanodrop_a260_280,
    nd.a260_230 AS nanodrop_a260_230,
    nd.nanodrop_total_dna_ug,

    qu.qubit_original_sample_conc,
    quosu.unit_abbreviation AS qubit_original_sample_unit,
    qu.qubit_total_dna_ug,

    pcr.pcr_date,
    pcr.primer_id AS pcr_primer_id,
    pcr_primer.target_gene_id AS pcr_target_gene_id,
    pcr.volume_reaction_ul,

    qpcr.qpcr_date,
    qpcr.ct_value,
    qpcr.inhibitor_test_result,

    lib.library_id,
    lib.library_prep_kit,
    lib.index_sequence,
    lib.read_length_bp AS library_read_length_bp,
    seq.sequencing_id,
    seq.sequencer,
    seq.total_reads,
    seq.raw_data_path,
    seq.genbank_accession_number,

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

    s.sampler_person_id,
    sampler_p.full_name AS sampler_full_name,
    s.receiver_person_id,
    receiver_p.full_name AS receiver_full_name,
    s.reception_date


FROM "lab"."root_samples" s
LEFT JOIN "reference"."status" stat ON s.status_id = stat.status_id
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


CREATE MATERIALIZED VIEW IF NOT EXISTS "lab"."monthly_sample_reception_mv" AS
SELECT
    TO_CHAR(reception_date, 'YYYY-MM') AS reception_month,
    sample_type_id,
    COUNT(sample_id) AS total_samples_received
FROM
    "lab"."root_samples"
WHERE
    reception_date IS NOT NULL
GROUP BY
    1, 2
ORDER BY
    1, 2
WITH DATA;


-- =========================================
CREATE OR REPLACE VIEW "lab"."detailed_samples_view" AS
SELECT
    s.sample_id,
    s.external_name,
    s.parent_sample_id,
    'Primary Sample' AS sample_origin_type, -- Identifies the source of this row
    s.sample_type_id,
    stype.sample_type_abrv,
    s.status_id,
    stat.notes AS sample_status_notes,
    s.sampling_id,
    s.sampling_date,
    s.reception_date,
    s.project_id,
    p.title AS project_title,
    s.customer_id,
    c.customer_name,
    s.storage_id,
    s.storage_position,
    s.notes,
    s.attachment,
    s.attachment_link,

    -- Sampling Event Details (from lab.sampling)
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

    -- Fish-specific Details (NULL placeholders for non-fish primary samples)
    NULL::text AS fish_species_id,
    NULL::text AS fish_species_en_name,
    NULL::numeric AS fish_total_length_mm,
    NULL::numeric AS fish_fork_length_mm,
    NULL::numeric AS fish_standard_length_mm,
    NULL::numeric AS fish_weight_g,
    NULL::text AS fish_sex,
    NULL::text AS fish_maturity_stage,
    NULL::text AS fish_stomach_contents,
    NULL::text AS fish_disease_info,
    NULL::text AS fish_tag_id,

    -- Tissue-specific Details (NULL placeholders)
    NULL::numeric AS tissue_weight_mg,
    NULL::text AS tissue_type,
    NULL::text AS tissue_preservation_method,

    -- DNA-specific Details (NULL placeholders)
    NULL::numeric AS dna_volume_ul,
    NULL::numeric AS dna_concentration_ng_ul,
    NULL::numeric AS dna_a260_280,
    NULL::numeric AS dna_a260_230,
    NULL::text AS dna_extraction_method,
    NULL::date AS dna_extraction_date_dna,
    NULL::integer AS dna_extraction_number,

    -- RNA-specific Details (NULL placeholders)
    NULL::numeric AS rna_volume_ul,
    NULL::numeric AS rna_concentration_ng_ul,
    NULL::numeric AS rna_a260_280,
    NULL::numeric AS rna_a260_230,
    NULL::text AS rna_extraction_method,
    NULL::date AS rna_extraction_date_rna,
    NULL::integer AS rna_extraction_number,

    -- Sediments-specific Details (NULL placeholders)
    NULL::numeric AS sediment_volume,
    NULL::text AS sediment_volume_unit,
    NULL::numeric AS sediment_depth_m,
    NULL::text AS sediment_sampling_method,
    NULL::text AS sediment_conservation_buffer,

    -- Water-specific Details (NULL placeholders)
    NULL::numeric AS water_volume_l,
    NULL::text AS water_filter,
    NULL::numeric AS water_filter_pore_size_um,
    NULL::numeric AS water_depth_m,
    NULL::text AS water_sampling_method,
    NULL::text AS water_conservation_buffer,

    -- Otoliths-specific Details (NULL placeholders)
    NULL::text AS otolith_id,
    NULL::text AS otolith_reader_person_id,
    NULL::text AS otolith_side,
    NULL::numeric AS otolith_age_reading_years,
    NULL::numeric AS otolith_confidence,

    -- Dissections Details (NULL placeholders)
    NULL::text AS dissection_id,
    NULL::text AS dissection_person_id,
    NULL::date AS dissection_date,
    NULL::jsonb AS dissection_stomach_contents_jsonb,
    NULL::numeric AS dissection_gonad_weight_g,
    NULL::numeric AS dissection_liver_weight_g,

    -- Extraction Details (NULL placeholders)
    NULL::text AS extraction_id,
    NULL::date AS extraction_process_date,
    NULL::text AS extraction_process_person_id,
    NULL::text AS extraction_process_kit,
    NULL::numeric AS extraction_process_elution_volume_ul,
    NULL::numeric AS extraction_process_yield_qubit_ng_ul,
    NULL::numeric AS extraction_process_yield_nanodrop_ng_ul,
    NULL::numeric AS extraction_process_a260_280,
    NULL::numeric AS extraction_process_a260_230,
    NULL::text AS extraction_result_dna_sample_id,
    NULL::text AS extraction_result_rna_sample_id,
    NULL::text AS extraction_blank_id,

    -- Nanodrop QC Details (NULL placeholders)
    NULL::text AS nanodrop_id,
    NULL::numeric AS nanodrop_concentration,
    NULL::text AS nanodrop_concentration_unit,
    NULL::numeric AS nanodrop_a260,
    NULL::numeric AS nanodrop_a260_280_qc,
    NULL::numeric AS nanodrop_a260_230_qc,
    NULL::numeric AS nanodrop_total_dna_ug,
    NULL::date AS nanodrop_measurement_date,
    NULL::text AS nanodrop_a260_280_note,
    NULL::text AS nanodrop_a260_230_note,

    -- Qubit QC Details (NULL placeholders)
    NULL::text AS qubit_id,
    NULL::numeric AS qubit_original_sample_conc,
    NULL::text AS qubit_original_sample_unit,
    NULL::numeric AS qubit_total_dna_ug,
    NULL::date AS qubit_measurement_date,
    NULL::text AS qubit_assay_kit,
    NULL::numeric AS qubit_tube_conc,
    NULL::text AS tube_unit_id,
    NULL::numeric AS sample_volume_ul,
    NULL::numeric AS elution_volume_ul,

    -- Tapestation QC Details (NULL placeholders)
    NULL::text AS tapestation_id,
    NULL::date AS tapestation_measurement_date,
    NULL::text AS tapestation_kit,

    -- PCR Details (NULL placeholders)
    NULL::text AS pcr_id,
    NULL::date AS pcr_date,
    NULL::text AS pcr_primer_id,
    NULL::text AS pcr_target_gene_id,
    NULL::numeric AS pcr_volume_reaction_ul,
    NULL::text AS pcr_blank_id,
    NULL::text AS pcr_position,

    -- Gel Electrophoresis Details (NULL placeholders)
    NULL::text AS gel_gelelectrophoresis_id,
    NULL::date AS gel_run_date,
    NULL::integer AS gel_band_size_bp,
    NULL::text AS gel_gel_type,
    NULL::text AS gel_position,
    NULL::text AS gel_ladder,
    NULL::numeric AS gel_voltage,
    NULL::numeric AS gel_run_time_minutes,

    -- qPCR Details (NULL placeholders)
    NULL::text AS qpcr_id,
    NULL::date AS qpcr_date,
    NULL::numeric AS qpcr_ct_value,
    NULL::text AS qpcr_inhibitor_test_result,
    NULL::text AS qpcr_position,
    NULL::text AS qpcr_primer_id_actual,
    NULL::text AS qpcr_pcr_blank_id,
    NULL::text AS qpcr_kit,
    NULL::numeric AS qpcr_volume_ul,

    -- Library Prep Details (NULL placeholders)
    NULL::text AS library_id,
    NULL::date AS library_prep_date,
    NULL::text AS library_name,
    NULL::text AS library_prep_kit,
    NULL::text AS library_index_sequence,
    NULL::integer AS library_read_length_bp,

    -- Sequencing Details (NULL placeholders)
    NULL::text AS sequencing_id,
    NULL::date AS sequencing_date,
    NULL::text AS sequencer,
    NULL::text AS flow_cell_id,
    NULL::bigint AS total_reads,
    NULL::text AS raw_data_path,
    NULL::text AS genbank_accession_number,
    NULL::text AS sequencing_library_prep_kit,
    NULL::text AS sequencing_index_sequence,
    NULL::integer AS sequencing_read_length_bp,

    -- Bioinformatics Analysis Details (NULL placeholders)
    NULL::text AS analysis_run_id,
    NULL::text AS pipeline_name,
    NULL::text AS pipeline_version,
    NULL::text AS bioinfo_reference_database,
    NULL::text AS bioinfo_database_version,
    NULL::numeric AS clustering_threshold,
    NULL::text AS final_output_path,

    -- eDNA Assignment Details (NULL placeholders)
    NULL::text AS edna_assignment_id,
    NULL::text AS edna_assigned_taxon_id,
    NULL::text AS edna_assigned_taxon_name,
    NULL::integer AS edna_read_count,
    NULL::numeric AS edna_confidence,

    -- Experiment Details (NULL placeholders for direct experiment link)
    e.experiment_id AS associated_experiment_id,
    e.experiment_title AS associated_experiment_title,
    e.experiment_date AS associated_experiment_date,
    e.aim AS associated_experiment_aim,
    e.method AS associated_experiment_method,
    exp_person.full_name AS experiment_person_name,

    -- Person information (NULL placeholders for specific sections)
    sampler_p.full_name AS sampler_full_name,
    receiver_p.full_name AS receiver_full_name

FROM
    "lab"."root_samples" s
LEFT JOIN "reference"."status" stat ON s.status_id = stat.status_id
LEFT JOIN "reference"."samples_type" stype ON s.sample_type_id = stype.sample_type_id
LEFT JOIN "lims"."projects" p ON s.project_id = p.project_id
LEFT JOIN "lims"."customers" c ON s.customer_id = c.customer_id
LEFT JOIN "lab"."storage" stor ON s.storage_id = stor.storage_id
LEFT JOIN "reference"."room" r ON stor.room_id = r.room_id
LEFT JOIN "lab"."sampling" samp ON s.sampling_id = samp.sampling_id AND s.sampling_date = samp.sampling_date
LEFT JOIN "reference"."units" wu ON samp.wind_unit_id = wu.unit_id
LEFT JOIN "reference"."units" su ON samp.salinity_unit_id = su.unit_id
LEFT JOIN "reference"."units" ou ON samp.oxygen_unit_id = ou.unit_id
LEFT JOIN "reference"."personal" sampler_p ON s.sampler_person_id = sampler_p.person_id
LEFT JOIN "reference"."personal" receiver_p ON s.receiver_person_id = receiver_p.person_id
LEFT JOIN "lab"."experiments_samples" es ON s.sample_id = es.sample_id AND s.sampling_date = es.experiment_date
LEFT JOIN "lab"."experiments" e ON es.experiment_id = e.experiment_id AND es.experiment_date = e.experiment_date
LEFT JOIN "reference"."personal" exp_person ON e.person_id = exp_person.person_id

UNION ALL
select
    f.sample_id,
    NULL AS external_name,
    f.parent_sample_id,
    'Derived Fish Sample' AS sample_origin_type,
    'Fish' AS sample_type_id,
    'F' AS sample_type_abrv,
    (SELECT status_id FROM "reference"."status" WHERE notes = 'Received') AS status_id, -- Default status
    (SELECT notes FROM "reference"."status" WHERE status_id = 'Received') AS sample_status_notes,
    f.sampling_id,
    f.sampling_date,
    NULL AS reception_date,
    f.project_id,
    p.title AS project_title,
    f.customer_id,
    c.customer_name,
    f.storage_id,
    f.storage_position,
    f.notes,
    f.attachment,
    f.attachment_link,

    -- Sampling Event Details (linked via sampling_id from fish)
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

    -- Fish-specific Details
    f.species_id,
    taxon_sp.en_name AS fish_species_en_name,
    f.total_length_mm,
    f.fork_length_mm,
    f.standard_length_mm,
    f.weight_g,
    f.sex,
    f.maturity_stage,
    f.stomach_contents,
    f.disease_info,
    f.tag_id,

    -- All other specific details are NULL
    NULL::numeric AS tissue_weight_mg, NULL::text AS tissue_type, NULL::text AS tissue_preservation_method,
    NULL::numeric AS dna_volume_ul, NULL::numeric AS dna_concentration_ng_ul, NULL::numeric AS dna_a260_280, NULL::numeric AS dna_a260_230, NULL::text AS dna_extraction_method, NULL::date AS dna_extraction_date_dna, NULL::integer AS dna_extraction_number,
    NULL::numeric AS rna_volume_ul, NULL::numeric AS rna_concentration_ng_ul, NULL::numeric AS rna_a260_280, NULL::numeric AS rna_a260_230, NULL::text AS rna_extraction_method, NULL::date AS rna_extraction_date_rna, NULL::integer AS rna_extraction_number,
    NULL::numeric AS sediment_volume, NULL::text AS sediment_volume_unit, NULL::numeric AS sediment_depth_m, NULL::text AS sediment_sampling_method, NULL::text AS sediment_conservation_buffer,
    NULL::numeric AS water_volume_l, NULL::text AS water_filter, NULL::numeric AS water_filter_pore_size_um, NULL::numeric AS water_depth_m, NULL::text AS water_sampling_method, NULL::text AS water_conservation_buffer,
    NULL::text AS otolith_id, NULL::text AS otolith_reader_person_id, NULL::text AS otolith_side, NULL::numeric AS otolith_age_reading_years, NULL::numeric AS otolith_confidence,
    NULL::text AS dissection_id, NULL::text AS dissection_person_id, NULL::date AS dissection_date, NULL::jsonb AS dissection_stomach_contents_jsonb, NULL::numeric AS dissection_gonad_weight_g, NULL::numeric AS dissection_liver_weight_g,
    NULL::text AS extraction_id, NULL::date AS extraction_process_date, NULL::text AS extraction_process_person_id, NULL::text AS extraction_process_kit, NULL::numeric AS extraction_process_elution_volume_ul, NULL::numeric AS extraction_process_yield_qubit_ng_ul, NULL::numeric AS extraction_process_yield_nanodrop_ng_ul, NULL::numeric AS extraction_process_a260_280, NULL::numeric AS extraction_process_a260_230, NULL::text AS extraction_result_dna_sample_id, NULL::text AS extraction_result_rna_sample_id,
    NULL::text AS extraction_blank_id,
    NULL::text AS nanodrop_id, NULL::numeric AS nanodrop_concentration, NULL::text AS nanodrop_concentration_unit, NULL::numeric AS nanodrop_a260, NULL::numeric AS nanodrop_a260_280_qc, NULL::numeric AS nanodrop_a260_230_qc, NULL::numeric AS nanodrop_total_dna_ug, NULL::date AS nanodrop_measurement_date, NULL::text AS nanodrop_a260_280_note, NULL::text AS nanodrop_a260_230_note,
    NULL::text AS qubit_id, NULL::numeric AS qubit_original_sample_conc, NULL::text AS qubit_original_sample_unit, NULL::numeric AS qubit_total_dna_ug, NULL::date AS qubit_measurement_date, NULL::text AS qubit_assay_kit, NULL::numeric AS qubit_tube_conc, NULL::text AS tube_unit_id, NULL::numeric AS sample_volume_ul, NULL::numeric AS elution_volume_ul,
    NULL::text AS tapestation_id, NULL::date AS tapestation_measurement_date, NULL::text AS tapestation_kit,
    NULL::text AS pcr_id, NULL::date AS pcr_date, NULL::text AS pcr_primer_id, NULL::text AS pcr_target_gene_id, NULL::numeric AS pcr_volume_reaction_ul, NULL::text AS pcr_blank_id, NULL::text AS pcr_position,
    NULL::text AS gel_gelelectrophoresis_id, NULL::date AS gel_run_date, NULL::integer AS gel_band_size_bp, NULL::text AS gel_gel_type, NULL::text AS gel_position, NULL::text AS gel_ladder, NULL::numeric AS gel_voltage, NULL::numeric AS gel_run_time_minutes,
    NULL::text AS qpcr_id, NULL::date AS qpcr_date, NULL::numeric AS qpcr_ct_value, NULL::text AS qpcr_inhibitor_test_result, NULL::text AS qpcr_position, NULL::text AS qpcr_primer_id_actual, NULL::text AS qpcr_pcr_blank_id, NULL::text AS qpcr_kit, NULL::numeric AS qpcr_volume_ul,
    NULL::text AS library_id, NULL::date AS library_prep_date, NULL::text AS library_name, NULL::text AS library_prep_kit, NULL::text AS library_index_sequence, NULL::integer AS library_read_length_bp,
    NULL::text AS sequencing_id, NULL::date AS sequencing_date, NULL::text AS sequencer, NULL::text AS flow_cell_id, NULL::bigint AS total_reads, NULL::text AS raw_data_path, NULL::text AS genbank_accession_number, NULL::text AS sequencing_library_prep_kit, NULL::text AS sequencing_index_sequence, NULL::integer AS sequencing_read_length_bp,
    NULL::text AS analysis_run_id, NULL::text AS pipeline_name, NULL::text AS pipeline_version, NULL::text AS bioinfo_reference_database, NULL::text AS bioinfo_database_version, NULL::numeric AS clustering_threshold, NULL::text AS final_output_path,
    NULL::text AS edna_assignment_id, NULL::text AS edna_assigned_taxon_id, NULL::text AS edna_assigned_taxon_name, NULL::integer AS edna_read_count, NULL::numeric AS edna_confidence,
    e.experiment_id AS associated_experiment_id, e.experiment_title AS associated_experiment_title, e.experiment_date AS associated_experiment_date, e.aim AS associated_experiment_aim, e.method AS associated_experiment_method, exp_person.full_name AS experiment_person_name,
    NULL::text AS sampler_full_name, NULL::text AS receiver_full_name

FROM
    "lab"."fish" f
LEFT JOIN "lims"."projects" p ON f.project_id = p.project_id
LEFT JOIN "lims"."customers" c ON f.customer_id = c.customer_id
LEFT JOIN "lab"."sampling" samp ON f.sampling_id = samp.sampling_id AND f.sampling_date = samp.sampling_date
LEFT JOIN "reference"."units" wu ON samp.wind_unit_id = wu.unit_id
LEFT JOIN "reference"."units" su ON samp.salinity_unit_id = su.unit_id
LEFT JOIN "reference"."units" ou ON samp.oxygen_unit_id = ou.unit_id
LEFT JOIN "reference"."taxon" taxon_sp ON f.species_id = taxon_sp.taxon_id
LEFT JOIN "lab"."experiments_samples" es ON f.sample_id = es.sample_id AND f.sampling_date = es.experiment_date
LEFT JOIN "lab"."experiments" e ON es.experiment_id = e.experiment_id AND es.experiment_date = e.experiment_date
LEFT JOIN "reference"."personal" exp_person ON e.person_id = exp_person.person_id

UNION ALL

SELECT
    t.sample_id,
    NULL AS external_name,
    t.parent_sample_id,
    'Derived Tissue Sample' AS sample_origin_type,
    'Tissue' AS sample_type_id,
    'T' AS sample_type_abrv,
    (SELECT status_id FROM "reference"."status" WHERE notes = 'Received') AS status_id,
    (SELECT notes FROM "reference"."status" WHERE status_id = 'Received') AS sample_status_notes,
    NULL::text AS sampling_id,
    t.experiment_date AS sampling_date,
    NULL AS reception_date,
    t.project_id,
    p.title AS project_title,
    NULL::integer AS customer_id,
    NULL::text AS customer_name,
    t.storage_id,
    t.storage_position,
    t.notes,
    t.attachment,
    t.attachment_link,

    -- Sampling Event Details (NULL for derived tissue, might come from parent)
    NULL::numeric AS sampling_lon, NULL::numeric AS sampling_lat, NULL::numeric AS fishing_start_lon, NULL::numeric AS fishing_start_lat, NULL::numeric AS fishing_end_lon, NULL::numeric AS fishing_end_lat,
    NULL::text AS sampling_location, NULL::numeric AS sampling_depth_m, NULL::numeric AS temperature_atmospheric_c, NULL::text AS weather, NULL::numeric AS wind_speed, NULL::text AS wind_unit,
    NULL::numeric AS salinity, NULL::text AS salinity_unit, NULL::numeric AS oxygen, NULL::text AS oxygen_unit,

    -- Fish-specific Details (NULL)
    NULL::text AS fish_species_id, NULL::text AS fish_species_en_name, NULL::numeric AS fish_total_length_mm, NULL::numeric AS fish_fork_length_mm, NULL::numeric AS fish_standard_length_mm, NULL::numeric AS fish_weight_g, NULL::text AS fish_sex, NULL::text AS fish_maturity_stage, NULL::text AS fish_stomach_contents, NULL::text AS fish_disease_info, NULL::text AS fish_tag_id,

    -- Tissue-specific Details
    t.weight_mg,
    t.tissue_type,
    t.preservation_method,

    -- All other specific details are NULL
    NULL::numeric AS dna_volume_ul, NULL::numeric AS dna_concentration_ng_ul, NULL::numeric AS dna_a260_280, NULL::numeric AS dna_a260_230, NULL::text AS dna_extraction_method, NULL::date AS dna_extraction_date_dna, NULL::integer AS dna_extraction_number,
    NULL::numeric AS rna_volume_ul, NULL::numeric AS rna_concentration_ng_ul, NULL::numeric AS rna_a260_280, NULL::numeric AS rna_a260_230, NULL::text AS rna_extraction_method, NULL::date AS rna_extraction_date_rna, NULL::integer AS rna_extraction_number,
    NULL::numeric AS sediment_volume, NULL::text AS sediment_volume_unit, NULL::numeric AS sediment_depth_m, NULL::text AS sediment_sampling_method, NULL::text AS sediment_conservation_buffer,
    NULL::numeric AS water_volume_l, NULL::text AS water_filter, NULL::numeric AS water_filter_pore_size_um, NULL::numeric AS water_depth_m, NULL::text AS water_sampling_method, NULL::text AS water_conservation_buffer,
    NULL::text AS otolith_id, NULL::text AS otolith_reader_person_id, NULL::text AS otolith_side, NULL::numeric AS otolith_age_reading_years, NULL::numeric AS otolith_confidence,
    NULL::text AS dissection_id, NULL::text AS dissection_person_id, NULL::date AS dissection_date, NULL::jsonb AS dissection_stomach_contents_jsonb, NULL::numeric AS dissection_gonad_weight_g, NULL::numeric AS dissection_liver_weight_g,
    NULL::text AS extraction_id, NULL::date AS extraction_process_date, NULL::text AS extraction_process_person_id, NULL::text AS extraction_process_kit, NULL::numeric AS extraction_process_elution_volume_ul, NULL::numeric AS extraction_process_yield_qubit_ng_ul, NULL::numeric AS extraction_process_yield_nanodrop_ng_ul, NULL::numeric AS extraction_process_a260_280, NULL::numeric AS extraction_process_a260_230, NULL::text AS extraction_result_dna_sample_id, NULL::text AS extraction_result_rna_sample_id,
    NULL::text AS extraction_blank_id,
    NULL::text AS nanodrop_id, NULL::numeric AS nanodrop_concentration, NULL::text AS nanodrop_concentration_unit, NULL::numeric AS nanodrop_a260, NULL::numeric AS nanodrop_a260_280_qc, NULL::numeric AS nanodrop_a260_230_qc, NULL::numeric AS nanodrop_total_dna_ug, NULL::date AS nanodrop_measurement_date, NULL::text AS nanodrop_a260_280_note, NULL::text AS nanodrop_a260_230_note,
    NULL::text AS qubit_id, NULL::numeric AS qubit_original_sample_conc, NULL::text AS qubit_original_sample_unit, NULL::numeric AS qubit_total_dna_ug, NULL::date AS qubit_measurement_date, NULL::text AS qubit_assay_kit, NULL::numeric AS qubit_tube_conc, NULL::text AS tube_unit_id, NULL::numeric AS sample_volume_ul, NULL::numeric AS elution_volume_ul,
    NULL::text AS tapestation_id, NULL::date AS tapestation_measurement_date, NULL::text AS tapestation_kit,
    NULL::text AS pcr_id, NULL::date AS pcr_date, NULL::text AS pcr_primer_id, NULL::text AS pcr_target_gene_id, NULL::numeric AS pcr_volume_reaction_ul, NULL::text AS pcr_blank_id, NULL::text AS pcr_position,
    NULL::text AS gel_gelelectrophoresis_id, NULL::date AS gel_run_date, NULL::integer AS gel_band_size_bp, NULL::text AS gel_gel_type, NULL::text AS gel_position, NULL::text AS gel_ladder, NULL::numeric AS gel_voltage, NULL::numeric AS gel_run_time_minutes,
    NULL::text AS qpcr_id, NULL::date AS qpcr_date, NULL::numeric AS qpcr_ct_value, NULL::text AS qpcr_inhibitor_test_result, NULL::text AS qpcr_position, NULL::text AS qpcr_primer_id_actual, NULL::text AS qpcr_pcr_blank_id, NULL::text AS qpcr_kit, NULL::numeric AS qpcr_volume_ul,
    NULL::text AS library_id, NULL::date AS library_prep_date, NULL::text AS library_name, NULL::text AS library_prep_kit, NULL::text AS library_index_sequence, NULL::integer AS library_read_length_bp,
    NULL::text AS sequencing_id, NULL::date AS sequencing_date, NULL::text AS sequencer, NULL::text AS flow_cell_id, NULL::bigint AS total_reads, NULL::text AS raw_data_path, NULL::text AS genbank_accession_number, NULL::text AS sequencing_library_prep_kit, NULL::text AS sequencing_index_sequence, NULL::integer AS sequencing_read_length_bp,
    NULL::text AS analysis_run_id, NULL::text AS pipeline_name, NULL::text AS pipeline_version, NULL::text AS bioinfo_reference_database, NULL::text AS bioinfo_database_version, NULL::numeric AS clustering_threshold, NULL::text AS final_output_path,
    NULL::text AS edna_assignment_id, NULL::text AS edna_assigned_taxon_id, NULL::text AS edna_assigned_taxon_name, NULL::integer AS edna_read_count, NULL::numeric AS edna_confidence,
    e.experiment_id AS associated_experiment_id, e.experiment_title AS associated_experiment_title, e.experiment_date AS associated_experiment_date, e.aim AS associated_experiment_aim, e.method AS associated_experiment_method, exp_person.full_name AS experiment_person_name,
    NULL::text AS sampler_full_name, NULL::text AS receiver_full_name

FROM
    "lab"."tissue" t
LEFT JOIN "lims"."projects" p ON t.project_id = p.project_id
LEFT JOIN "lab"."experiments" e ON t.experiment_id = e.experiment_id AND t.experiment_date = e.experiment_date
LEFT JOIN "reference"."personal" exp_person ON e.person_id = exp_person.person_id

UNION ALL
SELECT
    d.sample_id,
    NULL AS external_name,
    d.parent_sample_id,
    'Derived DNA Sample' AS sample_origin_type,
    'DNA' AS sample_type_id,
    'D' AS sample_type_abrv,
    (SELECT status_id FROM "reference"."status" WHERE notes = 'Received') AS status_id,
    (SELECT notes FROM "reference"."status" WHERE status_id = 'Received') AS sample_status_notes,
    NULL::text AS sampling_id,
    d.experiment_date AS sampling_date,
    d.extraction_date AS reception_date,
    d.project_id,
    p.title AS project_title,
    NULL::integer AS customer_id,
    NULL::text AS customer_name,
    d.storage_id,
    d.storage_position,
    d.notes,
    d.attachment,
    d.attachment_link,

    -- Sampling Event Details (NULL)
    NULL::numeric AS sampling_lon, NULL::numeric AS sampling_lat, NULL::numeric AS fishing_start_lon, NULL::numeric AS fishing_start_lat, NULL::numeric AS fishing_end_lon, NULL::numeric AS fishing_end_lat,
    NULL::text AS sampling_location, NULL::numeric AS sampling_depth_m, NULL::numeric AS temperature_atmospheric_c, NULL::text AS weather, NULL::numeric AS wind_speed, NULL::text AS wind_unit,
    NULL::numeric AS salinity, NULL::text AS salinity_unit, NULL::numeric AS oxygen, NULL::text AS oxygen_unit,

    -- Fish-specific Details (NULL)
    NULL::text AS fish_species_id, NULL::text AS fish_species_en_name, NULL::numeric AS fish_total_length_mm, NULL::numeric AS fish_fork_length_mm, NULL::numeric AS fish_standard_length_mm, NULL::numeric AS fish_weight_g, NULL::text AS fish_sex, NULL::text AS fish_maturity_stage, NULL::text AS fish_stomach_contents, NULL::text AS fish_disease_info, NULL::text AS fish_tag_id,

    -- Tissue-specific Details (NULL)
    NULL::numeric AS tissue_weight_mg, NULL::text AS tissue_type, NULL::text AS tissue_preservation_method,

    -- DNA-specific Details
    d.volume_ul,
    d.concentration_ng_ul,
    d.a260_280,
    d.a260_230,
    d.extraction_method,
    d.extraction_date AS dna_extraction_date_dna,
    d.extraction_number,

    -- All other specific details are NULL
    NULL::numeric AS rna_volume_ul, NULL::numeric AS rna_concentration_ng_ul, NULL::numeric AS rna_a260_280, NULL::numeric AS rna_a260_230, NULL::text AS rna_extraction_method, NULL::date AS rna_extraction_date_rna, NULL::integer AS rna_extraction_number,
    NULL::numeric AS sediment_volume, NULL::text AS sediment_volume_unit, NULL::numeric AS sediment_depth_m, NULL::text AS sediment_sampling_method, NULL::text AS sediment_conservation_buffer,
    NULL::numeric AS water_volume_l, NULL::text AS water_filter, NULL::numeric AS water_filter_pore_size_um, NULL::numeric AS water_depth_m, NULL::text AS water_sampling_method, NULL::text AS water_conservation_buffer,
    NULL::text AS otolith_id, NULL::text AS otolith_reader_person_id, NULL::text AS otolith_side, NULL::numeric AS otolith_age_reading_years, NULL::numeric AS otolith_confidence,
    NULL::text AS dissection_id, NULL::text AS dissection_person_id, NULL::date AS dissection_date, NULL::jsonb AS dissection_stomach_contents_jsonb, NULL::numeric AS dissection_gonad_weight_g, NULL::numeric AS dissection_liver_weight_g,
    NULL::text AS extraction_id, NULL::date AS extraction_process_date, NULL::text AS extraction_process_person_id, NULL::text AS extraction_process_kit, NULL::numeric AS extraction_process_elution_volume_ul, NULL::numeric AS extraction_process_yield_qubit_ng_ul, NULL::numeric AS extraction_process_yield_nanodrop_ng_ul, NULL::numeric AS extraction_process_a260_280, NULL::numeric AS extraction_process_a260_230, NULL::text AS extraction_result_dna_sample_id, NULL::text AS extraction_result_rna_sample_id,
    NULL::text AS extraction_blank_id,
    NULL::text AS nanodrop_id, NULL::numeric AS nanodrop_concentration, NULL::text AS nanodrop_concentration_unit, NULL::numeric AS nanodrop_a260, NULL::numeric AS nanodrop_a260_280_qc, NULL::numeric AS nanodrop_a260_230_qc, NULL::numeric AS nanodrop_total_dna_ug, NULL::date AS nanodrop_measurement_date, NULL::text AS nanodrop_a260_280_note, NULL::text AS nanodrop_a260_230_note,
    NULL::text AS qubit_id, NULL::numeric AS qubit_original_sample_conc, NULL::text AS qubit_original_sample_unit, NULL::numeric AS qubit_total_dna_ug, NULL::date AS qubit_measurement_date, NULL::text AS qubit_assay_kit, NULL::numeric AS qubit_tube_conc, NULL::text AS tube_unit_id, NULL::numeric AS sample_volume_ul, NULL::numeric AS elution_volume_ul,
    NULL::text AS tapestation_id, NULL::date AS tapestation_measurement_date, NULL::text AS tapestation_kit,
    NULL::text AS pcr_id, NULL::date AS pcr_date, NULL::text AS pcr_primer_id, NULL::text AS pcr_target_gene_id, NULL::numeric AS pcr_volume_reaction_ul, NULL::text AS pcr_blank_id, NULL::text AS pcr_position,
    NULL::text AS gel_gelelectrophoresis_id, NULL::date AS gel_run_date, NULL::integer AS gel_band_size_bp, NULL::text AS gel_gel_type, NULL::text AS gel_position, NULL::text AS gel_ladder, NULL::numeric AS gel_voltage, NULL::numeric AS gel_run_time_minutes,
    NULL::text AS qpcr_id, NULL::date AS qpcr_date, NULL::numeric AS qpcr_ct_value, NULL::text AS qpcr_inhibitor_test_result, NULL::text AS qpcr_position, NULL::text AS qpcr_primer_id_actual, NULL::text AS qpcr_pcr_blank_id, NULL::text AS qpcr_kit, NULL::numeric AS qpcr_volume_ul,
    NULL::text AS library_id, NULL::date AS library_prep_date, NULL::text AS library_name, NULL::text AS library_prep_kit, NULL::text AS library_index_sequence, NULL::integer AS library_read_length_bp,
    NULL::text AS sequencing_id, NULL::date AS sequencing_date, NULL::text AS sequencer, NULL::text AS flow_cell_id, NULL::bigint AS total_reads, NULL::text AS raw_data_path, NULL::text AS genbank_accession_number, NULL::text AS sequencing_library_prep_kit, NULL::text AS sequencing_index_sequence, NULL::integer AS sequencing_read_length_bp,
    NULL::text AS analysis_run_id, NULL::text AS pipeline_name, NULL::text AS pipeline_version, NULL::text AS bioinfo_reference_database, NULL::text AS bioinfo_database_version, NULL::numeric AS clustering_threshold, NULL::text AS final_output_path,
    NULL::text AS edna_assignment_id, NULL::text AS edna_assigned_taxon_id, NULL::text AS edna_assigned_taxon_name, NULL::integer AS edna_read_count, NULL::numeric AS edna_confidence,
    e.experiment_id AS associated_experiment_id, e.experiment_title AS associated_experiment_title, e.experiment_date AS associated_experiment_date, e.aim AS associated_experiment_aim, e.method AS associated_experiment_method, exp_person.full_name AS experiment_person_name,
    NULL::text AS sampler_full_name, NULL::text AS receiver_full_name

FROM
    "lab"."dna" d
LEFT JOIN "lims"."projects" p ON d.project_id = p.project_id
LEFT JOIN "lab"."experiments" e ON d.experiment_id = e.experiment_id AND d.experiment_date = e.experiment_date
LEFT JOIN "reference"."personal" exp_person ON e.person_id = exp_person.person_id

UNION ALL

SELECT
    r.sample_id,
    NULL AS external_name,
    r.parent_sample_id,
    'Derived RNA Sample' AS sample_origin_type,
    'RNA' AS sample_type_id,
    'R' AS sample_type_abrv,
    (SELECT status_id FROM "reference"."status" WHERE notes = 'Received') AS status_id,
    (SELECT notes FROM "reference"."status" WHERE status_id = 'Received') AS sample_status_notes,
    NULL::text AS sampling_id,
    r.experiment_date AS sampling_date,
    r.extraction_date AS reception_date,
    r.project_id,
    p.title AS project_title,
    NULL::integer AS customer_id,
    NULL::text AS customer_name,
    r.storage_id,
    r.storage_position,
    r.notes,
    r.attachment,
    r.attachment_link,

    -- Sampling Event Details (NULL)
    NULL::numeric AS sampling_lon, NULL::numeric AS sampling_lat, NULL::numeric AS fishing_start_lon, NULL::numeric AS fishing_start_lat, NULL::numeric AS fishing_end_lon, NULL::numeric AS fishing_end_lat,
    NULL::text AS sampling_location, NULL::numeric AS sampling_depth_m, NULL::numeric AS temperature_atmospheric_c, NULL::text AS weather, NULL::numeric AS wind_speed, NULL::text AS wind_unit,
    NULL::numeric AS salinity, NULL::text AS salinity_unit, NULL::numeric AS oxygen, NULL::text AS oxygen_unit,

    -- Fish-specific Details (NULL)
    NULL::text AS fish_species_id, NULL::text AS fish_species_en_name, NULL::numeric AS fish_total_length_mm, NULL::numeric AS fish_fork_length_mm, NULL::numeric AS fish_standard_length_mm, NULL::numeric AS fish_weight_g, NULL::text AS fish_sex, NULL::text AS fish_maturity_stage, NULL::text AS fish_stomach_contents, NULL::text AS fish_disease_info, NULL::text AS fish_tag_id,

    -- Tissue-specific Details (NULL)
    NULL::numeric AS tissue_weight_mg, NULL::text AS tissue_type, NULL::text AS tissue_preservation_method,

    -- DNA-specific Details (NULL)
    NULL::numeric AS dna_volume_ul, NULL::numeric AS dna_concentration_ng_ul, NULL::numeric AS dna_a260_280, NULL::numeric AS dna_a260_230, NULL::text AS dna_extraction_method, NULL::date AS dna_extraction_date_dna, NULL::integer AS dna_extraction_number,

    -- RNA-specific Details
    r.volume_ul,
    r.concentration_ng_ul,
    r.a260_280,
    r.a260_230,
    r.extraction_method,
    r.extraction_date AS rna_extraction_date_rna,
    r.extraction_number,

    -- All other specific details are NULL
    NULL::numeric AS sediment_volume, NULL::text AS sediment_volume_unit, NULL::numeric AS sediment_depth_m, NULL::text AS sediment_sampling_method, NULL::text AS sediment_conservation_buffer,
    NULL::numeric AS water_volume_l, NULL::text AS water_filter, NULL::numeric AS water_filter_pore_size_um, NULL::numeric AS water_depth_m, NULL::text AS water_sampling_method, NULL::text AS water_conservation_buffer,
    NULL::text AS otolith_id, NULL::text AS otolith_reader_person_id, NULL::text AS otolith_side, NULL::numeric AS otolith_age_reading_years, NULL::numeric AS otolith_confidence,
    NULL::text AS dissection_id, NULL::text AS dissection_person_id, NULL::date AS dissection_date, NULL::jsonb AS dissection_stomach_contents_jsonb, NULL::numeric AS dissection_gonad_weight_g, NULL::numeric AS dissection_liver_weight_g,
    NULL::text AS extraction_id, NULL::date AS extraction_process_date, NULL::text AS extraction_process_person_id, NULL::text AS extraction_process_kit, NULL::numeric AS extraction_process_elution_volume_ul, NULL::numeric AS extraction_process_yield_qubit_ng_ul, NULL::numeric AS extraction_process_yield_nanodrop_ng_ul, NULL::numeric AS extraction_process_a260_280, NULL::numeric AS extraction_process_a260_230, NULL::text AS extraction_result_dna_sample_id, NULL::text AS extraction_result_rna_sample_id,
    NULL::text AS extraction_blank_id,
    NULL::text AS nanodrop_id, NULL::numeric AS nanodrop_concentration, NULL::text AS nanodrop_concentration_unit, NULL::numeric AS nanodrop_a260, NULL::numeric AS nanodrop_a260_280_qc, NULL::numeric AS nanodrop_a260_230_qc, NULL::numeric AS nanodrop_total_dna_ug, NULL::date AS nanodrop_measurement_date, NULL::text AS nanodrop_a260_280_note, NULL::text AS nanodrop_a260_230_note,
    NULL::text AS qubit_id, NULL::numeric AS qubit_original_sample_conc, NULL::text AS qubit_original_sample_unit, NULL::numeric AS qubit_total_dna_ug, NULL::date AS qubit_measurement_date, NULL::text AS qubit_assay_kit, NULL::numeric AS qubit_tube_conc, NULL::text AS tube_unit_id, NULL::numeric AS sample_volume_ul, NULL::numeric AS elution_volume_ul,
    NULL::text AS tapestation_id, NULL::date AS tapestation_measurement_date, NULL::text AS tapestation_kit,
    NULL::text AS pcr_id, NULL::date AS pcr_date, NULL::text AS pcr_primer_id, NULL::text AS pcr_target_gene_id, NULL::numeric AS pcr_volume_reaction_ul, NULL::text AS pcr_blank_id, NULL::text AS pcr_position,
    NULL::text AS gel_gelelectrophoresis_id, NULL::date AS gel_run_date, NULL::integer AS gel_band_size_bp, NULL::text AS gel_gel_type, NULL::text AS gel_position, NULL::text AS gel_ladder, NULL::numeric AS gel_voltage, NULL::numeric AS gel_run_time_minutes,
    NULL::text AS qpcr_id, NULL::date AS qpcr_date, NULL::numeric AS qpcr_ct_value, NULL::text AS qpcr_inhibitor_test_result, NULL::text AS qpcr_position, NULL::text AS qpcr_primer_id_actual, NULL::text AS qpcr_pcr_blank_id, NULL::text AS qpcr_kit, NULL::numeric AS qpcr_volume_ul,
    NULL::text AS library_id, NULL::date AS library_prep_date, NULL::text AS library_name, NULL::text AS library_prep_kit, NULL::text AS library_index_sequence, NULL::integer AS library_read_length_bp,
    NULL::text AS sequencing_id, NULL::date AS sequencing_date, NULL::text AS sequencer, NULL::text AS flow_cell_id, NULL::bigint AS total_reads, NULL::text AS raw_data_path, NULL::text AS genbank_accession_number, NULL::text AS sequencing_library_prep_kit, NULL::text AS sequencing_index_sequence, NULL::integer AS sequencing_read_length_bp,
    NULL::text AS analysis_run_id, NULL::text AS pipeline_name, NULL::text AS pipeline_version, NULL::text AS bioinfo_reference_database, NULL::text AS bioinfo_database_version, NULL::numeric AS clustering_threshold, NULL::text AS final_output_path,
    NULL::text AS edna_assignment_id, NULL::text AS edna_assigned_taxon_id, NULL::text AS edna_assigned_taxon_name, NULL::integer AS edna_read_count, NULL::numeric AS edna_confidence,
    e.experiment_id AS associated_experiment_id, e.experiment_title AS associated_experiment_title, e.experiment_date AS associated_experiment_date, e.aim AS associated_experiment_aim, e.method AS associated_experiment_method, exp_person.full_name AS experiment_person_name,
    NULL::text AS sampler_full_name, NULL::text AS receiver_full_name

FROM
    "lab"."rna" r
LEFT JOIN "lims"."projects" p ON r.project_id = p.project_id
LEFT JOIN "lab"."experiments" e ON r.experiment_id = e.experiment_id AND r.experiment_date = e.experiment_date
LEFT JOIN "reference"."personal" exp_person ON e.person_id = exp_person.person_id

UNION ALL

SELECT
    sed.sample_id,
    sed.external_name,
    sed.parent_sample_id,
    'Derived Sediment Sample' AS sample_origin_type,
    'Sediments' AS sample_type_id,
    'S' AS sample_type_abrv,
    (SELECT status_id FROM "reference"."status" WHERE notes = 'Received') AS status_id,
    (SELECT notes FROM "reference"."status" WHERE status_id = 'Received') AS sample_status_notes,
    NULL::text AS sampling_id,
    sed.experiment_date AS sampling_date,
    NULL AS reception_date,
    sed.project_id,
    p.title AS project_title,
    NULL::integer AS customer_id,
    NULL::text AS customer_name,
    sed.storage_id,
    sed.storage_position,
    sed.notes,
    sed.attachment,
    sed.attachment_link,

    -- Sampling Event Details (NULL)
    NULL::numeric AS sampling_lon, NULL::numeric AS sampling_lat, NULL::numeric AS fishing_start_lon, NULL::numeric AS fishing_start_lat, NULL::numeric AS fishing_end_lon, NULL::numeric AS fishing_end_lat,
    NULL::text AS sampling_location, NULL::numeric AS sampling_depth_m, NULL::numeric AS temperature_atmospheric_c, NULL::text AS weather, NULL::numeric AS wind_speed, NULL::text AS wind_unit,
    NULL::numeric AS salinity, NULL::text AS salinity_unit, NULL::numeric AS oxygen, NULL::text AS oxygen_unit,

    -- Fish-specific Details (NULL)
    NULL::text AS fish_species_id, NULL::text AS fish_species_en_name, NULL::numeric AS fish_total_length_mm, NULL::numeric AS fish_fork_length_mm, NULL::numeric AS fish_standard_length_mm, NULL::numeric AS fish_weight_g, NULL::text AS fish_sex, NULL::text AS fish_maturity_stage, NULL::text AS fish_stomach_contents, NULL::text AS fish_disease_info, NULL::text AS fish_tag_id,

    -- Tissue-specific Details (NULL)
    NULL::numeric AS tissue_weight_mg, NULL::text AS tissue_type, NULL::text AS tissue_preservation_method,

    -- DNA-specific Details (NULL)
    NULL::numeric AS dna_volume_ul, NULL::numeric AS dna_concentration_ng_ul, NULL::numeric AS dna_a260_280, NULL::numeric AS dna_a260_230, NULL::text AS dna_extraction_method, NULL::date AS dna_extraction_date_dna, NULL::integer AS dna_extraction_number,

    -- RNA-specific Details (NULL)
    NULL::numeric AS rna_volume_ul, NULL::numeric AS rna_concentration_ng_ul, NULL::numeric AS rna_a260_280, NULL::numeric AS rna_a260_230, NULL::text AS rna_extraction_method, NULL::date AS rna_extraction_date_rna, NULL::integer AS rna_extraction_number,

    -- Sediments-specific Details
    sed.volume,
    svu.unit_abbreviation AS sediment_volume_unit,
    sed.depth_m,
    sed.sampling_method,
    sed.conservation_buffer,

    -- All other specific details are NULL
    NULL::numeric AS water_volume_l, NULL::text AS water_filter, NULL::numeric AS water_filter_pore_size_um, NULL::numeric AS water_depth_m, NULL::text AS water_sampling_method, NULL::text AS water_conservation_buffer,
    NULL::text AS otolith_id, NULL::text AS otolith_reader_person_id, NULL::text AS otolith_side, NULL::numeric AS otolith_age_reading_years, NULL::numeric AS otolith_confidence,
    NULL::text AS dissection_id, NULL::text AS dissection_person_id, NULL::date AS dissection_date, NULL::jsonb AS dissection_stomach_contents_jsonb, NULL::numeric AS dissection_gonad_weight_g, NULL::numeric AS dissection_liver_weight_g,
    NULL::text AS extraction_id, NULL::date AS extraction_process_date, NULL::text AS extraction_process_person_id, NULL::text AS extraction_process_kit, NULL::numeric AS extraction_process_elution_volume_ul, NULL::numeric AS extraction_process_yield_qubit_ng_ul, NULL::numeric AS extraction_process_yield_nanodrop_ng_ul, NULL::numeric AS extraction_process_a260_280, NULL::numeric AS extraction_process_a260_230, NULL::text AS extraction_result_dna_sample_id, NULL::text AS extraction_result_rna_sample_id,
    NULL::text AS extraction_blank_id,
    NULL::text AS nanodrop_id, NULL::numeric AS nanodrop_concentration, NULL::text AS nanodrop_concentration_unit, NULL::numeric AS nanodrop_a260, NULL::numeric AS nanodrop_a260_280_qc, NULL::numeric AS nanodrop_a260_230_qc, NULL::numeric AS nanodrop_total_dna_ug, NULL::date AS nanodrop_measurement_date, NULL::text AS nanodrop_a260_280_note, NULL::text AS nanodrop_a260_230_note,
    NULL::text AS qubit_id, NULL::numeric AS qubit_original_sample_conc, NULL::text AS qubit_original_sample_unit, NULL::numeric AS qubit_total_dna_ug, NULL::date AS qubit_measurement_date, NULL::text AS qubit_assay_kit, NULL::numeric AS qubit_tube_conc, NULL::text AS tube_unit_id, NULL::numeric AS sample_volume_ul, NULL::numeric AS elution_volume_ul,
    NULL::text AS tapestation_id, NULL::date AS tapestation_measurement_date, NULL::text AS tapestation_kit,
    NULL::text AS pcr_id, NULL::date AS pcr_date, NULL::text AS pcr_primer_id, NULL::text AS pcr_target_gene_id, NULL::numeric AS pcr_volume_reaction_ul, NULL::text AS pcr_blank_id, NULL::text AS pcr_position,
    NULL::text AS gel_gelelectrophoresis_id, NULL::date AS gel_run_date, NULL::integer AS gel_band_size_bp, NULL::text AS gel_gel_type, NULL::text AS gel_position, NULL::text AS gel_ladder, NULL::numeric AS gel_voltage, NULL::numeric AS gel_run_time_minutes,
    NULL::text AS qpcr_id, NULL::date AS qpcr_date, NULL::numeric AS qpcr_ct_value, NULL::text AS qpcr_inhibitor_test_result, NULL::text AS qpcr_position, NULL::text AS qpcr_primer_id_actual, NULL::text AS qpcr_pcr_blank_id, NULL::text AS qpcr_kit, NULL::numeric AS qpcr_volume_ul,
    NULL::text AS library_id, NULL::date AS library_prep_date, NULL::text AS library_name, NULL::text AS library_prep_kit, NULL::text AS library_index_sequence, NULL::integer AS library_read_length_bp,
    NULL::text AS sequencing_id, NULL::date AS sequencing_date, NULL::text AS sequencer, NULL::text AS flow_cell_id, NULL::bigint AS total_reads, NULL::text AS raw_data_path, NULL::text AS genbank_accession_number, NULL::text AS sequencing_library_prep_kit, NULL::text AS sequencing_index_sequence, NULL::integer AS sequencing_read_length_bp,
    NULL::text AS analysis_run_id, NULL::text AS pipeline_name, NULL::text AS pipeline_version, NULL::text AS bioinfo_reference_database, NULL::text AS bioinfo_database_version, NULL::numeric AS clustering_threshold, NULL::text AS final_output_path,
    NULL::text AS edna_assignment_id, NULL::text AS edna_assigned_taxon_id, NULL::text AS edna_assigned_taxon_name, NULL::integer AS edna_read_count, NULL::numeric AS edna_confidence,
    e.experiment_id AS associated_experiment_id, e.experiment_title AS associated_experiment_title, e.experiment_date AS associated_experiment_date, e.aim AS associated_experiment_aim, e.method AS associated_experiment_method, exp_person.full_name AS experiment_person_name,
    NULL::text AS sampler_full_name, NULL::text AS receiver_full_name

FROM
    "lab"."sediments" sed
LEFT JOIN "lims"."projects" p ON sed.project_id = p.project_id
LEFT JOIN "reference"."units" svu ON sed.volume_unit_id = svu.unit_id
LEFT JOIN "lab"."experiments" e ON sed.experiment_id = e.experiment_id AND sed.experiment_date = e.experiment_date
LEFT JOIN "reference"."personal" exp_person ON e.person_id = exp_person.person_id

UNION ALL

SELECT
    w.sample_id,
    NULL AS external_name,
    w.parent_sample_id,
    'Derived Water Sample' AS sample_origin_type,
    'Water' AS sample_type_id,
    'W' AS sample_type_abrv,
    (SELECT status_id FROM "reference"."status" WHERE notes = 'Received') AS status_id,
    (SELECT notes FROM "reference"."status" WHERE status_id = 'Received') AS sample_status_notes,
    NULL::text AS sampling_id,
    w.experiment_date AS sampling_date,
    NULL AS reception_date,
    w.project_id,
    p.title AS project_title,
    NULL::integer AS customer_id,
    NULL::text AS customer_name,
    w.storage_id,
    w.storage_position,
    w.notes,
    w.attachment,
    w.attachment_link,

    -- Sampling Event Details (NULL)
    NULL::numeric AS sampling_lon, NULL::numeric AS sampling_lat, NULL::numeric AS fishing_start_lon, NULL::numeric AS fishing_start_lat, NULL::numeric AS fishing_end_lon, NULL::numeric AS fishing_end_lat,
    NULL::text AS sampling_location, NULL::numeric AS sampling_depth_m, NULL::numeric AS temperature_atmospheric_c, NULL::text AS weather, NULL::numeric AS wind_speed, NULL::text AS wind_unit,
    NULL::numeric AS salinity, NULL::text AS salinity_unit, NULL::numeric AS oxygen, NULL::text AS oxygen_unit,

    -- Fish-specific Details (NULL)
    NULL::text AS fish_species_id, NULL::text AS fish_species_en_name, NULL::numeric AS fish_total_length_mm, NULL::numeric AS fish_fork_length_mm, NULL::numeric AS fish_standard_length_mm, NULL::numeric AS fish_weight_g, NULL::text AS fish_sex, NULL::text AS fish_maturity_stage, NULL::text AS fish_stomach_contents, NULL::text AS fish_disease_info, NULL::text AS fish_tag_id,

    -- Tissue-specific Details (NULL)
    NULL::numeric AS tissue_weight_mg, NULL::text AS tissue_type, NULL::text AS tissue_preservation_method,

    -- DNA-specific Details (NULL)
    NULL::numeric AS dna_volume_ul, NULL::numeric AS dna_concentration_ng_ul, NULL::numeric AS dna_a260_280, NULL::numeric AS dna_a260_230, NULL::text AS dna_extraction_method, NULL::date AS dna_extraction_date_dna, NULL::integer AS dna_extraction_number,

    -- RNA-specific Details (NULL)
    NULL::numeric AS rna_volume_ul, NULL::numeric AS rna_concentration_ng_ul, NULL::numeric AS rna_a260_280, NULL::numeric AS rna_a260_230, NULL::text AS rna_extraction_method, NULL::date AS rna_extraction_date_rna, NULL::integer AS rna_extraction_number,

    -- Sediments-specific Details (NULL)
    NULL::numeric AS sediment_volume, NULL::text AS sediment_volume_unit, NULL::numeric AS sediment_depth_m, NULL::text AS sediment_sampling_method, NULL::text AS sediment_conservation_buffer,

    -- Water-specific Details
    w.volume_l,
    w.filter,
    w.filter_pore_size_um,
    w.depth_m,
    w.sampling_method,
    w.conservation_buffer,

    -- All other specific details are NULL
    NULL::text AS otolith_id, NULL::text AS otolith_reader_person_id, NULL::text AS otolith_side, NULL::numeric AS otolith_age_reading_years, NULL::numeric AS otolith_confidence,
    NULL::text AS dissection_id, NULL::text AS dissection_person_id, NULL::date AS dissection_date, NULL::jsonb AS dissection_stomach_contents_jsonb, NULL::numeric AS dissection_gonad_weight_g, NULL::numeric AS dissection_liver_weight_g,
    NULL::text AS extraction_id, NULL::date AS extraction_process_date, NULL::text AS extraction_process_person_id, NULL::text AS extraction_process_kit, NULL::numeric AS extraction_process_elution_volume_ul, NULL::numeric AS extraction_process_yield_qubit_ng_ul, NULL::numeric AS extraction_process_yield_nanodrop_ng_ul, NULL::numeric AS extraction_process_a260_280, NULL::numeric AS extraction_process_a260_230, NULL::text AS extraction_result_dna_sample_id, NULL::text AS extraction_result_rna_sample_id,
    NULL::text AS extraction_blank_id,
    NULL::text AS nanodrop_id, NULL::numeric AS nanodrop_concentration, NULL::text AS nanodrop_concentration_unit, NULL::numeric AS nanodrop_a260, NULL::numeric AS nanodrop_a260_280_qc, NULL::numeric AS nanodrop_a260_230_qc, NULL::numeric AS nanodrop_total_dna_ug, NULL::date AS nanodrop_measurement_date, NULL::text AS nanodrop_a260_280_note, NULL::text AS nanodrop_a260_230_note,
    NULL::text AS qubit_id, NULL::numeric AS qubit_original_sample_conc, NULL::text AS qubit_original_sample_unit, NULL::numeric AS qubit_total_dna_ug, NULL::date AS qubit_measurement_date, NULL::text AS qubit_assay_kit, NULL::numeric AS qubit_tube_conc, NULL::text AS tube_unit_id, NULL::numeric AS sample_volume_ul, NULL::numeric AS elution_volume_ul,
    NULL::text AS tapestation_id, NULL::date AS tapestation_measurement_date, NULL::text AS tapestation_kit,
    NULL::text AS pcr_id, NULL::date AS pcr_date, NULL::text AS pcr_primer_id, NULL::text AS pcr_target_gene_id, NULL::numeric AS pcr_volume_reaction_ul, NULL::text AS pcr_blank_id, NULL::text AS pcr_position,
    NULL::text AS gel_gelelectrophoresis_id, NULL::date AS gel_run_date, NULL::integer AS gel_band_size_bp, NULL::text AS gel_gel_type, NULL::text AS gel_position, NULL::text AS gel_ladder, NULL::numeric AS gel_voltage, NULL::numeric AS gel_run_time_minutes,
    NULL::text AS qpcr_id, NULL::date AS qpcr_date, NULL::numeric AS qpcr_ct_value, NULL::text AS qpcr_inhibitor_test_result, NULL::text AS qpcr_position, NULL::text AS qpcr_primer_id_actual, NULL::text AS qpcr_pcr_blank_id, NULL::text AS qpcr_kit, NULL::numeric AS qpcr_volume_ul,
    NULL::text AS library_id, NULL::date AS library_prep_date, NULL::text AS library_name, NULL::text AS library_prep_kit, NULL::text AS library_index_sequence, NULL::integer AS library_read_length_bp,
    NULL::text AS sequencing_id, NULL::date AS sequencing_date, NULL::text AS sequencer, NULL::text AS flow_cell_id, NULL::bigint AS total_reads, NULL::text AS raw_data_path, NULL::text AS genbank_accession_number, NULL::text AS sequencing_library_prep_kit, NULL::text AS sequencing_index_sequence, NULL::integer AS sequencing_read_length_bp,
    NULL::text AS analysis_run_id, NULL::text AS pipeline_name, NULL::text AS pipeline_version, NULL::text AS bioinfo_reference_database, NULL::text AS bioinfo_database_version, NULL::numeric AS clustering_threshold, NULL::text AS final_output_path,
    NULL::text AS edna_assignment_id, NULL::text AS edna_assigned_taxon_id, NULL::text AS edna_assigned_taxon_name, NULL::integer AS edna_read_count, NULL::numeric AS edna_confidence,
    e.experiment_id AS associated_experiment_id, e.experiment_title AS associated_experiment_title, e.experiment_date AS associated_experiment_date, e.aim AS associated_experiment_aim, e.method AS associated_experiment_method, exp_person.full_name AS experiment_person_name,
    NULL::text AS sampler_full_name, NULL::text AS receiver_full_name

FROM
    "lab"."water" w
LEFT JOIN "lims"."projects" p ON w.project_id = p.project_id
LEFT JOIN "lab"."experiments" e ON w.experiment_id = e.experiment_id AND w.experiment_date = e.experiment_date
LEFT JOIN "reference"."personal" exp_person ON e.person_id = exp_person.person_id

UNION ALL

SELECT
    oto.otolith_id AS sample_id,
    NULL AS external_name,
    oto.sample_id AS parent_sample_id,
    'Otolith Sample' AS sample_origin_type,
    'Otolith' AS sample_type_id,
    'O' AS sample_type_abrv,
    (SELECT status_id FROM "reference"."status" WHERE notes = 'Received') AS status_id,
    (SELECT notes FROM "reference"."status" WHERE status_id = 'Received') AS sample_status_notes,
    NULL::text AS sampling_id,
    oto.experiment_date AS sampling_date,
    NULL AS reception_date,
    oto.project_id,
    p.title AS project_title,
    NULL::integer AS customer_id,
    NULL::text AS customer_name,
    NULL::text AS storage_id,
    NULL::text AS storage_position,
    oto.notes,
    oto.attachment,
    oto.attachment_link,

    -- Sampling Event Details (NULL placeholders)
    NULL::numeric AS sampling_lon, NULL::numeric AS sampling_lat, NULL::numeric AS fishing_start_lon, NULL::numeric AS fishing_start_lat, NULL::numeric AS fishing_end_lon, NULL::numeric AS fishing_end_lat,
    NULL::text AS sampling_location, NULL::numeric AS sampling_depth_m, NULL::numeric AS temperature_atmospheric_c, NULL::text AS weather, NULL::numeric AS wind_speed, NULL::text AS wind_unit,
    NULL::numeric AS salinity, NULL::text AS salinity_unit, NULL::numeric AS oxygen, NULL::text AS oxygen_unit,

    -- Fish-specific Details (NULL)
    NULL::text AS fish_species_id, NULL::text AS fish_species_en_name, NULL::numeric AS fish_total_length_mm, NULL::numeric AS fish_fork_length_mm, NULL::numeric AS fish_standard_length_mm, NULL::numeric AS fish_weight_g, NULL::text AS fish_sex, NULL::text AS fish_maturity_stage, NULL::text AS fish_stomach_contents, NULL::text AS fish_disease_info, NULL::text AS fish_tag_id,

    -- Tissue-specific Details (NULL)
    NULL::numeric AS tissue_weight_mg, NULL::text AS tissue_type, NULL::text AS tissue_preservation_method,

    -- DNA-specific Details (NULL)
    NULL::numeric AS dna_volume_ul, NULL::numeric AS dna_concentration_ng_ul, NULL::numeric AS dna_a260_280, NULL::numeric AS dna_a260_230, NULL::text AS dna_extraction_method, NULL::date AS dna_extraction_date_dna, NULL::integer AS dna_extraction_number,

    -- RNA-specific Details (NULL)
    NULL::numeric AS rna_volume_ul, NULL::numeric AS rna_concentration_ng_ul, NULL::numeric AS rna_a260_280, NULL::numeric AS rna_a260_230, NULL::text AS rna_extraction_method, NULL::date AS rna_extraction_date_rna, NULL::integer AS rna_extraction_number,

    -- Sediments-specific Details (NULL)
    NULL::numeric AS sediment_volume, NULL::text AS sediment_volume_unit, NULL::numeric AS sediment_depth_m, NULL::text AS sediment_sampling_method, NULL::text AS sediment_conservation_buffer,

    -- Water-specific Details (NULL)
    NULL::numeric AS water_volume_l, NULL::text AS water_filter, NULL::numeric AS water_filter_pore_size_um, NULL::numeric AS water_depth_m, NULL::text AS water_sampling_method, NULL::text AS water_conservation_buffer,

    -- Otoliths-specific Details
    oto.otolith_id,
    oto.reader_person_id,
    oto.side,
    oto.age_reading_years,
    oto.confidence,

    -- All other specific details are NULL
    NULL::text AS dissection_id, NULL::text AS dissection_person_id, NULL::date AS dissection_date, NULL::jsonb AS dissection_stomach_contents_jsonb, NULL::numeric AS dissection_gonad_weight_g, NULL::numeric AS dissection_liver_weight_g,
    NULL::text AS extraction_id, NULL::date AS extraction_process_date, NULL::text AS extraction_process_person_id, NULL::text AS extraction_process_kit, NULL::numeric AS extraction_process_elution_volume_ul, NULL::numeric AS extraction_process_yield_qubit_ng_ul, NULL::numeric AS extraction_process_yield_nanodrop_ng_ul, NULL::numeric AS extraction_process_a260_280, NULL::numeric AS extraction_process_a260_230, NULL::text AS extraction_result_dna_sample_id, NULL::text AS extraction_result_rna_sample_id,
    NULL::text AS extraction_blank_id,
    NULL::text AS nanodrop_id, NULL::numeric AS nanodrop_concentration, NULL::text AS nanodrop_concentration_unit, NULL::numeric AS nanodrop_a260, NULL::numeric AS nanodrop_a260_280_qc, NULL::numeric AS nanodrop_a260_230_qc, NULL::numeric AS nanodrop_total_dna_ug, NULL::date AS nanodrop_measurement_date, NULL::text AS nanodrop_a260_280_note, NULL::text AS nanodrop_a260_230_note,
    NULL::text AS qubit_id, NULL::numeric AS qubit_original_sample_conc, NULL::text AS qubit_original_sample_unit, NULL::numeric AS qubit_total_dna_ug, NULL::date AS qubit_measurement_date, NULL::text AS qubit_assay_kit, NULL::numeric AS qubit_tube_conc, NULL::text AS tube_unit_id, NULL::numeric AS sample_volume_ul, NULL::numeric AS elution_volume_ul,
    NULL::text AS tapestation_id, NULL::date AS tapestation_measurement_date, NULL::text AS tapestation_kit,
    NULL::text AS pcr_id, NULL::date AS pcr_date, NULL::text AS pcr_primer_id, NULL::text AS pcr_target_gene_id, NULL::numeric AS pcr_volume_reaction_ul, NULL::text AS pcr_blank_id, NULL::text AS pcr_position,
    NULL::text AS gel_gelelectrophoresis_id, NULL::date AS gel_run_date, NULL::integer AS gel_band_size_bp, NULL::text AS gel_gel_type, NULL::text AS gel_position, NULL::text AS gel_ladder, NULL::numeric AS gel_voltage, NULL::numeric AS gel_run_time_minutes,
    NULL::text AS qpcr_id, NULL::date AS qpcr_date, NULL::numeric AS qpcr_ct_value, NULL::text AS qpcr_inhibitor_test_result, NULL::text AS qpcr_position, NULL::text AS qpcr_primer_id_actual, NULL::text AS qpcr_pcr_blank_id, NULL::text AS qpcr_kit, NULL::numeric AS qpcr_volume_ul,
    NULL::text AS library_id, NULL::date AS library_prep_date, NULL::text AS library_name, NULL::text AS library_prep_kit, NULL::text AS library_index_sequence, NULL::integer AS library_read_length_bp,
    NULL::text AS sequencing_id, NULL::date AS sequencing_date, NULL::text AS sequencer, NULL::text AS flow_cell_id, NULL::bigint AS total_reads, NULL::text AS raw_data_path, NULL::text AS genbank_accession_number, NULL::text AS sequencing_library_prep_kit, NULL::text AS sequencing_index_sequence, NULL::integer AS sequencing_read_length_bp,
    NULL::text AS analysis_run_id, NULL::text AS pipeline_name, NULL::text AS pipeline_version, NULL::text AS bioinfo_reference_database, NULL::text AS bioinfo_database_version, NULL::numeric AS clustering_threshold, NULL::text AS final_output_path,
    NULL::text AS edna_assignment_id, NULL::text AS edna_assigned_taxon_id, NULL::text AS edna_assigned_taxon_name, NULL::integer AS edna_read_count, NULL::numeric AS edna_confidence,
    e.experiment_id AS associated_experiment_id, e.experiment_title AS associated_experiment_title, e.experiment_date AS associated_experiment_date, e.aim AS associated_experiment_aim, e.method AS associated_experiment_method, exp_person.full_name AS experiment_person_name,
    NULL::text AS sampler_full_name, NULL::text AS receiver_full_name
FROM
    "lab"."otoliths" oto
LEFT JOIN "lims"."projects" p ON oto.project_id = p.project_id
LEFT JOIN "lab"."experiments" e ON oto.experiment_id = e.experiment_id AND oto.experiment_date = e.experiment_date
LEFT JOIN "reference"."personal" exp_person ON e.person_id = exp_person.person_id

UNION ALL

SELECT
    ext.extraction_id AS sample_id,
    NULL AS external_name,
    ext.sample_id AS parent_sample_id,
    'Extraction Product' AS sample_origin_type,
    'Extraction' AS sample_type_id,
    'EXT' AS sample_type_abrv,
    ext.status_id AS status_id,
    stat.notes AS sample_status_notes,
    NULL::text AS sampling_id,
    ext.extraction_date AS sampling_date,
    NULL::date AS reception_date, 
    ext.project_id,
    p.title AS project_title,
    NULL::integer AS customer_id,
    NULL::text AS customer_name,
    ext.storage_id,
    ext.storage_position,
    ext.notes,
    ext.attachment,
    ext.attachment_link,

    -- Sampling Event Details (NULL)
    NULL::numeric AS sampling_lon, NULL::numeric AS sampling_lat, NULL::numeric AS fishing_start_lon, NULL::numeric AS fishing_start_lat, NULL::numeric AS fishing_end_lon, NULL::numeric AS fishing_end_lat,
    NULL::text AS sampling_location, NULL::numeric AS sampling_depth_m, NULL::numeric AS temperature_atmospheric_c, NULL::text AS weather, NULL::numeric AS wind_speed, NULL::text AS wind_unit,
    NULL::numeric AS salinity, NULL::text AS salinity_unit, NULL::numeric AS oxygen, NULL::text AS oxygen_unit,

    -- Fish-specific Details (NULL)
    NULL::text AS fish_species_id, NULL::text AS fish_species_en_name, NULL::numeric AS fish_total_length_mm, NULL::numeric AS fish_fork_length_mm, NULL::numeric AS fish_standard_length_mm, NULL::numeric AS fish_weight_g, NULL::text AS fish_sex, NULL::text AS fish_maturity_stage, NULL::text AS fish_stomach_contents, NULL::text AS fish_disease_info, NULL::text AS fish_tag_id,

    -- Tissue-specific Details (NULL)
    NULL::numeric AS tissue_weight_mg, NULL::text AS tissue_type, NULL::text AS tissue_preservation_method,

    -- DNA-specific Details (NULL for extraction output, since these are in lab.dna/rna tables already)
    NULL::numeric AS dna_volume_ul, NULL::numeric AS dna_concentration_ng_ul, NULL::numeric AS dna_a260_280, NULL::numeric AS dna_a260_230, NULL::text AS dna_extraction_method, NULL::date AS dna_extraction_date_dna, NULL::integer AS dna_extraction_number,

    -- RNA-specific Details (NULL for extraction output, since these are in lab.dna/rna tables already)
    NULL::numeric AS rna_volume_ul, NULL::numeric AS rna_concentration_ng_ul, NULL::numeric AS rna_a260_280, NULL::numeric AS rna_a260_230, NULL::text AS rna_extraction_method, NULL::date AS rna_extraction_date_rna, NULL::integer AS rna_extraction_number,

    -- Sediments-specific Details (NULL)
    NULL::numeric AS sediment_volume, NULL::text AS sediment_volume_unit, NULL::numeric AS sediment_depth_m, NULL::text AS sediment_sampling_method, NULL::text AS sediment_conservation_buffer,

    -- Water-specific Details (NULL)
    NULL::numeric AS water_volume_l, NULL::text AS water_filter, NULL::numeric AS water_filter_pore_size_um, NULL::numeric AS water_depth_m, NULL::text AS water_sampling_method, NULL::text AS water_conservation_buffer,

    -- Otoliths-specific Details (NULL)
    NULL::text AS otolith_id, NULL::text AS otolith_reader_person_id, NULL::text AS otolith_side, NULL::numeric AS otolith_age_reading_years, NULL::numeric AS otolith_confidence,

    -- Dissections Details (NULL)
    NULL::text AS dissection_id, NULL::text AS dissection_person_id, NULL::date AS dissection_date, NULL::jsonb AS dissection_stomach_contents_jsonb, NULL::numeric AS dissection_gonad_weight_g, NULL::numeric AS dissection_liver_weight_g,

    -- Extraction Details (from lab.extraction, these are the *process* details for this row)
    ext.extraction_id,
    ext.extraction_date AS extraction_process_date,
    ext.person_id AS extraction_process_person_id,
    ext.kit AS extraction_process_kit,
    ext.elution_volume_ul AS extraction_process_elution_volume_ul,
    ext.yield_qubit_ng_ul AS extraction_process_yield_qubit_ng_ul,
    ext.yield_nanodrop_ng_ul AS extraction_process_yield_nanodrop_ng_ul,
    ext.a260_280 AS extraction_process_a260_280,
    ext.a260_230 AS extraction_process_a260_230,
    ext.extracted_dna_sample_id AS extraction_result_dna_sample_id,
    ext.extracted_rna_sample_id AS extraction_result_rna_sample_id,
    ext.extraction_blank_id,

    -- All other specific details are NULL
    NULL::text AS nanodrop_id, NULL::numeric AS nanodrop_concentration, NULL::text AS nanodrop_concentration_unit, NULL::numeric AS nanodrop_a260, NULL::numeric AS nanodrop_a260_280_qc, NULL::numeric AS nanodrop_a260_230_qc, NULL::numeric AS nanodrop_total_dna_ug, NULL::date AS nanodrop_measurement_date, NULL::text AS nanodrop_a260_280_note, NULL::text AS nanodrop_a260_230_note,
    NULL::text AS qubit_id, NULL::numeric AS qubit_original_sample_conc, NULL::text AS qubit_original_sample_unit, NULL::numeric AS qubit_total_dna_ug, NULL::date AS qubit_measurement_date, NULL::text AS qubit_assay_kit, NULL::numeric AS qubit_tube_conc, NULL::text AS tube_unit_id, NULL::numeric AS sample_volume_ul, NULL::numeric AS elution_volume_ul,
    NULL::text AS tapestation_id, NULL::date AS tapestation_measurement_date, NULL::text AS tapestation_kit,
    NULL::text AS pcr_id, NULL::date AS pcr_date, NULL::text AS pcr_primer_id, NULL::text AS pcr_target_gene_id, NULL::numeric AS pcr_volume_reaction_ul, NULL::text AS pcr_blank_id, NULL::text AS pcr_position,
    NULL::text AS gel_gelelectrophoresis_id, NULL::date AS gel_run_date, NULL::integer AS gel_band_size_bp, NULL::text AS gel_gel_type, NULL::text AS gel_position, NULL::text AS gel_ladder, NULL::numeric AS gel_voltage, NULL::numeric AS gel_run_time_minutes,
    NULL::text AS qpcr_id, NULL::date AS qpcr_date, NULL::numeric AS qpcr_ct_value, NULL::text AS qpcr_inhibitor_test_result, NULL::text AS qpcr_position, NULL::text AS qpcr_primer_id_actual, NULL::text AS qpcr_pcr_blank_id, NULL::text AS qpcr_kit, NULL::numeric AS qpcr_volume_ul,
    NULL::text AS library_id, NULL::date AS library_prep_date, NULL::text AS library_name, NULL::text AS library_prep_kit, NULL::text AS library_index_sequence, NULL::integer AS library_read_length_bp,
    NULL::text AS sequencing_id, NULL::date AS sequencing_date, NULL::text AS sequencer, NULL::text AS flow_cell_id, NULL::bigint AS total_reads, NULL::text AS raw_data_path, NULL::text AS genbank_accession_number, NULL::text AS sequencing_library_prep_kit, NULL::text AS sequencing_index_sequence, NULL::integer AS sequencing_read_length_bp,
    NULL::text AS analysis_run_id, NULL::text AS pipeline_name, NULL::text AS pipeline_version, NULL::text AS bioinfo_reference_database, NULL::text AS bioinfo_database_version, NULL::numeric AS clustering_threshold, NULL::text AS final_output_path,
    NULL::text AS edna_assignment_id, NULL::text AS edna_assigned_taxon_id, NULL::text AS edna_assigned_taxon_name, NULL::integer AS edna_read_count, NULL::numeric AS edna_confidence,
    e.experiment_id AS associated_experiment_id, e.experiment_title AS associated_experiment_title, e.experiment_date AS associated_experiment_date, e.aim AS associated_experiment_aim, e.method AS associated_experiment_method, exp_person.full_name AS experiment_person_name,
    NULL::text AS sampler_full_name, NULL::text AS receiver_full_name

FROM
    "lab"."extraction" ext
LEFT JOIN "lims"."projects" p ON ext.project_id = p.project_id
LEFT JOIN "reference"."status" stat ON ext.status_id = stat.status_id
LEFT JOIN "lab"."experiments" e ON ext.experiment_id = e.experiment_id AND ext.experiment_date = e.experiment_date
LEFT JOIN "reference"."personal" exp_person ON e.person_id = exp_person.person_id

UNION ALL

SELECT
    nd.nanodrop_id AS sample_id,
    NULL AS external_name,
    nd.sample_id AS parent_sample_id,
    'Nanodrop QC Record' AS sample_origin_type,
    'NDQC' AS sample_type_id,
    'NDQC' AS sample_type_abrv,
    nd.status_id AS status_id,
    stat.notes AS sample_status_notes,
    NULL::text AS sampling_id,
    nd.measurement_date AS sampling_date,
    NULL AS reception_date,
    nd.project_id,
    p.title AS project_title,
    NULL::integer AS customer_id,
    NULL::text AS customer_name,
    nd.storage_id,
    nd.storage_position,
    nd.notes,
    nd.attachment,
    nd.attachment_link,

    -- All other specific details are NULL
    NULL::numeric AS sampling_lon, NULL::numeric AS sampling_lat, NULL::numeric AS fishing_start_lon, NULL::numeric AS fishing_start_lat, NULL::numeric AS fishing_end_lon, NULL::numeric AS fishing_end_lat,
    NULL::text AS sampling_location, NULL::numeric AS sampling_depth_m, NULL::numeric AS temperature_atmospheric_c, NULL::text AS weather, NULL::numeric AS wind_speed, NULL::text AS wind_unit,
    NULL::numeric AS salinity, NULL::text AS salinity_unit, NULL::numeric AS oxygen, NULL::text AS oxygen_unit,
    NULL::text AS fish_species_id, NULL::text AS fish_species_en_name, NULL::numeric AS fish_total_length_mm, NULL::numeric AS fish_fork_length_mm, NULL::numeric AS fish_standard_length_mm, NULL::numeric AS fish_weight_g, NULL::text AS fish_sex, NULL::text AS fish_maturity_stage, NULL::text AS fish_stomach_contents, NULL::text AS fish_disease_info, NULL::text AS fish_tag_id,
    NULL::numeric AS tissue_weight_mg, NULL::text AS tissue_type, NULL::text AS tissue_preservation_method,
    NULL::numeric AS dna_volume_ul, NULL::numeric AS dna_concentration_ng_ul, NULL::numeric AS dna_a260_280, NULL::numeric AS dna_a260_230, NULL::text AS dna_extraction_method, NULL::date AS dna_extraction_date_dna, NULL::integer AS dna_extraction_number,
    NULL::numeric AS rna_volume_ul, NULL::numeric AS rna_concentration_ng_ul, NULL::numeric AS rna_a260_280, NULL::numeric AS rna_a260_230, NULL::text AS rna_extraction_method, NULL::date AS rna_extraction_date_rna, NULL::integer AS rna_extraction_number,
    NULL::numeric AS sediment_volume, NULL::text AS sediment_volume_unit, NULL::numeric AS sediment_depth_m, NULL::text AS sediment_sampling_method, NULL::text AS sediment_conservation_buffer,
    NULL::numeric AS water_volume_l, NULL::text AS water_filter, NULL::numeric AS water_filter_pore_size_um, NULL::numeric AS water_depth_m, NULL::text AS water_sampling_method, NULL::text AS water_conservation_buffer,
    NULL::text AS otolith_id, NULL::text AS otolith_reader_person_id, NULL::text AS otolith_side, NULL::numeric AS otolith_age_reading_years, NULL::numeric AS otolith_confidence,
    NULL::text AS dissection_id, NULL::text AS dissection_person_id, NULL::date AS dissection_date, NULL::jsonb AS dissection_stomach_contents_jsonb, NULL::numeric AS dissection_gonad_weight_g, NULL::numeric AS dissection_liver_weight_g,
    NULL::text AS extraction_id, NULL::date AS extraction_process_date, NULL::text AS extraction_process_person_id, NULL::text AS extraction_process_kit, NULL::numeric AS extraction_process_elution_volume_ul, NULL::numeric AS extraction_process_yield_qubit_ng_ul, NULL::numeric AS extraction_process_yield_nanodrop_ng_ul, NULL::numeric AS extraction_process_a260_280, NULL::numeric AS extraction_process_a260_230, NULL::text AS extraction_result_dna_sample_id, NULL::text AS extraction_result_rna_sample_id,
    NULL::text AS extraction_blank_id,
    nd.nanodrop_id,
    nd.nanodrop_concentration,
    ndcu.unit_abbreviation AS nanodrop_concentration_unit,
    nd.a260,
    nd.a260_280 AS nanodrop_a260_280_qc,
    nd.a260_230 AS nanodrop_a260_230_qc,
    nd.nanodrop_total_dna_ug,
    nd.measurement_date,
    nd.a260_280_note,
    nd.a260_230_note,
    NULL::text AS qubit_id, NULL::numeric AS qubit_original_sample_conc, NULL::text AS qubit_original_sample_unit, NULL::numeric AS qubit_total_dna_ug, NULL::date AS qubit_measurement_date, NULL::text AS qubit_assay_kit, NULL::numeric AS qubit_tube_conc, NULL::text AS tube_unit_id, NULL::numeric AS sample_volume_ul, NULL::numeric AS elution_volume_ul,
    NULL::text AS tapestation_id, NULL::date AS tapestation_measurement_date, NULL::text AS tapestation_kit,
    NULL::text AS pcr_id, NULL::date AS pcr_date, NULL::text AS pcr_primer_id, NULL::text AS pcr_target_gene_id, NULL::numeric AS pcr_volume_reaction_ul, NULL::text AS pcr_blank_id, NULL::text AS pcr_position,
    NULL::text AS gel_gelelectrophoresis_id, NULL::date AS gel_run_date, NULL::integer AS gel_band_size_bp, NULL::text AS gel_gel_type, NULL::text AS gel_position, NULL::text AS gel_ladder, NULL::numeric AS gel_voltage, NULL::numeric AS gel_run_time_minutes,
    NULL::text AS qpcr_id, NULL::date AS qpcr_date, NULL::numeric AS qpcr_ct_value, NULL::text AS qpcr_inhibitor_test_result, NULL::text AS qpcr_position, NULL::text AS qpcr_primer_id_actual, NULL::text AS qpcr_pcr_blank_id, NULL::text AS qpcr_kit, NULL::numeric AS qpcr_volume_ul,
    NULL::text AS library_id, NULL::date AS library_prep_date, NULL::text AS library_name, NULL::text AS library_prep_kit, NULL::text AS library_index_sequence, NULL::integer AS library_read_length_bp,
    NULL::text AS sequencing_id, NULL::date AS sequencing_date, NULL::text AS sequencer, NULL::text AS flow_cell_id, NULL::bigint AS total_reads, NULL::text AS raw_data_path, NULL::text AS genbank_accession_number, NULL::text AS sequencing_library_prep_kit, NULL::text AS sequencing_index_sequence, NULL::integer AS sequencing_read_length_bp,
    NULL::text AS analysis_run_id, NULL::text AS pipeline_name, NULL::text AS pipeline_version, NULL::text AS bioinfo_reference_database, NULL::text AS bioinfo_database_version, NULL::numeric AS clustering_threshold, NULL::text AS final_output_path,
    NULL::text AS edna_assignment_id, NULL::text AS edna_assigned_taxon_id, NULL::text AS edna_assigned_taxon_name, NULL::integer AS edna_read_count, NULL::numeric AS edna_confidence,
    e.experiment_id AS associated_experiment_id, e.experiment_title AS associated_experiment_title, e.experiment_date AS associated_experiment_date, e.aim AS associated_experiment_aim, e.method AS associated_experiment_method, exp_person.full_name AS experiment_person_name,
    NULL::text AS sampler_full_name, NULL::text AS receiver_full_name

FROM
    "lab"."nanodrop" nd
LEFT JOIN "lims"."projects" p ON nd.project_id = p.project_id
LEFT JOIN "reference"."status" stat ON nd.status_id = stat.status_id
LEFT JOIN "reference"."units" ndcu ON nd.concentration_unit_id = ndcu.unit_id
LEFT JOIN "lab"."experiments" e ON nd.experiment_id = e.experiment_id AND nd.experiment_date = e.experiment_date
LEFT JOIN "reference"."personal" exp_person ON e.person_id = exp_person.person_id

UNION ALL

SELECT
    qu.qubit_id AS sample_id,
    NULL AS external_name,
    qu.sample_id AS parent_sample_id,
    'Qubit QC Record' AS sample_origin_type,
    'QubitQC' AS sample_type_id,
    'QBC' AS sample_type_abrv,
    qu.status_id AS status_id,
    stat.notes AS sample_status_notes,
    NULL::text AS sampling_id,
    qu.measurement_date AS sampling_date,
    NULL AS reception_date,
    qu.project_id,
    p.title AS project_title,
    NULL::integer AS customer_id,
    NULL::text AS customer_name,
    qu.storage_id,
    qu.storage_position,
    qu.notes,
    qu.attachment,
    qu.attachment_link,

    -- All other specific details are NULL
    NULL::numeric AS sampling_lon, NULL::numeric AS sampling_lat, NULL::numeric AS fishing_start_lon, NULL::numeric AS fishing_start_lat, NULL::numeric AS fishing_end_lon, NULL::numeric AS fishing_end_lat,
    NULL::text AS sampling_location, NULL::numeric AS sampling_depth_m, NULL::numeric AS temperature_atmospheric_c, NULL::text AS weather, NULL::numeric AS wind_speed, NULL::text AS wind_unit,
    NULL::numeric AS salinity, NULL::text AS salinity_unit, NULL::numeric AS oxygen, NULL::text AS oxygen_unit,
    NULL::text AS fish_species_id, NULL::text AS fish_species_en_name, NULL::numeric AS fish_total_length_mm, NULL::numeric AS fish_fork_length_mm, NULL::numeric AS fish_standard_length_mm, NULL::numeric AS fish_weight_g, NULL::text AS fish_sex, NULL::text AS fish_maturity_stage, NULL::text AS fish_stomach_contents, NULL::text AS fish_disease_info, NULL::text AS fish_tag_id,
    NULL::numeric AS tissue_weight_mg, NULL::text AS tissue_type, NULL::text AS tissue_preservation_method,
    NULL::numeric AS dna_volume_ul, NULL::numeric AS dna_concentration_ng_ul, NULL::numeric AS dna_a260_280, NULL::numeric AS dna_a260_230, NULL::text AS dna_extraction_method, NULL::date AS dna_extraction_date_dna, NULL::integer AS dna_extraction_number,
    NULL::numeric AS rna_volume_ul, NULL::numeric AS rna_concentration_ng_ul, NULL::numeric AS rna_a260_280, NULL::numeric AS rna_a260_230, NULL::text AS rna_extraction_method, NULL::date AS rna_extraction_date_rna, NULL::integer AS rna_extraction_number,
    NULL::numeric AS sediment_volume, NULL::text AS sediment_volume_unit, NULL::numeric AS sediment_depth_m, NULL::text AS sediment_sampling_method, NULL::text AS sediment_conservation_buffer,
    NULL::numeric AS water_volume_l, NULL::text AS water_filter, NULL::numeric AS water_filter_pore_size_um, NULL::numeric AS water_depth_m, NULL::text AS water_sampling_method, NULL::text AS water_conservation_buffer,
    NULL::text AS otolith_id, NULL::text AS otolith_reader_person_id, NULL::text AS otolith_side, NULL::numeric AS otolith_age_reading_years, NULL::numeric AS otolith_confidence,
    NULL::text AS dissection_id, NULL::text AS dissection_person_id, NULL::date AS dissection_date, NULL::jsonb AS dissection_stomach_contents_jsonb, NULL::numeric AS dissection_gonad_weight_g, NULL::numeric AS dissection_liver_weight_g,
    NULL::text AS extraction_id, NULL::date AS extraction_process_date, NULL::text AS extraction_process_person_id, NULL::text AS extraction_process_kit, NULL::numeric AS extraction_process_elution_volume_ul, NULL::numeric AS extraction_process_yield_qubit_ng_ul, NULL::numeric AS extraction_process_yield_nanodrop_ng_ul, NULL::numeric AS extraction_process_a260_280, NULL::numeric AS extraction_process_a260_230, NULL::text AS extraction_result_dna_sample_id, NULL::text AS extraction_result_rna_sample_id,
    NULL::text AS extraction_blank_id,
    NULL::text AS nanodrop_id, NULL::numeric AS nanodrop_concentration, NULL::text AS nanodrop_concentration_unit, NULL::numeric AS nanodrop_a260, NULL::numeric AS nanodrop_a260_280_qc, NULL::numeric AS nanodrop_a260_230_qc, NULL::numeric AS nanodrop_total_dna_ug, NULL::date AS nanodrop_measurement_date, NULL::text AS nanodrop_a260_280_note, NULL::text AS nanodrop_a260_230_note,
    qu.qubit_id,
    qu.qubit_original_sample_conc,
    quosu.unit_abbreviation AS qubit_original_sample_unit,
    qu.qubit_total_dna_ug,
    qu.measurement_date,
    qu.assay_kit,
    qu.qubit_tube_conc,
    qu.tube_unit_id,
    qu.sample_volume_ul,
    qu.elution_volume_ul,
    NULL::text AS tapestation_id, NULL::date AS tapestation_measurement_date, NULL::text AS tapestation_kit,
    NULL::text AS pcr_id, NULL::date AS pcr_date, NULL::text AS pcr_primer_id, NULL::text AS pcr_target_gene_id, NULL::numeric AS pcr_volume_reaction_ul, NULL::text AS pcr_blank_id, NULL::text AS pcr_position,
    NULL::text AS gel_gelelectrophoresis_id, NULL::date AS gel_run_date, NULL::integer AS gel_band_size_bp, NULL::text AS gel_gel_type, NULL::text AS gel_position, NULL::text AS gel_ladder, NULL::numeric AS gel_voltage, NULL::numeric AS gel_run_time_minutes,
    NULL::text AS qpcr_id, NULL::date AS qpcr_date, NULL::numeric AS qpcr_ct_value, NULL::text AS qpcr_inhibitor_test_result, NULL::text AS qpcr_position, NULL::text AS qpcr_primer_id_actual, NULL::text AS qpcr_pcr_blank_id, NULL::text AS qpcr_kit, NULL::numeric AS qpcr_volume_ul,
    NULL::text AS library_id, NULL::date AS library_prep_date, NULL::text AS library_name, NULL::text AS library_prep_kit, NULL::text AS library_index_sequence, NULL::integer AS library_read_length_bp,
    NULL::text AS sequencing_id, NULL::date AS sequencing_date, NULL::text AS sequencer, NULL::text AS flow_cell_id, NULL::bigint AS total_reads, NULL::text AS raw_data_path, NULL::text AS genbank_accession_number, NULL::text AS sequencing_library_prep_kit, NULL::text AS sequencing_index_sequence, NULL::integer AS sequencing_read_length_bp,
    NULL::text AS analysis_run_id, NULL::text AS pipeline_name, NULL::text AS pipeline_version, NULL::text AS bioinfo_reference_database, NULL::text AS bioinfo_database_version, NULL::numeric AS clustering_threshold, NULL::text AS final_output_path,
    NULL::text AS edna_assignment_id, NULL::text AS edna_assigned_taxon_id, NULL::text AS edna_assigned_taxon_name, NULL::integer AS edna_read_count, NULL::numeric AS edna_confidence,
    e.experiment_id AS associated_experiment_id, e.experiment_title AS associated_experiment_title, e.experiment_date AS associated_experiment_date, e.aim AS associated_experiment_aim, e.method AS associated_experiment_method, exp_person.full_name AS experiment_person_name,
    NULL::text AS sampler_full_name, NULL::text AS receiver_full_name
FROM
    "lab"."qubit" qu
LEFT JOIN "lims"."projects" p ON qu.project_id = p.project_id
LEFT JOIN "reference"."status" stat ON qu.status_id = stat.status_id
LEFT JOIN "reference"."units" quosu ON qu.original_sample_unit_id = quosu.unit_id
LEFT JOIN "lab"."experiments" e ON qu.experiment_id = e.experiment_id AND qu.experiment_date = e.experiment_date
LEFT JOIN "reference"."personal" exp_person ON e.person_id = exp_person.person_id

UNION ALL

SELECT
    ts.tapestation_id AS sample_id,
    NULL AS external_name,
    ts.sample_id AS parent_sample_id,
    'Tapestation QC Record' AS sample_origin_type,
    'TSQC' AS sample_type_id,
    'TSQC' AS sample_type_abrv,
    ts.status_id AS status_id,
    stat.notes AS sample_status_notes,
    NULL::text AS sampling_id,
    ts.measurement_date AS sampling_date,
    NULL AS reception_date,
    ts.project_id,
    p.title AS project_title,
    NULL::integer AS customer_id,
    NULL::text AS customer_name,
    ts.storage_id,
    ts.storage_position,
    ts.notes,
    ts.attachment,
    ts.attachment_link,

    -- All other specific details are NULL
    NULL::numeric AS sampling_lon, NULL::numeric AS sampling_lat, NULL::numeric AS fishing_start_lon, NULL::numeric AS fishing_start_lat, NULL::numeric AS fishing_end_lon, NULL::numeric AS fishing_end_lat,
    NULL::text AS sampling_location, NULL::numeric AS sampling_depth_m, NULL::numeric AS temperature_atmospheric_c, NULL::text AS weather, NULL::numeric AS wind_speed, NULL::text AS wind_unit,
    NULL::numeric AS salinity, NULL::text AS salinity_unit, NULL::numeric AS oxygen, NULL::text AS oxygen_unit,
    NULL::text AS fish_species_id, NULL::text AS fish_species_en_name, NULL::numeric AS fish_total_length_mm, NULL::numeric AS fish_fork_length_mm, NULL::numeric AS fish_standard_length_mm, NULL::numeric AS fish_weight_g, NULL::text AS fish_sex, NULL::text AS fish_maturity_stage, NULL::text AS fish_stomach_contents, NULL::text AS fish_disease_info, NULL::text AS fish_tag_id,
    NULL::numeric AS tissue_weight_mg, NULL::text AS tissue_type, NULL::text AS tissue_preservation_method,
    NULL::numeric AS dna_volume_ul, NULL::numeric AS dna_concentration_ng_ul, NULL::numeric AS dna_a260_280, NULL::numeric AS dna_a260_230, NULL::text AS dna_extraction_method, NULL::date AS dna_extraction_date_dna, NULL::integer AS dna_extraction_number,
    NULL::numeric AS rna_volume_ul, NULL::numeric AS rna_concentration_ng_ul, NULL::numeric AS rna_a260_280, NULL::numeric AS rna_a260_230, NULL::text AS rna_extraction_method, NULL::date AS rna_extraction_date_rna, NULL::integer AS rna_extraction_number,
    NULL::numeric AS sediment_volume, NULL::text AS sediment_volume_unit, NULL::numeric AS sediment_depth_m, NULL::text AS sediment_sampling_method, NULL::text AS sediment_conservation_buffer,
    NULL::numeric AS water_volume_l, NULL::text AS water_filter, NULL::numeric AS water_filter_pore_size_um, NULL::numeric AS water_depth_m, NULL::text AS water_sampling_method, NULL::text AS water_conservation_buffer,
    NULL::text AS otolith_id, NULL::text AS otolith_reader_person_id, NULL::text AS otolith_side, NULL::numeric AS otolith_age_reading_years, NULL::numeric AS otolith_confidence,
    NULL::text AS dissection_id, NULL::text AS dissection_person_id, NULL::date AS dissection_date, NULL::jsonb AS dissection_stomach_contents_jsonb, NULL::numeric AS dissection_gonad_weight_g, NULL::numeric AS dissection_liver_weight_g,
    NULL::text AS extraction_id, NULL::date AS extraction_process_date, NULL::text AS extraction_process_person_id, NULL::text AS extraction_process_kit, NULL::numeric AS extraction_process_elution_volume_ul, NULL::numeric AS extraction_process_yield_qubit_ng_ul, NULL::numeric AS extraction_process_yield_nanodrop_ng_ul, NULL::numeric AS extraction_process_a260_280, NULL::numeric AS extraction_process_a260_230, NULL::text AS extraction_result_dna_sample_id, NULL::text AS extraction_result_rna_sample_id,
    NULL::text AS extraction_blank_id,
    NULL::text AS nanodrop_id, NULL::numeric AS nanodrop_concentration, NULL::text AS nanodrop_concentration_unit, NULL::numeric AS nanodrop_a260, NULL::numeric AS nanodrop_a260_280_qc, NULL::numeric AS nanodrop_a260_230_qc, NULL::numeric AS nanodrop_total_dna_ug, NULL::date AS nanodrop_measurement_date, NULL::text AS nanodrop_a260_280_note, NULL::text AS nanodrop_a260_230_note,
    NULL::text AS qubit_id, NULL::numeric AS qubit_original_sample_conc, NULL::text AS qubit_original_sample_unit, NULL::numeric AS qubit_total_dna_ug, NULL::date AS qubit_measurement_date, NULL::text AS qubit_assay_kit, NULL::numeric AS qubit_tube_conc, NULL::text AS tube_unit_id, NULL::numeric AS sample_volume_ul, NULL::numeric AS elution_volume_ul,
    ts.tapestation_id,
    ts.measurement_date,
    ts.kit,
    NULL::text AS pcr_id, NULL::date AS pcr_date, NULL::text AS pcr_primer_id, NULL::text AS pcr_target_gene_id, NULL::numeric AS pcr_volume_reaction_ul, NULL::text AS pcr_blank_id, NULL::text AS pcr_position,
    NULL::text AS gel_gelelectrophoresis_id, NULL::date AS gel_run_date, NULL::integer AS gel_band_size_bp, NULL::text AS gel_gel_type, NULL::text AS gel_position, NULL::text AS gel_ladder, NULL::numeric AS gel_voltage, NULL::numeric AS gel_run_time_minutes,
    NULL::text AS qpcr_id, NULL::date AS qpcr_date, NULL::numeric AS qpcr_ct_value, NULL::text AS qpcr_inhibitor_test_result, NULL::text AS qpcr_position, NULL::text AS qpcr_primer_id_actual, NULL::text AS qpcr_pcr_blank_id, NULL::text AS qpcr_kit, NULL::numeric AS qpcr_volume_ul,
    NULL::text AS library_id, NULL::date AS library_prep_date, NULL::text AS library_name, NULL::text AS library_prep_kit, NULL::text AS library_index_sequence, NULL::integer AS library_read_length_bp,
    NULL::text AS sequencing_id, NULL::date AS sequencing_date, NULL::text AS sequencer, NULL::text AS flow_cell_id, NULL::bigint AS total_reads, NULL::text AS raw_data_path, NULL::text AS genbank_accession_number, NULL::text AS sequencing_library_prep_kit, NULL::text AS sequencing_index_sequence, NULL::integer AS sequencing_read_length_bp,
    NULL::text AS analysis_run_id, NULL::text AS pipeline_name, NULL::text AS pipeline_version, NULL::text AS bioinfo_reference_database, NULL::text AS bioinfo_database_version, NULL::numeric AS clustering_threshold, NULL::text AS final_output_path,
    NULL::text AS edna_assignment_id, NULL::text AS edna_assigned_taxon_id, NULL::text AS edna_assigned_taxon_name, NULL::integer AS edna_read_count, NULL::numeric AS edna_confidence,
    e.experiment_id AS associated_experiment_id, e.experiment_title AS associated_experiment_title, e.experiment_date AS associated_experiment_date, e.aim AS associated_experiment_aim, e.method AS associated_experiment_method, exp_person.full_name AS experiment_person_name,
    NULL::text AS sampler_full_name, NULL::text AS receiver_full_name
FROM
    "lab"."tapestation" ts
LEFT JOIN "lims"."projects" p ON ts.project_id = p.project_id
LEFT JOIN "reference"."status" stat ON ts.status_id = stat.status_id
LEFT JOIN "lab"."experiments" e ON ts.experiment_id = e.experiment_id AND ts.experiment_date = e.experiment_date
LEFT JOIN "reference"."personal" exp_person ON e.person_id = exp_person.person_id

UNION ALL

SELECT
    pcr.pcr_id AS sample_id,
    NULL AS external_name,
    pcr.sample_id AS parent_sample_id,
    'PCR Product' AS sample_origin_type,
    'PCRP' AS sample_type_id,
    'PCRP' AS sample_type_abrv,
    pcr.status_id AS status_id,
    stat.notes AS sample_status_notes,
    NULL::text AS sampling_id,
    pcr.pcr_date AS sampling_date,
    NULL AS reception_date,
    pcr.project_id,
    p.title AS project_title,
    NULL::integer AS customer_id,
    NULL::text AS customer_name,
    pcr.storage_id,
    pcr.storage_position,
    pcr.notes,
    pcr.attachment,
    pcr.attachment_link,

    -- All other specific details are NULL
    NULL::numeric AS sampling_lon, NULL::numeric AS sampling_lat, NULL::numeric AS fishing_start_lon, NULL::numeric AS fishing_start_lat, NULL::numeric AS fishing_end_lon, NULL::numeric AS fishing_end_lat,
    NULL::text AS sampling_location, NULL::numeric AS sampling_depth_m, NULL::numeric AS temperature_atmospheric_c, NULL::text AS weather, NULL::numeric AS wind_speed, NULL::text AS wind_unit,
    NULL::numeric AS salinity, NULL::text AS salinity_unit, NULL::numeric AS oxygen, NULL::text AS oxygen_unit,
    NULL::text AS fish_species_id, NULL::text AS fish_species_en_name, NULL::numeric AS fish_total_length_mm, NULL::numeric AS fish_fork_length_mm, NULL::numeric AS fish_standard_length_mm, NULL::numeric AS fish_weight_g, NULL::text AS fish_sex, NULL::text AS fish_maturity_stage, NULL::text AS fish_stomach_contents, NULL::text AS fish_disease_info, NULL::text AS fish_tag_id,
    NULL::numeric AS tissue_weight_mg, NULL::text AS tissue_type, NULL::text AS tissue_preservation_method,
    NULL::numeric AS dna_volume_ul, NULL::numeric AS dna_concentration_ng_ul, NULL::numeric AS dna_a260_280, NULL::numeric AS dna_a260_230, NULL::text AS dna_extraction_method, NULL::date AS dna_extraction_date_dna, NULL::integer AS dna_extraction_number,
    NULL::numeric AS rna_volume_ul, NULL::numeric AS rna_concentration_ng_ul, NULL::numeric AS rna_a260_280, NULL::numeric AS rna_a260_230, NULL::text AS rna_extraction_method, NULL::date AS rna_extraction_date_rna, NULL::integer AS rna_extraction_number,
    NULL::numeric AS sediment_volume, NULL::text AS sediment_volume_unit, NULL::numeric AS sediment_depth_m, NULL::text AS sediment_sampling_method, NULL::text AS sediment_conservation_buffer,
    NULL::numeric AS water_volume_l, NULL::text AS water_filter, NULL::numeric AS water_filter_pore_size_um, NULL::numeric AS water_depth_m, NULL::text AS water_sampling_method, NULL::text AS water_conservation_buffer,
    NULL::text AS otolith_id, NULL::text AS otolith_reader_person_id, NULL::text AS otolith_side, NULL::numeric AS otolith_age_reading_years, NULL::numeric AS otolith_confidence,
    NULL::text AS dissection_id, NULL::text AS dissection_person_id, NULL::date AS dissection_date, NULL::jsonb AS dissection_stomach_contents_jsonb, NULL::numeric AS dissection_gonad_weight_g, NULL::numeric AS dissection_liver_weight_g,
    NULL::text AS extraction_id, NULL::date AS extraction_process_date, NULL::text AS extraction_process_person_id, NULL::text AS extraction_process_kit, NULL::numeric AS extraction_process_elution_volume_ul, NULL::numeric AS extraction_process_yield_qubit_ng_ul, NULL::numeric AS extraction_process_yield_nanodrop_ng_ul, NULL::numeric AS extraction_process_a260_280, NULL::numeric AS extraction_process_a260_230, NULL::text AS extraction_result_dna_sample_id, NULL::text AS extraction_result_rna_sample_id,
    NULL::text AS extraction_blank_id,
    NULL::text AS nanodrop_id, NULL::numeric AS nanodrop_concentration, NULL::text AS nanodrop_concentration_unit, NULL::numeric AS nanodrop_a260, NULL::numeric AS nanodrop_a260_280_qc, NULL::numeric AS nanodrop_a260_230_qc, NULL::numeric AS nanodrop_total_dna_ug, NULL::date AS nanodrop_measurement_date, NULL::text AS nanodrop_a260_280_note, NULL::text AS nanodrop_a260_230_note,
    NULL::text AS qubit_id, NULL::numeric AS qubit_original_sample_conc, NULL::text AS qubit_original_sample_unit, NULL::numeric AS qubit_total_dna_ug, NULL::date AS qubit_measurement_date, NULL::text AS qubit_assay_kit, NULL::numeric AS qubit_tube_conc, NULL::text AS tube_unit_id, NULL::numeric AS sample_volume_ul, NULL::numeric AS elution_volume_ul,
    NULL::text AS tapestation_id, NULL::date AS tapestation_measurement_date, NULL::text AS tapestation_kit,
    pcr.pcr_id,
    pcr.pcr_date,
    pcr_primer.primer_id AS pcr_primer_id,
    pcr_primer.target_gene_id AS pcr_target_gene_id,
    pcr.volume_reaction_ul,
    pcr.pcr_blank_id,
    pcr.position AS pcr_position,
    NULL::text AS gel_gelelectrophoresis_id, NULL::date AS gel_run_date, NULL::integer AS gel_band_size_bp, NULL::text AS gel_gel_type, NULL::text AS gel_position, NULL::text AS gel_ladder, NULL::numeric AS gel_voltage, NULL::numeric AS gel_run_time_minutes,
    NULL::text AS qpcr_id, NULL::date AS qpcr_date, NULL::numeric AS qpcr_ct_value, NULL::text AS qpcr_inhibitor_test_result, NULL::text AS qpcr_position, NULL::text AS qpcr_primer_id_actual, NULL::text AS qpcr_pcr_blank_id, NULL::text AS qpcr_kit, NULL::numeric AS qpcr_volume_ul,
    NULL::text AS library_id, NULL::date AS library_prep_date, NULL::text AS library_name, NULL::text AS library_prep_kit, NULL::text AS library_index_sequence, NULL::integer AS library_read_length_bp,
    NULL::text AS sequencing_id, NULL::date AS sequencing_date, NULL::text AS sequencer, NULL::text AS flow_cell_id, NULL::bigint AS total_reads, NULL::text AS raw_data_path, NULL::text AS genbank_accession_number, NULL::text AS sequencing_library_prep_kit, NULL::text AS sequencing_index_sequence, NULL::integer AS sequencing_read_length_bp,
    NULL::text AS analysis_run_id, NULL::text AS pipeline_name, NULL::text AS pipeline_version, NULL::text AS bioinfo_reference_database, NULL::text AS bioinfo_database_version, NULL::numeric AS clustering_threshold, NULL::text AS final_output_path,
    NULL::text AS edna_assignment_id, NULL::text AS edna_assigned_taxon_id, NULL::text AS edna_assigned_taxon_name, NULL::integer AS edna_read_count, NULL::numeric AS edna_confidence,
    e.experiment_id AS associated_experiment_id, e.experiment_title AS associated_experiment_title, e.experiment_date AS associated_experiment_date, e.aim AS associated_experiment_aim, e.method AS associated_experiment_method, exp_person.full_name AS experiment_person_name,
    NULL::text AS sampler_full_name, NULL::text AS receiver_full_name
FROM
    "lab"."pcr" pcr
LEFT JOIN "lims"."projects" p ON pcr.project_id = p.project_id
LEFT JOIN "reference"."status" stat ON pcr.status_id = stat.status_id
LEFT JOIN "lims"."primers" pcr_primer ON pcr.primer_id = pcr_primer.primer_id
LEFT JOIN "lab"."experiments" e ON pcr.experiment_id = e.experiment_id AND pcr.experiment_date = e.experiment_date
LEFT JOIN "reference"."personal" exp_person ON e.person_id = exp_person.person_id

UNION ALL

SELECT
    gel.gelelectrophoresis_id AS sample_id,
    NULL AS external_name,
    gel.sample_id AS parent_sample_id,
    'Gel Electrophoresis Result' AS sample_origin_type,
    'GE' AS sample_type_id,
    'GE' AS sample_type_abrv,
    NULL AS status_id, -- Gel table doesn't have status_id, default to NULL
    NULL AS sample_status_notes,
    NULL::text AS sampling_id,
    gel.run_date AS sampling_date,
    NULL AS reception_date,
    gel.project_id,
    p.title AS project_title,
    NULL::integer AS customer_id,
    NULL::text AS customer_name,
    gel.storage_id,
    gel.storage_position,
    gel.notes,
    gel.attachment,
    gel.attachment_link,

    -- All other specific details are NULL
    NULL::numeric AS sampling_lon, NULL::numeric AS sampling_lat, NULL::numeric AS fishing_start_lon, NULL::numeric AS fishing_start_lat, NULL::numeric AS fishing_end_lon, NULL::numeric AS fishing_end_lat,
    NULL::text AS sampling_location, NULL::numeric AS sampling_depth_m, NULL::numeric AS temperature_atmospheric_c, NULL::text AS weather, NULL::numeric AS wind_speed, NULL::text AS wind_unit,
    NULL::numeric AS salinity, NULL::text AS salinity_unit, NULL::numeric AS oxygen, NULL::text AS oxygen_unit,
    NULL::text AS fish_species_id, NULL::text AS fish_species_en_name, NULL::numeric AS fish_total_length_mm, NULL::numeric AS fish_fork_length_mm, NULL::numeric AS fish_standard_length_mm, NULL::numeric AS fish_weight_g, NULL::text AS fish_sex, NULL::text AS fish_maturity_stage, NULL::text AS fish_stomach_contents, NULL::text AS fish_disease_info, NULL::text AS fish_tag_id,
    NULL::numeric AS tissue_weight_mg, NULL::text AS tissue_type, NULL::text AS tissue_preservation_method,
    NULL::numeric AS dna_volume_ul, NULL::numeric AS dna_concentration_ng_ul, NULL::numeric AS dna_a260_280, NULL::numeric AS dna_a260_230, NULL::text AS dna_extraction_method, NULL::date AS dna_extraction_date_dna, NULL::integer AS dna_extraction_number,
    NULL::numeric AS rna_volume_ul, NULL::numeric AS rna_concentration_ng_ul, NULL::numeric AS rna_a260_280, NULL::numeric AS rna_a260_230, NULL::text AS rna_extraction_method, NULL::date AS rna_extraction_date_rna, NULL::integer AS rna_extraction_number,
    NULL::numeric AS sediment_volume, NULL::text AS sediment_volume_unit, NULL::numeric AS sediment_depth_m, NULL::text AS sediment_sampling_method, NULL::text AS sediment_conservation_buffer,
    NULL::numeric AS water_volume_l, NULL::text AS water_filter, NULL::numeric AS water_filter_pore_size_um, NULL::numeric AS water_depth_m, NULL::text AS water_sampling_method, NULL::text AS water_conservation_buffer,
    NULL::text AS otolith_id, NULL::text AS otolith_reader_person_id, NULL::text AS otolith_side, NULL::numeric AS otolith_age_reading_years, NULL::numeric AS otolith_confidence,
    NULL::text AS dissection_id, NULL::text AS dissection_person_id, NULL::date AS dissection_date, NULL::jsonb AS dissection_stomach_contents_jsonb, NULL::numeric AS dissection_gonad_weight_g, NULL::numeric AS dissection_liver_weight_g,
    NULL::text AS extraction_id, NULL::date AS extraction_process_date, NULL::text AS extraction_process_person_id, NULL::text AS extraction_process_kit, NULL::numeric AS extraction_process_elution_volume_ul, NULL::numeric AS extraction_process_yield_qubit_ng_ul, NULL::numeric AS extraction_process_yield_nanodrop_ng_ul, NULL::numeric AS extraction_process_a260_280, NULL::numeric AS extraction_process_a260_230, NULL::text AS extraction_result_dna_sample_id, NULL::text AS extraction_result_rna_sample_id,
    NULL::text AS extraction_blank_id,
    NULL::text AS nanodrop_id, NULL::numeric AS nanodrop_concentration, NULL::text AS nanodrop_concentration_unit, NULL::numeric AS nanodrop_a260, NULL::numeric AS nanodrop_a260_280_qc, NULL::numeric AS nanodrop_a260_230_qc, NULL::numeric AS nanodrop_total_dna_ug, NULL::date AS nanodrop_measurement_date, NULL::text AS nanodrop_a260_280_note, NULL::text AS nanodrop_a260_230_note,
    NULL::text AS qubit_id, NULL::numeric AS qubit_original_sample_conc, NULL::text AS qubit_original_sample_unit, NULL::numeric AS qubit_total_dna_ug, NULL::date AS qubit_measurement_date, NULL::text AS qubit_assay_kit, NULL::numeric AS qubit_tube_conc, NULL::text AS tube_unit_id, NULL::numeric AS sample_volume_ul, NULL::numeric AS elution_volume_ul,
    NULL::text AS tapestation_id, NULL::date AS tapestation_measurement_date, NULL::text AS tapestation_kit,
    NULL::text AS pcr_id, NULL::date AS pcr_date, NULL::text AS pcr_primer_id, NULL::text AS pcr_target_gene_id, NULL::numeric AS pcr_volume_reaction_ul, NULL::text AS pcr_blank_id, NULL::text AS pcr_position,
    gel.gelelectrophoresis_id,
    gel.run_date,
    gel.band_size_bp,
    gel.gel_type,
    gel.position AS gel_position,
    gel.ladder AS gel_ladder,
    gel.voltage AS gel_voltage,
    gel.run_time_minutes AS gel_run_time_minutes,
    NULL::text AS qpcr_id, NULL::date AS qpcr_date, NULL::numeric AS qpcr_ct_value, NULL::text AS qpcr_inhibitor_test_result, NULL::text AS qpcr_position, NULL::text AS qpcr_primer_id_actual, NULL::text AS qpcr_pcr_blank_id, NULL::text AS qpcr_kit, NULL::numeric AS qpcr_volume_ul,
    NULL::text AS library_id, NULL::date AS library_prep_date, NULL::text AS library_name, NULL::text AS library_prep_kit, NULL::text AS library_index_sequence, NULL::integer AS library_read_length_bp,
    NULL::text AS sequencing_id, NULL::date AS sequencing_date, NULL::text AS sequencer, NULL::text AS flow_cell_id, NULL::bigint AS total_reads, NULL::text AS raw_data_path, NULL::text AS genbank_accession_number, NULL::text AS sequencing_library_prep_kit, NULL::text AS sequencing_index_sequence, NULL::integer AS sequencing_read_length_bp,
    NULL::text AS analysis_run_id, NULL::text AS pipeline_name, NULL::text AS pipeline_version, NULL::text AS bioinfo_reference_database, NULL::text AS bioinfo_database_version, NULL::numeric AS clustering_threshold, NULL::text AS final_output_path,
    NULL::text AS edna_assignment_id, NULL::text AS edna_assigned_taxon_id, NULL::text AS edna_assigned_taxon_name, NULL::integer AS edna_read_count, NULL::numeric AS edna_confidence,
    e.experiment_id AS associated_experiment_id, e.experiment_title AS associated_experiment_title, e.experiment_date AS associated_experiment_date, e.aim AS associated_experiment_aim, e.method AS associated_experiment_method, exp_person.full_name AS experiment_person_name,
    NULL::text AS sampler_full_name, NULL::text AS receiver_full_name
FROM
    "lab"."gelelectrophoresis" gel
LEFT JOIN "lims"."projects" p ON gel.project_id = p.project_id
LEFT JOIN "lab"."experiments" e ON gel.experiment_id = e.experiment_id AND gel.experiment_date = e.experiment_date
LEFT JOIN "reference"."personal" exp_person ON e.person_id = exp_person.person_id

UNION ALL

SELECT
    qpcr.qpcr_id AS sample_id,
    NULL AS external_name,
    qpcr.sample_id AS parent_sample_id,
    'qPCR Result' AS sample_origin_type,
    'QPCRR' AS sample_type_id,
    'QPCRR' AS sample_type_abrv,
    qpcr.status_id AS status_id,
    stat.notes AS sample_status_notes,
    NULL::text AS sampling_id,
    qpcr.qpcr_date AS sampling_date,
    NULL AS reception_date,
    qpcr.project_id,
    p.title AS project_title,
    NULL::integer AS customer_id,
    NULL::text AS customer_name,
    qpcr.storage_id,
    qpcr.storage_position,
    NULL::text AS notes,
    qpcr.attachment,
    qpcr.attachment_link,

    -- All other specific details are NULL
    NULL::numeric AS sampling_lon, NULL::numeric AS sampling_lat, NULL::numeric AS fishing_start_lon, NULL::numeric AS fishing_start_lat, NULL::numeric AS fishing_end_lon, NULL::numeric AS fishing_end_lat,
    NULL::text AS sampling_location, NULL::numeric AS sampling_depth_m, NULL::numeric AS temperature_atmospheric_c, NULL::text AS weather, NULL::numeric AS wind_speed, NULL::text AS wind_unit,
    NULL::numeric AS salinity, NULL::text AS salinity_unit, NULL::numeric AS oxygen, NULL::text AS oxygen_unit,
    NULL::text AS fish_species_id, NULL::text AS fish_species_en_name, NULL::numeric AS fish_total_length_mm, NULL::numeric AS fish_fork_length_mm, NULL::numeric AS fish_standard_length_mm, NULL::numeric AS fish_weight_g, NULL::text AS fish_sex, NULL::text AS fish_maturity_stage, NULL::text AS fish_stomach_contents, NULL::text AS fish_disease_info, NULL::text AS fish_tag_id,
    NULL::numeric AS tissue_weight_mg, NULL::text AS tissue_type, NULL::text AS tissue_preservation_method,
    NULL::numeric AS dna_volume_ul, NULL::numeric AS dna_concentration_ng_ul, NULL::numeric AS dna_a260_280, NULL::numeric AS dna_a260_230, NULL::text AS dna_extraction_method, NULL::date AS dna_extraction_date_dna, NULL::integer AS dna_extraction_number,
    NULL::numeric AS rna_volume_ul, NULL::numeric AS rna_concentration_ng_ul, NULL::numeric AS rna_a260_280, NULL::numeric AS rna_a260_230, NULL::text AS rna_extraction_method, NULL::date AS rna_extraction_date_rna, NULL::integer AS rna_extraction_number,
    NULL::numeric AS sediment_volume, NULL::text AS sediment_volume_unit, NULL::numeric AS sediment_depth_m, NULL::text AS sediment_sampling_method, NULL::text AS sediment_conservation_buffer,
    NULL::numeric AS water_volume_l, NULL::text AS water_filter, NULL::numeric AS water_filter_pore_size_um, NULL::numeric AS water_depth_m, NULL::text AS water_sampling_method, NULL::text AS water_conservation_buffer,
    NULL::text AS otolith_id, NULL::text AS otolith_reader_person_id, NULL::text AS otolith_side, NULL::numeric AS otolith_age_reading_years, NULL::numeric AS otolith_confidence,
    NULL::text AS dissection_id, NULL::text AS dissection_person_id, NULL::date AS dissection_date, NULL::jsonb AS dissection_stomach_contents_jsonb, NULL::numeric AS dissection_gonad_weight_g, NULL::numeric AS dissection_liver_weight_g,
    NULL::text AS extraction_id, NULL::date AS extraction_process_date, NULL::text AS extraction_process_person_id, NULL::text AS extraction_process_kit, NULL::numeric AS extraction_process_elution_volume_ul, NULL::numeric AS extraction_process_yield_qubit_ng_ul, NULL::numeric AS extraction_process_yield_nanodrop_ng_ul, NULL::numeric AS extraction_process_a260_280, NULL::numeric AS extraction_process_a260_230, NULL::text AS extraction_result_dna_sample_id, NULL::text AS extraction_result_rna_sample_id,
    NULL::text AS extraction_blank_id,
    NULL::text AS nanodrop_id, NULL::numeric AS nanodrop_concentration, NULL::text AS nanodrop_concentration_unit, NULL::numeric AS nanodrop_a260, NULL::numeric AS nanodrop_a260_280_qc, NULL::numeric AS nanodrop_a260_230_qc, NULL::numeric AS nanodrop_total_dna_ug, NULL::date AS nanodrop_measurement_date, NULL::text AS nanodrop_a260_280_note, NULL::text AS nanodrop_a260_230_note,
    NULL::text AS qubit_id, NULL::numeric AS qubit_original_sample_conc, NULL::text AS qubit_original_sample_unit, NULL::numeric AS qubit_total_dna_ug, NULL::date AS qubit_measurement_date, NULL::text AS qubit_assay_kit, NULL::numeric AS qubit_tube_conc, NULL::text AS tube_unit_id, NULL::numeric AS sample_volume_ul, NULL::numeric AS elution_volume_ul,
    NULL::text AS tapestation_id, NULL::date AS tapestation_measurement_date, NULL::text AS tapestation_kit,
    NULL::text AS pcr_id, NULL::date AS pcr_date, NULL::text AS pcr_primer_id, NULL::text AS pcr_target_gene_id, NULL::numeric AS pcr_volume_reaction_ul, NULL::text AS pcr_blank_id, NULL::text AS pcr_position,
    NULL::text AS gel_gelelectrophoresis_id, NULL::date AS gel_run_date, NULL::integer AS gel_band_size_bp, NULL::text AS gel_gel_type, NULL::text AS gel_position, NULL::text AS gel_ladder, NULL::numeric AS gel_voltage, NULL::numeric AS gel_run_time_minutes,
    qpcr.qpcr_id,
    qpcr.qpcr_date,
    qpcr.ct_value,
    qpcr.inhibitor_test_result,
    qpcr.position AS qpcr_position,
    qpcr.primer_id AS qpcr_primer_id_actual,
    qpcr.pcr_blank_id AS qpcr_pcr_blank_id,
    qpcr.kit AS qpcr_kit,
    qpcr.volume_ul AS qpcr_volume_ul,
    NULL::text AS library_id, NULL::date AS library_prep_date, NULL::text AS library_name, NULL::text AS library_prep_kit, NULL::text AS library_index_sequence, NULL::integer AS library_read_length_bp,
    NULL::text AS sequencing_id, NULL::date AS sequencing_date, NULL::text AS sequencer, NULL::text AS flow_cell_id, NULL::bigint AS total_reads, NULL::text AS raw_data_path, NULL::text AS genbank_accession_number, NULL::text AS sequencing_library_prep_kit, NULL::text AS sequencing_index_sequence, NULL::integer AS sequencing_read_length_bp,
    NULL::text AS analysis_run_id, NULL::text AS pipeline_name, NULL::text AS pipeline_version, NULL::text AS bioinfo_reference_database, NULL::text AS bioinfo_database_version, NULL::numeric AS clustering_threshold, NULL::text AS final_output_path,
    NULL::text AS edna_assignment_id, NULL::text AS edna_assigned_taxon_id, NULL::text AS edna_assigned_taxon_name, NULL::integer AS edna_read_count, NULL::numeric AS edna_confidence,
    e.experiment_id AS associated_experiment_id, e.experiment_title AS associated_experiment_title, e.experiment_date AS associated_experiment_date, e.aim AS associated_experiment_aim, e.method AS associated_experiment_method, exp_person.full_name AS experiment_person_name,
    NULL::text AS sampler_full_name, NULL::text AS receiver_full_name
FROM
    "lab"."qpcr" qpcr
LEFT JOIN "lims"."projects" p ON qpcr.project_id = p.project_id
LEFT JOIN "reference"."status" stat ON qpcr.status_id = stat.status_id
LEFT JOIN "lab"."experiments" e ON qpcr.experiment_id = e.experiment_id AND qpcr.experiment_date = e.experiment_date
LEFT JOIN "reference"."personal" exp_person ON e.person_id = exp_person.person_id

UNION ALL

SELECT
    lib.library_id AS sample_id,
    NULL AS external_name,
    lib.sample_id AS parent_sample_id,
    'Library Prep Product' AS sample_origin_type,
    'LIBP' AS sample_type_id,
    'LIBP' AS sample_type_abrv,
    (SELECT status_id FROM "reference"."status" WHERE notes = 'Received') AS status_id,
    (SELECT notes FROM "reference"."status" WHERE status_id = 'Received') AS sample_status_notes,
    NULL::text AS sampling_id,
    lib.prep_date AS sampling_date,
    NULL AS reception_date,
    lib.project_id,
    p.title AS project_title,
    NULL::integer AS customer_id,
    NULL::text AS customer_name,
    lib.storage_id,
    lib.storage_position,
    lib.notes,
    lib.attachment,
    lib.attachment_link,

    -- All other specific details are NULL
    NULL::numeric AS sampling_lon, NULL::numeric AS sampling_lat, NULL::numeric AS fishing_start_lon, NULL::numeric AS fishing_start_lat, NULL::numeric AS fishing_end_lon, NULL::numeric AS fishing_end_lat,
    NULL::text AS sampling_location, NULL::numeric AS sampling_depth_m, NULL::numeric AS temperature_atmospheric_c, NULL::text AS weather, NULL::numeric AS wind_speed, NULL::text AS wind_unit,
    NULL::numeric AS salinity, NULL::text AS salinity_unit, NULL::numeric AS oxygen, NULL::text AS oxygen_unit,
    NULL::text AS fish_species_id, NULL::text AS fish_species_en_name, NULL::numeric AS fish_total_length_mm, NULL::numeric AS fish_fork_length_mm, NULL::numeric AS fish_standard_length_mm, NULL::numeric AS fish_weight_g, NULL::text AS fish_sex, NULL::text AS fish_maturity_stage, NULL::text AS fish_stomach_contents, NULL::text AS fish_disease_info, NULL::text AS fish_tag_id,
    NULL::numeric AS tissue_weight_mg, NULL::text AS tissue_type, NULL::text AS tissue_preservation_method,
    NULL::numeric AS dna_volume_ul, NULL::numeric AS dna_concentration_ng_ul, NULL::numeric AS dna_a260_280, NULL::numeric AS dna_a260_230, NULL::text AS dna_extraction_method, NULL::date AS dna_extraction_date_dna, NULL::integer AS dna_extraction_number,
    NULL::numeric AS rna_volume_ul, NULL::numeric AS rna_concentration_ng_ul, NULL::numeric AS rna_a260_280, NULL::numeric AS rna_a260_230, NULL::text AS rna_extraction_method, NULL::date AS rna_extraction_date_rna, NULL::integer AS rna_extraction_number,
    NULL::numeric AS sediment_volume, NULL::text AS sediment_volume_unit, NULL::numeric AS sediment_depth_m, NULL::text AS sediment_sampling_method, NULL::text AS sediment_conservation_buffer,
    NULL::numeric AS water_volume_l, NULL::text AS water_filter, NULL::numeric AS water_filter_pore_size_um, NULL::numeric AS water_depth_m, NULL::text AS water_sampling_method, NULL::text AS water_conservation_buffer,
    NULL::text AS otolith_id, NULL::text AS otolith_reader_person_id, NULL::text AS otolith_side, NULL::numeric AS otolith_age_reading_years, NULL::numeric AS otolith_confidence,
    NULL::text AS dissection_id, NULL::text AS dissection_person_id, NULL::date AS dissection_date, NULL::jsonb AS dissection_stomach_contents_jsonb, NULL::numeric AS dissection_gonad_weight_g, NULL::numeric AS dissection_liver_weight_g,
    NULL::text AS extraction_id, NULL::date AS extraction_process_date, NULL::text AS extraction_process_person_id, NULL::text AS extraction_process_kit, NULL::numeric AS extraction_process_elution_volume_ul, NULL::numeric AS extraction_process_yield_qubit_ng_ul, NULL::numeric AS extraction_process_yield_nanodrop_ng_ul, NULL::numeric AS extraction_process_a260_280, NULL::numeric AS extraction_process_a260_230, NULL::text AS extraction_result_dna_sample_id, NULL::text AS extraction_result_rna_sample_id,
    NULL::text AS extraction_blank_id,
    NULL::text AS nanodrop_id, NULL::numeric AS nanodrop_concentration, NULL::text AS nanodrop_concentration_unit, NULL::numeric AS nanodrop_a260, NULL::numeric AS nanodrop_a260_280_qc, NULL::numeric AS nanodrop_a260_230_qc, NULL::numeric AS nanodrop_total_dna_ug, NULL::date AS nanodrop_measurement_date, NULL::text AS nanodrop_a260_280_note, NULL::text AS nanodrop_a260_230_note,
    NULL::text AS qubit_id, NULL::numeric AS qubit_original_sample_conc, NULL::text AS qubit_original_sample_unit, NULL::numeric AS qubit_total_dna_ug, NULL::date AS qubit_measurement_date, NULL::text AS qubit_assay_kit, NULL::numeric AS qubit_tube_conc, NULL::text AS tube_unit_id, NULL::numeric AS sample_volume_ul, NULL::numeric AS elution_volume_ul,
    NULL::text AS tapestation_id, NULL::date AS tapestation_measurement_date, NULL::text AS tapestation_kit,
    NULL::text AS pcr_id, NULL::date AS pcr_date, NULL::text AS pcr_primer_id, NULL::text AS pcr_target_gene_id, NULL::numeric AS pcr_volume_reaction_ul, NULL::text AS pcr_blank_id, NULL::text AS pcr_position,
    NULL::text AS gel_gelelectrophoresis_id, NULL::date AS gel_run_date, NULL::integer AS gel_band_size_bp, NULL::text AS gel_gel_type, NULL::text AS gel_position, NULL::text AS gel_ladder, NULL::numeric AS gel_voltage, NULL::numeric AS gel_run_time_minutes,
    NULL::text AS qpcr_id, NULL::date AS qpcr_date, NULL::numeric AS qpcr_ct_value, NULL::text AS qpcr_inhibitor_test_result, NULL::text AS qpcr_position, NULL::text AS qpcr_primer_id_actual, NULL::text AS qpcr_pcr_blank_id, NULL::text AS qpcr_kit, NULL::numeric AS qpcr_volume_ul,
    lib.library_id,
    lib.prep_date,
    lib.library_name,
    lib.library_prep_kit,
    lib.index_sequence,
    lib.read_length_bp,
    NULL::text AS sequencing_id, NULL::date AS sequencing_date, NULL::text AS sequencer, NULL::text AS flow_cell_id, NULL::bigint AS total_reads, NULL::text AS raw_data_path, NULL::text AS genbank_accession_number, NULL::text AS sequencing_library_prep_kit, NULL::text AS sequencing_index_sequence, NULL::integer AS sequencing_read_length_bp,
    NULL::text AS analysis_run_id, NULL::text AS pipeline_name, NULL::text AS pipeline_version, NULL::text AS bioinfo_reference_database, NULL::text AS bioinfo_database_version, NULL::numeric AS clustering_threshold, NULL::text AS final_output_path,
    NULL::text AS edna_assignment_id, NULL::text AS edna_assigned_taxon_id, NULL::text AS edna_assigned_taxon_name, NULL::integer AS edna_read_count, NULL::numeric AS edna_confidence,
    e.experiment_id AS associated_experiment_id, e.experiment_title AS associated_experiment_title, e.experiment_date AS associated_experiment_date, e.aim AS associated_experiment_aim, e.method AS associated_experiment_method, exp_person.full_name AS experiment_person_name,
    NULL::text AS sampler_full_name, NULL::text AS receiver_full_name
FROM
    "lab"."library" lib
LEFT JOIN "lims"."projects" p ON lib.project_id = p.project_id
LEFT JOIN "lab"."experiments" e ON lib.experiment_id = e.experiment_id AND lib.experiment_date = e.experiment_date
LEFT JOIN "reference"."personal" exp_person ON e.person_id = exp_person.person_id

UNION ALL

SELECT
    seq.sequencing_id AS sample_id,
    NULL AS external_name,
    seq.sample_id AS parent_sample_id,
    'Sequencing Run' AS sample_origin_type,
    'SEQR' AS sample_type_id,
    'SEQR' AS sample_type_abrv,
    seq.status_id AS status_id,
    stat.notes AS sample_status_notes,
    NULL::text AS sampling_id,
    seq.sequencing_date AS sampling_date,
    NULL AS reception_date,
    seq.project_id,
    p.title AS project_title,
    NULL::integer AS customer_id,
    NULL::text AS customer_name,
    seq.storage_id,
    seq.storage_position,
    seq.notes,
    seq.attachment,
    seq.attachment_link,

    -- All other specific details are NULL
    NULL::numeric AS sampling_lon, NULL::numeric AS sampling_lat, NULL::numeric AS fishing_start_lon, NULL::numeric AS fishing_start_lat, NULL::numeric AS fishing_end_lon, NULL::numeric AS fishing_end_lat,
    NULL::text AS sampling_location, NULL::numeric AS sampling_depth_m, NULL::numeric AS temperature_atmospheric_c, NULL::text AS weather, NULL::numeric AS wind_speed, NULL::text AS wind_unit,
    NULL::numeric AS salinity, NULL::text AS salinity_unit, NULL::numeric AS oxygen, NULL::text AS oxygen_unit,
    NULL::text AS fish_species_id, NULL::text AS fish_species_en_name, NULL::numeric AS fish_total_length_mm, NULL::numeric AS fish_fork_length_mm, NULL::numeric AS fish_standard_length_mm, NULL::numeric AS fish_weight_g, NULL::text AS fish_sex, NULL::text AS fish_maturity_stage, NULL::text AS fish_stomach_contents, NULL::text AS fish_disease_info, NULL::text AS fish_tag_id,
    NULL::numeric AS tissue_weight_mg, NULL::text AS tissue_type, NULL::text AS tissue_preservation_method,
    NULL::numeric AS dna_volume_ul, NULL::numeric AS dna_concentration_ng_ul, NULL::numeric AS dna_a260_280, NULL::numeric AS dna_a260_230, NULL::text AS dna_extraction_method, NULL::date AS dna_extraction_date_dna, NULL::integer AS dna_extraction_number,
    NULL::numeric AS rna_volume_ul, NULL::numeric AS rna_concentration_ng_ul, NULL::numeric AS rna_a260_280, NULL::numeric AS rna_a260_230, NULL::text AS rna_extraction_method, NULL::date AS rna_extraction_date_rna, NULL::integer AS rna_extraction_number,
    NULL::numeric AS sediment_volume, NULL::text AS sediment_volume_unit, NULL::numeric AS sediment_depth_m, NULL::text AS sediment_sampling_method, NULL::text AS sediment_conservation_buffer,
    NULL::numeric AS water_volume_l, NULL::text AS water_filter, NULL::numeric AS water_filter_pore_size_um, NULL::numeric AS water_depth_m, NULL::text AS water_sampling_method, NULL::text AS water_conservation_buffer,
    NULL::text AS otolith_id, NULL::text AS otolith_reader_person_id, NULL::text AS otolith_side, NULL::numeric AS otolith_age_reading_years, NULL::numeric AS otolith_confidence,
    NULL::text AS dissection_id, NULL::text AS dissection_person_id, NULL::date AS dissection_date, NULL::jsonb AS dissection_stomach_contents_jsonb, NULL::numeric AS dissection_gonad_weight_g, NULL::numeric AS dissection_liver_weight_g,
    NULL::text AS extraction_id, NULL::date AS extraction_process_date, NULL::text AS extraction_process_person_id, NULL::text AS extraction_process_kit, NULL::numeric AS extraction_process_elution_volume_ul, NULL::numeric AS extraction_process_yield_qubit_ng_ul, NULL::numeric AS extraction_process_yield_nanodrop_ng_ul, NULL::numeric AS extraction_process_a260_280, NULL::numeric AS extraction_process_a260_230, NULL::text AS extraction_result_dna_sample_id, NULL::text AS extraction_result_rna_sample_id,
    NULL::text AS extraction_blank_id,
    NULL::text AS nanodrop_id, NULL::numeric AS nanodrop_concentration, NULL::text AS nanodrop_concentration_unit, NULL::numeric AS nanodrop_a260, NULL::numeric AS nanodrop_a260_280_qc, NULL::numeric AS nanodrop_a260_230_qc, NULL::numeric AS nanodrop_total_dna_ug, NULL::date AS nanodrop_measurement_date, NULL::text AS nanodrop_a260_280_note, NULL::text AS nanodrop_a260_230_note,
    NULL::text AS qubit_id, NULL::numeric AS qubit_original_sample_conc, NULL::text AS qubit_original_sample_unit, NULL::numeric AS qubit_total_dna_ug, NULL::date AS qubit_measurement_date, NULL::text AS qubit_assay_kit, NULL::numeric AS qubit_tube_conc, NULL::text AS tube_unit_id, NULL::numeric AS sample_volume_ul, NULL::numeric AS elution_volume_ul,
    NULL::text AS tapestation_id, NULL::date AS tapestation_measurement_date, NULL::text AS tapestation_kit,
    NULL::text AS pcr_id, NULL::date AS pcr_date, NULL::text AS pcr_primer_id, NULL::text AS pcr_target_gene_id, NULL::numeric AS pcr_volume_reaction_ul, NULL::text AS pcr_blank_id, NULL::text AS pcr_position,
    NULL::text AS gel_gelelectrophoresis_id, NULL::date AS gel_run_date, NULL::integer AS gel_band_size_bp, NULL::text AS gel_gel_type, NULL::text AS gel_position, NULL::text AS gel_ladder, NULL::numeric AS gel_voltage, NULL::numeric AS gel_run_time_minutes,
    NULL::text AS qpcr_id, NULL::date AS qpcr_date, NULL::numeric AS qpcr_ct_value, NULL::text AS qpcr_inhibitor_test_result, NULL::text AS qpcr_position, NULL::text AS qpcr_primer_id_actual, NULL::text AS qpcr_pcr_blank_id, NULL::text AS qpcr_kit, NULL::numeric AS qpcr_volume_ul,
    NULL::text AS library_id, NULL::date AS library_prep_date, NULL::text AS library_name, NULL::text AS library_prep_kit, NULL::text AS library_index_sequence, NULL::integer AS library_read_length_bp,
    seq.sequencing_id,
    seq.sequencing_date,
    seq.sequencer,
    seq.flow_cell_id,
    seq.total_reads,
    seq.raw_data_path,
    seq.genbank_accession_number,
    seq.library_prep_kit AS sequencing_library_prep_kit,
    seq.index_sequence AS sequencing_index_sequence,
    seq.read_length_bp AS sequencing_read_length_bp,
    ar.run_id AS analysis_run_id,
    ap.pipeline_name,
    ap.version AS pipeline_version,
    rdb.db_name AS bioinfo_reference_database,
    rdb.db_version AS bioinfo_database_version,
    ar.clustering_threshold,
    ar.final_output_path,
    ea.assignment_id AS edna_assignment_id,
    ea.taxon_id AS edna_assigned_taxon_id,
    ea_taxon.en_name AS edna_assigned_taxon_name,
    ea.read_count AS edna_read_count,
    ea.confidence AS edna_confidence,
    e.experiment_id AS associated_experiment_id, e.experiment_title AS associated_experiment_title, e.experiment_date AS associated_experiment_date, e.aim AS associated_experiment_aim, e.method AS associated_experiment_method, exp_person.full_name AS experiment_person_name,
    NULL::text AS sampler_full_name, NULL::text AS receiver_full_name

FROM
    "lab"."sequencing" seq
LEFT JOIN "lims"."projects" p ON seq.project_id = p.project_id
LEFT JOIN "reference"."status" stat ON seq.status_id = stat.status_id
LEFT JOIN "lab"."experiments" e ON seq.experiment_id = e.experiment_id AND seq.sequencing_date = e.experiment_date -- Corrected join date
LEFT JOIN "reference"."personal" exp_person ON e.person_id = exp_person.person_id
LEFT JOIN "bioinformatics"."analysis_runs" ar ON seq.sequencing_id = ar.sequencing_id AND seq.sequencing_date = ar.sequencing_date
LEFT JOIN "bioinformatics"."analysis_pipelines" ap ON ar.pipeline_id = ap.pipeline_id
LEFT JOIN "bioinformatics"."reference_databases" rdb ON ar.reference_db_id = rdb.db_id
LEFT JOIN "bioinformatics"."edna_assignments" ea ON ar.run_id = ea.run_id AND ar.run_date = ea.run_date AND seq.sample_id = ea.sample_id
LEFT JOIN "reference"."taxon" ea_taxon ON ea.taxon_id = ea_taxon.taxon_id;



-- ==============================================================================
-- MYVIEW

CREATE OR REPLACE VIEW "lab"."myview" AS
-- 1. Parental Samples (Master Samples) - (Total columns: ~80)
SELECT
    s.sample_id,
    s.external_name,
    s.parent_sample_id,
    'Primary Sample' AS sample_origin_type,
    s.sample_type_id,
    stype.sample_type_abrv,
    s.status_id,
    stat.notes AS sample_status_notes,
    s.workflow_id,
    s.step_id, -- Current step ID of the sample
    s.sampling_id,
    s.sampling_date,
    s.reception_date,
    s.project_id,
    p.title AS project_title,
    s.customer_id,
    c.customer_name,
    s.storage_id,
    s.storage_position,
    s.notes,
    s.attachment,
    s.attachment_link,

    -- Associated Experiment (if linked via experiments_samples)
    exp.experiment_id AS associated_experiment_id,
    exp.experiment_title AS associated_experiment_title,
    exp.experiment_date AS associated_experiment_date,
    exp_person.full_name AS experiment_person_name,

    -- Sampling Event Details (from lab.sampling)
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
    ST_X(samp.geom) AS sampling_lon,
    ST_Y(samp.geom) AS sampling_lat,
    ST_X(samp.fishing_start_geom) AS fishing_start_lon,
    ST_Y(samp.fishing_start_geom) AS fishing_start_lat,
    ST_X(samp.fishing_end_geom) AS fishing_end_lon,
    ST_Y(samp.fishing_end_geom) AS fishing_end_lat,

    -- Specific process/derived sample IDs and their relevant dates/values (28 columns from here)
    NULL::text AS fish_species_id, NULL::text AS fish_species_en_name, NULL::numeric AS fish_total_length_mm, -- Fish (3)
    NULL::numeric AS tissue_weight_mg, NULL::text AS tissue_type, -- Tissue (2)
    NULL::numeric AS dna_volume_ul, NULL::numeric AS dna_concentration_ng_ul, NULL::date AS dna_extraction_date_dna, -- DNA (3)
    NULL::numeric AS rna_volume_ul, NULL::numeric AS rna_concentration_ng_ul, NULL::date AS rna_extraction_date_rna, -- RNA (3)
    NULL::text AS otolith_id, NULL::numeric AS otolith_age_reading_years, -- Otoliths (2)
    NULL::text AS extraction_id, NULL::date AS extraction_process_date, NULL::numeric AS extraction_process_yield_qubit_ng_ul, -- Extraction (3)
    NULL::text AS nanodrop_id, NULL::date AS nanodrop_measurement_date, NULL::numeric AS nanodrop_concentration, -- Nanodrop (3)
    NULL::text AS qubit_id, NULL::date AS qubit_measurement_date, NULL::numeric AS qubit_original_sample_conc, -- Qubit (3)
    NULL::text AS tapestation_id, NULL::date AS tapestation_measurement_date, -- Tapestation (2)
    NULL::text AS pcr_id, NULL::date AS pcr_date, NULL::text AS pcr_primer_id, -- PCR (3)
    NULL::text AS gelelectrophoresis_id, NULL::date AS gel_run_date, NULL::integer AS gel_band_size_bp, -- Gel Electrophoresis (3)
    NULL::text AS qpcr_id, NULL::date AS qpcr_date, NULL::numeric AS qpcr_ct_value, -- qPCR (3)
    NULL::text AS library_id, NULL::date AS library_prep_date, NULL::text AS library_name, -- Library (3)
    NULL::text AS sequencing_id, NULL::date AS sequencing_date, NULL::bigint AS total_reads, -- Sequencing (3)
    NULL::text AS analysis_run_id, NULL::date AS analysis_run_date, NULL::text AS pipeline_name, -- Analysis Runs (3)
    NULL::text AS edna_assignment_id, NULL::text AS edna_assigned_taxon_name, NULL::integer AS edna_read_count, -- eDNA Assignments (3)

    sampler_p.full_name AS sampler_full_name,
    receiver_p.full_name AS receiver_full_name

FROM
    "lab"."root_samples" s
LEFT JOIN "reference"."status" stat ON s.status_id = stat.status_id
LEFT JOIN "reference"."samples_type" stype ON s.sample_type_id = stype.sample_type_id
LEFT JOIN "lims"."projects" p ON s.project_id = p.project_id
LEFT JOIN "lims"."customers" c ON s.customer_id = c.customer_id
LEFT JOIN "lab"."sampling" samp ON s.sampling_id = samp.sampling_id AND s.sampling_date = samp.sampling_date
LEFT JOIN "reference"."units" wu ON samp.wind_unit_id = wu.unit_id
LEFT JOIN "reference"."units" su ON samp.salinity_unit_id = su.unit_id
LEFT JOIN "reference"."units" ou ON samp.oxygen_unit_id = ou.unit_id
LEFT JOIN "reference"."personal" sampler_p ON s.sampler_person_id = sampler_p.person_id
LEFT JOIN "reference"."personal" receiver_p ON s.receiver_person_id = receiver_p.person_id
LEFT JOIN "lab"."experiments_samples" es ON s.sample_id = es.sample_id
LEFT JOIN "lab"."experiments" exp ON es.experiment_id = exp.experiment_id AND es.experiment_date = exp.experiment_date
LEFT JOIN "reference"."personal" exp_person ON exp.person_id = exp_person.person_id

UNION ALL

-- 2. Derived Fish Samples
SELECT
    f.sample_id,
    NULL::text AS external_name, -- Added NULL for missing external_name
    f.parent_sample_id,
    'Derived Fish Sample' AS sample_origin_type,
    'Fish' AS sample_type_id,
    'F' AS sample_type_abrv,
    COALESCE(f.status_id, (SELECT status_id FROM "reference"."status" WHERE notes = 'Received')) AS status_id,
    COALESCE(stat.notes, 'Received') AS sample_status_notes,
    f.workflow_id,
    f.step_id,
    f.sampling_id,
    f.sampling_date,
    NULL::date AS reception_date,
    f.project_id,
    p.title AS project_title,
    f.customer_id,
    c.customer_name,
    f.storage_id,
    f.storage_position,
    f.notes,
    f.attachment,
    f.attachment_link,

    f.experiment_id AS associated_experiment_id,
    exp.experiment_title AS associated_experiment_title,
    f.experiment_date AS associated_experiment_date,
    exp_person.full_name AS experiment_person_name,

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
    ST_X(samp.geom) AS sampling_lon,
    ST_Y(samp.geom) AS sampling_lat,
    ST_X(samp.fishing_start_geom) AS fishing_start_lon,
    ST_Y(samp.fishing_start_geom) AS fishing_start_lat,
    ST_X(samp.fishing_end_geom) AS fishing_end_lon,
    ST_Y(samp.fishing_end_geom) AS fishing_end_lat,

    f.species_id, taxon_sp.en_name AS fish_species_en_name, f.total_length_mm, -- Fish (3)
    NULL::numeric AS tissue_weight_mg, NULL::text AS tissue_type, -- Tissue (2)
    NULL::numeric AS dna_volume_ul, NULL::numeric AS dna_concentration_ng_ul, NULL::date AS dna_extraction_date_dna, -- DNA (3)
    NULL::numeric AS rna_volume_ul, NULL::numeric AS rna_concentration_ng_ul, NULL::date AS rna_extraction_date_rna, -- RNA (3)
    NULL::text AS otolith_id, NULL::numeric AS otolith_age_reading_years, -- Otoliths (2)
    NULL::text AS extraction_id, NULL::date AS extraction_process_date, NULL::numeric AS extraction_process_yield_qubit_ng_ul, -- Extraction (3)
    NULL::text AS nanodrop_id, NULL::date AS nanodrop_measurement_date, NULL::numeric AS nanodrop_concentration, -- Nanodrop (3)
    NULL::text AS qubit_id, NULL::date AS qubit_measurement_date, NULL::numeric AS qubit_original_sample_conc, -- Qubit (3)
    NULL::text AS tapestation_id, NULL::date AS tapestation_measurement_date, -- Tapestation (2)
    NULL::text AS pcr_id, NULL::date AS pcr_date, NULL::text AS pcr_primer_id, -- PCR (3)
    NULL::text AS gelelectrophoresis_id, NULL::date AS gel_run_date, NULL::integer AS gel_band_size_bp, -- Gel Electrophoresis (3)
    NULL::text AS qpcr_id, NULL::date AS qpcr_date, NULL::numeric AS qpcr_ct_value, -- qPCR (3)
    NULL::text AS library_id, NULL::date AS library_prep_date, NULL::text AS library_name, -- Library (3)
    NULL::text AS sequencing_id, NULL::date AS sequencing_date, NULL::bigint AS total_reads, -- Sequencing (3)
    NULL::text AS analysis_run_id, NULL::date AS analysis_run_date, NULL::text AS pipeline_name, -- Analysis Runs (3)
    NULL::text AS edna_assignment_id, NULL::text AS edna_assigned_taxon_name, NULL::integer AS edna_read_count, -- eDNA Assignments (3)

    NULL::text AS sampler_full_name, NULL::text AS receiver_full_name -- Not directly on fish table

FROM
    "lab"."fish" f
LEFT JOIN "reference"."status" stat ON f.status_id = stat.status_id
LEFT JOIN "lims"."projects" p ON f.project_id = p.project_id
LEFT JOIN "lims"."customers" c ON f.customer_id = c.customer_id
LEFT JOIN "lab"."sampling" samp ON f.sampling_id = samp.sampling_id AND f.sampling_date = samp.sampling_date
LEFT JOIN "reference"."units" wu ON samp.wind_unit_id = wu.unit_id
LEFT JOIN "reference"."units" su ON samp.salinity_unit_id = su.unit_id
LEFT JOIN "reference"."units" ou ON samp.oxygen_unit_id = ou.unit_id
LEFT JOIN "reference"."taxon" taxon_sp ON f.species_id = taxon_sp.taxon_id
LEFT JOIN "lab"."experiments" exp ON f.experiment_id = exp.experiment_id AND f.experiment_date = exp.experiment_date
LEFT JOIN "reference"."personal" exp_person ON exp.person_id = exp_person.person_id

UNION ALL

-- 3. Derived Tissue Samples
SELECT
    t.sample_id,
    NULL::text AS external_name,
    t.parent_sample_id,
    'Derived Tissue Sample' AS sample_origin_type,
    'Tissue' AS sample_type_id,
    'T' AS sample_type_abrv,
    COALESCE(t.status_id, (SELECT status_id FROM "reference"."status" WHERE notes = 'Received')) AS status_id,
    COALESCE(stat.notes, 'Received') AS sample_status_notes,
    t.workflow_id,
    t.step_id,
    NULL::text AS sampling_id,
    t.experiment_date AS sampling_date,
    NULL::date AS reception_date,
    t.project_id,
    p.title AS project_title,
    NULL::integer AS customer_id,
    NULL::text AS customer_name,
    t.storage_id,
    t.storage_position,
    t.notes,
    t.attachment,
    t.attachment_link,

    t.experiment_id AS associated_experiment_id,
    exp.experiment_title AS associated_experiment_title,
    t.experiment_date AS associated_experiment_date,
    exp_person.full_name AS experiment_person_name,

    NULL::text AS sampling_location, NULL::numeric AS sampling_depth_m, NULL::numeric AS temperature_atmospheric_c, NULL::text AS weather, NULL::numeric AS wind_speed, NULL::text AS wind_unit,
    NULL::numeric AS salinity, NULL::text AS salinity_unit, NULL::numeric AS oxygen, NULL::text AS oxygen_unit,
    NULL::numeric AS sampling_lon, NULL::numeric AS sampling_lat, NULL::numeric AS fishing_start_lon, NULL::numeric AS fishing_start_lat, NULL::numeric AS fishing_end_lon, NULL::numeric AS fishing_end_lat,

    NULL::text AS fish_species_id, NULL::text AS fish_species_en_name, NULL::numeric AS fish_total_length_mm, -- Fish (3)
    t.weight_mg AS tissue_weight_mg, t.tissue_type, -- Tissue (2)
    NULL::numeric AS dna_volume_ul, NULL::numeric AS dna_concentration_ng_ul, NULL::date AS dna_extraction_date_dna, -- DNA (3)
    NULL::numeric AS rna_volume_ul, NULL::numeric AS rna_concentration_ng_ul, NULL::date AS rna_extraction_date_rna, -- RNA (3)
    NULL::text AS otolith_id, NULL::numeric AS otolith_age_reading_years, -- Otoliths (2)
    NULL::text AS extraction_id, NULL::date AS extraction_process_date, NULL::numeric AS extraction_process_yield_qubit_ng_ul, -- Extraction (3)
    NULL::text AS nanodrop_id, NULL::date AS nanodrop_measurement_date, NULL::numeric AS nanodrop_concentration, -- Nanodrop (3)
    NULL::text AS qubit_id, NULL::date AS qubit_measurement_date, NULL::numeric AS qubit_original_sample_conc, -- Qubit (3)
    NULL::text AS tapestation_id, NULL::date AS tapestation_measurement_date, -- Tapestation (2)
    NULL::text AS pcr_id, NULL::date AS pcr_date, NULL::text AS pcr_primer_id, -- PCR (3)
    NULL::text AS gelelectrophoresis_id, NULL::date AS gel_run_date, NULL::integer AS gel_band_size_bp, -- Gel Electrophoresis (3)
    NULL::text AS qpcr_id, NULL::date AS qpcr_date, NULL::numeric AS qpcr_ct_value, -- qPCR (3)
    NULL::text AS library_id, NULL::date AS library_prep_date, NULL::text AS library_name, -- Library (3)
    NULL::text AS sequencing_id, NULL::date AS sequencing_date, NULL::bigint AS total_reads, -- Sequencing (3)
    NULL::text AS analysis_run_id, NULL::date AS analysis_run_date, NULL::text AS pipeline_name, -- Analysis Runs (3)
    NULL::text AS edna_assignment_id, NULL::text AS edna_assigned_taxon_name, NULL::integer AS edna_read_count, -- eDNA Assignments (3)

    NULL::text AS sampler_full_name, NULL::text AS receiver_full_name
FROM
    "lab"."tissue" t
LEFT JOIN "reference"."status" stat ON t.status_id = stat.status_id
LEFT JOIN "lims"."projects" p ON t.project_id = p.project_id
LEFT JOIN "lab"."experiments" exp ON t.experiment_id = exp.experiment_id AND t.experiment_date = exp.experiment_date
LEFT JOIN "reference"."personal" exp_person ON exp.person_id = exp_person.person_id

UNION ALL

-- 4. Derived DNA Samples
SELECT
    d.sample_id,
    NULL::text AS external_name,
    d.parent_sample_id,
    'Derived DNA Sample' AS sample_origin_type,
    'DNA' AS sample_type_id,
    'D' AS sample_type_abrv,
    COALESCE(d.status_id, (SELECT status_id FROM "reference"."status" WHERE notes = 'Received')) AS status_id,
    COALESCE(stat.notes, 'Received') AS sample_status_notes,
    d.workflow_id,
    d.step_id,
    NULL::text AS sampling_id,
    d.experiment_date AS sampling_date,
    d.extraction_date AS reception_date,
    d.project_id,
    p.title AS project_title,
    NULL::integer AS customer_id,
    NULL::text AS customer_name,
    d.storage_id,
    d.storage_position,
    d.notes,
    d.attachment,
    d.attachment_link,

    d.experiment_id AS associated_experiment_id,
    exp.experiment_title AS associated_experiment_title,
    d.experiment_date AS associated_experiment_date,
    exp_person.full_name AS experiment_person_name,

    NULL::text AS sampling_location, NULL::numeric AS sampling_depth_m, NULL::numeric AS temperature_atmospheric_c, NULL::text AS weather, NULL::numeric AS wind_speed, NULL::text AS wind_unit,
    NULL::numeric AS salinity, NULL::text AS salinity_unit, NULL::numeric AS oxygen, NULL::text AS oxygen_unit,
    NULL::numeric AS sampling_lon, NULL::numeric AS sampling_lat, NULL::numeric AS fishing_start_lon, NULL::numeric AS fishing_start_lat, NULL::numeric AS fishing_end_lon, NULL::numeric AS fishing_end_lat,

    NULL::text AS fish_species_id, NULL::text AS fish_species_en_name, NULL::numeric AS fish_total_length_mm, -- Fish (3)
    NULL::numeric AS tissue_weight_mg, NULL::text AS tissue_type, -- Tissue (2)
    d.volume_ul AS dna_volume_ul, d.concentration_ng_ul AS dna_concentration_ng_ul, d.extraction_date AS dna_extraction_date_dna, -- DNA (3)
    NULL::numeric AS rna_volume_ul, NULL::numeric AS rna_concentration_ng_ul, NULL::date AS rna_extraction_date_rna, -- RNA (3)
    NULL::text AS otolith_id, NULL::numeric AS otolith_age_reading_years, -- Otoliths (2)
    NULL::text AS extraction_id, NULL::date AS extraction_process_date, NULL::numeric AS extraction_process_yield_qubit_ng_ul, -- Extraction (3)
    NULL::text AS nanodrop_id, NULL::date AS nanodrop_measurement_date, NULL::numeric AS nanodrop_concentration, -- Nanodrop (3)
    NULL::text AS qubit_id, NULL::date AS qubit_measurement_date, NULL::numeric AS qubit_original_sample_conc, -- Qubit (3)
    NULL::text AS tapestation_id, NULL::date AS tapestation_measurement_date, -- Tapestation (2)
    NULL::text AS pcr_id, NULL::date AS pcr_date, NULL::text AS pcr_primer_id, -- PCR (3)
    NULL::text AS gelelectrophoresis_id, NULL::date AS gel_run_date, NULL::integer AS gel_band_size_bp, -- Gel Electrophoresis (3)
    NULL::text AS qpcr_id, NULL::date AS qpcr_date, NULL::numeric AS qpcr_ct_value, -- qPCR (3)
    NULL::text AS library_id, NULL::date AS library_prep_date, NULL::text AS library_name, -- Library (3)
    NULL::text AS sequencing_id, NULL::date AS sequencing_date, NULL::bigint AS total_reads, -- Sequencing (3)
    NULL::text AS analysis_run_id, NULL::date AS analysis_run_date, NULL::text AS pipeline_name, -- Analysis Runs (3)
    NULL::text AS edna_assignment_id, NULL::text AS edna_assigned_taxon_name, NULL::integer AS edna_read_count, -- eDNA Assignments (3)

    NULL::text AS sampler_full_name, NULL::text AS receiver_full_name
FROM
    "lab"."dna" d
LEFT JOIN "reference"."status" stat ON d.status_id = stat.status_id
LEFT JOIN "lims"."projects" p ON d.project_id = p.project_id
LEFT JOIN "lab"."experiments" exp ON d.experiment_id = exp.experiment_id AND d.experiment_date = exp.experiment_date
LEFT JOIN "reference"."personal" exp_person ON exp.person_id = exp_person.person_id

UNION ALL

-- 5. Derived RNA Samples
SELECT
    r.sample_id,
    NULL::text AS external_name,
    r.parent_sample_id,
    'Derived RNA Sample' AS sample_origin_type,
    'RNA' AS sample_type_id,
    'R' AS sample_type_abrv,
    COALESCE(r.status_id, (SELECT status_id FROM "reference"."status" WHERE notes = 'Received')) AS status_id,
    COALESCE(stat.notes, 'Received') AS sample_status_notes,
    r.workflow_id,
    r.step_id,
    NULL::text AS sampling_id,
    r.experiment_date AS sampling_date,
    r.extraction_date AS reception_date,
    r.project_id,
    p.title AS project_title,
    NULL::integer AS customer_id,
    NULL::text AS customer_name,
    r.storage_id,
    r.storage_position,
    r.notes,
    r.attachment,
    r.attachment_link,

    r.experiment_id AS associated_experiment_id,
    exp.experiment_title AS associated_experiment_title,
    r.experiment_date AS associated_experiment_date,
    exp_person.full_name AS experiment_person_name,

    NULL::text AS sampling_location, NULL::numeric AS sampling_depth_m, NULL::numeric AS temperature_atmospheric_c, NULL::text AS weather, NULL::numeric AS wind_speed, NULL::text AS wind_unit,
    NULL::numeric AS salinity, NULL::text AS salinity_unit, NULL::numeric AS oxygen, NULL::text AS oxygen_unit,
    NULL::numeric AS sampling_lon, NULL::numeric AS sampling_lat, NULL::numeric AS fishing_start_lon, NULL::numeric AS fishing_start_lat, NULL::numeric AS fishing_end_lon, NULL::numeric AS fishing_end_lat,

    NULL::text AS fish_species_id, NULL::text AS fish_species_en_name, NULL::numeric AS fish_total_length_mm, -- Fish (3)
    NULL::numeric AS tissue_weight_mg, NULL::text AS tissue_type, -- Tissue (2)
    NULL::numeric AS dna_volume_ul, NULL::numeric AS dna_concentration_ng_ul, NULL::date AS dna_extraction_date_dna, -- DNA (3)
    r.volume_ul AS rna_volume_ul, r.concentration_ng_ul AS rna_concentration_ng_ul, r.extraction_date AS rna_extraction_date_rna, -- RNA (3)
    NULL::text AS otolith_id, NULL::numeric AS otolith_age_reading_years, -- Otoliths (2)
    NULL::text AS extraction_id, NULL::date AS extraction_process_date, NULL::numeric AS extraction_process_yield_qubit_ng_ul, -- Extraction (3)
    NULL::text AS nanodrop_id, NULL::date AS nanodrop_measurement_date, NULL::numeric AS nanodrop_concentration, -- Nanodrop (3)
    NULL::text AS qubit_id, NULL::date AS qubit_measurement_date, NULL::numeric AS qubit_original_sample_conc, -- Qubit (3)
    NULL::text AS tapestation_id, NULL::date AS tapestation_measurement_date, -- Tapestation (2)
    NULL::text AS pcr_id, NULL::date AS pcr_date, NULL::text AS pcr_primer_id, -- PCR (3)
    NULL::text AS gelelectrophoresis_id, NULL::date AS gel_run_date, NULL::integer AS gel_band_size_bp, -- Gel Electrophoresis (3)
    NULL::text AS qpcr_id, NULL::date AS qpcr_date, NULL::numeric AS qpcr_ct_value, -- qPCR (3)
    NULL::text AS library_id, NULL::date AS library_prep_date, NULL::text AS library_name, -- Library (3)
    NULL::text AS sequencing_id, NULL::date AS sequencing_date, NULL::bigint AS total_reads, -- Sequencing (3)
    NULL::text AS analysis_run_id, NULL::date AS analysis_run_date, NULL::text AS pipeline_name, -- Analysis Runs (3)
    NULL::text AS edna_assignment_id, NULL::text AS edna_assigned_taxon_name, NULL::integer AS edna_read_count, -- eDNA Assignments (3)

    NULL::text AS sampler_full_name, NULL::text AS receiver_full_name
FROM
    "lab"."rna" r
LEFT JOIN "reference"."status" stat ON r.status_id = stat.status_id
LEFT JOIN "lims"."projects" p ON r.project_id = p.project_id
LEFT JOIN "lab"."experiments" exp ON r.experiment_id = exp.experiment_id AND r.experiment_date = exp.experiment_date
LEFT JOIN "reference"."personal" exp_person ON exp.person_id = exp_person.person_id

UNION ALL

-- 6. Derived Sediments Samples
SELECT
    sed.sample_id,
    sed.external_name,
    sed.parent_sample_id,
    'Derived Sediment Sample' AS sample_origin_type,
    'Sediments' AS sample_type_id,
    'S' AS sample_type_abrv,
    COALESCE(sed.status_id, (SELECT status_id FROM "reference"."status" WHERE notes = 'Received')) AS status_id,
    COALESCE(stat.notes, 'Received') AS sample_status_notes,
    sed.workflow_id,
    sed.step_id,
    NULL::text AS sampling_id,
    sed.experiment_date AS sampling_date,
    NULL::date AS reception_date,
    sed.project_id,
    p.title AS project_title,
    NULL::integer AS customer_id,
    NULL::text AS customer_name,
    sed.storage_id,
    sed.storage_position,
    sed.notes,
    sed.attachment,
    sed.attachment_link,

    sed.experiment_id AS associated_experiment_id,
    exp.experiment_title AS associated_experiment_title,
    sed.experiment_date AS associated_experiment_date,
    exp_person.full_name AS experiment_person_name,

    NULL::text AS sampling_location, NULL::numeric AS sampling_depth_m, NULL::numeric AS temperature_atmospheric_c, NULL::text AS weather, NULL::numeric AS wind_speed, NULL::text AS wind_unit,
    NULL::numeric AS salinity, NULL::text AS salinity_unit, NULL::numeric AS oxygen, NULL::text AS oxygen_unit,
    NULL::numeric AS sampling_lon, NULL::numeric AS sampling_lat, NULL::numeric AS fishing_start_lon, NULL::numeric AS fishing_start_lat, NULL::numeric AS fishing_end_lon, NULL::numeric AS fishing_end_lat,

    NULL::text AS fish_species_id, NULL::text AS fish_species_en_name, NULL::numeric AS fish_total_length_mm, -- Fish (3)
    NULL::numeric AS tissue_weight_mg, NULL::text AS tissue_type, -- Tissue (2)
    NULL::numeric AS dna_volume_ul, NULL::numeric AS dna_concentration_ng_ul, NULL::date AS dna_extraction_date_dna, -- DNA (3)
    NULL::numeric AS rna_volume_ul, NULL::numeric AS rna_concentration_ng_ul, NULL::date AS rna_extraction_date_rna, -- RNA (3)
    NULL::text AS otolith_id, NULL::numeric AS otolith_age_reading_years, -- Otoliths (2)
    NULL::text AS extraction_id, NULL::date AS extraction_process_date, NULL::numeric AS extraction_process_yield_qubit_ng_ul, -- Extraction (3)
    NULL::text AS nanodrop_id, NULL::date AS nanodrop_measurement_date, NULL::numeric AS nanodrop_concentration, -- Nanodrop (3)
    NULL::text AS qubit_id, NULL::date AS qubit_measurement_date, NULL::numeric AS qubit_original_sample_conc, -- Qubit (3)
    NULL::text AS tapestation_id, NULL::date AS tapestation_measurement_date, -- Tapestation (2)
    NULL::text AS pcr_id, NULL::date AS pcr_date, NULL::text AS pcr_primer_id, -- PCR (3)
    NULL::text AS gelelectrophoresis_id, NULL::date AS gel_run_date, NULL::integer AS gel_band_size_bp, -- Gel Electrophoresis (3)
    NULL::text AS qpcr_id, NULL::date AS qpcr_date, NULL::numeric AS qpcr_ct_value, -- qPCR (3)
    NULL::text AS library_id, NULL::date AS library_prep_date, NULL::text AS library_name, -- Library (3)
    NULL::text AS sequencing_id, NULL::date AS sequencing_date, NULL::bigint AS total_reads, -- Sequencing (3)
    NULL::text AS analysis_run_id, NULL::date AS analysis_run_date, NULL::text AS pipeline_name, -- Analysis Runs (3)
    NULL::text AS edna_assignment_id, NULL::text AS edna_assigned_taxon_name, NULL::integer AS edna_read_count, -- eDNA Assignments (3)

    NULL::text AS sampler_full_name, NULL::text AS receiver_full_name
FROM
    "lab"."sediments" sed
LEFT JOIN "reference"."status" stat ON sed.status_id = stat.status_id
LEFT JOIN "lims"."projects" p ON sed.project_id = p.project_id
LEFT JOIN "lab"."experiments" exp ON sed.experiment_id = exp.experiment_id AND sed.experiment_date = exp.experiment_date
LEFT JOIN "reference"."personal" exp_person ON exp.person_id = exp_person.person_id

UNION ALL

-- 7. Derived Water Samples
SELECT
    w.sample_id,
    NULL AS external_name,
    w.parent_sample_id,
    'Derived Water Sample' AS sample_origin_type,
    'Water' AS sample_type_id,
    'W' AS sample_type_abrv,
    COALESCE(w.status_id, (SELECT status_id FROM "reference"."status" WHERE notes = 'Received')) AS status_id,
    COALESCE(stat.notes, 'Received') AS sample_status_notes,
    w.workflow_id,
    w.step_id,
    NULL::text AS sampling_id,
    w.experiment_date AS sampling_date,
    NULL::date AS reception_date,
    w.project_id,
    p.title AS project_title,
    NULL::integer AS customer_id,
    NULL::text AS customer_name,
    w.storage_id,
    w.storage_position,
    w.notes,
    w.attachment,
    w.attachment_link,

    w.experiment_id AS associated_experiment_id,
    exp.experiment_title AS associated_experiment_title,
    w.experiment_date AS associated_experiment_date,
    exp_person.full_name AS experiment_person_name,

    NULL::text AS sampling_location, NULL::numeric AS sampling_depth_m, NULL::numeric AS temperature_atmospheric_c, NULL::text AS weather, NULL::numeric AS wind_speed, NULL::text AS wind_unit,
    NULL::numeric AS salinity, NULL::text AS salinity_unit, NULL::numeric AS oxygen, NULL::text AS oxygen_unit,
    NULL::numeric AS sampling_lon, NULL::numeric AS sampling_lat, NULL::numeric AS fishing_start_lon, NULL::numeric AS fishing_start_lat, NULL::numeric AS fishing_end_lon, NULL::numeric AS fishing_end_lat,

    NULL::text AS fish_species_id, NULL::text AS fish_species_en_name, NULL::numeric AS fish_total_length_mm, -- Fish (3)
    NULL::numeric AS tissue_weight_mg, NULL::text AS tissue_type, -- Tissue (2)
    NULL::numeric AS dna_volume_ul, NULL::numeric AS dna_concentration_ng_ul, NULL::date AS dna_extraction_date_dna, -- DNA (3)
    NULL::numeric AS rna_volume_ul, NULL::numeric AS rna_concentration_ng_ul, NULL::date AS rna_extraction_date_rna, -- RNA (3)
    NULL::text AS otolith_id, NULL::numeric AS otolith_age_reading_years, -- Otoliths (2)
    NULL::text AS extraction_id, NULL::date AS extraction_process_date, NULL::numeric AS extraction_process_yield_qubit_ng_ul, -- Extraction (3)
    NULL::text AS nanodrop_id, NULL::date AS nanodrop_measurement_date, NULL::numeric AS nanodrop_concentration, -- Nanodrop (3)
    NULL::text AS qubit_id, NULL::date AS qubit_measurement_date, NULL::numeric AS qubit_original_sample_conc, -- Qubit (3)
    NULL::text AS tapestation_id, NULL::date AS tapestation_measurement_date, -- Tapestation (2)
    NULL::text AS pcr_id, NULL::date AS pcr_date, NULL::text AS pcr_primer_id, -- PCR (3)
    NULL::text AS gelelectrophoresis_id, NULL::date AS gel_run_date, NULL::integer AS gel_band_size_bp, -- Gel Electrophoresis (3)
    NULL::text AS qpcr_id, NULL::date AS qpcr_date, NULL::numeric AS qpcr_ct_value, -- qPCR (3)
    NULL::text AS library_id, NULL::date AS library_prep_date, NULL::text AS library_name, -- Library (3)
    NULL::text AS sequencing_id, NULL::date AS sequencing_date, NULL::bigint AS total_reads, -- Sequencing (3)
    NULL::text AS analysis_run_id, NULL::date AS analysis_run_date, NULL::text AS pipeline_name, -- Analysis Runs (3)
    NULL::text AS edna_assignment_id, NULL::text AS edna_assigned_taxon_name, NULL::integer AS edna_read_count, -- eDNA Assignments (3)

    NULL::text AS sampler_full_name, NULL::text AS receiver_full_name
FROM
    "lab"."water" w
LEFT JOIN "reference"."status" stat ON w.status_id = stat.status_id
LEFT JOIN "lims"."projects" p ON w.project_id = p.project_id
LEFT JOIN "lab"."experiments" exp ON w.experiment_id = exp.experiment_id AND w.experiment_date = exp.experiment_date
LEFT JOIN "reference"."personal" exp_person ON exp.person_id = exp_person.person_id

UNION ALL

-- 8. Derived Otolith Samples
SELECT
    oto.otolith_id AS sample_id,
    NULL AS external_name,
    oto.sample_id AS parent_sample_id,
    'Otolith Sample' AS sample_origin_type,
    'Otolith' AS sample_type_id,
    'O' AS sample_type_abrv,
    COALESCE(oto.status_id, (SELECT status_id FROM "reference"."status" WHERE notes = 'Received')) AS status_id,
    COALESCE(stat.notes, 'Received') AS sample_status_notes,
    oto.workflow_id,
    oto.step_id,
    NULL::text AS sampling_id,
    oto.experiment_date AS sampling_date,
    NULL::date AS reception_date,
    oto.project_id,
    p.title AS project_title,
    NULL::integer AS customer_id,
    NULL::text AS customer_name,
    NULL::text AS storage_id,
    NULL::text AS storage_position,
    oto.notes,
    oto.attachment,
    oto.attachment_link,

    oto.experiment_id AS associated_experiment_id,
    exp.experiment_title AS associated_experiment_title,
    oto.experiment_date AS associated_experiment_date,
    exp_person.full_name AS experiment_person_name,

    NULL::text AS sampling_location, NULL::numeric AS sampling_depth_m, NULL::numeric AS temperature_atmospheric_c, NULL::text AS weather, NULL::numeric AS wind_speed, NULL::text AS wind_unit,
    NULL::numeric AS salinity, NULL::text AS salinity_unit, NULL::numeric AS oxygen, NULL::text AS oxygen_unit,
    NULL::numeric AS sampling_lon, NULL::numeric AS sampling_lat, NULL::numeric AS fishing_start_lon, NULL::numeric AS fishing_start_lat, NULL::numeric AS fishing_end_lon, NULL::numeric AS fishing_end_lat,

    NULL::text AS fish_species_id, NULL::text AS fish_species_en_name, NULL::numeric AS fish_total_length_mm, -- Fish (3)
    NULL::numeric AS tissue_weight_mg, NULL::text AS tissue_type, -- Tissue (2)
    NULL::numeric AS dna_volume_ul, NULL::numeric AS dna_concentration_ng_ul, NULL::date AS dna_extraction_date_dna, -- DNA (3)
    NULL::numeric AS rna_volume_ul, NULL::numeric AS rna_concentration_ng_ul, NULL::date AS rna_extraction_date_rna, -- RNA (3)
    oto.otolith_id, oto.age_reading_years AS otolith_age_reading_years, -- Otoliths (2)
    NULL::text AS extraction_id, NULL::date AS extraction_process_date, NULL::numeric AS extraction_process_yield_qubit_ng_ul, -- Extraction (3)
    NULL::text AS nanodrop_id, NULL::date AS nanodrop_measurement_date, NULL::numeric AS nanodrop_concentration, -- Nanodrop (3)
    NULL::text AS qubit_id, NULL::date AS qubit_measurement_date, NULL::numeric AS qubit_original_sample_conc, -- Qubit (3)
    NULL::text AS tapestation_id, NULL::date AS tapestation_measurement_date, -- Tapestation (2)
    NULL::text AS pcr_id, NULL::date AS pcr_date, NULL::text AS pcr_primer_id, -- PCR (3)
    NULL::text AS gelelectrophoresis_id, NULL::date AS gel_run_date, NULL::integer AS gel_band_size_bp, -- Gel Electrophoresis (3)
    NULL::text AS qpcr_id, NULL::date AS qpcr_date, NULL::numeric AS qpcr_ct_value, -- qPCR (3)
    NULL::text AS library_id, NULL::date AS library_prep_date, NULL::text AS library_name, -- Library (3)
    NULL::text AS sequencing_id, NULL::date AS sequencing_date, NULL::bigint AS total_reads, -- Sequencing (3)
    NULL::text AS analysis_run_id, NULL::date AS analysis_run_date, NULL::text AS pipeline_name, -- Analysis Runs (3)
    NULL::text AS edna_assignment_id, NULL::text AS edna_assigned_taxon_name, NULL::integer AS edna_read_count, -- eDNA Assignments (3)

    NULL::text AS sampler_full_name, NULL::text AS receiver_full_name
FROM
    "lab"."otoliths" oto
LEFT JOIN "reference"."status" stat ON oto.status_id = stat.status_id
LEFT JOIN "lims"."projects" p ON oto.project_id = p.project_id
LEFT JOIN "lab"."experiments" exp ON oto.experiment_id = exp.experiment_id AND oto.experiment_date = exp.experiment_date
LEFT JOIN "reference"."personal" exp_person ON exp.person_id = exp_person.person_id

UNION ALL

-- 9. Extraction Records (as a "sample" of the extraction process)
SELECT
    ext.extraction_id AS sample_id,
    NULL AS external_name,
    ext.sample_id AS parent_sample_id,
    'Extraction Process' AS sample_origin_type,
    'Extraction' AS sample_type_id,
    'EXT' AS sample_type_abrv,
    COALESCE(ext.status_id, (SELECT status_id FROM "reference"."status" WHERE notes = 'Extracted')) AS status_id,
    COALESCE(stat.notes, 'Extracted') AS sample_status_notes,
    NULL::text AS workflow_id,
    NULL::text AS step_id,
    NULL::text AS sampling_id,
    ext.extraction_date AS sampling_date,
    NULL::date AS reception_date,
    ext.project_id,
    p.title AS project_title,
    NULL::integer AS customer_id,
    NULL::text AS customer_name,
    ext.storage_id,
    ext.storage_position,
    ext.notes,
    ext.attachment,
    ext.attachment_link,

    ext.experiment_id AS associated_experiment_id,
    exp.experiment_title AS associated_experiment_title,
    ext.experiment_date AS associated_experiment_date,
    exp_person.full_name AS experiment_person_name,

    NULL::text AS sampling_location, NULL::numeric AS sampling_depth_m, NULL::numeric AS temperature_atmospheric_c, NULL::text AS weather, NULL::numeric AS wind_speed, NULL::text AS wind_unit,
    NULL::numeric AS salinity, NULL::text AS salinity_unit, NULL::numeric AS oxygen, NULL::text AS oxygen_unit,
    NULL::numeric AS sampling_lon, NULL::numeric AS sampling_lat, NULL::numeric AS fishing_start_lon, NULL::numeric AS fishing_start_lat, NULL::numeric AS fishing_end_lon, NULL::numeric AS fishing_end_lat,

    NULL::text AS fish_species_id, NULL::text AS fish_species_en_name, NULL::numeric AS fish_total_length_mm, -- Fish (3)
    NULL::numeric AS tissue_weight_mg, NULL::text AS tissue_type, -- Tissue (2)
    NULL::numeric AS dna_volume_ul, NULL::numeric AS dna_concentration_ng_ul, NULL::date AS dna_extraction_date_dna, -- DNA (3)
    NULL::numeric AS rna_volume_ul, NULL::numeric AS rna_concentration_ng_ul, NULL::date AS rna_extraction_date_rna, -- RNA (3)
    NULL::text AS otolith_id, NULL::numeric AS otolith_age_reading_years, -- Otoliths (2)
    ext.extraction_id, ext.extraction_date AS extraction_process_date, ext.yield_qubit_ng_ul AS extraction_process_yield_qubit_ng_ul, -- Extraction (3)
    NULL::text AS nanodrop_id, NULL::date AS nanodrop_measurement_date, NULL::numeric AS nanodrop_concentration, -- Nanodrop (3)
    NULL::text AS qubit_id, NULL::date AS qubit_measurement_date, NULL::numeric AS qubit_original_sample_conc, -- Qubit (3)
    NULL::text AS tapestation_id, NULL::date AS tapestation_measurement_date, -- Tapestation (2)
    NULL::text AS pcr_id, NULL::date AS pcr_date, NULL::text AS pcr_primer_id, -- PCR (3)
    NULL::text AS gelelectrophoresis_id, NULL::date AS gel_run_date, NULL::integer AS gel_band_size_bp, -- Gel Electrophoresis (3)
    NULL::text AS qpcr_id, NULL::date AS qpcr_date, NULL::numeric AS qpcr_ct_value, -- qPCR (3)
    NULL::text AS library_id, NULL::date AS library_prep_date, NULL::text AS library_name, -- Library (3)
    NULL::text AS sequencing_id, NULL::date AS sequencing_date, NULL::bigint AS total_reads, -- Sequencing (3)
    NULL::text AS analysis_run_id, NULL::date AS analysis_run_date, NULL::text AS pipeline_name, -- Analysis Runs (3)
    NULL::text AS edna_assignment_id, NULL::text AS edna_assigned_taxon_name, NULL::integer AS edna_read_count, -- eDNA Assignments (3)

    NULL::text AS sampler_full_name, NULL::text AS receiver_full_name
FROM
    "lab"."extraction" ext
LEFT JOIN "reference"."status" stat ON ext.status_id = stat.status_id
LEFT JOIN "lims"."projects" p ON ext.project_id = p.project_id
LEFT JOIN "lab"."experiments" exp ON ext.experiment_id = exp.experiment_id AND ext.experiment_date = exp.experiment_date
LEFT JOIN "reference"."personal" exp_person ON exp.person_id = exp_person.person_id

UNION ALL

-- 10. Nanodrop QC Records
SELECT
    nd.nanodrop_id AS sample_id,
    NULL AS external_name,
    nd.sample_id AS parent_sample_id,
    'Nanodrop QC Record' AS sample_origin_type,
    'Nanodrop QC' AS sample_type_id,
    'NDQC' AS sample_type_abrv,
    COALESCE(nd.status_id, (SELECT status_id FROM "reference"."status" WHERE notes = 'Nanodrop QC')) AS status_id,
    COALESCE(stat.notes, 'Nanodrop QC') AS sample_status_notes,
    NULL::text AS workflow_id,
    NULL::text AS step_id,
    NULL::text AS sampling_id,
    nd.measurement_date AS sampling_date,
    NULL::date AS reception_date,
    nd.project_id,
    p.title AS project_title,
    NULL::integer AS customer_id,
    NULL::text AS customer_name,
    nd.storage_id,
    nd.storage_position,
    nd.notes,
    nd.attachment,
    nd.attachment_link,

    nd.experiment_id AS associated_experiment_id,
    exp.experiment_title AS associated_experiment_title,
    nd.experiment_date AS associated_experiment_date,
    exp_person.full_name AS experiment_person_name,

    NULL::text AS sampling_location, NULL::numeric AS sampling_depth_m, NULL::numeric AS temperature_atmospheric_c, NULL::text AS weather, NULL::numeric AS wind_speed, NULL::text AS wind_unit,
    NULL::numeric AS salinity, NULL::text AS salinity_unit, NULL::numeric AS oxygen, NULL::text AS oxygen_unit,
    NULL::numeric AS sampling_lon, NULL::numeric AS sampling_lat, NULL::numeric AS fishing_start_lon, NULL::numeric AS fishing_start_lat, NULL::numeric AS fishing_end_lon, NULL::numeric AS fishing_end_lat,

    NULL::text AS fish_species_id, NULL::text AS fish_species_en_name, NULL::numeric AS fish_total_length_mm, -- Fish (3)
    NULL::numeric AS tissue_weight_mg, NULL::text AS tissue_type, -- Tissue (2)
    NULL::numeric AS dna_volume_ul, NULL::numeric AS dna_concentration_ng_ul, NULL::date AS dna_extraction_date_dna, -- DNA (3)
    NULL::numeric AS rna_volume_ul, NULL::numeric AS rna_concentration_ng_ul, NULL::date AS rna_extraction_date_rna, -- RNA (3)
    NULL::text AS otolith_id, NULL::numeric AS otolith_age_reading_years, -- Otoliths (2)
    NULL::text AS extraction_id, NULL::date AS extraction_process_date, NULL::numeric AS extraction_process_yield_qubit_ng_ul, -- Extraction (3)
    nd.nanodrop_id, nd.measurement_date, nd.nanodrop_concentration, -- Nanodrop (3)
    NULL::text AS qubit_id, NULL::date AS qubit_measurement_date, NULL::numeric AS qubit_original_sample_conc, -- Qubit (3)
    NULL::text AS tapestation_id, NULL::date AS tapestation_measurement_date, -- Tapestation (2)
    NULL::text AS pcr_id, NULL::date AS pcr_date, NULL::text AS pcr_primer_id, -- PCR (3)
    NULL::text AS gelelectrophoresis_id, NULL::date AS gel_run_date, NULL::integer AS gel_band_size_bp, -- Gel Electrophoresis (3)
    NULL::text AS qpcr_id, NULL::date AS qpcr_date, NULL::numeric AS qpcr_ct_value, -- qPCR (3)
    NULL::text AS library_id, NULL::date AS library_prep_date, NULL::text AS library_name, -- Library (3)
    NULL::text AS sequencing_id, NULL::date AS sequencing_date, NULL::bigint AS total_reads, -- Sequencing (3)
    NULL::text AS analysis_run_id, NULL::date AS analysis_run_date, NULL::text AS pipeline_name, -- Analysis Runs (3)
    NULL::text AS edna_assignment_id, NULL::text AS edna_assigned_taxon_name, NULL::integer AS edna_read_count, -- eDNA Assignments (3)

    NULL::text AS sampler_full_name, NULL::text AS receiver_full_name
FROM
    "lab"."nanodrop" nd
LEFT JOIN "reference"."status" stat ON nd.status_id = stat.status_id
LEFT JOIN "lims"."projects" p ON nd.project_id = p.project_id
LEFT JOIN "lab"."experiments" exp ON nd.experiment_id = exp.experiment_id AND nd.experiment_date = exp.experiment_date
LEFT JOIN "reference"."personal" exp_person ON exp.person_id = exp_person.person_id

UNION ALL

-- 11. Qubit QC Records
SELECT
    qu.qubit_id AS sample_id,
    NULL AS external_name,
    qu.sample_id AS parent_sample_id,
    'Qubit QC Record' AS sample_origin_type,
    'Qubit QC' AS sample_type_id,
    'QBC' AS sample_type_abrv,
    COALESCE(qu.status_id, (SELECT status_id FROM "reference"."status" WHERE notes = 'Qubit QC')) AS status_id,
    COALESCE(stat.notes, 'Qubit QC') AS sample_status_notes,
    NULL::text AS workflow_id,
    NULL::text AS step_id,
    NULL::text AS sampling_id,
    qu.measurement_date AS sampling_date,
    NULL::date AS reception_date,
    qu.project_id,
    p.title AS project_title,
    NULL::integer AS customer_id,
    NULL::text AS customer_name,
    qu.storage_id,
    qu.storage_position,
    qu.notes,
    qu.attachment,
    qu.attachment_link,

    qu.experiment_id AS associated_experiment_id,
    exp.experiment_title AS associated_experiment_title,
    qu.experiment_date AS associated_experiment_date,
    exp_person.full_name AS experiment_person_name,

    NULL::text AS sampling_location, NULL::numeric AS sampling_depth_m, NULL::numeric AS temperature_atmospheric_c, NULL::text AS weather, NULL::numeric AS wind_speed, NULL::text AS wind_unit,
    NULL::numeric AS salinity, NULL::text AS salinity_unit, NULL::numeric AS oxygen, NULL::text AS oxygen_unit,
    NULL::numeric AS sampling_lon, NULL::numeric AS sampling_lat, NULL::numeric AS fishing_start_lon, NULL::numeric AS fishing_start_lat, NULL::numeric AS fishing_end_lon, NULL::numeric AS fishing_end_lat,

    NULL::text AS fish_species_id, NULL::text AS fish_species_en_name, NULL::numeric AS fish_total_length_mm, -- Fish (3)
    NULL::numeric AS tissue_weight_mg, NULL::text AS tissue_type, -- Tissue (2)
    NULL::numeric AS dna_volume_ul, NULL::numeric AS dna_concentration_ng_ul, NULL::date AS dna_extraction_date_dna, -- DNA (3)
    NULL::numeric AS rna_volume_ul, NULL::numeric AS rna_concentration_ng_ul, NULL::date AS rna_extraction_date_rna, -- RNA (3)
    NULL::text AS otolith_id, NULL::numeric AS otolith_age_reading_years, -- Otoliths (2)
    NULL::text AS extraction_id, NULL::date AS extraction_process_date, NULL::numeric AS extraction_process_yield_qubit_ng_ul, -- Extraction (3)
    NULL::text AS nanodrop_id, NULL::date AS nanodrop_measurement_date, NULL::numeric AS nanodrop_concentration, -- Nanodrop (3)
    qu.qubit_id, qu.measurement_date, qu.qubit_original_sample_conc, -- Qubit (3)
    NULL::text AS tapestation_id, NULL::date AS tapestation_measurement_date, -- Tapestation (2)
    NULL::text AS pcr_id, NULL::date AS pcr_date, NULL::text AS pcr_primer_id, -- PCR (3)
    NULL::text AS gelelectrophoresis_id, NULL::date AS gel_run_date, NULL::integer AS gel_band_size_bp, -- Gel Electrophoresis (3)
    NULL::text AS qpcr_id, NULL::date AS qpcr_date, NULL::numeric AS qpcr_ct_value, -- qPCR (3)
    NULL::text AS library_id, NULL::date AS library_prep_date, NULL::text AS library_name, -- Library (3)
    NULL::text AS sequencing_id, NULL::date AS sequencing_date, NULL::bigint AS total_reads, -- Sequencing (3)
    NULL::text AS analysis_run_id, NULL::date AS analysis_run_date, NULL::text AS pipeline_name, -- Analysis Runs (3)
    NULL::text AS edna_assignment_id, NULL::text AS edna_assigned_taxon_name, NULL::integer AS edna_read_count, -- eDNA Assignments (3)

    NULL::text AS sampler_full_name, NULL::text AS receiver_full_name
FROM
    "lab"."qubit" qu
LEFT JOIN "reference"."status" stat ON qu.status_id = stat.status_id
LEFT JOIN "lims"."projects" p ON qu.project_id = p.project_id
LEFT JOIN "lab"."experiments" exp ON qu.experiment_id = exp.experiment_id AND qu.experiment_date = exp.experiment_date
LEFT JOIN "reference"."personal" exp_person ON exp.person_id = exp_person.person_id

UNION ALL

-- 12. Tapestation QC Records
SELECT
    ts.tapestation_id AS sample_id,
    NULL AS external_name,
    ts.sample_id AS parent_sample_id,
    'Tapestation QC Record' AS sample_origin_type,
    'Tapestation QC' AS sample_type_id,
    'TSQC' AS sample_type_abrv,
    COALESCE(ts.status_id, (SELECT status_id FROM "reference"."status" WHERE notes = 'Tapestation QC')) AS status_id,
    COALESCE(stat.notes, 'Tapestation QC') AS sample_status_notes,
    NULL::text AS workflow_id,
    NULL::text AS step_id,
    NULL::text AS sampling_id,
    ts.measurement_date AS sampling_date,
    NULL::date AS reception_date,
    ts.project_id,
    p.title AS project_title,
    NULL::integer AS customer_id,
    NULL::text AS customer_name,
    ts.storage_id,
    ts.storage_position,
    ts.notes,
    ts.attachment,
    ts.attachment_link,

    ts.experiment_id AS associated_experiment_id,
    exp.experiment_title AS associated_experiment_title,
    ts.experiment_date AS associated_experiment_date,
    exp_person.full_name AS experiment_person_name,

    NULL::text AS sampling_location, NULL::numeric AS sampling_depth_m, NULL::numeric AS temperature_atmospheric_c, NULL::text AS weather, NULL::numeric AS wind_speed, NULL::text AS wind_unit,
    NULL::numeric AS salinity, NULL::text AS salinity_unit, NULL::numeric AS oxygen, NULL::text AS oxygen_unit,
    NULL::numeric AS sampling_lon, NULL::numeric AS sampling_lat, NULL::numeric AS fishing_start_lon, NULL::numeric AS fishing_start_lat, NULL::numeric AS fishing_end_lon, NULL::numeric AS fishing_end_lat,

    NULL::text AS fish_species_id, NULL::text AS fish_species_en_name, NULL::numeric AS fish_total_length_mm, -- Fish (3)
    NULL::numeric AS tissue_weight_mg, NULL::text AS tissue_type, -- Tissue (2)
    NULL::numeric AS dna_volume_ul, NULL::numeric AS dna_concentration_ng_ul, NULL::date AS dna_extraction_date_dna, -- DNA (3)
    NULL::numeric AS rna_volume_ul, NULL::numeric AS rna_concentration_ng_ul, NULL::date AS rna_extraction_date_rna, -- RNA (3)
    NULL::text AS otolith_id, NULL::numeric AS otolith_age_reading_years, -- Otoliths (2)
    NULL::text AS extraction_id, NULL::date AS extraction_process_date, NULL::numeric AS extraction_process_yield_qubit_ng_ul, -- Extraction (3)
    NULL::text AS nanodrop_id, NULL::date AS nanodrop_measurement_date, NULL::numeric AS nanodrop_concentration, -- Nanodrop (3)
    NULL::text AS qubit_id, NULL::date AS qubit_measurement_date, NULL::numeric AS qubit_original_sample_conc, -- Qubit (3)
    ts.tapestation_id, ts.measurement_date, -- Tapestation (2)
    NULL::text AS pcr_id, NULL::date AS pcr_date, NULL::text AS pcr_primer_id, -- PCR (3)
    NULL::text AS gelelectrophoresis_id, NULL::date AS gel_run_date, NULL::integer AS gel_band_size_bp, -- Gel Electrophoresis (3)
    NULL::text AS qpcr_id, NULL::date AS qpcr_date, NULL::numeric AS qpcr_ct_value, -- qPCR (3)
    NULL::text AS library_id, NULL::date AS library_prep_date, NULL::text AS library_name, -- Library (3)
    NULL::text AS sequencing_id, NULL::date AS sequencing_date, NULL::bigint AS total_reads, -- Sequencing (3)
    NULL::text AS analysis_run_id, NULL::date AS analysis_run_date, NULL::text AS pipeline_name, -- Analysis Runs (3)
    NULL::text AS edna_assignment_id, NULL::text AS edna_assigned_taxon_name, NULL::integer AS edna_read_count, -- eDNA Assignments (3)

    NULL::text AS sampler_full_name, NULL::text AS receiver_full_name
FROM
    "lab"."tapestation" ts
LEFT JOIN "reference"."status" stat ON ts.status_id = stat.status_id
LEFT JOIN "lims"."projects" p ON ts.project_id = p.project_id
LEFT JOIN "lab"."experiments" exp ON ts.experiment_id = exp.experiment_id AND ts.experiment_date = exp.experiment_date
LEFT JOIN "reference"."personal" exp_person ON exp.person_id = exp_person.person_id

UNION ALL

-- 13. PCR Records
SELECT
    pcr.pcr_id AS sample_id,
    NULL AS external_name,
    pcr.sample_id AS parent_sample_id,
    'PCR Product' AS sample_origin_type,
    'PCR Product' AS sample_type_id,
    'PCRP' AS sample_type_abrv,
    COALESCE(pcr.status_id, (SELECT status_id FROM "reference"."status" WHERE notes = 'PCR Done')) AS status_id,
    COALESCE(stat.notes, 'PCR Done') AS sample_status_notes,
    NULL::text AS workflow_id,
    NULL::text AS step_id,
    NULL::text AS sampling_id,
    pcr.pcr_date AS sampling_date,
    NULL::date AS reception_date,
    pcr.project_id,
    p.title AS project_title,
    NULL::integer AS customer_id,
    NULL::text AS customer_name,
    pcr.storage_id,
    pcr.storage_position,
    pcr.notes,
    pcr.attachment,
    pcr.attachment_link,

    pcr.experiment_id AS associated_experiment_id,
    exp.experiment_title AS associated_experiment_title,
    pcr.experiment_date AS associated_experiment_date,
    exp_person.full_name AS experiment_person_name,

    NULL::text AS sampling_location, NULL::numeric AS sampling_depth_m, NULL::numeric AS temperature_atmospheric_c, NULL::text AS weather, NULL::numeric AS wind_speed, NULL::text AS wind_unit,
    NULL::numeric AS salinity, NULL::text AS salinity_unit, NULL::numeric AS oxygen, NULL::text AS oxygen_unit,
    NULL::numeric AS sampling_lon, NULL::numeric AS sampling_lat, NULL::numeric AS fishing_start_lon, NULL::numeric AS fishing_start_lat, NULL::numeric AS fishing_end_lon, NULL::numeric AS fishing_end_lat,

    NULL::text AS fish_species_id, NULL::text AS fish_species_en_name, NULL::numeric AS fish_total_length_mm, -- Fish (3)
    NULL::numeric AS tissue_weight_mg, NULL::text AS tissue_type, -- Tissue (2)
    NULL::numeric AS dna_volume_ul, NULL::numeric AS dna_concentration_ng_ul, NULL::date AS dna_extraction_date_dna, -- DNA (3)
    NULL::numeric AS rna_volume_ul, NULL::numeric AS rna_concentration_ng_ul, NULL::date AS rna_extraction_date_rna, -- RNA (3)
    NULL::text AS otolith_id, NULL::numeric AS otolith_age_reading_years, -- Otoliths (2)
    NULL::text AS extraction_id, NULL::date AS extraction_process_date, NULL::numeric AS extraction_process_yield_qubit_ng_ul, -- Extraction (3)
    NULL::text AS nanodrop_id, NULL::date AS nanodrop_measurement_date, NULL::numeric AS nanodrop_concentration, -- Nanodrop (3)
    NULL::text AS qubit_id, NULL::date AS qubit_measurement_date, NULL::numeric AS qubit_original_sample_conc, -- Qubit (3)
    NULL::text AS tapestation_id, NULL::date AS tapestation_measurement_date, -- Tapestation (2)
    pcr.pcr_id, pcr.pcr_date, pcr.primer_id AS pcr_primer_id, -- PCR (3)
    NULL::text AS gelelectrophoresis_id, NULL::date AS gel_run_date, NULL::integer AS gel_band_size_bp, -- Gel Electrophoresis (3)
    NULL::text AS qpcr_id, NULL::date AS qpcr_date, NULL::numeric AS qpcr_ct_value, -- qPCR (3)
    NULL::text AS library_id, NULL::date AS library_prep_date, NULL::text AS library_name, -- Library (3)
    NULL::text AS sequencing_id, NULL::date AS sequencing_date, NULL::bigint AS total_reads, -- Sequencing (3)
    NULL::text AS analysis_run_id, NULL::date AS analysis_run_date, NULL::text AS pipeline_name, -- Analysis Runs (3)
    NULL::text AS edna_assignment_id, NULL::text AS edna_assigned_taxon_name, NULL::integer AS edna_read_count, -- eDNA Assignments (3)

    NULL::text AS sampler_full_name, NULL::text AS receiver_full_name
FROM
    "lab"."pcr" pcr
LEFT JOIN "reference"."status" stat ON pcr.status_id = stat.status_id
LEFT JOIN "lims"."projects" p ON pcr.project_id = p.project_id
LEFT JOIN "lab"."experiments" exp ON pcr.experiment_id = exp.experiment_id AND pcr.experiment_date = exp.experiment_date
LEFT JOIN "reference"."personal" exp_person ON exp.person_id = exp_person.person_id

UNION ALL

-- 14. Gel Electrophoresis Records
SELECT
    gel.gelelectrophoresis_id AS sample_id,
    NULL AS external_name,
    gel.sample_id AS parent_sample_id,
    'Gel Electrophoresis Result' AS sample_origin_type,
    'Gel Electrophoresis' AS sample_type_id,
    'GE' AS sample_type_abrv,
    COALESCE(gel.status_id, (SELECT status_id FROM "reference"."status" WHERE notes = 'Unknown Step')) AS status_id,
    COALESCE(stat.notes, 'Unknown Step') AS sample_status_notes,
    NULL::text AS workflow_id,
    NULL::text AS step_id,
    NULL::text AS sampling_id,
    gel.run_date AS sampling_date,
    NULL::date AS reception_date,
    gel.project_id,
    p.title AS project_title,
    NULL::integer AS customer_id,
    NULL::text AS customer_name,
    gel.storage_id,
    gel.storage_position,
    gel.notes,
    gel.attachment,
    gel.attachment_link,

    gel.experiment_id AS associated_experiment_id,
    exp.experiment_title AS associated_experiment_title,
    gel.experiment_date AS associated_experiment_date,
    exp_person.full_name AS experiment_person_name,

    NULL::text AS sampling_location, NULL::numeric AS sampling_depth_m, NULL::numeric AS temperature_atmospheric_c, NULL::text AS weather, NULL::numeric AS wind_speed, NULL::text AS wind_unit,
    NULL::numeric AS salinity, NULL::text AS salinity_unit, NULL::numeric AS oxygen, NULL::text AS oxygen_unit,
    NULL::numeric AS sampling_lon, NULL::numeric AS sampling_lat, NULL::numeric AS fishing_start_lon, NULL::numeric AS fishing_start_lat, NULL::numeric AS fishing_end_lon, NULL::numeric AS fishing_end_lat,

    NULL::text AS fish_species_id, NULL::text AS fish_species_en_name, NULL::numeric AS fish_total_length_mm, -- Fish (3)
    NULL::numeric AS tissue_weight_mg, NULL::text AS tissue_type, -- Tissue (2)
    NULL::numeric AS dna_volume_ul, NULL::numeric AS dna_concentration_ng_ul, NULL::date AS dna_extraction_date_dna, -- DNA (3)
    NULL::numeric AS rna_volume_ul, NULL::numeric AS rna_concentration_ng_ul, NULL::date AS rna_extraction_date_rna, -- RNA (3)
    NULL::text AS otolith_id, NULL::numeric AS otolith_age_reading_years, -- Otoliths (2)
    NULL::text AS extraction_id, NULL::date AS extraction_process_date, NULL::numeric AS extraction_process_yield_qubit_ng_ul, -- Extraction (3)
    NULL::text AS nanodrop_id, NULL::date AS nanodrop_measurement_date, NULL::numeric AS nanodrop_concentration, -- Nanodrop (3)
    NULL::text AS qubit_id, NULL::date AS qubit_measurement_date, NULL::numeric AS qubit_original_sample_conc, -- Qubit (3)
    NULL::text AS tapestation_id, NULL::date AS tapestation_measurement_date, -- Tapestation (2)
    NULL::text AS pcr_id, NULL::date AS pcr_date, NULL::text AS pcr_primer_id, -- PCR (3)
    gel.gelelectrophoresis_id, gel.run_date, gel.band_size_bp, -- Gel Electrophoresis (3)
    NULL::text AS qpcr_id, NULL::date AS qpcr_date, NULL::numeric AS qpcr_ct_value, -- qPCR (3)
    NULL::text AS library_id, NULL::date AS library_prep_date, NULL::text AS library_name, -- Library (3)
    NULL::text AS sequencing_id, NULL::date AS sequencing_date, NULL::bigint AS total_reads, -- Sequencing (3)
    NULL::text AS analysis_run_id, NULL::date AS analysis_run_date, NULL::text AS pipeline_name, -- Analysis Runs (3)
    NULL::text AS edna_assignment_id, NULL::text AS edna_assigned_taxon_name, NULL::integer AS edna_read_count, -- eDNA Assignments (3)

    NULL::text AS sampler_full_name, NULL::text AS receiver_full_name
FROM
    "lab"."gelelectrophoresis" gel
LEFT JOIN "reference"."status" stat ON gel.status_id = stat.status_id
LEFT JOIN "lims"."projects" p ON gel.project_id = p.project_id
LEFT JOIN "lab"."experiments" exp ON gel.experiment_id = exp.experiment_id AND gel.experiment_date = exp.experiment_date
LEFT JOIN "reference"."personal" exp_person ON exp.person_id = exp_person.person_id

UNION ALL

-- 15. qPCR Records
SELECT
    qpcr.qpcr_id AS sample_id,
    NULL AS external_name,
    qpcr.sample_id AS parent_sample_id,
    'qPCR Result' AS sample_origin_type,
    'qPCR' AS sample_type_id,
    'QPCRR' AS sample_type_abrv,
    COALESCE(qpcr.status_id, (SELECT status_id FROM "reference"."status" WHERE notes = 'qPCR Done')) AS status_id,
    COALESCE(stat.notes, 'qPCR Done') AS sample_status_notes,
    NULL::text AS workflow_id,
    NULL::text AS step_id,
    NULL::text AS sampling_id,
    qpcr.qpcr_date AS sampling_date,
    NULL::date AS reception_date,
    qpcr.project_id,
    p.title AS project_title,
    NULL::integer AS customer_id,
    NULL::text AS customer_name,
    qpcr.storage_id,
    qpcr.storage_position,
    qpcr.notes,
    qpcr.attachment,
    qpcr.attachment_link,

    qpcr.experiment_id AS associated_experiment_id,
    exp.experiment_title AS associated_experiment_title,
    qpcr.experiment_date AS associated_experiment_date,
    exp_person.full_name AS experiment_person_name,

    NULL::text AS sampling_location, NULL::numeric AS sampling_depth_m, NULL::numeric AS temperature_atmospheric_c, NULL::text AS weather, NULL::numeric AS wind_speed, NULL::text AS wind_unit,
    NULL::numeric AS salinity, NULL::text AS salinity_unit, NULL::numeric AS oxygen, NULL::text AS oxygen_unit,
    NULL::numeric AS sampling_lon, NULL::numeric AS sampling_lat, NULL::numeric AS fishing_start_lon, NULL::numeric AS fishing_start_lat, NULL::numeric AS fishing_end_lon, NULL::numeric AS fishing_end_lat,

    NULL::text AS fish_species_id, NULL::text AS fish_species_en_name, NULL::numeric AS fish_total_length_mm, -- Fish (3)
    NULL::numeric AS tissue_weight_mg, NULL::text AS tissue_type, -- Tissue (2)
    NULL::numeric AS dna_volume_ul, NULL::numeric AS dna_concentration_ng_ul, NULL::date AS dna_extraction_date_dna, -- DNA (3)
    NULL::numeric AS rna_volume_ul, NULL::numeric AS rna_concentration_ng_ul, NULL::date AS rna_extraction_date_rna, -- RNA (3)
    NULL::text AS otolith_id, NULL::numeric AS otolith_age_reading_years, -- Otoliths (2)
    NULL::text AS extraction_id, NULL::date AS extraction_process_date, NULL::numeric AS extraction_process_yield_qubit_ng_ul, -- Extraction (3)
    NULL::text AS nanodrop_id, NULL::date AS nanodrop_measurement_date, NULL::numeric AS nanodrop_concentration, -- Nanodrop (3)
    NULL::text AS qubit_id, NULL::date AS qubit_measurement_date, NULL::numeric AS qubit_original_sample_conc, -- Qubit (3)
    NULL::text AS tapestation_id, NULL::date AS tapestation_measurement_date, -- Tapestation (2)
    NULL::text AS pcr_id, NULL::date AS pcr_date, NULL::text AS pcr_primer_id, -- PCR (3)
    NULL::text AS gelelectrophoresis_id, NULL::date AS gel_run_date, NULL::integer AS gel_band_size_bp, -- Gel Electrophoresis (3)
    qpcr.qpcr_id, qpcr.qpcr_date, qpcr.ct_value, -- qPCR (3)
    NULL::text AS library_id, NULL::date AS library_prep_date, NULL::text AS library_name, -- Library (3)
    NULL::text AS sequencing_id, NULL::date AS sequencing_date, NULL::bigint AS total_reads, -- Sequencing (3)
    NULL::text AS analysis_run_id, NULL::date AS analysis_run_date, NULL::text AS pipeline_name, -- Analysis Runs (3)
    NULL::text AS edna_assignment_id, NULL::text AS edna_assigned_taxon_name, NULL::integer AS edna_read_count, -- eDNA Assignments (3)

    NULL::text AS sampler_full_name, NULL::text AS receiver_full_name
FROM
    "lab"."qpcr" qpcr
LEFT JOIN "reference"."status" stat ON qpcr.status_id = stat.status_id
LEFT JOIN "lims"."projects" p ON qpcr.project_id = p.project_id
LEFT JOIN "lab"."experiments" exp ON qpcr.experiment_id = exp.experiment_id AND qpcr.experiment_date = exp.experiment_date
LEFT JOIN "reference"."personal" exp_person ON exp.person_id = exp_person.person_id

UNION ALL

-- 16. Library Records
SELECT
    lib.library_id AS sample_id,
    NULL AS external_name,
    lib.sample_id AS parent_sample_id,
    'Library Prep Product' AS sample_origin_type,
    'Library' AS sample_type_id,
    'LIBP' AS sample_type_abrv,
    COALESCE(lib.status_id, (SELECT status_id FROM "reference"."status" WHERE notes = 'Library Prep')) AS status_id,
    COALESCE(stat.notes, 'Library Prep') AS sample_status_notes,
    NULL::text AS workflow_id,
    NULL::text AS step_id,
    NULL::text AS sampling_id,
    lib.prep_date AS sampling_date,
    NULL::date AS reception_date,
    lib.project_id,
    p.title AS project_title,
    NULL::integer AS customer_id,
    NULL::text AS customer_name,
    lib.storage_id,
    lib.storage_position,
    lib.notes,
    lib.attachment,
    lib.attachment_link,

    lib.experiment_id AS associated_experiment_id,
    exp.experiment_title AS associated_experiment_title,
    lib.experiment_date AS associated_experiment_date,
    exp_person.full_name AS experiment_person_name,

    NULL::text AS sampling_location, NULL::numeric AS sampling_depth_m, NULL::numeric AS temperature_atmospheric_c, NULL::text AS weather, NULL::numeric AS wind_speed, NULL::text AS wind_unit,
    NULL::numeric AS salinity, NULL::text AS salinity_unit, NULL::numeric AS oxygen, NULL::text AS oxygen_unit,
    NULL::numeric AS sampling_lon, NULL::numeric AS sampling_lat, NULL::numeric AS fishing_start_lon, NULL::numeric AS fishing_start_lat, NULL::numeric AS fishing_end_lon, NULL::numeric AS fishing_end_lat,

    NULL::text AS fish_species_id, NULL::text AS fish_species_en_name, NULL::numeric AS fish_total_length_mm, -- Fish (3)
    NULL::numeric AS tissue_weight_mg, NULL::text AS tissue_type, -- Tissue (2)
    NULL::numeric AS dna_volume_ul, NULL::numeric AS dna_concentration_ng_ul, NULL::date AS dna_extraction_date_dna, -- DNA (3)
    NULL::numeric AS rna_volume_ul, NULL::numeric AS rna_concentration_ng_ul, NULL::date AS rna_extraction_date_rna, -- RNA (3)
    NULL::text AS otolith_id, NULL::numeric AS otolith_age_reading_years, -- Otoliths (2)
    NULL::text AS extraction_id, NULL::date AS extraction_process_date, NULL::numeric AS extraction_process_yield_qubit_ng_ul, -- Extraction (3)
    NULL::text AS nanodrop_id, NULL::date AS nanodrop_measurement_date, NULL::numeric AS nanodrop_concentration, -- Nanodrop (3)
    NULL::text AS qubit_id, NULL::date AS qubit_measurement_date, NULL::numeric AS qubit_original_sample_conc, -- Qubit (3)
    NULL::text AS tapestation_id, NULL::date AS tapestation_measurement_date, -- Tapestation (2)
    NULL::text AS pcr_id, NULL::date AS pcr_date, NULL::text AS pcr_primer_id, -- PCR (3)
    NULL::text AS gelelectrophoresis_id, NULL::date AS gel_run_date, NULL::integer AS gel_band_size_bp, -- Gel Electrophoresis (3)
    NULL::text AS qpcr_id, NULL::date AS qpcr_date, NULL::numeric AS qpcr_ct_value, -- qPCR (3)
    lib.library_id, lib.prep_date, lib.library_name, -- Library (3)
    NULL::text AS sequencing_id, NULL::date AS sequencing_date, NULL::bigint AS total_reads, -- Sequencing (3)
    NULL::text AS analysis_run_id, NULL::date AS analysis_run_date, NULL::text AS pipeline_name, -- Analysis Runs (3)
    NULL::text AS edna_assignment_id, NULL::text AS edna_assigned_taxon_name, NULL::integer AS edna_read_count, -- eDNA Assignments (3)

    NULL::text AS sampler_full_name, NULL::text AS receiver_full_name
FROM
    "lab"."library" lib
LEFT JOIN "reference"."status" stat ON lib.status_id = stat.status_id
LEFT JOIN "lims"."projects" p ON lib.project_id = p.project_id
LEFT JOIN "lab"."experiments" exp ON lib.experiment_id = exp.experiment_id AND lib.experiment_date = exp.experiment_date
LEFT JOIN "reference"."personal" exp_person ON exp.person_id = exp_person.person_id

UNION ALL

-- 17. Sequencing Records
SELECT
    seq.sequencing_id AS sample_id,
    NULL AS external_name,
    seq.sample_id AS parent_sample_id,
    'Sequencing Run' AS sample_origin_type,
    'Sequencing' AS sample_type_id,
    'SEQR' AS sample_type_abrv,
    COALESCE(seq.status_id, (SELECT status_id FROM "reference"."status" WHERE notes = 'Sequencing Done')) AS status_id,
    COALESCE(stat.notes, 'Sequencing Done') AS sample_status_notes,
    NULL::text AS workflow_id,
    NULL::text AS step_id,
    NULL::text AS sampling_id,
    seq.sequencing_date AS sampling_date,
    NULL::date AS reception_date,
    seq.project_id,
    p.title AS project_title,
    NULL::integer AS customer_id,
    NULL::text AS customer_name,
    seq.storage_id,
    seq.storage_position,
    seq.notes,
    seq.attachment,
    seq.attachment_link,

    seq.experiment_id AS associated_experiment_id,
    exp.experiment_title AS associated_experiment_title,
    seq.experiment_date AS associated_experiment_date,
    exp_person.full_name AS experiment_person_name,

    NULL::text AS sampling_location, NULL::numeric AS sampling_depth_m, NULL::numeric AS temperature_atmospheric_c, NULL::text AS weather, NULL::numeric AS wind_speed, NULL::text AS wind_unit,
    NULL::numeric AS salinity, NULL::text AS salinity_unit, NULL::numeric AS oxygen, NULL::text AS oxygen_unit,
    NULL::numeric AS sampling_lon, NULL::numeric AS sampling_lat, NULL::numeric AS fishing_start_lon, NULL::numeric AS fishing_start_lat, NULL::numeric AS fishing_end_lon, NULL::numeric AS fishing_end_lat,

    NULL::text AS fish_species_id, NULL::text AS fish_species_en_name, NULL::numeric AS fish_total_length_mm, -- Fish (3)
    NULL::numeric AS tissue_weight_mg, NULL::text AS tissue_type, -- Tissue (2)
    NULL::numeric AS dna_volume_ul, NULL::numeric AS dna_concentration_ng_ul, NULL::date AS dna_extraction_date_dna, -- DNA (3)
    NULL::numeric AS rna_volume_ul, NULL::numeric AS rna_concentration_ng_ul, NULL::date AS rna_extraction_date_rna, -- RNA (3)
    NULL::text AS otolith_id, NULL::numeric AS otolith_age_reading_years, -- Otoliths (2)
    NULL::text AS extraction_id, NULL::date AS extraction_process_date, NULL::numeric AS extraction_process_yield_qubit_ng_ul, -- Extraction (3)
    NULL::text AS nanodrop_id, NULL::date AS nanodrop_measurement_date, NULL::numeric AS nanodrop_concentration, -- Nanodrop (3)
    NULL::text AS qubit_id, NULL::date AS qubit_measurement_date, NULL::numeric AS qubit_original_sample_conc, -- Qubit (3)
    NULL::text AS tapestation_id, NULL::date AS tapestation_measurement_date, -- Tapestation (2)
    NULL::text AS pcr_id, NULL::date AS pcr_date, NULL::text AS pcr_primer_id, -- PCR (3)
    NULL::text AS gelelectrophoresis_id, NULL::date AS gel_run_date, NULL::integer AS gel_band_size_bp, -- Gel Electrophoresis (3)
    NULL::text AS qpcr_id, NULL::date AS qpcr_date, NULL::numeric AS qpcr_ct_value, -- qPCR (3)
    NULL::text AS library_id, NULL::date AS library_prep_date, NULL::text AS library_name, -- Library (3)
    seq.sequencing_id, seq.sequencing_date, seq.total_reads, -- Sequencing (3)
    NULL::text AS analysis_run_id, NULL::date AS analysis_run_date, NULL::text AS pipeline_name, -- Analysis Runs (3)
    NULL::text AS edna_assignment_id, NULL::text AS edna_assigned_taxon_name, NULL::integer AS edna_read_count, -- eDNA Assignments (3)

    NULL::text AS sampler_full_name, NULL::text AS receiver_full_name
FROM
    "lab"."sequencing" seq
LEFT JOIN "reference"."status" stat ON seq.status_id = stat.status_id
LEFT JOIN "lims"."projects" p ON seq.project_id = p.project_id
LEFT JOIN "lab"."experiments" exp ON seq.experiment_id = exp.experiment_id AND seq.experiment_date = exp.experiment_date
LEFT JOIN "reference"."personal" exp_person ON exp.person_id = exp_person.person_id

UNION ALL

-- 18. Analysis Runs (as a "sample" of the bioinformatics process)
SELECT
    ar.run_id AS sample_id,
    NULL AS external_name,
    ar.sequencing_id AS parent_sample_id,
    'Bioinformatics Analysis Run' AS sample_origin_type,
    'Bioinformatics' AS sample_type_id,
    'Analysis' AS sample_type_abrv,
    COALESCE(ar.status_id, (SELECT status_id FROM "reference"."status" WHERE notes = 'Bioinformatics Done')) AS status_id,
    COALESCE(stat.notes, 'Bioinformatics Done') AS sample_status_notes,
    NULL::text AS workflow_id,
    NULL::text AS step_id,
    NULL::text AS sampling_id,
    ar.run_date::date AS sampling_date,
    NULL::date AS reception_date,
    NULL::text AS project_id,
    NULL::text AS project_title,
    NULL::integer AS customer_id,
    NULL::text AS customer_name,
    NULL::text AS storage_id,
    NULL::text AS storage_position,
    ar.notes,
    ar.attachment,
    ar.attachment_link,

    ar.experiment_id AS associated_experiment_id,
    exp.experiment_title AS associated_experiment_title,
    ar.experiment_date AS associated_experiment_date,
    exp_person.full_name AS experiment_person_name,

    NULL::text AS sampling_location, NULL::numeric AS sampling_depth_m, NULL::numeric AS temperature_atmospheric_c, NULL::text AS weather, NULL::numeric AS wind_speed, NULL::text AS wind_unit,
    NULL::numeric AS salinity, NULL::text AS salinity_unit, NULL::numeric AS oxygen, NULL::text AS oxygen_unit,
    NULL::numeric AS sampling_lon, NULL::numeric AS sampling_lat, NULL::numeric AS fishing_start_lon, NULL::numeric AS fishing_start_lat, NULL::numeric AS fishing_end_lon, NULL::numeric AS fishing_end_lat,

    NULL::text AS fish_species_id, NULL::text AS fish_species_en_name, NULL::numeric AS fish_total_length_mm, -- Fish (3)
    NULL::numeric AS tissue_weight_mg, NULL::text AS tissue_type, -- Tissue (2)
    NULL::numeric AS dna_volume_ul, NULL::numeric AS dna_concentration_ng_ul, NULL::date AS dna_extraction_date_dna, -- DNA (3)
    NULL::numeric AS rna_volume_ul, NULL::numeric AS rna_concentration_ng_ul, NULL::date AS rna_extraction_date_rna, -- RNA (3)
    NULL::text AS otolith_id, NULL::numeric AS otolith_age_reading_years, -- Otoliths (2)
    NULL::text AS extraction_id, NULL::date AS extraction_process_date, NULL::numeric AS extraction_process_yield_qubit_ng_ul, -- Extraction (3)
    NULL::text AS nanodrop_id, NULL::date AS nanodrop_measurement_date, NULL::numeric AS nanodrop_concentration, -- Nanodrop (3)
    NULL::text AS qubit_id, NULL::date AS qubit_measurement_date, NULL::numeric AS qubit_original_sample_conc, -- Qubit (3)
    NULL::text AS tapestation_id, NULL::date AS tapestation_measurement_date, -- Tapestation (2)
    NULL::text AS pcr_id, NULL::date AS pcr_date, NULL::text AS pcr_primer_id, -- PCR (3)
    NULL::text AS gelelectrophoresis_id, NULL::date AS gel_run_date, NULL::integer AS gel_band_size_bp, -- Gel Electrophoresis (3)
    NULL::text AS qpcr_id, NULL::date AS qpcr_date, NULL::numeric AS qpcr_ct_value, -- qPCR (3)
    NULL::text AS library_id, NULL::date AS library_prep_date, NULL::text AS library_name, -- Library (3)
    NULL::text AS sequencing_id, NULL::date AS sequencing_date, NULL::bigint AS total_reads, -- Sequencing (3)
    ar.run_id AS analysis_run_id, ar.run_date::date AS analysis_run_date, ap.pipeline_name, -- Analysis Runs (3)
    NULL::text AS edna_assignment_id, NULL::text AS edna_assigned_taxon_name, NULL::integer AS edna_read_count, -- eDNA Assignments (3)

    NULL::text AS sampler_full_name, NULL::text AS receiver_full_name
FROM
    "bioinformatics"."analysis_runs" ar
LEFT JOIN "reference"."status" stat ON ar.status_id = stat.status_id
LEFT JOIN "bioinformatics"."analysis_pipelines" ap ON ar.pipeline_id = ap.pipeline_id
LEFT JOIN "lab"."experiments" exp ON ar.experiment_id = exp.experiment_id AND ar.experiment_date = exp.experiment_date
LEFT JOIN "reference"."personal" exp_person ON exp.person_id = exp_person.person_id;

-- ======================================================================
-- 15. Partitioning Setup
-- ======================================================================
-- In section "15. Partitioning Setup"

DO $$
DECLARE
    current_year_int INTEGER := EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER;
    next_year_int INTEGER := current_year_int + 1;
BEGIN
    PERFORM "lab".create_sampling_partition_if_not_exists_manual(current_year_int);
    PERFORM "lab".create_sampling_partition_if_not_exists_manual(next_year_int);
END $$;

DO $$
DECLARE -- Re-declare variables here
    current_year_int INTEGER := EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER;
    next_year_int INTEGER := current_year_int + 1;
    current_year_start_date TEXT := (current_year_int || '-01-01');
    current_year_end_date TEXT := ((current_year_int + 1) || '-01-01');
    next_year_start_date TEXT := (next_year_int || '-01-01');
    next_year_end_date TEXT := ((next_year_int + 1) || '-01-01');
BEGIN
    EXECUTE 'CREATE TABLE IF NOT EXISTS "lab".parentalsamples_y' || current_year_int || ' PARTITION OF "lab"."root_samples"
             FOR VALUES FROM (''' || current_year_start_date || ''') TO (''' || current_year_end_date || ''');';

    EXECUTE 'CREATE TABLE IF NOT EXISTS "lab".parentalsamples_y' || next_year_int || ' PARTITION OF "lab"."root_samples"
             FOR VALUES FROM (''' || next_year_start_date || ''') TO (''' || next_year_end_date || ''');';
END $$;

DO $$
DECLARE -- Re-declare variables here
    current_year_int INTEGER := EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER;
    next_year_int INTEGER := current_year_int + 1;
BEGIN
    PERFORM "lab".create_experiments_partition_if_not_exists_manual(current_year_int);
    PERFORM "lab".create_experiments_partition_if_not_exists_manual(next_year_int);
END $$;

DO $$
DECLARE -- Re-declare variables here
    current_year_int INTEGER := EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER;
    next_year_int INTEGER := current_year_int + 1;
BEGIN
    PERFORM "lab".create_dissections_partition_if_not_exists_manual(current_year_int);
    PERFORM "lab".create_dissections_partition_if_not_exists_manual(next_year_int);
END $$;

DO $$
DECLARE -- Re-declare variables here
    current_year_int INTEGER := EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER;
    next_year_int INTEGER := current_year_int + 1;
BEGIN
    PERFORM "lab".create_extraction_partition_if_not_exists_manual(current_year_int);
    PERFORM "lab".create_extraction_partition_if_not_exists_manual(next_year_int);
END $$;

DO $$
DECLARE -- Re-declare variables here
    current_year_int INTEGER := EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER;
    next_year_int INTEGER := current_year_int + 1;
BEGIN
    PERFORM "lab".create_nanodrop_partition_if_not_exists_manual(current_year_int);
    PERFORM "lab".create_nanodrop_partition_if_not_exists_manual(next_year_int);
END $$;

DO $$
DECLARE -- Re-declare variables here
    current_year_int INTEGER := EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER;
    next_year_int INTEGER := current_year_int + 1;
BEGIN
    PERFORM "lab".create_qubit_partition_if_not_exists_manual(current_year_int);
    PERFORM "lab".create_qubit_partition_if_not_exists_manual(next_year_int);
END $$;

DO $$
DECLARE -- Re-declare variables here
    current_year_int INTEGER := EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER;
    next_year_int INTEGER := current_year_int + 1;
BEGIN
    PERFORM "lab".create_tapestation_partition_if_not_exists_manual(current_year_int);
    PERFORM "lab".create_tapestation_partition_if_not_exists_manual(next_year_int);
END $$;

DO $$
DECLARE -- Re-declare variables here
    current_year_int INTEGER := EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER;
    next_year_int INTEGER := current_year_int + 1;
BEGIN
    PERFORM "lab".create_pcr_partition_if_not_exists_manual(current_year_int);
    PERFORM "lab".create_pcr_partition_if_not_exists_manual(next_year_int);
END $$;

DO $$
DECLARE -- Re-declare variables here
    current_year_int INTEGER := EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER;
    next_year_int INTEGER := current_year_int + 1;
BEGIN
    PERFORM "lab".create_gelelectrophoresis_partition_if_not_exists_manual(current_year_int);
    PERFORM "lab".create_gelelectrophoresis_partition_if_not_exists_manual(next_year_int);
END $$;

DO $$
DECLARE -- Re-declare variables here
    current_year_int INTEGER := EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER;
    next_year_int INTEGER := current_year_int + 1;
BEGIN
    PERFORM "lab".create_qpcr_partition_if_not_exists_manual(current_year_int);
    PERFORM "lab".create_qpcr_partition_if_not_exists_manual(next_year_int);
END $$;

DO $$
DECLARE -- Re-declare variables here
    current_year_int INTEGER := EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER;
    next_year_int INTEGER := current_year_int + 1;
BEGIN
    PERFORM "lab".create_library_partition_if_not_exists_manual(current_year_int);
    PERFORM "lab".create_library_partition_if_not_exists_manual(next_year_int);
END $$;

DO $$
DECLARE -- Re-declare variables here
    current_year_int INTEGER := EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER;
    next_year_int INTEGER := current_year_int + 1;
BEGIN
    PERFORM "lab".create_sequencing_partition_if_not_exists_manual(current_year_int);
    PERFORM "lab".create_sequencing_partition_if_not_exists_manual(next_year_int);
END $$;

DO $$
DECLARE -- Re-declare variables here
    current_year_int INTEGER := EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER;
    next_year_int INTEGER := current_year_int + 1;
BEGIN
    PERFORM "lab".create_datasets_partition_if_not_exists_manual(current_year_int);
    PERFORM "lab".create_datasets_partition_if_not_exists_manual(next_year_int);
END $$;

DO $$
DECLARE -- Re-declare variables here
    current_year_int INTEGER := EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER;
    next_year_int INTEGER := current_year_int + 1;
BEGIN
    PERFORM "lab".create_dna_partition_if_not_exists_manual(current_year_int);
    PERFORM "lab".create_dna_partition_if_not_exists_manual(next_year_int);
END $$;

DO $$
DECLARE -- Re-declare variables here
    current_year_int INTEGER := EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER;
    next_year_int INTEGER := current_year_int + 1;
BEGIN
    PERFORM "lab".create_fish_partition_if_not_exists_manual(current_year_int);
    PERFORM "lab".create_fish_partition_if_not_exists_manual(next_year_int);
END $$;

DO $$
DECLARE -- Re-declare variables here
    current_year_int INTEGER := EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER;
    next_year_int INTEGER := current_year_int + 1;
BEGIN
    PERFORM "lab".create_fishing_partition_if_not_exists_manual(current_year_int);
    PERFORM "lab".create_fishing_partition_if_not_exists_manual(next_year_int);
END $$;


DO $$
DECLARE -- Re-declare variables here
    current_year_int INTEGER := EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER;
    next_year_int INTEGER := current_year_int + 1;
BEGIN
    PERFORM "lab".create_otoliths_partition_if_not_exists_manual(current_year_int);
    PERFORM "lab".create_otoliths_partition_if_not_exists_manual(next_year_int);
END $$;

DO $$
DECLARE -- Re-declare variables here
    current_year_int INTEGER := EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER;
    next_year_int INTEGER := current_year_int + 1;
BEGIN
    PERFORM "lab".create_rna_partition_if_not_exists_manual(current_year_int);
    PERFORM "lab".create_rna_partition_if_not_exists_manual(next_year_int);
END $$;

DO $$
DECLARE -- Re-declare variables here
    current_year_int INTEGER := EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER;
    next_year_int INTEGER := current_year_int + 1;
BEGIN
    PERFORM "lab".create_sediments_partition_if_not_exists_manual(current_year_int);
    PERFORM "lab".create_sediments_partition_if_not_exists_manual(next_year_int);
END $$;

DO $$
DECLARE -- Re-declare variables here
    current_year_int INTEGER := EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER;
    next_year_int INTEGER := current_year_int + 1;
BEGIN
    PERFORM "lab".create_tissue_partition_if_not_exists_manual(current_year_int);
    PERFORM "lab".create_tissue_partition_if_not_exists_manual(next_year_int);
END $$;

DO $$
DECLARE -- Re-declare variables here
    current_year_int INTEGER := EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER;
    next_year_int INTEGER := current_year_int + 1;
BEGIN
    PERFORM "lab".create_water_partition_if_not_exists_manual(current_year_int);
    PERFORM "lab".create_water_partition_if_not_exists_manual(next_year_int);
END $$;

DO $$
DECLARE -- Re-declare variables here
    current_year_int INTEGER := EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER;
    next_year_int INTEGER := current_year_int + 1;
BEGIN
    PERFORM "bioinformatics".create_analysis_runs_partition_if_not_exists_manual(current_year_int);
    PERFORM "bioinformatics".create_analysis_runs_partition_if_not_exists_manual(next_year_int);
END $$;


-- =============================

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



-- ======================================================================
-- 16. Row-Level Security (RLS) Policies
-- ======================================================================

ALTER TABLE "lims"."projects" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "lab"."root_samples" ENABLE ROW LEVEL SECURITY;

CREATE POLICY project_membership_policy ON "lims"."projects"
FOR SELECT
USING ("lims".is_member_of_project(project_id));

CREATE POLICY sample_project_membership_policy ON "lab"."root_samples"
FOR SELECT
USING ("lims".is_member_of_project(project_id));

-- ======================================================================
-- 17. Advanced JSONB and ltree Query Examples
-- ======================================================================

-- Querying JSONB data from the Dissections table
SELECT dissection_id, sample_id, stomach_contents_jsonb
FROM "lab"."dissections"
WHERE stomach_contents_jsonb ? 'item';

SELECT dissection_id, sample_id, stomach_contents_jsonb->>'item' AS item_name
FROM "lab"."dissections"
WHERE stomach_contents_jsonb @> '[{"item": "shrimp"}]'::jsonb;

SELECT dissection_id, sample_id, jsonb_array_elements(stomach_contents_jsonb) ->> 'quantity' AS quantity_of_item
FROM "lab"."dissections"
WHERE stomach_contents_jsonb @> '[{"item": "fish"}]'::jsonb;

-- Example of querying nested JSONB: assuming 'parameters_jsonb' in 'bioinformatics.analysis_runs'
-- SELECT run_id, parameters_jsonb->>'alignment_tool_version' AS tool_version
-- FROM "bioinformatics"."analysis_runs"
-- WHERE parameters_jsonb @> '{"pipeline_settings": {"min_quality": 30}}'::jsonb;

-- Update ltree paths (run after initial taxon data load)
SELECT "reference".update_taxon_ltree_paths();

-- Find all taxa belonging to the family 'Gadidae' (assuming 'Gadidae' is a taxon_id)
SELECT * FROM "reference"."taxon"
WHERE path <@ (SELECT path FROM "reference"."taxon" WHERE taxon_id = 'Gadidae');

-- Find the full lineage of 'Gadus morhua' (Atlantic Cod)
SELECT * FROM "reference"."taxon"
WHERE path @> (SELECT path FROM "reference"."taxon" WHERE taxon_id = 'Gadus morhua')
ORDER BY path;

-- Find all children directly under 'Animalia' (direct descendants)
SELECT taxon_id, de_name, en_name
FROM "reference"."taxon"
WHERE nlevel(path) = nlevel('Animalia'::ltree) + 1
  AND path <@ 'Animalia'::ltree;

-- Find common ancestor of two taxa
-- SELECT lca('Chordata'::ltree, 'Arthropoda'::ltree);

-- Additional JSONB Query Examples
-- Querying for keys in a JSONB object
SELECT run_id, parameters_jsonb
FROM "bioinformatics"."analysis_runs"
WHERE parameters_jsonb ? 'kmer_size';

-- Querying for existence of a key-value pair
SELECT run_id, parameters_jsonb
FROM "bioinformatics"."analysis_runs"
WHERE parameters_jsonb @> '{"quality_filter": true}'::jsonb;

-- Extracting a specific value from a nested JSONB object
SELECT run_id, parameters_jsonb->'processing'->>'trim_length' AS trim_length_setting
FROM "bioinformatics"."analysis_runs"
WHERE parameters_jsonb->'processing' ? 'trim_length';

-- Aggregating JSONB data
-- SELECT jsonb_object_agg(run_id, parameters_jsonb) FROM "bioinformatics"."analysis_runs";

-- Additional ltree Query Examples
-- Find all descendants of a specific path (e.g., all species under 'Chordata.Vertebrata')
-- SELECT taxon_id, en_name FROM "reference"."taxon" WHERE path ~ 'Chordata.Vertebrata.*'::ltree;

-- Find direct parents of a specific taxon
-- SELECT t2.taxon_id, t2.en_name
-- FROM "reference"."taxon" t1
-- JOIN "reference"."taxon" t2 ON t1.path @> t2.path AND nlevel(t1.path) = nlevel(t2.path) + 1
-- WHERE t1.taxon_id = 'Gadus morhua';

-- Find all ancestors of a specific taxon
-- SELECT t2.taxon_id, t2.en_name
-- FROM "reference"."taxon" t1
-- JOIN "reference"."taxon" t2 ON t1.path <@ t2.path
-- WHERE t1.taxon_id = 'Gadus morhua'
-- ORDER BY nlevel(t2.path) DESC;


-- ======================================================================
-- 18. Foreign Data Wrappers (FDW) Examples
-- ======================================================================

-- CREATE SERVER IF NOT EXISTS foreign_lims_server
-- FOREIGN DATA WRAPPER postgres_fdw
-- OPTIONS (host 'foreign_host', port '5432', dbname 'foreign_lims_db');

-- CREATE USER MAPPING IF NOT EXISTS FOR CURRENT_USER
-- SERVER foreign_lims_server
-- OPTIONS (user 'foreign_user', password 'foreign_password');

-- CREATE FOREIGN TABLE IF NOT EXISTS "lims"."foreign_projects" (
--      "project_id" text NOT NULL,
--      "title" text,
--      "start_date" date,
--      "end_date" date
-- )
-- SERVER foreign_lims_server
-- OPTIONS (schema_name 'lims', table_name 'projects');

-- SELECT * FROM "lims"."foreign_projects" WHERE "title" LIKE '%External%';

-- ======================================================================
-- 19. Aggregates Examples
-- ======================================================================

SELECT
    st.sample_type_id,
    COUNT(s.sample_id) AS total_samples
FROM
    "reference"."samples_type" st
LEFT JOIN
    "lab"."root_samples" s ON st.sample_type_id = s.sample_type_id
GROUP BY
    st.sample_type_id
ORDER BY
    total_samples DESC;

SELECT
    extraction_method,
    AVG(concentration_ng_ul) AS average_concentration_ng_ul
FROM
    "lab"."dna"
WHERE
    concentration_ng_ul IS NOT NULL
GROUP BY
    extraction_method
HAVING
    COUNT(concentration_ng_ul) > 1
ORDER BY
    average_concentration_ng_ul DESC;

SELECT
    EXTRACT(YEAR FROM reception_date) AS reception_year,
    COUNT(sample_id) AS samples_received
FROM
    "lab"."root_samples"
WHERE
    reception_date IS NOT NULL
GROUP BY
    reception_year
ORDER BY
    reception_year;

SELECT
    cs.species_en_name,
    MAX(f.total_length_mm) AS max_length_mm,
    MIN(f.total_length_mm) AS min_length_mm,
    AVG(f.weight_g) AS avg_weight_g
FROM
    "lab"."fish" f
JOIN
    "reference"."complete_species_taxon_view" cs ON f.species_id = cs.species_id
GROUP BY
    cs.species_en_name
ORDER BY
    max_length_mm DESC;

-- ======================================================================
-- 20. Add Deferred Foreign Key Constraints and Unique Constraints
-- ======================================================================

ALTER TABLE "reference"."taxon"
ADD CONSTRAINT "taxon_parent_fk" FOREIGN KEY ("taxon_parent")
REFERENCES "reference"."taxon"("taxon_id");

ALTER TABLE "reference"."species"
ADD CONSTRAINT "species_taxon_id_fk" FOREIGN KEY ("species_id")
REFERENCES "reference"."taxon"("taxon_id");

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

ALTER TABLE "lab"."storage"
ADD CONSTRAINT "storage_room_id_fk" FOREIGN KEY ("room_id")
REFERENCES "reference"."room"("room_id");

ALTER TABLE "lab"."storage"
ADD CONSTRAINT "storage_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id");

ALTER TABLE "lab"."experiments_projects"
ADD CONSTRAINT "experiments_projects_experiment_fk" FOREIGN KEY ("experiment_id", "experiment_date")
REFERENCES "lab"."experiments"("experiment_id", "experiment_date");

ALTER TABLE "lab"."experiments_projects"
ADD CONSTRAINT "experiments_projects_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id");

ALTER TABLE "lab"."protocol_runs"
ADD CONSTRAINT "protocol_runs_experiment_fk" FOREIGN KEY ("experiment_id", "experiment_date")
REFERENCES "lab"."experiments"("experiment_id", "experiment_date");

ALTER TABLE "lab"."protocol_runs"
ADD CONSTRAINT "protocol_runs_sop_id_fk" FOREIGN KEY ("sop_id")
REFERENCES "lims"."sop"("sop_id");

ALTER TABLE "lab"."protocol_runs"
ADD CONSTRAINT "protocol_runs_person_id_fk" FOREIGN KEY ("person_id")
REFERENCES "reference"."personal"("person_id");

ALTER TABLE "lab"."sampling"
ADD CONSTRAINT "sampling_experiment_fk" FOREIGN KEY ("experiment_id", "experiment_date")
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

ALTER TABLE "lab"."root_samples"
ADD CONSTRAINT "samples_master_sample_id_fk" FOREIGN KEY ("sample_id")
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."root_samples"
ADD CONSTRAINT "samples_parent_sample_id_fk" FOREIGN KEY ("parent_sample_id")
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."root_samples"
ADD CONSTRAINT "samples_sampling_fk" FOREIGN KEY ("sampling_id", "sampling_date")
REFERENCES "lab"."sampling"("sampling_id", "sampling_date");

ALTER TABLE "lab"."root_samples"
ADD CONSTRAINT "samples_storage_id_fk" FOREIGN KEY ("storage_id")
REFERENCES "lab"."storage"("storage_id");

ALTER TABLE "lab"."root_samples"
ADD CONSTRAINT "samples_sampler_person_id_fk" FOREIGN KEY ("sampler_person_id")
REFERENCES "reference"."personal"("person_id");

ALTER TABLE "lab"."root_samples"
ADD CONSTRAINT "samples_receiver_person_id_fk" FOREIGN KEY ("receiver_person_id")
REFERENCES "reference"."personal"("person_id");

ALTER TABLE "lab"."root_samples"
ADD CONSTRAINT "samples_sample_type_id_fk" FOREIGN KEY ("sample_type_id")
REFERENCES "reference"."samples_type"("sample_type_id");

ALTER TABLE "lab"."root_samples"
ADD CONSTRAINT "samples_status_id_fk" FOREIGN KEY ("status_id")
REFERENCES "reference"."status"("status_id");

ALTER TABLE "lab"."root_samples"
ADD CONSTRAINT "samples_workflow_id_fk" FOREIGN KEY ("workflow_id")
REFERENCES "lims"."workflows"("workflow_id");

ALTER TABLE "lab"."root_samples"
ADD CONSTRAINT "samples_step_id_fk" FOREIGN KEY ("step_id")
REFERENCES "lims"."workflow_steps"("step_id");

ALTER TABLE "lab"."root_samples"
ADD CONSTRAINT "samples_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id");

ALTER TABLE "lab"."root_samples"
ADD CONSTRAINT "samples_customer_id_fk" FOREIGN KEY ("customer_id")
REFERENCES "lims"."customers"("customer_id");

ALTER TABLE "lab"."storage_log"
ADD CONSTRAINT "storage_log_sample_fk" FOREIGN KEY ("sample_id", "sample_sampling_date")
REFERENCES "lab"."root_samples"("sample_id", "sampling_date");

ALTER TABLE "lab"."storage_log"
ADD CONSTRAINT "storage_log_storage_id_fk" FOREIGN KEY ("storage_id")
REFERENCES "lab"."storage"("storage_id");

ALTER TABLE "lab"."storage_log"
ADD CONSTRAINT "storage_log_person_id_fk" FOREIGN KEY ("person_id")
REFERENCES "reference"."personal"("person_id");


ALTER TABLE "lab"."fish"
ADD CONSTRAINT "fish_sample_id_fk" FOREIGN KEY ("sample_id")
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."fish"
ADD CONSTRAINT "fish_parent_sample_id_fk" FOREIGN KEY ("parent_sample_id")
REFERENCES "lab"."master_samples"("sample_id");

-- This FK now links to lab.sampling using sampling_id and sampling_date
ALTER TABLE "lab"."fish"
ADD CONSTRAINT "fish_sampling_fk" FOREIGN KEY ("sampling_id", "sampling_date")
REFERENCES "lab"."sampling"("sampling_id", "sampling_date");

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


ALTER TABLE "lab"."fish"
ADD CONSTRAINT "fish_experiment_fk" FOREIGN KEY ("experiment_id", "experiment_date")
REFERENCES "lab"."experiments"("experiment_id", "experiment_date");

ALTER TABLE "lab"."tissue"
ADD CONSTRAINT "tissue_sample_id_fk" FOREIGN KEY ("sample_id")
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."tissue"
ADD CONSTRAINT "tissue_parent_sample_id_fk" FOREIGN KEY ("parent_sample_id")
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."tissue"
ADD CONSTRAINT "tissue_experiment_fk" FOREIGN KEY ("experiment_id", "experiment_date")
REFERENCES "lab"."experiments"("experiment_id", "experiment_date");

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
ADD CONSTRAINT "dna_sample_id_fk" FOREIGN KEY ("sample_id")
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."dna"
ADD CONSTRAINT "dna_parent_sample_id_fk" FOREIGN KEY ("parent_sample_id")
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."dna"
ADD CONSTRAINT "dna_experiment_fk" FOREIGN KEY ("experiment_id", "experiment_date")
REFERENCES "lab"."experiments"("experiment_id", "experiment_date");

ALTER TABLE "lab"."dna"
ADD CONSTRAINT "dna_storage_id_fk" FOREIGN KEY ("storage_id")
REFERENCES "lab"."storage"("storage_id");

ALTER TABLE "lab"."dna"
ADD CONSTRAINT "dna_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id");

ALTER TABLE "lab"."rna"
ADD CONSTRAINT "rna_sample_id_fk" FOREIGN KEY ("sample_id")
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."rna"
ADD CONSTRAINT "rna_parent_sample_id_fk" FOREIGN KEY ("parent_sample_id")
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."rna"
ADD CONSTRAINT "rna_experiment_fk" FOREIGN KEY ("experiment_id", "experiment_date")
REFERENCES "lab"."experiments"("experiment_id", "experiment_date");

ALTER TABLE "lab"."rna"
ADD CONSTRAINT "rna_storage_id_fk" FOREIGN KEY ("storage_id")
REFERENCES "lab"."storage"("storage_id");

ALTER TABLE "lab"."rna"
ADD CONSTRAINT "rna_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id");

ALTER TABLE "lab"."sediments"
ADD CONSTRAINT "sediments_sample_id_fk" FOREIGN KEY ("sample_id")
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."sediments"
ADD CONSTRAINT "sediments_parent_sample_id_fk" FOREIGN KEY ("parent_sample_id")
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."sediments"
ADD CONSTRAINT "sediments_experiment_fk" FOREIGN KEY ("experiment_id", "experiment_date")
REFERENCES "lab"."experiments"("experiment_id", "experiment_date");

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
ADD CONSTRAINT "water_sample_id_fk" FOREIGN KEY ("sample_id")
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."water"
ADD CONSTRAINT "water_parent_sample_id_fk" FOREIGN KEY ("parent_sample_id")
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."water"
ADD CONSTRAINT "water_experiment_fk" FOREIGN KEY ("experiment_id", "experiment_date")
REFERENCES "lab"."experiments"("experiment_id", "experiment_date");

ALTER TABLE "lab"."water"
ADD CONSTRAINT "water_storage_id_fk" FOREIGN KEY ("storage_id")
REFERENCES "lab"."storage"("storage_id");

ALTER TABLE "lab"."water"
ADD CONSTRAINT "water_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id");

ALTER TABLE "lab"."experiments_samples"
ADD CONSTRAINT "experiments_samples_experiment_fk" FOREIGN KEY ("experiment_id", "experiment_date")
REFERENCES "lab"."experiments"("experiment_id", "experiment_date");

ALTER TABLE "lab"."experiments_samples"
ADD CONSTRAINT "experiments_samples_sample_id_fk" FOREIGN KEY ("sample_id")
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."dissections"
ADD CONSTRAINT "dissections_sample_id_fk" FOREIGN KEY ("sample_id")
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."dissections"
ADD CONSTRAINT "dissections_person_id_fk" FOREIGN KEY ("person_id")
REFERENCES "reference"."personal"("person_id");

ALTER TABLE "lab"."dissections"
ADD CONSTRAINT "dissections_status_id_fk" FOREIGN KEY ("status_id")
REFERENCES "reference"."status"("status_id");

ALTER TABLE "lab"."extraction"
ADD CONSTRAINT "extraction_experiment_fk" FOREIGN KEY ("experiment_id", "experiment_date")
REFERENCES "lab"."experiments"("experiment_id", "experiment_date");

ALTER TABLE "lab"."extraction"
ADD CONSTRAINT "extraction_sample_id_fk" FOREIGN KEY ("sample_id")
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
ADD CONSTRAINT "nanodrop_experiment_fk" FOREIGN KEY ("experiment_id", "experiment_date")
REFERENCES "lab"."experiments"("experiment_id", "experiment_date");

ALTER TABLE "lab"."nanodrop"
ADD CONSTRAINT "nanodrop_sample_id_fk" FOREIGN KEY ("sample_id")
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
ADD CONSTRAINT "qubit_sample_id_fk" FOREIGN KEY ("sample_id")
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."qubit"
ADD CONSTRAINT "qubit_experiment_fk" FOREIGN KEY ("experiment_id", "experiment_date")
REFERENCES "lab"."experiments"("experiment_id", "experiment_date");

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
ADD CONSTRAINT "tapestation_experiment_fk" FOREIGN KEY ("experiment_id", "experiment_date")
REFERENCES "lab"."experiments"("experiment_id", "experiment_date");

ALTER TABLE "lab"."tapestation"
ADD CONSTRAINT "tapestation_person_id_fk" FOREIGN KEY ("person_id")
REFERENCES "reference"."personal"("person_id");

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

ALTER TABLE "lab"."pcr"
ADD CONSTRAINT "pcr_experiment_fk" FOREIGN KEY ("experiment_id", "experiment_date")
REFERENCES "lab"."experiments"("experiment_id", "experiment_date");

ALTER TABLE "lab"."pcr"
ADD CONSTRAINT "pcr_sample_id_fk" FOREIGN KEY ("sample_id")
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
ADD CONSTRAINT "gelelectrophoresis_experiment_fk" FOREIGN KEY ("experiment_id", "experiment_date")
REFERENCES "lab"."experiments"("experiment_id", "experiment_date");

ALTER TABLE "lab"."gelelectrophoresis"
ADD CONSTRAINT "gelelectrophoresis_sample_id_fk" FOREIGN KEY ("sample_id")
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
ADD CONSTRAINT "qpcr_experiment_fk" FOREIGN KEY ("experiment_id", "experiment_date")
REFERENCES "lab"."experiments"("experiment_id", "experiment_date");

ALTER TABLE "lab"."qpcr"
ADD CONSTRAINT "qpcr_sample_id_fk" FOREIGN KEY ("sample_id")
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
ADD CONSTRAINT "library_experiment_fk" FOREIGN KEY ("experiment_id", "experiment_date")
REFERENCES "lab"."experiments"("experiment_id", "experiment_date");

ALTER TABLE "lab"."library"
ADD CONSTRAINT "library_sample_id_fk" FOREIGN KEY ("sample_id")
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
ADD CONSTRAINT "sequencing_experiment_fk" FOREIGN KEY ("experiment_id", "experiment_date")
REFERENCES "lab"."experiments"("experiment_id", "experiment_date");

ALTER TABLE "lab"."sequencing"
ADD CONSTRAINT "sequencing_library_fk" FOREIGN KEY ("library_id", "prep_date")
REFERENCES "lab"."library"("library_id", "prep_date");

ALTER TABLE "lab"."sequencing"
ADD CONSTRAINT "sequencing_sample_id_fk" FOREIGN KEY ("sample_id")
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

ALTER TABLE "bioinformatics"."analysis_runs"
ADD CONSTRAINT "analysis_runs_pipeline_id_fk" FOREIGN KEY ("pipeline_id")
REFERENCES "bioinformatics"."analysis_pipelines"("pipeline_id");

ALTER TABLE "bioinformatics"."analysis_runs"
ADD CONSTRAINT "analysis_runs_sequencing_fk" FOREIGN KEY ("sequencing_id", "sequencing_date")
REFERENCES "lab"."sequencing"("sequencing_id", "sequencing_date");

ALTER TABLE "bioinformatics"."analysis_runs"
ADD CONSTRAINT "analysis_runs_person_id_fk" FOREIGN KEY ("person_id")
REFERENCES "reference"."personal"("person_id");

ALTER TABLE "bioinformatics"."analysis_runs"
ADD CONSTRAINT "analysis_runs_reference_db_id_fk" FOREIGN KEY ("reference_db_id")
REFERENCES "bioinformatics"."reference_databases"("db_id");

ALTER TABLE "bioinformatics"."edna_assignments"
ADD CONSTRAINT "edna_assignments_run_fk" FOREIGN KEY ("run_id", "run_date")
REFERENCES "bioinformatics"."analysis_runs"("run_id", "run_date");

ALTER TABLE "bioinformatics"."edna_assignments"
ADD CONSTRAINT "edna_assignments_sample_id_fk" FOREIGN KEY ("sample_id")
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "bioinformatics"."edna_assignments"
ADD CONSTRAINT "edna_assignments_taxon_id_fk" FOREIGN KEY ("taxon_id")
REFERENCES "reference"."taxon"("taxon_id");

ALTER TABLE "projects"."ProjectWanderfische_FishingData"
ADD CONSTRAINT "fk_fishingdata_agency" FOREIGN KEY ("agency_id")
REFERENCES "lims"."external_contacts"("contact_id") ON UPDATE CASCADE ON DELETE RESTRICT;

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
REFERENCES "reference"."personal"("person_id") ON UPDATE CASCADE ON DELETE SET NULL;

ALTER TABLE "projects"."ProjectWanderfische_FishingData"
ADD CONSTRAINT "fk_fishingdata_last_modified_by" FOREIGN KEY ("last_modified_by")
REFERENCES "reference"."personal"("person_id") ON UPDATE CASCADE ON DELETE SET NULL;


ALTER TABLE "projects"."ProjectWanderfische_FishCatch"
ADD CONSTRAINT "fk_fishcatch_fishingdata" FOREIGN KEY ("fishing_record_id", "fishing_record_date")
REFERENCES "projects"."ProjectWanderfische_FishingData"("fishing_record_id", "record_date") ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE "projects"."ProjectWanderfische_FishCatch"
ADD CONSTRAINT "fk_fishcatch_taxon" FOREIGN KEY ("taxon_id")
REFERENCES "reference"."taxon"("taxon_id") ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE "projects"."ProjectWanderfische_FishCatch"
ADD CONSTRAINT "fk_fishcatch_created_by" FOREIGN KEY ("created_by")
REFERENCES "reference"."personal"("person_id") ON UPDATE CASCADE ON DELETE SET NULL;

ALTER TABLE "projects"."ProjectWanderfische_FishCatch"
ADD CONSTRAINT "fk_fishcatch_last_modified_by" FOREIGN KEY ("last_modified_by")
REFERENCES "reference"."personal"("person_id") ON UPDATE CASCADE ON DELETE SET NULL;


ALTER TABLE "projects"."ProjectWanderfische_Mail"
ADD CONSTRAINT "fk_mail_fishingdata" FOREIGN KEY ("fishing_record_id", "fishing_record_date")
REFERENCES "projects"."ProjectWanderfische_FishingData"("fishing_record_id", "record_date") ON UPDATE CASCADE ON DELETE SET NULL;

ALTER TABLE "projects"."ProjectWanderfische_Mail"
ADD CONSTRAINT "fk_mail_sender_person" FOREIGN KEY ("sender_person_id")
REFERENCES "reference"."personal"("person_id") ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE "projects"."ProjectWanderfische_Mail"
ADD CONSTRAINT "fk_mail_recipient_contact" FOREIGN KEY ("recipient_contact_id")
REFERENCES "lims"."external_contacts"("contact_id") ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE "projects"."ProjectWanderfische_Mail"
ADD CONSTRAINT "fk_mail_created_by" FOREIGN KEY ("created_by")
REFERENCES "reference"."personal"("person_id") ON UPDATE CASCADE ON DELETE SET NULL;

ALTER TABLE "projects"."ProjectWanderfische_Mail"
ADD CONSTRAINT "fk_mail_last_modified_by" FOREIGN KEY ("last_modified_by")
REFERENCES "reference"."personal"("person_id") ON UPDATE CASCADE ON DELETE SET NULL;


ALTER TABLE "projects"."ProjectWanderfische_Conversation"
ADD CONSTRAINT "fk_conversation_fishingdata" FOREIGN KEY ("fishing_record_id", "fishing_record_date")
REFERENCES "projects"."ProjectWanderfische_FishingData"("fishing_record_id", "record_date") ON UPDATE CASCADE ON DELETE SET NULL;

ALTER TABLE "projects"."ProjectWanderfische_Conversation"
ADD CONSTRAINT "fk_conversation_created_by" FOREIGN KEY ("created_by")
REFERENCES "reference"."personal"("person_id") ON UPDATE CASCADE ON DELETE SET NULL;

ALTER TABLE "projects"."ProjectWanderfische_Conversation"
ADD CONSTRAINT "fk_conversation_last_modified_by" FOREIGN KEY ("last_modified_by")
REFERENCES "reference"."personal"("person_id") ON UPDATE CASCADE ON DELETE SET NULL;


ALTER TABLE "projects"."ProjectWanderfische_ChatMessage"
ADD CONSTRAINT "fk_chatmessage_conversation" FOREIGN KEY ("conversation_id")
REFERENCES "projects"."ProjectWanderfische_Conversation"("conversation_id") ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE "projects"."ProjectWanderfische_ChatMessage"
ADD CONSTRAINT "fk_chatmessage_sender_person" FOREIGN KEY ("sender_person_id")
REFERENCES "reference"."personal"("person_id") ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE "projects"."ProjectWanderfische_ChatMessage"
ADD CONSTRAINT "fk_chatmessage_sender_contact" FOREIGN KEY ("sender_contact_id")
REFERENCES "lims"."external_contacts"("contact_id") ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE "projects"."ProjectWanderfische_ChatMessage"
ADD CONSTRAINT "fk_chatmessage_created_by" FOREIGN KEY ("created_by")
REFERENCES "reference"."personal"("person_id") ON UPDATE CASCADE ON DELETE SET NULL;

ALTER TABLE "projects"."ProjectWanderfische_ChatMessage"
ADD CONSTRAINT "fk_chatmessage_last_modified_by" FOREIGN KEY ("last_modified_by")
REFERENCES "reference"."personal"("person_id") ON UPDATE CASCADE ON DELETE SET NULL;







































-- ======================================================================
-- 9. Example Data Insertion (Optional)
-- Updated to include new fields and composite primary keys
-- ======================================================================


-- ======================================================================
-- ======================================================================
-- 14. Initial Data Population
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
('Sediments', 'S', 'Sedi ment sample'),
('Tissue', 'T', 'Tissue sample'),
('Fish', 'F', 'Fish sample'),
('Sequencing', 'Q', 'Sequencing run output'),
('Dataset', 'Z', 'Processed dataset'),
('Publication', 'PUB', 'Research Publication')
ON CONFLICT ("sample_type_id") DO NOTHING;


INSERT INTO "reference"."units" ("unit_id", "unit_name", "unit_abbreviation", "unit_type", "conversion_factor_to_base") VALUES
('mm', 'millimeter', 'mm', 'length', 0.001),
('g', 'gram', 'g', 'mass', 0.001),
('ul', 'microliter', 'µl', 'volume', 1e-6),
('ng_ul', 'nanogram per microliter', 'ng/µl', 'concentration', 1e-9),
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

INSERT INTO "reference"."personal" ("person_id", "full_name", "password_hash","status_id") VALUES
('system_user', 'System Automation', 'no_password_needed_for_system', 'Active')
ON CONFLICT ("person_id") DO NOTHING;

-- Insert statement for "reference"."Status"
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
('Unknown Step', 'An unknown step has occurred in the workflow'),
('Active', 'Project or item is currently active/in progress'),
('Planned', 'Project or activity is planned but not yet started'),
('Completed', 'Project or activity has been finished successfully'),
('On Hold', 'Project or activity is temporarily paused'),
('Cancelled', 'Project or activity has been cancelled'),
('Rejected', 'Sample or item failed quality control or is unusable'),
('In Transit', 'Sample or item is currently in transport'),
('In Stock', 'Reagent or item is available in inventory'),
('Expired', 'Reagent or item is past its expiration date')
ON CONFLICT ("status_id") DO NOTHING;

-- Insert statement for "reference"."category"
-- You'll need to define what categories you want to include.
-- Here are some common examples for a LIMS, you can adjust as needed.
INSERT INTO "reference"."category" ("category_id", "notes") VALUES
('Reagent', 'Chemicals and solutions used in experiments.'),
('Consumable', 'Disposable lab supplies like tips, tubes, and plates.'),
('Equipment', 'Laboratory instruments and machinery.'),
('Service', 'External services like sequencing or custom synthesis.'),
('Software', 'Licenses or subscriptions for bioinformatics or lab management tools.'),
('General', 'Miscellaneous items not fitting other categories.')
ON CONFLICT ("category_id") DO NOTHING;

-- Insert statement for "reference"."samples_type"
INSERT INTO "reference"."samples_type" ("sample_type_id", "sample_type_abrv", "notes") VALUES
('DNA', 'D', 'Deoxyribonucleic Acid sample'),
('RNA', 'R', 'Ribonucleic Acid sample'),
('Library', 'L', 'Sequencing Library sample'),
('Water', 'W', 'Water sample'),
('Sediments', 'S', 'Sedi ment sample'),
('Tissue', 'T', 'Tissue sample'),
('Fish', 'F', 'Fish sample'),
('Sequencing', 'Q', 'Sequencing run output'),
('Dataset', 'Z', 'Processed dataset'),
('Publication', 'PUB', 'Research Publication')
ON CONFLICT ("sample_type_id") DO NOTHING;

-- insert most genes
INSERT INTO "reference"."gene" ("gene_id", "notes") VALUES
('COI', 'Cytochrome c oxidase subunit I - Universal barcode marker for species identification'),
('CytB', 'Cytochrome b - Mitochondrial gene for phylogenetic analysis and population studies'),
('12S_rRNA', '12S ribosomal RNA - Mitochondrial gene for phylogenetic reconstruction'),
('16S_rRNA', '16S ribosomal RNA - Mitochondrial gene for phylogenetic reconstruction'),
('ACTB', 'Beta-actin - Housekeeping gene, commonly used as a control for gene expression studies'),
('GAPDH', 'Glyceraldehyde-3-phosphate dehydrogenase - Housekeeping gene, internal control for gene expression'),
('MHC_I', 'Major Histocompatibility Complex Class I - Immune gene, studied for disease resistance and diversity'),
('MHC_II', 'Major Histocompatibility Complex Class II - Immune gene, studied for disease resistance and diversity'),
('GH', 'Growth Hormone - Involved in growth and development, relevant for aquaculture and livestock'),
('PRL', 'Prolactin - Involved in reproduction, growth, and osmoregulation in fish'),
('RAG1', 'Recombination Activating Gene 1 - Nuclear gene for vertebrate phylogenetics'),
('S7', 'Ribosomal protein S7 - Nuclear gene for phylogenetic analysis'),
('Opsin_Rhodopsin', 'Opsin (Rhodopsin) - Genes involved in vision, studied for adaptation to light environments'),
('TLR3', 'Toll-like Receptor 3 - Immune receptor gene, important for innate immunity in fish'),
('HSP70', 'Heat Shock Protein 70 - Stress response gene, studied for environmental adaptation')
ON CONFLICT ("gene_id") DO NOTHING;





-- ======================================================================
-- 14. Initial Data Population (Continued with "Test_db" Data)
-- ======================================================================

-- Reference Schema Tables - Basic Entries for FKs
INSERT INTO "reference"."personal" ("person_id", "full_name", "password_hash","status_id") VALUES
('Test_db', 'Test_db Full Name', 'Test_db_hashed_password','Active')
ON CONFLICT ("person_id") DO NOTHING;

INSERT INTO "reference"."status" ("status_id", "notes") VALUES
('Test_db', 'Test_db Status Notes')
ON CONFLICT ("status_id") DO NOTHING;

INSERT INTO "reference"."room" ("room_id", "etage", "address") VALUES
('Test_db', 'Test_db', 'Test_db')
ON CONFLICT ("room_id") DO NOTHING;

INSERT INTO "reference"."vessel" ("vessel_id", "vessel_name") VALUES
('Test_db', 'Test_db')
ON CONFLICT ("vessel_id") DO NOTHING;

INSERT INTO "reference"."region" ("region_id", "region_abrv", "country") VALUES
('Test_db', 'TestDB', 'Test_db')
ON CONFLICT ("region_id") DO NOTHING;

INSERT INTO "reference"."ecosystem" ("ecosystem_id", "ecosystem_abrv", "country") VALUES
('Test_db', 'TestDB', 'Test_db')
ON CONFLICT ("ecosystem_id") DO NOTHING;

INSERT INTO "reference"."category" ("category_id") VALUES
('Test_db')
ON CONFLICT ("category_id") DO NOTHING;

INSERT INTO "reference"."samples_type" ("sample_type_id", "sample_type_abrv", "notes") VALUES
('Test_db', 'TestDB', 'Test_db')
ON CONFLICT ("sample_type_id") DO NOTHING;

INSERT INTO "reference"."gene" ("gene_id") VALUES
('Test_db')
ON CONFLICT ("gene_id") DO NOTHING;

INSERT INTO "reference"."taxon" ("taxon_id", "de_name", "en_name", "rank") VALUES
('Test_db', 'Test_db', 'Test_db', 'species')
ON CONFLICT ("taxon_id") DO NOTHING;
-- Populate ltree path after inserting taxon data
SELECT "reference".update_taxon_ltree_paths();

INSERT INTO "reference"."species" ("species_id", "de_name", "en_name", "max_length_mm", "max_age_years") VALUES
('Test_db', 'Test_db', 'Test_db', 1, 1)
ON CONFLICT ("species_id") DO NOTHING;

INSERT INTO "reference"."units" ("unit_id", "unit_name", "unit_abbreviation", "unit_type", "conversion_factor_to_base") VALUES
('Test_db', 'Test_db', 'TestDB', 'Test_db', 1)
ON CONFLICT ("unit_id") DO NOTHING;


-- Lims Schema Tables
INSERT INTO "lims"."external_contacts" ("contact_id", "full_name") VALUES
('Test_db', 'Test_db')
ON CONFLICT ("contact_id") DO NOTHING;

INSERT INTO "lims"."customers" ("customer_id", "customer_name", "customer_abrv") OVERRIDING SYSTEM VALUE VALUES
(1, 'Test_db', 'TestDB')
ON CONFLICT ("customer_id") DO NOTHING;

INSERT INTO "lims"."projects" ("project_id", "title", "status_id", "pi_person_id", "customer_id", "start_date") VALUES
('Test_db', 'Test_db', 'Test_db', 'Test_db', 1, '2025-07-01')
ON CONFLICT ("project_id") DO NOTHING;

INSERT INTO "lims"."project_persons" ("project_id", "person_id", "role") VALUES
('Test_db', 'Test_db', 'Test_db')
ON CONFLICT ("project_id", "person_id") DO NOTHING;

INSERT INTO "lab"."storage" ("storage_id", "room_id", "freezer", "etage", "temperature_c", "box", "box_size_x", "box_size_y", "storage_position_format", "project_id") VALUES
('Test_db', 'Test_db', 'Test_db', 'Test_db', 1, 'Test_db', 1, 1, 'Test_db', 'Test_db')
ON CONFLICT ("storage_id") DO NOTHING;

INSERT INTO "lims"."cruises" ("cruise_id", "project_id", "vessel_id", "status_id", "region_id", "ecosystem_id", "capitaine_contact_id", "chief_scientist_person_id", "start_date") VALUES
('Test_db', 'Test_db', 'Test_db', 'Test_db', 'Test_db', 'Test_db', 'Test_db', 'Test_db', '2025-07-01')
ON CONFLICT ("cruise_id") DO NOTHING;

INSERT INTO "lims"."workflows" ("workflow_id", "workflow_name") VALUES
('Test_db', 'Test_db')
ON CONFLICT ("workflow_id") DO NOTHING;

INSERT INTO "lims"."permits" ("permit_id", "permit_number", "issuing_authority", "valid_from") VALUES
('Test_db', 'Test_db', 'Test_db', '2025-07-01')
ON CONFLICT ("permit_id") DO NOTHING;

INSERT INTO "lims"."primers" ("primer_id", "target_gene_id", "primer_sequence_fwd") VALUES
('Test_db', 'Test_db', 'Test_db')
ON CONFLICT ("primer_id") DO NOTHING;

INSERT INTO "lims"."sop" ("sop_id", "title", "sop_id_origin", "version", "author_person_id", "date_realise") VALUES
('Test_db', 'Test_db', 'Test_db_origin', '1.0', 'Test_db', '2025-07-01')
ON CONFLICT ("sop_id") DO NOTHING;

INSERT INTO "lims"."workflow_steps" ("step_id", "workflow_id", "step_number", "step_name", "sop_id", "workflow_status_id") VALUES
('Test_db', 'Test_db', 1, 'Test_db', 'Test_db_origin_v10', 'Test_db')
ON CONFLICT ("step_id") DO NOTHING;

INSERT INTO "lims"."equipment" ("equipment_id", "equipment_name", "room_id") VALUES
('Test_db', 'Test_db', 'Test_db')
ON CONFLICT ("equipment_id") DO NOTHING;

INSERT INTO "lims"."suppliers" ("supplier_id", "supplier_name") VALUES
('Test_db', 'Test_db')
ON CONFLICT ("supplier_id") DO NOTHING;

INSERT INTO "lims"."inventory_items" ("item_id", "item_name", "category_id", "unit_id") VALUES
('Test_db', 'Test_db', 'Test_db', 'Test_db')
ON CONFLICT ("item_id") DO NOTHING;

INSERT INTO "lims"."orders" ("fi_order_nr", "item_id", "category_id", "order_date", "price", "quantity", "project_id", "supplier_id", "status_id") VALUES
('Test_db', 'Test_db', 'Test_db', '2025-07-01', 1, 1, 'Test_db', 'Test_db', 'Test_db')
ON CONFLICT ("fi_order_nr") DO NOTHING;

INSERT INTO "lims"."reagents" ("reagent_id", "reagent_complete_name", "category_id", "lot", "storage_id", "storage_position", "status_id", "reception_date", "expire_date", "order_id", "project_id", "quantity_available", "quantity_unit_id") VALUES
('Test_db', 'Test_db', 'Test_db', 'Test_db', 'Test_db', 1, 'Test_db', '2025-07-01', '2025-07-01', 'Test_db', 'Test_db', 1, 'Test_db')
ON CONFLICT ("reagent_id") DO NOTHING;

INSERT INTO "lims"."publication_type" ("publication_type_id") VALUES
('Test_db')
ON CONFLICT ("publication_type_id") DO NOTHING;

INSERT INTO "lims"."publications" ("publication_id", "publication_type_id", "project_id", "title", "journal", "volume", "issue", "pages", "doi", "date_publication", "date_submission", "first_author_person_id", "corresponding_author_person_id") VALUES
('Test_db', 'Test_db', 'Test_db', 'Test_db', 'Test_db', 'Test_db', 'Test_db', 'Test_db', 'Test_db', '2025-07-01', '2025-07-01', 'Test_db', 'Test_db')
ON CONFLICT ("publication_id") DO NOTHING;


-- Lab Schema Tables
INSERT INTO "lab"."experiments" ("experiment_id", "experiment_title", "aim", "method", "sop_id", "experiment_date", "person_id", "lab_book", "status_id") VALUES
('Test_db', 'Test_db', 'Test_db', 'Test_db', 'Test_db_origin_v10', '2025-07-01', 'Test_db', 'Test_db', 'Test_db')
ON CONFLICT ("experiment_id", "experiment_date") DO NOTHING;

INSERT INTO "lab"."experiments_projects" ("experiment_project_id", "experiment_id", "experiment_date", "project_id", "link_date") OVERRIDING SYSTEM VALUE VALUES
(1, 'Test_db', '2025-07-01', 'Test_db', '2025-07-01')
ON CONFLICT ("experiment_project_id") DO NOTHING;

INSERT INTO "lab"."protocol_runs" ("protocol_run_id", "experiment_id", "experiment_date", "sop_id", "run_date", "person_id") VALUES
('Test_db', 'Test_db', '2025-07-01', 'Test_db_origin_v10', '2025-07-01', 'Test_db')
ON CONFLICT ("protocol_run_id") DO NOTHING;

INSERT INTO "lab"."sampling" (
    "sampling_id", "experiment_id", "experiment_date", "project_id", "cruise_id", "region_id",
    "ecosystem_id", "vessel_id", "customer_id", "sampling_date", "geom", "location_name",
    "depth_m", "start_at", "end_at", "temperature_atmospheric_c", "weather", "wind_speed"
) VALUES (
    'Test_db', 'Test_db', '2025-07-01', 'Test_db', 'Test_db', 'Test_db',
    'Test_db', 'Test_db', 1, '2025-07-01', ST_SetSRID(ST_MakePoint(1, 1), 4326), 'Test_db',
    1, '00:00:01', '00:00:01', 1, 'Test_db', 1 -- Added the two missing 'Test_db' values here
)
ON CONFLICT ("sampling_id", "sampling_date") DO NOTHING;

-- Master samples is populated by the generate_sample_id trigger.
-- Inserting into `lab.samples` will populate `master_samples`.
-- INSERT INTO "lab"."master_samples" ("sample_id") VALUES ('Test_db') ON CONFLICT ("sample_id") DO NOTHING;

INSERT INTO "lab"."root_samples" ("external_name", "sampling_id", "sampling_date", "storage_id", "storage_position", "sampler_person_id", "receiver_person_id", "reception_date", "transport", "conservation_buffer", "sample_type_id", "status_id", "project_id", "customer_id") VALUES
('Test_db', '25TestDBTestDB0001', '2025-07-01', 'Test_db', 'Test_db', 'Test_db', 'Test_db', '2025-07-01', 'Test_db', 'Test_db', 'Test_db', 'Test_db', 'Test_db', 1)
ON CONFLICT ("sample_id", "sampling_date") DO NOTHING;

INSERT INTO "lab"."fishing" ("fishing_id", "sampling_id", "sampling_date", "taxon_id", "catch_kg", "catch_fish", "customer_id") VALUES
('Test_db_fish', '25TestDBTestDB0001', '2025-07-01', 'Test_db', 1, 1, 1)
ON CONFLICT ("fishing_id", "sampling_date") DO NOTHING;

INSERT INTO "lab"."storage_log" ("log_id", "sample_id", "sample_sampling_date", "storage_id", "person_id", "status") OVERRIDING SYSTEM VALUE VALUES
(1, 'Test_db_sample', '2025-07-01', 'Test_db', 'Test_db', 'Test_db')
ON CONFLICT ("log_id") DO NOTHING;

INSERT INTO "lab"."fish" ("parent_sample_id", "sampling_id", "sampling_date", "species_id", "total_length_mm", "fork_length_mm", "standard_length_mm", "weight_g", "sex", "maturity_stage", "stomach_contents", "disease_info", "tag_id", "storage_id", "storage_position", "project_id", "customer_id") VALUES
('TestDB25TestDBTestDB0001', '25TestDBTestDB0001', '2025-07-01', 'Test_db', 1, 1, 1, 1, 'Undetermined', 'Test_db', 'Test_db', 'Test_db', 'Test_db', 'Test_db', 'Test_db', 'Test_db', 1)
ON CONFLICT ("sample_id", "sampling_date") DO NOTHING;

INSERT INTO "lab"."tissue" ("parent_sample_id", "experiment_id", "experiment_date", "weight_mg", "tissue_type", "preservation_method", "storage_id", "storage_position", "project_id") VALUES
('TestDB25TestDBTestDB0001', 'Test_db', '2025-07-01', 1, 'Test_db', 'Test_db', 'Test_db', 'Test_db', 'Test_db')
ON CONFLICT ("sample_id", "experiment_date") DO NOTHING;

INSERT INTO "lab"."otoliths" ("sample_id","experiment_id", "experiment_date", "reader_person_id", "side", "age_reading_years", "confidence", "project_id") VALUES
('TestDB25TestDBTestDB0001', 'Test_db', '2025-07-01', 'Test_db', 'Test_db', 1, 1, 'Test_db')
ON CONFLICT ("otolith_id", "experiment_date") DO NOTHING;


INSERT INTO "lab"."dna" ("parent_sample_id", "experiment_id", "experiment_date", "volume_ul", "concentration_ng_ul", "a260_280", "a260_230", "extraction_method", "preservation_method", "extraction_date", "extraction_number", "storage_id", "storage_position", "project_id") VALUES
('TestDB25TestDBTestDB0001', 'Test_db', '2025-07-01', 1, 1, 1, 1, 'Test_db', 'Test_db', '2025-07-01', 1, 'Test_db', 'Test_db', 'Test_db')
ON CONFLICT ("sample_id", "experiment_date") DO NOTHING;

INSERT INTO "lab"."rna" ("parent_sample_id", "experiment_id", "experiment_date", "volume_ul", "concentration_ng_ul", "a260_280", "a260_230", "extraction_method", "preservation_method", "extraction_date", "extraction_number", "storage_id", "storage_position", "project_id") VALUES
('TestDB25TestDBTestDB0001', 'Test_db', '2025-07-01', 1, 1, 1, 1, 'Test_db', 'Test_db', '2025-07-01', 1, 'Test_db', 'Test_db', 'Test_db')
ON CONFLICT ("sample_id", "experiment_date") DO NOTHING;

INSERT INTO "lab"."sediments" ("sample_id", "experiment_id", "experiment_date", "project_id", "volume", "volume_unit_id", "depth_m", "sampling_method", "conservation_buffer", "storage_id", "storage_position", "external_name") VALUES
('TestDB25TestDBTestDB0001', 'Test_db', '2025-07-01', 'Test_db', 1, 'Test_db', 1, 'Test_db', 'Test_db', 'Test_db', 'Test_db', 'Test_db')
ON CONFLICT ("sample_id", "experiment_date") DO NOTHING;

INSERT INTO "lab"."water" ("sample_id", "parent_sample_id", "experiment_id", "experiment_date", "volume_l", "filter", "filter_pore_size_um", "depth_m", "sampling_method", "conservation_buffer", "storage_id", "storage_position", "project_id") VALUES
('TestDB25TestDBTestDB0001', 'TestDB25TestDBTestDB0001', 'Test_db', '2025-07-01', 1, 'Test_db', 1, 1, 'Test_db', 'Test_db', 'Test_db', 'Test_db', 'Test_db')
ON CONFLICT ("sample_id", "experiment_date") DO NOTHING;

INSERT INTO "lab"."experiments_samples" ("experiment_id", "experiment_date", "sample_id") VALUES
('Test_db', '2025-07-01', 'Test_db_sample')
ON CONFLICT ("experiment_id", "sample_id", "experiment_date") DO NOTHING;

INSERT INTO "lab"."dissections" ("dissection_id", "sample_id", "person_id", "dissection_date", "stomach_contents_jsonb", "gonad_weight_g", "liver_weight_g", "status_id") VALUES
('Test_db_dissection', 'TestDB25TestDBTestDB0001', 'Test_db', '2025-07-01', '{}'::jsonb, 1, 1, 'Test_db')
ON CONFLICT ("dissection_id", "dissection_date") DO NOTHING;

INSERT INTO "lab"."extraction" ("extraction_id", "experiment_id", "experiment_date", "sample_id", "sample_type_id", "extracted_dna_sample_id", "extracted_rna_sample_id", "extraction_date", "person_id", "kit", "elution_volume_ul", "yield_qubit_ng_ul", "yield_nanodrop_ng_ul", "a260_280", "a260_230", "extraction_blank_id", "status_id", "storage_id", "storage_position", "project_id") VALUES
('Test_db_extraction', 'Test_db', '2025-07-01', 'TestDB25TestDBTestDB0001',  'Test_db', NULL, NULL, '2025-07-01', 'Test_db', 'Test_db', 1, 1, 1, 1, 1, 'Test_db', 'Test_db', 'Test_db', 'Test_db', 'Test_db')
ON CONFLICT ("extraction_id", "extraction_date") DO NOTHING;

INSERT INTO "lab"."nanodrop" ("nanodrop_id", "experiment_id", "experiment_date", "sample_id", "nanodrop_concentration", "concentration_unit_id", "a260", "a260_280", "a260_280_note", "a260_230", "a260_230_note", "measurement_date", "elution_volume_ul", "person_id", "status_id", "storage_id", "storage_position", "project_id") VALUES
('Test_db_nanodrop', 'Test_db', '2025-07-01', 'TestDB25TestDBTestDB0001', 1, 'Test_db', 1, 1, 'Test_db', 1, 'Test_db', '2025-07-01', 1, 'Test_db', 'Test_db', 'Test_db', 'Test_db', 'Test_db')
ON CONFLICT ("nanodrop_id", "measurement_date") DO NOTHING;

INSERT INTO "lab"."qubit" ("qubit_id", "sample_id", "experiment_id", "experiment_date", "run_id", "assay_kit", "measurement_date", "qubit_tube_conc", "tube_unit_id", "qubit_original_sample_conc", "original_sample_unit_id", "sample_volume_ul", "elution_volume_ul", "person_id", "status_id", "storage_id", "storage_position", "project_id") VALUES
('Test_db_qubit', 'Test_db_sample', 'Test_db', '2025-07-01', 'Test_db', 'Test_db', '2025-07-01', 1, 'Test_db', 1, 'Test_db', 1, 1, 'Test_db', 'Test_db', 'Test_db', 'Test_db', 'Test_db')
ON CONFLICT ("qubit_id", "measurement_date") DO NOTHING;

INSERT INTO "lab"."tapestation" ("tapestation_id", "experiment_id", "experiment_date", "position", "measurement_date", "kit", "person_id", "sample_id", "storage_id", "storage_position", "status_id", "project_id") VALUES
('Test_db_tape', 'Test_db', '2025-07-01', 'Test_db', '2025-07-01', 'Test_db', 'Test_db', 'Test_db_sample', 'Test_db', 'Test_db', 'Test_db', 'Test_db')
ON CONFLICT ("tapestation_id", "measurement_date") DO NOTHING;

INSERT INTO "lab"."pcr" ("pcr_id", "experiment_id", "experiment_date", "sample_id", "position", "primer_id", "pcr_blank_id", "pcr_date", "person_id", "kit", "storage_id", "storage_position", "status_id", "project_id", "volume_reaction_ul") VALUES
('Test_db_pcr', 'Test_db', '2025-07-01', 'Test_db_sample', 'Test_db', 'Test_db', 'Test_db', '2025-07-01', 'Test_db', 'Test_db', 'Test_db', 'Test_db', 'Test_db', 'Test_db', 1)
ON CONFLICT ("pcr_id", "pcr_date") DO NOTHING;

INSERT INTO "lab"."gelelectrophoresis" ("gelelectrophoresis_id", "experiment_id", "experiment_date", "sample_id", "position", "ladder", "voltage", "band_size_bp", "gel_type", "run_time_minutes", "run_date", "person_id", "storage_id", "storage_position", "project_id") VALUES
('Test_db_gel', 'Test_db', '2025-07-01', 'Test_db_sample', 'Test_db', 'Test_db', 1, 1, 'Test_db', 1, '2025-07-01', 'Test_db', 'Test_db', 'Test_db', 'Test_db')
ON CONFLICT ("gelelectrophoresis_id", "run_date") DO NOTHING;

INSERT INTO "lab"."qpcr" ("qpcr_id", "experiment_id", "experiment_date", "sample_id", "position", "qpcr_date", "person_id", "primer_id", "ct_value", "inhibitor_test_result", "pcr_blank_id", "kit", "volume_ul", "storage_id", "storage_position", "status_id", "project_id") VALUES
('Test_db_qpcr', 'Test_db', '2025-07-01', 'Test_db_sample', 'Test_db', '2025-07-01', 'Test_db', 'Test_db', 1, 'Test_db', 'Test_db', 'Test_db', 1, 'Test_db', 'Test_db', 'Test_db', 'Test_db')
ON CONFLICT ("qpcr_id", "qpcr_date") DO NOTHING;

INSERT INTO "lab"."library" ("library_id", "experiment_id", "experiment_date", "sample_id", "library_name", "prep_date", "person_id", "library_prep_kit", "index_sequence", "read_length_bp", "storage_id", "storage_position", "project_id") VALUES
('Test_db_library', 'Test_db', '2025-07-01', 'Test_db_sample', 'Test_db', '2025-07-01', 'Test_db', 'Test_db', 'Test_db', 1, 'Test_db', 'Test_db', 'Test_db')
ON CONFLICT ("library_id", "prep_date") DO NOTHING;

INSERT INTO "lab"."sequencing" ("sequencing_id", "experiment_id", "experiment_date", "library_id", "prep_date", "sample_id", "sequencing_date", "person_id", "sequencer", "flow_cell_id", "library_prep_kit", "index_sequence", "read_length_bp", "total_reads", "raw_data_path", "genbank_accession_number", "status_id", "storage_id", "storage_position", "project_id") VALUES
('Test_db_seq', 'Test_db', '2025-07-01', 'Test_db_library', '2025-07-01', 'Test_db_sample', '2025-07-01', 'Test_db', 'Test_db', 'Test_db', 'Test_db', 'Test_db', 1, 1, 'Test_db', 'Test_db', 'Test_db', 'Test_db', 'Test_db', 'Test_db')
ON CONFLICT ("sequencing_id", "sequencing_date") DO NOTHING;

INSERT INTO "lab"."datasets" ("dataset_id", "source_type", "ecosystem_id", "region_id", "customer_id", "stored_location_id", "reception_date", "storage_path") VALUES
('Test_db_dataset', 'Test_db', 'Test_db', 'Test_db', 1, 'Test_db', '2025-07-01', 'Test_db')
ON CONFLICT ("dataset_id", "reception_date") DO NOTHING;

-- Bioinformatics Schema Tables
INSERT INTO "bioinformatics"."reference_databases" ("db_id", "db_name", "db_version", "url", "last_updated_date") VALUES
('Test_db', 'Test_db', 'Test_db', 'Test_db', '2025-07-01')
ON CONFLICT ("db_id") DO NOTHING;

INSERT INTO "bioinformatics"."analysis_pipelines" ("pipeline_id", "pipeline_name", "version", "repository_link") VALUES
('Test_db_pipeline', 'Test_db', 'Test_db', 'Test_db')
ON CONFLICT ("pipeline_id") DO NOTHING;

INSERT INTO "bioinformatics"."analysis_runs" ("run_id", "pipeline_id", "sequencing_id", "sequencing_date", "person_id", "run_date", "parameters_jsonb", "reference_db_id", "clustering_threshold", "final_output_path") VALUES
('Test_db_run', 'Test_db_pipeline', 'Test_db_seq', '2025-07-01', 'Test_db', '2025-07-01 10:00:00+02', '{}'::jsonb, 'Test_db', 1, 'Test_db')
ON CONFLICT ("run_id", "run_date") DO NOTHING;

INSERT INTO "bioinformatics"."edna_assignments" ("assignment_id", "run_id", "run_date", "sample_id", "taxon_id", "read_count", "confidence") VALUES
('Test_db_assignment', 'Test_db_run', '2025-07-01', 'Test_db_sample', 'Test_db', 1, 1)
ON CONFLICT ("assignment_id") DO NOTHING;



-- Ensure necessary reference data exists for FKs
INSERT INTO "lims"."external_contacts" ("contact_id", "full_name", "organization", "mail") VALUES
('agency_1', 'Max Mustermann', 'Fischereibehörde Nord', 'max.mustermann@agency1.de') ON CONFLICT (contact_id) DO NOTHING;
INSERT INTO "lims"."external_contacts" ("contact_id", "full_name", "organization", "mail") VALUES
('agency_2', 'Erika Musterfrau', 'Landesamt für Fischerei', 'erika.musterfrau@agency2.de') ON CONFLICT (contact_id) DO NOTHING;

INSERT INTO "lims"."projects" ("project_id", "title", "status_id", "pi_person_id", "start_date") VALUES
('ProjectWanderfische_Main', 'Wanderfische Monitoring', 'Active', 'system_user', '2024-01-01') ON CONFLICT (project_id) DO NOTHING;

INSERT INTO "reference"."taxon" ("taxon_id", "de_name", "en_name", "rank", "path") VALUES
('Gadus_morhua', 'Dorsch', 'Atlantic Cod', 'species', 'Animalia.Chordata.Actinopterygii.Gadiformes.Gadidae.Gadus.Gadus_morhua') ON CONFLICT (taxon_id) DO NOTHING;
INSERT INTO "reference"."taxon" ("taxon_id", "de_name", "en_name", "rank", "path") VALUES
('Salmo_salar', 'Atlantischer Lachs', 'Atlantic Salmon', 'species', 'Animalia.Chordata.Actinopterygii.Salmoniformes.Salmonidae.Salmo.Salmo_salar') ON CONFLICT (taxon_id) DO NOTHING;
INSERT INTO "reference"."taxon" ("taxon_id", "de_name", "en_name", "rank", "path") VALUES
('Perca_fluviatilis', 'Flussbarsch', 'European Perch', 'species', 'Animalia.Chordata.Actinopterygii.Perciformes.Percidae.Perca.Perca_fluviatilis') ON CONFLICT (taxon_id) DO NOTHING;
INSERT INTO "reference"."taxon" ("taxon_id", "de_name", "en_name", "rank", "path") VALUES
('Gasterosteus_aculeatus', 'Dreistachliger Stichling', 'Three-spined Stickleback', 'species', 'Animalia.Chordata.Actinopterygii.Gasterosteiformes.Gasterosteidae.Gasterosteus.Gasterosteus_aculeatus') ON CONFLICT (taxon_id) DO NOTHING;
INSERT INTO "reference"."taxon" ("taxon_id", "de_name", "en_name", "rank", "path") VALUES
('Gobio_gobio', 'Gründling', 'Gudgeon', 'species', 'Animalia.Chordata.Actinopterygii.Cypriniformes.Cyprinidae.Gobio.Gobio_gobio') ON CONFLICT (taxon_id) DO NOTHING;
INSERT INTO "reference"."taxon" ("taxon_id", "de_name", "en_name", "rank", "path") VALUES
('Leuciscus_leuciscus', 'Hasel', 'Chub', 'species', 'Animalia.Chordata.Actinopterygii.Cypriniformes.Cyprinidae.Leuciscus.Leuciscus_leuciscus') ON CONFLICT (taxon_id) DO NOTHING;

-- Populate ltree path after inserting new taxon data
SELECT "reference".update_taxon_ltree_paths();

-- Ensure units are available (from your existing schema)
INSERT INTO "reference"."units" ("unit_id", "unit_name", "unit_abbreviation", "unit_type", "conversion_factor_to_base") VALUES
('m', 'meter', 'm', 'length', 1),
('kg', 'kilogram', 'kg', 'mass', 1),
('C', 'Celsius', '°C', 'temperature', 1),
('PSU', 'Practical Salinity Unit', 'PSU', 'salinity', 1),
('mg_l', 'milligram per liter', 'mg/L', 'concentration', 1),
('NTU', 'Nephelometric Turbidity Unit', 'NTU', 'turbidity', 1),
('m_s', 'meter per second', 'm/s', 'speed', 1)
ON CONFLICT (unit_id) DO NOTHING;


-- Example 1: Data from "Datum Uhrzeit MST_ID Messstellen_Bezeichnung Los Rechtswert Hochwert Breite "watend/Boot" "Abschnitts-länge" Probenentnahme"
INSERT INTO "projects"."ProjectWanderfische_FishingData" (
    "agency_id", "project_id", "agency_record_id", "record_date", "record_time",
    "original_easting", "original_northing", "original_latitude", "original_longitude", "original_srid",
    "location_description", "average_width_m", "fishing_method", "fishing_length_m", "notes",
    "water_body_type", "water_depth_m", "fishing_start_time", "fishing_end_time",
    "original_data_jsonb"
) VALUES (
    'agency_1', 'ProjectWanderfische_Main', 'MST_ID_12692', '2025-08-18', '09:30:00',
    32573264, 5608084, NULL, NULL, 25832, -- Assuming UTM32N (EPSG:25832) for Rechtswert/Hochwert
    'Weid, oberhalb MWE, unterhalb Mündung Fisch-Bach', 2.5, 'E-Gerät', 300, NULL,
    'River', 1.5, '09:30:00', '10:00:00',
    '{"Datum": "18.08.2025", "Uhrzeit": "ab 09:30 Uhr", "MST_ID": "12692", "Messstellen_Bezeichnung": "Weid, oberhalb MWE, unterhalb Mündung Fisch-Bach", "Los": "1", "Rechtswert": "32573264", "Hochwert": "5608084", "Breite": ">2 - 5 m", "watend/Boot": "1", "Abschnitts-länge": "E-Gerät 300", "Probenentnahme": null}'::jsonb
);

-- Example 2: Data from "Datum Uhrzeit MST_ID RWB_NAME NAME_LAGE Los RW_UTM HW_UTM Breite Art_Elektrobefischung Befischungslaenge Bemerkung"
INSERT INTO "projects"."ProjectWanderfische_FishingData" (
    "agency_id", "project_id", "agency_record_id", "record_date", "record_time",
    "original_easting", "original_northing", "original_latitude", "original_longitude", "original_srid",
    "location_description", "water_body_name", "average_width_m", "fishing_method", "fishing_length_m", "notes",
    "water_body_type", "water_depth_m", "fishing_start_time", "fishing_end_time",
    "original_data_jsonb"
) VALUES (
    'agency_1', 'ProjectWanderfische_Main', 'MST_ID_10029', '2025-07-28', '09:30:00',
    429903, 5581907, NULL, NULL, 25832, -- Assuming UTM32N (EPSG:25832) for RW_UTM/HW_UTM
    'Lahn bei Limburg-Staffel', 'Lahn/Limburg', 30, 'Boot', 500, 'INGA (TB, LS), Biota',
    'River', 2.0, '09:30:00', '10:30:00',
    '{"Datum": "28.07.2025", "Uhrzeit": "ab 9:30", "MST_ID": "10029", "RWB_NAME": "Lahn/Limburg", "NAME_LAGE": "ChemisMST Lahn bei Limburg-Staffel", "Los": "4", "RW_UTM": "429903", "HW_UTM": "5581907", "Breite": ">20 - 40 m", "Art_Elektrobefischung": "Boot", "Befischungslaenge": "500", "Bemerkung": "INGA (TB, LS), Biota"}'::jsonb
);

-- Example 3: Data from "probestellennr Gewässername GWKZ Lagebeschreibung Synergie etrs89e etrs89n ofwk Fischgewässertyp Befischungsjahr"
INSERT INTO "projects"."ProjectWanderfische_FishingData" (
    "agency_id", "project_id", "agency_record_id", "record_date", "fishing_year",
    "original_easting", "original_northing", "original_latitude", "original_longitude", "original_srid",
    "location_description", "water_body_name", "water_body_code", "notes",
    "water_body_type", "catchment_area",
    "original_data_jsonb"
) VALUES (
    'agency_2', 'ProjectWanderfische_Main', 'aussen-01-41', '2025-01-01', 2025, -- Date is inferred as start of year if not provided
    476899, 5782848, NULL, NULL, 25832, -- Assuming ETRS89 UTM Zone 32N (EPSG:25832)
    'Kurz oberhalb Straßenbrücke Ascher Bruch', 'Else', '466', 'WRRL',
    'River', 'Weser',
    '{"probestellennr": "aussen-01-41", "Gewässername": "Else", "GWKZ": "466", "Lagebeschreibung": "Kurz oberhalb Straßenbrücke Ascher Bruch", "Synergie": "WRRL", "etrs89e": "476899", "etrs89n": "5782848", "ofwk": "DE_NRW_466_0", "Fischgewässertyp": "FiGt_23", "Befischungsjahr": "2025"}'::jsonb
);

-- Example 4: Data from "OWK-Nr. Gewässer Messstelle (kurz) Mst_Nr (Bio) Termin H_Wert_Fisch R_Wert_Fisch UTM_Fisch mittl. Breite in m Landkreis"
INSERT INTO "projects"."ProjectWanderfische_FishingData" (
    "agency_id", "project_id", "agency_record_id", "record_date",
    "original_easting", "original_northing", "original_latitude", "original_longitude", "original_srid",
    "location_description", "water_body_name", "average_width_m", "district",
    "water_body_type", "water_depth_m",
    "original_data_jsonb"
) VALUES (
    'agency_2', 'ProjectWanderfische_Main', 'MEL05OW01-00', '2025-09-16',
    678819, 5870927, NULL, NULL, 25832, -- Assuming UTM32 (EPSG:25832) for H_Wert_Fisch/R_Wert_Fisch
    'oh Str Wahrenberg-Scharpenhufe', 'Aland', 25, 'Landkreis Stendal',
    'River', 1.8,
    '{"OWK-Nr.": "MEL05OW01-00", "Gewässer": "Aland", "Messstelle (kurz)": "oh Str Wahrenberg-Scharpenhufe", "Mst_Nr (Bio)": "410640", "Termin": "16.09.2025", "H_Wert_Fisch": "5870927", "R_Wert_Fisch": "678819", "UTM_Fisch": "32", "mittl. Breite in m": ">25", "Landkreis": "Landkreis Stendal"}'::jsonb
);

-- Example 5: Data from "Wasserkörper Nr. Wasserkörper Messstelle Nr. Messstelle Jahr Dts. Artname wissenschaftl. Artname Anzahl Gesamt Anzahl Juvenil Anzahl Praeadult Anzahl Adult Befischte Strecke [m] Befischte Fläche [m²] Fischreferenz Einstufung Gewässerkategorie Gewässertyp Nr. Gewässertyp Flussgebietseinheit BGV Nr. Bearbeitungsgebiet UTM-32 East UTM-32 North UTM 32-East FIS UTM 32-North FIS Methode Bemerkung Probe"
-- This example contains multiple fish species per record, so we'll insert one fishing record
-- and then multiple fish catch records linked to it.
INSERT INTO "projects"."ProjectWanderfische_FishingData" (
    "agency_id", "project_id", "agency_record_id", "record_date", "fishing_year",
    "original_easting", "original_northing", "original_latitude", "original_longitude", "original_srid",
    "location_description", "water_body_name", "water_body_code",
    "fishing_length_m", "fishing_area_sqm", "fishing_method", "notes",
    "water_body_type", "catchment_area", "water_depth_m",
    "original_data_jsonb"
) VALUES (
    'agency_2', 'ProjectWanderfische_Main', 'vi_02_b_120864_2022', '2022-01-01', 2022, -- Date inferred as start of year
    32495543, 6083998, NULL, NULL, 25832, -- UTM-32 East/North (EPSG:25832)
    'Süderau, nordöstl. Böglum', 'Süderau und NG', 'vi_02_b',
    275, 1100, 'Elektrofischerei', NULL,
    'River', 'Eider', 1.2,
    '{"Wasserkörper Nr.": "vi_02_b", "Wasserkörper": "Süderau und NG", "Messstelle Nr.": "120864", "Messstelle": "Süderau, nordöstl. Böglum", "Jahr": "2022", "Dts. Artname": "Dreist. Stichling (Binnenform)", "wissenschaftl. Artname": "Gasterosteus aculeatus (Binnenform)", "Anzahl Gesamt": "25", "Anzahl Juvenil": "25", "Anzahl Praeadult": null, "Anzahl Adult": null, "Befischte Strecke [m]": "275", "Befischte Fläche [m²]": "1100", "Fischreferenz": "5c", "Einstufung": "1", "Gewässerkategorie": "Fließgewässer", "Gewässertyp Nr.": "19", "Gewässertyp": "Kleine Niederungsfließgewässer in Fluss- und Stromtälern", "Flussgebietseinheit": "Eider", "BGV Nr.": "2", "Bearbeitungsgebiet": "Gotteskoog", "UTM-32 East": "32495543", "UTM-32 North": "6083998", "UTM 32-East FIS": "32495544", "UTM 32-North FIS": "6083998", "Methode": "Elektrofischerei", "Bemerkung": null, "Probe": null}'::jsonb
);

-- Retrieve the last inserted fishing_record_id and record_date to link fish catches
DO $$
DECLARE
    last_fishing_record_id text;
    last_record_date date;
BEGIN
    SELECT fishing_record_id, record_date INTO last_fishing_record_id, last_record_date
    FROM "projects"."ProjectWanderfische_FishingData"
    ORDER BY created_at DESC
    LIMIT 1;

    -- Fish Catch records for the above fishing event
    INSERT INTO "projects"."ProjectWanderfische_FishCatch" (
        "fishing_record_id", "fishing_record_date", "taxon_id", "scientific_name_raw", "german_name_raw",
        "total_count", "juvenile_count", "praeadult_count", "adult_count",
        "individual_length_mm", "individual_weight_g", "sex", "maturity_stage", "condition_factor", "disease_info", "origin_type"
    ) VALUES
    (
        last_fishing_record_id, last_record_date,
        (SELECT taxon_id FROM "reference"."taxon" WHERE en_name = 'Three-spined Stickleback' LIMIT 1),
        'Gasterosteus aculeatus (Binnenform)', 'Dreist. Stichling (Binnenform)',
        25, 25, NULL, NULL,
        70, 5, 'Undetermined', 'Juvenile', 1.2, NULL, 'Wild'
    ),
    (
        last_fishing_record_id, last_record_date,
        (SELECT taxon_id FROM "reference"."taxon" WHERE en_name = 'Gudgeon' LIMIT 1),
        'Gobio gobio', 'Gründling',
        10, 1, 9, NULL,
        120, 15, 'Undetermined', 'Praeadult', 1.1, NULL, 'Wild'
    ),
    (
        last_fishing_record_id, last_record_date,
        (SELECT taxon_id FROM "reference"."taxon" WHERE en_name = 'Chub' LIMIT 1),
        'Leuciscus leuciscus', 'Hasel',
        2, NULL, NULL, 2,
        250, 150, 'Male', 'Adult', 1.3, NULL, 'Wild'
    );

    -- Example Mail
    INSERT INTO "projects"."ProjectWanderfische_Mail" (
        "fishing_record_id", "fishing_record_date", "sender_person_id", "recipient_contact_id",
        "subject", "body", "sent_at"
    ) VALUES (
        last_fishing_record_id, last_record_date, 'system_user', 'agency_1',
        'Data Request for 2022 Fishing Season', 'Dear Agency 1, we are requesting your full fishing data for the 2022 season.',
        '2023-01-15 10:00:00+01'
    );

    -- Example Conversation
    INSERT INTO "projects"."ProjectWanderfische_Conversation" (
        "fishing_record_id", "fishing_record_date", "topic", "started_at"
    ) VALUES (
        last_fishing_record_id, last_record_date, 'Coordination of 2022 Data Submission',
        '2023-01-16 14:00:00+01'
    );

    -- Retrieve the last inserted conversation_id to link chat messages
    DECLARE
        last_conversation_id text;
    BEGIN
        SELECT conversation_id INTO last_conversation_id
        FROM "projects"."ProjectWanderfische_Conversation"
        ORDER BY started_at DESC
        LIMIT 1;

        -- Example Chat Messages
        INSERT INTO "projects"."ProjectWanderfische_ChatMessage" (
            "conversation_id", "sender_person_id", "message_text", "sent_at"
        ) VALUES (
            last_conversation_id, 'system_user', 'Hi Agency 1, can you confirm receipt of our data request?',
            '2023-01-16 14:05:00+01'
        );

        INSERT INTO "projects"."ProjectWanderfische_ChatMessage" (
            "conversation_id", "sender_contact_id", "message_text", "sent_at"
        ) VALUES (
            last_conversation_id, 'agency_1', 'Yes, we received it. We will process it next week.',
            '2023-01-16 14:15:00+01'
        );
    END;
END $$;



