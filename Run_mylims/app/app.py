# app.py

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
import traceback

# Optional: load environment variables from a file named 'my.env'
# load_dotenv("my.env")

# --- Configuration ---
# Main LIMS Database (mylims)
DB_HOST: str = os.getenv('DB_HOST', '0.0.0.0') 
DB_NAME: str = os.getenv('DB_NAME', 'mylims')
DB_USER: str = os.getenv('DB_USER', 'web_admin')
DB_PASS: str = os.getenv('DB_PASS', 'password')

# Secondary Authentication Database (musr)
AUTH_DB_HOST: str = os.getenv('AUTH_DB_HOST', '0.0.0.0')
AUTH_DB_NAME: str = os.getenv('AUTH_DB_NAME', 'musr')
AUTH_DB_USER: str = os.getenv('AUTH_DB_USER', 'auth_user')
AUTH_DB_PASS: str = os.getenv('AUTH_DB_PASS', 'auth_password')

SECRET_KEY: str = os.getenv('SECRET_KEY', 'a_very_secret_key_for_session_management_and_security')

STATIC_FOLDER: str = '.'
FLASK_ENV: str = os.getenv('FLASK_ENV', 'production')
API_PREFIX: str = os.getenv('API_PREFIX', '/api') 

app = Flask(__name__, static_folder=STATIC_FOLDER)
app.secret_key = SECRET_KEY
CORS(app, supports_credentials=True)

# --- Primary Key Mapping (CONFIGURATION) ---
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

    # Views (using the base table PK)
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
    ('lab', 'monthly_sample_reception_mv'): 'lab.root_samples',
}


# --- UTILITY FUNCTIONS ---
def safe_date_parse(date_str: str) -> Optional[date]:
    """Safely converts a string to a date object."""
    if not date_str or not isinstance(date_str, str):
        return None
    
    try:
        return datetime.strptime(date_str, '%Y-%m-%d').date()
    except ValueError:
        pass
    
    try:
        if 'T' in date_str:
            date_part = date_str.split('T')[0]
            return datetime.strptime(date_part, '%Y-%m-%d').date()
    except ValueError:
        pass
        
    try:
        return date.fromisoformat(date_str)
    except (ValueError, TypeError):
        print(f"Warning: Failed to parse date string '{date_str}' in safe_date_parse.")
        return None

def get_db_connection():
    """Establishes and returns a new database connection to mylims."""
    print(f"DEBUG LIMS: Attempting connection to host={DB_HOST}, db={DB_NAME}, user={DB_USER}")
    try:
        conn = psycopg2.connect(host=DB_HOST, database=DB_NAME, user=DB_USER, password=DB_PASS)
        conn.autocommit = False
        return conn
    except psycopg2.OperationalError as e:
        print(f"FATAL: LIMS DB Connection Failed. Check DB_HOST/Credentials. Error: {e}")
        raise

def get_auth_db_connection():
    """Establishes and returns a new database connection to musr."""
    print(f"DEBUG AUTH: Attempting connection to host={AUTH_DB_HOST}, db={AUTH_DB_NAME}, user={AUTH_DB_USER}")
    try:
        conn = psycopg2.connect(host=AUTH_DB_HOST, database=AUTH_DB_NAME, user=AUTH_DB_USER, password=AUTH_DB_PASS)
        conn.autocommit = True
        return conn
    except psycopg2.OperationalError as e:
        print(f"FATAL: AUTH DB Connection Failed. Check AUTH_DB_HOST/Credentials. Error: {e}")
        return None

@app.before_request
def before_request_func():
    """Establishes a DB connection for the request and sets RLS context."""
    try:
        g.db_conn = get_db_connection()
    except Exception as e:
        print(f"CRITICAL: Failed to initialize database connection pool for request: {e}")
        return jsonify({"error": f"Internal Server Error: Database initialization failed. Check server logs."}), 503
    
    # Set RLS Context
    person_id_to_set = str(session.get('user_id', '')) 
    try:
        with g.db_conn.cursor() as cur:
            cur.execute("SELECT set_config('lims.current_person_id', %s, FALSE)", (person_id_to_set,))
            cur.execute("SELECT set_config('audit.logged_in_user', %s, FALSE)", (person_id_to_set,))
            g.db_conn.commit()
            print(f"RLS & Audit: Set context to '{person_id_to_set}'")
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
        return []
    if isinstance(pk_info, str):
        return [pk_info]
    return pk_info

def transform_row_for_json(row: Dict[str, Any]) -> Dict[str, Any]:
    """Transforms a database row into a JSON-serializable dictionary."""
    new_row = dict(row)
    for key, value in new_row.items():
        if isinstance(value, (memoryview, bytes)):
            new_row[key] = base64.b64encode(value).decode('utf-8')
        elif isinstance(value, time):
            new_row[key] = str(value)
        elif isinstance(value, datetime) or isinstance(value, date):
            new_row[key] = value.isoformat()
        elif isinstance(value, dict) and 'type' in value and 'coordinates' in value:
            new_row[key] = value
        elif isinstance(value, list) and all(isinstance(i, dict) and 'type' in i and 'coordinates' in i for i in value):
            new_row[key] = value
    return new_row

_resolved_names_cache: Dict[Tuple[str, str], Tuple[str, str, str]] = {}
_column_types_cache: Dict[Tuple[str, str], Dict[str, str]] = {}

def _resolve_table_casing(conn, requested_schema: str, requested_table: str) -> Optional[Tuple[str, str, str]]:
    """Resolves the actual casing of schema and table names and fetches table type."""
    cache_key = (requested_schema.lower(), requested_table.lower())
    if cache_key in _resolved_names_cache:
        return _resolved_names_cache[cache_key]

    query = """
        SELECT table_schema, table_name, table_type
        FROM information_schema.tables
        WHERE lower(table_schema) = lower(%s) AND lower(table_name) = lower(%s)
        UNION ALL
        SELECT table_schema, table_name, 'VIEW'
        FROM information_schema.views
        WHERE lower(table_schema) = lower(%s) AND lower(table_name) = lower(%s)
        LIMIT 1;
    """
    try:
        with conn.cursor() as cur:
            cur.execute(query, (requested_schema, requested_table, requested_schema, requested_table))
            result = cur.fetchone()
            if result:
                actual_schema, actual_table, table_type = result[0], result[1], result[2]
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

def _parse_malformed_input(data: Dict[str, Any]) -> Dict[str, Any]:
    """Attempts to fix data received as a single key containing concatenated column names."""
    try:
        if len(data) == 1 and isinstance(list(data.keys())[0], str) and ';' in list(data.keys())[0]:
            print("WARNING: Detected malformed single-key payload. Attempting manual parsing...")
            malformed_key = list(data.keys())[0]
            malformed_value = data[malformed_key]
            col_names = [k.strip() for k in malformed_key.split(';')]
            raw_col_values = malformed_value.split(';')

            if len(col_names) == len(raw_col_values) and len(col_names) > 1:
                new_data = {k: v for k, v in zip(col_names, raw_col_values) if k}
                print(f"Manually parsed data successfully into {len(new_data)} key/value pairs.")
                return new_data
            else:
                print(f"ERROR: Manual parsing failed due to count mismatch.")
    except Exception as e:
        print(f"CRITICAL PARSING EXCEPTION in _parse_malformed_input: {e}")
    
    return data # Return original data if parsing fails


# --- REGISTER ROUTE MODULES ---
# This step is CRITICAL to ensure all endpoints defined in the other files are loaded.
import auth_routes
import data_routes
# --- END ROUTE REGISTRATION ---

# --- Static Routes & Main Runner ---
@app.route('/')
def root():    
    """Redirects the root URL to the login page."""
    return redirect(url_for('serve_static', filename='login.html'))

@app.route('/<path:filename>')
def serve_static(filename: str):
    """Serves static files from the STATIC_FOLDER."""
    # Ensure the correct function signature is used
    return send_from_directory(app.static_folder, filename)

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
        # Use Waitress for production serving
        serve(app, host=host, port=port)