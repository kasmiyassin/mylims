
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
        FROM "lab"."parental_samples" s
        WHERE s.sample_id = target_sample_id;

        IF target_sample_sampling_date IS NULL THEN
            RAISE WARNING 'Could not determine sampling_date for sample_id % to update status in lab.samples. Status not updated.', target_sample_id;
            RETURN NEW;
        END IF;
    END IF;

    IF target_sample_id IS NOT NULL AND target_sample_sampling_date IS NOT NULL THEN
        UPDATE "lab"."parental_samples"
        SET "sample_status_id" = new_status
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

    EXECUTE 'CREATE TABLE IF NOT EXISTS "lab".' || quote_ident(partition_name) || ' PARTITION OF "lab"."parental_samples"
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

    EXECUTE 'CREATE TABLE IF NOT EXISTS "lab".' || quote_ident(partition_name) || ' PARTITION OF "lab"."parental_samples"
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
CREATE INDEX IF NOT EXISTS idx_samples_parent_sample_id ON "lab"."parental_samples" ("parent_sample_id");
CREATE INDEX IF NOT EXISTS idx_samples_sample_type_id ON "lab"."parental_samples" ("sample_type_id");
CREATE INDEX IF NOT EXISTS idx_samples_project_id ON "lab"."parental_samples" ("project_id");
CREATE INDEX IF NOT EXISTS idx_samples_storage_position ON "lab"."parental_samples" ("storage_position");
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
AFTER INSERT OR UPDATE OR DELETE ON "lab"."parental_samples"
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
CREATE TRIGGER trg_generate_sample_id BEFORE INSERT ON "lab"."parental_samples" FOR EACH ROW EXECUTE FUNCTION "lab".generate_sample_id();
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
BEFORE INSERT OR UPDATE ON "lab"."parental_samples"
FOR EACH ROW
EXECUTE FUNCTION "lab".validate_sample_sampling_date();

CREATE TRIGGER trg_create_sampling_partition
BEFORE INSERT ON "lab"."sampling"
FOR EACH ROW
EXECUTE FUNCTION "lab".create_sampling_partition_if_not_exists();

CREATE TRIGGER trg_create_samples_partition
BEFORE INSERT ON "lab"."parental_samples"
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

ALTER TABLE "lab"."parental_samples" ADD COLUMN IF NOT EXISTS sample_search_vector TSVECTOR;
CREATE INDEX IF NOT EXISTS idx_samples_gin_search ON "lab"."parental_samples" USING GIN (sample_search_vector);
CREATE TRIGGER trg_update_sample_search BEFORE INSERT OR UPDATE ON "lab"."parental_samples" FOR EACH ROW EXECUTE FUNCTION "lab".update_sample_search_vector_func();

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
DROP TRIGGER IF EXISTS trg_update_sample_search ON "lab"."parental_samples";
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

ALTER TABLE "lab"."parental_samples" ADD COLUMN IF NOT EXISTS sample_search_vector TSVECTOR;
CREATE INDEX IF NOT EXISTS idx_samples_gin_search ON "lab"."parental_samples" USING GIN (sample_search_vector);
CREATE TRIGGER trg_update_sample_search BEFORE INSERT OR UPDATE ON "lab"."parental_samples" FOR EACH ROW EXECUTE FUNCTION "lab".update_sample_search_vector_func();

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
