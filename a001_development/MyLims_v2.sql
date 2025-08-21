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
    "person_id" text PRIMARY KEY, -- manually
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
    "contact_id" text PRIMARY KEY, -- manually
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
    "project_id" text PRIMARY KEY, -- manually, the akronym
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
    "storage_id" text PRIMARY KEY, -- manually
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
    "cruise_id" text PRIMARY KEY, -- manually
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
    "batch_id" text PRIMARY KEY, -- manually
    "batch_name" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "lims"."batch_steps" (
    "step_id" text PRIMARY KEY, -- batchid_stepNumber
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
    "permit_id" text PRIMARY KEY, -- manually
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
    "primer_id" text PRIMARY KEY, -- manually
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
    "sop_id" text PRIMARY KEY, -- SopIdOrigin_vVesion e.g. sp34_v3
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
    "equipment_id" text PRIMARY KEY, -- manually
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
    "supplier_id" text PRIMARY KEY, -- manually
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
    "item_id" text PRIMARY KEY, -- manualy
    "item_name" text NOT NULL,
    "category_id" text,
    "notes" text,
    "unit_id" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "lims"."orders" (
    "fi_order_nr" text PRIMARY KEY, -- manually 
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
    "reagent_id" text PRIMARY KEY, -- manually
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
    "publication_type_id" text PRIMARY KEY, -- manzally
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "lims"."publications" (
    "publication_id" text PRIMARY KEY, -- manually
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
    "experiment_id" text NOT NULL, -- manually
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
    "sampling_id" text NOT NULL, -- 99FleHB-456 99 year -  ecosystem and Region Abrviation- 456 s
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
    "fishing_id" text NOT NULL, -- 99WesHH999_f999 samplingid_fserial
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
    "sampling_id" text NOT NULL, -- sampling id
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
    "sample_id" text NOT NULL, -- S99Pprj_999  sampletype abrviation year project/custmer avribiation_ serial
    "sample_type_id" text NOT NULL,
    "external_name" text,
    "parent_sample_id" text,
    "root_sample_id" text,
    "project_id" text,
    "customer_id" integer,
    "sample_creation_date" date NOT NULL,
    "parent_sample_creation_date" date,
    "root_sample_creation_date" date,
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
    "sample_id" text NOT NULL, -- manually
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
    "sample_id" text NOT NULL, -- manualy
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
    "otolith_id" text NOT NULL, --- manual
    "parent_sample_id" text,
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
    "sample_id" text NOT NULL, -- manual
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
    "sample_id" text NOT NULL, -- manual
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
    "sample_id" text NOT NULL, -- manual
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
    "sample_id" text NOT NULL, -- manual
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
    "sample_id" text NOT NULL, -- manual
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
    "dissection_id" text NOT NULL, -- sampleid_d9
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
    "nanodrop_id" text NOT NULL, -- sampleid_n9
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
    PRIMARY KEY ("nanodrop_id","experiment_date")
) PARTITION BY RANGE ("experiment_date");

CREATE TABLE IF NOT EXISTS "lab"."qubit" (
    "qubit_id" text NOT NULL, -- sampleid_q9
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
    "tapestation_id" text NOT NULL, -- sampleid_t9
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
    "gelelectrophoresis_id" text NOT NULL, -- sampleid_gel9
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
    "experiment_id" text, -- sampleid_qp99
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
    "library_id" text NOT NULL, --manualy
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
    "sequencing_run_id" text NOT NULL,  --RS25_999
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
    "data_seq_id" text NOT NULL,  --sampleid_RS4
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
    PRIMARY KEY ("data_seq_id", "sample_creation_date")
) PARTITION BY RANGE ("sample_creation_date");

CREATE TABLE IF NOT EXISTS "lab"."datasets" (
    "dataset_id" text NOT NULL, --Z25[sampleid]_999
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
    "pipeline_id" text PRIMARY KEY, -- BI25_p999
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
    "run_id" text NOT NULL, --BI25_ar999
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
    "assignment_id" text PRIMARY KEY, -- BI25_sampleid_999
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
    "fishing_record_id" serial NOT NULL, -- Part of composite PK, unique per year
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
    "fish_catch_id" serial PRIMARY KEY,
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
    "mail_id" serial PRIMARY KEY,
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
    "conversation_id" serial PRIMARY KEY,
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
    "message_id" serial PRIMARY KEY,
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


-- ======================================================================
-- F01. FUNCTIONS TO POPULATE PARTITIONING DATES FROM PARENT TABLES
-- These functions ensure the partitioning key column is populated before the partition is created.
-- ======================================================================

-- Function to populate sample_creation_date for child sample tables
-- CREATE OR REPLACE FUNCTION "lab".populate_date_from_root_sample()
-- RETURNS TRIGGER AS $$
-- DECLARE
--     parent_date date;
-- BEGIN
--     IF NEW.sample_creation_date IS NULL THEN
--        -- Check if the parent sample ID is provided and exists
--        IF NEW.sample_id IS NOT NULL THEN
--            SELECT "sample_creation_date"
--            INTO parent_date
--            FROM "lab"."root_samples"
--            WHERE "sample_id" = NEW.sample_id;
--    
--            IF NOT FOUND THEN
--                RAISE EXCEPTION 'Associated root_sample not found for sample_id %', NEW.sample_id;
--            END IF;
--    
--            NEW.sample_creation_date := parent_date;
--        END IF;
--    END IF;
--    RETURN NEW;
-- END;
-- $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "lab".populate_dates_for_root_sample()
RETURNS TRIGGER AS $$
DECLARE
    parent_record RECORD;
BEGIN
    -- This trigger should fire BEFORE INSERT on the root_samples table.

    -- Case 1: The sample is a new root sample (no parent or root ID specified).
    IF NEW.parent_sample_id IS NULL AND NEW.root_sample_id IS NULL THEN
        -- The root_sample_id and its creation date should be its own.
        NEW.root_sample_id := NEW.sample_id;
        NEW.root_sample_creation_date := NEW.sample_creation_date;
        -- The parent fields remain NULL.
        NEW.parental_sample_creation_date := NULL;

    -- Case 2: The sample is a child with a specified parent.
    ELSIF NEW.parent_sample_id IS NOT NULL THEN
        -- Look up the parent's creation date and its root's ID and date.
        SELECT "sample_creation_date", "root_sample_id", "root_sample_creation_date"
        INTO parent_record
        FROM "lab"."root_samples"
        WHERE "sample_id" = NEW.parent_sample_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Associated parent sample not found for sample_id %', NEW.parent_sample_id;
        END IF;

        -- Copy the dates from the parent record.
        NEW.parental_sample_creation_date := parent_record.sample_creation_date;
        NEW.root_sample_id := parent_record.root_sample_id;
        NEW.root_sample_creation_date := parent_record.root_sample_creation_date;
        -- Set the current sample's creation date to NOW().
        NEW.sample_creation_date := CURRENT_DATE;

    -- Case 3: The sample directly references a root sample but not a parent.
    ELSIF NEW.root_sample_id IS NOT NULL AND NEW.parent_sample_id IS NULL THEN
        -- Look up the root's creation date.
        SELECT "sample_creation_date"
        INTO parent_record
        FROM "lab"."root_samples"
        WHERE "sample_id" = NEW.root_sample_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Associated root sample not found for root_sample_id %', NEW.root_sample_id;
        END IF;

        -- Set the root dates.
        NEW.root_sample_creation_date := parent_record.sample_creation_date;
        -- The parent fields remain NULL.
        NEW.parental_sample_creation_date := NULL;
        -- Set the current sample's creation date to NOW().
        NEW.sample_creation_date := CURRENT_DATE;

    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to populate sampling_date for child tables from lab.sampling.
CREATE OR REPLACE FUNCTION "lab".populate_date_from_sampling()
RETURNS TRIGGER AS $$
DECLARE
    parent_date date;
BEGIN
    IF NEW.sampling_date IS NULL THEN
        IF NEW.sampling_id IS NOT NULL THEN
            SELECT "sampling_date"
            INTO parent_date
            FROM "lab"."sampling"
            WHERE "sampling_id" = NEW.sampling_id;

            IF NOT FOUND THEN
                RAISE EXCEPTION 'Associated sampling record not found for sampling_id %', NEW.sampling_id;
            END IF;

            NEW.sampling_date := parent_date;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to populate experiment_date for child tables from lab.experiments.
CREATE OR REPLACE FUNCTION "lab".populate_date_from_experiment()
RETURNS TRIGGER AS $$
DECLARE
    parent_date date;
BEGIN
    IF NEW.experiment_date IS NULL THEN
        IF NEW.experiment_id IS NOT NULL THEN
            SELECT "experiment_date"
            INTO parent_date
            FROM "lab"."experiments"
            WHERE "experiment_id" = NEW.experiment_id;

            IF NOT FOUND THEN
                RAISE EXCEPTION 'Associated experiment not found for experiment_id %', NEW.experiment_id;
            END IF;

            NEW.experiment_date := parent_date;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to populate sequencing_date for bioinformatics.analysis_runs from lab.sequencing_run.
CREATE OR REPLACE FUNCTION "bioinformatics".populate_date_from_sequencing()
RETURNS TRIGGER AS $$
DECLARE
    parent_date date;
BEGIN
    IF NEW.sequencing_date IS NULL THEN
        IF NEW.sequencing_id IS NOT NULL THEN
            SELECT "experiment_date" -- The partitioning column in sequencing_run is "experiment_date"
            INTO parent_date
            FROM "lab"."sequencing_run"
            WHERE "sequencing_run_id" = NEW.sequencing_id;

            IF NOT FOUND THEN
                RAISE EXCEPTION 'Associated sequencing run not found for sequencing_id %', NEW.sequencing_id;
            END IF;

            NEW.sequencing_date := parent_date;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ======================================================================
-- F02. DYNAMIC PARTITION CREATION FUNCTION
-- This is a generic function for creating yearly partitions based on a date column.
-- ======================================================================

CREATE OR REPLACE FUNCTION create_yearly_partition()
RETURNS TRIGGER AS $$
DECLARE
    partition_date date;
    partition_table_name text := TG_TABLE_NAME;
    partition_schema_name text := TG_TABLE_SCHEMA;
    partition_name text;
    start_date date;
    end_date date;
BEGIN
    -- Get the value of the partitioning date column from the new row.
    EXECUTE 'SELECT ($1).' || TG_ARGV[0] INTO partition_date USING NEW;

    IF partition_date IS NULL THEN
        RAISE EXCEPTION 'Cannot partition on NULL date column for %.%.', partition_schema_name, partition_table_name;
    END IF;

    -- Generate the start and end dates for the new yearly partition.
    start_date := DATE_TRUNC('year', partition_date);
    end_date := start_date + INTERVAL '1 year';
    
    -- Generate the unique partition name using the table name and year.
    partition_name := partition_table_name || '_y' || TO_CHAR(start_date, 'YYYY');

    -- Check if the partition exists and create it if it doesn't.
    -- The IF NOT EXISTS clause prevents errors if the trigger fires for an existing partition.
    EXECUTE 'CREATE TABLE IF NOT EXISTS ' || quote_ident(partition_schema_name) || '.' || quote_ident(partition_name) || ' PARTITION OF ' || quote_ident(partition_schema_name) || '.' || quote_ident(partition_table_name) || ' FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ======================================================================
-- F03. AUDIT LOGGING FUNCTION
-- ======================================================================

CREATE OR REPLACE FUNCTION "audit".if_modified_func() RETURNS TRIGGER AS $$
DECLARE
    v_old_data jsonb;
    v_new_data jsonb;
    v_action text;
BEGIN
    -- Determine the action type
    v_action := TG_OP;

    -- Capture data based on the action
    IF (TG_OP = 'UPDATE') THEN
        v_old_data := row_to_json(OLD)::jsonb;
        v_new_data := row_to_json(NEW)::jsonb;
    ELSIF (TG_OP = 'DELETE') THEN
        v_old_data := row_to_json(OLD)::jsonb;
    ELSIF (TG_OP = 'INSERT') THEN
        v_new_data := row_to_json(NEW)::jsonb;
    END IF;

    -- Insert the log entry
    INSERT INTO "audit"."log" ("schema_name", "table_name", "user_id", "action", "original_data", "new_data", "query_text")
    VALUES (
        TG_TABLE_SCHEMA::text,
        TG_TABLE_NAME::text,
        current_user::text,
        v_action,
        v_old_data,
        v_new_data,
        current_query()
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ======================================================================
-- F04. STATUS UPDATE FUNCTION
-- ======================================================================
-- The function to automatically update a sample's status in lab.root_samples.
-- This function is crucial for tracking sample progression through the workflow.
CREATE OR REPLACE FUNCTION "lab".update_sample_status()
RETURNS TRIGGER AS $$
DECLARE
    new_status_note text := TG_ARGV[0];
BEGIN
    -- Check if the sample exists and update its status
    UPDATE "lab"."root_samples"
    SET status_id = (SELECT status_id FROM "reference"."status" WHERE notes = new_status_note LIMIT 1)
    WHERE sample_id = NEW.sample_id AND sample_creation_date = NEW.sample_creation_date;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ======================================================================
-- F05. ID GENERATION FUNCTIONS
-- ======================================================================
-- Function to generate sampling_id (e.g., 25FleHB_001)
CREATE OR REPLACE FUNCTION "lab".generate_sampling_id()
RETURNS TRIGGER AS $$
DECLARE
    sampling_year text;
    ecosystem_abrv text;
    region_abrv text;
    id_prefix text;
    next_serial integer;
BEGIN
    sampling_year := TO_CHAR(COALESCE(NEW.sampling_date, CURRENT_DATE), 'YY');
    
    -- Get ecosystem and region abbreviations based on IDs
    SELECT COALESCE(e.ecosystem_abrv, 'UNK') INTO ecosystem_abrv
    FROM "reference"."ecosystem" e
    WHERE e.ecosystem_id = NEW.ecosystem_id;
    
    SELECT COALESCE(r.region_abrv, 'UNK') INTO region_abrv
    FROM "reference"."region" r
    WHERE r.region_id = NEW.region_id;

    -- Combine parts to create the prefix
    id_prefix := sampling_year || ecosystem_abrv || region_abrv;

    -- Find the next serial number for this specific prefix
    SELECT COALESCE(MAX(SUBSTRING("sampling_id" FROM LENGTH(id_prefix) + 1)::INTEGER), 0)
    INTO next_serial
    FROM "lab"."sampling"
    WHERE "sampling_id" LIKE id_prefix || '%';

    NEW.sampling_id := id_prefix || LPAD((next_serial + 1)::TEXT, 3, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate fishing_id (e.g., 25FleHB001_f001)
CREATE OR REPLACE FUNCTION "lab".generate_fishing_id()
RETURNS TRIGGER AS $$
DECLARE
    next_serial integer;
    id_prefix text;
BEGIN
    -- Prefix is parent sampling_id + "_f"
    id_prefix := NEW.sampling_id || '_f';

    -- Find the next serial number for this specific prefix
    SELECT COALESCE(MAX(SUBSTRING("fishing_id" FROM LENGTH(id_prefix) + 1)::INTEGER), 0)
    INTO next_serial
    FROM "lab"."fishing"
    WHERE "fishing_id" LIKE id_prefix || '%';

    NEW.fishing_id := id_prefix || LPAD((next_serial + 1)::TEXT, 3, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate individual_catch_id (e.g., fishing_id_if000)
CREATE OR REPLACE FUNCTION "lab".generate_individual_catch_id()
RETURNS TRIGGER AS $$
DECLARE
    next_serial integer;
    id_prefix text;
BEGIN
    -- Prefix is parent fishing_id + "_ic"
    id_prefix := NEW.fishing_id || '_ic';

    -- Find the next serial number for this specific prefix
    SELECT COALESCE(MAX(SUBSTRING("individual_catch_id" FROM LENGTH(id_prefix) + 1)::INTEGER), 0)
    INTO next_serial
    FROM "lab"."individual_catch_catch"
    WHERE "individual_catch_id" LIKE id_prefix || '%';

    NEW.individual_catch_id := id_prefix || LPAD((next_serial + 1)::TEXT, 3, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate root_samples and child IDs from a single entry point
CREATE OR REPLACE FUNCTION "lab".generate_sample_id()
RETURNS TRIGGER AS $$
DECLARE
    sample_type_abrv text;
    id_prefix text;
    next_serial integer;
    parent_id_check text;
BEGIN
    -- Get sample type abbreviation for ID part
    SELECT "sample_type_abrv" INTO sample_type_abrv
    FROM "reference"."samples_type"
    WHERE "sample_type_id" = NEW.sample_type_id;

    IF NEW.parent_sample_id IS NULL THEN
        -- Case 1: Generating a new ROOT sample ID (e.g., S25Pprj_001)
        DECLARE
            sample_year text;
            project_abrv text;
            customer_abrv text;
        BEGIN
            sample_year := TO_CHAR(COALESCE(NEW.sample_creation_date, CURRENT_DATE), 'YY');
            
            IF NEW.project_id IS NOT NULL THEN
                SELECT "project_abrv" INTO project_abrv
                FROM "lims"."projects"
                WHERE "project_id" = NEW.project_id;
                id_prefix := sample_type_abrv || sample_year || project_abrv;
            ELSIF NEW.customer_id IS NOT NULL THEN
                SELECT "customer_abrv" INTO customer_abrv
                FROM "lims"."customers"
                WHERE "customer_id" = NEW.customer_id;
                id_prefix := sample_type_abrv || sample_year || customer_abrv;
            ELSE
                RAISE EXCEPTION 'Cannot generate root sample ID: Missing project_id and customer_id.';
            END IF;

            SELECT COALESCE(MAX(SUBSTRING("sample_id" FROM LENGTH(id_prefix) + 1)::INTEGER), 0)
            INTO next_serial
            FROM "lab"."root_samples"
            WHERE "sample_id" LIKE id_prefix || '%';

            NEW.sample_id := id_prefix || LPAD((next_serial + 1)::TEXT, 3, '0');
        END;
    ELSE
        -- Case 2: Generating a CHILD sample ID (e.g., S25Pprj_001_F1)
        -- First, validate that the parent_sample_id exists
        SELECT "sample_id" INTO parent_id_check
        FROM "lab"."root_samples"
        WHERE "sample_id" = NEW.parent_sample_id;
        
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Parent sample ID ''%'' not found. Cannot generate child ID.', NEW.parent_sample_id;
        END IF;

        id_prefix := NEW.parent_sample_id || '_' || sample_type_abrv;

        SELECT COALESCE(MAX(SUBSTRING("sample_id" FROM LENGTH(id_prefix) + 1)::INTEGER), 0)
        INTO next_serial
        FROM "lab"."root_samples"
        WHERE "sample_id" LIKE id_prefix || '%';

        NEW.sample_id := id_prefix || (next_serial + 1)::TEXT;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate dissection_id (e.g., sampleid_d9)
CREATE OR REPLACE FUNCTION "lab".generate_dissection_id()
RETURNS TRIGGER AS $$
DECLARE
    next_serial integer;
    id_prefix text;
BEGIN
    -- Prefix is parent sample_id + "_d"
    id_prefix := NEW.sample_id || '_d';

    SELECT COALESCE(MAX(SUBSTRING("dissection_id" FROM LENGTH(id_prefix) + 1)::INTEGER), 0)
    INTO next_serial
    FROM "lab"."dissections"
    WHERE "dissection_id" LIKE id_prefix || '%';

    NEW.dissection_id := id_prefix || (next_serial + 1)::TEXT;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate nanodrop ID (e.g., sampleid_n9)
CREATE OR REPLACE FUNCTION "lab".generate_nanodrop_id()
RETURNS TRIGGER AS $$
DECLARE
    next_serial integer;
    id_prefix text;
BEGIN
    -- The request was sampleid_n9, so the parent ID is sample_id
    id_prefix := NEW.sample_id || '_n';

    SELECT COALESCE(MAX(SUBSTRING("nanodrop_id" FROM LENGTH(id_prefix) + 1)::INTEGER), 0)
    INTO next_serial
    FROM "lab"."nanodrop"
    WHERE "nanodrop_id" LIKE id_prefix || '%';

    NEW.nanodrop_id := id_prefix || (next_serial + 1)::TEXT;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate qubit_id (e.g., sampleid_q9)
CREATE OR REPLACE FUNCTION "lab".generate_qubit_id()
RETURNS TRIGGER AS $$
DECLARE
    next_serial integer;
    id_prefix text;
BEGIN
    -- Prefix is parent sample_id + "_q"
    id_prefix := NEW.sample_id || '_q';

    SELECT COALESCE(MAX(SUBSTRING("qubit_id" FROM LENGTH(id_prefix) + 1)::INTEGER), 0)
    INTO next_serial
    FROM "lab"."qubit"
    WHERE "qubit_id" LIKE id_prefix || '%';

    NEW.qubit_id := id_prefix || (next_serial + 1)::TEXT;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate tapestation_id (e.g., sampleid_t9)
CREATE OR REPLACE FUNCTION "lab".generate_tapestation_id()
RETURNS TRIGGER AS $$
DECLARE
    next_serial integer;
    id_prefix text;
BEGIN
    -- Prefix is parent sample_id + "_t"
    id_prefix := NEW.sample_id || '_t';

    SELECT COALESCE(MAX(SUBSTRING("tapestation_id" FROM LENGTH(id_prefix) + 1)::INTEGER), 0)
    INTO next_serial
    FROM "lab"."tapestation"
    WHERE "tapestation_id" LIKE id_prefix || '%';

    NEW.tapestation_id := id_prefix || (next_serial + 1)::TEXT;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate gelelectrophoresis_id (e.g., sampleid_gel9)
CREATE OR REPLACE FUNCTION "lab".generate_gelelectrophoresis_id()
RETURNS TRIGGER AS $$
DECLARE
    next_serial integer;
    id_prefix text;
BEGIN
    -- Prefix is parent sample_id + "_gel"
    id_prefix := NEW.sample_id || '_gel';

    SELECT COALESCE(MAX(SUBSTRING("gelelectrophoresis_id" FROM LENGTH(id_prefix) + 1)::INTEGER), 0)
    INTO next_serial
    FROM "lab"."gelelectrophoresis"
    WHERE "gelelectrophoresis_id" LIKE id_prefix || '%';

    NEW.gelelectrophoresis_id := id_prefix || (next_serial + 1)::TEXT;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate qpcr ID (e.g., sampleid_qp99)
CREATE OR REPLACE FUNCTION "lab".generate_qpcr_id()
RETURNS TRIGGER AS $$
DECLARE
    next_serial integer;
    id_prefix text;
BEGIN
    -- Prefix is parent sample_id + "_qp"
    id_prefix := NEW.sample_id || '_qp';

    SELECT COALESCE(MAX(SUBSTRING("experiment_id" FROM LENGTH(id_prefix) + 1)::INTEGER), 0)
    INTO next_serial
    FROM "lab"."qpcr"
    WHERE "experiment_id" LIKE id_prefix || '%';

    NEW.experiment_id := id_prefix || LPAD((next_serial + 1)::TEXT, 2, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate sequencing_run_id (e.g., RS25_999)
CREATE OR REPLACE FUNCTION "lab".generate_sequencing_run_id()
RETURNS TRIGGER AS $$
DECLARE
    current_year text;
    next_serial integer;
    id_prefix text;
BEGIN
    current_year := TO_CHAR(COALESCE(NEW.experiment_date, CURRENT_DATE), 'YY');
    id_prefix := 'RS' || current_year || '_';

    SELECT COALESCE(MAX(SUBSTRING("sequencing_run_id" FROM LENGTH(id_prefix) + 1)::INTEGER), 0)
    INTO next_serial
    FROM "lab"."sequencing_run"
    WHERE "sequencing_run_id" LIKE id_prefix || '%';

    NEW.sequencing_run_id := id_prefix || LPAD((next_serial + 1)::TEXT, 3, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate Seq_dataset ID (e.g., sampleid_RS4)
CREATE OR REPLACE FUNCTION "lab".generate_seq_dataset_id()
RETURNS TRIGGER AS $$
DECLARE
    next_serial integer;
    id_prefix text;
BEGIN
    -- Prefix is parent sample_id + "_RS"
    id_prefix := NEW.sample_id || '_RS';

    SELECT COALESCE(MAX(SUBSTRING("data_seq_id" FROM LENGTH(id_prefix) + 1)::INTEGER), 0)
    INTO next_serial
    FROM "lab"."Seq_dataset"
    WHERE "data_seq_id" LIKE id_prefix || '%';

    NEW.data_seq_id := id_prefix || (next_serial + 1)::TEXT;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate dataset_id (e.g., Z25[sampleid]_999)
CREATE OR REPLACE FUNCTION "lab".generate_dataset_id()
RETURNS TRIGGER AS $$
DECLARE
    dataset_year text;
    next_serial integer;
    id_prefix text;
BEGIN
    dataset_year := TO_CHAR(COALESCE(NEW.reception_date, CURRENT_DATE), 'YY');
    -- The requested format uses sample_id as part of the prefix, but that might be long.
    -- I will use the year and a sample-derived part to keep it clean.
    -- Let's use the first 5 characters of the sample_id for brevity.
    id_prefix := 'Z' || dataset_year || SUBSTRING(NEW.sample_id FROM 1 FOR 5) || '_';

    SELECT COALESCE(MAX(SUBSTRING("dataset_id" FROM LENGTH(id_prefix) + 1)::INTEGER), 0)
    INTO next_serial
    FROM "lab"."datasets"
    WHERE "dataset_id" LIKE id_prefix || '%';

    NEW.dataset_id := id_prefix || LPAD((next_serial + 1)::TEXT, 3, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate pipeline_id (e.g., BI25_p999)
CREATE OR REPLACE FUNCTION "bioinformatics".generate_pipeline_id()
RETURNS TRIGGER AS $$
DECLARE
    current_year text;
    next_serial integer;
    id_prefix text;
BEGIN
    current_year := TO_CHAR(CURRENT_DATE, 'YY');
    id_prefix := 'BI' || current_year || '_p';

    SELECT COALESCE(MAX(SUBSTRING("pipeline_id" FROM LENGTH(id_prefix) + 1)::INTEGER), 0)
    INTO next_serial
    FROM "bioinformatics"."analysis_pipelines"
    WHERE "pipeline_id" LIKE id_prefix || '%';

    NEW.pipeline_id := id_prefix || LPAD((next_serial + 1)::TEXT, 3, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate run_id (e.g., BI25_ar999)
CREATE OR REPLACE FUNCTION "bioinformatics".generate_analysis_run_id()
RETURNS TRIGGER AS $$
DECLARE
    current_year text;
    next_serial integer;
    id_prefix text;
BEGIN
    current_year := TO_CHAR(COALESCE(NEW.experiment_date, CURRENT_DATE), 'YY');
    id_prefix := 'BI' || current_year || '_ar';

    SELECT COALESCE(MAX(SUBSTRING("run_id" FROM LENGTH(id_prefix) + 1)::INTEGER), 0)
    INTO next_serial
    FROM "bioinformatics"."analysis_runs"
    WHERE "run_id" LIKE id_prefix || '%';

    NEW.run_id := id_prefix || LPAD((next_serial + 1)::TEXT, 3, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate assignment_id (e.g., BI25_sampleid_999)
CREATE OR REPLACE FUNCTION "bioinformatics".generate_edna_assignment_id()
RETURNS TRIGGER AS $$
DECLARE
    current_year text;
    next_serial integer;
    id_prefix text;
BEGIN
    current_year := TO_CHAR(COALESCE(NEW.sample_creation_date, CURRENT_DATE), 'YY');
    id_prefix := 'BI' || current_year || '_' || NEW.sample_id || '_';

    SELECT COALESCE(MAX(SUBSTRING("assignment_id" FROM LENGTH(id_prefix) + 1)::INTEGER), 0)
    INTO next_serial
    FROM "bioinformatics"."edna_assignments"
    WHERE "assignment_id" LIKE id_prefix || '%';

    NEW.assignment_id := id_prefix || LPAD((next_serial + 1)::TEXT, 3, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ======================================================================
-- F06. COORDINATE TRANSFORMATION FUNCTION
-- ======================================================================
-- Function to transform coordinates to EPSG:4326 (WGS84)
CREATE OR REPLACE FUNCTION "projects".transform_coordinates_to_wgs84(
    p_easting numeric,
    p_northing numeric,
    p_latitude numeric,
    p_longitude numeric,
    p_original_srid integer
)
RETURNS geometry(Point, 4326) AS $$
DECLARE
    temp_geom geometry;
BEGIN
    -- Case 1: Coordinates are already in WGS84 (SRID 4326)
    IF p_original_srid = 4326 AND p_longitude IS NOT NULL AND p_latitude IS NOT NULL THEN
        temp_geom := ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326);
    -- Case 2: Coordinates are in another SRID (Easting/Northing)
    ELSIF p_easting IS NOT NULL AND p_northing IS NOT NULL AND p_original_srid IS NOT NULL AND p_original_srid != 4326 THEN
        BEGIN
            temp_geom := ST_Transform(ST_SetSRID(ST_MakePoint(p_easting, p_northing), p_original_srid), 4326);
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING 'SRID % is not defined or transformation failed for coordinates (%, %). Returning NULL.', p_original_srid, p_easting, p_northing;
                RETURN NULL;
        END;
    ELSE
        -- No valid coordinate set found
        RAISE WARNING 'Incomplete or invalid coordinate data for transformation. Returning NULL.';
        RETURN NULL;
    END IF;

    -- Final validation for valid Point geometry
    IF temp_geom IS NOT NULL AND ST_GeometryType(temp_geom) = 'ST_Point' THEN
        RETURN temp_geom;
    ELSE
        RAISE WARNING 'Transformed geometry is not a valid POINT type. Returning NULL.';
        RETURN NULL;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Trigger function to populate geom_4326 before insert/update
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

-- ======================================================================
-- F07. FULL-TEXT SEARCH UPDATE FUNCTIONS
-- ======================================================================
-- Functions to update TSVECTOR columns for full-text search
CREATE OR REPLACE FUNCTION "lims".update_personal_search_vector_func()
RETURNS TRIGGER AS $$
BEGIN
    NEW.personal_search_vector =
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.full_name, '')) ||
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.mail, '')) ||
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.notes, ''));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "lims".update_contacts_search_vector_func()
RETURNS TRIGGER AS $$
BEGIN
    NEW.contacts_search_vector =
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.full_name, '')) ||
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.organization, '')) ||
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.mail, '')) ||
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.notes, ''));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "lims".update_customer_search_vector_func()
RETURNS TRIGGER AS $$
BEGIN
    NEW.customer_search_vector =
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.customer_name, '')) ||
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.customer_abrv, '')) ||
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.notes, ''));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "lims".update_project_search_vector_func()
RETURNS TRIGGER AS $$
BEGIN
    NEW.project_search_vector =
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.project_id, '')) ||
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.title, '')) ||
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.description, '')) ||
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.notes, ''));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "lims".update_sop_search_vector_func()
RETURNS TRIGGER AS $$
BEGIN
    NEW.sop_search_vector =
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.sop_id_origin, '')) ||
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.title, '')) ||
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.sop_protocol, '')) ||
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.notes, ''));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "lims".update_equipment_search_vector_func()
RETURNS TRIGGER AS $$
BEGIN
    NEW.equipment_search_vector =
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.equipment_name, '')) ||
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.lot, '')) ||
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.notes, ''));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "lims".update_supplier_search_vector_func()
RETURNS TRIGGER AS $$
BEGIN
    NEW.supplier_search_vector =
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.supplier_name, '')) ||
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.contact_person, '')) ||
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.notes, ''));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "lims".update_inventory_search_vector_func()
RETURNS TRIGGER AS $$
BEGIN
    NEW.inventory_search_vector =
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.item_name, '')) ||
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.notes, ''));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "lims".update_reagent_search_vector_func()
RETURNS TRIGGER AS $$
BEGIN
    NEW.reagent_search_vector =
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.reagent_complete_name, '')) ||
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.lot, '')) ||
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.notes, ''));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "lims".update_publication_search_vector_func()
RETURNS TRIGGER AS $$
BEGIN
    NEW.publication_search_vector =
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.title, '')) ||
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.journal, '')) ||
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

CREATE OR REPLACE FUNCTION "lab".update_sample_search_vector_func()
RETURNS TRIGGER AS $$
BEGIN
    NEW.sample_search_vector =
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.external_name, '')) ||
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.notes, ''));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "projects".update_fishing_data_search_vector_func()
RETURNS TRIGGER AS $$
BEGIN
    NEW.fishing_data_search_vector =
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.location_description, '')) ||
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.water_body_name, '')) ||
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.fishing_method, '')) ||
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.notes, '')) ||
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.original_data_jsonb::text, ''));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "projects".update_fish_catch_search_vector_func()
RETURNS TRIGGER AS $$
BEGIN
    NEW.fish_catch_search_vector =
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.scientific_name_raw, '')) ||
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.german_name_raw, '')) ||
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.notes, ''));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "projects".update_mail_search_vector_func()
RETURNS TRIGGER AS $$
BEGIN
    NEW.mail_search_vector =
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.subject, '')) ||
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.body, '')) ||
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.notes, ''));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "projects".update_conversation_search_vector_func()
RETURNS TRIGGER AS $$
BEGIN
    NEW.conversation_search_vector =
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.topic, '')) ||
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.notes, ''));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "projects".update_chat_message_search_vector_func()
RETURNS TRIGGER AS $$
BEGIN
    NEW.chat_message_search_vector =
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.message_text, '')) ||
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.notes, ''));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "lab".update_storage_search_vector_func()
RETURNS TRIGGER AS $$
BEGIN
    NEW.storage_search_vector =
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.freezer, '')) ||
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.box, '')) ||
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.address, '')) ||
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.notes, ''));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "bioinformatics".update_pipeline_search_vector_func()
RETURNS TRIGGER AS $$
BEGIN
    NEW.pipeline_search_vector =
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.pipeline_name, '')) ||
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.version, '')) ||
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.notes, ''));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ======================================================================
-- F08. LTREE PATH UPDATE FUNCTION
-- ======================================================================
-- Function to maintain the ltree path for hierarchical data.
CREATE OR REPLACE FUNCTION "reference".update_taxon_ltree_paths()
RETURNS TRIGGER AS $$
BEGIN
    -- Update the path for all affected rows, starting from the root.
    UPDATE "reference"."taxon" AS t
    SET path = subquery.new_path
    FROM (
        WITH RECURSIVE taxon_paths AS (
            -- Base case: The roots of the hierarchy
            SELECT
                taxon_id,
                taxon_id::ltree AS new_path
            FROM
                "reference"."taxon"
            WHERE
                taxon_parent IS NULL

            UNION ALL

            -- Recursive step: Find children and build their paths
            SELECT
                t.taxon_id,
                tp.new_path || t.taxon_id::ltree
            FROM
                taxon_paths tp
            JOIN
                "reference"."taxon" t ON t.taxon_parent = tp.taxon_id
        )
        SELECT
            taxon_id,
            new_path
        FROM
            taxon_paths
    ) AS subquery
    WHERE
        t.taxon_id = subquery.taxon_id;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;


-- ======================================================================
-- F09. RLS POLICY FUNCTION
-- ======================================================================
CREATE OR REPLACE FUNCTION "lims".is_member_of_project(p_project_id text)
RETURNS BOOLEAN AS $$
DECLARE
    current_person_id text := current_setting('lims.current_person_id', true);
BEGIN
    IF current_person_id IS NULL THEN
        RETURN FALSE;
    END IF;

    -- Check if the user is the Principal Investigator (PI) or a project member
    RETURN EXISTS (
        SELECT 1 FROM "lims"."projects" WHERE project_id = p_project_id AND pi_person_id = current_person_id
    ) OR EXISTS (
        SELECT 1 FROM "lims"."project_persons" WHERE project_id = p_project_id AND person_id = current_person_id
    );
END;
$$ LANGUAGE plpgsql STABLE;


-- ======================================================================
-- 1. TRIGGERS
-- ======================================================================
-- Triggers for Partitioning
-- The second argument passed to create_yearly_partition is the name of the date column to use for partitioning.
CREATE TRIGGER trg_create_experiments_partition BEFORE INSERT ON "lab"."experiments" FOR EACH ROW EXECUTE FUNCTION create_yearly_partition('experiment_date');
CREATE TRIGGER trg_create_sampling_partition BEFORE INSERT ON "lab"."sampling" FOR EACH ROW EXECUTE FUNCTION create_yearly_partition('sampling_date');
CREATE TRIGGER trg_create_fishing_partition BEFORE INSERT ON "lab"."fishing" FOR EACH ROW EXECUTE FUNCTION create_yearly_partition('sampling_date');
CREATE TRIGGER trg_create_individual_catch_partition BEFORE INSERT ON "lab"."individual_catch_catch" FOR EACH ROW EXECUTE FUNCTION create_yearly_partition('sampling_date');
CREATE TRIGGER trg_create_sampling_abiotic_data_partition BEFORE INSERT ON "lab"."sampling_abiotic_data" FOR EACH ROW EXECUTE FUNCTION create_yearly_partition('sampling_date');
CREATE TRIGGER trg_create_root_samples_partition BEFORE INSERT ON "lab"."root_samples" FOR EACH ROW EXECUTE FUNCTION create_yearly_partition('sample_creation_date');
CREATE TRIGGER trg_create_fish_partition BEFORE INSERT ON "lab"."fish" FOR EACH ROW EXECUTE FUNCTION create_yearly_partition('sample_creation_date');
CREATE TRIGGER trg_create_tissue_partition BEFORE INSERT ON "lab"."tissue" FOR EACH ROW EXECUTE FUNCTION create_yearly_partition('sample_creation_date');
CREATE TRIGGER trg_create_otoliths_partition BEFORE INSERT ON "lab"."otoliths" FOR EACH ROW EXECUTE FUNCTION create_yearly_partition('sample_creation_date');
CREATE TRIGGER trg_create_dna_partition BEFORE INSERT ON "lab"."dna" FOR EACH ROW EXECUTE FUNCTION create_yearly_partition('sample_creation_date');
CREATE TRIGGER trg_create_rna_partition BEFORE INSERT ON "lab"."rna" FOR EACH ROW EXECUTE FUNCTION create_yearly_partition('sample_creation_date');
CREATE TRIGGER trg_create_sediments_partition BEFORE INSERT ON "lab"."sediments" FOR EACH ROW EXECUTE FUNCTION create_yearly_partition('sample_creation_date');
CREATE TRIGGER trg_create_water_partition BEFORE INSERT ON "lab"."water" FOR EACH ROW EXECUTE FUNCTION create_yearly_partition('sample_creation_date');
CREATE TRIGGER trg_create_pcr_partition BEFORE INSERT ON "lab"."pcr" FOR EACH ROW EXECUTE FUNCTION create_yearly_partition('sample_creation_date');
CREATE TRIGGER trg_create_dissections_partition BEFORE INSERT ON "lab"."dissections" FOR EACH ROW EXECUTE FUNCTION create_yearly_partition('experiment_date');
CREATE TRIGGER trg_create_nanodrop_partition BEFORE INSERT ON "lab"."nanodrop" FOR EACH ROW EXECUTE FUNCTION create_yearly_partition('experiment_date');
CREATE TRIGGER trg_create_qubit_partition BEFORE INSERT ON "lab"."qubit" FOR EACH ROW EXECUTE FUNCTION create_yearly_partition('experiment_date');
CREATE TRIGGER trg_create_tapestation_partition BEFORE INSERT ON "lab"."tapestation" FOR EACH ROW EXECUTE FUNCTION create_yearly_partition('experiment_date');
CREATE TRIGGER trg_create_gelelectrophoresis_partition BEFORE INSERT ON "lab"."gelelectrophoresis" FOR EACH ROW EXECUTE FUNCTION create_yearly_partition('experiment_date');
CREATE TRIGGER trg_create_qpcr_partition BEFORE INSERT ON "lab"."qpcr" FOR EACH ROW EXECUTE FUNCTION create_yearly_partition('experiment_date');
CREATE TRIGGER trg_create_library_partition BEFORE INSERT ON "lab"."library" FOR EACH ROW EXECUTE FUNCTION create_yearly_partition('experiment_date');
CREATE TRIGGER trg_create_sequencing_run_partition BEFORE INSERT ON "lab"."sequencing_run" FOR EACH ROW EXECUTE FUNCTION create_yearly_partition('experiment_date');
CREATE TRIGGER trg_create_seq_dataset_partition BEFORE INSERT ON "lab"."Seq_dataset" FOR EACH ROW EXECUTE FUNCTION create_yearly_partition('experiment_date');
CREATE TRIGGER trg_create_datasets_partition BEFORE INSERT ON "lab"."datasets" FOR EACH ROW EXECUTE FUNCTION create_yearly_partition('reception_date');
CREATE TRIGGER trg_create_analysis_runs_partition BEFORE INSERT ON "bioinformatics"."analysis_runs" FOR EACH ROW EXECUTE FUNCTION create_yearly_partition('experiment_date');
CREATE TRIGGER trg_create_wanderfische_fishingdata_partition BEFORE INSERT ON "projects"."ProjectWanderfische_FishingData" FOR EACH ROW EXECUTE FUNCTION create_yearly_partition('record_date');

-- Triggers for populating date columns from parent tables before partitioning
CREATE TRIGGER trg_populate_experiments_projects_date BEFORE INSERT ON "lab"."experiments_projects" FOR EACH ROW EXECUTE FUNCTION "lab".populate_date_from_experiment();
CREATE TRIGGER trg_populate_experiments_samples_date BEFORE INSERT ON "lab"."experiments_samples" FOR EACH ROW EXECUTE FUNCTION "lab".populate_date_from_experiment();
CREATE TRIGGER trg_populate_protocol_runs_date BEFORE INSERT ON "lab"."protocol_runs" FOR EACH ROW EXECUTE FUNCTION "lab".populate_date_from_experiment();
CREATE TRIGGER trg_populate_fishing_date BEFORE INSERT ON "lab"."fishing" FOR EACH ROW EXECUTE FUNCTION "lab".populate_date_from_sampling();
CREATE TRIGGER trg_populate_individual_catch_date BEFORE INSERT ON "lab"."individual_catch_catch" FOR EACH ROW EXECUTE FUNCTION "lab".populate_date_from_sampling();
CREATE TRIGGER trg_populate_sampling_abiotic_data_date BEFORE INSERT ON "lab"."sampling_abiotic_data" FOR EACH ROW EXECUTE FUNCTION "lab".populate_date_from_sampling();
CREATE TRIGGER trg_populate_fish_date BEFORE INSERT ON "lab"."fish" FOR EACH ROW EXECUTE FUNCTION "lab".populate_date_from_root_sample();
CREATE TRIGGER trg_populate_tissue_date BEFORE INSERT ON "lab"."tissue" FOR EACH ROW EXECUTE FUNCTION "lab".populate_date_from_root_sample();
CREATE TRIGGER trg_populate_otoliths_date BEFORE INSERT ON "lab"."otoliths" FOR EACH ROW EXECUTE FUNCTION "lab".populate_date_from_root_sample();
CREATE TRIGGER trg_populate_dna_date BEFORE INSERT ON "lab"."dna" FOR EACH ROW EXECUTE FUNCTION "lab".populate_date_from_root_sample();
CREATE TRIGGER trg_populate_rna_date BEFORE INSERT ON "lab"."rna" FOR EACH ROW EXECUTE FUNCTION "lab".populate_date_from_root_sample();
CREATE TRIGGER trg_populate_sediments_date BEFORE INSERT ON "lab"."sediments" FOR EACH ROW EXECUTE FUNCTION "lab".populate_date_from_root_sample();
CREATE TRIGGER trg_populate_water_date BEFORE INSERT ON "lab"."water" FOR EACH ROW EXECUTE FUNCTION "lab".populate_date_from_root_sample();
CREATE TRIGGER trg_populate_pcr_date BEFORE INSERT ON "lab"."pcr" FOR EACH ROW EXECUTE FUNCTION "lab".populate_date_from_root_sample();
CREATE TRIGGER trg_populate_seq_dataset_date BEFORE INSERT ON "lab"."Seq_dataset" FOR EACH ROW EXECUTE FUNCTION "lab".populate_date_from_experiment();
CREATE TRIGGER trg_populate_analysis_runs_date BEFORE INSERT ON "bioinformatics"."analysis_runs" FOR EACH ROW EXECUTE FUNCTION "bioinformatics".populate_date_from_sequencing();

-- Triggers for automatic ID generation
CREATE TRIGGER trg_generate_sampling_id BEFORE INSERT ON "lab"."sampling" FOR EACH ROW EXECUTE FUNCTION "lab".generate_sampling_id();
CREATE TRIGGER trg_generate_fishing_id BEFORE INSERT ON "lab"."fishing" FOR EACH ROW EXECUTE FUNCTION "lab".generate_fishing_id();
CREATE TRIGGER trg_generate_individual_catch_id BEFORE INSERT ON "lab"."individual_catch_catch" FOR EACH ROW EXECUTE FUNCTION "lab".generate_individual_catch_id();
CREATE TRIGGER trg_generate_root_sample_id BEFORE INSERT ON "lab"."root_samples" FOR EACH ROW EXECUTE FUNCTION "lab".generate_sample_id();
CREATE TRIGGER trg_generate_dissection_id BEFORE INSERT ON "lab"."dissections" FOR EACH ROW EXECUTE FUNCTION "lab".generate_dissection_id();
CREATE TRIGGER trg_generate_nanodrop_id BEFORE INSERT ON "lab"."nanodrop" FOR EACH ROW EXECUTE FUNCTION "lab".generate_nanodrop_id();
CREATE TRIGGER trg_generate_qubit_id BEFORE INSERT ON "lab"."qubit" FOR EACH ROW EXECUTE FUNCTION "lab".generate_qubit_id();
CREATE TRIGGER trg_generate_tapestation_id BEFORE INSERT ON "lab"."tapestation" FOR EACH ROW EXECUTE FUNCTION "lab".generate_tapestation_id();
CREATE TRIGGER trg_generate_gelelectrophoresis_id BEFORE INSERT ON "lab"."gelelectrophoresis" FOR EACH ROW EXECUTE FUNCTION "lab".generate_gelelectrophoresis_id();
CREATE TRIGGER trg_generate_qpcr_id BEFORE INSERT ON "lab"."qpcr" FOR EACH ROW EXECUTE FUNCTION "lab".generate_qpcr_id();
CREATE TRIGGER trg_generate_sequencing_run_id BEFORE INSERT ON "lab"."sequencing_run" FOR EACH ROW EXECUTE FUNCTION "lab".generate_sequencing_run_id();
CREATE TRIGGER trg_generate_seq_dataset_id BEFORE INSERT ON "lab"."Seq_dataset" FOR EACH ROW EXECUTE FUNCTION "lab".generate_seq_dataset_id();
CREATE TRIGGER trg_generate_dataset_id BEFORE INSERT ON "lab"."datasets" FOR EACH ROW EXECUTE FUNCTION "lab".generate_dataset_id();
CREATE TRIGGER trg_generate_pipeline_id BEFORE INSERT ON "bioinformatics"."analysis_pipelines" FOR EACH ROW EXECUTE FUNCTION "bioinformatics".generate_pipeline_id();
CREATE TRIGGER trg_generate_analysis_run_id BEFORE INSERT ON "bioinformatics"."analysis_runs" FOR EACH ROW EXECUTE FUNCTION "bioinformatics".generate_analysis_run_id();
CREATE TRIGGER trg_generate_edna_assignment_id BEFORE INSERT ON "bioinformatics"."edna_assignments" FOR EACH ROW EXECUTE FUNCTION "bioinformatics".generate_edna_assignment_id();

-- Trigger for coordinate transformation
CREATE TRIGGER trg_populate_geom_4326 BEFORE INSERT OR UPDATE ON "projects"."ProjectWanderfische_FishingData" FOR EACH ROW EXECUTE FUNCTION "projects".populate_fishing_geom_4326();

-- Triggers for status updates
CREATE TRIGGER trg_update_status_dissection AFTER INSERT ON "lab"."dissections" FOR EACH ROW EXECUTE FUNCTION "lab".update_sample_status('Dissection');
CREATE TRIGGER trg_update_status_nanodrop AFTER INSERT ON "lab"."nanodrop" FOR EACH ROW EXECUTE FUNCTION "lab".update_sample_status('Nanodrop QC');
CREATE TRIGGER trg_update_status_qubit AFTER INSERT ON "lab"."qubit" FOR EACH ROW EXECUTE FUNCTION "lab".update_sample_status('Qubit QC');
CREATE TRIGGER trg_update_status_tapestation AFTER INSERT ON "lab"."tapestation" FOR EACH ROW EXECUTE FUNCTION "lab".update_sample_status('Tapestation QC');
CREATE TRIGGER trg_update_status_pcr AFTER INSERT ON "lab"."pcr" FOR EACH ROW EXECUTE FUNCTION "lab".update_sample_status('PCR Done');
CREATE TRIGGER trg_update_status_qpcr AFTER INSERT ON "lab"."qpcr" FOR EACH ROW EXECUTE FUNCTION "lab".update_sample_status('qPCR Done');
CREATE TRIGGER trg_update_status_library AFTER INSERT ON "lab"."library" FOR EACH ROW EXECUTE FUNCTION "lab".update_sample_status('Library Prep');
CREATE TRIGGER trg_update_status_sequencing_run AFTER INSERT ON "lab"."sequencing_run" FOR EACH ROW EXECUTE FUNCTION "lab".update_sample_status('Sequencing Done');
CREATE TRIGGER trg_update_status_analysis_runs AFTER INSERT ON "bioinformatics"."analysis_runs" FOR EACH ROW EXECUTE FUNCTION "lab".update_sample_status('Bioinformatics Done');

-- Triggers for Audit Logging
CREATE TRIGGER audit_trigger_personal AFTER INSERT OR UPDATE OR DELETE ON "lims"."personal" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_status AFTER INSERT OR UPDATE OR DELETE ON "reference"."status" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_room AFTER INSERT OR UPDATE OR DELETE ON "reference"."room" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_vessel AFTER INSERT OR UPDATE OR DELETE ON "reference"."vessel" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_region AFTER INSERT OR UPDATE OR DELETE ON "reference"."region" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_ecosystem AFTER INSERT OR UPDATE OR DELETE ON "reference"."ecosystem" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_category AFTER INSERT OR UPDATE OR DELETE ON "reference"."category" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_samples_type AFTER INSERT OR UPDATE OR DELETE ON "reference"."samples_type" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_gene AFTER INSERT OR UPDATE OR DELETE ON "reference"."gene" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_taxon AFTER INSERT OR UPDATE OR DELETE ON "reference"."taxon" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_units AFTER INSERT OR UPDATE OR DELETE ON "reference"."units" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_ref_dbs AFTER INSERT OR UPDATE OR DELETE ON "reference"."reference_databases" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_ext_contacts AFTER INSERT OR UPDATE OR DELETE ON "lims"."external_contacts" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_customers AFTER INSERT OR UPDATE OR DELETE ON "lims"."customers" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_projects AFTER INSERT OR UPDATE OR DELETE ON "lims"."projects" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_proj_persons AFTER INSERT OR UPDATE OR DELETE ON "lims"."project_persons" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_cruises AFTER INSERT OR UPDATE OR DELETE ON "lims"."cruises" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_batch AFTER INSERT OR UPDATE OR DELETE ON "lims"."batch" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_batch_steps AFTER INSERT OR UPDATE OR DELETE ON "lims"."batch_steps" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_permits AFTER INSERT OR UPDATE OR DELETE ON "lims"."permits" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_primers AFTER INSERT OR UPDATE OR DELETE ON "lims"."primers" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_sop AFTER INSERT OR UPDATE OR DELETE ON "lims"."sop" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_equipment AFTER INSERT OR UPDATE OR DELETE ON "lims"."equipment" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_suppliers AFTER INSERT OR UPDATE OR DELETE ON "lims"."suppliers" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_inv_items AFTER INSERT OR UPDATE OR DELETE ON "lims"."inventory_items" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_orders AFTER INSERT OR UPDATE OR DELETE ON "lims"."orders" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_reagents AFTER INSERT OR UPDATE OR DELETE ON "lims"."reagents" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_pub_type AFTER INSERT OR UPDATE OR DELETE ON "lims"."publication_type" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_publications AFTER INSERT OR UPDATE OR DELETE ON "lims"."publications" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_lab_storage AFTER INSERT OR UPDATE OR DELETE ON "lab"."storage" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_experiments AFTER INSERT OR UPDATE OR DELETE ON "lab"."experiments" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_exp_projects AFTER INSERT OR UPDATE OR DELETE ON "lab"."experiments_projects" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_exp_samples AFTER INSERT OR UPDATE OR DELETE ON "lab"."experiments_samples" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_protocol_runs AFTER INSERT OR UPDATE OR DELETE ON "lab"."protocol_runs" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_sampling AFTER INSERT OR UPDATE OR DELETE ON "lab"."sampling" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_fishing AFTER INSERT OR UPDATE OR DELETE ON "lab"."fishing" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_catch AFTER INSERT OR UPDATE OR DELETE ON "lab"."individual_catch_catch" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_abiotic_data AFTER INSERT OR UPDATE OR DELETE ON "lab"."sampling_abiotic_data" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_storage_log AFTER INSERT OR UPDATE OR DELETE ON "lab"."storage_log" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_root_samples AFTER INSERT OR UPDATE OR DELETE ON "lab"."root_samples" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_fish AFTER INSERT OR UPDATE OR DELETE ON "lab"."fish" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_tissue AFTER INSERT OR UPDATE OR DELETE ON "lab"."tissue" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_otoliths AFTER INSERT OR UPDATE OR DELETE ON "lab"."otoliths" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_dna AFTER INSERT OR UPDATE OR DELETE ON "lab"."dna" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_rna AFTER INSERT OR UPDATE OR DELETE ON "lab"."rna" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_sediments AFTER INSERT OR UPDATE OR DELETE ON "lab"."sediments" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_water AFTER INSERT OR UPDATE OR DELETE ON "lab"."water" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_pcr AFTER INSERT OR UPDATE OR DELETE ON "lab"."pcr" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_dissections AFTER INSERT OR UPDATE OR DELETE ON "lab"."dissections" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_nanodrop AFTER INSERT OR UPDATE OR DELETE ON "lab"."nanodrop" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_qubit AFTER INSERT OR UPDATE OR DELETE ON "lab"."qubit" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_tapestation AFTER INSERT OR UPDATE OR DELETE ON "lab"."tapestation" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_gelelectrophoresis AFTER INSERT OR UPDATE OR DELETE ON "lab"."gelelectrophoresis" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_qpcr AFTER INSERT OR UPDATE OR DELETE ON "lab"."qpcr" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_library AFTER INSERT OR UPDATE OR DELETE ON "lab"."library" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_seq_run AFTER INSERT OR UPDATE OR DELETE ON "lab"."sequencing_run" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_seq_dataset AFTER INSERT OR UPDATE OR DELETE ON "lab"."Seq_dataset" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_datasets AFTER INSERT OR UPDATE OR DELETE ON "lab"."datasets" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_pipelines AFTER INSERT OR UPDATE OR DELETE ON "bioinformatics"."analysis_pipelines" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_runs AFTER INSERT OR UPDATE OR DELETE ON "bioinformatics"."analysis_runs" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_assignments AFTER INSERT OR UPDATE OR DELETE ON "bioinformatics"."edna_assignments" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_proj_fishingdata AFTER INSERT OR UPDATE OR DELETE ON "projects"."ProjectWanderfische_FishingData" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_proj_fishcatch AFTER INSERT OR UPDATE OR DELETE ON "projects"."ProjectWanderfische_FishCatch" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_proj_mail AFTER INSERT OR UPDATE OR DELETE ON "projects"."ProjectWanderfische_Mail" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_proj_conversation AFTER INSERT OR UPDATE OR DELETE ON "projects"."ProjectWanderfische_Conversation" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_proj_chatmessage AFTER INSERT OR UPDATE OR DELETE ON "projects"."ProjectWanderfische_ChatMessage" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();

-- Triggers for Full-Text Search
CREATE TRIGGER trg_update_personal_search BEFORE INSERT OR UPDATE ON "lims"."personal" FOR EACH ROW EXECUTE FUNCTION "lims".update_personal_search_vector_func();
CREATE TRIGGER trg_update_contacts_search BEFORE INSERT OR UPDATE ON "lims"."external_contacts" FOR EACH ROW EXECUTE FUNCTION "lims".update_contacts_search_vector_func();
CREATE TRIGGER trg_update_customer_search BEFORE INSERT OR UPDATE ON "lims"."customers" FOR EACH ROW EXECUTE FUNCTION "lims".update_customer_search_vector_func();
CREATE TRIGGER trg_update_project_search BEFORE INSERT OR UPDATE ON "lims"."projects" FOR EACH ROW EXECUTE FUNCTION "lims".update_project_search_vector_func();
CREATE TRIGGER trg_update_sop_search BEFORE INSERT OR UPDATE ON "lims"."sop" FOR EACH ROW EXECUTE FUNCTION "lims".update_sop_search_vector_func();
CREATE TRIGGER trg_update_equipment_search BEFORE INSERT OR UPDATE ON "lims"."equipment" FOR EACH ROW EXECUTE FUNCTION "lims".update_equipment_search_vector_func();
CREATE TRIGGER trg_update_supplier_search BEFORE INSERT OR UPDATE ON "lims"."suppliers" FOR EACH ROW EXECUTE FUNCTION "lims".update_supplier_search_vector_func();
CREATE TRIGGER trg_update_inventory_search BEFORE INSERT OR UPDATE ON "lims"."inventory_items" FOR EACH ROW EXECUTE FUNCTION "lims".update_inventory_search_vector_func();
CREATE TRIGGER trg_update_reagent_search BEFORE INSERT OR UPDATE ON "lims"."reagents" FOR EACH ROW EXECUTE FUNCTION "lims".update_reagent_search_vector_func();
CREATE TRIGGER trg_update_publication_search BEFORE INSERT OR UPDATE ON "lims"."publications" FOR EACH ROW EXECUTE FUNCTION "lims".update_publication_search_vector_func();
CREATE TRIGGER trg_update_experiment_search BEFORE INSERT OR UPDATE ON "lab"."experiments" FOR EACH ROW EXECUTE FUNCTION "lab".update_experiment_search_vector_func();
CREATE TRIGGER trg_update_sample_search BEFORE INSERT OR UPDATE ON "lab"."root_samples" FOR EACH ROW EXECUTE FUNCTION "lab".update_sample_search_vector_func();
CREATE TRIGGER trg_update_fishing_data_search BEFORE INSERT OR UPDATE ON "projects"."ProjectWanderfische_FishingData" FOR EACH ROW EXECUTE FUNCTION "projects".update_fishing_data_search_vector_func();
CREATE TRIGGER trg_update_fish_catch_search BEFORE INSERT OR UPDATE ON "projects"."ProjectWanderfische_FishCatch" FOR EACH ROW EXECUTE FUNCTION "projects".update_fish_catch_search_vector_func();
CREATE TRIGGER trg_update_mail_search BEFORE INSERT OR UPDATE ON "projects"."ProjectWanderfische_Mail" FOR EACH ROW EXECUTE FUNCTION "projects".update_mail_search_vector_func();
CREATE TRIGGER trg_update_conversation_search BEFORE INSERT OR UPDATE ON "projects"."ProjectWanderfische_Conversation" FOR EACH ROW EXECUTE FUNCTION "projects".update_conversation_search_vector_func();
CREATE TRIGGER trg_update_chat_message_search BEFORE INSERT OR UPDATE ON "projects"."ProjectWanderfische_ChatMessage" FOR EACH ROW EXECUTE FUNCTION "projects".update_chat_message_search_vector_func();
CREATE TRIGGER trg_update_storage_search BEFORE INSERT OR UPDATE ON "lab"."storage" FOR EACH ROW EXECUTE FUNCTION "lab".update_storage_search_vector_func();
CREATE TRIGGER trg_update_pipeline_search BEFORE INSERT OR UPDATE ON "bioinformatics"."analysis_pipelines" FOR EACH ROW EXECUTE FUNCTION "bioinformatics".update_pipeline_search_vector_func();

-- Trigger for ltree path update
CREATE TRIGGER trg_update_taxon_path AFTER INSERT OR UPDATE ON "reference"."taxon" FOR EACH STATEMENT EXECUTE FUNCTION "reference".update_taxon_ltree_paths();

-- Ensure the trigger is set to use the new function.
-- If the old trigger exists, you may need to drop and re-create it.
CREATE TRIGGER trg_populate_dates_for_root_sample BEFORE INSERT ON "lab"."root_samples" FOR EACH ROW EXECUTE FUNCTION "lab".populate_dates_for_root_sample();

-- ======================================================================
-- 2. INDEXES
-- ======================================================================
-- Reference Schema Indexes
CREATE INDEX IF NOT EXISTS idx_personal_full_name ON "lims"."personal" USING gin(to_tsvector('english', "full_name"));
CREATE INDEX IF NOT EXISTS idx_personal_mail ON "lims"."personal" ("mail");
CREATE INDEX IF NOT EXISTS idx_taxon_path_gist ON "reference"."taxon" USING GIST ("path");
CREATE INDEX IF NOT EXISTS idx_taxon_en_name_gin ON "reference"."taxon" USING gin(to_tsvector('english', "en_name"));
CREATE INDEX IF NOT EXISTS idx_region_abrv ON "reference"."region" ("region_abrv");
CREATE INDEX IF NOT EXISTS idx_ecosystem_abrv ON "reference"."ecosystem" ("ecosystem_abrv");
CREATE INDEX IF NOT EXISTS idx_gene_id ON "reference"."gene" ("gene_id");
CREATE INDEX IF NOT EXISTS idx_samples_type_id ON "reference"."samples_type" ("sample_type_id");
CREATE INDEX IF NOT EXISTS idx_units_unit_type ON "reference"."units" ("unit_type");

-- Lims Schema Indexes
CREATE INDEX IF NOT EXISTS idx_external_contacts_full_name ON "lims"."external_contacts" USING gin(to_tsvector('english', "full_name"));
CREATE INDEX IF NOT EXISTS idx_customers_customer_name ON "lims"."customers" ("customer_name");
CREATE INDEX IF NOT EXISTS idx_customers_customer_abrv ON "lims"."customers" ("customer_abrv");
CREATE INDEX IF NOT EXISTS idx_projects_status_id ON "lims"."projects" ("status_id");
CREATE INDEX IF NOT EXISTS idx_projects_pi_person_id ON "lims"."projects" ("pi_person_id");
CREATE INDEX IF NOT EXISTS idx_projects_customer_id ON "lims"."projects" ("customer_id");
CREATE INDEX IF NOT EXISTS idx_projects_title ON "lims"."projects" USING gin(to_tsvector('english', "title"));
CREATE INDEX IF NOT EXISTS idx_project_persons_project_id ON "lims"."project_persons" ("project_id");
CREATE INDEX IF NOT EXISTS idx_project_persons_person_id ON "lims"."project_persons" ("person_id");
CREATE INDEX IF NOT EXISTS idx_cruises_project_id ON "lims"."cruises" ("project_id");
CREATE INDEX IF NOT EXISTS idx_cruises_vessel_id ON "lims"."cruises" ("vessel_id");
CREATE INDEX IF NOT EXISTS idx_cruises_region_id ON "lims"."cruises" ("region_id");
CREATE INDEX IF NOT EXISTS idx_cruises_ecosystem_id ON "lims"."cruises" ("ecosystem_id");
CREATE INDEX IF NOT EXISTS idx_cruises_chief_scientist_person_id ON "lims"."cruises" ("chief_scientist_person_id");
CREATE INDEX IF NOT EXISTS idx_batch_steps_batch_id ON "lims"."batch_steps" ("batch_id");
CREATE INDEX IF NOT EXISTS idx_batch_steps_sop_id ON "lims"."batch_steps" ("sop_id");
CREATE INDEX IF NOT EXISTS idx_primers_target_gene_id ON "lims"."primers" ("target_gene_id");
CREATE INDEX IF NOT EXISTS idx_sop_sop_id_origin ON "lims"."sop" ("sop_id_origin");
CREATE INDEX IF NOT EXISTS idx_sop_title ON "lims"."sop" USING gin(to_tsvector('english', "title"));
CREATE INDEX IF NOT EXISTS idx_equipment_room_id ON "lims"."equipment" ("room_id");
CREATE INDEX IF NOT EXISTS idx_orders_project_id ON "lims"."orders" ("project_id");
CREATE INDEX IF NOT EXISTS idx_orders_item_id ON "lims"."orders" ("item_id");
CREATE INDEX IF NOT EXISTS idx_orders_supplier_id ON "lims"."orders" ("supplier_id");
CREATE INDEX IF NOT EXISTS idx_orders_status_id ON "lims"."orders" ("status_id");
CREATE INDEX IF NOT EXISTS idx_reagents_project_id ON "lims"."reagents" ("project_id");
CREATE INDEX IF NOT EXISTS idx_reagents_category_id ON "lims"."reagents" ("category_id");
CREATE INDEX IF NOT EXISTS idx_reagents_storage_id ON "lims"."reagents" ("storage_id");
CREATE INDEX IF NOT EXISTS idx_reagents_order_id ON "lims"."reagents" ("order_id");
CREATE INDEX IF NOT EXISTS idx_publications_project_id ON "lims"."publications" ("project_id");
CREATE INDEX IF NOT EXISTS idx_publications_doi ON "lims"."publications" ("doi");
CREATE INDEX IF NOT EXISTS idx_publications_title ON "lims"."publications" USING gin(to_tsvector('english', "title"));

-- Lab Schema Indexes
CREATE INDEX IF NOT EXISTS idx_experiments_id_date ON "lab"."experiments" ("experiment_id", "experiment_date");
CREATE INDEX IF NOT EXISTS idx_experiments_person_id ON "lab"."experiments" ("person_id");
CREATE INDEX IF NOT EXISTS idx_experiments_projects_id_date ON "lab"."experiments_projects" ("experiment_id", "experiment_date");
CREATE INDEX IF NOT EXISTS idx_experiments_projects_project_id ON "lab"."experiments_projects" ("project_id");
CREATE INDEX IF NOT EXISTS idx_experiments_samples_id_date ON "lab"."experiments_samples" ("experiment_id", "experiment_date");
CREATE INDEX IF NOT EXISTS idx_experiments_samples_sample_id ON "lab"."experiments_samples" ("sample_id");
CREATE INDEX IF NOT EXISTS idx_protocol_runs_experiment_id ON "lab"."protocol_runs" ("experiment_id");
CREATE INDEX IF NOT EXISTS idx_protocol_runs_person_id ON "lab"."protocol_runs" ("person_id");
CREATE INDEX IF NOT EXISTS idx_sampling_id_date ON "lab"."sampling" ("sampling_id", "sampling_date");
CREATE INDEX IF NOT EXISTS idx_sampling_project_id ON "lab"."sampling" ("project_id");
CREATE INDEX IF NOT EXISTS idx_sampling_cruise_id ON "lab"."sampling" ("cruise_id");
CREATE INDEX IF NOT EXISTS idx_sampling_geom ON "lab"."sampling" USING GIST ("geom");
CREATE INDEX IF NOT EXISTS idx_fishing_sampling_id_date ON "lab"."fishing" ("sampling_id", "sampling_date");
CREATE INDEX IF NOT EXISTS idx_fishing_taxon_id ON "lab"."fishing" ("taxon_id");
CREATE INDEX IF NOT EXISTS idx_individual_catch_fishing_id ON "lab"."individual_catch_catch" ("fishing_id");
CREATE INDEX IF NOT EXISTS idx_individual_catch_taxon_id ON "lab"."individual_catch_catch" ("taxon_id");
CREATE INDEX IF NOT EXISTS idx_sampling_abiotic_sampling_id ON "lab"."sampling_abiotic_data" ("sampling_id", "sampling_date");
CREATE INDEX IF NOT EXISTS idx_root_samples_sample_id_date ON "lab"."root_samples" ("sample_id", "sample_creation_date");
CREATE INDEX IF NOT EXISTS idx_root_samples_parent_id ON "lab"."root_samples" ("parent_sample_id");
CREATE INDEX IF NOT EXISTS idx_root_samples_sampling_id_date ON "lab"."root_samples" ("sampling_id", "sampling_date");
CREATE INDEX IF NOT EXISTS idx_root_samples_experiment_id_date ON "lab"."root_samples" ("experiment_id", "experiment_date");
CREATE INDEX IF NOT EXISTS idx_root_samples_project_id ON "lab"."root_samples" ("project_id");
CREATE INDEX IF NOT EXISTS idx_fish_sample_id_date ON "lab"."fish" ("sample_id", "sample_creation_date");
CREATE INDEX IF NOT EXISTS idx_fish_species_id ON "lab"."fish" ("species_id");
CREATE INDEX IF NOT EXISTS idx_tissue_sample_id_date ON "lab"."tissue" ("sample_id", "sample_creation_date");
CREATE INDEX IF NOT EXISTS idx_otoliths_otolith_id_date ON "lab"."otoliths" ("otolith_id", "sample_creation_date");
CREATE INDEX IF NOT EXISTS idx_otoliths_reader_person_id ON "lab"."otoliths" ("reader_person_id");
CREATE INDEX IF NOT EXISTS idx_dna_sample_id_date ON "lab"."dna" ("sample_id", "sample_creation_date");
CREATE INDEX IF NOT EXISTS idx_rna_sample_id_date ON "lab"."rna" ("sample_id", "sample_creation_date");
CREATE INDEX IF NOT EXISTS idx_dissections_sample_id ON "lab"."dissections" ("sample_id");
CREATE INDEX IF NOT EXISTS idx_dissections_experiment_id ON "lab"."dissections" ("experiment_id", "experiment_date");
CREATE INDEX IF NOT EXISTS idx_nanodrop_sample_id ON "lab"."nanodrop" ("sample_id", "sample_creation_date");
CREATE INDEX IF NOT EXISTS idx_qubit_sample_id ON "lab"."qubit" ("sample_id", "sample_creation_date");
CREATE INDEX IF NOT EXISTS idx_tapestation_sample_id ON "lab"."tapestation" ("sample_id", "sample_creation_date");
CREATE INDEX IF NOT EXISTS idx_gelelectrophoresis_sample_id ON "lab"."gelelectrophoresis" ("sample_id", "sample_creation_date");
CREATE INDEX IF NOT EXISTS idx_qpcr_sample_id ON "lab"."qpcr" ("sample_id", "sample_creation_date");
CREATE INDEX IF NOT EXISTS idx_library_sample_id ON "lab"."library" ("sample_id", "sample_creation_date");
CREATE INDEX IF NOT EXISTS idx_sequencing_run_sample_id ON "lab"."sequencing_run" ("sample_id");
CREATE INDEX IF NOT EXISTS idx_sequencing_run_library_id ON "lab"."sequencing_run" ("library_id");
CREATE INDEX IF NOT EXISTS idx_seq_dataset_sample_id ON "lab"."Seq_dataset" ("sample_id");
CREATE INDEX IF NOT EXISTS idx_seq_dataset_sequencing_run_id ON "lab"."Seq_dataset" ("sequencing_run_id");
CREATE INDEX IF NOT EXISTS idx_datasets_sample_id ON "lab"."datasets" ("sample_id");
CREATE INDEX IF NOT EXISTS idx_datasets_experiment_id ON "lab"."datasets" ("experiment_id", "experiment_date");

-- Bioinformatics Schema Indexes
CREATE INDEX IF NOT EXISTS idx_analysis_pipelines_id ON "bioinformatics"."analysis_pipelines" ("pipeline_id");
CREATE INDEX IF NOT EXISTS idx_analysis_pipelines_name ON "bioinformatics"."analysis_pipelines" USING gin(to_tsvector('english', "pipeline_name"));
CREATE INDEX IF NOT EXISTS idx_analysis_runs_id_date ON "bioinformatics"."analysis_runs" ("run_id", "experiment_date");
CREATE INDEX IF NOT EXISTS idx_analysis_runs_pipeline_id ON "bioinformatics"."analysis_runs" ("pipeline_id");
CREATE INDEX IF NOT EXISTS idx_analysis_runs_sequencing_id ON "bioinformatics"."analysis_runs" ("sequencing_id", "sequencing_date");
CREATE INDEX IF NOT EXISTS idx_edna_assignments_run_id ON "bioinformatics"."edna_assignments" ("run_id");
CREATE INDEX IF NOT EXISTS idx_edna_assignments_sample_id ON "bioinformatics"."edna_assignments" ("sample_id", "sample_creation_date");
CREATE INDEX IF NOT EXISTS idx_edna_assignments_taxon_id ON "bioinformatics"."edna_assignments" ("taxon_id");

-- Projects Schema Indexes
CREATE INDEX IF NOT EXISTS idx_wander_fishingdata_id_date ON "projects"."ProjectWanderfische_FishingData" ("fishing_record_id", "record_date");
CREATE INDEX IF NOT EXISTS idx_wander_fishingdata_agency_id ON "projects"."ProjectWanderfische_FishingData" ("agency_id");
CREATE INDEX IF NOT EXISTS idx_wander_fishingdata_project_id ON "projects"."ProjectWanderfische_FishingData" ("project_id");
CREATE INDEX IF NOT EXISTS idx_wander_fishingdata_geom ON "projects"."ProjectWanderfische_FishingData" USING GIST ("geom_4326");
CREATE INDEX IF NOT EXISTS idx_wander_fishcatch_fishing_id_date ON "projects"."ProjectWanderfische_FishCatch" ("fishing_record_id", "fishing_record_date");
CREATE INDEX IF NOT EXISTS idx_wander_fishcatch_taxon_id ON "projects"."ProjectWanderfische_FishCatch" ("taxon_id");
CREATE INDEX IF NOT EXISTS idx_wander_mail_fishing_id_date ON "projects"."ProjectWanderfische_Mail" ("fishing_record_id", "fishing_record_date");
CREATE INDEX IF NOT EXISTS idx_wander_mail_sender_id ON "projects"."ProjectWanderfische_Mail" ("sender_person_id");
CREATE INDEX IF NOT EXISTS idx_wander_conversation_fishing_id_date ON "projects"."ProjectWanderfische_Conversation" ("fishing_record_id", "fishing_record_date");
CREATE INDEX IF NOT EXISTS idx_wander_chatmessage_conversation_id ON "projects"."ProjectWanderfische_ChatMessage" ("conversation_id");

-- ======================================================================
-- 3. VIEWS
-- ======================================================================
CREATE OR REPLACE VIEW "lims"."project_summary_view" AS
SELECT
    p.project_id,
    p.title,
    p.project_abrv,
    s.notes AS project_status,
    pers.full_name AS principal_investigator,
    cust.customer_name,
    p.start_date,
    p.end_date,
    p.funder,
    p.description
FROM
    "lims"."projects" p
LEFT JOIN
    "reference"."status" s ON p.status_id = s.status_id
LEFT JOIN
    "lims"."personal" pers ON p.pi_person_id = pers.person_id
LEFT JOIN
    "lims"."customers" cust ON p.customer_id = cust.customer_id;

CREATE OR REPLACE VIEW "lab"."sample_type_counts_view" AS
SELECT
    st.sample_type_id,
    st.sample_type_abrv,
    COUNT(rs.sample_id) AS total_samples
FROM
    "reference"."samples_type" st
LEFT JOIN
    "lab"."root_samples" rs ON st.sample_type_id = rs.sample_type_id
GROUP BY
    st.sample_type_id, st.sample_type_abrv
ORDER BY
    total_samples DESC;
    
CREATE OR REPLACE VIEW "lab"."storage_occupancy_view" AS
WITH sample_counts AS (
    SELECT
        storage_id,
        COUNT(sample_id) AS stored_samples
    FROM
        "lab"."root_samples"
    WHERE
        storage_id IS NOT NULL
    GROUP BY
        storage_id
)
SELECT
    s.storage_id,
    s.box,
    s.freezer,
    s.temperature_c,
    r.room_id,
    r.address AS room_address,
    (s.box_size_x * s.box_size_y) AS box_capacity,
    COALESCE(sc.stored_samples, 0) AS occupied_slots,
    (COALESCE(sc.stored_samples, 0)::NUMERIC / (s.box_size_x * s.box_size_y)) AS occupancy_ratio
FROM
    "lab"."storage" s
LEFT JOIN
    "reference"."room" r ON s.room_id = r.room_id
LEFT JOIN
    sample_counts sc ON s.storage_id = sc.storage_id
WHERE s.box_size_x IS NOT NULL AND s.box_size_y IS NOT NULL
ORDER BY
    occupancy_ratio DESC;

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
    p.contact_finance,
    p.contact_funder,
    p.notes AS project_notes
FROM
    "lims"."projects" p
LEFT JOIN
    "reference"."status" s ON p.status_id = s.status_id
LEFT JOIN
    "lims"."personal" pers ON p.pi_person_id = pers.person_id
LEFT JOIN
    "lims"."customers" c ON p.customer_id = c.customer_id;

CREATE OR REPLACE VIEW "reference"."taxon_hierarchy_view" AS
SELECT
    t.taxon_id,
    t.de_name,
    t.en_name,
    t.rank,
    t.path,
    ltree2text(subpath(t.path, 0, 1)) AS phylum,
    ltree2text(subpath(t.path, 1, 1)) AS class,
    ltree2text(subpath(t.path, 2, 1)) AS "order",
    ltree2text(subpath(t.path, 3, 1)) AS family,
    ltree2text(subpath(t.path, 4, 1)) AS genus,
    ltree2text(subpath(t.path, 5, 1)) AS species
FROM
    "reference"."taxon" t;

CREATE OR REPLACE VIEW "lims"."inventory_reagent_summary_view" AS
SELECT
    r.reagent_id,
    r.reagent_complete_name,
    cat.notes AS category,
    r.lot,
    r.quantity_available,
    ru.unit_abbreviation AS quantity_unit,
    r.reception_date,
    r.expire_date,
    s.supplier_name,
    r_status.notes AS reagent_status
FROM
    "lims"."reagents" r
LEFT JOIN
    "reference"."category" cat ON r.category_id = cat.category_id
LEFT JOIN
    "reference"."units" ru ON r.quantity_unit_id = ru.unit_id
LEFT JOIN
    "lims"."orders" o ON r.order_id = o.fi_order_nr
LEFT JOIN
    "lims"."suppliers" s ON o.supplier_id = s.supplier_id
LEFT JOIN
    "reference"."status" r_status ON r.status_id = r_status.status_id
ORDER BY r.expire_date ASC;


CREATE OR REPLACE VIEW "lab"."project_pipeline_progress_view" AS
SELECT
    p.project_id,
    p.title AS project_title,
    e.experiment_id,
    e.experiment_title,
    e.experiment_date,
    s.notes AS experiment_status,
    COUNT(DISTINCT rs.sample_id) AS total_samples,
    COUNT(DISTINCT dna.sample_id) AS dna_extracted,
    COUNT(DISTINCT rna.sample_id) AS rna_extracted,
    COUNT(DISTINCT lib.library_id) AS library_prepped,
    COUNT(DISTINCT sr.sequencing_run_id) AS sequenced
FROM
    "lims"."projects" p
LEFT JOIN
    "lab"."experiments_projects" ep ON p.project_id = ep.project_id
LEFT JOIN
    "lab"."experiments" e ON ep.experiment_id = e.experiment_id AND ep.experiment_date = e.experiment_date
LEFT JOIN
    "reference"."status" s ON e.status_id = s.status_id
LEFT JOIN
    "lab"."root_samples" rs ON e.experiment_id = rs.experiment_id AND e.experiment_date = rs.experiment_date
LEFT JOIN
    "lab"."dna" dna ON rs.sample_id = dna.sample_id AND rs.sample_creation_date = dna.sample_creation_date
LEFT JOIN
    "lab"."rna" rna ON rs.sample_id = rna.sample_id AND rs.sample_creation_date = rna.sample_creation_date
LEFT JOIN
    "lab"."library" lib ON rs.sample_id = lib.sample_id AND rs.sample_creation_date = lib.sample_creation_date
LEFT JOIN
    "lab"."sequencing_run" sr ON rs.sample_id = sr.sample_id AND rs.sample_creation_date = sr.sample_creation_date
GROUP BY
    p.project_id, p.title, e.experiment_id, e.experiment_title, e.experiment_date, s.notes
ORDER BY
    e.experiment_date DESC;

CREATE OR REPLACE VIEW "lab"."full_sampling_data_view" AS
SELECT
    s.sampling_id,
    s.sampling_date,
    s.project_id,
    p.title AS project_title,
    p.project_abrv,
    s.cruise_id,
    c.vessel_id,
    v.vessel_name,
    s.region_id,
    r.region_abrv,
    s.ecosystem_id,
    e.ecosystem_abrv,
    s.location_name,
    ST_X(s.geom) AS sampling_longitude,
    ST_Y(s.geom) AS sampling_latitude,
    ST_X(s.fishing_start_geom) AS fishing_start_longitude,
    ST_Y(s.fishing_start_geom) AS fishing_start_latitude,
    ST_X(s.fishing_end_geom) AS fishing_end_longitude,
    ST_Y(s.fishing_end_geom) AS fishing_end_latitude,
    s.depth_m,
    s.fishing_method,
    s.gear_type,
    s.total_catch_quantity_kg,
    s.total_catch_quantity_fish,
    s.status_id AS sampling_status,
    s_status.notes AS sampling_status_notes,
    sad.weather,
    sad.temperature_atmospheric_c,
    sad.temperature_sampling_depth_c,
    sad.salinity,
    su.unit_abbreviation AS salinity_unit,
    sad.ph,
    sad.oxygen,
    ou.unit_abbreviation AS oxygen_unit,
    sad.notes AS abiotic_notes,
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
    "lab"."sampling_abiotic_data" sad ON s.sampling_id = sad.sampling_id AND s.sampling_date = sad.sampling_date
LEFT JOIN
    "reference"."units" su ON sad.salinity_unit_id = su.unit_id
LEFT JOIN
    "reference"."units" ou ON sad.oxygen_unit_id = ou.unit_id
LEFT JOIN
    "reference"."status" s_status ON s.status_id = s_status.status_id
ORDER BY s.sampling_date DESC;

CREATE OR REPLACE VIEW "bioinformatics"."analysis_results_view" AS
SELECT
    ar.run_id,
    ap.pipeline_name,
    ap.version AS pipeline_version,
    ar.sequencing_id,
    ar.sequencing_date,
    rs.sample_id,
    rs.external_name,
    ea.taxon_id,
    t.en_name AS taxon_name,
    ea.read_count,
    ea.confidence,
    ar.final_output_path
FROM
    "bioinformatics"."analysis_runs" ar
JOIN
    "bioinformatics"."analysis_pipelines" ap ON ar.pipeline_id = ap.pipeline_id
JOIN
    "bioinformatics"."edna_assignments" ea ON ar.run_id = ea.run_id AND ar.experiment_date = ea.experiment_date
JOIN
    "lab"."root_samples" rs ON ea.sample_id = rs.sample_id AND ea.sample_creation_date = rs.sample_creation_date
LEFT JOIN
    "reference"."taxon" t ON ea.taxon_id = t.taxon_id;


CREATE OR REPLACE VIEW "lims"."publications_by_project_view" AS
SELECT
    p.project_id,
    p.title AS project_title,
    pub.publication_id,
    pub.title AS publication_title,
    pub.journal,
    pub.doi,
    pub.date_publication,
    pers.full_name AS first_author_name
FROM
    "lims"."projects" p
LEFT JOIN
    "lims"."publications" pub ON p.project_id = pub.project_id
LEFT JOIN
    "lims"."personal" pers ON pub.first_author_person_id = pers.person_id
ORDER BY pub.date_publication DESC;




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
LEFT JOIN "lab"."root_samples" s ON p.project_id = s.project_id
LEFT JOIN "lims"."cruises" c ON p.project_id = c.project_id
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
    COUNT(DISTINCT dna.sample_id) AS samples_dna_extracted,
    COUNT(DISTINCT rna.sample_id) AS samples_rna_extracted,
    COUNT(DISTINCT qu.qubit_id) AS samples_qubit_qc,
    COUNT(DISTINCT nd.nanodrop_id) AS samples_nanodrop_qc,
    COUNT(DISTINCT tap.tapestation_id) AS samples_tapestation_qc,
    COUNT(DISTINCT pcr.sample_id) AS samples_pcr_done,
    COUNT(DISTINCT qpcr.sample_id) AS samples_qpcr_done,
    COUNT(DISTINCT lib.library_id) AS samples_library_prepped,
    COUNT(DISTINCT sr.sequencing_run_id) AS samples_sequenced,
    COUNT(DISTINCT ar.run_id) AS samples_bioinformatics_done
FROM "lab"."experiments" e
LEFT JOIN "lab"."experiments_projects" ep ON e.experiment_id = ep.experiment_id AND e.experiment_date = ep.experiment_date
LEFT JOIN "lims"."projects" p ON ep.project_id = p.project_id
LEFT JOIN "reference"."status" stat ON e.status_id = stat.status_id
LEFT JOIN "lims"."personal" pers ON e.person_id = pers.person_id
LEFT JOIN "lab"."experiments_samples" es ON e.experiment_id = es.experiment_id AND e.experiment_date = es.experiment_date
LEFT JOIN "lab"."dna" dna ON es.sample_id = dna.sample_id AND es.sample_creation_date = dna.sample_creation_date
LEFT JOIN "lab"."rna" rna ON es.sample_id = rna.sample_id AND es.sample_creation_date = rna.sample_creation_date
LEFT JOIN "lab"."qubit" qu ON es.sample_id = qu.sample_id AND es.sample_creation_date = qu.sample_creation_date
LEFT JOIN "lab"."nanodrop" nd ON es.sample_id = nd.sample_id AND es.sample_creation_date = nd.sample_creation_date
LEFT JOIN "lab"."tapestation" tap ON es.sample_id = tap.sample_id AND es.sample_creation_date = tap.sample_creation_date
LEFT JOIN "lab"."pcr" pcr ON es.sample_id = pcr.sample_id AND es.sample_creation_date = pcr.sample_creation_date
LEFT JOIN "lab"."qpcr" qpcr ON es.sample_id = qpcr.sample_id AND es.sample_creation_date = qpcr.sample_creation_date
LEFT JOIN "lab"."library" lib ON es.sample_id = lib.sample_id AND es.sample_creation_date = lib.sample_creation_date
LEFT JOIN "lab"."sequencing_run" sr ON es.sample_id = sr.sample_id AND es.sample_creation_date = sr.sample_creation_date
LEFT JOIN "bioinformatics"."analysis_runs" ar ON sr.sequencing_run_id = ar.sequencing_id AND sr.experiment_date = ar.sequencing_date
GROUP BY
    e.experiment_id, e.experiment_title, p.project_id, p.title,
    stat.notes, e.experiment_date, pers.full_name
ORDER BY e.experiment_date DESC;

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

CREATE OR REPLACE VIEW "lab"."storage_log_history_view" AS
SELECT
    sl.log_id,
    sl.sample_id,
    rs.external_name,
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
    "lab"."root_samples" rs ON sl.sample_id = rs.sample_id AND sl.sample_sampling_date = rs.sample_creation_date
LEFT JOIN
    "lims"."personal" p ON sl.person_id = p.person_id
LEFT JOIN
    "lab"."storage" storage ON sl.storage_id = storage.storage_id
LEFT JOIN
    "reference"."status" stat ON sl.status_id = stat.status_id
ORDER BY
    sl.move_date DESC;

-- -------------------------------------------------------------
CREATE OR REPLACE VIEW "bioinformatics"."analysis_results_summary_view" AS
SELECT
    ar.run_id,
    ar.person_id,
    pers.full_name AS analyst_name,
    ap.pipeline_name,
    ap.version AS pipeline_version,
    ar.sequencing_id,
    sr.experiment_date AS sequencing_date,
    sr.sequencer,
    ar.reference_db_id,
    rdb.db_name AS reference_database_name,
    rdb.db_version AS bioinfo_database_version,
    ea.sample_id,
    rs.external_name AS sample_external_name,
    ea.taxon_id,
    t.en_name AS taxon_en_name,
    ea.read_count,
    ea.confidence,
    ar.notes AS run_notes,
    ea.notes AS assignment_notes
FROM
    "bioinformatics"."analysis_runs" ar
JOIN
    "bioinformatics"."analysis_pipelines" ap ON ar.pipeline_id = ap.pipeline_id
LEFT JOIN
    "lab"."sequencing_run" sr ON ar.sequencing_id = sr.sequencing_run_id AND ar.sequencing_date = sr.experiment_date
LEFT JOIN
    "lab"."root_samples" rs ON sr.sample_id = rs.sample_id AND sr.sample_creation_date = rs.sample_creation_date
LEFT JOIN
    "lims"."personal" pers ON ar.person_id = pers.person_id
LEFT JOIN
    "reference"."reference_databases" rdb ON ar.reference_db_id::text = rdb.db_id::text -- Corrected type cast for joining
LEFT JOIN
    "bioinformatics"."edna_assignments" ea ON ar.run_id = ea.run_id AND ar.experiment_date = ea.experiment_date
LEFT JOIN
    "reference"."taxon" t ON ea.taxon_id = t.taxon_id
ORDER BY ar.run_id;

-- -------------------------------------------------------------



CREATE OR REPLACE VIEW "lab"."full_sequencing_run_view" AS
SELECT
    sr.sequencing_run_id,
--    sr.sequencing_date,
    sr.person_id,
    pers.full_name AS sequencer_person_name,
    sr.sequencer,
    sr.flow_cell_id,
    sr.library_id,
    lib.library_name,
    lib.library_prep_kit,
    sr.sample_id,
    rs.external_name AS sample_external_name,
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
    "lab"."library" lib ON sr.library_id = lib.library_id AND sr.prep_date = lib.experiment_date
LEFT JOIN
    "lab"."root_samples" rs ON sr.sample_id = rs.sample_id AND sr.sample_creation_date = rs.sample_creation_date
LEFT JOIN
    "lims"."projects" p ON sr.project_id = p.project_id;

CREATE OR REPLACE VIEW "lab"."global_lims_view" AS
SELECT
    rs.sample_id,
    rs.sample_type_id,
    st.sample_type_abrv,
    rs.external_name,
    rs.parent_sample_id,
    rs.sample_creation_date,
    rs.reception_date,
    rs_status.notes AS sample_status,
    rs.notes AS sample_notes,
    rs.project_id,
    p.title AS project_title,
    p.description AS project_description,
    p_pi.full_name AS principal_investigator,
    c.customer_name,
    rs.sampling_id,
    s.sampling_date,
    s.location_name,
    s_vessel.vessel_name,
    s_region.region_abrv AS sampling_region,
    s_ecosystem.ecosystem_abrv AS sampling_ecosystem,
    s.fishing_method,
    s.total_catch_quantity_kg,
    s.total_catch_quantity_fish,
    sad.temperature_atmospheric_c,
    sad.salinity,
    sad.oxygen,
    sad.ph,
    sad.weather,
    rs.experiment_id,
    exp.experiment_title,
    exp.experiment_date,
    exp_pers.full_name AS experiment_lead,
    dis.dissection_id,
    dis.created_at AS dissection_date,
    dis.gonad_weight_g,
    dis.liver_weight_g,
    rs.storage_id,
    rs.storage_position,
    storage.freezer,
    storage_room.address AS storage_room_address,
    sl.move_date AS last_storage_move_date,
    sl.person_id AS last_move_person_id,
    f.species_id,
    f_taxon.en_name AS fish_species_name,
    f.total_length_mm,
    f.weight_g AS fish_weight_g,
    f.sex AS fish_sex,
    dna.concentration_ng_ul AS dna_concentration,
    dna.a260_280 AS dna_a260_280,
    rna.concentration_ng_ul AS rna_concentration,
    rna.a260_280 AS rna_a260_280,
    nd.nanodrop_id,
    nd.nanodrop_concentration,
    nd.a260_280 AS nd_a260_280,
    qu.qubit_id,
    qu.qubit_original_sample_conc,
    lib.library_id,
    lib.library_name,
    lib.library_prep_kit,
    sr.sequencing_run_id,
    sr.sequencer,
    sr.total_reads,
    sr.genbank_accession_number,
    ar.run_id AS analysis_run_id,
    ap.pipeline_name,
    ap.version AS pipeline_version,
    ar_db.db_name AS ref_db_name,
    ea.taxon_id AS assigned_taxon_id,
    ea_taxon.en_name AS assigned_taxon_name,
    ea.read_count,
    ea.confidence
FROM
    "lab"."root_samples" rs
LEFT JOIN
    "reference"."status" rs_status ON rs.status_id = rs_status.status_id
LEFT JOIN
    "reference"."samples_type" st ON rs.sample_type_id = st.sample_type_id
LEFT JOIN
    "lims"."projects" p ON rs.project_id = p.project_id
LEFT JOIN
    "lims"."customers" c ON rs.customer_id = c.customer_id
LEFT JOIN
    "lims"."personal" p_pi ON p.pi_person_id = p_pi.person_id
LEFT JOIN
    "lab"."sampling" s ON rs.sampling_id = s.sampling_id AND rs.sampling_date = s.sampling_date
LEFT JOIN
    "reference"."vessel" s_vessel ON s.vessel_id = s_vessel.vessel_id
LEFT JOIN
    "reference"."region" s_region ON s.region_id = s_region.region_id
LEFT JOIN
    "reference"."ecosystem" s_ecosystem ON s.ecosystem_id = s_ecosystem.ecosystem_id
LEFT JOIN
    "lab"."sampling_abiotic_data" sad ON s.sampling_id = sad.sampling_id AND s.sampling_date = sad.sampling_date
LEFT JOIN
    "lab"."experiments" exp ON rs.experiment_id = exp.experiment_id AND rs.experiment_date = exp.experiment_date
LEFT JOIN
    "lims"."personal" exp_pers ON exp.person_id = exp_pers.person_id
LEFT JOIN
    "lab"."storage" storage ON rs.storage_id = storage.storage_id
LEFT JOIN
    "reference"."room" storage_room ON storage.room_id = storage_room.room_id
LEFT JOIN
    "lab"."storage_log" sl ON rs.sample_id = sl.sample_id AND rs.sample_creation_date = sl.sample_sampling_date
LEFT JOIN
    "lab"."dissections" dis ON rs.sample_id = dis.sample_id AND rs.experiment_date = dis.experiment_date
LEFT JOIN
    "lab"."fish" f ON rs.sample_id = f.sample_id AND rs.sample_creation_date = f.sample_creation_date
LEFT JOIN
    "reference"."taxon" f_taxon ON f.species_id = f_taxon.taxon_id
LEFT JOIN
    "lab"."dna" dna ON rs.sample_id = dna.sample_id AND rs.sample_creation_date = dna.sample_creation_date
LEFT JOIN
    "lab"."rna" rna ON rs.sample_id = rna.sample_id AND rs.sample_creation_date = rna.sample_creation_date
LEFT JOIN
    "lab"."nanodrop" nd ON rs.sample_id = nd.sample_id AND rs.sample_creation_date = nd.sample_creation_date
LEFT JOIN
    "lab"."qubit" qu ON rs.sample_id = qu.sample_id AND rs.sample_creation_date = qu.sample_creation_date
LEFT JOIN
    "lab"."library" lib ON rs.sample_id = lib.sample_id AND rs.sample_creation_date = lib.sample_creation_date
LEFT JOIN
    "lab"."sequencing_run" sr ON rs.sample_id = sr.sample_id AND rs.sample_creation_date = sr.sample_creation_date
LEFT JOIN
    "bioinformatics"."analysis_runs" ar ON sr.sequencing_run_id = ar.sequencing_id AND sr.experiment_date = ar.sequencing_date
LEFT JOIN
    "bioinformatics"."analysis_pipelines" ap ON ar.pipeline_id = ap.pipeline_id
LEFT JOIN
    "reference"."reference_databases" ar_db ON ar.reference_db_id = ar_db.db_id
LEFT JOIN
    "bioinformatics"."edna_assignments" ea ON ar.run_id = ea.run_id AND ar.experiment_date = ea.experiment_date AND rs.sample_id = ea.sample_id AND rs.sample_creation_date = ea.sample_creation_date
LEFT JOIN
    "reference"."taxon" ea_taxon ON ea.taxon_id = ea_taxon.taxon_id;

-- ======================================================================
-- 4. RLS POLICIES
-- ======================================================================
-- Enable RLS on all relevant tables
ALTER TABLE "lims"."personal" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "lims"."external_contacts" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "lims"."customers" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "lims"."projects" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "lims"."sop" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "lims"."publications" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "lims"."reagents" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "lab"."storage" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "lab"."root_samples" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "lab"."sampling" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "lab"."experiments" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "lab"."fishing" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "lab"."fish" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "lab"."tissue" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "lab"."dna" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "lab"."rna" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "lab"."otoliths" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "lab"."dissections" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "lab"."nanodrop" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "lab"."qubit" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "lab"."tapestation" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "lab"."gelelectrophoresis" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "lab"."qpcr" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "lab"."library" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "lab"."sequencing_run" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "lab"."datasets" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "bioinformatics"."analysis_runs" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "bioinformatics"."edna_assignments" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "bioinformatics"."analysis_pipelines" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "projects"."ProjectWanderfische_FishingData" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "projects"."ProjectWanderfische_FishCatch" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "projects"."ProjectWanderfische_Mail" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "projects"."ProjectWanderfische_Conversation" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "projects"."ProjectWanderfische_ChatMessage" ENABLE ROW LEVEL SECURITY;

-- Policy Definitions
CREATE POLICY personal_rls_policy ON "lims"."personal" FOR SELECT USING (TRUE);
CREATE POLICY external_contacts_rls_policy ON "lims"."external_contacts" FOR SELECT USING (TRUE);
CREATE POLICY customer_rls_policy ON "lims"."customers" FOR SELECT USING (TRUE);
CREATE POLICY sop_rls_policy ON "lims"."sop" FOR SELECT USING (TRUE);
CREATE POLICY public_reagents_policy ON "lims"."reagents" FOR SELECT USING (TRUE);
CREATE POLICY public_storage_policy ON "lab"."storage" FOR SELECT USING (TRUE);
CREATE POLICY public_pipelines_policy ON "bioinformatics"."analysis_pipelines" FOR SELECT USING (TRUE);
CREATE POLICY project_membership_policy ON "lims"."projects" USING ("lims".is_member_of_project(project_id));
CREATE POLICY root_samples_rls_policy ON "lab"."root_samples" USING ("lims".is_member_of_project(project_id));
CREATE POLICY sampling_rls_policy ON "lab"."sampling" USING ("lims".is_member_of_project(project_id));
-- CREATE POLICY datasets_rls_policy ON "lab"."datasets" USING ("lims".is_member_of_project(project_id));
CREATE POLICY fishing_rls_policy ON "lab"."fishing" USING (EXISTS (SELECT 1 FROM "lab"."sampling" s WHERE s.sampling_id = fishing.sampling_id AND "lims".is_member_of_project(s.project_id)));
CREATE POLICY fish_rls_policy ON "lab"."fish" USING (EXISTS (SELECT 1 FROM "lab"."root_samples" rs WHERE rs.sample_id = fish.sample_id AND "lims".is_member_of_project(rs.project_id)));
CREATE POLICY tissue_rls_policy ON "lab"."tissue" USING (EXISTS (SELECT 1 FROM "lab"."root_samples" rs WHERE rs.sample_id = tissue.sample_id AND "lims".is_member_of_project(rs.project_id)));
CREATE POLICY dna_rls_policy ON "lab"."dna" USING (EXISTS (SELECT 1 FROM "lab"."root_samples" rs WHERE rs.sample_id = dna.sample_id AND "lims".is_member_of_project(rs.project_id)));
CREATE POLICY rna_rls_policy ON "lab"."rna" USING (EXISTS (SELECT 1 FROM "lab"."root_samples" rs WHERE rs.sample_id = rna.sample_id AND "lims".is_member_of_project(rs.project_id)));
CREATE POLICY otoliths_rls_policy ON "lab"."otoliths" USING (EXISTS (SELECT 1 FROM "lab"."root_samples" rs WHERE rs.sample_id = otoliths.parent_sample_id AND "lims".is_member_of_project(rs.project_id)));
CREATE POLICY dissections_rls_policy ON "lab"."dissections" USING (EXISTS (SELECT 1 FROM "lab"."root_samples" rs WHERE rs.sample_id = dissections.sample_id AND "lims".is_member_of_project(rs.project_id)));
CREATE POLICY nanodrop_rls_policy ON "lab"."nanodrop" USING (EXISTS (SELECT 1 FROM "lab"."root_samples" rs WHERE rs.sample_id = nanodrop.sample_id AND "lims".is_member_of_project(rs.project_id)));
CREATE POLICY qubit_rls_policy ON "lab"."qubit" USING (EXISTS (SELECT 1 FROM "lab"."root_samples" rs WHERE rs.sample_id = qubit.sample_id AND "lims".is_member_of_project(rs.project_id)));
CREATE POLICY tapestation_rls_policy ON "lab"."tapestation" USING (EXISTS (SELECT 1 FROM "lab"."root_samples" rs WHERE rs.sample_id = tapestation.sample_id AND "lims".is_member_of_project(rs.project_id)));
CREATE POLICY gelelectrophoresis_rls_policy ON "lab"."gelelectrophoresis" USING (EXISTS (SELECT 1 FROM "lab"."root_samples" rs WHERE rs.sample_id = gelelectrophoresis.sample_id AND "lims".is_member_of_project(rs.project_id)));
CREATE POLICY qpcr_rls_policy ON "lab"."qpcr" USING (EXISTS (SELECT 1 FROM "lab"."root_samples" rs WHERE rs.sample_id = qpcr.sample_id AND "lims".is_member_of_project(rs.project_id)));
CREATE POLICY library_rls_policy ON "lab"."library" USING (EXISTS (SELECT 1 FROM "lab"."root_samples" rs WHERE rs.sample_id = library.sample_id AND "lims".is_member_of_project(rs.project_id)));
CREATE POLICY sequencing_run_rls_policy ON "lab"."sequencing_run" USING (EXISTS (SELECT 1 FROM "lab"."root_samples" rs WHERE rs.sample_id = sequencing_run.sample_id AND "lims".is_member_of_project(rs.project_id)));
CREATE POLICY analysis_runs_rls_policy ON "bioinformatics"."analysis_runs" USING (EXISTS (SELECT 1 FROM "lab"."sequencing_run" sr WHERE sr.sequencing_run_id = analysis_runs.sequencing_id AND "lims".is_member_of_project(sr.project_id)));
CREATE POLICY edna_assignments_rls_policy ON "bioinformatics"."edna_assignments" USING (EXISTS (SELECT 1 FROM "lab"."root_samples" rs WHERE rs.sample_id = edna_assignments.sample_id AND "lims".is_member_of_project(rs.project_id)));
CREATE POLICY wander_fishingdata_policy ON "projects"."ProjectWanderfische_FishingData" USING ("lims".is_member_of_project(project_id));
CREATE POLICY wander_fishcatch_policy ON "projects"."ProjectWanderfische_FishCatch" USING (EXISTS (SELECT 1 FROM "projects"."ProjectWanderfische_FishingData" fd WHERE fd.fishing_record_id = fishcatch.fishing_record_id AND fd.record_date = fishcatch.fishing_record_date AND "lims".is_member_of_project(fd.project_id)));
CREATE POLICY wander_mail_policy ON "projects"."ProjectWanderfische_Mail" USING (EXISTS (SELECT 1 FROM "projects"."ProjectWanderfische_FishingData" fd WHERE fd.fishing_record_id = mail.fishing_record_id AND fd.record_date = mail.fishing_record_date AND "lims".is_member_of_project(fd.project_id)));
CREATE POLICY wander_conversation_policy ON "projects"."ProjectWanderfische_Conversation" USING (EXISTS (SELECT 1 FROM "projects"."ProjectWanderfische_FishingData" fd WHERE fd.fishing_record_id = conversation.fishing_record_id AND fd.record_date = conversation.fishing_record_date AND "lims".is_member_of_project(fd.project_id)));
CREATE POLICY wander_chatmessage_policy ON "projects"."ProjectWanderfische_ChatMessage" USING (EXISTS (SELECT 1 FROM "projects"."ProjectWanderfische_Conversation" conv WHERE conv.conversation_id = chatmessage.conversation_id));

-- ======================================================================
-- 5. FOREIGN KEYS & UNIQUE CONSTRAINTS
-- ======================================================================
ALTER TABLE "reference"."taxon" ADD CONSTRAINT fk_taxon_parent FOREIGN KEY ("taxon_parent") REFERENCES "reference"."taxon"("taxon_id");
ALTER TABLE "reference"."units" ADD CONSTRAINT fk_parent_unit FOREIGN KEY ("parent_unit_id") REFERENCES "reference"."units"("unit_id");
ALTER TABLE "lims"."personal" ADD CONSTRAINT fk_personal_status FOREIGN KEY ("status_id") REFERENCES "reference"."status"("status_id");
ALTER TABLE "lims"."projects" ADD CONSTRAINT fk_projects_status FOREIGN KEY ("status_id") REFERENCES "reference"."status"("status_id");
ALTER TABLE "lims"."projects" ADD CONSTRAINT fk_projects_pi FOREIGN KEY ("pi_person_id") REFERENCES "lims"."personal"("person_id");
ALTER TABLE "lims"."projects" ADD CONSTRAINT fk_projects_customer FOREIGN KEY ("customer_id") REFERENCES "lims"."customers"("customer_id");
ALTER TABLE "lims"."project_persons" ADD CONSTRAINT fk_proj_pers_project FOREIGN KEY ("project_id") REFERENCES "lims"."projects"("project_id") ON DELETE CASCADE;
ALTER TABLE "lims"."project_persons" ADD CONSTRAINT fk_proj_pers_person FOREIGN KEY ("person_id") REFERENCES "lims"."personal"("person_id") ON DELETE CASCADE;
ALTER TABLE "lims"."cruises" ADD CONSTRAINT fk_cruises_project FOREIGN KEY ("project_id") REFERENCES "lims"."projects"("project_id");
ALTER TABLE "lims"."cruises" ADD CONSTRAINT fk_cruises_vessel FOREIGN KEY ("vessel_id") REFERENCES "reference"."vessel"("vessel_id");
ALTER TABLE "lims"."cruises" ADD CONSTRAINT fk_cruises_status FOREIGN KEY ("status_id") REFERENCES "reference"."status"("status_id");
ALTER TABLE "lims"."cruises" ADD CONSTRAINT fk_cruises_region FOREIGN KEY ("region_id") REFERENCES "reference"."region"("region_id");
ALTER TABLE "lims"."cruises" ADD CONSTRAINT fk_cruises_ecosystem FOREIGN KEY ("ecosystem_id") REFERENCES "reference"."ecosystem"("ecosystem_id");
ALTER TABLE "lims"."cruises" ADD CONSTRAINT fk_cruises_capitaine FOREIGN KEY ("capitaine_contact_id") REFERENCES "lims"."external_contacts"("contact_id");
ALTER TABLE "lims"."cruises" ADD CONSTRAINT fk_cruises_chief_scientist FOREIGN KEY ("chief_scientist_person_id") REFERENCES "lims"."personal"("person_id");
ALTER TABLE "lims"."cruises" ADD CONSTRAINT fk_cruises_together_with FOREIGN KEY ("together_with_contact_id") REFERENCES "lims"."external_contacts"("contact_id");
ALTER TABLE "lims"."batch_steps" ADD CONSTRAINT fk_batch_steps_batch FOREIGN KEY ("batch_id") REFERENCES "lims"."batch"("batch_id") ON DELETE CASCADE;
ALTER TABLE "lims"."batch_steps" ADD CONSTRAINT fk_batch_steps_sop FOREIGN KEY ("sop_id") REFERENCES "lims"."sop"("sop_id");
ALTER TABLE "lims"."batch_steps" ADD CONSTRAINT fk_batch_steps_status FOREIGN KEY ("status_id") REFERENCES "reference"."status"("status_id");
ALTER TABLE "lims"."primers" ADD CONSTRAINT fk_primers_gene FOREIGN KEY ("target_gene_id") REFERENCES "reference"."gene"("gene_id");
ALTER TABLE "lims"."sop" ADD CONSTRAINT fk_sop_author FOREIGN KEY ("author_person_id") REFERENCES "lims"."personal"("person_id");
ALTER TABLE "lims"."sop" ADD CONSTRAINT fk_sop_reviewer1 FOREIGN KEY ("reviewer1_person_id") REFERENCES "lims"."personal"("person_id");
ALTER TABLE "lims"."sop" ADD CONSTRAINT fk_sop_reviewer2 FOREIGN KEY ("reviewer2_person_id") REFERENCES "lims"."personal"("person_id");
ALTER TABLE "lims"."equipment" ADD CONSTRAINT fk_equipment_room FOREIGN KEY ("room_id") REFERENCES "reference"."room"("room_id");
ALTER TABLE "lims"."inventory_items" ADD CONSTRAINT fk_inv_items_category FOREIGN KEY ("category_id") REFERENCES "reference"."category"("category_id");
ALTER TABLE "lims"."inventory_items" ADD CONSTRAINT fk_inv_items_unit FOREIGN KEY ("unit_id") REFERENCES "reference"."units"("unit_id");
ALTER TABLE "lims"."orders" ADD CONSTRAINT fk_orders_item FOREIGN KEY ("item_id") REFERENCES "lims"."inventory_items"("item_id");
ALTER TABLE "lims"."orders" ADD CONSTRAINT fk_orders_category FOREIGN KEY ("category_id") REFERENCES "reference"."category"("category_id");
ALTER TABLE "lims"."orders" ADD CONSTRAINT fk_orders_project FOREIGN KEY ("project_id") REFERENCES "lims"."projects"("project_id");
ALTER TABLE "lims"."orders" ADD CONSTRAINT fk_orders_supplier FOREIGN KEY ("supplier_id") REFERENCES "lims"."suppliers"("supplier_id");
ALTER TABLE "lims"."orders" ADD CONSTRAINT fk_orders_status FOREIGN KEY ("status_id") REFERENCES "reference"."status"("status_id");
ALTER TABLE "lims"."reagents" ADD CONSTRAINT fk_reagents_category FOREIGN KEY ("category_id") REFERENCES "reference"."category"("category_id");
ALTER TABLE "lims"."reagents" ADD CONSTRAINT fk_reagents_storage FOREIGN KEY ("storage_id") REFERENCES "lab"."storage"("storage_id");
ALTER TABLE "lims"."reagents" ADD CONSTRAINT fk_reagents_status FOREIGN KEY ("status_id") REFERENCES "reference"."status"("status_id");
ALTER TABLE "lims"."reagents" ADD CONSTRAINT fk_reagents_order FOREIGN KEY ("order_id") REFERENCES "lims"."orders"("fi_order_nr");
ALTER TABLE "lims"."reagents" ADD CONSTRAINT fk_reagents_project FOREIGN KEY ("project_id") REFERENCES "lims"."projects"("project_id");
ALTER TABLE "lims"."reagents" ADD CONSTRAINT fk_reagents_unit FOREIGN KEY ("quantity_unit_id") REFERENCES "reference"."units"("unit_id");
ALTER TABLE "lims"."publications" ADD CONSTRAINT fk_publications_type FOREIGN KEY ("publication_type_id") REFERENCES "lims"."publication_type"("publication_type_id");
ALTER TABLE "lims"."publications" ADD CONSTRAINT fk_publications_project FOREIGN KEY ("project_id") REFERENCES "lims"."projects"("project_id");
ALTER TABLE "lims"."publications" ADD CONSTRAINT fk_publications_author1 FOREIGN KEY ("first_author_person_id") REFERENCES "lims"."personal"("person_id");
ALTER TABLE "lims"."publications" ADD CONSTRAINT fk_publications_author_corr FOREIGN KEY ("corresponding_author_person_id") REFERENCES "lims"."personal"("person_id");
ALTER TABLE "lab"."storage" ADD CONSTRAINT fk_storage_room FOREIGN KEY ("room_id") REFERENCES "reference"."room"("room_id");
ALTER TABLE "lab"."storage" ADD CONSTRAINT fk_storage_project FOREIGN KEY ("project_id") REFERENCES "lims"."projects"("project_id");
ALTER TABLE "lab"."experiments_projects" ADD CONSTRAINT fk_exp_proj_exp FOREIGN KEY ("experiment_id", "experiment_date") REFERENCES "lab"."experiments"("experiment_id", "experiment_date");
ALTER TABLE "lab"."experiments_projects" ADD CONSTRAINT fk_exp_proj_project FOREIGN KEY ("project_id") REFERENCES "lims"."projects"("project_id");
ALTER TABLE "lab"."experiments_samples" ADD CONSTRAINT fk_exp_samples_exp FOREIGN KEY ("experiment_id", "experiment_date") REFERENCES "lab"."experiments"("experiment_id", "experiment_date");
ALTER TABLE "lab"."experiments_samples" ADD CONSTRAINT fk_exp_samples_sample FOREIGN KEY ("sample_id", "sample_creation_date") REFERENCES "lab"."root_samples"("sample_id", "sample_creation_date");
ALTER TABLE "lab"."protocol_runs" ADD CONSTRAINT fk_prot_runs_exp FOREIGN KEY ("experiment_id", "experiment_date") REFERENCES "lab"."experiments"("experiment_id", "experiment_date");
ALTER TABLE "lab"."protocol_runs" ADD CONSTRAINT fk_prot_runs_person FOREIGN KEY ("person_id") REFERENCES "lims"."personal"("person_id");
ALTER TABLE "lab"."sampling" ADD CONSTRAINT fk_sampling_project FOREIGN KEY ("project_id") REFERENCES "lims"."projects"("project_id");
ALTER TABLE "lab"."sampling" ADD CONSTRAINT fk_sampling_cruise FOREIGN KEY ("cruise_id") REFERENCES "lims"."cruises"("cruise_id");
ALTER TABLE "lab"."sampling" ADD CONSTRAINT fk_sampling_region FOREIGN KEY ("region_id") REFERENCES "reference"."region"("region_id");
ALTER TABLE "lab"."sampling" ADD CONSTRAINT fk_sampling_ecosystem FOREIGN KEY ("ecosystem_id") REFERENCES "reference"."ecosystem"("ecosystem_id");
ALTER TABLE "lab"."sampling" ADD CONSTRAINT fk_sampling_vessel FOREIGN KEY ("vessel_id") REFERENCES "reference"."vessel"("vessel_id");
ALTER TABLE "lab"."sampling" ADD CONSTRAINT fk_sampling_customer FOREIGN KEY ("customer_id") REFERENCES "lims"."customers"("customer_id");
ALTER TABLE "lab"."sampling" ADD CONSTRAINT fk_sampling_soak_time_unit FOREIGN KEY ("soak_time_unit_id") REFERENCES "reference"."units"("unit_id");
ALTER TABLE "lab"."sampling" ADD CONSTRAINT fk_sampling_trawl_speed_unit FOREIGN KEY ("trawl_speed_unit_id") REFERENCES "reference"."units"("unit_id");
ALTER TABLE "lab"."sampling" ADD CONSTRAINT fk_sampling_contact FOREIGN KEY ("together_with_contact_id") REFERENCES "lims"."external_contacts"("contact_id");
ALTER TABLE "lab"."sampling" ADD CONSTRAINT fk_sampling_status FOREIGN KEY ("status_id") REFERENCES "reference"."status"("status_id");
ALTER TABLE "lab"."fishing" ADD CONSTRAINT fk_fishing_sampling FOREIGN KEY ("sampling_id", "sampling_date") REFERENCES "lab"."sampling"("sampling_id", "sampling_date");
ALTER TABLE "lab"."fishing" ADD CONSTRAINT fk_fishing_taxon FOREIGN KEY ("taxon_id") REFERENCES "reference"."taxon"("taxon_id");
ALTER TABLE "lab"."individual_catch_catch" ADD CONSTRAINT fk_indiv_catch_fishing FOREIGN KEY ("fishing_id", "sampling_date") REFERENCES "lab"."fishing"("fishing_id", "sampling_date");
ALTER TABLE "lab"."individual_catch_catch" ADD CONSTRAINT fk_indiv_catch_taxon FOREIGN KEY ("taxon_id") REFERENCES "reference"."taxon"("taxon_id");
ALTER TABLE "lab"."sampling_abiotic_data" ADD CONSTRAINT fk_abiotic_sampling FOREIGN KEY ("sampling_id", "sampling_date") REFERENCES "lab"."sampling"("sampling_id", "sampling_date");
ALTER TABLE "lab"."sampling_abiotic_data" ADD CONSTRAINT fk_abiotic_wind_unit FOREIGN KEY ("wind_unit_id") REFERENCES "reference"."units"("unit_id");
ALTER TABLE "lab"."sampling_abiotic_data" ADD CONSTRAINT fk_abiotic_salinity_unit FOREIGN KEY ("salinity_unit_id") REFERENCES "reference"."units"("unit_id");
ALTER TABLE "lab"."sampling_abiotic_data" ADD CONSTRAINT fk_abiotic_pressure_unit FOREIGN KEY ("pressure_unit_id") REFERENCES "reference"."units"("unit_id");
ALTER TABLE "lab"."sampling_abiotic_data" ADD CONSTRAINT fk_abiotic_oxygen_unit FOREIGN KEY ("oxygen_unit_id") REFERENCES "reference"."units"("unit_id");
ALTER TABLE "lab"."sampling_abiotic_data" ADD CONSTRAINT fk_abiotic_conductivity_unit FOREIGN KEY ("conductivity_unit_id") REFERENCES "reference"."units"("unit_id");
ALTER TABLE "lab"."storage_log" ADD CONSTRAINT fk_storage_log_sample FOREIGN KEY ("sample_id", "sample_sampling_date") REFERENCES "lab"."root_samples"("sample_id", "sample_creation_date");
ALTER TABLE "lab"."storage_log" ADD CONSTRAINT fk_storage_log_storage FOREIGN KEY ("storage_id") REFERENCES "lab"."storage"("storage_id");
ALTER TABLE "lab"."storage_log" ADD CONSTRAINT fk_storage_log_person FOREIGN KEY ("person_id") REFERENCES "lims"."personal"("person_id");
ALTER TABLE "lab"."storage_log" ADD CONSTRAINT fk_storage_log_status FOREIGN KEY ("status_id") REFERENCES "reference"."status"("status_id");

ALTER TABLE "lab"."root_samples" ADD CONSTRAINT fk_root_sample_parent FOREIGN KEY ("parent_sample_id", "parental_sample_creation_date")  REFERENCES "lab"."root_samples"("sample_id", "sample_creation_date");
-- Adds a foreign key to the root sample, referencing its ID and creation date. This assumes the root_sample_id and root_sample_creation_date will point to the original sample in the hierarchy.
ALTER TABLE "lab"."root_samples" ADD CONSTRAINT fk_root_sample_root FOREIGN KEY ("root_sample_id", "root_sample_creation_date")  REFERENCES "lab"."root_samples"("sample_id", "sample_creation_date");

ALTER TABLE "lab"."root_samples" ADD CONSTRAINT fk_root_sample_type FOREIGN KEY ("sample_type_id") REFERENCES "reference"."samples_type"("sample_type_id");
ALTER TABLE "lab"."root_samples" ADD CONSTRAINT fk_root_sample_project FOREIGN KEY ("project_id") REFERENCES "lims"."projects"("project_id");
ALTER TABLE "lab"."root_samples" ADD CONSTRAINT fk_root_sample_customer FOREIGN KEY ("customer_id") REFERENCES "lims"."customers"("customer_id");
ALTER TABLE "lab"."root_samples" ADD CONSTRAINT fk_root_sample_sampling FOREIGN KEY ("sampling_id", "sampling_date") REFERENCES "lab"."sampling"("sampling_id", "sampling_date");
ALTER TABLE "lab"."root_samples" ADD CONSTRAINT fk_root_sample_exp FOREIGN KEY ("experiment_id", "experiment_date") REFERENCES "lab"."experiments"("experiment_id", "experiment_date");
ALTER TABLE "lab"."root_samples" ADD CONSTRAINT fk_root_sample_storage FOREIGN KEY ("storage_id") REFERENCES "lab"."storage"("storage_id");
ALTER TABLE "lab"."root_samples" ADD CONSTRAINT fk_root_sample_sampler FOREIGN KEY ("sampler_person_id") REFERENCES "lims"."personal"("person_id");
ALTER TABLE "lab"."root_samples" ADD CONSTRAINT fk_root_sample_receiver FOREIGN KEY ("receiver_person_id") REFERENCES "lims"."personal"("person_id");
ALTER TABLE "lab"."root_samples" ADD CONSTRAINT fk_root_sample_status FOREIGN KEY ("status_id") REFERENCES "reference"."status"("status_id");
ALTER TABLE "lab"."root_samples" ADD CONSTRAINT fk_root_sample_batch FOREIGN KEY ("batch_id") REFERENCES "lims"."batch"("batch_id");
ALTER TABLE "lab"."fish" ADD CONSTRAINT fk_fish_sample FOREIGN KEY ("sample_id", "sample_creation_date") REFERENCES "lab"."root_samples"("sample_id", "sample_creation_date");
ALTER TABLE "lab"."fish" ADD CONSTRAINT fk_fish_species FOREIGN KEY ("species_id") REFERENCES "reference"."taxon"("taxon_id");
ALTER TABLE "lab"."fish" ADD CONSTRAINT fk_fish_storage FOREIGN KEY ("storage_id") REFERENCES "lab"."storage"("storage_id");
ALTER TABLE "lab"."fish" ADD CONSTRAINT fk_fish_project FOREIGN KEY ("project_id") REFERENCES "lims"."projects"("project_id");
ALTER TABLE "lab"."fish" ADD CONSTRAINT fk_fish_batch FOREIGN KEY ("batch_id") REFERENCES "lims"."batch"("batch_id");
ALTER TABLE "lab"."fish" ADD CONSTRAINT fk_fish_step FOREIGN KEY ("step_id") REFERENCES "lims"."batch_steps"("step_id");
ALTER TABLE "lab"."fish" ADD CONSTRAINT fk_fish_customer FOREIGN KEY ("customer_id") REFERENCES "lims"."customers"("customer_id");
ALTER TABLE "lab"."fish" ADD CONSTRAINT fk_fish_status FOREIGN KEY ("status_id") REFERENCES "reference"."status"("status_id");
ALTER TABLE "lab"."tissue" ADD CONSTRAINT fk_tissue_sample FOREIGN KEY ("sample_id", "sample_creation_date") REFERENCES "lab"."root_samples"("sample_id", "sample_creation_date");
ALTER TABLE "lab"."tissue" ADD CONSTRAINT fk_tissue_storage FOREIGN KEY ("storage_id") REFERENCES "lab"."storage"("storage_id");
ALTER TABLE "lab"."tissue" ADD CONSTRAINT fk_tissue_project FOREIGN KEY ("project_id") REFERENCES "lims"."projects"("project_id");
ALTER TABLE "lab"."tissue" ADD CONSTRAINT fk_tissue_batch FOREIGN KEY ("batch_id") REFERENCES "lims"."batch"("batch_id");
ALTER TABLE "lab"."tissue" ADD CONSTRAINT fk_tissue_step FOREIGN KEY ("step_id") REFERENCES "lims"."batch_steps"("step_id");
ALTER TABLE "lab"."tissue" ADD CONSTRAINT fk_tissue_status FOREIGN KEY ("status_id") REFERENCES "reference"."status"("status_id");
ALTER TABLE "lab"."otoliths" ADD CONSTRAINT fk_otoliths_parent_sample FOREIGN KEY ("parent_sample_id", "sample_creation_date") REFERENCES "lab"."root_samples"("sample_id", "sample_creation_date");
ALTER TABLE "lab"."otoliths" ADD CONSTRAINT fk_otoliths_reader FOREIGN KEY ("reader_person_id") REFERENCES "lims"."personal"("person_id");
ALTER TABLE "lab"."otoliths" ADD CONSTRAINT fk_otoliths_project FOREIGN KEY ("project_id") REFERENCES "lims"."projects"("project_id");
ALTER TABLE "lab"."otoliths" ADD CONSTRAINT fk_otoliths_batch FOREIGN KEY ("batch_id") REFERENCES "lims"."batch"("batch_id");
ALTER TABLE "lab"."otoliths" ADD CONSTRAINT fk_otoliths_step FOREIGN KEY ("step_id") REFERENCES "lims"."batch_steps"("step_id");
ALTER TABLE "lab"."otoliths" ADD CONSTRAINT fk_otoliths_status FOREIGN KEY ("status_id") REFERENCES "reference"."status"("status_id");
ALTER TABLE "lab"."dna" ADD CONSTRAINT fk_dna_sample FOREIGN KEY ("sample_id", "sample_creation_date") REFERENCES "lab"."root_samples"("sample_id", "sample_creation_date");
ALTER TABLE "lab"."dna" ADD CONSTRAINT fk_dna_storage FOREIGN KEY ("storage_id") REFERENCES "lab"."storage"("storage_id");
ALTER TABLE "lab"."dna" ADD CONSTRAINT fk_dna_batch FOREIGN KEY ("batch_id") REFERENCES "lims"."batch"("batch_id");
ALTER TABLE "lab"."dna" ADD CONSTRAINT fk_dna_step FOREIGN KEY ("step_id") REFERENCES "lims"."batch_steps"("step_id");
ALTER TABLE "lab"."dna" ADD CONSTRAINT fk_dna_status FOREIGN KEY ("status_id") REFERENCES "reference"."status"("status_id");
ALTER TABLE "lab"."rna" ADD CONSTRAINT fk_rna_sample FOREIGN KEY ("sample_id", "sample_creation_date") REFERENCES "lab"."root_samples"("sample_id", "sample_creation_date");
ALTER TABLE "lab"."rna" ADD CONSTRAINT fk_rna_storage FOREIGN KEY ("storage_id") REFERENCES "lab"."storage"("storage_id");
ALTER TABLE "lab"."rna" ADD CONSTRAINT fk_rna_batch FOREIGN KEY ("batch_id") REFERENCES "lims"."batch"("batch_id");
ALTER TABLE "lab"."rna" ADD CONSTRAINT fk_rna_step FOREIGN KEY ("step_id") REFERENCES "lims"."batch_steps"("step_id");
ALTER TABLE "lab"."rna" ADD CONSTRAINT fk_rna_status FOREIGN KEY ("status_id") REFERENCES "reference"."status"("status_id");
ALTER TABLE "lab"."sediments" ADD CONSTRAINT fk_sediments_sample FOREIGN KEY ("sample_id", "sample_creation_date") REFERENCES "lab"."root_samples"("sample_id", "sample_creation_date");
ALTER TABLE "lab"."sediments" ADD CONSTRAINT fk_sediments_volume_unit FOREIGN KEY ("volume_unit_id") REFERENCES "reference"."units"("unit_id");
ALTER TABLE "lab"."sediments" ADD CONSTRAINT fk_sediments_storage FOREIGN KEY ("storage_id") REFERENCES "lab"."storage"("storage_id");
ALTER TABLE "lab"."sediments" ADD CONSTRAINT fk_sediments_batch FOREIGN KEY ("batch_id") REFERENCES "lims"."batch"("batch_id");
ALTER TABLE "lab"."sediments" ADD CONSTRAINT fk_sediments_step FOREIGN KEY ("step_id") REFERENCES "lims"."batch_steps"("step_id");
ALTER TABLE "lab"."sediments" ADD CONSTRAINT fk_sediments_status FOREIGN KEY ("status_id") REFERENCES "reference"."status"("status_id");
ALTER TABLE "lab"."water" ADD CONSTRAINT fk_water_sample FOREIGN KEY ("sample_id", "sample_creation_date") REFERENCES "lab"."root_samples"("sample_id", "sample_creation_date");
ALTER TABLE "lab"."water" ADD CONSTRAINT fk_water_storage FOREIGN KEY ("storage_id") REFERENCES "lab"."storage"("storage_id");
ALTER TABLE "lab"."water" ADD CONSTRAINT fk_water_batch FOREIGN KEY ("batch_id") REFERENCES "lims"."batch"("batch_id");
ALTER TABLE "lab"."water" ADD CONSTRAINT fk_water_step FOREIGN KEY ("step_id") REFERENCES "lims"."batch_steps"("step_id");
ALTER TABLE "lab"."water" ADD CONSTRAINT fk_water_status FOREIGN KEY ("status_id") REFERENCES "reference"."status"("status_id");
ALTER TABLE "lab"."pcr" ADD CONSTRAINT fk_pcr_sample FOREIGN KEY ("sample_id", "sample_creation_date") REFERENCES "lab"."root_samples"("sample_id", "sample_creation_date");
ALTER TABLE "lab"."pcr" ADD CONSTRAINT fk_pcr_primer FOREIGN KEY ("primer_id") REFERENCES "lims"."primers"("primer_id");
ALTER TABLE "lab"."pcr" ADD CONSTRAINT fk_pcr_person FOREIGN KEY ("person_id") REFERENCES "lims"."personal"("person_id");
ALTER TABLE "lab"."pcr" ADD CONSTRAINT fk_pcr_storage FOREIGN KEY ("storage_id") REFERENCES "lab"."storage"("storage_id");
ALTER TABLE "lab"."pcr" ADD CONSTRAINT fk_pcr_status FOREIGN KEY ("status_id") REFERENCES "reference"."status"("status_id");
ALTER TABLE "lab"."pcr" ADD CONSTRAINT fk_pcr_project FOREIGN KEY ("project_id") REFERENCES "lims"."projects"("project_id");
ALTER TABLE "lab"."dissections" ADD CONSTRAINT fk_dissections_sample FOREIGN KEY ("sample_id", "sample_creation_date") REFERENCES "lab"."root_samples"("sample_id", "sample_creation_date");
ALTER TABLE "lab"."dissections" ADD CONSTRAINT fk_dissections_person FOREIGN KEY ("person_id") REFERENCES "lims"."personal"("person_id");
ALTER TABLE "lab"."dissections" ADD CONSTRAINT fk_dissections_status FOREIGN KEY ("status_id") REFERENCES "reference"."status"("status_id");
ALTER TABLE "lab"."dissections" ADD CONSTRAINT fk_dissections_project FOREIGN KEY ("project_id") REFERENCES "lims"."projects"("project_id");
ALTER TABLE "lab"."dissections" ADD CONSTRAINT fk_dissections_exp FOREIGN KEY ("experiment_id", "experiment_date") REFERENCES "lab"."experiments"("experiment_id", "experiment_date");
ALTER TABLE "lab"."nanodrop" ADD CONSTRAINT fk_nanodrop_sample FOREIGN KEY ("sample_id", "sample_creation_date") REFERENCES "lab"."root_samples"("sample_id", "sample_creation_date");
ALTER TABLE "lab"."nanodrop" ADD CONSTRAINT fk_nanodrop_exp FOREIGN KEY ("experiment_id", "experiment_date") REFERENCES "lab"."experiments"("experiment_id", "experiment_date");
ALTER TABLE "lab"."nanodrop" ADD CONSTRAINT fk_nanodrop_unit FOREIGN KEY ("concentration_unit_id") REFERENCES "reference"."units"("unit_id");
ALTER TABLE "lab"."nanodrop" ADD CONSTRAINT fk_nanodrop_person FOREIGN KEY ("person_id") REFERENCES "lims"."personal"("person_id");
ALTER TABLE "lab"."nanodrop" ADD CONSTRAINT fk_nanodrop_status FOREIGN KEY ("status_id") REFERENCES "reference"."status"("status_id");
ALTER TABLE "lab"."nanodrop" ADD CONSTRAINT fk_nanodrop_storage FOREIGN KEY ("storage_id") REFERENCES "lab"."storage"("storage_id");
ALTER TABLE "lab"."nanodrop" ADD CONSTRAINT fk_nanodrop_project FOREIGN KEY ("project_id") REFERENCES "lims"."projects"("project_id");
ALTER TABLE "lab"."qubit" ADD CONSTRAINT fk_qubit_sample FOREIGN KEY ("sample_id", "sample_creation_date") REFERENCES "lab"."root_samples"("sample_id", "sample_creation_date");
ALTER TABLE "lab"."qubit" ADD CONSTRAINT fk_qubit_exp FOREIGN KEY ("experiment_id", "experiment_date") REFERENCES "lab"."experiments"("experiment_id", "experiment_date");
ALTER TABLE "lab"."qubit" ADD CONSTRAINT fk_qubit_tube_unit FOREIGN KEY ("tube_unit_id") REFERENCES "reference"."units"("unit_id");
ALTER TABLE "lab"."qubit" ADD CONSTRAINT fk_qubit_sample_unit FOREIGN KEY ("original_sample_unit_id") REFERENCES "reference"."units"("unit_id");
ALTER TABLE "lab"."qubit" ADD CONSTRAINT fk_qubit_person FOREIGN KEY ("person_id") REFERENCES "lims"."personal"("person_id");
ALTER TABLE "lab"."qubit" ADD CONSTRAINT fk_qubit_status FOREIGN KEY ("status_id") REFERENCES "reference"."status"("status_id");
ALTER TABLE "lab"."qubit" ADD CONSTRAINT fk_qubit_storage FOREIGN KEY ("storage_id") REFERENCES "lab"."storage"("storage_id");
ALTER TABLE "lab"."qubit" ADD CONSTRAINT fk_qubit_project FOREIGN KEY ("project_id") REFERENCES "lims"."projects"("project_id");
ALTER TABLE "lab"."tapestation" ADD CONSTRAINT fk_tapestation_sample FOREIGN KEY ("sample_id", "sample_creation_date") REFERENCES "lab"."root_samples"("sample_id", "sample_creation_date");
ALTER TABLE "lab"."tapestation" ADD CONSTRAINT fk_tapestation_exp FOREIGN KEY ("experiment_id", "experiment_date") REFERENCES "lab"."experiments"("experiment_id", "experiment_date");
ALTER TABLE "lab"."tapestation" ADD CONSTRAINT fk_tapestation_person FOREIGN KEY ("person_id") REFERENCES "lims"."personal"("person_id");
ALTER TABLE "lab"."tapestation" ADD CONSTRAINT fk_tapestation_storage FOREIGN KEY ("storage_id") REFERENCES "lab"."storage"("storage_id");
ALTER TABLE "lab"."tapestation" ADD CONSTRAINT fk_tapestation_status FOREIGN KEY ("status_id") REFERENCES "reference"."status"("status_id");
ALTER TABLE "lab"."tapestation" ADD CONSTRAINT fk_tapestation_project FOREIGN KEY ("project_id") REFERENCES "lims"."projects"("project_id");
ALTER TABLE "lab"."gelelectrophoresis" ADD CONSTRAINT fk_gel_sample FOREIGN KEY ("sample_id", "sample_creation_date") REFERENCES "lab"."root_samples"("sample_id", "sample_creation_date");
ALTER TABLE "lab"."gelelectrophoresis" ADD CONSTRAINT fk_gel_exp FOREIGN KEY ("experiment_id", "experiment_date") REFERENCES "lab"."experiments"("experiment_id", "experiment_date");
ALTER TABLE "lab"."gelelectrophoresis" ADD CONSTRAINT fk_gel_person FOREIGN KEY ("person_id") REFERENCES "lims"."personal"("person_id");
ALTER TABLE "lab"."gelelectrophoresis" ADD CONSTRAINT fk_gel_storage FOREIGN KEY ("storage_id") REFERENCES "lab"."storage"("storage_id");
ALTER TABLE "lab"."gelelectrophoresis" ADD CONSTRAINT fk_gel_status FOREIGN KEY ("status_id") REFERENCES "reference"."status"("status_id");
ALTER TABLE "lab"."gelelectrophoresis" ADD CONSTRAINT fk_gel_project FOREIGN KEY ("project_id") REFERENCES "lims"."projects"("project_id");
ALTER TABLE "lab"."qpcr" ADD CONSTRAINT fk_qpcr_sample FOREIGN KEY ("sample_id", "sample_creation_date") REFERENCES "lab"."root_samples"("sample_id", "sample_creation_date");
ALTER TABLE "lab"."qpcr" ADD CONSTRAINT fk_qpcr_exp FOREIGN KEY ("experiment_id", "experiment_date") REFERENCES "lab"."experiments"("experiment_id", "experiment_date");
ALTER TABLE "lab"."qpcr" ADD CONSTRAINT fk_qpcr_person FOREIGN KEY ("person_id") REFERENCES "lims"."personal"("person_id");
ALTER TABLE "lab"."qpcr" ADD CONSTRAINT fk_qpcr_primer FOREIGN KEY ("primer_id") REFERENCES "lims"."primers"("primer_id");
ALTER TABLE "lab"."qpcr" ADD CONSTRAINT fk_qpcr_storage FOREIGN KEY ("storage_id") REFERENCES "lab"."storage"("storage_id");
ALTER TABLE "lab"."qpcr" ADD CONSTRAINT fk_qpcr_status FOREIGN KEY ("status_id") REFERENCES "reference"."status"("status_id");
ALTER TABLE "lab"."qpcr" ADD CONSTRAINT fk_qpcr_project FOREIGN KEY ("project_id") REFERENCES "lims"."projects"("project_id");
ALTER TABLE "lab"."library" ADD CONSTRAINT fk_library_sample FOREIGN KEY ("sample_id", "sample_creation_date") REFERENCES "lab"."root_samples"("sample_id", "sample_creation_date");
ALTER TABLE "lab"."library" ADD CONSTRAINT fk_library_exp FOREIGN KEY ("experiment_id", "experiment_date") REFERENCES "lab"."experiments"("experiment_id", "experiment_date");
ALTER TABLE "lab"."library" ADD CONSTRAINT fk_library_person FOREIGN KEY ("person_id") REFERENCES "lims"."personal"("person_id");
ALTER TABLE "lab"."library" ADD CONSTRAINT fk_library_storage FOREIGN KEY ("storage_id") REFERENCES "lab"."storage"("storage_id");
ALTER TABLE "lab"."library" ADD CONSTRAINT fk_library_status FOREIGN KEY ("status_id") REFERENCES "reference"."status"("status_id");
ALTER TABLE "lab"."library" ADD CONSTRAINT fk_library_project FOREIGN KEY ("project_id") REFERENCES "lims"."projects"("project_id");
ALTER TABLE "lab"."sequencing_run" ADD CONSTRAINT fk_seq_run_sample FOREIGN KEY ("sample_id", "sample_creation_date") REFERENCES "lab"."root_samples"("sample_id", "sample_creation_date");
ALTER TABLE "lab"."sequencing_run" ADD CONSTRAINT fk_seq_run_exp FOREIGN KEY ("experiment_id", "experiment_date") REFERENCES "lab"."experiments"("experiment_id", "experiment_date");
-- ALTER TABLE "lab"."sequencing_run" ADD CONSTRAINT fk_seq_run_library FOREIGN KEY ("library_id") REFERENCES "lab"."library"("library_id");
ALTER TABLE "lab"."sequencing_run" ADD CONSTRAINT fk_seq_run_person FOREIGN KEY ("person_id") REFERENCES "lims"."personal"("person_id");
ALTER TABLE "lab"."sequencing_run" ADD CONSTRAINT fk_seq_run_status FOREIGN KEY ("status_id") REFERENCES "reference"."status"("status_id");
ALTER TABLE "lab"."sequencing_run" ADD CONSTRAINT fk_seq_run_storage FOREIGN KEY ("storage_id") REFERENCES "lab"."storage"("storage_id");
ALTER TABLE "lab"."sequencing_run" ADD CONSTRAINT fk_seq_run_project FOREIGN KEY ("project_id") REFERENCES "lims"."projects"("project_id");
-- ALTER TABLE "lab"."Seq_dataset" ADD CONSTRAINT fk_seq_dataset_library FOREIGN KEY ("library_id") REFERENCES "lab"."library"("library_id");
ALTER TABLE "lab"."Seq_dataset" ADD CONSTRAINT fk_seq_dataset_sample FOREIGN KEY ("sample_id", "sample_creation_date") REFERENCES "lab"."root_samples"("sample_id", "sample_creation_date");
-- ALTER TABLE "lab"."Seq_dataset" ADD CONSTRAINT fk_seq_dataset_seq_run FOREIGN KEY ("sequencing_run_id", "experiment_date") REFERENCES "lab"."sequencing_run"("sequencing_run_id", "experiment_date");
ALTER TABLE "lab"."datasets" ADD CONSTRAINT fk_datasets_sample FOREIGN KEY ("sample_id", "sample_creation_date") REFERENCES "lab"."root_samples"("sample_id", "sample_creation_date");
ALTER TABLE "lab"."datasets" ADD CONSTRAINT fk_datasets_ecosystem FOREIGN KEY ("ecosystem_id") REFERENCES "reference"."ecosystem"("ecosystem_id");
ALTER TABLE "lab"."datasets" ADD CONSTRAINT fk_datasets_exp FOREIGN KEY ("experiment_id", "experiment_date") REFERENCES "lab"."experiments"("experiment_id", "experiment_date");
ALTER TABLE "lab"."datasets" ADD CONSTRAINT fk_datasets_region FOREIGN KEY ("region_id") REFERENCES "reference"."region"("region_id");
ALTER TABLE "lab"."datasets" ADD CONSTRAINT fk_datasets_customer FOREIGN KEY ("customer_id") REFERENCES "lims"."customers"("customer_id");
ALTER TABLE "lab"."datasets" ADD CONSTRAINT fk_datasets_storage FOREIGN KEY ("stored_location_id") REFERENCES "lab"."storage"("storage_id");
ALTER TABLE "lab"."datasets" ADD CONSTRAINT fk_datasets_status FOREIGN KEY ("status_id") REFERENCES "reference"."status"("status_id");
ALTER TABLE "bioinformatics"."analysis_pipelines" ADD CONSTRAINT fk_pipelines_exp FOREIGN KEY ("experiment_id", "experiment_date") REFERENCES "lab"."experiments"("experiment_id", "experiment_date");
ALTER TABLE "bioinformatics"."analysis_pipelines" ADD CONSTRAINT fk_pipelines_status FOREIGN KEY ("status_id") REFERENCES "reference"."status"("status_id");
ALTER TABLE "bioinformatics"."analysis_runs" ADD CONSTRAINT fk_runs_pipeline FOREIGN KEY ("pipeline_id") REFERENCES "bioinformatics"."analysis_pipelines"("pipeline_id");
ALTER TABLE "bioinformatics"."analysis_runs" ADD CONSTRAINT fk_runs_sequencing FOREIGN KEY ("sequencing_id", "sequencing_date") REFERENCES "lab"."sequencing_run"("sequencing_run_id", "experiment_date");
ALTER TABLE "bioinformatics"."analysis_runs" ADD CONSTRAINT fk_runs_person FOREIGN KEY ("person_id") REFERENCES "lims"."personal"("person_id");
-- ALTER TABLE "bioinformatics"."analysis_runs" ADD CONSTRAINT fk_runs_ref_db FOREIGN KEY ("reference_db_id") REFERENCES "reference"."reference_databases"("db_id");
ALTER TABLE "bioinformatics"."analysis_runs" ADD CONSTRAINT fk_runs_exp FOREIGN KEY ("experiment_id", "experiment_date") REFERENCES "lab"."experiments"("experiment_id", "experiment_date");
ALTER TABLE "bioinformatics"."analysis_runs" ADD CONSTRAINT fk_runs_status FOREIGN KEY ("status_id") REFERENCES "reference"."status"("status_id");
-- ALTER TABLE "bioinformatics"."edna_assignments" ADD CONSTRAINT fk_assignments_run FOREIGN KEY ("run_id") REFERENCES "bioinformatics"."analysis_runs"("run_id");
ALTER TABLE "bioinformatics"."edna_assignments" ADD CONSTRAINT fk_assignments_sample FOREIGN KEY ("sample_id", "sample_creation_date") REFERENCES "lab"."root_samples"("sample_id", "sample_creation_date");
ALTER TABLE "bioinformatics"."edna_assignments" ADD CONSTRAINT fk_assignments_taxon FOREIGN KEY ("taxon_id") REFERENCES "reference"."taxon"("taxon_id");
ALTER TABLE "bioinformatics"."edna_assignments" ADD CONSTRAINT fk_assignments_exp FOREIGN KEY ("experiment_id", "experiment_date") REFERENCES "lab"."experiments"("experiment_id", "experiment_date");
ALTER TABLE "bioinformatics"."edna_assignments" ADD CONSTRAINT fk_assignments_status FOREIGN KEY ("status_id") REFERENCES "reference"."status"("status_id");
-- ALTER TABLE "projects"."ProjectWanderfische_FishingData" ADD CONSTRAINT fk_fishingdata_agency FOREIGN KEY ("agency_id") REFERENCES "lims"."external_contacts"("contact_id");
-- ALTER TABLE "projects"."ProjectWanderfische_FishingData" ADD CONSTRAINT fk_fishingdata_project FOREIGN KEY ("project_id") REFERENCES "lims"."projects"("project_id");
-- ALTER TABLE "projects"."ProjectWanderfische_FishingData" ADD CONSTRAINT fk_fishingdata_salinity_unit FOREIGN KEY ("salinity_unit_id") REFERENCES "reference"."units"("unit_id");
-- ALTER TABLE "projects"."ProjectWanderfische_FishingData" ADD CONSTRAINT fk_fishingdata_oxygen_unit FOREIGN KEY ("oxygen_unit_id") REFERENCES "reference"."units"("unit_id");
-- ALTER TABLE "projects"."ProjectWanderfische_FishingData" ADD CONSTRAINT fk_fishingdata_wind_unit FOREIGN KEY ("wind_unit_id") REFERENCES "reference"."units"("unit_id");
-- ALTER TABLE "projects"."ProjectWanderfische_FishCatch" ADD CONSTRAINT fk_fishcatch_fishingdata FOREIGN KEY ("fishing_record_id", "fishing_record_date") REFERENCES "projects"."ProjectWanderfische_FishingData"("fishing_record_id", "record_date");
-- ALTER TABLE "projects"."ProjectWanderfische_FishCatch" ADD CONSTRAINT fk_fishcatch_taxon FOREIGN KEY ("taxon_id") REFERENCES "reference"."taxon"("taxon_id");
-- ALTER TABLE "projects"."ProjectWanderfische_Mail" ADD CONSTRAINT fk_mail_fishingdata FOREIGN KEY ("fishing_record_id", "fishing_record_date") REFERENCES "projects"."ProjectWanderfische_FishingData"("fishing_record_id", "record_date");
-- ALTER TABLE "projects"."ProjectWanderfische_Mail" ADD CONSTRAINT fk_mail_sender FOREIGN KEY ("sender_person_id") REFERENCES "lims"."personal"("person_id");
-- ALTER TABLE "projects"."ProjectWanderfische_Mail" ADD CONSTRAINT fk_mail_recipient FOREIGN KEY ("recipient_contact_id") REFERENCES "lims"."external_contacts"("contact_id");
-- ALTER TABLE "projects"."ProjectWanderfische_Conversation" ADD CONSTRAINT fk_conv_fishingdata FOREIGN KEY ("fishing_record_id", "fishing_record_date") REFERENCES "projects"."ProjectWanderfische_FishingData"("fishing_record_id", "record_date");
-- ALTER TABLE "projects"."ProjectWanderfische_ChatMessage" ADD CONSTRAINT fk_chat_conv FOREIGN KEY ("conversation_id") REFERENCES "projects"."ProjectWanderfische_Conversation"("conversation_id");
-- ALTER TABLE "projects"."ProjectWanderfische_ChatMessage" ADD CONSTRAINT fk_chat_sender_person FOREIGN KEY ("sender_person_id") REFERENCES "lims"."personal"("person_id");
-- ALTER TABLE "projects"."ProjectWanderfische_ChatMessage" ADD CONSTRAINT fk_chat_sender_contact FOREIGN KEY ("sender_contact_id") REFERENCES "lims"."external_contacts"("contact_id");
ALTER TABLE "lims"."publications" ADD CONSTRAINT uc_doi_date UNIQUE ("doi", "date_publication");
ALTER TABLE "lims"."batch_steps" ADD CONSTRAINT uc_batch_step UNIQUE ("batch_id", "step_number");
ALTER TABLE "lab"."root_samples" ADD CONSTRAINT uc_root_sample_id UNIQUE ("sample_id", "sample_creation_date");
ALTER TABLE "lab"."otoliths" ADD CONSTRAINT uc_otolith_id UNIQUE ("otolith_id", "reader_person_id", "side", "sample_creation_date");
ALTER TABLE "lab"."qpcr" ADD CONSTRAINT uc_qpcr_sample_exp UNIQUE ("sample_id", "experiment_date");
ALTER TABLE "lab"."library" ADD CONSTRAINT uc_library_id_sample_exp UNIQUE ("library_id", "sample_id", "experiment_date");
ALTER TABLE "lab"."sequencing_run" ADD CONSTRAINT uc_seq_run_id_exp UNIQUE ("sequencing_run_id", "experiment_date");
-- ALTER TABLE "lab"."Seq_dataset" ADD CONSTRAINT uc_seq_dataset_id_exp UNIQUE ("data_seq_id", "experiment_date");
ALTER TABLE "lab"."datasets" ADD CONSTRAINT uc_dataset_id_reception UNIQUE ("dataset_id", "reception_date");
ALTER TABLE "bioinformatics"."analysis_runs" ADD CONSTRAINT uc_run_id_exp UNIQUE ("run_id", "experiment_date");
