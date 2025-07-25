import os
import psycopg2
import psycopg2.extras
import bcrypt
from flask import Flask, jsonify, request, send_from_directory, redirect, url_for
from flask_cors import CORS
from waitress import serve

DB_HOST = "134.110.12.161"
DB_NAME = "MG_lab"
DB_USER = "kasmi"
DB_PASS = "password"
FLASK_ENV="production"

STATIC_FOLDER = '.'
app = Flask(__name__, static_folder=STATIC_FOLDER)
CORS(app) 

def get_db_connection():
    try:
        conn = psycopg2.connect(host=DB_HOST, database=DB_NAME, user=DB_USER, password=DB_PASS)
        return conn
    except psycopg2.OperationalError as e:
        print(f"FATAL: Could not connect to database at {DB_HOST}. Error: {e}")
        raise

def get_pk_column(schema, table):
    """Determines the primary key column for a given table."""
    special_cases = {
        ('Lab', 'Fish'): 'sample_id', 
        ('Lab', 'Tissue'): 'sample_id',
        ('Lab', 'DNA'): 'sample_id', 
        ('Lab', 'RNA'): 'sample_id',
        ('Lab', 'Sediments'): 'sample_id', 
        ('Lab', 'Water'): 'sample_id',
        ('Lims', 'Projects'): 'project_id',
        ('Lab', 'Experiments'): 'Experiment_Nr',
        ('Lab', 'Library'): 'Library_id',
        ('Lab', 'Sequencing'): 'sequencing_id'
    }
    return special_cases.get((schema.capitalize(), table), 'nr')

# =================================================================
# API ENDPOINTS
# =================================================================

@app.route('/api/login', methods=['POST'])
def login_user():
    data = request.get_json()
    person_id = data.get('person_id')
    password = data.get('password')

    if person_id == 'demo' and password == 'password':
        return jsonify({"success": True, "user": {"person": "Demo User", "person_id": "demo"}})

    query = 'SELECT * FROM "Reference"."Personal" WHERE person_id = %s;'
    conn = get_db_connection()
    try:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute(query, (person_id,))
            user = cur.fetchone()
        
        if user and user.get('password_hash') and bcrypt.checkpw(password.encode('utf-8'), user['password_hash'].encode('utf-8')):
            user.pop('password_hash', None)
            return jsonify({"success": True, "user": user})
        else:
            return jsonify({"error": "Invalid credentials"}), 401
    except Exception as e:
        return jsonify({"error": str(e)}), 500
    finally:
        conn.close()

@app.route('/api/global-search/<string:search_term>', methods=['GET'])
def global_search(search_term):
    """Searches across multiple tables for a given term."""
    search_pattern = f"%{search_term}%"
    results = {}
    
    queries = {
        "projects": ('SELECT project_id, "Title" FROM "Lims"."Projects" WHERE project_id ILIKE %s OR "Title" ILIKE %s LIMIT 5', (search_pattern, search_pattern)),
        "samples": ('SELECT sample_id, sample_type, workflow_status_id FROM "Lab"."Samples" WHERE sample_id ILIKE %s LIMIT 5', (search_pattern,)),
        "experiments": ('SELECT "Experiment_Nr", "Experiment_title" FROM "Lab"."Experiments" WHERE "Experiment_Nr" ILIKE %s OR "Experiment_title" ILIKE %s LIMIT 5', (search_pattern, search_pattern)),
    }
    
    conn = get_db_connection()
    try:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            for key, (query, params) in queries.items():
                cur.execute(query, params)
                results[key] = cur.fetchall()
        return jsonify(results)
    except Exception as e:
        return jsonify({"error": str(e)}), 500
    finally:
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
    conn = get_db_connection()
    try:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute(query)
            stats = cur.fetchone()
        return jsonify(stats)
    except Exception as e:
        return jsonify({"error": str(e)}), 500
    finally:
        conn.close()


# --- GENERIC TABLE ENDPOINTS ---

@app.route('/api/table/<string:schema>/<string:table>', methods=['GET'])
def get_table_data(schema, table):
    """Generic function to fetch all data from a table, handling binary data."""
    query = f'SELECT * FROM "{schema.capitalize()}"."{table}"'
    conn = get_db_connection()
    try:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute(query)
            data = cur.fetchall()
            # ** FIX: Handle binary data (bytea) before sending as JSON **
            for row in data:
                if 'attachment' in row and isinstance(row['attachment'], memoryview):
                    row['attachment'] = f"<Attached File: {len(row['attachment'])} bytes>"
                if 'Attachment' in row and isinstance(row['Attachment'], memoryview):
                    row['Attachment'] = f"<Attached File: {len(row['Attachment'])} bytes>"
        return jsonify(data)
    except Exception as e:
        return jsonify({"error": str(e)}), 500
    finally: 
        conn.close()
    
@app.route('/api/table/<string:schema>/<string:table>', methods=['POST'])
def create_record(schema, table):
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
    elif 'attachment' in data:
        del data['attachment']
        
    filtered_data = {k: v for k, v in data.items() if v is not None and v != ''}
    columns = filtered_data.keys()
    values = list(filtered_data.values())
    column_names = ', '.join([f'"{col}"' for col in columns])
    value_placeholders = ', '.join(['%s'] * len(values))
    
    query = f'INSERT INTO "{schema.capitalize()}"."{table}" ({column_names}) VALUES ({value_placeholders}) RETURNING *;'
    conn = get_db_connection()
    try:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute(query, values)
            new_record = cur.fetchone()
            conn.commit()
        return jsonify(new_record), 201
    except Exception as e: 
        conn.rollback()
        return jsonify({"error": str(e)}), 500
    finally: 
        conn.close()

@app.route('/api/table/<string:schema>/<string:table>/<string:pk_value>', methods=['PUT'])
def update_record(schema, table, pk_value):
    pk_column = get_pk_column(schema, table)
    data = request.get_json()
    if not data: 
        return jsonify({"error": "No data provided"}), 400
        
    set_clause = ', '.join([f'"{key}" = %s' for key in data.keys()])
    values = list(data.values())
    try: 
        values.append(int(pk_value) if pk_column == 'nr' else pk_value)
    except ValueError: 
        return jsonify({"error": f"Invalid ID format: {pk_value}"}), 400
        
    query = f'UPDATE "{schema.capitalize()}"."{table}" SET {set_clause} WHERE "{pk_column}" = %s RETURNING *;'
    conn = get_db_connection()
    try:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute(query, values)
            updated_record = cur.fetchone()
            conn.commit()
        return jsonify(updated_record) if updated_record else (jsonify({"error": "Record not found"}), 404)
    except Exception as e: 
        conn.rollback()
        return jsonify({"error": str(e)}), 500
    finally: 
        conn.close()

@app.route('/api/table/<string:schema>/<string:table>/<string:pk_value>', methods=['DELETE'])
def delete_record(schema, table, pk_value):
    pk_column = get_pk_column(schema, table)
    query = f'DELETE FROM "{schema.capitalize()}"."{table}" WHERE "{pk_column}" = %s;'
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(query, (int(pk_value) if pk_column == 'nr' else pk_value,))
            conn.commit()
            if cur.rowcount == 0: 
                return jsonify({"error": "Record not found"}), 404
        return "", 204
    except Exception as e: 
        conn.rollback()
        return jsonify({"error": str(e)}), 500
    finally: 
        conn.close()

@app.route('/api/table/<string:schema>/<string:table>/batch_upload', methods=['POST'])
def batch_upload(schema, table):
    records = request.get_json()
    if not records or not isinstance(records, list): 
        return jsonify({"error": "Invalid data format."}), 400
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            columns = [col for col in records[0].keys()]
            column_names = ', '.join([f'"{col}"' for col in columns])
            query_template = f"INSERT INTO \"{schema.capitalize()}\".\"{table}\" ({column_names}) VALUES %s"
            
            # ** FIX: Convert empty strings to None (NULL) for database insertion **
            data_tuples = []
            for record in records:
                row = []
                for col in columns:
                    val = record.get(col)
                    row.append(None if val == '' else val)
                data_tuples.append(tuple(row))

            psycopg2.extras.execute_values(cur, query_template, data_tuples)
            conn.commit()
        return jsonify({"success": True, "inserted_rows": len(records)})
    except Exception as e:
        if conn: 
            conn.rollback()
        return jsonify({"success": False, "error": str(e)}), 500
    finally:
        if conn: 
            conn.close()

# =================================================================
# STATIC FILE SERVING & ROOT
# =================================================================
@app.route('/')
def root(): 
    return redirect(url_for('serve_static', filename='login.html'))

@app.route('/<path:filename>')
def serve_static(filename):
    return send_from_directory(app.static_folder, filename)

# =================================================================
# RUN THE SERVER
# =================================================================
if __name__ == '__main__':
    host = '0.0.0.0'
    port = 5200
    print("="*60 + f"\n TIFI LIMS Production-Ready Backend Server ".center(60, "=") + "\n" + "="*60)
    print(f" -> Serving LIMS frontend from: {os.path.abspath(STATIC_FOLDER)}")
    print(f" -> API listening on http://{host}:{port}/api/")
    print(f" -> Access the UI at http://127.0.0.1:{port}")
    print("="*60)
    serve(app, host=host, port=port)
