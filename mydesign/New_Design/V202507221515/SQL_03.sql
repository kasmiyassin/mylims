-- ======================================================================
-- 13. Views
-- ======================================================================

CREATE OR REPLACE VIEW "reference"."complete_species_taxon_view" AS
SELECT
    t.taxon_id,
    t.de_name AS taxon_de_name,
    t.en_name AS taxon_en_name,
    t.rank,
    t.notes AS taxon_notes,
    s.species_id,
    s.de_name AS species_de_name,
    s.en_name AS species_en_name,
    s.max_length_mm,
    s.max_age_years,
    s.notes AS species_notes
FROM
    "reference"."taxon" t
LEFT JOIN
    "reference"."species" s ON t.taxon_id = s.species_id;

CREATE OR REPLACE VIEW "lims"."project_overview_view" AS
SELECT
    p.project_id,
    p.title,
    p.status_id,
    p.pi_person_id,
    ref_p.full_name AS pi_full_name,
    p.funder,
    p.customer_id,
    c.customer_name,
    c.customer_abrv,
    p.start_date,
    p.end_date,
    p.report_date,
    p.notes
FROM
    "lims"."projects" p
LEFT JOIN
    "lims"."customers" c ON p.customer_id = c.customer_id
LEFT JOIN
    "reference"."personal" ref_p ON p.pi_person_id = ref_p.person_id;

CREATE OR REPLACE VIEW "lab"."sample_workflow_progress_view" AS
SELECT
    s.sample_id,
    s.external_name,
    s.sample_type_id,
    s.sample_status_id AS current_status,
    s.workflow_id,
    ws.step_name AS current_workflow_step,
    ws.step_number,
    ws.workflow_status_id AS step_status
FROM
    "lab"."parental_samples" s
LEFT JOIN
    "lims"."workflow_steps" ws ON s.workflow_id = ws.workflow_id AND s.step_id = ws.step_id;

CREATE OR REPLACE VIEW "lab"."storage_inventory_view" AS
SELECT
    st.storage_id,
    st.room_id,
    r.address AS room_address,
    st.freezer,
    st.etage,
    st.temperature_c,
    st.box,
    st.box_size_x,
    st.box_size_y,
    st.storage_position_format,
    s.sample_id,
    s.external_name AS sample_external_name,
    s.sample_type_id,
    s.reception_date AS sample_reception_date,
    s.project_id
FROM
    "lab"."storage" st
LEFT JOIN
    "reference"."room" r ON st.room_id = r.room_id
LEFT JOIN
    "lab"."parental_samples" s ON st.storage_id = s.storage_id;

CREATE OR REPLACE VIEW "lab"."experiment_summary_view" AS
SELECT
    e.experiment_id,
    e.experiment_title,
    e.aim,
    e.method,
    e.sop_id,
    sop.title AS sop_title,
    e.experiment_date,
    e.person_id AS experiment_person_id,
    ref_p.full_name AS experiment_person_name,
    e.lab_book,
    e.status_id,
    COUNT(DISTINCT es.sample_id) AS number_of_samples,
    COUNT(DISTINCT ep.project_id) AS number_of_projects
FROM
    "lab"."experiments" e
LEFT JOIN
    "lims"."sop" sop ON e.sop_id = sop.sop_id
LEFT JOIN
    "reference"."personal" ref_p ON e.person_id = ref_p.person_id
LEFT JOIN
    "lab"."experiments_samples" es ON e.experiment_id = es.experiment_id
LEFT JOIN
    "lab"."experiments_projects" ep ON e.experiment_id = ep.experiment_id
GROUP BY
    e.experiment_id, e.experiment_title, e.aim, e.method, e.sop_id, sop.title,
    e.experiment_date, e.person_id, ref_p.full_name, e.lab_book, e.status_id;

CREATE OR REPLACE VIEW "bioinformatics"."analysis_results_summary" AS
SELECT
    ar.run_id,
    ar.run_date,
    ar.person_id,
    ref_p.full_name AS analyst_name,
    ap.pipeline_name,
    ap.version AS pipeline_version,
    ar.sequencing_id,
    s.sample_id,
    s.external_name AS sample_external_name,
    ea.taxon_id,
    t.en_name AS taxon_en_name,
    ea.read_count,
    ea.confidence,
    ar.notes AS run_notes,
    ea.notes AS assignment_notes,
    ar.clustering_threshold,
    ar.final_output_path,
    rdb.db_name AS reference_database_name,
    rdb.db_version AS bioinfo_database_version
FROM
    "bioinformatics"."edna_assignments" ea
JOIN
    "bioinformatics"."analysis_runs" ar ON ea.run_id = ar.run_id
JOIN
    "bioinformatics"."analysis_pipelines" ap ON ar.pipeline_id = ap.pipeline_id
JOIN
    "lab"."sequencing" seq ON ar.sequencing_id = seq.sequencing_id
JOIN
    "lab"."parental_samples" s ON seq.sample_id = s.sample_id
LEFT JOIN
    "reference"."personal" ref_p ON ar.person_id = ref_p.person_id
LEFT JOIN
    "reference"."taxon" t ON ea.taxon_id = t.taxon_id
LEFT JOIN
    "bioinformatics"."reference_databases" rdb ON ar.reference_db_id = rdb.db_id;


CREATE OR REPLACE VIEW "lims"."project_financial_summary_view" AS
SELECT
    p.project_id,
    p.title AS project_title,
    p.pi_person_id,
    pers.full_name AS pi_name,
    SUM(o.price) AS total_cost,
    COUNT(o.fi_order_nr) AS number_of_orders,
    MIN(o.order_date) AS first_order_date,
    MAX(o.order_date) AS last_order_date
FROM
    "lims"."projects" p
JOIN "lims"."orders" o ON p.project_id = o.project_id
LEFT JOIN "reference"."personal" pers ON p.pi_person_id = pers.person_id
GROUP BY
    p.project_id, p.title, p.pi_person_id, pers.full_name
ORDER BY
    total_cost DESC;

CREATE OR REPLACE VIEW "bioinformatics"."full_analysis_results_view" AS
SELECT
    p.project_id,
    p.title AS project_title,
    samp.sampling_id,
    samp.sampling_date,
    samp.location_name AS sampling_location,
    s.sample_id,
    s.external_name,
    ar.run_id AS analysis_run_id,
    ap.pipeline_name,
    ap.version AS pipeline_version,
    t.taxon_id,
    t.en_name AS taxon_en_name,
    t.rank AS taxon_rank,
    ea.read_count,
    ea.confidence
FROM
    "bioinformatics"."edna_assignments" ea
JOIN "bioinformatics"."analysis_runs" ar ON ea.run_id = ar.run_id
JOIN "bioinformatics"."analysis_pipelines" ap ON ar.pipeline_id = ap.pipeline_id
JOIN "lab"."parental_samples" s ON ea.sample_id = s.sample_id
JOIN "lab"."sampling" samp ON s.sampling_id = samp.sampling_id AND s.sampling_date = samp.sampling_date
JOIN "lims"."projects" p ON s.project_id = p.project_id
JOIN "reference"."taxon" t ON ea.taxon_id = t.taxon_id
ORDER BY
    p.project_id, samp.sampling_date, s.sample_id, ea.read_count DESC;

CREATE OR REPLACE VIEW "lab"."storage_occupancy_view" AS
WITH box_counts AS (
    SELECT
        storage_id,
        COUNT(sample_id) AS stored_samples
    FROM "lab"."parental_samples"
    WHERE storage_id IS NOT NULL
    GROUP BY storage_id
)
SELECT
    st.storage_id,
    st.room_id,
    st.freezer,
    st.etage,
    st.temperature_c,
    st.box,
    st.box_size_x * st.box_size_y AS box_capacity,
    COALESCE(bc.stored_samples, 0) AS occupied_slots,
    (COALESCE(bc.stored_samples, 0)::NUMERIC * 100 / (st.box_size_x * st.box_size_y))::NUMERIC(5,2) AS occupancy_percent
FROM
    "lab"."storage" st
LEFT JOIN box_counts bc ON st.storage_id = bc.storage_id
WHERE st.box_size_x > 0 AND st.box_size_y > 0
ORDER BY
    occupancy_percent DESC;

CREATE OR REPLACE VIEW "lims"."project_comprehensive_summary_view" AS
SELECT
    p.project_id,
    p.title AS project_title,
    stat.notes AS project_status,
    p.funder,
    p.start_date,
    p.end_date,
    COUNT(DISTINCT ep.experiment_id) AS number_of_experiments,
    COUNT(DISTINCT s.sample_id) AS number_of_samples,
    SUM(o.price) AS total_order_cost
FROM "lims"."projects" p
LEFT JOIN "reference"."status" stat ON p.status_id = stat.status_id
LEFT JOIN "lab"."experiments_projects" ep ON p.project_id = ep.project_id
LEFT JOIN "lab"."parental_samples" s ON p.project_id = s.project_id
LEFT JOIN "lims"."orders" o ON p.project_id = o.project_id
GROUP BY
    p.project_id, p.title, stat.notes, p.funder, p.start_date, p.end_date
ORDER BY p.start_date DESC;

CREATE OR REPLACE VIEW "lab"."experiment_progress_overview_view" AS
SELECT
    e.experiment_id,
    e.experiment_title,
    p.project_id,
    p.title AS project_title,
    stat.notes AS experiment_status,
    e.experiment_date AS experiment_start_date,
    pers.full_name AS experiment_lead,
    COUNT(DISTINCT es.sample_id) AS total_samples_in_experiment,
    COUNT(DISTINCT ext.sample_id) AS samples_extracted,
    COUNT(DISTINCT qu.sample_id) AS samples_qubit_qc,
    COUNT(DISTINCT lib.sample_id) AS samples_library_prepped,
    COUNT(DISTINCT seq.sample_id) AS samples_sequenced,
    COUNT(DISTINCT ar.run_id) AS samples_bioinformatics_done
FROM "lab"."experiments" e
LEFT JOIN "lab"."experiments_projects" ep ON e.experiment_id = ep.experiment_id
LEFT JOIN "lims"."projects" p ON ep.project_id = p.project_id
LEFT JOIN "reference"."status" stat ON e.status_id = stat.status_id
LEFT JOIN "reference"."personal" pers ON e.person_id = pers.person_id
LEFT JOIN "lab"."experiments_samples" es ON e.experiment_id = es.experiment_id
LEFT JOIN "lab"."extraction" ext ON es.sample_id = ext.sample_id
LEFT JOIN "lab"."qubit" qu ON es.sample_id = qu.sample_id
LEFT JOIN "lab"."library" lib ON es.sample_id = lib.sample_id
LEFT JOIN "lab"."sequencing" seq ON es.sample_id = seq.sample_id
LEFT JOIN "bioinformatics"."analysis_runs" ar ON seq.sequencing_id = ar.sequencing_id
GROUP BY
    e.experiment_id, e.experiment_title, p.project_id, p.title,
    stat.notes, e.experiment_date, pers.full_name
ORDER BY e.experiment_date DESC;

CREATE OR REPLACE VIEW "lims"."reagent_status_view" AS
SELECT
    r.reagent_complete_name,
    r.category_id,
    r.lot,
    r.storage_id,
    stat.notes AS current_status,
    r.reception_date,
    r.expire_date,
    CASE
        WHEN r.expire_date IS NULL THEN NULL
        ELSE (r.expire_date - CURRENT_DATE)
    END AS days_until_expiry,
    r.quantity_available,
    ru.unit_abbreviation AS quantity_unit
FROM "lims"."reagents" r
LEFT JOIN "reference"."status" stat ON r.status_id = stat.status_id
LEFT JOIN "reference"."units" ru ON r.quantity_unit_id = ru.unit_id
ORDER BY r.expire_date ASC;


CREATE OR REPLACE VIEW "lab"."sample_full_details_view" AS
SELECT
    s.sample_id,
    s.external_name,
    s.project_id,
    p.title AS project_title,
    s.sample_type_id,
    stype.sample_type_abrv,
    s.sample_status_id,
    stat.notes AS sample_status_notes,
    s.parent_sample_id,

    s.storage_id,
    stor.freezer AS storage_freezer,
    stor.box AS storage_box,
    s.storage_position,
    stor.room_id,
    r.address AS room_address,
    r.etage AS room_etage,

    samp.sampling_id AS sampling_event_id,
    samp.sampling_date AS sampling_event_date,
    ST_X(samp.geom) AS sampling_lon,
    ST_Y(samp.geom) AS sampling_lat,
    ST_X(samp.fishing_start_geom) AS fishing_start_lon,
    ST_Y(samp.fishing_start_geom) AS fishing_start_lat,
    ST_X(samp.fishing_end_geom) AS fishing_end_lon,
    ST_Y(samp.fishing_end_geom) AS fishing_end_lat,
    samp.location_name AS sampling_location,
    samp.depth_m AS sampling_depth_m,
    samp.temperature_atmospheric_c,
    samp.weather,
    samp.wind_speed,
    wu.unit_abbreviation AS wind_unit,
    samp.salinity,
    su.unit_abbreviation AS salinity_unit,
    samp.oxygen,
    ou.unit_abbreviation AS oxygen_unit,

    f.species_id,
    taxon_sp.en_name AS species_en_name,
    f.total_length_mm,
    f.weight_g,
    f.sex,
    f.maturity_stage,
    f.stomach_contents,
    f.disease_info,
    f.tag_id,

    t.weight_mg AS tissue_weight_mg,
    t.tissue_type,
    t.preservation_method AS tissue_preservation_method,

    dna.volume_ul AS dna_volume_ul,
    dna.concentration_ng_ul AS dna_concentration_ng_ul,
    dna.a260_280 AS dna_a260_280,
    dna.a260_230 AS dna_a260_230,
    dna.extraction_method AS dna_extraction_method,

    rna.volume_ul AS rna_volume_ul,
    rna.concentration_ng_ul AS rna_concentration_ng_ul,
    rna.a260_280 AS rna_a260_280,
    rna.a260_230 AS rna_a260_230,
    rna.extraction_method AS rna_extraction_method,

    sed.volume AS sediment_volume,
    svu.unit_abbreviation AS sediment_volume_unit,
    sed.depth_m AS sediment_depth_m,
    sed.sampling_method AS sediment_sampling_method,

    wat.volume_l AS water_volume_l,
    wat.filter AS water_filter,
    wat.filter_pore_size_um AS water_filter_pore_size_um,
    wat.depth_m AS water_depth_m,

    ext.extraction_date,
    ext.kit AS extraction_kit,
    ext.elution_volume_ul AS extraction_elution_volume_ul,
    ext.yield_qubit_ng_ul,
    ext.yield_nanodrop_ng_ul,
    ext.a260_280 AS extraction_a260_280,
    ext.a260_230 AS extraction_a260_230,
    ext.extracted_dna_sample_id,
    ext.extracted_rna_sample_id,

    nd.nanodrop_concentration,
    ndcu.unit_abbreviation AS nanodrop_concentration_unit,
    nd.a260 AS nanodrop_a260,
    nd.a260_280 AS nanodrop_a260_280,
    nd.a260_230 AS nanodrop_a260_230,
    nd.nanodrop_total_dna_ug,

    qu.qubit_original_sample_conc,
    quosu.unit_abbreviation AS qubit_original_sample_unit,
    qu.qubit_total_dna_ug,

    pcr.pcr_date,
    pcr.primer_id AS pcr_primer_id,
    pcr_primer.target_gene_id AS pcr_target_gene_id,
    pcr.volume_reaction_ul,

    qpcr.qpcr_date,
    qpcr.ct_value,
    qpcr.inhibitor_test_result,

    lib.library_id,
    lib.library_prep_kit,
    lib.index_sequence,
    lib.read_length_bp AS library_read_length_bp,
    seq.sequencing_id,
    seq.sequencer,
    seq.total_reads,
    seq.raw_data_path,
    seq.genbank_accession_number,

    ar.run_id AS analysis_run_id,
    ap.pipeline_name,
    ap.version AS pipeline_version,
    rdb.db_name AS bioinfo_reference_database,
    rdb.db_version AS bioinfo_database_version,
    ar.clustering_threshold,
    ar.final_output_path,
    ea.taxon_id AS edna_assigned_taxon_id,
    ea_taxon.en_name AS edna_assigned_taxon_name,
    ea.read_count AS edna_read_count,
    ea.confidence,

    s.sampler_person_id,
    sampler_p.full_name AS sampler_full_name,
    s.receiver_person_id,
    receiver_p.full_name AS receiver_full_name,
    s.reception_date


FROM "lab"."parental_samples" s
LEFT JOIN "reference"."status" stat ON s.sample_status_id = stat.status_id
LEFT JOIN "reference"."samples_type" stype ON s.sample_type_id = stype.sample_type_id
LEFT JOIN "lims"."projects" p ON s.project_id = p.project_id
LEFT JOIN "lab"."storage" stor ON s.storage_id = stor.storage_id
LEFT JOIN "reference"."room" r ON stor.room_id = r.room_id
LEFT JOIN "lab"."sampling" samp ON s.sampling_id = samp.sampling_id AND s.sampling_date = samp.sampling_date
LEFT JOIN "lab"."fish" f ON s.sample_id = f.sample_id
LEFT JOIN "reference"."taxon" taxon_sp ON f.species_id = taxon_sp.taxon_id
LEFT JOIN "lab"."tissue" t ON s.sample_id = t.sample_id
LEFT JOIN "lab"."dna" dna ON s.sample_id = dna.sample_id
LEFT JOIN "lab"."rna" rna ON s.sample_id = rna.sample_id
LEFT JOIN "lab"."sediments" sed ON s.sample_id = sed.sample_id
LEFT JOIN "lab"."water" wat ON s.sample_id = wat.sample_id
LEFT JOIN "lab"."extraction" ext ON s.sample_id = ext.sample_id
LEFT JOIN "lab"."nanodrop" nd ON s.sample_id = nd.sample_id
LEFT JOIN "reference"."units" ndcu ON nd.concentration_unit_id = ndcu.unit_id
LEFT JOIN "lab"."qubit" qu ON s.sample_id = qu.sample_id
LEFT JOIN "reference"."units" quosu ON qu.original_sample_unit_id = quosu.unit_id
LEFT JOIN "lab"."pcr" pcr ON s.sample_id = pcr.sample_id
LEFT JOIN "lims"."primers" pcr_primer ON pcr.primer_id = pcr_primer.primer_id
LEFT JOIN "lab"."qpcr" qpcr ON s.sample_id = qpcr.sample_id
LEFT JOIN "lab"."library" lib ON s.sample_id = lib.sample_id
LEFT JOIN "lab"."sequencing" seq ON s.sample_id = seq.sample_id
LEFT JOIN "bioinformatics"."analysis_runs" ar ON seq.sequencing_id = ar.sequencing_id
LEFT JOIN "bioinformatics"."analysis_pipelines" ap ON ar.pipeline_id = ap.pipeline_id
LEFT JOIN "bioinformatics"."reference_databases" rdb ON ar.reference_db_id = rdb.db_id
LEFT JOIN "bioinformatics"."edna_assignments" ea ON ar.run_id = ea.run_id AND s.sample_id = ea.sample_id
LEFT JOIN "reference"."taxon" ea_taxon ON ea.taxon_id = ea_taxon.taxon_id
LEFT JOIN "reference"."units" wu ON samp.wind_unit_id = wu.unit_id
LEFT JOIN "reference"."units" su ON samp.salinity_unit_id = su.unit_id
LEFT JOIN "reference"."units" ou ON samp.oxygen_unit_id = ou.unit_id
LEFT JOIN "reference"."units" svu ON sed.volume_unit_id = svu.unit_id
LEFT JOIN "reference"."personal" sampler_p ON s.sampler_person_id = sampler_p.person_id
LEFT JOIN "reference"."personal" receiver_p ON s.receiver_person_id = receiver_p.person_id;


CREATE OR REPLACE VIEW "reference"."taxon_hierarchy_view" AS
SELECT
    t.taxon_id,
    t.de_name,
    t.en_name,
    t.rank,
    t.path,
    l.ancestor_taxon_id AS phylum_id,
    phylum_taxon.en_name AS phylum_en_name,
    l2.ancestor_taxon_id AS class_id,
    class_taxon.en_name AS class_en_name,
    l3.ancestor_taxon_id AS order_id,
    order_taxon.en_name AS order_en_name,
    l4.ancestor_taxon_id AS family_id,
    family_taxon.en_name AS family_en_name,
    l5.ancestor_taxon_id AS genus_id,
    genus_taxon.en_name AS genus_en_name,
    s.species_id AS species_level_id,
    s.en_name AS species_level_en_name
FROM
    "reference"."taxon" t
LEFT JOIN
    "reference"."species" s ON t.taxon_id = s.species_id
LEFT JOIN LATERAL (
    SELECT taxon_id AS ancestor_taxon_id
    FROM "reference"."taxon"
    WHERE path @> t.path AND rank = 'phylum'
) l ON TRUE
LEFT JOIN "reference"."taxon" phylum_taxon ON l.ancestor_taxon_id = phylum_taxon.taxon_id
LEFT JOIN LATERAL (
    SELECT taxon_id AS ancestor_taxon_id
    FROM "reference"."taxon"
    WHERE path @> t.path AND rank = 'class'
) l2 ON TRUE
LEFT JOIN "reference"."taxon" class_taxon ON l2.ancestor_taxon_id = class_taxon.taxon_id
LEFT JOIN LATERAL (
    SELECT taxon_id AS ancestor_taxon_id
    FROM "reference"."taxon"
    WHERE path @> t.path AND rank = 'order'
) l3 ON TRUE
LEFT JOIN "reference"."taxon" order_taxon ON l3.ancestor_taxon_id = order_taxon.taxon_id
LEFT JOIN LATERAL (
    SELECT taxon_id AS ancestor_taxon_id
    FROM "reference"."taxon"
    WHERE path @> t.path AND rank = 'family'
) l4 ON TRUE
LEFT JOIN "reference"."taxon" family_taxon ON l4.ancestor_taxon_id = family_taxon.taxon_id
LEFT JOIN LATERAL (
    SELECT taxon_id AS ancestor_taxon_id
    FROM "reference"."taxon"
    WHERE path @> t.path AND rank = 'genus'
) l5 ON TRUE
LEFT JOIN "reference"."taxon" genus_taxon ON l5.ancestor_taxon_id = genus_taxon.taxon_id
ORDER BY t.path;


CREATE MATERIALIZED VIEW IF NOT EXISTS "lab"."monthly_sample_reception_mv" AS
SELECT
    TO_CHAR(reception_date, 'YYYY-MM') AS reception_month,
    sample_type_id,
    COUNT(sample_id) AS total_samples_received
FROM
    "lab"."parental_samples"
WHERE
    reception_date IS NOT NULL
GROUP BY
    1, 2
ORDER BY
    1, 2
WITH DATA;


-- =========================================
CREATE OR REPLACE VIEW "lab"."detailed_samples_view" AS
SELECT
    s.sample_id,
    s.external_name,
    s.parent_sample_id,
    'Primary Sample' AS sample_origin_type, -- Identifies the source of this row
    s.sample_type_id,
    stype.sample_type_abrv,
    s.sample_status_id,
    stat.notes AS sample_status_notes,
    s.sampling_id,
    s.sampling_date,
    s.reception_date,
    s.project_id,
    p.title AS project_title,
    s.customer_id,
    c.customer_name,
    s.storage_id,
    s.storage_position,
    s.notes,
    s.attachment,
    s.attachment_link,

    -- Sampling Event Details (from lab.sampling)
    ST_X(samp.geom) AS sampling_lon,
    ST_Y(samp.geom) AS sampling_lat,
    ST_X(samp.fishing_start_geom) AS fishing_start_lon,
    ST_Y(samp.fishing_start_geom) AS fishing_start_lat,
    ST_X(samp.fishing_end_geom) AS fishing_end_lon,
    ST_Y(samp.fishing_end_geom) AS fishing_end_lat,
    samp.location_name AS sampling_location,
    samp.depth_m AS sampling_depth_m,
    samp.temperature_atmospheric_c,
    samp.weather,
    samp.wind_speed,
    wu.unit_abbreviation AS wind_unit,
    samp.salinity,
    su.unit_abbreviation AS salinity_unit,
    samp.oxygen,
    ou.unit_abbreviation AS oxygen_unit,

    -- Fish-specific Details (NULL placeholders for non-fish primary samples)
    NULL::text AS fish_species_id,
    NULL::text AS fish_species_en_name,
    NULL::numeric AS fish_total_length_mm,
    NULL::numeric AS fish_fork_length_mm,
    NULL::numeric AS fish_standard_length_mm,
    NULL::numeric AS fish_weight_g,
    NULL::text AS fish_sex,
    NULL::text AS fish_maturity_stage,
    NULL::text AS fish_stomach_contents,
    NULL::text AS fish_disease_info,
    NULL::text AS fish_tag_id,

    -- Tissue-specific Details (NULL placeholders)
    NULL::numeric AS tissue_weight_mg,
    NULL::text AS tissue_type,
    NULL::text AS tissue_preservation_method,

    -- DNA-specific Details (NULL placeholders)
    NULL::numeric AS dna_volume_ul,
    NULL::numeric AS dna_concentration_ng_ul,
    NULL::numeric AS dna_a260_280,
    NULL::numeric AS dna_a260_230,
    NULL::text AS dna_extraction_method,
    NULL::date AS dna_extraction_date_dna,
    NULL::integer AS dna_extraction_number,

    -- RNA-specific Details (NULL placeholders)
    NULL::numeric AS rna_volume_ul,
    NULL::numeric AS rna_concentration_ng_ul,
    NULL::numeric AS rna_a260_280,
    NULL::numeric AS rna_a260_230,
    NULL::text AS rna_extraction_method,
    NULL::date AS rna_extraction_date_rna,
    NULL::integer AS rna_extraction_number,

    -- Sediments-specific Details (NULL placeholders)
    NULL::numeric AS sediment_volume,
    NULL::text AS sediment_volume_unit,
    NULL::numeric AS sediment_depth_m,
    NULL::text AS sediment_sampling_method,
    NULL::text AS sediment_conservation_buffer,

    -- Water-specific Details (NULL placeholders)
    NULL::numeric AS water_volume_l,
    NULL::text AS water_filter,
    NULL::numeric AS water_filter_pore_size_um,
    NULL::numeric AS water_depth_m,
    NULL::text AS water_sampling_method,
    NULL::text AS water_conservation_buffer,

    -- Otoliths-specific Details (NULL placeholders)
    NULL::text AS otolith_id,
    NULL::text AS otolith_reader_person_id,
    NULL::text AS otolith_side,
    NULL::numeric AS otolith_age_reading_years,
    NULL::numeric AS otolith_confidence,

    -- Dissections Details (NULL placeholders)
    NULL::text AS dissection_id,
    NULL::text AS dissection_person_id,
    NULL::date AS dissection_date,
    NULL::jsonb AS dissection_stomach_contents_jsonb,
    NULL::numeric AS dissection_gonad_weight_g,
    NULL::numeric AS dissection_liver_weight_g,

    -- Extraction Details (NULL placeholders)
    NULL::text AS extraction_id,
    NULL::date AS extraction_process_date,
    NULL::text AS extraction_process_person_id,
    NULL::text AS extraction_process_kit,
    NULL::numeric AS extraction_process_elution_volume_ul,
    NULL::numeric AS extraction_process_yield_qubit_ng_ul,
    NULL::numeric AS extraction_process_yield_nanodrop_ng_ul,
    NULL::numeric AS extraction_process_a260_280,
    NULL::numeric AS extraction_process_a260_230,
    NULL::text AS extraction_result_dna_sample_id,
    NULL::text AS extraction_result_rna_sample_id,
    NULL::text AS extraction_blank_id,

    -- Nanodrop QC Details (NULL placeholders)
    NULL::text AS nanodrop_id,
    NULL::numeric AS nanodrop_concentration,
    NULL::text AS nanodrop_concentration_unit,
    NULL::numeric AS nanodrop_a260,
    NULL::numeric AS nanodrop_a260_280_qc,
    NULL::numeric AS nanodrop_a260_230_qc,
    NULL::numeric AS nanodrop_total_dna_ug,
    NULL::date AS nanodrop_measurement_date,
    NULL::text AS nanodrop_a260_280_note,
    NULL::text AS nanodrop_a260_230_note,

    -- Qubit QC Details (NULL placeholders)
    NULL::text AS qubit_id,
    NULL::numeric AS qubit_original_sample_conc,
    NULL::text AS qubit_original_sample_unit,
    NULL::numeric AS qubit_total_dna_ug,
    NULL::date AS qubit_measurement_date,
    NULL::text AS qubit_assay_kit,
    NULL::numeric AS qubit_tube_conc,
    NULL::text AS tube_unit_id,
    NULL::numeric AS sample_volume_ul,
    NULL::numeric AS elution_volume_ul,

    -- Tapestation QC Details (NULL placeholders)
    NULL::text AS tapestation_id,
    NULL::date AS tapestation_measurement_date,
    NULL::text AS tapestation_kit,

    -- PCR Details (NULL placeholders)
    NULL::text AS pcr_id,
    NULL::date AS pcr_date,
    NULL::text AS pcr_primer_id,
    NULL::text AS pcr_target_gene_id,
    NULL::numeric AS pcr_volume_reaction_ul,
    NULL::text AS pcr_blank_id,
    NULL::text AS pcr_position,

    -- Gel Electrophoresis Details (NULL placeholders)
    NULL::text AS gel_gelelectrophoresis_id,
    NULL::date AS gel_run_date,
    NULL::integer AS gel_band_size_bp,
    NULL::text AS gel_gel_type,
    NULL::text AS gel_position,
    NULL::text AS gel_ladder,
    NULL::numeric AS gel_voltage,
    NULL::numeric AS gel_run_time_minutes,

    -- qPCR Details (NULL placeholders)
    NULL::text AS qpcr_id,
    NULL::date AS qpcr_date,
    NULL::numeric AS qpcr_ct_value,
    NULL::text AS qpcr_inhibitor_test_result,
    NULL::text AS qpcr_position,
    NULL::text AS qpcr_primer_id_actual,
    NULL::text AS qpcr_pcr_blank_id,
    NULL::text AS qpcr_kit,
    NULL::numeric AS qpcr_volume_ul,

    -- Library Prep Details (NULL placeholders)
    NULL::text AS library_id,
    NULL::date AS library_prep_date,
    NULL::text AS library_name,
    NULL::text AS library_prep_kit,
    NULL::text AS library_index_sequence,
    NULL::integer AS library_read_length_bp,

    -- Sequencing Details (NULL placeholders)
    NULL::text AS sequencing_id,
    NULL::date AS sequencing_date,
    NULL::text AS sequencer,
    NULL::text AS flow_cell_id,
    NULL::bigint AS total_reads,
    NULL::text AS raw_data_path,
    NULL::text AS genbank_accession_number,
    NULL::text AS sequencing_library_prep_kit,
    NULL::text AS sequencing_index_sequence,
    NULL::integer AS sequencing_read_length_bp,

    -- Bioinformatics Analysis Details (NULL placeholders)
    NULL::text AS analysis_run_id,
    NULL::text AS pipeline_name,
    NULL::text AS pipeline_version,
    NULL::text AS bioinfo_reference_database,
    NULL::text AS bioinfo_database_version,
    NULL::numeric AS clustering_threshold,
    NULL::text AS final_output_path,

    -- eDNA Assignment Details (NULL placeholders)
    NULL::text AS edna_assignment_id,
    NULL::text AS edna_assigned_taxon_id,
    NULL::text AS edna_assigned_taxon_name,
    NULL::integer AS edna_read_count,
    NULL::numeric AS edna_confidence,

    -- Experiment Details (NULL placeholders for direct experiment link)
    e.experiment_id AS associated_experiment_id,
    e.experiment_title AS associated_experiment_title,
    e.experiment_date AS associated_experiment_date,
    e.aim AS associated_experiment_aim,
    e.method AS associated_experiment_method,
    exp_person.full_name AS experiment_person_name,

    -- Person information (NULL placeholders for specific sections)
    sampler_p.full_name AS sampler_full_name,
    receiver_p.full_name AS receiver_full_name

FROM
    "lab"."parental_samples" s
LEFT JOIN "reference"."status" stat ON s.sample_status_id = stat.status_id
LEFT JOIN "reference"."samples_type" stype ON s.sample_type_id = stype.sample_type_id
LEFT JOIN "lims"."projects" p ON s.project_id = p.project_id
LEFT JOIN "lims"."customers" c ON s.customer_id = c.customer_id
LEFT JOIN "lab"."storage" stor ON s.storage_id = stor.storage_id
LEFT JOIN "reference"."room" r ON stor.room_id = r.room_id
LEFT JOIN "lab"."sampling" samp ON s.sampling_id = samp.sampling_id AND s.sampling_date = samp.sampling_date
LEFT JOIN "reference"."units" wu ON samp.wind_unit_id = wu.unit_id
LEFT JOIN "reference"."units" su ON samp.salinity_unit_id = su.unit_id
LEFT JOIN "reference"."units" ou ON samp.oxygen_unit_id = ou.unit_id
LEFT JOIN "reference"."personal" sampler_p ON s.sampler_person_id = sampler_p.person_id
LEFT JOIN "reference"."personal" receiver_p ON s.receiver_person_id = receiver_p.person_id
LEFT JOIN "lab"."experiments_samples" es ON s.sample_id = es.sample_id AND s.sampling_date = es.experiment_date
LEFT JOIN "lab"."experiments" e ON es.experiment_id = e.experiment_id AND es.experiment_date = e.experiment_date
LEFT JOIN "reference"."personal" exp_person ON e.person_id = exp_person.person_id

UNION ALL
select
    f.sample_id,
    NULL AS external_name,
    f.parent_sample_id,
    'Derived Fish Sample' AS sample_origin_type,
    'Fish' AS sample_type_id,
    'F' AS sample_type_abrv,
    (SELECT status_id FROM "reference"."status" WHERE notes = 'Received') AS sample_status_id, -- Default status
    (SELECT notes FROM "reference"."status" WHERE status_id = 'Received') AS sample_status_notes,
    f.sampling_id,
    f.sampling_date,
    NULL AS reception_date,
    f.project_id,
    p.title AS project_title,
    f.customer_id,
    c.customer_name,
    f.storage_id,
    f.storage_position,
    f.notes,
    f.attachment,
    f.attachment_link,

    -- Sampling Event Details (linked via sampling_id from fish)
    ST_X(samp.geom) AS sampling_lon,
    ST_Y(samp.geom) AS sampling_lat,
    ST_X(samp.fishing_start_geom) AS fishing_start_lon,
    ST_Y(samp.fishing_start_geom) AS fishing_start_lat,
    ST_X(samp.fishing_end_geom) AS fishing_end_lon,
    ST_Y(samp.fishing_end_geom) AS fishing_end_lat,
    samp.location_name AS sampling_location,
    samp.depth_m AS sampling_depth_m,
    samp.temperature_atmospheric_c,
    samp.weather,
    samp.wind_speed,
    wu.unit_abbreviation AS wind_unit,
    samp.salinity,
    su.unit_abbreviation AS salinity_unit,
    samp.oxygen,
    ou.unit_abbreviation AS oxygen_unit,

    -- Fish-specific Details
    f.species_id,
    taxon_sp.en_name AS fish_species_en_name,
    f.total_length_mm,
    f.fork_length_mm,
    f.standard_length_mm,
    f.weight_g,
    f.sex,
    f.maturity_stage,
    f.stomach_contents,
    f.disease_info,
    f.tag_id,

    -- All other specific details are NULL
    NULL::numeric AS tissue_weight_mg, NULL::text AS tissue_type, NULL::text AS tissue_preservation_method,
    NULL::numeric AS dna_volume_ul, NULL::numeric AS dna_concentration_ng_ul, NULL::numeric AS dna_a260_280, NULL::numeric AS dna_a260_230, NULL::text AS dna_extraction_method, NULL::date AS dna_extraction_date_dna, NULL::integer AS dna_extraction_number,
    NULL::numeric AS rna_volume_ul, NULL::numeric AS rna_concentration_ng_ul, NULL::numeric AS rna_a260_280, NULL::numeric AS rna_a260_230, NULL::text AS rna_extraction_method, NULL::date AS rna_extraction_date_rna, NULL::integer AS rna_extraction_number,
    NULL::numeric AS sediment_volume, NULL::text AS sediment_volume_unit, NULL::numeric AS sediment_depth_m, NULL::text AS sediment_sampling_method, NULL::text AS sediment_conservation_buffer,
    NULL::numeric AS water_volume_l, NULL::text AS water_filter, NULL::numeric AS water_filter_pore_size_um, NULL::numeric AS water_depth_m, NULL::text AS water_sampling_method, NULL::text AS water_conservation_buffer,
    NULL::text AS otolith_id, NULL::text AS otolith_reader_person_id, NULL::text AS otolith_side, NULL::numeric AS otolith_age_reading_years, NULL::numeric AS otolith_confidence,
    NULL::text AS dissection_id, NULL::text AS dissection_person_id, NULL::date AS dissection_date, NULL::jsonb AS dissection_stomach_contents_jsonb, NULL::numeric AS dissection_gonad_weight_g, NULL::numeric AS dissection_liver_weight_g,
    NULL::text AS extraction_id, NULL::date AS extraction_process_date, NULL::text AS extraction_process_person_id, NULL::text AS extraction_process_kit, NULL::numeric AS extraction_process_elution_volume_ul, NULL::numeric AS extraction_process_yield_qubit_ng_ul, NULL::numeric AS extraction_process_yield_nanodrop_ng_ul, NULL::numeric AS extraction_process_a260_280, NULL::numeric AS extraction_process_a260_230, NULL::text AS extraction_result_dna_sample_id, NULL::text AS extraction_result_rna_sample_id,
    NULL::text AS extraction_blank_id,
    NULL::text AS nanodrop_id, NULL::numeric AS nanodrop_concentration, NULL::text AS nanodrop_concentration_unit, NULL::numeric AS nanodrop_a260, NULL::numeric AS nanodrop_a260_280_qc, NULL::numeric AS nanodrop_a260_230_qc, NULL::numeric AS nanodrop_total_dna_ug, NULL::date AS nanodrop_measurement_date, NULL::text AS nanodrop_a260_280_note, NULL::text AS nanodrop_a260_230_note,
    NULL::text AS qubit_id, NULL::numeric AS qubit_original_sample_conc, NULL::text AS qubit_original_sample_unit, NULL::numeric AS qubit_total_dna_ug, NULL::date AS qubit_measurement_date, NULL::text AS qubit_assay_kit, NULL::numeric AS qubit_tube_conc, NULL::text AS tube_unit_id, NULL::numeric AS sample_volume_ul, NULL::numeric AS elution_volume_ul,
    NULL::text AS tapestation_id, NULL::date AS tapestation_measurement_date, NULL::text AS tapestation_kit,
    NULL::text AS pcr_id, NULL::date AS pcr_date, NULL::text AS pcr_primer_id, NULL::text AS pcr_target_gene_id, NULL::numeric AS pcr_volume_reaction_ul, NULL::text AS pcr_blank_id, NULL::text AS pcr_position,
    NULL::text AS gel_gelelectrophoresis_id, NULL::date AS gel_run_date, NULL::integer AS gel_band_size_bp, NULL::text AS gel_gel_type, NULL::text AS gel_position, NULL::text AS gel_ladder, NULL::numeric AS gel_voltage, NULL::numeric AS gel_run_time_minutes,
    NULL::text AS qpcr_id, NULL::date AS qpcr_date, NULL::numeric AS qpcr_ct_value, NULL::text AS qpcr_inhibitor_test_result, NULL::text AS qpcr_position, NULL::text AS qpcr_primer_id_actual, NULL::text AS qpcr_pcr_blank_id, NULL::text AS qpcr_kit, NULL::numeric AS qpcr_volume_ul,
    NULL::text AS library_id, NULL::date AS library_prep_date, NULL::text AS library_name, NULL::text AS library_prep_kit, NULL::text AS library_index_sequence, NULL::integer AS library_read_length_bp,
    NULL::text AS sequencing_id, NULL::date AS sequencing_date, NULL::text AS sequencer, NULL::text AS flow_cell_id, NULL::bigint AS total_reads, NULL::text AS raw_data_path, NULL::text AS genbank_accession_number, NULL::text AS sequencing_library_prep_kit, NULL::text AS sequencing_index_sequence, NULL::integer AS sequencing_read_length_bp,
    NULL::text AS analysis_run_id, NULL::text AS pipeline_name, NULL::text AS pipeline_version, NULL::text AS bioinfo_reference_database, NULL::text AS bioinfo_database_version, NULL::numeric AS clustering_threshold, NULL::text AS final_output_path,
    NULL::text AS edna_assignment_id, NULL::text AS edna_assigned_taxon_id, NULL::text AS edna_assigned_taxon_name, NULL::integer AS edna_read_count, NULL::numeric AS edna_confidence,
    e.experiment_id AS associated_experiment_id, e.experiment_title AS associated_experiment_title, e.experiment_date AS associated_experiment_date, e.aim AS associated_experiment_aim, e.method AS associated_experiment_method, exp_person.full_name AS experiment_person_name,
    NULL::text AS sampler_full_name, NULL::text AS receiver_full_name

FROM
    "lab"."fish" f
LEFT JOIN "lims"."projects" p ON f.project_id = p.project_id
LEFT JOIN "lims"."customers" c ON f.customer_id = c.customer_id
LEFT JOIN "lab"."sampling" samp ON f.sampling_id = samp.sampling_id AND f.sampling_date = samp.sampling_date
LEFT JOIN "reference"."units" wu ON samp.wind_unit_id = wu.unit_id
LEFT JOIN "reference"."units" su ON samp.salinity_unit_id = su.unit_id
LEFT JOIN "reference"."units" ou ON samp.oxygen_unit_id = ou.unit_id
LEFT JOIN "reference"."taxon" taxon_sp ON f.species_id = taxon_sp.taxon_id
LEFT JOIN "lab"."experiments_samples" es ON f.sample_id = es.sample_id AND f.sampling_date = es.experiment_date
LEFT JOIN "lab"."experiments" e ON es.experiment_id = e.experiment_id AND es.experiment_date = e.experiment_date
LEFT JOIN "reference"."personal" exp_person ON e.person_id = exp_person.person_id

UNION ALL

SELECT
    t.sample_id,
    NULL AS external_name,
    t.parent_sample_id,
    'Derived Tissue Sample' AS sample_origin_type,
    'Tissue' AS sample_type_id,
    'T' AS sample_type_abrv,
    (SELECT status_id FROM "reference"."status" WHERE notes = 'Received') AS sample_status_id,
    (SELECT notes FROM "reference"."status" WHERE status_id = 'Received') AS sample_status_notes,
    NULL::text AS sampling_id,
    t.experiment_date AS sampling_date,
    NULL AS reception_date,
    t.project_id,
    p.title AS project_title,
    NULL::integer AS customer_id,
    NULL::text AS customer_name,
    t.storage_id,
    t.storage_position,
    t.notes,
    t.attachment,
    t.attachment_link,

    -- Sampling Event Details (NULL for derived tissue, might come from parent)
    NULL::numeric AS sampling_lon, NULL::numeric AS sampling_lat, NULL::numeric AS fishing_start_lon, NULL::numeric AS fishing_start_lat, NULL::numeric AS fishing_end_lon, NULL::numeric AS fishing_end_lat,
    NULL::text AS sampling_location, NULL::numeric AS sampling_depth_m, NULL::numeric AS temperature_atmospheric_c, NULL::text AS weather, NULL::numeric AS wind_speed, NULL::text AS wind_unit,
    NULL::numeric AS salinity, NULL::text AS salinity_unit, NULL::numeric AS oxygen, NULL::text AS oxygen_unit,

    -- Fish-specific Details (NULL)
    NULL::text AS fish_species_id, NULL::text AS fish_species_en_name, NULL::numeric AS fish_total_length_mm, NULL::numeric AS fish_fork_length_mm, NULL::numeric AS fish_standard_length_mm, NULL::numeric AS fish_weight_g, NULL::text AS fish_sex, NULL::text AS fish_maturity_stage, NULL::text AS fish_stomach_contents, NULL::text AS fish_disease_info, NULL::text AS fish_tag_id,

    -- Tissue-specific Details
    t.weight_mg,
    t.tissue_type,
    t.preservation_method,

    -- All other specific details are NULL
    NULL::numeric AS dna_volume_ul, NULL::numeric AS dna_concentration_ng_ul, NULL::numeric AS dna_a260_280, NULL::numeric AS dna_a260_230, NULL::text AS dna_extraction_method, NULL::date AS dna_extraction_date_dna, NULL::integer AS dna_extraction_number,
    NULL::numeric AS rna_volume_ul, NULL::numeric AS rna_concentration_ng_ul, NULL::numeric AS rna_a260_280, NULL::numeric AS rna_a260_230, NULL::text AS rna_extraction_method, NULL::date AS rna_extraction_date_rna, NULL::integer AS rna_extraction_number,
    NULL::numeric AS sediment_volume, NULL::text AS sediment_volume_unit, NULL::numeric AS sediment_depth_m, NULL::text AS sediment_sampling_method, NULL::text AS sediment_conservation_buffer,
    NULL::numeric AS water_volume_l, NULL::text AS water_filter, NULL::numeric AS water_filter_pore_size_um, NULL::numeric AS water_depth_m, NULL::text AS water_sampling_method, NULL::text AS water_conservation_buffer,
    NULL::text AS otolith_id, NULL::text AS otolith_reader_person_id, NULL::text AS otolith_side, NULL::numeric AS otolith_age_reading_years, NULL::numeric AS otolith_confidence,
    NULL::text AS dissection_id, NULL::text AS dissection_person_id, NULL::date AS dissection_date, NULL::jsonb AS dissection_stomach_contents_jsonb, NULL::numeric AS dissection_gonad_weight_g, NULL::numeric AS dissection_liver_weight_g,
    NULL::text AS extraction_id, NULL::date AS extraction_process_date, NULL::text AS extraction_process_person_id, NULL::text AS extraction_process_kit, NULL::numeric AS extraction_process_elution_volume_ul, NULL::numeric AS extraction_process_yield_qubit_ng_ul, NULL::numeric AS extraction_process_yield_nanodrop_ng_ul, NULL::numeric AS extraction_process_a260_280, NULL::numeric AS extraction_process_a260_230, NULL::text AS extraction_result_dna_sample_id, NULL::text AS extraction_result_rna_sample_id,
    NULL::text AS extraction_blank_id,
    NULL::text AS nanodrop_id, NULL::numeric AS nanodrop_concentration, NULL::text AS nanodrop_concentration_unit, NULL::numeric AS nanodrop_a260, NULL::numeric AS nanodrop_a260_280_qc, NULL::numeric AS nanodrop_a260_230_qc, NULL::numeric AS nanodrop_total_dna_ug, NULL::date AS nanodrop_measurement_date, NULL::text AS nanodrop_a260_280_note, NULL::text AS nanodrop_a260_230_note,
    NULL::text AS qubit_id, NULL::numeric AS qubit_original_sample_conc, NULL::text AS qubit_original_sample_unit, NULL::numeric AS qubit_total_dna_ug, NULL::date AS qubit_measurement_date, NULL::text AS qubit_assay_kit, NULL::numeric AS qubit_tube_conc, NULL::text AS tube_unit_id, NULL::numeric AS sample_volume_ul, NULL::numeric AS elution_volume_ul,
    NULL::text AS tapestation_id, NULL::date AS tapestation_measurement_date, NULL::text AS tapestation_kit,
    NULL::text AS pcr_id, NULL::date AS pcr_date, NULL::text AS pcr_primer_id, NULL::text AS pcr_target_gene_id, NULL::numeric AS pcr_volume_reaction_ul, NULL::text AS pcr_blank_id, NULL::text AS pcr_position,
    NULL::text AS gel_gelelectrophoresis_id, NULL::date AS gel_run_date, NULL::integer AS gel_band_size_bp, NULL::text AS gel_gel_type, NULL::text AS gel_position, NULL::text AS gel_ladder, NULL::numeric AS gel_voltage, NULL::numeric AS gel_run_time_minutes,
    NULL::text AS qpcr_id, NULL::date AS qpcr_date, NULL::numeric AS qpcr_ct_value, NULL::text AS qpcr_inhibitor_test_result, NULL::text AS qpcr_position, NULL::text AS qpcr_primer_id_actual, NULL::text AS qpcr_pcr_blank_id, NULL::text AS qpcr_kit, NULL::numeric AS qpcr_volume_ul,
    NULL::text AS library_id, NULL::date AS library_prep_date, NULL::text AS library_name, NULL::text AS library_prep_kit, NULL::text AS library_index_sequence, NULL::integer AS library_read_length_bp,
    NULL::text AS sequencing_id, NULL::date AS sequencing_date, NULL::text AS sequencer, NULL::text AS flow_cell_id, NULL::bigint AS total_reads, NULL::text AS raw_data_path, NULL::text AS genbank_accession_number, NULL::text AS sequencing_library_prep_kit, NULL::text AS sequencing_index_sequence, NULL::integer AS sequencing_read_length_bp,
    NULL::text AS analysis_run_id, NULL::text AS pipeline_name, NULL::text AS pipeline_version, NULL::text AS bioinfo_reference_database, NULL::text AS bioinfo_database_version, NULL::numeric AS clustering_threshold, NULL::text AS final_output_path,
    NULL::text AS edna_assignment_id, NULL::text AS edna_assigned_taxon_id, NULL::text AS edna_assigned_taxon_name, NULL::integer AS edna_read_count, NULL::numeric AS edna_confidence,
    e.experiment_id AS associated_experiment_id, e.experiment_title AS associated_experiment_title, e.experiment_date AS associated_experiment_date, e.aim AS associated_experiment_aim, e.method AS associated_experiment_method, exp_person.full_name AS experiment_person_name,
    NULL::text AS sampler_full_name, NULL::text AS receiver_full_name

FROM
    "lab"."tissue" t
LEFT JOIN "lims"."projects" p ON t.project_id = p.project_id
LEFT JOIN "lab"."experiments" e ON t.experiment_id = e.experiment_id AND t.experiment_date = e.experiment_date
LEFT JOIN "reference"."personal" exp_person ON e.person_id = exp_person.person_id

UNION ALL
SELECT
    d.sample_id,
    NULL AS external_name,
    d.parent_sample_id,
    'Derived DNA Sample' AS sample_origin_type,
    'DNA' AS sample_type_id,
    'D' AS sample_type_abrv,
    (SELECT status_id FROM "reference"."status" WHERE notes = 'Received') AS sample_status_id,
    (SELECT notes FROM "reference"."status" WHERE status_id = 'Received') AS sample_status_notes,
    NULL::text AS sampling_id,
    d.experiment_date AS sampling_date,
    d.extraction_date AS reception_date,
    d.project_id,
    p.title AS project_title,
    NULL::integer AS customer_id,
    NULL::text AS customer_name,
    d.storage_id,
    d.storage_position,
    d.notes,
    d.attachment,
    d.attachment_link,

    -- Sampling Event Details (NULL)
    NULL::numeric AS sampling_lon, NULL::numeric AS sampling_lat, NULL::numeric AS fishing_start_lon, NULL::numeric AS fishing_start_lat, NULL::numeric AS fishing_end_lon, NULL::numeric AS fishing_end_lat,
    NULL::text AS sampling_location, NULL::numeric AS sampling_depth_m, NULL::numeric AS temperature_atmospheric_c, NULL::text AS weather, NULL::numeric AS wind_speed, NULL::text AS wind_unit,
    NULL::numeric AS salinity, NULL::text AS salinity_unit, NULL::numeric AS oxygen, NULL::text AS oxygen_unit,

    -- Fish-specific Details (NULL)
    NULL::text AS fish_species_id, NULL::text AS fish_species_en_name, NULL::numeric AS fish_total_length_mm, NULL::numeric AS fish_fork_length_mm, NULL::numeric AS fish_standard_length_mm, NULL::numeric AS fish_weight_g, NULL::text AS fish_sex, NULL::text AS fish_maturity_stage, NULL::text AS fish_stomach_contents, NULL::text AS fish_disease_info, NULL::text AS fish_tag_id,

    -- Tissue-specific Details (NULL)
    NULL::numeric AS tissue_weight_mg, NULL::text AS tissue_type, NULL::text AS tissue_preservation_method,

    -- DNA-specific Details
    d.volume_ul,
    d.concentration_ng_ul,
    d.a260_280,
    d.a260_230,
    d.extraction_method,
    d.extraction_date AS dna_extraction_date_dna,
    d.extraction_number,

    -- All other specific details are NULL
    NULL::numeric AS rna_volume_ul, NULL::numeric AS rna_concentration_ng_ul, NULL::numeric AS rna_a260_280, NULL::numeric AS rna_a260_230, NULL::text AS rna_extraction_method, NULL::date AS rna_extraction_date_rna, NULL::integer AS rna_extraction_number,
    NULL::numeric AS sediment_volume, NULL::text AS sediment_volume_unit, NULL::numeric AS sediment_depth_m, NULL::text AS sediment_sampling_method, NULL::text AS sediment_conservation_buffer,
    NULL::numeric AS water_volume_l, NULL::text AS water_filter, NULL::numeric AS water_filter_pore_size_um, NULL::numeric AS water_depth_m, NULL::text AS water_sampling_method, NULL::text AS water_conservation_buffer,
    NULL::text AS otolith_id, NULL::text AS otolith_reader_person_id, NULL::text AS otolith_side, NULL::numeric AS otolith_age_reading_years, NULL::numeric AS otolith_confidence,
    NULL::text AS dissection_id, NULL::text AS dissection_person_id, NULL::date AS dissection_date, NULL::jsonb AS dissection_stomach_contents_jsonb, NULL::numeric AS dissection_gonad_weight_g, NULL::numeric AS dissection_liver_weight_g,
    NULL::text AS extraction_id, NULL::date AS extraction_process_date, NULL::text AS extraction_process_person_id, NULL::text AS extraction_process_kit, NULL::numeric AS extraction_process_elution_volume_ul, NULL::numeric AS extraction_process_yield_qubit_ng_ul, NULL::numeric AS extraction_process_yield_nanodrop_ng_ul, NULL::numeric AS extraction_process_a260_280, NULL::numeric AS extraction_process_a260_230, NULL::text AS extraction_result_dna_sample_id, NULL::text AS extraction_result_rna_sample_id,
    NULL::text AS extraction_blank_id,
    NULL::text AS nanodrop_id, NULL::numeric AS nanodrop_concentration, NULL::text AS nanodrop_concentration_unit, NULL::numeric AS nanodrop_a260, NULL::numeric AS nanodrop_a260_280_qc, NULL::numeric AS nanodrop_a260_230_qc, NULL::numeric AS nanodrop_total_dna_ug, NULL::date AS nanodrop_measurement_date, NULL::text AS nanodrop_a260_280_note, NULL::text AS nanodrop_a260_230_note,
    NULL::text AS qubit_id, NULL::numeric AS qubit_original_sample_conc, NULL::text AS qubit_original_sample_unit, NULL::numeric AS qubit_total_dna_ug, NULL::date AS qubit_measurement_date, NULL::text AS qubit_assay_kit, NULL::numeric AS qubit_tube_conc, NULL::text AS tube_unit_id, NULL::numeric AS sample_volume_ul, NULL::numeric AS elution_volume_ul,
    NULL::text AS tapestation_id, NULL::date AS tapestation_measurement_date, NULL::text AS tapestation_kit,
    NULL::text AS pcr_id, NULL::date AS pcr_date, NULL::text AS pcr_primer_id, NULL::text AS pcr_target_gene_id, NULL::numeric AS pcr_volume_reaction_ul, NULL::text AS pcr_blank_id, NULL::text AS pcr_position,
    NULL::text AS gel_gelelectrophoresis_id, NULL::date AS gel_run_date, NULL::integer AS gel_band_size_bp, NULL::text AS gel_gel_type, NULL::text AS gel_position, NULL::text AS gel_ladder, NULL::numeric AS gel_voltage, NULL::numeric AS gel_run_time_minutes,
    NULL::text AS qpcr_id, NULL::date AS qpcr_date, NULL::numeric AS qpcr_ct_value, NULL::text AS qpcr_inhibitor_test_result, NULL::text AS qpcr_position, NULL::text AS qpcr_primer_id_actual, NULL::text AS qpcr_pcr_blank_id, NULL::text AS qpcr_kit, NULL::numeric AS qpcr_volume_ul,
    NULL::text AS library_id, NULL::date AS library_prep_date, NULL::text AS library_name, NULL::text AS library_prep_kit, NULL::text AS library_index_sequence, NULL::integer AS library_read_length_bp,
    NULL::text AS sequencing_id, NULL::date AS sequencing_date, NULL::text AS sequencer, NULL::text AS flow_cell_id, NULL::bigint AS total_reads, NULL::text AS raw_data_path, NULL::text AS genbank_accession_number, NULL::text AS sequencing_library_prep_kit, NULL::text AS sequencing_index_sequence, NULL::integer AS sequencing_read_length_bp,
    NULL::text AS analysis_run_id, NULL::text AS pipeline_name, NULL::text AS pipeline_version, NULL::text AS bioinfo_reference_database, NULL::text AS bioinfo_database_version, NULL::numeric AS clustering_threshold, NULL::text AS final_output_path,
    NULL::text AS edna_assignment_id, NULL::text AS edna_assigned_taxon_id, NULL::text AS edna_assigned_taxon_name, NULL::integer AS edna_read_count, NULL::numeric AS edna_confidence,
    e.experiment_id AS associated_experiment_id, e.experiment_title AS associated_experiment_title, e.experiment_date AS associated_experiment_date, e.aim AS associated_experiment_aim, e.method AS associated_experiment_method, exp_person.full_name AS experiment_person_name,
    NULL::text AS sampler_full_name, NULL::text AS receiver_full_name

FROM
    "lab"."dna" d
LEFT JOIN "lims"."projects" p ON d.project_id = p.project_id
LEFT JOIN "lab"."experiments" e ON d.experiment_id = e.experiment_id AND d.experiment_date = e.experiment_date
LEFT JOIN "reference"."personal" exp_person ON e.person_id = exp_person.person_id

UNION ALL

SELECT
    r.sample_id,
    NULL AS external_name,
    r.parent_sample_id,
    'Derived RNA Sample' AS sample_origin_type,
    'RNA' AS sample_type_id,
    'R' AS sample_type_abrv,
    (SELECT status_id FROM "reference"."status" WHERE notes = 'Received') AS sample_status_id,
    (SELECT notes FROM "reference"."status" WHERE status_id = 'Received') AS sample_status_notes,
    NULL::text AS sampling_id,
    r.experiment_date AS sampling_date,
    r.extraction_date AS reception_date,
    r.project_id,
    p.title AS project_title,
    NULL::integer AS customer_id,
    NULL::text AS customer_name,
    r.storage_id,
    r.storage_position,
    r.notes,
    r.attachment,
    r.attachment_link,

    -- Sampling Event Details (NULL)
    NULL::numeric AS sampling_lon, NULL::numeric AS sampling_lat, NULL::numeric AS fishing_start_lon, NULL::numeric AS fishing_start_lat, NULL::numeric AS fishing_end_lon, NULL::numeric AS fishing_end_lat,
    NULL::text AS sampling_location, NULL::numeric AS sampling_depth_m, NULL::numeric AS temperature_atmospheric_c, NULL::text AS weather, NULL::numeric AS wind_speed, NULL::text AS wind_unit,
    NULL::numeric AS salinity, NULL::text AS salinity_unit, NULL::numeric AS oxygen, NULL::text AS oxygen_unit,

    -- Fish-specific Details (NULL)
    NULL::text AS fish_species_id, NULL::text AS fish_species_en_name, NULL::numeric AS fish_total_length_mm, NULL::numeric AS fish_fork_length_mm, NULL::numeric AS fish_standard_length_mm, NULL::numeric AS fish_weight_g, NULL::text AS fish_sex, NULL::text AS fish_maturity_stage, NULL::text AS fish_stomach_contents, NULL::text AS fish_disease_info, NULL::text AS fish_tag_id,

    -- Tissue-specific Details (NULL)
    NULL::numeric AS tissue_weight_mg, NULL::text AS tissue_type, NULL::text AS tissue_preservation_method,

    -- DNA-specific Details (NULL)
    NULL::numeric AS dna_volume_ul, NULL::numeric AS dna_concentration_ng_ul, NULL::numeric AS dna_a260_280, NULL::numeric AS dna_a260_230, NULL::text AS dna_extraction_method, NULL::date AS dna_extraction_date_dna, NULL::integer AS dna_extraction_number,

    -- RNA-specific Details
    r.volume_ul,
    r.concentration_ng_ul,
    r.a260_280,
    r.a260_230,
    r.extraction_method,
    r.extraction_date AS rna_extraction_date_rna,
    r.extraction_number,

    -- All other specific details are NULL
    NULL::numeric AS sediment_volume, NULL::text AS sediment_volume_unit, NULL::numeric AS sediment_depth_m, NULL::text AS sediment_sampling_method, NULL::text AS sediment_conservation_buffer,
    NULL::numeric AS water_volume_l, NULL::text AS water_filter, NULL::numeric AS water_filter_pore_size_um, NULL::numeric AS water_depth_m, NULL::text AS water_sampling_method, NULL::text AS water_conservation_buffer,
    NULL::text AS otolith_id, NULL::text AS otolith_reader_person_id, NULL::text AS otolith_side, NULL::numeric AS otolith_age_reading_years, NULL::numeric AS otolith_confidence,
    NULL::text AS dissection_id, NULL::text AS dissection_person_id, NULL::date AS dissection_date, NULL::jsonb AS dissection_stomach_contents_jsonb, NULL::numeric AS dissection_gonad_weight_g, NULL::numeric AS dissection_liver_weight_g,
    NULL::text AS extraction_id, NULL::date AS extraction_process_date, NULL::text AS extraction_process_person_id, NULL::text AS extraction_process_kit, NULL::numeric AS extraction_process_elution_volume_ul, NULL::numeric AS extraction_process_yield_qubit_ng_ul, NULL::numeric AS extraction_process_yield_nanodrop_ng_ul, NULL::numeric AS extraction_process_a260_280, NULL::numeric AS extraction_process_a260_230, NULL::text AS extraction_result_dna_sample_id, NULL::text AS extraction_result_rna_sample_id,
    NULL::text AS extraction_blank_id,
    NULL::text AS nanodrop_id, NULL::numeric AS nanodrop_concentration, NULL::text AS nanodrop_concentration_unit, NULL::numeric AS nanodrop_a260, NULL::numeric AS nanodrop_a260_280_qc, NULL::numeric AS nanodrop_a260_230_qc, NULL::numeric AS nanodrop_total_dna_ug, NULL::date AS nanodrop_measurement_date, NULL::text AS nanodrop_a260_280_note, NULL::text AS nanodrop_a260_230_note,
    NULL::text AS qubit_id, NULL::numeric AS qubit_original_sample_conc, NULL::text AS qubit_original_sample_unit, NULL::numeric AS qubit_total_dna_ug, NULL::date AS qubit_measurement_date, NULL::text AS qubit_assay_kit, NULL::numeric AS qubit_tube_conc, NULL::text AS tube_unit_id, NULL::numeric AS sample_volume_ul, NULL::numeric AS elution_volume_ul,
    NULL::text AS tapestation_id, NULL::date AS tapestation_measurement_date, NULL::text AS tapestation_kit,
    NULL::text AS pcr_id, NULL::date AS pcr_date, NULL::text AS pcr_primer_id, NULL::text AS pcr_target_gene_id, NULL::numeric AS pcr_volume_reaction_ul, NULL::text AS pcr_blank_id, NULL::text AS pcr_position,
    NULL::text AS gel_gelelectrophoresis_id, NULL::date AS gel_run_date, NULL::integer AS gel_band_size_bp, NULL::text AS gel_gel_type, NULL::text AS gel_position, NULL::text AS gel_ladder, NULL::numeric AS gel_voltage, NULL::numeric AS gel_run_time_minutes,
    NULL::text AS qpcr_id, NULL::date AS qpcr_date, NULL::numeric AS qpcr_ct_value, NULL::text AS qpcr_inhibitor_test_result, NULL::text AS qpcr_position, NULL::text AS qpcr_primer_id_actual, NULL::text AS qpcr_pcr_blank_id, NULL::text AS qpcr_kit, NULL::numeric AS qpcr_volume_ul,
    NULL::text AS library_id, NULL::date AS library_prep_date, NULL::text AS library_name, NULL::text AS library_prep_kit, NULL::text AS library_index_sequence, NULL::integer AS library_read_length_bp,
    NULL::text AS sequencing_id, NULL::date AS sequencing_date, NULL::text AS sequencer, NULL::text AS flow_cell_id, NULL::bigint AS total_reads, NULL::text AS raw_data_path, NULL::text AS genbank_accession_number, NULL::text AS sequencing_library_prep_kit, NULL::text AS sequencing_index_sequence, NULL::integer AS sequencing_read_length_bp,
    NULL::text AS analysis_run_id, NULL::text AS pipeline_name, NULL::text AS pipeline_version, NULL::text AS bioinfo_reference_database, NULL::text AS bioinfo_database_version, NULL::numeric AS clustering_threshold, NULL::text AS final_output_path,
    NULL::text AS edna_assignment_id, NULL::text AS edna_assigned_taxon_id, NULL::text AS edna_assigned_taxon_name, NULL::integer AS edna_read_count, NULL::numeric AS edna_confidence,
    e.experiment_id AS associated_experiment_id, e.experiment_title AS associated_experiment_title, e.experiment_date AS associated_experiment_date, e.aim AS associated_experiment_aim, e.method AS associated_experiment_method, exp_person.full_name AS experiment_person_name,
    NULL::text AS sampler_full_name, NULL::text AS receiver_full_name

FROM
    "lab"."rna" r
LEFT JOIN "lims"."projects" p ON r.project_id = p.project_id
LEFT JOIN "lab"."experiments" e ON r.experiment_id = e.experiment_id AND r.experiment_date = e.experiment_date
LEFT JOIN "reference"."personal" exp_person ON e.person_id = exp_person.person_id

UNION ALL

SELECT
    sed.sample_id,
    sed.external_name,
    sed.parent_sample_id,
    'Derived Sediment Sample' AS sample_origin_type,
    'Sediments' AS sample_type_id,
    'S' AS sample_type_abrv,
    (SELECT status_id FROM "reference"."status" WHERE notes = 'Received') AS sample_status_id,
    (SELECT notes FROM "reference"."status" WHERE status_id = 'Received') AS sample_status_notes,
    NULL::text AS sampling_id,
    sed.experiment_date AS sampling_date,
    NULL AS reception_date,
    sed.project_id,
    p.title AS project_title,
    NULL::integer AS customer_id,
    NULL::text AS customer_name,
    sed.storage_id,
    sed.storage_position,
    sed.notes,
    sed.attachment,
    sed.attachment_link,

    -- Sampling Event Details (NULL)
    NULL::numeric AS sampling_lon, NULL::numeric AS sampling_lat, NULL::numeric AS fishing_start_lon, NULL::numeric AS fishing_start_lat, NULL::numeric AS fishing_end_lon, NULL::numeric AS fishing_end_lat,
    NULL::text AS sampling_location, NULL::numeric AS sampling_depth_m, NULL::numeric AS temperature_atmospheric_c, NULL::text AS weather, NULL::numeric AS wind_speed, NULL::text AS wind_unit,
    NULL::numeric AS salinity, NULL::text AS salinity_unit, NULL::numeric AS oxygen, NULL::text AS oxygen_unit,

    -- Fish-specific Details (NULL)
    NULL::text AS fish_species_id, NULL::text AS fish_species_en_name, NULL::numeric AS fish_total_length_mm, NULL::numeric AS fish_fork_length_mm, NULL::numeric AS fish_standard_length_mm, NULL::numeric AS fish_weight_g, NULL::text AS fish_sex, NULL::text AS fish_maturity_stage, NULL::text AS fish_stomach_contents, NULL::text AS fish_disease_info, NULL::text AS fish_tag_id,

    -- Tissue-specific Details (NULL)
    NULL::numeric AS tissue_weight_mg, NULL::text AS tissue_type, NULL::text AS tissue_preservation_method,

    -- DNA-specific Details (NULL)
    NULL::numeric AS dna_volume_ul, NULL::numeric AS dna_concentration_ng_ul, NULL::numeric AS dna_a260_280, NULL::numeric AS dna_a260_230, NULL::text AS dna_extraction_method, NULL::date AS dna_extraction_date_dna, NULL::integer AS dna_extraction_number,

    -- RNA-specific Details (NULL)
    NULL::numeric AS rna_volume_ul, NULL::numeric AS rna_concentration_ng_ul, NULL::numeric AS rna_a260_280, NULL::numeric AS rna_a260_230, NULL::text AS rna_extraction_method, NULL::date AS rna_extraction_date_rna, NULL::integer AS rna_extraction_number,

    -- Sediments-specific Details
    sed.volume,
    svu.unit_abbreviation AS sediment_volume_unit,
    sed.depth_m,
    sed.sampling_method,
    sed.conservation_buffer,

    -- All other specific details are NULL
    NULL::numeric AS water_volume_l, NULL::text AS water_filter, NULL::numeric AS water_filter_pore_size_um, NULL::numeric AS water_depth_m, NULL::text AS water_sampling_method, NULL::text AS water_conservation_buffer,
    NULL::text AS otolith_id, NULL::text AS otolith_reader_person_id, NULL::text AS otolith_side, NULL::numeric AS otolith_age_reading_years, NULL::numeric AS otolith_confidence,
    NULL::text AS dissection_id, NULL::text AS dissection_person_id, NULL::date AS dissection_date, NULL::jsonb AS dissection_stomach_contents_jsonb, NULL::numeric AS dissection_gonad_weight_g, NULL::numeric AS dissection_liver_weight_g,
    NULL::text AS extraction_id, NULL::date AS extraction_process_date, NULL::text AS extraction_process_person_id, NULL::text AS extraction_process_kit, NULL::numeric AS extraction_process_elution_volume_ul, NULL::numeric AS extraction_process_yield_qubit_ng_ul, NULL::numeric AS extraction_process_yield_nanodrop_ng_ul, NULL::numeric AS extraction_process_a260_280, NULL::numeric AS extraction_process_a260_230, NULL::text AS extraction_result_dna_sample_id, NULL::text AS extraction_result_rna_sample_id,
    NULL::text AS extraction_blank_id,
    NULL::text AS nanodrop_id, NULL::numeric AS nanodrop_concentration, NULL::text AS nanodrop_concentration_unit, NULL::numeric AS nanodrop_a260, NULL::numeric AS nanodrop_a260_280_qc, NULL::numeric AS nanodrop_a260_230_qc, NULL::numeric AS nanodrop_total_dna_ug, NULL::date AS nanodrop_measurement_date, NULL::text AS nanodrop_a260_280_note, NULL::text AS nanodrop_a260_230_note,
    NULL::text AS qubit_id, NULL::numeric AS qubit_original_sample_conc, NULL::text AS qubit_original_sample_unit, NULL::numeric AS qubit_total_dna_ug, NULL::date AS qubit_measurement_date, NULL::text AS qubit_assay_kit, NULL::numeric AS qubit_tube_conc, NULL::text AS tube_unit_id, NULL::numeric AS sample_volume_ul, NULL::numeric AS elution_volume_ul,
    NULL::text AS tapestation_id, NULL::date AS tapestation_measurement_date, NULL::text AS tapestation_kit,
    NULL::text AS pcr_id, NULL::date AS pcr_date, NULL::text AS pcr_primer_id, NULL::text AS pcr_target_gene_id, NULL::numeric AS pcr_volume_reaction_ul, NULL::text AS pcr_blank_id, NULL::text AS pcr_position,
    NULL::text AS gel_gelelectrophoresis_id, NULL::date AS gel_run_date, NULL::integer AS gel_band_size_bp, NULL::text AS gel_gel_type, NULL::text AS gel_position, NULL::text AS gel_ladder, NULL::numeric AS gel_voltage, NULL::numeric AS gel_run_time_minutes,
    NULL::text AS qpcr_id, NULL::date AS qpcr_date, NULL::numeric AS qpcr_ct_value, NULL::text AS qpcr_inhibitor_test_result, NULL::text AS qpcr_position, NULL::text AS qpcr_primer_id_actual, NULL::text AS qpcr_pcr_blank_id, NULL::text AS qpcr_kit, NULL::numeric AS qpcr_volume_ul,
    NULL::text AS library_id, NULL::date AS library_prep_date, NULL::text AS library_name, NULL::text AS library_prep_kit, NULL::text AS library_index_sequence, NULL::integer AS library_read_length_bp,
    NULL::text AS sequencing_id, NULL::date AS sequencing_date, NULL::text AS sequencer, NULL::text AS flow_cell_id, NULL::bigint AS total_reads, NULL::text AS raw_data_path, NULL::text AS genbank_accession_number, NULL::text AS sequencing_library_prep_kit, NULL::text AS sequencing_index_sequence, NULL::integer AS sequencing_read_length_bp,
    NULL::text AS analysis_run_id, NULL::text AS pipeline_name, NULL::text AS pipeline_version, NULL::text AS bioinfo_reference_database, NULL::text AS bioinfo_database_version, NULL::numeric AS clustering_threshold, NULL::text AS final_output_path,
    NULL::text AS edna_assignment_id, NULL::text AS edna_assigned_taxon_id, NULL::text AS edna_assigned_taxon_name, NULL::integer AS edna_read_count, NULL::numeric AS edna_confidence,
    e.experiment_id AS associated_experiment_id, e.experiment_title AS associated_experiment_title, e.experiment_date AS associated_experiment_date, e.aim AS associated_experiment_aim, e.method AS associated_experiment_method, exp_person.full_name AS experiment_person_name,
    NULL::text AS sampler_full_name, NULL::text AS receiver_full_name

FROM
    "lab"."sediments" sed
LEFT JOIN "lims"."projects" p ON sed.project_id = p.project_id
LEFT JOIN "reference"."units" svu ON sed.volume_unit_id = svu.unit_id
LEFT JOIN "lab"."experiments" e ON sed.experiment_id = e.experiment_id AND sed.experiment_date = e.experiment_date
LEFT JOIN "reference"."personal" exp_person ON e.person_id = exp_person.person_id

UNION ALL

SELECT
    w.sample_id,
    NULL AS external_name,
    w.parent_sample_id,
    'Derived Water Sample' AS sample_origin_type,
    'Water' AS sample_type_id,
    'W' AS sample_type_abrv,
    (SELECT status_id FROM "reference"."status" WHERE notes = 'Received') AS sample_status_id,
    (SELECT notes FROM "reference"."status" WHERE status_id = 'Received') AS sample_status_notes,
    NULL::text AS sampling_id,
    w.experiment_date AS sampling_date,
    NULL AS reception_date,
    w.project_id,
    p.title AS project_title,
    NULL::integer AS customer_id,
    NULL::text AS customer_name,
    w.storage_id,
    w.storage_position,
    w.notes,
    w.attachment,
    w.attachment_link,

    -- Sampling Event Details (NULL)
    NULL::numeric AS sampling_lon, NULL::numeric AS sampling_lat, NULL::numeric AS fishing_start_lon, NULL::numeric AS fishing_start_lat, NULL::numeric AS fishing_end_lon, NULL::numeric AS fishing_end_lat,
    NULL::text AS sampling_location, NULL::numeric AS sampling_depth_m, NULL::numeric AS temperature_atmospheric_c, NULL::text AS weather, NULL::numeric AS wind_speed, NULL::text AS wind_unit,
    NULL::numeric AS salinity, NULL::text AS salinity_unit, NULL::numeric AS oxygen, NULL::text AS oxygen_unit,

    -- Fish-specific Details (NULL)
    NULL::text AS fish_species_id, NULL::text AS fish_species_en_name, NULL::numeric AS fish_total_length_mm, NULL::numeric AS fish_fork_length_mm, NULL::numeric AS fish_standard_length_mm, NULL::numeric AS fish_weight_g, NULL::text AS fish_sex, NULL::text AS fish_maturity_stage, NULL::text AS fish_stomach_contents, NULL::text AS fish_disease_info, NULL::text AS fish_tag_id,

    -- Tissue-specific Details (NULL)
    NULL::numeric AS tissue_weight_mg, NULL::text AS tissue_type, NULL::text AS tissue_preservation_method,

    -- DNA-specific Details (NULL)
    NULL::numeric AS dna_volume_ul, NULL::numeric AS dna_concentration_ng_ul, NULL::numeric AS dna_a260_280, NULL::numeric AS dna_a260_230, NULL::text AS dna_extraction_method, NULL::date AS dna_extraction_date_dna, NULL::integer AS dna_extraction_number,

    -- RNA-specific Details (NULL)
    NULL::numeric AS rna_volume_ul, NULL::numeric AS rna_concentration_ng_ul, NULL::numeric AS rna_a260_280, NULL::numeric AS rna_a260_230, NULL::text AS rna_extraction_method, NULL::date AS rna_extraction_date_rna, NULL::integer AS rna_extraction_number,

    -- Sediments-specific Details (NULL)
    NULL::numeric AS sediment_volume, NULL::text AS sediment_volume_unit, NULL::numeric AS sediment_depth_m, NULL::text AS sediment_sampling_method, NULL::text AS sediment_conservation_buffer,

    -- Water-specific Details
    w.volume_l,
    w.filter,
    w.filter_pore_size_um,
    w.depth_m,
    w.sampling_method,
    w.conservation_buffer,

    -- All other specific details are NULL
    NULL::text AS otolith_id, NULL::text AS otolith_reader_person_id, NULL::text AS otolith_side, NULL::numeric AS otolith_age_reading_years, NULL::numeric AS otolith_confidence,
    NULL::text AS dissection_id, NULL::text AS dissection_person_id, NULL::date AS dissection_date, NULL::jsonb AS dissection_stomach_contents_jsonb, NULL::numeric AS dissection_gonad_weight_g, NULL::numeric AS dissection_liver_weight_g,
    NULL::text AS extraction_id, NULL::date AS extraction_process_date, NULL::text AS extraction_process_person_id, NULL::text AS extraction_process_kit, NULL::numeric AS extraction_process_elution_volume_ul, NULL::numeric AS extraction_process_yield_qubit_ng_ul, NULL::numeric AS extraction_process_yield_nanodrop_ng_ul, NULL::numeric AS extraction_process_a260_280, NULL::numeric AS extraction_process_a260_230, NULL::text AS extraction_result_dna_sample_id, NULL::text AS extraction_result_rna_sample_id,
    NULL::text AS extraction_blank_id,
    NULL::text AS nanodrop_id, NULL::numeric AS nanodrop_concentration, NULL::text AS nanodrop_concentration_unit, NULL::numeric AS nanodrop_a260, NULL::numeric AS nanodrop_a260_280_qc, NULL::numeric AS nanodrop_a260_230_qc, NULL::numeric AS nanodrop_total_dna_ug, NULL::date AS nanodrop_measurement_date, NULL::text AS nanodrop_a260_280_note, NULL::text AS nanodrop_a260_230_note,
    NULL::text AS qubit_id, NULL::numeric AS qubit_original_sample_conc, NULL::text AS qubit_original_sample_unit, NULL::numeric AS qubit_total_dna_ug, NULL::date AS qubit_measurement_date, NULL::text AS qubit_assay_kit, NULL::numeric AS qubit_tube_conc, NULL::text AS tube_unit_id, NULL::numeric AS sample_volume_ul, NULL::numeric AS elution_volume_ul,
    NULL::text AS tapestation_id, NULL::date AS tapestation_measurement_date, NULL::text AS tapestation_kit,
    NULL::text AS pcr_id, NULL::date AS pcr_date, NULL::text AS pcr_primer_id, NULL::text AS pcr_target_gene_id, NULL::numeric AS pcr_volume_reaction_ul, NULL::text AS pcr_blank_id, NULL::text AS pcr_position,
    NULL::text AS gel_gelelectrophoresis_id, NULL::date AS gel_run_date, NULL::integer AS gel_band_size_bp, NULL::text AS gel_gel_type, NULL::text AS gel_position, NULL::text AS gel_ladder, NULL::numeric AS gel_voltage, NULL::numeric AS gel_run_time_minutes,
    NULL::text AS qpcr_id, NULL::date AS qpcr_date, NULL::numeric AS qpcr_ct_value, NULL::text AS qpcr_inhibitor_test_result, NULL::text AS qpcr_position, NULL::text AS qpcr_primer_id_actual, NULL::text AS qpcr_pcr_blank_id, NULL::text AS qpcr_kit, NULL::numeric AS qpcr_volume_ul,
    NULL::text AS library_id, NULL::date AS library_prep_date, NULL::text AS library_name, NULL::text AS library_prep_kit, NULL::text AS library_index_sequence, NULL::integer AS library_read_length_bp,
    NULL::text AS sequencing_id, NULL::date AS sequencing_date, NULL::text AS sequencer, NULL::text AS flow_cell_id, NULL::bigint AS total_reads, NULL::text AS raw_data_path, NULL::text AS genbank_accession_number, NULL::text AS sequencing_library_prep_kit, NULL::text AS sequencing_index_sequence, NULL::integer AS sequencing_read_length_bp,
    NULL::text AS analysis_run_id, NULL::text AS pipeline_name, NULL::text AS pipeline_version, NULL::text AS bioinfo_reference_database, NULL::text AS bioinfo_database_version, NULL::numeric AS clustering_threshold, NULL::text AS final_output_path,
    NULL::text AS edna_assignment_id, NULL::text AS edna_assigned_taxon_id, NULL::text AS edna_assigned_taxon_name, NULL::integer AS edna_read_count, NULL::numeric AS edna_confidence,
    e.experiment_id AS associated_experiment_id, e.experiment_title AS associated_experiment_title, e.experiment_date AS associated_experiment_date, e.aim AS associated_experiment_aim, e.method AS associated_experiment_method, exp_person.full_name AS experiment_person_name,
    NULL::text AS sampler_full_name, NULL::text AS receiver_full_name

FROM
    "lab"."water" w
LEFT JOIN "lims"."projects" p ON w.project_id = p.project_id
LEFT JOIN "lab"."experiments" e ON w.experiment_id = e.experiment_id AND w.experiment_date = e.experiment_date
LEFT JOIN "reference"."personal" exp_person ON e.person_id = exp_person.person_id

UNION ALL

SELECT
    oto.otolith_id AS sample_id,
    NULL AS external_name,
    oto.sample_id AS parent_sample_id,
    'Otolith Sample' AS sample_origin_type,
    'Otolith' AS sample_type_id,
    'O' AS sample_type_abrv,
    (SELECT status_id FROM "reference"."status" WHERE notes = 'Received') AS sample_status_id,
    (SELECT notes FROM "reference"."status" WHERE status_id = 'Received') AS sample_status_notes,
    NULL::text AS sampling_id,
    oto.experiment_date AS sampling_date,
    NULL AS reception_date,
    oto.project_id,
    p.title AS project_title,
    NULL::integer AS customer_id,
    NULL::text AS customer_name,
    NULL::text AS storage_id,
    NULL::text AS storage_position,
    oto.notes,
    oto.attachment,
    oto.attachment_link,

    -- Sampling Event Details (NULL placeholders)
    NULL::numeric AS sampling_lon, NULL::numeric AS sampling_lat, NULL::numeric AS fishing_start_lon, NULL::numeric AS fishing_start_lat, NULL::numeric AS fishing_end_lon, NULL::numeric AS fishing_end_lat,
    NULL::text AS sampling_location, NULL::numeric AS sampling_depth_m, NULL::numeric AS temperature_atmospheric_c, NULL::text AS weather, NULL::numeric AS wind_speed, NULL::text AS wind_unit,
    NULL::numeric AS salinity, NULL::text AS salinity_unit, NULL::numeric AS oxygen, NULL::text AS oxygen_unit,

    -- Fish-specific Details (NULL)
    NULL::text AS fish_species_id, NULL::text AS fish_species_en_name, NULL::numeric AS fish_total_length_mm, NULL::numeric AS fish_fork_length_mm, NULL::numeric AS fish_standard_length_mm, NULL::numeric AS fish_weight_g, NULL::text AS fish_sex, NULL::text AS fish_maturity_stage, NULL::text AS fish_stomach_contents, NULL::text AS fish_disease_info, NULL::text AS fish_tag_id,

    -- Tissue-specific Details (NULL)
    NULL::numeric AS tissue_weight_mg, NULL::text AS tissue_type, NULL::text AS tissue_preservation_method,

    -- DNA-specific Details (NULL)
    NULL::numeric AS dna_volume_ul, NULL::numeric AS dna_concentration_ng_ul, NULL::numeric AS dna_a260_280, NULL::numeric AS dna_a260_230, NULL::text AS dna_extraction_method, NULL::date AS dna_extraction_date_dna, NULL::integer AS dna_extraction_number,

    -- RNA-specific Details (NULL)
    NULL::numeric AS rna_volume_ul, NULL::numeric AS rna_concentration_ng_ul, NULL::numeric AS rna_a260_280, NULL::numeric AS rna_a260_230, NULL::text AS rna_extraction_method, NULL::date AS rna_extraction_date_rna, NULL::integer AS rna_extraction_number,

    -- Sediments-specific Details (NULL)
    NULL::numeric AS sediment_volume, NULL::text AS sediment_volume_unit, NULL::numeric AS sediment_depth_m, NULL::text AS sediment_sampling_method, NULL::text AS sediment_conservation_buffer,

    -- Water-specific Details (NULL)
    NULL::numeric AS water_volume_l, NULL::text AS water_filter, NULL::numeric AS water_filter_pore_size_um, NULL::numeric AS water_depth_m, NULL::text AS water_sampling_method, NULL::text AS water_conservation_buffer,

    -- Otoliths-specific Details
    oto.otolith_id,
    oto.reader_person_id,
    oto.side,
    oto.age_reading_years,
    oto.confidence,

    -- All other specific details are NULL
    NULL::text AS dissection_id, NULL::text AS dissection_person_id, NULL::date AS dissection_date, NULL::jsonb AS dissection_stomach_contents_jsonb, NULL::numeric AS dissection_gonad_weight_g, NULL::numeric AS dissection_liver_weight_g,
    NULL::text AS extraction_id, NULL::date AS extraction_process_date, NULL::text AS extraction_process_person_id, NULL::text AS extraction_process_kit, NULL::numeric AS extraction_process_elution_volume_ul, NULL::numeric AS extraction_process_yield_qubit_ng_ul, NULL::numeric AS extraction_process_yield_nanodrop_ng_ul, NULL::numeric AS extraction_process_a260_280, NULL::numeric AS extraction_process_a260_230, NULL::text AS extraction_result_dna_sample_id, NULL::text AS extraction_result_rna_sample_id,
    NULL::text AS extraction_blank_id,
    NULL::text AS nanodrop_id, NULL::numeric AS nanodrop_concentration, NULL::text AS nanodrop_concentration_unit, NULL::numeric AS nanodrop_a260, NULL::numeric AS nanodrop_a260_280_qc, NULL::numeric AS nanodrop_a260_230_qc, NULL::numeric AS nanodrop_total_dna_ug, NULL::date AS nanodrop_measurement_date, NULL::text AS nanodrop_a260_280_note, NULL::text AS nanodrop_a260_230_note,
    NULL::text AS qubit_id, NULL::numeric AS qubit_original_sample_conc, NULL::text AS qubit_original_sample_unit, NULL::numeric AS qubit_total_dna_ug, NULL::date AS qubit_measurement_date, NULL::text AS qubit_assay_kit, NULL::numeric AS qubit_tube_conc, NULL::text AS tube_unit_id, NULL::numeric AS sample_volume_ul, NULL::numeric AS elution_volume_ul,
    NULL::text AS tapestation_id, NULL::date AS tapestation_measurement_date, NULL::text AS tapestation_kit,
    NULL::text AS pcr_id, NULL::date AS pcr_date, NULL::text AS pcr_primer_id, NULL::text AS pcr_target_gene_id, NULL::numeric AS pcr_volume_reaction_ul, NULL::text AS pcr_blank_id, NULL::text AS pcr_position,
    NULL::text AS gel_gelelectrophoresis_id, NULL::date AS gel_run_date, NULL::integer AS gel_band_size_bp, NULL::text AS gel_gel_type, NULL::text AS gel_position, NULL::text AS gel_ladder, NULL::numeric AS gel_voltage, NULL::numeric AS gel_run_time_minutes,
    NULL::text AS qpcr_id, NULL::date AS qpcr_date, NULL::numeric AS qpcr_ct_value, NULL::text AS qpcr_inhibitor_test_result, NULL::text AS qpcr_position, NULL::text AS qpcr_primer_id_actual, NULL::text AS qpcr_pcr_blank_id, NULL::text AS qpcr_kit, NULL::numeric AS qpcr_volume_ul,
    NULL::text AS library_id, NULL::date AS library_prep_date, NULL::text AS library_name, NULL::text AS library_prep_kit, NULL::text AS library_index_sequence, NULL::integer AS library_read_length_bp,
    NULL::text AS sequencing_id, NULL::date AS sequencing_date, NULL::text AS sequencer, NULL::text AS flow_cell_id, NULL::bigint AS total_reads, NULL::text AS raw_data_path, NULL::text AS genbank_accession_number, NULL::text AS sequencing_library_prep_kit, NULL::text AS sequencing_index_sequence, NULL::integer AS sequencing_read_length_bp,
    NULL::text AS analysis_run_id, NULL::text AS pipeline_name, NULL::text AS pipeline_version, NULL::text AS bioinfo_reference_database, NULL::text AS bioinfo_database_version, NULL::numeric AS clustering_threshold, NULL::text AS final_output_path,
    NULL::text AS edna_assignment_id, NULL::text AS edna_assigned_taxon_id, NULL::text AS edna_assigned_taxon_name, NULL::integer AS edna_read_count, NULL::numeric AS edna_confidence,
    e.experiment_id AS associated_experiment_id, e.experiment_title AS associated_experiment_title, e.experiment_date AS associated_experiment_date, e.aim AS associated_experiment_aim, e.method AS associated_experiment_method, exp_person.full_name AS experiment_person_name,
    NULL::text AS sampler_full_name, NULL::text AS receiver_full_name
FROM
    "lab"."otoliths" oto
LEFT JOIN "lims"."projects" p ON oto.project_id = p.project_id
LEFT JOIN "lab"."experiments" e ON oto.experiment_id = e.experiment_id AND oto.experiment_date = e.experiment_date
LEFT JOIN "reference"."personal" exp_person ON e.person_id = exp_person.person_id

UNION ALL

SELECT
    ext.extraction_id AS sample_id,
    NULL AS external_name,
    ext.sample_id AS parent_sample_id,
    'Extraction Product' AS sample_origin_type,
    'Extraction' AS sample_type_id,
    'EXT' AS sample_type_abrv,
    ext.status_id AS sample_status_id,
    stat.notes AS sample_status_notes,
    NULL::text AS sampling_id,
    ext.extraction_date AS sampling_date,
    NULL::date AS reception_date, 
    ext.project_id,
    p.title AS project_title,
    NULL::integer AS customer_id,
    NULL::text AS customer_name,
    ext.storage_id,
    ext.storage_position,
    ext.notes,
    ext.attachment,
    ext.attachment_link,

    -- Sampling Event Details (NULL)
    NULL::numeric AS sampling_lon, NULL::numeric AS sampling_lat, NULL::numeric AS fishing_start_lon, NULL::numeric AS fishing_start_lat, NULL::numeric AS fishing_end_lon, NULL::numeric AS fishing_end_lat,
    NULL::text AS sampling_location, NULL::numeric AS sampling_depth_m, NULL::numeric AS temperature_atmospheric_c, NULL::text AS weather, NULL::numeric AS wind_speed, NULL::text AS wind_unit,
    NULL::numeric AS salinity, NULL::text AS salinity_unit, NULL::numeric AS oxygen, NULL::text AS oxygen_unit,

    -- Fish-specific Details (NULL)
    NULL::text AS fish_species_id, NULL::text AS fish_species_en_name, NULL::numeric AS fish_total_length_mm, NULL::numeric AS fish_fork_length_mm, NULL::numeric AS fish_standard_length_mm, NULL::numeric AS fish_weight_g, NULL::text AS fish_sex, NULL::text AS fish_maturity_stage, NULL::text AS fish_stomach_contents, NULL::text AS fish_disease_info, NULL::text AS fish_tag_id,

    -- Tissue-specific Details (NULL)
    NULL::numeric AS tissue_weight_mg, NULL::text AS tissue_type, NULL::text AS tissue_preservation_method,

    -- DNA-specific Details (NULL for extraction output, since these are in lab.dna/rna tables already)
    NULL::numeric AS dna_volume_ul, NULL::numeric AS dna_concentration_ng_ul, NULL::numeric AS dna_a260_280, NULL::numeric AS dna_a260_230, NULL::text AS dna_extraction_method, NULL::date AS dna_extraction_date_dna, NULL::integer AS dna_extraction_number,

    -- RNA-specific Details (NULL for extraction output, since these are in lab.dna/rna tables already)
    NULL::numeric AS rna_volume_ul, NULL::numeric AS rna_concentration_ng_ul, NULL::numeric AS rna_a260_280, NULL::numeric AS rna_a260_230, NULL::text AS rna_extraction_method, NULL::date AS rna_extraction_date_rna, NULL::integer AS rna_extraction_number,

    -- Sediments-specific Details (NULL)
    NULL::numeric AS sediment_volume, NULL::text AS sediment_volume_unit, NULL::numeric AS sediment_depth_m, NULL::text AS sediment_sampling_method, NULL::text AS sediment_conservation_buffer,

    -- Water-specific Details (NULL)
    NULL::numeric AS water_volume_l, NULL::text AS water_filter, NULL::numeric AS water_filter_pore_size_um, NULL::numeric AS water_depth_m, NULL::text AS water_sampling_method, NULL::text AS water_conservation_buffer,

    -- Otoliths-specific Details (NULL)
    NULL::text AS otolith_id, NULL::text AS otolith_reader_person_id, NULL::text AS otolith_side, NULL::numeric AS otolith_age_reading_years, NULL::numeric AS otolith_confidence,

    -- Dissections Details (NULL)
    NULL::text AS dissection_id, NULL::text AS dissection_person_id, NULL::date AS dissection_date, NULL::jsonb AS dissection_stomach_contents_jsonb, NULL::numeric AS dissection_gonad_weight_g, NULL::numeric AS dissection_liver_weight_g,

    -- Extraction Details (from lab.extraction, these are the *process* details for this row)
    ext.extraction_id,
    ext.extraction_date AS extraction_process_date,
    ext.person_id AS extraction_process_person_id,
    ext.kit AS extraction_process_kit,
    ext.elution_volume_ul AS extraction_process_elution_volume_ul,
    ext.yield_qubit_ng_ul AS extraction_process_yield_qubit_ng_ul,
    ext.yield_nanodrop_ng_ul AS extraction_process_yield_nanodrop_ng_ul,
    ext.a260_280 AS extraction_process_a260_280,
    ext.a260_230 AS extraction_process_a260_230,
    ext.extracted_dna_sample_id AS extraction_result_dna_sample_id,
    ext.extracted_rna_sample_id AS extraction_result_rna_sample_id,
    ext.extraction_blank_id,

    -- All other specific details are NULL
    NULL::text AS nanodrop_id, NULL::numeric AS nanodrop_concentration, NULL::text AS nanodrop_concentration_unit, NULL::numeric AS nanodrop_a260, NULL::numeric AS nanodrop_a260_280_qc, NULL::numeric AS nanodrop_a260_230_qc, NULL::numeric AS nanodrop_total_dna_ug, NULL::date AS nanodrop_measurement_date, NULL::text AS nanodrop_a260_280_note, NULL::text AS nanodrop_a260_230_note,
    NULL::text AS qubit_id, NULL::numeric AS qubit_original_sample_conc, NULL::text AS qubit_original_sample_unit, NULL::numeric AS qubit_total_dna_ug, NULL::date AS qubit_measurement_date, NULL::text AS qubit_assay_kit, NULL::numeric AS qubit_tube_conc, NULL::text AS tube_unit_id, NULL::numeric AS sample_volume_ul, NULL::numeric AS elution_volume_ul,
    NULL::text AS tapestation_id, NULL::date AS tapestation_measurement_date, NULL::text AS tapestation_kit,
    NULL::text AS pcr_id, NULL::date AS pcr_date, NULL::text AS pcr_primer_id, NULL::text AS pcr_target_gene_id, NULL::numeric AS pcr_volume_reaction_ul, NULL::text AS pcr_blank_id, NULL::text AS pcr_position,
    NULL::text AS gel_gelelectrophoresis_id, NULL::date AS gel_run_date, NULL::integer AS gel_band_size_bp, NULL::text AS gel_gel_type, NULL::text AS gel_position, NULL::text AS gel_ladder, NULL::numeric AS gel_voltage, NULL::numeric AS gel_run_time_minutes,
    NULL::text AS qpcr_id, NULL::date AS qpcr_date, NULL::numeric AS qpcr_ct_value, NULL::text AS qpcr_inhibitor_test_result, NULL::text AS qpcr_position, NULL::text AS qpcr_primer_id_actual, NULL::text AS qpcr_pcr_blank_id, NULL::text AS qpcr_kit, NULL::numeric AS qpcr_volume_ul,
    NULL::text AS library_id, NULL::date AS library_prep_date, NULL::text AS library_name, NULL::text AS library_prep_kit, NULL::text AS library_index_sequence, NULL::integer AS library_read_length_bp,
    NULL::text AS sequencing_id, NULL::date AS sequencing_date, NULL::text AS sequencer, NULL::text AS flow_cell_id, NULL::bigint AS total_reads, NULL::text AS raw_data_path, NULL::text AS genbank_accession_number, NULL::text AS sequencing_library_prep_kit, NULL::text AS sequencing_index_sequence, NULL::integer AS sequencing_read_length_bp,
    NULL::text AS analysis_run_id, NULL::text AS pipeline_name, NULL::text AS pipeline_version, NULL::text AS bioinfo_reference_database, NULL::text AS bioinfo_database_version, NULL::numeric AS clustering_threshold, NULL::text AS final_output_path,
    NULL::text AS edna_assignment_id, NULL::text AS edna_assigned_taxon_id, NULL::text AS edna_assigned_taxon_name, NULL::integer AS edna_read_count, NULL::numeric AS edna_confidence,
    e.experiment_id AS associated_experiment_id, e.experiment_title AS associated_experiment_title, e.experiment_date AS associated_experiment_date, e.aim AS associated_experiment_aim, e.method AS associated_experiment_method, exp_person.full_name AS experiment_person_name,
    NULL::text AS sampler_full_name, NULL::text AS receiver_full_name

FROM
    "lab"."extraction" ext
LEFT JOIN "lims"."projects" p ON ext.project_id = p.project_id
LEFT JOIN "reference"."status" stat ON ext.status_id = stat.status_id
LEFT JOIN "lab"."experiments" e ON ext.experiment_id = e.experiment_id AND ext.experiment_date = e.experiment_date
LEFT JOIN "reference"."personal" exp_person ON e.person_id = exp_person.person_id

UNION ALL

SELECT
    nd.nanodrop_id AS sample_id,
    NULL AS external_name,
    nd.sample_id AS parent_sample_id,
    'Nanodrop QC Record' AS sample_origin_type,
    'NDQC' AS sample_type_id,
    'NDQC' AS sample_type_abrv,
    nd.status_id AS sample_status_id,
    stat.notes AS sample_status_notes,
    NULL::text AS sampling_id,
    nd.measurement_date AS sampling_date,
    NULL AS reception_date,
    nd.project_id,
    p.title AS project_title,
    NULL::integer AS customer_id,
    NULL::text AS customer_name,
    nd.storage_id,
    nd.storage_position,
    nd.notes,
    nd.attachment,
    nd.attachment_link,

    -- All other specific details are NULL
    NULL::numeric AS sampling_lon, NULL::numeric AS sampling_lat, NULL::numeric AS fishing_start_lon, NULL::numeric AS fishing_start_lat, NULL::numeric AS fishing_end_lon, NULL::numeric AS fishing_end_lat,
    NULL::text AS sampling_location, NULL::numeric AS sampling_depth_m, NULL::numeric AS temperature_atmospheric_c, NULL::text AS weather, NULL::numeric AS wind_speed, NULL::text AS wind_unit,
    NULL::numeric AS salinity, NULL::text AS salinity_unit, NULL::numeric AS oxygen, NULL::text AS oxygen_unit,
    NULL::text AS fish_species_id, NULL::text AS fish_species_en_name, NULL::numeric AS fish_total_length_mm, NULL::numeric AS fish_fork_length_mm, NULL::numeric AS fish_standard_length_mm, NULL::numeric AS fish_weight_g, NULL::text AS fish_sex, NULL::text AS fish_maturity_stage, NULL::text AS fish_stomach_contents, NULL::text AS fish_disease_info, NULL::text AS fish_tag_id,
    NULL::numeric AS tissue_weight_mg, NULL::text AS tissue_type, NULL::text AS tissue_preservation_method,
    NULL::numeric AS dna_volume_ul, NULL::numeric AS dna_concentration_ng_ul, NULL::numeric AS dna_a260_280, NULL::numeric AS dna_a260_230, NULL::text AS dna_extraction_method, NULL::date AS dna_extraction_date_dna, NULL::integer AS dna_extraction_number,
    NULL::numeric AS rna_volume_ul, NULL::numeric AS rna_concentration_ng_ul, NULL::numeric AS rna_a260_280, NULL::numeric AS rna_a260_230, NULL::text AS rna_extraction_method, NULL::date AS rna_extraction_date_rna, NULL::integer AS rna_extraction_number,
    NULL::numeric AS sediment_volume, NULL::text AS sediment_volume_unit, NULL::numeric AS sediment_depth_m, NULL::text AS sediment_sampling_method, NULL::text AS sediment_conservation_buffer,
    NULL::numeric AS water_volume_l, NULL::text AS water_filter, NULL::numeric AS water_filter_pore_size_um, NULL::numeric AS water_depth_m, NULL::text AS water_sampling_method, NULL::text AS water_conservation_buffer,
    NULL::text AS otolith_id, NULL::text AS otolith_reader_person_id, NULL::text AS otolith_side, NULL::numeric AS otolith_age_reading_years, NULL::numeric AS otolith_confidence,
    NULL::text AS dissection_id, NULL::text AS dissection_person_id, NULL::date AS dissection_date, NULL::jsonb AS dissection_stomach_contents_jsonb, NULL::numeric AS dissection_gonad_weight_g, NULL::numeric AS dissection_liver_weight_g,
    NULL::text AS extraction_id, NULL::date AS extraction_process_date, NULL::text AS extraction_process_person_id, NULL::text AS extraction_process_kit, NULL::numeric AS extraction_process_elution_volume_ul, NULL::numeric AS extraction_process_yield_qubit_ng_ul, NULL::numeric AS extraction_process_yield_nanodrop_ng_ul, NULL::numeric AS extraction_process_a260_280, NULL::numeric AS extraction_process_a260_230, NULL::text AS extraction_result_dna_sample_id, NULL::text AS extraction_result_rna_sample_id,
    NULL::text AS extraction_blank_id,
    nd.nanodrop_id,
    nd.nanodrop_concentration,
    ndcu.unit_abbreviation AS nanodrop_concentration_unit,
    nd.a260,
    nd.a260_280 AS nanodrop_a260_280_qc,
    nd.a260_230 AS nanodrop_a260_230_qc,
    nd.nanodrop_total_dna_ug,
    nd.measurement_date,
    nd.a260_280_note,
    nd.a260_230_note,
    NULL::text AS qubit_id, NULL::numeric AS qubit_original_sample_conc, NULL::text AS qubit_original_sample_unit, NULL::numeric AS qubit_total_dna_ug, NULL::date AS qubit_measurement_date, NULL::text AS qubit_assay_kit, NULL::numeric AS qubit_tube_conc, NULL::text AS tube_unit_id, NULL::numeric AS sample_volume_ul, NULL::numeric AS elution_volume_ul,
    NULL::text AS tapestation_id, NULL::date AS tapestation_measurement_date, NULL::text AS tapestation_kit,
    NULL::text AS pcr_id, NULL::date AS pcr_date, NULL::text AS pcr_primer_id, NULL::text AS pcr_target_gene_id, NULL::numeric AS pcr_volume_reaction_ul, NULL::text AS pcr_blank_id, NULL::text AS pcr_position,
    NULL::text AS gel_gelelectrophoresis_id, NULL::date AS gel_run_date, NULL::integer AS gel_band_size_bp, NULL::text AS gel_gel_type, NULL::text AS gel_position, NULL::text AS gel_ladder, NULL::numeric AS gel_voltage, NULL::numeric AS gel_run_time_minutes,
    NULL::text AS qpcr_id, NULL::date AS qpcr_date, NULL::numeric AS qpcr_ct_value, NULL::text AS qpcr_inhibitor_test_result, NULL::text AS qpcr_position, NULL::text AS qpcr_primer_id_actual, NULL::text AS qpcr_pcr_blank_id, NULL::text AS qpcr_kit, NULL::numeric AS qpcr_volume_ul,
    NULL::text AS library_id, NULL::date AS library_prep_date, NULL::text AS library_name, NULL::text AS library_prep_kit, NULL::text AS library_index_sequence, NULL::integer AS library_read_length_bp,
    NULL::text AS sequencing_id, NULL::date AS sequencing_date, NULL::text AS sequencer, NULL::text AS flow_cell_id, NULL::bigint AS total_reads, NULL::text AS raw_data_path, NULL::text AS genbank_accession_number, NULL::text AS sequencing_library_prep_kit, NULL::text AS sequencing_index_sequence, NULL::integer AS sequencing_read_length_bp,
    NULL::text AS analysis_run_id, NULL::text AS pipeline_name, NULL::text AS pipeline_version, NULL::text AS bioinfo_reference_database, NULL::text AS bioinfo_database_version, NULL::numeric AS clustering_threshold, NULL::text AS final_output_path,
    NULL::text AS edna_assignment_id, NULL::text AS edna_assigned_taxon_id, NULL::text AS edna_assigned_taxon_name, NULL::integer AS edna_read_count, NULL::numeric AS edna_confidence,
    e.experiment_id AS associated_experiment_id, e.experiment_title AS associated_experiment_title, e.experiment_date AS associated_experiment_date, e.aim AS associated_experiment_aim, e.method AS associated_experiment_method, exp_person.full_name AS experiment_person_name,
    NULL::text AS sampler_full_name, NULL::text AS receiver_full_name

FROM
    "lab"."nanodrop" nd
LEFT JOIN "lims"."projects" p ON nd.project_id = p.project_id
LEFT JOIN "reference"."status" stat ON nd.status_id = stat.status_id
LEFT JOIN "reference"."units" ndcu ON nd.concentration_unit_id = ndcu.unit_id
LEFT JOIN "lab"."experiments" e ON nd.experiment_id = e.experiment_id AND nd.experiment_date = e.experiment_date
LEFT JOIN "reference"."personal" exp_person ON e.person_id = exp_person.person_id

UNION ALL

SELECT
    qu.qubit_id AS sample_id,
    NULL AS external_name,
    qu.sample_id AS parent_sample_id,
    'Qubit QC Record' AS sample_origin_type,
    'QubitQC' AS sample_type_id,
    'QBC' AS sample_type_abrv,
    qu.status_id AS sample_status_id,
    stat.notes AS sample_status_notes,
    NULL::text AS sampling_id,
    qu.measurement_date AS sampling_date,
    NULL AS reception_date,
    qu.project_id,
    p.title AS project_title,
    NULL::integer AS customer_id,
    NULL::text AS customer_name,
    qu.storage_id,
    qu.storage_position,
    qu.notes,
    qu.attachment,
    qu.attachment_link,

    -- All other specific details are NULL
    NULL::numeric AS sampling_lon, NULL::numeric AS sampling_lat, NULL::numeric AS fishing_start_lon, NULL::numeric AS fishing_start_lat, NULL::numeric AS fishing_end_lon, NULL::numeric AS fishing_end_lat,
    NULL::text AS sampling_location, NULL::numeric AS sampling_depth_m, NULL::numeric AS temperature_atmospheric_c, NULL::text AS weather, NULL::numeric AS wind_speed, NULL::text AS wind_unit,
    NULL::numeric AS salinity, NULL::text AS salinity_unit, NULL::numeric AS oxygen, NULL::text AS oxygen_unit,
    NULL::text AS fish_species_id, NULL::text AS fish_species_en_name, NULL::numeric AS fish_total_length_mm, NULL::numeric AS fish_fork_length_mm, NULL::numeric AS fish_standard_length_mm, NULL::numeric AS fish_weight_g, NULL::text AS fish_sex, NULL::text AS fish_maturity_stage, NULL::text AS fish_stomach_contents, NULL::text AS fish_disease_info, NULL::text AS fish_tag_id,
    NULL::numeric AS tissue_weight_mg, NULL::text AS tissue_type, NULL::text AS tissue_preservation_method,
    NULL::numeric AS dna_volume_ul, NULL::numeric AS dna_concentration_ng_ul, NULL::numeric AS dna_a260_280, NULL::numeric AS dna_a260_230, NULL::text AS dna_extraction_method, NULL::date AS dna_extraction_date_dna, NULL::integer AS dna_extraction_number,
    NULL::numeric AS rna_volume_ul, NULL::numeric AS rna_concentration_ng_ul, NULL::numeric AS rna_a260_280, NULL::numeric AS rna_a260_230, NULL::text AS rna_extraction_method, NULL::date AS rna_extraction_date_rna, NULL::integer AS rna_extraction_number,
    NULL::numeric AS sediment_volume, NULL::text AS sediment_volume_unit, NULL::numeric AS sediment_depth_m, NULL::text AS sediment_sampling_method, NULL::text AS sediment_conservation_buffer,
    NULL::numeric AS water_volume_l, NULL::text AS water_filter, NULL::numeric AS water_filter_pore_size_um, NULL::numeric AS water_depth_m, NULL::text AS water_sampling_method, NULL::text AS water_conservation_buffer,
    NULL::text AS otolith_id, NULL::text AS otolith_reader_person_id, NULL::text AS otolith_side, NULL::numeric AS otolith_age_reading_years, NULL::numeric AS otolith_confidence,
    NULL::text AS dissection_id, NULL::text AS dissection_person_id, NULL::date AS dissection_date, NULL::jsonb AS dissection_stomach_contents_jsonb, NULL::numeric AS dissection_gonad_weight_g, NULL::numeric AS dissection_liver_weight_g,
    NULL::text AS extraction_id, NULL::date AS extraction_process_date, NULL::text AS extraction_process_person_id, NULL::text AS extraction_process_kit, NULL::numeric AS extraction_process_elution_volume_ul, NULL::numeric AS extraction_process_yield_qubit_ng_ul, NULL::numeric AS extraction_process_yield_nanodrop_ng_ul, NULL::numeric AS extraction_process_a260_280, NULL::numeric AS extraction_process_a260_230, NULL::text AS extraction_result_dna_sample_id, NULL::text AS extraction_result_rna_sample_id,
    NULL::text AS extraction_blank_id,
    NULL::text AS nanodrop_id, NULL::numeric AS nanodrop_concentration, NULL::text AS nanodrop_concentration_unit, NULL::numeric AS nanodrop_a260, NULL::numeric AS nanodrop_a260_280_qc, NULL::numeric AS nanodrop_a260_230_qc, NULL::numeric AS nanodrop_total_dna_ug, NULL::date AS nanodrop_measurement_date, NULL::text AS nanodrop_a260_280_note, NULL::text AS nanodrop_a260_230_note,
    qu.qubit_id,
    qu.qubit_original_sample_conc,
    quosu.unit_abbreviation AS qubit_original_sample_unit,
    qu.qubit_total_dna_ug,
    qu.measurement_date,
    qu.assay_kit,
    qu.qubit_tube_conc,
    qu.tube_unit_id,
    qu.sample_volume_ul,
    qu.elution_volume_ul,
    NULL::text AS tapestation_id, NULL::date AS tapestation_measurement_date, NULL::text AS tapestation_kit,
    NULL::text AS pcr_id, NULL::date AS pcr_date, NULL::text AS pcr_primer_id, NULL::text AS pcr_target_gene_id, NULL::numeric AS pcr_volume_reaction_ul, NULL::text AS pcr_blank_id, NULL::text AS pcr_position,
    NULL::text AS gel_gelelectrophoresis_id, NULL::date AS gel_run_date, NULL::integer AS gel_band_size_bp, NULL::text AS gel_gel_type, NULL::text AS gel_position, NULL::text AS gel_ladder, NULL::numeric AS gel_voltage, NULL::numeric AS gel_run_time_minutes,
    NULL::text AS qpcr_id, NULL::date AS qpcr_date, NULL::numeric AS qpcr_ct_value, NULL::text AS qpcr_inhibitor_test_result, NULL::text AS qpcr_position, NULL::text AS qpcr_primer_id_actual, NULL::text AS qpcr_pcr_blank_id, NULL::text AS qpcr_kit, NULL::numeric AS qpcr_volume_ul,
    NULL::text AS library_id, NULL::date AS library_prep_date, NULL::text AS library_name, NULL::text AS library_prep_kit, NULL::text AS library_index_sequence, NULL::integer AS library_read_length_bp,
    NULL::text AS sequencing_id, NULL::date AS sequencing_date, NULL::text AS sequencer, NULL::text AS flow_cell_id, NULL::bigint AS total_reads, NULL::text AS raw_data_path, NULL::text AS genbank_accession_number, NULL::text AS sequencing_library_prep_kit, NULL::text AS sequencing_index_sequence, NULL::integer AS sequencing_read_length_bp,
    NULL::text AS analysis_run_id, NULL::text AS pipeline_name, NULL::text AS pipeline_version, NULL::text AS bioinfo_reference_database, NULL::text AS bioinfo_database_version, NULL::numeric AS clustering_threshold, NULL::text AS final_output_path,
    NULL::text AS edna_assignment_id, NULL::text AS edna_assigned_taxon_id, NULL::text AS edna_assigned_taxon_name, NULL::integer AS edna_read_count, NULL::numeric AS edna_confidence,
    e.experiment_id AS associated_experiment_id, e.experiment_title AS associated_experiment_title, e.experiment_date AS associated_experiment_date, e.aim AS associated_experiment_aim, e.method AS associated_experiment_method, exp_person.full_name AS experiment_person_name,
    NULL::text AS sampler_full_name, NULL::text AS receiver_full_name
FROM
    "lab"."qubit" qu
LEFT JOIN "lims"."projects" p ON qu.project_id = p.project_id
LEFT JOIN "reference"."status" stat ON qu.status_id = stat.status_id
LEFT JOIN "reference"."units" quosu ON qu.original_sample_unit_id = quosu.unit_id
LEFT JOIN "lab"."experiments" e ON qu.experiment_id = e.experiment_id AND qu.experiment_date = e.experiment_date
LEFT JOIN "reference"."personal" exp_person ON e.person_id = exp_person.person_id

UNION ALL

SELECT
    ts.tapestation_id AS sample_id,
    NULL AS external_name,
    ts.sample_id AS parent_sample_id,
    'Tapestation QC Record' AS sample_origin_type,
    'TSQC' AS sample_type_id,
    'TSQC' AS sample_type_abrv,
    ts.status_id AS sample_status_id,
    stat.notes AS sample_status_notes,
    NULL::text AS sampling_id,
    ts.measurement_date AS sampling_date,
    NULL AS reception_date,
    ts.project_id,
    p.title AS project_title,
    NULL::integer AS customer_id,
    NULL::text AS customer_name,
    ts.storage_id,
    ts.storage_position,
    ts.notes,
    ts.attachment,
    ts.attachment_link,

    -- All other specific details are NULL
    NULL::numeric AS sampling_lon, NULL::numeric AS sampling_lat, NULL::numeric AS fishing_start_lon, NULL::numeric AS fishing_start_lat, NULL::numeric AS fishing_end_lon, NULL::numeric AS fishing_end_lat,
    NULL::text AS sampling_location, NULL::numeric AS sampling_depth_m, NULL::numeric AS temperature_atmospheric_c, NULL::text AS weather, NULL::numeric AS wind_speed, NULL::text AS wind_unit,
    NULL::numeric AS salinity, NULL::text AS salinity_unit, NULL::numeric AS oxygen, NULL::text AS oxygen_unit,
    NULL::text AS fish_species_id, NULL::text AS fish_species_en_name, NULL::numeric AS fish_total_length_mm, NULL::numeric AS fish_fork_length_mm, NULL::numeric AS fish_standard_length_mm, NULL::numeric AS fish_weight_g, NULL::text AS fish_sex, NULL::text AS fish_maturity_stage, NULL::text AS fish_stomach_contents, NULL::text AS fish_disease_info, NULL::text AS fish_tag_id,
    NULL::numeric AS tissue_weight_mg, NULL::text AS tissue_type, NULL::text AS tissue_preservation_method,
    NULL::numeric AS dna_volume_ul, NULL::numeric AS dna_concentration_ng_ul, NULL::numeric AS dna_a260_280, NULL::numeric AS dna_a260_230, NULL::text AS dna_extraction_method, NULL::date AS dna_extraction_date_dna, NULL::integer AS dna_extraction_number,
    NULL::numeric AS rna_volume_ul, NULL::numeric AS rna_concentration_ng_ul, NULL::numeric AS rna_a260_280, NULL::numeric AS rna_a260_230, NULL::text AS rna_extraction_method, NULL::date AS rna_extraction_date_rna, NULL::integer AS rna_extraction_number,
    NULL::numeric AS sediment_volume, NULL::text AS sediment_volume_unit, NULL::numeric AS sediment_depth_m, NULL::text AS sediment_sampling_method, NULL::text AS sediment_conservation_buffer,
    NULL::numeric AS water_volume_l, NULL::text AS water_filter, NULL::numeric AS water_filter_pore_size_um, NULL::numeric AS water_depth_m, NULL::text AS water_sampling_method, NULL::text AS water_conservation_buffer,
    NULL::text AS otolith_id, NULL::text AS otolith_reader_person_id, NULL::text AS otolith_side, NULL::numeric AS otolith_age_reading_years, NULL::numeric AS otolith_confidence,
    NULL::text AS dissection_id, NULL::text AS dissection_person_id, NULL::date AS dissection_date, NULL::jsonb AS dissection_stomach_contents_jsonb, NULL::numeric AS dissection_gonad_weight_g, NULL::numeric AS dissection_liver_weight_g,
    NULL::text AS extraction_id, NULL::date AS extraction_process_date, NULL::text AS extraction_process_person_id, NULL::text AS extraction_process_kit, NULL::numeric AS extraction_process_elution_volume_ul, NULL::numeric AS extraction_process_yield_qubit_ng_ul, NULL::numeric AS extraction_process_yield_nanodrop_ng_ul, NULL::numeric AS extraction_process_a260_280, NULL::numeric AS extraction_process_a260_230, NULL::text AS extraction_result_dna_sample_id, NULL::text AS extraction_result_rna_sample_id,
    NULL::text AS extraction_blank_id,
    NULL::text AS nanodrop_id, NULL::numeric AS nanodrop_concentration, NULL::text AS nanodrop_concentration_unit, NULL::numeric AS nanodrop_a260, NULL::numeric AS nanodrop_a260_280_qc, NULL::numeric AS nanodrop_a260_230_qc, NULL::numeric AS nanodrop_total_dna_ug, NULL::date AS nanodrop_measurement_date, NULL::text AS nanodrop_a260_280_note, NULL::text AS nanodrop_a260_230_note,
    NULL::text AS qubit_id, NULL::numeric AS qubit_original_sample_conc, NULL::text AS qubit_original_sample_unit, NULL::numeric AS qubit_total_dna_ug, NULL::date AS qubit_measurement_date, NULL::text AS qubit_assay_kit, NULL::numeric AS qubit_tube_conc, NULL::text AS tube_unit_id, NULL::numeric AS sample_volume_ul, NULL::numeric AS elution_volume_ul,
    ts.tapestation_id,
    ts.measurement_date,
    ts.kit,
    NULL::text AS pcr_id, NULL::date AS pcr_date, NULL::text AS pcr_primer_id, NULL::text AS pcr_target_gene_id, NULL::numeric AS pcr_volume_reaction_ul, NULL::text AS pcr_blank_id, NULL::text AS pcr_position,
    NULL::text AS gel_gelelectrophoresis_id, NULL::date AS gel_run_date, NULL::integer AS gel_band_size_bp, NULL::text AS gel_gel_type, NULL::text AS gel_position, NULL::text AS gel_ladder, NULL::numeric AS gel_voltage, NULL::numeric AS gel_run_time_minutes,
    NULL::text AS qpcr_id, NULL::date AS qpcr_date, NULL::numeric AS qpcr_ct_value, NULL::text AS qpcr_inhibitor_test_result, NULL::text AS qpcr_position, NULL::text AS qpcr_primer_id_actual, NULL::text AS qpcr_pcr_blank_id, NULL::text AS qpcr_kit, NULL::numeric AS qpcr_volume_ul,
    NULL::text AS library_id, NULL::date AS library_prep_date, NULL::text AS library_name, NULL::text AS library_prep_kit, NULL::text AS library_index_sequence, NULL::integer AS library_read_length_bp,
    NULL::text AS sequencing_id, NULL::date AS sequencing_date, NULL::text AS sequencer, NULL::text AS flow_cell_id, NULL::bigint AS total_reads, NULL::text AS raw_data_path, NULL::text AS genbank_accession_number, NULL::text AS sequencing_library_prep_kit, NULL::text AS sequencing_index_sequence, NULL::integer AS sequencing_read_length_bp,
    NULL::text AS analysis_run_id, NULL::text AS pipeline_name, NULL::text AS pipeline_version, NULL::text AS bioinfo_reference_database, NULL::text AS bioinfo_database_version, NULL::numeric AS clustering_threshold, NULL::text AS final_output_path,
    NULL::text AS edna_assignment_id, NULL::text AS edna_assigned_taxon_id, NULL::text AS edna_assigned_taxon_name, NULL::integer AS edna_read_count, NULL::numeric AS edna_confidence,
    e.experiment_id AS associated_experiment_id, e.experiment_title AS associated_experiment_title, e.experiment_date AS associated_experiment_date, e.aim AS associated_experiment_aim, e.method AS associated_experiment_method, exp_person.full_name AS experiment_person_name,
    NULL::text AS sampler_full_name, NULL::text AS receiver_full_name
FROM
    "lab"."tapestation" ts
LEFT JOIN "lims"."projects" p ON ts.project_id = p.project_id
LEFT JOIN "reference"."status" stat ON ts.status_id = stat.status_id
LEFT JOIN "lab"."experiments" e ON ts.experiment_id = e.experiment_id AND ts.experiment_date = e.experiment_date
LEFT JOIN "reference"."personal" exp_person ON e.person_id = exp_person.person_id

UNION ALL

SELECT
    pcr.pcr_id AS sample_id,
    NULL AS external_name,
    pcr.sample_id AS parent_sample_id,
    'PCR Product' AS sample_origin_type,
    'PCRP' AS sample_type_id,
    'PCRP' AS sample_type_abrv,
    pcr.status_id AS sample_status_id,
    stat.notes AS sample_status_notes,
    NULL::text AS sampling_id,
    pcr.pcr_date AS sampling_date,
    NULL AS reception_date,
    pcr.project_id,
    p.title AS project_title,
    NULL::integer AS customer_id,
    NULL::text AS customer_name,
    pcr.storage_id,
    pcr.storage_position,
    pcr.notes,
    pcr.attachment,
    pcr.attachment_link,

    -- All other specific details are NULL
    NULL::numeric AS sampling_lon, NULL::numeric AS sampling_lat, NULL::numeric AS fishing_start_lon, NULL::numeric AS fishing_start_lat, NULL::numeric AS fishing_end_lon, NULL::numeric AS fishing_end_lat,
    NULL::text AS sampling_location, NULL::numeric AS sampling_depth_m, NULL::numeric AS temperature_atmospheric_c, NULL::text AS weather, NULL::numeric AS wind_speed, NULL::text AS wind_unit,
    NULL::numeric AS salinity, NULL::text AS salinity_unit, NULL::numeric AS oxygen, NULL::text AS oxygen_unit,
    NULL::text AS fish_species_id, NULL::text AS fish_species_en_name, NULL::numeric AS fish_total_length_mm, NULL::numeric AS fish_fork_length_mm, NULL::numeric AS fish_standard_length_mm, NULL::numeric AS fish_weight_g, NULL::text AS fish_sex, NULL::text AS fish_maturity_stage, NULL::text AS fish_stomach_contents, NULL::text AS fish_disease_info, NULL::text AS fish_tag_id,
    NULL::numeric AS tissue_weight_mg, NULL::text AS tissue_type, NULL::text AS tissue_preservation_method,
    NULL::numeric AS dna_volume_ul, NULL::numeric AS dna_concentration_ng_ul, NULL::numeric AS dna_a260_280, NULL::numeric AS dna_a260_230, NULL::text AS dna_extraction_method, NULL::date AS dna_extraction_date_dna, NULL::integer AS dna_extraction_number,
    NULL::numeric AS rna_volume_ul, NULL::numeric AS rna_concentration_ng_ul, NULL::numeric AS rna_a260_280, NULL::numeric AS rna_a260_230, NULL::text AS rna_extraction_method, NULL::date AS rna_extraction_date_rna, NULL::integer AS rna_extraction_number,
    NULL::numeric AS sediment_volume, NULL::text AS sediment_volume_unit, NULL::numeric AS sediment_depth_m, NULL::text AS sediment_sampling_method, NULL::text AS sediment_conservation_buffer,
    NULL::numeric AS water_volume_l, NULL::text AS water_filter, NULL::numeric AS water_filter_pore_size_um, NULL::numeric AS water_depth_m, NULL::text AS water_sampling_method, NULL::text AS water_conservation_buffer,
    NULL::text AS otolith_id, NULL::text AS otolith_reader_person_id, NULL::text AS otolith_side, NULL::numeric AS otolith_age_reading_years, NULL::numeric AS otolith_confidence,
    NULL::text AS dissection_id, NULL::text AS dissection_person_id, NULL::date AS dissection_date, NULL::jsonb AS dissection_stomach_contents_jsonb, NULL::numeric AS dissection_gonad_weight_g, NULL::numeric AS dissection_liver_weight_g,
    NULL::text AS extraction_id, NULL::date AS extraction_process_date, NULL::text AS extraction_process_person_id, NULL::text AS extraction_process_kit, NULL::numeric AS extraction_process_elution_volume_ul, NULL::numeric AS extraction_process_yield_qubit_ng_ul, NULL::numeric AS extraction_process_yield_nanodrop_ng_ul, NULL::numeric AS extraction_process_a260_280, NULL::numeric AS extraction_process_a260_230, NULL::text AS extraction_result_dna_sample_id, NULL::text AS extraction_result_rna_sample_id,
    NULL::text AS extraction_blank_id,
    NULL::text AS nanodrop_id, NULL::numeric AS nanodrop_concentration, NULL::text AS nanodrop_concentration_unit, NULL::numeric AS nanodrop_a260, NULL::numeric AS nanodrop_a260_280_qc, NULL::numeric AS nanodrop_a260_230_qc, NULL::numeric AS nanodrop_total_dna_ug, NULL::date AS nanodrop_measurement_date, NULL::text AS nanodrop_a260_280_note, NULL::text AS nanodrop_a260_230_note,
    NULL::text AS qubit_id, NULL::numeric AS qubit_original_sample_conc, NULL::text AS qubit_original_sample_unit, NULL::numeric AS qubit_total_dna_ug, NULL::date AS qubit_measurement_date, NULL::text AS qubit_assay_kit, NULL::numeric AS qubit_tube_conc, NULL::text AS tube_unit_id, NULL::numeric AS sample_volume_ul, NULL::numeric AS elution_volume_ul,
    NULL::text AS tapestation_id, NULL::date AS tapestation_measurement_date, NULL::text AS tapestation_kit,
    pcr.pcr_id,
    pcr.pcr_date,
    pcr_primer.primer_id AS pcr_primer_id,
    pcr_primer.target_gene_id AS pcr_target_gene_id,
    pcr.volume_reaction_ul,
    pcr.pcr_blank_id,
    pcr.position AS pcr_position,
    NULL::text AS gel_gelelectrophoresis_id, NULL::date AS gel_run_date, NULL::integer AS gel_band_size_bp, NULL::text AS gel_gel_type, NULL::text AS gel_position, NULL::text AS gel_ladder, NULL::numeric AS gel_voltage, NULL::numeric AS gel_run_time_minutes,
    NULL::text AS qpcr_id, NULL::date AS qpcr_date, NULL::numeric AS qpcr_ct_value, NULL::text AS qpcr_inhibitor_test_result, NULL::text AS qpcr_position, NULL::text AS qpcr_primer_id_actual, NULL::text AS qpcr_pcr_blank_id, NULL::text AS qpcr_kit, NULL::numeric AS qpcr_volume_ul,
    NULL::text AS library_id, NULL::date AS library_prep_date, NULL::text AS library_name, NULL::text AS library_prep_kit, NULL::text AS library_index_sequence, NULL::integer AS library_read_length_bp,
    NULL::text AS sequencing_id, NULL::date AS sequencing_date, NULL::text AS sequencer, NULL::text AS flow_cell_id, NULL::bigint AS total_reads, NULL::text AS raw_data_path, NULL::text AS genbank_accession_number, NULL::text AS sequencing_library_prep_kit, NULL::text AS sequencing_index_sequence, NULL::integer AS sequencing_read_length_bp,
    NULL::text AS analysis_run_id, NULL::text AS pipeline_name, NULL::text AS pipeline_version, NULL::text AS bioinfo_reference_database, NULL::text AS bioinfo_database_version, NULL::numeric AS clustering_threshold, NULL::text AS final_output_path,
    NULL::text AS edna_assignment_id, NULL::text AS edna_assigned_taxon_id, NULL::text AS edna_assigned_taxon_name, NULL::integer AS edna_read_count, NULL::numeric AS edna_confidence,
    e.experiment_id AS associated_experiment_id, e.experiment_title AS associated_experiment_title, e.experiment_date AS associated_experiment_date, e.aim AS associated_experiment_aim, e.method AS associated_experiment_method, exp_person.full_name AS experiment_person_name,
    NULL::text AS sampler_full_name, NULL::text AS receiver_full_name
FROM
    "lab"."pcr" pcr
LEFT JOIN "lims"."projects" p ON pcr.project_id = p.project_id
LEFT JOIN "reference"."status" stat ON pcr.status_id = stat.status_id
LEFT JOIN "lims"."primers" pcr_primer ON pcr.primer_id = pcr_primer.primer_id
LEFT JOIN "lab"."experiments" e ON pcr.experiment_id = e.experiment_id AND pcr.experiment_date = e.experiment_date
LEFT JOIN "reference"."personal" exp_person ON e.person_id = exp_person.person_id

UNION ALL

SELECT
    gel.gelelectrophoresis_id AS sample_id,
    NULL AS external_name,
    gel.sample_id AS parent_sample_id,
    'Gel Electrophoresis Result' AS sample_origin_type,
    'GE' AS sample_type_id,
    'GE' AS sample_type_abrv,
    NULL AS sample_status_id, -- Gel table doesn't have status_id, default to NULL
    NULL AS sample_status_notes,
    NULL::text AS sampling_id,
    gel.run_date AS sampling_date,
    NULL AS reception_date,
    gel.project_id,
    p.title AS project_title,
    NULL::integer AS customer_id,
    NULL::text AS customer_name,
    gel.storage_id,
    gel.storage_position,
    gel.notes,
    gel.attachment,
    gel.attachment_link,

    -- All other specific details are NULL
    NULL::numeric AS sampling_lon, NULL::numeric AS sampling_lat, NULL::numeric AS fishing_start_lon, NULL::numeric AS fishing_start_lat, NULL::numeric AS fishing_end_lon, NULL::numeric AS fishing_end_lat,
    NULL::text AS sampling_location, NULL::numeric AS sampling_depth_m, NULL::numeric AS temperature_atmospheric_c, NULL::text AS weather, NULL::numeric AS wind_speed, NULL::text AS wind_unit,
    NULL::numeric AS salinity, NULL::text AS salinity_unit, NULL::numeric AS oxygen, NULL::text AS oxygen_unit,
    NULL::text AS fish_species_id, NULL::text AS fish_species_en_name, NULL::numeric AS fish_total_length_mm, NULL::numeric AS fish_fork_length_mm, NULL::numeric AS fish_standard_length_mm, NULL::numeric AS fish_weight_g, NULL::text AS fish_sex, NULL::text AS fish_maturity_stage, NULL::text AS fish_stomach_contents, NULL::text AS fish_disease_info, NULL::text AS fish_tag_id,
    NULL::numeric AS tissue_weight_mg, NULL::text AS tissue_type, NULL::text AS tissue_preservation_method,
    NULL::numeric AS dna_volume_ul, NULL::numeric AS dna_concentration_ng_ul, NULL::numeric AS dna_a260_280, NULL::numeric AS dna_a260_230, NULL::text AS dna_extraction_method, NULL::date AS dna_extraction_date_dna, NULL::integer AS dna_extraction_number,
    NULL::numeric AS rna_volume_ul, NULL::numeric AS rna_concentration_ng_ul, NULL::numeric AS rna_a260_280, NULL::numeric AS rna_a260_230, NULL::text AS rna_extraction_method, NULL::date AS rna_extraction_date_rna, NULL::integer AS rna_extraction_number,
    NULL::numeric AS sediment_volume, NULL::text AS sediment_volume_unit, NULL::numeric AS sediment_depth_m, NULL::text AS sediment_sampling_method, NULL::text AS sediment_conservation_buffer,
    NULL::numeric AS water_volume_l, NULL::text AS water_filter, NULL::numeric AS water_filter_pore_size_um, NULL::numeric AS water_depth_m, NULL::text AS water_sampling_method, NULL::text AS water_conservation_buffer,
    NULL::text AS otolith_id, NULL::text AS otolith_reader_person_id, NULL::text AS otolith_side, NULL::numeric AS otolith_age_reading_years, NULL::numeric AS otolith_confidence,
    NULL::text AS dissection_id, NULL::text AS dissection_person_id, NULL::date AS dissection_date, NULL::jsonb AS dissection_stomach_contents_jsonb, NULL::numeric AS dissection_gonad_weight_g, NULL::numeric AS dissection_liver_weight_g,
    NULL::text AS extraction_id, NULL::date AS extraction_process_date, NULL::text AS extraction_process_person_id, NULL::text AS extraction_process_kit, NULL::numeric AS extraction_process_elution_volume_ul, NULL::numeric AS extraction_process_yield_qubit_ng_ul, NULL::numeric AS extraction_process_yield_nanodrop_ng_ul, NULL::numeric AS extraction_process_a260_280, NULL::numeric AS extraction_process_a260_230, NULL::text AS extraction_result_dna_sample_id, NULL::text AS extraction_result_rna_sample_id,
    NULL::text AS extraction_blank_id,
    NULL::text AS nanodrop_id, NULL::numeric AS nanodrop_concentration, NULL::text AS nanodrop_concentration_unit, NULL::numeric AS nanodrop_a260, NULL::numeric AS nanodrop_a260_280_qc, NULL::numeric AS nanodrop_a260_230_qc, NULL::numeric AS nanodrop_total_dna_ug, NULL::date AS nanodrop_measurement_date, NULL::text AS nanodrop_a260_280_note, NULL::text AS nanodrop_a260_230_note,
    NULL::text AS qubit_id, NULL::numeric AS qubit_original_sample_conc, NULL::text AS qubit_original_sample_unit, NULL::numeric AS qubit_total_dna_ug, NULL::date AS qubit_measurement_date, NULL::text AS qubit_assay_kit, NULL::numeric AS qubit_tube_conc, NULL::text AS tube_unit_id, NULL::numeric AS sample_volume_ul, NULL::numeric AS elution_volume_ul,
    NULL::text AS tapestation_id, NULL::date AS tapestation_measurement_date, NULL::text AS tapestation_kit,
    NULL::text AS pcr_id, NULL::date AS pcr_date, NULL::text AS pcr_primer_id, NULL::text AS pcr_target_gene_id, NULL::numeric AS pcr_volume_reaction_ul, NULL::text AS pcr_blank_id, NULL::text AS pcr_position,
    gel.gelelectrophoresis_id,
    gel.run_date,
    gel.band_size_bp,
    gel.gel_type,
    gel.position AS gel_position,
    gel.ladder AS gel_ladder,
    gel.voltage AS gel_voltage,
    gel.run_time_minutes AS gel_run_time_minutes,
    NULL::text AS qpcr_id, NULL::date AS qpcr_date, NULL::numeric AS qpcr_ct_value, NULL::text AS qpcr_inhibitor_test_result, NULL::text AS qpcr_position, NULL::text AS qpcr_primer_id_actual, NULL::text AS qpcr_pcr_blank_id, NULL::text AS qpcr_kit, NULL::numeric AS qpcr_volume_ul,
    NULL::text AS library_id, NULL::date AS library_prep_date, NULL::text AS library_name, NULL::text AS library_prep_kit, NULL::text AS library_index_sequence, NULL::integer AS library_read_length_bp,
    NULL::text AS sequencing_id, NULL::date AS sequencing_date, NULL::text AS sequencer, NULL::text AS flow_cell_id, NULL::bigint AS total_reads, NULL::text AS raw_data_path, NULL::text AS genbank_accession_number, NULL::text AS sequencing_library_prep_kit, NULL::text AS sequencing_index_sequence, NULL::integer AS sequencing_read_length_bp,
    NULL::text AS analysis_run_id, NULL::text AS pipeline_name, NULL::text AS pipeline_version, NULL::text AS bioinfo_reference_database, NULL::text AS bioinfo_database_version, NULL::numeric AS clustering_threshold, NULL::text AS final_output_path,
    NULL::text AS edna_assignment_id, NULL::text AS edna_assigned_taxon_id, NULL::text AS edna_assigned_taxon_name, NULL::integer AS edna_read_count, NULL::numeric AS edna_confidence,
    e.experiment_id AS associated_experiment_id, e.experiment_title AS associated_experiment_title, e.experiment_date AS associated_experiment_date, e.aim AS associated_experiment_aim, e.method AS associated_experiment_method, exp_person.full_name AS experiment_person_name,
    NULL::text AS sampler_full_name, NULL::text AS receiver_full_name
FROM
    "lab"."gelelectrophoresis" gel
LEFT JOIN "lims"."projects" p ON gel.project_id = p.project_id
LEFT JOIN "lab"."experiments" e ON gel.experiment_id = e.experiment_id AND gel.experiment_date = e.experiment_date
LEFT JOIN "reference"."personal" exp_person ON e.person_id = exp_person.person_id

UNION ALL

SELECT
    qpcr.qpcr_id AS sample_id,
    NULL AS external_name,
    qpcr.sample_id AS parent_sample_id,
    'qPCR Result' AS sample_origin_type,
    'QPCRR' AS sample_type_id,
    'QPCRR' AS sample_type_abrv,
    qpcr.status_id AS sample_status_id,
    stat.notes AS sample_status_notes,
    NULL::text AS sampling_id,
    qpcr.qpcr_date AS sampling_date,
    NULL AS reception_date,
    qpcr.project_id,
    p.title AS project_title,
    NULL::integer AS customer_id,
    NULL::text AS customer_name,
    qpcr.storage_id,
    qpcr.storage_position,
    NULL::text AS notes,
    qpcr.attachment,
    qpcr.attachment_link,

    -- All other specific details are NULL
    NULL::numeric AS sampling_lon, NULL::numeric AS sampling_lat, NULL::numeric AS fishing_start_lon, NULL::numeric AS fishing_start_lat, NULL::numeric AS fishing_end_lon, NULL::numeric AS fishing_end_lat,
    NULL::text AS sampling_location, NULL::numeric AS sampling_depth_m, NULL::numeric AS temperature_atmospheric_c, NULL::text AS weather, NULL::numeric AS wind_speed, NULL::text AS wind_unit,
    NULL::numeric AS salinity, NULL::text AS salinity_unit, NULL::numeric AS oxygen, NULL::text AS oxygen_unit,
    NULL::text AS fish_species_id, NULL::text AS fish_species_en_name, NULL::numeric AS fish_total_length_mm, NULL::numeric AS fish_fork_length_mm, NULL::numeric AS fish_standard_length_mm, NULL::numeric AS fish_weight_g, NULL::text AS fish_sex, NULL::text AS fish_maturity_stage, NULL::text AS fish_stomach_contents, NULL::text AS fish_disease_info, NULL::text AS fish_tag_id,
    NULL::numeric AS tissue_weight_mg, NULL::text AS tissue_type, NULL::text AS tissue_preservation_method,
    NULL::numeric AS dna_volume_ul, NULL::numeric AS dna_concentration_ng_ul, NULL::numeric AS dna_a260_280, NULL::numeric AS dna_a260_230, NULL::text AS dna_extraction_method, NULL::date AS dna_extraction_date_dna, NULL::integer AS dna_extraction_number,
    NULL::numeric AS rna_volume_ul, NULL::numeric AS rna_concentration_ng_ul, NULL::numeric AS rna_a260_280, NULL::numeric AS rna_a260_230, NULL::text AS rna_extraction_method, NULL::date AS rna_extraction_date_rna, NULL::integer AS rna_extraction_number,
    NULL::numeric AS sediment_volume, NULL::text AS sediment_volume_unit, NULL::numeric AS sediment_depth_m, NULL::text AS sediment_sampling_method, NULL::text AS sediment_conservation_buffer,
    NULL::numeric AS water_volume_l, NULL::text AS water_filter, NULL::numeric AS water_filter_pore_size_um, NULL::numeric AS water_depth_m, NULL::text AS water_sampling_method, NULL::text AS water_conservation_buffer,
    NULL::text AS otolith_id, NULL::text AS otolith_reader_person_id, NULL::text AS otolith_side, NULL::numeric AS otolith_age_reading_years, NULL::numeric AS otolith_confidence,
    NULL::text AS dissection_id, NULL::text AS dissection_person_id, NULL::date AS dissection_date, NULL::jsonb AS dissection_stomach_contents_jsonb, NULL::numeric AS dissection_gonad_weight_g, NULL::numeric AS dissection_liver_weight_g,
    NULL::text AS extraction_id, NULL::date AS extraction_process_date, NULL::text AS extraction_process_person_id, NULL::text AS extraction_process_kit, NULL::numeric AS extraction_process_elution_volume_ul, NULL::numeric AS extraction_process_yield_qubit_ng_ul, NULL::numeric AS extraction_process_yield_nanodrop_ng_ul, NULL::numeric AS extraction_process_a260_280, NULL::numeric AS extraction_process_a260_230, NULL::text AS extraction_result_dna_sample_id, NULL::text AS extraction_result_rna_sample_id,
    NULL::text AS extraction_blank_id,
    NULL::text AS nanodrop_id, NULL::numeric AS nanodrop_concentration, NULL::text AS nanodrop_concentration_unit, NULL::numeric AS nanodrop_a260, NULL::numeric AS nanodrop_a260_280_qc, NULL::numeric AS nanodrop_a260_230_qc, NULL::numeric AS nanodrop_total_dna_ug, NULL::date AS nanodrop_measurement_date, NULL::text AS nanodrop_a260_280_note, NULL::text AS nanodrop_a260_230_note,
    NULL::text AS qubit_id, NULL::numeric AS qubit_original_sample_conc, NULL::text AS qubit_original_sample_unit, NULL::numeric AS qubit_total_dna_ug, NULL::date AS qubit_measurement_date, NULL::text AS qubit_assay_kit, NULL::numeric AS qubit_tube_conc, NULL::text AS tube_unit_id, NULL::numeric AS sample_volume_ul, NULL::numeric AS elution_volume_ul,
    NULL::text AS tapestation_id, NULL::date AS tapestation_measurement_date, NULL::text AS tapestation_kit,
    NULL::text AS pcr_id, NULL::date AS pcr_date, NULL::text AS pcr_primer_id, NULL::text AS pcr_target_gene_id, NULL::numeric AS pcr_volume_reaction_ul, NULL::text AS pcr_blank_id, NULL::text AS pcr_position,
    NULL::text AS gel_gelelectrophoresis_id, NULL::date AS gel_run_date, NULL::integer AS gel_band_size_bp, NULL::text AS gel_gel_type, NULL::text AS gel_position, NULL::text AS gel_ladder, NULL::numeric AS gel_voltage, NULL::numeric AS gel_run_time_minutes,
    qpcr.qpcr_id,
    qpcr.qpcr_date,
    qpcr.ct_value,
    qpcr.inhibitor_test_result,
    qpcr.position AS qpcr_position,
    qpcr.primer_id AS qpcr_primer_id_actual,
    qpcr.pcr_blank_id AS qpcr_pcr_blank_id,
    qpcr.kit AS qpcr_kit,
    qpcr.volume_ul AS qpcr_volume_ul,
    NULL::text AS library_id, NULL::date AS library_prep_date, NULL::text AS library_name, NULL::text AS library_prep_kit, NULL::text AS library_index_sequence, NULL::integer AS library_read_length_bp,
    NULL::text AS sequencing_id, NULL::date AS sequencing_date, NULL::text AS sequencer, NULL::text AS flow_cell_id, NULL::bigint AS total_reads, NULL::text AS raw_data_path, NULL::text AS genbank_accession_number, NULL::text AS sequencing_library_prep_kit, NULL::text AS sequencing_index_sequence, NULL::integer AS sequencing_read_length_bp,
    NULL::text AS analysis_run_id, NULL::text AS pipeline_name, NULL::text AS pipeline_version, NULL::text AS bioinfo_reference_database, NULL::text AS bioinfo_database_version, NULL::numeric AS clustering_threshold, NULL::text AS final_output_path,
    NULL::text AS edna_assignment_id, NULL::text AS edna_assigned_taxon_id, NULL::text AS edna_assigned_taxon_name, NULL::integer AS edna_read_count, NULL::numeric AS edna_confidence,
    e.experiment_id AS associated_experiment_id, e.experiment_title AS associated_experiment_title, e.experiment_date AS associated_experiment_date, e.aim AS associated_experiment_aim, e.method AS associated_experiment_method, exp_person.full_name AS experiment_person_name,
    NULL::text AS sampler_full_name, NULL::text AS receiver_full_name
FROM
    "lab"."qpcr" qpcr
LEFT JOIN "lims"."projects" p ON qpcr.project_id = p.project_id
LEFT JOIN "reference"."status" stat ON qpcr.status_id = stat.status_id
LEFT JOIN "lab"."experiments" e ON qpcr.experiment_id = e.experiment_id AND qpcr.experiment_date = e.experiment_date
LEFT JOIN "reference"."personal" exp_person ON e.person_id = exp_person.person_id

UNION ALL

SELECT
    lib.library_id AS sample_id,
    NULL AS external_name,
    lib.sample_id AS parent_sample_id,
    'Library Prep Product' AS sample_origin_type,
    'LIBP' AS sample_type_id,
    'LIBP' AS sample_type_abrv,
    (SELECT status_id FROM "reference"."status" WHERE notes = 'Received') AS sample_status_id,
    (SELECT notes FROM "reference"."status" WHERE status_id = 'Received') AS sample_status_notes,
    NULL::text AS sampling_id,
    lib.prep_date AS sampling_date,
    NULL AS reception_date,
    lib.project_id,
    p.title AS project_title,
    NULL::integer AS customer_id,
    NULL::text AS customer_name,
    lib.storage_id,
    lib.storage_position,
    lib.notes,
    lib.attachment,
    lib.attachment_link,

    -- All other specific details are NULL
    NULL::numeric AS sampling_lon, NULL::numeric AS sampling_lat, NULL::numeric AS fishing_start_lon, NULL::numeric AS fishing_start_lat, NULL::numeric AS fishing_end_lon, NULL::numeric AS fishing_end_lat,
    NULL::text AS sampling_location, NULL::numeric AS sampling_depth_m, NULL::numeric AS temperature_atmospheric_c, NULL::text AS weather, NULL::numeric AS wind_speed, NULL::text AS wind_unit,
    NULL::numeric AS salinity, NULL::text AS salinity_unit, NULL::numeric AS oxygen, NULL::text AS oxygen_unit,
    NULL::text AS fish_species_id, NULL::text AS fish_species_en_name, NULL::numeric AS fish_total_length_mm, NULL::numeric AS fish_fork_length_mm, NULL::numeric AS fish_standard_length_mm, NULL::numeric AS fish_weight_g, NULL::text AS fish_sex, NULL::text AS fish_maturity_stage, NULL::text AS fish_stomach_contents, NULL::text AS fish_disease_info, NULL::text AS fish_tag_id,
    NULL::numeric AS tissue_weight_mg, NULL::text AS tissue_type, NULL::text AS tissue_preservation_method,
    NULL::numeric AS dna_volume_ul, NULL::numeric AS dna_concentration_ng_ul, NULL::numeric AS dna_a260_280, NULL::numeric AS dna_a260_230, NULL::text AS dna_extraction_method, NULL::date AS dna_extraction_date_dna, NULL::integer AS dna_extraction_number,
    NULL::numeric AS rna_volume_ul, NULL::numeric AS rna_concentration_ng_ul, NULL::numeric AS rna_a260_280, NULL::numeric AS rna_a260_230, NULL::text AS rna_extraction_method, NULL::date AS rna_extraction_date_rna, NULL::integer AS rna_extraction_number,
    NULL::numeric AS sediment_volume, NULL::text AS sediment_volume_unit, NULL::numeric AS sediment_depth_m, NULL::text AS sediment_sampling_method, NULL::text AS sediment_conservation_buffer,
    NULL::numeric AS water_volume_l, NULL::text AS water_filter, NULL::numeric AS water_filter_pore_size_um, NULL::numeric AS water_depth_m, NULL::text AS water_sampling_method, NULL::text AS water_conservation_buffer,
    NULL::text AS otolith_id, NULL::text AS otolith_reader_person_id, NULL::text AS otolith_side, NULL::numeric AS otolith_age_reading_years, NULL::numeric AS otolith_confidence,
    NULL::text AS dissection_id, NULL::text AS dissection_person_id, NULL::date AS dissection_date, NULL::jsonb AS dissection_stomach_contents_jsonb, NULL::numeric AS dissection_gonad_weight_g, NULL::numeric AS dissection_liver_weight_g,
    NULL::text AS extraction_id, NULL::date AS extraction_process_date, NULL::text AS extraction_process_person_id, NULL::text AS extraction_process_kit, NULL::numeric AS extraction_process_elution_volume_ul, NULL::numeric AS extraction_process_yield_qubit_ng_ul, NULL::numeric AS extraction_process_yield_nanodrop_ng_ul, NULL::numeric AS extraction_process_a260_280, NULL::numeric AS extraction_process_a260_230, NULL::text AS extraction_result_dna_sample_id, NULL::text AS extraction_result_rna_sample_id,
    NULL::text AS extraction_blank_id,
    NULL::text AS nanodrop_id, NULL::numeric AS nanodrop_concentration, NULL::text AS nanodrop_concentration_unit, NULL::numeric AS nanodrop_a260, NULL::numeric AS nanodrop_a260_280_qc, NULL::numeric AS nanodrop_a260_230_qc, NULL::numeric AS nanodrop_total_dna_ug, NULL::date AS nanodrop_measurement_date, NULL::text AS nanodrop_a260_280_note, NULL::text AS nanodrop_a260_230_note,
    NULL::text AS qubit_id, NULL::numeric AS qubit_original_sample_conc, NULL::text AS qubit_original_sample_unit, NULL::numeric AS qubit_total_dna_ug, NULL::date AS qubit_measurement_date, NULL::text AS qubit_assay_kit, NULL::numeric AS qubit_tube_conc, NULL::text AS tube_unit_id, NULL::numeric AS sample_volume_ul, NULL::numeric AS elution_volume_ul,
    NULL::text AS tapestation_id, NULL::date AS tapestation_measurement_date, NULL::text AS tapestation_kit,
    NULL::text AS pcr_id, NULL::date AS pcr_date, NULL::text AS pcr_primer_id, NULL::text AS pcr_target_gene_id, NULL::numeric AS pcr_volume_reaction_ul, NULL::text AS pcr_blank_id, NULL::text AS pcr_position,
    NULL::text AS gel_gelelectrophoresis_id, NULL::date AS gel_run_date, NULL::integer AS gel_band_size_bp, NULL::text AS gel_gel_type, NULL::text AS gel_position, NULL::text AS gel_ladder, NULL::numeric AS gel_voltage, NULL::numeric AS gel_run_time_minutes,
    NULL::text AS qpcr_id, NULL::date AS qpcr_date, NULL::numeric AS qpcr_ct_value, NULL::text AS qpcr_inhibitor_test_result, NULL::text AS qpcr_position, NULL::text AS qpcr_primer_id_actual, NULL::text AS qpcr_pcr_blank_id, NULL::text AS qpcr_kit, NULL::numeric AS qpcr_volume_ul,
    lib.library_id,
    lib.prep_date,
    lib.library_name,
    lib.library_prep_kit,
    lib.index_sequence,
    lib.read_length_bp,
    NULL::text AS sequencing_id, NULL::date AS sequencing_date, NULL::text AS sequencer, NULL::text AS flow_cell_id, NULL::bigint AS total_reads, NULL::text AS raw_data_path, NULL::text AS genbank_accession_number, NULL::text AS sequencing_library_prep_kit, NULL::text AS sequencing_index_sequence, NULL::integer AS sequencing_read_length_bp,
    NULL::text AS analysis_run_id, NULL::text AS pipeline_name, NULL::text AS pipeline_version, NULL::text AS bioinfo_reference_database, NULL::text AS bioinfo_database_version, NULL::numeric AS clustering_threshold, NULL::text AS final_output_path,
    NULL::text AS edna_assignment_id, NULL::text AS edna_assigned_taxon_id, NULL::text AS edna_assigned_taxon_name, NULL::integer AS edna_read_count, NULL::numeric AS edna_confidence,
    e.experiment_id AS associated_experiment_id, e.experiment_title AS associated_experiment_title, e.experiment_date AS associated_experiment_date, e.aim AS associated_experiment_aim, e.method AS associated_experiment_method, exp_person.full_name AS experiment_person_name,
    NULL::text AS sampler_full_name, NULL::text AS receiver_full_name
FROM
    "lab"."library" lib
LEFT JOIN "lims"."projects" p ON lib.project_id = p.project_id
LEFT JOIN "lab"."experiments" e ON lib.experiment_id = e.experiment_id AND lib.experiment_date = e.experiment_date
LEFT JOIN "reference"."personal" exp_person ON e.person_id = exp_person.person_id

UNION ALL

SELECT
    seq.sequencing_id AS sample_id,
    NULL AS external_name,
    seq.sample_id AS parent_sample_id,
    'Sequencing Run' AS sample_origin_type,
    'SEQR' AS sample_type_id,
    'SEQR' AS sample_type_abrv,
    seq.status_id AS sample_status_id,
    stat.notes AS sample_status_notes,
    NULL::text AS sampling_id,
    seq.sequencing_date AS sampling_date,
    NULL AS reception_date,
    seq.project_id,
    p.title AS project_title,
    NULL::integer AS customer_id,
    NULL::text AS customer_name,
    seq.storage_id,
    seq.storage_position,
    seq.notes,
    seq.attachment,
    seq.attachment_link,

    -- All other specific details are NULL
    NULL::numeric AS sampling_lon, NULL::numeric AS sampling_lat, NULL::numeric AS fishing_start_lon, NULL::numeric AS fishing_start_lat, NULL::numeric AS fishing_end_lon, NULL::numeric AS fishing_end_lat,
    NULL::text AS sampling_location, NULL::numeric AS sampling_depth_m, NULL::numeric AS temperature_atmospheric_c, NULL::text AS weather, NULL::numeric AS wind_speed, NULL::text AS wind_unit,
    NULL::numeric AS salinity, NULL::text AS salinity_unit, NULL::numeric AS oxygen, NULL::text AS oxygen_unit,
    NULL::text AS fish_species_id, NULL::text AS fish_species_en_name, NULL::numeric AS fish_total_length_mm, NULL::numeric AS fish_fork_length_mm, NULL::numeric AS fish_standard_length_mm, NULL::numeric AS fish_weight_g, NULL::text AS fish_sex, NULL::text AS fish_maturity_stage, NULL::text AS fish_stomach_contents, NULL::text AS fish_disease_info, NULL::text AS fish_tag_id,
    NULL::numeric AS tissue_weight_mg, NULL::text AS tissue_type, NULL::text AS tissue_preservation_method,
    NULL::numeric AS dna_volume_ul, NULL::numeric AS dna_concentration_ng_ul, NULL::numeric AS dna_a260_280, NULL::numeric AS dna_a260_230, NULL::text AS dna_extraction_method, NULL::date AS dna_extraction_date_dna, NULL::integer AS dna_extraction_number,
    NULL::numeric AS rna_volume_ul, NULL::numeric AS rna_concentration_ng_ul, NULL::numeric AS rna_a260_280, NULL::numeric AS rna_a260_230, NULL::text AS rna_extraction_method, NULL::date AS rna_extraction_date_rna, NULL::integer AS rna_extraction_number,
    NULL::numeric AS sediment_volume, NULL::text AS sediment_volume_unit, NULL::numeric AS sediment_depth_m, NULL::text AS sediment_sampling_method, NULL::text AS sediment_conservation_buffer,
    NULL::numeric AS water_volume_l, NULL::text AS water_filter, NULL::numeric AS water_filter_pore_size_um, NULL::numeric AS water_depth_m, NULL::text AS water_sampling_method, NULL::text AS water_conservation_buffer,
    NULL::text AS otolith_id, NULL::text AS otolith_reader_person_id, NULL::text AS otolith_side, NULL::numeric AS otolith_age_reading_years, NULL::numeric AS otolith_confidence,
    NULL::text AS dissection_id, NULL::text AS dissection_person_id, NULL::date AS dissection_date, NULL::jsonb AS dissection_stomach_contents_jsonb, NULL::numeric AS dissection_gonad_weight_g, NULL::numeric AS dissection_liver_weight_g,
    NULL::text AS extraction_id, NULL::date AS extraction_process_date, NULL::text AS extraction_process_person_id, NULL::text AS extraction_process_kit, NULL::numeric AS extraction_process_elution_volume_ul, NULL::numeric AS extraction_process_yield_qubit_ng_ul, NULL::numeric AS extraction_process_yield_nanodrop_ng_ul, NULL::numeric AS extraction_process_a260_280, NULL::numeric AS extraction_process_a260_230, NULL::text AS extraction_result_dna_sample_id, NULL::text AS extraction_result_rna_sample_id,
    NULL::text AS extraction_blank_id,
    NULL::text AS nanodrop_id, NULL::numeric AS nanodrop_concentration, NULL::text AS nanodrop_concentration_unit, NULL::numeric AS nanodrop_a260, NULL::numeric AS nanodrop_a260_280_qc, NULL::numeric AS nanodrop_a260_230_qc, NULL::numeric AS nanodrop_total_dna_ug, NULL::date AS nanodrop_measurement_date, NULL::text AS nanodrop_a260_280_note, NULL::text AS nanodrop_a260_230_note,
    NULL::text AS qubit_id, NULL::numeric AS qubit_original_sample_conc, NULL::text AS qubit_original_sample_unit, NULL::numeric AS qubit_total_dna_ug, NULL::date AS qubit_measurement_date, NULL::text AS qubit_assay_kit, NULL::numeric AS qubit_tube_conc, NULL::text AS tube_unit_id, NULL::numeric AS sample_volume_ul, NULL::numeric AS elution_volume_ul,
    NULL::text AS tapestation_id, NULL::date AS tapestation_measurement_date, NULL::text AS tapestation_kit,
    NULL::text AS pcr_id, NULL::date AS pcr_date, NULL::text AS pcr_primer_id, NULL::text AS pcr_target_gene_id, NULL::numeric AS pcr_volume_reaction_ul, NULL::text AS pcr_blank_id, NULL::text AS pcr_position,
    NULL::text AS gel_gelelectrophoresis_id, NULL::date AS gel_run_date, NULL::integer AS gel_band_size_bp, NULL::text AS gel_gel_type, NULL::text AS gel_position, NULL::text AS gel_ladder, NULL::numeric AS gel_voltage, NULL::numeric AS gel_run_time_minutes,
    NULL::text AS qpcr_id, NULL::date AS qpcr_date, NULL::numeric AS qpcr_ct_value, NULL::text AS qpcr_inhibitor_test_result, NULL::text AS qpcr_position, NULL::text AS qpcr_primer_id_actual, NULL::text AS qpcr_pcr_blank_id, NULL::text AS qpcr_kit, NULL::numeric AS qpcr_volume_ul,
    NULL::text AS library_id, NULL::date AS library_prep_date, NULL::text AS library_name, NULL::text AS library_prep_kit, NULL::text AS library_index_sequence, NULL::integer AS library_read_length_bp,
    seq.sequencing_id,
    seq.sequencing_date,
    seq.sequencer,
    seq.flow_cell_id,
    seq.total_reads,
    seq.raw_data_path,
    seq.genbank_accession_number,
    seq.library_prep_kit AS sequencing_library_prep_kit,
    seq.index_sequence AS sequencing_index_sequence,
    seq.read_length_bp AS sequencing_read_length_bp,
    ar.run_id AS analysis_run_id,
    ap.pipeline_name,
    ap.version AS pipeline_version,
    rdb.db_name AS bioinfo_reference_database,
    rdb.db_version AS bioinfo_database_version,
    ar.clustering_threshold,
    ar.final_output_path,
    ea.assignment_id AS edna_assignment_id,
    ea.taxon_id AS edna_assigned_taxon_id,
    ea_taxon.en_name AS edna_assigned_taxon_name,
    ea.read_count AS edna_read_count,
    ea.confidence AS edna_confidence,
    e.experiment_id AS associated_experiment_id, e.experiment_title AS associated_experiment_title, e.experiment_date AS associated_experiment_date, e.aim AS associated_experiment_aim, e.method AS associated_experiment_method, exp_person.full_name AS experiment_person_name,
    NULL::text AS sampler_full_name, NULL::text AS receiver_full_name

FROM
    "lab"."sequencing" seq
LEFT JOIN "lims"."projects" p ON seq.project_id = p.project_id
LEFT JOIN "reference"."status" stat ON seq.status_id = stat.status_id
LEFT JOIN "lab"."experiments" e ON seq.experiment_id = e.experiment_id AND seq.sequencing_date = e.experiment_date -- Corrected join date
LEFT JOIN "reference"."personal" exp_person ON e.person_id = exp_person.person_id
LEFT JOIN "bioinformatics"."analysis_runs" ar ON seq.sequencing_id = ar.sequencing_id AND seq.sequencing_date = ar.sequencing_date
LEFT JOIN "bioinformatics"."analysis_pipelines" ap ON ar.pipeline_id = ap.pipeline_id
LEFT JOIN "bioinformatics"."reference_databases" rdb ON ar.reference_db_id = rdb.db_id
LEFT JOIN "bioinformatics"."edna_assignments" ea ON ar.run_id = ea.run_id AND ar.run_date = ea.run_date AND seq.sample_id = ea.sample_id
LEFT JOIN "reference"."taxon" ea_taxon ON ea.taxon_id = ea_taxon.taxon_id;



-- ==============================================================================
-- ======================================================================
-- 15. Partitioning Setup
-- ======================================================================
-- In section "15. Partitioning Setup"

DO $$
DECLARE
    current_year_int INTEGER := EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER;
    next_year_int INTEGER := current_year_int + 1;
BEGIN
    PERFORM "lab".create_sampling_partition_if_not_exists_manual(current_year_int);
    PERFORM "lab".create_sampling_partition_if_not_exists_manual(next_year_int);
END $$;

DO $$
DECLARE -- Re-declare variables here
    current_year_int INTEGER := EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER;
    next_year_int INTEGER := current_year_int + 1;
    current_year_start_date TEXT := (current_year_int || '-01-01');
    current_year_end_date TEXT := ((current_year_int + 1) || '-01-01');
    next_year_start_date TEXT := (next_year_int || '-01-01');
    next_year_end_date TEXT := ((next_year_int + 1) || '-01-01');
BEGIN
    EXECUTE 'CREATE TABLE IF NOT EXISTS "lab".parentalsamples_y' || current_year_int || ' PARTITION OF "lab"."parental_samples"
             FOR VALUES FROM (''' || current_year_start_date || ''') TO (''' || current_year_end_date || ''');';

    EXECUTE 'CREATE TABLE IF NOT EXISTS "lab".parentalsamples_y' || next_year_int || ' PARTITION OF "lab"."parental_samples"
             FOR VALUES FROM (''' || next_year_start_date || ''') TO (''' || next_year_end_date || ''');';
END $$;

DO $$
DECLARE -- Re-declare variables here
    current_year_int INTEGER := EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER;
    next_year_int INTEGER := current_year_int + 1;
BEGIN
    PERFORM "lab".create_experiments_partition_if_not_exists_manual(current_year_int);
    PERFORM "lab".create_experiments_partition_if_not_exists_manual(next_year_int);
END $$;

DO $$
DECLARE -- Re-declare variables here
    current_year_int INTEGER := EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER;
    next_year_int INTEGER := current_year_int + 1;
BEGIN
    PERFORM "lab".create_dissections_partition_if_not_exists_manual(current_year_int);
    PERFORM "lab".create_dissections_partition_if_not_exists_manual(next_year_int);
END $$;

DO $$
DECLARE -- Re-declare variables here
    current_year_int INTEGER := EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER;
    next_year_int INTEGER := current_year_int + 1;
BEGIN
    PERFORM "lab".create_extraction_partition_if_not_exists_manual(current_year_int);
    PERFORM "lab".create_extraction_partition_if_not_exists_manual(next_year_int);
END $$;

DO $$
DECLARE -- Re-declare variables here
    current_year_int INTEGER := EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER;
    next_year_int INTEGER := current_year_int + 1;
BEGIN
    PERFORM "lab".create_nanodrop_partition_if_not_exists_manual(current_year_int);
    PERFORM "lab".create_nanodrop_partition_if_not_exists_manual(next_year_int);
END $$;

DO $$
DECLARE -- Re-declare variables here
    current_year_int INTEGER := EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER;
    next_year_int INTEGER := current_year_int + 1;
BEGIN
    PERFORM "lab".create_qubit_partition_if_not_exists_manual(current_year_int);
    PERFORM "lab".create_qubit_partition_if_not_exists_manual(next_year_int);
END $$;

DO $$
DECLARE -- Re-declare variables here
    current_year_int INTEGER := EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER;
    next_year_int INTEGER := current_year_int + 1;
BEGIN
    PERFORM "lab".create_tapestation_partition_if_not_exists_manual(current_year_int);
    PERFORM "lab".create_tapestation_partition_if_not_exists_manual(next_year_int);
END $$;

DO $$
DECLARE -- Re-declare variables here
    current_year_int INTEGER := EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER;
    next_year_int INTEGER := current_year_int + 1;
BEGIN
    PERFORM "lab".create_pcr_partition_if_not_exists_manual(current_year_int);
    PERFORM "lab".create_pcr_partition_if_not_exists_manual(next_year_int);
END $$;

DO $$
DECLARE -- Re-declare variables here
    current_year_int INTEGER := EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER;
    next_year_int INTEGER := current_year_int + 1;
BEGIN
    PERFORM "lab".create_gelelectrophoresis_partition_if_not_exists_manual(current_year_int);
    PERFORM "lab".create_gelelectrophoresis_partition_if_not_exists_manual(next_year_int);
END $$;

DO $$
DECLARE -- Re-declare variables here
    current_year_int INTEGER := EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER;
    next_year_int INTEGER := current_year_int + 1;
BEGIN
    PERFORM "lab".create_qpcr_partition_if_not_exists_manual(current_year_int);
    PERFORM "lab".create_qpcr_partition_if_not_exists_manual(next_year_int);
END $$;

DO $$
DECLARE -- Re-declare variables here
    current_year_int INTEGER := EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER;
    next_year_int INTEGER := current_year_int + 1;
BEGIN
    PERFORM "lab".create_library_partition_if_not_exists_manual(current_year_int);
    PERFORM "lab".create_library_partition_if_not_exists_manual(next_year_int);
END $$;

DO $$
DECLARE -- Re-declare variables here
    current_year_int INTEGER := EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER;
    next_year_int INTEGER := current_year_int + 1;
BEGIN
    PERFORM "lab".create_sequencing_partition_if_not_exists_manual(current_year_int);
    PERFORM "lab".create_sequencing_partition_if_not_exists_manual(next_year_int);
END $$;

DO $$
DECLARE -- Re-declare variables here
    current_year_int INTEGER := EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER;
    next_year_int INTEGER := current_year_int + 1;
BEGIN
    PERFORM "lab".create_datasets_partition_if_not_exists_manual(current_year_int);
    PERFORM "lab".create_datasets_partition_if_not_exists_manual(next_year_int);
END $$;

DO $$
DECLARE -- Re-declare variables here
    current_year_int INTEGER := EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER;
    next_year_int INTEGER := current_year_int + 1;
BEGIN
    PERFORM "lab".create_dna_partition_if_not_exists_manual(current_year_int);
    PERFORM "lab".create_dna_partition_if_not_exists_manual(next_year_int);
END $$;

DO $$
DECLARE -- Re-declare variables here
    current_year_int INTEGER := EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER;
    next_year_int INTEGER := current_year_int + 1;
BEGIN
    PERFORM "lab".create_fish_partition_if_not_exists_manual(current_year_int);
    PERFORM "lab".create_fish_partition_if_not_exists_manual(next_year_int);
END $$;

DO $$
DECLARE -- Re-declare variables here
    current_year_int INTEGER := EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER;
    next_year_int INTEGER := current_year_int + 1;
BEGIN
    PERFORM "lab".create_fishing_partition_if_not_exists_manual(current_year_int);
    PERFORM "lab".create_fishing_partition_if_not_exists_manual(next_year_int);
END $$;


DO $$
DECLARE -- Re-declare variables here
    current_year_int INTEGER := EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER;
    next_year_int INTEGER := current_year_int + 1;
BEGIN
    PERFORM "lab".create_otoliths_partition_if_not_exists_manual(current_year_int);
    PERFORM "lab".create_otoliths_partition_if_not_exists_manual(next_year_int);
END $$;

DO $$
DECLARE -- Re-declare variables here
    current_year_int INTEGER := EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER;
    next_year_int INTEGER := current_year_int + 1;
BEGIN
    PERFORM "lab".create_rna_partition_if_not_exists_manual(current_year_int);
    PERFORM "lab".create_rna_partition_if_not_exists_manual(next_year_int);
END $$;

DO $$
DECLARE -- Re-declare variables here
    current_year_int INTEGER := EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER;
    next_year_int INTEGER := current_year_int + 1;
BEGIN
    PERFORM "lab".create_sediments_partition_if_not_exists_manual(current_year_int);
    PERFORM "lab".create_sediments_partition_if_not_exists_manual(next_year_int);
END $$;

DO $$
DECLARE -- Re-declare variables here
    current_year_int INTEGER := EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER;
    next_year_int INTEGER := current_year_int + 1;
BEGIN
    PERFORM "lab".create_tissue_partition_if_not_exists_manual(current_year_int);
    PERFORM "lab".create_tissue_partition_if_not_exists_manual(next_year_int);
END $$;

DO $$
DECLARE -- Re-declare variables here
    current_year_int INTEGER := EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER;
    next_year_int INTEGER := current_year_int + 1;
BEGIN
    PERFORM "lab".create_water_partition_if_not_exists_manual(current_year_int);
    PERFORM "lab".create_water_partition_if_not_exists_manual(next_year_int);
END $$;

DO $$
DECLARE -- Re-declare variables here
    current_year_int INTEGER := EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER;
    next_year_int INTEGER := current_year_int + 1;
BEGIN
    PERFORM "bioinformatics".create_analysis_runs_partition_if_not_exists_manual(current_year_int);
    PERFORM "bioinformatics".create_analysis_runs_partition_if_not_exists_manual(next_year_int);
END $$;


-- =============================

CREATE OR REPLACE FUNCTION "lab".create_fishing_partition_if_not_exists()
RETURNS TRIGGER AS $$
DECLARE
    partition_date date;
    partition_name text;
    start_date date;
    end_date date;
BEGIN
    partition_date := NEW.sampling_date;
    IF partition_date IS NULL THEN
        RAISE EXCEPTION 'Cannot partition on NULL sampling_date for lab.fishing. Please provide a sampling_date.';
    END IF;

    start_date := DATE_TRUNC('year', partition_date);
    end_date := DATE_TRUNC('year', partition_date) + INTERVAL '1 year';
    partition_name := 'fishing_y' || TO_CHAR(start_date, 'YYYY');

    EXECUTE 'CREATE TABLE IF NOT EXISTS "lab".' || quote_ident(partition_name) || ' PARTITION OF "lab"."fishing"
             FOR VALUES FROM (''' || start_date || ''') TO (''' || end_date || ''');';

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

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



-- ======================================================================
-- 16. Row-Level Security (RLS) Policies
-- ======================================================================

ALTER TABLE "lims"."projects" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "lab"."parental_samples" ENABLE ROW LEVEL SECURITY;

CREATE POLICY project_membership_policy ON "lims"."projects"
FOR SELECT
USING ("lims".is_member_of_project(project_id));

CREATE POLICY sample_project_membership_policy ON "lab"."parental_samples"
FOR SELECT
USING ("lims".is_member_of_project(project_id));

-- ======================================================================
-- 17. Advanced JSONB and ltree Query Examples
-- ======================================================================

-- Querying JSONB data from the Dissections table
SELECT dissection_id, sample_id, stomach_contents_jsonb
FROM "lab"."dissections"
WHERE stomach_contents_jsonb ? 'item';

SELECT dissection_id, sample_id, stomach_contents_jsonb->>'item' AS item_name
FROM "lab"."dissections"
WHERE stomach_contents_jsonb @> '[{"item": "shrimp"}]'::jsonb;

SELECT dissection_id, sample_id, jsonb_array_elements(stomach_contents_jsonb) ->> 'quantity' AS quantity_of_item
FROM "lab"."dissections"
WHERE stomach_contents_jsonb @> '[{"item": "fish"}]'::jsonb;

-- Example of querying nested JSONB: assuming 'parameters_jsonb' in 'bioinformatics.analysis_runs'
-- SELECT run_id, parameters_jsonb->>'alignment_tool_version' AS tool_version
-- FROM "bioinformatics"."analysis_runs"
-- WHERE parameters_jsonb @> '{"pipeline_settings": {"min_quality": 30}}'::jsonb;

-- Update ltree paths (run after initial taxon data load)
SELECT "reference".update_taxon_ltree_paths();

-- Find all taxa belonging to the family 'Gadidae' (assuming 'Gadidae' is a taxon_id)
SELECT * FROM "reference"."taxon"
WHERE path <@ (SELECT path FROM "reference"."taxon" WHERE taxon_id = 'Gadidae');

-- Find the full lineage of 'Gadus morhua' (Atlantic Cod)
SELECT * FROM "reference"."taxon"
WHERE path @> (SELECT path FROM "reference"."taxon" WHERE taxon_id = 'Gadus morhua')
ORDER BY path;

-- Find all children directly under 'Animalia' (direct descendants)
SELECT taxon_id, de_name, en_name
FROM "reference"."taxon"
WHERE nlevel(path) = nlevel('Animalia'::ltree) + 1
  AND path <@ 'Animalia'::ltree;

-- Find common ancestor of two taxa
-- SELECT lca('Chordata'::ltree, 'Arthropoda'::ltree);

-- Additional JSONB Query Examples
-- Querying for keys in a JSONB object
SELECT run_id, parameters_jsonb
FROM "bioinformatics"."analysis_runs"
WHERE parameters_jsonb ? 'kmer_size';

-- Querying for existence of a key-value pair
SELECT run_id, parameters_jsonb
FROM "bioinformatics"."analysis_runs"
WHERE parameters_jsonb @> '{"quality_filter": true}'::jsonb;

-- Extracting a specific value from a nested JSONB object
SELECT run_id, parameters_jsonb->'processing'->>'trim_length' AS trim_length_setting
FROM "bioinformatics"."analysis_runs"
WHERE parameters_jsonb->'processing' ? 'trim_length';

-- Aggregating JSONB data
-- SELECT jsonb_object_agg(run_id, parameters_jsonb) FROM "bioinformatics"."analysis_runs";

-- Additional ltree Query Examples
-- Find all descendants of a specific path (e.g., all species under 'Chordata.Vertebrata')
-- SELECT taxon_id, en_name FROM "reference"."taxon" WHERE path ~ 'Chordata.Vertebrata.*'::ltree;

-- Find direct parents of a specific taxon
-- SELECT t2.taxon_id, t2.en_name
-- FROM "reference"."taxon" t1
-- JOIN "reference"."taxon" t2 ON t1.path @> t2.path AND nlevel(t1.path) = nlevel(t2.path) + 1
-- WHERE t1.taxon_id = 'Gadus morhua';

-- Find all ancestors of a specific taxon
-- SELECT t2.taxon_id, t2.en_name
-- FROM "reference"."taxon" t1
-- JOIN "reference"."taxon" t2 ON t1.path <@ t2.path
-- WHERE t1.taxon_id = 'Gadus morhua'
-- ORDER BY nlevel(t2.path) DESC;


-- ======================================================================
-- 18. Foreign Data Wrappers (FDW) Examples
-- ======================================================================

-- CREATE SERVER IF NOT EXISTS foreign_lims_server
-- FOREIGN DATA WRAPPER postgres_fdw
-- OPTIONS (host 'foreign_host', port '5432', dbname 'foreign_lims_db');

-- CREATE USER MAPPING IF NOT EXISTS FOR CURRENT_USER
-- SERVER foreign_lims_server
-- OPTIONS (user 'foreign_user', password 'foreign_password');

-- CREATE FOREIGN TABLE IF NOT EXISTS "lims"."foreign_projects" (
--      "project_id" text NOT NULL,
--      "title" text,
--      "start_date" date,
--      "end_date" date
-- )
-- SERVER foreign_lims_server
-- OPTIONS (schema_name 'lims', table_name 'projects');

-- SELECT * FROM "lims"."foreign_projects" WHERE "title" LIKE '%External%';

-- ======================================================================
-- 19. Aggregates Examples
-- ======================================================================

SELECT
    st.sample_type_id,
    COUNT(s.sample_id) AS total_samples
FROM
    "reference"."samples_type" st
LEFT JOIN
    "lab"."parental_samples" s ON st.sample_type_id = s.sample_type_id
GROUP BY
    st.sample_type_id
ORDER BY
    total_samples DESC;

SELECT
    extraction_method,
    AVG(concentration_ng_ul) AS average_concentration_ng_ul
FROM
    "lab"."dna"
WHERE
    concentration_ng_ul IS NOT NULL
GROUP BY
    extraction_method
HAVING
    COUNT(concentration_ng_ul) > 1
ORDER BY
    average_concentration_ng_ul DESC;

SELECT
    EXTRACT(YEAR FROM reception_date) AS reception_year,
    COUNT(sample_id) AS samples_received
FROM
    "lab"."parental_samples"
WHERE
    reception_date IS NOT NULL
GROUP BY
    reception_year
ORDER BY
    reception_year;

SELECT
    cs.species_en_name,
    MAX(f.total_length_mm) AS max_length_mm,
    MIN(f.total_length_mm) AS min_length_mm,
    AVG(f.weight_g) AS avg_weight_g
FROM
    "lab"."fish" f
JOIN
    "reference"."complete_species_taxon_view" cs ON f.species_id = cs.species_id
GROUP BY
    cs.species_en_name
ORDER BY
    max_length_mm DESC;

-- ======================================================================
-- 20. Add Deferred Foreign Key Constraints and Unique Constraints
-- ======================================================================

ALTER TABLE "reference"."taxon"
ADD CONSTRAINT "taxon_parent_fk" FOREIGN KEY ("taxon_parent")
REFERENCES "reference"."taxon"("taxon_id");

ALTER TABLE "reference"."species"
ADD CONSTRAINT "species_taxon_id_fk" FOREIGN KEY ("species_id")
REFERENCES "reference"."taxon"("taxon_id");

ALTER TABLE "lims"."projects"
ADD CONSTRAINT "projects_status_id_fk" FOREIGN KEY ("status_id")
REFERENCES "reference"."status"("status_id");

ALTER TABLE "lims"."projects"
ADD CONSTRAINT "projects_pi_person_id_fk" FOREIGN KEY ("pi_person_id")
REFERENCES "reference"."personal"("person_id");

ALTER TABLE "lims"."projects"
ADD CONSTRAINT "projects_customer_id_fk" FOREIGN KEY ("customer_id")
REFERENCES "lims"."customers"("customer_id");

ALTER TABLE "lims"."project_persons"
ADD CONSTRAINT "project_persons_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id") ON DELETE CASCADE;

ALTER TABLE "lims"."project_persons"
ADD CONSTRAINT "project_persons_person_id_fk" FOREIGN KEY ("person_id")
REFERENCES "reference"."personal"("person_id") ON DELETE CASCADE;

ALTER TABLE "lims"."cruises"
ADD CONSTRAINT "cruises_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id") ON DELETE CASCADE;

ALTER TABLE "lims"."cruises"
ADD CONSTRAINT "cruises_vessel_id_fk" FOREIGN KEY ("vessel_id")
REFERENCES "reference"."vessel"("vessel_id");

ALTER TABLE "lims"."cruises"
ADD CONSTRAINT "cruises_status_id_fk" FOREIGN KEY ("status_id")
REFERENCES "reference"."status"("status_id");

ALTER TABLE "lims"."cruises"
ADD CONSTRAINT "cruises_region_id_fk" FOREIGN KEY ("region_id")
REFERENCES "reference"."region"("region_id");

ALTER TABLE "lims"."cruises"
ADD CONSTRAINT "cruises_ecosystem_id_fk" FOREIGN KEY ("ecosystem_id")
REFERENCES "reference"."ecosystem"("ecosystem_id");

ALTER TABLE "lims"."cruises"
ADD CONSTRAINT "cruises_capitaine_contact_id_fk" FOREIGN KEY ("capitaine_contact_id")
REFERENCES "lims"."external_contacts"("contact_id");

ALTER TABLE "lims"."cruises"
ADD CONSTRAINT "cruises_chief_scientist_person_id_fk" FOREIGN KEY ("chief_scientist_person_id")
REFERENCES "reference"."personal"("person_id");

ALTER TABLE "lims"."cruises"
ADD CONSTRAINT "cruises_together_with_contact_id_fk" FOREIGN KEY ("together_with_contact_id")
REFERENCES "lims"."external_contacts"("contact_id");

ALTER TABLE "lims"."workflow_steps"
ADD CONSTRAINT "workflow_steps_workflow_id_fk" FOREIGN KEY ("workflow_id")
REFERENCES "lims"."workflows"("workflow_id") ON DELETE CASCADE;

ALTER TABLE "lims"."workflow_steps"
ADD CONSTRAINT "workflow_steps_sop_id_fk" FOREIGN KEY ("sop_id")
REFERENCES "lims"."sop"("sop_id");

ALTER TABLE "lims"."workflow_steps"
ADD CONSTRAINT "workflow_steps_workflow_status_id_fk" FOREIGN KEY ("workflow_status_id")
REFERENCES "reference"."status"("status_id");

ALTER TABLE "lims"."primers"
ADD CONSTRAINT "primers_target_gene_id_fk" FOREIGN KEY ("target_gene_id")
REFERENCES "reference"."gene"("gene_id");

ALTER TABLE "lims"."sop"
ADD CONSTRAINT "sop_author_person_id_fk" FOREIGN KEY ("author_person_id")
REFERENCES "reference"."personal"("person_id");

ALTER TABLE "lims"."sop"
ADD CONSTRAINT "sop_reviewer1_person_id_fk" FOREIGN KEY ("reviewer1_person_id")
REFERENCES "reference"."personal"("person_id");

ALTER TABLE "lims"."sop"
ADD CONSTRAINT "sop_reviewer2_person_id_fk" FOREIGN KEY ("reviewer2_person_id")
REFERENCES "reference"."personal"("person_id");

ALTER TABLE "lims"."equipment"
ADD CONSTRAINT "equipment_room_id_fk" FOREIGN KEY ("room_id")
REFERENCES "reference"."room"("room_id");

ALTER TABLE "lims"."inventory_items"
ADD CONSTRAINT "inventory_items_category_id_fk" FOREIGN KEY ("category_id")
REFERENCES "reference"."category"("category_id");

ALTER TABLE "lims"."inventory_items"
ADD CONSTRAINT "inventory_items_unit_id_fk" FOREIGN KEY ("unit_id")
REFERENCES "reference"."units"("unit_id");

ALTER TABLE "lims"."orders"
ADD CONSTRAINT "orders_item_id_fk" FOREIGN KEY ("item_id")
REFERENCES "lims"."inventory_items"("item_id");

ALTER TABLE "lims"."orders"
ADD CONSTRAINT "orders_category_id_fk" FOREIGN KEY ("category_id")
REFERENCES "reference"."category"("category_id");

ALTER TABLE "lims"."orders"
ADD CONSTRAINT "orders_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id");

ALTER TABLE "lims"."orders"
ADD CONSTRAINT "orders_supplier_id_fk" FOREIGN KEY ("supplier_id")
REFERENCES "lims"."suppliers"("supplier_id");

ALTER TABLE "lims"."orders"
ADD CONSTRAINT "orders_status_id_fk" FOREIGN KEY ("status_id")
REFERENCES "reference"."status"("status_id");

ALTER TABLE "lims"."reagents"
ADD CONSTRAINT "reagents_category_id_fk" FOREIGN KEY ("category_id")
REFERENCES "reference"."category"("category_id");

ALTER TABLE "lims"."reagents"
ADD CONSTRAINT "reagents_storage_id_fk" FOREIGN KEY ("storage_id")
REFERENCES "lab"."storage"("storage_id");

ALTER TABLE "lims"."reagents"
ADD CONSTRAINT "reagents_status_id_fk" FOREIGN KEY ("status_id")
REFERENCES "reference"."status"("status_id");

ALTER TABLE "lims"."reagents"
ADD CONSTRAINT "reagents_order_id_fk" FOREIGN KEY ("order_id")
REFERENCES "lims"."orders"("fi_order_nr");

ALTER TABLE "lims"."reagents"
ADD CONSTRAINT "reagents_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id");

ALTER TABLE "lims"."reagents"
ADD CONSTRAINT "reagents_quantity_unit_id_fk" FOREIGN KEY ("quantity_unit_id")
REFERENCES "reference"."units"("unit_id");

ALTER TABLE "lims"."publications"
ADD CONSTRAINT "publications_publication_type_id_fk" FOREIGN KEY ("publication_type_id")
REFERENCES "lims"."publication_type"("publication_type_id");

ALTER TABLE "lims"."publications"
ADD CONSTRAINT "publications_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id");

ALTER TABLE "lims"."publications"
ADD CONSTRAINT "publications_first_author_person_id_fk" FOREIGN KEY ("first_author_person_id")
REFERENCES "reference"."personal"("person_id");

ALTER TABLE "lims"."publications"
ADD CONSTRAINT "publications_corresponding_author_person_id_fk" FOREIGN KEY ("corresponding_author_person_id")
REFERENCES "reference"."personal"("person_id");

ALTER TABLE "lab"."storage"
ADD CONSTRAINT "storage_room_id_fk" FOREIGN KEY ("room_id")
REFERENCES "reference"."room"("room_id");

ALTER TABLE "lab"."storage"
ADD CONSTRAINT "storage_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id");

ALTER TABLE "lab"."experiments_projects"
ADD CONSTRAINT "experiments_projects_experiment_fk" FOREIGN KEY ("experiment_id", "experiment_date")
REFERENCES "lab"."experiments"("experiment_id", "experiment_date");

ALTER TABLE "lab"."experiments_projects"
ADD CONSTRAINT "experiments_projects_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id");

ALTER TABLE "lab"."protocol_runs"
ADD CONSTRAINT "protocol_runs_experiment_fk" FOREIGN KEY ("experiment_id", "experiment_date")
REFERENCES "lab"."experiments"("experiment_id", "experiment_date");

ALTER TABLE "lab"."protocol_runs"
ADD CONSTRAINT "protocol_runs_sop_id_fk" FOREIGN KEY ("sop_id")
REFERENCES "lims"."sop"("sop_id");

ALTER TABLE "lab"."protocol_runs"
ADD CONSTRAINT "protocol_runs_person_id_fk" FOREIGN KEY ("person_id")
REFERENCES "reference"."personal"("person_id");

ALTER TABLE "lab"."sampling"
ADD CONSTRAINT "sampling_experiment_fk" FOREIGN KEY ("experiment_id", "experiment_date")
REFERENCES "lab"."experiments"("experiment_id", "experiment_date");

ALTER TABLE "lab"."sampling"
ADD CONSTRAINT "sampling_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id") ON DELETE CASCADE;

ALTER TABLE "lab"."sampling"
ADD CONSTRAINT "sampling_cruise_id_fk" FOREIGN KEY ("cruise_id")
REFERENCES "lims"."cruises"("cruise_id");

ALTER TABLE "lab"."sampling"
ADD CONSTRAINT "sampling_region_id_fk" FOREIGN KEY ("region_id")
REFERENCES "reference"."region"("region_id");

ALTER TABLE "lab"."sampling"
ADD CONSTRAINT "sampling_ecosystem_id_fk" FOREIGN KEY ("ecosystem_id")
REFERENCES "reference"."ecosystem"("ecosystem_id");

ALTER TABLE "lab"."sampling"
ADD CONSTRAINT "sampling_vessel_id_fk" FOREIGN KEY ("vessel_id")
REFERENCES "reference"."vessel"("vessel_id");

ALTER TABLE "lab"."sampling"
ADD CONSTRAINT "sampling_customer_id_fk" FOREIGN KEY ("customer_id")
REFERENCES "lims"."customers"("customer_id");

ALTER TABLE "lab"."sampling"
ADD CONSTRAINT "sampling_wind_unit_id_fk" FOREIGN KEY ("wind_unit_id")
REFERENCES "reference"."units"("unit_id");

ALTER TABLE "lab"."sampling"
ADD CONSTRAINT "sampling_salinity_unit_id_fk" FOREIGN KEY ("salinity_unit_id")
REFERENCES "reference"."units"("unit_id");

ALTER TABLE "lab"."sampling"
ADD CONSTRAINT "sampling_pressure_unit_id_fk" FOREIGN KEY ("pressure_unit_id")
REFERENCES "reference"."units"("unit_id");

ALTER TABLE "lab"."sampling"
ADD CONSTRAINT "sampling_oxygen_unit_id_fk" FOREIGN KEY ("oxygen_unit_id")
REFERENCES "reference"."units"("unit_id");

ALTER TABLE "lab"."sampling"
ADD CONSTRAINT "sampling_conductivity_unit_id_fk" FOREIGN KEY ("conductivity_unit_id")
REFERENCES "reference"."units"("unit_id");

ALTER TABLE "lab"."sampling"
ADD CONSTRAINT "sampling_sample_type_id_fk" FOREIGN KEY ("sample_type_id")
REFERENCES "reference"."samples_type"("sample_type_id");

ALTER TABLE "lab"."sampling"
ADD CONSTRAINT "sampling_soak_time_unit_id_fk" FOREIGN KEY ("soak_time_unit_id")
REFERENCES "reference"."units"("unit_id");

ALTER TABLE "lab"."sampling"
ADD CONSTRAINT "sampling_trawl_speed_unit_id_fk" FOREIGN KEY ("trawl_speed_unit_id")
REFERENCES "reference"."units"("unit_id");

ALTER TABLE "lab"."sampling"
ADD CONSTRAINT "sampling_together_with_contact_id_fk" FOREIGN KEY ("together_with_contact_id")
REFERENCES "lims"."external_contacts"("contact_id");

ALTER TABLE "lab"."sampling"
ADD CONSTRAINT "sampling_status_id_fk" FOREIGN KEY ("status_id")
REFERENCES "reference"."status"("status_id");

ALTER TABLE "lab"."fishing"
ADD CONSTRAINT "fishing_sampling_fk" FOREIGN KEY ("sampling_id", "sampling_date")
REFERENCES "lab"."sampling"("sampling_id", "sampling_date") ON DELETE CASCADE;

ALTER TABLE "lab"."fishing"
ADD CONSTRAINT "fishing_taxon_id_fk" FOREIGN KEY ("taxon_id")
REFERENCES "reference"."taxon"("taxon_id");

ALTER TABLE "lab"."fishing"
ADD CONSTRAINT "fishing_customer_id_fk" FOREIGN KEY ("customer_id")
REFERENCES "lims"."customers"("customer_id");

ALTER TABLE "lab"."parental_samples"
ADD CONSTRAINT "samples_master_sample_id_fk" FOREIGN KEY ("sample_id")
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."parental_samples"
ADD CONSTRAINT "samples_parent_sample_id_fk" FOREIGN KEY ("parent_sample_id")
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."parental_samples"
ADD CONSTRAINT "samples_sampling_fk" FOREIGN KEY ("sampling_id", "sampling_date")
REFERENCES "lab"."sampling"("sampling_id", "sampling_date");

ALTER TABLE "lab"."parental_samples"
ADD CONSTRAINT "samples_storage_id_fk" FOREIGN KEY ("storage_id")
REFERENCES "lab"."storage"("storage_id");

ALTER TABLE "lab"."parental_samples"
ADD CONSTRAINT "samples_sampler_person_id_fk" FOREIGN KEY ("sampler_person_id")
REFERENCES "reference"."personal"("person_id");

ALTER TABLE "lab"."parental_samples"
ADD CONSTRAINT "samples_receiver_person_id_fk" FOREIGN KEY ("receiver_person_id")
REFERENCES "reference"."personal"("person_id");

ALTER TABLE "lab"."parental_samples"
ADD CONSTRAINT "samples_sample_type_id_fk" FOREIGN KEY ("sample_type_id")
REFERENCES "reference"."samples_type"("sample_type_id");

ALTER TABLE "lab"."parental_samples"
ADD CONSTRAINT "samples_sample_status_id_fk" FOREIGN KEY ("sample_status_id")
REFERENCES "reference"."status"("status_id");

ALTER TABLE "lab"."parental_samples"
ADD CONSTRAINT "samples_workflow_id_fk" FOREIGN KEY ("workflow_id")
REFERENCES "lims"."workflows"("workflow_id");

ALTER TABLE "lab"."parental_samples"
ADD CONSTRAINT "samples_step_id_fk" FOREIGN KEY ("step_id")
REFERENCES "lims"."workflow_steps"("step_id");

ALTER TABLE "lab"."parental_samples"
ADD CONSTRAINT "samples_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id");

ALTER TABLE "lab"."parental_samples"
ADD CONSTRAINT "samples_customer_id_fk" FOREIGN KEY ("customer_id")
REFERENCES "lims"."customers"("customer_id");

ALTER TABLE "lab"."storage_log"
ADD CONSTRAINT "storage_log_sample_fk" FOREIGN KEY ("sample_id", "sample_sampling_date")
REFERENCES "lab"."parental_samples"("sample_id", "sampling_date");

ALTER TABLE "lab"."storage_log"
ADD CONSTRAINT "storage_log_storage_id_fk" FOREIGN KEY ("storage_id")
REFERENCES "lab"."storage"("storage_id");

ALTER TABLE "lab"."storage_log"
ADD CONSTRAINT "storage_log_person_id_fk" FOREIGN KEY ("person_id")
REFERENCES "reference"."personal"("person_id");


ALTER TABLE "lab"."fish"
ADD CONSTRAINT "fish_sample_id_fk" FOREIGN KEY ("sample_id")
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."fish"
ADD CONSTRAINT "fish_parent_sample_id_fk" FOREIGN KEY ("parent_sample_id")
REFERENCES "lab"."master_samples"("sample_id");

-- This FK now links to lab.sampling using sampling_id and sampling_date
ALTER TABLE "lab"."fish"
ADD CONSTRAINT "fish_sampling_fk" FOREIGN KEY ("sampling_id", "sampling_date")
REFERENCES "lab"."sampling"("sampling_id", "sampling_date");

ALTER TABLE "lab"."fish"
ADD CONSTRAINT "fish_species_id_fk" FOREIGN KEY ("species_id")
REFERENCES "reference"."species"("species_id");

ALTER TABLE "lab"."fish"
ADD CONSTRAINT "fish_storage_id_fk" FOREIGN KEY ("storage_id")
REFERENCES "lab"."storage"("storage_id");

ALTER TABLE "lab"."fish"
ADD CONSTRAINT "fish_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id");

ALTER TABLE "lab"."fish"
ADD CONSTRAINT "fish_customer_id_fk" FOREIGN KEY ("customer_id")
REFERENCES "lims"."customers"("customer_id");


ALTER TABLE "lab"."fish"
ADD CONSTRAINT "fish_experiment_fk" FOREIGN KEY ("experiment_id", "experiment_date")
REFERENCES "lab"."experiments"("experiment_id", "experiment_date");

ALTER TABLE "lab"."tissue"
ADD CONSTRAINT "tissue_sample_id_fk" FOREIGN KEY ("sample_id")
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."tissue"
ADD CONSTRAINT "tissue_parent_sample_id_fk" FOREIGN KEY ("parent_sample_id")
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."tissue"
ADD CONSTRAINT "tissue_experiment_fk" FOREIGN KEY ("experiment_id", "experiment_date")
REFERENCES "lab"."experiments"("experiment_id", "experiment_date");

ALTER TABLE "lab"."tissue"
ADD CONSTRAINT "tissue_storage_id_fk" FOREIGN KEY ("storage_id")
REFERENCES "lab"."storage"("storage_id");

ALTER TABLE "lab"."tissue"
ADD CONSTRAINT "tissue_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id");

ALTER TABLE "lab"."otoliths"
ADD CONSTRAINT "otoliths_sample_id_fk" FOREIGN KEY ("sample_id")
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."otoliths"
ADD CONSTRAINT "otoliths_reader_person_id_fk" FOREIGN KEY ("reader_person_id")
REFERENCES "reference"."personal"("person_id");

ALTER TABLE "lab"."otoliths"
ADD CONSTRAINT "otoliths_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id");

ALTER TABLE "lab"."dna"
ADD CONSTRAINT "dna_sample_id_fk" FOREIGN KEY ("sample_id")
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."dna"
ADD CONSTRAINT "dna_parent_sample_id_fk" FOREIGN KEY ("parent_sample_id")
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."dna"
ADD CONSTRAINT "dna_experiment_fk" FOREIGN KEY ("experiment_id", "experiment_date")
REFERENCES "lab"."experiments"("experiment_id", "experiment_date");

ALTER TABLE "lab"."dna"
ADD CONSTRAINT "dna_storage_id_fk" FOREIGN KEY ("storage_id")
REFERENCES "lab"."storage"("storage_id");

ALTER TABLE "lab"."dna"
ADD CONSTRAINT "dna_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id");

ALTER TABLE "lab"."rna"
ADD CONSTRAINT "rna_sample_id_fk" FOREIGN KEY ("sample_id")
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."rna"
ADD CONSTRAINT "rna_parent_sample_id_fk" FOREIGN KEY ("parent_sample_id")
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."rna"
ADD CONSTRAINT "rna_experiment_fk" FOREIGN KEY ("experiment_id", "experiment_date")
REFERENCES "lab"."experiments"("experiment_id", "experiment_date");

ALTER TABLE "lab"."rna"
ADD CONSTRAINT "rna_storage_id_fk" FOREIGN KEY ("storage_id")
REFERENCES "lab"."storage"("storage_id");

ALTER TABLE "lab"."rna"
ADD CONSTRAINT "rna_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id");

ALTER TABLE "lab"."sediments"
ADD CONSTRAINT "sediments_sample_id_fk" FOREIGN KEY ("sample_id")
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."sediments"
ADD CONSTRAINT "sediments_parent_sample_id_fk" FOREIGN KEY ("parent_sample_id")
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."sediments"
ADD CONSTRAINT "sediments_experiment_fk" FOREIGN KEY ("experiment_id", "experiment_date")
REFERENCES "lab"."experiments"("experiment_id", "experiment_date");

ALTER TABLE "lab"."sediments"
ADD CONSTRAINT "sediments_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id");

ALTER TABLE "lab"."sediments"
ADD CONSTRAINT "sediments_volume_unit_id_fk" FOREIGN KEY ("volume_unit_id")
REFERENCES "reference"."units"("unit_id");

ALTER TABLE "lab"."sediments"
ADD CONSTRAINT "sediments_storage_id_fk" FOREIGN KEY ("storage_id")
REFERENCES "lab"."storage"("storage_id");

ALTER TABLE "lab"."water"
ADD CONSTRAINT "water_sample_id_fk" FOREIGN KEY ("sample_id")
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."water"
ADD CONSTRAINT "water_parent_sample_id_fk" FOREIGN KEY ("parent_sample_id")
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."water"
ADD CONSTRAINT "water_experiment_fk" FOREIGN KEY ("experiment_id", "experiment_date")
REFERENCES "lab"."experiments"("experiment_id", "experiment_date");

ALTER TABLE "lab"."water"
ADD CONSTRAINT "water_storage_id_fk" FOREIGN KEY ("storage_id")
REFERENCES "lab"."storage"("storage_id");

ALTER TABLE "lab"."water"
ADD CONSTRAINT "water_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id");

ALTER TABLE "lab"."experiments_samples"
ADD CONSTRAINT "experiments_samples_experiment_fk" FOREIGN KEY ("experiment_id", "experiment_date")
REFERENCES "lab"."experiments"("experiment_id", "experiment_date");

ALTER TABLE "lab"."experiments_samples"
ADD CONSTRAINT "experiments_samples_sample_id_fk" FOREIGN KEY ("sample_id")
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."dissections"
ADD CONSTRAINT "dissections_sample_id_fk" FOREIGN KEY ("sample_id")
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."dissections"
ADD CONSTRAINT "dissections_person_id_fk" FOREIGN KEY ("person_id")
REFERENCES "reference"."personal"("person_id");

ALTER TABLE "lab"."dissections"
ADD CONSTRAINT "dissections_status_id_fk" FOREIGN KEY ("status_id")
REFERENCES "reference"."status"("status_id");

ALTER TABLE "lab"."extraction"
ADD CONSTRAINT "extraction_experiment_fk" FOREIGN KEY ("experiment_id", "experiment_date")
REFERENCES "lab"."experiments"("experiment_id", "experiment_date");

ALTER TABLE "lab"."extraction"
ADD CONSTRAINT "extraction_sample_id_fk" FOREIGN KEY ("sample_id")
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."extraction"
ADD CONSTRAINT "extraction_parent_sample_id_fk" FOREIGN KEY ("parent_sample_id")
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."extraction"
ADD CONSTRAINT "extraction_sample_type_id_fk" FOREIGN KEY ("sample_type_id")
REFERENCES "reference"."samples_type"("sample_type_id");

ALTER TABLE "lab"."extraction"
ADD CONSTRAINT "extraction_extracted_dna_sample_id_fk" FOREIGN KEY ("extracted_dna_sample_id")
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."extraction"
ADD CONSTRAINT "extraction_extracted_rna_sample_id_fk" FOREIGN KEY ("extracted_rna_sample_id")
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."extraction"
ADD CONSTRAINT "extraction_person_id_fk" FOREIGN KEY ("person_id")
REFERENCES "reference"."personal"("person_id");

ALTER TABLE "lab"."extraction"
ADD CONSTRAINT "extraction_status_id_fk" FOREIGN KEY ("status_id")
REFERENCES "reference"."status"("status_id");

ALTER TABLE "lab"."extraction"
ADD CONSTRAINT "extraction_storage_id_fk" FOREIGN KEY ("storage_id")
REFERENCES "lab"."storage"("storage_id");

ALTER TABLE "lab"."extraction"
ADD CONSTRAINT "extraction_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id");

ALTER TABLE "lab"."nanodrop"
ADD CONSTRAINT "nanodrop_experiment_fk" FOREIGN KEY ("experiment_id", "experiment_date")
REFERENCES "lab"."experiments"("experiment_id", "experiment_date");

ALTER TABLE "lab"."nanodrop"
ADD CONSTRAINT "nanodrop_sample_id_fk" FOREIGN KEY ("sample_id")
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."nanodrop"
ADD CONSTRAINT "nanodrop_concentration_unit_id_fk" FOREIGN KEY ("concentration_unit_id")
REFERENCES "reference"."units"("unit_id");

ALTER TABLE "lab"."nanodrop"
ADD CONSTRAINT "nanodrop_person_id_fk" FOREIGN KEY ("person_id")
REFERENCES "reference"."personal"("person_id");

ALTER TABLE "lab"."nanodrop"
ADD CONSTRAINT "nanodrop_status_id_fk" FOREIGN KEY ("status_id")
REFERENCES "reference"."status"("status_id");

ALTER TABLE "lab"."nanodrop"
ADD CONSTRAINT "nanodrop_storage_id_fk" FOREIGN KEY ("storage_id")
REFERENCES "lab"."storage"("storage_id");

ALTER TABLE "lab"."nanodrop"
ADD CONSTRAINT "nanodrop_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id");

ALTER TABLE "lab"."qubit"
ADD CONSTRAINT "qubit_sample_id_fk" FOREIGN KEY ("sample_id")
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."qubit"
ADD CONSTRAINT "qubit_experiment_fk" FOREIGN KEY ("experiment_id", "experiment_date")
REFERENCES "lab"."experiments"("experiment_id", "experiment_date");

ALTER TABLE "lab"."qubit"
ADD CONSTRAINT "qubit_tube_unit_id_fk" FOREIGN KEY ("tube_unit_id")
REFERENCES "reference"."units"("unit_id");

ALTER TABLE "lab"."qubit"
ADD CONSTRAINT "qubit_original_sample_unit_id_fk" FOREIGN KEY ("original_sample_unit_id")
REFERENCES "reference"."units"("unit_id");

ALTER TABLE "lab"."qubit"
ADD CONSTRAINT "qubit_person_id_fk" FOREIGN KEY ("person_id")
REFERENCES "reference"."personal"("person_id");

ALTER TABLE "lab"."qubit"
ADD CONSTRAINT "qubit_status_id_fk" FOREIGN KEY ("status_id")
REFERENCES "reference"."status"("status_id");

ALTER TABLE "lab"."qubit"
ADD CONSTRAINT "qubit_storage_id_fk" FOREIGN KEY ("storage_id")
REFERENCES "lab"."storage"("storage_id");

ALTER TABLE "lab"."qubit"
ADD CONSTRAINT "qubit_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id");

ALTER TABLE "lab"."tapestation"
ADD CONSTRAINT "tapestation_experiment_fk" FOREIGN KEY ("experiment_id", "experiment_date")
REFERENCES "lab"."experiments"("experiment_id", "experiment_date");

ALTER TABLE "lab"."tapestation"
ADD CONSTRAINT "tapestation_person_id_fk" FOREIGN KEY ("person_id")
REFERENCES "reference"."personal"("person_id");

ALTER TABLE "lab"."tapestation"
ADD CONSTRAINT "tapestation_sample_id_fk" FOREIGN KEY ("sample_id")
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."tapestation"
ADD CONSTRAINT "tapestation_storage_id_fk" FOREIGN KEY ("storage_id")
REFERENCES "lab"."storage"("storage_id");

ALTER TABLE "lab"."tapestation"
ADD CONSTRAINT "tapestation_status_id_fk" FOREIGN KEY ("status_id")
REFERENCES "reference"."status"("status_id");

ALTER TABLE "lab"."tapestation"
ADD CONSTRAINT "tapestation_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id");

ALTER TABLE "lab"."pcr"
ADD CONSTRAINT "pcr_experiment_fk" FOREIGN KEY ("experiment_id", "experiment_date")
REFERENCES "lab"."experiments"("experiment_id", "experiment_date");

ALTER TABLE "lab"."pcr"
ADD CONSTRAINT "pcr_sample_id_fk" FOREIGN KEY ("sample_id")
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."pcr"
ADD CONSTRAINT "pcr_primer_id_fk" FOREIGN KEY ("primer_id")
REFERENCES "lims"."primers"("primer_id");

ALTER TABLE "lab"."pcr"
ADD CONSTRAINT "pcr_person_id_fk" FOREIGN KEY ("person_id")
REFERENCES "reference"."personal"("person_id");

ALTER TABLE "lab"."pcr"
ADD CONSTRAINT "pcr_storage_id_fk" FOREIGN KEY ("storage_id")
REFERENCES "lab"."storage"("storage_id");

ALTER TABLE "lab"."pcr"
ADD CONSTRAINT "pcr_status_id_fk" FOREIGN KEY ("status_id")
REFERENCES "reference"."status"("status_id");

ALTER TABLE "lab"."pcr"
ADD CONSTRAINT "pcr_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id");

ALTER TABLE "lab"."gelelectrophoresis"
ADD CONSTRAINT "gelelectrophoresis_experiment_fk" FOREIGN KEY ("experiment_id", "experiment_date")
REFERENCES "lab"."experiments"("experiment_id", "experiment_date");

ALTER TABLE "lab"."gelelectrophoresis"
ADD CONSTRAINT "gelelectrophoresis_sample_id_fk" FOREIGN KEY ("sample_id")
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."gelelectrophoresis"
ADD CONSTRAINT "gelelectrophoresis_person_id_fk" FOREIGN KEY ("person_id")
REFERENCES "reference"."personal"("person_id");

ALTER TABLE "lab"."gelelectrophoresis"
ADD CONSTRAINT "gelelectrophoresis_storage_id_fk" FOREIGN KEY ("storage_id")
REFERENCES "lab"."storage"("storage_id");

ALTER TABLE "lab"."gelelectrophoresis"
ADD CONSTRAINT "gelelectrophoresis_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id");

ALTER TABLE "lab"."qpcr"
ADD CONSTRAINT "qpcr_experiment_fk" FOREIGN KEY ("experiment_id", "experiment_date")
REFERENCES "lab"."experiments"("experiment_id", "experiment_date");

ALTER TABLE "lab"."qpcr"
ADD CONSTRAINT "qpcr_sample_id_fk" FOREIGN KEY ("sample_id")
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."qpcr"
ADD CONSTRAINT "qpcr_person_id_fk" FOREIGN KEY ("person_id")
REFERENCES "reference"."personal"("person_id");

ALTER TABLE "lab"."qpcr"
ADD CONSTRAINT "qpcr_primer_id_fk" FOREIGN KEY ("primer_id")
REFERENCES "lims"."primers"("primer_id");

ALTER TABLE "lab"."qpcr"
ADD CONSTRAINT "qpcr_storage_id_fk" FOREIGN KEY ("storage_id")
REFERENCES "lab"."storage"("storage_id");

ALTER TABLE "lab"."qpcr"
ADD CONSTRAINT "qpcr_status_id_fk" FOREIGN KEY ("status_id")
REFERENCES "reference"."status"("status_id");

ALTER TABLE "lab"."qpcr"
ADD CONSTRAINT "qpcr_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id");

ALTER TABLE "lab"."library"
ADD CONSTRAINT "library_experiment_fk" FOREIGN KEY ("experiment_id", "experiment_date")
REFERENCES "lab"."experiments"("experiment_id", "experiment_date");

ALTER TABLE "lab"."library"
ADD CONSTRAINT "library_sample_id_fk" FOREIGN KEY ("sample_id")
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."library"
ADD CONSTRAINT "library_person_id_fk" FOREIGN KEY ("person_id")
REFERENCES "reference"."personal"("person_id");

ALTER TABLE "lab"."library"
ADD CONSTRAINT "library_storage_id_fk" FOREIGN KEY ("storage_id")
REFERENCES "lab"."storage"("storage_id");

ALTER TABLE "lab"."library"
ADD CONSTRAINT "library_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id");

ALTER TABLE "lab"."sequencing"
ADD CONSTRAINT "sequencing_experiment_fk" FOREIGN KEY ("experiment_id", "experiment_date")
REFERENCES "lab"."experiments"("experiment_id", "experiment_date");

ALTER TABLE "lab"."sequencing"
ADD CONSTRAINT "sequencing_library_fk" FOREIGN KEY ("library_id", "prep_date")
REFERENCES "lab"."library"("library_id", "prep_date");

ALTER TABLE "lab"."sequencing"
ADD CONSTRAINT "sequencing_sample_id_fk" FOREIGN KEY ("sample_id")
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "lab"."sequencing"
ADD CONSTRAINT "sequencing_person_id_fk" FOREIGN KEY ("person_id")
REFERENCES "reference"."personal"("person_id");

ALTER TABLE "lab"."sequencing"
ADD CONSTRAINT "sequencing_status_id_fk" FOREIGN KEY ("status_id")
REFERENCES "reference"."status"("status_id");

ALTER TABLE "lab"."sequencing"
ADD CONSTRAINT "sequencing_storage_id_fk" FOREIGN KEY ("storage_id")
REFERENCES "lab"."storage"("storage_id");

ALTER TABLE "lab"."sequencing"
ADD CONSTRAINT "sequencing_project_id_fk" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id");

ALTER TABLE "lab"."datasets"
ADD CONSTRAINT "datasets_ecosystem_id_fk" FOREIGN KEY ("ecosystem_id")
REFERENCES "reference"."ecosystem"("ecosystem_id");

ALTER TABLE "lab"."datasets"
ADD CONSTRAINT "datasets_region_id_fk" FOREIGN KEY ("region_id")
REFERENCES "reference"."region"("region_id");

ALTER TABLE "lab"."datasets"
ADD CONSTRAINT "datasets_customer_id_fk" FOREIGN KEY ("customer_id")
REFERENCES "lims"."customers"("customer_id");

ALTER TABLE "lab"."datasets"
ADD CONSTRAINT "datasets_stored_location_id_fk" FOREIGN KEY ("stored_location_id")
REFERENCES "lab"."storage"("storage_id");

ALTER TABLE "bioinformatics"."analysis_runs"
ADD CONSTRAINT "analysis_runs_pipeline_id_fk" FOREIGN KEY ("pipeline_id")
REFERENCES "bioinformatics"."analysis_pipelines"("pipeline_id");

ALTER TABLE "bioinformatics"."analysis_runs"
ADD CONSTRAINT "analysis_runs_sequencing_fk" FOREIGN KEY ("sequencing_id", "sequencing_date")
REFERENCES "lab"."sequencing"("sequencing_id", "sequencing_date");

ALTER TABLE "bioinformatics"."analysis_runs"
ADD CONSTRAINT "analysis_runs_person_id_fk" FOREIGN KEY ("person_id")
REFERENCES "reference"."personal"("person_id");

ALTER TABLE "bioinformatics"."analysis_runs"
ADD CONSTRAINT "analysis_runs_reference_db_id_fk" FOREIGN KEY ("reference_db_id")
REFERENCES "bioinformatics"."reference_databases"("db_id");

ALTER TABLE "bioinformatics"."edna_assignments"
ADD CONSTRAINT "edna_assignments_run_fk" FOREIGN KEY ("run_id", "run_date")
REFERENCES "bioinformatics"."analysis_runs"("run_id", "run_date");

ALTER TABLE "bioinformatics"."edna_assignments"
ADD CONSTRAINT "edna_assignments_sample_id_fk" FOREIGN KEY ("sample_id")
REFERENCES "lab"."master_samples"("sample_id");

ALTER TABLE "bioinformatics"."edna_assignments"
ADD CONSTRAINT "edna_assignments_taxon_id_fk" FOREIGN KEY ("taxon_id")
REFERENCES "reference"."taxon"("taxon_id");

ALTER TABLE "projects"."ProjectWanderfische_FishingData"
ADD CONSTRAINT "fk_fishingdata_agency" FOREIGN KEY ("agency_id")
REFERENCES "lims"."external_contacts"("contact_id") ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE "projects"."ProjectWanderfische_FishingData"
ADD CONSTRAINT "fk_fishingdata_project" FOREIGN KEY ("project_id")
REFERENCES "lims"."projects"("project_id") ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE "projects"."ProjectWanderfische_FishingData"
ADD CONSTRAINT "fk_fishingdata_salinity_unit" FOREIGN KEY ("salinity_unit_id")
REFERENCES "reference"."units"("unit_id") ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE "projects"."ProjectWanderfische_FishingData"
ADD CONSTRAINT "fk_fishingdata_oxygen_unit" FOREIGN KEY ("oxygen_unit_id")
REFERENCES "reference"."units"("unit_id") ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE "projects"."ProjectWanderfische_FishingData"
ADD CONSTRAINT "fk_fishingdata_wind_unit" FOREIGN KEY ("wind_unit_id")
REFERENCES "reference"."units"("unit_id") ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE "projects"."ProjectWanderfische_FishingData"
ADD CONSTRAINT "fk_fishingdata_created_by" FOREIGN KEY ("created_by")
REFERENCES "reference"."personal"("person_id") ON UPDATE CASCADE ON DELETE SET NULL;

ALTER TABLE "projects"."ProjectWanderfische_FishingData"
ADD CONSTRAINT "fk_fishingdata_last_modified_by" FOREIGN KEY ("last_modified_by")
REFERENCES "reference"."personal"("person_id") ON UPDATE CASCADE ON DELETE SET NULL;


ALTER TABLE "projects"."ProjectWanderfische_FishCatch"
ADD CONSTRAINT "fk_fishcatch_fishingdata" FOREIGN KEY ("fishing_record_id", "fishing_record_date")
REFERENCES "projects"."ProjectWanderfische_FishingData"("fishing_record_id", "record_date") ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE "projects"."ProjectWanderfische_FishCatch"
ADD CONSTRAINT "fk_fishcatch_taxon" FOREIGN KEY ("taxon_id")
REFERENCES "reference"."taxon"("taxon_id") ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE "projects"."ProjectWanderfische_FishCatch"
ADD CONSTRAINT "fk_fishcatch_created_by" FOREIGN KEY ("created_by")
REFERENCES "reference"."personal"("person_id") ON UPDATE CASCADE ON DELETE SET NULL;

ALTER TABLE "projects"."ProjectWanderfische_FishCatch"
ADD CONSTRAINT "fk_fishcatch_last_modified_by" FOREIGN KEY ("last_modified_by")
REFERENCES "reference"."personal"("person_id") ON UPDATE CASCADE ON DELETE SET NULL;


ALTER TABLE "projects"."ProjectWanderfische_Mail"
ADD CONSTRAINT "fk_mail_fishingdata" FOREIGN KEY ("fishing_record_id", "fishing_record_date")
REFERENCES "projects"."ProjectWanderfische_FishingData"("fishing_record_id", "record_date") ON UPDATE CASCADE ON DELETE SET NULL;

ALTER TABLE "projects"."ProjectWanderfische_Mail"
ADD CONSTRAINT "fk_mail_sender_person" FOREIGN KEY ("sender_person_id")
REFERENCES "reference"."personal"("person_id") ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE "projects"."ProjectWanderfische_Mail"
ADD CONSTRAINT "fk_mail_recipient_contact" FOREIGN KEY ("recipient_contact_id")
REFERENCES "lims"."external_contacts"("contact_id") ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE "projects"."ProjectWanderfische_Mail"
ADD CONSTRAINT "fk_mail_created_by" FOREIGN KEY ("created_by")
REFERENCES "reference"."personal"("person_id") ON UPDATE CASCADE ON DELETE SET NULL;

ALTER TABLE "projects"."ProjectWanderfische_Mail"
ADD CONSTRAINT "fk_mail_last_modified_by" FOREIGN KEY ("last_modified_by")
REFERENCES "reference"."personal"("person_id") ON UPDATE CASCADE ON DELETE SET NULL;


ALTER TABLE "projects"."ProjectWanderfische_Conversation"
ADD CONSTRAINT "fk_conversation_fishingdata" FOREIGN KEY ("fishing_record_id", "fishing_record_date")
REFERENCES "projects"."ProjectWanderfische_FishingData"("fishing_record_id", "record_date") ON UPDATE CASCADE ON DELETE SET NULL;

ALTER TABLE "projects"."ProjectWanderfische_Conversation"
ADD CONSTRAINT "fk_conversation_created_by" FOREIGN KEY ("created_by")
REFERENCES "reference"."personal"("person_id") ON UPDATE CASCADE ON DELETE SET NULL;

ALTER TABLE "projects"."ProjectWanderfische_Conversation"
ADD CONSTRAINT "fk_conversation_last_modified_by" FOREIGN KEY ("last_modified_by")
REFERENCES "reference"."personal"("person_id") ON UPDATE CASCADE ON DELETE SET NULL;


ALTER TABLE "projects"."ProjectWanderfische_ChatMessage"
ADD CONSTRAINT "fk_chatmessage_conversation" FOREIGN KEY ("conversation_id")
REFERENCES "projects"."ProjectWanderfische_Conversation"("conversation_id") ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE "projects"."ProjectWanderfische_ChatMessage"
ADD CONSTRAINT "fk_chatmessage_sender_person" FOREIGN KEY ("sender_person_id")
REFERENCES "reference"."personal"("person_id") ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE "projects"."ProjectWanderfische_ChatMessage"
ADD CONSTRAINT "fk_chatmessage_sender_contact" FOREIGN KEY ("sender_contact_id")
REFERENCES "lims"."external_contacts"("contact_id") ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE "projects"."ProjectWanderfische_ChatMessage"
ADD CONSTRAINT "fk_chatmessage_created_by" FOREIGN KEY ("created_by")
REFERENCES "reference"."personal"("person_id") ON UPDATE CASCADE ON DELETE SET NULL;

ALTER TABLE "projects"."ProjectWanderfische_ChatMessage"
ADD CONSTRAINT "fk_chatmessage_last_modified_by" FOREIGN KEY ("last_modified_by")
REFERENCES "reference"."personal"("person_id") ON UPDATE CASCADE ON DELETE SET NULL;

