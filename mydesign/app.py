import os
import psycopg2
import psycopg2.extras
import bcrypt
from flask import Flask, jsonify, request, send_from_directory, redirect, url_for, session, g
from flask_cors import CORS
from waitress import serve
import base64
from typing import Any, Dict, List, Optional, Tuple, Union

# --- Configuration ---
# IMPORTANT: For production, use environment variables for sensitive data like passwords.
DB_HOST: str = os.getenv('DB_HOST', '0.0.0.0')
DB_NAME: str = os.getenv('DB_NAME', 'wanderfische')
DB_USER: str = os.getenv('DB_USER', 'kasmi')
DB_PASS: str = os.getenv('DB_PASS', 'password')
# Flask secret key for session management. CHANGE THIS FOR PRODUCTION!
SECRET_KEY: str = os.getenv('SECRET_KEY', 'a_very_secret_key_for_session_management_and_security')

STATIC_FOLDER: str = '.' # Serves frontend files from the directory where app.py is run
FLASK_ENV: str = os.getenv('FLASK_ENV', 'production') # 'development' for debugging, 'production' for deployment
API_PREFIX: str = os.getenv('API_PREFIX', '/api') # e.g., '/api', '/mymglab/api'

app = Flask(__name__, static_folder=STATIC_FOLDER)
app.secret_key = SECRET_KEY
# Enable CORS for all routes, allowing credentials (cookies/sessions)
CORS(app, supports_credentials=True)

# --- Primary Key Mapping ---
# Maps (schema_name_lower, table_name_lower) to their primary key column name (case-sensitive as in DB).
# This is crucial for generic PUT/DELETE/GET by ID.
# IMPORTANT: The primary key column name (the VALUE in this dictionary) MUST EXACTLY match the
# case-sensitive name of the primary key column in your PostgreSQL database.
# For tables with composite PKs (e.g., Lab.Experiments, Lab.Sampling, Lab.Samples, etc.),
# generic PUT/DELETE by a single PK will NOT work correctly. These operations would require
# custom API routes or a more sophisticated generic handler to accept all PK components.
PK_MAPPING: Dict[Tuple[str, str], str] = {
    # Schema: Reference
    ('reference', 'personal'): 'person_id',
    ('reference', 'status'): 'status_id',
    ('reference', 'room'): 'room_id',
    ('reference', 'vessel'): 'vessel_id',
    ('reference', 'region'): 'region_id',
    ('reference', 'ecosystem'): 'ecosystem_id',
    ('reference', 'category'): 'category_id',
    ('reference', 'samples_type'): 'sample_type_id',
    ('reference', 'gene'): 'gene_id',
    ('reference', 'taxon'): 'taxon_id',
    ('reference', 'species'): 'species_id',
    ('reference', 'units'): 'unit_id',

    # Schema: Lims
    ('lims', 'external_contacts'): 'contact_id',
    ('lims', 'customers'): 'customer_id',
    ('lims', 'projects'): 'project_id',
    ('lims', 'project_persons'): 'project_id', # Composite PK: (project_id, person_id)
    ('lims', 'cruises'): 'cruise_id',
    ('lims', 'workflows'): 'workflow_id',
    ('lims', 'permits'): 'permit_id',
    ('lims', 'primers'): 'primer_id',
    ('lims', 'sop'): 'sop_id',
    ('lims', 'workflow_steps'): 'step_id', # Composite PK: (workflow_id, step_number)
    ('lims', 'equipment'): 'equipment_id',
    ('lims', 'suppliers'): 'supplier_id',
    ('lims', 'inventory_items'): 'item_id',
    ('lims', 'orders'): 'fi_order_nr',
    ('lims', 'reagents'): 'reagent_id',
    ('lims', 'publication_type'): 'publication_type_id',
    ('lims', 'publications'): 'publication_id',

    # Schema: Lab
    ('lab', 'storage'): 'storage_id',
    ('lab', 'experiments'): 'experiment_id', # Composite PK: (experiment_id, experiment_date)
    ('lab', 'experiments_projects'): 'experiment_project_id', # Serial PK
    ('lab', 'protocol_runs'): 'protocol_run_id',
    ('lab', 'sampling'): 'sampling_id', # Composite PK: (sampling_id, sampling_date)
    ('lab', 'master_samples'): 'sample_id',
    ('lab', 'samples'): 'sample_id', # Composite PK: (sample_id, sampling_date)
    ('lab', 'fishing'): 'fishing_id',
    ('lab', 'storage_log'): 'log_id', # Serial PK
    ('lab', 'fish'): 'sample_id',
    ('lab', 'tissue'): 'sample_id',
    ('lab', 'otoliths'): 'otolith_id',
    ('lab', 'dna'): 'sample_id',
    ('lab', 'rna'): 'sample_id',
    ('lab', 'sediments'): 'sample_id',
    ('lab', 'water'): 'sample_id',
    ('lab', 'experiments_samples'): 'experiment_id', # Composite PK: (experiment_id, sample_id, experiment_date)
    ('lab', 'dissections'): 'dissection_id', # Composite PK: (dissection_id, dissection_date)
    ('lab', 'extraction'): 'extraction_id', # Composite PK: (extraction_id, extraction_date)
    ('lab', 'nanodrop'): 'nanodrop_id', # Composite PK: (nanodrop_id, measurement_date)
    ('lab', 'qubit'): 'qubit_id', # Composite PK: (qubit_id, measurement_date)
    ('lab', 'tapestation'): 'tapestation_id', # Composite PK: (tapestation_id, measurement_date)
    ('lab', 'pcr'): 'pcr_id', # Composite PK: (pcr_id, pcr_date)
    ('lab', 'gelelectrophoresis'): 'gelelectrophoresis_id', # Composite PK: (gelelectrophoresis_id, run_date)
    ('lab', 'qpcr'): 'qpcr_id', # Composite PK: (qpcr_id, qpcr_date)
    ('lab', 'library'): 'library_id', # Composite PK: (library_id, prep_date)
    ('lab', 'sequencing'): 'sequencing_id', # Composite PK: (sequencing_id, sequencing_date)
    ('lab', 'datasets'): 'dataset_id', # Composite PK: (dataset_id, reception_date)

    # Schema: Bioinformatics
    ('bioinformatics', 'reference_databases'): 'db_id',
    ('bioinformatics', 'analysis_pipelines'): 'pipeline_id',
    ('bioinformatics', 'analysis_runs'): 'run_id', # Composite PK: (run_id, run_date)
    ('bioinformatics', 'edna_assignments'): 'assignment_id',

    # Views (for read-only access, PKs here are for conceptual filtering, not for PUT/DELETE)
    ('reference', 'complete_species_taxon_view'): 'taxon_id',
    ('lab', 'detailed_samples_view'): 'sample_id',
    ('lims', 'project_overview_view'): 'project_id',
    ('lab', 'sample_workflow_progress_view'): 'sample_id',
    ('lab', 'storage_inventory_view'): 'storage_id',
    ('lab', 'experiment_summary_view'): 'experiment_id',
    ('bioinformatics', 'analysis_results_summary'): 'run_id',
    ('lims', 'project_financial_summary_view'): 'project_id',
    ('bioinformatics', 'full_analysis_results_view'): 'project_id',
    ('lab', 'storage_occupancy_view'): 'storage_id',
    ('lims', 'project_comprehensive_summary_view'): 'project_id',
    ('lab', 'experiment_progress_overview_view'): 'experiment_id',
    ('lims', 'reagent_status_view'): 'reagent_complete_name',
    ('lab', 'sample_full_details_view'): 'sample_id',
    ('reference', 'taxon_hierarchy_view'): 'taxon_id',
    ('lab', 'monthly_sample_reception_mv'): 'reception_month',
}

# --- Database Connection ---
def get_db_connection():
    try:
        conn = psycopg2.connect(host=DB_HOST, database=DB_NAME, user=DB_USER, password=DB_PASS)
        return conn
    except psycopg2.OperationalError as e:
        print(f"FATAL: Could not connect to database at {DB_HOST}. Error: {e}")
        raise

# --- Context Manager for DB connection ---
@app.before_request
def before_request_func():
    g.db_conn = get_db_connection()
    if 'user_id' in session and session['user_id'] is not None: # Check for None explicitly
        # Convert user_id to string for PostgreSQL set_config, as it expects text
        user_id_str = str(session['user_id'])
        with g.db_conn.cursor() as cur:
            # Use ::text cast in SQL to ensure type compatibility
            cur.execute("SELECT set_config('lims.current_person_id', %s::text, FALSE)", (user_id_str,))
            g.db_conn.commit()
            print(f"RLS: Set lims.current_person_id to {user_id_str}")
    else:
        with g.db_conn.cursor() as cur:
            cur.execute("SELECT set_config('lims.current_person_id', '', FALSE)")
            g.db_conn.commit()
            print("RLS: Cleared lims.current_person_id (no user logged in)")


@app.teardown_request
def teardown_request_func(exception=None):
    if hasattr(g, 'db_conn'):
        g.db_conn.close()

# --- Helper Functions ---
def get_pk_column(schema: str, table: str) -> str:
    pk_col = PK_MAPPING.get((schema.lower(), table.lower()))
    if pk_col is None:
        print(f"WARNING: No primary key mapping found for {schema}.{table}. Defaulting to 'nr'. "
              "Please ensure PK_MAPPING is correct and matches database column casing.")
        return 'nr'
    return pk_col

def transform_row_for_json(row: Dict[str, Any]) -> Dict[str, Any]:
    new_row = dict(row)
    for key, value in new_row.items():
        if isinstance(value, memoryview):
            new_row[key] = base64.b64encode(value.tobytes()).decode('utf-8')
        elif isinstance(value, bytes):
            new_row[key] = base64.b64encode(value).decode('utf-8')
    return new_row

# --- Database Schema/Table Casing Resolver ---
_resolved_names_cache: Dict[Tuple[str, str], Tuple[str, str]] = {}

def _resolve_table_casing(conn, requested_schema: str, requested_table: str) -> Optional[Tuple[str, str]]:
    cache_key = (requested_schema.lower(), requested_table.lower())
    if cache_key in _resolved_names_cache:
        return _resolved_names_cache[cache_key]

    query = """
        SELECT table_schema, table_name
        FROM information_schema.tables
        WHERE lower(table_schema) = lower(%s) AND lower(table_name) = lower(%s)
        LIMIT 1;
    """
    try:
        with conn.cursor() as cur:
            cur.execute(query, (requested_schema, requested_table))
            result = cur.fetchone()
            if result:
                actual_schema, actual_table = result[0], result[1]
                _resolved_names_cache[cache_key] = (actual_schema, actual_table)
                return actual_schema, actual_table
    except Exception as e:
        print(f"Error resolving table casing for {requested_schema}.{requested_table}: {e}")
    return None

# --- API Endpoints ---

@app.route(f'{API_PREFIX}/login', methods=['POST'])
def login_user():
    data = request.get_json()
    username = data.get('username')
    password = data.get('password')

    if not username or not password:
        return jsonify({"error": "Missing username or password"}), 400

    # 1. Special "TIFI" user bypass
    if username == 'TIFI' and password == 'password':
        session['user_id'] = 'TIFI'
        session['user_type'] = 'admin'
        session['is_admin'] = True
        return jsonify({"success": True, "user": {"full_name": "TIFI Admin", "person_id": "TIFI"}, "user_type": "admin"}), 200

    conn = None
    try:
        conn = g.db_conn
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            # 2. Authenticate against reference.personal (using person_id)
            query_personal = 'SELECT person_id, full_name, password_hash FROM "reference"."personal" WHERE person_id = %s;'
            cur.execute(query_personal, (username,))
            user_personal = cur.fetchone()

            if user_personal and user_personal.get('password_hash'):
                if bcrypt.checkpw(password.encode('utf-8'), user_personal['password_hash'].encode('utf-8')):
                    session['user_id'] = user_personal['person_id']
                    session['user_type'] = 'personal'
                    session['is_admin'] = False
                    user_personal.pop('password_hash', None)
                    return jsonify({"success": True, "user": user_personal, "user_type": "personal"}), 200

            # 3. Authenticate against lims.customers (using mail)
            query_customers = 'SELECT customer_id, customer_name, mail, password_hash FROM "lims"."customers" WHERE mail = %s;'
            cur.execute(query_customers, (username,))
            user_customer = cur.fetchone()

            if user_customer and user_customer.get('password_hash'):
                if bcrypt.checkpw(password.encode('utf-8'), user_customer['password_hash'].encode('utf-8')):
                    session['user_id'] = user_customer['customer_id']
                    session['user_type'] = 'customer'
                    session['is_admin'] = False
                    user_customer.pop('password_hash', None)
                    return jsonify({"success": True, "user": user_customer, "user_type": "customer"}), 200

            # 4. Authenticate against lims.external_contacts (using mail)
            query_external_contacts = 'SELECT contact_id, full_name, mail, password_hash FROM "lims"."external_contacts" WHERE mail = %s;'
            cur.execute(query_external_contacts, (username,))
            user_external = cur.fetchone()

            if user_external and user_external.get('password_hash'):
                if bcrypt.checkpw(password.encode('utf-8'), user_external['password_hash'].encode('utf-8')):
                    session['user_id'] = user_external['contact_id']
                    session['user_type'] = 'external_contact'
                    session['is_admin'] = False
                    user_external.pop('password_hash', None)
                    return jsonify({"success": True, "user": user_external, "user_type": "external_contact"}), 200

            # If none of the above succeeded
            return jsonify({"error": "Invalid credentials"}), 401

    except Exception as e:
        print(f"Login error for {username}: {e}")
        return jsonify({"error": "An internal server error occurred during login."}), 500


@app.route(f'{API_PREFIX}/logout', methods=['POST'])
def logout_user():
    session.pop('user_id', None)
    session.pop('user_type', None)
    session.pop('is_admin', None)
    return jsonify({"success": True, "message": "Logged out"}), 200

@app.route(f'{API_PREFIX}/global-search/<string:search_term>', methods=['GET'])
def global_search(search_term: str):
    ts_query_func = f"plainto_tsquery('public.lims_english', %s)"
    search_pattern = f"%{search_term}%"

    results: Dict[str, List[Dict[str, Any]]] = {}

    queries: Dict[str, Tuple[str, Tuple[str, ...]]] = {
        "projects": (
            f'SELECT project_id, title FROM "lims"."projects" WHERE project_search_vector @@ {ts_query_func} OR project_id ILIKE %s OR title ILIKE %s LIMIT 5',
            (search_term, search_pattern, search_pattern)
        ),
        "samples": (
            f'SELECT sample_id, external_name, sample_status_id FROM "lab"."samples" WHERE sample_search_vector @@ {ts_query_func} OR sample_id ILIKE %s OR external_name ILIKE %s LIMIT 5',
            (search_term, search_pattern, search_pattern)
        ),
        "experiments": (
            f'SELECT experiment_id, experiment_title FROM "lab"."experiments" WHERE experiment_search_vector @@ {ts_query_func} OR experiment_id ILIKE %s OR experiment_title ILIKE %s LIMIT 5',
            (search_term, search_pattern, search_pattern)
        ),
        "sop": (
            f'SELECT sop_id, title FROM "lims"."sop" WHERE sop_search_vector @@ {ts_query_func} OR sop_id ILIKE %s OR title ILIKE %s LIMIT 5',
            (search_term, search_pattern, search_pattern)
        ),
        "customers": (
            f'SELECT customer_id, customer_name FROM "lims"."customers" WHERE customer_search_vector @@ {ts_query_func} OR customer_name ILIKE %s LIMIT 5',
            (search_term, search_pattern)
        ),
        "species": (
            'SELECT species_id, de_name, en_name FROM "reference"."species" WHERE de_name ILIKE %s OR en_name ILIKE %s LIMIT 5',
            (search_pattern, search_pattern)
        ),
        "primers": (
            'SELECT primer_id, primer_sequence_fwd, primer_sequence_rev FROM "lims"."primers" WHERE primer_id ILIKE %s OR primer_sequence_fwd ILIKE %s OR primer_sequence_rev ILIKE %s LIMIT 5',
            (search_pattern, search_pattern, search_pattern)
        ),
        "reagents": (
            'SELECT reagent_id, reagent_complete_name, lot FROM "lims"."reagents" WHERE reagent_id ILIKE %s OR reagent_complete_name ILIKE %s OR lot ILIKE %s LIMIT 5',
            (search_pattern, search_pattern, search_pattern)
        ),
        "personal": (
            'SELECT person_id, full_name FROM "reference"."personal" WHERE person_id ILIKE %s OR full_name ILIKE %s LIMIT 5',
            (search_pattern, search_pattern)
        ),
        "detailed_samples_view": (
            'SELECT sample_id, external_name, sample_type_abrv, project_title FROM "lab"."detailed_samples_view" WHERE sample_id ILIKE %s OR external_name ILIKE %s OR project_title ILIKE %s LIMIT 5',
            (search_pattern, search_pattern, search_pattern)
        ),
        "project_overview_view": (
            'SELECT project_id, title, pi_full_name FROM "lims"."project_overview_view" WHERE project_id ILIKE %s OR title ILIKE %s OR pi_full_name ILIKE %s LIMIT 5',
            (search_pattern, search_pattern, search_pattern)
        ),
        "analysis_results_summary": (
            'SELECT run_id, sample_id, taxon_en_name FROM "bioinformatics"."analysis_results_summary" WHERE run_id ILIKE %s OR sample_id ILIKE %s OR taxon_en_name ILIKE %s LIMIT 5',
            (search_pattern, search_pattern, search_pattern)
        ),
    }
            
    try:
        conn = g.db_conn
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            for key, (query, params) in queries.items():
                try:
                    cur.execute(query, params)
                    results[key] = [transform_row_for_json(row) for row in cur.fetchall()]
                except Exception as inner_e:
                    print(f"Error executing search for {key}: {inner_e}")
                    results[key] = []
            return jsonify(results), 200
    except Exception as e:
        print(f"Global search error: {e}")
        return jsonify({"error": "An internal server error occurred during search."}), 500


@app.route(f'{API_PREFIX}/dashboard-stats', methods=['GET'])
def get_dashboard_stats():
    query = """
    SELECT
        (SELECT COUNT(*) FROM "lims"."projects" WHERE "status_id" = 'Active') AS active_projects,
        (SELECT COUNT(*) FROM "lab"."samples") AS total_samples,
        (SELECT COUNT(*) FROM "lab"."experiments" WHERE "experiment_date" >= date_trunc('month', CURRENT_DATE)) AS experiments_this_month,
        (SELECT COUNT(*) FROM "lims"."reagents" WHERE "expire_date" BETWEEN CURRENT_DATE AND CURRENT_DATE + interval '30 day') AS reagents_expiring_soon,
        (SELECT COUNT(*) FROM "lab"."storage_occupancy_view" WHERE occupancy_percent > 75) AS highly_occupied_storages,
        (SELECT COUNT(*) FROM "lims"."orders" WHERE status_id = 'Pending') AS pending_orders;
    """
    try:
        conn = g.db_conn
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute(query)
            stats = cur.fetchone()
        return jsonify(stats), 200
    except Exception as e:
        print(f"Dashboard stats error: {e}")
        return jsonify({"error": "An internal server error occurred while fetching dashboard stats."}), 500

@app.route(f'{API_PREFIX}/table_names_for_forms', methods=['GET'])
def table_names_for_forms():
    try:
        conn = g.db_conn
        with conn.cursor() as cur:
            query = """
            SELECT table_schema || '.' || table_name
            FROM information_schema.tables
            WHERE table_schema IN ('lab', 'lims', 'reference', 'bioinformatics', 'audit')
              AND table_type IN ('BASE TABLE', 'VIEW', 'MATERIALIZED VIEW')
              AND table_name NOT LIKE '%_seq'
              AND table_name NOT LIKE '%_y%'
            ORDER BY table_schema, table_name;
            """
            cur.execute(query)
            tables = [row[0] for row in cur.fetchall()]
            return jsonify(tables), 200
    except Exception as e:
        print(f"Error fetching table names for forms: {e}")
        return jsonify({"error": str(e)}), 500

@app.route(f'{API_PREFIX}/table/<string:schema>/<string:table>', methods=['GET'])
def get_table_data(schema: str, table: str):
    try:
        conn = g.db_conn

        resolved_names = _resolve_table_casing(conn, schema, table)
        if not resolved_names:
            return jsonify({"error": f"Table or view '{schema}.{table}' not found or inaccessible."}), 404
        
        actual_schema, actual_table = resolved_names
        full_qualified_name = f'"{actual_schema}"."{actual_table}"'
        
        base_query = f'SELECT * FROM {full_qualified_name}'
        where_clauses: List[str] = []
        params: List[Any] = []

        order_by_column: Optional[str] = None
        order_direction: str = 'ASC'

        for key, value in request.args.items():
            if not value:
                continue

            if key == 'limit' or key == 'offset':
                continue
            elif key == 'order_by':
                order_by_column = value
                continue
            elif key == 'order_direction':
                if value.upper() in ['ASC', 'DESC']:
                    order_direction = value.upper()
                continue

            filterable_columns = [
                'sample_id', 'project_id', 'status_id', 'sop_id', 'person_id',
                'room_id', 'category_id', 'primer_id', 'sample_type_id', 'region_id',
                'species_id', 'sampling_id', 'experiment_id', 'external_name',
                'workflow_id', 'workflow_name', 'workflow_status_id', 'step_id',
                'fi_order_nr', 'reagent_id', 'equipment_id', 'library_id',
                'sequencing_id', 'db_id', 'pipeline_id', 'run_id', 'assignment_id',
                'publication_id', 'cruise_id', 'vessel_id', 'ecosystem_id',
                'contact_id', 'customer_id', 'item_id', 'supplier_id',
                'publication_type_id', 'log_id', 'protocol_run_id', 'dissection_id',
                'extraction_id', 'nanodrop_id', 'qubit_id', 'tapestation_id',
                'pcr_id', 'gelelectrophoresis_id', 'qpcr_id', 'dataset_id',
                'reception_month',
                'sampling_date', 'experiment_date', 'dissection_date', 'extraction_date',
                'measurement_date', 'pcr_date', 'run_date', 'prep_date', 'sequencing_date',
                'reception_date', 'order_date', 'expire_date', 'date_publication',
                'date_submission', 'valid_from', 'valid_to', 'link_date', 'move_date',
                'action_timestamp', 'created_at', 'date_realise',
                'title', 'full_name', 'customer_name', 'experiment_title',
                'reagent_complete_name', 'lot', 'de_name', 'en_name', 'sample_type_abrv',
                'workflow_name', 'pipeline_name', 'db_name', 'item_name', 'supplier_name',
                'vessel_name', 'region_abrv', 'ecosystem_abrv', 'unit_name', 'unit_abbreviation',
                'pi_person_id', 'funder', 'temperature_c', 'box', 'freezer', 'sex', 'stomach_contents_jsonb',
                'mail',
                'path'
            ]

            if key.startswith('filter_'):
                col_name = key[len('filter_'):]
                if col_name in filterable_columns:
                    where_clauses.append(f'"{col_name}" ILIKE %s')
                    params.append(f'%{value}%')
                else:
                    print(f"Warning: Filter by non-filterable column '{col_name}' skipped.")
            elif key in filterable_columns:
                where_clauses.append(f'"{key}" = %s')
                params.append(value)

        if where_clauses:
            query = f"{base_query} WHERE {' AND '.join(where_clauses)}"
        else:
            query = base_query
        
        if order_by_column:
            if order_by_column in filterable_columns:
                query += f' ORDER BY "{order_by_column}" {order_direction}'
            else:
                print(f"Warning: Attempted to order by unlisted column '{order_by_column}'. Skipping order by.")
        
        limit = request.args.get('limit', type=int)
        offset = request.args.get('offset', type=int)
        if limit is not None:
            query += f" LIMIT %s"
            params.append(limit)
        if offset is not None:
            query += f" OFFSET %s"
            params.append(offset)

        query += ";"

        print(f"Executing GET query: {query} with params: {params}")
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute(query, params)
            data = cur.fetchall()
        
        processed_data = [transform_row_for_json(row) for row in data]
        
        return jsonify(processed_data), 200
    except Exception as e:
        print(f"Error fetching table data for {schema}.{table}: {e}")
        return jsonify({"error": str(e)}), 500
            
@app.route(f'{API_PREFIX}/table/<string:schema>/<string:table>', methods=['POST'])
def create_record(schema: str, table: str):
    try:
        conn = g.db_conn
        resolved_names = _resolve_table_casing(conn, schema, table)
        if not resolved_names:
            return jsonify({"error": f"Table '{schema}.{table}' not found or inaccessible."}), 404
        actual_schema, actual_table = resolved_names

        if request.is_json:    
            data = request.get_json()
            files = {}
        else:    
            data = request.form.to_dict()
            files = request.files

        if not data and not files:    
            return jsonify({"error": "No data provided"}), 400
            
        if 'attachment' in files and files['attachment'].filename != '':
            data['attachment'] = psycopg2.Binary(files['attachment'].read())
        elif 'attachment' in data and data['attachment'] == '':
            data['attachment'] = None
        
        if (actual_schema.lower() == 'reference' and actual_table.lower() == 'personal') or \
           (actual_schema.lower() == 'lims' and actual_table.lower() == 'customers') or \
           (actual_schema.lower() == 'lims' and actual_table.lower() == 'external_contacts'):
            if 'password' in data and data['password']:
                hashed_password = bcrypt.hashpw(data['password'].encode('utf-8'), bcrypt.gensalt())
                data['password_hash'] = hashed_password.decode('utf-8')
            data.pop('password', None)
        
        filtered_data = {k: (v if v != '' else None) for k, v in data.items()}
        
        columns = filtered_data.keys()
        values = list(filtered_data.values())
        
        column_names = ', '.join([f'"{col}"' for col in columns])
        value_placeholders = ', '.join(['%s'] * len(values))
        
        query = f'INSERT INTO "{actual_schema}"."{actual_table}" ({column_names}) VALUES ({value_placeholders}) RETURNING *;'
        
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            print(f"Executing POST query: {query} with values: {values}")
            cur.execute(query, values)
            new_record = cur.fetchone()
            conn.commit()
        return jsonify(transform_row_for_json(new_record)), 201
    except Exception as e:    
        if conn:
            conn.rollback()
        print(f"Error creating record in {schema}.{table}: {e}")
        return jsonify({"error": str(e)}), 500

@app.route(f'{API_PREFIX}/table/<string:schema>/<string:table>/<pk_value>', methods=['PUT'])
def update_record(schema: str, table: str, pk_value: Union[str, int]):
    try:
        conn = g.db_conn
        resolved_names = _resolve_table_casing(conn, schema, table)
        if not resolved_names:
            return jsonify({"error": f"Table '{schema}.{table}' not found or inaccessible."}), 404
        actual_schema, actual_table = resolved_names

        pk_column = get_pk_column(schema, table)
        data = request.get_json()
        if not data:    
            return jsonify({"error": "No data provided"}), 400
            
        set_clauses: List[str] = []
        values: List[Any] = []
        
        if (actual_schema.lower() == 'reference' and actual_table.lower() == 'personal') or \
           (actual_schema.lower() == 'lims' and actual_table.lower() == 'customers') or \
           (actual_schema.lower() == 'lims' and actual_table.lower() == 'external_contacts'):
            if 'password' in data and data['password']:
                hashed_password = bcrypt.hashpw(data['password'].encode('utf-8'), bcrypt.gensalt())
                data['password_hash'] = hashed_password.decode('utf-8')
            data.pop('password', None)
        
        for key, val in data.items():
            set_clauses.append(f'"{key}" = %s')
            values.append(None if val == '' else val)    
        
        if not set_clauses:
            return jsonify({"error": "No fields to update"}), 400

        integer_pk_tables = [
            ('lims', 'customers'), ('lab', 'experiments_projects'), ('lab', 'storage_log')
        ]
        
        try:
            if (schema.lower(), table.lower()) in integer_pk_tables:
                param_pk_value = int(pk_value)
            else:
                param_pk_value = pk_value
            values.append(param_pk_value)
        except ValueError:
            return jsonify({"error": f"Invalid ID format for '{pk_column}': {pk_value}. Expected integer for this table."}), 400
            
        query = f'UPDATE "{actual_schema}"."{actual_table}" SET {", ".join(set_clauses)} WHERE "{pk_column}" = %s RETURNING *;'
        
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            print(f"Executing PUT query: {query} with values: {values}")
            cur.execute(query, values)
            updated_record = cur.fetchone()
            conn.commit()
        if updated_record:
            return jsonify(transform_row_for_json(updated_record)), 200
        else:
            return jsonify({"error": "Record not found or no changes made."}), 404
    except Exception as e:    
        if conn:
            conn.rollback()
        print(f"Error updating record in {schema}.{table}: {e}")
        return jsonify({"error": str(e)}), 500

@app.route(f'{API_PREFIX}/table/<string:schema>/<string:table>/batch_upload', methods=['POST'])
def batch_upload(schema: str, table: str):
    try:
        conn = g.db_conn
        resolved_names = _resolve_table_casing(conn, schema, table)
        if not resolved_names:
            return jsonify({"error": f"Table '{schema}.{table}' not found or inaccessible."}), 404
        actual_schema, actual_table = resolved_names

        records = request.get_json()
        if not records or not isinstance(records, list):    
            return jsonify({"error": "Invalid data format. Expected a list of records."}), 400
            
        if not records:
            return jsonify({"success": True, "inserted_rows": 0}), 200

        first_record_keys = list(records[0].keys())
        processed_records_for_insertion = []

        for record in records:
            if set(record.keys()) != set(first_record_keys):
                return jsonify({"error": "All records in batch must have the same keys."}), 400

            temp_record = record.copy()
            if (actual_schema.lower() == 'reference' and actual_table.lower() == 'personal') or \
               (actual_schema.lower() == 'lims' and actual_table.lower() == 'customers') or \
               (actual_schema.lower() == 'lims' and actual_table.lower() == 'external_contacts'):
                if 'password' in temp_record and temp_record['password']:
                    hashed_password = bcrypt.hashpw(temp_record['password'].encode('utf-8'), bcrypt.gensalt())
                    temp_record['password_hash'] = hashed_password.decode('utf-8')
                temp_record.pop('password', None)

            processed_records_for_insertion.append({k: (v if v != '' else None) for k, v in temp_record.items()})

        columns = list(processed_records_for_insertion[0].keys())
        column_names = ', '.join([f'"{col}"' for col in columns])
        
        data_tuples: List[Tuple[Any, ...]] = []
        for record in processed_records_for_insertion:
            row = []
            for col in columns:
                val = record.get(col)
                row.append(None if val == '' else val)
            data_tuples.append(tuple(row))

        query_template = f"INSERT INTO \"{actual_schema}\".\"{actual_table}\" ({column_names}) VALUES %s"
        
        with conn.cursor() as cur:
            print(f"Executing batch_upload query: {query_template} with {len(data_tuples)} records.")
            psycopg2.extras.execute_values(cur, query_template, data_tuples)
            conn.commit()
        return jsonify({"success": True, "inserted_rows": len(records)}), 201
    except Exception as e:    
        if conn:
            conn.rollback()
        print(f"Error during batch upload for {schema}.{table}: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

# --- Static File Serving ---
@app.route('/')
def root():    
    return redirect(url_for('serve_static', filename='login.html'))

@app.route('/<path:filename>')
def serve_static(filename: str):
    return send_from_directory(app.static_folder, filename)

# --- Server Run ---
if __name__ == '__main__':
    host: str = '0.0.0.0'
    port: int = 5200

    print("="*60 + f"\n TIFI LIMS Backend Server ".center(60, "=") + "\n" + " Serving Multi-Table Login ".center(60, "=") + "\n" + "="*60)
    print(f" -> Serving LIMS frontend from: {os.path.abspath(STATIC_FOLDER)}")
    print(f" -> API listening on http://{host}:{port}{API_PREFIX}/")
    print(f" -> Access the UI at http://127.0.0.1:{port}")
    print("="*60)

    if FLASK_ENV == "development":
        app.run(host=host, port=port, debug=True)
    else:
        serve(app, host=host, port=port)