-- =============================================
-- Schema Creation
-- =============================================
CREATE SCHEMA IF NOT EXISTS "Lab";
CREATE SCHEMA IF NOT EXISTS "Lims";
CREATE SCHEMA IF NOT EXISTS "Reference";
CREATE SCHEMA IF NOT EXISTS "Project_Wanderfische";

-- =============================================
-- Schema: Reference
-- =============================================

-- Table: Reference.Status
CREATE TABLE IF NOT EXISTS "Reference"."Status" (
    "nr" serial PRIMARY KEY,
    "status_id" text UNIQUE NOT NULL,
    "Description" text
);

-- Table: Reference.Room
CREATE TABLE IF NOT EXISTS "Reference"."Room" (
    "nr" serial PRIMARY KEY,
    "room_id" text UNIQUE NOT NULL,
    "etage" text,
    "address" text,
    "description" text
);

-- Table: Reference.Genes
CREATE TABLE IF NOT EXISTS "Reference"."Genes" (
    "nr" serial PRIMARY KEY,
    "primer_id" text UNIQUE NOT NULL,
    "TargetGene" text,
    "Primer_Sequence_Fwd" text,
    "Primer_Sequence_Rev" text,
    "probe" text,
    "description" text,
    "Reference" text
);

-- Table: Reference.Location
CREATE TABLE IF NOT EXISTS "Reference"."Location" (
    "nr" serial PRIMARY KEY,
    "Region" text NOT NULL UNIQUE,
    "Region_id" text UNIQUE NOT NULL,
    "country" text,
    "category" text,
    "Notes" text
);

-- Table: Reference.SamplesType
CREATE TABLE IF NOT EXISTS "Reference"."SamplesType" (
    "nr" serial PRIMARY KEY,
    "sample_type" text UNIQUE NOT NULL,
    "sample_typeAbrv" text UNIQUE NOT NULL,
    "description" text
);

-- Table: Reference.Species
CREATE TABLE IF NOT EXISTS "Reference"."Species" (
    "nr" serial PRIMARY KEY,
    "Species" text UNIQUE NOT NULL,
    "Genus" text NOT NULL,
    "Order" text NOT NULL,
    "Family" text NOT NULL,
    "DE_name" text, -- German name
    "En_name" text, -- English name
    "Length" numeric,
    "max_age" numeric,
    "description" text
);

-- Table: Reference.Category
CREATE TABLE IF NOT EXISTS "Reference"."Category" (
    "nr" serial PRIMARY KEY,
    "category" text UNIQUE NOT NULL,
    "description" text
);

-- Table: Reference.personal
CREATE TABLE IF NOT EXISTS "Reference"."Personal" (
    "nr" serial PRIMARY KEY,
    "person" text NOT NULL,
    "person_id" text UNIQUE NOT NULL,
    "password_hash" text,
    "description" text
);


-- =============================================
-- Schema: Lims
-- =============================================

-- Table: Lims.Projects
CREATE TABLE IF NOT EXISTS "Lims"."Projects" (
    "nr" serial PRIMARY KEY,
    "project_id" text UNIQUE NOT NULL,
    "Title" text,
    "status_id" text REFERENCES "Reference"."Status"("status_id"),
    "PI" text REFERENCES "Reference"."Personal"("person_id"),
    "Funder" text,
    "Start_date" date,
    "End_date" date,
    "Report_date" date,
    "Notes" text,
    "linkpublication" text,
    "PermitNumber" text,
    "attachment" bytea
);

CREATE TABLE IF NOT EXISTS "Lims"."ProjectPersons" (
    "project_id" TEXT REFERENCES "Lims"."Projects"("project_id") ON DELETE CASCADE,
    "person_id" TEXT REFERENCES "Reference"."Personal"("person_id") ON DELETE CASCADE,
    "role" TEXT,
    PRIMARY KEY ("project_id", "person_id")
);


-- Table: Lims.Equipment
CREATE TABLE IF NOT EXISTS "Lims"."Equipment" (
    "nr" serial PRIMARY KEY,
    "equipment_id" text UNIQUE NOT NULL,
    "equipment" text,
    "room_id" text REFERENCES "Reference"."Room"("room_id"),
    "lot" text,
    "Mobility" text,
    "DateManintenance" date,
    "Notes" text,
    "attachment" bytea
);

-- Table: Lims.SOP
CREATE TABLE IF NOT EXISTS "Lims"."SOP" (
    "nr" serial PRIMARY KEY,
    "sop_id" text UNIQUE NOT NULL,
    "Title" text,
    "version" text,
    "author" text REFERENCES "Reference"."Personal"("person_id"),
    "date_realise" date,
    "sop_protocol" text,
    "Notes" text,
    "attachment" bytea
);



-- Table: Lims.orders
CREATE TABLE IF NOT EXISTS "Lims"."orders" (
    "nr" serial PRIMARY KEY,
    "FI_Order_Nr" text UNIQUE,
    "item" text,
    "category" text REFERENCES "Reference"."Category"("category"),
    "Date" date,
    "price" numeric,
    "Quantity" text,
    "project_id" text REFERENCES "Lims"."Projects"("project_id"),
    "Company" text,
    "Notes" text,
    "status_id" text REFERENCES "Reference"."Status"("status_id"),
    "attachment" bytea
);



-- =============================================
-- Schema: Lab
-- =============================================

-- Table: Lab.Storage
CREATE TABLE IF NOT EXISTS "Lab"."Storage" (
    "nr" serial PRIMARY KEY,
    "storage_id" text UNIQUE NOT NULL,
    "room_id" text REFERENCES "Reference"."Room"("room_id"),
    "Freezer" text,
    "Etage" text,
    "Temperature" numeric,
    "TemperatureUnit" text,
    "Box" text,
    "BoxX_ABC" numeric,
    "BoxY_123" numeric,
    "project_id" text REFERENCES "Lims"."Projects"("project_id"),
    "Notes" text,
    "attachment" bytea
);


-- Table: Lims.Reagents
CREATE TABLE IF NOT EXISTS "Lims"."Reagents" (
    "nr" serial PRIMARY KEY,
    "Reagent_Name" text UNIQUE NOT NULL,
    "Reagent_CompleteName" text NOT NULL,
    "category" text REFERENCES "Reference"."Category"("category"),
    "Lot" text,
    "storage_id" text REFERENCES "Lab"."Storage"("storage_id"),
    "storage_position" numeric,
    "status_id" text REFERENCES "Reference"."Status"("status_id"),
    "Recieption_date" date,
    "Expire_date" date,
    "project_id" text REFERENCES "Lims"."Projects"("project_id"),
    "attachment" bytea,
    "Notes" text
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
    "Ecosytem" text,
    "Region" text REFERENCES "Reference"."Location"("Region"),
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
    "attachment" bytea
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
    "Notes" text,
    "LabBook" text,
    "status_id" text REFERENCES "Reference"."Status"("status_id"),
    "attachment" bytea
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
    "sample_type" text NOT NULL REFERENCES "Reference"."SamplesType"("sample_type"),
    "workflow_status_id" text REFERENCES "Reference"."Status"("status_id") DEFAULT 'Received' NOT NULL,
    "project_id" text REFERENCES "Lims"."Projects"("project_id"),
    "External_Name" text,
    "Region" text REFERENCES "Reference"."Location"("Region"),
    "Species" text REFERENCES "Reference"."Species"("Species"),
    "Length" numeric,
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
    "Notes" text,
    "attachment" bytea,
    "last_status_update" timestamp DEFAULT CURRENT_TIMESTAMP,
    "source_table" text NOT NULL
);


-- Table: Lab.ExperimentSamples
CREATE TABLE IF NOT EXISTS "Lab"."ExperimentSamples" (
    "nr" serial,
    "Experiment_Nr" text NOT NULL REFERENCES "Lab"."Experiments"("Experiment_Nr"),
    "sample_id" text NOT NULL REFERENCES "Lab"."Samples"("sample_id"),
    "Notes" text,
    PRIMARY KEY ("Experiment_Nr", "sample_id")
);

-- Table: "Lab"."Fish"
CREATE TABLE IF NOT EXISTS "Lab"."Fish" (
    "nr" serial,
    "sample_id" text PRIMARY KEY,
    "Sampling_id" text REFERENCES "Lab"."Sampling"("Sampling_id"),
    "Experiment_Nr" text REFERENCES "Lab"."Experiments"("Experiment_Nr"),
    "Species" text NOT NULL REFERENCES "Reference"."Species"("Species"),
    "Length" numeric,
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
    "sample_type" text NOT NULL REFERENCES "Reference"."SamplesType"("sample_type"),
    "Region" text REFERENCES "Reference"."Location"("Region"),
    "Transport" text,
    "External_Name" text,
    "ParentSample_id" text REFERENCES "Lab"."Samples"("sample_id"),
    "project_id" text REFERENCES "Lims"."Projects"("project_id"),
    "Notes" text,
    "attachment" bytea
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
    "Region" text REFERENCES "Reference"."Location"("Region"),
    "sample_type" text NOT NULL REFERENCES "Reference"."SamplesType"("sample_type"),
    "External_Name" text,
    "ParentSample_id" text REFERENCES "Lab"."Samples"("sample_id"),
    "Fish_ParentalID" text REFERENCES "Lab"."Fish"("sample_id"),
    "project_id" text REFERENCES "Lims"."Projects"("project_id"),
    "Notes" text,
    "attachment" bytea
);

-- Table: Lab.DNA
CREATE TABLE IF NOT EXISTS "Lab"."DNA" (
    "nr" serial,
    "sample_id" text PRIMARY KEY,
    "Sampling_id" text REFERENCES "Lab"."Sampling"("Sampling_id"),
    "Experiment_Nr" text REFERENCES "Lab"."Experiments"("Experiment_Nr"),
    "Volume_uL" numeric,
    "Concentration" numeric,
    "sample_type" text NOT NULL REFERENCES "Reference"."SamplesType"("sample_type"),
    "Region" text REFERENCES "Reference"."Location"("Region"),
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
    "Notes" text,
    "attachment" bytea
);

-- Table: Lab.RNA
CREATE TABLE IF NOT EXISTS "Lab"."RNA" (
    "nr" serial,
    "sample_id" text PRIMARY KEY,
    "Sampling_id" text REFERENCES "Lab"."Sampling"("Sampling_id"),
    "Experiment_Nr" text REFERENCES "Lab"."Experiments"("Experiment_Nr"),
    "Volume_uL" numeric,
    "Concentration" numeric,
    "sample_type" text NOT NULL REFERENCES "Reference"."SamplesType"("sample_type"),
    "Region" text REFERENCES "Reference"."Location"("Region"),
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
    "Notes" text,
    "attachment" bytea
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
    "Region" text REFERENCES "Reference"."Location"("Region"),
    "sample_type" text NOT NULL REFERENCES "Reference"."SamplesType"("sample_type"),
    "Sampler" text,
    "Reciever" text,
    "sampling_date" date,
    "Recieption_date" date,
    "storage_id" text REFERENCES "Lab"."Storage"("storage_id"),
    "storage_position" numeric,
    "ParentSample_id" text REFERENCES "Lab"."Samples"("sample_id"),
    "External_Name" text,
    "project_id" text REFERENCES "Lims"."Projects"("project_id"),
    "Notes" text,
    "attachment" bytea
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
    "sample_type" text NOT NULL REFERENCES "Reference"."SamplesType"("sample_type"),
    "Region" text REFERENCES "Reference"."Location"("Region"),
    "storage_id" text REFERENCES "Lab"."Storage"("storage_id"),
    "storage_position" numeric,
    "Notes" text,
    "ParentSample_id" text REFERENCES "Lab"."Samples"("sample_id"),
    "External_Name" text,
    "project_id" text REFERENCES "Lims"."Projects"("project_id"),
    "attachment" bytea
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
    "Notes" text,
    "status_id" text REFERENCES "Reference"."Status"("status_id"),
    "storage_id" text REFERENCES "Lab"."Storage"("storage_id"),
    "storage_position" numeric,
    "project_id" text REFERENCES "Lims"."Projects"("project_id"),
    "attachment" bytea
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
    "Notes" text,
    "status_id" text REFERENCES "Reference"."Status"("status_id"),
    "attachment" bytea,
    "storage_id" text REFERENCES "Lab"."Storage"("storage_id"),
    "storage_position" numeric,
    "project_id" text REFERENCES "Lims"."Projects"("project_id"),
    "ResultDate" timestamp with time zone,
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
    "Notes" text,
    "status_id" text REFERENCES "Reference"."Status"("status_id"),
    "storage_id" text REFERENCES "Lab"."Storage"("storage_id"),
    "storage_position" numeric,
    "project_id" text REFERENCES "Lims"."Projects"("project_id"),
    "attachment" bytea,
    "ResultDate" timestamp with time zone,
    "QubitTotalDna_ug" numeric GENERATED ALWAYS AS (("Elution_volume_ul" * "QubitOriginal_sample_conc") / 1000) STORED
);

-- Table: Lab.Tapestation
CREATE TABLE IF NOT EXISTS "Lab"."Tapestation" (
    "nr" serial PRIMARY KEY,
    "Experiment_Nr" text REFERENCES "Lab"."Experiments"("Experiment_Nr"),
    "date" date,
    "kit" text,
    "Person" text,
    "Notes" text,
    "sample_id" text REFERENCES "Lab"."Samples"("sample_id"),
    "Position" text,
    "status_id" text REFERENCES "Reference"."Status"("status_id"),
    "storage_id" text REFERENCES "Lab"."Storage"("storage_id"),
    "storage_position" numeric,
    "project_id" text REFERENCES "Lims"."Projects"("project_id"),
    "attachment" bytea,
    "ResultDate" timestamp with time zone
);

-- Table: Lab.PCR
CREATE TABLE IF NOT EXISTS "Lab"."PCR" (
    "nr" serial PRIMARY KEY,
    "Experiment_Nr" text REFERENCES "Lab"."Experiments"("Experiment_Nr"),
    "sample_id" text REFERENCES "Lab"."Samples"("sample_id"),
    "position" text,
    "gene_id" text REFERENCES "Reference"."Genes"("primer_id"),
    "PCRBlankID" text,
    "Date" date,
    "Person" text,
    "Notes" text,
    "kit" text,
    "storage_id" text REFERENCES "Lab"."Storage"("storage_id"),
    "storage_position" numeric,
    "status_id" text REFERENCES "Reference"."Status"("status_id"),
    "project_id" text REFERENCES "Lims"."Projects"("project_id"),
    "attachment" bytea,
    "Volume" numeric
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
    "Notes" text,
    "storage_id" text REFERENCES "Lab"."Storage"("storage_id"),
    "storage_position" numeric,
    "project_id" text REFERENCES "Lims"."Projects"("project_id"),
    "attachment" bytea,
    "ResultDate" timestamp with time zone
);

-- Table: Lab.qPCR
CREATE TABLE IF NOT EXISTS "Lab"."qPCR" (
    "nr" serial PRIMARY KEY,
    "Experiment_Nr" text REFERENCES "Lab"."Experiments"("Experiment_Nr"),
    "sample_id" text REFERENCES "Lab"."Samples"("sample_id"),
    "position" text,
    "Date" date,
    "Person" text,
    "gene_id" text REFERENCES "Reference"."Genes"("primer_id"),
    "CtValue" numeric,
    "InhibitorTestResult" text,
    "PCRBlankID" text,
    "kit" text,
    "Volume" numeric,
    "storage_id" text REFERENCES "Lab"."Storage"("storage_id"),
    "storage_position" numeric,
    "status_id" text REFERENCES "Reference"."Status"("status_id"),
    "project_id" text REFERENCES "Lims"."Projects"("project_id"),
    "attachment" bytea,
    "Notes" text
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
    "Notes" text,
    "attachment" bytea,
    "ResultDate" timestamp with time zone
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
    "status_id" text REFERENCES "Reference"."Status"("status_id"),
    "storage_id" text REFERENCES "Lab"."Storage"("storage_id"),
    "storage_position" numeric,
    "GenbankAccessionNumber" text,
    "project_id" text REFERENCES "Lims"."Projects"("project_id"),
    "attachment" bytea,
    "ResultDate" timestamp with time zone
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
    "ReferenceDatabase" text,
    "DatabaseVersion" text,
    "ClusteringThreshold" numeric,
    "FinalOutputPath" text,
    "Notes" text,
    "sample_id" text REFERENCES "Lab"."Samples"("sample_id"),
    "storage_id" text REFERENCES "Lab"."Storage"("storage_id"),
    "storage_position" numeric,
    "project_id" text REFERENCES "Lims"."Projects"("project_id"),
    "status_id" text REFERENCES "Reference"."Status"("status_id"),
    "attachment" bytea,
    "ResultDate" timestamp with time zone
);


CREATE TABLE IF NOT EXISTS "Lab"."protocols" (
    "nr" serial PRIMARY KEY,
    "Experiments_Nr" TEXT REFERENCES "Lab"."Experiments"("Experiment_Nr"),
    "protocol" TEXT,
    "run" TEXT,
    "Notes" TEXT
);



-- =============================================
-- Schema: Project_Wanderfische
-- =============================================

-- Table: Project_Wanderfische.Budget
CREATE TABLE IF NOT EXISTS "Project_Wanderfische"."Budget" (
    "nr" serial PRIMARY KEY,
    "project_id" text REFERENCES "Lims"."Projects"("project_id"),
    "budget_category" text,
    "allocated_amount" numeric,
    "spent_amount" numeric,
    "budget_year" integer,
    "notes" text
);

-- Table: Project_Wanderfische.Deliverables
CREATE TABLE IF NOT EXISTS "Project_Wanderfische"."Deliverables" (
    "nr" serial PRIMARY KEY,
    "project_id" text REFERENCES "Lims"."Projects"("project_id"),
    "deliverable_name" text,
    "due_date" date,
    "delivered" boolean DEFAULT false,
    "status_id" text REFERENCES "Reference"."Status"("status_id"),
    "attachment" bytea,
    "comments" text
);


-- ====================================================
-- Add log who when changed
-- ====================================================
-- =============================================
-- Function to update modification timestamp and user
-- =============================================
CREATE OR REPLACE FUNCTION set_modified_columns()
RETURNS TRIGGER AS $$
BEGIN
    NEW.time_modification = CURRENT_TIMESTAMP;
    -- Optionally set modified_by to the current database user
    -- If your application manages users differently, you would update this logic
    NEW.modified_by = CURRENT_USER;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- =============================================
-- Reference Schema Tables
-- =============================================
ALTER TABLE "Reference"."Status"
ADD COLUMN IF NOT EXISTS "modified_by" TEXT,
ADD COLUMN IF NOT EXISTS "time_modification" TIMESTAMPTZ;
CREATE OR REPLACE TRIGGER trg_Status_modified BEFORE UPDATE ON "Reference"."Status" FOR EACH ROW EXECUTE FUNCTION set_modified_columns();

ALTER TABLE "Reference"."Room"
ADD COLUMN IF NOT EXISTS "modified_by" TEXT,
ADD COLUMN IF NOT EXISTS "time_modification" TIMESTAMPTZ;
CREATE OR REPLACE TRIGGER trg_Room_modified BEFORE UPDATE ON "Reference"."Room" FOR EACH ROW EXECUTE FUNCTION set_modified_columns();

ALTER TABLE "Reference"."Genes"
ADD COLUMN IF NOT EXISTS "modified_by" TEXT,
ADD COLUMN IF NOT EXISTS "time_modification" TIMESTAMPTZ;
CREATE OR REPLACE TRIGGER trg_Genes_modified BEFORE UPDATE ON "Reference"."Genes" FOR EACH ROW EXECUTE FUNCTION set_modified_columns();

ALTER TABLE "Reference"."Location"
ADD COLUMN IF NOT EXISTS "modified_by" TEXT,
ADD COLUMN IF NOT EXISTS "time_modification" TIMESTAMPTZ;
CREATE OR REPLACE TRIGGER trg_Location_modified BEFORE UPDATE ON "Reference"."Location" FOR EACH ROW EXECUTE FUNCTION set_modified_columns();

ALTER TABLE "Reference"."SamplesType"
ADD COLUMN IF NOT EXISTS "modified_by" TEXT,
ADD COLUMN IF NOT EXISTS "time_modification" TIMESTAMPTZ;
CREATE OR REPLACE TRIGGER trg_SamplesType_modified BEFORE UPDATE ON "Reference"."SamplesType" FOR EACH ROW EXECUTE FUNCTION set_modified_columns();

ALTER TABLE "Reference"."Species"
ADD COLUMN IF NOT EXISTS "modified_by" TEXT,
ADD COLUMN IF NOT EXISTS "time_modification" TIMESTAMPTZ;
CREATE OR REPLACE TRIGGER trg_Species_modified BEFORE UPDATE ON "Reference"."Species" FOR EACH ROW EXECUTE FUNCTION set_modified_columns();

ALTER TABLE "Reference"."Category"
ADD COLUMN IF NOT EXISTS "modified_by" TEXT,
ADD COLUMN IF NOT EXISTS "time_modification" TIMESTAMPTZ;
CREATE OR REPLACE TRIGGER trg_Category_modified BEFORE UPDATE ON "Reference"."Category" FOR EACH ROW EXECUTE FUNCTION set_modified_columns();

ALTER TABLE "Reference"."Personal"
ADD COLUMN IF NOT EXISTS "modified_by" TEXT,
ADD COLUMN IF NOT EXISTS "time_modification" TIMESTAMPTZ;
CREATE OR REPLACE TRIGGER trg_Personal_modified BEFORE UPDATE ON "Reference"."Personal" FOR EACH ROW EXECUTE FUNCTION set_modified_columns();

-- =============================================
-- Lims Schema Tables
-- =============================================
ALTER TABLE "Lims"."Projects"
ADD COLUMN IF NOT EXISTS "modified_by" TEXT,
ADD COLUMN IF NOT EXISTS "time_modification" TIMESTAMPTZ;
CREATE OR REPLACE TRIGGER trg_Projects_modified BEFORE UPDATE ON "Lims"."Projects" FOR EACH ROW EXECUTE FUNCTION set_modified_columns();

ALTER TABLE "Lims"."ProjectPersons"
ADD COLUMN IF NOT EXISTS "modified_by" TEXT,
ADD COLUMN IF NOT EXISTS "time_modification" TIMESTAMPTZ;
CREATE OR REPLACE TRIGGER trg_ProjectPersons_modified BEFORE UPDATE ON "Lims"."ProjectPersons" FOR EACH ROW EXECUTE FUNCTION set_modified_columns();

ALTER TABLE "Lims"."Equipment"
ADD COLUMN IF NOT EXISTS "modified_by" TEXT,
ADD COLUMN IF NOT EXISTS "time_modification" TIMESTAMPTZ;
CREATE OR REPLACE TRIGGER trg_Equipment_modified BEFORE UPDATE ON "Lims"."Equipment" FOR EACH ROW EXECUTE FUNCTION set_modified_columns();

ALTER TABLE "Lims"."SOP"
ADD COLUMN IF NOT EXISTS "modified_by" TEXT,
ADD COLUMN IF NOT EXISTS "time_modification" TIMESTAMPTZ;
CREATE OR REPLACE TRIGGER trg_SOP_modified BEFORE UPDATE ON "Lims"."SOP" FOR EACH ROW EXECUTE FUNCTION set_modified_columns();

ALTER TABLE "Lims"."orders"
ADD COLUMN IF NOT EXISTS "modified_by" TEXT,
ADD COLUMN IF NOT EXISTS "time_modification" TIMESTAMPTZ;
CREATE OR REPLACE TRIGGER trg_orders_modified BEFORE UPDATE ON "Lims"."orders" FOR EACH ROW EXECUTE FUNCTION set_modified_columns();

ALTER TABLE "Lims"."Reagents"
ADD COLUMN IF NOT EXISTS "modified_by" TEXT,
ADD COLUMN IF NOT EXISTS "time_modification" TIMESTAMPTZ;
CREATE OR REPLACE TRIGGER trg_Reagents_modified BEFORE UPDATE ON "Lims"."Reagents" FOR EACH ROW EXECUTE FUNCTION set_modified_columns();

-- =============================================
-- Lab Schema Tables
-- =============================================
ALTER TABLE "Lab"."Storage"
ADD COLUMN IF NOT EXISTS "modified_by" TEXT,
ADD COLUMN IF NOT EXISTS "time_modification" TIMESTAMPTZ;
CREATE OR REPLACE TRIGGER trg_Storage_modified BEFORE UPDATE ON "Lab"."Storage" FOR EACH ROW EXECUTE FUNCTION set_modified_columns();

ALTER TABLE "Lab"."Sampling"
ADD COLUMN IF NOT EXISTS "modified_by" TEXT,
ADD COLUMN IF NOT EXISTS "time_modification" TIMESTAMPTZ;
CREATE OR REPLACE TRIGGER trg_Sampling_modified BEFORE UPDATE ON "Lab"."Sampling" FOR EACH ROW EXECUTE FUNCTION set_modified_columns();

ALTER TABLE "Lab"."Experiments"
ADD COLUMN IF NOT EXISTS "modified_by" TEXT,
ADD COLUMN IF NOT EXISTS "time_modification" TIMESTAMPTZ;
CREATE OR REPLACE TRIGGER trg_Experiments_modified BEFORE UPDATE ON "Lab"."Experiments" FOR EACH ROW EXECUTE FUNCTION set_modified_columns();

ALTER TABLE "Lab"."Samples"
ADD COLUMN IF NOT EXISTS "modified_by" TEXT,
ADD COLUMN IF NOT EXISTS "time_modification" TIMESTAMPTZ;
CREATE OR REPLACE TRIGGER trg_Samples_modified BEFORE UPDATE ON "Lab"."Samples" FOR EACH ROW EXECUTE FUNCTION set_modified_columns();

ALTER TABLE "Lab"."ExperimentSamples"
ADD COLUMN IF NOT EXISTS "modified_by" TEXT,
ADD COLUMN IF NOT EXISTS "time_modification" TIMESTAMPTZ;
CREATE OR REPLACE TRIGGER trg_ExperimentSamples_modified BEFORE UPDATE ON "Lab"."ExperimentSamples" FOR EACH ROW EXECUTE FUNCTION set_modified_columns();

ALTER TABLE "Lab"."Fish"
ADD COLUMN IF NOT EXISTS "modified_by" TEXT,
ADD COLUMN IF NOT EXISTS "time_modification" TIMESTAMPTZ;
CREATE OR REPLACE TRIGGER trg_Fish_modified BEFORE UPDATE ON "Lab"."Fish" FOR EACH ROW EXECUTE FUNCTION set_modified_columns();

ALTER TABLE "Lab"."Tissue"
ADD COLUMN IF NOT EXISTS "modified_by" TEXT,
ADD COLUMN IF NOT EXISTS "time_modification" TIMESTAMPTZ;
CREATE OR REPLACE TRIGGER trg_Tissue_modified BEFORE UPDATE ON "Lab"."Tissue" FOR EACH ROW EXECUTE FUNCTION set_modified_columns();

ALTER TABLE "Lab"."DNA"
ADD COLUMN IF NOT EXISTS "modified_by" TEXT,
ADD COLUMN IF NOT EXISTS "time_modification" TIMESTAMPTZ;
CREATE OR REPLACE TRIGGER trg_DNA_modified BEFORE UPDATE ON "Lab"."DNA" FOR EACH ROW EXECUTE FUNCTION set_modified_columns();

ALTER TABLE "Lab"."RNA"
ADD COLUMN IF NOT EXISTS "modified_by" TEXT,
ADD COLUMN IF NOT EXISTS "time_modification" TIMESTAMPTZ;
CREATE OR REPLACE TRIGGER trg_RNA_modified BEFORE UPDATE ON "Lab"."RNA" FOR EACH ROW EXECUTE FUNCTION set_modified_columns();

ALTER TABLE "Lab"."Sediments"
ADD COLUMN IF NOT EXISTS "modified_by" TEXT,
ADD COLUMN IF NOT EXISTS "time_modification" TIMESTAMPTZ;
CREATE OR REPLACE TRIGGER trg_Sediments_modified BEFORE UPDATE ON "Lab"."Sediments" FOR EACH ROW EXECUTE FUNCTION set_modified_columns();

ALTER TABLE "Lab"."Water"
ADD COLUMN IF NOT EXISTS "modified_by" TEXT,
ADD COLUMN IF NOT EXISTS "time_modification" TIMESTAMPTZ;
CREATE OR REPLACE TRIGGER trg_Water_modified BEFORE UPDATE ON "Lab"."Water" FOR EACH ROW EXECUTE FUNCTION set_modified_columns();

ALTER TABLE "Lab"."Extraction"
ADD COLUMN IF NOT EXISTS "modified_by" TEXT,
ADD COLUMN IF NOT EXISTS "time_modification" TIMESTAMPTZ;
CREATE OR REPLACE TRIGGER trg_Extraction_modified BEFORE UPDATE ON "Lab"."Extraction" FOR EACH ROW EXECUTE FUNCTION set_modified_columns();

ALTER TABLE "Lab"."Nanodrop"
ADD COLUMN IF NOT EXISTS "modified_by" TEXT,
ADD COLUMN IF NOT EXISTS "time_modification" TIMESTAMPTZ;
CREATE OR REPLACE TRIGGER trg_Nanodrop_modified BEFORE UPDATE ON "Lab"."Nanodrop" FOR EACH ROW EXECUTE FUNCTION set_modified_columns();

ALTER TABLE "Lab"."Qubit"
ADD COLUMN IF NOT EXISTS "modified_by" TEXT,
ADD COLUMN IF NOT EXISTS "time_modification" TIMESTAMPTZ;
CREATE OR REPLACE TRIGGER trg_Qubit_modified BEFORE UPDATE ON "Lab"."Qubit" FOR EACH ROW EXECUTE FUNCTION set_modified_columns();

ALTER TABLE "Lab"."Tapestation"
ADD COLUMN IF NOT EXISTS "modified_by" TEXT,
ADD COLUMN IF NOT EXISTS "time_modification" TIMESTAMPTZ;
CREATE OR REPLACE TRIGGER trg_Tapestation_modified BEFORE UPDATE ON "Lab"."Tapestation" FOR EACH ROW EXECUTE FUNCTION set_modified_columns();

ALTER TABLE "Lab"."PCR"
ADD COLUMN IF NOT EXISTS "modified_by" TEXT,
ADD COLUMN IF NOT EXISTS "time_modification" TIMESTAMPTZ;
CREATE OR REPLACE TRIGGER trg_PCR_modified BEFORE UPDATE ON "Lab"."PCR" FOR EACH ROW EXECUTE FUNCTION set_modified_columns();

ALTER TABLE "Lab"."Gelelectrophoresis"
ADD COLUMN IF NOT EXISTS "modified_by" TEXT,
ADD COLUMN IF NOT EXISTS "time_modification" TIMESTAMPTZ;
CREATE OR REPLACE TRIGGER trg_Gelelectrophoresis_modified BEFORE UPDATE ON "Lab"."Gelelectrophoresis" FOR EACH ROW EXECUTE FUNCTION set_modified_columns();

ALTER TABLE "Lab"."qPCR"
ADD COLUMN IF NOT EXISTS "modified_by" TEXT,
ADD COLUMN IF NOT EXISTS "time_modification" TIMESTAMPTZ;
CREATE OR REPLACE TRIGGER trg_qPCR_modified BEFORE UPDATE ON "Lab"."qPCR" FOR EACH ROW EXECUTE FUNCTION set_modified_columns();

ALTER TABLE "Lab"."Library"
ADD COLUMN IF NOT EXISTS "modified_by" TEXT,
ADD COLUMN IF NOT EXISTS "time_modification" TIMESTAMPTZ;
CREATE OR REPLACE TRIGGER trg_Library_modified BEFORE UPDATE ON "Lab"."Library" FOR EACH ROW EXECUTE FUNCTION set_modified_columns();

ALTER TABLE "Lab"."Sequencing"
ADD COLUMN IF NOT EXISTS "modified_by" TEXT,
ADD COLUMN IF NOT EXISTS "time_modification" TIMESTAMPTZ;
CREATE OR REPLACE TRIGGER trg_Sequencing_modified BEFORE UPDATE ON "Lab"."Sequencing" FOR EACH ROW EXECUTE FUNCTION set_modified_columns();

ALTER TABLE "Lab"."Bioinformatics"
ADD COLUMN IF NOT EXISTS "modified_by" TEXT,
ADD COLUMN IF NOT EXISTS "time_modification" TIMESTAMPTZ;
CREATE OR REPLACE TRIGGER trg_Bioinformatics_modified BEFORE UPDATE ON "Lab"."Bioinformatics" FOR EACH ROW EXECUTE FUNCTION set_modified_columns();

ALTER TABLE "Lab"."protocols"
ADD COLUMN IF NOT EXISTS "modified_by" TEXT,
ADD COLUMN IF NOT EXISTS "time_modification" TIMESTAMPTZ;
CREATE OR REPLACE TRIGGER trg_protocols_modified BEFORE UPDATE ON "Lab"."protocols" FOR EACH ROW EXECUTE FUNCTION set_modified_columns();






-- ==============================================
-- Add workwlof for experiments special
-- ===============================================


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

-- =================================================================
-- Initial Data Population
-- =================================================================
INSERT INTO "Reference"."Status" ("status_id", "Description") VALUES
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
    "last_value" BIGINT NOT NULL
);

CREATE TABLE IF NOT EXISTS "Lab"."aliquot_sequence" (
    "base_id" TEXT PRIMARY KEY,
    "last_value" INT NOT NULL
);


--
-- FUNCTION 1: Generate Sample ID using a robust JSONB approach
--
CREATE OR REPLACE FUNCTION "Lab".generate_sample_id_trigger_func()
RETURNS TRIGGER AS $$
DECLARE
    json_new JSONB;
    parent_id TEXT;
    aliquot_suffix TEXT;
    aliquot_base_id TEXT;
    aliquot_seq_num INT;
    type_prefix TEXT;
    year_part TEXT;
    location_prefix TEXT;
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
        SELECT "sample_typeAbrv" INTO aliquot_suffix FROM "Reference"."SamplesType" WHERE "sample_type" = (json_new ->> 'sample_type');
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
        SELECT "sample_typeAbrv" INTO type_prefix FROM "Reference"."SamplesType" WHERE "sample_type" = (json_new ->> 'sample_type');
        IF type_prefix IS NULL THEN
            RAISE EXCEPTION 'Cannot generate sample ID: sample_type "%" not found.', (json_new ->> 'sample_type');
        END IF;

        -- Get location abbreviation from JSONB.
        IF (json_new ->> 'Region') IS NULL THEN
            RAISE EXCEPTION 'Cannot generate sample ID: "Region" field cannot be empty.';
        END IF;
        SELECT "Region_id" INTO location_prefix FROM "Reference"."Location" WHERE "Region" = (json_new ->> 'Region');
        IF location_prefix IS NULL THEN
            RAISE EXCEPTION 'Cannot generate sample ID: Region name "%" not found in "Reference"."Location".', (json_new ->> 'Region');
        END IF;

        -- Construct and assign the new ID.
        root_id_key := type_prefix || year_part || location_prefix;
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
    IF (json_new ->> 'Region') IS NULL THEN
        RAISE EXCEPTION 'Cannot generate Sampling ID: "Region" field cannot be empty.';
    END IF;

    SELECT "Region_id" INTO location_prefix
    FROM "Reference"."Location"
    WHERE "Region" = (json_new ->> 'Region');

    IF location_prefix IS NULL THEN
        RAISE EXCEPTION 'Cannot generate Sampling ID: Region name "%" not found in "Reference"."Location".', (json_new ->> 'Region');
    END IF;

    -- Construct the key for the sequence table: S + Year + LocationID
    sampling_id_key := year_part || location_prefix;

    -- Increment the sequence number for this specific key
    INSERT INTO "Lab"."sampling_id_sequence" ("key", "last_value") VALUES (sampling_id_key, 1)
    ON CONFLICT ("key") DO UPDATE SET "last_value" = "Lab"."sampling_id_sequence".last_value + 1
    RETURNING "last_value" INTO sampling_seq_num;

    -- Assign the new formatted Sampling_id
    NEW."Sampling_id" := sampling_id_key || lpad(sampling_seq_num::TEXT, 4, '0');

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
CREATE OR REPLACE FUNCTION "Lab".copy_to_samples()
RETURNS TRIGGER AS $$
DECLARE
    json_new JSONB;
BEGIN
    json_new := to_jsonb(NEW);

    INSERT INTO "Lab"."Samples" (
        "sample_id", "project_id", "Sampling_id", "Species", "Length", "Weight", "Sex", "MaturityStage", "Age",
        "StomachContents", "DiseaseInfo", "TagID", "Volume_uL", "Concentration", "Volume", "unity",
        "Depth", "Sampling_Method", "ConservationBuffer", "Tide", "VolumeL", "Filter", "FilterPoreSize",
        "Transport", "storage_id", "storage_position", "Sampler", "Reciever", "sampling_date",
        "Recieption_date", "sample_type", "Region", "External_Name", "Notes", "attachment",
        "workflow_status_id", "last_status_update", "source_table"
    ) VALUES (
        json_new ->> 'sample_id',
        json_new ->> 'project_id',
        json_new ->> 'Sampling_id',
        json_new ->> 'Species',
        (json_new ->> 'Length')::numeric,
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
        json_new ->> 'Region',
        json_new ->> 'External_Name',
        json_new ->> 'Notes',
        CASE WHEN json_new ->> 'attachment' IS NOT NULL THEN decode(json_new ->> 'attachment', 'hex') ELSE NULL END,
        'Received',
        CURRENT_TIMESTAMP,
        lower(TG_TABLE_NAME)
    )
    ON CONFLICT (sample_id) DO UPDATE SET
        "project_id" = COALESCE(EXCLUDED."project_id", "Lab"."Samples"."project_id"),
        "Region" = COALESCE(EXCLUDED."Region", "Lab"."Samples"."Region"),
        "Species" = COALESCE(EXCLUDED."Species", "Lab"."Samples"."Species"),
        "Notes" = COALESCE(EXCLUDED."Notes", "Lab"."Samples"."Notes"),
        "last_status_update" = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


--
--  FUNCTION 3: Consolidated function to update workflow status
--
CREATE OR REPLACE FUNCTION "Lab".update_workflow_status()
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
CREATE OR REPLACE FUNCTION "Lab".update_central_samples()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE "Lab"."Samples"
    SET
        "project_id" = NEW."project_id",
        "Region" = NEW."Region",
        "storage_id" = NEW."storage_id",
        "storage_position" = NEW."storage_position",
        "Notes" = NEW."Notes",
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
-- wird jede Ansicht zuerst gel�scht, falls sie existiert.
DROP VIEW IF EXISTS "Lab"."Samples_tracking" CASCADE;
DROP VIEW IF EXISTS "Lims"."Project_Summary" CASCADE;
DROP VIEW IF EXISTS "Lab"."Storage_Inventory_Summary" CASCADE;
DROP VIEW IF EXISTS "Lims"."Reagent_Stock_Status" CASCADE;
DROP VIEW IF EXISTS "Lab"."Experiment_Progress_Overview" CASCADE;
DROP VIEW IF EXISTS "Reference"."Complete_Species_Names" CASCADE;

-- View 1: Lab.Samples_tracking
-- Provides a comprehensive, unified view of all samples and their progress.
CREATE OR REPLACE VIEW "Lab"."Samples_tracking" AS
SELECT
    -- Core Sample Info from Lab.Samples
    s.sample_id,
    s.project_id,
    s.source_table,
    s.sample_type,
    s."External_Name",
    s.storage_id,
    s.storage_position,
    s."Sampler",
    s."Reciever",
    s.sampling_date AS sample_creation_date,
    s."Recieption_date",
    s."Notes" AS sample_notes,
    s.workflow_status_id AS current_workflow_status,
    stat."Description" AS workflow_status_description,
    s.last_status_update,

    -- Specific sample attributes from Lab.Samples and joined tables
    s."Species" AS species_scientific_name,
    ref_sp."DE_name" AS species_de_name,
    ref_sp."En_name" AS species_en_name,
    s."Length",
    s."Weight",
    s."Sex",
    s."MaturityStage",
    s."Age",
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
    samp.sampling_date AS sampling_event_date,
    samp."Lat" AS sampling_lat,
    samp."Lon" AS sampling_lon,
    loc."Region" AS location_name,
    loc.country AS location_country,
    samp."Ecosytem" AS sampling_ecosystem,

    -- Experiment Info
    exp."Experiment_Nr" AS exp_nr,
    exp."Experiment_title" AS exp_title,
    exp.project_id AS exp_project,

    -- Key results from analysis tables
    ext."Date" AS ext_date,
    ext."Yield_Qubit_ng_ul" AS ext_yield_qubit,
    qu.date AS qubit_date,
    qu."QubitOriginal_sample_conc" AS qubit_concentration,
    lib."Library_id",
    lib."Date" AS library_date,
    seq."Date" AS seq_date,
    seq."TotalReads" AS seq_total_reads,
    bio."Date" AS bio_date,
    bio."PipelineName" AS bio_pipeline_name
FROM "Lab"."Samples" s
LEFT JOIN "Reference"."Status" stat ON s.workflow_status_id = stat.status_id
LEFT JOIN "Reference"."Species" ref_sp ON s."Species" = ref_sp."Species"
LEFT JOIN "Reference"."Location" loc ON s."Region" = loc."Region"
LEFT JOIN "Lab"."Sampling" samp ON s."Sampling_id" = samp."Sampling_id"
LEFT JOIN "Lab"."ExperimentSamples" es ON s.sample_id = es.sample_id
LEFT JOIN "Lab"."Experiments" exp ON es."Experiment_Nr" = exp."Experiment_Nr"
LEFT JOIN "Lab"."Extraction" ext ON s.sample_id = ext.sample_id AND exp."Experiment_Nr" = ext."Experiment_Nr"
LEFT JOIN "Lab"."Qubit" qu ON s.sample_id = qu.sample_id AND exp."Experiment_Nr" = qu."Experiment_Nr"
LEFT JOIN "Lab"."Library" lib ON s.sample_id = lib.sample_id AND exp."Experiment_Nr" = lib."Experiment_Nr"
LEFT JOIN "Lab"."Sequencing" seq ON s.sample_id = seq.sample_id AND exp."Experiment_Nr" = seq."Experiment_Nr"
LEFT JOIN "Lab"."Bioinformatics" bio ON s.sample_id = bio.sample_id AND exp."Experiment_Nr" = bio."Experiment_Nr";


-- View 2: Lims.Project_Summary
-- Provides a high-level overview of all projects.
CREATE OR REPLACE VIEW "Lims"."Project_Summary" AS
SELECT
    p.project_id,
    p."Title" AS project_title,
    ref_status."Description" AS project_status,
    p."Funder",
    p."Start_date",
    p."End_date",
    COUNT(DISTINCT e."Experiment_Nr") AS number_of_experiments,
    COUNT(DISTINCT d.nr) AS number_of_deliverables,
    SUM(b.allocated_amount) AS total_allocated_budget,
    SUM(b.spent_amount) AS total_spent_budget
FROM "Lims"."Projects" p
LEFT JOIN "Reference"."Status" ref_status ON p.status_id = ref_status.status_id
LEFT JOIN "Lab"."Experiments" e ON p.project_id = e.project_id
LEFT JOIN "Project_Wanderfische"."Deliverables" d ON p.project_id = d.project_id
LEFT JOIN "Project_Wanderfische"."Budget" b ON p.project_id = b.project_id
GROUP BY
    p.project_id, p."Title", ref_status."Description", p."Funder",
    p."Start_date", p."End_date";


-- View 3: Lab.Storage_Inventory_Summary
-- Provides a summary of storage locations and sample counts.
CREATE OR REPLACE VIEW "Lab"."Storage_Inventory_Summary" AS
SELECT
    ls.storage_id,
    ls.room_id,
    rr.description AS room_description,
    ls."Freezer",
    ls."Temperature",
    ls."TemperatureUnit",
    ls."Box",
    ls."BoxX_ABC",
    ls."BoxY_123",
    COUNT(s.sample_id) AS total_samples_stored
FROM "Lab"."Storage" ls
LEFT JOIN "Reference"."Room" rr ON ls.room_id = rr.room_id
LEFT JOIN "Lab"."Samples" s ON ls.storage_id = s.storage_id
GROUP BY
    ls.storage_id, ls.room_id, rr.description, ls."Freezer", ls."Temperature",
    ls."TemperatureUnit", ls."Box", ls."BoxX_ABC", ls."BoxY_123"
ORDER BY ls.storage_id;


-- View 4: Lims.Reagent_Stock_Status
-- Monitors the current stock and expiry dates of reagents.
CREATE OR REPLACE VIEW "Lims"."Reagent_Stock_Status" AS
SELECT
    lr."Reagent_Name",
    lr."Reagent_CompleteName",
    lr.category,
    ref_cat.description AS category_description,
    lr."Lot",
    lr.storage_id,
    ref_status."Description" AS current_status,
    lr."Recieption_date",
    lr."Expire_date",
    (lr."Expire_date" - CURRENT_DATE) AS days_until_expiry
FROM "Lims"."Reagents" lr
LEFT JOIN "Reference"."Category" ref_cat ON lr.category = ref_cat.category
LEFT JOIN "Reference"."Status" ref_status ON lr.status_id = ref_status.status_id
ORDER BY lr."Expire_date" ASC;

-- View 5: Lab.Experiment_Progress_Overview
-- Tracks the progress of experiments through various lab stages.
CREATE OR REPLACE VIEW "Lab"."Experiment_Progress_Overview" AS
SELECT
    e."Experiment_Nr",
    e."Experiment_title",
    e.project_id,
    proj."Title" AS project_title,
    ref_status."Description" AS experiment_status,
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
LEFT JOIN "Reference"."Status" ref_status ON e.status_id = ref_status.status_id
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
    ref_status."Description", e."Date", e."Person"
ORDER BY e."Date" DESC;


-- View 6: Reference.Complete_Species_Names
-- Provides a convenient lookup for species scientific and common names.
CREATE OR REPLACE VIEW "Reference"."Complete_Species_Names" AS
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
FROM "Reference"."Species";






-- ===================================================================================
-- ==============================================================================

DROP VIEW IF EXISTS "Lab"."Samples_tracking" CASCADE;

CREATE OR REPLACE VIEW "Lab"."Samples_tracking" AS
SELECT
    -- Core Sample Info from Lab.Samples
    s.sample_id,
    s.project_id,
    p."Title" AS project_title,
    s.source_table,
    s.sample_type,
    st.description AS sample_type_description,
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
    s."Notes" AS sample_notes,
    s.workflow_status_id AS current_workflow_status,
    stat."Description" AS workflow_status_description,
    s.last_status_update,

    -- Specific sample attributes from Lab.Samples and joined tables
    s."Species" AS species_scientific_name,
    ref_sp."Genus" AS species_genus,
    ref_sp."Order" AS species_order,
    ref_sp."Family" AS species_family,
    ref_sp."DE_name" AS species_de_name,
    ref_sp."En_name" AS species_en_name,
    ref_sp."Length" AS species_avg_length,
    ref_sp.max_age AS species_max_age,
    s."Length" AS sample_length,
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
    samp."Ecosytem" AS sampling_ecosystem,
    loc."Region" AS location_name,
    loc."Region_id" AS location_region_id,
    loc.country AS location_country,
    loc.category AS location_category,
    loc."Notes" AS location_notes,
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
    exp."Notes" AS exp_notes,
    exp."LabBook" AS exp_labbook,
    exp.status_id AS exp_status_id,
    exp_status."Description" AS exp_status_description,
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
    ext."Notes" AS ext_notes,
    ext.status_id AS ext_status_id,
    ext_status."Description" AS ext_status_description,

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
    nd."Notes" AS nd_notes,
    nd."status_id" AS nd_status_id,
    nd_status."Description" AS nd_status_description,
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
    qu."Notes" AS qu_notes,
    qu."status_id" AS qu_status_id,
    qu_status."Description" AS qu_status_description,
    qu."ResultDate" AS qu_result_date,
    qu."QubitTotalDna_ug",

    -- Tapestation Results
    tape."date" AS tape_date,
    tape.kit AS tape_kit,
    tape."Person" AS tape_person,
    tape."Notes" AS tape_notes,
    tape."Position" AS tape_position,
    tape.status_id AS tape_status_id,
    tape_status."Description" AS tape_status_description,
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
    pcr."Notes" AS pcr_notes,
    pcr.kit AS pcr_kit,
    pcr."Volume" AS pcr_volume,
    pcr.status_id AS pcr_status_id,
    pcr_status."Description" AS pcr_status_description,

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
    qpcr_status."Description" AS qpcr_status_description,
    qpcr."Notes" AS qpcr_notes,

    -- Library Prep Results
    lib."Library_id",
    lib."Date" AS library_date,
    lib."Person" AS library_person,
    lib."LibraryPrepKit",
    lib."IndexSequence",
    lib."ReadLength" AS library_read_length,
    lib."Notes" AS library_notes,
    lib."ResultDate" AS library_result_date,

    -- Sequencing Results
    seq.sequencing_id,
    seq."Date" AS seq_date,
    seq."Person" AS seq_person,
    seq."Sequencer",
    seq."FlowCellID",
    seq."LibraryPrepKit" AS seq_library_prep_kit,
    seq."IndexSequence" AS seq_index_sequence,
    seq."ReadLength" AS seq_read_length,
    seq."TotalReads",
    seq."RawDataPath",
    seq."status_id" AS seq_status_id,
    seq_status."Description" AS seq_status_description,
    seq."GenbankAccessionNumber",
    seq."ResultDate" AS seq_result_date,

    -- Bioinformatics Results
    bio.bioinfo_id,
    bio."Date" AS bio_date,
    bio."Person" AS bio_person,
    bio."PipelineName" AS bio_pipeline_name,
    bio."PipelineVersion",
    bio."ReferenceDatabase",
    bio."DatabaseVersion",
    bio."ClusteringThreshold",
    bio."FinalOutputPath",
    bio."Notes" AS bio_notes,
    bio."status_id" AS bio_status_id,
    bio_status."Description" AS bio_status_description, -- Corrected: Quoted "Description"
    bio."ResultDate" AS bio_result_date

FROM "Lab"."Samples" s
LEFT JOIN "Reference"."Status" stat ON s.workflow_status_id = stat.status_id
LEFT JOIN "Reference"."SamplesType" st ON s.sample_type = st.sample_type
LEFT JOIN "Reference"."Species" ref_sp ON s."Species" = ref_sp."Species"
LEFT JOIN "Reference"."Location" loc ON s."Region" = loc."Region"
LEFT JOIN "Lims"."Projects" p ON s.project_id = p.project_id
LEFT JOIN "Lab"."Storage" stor ON s.storage_id = stor.storage_id
LEFT JOIN "Reference"."Room" rr ON stor.room_id = rr.room_id
LEFT JOIN "Lab"."Sampling" samp ON s."Sampling_id" = samp."Sampling_id"
LEFT JOIN "Lab"."ExperimentSamples" es ON s.sample_id = es.sample_id
LEFT JOIN "Lab"."Experiments" exp ON es."Experiment_Nr" = exp."Experiment_Nr"
LEFT JOIN "Reference"."Status" exp_status ON exp.status_id = exp_status.status_id
LEFT JOIN "Lims"."SOP" sop ON exp.sop_id = sop.sop_id
LEFT JOIN "Reference"."Personal" ref_person_sop ON sop.author = ref_person_sop.person_id
LEFT JOIN "Lab"."Extraction" ext ON s.sample_id = ext.sample_id AND es."Experiment_Nr" = ext."Experiment_Nr"
LEFT JOIN "Reference"."Status" ext_status ON ext.status_id = ext_status.status_id
LEFT JOIN "Lab"."Nanodrop" nd ON s.sample_id = nd.sample_id AND es."Experiment_Nr" = nd."Experiment_Nr"
LEFT JOIN "Reference"."Status" nd_status ON nd.status_id = nd_status.status_id
LEFT JOIN "Lab"."Qubit" qu ON s.sample_id = qu.sample_id AND es."Experiment_Nr" = qu."Experiment_Nr"
LEFT JOIN "Reference"."Status" qu_status ON qu.status_id = qu_status.status_id
LEFT JOIN "Lab"."Tapestation" tape ON s.sample_id = tape.sample_id AND es."Experiment_Nr" = tape."Experiment_Nr"
LEFT JOIN "Reference"."Status" tape_status ON tape.status_id = tape_status.status_id
LEFT JOIN "Lab"."PCR" pcr ON s.sample_id = pcr.sample_id AND es."Experiment_Nr" = pcr."Experiment_Nr"
LEFT JOIN "Reference"."Status" pcr_status ON pcr.status_id = pcr_status.status_id
LEFT JOIN "Reference"."Genes" ref_genes ON pcr.gene_id = ref_genes.primer_id
LEFT JOIN "Lab"."qPCR" qpcr ON s.sample_id = qpcr.sample_id AND es."Experiment_Nr" = qpcr."Experiment_Nr"
LEFT JOIN "Reference"."Status" qpcr_status ON qpcr.status_id = qpcr_status.status_id
LEFT JOIN "Reference"."Genes" ref_genes_qpcr ON qpcr.gene_id = ref_genes_qpcr.primer_id
LEFT JOIN "Lab"."Library" lib ON s.sample_id = lib.sample_id AND es."Experiment_Nr" = lib."Experiment_Nr"
LEFT JOIN "Lab"."Sequencing" seq ON s.sample_id = seq.sample_id AND es."Experiment_Nr" = seq."Experiment_Nr"
LEFT JOIN "Reference"."Status" seq_status ON seq.status_id = seq_status.status_id
LEFT JOIN "Lab"."Bioinformatics" bio ON s.sample_id = bio.sample_id AND es."Experiment_Nr" = bio."Experiment_Nr"
LEFT JOIN "Reference"."Status" bio_status ON bio.status_id = bio_status.status_id; -- ADDED this missing JOIN!




-- ===================================================================================
-- =============================================
-- Test Dataset Insertion Script
-- =============================================
-- This script populates the database with realistic test data.
-- It follows the logical order required by foreign key constraints.

-- =============================================
-- 1. Populate Reference Schema
-- =============================================

-- Insert Statuses (if not already present)
INSERT INTO "Reference"."Status" (status_id, "Description") VALUES
('Planned', 'The item is planned but not yet active.'),
('Active', 'The item is currently active or in progress.'),
('Completed', 'The item has been completed successfully.'),
('On Hold', 'The item is temporarily on hold.'),
('Cancelled', 'The item has been cancelled.'),
('Received', 'Sample has been received in the lab.'),
('Extracted', 'Sample has been extracted.'),
('Nanodrop QC', 'Sample quality checked with Nanodrop.'),
('Qubit QC', 'Sample quality checked with Qubit.'),
('Tapestation QC', 'Sample quality checked with Tapestation.'),
('PCR Done', 'PCR has been performed on the sample.'),
('qPCR Done', 'qPCR has been performed on the sample.'),
('Library Prep', 'Sequencing library has been prepared.'),
('Sequencing Done', 'Sample has been sequenced.'),
('Bioinformatics Done', 'Bioinformatics analysis is complete.'),
('Unknown Step', 'An unknown step has occurred in the workflow.')
ON CONFLICT (status_id) DO NOTHING;

-- Insert Rooms
INSERT INTO "Reference"."Room" (room_id, etage, address, description) VALUES
('2.37', '2', 'TIFI- 27572 Bremerhaven', 'Chemical Reception '),
('2.38', '2', 'TIFI- 27572 Bremerhaven', 'Extraction'),
('2.39', '2', 'TIFI- 27572 Bremerhaven', 'Bio-Storage Freezers'),
('2.40', '2', 'TIFI- 27572 Bremerhaven', 'Multi-media'),
('2.41', '2', 'TIFI- 27572 Bremerhaven', 'Post-PCR Gel'),
('2.42', '2', 'TIFI- 27572 Bremerhaven', 'Storage'),
('2.43', '2', 'TIFI- 27572 Bremerhaven', 'Post-PCR'),
('2.47', '2', 'TIFI- 27572 Bremerhaven', 'Pre-PCR eDNA')
ON CONFLICT (room_id) DO NOTHING;

-- Insert Genes
INSERT INTO "Reference"."Genes" ("TargetGene", "Primer_Sequence_Fwd", "Primer_Sequence_Rev", "probe", "primer_id", "description", "Reference") VALUES
('12S_MiFish_U', 'GTCGGTAAAACTCGTGCCAGC', 'CATAGTGGGGTATCTAATCCCAGTTTG', 'N/A', 'MiFish-U', 'Universal primer for fish metabarcoding', 'Miya et al. 2015'),
('COI_FishF1', 'TCAACCAACCACAAAGACATTGGCAC', 'TAGACTTCTGGGTGGCCAAAGAATCA', 'N/A', 'COI-F1', 'Standard Fish COI Barcode', 'Ward et al. 2005'),
('16S_V4', 'GTGCCAGCMGCCGCGGTAA', 'GGACTACHVGGGTWTCTAAT', 'N/A', '16S-V4', 'Bacterial 16S V4 region', 'Caporaso et al. 2011')
ON CONFLICT (primer_id) DO NOTHING;

-- Insert Locations
INSERT INTO "Reference"."Location" ("place", "place_id", "country", "category", "Notes") VALUES
('Baden-Württemberg', 'BW', 'Germany', 'State', NULL),
('Bayern', 'BY', 'Germany', 'State', NULL),
('Berlin', 'BE', 'Germany', 'State', NULL),
('Brandenburg', 'BB', 'Germany', 'State', NULL),
('Bremen', 'HB', 'Germany', 'State', NULL),
('Hamburg', 'HH', 'Germany', 'State', NULL),
('Hessen', 'HE', 'Germany', 'State', NULL),
('Niedersachsen', 'NI', 'Germany', 'State', NULL),
('Mecklenburg-Vorpommern', 'MV', 'Germany', 'State', NULL),
('Nordrhein-Westfalen', 'NW', 'Germany', 'State', NULL),
('Rheinland-Pfalz', 'RP', 'Germany', 'State', NULL),
('Saarland', 'SL', 'Germany', 'State', NULL),
('Sachsen', 'SN', 'Germany', 'State', NULL),
('Sachsen-Anhalt', 'ST', 'Germany', 'State', NULL),
('Schleswig-Holstein', 'SH', 'Germany', 'State', NULL),
('Thüringen', 'TH', 'Germany', 'State', NULL),
('Austria', 'iAT', 'Austria', 'Country', NULL),
('Belgium', 'iBE', 'Belgium', 'Country', NULL),
('Bulgaria', 'iBG', 'Bulgaria', 'Country', NULL),
('Croatia', 'iHR', 'Croatia', 'Country', NULL),
('Cyprus', 'iCY', 'Cyprus', 'Country', NULL),
('Czech Republic', 'iCZ', 'Czech Republic', 'Country', NULL),
('Denmark', 'iDK', 'Denmark', 'Country', NULL),
('Estonia', 'iEE', 'Estonia', 'Country', NULL),
('Finland', 'iFI', 'Finland', 'Country', NULL),
('France', 'iFR', 'France', 'Country', NULL),
('Germany', 'iDE', 'Germany', 'Country', NULL),
('Greece', 'iGR', 'Greece', 'Country', NULL),
('Hungary', 'iHU', 'Hungary', 'Country', NULL),
('Ireland', 'iIE', 'Ireland', 'Country', NULL),
('Italy', 'iIT', 'Italy', 'Country', NULL),
('Latvia', 'iLV', 'Latvia', 'Country', NULL),
('Lithuania', 'iLT', 'Lithuania', 'Country', NULL),
('Luxembourg', 'iLU', 'Luxembourg', 'Country', NULL),
('Malta', 'iMT', 'Malta', 'Country', NULL),
('Netherlands', 'iNL', 'Netherlands', 'Country', NULL),
('Poland', 'iPL', 'Poland', 'Country', NULL),
('Portugal', 'iPT', 'Portugal', 'Country', NULL),
('Romania', 'iRO', 'Romania', 'Country', NULL),
('Slovakia', 'iSK', 'Slovakia', 'Country', NULL),
('Slovenia', 'iSI', 'Slovenia', 'Country', NULL),
('Spain', 'iES', 'Spain', 'Country', NULL),
('Sweden', 'iSE', 'Sweden', 'Country', NULL)
ON CONFLICT ("place") DO NOTHING;

-- Insert Sample Types
INSERT INTO "Reference"."SamplesType" (sample_type, "sample_typeAbrv", description) VALUES
('Fish', 'F', 'Whole fish sample'),
('Tissue', 'T', 'Tissue sample, e.g., fin clip or muscle'),
('DNA', 'D', 'Extracted DNA'),
('RNA', 'R', 'Extracted RNA'),
('Water', 'W', 'Water sample, typically for eDNA'),
('Sediment', 'S', 'Sediment core or grab sample'),
('PCR', 'P', 'P'),
('Library', 'L', 'Sequencing Library')
ON CONFLICT (sample_type) DO NOTHING;

-- Insert Species
INSERT INTO "Reference"."Species" ("Species", "Genus", "Order", "Family", "DE_name", "En_name") VALUES
('Gadus morhua', 'Gadus', 'Gadiformes', 'Gadidae', 'Kabeljau', 'Atlantic Cod'),
('Clupea harengus', 'Clupea', 'Clupeiformes', 'Clupeidae', 'Hering', 'Atlantic Herring'),
('Pleuronectes platessa', 'Pleuronectes', 'Pleuronectiformes', 'Pleuronectidae', 'Scholle', 'European Plaice'),
('Pecten maximus', 'Pecten', 'Pectinida', 'Pectinidae', 'Große Pilgermuschel', 'Great Scallop'),
('Anguilla anguilla', 'Anguilla', 'Anguilliformes', 'Anguillidae', 'Europäischer Aal', 'European Eel'),
('Salmo salar', 'Salmo', 'Salmoniformes', 'Salmonidae', 'Atlantischer Lachs', 'Atlantic Salmon'),
('Alosa alosa', 'Alosa', 'Clupeiformes', 'Clupeidae', 'Maifisch', 'Allis Shad'),
('Alosa fallax', 'Alosa', 'Clupeiformes', 'Clupeidae', 'Finte', 'Twaite Shad'),
('Petromyzon marinus', 'Petromyzon', 'Petromyzontiformes', 'Petromyzontidae', 'Meerneunauge', 'Sea Lamprey'),
('Lampetra fluviatilis', 'Lampetra', 'Petromyzontiformes', 'Petromyzontidae', 'Flussneunauge', 'River Lamprey'),
('Salmo trutta', 'Salmo', 'Salmoniformes', 'Salmonidae', 'Meerforelle', 'Sea Trout'),
('Coregonus oxyrinchus', 'Coregonus', 'Salmoniformes', 'Salmonidae', 'Ostsee-Schnäpel', 'Baltic Whitefish'),  -- possibly extinct or reintroduced
('Coregonus maraena', 'Coregonus', 'Salmoniformes', 'Salmonidae', 'Maraene', 'Maraena Whitefish'),
('Platichthys flesus', 'Platichthys', 'Pleuronectiformes', 'Pleuronectidae', 'Flunder', 'European Flounder'), -- often semi-diadromous
('Chelon ramada', 'Chelon', 'Mugiliformes', 'Mugilidae', 'Dicklippiger Meeräschen', 'Thinlip Grey Mullet'),
('Liza aurata', 'Liza', 'Mugiliformes', 'Mugilidae', 'Goldlippige Meeräsche', 'Golden Grey Mullet'),
('Osmerus eperlanus', 'Osmerus', 'Osmeriformes', 'Osmeridae', 'Stint', 'European Smelt'),
('Acipenser sturio', 'Acipenser', 'Acipenseriformes', 'Acipenseridae', 'Europäischer Stör', 'European Sturgeon'),
('Acipenser oxyrinchus', 'Acipenser', 'Acipenseriformes', 'Acipenseridae', 'Atlantischer Stör', 'Atlantic Sturgeon')  -- reintroduced
ON CONFLICT ("Species") DO NOTHING;

-- Insert Categories for Orders/Reagents
INSERT INTO "Reference"."Category" (category, description) VALUES
('Consumables', 'General lab consumables like tips, tubes, gloves'),
('Primers', 'Chemicals and enzymes'),
('Kits', 'Pre-packaged kits for extraction, PCR, etc.'),
('Chemical', 'Chemicals and enzymes'),
('Enzyme', 'Chemicals and enzymes'),
('Polymerase', 'Chemicals and enzymes'),
('Sequencing', 'Reagents and services for sequencing'),
('Hardware', 'Computers and lab equipment')
ON CONFLICT ("category") DO NOTHING;

-- Insert Personnel
INSERT INTO "Reference"."Personal" (person, person_id, description) VALUES
('Reinhold Hanel','reinhold', 'PI'),
('Peggy','peggy', 'PI'),
('Lasse','lasse', 'PI'),
('Marko','reinhold', 'PI'),
('Timo','timo', 'researcher'),
('Yassine','yassine', 'researcher'),
('Janine', 'janine', 'TA'),
('Benita', 'benita', 'TA'),
('Ulrike', 'ultrike', 'TA'),
('Tina','tina', 'Technical Assistant')
ON CONFLICT ("person_id") DO NOTHING;


-- =============================================
-- 2. Populate LIMS Schema
-- =============================================
-- Insert a Project

INSERT INTO "Lims"."Projects" (project_id, "Title", status_id, "PI", "Funder", "Start_date", "End_date") VALUES
('wanderfische', 'eDNA Monitoring of Fish Migration', 'Active', 'reinhold', 'EMFAF', '2024-06-01', '2027-12-31')
ON CONFLICT ("project_id") DO NOTHING;

-- Assign People to the Project
INSERT INTO "Lims"."ProjectPersons" (project_id, person_id, role) VALUES
('wanderfische', 'reinhold', 'PI'),
('wanderfische', 'yassine', 'Researcher'),
('wanderfische', 'janine', 'TA'),
('wanderfische', 'tina', 'TA')
ON CONFLICT ("project_id", "person_id") DO NOTHING;

-- Insert Equipment
INSERT INTO "Lims"."Equipment" ("equipment_id", "equipment", room_id, "Mobility") VALUES
('qPCR', 'qPCR', '2.43', 'Stationary'),
('PCR_BioRad', 'Bio-Rad CFX96', '2.43', 'Stationary'),
('Freezer38.01', 'Thermo Scientific ULT Freezer', '2.38', 'Stationary'),
('Freezer38.02', 'Thermo Scientific ULT Freezer', '2.38', 'Stationary'),
('Freezer38.03', 'Thermo Scientific ULT Freezer', '2.38', 'Stationary')
ON CONFLICT ("equipment_id") DO NOTHING;

-- Insert an Order
INSERT INTO "Lims"."orders" (item, "category", "Date", "price", "Quantity", "project_id", "Company", "status_id") VALUES
('QIAGEN DNeasy Blood & Tissue Kit', 'Kits', '2025-02-15', 250.75, '1', 'wanderfische', 'QIAGEN GmbH', 'Completed')
ON CONFLICT ("FI_Order_Nr") DO NOTHING;

-- =============================================
-- 3. Populate Lab Setup Tables
-- =============================================
-- Insert Storage Locations
INSERT INTO "Lab"."Storage" ("storage_id", "room_id", "Freezer", "Temperature", "TemperatureUnit", "Box") VALUES
('F01e1B01', '2.38', 'Freezer38.01', -80, 'C', 'Box 01 - Fish Samples'),
('F01e1B02', '2.38', 'Freezer38.01', -80, 'C', 'Box 02 - Water Filters'),
('F01e1B03', '2.38', 'Freezer38.01', -20, 'C', 'Box 05 - DNA Extracts')
ON CONFLICT ("storage_id") DO NOTHING











-- =====================================
ALTER TABLE "Lab"."Samples"
ADD COLUMN IF NOT EXISTS "workflow_id" INTEGER REFERENCES "Lims"."Workflows"("Workflow_id");

-- Optional: If you want to drop and re-create existing triggers for Lab.Samples to handle the new column during initial insert or updates,
-- though typically ALTER TABLE ADD COLUMN does not require this for existing triggers,
-- it's good practice to consider if the trigger logic needs to change.
-- In your case, the existing copy_to_samples and update_central_samples functions use JSONB, so they should adapt automatically,
-- but the new column won't be populated by them unless you explicitly add it to the INSERT/UPDATE lists.

-- To populate workflow_id during insertion into Lab.Samples from source tables:
-- You would need to modify the "Lab".copy_to_samples() function.
-- However, since "Lab"."Fish", "Lab"."Tissue", etc., don't currently have a "workflow_id" column,
-- you'd either need to add it to all those tables as well OR have the user
-- explicitly assign the workflow_id to the sample after it's created.
-- For simplicity and consistency with your existing schema,
-- I would suggest populating workflow_id in Lab.Samples via an UPDATE
-- after the sample is created, or manually during initial data entry
-- in cases where a sample is directly inserted into Lab.Samples.

-- If you want to associate a sample with a workflow *at the time of its creation in the source tables*,
-- you would need to add 'workflow_id' to `Lab.Fish`, `Lab.Tissue`, `Lab.DNA`, etc., AND modify `copy_to_samples`.
-- Given your current setup, adding it only to Lab.Samples and managing it there seems more appropriate
-- as it's the central hub.






DROP VIEW IF EXISTS "Lab"."Samples_tracking" CASCADE;

CREATE OR REPLACE VIEW "Lab"."Samples_tracking" AS
SELECT
    -- Core Sample Info from Lab.Samples
    s.sample_id,
    s.project_id,
    p."Title" AS project_title,
    s.source_table,
    s.sample_type,
    st.description AS sample_type_description,
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
    s."Notes" AS sample_notes,
    s.workflow_status_id AS current_workflow_status,
    stat."Description" AS workflow_status_description,
    s.last_status_update,
    s.modified_by AS sample_modified_by, -- ADDED
    s.time_modification AS sample_time_modification, -- ADDED

    -- New Workflow Information from Lims.Workflows
    s.workflow_id,
    lwf."Workflow_name" AS assigned_workflow_name,
    lwf.decscription AS assigned_workflow_description,

    -- Specific sample attributes from Lab.Samples and joined tables
    s."Species" AS species_scientific_name,
    ref_sp."Genus" AS species_genus,
    ref_sp."Order" AS species_order,
    ref_sp."Family" AS species_family,
    ref_sp."DE_name" AS species_de_name,
    ref_sp."En_name" AS species_en_name,
    ref_sp."Length" AS species_avg_length,
    ref_sp.max_age AS species_max_age,
    s."Length" AS sample_length,
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
    samp."Ecosytem" AS sampling_ecosystem,
    loc."Region" AS location_name,
    loc."Region_id" AS location_region_id,
    loc.country AS location_country,
    loc.category AS location_category,
    loc."Notes" AS location_notes,
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
    samp.modified_by AS sampling_modified_by, -- ADDED
    samp.time_modification AS sampling_time_modification, -- ADDED

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
    exp."Notes" AS exp_notes,
    exp."LabBook" AS exp_labbook,
    exp.status_id AS exp_status_id,
    exp_status."Description" AS exp_status_description,
    exp."attachment" AS exp_attachment,
    exp.modified_by AS exp_modified_by, -- ADDED
    exp.time_modification AS exp_time_modification, -- ADDED

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
    ext."Notes" AS ext_notes,
    ext.status_id AS ext_status_id,
    ext_status."Description" AS ext_status_description,
    ext.modified_by AS ext_modified_by, -- ADDED
    ext.time_modification AS ext_time_modification, -- ADDED

    -- Nanodrop Results
    nd."Nanodrop_Concentration",
    nd."NanodropUnits",
    nd."Factor",
    nd."A260" AS nd_a260,
    nd."A260_280" AS nd_a260_280,
    nd."A260_230" AS nd_a260_230,
    nd."A260_230_note",
    nd."date" AS nd_date,
    nd."Elution_volume_ul" AS nd_elution_volume_ul,
    nd."Person" AS nd_person,
    nd."Notes" AS nd_notes,
    nd."status_id" AS nd_status_id,
    nd_status."Description" AS nd_status_description,
    nd."ResultDate" AS nd_result_date,
    nd."NanodropTotalDna_ug",
    nd.modified_by AS nd_modified_by, -- ADDED
    nd.time_modification AS nd_time_modification, -- ADDED

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
    qu."Notes" AS qu_notes,
    qu."status_id" AS qu_status_id,
    qu_status."Description" AS qu_status_description,
    qu."ResultDate" AS qu_result_date,
    qu."QubitTotalDna_ug",
    qu.modified_by AS qu_modified_by, -- ADDED
    qu.time_modification AS qu_time_modification, -- ADDED

    -- Tapestation Results
    tape."date" AS tape_date,
    tape.kit AS tape_kit,
    tape."Person" AS tape_person,
    tape."Notes" AS tape_notes,
    tape."Position" AS tape_position,
    tape.status_id AS tape_status_id,
    tape_status."Description" AS tape_status_description,
    tape."ResultDate" AS tape_result_date,
    tape.modified_by AS tape_modified_by, -- ADDED
    tape.time_modification AS tape_time_modification, -- ADDED

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
    pcr."Notes" AS pcr_notes,
    pcr.kit AS pcr_kit,
    pcr."Volume" AS pcr_volume,
    pcr.status_id AS pcr_status_id,
    pcr_status."Description" AS pcr_status_description,
    pcr.modified_by AS pcr_modified_by, -- ADDED
    pcr.time_modification AS pcr_time_modification, -- ADDED

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
    qpcr_status."Description" AS qpcr_status_description,
    qpcr."Notes" AS qpcr_notes,
    qpcr.modified_by AS qpcr_modified_by, -- ADDED
    qpcr.time_modification AS qpcr_time_modification, -- ADDED

    -- Library Prep Results
    lib."Library_id",
    lib."Date" AS library_date,
    lib."Person" AS library_person,
    lib."LibraryPrepKit",
    lib."IndexSequence",
    lib."ReadLength" AS library_read_length,
    lib."Notes" AS library_notes,
    lib."ResultDate" AS library_result_date,
    lib.modified_by AS lib_modified_by, -- ADDED
    lib.time_modification AS lib_time_modification, -- ADDED

    -- Sequencing Results
    seq.sequencing_id,
    seq."Date" AS seq_date,
    seq."Person" AS seq_person,
    seq."Sequencer",
    seq."FlowCellID",
    seq."LibraryPrepKit" AS seq_library_prep_kit,
    seq."IndexSequence" AS seq_index_sequence,
    seq."ReadLength" AS seq_read_length,
    seq."TotalReads",
    seq."RawDataPath",
    seq."status_id" AS seq_status_id,
    seq_status."Description" AS seq_status_description,
    seq."GenbankAccessionNumber",
    seq."ResultDate" AS seq_result_date,
    seq.modified_by AS seq_modified_by, -- ADDED
    seq.time_modification AS seq_time_modification, -- ADDED

    -- Bioinformatics Results
    bio.bioinfo_id,
    bio."Date" AS bio_date,
    bio."Person" AS bio_person,
    bio."PipelineName" AS bio_pipeline_name,
    bio."PipelineVersion",
    bio."ReferenceDatabase",
    bio."DatabaseVersion",
    bio."ClusteringThreshold",
    bio."FinalOutputPath",
    bio."Notes" AS bio_notes,
    bio."status_id" AS bio_status_id,
    bio_status."Description" AS bio_status_description,
    bio."ResultDate" AS bio_result_date,
    bio.modified_by AS bio_modified_by, -- ADDED
    bio.time_modification AS bio_time_modification -- ADDED

FROM "Lab"."Samples" s
LEFT JOIN "Lims"."Workflows" lwf ON s.workflow_id = lwf."Workflow_id" -- NEW JOIN
LEFT JOIN "Reference"."Status" stat ON s.workflow_status_id = stat.status_id
LEFT JOIN "Reference"."SamplesType" st ON s.sample_type = st.sample_type
LEFT JOIN "Reference"."Species" ref_sp ON s."Species" = ref_sp."Species"
LEFT JOIN "Reference"."Location" loc ON s."Region" = loc."Region"
LEFT JOIN "Lims"."Projects" p ON s.project_id = p.project_id
LEFT JOIN "Lab"."Storage" stor ON s.storage_id = stor.storage_id
LEFT JOIN "Reference"."Room" rr ON stor.room_id = rr.room_id
LEFT JOIN "Lab"."Sampling" samp ON s."Sampling_id" = samp."Sampling_id"
LEFT JOIN "Lab"."ExperimentSamples" es ON s.sample_id = es.sample_id
LEFT JOIN "Lab"."Experiments" exp ON es."Experiment_Nr" = exp."Experiment_Nr"
LEFT JOIN "Reference"."Status" exp_status ON exp.status_id = exp_status.status_id
LEFT JOIN "Lims"."SOP" sop ON exp.sop_id = sop.sop_id
LEFT JOIN "Reference"."Personal" ref_person_sop ON sop.author = ref_person_sop.person_id
LEFT JOIN "Lab"."Extraction" ext ON s.sample_id = ext.sample_id AND es."Experiment_Nr" = ext."Experiment_Nr"
LEFT JOIN "Reference"."Status" ext_status ON ext.status_id = ext_status.status_id
LEFT JOIN "Lab"."Nanodrop" nd ON s.sample_id = nd.sample_id AND es."Experiment_Nr" = nd."Experiment_Nr"
LEFT JOIN "Reference"."Status" nd_status ON nd.status_id = nd_status.status_id
LEFT JOIN "Lab"."Qubit" qu ON s.sample_id = qu.sample_id AND es."Experiment_Nr" = qu."Experiment_Nr"
LEFT JOIN "Reference"."Status" qu_status ON qu.status_id = qu_status.status_id
LEFT JOIN "Lab"."Tapestation" tape ON s.sample_id = tape.sample_id AND es."Experiment_Nr" = tape."Experiment_Nr"
LEFT JOIN "Reference"."Status" tape_status ON tape.status_id = tape_status.status_id
LEFT JOIN "Lab"."PCR" pcr ON s.sample_id = pcr.sample_id AND es."Experiment_Nr" = pcr."Experiment_Nr"
LEFT JOIN "Reference"."Status" pcr_status ON pcr.status_id = pcr_status.status_id
LEFT JOIN "Reference"."Genes" ref_genes ON pcr.gene_id = ref_genes.primer_id
LEFT JOIN "Lab"."qPCR" qpcr ON s.sample_id = qpcr.sample_id AND es."Experiment_Nr" = qpcr."Experiment_Nr"
LEFT JOIN "Reference"."Status" qpcr_status ON qpcr.status_id = qpcr_status.status_id
LEFT JOIN "Reference"."Genes" ref_genes_qpcr ON qpcr.gene_id = ref_genes_qpcr.primer_id
LEFT JOIN "Lab"."Library" lib ON s.sample_id = lib.sample_id AND es."Experiment_Nr" = lib."Experiment_Nr"
LEFT JOIN "Lab"."Sequencing" seq ON s.sample_id = seq.sample_id AND es."Experiment_Nr" = seq."Experiment_Nr"
LEFT JOIN "Reference"."Status" seq_status ON seq.status_id = seq_status.status_id
LEFT JOIN "Lab"."Bioinformatics" bio ON s.sample_id = bio.sample_id AND es."Experiment_Nr" = bio."Experiment_Nr"
LEFT JOIN "Reference"."Status" bio_status ON bio.status_id = bio_status.status_id;