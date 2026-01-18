-- -------------------------------------------------
-- Code for lims and ELN and booking system 
-- For genetic and fish biology lab
-- V5., 2025-12-20
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
    "latitude" numeric,
    "longitude" numeric,
    "geo_type" text,
    "geography" geography(Geography, 4326), -- lat and lon and geotype combined to create this geographe
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
    "latitude" numeric,
    "longitude" numeric,
    "geo_type" text,
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
    "receiver_person_id" text REFERENCES "lims"."persons"("person_id"),
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
    "tag_id" text,
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
    "yield_qubit_ug" numeric GENERATED ALWAYS AS (volume_uL * conc_qubit / 1000) STORED,
    "conc_nanodrop" numeric,
    "conc_nanodrop_unit" text DEFAULT 'ng_ul',
    "yield_nanodrop_ug" numeric GENERATED ALWAYS AS (volume_uL * conc_nanodrop / 1000) STORED,
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
    "file_format" text C,
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
-- 14. functions
-- =========================================

-- F14.1. AUDIT LOGGING FUNCTION
-- ###################################### 

CREATE OR REPLACE FUNCTION "audit".fn_log_audit_action()
RETURNS TRIGGER AS $$
DECLARE
    v_old_data jsonb := NULL;
    v_new_data jsonb := NULL;
    v_person_id text;
BEGIN
    -- 1. Get the application-level user ID from a session variable
    -- This variable will be set by Flask app before running queries.
    BEGIN
        v_person_id := current_setting('session.logged_in_person_id', true);
    EXCEPTION WHEN OTHERS THEN
        v_person_id := NULL;
    END;

    -- 2. Determine the action and capture data snapshots
    IF (TG_OP = 'UPDATE') THEN
        v_old_data := row_to_json(OLD)::jsonb;
        v_new_data := row_to_json(NEW)::jsonb;
        
        -- Optimization: If the data hasn't actually changed, don't log it
        IF v_old_data = v_new_data THEN
            RETURN NEW;
        END IF;

    ELSIF (TG_OP = 'DELETE') THEN
        v_old_data := row_to_json(OLD)::jsonb;
        v_new_data := NULL;

    ELSIF (TG_OP = 'INSERT') THEN
        v_old_data := NULL;
        v_new_data := row_to_json(NEW)::jsonb;
    END IF;

    -- 3. Insert into the audit_log table
    INSERT INTO "audit"."audit_log" (
        "schema_name",
        "table_name",
        "user_db_name",
        "logged_in_person_id",
        "action",
        "original_data",
        "new_data",
        "query_text"
    )
    VALUES (
        TG_TABLE_SCHEMA,
        TG_TABLE_NAME,
        session_user, -- Captures 'postgres' or 'web_admin'
        v_person_id,  -- Captures the researcher's ID from your Flask UI
        SUBSTRING(TG_OP, 1, 1), -- 'I', 'U', or 'D'
        v_old_data,
        v_new_data,
        current_query()
    );

    IF (TG_OP = 'DELETE') THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- TRIGGER for applied function to all table
DO $$
DECLARE
    t RECORD;
    v_schema_list text[] := ARRAY[
        'reference', 'core', 'lims', 'field', 'bio_assets', 
        'biologyfish', 'moleculargenetics', 'bioinformatics', 
        'communications', 'eln'
    ];
BEGIN
    -- Loop through every table in the specified schemas
    FOR t IN 
        SELECT table_schema, table_name 
        FROM information_schema.tables 
        WHERE table_schema = ANY(v_schema_list) 
          AND table_type = 'BASE TABLE'
    LOOP
        -- 1. Drop the trigger if it already exists to avoid errors on re-runs
        EXECUTE format('DROP TRIGGER IF EXISTS trg_audit_log ON %I.%I', 
                        t.table_schema, t.table_name);

        -- 2. Create the new trigger
        EXECUTE format('CREATE TRIGGER trg_audit_log 
                        AFTER INSERT OR UPDATE OR DELETE ON %I.%I 
                        FOR EACH ROW EXECUTE FUNCTION "audit".fn_log_audit_action()', 
                        t.table_schema, t.table_name);
        
        RAISE NOTICE 'Audit enabled on table: %.%', t.table_schema, t.table_name;
    END LOOP;
END $$;



-- F14.2. Labeling FUNCTIONS
-- ############################################################################

-- F14.2.1 Hierarchical Sample ID (Roots and Children)
-- Logic: Root = TypeYYPrj000 | Child = ParentID_type#
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION bio_assets.fn_generate_hierarchical_sample_id()
RETURNS TRIGGER AS $$
DECLARE
    v_type_abrv text;
    v_prj_acronym text;
    v_year text;
    v_prefix text;
    v_next_serial int;
BEGIN
    -- Get Type Abbreviation (e.g., 'F', 'T', 'D', 'P')
    SELECT abbreviation INTO v_type_abrv FROM reference.sample_type WHERE sample_type_id = NEW.sample_type_id;

    -- CASE 1: ROOT SAMPLE (No Parent)
    IF NEW.parent_sample_id IS NULL THEN
        SELECT acronym INTO v_prj_acronym FROM lims.projects WHERE project_id = NEW.project_id;
        v_year := TO_CHAR(COALESCE(NEW.collection_date, CURRENT_DATE), 'YY');
        v_prefix := COALESCE(v_type_abrv, 'S') || v_year || COALESCE(v_prj_acronym, 'UNK');
        
        SELECT COALESCE(MAX(SUBSTRING(sample_id FROM LENGTH(v_prefix) + 1)::int), 0) + 1
        INTO v_next_serial FROM bio_assets.samples_root 
        WHERE sample_id LIKE v_prefix || '%' AND parent_sample_id IS NULL;
        
        NEW.sample_id := v_prefix || LPAD(v_next_serial::text, 3, '0');

    -- CASE 2: CHILD SAMPLE (Derived from Parent)
    ELSE
        v_prefix := NEW.parent_sample_id || '_' || LOWER(v_type_abrv);
        
        SELECT COALESCE(MAX(SUBSTRING(sample_id FROM LENGTH(v_prefix) + 1)::int), 0) + 1
        INTO v_next_serial FROM bio_assets.samples_root WHERE sample_id LIKE v_prefix || '%';
        
        NEW.sample_id := v_prefix || v_next_serial::text;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- F14.2.2 Field Sampling ID
-- Logic: YY + EcoAbrv + RegAbrv + _000
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION field.fn_generate_sampling_id()
RETURNS TRIGGER AS $$
DECLARE
    v_year text := TO_CHAR(NEW.sampling_date, 'YY');
    v_eco_abrv text;
    v_reg_abrv text;
    v_prefix text;
    v_next_serial int;
BEGIN
    SELECT ecosystem_abrv INTO v_eco_abrv FROM reference.ecosystem WHERE ecosystem_id = NEW.ecosystem_id;
    SELECT region_abrv INTO v_reg_abrv FROM reference.region WHERE region_id = NEW.region_id;
    
    v_prefix := v_year || COALESCE(v_eco_abrv, 'XX') || COALESCE(v_reg_abrv, 'XX') || '_';
    
    SELECT COALESCE(MAX(SUBSTRING(sampling_id FROM LENGTH(v_prefix) + 1)::int), 0) + 1
    INTO v_next_serial FROM field.sampling_event WHERE sampling_id LIKE v_prefix || '%';
    
    NEW.sampling_id := v_prefix || LPAD(v_next_serial::text, 3, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- F14.2.3 Metadata Table IDs
-- Logic: SampleID + _suffix_ + 00
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_generate_metadata_id()
RETURNS TRIGGER AS $$
DECLARE
    v_id_col text := TG_ARGV[0];
    v_suffix text := TG_ARGV[1];
    v_prefix text;
    v_next_serial int;
    v_pad int := COALESCE(TG_ARGV[2]::int, 2);
BEGIN
    v_prefix := NEW.sample_id || '_' || v_suffix || '_';

    EXECUTE format('SELECT COALESCE(MAX(SUBSTRING(%I FROM %L)::int), 0) + 1 
                    FROM %I.%I WHERE %I LIKE %L', 
                    v_id_col, LENGTH(v_prefix) + 1, TG_TABLE_SCHEMA, TG_TABLE_NAME, v_id_col, v_prefix || '%')
    INTO v_next_serial;

    NEW := jsonb_populate_record(NEW, jsonb_build_object(v_id_col, v_prefix || LPAD(v_next_serial::text, v_pad, '0')));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- F14.2.4 Administrative Sequence IDs
-- Logic: YY + tag + _0000 | Dataset: PrjYYds_0000
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_generate_sequence_id()
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

-- F14.2.5 Special IDs (Bookings & Chat)
-- Logic: Booking = YYYYMMDD000 | Chat = PrjYYMMDD_00
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_generate_special_ids()
RETURNS TRIGGER AS $$
DECLARE
    v_next_serial int;
BEGIN
    IF TG_TABLE_NAME = 'bookings' THEN
        DECLARE v_date_prefix text := TO_CHAR(NEW.start_time, 'YYYYMMDD');
        BEGIN
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
            SELECT COALESCE(MAX(SUBSTRING(message_id FROM LENGTH(v_prefix) + 1)::int), 0) + 1
            INTO v_next_serial FROM communications.projects_chat WHERE message_id LIKE v_prefix || '%';
            NEW.message_id := v_prefix || LPAD(v_next_serial::text, 2, '0');
        END;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- F14.2.6 Reservation ID (Manual Override or Auto)
-- Logic: TypeYYEcoReg_000
-- ----------------------------------------------------------------------------
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
    -- Manual check: if ID is already provided, skip auto-gen
    IF NEW.reservation_sample_id IS NOT NULL AND NEW.reservation_sample_id <> '' THEN
        RETURN NEW;
    END IF;

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

-- F14.2.7 Catch ID
-- Logic: SamplingID + _Sp0000
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION field.fn_generate_catch_id() 
RETURNS TRIGGER AS $$
BEGIN
    NEW.catch_id := NEW.sampling_id || '_Sp' || LPAD((SELECT COALESCE(COUNT(*),0)+1 FROM field.catch WHERE sampling_id = NEW.sampling_id)::text, 4, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- TRIGGER REGISTRATION

-- 1. Bio Assets & Field
CREATE TRIGGER trg_hierarchical_sample_id BEFORE INSERT ON bio_assets.samples_root FOR EACH ROW EXECUTE FUNCTION bio_assets.fn_generate_hierarchical_sample_id();
CREATE TRIGGER trg_field_sampling_id BEFORE INSERT ON field.sampling_event FOR EACH ROW EXECUTE FUNCTION field.fn_generate_sampling_id();
CREATE TRIGGER trg_gen_reservation_id BEFORE INSERT ON bio_assets.samples_reservation FOR EACH ROW EXECUTE FUNCTION bio_assets.fn_generate_reservation_id();
CREATE TRIGGER trg_catch_id BEFORE INSERT ON field.catch FOR EACH ROW EXECUTE FUNCTION field.fn_generate_catch_id();

-- 2. Metadata Tables
CREATE TRIGGER trg_gen_diss_id BEFORE INSERT ON biologyfish.dissection FOR EACH ROW EXECUTE FUNCTION public.fn_generate_metadata_id('dissection_id', 'd');
CREATE TRIGGER trg_gen_nano_id BEFORE INSERT ON moleculargenetics.nanodrop FOR EACH ROW EXECUTE FUNCTION public.fn_generate_metadata_id('measurement_id', 'nanodrop');
CREATE TRIGGER trg_gen_qubit_id BEFORE INSERT ON moleculargenetics.qubit FOR EACH ROW EXECUTE FUNCTION public.fn_generate_metadata_id('measurement_id', 'qubit');
CREATE TRIGGER trg_gen_tape_id BEFORE INSERT ON moleculargenetics.tapestation FOR EACH ROW EXECUTE FUNCTION public.fn_generate_metadata_id('measurement_id', 'tapestation');
CREATE TRIGGER trg_gen_qpcr_id BEFORE INSERT ON moleculargenetics.qpcr FOR EACH ROW EXECUTE FUNCTION public.fn_generate_metadata_id('qpcr_id', 'qpcr', 3);
CREATE TRIGGER trg_gen_gel_id  BEFORE INSERT ON moleculargenetics.gelelectrophoresis FOR EACH ROW EXECUTE FUNCTION public.fn_generate_metadata_id('gel_id', 'Gel', 3);
CREATE TRIGGER trg_gen_assign_id BEFORE INSERT ON bioinformatics.assignments FOR EACH ROW EXECUTE FUNCTION public.fn_generate_metadata_id('assignment_id', 'assign', 6);

-- 3. Sequences & Admin
CREATE TRIGGER trg_gen_ds_id   BEFORE INSERT ON bioinformatics.seq_dataset FOR EACH ROW EXECUTE FUNCTION public.fn_generate_sequence_id('dataset_id', 'ds');
CREATE TRIGGER trg_gen_prot_id BEFORE INSERT ON eln.protocols FOR EACH ROW EXECUTE FUNCTION public.fn_generate_sequence_id('protocol_id', 'prtcl');
CREATE TRIGGER trg_gen_plan_id BEFORE INSERT ON communications.internal_plans FOR EACH ROW EXECUTE FUNCTION public.fn_generate_sequence_id('plan_id', 'intpln');
CREATE TRIGGER trg_gen_rep_id  BEFORE INSERT ON communications.reports FOR EACH ROW EXECUTE FUNCTION public.fn_generate_sequence_id('report_id', 'rprt');
CREATE TRIGGER trg_gen_book_id BEFORE INSERT ON eln.bookings FOR EACH ROW EXECUTE FUNCTION public.fn_generate_special_ids();
CREATE TRIGGER trg_gen_chat_id BEFORE INSERT ON communications.projects_chat FOR EACH ROW EXECUTE FUNCTION public.fn_generate_special_ids();


-- F14.3. AUTO-RESOLVE SAMPLE ID FROM EXTERNAL/TEAM ID
-- ############################################################################

CREATE OR REPLACE FUNCTION public.fn_resolve_sample_id_from_external()
RETURNS TRIGGER AS $$
DECLARE
    v_resolved_id text;
BEGIN
    -- Only run if sample_id is missing but an external_id/team_id is provided
    IF (NEW.sample_id IS NULL OR NEW.sample_id = '') AND 
       (NEW.external_id IS NOT NULL AND NEW.external_id <> '') THEN

        -- Search in samples_root for a match in either external_id or team_id
        -- We also check that the sample_type_id matches (e.g., DNA to DNA)
        SELECT sample_id INTO v_resolved_id
        FROM bio_assets.samples_root
        WHERE (external_id = NEW.external_id OR team_id = NEW.external_id)
          AND is_active = true
        LIMIT 1;

        -- If found, auto-fill the sample_id
        IF v_resolved_id IS NOT NULL THEN
            NEW.sample_id := v_resolved_id;
        ELSE
            -- Optional: Raise an error if the team ID isn't registered in root first
            RAISE EXCEPTION 'ID % not found in bio_assets.samples_root. Please register the root sample first.', NEW.external_id;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger

-- Apply to DNA/Nucleic Acid
CREATE TRIGGER trg_resolve_dna_id 
BEFORE INSERT ON moleculargenetics.nucleic_acid
FOR EACH ROW EXECUTE FUNCTION public.fn_resolve_sample_id_from_external();

-- Apply to Tissue
CREATE TRIGGER trg_resolve_tissue_id 
BEFORE INSERT ON bio_assets.tissue
FOR EACH ROW EXECUTE FUNCTION public.fn_resolve_sample_id_from_external();

-- Apply to Dissection
CREATE TRIGGER trg_resolve_dissection_id 
BEFORE INSERT ON biologyfish.dissection
FOR EACH ROW EXECUTE FUNCTION public.fn_resolve_sample_id_from_external();



-- F14.4. COORDINATE TO GEOGRAPHY CONVERSION
-- ############################################

CREATE OR REPLACE FUNCTION public.fn_sync_latlon_to_geography()
RETURNS TRIGGER AS $$
BEGIN
    -- Only proceed if coordinates are available and have changed or geography is empty
    IF (NEW.latitude IS NOT NULL AND NEW.longitude IS NOT NULL) THEN
        IF (TG_OP = 'INSERT' OR 
            OLD.latitude IS DISTINCT FROM NEW.latitude OR 
            OLD.longitude IS DISTINCT FROM NEW.longitude OR
            (TG_TABLE_NAME = 'sampling_event' AND NEW.geography IS NULL) OR
            (TG_TABLE_NAME = 'fishing' AND NEW.fishing_geography IS NULL)) 
        THEN

            -- Determine which geography column to fill based on the table
            IF TG_TABLE_NAME = 'sampling_event' THEN
                -- Sampling events are typically Points
                NEW.geography := ST_SetSRID(ST_MakePoint(NEW.longitude, NEW.latitude), 4326)::geography;
            
            ELSIF TG_TABLE_NAME = 'fishing' THEN
                -- Fishing can be different types based on geo_type column
                CASE LOWER(COALESCE(NEW.geo_type, 'point'))
                    WHEN 'path' THEN
                        -- Assuming path logic might involve multiple points; 
                        -- simple implementation: create a point if only one set of lat/lon exists
                        NEW.fishing_geography := ST_SetSRID(ST_MakePoint(NEW.longitude, NEW.latitude), 4326)::geography;
                    WHEN 'shape' THEN
                        -- Placeholder for polygon logic
                        NEW.fishing_geography := ST_SetSRID(ST_MakePoint(NEW.longitude, NEW.latitude), 4326)::geography;
                    ELSE
                        -- Default to Point
                        NEW.fishing_geography := ST_SetSRID(ST_MakePoint(NEW.longitude, NEW.latitude), 4326)::geography;
                END CASE;
            END IF;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- Trigger

-- Apply to Sampling Event
CREATE TRIGGER trg_sync_geo_sampling
BEFORE INSERT OR UPDATE OF latitude, longitude ON field.sampling_event
FOR EACH ROW EXECUTE FUNCTION public.fn_sync_latlon_to_geography();

-- Apply to Fishing
CREATE TRIGGER trg_sync_geo_fishing
BEFORE INSERT OR UPDATE OF latitude, longitude ON field.fishing
FOR EACH ROW EXECUTE FUNCTION public.fn_sync_latlon_to_geography();



-- F14.5. UPDATED LTREE PATH FUNCTION for taxon
-- This version handles the specific V5 column names: parent_taxon_id and taxon_path
-- ############################################
CREATE OR REPLACE FUNCTION "reference".fn_update_taxon_path()
RETURNS TRIGGER AS $$
DECLARE
    v_parent_path ltree;
BEGIN
    IF NEW.parent_taxon_id IS NOT NULL THEN
        -- Get the path of the parent
        SELECT taxon_path INTO v_parent_path 
        FROM "reference"."taxon" 
        WHERE taxon_id = NEW.parent_taxon_id;
        
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Parent taxon % not found.', NEW.parent_taxon_id;
        END IF;
        -- Combine parent path with the new ID
        NEW.taxon_path := v_parent_path || NEW.taxon_id;
    ELSE
        -- Root level path
        NEW.taxon_path := NEW.taxon_id::ltree;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for Taxon
CREATE TRIGGER trg_update_taxon_path 
BEFORE INSERT OR UPDATE OF parent_taxon_id ON "reference"."taxon" 
FOR EACH ROW EXECUTE FUNCTION "reference".fn_update_taxon_path();

-- F14.6. Search Configuration and Column Setup
-- Create a custom text search configuration
-- #################################### 

-- 1. SEARCH CONFIGURATION
CREATE TEXT SEARCH DICTIONARY english_stem (TEMPLATE = snowball, LANGUAGE = english);
CREATE TEXT SEARCH CONFIGURATION public.lims_english (COPY = english);
ALTER TEXT SEARCH CONFIGURATION public.lims_english 
ALTER MAPPING FOR asciiword, asciihword, hword, hword_part, word WITH english_stem;

-- 2. ADD SEARCH COLUMNS TO ALL RELEVANT TABLES
ALTER TABLE "core"."persons" ADD COLUMN IF NOT EXISTS "search_vector" tsvector;
ALTER TABLE "core"."organizations" ADD COLUMN IF NOT EXISTS "search_vector" tsvector;
ALTER TABLE "core"."locations" ADD COLUMN IF NOT EXISTS "search_vector" tsvector;
ALTER TABLE "core"."equipments" ADD COLUMN IF NOT EXISTS "search_vector" tsvector;
ALTER TABLE "lims"."projects" ADD COLUMN IF NOT EXISTS "search_vector" tsvector;
ALTER TABLE "lims"."sop" ADD COLUMN IF NOT EXISTS "search_vector" tsvector;
ALTER TABLE "field"."sampling_event" ADD COLUMN IF NOT EXISTS "search_vector" tsvector;
ALTER TABLE "field"."fishing" ADD COLUMN IF NOT EXISTS "search_vector" tsvector;
ALTER TABLE "bio_assets"."samples_root" ADD COLUMN IF NOT EXISTS "search_vector" tsvector;
ALTER TABLE "bio_assets"."specimen_organisms" ADD COLUMN IF NOT EXISTS "search_vector" tsvector;
ALTER TABLE "biologyfish"."dissection" ADD COLUMN IF NOT EXISTS "search_vector" tsvector;
ALTER TABLE "moleculargenetics"."nucleic_acid" ADD COLUMN IF NOT EXISTS "search_vector" tsvector;
ALTER TABLE "bioinformatics"."pipelines" ADD COLUMN IF NOT EXISTS "search_vector" tsvector;
ALTER TABLE "eln"."protocols" ADD COLUMN IF NOT EXISTS "search_vector" tsvector;
ALTER TABLE "communications"."projects_chat" ADD COLUMN IF NOT EXISTS "search_vector" tsvector;


-- Core Schema
CREATE OR REPLACE FUNCTION core.fn_update_persons_search() RETURNS TRIGGER AS $$
BEGIN
    NEW.search_vector := TO_TSVECTOR('public.lims_english', COALESCE(NEW.first_name,'') || ' ' || COALESCE(NEW.last_name,'') || ' ' || COALESCE(NEW.email,'') || ' ' || COALESCE(NEW.notes,''));
    RETURN NEW;
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION core.fn_update_orgs_search() RETURNS TRIGGER AS $$
BEGIN
    NEW.search_vector := TO_TSVECTOR('public.lims_english', COALESCE(NEW.name,'') || ' ' || COALESCE(NEW.notes,''));
    RETURN NEW;
END; $$ LANGUAGE plpgsql;

-- LIMS & Projects
CREATE OR REPLACE FUNCTION lims.fn_update_projects_search() RETURNS TRIGGER AS $$
BEGIN
    NEW.search_vector := TO_TSVECTOR('public.lims_english', COALESCE(NEW.title,'') || ' ' || COALESCE(NEW.acronym,'') || ' ' || COALESCE(NEW.description,'') || ' ' || COALESCE(NEW.notes,''));
    RETURN NEW;
END; $$ LANGUAGE plpgsql;

-- Samples & Biology
CREATE OR REPLACE FUNCTION bio_assets.fn_update_samples_search() RETURNS TRIGGER AS $$
BEGIN
    NEW.search_vector := TO_TSVECTOR('public.lims_english', COALESCE(NEW.sample_id,'') || ' ' || COALESCE(NEW.external_id,'') || ' ' || COALESCE(NEW.team_id,'') || ' ' || COALESCE(NEW.notes,''));
    RETURN NEW;
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION biologyfish.fn_update_dissection_search() RETURNS TRIGGER AS $$
BEGIN
    NEW.search_vector := TO_TSVECTOR('public.lims_english', COALESCE(NEW.stomach_contents_text,'') || ' ' || COALESCE(NEW.parasite_observation,'') || ' ' || COALESCE(NEW.notes,''));
    RETURN NEW;
END; $$ LANGUAGE plpgsql;

-- Communications
CREATE OR REPLACE FUNCTION communications.fn_update_chat_search() RETURNS TRIGGER AS $$
BEGIN
    NEW.search_vector := TO_TSVECTOR('public.lims_english', COALESCE(NEW.message_body,''));
    RETURN NEW;
END; $$ LANGUAGE plpgsql;

-- 4. TRIGGER REGISTRATION

CREATE TRIGGER trg_search_persons BEFORE INSERT OR UPDATE ON core.persons FOR EACH ROW EXECUTE FUNCTION core.fn_update_persons_search();
CREATE TRIGGER trg_search_orgs BEFORE INSERT OR UPDATE ON core.organizations FOR EACH ROW EXECUTE FUNCTION core.fn_update_orgs_search();
CREATE TRIGGER trg_search_projects BEFORE INSERT OR UPDATE ON lims.projects FOR EACH ROW EXECUTE FUNCTION lims.fn_update_projects_search();
CREATE TRIGGER trg_search_samples BEFORE INSERT OR UPDATE ON bio_assets.samples_root FOR EACH ROW EXECUTE FUNCTION bio_assets.fn_update_samples_search();
CREATE TRIGGER trg_search_dissection BEFORE INSERT OR UPDATE ON biologyfish.dissection FOR EACH ROW EXECUTE FUNCTION biologyfish.fn_update_dissection_search();
CREATE TRIGGER trg_search_chat BEFORE INSERT OR UPDATE ON communications.projects_chat FOR EACH ROW EXECUTE FUNCTION communications.fn_update_chat_search();

-- 5. GIN INDEXES FOR PERFORMANCE
CREATE INDEX idx_fts_persons ON core.persons USING GIN(search_vector);
CREATE INDEX idx_fts_projects ON lims.projects USING GIN(search_vector);
CREATE INDEX idx_fts_samples ON bio_assets.samples_root USING GIN(search_vector);
CREATE INDEX idx_fts_dissection ON biologyfish.dissection USING GIN(search_vector);

-- F14.7. Global Search Function
-- #################################### 


CREATE OR REPLACE FUNCTION public.fn_global_search(p_search_term text)
RETURNS TABLE(
    schema_name text, 
    table_name text, 
    primary_key_id text, 
    matching_data jsonb
) AS $$
DECLARE
    rec RECORD;
    query text;
BEGIN
    -- Iterate through all tables that have a 'search_vector' column
    FOR rec IN
        SELECT 
            t.table_schema, 
            t.table_name,
            (SELECT column_name 
             FROM information_schema.key_column_usage 
             WHERE table_name = t.table_name 
               AND table_schema = t.table_schema 
             LIMIT 1) as pk_col
        FROM information_schema.columns t
        WHERE t.column_name = 'search_vector'
          AND t.table_schema NOT IN ('information_schema', 'pg_catalog', 'audit')
    LOOP
        -- Execute dynamic search query for each table
        query := format(
            'SELECT %L::text, %L::text, %I::text, to_jsonb(t) ' ||
            'FROM %I.%I AS t ' ||
            'WHERE t.search_vector @@ plainto_tsquery(%L, %L)',
            rec.table_schema, rec.table_name, rec.pk_col, 
            rec.table_schema, rec.table_name, 
            'public.lims_english', p_search_term
        );
        
        RETURN QUERY EXECUTE query;
    END LOOP;
END;
$$ LANGUAGE plpgsql STABLE;


-- 15. Index
-- #################################### 

-- 1. REFERENCE SCHEMA INDEXES (Taxonomy & Hierarchy)
CREATE INDEX idx_ref_taxon_path ON "reference"."taxon" USING GIST ("taxon_path");
CREATE INDEX idx_ref_taxon_parent ON "reference"."taxon" ("parent_taxon_id");
CREATE INDEX idx_ref_eco_path ON "reference"."ecosystem" USING GIST ("ecosystem_path");
CREATE INDEX idx_ref_reg_path ON "reference"."region" USING GIST ("region_path");

-- 2. CORE SCHEMA INDEXES (People & Orgs)
CREATE INDEX idx_core_pers_org ON "core"."persons" ("organization_id");
CREATE INDEX idx_core_pers_fts ON "core"."persons" USING GIN ("search_vector");
CREATE INDEX idx_core_org_fts ON "core"."organizations" USING GIN ("search_vector");
CREATE INDEX idx_core_loc_geog ON "core"."locations" USING GIST ("geography");
CREATE INDEX idx_core_loc_parent ON "core"."locations" ("parent_location_id");

-- 3. LIMS SCHEMA INDEXES (Projects & Storage)
CREATE INDEX idx_lims_proj_fts ON "lims"."projects" USING GIN ("search_vector");
CREATE INDEX idx_lims_proj_dates ON "lims"."projects" ("start_date", "end_date");
CREATE INDEX idx_lims_exp_proj ON "lims"."experiments" ("project_id");
CREATE INDEX idx_lims_stor_parent ON "lims"."storage_units" ("parent_storage_id");
CREATE INDEX idx_lims_inst_type ON "lims"."equipments" ("equipment_type_id");

-- 4. FIELD SCHEMA INDEXES (Geospatial & Events)
CREATE INDEX idx_field_samp_date ON "field"."sampling_event" ("sampling_date");
CREATE INDEX idx_field_samp_geog ON "field"."sampling_event" USING GIST ("geography");
CREATE INDEX idx_field_samp_eco ON "field"."sampling_event" ("ecosystem_id");
CREATE INDEX idx_field_fish_samp ON "field"."fishing" ("sampling_id");
CREATE INDEX idx_field_fish_geog ON "field"."fishing" USING GIST ("fishing_geography");
CREATE INDEX idx_field_catch_samp ON "field"."catch" ("sampling_id");
CREATE INDEX idx_field_catch_tax ON "field"."catch" ("taxon_id");

-- 5. BIO_ASSETS SCHEMA INDEXES (Sample Lineage)
CREATE INDEX idx_bio_root_parent ON "bio_assets"."samples_root" ("parent_sample_id");
CREATE INDEX idx_bio_root_samp_ev ON "bio_assets"."samples_root" ("sampling_id");
CREATE INDEX idx_bio_root_proj ON "bio_assets"."samples_root" ("project_id");
CREATE INDEX idx_bio_root_type ON "bio_assets"."samples_root" ("sample_type_id");
CREATE INDEX idx_bio_root_extid ON "bio_assets"."samples_root" ("external_id");
CREATE INDEX idx_bio_root_teamid ON "bio_assets"."samples_root" ("team_id");
CREATE INDEX idx_bio_root_fts ON "bio_assets"."samples_root" USING GIN ("search_vector");
CREATE INDEX idx_bio_res_samp_ev ON "bio_assets"."samples_reservation" ("sampling_id");

-- 6. BIOLOGYFISH & MOLECULAR INDEXES (Lab Metadata)
CREATE INDEX idx_biofish_spec_tax ON "bio_assets"."specimen_organisms" ("taxon_id");
CREATE INDEX idx_biofish_diss_fts ON "biologyfish"."dissection" USING GIN ("search_vector");
CREATE INDEX idx_mol_pcr_run ON "moleculargenetics"."pcr" ("run_id");
CREATE INDEX idx_mol_lib_sample ON "moleculargenetics"."library" ("sample_id");
CREATE INDEX idx_mol_seq_lib ON "moleculargenetics"."sequencing" ("library_id");

-- 7. BIOINFORMATICS & ELN INDEXES
CREATE INDEX idx_binfo_ds_proj ON "bioinformatics"."seq_dataset" ("project_id");
CREATE INDEX idx_binfo_assign_ds ON "bioinformatics"."assignments" ("dataset_id");
CREATE INDEX idx_eln_book_inst ON "eln"."bookings" ("equipment_id");
CREATE INDEX idx_eln_book_time ON "eln"."bookings" ("start_time", "end_time");
CREATE INDEX idx_eln_prot_fts ON "eln"."protocols" USING GIN ("search_vector");

-- 8. COMMUNICATIONS & AUDIT INDEXES
CREATE INDEX idx_comm_chat_proj ON "communications"."projects_chat" ("project_id");
CREATE INDEX idx_comm_chat_fts ON "communications"."projects_chat" USING GIN ("search_vector");
CREATE INDEX idx_audit_log_table ON "audit"."audit_log" ("schema_name", "table_name");
CREATE INDEX idx_audit_log_time ON "audit"."audit_log" ("action_timestamp");
CREATE INDEX idx_audit_log_person ON "audit"."audit_log" ("logged_in_person_id");