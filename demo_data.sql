-- ======================================================================
-- DEMO DATA GENERATION FOR ALL TABLES
-- ======================================================================

-- Set a session variable for the current person for audit logs
SET lims.current_person_id TO 'system_user';

-- Disable triggers temporarily to avoid potential conflicts or performance issues during mass insert
-- Re-enable them after all data is inserted if needed, but for ID generation and partitioning, they are crucial.
-- For this script, we'll rely on the triggers for ID generation and partitioning.
-- ALTER TABLE "lab"."samples" DISABLE TRIGGER trg_generate_sample_id; -- This is NOT done as we rely on it.

-- 0. Populate core reference tables if not already done by schema script (using ON CONFLICT DO NOTHING)
-- These inserts are assumed to be in the main schema script already and are crucial for FKs.
-- INSERT INTO "reference"."status" ("status_id", "notes") VALUES ...
-- INSERT INTO "reference"."samples_type" ("sample_type_id", "sample_type_abrv", "notes") VALUES ...
-- INSERT INTO "reference"."units" ("unit_id", "unit_name", "unit_abbreviation", "unit_type", "conversion_factor_to_base") VALUES ...
-- INSERT INTO "reference"."personal" ("person_id", "full_name", "password_hash") VALUES ('system_user', 'System Automation', 'no_password_needed_for_system') ON CONFLICT ("person_id") DO NOTHING;

-- 1. Reference Data Tables (No/Few Outgoing FKs)
----------------------------------------------------------------------

-- reference.personal (extend existing, person_id is direct PK, not generated)
INSERT INTO "reference"."personal" ("person_id", "full_name", "room", "telephone", "mail", "password_hash", "notes")
SELECT
    'person_' || LPAD(s::TEXT, 3, '0'),
    'Demo Person ' || s,
    'Room ' || (s % 10 + 1) || '0',
    '999-000-' || LPAD(s::TEXT, 4, '0'),
    'demo.person.' || s || '@example.com',
    'hashed_pass_' || s,
    'Auto-generated demo person.'
FROM generate_series(1, 100) s
ON CONFLICT ("person_id") DO NOTHING; -- To avoid conflicts with 'system_user' or existing demo data

-- lims.external_contacts (contact_id is direct PK, not generated)
INSERT INTO "lims"."external_contacts" ("contact_id", "full_name", "organization", "telephone", "mail", "address", "password_hash", "notes")
SELECT
    'contact_' || SUBSTRING(REPLACE(uuid_generate_v4()::TEXT, '-', ''), 1, 6) || LPAD(s::TEXT, 3, '0'),
    'External Contact ' || s,
    'Org ' || (s % 20 + 1),
    '111-222-' || LPAD(s::TEXT, 4, '0'),
    'external.contact.' || s || '@org.com',
    'Street ' || s || ', City ' || (s % 10 + 1), -- Added missing 'address' column value
    'ext_hash_' || s,
    'Demo external contact ' || s || '.' -- Corrected 'notes' column value
FROM generate_series(1, 100) s
ON CONFLICT ("contact_id") DO NOTHING;

-- lims.customers (customer_id is SERIAL, so omit it)
INSERT INTO "lims"."customers" ("customer_name", "customer_abrv", "address", "mail", "phone", "password_hash", "notes")
SELECT
    'Customer ' || s,
    'CUST' || SUBSTRING(REPLACE(uuid_generate_v4()::TEXT, '-', ''), 1, 6) || LPAD(s::TEXT, 3, '0'), -- Generate unique part
    '123 Demo St, City ' || s,
    'customer' || s || '@demo.com',
    '555-100-' || LPAD(s::TEXT, 4, '0'),
    'cust_hash_' || s,
    'Demo customer generated for testing.'
FROM generate_series(1, 100) s
ON CONFLICT ("customer_abrv") DO NOTHING;


-- reference.room (room_id is direct PK, not generated)
INSERT INTO "reference"."room" ("room_id", "etage", "address", "notes")
SELECT
    'ROOM' || SUBSTRING(REPLACE(uuid_generate_v4()::TEXT, '-', ''), 1, 6) || LPAD(s::TEXT, 3, '0'),
    CASE (s % 3) WHEN 0 THEN 'Ground' WHEN 1 THEN 'First' ELSE 'Second' END,
    'Building A, ' || (s % 10 + 1) || ' Main St',
    'Demo room for storage.'
FROM generate_series(1, 100) s
ON CONFLICT ("room_id") DO NOTHING;

-- reference.vessel (vessel_id is direct PK, not generated)
INSERT INTO "reference"."vessel" ("vessel_id", "vessel_name", "belong_to", "notes")
SELECT
    'VESSEL' || SUBSTRING(REPLACE(uuid_generate_v4()::TEXT, '-', ''), 1, 6) || LPAD(s::TEXT, 3, '0'),
    'Research Vessel ' || s,
    'Institute ' || (s % 5 + 1),
    'Demo research vessel.'
FROM generate_series(1, 100) s
ON CONFLICT ("vessel_id") DO NOTHING;

-- reference.region (region_id is direct PK, not generated)
INSERT INTO "reference"."region" ("region_id", "region_abrv", "country", "category", "notes")
SELECT
    'REGION' || SUBSTRING(REPLACE(uuid_generate_v4()::TEXT, '-', ''), 1, 6) || LPAD(s::TEXT, 3, '0'),
    'RGN' || SUBSTRING(REPLACE(uuid_generate_v4()::TEXT, '-', ''), 1, 4) || LPAD(s::TEXT, 2, '0'),
    CASE (s % 3) WHEN 0 THEN 'Germany' WHEN 1 THEN 'Norway' ELSE 'Canada' END,
    CASE (s % 2) WHEN 0 THEN 'Oceanic' ELSE 'Coastal' END,
    'Demo geographic region.'
FROM generate_series(1, 100) s
ON CONFLICT ("region_id") DO NOTHING;

-- reference.ecosystem (ecosystem_id is direct PK, not generated)
INSERT INTO "reference"."ecosystem" ("ecosystem_id", "ecosystem_abrv", "country", "category", "notes")
SELECT
    'ECO' || SUBSTRING(REPLACE(uuid_generate_v4()::TEXT, '-', ''), 1, 6) || LPAD(s::TEXT, 3, '0'),
    'ECO' || SUBSTRING(REPLACE(uuid_generate_v4()::TEXT, '-', ''), 1, 4) || LPAD(s::TEXT, 2, '0'),
    CASE (s % 3) WHEN 0 THEN 'Germany' WHEN 1 THEN 'Norway' ELSE 'Canada' END,
    CASE (s % 2) WHEN 0 THEN 'Marine' ELSE 'Freshwater' END,
    'Demo ecosystem type.'
FROM generate_series(1, 100) s
ON CONFLICT ("ecosystem_id") DO NOTHING;

-- reference.category (category_id is direct PK, not generated)
INSERT INTO "reference"."category" ("category_id", "notes")
SELECT
    'CAT' || SUBSTRING(REPLACE(uuid_generate_v4()::TEXT, '-', ''), 1, 6) || LPAD(s::TEXT, 3, '0'),
    'Demo category ' || s
FROM generate_series(1, 100) s
ON CONFLICT ("category_id") DO NOTHING;

-- reference.gene (gene_id is direct PK, not generated)
INSERT INTO "reference"."gene" ("gene_id", "notes")
SELECT
    'GENE' || SUBSTRING(REPLACE(uuid_generate_v4()::TEXT, '-', ''), 1, 6) || LPAD(s::TEXT, 3, '0'),
    'Demo gene ' || s || ' (e.g., COI, 16S)'
FROM generate_series(1, 100) s
ON CONFLICT ("gene_id") DO NOTHING;

-- reference.taxon (taxon_id is direct PK, path is generated by trigger)
-- Populate with some base taxa first for hierarchy
INSERT INTO "reference"."taxon" ("taxon_id", "taxon_parent", "de_name", "en_name", "rank", "notes") VALUES
('Animalia', NULL, 'Tiere', 'Animals', 'kingdom', 'Kingdom of animals'),
('Chordata', 'Animalia', 'Chordates', 'Chordates', 'phylum', 'Phylum of Chordates'),
('Vertebrata', 'Chordata', 'Wirbeltiere', 'Vertebrates', 'subphylum', 'Subphylum of Vertebrates'),
('Actinopterygii', 'Vertebrata', 'Strahlenflosser', 'Ray-finned fishes', 'class', 'Class of Ray-finned fishes'),
('Gadiformes', 'Actinopterygii', 'Dorschartige', 'Cod-like fishes', 'order', 'Order of Cod-like fishes'),
('Gadidae', 'Gadiformes', 'Dorsche', 'Cod family', 'family', 'Family of Cods'),
('Gadus', 'Gadidae', 'Dorsche', 'Cod', 'genus', 'Genus of Cod'),
('Gadus morhua', 'Gadus', 'Kabeljau', 'Atlantic Cod', 'species', 'Atlantic Cod species')
ON CONFLICT ("taxon_id") DO NOTHING;

-- Add more demo taxa, referencing existing parents randomly
INSERT INTO "reference"."taxon" ("taxon_id", "taxon_parent", "de_name", "en_name", "rank", "notes")
SELECT
    'TX' || SUBSTRING(REPLACE(uuid_generate_v4()::TEXT, '-', ''), 1, 6) || LPAD(s::TEXT, 4, '0'),
    (SELECT taxon_id FROM "reference"."taxon" WHERE rank IN ('genus', 'family', 'order', 'class') ORDER BY RANDOM() LIMIT 1),
    'Demo Taxon De ' || s,
    'Demo Taxon En ' || s,
    CASE (s % 6)
        WHEN 0 THEN 'species'
        WHEN 1 THEN 'genus'
        WHEN 2 THEN 'family'
        WHEN 3 THEN 'order'
        WHEN 4 THEN 'class'
        ELSE 'phylum'
    END,
    'Auto-generated demo taxon.'
FROM generate_series(9, 100) s
ON CONFLICT ("taxon_id") DO NOTHING;

-- reference.species (species_id directly mapped to taxon_id)
INSERT INTO "reference"."species" ("species_id", "de_name", "en_name", "max_length_mm", "max_age_years", "notes")
SELECT
    t.taxon_id,
    'Demo ' || t.en_name || ' (de)',
    t.en_name,
    (s * 10)::NUMERIC + 10,
    (s * 0.1)::NUMERIC + 1,
    'Demo species data.'
FROM generate_series(1, 100) s
JOIN (
    SELECT taxon_id, en_name
    FROM "reference"."taxon"
    WHERE rank = 'species' AND taxon_id LIKE 'TX%' -- Only new generated species taxa
    ORDER BY RANDOM()
    LIMIT 100 -- Ensure we pick 100 distinct ones
) t ON TRUE
ON CONFLICT ("species_id") DO NOTHING;

-- Additionally, ensure 'Gadus morhua' exists
INSERT INTO "reference"."species" ("species_id", "de_name", "en_name", "max_length_mm", "max_age_years", "notes") VALUES
('Gadus morhua', 'Kabeljau', 'Atlantic Cod', 1500, 25, 'Well-known fish species.')
ON CONFLICT ("species_id") DO NOTHING;


-- lims.publication_type (publication_type_id is direct PK, not generated)
INSERT INTO "lims"."publication_type" ("publication_type_id", "notes")
SELECT
    'PUBTYPE' || SUBSTRING(REPLACE(uuid_generate_v4()::TEXT, '-', ''), 1, 6) || LPAD(s::TEXT, 3, '0'),
    'Demo publication type ' || s
FROM generate_series(1, 100) s
ON CONFLICT ("publication_type_id") DO NOTHING;


-- bioinformatics.reference_databases (db_id is direct PK, not generated)
INSERT INTO "bioinformatics"."reference_databases" ("db_id", "db_name", "db_version", "notes", "url", "last_updated_date")
SELECT
    'DB' || SUBSTRING(REPLACE(uuid_generate_v4()::TEXT, '-', ''), 1, 6) || LPAD(s::TEXT, 3, '0'),
    'Demo DB ' || s,
    'v' || (s % 5 + 1) || '.' || (s % 10),
    'Reference database for bioinformatics.',
    'http://db.example.com/' || s,
    (CURRENT_DATE - (s || ' days')::INTERVAL)::DATE
FROM generate_series(1, 100) s
ON CONFLICT ("db_id") DO NOTHING;

-- lims.workflows (workflow_id is direct PK, not generated)
INSERT INTO "lims"."workflows" ("workflow_id", "workflow_name", "notes")
SELECT
    'WF' || SUBSTRING(REPLACE(uuid_generate_v4()::TEXT, '-', ''), 1, 6) || LPAD(s::TEXT, 3, '0'),
    'Workflow ' || s,
    'Description for Workflow ' || s
FROM generate_series(1, 100) s
ON CONFLICT ("workflow_id") DO NOTHING;


-- lims.permits (permit_id is direct PK, not generated)
INSERT INTO "lims"."permits" ("permit_id", "permit_number", "issuing_authority", "valid_from", "valid_to", "reference", "notes")
SELECT
    'PERMIT' || SUBSTRING(REPLACE(uuid_generate_v4()::TEXT, '-', ''), 1, 6) || LPAD(s::TEXT, 3, '0'),
    'PN-' || LPAD(s::TEXT, 5, '0'),
    'Authority ' || (s % 10 + 1),
    (CURRENT_DATE - (s * 10 || ' days')::INTERVAL)::DATE,
    (CURRENT_DATE + (s * 10 || ' days')::INTERVAL)::DATE,
    'Ref-' || s,
    'Demo permit data.'
FROM generate_series(1, 100) s
ON CONFLICT ("permit_id") DO NOTHING;

-- lims.primers (primer_id is direct PK, uses gene_id)
INSERT INTO "lims"."primers" ("primer_id", "target_gene_id", "primer_sequence_fwd", "primer_sequence_rev", "probe", "reference", "notes")
SELECT
    'PRIMER' || SUBSTRING(REPLACE(uuid_generate_v4()::TEXT, '-', ''), 1, 6) || LPAD(s::TEXT, 3, '0'),
    (SELECT gene_id FROM "reference"."gene" ORDER BY RANDOM() LIMIT 1),
    'ATGCATGC' || LPAD(s::TEXT, 2, '0') || 'NNNN',
    'GCATGCAT' || LPAD(s::TEXT, 2, '0') || 'MMMM',
    CASE (s % 2) WHEN 0 THEN 'ProbeA' ELSE 'ProbeB' END,
    'Primer Ref ' || s,
    'Demo primer data.'
FROM generate_series(1, 100) s
ON CONFLICT ("primer_id") DO NOTHING;


-- lims.sop (sop_id generated by trigger, uses personal_id)
INSERT INTO "lims"."sop" ("title", "sop_id_origin", "version", "author_person_id", "reviewer1_person_id", "reviewer2_person_id", "date_realise", "sop_protocol", "notes")
SELECT
    'SOP Title ' || s,
    'SOP_' || LPAD(s::TEXT, 3, '0'),
    (s % 5 + 1) || '.' || (s % 10),
    (SELECT person_id FROM "reference"."personal" ORDER BY RANDOM() LIMIT 1),
    (SELECT person_id FROM "reference"."personal" ORDER BY RANDOM() LIMIT 1),
    (SELECT person_id FROM "reference"."personal" ORDER BY RANDOM() LIMIT 1),
    (CURRENT_DATE - (s || ' days')::INTERVAL)::DATE,
    'This is the detailed protocol for SOP ' || s || '.',
    'Notes for SOP ' || s
FROM generate_series(1, 100) s
ON CONFLICT ("sop_id") DO NOTHING;


-- lims.workflow_steps (step_id generated by trigger, uses workflow_id, sop_id, status_id)
INSERT INTO "lims"."workflow_steps" ("workflow_id", "step_number", "step_name", "sop_id", "workflow_status_id", "target_table_name", "notes")
SELECT
    (SELECT workflow_id FROM "lims"."workflows" ORDER BY RANDOM() LIMIT 1),
    (s % 10 + 1), -- Step numbers from 1 to 10
    'Step ' || (s % 10 + 1) || ' of Workflow ' || s,
    (SELECT sop_id FROM "lims"."sop" ORDER BY RANDOM() LIMIT 1),
    (SELECT status_id FROM "reference"."status" ORDER BY RANDOM() LIMIT 1),
    CASE (s % 3) WHEN 0 THEN 'lab.samples' WHEN 1 THEN 'lab.extraction' ELSE 'bioinformatics.analysis_runs' END,
    'Demo workflow step.'
FROM generate_series(1, 100) s
ON CONFLICT ("workflow_id", "step_number") DO NOTHING;


-- lims.equipment (equipment_id is direct PK, uses room_id)
INSERT INTO "lims"."equipment" ("equipment_id", "equipment_name", "room_id", "lot", "mobility", "date_maintenance", "notes")
SELECT
    'EQ' || SUBSTRING(REPLACE(uuid_generate_v4()::TEXT, '-', ''), 1, 6) || LPAD(s::TEXT, 3, '0'),
    'Equipment ' || s,
    (SELECT room_id FROM "reference"."room" ORDER BY RANDOM() LIMIT 1),
    'LOT' || LPAD(s::TEXT, 4, '0'),
    CASE (s % 2) WHEN 0 THEN 'Fixed' ELSE 'Mobile' END,
    (CURRENT_DATE - (s * 5 || ' days')::INTERVAL)::DATE,
    'Demo equipment.'
FROM generate_series(1, 100) s
ON CONFLICT ("equipment_id") DO NOTHING;


-- lims.suppliers (supplier_id is direct PK, not generated)
INSERT INTO "lims"."suppliers" ("supplier_id", "supplier_name", "address", "contact_person", "phone", "mail", "notes")
SELECT
    'SUPP' || SUBSTRING(REPLACE(uuid_generate_v4()::TEXT, '-', ''), 1, 6) || LPAD(s::TEXT, 3, '0'),
    'Supplier ' || s,
    'Supplier Address ' || s,
    'Contact ' || s,
    '777-888-' || LPAD(s::TEXT, 4, '0'),
    'supplier' || s || '@example.com',
    'Demo supplier data.'
FROM generate_series(1, 100) s
ON CONFLICT ("supplier_id") DO NOTHING;


-- lims.inventory_items (item_id is direct PK, uses category_id, unit_id)
INSERT INTO "lims"."inventory_items" ("item_id", "item_name", "category_id", "notes", "unit_id")
SELECT
    'ITEM' || SUBSTRING(REPLACE(uuid_generate_v4()::TEXT, '-', ''), 1, 6) || LPAD(s::TEXT, 3, '0'),
    'Inventory Item ' || s,
    (SELECT category_id FROM "reference"."category" ORDER BY RANDOM() LIMIT 1),
    'Demo inventory item.',
    (SELECT unit_id FROM "reference"."units" ORDER BY RANDOM() LIMIT 1)
FROM generate_series(1, 100) s
ON CONFLICT ("item_id") DO NOTHING;


-- lims.projects (uses customer_id from lims.customers and pi_person_id from reference.personal)
-- Re-inserting to ensure 100 unique demo projects, or extending
INSERT INTO "lims"."projects" ("project_id", "title", "status_id", "pi_person_id", "funder", "customer_id", "start_date", "end_date", "report_date", "notes")
SELECT
    'PROJ' || SUBSTRING(REPLACE(uuid_generate_v4()::TEXT, '-', ''), 1, 6) || LPAD(s::TEXT, 3, '0'),
    'Research Project ' || s,
    (SELECT status_id FROM "reference"."status" ORDER BY RANDOM() LIMIT 1),
    (SELECT person_id FROM "reference"."personal" ORDER BY RANDOM() LIMIT 1),
    'Funder Inc. ' || (s % 10 + 1),
    (SELECT customer_id FROM "lims"."customers" ORDER BY RANDOM() LIMIT 1),
    (CURRENT_DATE - (s || ' days')::INTERVAL)::DATE,
    (CURRENT_DATE + (s * 365 || ' days')::INTERVAL)::DATE,
    (CURRENT_DATE + (s * 365 + 30 || ' days')::INTERVAL)::DATE,
    'Demo project ' || s || ' for LIMS testing.'
FROM generate_series(1, 100) s
ON CONFLICT ("project_id") DO NOTHING;


-- lims.orders (fi_order_nr is direct PK, uses item_id, category_id, project_id, supplier_id, status_id)
INSERT INTO "lims"."orders" ("fi_order_nr", "item_id", "category_id", "order_date", "price", "quantity", "project_id", "supplier_id", "status_id", "notes")
SELECT
    'ORD' || SUBSTRING(REPLACE(uuid_generate_v4()::TEXT, '-', ''), 1, 6) || LPAD(s::TEXT, 3, '0'),
    (SELECT item_id FROM "lims"."inventory_items" ORDER BY RANDOM() LIMIT 1),
    (SELECT category_id FROM "reference"."category" ORDER BY RANDOM() LIMIT 1),
    (CURRENT_DATE - (s % 365 || ' days')::INTERVAL)::DATE,
    (s * 10.5)::NUMERIC,
    (s % 50 + 1)::NUMERIC,
    (SELECT project_id FROM "lims"."projects" ORDER BY RANDOM() LIMIT 1),
    (SELECT supplier_id FROM "lims"."suppliers" ORDER BY RANDOM() LIMIT 1),
    (SELECT status_id FROM "reference"."status" ORDER BY RANDOM() LIMIT 1),
    'Demo order for item ' || s
FROM generate_series(1, 100) s
ON CONFLICT ("fi_order_nr") DO NOTHING;


-- lims.reagents (reagent_id is direct PK, uses category_id, storage_id, status_id, order_id, project_id, quantity_unit_id)
INSERT INTO "lims"."reagents" ("reagent_id", "reagent_complete_name", "category_id", "lot", "storage_id", "storage_position", "status_id", "reception_date", "expire_date", "order_id", "project_id", "quantity_available", "quantity_unit_id", "notes")
SELECT
    'REAGENT' || SUBSTRING(REPLACE(uuid_generate_v4()::TEXT, '-', ''), 1, 6) || LPAD(s::TEXT, 3, '0'),
    'Reagent ' || s || ' - Batch ' || LPAD(s::TEXT, 2, '0'),
    (SELECT category_id FROM "reference"."category" ORDER BY RANDOM() LIMIT 1),
    'LOT' || LPAD(s::TEXT, 5, '0'),
    (SELECT storage_id FROM "lab"."storage" ORDER BY RANDOM() LIMIT 1),
    (s % 100)::NUMERIC,
    (SELECT status_id FROM "reference"."status" ORDER BY RANDOM() LIMIT 1),
    (CURRENT_DATE - (s * 2 || ' days')::INTERVAL)::DATE,
    (CURRENT_DATE + (s * 10 || ' days')::INTERVAL)::DATE,
    (SELECT fi_order_nr FROM "lims"."orders" ORDER BY RANDOM() LIMIT 1),
    (SELECT project_id FROM "lims"."projects" ORDER BY RANDOM() LIMIT 1),
    (s % 100 + 1)::NUMERIC,
    (SELECT unit_id FROM "reference"."units" WHERE unit_type IN ('volume', 'mass') ORDER BY RANDOM() LIMIT 1),
    'Demo reagent for testing.'
FROM generate_series(1, 100) s
ON CONFLICT ("reagent_id") DO NOTHING;


-- lims.cruises (cruise_id is direct PK, uses project_id, vessel_id, status_id, region_id, ecosystem_id, external_contacts, personal)
INSERT INTO "lims"."cruises" (
    "cruise_id", "project_id", "vessel_id", "status_id", "region_id", "ecosystem_id",
    "capitaine_contact_id", "chief_scientist_person_id", "start_date", "end_date",
    "together_with_contact_id", "notes"
)
SELECT
    'CRUISE' || SUBSTRING(REPLACE(uuid_generate_v4()::TEXT, '-', ''), 1, 6) || LPAD(s::TEXT, 3, '0'),
    (SELECT project_id FROM "lims"."projects" ORDER BY RANDOM() LIMIT 1),
    (SELECT vessel_id FROM "reference"."vessel" ORDER BY RANDOM() LIMIT 1),
    (SELECT status_id FROM "reference"."status" ORDER BY RANDOM() LIMIT 1), -- Any status
    (SELECT region_id FROM "reference"."region" ORDER BY RANDOM() LIMIT 1),
    (SELECT ecosystem_id FROM "reference"."ecosystem" ORDER BY RANDOM() LIMIT 1),
    (SELECT contact_id FROM "lims"."external_contacts" ORDER BY RANDOM() LIMIT 1),
    (SELECT person_id FROM "reference"."personal" ORDER BY RANDOM() LIMIT 1),
    (CURRENT_DATE - (s * 20 || ' days')::INTERVAL)::DATE,
    (CURRENT_DATE - (s * 20 - 30 || ' days')::INTERVAL)::DATE,
    (SELECT contact_id FROM "lims"."external_contacts" ORDER BY RANDOM() LIMIT 1),
    'Demo cruise details.'
FROM generate_series(1, 100) s
ON CONFLICT ("cruise_id") DO NOTHING;


-- lims.publications (publication_id is generated by trigger, uses publication_type_id, project_id, personal_id)
INSERT INTO "lims"."publications" (
    "publication_type_id", "project_id", "title", "journal", "volume", "issue", "pages", "doi",
    "date_publication", "date_submission", "first_author_person_id", "corresponding_author_person_id", "notes"
)
SELECT
    (SELECT publication_type_id FROM "lims"."publication_type" ORDER BY RANDOM() LIMIT 1),
    (SELECT project_id FROM "lims"."projects" ORDER BY RANDOM() LIMIT 1),
    'Research Paper ' || s || ': A Study on Marine Life',
    'Journal of Marine Science',
    (s % 20 + 1)::TEXT,
    (s % 4 + 1)::TEXT,
    (s * 2 + 10)::TEXT || '-' || (s * 2 + 20)::TEXT,
    '10.1000/demo.' || LPAD(s::TEXT, 5, '0'),
    (CURRENT_DATE - (s * 5 || ' days')::INTERVAL)::DATE,
    (CURRENT_DATE - (s * 5 + 60 || ' days')::INTERVAL)::DATE,
    (SELECT person_id FROM "reference"."personal" ORDER BY RANDOM() LIMIT 1),
    (SELECT person_id FROM "reference"."personal" ORDER BY RANDOM() LIMIT 1),
    'Demo publication entry.'
FROM generate_series(1, 100) s
ON CONFLICT ("publication_id") DO NOTHING;


-- lab.storage (storage_id is direct PK, uses room_id, project_id)
INSERT INTO "lab"."storage" ("storage_id", "room_id", "freezer", "etage", "temperature_c", "box", "box_size_x", "box_size_y", "storage_position_format", "project_id", "notes")
SELECT
    'STOR' || SUBSTRING(REPLACE(uuid_generate_v4()::TEXT, '-', ''), 1, 6) || LPAD(s::TEXT, 3, '0'),
    (SELECT room_id FROM "reference"."room" ORDER BY RANDOM() LIMIT 1),
    'Freezer ' || (s % 5 + 1),
    CASE (s % 2) WHEN 0 THEN 'A' ELSE 'B' END,
    (-80.0)::NUMERIC,
    'Box' || LPAD(s::TEXT, 3, '0'),
    10,
    10,
    'Rack-Row-Column',
    (SELECT project_id FROM "lims"."projects" ORDER BY RANDOM() LIMIT 1),
    'Demo storage location.'
FROM generate_series(1, 100) s
ON CONFLICT ("storage_id") DO NOTHING;


-- lab.experiments (experiment_id generated by trigger, experiment_date is part of PK and partitioning)
INSERT INTO "lab"."experiments" (
    "experiment_id", "experiment_title", "aim", "method", "sop_id", "experiment_date",
    "person_id", "notes", "lab_book", "status_id"
)
SELECT
    'EXP' || LPAD(s::TEXT, 3, '0'),
    'Experiment Title ' || s,
    'Aim of experiment ' || s,
    'Method X.Y.Z',
    (SELECT sop_id FROM "lims"."sop" ORDER BY RANDOM() LIMIT 1),
    (CURRENT_DATE - (s % 730 || ' days')::INTERVAL)::DATE, -- Distribute dates over last 2 years
    (SELECT person_id FROM "reference"."personal" ORDER BY RANDOM() LIMIT 1),
    'Notes for experiment ' || s,
    'LB-2024-' || LPAD(s::TEXT, 3, '0'),
    (SELECT status_id FROM "reference"."status" ORDER BY RANDOM() LIMIT 1)
FROM generate_series(1, 100) s
ON CONFLICT ("experiment_id", "experiment_date") DO NOTHING;


-- lab.experiments_projects (experiment_project_id is serial, uses experiment_id, experiment_date, project_id)
INSERT INTO "lab"."experiments_projects" ("experiment_id", "experiment_date", "project_id", "link_date", "notes")
SELECT
    e.experiment_id,
    e.experiment_date,
    (SELECT project_id FROM "lims"."projects" ORDER BY RANDOM() LIMIT 1),
    (e.experiment_date + (s % 30 || ' days')::INTERVAL)::DATE,
    'Link between experiment ' || e.experiment_id || ' and project.'
FROM generate_series(1, 100) s
JOIN "lab"."experiments" e ON e.experiment_id = 'EXP' || LPAD((s%100 + 1)::TEXT, 3, '0') AND e.experiment_date = (CURRENT_DATE - ((s%100+1) % 730 || ' days')::INTERVAL)::DATE
ON CONFLICT ("experiment_project_id") DO NOTHING; -- Assuming serial handles conflicts implicitly for its own ID


-- lab.protocol_runs (protocol_run_id generated by trigger, uses experiment_id, experiment_date, sop_id, person_id)
INSERT INTO "lab"."protocol_runs" (
    "experiment_id", "experiment_date", "sop_id", "protocol_text", "run_date", "person_id", "protocol_run_details", "notes"
)
SELECT
    e.experiment_id,
    e.experiment_date,
    (SELECT sop_id FROM "lims"."sop" ORDER BY RANDOM() LIMIT 1),
    'Protocol text for run ' || s,
    (CURRENT_DATE - (s % 365 || ' days')::INTERVAL)::DATE,
    (SELECT person_id FROM "reference"."personal" ORDER BY RANDOM() LIMIT 1),
    'Details for protocol run ' || s,
    'Notes for protocol run ' || s
FROM generate_series(1, 100) s
JOIN "lab"."experiments" e ON e.experiment_id = 'EXP' || LPAD((s%100 + 1)::TEXT, 3, '0') AND e.experiment_date = (CURRENT_DATE - ((s%100+1) % 730 || ' days')::INTERVAL)::DATE
ON CONFLICT ("protocol_run_id") DO NOTHING;


-- lab.sampling (sampling_id generated by trigger, sampling_date is PK & partitioning, uses experiment_id, experiment_date, project_id, cruise_id, region_id, ecosystem_id, vessel_id, customer_id, unit_id, external_contacts, status_id)
INSERT INTO "lab"."sampling" (
    "sampling_id", "experiment_id", "experiment_date", "project_id", "cruise_id", "region_id", "ecosystem_id",
    "vessel_id", "customer_id", "sampling_date", "geom", "fishing_start_geom", "fishing_end_geom", "location_name", "depth_m",
    "start_at", "end_at", "temperature_atmospheric_c", "weather", "wind_speed", "wind_unit_id",
    "temperature_sampling_depth_c", "salinity", "salinity_unit_id", "pressure", "pressure_unit_id",
    "oxygen", "oxygen_unit_id", "conductivity", "ph", "nitrate_mg_l",
    "phosphate_mg_l", "turbidity_ntu", "chlorophyll_a_ug_l", "current_speed_m_s", "current_direction_deg",
    "tide_stage", "light_par_umol_m2_s", "sea_state", "sample_volume_l", "sample_type_id", "preservative",
    "cloud_cover_percent", "rainfall_mm", "instrument_id", "calibration_date", "visibility_m",
    "fishing_date", "fishing_time_min", "fishing_method", "gear_type", "soak_time", "soak_time_unit_id",
    "trawl_speed", "trawl_speed_unit_id", "total_catch_quantity_kg", "total_catch_quantity_fish",
    "catch_notes", "operation_duration_min", "together_with_contact_id", "status_id", "notes",
    "attachment", "attachment_link"
)
SELECT
    'SAMP' || LPAD(s::TEXT, 4, '0'), -- 1
    e.experiment_id,                 -- 2
    e.experiment_date,               -- 3
    (SELECT project_id FROM "lims"."projects" ORDER BY RANDOM() LIMIT 1), -- 4
    (SELECT cruise_id FROM "lims"."cruises" ORDER BY RANDOM() LIMIT 1),   -- 5
    (SELECT region_id FROM "reference"."region" ORDER BY RANDOM() LIMIT 1), -- 6
    (SELECT ecosystem_id FROM "reference"."ecosystem" ORDER BY RANDOM() LIMIT 1), -- 7
    (SELECT vessel_id FROM "reference"."vessel" ORDER BY RANDOM() LIMIT 1), -- 8 **ADDED MISSING VALUE FOR VESSEL_ID**
    (SELECT customer_id FROM "lims"."customers" ORDER BY RANDOM() LIMIT 1), -- 9
    (CURRENT_DATE - (s % 730 || ' days')::INTERVAL)::DATE, -- 10
    ST_SetSRID(ST_MakePoint(RANDOM() * 360 - 180, RANDOM() * 180 - 90), 4326), -- 11
    ST_SetSRID(ST_MakePoint(RANDOM() * 360 - 180, RANDOM() * 180 - 90), 4326), -- 12
    ST_SetSRID(ST_MakePoint(RANDOM() * 360 - 180, RANDOM() * 180 - 90), 4326), -- 13
    'Location ' || s,                -- 14
    (s % 500)::NUMERIC,              -- 15
    (NOW() - (s % 24 || ' hours')::INTERVAL)::TIME, -- 16
    (NOW() - (s % 24 - 1 || ' hours')::INTERVAL)::TIME, -- 17
    (RANDOM() * 30)::NUMERIC,        -- 18
    CASE (s % 3) WHEN 0 THEN 'Sunny' WHEN 1 THEN 'Cloudy' ELSE 'Rainy' END, -- 19
    (RANDOM() * 50)::NUMERIC,        -- 20
    'm_s',                           -- 21
    (RANDOM() * 20)::NUMERIC,        -- 22 **FIXED: This is salinity (numeric)**
    (RANDOM() * 40)::NUMERIC + 10,   -- 23 **FIXED: This is salinity_unit_id (text), changed to a value**
    'PSU',                           -- 24 **FIXED: This is salinity_unit_id (text) based on previous turn logic, so now shifted**
    (RANDOM() * 10)::NUMERIC,        -- 25
    'dbar',                          -- 26
    (RANDOM() * 10)::NUMERIC,        -- 27
    'mg_l',                          -- 28
    (RANDOM() * 50)::NUMERIC,        -- 29
    (RANDOM() * 14)::NUMERIC,        -- 31
    (RANDOM() * 10)::NUMERIC,        -- 32
    (RANDOM() * 2)::NUMERIC,         -- 33
    (RANDOM() * 500)::NUMERIC,       -- 34
    (RANDOM() * 10)::NUMERIC,        -- 35
    (RANDOM() * 2)::NUMERIC,         -- 36
    (RANDOM() * 360)::NUMERIC,       -- 37
    CASE (s % 3) WHEN 0 THEN 'High' WHEN 1 THEN 'Low' ELSE 'Mid' END, -- 38
    (RANDOM() * 2000)::NUMERIC,      -- 39
    CASE (s % 3) WHEN 0 THEN 'Calm' WHEN 1 THEN 'Moderate' ELSE 'Rough' END, -- 40
    (RANDOM() * 100)::NUMERIC,       -- 41
    (SELECT sample_type_id FROM "reference"."samples_type" ORDER BY RANDOM() LIMIT 1), -- 42
    'Formalin',                      -- 43
    (RANDOM() * 100)::NUMERIC,       -- 44
    (RANDOM() * 5)::NUMERIC,         -- 45
    (SELECT equipment_id FROM "lims"."equipment" ORDER BY RANDOM() LIMIT 1), -- 46
    (CURRENT_DATE - (s * 3 || ' days')::INTERVAL)::DATE, -- 47
    (RANDOM() * 50)::NUMERIC,        -- 48
    (CURRENT_DATE - (s % 730 || ' days')::INTERVAL)::DATE, -- 49
    (NOW() - (s % 60 || ' minutes')::INTERVAL)::TIME, -- 50
    CASE (s % 2) WHEN 0 THEN 'Trawl' ELSE 'Net' END, -- 51
    'Gear' || LPAD((s%5+1)::TEXT,1,'0'), -- 52
    (RANDOM() * 120)::NUMERIC,       -- 53
    'min',                           -- 54
    (RANDOM() * 5)::NUMERIC,         -- 55
    'km_h',                          -- 56
    (RANDOM() * 1000)::NUMERIC,      -- 57
    (RANDOM() * 500)::NUMERIC,       -- 58
    'Catch notes for ' || s,         -- 59
    (RANDOM() * 180)::NUMERIC,       -- 60
    (SELECT contact_id FROM "lims"."external_contacts" ORDER BY RANDOM() LIMIT 1), -- 61
    (SELECT status_id FROM "reference"."status" ORDER BY RANDOM() LIMIT 1), -- 62
    'Sampling event for demo ' || s, -- 63
    NULL,                            -- 64: attachment -- Changed from bytea literal to NULL
    NULL                             -- 65: attachment_link -- Changed from URL to NULL
FROM generate_series(1, 100) s
JOIN "lab"."experiments" e ON e.experiment_id = 'EXP' || LPAD((s%100 +1)::TEXT, 3, '0') AND e.experiment_date = (CURRENT_DATE - ((s%100+1) % 730 || ' days')::INTERVAL)::DATE
ON CONFLICT ("sampling_id", "sampling_date") DO NOTHING;