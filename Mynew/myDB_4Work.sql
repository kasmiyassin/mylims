

-- ======================================================================
-- create schema

CREATE SCHEMA IF NOT EXISTS "Lab";
CREATE SCHEMA IF NOT EXISTS "Lims";
CREATE SCHEMA IF NOT EXISTS "reference";
CREATE SCHEMA IF NOT EXISTS "bioinformatics";

-- ======================================================================
-- create tables reference

CREATE TABLE IF NOT EXISTS "reference"."personal" (
    "person_id" text PRIMARY KEY, -- User to fill manually
    "Full Name" text,
    "room" text,
    "telephone" text,
    "mail" text,
    "password" TEXT NOT NULL,
    "description" text,
    "attachment" bytea,
    "modified_by" text REFERENCES "reference"."personal"("person_id"),
    "time_modification" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS "reference"."status" (
    "status_id" text PRIMARY KEY, -- to fill manually
    "description" text,
    "attachment" bytea,
    "modified_by" text REFERENCES "reference"."personal"("person_id"),
    "time_modification" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS "reference"."room" (
    "room_id" text PRIMARY KEY, -- to fill manually
    "etage" text,
    "address" text,
    "description" text,
    "attachment" bytea,
    "modified_by" text REFERENCES "reference"."personal"("person_id"),
    "time_modification" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS "reference"."vessel" (
    "vessel_id" text PRIMARY KEY, -- to fill manually
    "vessel name" text,
    "belong_to" text,
    "description" text,
    "attachment" bytea,
    "modified_by" text REFERENCES "reference"."personal"("person_id"),
    "time_modification" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS "reference"."region" (
    "region_id" text PRIMARY KEY, -- region name to fill manually
    "region_abrv" text UNIQUE NOT NULL,
    "country" text,
    "category" text,
    "description" text,
    "attachment" bytea,
    "modified_by" text REFERENCES "reference"."personal"("person_id"),
    "time_modification" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS "reference"."ecosystem" (
    "ecosystem_id" text PRIMARY KEY, -- ecosystem name to fill manually
    "ecosystem_abrv" text UNIQUE NOT NULL,
    "country" text,
    "category" text,
    "description" text,
    "attachment" bytea,
    "modified_by" text REFERENCES "reference"."personal"("person_id"),
    "time_modification" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS "reference"."category" (
    "category" text PRIMARY KEY, -- to fill  manually
    "description" text,
    "attachment" bytea,
    "modified_by" text REFERENCES "reference"."personal"("person_id"),
    "time_modification" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);


CREATE TABLE IF NOT EXISTS "reference"."samplesType" (
    "sample_type" text PRIMARY KEY, -- to fill  manually
    "sample_typeAbrv" text UNIQUE NOT NULL,
    "description" text,
    "attachment" bytea,
    "modified_by" text REFERENCES "reference"."personal"("person_id"),
    "time_modification" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);


CREATE TABLE IF NOT EXISTS "reference"."gene" (
    "gene_id" text PRIMARY KEY, -- to fill  manually
    "description" text,
    "attachment" bytea,
    "modified_by" text REFERENCES "reference"."personal"("person_id"),
    "time_modification" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS "reference"."taxon" (
    "taxon_id" text PRIMARY KEY, -- to fill  manually
    "taxon_parent" text REFERENCES "reference"."taxon"("taxon_id"),
    "DE_name" text,
    "En_name" text,
    "rank" text,
    "description" text,
    "attachment" bytea,
    "modified_by" text REFERENCES "reference"."personal"("person_id"),
    "time_modification" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS "reference"."species" (
    "species" text PRIMARY KEY REFERENCES "reference"."taxon"("taxon_id"), -- to fill  manually
    "DE_name" text,
    "En_name" text,
    "maxlength" numeric,
    "max_age" numeric,
    "description" text,
    "attachment" bytea,
    "modified_by" text REFERENCES "reference"."personal"("person_id"),
    "time_modification" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ======================================================================
-- Tables Lims
-- ======================================================================
-- Table Lims.customers

CREATE TABLE IF NOT EXISTS "Lims"."customers" (
    "customer_id" text PRIMARY KEY, -- automatically K000000
    "customer_name" text NOT NULL,
    "customer_abrv" text UNIQUE NOT NULL,
    "address" text NOT NULL,
    "mail" text NOT NULL,
    "phone" text NOT NULL,
    "description" text,
    "attachment" bytea,
    "modified_by" text REFERENCES "reference"."personal"("person_id"),
    "time_modification" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ======================================================================
-- ID Generation for Lims.customers
-- The sequence must be created BEFORE the function that uses it.

-- 1. Sequence for customer_id
DROP SEQUENCE IF EXISTS "Lims".customer_id_seq;
CREATE SEQUENCE IF NOT EXISTS "Lims".customer_id_seq START 1;

-- 2. Trigger function to generate the customer_id from the sequence
CREATE OR REPLACE FUNCTION "Lims".generate_customer_id()
RETURNS TRIGGER AS $$
BEGIN
    -- Concatenate 'K' with a 6-digit, zero-padded number from the sequence
    NEW.customer_id := 'K' || LPAD(NEXTVAL('"Lims".customer_id_seq')::TEXT, 6, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. Trigger that executes the function before an insert
DROP TRIGGER IF EXISTS trg_generate_customer_id ON "Lims"."customers";
CREATE TRIGGER trg_generate_customer_id
BEFORE INSERT ON "Lims"."customers"
FOR EACH ROW
EXECUTE FUNCTION "Lims".generate_customer_id();

-- ======================================================================

-- ============================

CREATE TABLE IF NOT EXISTS "Lims"."projects" (
    "project_id" text PRIMARY KEY, -- to fill manually
    "Title" text,
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "PI" text REFERENCES "reference"."personal"("person_id"),
    "Funder" text,
    "customer_id" text REFERENCES "Lims"."customers"("customer_id"),
    "Start_date" date,
    "End_date" date,
    "Report_date" date,
    "description" text,
    "attachment" bytea,
    "modified_by" text REFERENCES "reference"."personal"("person_id"),
    "time_modification" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS "Lims"."projectpersons" (
    "project_id" TEXT REFERENCES "Lims"."projects"("project_id") ON DELETE CASCADE, -- to fill manually
    "person_id" TEXT REFERENCES "reference"."personal"("person_id") ON DELETE CASCADE, -- to fill manually
    "role" TEXT,
    PRIMARY KEY ("project_id", "person_id"),
    "description" TEXT,
    "attachment" bytea,
    "modified_by" text REFERENCES "reference"."personal"("person_id"),
    "time_modification" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS "Lims"."cruises" (
    "cruise_id" TEXT PRIMARY KEY, -- to fill manually
    "project_id" TEXT NOT NULL REFERENCES "Lims"."projects"("project_id") ON DELETE CASCADE,
    "vessel_id" text REFERENCES "reference"."vessel"("vessel_id"),
    "status_id" text REFERENCES "reference"."status"("status_id") DEFAULT 'Received' NOT NULL,
    "region_id" text REFERENCES "reference"."region"("region_id"),
    "ecosystem_id" text REFERENCES "reference"."ecosystem"("ecosystem_id"),
    "capitaine_name" TEXT NOT NULL,
    "chief_scientist" TEXT NOT NULL,
    "start_date" date,
    "end_date" date,
    "together_with" TEXT,
    "description" TEXT,
    "attachment" bytea,
    "modified_by" text REFERENCES "reference"."personal"("person_id"),
    "time_modification" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);


CREATE TABLE IF NOT EXISTS "Lims"."workflows" (
    "workflow_id" TEXT PRIMARY KEY, -- to fill manually
    "workflow_name" TEXT,
    "description" TEXT,
    "attachment" bytea,
    "modified_by" text REFERENCES "reference"."personal"("person_id"),
    "time_modification" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS "Lims"."permits" (
    "permit_id" text PRIMARY KEY, -- to fill manually
    "permit_number" text,
    "issuing_authority" text,
    "valid_from" date,
    "valid_to" date,
    "reference" TEXT,
    "description" text,
    "attachment" bytea,
    "modified_by" text REFERENCES "reference"."personal"("person_id"),
    "time_modification" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS "Lims"."Primers" (
    "primer_id" text PRIMARY KEY, -- to fill manually
    "TargetGene" text REFERENCES "reference"."gene"("gene_id"),
    "Primer_Sequence_Fwd" text,
    "Primer_Sequence_Rev" text,
    "probe" text,
    "reference" Text,
    "description" text,
    "attachment" bytea,
    "modified_by" text REFERENCES "reference"."personal"("person_id"),
    "time_modification" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);


CREATE TABLE IF NOT EXISTS "Lims"."sop" (
    "sop_id" text PRIMARY KEY, -- automatically SopId_Origin_vversionnumber
    "Title" text,
    "SopId_Origin" text NOT NULL,
    "version" text NOT NULL,
    "author" text REFERENCES "reference"."personal"("person_id"),
    "reviewer1" text REFERENCES "reference"."personal"("person_id"),
    "reviewer2" text REFERENCES "reference"."personal"("person_id"),
    "date_realise" date,
    "sop_protocol" text,
    "description" text,
    "attachment" bytea,
    "modified_by" text REFERENCES "reference"."personal"("person_id"),
    "time_modification" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Trigger function for sop_id generation
CREATE OR REPLACE FUNCTION "Lims".generate_sop_id()
RETURNS TRIGGER AS $$
BEGIN
    NEW.sop_id := NEW."SopId_Origin" || '_v' || REPLACE(NEW.version, '.', '');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for sop_id generation
DROP TRIGGER IF EXISTS trg_generate_sop_id ON "Lims"."sop";
CREATE TRIGGER trg_generate_sop_id
BEFORE INSERT ON "Lims"."sop"
FOR EACH ROW
EXECUTE FUNCTION "Lims".generate_sop_id();


CREATE TABLE IF NOT EXISTS "Lims"."workflow_steps" (
    "step_id" TEXT PRIMARY KEY, -- automatically workflow_id_step_number_step_name
    "workflow_id" TEXT NOT NULL REFERENCES "Lims"."workflows"("workflow_id") ON DELETE CASCADE,
    "step_number" integer NOT NULL,
    "step_name" TEXT NOT NULL,
    "sop_id" TEXT REFERENCES "Lims"."sop"("sop_id"),
    "workflow_status_id" text REFERENCES "reference"."status"("status_id") DEFAULT 'Received' NOT NULL,
    "description" TEXT,
    "attachment" bytea,
    "modified_by" text REFERENCES "reference"."personal"("person_id"),
    "time_modification" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE ("workflow_id", "step_number")
);

-- Trigger function for workflow_steps_id generation
CREATE OR REPLACE FUNCTION "Lims".generate_workflow_step_id()
RETURNS TRIGGER AS $$
BEGIN
    NEW.step_id := NEW.workflow_id || '_' || NEW.step_number::TEXT || '_' || REPLACE(NEW.step_name, ' ', '_');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for workflow_steps_id generation
DROP TRIGGER IF EXISTS trg_generate_workflow_step_id ON "Lims"."workflow_steps";
CREATE TRIGGER trg_generate_workflow_step_id
BEFORE INSERT ON "Lims"."workflow_steps"
FOR EACH ROW
EXECUTE FUNCTION "Lims".generate_workflow_step_id();


CREATE TABLE IF NOT EXISTS "Lims"."Equipment" (
    "equipment_id" text PRIMARY KEY, -- to fill manually
    "equipment" text,
    "room_id" text REFERENCES "reference"."room"("room_id"),
    "lot" text,
    "Mobility" text,
    "dateManintenance" date,
    "description" text,
    "attachment" bytea,
    "modified_by" text REFERENCES "reference"."personal"("person_id"),
    "time_modification" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS "Lims"."orders" (
    "FI_Order_Nr" text PRIMARY KEY, -- to fill manually
    "item" text,
    "category" text REFERENCES "reference"."category"("category"),
    "date" date,
    "price" numeric,
    "quantity" text,
    "project_id" text REFERENCES "Lims"."projects"("project_id"),
    "company" text,
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "description" text,
    "attachment" bytea,
    "modified_by" text REFERENCES "reference"."personal"("person_id"),
    "time_modification" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);


CREATE TABLE IF NOT EXISTS "Lab"."storage" (
    "storage_id" text PRIMARY KEY, -- to fill manually
    "room_id" text REFERENCES "reference"."room"("room_id"),
    "Freezer" text,
    "Etage" text,
    "Temperature_C" numeric,
    "Box" text,
    "Box_size_X" numeric,
    "Box_size_Y" numeric,
    "project_id" text REFERENCES "Lims"."projects"("project_id"),
    "description" text,
    "attachment" bytea,
    "modified_by" text REFERENCES "reference"."personal"("person_id"),
    "time_modification" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);


CREATE TABLE IF NOT EXISTS "Lims"."Reagents" (
    "Reagents_id" text PRIMARY KEY, -- to fill manually
    "Reagent_CompleteName" text NOT NULL,
    "category" text REFERENCES "reference"."category"("category"),
    "Lot" text,
    "storage_id" text REFERENCES "Lab"."storage"("storage_id"),
    "storage_position" numeric,
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "Reception_date" date,
    "Expire_date" date,
    "order_id" TEXT REFERENCES "Lims"."orders"("FI_Order_Nr"),
    "project_id" text REFERENCES "Lims"."projects"("project_id"),
    "attachment" bytea,
    "description" text,
    "modified_by" text REFERENCES "reference"."personal"("person_id"),
    "time_modification" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ======================================================================
-- create tables Wet Lab


CREATE TABLE IF NOT EXISTS "Lab"."Experiments" (
    "Experiment_id" text PRIMARY KEY, -- to fill manually
    "Experiment_title" text,
    "aim" text,
    "Method" text,
    "sop_id" text REFERENCES "Lims"."sop"("sop_id"),
    "date" date,
    "person" text REFERENCES "reference"."personal"("person_id"),
    "description" text,
    "LabBook" text,
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "attachment" bytea,
    "modified_by" text REFERENCES "reference"."personal"("person_id"),
    "time_modification" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS "Lab"."ExperimentsProjects" (
    "ExperimentsProjects_id" serial PRIMARY KEY,
    "Experiment_id" text REFERENCES "Lab"."Experiments"("Experiment_id"),
    "project_id" text REFERENCES "Lims"."projects"("project_id"),
    "date" date,
    "description" text,
    "attachment" bytea,
    "modified_by" text REFERENCES "reference"."personal"("person_id"),
    "time_modification" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS "Lims"."protocols" (
    "nr" serial PRIMARY KEY,
    "Experiments_Nr" TEXT REFERENCES "Lab"."Experiments"("Experiment_id"),
    "protocol" TEXT,
    "run" TEXT,
    "description" TEXT
);

CREATE TABLE IF NOT EXISTS "Lab"."sampling" (
    "sampling_id" TEXT PRIMARY KEY,  -- 25WeHB0000 YYEcosystemabrvREGIONabrv0000
    "Experiment_id" TEXT REFERENCES "Lab"."Experiments"("Experiment_id"),
    "project_id" TEXT NOT NULL REFERENCES "Lims"."projects"("project_id") ON DELETE CASCADE,
    "cruise_id" TEXT REFERENCES "Lims"."cruises"("cruise_id"),
    "region_id" TEXT REFERENCES "reference"."region"("region_id"),
    "ecosystem_id" TEXT REFERENCES "reference"."ecosystem"("ecosystem_id"),
    "vessel_id" TEXT REFERENCES "reference"."vessel"("vessel_id"),
    "kunden_id" TEXT REFERENCES "Lims"."customers"("customer_id"),
    "sampling_date" DATE,
    "LonLat_Postgis_Lat" NUMERIC,
    "LonLat_Postgis_Lon" NUMERIC,
    "Depth_m" NUMERIC,
    "Location" TEXT,
    "start_at" date,
    "end_at" date,
    "Temperature_Atmospheric_c" NUMERIC,
    "Weather" TEXT,
    "Wind" TEXT,
    "WindUnit" TEXT,
    "TemperaturesamplingDepth_c" NUMERIC,
    "Salinity" NUMERIC,
    "SalinityUnit" TEXT,
    "Pressure" NUMERIC,
    "PressureUnit" TEXT,
    "Oxygen" NUMERIC,
    "OxygenUnit" TEXT,
    "Conducitivity" NUMERIC,
    "ConductivityUnit" TEXT,
    "pH" NUMERIC,
    "Nitrate_mgL" NUMERIC,
    "Phosphate_mgL" NUMERIC,
    "Turbidity_NTU" NUMERIC,
    "Chlorophyll_a_ugL" NUMERIC,
    "CurrentSpeed_m_s" NUMERIC,
    "CurrentDirection_deg" NUMERIC,
    "TideStage" TEXT,
    "Light_PAR_umol_m2_s" NUMERIC,
    "SeaState" TEXT,
    "sampleVolume_L" NUMERIC,
    "sampleType" TEXT,
    "Preservative" TEXT,
    "CloudCoverPercent" NUMERIC,
    "Rainfall_mm" NUMERIC,
    "InstrumentID" TEXT,
    "CalibrationDate" DATE,
    "Visibility_m" NUMERIC,
    "fishing_date" DATE,
    "fishing_time_min" TIME,
    "fishing_method" TEXT,
    "GearType" TEXT,
    "SoakTime" NUMERIC,
    "SoakTimeUnit" TEXT,
    "TrawlSpeed" NUMERIC,
    "TrawlSpeedUnit" TEXT,
    "Total_catch_quantity_kg" NUMERIC,
    "Total_catch_quantity_fish" NUMERIC,
    "catch_notes" TEXT,
    "Operation_duration_min" NUMERIC,
    "fishingStart_location" NUMERIC,
    "fishingEnd_location" NUMERIC,
    "sampler" text REFERENCES "reference"."personal"("person_id"),
    "Together_With" TEXT,
    "status_id" TEXT REFERENCES "reference"."status"("status_id") DEFAULT 'Received' NOT NULL,
    "customer_id" text REFERENCES "Lims"."customers"("customer_id"),
    "description" TEXT,
    "attachment" BYTEA,
    "modified_by" text REFERENCES "reference"."personal"("person_id"),
    "time_modification" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Removed the global sequence for sampling_id
DROP SEQUENCE IF EXISTS "Lab".sampling_serial_seq;

-- Trigger function for sampling_id generation with partitioned serial number
CREATE OR REPLACE FUNCTION "Lab".generate_sampling_id()
RETURNS TRIGGER AS $$
DECLARE
    sampling_year TEXT;
    ecosystem_abrv TEXT := '-';
    region_abrv TEXT := '-';
    customer_abrv TEXT := '-';
    id_prefix TEXT;
    next_serial INTEGER;
BEGIN
    -- Determine sampling year or reception year
    IF NEW.sampling_date IS NOT NULL THEN
        sampling_year := TO_CHAR(NEW.sampling_date, 'YY');
    ELSE
        sampling_year := TO_CHAR(CURRENT_DATE, 'YY'); -- Fallback to current year if no sampling or reception date
    END IF;

    -- Get ecosystem abbreviation
    SELECT COALESCE(e.ecosystem_abrv, '-') INTO ecosystem_abrv
    FROM "reference"."ecosystem" e
    WHERE e.ecosystem_id = NEW.ecosystem_id;

    -- Get region abbreviation
    SELECT COALESCE(r.region_abrv, '-') INTO region_abrv
    FROM "reference"."region" r
    WHERE r.region_id = NEW.region_id;

    -- If both ecosystem and region are missing, use customer abbreviation
    IF ecosystem_abrv = '-' AND region_abrv = '-' THEN
        SELECT COALESCE(c.customer_abrv, '-') INTO customer_abrv
        FROM "Lims"."customers" c
        WHERE c.customer_id = NEW.customer_id;
        id_prefix := sampling_year || customer_abrv;
    ELSE
        id_prefix := sampling_year || ecosystem_abrv || region_abrv;
    END IF;

    -- Find the maximum existing serial number for this prefix
    SELECT MAX(SUBSTRING("sampling_id" FROM LENGTH(id_prefix) + 1)::INTEGER)
    INTO next_serial
    FROM "Lab"."sampling"
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

-- Trigger for sampling_id generation
DROP TRIGGER IF EXISTS trg_generate_sampling_id ON "Lab"."sampling";
CREATE TRIGGER trg_generate_sampling_id
BEFORE INSERT ON "Lab"."sampling"
FOR EACH ROW
EXECUTE FUNCTION "Lab".generate_sampling_id();


CREATE TABLE IF NOT EXISTS "Lab"."fishing" (
    "fishing_id" text PRIMARY KEY, -- SamplingID_0000
    "sampling_id" TEXT NOT NULL REFERENCES "Lab"."sampling"("sampling_id") ON DELETE CASCADE,
    "taxon" text REFERENCES "reference"."taxon"("taxon_id"),
    "catch_kg" numeric,
    "catch_fish" numeric,
    "customer_id" text REFERENCES "Lims"."customers"("customer_id"),
    "description" text,
    "attachment" bytea,
    "modified_by" text REFERENCES "reference"."personal"("person_id"),
    "time_modification" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Sequence for fishing_id serial number
CREATE SEQUENCE IF NOT EXISTS "Lab".fishing_serial_seq START 1;

-- Trigger function for fishing_id generation
CREATE OR REPLACE FUNCTION "Lab".generate_fishing_id()
RETURNS TRIGGER AS $$
BEGIN
    NEW.fishing_id := NEW.sampling_id || '_' || LPAD(NEXTVAL('Lab.fishing_serial_seq')::TEXT, 4, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for fishing_id generation
DROP TRIGGER IF EXISTS trg_generate_fishing_id ON "Lab"."fishing";
CREATE TRIGGER trg_generate_fishing_id
BEFORE INSERT ON "Lab"."fishing"
FOR EACH ROW
EXECUTE FUNCTION "Lab".generate_fishing_id();


CREATE TABLE IF NOT EXISTS "Lab"."samples" (
    "sample_id" text PRIMARY KEY, -- F25WeHB0000 SampleTypeAbrvYYEcosystemREGION0000
    "External_Name" text,
    "Parentsample_id" text REFERENCES "Lab"."samples"("sample_id"),
    "sampling_id" text REFERENCES "Lab"."sampling"("sampling_id"),
    "storage_id" text REFERENCES "Lab"."storage"("storage_id"),
    "storage_position" numeric,
    "sampler" text REFERENCES "reference"."personal"("person_id"),
    "Reciever" text REFERENCES "reference"."personal"("person_id"),
    "sampling_date" date,
    "Reception_date" date,
    "Transport" text,
    "Conservation/Buffer" text,
    "sample_type" text NOT NULL REFERENCES "reference"."samplesType"("sample_type"),
    "sample_status_id" text REFERENCES "reference"."status"("status_id") DEFAULT 'Received' NOT NULL,
    "workflow_name" TEXT REFERENCES "Lims"."workflows"("workflow_id"),
    "step_name" TEXT REFERENCES "Lims"."workflow_steps"("step_id"),
    "project_id" text REFERENCES "Lims"."projects"("project_id"),
    "customer_id" text REFERENCES "Lims"."customers"("customer_id"),
    "description" text,
    "attachment" bytea,
    "modified_by" text REFERENCES "reference"."personal"("person_id"),
    "time_modification" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Removed the global sequence for sample_id
DROP SEQUENCE IF EXISTS "Lab".sample_serial_seq;

-- Trigger function for sample_id generation with partitioned serial number
CREATE OR REPLACE FUNCTION "Lab".generate_sample_id()
RETURNS TRIGGER AS $$
DECLARE
    sample_type_abrv TEXT;
    sampling_year TEXT;
    ecosystem_abrv TEXT := '-';
    region_abrv TEXT := '-';
    customer_abrv TEXT := '-';
    id_prefix TEXT;
    next_serial INTEGER;
    temp_sampling_id_exists TEXT; -- To check if NEW.sampling_id exists
BEGIN
    -- Get sample type abbreviation
    SELECT st."sample_typeAbrv" INTO sample_type_abrv
    FROM "reference"."samplesType" st
    WHERE st."sample_type" = NEW.sample_type;

    -- Determine sampling year or reception year, defaulting to current year
    IF NEW.sampling_date IS NOT NULL THEN
        sampling_year := TO_CHAR(NEW.sampling_date, 'YY');
    ELSIF NEW.Reception_date IS NOT NULL THEN
        sampling_year := TO_CHAR(NEW.Reception_date, 'YY');
    ELSE
        sampling_year := TO_CHAR(CURRENT_DATE, 'YY'); -- Fallback to current year
    END IF;

    -- Try to get ecosystem and region from sampling_id if available and valid
    IF NEW.sampling_id IS NOT NULL THEN
        SELECT samp.sampling_id INTO temp_sampling_id_exists
        FROM "Lab"."sampling" samp
        WHERE samp.sampling_id = NEW.sampling_id;

        IF temp_sampling_id_exists IS NOT NULL THEN
            SELECT
                COALESCE(e.ecosystem_abrv, '-'),
                COALESCE(r.region_abrv, '-')
            INTO
                ecosystem_abrv,
                region_abrv
            FROM
                "Lab"."sampling" samp_inner
            LEFT JOIN
                "reference"."ecosystem" e ON samp_inner.ecosystem_id = e.ecosystem_id
            LEFT JOIN
                "reference"."region" r ON samp_inner.region_id = r.region_id
            WHERE
                samp_inner.sampling_id = NEW.sampling_id;
        ELSE
            RAISE WARNING 'Provided sampling_id % for new sample does not exist in "Lab"."sampling". Generating ID using customer or default abbreviations.', NEW.sampling_id;
            -- Fallback to customer_id or default if sampling_id is invalid
            IF NEW.customer_id IS NOT NULL THEN
                SELECT COALESCE(c.customer_abrv, '-') INTO customer_abrv
                FROM "Lims"."customers" c
                WHERE c.customer_id = NEW.customer_id;
            END IF;
        END IF;
    END IF;

    -- Construct the ID prefix based on available information
    IF ecosystem_abrv != '-' OR region_abrv != '-' THEN
        id_prefix := sample_type_abrv || sampling_year || ecosystem_abrv || region_abrv;
    ELSIF customer_abrv != '-' THEN
        id_prefix := sample_type_abrv || sampling_year || customer_abrv;
    ELSE
        -- Fallback if no specific geographical/customer info
        id_prefix := sample_type_abrv || sampling_year || '--'; -- Use '--' for missing geo/customer info
    END IF;

    -- Find the maximum existing serial number for this prefix
    SELECT MAX(SUBSTRING("sample_id" FROM LENGTH(id_prefix) + 1)::INTEGER)
    INTO next_serial
    FROM "Lab"."samples"
    WHERE "sample_id" ILIKE id_prefix || '%';

    IF next_serial IS NULL THEN
        next_serial := 1;
    ELSE
        next_serial := next_serial + 1;
    END IF;

    NEW.sample_id := id_prefix || LPAD(next_serial::TEXT, 4, '0');

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for sample_id generation
DROP TRIGGER IF EXISTS trg_generate_sample_id ON "Lab"."samples";
CREATE TRIGGER trg_generate_sample_id
BEFORE INSERT ON "Lab"."samples"
FOR EACH ROW
EXECUTE FUNCTION "Lab".generate_sample_id();


CREATE TABLE IF NOT EXISTS "Lab"."storage_log" (
    "log_id" serial PRIMARY KEY,
    "sample_id" text NOT NULL REFERENCES "Lab"."samples"("sample_id"),
    "storage_id" text NOT NULL REFERENCES "Lab"."storage"("storage_id"),
    "person_id" text REFERENCES "reference"."personal"("person_id"),
    "move_date" timestamptz DEFAULT CURRENT_TIMESTAMP,
    "status" text NOT NULL,
    "storage_position" numeric,
    "description" text,
    "modified_by" text REFERENCES "reference"."personal"("person_id"),
    "time_modification" timestamptz DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS "Lab"."fish" (
    "sample_id" text PRIMARY KEY, -- F25WeHB0000 or F25WeHB0000f1
    "Experiment_id" text REFERENCES "Lab"."Experiments"("Experiment_id"),
    "Parentsample_id" text NOT NULL REFERENCES "Lab"."samples"("sample_id"),
    "species" text NOT NULL REFERENCES "reference"."species"("species"),
    "total_length_mm" numeric,
    "fork_length_mm" numeric,
    "standard_length_mm" numeric,
    "weight_g" numeric,
    "Sex" text,
    "MaturityStage" text,
    "StomachContents" text,
    "DiseaseInfo" text,
    "TagID" text,
    "storage_id" text REFERENCES "Lab"."storage"("storage_id"),
    "storage_position" numeric,
    "sampler" text,
    "Reciever" text,
    "sampling_date" date,
    "Reception_date" date,
    "project_id" text REFERENCES "Lims"."projects"("project_id"),
    "customer_id" text REFERENCES "Lims"."customers"("customer_id"),
    "description" text,
    "attachment" bytea,
    "modified_by" text REFERENCES "reference"."personal"("person_id"),
    "time_modification" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Sequence for child sample serial number for Fish
DROP SEQUENCE IF EXISTS "Lab".fish_child_serial_seq;
CREATE SEQUENCE IF NOT EXISTS "Lab".fish_child_serial_seq START 1;

-- Trigger function for child sample_id generation for Fish
CREATE OR REPLACE FUNCTION "Lab".generate_fish_child_sample_id()
RETURNS TRIGGER AS $$
DECLARE
    parent_sample_id_exists TEXT;
    fish_abrv TEXT;
    current_count INTEGER;
    next_serial INTEGER;
    id_prefix TEXT;
BEGIN
    -- Check if Parentsample_id exists in Lab.samples
    SELECT sample_id INTO parent_sample_id_exists FROM "Lab"."samples" WHERE sample_id = NEW."Parentsample_id";
    IF parent_sample_id_exists IS NULL THEN
        RAISE EXCEPTION 'Parentsample_id % does not exist in "Lab"."samples" table.', NEW."Parentsample_id";
    END IF;

    -- Get sample_typeAbrv for 'Fish'
    SELECT "sample_typeAbrv" INTO fish_abrv FROM "reference"."samplesType" WHERE "sample_type" = 'Fish';

    id_prefix := NEW."Parentsample_id" || LOWER(fish_abrv);

    -- Find the maximum existing serial number for this prefix
    SELECT MAX(SUBSTRING("sample_id" FROM LENGTH(id_prefix) + 1)::INTEGER)
    INTO next_serial
    FROM "Lab"."fish"
    WHERE "sample_id" ILIKE id_prefix || '%';

    IF next_serial IS NULL THEN
        next_serial := 1;
    ELSE
        next_serial := next_serial + 1;
    END IF;

    NEW.sample_id := id_prefix || next_serial::TEXT;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for fish child sample_id generation
DROP TRIGGER IF EXISTS trg_generate_fish_child_sample_id ON "Lab"."fish";
CREATE TRIGGER trg_generate_fish_child_sample_id
BEFORE INSERT ON "Lab"."fish"
FOR EACH ROW
EXECUTE FUNCTION "Lab".generate_fish_child_sample_id();


CREATE TABLE IF NOT EXISTS "Lab"."Tissue" (
    "sample_id" text PRIMARY KEY, -- T25WeHB0000 or F25WeHB0000t1
    "Parentsample_id" text NOT NULL REFERENCES "Lab"."samples"("sample_id"),
    "Experiment_id" text REFERENCES "Lab"."Experiments"("Experiment_id"),
    "Weight_mg" numeric,
    "tissue_type" text,
    "preservation_method" text,
    "storage_id" text REFERENCES "Lab"."storage"("storage_id"),
    "storage_position" numeric,
    "sampler" text,
    "sampling_date" date,
    "project_id" text REFERENCES "Lims"."projects"("project_id"),
    "description" text,
    "attachment" bytea,
    "modified_by" text REFERENCES "reference"."personal"("person_id"),
    "time_modification" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Sequence for child sample serial number for Tissue
DROP SEQUENCE IF EXISTS "Lab".tissue_child_serial_seq;
CREATE SEQUENCE IF NOT EXISTS "Lab".tissue_child_serial_seq START 1;

-- Trigger function for child sample_id generation for Tissue
CREATE OR REPLACE FUNCTION "Lab".generate_tissue_child_sample_id()
RETURNS TRIGGER AS $$
DECLARE
    parent_sample_id_exists TEXT;
    tissue_abrv TEXT;
    current_count INTEGER;
    next_serial INTEGER;
    id_prefix TEXT;
BEGIN
    -- Check if Parentsample_id exists in Lab.samples
    SELECT sample_id INTO parent_sample_id_exists FROM "Lab"."samples" WHERE sample_id = NEW."Parentsample_id";
    IF parent_sample_id_exists IS NULL THEN
        RAISE EXCEPTION 'Parentsample_id % does not exist in "Lab"."samples" table.', NEW."Parentsample_id";
    END IF;

    -- Get sample_typeAbrv for 'Tissue'
    SELECT "sample_typeAbrv" INTO tissue_abrv FROM "reference"."samplesType" WHERE "sample_type" = 'Tissue';

    id_prefix := NEW."Parentsample_id" || LOWER(tissue_abrv);

    -- Find the maximum existing serial number for this prefix
    SELECT MAX(SUBSTRING("sample_id" FROM LENGTH(id_prefix) + 1)::INTEGER)
    INTO next_serial
    FROM "Lab"."Tissue"
    WHERE "sample_id" ILIKE id_prefix || '%';

    IF next_serial IS NULL THEN
        next_serial := 1;
    ELSE
        next_serial := next_serial + 1;
    END IF;

    NEW.sample_id := id_prefix || next_serial::TEXT;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for tissue child sample_id generation
DROP TRIGGER IF EXISTS trg_generate_tissue_child_sample_id ON "Lab"."Tissue";
CREATE TRIGGER trg_generate_tissue_child_sample_id
BEFORE INSERT ON "Lab"."Tissue"
FOR EACH ROW
EXECUTE FUNCTION "Lab".generate_tissue_child_sample_id();


CREATE TABLE IF NOT EXISTS "Lab"."Otoliths" (
    "sample_id" text NOT NULL REFERENCES "Lab"."samples"("sample_id"),
    "reader_id" text NOT NULL REFERENCES "reference"."personal"("person_id"),
    "side" text NOT NULL,
    "age_reading_years" numeric,
    "confidence" numeric,
    "reading_date" date,
    "project_id" text REFERENCES "Lims"."projects"("project_id"),
    "description" text,
    "attachment" bytea,
    "modified_by" text REFERENCES "reference"."personal"("person_id"),
    "time_modification" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY ("sample_id", "reader_id", "side")
);

CREATE TABLE IF NOT EXISTS "Lab"."DNA" (
    "sample_id" text PRIMARY KEY, -- D25WeHB0000 or F25WeHB0000d1
    "Parentsample_id" text NOT NULL REFERENCES "Lab"."samples"("sample_id"),
    "Experiment_id" text REFERENCES "Lab"."Experiments"("Experiment_id"),
    "Volume_uL" numeric,
    "Concentration_ngul" numeric,
    "A260/280" numeric,
    "A260/230" numeric,
    "ExtractionMethod" text,
    "preservation_method" text,
    "Extraction_date" date,
    "extraction_number" INTEGER,
    "sampler" text,
    "sampling_date" date,
    "storage_id" text REFERENCES "Lab"."storage"("storage_id"),
    "storage_position" numeric,
    "project_id" text REFERENCES "Lims"."projects"("project_id"),
    "description" text,
    "attachment" bytea,
    "modified_by" text REFERENCES "reference"."personal"("person_id"),
    "time_modification" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Sequence for child sample serial number for DNA
DROP SEQUENCE IF EXISTS "Lab".dna_child_serial_seq;
CREATE SEQUENCE IF NOT EXISTS "Lab".dna_child_serial_seq START 1;

-- Trigger function for child sample_id generation for DNA
CREATE OR REPLACE FUNCTION "Lab".generate_dna_child_sample_id()
RETURNS TRIGGER AS $$
DECLARE
    parent_sample_id_exists TEXT;
    dna_abrv TEXT;
    current_count INTEGER;
    next_serial INTEGER;
    id_prefix TEXT;
BEGIN
    -- Check if Parentsample_id exists in Lab.samples
    SELECT sample_id INTO parent_sample_id_exists FROM "Lab"."samples" WHERE sample_id = NEW."Parentsample_id";
    IF parent_sample_id_exists IS NULL THEN
        RAISE EXCEPTION 'Parentsample_id % does not exist in "Lab"."samples" table.', NEW."Parentsample_id";
    END IF;

    -- Get sample_typeAbrv for 'DNA'
    SELECT "sample_typeAbrv" INTO dna_abrv FROM "reference"."samplesType" WHERE "sample_type" = 'DNA';

    id_prefix := NEW."Parentsample_id" || LOWER(dna_abrv);

    -- Find the maximum existing serial number for this prefix
    SELECT MAX(SUBSTRING("sample_id" FROM LENGTH(id_prefix) + 1)::INTEGER)
    INTO next_serial
    FROM "Lab"."DNA"
    WHERE "sample_id" ILIKE id_prefix || '%';

    IF next_serial IS NULL THEN
        next_serial := 1;
    ELSE
        next_serial := next_serial + 1;
    END IF;

    NEW.sample_id := id_prefix || next_serial::TEXT;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for DNA child sample_id generation
DROP TRIGGER IF EXISTS trg_generate_dna_child_sample_id ON "Lab"."DNA";
CREATE TRIGGER trg_generate_dna_child_sample_id
BEFORE INSERT ON "Lab"."DNA"
FOR EACH ROW
EXECUTE FUNCTION "Lab".generate_dna_child_sample_id();


CREATE TABLE IF NOT EXISTS "Lab"."RNA" (
    "sample_id" text PRIMARY KEY, -- R25WeHB0000 or F25WeHB0000r1
    "Parentsample_id" text NOT NULL REFERENCES "Lab"."samples"("sample_id"),
    "Experiment_id" text REFERENCES "Lab"."Experiments"("Experiment_id"),
    "Volume_uL" numeric,
    "Concentration_ngul" numeric,
    "A260/280" numeric,
    "A260/230" numeric,
    "ExtractionMethod" text,
    "preservation_method" text,
    "Extraction_date" date,
    "extraction_number" INTEGER,
    "sampler" text,
    "sampling_date" date,
    "storage_id" text REFERENCES "Lab"."storage"("storage_id"),
    "storage_position" numeric,
    "project_id" text REFERENCES "Lims"."projects"("project_id"),
    "description" text,
    "attachment" bytea,
    "modified_by" text REFERENCES "reference"."personal"("person_id"),
    "time_modification" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Sequence for child sample serial number for RNA
DROP SEQUENCE IF EXISTS "Lab".rna_child_serial_seq;
CREATE SEQUENCE IF NOT EXISTS "Lab".rna_child_serial_seq START 1;

-- Trigger function for child sample_id generation for RNA
CREATE OR REPLACE FUNCTION "Lab".generate_rna_child_sample_id()
RETURNS TRIGGER AS $$
DECLARE
    parent_sample_id_exists TEXT;
    rna_abrv TEXT;
    current_count INTEGER;
    next_serial INTEGER;
    id_prefix TEXT;
BEGIN
    -- Check if Parentsample_id exists in Lab.samples
    SELECT sample_id INTO parent_sample_id_exists FROM "Lab"."samples" WHERE sample_id = NEW."Parentsample_id";
    IF parent_sample_id_exists IS NULL THEN
        RAISE EXCEPTION 'Parentsample_id % does not exist in "Lab"."samples" table.', NEW."Parentsample_id";
    END IF;

    -- Get sample_typeAbrv for 'RNA'
    SELECT "sample_typeAbrv" INTO rna_abrv FROM "reference"."samplesType" WHERE "sample_type" = 'RNA';

    id_prefix := NEW."Parentsample_id" || LOWER(rna_abrv);

    -- Find the maximum existing serial number for this prefix
    SELECT MAX(SUBSTRING("sample_id" FROM LENGTH(id_prefix) + 1)::INTEGER)
    INTO next_serial
    FROM "Lab"."RNA"
    WHERE "sample_id" ILIKE id_prefix || '%';

    IF next_serial IS NULL THEN
        next_serial := 1;
    ELSE
        next_serial := next_serial + 1;
    END IF;

    NEW.sample_id := id_prefix || next_serial::TEXT;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for RNA child sample_id generation
DROP TRIGGER IF EXISTS trg_generate_rna_child_sample_id ON "Lab"."RNA";
CREATE TRIGGER trg_generate_rna_child_sample_id
BEFORE INSERT ON "Lab"."RNA"
FOR EACH ROW
EXECUTE FUNCTION "Lab".generate_rna_child_sample_id();


CREATE TABLE IF NOT EXISTS "Lab"."Sediments" (
    "sample_id" text PRIMARY KEY, -- S25WeHB0000 or F25WeHB0000s1
    "Experiment_id" text REFERENCES "Lab"."Experiments"("Experiment_id"),
    "Parentsample_id" text NOT NULL REFERENCES "Lab"."samples"("sample_id"),
    "project_id" text REFERENCES "Lims"."projects"("project_id"),
    "Volume" numeric,
    "unity" text,
    "Depth" numeric,
    "sampling_Method" text,
    "ConservationBuffer" text,
    "sampler" text,
    "Reciever" text,
    "sampling_date" date,
    "Reception_date" date,
    "storage_id" text REFERENCES "Lab"."storage"("storage_id"),
    "storage_position" numeric,
    "External_Name" text,
    "description" text,
    "attachment" bytea,
    "modified_by" text REFERENCES "reference"."personal"("person_id"),
    "time_modification" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Sequence for child sample serial number for Sediments
DROP SEQUENCE IF EXISTS "Lab".sediments_child_serial_seq;
CREATE SEQUENCE IF NOT EXISTS "Lab".sediments_child_serial_seq START 1;

-- Trigger function for child sample_id generation for Sediments
CREATE OR REPLACE FUNCTION "Lab".generate_sediments_child_sample_id()
RETURNS TRIGGER AS $$
DECLARE
    parent_sample_id_exists TEXT;
    sediments_abrv TEXT;
    current_count INTEGER;
    next_serial INTEGER;
    id_prefix TEXT;
BEGIN
    -- Check if Parentsample_id exists in Lab.samples
    SELECT sample_id INTO parent_sample_id_exists FROM "Lab"."samples" WHERE sample_id = NEW."Parentsample_id";
    IF parent_sample_id_exists IS NULL THEN
        RAISE EXCEPTION 'Parentsample_id % does not exist in "Lab"."samples" table.', NEW."Parentsample_id";
    END IF;

    -- Get sample_typeAbrv for 'Sediments'
    SELECT "sample_typeAbrv" INTO sediments_abrv FROM "reference"."samplesType" WHERE "sample_type" = 'Sediments';

    id_prefix := NEW."Parentsample_id" || LOWER(sediments_abrv);

    -- Find the maximum existing serial number for this prefix
    SELECT MAX(SUBSTRING("sample_id" FROM LENGTH(id_prefix) + 1)::INTEGER)
    INTO next_serial
    FROM "Lab"."Sediments"
    WHERE "sample_id" ILIKE id_prefix || '%';

    IF next_serial IS NULL THEN
        next_serial := 1;
    ELSE
        next_serial := next_serial + 1;
    END IF;

    NEW.sample_id := id_prefix || next_serial::TEXT;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for sediments child sample_id generation
DROP TRIGGER IF EXISTS trg_generate_sediments_child_sample_id ON "Lab"."Sediments";
CREATE TRIGGER trg_generate_sediments_child_sample_id
BEFORE INSERT ON "Lab"."Sediments"
FOR EACH ROW
EXECUTE FUNCTION "Lab".generate_sediments_child_sample_id();


CREATE TABLE IF NOT EXISTS "Lab"."Water" (
    "sample_id" text PRIMARY KEY, -- W25WeHB0000 or F25WeHB0000w1
    "Parentsample_id" text NOT NULL REFERENCES "Lab"."samples"("sample_id"),
    "Experiment_id" text REFERENCES "Lab"."Experiments"("Experiment_id"),
    "VolumeL" numeric,
    "Filter" text,
    "FilterPoreSize" numeric,
    "Depth" numeric,
    "sampling_Method" text,
    "ConservationBuffer" text,
    "sampler" text,
    "Reciever" text,
    "sampling_date" date,
    "Reception_date" date,
    "storage_id" text REFERENCES "Lab"."storage"("storage_id"),
    "storage_position" numeric,
    "description" text,
    "project_id" text REFERENCES "Lims"."projects"("project_id"),
    "attachment" bytea,
    "modified_by" text REFERENCES "reference"."personal"("person_id"),
    "time_modification" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Sequence for child sample serial number for Water
DROP SEQUENCE IF EXISTS "Lab".water_child_serial_seq;
CREATE SEQUENCE IF NOT EXISTS "Lab".water_child_serial_seq START 1;

-- Trigger function for child sample_id generation for Water
CREATE OR REPLACE FUNCTION "Lab".generate_water_child_sample_id()
RETURNS TRIGGER AS $$
DECLARE
    parent_sample_id_exists TEXT;
    water_abrv TEXT;
    current_count INTEGER;
    next_serial INTEGER;
    id_prefix TEXT;
BEGIN
    -- Check if Parentsample_id exists in Lab.samples
    SELECT sample_id INTO parent_sample_id_exists FROM "Lab"."samples" WHERE sample_id = NEW."Parentsample_id";
    IF parent_sample_id_exists IS NULL THEN
        RAISE EXCEPTION 'Parentsample_id % does not exist in "Lab"."samples" table.', NEW."Parentsample_id";
    END IF;

    -- Get sample_typeAbrv for 'Water'
    SELECT "sample_typeAbrv" INTO water_abrv FROM "reference"."samplesType" WHERE "sample_type" = 'Water';

    id_prefix := NEW."Parentsample_id" || LOWER(water_abrv);

    -- Find the maximum existing serial number for this prefix
    SELECT MAX(SUBSTRING("sample_id" FROM LENGTH(id_prefix) + 1)::INTEGER)
    INTO next_serial
    FROM "Lab"."Water"
    WHERE "sample_id" ILIKE id_prefix || '%';

    IF next_serial IS NULL THEN
        next_serial := 1;
    ELSE
        next_serial := next_serial + 1;
    END IF;

    NEW.sample_id := id_prefix || next_serial::TEXT;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for water child sample_id generation
DROP TRIGGER IF EXISTS trg_generate_water_child_sample_id ON "Lab"."Water";
CREATE TRIGGER trg_generate_water_child_sample_id
BEFORE INSERT ON "Lab"."Water"
FOR EACH ROW
EXECUTE FUNCTION "Lab".generate_water_child_sample_id();


CREATE TABLE IF NOT EXISTS "Lab"."Experimentsamples" (
    "Experiment_id" text NOT NULL REFERENCES "Lab"."Experiments"("Experiment_id"),
    "sample_id" text NOT NULL REFERENCES "Lab"."samples"("sample_id"),
    "description" text,
    PRIMARY KEY ("Experiment_id", "sample_id"),
    "modified_by" text REFERENCES "reference"."personal"("person_id"),
    "time_modification" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS "Lab"."Dissections" (
    "dissection_id" text PRIMARY KEY, -- Dissection2500000 YY0000
    "sample_id" text NOT NULL REFERENCES "Lab"."samples"("sample_id"),
    "person_id" text NOT NULL REFERENCES "reference"."personal"("person_id"),
    "dissection_date" date NOT NULL,
    "stomach_contents_jsonb" jsonb,
    "gonad_weight_g" numeric,
    "liver_weight_g" numeric,
    "description" text,
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "time_modification" timestamptz DEFAULT CURRENT_TIMESTAMP,
    "created_at" timestamptz DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "dissection_unique" UNIQUE ("sample_id", "person_id", "dissection_date")
);

-- Sequence for dissection_id serial number
DROP SEQUENCE IF EXISTS "Lab".dissection_serial_seq;
CREATE SEQUENCE IF NOT EXISTS "Lab".dissection_serial_seq START 1;

-- Trigger function for dissection_id generation
CREATE OR REPLACE FUNCTION "Lab".generate_dissection_id()
RETURNS TRIGGER AS $$
DECLARE
    current_year TEXT;
    next_serial INTEGER;
    id_prefix TEXT;
BEGIN
    current_year := TO_CHAR(COALESCE(NEW.dissection_date, CURRENT_DATE), 'YY');
    id_prefix := 'Dissection' || current_year;

    -- Find the maximum existing serial number for this prefix
    SELECT MAX(SUBSTRING("dissection_id" FROM LENGTH(id_prefix) + 1)::INTEGER)
    INTO next_serial
    FROM "Lab"."Dissections"
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

-- Trigger for dissection_id generation
DROP TRIGGER IF EXISTS trg_generate_dissection_id ON "Lab"."Dissections";
CREATE TRIGGER trg_generate_dissection_id
BEFORE INSERT ON "Lab"."Dissections"
FOR EACH ROW
EXECUTE FUNCTION "Lab".generate_dissection_id();


CREATE TABLE IF NOT EXISTS "Lab"."Extraction" (
    "Extraction_id" text PRIMARY KEY, -- Extraction2500000
    "Experiment_id" text REFERENCES "Lab"."Experiments"("Experiment_id"),
    "sample_id" text REFERENCES "Lab"."samples"("sample_id"), -- Parentsample_idSampleType1 F25WeHB0000d1
    "Parentsample_id" text NOT NULL REFERENCES "Lab"."samples"("sample_id"),
    "sample_type" text NOT NULL REFERENCES "reference"."samplesType"("sample_type"),
    "date" date,
    "person_id" text NOT NULL REFERENCES "reference"."personal"("person_id"),
    "kit" text,
    "ElutionVolume" numeric,
    "Yield_Qubit_ng_ul" numeric,
    "Yield_Nanodrop_ng_ul" numeric,
    "A260_280" numeric,
    "A260_230" numeric,
    "ExtractionBlankID" text,
    "description" text,
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "storage_id" text REFERENCES "Lab"."storage"("storage_id"),
    "storage_position" numeric,
    "project_id" text REFERENCES "Lims"."projects"("project_id"),
    "attachment" bytea,
    "modified_by" text REFERENCES "reference"."personal"("person_id"),
    "time_modification" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Sequence for Extraction_id serial number
DROP SEQUENCE IF EXISTS "Lab".extraction_serial_seq;
CREATE SEQUENCE IF NOT EXISTS "Lab".extraction_serial_seq START 1;

-- Trigger function for Extraction_id generation
CREATE OR REPLACE FUNCTION "Lab".generate_extraction_id()
RETURNS TRIGGER AS $$
DECLARE
    current_year TEXT;
    next_serial INTEGER;
    id_prefix TEXT;
BEGIN
    current_year := TO_CHAR(COALESCE(NEW.date, CURRENT_DATE), 'YY');
    id_prefix := 'Extraction' || current_year;

    -- Find the maximum existing serial number for this prefix
    SELECT MAX(SUBSTRING("Extraction_id" FROM LENGTH(id_prefix) + 1)::INTEGER)
    INTO next_serial
    FROM "Lab"."Extraction"
    WHERE "Extraction_id" ILIKE id_prefix || '%';

    IF next_serial IS NULL THEN
        next_serial := 1;
    ELSE
        next_serial := next_serial + 1;
    END IF;

    NEW."Extraction_id" := id_prefix || LPAD(next_serial::TEXT, 5, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for Extraction_id generation
DROP TRIGGER IF EXISTS trg_generate_extraction_id ON "Lab"."Extraction";
CREATE TRIGGER trg_generate_extraction_id
BEFORE INSERT ON "Lab"."Extraction"
FOR EACH ROW
EXECUTE FUNCTION "Lab".generate_extraction_id();


CREATE TABLE IF NOT EXISTS "Lab"."Nanodrop" (
    "nr" Text PRIMARY KEY, --NanodropYY0000
    "Experiment_id" text REFERENCES "Lab"."Experiments"("Experiment_id"),
    "sample_id" text REFERENCES "Lab"."samples"("sample_id"),
    "Nanodrop_Concentration ng/uL" numeric,
    "A260" numeric,
    "A260_280" numeric,
    "A260_280_note" text,
    "A260_230" numeric,
    "A260_230_note" text,
    "date" date,
    "Elution_volume_ul" numeric,
    "person" text,
    "description" text,
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "attachment" bytea,
    "storage_id" text REFERENCES "Lab"."storage"("storage_id"),
    "storage_position" numeric,
    "project_id" text REFERENCES "Lims"."projects"("project_id"),
    "Resultdate" timestamp with time zone,
    "modified_by" text REFERENCES "reference"."personal"("person_id"),
    "time_modification" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    "NanodropTotalDna_ug" numeric GENERATED ALWAYS AS (("Elution_volume_ul" * "Nanodrop_Concentration ng/uL") / 1000) STORED
);

-- Sequence for Nanodrop_nr serial number
DROP SEQUENCE IF EXISTS "Lab".nanodrop_serial_seq;
CREATE SEQUENCE IF NOT EXISTS "Lab".nanodrop_serial_seq START 1;

-- Trigger function for Nanodrop_nr generation
CREATE OR REPLACE FUNCTION "Lab".generate_nanodrop_nr()
RETURNS TRIGGER AS $$
DECLARE
    current_year TEXT;
    next_serial INTEGER;
    id_prefix TEXT;
BEGIN
    current_year := TO_CHAR(COALESCE(NEW.date, CURRENT_DATE), 'YY');
    id_prefix := 'Nanodrop' || current_year;

    -- Find the maximum existing serial number for this prefix
    SELECT MAX(SUBSTRING("nr" FROM LENGTH(id_prefix) + 1)::INTEGER)
    INTO next_serial
    FROM "Lab"."Nanodrop"
    WHERE "nr" ILIKE id_prefix || '%';

    IF next_serial IS NULL THEN
        next_serial := 1;
    ELSE
        next_serial := next_serial + 1;
    END IF;

    NEW.nr := id_prefix || LPAD(next_serial::TEXT, 4, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for Nanodrop_nr generation
DROP TRIGGER IF EXISTS trg_generate_nanodrop_nr ON "Lab"."Nanodrop";
CREATE TRIGGER trg_generate_nanodrop_nr
BEFORE INSERT ON "Lab"."Nanodrop"
FOR EACH ROW
EXECUTE FUNCTION "Lab".generate_nanodrop_nr();


CREATE TABLE IF NOT EXISTS "Lab"."Qubit" (
    "nr" text PRIMARY KEY, -- QubitYY00000
    "sample_id" text REFERENCES "Lab"."samples"("sample_id"),
    "Experiment_id" text REFERENCES "Lab"."Experiments"("Experiment_id"),
    "Run_id" text,
    "Assay_Kit" text,
    "date" date,
    "Qubit_tube_conc" numeric,
    "tube_unity" text,
    "QubitOriginal_sample_conc" numeric,
    "QubitOriginal_units" text,
    "sample_volume_ul" numeric,
    "Elution_volume_ul" numeric,
    "person" text,
    "description" text,
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "storage_id" text REFERENCES "Lab"."storage"("storage_id"),
    "storage_position" numeric,
    "project_id" text REFERENCES "Lims"."projects"("project_id"),
    "attachment" bytea,
    "modified_by" text REFERENCES "reference"."personal"("person_id"),
    "time_modification" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    "QubitTotalDna_ug" numeric GENERATED ALWAYS AS (("Elution_volume_ul" * "QubitOriginal_sample_conc") / 1000) STORED
);

-- Sequence for Qubit_nr serial number
DROP SEQUENCE IF EXISTS "Lab".qubit_serial_seq;
CREATE SEQUENCE IF NOT EXISTS "Lab".qubit_serial_seq START 1;

-- Trigger function for Qubit_nr generation
CREATE OR REPLACE FUNCTION "Lab".generate_qubit_nr()
RETURNS TRIGGER AS $$
DECLARE
    current_year TEXT;
    next_serial INTEGER;
    id_prefix TEXT;
BEGIN
    current_year := TO_CHAR(COALESCE(NEW.date, CURRENT_DATE), 'YY');
    id_prefix := 'Qubit' || current_year;

    -- Find the maximum existing serial number for this prefix
    SELECT MAX(SUBSTRING("nr" FROM LENGTH(id_prefix) + 1)::INTEGER)
    INTO next_serial
    FROM "Lab"."Qubit"
    WHERE "nr" ILIKE id_prefix || '%';

    IF next_serial IS NULL THEN
        next_serial := 1;
    ELSE
        next_serial := next_serial + 1;
    END IF;

    NEW.nr := id_prefix || LPAD(next_serial::TEXT, 5, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for Qubit_nr generation
DROP TRIGGER IF EXISTS trg_generate_qubit_nr ON "Lab"."Qubit";
CREATE TRIGGER trg_generate_qubit_nr
BEFORE INSERT ON "Lab"."Qubit"
FOR EACH ROW
EXECUTE FUNCTION "Lab".generate_qubit_nr();


CREATE TABLE IF NOT EXISTS "Lab"."Tapestation" (
    "nr" text PRIMARY KEY, -- TapeYY00000
    "Experiment_id" text REFERENCES "Lab"."Experiments"("Experiment_id"),
    "position" text,
    "date" date,
    "kit" text,
    "person" text,
    "description" text,
    "sample_id" text REFERENCES "Lab"."samples"("sample_id"),
    "storage_id" text REFERENCES "Lab"."storage"("storage_id"),
    "storage_position" numeric,
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "project_id" text REFERENCES "Lims"."projects"("project_id"),
    "attachment" bytea,
    "modified_by" text REFERENCES "reference"."personal"("person_id"),
    "time_modification" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Sequence for Tapestation_nr serial number
DROP SEQUENCE IF EXISTS "Lab".tapestation_serial_seq;
CREATE SEQUENCE IF NOT EXISTS "Lab".tapestation_serial_seq START 1;

-- Trigger function for Tapestation_nr generation
CREATE OR REPLACE FUNCTION "Lab".generate_tapestation_nr()
RETURNS TRIGGER AS $$
DECLARE
    current_year TEXT;
    next_serial INTEGER;
    id_prefix TEXT;
BEGIN
    current_year := TO_CHAR(COALESCE(NEW.date, CURRENT_DATE), 'YY');
    id_prefix := 'Tape' || current_year;

    -- Find the maximum existing serial number for this prefix
    SELECT MAX(SUBSTRING("nr" FROM LENGTH(id_prefix) + 1)::INTEGER)
    INTO next_serial
    FROM "Lab"."Tapestation"
    WHERE "nr" ILIKE id_prefix || '%';

    IF next_serial IS NULL THEN
        next_serial := 1;
    ELSE
        next_serial := next_serial + 1;
    END IF;

    NEW.nr := id_prefix || LPAD(next_serial::TEXT, 5, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for Tapestation_nr generation
DROP TRIGGER IF EXISTS trg_generate_tapestation_nr ON "Lab"."Tapestation";
CREATE TRIGGER trg_generate_tapestation_nr
BEFORE INSERT ON "Lab"."Tapestation"
FOR EACH ROW
EXECUTE FUNCTION "Lab".generate_tapestation_nr();


CREATE TABLE IF NOT EXISTS "Lab"."PCR" (
    "nr" text PRIMARY KEY, -- PCRYY00000
    "Experiment_id" text REFERENCES "Lab"."Experiments"("Experiment_id"),
    "sample_id" text REFERENCES "Lab"."samples"("sample_id"),
    "position" text,
    "gene_id" text REFERENCES "Lims"."Primers"("primer_id"),
    "PCRBlankID" text,
    "date" date,
    "person" text,
    "kit" text,
    "storage_id" text REFERENCES "Lab"."storage"("storage_id"),
    "storage_position" numeric,
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "description" text,
    "project_id" text REFERENCES "Lims"."projects"("project_id"),
    "attachment" bytea,
    "VolumeReaction" numeric,
    "modified_by" text REFERENCES "reference"."personal"("person_id"),
    "time_modification" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Sequence for PCR_nr serial number
DROP SEQUENCE IF EXISTS "Lab".pcr_serial_seq;
CREATE SEQUENCE IF NOT EXISTS "Lab".pcr_serial_seq START 1;

-- Trigger function for PCR_nr generation
CREATE OR REPLACE FUNCTION "Lab".generate_pcr_nr()
RETURNS TRIGGER AS $$
DECLARE
    current_year TEXT;
    next_serial INTEGER;
    id_prefix TEXT;
BEGIN
    current_year := TO_CHAR(COALESCE(NEW.date, CURRENT_DATE), 'YY');
    id_prefix := 'PCR' || current_year;

    -- Find the maximum existing serial number for this prefix
    SELECT MAX(SUBSTRING("nr" FROM LENGTH(id_prefix) + 1)::INTEGER)
    INTO next_serial
    FROM "Lab"."PCR"
    WHERE "nr" ILIKE id_prefix || '%';

    IF next_serial IS NULL THEN
        next_serial := 1;
    ELSE
        next_serial := next_serial + 1;
    END IF;

    NEW.nr := id_prefix || LPAD(next_serial::TEXT, 5, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for PCR_nr generation
DROP TRIGGER IF EXISTS trg_generate_pcr_nr ON "Lab"."PCR";
CREATE TRIGGER trg_generate_pcr_nr
BEFORE INSERT ON "Lab"."PCR"
FOR EACH ROW
EXECUTE FUNCTION "Lab".generate_pcr_nr();


CREATE TABLE IF NOT EXISTS "Lab"."Gelelectrophoresis" (
    "nr" text PRIMARY KEY, -- GelYY00000
    "Experiment_id" text REFERENCES "Lab"."Experiments"("Experiment_id"),
    "sample_id" text REFERENCES "Lab"."samples"("sample_id"),
    "position" text,
    "Ladder" text,
    "Voltage" numeric,
    "BandSize_bp" integer,
    "GelType" text,
    "RunTimeMinutes" numeric,
    "date" date,
    "person" text,
    "storage_id" text REFERENCES "Lab"."storage"("storage_id"),
    "storage_position" numeric,
    "project_id" text REFERENCES "Lims"."projects"("project_id"),
    "description" text,
    "attachment" bytea,
    "modified_by" text REFERENCES "reference"."personal"("person_id"),
    "time_modification" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Sequence for Gelelectrophoresis_nr serial number
DROP SEQUENCE IF EXISTS "Lab".gelelectrophoresis_serial_seq;
CREATE SEQUENCE IF NOT EXISTS "Lab".gelelectrophoresis_serial_seq START 1;

-- Trigger function for Gelelectrophoresis_nr generation
CREATE OR REPLACE FUNCTION "Lab".generate_gelelectrophoresis_nr()
RETURNS TRIGGER AS $$
DECLARE
    current_year TEXT;
    next_serial INTEGER;
    id_prefix TEXT;
BEGIN
    current_year := TO_CHAR(COALESCE(NEW.date, CURRENT_DATE), 'YY');
    id_prefix := 'Gel' || current_year;

    -- Find the maximum existing serial number for this prefix
    SELECT MAX(SUBSTRING("nr" FROM LENGTH(id_prefix) + 1)::INTEGER)
    INTO next_serial
    FROM "Lab"."Gelelectrophoresis"
    WHERE "nr" ILIKE id_prefix || '%';

    IF next_serial IS NULL THEN
        next_serial := 1;
    ELSE
        next_serial := next_serial + 1;
    END IF;

    NEW.nr := id_prefix || LPAD(next_serial::TEXT, 5, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for Gelelectrophoresis_nr generation
DROP TRIGGER IF EXISTS trg_generate_gelelectrophoresis_nr ON "Lab"."Gelelectrophoresis";
CREATE TRIGGER trg_generate_gelelectrophoresis_nr
BEFORE INSERT ON "Lab"."Gelelectrophoresis"
FOR EACH ROW
EXECUTE FUNCTION "Lab".generate_gelelectrophoresis_nr();


CREATE TABLE IF NOT EXISTS "Lab"."qPCR" (
    "nr" text PRIMARY KEY, -- qPCRYY00000
    "Experiment_id" text REFERENCES "Lab"."Experiments"("Experiment_id"),
    "sample_id" text REFERENCES "Lab"."samples"("sample_id"),
    "position" text,
    "date" date,
    "person" text,
    "gene_id" text REFERENCES "Lims"."Primers"("primer_id"),
    "CtValue" numeric,
    "InhibitorTestResult" text,
    "PCRBlankID" text,
    "kit" text,
    "Volume" numeric,
    "storage_id" text REFERENCES "Lab"."storage"("storage_id"),
    "storage_position" numeric,
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "project_id" text REFERENCES "Lims"."projects"("project_id"),
    "attachment" bytea,
    "modified_by" text REFERENCES "reference"."personal"("person_id"),
    "time_modification" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Sequence for qPCR_nr serial number
DROP SEQUENCE IF EXISTS "Lab".qpcr_serial_seq;
CREATE SEQUENCE IF NOT EXISTS "Lab".qpcr_serial_seq START 1;

-- Trigger function for qPCR_nr generation
CREATE OR REPLACE FUNCTION "Lab".generate_qpcr_nr()
RETURNS TRIGGER AS $$
DECLARE
    current_year TEXT;
    next_serial INTEGER;
    id_prefix TEXT;
BEGIN
    current_year := TO_CHAR(COALESCE(NEW.date, CURRENT_DATE), 'YY');
    id_prefix := 'qPCR' || current_year;

    -- Find the maximum existing serial number for this prefix
    SELECT MAX(SUBSTRING("nr" FROM LENGTH(id_prefix) + 1)::INTEGER)
    INTO next_serial
    FROM "Lab"."qPCR"
    WHERE "nr" ILIKE id_prefix || '%';

    IF next_serial IS NULL THEN
        next_serial := 1;
    ELSE
        next_serial := next_serial + 1;
    END IF;

    NEW.nr := id_prefix || LPAD(next_serial::TEXT, 5, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for qPCR_nr generation
DROP TRIGGER IF EXISTS trg_generate_qpcr_nr ON "Lab"."qPCR";
CREATE TRIGGER trg_generate_qpcr_nr
BEFORE INSERT ON "Lab"."qPCR"
FOR EACH ROW
EXECUTE FUNCTION "Lab".generate_qpcr_nr();


CREATE TABLE IF NOT EXISTS "Lab"."Library" (
    "Lib_id" text PRIMARY KEY, -- L250000 LYY0000
    "Experiment_id" text REFERENCES "Lab"."Experiments"("Experiment_id"),
    "sample_id" text NOT NULL REFERENCES "Lab"."samples"("sample_id"),
    "Library" text,
    "date" date,
    "person" text,
    "LibraryPrepKit" text,
    "IndexSequence" text,
    "ReadLength" integer,
    "storage_id" text REFERENCES "Lab"."storage"("storage_id"),
    "storage_position" numeric,
    "project_id" text REFERENCES "Lims"."projects"("project_id"),
    "description" text,
    "attachment" bytea,
    "modified_by" text REFERENCES "reference"."personal"("person_id"),
    "time_modification" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Sequence for Library_id serial number
DROP SEQUENCE IF EXISTS "Lab".library_serial_seq;
CREATE SEQUENCE IF NOT EXISTS "Lab".library_serial_seq START 1;

-- Trigger function for Library_id generation
CREATE OR REPLACE FUNCTION "Lab".generate_library_id()
RETURNS TRIGGER AS $$
DECLARE
    current_year TEXT;
    library_abrv TEXT;
    next_serial INTEGER;
    id_prefix TEXT;
BEGIN
    current_year := TO_CHAR(COALESCE(NEW.date, CURRENT_DATE), 'YY');
    SELECT "sample_typeAbrv" INTO library_abrv FROM "reference"."samplesType" WHERE "sample_type" = 'Library';
    id_prefix := library_abrv || current_year;

    -- Find the maximum existing serial number for this prefix
    SELECT MAX(SUBSTRING("Lib_id" FROM LENGTH(id_prefix) + 1)::INTEGER)
    INTO next_serial
    FROM "Lab"."Library"
    WHERE "Lib_id" ILIKE id_prefix || '%';

    IF next_serial IS NULL THEN
        next_serial := 1;
    ELSE
        next_serial := next_serial + 1;
    END IF;

    NEW."Lib_id" := id_prefix || LPAD(next_serial::TEXT, 4, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for Library_id generation
DROP TRIGGER IF EXISTS trg_generate_library_id ON "Lab"."Library";
CREATE TRIGGER trg_generate_library_id
BEFORE INSERT ON "Lab"."Library"
FOR EACH ROW
EXECUTE FUNCTION "Lab".generate_library_id();


CREATE TABLE IF NOT EXISTS "Lab"."Sequencing" (
    "Seq_id" text PRIMARY KEY,  -- SeqYY0000
    "Experiment_id" text REFERENCES "Lab"."Experiments"("Experiment_id"),
    "Library_id" text REFERENCES "Lab"."Library"("Lib_id"),
    "sample_id" text NOT NULL REFERENCES "Lab"."samples"("sample_id"),
    "date" date,
    "person" text,
    "Sequencer" text,
    "FlowCellID" text,
    "LibraryPrepKit" text,
    "IndexSequence" text,
    "ReadLength" integer,
    "TotalReads" bigint,
    "RawDataPath" text,
    "GenbankAccessionNumber" text,
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "storage_id" text REFERENCES "Lab"."storage"("storage_id"),
    "storage_position" numeric,
    "project_id" text REFERENCES "Lims"."projects"("project_id"),
    "attachment" bytea,
    "description" text,
    "modified_by" text REFERENCES "reference"."personal"("person_id"),
    "time_modification" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Remove the simple sequencing_serial_seq as it's not suitable for partitioned resets
DROP SEQUENCE IF EXISTS "Lab".sequencing_serial_seq;

-- Trigger function for Seq_id generation with partitioned serial number
CREATE OR REPLACE FUNCTION "Lab".generate_sequencing_id()
RETURNS TRIGGER AS $$
DECLARE
    current_year TEXT;
    ecosystem_abrv TEXT := '-';
    region_abrv TEXT := '-';
    customer_abrv TEXT := '-';
    id_prefix TEXT;
    next_serial INTEGER;
BEGIN
    current_year := TO_CHAR(COALESCE(NEW.date, CURRENT_DATE), 'YY');

    -- Try to get ecosystem and region from sampling_id via samples table
    SELECT
        COALESCE(e.ecosystem_abrv, '-'),
        COALESCE(r.region_abrv, '-')
    INTO
        ecosystem_abrv,
        region_abrv
    FROM
        "Lab"."samples" s
    LEFT JOIN
        "Lab"."sampling" samp ON s.sampling_id = samp.sampling_id
    LEFT JOIN
        "reference"."ecosystem" e ON samp.ecosystem_id = e.ecosystem_id
    LEFT JOIN
        "reference"."region" r ON samp.region_id = r.region_id
    WHERE
        s.sample_id = NEW.sample_id;

    -- If both ecosystem and region are missing, try customer abbreviation
    IF ecosystem_abrv = '-' AND region_abrv = '-' THEN
        SELECT COALESCE(cust.customer_abrv, '-') INTO customer_abrv
        FROM "Lab"."samples" s
        LEFT JOIN "Lims"."customers" cust ON s.customer_id = cust.customer_id
        WHERE s.sample_id = NEW.sample_id;

        id_prefix := 'Seq' || current_year || customer_abrv;
    ELSE
        id_prefix := 'Seq' || current_year || ecosystem_abrv || region_abrv;
    END IF;

    -- Find the maximum existing serial number for this prefix
    SELECT MAX(SUBSTRING("Seq_id" FROM LENGTH(id_prefix) + 1)::INTEGER)
    INTO next_serial
    FROM "Lab"."Sequencing"
    WHERE "Seq_id" ILIKE id_prefix || '%';

    IF next_serial IS NULL THEN
        next_serial := 1;
    ELSE
        next_serial := next_serial + 1;
    END IF;

    NEW."Seq_id" := id_prefix || LPAD(next_serial::TEXT, 4, '0');

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for Seq_id generation
DROP TRIGGER IF EXISTS trg_generate_sequencing_id ON "Lab"."Sequencing";
CREATE TRIGGER trg_generate_sequencing_id
BEFORE INSERT ON "Lab"."Sequencing"
FOR EACH ROW
EXECUTE FUNCTION "Lab".generate_sequencing_id();


CREATE TABLE IF NOT EXISTS "Lab"."datasets" (
    "dataset_id" text PRIMARY KEY, -- ZYY00000
    "source" text,
    "ecosystem_id" text REFERENCES "reference"."ecosystem"("ecosystem_id"),
    "region_id" text REFERENCES "reference"."region"("region_id"),
    "customer_id" text REFERENCES "Lims"."customers"("customer_id"),
    "stored_location" text REFERENCES "Lab"."storage"("storage_id"),
    "reception_date" date,
    "description" text,
    "attachment" bytea,
    "modified_by" text REFERENCES "reference"."personal"("person_id"),
    "time_modification" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Sequence for dataset_id serial number
DROP SEQUENCE IF EXISTS "Lab".dataset_serial_seq;
CREATE SEQUENCE IF NOT EXISTS "Lab".dataset_serial_seq START 1;

-- Trigger function for dataset_id generation
CREATE OR REPLACE FUNCTION "Lab".generate_dataset_id()
RETURNS TRIGGER AS $$
DECLARE
    current_year TEXT;
    customer_abrv TEXT := '-';
    ecosystem_abrv TEXT := '-';
    region_abrv TEXT := '-';
    dataset_abrv TEXT;
    id_prefix TEXT;
    next_serial INTEGER;
BEGIN
    current_year := TO_CHAR(COALESCE(NEW.reception_date, CURRENT_DATE), 'YY');
    SELECT "sample_typeAbrv" INTO dataset_abrv FROM "reference"."samplesType" WHERE "sample_type" = 'Dataset';

    IF NEW.customer_id IS NOT NULL THEN
        SELECT c.customer_abrv INTO customer_abrv
        FROM "Lims"."customers" c
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

    -- Find the maximum existing serial number for this prefix
    SELECT MAX(SUBSTRING("dataset_id" FROM LENGTH(id_prefix) + 1)::INTEGER)
    INTO next_serial
    FROM "Lab"."datasets"
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

-- Trigger for dataset_id generation
DROP TRIGGER IF EXISTS trg_generate_dataset_id ON "Lab"."datasets";
CREATE TRIGGER trg_generate_dataset_id
BEFORE INSERT ON "Lab"."datasets"
FOR EACH ROW
EXECUTE FUNCTION "Lab".generate_dataset_id();


-- ======================================================================
-- create tables Bioinfo

CREATE TABLE IF NOT EXISTS "bioinformatics"."analysis_pipelines" (
    "pipeline_id" text PRIMARY KEY, -- YY000000
    "name" text NOT NULL,
    "version" text NOT NULL,
    "repository_link" text,
    "description" text,
    "storage_id" text REFERENCES "Lab"."storage"("storage_id"),
    "storage_position" numeric,
    "project_id" text REFERENCES "Lims"."projects"("project_id"),
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "attachment" bytea,
    "modified_by" text REFERENCES "reference"."personal"("person_id"),
    "time_modification" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Sequence for pipeline_id serial number
DROP SEQUENCE IF EXISTS "bioinformatics".pipeline_serial_seq;
CREATE SEQUENCE IF NOT EXISTS "bioinformatics".pipeline_serial_seq START 1;

-- Trigger function for pipeline_id generation
CREATE OR REPLACE FUNCTION "bioinformatics".generate_pipeline_id()
RETURNS TRIGGER AS $$
DECLARE
    current_year TEXT;
    next_serial INTEGER;
    id_prefix TEXT;
BEGIN
    current_year := TO_CHAR(CURRENT_DATE, 'YY'); -- Assuming creation year for pipeline ID
    id_prefix := current_year;

    -- Find the maximum existing serial number for this prefix
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

-- Trigger for pipeline_id generation
DROP TRIGGER IF EXISTS trg_generate_pipeline_id ON "bioinformatics"."analysis_pipelines";
CREATE TRIGGER trg_generate_pipeline_id
BEFORE INSERT ON "bioinformatics"."analysis_pipelines"
FOR EACH ROW
EXECUTE FUNCTION "bioinformatics".generate_pipeline_id();


CREATE TABLE IF NOT EXISTS "bioinformatics"."analysis_runs" (
    "run_id" text PRIMARY KEY, -- YY000000
    "pipeline_id" text NOT NULL REFERENCES "bioinformatics"."analysis_pipelines"("pipeline_id"),
    "sequencing_run_id" text NOT NULL REFERENCES "Lab"."Sequencing"("Seq_id"),
    "person_id" text NOT NULL REFERENCES "reference"."personal"("person_id"),
    "run_date" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    "parameters_jsonb" jsonb,
    "description" text,
    "storage_id" text REFERENCES "Lab"."storage"("storage_id"),
    "storage_position" numeric,
    "project_id" text REFERENCES "Lims"."projects"("project_id"),
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "attachment" bytea,
    "modified_by" text REFERENCES "reference"."personal"("person_id"),
    "time_modification" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Sequence for run_id serial number
DROP SEQUENCE IF EXISTS "bioinformatics".analysis_runs_serial_seq;
CREATE SEQUENCE IF NOT EXISTS "bioinformatics".analysis_runs_serial_seq START 1;

-- Trigger function for run_id generation
CREATE OR REPLACE FUNCTION "bioinformatics".generate_analysis_run_id()
RETURNS TRIGGER AS $$
DECLARE
    current_year TEXT;
    next_serial INTEGER;
    id_prefix TEXT;
BEGIN
    current_year := TO_CHAR(COALESCE(NEW.run_date, CURRENT_DATE), 'YY');
    id_prefix := current_year;

    -- Find the maximum existing serial number for this prefix
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

-- Trigger for run_id generation
DROP TRIGGER IF EXISTS trg_generate_analysis_run_id ON "bioinformatics"."analysis_runs";
CREATE TRIGGER trg_generate_analysis_run_id
BEFORE INSERT ON "bioinformatics"."analysis_runs"
FOR EACH ROW
EXECUTE FUNCTION "bioinformatics".generate_analysis_run_id();


CREATE TABLE IF NOT EXISTS "bioinformatics"."edna_assignments" (
    "assignment_id" text PRIMARY KEY, -- YY000000
    "run_id" text NOT NULL REFERENCES "bioinformatics"."analysis_runs"("run_id"),
    "sample_id" text NOT NULL REFERENCES "Lab"."samples"("sample_id"),
    "taxon_id" text NOT NULL REFERENCES "reference"."taxon"("taxon_id"),
    "read_count" integer,
    "confidence" numeric,
    "description" text,
    "storage_id" text REFERENCES "Lab"."storage"("storage_id"),
    "storage_position" numeric,
    "project_id" text REFERENCES "Lims"."projects"("project_id"),
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "attachment" bytea,
    "modified_by" text REFERENCES "reference"."personal"("person_id"),
    "time_modification" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Sequence for assignment_id serial number
DROP SEQUENCE IF EXISTS "bioinformatics".edna_assignments_serial_seq;
CREATE SEQUENCE IF NOT EXISTS "bioinformatics".edna_assignments_serial_seq START 1;

-- Trigger function for assignment_id generation
CREATE OR REPLACE FUNCTION "bioinformatics".generate_edna_assignment_id()
RETURNS TRIGGER AS $$
DECLARE
    current_year TEXT;
    next_serial INTEGER;
    id_prefix TEXT;
BEGIN
    current_year := TO_CHAR(CURRENT_DATE, 'YY'); -- Assuming creation year for assignment ID
    id_prefix := current_year;

    -- Find the maximum existing serial number for this prefix
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

-- Trigger for assignment_id generation
DROP TRIGGER IF EXISTS trg_generate_edna_assignment_id ON "bioinformatics"."edna_assignments";
CREATE TRIGGER trg_generate_edna_assignment_id
BEFORE INSERT ON "bioinformatics"."edna_assignments"
FOR EACH ROW
EXECUTE FUNCTION "bioinformatics".generate_edna_assignment_id();




CREATE TABLE IF NOT EXISTS "Lab"."bioinformatics" (
    "sequencing_id" text REFERENCES "Lab"."Sequencing"("Seq_id"),
    "Experiment_id" text REFERENCES "Lab"."Experiments"("Experiment_id"),
    "date" date,
    "person" text,
    "PipelineName" text,
    "PipelineVersion" text,
    "referenceDatabase" text,
    "DatabaseVersion" text,
    "ClusteringThreshold" numeric,
    "FinalOutputPath" text,
    "sample_id" text REFERENCES "Lab"."samples"("sample_id"),
    "description" text,
    "storage_id" text REFERENCES "Lab"."storage"("storage_id"),
    "storage_position" numeric,
    "project_id" text REFERENCES "Lims"."projects"("project_id"),
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "attachment" bytea,
    "modified_by" text REFERENCES "reference"."personal"("person_id"),
    "time_modification" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
) INHERITS ("bioinformatics"."analysis_pipelines"); -- Inherit from analysis_pipelines

-- Sequence for bioinfo_id serial number
DROP SEQUENCE IF EXISTS "Lab".bioinfo_serial_seq;
CREATE SEQUENCE IF NOT EXISTS "Lab".bioinfo_serial_seq START 1;

-- Trigger function for bioinfo_id generation
CREATE OR REPLACE FUNCTION "Lab".generate_bioinfo_id()
RETURNS TRIGGER AS $$
DECLARE
    current_year TEXT;
    next_serial INTEGER;
    id_prefix TEXT;
BEGIN
    current_year := TO_CHAR(COALESCE(NEW.date, CURRENT_DATE), 'YY');
    id_prefix := current_year;

    -- Find the maximum existing serial number for this prefix
    SELECT MAX(SUBSTRING("bioinfo_id" FROM LENGTH(id_prefix) + 1)::INTEGER)
    INTO next_serial
    FROM "Lab"."bioinformatics"
    WHERE "bioinfo_id" ILIKE id_prefix || '%';

    IF next_serial IS NULL THEN
        next_serial := 1;
    ELSE
        next_serial := next_serial + 1;
    END IF;

    NEW.bioinfo_id := id_prefix || LPAD(next_serial::TEXT, 5, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for bioinfo_id generation
DROP TRIGGER IF EXISTS trg_generate_bioinfo_id ON "Lab"."bioinformatics";
CREATE TRIGGER trg_generate_bioinfo_id
BEFORE INSERT ON "Lab"."bioinformatics"
FOR EACH ROW
EXECUTE FUNCTION "Lab".generate_bioinfo_id();



-- ==========================================================
-- data starting

INSERT INTO "reference"."status" ("status_id", "description") VALUES
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
('bioinformatics Done', 'bioinformatics analysis is complete'),
('Unknown step', 'An unknown step has occurred in the workflow')
ON CONFLICT ("status_id") DO NOTHING;

INSERT INTO "reference"."samplesType" ("sample_type", "sample_typeAbrv", "description") VALUES
('DNA', 'D', 'Deoxyribonucleic Acid sample'),
('RNA', 'R', 'Ribonucleic Acid sample'),
('Library', 'L', 'Sequencing Library sample'),
('Water', 'W', 'Water sample'),
('Sediments', 'S', 'Sediment sample'),
('Tissue', 'T', 'Tissue sample'),
('Fish', 'F', 'Fish sample'),
('Sequencing', 'Q', 'Sequencing run output'),
('Dataset', 'Z', 'Processed dataset')
ON CONFLICT ("sample_type") DO NOTHING;

-- ==========================================================
-- Checks (Limitations)

-- Ensure existing constraints are dropped before re-adding to prevent "Constraint already exists" errors
ALTER TABLE "Lab"."fish" DROP CONSTRAINT IF EXISTS chk_fish_lengths_positive;
ALTER TABLE "Lab"."fish" DROP CONSTRAINT IF EXISTS chk_fish_weight_positive;
ALTER TABLE "Lab"."Tissue" DROP CONSTRAINT IF EXISTS chk_tissue_weight_positive;
ALTER TABLE "Lab"."DNA" DROP CONSTRAINT IF EXISTS chk_dna_volume_positive;
ALTER TABLE "Lab"."DNA" DROP CONSTRAINT IF EXISTS chk_dna_concentration_positive;
ALTER TABLE "Lab"."DNA" DROP CONSTRAINT IF EXISTS chk_dna_a260_280_range;
ALTER TABLE "Lab"."DNA" DROP CONSTRAINT IF EXISTS chk_dna_a260_230_range;
ALTER TABLE "Lab"."RNA" DROP CONSTRAINT IF EXISTS chk_rna_volume_positive;
ALTER TABLE "Lab"."RNA" DROP CONSTRAINT IF EXISTS chk_rna_concentration_positive;
ALTER TABLE "Lab"."RNA" DROP CONSTRAINT IF EXISTS chk_rna_a260_280_range;
ALTER TABLE "Lab"."RNA" DROP CONSTRAINT IF EXISTS chk_rna_a260_230_range;
ALTER TABLE "Lab"."Sediments" DROP CONSTRAINT IF EXISTS chk_sediments_volume_positive;
ALTER TABLE "Lab"."Sediments" DROP CONSTRAINT IF EXISTS chk_sediments_depth_positive;
ALTER TABLE "Lab"."Water" DROP CONSTRAINT IF EXISTS chk_water_volume_positive;
ALTER TABLE "Lab"."Water" DROP CONSTRAINT IF EXISTS chk_water_filter_pore_size_positive;
ALTER TABLE "Lab"."Water" DROP CONSTRAINT IF EXISTS chk_water_depth_positive;
ALTER TABLE "Lab"."Nanodrop" DROP CONSTRAINT IF EXISTS chk_nanodrop_concentration_positive;
ALTER TABLE "Lab"."Nanodrop" DROP CONSTRAINT IF EXISTS chk_nanodrop_a260_positive;
ALTER TABLE "Lab"."Nanodrop" DROP CONSTRAINT IF EXISTS chk_nanodrop_elution_volume_positive;
ALTER TABLE "Lab"."Qubit" DROP CONSTRAINT IF EXISTS chk_qubit_tube_conc_positive;
ALTER TABLE "Lab"."Qubit" DROP CONSTRAINT IF EXISTS chk_qubit_original_sample_conc_positive;
ALTER TABLE "Lab"."Qubit" DROP CONSTRAINT IF EXISTS chk_qubit_sample_volume_positive;
ALTER TABLE "Lab"."Qubit" DROP CONSTRAINT IF EXISTS chk_qubit_elution_volume_positive;
ALTER TABLE "Lab"."Tapestation" DROP CONSTRAINT IF EXISTS chk_tapestation_position_not_empty;
ALTER TABLE "Lab"."PCR" DROP CONSTRAINT IF EXISTS chk_pcr_volume_reaction_positive;
ALTER TABLE "Lab"."Gelelectrophoresis" DROP CONSTRAINT IF EXISTS chk_gelelectrophoresis_voltage_positive;
ALTER TABLE "Lab"."Gelelectrophoresis" DROP CONSTRAINT IF EXISTS chk_gelelectrophoresis_bandsize_positive;
ALTER TABLE "Lab"."Gelelectrophoresis" DROP CONSTRAINT IF EXISTS chk_gelelectrophoresis_runtime_positive;
ALTER TABLE "Lab"."qPCR" DROP CONSTRAINT IF EXISTS chk_qpcr_ctvalue_positive;
ALTER TABLE "Lab"."qPCR" DROP CONSTRAINT IF EXISTS chk_qpcr_volume_positive;
ALTER TABLE "Lab"."Library" DROP CONSTRAINT IF EXISTS chk_library_readlength_positive;
ALTER TABLE "Lab"."Sequencing" DROP CONSTRAINT IF EXISTS chk_sequencing_readlength_positive;
ALTER TABLE "Lab"."Sequencing" DROP CONSTRAINT IF EXISTS chk_sequencing_totalreads_positive;
ALTER TABLE "Lab"."bioinformatics" DROP CONSTRAINT IF EXISTS chk_bioinfo_clustering_threshold_range;
ALTER TABLE "bioinformatics"."edna_assignments" DROP CONSTRAINT IF EXISTS chk_edna_read_count_positive;
ALTER TABLE "bioinformatics"."edna_assignments" DROP CONSTRAINT IF EXISTS chk_edna_confidence_range;
ALTER TABLE "Lims"."projects" DROP CONSTRAINT IF EXISTS chk_project_dates;
ALTER TABLE "Lims"."cruises" DROP CONSTRAINT IF EXISTS chk_cruise_dates;
ALTER TABLE "Lims"."permits" DROP CONSTRAINT IF EXISTS chk_permit_valid_dates;
ALTER TABLE "Lims"."Reagents" DROP CONSTRAINT IF EXISTS chk_reagents_expire_date;
ALTER TABLE "Lab"."sampling" DROP CONSTRAINT IF EXISTS chk_sampling_start_end_dates;
ALTER TABLE "Lab"."fish" DROP CONSTRAINT IF EXISTS chk_fish_sex_enum;
ALTER TABLE "Lab"."sampling" DROP CONSTRAINT IF EXISTS chk_sampling_wind_unit_enum;
ALTER TABLE "Lab"."sampling" DROP CONSTRAINT IF EXISTS chk_sampling_salinity_unit_enum;
ALTER TABLE "Lab"."sampling" DROP CONSTRAINT IF EXISTS chk_sampling_pressure_unit_enum;
ALTER TABLE "Lab"."sampling" DROP CONSTRAINT IF EXISTS chk_sampling_oxygen_unit_enum;
ALTER TABLE "Lab"."sampling" DROP CONSTRAINT IF EXISTS chk_sampling_conductivity_unit_enum;


-- Check for positive numeric values where applicable (e.g., weights, volumes, concentrations)
ALTER TABLE "Lab"."fish"
ADD CONSTRAINT chk_fish_lengths_positive CHECK ("total_length_mm" IS NULL OR "total_length_mm" >= 0),
ADD CONSTRAINT chk_fish_weight_positive CHECK ("weight_g" IS NULL OR "weight_g" >= 0);

ALTER TABLE "Lab"."Tissue"
ADD CONSTRAINT chk_tissue_weight_positive CHECK ("Weight_mg" IS NULL OR "Weight_mg" >= 0);

ALTER TABLE "Lab"."DNA"
ADD CONSTRAINT chk_dna_volume_positive CHECK ("Volume_uL" IS NULL OR "Volume_uL" >= 0),
ADD CONSTRAINT chk_dna_concentration_positive CHECK ("Concentration_ngul" IS NULL OR "Concentration_ngul" >= 0),
ADD CONSTRAINT chk_dna_a260_280_range CHECK ("A260/280" IS NULL OR ("A260/280" >= 1.8 AND "A260/280" <= 2.0)), -- Typical range for pure DNA
ADD CONSTRAINT chk_dna_a260_230_range CHECK ("A260/230" IS NULL OR ("A260/230" >= 2.0 AND "A260/230" <= 2.2)); -- Typical range for pure DNA

ALTER TABLE "Lab"."RNA"
ADD CONSTRAINT chk_rna_volume_positive CHECK ("Volume_uL" IS NULL OR "Volume_uL" >= 0),
ADD CONSTRAINT chk_rna_concentration_positive CHECK ("Concentration_ngul" IS NULL OR "Concentration_ngul" >= 0),
ADD CONSTRAINT chk_rna_a260_280_range CHECK ("A260/280" IS NULL OR ("A260/280" >= 2.0 AND "A260/280" <= 2.2)), -- Typical range for pure RNA
ADD CONSTRAINT chk_rna_a260_230_range CHECK ("A260/230" IS NULL OR ("A260/230" >= 2.0 AND "A260/230" <= 2.2)); -- Typical range for pure RNA

ALTER TABLE "Lab"."Sediments"
ADD CONSTRAINT chk_sediments_volume_positive CHECK ("Volume" IS NULL OR "Volume" >= 0),
ADD CONSTRAINT chk_sediments_depth_positive CHECK ("Depth" IS NULL OR "Depth" >= 0);

ALTER TABLE "Lab"."Water"
ADD CONSTRAINT chk_water_volume_positive CHECK ("VolumeL" IS NULL OR "VolumeL" >= 0),
ADD CONSTRAINT chk_water_filter_pore_size_positive CHECK ("FilterPoreSize" IS NULL OR "FilterPoreSize" >= 0),
ADD CONSTRAINT chk_water_depth_positive CHECK ("Depth" IS NULL OR "Depth" >= 0);

ALTER TABLE "Lab"."Nanodrop"
ADD CONSTRAINT chk_nanodrop_concentration_positive CHECK ("Nanodrop_Concentration ng/uL" IS NULL OR "Nanodrop_Concentration ng/uL" >= 0),
ADD CONSTRAINT chk_nanodrop_a260_positive CHECK ("A260" IS NULL OR "A260" >= 0),
ADD CONSTRAINT chk_nanodrop_elution_volume_positive CHECK ("Elution_volume_ul" IS NULL OR "Elution_volume_ul" >= 0);

ALTER TABLE "Lab"."Qubit"
ADD CONSTRAINT chk_qubit_tube_conc_positive CHECK ("Qubit_tube_conc" IS NULL OR "Qubit_tube_conc" >= 0),
ADD CONSTRAINT chk_qubit_original_sample_conc_positive CHECK ("QubitOriginal_sample_conc" IS NULL OR "QubitOriginal_sample_conc" >= 0),
ADD CONSTRAINT chk_qubit_sample_volume_positive CHECK ("sample_volume_ul" IS NULL OR "sample_volume_ul" >= 0),
ADD CONSTRAINT chk_qubit_elution_volume_positive CHECK ("Elution_volume_ul" IS NULL OR "Elution_volume_ul" >= 0);

ALTER TABLE "Lab"."Tapestation"
ADD CONSTRAINT chk_tapestation_position_not_empty CHECK ("position" IS NULL OR "position" <> '');

ALTER TABLE "Lab"."PCR"
ADD CONSTRAINT chk_pcr_volume_reaction_positive CHECK ("VolumeReaction" IS NULL OR "VolumeReaction" >= 0);

ALTER TABLE "Lab"."Gelelectrophoresis"
ADD CONSTRAINT chk_gelelectrophoresis_voltage_positive CHECK ("Voltage" IS NULL OR "Voltage" >= 0),
ADD CONSTRAINT chk_gelelectrophoresis_bandsize_positive CHECK ("BandSize_bp" IS NULL OR "BandSize_bp" >= 0),
ADD CONSTRAINT chk_gelelectrophoresis_runtime_positive CHECK ("RunTimeMinutes" IS NULL OR "RunTimeMinutes" >= 0);

ALTER TABLE "Lab"."qPCR"
ADD CONSTRAINT chk_qpcr_ctvalue_positive CHECK ("CtValue" IS NULL OR "CtValue" >= 0),
ADD CONSTRAINT chk_qpcr_volume_positive CHECK ("Volume" IS NULL OR "Volume" >= 0);

ALTER TABLE "Lab"."Library"
ADD CONSTRAINT chk_library_readlength_positive CHECK ("ReadLength" IS NULL OR "ReadLength" >= 0);

ALTER TABLE "Lab"."Sequencing"
ADD CONSTRAINT chk_sequencing_readlength_positive CHECK ("ReadLength" IS NULL OR "ReadLength" >= 0),
ADD CONSTRAINT chk_sequencing_totalreads_positive CHECK ("TotalReads" IS NULL OR "TotalReads" >= 0);

ALTER TABLE "Lab"."bioinformatics"
ADD CONSTRAINT chk_bioinfo_clustering_threshold_range CHECK ("ClusteringThreshold" IS NULL OR ("ClusteringThreshold" >= 0 AND "ClusteringThreshold" <= 1));

ALTER TABLE "bioinformatics"."edna_assignments"
ADD CONSTRAINT chk_edna_read_count_positive CHECK ("read_count" IS NULL OR "read_count" >= 0),
ADD CONSTRAINT chk_edna_confidence_range CHECK ("confidence" IS NULL OR ("confidence" >= 0 AND "confidence" <= 1));

-- Check for valid date ranges (e.g., end_date after start_date)
ALTER TABLE "Lims"."projects"
ADD CONSTRAINT chk_project_dates CHECK ("End_date" IS NULL OR "Start_date" IS NULL OR "End_date" >= "Start_date");

ALTER TABLE "Lims"."cruises"
ADD CONSTRAINT chk_cruise_dates CHECK ("end_date" IS NULL OR "start_date" IS NULL OR "end_date" >= "start_date");

ALTER TABLE "Lims"."permits"
ADD CONSTRAINT chk_permit_valid_dates CHECK ("valid_to" IS NULL OR "valid_from" IS NULL OR "valid_to" >= "valid_from");

ALTER TABLE "Lims"."Reagents"
ADD CONSTRAINT chk_reagents_expire_date CHECK ("Expire_date" IS NULL OR "Reception_date" IS NULL OR "Expire_date" >= "Reception_date");

ALTER TABLE "Lab"."sampling"
ADD CONSTRAINT chk_sampling_start_end_dates CHECK ("end_at" IS NULL OR "start_at" IS NULL OR "end_at" >= "start_at");

-- Check for specific enum-like values where applicable (e.g., Sex, MaturityStage, WindUnit)
ALTER TABLE "Lab"."fish"
ADD CONSTRAINT chk_fish_sex_enum CHECK ("Sex" IN ('Male', 'Female', 'Undetermined', NULL));

ALTER TABLE "Lab"."sampling"
ADD CONSTRAINT chk_sampling_wind_unit_enum CHECK ("WindUnit" IN ('km/h', 'm/s', 'knots', NULL));

ALTER TABLE "Lab"."sampling"
ADD CONSTRAINT chk_sampling_salinity_unit_enum CHECK ("SalinityUnit" IN ('PSU', 'ppt', NULL));

ALTER TABLE "Lab"."sampling"
ADD CONSTRAINT chk_sampling_pressure_unit_enum CHECK ("PressureUnit" IN ('dbar', 'psi', 'kPa', NULL));

ALTER TABLE "Lab"."sampling"
ADD CONSTRAINT chk_sampling_oxygen_unit_enum CHECK ("OxygenUnit" IN ('mg/L', 'umol/L', NULL));

ALTER TABLE "Lab"."sampling"
ADD CONSTRAINT chk_sampling_conductivity_unit_enum CHECK ("ConductivityUnit" IN ('mS/cm', 'uS/cm', NULL));

-- ==========================================================
-- FUNCTIONS to update workflow status at samples table depending in which experiment table is

CREATE OR REPLACE FUNCTION "Lab".update_workflow_status_extraction()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE "Lab"."samples"
    SET "sample_status_id" = 'Extracted', "time_modification" = CURRENT_TIMESTAMP
    WHERE "sample_id" = NEW.sample_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_workflow_status_extraction ON "Lab"."Extraction";
CREATE TRIGGER trg_update_workflow_status_extraction
AFTER INSERT ON "Lab"."Extraction"
FOR EACH ROW
EXECUTE FUNCTION "Lab".update_workflow_status_extraction();


CREATE OR REPLACE FUNCTION "Lab".update_workflow_status_nanodrop()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE "Lab"."samples"
    SET "sample_status_id" = 'Nanodrop QC', "time_modification" = CURRENT_TIMESTAMP
    WHERE "sample_id" = NEW.sample_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_workflow_status_nanodrop ON "Lab"."Nanodrop";
CREATE TRIGGER trg_update_workflow_status_nanodrop
AFTER INSERT ON "Lab"."Nanodrop"
FOR EACH ROW
EXECUTE FUNCTION "Lab".update_workflow_status_nanodrop();


CREATE OR REPLACE FUNCTION "Lab".update_workflow_status_qubit()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE "Lab"."samples"
    SET "sample_status_id" = 'Qubit QC', "time_modification" = CURRENT_TIMESTAMP
    WHERE "sample_id" = NEW.sample_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_workflow_status_qubit ON "Lab"."Qubit";
CREATE TRIGGER trg_update_workflow_status_qubit
AFTER INSERT ON "Lab"."Qubit"
FOR EACH ROW
EXECUTE FUNCTION "Lab".update_workflow_status_qubit();


CREATE OR REPLACE FUNCTION "Lab".update_workflow_status_tapestation()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE "Lab"."samples"
    SET "sample_status_id" = 'Tapestation QC', "time_modification" = CURRENT_TIMESTAMP
    WHERE "sample_id" = NEW.sample_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_workflow_status_tapestation ON "Lab"."Tapestation";
CREATE TRIGGER trg_update_workflow_status_tapestation
AFTER INSERT ON "Lab"."Tapestation"
FOR EACH ROW
EXECUTE FUNCTION "Lab".update_workflow_status_tapestation();


CREATE OR REPLACE FUNCTION "Lab".update_workflow_status_pcr()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE "Lab"."samples"
    SET "sample_status_id" = 'PCR Done', "time_modification" = CURRENT_TIMESTAMP
    WHERE "sample_id" = NEW.sample_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_workflow_status_pcr ON "Lab"."PCR";
CREATE TRIGGER trg_update_workflow_status_pcr
AFTER INSERT ON "Lab"."PCR"
FOR EACH ROW
EXECUTE FUNCTION "Lab".update_workflow_status_pcr();


CREATE OR REPLACE FUNCTION "Lab".update_workflow_status_qpcr()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE "Lab"."samples"
    SET "sample_status_id" = 'qPCR Done', "time_modification" = CURRENT_TIMESTAMP
    WHERE "sample_id" = NEW.sample_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_workflow_status_qpcr ON "Lab"."qPCR";
CREATE TRIGGER trg_update_workflow_status_qpcr
AFTER INSERT ON "Lab"."qPCR"
FOR EACH ROW
EXECUTE FUNCTION "Lab".update_workflow_status_qpcr();


CREATE OR REPLACE FUNCTION "Lab".update_workflow_status_library()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE "Lab"."samples"
    SET "sample_status_id" = 'Library Prep', "time_modification" = CURRENT_TIMESTAMP
    WHERE "sample_id" = NEW.sample_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_workflow_status_library ON "Lab"."Library";
CREATE TRIGGER trg_update_workflow_status_library
AFTER INSERT ON "Lab"."Library"
FOR EACH ROW
EXECUTE FUNCTION "Lab".update_workflow_status_library();


CREATE OR REPLACE FUNCTION "Lab".update_workflow_status_sequencing()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE "Lab"."samples"
    SET "sample_status_id" = 'Sequencing Done', "time_modification" = CURRENT_TIMESTAMP
    WHERE "sample_id" = NEW.sample_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_workflow_status_sequencing ON "Lab"."Sequencing";
CREATE TRIGGER trg_update_workflow_status_sequencing
AFTER INSERT ON "Lab"."Sequencing"
FOR EACH ROW
EXECUTE FUNCTION "Lab".update_workflow_status_sequencing();


CREATE OR REPLACE FUNCTION "Lab".update_workflow_status_bioinformatics()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE "Lab"."samples"
    SET "sample_status_id" = 'bioinformatics Done', "time_modification" = CURRENT_TIMESTAMP
    WHERE "sample_id" = NEW.sample_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_workflow_status_bioinformatics ON "Lab"."bioinformatics";
CREATE TRIGGER trg_update_workflow_status_bioinformatics
AFTER INSERT ON "Lab"."bioinformatics"
FOR EACH ROW
EXECUTE FUNCTION "Lab".update_workflow_status_bioinformatics();

-- ==========================================================
-- Initial data (as provided in your original script)

INSERT INTO "reference"."status" ("status_id", "description") VALUES
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
('bioinformatics Done', 'bioinformatics analysis is complete'),
('Unknown step', 'An unknown step has occurred in the workflow')
ON CONFLICT ("status_id") DO NOTHING;

INSERT INTO "reference"."samplesType" ("sample_type", "sample_typeAbrv", "description") VALUES
('DNA', 'D', 'Deoxyribonucleic Acid sample'),
('RNA', 'R', 'Ribonucleic Acid sample'),
('Library', 'L', 'Sequencing Library sample'),
('Water', 'W', 'Water sample'),
('Sediments', 'S', 'Sediment sample'),
('Tissue', 'T', 'Tissue sample'),
('Fish', 'F', 'Fish sample'),
('Sequencing', 'Q', 'Sequencing run output'),
('Dataset', 'Z', 'Processed dataset')
ON CONFLICT ("sample_type") DO NOTHING;



-- ======================================================================
-- 1. Extensions
--    Enabling powerful built-in PostgreSQL functionalities.
--    Note: Some extensions might require superuser privileges to install.
-- ======================================================================

-- Enables UUID generation (useful for unique IDs if not using sequences)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Enables trigram matching for fuzzy string searching (useful for full-text search and LIKE queries)
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Enables connecting to other PostgreSQL databases as foreign data sources
CREATE EXTENSION IF NOT EXISTS postgres_fdw;

-- Enables key-value store for flexible schema (e.g., for custom sample metadata)
CREATE EXTENSION IF NOT EXISTS hstore;

-- Enables tablefunc for crosstab queries (pivot tables)
CREATE EXTENSION IF NOT EXISTS tablefunc;

-- Enables spatial data types and functions (useful for LonLat_Postgis_Lat/Lon in sampling)
-- Note: PostGIS installation might be more complex and require specific server setup.
-- CREATE EXTENSION IF NOT EXISTS postgis;

-- Enables ltree for hierarchical data structures (e.g., complex taxon hierarchies)
CREATE EXTENSION IF NOT EXISTS ltree;

-- Enables pg_stat_statements for query performance monitoring (requires configuration in postgresql.conf)
-- CREATE EXTENSION IF NOT EXISTS pg_stat_statements;


-- ======================================================================
-- 2. Advanced Functions
--    Custom functions for common LIMS operations and data manipulation.
-- ======================================================================

-- Function to calculate DNA yield from Nanodrop/Qubit (already a GENERATED ALWAYS column in Qubit/Nanodrop)
-- This is an example of a general-purpose calculation function.
CREATE OR REPLACE FUNCTION "Lab".calculate_dna_yield_ug(
    volume_ul NUMERIC,
    concentration_ng_ul NUMERIC
)
RETURNS NUMERIC AS $$
BEGIN
    IF volume_ul IS NULL OR concentration_ng_ul IS NULL THEN
        RETURN NULL;
    END IF;
    RETURN (volume_ul * concentration_ng_ul) / 1000;
END;
$$ LANGUAGE plpgsql;

-- Function to get full person name by person_id
CREATE OR REPLACE FUNCTION "reference".get_full_person_name(p_person_id TEXT)
RETURNS TEXT AS $$
DECLARE
    full_name TEXT;
BEGIN
    SELECT "Full Name" INTO full_name FROM "reference"."personal" WHERE "person_id" = p_person_id;
    RETURN full_name;
END;
$$ LANGUAGE plpgsql;

-- Function to get sample type abbreviation by sample type name
CREATE OR REPLACE FUNCTION "reference".get_sample_type_abrv(p_sample_type TEXT)
RETURNS TEXT AS $$
DECLARE
    abrv TEXT;
BEGIN
    SELECT "sample_typeAbrv" INTO abrv FROM "reference"."samplesType" WHERE "sample_type" = p_sample_type;
    RETURN abrv;
END;
$$ LANGUAGE plpgsql;

-- Function to calculate age from a birth date (example for personal table if birthdate was added)
CREATE OR REPLACE FUNCTION "reference".calculate_age(p_birth_date DATE)
RETURNS INTEGER AS $$
BEGIN
    IF p_birth_date IS NULL THEN
        RETURN NULL;
    END IF;
    RETURN EXTRACT(YEAR FROM AGE(CURRENT_DATE, p_birth_date));
END;
$$ LANGUAGE plpgsql;

-- Function to get the current step name for a sample's workflow
CREATE OR REPLACE FUNCTION "Lims".get_current_workflow_step_name(p_workflow_id TEXT, p_step_id TEXT)
RETURNS TEXT AS $$
DECLARE
    step_name TEXT;
BEGIN
    SELECT ws.step_name INTO step_name
    FROM "Lims"."workflow_steps" ws
    WHERE ws.workflow_id = p_workflow_id AND ws.step_id = p_step_id;
    RETURN step_name;
END;
$$ LANGUAGE plpgsql;

-- Function to update the time_modification column automatically (if not already handled by default CURRENT_TIMESTAMP)
-- This function is generally good practice to have explicit triggers for last modification.
CREATE OR REPLACE FUNCTION update_time_modification()
RETURNS TRIGGER AS $$
BEGIN
    NEW.time_modification = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Example application of update_time_modification trigger to a table
-- You would apply this to all tables where you want explicit update timestamps.
/*
DROP TRIGGER IF EXISTS trg_update_time_modification_personal ON "reference"."personal";
CREATE TRIGGER trg_update_time_modification_personal
BEFORE UPDATE ON "reference"."personal"
FOR EACH ROW
EXECUTE FUNCTION update_time_modification();
*/

-- Function to get all child samples recursively for a given parent sample_id
CREATE OR REPLACE FUNCTION "Lab".get_all_child_samples_recursive(p_parent_sample_id TEXT)
RETURNS SETOF TEXT AS $$
BEGIN
    RETURN QUERY
    WITH RECURSIVE child_samples AS (
        SELECT sample_id
        FROM "Lab"."samples"
        WHERE "Parentsample_id" = p_parent_sample_id
        UNION ALL
        SELECT s.sample_id
        FROM "Lab"."samples" s
        JOIN child_samples cs ON s."Parentsample_id" = cs.sample_id
    )
    SELECT sample_id FROM child_samples;
END;
$$ LANGUAGE plpgsql;

-- Function to get the full workflow path for a sample (simplified example)
CREATE OR REPLACE FUNCTION "Lab".get_sample_workflow_path(p_sample_id TEXT)
RETURNS TEXT AS $$
DECLARE
    workflow_path TEXT := '';
    current_workflow TEXT;
    current_step TEXT;
BEGIN
    SELECT workflow_name, step_name INTO current_workflow, current_step
    FROM "Lab"."samples"
    WHERE sample_id = p_sample_id;

    IF current_workflow IS NOT NULL AND current_step IS NOT NULL THEN
        workflow_path := current_workflow || ' -> ' || (SELECT step_name FROM "Lims"."workflow_steps" WHERE workflow_id = current_workflow AND step_id = current_step);
    END IF;
    RETURN workflow_path;
END;
$$ LANGUAGE plpgsql;

-- Function to validate a specific ID format using regex (example for project_id)
CREATE OR REPLACE FUNCTION "Lims".validate_project_id_format(p_project_id TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN p_project_id ~ '^[A-Z]{3}_[A-Z0-9]{3}_[0-9]{3}$'; -- Example: PRO_ABC_001
END;
$$ LANGUAGE plpgsql;

-- Function to check reagent availability based on quantity (requires a 'quantity_available' column in Reagents)
-- Assuming a 'quantity_available' column is added to Lims.Reagents for tracking.
/*
ALTER TABLE "Lims"."Reagents" ADD COLUMN IF NOT EXISTS "quantity_available" NUMERIC;
*/
CREATE OR REPLACE FUNCTION "Lims".check_reagent_availability(
    p_reagent_id TEXT,
    p_required_quantity NUMERIC
)
RETURNS BOOLEAN AS $$
DECLARE
    available_qty NUMERIC;
BEGIN
    SELECT "quantity_available" INTO available_qty
    FROM "Lims"."Reagents"
    WHERE "Reagents_id" = p_reagent_id;

    IF NOT FOUND OR available_qty IS NULL THEN
        RETURN FALSE; -- Reagent not found or quantity not tracked
    END IF;

    RETURN available_qty >= p_required_quantity;
END;
$$ LANGUAGE plpgsql;


-- ======================================================================
-- 3. Indexes
--    Optimizing query performance by adding indexes on frequently
--    queried columns, especially foreign keys and columns in WHERE/ORDER BY.
-- ======================================================================

-- Lims Schema Indexes
CREATE INDEX IF NOT EXISTS idx_customers_customer_name ON "Lims"."customers" ("customer_name");
CREATE INDEX IF NOT EXISTS idx_customers_customer_abrv ON "Lims"."customers" ("customer_abrv");
CREATE INDEX IF NOT EXISTS idx_projects_status_id ON "Lims"."projects" ("status_id");
CREATE INDEX IF NOT EXISTS idx_projects_pi ON "Lims"."projects" ("PI");
CREATE INDEX IF NOT EXISTS idx_projects_customer_id ON "Lims"."projects" ("customer_id");
CREATE INDEX IF NOT EXISTS idx_cruises_project_id ON "Lims"."cruises" ("project_id");
CREATE INDEX IF NOT EXISTS idx_cruises_region_id ON "Lims"."cruises" ("region_id");
CREATE INDEX IF NOT EXISTS idx_cruises_ecosystem_id ON "Lims"."cruises" ("ecosystem_id");
CREATE INDEX IF NOT EXISTS idx_workflow_steps_workflow_id ON "Lims"."workflow_steps" ("workflow_id");
CREATE INDEX IF NOT EXISTS idx_sop_sopid_origin ON "Lims"."sop" ("SopId_Origin");
CREATE INDEX IF NOT EXISTS idx_primers_targetgene ON "Lims"."Primers" ("TargetGene");
CREATE INDEX IF NOT EXISTS idx_equipment_room_id ON "Lims"."Equipment" ("room_id");
CREATE INDEX IF NOT EXISTS idx_orders_project_id ON "Lims"."orders" ("project_id");
CREATE INDEX IF NOT EXISTS idx_orders_category ON "Lims"."orders" ("category");

-- Lab Schema Indexes
CREATE INDEX IF NOT EXISTS idx_experiments_sop_id ON "Lab"."Experiments" ("sop_id");
CREATE INDEX IF NOT EXISTS idx_experiments_person ON "Lab"."Experiments" ("person");
CREATE INDEX IF NOT EXISTS idx_experimentsprojects_experiment_id ON "Lab"."ExperimentsProjects" ("Experiment_id");
CREATE INDEX IF NOT EXISTS idx_experimentsprojects_project_id ON "Lab"."ExperimentsProjects" ("project_id");
CREATE INDEX IF NOT EXISTS idx_sampling_project_id ON "Lab"."sampling" ("project_id");
CREATE INDEX IF NOT EXISTS idx_sampling_cruise_id ON "Lab"."sampling" ("cruise_id");
CREATE INDEX IF NOT EXISTS idx_sampling_region_id ON "Lab"."sampling" ("region_id");
CREATE INDEX IF NOT EXISTS idx_sampling_ecosystem_id ON "Lab"."sampling" ("ecosystem_id");
CREATE INDEX IF NOT EXISTS idx_sampling_customer_id ON "Lab"."sampling" ("customer_id");
CREATE INDEX IF NOT EXISTS idx_sampling_sampling_date ON "Lab"."sampling" ("sampling_date");
CREATE INDEX IF NOT EXISTS idx_fishing_sampling_id ON "Lab"."fishing" ("sampling_id");
CREATE INDEX IF NOT EXISTS idx_fishing_taxon ON "Lab"."fishing" ("taxon");
CREATE INDEX IF NOT EXISTS idx_samples_sampling_id ON "Lab"."samples" ("sampling_id");
CREATE INDEX IF NOT EXISTS idx_samples_parentsample_id ON "Lab"."samples" ("Parentsample_id");
CREATE INDEX IF NOT EXISTS idx_samples_sample_type ON "Lab"."samples" ("sample_type");
CREATE INDEX IF NOT EXISTS idx_samples_project_id ON "Lab"."samples" ("project_id");
CREATE INDEX IF NOT EXISTS idx_storage_log_sample_id ON "Lab"."storage_log" ("sample_id");
CREATE INDEX IF NOT EXISTS idx_fish_parentsample_id ON "Lab"."fish" ("Parentsample_id");
CREATE INDEX IF NOT EXISTS idx_fish_species ON "Lab"."fish" ("species");
CREATE INDEX IF NOT EXISTS idx_tissue_parentsample_id ON "Lab"."Tissue" ("Parentsample_id");
CREATE INDEX IF NOT EXISTS idx_dna_parentsample_id ON "Lab"."DNA" ("Parentsample_id");
CREATE INDEX IF NOT EXISTS idx_rna_parentsample_id ON "Lab"."RNA" ("Parentsample_id");
CREATE INDEX IF NOT EXISTS idx_sediments_parentsample_id ON "Lab"."Sediments" ("Parentsample_id");
CREATE INDEX IF NOT EXISTS idx_water_parentsample_id ON "Lab"."Water" ("Parentsample_id");
CREATE INDEX IF NOT EXISTS idx_otoliths_sample_id ON "Lab"."Otoliths" ("sample_id");
CREATE INDEX IF NOT EXISTS idx_extraction_sample_id ON "Lab"."Extraction" ("sample_id");
CREATE INDEX IF NOT EXISTS idx_nanodrop_sample_id ON "Lab"."Nanodrop" ("sample_id");
CREATE INDEX IF NOT EXISTS idx_qubit_sample_id ON "Lab"."Qubit" ("sample_id");
CREATE INDEX IF NOT EXISTS idx_tapestation_sample_id ON "Lab"."Tapestation" ("sample_id");
CREATE INDEX IF NOT EXISTS idx_pcr_sample_id ON "Lab"."PCR" ("sample_id");
CREATE INDEX IF NOT EXISTS idx_gelelectrophoresis_sample_id ON "Lab"."Gelelectrophoresis" ("sample_id");
CREATE INDEX IF NOT EXISTS idx_qpcr_sample_id ON "Lab"."qPCR" ("sample_id");
CREATE INDEX IF NOT EXISTS idx_library_sample_id ON "Lab"."Library" ("Lib_id"); -- Corrected to Lib_id
CREATE INDEX IF NOT EXISTS idx_sequencing_sample_id ON "Lab"."Sequencing" ("sample_id");
CREATE INDEX IF NOT EXISTS idx_sequencing_library_id ON "Lab"."Sequencing" ("Library_id");
CREATE INDEX IF NOT EXISTS idx_datasets_customer_id ON "Lab"."datasets" ("customer_id");
CREATE INDEX IF NOT EXISTS idx_datasets_ecosystem_id ON "Lab"."datasets" ("ecosystem_id");
CREATE INDEX IF NOT EXISTS idx_datasets_region_id ON "Lab"."datasets" ("region_id");
CREATE INDEX IF NOT EXISTS idx_bioinformatics_sample_id ON "Lab"."bioinformatics" ("sample_id");
CREATE INDEX IF NOT EXISTS idx_bioinformatics_sequencing_id ON "Lab"."bioinformatics" ("sequencing_id");

-- Bioinformatics Schema Indexes
CREATE INDEX IF NOT EXISTS idx_analysis_runs_pipeline_id ON "bioinformatics"."analysis_runs" ("pipeline_id");
CREATE INDEX IF NOT EXISTS idx_analysis_runs_sequencing_run_id ON "bioinformatics"."analysis_runs" ("sequencing_run_id");
CREATE INDEX IF NOT EXISTS idx_edna_assignments_run_id ON "bioinformatics"."edna_assignments" ("run_id");
CREATE INDEX IF NOT EXISTS idx_edna_assignments_sample_id ON "bioinformatics"."edna_assignments" ("sample_id");
CREATE INDEX IF NOT EXISTS idx_edna_assignments_taxon_id ON "bioinformatics"."edna_assignments" ("taxon_id");

-- Partial Index Example: Index only active projects
CREATE INDEX IF NOT EXISTS idx_projects_active ON "Lims"."projects" ("project_id") WHERE status_id = 'Active';

-- Expression Index Example: Index on lowercased customer name for case-insensitive searches (if not using trigram/full-text)
CREATE INDEX IF NOT EXISTS idx_customers_lower_name ON "Lims"."customers" (LOWER("customer_name"));

-- Index for ltree path if taxon hierarchy is stored using ltree
-- ALTER TABLE "reference"."taxon" ADD COLUMN IF NOT EXISTS path LTREE;
-- UPDATE "reference"."taxon" SET path = 'taxon_id_root'::ltree || taxon_id::ltree WHERE taxon_parent IS NULL;
-- UPDATE "reference"."taxon" t SET path = p.path || t.taxon_id::ltree FROM "reference"."taxon" p WHERE t.taxon_parent = p.taxon_id AND t.taxon_parent IS NOT NULL;
-- CREATE INDEX IF NOT EXISTS idx_taxon_path ON "reference"."taxon" USING GIST (path);
-- CREATE INDEX IF NOT EXISTS idx_taxon_path_btree ON "reference"."taxon" USING BTREE (path);


-- ======================================================================
-- 4. Views
--    Creating virtual tables for simplified data access and complex joins.
-- ======================================================================

-- View: Complete_species_Names/taxon views
-- Combines taxon and species information for a comprehensive species lookup.
CREATE OR REPLACE VIEW "reference"."Complete_Species_Taxon_View" AS
SELECT
    t.taxon_id,
    t."DE_name" AS taxon_de_name,
    t."En_name" AS taxon_en_name,
    t.rank,
    t.description AS taxon_description,
    s.species AS species_id,
    s."DE_name" AS species_de_name,
    s."En_name" AS species_en_name,
    s.maxlength,
    s.max_age,
    s.description AS species_description
FROM
    "reference"."taxon" t
LEFT JOIN
    "reference"."species" s ON t.taxon_id = s.species;

-- View: Detailed_Samples_View
-- Provides a comprehensive view of samples with related information from sampling, project, and customer.
CREATE OR REPLACE VIEW "Lab"."Detailed_Samples_View" AS
SELECT
    s."sample_id",
    s."External_Name",
    s."Parentsample_id",
    s."sampling_id",
    samp."Location" AS sampling_location, -- Using "Location" from sampling table
    samp."Depth_m" AS sampling_depth, -- Corrected column name to "Depth_m"
    s."storage_id",
    st."Freezer" AS storage_freezer, -- Corrected column name to "Freezer"
    st."Box" AS storage_box, -- Corrected column name to "Box"
    s."sampler",
    s."Reciever",
    s."Reception_date",
    s."Transport",
    s."Conservation/Buffer",
    s."sample_type",
    stype."sample_typeAbrv",
    s."sample_status_id",
    s."workflow_name",
    s."step_name",
    s."project_id",
    p."Title" AS project_title,
    s."customer_id",
    c."customer_name",
    c."customer_abrv",
    s."description",
    s."attachment",
    s."modified_by",
    s."time_modification"
FROM
    "Lab"."samples" s
LEFT JOIN
    "Lab"."sampling" samp ON s.sampling_id = samp.sampling_id
LEFT JOIN
    "Lab"."storage" st ON s.storage_id = st.storage_id
LEFT JOIN
    "Lims"."projects" p ON s.project_id = p.project_id
LEFT JOIN
    "Lims"."customers" c ON s.customer_id = c.customer_id
LEFT JOIN
    "reference"."samplesType" stype ON s.sample_type = stype.sample_type;


-- View: Project_Overview_View
-- Summarizes project details with PI and customer names.
CREATE OR REPLACE VIEW "Lims"."Project_Overview_View" AS
SELECT
    p."project_id",
    p."Title",
    p."status_id",
    p."PI" AS pi_person_id, -- Corrected column name to "PI"
    ref_p."Full Name" AS pi_full_name,
    p."Funder",
    p."customer_id",
    c."customer_name",
    c."customer_abrv",
    p."Start_date", -- Corrected column name to "Start_date"
    p."End_date", -- Corrected column name to "End_date"
    p."Report_date",
    p."description",
    p."time_modification"
FROM
    "Lims"."projects" p
LEFT JOIN
    "Lims"."customers" c ON p.customer_id::TEXT = c.customer_id::TEXT -- Explicit cast for robustness
LEFT JOIN
    "reference"."personal" ref_p ON p."PI" = ref_p."person_id"; -- Corrected column name to "PI"

-- View: Sample_Workflow_Progress_View
-- Shows the current status of each sample within its assigned workflow.
CREATE OR REPLACE VIEW "Lab"."Sample_Workflow_Progress_View" AS
SELECT
    s."sample_id",
    s."External_Name",
    s."sample_type",
    s."sample_status_id" AS current_status,
    s."workflow_name",
    ws."step_name" AS current_workflow_step,
    ws."step_number",
    ws."workflow_status_id" AS step_status,
    s."time_modification" AS last_sample_update
FROM
    "Lab"."samples" s
LEFT JOIN
    "Lims"."workflow_steps" ws ON s.workflow_name = ws.workflow_id AND s.step_name = ws.step_id; -- Assuming step_name in samples is actually step_id


-- View: Storage_Inventory_View
-- Provides details on samples stored in each storage location.
CREATE OR REPLACE VIEW "Lab"."Storage_Inventory_View" AS
SELECT
    st."storage_id",
    st."room_id",
    r."address" AS room_address,
    st."Freezer", -- Corrected column name to "Freezer"
    st."Etage",
    st."Temperature_C",
    st."Box", -- Corrected column name to "Box"
    st."Box_size_X",
    st."Box_size_Y",
    s."sample_id",
    s."External_Name" AS sample_external_name,
    s."sample_type",
    s."storage_position" AS sample_storage_position,
    s."Reception_date" AS sample_reception_date,
    s."project_id"
FROM
    "Lab"."storage" st
LEFT JOIN
    "reference"."room" r ON st."room_id" = r."room_id"
LEFT JOIN
    "Lab"."samples" s ON st."storage_id" = s."storage_id" AND s."storage_position" = s."storage_position";

-- View: Experiment_Summary_View
-- Summarizes key information for each experiment.
CREATE OR REPLACE VIEW "Lab"."Experiment_Summary_View" AS
SELECT
    e."Experiment_id",
    e."Experiment_title",
    e."aim",
    e."Method",
    e."sop_id",
    sop."Title" AS sop_title,
    e."date" AS experiment_date,
    e."person" AS experiment_person_id,
    ref_p."Full Name" AS experiment_person_name,
    e."LabBook",
    e."status_id",
    COUNT(DISTINCT es."sample_id") AS number_of_samples,
    COUNT(DISTINCT ep."project_id") AS number_of_projects
FROM
    "Lab"."Experiments" e
LEFT JOIN
    "Lims"."sop" sop ON e."sop_id" = sop."sop_id"
LEFT JOIN
    "reference"."personal" ref_p ON e."person" = ref_p."person_id"
LEFT JOIN
    "Lab"."Experimentsamples" es ON e."Experiment_id" = es."Experiment_id"
LEFT JOIN
    "Lab"."ExperimentsProjects" ep ON e."Experiment_id" = ep."Experiment_id"
GROUP BY
    e."Experiment_id", e."Experiment_title", e."aim", e."Method", e."sop_id", sop."Title",
    e.date, e.person, ref_p."Full Name", e."LabBook", e."status_id";

-- View: Bioinformatics_Results_Summary
-- Provides a summary of bioinformatics analysis results.
CREATE OR REPLACE VIEW "bioinformatics"."Analysis_Results_Summary" AS
SELECT
    ar."run_id",
    ar."run_date",
    ar."person_id",
    ref_p."Full Name" AS analyst_name,
    ap."name" AS pipeline_name,
    ap."version" AS pipeline_version,
    ar."sequencing_run_id",
    s."sample_id",
    s."External_Name" AS sample_external_name,
    ea."taxon_id",
    t."En_name" AS taxon_english_name,
    ea."read_count",
    ea."confidence",
    ar."description" AS run_description,
    ea."description" AS assignment_description
FROM
    "bioinformatics"."analysis_runs" ar
JOIN
    "bioinformatics"."analysis_pipelines" ap ON ar.pipeline_id = ap.pipeline_id
JOIN
    "Lab"."Sequencing" seq ON ar.sequencing_run_id = seq."Seq_id"
JOIN
    "Lab"."samples" s ON seq.sample_id = s.sample_id
LEFT JOIN
    "bioinformatics"."edna_assignments" ea ON ar.run_id = ea.run_id AND s.sample_id = ea.sample_id
LEFT JOIN
    "reference"."personal" ref_p ON ar.person_id = ref_p.person_id
LEFT JOIN
    "reference"."taxon" t ON ea.taxon_id = t.taxon_id;


-- View: Reagent_Expiry_Alerts_View
-- Lists reagents that are expired or expiring soon.
CREATE OR REPLACE VIEW "Lims"."Reagent_Expiry_Alerts_View" AS
SELECT
    "Reagents_id",
    "Reagent_CompleteName",
    "Lot",
    "Expire_date",
    "Reception_date",
    "project_id",
    "status_id"
FROM
    "Lims"."Reagents"
WHERE
    "Expire_date" IS NOT NULL AND "Expire_date" < (CURRENT_DATE + INTERVAL '30 days')
ORDER BY
    "Expire_date";

-- Materialized View Example: Monthly Sample Reception Summary
-- Useful for frequently accessed aggregate data that doesn't need real-time updates.
CREATE MATERIALIZED VIEW IF NOT EXISTS "Lab"."Monthly_Sample_Reception_MV" AS
SELECT
    TO_CHAR("Reception_date", 'YYYY-MM') AS reception_month,
    sample_type,
    COUNT(sample_id) AS total_samples_received
FROM
    "Lab"."samples"
WHERE
    "Reception_date" IS NOT NULL
GROUP BY
    1, 2
ORDER BY
    1, 2
WITH DATA;

-- To refresh a materialized view (e.g., daily or weekly)
-- REFRESH MATERIALIZED VIEW "Lab"."Monthly_Sample_Reception_MV";

-- View: Current_Storage_Summary
-- Provides a summary of currently stored samples by type and location.
CREATE OR REPLACE VIEW "Lab"."Current_Storage_Summary" AS
SELECT
    s.storage_id,
    st.room_id,
    st."Freezer", -- Corrected column name to "Freezer"
    st."Box", -- Corrected column name to "Box"
    s.sample_type,
    COUNT(s.sample_id) AS number_of_samples
FROM
    "Lab"."samples" s
JOIN
    "Lab"."storage" st ON s.storage_id = st.storage_id
GROUP BY
    s.storage_id, st."Freezer", st."Box", s.sample_type -- Corrected column names to "Freezer", "Box"
ORDER BY
    s.storage_id, s.sample_type;


-- ======================================================================
-- 5. Triggers (Updated and New)
--    Adding new triggers for advanced validation and data consistency.
-- ======================================================================

-- Trigger to ensure sample's sampling_date is within parent sampling record's dates
CREATE OR REPLACE FUNCTION "Lab".validate_sample_sampling_date()
RETURNS TRIGGER AS $$
DECLARE
    sampling_start_date DATE;
    sampling_end_date DATE;
BEGIN
    IF NEW.sampling_id IS NOT NULL THEN
        SELECT "start_at", "end_at" -- Corrected column names to "start_at", "end_at"
        INTO sampling_start_date, sampling_end_date
        FROM "Lab"."sampling"
        WHERE sampling_id = NEW.sampling_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Referenced sampling_id % does not exist in "Lab"."sampling".', NEW.sampling_id;
        END IF;

        IF NEW.sampling_date IS NOT NULL AND sampling_start_date IS NOT NULL AND NEW.sampling_date < sampling_start_date THEN
            RAISE EXCEPTION 'Sample sampling_date (%) cannot be before parent sampling start_at (%).', NEW.sampling_date, sampling_start_date;
        END IF;

        IF NEW.sampling_date IS NOT NULL AND sampling_end_date IS NOT NULL AND NEW.sampling_date > sampling_end_date THEN
            RAISE EXCEPTION 'Sample sampling_date (%) cannot be after parent sampling end_at (%).', NEW.sampling_date, sampling_end_date;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_validate_sample_sampling_date ON "Lab"."samples";
CREATE TRIGGER trg_validate_sample_sampling_date
BEFORE INSERT OR UPDATE ON "Lab"."samples"
FOR EACH ROW
EXECUTE FUNCTION "Lab".validate_sample_sampling_date();

-- Trigger to update reagent quantity on order receipt (example)
-- Requires a 'quantity_change' column in orders and 'quantity_available' in Reagents
/*
ALTER TABLE "Lims"."orders" ADD COLUMN IF NOT EXISTS "quantity_change" NUMERIC;
ALTER TABLE "Lims"."Reagents" ADD COLUMN IF NOT EXISTS "quantity_available" NUMERIC DEFAULT 0;

CREATE OR REPLACE FUNCTION "Lims".update_reagent_quantity_on_order()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status_id = 'Received' AND NEW.quantity_change IS NOT NULL THEN
        UPDATE "Lims"."Reagents"
        SET "quantity_available" = COALESCE("quantity_available", 0) + NEW.quantity_change
        WHERE "Reagents_id" = NEW.item; -- Assuming 'item' in orders refers to Reagents_id
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_reagent_qty_on_order ON "Lims"."orders";
CREATE TRIGGER trg_update_reagent_qty_on_order
AFTER UPDATE OF status_id ON "Lims"."orders"
FOR EACH ROW
WHEN (OLD.status_id IS DISTINCT FROM NEW.status_id)
EXECUTE FUNCTION "Lims".update_reagent_quantity_on_order();
*/

-- Trigger to log storage movements (already exists as storage_log table and trigger)
-- This is a review to ensure it's comprehensive.
-- The existing `Lab.storage_log` table and its implicit insert trigger (if serial primary key) or explicit trigger
-- should cover this. If you need more granular logging (e.g., on update of storage_id/position in samples),
-- a trigger on Lab.samples could be added.
/*
CREATE OR REPLACE FUNCTION "Lab".log_sample_storage_movement()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.storage_id IS DISTINCT FROM NEW.storage_id OR OLD.storage_position IS DISTINCT FROM NEW.storage_position THEN
        INSERT INTO "Lab"."storage_log" (sample_id, storage_id, person_id, status, storage_position, description)
        VALUES (NEW.sample_id, NEW.storage_id, NEW.modified_by, 'Moved', NEW.storage_position, 'Sample moved to new location');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_log_sample_storage_movement ON "Lab"."samples";
CREATE TRIGGER trg_log_sample_storage_movement
AFTER UPDATE OF storage_id, storage_position ON "Lab"."samples"
FOR EACH ROW
EXECUTE FUNCTION "Lab".log_sample_storage_movement();
*/


-- ======================================================================
-- 6. Constraints (Updated and New)
--    Reviewing existing constraints and adding complex ones.
-- ======================================================================

-- All Foreign Keys are already defined in the table creation.
-- All CHECK constraints are already defined in the base schema.
-- No new constraints are added here, but the existing ones are crucial for data integrity.
-- The `trg_validate_sample_sampling_date` trigger above adds a more complex date constraint.

-- Example: Check constraint for unique SOP version (already handled by unique on sop_id)
-- ALTER TABLE "Lims"."sop" ADD CONSTRAINT chk_sop_unique_version UNIQUE ("SopId_Origin", "version");
-- This is already implicitly handled by the sop_id generation logic if SopId_Origin and version are part of it.

-- Example: Exclusion constraint for overlapping cruises (requires btree_gist extension if not using PostGIS for spatial)
-- CREATE EXTENSION IF NOT EXISTS btree_gist;
/*
ALTER TABLE "Lims"."cruises"
ADD CONSTRAINT ex_cruises_overlap EXCLUDE USING GIST (
    DATERANGE("start_date", "end_date", '[]') WITH &&
) WHERE (project_id IS NOT NULL); -- Example: No overlapping cruises for the same project
*/


-- ======================================================================
-- 7. Partitioning by Year
--    Implementing declarative partitioning for selected large tables
--    based on a year column to improve performance and manageability.
--    This requires converting the original table to a partitioned table
--    and creating child partitions.
--    Note: This is a significant structural change and should be planned carefully.
--    The examples below assume the tables are NOT yet partitioned.
--    If they are, you'd need to adapt.
-- ======================================================================

-- Partitioning for Lab.sampling
-- If "Lab"."sampling" is not already partitioned, execute this block.
-- This will rename the original table, create a new partitioned table,
-- and migrate data.
DO $$
BEGIN
    IF (SELECT relispartition FROM pg_class WHERE relname = 'sampling' AND relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'Lab')) IS NOT TRUE THEN
        -- Rename original table
        ALTER TABLE "Lab"."sampling" RENAME TO "sampling_old";

        -- Create new partitioned table
        CREATE TABLE "Lab"."sampling" (
            "sampling_id" TEXT NOT NULL,
            "Experiment_id" TEXT REFERENCES "Lab"."Experiments"("Experiment_id"),
            "project_id" TEXT NOT NULL REFERENCES "Lims"."projects"("project_id") ON DELETE CASCADE,
            "cruise_id" TEXT REFERENCES "Lims"."cruises"("cruise_id"),
            "region_id" TEXT REFERENCES "reference"."region"("region_id"),
            "ecosystem_id" TEXT REFERENCES "reference"."ecosystem"("ecosystem_id"),
            "vessel_id" TEXT REFERENCES "reference"."vessel"("vessel_id"),
            "kunden_id" TEXT REFERENCES "Lims"."customers"("customer_id"),
            "sampling_date" DATE,
            "LonLat_Postgis_Lat" NUMERIC,
            "LonLat_Postgis_Lon" NUMERIC,
            "Depth_m" NUMERIC,
            "Location" TEXT,
            "start_at" date,
            "end_at" date,
            "Temperature_Atmospheric_c" NUMERIC,
            "Weather" TEXT,
            "Wind" TEXT,
            "WindUnit" TEXT,
            "TemperaturesamplingDepth_c" NUMERIC,
            "Salinity" NUMERIC,
            "SalinityUnit" TEXT,
            "Pressure" NUMERIC,
            "PressureUnit" TEXT,
            "Oxygen" NUMERIC,
            "OxygenUnit" TEXT,
            "Conducitivity" NUMERIC,
            "ConductivityUnit" TEXT,
            "pH" NUMERIC,
            "Nitrate_mgL" NUMERIC,
            "Phosphate_mgL" NUMERIC,
            "Turbidity_NTU" NUMERIC,
            "Chlorophyll_a_ugL" NUMERIC,
            "CurrentSpeed_m_s" NUMERIC,
            "CurrentDirection_deg" NUMERIC,
            "TideStage" TEXT,
            "Light_PAR_umol_m2_s" NUMERIC,
            "SeaState" TEXT,
            "sampleVolume_L" NUMERIC,
            "sampleType" TEXT,
            "Preservative" TEXT,
            "CloudCoverPercent" NUMERIC,
            "Rainfall_mm" NUMERIC,
            "InstrumentID" TEXT,
            "CalibrationDate" DATE,
            "Visibility_m" NUMERIC,
            "fishing_date" DATE,
            "fishing_time_min" TIME,
            "fishing_method" TEXT,
            "GearType" TEXT,
            "SoakTime" NUMERIC,
            "SoakTimeUnit" TEXT,
            "TrawlSpeed" NUMERIC,
            "TrawlSpeedUnit" TEXT,
            "Total_catch_quantity_kg" NUMERIC,
            "Total_catch_quantity_fish" NUMERIC,
            "catch_notes" TEXT,
            "Operation_duration_min" NUMERIC,
            "fishingStart_location" NUMERIC,
            "fishingEnd_location" NUMERIC,
            "sampler" text REFERENCES "reference"."personal"("person_id"),
            "Together_With" TEXT,
            "status_id" TEXT REFERENCES "reference"."status"("status_id") DEFAULT 'Received' NOT NULL,
            "customer_id" text REFERENCES "Lims"."customers"("customer_id"),
            "description" TEXT,
            "attachment" BYTEA,
            "modified_by" text REFERENCES "reference"."personal"("person_id"),
            "time_modification" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
        ) PARTITION BY RANGE ("sampling_date");

        -- Re-add primary key to the new partitioned table (PRIMARY KEY on partitioned tables requires all partition keys)
        ALTER TABLE "Lab"."sampling" ADD PRIMARY KEY ("sampling_id", "sampling_date");

        -- Re-add indexes from the old table to the new partitioned table (excluding the one on sampling_id if it's part of PK)
        -- Note: Indexes on partitioned tables are created per partition.
        -- You might need to manually create them on each child partition or define them on the master.
        CREATE INDEX IF NOT EXISTS idx_sampling_project_id ON "Lab"."sampling" ("project_id");
        CREATE INDEX IF NOT EXISTS idx_sampling_cruise_id ON "Lab"."sampling" ("cruise_id");
        CREATE INDEX IF NOT EXISTS idx_sampling_region_id ON "Lab"."sampling" ("region_id");
        CREATE INDEX IF NOT EXISTS idx_sampling_ecosystem_id ON "Lab"."sampling" ("ecosystem_id");
        CREATE INDEX IF NOT EXISTS idx_sampling_customer_id ON "Lab"."sampling" ("customer_id");
        -- The primary key index will cover sampling_id and sampling_date

        -- Migrate existing data from old table to new partitioned table
        INSERT INTO "Lab"."sampling" SELECT * FROM "Lab"."sampling_old";
        DROP TABLE "Lab"."sampling_old"; -- Drop old table after successful migration

        -- Re-create the trigger for sampling_id generation, pointing to the new table
        DROP TRIGGER IF EXISTS trg_generate_sampling_id ON "Lab"."sampling";
        CREATE TRIGGER trg_generate_sampling_id
        BEFORE INSERT ON "Lab"."sampling"
        FOR EACH ROW
        EXECUTE FUNCTION "Lab".generate_sampling_id();

    END IF;
END $$;

-- Create a function to create partitions dynamically for Lab.sampling
CREATE OR REPLACE FUNCTION "Lab".create_sampling_partition_if_not_exists()
RETURNS TRIGGER AS $$
DECLARE
    partition_date DATE;
    partition_name TEXT;
    start_date DATE;
    end_date DATE;
BEGIN
    partition_date := NEW.sampling_date;
    IF partition_date IS NULL THEN
        RAISE EXCEPTION 'Cannot partition on NULL sampling_date. Please provide a sampling_date.';
    END IF;

    start_date := DATE_TRUNC('year', partition_date);
    end_date := DATE_TRUNC('year', partition_date) + INTERVAL '1 year';
    partition_name := 'sampling_y' || TO_CHAR(start_date, 'YYYY');

    EXECUTE 'CREATE TABLE IF NOT EXISTS "Lab".' || quote_ident(partition_name) || ' PARTITION OF "Lab"."sampling"
             FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Attach the trigger to the main partitioned table (if not already attached by the DO block)
DROP TRIGGER IF EXISTS trg_create_sampling_partition ON "Lab"."sampling";
CREATE TRIGGER trg_create_sampling_partition
BEFORE INSERT ON "Lab"."sampling"
FOR EACH ROW
EXECUTE FUNCTION "Lab".create_sampling_partition_if_not_exists();

-- Helper function for manual partition creation (e.g., for initial setup or future years)
CREATE OR REPLACE FUNCTION "Lab".create_sampling_partition_if_not_exists_manual(p_year INTEGER)
RETURNS VOID AS $$
DECLARE
    start_date DATE;
    end_date DATE;
    partition_name TEXT;
BEGIN
    start_date := MAKE_DATE(p_year, 1, 1);
    end_date := MAKE_DATE(p_year + 1, 1, 1);
    partition_name := 'sampling_y' || p_year;

    EXECUTE 'CREATE TABLE IF NOT EXISTS "Lab".' || quote_ident(partition_name) || ' PARTITION OF "Lab"."sampling"
             FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';
END;
$$ LANGUAGE plpgsql;

-- Create initial partitions for current and next year for Lab.sampling (example)
SELECT "Lab".create_sampling_partition_if_not_exists_manual(EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER);
SELECT "Lab".create_sampling_partition_if_not_exists_manual(EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER + 1);


-- Partitioning for Lab.samples
DO $$
BEGIN
    IF (SELECT relispartition FROM pg_class WHERE relname = 'samples' AND relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'Lab')) IS NOT TRUE THEN
        -- Rename original table
        ALTER TABLE "Lab"."samples" RENAME TO "samples_old";

        -- Create new partitioned table
        CREATE TABLE "Lab"."samples" (
            "sample_id" text NOT NULL,
            "External_Name" text,
            "Parentsample_id" text REFERENCES "Lab"."samples"("sample_id"),
            "sampling_id" text, -- This will now refer to the partitioned sampling table
            "storage_id" text REFERENCES "Lab"."storage"("storage_id"),
            "storage_position" numeric,
            "sampler" text REFERENCES "reference"."personal"("person_id"),
            "Reciever" text REFERENCES "reference"."personal"("person_id"),
            "sampling_date" date, -- Partition key
            "Reception_date" date,
            "Transport" text,
            "Conservation/Buffer" text,
            "sample_type" text NOT NULL REFERENCES "reference"."samplesType"("sample_type"),
            "sample_status_id" text REFERENCES "reference"."status"("status_id") DEFAULT 'Received' NOT NULL,
            "workflow_name" TEXT REFERENCES "Lims"."workflows"("workflow_id"),
            "step_name" TEXT REFERENCES "Lims"."workflow_steps"("step_id"),
            "project_id" text REFERENCES "Lims"."projects"("project_id"),
            "customer_id" text REFERENCES "Lims"."customers"("customer_id"),
            "description" text,
            "attachment" bytea,
            "modified_by" text REFERENCES "reference"."personal"("person_id"),
            "time_modification" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
        ) PARTITION BY RANGE ("sampling_date");

        -- Re-add primary key to the new partitioned table
        ALTER TABLE "Lab"."samples" ADD PRIMARY KEY ("sample_id", "sampling_date");

        -- Re-establish the foreign key to the partitioned sampling table
        -- Note: This FK needs to reference the primary key of the partitioned table, which now includes sampling_date.
        -- If sampling_id alone is not unique, this FK might need adjustment or a unique index on (sampling_id, sampling_date)
        -- in the sampling table. Assuming for now that sampling_id is globally unique across all partitions for simplicity.
        -- If not, a more complex FK or trigger-based validation might be needed.
        ALTER TABLE "Lab"."samples" ADD CONSTRAINT fk_samples_sampling_id FOREIGN KEY (sampling_id) REFERENCES "Lab"."sampling"(sampling_id);

        -- Migrate existing data from old table to new partitioned table
        INSERT INTO "Lab"."samples" SELECT * FROM "Lab"."samples_old";
        DROP TABLE "Lab"."samples_old"; -- Drop old table after successful migration

        -- Re-create the trigger for sample_id generation, pointing to the new table
        DROP TRIGGER IF EXISTS trg_generate_sample_id ON "Lab"."samples";
        CREATE TRIGGER trg_generate_sample_id
        BEFORE INSERT ON "Lab"."samples"
        FOR EACH ROW
        EXECUTE FUNCTION "Lab".generate_sample_id();

    END IF;
END $$;

-- Create a function to create partitions dynamically for Lab.samples
CREATE OR REPLACE FUNCTION "Lab".create_samples_partition_if_not_exists()
RETURNS TRIGGER AS $$
DECLARE
    partition_date DATE;
    partition_name TEXT;
    start_date DATE;
    end_date DATE;
BEGIN
    partition_date := NEW.sampling_date;
    IF partition_date IS NULL THEN
        RAISE EXCEPTION 'Cannot partition on NULL sampling_date for Lab.samples. Please provide a sampling_date.';
    END IF;

    start_date := DATE_TRUNC('year', partition_date);
    end_date := DATE_TRUNC('year', partition_date) + INTERVAL '1 year';
    partition_name := 'samples_y' || TO_CHAR(start_date, 'YYYY');

    EXECUTE 'CREATE TABLE IF NOT EXISTS "Lab".' || quote_ident(partition_name) || ' PARTITION OF "Lab"."samples"
             FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Attach the trigger to the main partitioned samples table (if not already attached by the DO block)
DROP TRIGGER IF EXISTS trg_create_samples_partition ON "Lab"."samples";
CREATE TRIGGER trg_create_samples_partition
BEFORE INSERT ON "Lab"."samples"
FOR EACH ROW
EXECUTE FUNCTION "Lab".create_samples_partition_if_not_exists();

-- Helper function for manual partition creation for Lab.samples
CREATE OR REPLACE FUNCTION "Lab".create_samples_partition_if_not_exists_manual(p_year INTEGER)
RETURNS VOID AS $$
DECLARE
    start_date DATE;
    end_date DATE;
    partition_name TEXT;
BEGIN
    start_date := MAKE_DATE(p_year, 1, 1);
    end_date := MAKE_DATE(p_year + 1, 1, 1);
    partition_name := 'samples_y' || p_year;

    EXECUTE 'CREATE TABLE IF NOT EXISTS "Lab".' || quote_ident(partition_name) || ' PARTITION OF "Lab"."samples"
             FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';
END;
$$ LANGUAGE plpgsql;

-- Create initial partitions for current and next year for Lab.samples (example)
SELECT "Lab".create_samples_partition_if_not_exists_manual(EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER);
SELECT "Lab".create_samples_partition_if_not_exists_manual(EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER + 1);


-- You can apply this partitioning pattern to other tables with a clear date column
-- (e.g., Lab.Sequencing, Lab.Extraction, Lab.Nanodrop, Lab.Qubit, Lab.Tapestation, Lab.PCR, Lab.qPCR, Lab.Library, Lab.bioinformatics, bioinformatics.analysis_runs)
-- by adapting the DO block and trigger/function logic for each table.


-- ======================================================================
-- 8. Transactions Examples
--    Demonstrating atomic operations for data integrity.
-- ======================================================================

-- Example 1: Successful Transaction
BEGIN;
    INSERT INTO "Lims"."customers" ("customer_name", "customer_abrv", "address", "mail", "phone")
    VALUES ('New Customer Inc.', 'NCI', '123 Main St', 'contact@newcustomer.com', '555-1234');

    INSERT INTO "Lims"."projects" ("project_id", "Title", "customer_id", "PI")
    VALUES ('PROJ_NEW_001', 'New Research Project', (SELECT "customer_id" FROM "Lims"."customers" WHERE "customer_abrv" = 'NCI'), 'person_id_example'); -- Replace with actual person_id

COMMIT;

-- Example 2: Transaction with Rollback (e.g., due to an error or condition)
BEGIN;
    INSERT INTO "Lims"."customers" ("customer_name", "customer_abrv", "address", "mail", "phone")
    VALUES ('Another Customer Ltd.', 'ACL', '456 Oak Ave', 'info@anothercustomer.com', '555-5678');

    -- This insert might fail if 'NonExistentPI' is not a valid person_id, triggering a rollback
    INSERT INTO "Lims"."projects" ("project_id", "Title", "customer_id", "PI")
    VALUES ('PROJ_FAIL_001', 'Failing Project', (SELECT "customer_id" FROM "Lims"."customers" WHERE "customer_abrv" = 'ACL'), 'NonExistentPI');

ROLLBACK; -- If the second insert fails, the first one is also rolled back.


-- ======================================================================
-- 9. Aggregates Examples
--    Common aggregate functions for data analysis.
-- ======================================================================

-- Total number of samples per sample type
SELECT
    st.sample_type,
    COUNT(s.sample_id) AS total_samples
FROM
    "reference"."samplesType" st
LEFT JOIN
    "Lab"."samples" s ON st.sample_type = s.sample_type
GROUP BY
    st.sample_type
ORDER BY
    total_samples DESC;

-- Average DNA concentration per extraction method
SELECT
    "ExtractionMethod",
    AVG("Concentration_ngul") AS average_concentration_ng_ul
FROM
    "Lab"."DNA"
WHERE
    "Concentration_ngul" IS NOT NULL
GROUP BY
    "ExtractionMethod"
HAVING
    COUNT("Concentration_ngul") > 1 -- Only show methods with more than one measurement
ORDER BY
    average_concentration_ng_ul DESC;

-- Count of samples received per year
SELECT
    EXTRACT(YEAR FROM "Reception_date") AS reception_year,
    COUNT("sample_id") AS samples_received
FROM
    "Lab"."samples"
WHERE
    "Reception_date" IS NOT NULL
GROUP BY
    reception_year
ORDER BY
    reception_year;

-- Max and Min length of fish by species
SELECT
    cs.species_en_name,
    MAX(f.total_length_mm) AS max_length_mm,
    MIN(f.total_length_mm) AS min_length_mm,
    AVG(f.weight_g) AS avg_weight_g
FROM
    "Lab"."fish" f
JOIN
    "reference"."Complete_Species_Taxon_View" cs ON f.species = cs.species_id
GROUP BY
    cs.species_en_name
ORDER BY
    max_length_mm DESC;


-- ======================================================================
-- 10. Full-Text Search Configuration
--     Setting up full-text search for efficient text-based queries.
-- ======================================================================

-- ======================================================================
-- 10. Full-Text Search Configuration
--     Setting up full-text search for efficient text-based queries.
-- ======================================================================

-- Check if the configuration exists before creating it
DO $$
BEGIN
    -- Check if the configuration exists
    IF NOT EXISTS (
        SELECT 1
        FROM pg_catalog.pg_ts_config
        WHERE cfgname = 'lims_english'
    ) THEN
        -- Create the text search configuration
        CREATE TEXT SEARCH CONFIGURATION "public"."lims_english" (
            PARSER = pg_catalog."default"
        );
        
        -- Alter the text search configuration to use the English stemming dictionary
        ALTER TEXT SEARCH CONFIGURATION "public"."lims_english"
        ALTER MAPPING FOR asciiword, asciihword, hword, hword_asciipart, hword_part
        WITH pg_catalog.english_stem;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Add tsvector columns and GIN indexes for relevant tables/columns
-- Example for "Lims"."customers" description and customer_name
ALTER TABLE "Lims"."customers" ADD COLUMN IF NOT EXISTS customer_search_vector TSVECTOR;

UPDATE "Lims"."customers"
SET customer_search_vector =
    TO_TSVECTOR('public.lims_english', COALESCE("customer_name", '')) ||
    TO_TSVECTOR('public.lims_english', COALESCE(description, ''));

CREATE INDEX IF NOT EXISTS idx_customers_gin_search ON "Lims"."customers" USING GIN (customer_search_vector);

-- Create a trigger to update the tsvector column on insert/update
CREATE OR REPLACE FUNCTION "Lims".update_customer_search_vector()
RETURNS TRIGGER AS $$
BEGIN
    NEW.customer_search_vector =
        TO_TSVECTOR('public.lims_english', COALESCE(NEW."customer_name", '')) ||
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.description, ''));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_customer_search ON "Lims"."customers";
CREATE TRIGGER trg_update_customer_search
BEFORE INSERT OR UPDATE ON "Lims"."customers"
FOR EACH ROW
EXECUTE FUNCTION "Lims".update_customer_search_vector();

-- Example Full-Text Search Query
SELECT
    customer_id,
    customer_name,
    description
FROM
    "Lims"."customers"
WHERE
    customer_search_vector @@ TO_TSQUERY('public.lims_english', 'new & company'); -- Search for 'new' and 'company'

SELECT
    customer_id,
    customer_name,
    description
FROM
    "Lims"."customers"
WHERE
    customer_search_vector @@ TO_TSQUERY('public.lims_english', 'customer | service'); -- Search for 'customer' or 'service'

-- Example for "Lab"."samples" external_name and description
ALTER TABLE "Lab"."samples" ADD COLUMN IF NOT EXISTS sample_search_vector TSVECTOR;

UPDATE "Lab"."samples"
SET sample_search_vector =
    TO_TSVECTOR('public.lims_english', COALESCE("External_Name", '')) ||
    TO_TSVECTOR('public.lims_english', COALESCE(description, ''));

CREATE INDEX IF NOT EXISTS idx_samples_gin_search ON "Lab"."samples" USING GIN (sample_search_vector);

CREATE OR REPLACE FUNCTION "Lab".update_sample_search_vector()
RETURNS TRIGGER AS $$
BEGIN
    NEW.sample_search_vector =
        TO_TSVECTOR('public.lims_english', COALESCE(NEW."External_Name", '')) ||
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.description, ''));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_sample_search ON "Lab"."samples";
CREATE TRIGGER trg_update_sample_search
BEFORE INSERT OR UPDATE ON "Lab"."samples"
FOR EACH ROW
EXECUTE FUNCTION "Lab".update_sample_search_vector();

-- Example for "Lims"."sop" Title and sop_protocol
ALTER TABLE "Lims"."sop" ADD COLUMN IF NOT EXISTS sop_search_vector TSVECTOR;

UPDATE "Lims"."sop"
SET sop_search_vector =
    TO_TSVECTOR('public.lims_english', COALESCE("Title", '')) ||
    TO_TSVECTOR('public.lims_english', COALESCE(sop_protocol, ''));

CREATE INDEX IF NOT EXISTS idx_sop_gin_search ON "Lims"."sop" USING GIN (sop_search_vector);

CREATE OR REPLACE FUNCTION "Lims".update_sop_search_vector()
RETURNS TRIGGER AS $$
BEGIN
    NEW.sop_search_vector =
        TO_TSVECTOR('public.lims_english', COALESCE(NEW."Title", '')) ||
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.sop_protocol, ''));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_sop_search ON "Lims"."sop";
CREATE TRIGGER trg_update_sop_search
BEFORE INSERT OR UPDATE ON "Lims"."sop"
FOR EACH ROW
EXECUTE FUNCTION "Lims".update_sop_search_vector();







-- Create a custom text search configuration (optional, but good practice)
CREATE TEXT SEARCH CONFIGURATION IF NOT EXISTS "public"."lims_english" (
    PARSER = pg_catalog."default"
);
ALTER TEXT SEARCH CONFIGURATION "public"."lims_english" ALTER MAPPING FOR asciiword, asciihword, hword, hword_asciipart, hword_part WITH pg_catalog.english_stem;

-- Add tsvector columns and GIN indexes for relevant tables/columns
-- Example for "Lims"."customers" description and customer_name
ALTER TABLE "Lims"."customers" ADD COLUMN IF NOT EXISTS customer_search_vector TSVECTOR;

UPDATE "Lims"."customers"
SET customer_search_vector =
    TO_TSVECTOR('public.lims_english', COALESCE("customer_name", '')) ||
    TO_TSVECTOR('public.lims_english', COALESCE(description, ''));

CREATE INDEX IF NOT EXISTS idx_customers_gin_search ON "Lims"."customers" USING GIN (customer_search_vector);

-- Create a trigger to update the tsvector column on insert/update
CREATE OR REPLACE FUNCTION "Lims".update_customer_search_vector()
RETURNS TRIGGER AS $$
BEGIN
    NEW.customer_search_vector =
        TO_TSVECTOR('public.lims_english', COALESCE(NEW."customer_name", '')) ||
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.description, ''));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_customer_search ON "Lims"."customers";
CREATE TRIGGER trg_update_customer_search
BEFORE INSERT OR UPDATE ON "Lims"."customers"
FOR EACH ROW
EXECUTE FUNCTION "Lims".update_customer_search_vector();

-- Example Full-Text Search Query
SELECT
    customer_id,
    customer_name,
    description
FROM
    "Lims"."customers"
WHERE
    customer_search_vector @@ TO_TSQUERY('public.lims_english', 'new & company'); -- Search for 'new' and 'company'

SELECT
    customer_id,
    customer_name,
    description
FROM
    "Lims"."customers"
WHERE
    customer_search_vector @@ TO_TSQUERY('public.lims_english', 'customer | service'); -- Search for 'customer' or 'service'

-- Example for "Lab"."samples" external_name and description
ALTER TABLE "Lab"."samples" ADD COLUMN IF NOT EXISTS sample_search_vector TSVECTOR;

UPDATE "Lab"."samples"
SET sample_search_vector =
    TO_TSVECTOR('public.lims_english', COALESCE("External_Name", '')) ||
    TO_TSVECTOR('public.lims_english', COALESCE(description, ''));

CREATE INDEX IF NOT EXISTS idx_samples_gin_search ON "Lab"."samples" USING GIN (sample_search_vector);

CREATE OR REPLACE FUNCTION "Lab".update_sample_search_vector()
RETURNS TRIGGER AS $$
BEGIN
    NEW.sample_search_vector =
        TO_TSVECTOR('public.lims_english', COALESCE(NEW."External_Name", '')) ||
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.description, ''));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_sample_search ON "Lab"."samples";
CREATE TRIGGER trg_update_sample_search
BEFORE INSERT OR UPDATE ON "Lab"."samples"
FOR EACH ROW
EXECUTE FUNCTION "Lab".update_sample_search_vector();

-- Example for "Lims"."sop" Title and sop_protocol
ALTER TABLE "Lims"."sop" ADD COLUMN IF NOT EXISTS sop_search_vector TSVECTOR;

UPDATE "Lims"."sop"
SET sop_search_vector =
    TO_TSVECTOR('public.lims_english', COALESCE("Title", '')) ||
    TO_TSVECTOR('public.lims_english', COALESCE(sop_protocol, ''));

CREATE INDEX IF NOT EXISTS idx_sop_gin_search ON "Lims"."sop" USING GIN (sop_search_vector);

CREATE OR REPLACE FUNCTION "Lims".update_sop_search_vector()
RETURNS TRIGGER AS $$
BEGIN
    NEW.sop_search_vector =
        TO_TSVECTOR('public.lims_english', COALESCE(NEW."Title", '')) ||
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.sop_protocol, ''));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_sop_search ON "Lims"."sop";
CREATE TRIGGER trg_update_sop_search
BEFORE INSERT OR UPDATE ON "Lims"."sop"
FOR EACH ROW
EXECUTE FUNCTION "Lims".update_sop_search_vector();

-- Example for "Lab"."Experiments" Experiment_title and aim
ALTER TABLE "Lab"."Experiments" ADD COLUMN IF NOT EXISTS experiment_search_vector TSVECTOR;

UPDATE "Lab"."Experiments"
SET experiment_search_vector =
    TO_TSVECTOR('public.lims_english', COALESCE("Experiment_title", '')) ||
    TO_TSVECTOR('public.lims_english', COALESCE(aim, '')) ||
    TO_TSVECTOR('public.lims_english', COALESCE(Method, ''));

CREATE INDEX IF NOT EXISTS idx_experiments_gin_search ON "Lab"."Experiments" USING GIN (experiment_search_vector);

CREATE OR REPLACE FUNCTION "Lab".update_experiment_search_vector()
RETURNS TRIGGER AS $$
BEGIN
    NEW.experiment_search_vector =
        TO_TSVECTOR('public.lims_english', COALESCE(NEW."Experiment_title", '')) ||
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.aim, '')) ||
        TO_TSVECTOR('public.lims_english', COALESCE(NEW.Method, ''));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_experiment_search ON "Lab"."Experiments";
CREATE TRIGGER trg_update_experiment_search
BEFORE INSERT OR UPDATE ON "Lab"."Experiments"
FOR EACH ROW
EXECUTE FUNCTION "Lab".update_experiment_search_vector();


-- ======================================================================
-- 11. Foreign Data Wrappers (FDW) and Foreign Tables Examples
--     Illustrating how to access data from external databases.
--     Note: This is a conceptual example. Actual usage requires
--     a running foreign server and proper connection details.
-- ======================================================================

-- Create a foreign server (example connecting to another PostgreSQL database)
-- Replace 'foreign_host', 'foreign_port', 'foreign_dbname', 'foreign_user', 'foreign_password'
-- with actual connection details.
CREATE SERVER IF NOT EXISTS foreign_lims_server
FOREIGN DATA WRAPPER postgres_fdw
OPTIONS (host 'foreign_host', port '5432', dbname 'foreign_lims_db');

-- Create user mapping for the foreign server
-- This maps your current PostgreSQL user to a user on the foreign server.
CREATE USER MAPPING IF NOT EXISTS FOR CURRENT_USER
SERVER foreign_lims_server
OPTIONS (user 'foreign_user', password 'foreign_password');

-- Import foreign schemas (optional, imports all tables from a schema)
-- IMPORT FOREIGN SCHEMA public FROM SERVER foreign_lims_server INTO public;

-- Create a foreign table (example: accessing a 'remote_projects' table on the foreign server)
-- This creates a local representation of a table that exists on the foreign server.
CREATE FOREIGN TABLE IF NOT EXISTS "Lims"."foreign_projects" (
    "project_id" text NOT NULL,
    "Title" text,
    "Start_date" date,
    "End_date" date
)
SERVER foreign_lims_server
OPTIONS (schema_name 'Lims', table_name 'projects'); -- Assuming 'Lims.projects' exists on foreign_lims_db

-- Example query on a foreign table
SELECT * FROM "Lims"."foreign_projects" WHERE "Title" LIKE '%External%';


-- ======================================================================
-- 12. Foreign Keys (Review)
--     All foreign keys are already defined in the base schema.
--     They ensure referential integrity between tables.
--     No new code here, just confirmation of their importance.
-- ======================================================================

-- Foreign Keys are crucial for maintaining relationships and data consistency.
-- They are already correctly defined in the initial table creation statements.
-- For example:
-- "modified_by" text REFERENCES "reference"."personal"("person_id")
-- "project_id" TEXT NOT NULL REFERENCES "Lims"."projects"("project_id") ON DELETE CASCADE


-- ======================================================================
-- 13. Foreign Tables (as part of FDW)
--     Already covered in section 11.
-- ======================================================================

-- Foreign tables are created as part of the Foreign Data Wrapper setup
-- to allow querying external data as if it were local.
-- See section 11 for examples.





















































-- ======================================================================
-- Complementary PostgreSQL Code for LIMS Database (Revised and Expanded)
-- This script adds advanced features, performance optimizations,
-- and extended functionalities to the existing LIMS schema.
-- It is designed to be run AFTER the base schema (tables, basic triggers,
-- and constraints) has been successfully applied.
--
-- New Features Added:
-- - Section 5: Sample Status Update Triggers
-- - Section 6: Comprehensive Views for Data Analysis and Tracking
-- - Section 7: Data Auditing with a Generic Trigger
-- - Section 8: Advanced Security with Row-Level Security (RLS)
-- - Section 9: Advanced JSONB and ltree Query Examples
-- ======================================================================


-- ======================================================================
-- 1. Extensions
--    Enabling powerful built-in PostgreSQL functionalities.
-- ======================================================================

-- Enables UUID generation (useful for unique IDs if not using sequences)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Enables trigram matching for fuzzy string searching (improves LIKE/ILIKE performance)
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Enables connecting to other PostgreSQL databases as foreign data sources
CREATE EXTENSION IF NOT EXISTS postgres_fdw;

-- Enables key-value store for flexible schema (e.g., for custom sample metadata)
CREATE EXTENSION IF NOT EXISTS hstore;

-- Enables tablefunc for crosstab queries (pivot tables)
CREATE EXTENSION IF NOT EXISTS tablefunc;

-- Enables ltree for hierarchical data structures (e.g., complex taxon hierarchies)
CREATE EXTENSION IF NOT EXISTS ltree;


-- ======================================================================
-- 2. Advanced Functions
--    Custom functions for common LIMS operations and data manipulation.
-- ======================================================================

-- Function to calculate DNA yield. (Note: This logic is already in your generated columns,
-- but this serves as a good example of a reusable calculation function).
CREATE OR REPLACE FUNCTION "Lab".calculate_dna_yield_ug(
    volume_ul NUMERIC,
    concentration_ng_ul NUMERIC
)
RETURNS NUMERIC AS $$
BEGIN
    IF volume_ul IS NULL OR concentration_ng_ul IS NULL OR volume_ul < 0 OR concentration_ng_ul < 0 THEN
        RETURN NULL;
    END IF;
    -- Calculation: (Volume in µL * Concentration in ng/µL) / 1000 = Total yield in µg
    RETURN (volume_ul * concentration_ng_ul) / 1000;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Function to get the full name of a person from their ID.
CREATE OR REPLACE FUNCTION "reference".get_full_person_name(p_person_id TEXT)
RETURNS TEXT AS $$
DECLARE
    full_name TEXT;
BEGIN
    SELECT "Full Name" INTO full_name FROM "reference"."personal" WHERE "person_id" = p_person_id;
    RETURN full_name;
END;
$$ LANGUAGE plpgsql STABLE;

-- Function to get all child samples recursively for a given parent sample_id.
-- Useful for tracking the entire lineage of a sample.
CREATE OR REPLACE FUNCTION "Lab".get_all_child_samples_recursive(p_parent_sample_id TEXT)
RETURNS SETOF TEXT AS $$
BEGIN
    RETURN QUERY
    WITH RECURSIVE child_samples AS (
        -- Base case: direct children
        SELECT "sample_id"
        FROM "Lab"."samples"
        WHERE "Parentsample_id" = p_parent_sample_id
        UNION ALL
        -- Recursive step: children of children
        SELECT s."sample_id"
        FROM "Lab"."samples" s
        JOIN child_samples cs ON s."Parentsample_id" = cs."sample_id"
    )
    SELECT "sample_id" FROM child_samples;
END;
$$ LANGUAGE plpgsql STABLE;


-- ======================================================================
-- 3. Indexes
--    Optimizing query performance by adding indexes on frequently
--    queried columns, especially foreign keys and columns used in WHERE clauses.
-- ======================================================================

-- Note: Your original script had a very good set of indexes.
-- This section confirms them and adds a few common additions like for dates and names.

-- Lims Schema Indexes
CREATE INDEX IF NOT EXISTS idx_projects_pi ON "Lims"."projects" ("PI");
CREATE INDEX IF NOT EXISTS idx_projects_customer_id ON "Lims"."projects" ("customer_id");
CREATE INDEX IF NOT EXISTS idx_cruises_project_id ON "Lims"."cruises" ("project_id");

-- Lab Schema Indexes
CREATE INDEX IF NOT EXISTS idx_sampling_project_id ON "Lab"."sampling" ("project_id");
CREATE INDEX IF NOT EXISTS idx_sampling_sampling_date ON "Lab"."sampling" ("sampling_date");
CREATE INDEX IF NOT EXISTS idx_samples_parentsample_id ON "Lab"."samples" ("Parentsample_id");
CREATE INDEX IF NOT EXISTS idx_samples_project_id ON "Lab"."samples" ("project_id");
CREATE INDEX IF NOT EXISTS idx_fish_parentsample_id ON "Lab"."fish" ("Parentsample_id");
CREATE INDEX IF NOT EXISTS idx_fish_species ON "Lab"."fish" ("species");
CREATE INDEX IF NOT EXISTS idx_tissue_parentsample_id ON "Lab"."Tissue" ("Parentsample_id");
CREATE INDEX IF NOT EXISTS idx_dna_parentsample_id ON "Lab"."DNA" ("Parentsample_id");
CREATE INDEX IF NOT EXISTS idx_rna_parentsample_id ON "Lab"."RNA" ("Parentsample_id");
CREATE INDEX IF NOT EXISTS idx_sequencing_library_id ON "Lab"."Sequencing" ("Library_id");

-- Bioinformatics Schema Indexes
CREATE INDEX IF NOT EXISTS idx_analysis_runs_pipeline_id ON "bioinformatics"."analysis_runs" ("pipeline_id");
CREATE INDEX IF NOT EXISTS idx_edna_assignments_run_id ON "bioinformatics"."edna_assignments" ("run_id");
CREATE INDEX IF NOT EXISTS idx_edna_assignments_taxon_id ON "bioinformatics"."edna_assignments" ("taxon_id");

-- Partial Index Example: Index only projects that are currently active for faster lookups.
CREATE INDEX IF NOT EXISTS idx_projects_active ON "Lims"."projects" ("project_id") WHERE "status_id" = 'Active';

-- Expression Index Example: For case-insensitive searches on customer names.
CREATE INDEX IF NOT EXISTS idx_customers_lower_name ON "Lims"."customers" (LOWER("customer_name"));


-- ======================================================================
-- 4. Full-Text Search Configuration
--     Setting up full-text search for efficient text-based queries.
-- ======================================================================

-- Create a custom text search configuration for English with stemming.
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

-- Generic function to automatically update a tsvector column.
CREATE OR REPLACE FUNCTION "Lims".generate_tsvector()
RETURNS TRIGGER AS $$
DECLARE
    ts_config REGCONFIG := 'public.lims_english';
    document TEXT := '';
    target_column TEXT := TG_ARGV[TG_NARGS-1];
BEGIN
    -- Build the document from the specified source columns
    FOR i IN 0..TG_NARGS-2 LOOP
        document := document || ' ' || COALESCE(NEW[TG_ARGV[i]::text], '');
    END LOOP;

    -- Set the value of the target tsvector column
    NEW[target_column] := to_tsvector(ts_config, document);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply full-text search to "Lims"."sop" table
ALTER TABLE "Lims"."sop" ADD COLUMN IF NOT EXISTS sop_search_vector TSVECTOR;
CREATE INDEX IF NOT EXISTS idx_sop_gin_search ON "Lims"."sop" USING GIN (sop_search_vector);
DROP TRIGGER IF EXISTS trg_update_sop_search ON "Lims"."sop";
CREATE TRIGGER trg_update_sop_search
BEFORE INSERT OR UPDATE ON "Lims"."sop"
FOR EACH ROW EXECUTE PROCEDURE "Lims".generate_tsvector('Title', 'sop_protocol', 'description', 'sop_search_vector');

-- Apply full-text search to "Lab"."Experiments" table
ALTER TABLE "Lab"."Experiments" ADD COLUMN IF NOT EXISTS experiment_search_vector TSVECTOR;
CREATE INDEX IF NOT EXISTS idx_experiments_gin_search ON "Lab"."Experiments" USING GIN (experiment_search_vector);
DROP TRIGGER IF EXISTS trg_update_experiment_search ON "Lab"."Experiments";
CREATE TRIGGER trg_update_experiment_search
BEFORE INSERT OR UPDATE ON "Lab"."Experiments"
FOR EACH ROW EXECUTE PROCEDURE "Lims".generate_tsvector('Experiment_title', 'aim', 'Method', 'description', 'experiment_search_vector');


-- ======================================================================
-- 5. Sample Status Update Triggers
--    These triggers automatically update the "sample_status_id" in the
--    "Lab"."samples" table as a sample progresses through the workflow.
-- ======================================================================

-- Generic function to update the sample status
CREATE OR REPLACE FUNCTION "Lab".update_sample_status()
RETURNS TRIGGER AS $$
DECLARE
    new_status TEXT := TG_ARGV[0];
    target_sample_id TEXT;
BEGIN
    -- Determine the sample_id from the triggering table
    -- Most tables have a 'sample_id' column.
    -- For child samples (DNA, RNA, etc.), the status update should apply to the child sample itself.
    IF TG_TABLE_NAME IN ('dna', 'rna', 'tissue', 'fish', 'sediments', 'water', 'library', 'sequencing') THEN
        target_sample_id := NEW.sample_id;
    -- For process tables that reference a sample, use that reference.
    ELSIF TG_TABLE_NAME IN ('extraction', 'nanodrop', 'qubit', 'tapestation', 'pcr', 'qpcr', 'gelelectrophoresis', 'dissections', 'bioinformatics') THEN
        target_sample_id := NEW.sample_id;
    END IF;

    -- Update the status in the main samples table
    IF target_sample_id IS NOT NULL THEN
        UPDATE "Lab"."samples"
        SET "sample_status_id" = new_status,
            "time_modification" = CURRENT_TIMESTAMP
        WHERE "sample_id" = target_sample_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply the trigger to each relevant process table
DROP TRIGGER IF EXISTS trg_update_status_dissection ON "Lab"."Dissections";
CREATE TRIGGER trg_update_status_dissection AFTER INSERT ON "Lab"."Dissections" FOR EACH ROW EXECUTE PROCEDURE "Lab".update_sample_status('Dissection');

DROP TRIGGER IF EXISTS trg_update_status_extraction ON "Lab"."Extraction";
CREATE TRIGGER trg_update_status_extraction AFTER INSERT ON "Lab"."Extraction" FOR EACH ROW EXECUTE PROCEDURE "Lab".update_sample_status('Extracted');

DROP TRIGGER IF EXISTS trg_update_status_nanodrop ON "Lab"."Nanodrop";
CREATE TRIGGER trg_update_status_nanodrop AFTER INSERT ON "Lab"."Nanodrop" FOR EACH ROW EXECUTE PROCEDURE "Lab".update_sample_status('Nanodrop QC');

DROP TRIGGER IF EXISTS trg_update_status_qubit ON "Lab"."Qubit";
CREATE TRIGGER trg_update_status_qubit AFTER INSERT ON "Lab"."Qubit" FOR EACH ROW EXECUTE PROCEDURE "Lab".update_sample_status('Qubit QC');

DROP TRIGGER IF EXISTS trg_update_status_tapestation ON "Lab"."Tapestation";
CREATE TRIGGER trg_update_status_tapestation AFTER INSERT ON "Lab"."Tapestation" FOR EACH ROW EXECUTE PROCEDURE "Lab".update_sample_status('Tapestation QC');

DROP TRIGGER IF EXISTS trg_update_status_pcr ON "Lab"."PCR";
CREATE TRIGGER trg_update_status_pcr AFTER INSERT ON "Lab"."PCR" FOR EACH ROW EXECUTE PROCEDURE "Lab".update_sample_status('PCR Done');

DROP TRIGGER IF EXISTS trg_update_status_qpcr ON "Lab"."qPCR";
CREATE TRIGGER trg_update_status_qpcr AFTER INSERT ON "Lab"."qPCR" FOR EACH ROW EXECUTE PROCEDURE "Lab".update_sample_status('qPCR Done');

DROP TRIGGER IF EXISTS trg_update_status_library ON "Lab"."Library";
CREATE TRIGGER trg_update_status_library AFTER INSERT ON "Lab"."Library" FOR EACH ROW EXECUTE PROCEDURE "Lab".update_sample_status('Library Prep');

DROP TRIGGER IF EXISTS trg_update_status_sequencing ON "Lab"."Sequencing";
CREATE TRIGGER trg_update_status_sequencing AFTER INSERT ON "Lab"."Sequencing" FOR EACH ROW EXECUTE PROCEDURE "Lab".update_sample_status('Sequencing Done');

DROP TRIGGER IF EXISTS trg_update_status_bioinformatics ON "Lab"."bioinformatics";
CREATE TRIGGER trg_update_status_bioinformatics AFTER INSERT ON "Lab"."bioinformatics" FOR EACH ROW EXECUTE PROCEDURE "Lab".update_sample_status('Bioinformatics Done');


-- ======================================================================
-- 6. Comprehensive Views for Data Analysis and Tracking
--    Creating virtual tables (views) to simplify complex queries and provide
--    user-friendly summaries of the data.
-- ======================================================================

-- View: A complete audit trail for each sample, showing every step and result.
-- This is the core view for tracking sample status and history.
CREATE OR REPLACE VIEW "Lab"."Sample_Audit_Trail_View" AS
SELECT
    s.sample_id,
    s."External_Name",
    'Received' AS process_step,
    s."Reception_date"::TIMESTAMP AS process_date,
    s."Reciever" AS person_id,
    p_rec."Full Name" AS person_name,
    'Sample registered in LIMS.' AS details
FROM "Lab"."samples" s
LEFT JOIN "reference"."personal" p_rec ON s."Reciever" = p_rec.person_id

UNION ALL

SELECT
    d.sample_id,
    s."External_Name",
    'Dissection' AS process_step,
    d.dissection_date::TIMESTAMP AS process_date,
    d.person_id,
    p."Full Name" AS person_name,
    'Gonad: ' || d.gonad_weight_g || 'g, Liver: ' || d.liver_weight_g || 'g' AS details
FROM "Lab"."Dissections" d
JOIN "Lab"."samples" s ON d.sample_id = s.sample_id
LEFT JOIN "reference"."personal" p ON d.person_id = p.person_id

UNION ALL

SELECT
    e.sample_id,
    s."External_Name",
    'Extraction' AS process_step,
    e.date::TIMESTAMP AS process_date,
    e.person_id,
    p."Full Name" AS person_name,
    'Kit: ' || e.kit || ', Yield: ' || e."Yield_Qubit_ng_ul" || ' ng/uL' AS details
FROM "Lab"."Extraction" e
JOIN "Lab"."samples" s ON e.sample_id = s.sample_id
LEFT JOIN "reference"."personal" p ON e.person_id = p.person_id

UNION ALL

SELECT
    q.sample_id,
    s."External_Name",
    'Qubit QC' AS process_step,
    q.date::TIMESTAMP AS process_date,
    q.person AS person_id,
    p."Full Name" AS person_name,
    'Concentration: ' || q."QubitOriginal_sample_conc" || ' ' || q."QubitOriginal_units" AS details
FROM "Lab"."Qubit" q
JOIN "Lab"."samples" s ON q.sample_id = s.sample_id
LEFT JOIN "reference"."personal" p ON q.person = p.person_id

UNION ALL

SELECT
    l.sample_id,
    s."External_Name",
    'Library Prep' AS process_step,
    l.date::TIMESTAMP AS process_date,
    l.person AS person_id,
    p."Full Name" AS person_name,
    'Kit: ' || l."LibraryPrepKit" || ', Index: ' || l."IndexSequence" AS details
FROM "Lab"."Library" l
JOIN "Lab"."samples" s ON l.sample_id = s.sample_id
LEFT JOIN "reference"."personal" p ON l.person = p.person_id

UNION ALL

SELECT
    seq.sample_id,
    s."External_Name",
    'Sequencing' AS process_step,
    seq.date::TIMESTAMP AS process_date,
    seq.person AS person_id,
    p."Full Name" AS person_name,
    'Sequencer: ' || seq."Sequencer" || ', Reads: ' || seq."TotalReads" AS details
FROM "Lab"."Sequencing" seq
JOIN "Lab"."samples" s ON seq.sample_id = s.sample_id
LEFT JOIN "reference"."personal" p ON seq.person = p.person_id

ORDER BY sample_id, process_date;


-- View: Project financial summary, joining projects with orders.
CREATE OR REPLACE VIEW "Lims"."Project_Financial_Summary_View" AS
SELECT
    p.project_id,
    p."Title" AS project_title,
    p."PI" AS pi_person_id,
    pers."Full Name" AS pi_name,
    SUM(o.price) AS total_cost,
    COUNT(o."FI_Order_Nr") AS number_of_orders,
    MIN(o.date) AS first_order_date,
    MAX(o.date) AS last_order_date
FROM
    "Lims"."projects" p
JOIN "Lims"."orders" o ON p.project_id = o.project_id
LEFT JOIN "reference"."personal" pers ON p."PI" = pers.person_id
GROUP BY
    p.project_id, p."Title", p."PI", pers."Full Name"
ORDER BY
    total_cost DESC;

-- View: Full bioinformatics results, linking taxonomic assignments back to sampling event details.
CREATE OR REPLACE VIEW "bioinformatics"."Full_Analysis_Results_View" AS
SELECT
    p.project_id,
    p."Title" AS project_title,
    samp.sampling_id,
    samp.sampling_date,
    samp."Location" AS sampling_location,
    s.sample_id,
    s."External_Name",
    ar.run_id AS analysis_run_id,
    ap.name AS pipeline_name,
    ap.version AS pipeline_version,
    t.taxon_id,
    t."En_name" AS taxon_english_name,
    t.rank AS taxon_rank,
    ea.read_count,
    ea.confidence
FROM
    "bioinformatics"."edna_assignments" ea
JOIN "bioinformatics"."analysis_runs" ar ON ea.run_id = ar.run_id
JOIN "bioinformatics"."analysis_pipelines" ap ON ar.pipeline_id = ap.pipeline_id
JOIN "Lab"."samples" s ON ea.sample_id = s.sample_id
JOIN "Lab"."sampling" samp ON s.sampling_id = samp.sampling_id
JOIN "Lims"."projects" p ON s.project_id = p.project_id
JOIN "reference"."taxon" t ON ea.taxon_id = t.taxon_id
ORDER BY
    p.project_id, samp.sampling_date, s.sample_id, ea.read_count DESC;

-- View: Storage occupancy, calculating the percentage of used slots in each box.
CREATE OR REPLACE VIEW "Lab"."Storage_Occupancy_View" AS
WITH box_counts AS (
    SELECT
        storage_id,
        COUNT(sample_id) AS stored_samples
    FROM "Lab"."samples"
    WHERE storage_id IS NOT NULL
    GROUP BY storage_id
)
SELECT
    st.storage_id,
    st.room_id,
    st."Freezer",
    st."Box",
    st."Box_size_X" * st."Box_size_Y" AS box_capacity,
    COALESCE(bc.stored_samples, 0) AS occupied_slots,
    (COALESCE(bc.stored_samples, 0)::NUMERIC * 100 / (st."Box_size_X" * st."Box_size_Y"))::NUMERIC(5,2) AS occupancy_percent
FROM
    "Lab"."storage" st
LEFT JOIN box_counts bc ON st.storage_id = bc.storage_id
WHERE st."Box_size_X" > 0 AND st."Box_size_Y" > 0
ORDER BY
    occupancy_percent DESC;


-- ======================================================================
-- 7. Data Auditing with a Generic Trigger
--    Creates a log of all data changes (INSERT, UPDATE, DELETE) for
--    specified tables, which is essential for traceability and compliance.
-- ======================================================================

CREATE SCHEMA IF NOT EXISTS "audit";

CREATE TABLE IF NOT EXISTS "audit"."log" (
    id SERIAL PRIMARY KEY,
    schema_name TEXT NOT NULL,
    table_name TEXT NOT NULL,
    user_name TEXT,
    action_timestamp TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    action TEXT NOT NULL CHECK (action IN ('I', 'D', 'U')),
    original_data JSONB,
    new_data JSONB,
    query TEXT
);

CREATE OR REPLACE FUNCTION "audit".if_modified_func()
RETURNS TRIGGER AS $$
DECLARE
    audit_row "audit"."log";
    include_values BOOLEAN;
    log_statement TEXT;
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
    audit_row.user_name = session_user::TEXT;
    audit_row.query = current_query();

    INSERT INTO "audit"."log" VALUES (DEFAULT, audit_row.schema_name, audit_row.table_name, audit_row.user_name,
                                    DEFAULT, audit_row.action, audit_row.original_data, audit_row.new_data, audit_row.query);

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Example of applying the audit trigger to the 'projects' table.
-- This can be applied to any table you want to audit.
DROP TRIGGER IF EXISTS audit_trigger_projects ON "Lims"."projects";
CREATE TRIGGER audit_trigger_projects
AFTER INSERT OR UPDATE OR DELETE ON "Lims"."projects"
FOR EACH ROW EXECUTE PROCEDURE "audit".if_modified_func();

-- Example of applying the audit trigger to the 'samples' table.
DROP TRIGGER IF EXISTS audit_trigger_samples ON "Lab"."samples";
CREATE TRIGGER audit_trigger_samples
AFTER INSERT OR UPDATE OR DELETE ON "Lab"."samples"
FOR EACH ROW EXECUTE PROCEDURE "audit".if_modified_func();


-- ======================================================================
-- 8. Advanced Security with Row-Level Security (RLS)
--    Restricts which rows users can access based on their identity and
--    project membership.
-- ======================================================================

-- First, enable RLS on a table.
ALTER TABLE "Lims"."projects" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Lab"."samples" ENABLE ROW LEVEL SECURITY;

-- Create a helper function to check if the current user is part of a project.
-- This assumes you set the user's person_id in the session, e.g., SET lims.person_id = 'some_user';
CREATE OR REPLACE FUNCTION "Lims".is_member_of_project(p_project_id TEXT)
RETURNS BOOLEAN AS $$
DECLARE
    current_person_id TEXT := current_setting('lims.person_id', true);
BEGIN
    IF current_person_id IS NULL THEN
        RETURN FALSE; -- Deny access if user is not set
    END IF;

    -- Check if the user is the PI or listed in projectpersons
    RETURN EXISTS (
        SELECT 1 FROM "Lims"."projects" WHERE project_id = p_project_id AND "PI" = current_person_id
    ) OR EXISTS (
        SELECT 1 FROM "Lims"."projectpersons" WHERE project_id = p_project_id AND person_id = current_person_id
    );
END;
$$ LANGUAGE plpgsql STABLE;

-- Create security policies
-- Policy 1: Users can see projects they are a member of.
DROP POLICY IF EXISTS project_membership_policy ON "Lims"."projects";
CREATE POLICY project_membership_policy ON "Lims"."projects"
FOR SELECT
USING ("Lims".is_member_of_project(project_id));

-- Policy 2: Users can see samples belonging to projects they are a member of.
DROP POLICY IF EXISTS sample_project_membership_policy ON "Lab"."samples";
CREATE POLICY sample_project_membership_policy ON "Lab"."samples"
FOR SELECT
USING ("Lims".is_member_of_project(project_id));

-- To test RLS:
-- 1. SET lims.person_id = 'some_user_id';
-- 2. SELECT * FROM "Lims"."projects"; -- You will only see projects where 'some_user_id' is a member.
-- 3. RESET lims.person_id;


-- ======================================================================
-- 9. Advanced JSONB and ltree Query Examples
-- ======================================================================

-- Example 1: Querying JSONB data from the Dissections table
-- Find all dissections where 'shrimp' was found in the stomach contents.
SELECT
    dissection_id,
    sample_id,
    stomach_contents_jsonb
FROM "Lab"."Dissections"
WHERE stomach_contents_jsonb @> '[{"item": "shrimp"}]'::jsonb;

-- Aggregate data from JSONB: Count the occurrences of each stomach item.
CREATE OR REPLACE VIEW "Lab"."Stomach_Contents_Summary_View" AS
SELECT
    item,
    COUNT(*) AS occurrence_count
FROM (
    SELECT
        (jsonb_array_elements(stomach_contents_jsonb)->>'item') AS item
    FROM "Lab"."Dissections"
    WHERE jsonb_typeof(stomach_contents_jsonb) = 'array'
) AS items
GROUP BY item
ORDER BY occurrence_count DESC;


-- Example 2: Using ltree for taxonomic hierarchy
-- STEP A: Add and populate the ltree path column in the taxon table.
ALTER TABLE "reference"."taxon" ADD COLUMN IF NOT EXISTS path LTREE;
CREATE INDEX IF NOT EXISTS idx_taxon_path_gist ON "reference"."taxon" USING GIST (path);

-- Recursive function to build the ltree paths
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

-- Run the function to populate the paths
-- SELECT "reference".update_taxon_ltree_paths();

-- STEP B: Query the hierarchy using ltree operators
-- Find all taxa belonging to the family 'Gadidae' (assuming 'Gadidae' is a taxon_id)
-- The <@ operator means 'is descendant of'
/*
SELECT * FROM "reference"."taxon"
WHERE path <@ (SELECT path FROM "reference"."taxon" WHERE taxon_id = 'Gadidae');
*/

-- Find the full lineage of 'Gadus morhua' (Atlantic Cod)
-- The @> operator means 'is ancestor of'
/*
SELECT * FROM "reference"."taxon"
WHERE path @> (SELECT path FROM "reference"."taxon" WHERE taxon_id = 'Gadus morhua')
ORDER BY path;
*/


































































-- ======================================================================
-- Complementary PostgreSQL Code for LIMS Database (Revised and Expanded)
-- This script adds advanced features, performance optimizations,
-- and extended functionalities to the existing LIMS schema.
-- It is designed to be run AFTER the base schema (tables, basic triggers,
-- and constraints) has been successfully applied.
--
-- New Features Added:
-- - Section 5: Sample Status Update Triggers
-- - Section 6: Comprehensive Views for Data Analysis and Tracking (Expanded)
-- - Section 7: Data Auditing with a Generic Trigger
-- - Section 8: Advanced Security with Row-Level Security (RLS)
-- - Section 9: Advanced JSONB and ltree Query Examples
-- ======================================================================


-- ======================================================================
-- 1. Extensions
--    Enabling powerful built-in PostgreSQL functionalities.
-- ======================================================================

-- Enables UUID generation (useful for unique IDs if not using sequences)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Enables trigram matching for fuzzy string searching (improves LIKE/ILIKE performance)
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Enables connecting to other PostgreSQL databases as foreign data sources
CREATE EXTENSION IF NOT EXISTS postgres_fdw;

-- Enables key-value store for flexible schema (e.g., for custom sample metadata)
CREATE EXTENSION IF NOT EXISTS hstore;

-- Enables tablefunc for crosstab queries (pivot tables)
CREATE EXTENSION IF NOT EXISTS tablefunc;

-- Enables ltree for hierarchical data structures (e.g., complex taxon hierarchies)
CREATE EXTENSION IF NOT EXISTS ltree;


-- ======================================================================
-- 2. Advanced Functions
--    Custom functions for common LIMS operations and data manipulation.
-- ======================================================================

-- Function to calculate DNA yield. (Note: This logic is already in your generated columns,
-- but this serves as a good example of a reusable calculation function).
CREATE OR REPLACE FUNCTION "Lab".calculate_dna_yield_ug(
    volume_ul NUMERIC,
    concentration_ng_ul NUMERIC
)
RETURNS NUMERIC AS $$
BEGIN
    IF volume_ul IS NULL OR concentration_ng_ul IS NULL OR volume_ul < 0 OR concentration_ng_ul < 0 THEN
        RETURN NULL;
    END IF;
    -- Calculation: (Volume in µL * Concentration in ng/µL) / 1000 = Total yield in µg
    RETURN (volume_ul * concentration_ng_ul) / 1000;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Function to get the full name of a person from their ID.
CREATE OR REPLACE FUNCTION "reference".get_full_person_name(p_person_id TEXT)
RETURNS TEXT AS $$
DECLARE
    full_name TEXT;
BEGIN
    SELECT "Full Name" INTO full_name FROM "reference"."personal" WHERE "person_id" = p_person_id;
    RETURN full_name;
END;
$$ LANGUAGE plpgsql STABLE;

-- Function to get all child samples recursively for a given parent sample_id.
-- Useful for tracking the entire lineage of a sample.
CREATE OR REPLACE FUNCTION "Lab".get_all_child_samples_recursive(p_parent_sample_id TEXT)
RETURNS SETOF TEXT AS $$
BEGIN
    RETURN QUERY
    WITH RECURSIVE child_samples AS (
        -- Base case: direct children
        SELECT "sample_id"
        FROM "Lab"."samples"
        WHERE "Parentsample_id" = p_parent_sample_id
        UNION ALL
        -- Recursive step: children of children
        SELECT s."sample_id"
        FROM "Lab"."samples" s
        JOIN child_samples cs ON s."Parentsample_id" = cs.sample_id
    )
    SELECT "sample_id" FROM child_samples;
END;
$$ LANGUAGE plpgsql STABLE;


-- ======================================================================
-- 3. Indexes
--    Optimizing query performance by adding indexes on frequently
--    queried columns, especially foreign keys and columns used in WHERE clauses.
-- ======================================================================

-- Note: Your original script had a very good set of indexes.
-- This section confirms them and adds a few common additions like for dates and names.

-- Lims Schema Indexes
CREATE INDEX IF NOT EXISTS idx_projects_pi ON "Lims"."projects" ("PI");
CREATE INDEX IF NOT EXISTS idx_projects_customer_id ON "Lims"."projects" ("customer_id");
CREATE INDEX IF NOT EXISTS idx_cruises_project_id ON "Lims"."cruises" ("project_id");

-- Lab Schema Indexes
CREATE INDEX IF NOT EXISTS idx_sampling_project_id ON "Lab"."sampling" ("project_id");
CREATE INDEX IF NOT EXISTS idx_sampling_sampling_date ON "Lab"."sampling" ("sampling_date");
CREATE INDEX IF NOT EXISTS idx_samples_parentsample_id ON "Lab"."samples" ("Parentsample_id");
CREATE INDEX IF NOT EXISTS idx_samples_project_id ON "Lab"."samples" ("project_id");
CREATE INDEX IF NOT EXISTS idx_fish_parentsample_id ON "Lab"."fish" ("Parentsample_id");
CREATE INDEX IF NOT EXISTS idx_fish_species ON "Lab"."fish" ("species");
CREATE INDEX IF NOT EXISTS idx_tissue_parentsample_id ON "Lab"."Tissue" ("Parentsample_id");
CREATE INDEX IF NOT EXISTS idx_dna_parentsample_id ON "Lab"."DNA" ("Parentsample_id");
CREATE INDEX IF NOT EXISTS idx_rna_parentsample_id ON "Lab"."RNA" ("Parentsample_id");
CREATE INDEX IF NOT EXISTS idx_sequencing_library_id ON "Lab"."Sequencing" ("Library_id");

-- Bioinformatics Schema Indexes
CREATE INDEX IF NOT EXISTS idx_analysis_runs_pipeline_id ON "bioinformatics"."analysis_runs" ("pipeline_id");
CREATE INDEX IF NOT EXISTS idx_edna_assignments_run_id ON "bioinformatics"."edna_assignments" ("run_id");
CREATE INDEX IF NOT EXISTS idx_edna_assignments_taxon_id ON "bioinformatics"."edna_assignments" ("taxon_id");

-- Partial Index Example: Index only projects that are currently active for faster lookups.
CREATE INDEX IF NOT EXISTS idx_projects_active ON "Lims"."projects" ("project_id") WHERE "status_id" = 'Active';

-- Expression Index Example: For case-insensitive searches on customer names.
CREATE INDEX IF NOT EXISTS idx_customers_lower_name ON "Lims"."customers" (LOWER("customer_name"));


-- ======================================================================
-- 4. Full-Text Search Configuration
--     Setting up full-text search for efficient text-based queries.
-- ======================================================================

-- Create a custom text search configuration for English with stemming.
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

-- Generic function to automatically update a tsvector column.
CREATE OR REPLACE FUNCTION "Lims".generate_tsvector()
RETURNS TRIGGER AS $$
DECLARE
    ts_config REGCONFIG := 'public.lims_english';
    document TEXT := '';
    target_column TEXT := TG_ARGV[TG_NARGS-1];
BEGIN
    -- Build the document from the specified source columns
    FOR i IN 0..TG_NARGS-2 LOOP
        document := document || ' ' || COALESCE(NEW[TG_ARGV[i]::text], '');
    END LOOP;

    -- Set the value of the target tsvector column
    NEW[target_column] := to_tsvector(ts_config, document);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply full-text search to "Lims"."sop" table
ALTER TABLE "Lims"."sop" ADD COLUMN IF NOT EXISTS sop_search_vector TSVECTOR;
CREATE INDEX IF NOT EXISTS idx_sop_gin_search ON "Lims"."sop" USING GIN (sop_search_vector);
DROP TRIGGER IF EXISTS trg_update_sop_search ON "Lims"."sop";
CREATE TRIGGER trg_update_sop_search
BEFORE INSERT OR UPDATE ON "Lims"."sop"
FOR EACH ROW EXECUTE PROCEDURE "Lims".generate_tsvector('Title', 'sop_protocol', 'description', 'sop_search_vector');

-- Apply full-text search to "Lab"."Experiments" table
ALTER TABLE "Lab"."Experiments" ADD COLUMN IF NOT EXISTS experiment_search_vector TSVECTOR;
CREATE INDEX IF NOT EXISTS idx_experiments_gin_search ON "Lab"."Experiments" USING GIN (experiment_search_vector);
DROP TRIGGER IF EXISTS trg_update_experiment_search ON "Lab"."Experiments";
CREATE TRIGGER trg_update_experiment_search
BEFORE INSERT OR UPDATE ON "Lab"."Experiments"
FOR EACH ROW EXECUTE PROCEDURE "Lims".generate_tsvector('Experiment_title', 'aim', 'Method', 'description', 'experiment_search_vector');


-- ======================================================================
-- 5. Sample Status Update Triggers
--    These triggers automatically update the "sample_status_id" in the
--    "Lab"."samples" table as a sample progresses through the workflow.
-- ======================================================================

-- Generic function to update the sample status
CREATE OR REPLACE FUNCTION "Lab".update_sample_status()
RETURNS TRIGGER AS $$
DECLARE
    new_status TEXT := TG_ARGV[0];
    target_sample_id TEXT;
BEGIN
    -- Determine the sample_id from the triggering table
    -- Most tables have a 'sample_id' column.
    -- For child samples (DNA, RNA, etc.), the status update should apply to the child sample itself.
    IF TG_TABLE_NAME IN ('dna', 'rna', 'tissue', 'fish', 'sediments', 'water', 'library', 'sequencing') THEN
        target_sample_id := NEW.sample_id;
    -- For process tables that reference a sample, use that reference.
    ELSIF TG_TABLE_NAME IN ('extraction', 'nanodrop', 'qubit', 'tapestation', 'pcr', 'qpcr', 'gelelectrophoresis', 'dissections', 'bioinformatics') THEN
        target_sample_id := NEW.sample_id;
    END IF;

    -- Update the status in the main samples table
    IF target_sample_id IS NOT NULL THEN
        UPDATE "Lab"."samples"
        SET "sample_status_id" = new_status,
            "time_modification" = CURRENT_TIMESTAMP
        WHERE "sample_id" = target_sample_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply the trigger to each relevant process table
DROP TRIGGER IF EXISTS trg_update_status_dissection ON "Lab"."Dissections";
CREATE TRIGGER trg_update_status_dissection AFTER INSERT ON "Lab"."Dissections" FOR EACH ROW EXECUTE PROCEDURE "Lab".update_sample_status('Dissection');

DROP TRIGGER IF EXISTS trg_update_status_extraction ON "Lab"."Extraction";
CREATE TRIGGER trg_update_status_extraction AFTER INSERT ON "Lab"."Extraction" FOR EACH ROW EXECUTE PROCEDURE "Lab".update_sample_status('Extracted');

DROP TRIGGER IF EXISTS trg_update_status_nanodrop ON "Lab"."Nanodrop";
CREATE TRIGGER trg_update_status_nanodrop AFTER INSERT ON "Lab"."Nanodrop" FOR EACH ROW EXECUTE PROCEDURE "Lab".update_sample_status('Nanodrop QC');

DROP TRIGGER IF EXISTS trg_update_status_qubit ON "Lab"."Qubit";
CREATE TRIGGER trg_update_status_qubit AFTER INSERT ON "Lab"."Qubit" FOR EACH ROW EXECUTE PROCEDURE "Lab".update_sample_status('Qubit QC');

DROP TRIGGER IF EXISTS trg_update_status_tapestation ON "Lab"."Tapestation";
CREATE TRIGGER trg_update_status_tapestation AFTER INSERT ON "Lab"."Tapestation" FOR EACH ROW EXECUTE PROCEDURE "Lab".update_sample_status('Tapestation QC');

DROP TRIGGER IF EXISTS trg_update_status_pcr ON "Lab"."PCR";
CREATE TRIGGER trg_update_status_pcr AFTER INSERT ON "Lab"."PCR" FOR EACH ROW EXECUTE PROCEDURE "Lab".update_sample_status('PCR Done');

DROP TRIGGER IF EXISTS trg_update_status_qpcr ON "Lab"."qPCR";
CREATE TRIGGER trg_update_status_qpcr AFTER INSERT ON "Lab"."qPCR" FOR EACH ROW EXECUTE PROCEDURE "Lab".update_sample_status('qPCR Done');

DROP TRIGGER IF EXISTS trg_update_status_library ON "Lab"."Library";
CREATE TRIGGER trg_update_status_library AFTER INSERT ON "Lab"."Library" FOR EACH ROW EXECUTE PROCEDURE "Lab".update_sample_status('Library Prep');

DROP TRIGGER IF EXISTS trg_update_status_sequencing ON "Lab"."Sequencing";
CREATE TRIGGER trg_update_status_sequencing AFTER INSERT ON "Lab"."Sequencing" FOR EACH ROW EXECUTE PROCEDURE "Lab".update_sample_status('Sequencing Done');

DROP TRIGGER IF EXISTS trg_update_status_bioinformatics ON "Lab"."bioinformatics";
CREATE TRIGGER trg_update_status_bioinformatics AFTER INSERT ON "Lab"."bioinformatics" FOR EACH ROW EXECUTE PROCEDURE "Lab".update_sample_status('Bioinformatics Done');


-- ======================================================================
-- 6. Comprehensive Views for Data Analysis and Tracking
--    Creating virtual tables (views) to simplify complex queries and provide
--    user-friendly summaries of the data.
-- ======================================================================

-- To ensure the script is re-runnable, drop existing views first.
DROP VIEW IF EXISTS "Lab"."Sample_Full_Details_View" CASCADE;
DROP VIEW IF EXISTS "Lims"."Project_Comprehensive_Summary_View" CASCADE;
DROP VIEW IF EXISTS "Lab"."Experiment_Progress_Overview_View" CASCADE;
DROP VIEW IF EXISTS "Lims"."Reagent_Status_View" CASCADE;
DROP VIEW IF EXISTS "Lab"."Sample_Audit_Trail_View" CASCADE;
DROP VIEW IF EXISTS "Lims"."Project_Financial_Summary_View" CASCADE;
DROP VIEW IF EXISTS "bioinformatics"."Full_Analysis_Results_View" CASCADE;
DROP VIEW IF EXISTS "Lab"."Storage_Occupancy_View" CASCADE;

-- View 1: A complete audit trail for each sample, showing every step and result.
-- This is the core view for tracking sample status and history.
CREATE OR REPLACE VIEW "Lab"."Sample_Audit_Trail_View" AS
SELECT
    s.sample_id,
    s."External_Name",
    'Received' AS process_step,
    s."Reception_date"::TIMESTAMP AS process_date,
    s."Reciever" AS person_id,
    p_rec."Full Name" AS person_name,
    'Sample registered in LIMS.' AS details
FROM "Lab"."samples" s
LEFT JOIN "reference"."personal" p_rec ON s."Reciever" = p_rec.person_id

UNION ALL

SELECT
    d.sample_id,
    s."External_Name",
    'Dissection' AS process_step,
    d.dissection_date::TIMESTAMP AS process_date,
    d.person_id,
    p."Full Name" AS person_name,
    'Gonad: ' || d.gonad_weight_g || 'g, Liver: ' || d.liver_weight_g || 'g' AS details
FROM "Lab"."Dissections" d
JOIN "Lab"."samples" s ON d.sample_id = s.sample_id
LEFT JOIN "reference"."personal" p ON d.person_id = p.person_id

UNION ALL

SELECT
    e.sample_id,
    s."External_Name",
    'Extraction' AS process_step,
    e.date::TIMESTAMP AS process_date,
    e.person_id,
    p."Full Name" AS person_name,
    'Kit: ' || e.kit || ', Yield: ' || e."Yield_Qubit_ng_ul" || ' ng/uL' AS details
FROM "Lab"."Extraction" e
JOIN "Lab"."samples" s ON e.sample_id = s.sample_id
LEFT JOIN "reference"."personal" p ON e.person_id = p.person_id

UNION ALL

SELECT
    q.sample_id,
    s."External_Name",
    'Qubit QC' AS process_step,
    q.date::TIMESTAMP AS process_date,
    q.person AS person_id,
    p."Full Name" AS person_name,
    'Concentration: ' || q."QubitOriginal_sample_conc" || ' ' || q."QubitOriginal_units" AS details
FROM "Lab"."Qubit" q
JOIN "Lab"."samples" s ON q.sample_id = s.sample_id
LEFT JOIN "reference"."personal" p ON q.person = p.person_id

UNION ALL

SELECT
    l.sample_id,
    s."External_Name",
    'Library Prep' AS process_step,
    l.date::TIMESTAMP AS process_date,
    l.person AS person_id,
    p."Full Name" AS person_name,
    'Kit: ' || l."LibraryPrepKit" || ', Index: ' || l."IndexSequence" AS details
FROM "Lab"."Library" l
JOIN "Lab"."samples" s ON l.sample_id = s.sample_id
LEFT JOIN "reference"."personal" p ON l.person = p.person_id

UNION ALL

SELECT
    seq.sample_id,
    s."External_Name",
    'Sequencing' AS process_step,
    seq.date::TIMESTAMP AS process_date,
    seq.person AS person_id,
    p."Full Name" AS person_name,
    'Sequencer: ' || seq."Sequencer" || ', Reads: ' || seq."TotalReads" AS details
FROM "Lab"."Sequencing" seq
JOIN "Lab"."samples" s ON seq.sample_id = s.sample_id
LEFT JOIN "reference"."personal" p ON seq.person = p.person_id

ORDER BY sample_id, process_date;


-- View 2: Project financial summary, joining projects with orders.
CREATE OR REPLACE VIEW "Lims"."Project_Financial_Summary_View" AS
SELECT
    p.project_id,
    p."Title" AS project_title,
    p."PI" AS pi_person_id,
    pers."Full Name" AS pi_name,
    SUM(o.price) AS total_cost,
    COUNT(o."FI_Order_Nr") AS number_of_orders,
    MIN(o.date) AS first_order_date,
    MAX(o.date) AS last_order_date
FROM
    "Lims"."projects" p
JOIN "Lims"."orders" o ON p.project_id = o.project_id
LEFT JOIN "reference"."personal" pers ON p."PI" = pers.person_id
GROUP BY
    p.project_id, p."Title", p."PI", pers."Full Name"
ORDER BY
    total_cost DESC;

-- View 3: Full bioinformatics results, linking taxonomic assignments back to sampling event details.
CREATE OR REPLACE VIEW "bioinformatics"."Full_Analysis_Results_View" AS
SELECT
    p.project_id,
    p."Title" AS project_title,
    samp.sampling_id,
    samp.sampling_date,
    samp."Location" AS sampling_location,
    s.sample_id,
    s."External_Name",
    ar.run_id AS analysis_run_id,
    ap.name AS pipeline_name,
    ap.version AS pipeline_version,
    t.taxon_id,
    t."En_name" AS taxon_english_name,
    t.rank AS taxon_rank,
    ea.read_count,
    ea.confidence
FROM
    "bioinformatics"."edna_assignments" ea
JOIN "bioinformatics"."analysis_runs" ar ON ea.run_id = ar.run_id
JOIN "bioinformatics"."analysis_pipelines" ap ON ar.pipeline_id = ap.pipeline_id
JOIN "Lab"."samples" s ON ea.sample_id = s.sample_id
JOIN "Lab"."sampling" samp ON s.sampling_id = samp.sampling_id
JOIN "Lims"."projects" p ON s.project_id = p.project_id
JOIN "reference"."taxon" t ON ea.taxon_id = t.taxon_id
ORDER BY
    p.project_id, samp.sampling_date, s.sample_id, ea.read_count DESC;

-- View 4: Storage occupancy, calculating the percentage of used slots in each box.
CREATE OR REPLACE VIEW "Lab"."Storage_Occupancy_View" AS
WITH box_counts AS (
    SELECT
        storage_id,
        COUNT(sample_id) AS stored_samples
    FROM "Lab"."samples"
    WHERE storage_id IS NOT NULL
    GROUP BY storage_id
)
SELECT
    st.storage_id,
    st.room_id,
    st."Freezer",
    st."Box",
    st."Box_size_X" * st."Box_size_Y" AS box_capacity,
    COALESCE(bc.stored_samples, 0) AS occupied_slots,
    (COALESCE(bc.stored_samples, 0)::NUMERIC * 100 / (st."Box_size_X" * st."Box_size_Y"))::NUMERIC(5,2) AS occupancy_percent
FROM
    "Lab"."storage" st
LEFT JOIN box_counts bc ON st.storage_id = bc.storage_id
WHERE st."Box_size_X" > 0 AND st."Box_size_Y" > 0
ORDER BY
    occupancy_percent DESC;

-- View 5 (New): Comprehensive Project Summary
-- Provides a high-level overview of projects, including sample and experiment counts.
CREATE OR REPLACE VIEW "Lims"."Project_Comprehensive_Summary_View" AS
SELECT
    p.project_id,
    p."Title" AS project_title,
    stat.description AS project_status,
    p."Funder",
    p."Start_date",
    p."End_date",
    COUNT(DISTINCT ex."Experiment_id") AS number_of_experiments,
    COUNT(DISTINCT s.sample_id) AS number_of_samples,
    SUM(o.price) AS total_order_cost
FROM "Lims"."projects" p
LEFT JOIN "reference"."status" stat ON p.status_id = stat.status_id
LEFT JOIN "Lab"."Experiments" ex ON p.project_id = ex.project_id
LEFT JOIN "Lab"."samples" s ON p.project_id = s.project_id
LEFT JOIN "Lims"."orders" o ON p.project_id = o.project_id
GROUP BY
    p.project_id, p."Title", stat.description, p."Funder", p."Start_date", p."End_date"
ORDER BY p."Start_date" DESC;

-- View 6 (New): Experiment Progress Overview
-- Tracks the progress of experiments by counting samples at each major stage.
CREATE OR REPLACE VIEW "Lab"."Experiment_Progress_Overview_View" AS
SELECT
    e."Experiment_id",
    e."Experiment_title",
    e.project_id,
    p."Title" AS project_title,
    stat.description AS experiment_status,
    e.date AS experiment_start_date,
    pers."Full Name" AS experiment_lead,
    COUNT(DISTINCT es.sample_id) AS total_samples_in_experiment,
    COUNT(DISTINCT ext.sample_id) AS samples_extracted,
    COUNT(DISTINCT qu.sample_id) AS samples_qubit_qc,
    COUNT(DISTINCT lib.sample_id) AS samples_library_prepped,
    COUNT(DISTINCT seq.sample_id) AS samples_sequenced,
    COUNT(DISTINCT bio.sample_id) AS samples_bioinformatics_done
FROM "Lab"."Experiments" e
LEFT JOIN "Lims"."projects" p ON e.project_id = p.project_id
LEFT JOIN "reference"."status" stat ON e.status_id = stat.status_id
LEFT JOIN "reference"."personal" pers ON e.person = pers.person_id
LEFT JOIN "Lab"."Experimentsamples" es ON e."Experiment_id" = es."Experiment_id"
LEFT JOIN "Lab"."Extraction" ext ON es.sample_id = ext.sample_id
LEFT JOIN "Lab"."Qubit" qu ON es.sample_id = qu.sample_id
LEFT JOIN "Lab"."Library" lib ON es.sample_id = lib."sample_id"
LEFT JOIN "Lab"."Sequencing" seq ON es.sample_id = seq.sample_id
LEFT JOIN "Lab"."bioinformatics" bio ON es.sample_id = bio.sample_id
GROUP BY
    e."Experiment_id", e."Experiment_title", e.project_id, p."Title",
    stat.description, e.date, pers."Full Name"
ORDER BY e.date DESC;

-- View 7 (New): Reagent Status View
-- Monitors the current stock and expiry dates of reagents.
CREATE OR REPLACE VIEW "Lims"."Reagent_Status_View" AS
SELECT
    r."Reagent_CompleteName",
    r.category,
    r."Lot",
    r.storage_id,
    stat.description AS current_status,
    r."Reception_date",
    r."Expire_date",
    CASE
        WHEN r."Expire_date" IS NULL THEN NULL
        ELSE (r."Expire_date" - CURRENT_DATE)
    END AS days_until_expiry
FROM "Lims"."Reagents" r
LEFT JOIN "reference"."status" stat ON r.status_id = stat.status_id
ORDER BY r."Expire_date" ASC;


-- View 8 (New): The "Mega View" for complete sample tracking, based on your original Samples_tracking view.
CREATE OR REPLACE VIEW "Lab"."Sample_Full_Details_View" AS
SELECT
    -- Core Sample Info
    s.sample_id,
    s."External_Name",
    s.project_id,
    p."Title" AS project_title,
    s.sample_type,
    s.sample_status_id,
    stat.description AS sample_status_description,
    s.time_modification AS last_status_update,
    s."Parentsample_id",

    -- Storage Info
    s.storage_id,
    stor."Freezer" AS storage_freezer,
    stor."Box" AS storage_box,
    s.storage_position,
    stor.room_id,

    -- Sampling Event Info
    samp.sampling_id AS sampling_event_id,
    samp.sampling_date AS sampling_event_date,
    samp."Location" AS sampling_location,
    samp."Depth_m" AS sampling_depth,
    samp."Temperature_Atmospheric_c",
    samp."Weather",

    -- Fish Specifics
    f.species,
    tax."En_name" AS species_english_name,
    f.total_length_mm,
    f.weight_g,
    f."Sex",
    f."MaturityStage",

    -- Extraction Results
    ext.date AS extraction_date,
    ext.kit AS extraction_kit,
    ext."Yield_Qubit_ng_ul",
    ext."A260_280" AS extraction_a260_280,

    -- Library & Sequencing
    lib."Lib_id",
    lib."LibraryPrepKit",
    lib."IndexSequence",
    seq."Seq_id",
    seq."Sequencer",
    seq."TotalReads"

FROM "Lab"."samples" s
LEFT JOIN "reference"."status" stat ON s.sample_status_id = stat.status_id
LEFT JOIN "Lims"."projects" p ON s.project_id = p.project_id
LEFT JOIN "Lab"."storage" stor ON s.storage_id = stor.storage_id
LEFT JOIN "Lab"."sampling" samp ON s.sampling_id = samp.sampling_id
-- Left join to all specific sample type and process tables
LEFT JOIN "Lab"."fish" f ON s.sample_id = f.sample_id
LEFT JOIN "reference"."taxon" tax ON f.species = tax.taxon_id
LEFT JOIN "Lab"."Extraction" ext ON s.sample_id = ext.sample_id
LEFT JOIN "Lab"."Library" lib ON s.sample_id = lib.sample_id
LEFT JOIN "Lab"."Sequencing" seq ON s.sample_id = seq.sample_id;


-- ======================================================================
-- 7. Data Auditing with a Generic Trigger
--    Creates a log of all data changes (INSERT, UPDATE, DELETE) for
--    specified tables, which is essential for traceability and compliance.
-- ======================================================================

CREATE SCHEMA IF NOT EXISTS "audit";

CREATE TABLE IF NOT EXISTS "audit"."log" (
    id SERIAL PRIMARY KEY,
    schema_name TEXT NOT NULL,
    table_name TEXT NOT NULL,
    user_name TEXT,
    action_timestamp TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    action TEXT NOT NULL CHECK (action IN ('I', 'D', 'U')),
    original_data JSONB,
    new_data JSONB,
    query TEXT
);

CREATE OR REPLACE FUNCTION "audit".if_modified_func()
RETURNS TRIGGER AS $$
DECLARE
    audit_row "audit"."log";
    include_values BOOLEAN;
    log_statement TEXT;
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
    audit_row.user_name = session_user::TEXT;
    audit_row.query = current_query();

    INSERT INTO "audit"."log" VALUES (DEFAULT, audit_row.schema_name, audit_row.table_name, audit_row.user_name,
                                    DEFAULT, audit_row.action, audit_row.original_data, audit_row.new_data, audit_row.query);

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Example of applying the audit trigger to the 'projects' table.
-- This can be applied to any table you want to audit.
DROP TRIGGER IF EXISTS audit_trigger_projects ON "Lims"."projects";
CREATE TRIGGER audit_trigger_projects
AFTER INSERT OR UPDATE OR DELETE ON "Lims"."projects"
FOR EACH ROW EXECUTE PROCEDURE "audit".if_modified_func();

-- Example of applying the audit trigger to the 'samples' table.
DROP TRIGGER IF EXISTS audit_trigger_samples ON "Lab"."samples";
CREATE TRIGGER audit_trigger_samples
AFTER INSERT OR UPDATE OR DELETE ON "Lab"."samples"
FOR EACH ROW EXECUTE PROCEDURE "audit".if_modified_func();


-- ======================================================================
-- 8. Advanced Security with Row-Level Security (RLS)
--    Restricts which rows users can access based on their identity and
--    project membership.
-- ======================================================================

-- First, enable RLS on a table.
ALTER TABLE "Lims"."projects" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Lab"."samples" ENABLE ROW LEVEL SECURITY;

-- Create a helper function to check if the current user is part of a project.
-- This assumes you set the user's person_id in the session, e.g., SET lims.person_id = 'some_user';
CREATE OR REPLACE FUNCTION "Lims".is_member_of_project(p_project_id TEXT)
RETURNS BOOLEAN AS $$
DECLARE
    current_person_id TEXT := current_setting('lims.person_id', true);
BEGIN
    IF current_person_id IS NULL THEN
        RETURN FALSE; -- Deny access if user is not set
    END IF;

    -- Check if the user is the PI or listed in projectpersons
    RETURN EXISTS (
        SELECT 1 FROM "Lims"."projects" WHERE project_id = p_project_id AND "PI" = current_person_id
    ) OR EXISTS (
        SELECT 1 FROM "Lims"."projectpersons" WHERE project_id = p_project_id AND person_id = current_person_id
    );
END;
$$ LANGUAGE plpgsql STABLE;

-- Create security policies
-- Policy 1: Users can see projects they are a member of.
DROP POLICY IF EXISTS project_membership_policy ON "Lims"."projects";
CREATE POLICY project_membership_policy ON "Lims"."projects"
FOR SELECT
USING ("Lims".is_member_of_project(project_id));

-- Policy 2: Users can see samples belonging to projects they are a member of.
DROP POLICY IF EXISTS sample_project_membership_policy ON "Lab"."samples";
CREATE POLICY sample_project_membership_policy ON "Lab"."samples"
FOR SELECT
USING ("Lims".is_member_of_project(project_id));

-- To test RLS:
-- 1. SET lims.person_id = 'some_user_id';
-- 2. SELECT * FROM "Lims"."projects"; -- You will only see projects where 'some_user_id' is a member.
-- 3. RESET lims.person_id;


-- ======================================================================
-- 9. Advanced JSONB and ltree Query Examples
-- ======================================================================

-- Example 1: Querying JSONB data from the Dissections table
-- Find all dissections where 'shrimp' was found in the stomach contents.
SELECT
    dissection_id,
    sample_id,
    stomach_contents_jsonb
FROM "Lab"."Dissections"
WHERE stomach_contents_jsonb @> '[{"item": "shrimp"}]'::jsonb;

-- Aggregate data from JSONB: Count the occurrences of each stomach item.
CREATE OR REPLACE VIEW "Lab"."Stomach_Contents_Summary_View" AS
SELECT
    item,
    COUNT(*) AS occurrence_count
FROM (
    SELECT
        (jsonb_array_elements(stomach_contents_jsonb)->>'item') AS item
    FROM "Lab"."Dissections"
    WHERE jsonb_typeof(stomach_contents_jsonb) = 'array'
) AS items
GROUP BY item
ORDER BY occurrence_count DESC;


-- Example 2: Using ltree for taxonomic hierarchy
-- STEP A: Add and populate the ltree path column in the taxon table.
ALTER TABLE "reference"."taxon" ADD COLUMN IF NOT EXISTS path LTREE;
CREATE INDEX IF NOT EXISTS idx_taxon_path_gist ON "reference"."taxon" USING GIST (path);

-- Recursive function to build the ltree paths
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

-- Run the function to populate the paths
-- SELECT "reference".update_taxon_ltree_paths();

-- STEP B: Query the hierarchy using ltree operators
-- Find all taxa belonging to the family 'Gadidae' (assuming 'Gadidae' is a taxon_id)
-- The <@ operator means 'is descendant of'
/*
SELECT * FROM "reference"."taxon"
WHERE path <@ (SELECT path FROM "reference"."taxon" WHERE taxon_id = 'Gadidae');
*/

-- Find the full lineage of 'Gadus morhua' (Atlantic Cod)
-- The @> operator means 'is ancestor of'
/*
SELECT * FROM "reference"."taxon"
WHERE path @> (SELECT path FROM "reference"."taxon" WHERE taxon_id = 'Gadus morhua')
ORDER BY path;
*/
