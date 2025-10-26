-- ... (Keep all your existing SQL code above this line) ...

-- ======================================================================
-- ELN SCHEMA AND TABLES (NEW SECTION - COMPLETE V1 + Enhancements)
-- ======================================================================

-- -- Create ELN Schema --
CREATE SCHEMA IF NOT EXISTS "eln";

-- -- ELN Utility Function (Shared) --
CREATE OR REPLACE FUNCTION "eln".update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
   NEW.updated_at = now();
   RETURN NEW;
END;
$$ language 'plpgsql';
COMMENT ON FUNCTION "eln".update_updated_at_column() IS 'Updates the updated_at timestamp on modification.';


-- -- Main ELN Tables --

-- eln.protocols: Stores the core protocol information
CREATE TABLE IF NOT EXISTS "eln"."protocols" (
    "protocol_id" text PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    "title" text NOT NULL,
    "description" text,
    "author_person_id" text REFERENCES "lims"."personal"("person_id") ON DELETE SET NULL,
    "version" integer DEFAULT 1,
    "project_id" text REFERENCES "lims"."projects"("project_id") ON DELETE SET NULL,
    "tags" text,
    "notes" text,
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "created_at" timestamptz DEFAULT CURRENT_TIMESTAMP,
    "updated_at" timestamptz DEFAULT CURRENT_TIMESTAMP,
    "attachment" bytea,
    "attachment_link" text,
    "protocol_search_vector" tsvector,
    -- Enhancements:
    "parent_protocol_id" text REFERENCES "eln"."protocols"("protocol_id") ON DELETE SET NULL, -- For forking/copying
    "is_template" boolean DEFAULT false,
    "is_public" boolean DEFAULT false, -- For potential sharing features
    "current_version_id" text -- Link to the current version in protocol_versions (FK added later)
);
COMMENT ON TABLE "eln"."protocols" IS 'Stores main laboratory protocols and ELN entries.';

-- eln.protocol_steps: Stores individual steps within a protocol
CREATE TABLE IF NOT EXISTS "eln"."protocol_steps" (
    "step_id" text PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    "protocol_id" text NOT NULL REFERENCES "eln"."protocols"("protocol_id") ON DELETE CASCADE,
    "step_number" integer NOT NULL,
    "title" text,
    "description" text NOT NULL, -- Rich text/HTML content from Quill
    "estimated_time_minutes" integer,
    "components" jsonb, -- Store linked components info as JSON for quick access (optional)
    "notes" text,
    "tags" text,
    "created_at" timestamptz DEFAULT CURRENT_TIMESTAMP,
    "updated_at" timestamptz DEFAULT CURRENT_TIMESTAMP,
    "step_search_vector" tsvector,
    -- Enhancements:
    "parent_step_id" text REFERENCES "eln"."protocol_steps"("step_id") ON DELETE SET NULL, -- For step hierarchy or linking
    "step_type" text DEFAULT 'instruction', -- e.g., 'instruction', 'timer', 'note', 'section_header'
    "expected_result" text,
    "safety_notes" text,
    CONSTRAINT unique_protocol_step_number UNIQUE ("protocol_id", "step_number")
);
COMMENT ON TABLE "eln"."protocol_steps" IS 'Stores individual steps belonging to a protocol.';
COMMENT ON COLUMN "eln"."protocol_steps"."description" IS 'Rich text/HTML content describing the step procedure.';


-- -- Versioning Tables --

-- eln.protocol_versions: Stores historical versions of the main protocol metadata
CREATE TABLE IF NOT EXISTS "eln"."protocol_versions" (
    "version_id" text PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    "protocol_id" text NOT NULL REFERENCES "eln"."protocols"("protocol_id") ON DELETE CASCADE,
    "version_number" integer NOT NULL,
    "title" text NOT NULL,
    "description" text,
    "author_person_id" text REFERENCES "lims"."personal"("person_id") ON DELETE SET NULL,
    "project_id" text REFERENCES "lims"."projects"("project_id") ON DELETE SET NULL,
    "tags" text,
    "notes" text,
    "status_id" text REFERENCES "reference"."status"("status_id"),
    "created_at" timestamptz NOT NULL, -- Timestamp when this version was created (copied from original)
    "modified_by_person_id" text REFERENCES "lims"."personal"("person_id") ON DELETE SET NULL, -- Who made the change leading to this version
    "modification_timestamp" timestamptz DEFAULT CURRENT_TIMESTAMP, -- When this version record was created
    CONSTRAINT unique_protocol_version UNIQUE ("protocol_id", "version_number")
);
COMMENT ON TABLE "eln"."protocol_versions" IS 'Stores historical snapshots of protocol metadata upon significant updates.';

-- Add FK constraint from protocols to protocol_versions after table creation
ALTER TABLE "eln"."protocols"
    ADD CONSTRAINT fk_current_version FOREIGN KEY ("current_version_id") REFERENCES "eln"."protocol_versions"("version_id") ON DELETE SET NULL;


-- eln.protocol_step_versions: Stores historical versions of protocol steps
CREATE TABLE IF NOT EXISTS "eln"."protocol_step_versions" (
    "step_version_id" text PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    "protocol_version_id" text NOT NULL REFERENCES "eln"."protocol_versions"("version_id") ON DELETE CASCADE,
    "original_step_id" text NOT NULL, -- References the step_id in the main protocol_steps table
    "step_number" integer NOT NULL,
    "title" text,
    "description" text,
    "estimated_time_minutes" integer,
    "components" jsonb,
    "step_type" text,
    "expected_result" text,
    "safety_notes" text,
    "notes" text,
    "tags" text,
    "created_at" timestamptz NOT NULL, -- Timestamp when this step version was created (copied from original)
    "modification_timestamp" timestamptz DEFAULT CURRENT_TIMESTAMP -- When this version record was created
    -- No direct FK to protocol_steps on original_step_id to allow step deletion while retaining history
);
COMMENT ON TABLE "eln"."protocol_step_versions" IS 'Stores historical snapshots of protocol steps linked to a specific protocol version.';


-- -- Feature Tables --

-- eln.step_components: Defines components (reagents, equipment, samples) used in a step
CREATE TABLE IF NOT EXISTS "eln"."step_components" (
    "component_link_id" text PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    "step_id" text NOT NULL REFERENCES "eln"."protocol_steps"("step_id") ON DELETE CASCADE,
    "component_type" text NOT NULL CHECK ("component_type" IN ('reagent', 'equipment', 'sample', 'consumable', 'other')), -- Type of component
    "component_id" text NOT NULL, -- ID linking to the specific item (e.g., reagent_id, equipment_id, sample_id, inventory_item_id)
    "component_name" text, -- Denormalized name for easier display
    "quantity" numeric,
    "unit_id" text REFERENCES "reference"."units"("unit_id"),
    "concentration" numeric,
    "concentration_unit_id" text REFERENCES "reference"."units"("unit_id"), -- e.g., ng/ul, Molar
    "storage_location" text, -- Optional: Specific location if needed (e.g., Freezer A, Shelf 3)
    "notes" text,
    "added_at" timestamptz DEFAULT CURRENT_TIMESTAMP
    -- Consider adding FK constraints based on component_type if feasible and desired
);
COMMENT ON TABLE "eln"."step_components" IS 'Links protocol steps to specific components like reagents, equipment, or samples.';


-- eln.comments: Stores comments on protocols or specific steps
CREATE TABLE IF NOT EXISTS "eln"."comments" (
    "comment_id" text PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    "protocol_id" text NOT NULL REFERENCES "eln"."protocols"("protocol_id") ON DELETE CASCADE,
    "step_id" text REFERENCES "eln"."protocol_steps"("step_id") ON DELETE CASCADE, -- Optional: Link comment to a specific step
    "parent_comment_id" text REFERENCES "eln"."comments"("comment_id") ON DELETE CASCADE, -- For threaded comments
    "person_id" text NOT NULL REFERENCES "lims"."personal"("person_id") ON DELETE CASCADE,
    "comment_text" text NOT NULL,
    "created_at" timestamptz DEFAULT CURRENT_TIMESTAMP,
    "updated_at" timestamptz DEFAULT CURRENT_TIMESTAMP,
    "tags" text,
    "comment_search_vector" tsvector, -- Added search vector
    CONSTRAINT chk_comment_target CHECK ("step_id" IS NOT NULL OR "protocol_id" IS NOT NULL) -- Ensure comment links somewhere
);
COMMENT ON TABLE "eln"."comments" IS 'Stores user comments related to protocols or specific steps.';


-- eln.step_executions: Tracks the execution and completion status of steps
CREATE TABLE IF NOT EXISTS "eln"."step_executions" (
    "execution_id" text PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    "protocol_run_guid" uuid DEFAULT uuid_generate_v4(), -- A GUID to group all steps executed in a single run/instance of the protocol
    "protocol_id" text NOT NULL REFERENCES "eln"."protocols"("protocol_id") ON DELETE CASCADE, -- Link to the protocol being run
    "protocol_version_id" text REFERENCES "eln"."protocol_versions"("version_id") ON DELETE SET NULL, -- Link to the specific version run (optional but recommended)
    "step_id" text NOT NULL, -- Link to the step being executed (No FK to allow history if step deleted)
    "step_number" integer, -- Denormalized for easier ordering/display
    "executed_by_person_id" text REFERENCES "lims"."personal"("person_id") ON DELETE SET NULL,
    "start_time" timestamptz,
    "end_time" timestamptz,
    "status" text DEFAULT 'pending' CHECK (status IN ('pending', 'in_progress', 'completed', 'skipped', 'failed')),
    "actual_duration_minutes" integer GENERATED ALWAYS AS (
        CASE WHEN start_time IS NOT NULL AND end_time IS NOT NULL THEN
            EXTRACT(EPOCH FROM (end_time - start_time))/60
        ELSE NULL END
    ) STORED,
    "execution_notes" text, -- Notes specific to this execution instance (e.g., deviations)
    "results_summary" text, -- Brief summary of results for this step instance
    "results_data" jsonb, -- Store structured results data if applicable
    "attachment" bytea,
    "attachment_link" text,
    "created_at" timestamptz DEFAULT CURRENT_TIMESTAMP -- When this execution record was created
);
COMMENT ON TABLE "eln"."step_executions" IS 'Tracks the execution status, timing, and results for each step during a protocol run.';
COMMENT ON COLUMN "eln"."step_executions"."protocol_run_guid" IS 'Groups all step executions belonging to the same instance of running a protocol.';

-- -- Indexes for ELN tables --
CREATE INDEX IF NOT EXISTS idx_eln_protocols_author ON "eln"."protocols" ("author_person_id");
CREATE INDEX IF NOT EXISTS idx_eln_protocols_project ON "eln"."protocols" ("project_id");
CREATE INDEX IF NOT EXISTS idx_eln_protocols_search ON "eln"."protocols" USING GIN ("protocol_search_vector");
CREATE INDEX IF NOT EXISTS idx_eln_protocol_steps_protocol ON "eln"."protocol_steps" ("protocol_id");
CREATE INDEX IF NOT EXISTS idx_eln_protocol_steps_search ON "eln"."protocol_steps" USING GIN ("step_search_vector");
CREATE INDEX IF NOT EXISTS idx_eln_protocol_versions_protocol ON "eln"."protocol_versions" ("protocol_id");
CREATE INDEX IF NOT EXISTS idx_eln_step_versions_protocol_version ON "eln"."protocol_step_versions" ("protocol_version_id");
CREATE INDEX IF NOT EXISTS idx_eln_step_versions_original_step ON "eln"."protocol_step_versions" ("original_step_id");
CREATE INDEX IF NOT EXISTS idx_eln_step_components_step ON "eln"."step_components" ("step_id");
CREATE INDEX IF NOT EXISTS idx_eln_step_components_component ON "eln"."step_components" ("component_type", "component_id");
CREATE INDEX IF NOT EXISTS idx_eln_comments_protocol ON "eln"."comments" ("protocol_id");
CREATE INDEX IF NOT EXISTS idx_eln_comments_step ON "eln"."comments" ("step_id");
CREATE INDEX IF NOT EXISTS idx_eln_comments_person ON "eln"."comments" ("person_id");
CREATE INDEX IF NOT EXISTS idx_eln_comments_search ON "eln"."comments" USING GIN ("comment_search_vector");
CREATE INDEX IF NOT EXISTS idx_eln_step_executions_run_guid ON "eln"."step_executions" ("protocol_run_guid");
CREATE INDEX IF NOT EXISTS idx_eln_step_executions_protocol ON "eln"."step_executions" ("protocol_id");
CREATE INDEX IF NOT EXISTS idx_eln_step_executions_step ON "eln"."step_executions" ("step_id");
CREATE INDEX IF NOT EXISTS idx_eln_step_executions_person ON "eln"."step_executions" ("executed_by_person_id");
CREATE INDEX IF NOT EXISTS idx_eln_step_executions_status ON "eln"."step_executions" ("status");


-- -- ELN Triggers --

-- Update 'updated_at' timestamp triggers
CREATE TRIGGER trg_update_protocols_updated_at BEFORE UPDATE ON "eln"."protocols"
FOR EACH ROW EXECUTE FUNCTION "eln".update_updated_at_column();

CREATE TRIGGER trg_update_steps_updated_at BEFORE UPDATE ON "eln"."protocol_steps"
FOR EACH ROW EXECUTE FUNCTION "eln".update_updated_at_column();

CREATE TRIGGER trg_update_comments_updated_at BEFORE UPDATE ON "eln"."comments"
FOR EACH ROW EXECUTE FUNCTION "eln".update_updated_at_column();


-- Full Text Search update triggers
CREATE OR REPLACE FUNCTION "eln".update_protocol_search_vector_func() RETURNS TRIGGER AS $$
BEGIN
    NEW.protocol_search_vector =
        setweight(to_tsvector('public.lims_english', coalesce(NEW.title,'')), 'A') ||
        setweight(to_tsvector('public.lims_english', coalesce(NEW.description,'')), 'B') ||
        setweight(to_tsvector('public.lims_english', coalesce(NEW.tags,'')), 'C') ||
        setweight(to_tsvector('public.lims_english', coalesce(NEW.notes,'')), 'D');
    RETURN NEW;
END $$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_protocol_search BEFORE INSERT OR UPDATE ON "eln"."protocols"
FOR EACH ROW EXECUTE FUNCTION "eln".update_protocol_search_vector_func();


CREATE OR REPLACE FUNCTION "eln".update_step_search_vector_func() RETURNS TRIGGER AS $$
BEGIN
    NEW.step_search_vector =
        setweight(to_tsvector('public.lims_english', coalesce(NEW.title,'')), 'B') ||
        setweight(to_tsvector('public.lims_english', regexp_replace(coalesce(NEW.description,''), '<[^>]*>', '', 'g')) , 'C') || -- Strip HTML tags
        setweight(to_tsvector('public.lims_english', coalesce(NEW.notes,'')), 'D') ||
        setweight(to_tsvector('public.lims_english', coalesce(NEW.tags,'')), 'D');
    RETURN NEW;
END $$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_step_search BEFORE INSERT OR UPDATE ON "eln"."protocol_steps"
FOR EACH ROW EXECUTE FUNCTION "eln".update_step_search_vector_func();


CREATE OR REPLACE FUNCTION "eln".update_comment_search_vector_func() RETURNS TRIGGER AS $$
BEGIN
    NEW.comment_search_vector = to_tsvector('public.lims_english', coalesce(NEW.comment_text,''));
    RETURN NEW;
END $$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_comment_search BEFORE INSERT OR UPDATE ON "eln"."comments"
FOR EACH ROW EXECUTE FUNCTION "eln".update_comment_search_vector_func();


-- Versioning Trigger
CREATE OR REPLACE FUNCTION "eln".create_protocol_version_snapshot()
RETURNS TRIGGER AS $$
DECLARE
    v_new_version_number integer;
    v_new_version_id text;
BEGIN
    -- Only run if title or description actually changes
    IF NEW.title IS DISTINCT FROM OLD.title OR NEW.description IS DISTINCT FROM OLD.description THEN

        -- 1. Determine the next version number
        SELECT COALESCE(MAX(version_number), 0) + 1
        INTO v_new_version_number
        FROM "eln"."protocol_versions"
        WHERE protocol_id = OLD.protocol_id;

        -- 2. Insert snapshot of the *old* state into protocol_versions
        INSERT INTO "eln"."protocol_versions" (
            protocol_id, version_number, title, description, author_person_id,
            project_id, tags, notes, status_id, created_at, modified_by_person_id
        )
        VALUES (
            OLD.protocol_id, v_new_version_number, OLD.title, OLD.description, OLD.author_person_id,
            OLD.project_id, OLD.tags, OLD.notes, OLD.status_id, OLD.created_at, current_setting('lims.current_person_id', TRUE)
        ) RETURNING version_id INTO v_new_version_id;

        -- 3. Insert snapshots of all *current* steps associated with this old protocol state
        INSERT INTO "eln"."protocol_step_versions" (
            protocol_version_id, original_step_id, step_number, title, description,
            estimated_time_minutes, components, step_type, expected_result, safety_notes, notes, tags, created_at
        )
        SELECT
            v_new_version_id, s.step_id, s.step_number, s.title, s.description,
            s.estimated_time_minutes, s.components, s.step_type, s.expected_result, s.safety_notes, s.notes, s.tags, s.created_at
        FROM "eln"."protocol_steps" s
        WHERE s.protocol_id = OLD.protocol_id;

        -- 4. Update the main protocol record's version number and current_version_id link
        NEW.version = v_new_version_number;
        NEW.current_version_id = v_new_version_id;

    END IF;

    -- Always update the 'updated_at' timestamp on the main protocol record for any change
    NEW.updated_at = CURRENT_TIMESTAMP;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_version_protocol_on_update ON "eln"."protocols";
CREATE TRIGGER trg_version_protocol_on_update
BEFORE UPDATE ON "eln"."protocols"
FOR EACH ROW
WHEN (OLD.* IS DISTINCT FROM NEW.*) -- Trigger on any change, function checks specific fields
EXECUTE FUNCTION "eln".create_protocol_version_snapshot();


-- Audit Triggers for ALL new ELN tables
CREATE TRIGGER audit_trigger_eln_protocols AFTER INSERT OR UPDATE OR DELETE ON "eln"."protocols"
FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();

CREATE TRIGGER audit_trigger_eln_protocol_steps AFTER INSERT OR UPDATE OR DELETE ON "eln"."protocol_steps"
FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();

CREATE TRIGGER audit_trigger_eln_protocol_versions AFTER INSERT OR UPDATE OR DELETE ON "eln"."protocol_versions"
FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();

CREATE TRIGGER audit_trigger_eln_step_versions AFTER INSERT OR UPDATE OR DELETE ON "eln"."protocol_step_versions"
FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();

CREATE TRIGGER audit_trigger_eln_step_components AFTER INSERT OR UPDATE OR DELETE ON "eln"."step_components"
FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();

CREATE TRIGGER audit_trigger_eln_comments AFTER INSERT OR UPDATE OR DELETE ON "eln"."comments"
FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();

CREATE TRIGGER audit_trigger_eln_step_executions AFTER INSERT OR UPDATE OR DELETE ON "eln"."step_executions"
FOR EACH ROW EXECUTE FUNCTION "audit"."if_modified_func"();


-- Update global search function to include ELN schema and new tables
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
            c.table_schema IN ('lab', 'lims', 'reference', 'bioinformatics', 'projects', 'eln') -- Added 'eln'
            AND c.column_name LIKE '%_search_vector'
    LOOP
        query := format(
            'SELECT %L, %L, to_jsonb(t) FROM %I.%I AS t WHERE %I @@ plainto_tsquery(''public.lims_english'', %L) LIMIT 10', -- Using plainto_tsquery and adding LIMIT
            rec.table_schema,
            rec.table_name,
            rec.table_schema,
            rec.table_name,
            rec.column_name,
            p_search_term
        );
        -- Execute safely
        BEGIN
            RETURN QUERY EXECUTE query;
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'Search failed for %.%: %', rec.table_schema, rec.table_name, SQLERRM;
        END;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- ======================================================================
-- END OF ELN SCHEMA ADDITIONS
-- ======================================================================

