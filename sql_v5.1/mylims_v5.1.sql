-- -------------------------------------------------
-- Code for lims and ELN and booking system 
-- For genetic and fish biology lab
-- V5.1, 2025-1-31
-- -------------------------------------------------
-- this is complete whole database without passowrd


-- Create the password user
CREATE USER BioDiv WITH PASSWORD 'auth_password'; 

-- Create the database 'musr' 
CREATE DATABASE mylims OWNER BioDiv;

-- Create the schema and table (Run while connected to the musr database)
\c mylims; 

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
CREATE SCHEMA IF NOT EXISTS "reference"; -- referencial data that should not changed all time
CREATE SCHEMA IF NOT EXISTS "core"; -- personal, contacts, 
CREATE SCHEMA IF NOT EXISTS "lims"; -- storage, instruments...
CREATE SCHEMA IF NOT EXISTS "field"; -- field work
CREATE SCHEMA IF NOT EXISTS "bio_assets"; -- samples
CREATE SCHEMA IF NOT EXISTS "biologyfish"; -- fish biology analyses
CREATE SCHEMA IF NOT EXISTS "moleculargenetics"; -- molecular biology
CREATE SCHEMA IF NOT EXISTS "bioinformatics"; -- bioinformatics anaylses
CREATE SCHEMA IF NOT EXISTS "communications"; -- chat and exchange with others
CREATE SCHEMA IF NOT EXISTS "eln"; --
CREATE SCHEMA IF NOT EXISTS "audit"; -- 
CREATE SCHEMA IF NOT EXISTS "dashboard"; -- 

-- =========================================
-- 3. AUDIT SCHEMA
-- =========================================
CREATE TABLE IF NOT EXISTS "audit"."audit_log" (
    "id" bigserial PRIMARY KEY, --YYYYMMDDxxxxx  like 202601011 202601012
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
    "notes" text
);

CREATE TABLE IF NOT EXISTS "reference"."category" (
    "category_id" text PRIMARY KEY,
    "notes" text
);

CREATE TABLE IF NOT EXISTS "reference"."sample_type" (
    "sample_type_id" text PRIMARY KEY,
    "abbreviation" text UNIQUE NOT NULL,
    "rank" text,
    "sample_path" ltree,
    "notes" text
);

CREATE TABLE IF NOT EXISTS "reference"."units" (
    "unit_id" text PRIMARY KEY,
    "unit_name" text NOT NULL,
    "unit_abbreviation" text UNIQUE NOT NULL,
    "unit_type" text NOT NULL,
    "parent_unit_id" text REFERENCES "reference"."units"("unit_id"),
    "conversion_factor" numeric
);

CREATE TABLE IF NOT EXISTS "reference"."taxon" (
    -- species info taxomics info
    "taxon_id" text PRIMARY KEY, -- manual
    "parent_taxon_id" text REFERENCES "reference"."taxon"("taxon_id"),
    "scientific_name" text NOT NULL,
    "common_name_en" text,
    "common_name_de" text,
    "rank" text, -- species, family
    "taxon_path" ltree, -- e.g. Animalia.Chordata.Actinopterygii.Salmoniformes.Salmonidae.Salmo.salar
    "organism_type" text, -- e.g. 'fish', 'invertebrate', 'plant'
    -- YK: it is better to include it into the sample table or  with organism type to replaced these with organizme type, so that easier to select organizme type
    -- I was thinking maybe if we also sample other organisms for isotopes in the Weser, we should prep the database also for that? 
    -- "is_fish" boolean DEFAULT false , 
    -- "is_invertebrate" boolean DEFAULT false,
    -- "is_plant" boolean DEFAULT false,
    -- physiological limitation
    "has_fork_length" boolean DEFAULT false,
    "has_standard_length" boolean DEFAULT false,
    "has_otoliths" boolean DEFAULT false,
    "has_scales" boolean DEFAULT false,
    "min_total_length_mm" numeric,
    "max_total_length_mm" numeric,
    "min_fork_length_mm" numeric,
    "max_fork_length_mm" numeric,
    "min_standard_length_mm" numeric,
    "max_standard_length_mm" numeric,
    "min_weight_g" numeric,
    "max_weight_g" numeric,
    -- specification tags
    "tags_type" text,
    -- extra info
    "notes" text,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "reference"."region" (
    "region_id" text PRIMARY KEY, --manual name region
    "region_abrv" text UNIQUE NOT NULL,
    "parent_region" text,
    "rank" text,
    "region_path" ltree,
    "notes" text,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "reference"."ecosystem" (
    "ecosystem_id" text PRIMARY KEY, --manual
    "ecosystem_abrv" text UNIQUE NOT NULL,
    "notes" text,
    "rank" text,
    "ecosystem_path" ltree,
    "attachment_link" text
);


CREATE TABLE IF NOT EXISTS "reference"."genes" (
    "gene_id" text PRIMARY KEY, --manual
    "gene_name" text,
    "description" text,
    "notes" text,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "reference"."reference_databases" (
    "db_id" serial PRIMARY KEY, -- manual abrv database
    "db_name" text NOT NULL,
    "version" text,
    "url" text,
    "last_updated" date,
    "notes" text,
    "attachment_link" text
);


-- =========================================
-- 5. CORE SCHEMA
-- =========================================
CREATE TABLE IF NOT EXISTS "core"."organizations" (
    "organization_id" text PRIMARY KEY, -- manual organization abrv
    "name" text NOT NULL,
    "type" text CHECK (type IN ('Internal', 'Funder', 'Partner', 'Supplier', 'Customer')),
    "address" text,
    "country" text,
    "contact_email" text,
    "contact_phone" text,
    "notes" text,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "core"."persons" (
    "person_id" text PRIMARY KEY, -- manual first name or org_firstname
    "salutation" text,
    "first_name" text NOT NULL,
    "last_name" text NOT NULL,
    "email" text UNIQUE,
    "phone" text,
    "address" text,
    "country" text,
    "organization_id" text REFERENCES "core"."organizations"("organization_id"),
    "room" text,
	"role_in_org" text,
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "notes" text,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "core"."locations" (
    "build_id" text PRIMARY KEY, -- manual
    "parent_build_id" text REFERENCES "core"."locations"("build_id"),
    "name" text,
    "etage" text,
    "address" text,
    "organization_id" text REFERENCES "core"."organizations"("organization_id"),
    "city" text,
    "country" text,
    "rank" text,
    "location_path" ltree,
    "notes" text,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "core"."equipments" (
    "equipment_id" text PRIMARY KEY, -- manual
    "name" text NOT NULL,
    "model" text,
    "serial_number" text,
    "manufacturer_id" text REFERENCES "core"."organizations"("organization_id"),
    "purchase_date" date,
    "room_id" text REFERENCES "core"."locations"("build_id"),
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "notes" text,
    "attachment_link" text
);


CREATE TABLE IF NOT EXISTS "core"."vessel" (
    "vessel_id" text PRIMARY KEY, -- manual
    "vessel_name" text,
    "captain" text REFERENCES "core"."persons"("person_id"),
    "belong_to" text,
    "mmsi_number" text,
    "notes" text,
    "attachment_link" text
);

-- =========================================
-- 6. LIMS SCHEMA
-- =========================================
CREATE TABLE IF NOT EXISTS "lims"."projects" (
    "project_id" text PRIMARY KEY, -- manual e.g. AQP, ADA, MEM
    "title" text NOT NULL,
    "acronym" text NOT NULL,
    "grant_nr" text,
    "start_date" date,
    "end_date" date,
    "funding_source" text,
    "pi_person_id" text REFERENCES "core"."persons"("person_id"),
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "description" text,
    "report_date" text,
    "contact_finance" text,
    "contact_funder" text,
    "notes" text,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "lims"."project_personal" (
    "project_id" text REFERENCES "lims"."projects"("project_id") ON DELETE CASCADE,
    "person_id" text REFERENCES "core"."persons"("person_id") ON DELETE CASCADE,
    "role" text,
    "start_date" date,
    "end_date" date,
    PRIMARY KEY ("project_id", "person_id")
);

CREATE TABLE IF NOT EXISTS "lims"."permits" (
    "permit_id" text PRIMARY KEY, -- manual
    "permit_number" text,
    "issuing_authority" text,
    "valid_from" date,
    "valid_to" date,
    "reference" text,
    "project_id" text REFERENCES "lims"."projects"("project_id") ON DELETE CASCADE,
    "notes" text,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "lims"."sop" (
    "sop_id" text PRIMARY KEY, -- sopnrlab_version
    "title" text NOT NULL,
    "sop_nr_lab" text NOT NULL,
    "version" text,
    "author_id" text REFERENCES "core"."persons"("person_id"),
    "reviewer1_person_id" text  REFERENCES "core"."persons"("person_id"),
    "reviewer2_person_id" text  REFERENCES "core"."persons"("person_id"),
    "content" text,
    "is_active" boolean DEFAULT true,
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "attachment_link" text,
    "notes" text
);

CREATE TABLE IF NOT EXISTS "lims"."storage" (
    "storage_id" text PRIMARY KEY, -- manual
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
    "notes" text,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "lims"."reagents" (
    "reagent_id" text PRIMARY KEY, -- abrv manual
    "name" text NOT NULL,
    "lot_number" text,
    "supplier_id" text REFERENCES "core"."organizations"("organization_id"),
    "catalog_number" text,
    "expiry_date" date,
    "storage_id" text REFERENCES "lims"."storage"("storage_id"),
    "quantity" numeric,
    "unit_id" text REFERENCES "reference"."units"("unit_id"),
    "SDS_link" text,
    "notes" text,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "lims"."experiments" (
    "experiment_id" text PRIMARY KEY, -- manual according to lab
    "title" text,
    "processing_date" date NOT NULL DEFAULT CURRENT_DATE,
    "aim" text,
    "method" text,
    "sop_id" text REFERENCES "lims"."sop"("sop_id"),
    "person_id" text REFERENCES "core"."persons"("person_id"),
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "notes" text,
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
    "cruise_id" text PRIMARY KEY, -- manual according TI
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
    "notes" text
);

CREATE TABLE IF NOT EXISTS "field"."sampling_event" (
    "sampling_id" text PRIMARY KEY, -- YYEcoReg_000 
    "sampling_date" date NOT NULL,
    "External_sampling_id" text,
    "project_id" text REFERENCES "lims"."projects"("project_id"),
    "cruise_id" text REFERENCES "field"."cruises"("cruise_id"),
    "region_id" text REFERENCES "reference"."region"("region_id"),
    "ecosystem_id" text REFERENCES "reference"."ecosystem"("ecosystem_id"),
    "vessel_id" text REFERENCES "core"."vessel"("vessel_id"),
    "experiment_id" text REFERENCES "lims"."experiments"("experiment_id"),
    "latitude" numeric CHECK (latitude >= -90 AND latitude <= 90), 
    "longitude" numeric CHECK (longitude >= -180 AND longitude <= 180),
    "geo_type" text,
	"geography" geography(Geometry, 4326), -- Supports Point, LineString, or Polygon    
	"together_with_contact_id" text REFERENCES "core"."persons"("person_id"),
    "together_with_organization_id" text REFERENCES "core"."organizations"("organization_id"),
    "status_id" text DEFAULT 'Planned' NOT NULL REFERENCES "reference"."status"("status_id"),
    "notes" text,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "field"."sampling_abiotic" ( 
    "sampling_id" text PRIMARY KEY REFERENCES "field"."sampling_event"("sampling_id"),
    "weather" text,
    "temperature_atmospheric_c" numeric,
    "temperature_sampling_depth_c" numeric,
    "temperature_unit_id" text REFERENCES "reference"."units"("unit_id"),
    "ph" numeric,
    "turbidity_ntu" numeric,
    "oxygen" numeric,
    "oxygen_unit_id" text REFERENCES "reference"."units"("unit_id"),
    "salinity" numeric,
    "salinity_unit_id" text REFERENCES "reference"."units"("unit_id"),
    "conductivity" numeric,
    "conductivity_unit_id" text REFERENCES "reference"."units"("unit_id"),
    "pressure" numeric,
    "pressure_unit_id" text REFERENCES "reference"."units"("unit_id"),
    "nitrate_mg_l" numeric,
    "phosphate_mg_l" numeric,
    "chlorophyll_a_ug_l" numeric,
    "current_speed_m_s" numeric,
    "current_direction_deg" numeric,
    "tide_stage" text,
    "light_par_umol_m2_s" numeric,
    "sea_state" text,
    "cloud_cover_percent" numeric,
    "rainfall_mm" numeric,
    "visibility_m" numeric,
    "wind_speed" numeric,
    "wind_unit_id" text REFERENCES "reference"."units"("unit_id"),
    "secchi_depth_m" numeric,
    "attachment_link" text,
    "instrument_id" text REFERENCES "core"."equipments"("equipment_id"),
    "notes" text,
    "creation_date" timestamptz DEFAULT CURRENT_TIMESTAMP
);


CREATE TABLE IF NOT EXISTS "field"."fishing" (
    "sampling_id" text PRIMARY KEY REFERENCES "field"."sampling_event"("sampling_id"),
    "latitude" numeric CHECK (latitude >= -90 AND latitude <= 90), 
    "longitude" numeric CHECK (longitude >= -180 AND longitude <= 180),
    "geo_type" text,
	"fishing_geography" geography(Geometry, 4326), -- Supports Point, LineString, or Polygon
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
    "notes" text,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "field"."catch" (
    "catch_id" serial PRIMARY KEY, -- Samplingid_Sp_0001 for each species
    "sampling_id" text REFERENCES "field"."sampling_event"("sampling_id"),
    "total_catch_weight_kg" numeric,
    "taxon_id" text REFERENCES "reference"."taxon"("taxon_id"),
    "quantity_weight_kg" numeric,
    "quantity_count" integer,
    "notes" text,
    "attachment_link" text
);

-- 12 eLN

CREATE TABLE IF NOT EXISTS "eln"."batch" (
    "batch_id" text PRIMARY KEY, -- manual for being understandable 
    "name" text,
    "description" text,
    "creation_date" date DEFAULT CURRENT_DATE,
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "notes" text
);

CREATE TABLE IF NOT EXISTS "eln"."bookable_resources" (
    "resource_id" text PRIMARY KEY, --manual 
    "equipment_id" text REFERENCES "core"."equipments"("equipment_id"),
    "name" text,
    "is_active" boolean DEFAULT true,
    "calendar_color" text,
    "notes" text
);

-- =========================================
-- 8. BIO_ASSETS SCHEMA
-- =========================================
CREATE TABLE IF NOT EXISTS "bio_assets"."samples_reservation" (
    "reservation_sample_id" text PRIMARY KEY, -- W25WesHB_001 Typesampleabrv Year Eco Region abrvs _ serial number
    "sample_type_id" text NOT NULL REFERENCES "reference"."sample_type"("sample_type_id"),
    "project_id" text REFERENCES "lims"."projects"("project_id"),
    "sampling_id" text,
    "experiment_id" text REFERENCES "lims"."experiments"("experiment_id"),
    "planned_date" date,
    "transport" text,
    "conservation" text,
    "Sampler_id" text ,
    "status_id" text REFERENCES "reference"."status"("status_id") DEFAULT 'Planned',
    "is_sampled" boolean DEFAULT true,
    "is_pathogen" boolean DEFAULT false, 
    "other_info" text,
    "notes" text,
    "attachment_link" text,
    "actual_sample_id" text
);

CREATE TABLE IF NOT EXISTS "bio_assets"."samples_root" (
    "sample_id" text PRIMARY KEY, -- for root sample W25Prj_001; for child sample W25Prj_001_d_01
    "team_id" text,
    "external_id" text,
    "parent_sample_id" text REFERENCES "bio_assets"."samples_root"("sample_id"), -- if available then sample will be created is child
    "sample_type_id" text REFERENCES "reference"."sample_type"("sample_type_id"), -- what detemine the W or d of parent/child id
    "sampling_id" text REFERENCES "field"."sampling_event"("sampling_id"),
    "experiment_id" text REFERENCES "lims"."experiments"("experiment_id"),
    "collection_date" date,
    "storage_id" text REFERENCES "lims"."storage"("storage_id"),
    "storage_position" text,
    "sampler_person_id" text,
    "receiver_person_id" text REFERENCES "core"."persons"("person_id"),
    "reception_date" date,
    "transport" text,
    "conservation" text,
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "batch_id" text REFERENCES "eln"."batch"("batch_id"),
    "project_id" text REFERENCES "lims"."projects"("project_id"),
    "is_active" boolean DEFAULT true,
    "is_pathogen" boolean DEFAULT false, 
    "notes" text,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "lims"."experiments_samples" (
    "experiment_id" text REFERENCES "lims"."experiments"("experiment_id"),
    "sample_id" text REFERENCES "bio_assets"."samples_root"("sample_id"),
    "external_id" text,
    PRIMARY KEY ("experiment_id", "sample_id")
);


CREATE TABLE IF NOT EXISTS "bio_assets"."sediments" (
    "sample_id" text PRIMARY KEY REFERENCES "bio_assets"."samples_root"("sample_id"),
    "external_id" text,
    "grain_size" text,
    "weight_mg" numeric,
    "depth_m" numeric,
    "sampling_method" text,
    "notes" text,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "bio_assets"."water" (
    "sample_id" text PRIMARY KEY REFERENCES "bio_assets"."samples_root"("sample_id"),
    "external_id" text,
    "volume_filtered_ml" numeric,
    "filter_type" text,
    "pore_size_um" numeric,
    "depth_m" numeric,
    "sampling_method" text,
    "conservation" text,
    "notes" text,
    "attachment_link" text
);

-- =========================================
-- 9. BIOLOGYFISH SCHEMA
-- =========================================
CREATE TABLE IF NOT EXISTS "bio_assets"."specimen_organisms" (
    "sample_id" text PRIMARY KEY REFERENCES "bio_assets"."samples_root"("sample_id"),
    "external_id" text,
    "organism_type" text NOT NULL , -- Fish, plakton...
    "taxon_id" text REFERENCES "reference"."taxon"("taxon_id"),
    "weight_g" numeric,
    "standard_length_mm" numeric,
    "fork_length_mm" numeric,
    "total_length_mm" numeric,
    "eye_diameter_mm" numeric,
    "sex" text CHECK ("sex" IN ('M', 'F', 'U', NULL)), -- Male, Female, undetermined
    "reproductive_state" numeric,
    "life_stage" text,
    "Transmitter_ID" text,
    "PITTag" text,
    "notes" text,
    "person_id" text REFERENCES "core"."persons"("person_id"),
    "attachment_link" text,
    "processing_date" date
);

CREATE TABLE IF NOT EXISTS "biologyfish"."dissection" (
    "dissection_id" text PRIMARY KEY , -- sampleid_dissection_01
    "sample_id" text REFERENCES "bio_assets"."specimen_organisms"("sample_id"),
    "external_id" text,
    "taxon_id" text REFERENCES "reference"."taxon"("taxon_id"),
    "experiment_id" text REFERENCES "lims"."experiments"("experiment_id"),
    "processing_date" date,
    "weight_g" numeric,
    "standard_length_mm" numeric,
    "fork_length_mm" numeric,
    "total_length_mm" numeric,
    "eye_diameter_mm" numeric,
    "sex" text CHECK ("sex" IN ('M', 'F', 'U', NULL)), -- Male, Female, undetermined
    "reproductive_state" numeric,
    "liver_weight_g" numeric,
    "stomach_weight_g" numeric,
    "gonad_weight_g" numeric,
    "ug_per_egg" numeric,
    "transmitter_ID" text,
    "PITTag" text,
    "surgeon_ID" text,
    "genetics_sample" text,
    "Scale_Sample" text,
    "Scale_Proc" text,
    "Muscle_Sample" text,
    "Muscle_Iso_Hom" text,
    "Muscle_Iso_Wei" text,
    "Blood_Sample" text,
    "Eyelens_Sample" text,
    "Otolith_Sample" text,
    "Oto_Laser_Sample" text,
  	"Oto_Iso_Sample" text,
    "Stomach_Content" text,
    "stomach_fullness_index" text,
    "stomach_contents_text" text,
    "parasite_observation" text,
    "pathology_observation" text,
    "stomach_contents_jsonb" jsonb,
    "parasite_observation_jsonb" jsonb,
    "pathology_observation_jsonb" jsonb,
    "person_id" text REFERENCES "core"."persons"("person_id"),
    "notes" text,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "bio_assets"."tissue" (
    "sample_id" text PRIMARY KEY REFERENCES "bio_assets"."samples_root"("sample_id"),
    "external_id" text,
    "tissue_type" text,
    "preservation_medium" text,
    "weight_mg" numeric,
    "notes" text,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "biologyfish"."otoliths" (
    "otolith_id" text PRIMARY KEY,
    "experiment_id" text REFERENCES "lims"."experiments"("experiment_id"),
    "sample_id" text REFERENCES "bio_assets"."specimen_organisms"("sample_id"),
    "external_id" text,
    "age_read" integer,
    "read_by_person_id" text REFERENCES "core"."persons"("person_id"),
    "confidence_level" text,
    "image_path" text,
    "notes" text,
    "attachment_link" text
);


CREATE TABLE IF NOT EXISTS "biologyfish"."tag_mark" (
    "tag_id" text PRIMARY KEY,
    "sample_id" text REFERENCES "bio_assets"."specimen_organisms"("sample_id"),
    "external_id" text,
    "experiment_id" text REFERENCES "lims"."experiments"("experiment_id"),
    "processing_date" date,
    "weight_g" numeric,
    "total_length_mm" numeric,
    "model_type" text,
    "tag_ref" text,
    "notes" text,
    "attachment_link" text
);



-- =========================================
-- 10. MOLECULARGENETICS SCHEMA
-- =========================================
CREATE TABLE IF NOT EXISTS "moleculargenetics"."nucleic_acid" ( --RNA or DNA
    "sample_id" text PRIMARY KEY REFERENCES "bio_assets"."samples_root"("sample_id"),
    "external_id" text,
    "experiment_id" text REFERENCES "lims"."experiments"("experiment_id"),
    "processing_date" date,
    "extraction_method" text,
    "kit" text,
    "volume_uL" numeric,
    "volume_unit" text DEFAULT 'ul',
    "conc_qubit" numeric,
    "conc_qubit_unit" text DEFAULT 'ng_ul',
    "yield_qubit_ug" numeric GENERATED ALWAYS AS ("nucleic_acid"."volume_uL" * "nucleic_acid"."conc_qubit" / 1000) STORED,
    "conc_nanodrop" numeric,
    "conc_nanodrop_unit" text DEFAULT 'ng_ul',
    "yield_nanodrop_ug" numeric GENERATED ALWAYS AS ("nucleic_acid"."volume_uL" * "nucleic_acid"."conc_nanodrop" / 1000) STORED,
    "a260_280" numeric,
    "a260_230" numeric,
    "DIN_RIN_score" numeric, -- RIN or DIN
    "extraction_blank_id" text,
    "notes" text,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "moleculargenetics"."nanodrop" (
    "measurement_id" text PRIMARY KEY, --sampleid_nanodrop_00
    "sample_id" text REFERENCES "bio_assets"."samples_root"("sample_id"),
    "experiment_id" text REFERENCES "lims"."experiments"("experiment_id"),
    "processing_date" date,
    "concentration" numeric,
    "conc_unit" text DEFAULT 'ng_ul',
    "a260" numeric,
    "a280" numeric,
    "a260_a280" numeric,
    "a260_a230" numeric,
    "notes" text
);

CREATE TABLE IF NOT EXISTS "moleculargenetics"."qubit" (
    "measurement_id" text PRIMARY KEY, --sampleid_qubit_00
    "sample_id" text REFERENCES "bio_assets"."samples_root"("sample_id"),
    "processing_date" date,
    "concentration" numeric,
    "conc_unit" text DEFAULT 'ng_ul',
    "assay_type" text,
    "notes" text
);

CREATE TABLE IF NOT EXISTS "moleculargenetics"."tapestation" (
    "measurement_id" serial PRIMARY KEY, --sampleid_Tapestation_00
    "sample_id" text REFERENCES "bio_assets"."samples_root"("sample_id"),
    "processing_date" date,
    "avg_size_bp" numeric,
    "concentration" numeric,
    "conc_unit" text DEFAULT 'ng_ul',
    "molarity" numeric,
    "molarity_unit" text DEFAULT 'nmol/l',
    "Integrated_area_percent" numeric,
    "DIN_RIN" numeric,
    "kit" text,
    "notes" text
);

CREATE TABLE IF NOT EXISTS "moleculargenetics"."pcr" (
    "pcr_id" text PRIMARY KEY REFERENCES "bio_assets"."samples_root"("sample_id"), -- sampleid_pcr_000 
    "sample_id" text REFERENCES "bio_assets"."samples_root"("sample_id"),
    "experiment_id" text REFERENCES "lims"."experiments"("experiment_id"),
    "processing_date" date,
    "volume_reaction" numeric,
    "volume_sample" numeric,
    "dilution_factor" numeric,
    "primer_fwd_id" text,
    "primer_rev_id" text,
    "polymerase_mastermix" text,
    "cycles" integer,
    "annealing_temp_c" numeric,
    "position" text, -- A1
    "notes" text
);

CREATE TABLE IF NOT EXISTS "moleculargenetics"."qpcr" (
    "qpcr_id" text PRIMARY KEY, --sample_id_qPCR_00
    "processing_date" date,
    "sample_id" text REFERENCES "bio_assets"."samples_root"("sample_id"),
    "experiment_id" text REFERENCES "lims"."experiments"("experiment_id"),
    "target_gene_id" text REFERENCES "reference"."genes"("gene_id"),
    "polymerase_mastermix" text,
    "volume_reaction" numeric,
    "volume_sample" numeric,
    "dilution_factor" numeric,
    "position" text, -- A1
    "ct_value" numeric,
    "notes" text
);

CREATE TABLE IF NOT EXISTS "moleculargenetics"."gelelectrophoresis" (
    "gel_id" text PRIMARY KEY, --sample_id_Gel_000 
    "processing_date" date,
    "sample_id" text REFERENCES "bio_assets"."samples_root"("sample_id"),
    "pcr_id" text REFERENCES "moleculargenetics"."pcr"("pcr_id"),
    "external_id" text,
    "experiment_id" text REFERENCES "lims"."experiments"("experiment_id"),
    "gel_percentage" numeric,
    "volume_reaction" numeric,
    "volume_sample" numeric,
    "dilution_factor" numeric,
    "lader" text,
    "marker" text,
    "voltage" numeric,
    "run_time_min" integer,
    "band_size_bp" integer,
    "position" text, -- from left to right 1
    "image_path" text,
    "notes" text
);

CREATE TABLE "moleculargenetics"."library" (
    "library_id" text PRIMARY KEY REFERENCES "bio_assets"."samples_root"("sample_id"),
    "prep_kit" text,
    "processing_date" date,
    "avg_fragment_size" numeric,
    "concentration_ng_uL" numeric,
    "molarity_nm" numeric,
    "lib_barcode" text, -- unique per library
    "status_id" text REFERENCES reference.status("status_id"),
    "notes" text
);

CREATE TABLE "moleculargenetics"."library_samples" (
    "library_id" text REFERENCES "bio_assets"."samples_root"("sample_id"),
    "sample_id" text REFERENCES "bio_assets"."samples_root"("sample_id"),
    "sample_barcode" text, -- unique per sample within this library
    PRIMARY KEY ("library_id", "sample_id")
);


CREATE TABLE IF NOT EXISTS "moleculargenetics"."sequencing_flowcells" (
    "flowcell_id" text PRIMARY KEY, -- manual basing on workflow id producer
    "processing_date" date,
    "type" text,
    "sequencer_id" text REFERENCES "core"."equipments"("equipment_id"),
    "run_date" date,
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "notes" text
);

CREATE TABLE "moleculargenetics"."sequencing" (
    "run_id" text PRIMARY KEY, -- YYSeqRun_000 25SeqRun_000
    "flowcell_id" text REFERENCES "moleculargenetics"."sequencing_flowcells"("flowcell_id"),
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "notes" text
);

CREATE TABLE "moleculargenetics"."sequencing_libraries" (
    "run_id" text REFERENCES "moleculargenetics"."sequencing"("run_id") ON DELETE CASCADE,
    "library_id" text REFERENCES "bio_assets"."samples_root"("sample_id") ON DELETE CASCADE,
    "lane_number" integer,
    PRIMARY KEY ("run_id", "library_id")
);


-- =========================================
-- 11. BIOINFORMATICS SCHEMA
-- =========================================
CREATE TABLE IF NOT EXISTS "bioinformatics"."pipelines" (
    "pipeline_id" text PRIMARY KEY, -- pip_000
    "name" text NOT NULL,
    "version" text,
    "repository_url" text,
    "parameters_json" jsonb,
    "notes" text
);

CREATE TABLE IF NOT EXISTS "bioinformatics"."seq_dataset" (
    "dataset_id" text PRIMARY KEY, -- Prj25DS_000
    "description" text,
    "file_path" text,
    "file_format" text,
    "run_id" text REFERENCES "moleculargenetics"."sequencing"("run_id"),
    "read_count_filtered" bigint,
    "quality_metrics_json" jsonb,
    "checksum_md5" text,
    "notes" text
);

CREATE TABLE "bioinformatics"."seq_sample_assignment" (
    "dataset_id" text REFERENCES "bioinformatics"."seq_dataset"("dataset_id"),
    "sample_id" text REFERENCES "bio_assets"."samples_root"("sample_id"),
    "library_id" text REFERENCES "bio_assets"."samples_root"("sample_id"),
    "barcode" text, -- copy from library_samples
    "read_count" bigint,
    PRIMARY KEY ("dataset_id", "sample_id")
);

CREATE TABLE IF NOT EXISTS "bioinformatics"."assignments" (
    "assignment_id" bigserial PRIMARY KEY, -- sampleid_assign_000000
    "sample_id" text REFERENCES "bio_assets"."samples_root"("sample_id"),
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

CREATE TABLE IF NOT EXISTS "eln"."bookings" (
    "booking_id" bigserial PRIMARY KEY,  -- YYYYMMDD000
    "resource_id" text REFERENCES "eln"."bookable_resources"("resource_id"),
    "person_id" text REFERENCES "core"."persons"("person_id"),
    "start_time" timestamptz NOT NULL,
    "end_time" timestamptz NOT NULL,
    "project_id" text REFERENCES "lims"."projects"("project_id"),
    "notes" text
);

CREATE TABLE IF NOT EXISTS "eln"."protocols" (
    "protocol_id" text PRIMARY KEY, -- 25prtcl_0000
    "title" text NOT NULL,
    "experiment_id" text REFERENCES "lims"."experiments"("experiment_id"),
    "author_id" text REFERENCES "core"."persons"("person_id"),
    "created_at" date DEFAULT CURRENT_DATE,
    "content_json" jsonb,
    "version" text,
    "notes" text
);

CREATE TABLE IF NOT EXISTS "eln"."protocols_run" (
    "run_id" text PRIMARY KEY, --25rprtcl_0000
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
    "message_id" text PRIMARY KEY, -- PrjYYMMDD_00
    "project_id" text REFERENCES "lims"."projects"("project_id"),
    "sender_id" text REFERENCES "core"."persons"("person_id"),
    "sent_at" timestamptz DEFAULT CURRENT_TIMESTAMP,
    "message_body" text,
    "attachment_path" text
);

CREATE TABLE IF NOT EXISTS "communications"."internal_plans" (
    "plan_id" text PRIMARY KEY, -- 25intpln_000
    "title" text,
    "created_by" text REFERENCES "core"."persons"("person_id"),
    "deadline" date,
    "content" text,
    "status_id" text REFERENCES "reference"."status"("status_id")
);

CREATE TABLE IF NOT EXISTS "communications"."reports" (
    "report_id" text PRIMARY KEY, -- 25rprt_000
    "project_id" text REFERENCES "lims"."projects"("project_id"),
    "title" text,
    "generated_by" text REFERENCES "core"."persons"("person_id"),
    "generation_date" date DEFAULT CURRENT_DATE,
    "file_path" text,
    "type" text
);


-- =========================================
-- 14. FUNCTIONS & TRIGGERS
-- =========================================

-- 14.1 SETUP SEARCH CONFIGURATION
-- ----------------------------------------------------------------------------
-- Creates a specific text search configuration for the lab (English stemmer)
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_ts_config WHERE cfgname = 'lims_english') THEN
        CREATE TEXT SEARCH DICTIONARY english_stem (TEMPLATE = snowball, LANGUAGE = english);
        CREATE TEXT SEARCH CONFIGURATION dashboard.lims_english (COPY = english);
        ALTER TEXT SEARCH CONFIGURATION dashboard.lims_english 
        ALTER MAPPING FOR asciiword, asciihword, hword, hword_part, word WITH english_stem;
    END IF;
END $$;

-- 14.2 AUDIT LOGGING SYSTEM
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION "audit".fn_log_audit_action()
RETURNS TRIGGER AS $$
DECLARE
    v_old_data jsonb := NULL;
    v_new_data jsonb := NULL;
    v_person_id text;
BEGIN
    -- Attempt to capture the application-level user ID (if set by the app/API session)
    BEGIN
        v_person_id := current_setting('session.logged_in_person_id', true);
    EXCEPTION WHEN OTHERS THEN
        v_person_id := NULL;
    END;

    IF (TG_OP = 'UPDATE') THEN
        v_old_data := row_to_json(OLD)::jsonb;
        v_new_data := row_to_json(NEW)::jsonb;
        -- Optimization: Do not log if data hasn't changed
        IF v_old_data = v_new_data THEN RETURN NEW; END IF;
    ELSIF (TG_OP = 'DELETE') THEN
        v_old_data := row_to_json(OLD)::jsonb;
    ELSIF (TG_OP = 'INSERT') THEN
        v_new_data := row_to_json(NEW)::jsonb;
    END IF;

    INSERT INTO "audit"."audit_log" (
        "schema_name", "table_name", "user_db_name", "logged_in_person_id",
        "action", "original_data", "new_data", "query_text"
    )
    VALUES (
        TG_TABLE_SCHEMA, TG_TABLE_NAME, session_user, v_person_id,
        SUBSTRING(TG_OP, 1, 1), v_old_data, v_new_data, current_query()
    );

    IF (TG_OP = 'DELETE') THEN RETURN OLD; ELSE RETURN NEW; END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 14.3 ID GENERATION FUNCTIONS
-- ----------------------------------------------------------------------------

-- 14.3.1 Hierarchical Sample ID (Roots and Children)
-- Logic: Root = TypeYYPrj001 | Child = ParentID_type#
CREATE OR REPLACE FUNCTION bio_assets.fn_generate_hierarchical_sample_id()
RETURNS TRIGGER AS $$
DECLARE
    v_type_abrv text;
    v_prj_acronym text;
    v_year text;
    v_root_id text;
    v_prefix text;
    v_next_serial int;
BEGIN
    -- Concurrency Safety: Lock table to prevent duplicate IDs
    LOCK TABLE bio_assets.samples_root IN SHARE ROW EXCLUSIVE MODE;

    -- Get the abbreviation for the current sample type (e.g., 't', 'd', 'p')
    SELECT LOWER(abbreviation) INTO v_type_abrv 
    FROM reference.sample_type 
    WHERE sample_type_id = NEW.sample_type_id;

    -- CASE 1: ROOT SAMPLE
    IF NEW.parent_sample_id IS NULL THEN
        SELECT acronym INTO v_prj_acronym FROM lims.projects WHERE project_id = NEW.project_id;
        v_year := TO_CHAR(COALESCE(NEW.collection_date, CURRENT_DATE), 'YY');
        
        -- Format: TYPE + YEAR + PRJ (e.g., F20MG)
        v_prefix := UPPER(COALESCE(v_type_abrv, 'S')) || v_year || COALESCE(v_prj_acronym, 'UNK') || '_';
        
        -- Find the next serial for this root prefix
        SELECT COALESCE(MAX(SUBSTRING(sample_id FROM LENGTH(v_prefix) + 1)::int), 0) + 1
        INTO v_next_serial 
        FROM bio_assets.samples_root 
        WHERE sample_id LIKE v_prefix || '%' 
          AND sample_id NOT LIKE '%.%'; -- Ensure we only look at other roots
        
        NEW.sample_id := v_prefix || LPAD(v_next_serial::text, 3, '0');

    -- CASE 2: CHILD SAMPLE (Derived from a parent)
    ELSE
        -- Step A: Extract the true ROOT ID from the parent
        -- If parent is 'F20MG_001.t2', split_part returns 'F20MG_001'
        -- If parent is 'F20MG_001', split_part still returns 'F20MG_001'
        SELECT split_part(NEW.parent_sample_id, '.', 1) INTO v_root_id;
        
        -- Step B: Build the search prefix for THIS root and THIS type
        -- e.g., 'F20MG_001.d'
        v_prefix := v_root_id || '.' || LOWER(COALESCE(v_type_abrv, 'x'));
        
        -- Step C: Find the next serial for this specific root and type combination
        -- This counts how many of this type (e.g., DNA) exist for this specific fish
        SELECT COALESCE(MAX(SUBSTRING(sample_id FROM LENGTH(v_prefix) + 1)::int), 0) + 1
        INTO v_next_serial 
        FROM bio_assets.samples_root 
        WHERE sample_id LIKE v_prefix || '%';
        
        -- Step D: Assign the flat ID (e.g., F20MG_001.d5)
        NEW.sample_id := v_prefix || v_next_serial::text;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 14.3.2 Field Sampling ID
-- Logic: YY + Eco + Reg + _001
CREATE OR REPLACE FUNCTION field.fn_generate_sampling_id()
RETURNS TRIGGER AS $$
DECLARE
    v_year text := TO_CHAR(NEW.sampling_date, 'YY');
    v_eco_abrv text;
    v_reg_abrv text;
    v_prefix text;
    v_next_serial int;
BEGIN
    LOCK TABLE field.sampling_event IN SHARE ROW EXCLUSIVE MODE;

    SELECT ecosystem_abrv INTO v_eco_abrv FROM reference.ecosystem WHERE ecosystem_id = NEW.ecosystem_id;
    SELECT region_abrv INTO v_reg_abrv FROM reference.region WHERE region_id = NEW.region_id;
    
    v_prefix := v_year || COALESCE(v_eco_abrv, 'XX') || COALESCE(v_reg_abrv, 'XX') || '_';
    
    SELECT COALESCE(MAX(SUBSTRING(sampling_id FROM LENGTH(v_prefix) + 1)::int), 0) + 1
    INTO v_next_serial FROM field.sampling_event WHERE sampling_id LIKE v_prefix || '%';
    
    NEW.sampling_id := v_prefix || LPAD(v_next_serial::text, 3, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 14.3.3 Metadata Table IDs (Generic)
-- Logic: SampleID_suffix_01
CREATE OR REPLACE FUNCTION dashboard.fn_generate_metadata_id()
RETURNS TRIGGER AS $$
DECLARE
    v_id_col text := TG_ARGV[0]; 
    v_suffix text := TG_ARGV[1]; 
    v_pad int := COALESCE(TG_ARGV[2]::int, 2); 
    v_prefix text;
    v_next_serial int;
BEGIN
    IF NEW.sample_id IS NULL THEN RAISE EXCEPTION 'Sample ID missing for metadata generation'; END IF;

    v_prefix := NEW.sample_id || '_' || v_suffix || '_';

    EXECUTE format('SELECT COALESCE(MAX(SUBSTRING(%I FROM %L)::int), 0) + 1 
                    FROM %I.%I WHERE %I LIKE %L', 
                    v_id_col, LENGTH(v_prefix) + 1, TG_TABLE_SCHEMA, TG_TABLE_NAME, v_id_col, v_prefix || '%')
    INTO v_next_serial;

    NEW := jsonb_populate_record(NEW, jsonb_build_object(v_id_col, v_prefix || LPAD(v_next_serial::text, v_pad, '0')));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 14.3.4 Sequence IDs (Admin/ELN)
-- Logic: YYtag_0001
CREATE OR REPLACE FUNCTION dashboard.fn_generate_sequence_id()
RETURNS TRIGGER AS $$
DECLARE
    v_id_col text := TG_ARGV[0];
    v_tag text := TG_ARGV[1];
    v_year text := TO_CHAR(CURRENT_DATE, 'YY');
    v_prefix text;
    v_next_serial int;
BEGIN
    IF v_tag = 'ds' THEN
        DECLARE v_prj text;
        BEGIN
             SELECT acronym INTO v_prj FROM lims.projects WHERE project_id = NEW.project_id;
             v_prefix := COALESCE(v_prj, 'UNK') || v_year || 'ds_';
        END;
    ELSE
        v_prefix := v_year || v_tag || '_';
    END IF;

    EXECUTE format('SELECT COALESCE(MAX(SUBSTRING(%I FROM %L)::int), 0) + 1 
                    FROM %I.%I WHERE %I LIKE %L', 
                    v_id_col, LENGTH(v_prefix) + 1, TG_TABLE_SCHEMA, TG_TABLE_NAME, v_id_col, v_prefix || '%')
    INTO v_next_serial;

    NEW := jsonb_populate_record(NEW, jsonb_build_object(v_id_col, v_prefix || LPAD(v_next_serial::text, 4, '0')));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 14.3.5 Special IDs (Bookings & Chat)
CREATE OR REPLACE FUNCTION dashboard.fn_generate_special_ids()
RETURNS TRIGGER AS $$
DECLARE
    v_next_serial int;
BEGIN
    IF TG_TABLE_NAME = 'bookings' THEN
        DECLARE v_date_prefix text := TO_CHAR(NEW.start_time, 'YYYYMMDD');
        BEGIN
            LOCK TABLE eln.bookings IN SHARE ROW EXCLUSIVE MODE;
            SELECT COALESCE(MAX(SUBSTRING(booking_id::text FROM 9)::int), 0) + 1
            INTO v_next_serial FROM eln.bookings WHERE booking_id::text LIKE v_date_prefix || '%';
            NEW.booking_id := (v_date_prefix || LPAD(v_next_serial::text, 3, '0'))::bigint;
        END;
    ELSIF TG_TABLE_NAME = 'projects_chat' THEN
        DECLARE 
            v_prj text; 
            v_date text := TO_CHAR(CURRENT_TIMESTAMP, 'YYMMDD'); 
            v_prefix text;
        BEGIN
            SELECT acronym INTO v_prj FROM lims.projects WHERE project_id = NEW.project_id;
            v_prefix := COALESCE(v_prj, 'UNK') || v_date || '_';
            
            LOCK TABLE communications.projects_chat IN SHARE ROW EXCLUSIVE MODE;
            SELECT COALESCE(MAX(SUBSTRING(message_id FROM LENGTH(v_prefix) + 1)::int), 0) + 1
            INTO v_next_serial FROM communications.projects_chat WHERE message_id LIKE v_prefix || '%';
            NEW.message_id := v_prefix || LPAD(v_next_serial::text, 2, '0');
        END;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 14.3.6 Reservation IDs
-- Logic: TypeYYEcoReg_001
CREATE OR REPLACE FUNCTION bio_assets.fn_generate_reservation_id()
RETURNS TRIGGER AS $$
DECLARE
    v_type_abrv text;
    v_year text := TO_CHAR(COALESCE(NEW.planned_date, CURRENT_DATE), 'YY');
    v_eco_abrv text;
    v_reg_abrv text;
    v_prefix text;
    v_next_serial int;
BEGIN
    IF NEW.reservation_sample_id IS NOT NULL AND NEW.reservation_sample_id <> '' THEN
        RETURN NEW;
    END IF;

    LOCK TABLE bio_assets.samples_reservation IN SHARE ROW EXCLUSIVE MODE;

    SELECT abbreviation INTO v_type_abrv FROM reference.sample_type WHERE sample_type_id = NEW.sample_type_id;

    SELECT e.ecosystem_abrv, r.region_abrv INTO v_eco_abrv, v_reg_abrv
    FROM field.sampling_event s
    LEFT JOIN reference.ecosystem e ON s.ecosystem_id = e.ecosystem_id
    LEFT JOIN reference.region r ON s.region_id = r.region_id
    WHERE s.sampling_id = NEW.sampling_id;

    v_prefix := COALESCE(v_type_abrv, 'S') || v_year || COALESCE(v_eco_abrv, 'XX') || COALESCE(v_reg_abrv, 'XX') || '_';

    SELECT COALESCE(MAX(SUBSTRING(reservation_sample_id FROM LENGTH(v_prefix) + 1)::int), 0) + 1
    INTO v_next_serial FROM bio_assets.samples_reservation WHERE reservation_sample_id LIKE v_prefix || '%';

    NEW.reservation_sample_id := v_prefix || LPAD(v_next_serial::text, 3, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 14.3.7 Catch IDs
CREATE OR REPLACE FUNCTION field.fn_generate_catch_id() 
RETURNS TRIGGER AS $$
BEGIN
    -- Uses count as simple serial for catch within a sampling event
    NEW.catch_id := NEW.sampling_id || '_Sp' || LPAD((SELECT COALESCE(COUNT(*),0)+1 FROM field.catch WHERE sampling_id = NEW.sampling_id)::text, 4, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- 14.4 HELPER & SYNC FUNCTIONS
-- ----------------------------------------------------------------------------

-- 14.4.1 Auto-Resolve Sample ID from External ID
CREATE OR REPLACE FUNCTION dashboard.fn_resolve_sample_id_from_external()
RETURNS TRIGGER AS $$
DECLARE
    v_resolved_id text;
BEGIN
    IF (NEW.sample_id IS NULL OR NEW.sample_id = '') AND 
       (NEW.external_id IS NOT NULL AND NEW.external_id <> '') THEN
        SELECT sample_id INTO v_resolved_id
        FROM bio_assets.samples_root
        WHERE (external_id = NEW.external_id OR team_id = NEW.external_id)
          AND is_active = true
        LIMIT 1;

        IF v_resolved_id IS NOT NULL THEN
            NEW.sample_id := v_resolved_id;
        ELSE
            RAISE EXCEPTION 'ID % not found in bio_assets.samples_root.', NEW.external_id;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 14.4.2 Geography Sync (PostGIS)
-- Handles INSERT and UPDATE, including clearing geography if lat/lon is removed
CREATE OR REPLACE FUNCTION dashboard.fn_sync_latlon_to_geography()
RETURNS TRIGGER AS $$
BEGIN
    IF (NEW.latitude IS NOT NULL AND NEW.longitude IS NOT NULL) THEN
        IF TG_TABLE_NAME = 'sampling_event' THEN
            NEW.geography := ST_SetSRID(ST_MakePoint(NEW.longitude, NEW.latitude), 4326)::geography;
        ELSIF TG_TABLE_NAME = 'fishing' THEN
            NEW.fishing_geography := ST_SetSRID(ST_MakePoint(NEW.longitude, NEW.latitude), 4326)::geography;
        END IF;
    ELSIF (NEW.latitude IS NULL OR NEW.longitude IS NULL) THEN
        IF TG_TABLE_NAME = 'sampling_event' THEN
            NEW.geography := NULL;
        ELSIF TG_TABLE_NAME = 'fishing' THEN
            NEW.fishing_geography := NULL;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 14.4.3 Taxon Path
CREATE OR REPLACE FUNCTION "reference".fn_update_taxon_path()
RETURNS TRIGGER AS $$
DECLARE
    v_parent_path ltree;
BEGIN
    IF NEW.parent_taxon_id IS NOT NULL THEN
        SELECT taxon_path INTO v_parent_path 
        FROM "reference"."taxon" 
        WHERE taxon_id = NEW.parent_taxon_id;
        
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Parent taxon % not found.', NEW.parent_taxon_id;
        END IF;
        NEW.taxon_path := v_parent_path || NEW.taxon_id;
    ELSE
        NEW.taxon_path := NEW.taxon_id::ltree;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- 14.5 SEARCH VECTOR UPDATES
-- ----------------------------------------------------------------------------
DO $$
DECLARE
    t RECORD;
    -- List of your V5 schemas that need search capabilities
    v_schema_list text[] := ARRAY['core', 'lims', 'field', 'bio_assets', 'biologyfish', 'moleculargenetics', 'communications', 'eln'];
BEGIN
    FOR t IN 
        SELECT table_schema, table_name 
        FROM information_schema.tables 
        WHERE table_schema = ANY(v_schema_list) 
          AND table_type = 'BASE TABLE'
    LOOP
        -- Only add if the column doesn't already exist to avoid errors
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = t.table_schema 
              AND table_name = t.table_name 
              AND column_name = 'search_vector'
        ) THEN
            EXECUTE format('ALTER TABLE %I.%I ADD COLUMN search_vector tsvector', t.table_schema, t.table_name);
            RAISE NOTICE 'Added search_vector to %.%', t.table_schema, t.table_name;
        END IF;
    END LOOP;
END $$;


-- Standardizers for Full Text Search
CREATE OR REPLACE FUNCTION core.fn_update_persons_search() RETURNS TRIGGER AS $$
BEGIN
    NEW.search_vector := TO_TSVECTOR('dashboard.lims_english', CONCAT_WS(' ', NEW.first_name, NEW.last_name, NEW.email, NEW.notes));
    RETURN NEW;
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION core.fn_update_orgs_search() RETURNS TRIGGER AS $$
BEGIN
    NEW.search_vector := TO_TSVECTOR('dashboard.lims_english', CONCAT_WS(' ', NEW.name, NEW.notes));
    RETURN NEW;
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION lims.fn_update_projects_search() RETURNS TRIGGER AS $$
BEGIN
    NEW.search_vector := TO_TSVECTOR('dashboard.lims_english', CONCAT_WS(' ', NEW.title, NEW.acronym, NEW.description, NEW.notes));
    RETURN NEW;
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION bio_assets.fn_update_samples_search() RETURNS TRIGGER AS $$
BEGIN
    NEW.search_vector := TO_TSVECTOR('dashboard.lims_english', CONCAT_WS(' ', NEW.sample_id, NEW.external_id, NEW.team_id, NEW.notes));
    RETURN NEW;
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION biologyfish.fn_update_dissection_search() RETURNS TRIGGER AS $$
BEGIN
    NEW.search_vector := TO_TSVECTOR('dashboard.lims_english', CONCAT_WS(' ', NEW.stomach_contents_text, NEW.parasite_observation, NEW.notes));
    RETURN NEW;
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION communications.fn_update_chat_search() RETURNS TRIGGER AS $$
BEGIN
    NEW.search_vector := TO_TSVECTOR('dashboard.lims_english', COALESCE(NEW.message_body,''));
    RETURN NEW;
END; $$ LANGUAGE plpgsql;

-- 14.6 GLOBAL SEARCH FUNCTION
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION dashboard.fn_global_search(p_search_term text)
RETURNS TABLE(schema_name text, table_name text, primary_key_id text, matching_data jsonb) AS $$
DECLARE
    rec RECORD;
    query text;
BEGIN
    FOR rec IN
        SELECT t.table_schema, t.table_name,
            (SELECT column_name FROM information_schema.key_column_usage 
             WHERE table_name = t.table_name AND table_schema = t.table_schema LIMIT 1) as pk_col
        FROM information_schema.columns t
        WHERE t.column_name = 'search_vector'
          AND t.table_schema NOT IN ('information_schema', 'pg_catalog', 'audit')
    LOOP
        query := format(
            'SELECT %L::text, %L::text, %I::text, to_jsonb(t) FROM %I.%I AS t ' ||
            'WHERE t.search_vector @@ plainto_tsquery(%L, %L)',
            rec.table_schema, rec.table_name, rec.pk_col, rec.table_schema, rec.table_name, 
            'dashboard.lims_english', p_search_term
        );
        RETURN QUERY EXECUTE query;
    END LOOP;
END;
$$ LANGUAGE plpgsql STABLE;


-- 14.7 TRIGGER REGISTRATION 
-- ============================================================================

DO $$
BEGIN
    -- 1. Bio Assets & Field IDs
    DROP TRIGGER IF EXISTS trg_hierarchical_sample_id ON bio_assets.samples_root;
    CREATE TRIGGER trg_hierarchical_sample_id BEFORE INSERT ON bio_assets.samples_root FOR EACH ROW EXECUTE FUNCTION bio_assets.fn_generate_hierarchical_sample_id();

    DROP TRIGGER IF EXISTS trg_field_sampling_id ON field.sampling_event;
    CREATE TRIGGER trg_field_sampling_id BEFORE INSERT ON field.sampling_event FOR EACH ROW EXECUTE FUNCTION field.fn_generate_sampling_id();

    DROP TRIGGER IF EXISTS trg_gen_reservation_id ON bio_assets.samples_reservation;
    CREATE TRIGGER trg_gen_reservation_id BEFORE INSERT ON bio_assets.samples_reservation FOR EACH ROW EXECUTE FUNCTION bio_assets.fn_generate_reservation_id();

    DROP TRIGGER IF EXISTS trg_catch_id ON field.catch;
    CREATE TRIGGER trg_catch_id BEFORE INSERT ON field.catch FOR EACH ROW EXECUTE FUNCTION field.fn_generate_catch_id();

    -- 2. Metadata Tables (IDs)
    DROP TRIGGER IF EXISTS trg_gen_diss_id ON biologyfish.dissection;
    CREATE TRIGGER trg_gen_diss_id BEFORE INSERT ON biologyfish.dissection FOR EACH ROW EXECUTE FUNCTION dashboard.fn_generate_metadata_id('dissection_id', 'dissection');

    DROP TRIGGER IF EXISTS trg_gen_nano_id ON moleculargenetics.nanodrop;
    CREATE TRIGGER trg_gen_nano_id BEFORE INSERT ON moleculargenetics.nanodrop FOR EACH ROW EXECUTE FUNCTION dashboard.fn_generate_metadata_id('measurement_id', 'nanodrop');

    DROP TRIGGER IF EXISTS trg_gen_qubit_id ON moleculargenetics.qubit;
    CREATE TRIGGER trg_gen_qubit_id BEFORE INSERT ON moleculargenetics.qubit FOR EACH ROW EXECUTE FUNCTION dashboard.fn_generate_metadata_id('measurement_id', 'qubit');

    DROP TRIGGER IF EXISTS trg_gen_tape_id ON moleculargenetics.tapestation;
    CREATE TRIGGER trg_gen_tape_id BEFORE INSERT ON moleculargenetics.tapestation FOR EACH ROW EXECUTE FUNCTION dashboard.fn_generate_metadata_id('measurement_id', 'tapestation');

    DROP TRIGGER IF EXISTS trg_gen_qpcr_id ON moleculargenetics.qpcr;
    CREATE TRIGGER trg_gen_qpcr_id BEFORE INSERT ON moleculargenetics.qpcr FOR EACH ROW EXECUTE FUNCTION dashboard.fn_generate_metadata_id('qpcr_id', 'qpcr', 3);

    DROP TRIGGER IF EXISTS trg_gen_gel_id ON moleculargenetics.gelelectrophoresis;
    CREATE TRIGGER trg_gen_gel_id  BEFORE INSERT ON moleculargenetics.gelelectrophoresis FOR EACH ROW EXECUTE FUNCTION dashboard.fn_generate_metadata_id('gel_id', 'Gel', 3);

    DROP TRIGGER IF EXISTS trg_gen_assign_id ON bioinformatics.assignments;
    CREATE TRIGGER trg_gen_assign_id BEFORE INSERT ON bioinformatics.assignments FOR EACH ROW EXECUTE FUNCTION dashboard.fn_generate_metadata_id('assignment_id', 'assign', 6);

    -- 3. Sequence & Special IDs
    DROP TRIGGER IF EXISTS trg_gen_ds_id ON bioinformatics.seq_dataset;
    CREATE TRIGGER trg_gen_ds_id   BEFORE INSERT ON bioinformatics.seq_dataset FOR EACH ROW EXECUTE FUNCTION dashboard.fn_generate_sequence_id('dataset_id', 'ds');

    DROP TRIGGER IF EXISTS trg_gen_prot_id ON eln.protocols;
    CREATE TRIGGER trg_gen_prot_id BEFORE INSERT ON eln.protocols FOR EACH ROW EXECUTE FUNCTION dashboard.fn_generate_sequence_id('protocol_id', 'prtcl');

    DROP TRIGGER IF EXISTS trg_gen_plan_id ON communications.internal_plans;
    CREATE TRIGGER trg_gen_plan_id BEFORE INSERT ON communications.internal_plans FOR EACH ROW EXECUTE FUNCTION dashboard.fn_generate_sequence_id('plan_id', 'intpln');

    DROP TRIGGER IF EXISTS trg_gen_rep_id ON communications.reports;
    CREATE TRIGGER trg_gen_rep_id  BEFORE INSERT ON communications.reports FOR EACH ROW EXECUTE FUNCTION dashboard.fn_generate_sequence_id('report_id', 'rprt');

    DROP TRIGGER IF EXISTS trg_gen_book_id ON eln.bookings;
    CREATE TRIGGER trg_gen_book_id BEFORE INSERT ON eln.bookings FOR EACH ROW EXECUTE FUNCTION dashboard.fn_generate_special_ids();

    DROP TRIGGER IF EXISTS trg_gen_chat_id ON communications.projects_chat;
    CREATE TRIGGER trg_gen_chat_id BEFORE INSERT ON communications.projects_chat FOR EACH ROW EXECUTE FUNCTION dashboard.fn_generate_special_ids();

    -- 4. Sample Resolution (External ID Link)
    DROP TRIGGER IF EXISTS trg_resolve_dna_id ON moleculargenetics.nucleic_acid;
    CREATE TRIGGER trg_resolve_dna_id BEFORE INSERT ON moleculargenetics.nucleic_acid FOR EACH ROW EXECUTE FUNCTION dashboard.fn_resolve_sample_id_from_external();

    DROP TRIGGER IF EXISTS trg_resolve_tissue_id ON bio_assets.tissue;
    CREATE TRIGGER trg_resolve_tissue_id BEFORE INSERT ON bio_assets.tissue FOR EACH ROW EXECUTE FUNCTION dashboard.fn_resolve_sample_id_from_external();

    DROP TRIGGER IF EXISTS trg_resolve_dissection_id ON biologyfish.dissection;
    CREATE TRIGGER trg_resolve_dissection_id BEFORE INSERT ON biologyfish.dissection FOR EACH ROW EXECUTE FUNCTION dashboard.fn_resolve_sample_id_from_external();

    -- 5. Sync & Paths
    DROP TRIGGER IF EXISTS trg_sync_geo_sampling ON field.sampling_event;
    CREATE TRIGGER trg_sync_geo_sampling BEFORE INSERT OR UPDATE OF latitude, longitude ON field.sampling_event FOR EACH ROW EXECUTE FUNCTION dashboard.fn_sync_latlon_to_geography();

    DROP TRIGGER IF EXISTS trg_sync_geo_fishing ON field.fishing;
    CREATE TRIGGER trg_sync_geo_fishing BEFORE INSERT OR UPDATE OF latitude, longitude ON field.fishing FOR EACH ROW EXECUTE FUNCTION dashboard.fn_sync_latlon_to_geography();

    DROP TRIGGER IF EXISTS trg_update_taxon_path ON "reference"."taxon";
    CREATE TRIGGER trg_update_taxon_path BEFORE INSERT OR UPDATE OF parent_taxon_id ON "reference"."taxon" FOR EACH ROW EXECUTE FUNCTION "reference".fn_update_taxon_path();

    -- 6. Search Vectors
    DROP TRIGGER IF EXISTS trg_search_persons ON core.persons;
    CREATE TRIGGER trg_search_persons BEFORE INSERT OR UPDATE ON core.persons FOR EACH ROW EXECUTE FUNCTION core.fn_update_persons_search();

    DROP TRIGGER IF EXISTS trg_search_orgs ON core.organizations;
    CREATE TRIGGER trg_search_orgs BEFORE INSERT OR UPDATE ON core.organizations FOR EACH ROW EXECUTE FUNCTION core.fn_update_orgs_search();

    DROP TRIGGER IF EXISTS trg_search_projects ON lims.projects;
    CREATE TRIGGER trg_search_projects BEFORE INSERT OR UPDATE ON lims.projects FOR EACH ROW EXECUTE FUNCTION lims.fn_update_projects_search();

    DROP TRIGGER IF EXISTS trg_search_samples ON bio_assets.samples_root;
    CREATE TRIGGER trg_search_samples BEFORE INSERT OR UPDATE ON bio_assets.samples_root FOR EACH ROW EXECUTE FUNCTION bio_assets.fn_update_samples_search();

    DROP TRIGGER IF EXISTS trg_search_dissection ON biologyfish.dissection;
    CREATE TRIGGER trg_search_dissection BEFORE INSERT OR UPDATE ON biologyfish.dissection FOR EACH ROW EXECUTE FUNCTION biologyfish.fn_update_dissection_search();

    DROP TRIGGER IF EXISTS trg_search_chat ON communications.projects_chat;
    CREATE TRIGGER trg_search_chat BEFORE INSERT OR UPDATE ON communications.projects_chat FOR EACH ROW EXECUTE FUNCTION communications.fn_update_chat_search();
END $$;

-- 14.8 GLOBAL AUDIT ACTIVATION
-- ----------------------------------------------------------------------------
DO $$
DECLARE
    t RECORD;
    v_schema_list text[] := ARRAY['reference', 'core', 'lims', 'field', 'bio_assets', 'biologyfish', 'moleculargenetics', 'bioinformatics', 'communications', 'eln'];
BEGIN
    FOR t IN 
        SELECT table_schema, table_name FROM information_schema.tables 
        WHERE table_schema = ANY(v_schema_list) AND table_type = 'BASE TABLE'
    LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS trg_audit_log ON %I.%I', t.table_schema, t.table_name);
        EXECUTE format('CREATE TRIGGER trg_audit_log AFTER INSERT OR UPDATE OR DELETE ON %I.%I FOR EACH ROW EXECUTE FUNCTION "audit".fn_log_audit_action()', t.table_schema, t.table_name);
    END LOOP;
END $$;


-- =========================================
-- 15. INDEXES
-- =========================================

-- 15.1 REFERENCE SCHEMA (Hierarchy & Lookups)
CREATE INDEX IF NOT EXISTS idx_ref_taxon_path ON "reference"."taxon" USING GIST ("taxon_path");
CREATE INDEX IF NOT EXISTS idx_ref_taxon_parent ON "reference"."taxon" ("parent_taxon_id");
CREATE INDEX IF NOT EXISTS idx_ref_eco_path ON "reference"."ecosystem" USING GIST ("ecosystem_path");
CREATE INDEX IF NOT EXISTS idx_ref_reg_path ON "reference"."region" USING GIST ("region_path");
CREATE INDEX IF NOT EXISTS idx_ref_sci_name ON "reference"."taxon" USING gin ("scientific_name" gin_trgm_ops);

-- 15.2 CORE SCHEMA (Search & Relationships)
CREATE INDEX IF NOT EXISTS idx_core_pers_org ON "core"."persons" ("organization_id");
CREATE INDEX IF NOT EXISTS idx_core_pers_fts ON "core"."persons" USING GIN ("search_vector");
CREATE INDEX IF NOT EXISTS idx_core_org_fts ON "core"."organizations" USING GIN ("search_vector");
CREATE INDEX IF NOT EXISTS idx_core_loc_geog ON "core"."locations" USING GIST ("location_path");
CREATE INDEX IF NOT EXISTS idx_core_loc_parent ON "core"."locations" ("parent_build_id");
CREATE INDEX IF NOT EXISTS idx_core_equip_room ON "core"."equipments" ("room_id");

-- 15.3 LIMS SCHEMA (Projects & Experiments)
CREATE INDEX IF NOT EXISTS idx_lims_proj_fts ON "lims"."projects" USING GIN ("search_vector");
CREATE INDEX IF NOT EXISTS idx_lims_proj_dates ON "lims"."projects" ("start_date", "end_date");
CREATE INDEX IF NOT EXISTS idx_lims_exp_proj ON "lims"."experiments_projects" ("project_id");
CREATE INDEX IF NOT EXISTS idx_lims_stor_parent ON "lims"."storage" ("parent_storage_id");
CREATE INDEX IF NOT EXISTS idx_lims_exp_sop ON "lims"."experiments" ("sop_id");

-- 15.4 FIELD SCHEMA (Geospatial & Time)
CREATE INDEX IF NOT EXISTS idx_field_samp_date ON "field"."sampling_event" ("sampling_date");
CREATE INDEX IF NOT EXISTS idx_field_samp_geog ON "field"."sampling_event" USING GIST ("geography");
CREATE INDEX IF NOT EXISTS idx_field_samp_eco ON "field"."sampling_event" ("ecosystem_id");
CREATE INDEX IF NOT EXISTS idx_field_samp_cruise ON "field"."sampling_event" ("cruise_id");
CREATE INDEX IF NOT EXISTS idx_field_fish_samp ON "field"."fishing" ("sampling_id");
CREATE INDEX IF NOT EXISTS idx_field_fish_geog ON "field"."fishing" USING GIST ("fishing_geography");
CREATE INDEX IF NOT EXISTS idx_field_catch_samp ON "field"."catch" ("sampling_id");
CREATE INDEX IF NOT EXISTS idx_field_catch_tax ON "field"."catch" ("taxon_id");

-- 15.5 BIO_ASSETS SCHEMA (Lineage & Search)
CREATE INDEX IF NOT EXISTS idx_bio_root_parent ON "bio_assets"."samples_root" ("parent_sample_id");
CREATE INDEX IF NOT EXISTS idx_bio_root_samp_ev ON "bio_assets"."samples_root" ("sampling_id");
CREATE INDEX IF NOT EXISTS idx_bio_root_proj ON "bio_assets"."samples_root" ("project_id");
CREATE INDEX IF NOT EXISTS idx_bio_root_type ON "bio_assets"."samples_root" ("sample_type_id");
CREATE INDEX IF NOT EXISTS idx_bio_root_extid ON "bio_assets"."samples_root" ("external_id");
CREATE INDEX IF NOT EXISTS idx_bio_root_teamid ON "bio_assets"."samples_root" ("team_id");
CREATE INDEX IF NOT EXISTS idx_bio_root_fts ON "bio_assets"."samples_root" USING GIN ("search_vector");
CREATE INDEX IF NOT EXISTS idx_bio_res_samp_ev ON "bio_assets"."samples_reservation" ("sampling_id");

-- 15.6 BIOLOGYFISH & MOLECULAR INDEXES (Lab Metadata)
CREATE INDEX IF NOT EXISTS idx_biofish_spec_tax ON "bio_assets"."specimen_organisms" ("taxon_id");
CREATE INDEX IF NOT EXISTS idx_biofish_diss_fts ON "biologyfish"."dissection" USING GIN ("search_vector");
CREATE INDEX IF NOT EXISTS idx_biofish_diss_samp ON "biologyfish"."dissection" ("sample_id");
CREATE INDEX IF NOT EXISTS idx_mol_pcr_exp ON "moleculargenetics"."pcr" ("experiment_id");
CREATE INDEX IF NOT EXISTS idx_mol_seq_lib ON "moleculargenetics"."sequencing_libraries" ("library_id");
CREATE INDEX IF NOT EXISTS idx_mol_seq_run ON "moleculargenetics"."sequencing_libraries" ("run_id");

-- 15.7 BIOINFORMATICS & ELN INDEXES
CREATE INDEX IF NOT EXISTS idx_binfo_ds_run ON "bioinformatics"."seq_dataset" ("run_id");
CREATE INDEX IF NOT EXISTS idx_binfo_assign_ds ON "bioinformatics"."assignments" ("dataset_id");
CREATE INDEX IF NOT EXISTS idx_eln_book_res ON "eln"."bookings" ("resource_id");
CREATE INDEX IF NOT EXISTS idx_eln_book_time ON "eln"."bookings" ("start_time", "end_time");
CREATE INDEX IF NOT EXISTS idx_eln_prot_fts ON "eln"."protocols" USING GIN ("search_vector");
CREATE INDEX IF NOT EXISTS idx_eln_prot_json ON "eln"."protocols" USING GIN ("content_json");

-- 15.8 COMMUNICATIONS & AUDIT INDEXES
CREATE INDEX IF NOT EXISTS idx_comm_chat_proj ON "communications"."projects_chat" ("project_id");
CREATE INDEX IF NOT EXISTS idx_comm_chat_fts ON "communications"."projects_chat" USING GIN ("search_vector");
CREATE INDEX IF NOT EXISTS idx_audit_log_target ON "audit"."audit_log" ("schema_name", "table_name");
CREATE INDEX IF NOT EXISTS idx_audit_log_time ON "audit"."audit_log" ("action_timestamp");
CREATE INDEX IF NOT EXISTS idx_audit_log_person ON "audit"."audit_log" ("logged_in_person_id");



-- ==========================================================
-- 16. VIEWS & DASHBOARDS (CORRECTED & CLEAN)
-- ==========================================================

-- ----------------------------------------------------------------------------
-- 16.0. GLOBAL LAB OVERVIEW (Master View)
-- ----------------------------------------------------------------------------
-- ============================================================================
-- GLOBAL LAB OVERVIEW MASTER VIEW (V5.1 Optimized)
-- Consolidates all lab stages: Field -> Biology -> Molecular -> Bioinfo
-- ============================================================================

CREATE OR REPLACE VIEW dashboard.global_lab_overview AS
WITH 
-- 1. AGGREGATE MOLECULAR QC DATA
agg_nanodrop AS (
    SELECT sample_id, jsonb_agg(jsonb_build_object(
        'id', measurement_id, 'date', processing_date, 
        'conc', concentration, 'unit', conc_unit, 
        '260_280', a260_a280, '260_230', a260_a230
    )) as nanodrop_data
    FROM moleculargenetics.nanodrop GROUP BY sample_id
),
agg_qubit AS (
    SELECT sample_id, jsonb_agg(jsonb_build_object(
        'id', measurement_id, 'date', processing_date, 
        'conc', concentration, 'unit', conc_unit, 
        'assay', assay_type
    )) as qubit_data
    FROM moleculargenetics.qubit GROUP BY sample_id
),
agg_tapestation AS (
    SELECT sample_id, jsonb_agg(jsonb_build_object(
        'id', measurement_id, 'date', processing_date, 
        'avg_size', avg_size_bp, 'conc', concentration, 
        'rin', "DIN_RIN", 'molarity', molarity
    )) as tapestation_data
    FROM moleculargenetics.tapestation GROUP BY sample_id
),
agg_gel AS (
    SELECT sample_id, jsonb_agg(jsonb_build_object(
        'id', gel_id, 'date', processing_date, 
        'vol', volume_sample, 'band', band_size_bp, 
        'img', image_path
    )) as gel_data
    FROM moleculargenetics.gelelectrophoresis GROUP BY sample_id
),
agg_qpcr AS (
    SELECT sample_id, jsonb_agg(jsonb_build_object(
        'id', qpcr_id, 'date', processing_date, 
        'target', target_gene_id, 'ct', ct_value
    )) as qpcr_data
    FROM moleculargenetics.qpcr GROUP BY sample_id
),

-- 2. AGGREGATE SEQUENCING HISTORY
agg_sequencing AS (
    SELECT 
        sl.library_id, 
        jsonb_agg(jsonb_build_object(
            'run_id', s.run_id, 
            'lane', sl.lane_number,
            'flowcell', s.flowcell_id, 
            'date', fc.run_date, 
            'sequencer', fc.sequencer_id,
            'status', s.status_id
        )) as sequencing_history,
        MAX(s.run_id) as latest_run_id
    FROM moleculargenetics.sequencing_libraries sl
    JOIN moleculargenetics.sequencing s ON sl.run_id = s.run_id
    LEFT JOIN moleculargenetics.sequencing_flowcells fc ON s.flowcell_id = fc.flowcell_id
    GROUP BY sl.library_id
),

-- 3. AGGREGATE BIOINFORMATICS
agg_bioinfo AS (
    SELECT 
        sample_id, 
        SUM("count") as total_reads_assigned,
        COUNT(DISTINCT taxon_id) as distinct_taxa_count,
        jsonb_agg(jsonb_build_object(
            'taxon', taxon_id, 'count', "count", 'conf', confidence
        ) ORDER BY "count" DESC) FILTER (WHERE "count" > 10) as top_hits
    FROM bioinformatics.assignments 
    GROUP BY sample_id
)

SELECT
    -- === 1. IDENTITY & HIERARCHY ===
    s.sample_id,
    split_part(s.sample_id, '.', 1) AS root_id, -- Extraction of the Root/Fish ID
    s.external_id,
    s.team_id,
    s.sample_type_id,
    st.abbreviation as type_abrv,
    s.parent_sample_id,
    s.is_active,
    s.status_id as sample_status,
    s.collection_date,

    -- === 2. PROJECT & MANAGEMENT ===
    prj.project_id,
    prj.acronym as project_acronym,
    prj.title as project_title,
    prj.pi_person_id,
    b.batch_id,
    b.name as batch_name,
    exp.experiment_id,
    exp.title as experiment_title,
    sop.sop_id,
    sop.title as sop_title,

    -- === 3. STORAGE LOCATION ===
    s.storage_id,
    stor.name as storage_name,
    stor.type as storage_type,
    stor.room_id,
    s.storage_position,

    -- === 4. FIELD & SAMPLING CONTEXT ===
    se.sampling_id,
    se.sampling_date,
    se.latitude as sampling_lat,
    se.longitude as sampling_lon,
    r.region_abrv as region,
    e.ecosystem_abrv as ecosystem,
    cr.cruise_id,
    cr.name as cruise_name,
    v.vessel_name,
    
    -- Abiotic Data
    ab.temperature_sampling_depth_c as field_temp_c,
    ab.salinity as field_salinity,
    ab.oxygen as field_oxygen,
    ab.ph as field_ph,
    ab.turbidity_ntu,
    
    -- Fishing Event Data
    fish.fishing_method,
    fish.depth_m as fishing_depth,
    fish.total_catch_quantity_kg,

    -- === 5. BIOLOGICAL SPECIMEN ===
    spec.organism_type,
    tax.scientific_name,
    tax.common_name_en,
    spec.sex,
    spec.life_stage,
    spec.total_length_mm,
    spec.weight_g as specimen_weight_g,
    spec.processing_date as biology_processing_date,
    
    -- Dissection Details
    diss.dissection_id,
    diss.liver_weight_g,
    diss.gonad_weight_g,
    diss.stomach_contents_text,
    diss.parasite_observation,
    diss.notes as dissection_notes,
    
    -- Otoliths & Tags
    oto.otolith_id,
    oto.age_read,
    oto.confidence_level as otolith_confidence,
    tag.tag_id as tag_mark_id,
    tag.model_type as tag_model,

    -- === 6. ENVIRONMENTAL SAMPLES ===
    wat.volume_filtered_ml,
    wat.filter_type,
    sed.grain_size,
    sed.weight_mg as sediment_weight,
    tis.tissue_type,
    tis.preservation_medium,
	
	-- === 7. MOLECULAR: EXTRACTION ===
    na.extraction_method,
    na.kit as extraction_kit,
	na."volume_uL" as extract_vol,
    na.conc_qubit as extract_conc_qubit,
    na.conc_nanodrop as extract_conc_nano,
    na."DIN_RIN_score",
    na.yield_qubit_ug,
	
    -- === 8. MOLECULAR: PCR & PROCESSING ===
    pcr.pcr_id,
    pcr.cycles as pcr_cycles,
    pcr.polymerase_mastermix,
    pcr.primer_fwd_id,
    pcr.primer_rev_id,
    
    -- === 9. MOLECULAR QC AGGREGATES ===
    nd.nanodrop_data,
    qb.qubit_data,
    ts.tapestation_data,
    gl.gel_data,
    qp.qpcr_data,

    -- === 10. LIBRARY & SEQUENCING ===
    lib.library_id,
    lib.prep_kit as lib_kit,
    lib.avg_fragment_size,
    lib.lib_barcode,
    seq.sequencing_history,
    seq.latest_run_id,

    -- === 11. BIOINFORMATICS ===
    bi.total_reads_assigned,
    bi.distinct_taxa_count,
    bi.top_hits,
    ds.dataset_id, 
    ds.description as dataset_desc,
    ds.read_count_filtered as dataset_total_reads,
    
    -- === 12. METADATA ===
    s.attachment_link,
    s.notes as sample_notes

FROM bio_assets.samples_root s
-- Reference Lookups
LEFT JOIN reference.sample_type st ON s.sample_type_id = st.sample_type_id
-- LIMS Core
LEFT JOIN lims.projects prj ON s.project_id = prj.project_id
LEFT JOIN lims.storage stor ON s.storage_id = stor.storage_id
LEFT JOIN eln.batch b ON s.batch_id = b.batch_id
LEFT JOIN lims.experiments exp ON s.experiment_id = exp.experiment_id
LEFT JOIN lims.sop sop ON exp.sop_id = sop.sop_id
-- Field
LEFT JOIN field.sampling_event se ON s.sampling_id = se.sampling_id
LEFT JOIN reference.region r ON se.region_id = r.region_id
LEFT JOIN reference.ecosystem e ON se.ecosystem_id = e.ecosystem_id
LEFT JOIN field.cruises cr ON se.cruise_id = cr.cruise_id
LEFT JOIN core.vessel v ON se.vessel_id = v.vessel_id
LEFT JOIN field.sampling_abiotic ab ON se.sampling_id = ab.sampling_id
LEFT JOIN field.fishing fish ON se.sampling_id = fish.sampling_id
-- Biological
LEFT JOIN bio_assets.specimen_organisms spec ON s.sample_id = spec.sample_id
LEFT JOIN reference.taxon tax ON spec.taxon_id = tax.taxon_id
LEFT JOIN bio_assets.water wat ON s.sample_id = wat.sample_id
LEFT JOIN bio_assets.sediments sed ON s.sample_id = sed.sample_id
LEFT JOIN bio_assets.tissue tis ON s.sample_id = tis.sample_id
LEFT JOIN biologyfish.dissection diss ON spec.sample_id = diss.sample_id
LEFT JOIN biologyfish.otoliths oto ON spec.sample_id = oto.sample_id
LEFT JOIN biologyfish.tag_mark tag ON spec.sample_id = tag.sample_id
-- Molecular
LEFT JOIN moleculargenetics.nucleic_acid na ON s.sample_id = na.sample_id
LEFT JOIN moleculargenetics.pcr pcr ON s.sample_id = pcr.sample_id
LEFT JOIN moleculargenetics.library_samples ls ON s.sample_id = ls.sample_id
LEFT JOIN moleculargenetics.library lib ON ls.library_id = lib.library_id
-- Aggregates
LEFT JOIN agg_nanodrop nd ON s.sample_id = nd.sample_id
LEFT JOIN agg_qubit qb ON s.sample_id = qb.sample_id
LEFT JOIN agg_tapestation ts ON s.sample_id = ts.sample_id
LEFT JOIN agg_gel gl ON s.sample_id = gl.sample_id
LEFT JOIN agg_qpcr qp ON s.sample_id = qp.sample_id
LEFT JOIN agg_sequencing seq ON lib.library_id = seq.library_id
LEFT JOIN agg_bioinfo bi ON s.sample_id = bi.sample_id
-- Bioinformatics Join
LEFT JOIN bioinformatics.seq_sample_assignment ssa ON s.sample_id = ssa.sample_id
LEFT JOIN bioinformatics.seq_dataset ds ON ssa.dataset_id = ds.dataset_id;


-- ------------------------------------------------------------------
-- VIEW TO SHOW ROOT_ID EXPLICITLY
-- ------------------------------------------------------------------
-- This allows you to filter by "root" easily even if you only have the PCR ID

CREATE OR REPLACE VIEW bio_assets.view_samples_with_root AS
SELECT 
    sample_id,
    split_part(sample_id, '.', 1) AS root_id, -- Extracted Root
    parent_sample_id,
    sample_type_id,
    collection_date,
    project_id,
    CASE 
        WHEN sample_id LIKE '%.%' THEN 'Child'
        ELSE 'Root'
    END AS generation_level
FROM bio_assets.samples_root;

COMMENT ON FUNCTION bio_assets.fn_generate_hierarchical_sample_id() IS 
'Generates Root IDs as TXXPRJ_nnn and Child IDs as ROOT.TypeN, flattening the history for readability.';

-- ----------------------------------------------------------------------------
-- 16.2. FIELD & SPATIAL
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW field.view_sampling_map_data AS
SELECT 
    se.sampling_id,
    se.sampling_date,
    se.project_id,
    c.name AS cruise_name,
    v.vessel_name,
    r.region_abrv,
    e.ecosystem_abrv,
    se.latitude,
    se.longitude,
    jsonb_build_object(
        'type', 'Feature',
        'geometry', ST_AsGeoJSON(se.geography)::jsonb,
        'properties', jsonb_build_object(
            'id', se.sampling_id,
            'date', se.sampling_date,
            'cruise', c.name,
            'temp', ab.temperature_sampling_depth_c,
            'salinity', ab.salinity
        )
    ) AS geojson_feature
FROM field.sampling_event se
LEFT JOIN field.cruises c ON se.cruise_id = c.cruise_id
LEFT JOIN core.vessel v ON se.vessel_id = v.vessel_id
LEFT JOIN reference.region r ON se.region_id = r.region_id
LEFT JOIN reference.ecosystem e ON se.ecosystem_id = e.ecosystem_id
LEFT JOIN field.sampling_abiotic ab ON se.sampling_id = ab.sampling_id
WHERE se.latitude IS NOT NULL;

CREATE OR REPLACE VIEW field.view_catch_statistics AS
SELECT 
    c.sampling_id,
    se.sampling_date,
    r.region_abrv,
    t.scientific_name,
    t.common_name_en,
    SUM(c.quantity_weight_kg) AS total_biomass_kg,
    SUM(c.quantity_count) AS total_abundance,
    se.project_id
FROM field.catch c
JOIN field.sampling_event se ON c.sampling_id = se.sampling_id
JOIN reference.taxon t ON c.taxon_id = t.taxon_id
JOIN reference.region r ON se.region_id = r.region_id
GROUP BY c.sampling_id, se.sampling_date, r.region_abrv, t.scientific_name, t.common_name_en, se.project_id;


-- ----------------------------------------------------------------------------
-- 16.3. BIOLOGY & SPECIMEN
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW biologyfish.view_biological_profile AS
SELECT 
    spec.sample_id,
    spec.organism_type,
    t.scientific_name,
    spec.sex,
    spec.life_stage,
    spec.total_length_mm,
    spec.weight_g AS total_weight_g,
    d.liver_weight_g,
    d.gonad_weight_g,
    d.stomach_contents_text,
    d.parasite_observation,
    CASE WHEN spec.total_length_mm > 0 THEN 
        (spec.weight_g * 100) / (spec.total_length_mm ^ 3) 
    ELSE NULL END AS fulton_condition_factor,
    CASE WHEN spec.weight_g > 0 THEN 
        (d.gonad_weight_g / spec.weight_g) * 100 
    ELSE NULL END AS gonadosomatic_index_GSI,
    CASE WHEN spec.weight_g > 0 THEN 
        (d.liver_weight_g / spec.weight_g) * 100 
    ELSE NULL END AS hepatosomatic_index_HSI,
    oto.age_read AS otolith_age,
    oto.confidence_level AS age_confidence
FROM bio_assets.specimen_organisms spec
LEFT JOIN reference.taxon t ON spec.taxon_id = t.taxon_id
LEFT JOIN biologyfish.dissection d ON spec.sample_id = d.sample_id
LEFT JOIN biologyfish.otoliths oto ON spec.sample_id = oto.sample_id;


-- ----------------------------------------------------------------------------
-- 16.4. INVENTORY & STORAGE
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW lims.view_sample_location_paths AS
WITH RECURSIVE storage_tree AS (
    SELECT 
        storage_id, name, parent_storage_id, name::text AS full_path
    FROM lims.storage WHERE parent_storage_id IS NULL
    UNION ALL
    SELECT 
        s.storage_id, s.name, s.parent_storage_id, st.full_path || ' > ' || s.name
    FROM lims.storage s JOIN storage_tree st ON s.parent_storage_id = st.storage_id
)
SELECT 
    samp.sample_id, samp.sample_type_id, samp.external_id,
    st.full_path AS storage_location, samp.storage_position, samp.collection_date
FROM bio_assets.samples_root samp
JOIN storage_tree st ON samp.storage_id = st.storage_id
WHERE samp.is_active = true;

CREATE OR REPLACE VIEW lims.view_reagent_alerts AS
SELECT 
    r.reagent_id, r.name, r.lot_number, r.expiry_date, r.quantity, u.unit_abbreviation, st.name AS storage_location,
    CASE 
        WHEN r.expiry_date < CURRENT_DATE THEN 'EXPIRED'
        WHEN r.expiry_date < CURRENT_DATE + INTERVAL '30 days' THEN 'EXPIRING SOON'
        ELSE 'OK'
    END AS status_alert
FROM lims.reagents r
LEFT JOIN reference.units u ON r.unit_id = u.unit_id
LEFT JOIN lims.storage st ON r.storage_id = st.storage_id
WHERE r.expiry_date < CURRENT_DATE + INTERVAL '60 days'
ORDER BY r.expiry_date ASC;


-- ----------------------------------------------------------------------------
-- 16.5. MOLECULAR LAB & QC
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW moleculargenetics.view_extraction_qc_summary AS
SELECT 
    na.sample_id, na.extraction_method, na.kit, na.processing_date,
    na.yield_nanodrop_ug, na.yield_qubit_ug, na.a260_280, na.a260_230, na."DIN_RIN_score",
    CASE 
        WHEN na.a260_280 < 1.7 OR na.a260_280 > 2.1 THEN 'Check Purity'
        WHEN na.conc_qubit < 1.0 THEN 'Low Conc'
        ELSE 'Pass'
    END AS qc_flag
FROM moleculargenetics.nucleic_acid na;

-- CORRECTED: Removed invalid "sample_id" and replaced with "sample_count"
CREATE OR REPLACE VIEW moleculargenetics.view_sequencing_queue AS
SELECT 
    l.library_id,
    (SELECT COUNT(*) FROM moleculargenetics.library_samples WHERE library_id = l.library_id) AS sample_count,
    l.prep_kit, l.molarity_nm, l.lib_barcode, sl.run_id, seq.status_id AS run_status, fc.sequencer_id,
    CASE 
        WHEN sl.run_id IS NULL THEN 'Pending Assignment'
        WHEN seq.status_id = 'Completed' THEN 'Sequenced'
        WHEN seq.status_id = 'Running' THEN 'In Progress'
        ELSE 'Scheduled'
    END AS pipeline_stage
FROM moleculargenetics.library l
LEFT JOIN moleculargenetics.sequencing_libraries sl ON l.library_id = sl.library_id
LEFT JOIN moleculargenetics.sequencing seq ON sl.run_id = seq.run_id
LEFT JOIN moleculargenetics.sequencing_flowcells fc ON seq.flowcell_id = fc.flowcell_id;


-- ----------------------------------------------------------------------------
-- 16.6. BIOINFORMATICS
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW bioinformatics.view_taxonomy_results AS
SELECT 
    a.sample_id, ds.dataset_id, p.name AS pipeline_used, t.scientific_name, t.rank,
    a."count" AS read_count, -- FIXED QUOTES
    a.confidence,
    ROUND((a."count"::numeric / SUM(a."count") OVER (PARTITION BY a.sample_id)) * 100, 2) AS relative_abundance_pct
FROM bioinformatics.assignments a
JOIN bioinformatics.seq_dataset ds ON a.dataset_id = ds.dataset_id
JOIN bioinformatics.pipelines p ON a.pipeline_id = p.pipeline_id
JOIN reference.taxon t ON a.taxon_id = t.taxon_id;


-- ----------------------------------------------------------------------------
-- 16.7. ELN, ADMIN & SEARCH
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW eln.view_booking_calendar_events AS
SELECT 
    b.booking_id, res.name AS resource_title, res.calendar_color,
    p.first_name || ' ' || p.last_name AS booked_by,
    b.start_time, b.end_time, b.project_id, b.notes
FROM eln.bookings b
JOIN eln.bookable_resources res ON b.resource_id = res.resource_id
JOIN core.persons p ON b.person_id = p.person_id;

CREATE OR REPLACE VIEW audit.view_readable_log AS
SELECT 
    a.action_timestamp, a.schema_name, a.table_name, a.action,
    COALESCE(p.first_name || ' ' || p.last_name, a.user_db_name) AS actor,
    a.original_data, a.new_data, a.query_text
FROM audit.audit_log a
LEFT JOIN core.persons p ON a.logged_in_person_id = p.person_id
ORDER BY a.action_timestamp DESC;

CREATE OR REPLACE VIEW dashboard.view_global_search_index AS
    SELECT 'Person' as type, person_id as id, first_name || ' ' || last_name as label, search_vector FROM core.persons
    UNION ALL
    SELECT 'Project', project_id, title, search_vector FROM lims.projects
    UNION ALL
    SELECT 'Sample', sample_id, external_id || ' (' || sample_type_id || ')', search_vector FROM bio_assets.samples_root
    UNION ALL
    SELECT 'Protocol', protocol_id, title, search_vector FROM eln.protocols
    UNION ALL
    SELECT 'Chat', message_id, substring(message_body from 1 for 50), search_vector FROM communications.projects_chat;


-- ----------------------------------------------------------------------------
-- 16.8. LINEAGE & TRACEABILITY
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW bio_assets.view_downstream_lineage AS
WITH RECURSIVE hierarchy AS (
    SELECT 
        s.sample_id AS ancestor_sample_id, s.sample_id AS descendant_sample_id,
        s.sample_type_id AS descendant_type, 0 AS depth, s.sample_id::text AS path
    FROM bio_assets.samples_root s
    UNION ALL
    SELECT 
        h.ancestor_sample_id, s.sample_id, s.sample_type_id, h.depth + 1, h.path || ' -> ' || s.sample_id
    FROM bio_assets.samples_root s JOIN hierarchy h ON s.parent_sample_id = h.descendant_sample_id
)
SELECT 
    h.ancestor_sample_id, h.descendant_sample_id, h.descendant_type, h.depth, h.path,
    CASE WHEN d.dissection_id IS NOT NULL THEN 'Yes' ELSE NULL END AS is_dissected, d.weight_g AS dissected_weight,
    CASE WHEN na.sample_id IS NOT NULL THEN na.extraction_method ELSE NULL END AS extraction_method, na.yield_qubit_ug AS dna_yield,
    CASE WHEN lib.library_id IS NOT NULL THEN lib.prep_kit ELSE NULL END AS library_kit,
    CASE WHEN seq.run_id IS NOT NULL THEN seq.run_id ELSE NULL END AS sequencing_run
FROM hierarchy h
LEFT JOIN biologyfish.dissection d ON h.descendant_sample_id = d.sample_id
LEFT JOIN moleculargenetics.nucleic_acid na ON h.descendant_sample_id = na.sample_id
-- FIXED: Join Library via the mapping table
LEFT JOIN moleculargenetics.library_samples ls ON h.descendant_sample_id = ls.sample_id
LEFT JOIN moleculargenetics.library lib ON ls.library_id = lib.library_id
LEFT JOIN moleculargenetics.sequencing_libraries seq_lib ON lib.library_id = seq_lib.library_id
LEFT JOIN moleculargenetics.sequencing seq ON seq_lib.run_id = seq.run_id;

CREATE OR REPLACE VIEW bio_assets.view_upstream_provenance AS
WITH RECURSIVE ancestry AS (
    SELECT 
        s.sample_id AS target_child_id, s.sample_id AS ancestor_id,
        s.sample_type_id AS ancestor_type, 0 AS steps_up, s.sample_id::text AS lineage_path
    FROM bio_assets.samples_root s
    UNION ALL
    SELECT 
        a.target_child_id, s.sample_id, s.sample_type_id, a.steps_up + 1, s.sample_id || ' -> ' || a.lineage_path
    FROM bio_assets.samples_root s JOIN ancestry a ON s.sample_id = (SELECT parent_sample_id FROM bio_assets.samples_root WHERE sample_id = a.ancestor_id)
)
SELECT * FROM ancestry;


-- ----------------------------------------------------------------------------
-- 16.9. ADVANCED METRICS (Throughput MV only)
-- ----------------------------------------------------------------------------

-- MATERIALIZED VIEW: Full Lab Pipeline Throughput
CREATE MATERIALIZED VIEW IF NOT EXISTS "dashboard"."monthly_lab_throughput_mv" AS
WITH monthly_stats AS (
    SELECT TO_CHAR(processing_date, 'YYYY-MM') AS month_p, 'Biology: Dissection' AS stage, COUNT(*) AS count FROM biologyfish.dissection WHERE processing_date IS NOT NULL GROUP BY 1, 2
    UNION ALL
    SELECT TO_CHAR(processing_date, 'YYYY-MM') AS month_p, 'Molecular: Extraction' AS stage, COUNT(*) AS count FROM moleculargenetics.nucleic_acid WHERE processing_date IS NOT NULL GROUP BY 1, 2
    UNION ALL
    SELECT TO_CHAR(processing_date, 'YYYY-MM') AS month_p, 'Molecular: PCR' AS stage, COUNT(*) AS count FROM moleculargenetics.pcr WHERE processing_date IS NOT NULL GROUP BY 1, 2
    UNION ALL
    SELECT TO_CHAR(processing_date, 'YYYY-MM') AS month_p, 'Molecular: Library Prep' AS stage, COUNT(*) AS count FROM moleculargenetics.library WHERE processing_date IS NOT NULL GROUP BY 1, 2
    UNION ALL
    SELECT TO_CHAR(processing_date, 'YYYY-MM') AS month_p, 'QC: Tapestation' AS stage, COUNT(*) AS count FROM moleculargenetics.tapestation WHERE processing_date IS NOT NULL GROUP BY 1, 2
    UNION ALL
    SELECT TO_CHAR(fc.run_date, 'YYYY-MM') AS month_p, 'Sequencing: Run' AS stage, COUNT(s.run_id) AS count 
    FROM moleculargenetics.sequencing s JOIN moleculargenetics.sequencing_flowcells fc ON s.flowcell_id = fc.flowcell_id WHERE fc.run_date IS NOT NULL GROUP BY 1, 2
    UNION ALL
    SELECT TO_CHAR(fc.run_date, 'YYYY-MM') AS month_p, 'Bioinfo: Taxon Assignment' AS stage, COUNT(DISTINCT a.sample_id) AS count
    FROM bioinformatics.assignments a 
    JOIN bioinformatics.seq_dataset ds ON a.dataset_id = ds.dataset_id 
    JOIN moleculargenetics.sequencing s ON ds.run_id = s.run_id 
    JOIN moleculargenetics.sequencing_flowcells fc ON s.flowcell_id = fc.flowcell_id 
    WHERE fc.run_date IS NOT NULL GROUP BY 1, 2
)
SELECT month_p as month_period, stage, count, SUM(count) OVER (PARTITION BY stage ORDER BY month_p) as cumulative_total
FROM monthly_stats ORDER BY month_p DESC, stage ASC
WITH DATA;

CREATE INDEX idx_lab_throughput_period ON "dashboard"."monthly_lab_throughput_mv" (month_period);