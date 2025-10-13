from flask import Flask, request, jsonify, session, send_from_directory, redirect, url_for, g
from flask_cors import CORS
from waitress import serve
import os
import bcrypt
import base64
import json
from typing import Any, Dict, List, Optional, Tuple, Union
from datetime import datetime, timedelta, time, date
import psycopg2
from psycopg2 import sql, extras
from dotenv import load_dotenv

load_dotenv()

DB_HOST: str = os.getenv('DB_HOST', '0.0.0.0')
DB_NAME: str = os.getenv('DB_NAME', 'demo_lims')
DB_USER: str = os.getenv('DB_USER', 'kasmi')
DB_PASS: str = os.getenv('DB_PASS', 'password')
SECRET_KEY: str = os.getenv('SECRET_KEY', 'a_very_secret_key_for_session_management_and_security')

STATIC_FOLDER: str = '.'
FLASK_ENV: str = os.getenv('FLASK_ENV', 'production')
API_PREFIX: str = os.getenv('API_PREFIX', '/api') # Changed to /mylims/api to match frontend

app = Flask(__name__, static_folder=STATIC_FOLDER)
app.secret_key = SECRET_KEY
CORS(app, supports_credentials=True)

# --- Primary Key Mapping ---
# IMPORTANT: This list has been updated to include all tables from MyLims_v4.sql, 
# especially the new booking tables: lims.bookable_resource and lims.booking.
PK_MAPPING: Dict[Tuple[str, str], Union[str, List[str]]] = {
    ('reference', 'status'): 'status_id',
    ('reference', 'room'): 'room_id',
    ('reference', 'vessel'): 'vessel_id',
    ('reference', 'region'): 'region_id',
    ('reference', 'ecosystem'): 'ecosystem_id',
    ('reference', 'category'): 'category_id',
    ('reference', 'samples_type'): 'sample_type_id',
    ('reference', 'gene'): 'gene_id',
    ('reference', 'taxon'): 'taxon_id',
    ('reference', 'units'): 'unit_id',
    ('reference', 'reference_databases'): 'db_id',
    ('lims', 'personal'): 'person_id',
    ('lims', 'external_contacts'): 'contact_id',
    ('lims', 'customers'): 'customer_id',
    ('lims', 'projects'): 'project_id',
    ('lims', 'project_persons'): ['project_id', 'person_id'],
    ('lims', 'cruises'): 'cruise_id',
    ('lims', 'sop'): 'sop_id',
    ('lims', 'batch'): 'batch_id',
    ('lims', 'batch_steps'): ['batch_id', 'step_number'],
    ('lims', 'permits'): 'permit_id',
    ('lims', 'primers'): 'primer_id',
    ('lims', 'equipment'): 'equipment_id',
    ('lims', 'instrument_maintenance'): 'maintenance_id',
    ('lims', 'suppliers'): 'supplier_id',
    ('lims', 'inventory_items'): 'item_id',
    ('lims', 'orders'): 'fi_order_nr',
    ('lims', 'reagents'): 'reagent_id',
    ('lims', 'publication_type'): 'publication_type_id',
    ('lims', 'publications'): 'publication_id',
    ('lims', 'bookable_resource'): 'resource_id',
    ('lims', 'booking'): 'booking_id',
    
    ('lab', 'storage'): 'storage_id',
    ('lab', 'experiments'): ['experiment_id', 'experiment_date'],
    ('lab', 'experiments_projects'): ['experiment_id', 'project_id', 'experiment_date'],
    ('lab', 'experiments_samples'): ['experiment_id', 'experiment_date', 'sample_id', 'sample_creation_date'],
    ('lab', 'protocol_runs'): 'protocol_run_id',
    ('lab', 'sampling'): ['sampling_id', 'sampling_date'],
    ('lab', 'fishing'): ['fishing_id', 'creation_date'],
    ('lab', 'individual_catch_catch'): ['individual_catch_id', 'creation_date'],
    ('lab', 'sampling_abiotic_data'): ['sampling_id', 'creation_date'],
    ('lab', 'root_samples'): ['sample_id', 'sample_creation_date'],
    ('lab', 'reservation_samples'): ['reservation_sample_id'], 
    ('lab', 'storage_log'): 'log_id',
    ('lab', 'fish'): ['sample_id', 'creation_date'],
    ('lab', 'tissue'): ['sample_id', 'creation_date'],
    ('lab', 'otoliths'): ['sample_id', 'reader_person_id', 'side', 'creation_date'],
    ('lab', 'dna'): ['sample_id', 'creation_date'],
    ('lab', 'rna'): ['sample_id', 'creation_date'],
    ('lab', 'sediments'): ['sample_id', 'creation_date'],
    ('lab', 'water'): ['sample_id', 'creation_date'],
    ('lab', 'pcr'): ['pcr_id', 'creation_date'],
    ('lab', 'dissections'): ['dissection_id', 'creation_date'],
    ('lab', 'nanodrop'): ['nanodrop_id', 'creation_date'],
    ('lab', 'qubit'): ['qubit_id', 'creation_date'],
    ('lab', 'tapestation'): ['tapestation_id', 'creation_date'],
    ('lab', 'gelelectrophoresis'): ['gelelectrophoresis_id', 'creation_date'],
    ('lab', 'qpcr'): ['qpcr_id', 'creation_date'],
    ('lab', 'library'): ['library_id', 'sample_id', 'creation_date'],
    ('lab', 'sequencing_run'): ['sequencing_run_id', 'creation_date'],
    ('lab', 'seq_dataset'): ['data_seq_id', 'creation_date'],
    ('lab', 'datasets'): ['dataset_id', 'reception_date'],
    
    ('bioinformatics', 'analysis_pipelines'): 'pipeline_id',
    ('bioinformatics', 'analysis_runs'): ['run_id', 'creation_date'],
    ('bioinformatics', 'edna_assignments'): ['assignment_id', 'creation_date'],
    
    ('projects', 'projectwanderfische_fishingdata'): ['fishing_record_id', 'record_date'],
    ('projects', 'projectwanderfische_fishcatch'): 'fish_catch_id',
    ('projects', 'projectwanderfische_mail'): 'mail_id',
    ('projects', 'projectwanderfische_conversation'): 'conversation_id',
    ('projects', 'projectwanderfische_chatmessage'): 'message_id',
    
    ('audit', 'log'): 'id',

    # Views
    ('lims', 'project_summary_view'): 'project_id',
    ('lab', 'sample_type_counts_view'): 'sample_type_id',
    ('lab', 'storage_occupancy_view'): 'storage_id',
    ('lims', 'projects_with_contact_details_view'): 'project_id',
    ('reference', 'taxon_hierarchy_view'): 'taxon_id',
    ('lims', 'inventory_reagent_summary_view'): 'reagent_id',
    ('lab', 'project_pipeline_progress_view'): 'project_id',
    ('lab', 'full_sampling_data_view'): ['sampling_id', 'sampling_date'],
    ('bioinformatics', 'analysis_results_view'): 'run_id',
    ('lims', 'publications_by_project_view'): 'project_id',
    ('lims', 'project_comprehensive_summary_view'): 'project_id',
    ('lab', 'experiment_progress_overview_view'): 'experiment_id',
    ('lims', 'reagent_status_view'): 'reagent_id',
    ('lab', 'storage_log_history_view'): 'log_id',
    ('bioinformatics', 'analysis_results_summary_view'): 'run_id',
    ('lab', 'full_sequencing_run_view'): 'sequencing_run_id',
    ('lab', 'global_lims_view'): ['sample_id', 'sample_creation_date'],
    ('lab', 'monthly_sample_reception_mv'): ['reception_month', 'sample_type_id'],
}

VIEW_TO_BASE_TABLE_MAPPING: Dict[str, str] = {
    'lims.project_summary_view': 'lims.projects',
    'lab.sample_type_counts_view': 'lab.root_samples',
    'lab.storage_occupancy_view': 'lab.storage',
    'lims.projects_with_contact_details_view': 'lims.projects',
    'reference.taxon_hierarchy_view': 'reference.taxon',
    'lims.inventory_reagent_summary_view': 'lims.reagents',
    'lab.project_pipeline_progress_view': 'lims.projects',
    'lab.full_sampling_data_view': 'lab.sampling',
    'bioinformatics.analysis_results_view': 'bioinformatics.analysis_runs',
    'lims.publications_by_project_view': 'lims.publications',
    'lims.project_comprehensive_summary_view': 'lims.projects',
    'lab.experiment_progress_overview_view': 'lab.experiments',
    'lims.reagent_status_view': 'lims.reagents',
    'lab.storage_log_history_view': 'lab.storage_log',
    'bioinformatics.analysis_results_summary_view': 'bioinformatics.analysis_runs',
    'lab.full_sequencing_run_view': 'lab.sequencing_run',
    'lab.global_lims_view': 'lab.root_samples',
    'lab.monthly_sample_reception_mv': 'lab.root_samples',
}


def get_db_connection():
    """Establishes and returns a new database connection."""
    try:
        conn = psycopg2.connect(host=DB_HOST, database=DB_NAME, user=DB_USER, password=DB_PASS)
        conn.autocommit = False
        return conn
    except psycopg2.OperationalError as e:
        print(f"FATAL: Could not connect to database at {DB_HOST}. Error: {e}")
        raise

@app.before_request
def before_request_func():
    """
    Establishes a database connection for the request and sets RLS context.
    The 'kasmi' user is a superuser and bypasses RLS policies.
    """
    g.db_conn = get_db_connection()
    person_id_to_set = str(session.get('user_id', '')) # Ensure it's a string for consistency

    try:
        with g.db_conn.cursor() as cur:
            # Set the RLS context (already present)
            cur.execute("SELECT set_config('lims.current_person_id', %s, FALSE)", (person_id_to_set,))
            
            # --- NEW: Set a separate variable for Auditing ---
            cur.execute("SELECT set_config('audit.logged_in_user', %s, FALSE)", (person_id_to_set,))
            
            g.db_conn.commit()
            print(f"RLS & Audit: Set lims.current_person_id and audit.logged_in_user to '{person_id_to_set}'")
    except Exception as e:
        print(f"ERROR: Could not set session variables: {e}")


@app.teardown_request
def teardown_request_func(exception=None):
    """Closes the database connection after each request."""
    if hasattr(g, 'db_conn'):
        if exception and not g.db_conn.closed:
            g.db_conn.rollback()
            print("Database transaction rolled back due to an exception.")
        elif not g.db_conn.closed:
            pass
        g.db_conn.close()

def get_pk_columns(schema: str, table: str) -> List[str]:
    """Retrieves primary key column names for a given table."""
    pk_info = PK_MAPPING.get((schema.lower(), table.lower()))
    if pk_info is None:
        print(f"WARNING: No primary key mapping found for {schema}.{table}. Returning empty list. "
              "Please ensure PK_MAPPING is correct and matches database column casing.")
        return []
    if isinstance(pk_info, str):
        return [pk_info]
    return pk_info

def transform_row_for_json(row: Dict[str, Any]) -> Dict[str, Any]:
    """
    Transforms a database row (RealDictRow) into a JSON-serializable dictionary.
    Handles binary data (bytea) and time/date objects.
    """
    new_row = dict(row)
    for key, value in new_row.items():
        if isinstance(value, (memoryview, bytes)):
            new_row[key] = base64.b64encode(value).decode('utf-8')
        elif isinstance(value, time):
            new_row[key] = str(value)
        elif isinstance(value, datetime) or isinstance(value, date): # Corrected to use date from datetime import
            new_row[key] = value.isoformat()
        elif isinstance(value, dict) and 'type' in value and 'coordinates' in value:
            new_row[key] = value
        elif isinstance(value, list) and all(isinstance(i, dict) and 'type' in i and 'coordinates' in i for i in value):
            new_row[key] = value
    return new_row

_resolved_names_cache: Dict[Tuple[str, str], Tuple[str, str, str]] = {}
_column_types_cache: Dict[Tuple[str, str], Dict[str, str]] = {}

def _resolve_table_casing(conn, requested_schema: str, requested_table: str) -> Optional[Tuple[str, str, str]]:
    """Resolves the actual casing of schema and table names in the database and fetches table type."""
    cache_key = (requested_schema.lower(), requested_table.lower())
    if cache_key in _resolved_names_cache:
        return _resolved_names_cache[cache_key]

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
            
            query_views = """
                SELECT table_schema, table_name
                FROM information_schema.views
                WHERE lower(table_schema) = lower(%s) AND lower(table_name) = lower(%s)
                LIMIT 1;
            """
            cur.execute(query_views, (requested_schema, requested_table))
            result_view = cur.fetchone()
            if result_view:
                actual_schema, actual_table = result_view[0], result_view[1]
                table_type = 'VIEW'
                _resolved_names_cache[cache_key] = (actual_schema, actual_table, table_type)
                return actual_schema, actual_table, table_type
            
            # Check for partitioned tables
            query_partitioned = """
                SELECT parent.relnamespace::regnamespace::text, parent.relname::text, 'PARTITIONED TABLE'
                FROM pg_class AS parent
                JOIN pg_namespace AS ns ON parent.relnamespace = ns.oid
                WHERE ns.nspname = %s AND parent.relname = %s AND parent.relkind = 'p';
            """
            cur.execute(query_partitioned, (requested_schema, requested_table))
            result_partitioned = cur.fetchone()
            if result_partitioned:
                actual_schema, actual_table, table_type = result_partitioned[0], result_partitioned[1], result_partitioned[2]
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


# --- Authentication Routes ---

@app.route(f'{API_PREFIX}/login', methods=['POST'])
def login_user():
    """
    Handles user login across different user tables, including special cases for superadmins.
    """
    data = request.get_json()
    username = data.get('username')
    password = data.get('password')

    if not username or not password:
        return jsonify({"error": "Missing username or password"}), 400

    # Special hardcoded superadmin login for 'TIFI' and 'kasmi'
    if username == 'TIFI' and password == 'password':
        session['user_id'] = 'TIFI'
        session['user_type'] = 'admin'
        session['is_admin'] = True
        return jsonify({"success": True, "user": {"full_name": "TIFI Admin", "person_id": "TIFI"}, "user_type": "admin"}), 200

    if username == 'kasmi' and password == 'password':
        session['user_id'] = 'kasmi'
        session['user_type'] = 'superadmin'
        session['is_admin'] = True
        return jsonify({"success": True, "user": {"full_name": "Kasmi Superadmin", "person_id": "kasmi"}, "user_type": "superadmin"}), 200

    conn = g.db_conn
    try:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            # First, try to log in as a regular lab member
            query_personal = 'SELECT person_id, full_name, password_hash, mail, room, telephone FROM "lims"."personal" WHERE person_id = %s OR mail = %s;'
            cur.execute(query_personal, (username, username))
            user_personal = cur.fetchone()

            if user_personal and user_personal.get('password_hash'):
                # bcrypt.checkpw requires bytes, so we encode the password
                if bcrypt.checkpw(password.encode('utf-8'), user_personal['password_hash'].encode('utf-8')):
                    session['user_id'] = user_personal['person_id']
                    session['user_type'] = 'personal'
                    session['is_admin'] = False
                    user_personal.pop('password_hash', None)
                    return jsonify({"success": True, "user": user_personal, "user_type": "personal"}), 200

            # Then, try to log in as a customer
            query_customers = 'SELECT customer_id, customer_name, mail, password_hash, phone, address FROM "lims"."customers" WHERE mail = %s;'
            cur.execute(query_customers, (username,))
            user_customer = cur.fetchone()

            if user_customer and user_customer.get('password_hash'):
                if bcrypt.checkpw(password.encode('utf-8'), user_customer['password_hash'].encode('utf-8')):
                    # FIX: Convert customer_id (INT) to STRING for RLS context consistency
                    session['user_id'] = str(user_customer['customer_id']) 
                    session['user_type'] = 'customer'
                    session['is_admin'] = False
                    user_customer.pop('password_hash', None)
                    return jsonify({"success": True, "user": user_customer, "user_type": "customer"}), 200

            # Finally, try to log in as an external contact
            query_external_contacts = 'SELECT contact_id, full_name, mail, password_hash, telephone, organization, address FROM "lims"."external_contacts" WHERE mail = %s;'
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

# --- Dashboard & Search Routes ---

@app.route(f'{API_PREFIX}/global-search/<string:search_term>', methods=['GET'])
def global_search(search_term: str):
    """Performs a global search across multiple tables using full-text search or ILIKE."""
    ts_query_func = f"plainto_tsquery('public.lims_english', %s)"
    search_pattern = f"%{search_term}%"

    results: Dict[str, List[Dict[str, Any]]] = {}
    
    queries: Dict[str, Tuple[str, Tuple[Any, ...]]] = {
        "projects": (
            f'SELECT project_id, title FROM "lims"."projects" WHERE project_search_vector @@ {ts_query_func} OR "project_id" ILIKE %s OR "title" ILIKE %s LIMIT 5',
            (search_term, search_pattern, search_pattern)
        ),
        "samples": (
            f'SELECT sample_id, external_name FROM "lab"."root_samples" WHERE sample_search_vector @@ {ts_query_func} OR "sample_id" ILIKE %s OR "external_name" ILIKE %s LIMIT 5',
            (search_term, search_pattern, search_pattern)
        ),
        "experiments": (
            f'SELECT experiment_id, experiment_title FROM "lab"."experiments" WHERE experiment_search_vector @@ {ts_query_func} OR "experiment_id" ILIKE %s OR "experiment_title" ILIKE %s LIMIT 5',
            (search_term, search_pattern, search_pattern)
        ),
        "sop": (
            f'SELECT sop_id, title FROM "lims"."sop" WHERE sop_search_vector @@ {ts_query_func} OR "sop_id" ILIKE %s OR "title" ILIKE %s LIMIT 5',
            (search_term, search_pattern, search_pattern)
        ),
        "customers": (
            f'SELECT customer_id, customer_name FROM "lims"."customers" WHERE customer_search_vector @@ {ts_query_func} OR "customer_name" ILIKE %s LIMIT 5',
            (search_term, search_pattern)
        ),
        "taxon": (
            'SELECT taxon_id, de_name, en_name FROM "reference"."taxon" WHERE "de_name" ILIKE %s OR "en_name" ILIKE %s LIMIT 5',
            (search_pattern, search_pattern)
        ),
        "primers": (
            'SELECT primer_id, primer_sequence_fwd, primer_sequence_rev FROM "lims"."primers" WHERE "primer_id" ILIKE %s OR "primer_sequence_fwd" ILIKE %s OR "primer_sequence_rev" ILIKE %s LIMIT 5',
            (search_pattern, search_pattern, search_pattern)
        ),
        "reagents": (
            'SELECT reagent_id, reagent_complete_name, lot FROM "lims"."reagents" WHERE "reagent_search_vector" @@ {ts_query_func} OR "reagent_id" ILIKE %s OR "reagent_complete_name" ILIKE %s OR "lot" ILIKE %s LIMIT 5',
            (search_term, search_pattern, search_pattern, search_pattern)
        ),
        "personal": (
            'SELECT person_id, full_name FROM "lims"."personal" WHERE "person_id" ILIKE %s OR "full_name" ILIKE %s LIMIT 5',
            (search_pattern, search_pattern)
        ),
        "project_overview_view": (
            'SELECT project_id, title AS project_title FROM "lims"."project_comprehensive_summary_view" WHERE "project_id" ILIKE %s OR "title" ILIKE %s LIMIT 5',
            (search_pattern, search_pattern)
        ),
        "analysis_results_summary_view": (
            'SELECT run_id, sample_id, taxon_en_name FROM "bioinformatics"."analysis_results_summary_view" WHERE "run_id" ILIKE %s OR "sample_id" ILIKE %s OR "taxon_en_name" ILIKE %s LIMIT 5',
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
        conn = g.db_conn
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute("SELECT COUNT(*) AS active_projects FROM \"lims\".\"projects\" WHERE \"status_id\" = 'In Progress';")
            stats['active_projects'] = cur.fetchone()['active_projects']

            cur.execute("SELECT COUNT(*) AS total_samples FROM \"lab\".\"root_samples\";")
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
                WHERE "status_id" = 'In Progress';
            """)
            stats['active_orders'] = cur.fetchone()['active_orders']

            cur.execute("""
                SELECT COUNT(DISTINCT storage_id) AS occupied_storage_units
                FROM "lab"."root_samples"
                WHERE storage_id IS NOT NULL;
            """)
            stats['occupied_storage_units'] = cur.fetchone()['occupied_storage_units']

            cur.execute("SELECT COUNT(*) AS total_sops FROM \"lims\".\"sop\";")
            stats['total_sops'] = cur.fetchone()['total_sops']
            
            cur.execute("SELECT COUNT(*) AS total_experiments FROM \"lab\".\"experiments\";")
            stats['total_experiments'] = cur.fetchone()['total_experiments']

            cur.execute("""
                SELECT COUNT(*) AS active_personnel
                FROM "lims"."personal"
                WHERE "status_id" != 'Destroyed' AND "status_id" != 'Archived';
            """)
            stats['active_personnel'] = cur.fetchone()['active_personnel']


        return jsonify(stats), 200
    except Exception as e:
        print(f"Dashboard stats error: {e}")
        return jsonify({"error": "An internal server error occurred while fetching dashboard stats."}), 500


# --- Table Metadata Routes ---

@app.route(f'{API_PREFIX}/table_names_for_forms', methods=['GET'])
def table_names_for_forms():
    """
    Returns a list of all table and view names in specified schemas,
    suitable for populating dynamic forms.
    """
    try:
        conn = g.db_conn
        with conn.cursor() as cur:
            query = """
            SELECT table_schema || '.' || table_name
            FROM information_schema.tables
            WHERE table_schema IN ('lab', 'lims', 'reference', 'bioinformatics', 'audit', 'projects')
              AND table_type IN ('BASE TABLE', 'VIEW', 'MATERIALIZED VIEW')
              AND table_name NOT LIKE '%_seq'
              AND table_name NOT LIKE '%_y%'
              AND table_name NOT IN ('log', 'master_samples')
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

        resolved = _resolve_table_casing(conn, schema, table)
        if not resolved:
            return jsonify({"error": f"Table or view '{schema}.{table}' not found or inaccessible."}), 404
        
        actual_schema, actual_table, table_type_info = resolved

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
            col['table_type'] = table_type_info


        return jsonify(columns), 200
    except Exception as e:
        print(f"Error fetching schema for {schema}.{table}: {e}")
        return jsonify({"error": str(e)}), 500


# --- Filter Support Route (NEW) ---

@app.route(f'{API_PREFIX}/table/<string:schema>/<string:table>/distinct_values', methods=['GET'])
def get_distinct_column_values(schema: str, table: str):
    """
    Fetches a list of distinct, non-null values for a specified column
    from a table, optionally constrained by a pre-filter (WHERE clause).
    """
    conn = g.db_conn
    column_name = request.args.get('column')
    
    if not column_name:
        return jsonify({"error": "Missing 'column' parameter"}), 400

    try:
        resolved = _resolve_table_casing(conn, schema, table)
        if not resolved:
            return jsonify({"error": f"Table or view '{schema}.{table}' not found or inaccessible."}), 404
        actual_schema, actual_table, table_type = resolved
        
        column_types = _get_column_types(conn, actual_schema, actual_table)

        if column_name not in column_types:
            return jsonify({"error": f"Column '{column_name}' does not exist in {schema}.{table}"}), 404

        # Dynamic filtering based on query parameters (e.g., filter_project_id=P001)
        where_clauses: List[str] = []
        params: List[Any] = []
        
        # Collect all filter_XXX parameters except the column we are querying distinct values for
        for key, value in request.args.items():
            if key.startswith('filter_') and key != f'filter_{column_name}' and value:
                col_to_filter = key[len('filter_'):]
                
                # Check if the column exists to prevent injection errors
                if col_to_filter not in column_types:
                    continue 

                col_type = column_types[col_to_filter]
                
                # Handling date column filters (assuming client filters by year for simplicity)
                if col_to_filter == 'planned_collection_date' and len(value) == 4 and value.isdigit():
                    try:
                        year = int(value)
                        start_date = date(year, 1, 1)
                        end_date = date(year + 1, 1, 1)
                        where_clauses.append(f'"{col_to_filter}" >= %s AND "{col_to_filter}" < %s')
                        params.extend([start_date, end_date])
                    except ValueError:
                        pass # Ignore invalid year format
                
                # General exact match for ID fields or numeric/date types
                elif col_to_filter.endswith('_id') or col_to_filter == 'project_id' or col_type in ['integer', 'bigint', 'date']:
                    where_clauses.append(f'"{col_to_filter}" = %s')
                    params.append(value)
                
                # General ILIKE for text fields
                elif col_type in ['text', 'character varying']:
                    where_clauses.append(f'"{col_to_filter}" ILIKE %s')
                    params.append(f'%{value}%')


        # Construct the query using psycopg2.sql
        query_template = sql.SQL('SELECT DISTINCT {} FROM {}.{}')
        
        if where_clauses:
            query_template = sql.SQL('SELECT DISTINCT {} FROM {}.{} WHERE {}')

        query = query_template.format(
            sql.Identifier(column_name),
            sql.Identifier(actual_schema),
            sql.Identifier(actual_table),
            sql.SQL(' AND ').join(map(sql.SQL, where_clauses)) if where_clauses else sql.SQL('')
        )
        
        # Final query execution
        final_query = query
        print(f"Executing DISTINCT query: {final_query.as_string(conn)} with params: {params}")

        with conn.cursor() as cur:
            cur.execute(final_query, params)
            # Filter out None/NULL values and return a simple list
            distinct_values = [row[0] for row in cur.fetchall() if row[0] is not None]
        
        return jsonify(distinct_values), 200
        
    except Exception as e:
        print(f"Error fetching distinct values for {schema}.{table}.{column_name}: {e}")
        return jsonify({"error": str(e)}), 500


# --- CRUD Routes (General) ---

@app.route(f'{API_PREFIX}/table/<string:schema>/<string:table>', methods=['GET'])
def get_table_data(schema: str, table: str):
    """
    Fetches data from a specified table or view, with optional filters, ordering, and pagination.
    Supports filtering by specific IDs, dates, and a general 'filter_' prefix for other columns.
    """
    conn = g.db_conn
    try:
        resolved = _resolve_table_casing(conn, schema, table)
        if not resolved:
            return jsonify({"error": f"Table or view '{schema}.{table}' not found or inaccessible."}), 404
        
        actual_schema, actual_table, table_type = resolved
        
        where_clauses: List[str] = []
        params: List[Any] = []
        
        filter_project_id_value = request.args.get('filter_project_id')
        filter_experiment_id_value = request.args.get('filter_experiment_id')
        filter_experiment_date_value = request.args.get('filter_experiment_date')
        filter_sample_id_value = request.args.get('filter_sample_id')
        filter_sample_creation_date_value = request.args.get('filter_sample_creation_date')
        filter_sampling_id_value = request.args.get('filter_sampling_id')
        filter_sampling_date_value = request.args.get('filter_sampling_date')
        filter_protocol_id_value = request.args.get('filter_protocol_id')
        exclude_status_id_value = request.args.get('exclude_status_id')
        filter_status_id_value = request.args.get('filter_status_id')
        filter_associated_experiment_id_value = request.args.get('filter_associated_experiment_id')
        filter_associated_experiment_date_value = request.args.get('filter_associated_experiment_date')
        filter_planned_collection_date_ge_value = request.args.get('filter_planned_collection_date_ge')
        
        # Booking specific filters
        filter_start_time_start_value = request.args.get('filter_start_time_start')
        filter_end_time_end_value = request.args.get('filter_end_time_end')

        base_query_select = f'SELECT "{actual_table}".*'
        base_query_from = f'FROM "{actual_schema}"."{actual_table}"'
        
        def parse_date_filter(date_str):
            """Helper to parse date strings into date objects."""
            try:
                return datetime.strptime(date_str, '%Y-%m-%d').date()
            except (ValueError, TypeError):
                return None
        
        def parse_datetime_filter(dt_str):
            """Helper to parse datetime strings into datetime objects."""
            try:
                return datetime.fromisoformat(dt_str)
            except (ValueError, TypeError):
                return None


        if actual_table.lower() == 'booking':
            if filter_start_time_start_value:
                start_dt = parse_datetime_filter(filter_start_time_start_value)
                if start_dt:
                    where_clauses.append(f'"{actual_table}"."end_time" >= %s')
                    params.append(start_dt)
            if filter_end_time_end_value:
                end_dt = parse_datetime_filter(filter_end_time_end_value)
                if end_dt:
                    where_clauses.append(f'"{actual_table}"."start_time" < %s')
                    params.append(end_dt)


        if filter_planned_collection_date_ge_value and actual_table.lower() == 'reservation_samples':
            filter_date_obj = parse_date_filter(filter_planned_collection_date_ge_value)
            if filter_date_obj:
                where_clauses.append(f'"{actual_table}"."planned_collection_date" >= %s')
                params.append(filter_date_obj)


        if filter_experiment_id_value and filter_experiment_date_value:
            filter_exp_date_obj = parse_date_filter(filter_experiment_date_value)
            if actual_schema.lower() == 'lab' and actual_table.lower() == 'experiments':
                where_clauses.append(f'"{actual_table}"."experiment_id" ILIKE %s')
                params.append(f'%{filter_experiment_id_value}%')
                where_clauses.append(f'"{actual_table}"."experiment_date" = %s')
                params.append(filter_exp_date_obj)
            elif actual_schema.lower() == 'bioinformatics' and actual_table.lower() == 'analysis_runs':
                base_query_from += f"""
                    JOIN "lab"."sequencing_run" AS S ON "{actual_table}".sequencing_id = S.sequencing_run_id 
                    AND "{actual_table}".sequencing_date = S.creation_date
                """
                where_clauses.append(f'S.experiment_id ILIKE %s')
                params.append(f'%{filter_experiment_id_value}%')
                where_clauses.append(f'S.experiment_date = %s')
                params.append(filter_exp_date_obj)
            elif actual_schema.lower() == 'bioinformatics' and actual_table.lower() == 'edna_assignments':
                base_query_from += f"""
                    JOIN "bioinformatics"."analysis_runs" AS AR ON "{actual_table}".run_id = AR.run_id 
                    AND "{actual_table}".run_creation_date = AR.creation_date
                    JOIN "lab"."sequencing_run" AS S ON AR.sequencing_id = S.sequencing_run_id 
                    AND AR.sequencing_date = S.creation_date
                """
                where_clauses.append(f'S.experiment_id ILIKE %s')
                params.append(f'%{filter_experiment_id_value}%')
                where_clauses.append(f'S.experiment_date = %s')
                params.append(filter_exp_date_obj)
            elif actual_schema.lower() == 'lab' and actual_table.lower() in [
                'experiments_projects', 'experiments_samples', 'protocol_runs', 
                'dissections', 'nanodrop', 'qubit', 'tapestation', 
                'gelelectrophoresis', 'qpcr', 'library', 'sequencing_run', 
                'datasets'
            ]:
                where_clauses.append(f'"{actual_table}"."experiment_id" ILIKE %s')
                params.append(f'%{filter_experiment_id_value}%')
                where_clauses.append(f'"{actual_table}"."experiment_date" = %s')
                params.append(filter_exp_date_obj)
        
        if filter_sample_id_value:
            if actual_schema.lower() == 'lab' and actual_table.lower() == 'root_samples':
                where_clauses.append(f'"{actual_table}"."sample_id" ILIKE %s')
                params.append(f'%{filter_sample_id_value}%')
                if filter_sample_creation_date_value:
                    filter_samp_create_date_obj = parse_date_filter(filter_sample_creation_date_value)
                    where_clauses.append(f'"{actual_table}"."sample_creation_date" = %s')
                    params.append(filter_samp_create_date_obj)
            elif actual_schema.lower() == 'lab' and actual_table.lower() in ['fish', 'tissue', 'otoliths', 'dna', 'rna', 'sediments', 'water', 'experiments_samples', 'dissections', 'nanodrop', 'qubit', 'tapestation', 'gelelectrophoresis', 'pcr', 'qpcr', 'library', 'sequencing_run', 'seq_dataset', 'datasets', 'storage_log', 'reservation_samples']:
                where_clauses.append(f'"{actual_table}"."sample_id" ILIKE %s')
                params.append(f'%{filter_sample_id_value}%')
                if filter_sample_creation_date_value:
                    filter_samp_create_date_obj = parse_date_filter(filter_sample_creation_date_value)
                    where_clauses.append(f'"{actual_table}"."sample_creation_date" = %s')
                    params.append(filter_samp_create_date_obj)
            elif actual_schema.lower() == 'bioinformatics' and actual_table.lower() == 'edna_assignments':
                where_clauses.append(f'"{actual_table}"."sample_id" ILIKE %s')
                params.append(f'%{filter_sample_id_value}%')
                if filter_sample_creation_date_value:
                    filter_samp_create_date_obj = parse_date_filter(filter_sample_creation_date_value)
                    where_clauses.append(f'"{actual_table}"."sample_creation_date" = %s')
                    params.append(filter_samp_create_date_obj)
        
        if filter_sampling_id_value and filter_sampling_date_value:
            filter_samp_date_obj = parse_date_filter(filter_sampling_date_value)
            if actual_schema.lower() == 'lab' and actual_table.lower() == 'sampling':
                where_clauses.append(f'"{actual_table}"."sampling_id" ILIKE %s')
                params.append(f'%{filter_sampling_id_value}%')
                where_clauses.append(f'"{actual_table}"."sampling_date" = %s')
                params.append(filter_samp_date_obj)
            elif actual_schema.lower() == 'lab' and actual_table.lower() in ['root_samples', 'fishing', 'individual_catch_catch', 'sampling_abiotic_data', 'reservation_samples']:
                where_clauses.append(f'"{actual_table}"."sampling_id" ILIKE %s')
                params.append(f'%{filter_sampling_id_value}%')
                where_clauses.append(f'"{actual_table}"."sampling_date" = %s')
                params.append(filter_samp_date_obj)
        
        if filter_project_id_value:
            if 'project_id' in _get_column_types(conn, actual_schema, actual_table):
                where_clauses.append(f'"{actual_table}"."project_id" ILIKE %s')
                params.append(f'%{filter_project_id_value}%')

        if filter_protocol_id_value:
            if 'protocol_id' in _get_column_types(conn, actual_schema, actual_table):
                where_clauses.append(f'"{actual_table}"."protocol_id" = %s')
                params.append(filter_protocol_id_value)

        if exclude_status_id_value:
            if 'status_id' in _get_column_types(conn, actual_schema, actual_table):
                where_clauses.append(f'"{actual_table}"."status_id" != %s')
                params.append(exclude_status_id_value)
        if filter_status_id_value:
            if 'status_id' in _get_column_types(conn, actual_schema, actual_table):
                # Handle comma-separated list of statuses
                status_list = [s.strip() for s in filter_status_id_value.split(',') if s.strip()]
                if status_list:
                    placeholders = ', '.join(['%s'] * len(status_list))
                    where_clauses.append(f'"{actual_table}"."status_id" IN ({placeholders})')
                    params.extend(status_list)

        order_by_column: Optional[str] = None
        order_direction: str = 'ASC'
        limit: Optional[int] = None
        offset: Optional[int] = None
        
        for key, value in request.args.items():
            if not value:
                continue
            
            if key in ['filter_project_id', 'filter_experiment_id', 'filter_experiment_date', 
                       'filter_sample_id', 'filter_sample_creation_date', 'filter_sampling_id',
                       'filter_sampling_date', 'filter_protocol_id', 'exclude_status_id', 
                       'filter_status_id', 'filter_associated_experiment_id', 'filter_associated_experiment_date',
                       'filter_planned_collection_date_ge', 'filter_start_time_start', 'filter_end_time_end']: # Added all filters
                continue

            if key == 'limit':
                limit = int(value)
                continue
            elif key == 'offset':
                offset = int(value)
                continue
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
            else:
                if key in _get_column_types(conn, actual_schema, actual_table):
                    where_clauses.append(f'"{key}" = %s')
                    params.append(value)


        query = f"{base_query_select} {base_query_from}"
        if where_clauses:
            query += f" WHERE {' AND '.join(where_clauses)}"
            
        if order_by_column:
            # Check if order_by_column is a valid column name before using it
            if order_by_column in _get_column_types(conn, actual_schema, actual_table):
                quoted_order_by_column = f'"{actual_table}"."{order_by_column}"'
                query += f' ORDER BY {quoted_order_by_column} {order_direction}'
            else:
                print(f"Warning: Invalid order_by column '{order_by_column}' skipped.")
            
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
    conn = g.db_conn
    try:
        resolved = _resolve_table_casing(conn, schema, table)
        if not resolved:
            return jsonify({"error": f"Table '{schema}.{table}' not found or inaccessible."}), 404
        actual_schema, actual_table, table_type = resolved

        column_types = _get_column_types(conn, actual_schema, actual_table)

        data = {}
        files = request.files

        if request.is_json:
            data = request.get_json()
        elif request.form:
            data = request.form.to_dict()

        if not data and not files:
            return jsonify({"error": "No data provided"}), 400
            
        if 'attachment' in files and files['attachment'].filename != '':
            data['attachment'] = psycopg2.Binary(files['attachment'].read())
        elif 'attachment' in data and (data['attachment'] == '' or (isinstance(data['attachment'], dict) and not data['attachment'])):
            data['attachment'] = None
            
        if (actual_schema.lower() == 'lims' and actual_table.lower() == 'personal') or \
           (actual_schema.lower() == 'lims' and actual_table.lower() == 'customers') or \
           (actual_schema.lower() == 'lims' and actual_table.lower() == 'external_contacts'):
            if 'password' in data and data['password']:
                hashed_password = bcrypt.hashpw(data['password'].encode('utf-8'), bcrypt.gensalt())
                data['password_hash'] = hashed_password.decode('utf-8')
            data.pop('password', None)
            
        project_ids_str = None
        sample_ids_str = None
        linked_person_ids = None
        
        # --- Root Sample Logic (Fix for missing project_id/customer_id) ---
        if actual_schema.lower() == 'lab' and actual_table.lower() == 'root_samples':
            if data.get('parent_sample_id') is None and data.get('project_id') is None and data.get('customer_id') is None:
                # Set a known project_id for the ID function to work if neither is provided
                print("WARNING: Missing project_id/customer_id for new root sample. Using PROJ_FALLBACK.")
                data['project_id'] = 'Proj_BioMon' # Assuming 'Proj_BioMon' exists and is accessible
        # --- END Root Sample Logic ---


        if actual_schema.lower() == 'lab' and actual_table.lower() == 'experiments':
            project_ids_str = data.pop('project_ids', None)
            sample_ids_str = data.pop('sample_ids', None)
        elif actual_schema.lower() == 'lims' and actual_table.lower() == 'projects':
            if 'linked_person_ids' in data:
                linked_person_ids = [p.strip() for p in data.pop('linked_person_ids', '').split(';') if p.strip()]

        filtered_data = {}
        for k, v in data.items():
            if k == 'attachment':
                filtered_data[k] = v
            elif k == 'attachment_link' and v == '':
                filtered_data[k] = None
            elif v == '':
                filtered_data[k] = None
            elif k.endswith('_id') and (str(v).lower() == 'undefined' or str(v).lower() == 'null'):
                filtered_data[k] = None
            elif k.endswith('_id') and column_types.get(k) == 'integer' and v is not None:
                 try:
                     filtered_data[k] = int(v)
                 except ValueError:
                     filtered_data[k] = None # Cast ID strings to int for integer FKs
            elif column_types.get(k) == 'jsonb' and isinstance(v, str):
                try:
                    filtered_data[k] = json.loads(v)
                except json.JSONDecodeError:
                    print(f"WARNING: Invalid JSON for column '{k}'. Storing as None. Value: {v}")
                    filtered_data[k] = None
            elif column_types.get(k) == 'boolean':
                filtered_data[k] = str(v).lower() in ['true', 'on']
            elif column_types.get(k) == 'date' and isinstance(v, str) and v:
                try:
                    filtered_data[k] = datetime.strptime(v, '%Y-%m-%d').date()
                except ValueError:
                    print(f"WARNING: Invalid date format for column '{k}'. Storing as None. Value: {v}")
                    filtered_data[k] = None
            else:
                filtered_data[k] = v
            
        columns = filtered_data.keys()
        values = [filtered_data[col] for col in columns]
        
        column_names = ', '.join([f'"{col}"' for col in columns])
        value_placeholders = ', '.join(['%s'] * len(values))
        
        query = f'INSERT INTO "{actual_schema}"."{actual_table}" ({column_names}) VALUES ({value_placeholders}) RETURNING *;'
        
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            print(f"Executing POST query: {query} with values: {values}")
            cur.execute(query, values)
            new_record = cur.fetchone()
            
            if actual_schema.lower() == 'lab' and actual_table.lower() == 'experiments' and new_record:
                experiment_id = new_record['experiment_id']
                experiment_date = new_record['experiment_date'] # Date object
                
                # --- Link Projects ---
                if project_ids_str:
                    project_list = [p.strip() for p in project_ids_str.split(';') if p.strip()]
                    for project_id in project_list:
                        try:
                            cur.execute(
                                'INSERT INTO "lab"."experiments_projects" ("experiment_id", "experiment_date", "project_id") VALUES (%s, %s, %s);',
                                (experiment_id, experiment_date, project_id)
                            )
                        except Exception as e:
                            print(f"  Warning: Could not link project {project_id} to experiment {experiment_id}: {e}")

                # --- Link Samples ---
                if sample_ids_str:
                    sample_list = [s.strip() for s in sample_ids_str.split(';') if s.strip()]
                    for sample_id in sample_list:
                        try:
                            cur.execute(
                                'SELECT "sample_creation_date" FROM "lab"."root_samples" WHERE "sample_id" = %s;', (sample_id,)
                            )
                            sample_creation_date = cur.fetchone()['sample_creation_date'] # Date object
                            cur.execute(
                                'INSERT INTO "lab"."experiments_samples" ("experiment_id", "experiment_date", "sample_id", "sample_creation_date") VALUES (%s, %s, %s, %s);',
                                (experiment_id, experiment_date, sample_id, sample_creation_date)
                            )
                        except Exception as e:
                            print(f"  Warning: Could not link sample {sample_id} to experiment {experiment_id}: {e}")
            
            elif actual_schema.lower() == 'lims' and actual_table.lower() == 'projects' and new_record and linked_person_ids:
                project_id = new_record['project_id']
                for person_id in linked_person_ids:
                    try:
                        cur.execute(
                            'INSERT INTO "lims"."project_persons" ("project_id", "person_id") VALUES (%s, %s);',
                            (project_id, person_id)
                        )
                        print(f"  Linked person {person_id} to new project {project_id}")
                    except Exception as e:
                        print(f"  Warning: Could not link person {person_id} to new project {project_id}: {e}")
            
            conn.commit()
        return jsonify(transform_row_for_json(new_record)), 201
    except Exception as e:    
        if conn:
            conn.rollback()
        print(f"Error creating record in {schema}.{table}: {e}")
        return jsonify({"error": str(e)}), 500
            
@app.route(f'{API_PREFIX}/table/<string:schema>/<string:table>', methods=['PUT'])
def update_record(schema: str, table: str):
    """
    Updates an existing record in the specified table identified by its primary key(s).
    Handles file uploads, password hashing, and ignores special linked records.
    """
    conn = g.db_conn
    try:
        resolved = _resolve_table_casing(conn, schema, table)
        if not resolved:
            return jsonify({"error": f"Table '{schema}.{table}' not found or inaccessible."}), 404
        actual_schema, actual_table, table_type = resolved

        pk_columns = get_pk_columns(schema, table)
        column_types = _get_column_types(conn, actual_schema, actual_table)

        pk_values_from_request = {}
        for pk_col in pk_columns:
            pk_val = request.args.get(pk_col)
            if pk_val is None:
                return jsonify({"error": f"Missing primary key component: {pk_col}"}), 400
            
            if column_types.get(pk_col) == 'date':
                try:
                    pk_values_from_request[pk_col] = datetime.strptime(pk_val, '%Y-%m-%d').date()
                except (ValueError, TypeError):
                    pk_values_from_request[pk_col] = pk_val
            else:
                pk_values_from_request[pk_col] = pk_val

        data = {}
        files = request.files

        if request.is_json:
            data = request.get_json()
        elif request.form:
            data = request.form.to_dict()

        if not data and not files:
            return jsonify({"error": "No data provided"}), 400

        if 'attachment' in files and files['attachment'].filename != '':
            data['attachment'] = psycopg2.Binary(files['attachment'].read())
        elif 'attachment' in data and (data['attachment'] == '' or (isinstance(data['attachment'], dict) and not data['attachment'])):
            data['attachment'] = None

        set_clauses: List[str] = []
        values: List[Any] = []
        
        if (actual_schema.lower() == 'lims' and actual_table.lower() == 'personal') or \
           (actual_schema.lower() == 'lims' and actual_table.lower() == 'customers') or \
           (actual_schema.lower() == 'lims' and actual_table.lower() == 'external_contacts'):
            if 'password' in data and data['password']:
                hashed_password = bcrypt.hashpw(data['password'].encode('utf-8'), bcrypt.gensalt())
                data['password_hash'] = hashed_password.decode('utf-8')
            data.pop('password', None)
            
        for key, val in data.items():
            if key in pk_columns or key in ['project_ids', 'sample_ids', 'linked_person_ids']:
                continue
            
            elif key == 'attachment_link' and val == '':
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
                values.append(str(val).lower() in ['true', 'on'])
            elif column_types.get(key) == 'date' and isinstance(val, str) and val:
                try:
                    set_clauses.append(f'"{key}" = %s')
                    values.append(datetime.strptime(val, '%Y-%m-%d').date())
                except ValueError:
                    print(f"WARNING: Invalid date format for column '{key}'. Skipping update for this field.")
                    continue
            elif column_types.get(key) == 'timestamp with time zone' and isinstance(val, str) and val:
                try:
                    # Parse local datetime string from HTML and assume it's in the client's timezone, 
                    set_clauses.append(f'"{key}" = %s')
                    values.append(datetime.strptime(val, '%Y-%m-%dT%H:%M'))
                except ValueError:
                    print(f"WARNING: Invalid datetime format for column '{key}'. Skipping update for this field.")
                    continue
            else:
                set_clauses.append(f'"{key}" = %s')
                values.append(None if val == '' else val)
            
        if not set_clauses:
            return jsonify({"error": "No fields to update"}), 400

        pk_where_clauses = []
        pk_where_values: List[Any] = [] 
        for pk_col in pk_columns:
            pk_where_clauses.append(f'"{pk_col}" = %s')
            pk_val = pk_values_from_request[pk_col]
            if column_types.get(pk_col) == 'date' and pk_val is not None:
                # Need to ensure that PK date strings are converted back to date objects for comparison
                if isinstance(pk_val, str):
                    try:
                        pk_where_values.append(datetime.strptime(pk_val, '%Y-%m-%d').date())
                    except ValueError:
                        pk_where_values.append(pk_val) # Fallback to string if date conversion fails
                else:
                    pk_where_values.append(pk_val)
            else:
                pk_where_values.append(pk_val)
        
        all_values = values + pk_where_values
        
        query = f'UPDATE "{actual_schema}"."{actual_table}" SET {", ".join(set_clauses)} WHERE {" AND ".join(pk_where_clauses)} RETURNING *;'
        
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            print(f"Executing PUT query: {query} with values: {all_values}")
            cur.execute(query, all_values)
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
    """
    Deletes a record from the specified table using its primary key(s) or filters.
    """
    conn = g.db_conn
    try:
        resolved = _resolve_table_casing(conn, schema, table)
        if not resolved:
            return jsonify({"error": f"Table '{schema}.{table}' not found or inaccessible."}), 404
        actual_schema, actual_table, table_type = resolved

        pk_columns = get_pk_columns(schema, table)
        column_types = _get_column_types(conn, actual_schema, actual_table)

        pk_values_for_query = []
        where_clauses = []
        
        # Handle query parameters for mass deletion (e.g., /table/lims/project_persons?filter_project_id=P001)
        mass_delete_params = {k: v for k, v in request.args.items() if k.startswith('filter_')}
        
        if mass_delete_params:
            for key, val in mass_delete_params.items():
                col_name = key[len('filter_'):]
                if col_name in column_types:
                    where_clauses.append(f'"{col_name}" = %s')
                    if column_types.get(col_name) == 'date':
                        try:
                            pk_values_for_query.append(datetime.strptime(val, '%Y-%m-%d').date())
                        except ValueError:
                            pk_values_for_query.append(val)
                    else:
                        pk_values_for_query.append(val)
                else:
                    return jsonify({"error": f"Invalid filter column for deletion: {col_name}"}), 400
            
            if not where_clauses:
                 return jsonify({"error": "No valid filter criteria provided for mass deletion."}), 400

        else: # Standard PK-based single deletion
            for pk_col in pk_columns:
                pk_val = request.args.get(pk_col)
                if pk_val is None:
                    return jsonify({"error": f"Missing primary key component for deletion: {pk_col}"}), 400
                
                if column_types.get(pk_col) == 'date' and pk_val is not None:
                    try:
                        pk_val = datetime.strptime(pk_val, '%Y-%m-%d').date();
                    except ValueError:
                        pass

                where_clauses.append(f'"{pk_col}" = %s')
                pk_values_for_query.append(pk_val)

        query = f'DELETE FROM "{actual_schema}"."{actual_table}" WHERE {" AND ".join(where_clauses)} RETURNING *;'
        
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            print(f"Executing DELETE query: {query} with params: {pk_values_for_query}")
            cur.execute(query, pk_values_for_query)
            
            # Use cur.rowcount for mass deletion, cur.fetchone() for single deletion check
            if mass_delete_params:
                deleted_count = cur.rowcount
                conn.commit()
                return jsonify({"success": True, "message": f"Successfully deleted {deleted_count} records.", "deleted_count": deleted_count}), 200
            
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
    """
    Handles bulk insertion of records from a list of dictionaries (e.g., from CSV/JSON upload).
    Supports special linking logic for experiments/projects/samples and projects/persons.
    """
    conn = g.db_conn
    try:
        resolved = _resolve_table_casing(conn, schema, table)
        if not resolved:
            return jsonify({"error": f"Table '{schema}.{table}' not found or inaccessible."}), 404
        actual_schema, actual_table, table_type = resolved

        column_types = _get_column_types(conn, actual_schema, actual_table)

        records = request.get_json()
        if not records or not isinstance(records, list):
            return jsonify({"error": "Invalid data format. Expected a list of records."}), 400
            
        if not records:
            return jsonify({"success": True, "inserted_rows": 0}), 200

        inserted_count = 0
        
        if actual_schema.lower() == 'lab' and actual_table.lower() == 'experiments':
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
                for record_data in records:
                    project_ids_str = record_data.pop('project_ids', None)
                    sample_ids_str = record_data.pop('sample_ids', None)

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
                        elif column_types.get(k) == 'date' and isinstance(v, str) and v: # <-- FIX: Handle date string
                            try:
                                filtered_record[k] = datetime.strptime(v, '%Y-%m-%d').date()
                            except ValueError:
                                print(f"WARNING: Invalid date format for column '{k}'. Storing as None. Value: {v}")
                                filtered_record[k] = None
                        else:
                            filtered_record[k] = v
                    
                    # Password/Attachment handling (copied from original, ensuring consistency)
                    if (actual_schema.lower() == 'lims' and actual_table.lower() == 'personal') or \
                       (actual_schema.lower() == 'lims' and actual_table.lower() == 'customers') or \
                       (actual_schema.lower() == 'lims' and actual_table.lower() == 'external_contacts'):
                        if 'password' in filtered_record and filtered_record['password']:
                            hashed_password = bcrypt.hashpw(filtered_record['password'].encode('utf-8'), bcrypt.gensalt())
                            filtered_record['password_hash'] = hashed_password.decode('utf-8')
                        filtered_record.pop('password', None)
                    
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

                    if 'attachment_link' in filtered_record and filtered_record['attachment_link'] == '':
                        filtered_record['attachment_link'] = None
                            
                    columns = filtered_record.keys()
                    values = [filtered_record[col] for col in columns]

                    column_names = ', '.join([f'"{col}"' for col in columns])
                    value_placeholders = ', '.join(['%s'] * len(values))
                    
                    insert_query = f'INSERT INTO "{actual_schema}"."{actual_table}" ({column_names}) VALUES ({value_placeholders}) RETURNING *;'
                    
                    try:
                        cur.execute(insert_query, values)
                        new_record = cur.fetchone()
                        if new_record:
                            inserted_count += 1

                            experiment_id = new_record['experiment_id']
                            # FIX: Use the actual returned date object for linking
                            experiment_date = new_record['experiment_date'] 

                            if project_ids_str:
                                project_list = [p.strip() for p in project_ids_str.split(';') if p.strip()]
                                for project_id in project_list:
                                    try:
                                        cur.execute(
                                            'INSERT INTO "lab"."experiments_projects" ("experiment_id", "experiment_date", "project_id") VALUES (%s, %s, %s);',
                                            (experiment_id, experiment_date, project_id) # <-- FIX: Pass date object
                                        )
                                    except Exception as e:
                                        print(f"  Warning: Could not link project {project_id} to experiment {experiment_id} during batch upload: {e}")

                            if sample_ids_str:
                                sample_list = [s.strip() for s in sample_ids_str.split(';') if s.strip()]
                                for sample_id in sample_list:
                                    try:
                                        cur.execute(
                                            'SELECT "sample_creation_date" FROM "lab"."root_samples" WHERE "sample_id" = %s;', (sample_id,)
                                        )
                                        sample_creation_date = cur.fetchone()['sample_creation_date'] # Date object
                                        cur.execute(
                                            'INSERT INTO "lab"."experiments_samples" ("experiment_id", "experiment_date", "sample_id", "sample_creation_date") VALUES (%s, %s, %s, %s);',
                                            (experiment_id, experiment_date, sample_id, sample_creation_date) # <-- FIX: Pass date objects
                                        )
                                    except Exception as e:
                                        print(f"  Warning: Could not link sample {sample_id} to experiment {experiment_id}: {e}")
                    except Exception as e:
                        print(f"Error inserting individual record in batch for {actual_schema}.{actual_table}: {e}")
                conn.commit()
        
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
                        elif column_types.get(k) == 'date' and isinstance(v, str) and v:
                            try:
                                filtered_record[k] = datetime.strptime(v, '%Y-%m-%d').date()
                            except ValueError:
                                print(f"WARNING: Invalid date format for column '{k}'. Storing as None. Value: {v}")
                                filtered_record[k] = None
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
                        if new_project:
                            inserted_count += 1

                            if linked_person_ids_str:
                                project_id = new_project['project_id']
                                person_list = [p.strip() for p in linked_person_ids_str.split(';') if p.strip()]
                                for person_id in person_list:
                                    try:
                                        cur.execute(
                                            'INSERT INTO "lims"."project_persons" ("project_id", "person_id") VALUES (%s, %s);',
                                            (project_id, person_id)
                                        )
                                    except Exception as e:
                                        print(f"  Warning: Could not link person {person_id} to project {project_id} during batch upload: {e}")
                    except Exception as e:
                        print(f"Error inserting individual project record in batch: {e}")
                conn.commit()
        
        else:
            if not records:
                return jsonify({"success": True, "inserted_rows": 0}), 200

            first_record_keys = list(records[0].keys())
            processed_records_for_insertion = []

            for record in records:
                if set(record.keys()) != set(first_record_keys):
                    conn.rollback()
                    return jsonify({"error": "All records in batch must have the same set of columns for batch insertion."}), 400

                temp_record = record.copy()
                if (actual_schema.lower() == 'lims' and actual_table.lower() == 'personal') or \
                   (actual_schema.lower() == 'lims' and actual_table.lower() == 'customers') or \
                   (actual_schema.lower() == 'lims' and actual_table.lower() == 'external_contacts'):
                    if 'password' in temp_record and temp_record['password']:
                        hashed_password = bcrypt.hashpw(temp_record['password'].encode('utf-8'), bcrypt.gensalt())
                        temp_record['password_hash'] = hashed_password.decode('utf-8')
                    temp_record.pop('password', None)
                
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

                for k, v in temp_record.items():
                    if column_types.get(k) == 'jsonb' and isinstance(v, str):
                        try:
                            temp_record[k] = json.loads(v)
                        except json.JSONDecodeError:
                            print(f"WARNING: Invalid JSON for column '{k}'. Storing as None. Value: {v}")
                            temp_record[k] = None
                    elif column_types.get(k) == 'boolean':
                        temp_record[k] = str(v).lower() in ['true', 'on']
                    elif column_types.get(k) == 'date' and isinstance(v, str) and v:
                        try:
                            temp_record[k] = datetime.strptime(v, '%Y-%m-%d').date()
                        except ValueError:
                            print(f"WARNING: Invalid date format for column '{k}'. Storing as None. Value: {v}")
                            temp_record[k] = None
                    else:
                        temp_record[k] = v

                processed_records_for_insertion.append({k: (v if v != '' else None) for k, v in temp_record.items()})

            columns = list(processed_records_for_insertion[0].keys())
            column_names = ', '.join([f'"{col}"' for col in columns])
            
            data_tuples: List[Tuple[Any, ...]] = []
            for record_data in processed_records_for_insertion:
                row = []
                for col in columns:
                    val = record_data.get(col)
                    row.append(val)
                data_tuples.append(tuple(row))

            query_template = f"INSERT INTO \"{actual_schema}\".\"{actual_table}\" ({column_names}) VALUES %s"
            
            with conn.cursor() as cur:
                print(f"Executing batch_upload query: {query_template} with {len(data_tuples)} records.")
                psycopg2.extras.execute_values(cur, query_template, data_tuples)
                conn.commit()
            inserted_count = len(records)
            
        return jsonify({"success": True, "inserted_rows": inserted_count}), 201
    except Exception as e:    
        if conn:
            conn.rollback()
        print(f"Error during batch upload for {schema}.{table}: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@app.route(f'{API_PREFIX}/table/<string:schema>/<string:table>/batch_update', methods=['PUT'])
def batch_update(schema: str, table: str):
    """
    Performs a bulk update of records.
    Expects a JSON array of objects, where each object contains primary key(s)
    and fields to update.
    """
    conn = g.db_conn
    try:
        resolved = _resolve_table_casing(conn, schema, table)
        if not resolved:
            return jsonify({"error": f"Table '{schema}.{table}' not found or inaccessible."}), 404
        actual_schema, actual_table, table_type = resolved

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
                pk_where_clauses_parts: List[str] = []
                pk_where_values: List[Any] = []

                update_fields = {k: v for k, v in record_data.items() if k not in pk_columns}
                pk_fields = {k: v for k, v in record_data.items() if k in pk_columns}

                if not all(pk_col in pk_fields for pk_col in pk_columns):
                    print(f"  Warning: Skipping record in batch update due to missing primary key(s): {record_data}")
                    continue
                
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
                        set_values.append(str(val).lower() in ['true', 'on'])
                    elif column_types.get(key) == 'date' and isinstance(val, str) and val:
                        try:
                            set_clauses_parts.append(f'"{key}" = %s')
                            set_values.append(datetime.strptime(val, '%Y-%m-%d').date())
                        except ValueError:
                            print(f"WARNING: Invalid date format for column '{key}'. Skipping update for this field.")
                            continue
                    else:
                        set_clauses_parts.append(f'"{key}" = %s')
                        set_values.append(None if val == '' else val)
                
                if not set_clauses_parts:
                    print(f"  Warning: Skipping record in batch update as no update fields provided: {record_data}")
                    continue

                for pk_col in pk_columns:
                    pk_where_clauses_parts.append(f'"{pk_col}" = %s')
                    pk_val = pk_fields[pk_col]
                    if column_types.get(pk_col) == 'date' and pk_val is not None:
                        try:
                            pk_where_values.append(datetime.strptime(str(pk_val), '%Y-%m-%d').date())
                        except ValueError:
                            pk_where_values.append(pk_val)
                    else:
                        pk_where_values.append(pk_val)
                
                all_values = set_values + pk_where_values
                
                update_query = f'UPDATE "{actual_schema}"."{actual_table}" SET {", ".join(set_clauses_parts)} WHERE {" AND ".join(pk_where_clauses_parts)} RETURNING *;'
                
                try:
                    cur.execute(update_query, all_values)
                    if cur.fetchone():
                        updated_count += 1
                    else:
                        print(f"  Warning: Record not found for update in batch: {record_data}")
                except Exception as e:
                    print(f"  Error updating record in batch for {actual_schema}.{actual_table} (PK: {pk_fields}): {e}")
            conn.commit()
            return jsonify({"success": True, "updated_rows": updated_count}), 200

    except Exception as e:
        if conn:
            conn.rollback()
        print(f"Error during batch update for {schema}.{table}: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


@app.route('/')
def root():    
    """Redirects the root URL to the login page."""
    return redirect(url_for('serve_static', filename='login.html'))

@app.route('/<path:filename>')
def serve_static(filename: str):
    """Serves static files from the STATIC_FOLDER."""
    return send_from_directory(app.static_folder, filename)

if __name__ == '__main__':
    host: str = '0.0.0.0'
    port: int = 5400

    print("="*60 + f"\n TIFI LIMS Backend Server ".center(60, "=") + "\n" + " Serving Multi-Table Login ".center(60, "=") + "\n" + "=".center(60, "="))
    print(f" -> Serving LIMS frontend from: {os.path.abspath(STATIC_FOLDER)}")
    print(f" -> API listening on http://{host}:{port}{API_PREFIX}/")
    print(f" -> Access the UI at http://127.0.0.1:{port}")
    print("="*60)

    if FLASK_ENV == "development":
        app.run(host=host, port=port, debug=True)
    else:
        serve(app, host=host, port=port)
