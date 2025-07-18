import os
import psycopg2
import psycopg2.extras
import bcrypt
from flask import Flask, jsonify, request, send_from_directory, redirect, url_for, g # Import g for app context
from flask_cors import CORS
from waitress import serve # For production-ready server
import base64 # Added this import for Base64 encoding
import json # For handling JSONB fields

# Database connection details
# IMPORTANT: For production, use environment variables for sensitive data like passwords.
DB_HOST = os.getenv('DB_HOST', 'localhost') # Use 'localhost' if running DB on same machine and not accessing from other containers
DB_NAME = os.getenv('DB_NAME', 'MyLims') # Changed to MyLims as per user request
DB_USER = os.getenv('DB_USER', 'kasmi')
DB_PASS = os.getenv('DB_PASS', 'password') # Replace with your actual password or env var

# Static folder for serving frontend files (current directory where app.py is run)
STATIC_FOLDER = '.'
app = Flask(__name__, static_folder=STATIC_FOLDER)

# IMPORTANT: Set FLASK_ENV to "development" for debugging, "production" for deployment.
FLASK_ENV = os.getenv('FLASK_ENV', 'production') # Default to production

CORS(app) # Enable CORS for all routes (essential for frontend-backend communication)

def get_db_connection():
    """
    Establishes a connection to the PostgreSQL database.
    Uses Flask's `g` object to store the connection for the current request
    to ensure it's reused and properly closed.
    """
    if 'db_conn' not in g:
        try:
            conn = psycopg2.connect(host=DB_HOST, database=DB_NAME, user=DB_USER, password=DB_PASS)
            g.db_conn = conn
        except psycopg2.OperationalError as e:
            print(f"FATAL: Could not connect to database at {DB_HOST}. Error: {e}")
            raise # Re-raise to stop server if DB connection fails on startup
    return g.db_conn

@app.teardown_appcontext
def close_db_connection(exception):
    """
    Closes the database connection at the end of the request.
    """
    conn = g.pop('db_conn', None)
    if conn is not None:
        conn.close()

def get_pk_column(schema, table):
    """
    Determines the primary key column(s) for a given table based on schema and table name.
    Returns a string for single PKs, or a tuple of strings for composite PKs.
    This mapping is crucial for the generic PUT and DELETE endpoints to work correctly.
    """
    # Normalize schema and table names to lowercase for robust matching
    schema_lower = schema.lower()
    table_lower = table.lower()

    # Comprehensive mapping of primary keys from MyLims.sql
    pk_map = {
        # Schema: Reference
        ('reference', 'personal'): 'person_id',
        ('reference', 'status'): 'status_id',
        ('reference', 'room'): 'room_id',
        ('reference', 'vessel'): 'vessel_id',
        ('reference', 'region'): 'region_id',
        ('reference', 'ecosystem'): 'ecosystem_id',
        ('reference', 'category'): 'category_id', # Corrected from 'category' to 'category_id'
        ('reference', 'samples_type'): 'sample_type_id', # Corrected from 'sample_type' to 'sample_type_id'
        ('reference', 'gene'): 'gene_id',
        ('reference', 'taxon'): 'taxon_id',
        ('reference', 'species'): 'species_id',
        ('reference', 'units'): 'unit_id',
        ('lims', 'external_contacts'): 'contact_id', # New table
        ('lims', 'publication_type'): 'publication_type_id', # New table

        # Schema: Lims
        ('lims', 'customers'): 'customer_id',
        ('lims', 'projects'): 'project_id',
        ('lims', 'project_persons'): ('project_id', 'person_id'), # Composite PK
        ('lims', 'cruises'): 'cruise_id',
        ('lims', 'workflows'): 'workflow_id',
        ('lims', 'permits'): 'permit_id',
        ('lims', 'primers'): 'primer_id',
        ('lims', 'sop'): 'sop_id',
        ('lims', 'workflow_steps'): 'step_id',
        ('lims', 'equipment'): 'equipment_id',
        ('lims', 'suppliers'): 'supplier_id', # New table
        ('lims', 'inventory_items'): 'item_id', # New table
        ('lims', 'orders'): 'fi_order_nr',
        ('lims', 'reagents'): 'reagent_id', # Corrected from 'Reagents_id' to 'reagent_id'
        ('lims', 'publications'): 'publication_id', # New table

        # Schema: Lab
        ('lab', 'storage'): 'storage_id',
        ('lab', 'experiments'): 'experiment_id',
        ('lab', 'experiments_projects'): 'experiment_project_id', # Serial PK
        ('lab', 'protocol_runs'): 'protocol_run_id', # New table
        ('lab', 'sampling'): ('sampling_id', 'sampling_date'), # Composite PK (partitioned)
        ('lab', 'fishing'): 'fishing_id',
        ('lab', 'samples'): ('sample_id', 'sampling_date'), # Composite PK (partitioned)
        ('lab', 'storage_log'): 'log_id', # Serial PK
        ('lab', 'fish'): 'sample_id',
        ('lab', 'tissue'): 'sample_id',
        ('lab', 'otoliths'): 'otolith_id', # New table
        ('lab', 'dna'): 'sample_id',
        ('lab', 'rna'): 'sample_id',
        ('lab', 'sediments'): 'sample_id',
        ('lab', 'water'): 'sample_id',
        ('lab', 'experiments_samples'): ('experiment_id', 'sample_id'), # Composite PK
        ('lab', 'dissections'): 'dissection_id',
        ('lab', 'extraction'): 'extraction_id',
        ('lab', 'nanodrop'): 'nanodrop_id',
        ('lab', 'qubit'): 'qubit_id',
        ('lab', 'tapestation'): 'tapestation_id',
        ('lab', 'pcr'): 'pcr_id',
        ('lab', 'gelelectrophoresis'): 'gelelectrophoresis_id',
        ('lab', 'qpcr'): 'qpcr_id',
        ('lab', 'library'): 'library_id',
        ('lab', 'sequencing'): 'sequencing_id',
        ('lab', 'datasets'): 'dataset_id',

        # Schema: Bioinformatics
        ('bioinformatics', 'reference_databases'): 'db_id', # New table
        ('bioinformatics', 'analysis_pipelines'): 'pipeline_id', # New table
        ('bioinformatics', 'analysis_runs'): 'run_id', # New table
        ('bioinformatics', 'edna_assignments'): 'assignment_id', # New table
    }
    
    pk = pk_map.get((schema_lower, table_lower))
    if pk:
        return pk

    # Fallback for views or tables not explicitly listed, try common PK names
    # This is less reliable and should be avoided for critical tables.
    # For views, there is no "PK" in the traditional sense, so fetching by PK won't work.
    # Frontend should not attempt PUT/DELETE on views.
    print(f"WARNING: No explicit PK mapping for {schema}.{table}. Attempting common PKs.")
    conn = get_db_connection()
    with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
        try:
            # Query PostgreSQL's information schema to find actual primary key columns
            cur.execute(f"""
                SELECT a.attname
                FROM pg_index i
                JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY(i.indkey)
                WHERE i.indrelid = '"{schema}"."{table}"'::regclass AND i.indisprimary;
            """)
            pk_cols = [row['attname'] for row in cur.fetchall()]
            if len(pk_cols) == 1:
                return pk_cols[0]
            elif len(pk_cols) > 1:
                return tuple(pk_cols)
        except Exception as e:
            print(f"Error querying PK from information_schema for {schema}.{table}: {e}")

    # Final fallback if no PK is found via mapping or information_schema
    return 'id' # Default to 'id' or 'nr' if no other PK is found (less reliable)


def get_table_column_info(schema, table):
    """
    Retrieves column information (name, type, is_nullable) for a given table.
    Used for dynamic form generation and validation.
    """
    conn = get_db_connection()
    with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
        cur.execute(f"""
            SELECT column_name, data_type, is_nullable
            FROM information_schema.columns
            WHERE table_schema = %s AND table_name = %s
            ORDER BY ordinal_position;
        """, (schema, table))
        return cur.fetchall()

# =================================================================
# API ENDPOINTS
# All routes are prefixed with '/mymglab/api/'
# =================================================================

@app.route('/mymglab/api/login', methods=['POST'])
def login_user():
    """Handles user login authentication."""
    data = request.get_json()
    person_id = data.get('person_id')
    password = data.get('password')

    if not person_id or not password:
        return jsonify({"error": "Missing person ID or password"}), 400

    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            # Query for password_hash from the "reference"."personal" table
            # Column name is "password_hash" as per MyLims.sql
            query = 'SELECT "full_name" AS person, "person_id", "password_hash" FROM "reference"."personal" WHERE "person_id" = %s;'
            cur.execute(query, (person_id,))
            user = cur.fetchone()
            
        if user:
            # Verify password using bcrypt
            # Ensure the stored hash is not None and is a valid bcrypt hash
            if user.get('password_hash') and bcrypt.checkpw(password.encode('utf-8'), user['password_hash'].encode('utf-8')):
                user.pop('password_hash', None) # Remove hash before sending to frontend for security
                return jsonify({"success": True, "user": user}), 200
            else:
                return jsonify({"error": "Invalid credentials"}), 401
        else:
            return jsonify({"error": "Invalid credentials"}), 401
    except Exception as e:
        print(f"Login error: {e}")
        return jsonify({"error": "An internal server error occurred during login."}), 500
    finally:
        if conn:
            conn.close()

@app.route('/mymglab/api/register_user', methods=['POST'])
def register_user():
    """Registers a new user in the reference.personal table."""
    data = request.get_json()
    person_id = data.get('person_id')
    full_name = data.get('full_name')
    password = data.get('password')

    if not person_id or not full_name or not password:
        return jsonify({"error": "Missing person ID, full name, or password"}), 400

    hashed_password = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')

    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            # Check if user already exists
            cur.execute('SELECT person_id FROM "reference"."personal" WHERE person_id = %s;', (person_id,))
            if cur.fetchone():
                return jsonify({"error": "User with this ID already exists"}), 409 # 409 Conflict

            query = 'INSERT INTO "reference"."personal" ("person_id", "full_name", "password_hash") VALUES (%s, %s, %s) RETURNING *;'
            cur.execute(query, (person_id, full_name, hashed_password))
            new_user = cur.fetchone()
            conn.commit()
            new_user.pop('password_hash', None)
            return jsonify(new_user), 201
    except Exception as e:
        if conn:
            conn.rollback()
        print(f"Registration error: {e}")
        return jsonify({"error": str(e)}), 500
    finally:
        if conn:
            conn.close()

@app.route('/mymglab/api/update_password', methods=['PUT'])
def update_password():
    """Updates a user's password."""
    data = request.get_json()
    person_id = data.get('person_id')
    new_password = data.get('new_password')

    if not person_id or not new_password:
        return jsonify({"error": "Missing person ID or new password"}), 400

    hashed_password = bcrypt.hashpw(new_password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')

    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor() as cur:
            query = 'UPDATE "reference"."personal" SET "password_hash" = %s WHERE "person_id" = %s;'
            cur.execute(query, (hashed_password, person_id))
            conn.commit()
            if cur.rowcount == 0:
                return jsonify({"error": "User not found"}), 404
            return jsonify({"success": True, "message": "Password updated successfully"}), 200
    except Exception as e:
        if conn:
            conn.rollback()
        print(f"Password update error: {e}")
        return jsonify({"error": str(e)}), 500
    finally:
        if conn:
            conn.close()

@app.route('/mymglab/api/global-search/<string:search_term>', methods=['GET'])
def global_search(search_term):
    """Searches across multiple tables for a given term using full-text search."""
    # Use plainto_tsquery for basic search, or to_tsquery for more advanced (AND, OR)
    # Search term needs to be escaped for tsquery if it contains special characters,
    # but plainto_tsquery handles most user inputs safely.
    ts_query = f"plainto_tsquery('public.lims_english', %s)"
    
    results = {}
    
    # Define search queries for different tables using their tsvector columns
    queries = {
        "projects": ('SELECT project_id, title FROM "lims"."projects" WHERE project_search_vector @@ ' + ts_query + ' LIMIT 5',),
        "samples": ('SELECT sample_id, sample_type_id AS sample_type, sample_status_id FROM "lab"."samples" WHERE sample_search_vector @@ ' + ts_query + ' LIMIT 5',),
        "experiments": ('SELECT experiment_id, experiment_title FROM "lab"."experiments" WHERE experiment_search_vector @@ ' + ts_query + ' LIMIT 5',),
        "sops": ('SELECT sop_id, title FROM "lims"."sop" WHERE sop_search_vector @@ ' + ts_query + ' LIMIT 5',),
        "reagents": ('SELECT reagent_id, reagent_complete_name FROM "lims"."reagents" WHERE reagent_search_vector @@ ' + ts_query + ' LIMIT 5',), # Assuming reagent_search_vector exists
        "personal": ('SELECT person_id, full_name AS "Full Name" FROM "reference"."personal" WHERE personal_search_vector @@ ' + ts_query + ' LIMIT 5',), # Assuming personal_search_vector exists
    }
    
    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            for key, (query_template,) in queries.items():
                try:
                    cur.execute(query_template, (search_term,))
                    results[key] = cur.fetchall()
                except psycopg2.errors.UndefinedColumn as e:
                    print(f"WARNING: Skipping search for {key} due to missing tsvector column: {e}")
                    results[key] = [] # Return empty list if column is missing
        return jsonify(results), 200
    except Exception as e:
        print(f"Global search error: {e}")
        return jsonify({"error": "An internal server error occurred during search."}), 500
    finally:
        if conn:
            conn.close()

@app.route('/mymglab/api/dashboard-stats', methods=['GET'])
def get_dashboard_stats():
    """Fetches key statistics for the dashboard."""
    query = """
    SELECT
        (SELECT COUNT(*) FROM "lims"."projects" WHERE "status_id" = 'Active') AS active_projects,
        (SELECT COUNT(*) FROM "lab"."samples") AS total_samples,
        (SELECT COUNT(*) FROM "lab"."experiments" WHERE "experiment_date" >= date_trunc('month', CURRENT_DATE)) AS experiments_this_month,
        (SELECT COUNT(*) FROM "lims"."reagents" WHERE "expire_date" BETWEEN CURRENT_DATE AND CURRENT_DATE + interval '30 day') AS reagents_expiring_soon;
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

@app.route('/mymglab/api/table/<string:schema>/<string:table>', methods=['GET'])
def get_table_data(schema, table):
    """
    Generic function to fetch data from a table or view, with optional filtering.
    Handles binary data (bytea) by Base64 encoding it for JSON serialization.
    """
    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            # Ensure schema and table names match PostgreSQL's case-sensitive identifiers
            # Convert to lowercase for schema/table names as they are usually lowercase in SQL
            # But actual column names in the DB might be camelCase or PascalCase, so keep them as is.
            db_schema_name = schema.lower()
            db_table_name = table.lower() # Use lower() for table name to match SQL
            
            # Special handling for views which might have PascalCase names in the SQL schema
            if table == 'Sample_Full_Details_View':
                db_table_name = 'sample_full_details_view'
            elif table == 'Project_Comprehensive_Summary_View':
                db_table_name = 'project_comprehensive_summary_view'
            elif table == 'Storage_Occupancy_View':
                db_table_name = 'storage_occupancy_view'
            elif table == 'Reagent_Status_View':
                db_table_name = 'reagent_status_view'
            elif table == 'Experiment_Progress_Overview_View':
                db_table_name = 'experiment_progress_overview_view'
            elif table == 'Complete_Species_Taxon_View':
                db_table_name = 'complete_species_taxon_view'
            elif table == 'Taxon_Hierarchy_View':
                db_table_name = 'taxon_hierarchy_view'
            elif table == 'analysis_results_summary': # For bioinformatics schema
                db_table_name = 'analysis_results_summary'
            elif table == 'Samples_tracking': # Old view name, map to new Lab.samples directly or a new view
                db_table_name = 'samples' # Direct to lab.samples for now, or create a specific view if needed
                db_schema_name = 'lab'
            
            base_query = f'SELECT * FROM "{db_schema_name}"."{db_table_name}"'
            where_clauses = []
            params = []

            # Add generic filtering for any column specified in query parameters
            for key, value in request.args.items():
                if key.startswith('filter_'):
                    col_name = key[len('filter_'):] # Remove 'filter_' prefix
                    # For exact match filtering (e.g., for FKs), use = instead of ILIKE
                    if key.endswith('_id') or key.endswith('_Nr') or key == 'sample_type': # Add more exact match fields as needed
                        where_clauses.append(f'"{col_name}" = %s')
                        params.append(value)
                    else:
                        where_clauses.append(f'"{col_name}" ILIKE %s') # Case-insensitive search for text
                        params.append(f"%{value}%")
                elif key == 'limit': # Handle limit parameter
                    pass # Handled separately below
                elif key == 'order': # Handle order parameter
                    pass # Handled separately below
                else:
                    # Allow direct column filtering with exact match if not prefixed
                    where_clauses.append(f'"{key}" = %s')
                    params.append(value)

            query_parts = []
            if where_clauses:
                query_parts.append(f"WHERE {' AND '.join(where_clauses)}")
            
            # Add ordering
            order_by = request.args.get('order_by')
            order_direction = request.args.get('order_direction', 'asc')
            if order_by:
                query_parts.append(f'ORDER BY "{order_by}" {order_direction.upper()}')

            # Add limit
            limit = request.args.get('limit')
            if limit and limit.isdigit():
                query_parts.append(f'LIMIT {limit}')

            query = f"{base_query} {' '.join(query_parts)};"
            
            # Print the executed query and parameters for debugging purposes
            print(f"Executing GET query: {query} with params: {params}")    
            cur.execute(query, params)
            data = cur.fetchall()
            
            # Process data to handle memoryview objects from bytea columns and jsonb
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
                    elif isinstance(value, dict) or isinstance(value, list):
                        # Handle jsonb fields that are already parsed by RealDictCursor
                        # Ensure they are valid JSON strings if needed for frontend consumption
                        new_row[key] = value # RealDictCursor usually handles jsonb directly
                processed_data.append(new_row)
            
            return jsonify(processed_data), 200 # Return the processed data
    except psycopg2.errors.UndefinedTable as e:
        print(f"Error: Table or view '{db_schema_name}.{db_table_name}' does not exist. {e}")
        return jsonify({"error": f"Table or view '{schema}.{table}' does not exist."}), 404
    except Exception as e:
        print(f"Error fetching table data for {schema}.{table}: {e}")
        return jsonify({"error": str(e)}), 500
    finally:    
        if conn:
            conn.close()
            
@app.route('/mymglab/api/table/<string:schema>/<string:table>', methods=['POST'])
def create_record(schema, table):
    """Generic function to create a new record in a table."""
    conn = None
    try:
        conn = get_db_connection()
        
        # Determine if the request is JSON (for most data) or multipart (for file uploads)
        if request.is_json:    
            data = request.get_json()
        else:    
            data = request.form.to_dict() # Form data for regular fields
            # Handle files from multipart form
            for key, file_storage in request.files.items():
                if file_storage and file_storage.filename != '':
                    data[key] = psycopg2.Binary(file_storage.read())
                else:
                    data[key] = None # Explicitly set to None if file input was empty

        if not data:    
            return jsonify({"error": "No data provided"}), 400
            
        # Convert empty strings to None for database insertion for all fields
        # This ensures that empty strings from frontend don't violate NOT NULL constraints
        # or get stored as actual empty strings when NULL is intended.
        # Also handle JSONB fields: if they are strings, attempt to parse them.
        processed_data = {}
        for k, v in data.items():
            if v == '':
                processed_data[k] = None
            elif k.endswith('_jsonb') and isinstance(v, str):
                try:
                    processed_data[k] = json.loads(v)
                except json.JSONDecodeError:
                    return jsonify({"error": f"Invalid JSON format for field '{k}'"}), 400
            else:
                processed_data[k] = v

        columns = processed_data.keys()
        values = list(processed_data.values())
        
        # Quote column names to handle case-sensitive PostgreSQL identifiers
        column_names = ', '.join([f'"{col}"' for col in columns])
        value_placeholders = ', '.join(['%s'] * len(values))
        
        query = f'INSERT INTO "{schema.lower()}"."{table.lower()}" ({column_names}) VALUES ({value_placeholders}) RETURNING *;'
        
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            print(f"Executing POST query: {query} with values: {values}") # For debugging
            cur.execute(query, values)
            new_record = cur.fetchone()
            conn.commit() # Commit the transaction
        return jsonify(new_record), 201 # 201 Created status for successful creation
    except psycopg2.errors.UniqueViolation as e:
        if conn:
            conn.rollback()
        print(f"Unique violation error creating record in {schema}.{table}: {e}")
        return jsonify({"error": f"A record with this unique identifier already exists. Details: {e.diag.message_detail}"}), 409
    except psycopg2.errors.ForeignKeyViolation as e:
        if conn:
            conn.rollback()
        print(f"Foreign key violation error creating record in {schema}.{table}: {e}")
        return jsonify({"error": f"Referenced record not found (foreign key violation). Details: {e.diag.message_detail}"}), 400
    except Exception as e:    
        if conn:
            conn.rollback() # Rollback on error
        print(f"Error creating record in {schema}.{table}: {e}")
        return jsonify({"error": str(e)}), 500
    finally:    
        if conn:
            conn.close()

@app.route('/mymglab/api/table/<string:schema>/<string:table>/<pk_value>', methods=['PUT'])
def update_record(schema, table, pk_value):
    """
    Generic function to update an existing record in a table.
    Handles single or composite primary keys, including partitioned tables.
    For partitioned tables (lab.samples, lab.sampling), `sampling_date` MUST be in the request body.
    """
    pk_columns = get_pk_column(schema, table) # Get the primary key column name(s)
    data = request.get_json() # Get JSON data from the request body
    if not data:    
        return jsonify({"error": "No data provided"}), 400
        
    set_clauses = []
    values = []
    
    # Iterate through provided data to dynamically build the SET clause
    for key, val in data.items():
        # Skip PK columns if they are part of the composite key and not meant for update
        if (isinstance(pk_columns, tuple) and key in pk_columns) or (isinstance(pk_columns, str) and key == pk_columns):
            continue # PKs are in WHERE clause, not SET clause
        
        set_clauses.append(f'"{key}" = %s')
        # Convert empty strings to None (NULL in DB) for consistency
        # Handle JSONB fields: if they are strings, attempt to parse them.
        if val == '':
            values.append(None)
        elif key.endswith('_jsonb') and isinstance(val, str):
            try:
                values.append(json.loads(val))
            except json.JSONDecodeError:
                return jsonify({"error": f"Invalid JSON format for field '{key}'"}), 400
        else:
            values.append(val)
    
    if not set_clauses: # If no fields were provided to update
        return jsonify({"error": "No fields to update"}), 400

    where_clauses = []
    pk_values_for_query = []

    if isinstance(pk_columns, tuple): # Composite primary key
        # For partitioned tables, the partition key (sampling_date) must be provided in the body
        if (schema.lower(), table.lower()) in [('lab', 'sampling'), ('lab', 'samples')]:
            sampling_date = data.get('sampling_date')
            if not sampling_date:
                return jsonify({"error": f"Missing 'sampling_date' in request body for partitioned table '{table}' update."}), 400
            
            # Ensure the primary key value from URL is for the main PK column (e.g., sample_id, sampling_id)
            main_pk_column = pk_columns[0] # Assume first element of tuple is the main ID
            where_clauses.append(f'"{main_pk_column}" = %s')
            pk_values_for_query.append(pk_value)
            
            # Add the partition key to the WHERE clause
            where_clauses.append(f'"{pk_columns[1]}" = %s') # pk_columns[1] is 'sampling_date'
            pk_values_for_query.append(sampling_date)

        else: # Other composite PKs (e.g., project_persons, experiments_samples)
            # For other composite PKs, the frontend must send all PK components in the body
            # and the URL pk_value might be a concatenation or not used directly.
            # For simplicity, we'll expect all PK components to be in the `data` payload
            # and `pk_value` will be ignored or used as a primary identifier.
            # This needs careful frontend design for composite PKs.
            # For now, if it's a composite PK and not partitioned, we expect all parts in `data`.
            for col in pk_columns:
                if col not in data:
                    return jsonify({"error": f"Missing primary key component '{col}' in request body for composite PK update."}), 400
                where_clauses.append(f'"{col}" = %s')
                pk_values_for_query.append(data[col])
            
            # If the URL pk_value is meant to be one of the composite parts, handle it.
            # Otherwise, it's redundant.
            # Example: if pk_value is 'project_id' and 'person_id' is in data.
            # For simplicity, if it's a composite, we rely on the body.
            # The `pk_value` in the URL becomes less meaningful for composite keys.
            # A more robust solution would be to pass composite keys as URL params or a custom route.
            print(f"WARNING: Updating composite PK table '{table}' using URL pk_value '{pk_value}'. Relying on body for all PK components for WHERE clause.")
            # We've already added components from data, so just ensure URL pk_value is handled if it's one of them
            # For now, just ensure the main PK from the URL is also checked if it's part of the composite
            if pk_columns[0] in data and str(data[pk_columns[0]]) != str(pk_value):
                # This indicates a mismatch, handle as error or warning
                print(f"WARNING: URL PK '{pk_value}' does not match body PK '{data[pk_columns[0]]}' for composite key update. Using body's PK.")

    else: # Single primary key
        where_clauses.append(f'"{pk_columns}" = %s')
        # Convert PK value to int if the PK column is an integer type (serial)
        # This mapping should be consistent with get_pk_column
        if schema.lower() == 'lab' and table.lower() in ['experiments_projects', 'storage_log', 'nanodrop', 'qubit', 'tapestation', 'pcr', 'gelelectrophoresis', 'qpcr', 'library', 'sequencing', 'extraction', 'dissections', 'fishing'] and pk_columns == 'nr':
             # These tables use 'nr' as a serial PK and need int casting if 'nr' is the PK name
             try:
                 pk_values_for_query.append(int(pk_value))
             except ValueError:
                 return jsonify({"error": f"Invalid ID format for '{pk_columns}': {pk_value}. Expected integer."}), 400
        elif schema.lower() == 'lims' and table.lower() in ['customers', 'orders'] and pk_columns == 'customer_id':
            try:
                 pk_values_for_query.append(int(pk_value))
            except ValueError:
                 return jsonify({"error": f"Invalid ID format for '{pk_columns}': {pk_value}. Expected integer."}), 400
        else:
            pk_values_for_query.append(pk_value)
    
    # Combine values for SET clause and WHERE clause
    final_values = values + pk_values_for_query
        
    query = f'UPDATE "{schema.lower()}"."{table.lower()}" SET {", ".join(set_clauses)} WHERE {" AND ".join(where_clauses)} RETURNING *;'
    
    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            print(f"Executing PUT query: {query} with values: {final_values}") # For debugging
            cur.execute(query, final_values)
            updated_record = cur.fetchone() # Fetch the updated record
            conn.commit() # Commit the transaction
        if updated_record:
            return jsonify(updated_record), 200 # 200 OK for successful update
        else:
            return jsonify({"error": "Record not found or no changes made."}), 404 # 404 Not Found if record doesn't exist
    except psycopg2.errors.ForeignKeyViolation as e:
        if conn:
            conn.rollback()
        print(f"Foreign key violation error updating record in {schema}.{table}: {e}")
        return jsonify({"error": f"Referenced record not found (foreign key violation). Details: {e.diag.message_detail}"}), 400
    except Exception as e:    
        if conn:
            conn.rollback() # Rollback on error
        print(f"Error updating record in {schema}.{table}: {e}")
        return jsonify({"error": str(e)}), 500
    finally:    
        if conn:
            conn.close()

@app.route('/mymglab/api/table/<string:schema>/<string:table>/<pk_value>', methods=['DELETE'])
def delete_record(schema, table, pk_value):
    """
    Generic function to delete a record from a table.
    Handles single or composite primary keys, including partitioned tables.
    For partitioned tables (lab.samples, lab.sampling), `sampling_date` MUST be passed as a query parameter.
    """
    pk_columns = get_pk_column(schema, table) # Get the primary key column name(s)
    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor() as cur:
            where_clauses = []
            params = []

            if isinstance(pk_columns, tuple): # Composite primary key
                # For partitioned tables, require the partition key in query params
                if (schema.lower(), table.lower()) in [('lab', 'sampling'), ('lab', 'samples')]:
                    sampling_date = request.args.get('sampling_date')
                    if not sampling_date:
                        return jsonify({"error": f"Missing 'sampling_date' query parameter for partitioned table '{table}' deletion."}), 400
                    
                    main_pk_column = pk_columns[0]
                    where_clauses.append(f'"{main_pk_column}" = %s')
                    params.append(pk_value)
                    
                    where_clauses.append(f'"{pk_columns[1]}" = %s')
                    params.append(sampling_date)
                else: # Other composite PKs, expect all parts as query parameters
                    # This requires the frontend to send all parts of the composite key as query params
                    # e.g., /api/table/lims/project_persons/PROJECT_ID?person_id=PERSON_ID
                    # The `pk_value` in the URL will be assumed to be the first part of the composite key.
                    main_pk_column = pk_columns[0]
                    where_clauses.append(f'"{main_pk_column}" = %s')
                    params.append(pk_value)
                    
                    for col in pk_columns[1:]: # Add remaining composite key parts from query args
                        val = request.args.get(col)
                        if not val:
                            return jsonify({"error": f"Missing primary key component '{col}' in query parameters for composite PK deletion."}), 400
                        where_clauses.append(f'"{col}" = %s')
                        params.append(val)
            else: # Single primary key
                where_clauses.append(f'"{pk_columns}" = %s')
                # Convert PK value to int if the PK column is an integer type (serial)
                if schema.lower() == 'lab' and table.lower() in ['experiments_projects', 'storage_log', 'nanodrop', 'qubit', 'tapestation', 'pcr', 'gelelectrophoresis', 'qpcr', 'library', 'sequencing', 'extraction', 'dissections', 'fishing'] and pk_columns == 'nr':
                     try:
                         params.append(int(pk_value))
                     except ValueError:
                         return jsonify({"error": f"Invalid ID format for '{pk_columns}': {pk_value}. Expected integer."}), 400
                elif schema.lower() == 'lims' and table.lower() in ['customers', 'orders'] and pk_columns == 'customer_id':
                    try:
                         params.append(int(pk_value))
                    except ValueError:
                         return jsonify({"error": f"Invalid ID format for '{pk_columns}': {pk_value}. Expected integer."}), 400
                else:
                    params.append(pk_value)

            query = f'DELETE FROM "{schema.lower()}"."{table.lower()}" WHERE {" AND ".join(where_clauses)};'
            print(f"Executing DELETE query: {query} with params: {params}") # For debugging
            cur.execute(query, params)
            conn.commit() # Commit the transaction
            if cur.rowcount == 0:    
                return jsonify({"error": "Record not found"}), 404 # 404 Not Found if record doesn't exist
        return "", 204 # 204 No Content for successful deletion (no body returned)
    except psycopg2.errors.ForeignKeyViolation as e:
        if conn:
            conn.rollback()
        print(f"Foreign key violation error deleting record in {schema}.{table}: {e}")
        return jsonify({"error": f"Cannot delete record due to existing dependencies (foreign key violation). Details: {e.diag.message_detail}"}), 409 # 409 Conflict
    except Exception as e:    
        if conn:
            conn.rollback() # Rollback on error
        print(f"Error deleting record in {schema}.{table}: {e}")
        return jsonify({"error": str(e)}), 500
    finally:    
        if conn:
            conn.close()

@app.route('/mymglab/api/table/<string:schema>/<string:table>/batch_upload', methods=['POST'])
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
            # Handle JSONB fields: if they are strings, attempt to parse them.
            data_tuples = []
            for record in records:
                row = []
                for col in columns:
                    val = record.get(col)
                    if val == '':
                        row.append(None)
                    elif col.endswith('_jsonb') and isinstance(val, str):
                        try:
                            row.append(json.loads(val))
                        except json.JSONDecodeError:
                            # Log error but continue for batch, or raise specific error
                            print(f"WARNING: Invalid JSON for field '{col}' in record: {val}. Setting to None.")
                            row.append(None)
                    elif col == 'attachment' and val is not None:
                        try:
                            # Assume base64 encoded string is sent for attachment in batch
                            row.append(psycopg2.Binary(base64.b64decode(val)))
                        except Exception as decode_error:
                            print(f"Warning: Could not decode base64 for attachment in batch. Error: {decode_error}")
                            row.append(None) # Treat as null if decoding fails
                    else:
                        row.append(val)
                data_tuples.append(tuple(row))

            query_template = f"INSERT INTO \"{schema.lower()}\".\"{table.lower()}\" ({column_names}) VALUES %s"
            
            print(f"Executing batch_upload query: {query_template} with {len(data_tuples)} records.") # For debugging
            psycopg2.extras.execute_values(cur, query_template, data_tuples) # Efficient batch insert
            conn.commit() # Commit the transaction
        return jsonify({"success": True, "inserted_rows": len(records)}), 201 # 201 Created for batch insert
    except psycopg2.errors.UniqueViolation as e:
        if conn:
            conn.rollback()
        print(f"Unique violation error during batch upload for {schema}.{table}: {e}")
        return jsonify({"success": False, "error": f"Batch upload failed due to unique constraint violation. Details: {e.diag.message_detail}"}), 409
    except psycopg2.errors.ForeignKeyViolation as e:
        if conn:
            conn.rollback()
        print(f"Foreign key violation error during batch upload for {schema}.{table}: {e}")
        return jsonify({"success": False, "error": f"Batch upload failed due to foreign key violation. Ensure all referenced IDs exist. Details: {e.diag.message_detail}"}), 400
    except Exception as e:
        if conn:    
            conn.rollback() # Rollback on error
        print(f"Error during batch upload for {schema}.{table}: {e}")
        return jsonify({"success": False, "error": str(e)}), 500
    finally:
        if conn:    
            conn.close()

@app.route('/mymglab/api/table/<string:schema>/<string:table>/info', methods=['GET'])
def get_table_info(schema, table):
    """
    Returns column information (name, type, is_nullable) for a given table.
    Useful for dynamically building forms in the frontend when a table is empty.
    """
    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute(f"""
                SELECT column_name AS name, data_type AS type, is_nullable
                FROM information_schema.columns
                WHERE table_schema = %s AND table_name = %s
                ORDER BY ordinal_position;
            """, (schema.lower(), table.lower()))
            columns = cur.fetchall()
            return jsonify({"columns": columns}), 200
    except psycopg2.errors.UndefinedTable:
        return jsonify({"error": f"Table '{schema}.{table}' not found."}), 404
    except Exception as e:
        print(f"Error fetching table info for {schema}.{table}: {e}")
        return jsonify({"error": str(e)}), 500
    finally:
        if conn:
            conn.close()

@app.route('/mymglab/api/table_names_for_forms', methods=['GET'])
def get_all_table_names():
    """
    Returns a list of all non-system table names across specific schemas.
    Used for dynamic dropdowns in the frontend (e.g., for workflow step target tables).
    """
    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor() as cur:
            # Only include tables from our defined schemas, exclude audit.log and partitioned tables' children
            cur.execute("""
                SELECT table_schema, table_name
                FROM information_schema.tables
                WHERE table_schema IN ('lab', 'lims', 'reference', 'bioinformatics', 'audit')
                AND table_type = 'BASE TABLE'
                AND table_name NOT LIKE '%_y%' -- Exclude partitioned child tables (e.g., sampling_y2024)
                AND table_name NOT IN ('log') -- Exclude audit.log
                ORDER BY table_schema, table_name;
            """)
            tables = []
            for schema_name, table_name in cur.fetchall():
                # Format as Schema.TableName for clarity in frontend
                tables.append(f"{schema_name.capitalize()}.{table_name}")
            return jsonify(tables), 200
    except Exception as e:
        print(f"Error fetching all table names: {e}")
        return jsonify({"error": str(e)}), 500
    finally:
        if conn:
            conn.close()

@app.route('/mymglab/api/create_if_not_exists/<string:schema>/<string:table>', methods=['POST'])
def create_if_not_exists(schema, table):
    """
    Generic function to create a new record in a table only if it doesn't already exist
    based on its primary key. Useful for reference tables where you want to ensure
    an entry exists before linking to it.
    """
    data = request.get_json()
    if not data:
        return jsonify({"error": "No data provided"}), 400

    pk_columns = get_pk_column(schema, table)
    if isinstance(pk_columns, tuple):
        return jsonify({"error": "create_if_not_exists does not support composite primary keys."}), 400
    
    pk_value = data.get(pk_columns)
    if not pk_value:
        return jsonify({"error": f"Missing primary key '{pk_columns}' in data."}), 400

    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            # Check if record already exists
            cur.execute(f'SELECT "{pk_columns}" FROM "{schema.lower()}"."{table.lower()}" WHERE "{pk_columns}" = %s;', (pk_value,))
            if cur.fetchone():
                return jsonify({"success": True, "message": "Record already exists.", "created": False}), 200
            
            # If not exists, proceed with insertion
            columns = data.keys()
            values = list(data.values())
            column_names = ', '.join([f'"{col}"' for col in columns])
            value_placeholders = ', '.join(['%s'] * len(values))
            
            query = f'INSERT INTO "{schema.lower()}"."{table.lower()}" ({column_names}) VALUES ({value_placeholders}) RETURNING *;'
            cur.execute(query, values)
            new_record = cur.fetchone()
            conn.commit()
            return jsonify({"success": True, "message": "Record created.", "created": True, "record": new_record}), 201
    except psycopg2.errors.UniqueViolation as e:
        if conn:
            conn.rollback()
        # If a unique violation occurs, it means it was created by another concurrent transaction,
        # or it exists but wasn't caught by our initial SELECT (race condition). Treat as exists.
        print(f"Unique violation during create_if_not_exists for {schema}.{table}: {e}. Treating as already exists.")
        return jsonify({"success": True, "message": "Record already exists (unique violation).", "created": False}), 200
    except Exception as e:
        if conn:
            conn.rollback()
        print(f"Error in create_if_not_exists for {schema}.{table}: {e}")
        return jsonify({"error": str(e)}), 500
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
    print(f" -> API listening on http://{host}:{port}/mymglab/api/")
    print(f" -> Access the UI at http://127.0.0.1:{port}")
    print("="*60)

    # Use app.run() for development with debugging, waitress for production deployment
    if FLASK_ENV == "development":
        app.run(host=host, port=port, debug=True)
    else:
        # Waitress is a production-ready WSGI server
        serve(app, host=host, port=port)
