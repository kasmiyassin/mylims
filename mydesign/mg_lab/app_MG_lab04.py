import os
import psycopg2
import psycopg2.extras
import bcrypt
from flask import Flask, jsonify, request, send_from_directory, redirect, url_for
from flask_cors import CORS
from waitress import serve # For production-ready server

# Database connection details
# IMPORTANT: For production, use environment variables for sensitive data like passwords.
DB_HOST = os.getenv('DB_HOST', '0.0.0.0') # Use 'localhost' if running DB on same machine and not accessing from other containers
DB_NAME = os.getenv('DB_NAME', 'MG_lab')
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
        ('reference', 'genes'): 'primer_id',
        ('reference', 'location'): 'place', # 'place' is UNIQUE NOT NULL
        ('reference', 'samplestype'): 'sample_type',
        ('reference', 'species'): 'Species', # Case-sensitive column name
        ('reference', 'category'): 'category',
        ('reference', 'personal'): 'person_id',

        # Schema: Lims
        ('lims', 'projects'): 'project_id',
        # 'ProjectPersons' has a composite PK (project_id, person_id).
        # Generic PUT/DELETE by a single PK value won't work directly for composite keys.
        # If operations on ProjectPersons require both keys, a custom endpoint is needed.
        # For now, it will default to 'nr' if accessed generically, which is likely incorrect.
        # ('lims', 'projectpersons'): ('project_id', 'person_id'), # Composite PK - handled by custom routes if needed
        ('lims', 'equipment'): 'equipment_id',
        ('lims', 'sop'): 'sop_id',
        ('lims', 'orders'): 'FI_Order_Nr', # 'FI_Order_Nr' is UNIQUE, suitable as a single PK for API
        ('lims', 'reagents'): 'Reagent_Name', # 'Reagent_Name' is UNIQUE NOT NULL

        # Schema: Lab
        ('lab', 'storage'): 'storage_id',
        ('lab', 'sampling'): 'Sampling_id',
        ('lab', 'experiments'): 'Experiment_Nr',
        ('lab', 'samples'): 'sample_id', # Critical: 'sample_id' is the PK, not 'nr'
        # 'ExperimentSamples' has a composite PK (Experiment_Nr, sample_id).
        # Similar to ProjectPersons, generic PUT/DELETE won't work directly.
        # ('lab', 'experimentsamples'): ('Experiment_Nr', 'sample_id'), # Composite PK - handled by custom routes if needed
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
        ('lab', 'library'): 'Library_id', # 'Library_id' is UNIQUE NOT NULL
        ('lab', 'sequencing'): 'sequencing_id', # 'sequencing_id' is UNIQUE NOT NULL
        ('lab', 'bioinformatics'): 'bioinfo_id', # 'bioinfo_id' is a serial PRIMARY KEY
        ('lab', 'protocols'): 'nr', # Explicitly define 'nr' as PK for Protocols

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
    return 'nr'

# =================================================================
# API ENDPOINTS
# =================================================================

@app.route('/api/login', methods=['POST'])
def login_user():
    """Handles user login authentication."""
    data = request.get_json()
    person_id = data.get('person_id')
    password = data.get('password')

    # Simple demo login for testing without actual DB access
    if person_id == 'demo' and password == 'password':
        return jsonify({"success": True, "user": {"person": "Demo User", "person_id": "demo"}}), 200

    query = 'SELECT person, person_id, password_hash FROM "Reference"."Personal" WHERE person_id = %s;'
    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute(query, (person_id,))
            user = cur.fetchone()
        
        # Verify password using bcrypt if user exists and hash is present
        if user and user.get('password_hash') and bcrypt.checkpw(password.encode('utf-8'), user['password_hash'].encode('utf-8')):
            user.pop('password_hash', None) # Remove hash before sending to frontend for security
            return jsonify({"success": True, "user": user}), 200
        else:
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
        "projects": ('SELECT project_id, "Title" FROM "Lims"."Projects" WHERE project_id ILIKE %s OR "Title" ILIKE %s LIMIT 5', (search_pattern, search_pattern)),
        "samples": ('SELECT sample_id, sample_type, workflow_status_id FROM "Lab"."Samples" WHERE sample_id ILIKE %s LIMIT 5', (search_pattern,)),
        "experiments": ('SELECT "Experiment_Nr", "Experiment_title" FROM "Lab"."Experiments" WHERE "Experiment_Nr" ILIKE %s OR "Experiment_title" ILIKE %s LIMIT 5', (search_pattern, search_pattern)),
        # You could add protocols here too if you want to search by content or Exp_Nr
        # "protocols": ('SELECT nr, "Experiments_Nr", protocol FROM "Lab"."protocols" WHERE "Experiments_Nr" ILIKE %s OR protocol ILIKE %s LIMIT 5', (search_pattern, search_pattern)),
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

# --- GENERIC TABLE ENDPOINTS ---

@app.route('/api/table/<string:schema>/<string:table>', methods=['GET'])
def get_table_data(schema, table):
    """
    Generic function to fetch data from a table, with optional filtering.
    Specifically handles 'Lab.protocols' for 'filter_Experiments_Nr' query parameter.
    """
    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            base_query = f'SELECT * FROM "{schema.capitalize()}"."{table}"'
            where_clauses = []
            params = []

            # Specific handling for Lab.protocols filter by Experiments_Nr
            if schema.capitalize() == 'Lab' and table == 'protocols':
                experiment_nr_filter = request.args.get('filter_Experiments_Nr')
                if experiment_nr_filter:
                    where_clauses.append('"Experiments_Nr" = %s')
                    params.append(experiment_nr_filter)
            
            # You can extend this for other generic filters if needed across tables
            # For example, to allow filtering by any column:
            # for key, value in request.args.items():
            #   if key.startswith('filter_'):
            #       col_name = key[len('filter_'):] # Remove 'filter_' prefix
            #       where_clauses.append(f'"{col_name}" ILIKE %s') # Case-insensitive search
            #       params.append(f"%{value}%")

            if where_clauses:
                query = f"{base_query} WHERE {' AND '.join(where_clauses)};"
            else:
                query = f"{base_query};"
            
            # Print the executed query and parameters for debugging purposes
            print(f"Executing GET query: {query} with params: {params}") 
            cur.execute(query, params)
            data = cur.fetchall()
            
            # Handle binary data (bytea) before sending as JSON
            # PostgreSQL's psycopg2 returns bytea as memoryview objects.
            for row in data:
                # Check for 'attachment' and 'Attachment' keys as per your schema
                if 'attachment' in row and isinstance(row['attachment'], memoryview):
                    row['attachment'] = f"<Attached File: {len(row['attachment'])} bytes>"
                if 'Attachment' in row and isinstance(row['Attachment'], memoryview):
                    row['Attachment'] = f"<Attached File: {len(row['Attachment'])} bytes>"
            return jsonify(data), 200
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
    elif 'attachment' in data and not files: # If attachment key is present but no file and not empty string, keep it (e.g. if string representation of file was sent)
        pass # Keep as is, might be a placeholder or string data
    elif 'attachment' in data and files and files['attachment'].filename == '': # Case where 'attachment' is in data but an empty file was sent
         del data['attachment'] # Remove it if no actual file was provided

    # Convert empty strings to None for database insertion for all fields
    # This ensures that empty strings from frontend don't violate NOT NULL constraints
    # or get stored as actual empty strings when NULL is intended.
    filtered_data = {k: v if v != '' else None for k, v in data.items()}
    
    columns = filtered_data.keys()
    values = list(filtered_data.values())
    
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
    # Convert PK value to int if the PK column is 'nr' (serial primary key)
    try:
        values.append(int(pk_value) if pk_column == 'nr' or pk_column == 'bioinfo_id' else pk_value)
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
            param_value = int(pk_value) if pk_column == 'nr' or pk_column == 'bioinfo_id' else pk_value
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
