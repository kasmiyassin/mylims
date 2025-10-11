-- -------------------------------------------------
-- Code for lims and ELN and booking system 
-- For genetic and biology lab
-- V4. Clean, 2025-09-01_YK
-- -------------------------------------------------

-- -- =========================================
-- 1. EXTENSIONS
-- -- =========================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "postgres_fdw";
CREATE EXTENSION IF NOT EXISTS "hstore";
CREATE EXTENSION IF NOT EXISTS "tablefunc";
CREATE EXTENSION IF NOT EXISTS "ltree";
CREATE EXTENSION IF NOT EXISTS "postgis";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- -- =========================================
-- 2. SCHEMA CREATION
-- -- =========================================
CREATE SCHEMA IF NOT EXISTS "lab";
CREATE SCHEMA IF NOT EXISTS "lims";
CREATE SCHEMA IF NOT EXISTS "reference";
CREATE SCHEMA IF NOT EXISTS "bioinformatics";
CREATE SCHEMA IF NOT EXISTS "audit";
CREATE SCHEMA IF NOT EXISTS "projects";


-- -- =========================================
-- 4. AUDIT LOG TABLE
-- -- =========================================
CREATE TABLE IF NOT EXISTS "audit"."log" (
    "id" bigserial PRIMARY KEY,
    "schema_name" text NOT NULL,
    "table_name" text NOT NULL,
    "user_db_name" text DEFAULT current_user, -- Renamed for clarity: original DB user
    "logged_in_person_id" text,               -- NEW: The person ID from LIMS session
    "logged_in_full_name" text,               -- NEW: The person's full name
    "action_timestamp" timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "action" text NOT NULL CHECK ("action" IN ('I', 'D', 'U', 'T')),
    "original_data" jsonb,
    "new_data" jsonb,
    "query_text" text
);



-- -- =========================================
-- 5. REFERENCE SCHEMA TABLES
-- -- =========================================
-- These tables store controlled vocabularies and reference data to ensure consistency.

CREATE TABLE IF NOT EXISTS "reference"."status" (
    "status_id" text PRIMARY KEY,
    "tags" text,
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
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "reference"."vessel" (
    "vessel_id" text PRIMARY KEY,
    "vessel_name" text,
    "belong_to" text,
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "reference"."region" (
    "region_id" text PRIMARY KEY,
    "region_abrv" text UNIQUE NOT NULL,
    "parent_region" text,
    "rank" text,
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
    "path" ltree
);

CREATE TABLE IF NOT EXISTS "reference"."ecosystem" (
    "ecosystem_id" text PRIMARY KEY,
    "ecosystem_abrv" text UNIQUE NOT NULL,
    "country" text,
    "rank" text,
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
    "path" ltree
);

CREATE TABLE IF NOT EXISTS "reference"."category" (
    "category_id" text PRIMARY KEY,
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "reference"."samples_type" (
    "sample_type_id" text PRIMARY KEY,
    "sample_type_abrv" text UNIQUE NOT NULL,
    "rank" text,
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "reference"."gene" (
    "gene_id" text PRIMARY KEY,
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "reference"."taxon" (
    "taxon_id" text PRIMARY KEY,
    "taxon_parent" text REFERENCES "reference"."taxon"("taxon_id"),
    "de_name" text,
    "en_name" text,
    "max_length_mm" numeric,
    "max_age_years" numeric,
    "rank" text,
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
    "path" ltree
);

CREATE TABLE IF NOT EXISTS "reference"."units" (
    "unit_id" text PRIMARY KEY,
    "unit_name" text NOT NULL,
    "unit_abbreviation" text UNIQUE NOT NULL,
    "unit_type" text NOT NULL, -- e.g., 'Mass', 'Volume', 'Concentration', 'Length'
    "parent_unit_id" text REFERENCES "reference"."units"("unit_id"),
    "conversion_factor_to_parent" numeric
);

CREATE TABLE IF NOT EXISTS "reference"."reference_databases" (
    "db_id" serial PRIMARY KEY,
    "db_name" text NOT NULL,
    "db_version" text,
    "tags" text,
    "notes" text,
    "url" text,
    "path" text,
    "last_updated_date" date,
    "attachment" bytea,
    "attachment_link" text
);


-- -- =========================================
-- 6. LIMS SCHEMA TABLES
-- -- =========================================
CREATE TABLE IF NOT EXISTS "lims"."personal" (
    "person_id" text PRIMARY KEY,
    "salutation" text,
    "full_name" text,
    "room" text,
    "telephone" text,
    "mail" text UNIQUE,
    "password_hash" text NOT NULL,
    "status_id" text NOT NULL REFERENCES "reference"."status"("status_id"),
    "tags" text,
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
    "tags" text,
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
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "lims"."projects" (
    "project_id" text PRIMARY KEY,
    "project_abrv" text,
    "title" text,
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "pi_person_id" text REFERENCES "lims"."personal"("person_id"),
    "funder" text,
    "customer_id" integer REFERENCES "lims"."customers"("customer_id"),
    "start_date" date,
    "end_date" date,
    "report_date" date,
    "contact_finance" text,
    "contact_funder" text,
    "description" text,
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "lims"."project_persons" (
    "project_id" text REFERENCES "lims"."projects"("project_id") ON DELETE CASCADE,
    "person_id" text REFERENCES "lims"."personal"("person_id") ON DELETE CASCADE,
    "role" text,
    PRIMARY KEY ("project_id", "person_id"),
    "link_date" date,
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "lab"."storage" (
    "storage_id" text PRIMARY KEY,
    "room_id" text REFERENCES "reference"."room"("room_id"),
    "freezer" text,
    "etage" text,
    "temperature_c" numeric,
    "box" text,
    "box_size_x" numeric,
    "box_size_y" numeric,
    "storage_position_format" text,
    "project_id" text REFERENCES "lims"."projects"("project_id"),
    "address" text,
    "status_id" text, 
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "lims"."cruises" (
    "cruise_id" text PRIMARY KEY,
    "project_id" text REFERENCES "lims"."projects"("project_id"),
    "vessel_id" text REFERENCES "reference"."vessel"("vessel_id"),
    "status_id" text DEFAULT 'Received' NOT NULL REFERENCES "reference"."status"("status_id"),
    "region_id" text REFERENCES "reference"."region"("region_id"),
    "ecosystem_id" text REFERENCES "reference"."ecosystem"("ecosystem_id"),
    "capitaine_contact_id" text REFERENCES "lims"."external_contacts"("contact_id"),
    "chief_scientist_person_id" text REFERENCES "lims"."personal"("person_id"),
    "start_date" date,
    "end_date" date,
    "together_with_contact_id" text REFERENCES "lims"."external_contacts"("contact_id"),
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "lims"."sop" (
    "sop_id" text PRIMARY KEY,
    "title" text,
    "sop_id_origin" text NOT NULL,
    "version" text NOT NULL,
    "author_person_id" text REFERENCES "lims"."personal"("person_id"),
    "reviewer1_person_id" text REFERENCES "lims"."personal"("person_id"),
    "reviewer2_person_id" text REFERENCES "lims"."personal"("person_id"),
    "date_realise" date,
    "sop_protocol" text,
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "lims"."batch" (
    "batch_id" text PRIMARY KEY,
    "batch_name" text,
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "lims"."batch_steps" (
    "step_id" text PRIMARY KEY,
    "batch_id" text NOT NULL REFERENCES "lims"."batch"("batch_id") ON DELETE CASCADE,
    "step_number" integer NOT NULL,
    "step_name" text NOT NULL,
    "sop_id" text REFERENCES "lims"."sop"("sop_id"),
    "status_id" text DEFAULT 'Received' NOT NULL REFERENCES "reference"."status"("status_id"),
    "target_table_name" text,
    "tags" text,
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
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "lims"."primers" (
    "primer_id" text PRIMARY KEY,
    "target_gene_id" text REFERENCES "reference"."gene"("gene_id"),
    "primer_sequence_fwd" text,
    "primer_sequence_rev" text,
    "probe" text,
    "reference" text,
    "storage_id" text REFERENCES "lab"."storage"("storage_id"),
    "storage_position" text,
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "lims"."equipment" (
    "equipment_id" text PRIMARY KEY,
    "equipment_name" text,
    "room_id" text REFERENCES "reference"."room"("room_id"),
    "lot" text,
    "mobility" text,
    "date_maintenance" date,
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "lims"."instrument_maintenance" (
    "maintenance_id" serial PRIMARY KEY,
    "equipment_id" text NOT NULL REFERENCES "lims"."equipment"("equipment_id"),
    "maintenance_date" date NOT NULL,
    "performed_by_person_id" text REFERENCES "lims"."personal"("person_id"),
    "maintenance_type" text NOT NULL CHECK (maintenance_type IN ('Calibration', 'Repair', 'Preventive Maintenance', 'Validation')),
    "description" text,
    "next_due_date" date,
    "tags" text,
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
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "lims"."inventory_items" (
    "item_id" text PRIMARY KEY,
    "item_name" text NOT NULL,
    "category_id" text REFERENCES "reference"."category"("category_id"),
    "tags" text,
    "notes" text,
    "unit_id" text REFERENCES "reference"."units"("unit_id"),
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "lims"."orders" (
    "fi_order_nr" text PRIMARY KEY,
    "item_id" text REFERENCES "lims"."inventory_items"("item_id"),
    "category_id" text REFERENCES "reference"."category"("category_id"),
    "order_date" date,
    "price" numeric,
    "quantity" numeric,
    "project_id" text REFERENCES "lims"."projects"("project_id"),
    "supplier_id" text REFERENCES "lims"."suppliers"("supplier_id"),
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "lims"."reagents" (
    "reagent_id" text PRIMARY KEY,
    "reagent_complete_name" text NOT NULL,
    "category_id" text REFERENCES "reference"."category"("category_id"),
    "lot" text,
    "storage_id" text REFERENCES "lab"."storage"("storage_id"),
    "storage_position" text,
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "reception_date" date,
    "expire_date" date,
    "order_id" text REFERENCES "lims"."orders"("fi_order_nr"),
    "project_id" text REFERENCES "lims"."projects"("project_id"),
    "quantity_available" numeric,
    "quantity_unit_id" text REFERENCES "reference"."units"("unit_id"),
    "attachment" bytea,
    "attachment_link" text,
    "notes" text
);

CREATE TABLE IF NOT EXISTS "lims"."publication_type" (
    "publication_type_id" text PRIMARY KEY,
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "lims"."publications" (
    "publication_id" text PRIMARY KEY,
    "publication_type_id" text REFERENCES "lims"."publication_type"("publication_type_id"),
    "title" text NOT NULL,
    "journal" text,
    "volume" text,
    "issue" text,
    "pages" text,
    "doi" text,
    "date_publication" date,
    "date_submission" date,
    "first_author_person_id" text REFERENCES "lims"."personal"("person_id"),
    "corresponding_author_person_id" text REFERENCES "lims"."personal"("person_id"),
    "project_id" text REFERENCES "lims"."projects"("project_id"),
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);


-- -- =========================================
-- 7. LAB SCHEMA TABLES
-- -- =========================================

CREATE TABLE IF NOT EXISTS "lab"."experiments" (
    "experiment_id" text NOT NULL,
    "experiment_title" text,
    "experiment_date" date NOT NULL,
    "aim" text,
    "method" text,
    "sop_id" text,
    "person_id" text,
    "tags" text,
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
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
    PRIMARY KEY ("experiment_id", "project_id", "experiment_date"),
    FOREIGN KEY ("experiment_id", "experiment_date") REFERENCES "lab"."experiments"("experiment_id", "experiment_date"),
    FOREIGN KEY ("project_id") REFERENCES "lims"."projects"("project_id")
);

CREATE TABLE IF NOT EXISTS "lab"."experiments_samples" (
    "experiment_id" text NOT NULL,
    "experiment_date" date,
    "sample_id" text NOT NULL,
    "sample_creation_date" date ,
    "tags" text,
    "notes" text,
    PRIMARY KEY ("experiment_id", "experiment_date", "sample_id", "sample_creation_date"),
    FOREIGN KEY ("experiment_id", "experiment_date") REFERENCES "lab"."experiments"("experiment_id", "experiment_date")
);

CREATE TABLE IF NOT EXISTS "lab"."protocol_runs" (
    "protocol_run_id" serial PRIMARY KEY,
    "experiment_id" text NOT NULL,
    "experiment_date" date NOT NULL,
    "protocol_text" text,
    "person_id" text REFERENCES "lims"."personal"("person_id"),
    "protocol_run_details" text,
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
    FOREIGN KEY ("experiment_id", "experiment_date") REFERENCES "lab"."experiments"("experiment_id", "experiment_date")
);

CREATE TABLE "lab"."sampling" (
    "sampling_id" text NOT NULL,
    "sampling_date" date NOT NULL,
    "External_sampling_id" text,
    "project_id" text REFERENCES "lims"."projects"("project_id"),
    "cruise_id" text REFERENCES "lims"."cruises"("cruise_id"),
    "region_id" text REFERENCES "reference"."region"("region_id"),
    "ecosystem_id" text REFERENCES "reference"."ecosystem"("ecosystem_id"),
    "vessel_id" text REFERENCES "reference"."vessel"("vessel_id"),
    "customer_id" integer REFERENCES "lims"."customers"("customer_id"),
    "experiment_id" text,
    "experiment_date" date,
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
    "soak_time_unit_id" text REFERENCES "reference"."units"("unit_id"),
    "trawl_speed" numeric,
    "trawl_speed_unit_id" text REFERENCES "reference"."units"("unit_id"),
    "total_catch_quantity_kg" numeric,
    "total_catch_quantity_fish" numeric,
    "catch_notes" text,
    "operation_duration_min" numeric,
    "together_with_contact_id" text REFERENCES "lims"."external_contacts"("contact_id"),
    "status_id" text DEFAULT 'Planned' NOT NULL REFERENCES "reference"."status"("status_id"),
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
    FOREIGN KEY ("experiment_id", "experiment_date") REFERENCES "lab"."experiments"("experiment_id", "experiment_date"),
    PRIMARY KEY ("sampling_id","sampling_date")
) PARTITION BY RANGE ("sampling_date");

CREATE TABLE IF NOT EXISTS "lab"."fishing" (
    "fishing_id" text NOT NULL,
    "sampling_id" text NOT NULL,
    "sampling_date" date NOT NULL,
    "taxon_id" text REFERENCES "reference"."taxon"("taxon_id"),
    "catch_kg" numeric,
    "catch_fish" numeric,
    "done_by" text,
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
    "creation_date" timestamptz DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY ("fishing_id","creation_date"),
    FOREIGN KEY ("sampling_id", "sampling_date") REFERENCES "lab"."sampling"("sampling_id", "sampling_date")
) PARTITION BY RANGE ("creation_date");

CREATE TABLE IF NOT EXISTS "lab"."individual_catch_catch" (
    "individual_catch_id" text NOT NULL,
    "sampling_id" text NOT NULL,
    "sampling_date" date NOT NULL,
    "taxon_id" text NOT NULL REFERENCES "reference"."taxon"("taxon_id"),
    "SL_mm" numeric,
    "total_length_mm" numeric,
    "weight_g" numeric,
    "sex" text CHECK ("sex" IN ('Male', 'Female', 'Undetermined', NULL)),
    "maturity_stage" text,
    "done_by" text,
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
    "creation_date" timestamptz DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY ("individual_catch_id", "creation_date"),
    FOREIGN KEY ("sampling_id", "sampling_date") REFERENCES "lab"."sampling"("sampling_id", "sampling_date")
) PARTITION BY RANGE ("creation_date");

CREATE TABLE "lab"."sampling_abiotic_data" (
    "sampling_id" text NOT NULL,
    "sampling_date" date NOT NULL,
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
    PRIMARY KEY ("sampling_id","creation_date"),
    FOREIGN KEY ("sampling_id", "sampling_date") REFERENCES "lab"."sampling"("sampling_id", "sampling_date")
) PARTITION BY RANGE ("creation_date");

-- #############################
CREATE TABLE IF NOT EXISTS "lab"."reservation_samples" (
    "reservation_sample_id" text NOT NULL,
    "project_id" text REFERENCES "lims"."projects"("project_id"),
    "sampling_id" text,
    "sampling_date" date,
    "sample_type_id" text NOT NULL REFERENCES "reference"."samples_type"("sample_type_id"),
    "planned_collection_date" date,
    "status_id" text REFERENCES "reference"."status"("status_id") DEFAULT 'Planned',
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
    "creation_date" timestamptz DEFAULT CURRENT_TIMESTAMP,
    "actual_sample_id" text,
    "actual_sample_creation_date" date,
    PRIMARY KEY ("reservation_sample_id"),
    FOREIGN KEY ("sampling_id", "sampling_date") REFERENCES "lab"."sampling"("sampling_id", "sampling_date")
);

-- #############################

CREATE TABLE "lab"."root_samples" (
    "sample_id" text NOT NULL,
    "sample_type_id" text NOT NULL REFERENCES "reference"."samples_type"("sample_type_id"),
    "external_name" text,
    "parent_sample_id" text,
    "root_sample_id" text,
    "project_id" text REFERENCES "lims"."projects"("project_id"),
    "customer_id" integer REFERENCES "lims"."customers"("customer_id"),
    "sample_creation_date" date ,
    "parent_sample_creation_date" date,
    "root_sample_creation_date" date,
    "sampling_id" text,
    "sampling_date" date,
    "experiment_id" text,
    "experiment_date" date,
    "storage_id" text REFERENCES "lab"."storage"("storage_id"),
    "storage_position" text,
    "sampler_person_id" text,
    "receiver_person_id" text REFERENCES "lims"."personal"("person_id"),
    "reception_date" date,
    "transport" text,
    "conservation" text,
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "batch_id" text REFERENCES "lims"."batch"("batch_id"),
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
    PRIMARY KEY("sample_id","sample_creation_date"),
    FOREIGN KEY ("parent_sample_id", "parent_sample_creation_date") REFERENCES "lab"."root_samples"("sample_id", "sample_creation_date"),
    FOREIGN KEY ("root_sample_id", "root_sample_creation_date") REFERENCES "lab"."root_samples"("sample_id", "sample_creation_date"),
    FOREIGN KEY ("sampling_id", "sampling_date") REFERENCES "lab"."sampling"("sampling_id", "sampling_date"),
    FOREIGN KEY ("experiment_id", "experiment_date") REFERENCES "lab"."experiments"("experiment_id", "experiment_date")
) PARTITION BY RANGE ("sample_creation_date");

CREATE TABLE IF NOT EXISTS "lab"."storage_log" (
    "log_id" serial PRIMARY KEY,
    "sample_id" text NOT NULL,
    "sample_creation_date" date,
    "storage_id" text NOT NULL REFERENCES "lab"."storage"("storage_id"),
    "person_id" text REFERENCES "lims"."personal"("person_id"),
    "move_date" timestamptz DEFAULT CURRENT_TIMESTAMP,
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "storage_position" text,
    "tags" text,
    "notes" text,
    FOREIGN KEY ("sample_id", "sample_creation_date") REFERENCES "lab"."root_samples"("sample_id", "sample_creation_date")
);

CREATE TABLE IF NOT EXISTS "lab"."fish" (
    "sample_id" text NOT NULL,
    "sample_creation_date" date ,
    "species_id" text NOT NULL REFERENCES "reference"."taxon"("taxon_id"),
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
    "project_id" text REFERENCES "lims"."projects"("project_id"),
    "batch_id" text REFERENCES "lims"."batch"("batch_id"),
    "step_id" text REFERENCES "lims"."batch_steps"("step_id"),
    "customer_id" integer REFERENCES "lims"."customers"("customer_id"),
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
    "creation_date" timestamptz DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY ("sample_id","creation_date"),
    FOREIGN KEY ("sample_id", "sample_creation_date") REFERENCES "lab"."root_samples"("sample_id", "sample_creation_date")
) PARTITION BY RANGE ("creation_date");
ALTER TABLE "lab"."fish" ADD CONSTRAINT chk_fish_sex_enum CHECK ("sex" IN ('Male', 'Female', 'Undetermined', NULL));

CREATE TABLE IF NOT EXISTS "lab"."tissue" (
    "sample_id" text NOT NULL,
    "sample_creation_date" date,
    "weight_g" numeric,
    "tissue_type" text,
    "preservation_method" text,
    "project_id" text REFERENCES "lims"."projects"("project_id"),
    "batch_id" text REFERENCES "lims"."batch"("batch_id"),
    "step_id" text REFERENCES "lims"."batch_steps"("step_id"),
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
    "creation_date" timestamptz DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY ("sample_id","creation_date"),
    FOREIGN KEY ("sample_id", "sample_creation_date") REFERENCES "lab"."root_samples"("sample_id", "sample_creation_date")
) PARTITION BY RANGE ("creation_date");

CREATE TABLE IF NOT EXISTS "lab"."otoliths" (
    "sample_id" text NOT NULL,
    "sample_creation_date" date,
    "reader_person_id" text NOT NULL REFERENCES "lims"."personal"("person_id"),
    "side" text NOT NULL,
    "age_reading_years" numeric,
    "confidence" numeric,
    "project_id" text REFERENCES "lims"."projects"("project_id"),
    "batch_id" text REFERENCES "lims"."batch"("batch_id"),
    "step_id" text REFERENCES "lims"."batch_steps"("step_id"),
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
    "creation_date" timestamptz DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY ("sample_id", "reader_person_id","side","creation_date"),
    FOREIGN KEY ("sample_id", "sample_creation_date") REFERENCES "lab"."root_samples"("sample_id", "sample_creation_date")
) PARTITION BY RANGE ("creation_date");

CREATE TABLE IF NOT EXISTS "lab"."dna" (
    "sample_id" text NOT NULL,
    "sample_creation_date" date,
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
    "batch_id" text REFERENCES "lims"."batch"("batch_id"),
    "step_id" text REFERENCES "lims"."batch_steps"("step_id"),
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
    "creation_date" timestamptz DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY ("sample_id","creation_date"),
    FOREIGN KEY ("sample_id", "sample_creation_date") REFERENCES "lab"."root_samples"("sample_id", "sample_creation_date")
) PARTITION BY RANGE ("creation_date");

CREATE TABLE IF NOT EXISTS "lab"."rna" (
    "sample_id" text NOT NULL,
    "sample_creation_date" date,
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
    "batch_id" text REFERENCES "lims"."batch"("batch_id"),
    "step_id" text REFERENCES "lims"."batch_steps"("step_id"),
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
    "creation_date" timestamptz DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY ("sample_id","creation_date"),
    FOREIGN KEY ("sample_id", "sample_creation_date") REFERENCES "lab"."root_samples"("sample_id", "sample_creation_date")
) PARTITION BY RANGE ("creation_date");

CREATE TABLE IF NOT EXISTS "lab"."sediments" (
    "sample_id" text NOT NULL,
    "sample_creation_date" date,
    "volume" numeric,
    "volume_unit_id" text REFERENCES "reference"."units"("unit_id"),
    "depth_m" numeric,
    "sampling_method" text,
    "conservation_buffer" text,
    "external_name" text,
    "batch_id" text REFERENCES "lims"."batch"("batch_id"),
    "step_id" text REFERENCES "lims"."batch_steps"("step_id"),
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
    "creation_date" timestamptz DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY ("sample_id","creation_date"),
    FOREIGN KEY ("sample_id", "sample_creation_date") REFERENCES "lab"."root_samples"("sample_id", "sample_creation_date")
) PARTITION BY RANGE ("creation_date");

CREATE TABLE IF NOT EXISTS "lab"."water" (
    "sample_id" text NOT NULL,
    "sample_creation_date" date,
    "volume_L" numeric,
	"filter" text,
    "filter_pore_size_um" numeric,
    "depth_m" numeric,
    "sampling_method" text,
    "conservation_buffer" text,
    "batch_id" text REFERENCES "lims"."batch"("batch_id"),
    "step_id" text REFERENCES "lims"."batch_steps"("step_id"),
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
    "creation_date" timestamptz DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY ("sample_id", "creation_date"),
    FOREIGN KEY ("sample_id", "sample_creation_date") REFERENCES "lab"."root_samples"("sample_id", "sample_creation_date")
) PARTITION BY RANGE ("creation_date");

CREATE TABLE IF NOT EXISTS "lab"."pcr" (
    "pcr_id" text NOT NULL,
    "sample_id" text NOT NULL,
    "sample_creation_date" date,
    "experiment_id" text,
    "experiment_date" date, 
    "storage_id" text REFERENCES "lab"."storage"("storage_id"),
    "storage_position" text,
    "position" text,
    "primer_id" text REFERENCES "lims"."primers"("primer_id"),
    "pcr_blank_id" text,
    "person_id" text REFERENCES "lims"."personal"("person_id"),
    "kit" text,
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "tags" text,
    "notes" text,
    "project_id" text REFERENCES "lims"."projects"("project_id"),
    "attachment" bytea,
    "attachment_link" text,
    "volume_reaction_ul" numeric,
    "creation_date" timestamptz DEFAULT CURRENT_TIMESTAMP,
    "pcr_date" date, 
    PRIMARY KEY ("pcr_id", "creation_date"),
    FOREIGN KEY ("sample_id", "sample_creation_date") REFERENCES "lab"."root_samples"("sample_id", "sample_creation_date"),
    FOREIGN KEY ("experiment_id", "experiment_date") REFERENCES "lab"."experiments"("experiment_id", "experiment_date")
) PARTITION BY RANGE ("creation_date");

CREATE TABLE IF NOT EXISTS "lab"."dissections" (
    "dissection_id" text NOT NULL,
    "person_id" text NOT NULL REFERENCES "lims"."personal"("person_id"),
    "sample_id" text NOT NULL,
    "sample_creation_date" date,
    "project_id" text REFERENCES "lims"."projects"("project_id"),
    "experiment_id" text,
    "experiment_date" date, 
    "stomach_contents_jsonb" jsonb,
    "gonad_weight_g" numeric,
    "liver_weight_g" numeric,
    "tags" text,
    "notes" text,
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "creation_date" timestamptz DEFAULT CURRENT_TIMESTAMP,
    "attachment" bytea,
    "attachment_link" text,
    PRIMARY KEY ("dissection_id","creation_date"),
    FOREIGN KEY ("sample_id", "sample_creation_date") REFERENCES "lab"."root_samples"("sample_id", "sample_creation_date"),
    FOREIGN KEY ("experiment_id", "experiment_date") REFERENCES "lab"."experiments"("experiment_id", "experiment_date")
) PARTITION BY RANGE ("creation_date");

CREATE TABLE IF NOT EXISTS "lab"."nanodrop" (
    "nanodrop_id" text NOT NULL,
    "sample_id" text NOT NULL,
    "sample_creation_date" date,
    "experiment_id" text,
    "experiment_date" date, 
    "nanodrop_concentration" numeric,
    "concentration_unit_id" text REFERENCES "reference"."units"("unit_id"),
    "a260" numeric,
    "a260_280" numeric,
    "a260_280_note" text,
    "a260_230" numeric,
    "a260_230_note" text,
    "elution_volume_ul" numeric,
    "person_id" text REFERENCES "lims"."personal"("person_id"),
    "tags" text,
    "notes" text,
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "attachment" bytea,
    "attachment_link" text,
    "project_id" text REFERENCES "lims"."projects"("project_id"),
    "result_date" timestamptz,
    "nanodrop_total_dna_ug" numeric GENERATED ALWAYS AS (("elution_volume_ul" * "nanodrop_concentration") / 1000) STORED,
    "creation_date" timestamptz DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY ("nanodrop_id","creation_date"),
    FOREIGN KEY ("sample_id", "sample_creation_date") REFERENCES "lab"."root_samples"("sample_id", "sample_creation_date"),
    FOREIGN KEY ("experiment_id", "experiment_date") REFERENCES "lab"."experiments"("experiment_id", "experiment_date")
) PARTITION BY RANGE ("creation_date");

CREATE TABLE IF NOT EXISTS "lab"."qubit" (
    "qubit_id" text NOT NULL,
    "sample_id" text NOT NULL,
    "sample_creation_date" date,
    "experiment_id" text,
    "experiment_date" date, 
    "run_id" text,
    "assay_kit" text,
    "qubit_tube_conc" numeric,
    "tube_unit_id" text REFERENCES "reference"."units"("unit_id"),
    "qubit_original_sample_conc" numeric,
    "original_sample_unit_id" text REFERENCES "reference"."units"("unit_id"),
    "sample_volume_ul" numeric,
    "elution_volume_ul" numeric,
    "person_id" text REFERENCES "lims"."personal"("person_id"),
    "tags" text,
    "notes" text,
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "project_id" text REFERENCES "lims"."projects"("project_id"),
    "attachment" bytea,
    "attachment_link" text,
    "qubit_total_dna_ug" numeric GENERATED ALWAYS AS (("elution_volume_ul" * "qubit_original_sample_conc") / 1000) STORED,
    "creation_date" timestamptz DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY ("qubit_id","creation_date"),
    FOREIGN KEY ("sample_id", "sample_creation_date") REFERENCES "lab"."root_samples"("sample_id", "sample_creation_date"),
    FOREIGN KEY ("experiment_id", "experiment_date") REFERENCES "lab"."experiments"("experiment_id", "experiment_date")
) PARTITION BY RANGE ("creation_date");

CREATE TABLE IF NOT EXISTS "lab"."tapestation" (
    "tapestation_id" text NOT NULL,
    "sample_id" text NOT NULL,
    "sample_creation_date" date,
    "experiment_id" text,
    "experiment_date" date, 
    "position" text,
    "kit" text,
    "person_id" text REFERENCES "lims"."personal"("person_id"),
    "tags" text,
    "notes" text,
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "project_id" text REFERENCES "lims"."projects"("project_id"),
    "attachment" bytea,
    "attachment_link" text,
    "creation_date" timestamptz DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY ("tapestation_id","creation_date"),
    FOREIGN KEY ("sample_id", "sample_creation_date") REFERENCES "lab"."root_samples"("sample_id", "sample_creation_date"),
    FOREIGN KEY ("experiment_id", "experiment_date") REFERENCES "lab"."experiments"("experiment_id", "experiment_date")
) PARTITION BY RANGE ("creation_date");

CREATE TABLE IF NOT EXISTS "lab"."gelelectrophoresis" (
    "gelelectrophoresis_id" text NOT NULL,
    "sample_id" text NOT NULL,
    "sample_creation_date" date,
    "experiment_id" text,
    "experiment_date" date, -- Populated by trigger
    "position" text,
    "ladder" text,
    "voltage" numeric,
    "band_size_bp" integer,
    "gel_type" text,
    "run_time_minutes" numeric,
    "person_id" text REFERENCES "lims"."personal"("person_id"),
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "project_id" text REFERENCES "lims"."projects"("project_id"),
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
    "creation_date" timestamptz DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY ("gelelectrophoresis_id","creation_date"),
    FOREIGN KEY ("sample_id", "sample_creation_date") REFERENCES "lab"."root_samples"("sample_id", "sample_creation_date"),
    FOREIGN KEY ("experiment_id", "experiment_date") REFERENCES "lab"."experiments"("experiment_id", "experiment_date")
) PARTITION BY RANGE ("creation_date");

CREATE TABLE IF NOT EXISTS "lab"."qpcr" (
    "qpcr_id" text NOT NULL,
    "experiment_id" text NOT NULL,
    "experiment_date" date NOT NULL,
    "sample_id" text NOT NULL,
    "sample_creation_date" date,
    "position" text,
    "person_id" text REFERENCES "lims"."personal"("person_id"),
    "primer_id" text REFERENCES "lims"."primers"("primer_id"),
    "ct_value" numeric,
    "inhibitor_test_result" text,
    "pcr_blank_id" text,
    "kit" text,
    "volume_ul" numeric,
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "project_id" text REFERENCES "lims"."projects"("project_id"),
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
    "creation_date" timestamptz DEFAULT CURRENT_TIMESTAMP,
    "qpcr_date" date, -- Populated by trigger
    PRIMARY KEY ("qpcr_id", "creation_date"),
    FOREIGN KEY ("sample_id", "sample_creation_date") REFERENCES "lab"."root_samples"("sample_id", "sample_creation_date"),
    FOREIGN KEY ("experiment_id", "experiment_date") REFERENCES "lab"."experiments"("experiment_id", "experiment_date")
) PARTITION BY RANGE ("creation_date");

CREATE TABLE IF NOT EXISTS "lab"."library" (
    "library_id" text NOT NULL,
    "experiment_id" text NOT NULL,
    "experiment_date" date, -- Populated by trigger
    "sample_id" text NOT NULL,
    "sample_creation_date" date,
    "library_name" text,
    "person_id" text REFERENCES "lims"."personal"("person_id"),
    "library_prep_kit" text,
    "index_sequence" text,
    "barcode_seq" text,
    "read_length_bp" integer,
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "project_id" text REFERENCES "lims"."projects"("project_id"),
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
    "creation_date" timestamptz DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY ("library_id","sample_id","creation_date"),
    FOREIGN KEY ("sample_id", "sample_creation_date") REFERENCES "lab"."root_samples"("sample_id", "sample_creation_date"),
    FOREIGN KEY ("experiment_id", "experiment_date") REFERENCES "lab"."experiments"("experiment_id", "experiment_date")
) PARTITION BY RANGE ("creation_date");

CREATE TABLE IF NOT EXISTS "lab"."sequencing_run" (
    "sequencing_run_id" text NOT NULL,
    "experiment_id" text NOT NULL,
    "experiment_date" date, -- Populated by trigger
    "library_id" text,
    "prep_date" date,
    "sample_id" text,
    "sample_creation_date" date,
    "person_id" text REFERENCES "lims"."personal"("person_id"),
    "sequencer" text,
    "flow_cell_id" text,
    "library_prep_kit" text,
    "read_length_bp" integer,
    "total_reads" bigint,
    "raw_data_path" text,
    "genbank_accession_number" text,
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "project_id" text REFERENCES "lims"."projects"("project_id"),
    "attachment" bytea,
    "attachment_link" text,
    "tags" text,
    "notes" text,
    "creation_date" timestamptz DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY ("sequencing_run_id", "creation_date"),
    FOREIGN KEY ("sample_id", "sample_creation_date") REFERENCES "lab"."root_samples"("sample_id", "sample_creation_date"),
    FOREIGN KEY ("experiment_id", "experiment_date") REFERENCES "lab"."experiments"("experiment_id", "experiment_date")
) PARTITION BY RANGE ("creation_date");

CREATE TABLE IF NOT EXISTS "lab"."seq_dataset" (
    "data_seq_id" text NOT NULL,
    "sample_id" text NOT NULL,
    "sample_creation_date" date,
    "sequencing_run_id" text,
    "sequencer" text,
    "index_sequence" text,
    "barcode" text,
    "read_length_bp" integer,
    "total_reads" bigint,
    "raw_data_path" text,
    "bank_accession_number" text,
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "project_id" text,
    "attachment" bytea,
    "attachment_link" text,
    "tags" text,
    "notes" text,
    "data_seq_date" date, -- Populated by trigger
    "creation_date" timestamptz DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY ("data_seq_id", "creation_date"),
    FOREIGN KEY ("sample_id", "sample_creation_date") REFERENCES "lab"."root_samples"("sample_id", "sample_creation_date"),
    FOREIGN KEY ("sequencing_run_id", "creation_date") REFERENCES "lab"."sequencing_run"("sequencing_run_id", "creation_date")
) PARTITION BY RANGE ("creation_date");

CREATE TABLE IF NOT EXISTS "lab"."datasets" (
    "dataset_id" text NOT NULL,
    "sample_id" text,
    "sample_creation_date" date,
    "source_type" text,
    "ecosystem_id" text REFERENCES "reference"."ecosystem"("ecosystem_id"),
    "experiment_id" text,
    "experiment_date" date,
    "region_id" text REFERENCES "reference"."region"("region_id"),
    "customer_id" integer REFERENCES "lims"."customers"("customer_id"),
    "stored_location_id" text REFERENCES "lab"."storage"("storage_id"),
    "reception_date" date NOT NULL,
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
    "storage_path" text,
    "creation_date" timestamptz DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY ("dataset_id", "reception_date"),
    FOREIGN KEY ("sample_id", "sample_creation_date") REFERENCES "lab"."root_samples"("sample_id", "sample_creation_date"),
    FOREIGN KEY ("experiment_id", "experiment_date") REFERENCES "lab"."experiments"("experiment_id", "experiment_date")
) PARTITION BY RANGE ("reception_date");


-- -- =========================================
-- 8. BIOINFORMATICS SCHEMA TABLES
-- -- =========================================
-- Tables for managing bioinformatics pipelines, analysis runs, and results.

CREATE TABLE IF NOT EXISTS "bioinformatics"."analysis_pipelines" (
    "pipeline_id" text PRIMARY KEY,
    "pipeline_name" text NOT NULL,
    "version" text NOT NULL,
    "repository_link" text,
    "experiment_id" text,
    "experiment_date" date,
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
    FOREIGN KEY ("experiment_id", "experiment_date") REFERENCES "lab"."experiments"("experiment_id", "experiment_date")
);

CREATE TABLE IF NOT EXISTS "bioinformatics"."analysis_runs" (
    "run_id" text NOT NULL,
    "run_date" date, -- Populated by trigger
    "pipeline_id" text NOT NULL REFERENCES "bioinformatics"."analysis_pipelines"("pipeline_id"),
    "sequencing_id" text NOT NULL,
    "sequencing_date" date NOT NULL,
    "person_id" text NOT NULL REFERENCES "lims"."personal"("person_id"),
    "parameters_jsonb" jsonb,
    "reference_db_id" integer REFERENCES "reference"."reference_databases"("db_id"),
    "clustering_threshold" numeric,
    "final_output_path" text,
    "experiment_id" text,
    "experiment_date" date,
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
    "creation_date" timestamptz DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY ("run_id", "creation_date"),
    FOREIGN KEY ("sequencing_id", "sequencing_date") REFERENCES "lab"."sequencing_run"("sequencing_run_id", "creation_date"),
    FOREIGN KEY ("experiment_id", "experiment_date") REFERENCES "lab"."experiments"("experiment_id", "experiment_date")
) PARTITION BY RANGE ("creation_date");

CREATE TABLE IF NOT EXISTS "bioinformatics"."edna_assignments" (
    "assignment_id" Text NOT NULL,
    "assignment_date" date, -- Populated by trigger
    "run_id" text NOT NULL,
    "run_creation_date" date NOT NULL,
    "sample_id" text NOT NULL,
    "sample_creation_date" date,
    "taxon_id" text NOT NULL REFERENCES "reference"."taxon"("taxon_id"),
    "read_count" integer,
    "confidence" numeric,
    "experiment_id" text,
    "experiment_date" date,
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
    "creation_date" timestamptz DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY ("assignment_id", "creation_date"),
    FOREIGN KEY ("run_id", "run_creation_date") REFERENCES "bioinformatics"."analysis_runs"("run_id", "creation_date"),
    FOREIGN KEY ("sample_id", "sample_creation_date") REFERENCES "lab"."root_samples"("sample_id", "sample_creation_date"),
    FOREIGN KEY ("experiment_id", "experiment_date") REFERENCES "lab"."experiments"("experiment_id", "experiment_date")
) PARTITION BY RANGE ("creation_date");


-- -- =========================================
-- 9. PROJECTS SCHEMA TABLES
-- -- =========================================
-- Custom tables for specific, named projects.

CREATE TABLE IF NOT EXISTS "projects"."ProjectWanderfische_FishingData" (
    "fishing_record_id" serial NOT NULL,
    "agency_id" text NOT NULL REFERENCES "lims"."external_contacts"("contact_id"),
    "project_id" text NOT NULL REFERENCES "lims"."projects"("project_id"),
    "agency_record_id" text,
    "record_date" date NOT NULL,
    "record_time" time,
    "fishing_year" integer,
    "fishing_start_time" time,
    "fishing_end_time" time,
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
    "fishing_method" text,
    "gear_type" text,
    "fishing_length_m" numeric,
    "fishing_area_sqm" numeric,
    "average_width_m" numeric,
    "total_catch_quantity_kg" numeric,
    "total_catch_quantity_fish" integer,
    "temperature_c" numeric,
    "salinity" numeric,
    "salinity_unit_id" text REFERENCES "reference"."units"("unit_id"),
    "oxygen" numeric,
    "oxygen_unit_id" text REFERENCES "reference"."units"("unit_id"),
    "ph" numeric,
    "turbidity_ntu" numeric,
    "weather_conditions" text,
    "wind_speed" numeric,
    "wind_unit_id" text REFERENCES "reference"."units"("unit_id"),
    "tags" text,
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

CREATE TABLE IF NOT EXISTS "projects"."ProjectWanderfische_FishCatch" (
    "fish_catch_id" serial PRIMARY KEY,
    "fishing_record_id" integer NOT NULL,
    "fishing_record_date" date NOT NULL,
    "taxon_id" text REFERENCES "reference"."taxon"("taxon_id"),
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
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
    "created_at" timestamptz DEFAULT CURRENT_TIMESTAMP,
    "created_by" text,
    "last_modified_at" timestamptz DEFAULT CURRENT_TIMESTAMP,
    "last_modified_by" text,
    FOREIGN KEY ("fishing_record_id", "fishing_record_date") REFERENCES "projects"."ProjectWanderfische_FishingData"("fishing_record_id", "record_date")
);

CREATE TABLE IF NOT EXISTS "projects"."ProjectWanderfische_Mail" (
    "mail_id" serial PRIMARY KEY,
    "fishing_record_id" integer,
    "fishing_record_date" date,
    "sender_person_id" text REFERENCES "lims"."personal"("person_id"),
    "recipient_contact_id" text REFERENCES "lims"."external_contacts"("contact_id"),
    "subject" text NOT NULL,
    "body" text,
    "sent_at" timestamptz NOT NULL,
    "attachment" bytea,
    "attachment_link" text,
    "tags" text,
    "notes" text,
    "created_at" timestamptz DEFAULT CURRENT_TIMESTAMP,
    "created_by" text,
    "last_modified_at" timestamptz DEFAULT CURRENT_TIMESTAMP,
    "last_modified_by" text,
    FOREIGN KEY ("fishing_record_id", "fishing_record_date") REFERENCES "projects"."ProjectWanderfische_FishingData"("fishing_record_id", "record_date")
);

CREATE TABLE IF NOT EXISTS "projects"."ProjectWanderfische_Conversation" (
    "conversation_id" serial PRIMARY KEY,
    "fishing_record_id" integer,
    "fishing_record_date" date,
    "topic" text NOT NULL,
    "started_at" timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "last_updated_at" timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "tags" text,
    "notes" text,
    "created_at" timestamptz DEFAULT CURRENT_TIMESTAMP,
    "created_by" text,
    "last_modified_at" timestamptz DEFAULT CURRENT_TIMESTAMP,
    "last_modified_by" text,
    FOREIGN KEY ("fishing_record_id", "fishing_record_date") REFERENCES "projects"."ProjectWanderfische_FishingData"("fishing_record_id", "record_date")
);

-- NEW TABLE: To store individual messages within a conversation.
CREATE TABLE IF NOT EXISTS "projects"."ProjectWanderfische_ChatMessage" (
    "message_id" serial PRIMARY KEY,
    "conversation_id" integer NOT NULL REFERENCES "projects"."ProjectWanderfische_Conversation"("conversation_id"),
    "sender_person_id" text REFERENCES "lims"."personal"("person_id"),
    "sender_contact_id" text REFERENCES "lims"."external_contacts"("contact_id"),
    "message_text" text NOT NULL,
    "sent_at" timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
    "created_at" timestamptz DEFAULT CURRENT_TIMESTAMP,
    "created_by" text,
    CONSTRAINT chk_sender_not_null CHECK (sender_person_id IS NOT NULL OR sender_contact_id IS NOT NULL)
);


-- -- =========================================
-- 10. FUNCTIONS
-- -- =========================================

-- F01. AUDIT LOGGING FUNCTION
CREATE OR REPLACE FUNCTION "audit".if_modified_func() RETURNS TRIGGER AS $$
DECLARE
    v_old_data jsonb;
    v_new_data jsonb;
    v_action text;
    v_person_id text := current_setting('audit.logged_in_user', TRUE); -- Get LIMS user ID
    v_full_name text;
BEGIN
    IF (TG_OP = 'UPDATE') THEN
        v_action := 'U';
        v_old_data := row_to_json(OLD)::jsonb;
        v_new_data := row_to_json(NEW)::jsonb;
    ELSIF (TG_OP = 'DELETE') THEN
        v_action := 'D';
        v_old_data := row_to_json(OLD)::jsonb;
        v_new_data := NULL;
    ELSIF (TG_OP = 'INSERT') THEN
        v_action := 'I';
        v_old_data := NULL;
        v_new_data := row_to_json(NEW)::jsonb;
    ELSE
        RETURN NULL;
    END IF;

    -- Lookup the full name of the logged-in person if the ID is set
    IF v_person_id IS NOT NULL AND v_person_id != '' THEN
        SELECT full_name INTO v_full_name FROM "lims"."personal" WHERE person_id = v_person_id;
        IF NOT FOUND THEN
             -- Handle case where user is a customer/external contact (or 'TIFI' admin)
             v_full_name := 'System User/' || v_person_id;
        END IF;
    END IF;

    INSERT INTO "audit"."log" (
        "schema_name", "table_name", "user_db_name", 
        "logged_in_person_id", "logged_in_full_name", 
        "action", "original_data", "new_data", "query_text"
    )
    VALUES (
        TG_TABLE_SCHEMA::text,
        TG_TABLE_NAME::text,
        current_user::text,
        v_person_id,
        v_full_name,
        v_action,
        v_old_data,
        v_new_data,
        current_query()
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ###################################### 
-- F02a. CENTRALIZED DATE POPULATION FUNCTION
-- This function populates sample_creation_date in child tables from root_samples.
CREATE OR REPLACE FUNCTION "lab".populate_date_from_root_sample()
RETURNS TRIGGER AS $$
DECLARE
    parent_date date;
    parent_id text;
    root_id text;
    root_date date;
BEGIN
    IF NEW.sample_creation_date IS NULL THEN
        -- Get the parent's sample_id
        parent_id := NEW.sample_id;
        -- Lookup the sample_creation_date in the root_samples table
        SELECT rs.sample_creation_date
        INTO parent_date
        FROM "lab"."root_samples" rs
        WHERE rs.sample_id = parent_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Associated root_sample not found for sample_id %', parent_id;
        END IF;
        NEW.sample_creation_date := parent_date;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ########################################### 
-- F02. ID GENERATION FUNCTION (ROOT SAMPLES)

CREATE OR REPLACE FUNCTION "lab".generate_root_sample_id()
RETURNS TRIGGER AS $$
DECLARE
    v_sample_type_abrv text;
    id_prefix text;
    next_serial integer;
    sample_year text;
    project_abrv text;
    customer_abrv text;
BEGIN
    -- This trigger should only run for root samples (those without a parent)
    IF NEW.parent_sample_id IS NOT NULL THEN
      RETURN NEW;
    END IF;
    
    -- Get sample type abbreviation for ID part
    SELECT st."sample_type_abrv" INTO v_sample_type_abrv
    FROM "reference"."samples_type" st
    WHERE st."sample_type_id" = NEW.sample_type_id;

    sample_year := TO_CHAR(COALESCE(NEW.sample_creation_date, CURRENT_DATE), 'YY');
    
    IF NEW.project_id IS NOT NULL THEN
        SELECT p."project_abrv" INTO project_abrv
        FROM "lims"."projects" p
        WHERE p."project_id" = NEW.project_id;
        id_prefix := v_sample_type_abrv || sample_year || project_abrv;
    ELSIF NEW.customer_id IS NOT NULL THEN
        SELECT c."customer_abrv" INTO customer_abrv
        FROM "lims"."customers" c
        WHERE c."customer_id" = NEW.customer_id;
        id_prefix := v_sample_type_abrv || sample_year || customer_abrv;
    ELSE
        RAISE EXCEPTION 'Cannot generate root sample ID: Missing project_id and customer_id.';
    END IF;

    -- Atomically get the next serial number for this prefix
    SELECT COALESCE(MAX(SUBSTRING(rs."sample_id" FROM LENGTH(id_prefix) + 1)::INTEGER), 0)
    INTO next_serial
    FROM "lab"."root_samples" rs
    WHERE rs."sample_id" LIKE id_prefix || '%';

    NEW.sample_id := id_prefix || LPAD((next_serial + 1)::TEXT, 3, '0');
    
    -- Set root_sample_id and its creation date for new root samples
    NEW.root_sample_id := NEW.sample_id;
    NEW.root_sample_creation_date := NEW.sample_creation_date;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- F03. ID GENERATION FUNCTION (CHILD SAMPLES)
CREATE OR REPLACE FUNCTION "lab".generate_child_sample_id()
RETURNS TRIGGER AS $$
DECLARE
    v_sample_type_abrv text;
    id_prefix text;
    next_serial integer;
    parent_record RECORD;
BEGIN
    -- This trigger should only run for child samples
    IF NEW.parent_sample_id IS NULL THEN
        RETURN NEW;
    END IF;

    -- Get sample type abbreviation for ID part
    SELECT st."sample_type_abrv" INTO v_sample_type_abrv
    FROM "reference"."samples_type" st
    WHERE st."sample_type_id" = NEW.sample_type_id;
    
    -- Get parent and root sample info
    SELECT rs.sample_creation_date, rs.root_sample_id, rs.root_sample_creation_date
    INTO parent_record
    FROM "lab"."root_samples" rs
    WHERE rs.sample_id = NEW.parent_sample_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Parent sample ID ''%'' not found. Cannot generate child ID.', NEW.parent_sample_id;
    END IF;


    -- Populate root info from parent record
    NEW.parent_sample_creation_date := parent_record.sample_creation_date;
    NEW.root_sample_id := parent_record.root_sample_id;
    NEW.root_sample_creation_date := parent_record.root_sample_creation_date;
    
    id_prefix := NEW.parent_sample_id || '_' || v_sample_type_abrv;

    SELECT COALESCE(MAX(SUBSTRING(rs."sample_id" FROM LENGTH(id_prefix) + 1)::INTEGER), 0)
    INTO next_serial
    FROM "lab"."root_samples" rs
    WHERE rs."sample_id" LIKE id_prefix || '%';

    NEW.sample_id := id_prefix || (next_serial + 1)::TEXT;
    
    IF NEW.sample_creation_date IS NULL THEN
      NEW.sample_creation_date := CURRENT_DATE;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- F04. COORDINATE TRANSFORMATION FUNCTION
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
    IF p_original_srid = 4326 AND p_longitude IS NOT NULL AND p_latitude IS NOT NULL THEN
        temp_geom := ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326);
    ELSIF p_easting IS NOT NULL AND p_northing IS NOT NULL AND p_original_srid IS NOT NULL AND p_original_srid != 4326 THEN
        BEGIN
            temp_geom := ST_Transform(ST_SetSRID(ST_MakePoint(p_easting, p_northing), p_original_srid), 4326);
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING 'SRID % is not defined or transformation failed for coordinates (%, %). Returning NULL.', p_original_srid, p_easting, p_northing;
                RETURN NULL;
        END;
    ELSE
        RETURN NULL;
    END IF;

    IF temp_geom IS NOT NULL AND ST_GeometryType(temp_geom) = 'ST_Point' THEN
        RETURN temp_geom;
    ELSE
        RAISE WARNING 'Transformed geometry is not a valid POINT type. Returning NULL.';
        RETURN NULL;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- F05. RLS POLICY HELPER FUNCTION
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

-- F06. LTREE PATH UPDATE FUNCTION
CREATE OR REPLACE FUNCTION "reference".update_taxon_ltree_path_for_row()
RETURNS TRIGGER AS $$
DECLARE
    parent_path ltree;
BEGIN
    IF NEW.taxon_parent IS NOT NULL THEN
        SELECT path INTO parent_path FROM "reference"."taxon" WHERE taxon_id = NEW.taxon_parent;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Parent taxon with ID % not found.', NEW.taxon_parent;
        END IF;
        NEW.path := parent_path || NEW.taxon_id;
    ELSE
        NEW.path := NEW.taxon_id::ltree;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- F07. STATUS UPDATE FUNCTION
CREATE OR REPLACE FUNCTION "lab".update_sample_status()
RETURNS TRIGGER AS $$
DECLARE
    new_status_id text := NEW.status_id;
BEGIN
    IF new_status_id IS NOT NULL THEN
      UPDATE "lab"."root_samples"
      SET status_id = new_status_id
      WHERE sample_id = NEW.sample_id AND sample_creation_date = NEW.sample_creation_date;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- F08. ID GENERATION FUNCTIONS (VARIOUS TABLES)
CREATE OR REPLACE FUNCTION "lab".generate_sampling_id() RETURNS TRIGGER AS $$
DECLARE sampling_year text; ecosystem_abrv text; region_abrv text; id_prefix text; next_serial integer;
BEGIN
    sampling_year := TO_CHAR(COALESCE(NEW.sampling_date, CURRENT_DATE), 'YY');
    SELECT COALESCE(e.ecosystem_abrv, 'UNK') INTO ecosystem_abrv FROM "reference"."ecosystem" e WHERE e.ecosystem_id = NEW.ecosystem_id;
    SELECT COALESCE(r.region_abrv, 'UNK') INTO region_abrv FROM "reference"."region" r WHERE r.region_id = NEW.region_id;
    id_prefix := sampling_year || ecosystem_abrv || region_abrv;
    SELECT COALESCE(MAX(SUBSTRING("sampling_id" FROM LENGTH(id_prefix) + 1)::INTEGER), 0) INTO next_serial FROM "lab"."sampling" WHERE "sampling_id" LIKE id_prefix || '%';
    NEW.sampling_id := id_prefix || LPAD((next_serial + 1)::TEXT, 3, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "lab".generate_fishing_id() RETURNS TRIGGER AS $$
DECLARE next_serial integer; id_prefix text;
BEGIN
    id_prefix := NEW.sampling_id || '_f';
    SELECT COALESCE(MAX(SUBSTRING("fishing_id" FROM LENGTH(id_prefix) + 1)::INTEGER), 0) INTO next_serial FROM "lab"."fishing" WHERE "fishing_id" LIKE id_prefix || '%';
    NEW.fishing_id := id_prefix || LPAD((next_serial + 1)::TEXT, 3, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "lab".generate_individual_catch_id() RETURNS TRIGGER AS $$
DECLARE next_serial integer; id_prefix text;
BEGIN
    id_prefix := NEW.sampling_id || '_ic';
    SELECT COALESCE(MAX(SUBSTRING("individual_catch_id" FROM LENGTH(id_prefix) + 1)::INTEGER), 0) INTO next_serial FROM "lab"."individual_catch_catch" WHERE "individual_catch_id" LIKE id_prefix || '%';
    NEW.individual_catch_id := id_prefix || LPAD((next_serial + 1)::TEXT, 3, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "lab".generate_dissection_id() RETURNS TRIGGER AS $$
DECLARE next_serial integer; id_prefix text;
BEGIN
    id_prefix := NEW.sample_id || '_d';
    SELECT COALESCE(MAX(SUBSTRING("dissection_id" FROM LENGTH(id_prefix) + 1)::INTEGER), 0) INTO next_serial FROM "lab"."dissections" WHERE "dissection_id" LIKE id_prefix || '%';
    NEW.dissection_id := id_prefix || (next_serial + 1)::TEXT;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "lab".generate_nanodrop_id() RETURNS TRIGGER AS $$
DECLARE next_serial integer; id_prefix text;
BEGIN
    id_prefix := NEW.sample_id || '_n';
    SELECT COALESCE(MAX(SUBSTRING("nanodrop_id" FROM LENGTH(id_prefix) + 1)::INTEGER), 0) INTO next_serial FROM "lab"."nanodrop" WHERE "nanodrop_id" LIKE id_prefix || '%';
    NEW.nanodrop_id := id_prefix || (next_serial + 1)::TEXT;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "lab".generate_qubit_id() RETURNS TRIGGER AS $$
DECLARE next_serial integer; id_prefix text;
BEGIN
    id_prefix := NEW.sample_id || '_q';
    SELECT COALESCE(MAX(SUBSTRING("qubit_id" FROM LENGTH(id_prefix) + 1)::INTEGER), 0) INTO next_serial FROM "lab"."qubit" WHERE "qubit_id" LIKE id_prefix || '%';
    NEW.qubit_id := id_prefix || (next_serial + 1)::TEXT;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "lab".generate_tapestation_id() RETURNS TRIGGER AS $$
DECLARE next_serial integer; id_prefix text;
BEGIN
    id_prefix := NEW.sample_id || '_t';
    SELECT COALESCE(MAX(SUBSTRING("tapestation_id" FROM LENGTH(id_prefix) + 1)::INTEGER), 0) INTO next_serial FROM "lab"."tapestation" WHERE "tapestation_id" LIKE id_prefix || '%';
    NEW.tapestation_id := id_prefix || (next_serial + 1)::TEXT;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "lab".generate_gelelectrophoresis_id() RETURNS TRIGGER AS $$
DECLARE next_serial integer; id_prefix text;
BEGIN
    id_prefix := NEW.sample_id || '_gel';
    SELECT COALESCE(MAX(SUBSTRING("gelelectrophoresis_id" FROM LENGTH(id_prefix) + 1)::INTEGER), 0) INTO next_serial FROM "lab"."gelelectrophoresis" WHERE "gelelectrophoresis_id" LIKE id_prefix || '%';
    NEW.gelelectrophoresis_id := id_prefix || (next_serial + 1)::TEXT;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "lab".generate_pcr_id() RETURNS TRIGGER AS $$
DECLARE next_serial integer; id_prefix text; pcr_year text;
BEGIN
    pcr_year := TO_CHAR(COALESCE(NEW.pcr_date, CURRENT_DATE), 'YY');
    id_prefix := 'pcr' || pcr_year || '_';
    SELECT COALESCE(MAX(SUBSTRING("pcr_id" FROM LENGTH(id_prefix) + 1)::INTEGER), 0) INTO next_serial FROM "lab"."pcr" WHERE "pcr_id" LIKE id_prefix || '%';
    NEW.pcr_id := id_prefix || LPAD((next_serial + 1)::TEXT, 3, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "lab".generate_qpcr_id() RETURNS TRIGGER AS $$
DECLARE next_serial integer; id_prefix text; qpcr_year text;
BEGIN
    qpcr_year := TO_CHAR(COALESCE(NEW.qpcr_date, CURRENT_DATE), 'YY');
    id_prefix := 'qpcr' || qpcr_year || '_';
    SELECT COALESCE(MAX(SUBSTRING("qpcr_id" FROM LENGTH(id_prefix) + 1)::INTEGER), 0) INTO next_serial FROM "lab"."qpcr" WHERE "qpcr_id" LIKE id_prefix || '%';
    NEW.qpcr_id := id_prefix || LPAD((next_serial + 1)::TEXT, 3, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "lab".generate_sequencing_run_id() RETURNS TRIGGER AS $$
DECLARE current_year text; next_serial integer; id_prefix text;
BEGIN
    current_year := TO_CHAR(COALESCE(NEW.experiment_date, CURRENT_DATE), 'YY');
    id_prefix := 'RS' || current_year || '_';
    SELECT COALESCE(MAX(SUBSTRING("sequencing_run_id" FROM LENGTH(id_prefix) + 1)::INTEGER), 0) INTO next_serial FROM "lab"."sequencing_run" WHERE "sequencing_run_id" LIKE id_prefix || '%';
    NEW.sequencing_run_id := id_prefix || LPAD((next_serial + 1)::TEXT, 3, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "lab".generate_seq_dataset_id() RETURNS TRIGGER AS $$
DECLARE next_serial integer; id_prefix text; dataset_year text;
BEGIN
    dataset_year := TO_CHAR(COALESCE(NEW.data_seq_date, CURRENT_DATE), 'YY');
    id_prefix := 'S' || dataset_year || '_' || NEW.sample_id || '_';
    SELECT COALESCE(MAX(SUBSTRING("data_seq_id" FROM LENGTH(id_prefix) + 1)::INTEGER), 0) INTO next_serial FROM "lab"."seq_dataset" WHERE "data_seq_id" LIKE id_prefix || '%';
    NEW.data_seq_id := id_prefix || LPAD((next_serial + 1)::TEXT, 3, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "lab".generate_dataset_id() RETURNS TRIGGER AS $$
DECLARE dataset_year text; next_serial integer; id_prefix text;
BEGIN
    dataset_year := TO_CHAR(COALESCE(NEW.reception_date, CURRENT_DATE), 'YY');
    id_prefix := 'Z' || dataset_year || SUBSTRING(NEW.sample_id FROM 1 FOR 5) || '_';
    SELECT COALESCE(MAX(SUBSTRING("dataset_id" FROM LENGTH(id_prefix) + 1)::INTEGER), 0) INTO next_serial FROM "lab"."datasets" WHERE "dataset_id" LIKE id_prefix || '%';
    NEW.dataset_id := id_prefix || LPAD((next_serial + 1)::TEXT, 3, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "bioinformatics".generate_pipeline_id() RETURNS TRIGGER AS $$
DECLARE current_year text; next_serial integer; id_prefix text;
BEGIN
    current_year := TO_CHAR(CURRENT_DATE, 'YY');
    id_prefix := 'BI' || current_year || '_p';
    SELECT COALESCE(MAX(SUBSTRING("pipeline_id" FROM LENGTH(id_prefix) + 1)::INTEGER), 0) INTO next_serial FROM "bioinformatics"."analysis_pipelines" WHERE "pipeline_id" LIKE id_prefix || '%';
    NEW.pipeline_id := id_prefix || LPAD((next_serial + 1)::TEXT, 3, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "bioinformatics".generate_analysis_run_id() RETURNS TRIGGER AS $$
DECLARE current_year text; next_serial integer; id_prefix text;
BEGIN
    current_year := TO_CHAR(COALESCE(NEW.run_date, CURRENT_DATE), 'YY');
    id_prefix := 'BI' || current_year || '_ar';
    SELECT COALESCE(MAX(SUBSTRING("run_id" FROM LENGTH(id_prefix) + 1)::INTEGER), 0) INTO next_serial FROM "bioinformatics"."analysis_runs" WHERE "run_id" LIKE id_prefix || '%';
    NEW.run_id := id_prefix || LPAD((next_serial + 1)::TEXT, 3, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "bioinformatics".generate_edna_assignment_id() RETURNS TRIGGER AS $$
DECLARE current_year text; next_serial integer; id_prefix text;
BEGIN
    current_year := TO_CHAR(COALESCE(NEW.assignment_date, CURRENT_DATE), 'YY');
    id_prefix := 'BI' || current_year || '_' || NEW.sample_id || '_';
    SELECT COALESCE(MAX(SUBSTRING("assignment_id" FROM LENGTH(id_prefix) + 1)::INTEGER), 0) INTO next_serial FROM "bioinformatics"."edna_assignments" WHERE "assignment_id" LIKE id_prefix || '%';
    NEW.assignment_id := id_prefix || LPAD((next_serial + 1)::TEXT, 3, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- F15. RESERVATION ID GENERATION FUNCTION (NEW)
CREATE OR REPLACE FUNCTION "lab".generate_reservation_sample_id()
RETURNS TRIGGER AS $$
DECLARE
    v_sample_type_abrv text;
    v_ecosystem_abrv text;
    v_region_abrv text;
    id_prefix text;
    next_serial integer;
    reservation_year text;
    sampling_record RECORD;
BEGIN
    -- 1. Get abbreviations and year
    SELECT st."sample_type_abrv" INTO v_sample_type_abrv
    FROM "reference"."samples_type" st
    WHERE st."sample_type_id" = NEW.sample_type_id;

    reservation_year := TO_CHAR(COALESCE(NEW.planned_collection_date, CURRENT_DATE), 'YY');
    
    -- 2. Get Ecosystem and Region from linked Sampling record
    SELECT s.ecosystem_id, s.region_id
    INTO sampling_record
    FROM "lab"."sampling" s
    WHERE s.sampling_id = NEW.sampling_id AND s.sampling_date = NEW.sampling_date;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Associated sampling record not found for sampling_id % and sampling_date %.', NEW.sampling_id, NEW.sampling_date;
    END IF;

    SELECT COALESCE(e.ecosystem_abrv, 'UNK') INTO v_ecosystem_abrv FROM "reference"."ecosystem" e WHERE e.ecosystem_id = sampling_record.ecosystem_id;
    SELECT COALESCE(r.region_abrv, 'UNK') INTO v_region_abrv FROM "reference"."region" r WHERE r.region_id = sampling_record.region_id;

    -- 3. Construct prefix
    id_prefix := v_sample_type_abrv || reservation_year || v_ecosystem_abrv || v_region_abrv || '_';

    -- 4. Atomically get the next serial number for this prefix
    SELECT COALESCE(MAX(SUBSTRING(rs."reservation_sample_id" FROM LENGTH(id_prefix) + 1)::INTEGER), 0)
    INTO next_serial
    FROM "lab"."reservation_samples" rs
    WHERE rs."reservation_sample_id" LIKE id_prefix || '%';

    -- 5. Assign the new ID
    NEW.reservation_sample_id := id_prefix || LPAD((next_serial + 1)::TEXT, 4, '0');

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- F09. FULL-TEXT SEARCH SETUP AND FUNCTIONS
-- Create a custom text search configuration
CREATE TEXT SEARCH DICTIONARY english_stem (TEMPLATE = snowball, LANGUAGE = english);
CREATE TEXT SEARCH CONFIGURATION public.lims_english (COPY = english);
ALTER TEXT SEARCH CONFIGURATION public.lims_english ALTER MAPPING FOR asciiword, asciihword, hword, hword_part, word WITH english_stem;

-- Add tsvector columns to tables
ALTER TABLE "lims"."personal" ADD COLUMN IF NOT EXISTS "personal_search_vector" tsvector;
ALTER TABLE "lims"."external_contacts" ADD COLUMN IF NOT EXISTS "contacts_search_vector" tsvector;
ALTER TABLE "lims"."customers" ADD COLUMN IF NOT EXISTS "customer_search_vector" tsvector;
ALTER TABLE "lims"."projects" ADD COLUMN IF NOT EXISTS "project_search_vector" tsvector;
ALTER TABLE "lims"."sop" ADD COLUMN IF NOT EXISTS "sop_search_vector" tsvector;
ALTER TABLE "lims"."equipment" ADD COLUMN IF NOT EXISTS "equipment_search_vector" tsvector;
ALTER TABLE "lims"."suppliers" ADD COLUMN IF NOT EXISTS "supplier_search_vector" tsvector;
ALTER TABLE "lims"."inventory_items" ADD COLUMN IF NOT EXISTS "inventory_search_vector" tsvector;
ALTER TABLE "lims"."reagents" ADD COLUMN IF NOT EXISTS "reagent_search_vector" tsvector;
ALTER TABLE "lims"."publications" ADD COLUMN IF NOT EXISTS "publication_search_vector" tsvector;
ALTER TABLE "lab"."experiments" ADD COLUMN IF NOT EXISTS "experiment_search_vector" tsvector;
ALTER TABLE "lab"."root_samples" ADD COLUMN IF NOT EXISTS "sample_search_vector" tsvector;
ALTER TABLE "projects"."ProjectWanderfische_FishingData" ADD COLUMN IF NOT EXISTS "fishing_data_search_vector" tsvector;
ALTER TABLE "projects"."ProjectWanderfische_FishCatch" ADD COLUMN IF NOT EXISTS "fish_catch_search_vector" tsvector;
ALTER TABLE "projects"."ProjectWanderfische_Mail" ADD COLUMN IF NOT EXISTS "mail_search_vector" tsvector;
ALTER TABLE "projects"."ProjectWanderfische_Conversation" ADD COLUMN IF NOT EXISTS "conversation_search_vector" tsvector;
ALTER TABLE "projects"."ProjectWanderfische_ChatMessage" ADD COLUMN IF NOT EXISTS "chat_message_search_vector" tsvector;
ALTER TABLE "lab"."storage" ADD COLUMN IF NOT EXISTS "storage_search_vector" tsvector;
ALTER TABLE "bioinformatics"."analysis_pipelines" ADD COLUMN IF NOT EXISTS "pipeline_search_vector" tsvector;
ALTER TABLE "bioinformatics"."analysis_runs" ADD COLUMN IF NOT EXISTS "runs_search_vector" tsvector;

-- Trigger functions to update tsvector columns
CREATE TRIGGER trg_generate_reservation_sample_id BEFORE INSERT ON "lab"."reservation_samples" FOR EACH ROW EXECUTE FUNCTION "lab".generate_reservation_sample_id();
CREATE TRIGGER audit_trigger_reservation_samples AFTER INSERT OR UPDATE OR DELETE ON "lab"."reservation_samples" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();

CREATE OR REPLACE FUNCTION "lims".update_personal_search_vector_func() RETURNS TRIGGER AS $$ BEGIN NEW.personal_search_vector = TO_TSVECTOR('public.lims_english', COALESCE(NEW.full_name, '')) || TO_TSVECTOR('public.lims_english', COALESCE(NEW.mail, '')) || TO_TSVECTOR('public.lims_english', COALESCE(NEW.notes, '')); RETURN NEW; END; $$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION "lims".update_contacts_search_vector_func() RETURNS TRIGGER AS $$ BEGIN NEW.contacts_search_vector = TO_TSVECTOR('public.lims_english', COALESCE(NEW.full_name, '')) || TO_TSVECTOR('public.lims_english', COALESCE(NEW.organization, '')) || TO_TSVECTOR('public.lims_english', COALESCE(NEW.mail, '')) || TO_TSVECTOR('public.lims_english', COALESCE(NEW.notes, '')); RETURN NEW; END; $$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION "lims".update_customer_search_vector_func() RETURNS TRIGGER AS $$ BEGIN NEW.customer_search_vector = TO_TSVECTOR('public.lims_english', COALESCE(NEW.customer_name, '')) || TO_TSVECTOR('public.lims_english', COALESCE(NEW.customer_abrv, '')) || TO_TSVECTOR('public.lims_english', COALESCE(NEW.notes, '')); RETURN NEW; END; $$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION "lims".update_project_search_vector_func() RETURNS TRIGGER AS $$ BEGIN NEW.project_search_vector = TO_TSVECTOR('public.lims_english', COALESCE(NEW.project_id, '')) || TO_TSVECTOR('public.lims_english', COALESCE(NEW.title, '')) || TO_TSVECTOR('public.lims_english', COALESCE(NEW.description, '')) || TO_TSVECTOR('public.lims_english', COALESCE(NEW.notes, '')); RETURN NEW; END; $$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION "lims".update_sop_search_vector_func() RETURNS TRIGGER AS $$ BEGIN NEW.sop_search_vector = TO_TSVECTOR('public.lims_english', COALESCE(NEW.sop_id_origin, '')) || TO_TSVECTOR('public.lims_english', COALESCE(NEW.title, '')) || TO_TSVECTOR('public.lims_english', COALESCE(NEW.sop_protocol, '')) || TO_TSVECTOR('public.lims_english', COALESCE(NEW.notes, '')); RETURN NEW; END; $$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION "lims".update_equipment_search_vector_func() RETURNS TRIGGER AS $$ BEGIN NEW.equipment_search_vector = TO_TSVECTOR('public.lims_english', COALESCE(NEW.equipment_name, '')) || TO_TSVECTOR('public.lims_english', COALESCE(NEW.lot, '')) || TO_TSVECTOR('public.lims_english', COALESCE(NEW.notes, '')); RETURN NEW; END; $$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION "lims".update_supplier_search_vector_func() RETURNS TRIGGER AS $$ BEGIN NEW.supplier_search_vector = TO_TSVECTOR('public.lims_english', COALESCE(NEW.supplier_name, '')) || TO_TSVECTOR('public.lims_english', COALESCE(NEW.contact_person, '')) || TO_TSVECTOR('public.lims_english', COALESCE(NEW.notes, '')); RETURN NEW; END; $$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION "lims".update_inventory_search_vector_func() RETURNS TRIGGER AS $$ BEGIN NEW.inventory_search_vector = TO_TSVECTOR('public.lims_english', COALESCE(NEW.item_name, '')) || TO_TSVECTOR('public.lims_english', COALESCE(NEW.notes, '')); RETURN NEW; END; $$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION "lims".update_reagent_search_vector_func() RETURNS TRIGGER AS $$ BEGIN NEW.reagent_search_vector = TO_TSVECTOR('public.lims_english', COALESCE(NEW.reagent_complete_name, '')) || TO_TSVECTOR('public.lims_english', COALESCE(NEW.lot, '')) || TO_TSVECTOR('public.lims_english', COALESCE(NEW.notes, '')); RETURN NEW; END; $$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION "lims".update_publication_search_vector_func() RETURNS TRIGGER AS $$ BEGIN NEW.publication_search_vector = TO_TSVECTOR('public.lims_english', COALESCE(NEW.title, '')) || TO_TSVECTOR('public.lims_english', COALESCE(NEW.journal, '')) || TO_TSVECTOR('public.lims_english', COALESCE(NEW.notes, '')); RETURN NEW; END; $$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION "lab".update_experiment_search_vector_func() RETURNS TRIGGER AS $$ BEGIN NEW.experiment_search_vector = TO_TSVECTOR('public.lims_english', COALESCE(NEW.experiment_title, '')) || TO_TSVECTOR('public.lims_english', COALESCE(NEW.aim, '')) || TO_TSVECTOR('public.lims_english', COALESCE(NEW.method, '')) || TO_TSVECTOR('public.lims_english', COALESCE(NEW.notes, '')); RETURN NEW; END; $$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION "lab".update_sample_search_vector_func() RETURNS TRIGGER AS $$ BEGIN NEW.sample_search_vector = TO_TSVECTOR('public.lims_english', COALESCE(NEW.external_name, '')) || TO_TSVECTOR('public.lims_english', COALESCE(NEW.notes, '')); RETURN NEW; END; $$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION "projects".update_fishing_data_search_vector_func() RETURNS TRIGGER AS $$ BEGIN NEW.fishing_data_search_vector = TO_TSVECTOR('public.lims_english', COALESCE(NEW.location_description, '')) || TO_TSVECTOR('public.lims_english', COALESCE(NEW.water_body_name, '')) || TO_TSVECTOR('public.lims_english', COALESCE(NEW.fishing_method, '')) || TO_TSVECTOR('public.lims_english', COALESCE(NEW.notes, '')) || TO_TSVECTOR('public.lims_english', COALESCE(NEW.original_data_jsonb::text, '')); RETURN NEW; END; $$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION "projects".update_fish_catch_search_vector_func() RETURNS TRIGGER AS $$ BEGIN NEW.fish_catch_search_vector = TO_TSVECTOR('public.lims_english', COALESCE(NEW.scientific_name_raw, '')) || TO_TSVECTOR('public.lims_english', COALESCE(NEW.german_name_raw, '')) || TO_TSVECTOR('public.lims_english', COALESCE(NEW.notes, '')); RETURN NEW; END; $$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION "projects".update_mail_search_vector_func() RETURNS TRIGGER AS $$ BEGIN NEW.mail_search_vector = TO_TSVECTOR('public.lims_english', COALESCE(NEW.subject, '')) || TO_TSVECTOR('public.lims_english', COALESCE(NEW.body, '')) || TO_TSVECTOR('public.lims_english', COALESCE(NEW.notes, '')); RETURN NEW; END; $$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION "projects".update_conversation_search_vector_func() RETURNS TRIGGER AS $$ BEGIN NEW.conversation_search_vector = TO_TSVECTOR('public.lims_english', COALESCE(NEW.topic, '')) || TO_TSVECTOR('public.lims_english', COALESCE(NEW.notes, '')); RETURN NEW; END; $$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION "projects".update_chat_message_search_vector_func() RETURNS TRIGGER AS $$ BEGIN NEW.chat_message_search_vector = TO_TSVECTOR('public.lims_english', COALESCE(NEW.message_text, '')); RETURN NEW; END; $$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION "lab".update_storage_search_vector_func() RETURNS TRIGGER AS $$ BEGIN NEW.storage_search_vector = TO_TSVECTOR('public.lims_english', COALESCE(NEW.freezer, '')) || TO_TSVECTOR('public.lims_english', COALESCE(NEW.box, '')) || TO_TSVECTOR('public.lims_english', COALESCE(NEW.address, '')) || TO_TSVECTOR('public.lims_english', COALESCE(NEW.notes, '')); RETURN NEW; END; $$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION "bioinformatics".update_pipeline_search_vector_func() RETURNS TRIGGER AS $$ BEGIN NEW.pipeline_search_vector = TO_TSVECTOR('public.lims_english', COALESCE(NEW.pipeline_name, '')) || TO_TSVECTOR('public.lims_english', COALESCE(NEW.version, '')) || TO_TSVECTOR('public.lims_english', COALESCE(NEW.notes, '')); RETURN NEW; END; $$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION "bioinformatics".update_runs_search_vector_func() RETURNS TRIGGER AS $$ BEGIN NEW.runs_search_vector = TO_TSVECTOR('public.lims_english', COALESCE(NEW.run_id, '')) || TO_TSVECTOR('public.lims_english', COALESCE(NEW.final_output_path, '')) || TO_TSVECTOR('public.lims_english', COALESCE(NEW.notes, '')); RETURN NEW; END; $$ LANGUAGE plpgsql;

-- F10. SET DEFAULT STATUS FUNCTION
CREATE OR REPLACE FUNCTION set_default_status_on_insert()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status_id IS NULL THEN
        NEW.status_id := 'Received'; -- Or 'Planned', 'New', etc.
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- F11. GLOBAL SEARCH FUNCTION
CREATE OR REPLACE FUNCTION "public".search_all_tables(p_search_term text)
RETURNS TABLE(schema_name text, table_name text, matching_row jsonb) AS $$
DECLARE
    rec RECORD;
    query text;
BEGIN
    FOR rec IN
        SELECT
            c.table_schema,
            c.table_name,
            c.column_name
        FROM
            information_schema.columns c
        WHERE
            c.table_schema IN ('lab', 'lims', 'reference', 'bioinformatics', 'projects')
            AND c.column_name LIKE '%_search_vector'
    LOOP
        query := format(
            'SELECT %L, %L, to_jsonb(t) FROM %I.%I AS t WHERE %I @@ to_tsquery(''public.lims_english'', %L)',
            rec.table_schema,
            rec.table_name,
            rec.table_schema,
            rec.table_name,
            rec.column_name,
            p_search_term
        );
        RETURN QUERY EXECUTE query;
    END LOOP;
END;
$$ LANGUAGE plpgsql;


-- -- =========================================
-- 11. PARTITION MANAGEMENT & DATE PROPAGATION
-- -- =========================================
-- 11.1. DYNAMIC PARTITION MANAGEMENT FUNCTION
CREATE OR REPLACE FUNCTION manage_partitions(p_schema_name TEXT, p_table_name TEXT, p_target_date DATE)
RETURNS VOID AS $$
DECLARE
    partition_name TEXT;
    partition_start_date DATE;
    partition_end_date DATE;
BEGIN
    -- Calculate the start and end of the month for the given target date.
    partition_start_date := date_trunc('month', p_target_date)::DATE;
    partition_end_date := (partition_start_date + INTERVAL '1 month')::DATE;
    
    -- Define a standardized partition name (e.g., experiments_y2025m09).
    partition_name := format('%s_y%sm%s', p_table_name, to_char(partition_start_date, 'YYYY'), to_char(partition_start_date, 'MM'));

    -- Check if the partition already exists to prevent errors.
    IF NOT EXISTS (
        SELECT 1
        FROM pg_class AS c
        JOIN pg_namespace AS n ON c.relnamespace = n.oid
        WHERE n.nspname = p_schema_name AND c.relname = partition_name
    ) THEN
        -- If it doesn't exist, create it using dynamic SQL.
        RAISE NOTICE 'Creating partition % for table %.%', partition_name, p_schema_name, p_table_name;
        EXECUTE format(
            'CREATE TABLE %I.%I PARTITION OF %I.%I FOR VALUES FROM (%L) TO (%L);',
            p_schema_name,
            partition_name,
            p_schema_name,
            p_table_name,
            partition_start_date,
            partition_end_date
        );
    ELSE
        RAISE NOTICE 'Partition % for table %.% already exists.', partition_name, p_schema_name, p_table_name;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- 11.2. DATE PROPAGATION FUNCTIONS
-- Function for tables linked to "lab"."root_samples"
CREATE OR REPLACE FUNCTION lab.copy_date_from_root_sample()
RETURNS TRIGGER AS $$
DECLARE
    v_parent_date DATE;
    v_parent_id TEXT;
BEGIN
    v_parent_id := CASE
        WHEN TG_TABLE_NAME = 'otoliths' THEN NEW.parent_sample_id
        ELSE NEW.sample_id
    END;

    SELECT sample_creation_date INTO v_parent_date
    FROM lab.root_samples
    WHERE sample_id = v_parent_id AND sample_creation_date = NEW.sample_creation_date;

    IF v_parent_date IS NULL THEN
        RAISE EXCEPTION 'Parent sample with id % and date % not found in lab.root_samples. Cannot insert into %', v_parent_id, NEW.sample_creation_date, TG_TABLE_NAME;
    END IF;

    NEW.sample_creation_date := v_parent_date;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function for tables linked to "lab"."experiments"
CREATE OR REPLACE FUNCTION lab.copy_date_from_experiment()
RETURNS TRIGGER AS $$
DECLARE
    v_parent_date DATE;
BEGIN
    SELECT experiment_date INTO v_parent_date
    FROM lab.experiments
    WHERE experiment_id = NEW.experiment_id AND experiment_date = NEW.experiment_date;

    IF v_parent_date IS NULL THEN
        RAISE EXCEPTION 'Parent experiment with id % and date % not found in lab.experiments. Cannot insert into %', NEW.experiment_id, NEW.experiment_date, TG_TABLE_NAME;
    END IF;

    NEW.experiment_date := v_parent_date;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to set date columns to current date if NULL
CREATE OR REPLACE FUNCTION "public".populate_date_if_null()
RETURNS TRIGGER AS $$
DECLARE
    date_col_name TEXT;
BEGIN
    -- Determine which date column to populate based on the table name
    date_col_name := CASE TG_TABLE_NAME
        WHEN 'analysis_runs' THEN 'run_date'
        WHEN 'pcr' THEN 'pcr_date'
        WHEN 'qpcr' THEN 'qpcr_date'
        WHEN 'seq_dataset' THEN 'data_seq_date'
        WHEN 'edna_assignments' THEN 'assignment_date'
        ELSE NULL
    END;

    IF date_col_name IS NOT NULL THEN
        -- Using EXECUTE to dynamically set the column value
        EXECUTE format('SELECT ($1).%I IS NULL', date_col_name) USING NEW
        INTO date_col_name; -- Re-using variable to check for NULL

        IF date_col_name THEN -- If it was NULL
            EXECUTE format('NEW.%I := CURRENT_DATE;', date_col_name);
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- #######################
-- F12. SET DEFAULT STATUS FUNCTION

CREATE OR REPLACE FUNCTION set_default_status_on_insert()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status_id IS NULL THEN
        NEW.status_id := 'Received';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- F13. POPULATE DATE FROM PARENT TABLES
-- These functions ensure the date columns are populated from a parent table before a trigger for partitioning can fire.
CREATE OR REPLACE FUNCTION "lab".populate_date_from_experiment()
RETURNS TRIGGER AS $$
DECLARE parent_date date;
BEGIN
    SELECT "experiment_date" INTO parent_date FROM "lab"."experiments" WHERE "experiment_id" = NEW.experiment_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Associated experiment not found for experiment_id %', NEW.experiment_id; END IF;
    NEW.experiment_date := parent_date;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "lab".populate_date_from_sampling()
RETURNS TRIGGER AS $$
DECLARE parent_date date;
BEGIN
    SELECT "sampling_date" INTO parent_date FROM "lab"."sampling" WHERE "sampling_id" = NEW.sampling_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Associated sampling record not found for sampling_id %', NEW.sampling_id; END IF;
    NEW.sampling_date := parent_date;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "bioinformatics".populate_date_from_sequencing()
RETURNS TRIGGER AS $$
DECLARE parent_date date;
BEGIN
    SELECT "experiment_date" INTO parent_date FROM "lab"."sequencing_run" WHERE "sequencing_run_id" = NEW.sequencing_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Associated sequencing run not found for sequencing_id %', NEW.sequencing_id; END IF;
    NEW.sequencing_date := parent_date;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- F14. POPULATE RUN DATE
CREATE OR REPLACE FUNCTION "bioinformatics".populate_run_date()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.run_date IS NULL THEN
    NEW.run_date := CURRENT_DATE;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "lab".populate_pcr_date()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.pcr_date IS NULL THEN
    NEW.pcr_date := CURRENT_DATE;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "lab".populate_qpcr_date()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.qpcr_date IS NULL THEN
    NEW.qpcr_date := CURRENT_DATE;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION "lab".populate_seq_dataset_date()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.data_seq_date IS NULL THEN
    NEW.data_seq_date := CURRENT_DATE;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
-- ##########################################

-- -- =========================================
-- 12. TRIGGERS
-- -- =========================================

-- 12.1. Triggers for Automatic ID Generation
CREATE TRIGGER trg_generate_root_sample_id BEFORE INSERT ON "lab"."root_samples" FOR EACH ROW WHEN (NEW.parent_sample_id IS NULL) EXECUTE FUNCTION "lab".generate_root_sample_id();
CREATE TRIGGER trg_generate_child_sample_id BEFORE INSERT ON "lab"."root_samples" FOR EACH ROW WHEN (NEW.parent_sample_id IS NOT NULL) EXECUTE FUNCTION "lab".generate_child_sample_id();
CREATE TRIGGER trg_generate_sampling_id BEFORE INSERT ON "lab"."sampling" FOR EACH ROW EXECUTE FUNCTION "lab".generate_sampling_id();
CREATE TRIGGER trg_generate_fishing_id BEFORE INSERT ON "lab"."fishing" FOR EACH ROW EXECUTE FUNCTION "lab".generate_fishing_id();
CREATE TRIGGER trg_generate_individual_catch_id BEFORE INSERT ON "lab"."individual_catch_catch" FOR EACH ROW EXECUTE FUNCTION "lab".generate_individual_catch_id();
CREATE TRIGGER trg_generate_dissection_id BEFORE INSERT ON "lab"."dissections" FOR EACH ROW EXECUTE FUNCTION "lab".generate_dissection_id();
CREATE TRIGGER trg_generate_nanodrop_id BEFORE INSERT ON "lab"."nanodrop" FOR EACH ROW EXECUTE FUNCTION "lab".generate_nanodrop_id();
CREATE TRIGGER trg_generate_qubit_id BEFORE INSERT ON "lab"."qubit" FOR EACH ROW EXECUTE FUNCTION "lab".generate_qubit_id();
CREATE TRIGGER trg_generate_tapestation_id BEFORE INSERT ON "lab"."tapestation" FOR EACH ROW EXECUTE FUNCTION "lab".generate_tapestation_id();
CREATE TRIGGER trg_generate_gelelectrophoresis_id BEFORE INSERT ON "lab"."gelelectrophoresis" FOR EACH ROW EXECUTE FUNCTION "lab".generate_gelelectrophoresis_id();
CREATE TRIGGER trg_generate_pcr_id BEFORE INSERT ON "lab"."pcr" FOR EACH ROW EXECUTE FUNCTION "lab".generate_pcr_id();
CREATE TRIGGER trg_generate_qpcr_id BEFORE INSERT ON "lab"."qpcr" FOR EACH ROW EXECUTE FUNCTION "lab".generate_qpcr_id();
CREATE TRIGGER trg_generate_sequencing_run_id BEFORE INSERT ON "lab"."sequencing_run" FOR EACH ROW EXECUTE FUNCTION "lab".generate_sequencing_run_id();
CREATE TRIGGER trg_generate_seq_dataset_id BEFORE INSERT ON "lab"."seq_dataset" FOR EACH ROW EXECUTE FUNCTION "lab".generate_seq_dataset_id();
CREATE TRIGGER trg_generate_dataset_id BEFORE INSERT ON "lab"."datasets" FOR EACH ROW EXECUTE FUNCTION "lab".generate_dataset_id();
CREATE TRIGGER trg_generate_pipeline_id BEFORE INSERT ON "bioinformatics"."analysis_pipelines" FOR EACH ROW EXECUTE FUNCTION "bioinformatics".generate_pipeline_id();
CREATE TRIGGER trg_generate_analysis_run_id BEFORE INSERT ON "bioinformatics"."analysis_runs" FOR EACH ROW EXECUTE FUNCTION "bioinformatics".generate_analysis_run_id();
CREATE TRIGGER trg_generate_edna_assignment_id BEFORE INSERT ON "bioinformatics"."edna_assignments" FOR EACH ROW EXECUTE FUNCTION "bioinformatics".generate_edna_assignment_id();

-- ###########################################
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
CREATE TRIGGER trg_populate_qpcr_date BEFORE INSERT ON "lab"."qpcr" FOR EACH ROW EXECUTE FUNCTION "lab".populate_date_from_root_sample();
CREATE TRIGGER trg_populate_seq_dataset_date BEFORE INSERT ON "lab"."seq_dataset" FOR EACH ROW EXECUTE FUNCTION "lab".populate_date_from_root_sample();
CREATE TRIGGER trg_populate_sequencing_run_date BEFORE INSERT ON "lab"."sequencing_run" FOR EACH ROW EXECUTE FUNCTION "lab".populate_date_from_root_sample();
CREATE TRIGGER trg_populate_analysis_runs_date BEFORE INSERT ON "bioinformatics"."analysis_runs" FOR EACH ROW EXECUTE FUNCTION "bioinformatics".populate_date_from_sequencing();
CREATE TRIGGER trg_populate_edna_assignments_date BEFORE INSERT ON "bioinformatics"."edna_assignments" FOR EACH ROW EXECUTE FUNCTION "lab".populate_date_from_root_sample();

-- CREATE TRIGGER trg_set_default_status_edna_assignments BEFORE INSERT ON "bioinformatics"."edna_assignments" FOR EACH ROW EXECUTE FUNCTION set_default_status_on_insert();
CREATE TRIGGER trg_set_pcr_date BEFORE INSERT ON "lab"."pcr" FOR EACH ROW EXECUTE FUNCTION "lab".populate_pcr_date();
CREATE TRIGGER trg_set_qpcr_date BEFORE INSERT ON "lab"."qpcr" FOR EACH ROW EXECUTE FUNCTION "lab".populate_qpcr_date();
CREATE TRIGGER trg_set_seq_dataset_date BEFORE INSERT ON "lab"."seq_dataset" FOR EACH ROW EXECUTE FUNCTION "lab".populate_seq_dataset_date();
CREATE TRIGGER trg_set_run_date BEFORE INSERT ON "bioinformatics"."analysis_runs" FOR EACH ROW EXECUTE FUNCTION "bioinformatics".populate_run_date();
CREATE TRIGGER trg_set_edna_assignment_date BEFORE INSERT ON "bioinformatics"."edna_assignments" FOR EACH ROW EXECUTE FUNCTION "bioinformatics".populate_run_date();

-- ############################################ 


-- 12.3. Triggers for other logic
CREATE OR REPLACE FUNCTION "projects".populate_fishing_geom_4326_trigger()
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
CREATE TRIGGER trg_populate_geom_4326 BEFORE INSERT OR UPDATE ON "projects"."ProjectWanderfische_FishingData" FOR EACH ROW EXECUTE FUNCTION "projects".populate_fishing_geom_4326_trigger();
CREATE TRIGGER trg_update_taxon_path BEFORE INSERT OR UPDATE ON "reference"."taxon" FOR EACH ROW EXECUTE FUNCTION "reference".update_taxon_ltree_path_for_row();
CREATE TRIGGER trg_update_status_dissection AFTER INSERT ON "lab"."dissections" FOR EACH ROW EXECUTE FUNCTION "lab".update_sample_status();
CREATE TRIGGER trg_update_status_nanodrop AFTER INSERT ON "lab"."nanodrop" FOR EACH ROW EXECUTE FUNCTION "lab".update_sample_status();
CREATE TRIGGER trg_update_status_qubit AFTER INSERT ON "lab"."qubit" FOR EACH ROW EXECUTE FUNCTION "lab".update_sample_status();
CREATE TRIGGER trg_update_status_tapestation AFTER INSERT ON "lab"."tapestation" FOR EACH ROW EXECUTE FUNCTION "lab".update_sample_status();
CREATE TRIGGER trg_update_status_pcr AFTER INSERT ON "lab"."pcr" FOR EACH ROW EXECUTE FUNCTION "lab".update_sample_status();
CREATE TRIGGER trg_update_status_qpcr AFTER INSERT ON "lab"."qpcr" FOR EACH ROW EXECUTE FUNCTION "lab".update_sample_status();
CREATE TRIGGER trg_update_status_library AFTER INSERT ON "lab"."library" FOR EACH ROW EXECUTE FUNCTION "lab".update_sample_status();
CREATE TRIGGER trg_update_status_sequencing_run AFTER INSERT ON "lab"."sequencing_run" FOR EACH ROW EXECUTE FUNCTION "lab".update_sample_status();
CREATE TRIGGER trg_update_status_analysis_runs AFTER INSERT ON "bioinformatics"."analysis_runs" FOR EACH ROW EXECUTE FUNCTION "lab".update_sample_status();

-- 12.4. Triggers for Default Status
CREATE TRIGGER trg_set_default_status_projects BEFORE INSERT ON "lims"."projects" FOR EACH ROW EXECUTE FUNCTION set_default_status_on_insert();
CREATE TRIGGER trg_set_default_status_cruises BEFORE INSERT ON "lims"."cruises" FOR EACH ROW EXECUTE FUNCTION set_default_status_on_insert();
CREATE TRIGGER trg_set_default_status_batch_steps BEFORE INSERT ON "lims"."batch_steps" FOR EACH ROW EXECUTE FUNCTION set_default_status_on_insert();
CREATE TRIGGER trg_set_default_status_reagents BEFORE INSERT ON "lims"."reagents" FOR EACH ROW EXECUTE FUNCTION set_default_status_on_insert();
CREATE TRIGGER trg_set_default_status_experiments BEFORE INSERT ON "lab"."experiments" FOR EACH ROW EXECUTE FUNCTION set_default_status_on_insert();
CREATE TRIGGER trg_set_default_status_sampling BEFORE INSERT ON "lab"."sampling" FOR EACH ROW EXECUTE FUNCTION set_default_status_on_insert();
CREATE TRIGGER trg_set_default_status_root_samples BEFORE INSERT ON "lab"."root_samples" FOR EACH ROW EXECUTE FUNCTION set_default_status_on_insert();
CREATE TRIGGER trg_set_default_status_fish BEFORE INSERT ON "lab"."fish" FOR EACH ROW EXECUTE FUNCTION set_default_status_on_insert();
CREATE TRIGGER trg_set_default_status_tissue BEFORE INSERT ON "lab"."tissue" FOR EACH ROW EXECUTE FUNCTION set_default_status_on_insert();
CREATE TRIGGER trg_set_default_status_otoliths BEFORE INSERT ON "lab"."otoliths" FOR EACH ROW EXECUTE FUNCTION set_default_status_on_insert();
CREATE TRIGGER trg_set_default_status_dna BEFORE INSERT ON "lab"."dna" FOR EACH ROW EXECUTE FUNCTION set_default_status_on_insert();
CREATE TRIGGER trg_set_default_status_rna BEFORE INSERT ON "lab"."rna" FOR EACH ROW EXECUTE FUNCTION set_default_status_on_insert();
CREATE TRIGGER trg_set_default_status_sediments BEFORE INSERT ON "lab"."sediments" FOR EACH ROW EXECUTE FUNCTION set_default_status_on_insert();
CREATE TRIGGER trg_set_default_status_water BEFORE INSERT ON "lab"."water" FOR EACH ROW EXECUTE FUNCTION set_default_status_on_insert();
CREATE TRIGGER trg_set_default_status_pcr BEFORE INSERT ON "lab"."pcr" FOR EACH ROW EXECUTE FUNCTION set_default_status_on_insert();
CREATE TRIGGER trg_set_default_status_dissections BEFORE INSERT ON "lab"."dissections" FOR EACH ROW EXECUTE FUNCTION set_default_status_on_insert();
CREATE TRIGGER trg_set_default_status_nanodrop BEFORE INSERT ON "lab"."nanodrop" FOR EACH ROW EXECUTE FUNCTION set_default_status_on_insert();
CREATE TRIGGER trg_set_default_status_qubit BEFORE INSERT ON "lab"."qubit" FOR EACH ROW EXECUTE FUNCTION set_default_status_on_insert();
CREATE TRIGGER trg_set_default_status_tapestation BEFORE INSERT ON "lab"."tapestation" FOR EACH ROW EXECUTE FUNCTION set_default_status_on_insert();
CREATE TRIGGER trg_set_default_status_gelelectrophoresis BEFORE INSERT ON "lab"."gelelectrophoresis" FOR EACH ROW EXECUTE FUNCTION set_default_status_on_insert();
CREATE TRIGGER trg_set_default_status_qpcr BEFORE INSERT ON "lab"."qpcr" FOR EACH ROW EXECUTE FUNCTION set_default_status_on_insert();
CREATE TRIGGER trg_set_default_status_library BEFORE INSERT ON "lab"."library" FOR EACH ROW EXECUTE FUNCTION set_default_status_on_insert();
CREATE TRIGGER trg_set_default_status_sequencing_run BEFORE INSERT ON "lab"."sequencing_run" FOR EACH ROW EXECUTE FUNCTION set_default_status_on_insert();
CREATE TRIGGER trg_set_default_status_datasets BEFORE INSERT ON "lab"."datasets" FOR EACH ROW EXECUTE FUNCTION set_default_status_on_insert();
CREATE TRIGGER trg_set_default_status_pipelines BEFORE INSERT ON "bioinformatics"."analysis_pipelines" FOR EACH ROW EXECUTE FUNCTION set_default_status_on_insert();
CREATE TRIGGER trg_set_default_status_analysis_runs BEFORE INSERT ON "bioinformatics"."analysis_runs" FOR EACH ROW EXECUTE FUNCTION set_default_status_on_insert();
CREATE TRIGGER trg_set_default_status_edna_assignments BEFORE INSERT ON "bioinformatics"."edna_assignments" FOR EACH ROW EXECUTE FUNCTION set_default_status_on_insert();

-- 12.5. Triggers for Audit Logging (Apply to all tables)
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
CREATE TRIGGER audit_trigger_seq_dataset AFTER INSERT OR UPDATE OR DELETE ON "lab"."seq_dataset" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_datasets AFTER INSERT OR UPDATE OR DELETE ON "lab"."datasets" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_pipelines AFTER INSERT OR UPDATE OR DELETE ON "bioinformatics"."analysis_pipelines" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_runs AFTER INSERT OR UPDATE OR DELETE ON "bioinformatics"."analysis_runs" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_assignments AFTER INSERT OR UPDATE OR DELETE ON "bioinformatics"."edna_assignments" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_proj_fishingdata AFTER INSERT OR UPDATE OR DELETE ON "projects"."ProjectWanderfische_FishingData" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_proj_fishcatch AFTER INSERT OR UPDATE OR DELETE ON "projects"."ProjectWanderfische_FishCatch" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_proj_mail AFTER INSERT OR UPDATE OR DELETE ON "projects"."ProjectWanderfische_Mail" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_proj_conversation AFTER INSERT OR UPDATE OR DELETE ON "projects"."ProjectWanderfische_Conversation" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();
CREATE TRIGGER audit_trigger_proj_chatmessage AFTER INSERT OR UPDATE OR DELETE ON "projects"."ProjectWanderfische_ChatMessage" FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();

-- 12.6. Triggers for Full-Text Search
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
CREATE TRIGGER trg_update_runs_search BEFORE INSERT OR UPDATE ON "bioinformatics"."analysis_runs" FOR EACH ROW EXECUTE FUNCTION "bioinformatics".update_runs_search_vector_func();


-- -- =========================================
-- 13. INDEXES
-- -- =========================================
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
CREATE INDEX IF NOT EXISTS idx_individual_catch_fishing_id ON "lab"."individual_catch_catch" ("sampling_id");
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
CREATE INDEX IF NOT EXISTS idx_otoliths_otolith_id_date ON "lab"."otoliths" ("sample_id", "sample_creation_date");
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
CREATE INDEX IF NOT EXISTS idx_seq_dataset_sample_id ON "lab"."seq_dataset" ("sample_id");
CREATE INDEX IF NOT EXISTS idx_seq_dataset_sequencing_run_id ON "lab"."seq_dataset" ("sequencing_run_id");
CREATE INDEX IF NOT EXISTS idx_datasets_sample_id ON "lab"."datasets" ("sample_id");
CREATE INDEX IF NOT EXISTS idx_datasets_experiment_id ON "lab"."datasets" ("experiment_id", "experiment_date");
CREATE INDEX IF NOT EXISTS idx_pcr_sample_id ON "lab"."pcr" ("sample_id", "sample_creation_date");
CREATE INDEX IF NOT EXISTS idx_qpcr_sample_id_exp ON "lab"."qpcr" ("sample_id", "sample_creation_date");


-- Bioinformatics Schema Indexes
CREATE INDEX IF NOT EXISTS idx_analysis_pipelines_id ON "bioinformatics"."analysis_pipelines" ("pipeline_id");
CREATE INDEX IF NOT EXISTS idx_analysis_pipelines_name ON "bioinformatics"."analysis_pipelines" USING gin(to_tsvector('english', "pipeline_name"));
CREATE INDEX IF NOT EXISTS idx_analysis_runs_id_date ON "bioinformatics"."analysis_runs" ("run_id", "creation_date");
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


-- -- =========================================
-- 14. VIEWS & MATERIALIZED VIEWS
-- -- =========================================
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
WHERE s.box_size_x IS NOT NULL AND s.box_size_y IS NOT NULL AND (s.box_size_x * s.box_size_y) > 0
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
    "bioinformatics"."edna_assignments" ea ON ar.run_id = ea.run_id AND ar.creation_date = ea.run_creation_date
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

-- A more comprehensive project summary view
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
    SUM(o.price * o.quantity) AS total_order_cost
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
LEFT JOIN "bioinformatics"."analysis_runs" ar ON sr.sequencing_run_id = ar.sequencing_id AND sr.creation_date = ar.sequencing_date
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
    "lab"."root_samples" rs ON sl.sample_id = rs.sample_id AND sl.sample_creation_date = rs.sample_creation_date
LEFT JOIN
    "lims"."personal" p ON sl.person_id = p.person_id
LEFT JOIN
    "lab"."storage" storage ON sl.storage_id = storage.storage_id
LEFT JOIN
    "reference"."status" stat ON sl.status_id = stat.status_id
ORDER BY
    sl.move_date DESC;

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
    "reference"."reference_databases" rdb ON ar.reference_db_id = rdb.db_id
LEFT JOIN
    "bioinformatics"."edna_assignments" ea ON ar.run_id = ea.run_id AND ar.run_date = ea.assignment_date
LEFT JOIN
    "reference"."taxon" t ON ea.taxon_id = t.taxon_id
ORDER BY ar.run_id;

CREATE OR REPLACE VIEW "lab"."full_sequencing_run_view" AS
SELECT
    sr.sequencing_run_id,
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
    dis.creation_date AS dissection_date,
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
    "reference"."room" storage_room ON storage.room_id = storage.room_id
LEFT JOIN
    "lab"."storage_log" sl ON rs.sample_id = sl.sample_id AND rs.sample_creation_date = sl.sample_creation_date
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
    "bioinformatics"."analysis_runs" ar ON sr.sequencing_run_id = ar.sequencing_id AND sr.creation_date = ar.sequencing_date
LEFT JOIN
    "bioinformatics"."analysis_pipelines" ap ON ar.pipeline_id = ap.pipeline_id
LEFT JOIN
    "reference"."reference_databases" ar_db ON ar.reference_db_id = ar_db.db_id
LEFT JOIN
    "bioinformatics"."edna_assignments" ea ON ar.run_id = ea.run_id AND ar.creation_date = ea.run_creation_date AND rs.sample_id = ea.sample_id AND rs.sample_creation_date = ea.sample_creation_date
LEFT JOIN
    "reference"."taxon" ea_taxon ON ea.taxon_id = ea_taxon.taxon_id;

-- Materialized View for performance-intensive reporting
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
COMMENT ON MATERIALIZED VIEW "lab"."monthly_sample_reception_mv" IS 'Aggregates monthly sample reception counts for faster reporting. Refresh periodically.';


-- -- =========================================
-- 15. ROW-LEVEL SECURITY (RLS) POLICIES
-- -- =========================================
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
-- Public/Shared tables (all authenticated users can see)
CREATE POLICY personal_rls_policy ON "lims"."personal" FOR SELECT USING (TRUE);
CREATE POLICY external_contacts_rls_policy ON "lims"."external_contacts" FOR SELECT USING (TRUE);
CREATE POLICY customer_rls_policy ON "lims"."customers" FOR SELECT USING (TRUE);
CREATE POLICY sop_rls_policy ON "lims"."sop" FOR SELECT USING (TRUE);
CREATE POLICY public_reagents_policy ON "lims"."reagents" FOR SELECT USING (TRUE);
CREATE POLICY public_storage_policy ON "lab"."storage" FOR SELECT USING (TRUE);
CREATE POLICY public_pipelines_policy ON "bioinformatics"."analysis_pipelines" FOR SELECT USING (TRUE);

-- Project-based policies (only project members can see)
CREATE POLICY project_membership_policy ON "lims"."projects" USING ("lims".is_member_of_project(project_id));
CREATE POLICY root_samples_rls_policy ON "lab"."root_samples" USING ("lims".is_member_of_project(project_id));
CREATE POLICY sampling_rls_policy ON "lab"."sampling" USING ("lims".is_member_of_project(project_id));
-- CREATE POLICY datasets_rls_policy ON "lab"."datasets" USING ("lims".is_member_of_project((SELECT project_id FROM lab.experiments e WHERE e.experiment_id = datasets.experiment_id AND e.experiment_date = datasets.experiment_date)));
CREATE POLICY fishing_rls_policy ON "lab"."fishing" USING (EXISTS (SELECT 1 FROM "lab"."sampling" s WHERE s.sampling_id = fishing.sampling_id AND "lims".is_member_of_project(s.project_id)));
CREATE POLICY fish_rls_policy ON "lab"."fish" USING (EXISTS (SELECT 1 FROM "lab"."root_samples" rs WHERE rs.sample_id = fish.sample_id AND "lims".is_member_of_project(rs.project_id)));
CREATE POLICY tissue_rls_policy ON "lab"."tissue" USING (EXISTS (SELECT 1 FROM "lab"."root_samples" rs WHERE rs.sample_id = tissue.sample_id AND "lims".is_member_of_project(rs.project_id)));
CREATE POLICY dna_rls_policy ON "lab"."dna" USING (EXISTS (SELECT 1 FROM "lab"."root_samples" rs WHERE rs.sample_id = dna.sample_id AND "lims".is_member_of_project(rs.project_id)));
CREATE POLICY rna_rls_policy ON "lab"."rna" USING (EXISTS (SELECT 1 FROM "lab"."root_samples" rs WHERE rs.sample_id = rna.sample_id AND "lims".is_member_of_project(rs.project_id)));
CREATE POLICY otoliths_rls_policy ON "lab"."otoliths" USING (EXISTS (SELECT 1 FROM "lab"."root_samples" rs WHERE rs.sample_id = otoliths.sample_id AND "lims".is_member_of_project(rs.project_id)));
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
CREATE POLICY wander_fishcatch_policy ON "projects"."ProjectWanderfische_FishCatch" USING (EXISTS (SELECT 1 FROM "projects"."ProjectWanderfische_FishingData" fd WHERE fd.fishing_record_id = "ProjectWanderfische_FishCatch".fishing_record_id AND fd.record_date = "ProjectWanderfische_FishCatch".fishing_record_date AND "lims".is_member_of_project(fd.project_id)));
CREATE POLICY wander_mail_policy ON "projects"."ProjectWanderfische_Mail" USING (EXISTS (SELECT 1 FROM "projects"."ProjectWanderfische_FishingData" fd WHERE fd.fishing_record_id = "ProjectWanderfische_Mail".fishing_record_id AND fd.record_date = "ProjectWanderfische_Mail".fishing_record_date AND "lims".is_member_of_project(fd.project_id)));
CREATE POLICY wander_conversation_policy ON "projects"."ProjectWanderfische_Conversation" USING (EXISTS (SELECT 1 FROM "projects"."ProjectWanderfische_FishingData" fd WHERE fd.fishing_record_id = "ProjectWanderfische_Conversation".fishing_record_id AND fd.record_date = "ProjectWanderfische_Conversation".fishing_record_date AND "lims".is_member_of_project(fd.project_id)));
CREATE POLICY wander_chatmessage_policy ON "projects"."ProjectWanderfische_ChatMessage" USING (EXISTS (SELECT 1 FROM "projects"."ProjectWanderfische_Conversation" conv JOIN "projects"."ProjectWanderfische_FishingData" fd ON conv.fishing_record_id = fd.fishing_record_id AND conv.fishing_record_date = fd.record_date WHERE conv.conversation_id = "ProjectWanderfische_ChatMessage".conversation_id AND "lims".is_member_of_project(fd.project_id)));


-- -- =========================================
-- 16. UNIQUE CONSTRAINTS
-- -- =========================================
ALTER TABLE "lims"."publications" ADD CONSTRAINT uc_doi_date UNIQUE ("doi", "date_publication");
ALTER TABLE "lims"."batch_steps" ADD CONSTRAINT uc_batch_step UNIQUE ("batch_id", "step_number");
ALTER TABLE "lab"."root_samples" ADD CONSTRAINT uc_root_sample_id UNIQUE ("sample_id", "sample_creation_date");
ALTER TABLE "lab"."otoliths" ADD CONSTRAINT uc_otolith_id UNIQUE ("sample_id", "reader_person_id", "side", "creation_date");
ALTER TABLE "lab"."qpcr" ADD CONSTRAINT uc_qpcr_id_date UNIQUE ("qpcr_id", "creation_date");
ALTER TABLE "lab"."library" ADD CONSTRAINT uc_library_id_sample_exp UNIQUE ("library_id", "sample_id", "creation_date");
ALTER TABLE "lab"."sequencing_run" ADD CONSTRAINT uc_seq_run_id_exp UNIQUE ("sequencing_run_id", "creation_date");
ALTER TABLE "lab"."seq_dataset" ADD CONSTRAINT uc_seq_dataset_id_date UNIQUE ("data_seq_id", "creation_date");
ALTER TABLE "lab"."datasets" ADD CONSTRAINT uc_dataset_id_reception UNIQUE ("dataset_id", "reception_date");
ALTER TABLE "bioinformatics"."analysis_runs" ADD CONSTRAINT uc_run_id_date UNIQUE ("run_id", "creation_date");
ALTER TABLE "bioinformatics"."edna_assignments" ADD CONSTRAINT uc_assignment_id_date UNIQUE ("assignment_id", "creation_date");


-- ###############################################################
-- Dummy partition tables for initial setup
-- ###############################################################

DO $$
DECLARE
    parent_table_name text;
    parent_schema text;
    default_partition_name text;
    yearly_partition_name text;
    start_date date;
    end_date date;
    table_list text[] := ARRAY[
        'lab.experiments', 'lab.sampling', 'lab.fishing', 'lab.individual_catch_catch',
        'lab.sampling_abiotic_data', 'lab.root_samples', 'lab.fish', 'lab.tissue',
        'lab.otoliths', 'lab.dna', 'lab.rna', 'lab.sediments', 'lab.water', 'lab.pcr',
        'lab.dissections', 'lab.nanodrop', 'lab.qubit', 'lab.tapestation',
        'lab.gelelectrophoresis', 'lab.qpcr', 'lab.library', 'lab.sequencing_run',
        'lab.seq_dataset', 'lab.datasets', 'bioinformatics.analysis_runs', 'bioinformatics.edna_assignments',
        'projects.ProjectWanderfische_FishingData'
    ];
    rec_table RECORD;
BEGIN
    FOR rec_table IN SELECT unnest(table_list) AS full_name LOOP
        parent_schema := split_part(rec_table.full_name, '.', 1);
        parent_table_name := split_part(rec_table.full_name, '.', 2);

        -- Corrected syntax for creating the default partition
        default_partition_name := parent_table_name || '_default';
        BEGIN
            EXECUTE format('CREATE TABLE %I.%I PARTITION OF %I.%I DEFAULT', parent_schema, default_partition_name, parent_schema, parent_table_name);
        EXCEPTION
            WHEN duplicate_table THEN
                RAISE NOTICE 'Default partition for table %.% already exists.', parent_schema, parent_table_name;
        END;

        FOR start_date IN SELECT generate_series(date_trunc('year', now()) - INTERVAL '2 years', date_trunc('year', now()) + INTERVAL '10 years', '1 year') LOOP
            end_date := start_date + INTERVAL '1 year';
            yearly_partition_name := parent_table_name || '_y' || EXTRACT(YEAR FROM start_date);
            BEGIN
                EXECUTE format('CREATE TABLE %I.%I PARTITION OF %I.%I FOR VALUES FROM (%L) TO (%L)',
                    parent_schema, yearly_partition_name, parent_schema, parent_table_name, start_date, end_date);
            EXCEPTION
                WHEN duplicate_table THEN
                    RAISE NOTICE 'Partition % for table %.% already exists.', yearly_partition_name, parent_schema, parent_table_name;
            END;
        END LOOP;
    END LOOP;
END $$;



-- ####################################
-- Great booking schema
-- ####################################

-- lims.bookable_resource Table
CREATE TABLE IF NOT EXISTS "lims"."bookable_resource" (
    "resource_id" text PRIMARY KEY,
    "resource_name" text NOT NULL,
    "resource_type" text NOT NULL, -- e.g., Centrifuge, PCR machine, Bench area
    "room_id" text REFERENCES "reference"."room"("room_id"),
    "equipment_id" text,
    "capacity" integer DEFAULT 1, -- The number of people/bookings this resource can handle simultaneously
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text
);


--  lims.booking Table
CREATE TABLE IF NOT EXISTS "lims"."booking" (
    "booking_id" bigserial PRIMARY KEY,
    "resource_id" text NOT NULL REFERENCES "lims"."bookable_resource"("resource_id"),
    "person_id" text NOT NULL,
    "start_time" timestamptz NOT NULL,
    "end_time" timestamptz NOT NULL,
    "project_id" text REFERENCES "lims"."projects"("project_id"),
    "tags" text,
    "notes" text,
    "attachment" bytea,
    "attachment_link" text,
    "created_at" timestamptz DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_booking_time CHECK ("start_time" < "end_time")
);


-- Check Constraint for Concurrent Bookings
-- to prevent overbooking based on the capacity of a resource. 
-- Function to check for booking conflicts
CREATE OR REPLACE FUNCTION "lims".check_booking_capacity()
RETURNS TRIGGER AS $$
DECLARE
    v_capacity INTEGER;
    v_concurrent_bookings INTEGER;
BEGIN
    -- Get the capacity of the resource being booked
    SELECT capacity INTO v_capacity FROM "lims"."bookable_resource" WHERE resource_id = NEW.resource_id;

    -- Count existing, non-conflicting bookings for this resource
    SELECT COUNT(*) INTO v_concurrent_bookings
    FROM "lims"."booking"
    WHERE
        resource_id = NEW.resource_id
        AND booking_id != NEW.booking_id -- Exclude the new or updated row itself
        AND (
            (NEW.start_time, NEW.end_time) OVERLAPS (start_time, end_time)
        );

    -- Check if the new booking exceeds the resource's capacity
    IF v_concurrent_bookings >= v_capacity THEN
        RAISE EXCEPTION 'This resource is already fully booked for the requested time slot. Capacity: %, Current Bookings: %', v_capacity, v_concurrent_bookings;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to enforce the capacity check before inserting or updating a booking
CREATE TRIGGER trg_check_booking_capacity BEFORE INSERT OR UPDATE ON "lims"."booking"
FOR EACH ROW EXECUTE FUNCTION "lims".check_booking_capacity();






































































-- ======================================================================
-- DEMO DATA GENERATION SCRIPT
-- ======================================================================
-- Set a context date for partitioning triggers. This helps ensure data
-- is inserted into the correct partitions.
SET "projects.current_date" = '2025-08-20';
SET "lims.current_person_id" = 'jane.doe';

-- ======================================================================
-- 1. REFERENCE SCHEMA - BASE DATA
-- ======================================================================

DO $$ BEGIN
    INSERT INTO "reference"."status" ("status_id", "notes") VALUES
    ('Planned', 'The action or item is planned but not started.'),
    ('Received', 'The item has been received and is ready for use.'),
    ('In Progress', 'The work on this item is currently in progress.'),
    ('Completed', 'The process has been successfully completed.'),
    ('Dissection', 'The sample has undergone dissection.'),
    ('Otoliths_Reading', 'The sample has undergone dissection.'),
    ('Nanodrop QC', 'The sample has been checked with Nanodrop for quality control.'),
    ('Qubit QC', 'The sample has been checked with Qubit for quality control.'),
    ('Tapestation QC', 'The sample has been checked with Tapestation for quality control.'),
    ('PCR Done', 'The Polymerase Chain Reaction step is completed.'),
    ('qPCR Done', 'The quantitative PCR step is completed.'),
    ('Library Prep', 'The sequencing library has been prepared.'),
    ('Sequencing Done', 'The sequencing run is completed.'),
    ('Bioinformatics Done', 'The bioinformatics analysis is completed.'),
    ('Archived', 'The item is stored for long-term retention.'),
    ('Destroyed', 'The item has been destroyed and is no longer available.'),
    ('On Hold', 'The process is temporarily paused.');

    INSERT INTO "reference"."room" ("room_id", "etage", "address", "institute", "city", "country") VALUES
    ('R101', '1st Floor', '123 Ocean Blvd', 'Marine Research Institute', 'Bremerhaven', 'Germany'),
    ('R202', '2nd Floor', '123 Ocean Blvd', 'Marine Research Institute', 'Bremerhaven', 'Germany');

    INSERT INTO "reference"."vessel" ("vessel_id", "vessel_name", "belong_to") VALUES
    ('RV_Meteor', 'Research Vessel Meteor', 'DFG'),
    ('RV_Sonne', 'Research Vessel Sonne', 'BMF');

    INSERT INTO "reference"."region" ("region_id", "region_abrv", "parent_region", "rank", "path") VALUES
    ('Eur', 'Eu', NULL, 'Continent', 'Eur'),
    ('Asia', 'As', NULL, 'Continent', 'Asia'),
    ('Arctic', 'Arc', 'Eur', 'Region', 'Eur.Arctic'),
    ('BalticSea', 'Blt', 'Eur', 'Sea', 'Eur.BalticSea'),
    ('NorthSea', 'NSe', 'Eur', 'Sea', 'Eur.NorthSea');

    INSERT INTO "reference"."ecosystem" ("ecosystem_id", "ecosystem_abrv", "country", "rank", "path") VALUES
    ('Freshwater', 'Fw', NULL, 'Terrestrial', 'Freshwater'),
    ('Marine', 'Mar', NULL, 'Aquatic', 'Marine'),
    ('Estuary', 'Est', NULL, 'Aquatic', 'Estuary');

    INSERT INTO "reference"."category" ("category_id", "notes") VALUES
    ('Consumables', 'General lab consumables'),
    ('Kits', 'Reagent kits for specific protocols'),
    ('Chemicals', 'General-purpose chemicals'),
    ('Samples', 'Samples of biological origin');

    INSERT INTO "reference"."samples_type" ("sample_type_id", "sample_type_abrv", "rank") VALUES
    ('Root', 'S', 'Primary'),
    ('Fish', 'F', 'Biological'),
    ('Tissue', 'T', 'Biological'),
    ('DNA', 'D', 'Molecular'),
    ('RNA', 'R', 'Molecular'),
    ('PCR_Product', 'P', 'Molecular'),
    ('Library', 'L', 'Molecular'),
    ('Water', 'W', 'Environmental'),
    ('Sediment', 'Sd', 'Environmental'),
    ('Otolith', 'Ot', 'Biological');

    INSERT INTO "reference"."gene" ("gene_id") VALUES
    ('16S rRNA'),
    ('18S rRNA'),
    ('COI');

    INSERT INTO "reference"."taxon" ("taxon_id", "taxon_parent", "de_name", "en_name", "rank", "path") VALUES
    ('Animalia', NULL, 'Tiere', 'Animals', 'Kingdom', 'Animalia'),
    ('Chordata', 'Animalia', 'Wirbeltiere', 'Vertebrates', 'Phylum', 'Animalia.Chordata'),
    ('Actinopterygii', 'Chordata', 'Strahlenflosser', 'Ray-finned fishes', 'Class', 'Animalia.Chordata.Actinopterygii'),
    ('Gadiformes', 'Actinopterygii', 'Dorschartige', 'Cod-like fishes', 'Order', 'Animalia.Chordata.Actinopterygii.Gadiformes'),
    ('Gadus', 'Gadiformes', 'Kabeljau-Gattung', 'Cod genus', 'Genus', 'Animalia.Chordata.Actinopterygii.Gadiformes.Gadus'),
    ('Gadus_morhua', 'Gadus', 'Kabeljau', 'Atlantic Cod', 'Species', 'Animalia.Chordata.Actinopterygii.Gadiformes.Gadus.Gadus_morhua'),
    ('Bacteria', NULL, 'Bakterien', 'Bacteria', 'Kingdom', 'Bacteria'),
    ('Firmicutes', 'Bacteria', NULL, 'Firmicutes', 'Phylum', 'Bacteria.Firmicutes'),
    ('Bacillales', 'Firmicutes', NULL, 'Bacillales', 'Order', 'Bacteria.Firmicutes.Bacillales'),
    ('Bacteria_Unclassified', 'Bacteria', NULL, 'Unclassified Bacteria', 'Unclassified', 'Bacteria.Bacteria_Unclassified');

    INSERT INTO "reference"."units" ("unit_id", "unit_name", "unit_abbreviation", "unit_type", "parent_unit_id", "conversion_factor_to_parent") VALUES
    ('meter', 'meter', 'm', 'Length', NULL, 1),
    ('kilometer', 'kilometer', 'km', 'Length', 'meter', 1000),
    ('millimeter', 'millimeter', 'mm', 'Length', 'meter', 0.001),
    ('kilogram', 'kilogram', 'kg', 'Mass', NULL, 1),
    ('gram', 'gram', 'g', 'Mass', 'kilogram', 0.001),
    ('liter', 'liter', 'L', 'Volume', NULL, 1),
    ('milliliter', 'milliliter', 'ml', 'Volume', 'liter', 0.001),
    ('microliter', 'microliter', 'ul', 'Volume', 'milliliter', 0.001),
    ('nanogram', 'nanogram', 'ng', 'Mass', 'kilogram', 0.000000001),
    ('ng_ul', 'nanogram per microliter', 'ng/ul', 'Concentration', NULL, NULL),
    ('microgram', 'microgram', 'ug', 'Mass', 'kilogram', 0.000001),
    ('ug_L', 'microgram per liter', 'ug/L', 'Concentration', NULL, NULL),
    ('Celsius', 'Degree Celsius', '°C', 'Temperature', NULL, NULL),
    ('PSU', 'Practical Salinity Units', 'PSU', 'Salinity', NULL, NULL),
    ('mg_L', 'milligram per liter', 'mg/L', 'Concentration', NULL, NULL),
    ('NTU', 'Nephelometric Turbidity Units', 'NTU', 'Turbidity', NULL, NULL),
    ('umol_m2s', 'micromoles per square meter per second', 'umol/(m²s)', 'Irradiance', NULL, NULL),
    ('m_s', 'meters per second', 'm/s', 'Velocity', NULL, NULL),
    ('hPa', 'Hectopascal', 'hPa', 'Pressure', NULL, NULL),
    ('min', 'Minute', 'min', 'Time', NULL, NULL);

    INSERT INTO "reference"."reference_databases" ("db_name", "db_version", "last_updated_date") VALUES
    ('NCBI RefSeq', '2025-01', '2025-01-15'),
    ('BOLD', '4.0.0', '2024-11-20'),
    ('GTDB', 'R207', '2025-02-10');
END $$;

-- ------------------------------------------------------------------------------------------------------------------

-- ======================================================================
-- 2. LIMS SCHEMA - CORE DATA
-- ======================================================================

DO $$ BEGIN
    INSERT INTO "lims"."personal" ("person_id", "salutation", "full_name", "room", "telephone", "mail", "password_hash", "status_id") VALUES
    ('john.smith', 'Mr.', 'John Smith', 'R101', '+49 123 456789', 'john.smith@lims.org', 'hashed_pass_1', 'Received'),
    ('jane.doe', 'Ms.', 'Jane Doe', 'R202', '+49 123 987654', 'jane.doe@lims.org', 'hashed_pass_2', 'Received'),
    ('peter.jones', 'Dr.', 'Peter Jones', 'R101', '+49 123 112233', 'peter.jones@lims.org', 'hashed_pass_3', 'Received');

    INSERT INTO "lims"."external_contacts" ("contact_id", "full_name", "organization", "mail") VALUES
    ('marine_research_uni', 'Dr. Schmidt', 'Marine Research University', 'schmidt@mru.de'),
    ('fisheries_agency', 'Mr. Fischer', 'State Fisheries Agency', 'fischer@sfa.gov');

    INSERT INTO "lims"."customers" ("customer_name", "customer_abrv", "address", "mail", "password_hash") VALUES
    ('Blue Ocean Foundation', 'BOF', '100 Beach St', 'info@bof.org', 'hashed_pass_c1'),
    ('EcoSolutions GmbH', 'ESG', '200 Forest Rd', 'contact@ecosolutions.de', 'hashed_pass_c2');

    INSERT INTO "lims"."projects" ("project_id", "project_abrv", "title", "status_id", "pi_person_id", "funder", "customer_id", "start_date", "end_date", "description") VALUES
    ('Proj_AquaGen', 'AquaGen', 'Aquatic Genetic Diversity Study', 'Completed', 'john.smith', 'EU Horizon', (SELECT customer_id FROM "lims"."customers" WHERE customer_abrv = 'BOF'), '2024-01-10', '2025-01-10', 'A project to assess genetic diversity of marine species.'),
    ('Proj_BioMon', 'BioMon', 'Biodiversity Monitoring in the North Sea', 'In Progress', 'jane.doe', 'Ministry of Research', (SELECT customer_id FROM "lims"."customers" WHERE customer_abrv = 'ESG'), '2025-03-01', '2026-03-01', 'Long-term biodiversity monitoring with eDNA methods.');

    INSERT INTO "lims"."project_persons" ("project_id", "person_id", "role", "link_date") VALUES
    ('Proj_AquaGen', 'john.smith', 'Project Lead', '2024-01-10'),
    ('Proj_AquaGen', 'peter.jones', 'Researcher', '2024-02-15'),
    ('Proj_BioMon', 'jane.doe', 'Project Lead', '2025-03-01'),
    ('Proj_BioMon', 'john.smith', 'Collaborator', '2025-04-01');

    INSERT INTO "lims"."cruises" ("cruise_id", "project_id", "vessel_id", "status_id", "region_id", "ecosystem_id", "chief_scientist_person_id", "start_date", "end_date") VALUES
    ('CRUISE_NSe24', 'Proj_AquaGen', 'RV_Meteor', 'Completed', 'NorthSea', 'Marine', 'john.smith', '2024-05-20', '2024-06-15'),
    ('CRUISE_Blt25', 'Proj_BioMon', 'RV_Sonne', 'In Progress', 'BalticSea', 'Estuary', 'jane.doe', '2025-04-10', '2025-05-05');

    INSERT INTO "lab"."storage" ("storage_id", "room_id", "freezer", "etage", "temperature_c", "box", "box_size_x", "box_size_y", "project_id") VALUES
    ('S_R101_F1_B1', 'R101', 'Freezer 1', 'Ground Floor', -80, 'Box 1', 10, 10, 'Proj_AquaGen'),
    ('S_R202_F2_B2', 'R202', 'Freezer 2', '1st Floor', -20, 'Box 2', 5, 5, 'Proj_BioMon');

    INSERT INTO "lims"."batch" ("batch_id", "batch_name") VALUES
    ('Batch_DNA_Ext_001', 'Batch 1 for DNA Extraction'),
    ('Batch_Lib_Prep_002', 'Batch 2 for Library Preparation');

    INSERT INTO "lims"."sop" ("sop_id", "title", "sop_id_origin", "version", "author_person_id", "date_realise", "sop_protocol") VALUES
    ('SOP_DNA_Ext_v1', 'DNA Extraction from Fish Tissue', 'DNA_Ext_v1', '1', 'peter.jones', '2024-03-01', 'Detailed protocol for DNA extraction using a commercial kit.'),
    ('SOP_Lib_Prep_v1', 'Library Preparation for Illumina Sequencing', 'Lib_Prep_v1', '1', 'jane.doe', '2024-04-10', 'Step-by-step guide for preparing sequencing libraries.');

    INSERT INTO "lims"."batch_steps" ("step_id", "batch_id", "step_number", "step_name", "sop_id", "status_id") VALUES
    ('Batch_DNA_Ext_001_1', 'Batch_DNA_Ext_001', 1, 'Sample Lysis', 'SOP_DNA_Ext_v1', 'Completed'),
    ('Batch_DNA_Ext_001_2', 'Batch_DNA_Ext_001', 2, 'DNA Purification', 'SOP_DNA_Ext_v1', 'In Progress');

    INSERT INTO "lims"."primers" ("primer_id", "target_gene_id", "primer_sequence_fwd", "primer_sequence_rev", "reference") VALUES
    ('16S_V4_F', '16S rRNA', 'GTGCCAGCMGCCGCGGTAA', 'GGACTACHVGGGTWTCTAAT', 'Reference A'),
    ('COI_Fish_F', 'COI', 'GGTCAACAAATCATAAAGATATTGG', 'TAAACTTCAGGGTGACCAAAAAATCA', 'Reference B');

    INSERT INTO "lims"."publication_type" ("publication_type_id", "notes") VALUES
    ('Journal_Article', 'Peer-reviewed journal publication'),
    ('Conference_Abstract', 'Abstract from a conference proceeding'),
    ('Thesis', 'Academic thesis (e.g., PhD, Master)');

    INSERT INTO "lims"."suppliers" ("supplier_id", "supplier_name", "contact_person", "mail") VALUES
    ('Qiagen', 'Qiagen GmbH', 'Contact Qiagen', 'sales@qiagen.com'),
    ('Sigma-Aldrich', 'Sigma-Aldrich', 'Contact Aldrich', 'info@sigma-aldrich.com');

    INSERT INTO "lims"."inventory_items" ("item_id", "item_name", "category_id", "unit_id") VALUES
    ('QIAampDNA', 'QIAamp DNA Mini Kit', 'Kits', NULL),
    ('Ethanol', 'Ethanol 99.5%', 'Chemicals', 'liter');

    INSERT INTO "lims"."orders" ("fi_order_nr", "item_id", "category_id", "order_date", "price", "quantity", "project_id", "supplier_id", "status_id") VALUES
    ('PO_AG24_001', 'QIAampDNA', 'Kits', '2024-02-15', 500.00, 1, 'Proj_AquaGen', 'Qiagen', 'Completed'),
    ('PO_BM25_001', 'Ethanol', 'Chemicals', '2025-04-05', 50.00, 1, 'Proj_BioMon', 'Sigma-Aldrich', 'Received');

    INSERT INTO "lims"."reagents" ("reagent_id", "reagent_complete_name", "category_id", "lot", "storage_id", "storage_position", "quantity_available", "quantity_unit_id", "reception_date", "expire_date", "order_id", "project_id", "status_id") VALUES
    ('QIAamp_LotA', 'QIAamp DNA Mini Kit, Lot A', 'Kits', 'LotA123', 'S_R101_F1_B1', 1, 50, 'gram', '2024-03-01', '2025-03-01', 'PO_AG24_001', 'Proj_AquaGen', 'Received'),
    ('Ethanol_LotB', 'Ethanol 99.5%, Lot B', 'Chemicals', 'LotB456', 'S_R202_F2_B2', 1, 10, 'liter', '2025-04-10', '2026-04-10', 'PO_BM25_001', 'Proj_BioMon', 'Received');

    INSERT INTO "lims"."equipment" ("equipment_id", "equipment_name", "room_id", "lot") VALUES
    ('Qubit_3', 'Qubit 3 Fluorometer', 'R101', 'LOTA123'),
    ('Nanodrop_2000', 'Nanodrop 2000 Spectrophotometer', 'R101', 'LOTB456');

    INSERT INTO "lims"."permits" ("permit_id", "permit_number", "issuing_authority", "valid_from", "valid_to", "reference") VALUES
    ('Permit-12345', 'DE-BW-12345', 'State Environmental Agency', '2025-01-01', '2025-12-31', 'Fishing permit for Baltic Sea');


    INSERT INTO "lims"."publications" ("publication_id", "publication_type_id", "title", "journal", "doi", "date_publication", "first_author_person_id", "project_id") VALUES
    ('Pub-2025-001', 'Journal_Article', 'Genetic Diversity of Cod in the North Sea', 'Journal of Marine Science', '10.1016/j.jmarsys.2025.103756', '2025-07-20', 'john.smith', 'Proj_AquaGen');
END $$;
-- ------------------------------------------------------------------------------------------------------------------

-- ======================================================================
-- 3. LAB SCHEMA - WORKFLOW DATA
-- ======================================================================

DO $$
DECLARE
    sampling_id_val text;
    sample_id_w text;
    sample_id_s text;
    sample_id_f text;
    sample_id_t text;
BEGIN
    -- 3.1 lab.sampling
    INSERT INTO "lab"."sampling" ("sampling_date", "project_id", "cruise_id", "region_id", "ecosystem_id", "vessel_id", "depth_m", "location_name", "fishing_method", "total_catch_quantity_kg", "total_catch_quantity_fish", "status_id") VALUES
    ('2025-05-01', 'Proj_BioMon', 'CRUISE_Blt25', 'BalticSea', 'Estuary', 'RV_Sonne', 15.5, 'Coastal Area 1', 'Netting', 25.5, 120, 'In Progress'),
    ('2025-06-05', 'Proj_BioMon', 'CRUISE_Blt25', 'BalticSea', 'Marine', 'RV_Sonne', 30.0, 'Open Sea 2', 'Trawling', 50.0, 80, 'Planned');

    SELECT "sampling_id" INTO sampling_id_val FROM "lab"."sampling" WHERE "location_name" = 'Coastal Area 1' LIMIT 1;

    -- 3.2 lab.experiments
    INSERT INTO "lab"."experiments" ("experiment_id", "experiment_date", "experiment_title", "aim", "method", "sop_id", "person_id", "status_id") VALUES
    ('Exp_eDNA_001', '2025-08-20', 'eDNA Extraction from Water Samples', 'Extract high-quality DNA for sequencing.', 'Standard phenol-chloroform extraction.', 'SOP_DNA_Ext_v1', 'jane.doe', 'In Progress'),
    ('Exp_qPCR_002', '2025-08-21', 'qPCR for Species Identification', 'Quantify specific fish DNA from eDNA samples.', 'qPCR with species-specific primers.', 'SOP_Lib_Prep_v1', 'peter.jones', 'In Progress');

    -- 3.3 lab.root_samples
    INSERT INTO "lab"."root_samples" ("sample_type_id", "project_id", "sample_creation_date", "sampling_id", "sampler_person_id", "status_id") VALUES
    ('Water', 'Proj_BioMon', '2025-05-01', sampling_id_val,  'jane.doe', 'Received'),
    ('Sediment', 'Proj_BioMon', '2025-05-01', sampling_id_val,  'jane.doe', 'Received');

    SELECT "sample_id" INTO sample_id_w FROM "lab"."root_samples" WHERE "sample_type_id" = 'Water' AND "sample_creation_date" = '2025-05-01' LIMIT 1;
    SELECT "sample_id" INTO sample_id_s FROM "lab"."root_samples" WHERE "sample_type_id" = 'Sediment' AND "sample_creation_date" = '2025-05-01' LIMIT 1;

    INSERT INTO "lab"."root_samples" ("sample_type_id", "project_id", "sample_creation_date", "sampling_id", "sampler_person_id", "status_id") VALUES
    ('Fish', 'Proj_BioMon', '2025-05-01', sampling_id_val,  'jane.doe', 'Received');
    SELECT "sample_id" INTO sample_id_f FROM "lab"."root_samples" WHERE "sample_type_id" = 'Fish' AND "sample_creation_date" = '2025-05-01' LIMIT 1;

    INSERT INTO "lab"."root_samples" ("sample_type_id", "project_id", "parent_sample_id", "sample_creation_date") VALUES
    ('Tissue', 'Proj_BioMon', sample_id_f, '2025-05-01');
    SELECT "sample_id" INTO sample_id_t FROM "lab"."root_samples" WHERE "sample_type_id" = 'Tissue' AND "sample_creation_date" = '2025-05-01' ORDER BY "sample_id" DESC LIMIT 1;

    -- 3.4 lab.dna
    INSERT INTO "lab"."dna" ("sample_id", "volume_ul", "concentration_ng_ul", "extraction_method", "extraction_date", "batch_id", "status_id") VALUES
    (sample_id_w, 50, 25.5, 'Phenol-Chloroform', '2025-08-20', 'Batch_DNA_Ext_001', 'Received'),
    (sample_id_t, 100, 50.0, 'CTAB', '2025-08-20', 'Batch_DNA_Ext_001', 'Received');

    -- 3.5 lab.rna
    INSERT INTO "lab"."rna" ("sample_id", "volume_ul", "concentration_ng_ul", "extraction_method", "extraction_date", "kit", "status_id") VALUES
    (sample_id_t, 40, 30.2, 'Trizol', '2025-08-21', 'RNA Kit', 'Received');

    -- 3.6 lab.qubit
    INSERT INTO "lab"."qubit" ("sample_id", "experiment_id",  "qubit_tube_conc", "tube_unit_id", "qubit_original_sample_conc", "original_sample_unit_id", "person_id", "status_id") VALUES
    (sample_id_w, 'Exp_eDNA_001', 2.0, 'ng_ul', 100.0, 'ng_ul', 'peter.jones', 'Qubit QC');

    -- 3.7 lab.nanodrop
    INSERT INTO "lab"."nanodrop" ("sample_id", "experiment_id",  "nanodrop_concentration", "concentration_unit_id", "a260_280", "a260_230", "person_id", "status_id") VALUES
    (sample_id_w, 'Exp_eDNA_001',  2.1, 'ng_ul', 1.85, 2.15, 'peter.jones', 'Nanodrop QC');

    -- 3.8 lab.gelelectrophoresis
    INSERT INTO "lab"."gelelectrophoresis" ("gelelectrophoresis_id", "sample_id", "experiment_id", "experiment_date", "position", "ladder", "voltage", "band_size_bp", "gel_type", "run_time_minutes", "person_id", "status_id") VALUES
    ('Gel-001', sample_id_w,  'Exp_eDNA_001', '2025-08-20', 'A1', '1kb Ladder', 100, 500, 'Agarose 1%', 45, 'peter.jones', 'Completed');

    -- 3.9 lab.pcr
    INSERT INTO "lab"."pcr" ("pcr_id", "pcr_date", "sample_id", "primer_id", "person_id", "kit", "storage_id", "project_id", "status_id") VALUES
    ('pcr25_001', '2025-08-21', sample_id_w,  '16S_V4_F', 'jane.doe', 'PCR Master Mix', 'S_R101_F1_B1', 'Proj_BioMon', 'PCR Done');

    -- 3.10 lab.library
    INSERT INTO "lab"."library" ("library_id", "experiment_id", "experiment_date", "sample_id", "library_name", "person_id", "library_prep_kit", "index_sequence", "project_id", "status_id") VALUES
    ('Lib_eDNA_001', 'Exp_eDNA_001', '2025-08-20', sample_id_w,  'eDNA_Lib_1', 'john.smith', 'Nextera XT', 'GATTACA', 'Proj_BioMon', 'Library Prep');

    -- 3.11 lab.sequencing_run
    INSERT INTO "lab"."sequencing_run" ("sequencing_run_id", "experiment_id", "experiment_date", "library_id", "prep_date", "sample_id", "person_id", "sequencer", "flow_cell_id", "total_reads", "project_id", "status_id") VALUES
    ('RS25_001', 'Exp_eDNA_001', '2025-08-20', 'Lib_eDNA_001', '2025-08-20', sample_id_w,  'john.smith', 'MiSeq', 'FC-A1', 15000000, 'Proj_BioMon', 'Sequencing Done');

    -- 3.12 lab.datasets
    INSERT INTO "lab"."datasets" ("dataset_id", "sample_id", "source_type", "ecosystem_id", "experiment_id", "experiment_date", "reception_date", "status_id", "storage_path") VALUES
    ('Z25S25Bio_001', sample_id_w,  'Sequencing', 'Estuary', 'Exp_eDNA_001', '2025-08-20', '2025-08-21', 'Received', '/data/proj/biomon/raw_seq_data');

    -- 3.13 lab.storage_log
    INSERT INTO "lab"."storage_log" ("sample_id", "storage_id", "person_id", "status_id", "storage_position", "notes") VALUES
    (sample_id_w,  'S_R101_F1_B1', 'jane.doe', 'Received', 'A1', 'Initial storage location after reception.');

    -- 3.14 lab.fishing
    INSERT INTO "lab"."fishing" ("sampling_id",  "taxon_id", "catch_kg") VALUES
    (sampling_id_val, 'Gadus_morhua', 15.2);

    -- 3.15 lab.individual_catch_catch
    INSERT INTO "lab"."individual_catch_catch" ("sampling_id", "taxon_id", "SL_mm", "weight_g", "sex") VALUES
    (sampling_id_val, 'Gadus_morhua', 350, 450, 'Male'),
    (sampling_id_val,  'Gadus_morhua', 420, 600, 'Female');

    -- 3.16 lab.sampling_abiotic_data
    INSERT INTO "lab"."sampling_abiotic_data" ("sampling_id", "temperature_sampling_depth_c", "salinity", "salinity_unit_id", "oxygen", "oxygen_unit_id") VALUES
    (sampling_id_val,  12.5, 28.5, 'PSU', 8.2, 'mg_L');

    -- 3.17 lab.dissections
    INSERT INTO "lab"."dissections" ("dissection_id", "person_id", "sample_id", "project_id", "experiment_id", "experiment_date", "gonad_weight_g", "liver_weight_g", "status_id") VALUES
    ('S25BioMon003_d1', 'jane.doe', sample_id_f,  'Proj_BioMon', 'Exp_eDNA_001', '2025-08-20', 55.2, 85.1, 'Completed');

    -- 3.18 lab.seq_dataset
    INSERT INTO "lab"."seq_dataset" ("data_seq_id", "sample_id", "sequencing_run_id", "sequencer", "total_reads", "raw_data_path", "status_id", "project_id", "notes", "data_seq_date") VALUES
    ('S25BioM_W_RS001', sample_id_w,  'RS25_001', 'MiSeq', 15000000, '/data/raw_seq/S25BioMon001', 'Completed', 'Proj_BioMon', 'eDNA sequencing dataset from water sample', '2025-08-20');

    -- 3.19 lab.otoliths
   INSERT INTO "lab"."otoliths" ("sample_id", "reader_person_id", "side", "age_reading_years", "project_id", "status_id") VALUES
    (sample_id_f, 'john.smith', 'left', 2.5, 'Proj_BioMon', 'Completed');

    -- 3.20 lab.tapestation
    INSERT INTO "lab"."tapestation" ("tapestation_id", "sample_id", "experiment_id", "experiment_date", "position", "kit", "person_id", "status_id") VALUES
    ('Tapes-001', sample_id_w, 'Exp_eDNA_001', '2025-08-20', '1', 'DNA ScreenTape', 'peter.jones', 'Completed');

    -- 3.21 lab.water
    INSERT INTO "lab"."water" ("sample_id", "volume_L", "filter", "depth_m", "sampling_method", "conservation_buffer", "status_id") VALUES
    (sample_id_w,  500, '0.45 um', 15.5, 'Niskin Bottle', 'Ethanol', 'Received');

    -- 3.22 lab.sediments
    INSERT INTO "lab"."sediments" ("sample_id", "volume", "volume_unit_id", "depth_m", "sampling_method", "conservation_buffer", "status_id") VALUES
    (sample_id_s,  100, 'milliliter', 15.5, 'Box Corer', 'DMSO', 'Received');

END $$;
-- ------------------------------------------------------------------------------------------------------------------

-- ======================================================================
-- 4. BIOINFORMATICS SCHEMA
-- ======================================================================

DO $$
DECLARE
    sample_id_w text;
    sample_id_s text;
    run_id_val text;
BEGIN
    SELECT "sample_id" INTO sample_id_w FROM "lab"."root_samples" WHERE "sample_type_id" = 'Water' AND "sample_creation_date" = '2025-05-01' LIMIT 1;
    SELECT "sample_id" INTO sample_id_s FROM "lab"."root_samples" WHERE "sample_type_id" = 'Sediment' AND "sample_creation_date" = '2025-05-01' LIMIT 1;
    
    INSERT INTO "bioinformatics"."analysis_pipelines" ("pipeline_name", "version", "repository_link", "experiment_id", "experiment_date", "status_id") VALUES
    ('eDNA_Metabarcoding_Pipeline', '1.0', 'https://github.com/my/pipeline', 'Exp_eDNA_001', '2025-08-20', 'Completed');

--    INSERT INTO "bioinformatics"."analysis_runs" ("run_id", "run_date", "pipeline_id", "sequencing_id", "sequencing_date", "person_id", "reference_db_id", "final_output_path", "experiment_id", "experiment_date", "status_id") VALUES
--    ('BI25_ar001', '2025-08-21', (SELECT "pipeline_id" FROM "bioinformatics"."analysis_pipelines" WHERE "pipeline_name" = 'eDNA_Metabarcoding_Pipeline'), 'RS25_001', '2025-08-20', 'peter.jones', (SELECT "db_id" FROM "reference"."reference_databases" WHERE "db_name" = 'NCBI RefSeq'), '/data/proj/biomon/analysis/run1', 'Exp_eDNA_001', '2025-08-21', 'Completed');

--    SELECT "run_id" INTO run_id_val FROM "bioinformatics"."analysis_runs" WHERE "sequencing_id" = 'RS25_001' AND "run_date" = '2025-08-21' LIMIT 1;

--    INSERT INTO "bioinformatics"."edna_assignments" ("assignment_id", "assignment_date", "run_id", "sample_id", "sample_creation_date", "taxon_id", "read_count", "confidence", "experiment_id", "experiment_date", "status_id") VALUES
--    ('BI25_S25Bio_001', '2025-08-21', run_id_val, sample_id_w, '2025-05-01', 'Gadus_morhua', 1500, 0.95, 'Exp_eDNA_001', '2025-08-21', 'Completed'),
--    ('BI25_S25Bio_002', '2025-08-21', run_id_val, sample_id_s, '2025-05-01', 'Bacteria_Unclassified', 5000, 0.70, 'Exp_eDNA_001', '2025-08-21', 'Completed');
END $$;
-- ------------------------------------------------------------------------------------------------------------------

-- ======================================================================
-- 5. PROJECTS SCHEMA - WANDERFISCHE PROJECT
-- ======================================================================

DO $$
DECLARE
    wander_fishing_id integer;
    wander_conv_id integer;
BEGIN
    INSERT INTO "projects"."ProjectWanderfische_FishingData" ("agency_id", "project_id", "agency_record_id", "record_date", "location_description", "water_body_name", "water_body_type", "catchment_area", "original_latitude", "original_longitude", "original_srid", "created_by") VALUES
    ('fisheries_agency', 'Proj_AquaGen', 'SFA_Rec_2024_001', '2024-06-01', 'Elbe Estuary Site A', 'Elbe', 'Estuary', 'Elbe', 53.9, 8.8, 4326, 'jane.doe');
    SELECT "fishing_record_id" INTO wander_fishing_id FROM "projects"."ProjectWanderfische_FishingData" WHERE "agency_record_id" = 'SFA_Rec_2024_001';

    INSERT INTO "projects"."ProjectWanderfische_FishCatch" ("fishing_record_id", "fishing_record_date", "taxon_id", "scientific_name_raw", "german_name_raw", "total_count", "adult_count", "notes") VALUES
    (wander_fishing_id, '2024-06-01', 'Gadus_morhua', 'Gadus morhua', 'Kabeljau', 5, 3, 'All adult fish were tagged.'),
    (wander_fishing_id, '2024-06-01', 'Gadus_morhua', 'Gadus morhua', 'Kabeljau', 2, 0, 'Juveniles found in the catch.');

    INSERT INTO "projects"."ProjectWanderfische_Mail" ("fishing_record_id", "fishing_record_date", "sender_person_id", "recipient_contact_id", "subject", "body", "sent_at") VALUES
    (wander_fishing_id, '2024-06-01', 'jane.doe', 'fisheries_agency', 'Data request for Elbe sampling', 'Hi, we are requesting raw data for the Elbe Estuary project.', '2024-06-05 10:00:00+02');

    INSERT INTO "projects"."ProjectWanderfische_Conversation" ("fishing_record_id", "fishing_record_date", "topic") VALUES
    (wander_fishing_id, '2024-06-01', 'Data transfer discussion for Elbe Estuary');
    SELECT "conversation_id" INTO wander_conv_id FROM "projects"."ProjectWanderfische_Conversation" WHERE "topic" LIKE 'Data transfer discussion%';

    INSERT INTO "projects"."ProjectWanderfische_ChatMessage" ("conversation_id", "sender_person_id", "message_text") VALUES
    (wander_conv_id, 'jane.doe', 'Received your email. We are working on providing the raw data files.'),
    (wander_conv_id, 'john.smith', 'Please compress the data before sending it.');
END $$;
