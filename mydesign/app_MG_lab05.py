import os
import psycopg2
import psycopg2.extras
import bcrypt
from flask import Flask, jsonify, request, send_from_directory, redirect, url_for
from flask_cors import CORS
from waitress import serve # For production-ready server
import base64
from typing import Any, Dict, List, Optional, Tuple, Union

# --- Configuration ---
# IMPORTANT: For production, use environment variables for sensitive data like passwords.
DB_HOST: str = os.getenv('DB_HOST', '0.0.0.0')
DB_NAME: str = os.getenv('DB_NAME', 'MG_lab')
DB_USER: str = os.getenv('DB_USER', 'kasmi')
DB_PASS: str = os.getenv('DB_PASS', 'password')

STATIC_FOLDER: str = '.' # Serves frontend files from the directory where app.py is run
FLASK_ENV: str = os.getenv('FLASK_ENV', 'production') # 'development' for debugging, 'production' for deployment
API_PREFIX: str = os.getenv('API_PREFIX', '/api') # e.g., '/api', '/mymglab/api'

app = Flask(__name__, static_folder=STATIC_FOLDER)
CORS(app) # Enable CORS for all routes

# --- Primary Key Mapping ---
# Maps (schema_name_lower, table_name_lower) to their primary key column name (case-sensitive as in DB).
# This is crucial for generic PUT/DELETE/GET by ID.
# For tables with composite PKs (e.g., Lims.ProjectPersons, Lab.ExperimentSamples),
# generic PUT/DELETE by a single PK won't work correctly unless 'nr' is a unique row identifier.
# For truly robust composite PK operations, custom API routes would be needed.
PK_MAPPING: Dict[Tuple[str, str], str] = {
    # Schema: Reference
    ('reference', 'status'): 'status_id',
    ('reference', 'room'): 'room_id',
    ('reference', 'genes'): 'primer_id',
    ('reference', 'location'): 'Region', # Corrected based on your schema
    ('reference', 'samplestype'): 'sample_type',
    ('reference', 'species'): 'Species', # Case-sensitive column name
    ('reference', 'category'): 'category',
    ('reference', 'personal'): 'person_id',

    # Schema: Lims
    ('lims', 'projects'): 'project_id',
    ('lims', 'equipment'): 'equipment_id',
    ('lims', 'sop'): 'sop_id',
    ('lims', 'orders'): 'FI_Order_Nr',
    ('lims', 'reagents'): 'Reagent_Name',
    ('lims', 'workflows'): 'Workflow_id', # Primary key for Workflows (note: 'Workflow_id' as per your schema)
    ('lims', 'workflow_steps'): 'step_id', # Primary key for Workflow_steps

    # Schema: Lab
    ('lab', 'storage'): 'storage_id',
    ('lab', 'sampling'): 'Sampling_id',
    ('lab', 'experiments'): 'Experiment_Nr',
    ('lab', 'samples'): 'sample_id', # Critical: 'sample_id' is the PK, not 'nr'
    ('lab', 'fish'): 'sample_id',
    ('lab', 'tissue'): 'sample_id',
    ('lab', 'dna'): 'sample_id',
    ('lab', 'rna'): 'sample_id',
    ('lab', 'sediments'): 'sample_id',
    ('lab', 'water'): 'sample_id',
    ('lab', 'extraction'): 'nr',
    ('lab', 'nanodrop'): 'nr',
    ('lab', 'qubit'): 'nr',
    ('lab', 'tapestation'): 'nr',
    ('lab', 'pcr'): 'nr',
    ('lab', 'gelelectrophoresis'): 'nr',
    ('lab', 'qpcr'): 'nr',
    ('lab', 'library'): 'Library_id',
    ('lab', 'sequencing'): 'sequencing_id',
    ('lab', 'bioinformatics'): 'bioinfo_id',
    ('lab', 'protocols'): 'nr',
    ('lab', 'samples_tracking'): 'sample_id', # Primary key for the view
    
    # Schema: Project_Wanderfische
    ('project_wanderfische', 'budget'): 'nr',
    ('project_wanderfische', 'deliverables'): 'nr',
}

# --- Database Connection ---
def get_db_connection():
    """Establishes a connection to the PostgreSQL database."""
    try:
        conn = psycopg2.connect(host=DB_HOST, database=DB_NAME, user=DB_USER, password=DB_PASS)
        return conn
    except psycopg2.OperationalError as e:
        print(f"FATAL: Could not connect to database at {DB_HOST}. Error: {e}")
        raise # Re-raise to stop server if DB connection fails on startup

# --- Helper Functions ---
def get_pk_column(schema: str, table: str) -> str:
    """Retrieves the primary key column name for a given schema and table."""
    return PK_MAPPING.get((schema.lower(), table.lower()), 'nr')

def transform_row_for_json(row: Dict[str, Any]) -> Dict[str, Any]:
    """Converts special data types (like memoryview from bytea) in a row for JSON serialization."""
    new_row = dict(row) # Create a mutable copy
    for key, value in new_row.items():
        if isinstance(value, memoryview):
            # Encode binary data to Base64 string
            new_row[key] = base64.b64encode(value.tobytes()).decode('utf-8')
        elif isinstance(value, bytes):
            # Also handle direct bytes objects
            new_row[key] = base64.b64encode(value).decode('utf-8')
    return new_row

# --- API Endpoints ---

@app.route(f'{API_PREFIX}/login', methods=['POST'])
def login_user():
    """Handles user login authentication."""
    data = request.get_json()
    person_id = data.get('person_id')
    password = data.get('password')

    if not person_id or not password:
        return jsonify({"error": "Missing person_id or password"}), 400

    # Simple demo login for development/testing
    if FLASK_ENV == 'development' and person_id == 'demo' and password == 'password':
        return jsonify({"success": True, "user": {"person": "Demo User", "person_id": "demo"}}), 200

    query = 'SELECT person, person_id, password_hash FROM "Reference"."Personal" WHERE person_id = %s;'
    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute(query, (person_id,))
            user = cur.fetchone()
            
        if user and user.get('password_hash') and bcrypt.checkpw(password.encode('utf-8'), user['password_hash'].encode('utf-8')):
            user.pop('password_hash', None) # Remove hash for security
            return jsonify({"success": True, "user": user}), 200
        else:
            return jsonify({"error": "Invalid credentials"}), 401
    except Exception as e:
        print(f"Login error for {person_id}: {e}")
        return jsonify({"error": "An internal server error occurred during login."}), 500
    finally:
        if conn:
            conn.close()

@app.route(f'{API_PREFIX}/global-search/<string:search_term>', methods=['GET'])
def global_search(search_term: str):
    """Searches across multiple tables for a given term."""
    search_pattern = f"%{search_term}%"
    results: Dict[str, List[Dict[str, Any]]] = {}
    
    queries: Dict[str, Tuple[str, Tuple[str, ...]]] = {
        "projects": ('SELECT project_id, "Title" FROM "Lims"."Projects" WHERE project_id ILIKE %s OR "Title" ILIKE %s LIMIT 5', (search_pattern, search_pattern)),
        "samples": ('SELECT sample_id, sample_type, workflow_status_id FROM "Lab"."Samples" WHERE sample_id ILIKE %s LIMIT 5', (search_pattern,)),
        "experiments": ('SELECT "Experiment_Nr", "Experiment_title" FROM "Lab"."Experiments" WHERE "Experiment_Nr" ILIKE %s OR "Experiment_title" ILIKE %s LIMIT 5', (search_pattern, search_pattern)),
    }
    
    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            for key, (query, params) in queries.items():
                cur.execute(query, params)
                results[key] = [transform_row_for_json(row) for row in cur.fetchall()]
        return jsonify(results), 200
    except Exception as e:
        print(f"Global search error: {e}")
        return jsonify({"error": "An internal server error occurred during search."}), 500
    finally:
        if conn:
            conn.close()

@app.route(f'{API_PREFIX}/dashboard-stats', methods=['GET'])
def get_dashboard_stats():
    """Fetches key statistics for the dashboard."""
    query = """
    SELECT
        (SELECT COUNT(*) FROM "Lims"."Projects" WHERE "status_id" = 'Active') AS active_projects,
        (SELECT COUNT(*) FROM "Lab"."Samples") AS total_samples,
        (SELECT COUNT(*) FROM "Lab"."Experiments" WHERE "Date" >= date_trunc('month', CURRENT_DATE)) AS experiments_this_month,
        (SELECT COUNT(*) FROM "Lims"."Reagents" WHERE "Expire_date" BETWEEN CURRENT_DATE AND CURRENT_DATE + interval '30 day') AS reagents_expiring_soon;
    """
    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute(query)
            stats = cur.fetchone()
        return jsonify(stats), 200
    except Exception as e:
        print(f"Dashboard stats error: {e}")
        return jsonify({"error": "An internal server error occurred while fetching dashboard stats."}), 500
    finally:
        if conn:
            conn.close()

@app.route(f'{API_PREFIX}/table_names_for_forms', methods=['GET'])
def table_names_for_forms():
    """
    Returns a list of table names relevant for 'Target Table Name' dropdowns.
    Queries the database's information_schema for base tables in specific schemas.
    """
    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor() as cur:
            query = """
            SELECT table_schema || '.' || table_name
            FROM information_schema.tables
            WHERE table_schema IN ('Lab', 'Lims', 'Reference', 'Project_Wanderfische')
              AND table_type = 'BASE TABLE'
              AND table_name NOT LIKE '%_sequence' -- Exclude sequence tables
              AND table_name NOT IN ('sample_id_sequence', 'aliquot_sequence', 'sampling_id_sequence')
            ORDER BY table_schema, table_name;
            """
            cur.execute(query)
            tables = [row[0] for row in cur.fetchall()]
            return jsonify(tables), 200
    except Exception as e:
        print(f"Error fetching table names for forms: {e}")
        return jsonify({"error": str(e)}), 500
    finally:
        if conn:
            conn.close()

@app.route(f'{API_PREFIX}/table/<string:schema>/<string:table>', methods=['GET'])
def get_table_data(schema: str, table: str):
    """
    Generic function to fetch data from a table or view, with optional filtering and limit.
    Handles PostgreSQL's case-sensitive schema/table names with proper quoting.
    """
    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            # Use specific quoted names for schemas and tables as they appear in DB
            # This is crucial for case-sensitive PostgreSQL identifiers
            full_qualified_name = f'"{schema}"."{table}"'
            
            base_query = f'SELECT * FROM {full_qualified_name}'
            where_clauses: List[str] = []
            params: List[Any] = []

            # Process query parameters for filtering
            for key, value in request.args.items():
                if not value:
                    continue # Skip empty values

                # Handle specific query parameters (e.g., 'limit', 'offset')
                if key == 'limit':
                    continue # Processed later
                if key == 'offset':
                    continue # Processed later

                # For filtering data by column values:
                # Use quoted column names to respect case-sensitivity in DB
                # Example: filter_column=value OR column_name=value
                if key.startswith('filter_'):
                    col_name = key[len('filter_'):]
                    where_clauses.append(f'"{col_name}" ILIKE %s') # Case-insensitive search for flexibility
                    params.append(f'%{value}%')
                else:
                    # Direct equality filters for known foreign keys or primary keys
                    # This list should include any column name you might directly filter by in the UI
                    # e.g., ?sample_id=XYZ, ?project_id=ABC
                    # Ensure the key here matches the exact column name in the DB
                    filterable_columns = [
                        'sample_id', 'project_id', 'status_id', 'sop_id', 'person_id',
                        'room_id', 'category', 'primer_id', 'sample_type', 'Region',
                        'Species', 'Sampling_id', 'Experiment_Nr', 'External_Name',
                        'workflow_id', 'Workflow_name', 'Workflow_Status_id', 'step_id', # Workflow related
                        'FI_Order_Nr', 'Reagent_Name', 'equipment_id', 'Library_id',
                        'sequencing_id', 'bioinfo_id'
                    ]
                    if key in filterable_columns:
                        where_clauses.append(f'"{key}" = %s') # Exact match for specific columns
                        params.append(value)
                    # Add any other generic filters if needed here

            if where_clauses:
                query = f"{base_query} WHERE {' AND '.join(where_clauses)}"
            else:
                query = base_query
            
            # Add LIMIT and OFFSET if provided in query parameters
            limit = request.args.get('limit', type=int)
            offset = request.args.get('offset', type=int)
            if limit is not None:
                query += f" LIMIT %s"
                params.append(limit)
            if offset is not None:
                query += f" OFFSET %s"
                params.append(offset)

            query += ";" # End the query

            print(f"Executing GET query: {query} with params: {params}") 
            cur.execute(query, params)
            data = cur.fetchall()
            
            processed_data = [transform_row_for_json(row) for row in data]
            
            return jsonify(processed_data), 200
    except Exception as e:
        print(f"Error fetching table data for {schema}.{table}: {e}")
        return jsonify({"error": str(e)}), 500
    finally:    
        if conn:
            conn.close()
        
@app.route(f'{API_PREFIX}/table/<string:schema>/<string:table>', methods=['POST'])
def create_record(schema: str, table: str):
    """Generic function to create a new record in a table."""
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

    filtered_data = {k: (v if v != '' else None) for k, v in data.items()}
    
    columns = filtered_data.keys()
    values = list(filtered_data.values())
    
    # Use original case for column names from the data keys for quoting
    column_names = ', '.join([f'"{col}"' for col in columns])
    value_placeholders = ', '.join(['%s'] * len(values))
    
    # Use the schema and table names as they appear in the database definition for quoting
    query = f'INSERT INTO "{schema}"."{table}" ({column_names}) VALUES ({value_placeholders}) RETURNING *;'
    conn = None
    try:
        conn = get_db_connection()
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
    finally:    
        if conn:
            conn.close()

@app.route(f'{API_PREFIX}/table/<string:schema>/<string:table>/<pk_value>', methods=['PUT'])
def update_record(schema: str, table: str, pk_value: Union[str, int]):
    """Generic function to update an existing record in a table."""
    pk_column = get_pk_column(schema, table)
    data = request.get_json()
    if not data:    
        return jsonify({"error": "No data provided"}), 400
        
    set_clauses: List[str] = []
    values: List[Any] = []
    
    for key, val in data.items():
        set_clauses.append(f'"{key}" = %s')
        values.append(None if val == '' else val)    
    
    if not set_clauses:
        return jsonify({"error": "No fields to update"}), 400

    try:
        # Convert PK value to int if the PK column is integer-based
        if pk_column in ['nr', 'bioinfo_id', 'Workflow_id', 'step_id']: # Note: 'Workflow_id' for Lims.Workflows
            param_pk_value = int(pk_value)
        else:
            param_pk_value = pk_value
        values.append(param_pk_value)
    except ValueError:
        return jsonify({"error": f"Invalid ID format for '{pk_column}': {pk_value}"}), 400
        
    # Use exact schema and table names as in DB for quoting
    query = f'UPDATE "{schema}"."{table}" SET {", ".join(set_clauses)} WHERE "{pk_column}" = %s RETURNING *;'
    conn = None
    try:
        conn = get_db_connection()
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
    finally:    
        if conn:
            conn.close()

@app.route(f'{API_PREFIX}/table/<string:schema>/<string:table>/<pk_value>', methods=['DELETE'])
def delete_record(schema: str, table: str, pk_value: Union[str, int]):
    """Generic function to delete a record from a table."""
    pk_column = get_pk_column(schema, table)
    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor() as cur:
            # Convert PK value to int if the PK column is integer-based
            try:
                if pk_column in ['nr', 'bioinfo_id', 'Workflow_id', 'step_id']:
                    param_pk_value = int(pk_value)
                else:
                    param_pk_value = pk_value
            except ValueError:
                return jsonify({"error": f"Invalid ID format for '{pk_column}': {pk_value}"}), 400

            # Use exact schema and table names as in DB for quoting
            query = f'DELETE FROM "{schema}"."{table}" WHERE "{pk_column}" = %s;'
            print(f"Executing DELETE query: {query} with param: {param_pk_value}")
            cur.execute(query, (param_pk_value,))
            conn.commit()
            if cur.rowcount == 0:    
                return jsonify({"error": "Record not found"}), 404
        return "", 204
    except Exception as e:    
        if conn:
            conn.rollback()
        print(f"Error deleting record in {schema}.{table}: {e}")
        return jsonify({"error": str(e)}), 500
    finally:    
        if conn:
            conn.close()

@app.route(f'{API_PREFIX}/table/<string:schema>/<string:table>/batch_upload', methods=['POST'])
def batch_upload(schema: str, table: str):
    """Handles batch insertion of records into a table."""
    records = request.get_json()
    if not records or not isinstance(records, list):    
        return jsonify({"error": "Invalid data format. Expected a list of records."}), 400
    
    if not records:
        return jsonify({"success": True, "inserted_rows": 0}), 200

    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor() as cur:
            columns = list(records[0].keys()) # Ensure consistent column order
            column_names = ', '.join([f'"{col}"' for col in columns])
            
            data_tuples: List[Tuple[Any, ...]] = []
            for record in records:
                row = []
                for col in columns:
                    val = record.get(col)
                    row.append(None if val == '' else val)
                data_tuples.append(tuple(row))

            # Use exact schema and table names as in DB for quoting
            query_template = f"INSERT INTO \"{schema}\".\"{table}\" ({column_names}) VALUES %s"
            
            print(f"Executing batch_upload query: {query_template} with {len(data_tuples)} records.")
            psycopg2.extras.execute_values(cur, query_template, data_tuples)
            conn.commit()
        return jsonify({"success": True, "inserted_rows": len(records)}), 201
    except Exception as e:
        if conn:    
            conn.rollback()
        print(f"Error during batch upload for {schema}.{table}: {e}")
        return jsonify({"success": False, "error": str(e)}), 500
    finally:    
        if conn:
            conn.close()

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

    print("="*60 + f"\n TIFI LIMS Backend Server ".center(60, "=") + "\n" + "="*60)
    print(f" -> Serving LIMS frontend from: {os.path.abspath(STATIC_FOLDER)}")
    print(f" -> API listening on http://{host}:{port}{API_PREFIX}/")
    print(f" -> Access the UI at http://127.0.0.1:{port}")
    print("="*60)

    if FLASK_ENV == "development":
        app.run(host=host, port=port, debug=True)
    else:
        serve(app, host=host, port=port)