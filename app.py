from flask import Flask, request, jsonify, session, send_from_directory, redirect, url_for, g
from flask_cors import CORS
from waitress import serve
import os
import bcrypt
import base64
import json
import uuid
import decimal
from typing import Any, Dict, List, Optional, Tuple, Union
from datetime import datetime, timedelta, time, date
import psycopg2
from psycopg2 import sql, extras

# --- Configuration ---
# Main LIMS Database (mylims V5)
DB_HOST: str = os.getenv('DB_HOST', '0.0.0.0') 
DB_NAME: str = os.getenv('DB_NAME', 'mylims') # V5 Database
DB_USER: str = os.getenv('DB_USER', 'kasmi') # Ensure this user has access to V5 schemas
DB_PASS: str = os.getenv('DB_PASS', 'password')

# Secondary Authentication Database (musr)
# Preserved from V4 architecture. 
AUTH_DB_HOST: str = os.getenv('AUTH_DB_HOST', '0.0.0.0')
AUTH_DB_NAME: str = os.getenv('AUTH_DB_NAME', 'musr')
AUTH_DB_USER: str = os.getenv('AUTH_DB_USER', 'auth_user')
AUTH_DB_PASS: str = os.getenv('AUTH_DB_PASS', 'auth_password')

SECRET_KEY: str = os.getenv('SECRET_KEY', 'CHANGEME_IN_PRODUCTION_' + str(uuid.uuid4()))
STATIC_FOLDER: str = os.getenv('STATIC_FOLDER', 'static')

# Schemas introduced in MyLims V5
# We explicitly whitelist these to prevent access to system schemas
ALLOWED_SCHEMAS = {
    'reference', 
    'core', 
    'lims', 
    'field', 
    'bio_assets', 
    'moleculargenetics', 
    'bioinformatics', 
    'inventory', 
    'finance', 
    'audit', 
    'projects'
}

app = Flask(__name__, static_folder=STATIC_FOLDER)
app.secret_key = SECRET_KEY
CORS(app, supports_credentials=True) # Enable CORS for frontend development

# --- Custom JSON Encoder for V5 Data Types ---
class CustomJSONEncoder(json.JSONEncoder):
    """
    Handles serialization of PostgreSQL V5 specific types:
    - UUIDs (used extensively in V5)
    - Datetime/Date
    - Decimals
    - Bytes (e.g., geometry/blob)
    """
    def default(self, obj):
        if isinstance(obj, uuid.UUID):
            return str(obj)
        if isinstance(obj, (datetime, date, time)):
            return obj.isoformat()
        if isinstance(obj, decimal.Decimal):
            return float(obj)
        if isinstance(obj, bytes):
            # Attempt to decode bytes to utf-8, fallback to base64 or skip
            try:
                return obj.decode('utf-8')
            except:
                return "<binary_data>" # Placeholder for non-text binary
        return super().default(obj)

# Assign the custom encoder to the app
app.json_encoder = CustomJSONEncoder

# --- Database Connection Helpers ---

def get_db_connection():
    """Connects to the main mylims V5 database."""
    try:
        conn = psycopg2.connect(
            host=DB_HOST,
            database=DB_NAME,
            user=DB_USER,
            password=DB_PASS
        )
        # Register UUID adapter globally for this connection
        extras.register_uuid()
        return conn
    except Exception as e:
        print(f"Error connecting to Main DB ({DB_NAME}): {e}")
        return None

def get_auth_db_connection():
    """Connects to the authentication database (musr)."""
    try:
        conn = psycopg2.connect(
            host=AUTH_DB_HOST,
            database=AUTH_DB_NAME,
            user=AUTH_DB_USER,
            password=AUTH_DB_PASS
        )
        return conn
    except Exception as e:
        print(f"Error connecting to Auth DB ({AUTH_DB_NAME}): {e}")
        return None

# --- Utility Functions ---

def get_pk_column(schema: str, table: str) -> Optional[str]:
    """
    Detects the Primary Key column for a table.
    Works with V5's UUID keys and standard integer keys.
    """
    conn = get_db_connection()
    if not conn:
        return None
    try:
        with conn.cursor() as cursor:
            # Query information_schema for the PK constraint
            cursor.execute("""
                SELECT kcu.column_name
                FROM information_schema.table_constraints tc
                JOIN information_schema.key_column_usage kcu
                  ON tc.constraint_name = kcu.constraint_name
                  AND tc.table_schema = kcu.table_schema
                WHERE tc.constraint_type = 'PRIMARY KEY'
                  AND tc.table_schema = %s
                  AND tc.table_name = %s
                LIMIT 1;
            """, (schema, table))
            result = cursor.fetchone()
            return result[0] if result else None
    except Exception as e:
        print(f"Error getting PK for {schema}.{table}: {e}")
        return None
    finally:
        conn.close()

def is_schema_allowed(schema: str) -> bool:
    """Security check to ensure we only access allowed V5 schemas."""
    return schema in ALLOWED_SCHEMAS

# --- Routes: Authentication ---

@app.route('/login', methods=['POST'])
def login():
    data = request.json
    username = data.get('username')
    password = data.get('password')

    if not username or not password:
        return jsonify({'success': False, 'message': 'Missing credentials'}), 400

    conn = get_auth_db_connection()
    if not conn:
        return jsonify({'success': False, 'message': 'Auth Database Unavailable'}), 500

    try:
        with conn.cursor(cursor_factory=extras.RealDictCursor) as cursor:
            # Check against musr.public.auth_users
            # NOTE: If you migrated auth to mylims.core.users, update this query.
            cursor.execute("SELECT * FROM public.auth_users WHERE username = %s", (username,))
            user = cursor.fetchone()

            if user and bcrypt.checkpw(password.encode('utf-8'), user['password_hash'].encode('utf-8')):
                session['user_id'] = user['user_id']
                session['username'] = user['username']
                session['role'] = user.get('role', 'user')
                return jsonify({'success': True, 'message': 'Login successful', 'role': user.get('role', 'user')})
            else:
                return jsonify({'success': False, 'message': 'Invalid credentials'}), 401
    except Exception as e:
        print(f"Login Error: {e}")
        return jsonify({'success': False, 'message': 'Internal Server Error'}), 500
    finally:
        conn.close()

@app.route('/logout', methods=['POST'])
def logout():
    session.clear()
    return jsonify({'success': True, 'message': 'Logged out'})

@app.route('/get_user_info', methods=['GET'])
def get_user_info():
    if 'user_id' in session:
        return jsonify({
            'logged_in': True, 
            'username': session['username'], 
            'role': session.get('role')
        })
    return jsonify({'logged_in': False})

# --- Routes: Generic Metadata (V5 Compatible) ---

@app.route('/get_tables', methods=['GET'])
def get_tables():
    """
    Returns a dictionary of schemas and their tables.
    Filtered by the V5 ALLOWED_SCHEMAS list.
    """
    conn = get_db_connection()
    if not conn:
        return jsonify({'error': 'Database connection failed'}), 500

    try:
        with conn.cursor() as cursor:
            # Fetch tables only from allowed schemas
            cursor.execute("""
                SELECT table_schema, table_name 
                FROM information_schema.tables 
                WHERE table_schema = ANY(%s)
                ORDER BY table_schema, table_name;
            """, (list(ALLOWED_SCHEMAS),))
            
            rows = cursor.fetchall()
            structure = {}
            for schema, table in rows:
                if schema not in structure:
                    structure[schema] = []
                structure[schema].append(table)
                
            return jsonify(structure)
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()

@app.route('/get_columns/<schema>/<table>', methods=['GET'])
def get_columns(schema, table):
    if not is_schema_allowed(schema):
        return jsonify({'error': 'Schema not allowed'}), 403

    conn = get_db_connection()
    if not conn:
        return jsonify({'error': 'Database connection failed'}), 500

    try:
        with conn.cursor(cursor_factory=extras.RealDictCursor) as cursor:
            # Get standard column info
            cursor.execute("""
                SELECT column_name, data_type, is_nullable, column_default
                FROM information_schema.columns 
                WHERE table_schema = %s AND table_name = %s
                ORDER BY ordinal_position;
            """, (schema, table))
            columns = cursor.fetchall()

            # Get Foreign Key details
            cursor.execute("""
                SELECT
                    kcu.column_name, 
                    ccu.table_schema AS foreign_schema,
                    ccu.table_name AS foreign_table,
                    ccu.column_name AS foreign_column
                FROM information_schema.key_column_usage AS kcu
                JOIN information_schema.referential_constraints AS rc
                    ON kcu.constraint_name = rc.constraint_name
                JOIN information_schema.constraint_column_usage AS ccu
                    ON rc.unique_constraint_name = ccu.constraint_name
                WHERE kcu.table_schema = %s AND kcu.table_name = %s;
            """, (schema, table))
            fks = cursor.fetchall()
            
            # Map FKs for easier frontend consumption
            fk_map = {fk['column_name']: fk for fk in fks}
            
            # Identify PK
            pk_col = get_pk_column(schema, table)

            enriched_columns = []
            for col in columns:
                col_data = dict(col)
                col_data['is_pk'] = (col['column_name'] == pk_col)
                col_data['foreign_key'] = fk_map.get(col['column_name'])
                enriched_columns.append(col_data)

            return jsonify(enriched_columns)
    except Exception as e:
        print(f"Error fetching columns: {e}")
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()

@app.route('/get_dropdown_options', methods=['POST'])
def get_dropdown_options():
    """
    Dynamic dropdown fetcher.
    Upgraded for V5 to better guess "display names" for new schemas.
    """
    data = request.json
    schema = data.get('schema')
    table = data.get('table')
    
    if not schema or not table:
        return jsonify({'error': 'Missing schema or table'}), 400
        
    if not is_schema_allowed(schema):
        return jsonify({'error': 'Schema not allowed'}), 403

    conn = get_db_connection()
    if not conn:
        return jsonify({'error': 'DB Connection failed'}), 500

    try:
        pk_col = get_pk_column(schema, table)
        if not pk_col:
            return jsonify({'error': 'No PK found for table'}), 400

        with conn.cursor(cursor_factory=extras.RealDictCursor) as cursor:
            # 1. Get all column names to find a suitable display column
            cursor.execute(sql.SQL("SELECT * FROM {}.{} LIMIT 1").format(
                sql.Identifier(schema),
                sql.Identifier(table)
            ))
            cols = [desc[0] for desc in cursor.description]
            
            # 2. Heuristics for V5 display name (Priority Order)
            # Checked against common LIMS/Bio patterns
            candidates = [
                'name', 'title', 'label',  # Generic
                'scientific_name', 'taxon_name', # Reference/Bio
                'project_name', # Projects
                'sample_id', 'sample_code', # Bio Assets
                'username', 'fullname', 'lastname', # Core/People
                'instrument_name', 'method_name', # Lims
                'code', 'id' # Fallback
            ]
            
            display_col = pk_col # Default to PK
            for c in candidates:
                if c in cols:
                    display_col = c
                    break
            
            # 3. Handle specific case for People/Users (concat names)
            if 'firstname' in cols and 'lastname' in cols:
                query = sql.SQL("SELECT {} AS value, firstname || ' ' || lastname AS label FROM {}.{} ORDER BY label ASC LIMIT 500").format(
                    sql.Identifier(pk_col),
                    sql.Identifier(schema),
                    sql.Identifier(table)
                )
            else:
                # Standard Query
                query = sql.SQL("SELECT {} AS value, {} AS label FROM {}.{} ORDER BY label ASC LIMIT 500").format(
                    sql.Identifier(pk_col),
                    sql.Identifier(display_col),
                    sql.Identifier(schema),
                    sql.Identifier(table)
                )

            cursor.execute(query)
            options = cursor.fetchall()
            return jsonify(options)

    except Exception as e:
        print(f"Dropdown error for {schema}.{table}: {e}")
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()

# --- Routes: Generic CRUD (V5 Compatible) ---

@app.route('/list_records/<schema>/<table>', methods=['GET'])
def list_records(schema, table):
    if not is_schema_allowed(schema):
        return jsonify({'error': 'Schema not allowed'}), 403

    conn = get_db_connection()
    if not conn:
        return jsonify({'error': 'DB Connection failed'}), 500

    try:
        with conn.cursor(cursor_factory=extras.RealDictCursor) as cursor:
            # Simple select all (limit 1000 for performance)
            query = sql.SQL("SELECT * FROM {}.{} LIMIT 1000").format(
                sql.Identifier(schema),
                sql.Identifier(table)
            )
            cursor.execute(query)
            rows = cursor.fetchall()
            return jsonify(rows) # CustomJSONEncoder handles UUIDs/Dates here
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()

@app.route('/get_record/<schema>/<table>/<pk_value>', methods=['GET'])
def get_record(schema, table, pk_value):
    if not is_schema_allowed(schema):
        return jsonify({'error': 'Schema not allowed'}), 403

    pk_col = get_pk_column(schema, table)
    if not pk_col:
        return jsonify({'error': 'PK not found'}), 400

    conn = get_db_connection()
    try:
        with conn.cursor(cursor_factory=extras.RealDictCursor) as cursor:
            query = sql.SQL("SELECT * FROM {}.{} WHERE {} = %s").format(
                sql.Identifier(schema),
                sql.Identifier(table),
                sql.Identifier(pk_col)
            )
            cursor.execute(query, (pk_value,))
            row = cursor.fetchone()
            if row:
                return jsonify(row)
            return jsonify({'error': 'Record not found'}), 404
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()

@app.route('/add_record/<schema>/<table>', methods=['POST'])
def add_record(schema, table):
    if not is_schema_allowed(schema):
        return jsonify({'error': 'Schema not allowed'}), 403

    data = request.json
    if not data:
        return jsonify({'error': 'No data provided'}), 400

    conn = get_db_connection()
    try:
        # Filter out empty strings for numeric/date fields or let DB handle defaults
        clean_data = {}
        for k, v in data.items():
            if v == "": 
                clean_data[k] = None
            else:
                clean_data[k] = v

        columns = clean_data.keys()
        values = [clean_data[col] for col in columns]

        with conn.cursor() as cursor:
            query = sql.SQL("INSERT INTO {}.{} ({}) VALUES ({}) RETURNING *").format(
                sql.Identifier(schema),
                sql.Identifier(table),
                sql.SQL(', ').join(map(sql.Identifier, columns)),
                sql.SQL(', ').join(sql.Placeholder() * len(columns))
            )
            cursor.execute(query, values)
            conn.commit()
            # Fetch the inserted ID (generic)
            new_id = cursor.fetchone()[0] # Usually the first column or PK
            return jsonify({'success': True, 'id': new_id}), 201
    except Exception as e:
        if conn: conn.rollback()
        print(f"Add Error: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500
    finally:
        if conn: conn.close()

@app.route('/update_record/<schema>/<table>/<pk_value>', methods=['PUT'])
def update_record(schema, table, pk_value):
    if not is_schema_allowed(schema):
        return jsonify({'error': 'Schema not allowed'}), 403

    data = request.json
    pk_col = get_pk_column(schema, table)
    if not pk_col:
        return jsonify({'error': 'PK not found'}), 400

    conn = get_db_connection()
    try:
        clean_data = {k: (None if v == "" else v) for k, v in data.items()}
        
        # Remove PK from update data if present to prevent errors
        if pk_col in clean_data:
            del clean_data[pk_col]

        columns = clean_data.keys()
        values = [clean_data[col] for col in columns]
        values.append(pk_value) # Add PK for WHERE clause

        with conn.cursor() as cursor:
            query = sql.SQL("UPDATE {}.{} SET {} WHERE {} = %s").format(
                sql.Identifier(schema),
                sql.Identifier(table),
                sql.SQL(', ').join([sql.SQL("{} = %s").format(sql.Identifier(k)) for k in columns]),
                sql.Identifier(pk_col)
            )
            cursor.execute(query, values)
            conn.commit()
            return jsonify({'success': True}), 200
    except Exception as e:
        if conn: conn.rollback()
        return jsonify({'success': False, 'error': str(e)}), 500
    finally:
        if conn: conn.close()

# --- Server Entry Point ---

@app.route('/')
def root():
    return redirect(url_for('serve_static', filename='login.html'))

@app.route('/<path:filename>')
def serve_static(filename: str):
    return send_from_directory(app.static_folder, filename)

if __name__ == '__main__':
    host_ip = '0.0.0.0'
    port_num = 5300
    
    print("="*60)
    print(" TIFI LIMS V5 Backend Server ".center(60, "="))
    print(" Compatible with Schema V5 (UUID, Core, BioAssets) ".center(60, "="))
    print("="*60)
    print(f" -> Serving on http://{host_ip}:{port_num}")
    print(f" -> Connecting to Data DB: {DB_NAME} (User: {DB_USER})")
    print(f" -> Connecting to Auth DB: {AUTH_DB_NAME} (User: {AUTH_DB_USER})")
    
    # Use Waitress for production-ready serving
    serve(app, host=host_ip, port=port_num)