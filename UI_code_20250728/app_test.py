from flask import Flask, request, jsonify, session, send_from_directory, redirect, url_for, g
from flask_cors import CORS
from waitress import serve
import os
import bcrypt
import base64
import json
from typing import Any, Dict, List, Optional, Tuple, Union
from datetime import datetime, timedelta, time
import psycopg2
from psycopg2 import sql, extras
from dotenv import load_dotenv

load_dotenv()

DB_HOST: str = os.getenv('DB_HOST', '0.0.0.0')
DB_NAME: str = os.getenv('DB_NAME', 'wanderfische')
DB_USER: str = os.getenv('DB_USER', 'kasmi')
DB_PASS: str = os.getenv('DB_PASS', 'password')
SECRET_KEY: str = os.getenv('SECRET_KEY', 'a_very_secret_key_for_session_management_and_security')

STATIC_FOLDER: str = '.'
FLASK_ENV: str = os.getenv('FLASK_ENV', 'production')
API_PREFIX: str = os.getenv('API_PREFIX', '/api')

app = Flask(__name__, static_folder=STATIC_FOLDER)
app.secret_key = SECRET_KEY
CORS(app, supports_credentials=True)

PK_MAPPING: Dict[Tuple[str, str], Union[str, List[str]]] = {
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
    ('lims', 'external_contacts'): 'contact_id',
    ('lims', 'customers'): 'customer_id',
    ('lims', 'projects'): 'project_id',
    ('lims', 'project_persons'): ['project_id', 'person_id'],
    ('lab', 'storage'): 'storage_id',
    ('lims', 'cruises'): 'cruise_id',
    ('lims', 'workflows'): 'workflow_id',
    ('lims', 'permits'): 'permit_id',
    ('lims', 'primers'): 'primer_id',
    ('lims', 'sop'): 'sop_id',
    ('lims', 'workflow_steps'): ['workflow_id', 'step_number'],
    ('lims', 'equipment'): 'equipment_id',
    ('lims', 'suppliers'): 'supplier_id',
    ('lims', 'inventory_items'): 'item_id',
    ('lims', 'orders'): 'fi_order_nr',
    ('lims', 'reagents'): 'reagent_id',
    ('lims', 'publication_type'): 'publication_type_id',
    ('lims', 'publications'): 'publication_id',
    ('lab', 'experiments'): ['experiment_id', 'experiment_date'],
    ('lab', 'experiments_projects'): 'experiment_project_id',
    ('lab', 'protocol_runs'): 'protocol_run_id',
    ('lab', 'sampling'): ['sampling_id', 'sampling_date'],
    ('lab', 'master_samples'): 'sample_id',
    ('lab', 'parental_samples'): ['sample_id', 'sampling_date'],
    ('lab', 'fishing'): ['fishing_id', 'sampling_date'],
    ('lab', 'fish'): ['sample_id', 'sampling_date'],
    ('lab', 'tissue'): ['sample_id', 'experiment_date'],
    ('lab', 'otoliths'): ['otolith_id', 'experiment_date'],
    ('lab', 'dna'): ['sample_id', 'experiment_date'],
    ('lab', 'rna'): ['sample_id', 'experiment_date'],
    ('lab', 'sediments'): ['sample_id', 'experiment_date'],
    ('lab', 'water'): ['sample_id', 'experiment_date'],
    ('lab', 'experiments_samples'): ['experiment_id', 'sample_id', 'experiment_date'],
    ('lab', 'dissections'): ['dissection_id', 'dissection_date'],
    ('lab', 'extraction'): ['extraction_id', 'extraction_date'],
    ('lab', 'nanodrop'): ['nanodrop_id', 'measurement_date'],
    ('lab', 'qubit'): ['qubit_id', 'measurement_date'],
    ('lab', 'tapestation'): ['tapestation_id', 'measurement_date'],
    ('lab', 'pcr'): ['pcr_id', 'pcr_date'],
    ('lab', 'gelelectrophoresis'): ['gelelectrophoresis_id', 'run_date'],
    ('lab', 'qpcr'): ['qpcr_id', 'qpcr_date'],
    ('lab', 'library'): ['library_id', 'prep_date'],
    ('lab', 'sequencing'): ['sequencing_id', 'sequencing_date'],
    ('lab', 'datasets'): ['dataset_id', 'reception_date'],
    ('bioinformatics', 'reference_databases'): 'db_id',
    ('bioinformatics', 'analysis_pipelines'): 'pipeline_id',
    ('bioinformatics', 'analysis_runs'): ['run_id', 'run_date'],
    ('bioinformatics', 'edna_assignments'): 'assignment_id',
    ('projects', 'projectwanderfische_fishingdata'): ['fishing_record_id', 'record_date'],
    ('projects', 'projectwanderfische_fishcatch'): 'fish_catch_id',
    ('projects', 'projectwanderfische_mail'): 'mail_id',
    ('projects', 'projectwanderfische_conversation'): 'conversation_id',
    ('projects', 'projectwanderfische_chatmessage'): 'message_id',
    # Note: 'log' and 'master_samples' are generally not meant for direct CRUD via generic API,
    # but if needed, their PKs should be defined:
    ('lab', 'storage_log'): 'log_id', # Added for completeness as it was mentioned before
    ('lab', 'master_samples'): 'sample_id', # Added for completeness

    # Views (often read-only or handled by specific functions)
    ('reference', 'complete_species_taxon_view'): 'taxon_id',
    ('lab', 'detailed_samples_view'): 'sample_id', # Assuming sample_id is main identifier
    ('lims', 'project_overview_view'): 'project_id',
    ('lab', 'sample_workflow_progress_view'): 'sample_id',
    ('lims', 'reagent_status_view'): 'reagent_id',
    ('lab', 'sample_full_details_view'): ['sample_id', 'sampling_date'],
    ('lims', 'project_personnel_view'): ['project_id', 'person_id'],
    ('lims', 'order_details_view'): 'fi_order_nr',
    ('reference', 'complete_species_taxon_view'): 'taxon_id',
    ('lab', 'storage_inventory_view'): 'storage_id',
    ('lab', 'experiment_summary_view'): 'experiment_id',
    ('bioinformatics', 'analysis_results_summary'): ['run_id', 'run_date'],
    ('lims', 'project_financial_summary_view'): 'project_id',
    ('bioinformatics', 'full_analysis_results_view'): 'sample_id',
    ('lab', 'storage_occupancy_view'): 'storage_id',
    ('lims', 'project_comprehensive_summary_view'): 'project_id',
    ('lab', 'experiment_progress_overview_view'): 'experiment_id',
    ('lims', 'reagent_status_view'): 'reagent_id',
    ('reference', 'taxon_hierarchy_view'): 'taxon_id',
    ('lab', 'monthly_sample_reception_mv'): 'reception_month',
}

VIEW_TO_BASE_TABLE_MAPPING: Dict[str, str] = {
    'lab.detailed_samples_view': 'lab.parental_samples',
    'lims.project_overview_view': 'lims.projects',
    'lab.sample_workflow_progress_view': 'lab.parental_samples',
    'lims.reagent_status_view': 'lims.reagents',
    'lab.sample_full_details_view': 'lab.parental_samples',
    'lims.project_personnel_view': 'lims.project_persons',
    'lims.order_details_view': 'lims.orders',
    'reference.complete_species_taxon_view': 'reference.taxon', # Or reference.species
    'lab.storage_inventory_view': 'lab.storage',
    'lab.experiment_summary_view': 'lab.experiments',
    'bioinformatics.analysis_results_summary': 'bioinformatics.analysis_runs',
    'lims.project_financial_summary_view': 'lims.projects',
    'bioinformatics.full_analysis_results_view': 'bioinformatics.edna_assignments',
    'lab.storage_occupancy_view': 'lab.storage',
    'lims.project_comprehensive_summary_view': 'lims.projects',
    'lab.experiment_progress_overview_view': 'lab.experiments',
    'reference.taxon_hierarchy_view': 'reference.taxon',
    'lab.monthly_sample_reception_mv': 'lab.parental_samples', # MV is writable like a table for inserts if configured, but complex for update/delete directly
}


def get_db_connection():
    """Establishes and returns a new database connection."""
    try:
        conn = psycopg2.connect(host=DB_HOST, database=DB_NAME, user=DB_USER, password=DB_PASS)
        conn.autocommit = False # Ensure transactions are managed manually
        return conn
    except psycopg2.OperationalError as e:
        print(f"FATAL: Could not connect to database at {DB_HOST}. Error: {e}")
        raise

@app.before_request
def before_request_func():
    """
    Establishes a database connection for the request and sets RLS context.
    """
    g.db_conn = get_db_connection()
    # Set RLS current_person_id based on session.
    # Use empty string if not logged in, as NULL might behave differently in set_config.
    person_id_to_set = session.get('user_id', '')
    if isinstance(person_id_to_set, int): # Convert customer_id (int) to string for RLS
        person_id_to_set = str(person_id_to_set)

    try:
        with g.db_conn.cursor() as cur:
            # The 'FALSE' argument means the setting is local to the current transaction.
            # This is generally safer for web applications.
            cur.execute("SELECT set_config('lims.current_person_id', %s, FALSE)", (person_id_to_set,))
            g.db_conn.commit() # Commit the set_config transaction
            print(f"RLS: Set lims.current_person_id to '{person_id_to_set}'")
    except Exception as e:
        print(f"ERROR: Could not set lims.current_person_id for RLS: {e}")
        # Optionally, raise an error or handle it based on your security policy

@app.teardown_request
def teardown_request_func(exception=None):
    """Closes the database connection after each request."""
    if hasattr(g, 'db_conn'):
        if exception and not g.db_conn.closed:
            g.db_conn.rollback() # Rollback on exception
            print("Database transaction rolled back due to an exception.")
        elif not g.db_conn.closed:
            # If no exception, but not committed yet, commit here.
            # However, it's better to explicitly commit in routes for DML operations.
            pass # We rely on explicit commits in routes for DML
        g.db_conn.close()

def get_pk_columns(schema: str, table: str) -> List[str]:
    """Retrieves primary key column names for a given table."""
    pk_info = PK_MAPPING.get((schema.lower(), table.lower()))
    if pk_info is None:
        print(f"WARNING: No primary key mapping found for {schema}.{table}. Returning empty list. "
              "Please ensure PK_MAPPING is correct and matches database column casing.")
        return [] # Return empty list if no PK found or mapped
    if isinstance(pk_info, str):
        return [pk_info]
    return pk_info

def transform_row_for_json(row: Dict[str, Any]) -> Dict[str, Any]:
    """
    Transforms a database row (RealDictRow) into a JSON-serializable dictionary.
    Handles binary data (bytea) and time objects.
    """
    new_row = dict(row)
    for key, value in new_row.items():
        if isinstance(value, (memoryview, bytes)):
            new_row[key] = base64.b64encode(value).decode('utf-8')
        elif isinstance(value, time): # Handle datetime.time objects
            new_row[key] = str(value) # Convert to string for JSON serialization
        elif isinstance(value, datetime): # Handle datetime.datetime objects (timestamps)
            new_row[key] = value.isoformat() # Convert to ISO format string
        elif isinstance(value, dict) and 'type' in value and 'coordinates' in value:
            # Basic GeoJSON detection for points. Render as dict, frontend can handle.
            new_row[key] = value
        elif isinstance(value, list) and all(isinstance(i, dict) and 'type' in i and 'coordinates' in i for i in value):
            # Basic GeoJSON detection for collections. Render as list of dicts.
            new_row[key] = value
    return new_row

# Caches for resolved table names and column types to reduce DB queries
_resolved_names_cache: Dict[Tuple[str, str], Tuple[str, str, str]] = {} # Added table_type to cache
_column_types_cache: Dict[Tuple[str, str], Dict[str, str]] = {}

def _resolve_table_casing(conn, requested_schema: str, requested_table: str) -> Optional[Tuple[str, str, str]]:
    """Resolves the actual casing of schema and table names in the database and fetches table type."""
    cache_key = (requested_schema.lower(), requested_table.lower())
    if cache_key in _resolved_names_cache:
        return _resolved_names_cache[cache_key]

    # Check base tables first
    query_tables = """
        SELECT table_schema, table_name, table_type
        FROM information_schema.tables
        WHERE lower(table_schema) = lower(%s) AND lower(table_name) = lower(%s)
        LIMIT 1;
    """
    try:
        with conn.cursor() as cur:
            cur.execute(query_tables, (requested_schema, requested_table))
            result = cur.fetchone()
            if result:
                actual_schema, actual_table, table_type = result[0], result[1], result[2]
                _resolved_names_cache[cache_key] = (actual_schema, actual_table, table_type)
                return actual_schema, actual_table, table_type
            
            # If not found in tables, check views and materialized views
            query_views = """
                SELECT table_schema, table_name, 'VIEW' AS table_type -- information_schema.views doesn't have table_type, so hardcode for simplicity
                FROM information_schema.views
                WHERE lower(table_schema) = lower(%s) AND lower(table_name) = lower(%s)
                LIMIT 1;
            """
            cur.execute(query_views, (requested_schema, requested_table))
            result_view = cur.fetchone()
            if result_view:
                actual_schema, actual_table = result_view[0], result_view[1]
                table_type = 'VIEW' # Default to 'VIEW' for entries from information_schema.views
                _resolved_names_cache[cache_key] = (actual_schema, actual_table, table_type)
                return actual_schema, actual_table, table_type

    except Exception as e:
        print(f"Error resolving table casing for {requested_schema}.{requested_table}: {e}")
    return None

def _get_column_types(conn, schema: str, table: str) -> Dict[str, str]:
    """Fetches column names and their data types for a given table."""
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


@app.route(f'{API_PREFIX}/login', methods=['POST'])
def login_user():
    """Handles user login across different user tables."""
    data = request.get_json()
    username = data.get('username')
    password = data.get('password')

    if not username or not password:
        return jsonify({"error": "Missing username or password"}), 400

    # Handle hardcoded TIFI admin for quick access
    if username == 'TIFI' and password == 'password':
        session['user_id'] = 'TIFI'
        session['user_type'] = 'admin'
        session['is_admin'] = True
        return jsonify({"success": True, "user": {"full_name": "TIFI Admin", "person_id": "TIFI"}, "user_type": "admin"}), 200

    conn = g.db_conn
    try:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            # Try logging in as 'personal' user
            query_personal = 'SELECT person_id, full_name, password_hash FROM "reference"."personal" WHERE person_id = %s;'
            cur.execute(query_personal, (username,))
            user_personal = cur.fetchone()

            if user_personal and user_personal.get('password_hash'):
                if bcrypt.checkpw(password.encode('utf-8'), user_personal['password_hash'].encode('utf-8')):
                    session['user_id'] = user_personal['person_id']
                    session['user_type'] = 'personal'
                    session['is_admin'] = False
                    user_personal.pop('password_hash', None) # Remove hash before sending to frontend
                    return jsonify({"success": True, "user": user_personal, "user_type": "personal"}), 200

            # Try logging in as 'customers' user (using mail as username)
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

            # Try logging in as 'external_contacts' user (using mail as username)
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

            return jsonify({"error": "Invalid credentials"}), 401
    except Exception as e:
        print(f"Login error for {username}: {e}")
        return jsonify({"error": "An internal server error occurred during login."}), 500


@app.route(f'{API_PREFIX}/logout', methods=['POST'])
def logout_user():
    """Logs out the current user by clearing the session."""
    session.pop('user_id', None)
    session.pop('user_type', None)
    session.pop('is_admin', None)
    return jsonify({"success": True, "message": "Logged out"}), 200

@app.route(f'{API_PREFIX}/global-search/<string:search_term>', methods=['GET'])
def global_search(search_term: str):
    """Performs a global search across multiple tables using full-text search or ILIKE."""
    # Ensure lims_english text search configuration exists in your DB
    ts_query_func = f"plainto_tsquery('public.lims_english', %s)"
    search_pattern = f"%{search_term}%" # For ILIKE searches

    results: Dict[str, List[Dict[str, Any]]] = {}

    # Define queries for different tables/views
    # Each tuple contains (SQL query string, parameters tuple)
    queries: Dict[str, Tuple[str, Tuple[Any, ...]]] = {
        "projects": (
            f'SELECT project_id, title FROM "lims"."projects" WHERE project_search_vector @@ {ts_query_func} OR project_id ILIKE %s OR title ILIKE %s LIMIT 5',
            (search_term, search_pattern, search_pattern)
        ),
        "samples": (
            f'SELECT sample_id, external_name, sample_status_id FROM "lab"."parental_samples" WHERE sample_search_vector @@ {ts_query_func} OR sample_id ILIKE %s OR external_name ILIKE %s LIMIT 5',
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
    """Fetches key statistics for the dashboard."""
    stats = {}
    try:
        conn = g.db_conn # Initialize conn
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute("SELECT COUNT(*) AS active_projects FROM \"lims\".\"projects\" WHERE \"status_id\" = 'Active';")
            stats['active_projects'] = cur.fetchone()['active_projects']

            cur.execute("SELECT COUNT(*) AS total_samples FROM \"lab\".\"master_samples\";")
            stats['total_samples'] = cur.fetchone()['total_samples']

            current_month_start = datetime.now().replace(day=1, hour=0, minute=0, second=0, microsecond=0)
            cur.execute("""
                SELECT COUNT(*) AS experiments_this_month
                FROM "lab"."experiments"
                WHERE "experiment_date" >= %s;
            """, (current_month_start.date(),))
            stats['experiments_this_month'] = cur.fetchone()['experiments_this_month']

            cur.execute("""
                SELECT COUNT(*) AS active_orders
                FROM "lims"."orders"
                WHERE "status_id" = 'Active';
            """)
            stats['active_orders'] = cur.fetchone()['active_orders']

            cur.execute("""
                SELECT COUNT(DISTINCT storage_id) AS occupied_storage_units
                FROM "lab"."parental_samples"
                WHERE storage_id IS NOT NULL AND storage_position IS NOT NULL;
            """)
            stats['occupied_storage_units'] = cur.fetchone()['occupied_storage_units']

            cur.execute("SELECT COUNT(*) AS total_sops FROM \"lims\".\"sop\";")
            stats['total_sops'] = cur.fetchone()['total_sops']
            
            cur.execute("SELECT COUNT(*) AS total_experiments FROM \"lab\".\"experiments\";")
            stats['total_experiments'] = cur.fetchone()['total_experiments']

            # New: Count of Active Personnel
            cur.execute("""
                SELECT COUNT(*) AS active_personnel
                FROM "reference"."personal"
                WHERE "status_id" = 'Active';
            """)
            stats['active_personnel'] = cur.fetchone()['active_personnel']


        return jsonify(stats), 200
    except Exception as e:
        print(f"Dashboard stats error: {e}")
        return jsonify({"error": "An internal server error occurred while fetching dashboard stats."}), 500


@app.route(f'{API_PREFIX}/table_names_for_forms', methods=['GET'])
def table_names_for_forms():
    """
    Returns a list of all table and view names in specified schemas,
    suitable for populating dynamic forms.
    """
    try:
        conn = g.db_conn # Initialize conn
        with conn.cursor() as cur:
            query = """
            SELECT table_schema || '.' || table_name
            FROM information_schema.tables
            WHERE table_schema IN ('lab', 'lims', 'reference', 'bioinformatics', 'audit', 'projects')
              AND table_type IN ('BASE TABLE', 'VIEW', 'MATERIALIZED VIEW')
              AND table_name NOT LIKE '%_seq' -- Exclude sequences
              AND table_name NOT LIKE '%_y%' -- Exclude partitions (e.g., table_y2023)
              AND table_name NOT IN ('log', 'master_samples') -- Exclude audit log and internal master samples
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
        conn = g.db_conn # Initialize conn

        # Resolve actual schema and table name casing, and get table type
        resolved = _resolve_table_casing(conn, schema, table)
        if not resolved:
            return jsonify({"error": f"Table or view '{schema}.{table}' not found or inaccessible."}), 404
        
        actual_schema, actual_table, table_type_info = resolved # Unpack schema, table name, and table_type

        query = """
            SELECT 
                c.column_name, 
                c.data_type, 
                c.is_nullable, 
                c.column_default
            FROM information_schema.columns c
            WHERE c.table_schema = %s AND c.table_name = %s
            ORDER BY c.ordinal_position;
        """
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute(query, (actual_schema, actual_table))
            columns = cur.fetchall()
        
        pk_columns = get_pk_columns(actual_schema, actual_table)
        for col in columns:
            col['is_primary_key'] = col['column_name'] in pk_columns
            col['table_type'] = table_type_info # Add table_type to each column for frontend logic


        return jsonify(columns), 200
    except Exception as e:
        print(f"Error fetching schema for {schema}.{table}: {e}")
        return jsonify({"error": str(e)}), 500


@app.route(f'{API_PREFIX}/table/<string:schema>/<string:table>', methods=['GET'])
def get_table_data(schema: str, table: str):
    """
    Fetches data from a specified table or view, with optional filters, ordering, and pagination.
    Supports filtering by specific IDs, dates, and a general 'filter_' prefix for other columns.
    """
    conn = g.db_conn # Initialize conn at the top of the function
    try:
        resolved = _resolve_table_casing(conn, schema, table)
        if not resolved:
            return jsonify({"error": f"Table or view '{schema}.{table}' not found or inaccessible."}), 404
        
        actual_schema, actual_table, table_type = resolved # Unpack schema, table name, and table_type
        
        where_clauses: List[str] = []
        params: List[Any] = []
        
        # Specific filter parameters from request arguments
        filter_project_id_value = request.args.get('filter_project_id')
        filter_experiment_id_value = request.args.get('filter_experiment_id')
        filter_experiment_date_value = request.args.get('filter_experiment_date')
        filter_sample_id_value = request.args.get('filter_sample_id')
        filter_sampling_date_value = request.args.get('filter_sampling_date') # New: for composite PK filtering
        filter_protocol_id_value = request.args.get('filter_protocol_id')
        exclude_status_id_value = request.args.get('exclude_status_id') # For SOPs
        filter_status_id_value = request.args.get('filter_status_id') # For Projects

        base_query_select = f'SELECT "{actual_table}".*'
        base_query_from = f'FROM "{actual_schema}"."{actual_table}"'
        
        def parse_date_filter(date_str):
            """Helper to parse date strings into date objects."""
            try:
                return datetime.strptime(date_str, '%Y-%m-%d').date()
            except (ValueError, TypeError):
                return None

        # Complex filtering for linked tables (e.g., experiments by project, samples by experiment)
        if filter_experiment_id_value and filter_experiment_date_value:
            filter_exp_date_obj = parse_date_filter(filter_experiment_date_value)

            if actual_schema.lower() == 'lab' and actual_table.lower() == 'experiments':
                where_clauses.append(f'"{actual_table}"."experiment_id" ILIKE %s')
                params.append(f'%{filter_experiment_id_value}%')
                where_clauses.append(f'"{actual_table}"."experiment_date" = %s')
                params.append(filter_exp_date_obj)
            elif actual_schema.lower() == 'lab' and actual_table.lower() in ['experiments_projects', 'experiments_samples', 'protocol_runs', 'dissections', 'extraction', 'nanodrop', 'qubit', 'tapestation', 'pcr', 'gelelectrophoresis', 'qpcr', 'library', 'sequencing', 'datasets', 'tissue', 'otoliths', 'dna', 'rna', 'sediments', 'water']:
                # For tables with experiment_id and experiment_date as direct columns (often part of PK)
                where_clauses.append(f'"{actual_table}"."experiment_id" ILIKE %s')
                params.append(f'%{filter_experiment_id_value}%')
                where_clauses.append(f'"{actual_table}"."experiment_date" = %s')
                params.append(filter_exp_date_obj)
            elif actual_schema.lower() == 'bioinformatics' and actual_table.lower() == 'analysis_runs':
                # Join through sequencing to filter analysis_runs by experiment
                base_query_from += f"""
                    JOIN "lab"."sequencing" AS S ON "{actual_table}".sequencing_id = S.sequencing_id 
                    AND "{actual_table}".sequencing_date = S.sequencing_date
                """
                where_clauses.append(f'S.experiment_id ILIKE %s')
                params.append(f'%{filter_experiment_id_value}%')
                where_clauses.append(f'S.experiment_date = %s')
                params.append(filter_exp_date_obj)
            elif actual_schema.lower() == 'bioinformatics' and actual_table.lower() == 'edna_assignments':
                # Join through analysis_runs and sequencing to filter edna_assignments by experiment
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
        
        elif filter_sample_id_value:
            # Handle filtering by sample_id, potentially with sampling_date for composite PKs
            if actual_schema.lower() == 'lab':
                if actual_table.lower() == 'parental_samples':
                    where_clauses.append(f'"{actual_table}"."sample_id" ILIKE %s')
                    params.append(f'%{filter_sample_id_value}%')
                    if filter_sampling_date_value:
                        filter_samp_date_obj = parse_date_filter(filter_sampling_date_value)
                        where_clauses.append(f'"{actual_table}"."sampling_date" = %s')
                        params.append(filter_samp_date_obj)
                elif actual_table.lower() == 'fish':
                    where_clauses.append(f'"{actual_table}"."sample_id" ILIKE %s')
                    params.append(f'%{filter_sample_id_value}%')
                    if filter_sampling_date_value: # fish has sampling_date as part of its PK
                        filter_samp_date_obj = parse_date_filter(filter_sampling_date_value)
                        where_clauses.append(f'"{actual_table}"."sampling_date" = %s')
                        params.append(filter_samp_date_obj)
                elif actual_table.lower() == 'storage_log':
                    where_clauses.append(f'"{actual_table}"."sample_id" ILIKE %s')
                    params.append(f'%{filter_sample_id_value}%')
                    if filter_sampling_date_value: # storage_log links via sample_id and sample_sampling_date
                        filter_samp_date_obj = parse_date_filter(filter_sampling_date_value)
                        where_clauses.append(f'"{actual_table}"."sample_sampling_date" = %s')
                        params.append(filter_samp_date_obj)
                elif actual_table.lower() == 'fishing':
                    # Fishing table has sampling_id and sampling_date as part of its PK, but can be filtered by a sample_id that links to it
                    base_query_from += f"""
                        JOIN "lab"."parental_samples" AS S ON "{actual_table}".sampling_id = S.sampling_id
                        AND "{actual_table}".sampling_date = S.sampling_date
                    """
                    where_clauses.append(f'S.sample_id ILIKE %s')
                    params.append(f'%{filter_sample_id_value}%')
                    if filter_sampling_date_value:
                        filter_samp_date_obj = parse_date_filter(filter_sampling_date_value)
                        where_clauses.append(f'S.sampling_date = %s')
                        params.append(filter_samp_date_obj)
                elif actual_table.lower() == 'sampling':
                    # Sampling table can be filtered by a sample_id that links to it
                    base_query_from += f"""
                        JOIN "lab"."parental_samples" AS S ON "{actual_table}".sampling_id = S.sampling_id
                        AND "{actual_table}".sampling_date = S.sampling_date
                    """
                    where_clauses.append(f'S.sample_id ILIKE %s')
                    params.append(f'%{filter_sample_id_value}%')
                    if filter_sampling_date_value:
                        filter_samp_date_obj = parse_date_filter(filter_sampling_date_value)
                        where_clauses.append(f'S.sampling_date = %s')
                        params.append(filter_samp_date_obj)
                elif actual_table.lower() in ['tissue', 'otoliths', 'dna', 'rna', 'sediments', 'water', 'experiments_samples', 'dissections', 'extraction', 'nanodrop', 'qubit', 'tapestation', 'pcr', 'gelelectrophoresis', 'qpcr', 'library', 'sequencing']:
                    # These tables have sample_id as a direct foreign key
                    where_clauses.append(f'"{actual_table}"."sample_id" ILIKE %s')
                    params.append(f'%{filter_sample_id_value}%')
            elif actual_schema.lower() == 'bioinformatics' and actual_table.lower() == 'analysis_runs':
                # Filter analysis_runs by sample_id via sequencing table
                base_query_from += f"""
                    JOIN "lab"."sequencing" AS SEQ ON "{actual_table}".sequencing_id = SEQ.sequencing_id
                    AND "{actual_table}".sequencing_date = SEQ.sequencing_date
                """
                where_clauses.append(f'SEQ.sample_id ILIKE %s')
                params.append(f'%{filter_sample_id_value}%')
            elif actual_schema.lower() == 'bioinformatics' and actual_table.lower() == 'edna_assignments':
                # Filter edna_assignments directly by sample_id
                where_clauses.append(f'"{actual_table}"."sample_id" ILIKE %s')
                params.append(f'%{filter_sample_id_value}%')
        
        # General filter for project_id (if not covered by experiment or sample specific filters)
        if filter_project_id_value and actual_schema.lower() == 'lims' and actual_table.lower() == 'projects':
            # This handles direct filtering of the projects table by its own project_id
            where_clauses.append(f'"{actual_table}"."project_id" ILIKE %s')
            params.append(f'%{filter_project_id_value}%')
        elif filter_project_id_value: # For other tables that have a project_id column
            if 'project_id' in _get_column_types(conn, actual_schema, actual_table):
                where_clauses.append(f'"{actual_table}"."project_id" ILIKE %s')
                params.append(f'%{filter_project_id_value}%')

        # Filter by protocol_id for protocol_runs
        if filter_protocol_id_value and actual_schema.lower() == 'lab' and actual_table.lower() == 'protocol_runs':
            where_clauses.append(f'"{actual_table}"."protocol_id" = %s')
            params.append(filter_protocol_id_value)

        # Status filters
        if exclude_status_id_value:
            # Assumes the table has a 'status_id' column
            if 'status_id' in _get_column_types(conn, actual_schema, actual_table):
                where_clauses.append(f'"{actual_table}"."status_id" != %s')
                params.append(exclude_status_id_value)
        if filter_status_id_value:
            # Assumes the table has a 'status_id' column
            if 'status_id' in _get_column_types(conn, actual_schema, actual_table):
                where_clauses.append(f'"{actual_table}"."status_id" = %s')
                params.append(filter_status_id_value)


        order_by_column: Optional[str] = None
        order_direction: str = 'ASC'

        # Process generic filters (e.g., filter_column_name=value) and order_by/limit/offset
        for key, value in request.args.items():
            if not value:
                continue
            
            # Skip parameters already handled by specific filters above
            if key in ['filter_project_id', 'filter_experiment_id', 'filter_experiment_date', 
                       'filter_sample_id', 'filter_sampling_date', 'filter_protocol_id',
                       'exclude_status_id', 'filter_status_id']:
                continue

            if key == 'limit':
                pass # Handled after WHERE clause
            elif key == 'offset':
                pass # Handled after WHERE clause
            elif key == 'order_by':
                order_by_column = value
                continue
            elif key == 'order_direction':
                if value.upper() in ['ASC', 'DESC']:
                    order_direction = value.upper()
                continue
            elif key == 'filter_expire_date_within_30_days' and value.lower() == 'true':
                if 'expire_date' in _get_column_types(conn, actual_schema, actual_table):
                    where_clauses.append(f'"expire_date" BETWEEN CURRENT_DATE AND CURRENT_DATE + interval \'30 day\'')
                continue

            # Handle filters with 'filter_' prefix or direct column names
            if key.startswith('filter_') and not (key.endswith('_month') or key.endswith('_year')):
                col_name = key[len('filter_'):]
                if col_name in _get_column_types(conn, actual_schema, actual_table):
                    where_clauses.append(f'"{col_name}" ILIKE %s')
                    params.append(f'%{value}%')
                else:
                    print(f"Warning: Filter by non-existent or unfilterable column '{col_name}' skipped for {actual_schema}.{actual_table}.")
            elif key.startswith('filter_') and (key.endswith('_month') or key.endswith('_year')):
                col_name_raw = key[len('filter_'):]
                col_name = col_name_raw.replace('_month', '').replace('_year', '')
                if col_name in _get_column_types(conn, actual_schema, actual_table) and _get_column_types(conn, actual_schema, actual_table).get(col_name) == 'date':
                    if key.endswith('_month'):
                        try:
                            start_date_of_month = datetime.strptime(value, '%Y-%m').date()
                            # Calculate end of month correctly
                            end_date_of_month = (start_date_of_month.replace(day=1) + timedelta(days=32)).replace(day=1) - timedelta(days=1)
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
                    print(f"Warning: Date filter by non-existent or non-date column '{col_name}' skipped for {actual_schema}.{actual_table}.")
            # Direct column name filters (for exact matches, typically used for PKs in specific filters, but could be general)
            elif key in _get_column_types(conn, actual_schema, actual_table):
                # This catches direct filters like `?column_name=value` which are usually for exact match, not ILIKE
                where_clauses.append(f'"{key}" = %s')
                params.append(value)


        query = f"{base_query_select} {base_query_from}"
        if where_clauses:
            query += f" WHERE {' AND '.join(where_clauses)}"
            
        # Handle ordering
        if order_by_column:
            # Determine which table alias to use for ordering in joins
            quoted_order_by_column = f'"{actual_table}"."{order_by_column}"' # Default to main table
            if actual_schema.lower() == 'bioinformatics' and actual_table.lower() in ['analysis_runs', 'edna_assignments'] and order_by_column in ['experiment_id', 'experiment_date']:
                # If these tables are joined via sequencing (S) to get experiment info
                if 'JOIN "lab"."sequencing" AS S' in base_query_from: # Check if join was added
                    quoted_order_by_column = f'S."{order_by_column}"'
            elif actual_schema.lower() == 'lab' and actual_table.lower() in ['fishing', 'sampling'] and order_by_column in ['sample_id', 'sampling_date']:
                 # If these tables are joined via parental_samples (S) to get sample info
                if 'JOIN "lab"."parental_samples" AS S' in base_query_from: # Check if join was added
                    quoted_order_by_column = f'S."{order_by_column}"'
            
            query += f' ORDER BY {quoted_order_by_column} {order_direction}'
            
        # Handle pagination
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
    """
    Creates a new record in the specified table.
    Handles file uploads, password hashing, and special linked records (e.g., projects and persons).
    """
    conn = g.db_conn # Initialize conn at the top of the function
    try:
        resolved = _resolve_table_casing(conn, schema, table) # Get actual casing and table type
        if not resolved:
            return jsonify({"error": f"Table '{schema}.{table}' not found or inaccessible."}), 404
        actual_schema, actual_table, table_type = resolved # Unpack all three

        column_types = _get_column_types(conn, actual_schema, actual_table)

        data = {}
        files = request.files

        # Determine if content-type is JSON or multipart/form-data
        if request.is_json:
            data = request.get_json()
        elif request.form: # If it's form data (even without files)
            data = request.form.to_dict()

        if not data and not files:
            return jsonify({"error": "No data provided"}), 400
            
        # Handle attachment file if present in multipart form data
        if 'attachment' in files and files['attachment'].filename != '':
            data['attachment'] = psycopg2.Binary(files['attachment'].read())
        elif 'attachment' in data and (data['attachment'] == '' or (isinstance(data['attachment'], dict) and not data['attachment'])):
            # If attachment field was sent as empty string or empty dict from JSON/form
            data['attachment'] = None
            
        # Handle password hashing for user-related tables
        if (actual_schema.lower() == 'reference' and actual_table.lower() == 'personal') or \
           (actual_schema.lower() == 'lims' and actual_table.lower() == 'customers') or \
           (actual_schema.lower() == 'lims' and actual_table.lower() == 'external_contacts'):
            if 'password' in data and data['password']:
                hashed_password = bcrypt.hashpw(data['password'].encode('utf-8'), bcrypt.gensalt())
                data['password_hash'] = hashed_password.decode('utf-8')
            data.pop('password', None) # Remove plain password before insertion
            
        # Extract special fields that are not direct columns but manage relationships
        project_ids_str = None
        sample_ids_str = None
        linked_person_ids = None # For lims.projects

        if actual_schema.lower() == 'lab' and actual_table.lower() == 'experiments':
            project_ids_str = data.pop('project_ids', None)
            sample_ids_str = data.pop('sample_ids', None)
        elif actual_schema.lower() == 'lims' and actual_table.lower() == 'projects':
            # Handle special 'linked_person_ids' field for lims.projects
            if 'linked_person_ids' in data:
                # Expects a semicolon-separated string of person_ids
                linked_person_ids = [p.strip() for p in data.pop('linked_person_ids', '').split(';') if p.strip()]

        filtered_data = {}
        for k, v in data.items():
            if k == 'attachment': # Handle attachment specifically
                filtered_data[k] = v
            elif k == 'attachment_link' and v == '': # Explicitly handle empty attachment_link
                filtered_data[k] = None
            elif v == '':
                filtered_data[k] = None
            # Explicitly handle 'undefined' string from frontend for nullable FKs
            elif k.endswith('_id') and str(v).lower() == 'undefined':
                filtered_data[k] = None
            elif column_types.get(k) == 'jsonb' and isinstance(v, str):
                try:
                    filtered_data[k] = json.loads(v)
                except json.JSONDecodeError:
                    print(f"WARNING: Invalid JSON for column '{k}'. Storing as None. Value: {v}")
                    filtered_data[k] = None
            elif column_types.get(k) == 'boolean':
                # Convert 'true'/'false' strings or 'on'/'' from checkboxes to Python bool
                filtered_data[k] = str(v).lower() in ['true', 'on']
            else:
                filtered_data[k] = v
            
        columns = filtered_data.keys()
        values = [filtered_data[col] for col in columns] # Ensure values order matches columns
        
        column_names = ', '.join([f'"{col}"' for col in columns])
        value_placeholders = ', '.join(['%s'] * len(values))
        
        query = f'INSERT INTO "{actual_schema}"."{actual_table}" ({column_names}) VALUES ({value_placeholders}) RETURNING *;'
        
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            print(f"Executing POST query: {query} with values: {values}")
            cur.execute(query, values)
            new_record = cur.fetchone()
            
            # Post-insertion linking for specific tables
            if actual_schema.lower() == 'lab' and actual_table.lower() == 'experiments' and new_record:
                experiment_id = new_record['experiment_id']
                experiment_date = new_record['experiment_date']

                if project_ids_str:
                    project_list = [p.strip() for p in project_ids_str.split(';') if p.strip()]
                    for project_id in project_list:
                        try:
                            cur.execute(
                                'INSERT INTO "lab"."experiments_projects" ("experiment_id", "experiment_date", "project_id", "link_date") VALUES (%s, %s, %s, CURRENT_DATE);',
                                (experiment_id, experiment_date, project_id)
                            )
                        except Exception as e:
                            print(f"  Warning: Could not link project {project_id} to experiment {experiment_id}: {e}")

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
            elif actual_schema.lower() == 'lims' and actual_table.lower() == 'projects' and new_record and linked_person_ids:
                project_id = new_record['project_id']
                for person_id in linked_person_ids:
                    try:
                        cur.execute(
                            'INSERT INTO "lims"."project_persons" ("project_id", "person_id", "link_date") VALUES (%s, %s, CURRENT_DATE);',
                            (project_id, person_id)
                        )
                        print(f"  Linked person {person_id} to new project {project_id}")
                    except Exception as e:
                        print(f"  Warning: Could not link person {person_id} to new project {project_id}: {e}")
            
            conn.commit() # Commit the transaction after all inserts
        return jsonify(transform_row_for_json(new_record)), 201
    except Exception as e:    
        if conn:
            conn.rollback() # Rollback on any error
        print(f"Error creating record in {schema}.{table}: {e}")
        return jsonify({"error": str(e)}), 500
            
@app.route(f'{API_PREFIX}/table/<string:schema>/<string:table>', methods=['PUT'])
def update_record(schema: str, table: str):
    """
    Updates an existing record in the specified table identified by its primary key(s).
    Handles file uploads, password hashing, and ignores special linked fields.
    """
    conn = g.db_conn # Initialize conn at the top of the function
    try:
        resolved = _resolve_table_casing(conn, schema, table) # Get actual casing and table type
        if not resolved:
            return jsonify({"error": f"Table '{schema}.{table}' not found or inaccessible."}), 404
        actual_schema, actual_table, table_type = resolved # Unpack all three

        pk_columns = get_pk_columns(schema, table)
        column_types = _get_column_types(conn, actual_schema, actual_table) # Needed for PK type conversion

        pk_values_from_request = {}
        for pk_col in pk_columns:
            pk_val = request.args.get(pk_col)
            if pk_val is None:
                return jsonify({"error": f"Missing primary key component: {pk_col}"}), 400
            
            # Convert PK date strings to date objects for correct WHERE clause matching
            if column_types.get(pk_col) == 'date' and pk_val is not None:
                try:
                    pk_values_from_request[pk_col] = datetime.strptime(pk_val, '%Y-%m-%d').date()
                except ValueError:
                    # If conversion fails, keep as string or handle error
                    pk_values_from_request[pk_col] = pk_val
            else:
                pk_values_from_request[pk_col] = pk_val

        data = {}
        files = request.files

        # Determine if content-type is JSON or multipart/form-data
        if request.is_json:
            data = request.get_json()
        elif request.form: # If it's form data (even without files)
            data = request.form.to_dict()

        if not data and not files:
            return jsonify({"error": "No data provided"}), 400

        # Handle attachment file if present in multipart form data
        if 'attachment' in files and files['attachment'].filename != '':
            data['attachment'] = psycopg2.Binary(files['attachment'].read())
        elif 'attachment' in data and (data['attachment'] == '' or (isinstance(data['attachment'], dict) and not data['attachment'])):
            # If attachment field was sent as empty string or empty dict from JSON/form
            data['attachment'] = None

        set_clauses: List[str] = []
        values: List[Any] = []
        
        # Handle password hashing for update
        if (actual_schema.lower() == 'reference' and actual_table.lower() == 'personal') or \
           (actual_schema.lower() == 'lims' and actual_table.lower() == 'customers') or \
           (actual_schema.lower() == 'lims' and actual_table.lower() == 'external_contacts'):
            if 'password' in data and data['password']:
                hashed_password = bcrypt.hashpw(data['password'].encode('utf-8'), bcrypt.gensalt())
                data['password_hash'] = hashed_password.decode('utf-8')
            data.pop('password', None) # Remove plain password before update
            
        # Build SET clauses for the UPDATE query
        for key, val in data.items():
            # Skip primary key columns and special frontend-only fields
            if key in pk_columns or key in ['project_ids', 'sample_ids', 'linked_person_ids']:
                continue
            
            elif key == 'attachment_link' and val == '': # Explicitly handle empty attachment_link
                set_clauses.append(f'"{key}" = %s')
                values.append(None)
            elif column_types.get(key) == 'jsonb' and isinstance(val, str):
                try:
                    set_clauses.append(f'"{key}" = %s')
                    values.append(json.loads(val))
                except json.JSONDecodeError:
                    print(f"WARNING: Invalid JSON for column '{key}'. Storing as None. Value: {val}")
                    set_clauses.append(f'"{key}" = %s')
                    values.append(None)
            elif column_types.get(key) == 'boolean':
                set_clauses.append(f'"{key}" = %s')
                values.append(str(val).lower() in ['true', 'on']) # Handle 'true'/'false' strings or 'on'/'' from checkboxes
            else:
                set_clauses.append(f'"{key}" = %s')
                values.append(None if val == '' else val)
            
        if not set_clauses:
            return jsonify({"error": "No fields to update"}), 400

        # Build WHERE clause using primary key(s)
        pk_where_clauses = [] # Initialize pk_where_clauses here
        pk_where_values: List[Any] = [] 
        for pk_col in pk_columns:
            pk_where_clauses.append(f'"{pk_col}" = %s')
            pk_where_values.append(pk_values_from_request[pk_col]) # Use the already parsed PK values
            
        # Combine all values for execution: SET values first, then WHERE PK values
        all_values = values + pk_where_values
        
        query = f'UPDATE "{actual_schema}"."{actual_table}" SET {", ".join(set_clauses)} WHERE {" AND ".join(pk_where_clauses)} RETURNING *;'
        
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            print(f"Executing PUT query: {query} with values: {all_values}")
            cur.execute(query, all_values)
            updated_record = cur.fetchone()
            conn.commit() # Commit the transaction
        if updated_record:
            return jsonify(transform_row_for_json(updated_record)), 200
        else:
            return jsonify({"error": "Record not found or no changes made."}), 404
    except Exception as e:    
        if conn:
            conn.rollback() # Rollback on any error
        print(f"Error updating record in {schema}.{table}: {e}")
        return jsonify({"error": str(e)}), 500


@app.route(f'{API_PREFIX}/table/<string:schema>/<string:table>', methods=['DELETE'])
def delete_record(schema: str, table: str):
    """
    Deletes a record from the specified table using its primary key(s).
    """
    conn = g.db_conn # Initialize conn at the top of the function
    try:
        resolved = _resolve_table_casing(conn, schema, table)
        if not resolved:
            return jsonify({"error": f"Table '{schema}.{table}' not found or inaccessible."}), 404
        actual_schema, actual_table, table_type = resolved # Unpack all three

        pk_columns = get_pk_columns(schema, table)
        column_types = _get_column_types(conn, actual_schema, actual_table) # Needed for PK type conversion

        pk_values_for_query = []
        where_clauses = [] # Initialize where_clauses here
        for pk_col in pk_columns:
            pk_val = request.args.get(pk_col)
            if pk_val is None:
                return jsonify({"error": f"Missing primary key component for deletion: {pk_col}"}), 400
            
            if column_types.get(pk_col) == 'date' and pk_val is not None: # Convert PK date strings to date objects for correct WHERE clause matching
                try:
                    pk_val = datetime.strptime(pk_val, '%Y-%m-%d').date()
                except ValueError:
                    pass # Keep as string if conversion fails

            where_clauses.append(f'"{pk_col}" = %s')
            pk_values_for_query.append(pk_val)

        query = f'DELETE FROM "{actual_schema}"."{actual_table}" WHERE {" AND ".join(where_clauses)} RETURNING *;'
        
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            print(f"Executing DELETE query: {query} with params: {pk_values_for_query}")
            cur.execute(query, pk_values_for_query)
            deleted_record = cur.fetchone()
            conn.commit() # Commit the transaction
        
        if deleted_record:
            return jsonify({"success": True, "message": "Record deleted successfully."}), 200
        else:
            return jsonify({"error": "Record not found or could not be deleted."}), 404
    except Exception as e:
        if conn:
            conn.rollback() # Rollback on any error
        print(f"Error deleting record from {schema}.{table}: {e}")
        return jsonify({"error": str(e)}), 500

@app.route(f'{API_PREFIX}/table/<string:schema>/<string:table>/batch_upload', methods=['POST'])
def batch_upload(schema: str, table: str):
    """
    Handles bulk insertion of records from a list of dictionaries (e.g., from CSV/JSON upload).
    Supports special linking logic for experiments/projects/samples and projects/persons.
    """
    conn = g.db_conn # Initialize conn at the top of the function
    try:
        resolved = _resolve_table_casing(conn, schema, table) # Get actual casing and table type
        if not resolved:
            return jsonify({"error": f"Table '{schema}.{table}' not found or inaccessible."}), 404
        actual_schema, actual_table, table_type = resolved # Unpack all three

        column_types = _get_column_types(conn, actual_schema, actual_table)

        records = request.get_json() # Expects a JSON array of objects
        if not records or not isinstance(records, list):    
            return jsonify({"error": "Invalid data format. Expected a list of records."}), 400
            
        if not records:
            return jsonify({"success": True, "inserted_rows": 0}), 200

        inserted_count = 0
        
        # Special batch handling for 'experiments' and 'projects' due to linked tables
        if actual_schema.lower() == 'lab' and actual_table.lower() == 'experiments':
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
                for record_data in records:
                    project_ids_str = record_data.pop('project_ids', None) # Extract linked project IDs
                    sample_ids_str = record_data.pop('sample_ids', None) # Extract linked sample IDs

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
                        elif column_types.get(k) == 'boolean':
                            filtered_record[k] = str(v).lower() in ['true', 'on']
                        else:
                            filtered_record[k] = v
                    
                    # Handle password hashing (if applicable to this table)
                    if (actual_schema.lower() == 'reference' and actual_table.lower() == 'personal') or \
                       (actual_schema.lower() == 'lims' and actual_table.lower() == 'customers') or \
                       (actual_schema.lower() == 'lims' and actual_table.lower() == 'external_contacts'):
                        if 'password' in filtered_record and filtered_record['password']:
                            hashed_password = bcrypt.hashpw(filtered_record['password'].encode('utf-8'), bcrypt.gensalt())
                            filtered_record['password_hash'] = hashed_password.decode('utf-8')
                        filtered_record.pop('password', None)
                    
                    # Handle attachment (base64 decoded from CSV, for example)
                    if 'attachment' in filtered_record and filtered_record['attachment'] == '':
                        filtered_record['attachment'] = None
                    elif 'attachment' in filtered_record and isinstance(filtered_record['attachment'], str):
                            try:
                                filtered_record['attachment'] = base64.b64decode(filtered_record['attachment'])
                            except Exception as e:
                                print(f"  Warning: Could not decode base64 attachment for record: {e}")
                                filtered_record['attachment'] = None
                    elif 'attachment' in filtered_record and isinstance(filtered_record['attachment'], dict) and not filtered_record['attachment']:
                        filtered_record['attachment'] = None

                    if 'attachment_link' in filtered_record and filtered_record['attachment_link'] == '': # Explicitly handle empty attachment_link
                        filtered_record['attachment_link'] = None
                            
                    columns = filtered_record.keys()
                    values = [filtered_record[col] for col in columns]

                    column_names = ', '.join([f'"{col}"' for col in columns])
                    value_placeholders = ', '.join(['%s'] * len(values))
                    
                    insert_query = f'INSERT INTO "{actual_schema}"."{actual_table}" ({column_names}) VALUES ({value_placeholders}) RETURNING *;'
                    
                    try:
                        cur.execute(insert_query, values)
                        new_record = cur.fetchone()
                        if new_record: # Only increment if insertion was successful
                            inserted_count += 1

                            experiment_id = new_record['experiment_id']
                            experiment_date = new_record['experiment_date']

                            # Link projects to the new experiment
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

                            # Link samples to the new experiment
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
                conn.commit() # Commit once after all individual records are processed
        
        elif actual_schema.lower() == 'lims' and actual_table.lower() == 'projects':
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
                        elif column_types.get(k) == 'boolean':
                            filtered_record[k] = str(v).lower() in ['true', 'on']
                        else:
                            filtered_record[k] = v

                    columns = filtered_record.keys()
                    values = [filtered_record[col] for col in columns]
                    column_names = ', '.join([f'"{col}"' for col in columns])
                    value_placeholders = ', '.join(['%s'] * len(values))
                    insert_query = f'INSERT INTO "{actual_schema}"."{actual_table}" ({column_names}) VALUES ({value_placeholders}) RETURNING *;'

                    try:
                        cur.execute(insert_query, values)
                        new_project = cur.fetchone()
                        if new_project: # Only increment if insertion was successful
                            inserted_count += 1

                            # Link persons to the new project
                            if linked_person_ids_str:
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
                conn.commit() # Commit once after all individual records are processed
        
        else: # Generic batch upload for other tables
            if not records: # Double check if records list is empty after filtering
                return jsonify({"success": True, "inserted_rows": 0}), 200

            # Assuming all records in the batch have the same set of keys (columns)
            first_record_keys = list(records[0].keys())
            processed_records_for_insertion = []

            for record in records:
                # Basic validation: ensure all records in batch have consistent keys
                if set(record.keys()) != set(first_record_keys):
                    # It's safer to rollback and fail if data is inconsistent
                    conn.rollback()
                    return jsonify({"error": "All records in batch must have the same set of columns for batch insertion."}), 400

                temp_record = record.copy()
                # Handle password hashing
                if (actual_schema.lower() == 'reference' and actual_table.lower() == 'personal') or \
                   (actual_schema.lower() == 'lims' and actual_table.lower() == 'customers') or \
                   (actual_schema.lower() == 'lims' and actual_table.lower() == 'external_contacts'):
                    if 'password' in temp_record and temp_record['password']:
                        hashed_password = bcrypt.hashpw(temp_record['password'].encode('utf-8'), bcrypt.gensalt())
                        temp_record['password_hash'] = hashed_password.decode('utf-8')
                    temp_record.pop('password', None)
                
                # Handle attachment (base64 decoded from CSV/JSON input)
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

                if 'attachment_link' in temp_record and temp_record['attachment_link'] == '':
                    temp_record['attachment_link'] = None

                # Convert JSONB strings to Python dicts if necessary
                for k, v in temp_record.items():
                    if column_types.get(k) == 'jsonb' and isinstance(v, str):
                        try:
                            temp_record[k] = json.loads(v)
                        except json.JSONDecodeError:
                            print(f"WARNING: Invalid JSON for column '{k}' during batch upload. Storing as None. Value: {v}")
                            temp_record[k] = None
                    elif column_types.get(k) == 'boolean':
                        temp_record[k] = str(v).lower() in ['true', 'on']
                    else:
                        temp_record[k] = v

                processed_records_for_insertion.append({k: (v if v != '' else None) for k, v in temp_record.items()})

            columns = list(processed_records_for_insertion[0].keys())
            column_names = ', '.join([f'"{col}"' for col in columns])
            
            # Prepare data as a list of tuples for execute_values
            data_tuples: List[Tuple[Any, ...]] = []
            for record_data in processed_records_for_insertion:
                row = []
                for col in columns:
                    val = record_data.get(col)
                    row.append(val) # psycopg2 handles None correctly
                data_tuples.append(tuple(row))

            query_template = f"INSERT INTO \"{actual_schema}\".\"{actual_table}\" ({column_names}) VALUES %s"
            
            with conn.cursor() as cur:
                print(f"Executing batch_upload query: {query_template} with {len(data_tuples)} records.")
                psycopg2.extras.execute_values(cur, query_template, data_tuples)
                conn.commit() # Commit once for the whole batch
            inserted_count = len(records)
            
        return jsonify({"success": True, "inserted_rows": inserted_count}), 201
    except Exception as e:    
        if conn:
            conn.rollback() # Rollback on any error
        print(f"Error during batch upload for {schema}.{table}: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@app.route(f'{API_PREFIX}/table/<string:schema>/<string:table>/batch_update', methods=['PUT'])
def batch_update(schema: str, table: str):
    """
    Performs a bulk update of records.
    Expects a JSON array of objects, where each object contains primary key(s)
    and fields to update.
    """
    conn = g.db_conn # Initialize conn at the top of the function
    try:
        resolved = _resolve_table_casing(conn, schema, table) # Get actual casing and table type
        if not resolved:
            return jsonify({"error": f"Table '{schema}.{table}' not found or inaccessible."}), 404
        actual_schema, actual_table, table_type = resolved # Unpack all three

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
                set_clauses_parts: List[str] = []
                set_values: List[Any] = []
                pk_where_clauses_parts: List[str] = [] # Initialize pk_where_clauses_parts here
                pk_where_values: List[Any] = [] # Values for the PKs in WHERE clause

                # Separate update fields from PK fields
                update_fields = {k: v for k, v in record_data.items() if k not in pk_columns}
                pk_fields = {k: v for k, v in record_data.items() if k in pk_columns}

                # Validate all PKs are present for the current record
                if not all(pk_col in pk_fields for pk_col in pk_columns):
                    print(f"  Warning: Skipping record in batch update due to missing primary key(s): {record_data}")
                    continue
                
                # Build SET clauses
                for key, val in update_fields.items():
                    if key == 'attachment_link' and val == '':
                        set_clauses_parts.append(f'"{key}" = %s')
                        set_values.append(None)
                    elif column_types.get(key) == 'jsonb' and isinstance(val, str):
                        try:
                            set_clauses_parts.append(f'"{key}" = %s')
                            set_values.append(json.loads(val))
                        except json.JSONDecodeError:
                            print(f"WARNING: Invalid JSON for column '{key}'. Storing as None. Value: {val}")
                            set_clauses_parts.append(f'"{key}" = %s')
                            set_values.append(None)
                    elif column_types.get(key) == 'boolean':
                        set_clauses_parts.append(f'"{key}" = %s')
                        set_values.append(str(val).lower() in ['true', 'on']) # Handle 'true'/'false' strings or 'on'/''
                    else:
                        set_clauses_parts.append(f'"{key}" = %s')
                        set_values.append(None if val == '' else val)
                
                if not set_clauses_parts:
                    print(f"  Warning: Skipping record in batch update as no update fields provided: {record_data}")
                    continue

                # Prepare PK values for WHERE clause
                for pk_col in pk_columns:
                    pk_where_clauses_parts.append(f'"{pk_col}" = %s')
                    pk_val = pk_fields[pk_col]
                    # Convert PK date strings to date objects for correct WHERE clause matching
                    if column_types.get(pk_col) == 'date' and pk_val is not None:
                        try:
                            pk_where_values.append(datetime.strptime(pk_val, '%Y-%m-%d').date())
                        except ValueError:
                            pk_where_values.append(pk_val) # Keep as string if conversion fails
                    else:
                        pk_where_values.append(pk_val)
                
                # Combine all values for execution: SET values first, then WHERE PK values
                all_values = set_values + pk_where_values
                
                update_query = f'UPDATE "{actual_schema}"."{actual_table}" SET {", ".join(set_clauses_parts)} WHERE {" AND ".join(pk_where_clauses_parts)} RETURNING *;'
                
                try:
                    cur.execute(update_query, all_values)
                    if cur.fetchone(): # Check if any row was actually updated
                        updated_count += 1
                    else:
                        print(f"  Warning: Record not found for update in batch: {record_data}")
                except Exception as e:
                    print(f"  Error updating record in batch for {actual_schema}.{actual_table} (PK: {pk_fields}): {e}")
            conn.commit() # Commit once for the whole batch
            return jsonify({"success": True, "updated_rows": updated_count}), 200

    except Exception as e:
        if conn:
            conn.rollback() # Rollback on any error
        print(f"Error during batch update for {schema}.{table}: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


# --- Static File Serving ---
@app.route('/')
def root():    
    """Redirects the root URL to the login page."""
    return redirect(url_for('serve_static', filename='login.html'))

@app.route('/<path:filename>')
def serve_static(filename: str):
    """Serves static files from the STATIC_FOLDER."""
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
        # In development, Flask's reloader and debugger are useful
        app.run(host=host, port=port, debug=True)
    else:
        # In production, use Waitress for a more robust WSGI server
        serve(app, host=host, port=port)