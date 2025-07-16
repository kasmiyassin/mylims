import os
import psycopg2
import psycopg2.extras
import bcrypt
from flask import Flask, jsonify, request, send_from_directory, redirect, url_for
from flask_cors import CORS
from waitress import serve # For production-ready server
import base64 # Added this import for Base64 encoding

# Database connection details
# IMPORTANT: For production, use environment variables for sensitive data like passwords.
DB_HOST = os.getenv('DB_HOST', '0.0.0.0') # Use 'localhost' if running DB on same machine and not accessing from other containers
DB_NAME = os.getenv('DB_NAME', 'migfish')
DB_USER = os.getenv('DB_USER', 'kasmi')
DB_PASS = os.getenv('DB_PASS', 'password') # Replace with your actual password or env var

# Static folder for serving frontend files (current directory where app.py is run)
STATIC_FOLDER = '.'
app = Flask(__name__, static_folder=STATIC_FOLDER)

# IMPORTANT: Set FLASK_ENV to "development" for debugging, "production" for deployment.
# For development, you might use app.run(debug=True) instead of waitress.
# For production, keep debug=False.
FLASK_ENV = os.getenv('FLASK_ENV', 'production') # Default to production

CORS(app) # Enable CORS for all routes (essential for frontend-backend communication)

def get_db_connection():
    """Establishes a connection to the PostgreSQL database."""
    try:
        conn = psycopg2.connect(host=DB_HOST, database=DB_NAME, user=DB_USER, password=DB_PASS)
        return conn
    except psycopg2.OperationalError as e:
        # Log a fatal error if database connection fails
        print(f"FATAL: Could not connect to database at {DB_HOST}. Error: {e}")
        # In a real application, you might want to log this more robustly and potentially exit.
        raise # Re-raise to stop server if DB connection fails on startup

def get_pk_column(schema, table):
    """
    Determines the primary key column for a given table based on schema and table name.
    This is crucial for the generic PUT and DELETE endpoints to work correctly.
    Defaults to 'nr' if no specific primary key is defined.
    """
    # Normalize schema and table names to lowercase for robust matching
    schema_lower = schema.lower()
    table_lower = table.lower()

    special_cases = {
        # Schema: Reference
        ('reference', 'status'): 'status_id',
        ('reference', 'room'): 'room_id',
        ('reference', 'gene'): 'gene_id', # Corrected from 'genes' to 'gene', and 'primer_id' to 'gene_id'
        ('reference', 'region'): 'region_id', # Corrected from 'location' to 'region', and 'Region' to 'region_id'
        ('reference', 'samplestype'): 'sample_type',
        ('reference', 'species'): 'species', # Case-sensitive column name in DB is 'species'
        ('reference', 'category'): 'category',
        ('reference', 'personal'): 'person_id',
        ('reference', 'vessel'): 'vessel_id',
        ('reference', 'ecosystem'): 'ecosystem_id',
        ('reference', 'taxon'): 'taxon_id',

        # Schema: Lims
        ('lims', 'customers'): 'customer_id',
        ('lims', 'projects'): 'project_id',
        # 'ProjectPersons' has a composite PK (project_id, person_id).
        # Generic PUT/DELETE by a single PK value won't work directly for composite keys.
        # If operations on ProjectPersons require both keys, a custom endpoint is needed.
        # For now, it will default to 'nr' if accessed generically, which is likely incorrect.
        # ('lims', 'projectpersons'): ('project_id', 'person_id'), # Composite PK - handled by custom routes if needed
        ('lims', 'cruises'): 'cruise_id',
        ('lims', 'workflows'): 'workflow_id',
        ('lims', 'permits'): 'permit_id',
        ('lims', 'primers'): 'primer_id', # Corrected from 'genes' to 'primers'
        ('lims', 'sop'): 'sop_id',
        ('lims', 'workflow_steps'): 'step_id',
        ('lims', 'equipment'): 'equipment_id',
        ('lims', 'orders'): 'FI_Order_Nr', # 'FI_Order_Nr' is UNIQUE, suitable as a single PK for API
        ('lims', 'reagents'): 'Reagents_id', # Corrected from 'Reagent_Name' to 'Reagents_id'

        # Schema: Lab
        ('lab', 'storage'): 'storage_id',
        ('lab', 'experiments'): 'Experiment_id', # Corrected from 'Experiment_Nr' to 'Experiment_id'
        ('lab', 'experimentsprojects'): 'ExperimentsProjects_id', # This is a serial PK, 'nr' is not used here.
        ('lab', 'protocols'): 'nr', # Explicitly define 'nr' as PK for Protocols
        ('lab', 'sampling'): 'sampling_id', # Corrected from 'Sampling_id' to 'sampling_id'
        ('lab', 'fishing'): 'fishing_id',
        ('lab', 'samples'): 'sample_id', # Critical: 'sample_id' is the PK, not 'nr'
        # 'ExperimentSamples' has a composite PK (Experiment_Nr, sample_id).
        # Similar to ProjectPersons, generic PUT/DELETE won't work directly.
        # ('lab', 'experimentsamples'): ('Experiment_id', 'sample_id'), # Composite PK - handled by custom routes if needed
        ('lab', 'storage_log'): 'log_id', # Serial PK
        ('lab', 'fish'): 'sample_id',
        ('lab', 'tissue'): 'sample_id',
        ('lab', 'otoliths'): 'sample_id', # Composite PK ('sample_id', 'reader_id', 'side') - generic PUT/DELETE won't work directly.
        ('lab', 'dna'): 'sample_id',
        ('lab', 'rna'): 'sample_id',
        ('lab', 'sediments'): 'sample_id',
        ('lab', 'water'): 'sample_id',
        ('lab', 'dissections'): 'dissection_id',
        ('lab', 'extraction'): 'Extraction_id', # Corrected from 'nr' to 'Extraction_id'
        ('lab', 'nanodrop'): 'nr',
        ('lab', 'qubit'): 'nr',
        ('lab', 'tapestation'): 'nr',
        ('lab', 'pcr'): 'nr',
        ('lab', 'gelelectrophoresis'): 'nr',
        ('lab', 'qpcr'): 'nr',
        ('lab', 'library'): 'Lib_id', # Corrected from 'Library_id' to 'Lib_id'
        ('lab', 'sequencing'): 'Seq_id', # Corrected from 'sequencing_id' to 'Seq_id'
        ('lab', 'datasets'): 'dataset_id',
        ('lab', 'bioinformatics'): 'bioinfo_id', # This table inherits, but 'bioinfo_id' is generated as its unique identifier.

        # Schema: Bioinformatics
        ('bioinformatics', 'analysis_pipelines'): 'pipeline_id',
        ('bioinformatics', 'analysis_runs'): 'run_id',
        ('bioinformatics', 'edna_assignments'): 'assignment_id',

        # Schema: Project_Wanderfische
        ('project_wanderfische', 'budget'): 'nr',
        ('project_wanderfische', 'deliverables'): 'nr'
    }
    
    # Attempt to find the primary key in the special_cases dictionary
    pk = special_cases.get((schema_lower, table_lower))
    if pk:
        return pk

    # Default to 'nr' if no specific primary key is found.
    # This covers all tables that use 'nr' as their serial primary key.
    # This default is less reliable for tables not explicitly listed,
    # so it's best to explicitly define all PKs in special_cases.
    return 'nr'

# =================================================================
# API ENDPOINTS
# =================================================================

@app.route('/mymglab/api/login', methods=['POST'])
def login_user():
    """Handles user login authentication."""
    data = request.get_json()

    # --- DEBUGGING: Print received JSON data ---
    print(f"Received login request JSON: {data}")

    person_id = data.get('person_id')
    password = data.get('password')

    # --- DEBUGGING: Print extracted person_id and password ---
    print(f"Extracted person_id: {person_id}, password: {password}")

    # --- DEMO LOGIN (for testing without DB access) ---
    if person_id == 'demo' and password == 'password':
        print("--- Demo login successful ---")
        return jsonify({"success": True, "user": {"person": "Demo User", "person_id": "demo"}}), 200

    # Query for password from the "Reference"."Personal" table
    # IMPORTANT: The column name in your DB schema is "password" (all lowercase).
    query = 'SELECT "Full Name" as person, person_id, password FROM "reference"."personal" WHERE person_id = %s;'
    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute(query, (person_id,))
            user = cur.fetchone()
            
        if user:
            print(f"User found in DB: {user['person_id']}, Hashed Password (from DB): {user.get('password')}")
            # Verify password using bcrypt if user exists and hash is present
            # Ensure 'password' column is used for bcrypt check
            if user.get('password') and bcrypt.checkpw(password.encode('utf-8'), user['password'].encode('utf-8')):
                user.pop('password', None) # Remove hash before sending to frontend for security
                print("--- Database login successful ---")
                return jsonify({"success": True, "user": user}), 200
            else:
                print("--- Password mismatch or no password hash found for user ---")
                return jsonify({"error": "Invalid credentials"}), 401
        else:
            print("--- User not found in database ---")
            return jsonify({"error": "Invalid credentials"}), 401
    except Exception as e:
        print(f"Login error: {e}") # Log the actual error on the server side for debugging
        return jsonify({"error": "An internal server error occurred during login."}), 500
    finally:
        if conn:
            conn.close()

@app.route('/api/global-search/<string:search_term>', methods=['GET'])
def global_search(search_term):
    """Searches across multiple tables for a given term."""
    search_pattern = f"%{search_term}%" # Pattern for ILIKE (case-insensitive LIKE)
    results = {}
    
    # Define search queries for different tables
    queries = {
        "projects": ('SELECT project_id, "Title" FROM "Lims"."projects" WHERE project_id ILIKE %s OR "Title" ILIKE %s LIMIT 5', (search_pattern, search_pattern)),
        "samples": ('SELECT sample_id, sample_type, sample_status_id FROM "Lab"."samples" WHERE sample_id ILIKE %s OR "External_Name" ILIKE %s LIMIT 5', (search_pattern, search_pattern)),
        "experiments": ('SELECT "Experiment_id", "Experiment_title" FROM "Lab"."Experiments" WHERE "Experiment_id" ILIKE %s OR "Experiment_title" ILIKE %s LIMIT 5', (search_pattern, search_pattern)),
        "sops": ('SELECT sop_id, "Title" FROM "Lims"."sop" WHERE sop_id ILIKE %s OR "Title" ILIKE %s LIMIT 5', (search_pattern, search_pattern)),
        "reagents": ('SELECT "Reagents_id", "Reagent_CompleteName" FROM "Lims"."Reagents" WHERE "Reagents_id" ILIKE %s OR "Reagent_CompleteName" ILIKE %s LIMIT 5', (search_pattern, search_pattern)),
        "personal": ('SELECT person_id, "Full Name" FROM "reference"."personal" WHERE person_id ILIKE %s OR "Full Name" ILIKE %s LIMIT 5', (search_pattern, search_pattern)),
    }
    
    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            for key, (query, params) in queries.items():
                cur.execute(query, params)
                results[key] = cur.fetchall()
        return jsonify(results), 200
    except Exception as e:
        print(f"Global search error: {e}")
        return jsonify({"error": "An internal server error occurred during search."}), 500
    finally:
        if conn:
            conn.close()

@app.route('/api/dashboard-stats', methods=['GET'])
def get_dashboard_stats():
    """Fetches key statistics for the dashboard."""
    query = """
    SELECT
        (SELECT COUNT(*) FROM "Lims"."projects" WHERE "status_id" = 'Active') AS active_projects,
        (SELECT COUNT(*) FROM "Lab"."samples") AS total_samples,
        (SELECT COUNT(*) FROM "Lab"."Experiments" WHERE "date" >= date_trunc('month', CURRENT_DATE)) AS experiments_this_month,
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

# --- GENERIC TABLE ENDPOINTS ---

@app.route('/api/table/<string:schema>/<string:table>', methods=['GET'])
def get_table_data(schema, table):
    """
    Generic function to fetch data from a table, with optional filtering.
    Handles binary data (bytea) by Base64 encoding it for JSON serialization.
    """
    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            # Ensure schema and table names match PostgreSQL's case-sensitive identifiers
            base_query = f'SELECT * FROM "{schema.capitalize()}"."{table}"'
            where_clauses = []
            params = []

            # Add generic filtering for any column specified in query parameters
            for key, value in request.args.items():
                if key.startswith('filter_'):
                    col_name = key[len('filter_'):] # Remove 'filter_' prefix
                    # Ensure column name is quoted to handle case-sensitive PostgreSQL identifiers
                    where_clauses.append(f'"{col_name}" ILIKE %s') # Case-insensitive search
                    params.append(f"%{value}%")

            if where_clauses:
                query = f"{base_query} WHERE {' AND '.join(where_clauses)};"
            else:
                query = f"{base_query};"
            
            # Print the executed query and parameters for debugging purposes
            print(f"Executing GET query: {query} with params: {params}")    
            cur.execute(query, params)
            data = cur.fetchall()
            
            # Process data to handle memoryview objects from bytea columns
            # Convert memoryview (binary) to Base64 string for JSON serialization
            processed_data = []
            for row in data:
                new_row = dict(row) # Create a mutable dictionary from the RealDictRow
                for key, value in new_row.items():
                    if isinstance(value, memoryview):
                        # Encode memoryview to bytes, then to base64 string
                        new_row[key] = base64.b64encode(value.tobytes()).decode('utf-8')
                    elif isinstance(value, bytes):
                        # Also handle direct bytes objects if they somehow appear
                        new_row[key] = base64.b64encode(value).decode('utf-8')
                processed_data.append(new_row)
            
            return jsonify(processed_data), 200 # Return the processed data
    except Exception as e:
        print(f"Error fetching table data for {schema}.{table}: {e}")
        return jsonify({"error": str(e)}), 500
    finally:    
        if conn:
            conn.close()
            
@app.route('/api/table/<string:schema>/<string:table>', methods=['POST'])
def create_record(schema, table):
    """Generic function to create a new record in a table."""
    # Determine if the request is JSON (for most data) or multipart (for file uploads)
    if request.is_json:    
        data = request.get_json()
        files = {} # No files in JSON request
    else:    
        data = request.form.to_dict() # Form data for regular fields
        files = request.files # Files for file uploads

    if not data and not files:    
        return jsonify({"error": "No data provided"}), 400
        
    # Handle 'attachment' field for file uploads (assuming bytea type in DB)
    if 'attachment' in files and files['attachment'].filename != '':
        data['attachment'] = psycopg2.Binary(files['attachment'].read())
    elif 'attachment' in data and data['attachment'] == '': # If empty string sent for attachment, treat as null
        data['attachment'] = None # Explicitly set to None for NULL in DB
    elif 'attachment' in data and files and files['attachment'].filename == '': # Case where 'attachment' is in data but an empty file was sent
            data.pop('attachment', None) # Remove it if no actual file was provided


    # Convert empty strings to None for database insertion for all fields
    # This ensures that empty strings from frontend don't violate NOT NULL constraints
    # or get stored as actual empty strings when NULL is intended.
    filtered_data = {k: v if v != '' else None for k, v in data.items()}
    
    columns = filtered_data.keys()
    values = list(filtered_data.values())
    
    # Quote column names to handle case-sensitive PostgreSQL identifiers
    column_names = ', '.join([f'"{col}"' for col in columns])
    value_placeholders = ', '.join(['%s'] * len(values))
    
    query = f'INSERT INTO "{schema.capitalize()}"."{table}" ({column_names}) VALUES ({value_placeholders}) RETURNING *;'
    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            print(f"Executing POST query: {query} with values: {values}") # For debugging
            cur.execute(query, values)
            new_record = cur.fetchone()
            conn.commit() # Commit the transaction
        return jsonify(new_record), 201 # 201 Created status for successful creation
    except Exception as e:    
        if conn:
            conn.rollback() # Rollback on error
        print(f"Error creating record in {schema}.{table}: {e}")
        return jsonify({"error": str(e)}), 500
    finally:    
        if conn:
            conn.close()

@app.route('/api/table/<string:schema>/<string:table>/<string:pk_value>', methods=['PUT'])
def update_record(schema, table, pk_value):
    """Generic function to update an existing record in a table."""
    pk_column = get_pk_column(schema, table) # Get the primary key column name
    data = request.get_json() # Get JSON data from the request body
    if not data:    
        return jsonify({"error": "No data provided"}), 400
        
    set_clauses = []
    values = []
    
    # Iterate through provided data to dynamically build the SET clause
    for key, val in data.items():
        set_clauses.append(f'"{key}" = %s')
        # Convert empty strings to None (NULL in DB) for consistency
        values.append(None if val == '' else val)    
    
    if not set_clauses: # If no fields were provided to update
        return jsonify({"error": "No fields to update"}), 400

    # Add the primary key value to the end of the values list for the WHERE clause
    # Only cast to int if the PK column is 'nr' (serial primary key) as other generated IDs are text.
    try:
        # Explicitly check for common integer PKs, otherwise treat as string
        if pk_column in ['nr', 'ExperimentsProjects_id', 'log_id', 'analysis_runs_serial_seq', 'edna_assignments_serial_seq', 'pipeline_serial_seq']:
            param_pk_value = int(pk_value)
        else:
            param_pk_value = pk_value
        values.append(param_pk_value)
    except ValueError: # If pk_column is an integer type but pk_value isn't a valid integer
        return jsonify({"error": f"Invalid ID format for '{pk_column}': {pk_value}"}), 400
        
    query = f'UPDATE "{schema.capitalize()}"."{table}" SET {", ".join(set_clauses)} WHERE "{pk_column}" = %s RETURNING *;'
    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            print(f"Executing PUT query: {query} with values: {values}") # For debugging
            cur.execute(query, values)
            updated_record = cur.fetchone() # Fetch the updated record
            conn.commit() # Commit the transaction
        if updated_record:
            return jsonify(updated_record), 200 # 200 OK for successful update
        else:
            return jsonify({"error": "Record not found or no changes made."}), 404 # 404 Not Found if record doesn't exist
    except Exception as e:    
        if conn:
            conn.rollback() # Rollback on error
        print(f"Error updating record in {schema}.{table}: {e}")
        return jsonify({"error": str(e)}), 500
    finally:    
        if conn:
            conn.close()

@app.route('/api/table/<string:schema>/<string:table>/<string:pk_value>', methods=['DELETE'])
def delete_record(schema, table, pk_value):
    """Generic function to delete a record from a table."""
    pk_column = get_pk_column(schema, table) # Get the primary key column name
    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor() as cur:
            # Convert PK value to int if the PK column is an integer type
            if pk_column in ['nr', 'ExperimentsProjects_id', 'log_id', 'analysis_runs_serial_seq', 'edna_assignments_serial_seq', 'pipeline_serial_seq']:
                param_value = int(pk_value)
            else:
                param_value = pk_value
            query = f'DELETE FROM "{schema.capitalize()}"."{table}" WHERE "{pk_column}" = %s;'
            print(f"Executing DELETE query: {query} with param: {param_value}") # For debugging
            cur.execute(query, (param_value,))
            conn.commit() # Commit the transaction
            if cur.rowcount == 0:    
                return jsonify({"error": "Record not found"}), 404 # 404 Not Found if record doesn't exist
        return "", 204 # 204 No Content for successful deletion (no body returned)
    except ValueError: # If pk_column is an integer type but pk_value isn't a valid integer
        return jsonify({"error": f"Invalid ID format for '{pk_column}': {pk_value}"}), 400
    except Exception as e:    
        if conn:
            conn.rollback() # Rollback on error
        print(f"Error deleting record in {schema}.{table}: {e}")
        return jsonify({"error": str(e)}), 500
    finally:    
        if conn:
            conn.close()

@app.route('/api/table/<string:schema>/<string:table>/batch_upload', methods=['POST'])
def batch_upload(schema, table):
    """Handles batch insertion of records into a table."""
    records = request.get_json()
    if not records or not isinstance(records, list):    
        return jsonify({"error": "Invalid data format. Expected a list of records."}), 400
    
    if not records: # Handle empty list of records gracefully
        return jsonify({"success": True, "inserted_rows": 0}), 200

    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor() as cur:
            # Assume all records in the batch have the same keys/columns
            columns = [col for col in records[0].keys()]
            column_names = ', '.join([f'"{col}"' for col in columns])
            
            # Convert empty strings to None (NULL) for database insertion
            data_tuples = []
            for record in records:
                row = []
                for col in columns:
                    val = record.get(col)
                    # Handle 'attachment' field for binary data if present in batch
                    if col == 'attachment' and val is not None:
                        try:
                            # Assume base64 encoded string is sent for attachment in batch
                            row.append(psycopg2.Binary(base64.b64decode(val)))
                        except Exception as decode_error:
                            print(f"Warning: Could not decode base64 for attachment in batch. Error: {decode_error}")
                            row.append(None) # Treat as null if decoding fails
                    else:
                        row.append(None if val == '' else val) # Convert empty string to None
                data_tuples.append(tuple(row))

            query_template = f"INSERT INTO \"{schema.capitalize()}\".\"{table}\" ({column_names}) VALUES %s"
            
            print(f"Executing batch_upload query: {query_template} with {len(data_tuples)} records.") # For debugging
            psycopg2.extras.execute_values(cur, query_template, data_tuples) # Efficient batch insert
            conn.commit() # Commit the transaction
        return jsonify({"success": True, "inserted_rows": len(records)}), 201 # 201 Created for batch insert
    except Exception as e:
        if conn:    
            conn.rollback() # Rollback on error
        print(f"Error during batch upload for {schema}.{table}: {e}")
        return jsonify({"success": False, "error": str(e)}), 500
    finally:
        if conn:    
            conn.close()

# =================================================================
# STATIC FILE SERVING & ROOT
# =================================================================
@app.route('/')
def root():    
    # Redirect the root URL to the login page
    return redirect(url_for('serve_static', filename='login.html'))

@app.route('/<path:filename>')
def serve_static(filename):
    # Serve static files (HTML, CSS, JS, images) from the configured STATIC_FOLDER
    return send_from_directory(app.static_folder, filename)

# =================================================================
# RUN THE SERVER
# =================================================================
if __name__ == '__main__':
    host = '0.0.0.0' # Listen on all available network interfaces
    port = 5200 # Port for the server

    print("="*60 + f"\n TIFI LIMS Backend Server ".center(60, "=") + "\n" + "="*60)
    print(f" -> Serving LIMS frontend from: {os.path.abspath(STATIC_FOLDER)}")
    print(f" -> API listening on http://{host}:{port}/api/")
    print(f" -> Access the UI at http://127.0.0.1:{port}")
    print("="*60)

    # Use app.run() for development with debugging, waitress for production deployment
    if FLASK_ENV == "development":
        app.run(host=host, port=port, debug=True)
    else:
        # Waitress is a production-ready WSGI server
        serve(app, host=host, port=port)
