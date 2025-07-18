-- ======================================================================
-- MyLims Database Demo Data (2019-2025) - FINAL CORRECTED VERSION
--
-- This script generates demo data for all tables in the MyLims schema.
-- It's intended for populating a freshly created, empty MyLims database.
--
-- To use:
-- 1. Ensure your MyLims database schema (MyLims.sql) has been successfully applied.
-- 2. Connect to your MyLims database.
-- 3. Execute this script.
-- ======================================================================

-- Set LIMS user for audit triggers
SET lims.current_person_id = 'demo_user_admin'; -- Ensure this person_id exists in reference.personal after inserts

-- --- Helper Functions for Data Generation ---
-- These functions are used by the data generation script below.
-- They are NOT part of your MyLims.sql schema.
-- Drop them first if they exist from previous runs.
DROP FUNCTION IF EXISTS generate_random_string(INT);
DROP FUNCTION IF EXISTS generate_random_date_in_range(INT, INT);
DROP FUNCTION IF EXISTS generate_random_phone();
DROP FUNCTION IF EXISTS generate_random_email(TEXT);
DROP FUNCTION IF EXISTS generate_random_coordinate();
DROP FUNCTION IF EXISTS get_demo_password_hash();

CREATE OR REPLACE FUNCTION generate_random_string(length INT)
RETURNS TEXT LANGUAGE plpgsql AS $$
DECLARE
    chars TEXT := 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    result TEXT := '';
    i INT := 0;
BEGIN
    FOR i IN 1..length LOOP
        result := result || SUBSTRING(chars, FLOOR(RANDOM() * LENGTH(chars) + 1)::INT, 1);
    END LOOP;
    RETURN result;
END;
$$;

CREATE OR REPLACE FUNCTION generate_random_date_in_range(start_year INT, end_year INT)
RETURNS DATE LANGUAGE plpgsql AS $$
DECLARE
    start_date DATE := (start_year || '-01-01')::DATE;
    end_date DATE := (end_year || '-12-31')::DATE;
    random_days INT := FLOOR(RANDOM() * (end_date - start_date + 1));
BEGIN
    RETURN start_date + random_days;
END;
$$;

CREATE OR REPLACE FUNCTION generate_random_phone()
RETURNS TEXT LANGUAGE plpgsql AS $$
BEGIN
    RETURN '(0' || FLOOR(RANDOM() * 9 + 1)::INT || ') ' || LPAD(FLOOR(RANDOM() * 100000000)::TEXT, 8, '0');
END;
$$;

CREATE OR REPLACE FUNCTION generate_random_email(domain_name TEXT)
RETURNS TEXT LANGUAGE plpgsql AS $$
BEGIN
    RETURN generate_random_string(5) || '.' || generate_random_string(7) || '@' || domain_name;
END;
$$;

CREATE OR REPLACE FUNCTION generate_random_coordinate()
RETURNS NUMERIC LANGUAGE plpgsql AS $$
BEGIN
    RETURN (RANDOM() * 180 - 90)::NUMERIC(9,6); -- Latitude or Longitude
END;
$$;

-- Pre-hashed password for 'password' (bcrypt hash)
CREATE OR REPLACE FUNCTION get_demo_password_hash()
RETURNS TEXT LANGUAGE plpgsql AS $$
BEGIN
    RETURN '$2b$12$f0g5.nJ3Rk.yYpQ2nJ3N2u.N2o2S.N2z2N2l.N2';
END;
$$;


-- ======================================================================
-- Data for Reference Schema
-- ======================================================================

-- reference.status (pre-filled, if not already)
INSERT INTO "reference"."status" ("status_id", "notes") VALUES
('Received', 'Sample has been received in the lab'),
('Dissection', 'Sample has been dissected'),
('Extracted', 'Sample has been extracted'),
('Nanodrop QC', 'Sample quality checked with Nanodrop'),
('Qubit QC', 'Sample quality checked with Qubit'),
('Tapestation QC', 'Sample quality checked with Tapestation'),
('PCR Done', 'PCR has been performed on the sample'),
('qPCR Done', 'qPCR has been performed on the sample'),
('Library Prep', 'Sequencing library has been prepared'),
('Sequencing Done', 'Sample has been sequenced'),
('Bioinformatics Done', 'Bioinformatics analysis is complete'),
('Completed', 'Workflow completed'),
('Cancelled', 'Project/Sample cancelled'),
('On Hold', 'Project/Sample on hold'),
('Active', 'Project/Sample active'),
('Planned', 'Activity planned'),
('Archived', 'Data archived'),
('Gelelectrophoresis', 'Gel electrophoresis performed') -- Added missing status
ON CONFLICT ("status_id") DO NOTHING;

-- reference.room
INSERT INTO "reference"."room" ("room_id", "etage", "address", "notes")
SELECT
    'Room' || LPAD(s.id::TEXT, 2, '0'),
    CASE WHEN s.id % 2 = 0 THEN 'Ground Floor' ELSE '1st Floor' END,
    'Institute Address ' || (s.id + 10)::TEXT,
    'Notes for Room ' || LPAD(s.id::TEXT, 2, '0')
FROM GENERATE_SERIES(1, 10) AS s(id)
ON CONFLICT ("room_id") DO NOTHING;

-- reference.vessel
INSERT INTO "reference"."vessel" ("vessel_id", "vessel_name", "belong_to", "notes")
SELECT
    'VESSEL' || LPAD(s.id::TEXT, 2, '0'),
    'Research Vessel ' || generate_random_string(5),
    'Institute ' || s.id,
    'Notes for Vessel ' || s.id
FROM GENERATE_SERIES(1, 5) AS s(id)
ON CONFLICT ("vessel_id") DO NOTHING;

-- reference.region
INSERT INTO "reference"."region" ("region_id", "region_abrv", "country", "category", "notes")
SELECT
    'REG' || LPAD(s.id::TEXT, 2, '0'),
    generate_random_string(3),
    CASE s.id % 3 WHEN 0 THEN 'Germany' WHEN 1 THEN 'Norway' ELSE 'UK' END,
    CASE s.id % 2 WHEN 0 THEN 'North Sea' ELSE 'Baltic Sea' END,
    'Notes for Region ' || s.id
FROM GENERATE_SERIES(1, 10) AS s(id)
ON CONFLICT ("region_id") DO NOTHING;

-- reference.ecosystem
INSERT INTO "reference"."ecosystem" ("ecosystem_id", "ecosystem_abrv", "country", "category", "notes")
SELECT
    'ECO' || LPAD(s.id::TEXT, 2, '0'),
    generate_random_string(4),
    CASE s.id % 3 WHEN 0 THEN 'Oceanic' WHEN 1 THEN 'Coastal' ELSE 'Freshwater' END,
    CASE s.id % 2 WHEN 0 THEN 'Marine' ELSE 'Terrestrial' END,
    'Notes for Ecosystem ' || s.id
FROM GENERATE_SERIES(1, 10) AS s(id)
ON CONFLICT ("ecosystem_id") DO NOTHING;

-- reference.category
INSERT INTO "reference"."category" ("category_id", "notes")
SELECT
    'CAT' || LPAD(s.id::TEXT, 2, '0'),
    'Notes for Category ' || s.id
FROM GENERATE_SERIES(1, 10) AS s(id)
ON CONFLICT ("category_id") DO NOTHING;

-- reference.samples_type (pre-filled, if not already)
INSERT INTO "reference"."samples_type" ("sample_type_id", "sample_type_abrv", "notes") VALUES
('DNA', 'D', 'Deoxyribonucleic Acid sample'),
('RNA', 'R', 'Ribonucleic Acid sample'),
('Library', 'L', 'Sequencing Library sample'),
('Water', 'W', 'Water sample'),
('Sediments', 'S', 'Sediment sample'),
('Tissue', 'T', 'Tissue sample'),
('Fish', 'F', 'Fish sample'),
('Sequencing', 'Q', 'Sequencing run output'),
('Dataset', 'Z', 'Processed dataset'),
('Publication', 'PUB', 'Research Publication')
ON CONFLICT ("sample_type_id") DO NOTHING;

-- reference.gene
INSERT INTO "reference"."gene" ("gene_id", "notes")
SELECT
    'GENE' || LPAD(s.id::TEXT, 3, '0'),
    'Notes for Gene ' || s.id
FROM GENERATE_SERIES(1, 10) AS s(id)
ON CONFLICT ("gene_id") DO NOTHING;

-- reference.units (pre-filled, if not already)
INSERT INTO "reference"."units" ("unit_id", "unit_name", "unit_abbreviation", "unit_type", "conversion_factor_to_base") VALUES
('mm', 'millimeter', 'mm', 'length', 0.001),
('g', 'gram', 'g', 'mass', 0.001),
('mg', 'milligram', 'mg', 'mass', 0.000001),
('ul', 'microliter', 'µL', 'volume', 1e-6),
('ng_ul', 'nanogram per microliter', 'ng/µL', 'concentration', 1e-9),
('bp', 'base pair', 'bp', 'length', 1),
('km_h', 'kilometer per hour', 'km/h', 'speed', 0.277778),
('m_s', 'meter per second', 'm/s', 'speed', 1),
('PSU', 'Practical Salinity Unit', 'PSU', 'salinity', 1),
('ppt', 'parts per thousand', 'ppt', 'salinity', 1),
('dbar', 'decibar', 'dbar', 'pressure', 1),
('psi', 'pounds per square inch', 'psi', 'pressure', 0.0689476),
('kPa', 'kilopascal', 'kPa', 'pressure', 1000),
('mg_l', 'milligram per liter', 'mg/L', 'concentration', 1),
('umol_l', 'micromole per liter', 'µmol/L', 'concentration', 1),
('ntu', 'Nephelometric Turbidity Unit', 'NTU', 'turbidity', 1),
('ug_l', 'microgram per liter', 'µg/L', 'concentration', 1),
('deg', 'degree', 'deg', 'angle', 1),
('min', 'minute', 'min', 'time', 60),
('h', 'hour', 'h', 'time', 3600),
('c', 'Celsius', '°C', 'temperature', 1),
('l', 'liter', 'L', 'volume', 1),
('um', 'micrometer', 'µm', 'length', 1e-6),
('m', 'meter', 'm', 'length', 1)
ON CONFLICT ("unit_id") DO NOTHING;

-- reference.personal (for PI, authors, etc.)
INSERT INTO "reference"."personal" ("person_id", "full_name", "room", "telephone", "mail", "password_hash", "notes")
SELECT
    'P' || LPAD(s.id::TEXT, 4, '0'),
    generate_random_string(8) || ' ' || generate_random_string(10),
    (SELECT room_id FROM "reference"."room" ORDER BY RANDOM() LIMIT 1),
    generate_random_phone(),
    generate_random_email('institute.org'),
    get_demo_password_hash(), -- Password 'password'
    'Notes for person ' || s.id
FROM GENERATE_SERIES(1, 20) AS s(id)
ON CONFLICT ("person_id") DO NOTHING;

-- Add a specific user for the demo_user_admin setting
INSERT INTO "reference"."personal" ("person_id", "full_name", "password_hash") VALUES
('demo_user_admin', 'Demo Admin User', get_demo_password_hash())
ON CONFLICT ("person_id") DO NOTHING;


-- reference.taxon (simple hierarchy for demo)
-- Kingdom -> Phylum -> Class -> Order -> Family -> Genus -> Species
INSERT INTO "reference"."taxon" ("taxon_id", "taxon_parent", "de_name", "en_name", "rank")
SELECT 'KINGDOM' || LPAD(s.id::TEXT, 2, '0'), NULL, 'Königreich ' || s.id, 'Kingdom ' || s.id, 'kingdom'
FROM GENERATE_SERIES(1, 2) AS s(id)
ON CONFLICT ("taxon_id") DO NOTHING;

INSERT INTO "reference"."taxon" ("taxon_id", "taxon_parent", "de_name", "en_name", "rank")
SELECT 'PHY' || LPAD(s.id::TEXT, 3, '0'), (SELECT taxon_id FROM "reference"."taxon" WHERE rank = 'kingdom' ORDER BY RANDOM() LIMIT 1),
       'Stamm ' || s.id, 'Phylum ' || s.id, 'phylum'
FROM GENERATE_SERIES(1, 5) AS s(id)
ON CONFLICT ("taxon_id") DO NOTHING;

INSERT INTO "reference"."taxon" ("taxon_id", "taxon_parent", "de_name", "en_name", "rank")
SELECT 'CLASS' || LPAD(s.id::TEXT, 3, '0'), (SELECT taxon_id FROM "reference"."taxon" WHERE rank = 'phylum' ORDER BY RANDOM() LIMIT 1),
       'Klasse ' || s.id, 'Class ' || s.id, 'class'
FROM GENERATE_SERIES(1, 10) AS s(id)
ON CONFLICT ("taxon_id") DO NOTHING;

INSERT INTO "reference"."taxon" ("taxon_id", "taxon_parent", "de_name", "en_name", "rank")
SELECT 'ORDER' || LPAD(s.id::TEXT, 3, '0'), (SELECT taxon_id FROM "reference"."taxon" WHERE rank = 'class' ORDER BY RANDOM() LIMIT 1),
       'Ordnung ' || s.id, 'Order ' || s.id, 'order'
FROM GENERATE_SERIES(1, 15) AS s(id)
ON CONFLICT ("taxon_id") DO NOTHING;

INSERT INTO "reference"."taxon" ("taxon_id", "taxon_parent", "de_name", "en_name", "rank")
SELECT 'FAM' || LPAD(s.id::TEXT, 3, '0'), (SELECT taxon_id FROM "reference"."taxon" WHERE rank = 'order' ORDER BY RANDOM() LIMIT 1),
       'Familie ' || s.id, 'Family ' || s.id, 'family'
FROM GENERATE_SERIES(1, 20) AS s(id)
ON CONFLICT ("taxon_id") DO NOTHING;

INSERT INTO "reference"."taxon" ("taxon_id", "taxon_parent", "de_name", "en_name", "rank")
SELECT 'GENUS' || LPAD(s.id::TEXT, 3, '0'), (SELECT taxon_id FROM "reference"."taxon" WHERE rank = 'family' ORDER BY RANDOM() LIMIT 1),
       'Gattung ' || s.id, 'Genus ' || s.id, 'genus'
FROM GENERATE_SERIES(1, 30) AS s(id)
ON CONFLICT ("taxon_id") DO NOTHING;

INSERT INTO "reference"."taxon" ("taxon_id", "taxon_parent", "de_name", "en_name", "rank")
SELECT 'SP' || LPAD(s.id::TEXT, 4, '0'), (SELECT taxon_id FROM "reference"."taxon" WHERE rank = 'genus' ORDER BY RANDOM() LIMIT 1),
       'Art ' || s.id, 'Species ' || s.id, 'species'
FROM GENERATE_SERIES(1, 50) AS s(id)
ON CONFLICT ("taxon_id") DO NOTHING;

-- Call function to populate ltree paths after all taxons are inserted
SELECT "reference".update_taxon_ltree_paths();

-- reference.species
INSERT INTO "reference"."species" ("species_id", "de_name", "en_name", "max_length_mm", "max_age_years", "notes")
SELECT
    t.taxon_id,
    t.de_name,
    t.en_name,
    FLOOR(RANDOM() * 1000 + 50)::NUMERIC(10,2),
    FLOOR(RANDOM() * 50 + 1)::NUMERIC(10,2),
    'Species notes for ' || t.en_name
FROM "reference"."taxon" t
WHERE t.rank = 'species'
ON CONFLICT ("species_id") DO NOTHING;


-- ======================================================================
-- Data for Lims Schema
-- ======================================================================

-- lims.external_contacts
INSERT INTO "lims"."external_contacts" ("contact_id", "full_name", "organization", "telephone", "mail", "password_hash", "notes")
SELECT
    'EXTC' || LPAD(s.id::TEXT, 3, '0'),
    generate_random_string(7) || ' External',
    'Org ' || s.id,
    generate_random_phone(),
    generate_random_email('external.com'),
    get_demo_password_hash(),
    'Notes for external contact ' || s.id
FROM GENERATE_SERIES(1, 10) AS s(id)
ON CONFLICT ("contact_id") DO NOTHING;

-- lims.customers
INSERT INTO "lims"."customers" ("customer_id", "customer_name", "customer_abrv", "address", "mail", "phone", "password_hash", "notes")
SELECT
    'CUST' || LPAD(s.id::TEXT, 3, '0'), -- Manual customer_id as per schema
    'Customer ' || generate_random_string(8),
    generate_random_string(4),
    generate_random_string(15) || ' St.',
    generate_random_email('customer.com'),
    generate_random_phone(),
    get_demo_password_hash(),
    'Notes for customer ' || s.id
FROM GENERATE_SERIES(1, 15) AS s(id)
ON CONFLICT ("customer_id") DO NOTHING;

-- lims.projects
INSERT INTO "lims"."projects" ("project_id", "title", "status_id", "pi_person_id", "funder", "customer_id", "start_date", "end_date", "report_date", "notes")
SELECT
    'PROJ' || LPAD(s.id::TEXT, 4, '0'),
    'Research Project ' || generate_random_string(10),
    (SELECT status_id FROM "reference"."status" WHERE status_id IN ('Active', 'On Hold', 'Completed') ORDER BY RANDOM() LIMIT 1),
    (SELECT person_id FROM "reference"."personal" ORDER BY RANDOM() LIMIT 1),
    'Funder ' || generate_random_string(5),
    (SELECT customer_id FROM "lims"."customers" ORDER BY RANDOM() LIMIT 1),
    generate_random_date_in_range(2019, 2023),
    generate_random_date_in_range(2023, 2025),
    generate_random_date_in_range(2024, 2025),
    'Notes for project ' || s.id
FROM GENERATE_SERIES(1, 50) AS s(id)
ON CONFLICT ("project_id") DO NOTHING;

-- lims.project_persons
INSERT INTO "lims"."project_persons" ("project_id", "person_id", "role", "notes")
SELECT
    p.project_id,
    pers.person_id,
    CASE FLOOR(RANDOM() * 3) WHEN 0 THEN 'Lead' WHEN 1 THEN 'Contributor' ELSE 'Assistant' END,
    'Role in project'
FROM "lims"."projects" p, "reference"."personal" pers
WHERE RANDOM() < 0.3 -- Randomly assign some persons to projects
LIMIT 50
ON CONFLICT ("project_id", "person_id") DO NOTHING;

-- lims.cruises
INSERT INTO "lims"."cruises" ("cruise_id", "project_id", "vessel_id", "status_id", "region_id", "ecosystem_id", "capitaine_contact_id", "chief_scientist_person_id", "start_date", "end_date", "together_with_contact_id", "notes")
SELECT
    'CRUISE' || LPAD(s.id::TEXT, 3, '0'),
    (SELECT project_id FROM "lims"."projects" ORDER BY RANDOM() LIMIT 1),
    (SELECT vessel_id FROM "reference"."vessel" ORDER BY RANDOM() LIMIT 1),
    (SELECT status_id FROM "reference"."status" WHERE status_id IN ('Planned', 'Active', 'Completed') ORDER BY RANDOM() LIMIT 1),
    (SELECT region_id FROM "reference"."region" ORDER BY RANDOM() LIMIT 1),
    (SELECT ecosystem_id FROM "reference"."ecosystem" ORDER BY RANDOM() LIMIT 1),
    (SELECT contact_id FROM "lims"."external_contacts" ORDER BY RANDOM() LIMIT 1),
    (SELECT person_id FROM "reference"."personal" ORDER BY RANDOM() LIMIT 1),
    generate_random_date_in_range(2019, 2024),
    generate_random_date_in_range(2024, 2025),
    (SELECT contact_id FROM "lims"."external_contacts" ORDER BY RANDOM() LIMIT 1),
    'Notes for cruise ' || s.id
FROM GENERATE_SERIES(1, 10) AS s(id)
ON CONFLICT ("cruise_id") DO NOTHING;

-- lims.workflows
INSERT INTO "lims"."workflows" ("workflow_id", "workflow_name", "notes")
SELECT
    'WF' || LPAD(s.id::TEXT, 2, '0'),
    'Workflow ' || generate_random_string(8),
    'Notes for workflow ' || s.id
FROM GENERATE_SERIES(1, 5) AS s(id)
ON CONFLICT ("workflow_id") DO NOTHING;

-- lims.permits
INSERT INTO "lims"."permits" ("permit_id", "permit_number", "issuing_authority", "valid_from", "valid_to", "reference", "notes")
SELECT
    'PERMIT' || LPAD(s.id::TEXT, 3, '0'),
    generate_random_string(10) || '-' || s.id,
    'Authority ' || s.id,
    generate_random_date_in_range(2019, 2021),
    generate_random_date_in_range(2023, 2025),
    'Ref ' || s.id,
    'Notes for permit ' || s.id
FROM GENERATE_SERIES(1, 10) AS s(id)
ON CONFLICT ("permit_id") DO NOTHING;

-- lims.primers
INSERT INTO "lims"."primers" ("primer_id", "target_gene_id", "primer_sequence_fwd", "primer_sequence_rev", "probe", "reference", "notes")
SELECT
    'PRIMER' || LPAD(s.id::TEXT, 3, '0'),
    (SELECT gene_id FROM "reference"."gene" ORDER BY RANDOM() LIMIT 1),
    generate_random_string(20) || 'FWD',
    generate_random_string(20) || 'REV',
    generate_random_string(10) || 'PROBE',
    'Ref ' || s.id,
    'Notes for primer ' || s.id
FROM GENERATE_SERIES(1, 20) AS s(id)
ON CONFLICT ("primer_id") DO NOTHING;

-- lims.sop
INSERT INTO "lims"."sop" ("sop_id", "title", "sop_id_origin", "version", "author_person_id", "reviewer1_person_id", "reviewer2_person_id", "date_realise", "sop_protocol", "notes")
SELECT
    'SOP' || LPAD(s.id::TEXT, 3, '0') || '_v' || REPLACE((FLOOR(RANDOM()*3)+1)::TEXT || '.' || FLOOR(RANDOM()*10)::TEXT, '.', ''),
    'Standard Protocol ' || generate_random_string(10),
    'SOP_ORIG' || LPAD(s.id::TEXT, 3, '0'),
    (FLOOR(RANDOM()*3)+1)::TEXT || '.' || FLOOR(RANDOM()*10)::TEXT,
    (SELECT person_id FROM "reference"."personal" ORDER BY RANDOM() LIMIT 1),
    (SELECT person_id FROM "reference"."personal" ORDER BY RANDOM() LIMIT 1),
    (SELECT person_id FROM "reference"."personal" ORDER BY RANDOM() LIMIT 1),
    generate_random_date_in_range(2019, 2024),
    '<p><strong>Introduction:</strong> This is a demo protocol. ' || generate_random_string(100) || '</p><h2>Steps:</h2><div class="ql-custom-checkbox-item"><span class="ql-custom-checkbox"></span><span class="ql-custom-checkbox-text">Step 1: ' || generate_random_string(30) || '</span></div><div class="ql-custom-checkbox-item"><span class="ql-custom-checkbox"></span><span class="ql-custom-checkbox-text">Step 2: ' || generate_random_string(40) || '</span></div><p><strong>Conclusion:</strong> ' || generate_random_string(50) || '</p>',
    'Notes for SOP ' || s.id
FROM GENERATE_SERIES(1, 20) AS s(id)
ON CONFLICT ("sop_id") DO NOTHING;

-- lims.workflow_steps
INSERT INTO "lims"."workflow_steps" ("step_id", "workflow_id", "step_number", "step_name", "sop_id", "workflow_status_id", "target_table_name", "notes")
SELECT
    wf.workflow_id || '_STEP' || LPAD(s.step_num::TEXT, 2, '0'),
    wf.workflow_id,
    s.step_num,
    s.step_name,
    (SELECT sop_id FROM "lims"."sop" ORDER BY RANDOM() LIMIT 1),
    s.status_id,
    s.target_table,
    'Notes for workflow step ' || s.step_num
FROM "lims"."workflows" wf,
(
    VALUES
    (1, 'Received', 'Received', NULL),
    (2, 'Dissection', 'Dissection', 'Lab.dissections'),
    (3, 'Extracted', 'Extracted', 'Lab.extraction'),
    (4, 'Nanodrop QC', 'Nanodrop QC', 'Lab.nanodrop'),
    (5, 'Qubit QC', 'Qubit QC', 'Lab.qubit'),
    (6, 'Tapestation QC', 'Tapestation QC', 'Lab.tapestation'),
    (7, 'PCR Done', 'PCR Done', 'Lab.pcr'),
    (8, 'qPCR Done', 'qPCR Done', 'Lab.qpcr'),
    (9, 'Library Prep', 'Library Prep', 'Lab.library'),
    (10, 'Sequencing Done', 'Sequencing Done', 'Lab.sequencing'),
    (11, 'Bioinformatics Done', 'Bioinformatics Done', 'Bioinformatics.analysis_runs'),
    (12, 'Completed', 'Completed', NULL),
    (13, 'Gelelectrophoresis', 'Gelelectrophoresis', 'Lab.gelelectrophoresis') -- Added missing step
) AS s(step_num, step_name, status_id, target_table)
ON CONFLICT ("step_id") DO NOTHING;

-- lims.equipment
INSERT INTO "lims"."equipment" ("equipment_id", "equipment_name", "room_id", "lot", "mobility", "date_maintenance", "notes")
SELECT
    'EQ' || LPAD(s.id::TEXT, 3, '0'),
    'Equipment ' || generate_random_string(8),
    (SELECT room_id FROM "reference"."room" ORDER BY RANDOM() LIMIT 1),
    'LOT' || LPAD(s.id::TEXT, 4, '0'),
    CASE WHEN s.id % 2 = 0 THEN 'Fixed' ELSE 'Mobile' END,
    generate_random_date_in_range(2023, 2025),
    'Notes for equipment ' || s.id
FROM GENERATE_SERIES(1, 15) AS s(id)
ON CONFLICT ("equipment_id") DO NOTHING;

-- lims.suppliers
INSERT INTO "lims"."suppliers" ("supplier_id", "supplier_name", "address", "contact_person", "phone", "mail", "notes")
SELECT
    'SUPP' || LPAD(s.id::TEXT, 3, '0'),
    'Supplier ' || generate_random_string(10),
    generate_random_string(20) || ' Ave.',
    generate_random_string(10),
    generate_random_phone(),
    generate_random_email('supplier.com'),
    'Notes for supplier ' || s.id
FROM GENERATE_SERIES(1, 10) AS s(id)
ON CONFLICT ("supplier_id") DO NOTHING;

-- lims.inventory_items
INSERT INTO "lims"."inventory_items" ("item_id", "item_name", "category_id", "notes", "unit_id")
SELECT
    'ITEM' || LPAD(s.id::TEXT, 4, '0'),
    'Lab Item ' || generate_random_string(10),
    (SELECT category_id FROM "reference"."category" ORDER BY RANDOM() LIMIT 1),
    'Notes for item ' || s.id,
    (SELECT unit_id FROM "reference"."units" WHERE unit_type IN ('volume', 'mass') ORDER BY RANDOM() LIMIT 1)
FROM GENERATE_SERIES(1, 20) AS s(id)
ON CONFLICT ("item_id") DO NOTHING;

-- lims.orders
INSERT INTO "lims"."orders" ("fi_order_nr", "item_id", "category_id", "order_date", "price", "quantity", "project_id", "supplier_id", "status_id", "notes")
SELECT
    'ORD' || LPAD(s.id::TEXT, 5, '0'),
    (SELECT item_id FROM "lims"."inventory_items" ORDER BY RANDOM() LIMIT 1),
    (SELECT category_id FROM "reference"."category" ORDER BY RANDOM() LIMIT 1),
    generate_random_date_in_range(2019, 2024),
    FLOOR(RANDOM() * 1000 + 10)::NUMERIC(10,2),
    FLOOR(RANDOM() * 100 + 1)::NUMERIC(10,2),
    (SELECT project_id FROM "lims"."projects" ORDER BY RANDOM() LIMIT 1),
    (SELECT supplier_id FROM "lims"."suppliers" ORDER BY RANDOM() LIMIT 1),
    (SELECT status_id FROM "reference"."status" WHERE status_id IN ('Active', 'Completed', 'Cancelled') ORDER BY RANDOM() LIMIT 1),
    'Notes for order ' || s.id
FROM GENERATE_SERIES(1, 30) AS s(id)
ON CONFLICT ("fi_order_nr") DO NOTHING;

-- lab.storage (Created here because reagents need it)
INSERT INTO "lab"."storage" ("storage_id", "room_id", "freezer", "etage", "temperature_c", "box", "box_size_x", "box_size_y", "storage_position_format", "project_id", "notes")
SELECT
    'STOR' || LPAD(s.id::TEXT, 3, '0'),
    (SELECT room_id FROM "reference"."room" ORDER BY RANDOM() LIMIT 1),
    'FZR' || LPAD(FLOOR(RANDOM() * 5 + 1)::TEXT, 2, '0'),
    FLOOR(RANDOM() * 3 + 1)::TEXT,
    (RANDOM() * 50 - 80)::NUMERIC(5,2), -- -80 to -30 range
    'BOX' || LPAD(s.id::TEXT, 3, '0'),
    10, 10, 'A1',
    (SELECT project_id FROM "lims"."projects" ORDER BY RANDOM() LIMIT 1),
    'Notes for storage ' || s.id
FROM GENERATE_SERIES(1, 10) AS s(id)
ON CONFLICT ("storage_id") DO NOTHING;

-- lims.reagents
INSERT INTO "lims"."reagents" ("reagent_id", "reagent_complete_name", "category_id", "lot", "storage_id", "storage_position", "status_id", "reception_date", "expire_date", "order_id", "project_id", "quantity_available", "quantity_unit_id", "notes")
SELECT
    'REAG' || LPAD(s.id::TEXT, 4, '0'),
    'Reagent ' || generate_random_string(10),
    (SELECT category_id FROM "reference"."category" ORDER BY RANDOM() LIMIT 1),
    'LOT' || generate_random_string(5),
    (SELECT storage_id FROM "lab"."storage" ORDER BY RANDOM() LIMIT 1),
    FLOOR(RANDOM() * 100 + 1),
    (SELECT status_id FROM "reference"."status" WHERE status_id IN ('Active', 'Expired', 'On Hold') ORDER BY RANDOM() LIMIT 1),
    generate_random_date_in_range(2020, 2024),
    generate_random_date_in_range(2024, 2026),
    (SELECT fi_order_nr FROM "lims"."orders" ORDER BY RANDOM() LIMIT 1),
    (SELECT project_id FROM "lims"."projects" ORDER BY RANDOM() LIMIT 1),
    FLOOR(RANDOM() * 1000)::NUMERIC(10,2),
    (SELECT unit_id FROM "reference"."units" WHERE unit_type IN ('volume', 'mass', 'concentration') ORDER BY RANDOM() LIMIT 1),
    'Notes for reagent ' || s.id
FROM GENERATE_SERIES(1, 50) AS s(id)
ON CONFLICT ("reagent_id") DO NOTHING;

-- lims.publication_type
INSERT INTO "lims"."publication_type" ("publication_type_id", "notes") VALUES
('JournalArticle', 'Published in a scientific journal'),
('ConferencePaper', 'Presented at a conference'),
('Thesis', 'Academic thesis or dissertation'),
('Report', 'Internal or external report')
ON CONFLICT ("publication_type_id") DO NOTHING;

-- lims.publications
INSERT INTO "lims"."publications" ("publication_id", "publication_type_id", "project_id", "title", "journal", "volume", "issue", "pages", "doi", "date_publication", "date_submission", "first_author_person_id", "corresponding_author_person_id", "notes")
SELECT
    'PUB' || LPAD(s.id::TEXT, 4, '0'), -- This will be overwritten by trigger
    (SELECT publication_type_id FROM "lims"."publication_type" ORDER BY RANDOM() LIMIT 1),
    (SELECT project_id FROM "lims"."projects" ORDER BY RANDOM() LIMIT 1),
    'Title of Publication ' || generate_random_string(15),
    'Journal of ' || generate_random_string(8),
    FLOOR(RANDOM() * 20 + 1)::TEXT,
    FLOOR(RANDOM() * 10 + 1)::TEXT,
    (FLOOR(RANDOM() * 100 + 1))::TEXT || '-' || (FLOOR(RANDOM() * 200 + 101))::TEXT,
    '10.' || LPAD(s.id::TEXT, 4, '0') || '/' || generate_random_string(5),
    generate_random_date_in_range(2019, 2024),
    generate_random_date_in_range(2018, 2023),
    (SELECT person_id FROM "reference"."personal" ORDER BY RANDOM() LIMIT 1),
    (SELECT person_id FROM "reference"."personal" ORDER BY RANDOM() LIMIT 1),
    'Notes for publication ' || s.id
FROM GENERATE_SERIES(1, 20) AS s(id)
ON CONFLICT ("publication_id") DO NOTHING;


-- ======================================================================
-- Data for Lab Schema
-- ======================================================================

-- lab.experiments
INSERT INTO "lab"."experiments" ("experiment_id", "experiment_title", "aim", "method", "sop_id", "experiment_date", "person_id", "notes", "lab_book", "status_id")
SELECT
    'EXP' || LPAD(s.id::TEXT, 4, '0'),
    'Experiment ' || generate_random_string(12),
    'Aim of experiment ' || s.id,
    'Method for experiment ' || s.id,
    (SELECT sop_id FROM "lims"."sop" ORDER BY RANDOM() LIMIT 1),
    generate_random_date_in_range(2019, 2025),
    (SELECT person_id FROM "reference"."personal" ORDER BY RANDOM() LIMIT 1),
    'Notes for experiment ' || s.id,
    'LB-EXP-' || s.id,
    (SELECT status_id FROM "reference"."status" WHERE status_id IN ('Active', 'Completed', 'On Hold') ORDER BY RANDOM() LIMIT 1)
FROM GENERATE_SERIES(1, 50) AS s(id)
ON CONFLICT ("experiment_id") DO NOTHING;

-- lab.experiments_projects
INSERT INTO "lab"."experiments_projects" ("experiment_id", "project_id", "link_date", "notes")
SELECT
    e.experiment_id,
    p.project_id,
    generate_random_date_in_range(2019, 2025),
    'Link notes'
FROM "lab"."experiments" e, "lims"."projects" p
WHERE RANDOM() < 0.2 -- Randomly link some experiments to projects
LIMIT 50
ON CONFLICT ("experiment_project_id") DO NOTHING;

-- lab.protocol_runs
INSERT INTO "lab"."protocol_runs" ("experiment_id", "sop_id", "protocol_text", "run_date", "person_id", "protocol_run_details", "notes")
SELECT
    (SELECT experiment_id FROM "lab"."experiments" ORDER BY RANDOM() LIMIT 1),
    (SELECT sop_id FROM "lims"."sop" ORDER BY RANDOM() LIMIT 1),
    '{"ops":[{"insert":"This is a simulated protocol run."}]}', -- Simple Delta JSON
    generate_random_date_in_range(2019, 2025),
    (SELECT person_id FROM "reference"."personal" ORDER BY RANDOM() LIMIT 1),
    '{"overallStatus":"Completed", "runStarted":"' || NOW()::TEXT || '"}', -- Simple JSONB for run details
    'Run notes for protocol ' || s.id
FROM GENERATE_SERIES(1, 50) AS s(id); -- protocol_run_id generated by trigger

-- lab.sampling (Parent for partitioned table)
INSERT INTO "lab"."sampling" ("sampling_id", "experiment_id", "project_id", "cruise_id", "region_id", "ecosystem_id", "vessel_id", "customer_id", "sampling_date", "geom", "fishing_start_geom", "fishing_end_geom", "location_name", "depth_m", "start_at", "end_at", "temperature_atmospheric_c", "weather", "wind_speed", "wind_unit_id", "salinity", "salinity_unit_id", "oxygen", "oxygen_unit_id", "conductivity", "conductivity_unit_id", "ph", "nitrate_mg_l", "phosphate_mg_l", "turbidity_ntu", "chlorophyll_a_ug_l", "current_speed_m_s", "current_direction_deg", "tide_stage", "light_par_umol_m2_s", "sea_state", "sample_volume_l", "sample_type_id", "preservative", "cloud_cover_percent", "rainfall_mm", "instrument_id", "calibration_date", "visibility_m", "fishing_date", "fishing_time_min", "fishing_method", "gear_type", "soak_time", "soak_time_unit_id", "trawl_speed", "trawl_speed_unit_id", "total_catch_quantity_kg", "total_catch_quantity_fish", "catch_notes", "operation_duration_min", "together_with_contact_id", "status_id", "notes")
SELECT
    'SAMP' || LPAD(s.id::TEXT, 4, '0'), -- This will be overwritten by trigger
    (SELECT experiment_id FROM "lab"."experiments" ORDER BY RANDOM() LIMIT 1),
    (SELECT project_id FROM "lims"."projects" ORDER BY RANDOM() LIMIT 1),
    (SELECT cruise_id FROM "lims"."cruises" ORDER BY RANDOM() LIMIT 1),
    (SELECT region_id FROM "reference"."region" ORDER BY RANDOM() LIMIT 1),
    (SELECT ecosystem_id FROM "reference"."ecosystem" ORDER BY RANDOM() LIMIT 1),
    (SELECT vessel_id FROM "reference"."vessel" ORDER BY RANDOM() LIMIT 1),
    (SELECT customer_id FROM "lims"."customers" ORDER BY RANDOM() LIMIT 1),
    generate_random_date_in_range(2019, 2025), -- Partition key
    ST_SetSRID(ST_MakePoint(generate_random_coordinate(), generate_random_coordinate()), 4326),
    ST_SetSRID(ST_MakePoint(generate_random_coordinate(), generate_random_coordinate()), 4326),
    ST_SetSRID(ST_MakePoint(generate_random_coordinate(), generate_random_coordinate()), 4326),
    'Loc ' || s.id, FLOOR(RANDOM() * 100),
    (TIMESTAMP '08:00:00' + (RANDOM() * INTERVAL '8 hours'))::TIME,
    (TIMESTAMP '16:00:00' + (RANDOM() * INTERVAL '8 hours'))::TIME,
    (RANDOM() * 30 + 5)::NUMERIC(5,2), 'Sunny', (RANDOM() * 20)::NUMERIC(5,2),
    (SELECT unit_id FROM "reference"."units" WHERE unit_type = 'speed' ORDER BY RANDOM() LIMIT 1),
    (RANDOM() * 35)::NUMERIC(5,2),
    (SELECT unit_id FROM "reference"."units" WHERE unit_type = 'salinity' ORDER BY RANDOM() LIMIT 1),
    (RANDOM() * 10)::NUMERIC(5,2),
    (SELECT unit_id FROM "reference"."units" WHERE unit_type = 'concentration' ORDER BY RANDOM() LIMIT 1),
    (RANDOM() * 60)::NUMERIC(5,2),
    (SELECT unit_id FROM "reference"."units" WHERE unit_type = 'conductivity' ORDER BY RANDOM() LIMIT 1),
    (RANDOM() * 2 + 7)::NUMERIC(5,2), (RANDOM() * 5)::NUMERIC(5,2),
    (RANDOM() * 0.5)::NUMERIC(5,2), (RANDOM() * 50)::NUMERIC(5,2),
    (RANDOM() * 10)::NUMERIC(5,2), (RANDOM() * 2)::NUMERIC(5,2),
    (RANDOM() * 360)::NUMERIC(5,2), 'High Tide', (RANDOM() * 2000)::NUMERIC(5,2),
    'Calm', FLOOR(RANDOM() * 100)::NUMERIC(5,2),
    (SELECT sample_type_id FROM "reference"."samples_type" ORDER BY RANDOM() LIMIT 1),
    'Ethanol', FLOOR(RANDOM() * 100)::NUMERIC(5,2),
    (RANDOM() * 10)::NUMERIC(5,2), 'INSTR' || s.id,
    generate_random_date_in_range(2019, 2023), FLOOR(RANDOM() * 50)::NUMERIC(5,2),
    generate_random_date_in_range(2019, 2025), (TIMESTAMP '01:00:00' + (RANDOM() * INTERVAL '4 hours'))::TIME,
    'Trawl', 'Net', FLOOR(RANDOM() * 60)::NUMERIC(5,2),
    (SELECT unit_id FROM "reference"."units" WHERE unit_type = 'time' ORDER BY RANDOM() LIMIT 1),
    (RANDOM() * 5)::NUMERIC(5,2),
    (SELECT unit_id FROM "reference"."units" WHERE unit_type = 'speed' ORDER BY RANDOM() LIMIT 1),
    FLOOR(RANDOM() * 50)::NUMERIC(5,2), FLOOR(RANDOM() * 100)::NUMERIC(5,2),
    'Catch notes ' || s.id, FLOOR(RANDOM() * 240)::NUMERIC(5,2),
    (SELECT contact_id FROM "lims"."external_contacts" ORDER BY RANDOM() LIMIT 1),
    (SELECT status_id FROM "reference"."status" WHERE status_id IN ('Planned', 'Active', 'Completed') ORDER BY RANDOM() LIMIT 1),
    'General notes for sampling ' || s.id
FROM GENERATE_SERIES(1, 50) AS s(id);

-- lab.master_samples (This table is filled by lab.generate_sample_id trigger)
-- No direct inserts here, it's managed by triggers.

-- lab.samples (Parent for partitioned table)
INSERT INTO "lab"."samples" ("external_name", "parent_sample_id", "sampling_id", "sampling_date", "storage_id", "storage_position", "sampler_person_id", "receiver_person_id", "reception_date", "transport", "conservation_buffer", "sample_type_id", "sample_status_id", "workflow_id", "step_id", "project_id", "customer_id", "notes")
SELECT
    'Sample Ext. Name ' || s.id,
    NULL, -- No parent for primary samples
    (SELECT sampling_id FROM "lab"."sampling" ORDER BY RANDOM() LIMIT 1),
    generate_random_date_in_range(2019, 2025), -- Partition key (ensure this date matches a sampling_id's date if linking)
    (SELECT storage_id FROM "lab"."storage" ORDER BY RANDOM() LIMIT 1),
    FLOOR(RANDOM() * 100 + 1)::TEXT,
    (SELECT person_id FROM "reference"."personal" ORDER BY RANDOM() LIMIT 1),
    (SELECT person_id FROM "reference"."personal" ORDER BY RANDOM() LIMIT 1),
    generate_random_date_in_range(2019, 2025),
    'Cold Chain', 'DMSO',
    (SELECT sample_type_id FROM "reference"."samples_type" ORDER BY RANDOM() LIMIT 1),
    (SELECT status_id FROM "reference"."status" WHERE status_id IN ('Received', 'Dissection', 'Extracted') ORDER BY RANDOM() LIMIT 1),
    (SELECT workflow_id FROM "lims"."workflows" ORDER BY RANDOM() LIMIT 1),
    (SELECT step_id FROM "lims"."workflow_steps" ORDER BY RANDOM() LIMIT 1),
    (SELECT project_id FROM "lims"."projects" ORDER BY RANDOM() LIMIT 1),
    (SELECT customer_id FROM "lims"."customers" ORDER BY RANDOM() LIMIT 1),
    'Notes for sample ' || s.id
FROM GENERATE_SERIES(1, 50) AS s(id); -- sample_id generated by trigger

-- lab.fishing
INSERT INTO "lab"."fishing" ("sampling_id", "sampling_date", "taxon_id", "catch_kg", "catch_fish", "customer_id", "notes")
SELECT
    sa.sampling_id,
    sa.sampling_date,
    (SELECT taxon_id FROM "reference"."taxon" WHERE rank = 'species' ORDER BY RANDOM() LIMIT 1),
    (RANDOM() * 100)::NUMERIC(10,2),
    FLOOR(RANDOM() * 500),
    (SELECT customer_id FROM "lims"."customers" ORDER BY RANDOM() LIMIT 1),
    'Fishing notes ' || s.id
FROM GENERATE_SERIES(1, 20) AS s(id)
JOIN (SELECT sampling_id, sampling_date FROM "lab"."sampling" ORDER BY RANDOM() LIMIT 20) sa ON TRUE; -- fishing_id generated by trigger

-- lab.storage_log
INSERT INTO "lab"."storage_log" ("sample_id", "sample_sampling_date", "storage_id", "person_id", "move_date", "status", "storage_position", "notes")
SELECT
    sm.sample_id,
    sm.sampling_date,
    sm.storage_id,
    (SELECT person_id FROM "reference"."personal" ORDER BY RANDOM() LIMIT 1),
    NOW() - (RANDOM() * INTERVAL '365 days'),
    'Moved',
    sm.storage_position,
    'Moved to new position'
FROM (SELECT sample_id, sampling_date, storage_id, storage_position FROM "lab"."samples" WHERE storage_id IS NOT NULL ORDER BY RANDOM() LIMIT 50) sm;

-- lab.fish (child sample)
INSERT INTO "lab"."fish" ("parent_sample_id", "experiment_id", "species_id", "total_length_mm", "fork_length_mm", "standard_length_mm", "weight_g", "sex", "maturity_stage", "stomach_contents", "disease_info", "tag_id", "storage_id", "storage_position", "project_id", "customer_id", "notes")
SELECT
    sm.sample_id,
    (SELECT experiment_id FROM "lab"."experiments" ORDER BY RANDOM() LIMIT 1),
    (SELECT species_id FROM "reference"."species" ORDER BY RANDOM() LIMIT 1),
    FLOOR(RANDOM() * 500 + 50), FLOOR(RANDOM() * 450 + 50), FLOOR(RANDOM() * 400 + 50),
    FLOOR(RANDOM() * 2000 + 100),
    CASE FLOOR(RANDOM() * 3) WHEN 0 THEN 'Male' WHEN 1 THEN 'Female' ELSE 'Undetermined' END,
    'Stage ' || FLOOR(RANDOM() * 5 + 1),
    '{"items": ["shrimp", "fish larvae"]}', 'None',
    'TAG' || LPAD(s.id::TEXT, 3, '0'),
    (SELECT storage_id FROM "lab"."storage" ORDER BY RANDOM() LIMIT 1),
    FLOOR(RANDOM() * 100 + 1)::TEXT,
    (SELECT project_id FROM "lims"."projects" ORDER BY RANDOM() LIMIT 1),
    (SELECT customer_id FROM "lims"."customers" ORDER BY RANDOM() LIMIT 1),
    'Fish sample notes ' || s.id
FROM GENERATE_SERIES(1, 20) AS s(id)
JOIN (SELECT sample_id FROM "lab"."master_samples" ORDER BY RANDOM() LIMIT 20) sm ON TRUE; -- sample_id generated by trigger

-- lab.tissue (child sample)
INSERT INTO "lab"."tissue" ("parent_sample_id", "experiment_id", "weight_mg", "tissue_type", "preservation_method", "storage_id", "storage_position", "project_id", "notes")
SELECT
    sm.sample_id,
    (SELECT experiment_id FROM "lab"."experiments" ORDER BY RANDOM() LIMIT 1),
    FLOOR(RANDOM() * 500 + 10),
    CASE FLOOR(RANDOM() * 3) WHEN 0 THEN 'Muscle' WHEN 1 THEN 'Liver' ELSE 'Fin' END,
    'Ethanol',
    (SELECT storage_id FROM "lab"."storage" ORDER BY RANDOM() LIMIT 1),
    FLOOR(RANDOM() * 100 + 1)::TEXT,
    (SELECT project_id FROM "lims"."projects" ORDER BY RANDOM() LIMIT 1),
    'Tissue sample notes ' || s.id
FROM GENERATE_SERIES(1, 20) AS s(id)
JOIN (SELECT sample_id FROM "lab"."master_samples" ORDER BY RANDOM() LIMIT 20) sm ON TRUE; -- sample_id generated by trigger

-- lab.otoliths
INSERT INTO "lab"."otoliths" ("sample_id", "reader_person_id", "side", "age_reading_years", "confidence", "reading_date", "project_id", "notes")
SELECT
    sm.sample_id,
    (SELECT person_id FROM "reference"."personal" ORDER BY RANDOM() LIMIT 1),
    CASE FLOOR(RANDOM() * 2) WHEN 0 THEN 'Left' ELSE 'Right' END,
    FLOOR(RANDOM() * 30 + 1),
    (RANDOM() * 1)::NUMERIC(3,2),
    generate_random_date_in_range(2019, 2025),
    (SELECT project_id FROM "lims"."projects" ORDER BY RANDOM() LIMIT 1),
    'Otolith notes ' || s.id
FROM GENERATE_SERIES(1, 20) AS s(id)
JOIN (SELECT sample_id FROM "lab"."master_samples" ORDER BY RANDOM() LIMIT 20) sm ON TRUE; -- otolith_id generated by trigger

-- lab.dna (child sample)
INSERT INTO "lab"."dna" ("parent_sample_id", "experiment_id", "volume_ul", "concentration_ng_ul", "a260_280", "a260_230", "extraction_method", "preservation_method", "extraction_date", "extraction_number", "storage_id", "storage_position", "project_id", "notes")
SELECT
    sm.sample_id,
    (SELECT experiment_id FROM "lab"."experiments" ORDER BY RANDOM() LIMIT 1),
    FLOOR(RANDOM() * 100 + 10),
    (RANDOM() * 100 + 10)::NUMERIC(10,2),
    (RANDOM() * 0.5 + 1.8)::NUMERIC(3,2), (RANDOM() * 0.5 + 1.8)::NUMERIC(3,2),
    'Qiagen', 'Frozen', generate_random_date_in_range(2019, 2025),
    FLOOR(RANDOM() * 5 + 1),
    (SELECT storage_id FROM "lab"."storage" ORDER BY RANDOM() LIMIT 1),
    FLOOR(RANDOM() * 100 + 1)::TEXT,
    (SELECT project_id FROM "lims"."projects" ORDER BY RANDOM() LIMIT 1),
    'DNA sample notes ' || s.id
FROM GENERATE_SERIES(1, 20) AS s(id)
JOIN (SELECT sample_id FROM "lab"."master_samples" ORDER BY RANDOM() LIMIT 20) sm ON TRUE; -- sample_id generated by trigger

-- lab.rna (child sample)
INSERT INTO "lab"."rna" ("parent_sample_id", "experiment_id", "volume_ul", "concentration_ng_ul", "a260_280", "a260_230", "extraction_method", "preservation_method", "extraction_date", "extraction_number", "storage_id", "storage_position", "project_id", "notes")
SELECT
    sm.sample_id,
    (SELECT experiment_id FROM "lab"."experiments" ORDER BY RANDOM() LIMIT 1),
    FLOOR(RANDOM() * 100 + 10),
    (RANDOM() * 50 + 5)::NUMERIC(10,2),
    (RANDOM() * 0.5 + 1.8)::NUMERIC(3,2), (RANDOM() * 0.5 + 1.8)::NUMERIC(3,2),
    'Trizol', 'Frozen', generate_random_date_in_range(2019, 2025),
    FLOOR(RANDOM() * 5 + 1),
    (SELECT storage_id FROM "lab"."storage" ORDER BY RANDOM() LIMIT 1),
    FLOOR(RANDOM() * 100 + 1)::TEXT,
    (SELECT project_id FROM "lims"."projects" ORDER BY RANDOM() LIMIT 1),
    'RNA sample notes ' || s.id
FROM GENERATE_SERIES(1, 20) AS s(id)
JOIN (SELECT sample_id FROM "lab"."master_samples" ORDER BY RANDOM() LIMIT 20) sm ON TRUE; -- sample_id generated by trigger

-- lab.sediments (child sample)
INSERT INTO "lab"."sediments" ("parent_sample_id", "experiment_id", "project_id", "volume", "volume_unit_id", "depth_m", "sampling_method", "conservation_buffer", "storage_id", "storage_position", "external_name", "notes")
SELECT
    sm.sample_id,
    (SELECT experiment_id FROM "lab"."experiments" ORDER BY RANDOM() LIMIT 1),
    (SELECT project_id FROM "lims"."projects" ORDER BY RANDOM() LIMIT 1),
    FLOOR(RANDOM() * 100 + 10),
    (SELECT unit_id FROM "reference"."units" WHERE unit_type = 'volume' ORDER BY RANDOM() LIMIT 1),
    FLOOR(RANDOM() * 50 + 1),
    'Grab', 'Formalin',
    (SELECT storage_id FROM "lab"."storage" ORDER BY RANDOM() LIMIT 1),
    FLOOR(RANDOM() * 100 + 1)::TEXT,
    'Sediment Ext. Name ' || s.id,
    'Sediment sample notes ' || s.id
FROM GENERATE_SERIES(1, 20) AS s(id)
JOIN (SELECT sample_id FROM "lab"."master_samples" ORDER BY RANDOM() LIMIT 20) sm ON TRUE; -- sample_id generated by trigger

-- lab.water (child sample)
INSERT INTO "lab"."water" ("parent_sample_id", "experiment_id", "volume_l", "filter", "filter_pore_size_um", "depth_m", "sampling_method", "conservation_buffer", "storage_id", "storage_position", "notes", "project_id")
SELECT
    sm.sample_id,
    (SELECT experiment_id FROM "lab"."experiments" ORDER BY RANDOM() LIMIT 1),
    (RANDOM() * 10 + 1)::NUMERIC(5,2), 'GF/F', (RANDOM() * 1 + 0.1)::NUMERIC(3,2),
    FLOOR(RANDOM() * 200 + 1), 'Niskin', 'None',
    (SELECT storage_id FROM "lab"."storage" ORDER BY RANDOM() LIMIT 1),
    FLOOR(RANDOM() * 100 + 1)::TEXT,
    'Water sample notes ' || s.id,
    (SELECT project_id FROM "lims"."projects" ORDER BY RANDOM() LIMIT 1)
FROM GENERATE_SERIES(1, 20) AS s(id)
JOIN (SELECT sample_id FROM "lab"."master_samples" ORDER BY RANDOM() LIMIT 20) sm ON TRUE; -- sample_id generated by trigger

-- lab.experiments_samples
INSERT INTO "lab"."experiments_samples" ("experiment_id", "sample_id", "notes")
SELECT
    e.experiment_id,
    sm.sample_id,
    'Experiment sample link notes'
FROM (SELECT experiment_id FROM "lab"."experiments" ORDER BY RANDOM() LIMIT 25) e
JOIN (SELECT sample_id FROM "lab"."master_samples" ORDER BY RANDOM() LIMIT 25) sm ON TRUE
LIMIT 50
ON CONFLICT ("experiment_id", "sample_id") DO NOTHING;

-- lab.dissections
INSERT INTO "lab"."dissections" ("sample_id", "person_id", "dissection_date", "stomach_contents_jsonb", "gonad_weight_g", "liver_weight_g", "notes", "status_id")
SELECT
    sm.sample_id,
    (SELECT person_id FROM "reference"."personal" ORDER BY RANDOM() LIMIT 1),
    generate_random_date_in_range(2019, 2025),
    CASE WHEN RANDOM() < 0.5 THEN '{"items": ["algae", "detritus"]}'::jsonb ELSE NULL END,
    (RANDOM() * 100)::NUMERIC(10,2), (RANDOM() * 50)::NUMERIC(10,2),
    'Dissection notes ' || s.id,
    (SELECT status_id FROM "reference"."status" WHERE status_id = 'Dissection' LIMIT 1)
FROM GENERATE_SERIES(1, 20) AS s(id)
JOIN (SELECT sample_id FROM "lab"."master_samples" ORDER BY RANDOM() LIMIT 20) sm ON TRUE; -- dissection_id generated by trigger

-- lab.extraction
INSERT INTO "lab"."extraction" ("experiment_id", "sample_id", "parent_sample_id", "sample_type_id", "extracted_dna_sample_id", "extracted_rna_sample_id", "extraction_date", "person_id", "kit", "elution_volume_ul", "yield_qubit_ng_ul", "yield_nanodrop_ng_ul", "a260_280", "a260_230", "extraction_blank_id", "notes", "status_id", "storage_id", "storage_position", "project_id")
SELECT
    (SELECT experiment_id FROM "lab"."experiments" ORDER BY RANDOM() LIMIT 1),
    sm.sample_id,
    sm.sample_id, -- Parent is the same as input for first extraction
    (SELECT sample_type_id FROM "reference"."samples_type" ORDER BY RANDOM() LIMIT 1),
    (SELECT sample_id FROM "lab"."master_samples" WHERE sample_id LIKE 'D%' ORDER BY RANDOM() LIMIT 1),
    (SELECT sample_id FROM "lab"."master_samples" WHERE sample_id LIKE 'R%' ORDER BY RANDOM() LIMIT 1),
    generate_random_date_in_range(2019, 2025),
    (SELECT person_id FROM "reference"."personal" ORDER BY RANDOM() LIMIT 1),
    'DNeasy Blood & Tissue Kit', FLOOR(RANDOM() * 100 + 50),
    (RANDOM() * 50 + 10)::NUMERIC(10,2), (RANDOM() * 60 + 5)::NUMERIC(10,2),
    (RANDOM() * 0.5 + 1.8)::NUMERIC(3,2), (RANDOM() * 0.5 + 1.8)::NUMERIC(3,2),
    NULL, 'Extraction notes ' || s.id,
    (SELECT status_id FROM "reference"."status" WHERE status_id = 'Extracted' LIMIT 1),
    (SELECT storage_id FROM "lab"."storage" ORDER BY RANDOM() LIMIT 1),
    FLOOR(RANDOM() * 100 + 1)::TEXT,
    (SELECT project_id FROM "lims"."projects" ORDER BY RANDOM() LIMIT 1)
FROM GENERATE_SERIES(1, 30) AS s(id)
JOIN (SELECT sample_id FROM "lab"."master_samples" ORDER BY RANDOM() LIMIT 30) sm ON TRUE; -- extraction_id generated by trigger

-- lab.nanodrop
INSERT INTO "lab"."nanodrop" ("experiment_id", "sample_id", "nanodrop_concentration", "concentration_unit_id", "a260", "a260_280", "a260_280_note", "a260_230", "a260_230_note", "measurement_date", "elution_volume_ul", "person_id", "notes", "status_id", "storage_id", "storage_position", "project_id", "result_date")
SELECT
    (SELECT experiment_id FROM "lab"."experiments" ORDER BY RANDOM() LIMIT 1),
    sm.sample_id,
    (RANDOM() * 100 + 10)::NUMERIC(10,2), (SELECT unit_id FROM "reference"."units" WHERE unit_id = 'ng_ul' LIMIT 1),
    (RANDOM() * 0.5 + 0.1)::NUMERIC(3,2), (RANDOM() * 0.5 + 1.8)::NUMERIC(3,2), 'Good',
    (RANDOM() * 0.5 + 1.8)::NUMERIC(3,2), 'Good',
    generate_random_date_in_range(2019, 2025),
    FLOOR(RANDOM() * 50)::NUMERIC(10,2),
    (SELECT person_id FROM "reference"."personal" ORDER BY RANDOM() LIMIT 1),
    'Nanodrop notes ' || s.id,
    (SELECT status_id FROM "reference"."status" WHERE status_id = 'Nanodrop QC' LIMIT 1),
    (SELECT storage_id FROM "lab"."storage" ORDER BY RANDOM() LIMIT 1),
    FLOOR(RANDOM() * 100 + 1)::TEXT,
    (SELECT project_id FROM "lims"."projects" ORDER BY RANDOM() LIMIT 1),
    NOW() - (RANDOM() * INTERVAL '365 days')
FROM GENERATE_SERIES(1, 30) AS s(id)
JOIN (SELECT sample_id FROM "lab"."master_samples" ORDER BY RANDOM() LIMIT 30) sm ON TRUE; -- nanodrop_id generated by trigger

-- lab.qubit
INSERT INTO "lab"."qubit" ("sample_id", "experiment_id", "run_id", "assay_kit", "measurement_date", "qubit_tube_conc", "tube_unit_id", "qubit_original_sample_conc", "original_sample_unit_id", "sample_volume_ul", "elution_volume_ul", "person_id", "notes", "status_id", "storage_id", "storage_position", "project_id")
SELECT
    sm.sample_id,
    (SELECT experiment_id FROM "lab"."experiments" ORDER BY RANDOM() LIMIT 1),
    'RUN' || LPAD(s.id::TEXT, 3, '0'), 'dsDNA HS',
    generate_random_date_in_range(2019, 2025),
    (RANDOM() * 200 + 10)::NUMERIC(10,2), (SELECT unit_id FROM "reference"."units" WHERE unit_id = 'ng_ul' LIMIT 1),
    (RANDOM() * 100 + 5)::NUMERIC(10,2), (SELECT unit_id FROM "reference"."units" WHERE unit_id = 'ng_ul' LIMIT 1),
    FLOOR(RANDOM() * 100), FLOOR(RANDOM() * 50),
    (SELECT person_id FROM "reference"."personal" ORDER BY RANDOM() LIMIT 1),
    'Qubit notes ' || s.id,
    (SELECT status_id FROM "reference"."status" WHERE status_id = 'Qubit QC' LIMIT 1),
    (SELECT storage_id FROM "lab"."storage" ORDER BY RANDOM() LIMIT 1),
    FLOOR(RANDOM() * 100 + 1)::TEXT,
    (SELECT project_id FROM "lims"."projects" ORDER BY RANDOM() LIMIT 1)
FROM GENERATE_SERIES(1, 30) AS s(id)
JOIN (SELECT sample_id FROM "lab"."master_samples" ORDER BY RANDOM() LIMIT 30) sm ON TRUE; -- qubit_id generated by trigger

-- lab.tapestation
INSERT INTO "lab"."tapestation" ("experiment_id", "position", "measurement_date", "kit", "person_id", "notes", "sample_id", "storage_id", "storage_position", "status_id", "project_id")
SELECT
    (SELECT experiment_id FROM "lab"."experiments" ORDER BY RANDOM() LIMIT 1),
    'A' || FLOOR(RANDOM() * 12 + 1),
    generate_random_date_in_range(2019, 2025),
    'TapeStation HS D5000',
    (SELECT person_id FROM "reference"."personal" ORDER BY RANDOM() LIMIT 1),
    'Tapestation notes ' || s.id,
    sm.sample_id,
    (SELECT storage_id FROM "lab"."storage" ORDER BY RANDOM() LIMIT 1),
    FLOOR(RANDOM() * 100 + 1)::TEXT,
    (SELECT status_id FROM "reference"."status" WHERE status_id = 'Tapestation QC' LIMIT 1),
    (SELECT project_id FROM "lims"."projects" ORDER BY RANDOM() LIMIT 1)
FROM GENERATE_SERIES(1, 30) AS s(id)
JOIN (SELECT sample_id FROM "lab"."master_samples" ORDER BY RANDOM() LIMIT 30) sm ON TRUE; -- tapestation_id generated by trigger

-- lab.pcr
INSERT INTO "lab"."pcr" ("experiment_id", "sample_id", "position", "primer_id", "pcr_blank_id", "pcr_date", "person_id", "kit", "storage_id", "storage_position", "status_id", "notes", "project_id", "volume_reaction_ul")
SELECT
    (SELECT experiment_id FROM "lab"."experiments" ORDER BY RANDOM() LIMIT 1),
    sm.sample_id,
    'Well ' || FLOOR(RANDOM() * 96 + 1),
    (SELECT primer_id FROM "lims"."primers" ORDER BY RANDOM() LIMIT 1),
    CASE WHEN RANDOM() < 0.1 THEN 'BLANK' || s.id ELSE NULL END,
    generate_random_date_in_range(2019, 2025),
    (SELECT person_id FROM "reference"."personal" ORDER BY RANDOM() LIMIT 1),
    'Taq PCR Master Mix',
    (SELECT storage_id FROM "lab"."storage" ORDER BY RANDOM() LIMIT 1),
    FLOOR(RANDOM() * 100 + 1)::TEXT,
    (SELECT status_id FROM "reference"."status" WHERE status_id = 'PCR Done' LIMIT 1),
    'PCR notes ' || s.id,
    (SELECT project_id FROM "lims"."projects" ORDER BY RANDOM() LIMIT 1),
    FLOOR(RANDOM() * 50 + 10)::NUMERIC(10,2)
FROM GENERATE_SERIES(1, 30) AS s(id)
JOIN (SELECT sample_id FROM "lab"."master_samples" ORDER BY RANDOM() LIMIT 30) sm ON TRUE; -- pcr_id generated by trigger

-- lab.gelelectrophoresis
INSERT INTO "lab"."gelelectrophoresis" ("experiment_id", "sample_id", "position", "ladder", "voltage", "band_size_bp", "gel_type", "run_time_minutes", "run_date", "person_id", "storage_id", "storage_position", "project_id", "notes")
SELECT
    (SELECT experiment_id FROM "lab"."experiments" ORDER BY RANDOM() LIMIT 1),
    sm.sample_id,
    'Lane ' || FLOOR(RANDOM() * 20 + 1),
    '1kb DNA Ladder', 100, FLOOR(RANDOM() * 1000 + 100), 'Agarose',
    FLOOR(RANDOM() * 60 + 30), generate_random_date_in_range(2019, 2025),
    (SELECT person_id FROM "reference"."personal" ORDER BY RANDOM() LIMIT 1),
    (SELECT storage_id FROM "lab"."storage" ORDER BY RANDOM() LIMIT 1),
    FLOOR(RANDOM() * 100 + 1)::TEXT,
    (SELECT project_id FROM "lims"."projects" ORDER BY RANDOM() LIMIT 1),
    'Gel electrophoresis notes ' || s.id
FROM GENERATE_SERIES(1, 20) AS s(id)
JOIN (SELECT sample_id FROM "lab"."master_samples" ORDER BY RANDOM() LIMIT 20) sm ON TRUE; -- gelelectrophoresis_id generated by trigger

-- lab.qpcr
INSERT INTO "lab"."qpcr" ("experiment_id", "sample_id", "position", "qpcr_date", "person_id", "primer_id", "ct_value", "inhibitor_test_result", "pcr_blank_id", "kit", "volume_ul", "storage_id", "storage_position", "status_id", "project_id")
SELECT
    (SELECT experiment_id FROM "lab"."experiments" ORDER BY RANDOM() LIMIT 1),
    sm.sample_id,
    'Well ' || FLOOR(RANDOM() * 96 + 1),
    generate_random_date_in_range(2019, 2025),
    (SELECT person_id FROM "reference"."personal" ORDER BY RANDOM() LIMIT 1),
    (SELECT primer_id FROM "lims"."primers" ORDER BY RANDOM() LIMIT 1),
    (RANDOM() * 30 + 10)::NUMERIC(5,2),
    CASE WHEN RANDOM() < 0.1 THEN 'Positive' ELSE 'Negative' END,
    NULL, 'qPCR Mastermix', FLOOR(RANDOM() * 20 + 5),
    (SELECT storage_id FROM "lab"."storage" ORDER BY RANDOM() LIMIT 1),
    FLOOR(RANDOM() * 100 + 1)::TEXT,
    (SELECT status_id FROM "reference"."status" WHERE status_id = 'qPCR Done' LIMIT 1),
    (SELECT project_id FROM "lims"."projects" ORDER BY RANDOM() LIMIT 1)
FROM GENERATE_SERIES(1, 20) AS s(id)
JOIN (SELECT sample_id FROM "lab"."master_samples" ORDER BY RANDOM() LIMIT 20) sm ON TRUE; -- qpcr_id generated by trigger

-- lab.library
INSERT INTO "lab"."library" ("experiment_id", "sample_id", "library_name", "prep_date", "person_id", "library_prep_kit", "index_sequence", "read_length_bp", "storage_id", "storage_position", "project_id", "notes")
SELECT
    (SELECT experiment_id FROM "lab"."experiments" ORDER BY RANDOM() LIMIT 1),
    sm.sample_id,
    'Library ' || generate_random_string(8),
    generate_random_date_in_range(2020, 2025),
    (SELECT person_id FROM "reference"."personal" ORDER BY RANDOM() LIMIT 1),
    'Nextera DNA Flex', 'INDEX' || LPAD(s.id::TEXT, 2, '0'),
    FLOOR(RANDOM() * 150 + 50),
    (SELECT storage_id FROM "lab"."storage" ORDER BY RANDOM() LIMIT 1),
    FLOOR(RANDOM() * 100 + 1)::TEXT,
    (SELECT project_id FROM "lims"."projects" ORDER BY RANDOM() LIMIT 1),
    'Library prep notes ' || s.id
FROM GENERATE_SERIES(1, 20) AS s(id)
JOIN (SELECT sample_id FROM "lab"."master_samples" ORDER BY RANDOM() LIMIT 20) sm ON TRUE; -- library_id generated by trigger

-- lab.sequencing
INSERT INTO "lab"."sequencing" ("experiment_id", "library_id", "sample_id", "sequencing_date", "person_id", "sequencer", "flow_cell_id", "library_prep_kit", "index_sequence", "read_length_bp", "total_reads", "raw_data_path", "genbank_accession_number", "status_id", "storage_id", "storage_position", "project_id", "notes")
SELECT
    (SELECT experiment_id FROM "lab"."experiments" ORDER BY RANDOM() LIMIT 1),
    (SELECT library_id FROM "lab"."library" ORDER BY RANDOM() LIMIT 1),
    sm.sample_id,
    generate_random_date_in_range(2020, 2025),
    (SELECT person_id FROM "reference"."personal" ORDER BY RANDOM() LIMIT 1),
    'Illumina NovaSeq', 'FLOWCELL' || LPAD(s.id::TEXT, 3, '0'),
    'Nextera DNA Flex', 'INDEX' || LPAD(s.id::TEXT, 2, '0'),
    FLOOR(RANDOM() * 150 + 50), FLOOR(RANDOM() * 1000000000 + 1000000),
    '/data/raw/' || generate_random_string(10), 'ACC' || LPAD(s.id::TEXT, 5, '0'),
    (SELECT status_id FROM "reference"."status" WHERE status_id = 'Sequencing Done' LIMIT 1),
    (SELECT storage_id FROM "lab"."storage" ORDER BY RANDOM() LIMIT 1),
    FLOOR(RANDOM() * 100 + 1)::TEXT,
    (SELECT project_id FROM "lims"."projects" ORDER BY RANDOM() LIMIT 1),
    'Sequencing notes ' || s.id
FROM GENERATE_SERIES(1, 20) AS s(id)
JOIN (SELECT sample_id FROM "lab"."master_samples" ORDER BY RANDOM() LIMIT 20) sm ON TRUE; -- sequencing_id generated by trigger

-- lab.datasets
INSERT INTO "lab"."datasets" ("source_type", "ecosystem_id", "region_id", "customer_id", "stored_location_id", "reception_date", "notes", "storage_path")
SELECT
    'Sequencing Data',
    (SELECT ecosystem_id FROM "reference"."ecosystem" ORDER BY RANDOM() LIMIT 1),
    (SELECT region_id FROM "reference"."region" ORDER BY RANDOM() LIMIT 1),
    (SELECT customer_id FROM "lims"."customers" ORDER BY RANDOM() LIMIT 1),
    (SELECT storage_id FROM "lab"."storage" ORDER BY RANDOM() LIMIT 1),
    generate_random_date_in_range(2020, 2025),
    'Dataset notes ' || s.id,
    '/datasets/' || generate_random_string(10)
FROM GENERATE_SERIES(1, 15) AS s(id); -- dataset_id generated by trigger


-- ======================================================================
-- Data for Bioinformatics Schema
-- ======================================================================

-- bioinformatics.reference_databases
INSERT INTO "bioinformatics"."reference_databases" ("db_id", "db_name", "db_version", "notes", "url", "last_updated_date")
SELECT
    'DB' || LPAD(s.id::TEXT, 2, '0'),
    'Reference DB ' || generate_random_string(5),
    (FLOOR(RANDOM() * 10 + 1))::TEXT || '.0',
    'Notes for DB ' || s.id,
    'http://db.example.com/' || s.id,
    generate_random_date_in_range(2023, 2025)
FROM GENERATE_SERIES(1, 5) AS s(id)
ON CONFLICT ("db_id") DO NOTHING;

-- bioinformatics.analysis_pipelines
INSERT INTO "bioinformatics"."analysis_pipelines" ("pipeline_id", "pipeline_name", "version", "repository_link", "notes")
SELECT
    'PIPE' || LPAD(s.id::TEXT, 2, '0'), -- This will be overwritten by trigger
    'Analysis Pipeline ' || generate_random_string(8),
    'v' || (FLOOR(RANDOM() * 5 + 1))::TEXT || '.' || FLOOR(RANDOM() * 10)::TEXT,
    'http://github.com/pipeline/' || s.id,
    'Notes for pipeline ' || s.id
FROM GENERATE_SERIES(1, 10) AS s(id)
ON CONFLICT ("pipeline_id") DO NOTHING;

-- bioinformatics.analysis_runs
INSERT INTO "bioinformatics"."analysis_runs" ("pipeline_id", "sequencing_id", "person_id", "run_date", "parameters_jsonb", "reference_db_id", "clustering_threshold", "final_output_path", "notes")
SELECT
    (SELECT pipeline_id FROM "bioinformatics"."analysis_pipelines" ORDER BY RANDOM() LIMIT 1),
    (SELECT sequencing_id FROM "lab"."sequencing" ORDER BY RANDOM() LIMIT 1),
    (SELECT person_id FROM "reference"."personal" ORDER BY RANDOM() LIMIT 1),
    NOW() - (RANDOM() * INTERVAL '365 days'),
    '{"min_reads": ' || FLOOR(RANDOM() * 1000)::TEXT || '}',
    (SELECT db_id FROM "bioinformatics"."reference_databases" ORDER BY RANDOM() LIMIT 1),
    (RANDOM() * 0.1 + 0.9)::NUMERIC(3,2),
    '/analysis_results/' || generate_random_string(10),
    'Analysis run notes ' || s.id
FROM GENERATE_SERIES(1, 20) AS s(id); -- run_id generated by trigger

-- bioinformatics.edna_assignments
INSERT INTO "bioinformatics"."edna_assignments" ("run_id", "sample_id", "taxon_id", "read_count", "confidence", "notes")
SELECT
    (SELECT run_id FROM "bioinformatics"."analysis_runs" ORDER BY RANDOM() LIMIT 1),
    (SELECT sample_id FROM "lab"."master_samples" ORDER BY RANDOM() LIMIT 1),
    (SELECT taxon_id FROM "reference"."taxon" WHERE rank = 'species' ORDER BY RANDOM() LIMIT 1),
    FLOOR(RANDOM() * 100000 + 100), (RANDOM() * 1)::NUMERIC(3,2),
    'Assignment notes ' || s.id
FROM GENERATE_SERIES(1, 30) AS s(id); -- assignment_id generated by trigger

-- ======================================================================
-- END OF DATA GENERATION
-- ======================================================================

-- Reset LIMS user to empty string after data generation
SET lims.current_person_id = '';

-- Remove helper functions (optional, but keeps schema clean)
DROP FUNCTION IF EXISTS generate_random_string(INT);
DROP FUNCTION IF EXISTS generate_random_date_in_range(INT, INT);
DROP FUNCTION IF EXISTS generate_random_phone();
DROP FUNCTION IF EXISTS generate_random_email(TEXT);
DROP FUNCTION IF EXISTS generate_random_coordinate();
DROP FUNCTION IF EXISTS get_demo_password_hash();
