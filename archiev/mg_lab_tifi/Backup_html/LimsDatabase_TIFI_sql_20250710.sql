-- =============================================
-- Schema Creation
-- =============================================
CREATE SCHEMA IF NOT EXISTS "Lab";
CREATE SCHEMA IF NOT EXISTS "Lims";
CREATE SCHEMA IF NOT EXISTS "reference";

-- =============================================
-- Schema: reference
-- =============================================

-- Table: reference.Status
CREATE TABLE IF NOT EXISTS "reference"."Status" (
    "nr" serial PRIMARY KEY,
    "status_id" text UNIQUE NOT NULL,
    "decscription" text,
    "modified_by" text,
    "time_modification" timestamptz
);

-- Table: reference.room
CREATE TABLE IF NOT EXISTS "reference"."room" (
    "nr" serial PRIMARY KEY,
    "room_id" text UNIQUE NOT NULL,
    "etage" text,
    "address" text,
    "decscription" text,
    "attachment" bytea,
    "modified_by" text,
    "time_modification" timestamptz
);

-- Table: reference.Genes
CREATE TABLE IF NOT EXISTS "reference"."Genes" (
    "nr" serial PRIMARY KEY,
    "primer_id" text UNIQUE NOT NULL,
    "TargetGene" text,
    "Primer_Sequence_Fwd" text,
    "Primer_Sequence_Rev" text,
    "probe" text,
    "decscription" text,
    "notes" text,
    "reference" tex,
    "attachment" byteat,
    "modified_by" text,
    "time_modification" timestamptz
);

-- Table: reference.region
CREATE TABLE IF NOT EXISTS "reference"."regionTab" (
    "nr" serial PRIMARY KEY,
    "region" text NOT NULL UNIQUE,
    "region_id" text UNIQUE NOT NULL,
    "country" text,
    "category" text,
    "notes" text,
    "attachment" bytea,
    "modified_by" text,
    "time_modification" timestamptz
);

-- Table: reference.SamplesType
CREATE TABLE IF NOT EXISTS "reference"."SamplesType" (
    "nr" serial PRIMARY KEY,
    "sample_type" text UNIQUE NOT NULL,
    "sample_typeAbrv" text UNIQUE NOT NULL,
    "decscription" text,
    "attachment" bytea,
    "modified_by" text,
    "time_modification" timestamptz
);

-- Table: reference.Species
CREATE TABLE IF NOT EXISTS "reference"."Species" (
    "nr" serial PRIMARY KEY,
    "Species" text UNIQUE NOT NULL,
    "Genus" text NOT NULL,
    "Order" text NOT NULL,
    "Family" text NOT NULL,
    "DE_name" text, -- German name
    "En_name" text, -- English name
    "maxlength" numeric,
    "max_age" numeric,
    "decscription" text,
    "attachment" bytea,
    "modified_by" text,
    "time_modification" timestamptz
);

-- Table: reference.Category
CREATE TABLE IF NOT EXISTS "reference"."Category" (
    "nr" serial PRIMARY KEY,
    "category" text UNIQUE NOT NULL,
    "decscription" text,
    "attachment" bytea,
    "modified_by" text,
    "time_modification" timestamptz
);

-- Table: reference.personal
CREATE TABLE IF NOT EXISTS "reference"."Personal" (
    "nr" serial PRIMARY KEY,
    "person" text NOT NULL,
    "person_id" text UNIQUE NOT NULL,
    "password_hash" text,
    "decscription" text,
    "attachment" bytea,
    "modified_by" text,
    "time_modification" timestamptz
);


-- Lims.Workflows
CREATE TABLE IF NOT EXISTS "Lims"."Workflows" (
    "Workflow_name" TEXT UNIQUE NOT NULL, -- e.g., 'Fish species ID', 'eDNA Water Monitoring'
    "Workflow_id" serial PRIMARY KEY,
    "decscription" TEXT,
    "attachment" bytea,
    "modified_by" text,
    "time_modification" timestamptz
);


-- Lims.Workflow_steps
CREATE TABLE IF NOT EXISTS "Lims"."Workflow_steps" (
    "step_id" SERIAL PRIMARY KEY,
    "Workflow_id" serial NOT NULL REFERENCES "reference"."Workflows"("Workflow_id") ON DELETE CASCADE,
    "Step_number" integer NOT NULL, -- The order of the step (1, 2, 3...)
    "Step_name" TEXT NOT NULL,       -- e.g., 'Extraction', 'PCR Amplification', 'Sequencing'
    "SOP_id" TEXT REFERENCES "Lims"."SOP"("sop_id"), -- The exact SOP for this step (Corrected to lowercase sop_id)
    "Target_table_name" TEXT NOT NULL, -- The table the UI should use (e.g., 'Lab.Extraction', 'Lab.PCR')
    "Workflow_Status_id" text REFERENCES "reference"."Status"("status_id") DEFAULT 'Received' NOT NULL,
    "modified_by" text,
    "time_modification" timestamptz,
    UNIQUE ("Workflow_id", "Step_number") -- Ensures each step in a Workflow is unique
);
-- =============================================
-- Schema: Lims
-- =============================================

-- Table: Lims.Projects
CREATE TABLE IF NOT EXISTS "Lims"."Projects" (
    "nr" serial PRIMARY KEY,
    "project_id" text UNIQUE NOT NULL,
    "Title" text,
    "status_id" text REFERENCES "reference"."Status"("status_id"),
    "PI" text REFERENCES "reference"."Personal"("person_id"),
    "Funder" text,
    "Start_date" date,
    "End_date" date,
    "Report_date" date,
    "notes" text,
    "linkpublication" text,
    "PermitNumber" text,
    "attachment" bytea,
    "modified_by" text,
    "time_modification" timestamptz
);

CREATE TABLE IF NOT EXISTS "Lims"."ProjectPersons" (
    "project_id" TEXT REFERENCES "Lims"."Projects"("project_id") ON DELETE CASCADE,
    "person_id" TEXT REFERENCES "reference"."Personal"("person_id") ON DELETE CASCADE,
    "role" TEXT,
    PRIMARY KEY ("project_id", "person_id"),
    "modified_by" text,
    "time_modification" timestamptz
);


-- Table: Lims.Equipment
CREATE TABLE IF NOT EXISTS "Lims"."Equipment" (
    "nr" serial PRIMARY KEY,
    "equipment_id" text UNIQUE NOT NULL,
    "equipment" text,
    "room_id" text REFERENCES "reference"."room"("room_id"),
    "lot" text,
    "Mobility" text,
    "DateManintenance" date,
    "notes" text,
    "attachment" bytea,
    "modified_by" text,
    "time_modification" timestamptz
);

-- Table: Lims.SOP
CREATE TABLE IF NOT EXISTS "Lims"."SOP" (
    "nr" serial PRIMARY KEY,
    "sop_id" text UNIQUE NOT NULL,
    "Title" text,
    "version" text,
    "author" text REFERENCES "reference"."Personal"("person_id"),
    "date_realise" date,
    "sop_protocol" text,
    "notes" text,
    "attachment" bytea,
    "modified_by" text,
    "time_modification" timestamptz
);

-- Table: Lims.orders
CREATE TABLE IF NOT EXISTS "Lims"."orders" (
    "nr" serial PRIMARY KEY,
    "FI_Order_Nr" text UNIQUE,
    "item" text,
    "category" text REFERENCES "reference"."Category"("category"),
    "Date" date,
    "price" numeric,
    "Quantity" text,
    "project_id" text REFERENCES "Lims"."Projects"("project_id"),
    "Company" text,
    "notes" text,
    "status_id" text REFERENCES "reference"."Status"("status_id"),
    "attachment" bytea,
    "modified_by" text,
    "time_modification" timestamptz
);



-- =============================================
-- Schema: Lab
-- =============================================

-- Table: Lab.Storage
CREATE TABLE IF NOT EXISTS "Lab"."Storage" (
    "nr" serial PRIMARY KEY,
    "storage_id" text UNIQUE NOT NULL,
    "room_id" text REFERENCES "reference"."room"("room_id"),
    "Freezer" text,
    "Etage" text,
    "Temperature" numeric,
    "TemperatureUnit" text,
    "Box" text,
    "BoxX_ABC" numeric,
    "BoxY_123" numeric,
    "project_id" text REFERENCES "Lims"."Projects"("project_id"),
    "notes" text,
    "attachment" bytea,
    "modified_by" text,
    "time_modification" timestamptz
);


-- Table: Lims.Reagents
CREATE TABLE IF NOT EXISTS "Lims"."Reagents" (
    "nr" serial PRIMARY KEY,
    "Reagent_Name" text UNIQUE NOT NULL,
    "Reagent_CompleteName" text NOT NULL,
    "category" text REFERENCES "reference"."Category"("category"),
    "Lot" text,
    "storage_id" text REFERENCES "Lab"."Storage"("storage_id"),
    "storage_position" numeric,
    "status_id" text REFERENCES "reference"."Status"("status_id"),
    "Recieption_date" date,
    "Expire_date" date,
    "project_id" text REFERENCES "Lims"."Projects"("project_id"),
    "attachment" bytea,
    "notes" text,
    "modified_by" text,
    "time_modification" timestamptz
);

-- Table: Lab.Sampling
CREATE TABLE IF NOT EXISTS "Lab"."Sampling" (
    "nr" serial PRIMARY KEY,
    "Sampling_id" text UNIQUE NOT NULL,
    "Experiment_Nr" text REFERENCES "Lab"."Experiments"("Experiment_Nr"),
    "sampling_date" date,
    "Lat" numeric,
    "Lon" numeric,
    "Depth" numeric,
    "DepthUnit" text,
    "place" text,
    "region" text REFERENCES "reference"."regionTab"("region"),
    "country" text,
    "project_id" text REFERENCES "Lims"."Projects"("project_id"),
    "TemperatureAtmospher" numeric,
    "TempAtmospherUnit" text,
    "Weather" text,
    "Wind" text,
    "WindUnit" text,
    "TemperatureSamplingDepth" numeric,
    "TempSamplingDepthUnit" text,
    "Salinity" numeric,
    "SalinityUnit" text,
    "Pressure" numeric,
    "PressureUnit" text,
    "Oxygen" numeric,
    "OxygenUnit" text,
    "Conducitivity" numeric,
    "ConductivityUnit" text,
    "GearTypeID" text,
    "SoakTime" numeric,
    "SoakTimeUnit" text,
    "TrawlSpeed" numeric,
    "TrawlSpeedUnit" text,
    "Together_With" text,
    "attachment" bytea,
    "modified_by" text,
    "time_modification" timestamptz
);

-- Table: Lab.Experiments
CREATE TABLE IF NOT EXISTS "Lab"."Experiments" (
    "nr" serial PRIMARY KEY,
    "Experiment_Nr" text UNIQUE NOT NULL,
    "Experiment_title" text,
    "project_id" text REFERENCES "Lims"."Projects"("project_id"),
    "aim" text,
    "Method" text,
    "sop_id" text REFERENCES "Lims"."SOP"("sop_id"),
    "Date" date,
    "Person" text,
    "notes" text,
    "LabBook" text,
    "status_id" text REFERENCES "reference"."Status"("status_id"),
    "attachment" bytea,
    "modified_by" text,
    "time_modification" timestamptz
);

-- This central table's definition is crucial for the functions to work.
CREATE TABLE IF NOT EXISTS "Lab"."Samples" (
    "nr" serial,
    "sample_id" text PRIMARY KEY,
    "Sampling_id" text REFERENCES "Lab"."Sampling"("Sampling_id"),
    "storage_id" text REFERENCES "Lab"."Storage"("storage_id"),
    "storage_position" numeric,
    "Sampler" text,
    "Reciever" text,
    "sampling_date" date,
    "Recieption_date" date,
    "sample_type" text NOT NULL REFERENCES "reference"."SamplesType"("sample_type"),
    "workflow_status_id" text REFERENCES "reference"."Status"("status_id") DEFAULT 'Received' NOT NULL,
    "project_id" text REFERENCES "Lims"."Projects"("project_id"),
    "External_Name" text,
    "region" text REFERENCES "reference"."regionTab"("region"),
    "Species" text REFERENCES "reference"."Species"("Species"),
    "maxlength" numeric,
    "Weight" numeric,
    "Sex" text,
    "MaturityStage" text,
    "Age" numeric,
    "StomachContents" text,
    "DiseaseInfo" text,
    "TagID" text,
    "Volume_uL" numeric,
    "Concentration" numeric,
    "Volume" numeric,
    "unity" text,
    "Depth" numeric,
    "Sampling_Method" text,
    "ConservationBuffer" text,
    "Tide" text,
    "VolumeL" numeric,
    "Filter" text,
    "FilterPoreSize" numeric,
    "Transport" text,
    "notes" text,
    "attachment" bytea,
    "last_status_update" timestamp DEFAULT CURRENT_TIMESTAMP,
    "source_table" text NOT NULL,
    "modified_by" text,
    "time_modification" timestamptz
);


-- Table: Lab.ExperimentSamples
CREATE TABLE IF NOT EXISTS "Lab"."ExperimentSamples" (
    "nr" serial,
    "Experiment_Nr" text NOT NULL REFERENCES "Lab"."Experiments"("Experiment_Nr"),
    "sample_id" text NOT NULL REFERENCES "Lab"."Samples"("sample_id"),
    "notes" text,
    PRIMARY KEY ("Experiment_Nr", "sample_id"),
    "modified_by" text,
    "time_modification" timestamptz
);

-- Table: "Lab"."Fish"
CREATE TABLE IF NOT EXISTS "Lab"."Fish" (
    "nr" serial,
    "sample_id" text PRIMARY KEY,
    "Sampling_id" text REFERENCES "Lab"."Sampling"("Sampling_id"),
    "Experiment_Nr" text REFERENCES "Lab"."Experiments"("Experiment_Nr"),
    "Species" text NOT NULL REFERENCES "reference"."Species"("Species"),
    "maxlength" numeric,
    "Weight" numeric,
    "Sex" text,
    "MaturityStage" text,
    "Age" numeric,
    "StomachContents" text,
    "DiseaseInfo" text,
    "TagID" text,
    "storage_id" text REFERENCES "Lab"."Storage"("storage_id"),
    "storage_position" numeric,
    "Sampler" text,
    "Reciever" text,
    "sampling_date" date,
    "Recieption_date" date,
    "sample_type" text NOT NULL REFERENCES "reference"."SamplesType"("sample_type"),
    "region" text REFERENCES "reference"."regionTab"("region"),
    "Transport" text,
    "External_Name" text,
    "ParentSample_id" text REFERENCES "Lab"."Samples"("sample_id"),
    "project_id" text REFERENCES "Lims"."Projects"("project_id"),
    "notes" text,
    "attachment" bytea,
    "Workflow_name" TEXT REFERENCES "reference"."Workflows"("Workflow_id"),
    "Step_name" TEXT REFERENCES "reference"."Workflow_steps"("Step_name"),
    "modified_by" text,
    "time_modification" timestamptz
);

-- Table: Lab.Tissue
CREATE TABLE IF NOT EXISTS "Lab"."Tissue" (
    "nr" serial,
    "sample_id" text PRIMARY KEY,
    "Sampling_id" text REFERENCES "Lab"."Sampling"("Sampling_id"),
    "Experiment_Nr" text REFERENCES "Lab"."Experiments"("Experiment_Nr"),
    "Weight" numeric,
    "storage_id" text REFERENCES "Lab"."Storage"("storage_id"),
    "storage_position" numeric,
    "Sampler" text,
    "Reciever" text,
    "sampling_date" date,
    "Recieption_date" date,
    "region" text REFERENCES "reference"."regionTab"("region"),
    "sample_type" text NOT NULL REFERENCES "reference"."SamplesType"("sample_type"),
    "External_Name" text,
    "ParentSample_id" text REFERENCES "Lab"."Samples"("sample_id"),
    "Fish_ParentalID" text REFERENCES "Lab"."Fish"("sample_id"),
    "project_id" text REFERENCES "Lims"."Projects"("project_id"),
    "notes" text,
    "Workflow_name" TEXT REFERENCES "reference"."Workflows"("Workflow_id"),
    "Step_name" TEXT REFERENCES "reference"."Workflow_steps"("Step_name"),
    "attachment" bytea,
    "modified_by" text,
    "time_modification" timestamptz
);

-- Table: Lab.DNA
CREATE TABLE IF NOT EXISTS "Lab"."DNA" (
    "nr" serial,
    "sample_id" text PRIMARY KEY,
    "Sampling_id" text REFERENCES "Lab"."Sampling"("Sampling_id"),
    "Experiment_Nr" text REFERENCES "Lab"."Experiments"("Experiment_Nr"),
    "Volume_uL" numeric,
    "Concentration" numeric,
    "sample_type" text NOT NULL REFERENCES "reference"."SamplesType"("sample_type"),
    "region" text REFERENCES "reference"."regionTab"("region"),
    "sampling_date" date,
    "Recieption_date" date,
    "storage_id" text REFERENCES "Lab"."Storage"("storage_id"),
    "storage_position" numeric,
    "Sampler" text,
    "Reciever" text,
    "ParentSample_id" text REFERENCES "Lab"."Samples"("sample_id"),
    "Fish_ParentalID" text REFERENCES "Lab"."Fish"("sample_id"),
    "Tissue_ParentalID" text REFERENCES "Lab"."Tissue"("sample_id"),
    "External_Name" text,
    "project_id" text REFERENCES "Lims"."Projects"("project_id"),
    "notes" text,
    "attachment" bytea,
    "Workflow_name" TEXT REFERENCES "reference"."Workflows"("Workflow_id"),
    "Step_name" TEXT REFERENCES "reference"."Workflow_steps"("Step_name"),
    "modified_by" text,
    "time_modification" timestamptz
);

-- Table: Lab.RNA
CREATE TABLE IF NOT EXISTS "Lab"."RNA" (
    "nr" serial,
    "sample_id" text PRIMARY KEY,
    "Sampling_id" text REFERENCES "Lab"."Sampling"("Sampling_id"),
    "Experiment_Nr" text REFERENCES "Lab"."Experiments"("Experiment_Nr"),
    "Volume_uL" numeric,
    "Concentration" numeric,
    "sample_type" text NOT NULL REFERENCES "reference"."SamplesType"("sample_type"),
    "region" text REFERENCES "reference"."regionTab"("region"),
    "sampling_date" date,
    "Recieption_date" date,
    "storage_id" text REFERENCES "Lab"."Storage"("storage_id"),
    "storage_position" numeric,
    "Sampler" text,
    "Reciever" text,
    "ParentSample_id" text REFERENCES "Lab"."Samples"("sample_id"),
    "Fish_ParentalID" text REFERENCES "Lab"."Fish"("sample_id"),
    "Tissue_ParentalID" text REFERENCES "Lab"."Tissue"("sample_id"),
    "External_Name" text,
    "project_id" text REFERENCES "Lims"."Projects"("project_id"),
    "notes" text,
    "attachment" bytea,
    "Workflow_name" TEXT REFERENCES "reference"."Workflows"("Workflow_id"),
    "Step_name" TEXT REFERENCES "reference"."Workflow_steps"("Step_name"),
    "modified_by" text,
    "time_modification" timestamptz
);

-- Table: Lab.Sediments
CREATE TABLE IF NOT EXISTS "Lab"."Sediments" (
    "nr" serial,
    "sample_id" text PRIMARY KEY,
    "Sampling_id" text REFERENCES "Lab"."Sampling"("Sampling_id"),
    "Experiment_Nr" text REFERENCES "Lab"."Experiments"("Experiment_Nr"),
    "Volume" numeric,
    "unity" text,
    "Depth" numeric,
    "Sampling_Method" text,
    "ConservationBuffer" text,
    "Tide" text,
    "region" text REFERENCES "reference"."regionTab"("region"),
    "sample_type" text NOT NULL REFERENCES "reference"."SamplesType"("sample_type"),
    "Sampler" text,
    "Reciever" text,
    "sampling_date" date,
    "Recieption_date" date,
    "storage_id" text REFERENCES "Lab"."Storage"("storage_id"),
    "storage_position" numeric,
    "ParentSample_id" text REFERENCES "Lab"."Samples"("sample_id"),
    "External_Name" text,
    "project_id" text REFERENCES "Lims"."Projects"("project_id"),
    "notes" text,
    "attachment" bytea,
    "Workflow_name" TEXT REFERENCES "reference"."Workflows"("Workflow_id"),
    "Step_name" TEXT REFERENCES "reference"."Workflow_steps"("Step_name"),
    "modified_by" text,
    "time_modification" timestamptz
);

-- Table: Lab.Water
CREATE TABLE IF NOT EXISTS "Lab"."Water" (
    "nr" serial,
    "sample_id" text PRIMARY KEY,
    "Sampling_id" text REFERENCES "Lab"."Sampling"("Sampling_id"),
    "Experiment_Nr" text REFERENCES "Lab"."Experiments"("Experiment_Nr"),
    "VolumeL" numeric,
    "Filter" text,
    "FilterPoreSize" numeric,
    "Depth" numeric,
    "Sampling_Method" text,
    "ConservationBuffer" text,
    "Sampler" text,
    "Reciever" text,
    "sampling_date" date,
    "Recieption_date" date,
    "sample_type" text NOT NULL REFERENCES "reference"."SamplesType"("sample_type"),
    "region" text REFERENCES "reference"."regionTab"("region"),
    "storage_id" text REFERENCES "Lab"."Storage"("storage_id"),
    "storage_position" numeric,
    "notes" text,
    "ParentSample_id" text REFERENCES "Lab"."Samples"("sample_id"),
    "External_Name" text,
    "project_id" text REFERENCES "Lims"."Projects"("project_id"),
    "attachment" bytea,
    "Workflow_name" TEXT REFERENCES "reference"."Workflows"("Workflow_id"),
    "Step_name" TEXT REFERENCES "reference"."Workflow_steps"("Step_name"),
    "modified_by" text,
    "time_modification" timestamptz
);

-- Table: Lab.Extraction
CREATE TABLE IF NOT EXISTS "Lab"."Extraction" (
    "nr" serial PRIMARY KEY,
    "Experiment_Nr" text REFERENCES "Lab"."Experiments"("Experiment_Nr"),
    "sample_id" text REFERENCES "Lab"."Samples"("sample_id"),
    "Date" date,
    "Person" text,
    "kit" text,
    "ElutionVolume" numeric,
    "Yield_Qubit_ng_ul" numeric,
    "Yield_Nanodrop_ng_ul" numeric,
    "A260_280" numeric,
    "A260_230" numeric,
    "ExtractionBlankID" text,
    "notes" text,
    "status_id" text REFERENCES "reference"."Status"("status_id"),
    "storage_id" text REFERENCES "Lab"."Storage"("storage_id"),
    "storage_position" numeric,
    "project_id" text REFERENCES "Lims"."Projects"("project_id"),
    "attachment" bytea,
    "modified_by" text,
    "time_modification" timestamptz
);

-- Table: Lab.Nanodrop
CREATE TABLE IF NOT EXISTS "Lab"."Nanodrop" (
    "nr" serial PRIMARY KEY,
    "Experiment_Nr" text REFERENCES "Lab"."Experiments"("Experiment_Nr"),
    "sample_id" text REFERENCES "Lab"."Samples"("sample_id"),
    "Nanodrop_Concentration" numeric,
    "NanodropUnits" text,
    "Factor" text,
    "A260" numeric,
    "A260_280" numeric,
    "A260_280_note" text,
    "A260_230" numeric,
    "A260_230_note" text,
    "date" date,
    "Elution_volume_ul" numeric,
    "Person" text,
    "notes" text,
    "status_id" text REFERENCES "reference"."Status"("status_id"),
    "attachment" bytea,
    "storage_id" text REFERENCES "Lab"."Storage"("storage_id"),
    "storage_position" numeric,
    "project_id" text REFERENCES "Lims"."Projects"("project_id"),
    "ResultDate" timestamp with time zone,
    "modified_by" text,
    "time_modification" timestamptz
    "NanodropTotalDna_ug" numeric GENERATED ALWAYS AS (("Elution_volume_ul" * "Nanodrop_Concentration") / 1000) STORED
);

-- Table: Lab.Qubit
CREATE TABLE IF NOT EXISTS "Lab"."Qubit" (
    "nr" serial PRIMARY KEY,
    "Experiment_Nr" text REFERENCES "Lab"."Experiments"("Experiment_Nr"),
    "Run_id" text,
    "Assay_Kit" text,
    "sample_id" text REFERENCES "Lab"."Samples"("sample_id"),
    "date" date,
    "Qubit_tube_conc" numeric,
    "tube_unity" text,
    "QubitOriginal_sample_conc" numeric,
    "QubitOriginal_units" text,
    "Sample_volume_ul" numeric,
    "Elution_volume_ul" numeric,
    "Person" text,
    "notes" text,
    "status_id" text REFERENCES "reference"."Status"("status_id"),
    "storage_id" text REFERENCES "Lab"."Storage"("storage_id"),
    "storage_position" numeric,
    "project_id" text REFERENCES "Lims"."Projects"("project_id"),
    "attachment" bytea,
    "ResultDate" timestamp with time zone,
    "modified_by" text,
    "time_modification" timestamptz
    "QubitTotalDna_ug" numeric GENERATED ALWAYS AS (("Elution_volume_ul" * "QubitOriginal_sample_conc") / 1000) STORED
);

-- Table: Lab.Tapestation
CREATE TABLE IF NOT EXISTS "Lab"."Tapestation" (
    "nr" serial PRIMARY KEY,
    "Experiment_Nr" text REFERENCES "Lab"."Experiments"("Experiment_Nr"),
    "date" date,
    "kit" text,
    "Person" text,
    "notes" text,
    "sample_id" text REFERENCES "Lab"."Samples"("sample_id"),
    "Position" text,
    "status_id" text REFERENCES "reference"."Status"("status_id"),
    "storage_id" text REFERENCES "Lab"."Storage"("storage_id"),
    "storage_position" numeric,
    "project_id" text REFERENCES "Lims"."Projects"("project_id"),
    "attachment" bytea,
    "ResultDate" timestamp with time zone,
    "modified_by" text,
    "time_modification" timestamptz
);

-- Table: Lab.PCR
CREATE TABLE IF NOT EXISTS "Lab"."PCR" (
    "nr" serial PRIMARY KEY,
    "Experiment_Nr" text REFERENCES "Lab"."Experiments"("Experiment_Nr"),
    "sample_id" text REFERENCES "Lab"."Samples"("sample_id"),
    "position" text,
    "gene_id" text REFERENCES "reference"."Genes"("primer_id"),
    "PCRBlankID" text,
    "Date" date,
    "Person" text,
    "notes" text,
    "kit" text,
    "storage_id" text REFERENCES "Lab"."Storage"("storage_id"),
    "storage_position" numeric,
    "status_id" text REFERENCES "reference"."Status"("status_id"),
    "project_id" text REFERENCES "Lims"."Projects"("project_id"),
    "attachment" bytea,
    "Volume" numeric,
    "modified_by" text,
    "time_modification" timestamptz
);

-- Table: Lab.Gelelectrophoresis
CREATE TABLE IF NOT EXISTS "Lab"."Gelelectrophoresis" (
    "nr" serial PRIMARY KEY,
    "Experiment_Nr" text REFERENCES "Lab"."Experiments"("Experiment_Nr"),
    "sample_id" text REFERENCES "Lab"."Samples"("sample_id"),
    "position" text,
    "Ladder" text,
    "Voltage" numeric,
    "BandSize_bp" integer,
    "GelType" text,
    "RunTimeMinutes" numeric,
    "date" date,
    "Person" text,
    "notes" text,
    "storage_id" text REFERENCES "Lab"."Storage"("storage_id"),
    "storage_position" numeric,
    "project_id" text REFERENCES "Lims"."Projects"("project_id"),
    "attachment" bytea,
    "ResultDate" timestamp with time zone,
    "modified_by" text,
    "time_modification" timestamptz
);

-- Table: Lab.qPCR
CREATE TABLE IF NOT EXISTS "Lab"."qPCR" (
    "nr" serial PRIMARY KEY,
    "Experiment_Nr" text REFERENCES "Lab"."Experiments"("Experiment_Nr"),
    "sample_id" text REFERENCES "Lab"."Samples"("sample_id"),
    "position" text,
    "Date" date,
    "Person" text,
    "gene_id" text REFERENCES "reference"."Genes"("primer_id"),
    "CtValue" numeric,
    "InhibitorTestResult" text,
    "PCRBlankID" text,
    "kit" text,
    "Volume" numeric,
    "storage_id" text REFERENCES "Lab"."Storage"("storage_id"),
    "storage_position" numeric,
    "status_id" text REFERENCES "reference"."Status"("status_id"),
    "project_id" text REFERENCES "Lims"."Projects"("project_id"),
    "attachment" bytea,
    "notes" text,
    "modified_by" text,
    "time_modification" timestamptz
);

-- Table: Lab.Library
CREATE TABLE IF NOT EXISTS "Lab"."Library" (
    "nr" serial PRIMARY KEY,
    "Experiment_Nr" text REFERENCES "Lab"."Experiments"("Experiment_Nr"),
    "Library_id" text UNIQUE NOT NULL,
    "sample_id" text REFERENCES "Lab"."Samples"("sample_id"),
    "Library" text,
    "Date" date,
    "Person" text,
    "LibraryPrepKit" text,
    "IndexSequence" text,
    "ReadLength" integer,
    "storage_id" text REFERENCES "Lab"."Storage"("storage_id"),
    "storage_position" numeric,
    "project_id" text REFERENCES "Lims"."Projects"("project_id"),
    "notes" text,
    "attachment" bytea,
    "ResultDate" timestamp with time zone,
    "modified_by" text,
    "time_modification" timestamptz
);

-- Table: Lab.Sequencing
CREATE TABLE IF NOT EXISTS "Lab"."Sequencing" (
    "nr" serial PRIMARY KEY,
    "Experiment_Nr" text REFERENCES "Lab"."Experiments"("Experiment_Nr"),
    "sequencing_id" text UNIQUE NOT NULL,
    "sample_id" text REFERENCES "Lab"."Samples"("sample_id"),
    "Library_id" text REFERENCES "Lab"."Library"("Library_id"),
    "Date" date,
    "Person" text,
    "Sequencer" text,
    "FlowCellID" text,
    "LibraryPrepKit" text,
    "IndexSequence" text,
    "ReadLength" integer,
    "TotalReads" bigint,
    "RawDataPath" text,
    "status_id" text REFERENCES "reference"."Status"("status_id"),
    "storage_id" text REFERENCES "Lab"."Storage"("storage_id"),
    "storage_position" numeric,
    "GenbankAccessionNumber" text,
    "project_id" text REFERENCES "Lims"."Projects"("project_id"),
    "attachment" bytea,
    "ResultDate" timestamp with time zone,
    "modified_by" text,
    "time_modification" timestamptz
);

-- Table: Lab.Bioinformatics
CREATE TABLE IF NOT EXISTS "Lab"."Bioinformatics" (
    "bioinfo_id" serial PRIMARY KEY,
    "sequencing_id" text REFERENCES "Lab"."Sequencing"("sequencing_id"),
    "Experiment_Nr" text REFERENCES "Lab"."Experiments"("Experiment_Nr"),
    "Date" date,
    "Person" text,
    "PipelineName" text,
    "PipelineVersion" text,
    "referenceDatabase" text,
    "DatabaseVersion" text,
    "ClusteringThreshold" numeric,
    "FinalOutputPath" text,
    "notes" text,
    "sample_id" text REFERENCES "Lab"."Samples"("sample_id"),
    "storage_id" text REFERENCES "Lab"."Storage"("storage_id"),
    "storage_position" numeric,
    "project_id" text REFERENCES "Lims"."Projects"("project_id"),
    "status_id" text REFERENCES "reference"."Status"("status_id"),
    "attachment" bytea,
    "ResultDate" timestamp with time zone,
    "modified_by" text,
    "time_modification" timestamptz
);


CREATE TABLE IF NOT EXISTS "Lab"."protocols" (
    "nr" serial PRIMARY KEY,
    "Experiments_Nr" TEXT REFERENCES "Lab"."Experiments"("Experiment_Nr"),
    "protocol" TEXT,
    "run" TEXT,
    "notes" TEXT,
    "modified_by" text,
    "time_modification" timestamptz
);




-- =================================================================
-- Initial Data Population
-- =================================================================
INSERT INTO "reference"."Status" ("status_id", "decscription") VALUES
('Received', 'Sample has been received in the lab'),
('Extracted', 'Sample has been extracted'),
('Nanodrop QC', 'Sample quality checked with Nanodrop'),
('Qubit QC', 'Sample quality checked with Qubit'),
('Tapestation QC', 'Sample quality checked with Tapestation'),
('PCR Done', 'PCR has been performed on the sample'),
('qPCR Done', 'qPCR has been performed on the sample'),
('Library Prep', 'Sequencing library has been prepared'),
('Sequencing Done', 'Sample has been sequenced'),
('Bioinformatics Done', 'Bioinformatics analysis is complete'),
('Unknown Step', 'An unknown step has occurred in the workflow')
ON CONFLICT ("status_id") DO NOTHING;


-- =================================================================
-- FUNCTIONS AND TRIGGERS
-- =================================================================

-- Sequence tables used by the ID generation function
CREATE TABLE IF NOT EXISTS "Lab"."sample_id_sequence" (
    "key" TEXT PRIMARY KEY,
    "last_value" BIGINT NOT NULL,
    "modified_by" text,
    "time_modification" timestamptz
);

CREATE TABLE IF NOT EXISTS "Lab"."aliquot_sequence" (
    "base_id" TEXT PRIMARY KEY,
    "last_value" INT NOT NULL,
    "modified_by" text,
    "time_modification" timestamptz
);


--
-- FUNCTION 1: Generate Sample ID using a robust JSONB approach
--
CREATE OR REplace FUNCTION "Lab".generate_sample_id_trigger_func()
RETURNS TRIGGER AS $$
DECLARE
    json_new JSONB;
    parent_id TEXT;
    aliquot_suffix TEXT;
    aliquot_base_id TEXT;
    aliquot_seq_num INT;
    type_prefix TEXT;
    year_part TEXT;
    regionTab_prefix TEXT;
    date_to_use DATE;
    root_seq_num BIGINT;
    root_id_key TEXT;
BEGIN
    -- Convert the entire NEW record to a JSONB object for safe field access.
    json_new := to_jsonb(NEW);

    -- Check for ParentSample_id safely.
    parent_id := json_new ->> 'ParentSample_id';

    IF parent_id IS NOT NULL AND parent_id <> '' THEN
        -- LOGIC FOR ALIQUOTS
        SELECT "sample_typeAbrv" INTO aliquot_suffix FROM "reference"."SamplesType" WHERE "sample_type" = (json_new ->> 'sample_type');
        IF aliquot_suffix IS NULL THEN
            RAISE EXCEPTION 'Cannot generate aliquot ID: sample_type "%" not found.', (json_new ->> 'sample_type');
        END IF;

        aliquot_base_id := parent_id || lower(aliquot_suffix);

        INSERT INTO "Lab".aliquot_sequence ("base_id", "last_value") VALUES (aliquot_base_id, 1)
        ON CONFLICT ("base_id") DO UPDATE SET "last_value" = "Lab".aliquot_sequence.last_value + 1
        RETURNING "last_value" INTO aliquot_seq_num;

        NEW.sample_id := aliquot_base_id || aliquot_seq_num;
        RETURN NEW;
    ELSE
        -- LOGIC FOR NEW ROOT SAMPLES
        date_to_use := COALESCE(
            (json_new ->> 'sampling_date')::date,
            (json_new ->> 'Recieption_date')::date,
            CURRENT_DATE
        );
        year_part := to_char(date_to_use, 'YY');

        -- Get sample type abbreviation from JSONB.
        SELECT "sample_typeAbrv" INTO type_prefix FROM "reference"."SamplesType" WHERE "sample_type" = (json_new ->> 'sample_type');
        IF type_prefix IS NULL THEN
            RAISE EXCEPTION 'Cannot generate sample ID: sample_type "%" not found.', (json_new ->> 'sample_type');
        END IF;

        -- Get regionTab abbreviation from JSONB.
        IF (json_new ->> 'region') IS NULL THEN
            RAISE EXCEPTION 'Cannot generate sample ID: "region" field cannot be empty.';
        END IF;
        SELECT "region_id" INTO regionTab_prefix FROM "reference"."regionTab" WHERE "region" = (json_new ->> 'region');
        IF regionTab_prefix IS NULL THEN
            RAISE EXCEPTION 'Cannot generate sample ID: region name "%" not found in "reference"."regionTab".', (json_new ->> 'region');
        END IF;

        -- Construct and assign the new ID.
        root_id_key := type_prefix || year_part || regionTab_prefix;
        INSERT INTO "Lab".sample_id_sequence ("key", "last_value") VALUES (root_id_key, 1)
        ON CONFLICT ("key") DO UPDATE SET "last_value" = "Lab".sample_id_sequence.last_value + 1
        RETURNING "last_value" INTO root_seq_num;
        NEW.sample_id := root_id_key || lpad(root_seq_num::TEXT, 4, '0');
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;


-- =============================================
-- Sequence Table for Sampling_id
-- =============================================
CREATE TABLE IF NOT EXISTS "Lab"."sampling_id_sequence" (
    "key" TEXT PRIMARY KEY,
    "last_value" BIGINT NOT NULL
);

---
-- FUNCTION to Generate Sampling ID
---
CREATE OR REPLACE FUNCTION "Lab".generate_sampling_id_trigger_func()
RETURNS TRIGGER AS $$
DECLARE
    json_new JSONB;
    year_part TEXT;
    location_prefix TEXT;
    date_to_use DATE;
    sampling_seq_num BIGINT;
    sampling_id_key TEXT;
BEGIN
    -- Convert the entire NEW record to a JSONB object for safe field access.
    json_new := to_jsonb(NEW);

    -- Determine the date to use for the year part
    date_to_use := COALESCE(
        (json_new ->> 'sampling_date')::date,
        CURRENT_DATE
    );
    year_part := to_char(date_to_use, 'YY');

    -- Get location abbreviation from JSONB.
    IF (json_new ->> 'region') IS NULL THEN
        RAISE EXCEPTION 'Cannot generate Sampling ID: "region" field cannot be empty.';
    END IF;

    SELECT "region_id" INTO location_prefix
    FROM "reference"."regionTab"
    WHERE "region" = (json_new ->> 'region');

    IF location_prefix IS NULL THEN
        RAISE EXCEPTION 'Cannot generate Sampling ID: region name "%" not found in "reference"."regionTab".', (json_new ->> 'region');
    END IF;

    -- Construct the key for the sequence table: S + Year + LocationID
    sampling_id_key := year_part || location_prefix;

    -- Increment the sequence number for this specific key
    INSERT INTO "Lab"."sampling_id_sequence" ("key", "last_value") VALUES (sampling_id_key, 1)
    ON CONFLICT ("key") DO UPDATE SET "last_value" = "Lab"."sampling_id_sequence".last_value + 1
    RETURNING "last_value" INTO sampling_seq_num;

    -- Assign the new formatted Sampling_id
    NEW."sampling_id" := sampling_id_key || lpad(sampling_seq_num::TEXT, 4, '0');

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

---
-- TRIGGER for Lab.Sampling table
---
DROP TRIGGER IF EXISTS trg_generate_sampling_id ON "Lab"."Sampling";

CREATE TRIGGER trg_generate_sampling_id
BEFORE INSERT ON "Lab"."Sampling"
FOR EACH ROW
EXECUTE FUNCTION "Lab".generate_sampling_id_trigger_func();
--
-- FUNCTION 2: Copy data to the central Lab.Samples table
--
CREATE OR REplace FUNCTION "Lab".copy_to_samples()
RETURNS TRIGGER AS $$
DECLARE
    json_new JSONB;
BEGIN
    json_new := to_jsonb(NEW);

    INSERT INTO "Lab"."Samples" (
        "sample_id", "project_id", "Sampling_id", "Species", "maxlength", "Weight", "Sex", "MaturityStage", "Age",
        "StomachContents", "DiseaseInfo", "TagID", "Volume_uL", "Concentration", "Volume", "unity",
        "Depth", "Sampling_Method", "ConservationBuffer", "Tide", "VolumeL", "Filter", "FilterPoreSize",
        "Transport", "storage_id", "storage_position", "Sampler", "Reciever", "sampling_date",
        "Recieption_date", "sample_type", "region", "External_Name", "notes", "attachment",
        "workflow_status_id", "last_status_update", "source_table"
    ) VALUES (
        json_new ->> 'sample_id',
        json_new ->> 'project_id',
        json_new ->> 'Sampling_id',
        json_new ->> 'Species',
        (json_new ->> 'maxlength')::numeric,
        (json_new ->> 'Weight')::numeric,
        json_new ->> 'Sex',
        json_new ->> 'MaturityStage',
        (json_new ->> 'Age')::numeric,
        json_new ->> 'StomachContents',
        json_new ->> 'DiseaseInfo',
        json_new ->> 'TagID',
        (json_new ->> 'Volume_uL')::numeric,
        (json_new ->> 'Concentration')::numeric,
        (json_new ->> 'Volume')::numeric,
        json_new ->> 'unity',
        (json_new ->> 'Depth')::numeric,
        json_new ->> 'Sampling_Method',
        json_new ->> 'ConservationBuffer',
        json_new ->> 'Tide',
        (json_new ->> 'VolumeL')::numeric,
        json_new ->> 'Filter',
        (json_new ->> 'FilterPoreSize')::numeric,
        json_new ->> 'Transport',
        json_new ->> 'storage_id',
        (json_new ->> 'storage_position')::numeric,
        json_new ->> 'Sampler',
        json_new ->> 'Reciever',
        (json_new ->> 'sampling_date')::date,
        (json_new ->> 'Recieption_date')::date,
        json_new ->> 'sample_type',
        json_new ->> 'region',
        json_new ->> 'External_Name',
        json_new ->> 'notes',
        CASE WHEN json_new ->> 'attachment' IS NOT NULL THEN decode(json_new ->> 'attachment', 'hex') ELSE NULL END,
        'Received',
        CURRENT_TIMESTAMP,
        lower(TG_TABLE_NAME)
    )
    ON CONFLICT (sample_id) DO UPDATE SET
        "project_id" = COALESCE(EXCLUDED."project_id", "Lab"."Samples"."project_id"),
        "region" = COALESCE(EXCLUDED."region", "Lab"."Samples"."region"),
        "Species" = COALESCE(EXCLUDED."Species", "Lab"."Samples"."Species"),
        "notes" = COALESCE(EXCLUDED."notes", "Lab"."Samples"."notes"),
        "last_status_update" = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


--
--  FUNCTION 3: Consolidated function to update workflow status
--
CREATE OR REplace FUNCTION "Lab".update_workflow_status()
RETURNS TRIGGER AS $$
DECLARE
    new_status TEXT;
BEGIN
    new_status := CASE TG_TABLE_NAME
        WHEN 'Extraction' THEN 'Extracted'
        WHEN 'Nanodrop' THEN 'Nanodrop QC'
        WHEN 'Qubit' THEN 'Qubit QC'
        WHEN 'Tapestation' THEN 'Tapestation QC'
        WHEN 'PCR' THEN 'PCR Done'
        WHEN 'qPCR' THEN 'qPCR Done'
        WHEN 'Library' THEN 'Library Prep'
        WHEN 'Sequencing' THEN 'Sequencing Done'
        WHEN 'Bioinformatics' THEN 'Bioinformatics Done'
        ELSE 'Unknown Step'
    END;

    UPDATE "Lab"."Samples"
    SET "workflow_status_id" = new_status, "last_status_update" = CURRENT_TIMESTAMP
    WHERE "sample_id" = NEW.sample_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


--
-- FUNCTION 4: Update the central Lab.Samples table after a source table is updated
--
CREATE OR REplace FUNCTION "Lab".update_central_samples()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE "Lab"."Samples"
    SET
        "project_id" = NEW."project_id",
        "region" = NEW."region",
        "storage_id" = NEW."storage_id",
        "storage_position" = NEW."storage_position",
        "notes" = NEW."notes",
        "attachment" = NEW."attachment",
        "last_status_update" = CURRENT_TIMESTAMP
    WHERE "sample_id" = NEW."sample_id";

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- =============================================
-- TRIGGER DEFINITIONS
-- =============================================

-- Drop existing triggers to ensure a clean slate on re-run
DROP TRIGGER IF EXISTS trg_generate_fish_sample_id ON "Lab"."Fish";
DROP TRIGGER IF EXISTS trg_generate_tissue_sample_id ON "Lab"."Tissue";
DROP TRIGGER IF EXISTS trg_generate_dna_sample_id ON "Lab"."DNA";
DROP TRIGGER IF EXISTS trg_generate_rna_sample_id ON "Lab"."RNA";
DROP TRIGGER IF EXISTS trg_generate_sediments_sample_id ON "Lab"."Sediments";
DROP TRIGGER IF EXISTS trg_generate_water_sample_id ON "Lab"."Water";

DROP TRIGGER IF EXISTS copy_fish_to_samples ON "Lab"."Fish";
DROP TRIGGER IF EXISTS copy_tissue_to_samples ON "Lab"."Tissue";
DROP TRIGGER IF EXISTS copy_dna_to_samples ON "Lab"."DNA";
DROP TRIGGER IF EXISTS copy_rna_to_samples ON "Lab"."RNA";
DROP TRIGGER IF EXISTS copy_sediments_to_samples ON "Lab"."Sediments";
DROP TRIGGER IF EXISTS copy_water_to_samples ON "Lab"."Water";

DROP TRIGGER IF EXISTS trg_update_extraction_status ON "Lab"."Extraction";
DROP TRIGGER IF EXISTS trg_update_nanodrop_status ON "Lab"."Nanodrop";
DROP TRIGGER IF EXISTS trg_update_qubit_status ON "Lab"."Qubit";
DROP TRIGGER IF EXISTS trg_update_tapestation_status ON "Lab"."Tapestation";
DROP TRIGGER IF EXISTS trg_update_pcr_status ON "Lab"."PCR";
DROP TRIGGER IF EXISTS trg_update_qpcr_status ON "Lab"."qPCR";
DROP TRIGGER IF EXISTS trg_update_library_status ON "Lab"."Library";
DROP TRIGGER IF EXISTS trg_update_sequencing_status ON "Lab"."Sequencing";
DROP TRIGGER IF EXISTS trg_update_bioinformatics_status ON "Lab"."Bioinformatics";

DROP TRIGGER IF EXISTS trg_update_samples_from_fish ON "Lab"."Fish";
DROP TRIGGER IF EXISTS trg_update_samples_from_tissue ON "Lab"."Tissue";
DROP TRIGGER IF EXISTS trg_update_samples_from_dna ON "Lab"."DNA";
DROP TRIGGER IF EXISTS trg_update_samples_from_rna ON "Lab"."RNA";
DROP TRIGGER IF EXISTS trg_update_samples_from_water ON "Lab"."Water";
DROP TRIGGER IF EXISTS trg_update_samples_from_sediments ON "Lab"."Sediments";


-- Triggers to generate sample_id BEFORE INSERT
CREATE TRIGGER trg_generate_fish_sample_id BEFORE INSERT ON "Lab"."Fish" FOR EACH ROW EXECUTE FUNCTION "Lab".generate_sample_id_trigger_func();
CREATE TRIGGER trg_generate_tissue_sample_id BEFORE INSERT ON "Lab"."Tissue" FOR EACH ROW EXECUTE FUNCTION "Lab".generate_sample_id_trigger_func();
CREATE TRIGGER trg_generate_dna_sample_id BEFORE INSERT ON "Lab"."DNA" FOR EACH ROW EXECUTE FUNCTION "Lab".generate_sample_id_trigger_func();
CREATE TRIGGER trg_generate_rna_sample_id BEFORE INSERT ON "Lab"."RNA" FOR EACH ROW EXECUTE FUNCTION "Lab".generate_sample_id_trigger_func();
CREATE TRIGGER trg_generate_sediments_sample_id BEFORE INSERT ON "Lab"."Sediments" FOR EACH ROW EXECUTE FUNCTION "Lab".generate_sample_id_trigger_func();
CREATE TRIGGER trg_generate_water_sample_id BEFORE INSERT ON "Lab"."Water" FOR EACH ROW EXECUTE FUNCTION "Lab".generate_sample_id_trigger_func();


-- Triggers to copy data to the master "Lab"."Samples" table AFTER INSERT
CREATE TRIGGER copy_fish_to_samples AFTER INSERT ON "Lab"."Fish" FOR EACH ROW EXECUTE FUNCTION "Lab".copy_to_samples();
CREATE TRIGGER copy_tissue_to_samples AFTER INSERT ON "Lab"."Tissue" FOR EACH ROW EXECUTE FUNCTION "Lab".copy_to_samples();
CREATE TRIGGER copy_dna_to_samples AFTER INSERT ON "Lab"."DNA" FOR EACH ROW EXECUTE FUNCTION "Lab".copy_to_samples();
CREATE TRIGGER copy_rna_to_samples AFTER INSERT ON "Lab"."RNA" FOR EACH ROW EXECUTE FUNCTION "Lab".copy_to_samples();
CREATE TRIGGER copy_sediments_to_samples AFTER INSERT ON "Lab"."Sediments" FOR EACH ROW EXECUTE FUNCTION "Lab".copy_to_samples();
CREATE TRIGGER copy_water_to_samples AFTER INSERT ON "Lab"."Water" FOR EACH ROW EXECUTE FUNCTION "Lab".copy_to_samples();


-- Triggers to update workflow status in Lab.Samples using the single generic function
CREATE TRIGGER trg_update_extraction_status AFTER INSERT ON "Lab"."Extraction" FOR EACH ROW EXECUTE FUNCTION "Lab".update_workflow_status();
CREATE TRIGGER trg_update_nanodrop_status AFTER INSERT ON "Lab"."Nanodrop" FOR EACH ROW EXECUTE FUNCTION "Lab".update_workflow_status();
CREATE TRIGGER trg_update_qubit_status AFTER INSERT ON "Lab"."Qubit" FOR EACH ROW EXECUTE FUNCTION "Lab".update_workflow_status();
CREATE TRIGGER trg_update_tapestation_status AFTER INSERT ON "Lab"."Tapestation" FOR EACH ROW EXECUTE FUNCTION "Lab".update_workflow_status();
CREATE TRIGGER trg_update_pcr_status AFTER INSERT ON "Lab"."PCR" FOR EACH ROW EXECUTE FUNCTION "Lab".update_workflow_status();
CREATE TRIGGER trg_update_qpcr_status AFTER INSERT ON "Lab"."qPCR" FOR EACH ROW EXECUTE FUNCTION "Lab".update_workflow_status();
CREATE TRIGGER trg_update_library_status AFTER INSERT ON "Lab"."Library" FOR EACH ROW EXECUTE FUNCTION "Lab".update_workflow_status();
CREATE TRIGGER trg_update_sequencing_status AFTER INSERT ON "Lab"."Sequencing" FOR EACH ROW EXECUTE FUNCTION "Lab".update_workflow_status();
CREATE TRIGGER trg_update_bioinformatics_status AFTER INSERT ON "Lab"."Bioinformatics" FOR EACH ROW EXECUTE FUNCTION "Lab".update_workflow_status();


-- Triggers to update Lab.Samples AFTER UPDATE on a source table
CREATE TRIGGER trg_update_samples_from_fish AFTER UPDATE ON "Lab"."Fish" FOR EACH ROW EXECUTE FUNCTION "Lab".update_central_samples();
CREATE TRIGGER trg_update_samples_from_tissue AFTER UPDATE ON "Lab"."Tissue" FOR EACH ROW EXECUTE FUNCTION "Lab".update_central_samples();
CREATE TRIGGER trg_update_samples_from_dna AFTER UPDATE ON "Lab"."DNA" FOR EACH ROW EXECUTE FUNCTION "Lab".update_central_samples();
CREATE TRIGGER trg_update_samples_from_rna AFTER UPDATE ON "Lab"."RNA" FOR EACH ROW EXECUTE FUNCTION "Lab".update_central_samples();
CREATE TRIGGER trg_update_samples_from_water AFTER UPDATE ON "Lab"."Water" FOR EACH ROW EXECUTE FUNCTION "Lab".update_central_samples();
CREATE TRIGGER trg_update_samples_from_sediments AFTER UPDATE ON "Lab"."Sediments" FOR EACH ROW EXECUTE FUNCTION "Lab".update_central_samples();


-- =============================================
-- Views
-- =============================================

-- HINWEIS: Um Fehler bei der Neudefinition von Spalten zu vermeiden,
-- wird jede Ansicht zuerst gelöscht, falls sie existiert.
DROP VIEW IF EXISTS "Lab"."Samples_tracking" CASCADE;
DROP VIEW IF EXISTS "Lims"."Project_Summary" CASCADE;
DROP VIEW IF EXISTS "Lab"."Storage_Inventory_Summary" CASCADE;
DROP VIEW IF EXISTS "Lims"."Reagent_Stock_Status" CASCADE;
DROP VIEW IF EXISTS "Lab"."Experiment_Progress_Overview" CASCADE;
DROP VIEW IF EXISTS "reference"."Complete_Species_Names" CASCADE;


-- View 2: Lims.Project_Summary
-- Provides a high-level overview of all projects.
CREATE OR REplace VIEW "Lims"."Project_Summary" AS
SELECT
    p.project_id,
    p."Title" AS project_title,
    ref_status."decscription" AS project_status,
    p."Funder",
    p."Start_date",
    p."End_date",
    COUNT(DISTINCT e."Experiment_Nr") AS number_of_experiments,
    COUNT(DISTINCT d.nr) AS number_of_deliverables,
    SUM(b.allocated_amount) AS total_allocated_budget,
    SUM(b.spent_amount) AS total_spent_budget
FROM "Lims"."Projects" p
LEFT JOIN "reference"."Status" ref_status ON p.status_id = ref_status.status_id
LEFT JOIN "Lab"."Experiments" e ON p.project_id = e.project_id
LEFT JOIN "Project_Wanderfische"."Deliverables" d ON p.project_id = d.project_id
LEFT JOIN "Project_Wanderfische"."Budget" b ON p.project_id = b.project_id
GROUP BY
    p.project_id, p."Title", ref_status."decscription", p."Funder",
    p."Start_date", p."End_date";


-- View 3: Lab.Storage_Inventory_Summary
-- Provides a summary of storage regionTabs and sample counts.
CREATE OR REplace VIEW "Lab"."Storage_Inventory_Summary" AS
SELECT
    ls.storage_id,
    ls.room_id,
    rr.decscription AS room_decscription,
    ls."Freezer",
    ls."Temperature",
    ls."TemperatureUnit",
    ls."Box",
    ls."BoxX_ABC",
    ls."BoxY_123",
    COUNT(s.sample_id) AS total_samples_stored
FROM "Lab"."Storage" ls
LEFT JOIN "reference"."room" rr ON ls.room_id = rr.room_id
LEFT JOIN "Lab"."Samples" s ON ls.storage_id = s.storage_id
GROUP BY
    ls.storage_id, ls.room_id, rr.decscription, ls."Freezer", ls."Temperature",
    ls."TemperatureUnit", ls."Box", ls."BoxX_ABC", ls."BoxY_123"
ORDER BY ls.storage_id;


-- View 4: Lims.Reagent_Stock_Status
-- Monitors the current stock and expiry dates of reagents.
CREATE OR REplace VIEW "Lims"."Reagent_Stock_Status" AS
SELECT
    lr."Reagent_Name",
    lr."Reagent_CompleteName",
    lr.category,
    ref_cat.decscription AS category_decscription,
    lr."Lot",
    lr.storage_id,
    ref_status."decscription" AS current_status,
    lr."Recieption_date",
    lr."Expire_date",
    (lr."Expire_date" - CURRENT_DATE) AS days_until_expiry
FROM "Lims"."Reagents" lr
LEFT JOIN "reference"."Category" ref_cat ON lr.category = ref_cat.category
LEFT JOIN "reference"."Status" ref_status ON lr.status_id = ref_status.status_id
ORDER BY lr."Expire_date" ASC;

-- View 5: Lab.Experiment_Progress_Overview
-- Tracks the progress of experiments through various lab stages.
CREATE OR REplace VIEW "Lab"."Experiment_Progress_Overview" AS
SELECT
    e."Experiment_Nr",
    e."Experiment_title",
    e.project_id,
    proj."Title" AS project_title,
    ref_status."decscription" AS experiment_status,
    e."Date" AS experiment_start_date,
    e."Person" AS experiment_lead,
    COUNT(DISTINCT es.sample_id) AS total_samples_in_experiment,
    COUNT(DISTINCT ext.sample_id) AS samples_extracted_count,
    COUNT(DISTINCT nano.sample_id) AS samples_nanodrop_qc_count,
    COUNT(DISTINCT qu.sample_id) AS samples_qubit_qc_count,
    COUNT(DISTINCT tape.sample_id) AS samples_tapestation_qc_count,
    COUNT(DISTINCT pcr.sample_id) AS samples_pcr_done_count,
    COUNT(DISTINCT qpcr.sample_id) AS samples_qpcr_done_count,
    COUNT(DISTINCT lib.sample_id) AS samples_library_prep_count,
    COUNT(DISTINCT seq.sample_id) AS samples_sequenced_count,
    COUNT(DISTINCT bio.sample_id) AS samples_bioinformatics_done_count
FROM "Lab"."Experiments" e
LEFT JOIN "Lims"."Projects" proj ON e.project_id = proj.project_id
LEFT JOIN "reference"."Status" ref_status ON e.status_id = ref_status.status_id
LEFT JOIN "Lab"."ExperimentSamples" es ON e."Experiment_Nr" = es."Experiment_Nr"
LEFT JOIN "Lab"."Extraction" ext ON e."Experiment_Nr" = ext."Experiment_Nr" AND es.sample_id = ext.sample_id
LEFT JOIN "Lab"."Nanodrop" nano ON e."Experiment_Nr" = nano."Experiment_Nr" AND es.sample_id = nano.sample_id
LEFT JOIN "Lab"."Qubit" qu ON e."Experiment_Nr" = qu."Experiment_Nr" AND es.sample_id = qu.sample_id
LEFT JOIN "Lab"."Tapestation" tape ON e."Experiment_Nr" = tape."Experiment_Nr" AND es.sample_id = tape.sample_id
LEFT JOIN "Lab"."PCR" pcr ON e."Experiment_Nr" = pcr."Experiment_Nr" AND es.sample_id = pcr.sample_id
LEFT JOIN "Lab"."qPCR" qpcr ON e."Experiment_Nr" = qpcr."Experiment_Nr" AND es.sample_id = qpcr.sample_id
LEFT JOIN "Lab"."Library" lib ON e."Experiment_Nr" = lib."Experiment_Nr" AND es.sample_id = lib.sample_id
LEFT JOIN "Lab"."Sequencing" seq ON e."Experiment_Nr" = seq."Experiment_Nr" AND es.sample_id = seq.sample_id
LEFT JOIN "Lab"."Bioinformatics" bio ON e."Experiment_Nr" = bio."Experiment_Nr" AND es.sample_id = bio.sample_id
GROUP BY
    e."Experiment_Nr", e."Experiment_title", e.project_id, proj."Title",
    ref_status."decscription", e."Date", e."Person"
ORDER BY e."Date" DESC;


-- View 6: reference.Complete_Species_Names
-- Provides a convenient lookup for species scientific and common names.
CREATE OR REplace VIEW "reference"."Complete_Species_Names" AS
SELECT
    nr,
    "Species",
    "Genus",
    "Order",
    "Family",
    "DE_name",
    "En_name",
    "Genus" || ' ' || "Species" AS full_scientific_name,
    "En_name" || ' (' || "Genus" || ' ' || "Species" || ')' AS combined_english_name
FROM "reference"."Species";






-- ===================================================================================
-- ==============================================================================

DROP VIEW IF EXISTS "Lab"."Samples_tracking" CASCADE;

CREATE OR REplace VIEW "Lab"."Samples_tracking" AS
SELECT
    -- Core Sample Info from Lab.Samples
    s.sample_id,
    s.project_id,
    p."Title" AS project_title,
    s.source_table,
    s.sample_type,
    st.decscription AS sample_type_decscription,
    s."External_Name",
    s.storage_id,
    stor.room_id AS storage_room_id,
    rr.room_id AS room_id,
    rr.etage AS room_etage,
    rr.address AS room_address,
    stor."Freezer",
    stor."Temperature" AS storage_temperature,
    stor."TemperatureUnit" AS storage_temperature_unit,
    stor."Box" AS storage_box,
    stor."BoxX_ABC" AS storage_box_x,
    stor."BoxY_123" AS storage_box_y,
    s.storage_position,
    s."Sampler",
    s."Reciever",
    s.sampling_date AS sample_creation_date,
    s."Recieption_date",
    s."notes" AS sample_notes,
    s.workflow_status_id AS current_workflow_status,
    stat."decscription" AS workflow_status_decscription,
    s.last_status_update,

    -- Specific sample attributes from Lab.Samples and joined tables
    s."Species" AS species_scientific_name,
    ref_sp."Genus" AS species_genus,
    ref_sp."Order" AS species_order,
    ref_sp."Family" AS species_family,
    ref_sp."DE_name" AS species_de_name,
    ref_sp."En_name" AS species_en_name,
    ref_sp."maxlength" AS species_avg_maxlength,
    ref_sp.max_age AS species_max_age,
    s."maxlength" AS sample_maxlength,
    s."Weight" AS sample_weight,
    s."Sex" AS sample_sex,
    s."MaturityStage" AS sample_maturity_stage,
    s."Age" AS sample_age,
    s."StomachContents",
    s."DiseaseInfo",
    s."TagID",
    s."Volume_uL",
    s."Concentration",
    s."Volume",
    s.unity,
    s."Depth" AS sample_specific_depth,
    s."Sampling_Method" AS sample_method,
    s."ConservationBuffer" AS sample_conservation_buffer,
    s."Tide",
    s."VolumeL",
    s."Filter",
    s."FilterPoreSize",
    s."Transport",

    -- Ecological context from Lab.Sampling
    samp."Sampling_id" AS sampling_event_id,
    samp.sampling_date AS sampling_event_date,
    samp."Lat" AS sampling_lat,
    samp."Lon" AS sampling_lon,
    samp."Depth" AS sampling_depth,
    samp."DepthUnit" AS sampling_depth_unit,
    samp."place" AS sampling_place,
    loc."region" AS regionTab_name,
    loc."region_id" AS regionTab_region_id,
    loc.country AS regionTab_country,
    loc.category AS regionTab_category,
    loc."notes" AS regionTab_notes,
    samp."TemperatureAtmospher" AS sampling_temp_atmospher,
    samp."TempAtmospherUnit" AS sampling_temp_atmospher_unit,
    samp."Weather" AS sampling_weather,
    samp."Wind" AS sampling_wind,
    samp."WindUnit" AS sampling_wind_unit,
    samp."TemperatureSamplingDepth" AS sampling_temp_sampling_depth,
    samp."TempSamplingDepthUnit" AS sampling_temp_sampling_depth_unit,
    samp."Salinity" AS sampling_salinity,
    samp."SalinityUnit" AS sampling_salinity_unit,
    samp."Pressure" AS sampling_pressure,
    samp."PressureUnit" AS sampling_pressure_unit,
    samp."Oxygen" AS sampling_oxygen,
    samp."OxygenUnit" AS sampling_oxygen_unit,
    samp."Conducitivity" AS sampling_conductivity,
    samp."ConductivityUnit" AS sampling_conductivity_unit,
    samp."GearTypeID" AS sampling_gear_type_id,
    samp."SoakTime" AS sampling_soak_time,
    samp."SoakTimeUnit" AS sampling_soak_time_unit,
    samp."TrawlSpeed" AS sampling_trawl_speed,
    samp."TrawlSpeedUnit" AS sampling_trawl_speed_unit,
    samp."Together_With" AS sampling_together_with,
    samp."attachment" AS sampling_attachment,

    -- Experiment Info
    exp."Experiment_Nr" AS exp_nr,
    exp."Experiment_title" AS exp_title,
    exp.aim AS exp_aim,
    exp."Method" AS exp_method,
    exp.sop_id AS exp_sop_id,
    sop."Title" AS sop_title,
    sop.version AS sop_version,
    sop.author AS sop_author_id,
    ref_person_sop.person AS sop_author_name,
    sop.date_realise AS sop_release_date,
    sop.sop_protocol AS sop_protocol_content,
    exp."Date" AS exp_date,
    exp."Person" AS exp_person,
    exp."notes" AS exp_notes,
    exp."LabBook" AS exp_labbook,
    exp.status_id AS exp_status_id,
    exp_status."decscription" AS exp_status_decscription,
    exp."attachment" AS exp_attachment, -- Corrected column name to "attachment"

    -- Extraction Results
    ext."Date" AS ext_date,
    ext."Person" AS ext_person,
    ext.kit AS ext_kit,
    ext."ElutionVolume" AS ext_elution_volume,
    ext."Yield_Qubit_ng_ul" AS ext_yield_qubit,
    ext."Yield_Nanodrop_ng_ul" AS ext_yield_nanodrop,
    ext."A260_280" AS ext_a260_280,
    ext."A260_230" AS ext_a260_230,
    ext."ExtractionBlankID" AS ext_blank_id,
    ext."notes" AS ext_notes,
    ext.status_id AS ext_status_id,
    ext_status."decscription" AS ext_status_decscription,

    -- Nanodrop Results
    nd."Nanodrop_Concentration",
    nd."NanodropUnits",
    nd."Factor",
    nd."A260" AS nd_a260,
    nd."A260_280" AS nd_a260_280,
    nd."A260_280_note",
    nd."A260_230" AS nd_a260_230,
    nd."A260_230_note",
    nd."date" AS nd_date,
    nd."Elution_volume_ul" AS nd_elution_volume_ul,
    nd."Person" AS nd_person,
    nd."notes" AS nd_notes,
    nd."status_id" AS nd_status_id,
    nd_status."decscription" AS nd_status_decscription,
    nd."ResultDate" AS nd_result_date,
    nd."NanodropTotalDna_ug",

    -- Qubit Results
    qu."Run_id" AS qu_run_id,
    qu."Assay_Kit" AS qu_assay_kit,
    qu."date" AS qu_date,
    qu."Qubit_tube_conc",
    qu.tube_unity,
    qu."QubitOriginal_sample_conc",
    qu."QubitOriginal_units",
    qu."Sample_volume_ul" AS qu_sample_volume_ul,
    qu."Elution_volume_ul" AS qu_elution_volume_ul,
    qu."Person" AS qu_person,
    qu."notes" AS qu_notes,
    qu."status_id" AS qu_status_id,
    qu_status."decscription" AS qu_status_decscription,
    qu."ResultDate" AS qu_result_date,
    qu."QubitTotalDna_ug",

    -- Tapestation Results
    tape."date" AS tape_date,
    tape.kit AS tape_kit,
    tape."Person" AS tape_person,
    tape."notes" AS tape_notes,
    tape."Position" AS tape_position,
    tape.status_id AS tape_status_id,
    tape_status."decscription" AS tape_status_decscription,
    tape."ResultDate" AS tape_result_date,

    -- PCR Results
    pcr.position AS pcr_position,
    pcr.gene_id AS pcr_gene_id,
    ref_genes."TargetGene" AS pcr_target_gene,
    ref_genes."Primer_Sequence_Fwd" AS pcr_primer_fwd,
    ref_genes."Primer_Sequence_Rev" AS pcr_primer_rev,
    ref_genes.probe AS pcr_probe,
    pcr."PCRBlankID",
    pcr."Date" AS pcr_date,
    pcr."Person" AS pcr_person,
    pcr."notes" AS pcr_notes,
    pcr.kit AS pcr_kit,
    pcr."Volume" AS pcr_volume,
    pcr.status_id AS pcr_status_id,
    pcr_status."decscription" AS pcr_status_decscription,

    -- qPCR Results
    qpcr.position AS qpcr_position,
    qpcr."Date" AS qpcr_date,
    qpcr."Person" AS qpcr_person,
    qpcr.gene_id AS qpcr_gene_id,
    ref_genes_qpcr."TargetGene" AS qpcr_target_gene,
    qpcr."CtValue",
    qpcr."InhibitorTestResult",
    qpcr."PCRBlankID" AS qpcr_blank_id,
    qpcr.kit AS qpcr_kit,
    qpcr."Volume" AS qpcr_volume,
    qpcr.status_id AS qpcr_status_id,
    qpcr_status."decscription" AS qpcr_status_decscription,
    qpcr."notes" AS qpcr_notes,

    -- Library Prep Results
    lib."Library_id",
    lib."Date" AS library_date,
    lib."Person" AS library_person,
    lib."LibraryPrepKit",
    lib."IndexSequence",
    lib."Readlength" AS library_read_length,
    lib."notes" AS library_notes,
    lib."ResultDate" AS library_result_date,

    -- Sequencing Results
    seq.sequencing_id,
    seq."Date" AS seq_date,
    seq."Person" AS seq_person,
    seq."Sequencer",
    seq."FlowCellID",
    seq."LibraryPrepKit" AS seq_library_prep_kit,
    seq."IndexSequence" AS seq_index_sequence,
    seq."Readlength" AS seq_read_length,
    seq."TotalReads",
    seq."RawDataPath",
    seq."status_id" AS seq_status_id,
    seq_status."decscription" AS seq_status_decscription,
    seq."GenbankAccessionNumber",
    seq."ResultDate" AS seq_result_date,

    -- Bioinformatics Results
    bio.bioinfo_id,
    bio."Date" AS bio_date,
    bio."Person" AS bio_person,
    bio."PipelineName" AS bio_pipeline_name,
    bio."PipelineVersion",
    bio."referenceDatabase",
    bio."DatabaseVersion",
    bio."ClusteringThreshold",
    bio."FinalOutputPath",
    bio."notes" AS bio_notes,
    bio."status_id" AS bio_status_id,
    bio_status."decscription" AS bio_status_decscription, -- Corrected: Quoted "decscription"
    bio."ResultDate" AS bio_result_date

FROM "Lab"."Samples" s
LEFT JOIN "reference"."Status" stat ON s.workflow_status_id = stat.status_id
LEFT JOIN "reference"."SamplesType" st ON s.sample_type = st.sample_type
LEFT JOIN "reference"."Species" ref_sp ON s."Species" = ref_sp."Species"
LEFT JOIN "reference"."regionTab" loc ON s."region" = loc."region"
LEFT JOIN "Lims"."Projects" p ON s.project_id = p.project_id
LEFT JOIN "Lab"."Storage" stor ON s.storage_id = stor.storage_id
LEFT JOIN "reference"."room" rr ON stor.room_id = rr.room_id
LEFT JOIN "Lab"."Sampling" samp ON s."Sampling_id" = samp."Sampling_id"
LEFT JOIN "Lab"."ExperimentSamples" es ON s.sample_id = es.sample_id
LEFT JOIN "Lab"."Experiments" exp ON es."Experiment_Nr" = exp."Experiment_Nr"
LEFT JOIN "reference"."Status" exp_status ON exp.status_id = exp_status.status_id
LEFT JOIN "Lims"."SOP" sop ON exp.sop_id = sop.sop_id
LEFT JOIN "reference"."Personal" ref_person_sop ON sop.author = ref_person_sop.person_id
LEFT JOIN "Lab"."Extraction" ext ON s.sample_id = ext.sample_id AND es."Experiment_Nr" = ext."Experiment_Nr"
LEFT JOIN "reference"."Status" ext_status ON ext.status_id = ext_status.status_id
LEFT JOIN "Lab"."Nanodrop" nd ON s.sample_id = nd.sample_id AND es."Experiment_Nr" = nd."Experiment_Nr"
LEFT JOIN "reference"."Status" nd_status ON nd.status_id = nd_status.status_id
LEFT JOIN "Lab"."Qubit" qu ON s.sample_id = qu.sample_id AND es."Experiment_Nr" = qu."Experiment_Nr"
LEFT JOIN "reference"."Status" qu_status ON qu.status_id = qu_status.status_id
LEFT JOIN "Lab"."Tapestation" tape ON s.sample_id = tape.sample_id AND es."Experiment_Nr" = tape."Experiment_Nr"
LEFT JOIN "reference"."Status" tape_status ON tape.status_id = tape_status.status_id
LEFT JOIN "Lab"."PCR" pcr ON s.sample_id = pcr.sample_id AND es."Experiment_Nr" = pcr."Experiment_Nr"
LEFT JOIN "reference"."Status" pcr_status ON pcr.status_id = pcr_status.status_id
LEFT JOIN "reference"."Genes" ref_genes ON pcr.gene_id = ref_genes.primer_id
LEFT JOIN "Lab"."qPCR" qpcr ON s.sample_id = qpcr.sample_id AND es."Experiment_Nr" = qpcr."Experiment_Nr"
LEFT JOIN "reference"."Status" qpcr_status ON qpcr.status_id = qpcr_status.status_id
LEFT JOIN "reference"."Genes" ref_genes_qpcr ON qpcr.gene_id = ref_genes_qpcr.primer_id
LEFT JOIN "Lab"."Library" lib ON s.sample_id = lib.sample_id AND es."Experiment_Nr" = lib."Experiment_Nr"
LEFT JOIN "Lab"."Sequencing" seq ON s.sample_id = seq.sample_id AND es."Experiment_Nr" = seq."Experiment_Nr"
LEFT JOIN "reference"."Status" seq_status ON seq.status_id = seq_status.status_id
LEFT JOIN "Lab"."Bioinformatics" bio ON s.sample_id = bio.sample_id AND es."Experiment_Nr" = bio."Experiment_Nr"
LEFT JOIN "reference"."Status" bio_status ON bio.status_id = bio_status.status_id; -- ADDED this missing JOIN!