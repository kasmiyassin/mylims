from flask import Flask, request, jsonify, session, send_from_directory, redirect, url_for, g
from flask_cors import CORS
from waitress import serve
import os
import bcrypt
import base64
import json # Import json module
from typing import Any, Dict, List, Optional, Tuple, Union
from datetime import datetime, timedelta, time
import psycopg2
from psycopg2 import sql, extras
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

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
API_PREFIX: str = os.getenv('API_PREFIX', '/api') # e.g., '/api', '/tifi-lims/api'

app = Flask(__name__, static_folder=STATIC_FOLDER)
app.secret_key = SECRET_KEY
# Enable CORS for all routes, allowing credentials (cookies/sessions)
CORS(app, supports_credentials=True)

# --- Primary Key Mapping ---
# Maps (schema_name_lower, table_name_lower) to their primary key column name (case-sensitive as in DB).
# This is crucial for generic GET by ID, and now, to identify all parts of a composite PK.
# The value for composite PKs should be a list of column names, not a single string.
PK_MAPPING: Dict[Tuple[str, str], Union[str, List[str]]] = {
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
    ('lims', 'project_persons'): ['project_id', 'person_id'], # Composite PK
    ('lims', 'cruises'): 'cruise_id',
    ('lims', 'workflows'): 'workflow_id',
    ('lims', 'permits'): 'permit_id',
    ('lims', 'primers'): 'primer_id',
    ('lims', 'sop'): 'sop_id',
    ('lims', 'workflow_steps'): ['workflow_id', 'step_number'], # Composite PK
    ('lims', 'equipment'): 'equipment_id',
    ('lims', 'suppliers'): 'supplier_id',
    ('lims', 'inventory_items'): 'item_id',
    ('lims', 'orders'): 'fi_order_nr',
    ('lims', 'reagents'): 'reagent_id',
    ('lims', 'publication_type'): 'publication_type_id',
    ('lims', 'publications'): 'publication_id',

    # Schema: Lab
    ('lab', 'storage'): 'storage_id',
    ('lab', 'experiments'): ['experiment_id', 'experiment_date'], # Composite PK
    ('lab', 'experiments_projects'): 'experiment_project_id', # Serial PK
    ('lab', 'protocol_runs'): 'protocol_run_id', # Primary key for protocol_runs
    ('lab', 'sampling'): ['sampling_id', 'sampling_date'], # Composite PK
    ('lab', 'master_samples'): 'sample_id',
    ('lab', 'samples'): ['sample_id', 'sampling_date'], # Composite PK
    ('lab', 'fishing'): ['fishing_id', 'sampling_date'], # Composite PK
    ('lab', 'storage_log'): 'log_id', # Serial PK
    ('lab', 'fish'): ['sample_id', 'sampling_date'], # Composite PK
    ('lab', 'tissue'): ['sample_id', 'experiment_date'], # Composite PK
    ('lab', 'otoliths'): ['otolith_id', 'experiment_date'], # Composite PK
    ('lab', 'dna'): ['sample_id', 'experiment_date'], # Composite PK
    ('lab', 'rna'): ['sample_id', 'experiment_date'], # Composite PK
    ('lab', 'sediments'): ['sample_id', 'experiment_date'], # Composite PK
    ('lab', 'water'): ['sample_id', 'experiment_date'], # Composite PK
    ('lab', 'experiments_samples'): ['experiment_id', 'sample_id', 'experiment_date'], # Composite PK
    ('lab', 'dissections'): ['dissection_id', 'dissection_date'], # Composite PK
    ('lab', 'extraction'): ['extraction_id', 'extraction_date'], # Composite PK
    ('lab', 'nanodrop'): ['nanodrop_id', 'measurement_date'], # Composite PK
    ('lab', 'qubit'): ['qubit_id', 'measurement_date'], # Composite PK
    ('lab', 'tapestation'): ['tapestation_id', 'measurement_date'], # Composite PK
    ('lab', 'pcr'): ['pcr_id', 'pcr_date'], # Composite PK
    ('lab', 'gelelectrophoresis'): ['gelelectrophoresis_id', 'run_date'], # Composite PK
    ('lab', 'qpcr'): ['qpcr_id', 'qpcr_date'], # Composite PK
    ('lab', 'library'): ['library_id', 'prep_date'], # Composite PK
    ('lab', 'sequencing'): ['sequencing_id', 'sequencing_date'], # Composite PK
    ('lab', 'datasets'): ['dataset_id', 'reception_date'], # Composite PK

    # Schema: Bioinformatics
    ('bioinformatics', 'reference_databases'): 'db_id',
    ('bioinformatics', 'analysis_pipelines'): 'pipeline_id',
    ('bioinformatics', 'analysis_runs'): ['run_id', 'run_date'], # Composite PK
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
    ('lims', 'project_personnel_view'): ['project_person_id'], # Added this view PK
    ('lims', 'order_details_view'): ['fi_order_nr'], # Added this view PK
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
# Modified get_pk_columns to return a list of PK column names
def get_pk_columns(schema: str, table: str) -> List[str]:
    pk_info = PK_MAPPING.get((schema.lower(), table.lower()))
    if pk_info is None:
        print(f"WARNING: No primary key mapping found for {schema}.{table}. Defaulting to ['nr']. "
              "Please ensure PK_MAPPING is correct and matches database column casing.")
        return ['nr']
    if isinstance(pk_info, str):
        return [pk_info]
    return pk_info

def transform_row_for_json(row: Dict[str, Any]) -> Dict[str, Any]:
    new_row = dict(row)
    for key, value in new_row.items():
        if isinstance(value, memoryview):
            new_row[key] = base64.b64encode(value.tobytes()).decode('utf-8')
        elif isinstance(value, bytes):
            new_row[key] = base64.b64encode(value).decode('utf-8')
        elif isinstance(value, time): # Handle datetime.time objects
            new_row[key] = str(value)
        # RealDictCursor usually converts JSONB to Python dicts automatically,
        # so no special handling needed for output here unless it's still a string.
        # If it's a string that should be a dict, it implies it wasn't parsed by RealDictCursor.
        elif isinstance(value, str) and (key.endswith('_jsonb') or key == 'run_details'): # Heuristic for JSONB columns
            try:
                new_row[key] = json.loads(value)
            except json.JSONDecodeError:
                pass # Keep as string if not valid JSON
    return new_row

# --- Database Schema/Table Casing Resolver ---
_resolved_names_cache: Dict[Tuple[str, str], Tuple[str, str]] = {}
_column_types_cache: Dict[Tuple[str, str], Dict[str, str]] = {} # Cache for column types

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

def _get_column_types(conn, schema: str, table: str) -> Dict[str, str]:
    cache_key = (schema.lower(), table.lower())
    if cache_key in _column_types_cache:
        return _column_types_cache[cache_key]

    query = """
        SELECT column_name, data_type
        FROM information_schema.columns
        WHERE table_schema = %s AND table_name = %s;
    """
    column_types = {}
    try:
        with conn.cursor() as cur:
            cur.execute(query, (schema, table))
            for row in cur.fetchall():
                column_types[row[0]] = row[1]
        _column_types_cache[cache_key] = column_types
    except Exception as e:
        print(f"Error fetching column types for {schema}.{table}: {e}")
    return column_types


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
            (search_pattern, search_pattern)
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
            (search_term, search_pattern, search_pattern)
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
    """
    Fetches key statistics for the dashboard.
    Updated to reflect specific requests for total samples, storage occupancy,
    experiments by month, and most active personnel.
    """
    conn = g.db_conn
    stats = {}
    try:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            # 1. Active Projects
            cur.execute("SELECT COUNT(*) AS active_projects FROM \"lims\".\"projects\" WHERE \"status_id\" = 'Active';")
            stats['active_projects'] = cur.fetchone()['active_projects']

            # 2. Total Samples (including children/master samples from relevant tables)
            # This is a more comprehensive count across all sample-related tables.
            # Master_samples is the most direct total unique samples.
            cur.execute("SELECT COUNT(*) AS total_samples FROM \"lab\".\"master_samples\";")
            stats['total_samples'] = cur.fetchone()['total_samples']

            # 3. Experiments this Month
            current_month_start = datetime.now().replace(day=1, hour=0, minute=0, second=0, microsecond=0)
            cur.execute("""
                SELECT COUNT(*) AS experiments_this_month
                FROM "lab"."experiments"
                WHERE "experiment_date" >= %s;
            """, (current_month_start.date(),))
            stats['experiments_this_month'] = cur.fetchone()['experiments_this_month']

            # 4. Active Order Number (replacing Reagents Expiring)
            cur.execute("""
                SELECT COUNT(*) AS active_orders
                FROM "lims"."orders"
                WHERE "status_id" = 'Active';
            """)
            stats['active_orders'] = cur.fetchone()['active_orders']

            # 5. How much storage is full (number of storage units with assigned samples)
            cur.execute("""
                SELECT COUNT(DISTINCT storage_id) AS occupied_storage_units
                FROM "lab"."samples"
                WHERE storage_id IS NOT NULL AND storage_position IS NOT NULL;
            """)
            stats['occupied_storage_units'] = cur.fetchone()['occupied_storage_units']

            # 6. Total SOPs (from lims.sop)
            cur.execute("SELECT COUNT(*) AS total_sops FROM \"lims\".\"sop\";")
            stats['total_sops'] = cur.fetchone()['total_sops']
            
            # 7. Total Experiments (overall)
            cur.execute("SELECT COUNT(*) AS total_experiments FROM \"lab\".\"experiments\";")
            stats['total_experiments'] = cur.fetchone()['total_experiments']

            # 8. Most Active Person (example: based on most audit log entries in the last 90 days)
            ninety_days_ago = (datetime.now() - timedelta(days=90)).isoformat()
            cur.execute("""
                SELECT user_id, COUNT(*) AS activity_count
                FROM "audit"."log"
                WHERE action_timestamp >= %s AND user_id IS NOT NULL AND user_id != 'system_user'
                GROUP BY user_id
                ORDER BY activity_count DESC
                LIMIT 1;
            """, (ninety_days_ago,))
            most_active_person = cur.fetchone()
            stats['most_active_person'] = most_active_person['user_id'] if most_active_person else 'N/A'
            stats['most_active_person_activity_count'] = most_active_person['activity_count'] if most_active_person else 0

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

@app.route(f'{API_PREFIX}/table/<string:schema>/<string:table>/schema', methods=['GET'])
def get_table_schema(schema: str, table: str):
    """
    Fetches the schema (column names and data types) for a given table.
    """
    try:
        conn = g.db_conn
        resolved_names = _resolve_table_casing(conn, schema, table)
        if not resolved_names:
            return jsonify({"error": f"Table or view '{schema}.{table}' not found or inaccessible."}), 404
        
        actual_schema, actual_table = resolved_names

        query = """
            SELECT column_name, data_type, is_nullable, column_default
            FROM information_schema.columns
            WHERE table_schema = %s AND table_name = %s
            ORDER BY ordinal_position;
        """
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute(query, (actual_schema, actual_table))
            columns = cur.fetchall()
        
        # Add primary key information to the schema
        pk_columns = get_pk_columns(actual_schema, actual_table)
        for col in columns:
            col['is_primary_key'] = col['column_name'] in pk_columns

        return jsonify(columns), 200
    except Exception as e:
        print(f"Error fetching schema for {schema}.{table}: {e}")
        return jsonify({"error": str(e)}), 500


@app.route(f'{API_PREFIX}/table/<string:schema>/<string:table>', methods=['GET'])
def get_table_data(schema: str, table: str):
    try:
        conn = g.db_conn

        resolved_names = _resolve_table_casing(conn, schema, table)
        if not resolved_names:
            return jsonify({"error": f"Table or view '{schema}.{table}' not found or inaccessible."}), 404
        
        actual_schema, actual_table = resolved_names
        
        where_clauses: List[str] = []
        params: List[Any] = []
        
        # Extract filter parameters
        filter_project_id_value = request.args.get('filter_project_id')
        filter_experiment_id_value = request.args.get('filter_experiment_id')
        filter_experiment_date_value = request.args.get('filter_experiment_date')
        filter_sample_id_value = request.args.get('filter_sample_id')
        filter_sampling_date_value = request.args.get('filter_sampling_date')
        filter_protocol_id_value = request.args.get('filter_protocol_id') # NEW: for protocol runs
        exclude_status_id_value = request.args.get('exclude_status_id') # NEW: for excluding archived protocols

        base_query_select = f'SELECT "{actual_table}".*'
        base_query_from = f'FROM "{actual_schema}"."{actual_table}"'
        
        # Helper to parse date string to date object
        def parse_date_filter(date_str):
            try:
                return datetime.strptime(date_str, '%Y-%m-%d').date()
            except (ValueError, TypeError):
                return None

        # --- SPECIAL HANDLING FOR TABLES FILTERED BY experiment_id/date ---
        if filter_experiment_id_value and filter_experiment_date_value:
            filter_exp_date_obj = parse_date_filter(filter_experiment_date_value)

            if actual_schema.lower() == 'lab' and actual_table.lower() == 'experiments':
                where_clauses.append(f'"{actual_table}"."experiment_id" ILIKE %s')
                params.append(f'%{filter_experiment_id_value}%')
                where_clauses.append(f'"{actual_table}"."experiment_date" = %s')
                params.append(filter_exp_date_obj)
            elif actual_schema.lower() == 'lab' and actual_table.lower() in ['experiments_projects', 'experiments_samples', 'protocol_runs', 'dissections', 'extraction', 'nanodrop', 'qubit', 'tapestation', 'pcr', 'gelelectrophoresis', 'qpcr', 'library', 'sequencing', 'datasets', 'tissue', 'otoliths', 'dna', 'rna', 'sediments', 'water']:
                # These tables directly contain experiment_id and experiment_date
                where_clauses.append(f'"{actual_table}"."experiment_id" ILIKE %s')
                params.append(f'%{filter_experiment_id_value}%')
                where_clauses.append(f'"{actual_table}"."experiment_date" = %s')
                params.append(filter_exp_date_obj)
            elif actual_schema.lower() == 'bioinformatics' and actual_table.lower() == 'analysis_runs':
                base_query_from += f"""
                    JOIN "lab"."sequencing" AS S ON "{actual_table}".sequencing_id = S.sequencing_id 
                    AND "{actual_table}".sequencing_date = S.sequencing_date
                """
                where_clauses.append(f'S.experiment_id ILIKE %s')
                params.append(f'%{filter_experiment_id_value}%')
                where_clauses.append(f'S.experiment_date = %s')
                params.append(filter_exp_date_obj)
            elif actual_schema.lower() == 'bioinformatics' and actual_table.lower() == 'edna_assignments':
                base_query_from += f"""
                    JOIN "bioinformatics"."analysis_runs" AS AR ON "{actual_table}".run_id = AR.run_id 
                    AND "{actual_table}".run_date = AR.run_date
                    JOIN "lab"."sequencing" AS S ON AR.sequencing_id = S.sequencing_id 
                    AND AR.sequencing_date = S.sequencing_date
                """
                where_clauses.append(f'S.experiment_id ILIKE %s')
                params.append(f'%{filter_experiment_id_value}%')
                where_clauses.append(f'S.experiment_date = %s')
                params.append(filter_exp_date_obj)
        
        # --- SPECIAL HANDLING FOR TABLES FILTERED BY sample_id/sampling_date ---
        elif filter_sample_id_value:
            if actual_schema.lower() == 'lab' and actual_table.lower() == 'samples':
                # Main samples table, direct filter
                where_clauses.append(f'"{actual_table}"."sample_id" ILIKE %s')
                params.append(f'%{filter_sample_id_value}%')
                if filter_sampling_date_value:
                    filter_samp_date_obj = parse_date_filter(filter_sampling_date_value)
                    where_clauses.append(f'"{actual_table}"."sampling_date" = %s')
                    params.append(filter_samp_date_obj)
            elif actual_schema.lower() == 'lab' and actual_table.lower() in ['fish', 'fishing', 'storage_log']:
                # These tables directly contain sample_id (or sampling_id which is related to sample_id)
                # and sampling_date
                where_clauses.append(f'"{actual_table}"."sample_id" ILIKE %s') # Assuming sample_id for fish, storage_log
                params.append(f'%{filter_sample_id_value}%')
                if filter_sampling_date_value:
                    filter_samp_date_obj = parse_date_filter(filter_sampling_date_value)
                    where_clauses.append(f'"{actual_table}"."sampling_date" = %s')
                    params.append(filter_samp_date_obj)
                # Special case for 'fishing' table which uses 'sampling_id'
                if actual_table.lower() == 'fishing':
                    # Need to join to lab.samples to filter by sample_id
                    base_query_from += f"""
                        JOIN "lab"."samples" AS S ON "{actual_table}".sampling_id = S.sampling_id
                        AND "{actual_table}".sampling_date = S.sampling_date
                    """
                    where_clauses.append(f'S.sample_id ILIKE %s')
                    params.append(f'%{filter_sample_id_value}%')
                    if filter_sampling_date_value:
                        filter_samp_date_obj = parse_date_filter(filter_sampling_date_value)
                        where_clauses.append(f'S.sampling_date = %s')
                        params.append(filter_samp_date_obj)
            elif actual_schema.lower() == 'lab' and actual_table.lower() == 'sampling':
                # Sampling table can be filtered by sample_id via join
                base_query_from += f"""
                    JOIN "lab"."samples" AS S ON "{actual_table}".sampling_id = S.sampling_id
                    AND "{actual_table}".sampling_date = S.sampling_date
                """
                where_clauses.append(f'S.sample_id ILIKE %s')
                params.append(f'%{filter_sample_id_value}%')
                if filter_sampling_date_value:
                    filter_samp_date_obj = parse_date_filter(filter_sampling_date_value)
                    where_clauses.append(f'S.sampling_date = %s')
                    params.append(filter_samp_date_obj)
            elif actual_schema.lower() == 'lab' and actual_table.lower() in ['tissue', 'otoliths', 'dna', 'rna', 'sediments', 'water', 'experiments_samples', 'dissections', 'extraction', 'nanodrop', 'qubit', 'tapestation', 'pcr', 'gelelectrophoresis', 'qpcr', 'library', 'sequencing']:
                # These tables have sample_id and experiment_id/date, but can be filtered by sample_id directly
                where_clauses.append(f'"{actual_table}"."sample_id" ILIKE %s')
                params.append(f'%{filter_sample_id_value}%')
                # No additional date filter added here as they are partitioned by experiment_date, not sampling_date
            elif actual_schema.lower() == 'bioinformatics' and actual_table.lower() == 'analysis_runs':
                # analysis_runs is linked to samples via sequencing
                base_query_from += f"""
                    JOIN "lab"."sequencing" AS SEQ ON "{actual_table}".sequencing_id = SEQ.sequencing_id
                    AND "{actual_table}".sequencing_date = SEQ.sequencing_date
                """
                where_clauses.append(f'SEQ.sample_id ILIKE %s')
                params.append(f'%{filter_sample_id_value}%')
            elif actual_schema.lower() == 'bioinformatics' and actual_table.lower() == 'edna_assignments':
                # edna_assignments directly has sample_id
                where_clauses.append(f'"{actual_table}"."sample_id" ILIKE %s')
                params.append(f'%{filter_sample_id_value}%')
            
        # --- SPECIAL HANDLING FOR lims.projects WHEN FILTERED BY project_id ---
        elif actual_schema.lower() == 'lims' and actual_table.lower() == 'projects' and filter_project_id_value:
            # Modify the base query to perform a JOIN with experiments_projects
            base_query_from += f"""
                JOIN "lab"."experiments_projects" AS EP ON "{actual_table}".project_id = EP.project_id
            """
            # Add the project_id filter to the WHERE clause using the junction table alias
            where_clauses.append(f'EP.project_id ILIKE %s')
            params.append(f'%{filter_project_id_value}%')
            
        # --- NEW: Handle filter_protocol_id for lab.protocol_runs ---
        if filter_protocol_id_value and actual_schema.lower() == 'lab' and actual_table.lower() == 'protocol_runs':
            where_clauses.append(f'"{actual_table}"."protocol_id" = %s')
            params.append(filter_protocol_id_value)

        # --- NEW: Handle exclude_status_id filter ---
        if exclude_status_id_value:
            # This applies to any table that has a 'status_id' column
            where_clauses.append(f'"{actual_table}"."status_id" != %s')
            params.append(exclude_status_id_value)


        order_by_column: Optional[str] = None
        order_direction: str = 'ASC'

        # Iterate through all query arguments to apply filters, skipping already handled ones
        for key, value in request.args.items():
            if not value:
                continue
            
            # Skip filters already handled by special blocks
            if (key == 'filter_project_id' and filter_project_id_value) or \
               (key == 'filter_experiment_id' and filter_experiment_id_value) or \
               (key == 'filter_experiment_date' and filter_experiment_date_value) or \
               (key == 'filter_sample_id' and filter_sample_id_value) or \
               (key == 'filter_sampling_date' and filter_sampling_date_value) or \
               (key == 'filter_protocol_id' and filter_protocol_id_value) or \
               (key == 'exclude_status_id' and exclude_status_id_value): # Exclude this from generic parsing
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
            # Specific filter for 'expire_date_within_30_days' for reagents dashboard stat
            elif key == 'filter_expire_date_within_30_days' and value.lower() == 'true':
                where_clauses.append(f'"expire_date" BETWEEN CURRENT_DATE AND CURRENT_DATE + interval \'30 day\'')
                continue # No param needed for this one

            # Standard list of filterable columns (ensure it contains all columns you might filter by)
            filterable_columns = [
                'sample_id', 'status_id', 'sop_id', 'person_id', 'project_id', 
                'room_id', 'vessel_id', 'region_id', 'ecosystem_id', 'category_id', 'sample_type_id', 'gene_id', 'taxon_id', 'species_id', 'unit_id', 
                'contact_id', 'customer_id', 'workflow_id', 'permit_id', 'primer_id', 'step_number', 'equipment_id', 'supplier_id', 'item_id', 'fi_order_nr', 'reagent_id', 'publication_type_id', 'publication_id', 
                'storage_id', 'experiment_id', 'experiment_project_id', 'protocol_run_id', 'sampling_id', 'master_sample_id', 'log_id', 'fishing_id', 'otolith_id', 'dataset_id', 
                'db_id', 'pipeline_id', 'run_id', 'assignment_id', 
                'external_name', 'title', 'full_name', 'customer_name', 'experiment_title', 'reagent_complete_name', 'lot', 'de_name', 'en_name', 'sample_type_abrv', 'workflow_name', 'pipeline_name', 'db_name', 'item_name', 'supplier_name', 'vessel_name', 'region_abrv', 'ecosystem_abrv', 'unit_name', 'unit_abbreviation', 'pi_person_id', 'funder', 'temperature_c', 'box', 'freezer', 'sex', 'stomach_contents_jsonb',
                'mail', 'protocol_text', # Added protocol_text for filtering if needed
                'path', 
                # Date/Timestamp fields for filtering
                'reception_date', 'experiment_date', 'dissection_date', 'extraction_date', 'measurement_date', 'pcr_date', 'run_date', 'prep_date', 'sequencing_date', 'order_date', 'expire_date', 'date_publication', 'date_submission', 'valid_from', 'valid_to', 'link_date', 'move_date', 'action_timestamp', 'created_at', 'date_realise', 'sampling_date'
            ]
            
            # Handling date/year filters
            if key.startswith('filter_') and (key.endswith('_month') or key.endswith('_year')):
                col_name_raw = key[len('filter_'):]
                col_name = col_name_raw.replace('_month', '').replace('_year', '') # Get base column name

                if col_name in filterable_columns: # Ensure the base column is filterable
                    if key.endswith('_month'):
                        try:
                            start_date_of_month = datetime.strptime(value, '%Y-%m').date()
                            end_date_of_month = (start_date_of_month.replace(day=28) + timedelta(days=4)).replace(day=1) - timedelta(days=1)
                            where_clauses.append(f'"{col_name}" BETWEEN %s AND %s')
                            params.extend([start_date_of_month, end_date_of_month])
                        except ValueError:
                            print(f"Warning: Invalid date format for month filter '{value}'. Skipping filter.")
                    elif key.endswith('_year'):
                        try:
                            start_date_of_year = datetime.strptime(value, '%Y').date()
                            end_date_of_year = start_date_of_year.replace(year=start_date_of_year.year + 1) - timedelta(days=1)
                            where_clauses.append(f'"{col_name}" BETWEEN %s AND %s')
                            params.extend([start_date_of_year, end_date_of_year])
                        except ValueError:
                            print(f"Warning: Invalid date format for year filter '{value}'. Skipping filter.")
                else:
                    print(f"Warning: Date filter by non-filterable column '{col_name}' skipped.")
            elif key.startswith('filter_'): # General text/ID filters
                col_name = key[len('filter_'):]
                if col_name in filterable_columns:
                    where_clauses.append(f'"{col_name}" ILIKE %s')
                    params.append(f'%{value}%')
                else:
                    print(f"Warning: Filter by non-filterable column '{col_name}' skipped.")
            elif key in filterable_columns: # Direct equality match for non-filter_ prefixed keys
                where_clauses.append(f'"{key}" = %s')
                params.append(value)

        # Construct the full query
        query = f"{base_query_select} {base_query_from}"
        if where_clauses:
            query += f" WHERE {' AND '.join(where_clauses)}"
            
        # Add ORDER BY clause
        if order_by_column:
            # Ensure order_by_column is qualified if it's from a joined table
            # This logic needs to be careful to apply to the correct alias or original table
            if order_by_column in ['experiment_id', 'experiment_date'] and (actual_schema.lower() == 'bioinformatics' and actual_table.lower() in ['analysis_runs', 'edna_assignments']):
                # For these cases, order by the joined table 'S' (sequencing)
                quoted_order_by_column = f'S."{order_by_column}"' 
            elif order_by_column in ['sample_id', 'sampling_date'] and (actual_schema.lower() == 'lab' and actual_table.lower() in ['fishing', 'sampling']):
                 # For fishing/sampling, if filtering by sample_id, order by S.sample_id
                if filter_sample_id_value: # Only if a join with S is active
                    quoted_order_by_column = f'S."{order_by_column}"'
                else: # Otherwise, order by the table's own column
                    quoted_order_by_column = f'"{actual_table}"."{order_by_column}"'
            else:
                quoted_order_by_column = f'"{actual_table}"."{order_by_column}"'
            query += f' ORDER BY {quoted_order_by_column} {order_direction}'
            
        # Add LIMIT and OFFSET clauses
        limit = request.args.get('limit', type=int)
        offset = request.args.get('offset', type=int)
        if limit is not None:
            query += f" LIMIT %s"
            params.append(limit)
        if offset is not None:
            query += f" OFFSET %s"
            params.append(offset)

        query += ";" # Finalize the query

        print(f"Executing GET query: {query} with params: {params}")
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute(query, params)
            data = cur.fetchall()
        
        # Transform data for JSON serialization (handling bytea, time types)
        processed_data = [transform_row_for_json(row) for row in data]
        
        return jsonify(processed_data), 200
    except Exception as e:
        print(f"Error fetching table data for {schema}.{table}: {e}")
        return jsonify({"error": str(e)}), 500
            
@app.route(f'{API_PREFIX}/table/<string:schema>/<string:table>', methods=['POST'])
def create_record(schema: str, table: str):
    conn = g.db_conn
    try:
        resolved_names = _resolve_table_casing(conn, schema, table)
        if not resolved_names:
            return jsonify({"error": f"Table '{schema}.{table}' not found or inaccessible."}), 404
        actual_schema, actual_table = resolved_names

        # Get column types for JSONB handling
        column_types = _get_column_types(conn, actual_schema, actual_table)

        # Check if the request contains JSON data or form data (for file uploads)
        if request.is_json:
            data = request.get_json()
        else:
            data = request.form.to_dict()

        # Handle file attachments separately from JSON data
        files = request.files
        if 'attachment' in files and files['attachment'].filename != '':
            data['attachment'] = psycopg2.Binary(files['attachment'].read())
        # Convert empty string from form/json for 'attachment' to None
        elif 'attachment' in data and (data['attachment'] == '' or (isinstance(data['attachment'], dict) and not data['attachment'])):
            data['attachment'] = None
            
        if not data and not files:
            return jsonify({"error": "No data provided"}), 400
            
        if (actual_schema.lower() == 'reference' and actual_table.lower() == 'personal') or \
           (actual_schema.lower() == 'lims' and actual_table.lower() == 'customers') or \
           (actual_schema.lower() == 'lims' and actual_table.lower() == 'external_contacts'):
            if 'password' in data and data['password']:
                hashed_password = bcrypt.hashpw(data['password'].encode('utf-8'), bcrypt.gensalt())
                data['password_hash'] = hashed_password.decode('utf-8')
            data.pop('password', None)
            
        # Extract custom fields for linked tables before filtering for main table insertion
        project_ids_str = None
        sample_ids_str = None
        if actual_schema.lower() == 'lab' and actual_table.lower() == 'experiments':
            project_ids_str = data.pop('project_ids', None) # Pop to remove from main table columns
            sample_ids_str = data.pop('sample_ids', None) # Pop to remove from main table columns

        # Filtered data now only contains columns that map directly to the DB table
        # Convert empty strings to None, and ensure attachment is handled.
        filtered_data = {}
        for k, v in data.items():
            if k == 'attachment':
                # 'attachment' is already handled above to be bytes, None, or psycopg2.Binary
                filtered_data[k] = v
            elif v == '':
                filtered_data[k] = None
            elif column_types.get(k) == 'jsonb' and isinstance(v, str):
                try:
                    filtered_data[k] = json.loads(v)
                except json.JSONDecodeError:
                    print(f"WARNING: Invalid JSON for column '{k}'. Storing as None. Value: {v}")
                    filtered_data[k] = None # Store None if JSON is invalid
            else:
                filtered_data[k] = v
            
        columns = filtered_data.keys()
        values = list(filtered_data.values())
        
        column_names = ', '.join([f'"{col}"' for col in columns])
        value_placeholders = ', '.join(['%s'] * len(values))
        
        # Construct the INSERT query for the main table
        query = f'INSERT INTO "{actual_schema}"."{actual_table}" ({column_names}) VALUES ({value_placeholders}) RETURNING *;'
        
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            print(f"Executing POST query: {query} with values: {values}")
            cur.execute(query, values)
            new_record = cur.fetchone()
            
            # Handle linked tables specifically for 'lab.experiments'
            if actual_schema.lower() == 'lab' and actual_table.lower() == 'experiments' and new_record:
                experiment_id = new_record['experiment_id']
                experiment_date = new_record['experiment_date']

                # Insert into experiments_projects
                if project_ids_str:
                    project_list = [p.strip() for p in project_ids_str.split(';') if p.strip()]
                    for project_id in project_list:
                        try:
                            # Use current_date for link_date or get it from form if available
                            cur.execute(
                                'INSERT INTO "lab"."experiments_projects" ("experiment_id", "experiment_date", "project_id", "link_date") VALUES (%s, %s, %s, CURRENT_DATE);',
                                (experiment_id, experiment_date, project_id)
                            )
                        except Exception as e:
                            print(f"  Warning: Could not link project {project_id} to experiment {experiment_id}: {e}")
                            # Log error but allow other links/main record to proceed

                # Insert into experiments_samples
                if sample_ids_str:
                    sample_list = [s.strip() for s in sample_ids_str.split(';') if s.strip()]
                    for sample_id in sample_list:
                        try:
                            cur.execute(
                                'INSERT INTO "lab"."experiments_samples" ("experiment_id", "experiment_date", "sample_id") VALUES (%s, %s, %s);',
                                (experiment_id, experiment_date, sample_id)
                            )
                        except Exception as e:
                            print(f"  Warning: Could not link sample {sample_id} to experiment {experiment_id}: {e}")
                            # Log error but allow other links/main record to proceed
            
            conn.commit() # Commit all changes in the transaction
        return jsonify(transform_row_for_json(new_record)), 201
    except Exception as e:    
        if conn:
            conn.rollback() # Rollback all changes if any error occurs
        print(f"Error creating record in {schema}.{table}: {e}")
        return jsonify({"error": str(e)}), 500
            
@app.route(f'{API_PREFIX}/table/<string:schema>/<string:table>', methods=['PUT'])
def update_record(schema: str, table: str):
    try:
        conn = g.db_conn
        resolved_names = _resolve_table_casing(conn, schema, table)
        if not resolved_names:
            return jsonify({"error": f"Table '{schema}.{table}' not found or inaccessible."}), 404
        actual_schema, actual_table = resolved_names

        pk_columns = get_pk_columns(schema, table) # Get all PK columns

        # Get column types for JSONB handling
        column_types = _get_column_types(conn, actual_schema, actual_table)

        # Collect PK values from query parameters
        pk_values_from_request = {}
        for pk_col in pk_columns:
            pk_val = request.args.get(pk_col)
            if pk_val is None:
                return jsonify({"error": f"Missing primary key component: {pk_col}"}), 400
            pk_values_from_request[pk_col] = pk_val

        # Check for file attachments first, if any
        files = request.files
        if 'attachment' in files and files['attachment'].filename != '':
            attachment_data = psycopg2.Binary(files['attachment'].read())
            data = request.form.to_dict() # Get other form fields
            data['attachment'] = attachment_data
        else:
            data = request.get_json()
            if not data:
                return jsonify({"error": "No data provided"}), 400
            # Handle case where attachment might be sent as an empty dict or empty string in JSON
            if 'attachment' in data and (data['attachment'] == '' or (isinstance(data['attachment'], dict) and not data['attachment'])):
                data['attachment'] = None


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
            # Skip custom frontend-only fields for direct DB update.
            # Also skip PK columns if they are sent in the body (they are handled by WHERE clause).
            if key in ['project_ids', 'sample_ids', 'linked_person_ids'] or key in pk_columns: # Added linked_person_ids
                continue
            
            # Handle JSONB columns for input
            if column_types.get(key) == 'jsonb' and isinstance(val, str):
                try:
                    set_clauses.append(f'"{key}" = %s')
                    values.append(json.loads(val))
                except json.JSONDecodeError:
                    print(f"WARNING: Invalid JSON for column '{key}'. Storing as None. Value: {val}")
                    set_clauses.append(f'"{key}" = %s')
                    values.append(None) # Store None if JSON is invalid
            else:
                set_clauses.append(f'"{key}" = %s')
                values.append(None if val == '' else val)    
        
        if not set_clauses:
            return jsonify({"error": "No fields to update"}), 400

        # Construct WHERE clause for composite primary key
        where_pk_clauses = []
        for pk_col in pk_columns:
            where_pk_clauses.append(f'"{pk_col}" = %s')
            pk_val = pk_values_from_request[pk_col]
            # Special handling for date columns in PK comparison in backend
            if 'date' in pk_col.lower() and pk_val is not None:
                try:
                    # Attempt to parse date string into a date object if it's a date PK
                    pk_val = datetime.strptime(pk_val, '%Y-%m-%d').date()
                except ValueError:
                    # If parsing fails, use as string (let DB decide type compatibility if not strict)
                    pass
            values.append(pk_val) # Add PK values to the end of the 'values' list

        query = f'UPDATE "{actual_schema}"."{actual_table}" SET {", ".join(set_clauses)} WHERE {" AND ".join(where_pk_clauses)} RETURNING *;'
        
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


@app.route(f'{API_PREFIX}/table/<string:schema>/<string:table>', methods=['DELETE'])
def delete_record(schema: str, table: str):
    conn = g.db_conn
    try:
        resolved_names = _resolve_table_casing(conn, schema, table)
        if not resolved_names:
            return jsonify({"error": f"Table '{schema}.{table}' not found or inaccessible."}), 404
        actual_schema, actual_table = resolved_names

        pk_columns = get_pk_columns(schema, table) # Get all PK columns

        # Collect PK values from query parameters
        pk_values_from_request = []
        where_clauses = []
        for pk_col in pk_columns:
            pk_val = request.args.get(pk_col)
            if pk_val is None:
                return jsonify({"error": f"Missing primary key component for deletion: {pk_col}"}), 400
            
            # Special handling for date columns in PK comparison in backend
            if 'date' in pk_col.lower() and pk_val is not None:
                try:
                    pk_val = datetime.strptime(pk_val, '%Y-%m-%d').date()
                except ValueError:
                    pass # Keep as string if not a valid date format

            where_clauses.append(f'"{pk_col}" = %s')
            pk_values_from_request.append(pk_val)

        query = f'DELETE FROM "{actual_schema}"."{actual_table}" WHERE {" AND ".join(where_clauses)} RETURNING *;'
        
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            print(f"Executing DELETE query: {query} with params: {pk_values_from_request}")
            cur.execute(query, pk_values_from_request)
            deleted_record = cur.fetchone()
            conn.commit()
        
        if deleted_record:
            return jsonify({"success": True, "message": "Record deleted successfully."}), 200
        else:
            return jsonify({"error": "Record not found or could not be deleted."}), 404
    except Exception as e:
        if conn:
            conn.rollback()
        print(f"Error deleting record from {schema}.{table}: {e}")
        return jsonify({"error": str(e)}), 500

@app.route(f'{API_PREFIX}/table/<string:schema>/<string:table>/batch_upload', methods=['POST'])
def batch_upload(schema: str, table: str):
    conn = g.db_conn
    try:
        resolved_names = _resolve_table_casing(conn, schema, table)
        if not resolved_names:
            return jsonify({"error": f"Table '{schema}.{table}' not found or inaccessible."}), 404
        actual_schema, actual_table = resolved_names

        # Get column types for JSONB handling
        column_types = _get_column_types(conn, actual_schema, actual_table)

        records = request.get_json()
        if not records or not isinstance(records, list):    
            return jsonify({"error": "Invalid data format. Expected a list of records."}), 400
            
        if not records:
            return jsonify({"success": True, "inserted_rows": 0}), 200

        inserted_count = 0
        
        # Special handling for 'lab.experiments' due to linked tables
        if actual_schema.lower() == 'lab' and actual_table.lower() == 'experiments':
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
                for record_data in records: # Use record_data to avoid conflict with `record`
                    # Pop custom fields for linked tables (they are not part of main experiments table)
                    project_ids_str = record_data.pop('project_ids', None)
                    sample_ids_str = record_data.pop('sample_ids', None)

                    # Prepare data for main experiments table insertion
                    filtered_record = {}
                    for k, v in record_data.items():
                        if v == '':
                            filtered_record[k] = None
                        elif column_types.get(k) == 'jsonb' and isinstance(v, str):
                            try:
                                filtered_record[k] = json.loads(v)
                            except json.JSONDecodeError:
                                print(f"WARNING: Invalid JSON for column '{k}' during batch upload. Storing as None. Value: {v}")
                                filtered_record[k] = None
                        else:
                            filtered_record[k] = v
                    
                    # Handle password hashing if applicable (copied from create_record)
                    if (actual_schema.lower() == 'reference' and actual_table.lower() == 'personal') or \
                       (actual_schema.lower() == 'lims' and actual_table.lower() == 'customers') or \
                       (actual_schema.lower() == 'lims' and actual_table.lower() == 'external_contacts'):
                        if 'password' in filtered_record and filtered_record['password']:
                            hashed_password = bcrypt.hashpw(filtered_record['password'].encode('utf-8'), bcrypt.gensalt())
                            filtered_record['password_hash'] = hashed_password.decode('utf-8')
                        filtered_record.pop('password', None)
                    
                    # Handle attachment if applicable (copied from create_record, assuming it's already in the dict for batch)
                    # For batch upload, files would typically be base64 encoded strings in the JSON data,
                    # not actual Werkzeug FileStorage objects.
                    if 'attachment' in filtered_record and filtered_record['attachment'] == '':
                        filtered_record['attachment'] = None
                    elif 'attachment' in filtered_record and isinstance(filtered_record['attachment'], str):
                            # Assuming base64 encoded string from CSV/XLSX
                            try:
                                filtered_record['attachment'] = base64.b64decode(filtered_record['attachment'])
                            except Exception as e:
                                print(f"  Warning: Could not decode base64 attachment for record: {e}")
                                filtered_record['attachment'] = None # Set to None on error
                    elif 'attachment' in filtered_record and isinstance(filtered_record['attachment'], dict) and not filtered_record['attachment']:
                        filtered_record['attachment'] = None

                    columns = filtered_record.keys()
                    values = list(filtered_record.values())

                    column_names = ', '.join([f'"{col}"' for col in columns])
                    value_placeholders = ', '.join(['%s'] * len(values))
                    
                    insert_query = f'INSERT INTO "{actual_schema}"."{actual_table}" ({column_names}) VALUES ({value_placeholders}) RETURNING *;'
                    
                    try:
                        cur.execute(insert_query, values)
                        new_record = cur.fetchone()
                        inserted_count += 1

                        if new_record:
                            experiment_id = new_record['experiment_id']
                            experiment_date = new_record['experiment_date']

                            # Insert into experiments_projects
                            if project_ids_str:
                                project_list = [p.strip() for p in project_ids_str.split(';') if p.strip()]
                                for project_id in project_list:
                                    try:
                                        cur.execute(
                                            'INSERT INTO "lab"."experiments_projects" ("experiment_id", "experiment_date", "project_id", "link_date") VALUES (%s, %s, %s, CURRENT_DATE);',
                                            (experiment_id, experiment_date, project_id)
                                        )
                                    except Exception as e:
                                        print(f"  Warning: Could not link project {project_id} to experiment {experiment_id} during batch upload: {e}")

                            # Insert into experiments_samples
                            if sample_ids_str:
                                sample_list = [s.strip() for s in sample_ids_str.split(';') if s.strip()]
                                for sample_id in sample_list:
                                    try:
                                        cur.execute(
                                            'INSERT INTO "lab"."experiments_samples" ("experiment_id", "experiment_date", "sample_id") VALUES (%s, %s, %s);',
                                            (experiment_id, experiment_date, sample_id)
                                        )
                                    except Exception as e:
                                        print(f"  Warning: Could not link sample {sample_id} to experiment {experiment_id} during batch upload: {e}")
                    except Exception as e:
                        print(f"Error inserting individual record in batch for {actual_schema}.{actual_table}: {e}")
                        # If a record fails, it's rolled back, and the loop continues for the next record.
                        # The overall transaction will still commit for successful records.
                conn.commit() # Commit all changes after processing all records in the batch
        elif actual_schema.lower() == 'lims' and actual_table.lower() == 'projects': # Special handling for projects batch upload
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
                for record_data in records:
                    linked_person_ids_str = record_data.pop('linked_person_ids', None)

                    filtered_record = {}
                    for k, v in record_data.items():
                        if v == '':
                            filtered_record[k] = None
                        elif column_types.get(k) == 'jsonb' and isinstance(v, str):
                            try:
                                filtered_record[k] = json.loads(v)
                            except json.JSONDecodeError:
                                print(f"WARNING: Invalid JSON for column '{k}' during batch upload. Storing as None. Value: {v}")
                                filtered_record[k] = None
                        else:
                            filtered_record[k] = v

                    columns = filtered_record.keys()
                    values = list(filtered_record.values())
                    column_names = ', '.join([f'"{col}"' for col in columns])
                    value_placeholders = ', '.join(['%s'] * len(values))
                    insert_query = f'INSERT INTO "{actual_schema}"."{actual_table}" ({column_names}) VALUES ({value_placeholders}) RETURNING *;'

                    try:
                        cur.execute(insert_query, values)
                        new_project = cur.fetchone()
                        inserted_count += 1

                        if new_project and linked_person_ids_str:
                            project_id = new_project['project_id']
                            person_list = [p.strip() for p in linked_person_ids_str.split(';') if p.strip()]
                            for person_id in person_list:
                                try:
                                    cur.execute(
                                        'INSERT INTO "lims"."project_persons" ("project_id", "person_id", "link_date") VALUES (%s, %s, CURRENT_DATE);',
                                        (project_id, person_id)
                                    )
                                except Exception as e:
                                    print(f"  Warning: Could not link person {person_id} to project {project_id} during batch upload: {e}")
                    except Exception as e:
                        print(f"Error inserting individual project record in batch: {e}")
                conn.commit()
        else: # Original batch upload logic for other tables (no complex linked fields)
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
                
                # Handle attachment for non-experiments tables in batch, if present
                if 'attachment' in temp_record and temp_record['attachment'] == '':
                    temp_record['attachment'] = None
                elif 'attachment' in temp_record and isinstance(temp_record['attachment'], str):
                    try:
                        temp_record['attachment'] = base64.b64decode(temp_record['attachment'])
                    except Exception as e:
                        print(f"  Warning: Could not decode base64 attachment for record: {e}")
                        temp_record['attachment'] = None
                elif 'attachment' in temp_record and isinstance(temp_record['attachment'], dict) and not temp_record['attachment']:
                    temp_record['attachment'] = None

                # Handle JSONB fields for other tables in batch
                for k, v in temp_record.items():
                    if column_types.get(k) == 'jsonb' and isinstance(v, str):
                        try:
                            temp_record[k] = json.loads(v)
                        except json.JSONDecodeError:
                            print(f"WARNING: Invalid JSON for column '{k}' during batch upload. Storing as None. Value: {v}")
                            temp_record[k] = None

                processed_records_for_insertion.append({k: (v if v != '' else None) for k, v in temp_record.items()})

            columns = list(processed_records_for_insertion[0].keys())
            column_names = ', '.join([f'"{col}"' for col in columns])
            
            data_tuples: List[Tuple[Any, ...]] = []
            for record_data in processed_records_for_insertion: # Use record_data here as well
                row = []
                for col in columns:
                    val = record_data.get(col) # Get value from record_data
                    row.append(None if val == '' else val)
                data_tuples.append(tuple(row))

            query_template = f"INSERT INTO \"{actual_schema}\".\"{actual_table}\" ({column_names}) VALUES %s"
            
            with conn.cursor() as cur:
                print(f"Executing batch_upload query: {query_template} with {len(data_tuples)} records.")
                psycopg2.extras.execute_values(cur, query_template, data_tuples)
                conn.commit()
            inserted_count = len(records) # For non-experiments tables, all records are inserted in batch
            
        return jsonify({"success": True, "inserted_rows": inserted_count}), 201
    except Exception as e:    
        if conn:
            conn.rollback()
        print(f"Error during batch upload for {schema}.{table}: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@app.route(f'{API_PREFIX}/table/<string:schema>/<string:table>/batch_update', methods=['PUT'])
def batch_update(schema: str, table: str):
    conn = g.db_conn
    try:
        resolved_names = _resolve_table_casing(conn, schema, table)
        if not resolved_names:
            return jsonify({"error": f"Table '{schema}.{table}' not found or inaccessible."}), 404
        actual_schema, actual_table = resolved_names

        # Get column types for JSONB handling
        column_types = _get_column_types(conn, actual_schema, actual_table)

        records_to_update = request.get_json()
        if not records_to_update or not isinstance(records_to_update, list):
            return jsonify({"error": "Invalid data format. Expected a list of records for batch update."}), 400

        pk_columns = get_pk_columns(schema, table)
        if not pk_columns:
            return jsonify({"error": f"Primary key not defined for {schema}.{table}. Cannot perform batch update."}), 400

        updated_count = 0
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            for record_data in records_to_update:
                set_clauses: List[str] = []
                values: List[Any] = []
                pk_where_clauses: List[str] = []
                pk_values: List[Any] = []

                # Separate PK fields from update fields
                for key, val in record_data.items():
                    if key in pk_columns:
                        pk_where_clauses.append(f'"{key}" = %s')
                        # Handle date formatting for PKs if necessary (matches frontend sending format)
                        if 'date' in key.lower() and key in request.args and isinstance(request.args[key], str): # Check request.args for original PK value as string
                            try:
                                val = datetime.strptime(request.args[key], '%Y-%m-%d').date()
                            except ValueError:
                                pass # Keep as string if not a valid date format
                        pk_values.append(val)
                    else:
                        # Handle JSONB columns for input during batch update
                        if column_types.get(key) == 'jsonb' and isinstance(val, str):
                            try:
                                set_clauses.append(f'"{key}" = %s')
                                values.append(json.loads(val))
                            except json.JSONDecodeError:
                                print(f"WARNING: Invalid JSON for column '{key}' during batch update. Storing as None. Value: {val}")
                                set_clauses.append(f'"{key}" = %s')
                                values.append(None)
                        else:
                            set_clauses.append(f'"{key}" = %s')
                            values.append(None if val == '' else val)
                
                if not pk_where_clauses:
                    print(f"  Warning: Skipping record in batch update due to missing primary key(s): {record_data}")
                    continue # Skip this record if it doesn't have all PKs

                if not set_clauses:
                    print(f"  Warning: Skipping record in batch update as no update fields provided: {record_data}")
                    continue # Skip if no fields to update

                # Combine update values and PK values for query execution
                all_values = values + pk_values
                
                update_query = f'UPDATE "{actual_schema}"."{actual_table}" SET {", ".join(set_clauses)} WHERE {" AND ".join(pk_where_clauses)} RETURNING *;'
                
                try:
                    cur.execute(update_query, all_values)
                    if cur.fetchone():
                        updated_count += 1
                    else:
                        print(f"  Warning: Record not found for update in batch: {record_data}")
                except Exception as e:
                    print(f"  Error updating record in batch for {actual_schema}.{actual_table} (PK: {pk_values}): {e}")
                    # Continue processing other records even if one fails
            conn.commit()
            return jsonify({"success": True, "updated_rows": updated_count}), 200

    except Exception as e:
        if conn:
            conn.rollback()
        print(f"Error during batch update for {schema}.{table}: {e}")
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
    port: int = 5300

    print("="*60 + f"\n TIFI LIMS Backend Server ".center(60, "=") + "\n" + " Serving Multi-Table Login ".center(60, "=") + "\n" + "=".center(60, "="))
    print(f" -> Serving LIMS frontend from: {os.path.abspath(STATIC_FOLDER)}")
    print(f" -> API listening on http://{host}:{port}{API_PREFIX}/")
    print(f" -> Access the UI at http://127.0.0.1:{port}")
    print("="*60)

    if FLASK_ENV == "development":
        app.run(host=host, port=port, debug=True)
    else:
        serve(app, host=host, port=5300)