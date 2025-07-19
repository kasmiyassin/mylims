# pip install reportlab
# pip install Flask psycopg2-binary bcrypt waitress
import os
import psycopg2
import psycopg2.extras
import bcrypt
from flask import Flask, jsonify, request, send_from_directory, redirect, url_for, g, make_response
from flask_cors import CORS
from waitress import serve
import base64
import json
import csv
from io import StringIO, BytesIO
from functools import wraps

# For PDF generation
from reportlab.lib.pagesizes import letter
from reportlab.pdfgen import canvas
from reportlab.lib.units import inch
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer
from reportlab.lib.styles import getSampleStyleSheet

# Database connection details
DB_HOST = os.getenv('DB_HOST', 'localhost')
DB_NAME = os.getenv('DB_NAME', 'wanderfische')
DB_USER = os.getenv('DB_USER', 'kasmi')
DB_PASS = os.getenv('DB_PASS', 'password')

STATIC_FOLDER = '.'
app = Flask(__name__, static_folder=STATIC_FOLDER)
FLASK_ENV = os.getenv('FLASK_ENV', 'development')

CORS(app)

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
            raise
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
        ('lims', 'project_persons'): ('project_id', 'person_id'),
        ('lims', 'cruises'): 'cruise_id',
        ('lims', 'workflows'): 'workflow_id',
        ('lims', 'permits'): 'permit_id',
        ('lims', 'primers'): 'primer_id',
        ('lims', 'sop'): 'sop_id',
        ('lims', 'workflow_steps'): 'step_id',
        ('lims', 'equipment'): 'equipment_id',
        ('lims', 'suppliers'): 'supplier_id',
        ('lims', 'inventory_items'): 'item_id',
        ('lims', 'orders'): 'fi_order_nr',
        ('lims', 'reagents'): 'reagent_id',
        ('lims', 'publication_type'): 'publication_type_id',
        ('lims', 'publications'): 'publication_id',

        # Schema: Lab
        ('lab', 'storage'): 'storage_id',
        ('lab', 'experiments'): ('experiment_id', 'experiment_date'),
        ('lab', 'experiments_projects'): 'experiment_project_id',
        ('lab', 'protocol_runs'): 'protocol_run_id',
        ('lab', 'sampling'): ('sampling_id', 'sampling_date'),
        ('lab', 'master_samples'): 'sample_id',
        ('lab', 'samples'): ('sample_id', 'sampling_date'),
        ('lab', 'storage_log'): 'log_id',
        ('lab', 'fish'): 'sample_id',
        ('lab', 'tissue'): 'sample_id',
        ('lab', 'otoliths'): 'otolith_id',
        ('lab', 'dna'): 'sample_id',
        ('lab', 'rna'): 'sample_id',
        ('lab', 'sediments'): 'sample_id',
        ('lab', 'water'): 'sample_id',
        ('lab', 'experiments_samples'): ('experiment_id', 'sample_id', 'experiment_date'),
        ('lab', 'dissections'): ('dissection_id', 'dissection_date'),
        ('lab', 'extraction'): ('extraction_id', 'extraction_date'),
        ('lab', 'nanodrop'): ('nanodrop_id', 'measurement_date'),
        ('lab', 'qubit'): ('qubit_id', 'measurement_date'),
        ('lab', 'tapestation'): ('tapestation_id', 'measurement_date'),
        ('lab', 'pcr'): ('pcr_id', 'pcr_date'),
        ('lab', 'gelelectrophoresis'): ('gelelectrophoresis_id', 'run_date'),
        ('lab', 'qpcr'): ('qpcr_id', 'qpcr_date'),
        ('lab', 'library'): ('library_id', 'prep_date'),
        ('lab', 'sequencing'): ('sequencing_id', 'sequencing_date'),
        ('lab', 'datasets'): ('dataset_id', 'reception_date'),

        # Schema: Bioinformatics
        ('bioinformatics', 'reference_databases'): 'db_id',
        ('bioinformatics', 'analysis_pipelines'): 'pipeline_id',
        ('bioinformatics', 'analysis_runs'): ('run_id', 'run_date'),
        ('bioinformatics', 'edna_assignments'): 'assignment_id',
    }

    pk = pk_map.get((schema_lower, table_lower))
    if pk:
        return pk

    # Fallback for views or tables not explicitly listed, try common PK names
    # This is less reliable and should be avoided for critical tables.
    print(f"WARNING: No explicit PK mapping for {schema}.{table}. Attempting common PKs.")
    conn = get_db_connection()
    with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
        try:
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

    return 'id' # Default to 'id' or 'nr' if no other PK is found (less reliable)

# --- BASIC AUTHENTICATION DECORATOR (FOR DEMONSTRATION ONLY) ---
# This is NOT secure for production. Use JWT or session management in a real app.
def login_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        user_id = request.headers.get('X-User-ID')
        user_type = request.headers.get('X-User-Type')
        if not user_id or not user_type:
            return jsonify({"error": "Authentication required. Please provide X-User-ID and X-User-Type headers."}), 401
        # In a real application, you would validate the user_id and user_type against your database
        # For this example, we'll just pass them through
        g.current_user_id = user_id
        g.current_user_type = user_type
        return f(*args, **kwargs)
    return decorated_function

# =================================================================
# API ENDPOINTS
# All routes are prefixed with '/mymglab/api/'
# =================================================================

@app.route('/mymglab/api/login', methods=['POST'])
def login_user():
    """Handles user login authentication for personal, customers, and external_contacts."""
    data = request.get_json()
    user_type = data.get('user_type')
    user_id = data.get('user_id')
    password = data.get('password')

    if not user_type or not user_id or not password:
        return jsonify({"error": "Missing user type, ID, or password"}), 400

    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            table_name = ""
            id_column = ""
            name_column = ""

            if user_type == 'personal':
                table_name = '"reference"."personal"'
                id_column = 'person_id'
                name_column = 'full_name'
            elif user_type == 'customers':
                table_name = '"lims"."customers"'
                id_column = 'customer_id'
                name_column = 'customer_name'
            elif user_type == 'external_contacts':
                table_name = '"lims"."external_contacts"'
                id_column = 'contact_id'
                name_column = 'full_name'
            else:
                return jsonify({"error": "Invalid user type"}), 400

            query = f'SELECT "{id_column}", "{name_column}", "password_hash" FROM {table_name} WHERE "{id_column}" = %s;'
            cur.execute(query, (user_id,))
            user = cur.fetchone()

        if user:
            if user.get('password_hash') and bcrypt.checkpw(password.encode('utf-8'), user['password_hash'].encode('utf-8')):
                user.pop('password_hash', None)
                user['user_type'] = user_type
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

@app.route('/mymglab/api/register_customer', methods=['POST'])
def register_customer():
    """Registers a new customer in the lims.customers table."""
    data = request.get_json()
    customer_name = data.get('customer_name')
    customer_abrv = data.get('customer_abrv')
    address = data.get('address')
    mail = data.get('mail')
    phone = data.get('phone')
    password = data.get('password')

    if not all([customer_name, customer_abrv, address, mail, phone, password]):
        return jsonify({"error": "Missing required fields"}), 400

    hashed_password = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')

    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute('SELECT customer_id FROM "lims"."customers" WHERE customer_abrv = %s;', (customer_abrv,))
            if cur.fetchone():
                return jsonify({"error": "Customer with this abbreviation already exists"}), 409

            query = """
                INSERT INTO "lims"."customers" ("customer_name", "customer_abrv", "address", "mail", "phone", "password_hash")
                VALUES (%s, %s, %s, %s, %s, %s) RETURNING *;
            """
            cur.execute(query, (customer_name, customer_abrv, address, mail, phone, hashed_password))
            new_customer = cur.fetchone()
            conn.commit()
            new_customer.pop('password_hash', None)
            return jsonify({"success": True, "customer": new_customer}), 201
    except Exception as e:
        if conn:
            conn.rollback()
        print(f"Customer registration error: {e}")
        return jsonify({"error": str(e)}), 500
    finally:
        if conn:
            conn.close()

@app.route('/mymglab/api/update_password', methods=['PUT'])
@login_required # Protect this endpoint
def update_password():
    """Updates a user's password."""
    data = request.get_json()
    user_type = data.get('user_type')
    user_id = data.get('user_id')
    new_password = data.get('new_password')

    # Ensure the user making the request is authorized to change this password
    if g.current_user_id != user_id or g.current_user_type != user_type:
        return jsonify({"error": "Unauthorized to change this user's password."}), 403

    if not all([user_type, user_id, new_password]):
        return jsonify({"error": "Missing user type, ID, or new password"}), 400

    hashed_password = bcrypt.hashpw(new_password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')

    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor() as cur:
            table_name = ""
            id_column = ""

            if user_type == 'personal':
                table_name = '"reference"."personal"'
                id_column = 'person_id'
            elif user_type == 'customers':
                table_name = '"lims"."customers"'
                id_column = 'customer_id'
            elif user_type == 'external_contacts':
                table_name = '"lims"."external_contacts"'
                id_column = 'contact_id'
            else:
                return jsonify({"error": "Invalid user type"}), 400

            query = f'UPDATE {table_name} SET "password_hash" = %s WHERE "{id_column}" = %s;'
            cur.execute(query, (hashed_password, user_id))
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
@login_required # Protect this endpoint
def global_search(search_term):
    """Searches across multiple tables for a given term using full-text search."""
    ts_query = f"plainto_tsquery('public.lims_english', %s)"

    results = {}

    queries = {
        "projects": ('SELECT project_id, title FROM "lims"."projects" WHERE project_search_vector @@ ' + ts_query + ' LIMIT 5',),
        "samples": ('SELECT sample_id, sample_type_id AS sample_type, sample_status_id FROM "lab"."samples" WHERE sample_search_vector @@ ' + ts_query + ' LIMIT 5',),
        "experiments": ('SELECT experiment_id, experiment_title FROM "lab"."experiments" WHERE experiment_search_vector @@ ' + ts_query + ' LIMIT 5',),
        "sops": ('SELECT sop_id, title FROM "lims"."sop" WHERE sop_search_vector @@ ' + ts_query + ' LIMIT 5',),
        "reagents": ('SELECT reagent_id, reagent_complete_name FROM "lims"."reagents" WHERE reagent_search_vector @@ ' + ts_query + ' LIMIT 5',),
        "personal": ('SELECT person_id, full_name AS "Full Name" FROM "reference"."personal" WHERE personal_search_vector @@ ' + ts_query + ' LIMIT 5',),
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
                    results[key] = []
        return jsonify(results), 200
    except Exception as e:
        print(f"Global search error: {e}")
        return jsonify({"error": "An internal server error occurred during search."}), 500
    finally:
        if conn:
            conn.close()

@app.route('/mymglab/api/dashboard-stats', methods=['GET'])
@login_required # Protect this endpoint
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
@login_required # Protect this endpoint
def get_table_data(schema, table):
    """
    Generic function to fetch data from a table or view, with optional filtering.
    Handles binary data (bytea) by Base64 encoding it for JSON serialization.
    """
    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            db_schema_name = schema.lower()
            db_table_name = table.lower()

            # Special handling for views which might have PascalCase names in the SQL schema
            # Or if the frontend uses a different casing/name
            view_name_map = {
                'sample_full_details_view': 'sample_full_details_view',
                'project_comprehensive_summary_view': 'project_comprehensive_summary_view',
                'storage_occupancy_view': 'storage_occupancy_view',
                'reagent_status_view': 'reagent_status_view',
                'experiment_progress_overview_view': 'experiment_progress_overview_view',
                'complete_species_taxon_view': 'complete_species_taxon_view',
                'taxon_hierarchy_view': 'taxon_hierarchy_view',
                'analysis_results_summary': 'analysis_results_summary',
                'detailed_samples_view': 'detailed_samples_view',
                'project_overview_view': 'project_overview_view',
                'sample_workflow_progress_view': 'sample_workflow_progress_view',
                'storage_inventory_view': 'storage_inventory_view',
                'experiment_summary_view': 'experiment_summary_view',
                'project_financial_summary_view': 'project_financial_summary_view',
                'full_analysis_results_view': 'full_analysis_results_view',
                'monthly_sample_reception_mv': 'monthly_sample_reception_mv'
            }
            if table.lower() in view_name_map:
                db_table_name = view_name_map[table.lower()]

            base_query = f'SELECT * FROM "{db_schema_name}"."{db_table_name}"'
            where_clauses = []
            params = []

            for key, value in request.args.items():
                if key.startswith('filter_'):
                    col_name = key[len('filter_'):]
                    # Attempt to cast to int for ID fields if numeric, otherwise use ILIKE
                    if col_name.endswith('_id') or col_name.endswith('_nr') or col_name.endswith('_date') or col_name == 'sample_type_id' or col_name == 'customer_id':
                        try:
                            params.append(int(value))
                        except ValueError:
                            params.append(value) # Keep as string if not int
                        where_clauses.append(f'"{col_name}" = %s')
                    else:
                        where_clauses.append(f'"{col_name}" ILIKE %s')
                        params.append(f"%{value}%")
                elif key not in ['limit', 'order_by', 'order_direction', 'format']: # 'format' added for export
                    # Direct column filtering with exact match
                    where_clauses.append(f'"{key}" = %s')
                    params.append(value)

            query_parts = []
            if where_clauses:
                query_parts.append(f"WHERE {' AND '.join(where_clauses)}")

            order_by = request.args.get('order_by')
            order_direction = request.args.get('order_direction', 'asc')
            if order_by:
                query_parts.append(f'ORDER BY "{order_by}" {order_direction.upper()}')

            limit = request.args.get('limit')
            if limit and limit.isdigit():
                query_parts.append(f'LIMIT {limit}')

            query = f"{base_query} {' '.join(query_parts)};"

            print(f"Executing GET query: {query} with params: {params}")
            cur.execute(query, params)
            data = cur.fetchall()

            processed_data = []
            for row in data:
                new_row = dict(row)
                for key, value in new_row.items():
                    if isinstance(value, memoryview):
                        new_row[key] = base64.b64encode(value.tobytes()).decode('utf-8')
                    elif isinstance(value, bytes):
                        new_row[key] = base64.b64encode(value).decode('utf-8')
                    elif isinstance(value, (dict, list)): # Handle jsonb fields
                        new_row[key] = value
                    elif isinstance(value, psycopg2.Date): # Convert psycopg2 Date to string
                        new_row[key] = value.isoformat()
                    elif isinstance(value, psycopg2.Time): # Convert psycopg2 Time to string
                        new_row[key] = str(value)
                    elif isinstance(value, psycopg2.Timestamp): # Convert psycopg2 Timestamp to string
                        new_row[key] = value.isoformat()
                processed_data.append(new_row)

            return jsonify(processed_data), 200
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
@login_required # Protect this endpoint
def create_record(schema, table):
    """Generic function to create a new record in a table."""
    conn = None
    try:
        conn = get_db_connection()

        if request.is_json:
            data = request.get_json()
        else:
            data = request.form.to_dict()
            for key, file_storage in request.files.items():
                if file_storage and file_storage.filename != '':
                    data[key] = psycopg2.Binary(file_storage.read())
                else:
                    data[key] = None

        if not data:
            return jsonify({"error": "No data provided"}), 400

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

        column_names = ', '.join([f'"{col}"' for col in columns])
        value_placeholders = ', '.join(['%s'] * len(values))

        query = f'INSERT INTO "{schema.lower()}"."{table.lower()}" ({column_names}) VALUES ({value_placeholders}) RETURNING *;'

        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            print(f"Executing POST query: {query} with values: {values}")
            cur.execute(query, values)
            new_record = cur.fetchone()
            conn.commit()
        return jsonify(new_record), 201
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
            conn.rollback()
        print(f"Error creating record in {schema}.{table}: {e}")
        return jsonify({"error": str(e)}), 500
    finally:
        if conn:
            conn.close()

@app.route('/mymglab/api/table/<string:schema>/<string:table>/<pk_value>', methods=['PUT'])
@login_required # Protect this endpoint
def update_record(schema, table, pk_value):
    """
    Generic function to update an existing record in a table.
    Handles single or composite primary keys.
    For composite primary keys, additional PK components must be provided in the request body.
    """
    pk_columns = get_pk_column(schema, table)
    data = request.get_json()
    if not data:
        return jsonify({"error": "No data provided"}), 400

    set_clauses = []
    values = []

    for key, val in data.items():
        # Skip PK columns as they are used in WHERE clause, not SET clause
        if (isinstance(pk_columns, tuple) and key in pk_columns) or (isinstance(pk_columns, str) and key == pk_columns):
            continue

        set_clauses.append(f'"{key}" = %s')
        if val == '':
            values.append(None)
        elif key.endswith('_jsonb') and isinstance(val, str):
            try:
                values.append(json.loads(val))
            except json.JSONDecodeError:
                return jsonify({"error": f"Invalid JSON format for field '{key}'"}), 400
        else:
            values.append(val)

    if not set_clauses:
        return jsonify({"error": "No fields to update"}), 400

    where_clauses = []
    pk_values_for_query = []

    if isinstance(pk_columns, tuple):
        # First part of composite PK from URL
        where_clauses.append(f'"{pk_columns[0]}" = %s')
        pk_values_for_query.append(pk_value)

        # Remaining parts from request body
        for i in range(1, len(pk_columns)):
            col = pk_columns[i]
            if col not in data:
                return jsonify({"error": f"Missing primary key component '{col}' in request body for composite PK update."}), 400
            where_clauses.append(f'"{col}" = %s')
            pk_values_for_query.append(data[col])
    else:
        # Single primary key from URL
        where_clauses.append(f'"{pk_columns}" = %s')
        pk_values_for_query.append(pk_value)

    final_values = values + pk_values_for_query

    query = f'UPDATE "{schema.lower()}"."{table.lower()}" SET {", ".join(set_clauses)} WHERE {" AND ".join(where_clauses)} RETURNING *;'

    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            print(f"Executing PUT query: {query} with values: {final_values}")
            cur.execute(query, final_values)
            updated_record = cur.fetchone()
            conn.commit()
        if updated_record:
            return jsonify(updated_record), 200
        else:
            return jsonify({"error": "Record not found or no changes made."}), 404
    except psycopg2.errors.ForeignKeyViolation as e:
        if conn:
            conn.rollback()
        print(f"Foreign key violation error updating record in {schema}.{table}: {e}")
        return jsonify({"error": f"Referenced record not found (foreign key violation). Details: {e.diag.message_detail}"}), 400
    except Exception as e:
        if conn:
            conn.rollback()
        print(f"Error updating record in {schema}.{table}: {e}")
        return jsonify({"error": str(e)}), 500
    finally:
        if conn:
            conn.close()

@app.route('/mymglab/api/table/<string:schema>/<string:table>/<pk_value>', methods=['DELETE'])
@login_required # Protect this endpoint
def delete_record(schema, table, pk_value):
    """
    Generic function to delete a record from a table.
    Handles single or composite primary keys.
    For composite primary keys, additional PK components must be passed as query parameters.
    """
    pk_columns = get_pk_column(schema, table)
    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor() as cur:
            where_clauses = []
            params = []

            if isinstance(pk_columns, tuple):
                # First part of composite PK from URL
                where_clauses.append(f'"{pk_columns[0]}" = %s')
                params.append(pk_value)

                # Remaining parts from query parameters
                for i in range(1, len(pk_columns)):
                    col = pk_columns[i]
                    val = request.args.get(col)
                    if not val:
                        return jsonify({"error": f"Missing primary key component '{col}' in query parameters for composite PK deletion."}), 400
                    where_clauses.append(f'"{col}" = %s')
                    params.append(val)
            else:
                # Single primary key from URL
                where_clauses.append(f'"{pk_columns}" = %s')
                params.append(pk_value)

            query = f'DELETE FROM "{schema.lower()}"."{table.lower()}" WHERE {" AND ".join(where_clauses)};'
            print(f"Executing DELETE query: {query} with params: {params}")
            cur.execute(query, params)
            conn.commit()
            if cur.rowcount == 0:
                return jsonify({"error": "Record not found"}), 404
        return "", 204
    except psycopg2.errors.ForeignKeyViolation as e:
        if conn:
            conn.rollback()
        print(f"Foreign key violation error deleting record in {schema}.{table}: {e}")
        return jsonify({"error": f"Cannot delete record due to existing dependencies (foreign key violation). Details: {e.diag.message_detail}"}), 409
    except Exception as e:
        if conn:
            conn.rollback()
        print(f"Error deleting record in {schema}.{table}: {e}")
        return jsonify({"error": str(e)}), 500
    finally:
        if conn:
            conn.close()

@app.route('/mymglab/api/table/<string:schema>/<string:table>/batch_upload', methods=['POST'])
@login_required # Protect this endpoint
def batch_upload(schema, table):
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
            columns = [col for col in records[0].keys()]
            column_names = ', '.join([f'"{col}"' for col in columns])

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
                            print(f"WARNING: Invalid JSON for field '{col}' in record: {val}. Setting to None.")
                            row.append(None)
                    elif col == 'attachment' and val is not None:
                        try:
                            row.append(psycopg2.Binary(base64.b64decode(val)))
                        except Exception as decode_error:
                            print(f"Warning: Could not decode base64 for attachment in batch. Error: {decode_error}")
                            row.append(None)
                    else:
                        row.append(val)
                data_tuples.append(tuple(row))

            query_template = f"INSERT INTO \"{schema.lower()}\".\"{table.lower()}\" ({column_names}) VALUES %s"

            print(f"Executing batch_upload query: {query_template} with {len(data_tuples)} records.")
            psycopg2.extras.execute_values(cur, query_template, data_tuples)
            conn.commit()
        return jsonify({"success": True, "inserted_rows": len(records)}), 201
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
            conn.rollback()
        print(f"Error during batch upload for {schema}.{table}: {e}")
        return jsonify({"success": False, "error": str(e)}), 500
    finally:
        if conn:
            conn.close()

@app.route('/mymglab/api/table/<string:schema>/<string:table>/info', methods=['GET'])
@login_required # Protect this endpoint
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
@login_required # Protect this endpoint
def get_all_table_names():
    """
    Returns a list of all non-system table names across specific schemas.
    Used for dynamic dropdowns in the frontend (e.g., for workflow step target tables).
    """
    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor() as cur:
            cur.execute("""
                SELECT table_schema, table_name
                FROM information_schema.tables
                WHERE table_schema IN ('lab', 'lims', 'reference', 'bioinformatics', 'audit')
                AND table_type = 'BASE TABLE'
                AND table_name NOT LIKE '%_y%'
                AND table_name NOT IN ('log')
                ORDER BY table_schema, table_name;
            """)
            tables = []
            for schema_name, table_name in cur.fetchall():
                tables.append(f"{schema_name.capitalize()}.{table_name}")
            return jsonify(tables), 200
    except Exception as e:
        print(f"Error fetching all table names: {e}")
        return jsonify({"error": str(e)}), 500
    finally:
        if conn:
            conn.close()

@app.route('/mymglab/api/create_if_not_exists/<string:schema>/<string:table>', methods=['POST'])
@login_required # Protect this endpoint
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
            cur.execute(f'SELECT "{pk_columns}" FROM "{schema.lower()}"."{table.lower()}" WHERE "{pk_columns}" = %s;', (pk_value,))
            if cur.fetchone():
                return jsonify({"success": True, "message": "Record already exists.", "created": False}), 200

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

@app.route('/mymglab/api/table/<string:schema>/<string:table>/export', methods=['GET'])
@login_required # Protect this endpoint
def export_table_data(schema, table):
    """
    Exports data from a table or view in CSV or JSON format.
    Supports filtering, ordering, and limiting via query parameters.
    """
    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            db_schema_name = schema.lower()
            db_table_name = table.lower()

            # Reuse the view_name_map from get_table_data for consistency
            view_name_map = {
                'sample_full_details_view': 'sample_full_details_view',
                'project_comprehensive_summary_view': 'project_comprehensive_summary_view',
                'storage_occupancy_view': 'storage_occupancy_view',
                'reagent_status_view': 'reagent_status_view',
                'experiment_progress_overview_view': 'experiment_progress_overview_view',
                'complete_species_taxon_view': 'complete_species_taxon_view',
                'taxon_hierarchy_view': 'taxon_hierarchy_view',
                'analysis_results_summary': 'analysis_results_summary',
                'detailed_samples_view': 'detailed_samples_view',
                'project_overview_view': 'project_overview_view',
                'sample_workflow_progress_view': 'sample_workflow_progress_view',
                'storage_inventory_view': 'storage_inventory_view',
                'experiment_summary_view': 'experiment_summary_view',
                'project_financial_summary_view': 'project_financial_summary_view',
                'full_analysis_results_view': 'full_analysis_results_view',
                'monthly_sample_reception_mv': 'monthly_sample_reception_mv'
            }
            if table.lower() in view_name_map:
                db_table_name = view_name_map[table.lower()]

            base_query = f'SELECT * FROM "{db_schema_name}"."{db_table_name}"'
            where_clauses = []
            params = []

            for key, value in request.args.items():
                if key.startswith('filter_'):
                    col_name = key[len('filter_'):]
                    if col_name.endswith('_id') or col_name.endswith('_nr') or col_name.endswith('_date') or col_name == 'sample_type_id' or col_name == 'customer_id':
                        try:
                            params.append(int(value))
                        except ValueError:
                            params.append(value)
                        where_clauses.append(f'"{col_name}" = %s')
                    else:
                        where_clauses.append(f'"{col_name}" ILIKE %s')
                        params.append(f"%{value}%")
                elif key not in ['limit', 'order_by', 'order_direction', 'format']:
                    where_clauses.append(f'"{key}" = %s')
                    params.append(value)

            query_parts = []
            if where_clauses:
                query_parts.append(f"WHERE {' AND '.join(where_clauses)}")

            order_by = request.args.get('order_by')
            order_direction = request.args.get('order_direction', 'asc')
            if order_by:
                query_parts.append(f'ORDER BY "{order_by}" {order_direction.upper()}')

            limit = request.args.get('limit')
            if limit and limit.isdigit():
                query_parts.append(f'LIMIT {limit}')

            query = f"{base_query} {' '.join(query_parts)};"

            print(f"Executing EXPORT query: {query} with params: {params}")
            cur.execute(query, params)
            data = cur.fetchall()

            # Process data to handle memoryview, bytes, and date/time objects
            processed_data = []
            for row in data:
                new_row = dict(row)
                for key, value in new_row.items():
                    if isinstance(value, memoryview):
                        new_row[key] = base64.b64encode(value.tobytes()).decode('utf-8')
                    elif isinstance(value, bytes):
                        new_row[key] = base64.b64encode(value).decode('utf-8')
                    elif isinstance(value, (dict, list)):
                        new_row[key] = json.dumps(value) # Convert JSONB to string for CSV/JSON consistency
                    elif isinstance(value, psycopg2.Date):
                        new_row[key] = value.isoformat()
                    elif isinstance(value, psycopg2.Time):
                        new_row[key] = str(value)
                    elif isinstance(value, psycopg2.Timestamp):
                        new_row[key] = value.isoformat()
                    elif value is None:
                        new_row[key] = '' # Represent None as empty string for CSV
                processed_data.append(new_row)

            export_format = request.args.get('format', 'json').lower()

            if export_format == 'csv':
                if not processed_data:
                    return "", 204 # No content if no data

                output = StringIO()
                writer = csv.DictWriter(output, fieldnames=processed_data[0].keys())
                writer.writeheader()
                writer.writerows(processed_data)
                csv_output = output.getvalue()

                response = make_response(csv_output)
                response.headers["Content-Disposition"] = f"attachment; filename={schema}_{table}.csv"
                response.headers["Content-type"] = "text/csv"
                return response
            elif export_format == 'json':
                response = jsonify(processed_data)
                response.headers["Content-Disposition"] = f"attachment; filename={schema}_{table}.json"
                response.headers["Content-type"] = "application/json"
                return response
            else:
                return jsonify({"error": "Invalid export format. Supported formats: csv, json."}), 400

    except psycopg2.errors.UndefinedTable as e:
        print(f"Error: Table or view '{db_schema_name}.{db_table_name}' does not exist. {e}")
        return jsonify({"error": f"Table or view '{schema}.{table}' does not exist."}), 404
    except Exception as e:
        print(f"Error exporting table data for {schema}.{table}: {e}")
        return jsonify({"error": str(e)}), 500
    finally:
        if conn:
            conn.close()

@app.route('/mymglab/api/table/<string:schema>/<string:table>/import_csv', methods=['POST'])
@login_required # Protect this endpoint
def import_csv_data(schema, table):
    """
    Imports data into a table from a CSV file.
    Expects a file upload with 'Content-Type: multipart/form-data'.
    """
    if 'file' not in request.files:
        return jsonify({"error": "No file part in the request"}), 400

    file = request.files['file']
    if file.filename == '':
        return jsonify({"error": "No selected file"}), 400

    if not file.filename.endswith('.csv'):
        return jsonify({"error": "Invalid file type. Only CSV files are supported."}), 400

    conn = None
    try:
        conn = get_db_connection()
        csv_file_content = StringIO(file.read().decode('utf-8'))
        reader = csv.DictReader(csv_file_content)
        records = []
        for row in reader:
            processed_row = {}
            for k, v in row.items():
                # Convert empty strings to None
                if v == '':
                    processed_row[k] = None
                # Attempt to parse JSONB fields if they are strings
                elif k.endswith('_jsonb') and isinstance(v, str):
                    try:
                        processed_row[k] = json.loads(v)
                    except json.JSONDecodeError:
                        print(f"WARNING: Invalid JSON for field '{k}' in CSV row: {v}. Setting to None.")
                        processed_row[k] = None
                else:
                    processed_row[k] = v
            records.append(processed_row)

        if not records:
            return jsonify({"success": True, "inserted_rows": 0, "message": "CSV file was empty."}), 200

        columns = records[0].keys()
        column_names = ', '.join([f'"{col}"' for col in columns])
        value_placeholders = ', '.join(['%s'] * len(columns))

        data_tuples = []
        for record in records:
            row_values = []
            for col in columns:
                row_values.append(record.get(col)) # Use .get to handle missing columns gracefully (will be None)
            data_tuples.append(tuple(row_values))

        query_template = f"INSERT INTO \"{schema.lower()}\".\"{table.lower()}\" ({column_names}) VALUES %s"

        with conn.cursor() as cur:
            print(f"Executing CSV import query for {len(data_tuples)} records into {schema}.{table}")
            psycopg2.extras.execute_values(cur, query_template, data_tuples)
            conn.commit()
        return jsonify({"success": True, "inserted_rows": len(records), "message": f"Successfully imported {len(records)} records."}), 201
    except psycopg2.errors.UniqueViolation as e:
        if conn:
            conn.rollback()
        print(f"Unique violation error during CSV import for {schema}.{table}: {e}")
        return jsonify({"success": False, "error": f"CSV import failed due to unique constraint violation. Details: {e.diag.message_detail}"}), 409
    except psycopg2.errors.ForeignKeyViolation as e:
        if conn:
            conn.rollback()
        print(f"Foreign key violation error during CSV import for {schema}.{table}: {e}")
        return jsonify({"success": False, "error": f"CSV import failed due to foreign key violation. Ensure all referenced IDs exist. Details: {e.diag.message_detail}"}), 400
    except Exception as e:
        if conn:
            conn.rollback()
        print(f"Error during CSV import for {schema}.{table}: {e}")
        return jsonify({"success": False, "error": str(e)}), 500
    finally:
        if conn:
            conn.close()


@app.route('/mymglab/api/generate_pdf_from_html', methods=['POST'])
@login_required # Protect this endpoint
def generate_pdf_from_html():
    """
    Generates a PDF from HTML content provided in the request body.
    Note: ReportLab is a low-level PDF library. Complex HTML/CSS rendering might be limited.
    """
    html_content = request.get_data(as_text=True) # Get raw HTML content from body

    if not html_content:
        return jsonify({"error": "No HTML content provided in the request body."}), 400

    buffer = BytesIO()
    doc = SimpleDocTemplate(buffer, pagesize=letter)
    styles = getSampleStyleSheet()
    story = []

    # Simple parsing: Treat each line as a paragraph for basic text rendering
    # For more complex HTML, you'd need a dedicated HTML parser and layout engine.
    for line in html_content.splitlines():
        line = line.strip()
        if line:
            # Basic attempt to handle simple HTML tags like <h1>, <p>, <strong>
            # This is highly simplified and will not render full HTML/CSS.
            if line.startswith('<h1'):
                story.append(Paragraph(line.replace('<h1>','').replace('</h1>',''), styles['h1']))
            elif line.startswith('<h2'):
                story.append(Paragraph(line.replace('<h2>','').replace('</h2>',''), styles['h2']))
            elif line.startswith('<p'):
                story.append(Paragraph(line.replace('<p>','').replace('</p>',''), styles['Normal']))
            elif line.startswith('<strong'):
                story.append(Paragraph(line.replace('<strong>','').replace('</strong>',''), styles['Code'])) # Using Code style for bold
            else:
                story.append(Paragraph(line, styles['Normal']))
            story.append(Spacer(1, 0.2 * inch)) # Add some space after each line/paragraph

    try:
        doc.build(story)
        pdf_output = buffer.getvalue()
        buffer.close()

        response = make_response(pdf_output)
        response.headers["Content-Disposition"] = "attachment; filename=generated_document.pdf"
        response.headers["Content-Type"] = "application/pdf"
        return response
    except Exception as e:
        print(f"Error generating PDF: {e}")
        return jsonify({"error": f"Failed to generate PDF: {str(e)}"}), 500


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
    host = '0.0.0.0'
    port = 5200

    print("="*60 + f"\n TIFI LIMS Backend Server ".center(60, "=") + "\n" + "="*60)
    print(f" -> Serving LIMS frontend from: {os.path.abspath(STATIC_FOLDER)}")
    print(f" -> API listening on http://{host}:{port}/mymglab/api/")
    print(f" -> Access the UI at http://127.0.0.1:{port}")
    print("="*60)

    if FLASK_ENV == "development":
        app.run(host=host, port=port, debug=True)
    else:
        serve(app, host=host, port=port)
