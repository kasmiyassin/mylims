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
    "taxon_id" text PRIMARY KEY,
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
    "region_id" text PRIMARY KEY,
    "region_abrv" text UNIQUE NOT NULL,
    "parent_region" text,
    "rank" text,
    "region_path" ltree,
    "notes" text,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "reference"."ecosystem" (
    "ecosystem_id" text PRIMARY KEY,
    "ecosystem_abrv" text UNIQUE NOT NULL,
    "notes" text,
    "rank" text,
    "ecosystem_path" ltree,
    "attachment_link" text
);


CREATE TABLE IF NOT EXISTS "reference"."genes" (
    "gene_id" text PRIMARY KEY,
    "gene_name" text,
    "description" text,
    "notes" text,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "reference"."reference_databases" (
    "db_id" serial PRIMARY KEY,
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
    "organization_id" text PRIMARY KEY,
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
    "person_id" text PRIMARY KEY,
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
    "build_id" text PRIMARY KEY,
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
    "equipment_id" text PRIMARY KEY,
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
    "vessel_id" text PRIMARY KEY,
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
    "project_id" text PRIMARY KEY, -- e.g. AQP, ADA, MEM
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
    "permit_id" text PRIMARY KEY,
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
    "sop_id" text PRIMARY KEY,
    "title" text NOT NULL,
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
    "notes" text,
    "attachment_link" text
);

CREATE TABLE IF NOT EXISTS "lims"."reagents" (
    "reagent_id" text PRIMARY KEY, -- R0001
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
    "experiment_id" text PRIMARY KEY,
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
    "cruise_id" text PRIMARY KEY, -- manual
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
    "sampling_id" text PRIMARY KEY, -- 25RigEco001
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
    "geography" geography(Geography, 4326),
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
    "catch_id" serial PRIMARY KEY, -- Samplingid_0001
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
    "reservation_sample_id" text PRIMARY KEY,
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
    "sample_id" text PRIMARY KEY,
    "team_id" text,
    "external_id" text,
    "parent_sample_id" text REFERENCES "bio_assets"."samples_root"("sample_id"),
    "sample_type_id" text REFERENCES "reference"."sample_type"("sample_type_id"),
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
    "dissection_id" text PRIMARY KEY,
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
    "measurement_id" text PRIMARY KEY, --sampleid_nanodrop_000
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
    "measurement_id" text PRIMARY KEY, --sampleid_qubit_000
    "sample_id" text REFERENCES "bio_assets"."samples_root"("sample_id"),
    "processing_date" date,
    "concentration" numeric,
    "conc_unit" text DEFAULT 'ng_ul',
    "assay_type" text,
    "notes" text
);

CREATE TABLE IF NOT EXISTS "moleculargenetics"."tapestation" (
    "measurement_id" serial PRIMARY KEY, --sampleid_Tapestation_000
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
    "pcr_id" text PRIMARY KEY, -- sample_id_pcr_000 
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
    "qpcr_id" text PRIMARY KEY, --sample_id_qPCR_000
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
    "library_id" text PRIMARY KEY,
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
    "library_id" text REFERENCES "moleculargenetics"."library"("library_id") ON DELETE CASCADE,
    "sample_id" text REFERENCES "bio_assets"."samples_root"("sample_id"),
    "sample_barcode" text, -- unique per sample within this library
    PRIMARY KEY ("library_id", "sample_id")
);


CREATE TABLE IF NOT EXISTS "moleculargenetics"."sequencing_flowcells" (
    "flowcell_id" text PRIMARY KEY, -- manual
    "processing_date" date,
    "type" text,
    "sequencer_id" text REFERENCES "core"."equipments"("equipment_id"),
    "run_date" date,
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "notes" text
);

CREATE TABLE "moleculargenetics"."sequencing" (
    "run_id" text PRIMARY KEY,
    "flowcell_id" text REFERENCES "moleculargenetics"."sequencing_flowcells"("flowcell_id"),
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "notes" text
);

CREATE TABLE "moleculargenetics"."sequencing_libraries" (
    "run_id" text REFERENCES "moleculargenetics"."sequencing"("run_id") ON DELETE CASCADE,
    "library_id" text REFERENCES "moleculargenetics".library("library_id") ON DELETE CASCADE,
    "lane_number" integer,
    PRIMARY KEY ("run_id", "library_id")
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
    "checksum_md5" text,
    "notes" text
);

CREATE TABLE "bioinformatics"."seq_sample_assignment" (
    "dataset_id" text REFERENCES "bioinformatics"."seq_dataset"("dataset_id"),
    "sample_id" text REFERENCES "bio_assets"."samples_root"("sample_id"),
    "library_id" text REFERENCES "moleculargenetics"."library"("library_id"),
    "barcode" text, -- copy from library_samples
    "read_count" bigint,
    PRIMARY KEY ("dataset_id", "sample_id")
);

CREATE TABLE IF NOT EXISTS "bioinformatics"."assignments" (
    "assignment_id" bigserial PRIMARY KEY, --sampleid_read_000000
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
