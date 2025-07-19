-- ======================================================================
-- DEMO DATA GENERATION FOR ALL TABLES
-- ======================================================================
-- ======================================================================
-- Demo Data Population for LIMS Database
-- This script inserts approximately 20 rows into each table.
-- It assumes the schema defined in 'postgres-schema-with-partitioning'
-- has already been executed.
-- ======================================================================

-- Set a user for audit log purposes (optional, but good for testing audit triggers)
SET lims.current_person_id TO 'system_user';

-- ======================================================================
-- 1. Reference Schema Data
-- ======================================================================

-- reference.personal
INSERT INTO "reference"."personal" ("person_id", "full_name", "room", "telephone", "mail", "password_hash", "notes") VALUES
('system_user', 'System Automation', NULL, NULL, NULL, 'hashed_system_pw', 'Automated system processes'),
('john.doe', 'John Doe', 'A101', '123-456-7890', 'john.doe@example.com', 'hashed_pw_john', 'Lead Scientist, Bioinformatics'),
('jane.smith', 'Jane Smith', 'B202', '098-765-4321', 'jane.smith@example.com', 'hashed_pw_jane', 'Lab Manager'),
('alice.jones', 'Alice Jones', 'C303', '111-222-3333', 'alice.jones@example.com', 'hashed_pw_alice', 'Research Assistant, Lab'),
('bob.white', 'Bob White', 'D404', '444-555-6666', 'bob.white@example.com', 'hashed_pw_bob', 'Bioinformatics Analyst'),
('charlie.brown', 'Charlie Brown', 'A101', '777-888-9999', 'charlie.brown@example.com', 'hashed_pw_charlie', 'Junior Lab Technician'),
('david.green', 'David Green', 'B202', '123-123-1234', 'david.green@example.com', 'hashed_pw_david', 'Senior Scientist'),
('emily.black', 'Emily Black', 'C303', '456-456-4567', 'emily.black@example.com', 'hashed_pw_emily', 'Data Scientist'),
('frank.grey', 'Frank Grey', 'D404', '789-789-7890', 'frank.grey@example.com', 'hashed_pw_frank', 'Lab Technician'),
('grace.hall', 'Grace Hall', 'A101', '101-101-1010', 'grace.hall@example.com', 'hashed_pw_grace', 'Postdoc Researcher'),
('henry.king', 'Henry King', 'B202', '202-202-2020', 'henry.king@example.com', 'hashed_pw_henry', 'Intern'),
('irene.lim', 'Irene Lim', 'C303', '303-303-3030', 'irene.lim@example.com', 'hashed_pw_irene', 'Project Coordinator'),
('kevin.scott', 'Kevin Scott', 'D404', '404-404-4040', 'kevin.scott@example.com', 'hashed_pw_kevin', 'IT Support'),
('laura.miller', 'Laura Miller', 'A101', '505-505-5050', 'laura.miller@example.com', 'hashed_pw_laura', 'QA Specialist'),
('mike.taylor', 'Mike Taylor', 'B202', '606-606-6060', 'mike.taylor@example.com', 'hashed_pw_mike', 'HR Manager'),
('nancy.clark', 'Nancy Clark', 'C303', '707-707-7070', 'nancy.clark@example.com', 'hashed_pw_nancy', 'Finance Officer'),
('olivia.davis', 'Olivia Davis', 'D404', '808-808-8080', 'olivia.davis@example.com', 'hashed_pw_olivia', 'Purchasing Agent'),
('peter.evans', 'Peter Evans', 'A101', '909-909-9090', 'peter.evans@example.com', 'hashed_pw_peter', 'Safety Officer'),
('quinn.fisher', 'Quinn Fisher', 'B202', '121-212-1212', 'quinn.fisher@example.com', 'hashed_pw_quinn', 'Legal Counsel'),
('rachel.gonzalez', 'Rachel Gonzalez', 'C303', '343-434-3434', 'rachel.gonzalez@example.com', 'hashed_pw_rachel', 'Communications Lead')
ON CONFLICT ("person_id") DO NOTHING;

-- reference.status (already populated in schema, adding more if needed)
INSERT INTO "reference"."status" ("status_id", "notes") VALUES
('Planned', 'Activity is planned but not started'),
('In Progress', 'Activity is currently ongoing'),
('Completed', 'Activity has been successfully completed'),
('On Hold', 'Activity is temporarily paused'),
('Cancelled', 'Activity has been cancelled'),
('Failed', 'Activity failed to complete successfully'),
('Review', 'Activity results are under review')
ON CONFLICT ("status_id") DO NOTHING;

-- reference.room
INSERT INTO "reference"."room" ("room_id", "etage", "address", "notes") VALUES
('A101', '1st Floor', 'Main Building, 123 Lab St', 'Wet Lab for sample processing'),
('B202', '2nd Floor', 'Main Building, 123 Lab St', 'Molecular Biology Lab'),
('C303', '3rd Floor', 'Main Building, 123 Lab St', 'Bioinformatics Server Room'),
('D404', '4th Floor', 'Main Building, 123 Lab St', 'Microscopy Suite'),
('E505', '5th Floor', 'Annex Building, 456 Research Ave', 'Storage Facility'),
('F606', '6th Floor', 'Annex Building, 456 Research Ave', 'Chemical Storage'),
('G707', '7th Floor', 'Main Building, 123 Lab St', 'Office Space'),
('H808', '8th Floor', 'Main Building, 123 Lab St', 'Meeting Rooms'),
('I909', '9th Floor', 'Annex Building, 456 Research Ave', 'Culture Room'),
('J101', '1st Floor', 'Main Building, 123 Lab St', 'Sample Reception'),
('K202', '2nd Floor', 'Main Building, 123 Lab St', 'DNA Extraction Room'),
('L303', '3rd Floor', 'Main Building, 123 Lab St', 'Sequencing Lab'),
('M404', '4th Floor', 'Main Building, 123 Lab St', 'Histology Lab'),
('N505', '5th Floor', 'Annex Building, 456 Research Ave', 'Cold Storage'),
('O606', '6th Floor', 'Annex Building, 456 Research Ave', 'Waste Disposal'),
('P707', '7th Floor', 'Main Building, 123 Lab St', 'Break Room'),
('Q808', '8th Floor', 'Main Building, 123 Lab St', 'Library'),
('R909', '9th Floor', 'Annex Building, 456 Research Ave', 'Greenhouse'),
('S101', '1st Floor', 'Main Building, 123 Lab St', 'Instrument Room'),
('T202', '2nd Floor', 'Main Building, 123 Lab St', 'PCR Prep Room')
ON CONFLICT ("room_id") DO NOTHING;

-- reference.vessel
INSERT INTO "reference"."vessel" ("vessel_id", "vessel_name", "belong_to") VALUES
('RV_Investigator', 'R/V Investigator', 'Oceanographic Institute'),
('RV_Explorer', 'R/V Explorer', 'Marine Research Center'),
('FV_Seagull', 'F/V Seagull', 'Local Fishing Fleet'),
('RV_Discovery', 'R/V Discovery', 'University Research'),
('RV_Oceanus', 'R/V Oceanus', 'National Science Foundation'),
('FV_Stardust', 'F/V Stardust', 'Independent Fisherman'),
('RV_Pioneer', 'R/V Pioneer', 'Private Research Firm'),
('RV_Navigator', 'R/V Navigator', 'Government Agency'),
('FV_Bluefin', 'F/V Bluefin', 'Commercial Fishing'),
('RV_Challenger', 'R/V Challenger', 'International Consortium'),
('RV_Horizon', 'R/V Horizon', 'Environmental Agency'),
('FV_Dolphin', 'F/V Dolphin', 'Small Scale Fishing'),
('RV_Voyager', 'R/V Voyager', 'Deep Sea Exploration'),
('RV_Sentinel', 'R/V Sentinel', 'Coastal Monitoring'),
('FV_Neptune', 'F/V Neptune', 'Aquaculture Support'),
('RV_Aurora', 'R/V Aurora', 'Polar Research'),
('FV_Pelican', 'F/V Pelican', 'Shellfish Harvesting'),
('RV_Global', 'R/V Global', 'Global Climate Study'),
('FV_Starfish', 'F/V Starfish', 'Recreational Fishing'),
('RV_Hydro', 'R/V Hydro', 'Hydrographic Survey')
ON CONFLICT ("vessel_id") DO NOTHING;

-- reference.region
INSERT INTO "reference"."region" ("region_id", "region_abrv", "country", "category") VALUES
('NA_Atl', 'NA-ATL', 'USA', 'North Atlantic'),
('EU_Med', 'EU-MED', 'Spain', 'Mediterranean'),
('AS_Pac', 'AS-PAC', 'Japan', 'Asia Pacific'),
('SA_Atl', 'SA-ATL', 'Brazil', 'South Atlantic'),
('AF_Ind', 'AF-IND', 'South Africa', 'Indian Ocean'),
('OC_Pac', 'OC-PAC', 'Australia', 'Oceania Pacific'),
('NA_Pac', 'NA-PAC', 'Canada', 'North Pacific'),
('EU_Nor', 'EU-NOR', 'Norway', 'North Sea'),
('AS_Ind', 'AS-IND', 'India', 'Indian Ocean'),
('SA_Pac', 'SA-PAC', 'Chile', 'South Pacific'),
('AF_Atl', 'AF-ATL', 'Nigeria', 'West Africa Atlantic'),
('OC_Ind', 'OC-IND', 'Indonesia', 'Indian Ocean'),
('AR_Arc', 'AR-ARC', 'Arctic', 'Arctic Ocean'),
('AN_Ant', 'AN-ANT', 'Antarctica', 'Southern Ocean'),
('EU_Bal', 'EU-BAL', 'Germany', 'Baltic Sea'),
('AS_Sou', 'AS-SOU', 'China', 'South China Sea'),
('NA_Car', 'NA-CAR', 'Mexico', 'Caribbean Sea'),
('AF_Red', 'AF-RED', 'Egypt', 'Red Sea'),
('SA_Car', 'SA-CAR', 'Colombia', 'Caribbean Sea'),
('EU_Bla', 'EU-BLA', 'Turkey', 'Black Sea')
ON CONFLICT ("region_id") DO NOTHING;

-- reference.ecosystem
INSERT INTO "reference"."ecosystem" ("ecosystem_id", "ecosystem_abrv", "country", "category") VALUES
('OpenOcean', 'OO', NULL, 'Pelagic'),
('Coastal', 'CO', NULL, 'Nearshore'),
('DeepSea', 'DS', NULL, 'Benthic'),
('Estuary', 'ES', NULL, 'Brackish'),
('CoralReef', 'CR', NULL, 'Tropical Marine'),
('Mangrove', 'MG', NULL, 'Coastal Forest'),
('Polar', 'PO', NULL, 'Arctic/Antarctic'),
('HydrothermalVent', 'HV', NULL, 'Deep Sea Vent'),
('SeagrassBed', 'SB', NULL, 'Coastal Vegetation'),
('SaltMarsh', 'SM', NULL, 'Coastal Wetland'),
('KelpForest', 'KF', NULL, 'Temperate Marine'),
('Riverine', 'RI', NULL, 'Freshwater River'),
('Lake', 'LA', NULL, 'Freshwater Lake'),
('Wetland', 'WL', NULL, 'Freshwater Wetland'),
('Intertidal', 'IT', NULL, 'Tidal Zone'),
('UpwellingZone', 'UZ', NULL, 'Productive Ocean'),
('SubmarineCanyon', 'SC', NULL, 'Deep Sea Feature'),
('Fjord', 'FJ', NULL, 'Glacial Marine'),
('IceEdge', 'IE', NULL, 'Polar Marine'),
('Lagoon', 'LG', NULL, 'Shallow Coastal')
ON CONFLICT ("ecosystem_id") DO NOTHING;

-- reference.category
INSERT INTO "reference"."category" ("category_id", "notes") VALUES
('Chemical', 'Lab reagents and chemicals'),
('Consumable', 'Disposable lab supplies'),
('Equipment', 'Lab instruments and machinery'),
('Software', 'Bioinformatics software licenses'),
('Service', 'External lab services'),
('Biological', 'Biological samples or materials'),
('OfficeSupply', 'General office supplies'),
('Safety', 'Safety equipment and supplies'),
('FieldSupply', 'Supplies for field work'),
('ITHardware', 'Computer hardware and peripherals'),
('Glassware', 'Laboratory glassware'),
('Plasticware', 'Laboratory plasticware'),
('Media', 'Cell culture media'),
('Kit', 'Molecular biology kits'),
('Standard', 'Calibration standards'),
('ReferenceMaterial', 'Certified reference materials'),
('AnimalFeed', 'Animal feed for aquaculture'),
('CleaningSupply', 'Cleaning supplies for the lab'),
('Maintenance', 'Equipment maintenance parts'),
('Training', 'Training courses or materials')
ON CONFLICT ("category_id") DO NOTHING;

-- reference.samples_type (already populated in schema, adding more if needed)
INSERT INTO "reference"."samples_type" ("sample_type_id", "sample_type_abrv", "notes") VALUES
('WaterFilter', 'WF', 'Water sample filtered'),
('SedimentCore', 'SC', 'Sediment core sample'),
('Plankton', 'PL', 'Plankton net sample'),
('Benthos', 'BT', 'Benthic grab sample'),
('Environmental', 'EV', 'General environmental sample'),
('Microbe', 'MB', 'Microbial culture or isolate'),
('Protein', 'PR', 'Protein extract sample'),
('Lipid', 'LP', 'Lipid extract sample'),
('Metabolite', 'MT', 'Metabolite extract sample'),
('Isotope', 'IS', 'Isotope sample'),
('CellCulture', 'CC', 'Cell culture sample'),
('TissueBiopsy', 'TB', 'Tissue biopsy sample'),
('Blood', 'BL', 'Blood sample'),
('Urine', 'UR', 'Urine sample'),
('Hair', 'HR', 'Hair sample'),
('Feather', 'FT', 'Feather sample'),
('Scale', 'SL', 'Fish scale sample'),
('Bone', 'BN', 'Bone sample'),
('Shell', 'SH', 'Shell sample'),
('Feces', 'FC', 'Fecal sample')
ON CONFLICT ("sample_type_id") DO NOTHING;

-- reference.gene
INSERT INTO "reference"."gene" ("gene_id", "notes") VALUES
('16S_rRNA', 'Bacterial 16S ribosomal RNA gene'),
('18S_rRNA', 'Eukaryotic 18S ribosomal RNA gene'),
('COI', 'Cytochrome c oxidase subunit I gene'),
('ITS', 'Internal Transcribed Spacer region'),
('rbcL', 'Ribulose-1,5-bisphosphate carboxylase/oxygenase large subunit'),
('mtDNA_CR', 'Mitochondrial DNA control region'),
('CytB', 'Cytochrome B gene'),
('ND1', 'NADH dehydrogenase subunit 1 gene'),
('HSP70', 'Heat shock protein 70 gene'),
('GAPDH', 'Glyceraldehyde-3-phosphate dehydrogenase gene'),
('Actin', 'Actin gene'),
('Tubulin', 'Tubulin gene'),
('rpoB', 'RNA polymerase beta subunit gene'),
('gyrB', 'DNA gyrase subunit B gene'),
('nifH', 'Nitrogenase reductase gene'),
('amoA', 'Ammonia monooxygenase subunit A gene'),
('mcrA', 'Methyl coenzyme M reductase alpha subunit gene'),
('dsrB', 'Dissimilatory sulfite reductase beta subunit gene'),
('pmoA', 'Particulate methane monooxygenase subunit A gene'),
('nirK', 'Nitrite reductase (copper-containing) gene')
ON CONFLICT ("gene_id") DO NOTHING;

-- reference.taxon (simplified hierarchy for demo)
INSERT INTO "reference"."taxon" ("taxon_id", "taxon_parent", "de_name", "en_name", "rank") VALUES
('Life', NULL, 'Leben', 'Life', 'kingdom'),
('Animalia', 'Life', 'Tiere', 'Animals', 'kingdom'),
('Chordata', 'Animalia', 'Chordatiere', 'Chordates', 'phylum'),
('Vertebrata', 'Chordata', 'Wirbeltiere', 'Vertebrates', 'subphylum'),
('Actinopterygii', 'Vertebrata', 'Strahlenflosser', 'Ray-finned fishes', 'class'),
('Teleostei', 'Actinopterygii', 'Echte Knochenfische', 'Teleosts', 'infraclass'),
('Gadiformes', 'Teleostei', 'Dorschartige', 'Cod-like fishes', 'order'),
('Gadidae', 'Gadiformes', 'Dorsche', 'Codfishes', 'family'),
('Gadus', 'Gadidae', 'Dorsch', 'Cod', 'genus'),
('Gadus_morhua', 'Gadus', 'Atlantischer Kabeljau', 'Atlantic Cod', 'species'),
('Mammalia', 'Vertebrata', 'Säugetiere', 'Mammals', 'class'),
('Cetacea', 'Mammalia', 'Wale', 'Whales, Dolphins, Porpoises', 'order'),
('Delphinidae', 'Cetacea', 'Delfine', 'Oceanic Dolphins', 'family'),
('Tursiops', 'Delphinidae', 'Großer Tümmler', 'Bottlenose Dolphin', 'genus'),
('Tursiops_truncatus', 'Tursiops', 'Großer Tümmler (Art)', 'Common Bottlenose Dolphin', 'species'),
('Arthropoda', 'Animalia', 'Gliederfüßer', 'Arthropods', 'phylum'),
('Crustacea', 'Arthropoda', 'Krebstiere', 'Crustaceans', 'subphylum'),
('Decapoda', 'Crustacea', 'Zehnfußkrebse', 'Decapods', 'order'),
('Penaeidae', 'Decapoda', 'Echte Garnelen', 'Penaeid shrimps', 'family'),
('Penaeus', 'Penaeidae', 'Garnelen', 'Penaeid shrimp', 'genus'),
('Penaeus_monodon', 'Penaeus', 'Schwarze Tigergarnele', 'Giant Tiger Prawn', 'species')
ON CONFLICT ("taxon_id") DO NOTHING;

-- Update ltree paths after inserting hierarchical data
SELECT "reference".update_taxon_ltree_paths();

-- reference.species
INSERT INTO "reference"."species" ("species_id", "de_name", "en_name", "max_length_mm", "max_age_years") VALUES
('Gadus_morhua', 'Atlantischer Kabeljau', 'Atlantic Cod', 2000, 25),
('Tursiops_truncatus', 'Großer Tümmler (Art)', 'Common Bottlenose Dolphin', 4000, 50),
('Penaeus_monodon', 'Schwarze Tigergarnele', 'Giant Tiger Prawn', 360, 3)
ON CONFLICT ("species_id") DO NOTHING;

-- reference.units (already populated in schema, adding more if needed)
INSERT INTO "reference"."units" ("unit_id", "unit_name", "unit_abbreviation", "unit_type", "conversion_factor_to_base") VALUES
('kg', 'kilogram', 'kg', 'mass', 1),
('m', 'meter', 'm', 'length', 1),
('cm', 'centimeter', 'cm', 'length', 0.01),
('km', 'kilometer', 'km', 'length', 1000),
('ml', 'milliliter', 'ml', 'volume', 1e-3),
('ng', 'nanogram', 'ng', 'mass', 1e-12),
('pg', 'picogram', 'pg', 'mass', 1e-15),
('nM', 'nanomolar', 'nM', 'concentration', 1e-9),
('uM', 'micromolar', 'µM', 'concentration', 1e-6),
('mM', 'millimolar', 'mM', 'concentration', 1e-3),
('M', 'molar', 'M', 'concentration', 1),
('min', 'minute', 'min', 'time', 60),
('hour', 'hour', 'h', 'time', 3600),
('day', 'day', 'd', 'time', 86400),
('week', 'week', 'wk', 'time', 604800),
('month', 'month', 'mo', 'time', 2629746),
('year', 'year', 'yr', 'time', 31556952),
('percent', 'percent', '%', 'ratio', 0.01),
('ratio', 'ratio', 'ratio', 'ratio', 1)
ON CONFLICT ("unit_id") DO NOTHING;

-- ======================================================================
-- 2. Lims Schema Data
-- ======================================================================

-- lims.external_contacts
INSERT INTO "lims"."external_contacts" ("contact_id", "full_name", "organization", "telephone", "mail", "address") VALUES
('ext_uni_a', 'Dr. Anna Lee', 'University of Oceanography', '555-111-2222', 'anna.lee@uni.edu', '10 University Rd'),
('ext_gov_b', 'Mr. Ben Carter', 'Fisheries Department', '555-333-4444', 'ben.carter@gov.org', '20 Government Plaza'),
('ext_comp_c', 'Ms. Clara Diaz', 'BioTech Solutions Inc.', '555-555-6666', 'clara.diaz@biotech.com', '30 Innovation Dr'),
('ext_uni_d', 'Dr. Daniel Evans', 'Marine Biology Institute', '555-777-8888', 'daniel.evans@marine.edu', '40 Coastal Blvd'),
('ext_gov_e', 'Ms. Eva Foster', 'Environmental Protection Agency', '555-999-0000', 'eva.foster@epa.gov', '50 Green St'),
('ext_comp_f', 'Mr. Fred Gomez', 'AquaGenetics Ltd.', '555-123-4567', 'fred.gomez@aquagen.com', '60 Research Park'),
('ext_uni_g', 'Dr. Gina Harris', 'Coastal Ecology Lab', '555-234-5678', 'gina.harris@coast.edu', '70 Beachfront Ave'),
('ext_gov_h', 'Mr. Harry Ingram', 'Wildlife Conservation Dept.', '555-345-6789', 'harry.ingram@wildlife.gov', '80 Forest Rd'),
('ext_comp_i', 'Ms. Ivy Jenkins', 'Oceanic Data Services', '555-456-7890', 'ivy.jenkins@oceanic.com', '90 Data Center Way'),
('ext_uni_j', 'Dr. Jack Kelly', 'Polar Research Center', '555-567-8901', 'jack.kelly@polar.edu', '100 Ice Cap St'),
('ext_gov_k', 'Mr. Kyle Lopez', 'National Park Service', '555-678-9012', 'kyle.lopez@nps.gov', '110 Park Dr'),
('ext_comp_l', 'Ms. Lisa Moore', 'Marine Supplies Co.', '555-789-0123', 'lisa.moore@marinesupplies.com', '120 Port Rd'),
('ext_uni_m', 'Dr. Mark Nelson', 'Deep Sea Exploration Unit', '555-890-1234', 'mark.nelson@deepsea.edu', '130 Trench Ave'),
('ext_gov_n', 'Ms. Nora Owens', 'Customs and Border Protection', '555-012-3456', 'nora.owens@cbp.gov', '140 Border Rd'),
('ext_comp_o', 'Mr. Oscar Perry', 'Environmental Consulting', '555-234-5678', 'oscar.perry@environconsult.com', '150 Green Way'),
('ext_uni_p', 'Dr. Pam Queen', 'Freshwater Ecosystems Lab', '555-345-6789', 'pam.queen@freshwater.edu', '160 River Rd'),
('ext_gov_q', 'Mr. Quentin Ross', 'Agricultural Department', '555-456-7890', 'quentin.ross@agri.gov', '170 Farm Lane'),
('ext_comp_r', 'Ms. Rita Scott', 'Food Safety Testing', '555-567-8901', 'rita.scott@foodsafety.com', '180 Food St'),
('ext_uni_s', 'Dr. Sam Turner', 'Genomics Research Center', '555-678-9012', 'sam.turner@genomics.edu', '190 Genome Ave'),
('ext_gov_t', 'Mr. Tom Vance', 'Health Department', '555-789-0123', 'tom.vance@health.gov', '200 Health Blvd')
ON CONFLICT ("contact_id") DO NOTHING;

-- lims.customers
INSERT INTO "lims"."customers" ("customer_name", "customer_abrv", "address", "mail", "phone") VALUES
('Global Marine Research', 'GMR', '100 Ocean Drive', 'contact@gmr.org', '111-222-3333'),
('Coastal Fisheries Co.', 'CFC', '200 Port Road', 'info@cfc.com', '444-555-6666'),
('AquaCulture Innovations', 'AQI', '300 Farm Lane', 'sales@aqi.net', '777-888-9999'),
('Deep Sea Explorers LLC', 'DSE', '400 Abyss Way', 'support@dse.com', '123-987-6543'),
('Environmental Solutions Group', 'ESG', '500 Green Street', 'admin@esg.org', '987-654-3210'),
('Marine Biotechnology Corp', 'MBC', '600 Biotech Blvd', 'contact@mbc.com', '234-567-8901'),
('Oceanic Conservation Trust', 'OCT', '700 Coral Reef Ave', 'info@oct.org', '567-890-1234'),
('Polar Science Foundation', 'PSF', '800 Iceberg Rd', 'grants@psf.org', '890-123-4567'),
('Riverine Ecosystems Study', 'RES', '900 River Bank', 'research@res.edu', '345-678-9012'),
('Lake Management Services', 'LMS', '1000 Lake Shore', 'contact@lms.com', '678-901-2345'),
('Wetland Restoration Project', 'WRP', '1100 Marshland', 'info@wrp.org', '901-234-5678'),
('Intertidal Zone Research', 'IZR', '1200 Tidal Flats', 'admin@izr.edu', '210-987-6543'),
('Upwelling Dynamics Institute', 'UDI', '1300 Current St', 'support@udi.org', '543-210-9876'),
('Submarine Canyon Survey', 'SCS', '1400 Canyon Rd', 'contact@scs.com', '876-543-2109'),
('Fjord Ecology Center', 'FEC', '1500 Fjord View', 'info@fec.edu', '109-876-5432'),
('Ice Edge Climate Studies', 'IECS', '1600 Glacier Point', 'research@iecs.org', '432-109-8765'),
('Lagoon Biodiversity Project', 'LBP', '1700 Lagoon Rd', 'admin@lbp.com', '765-432-1098'),
('Coastal Development Group', 'CDG', '1800 Beach Blvd', 'contact@cdg.net', '098-765-4321'),
('Marine Waste Management', 'MWM', '1900 Recycle Way', 'info@mwm.org', '321-098-7654'),
('Global Ocean Observing System', 'GOOS', '2000 Satellite Rd', 'data@goos.org', '654-321-0987')
ON CONFLICT ("customer_id") DO NOTHING;

-- lims.projects
INSERT INTO "lims"."projects" ("project_id", "title", "status_id", "pi_person_id", "funder", "customer_id", "start_date", "end_date", "report_date") VALUES
('PROJ-2023-001', 'Atlantic Cod Population Dynamics', 'In Progress', 'john.doe', 'National Fisheries Grant', 1, '2023-01-15', '2024-12-31', '2025-01-31'),
('PROJ-2023-002', 'Mediterranean Dolphin Health Assessment', 'Completed', 'jane.smith', 'EU Research Fund', 4, '2023-03-01', '2024-06-30', '2024-07-15'),
('PROJ-2023-003', 'Tiger Prawn Aquaculture Optimization', 'In Progress', 'alice.jones', 'Private Investor', 3, '2023-05-10', '2025-04-30', '2025-05-15'),
('PROJ-2023-004', 'Deep Sea Microbial Diversity', 'Planned', 'bob.white', 'Oceanic Research Council', 4, '2024-01-01', '2026-12-31', '2027-01-31'),
('PROJ-2023-005', 'Coastal Water Quality Monitoring', 'In Progress', 'john.doe', 'Local Government', 5, '2023-07-20', '2024-11-30', '2024-12-15'),
('PROJ-2023-006', 'Marine Bioactive Compound Discovery', 'On Hold', 'david.green', 'Pharmaceutical Co.', 6, '2023-09-01', '2025-08-31', '2025-09-15'),
('PROJ-2023-007', 'Coral Reef Restoration Techniques', 'Completed', 'grace.hall', 'Environmental Trust', 7, '2022-11-01', '2023-10-31', '2023-11-15'),
('PROJ-2023-008', 'Arctic Ice Edge Ecosystem Study', 'In Progress', 'henry.king', 'International Arctic Council', 8, '2023-02-01', '2025-01-31', '2025-02-15'),
('PROJ-2023-009', 'Riverine Fish Migration Patterns', 'Planned', 'irene.lim', 'National Wildlife Fund', 9, '2024-03-01', '2025-09-30', '2025-10-15'),
('PROJ-2023-010', 'Great Lakes Invasive Species Control', 'In Progress', 'kevin.scott', 'Regional Water Authority', 10, '2023-04-01', '2024-08-31', '2024-09-15'),
('PROJ-2023-011', 'Wetland Carbon Sequestration', 'Completed', 'laura.miller', 'Climate Change Initiative', 11, '2022-06-01', '2023-05-31', '2023-06-15'),
('PROJ-2023-012', 'Intertidal Algae Blooms', 'In Progress', 'mike.taylor', 'Coastal Research Grant', 12, '2023-08-01', '2024-07-31', '2024-08-15'),
('PROJ-2023-013', 'Ocean Upwelling Productivity', 'Planned', 'nancy.clark', 'Oceanographic Society', 13, '2024-02-15', '2026-01-31', '2026-02-15'),
('PROJ-2023-014', 'Submarine Canyon Benthic Fauna', 'In Progress', 'olivia.davis', 'Deep Sea Exploration Fund', 14, '2023-10-01', '2025-03-31', '2025-04-15'),
('PROJ-2023-015', 'Fjord Sediment Contamination', 'Completed', 'peter.evans', 'Environmental Monitoring Agency', 15, '2022-09-01', '2023-08-31', '2023-09-15'),
('PROJ-2023-016', 'Baltic Sea Biodiversity Survey', 'In Progress', 'quinn.fisher', 'Baltic Sea Initiative', 1, '2023-06-01', '2024-05-31', '2024-06-15'),
('PROJ-2023-017', 'South China Sea Coral Health', 'Planned', 'rachel.gonzalez', 'Asian Marine Fund', 16, '2024-04-01', '2026-03-31', '2026-04-15'),
('PROJ-2023-018', 'Caribbean Shark Tracking', 'In Progress', 'john.doe', 'Wildlife Conservation Org', 17, '2023-09-15', '2025-02-28', '2025-03-15'),
('PROJ-2023-019', 'Red Sea Fish Stock Assessment', 'Completed', 'jane.smith', 'Regional Fisheries Org', 18, '2022-12-01', '2023-11-30', '2023-12-15'),
('PROJ-2023-020', 'Black Sea Pollution Impact', 'In Progress', 'alice.jones', 'European Environmental Fund', 19, '2023-07-01', '2024-06-30', '2024-07-15')
ON CONFLICT ("project_id") DO NOTHING;

-- lims.project_persons
INSERT INTO "lims"."project_persons" ("project_id", "person_id", "role") VALUES
('PROJ-2023-001', 'john.doe', 'Principal Investigator'),
('PROJ-2023-001', 'alice.jones', 'Researcher'),
('PROJ-2023-002', 'jane.smith', 'Principal Investigator'),
('PROJ-2023-002', 'emily.black', 'Data Analyst'),
('PROJ-2023-003', 'alice.jones', 'Principal Investigator'),
('PROJ-2023-003', 'charlie.brown', 'Lab Support'),
('PROJ-2023-004', 'bob.white', 'Principal Investigator'),
('PROJ-2023-004', 'david.green', 'Co-Investigator'),
('PROJ-2023-005', 'john.doe', 'Principal Investigator'),
('PROJ-2023-005', 'frank.grey', 'Field Technician'),
('PROJ-2023-006', 'david.green', 'Principal Investigator'),
('PROJ-2023-006', 'grace.hall', 'Lab Scientist'),
('PROJ-2023-007', 'grace.hall', 'Principal Investigator'),
('PROJ-2023-007', 'henry.king', 'Assistant'),
('PROJ-2023-008', 'henry.king', 'Principal Investigator'),
('PROJ-2023-008', 'irene.lim', 'Logistics Coordinator'),
('PROJ-2023-009', 'irene.lim', 'Principal Investigator'),
('PROJ-2023-009', 'kevin.scott', 'IT Support'),
('PROJ-2023-010', 'kevin.scott', 'Principal Investigator'),
('PROJ-2023-010', 'laura.miller', 'QA Lead'),
('PROJ-2023-011', 'laura.miller', 'Principal Investigator'),
('PROJ-2023-011', 'mike.taylor', 'Admin Support'),
('PROJ-2023-012', 'mike.taylor', 'Principal Investigator'),
('PROJ-2023-012', 'nancy.clark', 'Finance Support'),
('PROJ-2023-013', 'nancy.clark', 'Principal Investigator'),
('PROJ-2023-013', 'olivia.davis', 'Purchasing'),
('PROJ-2023-014', 'olivia.davis', 'Principal Investigator'),
('PROJ-2023-014', 'peter.evans', 'Safety Officer'),
('PROJ-2023-015', 'peter.evans', 'Principal Investigator'),
('PROJ-2023-015', 'quinn.fisher', 'Legal Advisor'),
('PROJ-2023-016', 'quinn.fisher', 'Principal Investigator'),
('PROJ-2023-016', 'rachel.gonzalez', 'Communications'),
('PROJ-2023-017', 'rachel.gonzalez', 'Principal Investigator'),
('PROJ-2023-017', 'john.doe', 'Collaborator'),
('PROJ-2023-018', 'john.doe', 'Principal Investigator'),
('PROJ-2023-018', 'jane.smith', 'Collaborator'),
('PROJ-2023-019', 'jane.smith', 'Principal Investigator'),
('PROJ-2023-019', 'alice.jones', 'Collaborator'),
('PROJ-2023-020', 'alice.jones', 'Principal Investigator'),
('PROJ-2023-020', 'bob.white', 'Collaborator')
ON CONFLICT ("project_id", "person_id") DO NOTHING;

-- lab.storage (requires room_id and project_id)
INSERT INTO "lab"."storage" ("storage_id", "room_id", "freezer", "etage", "temperature_c", "box", "box_size_x", "box_size_y", "storage_position_format", "project_id") VALUES
('FRZ-A-01', 'A101', 'Freezer 1', 'Ground', -80, 'Box A1', 10, 10, 'A-01-X-Y', 'PROJ-2023-001'),
('FRZ-A-02', 'A101', 'Freezer 1', 'Ground', -80, 'Box A2', 10, 10, 'A-02-X-Y', 'PROJ-2023-001'),
('FRZ-B-01', 'B202', 'Freezer 2', 'First', -20, 'Box B1', 5, 5, 'B-01-X-Y', 'PROJ-2023-002'),
('FRZ-B-02', 'B202', 'Freezer 2', 'First', -20, 'Box B2', 5, 5, 'B-02-X-Y', 'PROJ-2023-002'),
('FRZ-C-01', 'C303', 'Freezer 3', 'Second', -196, 'Tank C1', 20, 20, 'C-01-X-Y', 'PROJ-2023-003'),
('FRZ-C-02', 'C303', 'Freezer 3', 'Second', -196, 'Tank C2', 20, 20, 'C-02-X-Y', 'PROJ-2023-003'),
('FRZ-D-01', 'D404', 'Freezer 4', 'Third', 4, 'Fridge D1', 8, 8, 'D-01-X-Y', 'PROJ-2023-004'),
('FRZ-D-02', 'D404', 'Freezer 4', 'Third', 4, 'Fridge D2', 8, 8, 'D-02-X-Y', 'PROJ-2023-004'),
('RM-E-01', 'E505', 'Shelf 1', 'Fourth', 20, 'Room E1', 50, 50, 'E-01-X-Y', 'PROJ-2023-005'),
('RM-E-02', 'E505', 'Shelf 2', 'Fourth', 20, 'Room E2', 50, 50, 'E-02-X-Y', 'PROJ-2023-005'),
('FRZ-F-01', 'F606', 'Freezer 5', 'Fifth', -40, 'Box F1', 12, 12, 'F-01-X-Y', 'PROJ-2023-006'),
('FRZ-F-02', 'F606', 'Freezer 5', 'Fifth', -40, 'Box F2', 12, 12, 'F-02-X-Y', 'PROJ-2023-006'),
('FRZ-G-01', 'G707', 'Freezer 6', 'Sixth', -70, 'Box G1', 15, 15, 'G-01-X-Y', 'PROJ-2023-007'),
('FRZ-G-02', 'G707', 'Freezer 6', 'Sixth', -70, 'Box G2', 15, 15, 'G-02-X-Y', 'PROJ-2023-007'),
('FRZ-H-01', 'H808', 'Freezer 7', 'Seventh', -150, 'Tank H1', 25, 25, 'H-01-X-Y', 'PROJ-2023-008'),
('FRZ-H-02', 'H808', 'Freezer 7', 'Seventh', -150, 'Tank H2', 25, 25, 'H-02-X-Y', 'PROJ-2023-008'),
('RM-I-01', 'I909', 'Incubator 1', 'Eighth', 37, 'Rack I1', 10, 10, 'I-01-X-Y', 'PROJ-2023-009'),
('RM-I-02', 'I909', 'Incubator 2', 'Eighth', 30, 'Rack I2', 10, 10, 'I-02-X-Y', 'PROJ-2023-009'),
('FRZ-J-01', 'J101', 'Freezer 8', 'Ground', -80, 'Box J1', 10, 10, 'J-01-X-Y', 'PROJ-2023-010'),
('FRZ-J-02', 'J101', 'Freezer 8', 'Ground', -80, 'Box J2', 10, 10, 'J-02-X-Y', 'PROJ-2023-010')
ON CONFLICT ("storage_id") DO NOTHING;

-- lims.cruises
INSERT INTO "lims"."cruises" ("cruise_id", "project_id", "vessel_id", "status_id", "region_id", "ecosystem_id", "capitaine_contact_id", "chief_scientist_person_id", "start_date", "end_date", "together_with_contact_id") VALUES
('CRU-2023-001', 'PROJ-2023-001', 'RV_Investigator', 'Completed', 'NA_Atl', 'OpenOcean', 'ext_uni_a', 'john.doe', '2023-02-01', '2023-03-01', 'ext_gov_b'),
('CRU-2023-002', 'PROJ-2023-002', 'RV_Explorer', 'Completed', 'EU_Med', 'Coastal', 'ext_gov_b', 'jane.smith', '2023-04-10', '2023-05-10', 'ext_uni_a'),
('CRU-2023-003', 'PROJ-2023-003', 'FV_Seagull', 'In Progress', 'AS_Pac', 'Coastal', 'ext_comp_c', 'alice.jones', '2023-06-01', '2023-07-01', 'ext_comp_f'),
('CRU-2023-004', 'PROJ-2023-004', 'RV_Discovery', 'Planned', 'SA_Atl', 'DeepSea', 'ext_uni_d', 'bob.white', '2024-02-01', '2024-03-15', 'ext_uni_m'),
('CRU-2023-005', 'PROJ-2023-005', 'RV_Oceanus', 'In Progress', 'NA_Atl', 'Coastal', 'ext_gov_e', 'john.doe', '2023-08-01', '2023-09-01', 'ext_gov_h'),
('CRU-2023-006', 'PROJ-2023-006', 'RV_Pioneer', 'On Hold', 'AF_Ind', 'OpenOcean', 'ext_comp_f', 'david.green', '2023-10-01', '2023-11-01', 'ext_comp_o'),
('CRU-2023-007', 'PROJ-2023-007', 'RV_Navigator', 'Completed', 'OC_Pac', 'CoralReef', 'ext_uni_g', 'grace.hall', '2022-12-01', '2023-01-01', 'ext_comp_i'),
('CRU-2023-008', 'PROJ-2023-008', 'RV_Challenger', 'In Progress', 'AR_Arc', 'Polar', 'ext_uni_j', 'henry.king', '2023-03-01', '2023-04-01', 'ext_gov_k'),
('CRU-2023-009', 'PROJ-2023-009', 'RV_Horizon', 'Planned', 'EU_Nor', 'Estuary', 'ext_gov_k', 'irene.lim', '2024-04-01', '2024-05-01', 'ext_uni_p'),
('CRU-2023-010', 'PROJ-2023-010', 'FV_Bluefin', 'In Progress', 'AS_Ind', 'Lake', 'ext_comp_l', 'kevin.scott', '2023-05-01', '2023-06-01', 'ext_comp_r'),
('CRU-2023-011', 'PROJ-2023-011', 'RV_Voyager', 'Completed', 'SA_Pac', 'Wetland', 'ext_uni_m', 'laura.miller', '2022-07-01', '2022-08-01', 'ext_uni_s'),
('CRU-2023-012', 'PROJ-2023-012', 'RV_Sentinel', 'In Progress', 'AF_Atl', 'Intertidal', 'ext_gov_n', 'mike.taylor', '2023-09-01', '2023-10-01', 'ext_gov_t'),
('CRU-2023-013', 'PROJ-2023-013', 'FV_Neptune', 'Planned', 'OC_Ind', 'UpwellingZone', 'ext_comp_o', 'nancy.clark', '2024-03-01', '2024-04-01', 'ext_uni_a'),
('CRU-2023-014', 'PROJ-2023-014', 'RV_Aurora', 'In Progress', 'AN_Ant', 'SubmarineCanyon', 'ext_uni_p', 'olivia.davis', '2023-11-01', '2023-12-01', 'ext_gov_b'),
('CRU-2023-015', 'PROJ-2023-015', 'FV_Pelican', 'Completed', 'EU_Bal', 'Fjord', 'ext_gov_q', 'peter.evans', '2022-10-01', '2022-11-01', 'ext_comp_c'),
('CRU-2023-016', 'PROJ-2023-016', 'RV_Global', 'In Progress', 'AS_Sou', 'IceEdge', 'ext_comp_r', 'quinn.fisher', '2023-07-01', '2023-08-01', 'ext_uni_d'),
('CRU-2023-017', 'PROJ-2023-017', 'FV_Starfish', 'Planned', 'NA_Car', 'Lagoon', 'ext_uni_s', 'rachel.gonzalez', '2024-05-01', '2024-06-01', 'ext_gov_e'),
('CRU-2023-018', 'PROJ-2023-018', 'RV_Hydro', 'In Progress', 'AF_Red', 'OpenOcean', 'ext_gov_t', 'john.doe', '2023-10-15', '2023-11-15', 'ext_comp_f'),
('CRU-2023-019', 'PROJ-2023-019', 'RV_Investigator', 'Completed', 'SA_Car', 'Coastal', 'ext_uni_a', 'jane.smith', '2022-12-10', '2023-01-10', 'ext_gov_b'),
('CRU-2023-020', 'PROJ-2023-020', 'RV_Explorer', 'In Progress', 'EU_Bla', 'DeepSea', 'ext_gov_b', 'alice.jones', '2023-08-10', '2023-09-10', 'ext_uni_a')
ON CONFLICT ("cruise_id") DO NOTHING;

-- lims.workflows
INSERT INTO "lims"."workflows" ("workflow_id", "workflow_name") VALUES
('WF-DNA-Extraction', 'Standard DNA Extraction Workflow'),
('WF-RNA-Extraction', 'RNA Extraction and QC Workflow'),
('WF-Library-Prep', 'Illumina Library Preparation Workflow'),
('WF-Sequencing', 'Next-Gen Sequencing Run Workflow'),
('WF-Bioinfo-Analysis', 'Bioinformatics Data Analysis Workflow'),
('WF-Sample-Reception', 'Sample Reception and Initial Processing'),
('WF-Fish-Dissection', 'Fish Dissection and Tissue Sampling'),
('WF-Water-Filtration', 'Water Sample Filtration and Preservation'),
('WF-Sediment-Processing', 'Sediment Sample Processing'),
('WF-Otolith-Aging', 'Otolith Preparation and Age Reading'),
('WF-PCR-Amplification', 'PCR Amplification and Gel QC'),
('WF-qPCR-Quantification', 'qPCR Absolute Quantification'),
('WF-Nanodrop-QC', 'Nanodrop Quality Control'),
('WF-Qubit-QC', 'Qubit Quality Control'),
('WF-Tapestation-QC', 'Tapestation Quality Control'),
('WF-Data-Archiving', 'Raw Data Archiving and Metadata Creation'),
('WF-Report-Generation', 'Project Report Generation'),
('WF-Sample-Shipping', 'Sample Shipping to External Labs'),
('WF-Equipment-Maintenance', 'Equipment Maintenance and Calibration'),
('WF-Reagent-Management', 'Reagent Inventory and Expiry Management')
ON CONFLICT ("workflow_id") DO NOTHING;

-- lims.sop
INSERT INTO "lims"."sop" ("sop_id", "title", "sop_id_origin", "version", "author_person_id", "reviewer1_person_id", "reviewer2_person_id", "date_realise", "sop_protocol") VALUES
('DNA-EXT-001_v10', 'Genomic DNA Extraction from Fish Tissue', 'DNA-EXT-001', '1.0', 'jane.smith', 'john.doe', 'david.green', '2022-01-01', 'Detailed protocol for DNA extraction...'),
('RNA-EXT-002_v11', 'Total RNA Isolation from Plankton', 'RNA-EXT-002', '1.1', 'alice.jones', 'jane.smith', 'emily.black', '2022-03-15', 'Protocol for RNA isolation from small organisms...'),
('LIB-PREP-003_v20', 'Illumina DNA Library Preparation', 'LIB-PREP-003', '2.0', 'john.doe', 'bob.white', 'grace.hall', '2022-05-20', 'Standard protocol for sequencing library prep...'),
('SEQ-RUN-004_v10', 'MiSeq Sequencing Run Setup', 'SEQ-RUN-004', '1.0', 'bob.white', 'john.doe', 'david.green', '2022-07-01', 'Instructions for setting up a MiSeq run...'),
('BIOINFO-005_v10', '16S rRNA Gene Sequence Analysis', 'BIOINFO-005', '1.0', 'emily.black', 'bob.white', 'john.doe', '2022-09-10', 'Bioinformatics pipeline for 16S data...'),
('SAMPLE-REC-006_v10', 'Sample Reception and Logging', 'SAMPLE-REC-006', '1.0', 'charlie.brown', 'jane.smith', 'alice.jones', '2022-11-01', 'Procedure for receiving and logging samples...'),
('FISH-DIS-007_v10', 'Fish Dissection for Tissue Sampling', 'FISH-DIS-007', '1.0', 'frank.grey', 'alice.jones', 'charlie.brown', '2023-01-05', 'Standard procedure for fish dissection...'),
('WATER-FIL-008_v10', 'Water Sample Filtration', 'WATER-FIL-008', '1.0', 'grace.hall', 'frank.grey', 'henry.king', '2023-03-01', 'Protocol for filtering water samples...'),
('SED-PROC-009_v10', 'Sediment Core Processing', 'SED-PROC-009', '1.0', 'henry.king', 'grace.hall', 'irene.lim', '2023-05-10', 'Processing steps for sediment cores...'),
('OTOLITH-010_v10', 'Otolith Preparation and Sectioning', 'OTOLITH-010', '1.0', 'irene.lim', 'henry.king', 'kevin.scott', '2023-07-01', 'Detailed steps for otolith preparation...'),
('PCR-AMP-011_v10', 'Standard PCR Amplification', 'PCR-AMP-011', '1.0', 'kevin.scott', 'irene.lim', 'laura.miller', '2023-09-01', 'General PCR protocol...'),
('QPCR-012_v10', 'qPCR Absolute Quantification Protocol', 'QPCR-012', '1.0', 'laura.miller', 'kevin.scott', 'mike.taylor', '2023-11-01', 'Protocol for quantitative PCR...'),
('NANODROP-013_v10', 'Nanodrop QC for Nucleic Acids', 'NANODROP-013', '1.0', 'mike.taylor', 'laura.miller', 'nancy.clark', '2024-01-01', 'Nanodrop usage and data interpretation...'),
('QUBIT-014_v10', 'Qubit Fluorometer DNA/RNA Quantification', 'QUBIT-014', '1.0', 'nancy.clark', 'mike.taylor', 'olivia.davis', '2024-03-01', 'Qubit system operation...'),
('TAPESTATION-015_v10', 'Tapestation DNA/RNA Sizing & Quality', 'TAPESTATION-015', '1.0', 'olivia.davis', 'nancy.clark', 'peter.evans', '2024-05-01', 'Tapestation system operation...'),
('DATA-ARCH-016_v10', 'Raw Sequencing Data Archiving', 'DATA-ARCH-016', '1.0', 'peter.evans', 'olivia.davis', 'quinn.fisher', '2024-07-01', 'Procedure for archiving raw data...'),
('REPORT-GEN-017_v10', 'Project Report Generation Guidelines', 'REPORT-GEN-017', '1.0', 'quinn.fisher', 'peter.evans', 'rachel.gonzalez', '2024-09-01', 'Guidelines for generating project reports...'),
('SAMPLE-SHIP-018_v10', 'External Sample Shipping Protocol', 'SAMPLE-SHIP-018', '1.0', 'rachel.gonzalez', 'quinn.fisher', 'john.doe', '2024-11-01', 'Protocol for shipping samples safely...'),
('EQUIP-MAINT-019_v10', 'Lab Equipment Preventative Maintenance', 'EQUIP-MAINT-019', '1.0', 'john.doe', 'rachel.gonzalez', 'jane.smith', '2025-01-01', 'Routine maintenance for lab equipment...'),
('REAGENT-MGMT-020_v10', 'Reagent Inventory Management', 'REAGENT-MGMT-020', '1.0', 'jane.smith', 'john.doe', 'alice.jones', '2025-03-01', 'Managing reagents and expiry dates...')
ON CONFLICT ("sop_id") DO NOTHING;

-- lims.workflow_steps
INSERT INTO "lims"."workflow_steps" ("workflow_id", "step_number", "step_name", "sop_id", "workflow_status_id", "target_table_name") VALUES
('WF-DNA-Extraction', 1, 'Tissue Homogenization', 'DNA-EXT-001_v10', 'Completed', 'lab.extraction'),
('WF-DNA-Extraction', 2, 'Lysis and Proteinase K Digestion', 'DNA-EXT-001_v10', 'Completed', 'lab.extraction'),
('WF-DNA-Extraction', 3, 'DNA Purification', 'DNA-EXT-001_v10', 'Completed', 'lab.extraction'),
('WF-DNA-Extraction', 4, 'DNA Elution', 'DNA-EXT-001_v10', 'Completed', 'lab.dna'),
('WF-DNA-Extraction', 5, 'DNA QC (Nanodrop)', 'NANODROP-013_v10', 'Completed', 'lab.nanodrop'),
('WF-DNA-Extraction', 6, 'DNA QC (Qubit)', 'QUBIT-014_v10', 'Completed', 'lab.qubit'),
('WF-DNA-Extraction', 7, 'DNA QC (Tapestation)', 'TAPESTATION-015_v10', 'Completed', 'lab.tapestation'),
('WF-Sequencing', 1, 'Library Normalization', 'LIB-PREP-003_v20', 'Completed', 'lab.library'),
('WF-Sequencing', 2, 'Pooling Libraries', 'LIB-PREP-003_v20', 'Completed', 'lab.library'),
('WF-Sequencing', 3, 'Sequencer Loading', 'SEQ-RUN-004_v10', 'Completed', 'lab.sequencing'),
('WF-Sequencing', 4, 'Sequencing Run', 'SEQ-RUN-004_v10', 'Completed', 'lab.sequencing'),
('WF-Bioinfo-Analysis', 1, 'Raw Data QC', 'BIOINFO-005_v10', 'Completed', 'bioinformatics.analysis_runs'),
('WF-Bioinfo-Analysis', 2, 'Read Trimming and Filtering', 'BIOINFO-005_v10', 'Completed', 'bioinformatics.analysis_runs'),
('WF-Bioinfo-Analysis', 3, 'Taxonomic Assignment', 'BIOINFO-005_v10', 'Completed', 'bioinformatics.edna_assignments'),
('WF-Bioinfo-Analysis', 4, 'Data Visualization', 'BIOINFO-005_v10', 'Completed', 'bioinformatics.analysis_runs'),
('WF-Sample-Reception', 1, 'Sample Check-in', 'SAMPLE-REC-006_v10', 'Completed', 'lab.samples'),
('WF-Sample-Reception', 2, 'Initial Storage', 'SAMPLE-REC-006_v10', 'Completed', 'lab.storage_log'),
('WF-Fish-Dissection', 1, 'Fish Measurement', 'FISH-DIS-007_v10', 'Completed', 'lab.fish'),
('WF-Fish-Dissection', 2, 'Tissue Removal', 'FISH-DIS-007_v10', 'Completed', 'lab.tissue'),
('WF-Otolith-Aging', 1, 'Otolith Extraction', 'OTOLITH-010_v10', 'Completed', 'lab.otoliths')
ON CONFLICT ("step_id") DO NOTHING;

-- lims.equipment
INSERT INTO "lims"."equipment" ("equipment_id", "equipment_name", "room_id", "lot", "mobility", "date_maintenance") VALUES
('EQ-SEQ-001', 'Illumina MiSeq', 'L303', 'LOT12345', 'Fixed', '2024-06-01'),
('EQ-PCR-002', 'Applied Biosystems Thermal Cycler', 'T202', 'LOT67890', 'Fixed', '2024-05-15'),
('EQ-QC-003', 'Nanodrop OneC', 'K202', 'LOT11223', 'Mobile', '2024-07-01'),
('EQ-QC-004', 'Qubit 4 Fluorometer', 'K202', 'LOT44556', 'Mobile', '2024-07-05'),
('EQ-QC-005', 'Agilent Tapestation 4200', 'K202', 'LOT77889', 'Mobile', '2024-06-20'),
('EQ-FREEZER-006', '-80C Freezer Thermo', 'N505', 'LOT99001', 'Fixed', '2024-04-01'),
('EQ-FREEZER-007', '-20C Freezer Labcold', 'N505', 'LOT22334', 'Fixed', '2024-04-05'),
('EQ-FRIDGE-008', '4C Fridge Panasonic', 'N505', 'LOT55667', 'Fixed', '2024-04-10'),
('EQ-HOOD-009', 'Laminar Flow Hood Esco', 'A101', 'LOT88990', 'Fixed', '2024-03-01'),
('EQ-BALANCE-010', 'Analytical Balance Mettler Toledo', 'A101', 'LOT10112', 'Mobile', '2024-02-15'),
('EQ-PHMETER-011', 'pH Meter Hanna', 'A101', 'LOT13141', 'Mobile', '2024-01-20'),
('EQ-CENTRIFUGE-012', 'Centrifuge Eppendorf', 'B202', 'LOT15161', 'Mobile', '2024-05-01'),
('EQ-WATERBATH-013', 'Water Bath Fisher Scientific', 'B202', 'LOT17181', 'Fixed', '2024-04-25'),
('EQ-SHAKER-014', 'Orbital Shaker Labnet', 'B202', 'LOT19202', 'Mobile', '2024-03-20'),
('EQ-MICROSCOPE-015', 'Compound Microscope Olympus', 'D404', 'LOT21223', 'Fixed', '2024-06-10'),
('EQ-INCUBATOR-016', 'CO2 Incubator Binder', 'I909', 'LOT23245', 'Fixed', '2024-05-05'),
('EQ-AUTOCLAVE-017', 'Autoclave Priorclave', 'S101', 'LOT25267', 'Fixed', '2024-07-10'),
('EQ-FREEZEDRYER-018', 'Freeze Dryer Labconco', 'S101', 'LOT27289', 'Fixed', '2024-06-15'),
('EQ-SONICATOR-019', 'Ultrasonic Processor Qsonica', 'S101', 'LOT29301', 'Mobile', '2024-05-20'),
('EQ-ROBOT-020', 'Automated Liquid Handler Tecan', 'L303', 'LOT31323', 'Fixed', '2024-04-15')
ON CONFLICT ("equipment_id") DO NOTHING;

-- lims.suppliers
INSERT INTO "lims"."suppliers" ("supplier_id", "supplier_name", "address", "contact_person", "phone", "mail") VALUES
('SUP-THERMO', 'Thermo Fisher Scientific', '168 3rd Ave, Waltham, MA', 'Sarah Chen', '781-622-1000', 'info@thermofisher.com'),
('SUP-QIAGEN', 'QIAGEN', '19300 Germantown Rd, Germantown, MD', 'David Kim', '800-426-2122', 'support@qiagen.com'),
('SUP-ILLUMINA', 'Illumina Inc.', '5200 Illumina Way, San Diego, CA', 'Emily White', '858-202-4500', 'sales@illumina.com'),
('SUP-SIGMA', 'Sigma-Aldrich', '3050 Spruce St, St. Louis, MO', 'Frank Green', '800-325-3010', 'custserv@sigmaaldrich.com'),
('SUP-VWR', 'VWR International', '100 Matsonford Rd, Radnor, PA', 'Grace Hall', '800-932-5000', 'info@vwr.com'),
('SUP-FISHER', 'Fisher Scientific', '300 Industry Dr, Pittsburgh, PA', 'Henry King', '800-766-7000', 'contact@fishersci.com'),
('SUP-AGILENT', 'Agilent Technologies', '5301 Stevens Creek Blvd, Santa Clara, CA', 'Irene Lim', '800-227-9770', 'support@agilent.com'),
('SUP-EPPENDORF', 'Eppendorf AG', '22334 Hamburg, Germany', 'Jack Miller', '+49 40 53801-0', 'info@eppendorf.com'),
('SUP-BIO-RAD', 'Bio-Rad Laboratories', '1000 Alfred Nobel Dr, Hercules, CA', 'Karen Nelson', '800-424-6723', 'sales@bio-rad.com'),
('SUP-PROMEGA', 'Promega Corporation', '2800 Woods Hollow Rd, Madison, WI', 'Liam Owens', '800-356-9526', 'techserv@promega.com'),
('SUP-ROCHE', 'Roche Diagnostics', '9115 Hague Rd, Indianapolis, IN', 'Mia Perez', '800-428-5074', 'info@roche.com'),
('SUP-LONZA', 'Lonza Group Ltd.', 'Muenchensteinerstrasse 38, Basel, Switzerland', 'Noah Quinn', '+41 61 316 81 11', 'info@lonza.com'),
('SUP-CORNING', 'Corning Inc.', '1 Riverfront Plaza, Corning, NY', 'Olivia Roberts', '800-492-1110', 'support@corning.com'),
('SUP-SARSTEDT', 'Sarstedt AG & Co. KG', 'Sarstedtstr. 1, Nümbrecht, Germany', 'Peter Smith', '+49 2293 305-0', 'info@sarstedt.com'),
('SUP-MILLIPORE', 'MilliporeSigma', '290 Concord Rd, Billerica, MA', 'Quinn Taylor', '800-645-5476', 'support@milliporesigma.com'),
('SUP-PERKIN', 'PerkinElmer Inc.', '940 Winter St, Waltham, MA', 'Rachel Vance', '800-762-4000', 'info@perkinelmer.com'),
('SUP-WATERS', 'Waters Corporation', '34 Maple St, Milford, MA', 'Sam White', '800-252-4752', 'support@waters.com'),
('SUP-ZEISS', 'Carl Zeiss AG', 'Carl-Zeiss-Straße 22, Oberkochen, Germany', 'Tina Young', '+49 7364 20-0', 'info@zeiss.com'),
('SUP-LEICA', 'Leica Microsystems', 'Ernst-Leitz-Straße 17-37, Wetzlar, Germany', 'Ursula Zeller', '+49 6441 29-0', 'info@leica-microsystems.com'),
('SUP-OLYMPUS', 'Olympus Corporation', 'Shinjuku Monolith, 3-1 Nishi-Shinjuku 2-chome, Shinjuku-ku, Tokyo, Japan', 'Victor Adams', '+81 3-3340-2111', 'info@olympus-global.com')
ON CONFLICT ("supplier_id") DO NOTHING;

-- lims.inventory_items
INSERT INTO "lims"."inventory_items" ("item_id", "item_name", "category_id", "unit_id") VALUES
('ITEM-DNA-KIT-001', 'DNA Extraction Kit', 'Kit', 'unit'), -- Assuming 'unit' is a valid unit_id
('ITEM-PCR-MASTER-002', 'PCR Master Mix', 'Chemical', 'ml'),
('ITEM-PIPETTE-TIP-003', 'Filter Pipette Tips 1000ul', 'Consumable', 'unit'),
('ITEM-AGAROSE-004', 'Agarose LE', 'Chemical', 'g'),
('ITEM-SYBR-005', 'SYBR Green Master Mix', 'Chemical', 'ml'),
('ITEM-PLATE-96', '96-Well PCR Plate', 'Consumable', 'unit'),
('ITEM-TUBE-1.5', '1.5ml Microcentrifuge Tubes', 'Consumable', 'unit'),
('ITEM-GLOVES', 'Nitrile Gloves (Box)', 'Safety', 'unit'),
('ITEM-ETHANOL', 'Ethanol 99.5%', 'Chemical', 'l'),
('ITEM-WATER-NUC', 'Nuclease-Free Water', 'Chemical', 'ml'),
('ITEM-BUFFER-TE', 'TE Buffer pH 8.0', 'Chemical', 'ml'),
('ITEM-ENZYME-REST', 'Restriction Enzyme EcoRI', 'Chemical', 'unit'),
('ITEM-LADDER-DNA', 'DNA Ladder 1kb', 'Chemical', 'ul'),
('ITEM-PRIMER-FWD', 'Universal Primer FWD', 'Chemical', 'ng_ul'),
('ITEM-PRIMER-REV', 'Universal Primer REV', 'Chemical', 'ng_ul'),
('ITEM-FILTER-0.22', 'Syringe Filter 0.22µm', 'Consumable', 'unit'),
('ITEM-CONICAL-50', '50ml Conical Tubes', 'Consumable', 'unit'),
('ITEM-SCALPEL', 'Disposable Scalpel', 'FieldSupply', 'unit'),
('ITEM-FORMALIN', 'Formalin 10%', 'Chemical', 'l'),
('ITEM-RNALATER', 'RNAlater Solution', 'Chemical', 'ml')
ON CONFLICT ("item_id") DO NOTHING;

-- lims.orders
INSERT INTO "lims"."orders" ("fi_order_nr", "item_id", "category_id", "order_date", "price", "quantity", "project_id", "supplier_id", "status_id") VALUES
('ORD-2023-001', 'ITEM-DNA-KIT-001', 'Kit', '2023-01-05', 500.00, 5, 'PROJ-2023-001', 'SUP-QIAGEN', 'Completed'),
('ORD-2023-002', 'ITEM-PCR-MASTER-002', 'Chemical', '2023-01-10', 120.50, 10, 'PROJ-2023-001', 'SUP-THERMO', 'Completed'),
('ORD-2023-003', 'ITEM-PIPETTE-TIP-003', 'Consumable', '2023-01-15', 30.00, 20, 'PROJ-2023-002', 'SUP-VWR', 'Completed'),
('ORD-2023-004', 'ITEM-AGAROSE-004', 'Chemical', '2023-02-01', 80.00, 2, 'PROJ-2023-003', 'SUP-SIGMA', 'Completed'),
('ORD-2023-005', 'ITEM-SYBR-005', 'Chemical', '2023-02-05', 250.00, 3, 'PROJ-2023-004', 'SUP-THERMO', 'In Progress'),
('ORD-2023-006', 'ITEM-PLATE-96', 'Consumable', '2023-02-10', 15.00, 50, 'PROJ-2023-005', 'SUP-VWR', 'Completed'),
('ORD-2023-007', 'ITEM-TUBE-1.5', 'Consumable', '2023-02-15', 10.00, 100, 'PROJ-2023-006', 'SUP-FISHER', 'In Progress'),
('ORD-2023-008', 'ITEM-GLOVES', 'Safety', '2023-03-01', 25.00, 10, 'PROJ-2023-007', 'SUP-VWR', 'Completed'),
('ORD-2023-009', 'ITEM-ETHANOL', 'Chemical', '2023-03-05', 40.00, 5, 'PROJ-2023-008', 'SUP-SIGMA', 'In Progress'),
('ORD-2023-010', 'ITEM-WATER-NUC', 'Chemical', '2023-03-10', 50.00, 10, 'PROJ-2023-009', 'SUP-THERMO', 'Planned'),
('ORD-2023-011', 'ITEM-BUFFER-TE', 'Chemical', '2023-03-15', 35.00, 5, 'PROJ-2023-010', 'SUP-SIGMA', 'In Progress'),
('ORD-2023-012', 'ITEM-ENZYME-REST', 'Chemical', '2023-04-01', 300.00, 1, 'PROJ-2023-011', 'SUP-PROMEGA', 'Completed'),
('ORD-2023-013', 'ITEM-LADDER-DNA', 'Chemical', '2023-04-05', 75.00, 2, 'PROJ-2023-012', 'SUP-BIO-RAD', 'In Progress'),
('ORD-2023-014', 'ITEM-PRIMER-FWD', 'Chemical', '2023-04-10', 90.00, 5, 'PROJ-2023-013', 'SUP-THERMO', 'Planned'),
('ORD-2023-015', 'ITEM-PRIMER-REV', 'Chemical', '2023-04-15', 90.00, 5, 'PROJ-2023-014', 'SUP-THERMO', 'In Progress'),
('ORD-2023-016', 'ITEM-FILTER-0.22', 'Consumable', '2023-05-01', 20.00, 20, 'PROJ-2023-015', 'SUP-VWR', 'Completed'),
('ORD-2023-017', 'ITEM-CONICAL-50', 'Consumable', '2023-05-05', 12.00, 50, 'PROJ-2023-016', 'SUP-FISHER', 'In Progress'),
('ORD-2023-018', 'ITEM-SCALPEL', 'FieldSupply', '2023-05-10', 5.00, 10, 'PROJ-2023-017', 'SUP-VWR', 'Planned'),
('ORD-2023-019', 'ITEM-FORMALIN', 'Chemical', '2023-05-15', 60.00, 3, 'PROJ-2023-018', 'SUP-SIGMA', 'In Progress'),
('ORD-2023-020', 'ITEM-RNALATER', 'Chemical', '2023-06-01', 150.00, 2, 'PROJ-2023-019', 'SUP-QIAGEN', 'Completed')
ON CONFLICT ("fi_order_nr") DO NOTHING;

-- lims.reagents
INSERT INTO "lims"."reagents" ("reagent_id", "reagent_complete_name", "category_id", "lot", "storage_id", "storage_position", "status_id", "reception_date", "expire_date", "order_id", "project_id", "quantity_available", "quantity_unit_id") VALUES
('REAG-DNA-KIT-001', 'QIAGEN DNeasy Blood & Tissue Kit', 'Kit', 'LOT12345', 'FRZ-A-01', '1', 'Received', '2023-01-10', '2025-01-10', 'ORD-2023-001', 'PROJ-2023-001', 5, 'unit'),
('REAG-PCR-MM-002', 'Thermo Scientific DreamTaq Green PCR Master Mix', 'Chemical', 'LOT67890', 'FRZ-B-01', '2', 'Received', '2023-01-15', '2024-07-15', 'ORD-2023-002', 'PROJ-2023-001', 10, 'ml'),
('REAG-SYBR-003', 'Applied Biosystems SYBR Green Master Mix', 'Chemical', 'LOT11223', 'FRZ-B-01', '3', 'Received', '2023-02-10', '2024-08-10', 'ORD-2023-005', 'PROJ-2023-004', 3, 'ml'),
('REAG-ETHANOL-004', 'Sigma-Aldrich Ethanol 99.5%', 'Chemical', 'LOT44556', 'RM-E-01', '10', 'Received', '2023-03-10', '2026-03-10', 'ORD-2023-009', 'PROJ-2023-008', 5, 'l'),
('REAG-WATER-005', 'Nuclease-Free Water Ambion', 'Chemical', 'LOT77889', 'RM-E-01', '11', 'Received', '2023-03-15', '2025-03-15', 'ORD-2023-010', 'PROJ-2023-009', 10, 'ml'),
('REAG-TE-006', 'TE Buffer pH 8.0 Thermo Scientific', 'Chemical', 'LOT99001', 'RM-E-01', '12', 'Received', '2023-03-20', '2025-09-20', 'ORD-2023-011', 'PROJ-2023-010', 5, 'ml'),
('REAG-ECORI-007', 'Restriction Enzyme EcoRI Promega', 'Chemical', 'LOT22334', 'FRZ-B-01', '4', 'Received', '2023-04-05', '2024-10-05', 'ORD-2023-012', 'PROJ-2023-011', 1, 'unit'),
('REAG-LADDER-008', 'DNA Ladder 1kb Bio-Rad', 'Chemical', 'LOT55667', 'FRZ-B-01', '5', 'Received', '2023-04-10', '2024-04-10', 'ORD-2023-013', 'PROJ-2023-012', 2, 'ul'),
('REAG-PRIMER-FWD-009', 'Universal Primer FWD Custom', 'Chemical', 'LOT88990', 'FRZ-C-01', '1', 'Received', '2023-04-15', '2024-04-15', 'ORD-2023-014', 'PROJ-2023-013', 5, 'ng_ul'),
('REAG-PRIMER-REV-010', 'Universal Primer REV Custom', 'Chemical', 'LOT10112', 'FRZ-C-01', '2', 'Received', '2023-04-20', '2024-04-20', 'ORD-2023-015', 'PROJ-2023-014', 5, 'ng_ul'),
('REAG-FORMALIN-011', 'Formalin 10% Sigma-Aldrich', 'Chemical', 'LOT13141', 'RM-E-01', '13', 'Received', '2023-05-20', '2026-05-20', 'ORD-2023-019', 'PROJ-2023-018', 3, 'l'),
('REAG-RNALATER-012', 'RNAlater Solution QIAGEN', 'Chemical', 'LOT15161', 'FRZ-A-01', '6', 'Received', '2023-06-05', '2025-06-05', 'ORD-2023-020', 'PROJ-2023-019', 2, 'ml'),
('REAG-AGAROSE-013', 'Agarose LE Promega', 'Chemical', 'LOT17181', 'RM-E-01', '14', 'Received', '2023-02-05', '2025-02-05', 'ORD-2023-004', 'PROJ-2023-003', 2, 'g'),
('REAG-KIT-014', 'Library Prep Kit Illumina', 'Kit', 'LOT19202', 'FRZ-C-01', '3', 'Received', '2023-07-01', '2024-12-31', NULL, 'PROJ-2023-001', 1, 'unit'),
('REAG-ENZYME-015', 'DNA Polymerase NEB', 'Chemical', 'LOT21223', 'FRZ-B-01', '7', 'Received', '2023-08-01', '2024-11-01', NULL, 'PROJ-2023-002', 1, 'unit'),
('REAG-BUFFER-016', 'Loading Dye Bio-Rad', 'Chemical', 'LOT23245', 'RM-E-01', '15', 'Received', '2023-09-01', '2025-03-01', NULL, 'PROJ-2023-003', 10, 'ml'),
('REAG-ANTIBODY-017', 'Primary Antibody Abcam', 'Chemical', 'LOT25267', 'FRZ-D-01', '1', 'Received', '2023-10-01', '2024-09-01', NULL, 'PROJ-2023-004', 1, 'unit'),
('REAG-MEDIA-018', 'Cell Culture Media Gibco', 'Media', 'LOT27289', 'RM-I-01', '1', 'Received', '2023-11-01', '2024-05-01', NULL, 'PROJ-2023-009', 5, 'l'),
('REAG-PLASTICWARE-019', 'Sterile Petri Dishes Sarstedt', 'Plasticware', 'LOT29301', 'RM-E-02', '1', 'Received', '2023-12-01', '2026-12-01', NULL, 'PROJ-2023-010', 20, 'unit'),
('REAG-GLASSWARE-020', 'Beakers Pyrex', 'Glassware', 'LOT31323', 'RM-E-02', '2', 'Received', '2024-01-01', '2030-01-01', NULL, 'PROJ-2023-011', 10, 'unit')
ON CONFLICT ("reagent_id") DO NOTHING;

-- lims.publication_type
INSERT INTO "lims"."publication_type" ("publication_type_id", "notes") VALUES
('JournalArticle', 'Peer-reviewed journal article'),
('ConferencePaper', 'Conference proceedings paper'),
('Thesis', 'Master or PhD thesis'),
('Report', 'Technical report'),
('BookChapter', 'Chapter in an edited book'),
('Poster', 'Conference poster presentation'),
('Preprint', 'Pre-publication manuscript'),
('DataRelease', 'Dataset release publication'),
('SoftwareRelease', 'Software release publication'),
('Patent', 'Patent application or granted patent')
ON CONFLICT ("publication_type_id") DO NOTHING;

-- lims.publications (using generate_publication_id trigger)
INSERT INTO "lims"."publications" ("publication_type_id", "project_id", "title", "journal", "volume", "issue", "pages", "doi", "date_publication", "date_submission", "first_author_person_id", "corresponding_author_person_id") VALUES
('JournalArticle', 'PROJ-2023-001', 'Genomic insights into Atlantic Cod adaptation', 'Nature Ecology & Evolution', '7', '1', '1-10', '10.1038/s41559-023-02000-x', '2023-01-20', '2022-08-01', 'john.doe', 'john.doe'),
('ConferencePaper', 'PROJ-2023-002', 'Acoustic monitoring of dolphin behavior', 'Proc. Int. Marine Mammal Conf.', '2023', NULL, '55-60', NULL, '2023-05-25', '2023-03-01', 'jane.smith', 'jane.smith'),
('JournalArticle', 'PROJ-2023-003', 'Improved growth rates in farmed tiger prawns', 'Aquaculture Journal', '15', '3', '112-120', '10.1016/j.aqua.2023.01.001', '2023-06-10', '2023-02-15', 'alice.jones', 'alice.jones'),
('Report', 'PROJ-2023-005', 'Annual Coastal Water Quality Report 2023', NULL, NULL, NULL, NULL, NULL, '2023-12-01', '2023-11-01', 'john.doe', 'john.doe'),
('Thesis', 'PROJ-2023-007', 'Coral Restoration Success in the Pacific', 'PhD Thesis, University of Oceanography', NULL, NULL, '1-200', NULL, '2023-11-01', '2023-09-01', 'grace.hall', 'grace.hall'),
('JournalArticle', 'PROJ-2023-008', 'Microbial communities in Arctic sea ice', 'Polar Biology', '47', '2', '201-210', '10.1007/s00300-023-01111-1', '2024-01-15', '2023-07-01', 'henry.king', 'henry.king'),
('ConferencePaper', 'PROJ-2023-010', 'Genetic markers for invasive carp in Great Lakes', 'Proc. Freshwater Biology Conf.', '2024', NULL, '10-15', NULL, '2024-06-20', '2024-04-01', 'kevin.scott', 'kevin.scott'),
('Report', 'PROJ-2023-011', 'Carbon Sequestration Potential of Coastal Wetlands', NULL, NULL, NULL, NULL, NULL, '2023-06-01', '2023-05-01', 'laura.miller', 'laura.miller'),
('JournalArticle', 'PROJ-2023-012', 'Factors influencing intertidal algal blooms', 'Journal of Phycology', '59', '4', '401-410', '10.1111/jpy.12345', '2024-02-01', '2023-09-01', 'mike.taylor', 'mike.taylor'),
('Thesis', 'PROJ-2023-015', 'Heavy metal contamination in Fjord sediments', 'MSc Thesis, Environmental University', NULL, NULL, '1-150', NULL, '2023-09-10', '2023-07-01', 'peter.evans', 'peter.evans'),
('JournalArticle', 'PROJ-2023-016', 'Biodiversity patterns in the Baltic Sea', 'Marine Ecology Progress Series', '700', NULL, '1-12', '10.3354/meps12345', '2024-03-01', '2023-10-01', 'quinn.fisher', 'quinn.fisher'),
('ConferencePaper', 'PROJ-2023-018', 'Satellite tracking of Caribbean reef sharks', 'Proc. Marine Conservation Conf.', '2024', NULL, '70-75', NULL, '2024-04-10', '2024-01-01', 'john.doe', 'john.doe'),
('Report', 'PROJ-2023-019', 'Red Sea Fish Stock Assessment 2023', NULL, NULL, NULL, NULL, NULL, '2023-12-20', '2023-11-15', 'jane.smith', 'jane.smith'),
('JournalArticle', 'PROJ-2023-020', 'Impact of pollution on Black Sea benthic fauna', 'Environmental Pollution', '345', NULL, '113200', '10.1016/j.envpol.2023.113200', '2024-01-05', '2023-08-01', 'alice.jones', 'alice.jones'),
('JournalArticle', 'PROJ-2023-004', 'Novel microbial species from deep-sea vents', 'Microbial Ecology', '88', '5', '1000-1010', '10.1007/s00248-024-02400-x', '2024-05-01', '2024-01-01', 'bob.white', 'bob.white'),
('ConferencePaper', 'PROJ-2023-006', 'Screening marine organisms for anti-cancer compounds', 'Proc. Marine Biotechnology Symp.', '2024', NULL, '150-155', NULL, '2024-06-01', '2024-03-01', 'david.green', 'david.green'),
('Report', 'PROJ-2023-009', 'Annual Report on Riverine Ecosystem Health', NULL, NULL, NULL, NULL, NULL, '2024-07-01', '2024-05-01', 'irene.lim', 'irene.lim'),
('JournalArticle', 'PROJ-2023-013', 'Primary productivity in Eastern Pacific upwelling zones', 'Limnology and Oceanography', '69', '3', '300-310', '10.1002/lno.12345', '2024-08-01', '2024-02-01', 'nancy.clark', 'nancy.clark'),
('ConferencePaper', 'PROJ-2023-014', 'New insights into deep-sea invertebrate diversity', 'Proc. Deep Sea Biology Symp.', '2024', NULL, '200-205', NULL, '2024-09-01', '2024-04-01', 'olivia.davis', 'olivia.davis'),
('Report', 'PROJ-2023-017', 'Caribbean Coastal Zone Development Impact Assessment', NULL, NULL, NULL, NULL, NULL, '2024-10-01', '2024-06-01', 'rachel.gonzalez', 'rachel.gonzalez')
ON CONFLICT ("publication_id") DO NOTHING;

-- ======================================================================
-- 3. Lab Schema Data
-- ======================================================================

-- lab.experiments (using generate_experiment_id is not defined, so manual ID)
-- Note: The schema defines a primary key on ("experiment_id", "experiment_date")
-- and partitioning by "experiment_date".
INSERT INTO "lab"."experiments" ("experiment_id", "experiment_title", "aim", "method", "sop_id", "experiment_date", "person_id", "status_id") VALUES
('EXP-2023-001', 'Cod Gut Microbiome Analysis', 'Analyze gut microbial composition of Atlantic Cod.', '16S rRNA gene sequencing', 'DNA-EXT-001_v10', '2023-03-05', 'john.doe', 'In Progress'),
('EXP-2023-002', 'Dolphin Skin RNA Expression', 'Study gene expression in dolphin skin tissue.', 'RNA-Seq', 'RNA-EXT-002_v11', '2023-04-15', 'jane.smith', 'Completed'),
('EXP-2023-003', 'Prawn Growth Hormone PCR', 'Quantify growth hormone gene expression in prawns.', 'qPCR', 'PCR-AMP-011_v10', '2023-06-01', 'alice.jones', 'In Progress'),
('EXP-2023-004', 'Deep Sea Sediment eDNA', 'Identify microbial diversity from sediment eDNA.', 'Metabarcoding', 'DNA-EXT-001_v10', '2023-07-10', 'bob.white', 'Planned'),
('EXP-2023-005', 'Coastal Water Pathogen Detection', 'Detect presence of specific pathogens in coastal waters.', 'qPCR', 'QPCR-012_v10', '2023-08-20', 'john.doe', 'In Progress'),
('EXP-2023-006', 'Marine Natural Product Screening', 'Screen marine extracts for antimicrobial activity.', 'Bioassay', NULL, '2023-09-01', 'david.green', 'On Hold'),
('EXP-2023-007', 'Coral Bleaching Gene Expression', 'Investigate gene expression changes during coral bleaching.', 'RNA-Seq', 'RNA-EXT-002_v11', '2023-10-10', 'grace.hall', 'Completed'),
('EXP-2023-008', 'Arctic Microbial Community Structure', 'Characterize microbial communities in Arctic brine channels.', '16S rRNA gene sequencing', 'DNA-EXT-001_v10', '2023-11-20', 'henry.king', 'In Progress'),
('EXP-2023-009', 'River Fish Diet Analysis', 'Determine diet composition of river fish using eDNA.', 'eDNA Metabarcoding', 'DNA-EXT-001_v10', '2024-01-05', 'irene.lim', 'Planned'),
('EXP-2023-010', 'Invasive Species eDNA Detection', 'Detect invasive species in lake water samples.', 'qPCR', 'QPCR-012_v10', '2024-02-15', 'kevin.scott', 'In Progress'),
('EXP-2023-011', 'Wetland Plant Microbiome', 'Analyze microbial communities associated with wetland plants.', '16S rRNA gene sequencing', 'DNA-EXT-001_v10', '2024-03-01', 'laura.miller', 'Completed'),
('EXP-2023-012', 'Algal Bloom Toxin Gene Detection', 'Identify toxin-producing genes in algal bloom samples.', 'PCR', 'PCR-AMP-011_v10', '2024-04-10', 'mike.taylor', 'In Progress'),
('EXP-2023-013', 'Ocean Primary Producer Diversity', 'Assess diversity of phytoplankton in upwelling zones.', '18S rRNA gene sequencing', 'DNA-EXT-001_v10', '2024-05-20', 'nancy.clark', 'Planned'),
('EXP-2023-014', 'Deep Sea Invertebrate eDNA', 'Identify invertebrate species from deep-sea eDNA samples.', 'COI Metabarcoding', 'DNA-EXT-001_v10', '2024-06-01', 'olivia.davis', 'In Progress'),
('EXP-2023-015', 'Fjord Sediment Bacterial Contamination', 'Quantify specific bacterial contaminants in fjord sediments.', 'qPCR', 'QPCR-012_v10', '2024-07-10', 'peter.evans', 'Completed'),
('EXP-2023-016', 'Baltic Sea Fish Stock Genetics', 'Genetic diversity analysis of key Baltic Sea fish stocks.', 'Microsatellite genotyping', 'DNA-EXT-001_v10', '2024-08-01', 'quinn.fisher', 'In Progress'),
('EXP-2023-017', 'Caribbean Reef Health Diagnostics', 'Develop eDNA diagnostic tools for coral reef health.', 'Metabarcoding', 'DNA-EXT-001_v10', '2024-09-10', 'rachel.gonzalez', 'Planned'),
('EXP-2023-018', 'Red Sea Coral Disease Pathogen', 'Identify pathogens associated with coral diseases in Red Sea.', 'PCR', 'PCR-AMP-011_v10', '2024-10-20', 'john.doe', 'In Progress'),
('EXP-2023-019', 'Black Sea Pollution Biomarkers', 'Investigate gene expression biomarkers for pollution in Black Sea fish.', 'RNA-Seq', 'RNA-EXT-002_v11', '2024-11-01', 'jane.smith', 'Completed'),
('EXP-2023-020', 'Global Ocean Plankton Diversity', 'Global survey of plankton diversity using metagenomics.', 'Metagenomics', 'DNA-EXT-001_v10', '2024-12-01', 'alice.jones', 'Planned')
ON CONFLICT ("experiment_id", "experiment_date") DO NOTHING;

-- lab.experiments_projects
INSERT INTO "lab"."experiments_projects" ("experiment_id", "experiment_date", "project_id", "link_date") VALUES
('EXP-2023-001', '2023-03-05', 'PROJ-2023-001', '2023-03-05'),
('EXP-2023-002', '2023-04-15', 'PROJ-2023-002', '2023-04-15'),
('EXP-2023-003', '2023-06-01', 'PROJ-2023-003', '2023-06-01'),
('EXP-2023-004', '2023-07-10', 'PROJ-2023-004', '2023-07-10'),
('EXP-2023-005', '2023-08-20', 'PROJ-2023-005', '2023-08-20'),
('EXP-2023-006', '2023-09-01', 'PROJ-2023-006', '2023-09-01'),
('EXP-2023-007', '2023-10-10', 'PROJ-2023-007', '2023-10-10'),
('EXP-2023-008', '2023-11-20', 'PROJ-2023-008', '2023-11-20'),
('EXP-2023-009', '2024-01-05', 'PROJ-2023-009', '2024-01-05'),
('EXP-2023-010', '2024-02-15', 'PROJ-2023-010', '2024-02-15'),
('EXP-2023-011', '2024-03-01', 'PROJ-2023-011', '2024-03-01'),
('EXP-2023-012', '2024-04-10', 'PROJ-2023-012', '2024-04-10'),
('EXP-2023-013', '2024-05-20', 'PROJ-2023-013', '2024-05-20'),
('EXP-2023-014', '2024-06-01', 'PROJ-2023-014', '2024-06-01'),
('EXP-2023-015', '2024-07-10', 'PROJ-2023-015', '2024-07-10'),
('EXP-2023-016', '2024-08-01', 'PROJ-2023-016', '2024-08-01'),
('EXP-2023-017', '2024-09-10', 'PROJ-2023-017', '2024-09-10'),
('EXP-2023-018', '2024-10-20', 'PROJ-2023-018', '2024-10-20'),
('EXP-2023-019', '2024-11-01', 'PROJ-2023-019', '2024-11-01'),
('EXP-2023-020', '2024-12-01', 'PROJ-2023-020', '2024-12-01')
ON CONFLICT ("experiment_project_id") DO NOTHING;

-- lab.protocol_runs (using generate_protocol_run_id trigger)
INSERT INTO "lab"."protocol_runs" ("experiment_id", "experiment_date", "sop_id", "run_date", "person_id", "protocol_run_details") VALUES
('EXP-2023-001', '2023-03-05', 'DNA-EXT-001_v10', '2023-03-06', 'alice.jones', 'Automated extraction on 10 samples.'),
('EXP-2023-001', '2023-03-05', 'NANODROP-013_v10', '2023-03-07', 'charlie.brown', 'QC for 10 DNA samples.'),
('EXP-2023-002', '2023-04-15', 'RNA-EXT-002_v11', '2023-04-16', 'frank.grey', 'Manual RNA extraction, 5 samples.'),
('EXP-2023-002', '2023-04-15', 'QUBIT-014_v10', '2023-04-17', 'grace.hall', 'Qubit QC for 5 RNA samples.'),
('EXP-2023-003', '2023-06-01', 'PCR-AMP-011_v10', '2023-06-02', 'henry.king', 'PCR amplification for 20 prawn samples.'),
('EXP-2023-003', '2023-06-01', 'GELELECTROPHORESIS-015_v10', '2023-06-03', 'irene.lim', 'Gel electrophoresis of PCR products.'),
('EXP-2023-004', '2023-07-10', 'DNA-EXT-001_v10', '2023-07-11', 'kevin.scott', 'eDNA extraction from 15 sediment samples.'),
('EXP-2023-004', '2023-07-10', 'NANODROP-013_v10', '2023-07-12', 'laura.miller', 'QC for 15 eDNA samples.'),
('EXP-2023-005', '2023-08-20', 'QPCR-012_v10', '2023-08-21', 'mike.taylor', 'qPCR run for pathogen detection, 20 water samples.'),
('EXP-2023-005', '2023-08-20', 'QUBIT-014_v10', '2023-08-22', 'nancy.clark', 'Qubit QC for qPCR templates.'),
('EXP-2023-007', '2023-10-10', 'RNA-EXT-002_v11', '2023-10-11', 'olivia.davis', 'RNA isolation from coral biopsies.'),
('EXP-2023-007', '2023-10-10', 'TAPESTATION-015_v10', '2023-10-12', 'peter.evans', 'Tapestation QC for coral RNA.'),
('EXP-2023-008', '2023-11-20', 'DNA-EXT-001_v10', '2023-11-21', 'quinn.fisher', 'DNA extraction from Arctic microbial mats.'),
('EXP-2023-008', '2023-11-20', 'QUBIT-014_v10', '2023-11-22', 'rachel.gonzalez', 'Qubit QC for Arctic DNA samples.'),
('EXP-2023-009', '2024-01-05', 'DNA-EXT-001_v10', '2024-01-06', 'john.doe', 'eDNA extraction from river water.'),
('EXP-2023-009', '2024-01-05', 'NANODROP-013_v10', '2024-01-07', 'jane.smith', 'Nanodrop QC for river eDNA.'),
('EXP-2023-010', '2024-02-15', 'QPCR-012_v10', '2024-02-16', 'alice.jones', 'qPCR for invasive species detection.'),
('EXP-2023-010', '2024-02-15', 'TAPESTATION-015_v10', '2024-02-17', 'bob.white', 'Tapestation QC for qPCR templates.'),
('EXP-2023-011', '2024-03-01', 'DNA-EXT-001_v10', '2024-03-02', 'charlie.brown', 'DNA extraction from wetland plant roots.'),
('EXP-2023-011', '2024-03-01', 'QUBIT-014_v10', '2024-03-03', 'david.green', 'Qubit QC for plant DNA.')
ON CONFLICT ("protocol_run_id") DO NOTHING;

-- lab.sampling (using generate_sampling_id trigger)
-- Note: geom data is simplified for demo purposes.
INSERT INTO "lab"."sampling" ("project_id", "cruise_id", "region_id", "ecosystem_id", "customer_id", "sampling_date", "geom", "location_name", "depth_m", "sample_type_id", "status_id") VALUES
('PROJ-2023-001', 'CRU-2023-001', 'NA_Atl', 'OpenOcean', 1, '2023-02-10', ST_SetSRID(ST_MakePoint(-70.0, 40.0), 4326), 'Georges Bank', 50, 'Fish', 'Completed'),
('PROJ-2023-001', 'CRU-2023-001', 'NA_Atl', 'OpenOcean', 1, '2023-02-15', ST_SetSRID(ST_MakePoint(-69.5, 40.5), 4326), 'Gulf of Maine', 100, 'Water', 'Completed'),
('PROJ-2023-002', 'CRU-2023-002', 'EU_Med', 'Coastal', 2, '2023-04-20', ST_SetSRID(ST_MakePoint(3.0, 40.0), 4326), 'Barcelona Coast', 20, 'Tissue', 'Completed'),
('PROJ-2023-002', 'CRU-2023-002', 'EU_Med', 'Coastal', 2, '2023-04-25', ST_SetSRID(ST_MakePoint(3.5, 40.5), 4326), 'Valencia Bay', 15, 'Water', 'Completed'),
('PROJ-2023-003', 'CRU-2023-003', 'AS_Pac', 'Coastal', 3, '2023-06-05', ST_SetSRID(ST_MakePoint(135.0, 35.0), 4326), 'Tokyo Bay', 10, 'Fish', 'In Progress'),
('PROJ-2023-003', 'CRU-2023-003', 'AS_Pac', 'Coastal', 3, '2023-06-10', ST_SetSRID(ST_MakePoint(135.5, 35.5), 4326), 'Osaka Bay', 8, 'WaterFilter', 'In Progress'),
('PROJ-2023-004', 'CRU-2023-004', 'SA_Atl', 'DeepSea', 4, '2024-02-10', ST_SetSRID(ST_MakePoint(-30.0, -20.0), 4326), 'Mid-Atlantic Ridge', 2000, 'Sediments', 'Planned'),
('PROJ-2023-004', 'CRU-2023-004', 'SA_Atl', 'DeepSea', 4, '2024-02-15', ST_SetSRID(ST_MakePoint(-30.5, -20.5), 4326), 'South Atlantic Abyssal', 3000, 'Water', 'Planned'),
('PROJ-2023-005', 'CRU-2023-005', 'NA_Atl', 'Coastal', 5, '2023-08-05', ST_SetSRID(ST_MakePoint(-71.0, 41.0), 4326), 'Rhode Island Coast', 10, 'Water', 'In Progress'),
('PROJ-2023-005', 'CRU-2023-005', 'NA_Atl', 'Coastal', 5, '2023-08-10', ST_SetSRID(ST_MakePoint(-71.5, 41.5), 4326), 'Cape Cod Bay', 12, 'WaterFilter', 'In Progress'),
('PROJ-2023-006', 'CRU-2023-006', 'AF_Ind', 'OpenOcean', 6, '2023-10-05', ST_SetSRID(ST_MakePoint(50.0, -10.0), 4326), 'Mozambique Channel', 500, 'Plankton', 'On Hold'),
('PROJ-2023-006', 'CRU-2023-006', 'AF_Ind', 'OpenOcean', 6, '2023-10-10', ST_SetSRID(ST_MakePoint(50.5, -10.5), 4326), 'Comoros Basin', 1000, 'Water', 'On Hold'),
('PROJ-2023-007', 'CRU-2023-007', 'OC_Pac', 'CoralReef', 7, '2022-12-15', ST_SetSRID(ST_MakePoint(170.0, -10.0), 4326), 'Great Barrier Reef', 5, 'Tissue', 'Completed'),
('PROJ-2023-007', 'CRU-2023-007', 'OC_Pac', 'CoralReef', 7, '2022-12-20', ST_SetSRID(ST_MakePoint(170.5, -10.5), 4326), 'Fiji Coral Gardens', 7, 'Water', 'Completed'),
('PROJ-2023-008', 'CRU-2023-008', 'AR_Arc', 'Polar', 8, '2023-03-10', ST_SetSRID(ST_MakePoint(15.0, 80.0), 4326), 'Svalbard Ice Edge', 20, 'IceEdge', 'In Progress'),
('PROJ-2023-008', 'CRU-2023-008', 'AR_Arc', 'Polar', 8, '2023-03-15', ST_SetSRID(ST_MakePoint(15.5, 80.5), 4326), 'Greenland Sea', 50, 'Water', 'In Progress'),
('PROJ-2023-009', 'CRU-2023-009', 'EU_Nor', 'Estuary', 9, '2024-04-10', ST_SetSRID(ST_MakePoint(8.0, 53.0), 4326), 'Elbe Estuary', 5, 'Fish', 'Planned'),
('PROJ-2023-009', 'CRU-2023-009', 'EU_Nor', 'Estuary', 9, '2024-04-15', ST_SetSRID(ST_MakePoint(8.5, 53.5), 4326), 'Weser Estuary', 7, 'Sediments', 'Planned'),
('PROJ-2023-010', 'CRU-2023-010', 'AS_Ind', 'Lake', 10, '2023-05-10', ST_SetSRID(ST_MakePoint(77.0, 28.0), 4326), 'Dal Lake', 10, 'Water', 'In Progress'),
('PROJ-2023-010', 'CRU-2023-010', 'AS_Ind', 'Lake', 10, '2023-05-15', ST_SetSRID(ST_MakePoint(77.5, 28.5), 4326), 'Pichola Lake', 12, 'Fish', 'In Progress')
ON CONFLICT ("sampling_id", "sampling_date") DO NOTHING;

-- lab.master_samples (populated by generate_sample_id trigger)
-- No direct inserts here, as it's handled by the trigger on lab.samples

-- lab.samples (using generate_sample_id trigger)
-- Note: sampling_id and sampling_date must exist in lab.sampling
INSERT INTO "lab"."samples" ("external_name", "parent_sample_id", "sampling_id", "sampling_date", "storage_id", "storage_position", "sampler_person_id", "receiver_person_id", "reception_date", "transport", "conservation_buffer", "sample_type_id", "project_id", "customer_id") VALUES
('Cod-Gut-001', NULL, '23NA-ATL0001', '2023-02-10', 'FRZ-A-01', 'A-01-1-1', 'john.doe', 'jane.smith', '2023-02-12', 'Chilled', 'Ethanol', 'Tissue', 'PROJ-2023-001', 1),
('Cod-Gut-002', NULL, '23NA-ATL0001', '2023-02-10', 'FRZ-A-01', 'A-01-1-2', 'john.doe', 'jane.smith', '2023-02-12', 'Chilled', 'Ethanol', 'Tissue', 'PROJ-2023-001', 1),
('Dolphin-Skin-001', NULL, '23EU-MED0001', '2023-04-20', 'FRZ-B-01', 'B-01-1-1', 'jane.smith', 'alice.jones', '2023-04-22', 'Frozen', 'RNAlater', 'Tissue', 'PROJ-2023-002', 2),
('Dolphin-Skin-002', NULL, '23EU-MED0001', '2023-04-20', 'FRZ-B-01', 'B-01-1-2', 'jane.smith', 'alice.jones', '2023-04-22', 'Frozen', 'RNAlater', 'Tissue', 'PROJ-2023-002', 2),
('Prawn-Muscle-001', NULL, '23AS-PAC0001', '2023-06-05', 'FRZ-C-01', 'C-01-1-1', 'alice.jones', 'charlie.brown', '2023-06-07', 'Frozen', 'None', 'Tissue', 'PROJ-2023-003', 3),
('Prawn-Muscle-002', NULL, '23AS-PAC0001', '2023-06-05', 'FRZ-C-01', 'C-01-1-2', 'alice.jones', 'charlie.brown', '2023-06-07', 'Frozen', 'None', 'Tissue', 'PROJ-2023-003', 3),
('Sediment-Core-A', NULL, '24SA-ATL0001', '2024-02-10', 'RM-E-01', 'E-01-1-1', 'bob.white', 'david.green', '2024-02-18', 'Chilled', 'None', 'Sediments', 'PROJ-2023-004', 4),
('Sediment-Core-B', NULL, '24SA-ATL0001', '2024-02-10', 'RM-E-01', 'E-01-1-2', 'bob.white', 'david.green', '2024-02-18', 'Chilled', 'None', 'Sediments', 'PROJ-2023-004', 4),
('Water-Coastal-001', NULL, '23NA-ATL0003', '2023-08-05', 'FRZ-D-01', 'D-01-1-1', 'john.doe', 'frank.grey', '2023-08-07', 'Chilled', 'None', 'Water', 'PROJ-2023-005', 5),
('Water-Coastal-002', NULL, '23NA-ATL0003', '2023-08-05', 'FRZ-D-01', 'D-01-1-2', 'john.doe', 'frank.grey', '2023-08-07', 'Chilled', 'None', 'Water', 'PROJ-2023-005', 5),
('Coral-Biopsy-001', NULL, '22OC-PAC0001', '2022-12-15', 'FRZ-G-01', 'G-01-1-1', 'grace.hall', 'henry.king', '2022-12-18', 'Frozen', 'Ethanol', 'Tissue', 'PROJ-2023-007', 7),
('Coral-Biopsy-002', NULL, '22OC-PAC0001', '2022-12-15', 'FRZ-G-01', 'G-01-1-2', 'grace.hall', 'henry.king', '2022-12-18', 'Frozen', 'Ethanol', 'Tissue', 'PROJ-2023-007', 7),
('Arctic-Mat-001', NULL, '23AR-ARC0001', '2023-03-10', 'FRZ-H-01', 'H-01-1-1', 'henry.king', 'irene.lim', '2023-03-15', 'Frozen', 'None', 'Microbe', 'PROJ-2023-008', 8),
('Arctic-Mat-002', NULL, '23AR-ARC0001', '2023-03-10', 'FRZ-H-01', 'H-01-1-2', 'henry.king', 'irene.lim', '2023-03-15', 'Frozen', 'None', 'Microbe', 'PROJ-2023-008', 8),
('River-Water-001', NULL, '24EU-NOR0001', '2024-04-10', 'FRZ-J-01', 'J-01-1-1', 'irene.lim', 'kevin.scott', '2024-04-12', 'Chilled', 'None', 'Water', 'PROJ-2023-009', 9),
('River-Water-002', NULL, '24EU-NOR0001', '2024-04-10', 'FRZ-J-01', 'J-01-1-2', 'irene.lim', 'kevin.scott', '2024-04-12', 'Chilled', 'None', 'Water', 'PROJ-2023-009', 9),
('Lake-Fish-001', NULL, '23AS-IND0002', '2023-05-15', 'FRZ-J-01', 'J-01-2-1', 'kevin.scott', 'laura.miller', '2023-05-17', 'Chilled', 'None', 'Fish', 'PROJ-2023-010', 10),
('Lake-Fish-002', NULL, '23AS-IND0002', '2023-05-15', 'FRZ-J-01', 'J-01-2-2', 'kevin.scott', 'laura.miller', '2023-05-17', 'Chilled', 'None', 'Fish', 'PROJ-2023-010', 10),
('Wetland-Plant-001', NULL, NULL, '2024-03-01', 'RM-E-02', 'E-02-1-1', 'laura.miller', 'mike.taylor', '2024-03-03', 'Chilled', 'None', 'Tissue', 'PROJ-2023-011', 11),
('Wetland-Plant-002', NULL, NULL, '2024-03-01', 'RM-E-02', 'E-02-1-2', 'laura.miller', 'mike.taylor', '2024-03-03', 'Chilled', 'None', 'Tissue', 'PROJ-2023-011', 11)
ON CONFLICT ("sample_id", "sampling_date") DO NOTHING;

-- lab.fishing
INSERT INTO "lab"."fishing" ("sampling_id", "sampling_date", "taxon_id", "catch_kg", "catch_fish", "customer_id") VALUES
('23NA-ATL0001', '2023-02-10', 'Gadus_morhua', 50.5, 10, 1),
('23AS-PAC0001', '2023-06-05', 'Penaeus_monodon', 10.2, 500, 3),
('23AS-IND0002', '2023-05-15', 'Gadus_morhua', 20.0, 5, 10), -- Using Gadus_morhua as a placeholder for lake fish
('24EU-NOR0001', '2024-04-10', 'Gadus_morhua', 15.0, 3, 9) -- Using Gadus_morhua as a placeholder for river fish
ON CONFLICT ("fishing_id") DO NOTHING;

-- lab.storage_log
INSERT INTO "lab"."storage_log" ("sample_id", "sample_sampling_date", "storage_id", "person_id", "move_date", "status", "storage_position") VALUES
('T23NA-ATL00010001', '2023-02-10', 'FRZ-A-01', 'jane.smith', '2023-02-12 10:00:00', 'Stored', 'A-01-1-1'),
('T23NA-ATL00010002', '2023-02-10', 'FRZ-A-01', 'jane.smith', '2023-02-12 10:05:00', 'Stored', 'A-01-1-2'),
('T23EU-MED00010001', '2023-04-20', 'FRZ-B-01', 'alice.jones', '2023-04-22 11:00:00', 'Stored', 'B-01-1-1'),
('T23EU-MED00010002', '2023-04-20', 'FRZ-B-01', 'alice.jones', '2023-04-22 11:05:00', 'Stored', 'B-01-1-2'),
('T23AS-PAC00010001', '2023-06-05', 'FRZ-C-01', 'charlie.brown', '2023-06-07 12:00:00', 'Stored', 'C-01-1-1'),
('T23AS-PAC00010002', '2023-06-05', 'FRZ-C-01', 'charlie.brown', '2023-06-07 12:05:00', 'Stored', 'C-01-1-2'),
('S24SA-ATL00010001', '2024-02-10', 'RM-E-01', 'david.green', '2024-02-18 09:00:00', 'Stored', 'E-01-1-1'),
('S24SA-ATL00010002', '2024-02-10', 'RM-E-01', 'david.green', '2024-02-18 09:05:00', 'Stored', 'E-01-1-2'),
('W23NA-ATL00030001', '2023-08-05', 'FRZ-D-01', 'frank.grey', '2023-08-07 13:00:00', 'Stored', 'D-01-1-1'),
('W23NA-ATL00030002', '2023-08-05', 'FRZ-D-01', 'frank.grey', '2023-08-07 13:05:00', 'Stored', 'D-01-1-2'),
('T22OC-PAC00010001', '2022-12-15', 'FRZ-G-01', 'henry.king', '2022-12-18 14:00:00', 'Stored', 'G-01-1-1'),
('T22OC-PAC00010002', '2022-12-15', 'FRZ-G-01', 'henry.king', '2022-12-18 14:05:00', 'Stored', 'G-01-1-2'),
('MB23AR-ARC00010001', '2023-03-10', 'FRZ-H-01', 'irene.lim', '2023-03-15 15:00:00', 'Stored', 'H-01-1-1'),
('MB23AR-ARC00010002', '2023-03-10', 'FRZ-H-01', 'irene.lim', '2023-03-15 15:05:00', 'Stored', 'H-01-1-2'),
('W24EU-NOR00010001', '2024-04-10', 'FRZ-J-01', 'kevin.scott', '2024-04-12 16:00:00', 'Stored', 'J-01-1-1'),
('W24EU-NOR00010002', '2024-04-10', 'FRZ-J-01', 'kevin.scott', '2024-04-12 16:05:00', 'Stored', 'J-01-1-2'),
('F23AS-IND00020001', '2023-05-15', 'FRZ-J-01', 'laura.miller', '2023-05-17 17:00:00', 'Stored', 'J-01-2-1'),
('F23AS-IND00020002', '2023-05-15', 'FRZ-J-01', 'laura.miller', '2023-05-17 17:05:00', 'Stored', 'J-01-2-2'),
('T24-00010001', '2024-03-01', 'RM-E-02', 'mike.taylor', '2024-03-03 18:00:00', 'Stored', 'E-02-1-1'),
('T24-00010002', '2024-03-01', 'RM-E-02', 'mike.taylor', '2024-03-03 18:05:00', 'Stored', 'E-02-1-2')
ON CONFLICT ("log_id") DO NOTHING;

-- lab.fish (using generate_fish_child_sample_id trigger)
-- Parent samples must be of type 'Fish'
INSERT INTO "lab"."fish" ("parent_sample_id", "species_id", "total_length_mm", "weight_g", "sex", "project_id", "customer_id") VALUES
('F23NA-ATL00010001', 'Gadus_morhua', 800, 5000, 'Male', 'PROJ-2023-001', 1),
('F23NA-ATL00010002', 'Gadus_morhua', 750, 4500, 'Female', 'PROJ-2023-001', 1),
('F23AS-IND00020001', 'Gadus_morhua', 300, 500, 'Undetermined', 'PROJ-2023-010', 10), -- Placeholder for lake fish
('F23AS-IND00020002', 'Gadus_morhua', 320, 550, 'Male', 'PROJ-2023-010', 10), -- Placeholder for lake fish
('F24EU-NOR00010001', 'Gadus_morhua', 450, 1200, 'Female', 'PROJ-2023-009', 9), -- Placeholder for river fish
('F24EU-NOR00010002', 'Gadus_morhua', 400, 1000, 'Male', 'PROJ-2023-009', 9) -- Placeholder for river fish
ON CONFLICT ("sample_id") DO NOTHING;

-- lab.tissue (using generate_tissue_child_sample_id trigger)
-- Parent samples can be any type, but usually 'Fish' or 'Master Sample'
INSERT INTO "lab"."tissue" ("parent_sample_id", "weight_mg", "tissue_type", "preservation_method", "storage_id", "storage_position", "project_id") VALUES
('T23NA-ATL00010001', 50, 'Muscle', 'Ethanol', 'FRZ-A-01', 'A-01-1-3', 'PROJ-2023-001'),
('T23NA-ATL00010002', 45, 'Liver', 'Ethanol', 'FRZ-A-01', 'A-01-1-4', 'PROJ-2023-001'),
('T23EU-MED00010001', 100, 'Skin', 'RNAlater', 'FRZ-B-01', 'B-01-1-3', 'PROJ-2023-002'),
('T23EU-MED00010002', 90, 'Brain', 'RNAlater', 'FRZ-B-01', 'B-01-1-4', 'PROJ-2023-002'),
('T23AS-PAC00010001', 20, 'Gill', 'Frozen', 'FRZ-C-01', 'C-01-1-3', 'PROJ-2023-003'),
('T23AS-PAC00010002', 25, 'Hepatopancreas', 'Frozen', 'FRZ-C-01', 'C-01-1-4', 'PROJ-2023-003'),
('T22OC-PAC00010001', 150, 'Coral Polyp', 'Ethanol', 'FRZ-G-01', 'G-01-1-3', 'PROJ-2023-007'),
('T22OC-PAC00010002', 120, 'Coral Skeleton', 'Ethanol', 'FRZ-G-01', 'G-01-1-4', 'PROJ-2023-007'),
('MB23AR-ARC00010001', 5, 'Microbial Mat', 'Frozen', 'FRZ-H-01', 'H-01-1-3', 'PROJ-2023-008'),
('MB23AR-ARC00010002', 7, 'Brine Sample', 'Frozen', 'FRZ-H-01', 'H-01-1-4', 'PROJ-2023-008'),
('T24-00010001', 30, 'Root', 'Chilled', 'RM-E-02', 'E-02-1-3', 'PROJ-2023-011'),
('T24-00010002', 25, 'Leaf', 'Chilled', 'RM-E-02', 'E-02-1-4', 'PROJ-2023-011')
ON CONFLICT ("sample_id") DO NOTHING;

-- lab.dna (using generate_dna_child_sample_id trigger)
-- Parent samples can be any type, but usually 'Tissue', 'Water', 'Sediments'
INSERT INTO "lab"."dna" ("parent_sample_id", "volume_ul", "concentration_ng_ul", "a260_280", "a260_230", "extraction_method", "preservation_method", "extraction_date", "extraction_number", "storage_id", "storage_position", "project_id") VALUES
('T23NA-ATL00010001', 50, 80, 1.85, 2.05, 'DNeasy Kit', 'Frozen', '2023-03-06', 1, 'FRZ-A-01', 'A-01-2-1', 'PROJ-2023-001'),
('T23NA-ATL00010002', 45, 75, 1.80, 2.00, 'DNeasy Kit', 'Frozen', '2023-03-06', 2, 'FRZ-A-01', 'A-01-2-2', 'PROJ-2023-001'),
('T23AS-PAC00010001', 60, 90, 1.90, 2.10, 'Phenol-Chloroform', 'Frozen', '2023-06-08', 1, 'FRZ-C-01', 'C-01-2-1', 'PROJ-2023-003'),
('T23AS-PAC00010002', 55, 85, 1.88, 2.08, 'Phenol-Chloroform', 'Frozen', '2023-06-08', 2, 'FRZ-C-01', 'C-01-2-2', 'PROJ-2023-003'),
('S24SA-ATL00010001', 70, 100, 1.95, 2.15, 'Soil DNA Kit', 'Frozen', '2024-02-20', 1, 'FRZ-D-01', 'D-01-2-1', 'PROJ-2023-004'),
('S24SA-ATL00010002', 65, 95, 1.92, 2.12, 'Soil DNA Kit', 'Frozen', '2024-02-20', 2, 'FRZ-D-01', 'D-01-2-2', 'PROJ-2023-004'),
('W23NA-ATL00030001', 80, 10, 1.70, 1.80, 'Water Filtration', 'Frozen', '2023-08-08', 1, 'FRZ-D-01', 'D-01-2-3', 'PROJ-2023-005'),
('W23NA-ATL00030002', 75, 8, 1.68, 1.78, 'Water Filtration', 'Frozen', '2023-08-08', 2, 'FRZ-D-01', 'D-01-2-4', 'PROJ-2023-005'),
('MB23AR-ARC00010001', 50, 60, 1.80, 2.00, 'Microbial DNA Kit', 'Frozen', '2023-11-22', 1, 'FRZ-H-01', 'H-01-2-1', 'PROJ-2023-008'),
('MB23AR-ARC00010002', 45, 55, 1.78, 1.98, 'Microbial DNA Kit', 'Frozen', '2023-11-22', 2, 'FRZ-H-01', 'H-01-2-2', 'PROJ-2023-008'),
('W24EU-NOR00010001', 70, 12, 1.75, 1.85, 'Water Filtration', 'Frozen', '2024-04-13', 1, 'FRZ-J-01', 'J-01-1-3', 'PROJ-2023-009'),
('W24EU-NOR00010002', 65, 10, 1.72, 1.82, 'Water Filtration', 'Frozen', '2024-04-13', 2, 'FRZ-J-01', 'J-01-1-4', 'PROJ-2023-009'),
('T24-00010001', 55, 70, 1.85, 2.05, 'Plant DNA Kit', 'Frozen', '2024-03-04', 1, 'RM-E-02', 'E-02-2-1', 'PROJ-2023-011'),
('T24-00010002', 50, 65, 1.82, 2.02, 'Plant DNA Kit', 'Frozen', '2024-03-04', 2, 'RM-E-02', 'E-02-2-2', 'PROJ-2023-011')
ON CONFLICT ("sample_id") DO NOTHING;

-- lab.rna (using generate_rna_child_sample_id trigger)
-- Parent samples can be any type, but usually 'Tissue', 'Water', 'Sediments'
INSERT INTO "lab"."rna" ("parent_sample_id", "volume_ul", "concentration_ng_ul", "a260_280", "a260_230", "extraction_method", "preservation_method", "extraction_date", "extraction_number", "storage_id", "storage_position", "project_id") VALUES
('T23EU-MED00010001', 40, 60, 2.00, 1.90, 'RNAeasy Kit', 'Frozen', '2023-04-18', 1, 'FRZ-B-01', 'B-01-2-1', 'PROJ-2023-002'),
('T23EU-MED00010002', 35, 55, 1.98, 1.88, 'RNAeasy Kit', 'Frozen', '2023-04-18', 2, 'FRZ-B-01', 'B-01-2-2', 'PROJ-2023-002'),
('T22OC-PAC00010001', 50, 70, 2.05, 1.95, 'TRIzol', 'Frozen', '2022-12-22', 1, 'FRZ-G-01', 'G-01-2-1', 'PROJ-2023-007'),
('T22OC-PAC00010002', 45, 65, 2.02, 1.92, 'TRIzol', 'Frozen', '2022-12-22', 2, 'FRZ-G-01', 'G-01-2-2', 'PROJ-2023-007')
ON CONFLICT ("sample_id") DO NOTHING;

-- lab.sediments (using generate_sediments_child_sample_id trigger)
-- Parent samples can be any type, but usually 'Master Sample'
INSERT INTO "lab"."sediments" ("parent_sample_id", "volume", "volume_unit_id", "depth_m", "sampling_method", "conservation_buffer", "storage_id", "storage_position", "external_name", "project_id") VALUES
('S24SA-ATL00010001', 100, 'ml', 2000, 'Box Corer', 'None', 'RM-E-01', 'E-01-1-3', 'DeepSeaCore-01', 'PROJ-2023-004'),
('S24SA-ATL00010002', 120, 'ml', 2050, 'Multi-Corer', 'None', 'RM-E-01', 'E-01-1-4', 'DeepSeaCore-02', 'PROJ-2023-004'),
('S24EU-NOR00010001', 50, 'ml', 6, 'Grab Sampler', 'None', 'RM-E-02', 'E-02-1-5', 'EstuarySediment-01', 'PROJ-2023-009'),
('S24EU-NOR00010002', 55, 'ml', 7, 'Grab Sampler', 'None', 'RM-E-02', 'E-02-1-6', 'EstuarySediment-02', 'PROJ-2023-009')
ON CONFLICT ("sample_id") DO NOTHING;

-- lab.water (using generate_water_child_sample_id trigger)
-- Parent samples can be any type, but usually 'Master Sample'
INSERT INTO "lab"."water" ("parent_sample_id", "volume_l", "filter", "filter_pore_size_um", "depth_m", "sampling_method", "conservation_buffer", "storage_id", "storage_position", "project_id") VALUES
('W23NA-ATL00030001', 10, 'GF/F', 0.7, 5, 'Niskin Bottle', 'None', 'FRZ-D-01', 'D-01-1-3', 'PROJ-2023-005'),
('W23NA-ATL00030002', 12, 'GF/F', 0.7, 8, 'Niskin Bottle', 'None', 'FRZ-D-01', 'D-01-1-4', 'PROJ-2023-005'),
('W24EU-NOR00010001', 5, '0.45um', 0.45, 2, 'Bucket', 'None', 'FRZ-J-01', 'J-01-1-5', 'PROJ-2023-009'),
('W24EU-NOR00010002', 6, '0.45um', 0.45, 3, 'Bucket', 'None', 'FRZ-J-01', 'J-01-1-6', 'PROJ-2023-009')
ON CONFLICT ("sample_id") DO NOTHING;

-- lab.otoliths (using generate_otolith_id trigger)
-- Parent sample must be a 'Fish' sample
INSERT INTO "lab"."otoliths" ("sample_id", "reader_person_id", "side", "age_reading_years", "confidence", "reading_date", "project_id") VALUES
('F23NA-ATL00010001', 'john.doe', 'Left', 5, 0.95, '2023-03-10', 'PROJ-2023-001'),
('F23NA-ATL00010001', 'jane.smith', 'Right', 5, 0.90, '2023-03-11', 'PROJ-2023-001'),
('F23NA-ATL00010002', 'john.doe', 'Left', 4, 0.92, '2023-03-12', 'PROJ-2023-001'),
('F23NA-ATL00010002', 'jane.smith', 'Right', 4, 0.88, '2023-03-13', 'PROJ-2023-001'),
('F23AS-IND00020001', 'alice.jones', 'Left', 2, 0.80, '2023-06-01', 'PROJ-2023-010'),
('F23AS-IND00020001', 'bob.white', 'Right', 2, 0.75, '2023-06-02', 'PROJ-2023-010')
ON CONFLICT ("otolith_id") DO NOTHING;

-- lab.dissections (using generate_dissection_id trigger)
-- Parent sample must be a 'Fish' sample
INSERT INTO "lab"."dissections" ("sample_id", "person_id", "dissection_date", "stomach_contents_jsonb", "gonad_weight_g", "liver_weight_g", "status_id") VALUES
('F23NA-ATL00010001', 'charlie.brown', '2023-02-20', '[{"item": "small fish", "quantity": 3}, {"item": "crustacean", "quantity": 10}]', 10.5, 25.3, 'Completed'),
('F23NA-ATL00010002', 'charlie.brown', '2023-02-21', '[{"item": "squid", "quantity": 1}]', 8.2, 22.1, 'Completed'),
('F23AS-IND00020001', 'frank.grey', '2023-05-20', '[{"item": "insect larvae", "quantity": 20}]', 1.2, 3.5, 'Completed'),
('F23AS-IND00020002', 'frank.grey', '2023-05-21', '[{"item": "algae", "quantity": 1}]', 1.5, 3.8, 'Completed')
ON CONFLICT ("dissection_id", "dissection_date") DO NOTHING;

-- lab.extraction (using generate_extraction_id trigger)
-- Parent sample can be any type, typically 'Tissue', 'Water', 'Sediments'
INSERT INTO "lab"."extraction" ("experiment_id", "experiment_date", "sample_id", "parent_sample_id", "sample_type_id", "extracted_dna_sample_id", "extracted_rna_sample_id", "extraction_date", "person_id", "kit", "elution_volume_ul", "yield_qubit_ng_ul", "yield_nanodrop_ng_ul", "a260_280", "a260_230", "status_id", "project_id") VALUES
('EXP-2023-001', '2023-03-05', 'D23NA-ATL00010001', 'T23NA-ATL00010001', 'Tissue', 'D23NA-ATL00010001', NULL, '2023-03-06', 'alice.jones', 'DNeasy Kit', 50, 80, 78, 1.85, 2.05, 'Completed', 'PROJ-2023-001'),
('EXP-2023-001', '2023-03-05', 'D23NA-ATL00010002', 'T23NA-ATL00010002', 'Tissue', 'D23NA-ATL00010002', NULL, '2023-03-06', 'alice.jones', 'DNeasy Kit', 45, 75, 73, 1.80, 2.00, 'Completed', 'PROJ-2023-001'),
('EXP-2023-002', '2023-04-15', 'R23EU-MED00010001', 'T23EU-MED00010001', 'Tissue', NULL, 'R23EU-MED00010001', '2023-04-16', 'frank.grey', 'RNAeasy Kit', 40, 60, 58, 2.00, 1.90, 'Completed', 'PROJ-2023-002'),
('EXP-2023-002', '2023-04-15', 'R23EU-MED00010002', 'T23EU-MED00010002', 'Tissue', NULL, 'R23EU-MED00010002', '2023-04-16', 'frank.grey', 'RNAeasy Kit', 35, 55, 53, 1.98, 1.88, 'Completed', 'PROJ-2023-002'),
('EXP-2023-004', '2023-07-10', 'D24SA-ATL00010001', 'S24SA-ATL00010001', 'Sediments', 'D24SA-ATL00010001', NULL, '2023-07-11', 'kevin.scott', 'Soil DNA Kit', 70, 100, 98, 1.95, 2.15, 'Completed', 'PROJ-2023-004'),
('EXP-2023-004', '2023-07-10', 'D24SA-ATL00010002', 'S24SA-ATL00010002', 'Sediments', 'D24SA-ATL00010002', NULL, '2023-07-11', 'kevin.scott', 'Soil DNA Kit', 65, 95, 93, 1.92, 2.12, 'Completed', 'PROJ-2023-004'),
('EXP-2023-005', '2023-08-20', 'D23NA-ATL00030001', 'W23NA-ATL00030001', 'Water', 'D23NA-ATL00030001', NULL, '2023-08-21', 'mike.taylor', 'Water Filtration', 80, 10, 9, 1.70, 1.80, 'Completed', 'PROJ-2023-005'),
('EXP-2023-005', '2023-08-20', 'D23NA-ATL00030002', 'W23NA-ATL00030002', 'Water', 'D23NA-ATL00030002', NULL, '2023-08-21', 'mike.taylor', 'Water Filtration', 75, 8, 7, 1.68, 1.78, 'Completed', 'PROJ-2023-005'),
('EXP-2023-008', '2023-11-20', 'D23AR-ARC00010001', 'MB23AR-ARC00010001', 'Microbe', 'D23AR-ARC00010001', NULL, '2023-11-21', 'quinn.fisher', 'Microbial DNA Kit', 50, 60, 58, 1.80, 2.00, 'Completed', 'PROJ-2023-008'),
('EXP-2023-008', '2023-11-20', 'D23AR-ARC00010002', 'MB23AR-ARC00010002', 'Microbe', 'D23AR-ARC00010002', NULL, '2023-11-21', 'quinn.fisher', 'Microbial DNA Kit', 45, 55, 53, 1.78, 1.98, 'Completed', 'PROJ-2023-008'),
('EXP-2023-009', '2024-01-05', 'D24EU-NOR00010001', 'W24EU-NOR00010001', 'Water', 'D24EU-NOR00010001', NULL, '2024-01-06', 'john.doe', 'Water Filtration', 70, 12, 11, 1.75, 1.85, 'Completed', 'PROJ-2023-009'),
('EXP-2023-009', '2024-01-05', 'D24EU-NOR00010002', 'W24EU-NOR00010002', 'Water', 'D24EU-NOR00010002', NULL, '2024-01-06', 'john.doe', 'Water Filtration', 65, 10, 9, 1.72, 1.82, 'Completed', 'PROJ-2023-009'),
('EXP-2023-011', '2024-03-01', 'D24-00010001', 'T24-00010001', 'Tissue', 'D24-00010001', NULL, '2024-03-02', 'charlie.brown', 'Plant DNA Kit', 55, 70, 68, 1.85, 2.05, 'Completed', 'PROJ-2023-011'),
('EXP-2023-011', '2024-03-01', 'D24-00010002', 'T24-00010002', 'Tissue', 'D24-00010002', NULL, '2024-03-02', 'charlie.brown', 'Plant DNA Kit', 50, 65, 63, 1.82, 2.02, 'Completed', 'PROJ-2023-011')
ON CONFLICT ("extraction_id", "extraction_date") DO NOTHING;

-- lab.nanodrop (using generate_nanodrop_id trigger)
-- Sample IDs must exist in lab.master_samples
INSERT INTO "lab"."nanodrop" ("sample_id", "experiment_id", "experiment_date", "nanodrop_concentration", "concentration_unit_id", "a260", "a260_280", "a260_230", "measurement_date", "elution_volume_ul", "person_id", "status_id", "project_id") VALUES
('D23NA-ATL00010001', 'EXP-2023-001', '2023-03-05', 78, 'ng_ul', 1.56, 1.85, 2.05, '2023-03-07', 50, 'charlie.brown', 'Completed', 'PROJ-2023-001'),
('D23NA-ATL00010002', 'EXP-2023-001', '2023-03-05', 73, 'ng_ul', 1.46, 1.80, 2.00, '2023-03-07', 45, 'charlie.brown', 'Completed', 'PROJ-2023-001'),
('D23AS-PAC00010001', 'EXP-2023-003', '2023-06-01', 90, 'ng_ul', 1.80, 1.90, 2.10, '2023-06-09', 60, 'henry.king', 'Completed', 'PROJ-2023-003'),
('D23AS-PAC00010002', 'EXP-2023-003', '2023-06-01', 85, 'ng_ul', 1.70, 1.88, 2.08, '2023-06-09', 55, 'henry.king', 'Completed', 'PROJ-2023-003'),
('D24SA-ATL00010001', 'EXP-2023-004', '2023-07-10', 98, 'ng_ul', 1.96, 1.95, 2.15, '2023-07-12', 70, 'laura.miller', 'Completed', 'PROJ-2023-004'),
('D24SA-ATL00010002', 'EXP-2023-004', '2023-07-10', 93, 'ng_ul', 1.86, 1.92, 2.12, '2023-07-12', 65, 'laura.miller', 'Completed', 'PROJ-2023-004'),
('D23NA-ATL00030001', 'EXP-2023-005', '2023-08-20', 9, 'ng_ul', 0.18, 1.70, 1.80, '2023-08-22', 80, 'nancy.clark', 'Completed', 'PROJ-2023-005'),
('D23NA-ATL00030002', 'EXP-2023-005', '2023-08-20', 7, 'ng_ul', 0.14, 1.68, 1.78, '2023-08-22', 75, 'nancy.clark', 'Completed', 'PROJ-2023-005'),
('D23AR-ARC00010001', 'EXP-2023-008', '2023-11-20', 58, 'ng_ul', 1.16, 1.80, 2.00, '2023-11-23', 50, 'rachel.gonzalez', 'Completed', 'PROJ-2023-008'),
('D23AR-ARC00010002', 'EXP-2023-008', '2023-11-20', 53, 'ng_ul', 1.06, 1.78, 1.98, '2023-11-23', 45, 'rachel.gonzalez', 'Completed', 'PROJ-2023-008'),
('D24EU-NOR00010001', 'EXP-2023-009', '2024-01-05', 11, 'ng_ul', 0.22, 1.75, 1.85, '2024-01-07', 70, 'jane.smith', 'Completed', 'PROJ-2023-009'),
('D24EU-NOR00010002', 'EXP-2023-009', '2024-01-05', 9, 'ng_ul', 0.18, 1.72, 1.82, '2024-01-07', 65, 'jane.smith', 'Completed', 'PROJ-2023-009'),
('D24-00010001', 'EXP-2023-011', '2024-03-01', 68, 'ng_ul', 1.36, 1.85, 2.05, '2024-03-04', 55, 'david.green', 'Completed', 'PROJ-2023-011'),
('D24-00010002', 'EXP-2023-011', '2024-03-01', 63, 'ng_ul', 1.26, 1.82, 2.02, '2024-03-04', 50, 'david.green', 'Completed', 'PROJ-2023-011')
ON CONFLICT ("nanodrop_id", "measurement_date") DO NOTHING;

-- lab.qubit (using generate_qubit_id trigger)
-- Sample IDs must exist in lab.master_samples
INSERT INTO "lab"."qubit" ("sample_id", "experiment_id", "experiment_date", "assay_kit", "measurement_date", "qubit_tube_conc", "tube_unit_id", "qubit_original_sample_conc", "original_sample_unit_id", "sample_volume_ul", "elution_volume_ul", "person_id", "status_id", "project_id") VALUES
('D23NA-ATL00010001', 'EXP-2023-001', '2023-03-05', 'dsDNA HS', '2023-03-07', 4, 'ng_ul', 80, 'ng_ul', 1, 50, 'charlie.brown', 'Completed', 'PROJ-2023-001'),
('D23NA-ATL00010002', 'EXP-2023-001', '2023-03-05', 'dsDNA HS', '2023-03-07', 3.75, 'ng_ul', 75, 'ng_ul', 1, 45, 'charlie.brown', 'Completed', 'PROJ-2023-001'),
('R23EU-MED00010001', 'EXP-2023-002', '2023-04-15', 'RNA HS', '2023-04-17', 3, 'ng_ul', 60, 'ng_ul', 1, 40, 'grace.hall', 'Completed', 'PROJ-2023-002'),
('R23EU-MED00010002', 'EXP-2023-002', '2023-04-15', 'RNA HS', '2023-04-17', 2.75, 'ng_ul', 55, 'ng_ul', 1, 35, 'grace.hall', 'Completed', 'PROJ-2023-002'),
('D24SA-ATL00010001', 'EXP-2023-004', '2023-07-10', 'dsDNA HS', '2023-07-12', 5, 'ng_ul', 100, 'ng_ul', 1, 70, 'laura.miller', 'Completed', 'PROJ-2023-004'),
('D24SA-ATL00010002', 'EXP-2023-004', '2023-07-10', 'dsDNA HS', '2023-07-12', 4.75, 'ng_ul', 95, 'ng_ul', 1, 65, 'laura.miller', 'Completed', 'PROJ-2023-004'),
('D23NA-ATL00030001', 'EXP-2023-005', '2023-08-20', 'dsDNA HS', '2023-08-22', 0.5, 'ng_ul', 10, 'ng_ul', 1, 80, 'nancy.clark', 'Completed', 'PROJ-2023-005'),
('D23NA-ATL00030002', 'EXP-2023-005', '2023-08-20', 'dsDNA HS', '2023-08-22', 0.4, 'ng_ul', 8, 'ng_ul', 1, 75, 'nancy.clark', 'Completed', 'PROJ-2023-005'),
('D23AR-ARC00010001', 'EXP-2023-008', '2023-11-20', 'dsDNA HS', '2023-11-23', 3, 'ng_ul', 60, 'ng_ul', 1, 50, 'rachel.gonzalez', 'Completed', 'PROJ-2023-008'),
('D23AR-ARC00010002', 'EXP-2023-008', '2023-11-20', 'dsDNA HS', '2023-11-23', 2.75, 'ng_ul', 55, 'ng_ul', 1, 45, 'rachel.gonzalez', 'Completed', 'PROJ-2023-008'),
('D24EU-NOR00010001', 'EXP-2023-009', '2024-01-05', 'dsDNA HS', '2024-01-07', 0.6, 'ng_ul', 12, 'ng_ul', 1, 70, 'jane.smith', 'Completed', 'PROJ-2023-009'),
('D24EU-NOR00010002', 'EXP-2023-009', '2024-01-05', 'dsDNA HS', '2024-01-07', 0.5, 'ng_ul', 10, 'ng_ul', 1, 65, 'jane.smith', 'Completed', 'PROJ-2023-009'),
('D24-00010001', 'EXP-2023-011', '2024-03-01', 'dsDNA HS', '2024-03-04', 3.5, 'ng_ul', 70, 'ng_ul', 1, 55, 'david.green', 'Completed', 'PROJ-2023-011'),
('D24-00010002', 'EXP-2023-011', '2024-03-01', 'dsDNA HS', '2024-03-04', 3.25, 'ng_ul', 65, 'ng_ul', 1, 50, 'david.green', 'Completed', 'PROJ-2023-011')
ON CONFLICT ("qubit_id", "measurement_date") DO NOTHING;

-- lab.tapestation (using generate_tapestation_id trigger)
-- Sample IDs must exist in lab.master_samples
INSERT INTO "lab"."tapestation" ("sample_id", "experiment_id", "experiment_date", "position", "measurement_date", "kit", "person_id", "status_id", "project_id") VALUES
('D23NA-ATL00010001', 'EXP-2023-001', '2023-03-05', 'A1', '2023-03-08', 'Genomic DNA ScreenTape', 'charlie.brown', 'Completed', 'PROJ-2023-001'),
('D23NA-ATL00010002', 'EXP-2023-001', '2023-03-05', 'A2', '2023-03-08', 'Genomic DNA ScreenTape', 'charlie.brown', 'Completed', 'PROJ-2023-001'),
('R23EU-MED00010001', 'EXP-2023-002', '2023-04-15', 'B1', '2023-04-19', 'RNA ScreenTape', 'grace.hall', 'Completed', 'PROJ-2023-002'),
('R23EU-MED00010002', 'EXP-2023-002', '2023-04-15', 'B2', '2023-04-19', 'RNA ScreenTape', 'grace.hall', 'Completed', 'PROJ-2023-002'),
('D23AR-ARC00010001', 'EXP-2023-008', '2023-11-20', 'C1', '2023-11-24', 'Genomic DNA ScreenTape', 'rachel.gonzalez', 'Completed', 'PROJ-2023-008'),
('D23AR-ARC00010002', 'EXP-2023-008', '2023-11-20', 'C2', '2023-11-24', 'Genomic DNA ScreenTape', 'rachel.gonzalez', 'Completed', 'PROJ-2023-008'),
('D24-00010001', 'EXP-2023-011', '2024-03-01', 'D1', '2024-03-05', 'Genomic DNA ScreenTape', 'david.green', 'Completed', 'PROJ-2023-011'),
('D24-00010002', 'EXP-2023-011', '2024-03-01', 'D2', '2024-03-05', 'Genomic DNA ScreenTape', 'david.green', 'Completed', 'PROJ-2023-011')
ON CONFLICT ("tapestation_id", "measurement_date") DO NOTHING;

-- lab.pcr (using generate_pcr_id trigger)
-- Sample IDs must exist in lab.master_samples, primer_id in lims.primers
INSERT INTO "lab"."pcr" ("experiment_id", "experiment_date", "sample_id", "position", "primer_id", "pcr_date", "person_id", "kit", "status_id", "project_id", "volume_reaction_ul") VALUES
('EXP-2023-001', '2023-03-05', 'D23NA-ATL00010001', 'A1', '16S_rRNA', '2023-03-10', 'alice.jones', 'DreamTaq Green', 'Completed', 'PROJ-2023-001', 25),
('EXP-2023-001', '2023-03-05', 'D23NA-ATL00010002', 'A2', '16S_rRNA', '2023-03-10', 'alice.jones', 'DreamTaq Green', 'Completed', 'PROJ-2023-001', 25),
('EXP-2023-003', '2023-06-01', 'D23AS-PAC00010001', 'B1', 'COI', '2023-06-12', 'henry.king', 'Phusion High-Fidelity', 'Completed', 'PROJ-2023-003', 50),
('EXP-2023-003', '2023-06-01', 'D23AS-PAC00010002', 'B2', 'COI', '2023-06-12', 'henry.king', 'Phusion High-Fidelity', 'Completed', 'PROJ-2023-003', 50),
('EXP-2023-012', '2024-04-10', 'D23NA-ATL00030001', 'C1', '18S_rRNA', '2024-04-15', 'mike.taylor', 'GoTaq Green', 'In Progress', 'PROJ-2023-012', 25),
('EXP-2023-012', '2024-04-10', 'D23NA-ATL00030002', 'C2', '18S_rRNA', '2024-04-15', 'mike.taylor', 'GoTaq Green', 'In Progress', 'PROJ-2023-012', 25),
('EXP-2023-016', '2024-08-01', 'D23NA-ATL00010001', 'D1', 'CytB', '2024-08-05', 'quinn.fisher', 'KAPA HiFi HotStart', 'In Progress', 'PROJ-2023-016', 50),
('EXP-2023-016', '2024-08-01', 'D23NA-ATL00010002', 'D2', 'CytB', '2024-08-05', 'quinn.fisher', 'KAPA HiFi HotStart', 'In Progress', 'PROJ-2023-016', 50),
('EXP-2023-018', '2024-10-20', 'D22OC-PAC00010001', 'E1', 'HSP70', '2024-10-25', 'john.doe', 'Platinum Taq', 'In Progress', 'PROJ-2023-018', 25),
('EXP-2023-018', '2024-10-20', 'D22OC-PAC00010002', 'E2', 'HSP70', '2024-10-25', 'john.doe', 'Platinum Taq', 'In Progress', 'PROJ-2023-018', 25)
ON CONFLICT ("pcr_id", "pcr_date") DO NOTHING;

-- lab.gelelectrophoresis (using generate_gelelectrophoresis_id trigger)
-- Sample IDs must exist in lab.master_samples
INSERT INTO "lab"."gelelectrophoresis" ("experiment_id", "experiment_date", "sample_id", "position", "ladder", "voltage", "band_size_bp", "gel_type", "run_time_minutes", "run_date", "person_id", "project_id") VALUES
('EXP-2023-001', '2023-03-05', 'D23NA-ATL00010001', 'Lane 1', '1kb Ladder', 100, 1500, 'Agarose', 60, '2023-03-11', 'charlie.brown', 'PROJ-2023-001'),
('EXP-2023-001', '2023-03-05', 'D23NA-ATL00010002', 'Lane 2', '1kb Ladder', 100, 1500, 'Agarose', 60, '2023-03-11', 'charlie.brown', 'PROJ-2023-001'),
('EXP-2023-003', '2023-06-01', 'D23AS-PAC00010001', 'Lane 3', '100bp Ladder', 120, 500, 'Agarose', 45, '2023-06-13', 'irene.lim', 'PROJ-2023-003'),
('EXP-2023-003', '2023-06-01', 'D23AS-PAC00010002', 'Lane 4', '100bp Ladder', 120, 500, 'Agarose', 45, '2023-06-13', 'irene.lim', 'PROJ-2023-003')
ON CONFLICT ("gelelectrophoresis_id", "run_date") DO NOTHING;

-- lab.qpcr (using generate_qpcr_id trigger)
-- Sample IDs must exist in lab.master_samples, primer_id in lims.primers
INSERT INTO "lab"."qpcr" ("experiment_id", "experiment_date", "sample_id", "position", "qpcr_date", "person_id", "primer_id", "ct_value", "inhibitor_test_result", "kit", "volume_ul", "status_id", "project_id") VALUES
('EXP-2023-003', '2023-06-01', 'D23AS-PAC00010001', 'A1', '2023-06-15', 'henry.king', 'COI', 22.5, 'Negative', 'SYBR Green', 20, 'Completed', 'PROJ-2023-003'),
('EXP-2023-003', '2023-06-01', 'D23AS-PAC00010002', 'A2', '2023-06-15', 'henry.king', 'COI', 23.1, 'Negative', 'SYBR Green', 20, 'Completed', 'PROJ-2023-003'),
('EXP-2023-005', '2023-08-20', 'D23NA-ATL00030001', 'B1', '2023-08-25', 'mike.taylor', '16S_rRNA', 28.0, 'Negative', 'TaqMan', 25, 'Completed', 'PROJ-2023-005'),
('EXP-2023-005', '2023-08-20', 'D23NA-ATL00030002', 'B2', '2023-08-25', 'mike.taylor', '16S_rRNA', 29.5, 'Negative', 'TaqMan', 25, 'Completed', 'PROJ-2023-005'),
('EXP-2023-010', '2024-02-15', 'D23AS-IND00020001', 'C1', '2024-02-20', 'kevin.scott', '18S_rRNA', 20.0, 'Negative', 'SYBR Green', 20, 'In Progress', 'PROJ-2023-010'),
('EXP-2023-010', '2024-02-15', 'D23AS-IND00020002', 'C2', '2024-02-20', 'kevin.scott', '18S_rRNA', 21.5, 'Negative', 'SYBR Green', 20, 'In Progress', 'PROJ-2023-010'),
('EXP-2023-015', '2024-07-10', 'D24SA-ATL00010001', 'D1', '16S_rRNA', '2024-07-15', 'peter.evans', 'TaqMan', 25.0, 'Negative', 'SYBR Green', 20, 'Completed', 'PROJ-2023-015'),
('EXP-2023-015', '2024-07-10', 'D24SA-ATL00010002', 'D2', '16S_rRNA', '2024-07-15', 'peter.evans', 'TaqMan', 26.5, 'Negative', 'SYBR Green', 20, 'Completed', 'PROJ-2023-015')
ON CONFLICT ("qpcr_id", "qpcr_date") DO NOTHING;

-- lab.library (using generate_library_id trigger)
-- Sample IDs must exist in lab.master_samples
INSERT INTO "lab"."library" ("experiment_id", "experiment_date", "sample_id", "library_name", "prep_date", "person_id", "library_prep_kit", "index_sequence", "read_length_bp", "project_id") VALUES
('EXP-2023-001', '2023-03-05', 'D23NA-ATL00010001', 'CodGutLib-001', '2023-03-20', 'john.doe', 'Illumina DNA Prep', 'ATGCAT', 150, 'PROJ-2023-001'),
('EXP-2023-001', '2023-03-05', 'D23NA-ATL00010002', 'CodGutLib-002', '2023-03-20', 'john.doe', 'Illumina DNA Prep', 'GCTAGC', 150, 'PROJ-2023-001'),
('EXP-2023-002', '2023-04-15', 'R23EU-MED00010001', 'DolphinSkinRNA-001', '2023-05-01', 'jane.smith', 'Illumina RNA Prep', 'TAGCTA', 100, 'PROJ-2023-002'),
('EXP-2023-002', '2023-04-15', 'R23EU-MED00010002', 'DolphinSkinRNA-002', '2023-05-01', 'jane.smith', 'Illumina RNA Prep', 'CGATCG', 100, 'PROJ-2023-002'),
('EXP-2023-004', '2023-07-10', 'D24SA-ATL00010001', 'DeepSeaSedLib-001', '2023-07-25', 'bob.white', 'Nextera XT', 'ATCGTA', 250, 'PROJ-2023-004'),
('EXP-2023-004', '2023-07-10', 'D24SA-ATL00010002', 'DeepSeaSedLib-002', '2023-07-25', 'bob.white', 'Nextera XT', 'TACGAT', 250, 'PROJ-2023-004'),
('EXP-2023-008', '2023-11-20', 'D23AR-ARC00010001', 'ArcticMicLib-001', '2023-12-10', 'henry.king', 'Illumina DNA Prep', 'GCAATG', 150, 'PROJ-2023-008'),
('EXP-2023-008', '2023-11-20', 'D23AR-ARC00010002', 'ArcticMicLib-002', '2023-12-10', 'henry.king', 'Illumina DNA Prep', 'TGCATC', 150, 'PROJ-2023-008'),
('EXP-2023-011', '2024-03-01', 'D24-00010001', 'WetlandPlantLib-001', '2024-03-20', 'laura.miller', 'Illumina DNA Prep', 'AGCTAG', 150, 'PROJ-2023-011'),
('EXP-2023-011', '2024-03-01', 'D24-00010002', 'WetlandPlantLib-002', '2024-03-20', 'laura.miller', 'Illumina DNA Prep', 'CTAGCT', 150, 'PROJ-2023-011')
ON CONFLICT ("library_id", "prep_date") DO NOTHING;

-- lab.sequencing (using generate_sequencing_id trigger)
-- Sample IDs must exist in lab.master_samples, library_id in lab.library
INSERT INTO "lab"."sequencing" ("experiment_id", "experiment_date", "library_id", "prep_date", "sample_id", "sequencing_date", "person_id", "sequencer", "flow_cell_id", "total_reads", "raw_data_path", "status_id", "project_id") VALUES
('EXP-2023-001', '2023-03-05', 'LIB_EXP-2023-001_D23NA-ATL00010001_001', '2023-03-20', 'D23NA-ATL00010001', '2023-03-25', 'john.doe', 'MiSeq', 'FC-12345', 1000000, '/data/raw/cod_gut_001', 'Completed', 'PROJ-2023-001'),
('EXP-2023-001', '2023-03-05', 'LIB_EXP-2023-001_D23NA-ATL00010002_001', '2023-03-20', 'D23NA-ATL00010002', '2023-03-25', 'john.doe', 'MiSeq', 'FC-12345', 980000, '/data/raw/cod_gut_002', 'Completed', 'PROJ-2023-001'),
('EXP-2023-002', '2023-04-15', 'LIB_EXP-2023-002_R23EU-MED00010001_001', '2023-05-01', 'R23EU-MED00010001', '2023-05-10', 'jane.smith', 'NextSeq', 'FC-67890', 5000000, '/data/raw/dolphin_skin_001', 'Completed', 'PROJ-2023-002'),
('EXP-2023-002', '2023-04-15', 'LIB_EXP-2023-002_R23EU-MED00010002_001', '2023-05-01', 'R23EU-MED00010002', '2023-05-10', 'jane.smith', 'NextSeq', 'FC-67890', 4800000, '/data/raw/dolphin_skin_002', 'Completed', 'PROJ-2023-002'),
('EXP-2023-004', '2023-07-10', 'LIB_EXP-2023-004_D24SA-ATL00010001_001', '2023-07-25', 'D24SA-ATL00010001', '2023-08-05', 'bob.white', 'NovaSeq', 'FC-ABCDE', 10000000, '/data/raw/deepsea_sed_001', 'In Progress', 'PROJ-2023-004'),
('EXP-2023-004', '2023-07-10', 'LIB_EXP-2023-004_D24SA-ATL00010002_001', '2023-07-25', 'D24SA-ATL00010002', '2023-08-05', 'bob.white', 'NovaSeq', 'FC-ABCDE', 9500000, '/data/raw/deepsea_sed_002', 'In Progress', 'PROJ-2023-004'),
('EXP-2023-008', '2023-11-20', 'LIB_EXP-2023-008_D23AR-ARC00010001_001', '2023-12-10', 'D23AR-ARC00010001', '2023-12-20', 'henry.king', 'MiSeq', 'FC-FGHIJ', 1200000, '/data/raw/arctic_mic_001', 'In Progress', 'PROJ-2023-008'),
('EXP-2023-008', '2023-11-20', 'LIB_EXP-2023-008_D23AR-ARC00010002_001', '2023-12-10', 'D23AR-ARC00010002', '2023-12-20', 'henry.king', 'MiSeq', 'FC-FGHIJ', 1150000, '/data/raw/arctic_mic_002', 'In Progress', 'PROJ-2023-008'),
('EXP-2023-011', '2024-03-01', 'LIB_EXP-2023-011_D24-00010001_001', '2024-03-20', 'D24-00010001', '2024-03-30', 'laura.miller', 'NextSeq', 'FC-KLMNO', 6000000, '/data/raw/wetland_plant_001', 'Completed', 'PROJ-2023-011'),
('EXP-2023-011', '2024-03-01', 'LIB_EXP-2023-011_D24-00010002_001', '2024-03-20', 'D24-00010002', '2024-03-30', 'laura.miller', 'NextSeq', 'FC-KLMNO', 5800000, '/data/raw/wetland_plant_002', 'Completed', 'PROJ-2023-011')
ON CONFLICT ("sequencing_id", "sequencing_date") DO NOTHING;

-- lab.datasets (using generate_dataset_id trigger)
INSERT INTO "lab"."datasets" ("source_type", "ecosystem_id", "region_id", "customer_id", "stored_location_id", "reception_date", "storage_path") VALUES
('Sequencing Output', 'OpenOcean', 'NA_Atl', 1, 'RM-E-01', '2023-04-01', '/data/processed/cod_gut_data'),
('Sequencing Output', 'Coastal', 'EU_Med', 2, 'RM-E-01', '2023-05-20', '/data/processed/dolphin_skin_data'),
('Sequencing Output', 'Coastal', 'AS_Pac', 3, 'RM-E-01', '2023-07-10', '/data/processed/prawn_gh_data'),
('Sequencing Output', 'DeepSea', 'SA_Atl', 4, 'RM-E-01', '2023-08-15', '/data/processed/deepsea_microbe_data'),
('Sequencing Output', 'Coastal', 'NA_Atl', 5, 'RM-E-01', '2023-09-10', '/data/processed/coastal_pathogen_data'),
('Sequencing Output', 'OpenOcean', 'AF_Ind', 6, 'RM-E-01', '2023-11-01', '/data/processed/marine_np_data'),
('Sequencing Output', 'CoralReef', 'OC_Pac', 7, 'RM-E-01', '2024-01-01', '/data/processed/coral_bleaching_data'),
('Sequencing Output', 'Polar', 'AR_Arc', 8, 'RM-E-01', '2024-01-15', '/data/processed/arctic_microbial_data'),
('Sequencing Output', 'Estuary', 'EU_Nor', 9, 'RM-E-01', '2024-02-10', '/data/processed/river_fish_diet_data'),
('Sequencing Output', 'Lake', 'AS_Ind', 10, 'RM-E-01', '2024-03-01', '/data/processed/invasive_species_data'),
('Sequencing Output', 'Wetland', 'SA_Pac', 11, 'RM-E-01', '2024-04-10', '/data/processed/wetland_plant_data'),
('Sequencing Output', 'Intertidal', 'AF_Atl', 12, 'RM-E-01', '2024-05-01', '/data/processed/algal_bloom_data'),
('Sequencing Output', 'UpwellingZone', 'OC_Ind', 13, 'RM-E-01', '2024-06-01', '/data/processed/ocean_primary_data'),
('Sequencing Output', 'SubmarineCanyon', 'AN_Ant', 14, 'RM-E-01', '2024-07-01', '/data/processed/deepsea_invert_data'),
('Sequencing Output', 'Fjord', 'EU_Bal', 15, 'RM-E-01', '2024-08-01', '/data/processed/fjord_sediment_data'),
('Sequencing Output', 'IceEdge', 'AS_Sou', 16, 'RM-E-01', '2024-09-01', '/data/processed/baltic_fish_genetics_data'),
('Sequencing Output', 'Lagoon', 'NA_Car', 17, 'RM-E-01', '2024-10-01', '/data/processed/caribbean_reef_data'),
('Sequencing Output', 'OpenOcean', 'AF_Red', 18, 'RM-E-01', '2024-11-01', '/data/processed/red_sea_coral_data'),
('Sequencing Output', 'Coastal', 'SA_Car', 19, 'RM-E-01', '2024-12-01', '/data/processed/black_sea_pollution_data'),
('Sequencing Output', 'DeepSea', 'EU_Bla', 20, 'RM-E-01', '2025-01-01', '/data/processed/global_plankton_data')
ON CONFLICT ("dataset_id", "reception_date") DO NOTHING;

-- ======================================================================
-- 4. Bioinformatics Schema Data
-- ======================================================================

-- bioinformatics.reference_databases
INSERT INTO "bioinformatics"."reference_databases" ("db_id", "db_name", "db_version", "url", "last_updated_date") VALUES
('DB-NCBI-NT', 'NCBI Nucleotide', '202310', 'https://www.ncbi.nlm.nih.gov/nucleotide/', '2023-10-01'),
('DB-SILVA-138', 'SILVA rRNA Database', '138.1', 'https://www.arb-silva.de/', '2023-05-15'),
('DB-UNITE-8.3', 'UNITE Fungal ITS Database', '8.3', 'https://unite.ut.ee/', '2023-07-01'),
('DB-BOLD', 'Barcode of Life Data System', '4.0', 'http://www.boldsystems.org/', '2023-09-01'),
('DB-GTDB', 'Genome Taxonomy Database', 'R207', 'https://gtdb.ecogenomic.org/', '2023-11-01'),
('DB-IMGT', 'IMGT/GENE-DB', '2023-4', 'https://www.imgt.org/', '2023-04-01'),
('DB-KEGG', 'KEGG Pathway Database', '2023-01', 'https://www.genome.jp/kegg/', '2023-01-01'),
('DB-PFAM', 'Pfam Protein Families', '35.0', 'https://pfam.xfam.org/', '2023-06-01'),
('DB-SWISSPROT', 'Swiss-Prot Protein Database', '2023-03', 'https://www.uniprot.org/', '2023-03-01'),
('DB-ENZYME', 'ENZYME database', '2023-02', 'https://enzyme.expasy.org/', '2023-02-01'),
('DB-GO', 'Gene Ontology', '2023-08', 'http://geneontology.org/', '2023-08-01'),
('DB-MIRBASE', 'miRBase microRNA Database', '22.1', 'https://www.mirbase.org/', '2023-10-01'),
('DB-PATRIC', 'PATRIC Bacterial Bioinformatics Resource Center', '3.6.12', 'https://www.patricbrc.org/', '2023-12-01'),
('DB-VIRUS', 'Virus-Host DB', '2023-09', 'https://www.genome.jp/virushostdb/', '2023-09-01'),
('DB-PLANT_TFDB', 'Plant Transcription Factor Database', '5.0', 'http://planttfdb.gao-lab.org/', '2023-07-01'),
('DB-DRUG_BANK', 'DrugBank', '5.1.10', 'https://go.drugbank.com/', '2023-05-01'),
('DB-CHEMBL', 'ChEMBL', '33', 'https://www.ebi.ac.uk/chembl/', '2023-04-01'),
('DB-PUBCHEM', 'PubChem', '2023-11', 'https://pubchem.ncbi.nlm.nih.gov/', '2023-11-01'),
('DB-PDB', 'Protein Data Bank', '2023-12', 'https://www.rcsb.org/', '2023-12-01'),
('DB-STRING', 'STRING protein-protein interaction database', '12.0', 'https://string-db.org/', '2024-01-01')
ON CONFLICT ("db_id") DO NOTHING;

-- bioinformatics.analysis_pipelines (using generate_pipeline_id trigger)
INSERT INTO "bioinformatics"."analysis_pipelines" ("pipeline_name", "version", "repository_link") VALUES
('16S_Amplicon_Pipeline', '1.0.0', 'https://github.com/lab/16S_pipeline'),
('RNA_Seq_Quantification', '2.1.0', 'https://github.com/lab/rnaseq_pipeline'),
('eDNA_Metabarcoding', '1.5.0', 'https://github.com/lab/eDNA_pipeline'),
('Genome_Assembly_Pipeline', '3.0.0', 'https://github.com/lab/assembly_pipeline'),
('Variant_Calling_Pipeline', '1.2.0', 'https://github.com/lab/variant_pipeline'),
('Metagenomics_Taxonomic_Profiling', '1.0.0', 'https://github.com/lab/metagenomics_pipeline'),
('Transcriptome_Assembly', '1.0.0', 'https://github.com/lab/transcriptome_pipeline'),
('Proteomics_Analysis', '1.0.0', 'https://github.com/lab/proteomics_pipeline'),
('CRISPR_Target_Design', '1.0.0', 'https://github.com/lab/crispr_pipeline'),
('Phylogenetic_Tree_Construction', '1.0.0', 'https://github.com/lab/phylogeny_pipeline'),
('Functional_Annotation', '1.0.0', 'https://github.com/lab/functional_annotation'),
('Comparative_Genomics', '1.0.0', 'https://github.com/lab/comparative_genomics'),
('Epigenetics_Analysis', '1.0.0', 'https://github.com/lab/epigenetics_pipeline'),
('Single_Cell_RNA_Seq', '1.0.0', 'https://github.com/lab/single_cell_rnaseq'),
('Spatial_Transcriptomics', '1.0.0', 'https://github.com/lab/spatial_transcriptomics'),
('Machine_Learning_Genomics', '1.0.0', 'https://github.com/lab/ml_genomics'),
('Drug_Discovery_Screening', '1.0.0', 'https://github.com/lab/drug_screening'),
('Structural_Bioinformatics', '1.0.0', 'https://github.com/lab/structural_bioinfo'),
('Population_Genetics', '1.0.0', 'https://github.com/lab/pop_genetics'),
('Environmental_DNA_Quantification', '1.0.0', 'https://github.com/lab/edna_quant_pipeline')
ON CONFLICT ("pipeline_id") DO NOTHING;

-- bioinformatics.analysis_runs (using generate_analysis_run_id trigger)
-- sequencing_id and sequencing_date must exist in lab.sequencing
INSERT INTO "bioinformatics"."analysis_runs" ("pipeline_id", "sequencing_id", "sequencing_date", "person_id", "run_date", "parameters_jsonb", "reference_db_id", "clustering_threshold", "final_output_path") VALUES
('23000001', 'SEQ_EXP-2023-001_D23NA-ATL00010001_001', '2023-03-25', 'emily.black', '2023-04-01 10:00:00', '{"min_quality": 30, "trim_length": 140}', 'DB-SILVA-138', 0.97, '/results/cod_gut_001_16S'),
('23000001', 'SEQ_EXP-2023-001_D23NA-ATL00010002_001', '2023-03-25', 'emily.black', '2023-04-01 11:00:00', '{"min_quality": 30, "trim_length": 140}', 'DB-SILVA-138', 0.97, '/results/cod_gut_002_16S'),
('23000002', 'SEQ_EXP-2023-002_R23EU-MED00010001_001', '2023-05-10', 'bob.white', '2023-05-15 09:00:00', '{"aligner": "STAR", "quant_method": "Salmon"}', 'DB-NCBI-NT', NULL, '/results/dolphin_skin_001_rnaseq'),
('23000002', 'SEQ_EXP-2023-002_R23EU-MED00010002_001', '2023-05-10', 'bob.white', '2023-05-15 10:00:00', '{"aligner": "STAR", "quant_method": "Salmon"}', 'DB-NCBI-NT', NULL, '/results/dolphin_skin_002_rnaseq'),
('23000003', 'SEQ_EXP-2023-004_D24SA-ATL00010001_001', '2023-08-05', 'emily.black', '2023-08-10 14:00:00', '{"primer_set": "COI", "min_reads": 100}', 'DB-BOLD', 0.98, '/results/deepsea_sed_001_edna'),
('23000003', 'SEQ_EXP-2023-004_D24SA-ATL00010002_001', '2023-08-05', 'emily.black', '2023-08-10 15:00:00', '{"primer_set": "COI", "min_reads": 100}', 'DB-BOLD', 0.98, '/results/deepsea_sed_002_edna'),
('23000001', 'SEQ_EXP-2023-008_D23AR-ARC00010001_001', '2023-12-20', 'bob.white', '2024-01-05 10:00:00', '{"min_quality": 25, "trim_length": 130}', 'DB-SILVA-138', 0.97, '/results/arctic_mic_001_16S'),
('23000001', 'SEQ_EXP-2023-008_D23AR-ARC00010002_001', '2023-12-20', 'bob.white', '2024-01-05 11:00:00', '{"min_quality": 25, "trim_length": 130}', 'DB-SILVA-138', 0.97, '/results/arctic_mic_002_16S'),
('23000002', 'SEQ_EXP-2023-011_D24-00010001_001', '2024-03-30', 'emily.black', '2024-04-10 09:00:00', '{"aligner": "HISAT2", "quant_method": "featureCounts"}', 'DB-NCBI-NT', NULL, '/results/wetland_plant_001_rnaseq'),
('23000002', 'SEQ_EXP-2023-011_D24-00010002_001', '2024-03-30', 'emily.black', '2024-04-10 10:00:00', '{"aligner": "HISAT2", "quant_method": "featureCounts"}', 'DB-NCBI-NT', NULL, '/results/wetland_plant_002_rnaseq')
ON CONFLICT ("run_id", "run_date") DO NOTHING;

-- bioinformatics.edna_assignments (using generate_edna_assignment_id trigger)
-- run_id and run_date must exist in bioinformatics.analysis_runs
-- sample_id must exist in lab.master_samples
-- taxon_id must exist in reference.taxon
INSERT INTO "bioinformatics"."edna_assignments" ("run_id", "run_date", "sample_id", "taxon_id", "read_count", "confidence") VALUES
('23000001', '2023-04-01 10:00:00', 'D23NA-ATL00010001', 'Gadus_morhua', 50000, 0.99),
('23000001', '2023-04-01 10:00:00', 'D23NA-ATL00010001', 'Penaeus_monodon', 1000, 0.75),
('23000001', '2023-04-01 11:00:00', 'D23NA-ATL00010002', 'Gadus_morhua', 48000, 0.98),
('23000001', '2023-04-01 11:00:00', 'D23NA-ATL00010002', 'Tursiops_truncatus', 500, 0.60),
('23000003', '2023-08-10 14:00:00', 'D24SA-ATL00010001', 'Penaeus_monodon', 15000, 0.95),
('23000003', '2023-08-10 14:00:00', 'D24SA-ATL00010001', 'Gadus_morhua', 200, 0.50),
('23000003', '2023-08-10 15:00:00', 'D24SA-ATL00010002', 'Penaeus_monodon', 14000, 0.94),
('23000003', '2023-08-10 15:00:00', 'D24SA-ATL00010002', 'Tursiops_truncatus', 100, 0.40),
('23000001', '2024-01-05 10:00:00', 'D23AR-ARC00010001', 'Gadus_morhua', 10000, 0.80),
('23000001', '2024-01-05 10:00:00', 'D23AR-ARC00010001', 'Penaeus_monodon', 50, 0.30),
('23000001', '2024-01-05 11:00:00', 'D23AR-ARC00010002', 'Gadus_morhua', 9500, 0.78),
('23000001', '2024-01-05 11:00:00', 'D23AR-ARC00010002', 'Tursiops_truncatus', 20, 0.20),
('23000002', '2024-04-10 09:00:00', 'D24-00010001', 'Gadus_morhua', 500, 0.65),
('23000002', '2024-04-10 09:00:00', 'D24-00010001', 'Penaeus_monodon', 10, 0.10),
('23000002', '2024-04-10 10:00:00', 'D24-00010002', 'Gadus_morhua', 480, 0.63),
('23000002', '2024-04-10 10:00:00', 'D24-00010002', 'Tursiops_truncatus', 5, 0.05)
ON CONFLICT ("assignment_id") DO NOTHING;

-- ======================================================================
-- 5. Final Audit Log and Materialized View Refresh
-- ======================================================================

-- Refresh materialized views after data insertion
REFRESH MATERIALIZED VIEW "lab"."monthly_sample_reception_mv";

-- Reset the user for audit log purposes (optional)
RESET lims.current_person_id;

-- Verify some data (optional, for quick check)
-- SELECT COUNT(*) FROM "lab"."samples";
-- SELECT COUNT(*) FROM "bioinformatics"."analysis_runs";
-- SELECT * FROM "lab"."samples" LIMIT 5;
-- SELECT * FROM "bioinformatics"."analysis_runs" LIMIT 5;


























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

-- ==========================================================================================================
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
JOIN (SELECT experiment_id, experiment_date FROM "lab"."experiments" ORDER BY RANDOM() LIMIT 1) e ON TRUE
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
JOIN (SELECT experiment_id, experiment_date FROM "lab"."experiments" ORDER BY RANDOM() LIMIT 1) e ON TRUE
ON CONFLICT ("protocol_run_id") DO NOTHING;


-- lab.sampling (sampling_id generated by trigger, sampling_date is PK & partitioning, uses experiment_id, experiment_date, project_id, cruise_id, region_id, ecosystem_id, vessel_id, customer_id, unit_id, external_contacts, status_id)
INSERT INTO "lab"."sampling" (
    "sampling_id", "experiment_id", "experiment_date", "project_id", "cruise_id", "region_id", "ecosystem_id",
    "vessel_id", "customer_id", "sampling_date", "geom", "fishing_start_geom", "fishing_end_geom", "location_name", "depth_m",
    "start_at", "end_at", "temperature_atmospheric_c", "weather", "wind_speed", "wind_unit_id",
    "temperature_sampling_depth_c", "salinity", "salinity_unit_id", "pressure", "pressure_unit_id",
    "oxygen", "oxygen_unit_id", "conductivity", "conductivity_unit_id", "ph", "nitrate_mg_l",
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
    (SELECT vessel_id FROM "reference"."vessel" ORDER BY RANDOM() LIMIT 1), -- 8
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
    (RANDOM() * 20)::NUMERIC,        -- 22
    'PSU',                           -- 23
    (RANDOM() * 10)::NUMERIC,        -- 24
    'dbar',                          -- 25
    (RANDOM() * 10)::NUMERIC,        -- 26
    'mg_l',                          -- 27
    (RANDOM() * 50)::NUMERIC,        -- 28
    'S_m',                           -- 29
    (RANDOM() * 14)::NUMERIC,        -- 30
    (RANDOM() * 10)::NUMERIC,        -- 31
    (RANDOM() * 2)::NUMERIC,         -- 32
    (RANDOM() * 500)::NUMERIC,       -- 33
    (RANDOM() * 10)::NUMERIC,        -- 34
    (RANDOM() * 2)::NUMERIC,         -- 35
    (RANDOM() * 360)::NUMERIC,       -- 36
    CASE (s % 3) WHEN 0 THEN 'High' WHEN 1 THEN 'Low' ELSE 'Mid' END, -- 37
    (RANDOM() * 2000)::NUMERIC,      -- 38
    CASE (s % 3) WHEN 0 THEN 'Calm' WHEN 1 THEN 'Moderate' ELSE 'Rough' END, -- 39
    (RANDOM() * 100)::NUMERIC,       -- 40
    (SELECT sample_type_id FROM "reference"."samples_type" ORDER BY RANDOM() LIMIT 1), -- 41
    'Formalin',                      -- 42
    (RANDOM() * 100)::NUMERIC,       -- 43
    (RANDOM() * 5)::NUMERIC,         -- 44
    (SELECT equipment_id FROM "lims"."equipment" ORDER BY RANDOM() LIMIT 1), -- 45
    (CURRENT_DATE - (s * 3 || ' days')::INTERVAL)::DATE, -- 46
    (RANDOM() * 50)::NUMERIC,        -- 47
    (CURRENT_DATE - (s % 730 || ' days')::INTERVAL)::DATE, -- 48
    (NOW() - (s % 60 || ' minutes')::INTERVAL)::TIME, -- 49
    CASE (s % 2) WHEN 0 THEN 'Trawl' ELSE 'Net' END, -- 50
    'Gear' || LPAD((s%5+1)::TEXT,1,'0'), -- 51
    (RANDOM() * 120)::NUMERIC,       -- 52
    'min',                           -- 53
    (RANDOM() * 5)::NUMERIC,         -- 54
    'km_h',                          -- 55
    (RANDOM() * 1000)::NUMERIC,      -- 56
    (RANDOM() * 500)::NUMERIC,       -- 57
    'Catch notes for ' || s,         -- 58
    (RANDOM() * 180)::NUMERIC,       -- 59
    (SELECT contact_id FROM "lims"."external_contacts" ORDER BY RANDOM() LIMIT 1), -- 60
    (SELECT status_id FROM "reference"."status" ORDER BY RANDOM() LIMIT 1), -- 61
    'Sampling event for demo ' || s, -- 62
    NULL,                            -- 63: attachment -- Changed from bytea literal to NULL
    NULL                             -- 64: attachment_link -- Changed from URL to NULL
FROM generate_series(1, 100) s
JOIN (SELECT experiment_id, experiment_date FROM "lab"."experiments" ORDER BY RANDOM() LIMIT 1) e ON TRUE
ON CONFLICT ("sampling_id", "sampling_date") DO NOTHING;


-- lab.master_samples is populated by triggers on lab.samples and child sample tables. NO DIRECT INSERT.

-- lab.samples (sample_id generated by trigger, sampling_date is PK & partitioning, uses master_samples (implicitly), sampling, storage, personal, sample_type, status, workflow, workflow_step, project, customer)
INSERT INTO "lab"."samples" (
    "sample_id", "external_name", "parent_sample_id", "sampling_id", "sampling_date",
    "storage_id", "storage_position", "sampler_person_id", "receiver_person_id", "reception_date",
    "transport", "conservation_buffer", "sample_type_id", "sample_status_id", "workflow_id",
    "step_id", "project_id", "customer_id", "notes"
)
SELECT
    'SAM' || LPAD(s::TEXT, 4, '0'),
    'External-Sample-' || s,
    NULL, -- For root samples; can link to other samples later for derived ones
    (SELECT sampling_id FROM "lab"."sampling" ORDER BY RANDOM() LIMIT 1),
    (SELECT sampling_date FROM "lab"."sampling" WHERE sampling_id = (SELECT sampling_id FROM "lab"."sampling" ORDER BY RANDOM() LIMIT 1)),
    (SELECT storage_id FROM "lab"."storage" ORDER BY RANDOM() LIMIT 1),
    'Pos-' || LPAD(s::TEXT, 3, '0'),
    (SELECT person_id FROM "reference"."personal" ORDER BY RANDOM() LIMIT 1),
    (SELECT person_id FROM "reference"."personal" ORDER BY RANDOM() LIMIT 1),
    (CURRENT_DATE - (s % 730 || ' days')::INTERVAL)::DATE,
    CASE (s % 3) WHEN 0 THEN 'Courier' WHEN 1 THEN 'Lab Transfer' ELSE 'Hand Carry' END,
    'Ethanol',
    (SELECT sample_type_id FROM "reference"."samples_type" ORDER BY RANDOM() LIMIT 1),
    (SELECT status_id FROM "reference"."status" ORDER BY RANDOM() LIMIT 1),
    (SELECT workflow_id FROM "lims"."workflows" ORDER BY RANDOM() LIMIT 1),
    (SELECT step_id FROM "lims"."workflow_steps" ORDER BY RANDOM() LIMIT 1),
    (SELECT project_id FROM "lims"."projects" ORDER BY RANDOM() LIMIT 1),
    (SELECT customer_id FROM "lims"."customers" ORDER BY RANDOM() LIMIT 1),
    'Demo sample for testing purposes ' || s
FROM generate_series(1, 100) s
ON CONFLICT ("sample_id", "sampling_date") DO NOTHING;


-- lab.fishing (fishing_id generated by trigger, uses sampling_id, sampling_date, taxon_id, customer_id)
INSERT INTO "lab"."fishing" ("sampling_id", "sampling_date", "taxon_id", "catch_kg", "catch_fish", "customer_id", "notes")
SELECT
    samp.sampling_id,
    samp.sampling_date,
    (SELECT taxon_id FROM "reference"."taxon" WHERE rank = 'species' ORDER BY RANDOM() LIMIT 1),
    (RANDOM() * 100)::NUMERIC,
    (RANDOM() * 500)::NUMERIC,
    (SELECT customer_id FROM "lims"."customers" ORDER BY RANDOM() LIMIT 1),
    'Fishing catch record for demo.'
FROM generate_series(1, 100) s
JOIN (SELECT sampling_id, sampling_date FROM "lab"."sampling" ORDER BY RANDOM() LIMIT 1) samp ON TRUE
ON CONFLICT ("fishing_id") DO NOTHING;


-- lab.storage_log (log_id is serial, uses sample_id, sample_sampling_date, storage_id, person_id)
INSERT INTO "lab"."storage_log" ("sample_id", "sample_sampling_date", "storage_id", "person_id", "move_date", "status", "storage_position", "notes")
SELECT
    sam.sample_id,
    sam.sampling_date,
    (SELECT storage_id FROM "lab"."storage" ORDER BY RANDOM() LIMIT 1),
    (SELECT person_id FROM "reference"."personal" ORDER BY RANDOM() LIMIT 1),
    (CURRENT_TIMESTAMP - (s || ' hours')::INTERVAL)::TIMESTAMPTZ,
    (SELECT status_id FROM "reference"."status" ORDER BY RANDOM() LIMIT 1),
    'S_POS-' || LPAD(s::TEXT, 3, '0'),
    'Demo storage log entry.'
FROM generate_series(1, 100) s
JOIN (SELECT sample_id, sampling_date FROM "lab"."samples" ORDER BY RANDOM() LIMIT 1) sam ON TRUE;


-- lab.fish (sample_id is direct PK, uses master_samples, experiment_id, experiment_date, species_id, storage_id, project_id, customer_id)
INSERT INTO "lab"."fish" (
    "sample_id", "parent_sample_id", "experiment_id", "experiment_date", "species_id",
    "total_length_mm", "fork_length_mm", "standard_length_mm", "weight_g", "sex",
    "maturity_stage", "stomach_contents", "disease_info", "tag_id", "storage_id",
    "storage_position", "project_id", "customer_id", "notes"
)
SELECT
    (SELECT sample_id FROM "lab"."samples" WHERE sample_type_id = 'Fish' ORDER BY RANDOM() LIMIT 1),
    (SELECT sample_id FROM "lab"."samples" WHERE sample_type_id = 'Fish' ORDER BY RANDOM() LIMIT 1), -- Parent can be another fish or sampling sample
    e.experiment_id,
    e.experiment_date,
    (SELECT species_id FROM "reference"."species" ORDER BY RANDOM() LIMIT 1),
    (RANDOM() * 1000)::NUMERIC,
    (RANDOM() * 900)::NUMERIC,
    (RANDOM() * 800)::NUMERIC,
    (RANDOM() * 5000)::NUMERIC,
    CASE (s % 3) WHEN 0 THEN 'Male' WHEN 1 THEN 'Female' ELSE 'Undetermined' END,
    'Stage ' || (s % 5 + 1),
    'Stomach contents data.',
    'Disease ' || s,
    'TAG-' || LPAD(s::TEXT, 4, '0'),
    (SELECT storage_id FROM "lab"."storage" ORDER BY RANDOM() LIMIT 1),
    'FishPos-' || LPAD(s::TEXT, 3, '0'),
    (SELECT project_id FROM "lims"."projects" ORDER BY RANDOM() LIMIT 1),
    (SELECT customer_id FROM "lims"."customers" ORDER BY RANDOM() LIMIT 1),
    'Demo fish sample.'
FROM generate_series(1, 100) s
JOIN (SELECT experiment_id, experiment_date FROM "lab"."experiments" ORDER BY RANDOM() LIMIT 1) e ON TRUE
ON CONFLICT ("sample_id") DO UPDATE SET "parent_sample_id" = EXCLUDED."parent_sample_id";


-- lab.tissue (sample_id is direct PK, uses master_samples, experiment_id, experiment_date, storage_id, project_id)
INSERT INTO "lab"."tissue" (
    "sample_id", "parent_sample_id", "experiment_id", "experiment_date", "weight_mg",
    "tissue_type", "preservation_method", "storage_id", "storage_position", "project_id", "notes"
)
SELECT
    (SELECT sample_id FROM "lab"."samples" WHERE sample_type_id = 'Tissue' ORDER BY RANDOM() LIMIT 1),
    (SELECT sample_id FROM "lab"."samples" WHERE sample_type_id IN ('Fish', 'Tissue') ORDER BY RANDOM() LIMIT 1),
    e.experiment_id,
    e.experiment_date,
    (RANDOM() * 1000)::NUMERIC,
    CASE (s % 3) WHEN 0 THEN 'Muscle' WHEN 1 THEN 'Liver' ELSE 'Fin Clip' END,
    'RNALater',
    (SELECT storage_id FROM "lab"."storage" ORDER BY RANDOM() LIMIT 1),
    'TissuePos-' || LPAD(s::TEXT, 3, '0'),
    (SELECT project_id FROM "lims"."projects" ORDER BY RANDOM() LIMIT 1),
    'Demo tissue sample.'
FROM generate_series(1, 100) s
JOIN (SELECT experiment_id, experiment_date FROM "lab"."experiments" ORDER BY RANDOM() LIMIT 1) e ON TRUE
ON CONFLICT ("sample_id") DO UPDATE SET "parent_sample_id" = EXCLUDED."parent_sample_id";


-- lab.otoliths (otolith_id generated by trigger, uses sample_id, person_id, project_id)
INSERT INTO "lab"."otoliths" ("sample_id", "reader_person_id", "side", "age_reading_years", "confidence", "reading_date", "project_id", "notes")
SELECT
    (SELECT sample_id FROM "lab"."samples" WHERE sample_type_id = 'Fish' ORDER BY RANDOM() LIMIT 1),
    (SELECT person_id FROM "reference"."personal" ORDER BY RANDOM() LIMIT 1),
    CASE (s % 2) WHEN 0 THEN 'Left' ELSE 'Right' END,
    (RANDOM() * 20)::NUMERIC,
    (RANDOM())::NUMERIC,
    (CURRENT_DATE - (s % 365 || ' days')::INTERVAL)::DATE,
    (SELECT project_id FROM "lims"."projects" ORDER BY RANDOM() LIMIT 1),
    'Otolith reading demo.'
FROM generate_series(1, 100) s
ON CONFLICT ("sample_id", "reader_person_id", "side") DO NOTHING;


-- lab.dna (sample_id is direct PK, uses master_samples, experiment_id, experiment_date, storage_id, project_id)
INSERT INTO "lab"."dna" (
    "sample_id", "parent_sample_id", "experiment_id", "experiment_date", "volume_ul",
    "concentration_ng_ul", "a260_280", "a260_230", "extraction_method", "preservation_method",
    "extraction_date", "extraction_number", "storage_id", "storage_position", "project_id", "notes"
)
SELECT
    (SELECT sample_id FROM "lab"."samples" WHERE sample_type_id = 'DNA' ORDER BY RANDOM() LIMIT 1),
    (SELECT sample_id FROM "lab"."samples" WHERE sample_type_id IN ('Tissue', 'DNA') ORDER BY RANDOM() LIMIT 1),
    e.experiment_id,
    e.experiment_date,
    (RANDOM() * 100)::NUMERIC,
    (RANDOM() * 50)::NUMERIC,
    (RANDOM() * 0.5 + 1.8)::NUMERIC,
    (RANDOM() * 0.5 + 1.8)::NUMERIC,
    'Qiagen DNeasy',
    'Frozen -80C',
    (CURRENT_DATE - (s % 365 || ' days')::INTERVAL)::DATE,
    (s % 5 + 1),
    (SELECT storage_id FROM "lab"."storage" ORDER BY RANDOM() LIMIT 1),
    'DNAPos-' || LPAD(s::TEXT, 3, '0'),
    (SELECT project_id FROM "lims"."projects" ORDER BY RANDOM() LIMIT 1),
    'Demo DNA sample.'
FROM generate_series(1, 100) s
JOIN (SELECT experiment_id, experiment_date FROM "lab"."experiments" ORDER BY RANDOM() LIMIT 1) e ON TRUE
ON CONFLICT ("sample_id") DO UPDATE SET "parent_sample_id" = EXCLUDED."parent_sample_id";


-- lab.rna (sample_id is direct PK, uses master_samples, experiment_id, experiment_date, storage_id, project_id)
INSERT INTO "lab"."rna" (
    "sample_id", "parent_sample_id", "experiment_id", "experiment_date", "volume_ul",
    "concentration_ng_ul", "a260_280", "a260_230", "extraction_method", "preservation_method",
    "extraction_date", "extraction_number", "storage_id", "storage_position", "project_id", "notes"
)
SELECT
    (SELECT sample_id FROM "lab"."samples" WHERE sample_type_id = 'RNA' ORDER BY RANDOM() LIMIT 1),
    (SELECT sample_id FROM "lab"."samples" WHERE sample_type_id IN ('Tissue', 'RNA') ORDER BY RANDOM() LIMIT 1),
    e.experiment_id,
    e.experiment_date,
    (RANDOM() * 100)::NUMERIC,
    (RANDOM() * 50)::NUMERIC,
    (RANDOM() * 0.5 + 1.9)::NUMERIC,
    (RANDOM() * 0.5 + 1.5)::NUMERIC,
    'Trizol',
    'Frozen -80C',
    (CURRENT_DATE - (s % 365 || ' days')::INTERVAL)::DATE,
    (s % 5 + 1),
    (SELECT storage_id FROM "lab"."storage" ORDER BY RANDOM() LIMIT 1),
    'RNAPos-' || LPAD(s::TEXT, 3, '0'),
    (SELECT project_id FROM "lims"."projects" ORDER BY RANDOM() LIMIT 1),
    'Demo RNA sample.'
FROM generate_series(1, 100) s
JOIN (SELECT experiment_id, experiment_date FROM "lab"."experiments" ORDER BY RANDOM() LIMIT 1) e ON TRUE
ON CONFLICT ("sample_id") DO UPDATE SET "parent_sample_id" = EXCLUDED."parent_sample_id";


-- lab.sediments (sample_id is direct PK, uses master_samples, experiment_id, experiment_date, volume_unit_id, storage_id, project_id)
INSERT INTO "lab"."sediments" (
    "sample_id", "parent_sample_id", "experiment_id", "experiment_date", "volume", "volume_unit_id",
    "depth_m", "sampling_method", "conservation_buffer", "storage_id", "storage_position",
    "external_name", "notes"
)
SELECT
    (SELECT sample_id FROM "lab"."samples" WHERE sample_type_id = 'Sediments' ORDER BY RANDOM() LIMIT 1),
    (SELECT sample_id FROM "lab"."samples" WHERE sample_type_id = 'Sediments' ORDER BY RANDOM() LIMIT 1),
    e.experiment_id,
    e.experiment_date,
    (RANDOM() * 10)::NUMERIC,
    'l', -- Assuming 'l' unit exists
    (RANDOM() * 500)::NUMERIC,
    'Grab Sampler',
    'None',
    (SELECT storage_id FROM "lab"."storage" ORDER BY RANDOM() LIMIT 1),
    'SedPos-' || LPAD(s::TEXT, 3, '0'),
    'External Sed ' || s,
    (SELECT project_id FROM "lims"."projects" ORDER BY RANDOM() LIMIT 1)
FROM generate_series(1, 100) s
JOIN (SELECT experiment_id, experiment_date FROM "lab"."experiments" ORDER BY RANDOM() LIMIT 1) e ON TRUE
ON CONFLICT ("sample_id") DO UPDATE SET "parent_sample_id" = EXCLUDED."parent_sample_id";


-- lab.water (sample_id is direct PK, uses master_samples, experiment_id, experiment_date, storage_id, project_id)
INSERT INTO "lab"."water" (
    "sample_id", "parent_sample_id", "experiment_id", "experiment_date", "volume_l", "filter",
    "filter_pore_size_um", "depth_m", "sampling_method", "conservation_buffer", "storage_id",
    "storage_position", "notes", "project_id"
)
SELECT
    (SELECT sample_id FROM "lab"."samples" WHERE sample_type_id = 'Water' ORDER BY RANDOM() LIMIT 1),
    (SELECT sample_id FROM "lab"."samples" WHERE sample_type_id = 'Water' ORDER BY RANDOM() LIMIT 1),
    e.experiment_id,
    e.experiment_date,
    (RANDOM() * 50)::NUMERIC,
    'GF/F',
    0.7,
    (RANDOM() * 100)::NUMERIC,
    'Niskin Bottle',
    'Filtered',
    (SELECT storage_id FROM "lab"."storage" ORDER BY RANDOM() LIMIT 1),
    'WaterPos-' || LPAD(s::TEXT, 3, '0'),
    'Demo water sample.',
    (SELECT project_id FROM "lims"."projects" ORDER BY RANDOM() LIMIT 1)
FROM generate_series(1, 100) s
JOIN (SELECT experiment_id, experiment_date FROM "lab"."experiments" ORDER BY RANDOM() LIMIT 1) e ON TRUE
ON CONFLICT ("sample_id") DO UPDATE SET "parent_sample_id" = EXCLUDED."parent_sample_id";


-- lab.experiments_samples (uses experiment_id, experiment_date, sample_id)
INSERT INTO "lab"."experiments_samples" ("experiment_id", "experiment_date", "sample_id", "notes")
SELECT
    e.experiment_id,
    e.experiment_date,
    (SELECT sample_id FROM "lab"."samples" ORDER BY RANDOM() LIMIT 1),
    'Link between experiment and sample.'
FROM generate_series(1, 100) s
JOIN (SELECT experiment_id, experiment_date FROM "lab"."experiments" ORDER BY RANDOM() LIMIT 1) e ON TRUE
ON CONFLICT ("experiment_id", "sample_id", "experiment_date") DO NOTHING;


-- lab.dissections (dissection_id generated by trigger, dissection_date is PK & partitioning, uses sample_id, person_id, status_id)
INSERT INTO "lab"."dissections" (
    "sample_id", "person_id", "dissection_date", "stomach_contents_jsonb",
    "gonad_weight_g", "liver_weight_g", "notes", "status_id"
)
SELECT
    (SELECT sample_id FROM "lab"."samples" WHERE sample_type_id = 'Fish' ORDER BY RANDOM() LIMIT 1),
    (SELECT person_id FROM "reference"."personal" ORDER BY RANDOM() LIMIT 1),
    (CURRENT_DATE - (s % 365 || ' days')::INTERVAL)::DATE,
    '{"items": ["fish", "crustaceans"], "count": ' || (s % 10 + 1) || '}'::jsonb,
    (RANDOM() * 10)::NUMERIC,
    (RANDOM() * 5)::NUMERIC,
    'Demo dissection notes.',
    (SELECT status_id FROM "reference"."status" ORDER BY RANDOM() LIMIT 1)
FROM generate_series(1, 100) s;


-- lab.extraction (extraction_id generated by trigger, extraction_date is PK & partitioning, uses experiment_id, experiment_date, sample_id, parent_sample_id, sample_type_id, extracted_dna_sample_id, extracted_rna_sample_id, person_id, status_id, storage_id, project_id)
INSERT INTO "lab"."extraction" (
    "experiment_id", "experiment_date", "sample_id", "parent_sample_id", "sample_type_id",
    "extracted_dna_sample_id", "extracted_rna_sample_id", "extraction_date", "person_id", "kit",
    "elution_volume_ul", "yield_qubit_ng_ul", "yield_nanodrop_ng_ul", "a260_280", "a260_230",
    "extraction_blank_id", "notes", "status_id", "storage_id", "storage_position", "project_id"
)
SELECT
    e.experiment_id,
    e.experiment_date,
    (SELECT sample_id FROM "lab"."samples" WHERE sample_type_id IN ('DNA', 'RNA') ORDER BY RANDOM() LIMIT 1),
    (SELECT sample_id FROM "lab"."samples" WHERE sample_type_id IN ('Tissue', 'DNA', 'RNA') ORDER BY RANDOM() LIMIT 1),
    (SELECT sample_type_id FROM "reference"."samples_type" WHERE sample_type_id IN ('DNA', 'RNA') ORDER BY RANDOM() LIMIT 1),
    NULL, -- These might be generated later for actual DNA/RNA samples
    NULL, -- These might be generated later for actual DNA/RNA samples
    (CURRENT_DATE - (s % 365 || ' days')::INTERVAL)::DATE,
    (SELECT person_id FROM "reference"."personal" ORDER BY RANDOM() LIMIT 1),
    'Zymo Quick-DNA',
    (RANDOM() * 100)::NUMERIC,
    (RANDOM() * 50)::NUMERIC,
    (RANDOM() * 60)::NUMERIC,
    (RANDOM() * 0.5 + 1.8)::NUMERIC,
    (RANDOM() * 0.5 + 1.8)::NUMERIC,
    'BLK-' || LPAD(s::TEXT, 3, '0'), -- Dummy blank ID
    'Demo extraction record.',
    (SELECT status_id FROM "reference"."status" ORDER BY RANDOM() LIMIT 1),
    (SELECT storage_id FROM "lab"."storage" ORDER BY RANDOM() LIMIT 1),
    'ExtPos-' || LPAD(s::TEXT, 3, '0'),
    (SELECT project_id FROM "lims"."projects" ORDER BY RANDOM() LIMIT 1)
FROM generate_series(1, 100) s
JOIN (SELECT experiment_id, experiment_date FROM "lab"."experiments" ORDER BY RANDOM() LIMIT 1) e ON TRUE;


-- lab.nanodrop (nanodrop_id generated by trigger, measurement_date is PK & partitioning, uses experiment_id, experiment_date, sample_id, concentration_unit_id, person_id, status_id, storage_id, project_id)
INSERT INTO "lab"."nanodrop" (
    "experiment_id", "experiment_date", "sample_id", "nanodrop_concentration", "concentration_unit_id",
    "a260", "a260_280", "a260_280_note", "a260_230", "a260_230_note", "measurement_date",
    "elution_volume_ul", "person_id", "notes", "status_id", "storage_id", "storage_position", "project_id"
)
SELECT
    e.experiment_id,
    e.experiment_date,
    (SELECT sample_id FROM "lab"."dna" ORDER BY RANDOM() LIMIT 1),
    (RANDOM() * 200)::NUMERIC,
    'ng_ul', -- Assuming ng_ul unit exists
    (RANDOM() * 2)::NUMERIC,
    (RANDOM() * 0.5 + 1.8)::NUMERIC,
    'Good ratio',
    (RANDOM() * 0.5 + 1.8)::NUMERIC,
    'Good ratio',
    (CURRENT_DATE - (s % 365 || ' days')::INTERVAL)::DATE,
    (RANDOM() * 50)::NUMERIC,
    (SELECT person_id FROM "reference"."personal" ORDER BY RANDOM() LIMIT 1),
    'Demo nanodrop reading.',
    (SELECT status_id FROM "reference"."status" ORDER BY RANDOM() LIMIT 1),
    (SELECT storage_id FROM "lab"."storage" ORDER BY RANDOM() LIMIT 1),
    'NanoPos-' || LPAD(s::TEXT, 3, '0'),
    (SELECT project_id FROM "lims"."projects" ORDER BY RANDOM() LIMIT 1)
FROM generate_series(1, 100) s
JOIN (SELECT experiment_id, experiment_date FROM "lab"."experiments" ORDER BY RANDOM() LIMIT 1) e ON TRUE;


-- lab.qubit (qubit_id generated by trigger, measurement_date is PK & partitioning, uses sample_id, experiment_id, experiment_date, unit_id, person_id, status_id, storage_id, project_id)
INSERT INTO "lab"."qubit" (
    "sample_id", "experiment_id", "experiment_date", "run_id", "assay_kit", "measurement_date",
    "qubit_tube_conc", "tube_unit_id", "qubit_original_sample_conc", "original_sample_unit_id",
    "sample_volume_ul", "elution_volume_ul", "person_id", "notes", "status_id", "storage_id", "storage_position", "project_id"
)
SELECT
    (SELECT sample_id FROM "lab"."dna" ORDER BY RANDOM() LIMIT 1),
    e.experiment_id,
    e.experiment_date,
    'QRUN-' || LPAD(s::TEXT, 3, '0'),
    'Qubit dsDNA HS',
    (CURRENT_DATE - (s % 365 || ' days')::INTERVAL)::DATE,
    (RANDOM() * 10)::NUMERIC,
    'ng_ul',
    (RANDOM() * 100)::NUMERIC,
    'ng_ul',
    (RANDOM() * 5)::NUMERIC,
    (RANDOM() * 50)::NUMERIC,
    (SELECT person_id FROM "reference"."personal" ORDER BY RANDOM() LIMIT 1),
    'Demo qubit reading.',
    (SELECT status_id FROM "reference"."status" ORDER BY RANDOM() LIMIT 1),
    (SELECT storage_id FROM "lab"."storage" ORDER BY RANDOM() LIMIT 1),
    'QubitPos-' || LPAD(s::TEXT, 3, '0'),
    (SELECT project_id FROM "lims"."projects" ORDER BY RANDOM() LIMIT 1)
FROM generate_series(1, 100) s
JOIN (SELECT experiment_id, experiment_date FROM "lab"."experiments" ORDER BY RANDOM() LIMIT 1) e ON TRUE;


-- lab.tapestation (tapestation_id generated by trigger, measurement_date is PK & partitioning, uses experiment_id, experiment_date, person_id, sample_id, storage_id, status_id, project_id)
INSERT INTO "lab"."tapestation" (
    "experiment_id", "experiment_date", "position", "measurement_date", "kit", "person_id",
    "notes", "sample_id", "storage_id", "storage_position", "status_id", "project_id"
)
SELECT
    e.experiment_id,
    e.experiment_date,
    'A' || (s % 12 + 1)::TEXT,
    (CURRENT_DATE - (s % 365 || ' days')::INTERVAL)::DATE,
    'High Sensitivity D1000',
    (SELECT person_id FROM "reference"."personal" ORDER BY RANDOM() LIMIT 1),
    'Demo tapestation run.',
    (SELECT sample_id FROM "lab"."dna" ORDER BY RANDOM() LIMIT 1),
    (SELECT storage_id FROM "lab"."storage" ORDER BY RANDOM() LIMIT 1),
    'TapePos-' || LPAD(s::TEXT, 3, '0'),
    (SELECT status_id FROM "reference"."status" ORDER BY RANDOM() LIMIT 1),
    (SELECT project_id FROM "lims"."projects" ORDER BY RANDOM() LIMIT 1)
FROM generate_series(1, 100) s
JOIN (SELECT experiment_id, experiment_date FROM "lab"."experiments" ORDER BY RANDOM() LIMIT 1) e ON TRUE;


-- lab.pcr (pcr_id generated by trigger, pcr_date is PK & partitioning, uses experiment_id, experiment_date, sample_id, primer_id, person_id, storage_id, status_id, project_id)
INSERT INTO "lab"."pcr" (
    "experiment_id", "experiment_date", "sample_id", "position", "primer_id", "pcr_blank_id",
    "pcr_date", "person_id", "kit", "storage_id", "storage_position", "status_id", "notes",
    "project_id", "volume_reaction_ul"
)
SELECT
    e.experiment_id,
    e.experiment_date,
    (SELECT sample_id FROM "lab"."dna" ORDER BY RANDOM() LIMIT 1),
    'Plate ' || LPAD((s%10+1)::TEXT, 2, '0') || '-' || LPAD((s%8+1)::TEXT, 2, '0'),
    (SELECT primer_id FROM "lims"."primers" ORDER BY RANDOM() LIMIT 1),
    'PCRBLK-' || LPAD(s::TEXT, 3, '0'),
    (CURRENT_DATE - (s % 365 || ' days')::INTERVAL)::DATE,
    (SELECT person_id FROM "reference"."personal" ORDER BY RANDOM() LIMIT 1),
    'Kapa HiFi HotStart',
    (SELECT storage_id FROM "lab"."storage" ORDER BY RANDOM() LIMIT 1),
    'PCRPos-' || LPAD(s::TEXT, 3, '0'),
    (SELECT status_id FROM "reference"."status" ORDER BY RANDOM() LIMIT 1),
    'Demo PCR reaction.',
    (SELECT project_id FROM "lims"."projects" ORDER BY RANDOM() LIMIT 1),
    25.0
FROM generate_series(1, 100) s
JOIN (SELECT experiment_id, experiment_date FROM "lab"."experiments" ORDER BY RANDOM() LIMIT 1) e ON TRUE;


-- lab.gelelectrophoresis (gelelectrophoresis_id generated by trigger, run_date is PK & partitioning, uses experiment_id, experiment_date, sample_id, person_id, storage_id, project_id)
INSERT INTO "lab"."gelelectrophoresis" (
    "experiment_id", "experiment_date", "sample_id", "position", "ladder", "voltage", "band_size_bp",
    "gel_type", "run_time_minutes", "run_date", "person_id", "storage_id", "storage_position", "project_id", "notes"
)
SELECT
    e.experiment_id,
    e.experiment_date,
    (SELECT sample_id FROM "lab"."dna" ORDER BY RANDOM() LIMIT 1),
    'Lane ' || LPAD(s::TEXT, 2, '0'),
    '1kb Plus Ladder',
    100::NUMERIC,
    (RANDOM() * 5000 + 100)::INTEGER,
    'Agarose 1%',
    60::NUMERIC,
    (CURRENT_DATE - (s % 365 || ' days')::INTERVAL)::DATE,
    (SELECT person_id FROM "reference"."personal" ORDER BY RANDOM() LIMIT 1),
    (SELECT storage_id FROM "lab"."storage" ORDER BY RANDOM() LIMIT 1),
    'GelPos-' || LPAD(s::TEXT, 3, '0'),
    (SELECT project_id FROM "lims"."projects" ORDER BY RANDOM() LIMIT 1),
    'Demo gel electrophoresis run.'
FROM generate_series(1, 100) s
JOIN (SELECT experiment_id, experiment_date FROM "lab"."experiments" ORDER BY RANDOM() LIMIT 1) e ON TRUE;


-- lab.qpcr (qpcr_id generated by trigger, qpcr_date is PK & partitioning, uses experiment_id, experiment_date, sample_id, person_id, primer_id, storage_id, status_id, project_id)
INSERT INTO "lab"."qpcr" (
    "experiment_id", "experiment_date", "sample_id", "position", "qpcr_date", "person_id", "primer_id",
    "ct_value", "inhibitor_test_result", "pcr_blank_id", "kit", "volume_ul", "storage_id",
    "storage_position", "status_id", "notes", "project_id"
)
SELECT
    e.experiment_id,
    e.experiment_date,
    (SELECT sample_id FROM "lab"."dna" ORDER BY RANDOM() LIMIT 1),
    'Well ' || LPAD((s%96+1)::TEXT, 3, '0'),
    (CURRENT_DATE - (s % 365 || ' days')::INTERVAL)::DATE,
    (SELECT person_id FROM "reference"."personal" ORDER BY RANDOM() LIMIT 1),
    (SELECT primer_id FROM "lims"."primers" ORDER BY RANDOM() LIMIT 1),
    (RANDOM() * 40)::NUMERIC,
    CASE (s % 2) WHEN 0 THEN 'Negative' ELSE 'Positive' END,
    'QPCBLK-' || LPAD(s::TEXT, 3, '0'),
    'PowerUp SYBR Green',
    20.0,
    (SELECT storage_id FROM "lab"."storage" ORDER BY RANDOM() LIMIT 1),
    'QPCRPos-' || LPAD(s::TEXT, 3, '0'),
    (SELECT status_id FROM "reference"."status" ORDER BY RANDOM() LIMIT 1),
    'Demo qPCR run.',
    (SELECT project_id FROM "lims"."projects" ORDER BY RANDOM() LIMIT 1)
FROM generate_series(1, 100) s
JOIN (SELECT experiment_id, experiment_date FROM "lab"."experiments" ORDER BY RANDOM() LIMIT 1) e ON TRUE;


-- lab.library (library_id generated by trigger, prep_date is PK & partitioning, uses experiment_id, experiment_date, sample_id, personal, storage_id, project_id)
INSERT INTO "lab"."library" (
    "library_id", "experiment_id", "experiment_date", "sample_id", "library_name", "prep_date",
    "person_id", "library_prep_kit", "index_sequence", "read_length_bp", "storage_id",
    "storage_position", "project_id", "notes"
)
SELECT
    'LIB' || LPAD(s::TEXT, 3, '0'),
    e.experiment_id,
    e.experiment_date,
    (SELECT sample_id FROM "lab"."dna" ORDER BY RANDOM() LIMIT 1),
    'Library ' || s,
    (CURRENT_DATE - (s % 365 || ' days')::INTERVAL)::DATE,
    (SELECT person_id FROM "reference"."personal" ORDER BY RANDOM() LIMIT 1),
    'NEBNext Ultra II DNA Library Prep',
    'ATGC' || LPAD(s::TEXT, 2, '0'),
    150,
    (SELECT storage_id FROM "lab"."storage" ORDER BY RANDOM() LIMIT 1),
    'LibPos-' || LPAD(s::TEXT, 3, '0'),
    (SELECT project_id FROM "lims"."projects" ORDER BY RANDOM() LIMIT 1),
    'Demo library prep.'
FROM generate_series(1, 100) s
JOIN (SELECT experiment_id, experiment_date FROM "lab"."experiments" ORDER BY RANDOM() LIMIT 1) e ON TRUE;


-- lab.sequencing (sequencing_id generated by trigger, sequencing_date is PK & partitioning, uses experiment_id, experiment_date, library_id, prep_date, sample_id, personal, status_id, storage_id, project_id)
INSERT INTO "lab"."sequencing" (
    "sequencing_id", "experiment_id", "experiment_date", "library_id", "prep_date", "sample_id",
    "sequencing_date", "person_id", "sequencer", "flow_cell_id", "library_prep_kit", "index_sequence",
    "read_length_bp", "total_reads", "raw_data_path", "genbank_accession_number", "status_id",
    "storage_id", "storage_position", "project_id", "notes"
)
SELECT
    'SEQ' || LPAD(s::TEXT, 3, '0'),
    e.experiment_id,
    e.experiment_date,
    lib.library_id,
    lib.prep_date,
    (SELECT sample_id FROM "lab"."dna" ORDER BY RANDOM() LIMIT 1),
    (CURRENT_DATE - (s % 365 || ' days')::INTERVAL)::DATE,
    (SELECT person_id FROM "reference"."personal" ORDER BY RANDOM() LIMIT 1),
    'Illumina MiSeq',
    'FC-' || LPAD(s::TEXT, 5, '0'),
    'NEBNext Ultra II DNA Library Prep',
    'ATGC' || LPAD((s%10+1)::TEXT, 2, '0'),
    150,
    (s * 1000000)::BIGINT,
    '/data/raw/seq' || s,
    'GBA-' || LPAD(s::TEXT, 5, '0'),
    (SELECT status_id FROM "reference"."status" ORDER BY RANDOM() LIMIT 1),
    (SELECT storage_id FROM "lab"."storage" ORDER BY RANDOM() LIMIT 1),
    'SeqPos-' || LPAD(s::TEXT, 3, '0'),
    (SELECT project_id FROM "lims"."projects" ORDER BY RANDOM() LIMIT 1),
    'Demo sequencing run.'
FROM generate_series(1, 100) s
JOIN (SELECT experiment_id, experiment_date FROM "lab"."experiments" ORDER BY RANDOM() LIMIT 1) e ON TRUE
JOIN (SELECT library_id, prep_date FROM "lab"."library" ORDER BY RANDOM() LIMIT 1) lib ON TRUE;


-- lab.datasets (dataset_id generated by trigger, reception_date is PK & partitioning, uses ecosystem_id, region_id, customer_id, stored_location_id)
INSERT INTO "lab"."datasets" (
    "dataset_id", "source_type", "ecosystem_id", "region_id", "customer_id",
    "stored_location_id", "reception_date", "notes", "storage_path"
)
SELECT
    'DATASET' || SUBSTRING(REPLACE(uuid_generate_v4()::TEXT, '-', ''), 1, 6) || LPAD(s::TEXT, 3, '0'),
    CASE (s % 3) WHEN 0 THEN 'Raw Seq' WHEN 1 THEN 'Processed Reads' ELSE 'Assembly' END,
    (SELECT ecosystem_id FROM "reference"."ecosystem" ORDER BY RANDOM() LIMIT 1),
    (SELECT region_id FROM "reference"."region" ORDER BY RANDOM() LIMIT 1),
    (SELECT customer_id FROM "lims"."customers" ORDER BY RANDOM() LIMIT 1),
    (SELECT storage_id FROM "lab"."storage" ORDER BY RANDOM() LIMIT 1),
    (CURRENT_DATE - (s % 365 || ' days')::INTERVAL)::DATE,
    'Demo dataset for bioinformatics.',
    '/data/datasets/' || LPAD(s::TEXT, 3, '0')
FROM generate_series(1, 100) s
ON CONFLICT ("dataset_id", "reception_date") DO NOTHING;


-- bioinformatics.analysis_pipelines (pipeline_id generated by trigger)
INSERT INTO "bioinformatics"."analysis_pipelines" ("pipeline_id", "pipeline_name", "version", "repository_link", "notes")
SELECT
    'PIPE' || SUBSTRING(REPLACE(uuid_generate_v4()::TEXT, '-', ''), 1, 6) || LPAD(s::TEXT, 3, '0'),
    'Pipeline ' || s,
    'v' || (s % 5 + 1) || '.0',
    'https://github.com/pipeline' || s,
    'Demo bioinformatics pipeline.'
FROM generate_series(1, 100) s
ON CONFLICT ("pipeline_id") DO NOTHING;


-- bioinformatics.analysis_runs (run_id generated by trigger, run_date is PK & partitioning, uses pipeline_id, sequencing_id, sequencing_date, person_id, reference_db_id)
INSERT INTO "bioinformatics"."analysis_runs" (
    "pipeline_id", "sequencing_id", "sequencing_date", "person_id", "run_date", "parameters_jsonb",
    "reference_db_id", "clustering_threshold", "final_output_path", "notes"
)
SELECT
    (SELECT pipeline_id FROM "bioinformatics"."analysis_pipelines" ORDER BY RANDOM() LIMIT 1),
    seq.sequencing_id,
    seq.sequencing_date,
    (SELECT person_id FROM "reference"."personal" ORDER BY RANDOM() LIMIT 1),
    (CURRENT_TIMESTAMP - (s % 365 || ' hours')::INTERVAL)::TIMESTAMPTZ, -- Run date can be timestamp
    '{"min_reads": ' || (s % 100 + 1) || ', "quality_threshold": ' || (s % 40 + 10) || '}'::jsonb,
    (SELECT db_id FROM "bioinformatics"."reference_databases" ORDER BY RANDOM() LIMIT 1),
    (RANDOM() * 0.1 + 0.9)::NUMERIC(3,2), -- 0.90 to 1.00
    '/analysis/run' || s,
    'Demo analysis run.'
FROM generate_series(1, 100) s
JOIN (SELECT sequencing_id, sequencing_date FROM "lab"."sequencing" ORDER BY RANDOM() LIMIT 1) seq ON TRUE
ON CONFLICT ("run_id", "run_date") DO NOTHING;


-- bioinformatics.edna_assignments (assignment_id generated by trigger, uses run_id, run_date, sample_id, taxon_id)
INSERT INTO "bioinformatics"."edna_assignments" (
    "run_id", "run_date", "sample_id", "taxon_id", "read_count", "confidence", "notes"
)
SELECT
    ar.run_id,
    ar.run_date::date, -- Cast timestamp to date for FK
    (SELECT sample_id FROM "lab"."samples" WHERE sample_type_id = 'DNA' ORDER BY RANDOM() LIMIT 1),
    (SELECT taxon_id FROM "reference"."taxon" WHERE rank = 'species' ORDER BY RANDOM() LIMIT 1),
    (RANDOM() * 100000)::INTEGER,
    (RANDOM())::NUMERIC,
    'eDNA assignment for demo run.'
FROM generate_series(1, 100) s
JOIN (SELECT run_id, run_date FROM "bioinformatics"."analysis_runs" ORDER BY RANDOM() LIMIT 1) ar ON TRUE
ON CONFLICT ("assignment_id") DO NOTHING;


-- Reset current_person_id to avoid accidental use in other contexts
RESET lims.current_person_id;