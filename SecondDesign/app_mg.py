import os
import json
from datetime import date, datetime
from flask import Flask, request, jsonify, session, send_from_directory
from flask_bcrypt import Bcrypt
from flask_cors import CORS
import psycopg2
from psycopg2 import pool
from psycopg2.extras import RealDictCursor
# Database connection details
# IMPORTANT: For production, use environment variables for sensitive data like passwords.
DB_HOST = os.getenv('DB_HOST', '0.0.0.0') # Use 'localhost' if running DB on same machine and not accessing from other containers
DB_NAME = os.getenv('DB_NAME', 'migfish')
DB_USER = os.getenv('DB_USER', 'kasmi')
DB_PASS = os.getenv('DB_PASS', 'password') # Replace with your actual password or env var

# Static folder for serving frontend files (current directory where app.py is run)
STATIC_FOLDER = '.'
app = Flask(__name__, static_folder=STATIC_FOLDER)

# Initialize Bcrypt for password hashing
bcrypt = Bcrypt(app)

# --- Database Connection Pool ---
# Using a connection pool for better performance with multiple requests
db_pool = None

def init_db_pool():
    global db_pool
    if db_pool is None:
        try:
            db_pool = psycopg2.pool.SimpleConnectionPool(
                minconn=1,
                maxconn=10,
                dsn=app.config['DATABASE_URL']
            )
            print("Database connection pool initialized successfully.")
        except Exception as e:
            print(f"Error initializing database pool: {e}")
            # Exit or handle this critical error appropriately
            exit(1)

# Initialize the pool when the app starts
with app.app_context():
    init_db_pool()

def get_db_connection():
    """Retrieves a connection from the pool."""
    try:
        return db_pool.getconn()
    except Exception as e:
        print(f"Error getting connection from pool: {e}")
        raise

def release_db_connection(conn):
    """Returns a connection to the pool."""
    if conn:
        db_pool.putconn(conn)

def execute_query(query, params=None, fetch_type='none'):
    """
    Executes a database query.
    :param query: SQL query string.
    :param params: Tuple or dict of parameters for the query.
    :param fetch_type: 'one' for single row, 'all' for multiple rows, 'none' for DML.
    :return: Fetched data or None.
    """
    conn = None
    cursor = None
    try:
        conn = get_db_connection()
        # Use RealDictCursor to get results as dictionaries
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        cursor.execute(query, params)
        conn.commit() # Commit changes for DML operations

        if fetch_type == 'one':
            return cursor.fetchone()
        elif fetch_type == 'all':
            return cursor.fetchall()
        else:
            return None
    except Exception as e:
        conn.rollback() # Rollback on error
        print(f"Database query error: {e}")
        raise
    finally:
        if cursor:
            cursor.close()
        if conn:
            release_db_connection(conn)

# --- Helper for JSON serialization of datetime objects ---
def json_serial(obj):
    """JSON serializer for objects not serializable by default json code"""
    if isinstance(obj, (datetime, date)):
        return obj.isoformat()
    raise TypeError ("Type %s not serializable" % type(obj))

# --- API Base URL ---
API_BASE_URL = '/mymglab/api'

# --- Routes for serving HTML files (Static Files) ---
@app.route('/')
def index():
    return send_from_directory(app.static_folder, 'login.html')

@app.route('/<path:filename>')
def static_files(filename):
    # Prevent directory traversal
    if '..' in filename or filename.startswith('/'):
        return "Access Denied", 403
    return send_from_directory(app.static_folder, filename)

# --- Authentication Routes ---
@app.route(f'{API_BASE_URL}/login', methods=['POST'])
def login():
    data = request.get_json()
    person_id = data.get('person_id')
    password = data.get('password')

    if not person_id or not password:
        return jsonify({"success": False, "error": "Missing username or password"}), 400

    try:
        user = execute_query(
            "SELECT person_id, full_name, password_hash FROM reference.personal WHERE person_id = %s",
            (person_id,),
            fetch_type='one'
        )

        if user and bcrypt.check_password_hash(user['password_hash'], password):
            session['logged_in'] = True
            session['user_id'] = user['person_id']
            session['full_name'] = user['full_name']
            return jsonify({"success": True, "message": "Login successful", "user": {"person_id": user['person_id'], "full_name": user['full_name']}}), 200
        else:
            return jsonify({"success": False, "error": "Invalid credentials"}), 401
    except Exception as e:
        print(f"Login error: {e}")
        return jsonify({"success": False, "error": "An internal server error occurred"}), 500

@app.route(f'{API_BASE_URL}/logout', methods=['POST'])
def logout():
    session.pop('logged_in', None)
    session.pop('user_id', None)
    session.pop('full_name', None)
    return jsonify({"success": True, "message": "Logged out successfully"}), 200

# --- Middleware to check authentication for API routes (optional, but good practice) ---
@app.before_request
def check_auth():
    # Allow login, logout, and static files without authentication
    if request.path.startswith(API_BASE_URL) and request.path not in [f'{API_BASE_URL}/login', f'{API_BASE_URL}/logout']:
        if not session.get('logged_in'):
            # For API calls, return JSON error
            if request.is_json:
                return jsonify({"success": False, "error": "Unauthorized. Please log in."}), 401
            # For direct page access, redirect to login (Flask handles this for static files)
            # This part is mostly for server-rendered apps, but good to keep in mind
            pass # Frontend will handle redirect based on API response

# --- Generic Dropdown Data Endpoints ---
@app.route(f'{API_BASE_URL}/persons', methods=['GET'])
def get_persons():
    try:
        persons = execute_query("SELECT person_id, full_name FROM reference.personal ORDER BY full_name", fetch_type='all')
        return jsonify(persons), 200
    except Exception as e:
        print(f"Error fetching persons: {e}")
        return jsonify({"error": "Failed to fetch persons"}), 500

@app.route(f'{API_BASE_URL}/projects', methods=['GET'])
def get_projects():
    try:
        # Join with personal table to get lead person's full name
        projects = execute_query("""
            SELECT p.project_id, p.project_name, p.description, p.start_date, p.end_date, p.status, p.lead_person_id, rp.full_name AS lead_person_name
            FROM lab.projects p
            LEFT JOIN reference.personal rp ON p.lead_person_id = rp.person_id
            ORDER BY p.project_id
        """, fetch_type='all')
        return jsonify(json.loads(json.dumps(projects, default=json_serial))), 200
    except Exception as e:
        print(f"Error fetching projects: {e}")
        return jsonify({"error": "Failed to fetch projects"}), 500

@app.route(f'{API_BASE_URL}/projects', methods=['POST'])
def add_project():
    data = request.get_json()
    try:
        new_project_id = execute_query("""
            INSERT INTO lab.projects (project_name, description, start_date, end_date, status, lead_person_id)
            VALUES (%s, %s, %s, %s, %s, %s) RETURNING project_id
        """, (data['project_name'], data.get('description'), data['start_date'], data.get('end_date'), data['status'], data['lead_person_id']), fetch_type='one')
        return jsonify({"success": True, "message": "Project added successfully!", "project_id": new_project_id['project_id']}), 201
    except Exception as e:
        print(f"Error adding project: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@app.route(f'{API_BASE_URL}/projects/<int:project_id>', methods=['PUT'])
def update_project(project_id):
    data = request.get_json()
    try:
        execute_query("""
            UPDATE lab.projects
            SET project_name = %s, description = %s, start_date = %s, end_date = %s, status = %s, lead_person_id = %s
            WHERE project_id = %s
        """, (data['project_name'], data.get('description'), data['start_date'], data.get('end_date'), data['status'], data['lead_person_id'], project_id))
        return jsonify({"success": True, "message": "Project updated successfully!"}), 200
    except Exception as e:
        print(f"Error updating project: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@app.route(f'{API_BASE_URL}/projects/<int:project_id>', methods=['DELETE'])
def delete_project(project_id):
    try:
        execute_query("DELETE FROM lab.projects WHERE project_id = %s", (project_id,))
        return jsonify({"success": True, "message": "Project deleted successfully!"}), 200
    except Exception as e:
        print(f"Error deleting project: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

# --- Samples Endpoints ---
@app.route(f'{API_BASE_URL}/samples', methods=['GET'])
def get_samples():
    try:
        samples = execute_query("""
            SELECT
                s.sample_id, s.sample_name, s.collection_date, s.quantity, s.unit, s.notes,
                st.sample_type_id, st.type_name,
                ss.status_id, ss.status_name,
                p.project_id, p.project_name,
                e.experiment_id, e.experiment_name,
                sl.storage_location_id, sl.location_name
            FROM lab.samples s
            LEFT JOIN reference.sample_type st ON s.sample_type_id = st.sample_type_id
            LEFT JOIN reference.sample_status ss ON s.status_id = ss.status_id
            LEFT JOIN lab.projects p ON s.project_id = p.project_id
            LEFT JOIN lab.experiments e ON s.experiment_id = e.experiment_id
            LEFT JOIN lab.storage_location sl ON s.storage_location_id = sl.storage_location_id
            ORDER BY s.sample_id
        """, fetch_type='all')
        return jsonify(json.loads(json.dumps(samples, default=json_serial))), 200
    except Exception as e:
        print(f"Error fetching samples: {e}")
        return jsonify({"error": "Failed to fetch samples"}), 500

@app.route(f'{API_BASE_URL}/samples', methods=['POST'])
def add_sample():
    data = request.get_json()
    try:
        new_sample_id = execute_query("""
            INSERT INTO lab.samples (sample_name, sample_type_id, collection_date, status_id, project_id, experiment_id, quantity, unit, storage_location_id, notes)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s) RETURNING sample_id
        """, (data['sample_name'], data['sample_type_id'], data['collection_date'], data['status_id'],
              data.get('project_id'), data.get('experiment_id'), data.get('quantity'), data.get('unit'), data.get('storage_location_id'), data.get('notes')), fetch_type='one')
        return jsonify({"success": True, "message": "Sample added successfully!", "sample_id": new_sample_id['sample_id']}), 201
    except Exception as e:
        print(f"Error adding sample: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@app.route(f'{API_BASE_URL}/samples/<int:sample_id>', methods=['PUT'])
def update_sample(sample_id):
    data = request.get_json()
    try:
        execute_query("""
            UPDATE lab.samples
            SET sample_name = %s, sample_type_id = %s, collection_date = %s, status_id = %s, project_id = %s, experiment_id = %s, quantity = %s, unit = %s, storage_location_id = %s, notes = %s
            WHERE sample_id = %s
        """, (data['sample_name'], data['sample_type_id'], data['collection_date'], data['status_id'],
              data.get('project_id'), data.get('experiment_id'), data.get('quantity'), data.get('unit'), data.get('storage_location_id'), data.get('notes'), sample_id))
        return jsonify({"success": True, "message": "Sample updated successfully!"}), 200
    except Exception as e:
        print(f"Error updating sample: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@app.route(f'{API_BASE_URL}/samples/<int:sample_id>', methods=['DELETE'])
def delete_sample(sample_id):
    try:
        execute_query("DELETE FROM lab.samples WHERE sample_id = %s", (sample_id,))
        return jsonify({"success": True, "message": "Sample deleted successfully!"}), 200
    except Exception as e:
        print(f"Error deleting sample: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@app.route(f'{API_BASE_URL}/sample_types', methods=['GET'])
def get_sample_types():
    try:
        types = execute_query("SELECT sample_type_id, type_name FROM reference.sample_type ORDER BY type_name", fetch_type='all')
        return jsonify(types), 200
    except Exception as e:
        print(f"Error fetching sample types: {e}")
        return jsonify({"error": "Failed to fetch sample types"}), 500

@app.route(f'{API_BASE_URL}/sample_statuses', methods=['GET'])
def get_sample_statuses():
    try:
        statuses = execute_query("SELECT status_id, status_name FROM reference.sample_status ORDER BY status_name", fetch_type='all')
        return jsonify(statuses), 200
    except Exception as e:
        print(f"Error fetching sample statuses: {e}")
        return jsonify({"error": "Failed to fetch sample statuses"}), 500

# --- Sampling Endpoints ---
@app.route(f'{API_BASE_URL}/sampling', methods=['GET'])
def get_sampling_records():
    try:
        records = execute_query("""
            SELECT
                sa.sampling_id, sa.sampling_date, sa.notes,
                s.sample_id, s.sample_name,
                p.project_id, p.project_name,
                e.experiment_id, e.experiment_name,
                rp.person_id, rp.full_name AS person_name
            FROM lab.sampling sa
            LEFT JOIN lab.samples s ON sa.sample_id = s.sample_id
            LEFT JOIN lab.projects p ON s.project_id = p.project_id
            LEFT JOIN lab.experiments e ON s.experiment_id = e.experiment_id
            LEFT JOIN reference.personal rp ON sa.person_id = rp.person_id
            ORDER BY sa.sampling_date DESC
        """, fetch_type='all')
        return jsonify(json.loads(json.dumps(records, default=json_serial))), 200
    except Exception as e:
        print(f"Error fetching sampling records: {e}")
        return jsonify({"error": "Failed to fetch sampling records"}), 500

@app.route(f'{API_BASE_URL}/sampling', methods=['POST'])
def add_sampling_record():
    data = request.get_json()
    try:
        new_id = execute_query("""
            INSERT INTO lab.sampling (sample_id, sampling_date, person_id, notes)
            VALUES (%s, %s, %s, %s) RETURNING sampling_id
        """, (data['sample_id'], data['sampling_date'], data['person_id'], data.get('notes')), fetch_type='one')
        return jsonify({"success": True, "message": "Sampling record added successfully!", "sampling_id": new_id['sampling_id']}), 201
    except Exception as e:
        print(f"Error adding sampling record: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@app.route(f'{API_BASE_URL}/sampling/<int:sampling_id>', methods=['PUT'])
def update_sampling_record(sampling_id):
    data = request.get_json()
    try:
        execute_query("""
            UPDATE lab.sampling
            SET sample_id = %s, sampling_date = %s, person_id = %s, notes = %s
            WHERE sampling_id = %s
        """, (data['sample_id'], data['sampling_date'], data['person_id'], data.get('notes'), sampling_id))
        return jsonify({"success": True, "message": "Sampling record updated successfully!"}), 200
    except Exception as e:
        print(f"Error updating sampling record: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@app.route(f'{API_BASE_URL}/sampling/<int:sampling_id>', methods=['DELETE'])
def delete_sampling_record(sampling_id):
    try:
        execute_query("DELETE FROM lab.sampling WHERE sampling_id = %s", (sampling_id,))
        return jsonify({"success": True, "message": "Sampling record deleted successfully!"}), 200
    except Exception as e:
        print(f"Error deleting sampling record: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

# --- Experiments Endpoints ---
@app.route(f'{API_BASE_URL}/experiments', methods=['GET'])
def get_experiments():
    try:
        experiments = execute_query("""
            SELECT
                e.experiment_id, e.experiment_name, e.description, e.start_date, e.end_date, e.notes,
                es.status_id, es.status_name,
                p.project_id, p.project_name,
                pr.protocol_id, pr.protocol_name,
                pe.person_id, pe.full_name AS person_name,
                m.machine_id, m.machine_name
            FROM lab.experiments e
            LEFT JOIN reference.experiment_status es ON e.status_id = es.status_id
            LEFT JOIN lab.projects p ON e.project_id = p.project_id
            LEFT JOIN lab.protocols pr ON e.protocol_id = pr.protocol_id
            LEFT JOIN reference.personal pe ON e.person_id = pe.person_id
            LEFT JOIN lab.machines m ON e.machine_id = m.machine_id
            ORDER BY e.experiment_id
        """, fetch_type='all')
        return jsonify(json.loads(json.dumps(experiments, default=json_serial))), 200
    except Exception as e:
        print(f"Error fetching experiments: {e}")
        return jsonify({"error": "Failed to fetch experiments"}), 500

@app.route(f'{API_BASE_URL}/experiments', methods=['POST'])
def add_experiment():
    data = request.get_json()
    try:
        new_id = execute_query("""
            INSERT INTO lab.experiments (experiment_name, description, start_date, end_date, status_id, project_id, protocol_id, person_id, machine_id, notes)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s) RETURNING experiment_id
        """, (data['experiment_name'], data.get('description'), data['start_date'], data.get('end_date'), data['status_id'],
              data['project_id'], data.get('protocol_id'), data['person_id'], data.get('machine_id'), data.get('notes')), fetch_type='one')
        return jsonify({"success": True, "message": "Experiment added successfully!", "experiment_id": new_id['experiment_id']}), 201
    except Exception as e:
        print(f"Error adding experiment: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@app.route(f'{API_BASE_URL}/experiments/<int:experiment_id>', methods=['PUT'])
def update_experiment(experiment_id):
    data = request.get_json()
    try:
        execute_query("""
            UPDATE lab.experiments
            SET experiment_name = %s, description = %s, start_date = %s, end_date = %s, status_id = %s, project_id = %s, protocol_id = %s, person_id = %s, machine_id = %s, notes = %s
            WHERE experiment_id = %s
        """, (data['experiment_name'], data.get('description'), data['start_date'], data.get('end_date'), data['status_id'],
              data['project_id'], data.get('protocol_id'), data['person_id'], data.get('machine_id'), data.get('notes'), experiment_id))
        return jsonify({"success": True, "message": "Experiment updated successfully!"}), 200
    except Exception as e:
        print(f"Error updating experiment: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@app.route(f'{API_BASE_URL}/experiments/<int:experiment_id>', methods=['DELETE'])
def delete_experiment(experiment_id):
    try:
        execute_query("DELETE FROM lab.experiments WHERE experiment_id = %s", (experiment_id,))
        return jsonify({"success": True, "message": "Experiment deleted successfully!"}), 200
    except Exception as e:
        print(f"Error deleting experiment: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@app.route(f'{API_BASE_URL}/experiment_statuses', methods=['GET'])
def get_experiment_statuses():
    try:
        statuses = execute_query("SELECT status_id, status_name FROM reference.experiment_status ORDER BY status_name", fetch_type='all')
        return jsonify(statuses), 200
    except Exception as e:
        print(f"Error fetching experiment statuses: {e}")
        return jsonify({"error": "Failed to fetch experiment statuses"}), 500

# --- Protocols Endpoints ---
@app.route(f'{API_BASE_URL}/protocols', methods=['GET'])
def get_protocols():
    try:
        protocols = execute_query("""
            SELECT
                pr.protocol_id, pr.protocol_name, pr.description, pr.version, pr.creation_date, pr.file_path, pr.notes,
                pt.protocol_type_id, pt.type_name,
                pe.person_id, pe.full_name AS person_name
            FROM lab.protocols pr
            LEFT JOIN reference.protocol_type pt ON pr.protocol_type_id = pt.protocol_type_id
            LEFT JOIN reference.personal pe ON pr.person_id = pe.person_id
            ORDER BY pr.protocol_id
        """, fetch_type='all')
        return jsonify(json.loads(json.dumps(protocols, default=json_serial))), 200
    except Exception as e:
        print(f"Error fetching protocols: {e}")
        return jsonify({"error": "Failed to fetch protocols"}), 500

@app.route(f'{API_BASE_URL}/protocols', methods=['POST'])
def add_protocol():
    data = request.get_json()
    try:
        new_id = execute_query("""
            INSERT INTO lab.protocols (protocol_name, protocol_type_id, description, version, creation_date, person_id, file_path, notes)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s) RETURNING protocol_id
        """, (data['protocol_name'], data['protocol_type_id'], data.get('description'), data.get('version'),
              data['creation_date'], data['person_id'], data.get('file_path'), data.get('notes')), fetch_type='one')
        return jsonify({"success": True, "message": "Protocol added successfully!", "protocol_id": new_id['protocol_id']}), 201
    except Exception as e:
        print(f"Error adding protocol: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@app.route(f'{API_BASE_URL}/protocols/<int:protocol_id>', methods=['PUT'])
def update_protocol(protocol_id):
    data = request.get_json()
    try:
        execute_query("""
            UPDATE lab.protocols
            SET protocol_name = %s, protocol_type_id = %s, description = %s, version = %s, creation_date = %s, person_id = %s, file_path = %s, notes = %s
            WHERE protocol_id = %s
        """, (data['protocol_name'], data['protocol_type_id'], data.get('description'), data.get('version'),
              data['creation_date'], data['person_id'], data.get('file_path'), data.get('notes'), protocol_id))
        return jsonify({"success": True, "message": "Protocol updated successfully!"}), 200
    except Exception as e:
        print(f"Error updating protocol: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@app.route(f'{API_BASE_URL}/protocols/<int:protocol_id>', methods=['DELETE'])
def delete_protocol(protocol_id):
    try:
        execute_query("DELETE FROM lab.protocols WHERE protocol_id = %s", (protocol_id,))
        return jsonify({"success": True, "message": "Protocol deleted successfully!"}), 200
    except Exception as e:
        print(f"Error deleting protocol: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@app.route(f'{API_BASE_URL}/protocol_types', methods=['GET'])
def get_protocol_types():
    try:
        types = execute_query("SELECT protocol_type_id, type_name FROM reference.protocol_type ORDER BY type_name", fetch_type='all')
        return jsonify(types), 200
    except Exception as e:
        print(f"Error fetching protocol types: {e}")
        return jsonify({"error": "Failed to fetch protocol types"}), 500

# --- Processing Endpoints ---
@app.route(f'{API_BASE_URL}/processing', methods=['GET'])
def get_processing_records():
    try:
        records = execute_query("""
            SELECT
                pr.processing_id, pr.start_date, pr.end_date, pr.notes,
                s.sample_id, s.sample_name,
                proto.protocol_id, proto.protocol_name,
                m.machine_id, m.machine_name,
                pe.person_id, pe.full_name AS person_name,
                ps.status_id, ps.status_name
            FROM lab.processing pr
            LEFT JOIN lab.samples s ON pr.sample_id = s.sample_id
            LEFT JOIN lab.protocols proto ON pr.protocol_id = proto.protocol_id
            LEFT JOIN lab.machines m ON pr.machine_id = m.machine_id
            LEFT JOIN reference.personal pe ON pr.person_id = pe.person_id
            LEFT JOIN reference.processing_status ps ON pr.status_id = ps.status_id
            ORDER BY pr.processing_id
        """, fetch_type='all')
        return jsonify(json.loads(json.dumps(records, default=json_serial))), 200
    except Exception as e:
        print(f"Error fetching processing records: {e}")
        return jsonify({"error": "Failed to fetch processing records"}), 500

@app.route(f'{API_BASE_URL}/processing', methods=['POST'])
def add_processing_record():
    data = request.get_json()
    try:
        new_id = execute_query("""
            INSERT INTO lab.processing (sample_id, protocol_id, machine_id, person_id, start_date, end_date, status_id, notes)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s) RETURNING processing_id
        """, (data['sample_id'], data['protocol_id'], data['machine_id'], data['person_id'],
              data['start_date'], data.get('end_date'), data['status_id'], data.get('notes')), fetch_type='one')
        return jsonify({"success": True, "message": "Processing record added successfully!", "processing_id": new_id['processing_id']}), 201
    except Exception as e:
        print(f"Error adding processing record: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@app.route(f'{API_BASE_URL}/processing/<int:processing_id>', methods=['PUT'])
def update_processing_record(processing_id):
    data = request.get_json()
    try:
        execute_query("""
            UPDATE lab.processing
            SET sample_id = %s, protocol_id = %s, machine_id = %s, person_id = %s, start_date = %s, end_date = %s, status_id = %s, notes = %s
            WHERE processing_id = %s
        """, (data['sample_id'], data['protocol_id'], data['machine_id'], data['person_id'],
              data['start_date'], data.get('end_date'), data['status_id'], data.get('notes'), processing_id))
        return jsonify({"success": True, "message": "Processing record updated successfully!"}), 200
    except Exception as e:
        print(f"Error updating processing record: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@app.route(f'{API_BASE_URL}/processing/<int:processing_id>', methods=['DELETE'])
def delete_processing_record(processing_id):
    try:
        execute_query("DELETE FROM lab.processing WHERE processing_id = %s", (processing_id,))
        return jsonify({"success": True, "message": "Processing record deleted successfully!"}), 200
    except Exception as e:
        print(f"Error deleting processing record: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@app.route(f'{API_BASE_URL}/processing_statuses', methods=['GET'])
def get_processing_statuses():
    try:
        statuses = execute_query("SELECT status_id, status_name FROM reference.processing_status ORDER BY status_name", fetch_type='all')
        return jsonify(statuses), 200
    except Exception as e:
        print(f"Error fetching processing statuses: {e}")
        return jsonify({"error": "Failed to fetch processing statuses"}), 500

# --- Laboratory Endpoints ---
@app.route(f'{API_BASE_URL}/laboratories', methods=['GET'])
def get_laboratories():
    try:
        labs = execute_query("""
            SELECT
                l.laboratory_id, l.laboratory_name, l.location, l.phone, l.email, l.notes,
                rp.person_id AS contact_person_id, rp.full_name AS contact_person_name
            FROM lab.laboratory l
            LEFT JOIN reference.personal rp ON l.contact_person_id = rp.person_id
            ORDER BY l.laboratory_id
        """, fetch_type='all')
        return jsonify(json.loads(json.dumps(labs, default=json_serial))), 200
    except Exception as e:
        print(f"Error fetching laboratories: {e}")
        return jsonify({"error": "Failed to fetch laboratories"}), 500

@app.route(f'{API_BASE_URL}/laboratories', methods=['POST'])
def add_laboratory():
    data = request.get_json()
    try:
        new_id = execute_query("""
            INSERT INTO lab.laboratory (laboratory_name, location, contact_person_id, phone, email, notes)
            VALUES (%s, %s, %s, %s, %s, %s) RETURNING laboratory_id
        """, (data['laboratory_name'], data.get('location'), data['contact_person_id'],
              data.get('phone'), data.get('email'), data.get('notes')), fetch_type='one')
        return jsonify({"success": True, "message": "Laboratory added successfully!", "laboratory_id": new_id['laboratory_id']}), 201
    except Exception as e:
        print(f"Error adding laboratory: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@app.route(f'{API_BASE_URL}/laboratories/<int:laboratory_id>', methods=['PUT'])
def update_laboratory(laboratory_id):
    data = request.get_json()
    try:
        execute_query("""
            UPDATE lab.laboratory
            SET laboratory_name = %s, location = %s, contact_person_id = %s, phone = %s, email = %s, notes = %s
            WHERE laboratory_id = %s
        """, (data['laboratory_name'], data.get('location'), data['contact_person_id'],
              data.get('phone'), data.get('email'), data.get('notes'), laboratory_id))
        return jsonify({"success": True, "message": "Laboratory updated successfully!"}), 200
    except Exception as e:
        print(f"Error updating laboratory: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@app.route(f'{API_BASE_URL}/laboratories/<int:laboratory_id>', methods=['DELETE'])
def delete_laboratory(laboratory_id):
    try:
        execute_query("DELETE FROM lab.laboratory WHERE laboratory_id = %s", (laboratory_id,))
        return jsonify({"success": True, "message": "Laboratory deleted successfully!"}), 200
    except Exception as e:
        print(f"Error deleting laboratory: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

# --- Workflow Endpoints ---
@app.route(f'{API_BASE_URL}/workflow_steps', methods=['GET'])
def get_workflow_steps():
    try:
        steps = execute_query("""
            SELECT
                ws.workflow_step_id, ws.step_name, ws.description, ws.order_index, ws.estimated_duration_days, ws.notes,
                rp.person_id AS responsible_person_id, rp.full_name AS responsible_person_name
            FROM lab.workflow_steps ws
            LEFT JOIN reference.personal rp ON ws.responsible_person_id = rp.person_id
            ORDER BY ws.order_index
        """, fetch_type='all')
        return jsonify(json.loads(json.dumps(steps, default=json_serial))), 200
    except Exception as e:
        print(f"Error fetching workflow steps: {e}")
        return jsonify({"error": "Failed to fetch workflow steps"}), 500

@app.route(f'{API_BASE_URL}/workflow_steps', methods=['POST'])
def add_workflow_step():
    data = request.get_json()
    try:
        new_id = execute_query("""
            INSERT INTO lab.workflow_steps (step_name, description, order_index, responsible_person_id, estimated_duration_days, notes)
            VALUES (%s, %s, %s, %s, %s, %s) RETURNING workflow_step_id
        """, (data['step_name'], data.get('description'), data.get('order_index'),
              data['responsible_person_id'], data.get('estimated_duration_days'), data.get('notes')), fetch_type='one')
        return jsonify({"success": True, "message": "Workflow step added successfully!", "workflow_step_id": new_id['workflow_step_id']}), 201
    except Exception as e:
        print(f"Error adding workflow step: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@app.route(f'{API_BASE_URL}/workflow_steps/<int:workflow_step_id>', methods=['PUT'])
def update_workflow_step(workflow_step_id):
    data = request.get_json()
    try:
        execute_query("""
            UPDATE lab.workflow_steps
            SET step_name = %s, description = %s, order_index = %s, responsible_person_id = %s, estimated_duration_days = %s, notes = %s
            WHERE workflow_step_id = %s
        """, (data['step_name'], data.get('description'), data.get('order_index'),
              data['responsible_person_id'], data.get('estimated_duration_days'), data.get('notes'), workflow_step_id))
        return jsonify({"success": True, "message": "Workflow step updated successfully!"}), 200
    except Exception as e:
        print(f"Error updating workflow step: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@app.route(f'{API_BASE_URL}/workflow_steps/<int:workflow_step_id>', methods=['DELETE'])
def delete_workflow_step(workflow_step_id):
    try:
        execute_query("DELETE FROM lab.workflow_steps WHERE workflow_step_id = %s", (workflow_step_id,))
        return jsonify({"success": True, "message": "Workflow step deleted successfully!"}), 200
    except Exception as e:
        print(f"Error deleting workflow step: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

# --- Labeling Endpoints ---
@app.route(f'{API_BASE_URL}/labels', methods=['GET'])
def get_labels():
    try:
        labels = execute_query("""
            SELECT
                l.label_id, l.label_text, l.creation_date, l.notes,
                s.sample_id, s.sample_name,
                lt.label_type_id, lt.type_name,
                rp.person_id, rp.full_name AS person_name
            FROM lab.labels l
            LEFT JOIN lab.samples s ON l.sample_id = s.sample_id
            LEFT JOIN reference.label_type lt ON l.label_type_id = lt.label_type_id
            LEFT JOIN reference.personal rp ON l.person_id = rp.person_id
            ORDER BY l.label_id
        """, fetch_type='all')
        return jsonify(json.loads(json.dumps(labels, default=json_serial))), 200
    except Exception as e:
        print(f"Error fetching labels: {e}")
        return jsonify({"error": "Failed to fetch labels"}), 500

@app.route(f'{API_BASE_URL}/labels', methods=['POST'])
def add_label():
    data = request.get_json()
    try:
        new_id = execute_query("""
            INSERT INTO lab.labels (sample_id, label_type_id, label_text, creation_date, person_id, notes)
            VALUES (%s, %s, %s, %s, %s, %s) RETURNING label_id
        """, (data['sample_id'], data['label_type_id'], data['label_text'],
              data['creation_date'], data['person_id'], data.get('notes')), fetch_type='one')
        return jsonify({"success": True, "message": "Label added successfully!", "label_id": new_id['label_id']}), 201
    except Exception as e:
        print(f"Error adding label: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@app.route(f'{API_BASE_URL}/labels/<int:label_id>', methods=['PUT'])
def update_label(label_id):
    data = request.get_json()
    try:
        execute_query("""
            UPDATE lab.labels
            SET sample_id = %s, label_type_id = %s, label_text = %s, creation_date = %s, person_id = %s, notes = %s
            WHERE label_id = %s
        """, (data['sample_id'], data['label_type_id'], data['label_text'],
              data['creation_date'], data['person_id'], data.get('notes'), label_id))
        return jsonify({"success": True, "message": "Label updated successfully!"}), 200
    except Exception as e:
        print(f"Error updating label: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@app.route(f'{API_BASE_URL}/labels/<int:label_id>', methods=['DELETE'])
def delete_label(label_id):
    try:
        execute_query("DELETE FROM lab.labels WHERE label_id = %s", (label_id,))
        return jsonify({"success": True, "message": "Label deleted successfully!"}), 200
    except Exception as e:
        print(f"Error deleting label: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@app.route(f'{API_BASE_URL}/label_types', methods=['GET'])
def get_label_types():
    try:
        types = execute_query("SELECT label_type_id, type_name FROM reference.label_type ORDER BY type_name", fetch_type='all')
        return jsonify(types), 200
    except Exception as e:
        print(f"Error fetching label types: {e}")
        return jsonify({"error": "Failed to fetch label types"}), 500

# --- Machines Endpoints ---
@app.route(f'{API_BASE_URL}/machines', methods=['GET'])
def get_machines():
    try:
        machines = execute_query("SELECT machine_id, machine_name, description, manufacturer, model, serial_number, installation_date, last_maintenance_date, notes FROM lab.machines ORDER BY machine_name", fetch_type='all')
        return jsonify(json.loads(json.dumps(machines, default=json_serial))), 200
    except Exception as e:
        print(f"Error fetching machines: {e}")
        return jsonify({"error": "Failed to fetch machines"}), 500

# --- Storage Endpoints (Combined) ---
@app.route(f'{API_BASE_URL}/storage_locations', methods=['GET'])
def get_storage_locations():
    try:
        locations = execute_query("SELECT storage_location_id, location_name, location_type, capacity, notes FROM lab.storage_location ORDER BY location_name", fetch_type='all')
        return jsonify(locations), 200
    except Exception as e:
        print(f"Error fetching storage locations: {e}")
        return jsonify({"error": "Failed to fetch storage locations"}), 500

@app.route(f'{API_BASE_URL}/storage_locations', methods=['POST'])
def add_storage_location():
    data = request.get_json()
    try:
        new_id = execute_query("""
            INSERT INTO lab.storage_location (location_name, location_type, capacity, notes)
            VALUES (%s, %s, %s, %s) RETURNING storage_location_id
        """, (data['location_name'], data.get('location_type'), data.get('capacity'), data.get('notes')), fetch_type='one')
        return jsonify({"success": True, "message": "Location added successfully!", "storage_location_id": new_id['storage_location_id']}), 201
    except Exception as e:
        print(f"Error adding storage location: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@app.route(f'{API_BASE_URL}/storage_locations/<int:location_id>', methods=['PUT'])
def update_storage_location(location_id):
    data = request.get_json()
    try:
        execute_query("""
            UPDATE lab.storage_location
            SET location_name = %s, location_type = %s, capacity = %s, notes = %s
            WHERE storage_location_id = %s
        """, (data['location_name'], data.get('location_type'), data.get('capacity'), data.get('notes'), location_id))
        return jsonify({"success": True, "message": "Location updated successfully!"}), 200
    except Exception as e:
        print(f"Error updating storage location: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@app.route(f'{API_BASE_URL}/storage_locations/<int:location_id>', methods=['DELETE'])
def delete_storage_location(location_id):
    try:
        execute_query("DELETE FROM lab.storage_location WHERE storage_location_id = %s", (location_id,))
        return jsonify({"success": True, "message": "Location deleted successfully!"}), 200
    except Exception as e:
        print(f"Error deleting storage location: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@app.route(f'{API_BASE_URL}/storage_lagers', methods=['GET'])
def get_storage_lagers():
    try:
        lagers = execute_query("""
            SELECT sl.lager_id, sl.lager_name, sl.capacity, sl.notes,
                   loc.storage_location_id, loc.location_name
            FROM lab.storage_lager sl
            LEFT JOIN lab.storage_location loc ON sl.storage_location_id = loc.storage_location_id
            ORDER BY sl.lager_name
        """, fetch_type='all')
        return jsonify(lagers), 200
    except Exception as e:
        print(f"Error fetching storage lagers: {e}")
        return jsonify({"error": "Failed to fetch storage lagers"}), 500

@app.route(f'{API_BASE_URL}/storage_lagers', methods=['POST'])
def add_storage_lager():
    data = request.get_json()
    try:
        new_id = execute_query("""
            INSERT INTO lab.storage_lager (lager_name, storage_location_id, capacity, notes)
            VALUES (%s, %s, %s, %s) RETURNING lager_id
        """, (data['lager_name'], data['storage_location_id'], data.get('capacity'), data.get('notes')), fetch_type='one')
        return jsonify({"success": True, "message": "Lager added successfully!", "lager_id": new_id['lager_id']}), 201
    except Exception as e:
        print(f"Error adding storage lager: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@app.route(f'{API_BASE_URL}/storage_lagers/<int:lager_id>', methods=['PUT'])
def update_storage_lager(lager_id):
    data = request.get_json()
    try:
        execute_query("""
            UPDATE lab.storage_lager
            SET lager_name = %s, storage_location_id = %s, capacity = %s, notes = %s
            WHERE lager_id = %s
        """, (data['lager_name'], data['storage_location_id'], data.get('capacity'), data.get('notes'), lager_id))
        return jsonify({"success": True, "message": "Lager updated successfully!"}), 200
    except Exception as e:
        print(f"Error updating storage lager: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@app.route(f'{API_BASE_URL}/storage_lagers/<int:lager_id>', methods=['DELETE'])
def delete_storage_lager(lager_id):
    try:
        execute_query("DELETE FROM lab.storage_lager WHERE lager_id = %s", (lager_id,))
        return jsonify({"success": True, "message": "Lager deleted successfully!"}), 200
    except Exception as e:
        print(f"Error deleting storage lager: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@app.route(f'{API_BASE_URL}/storage_boxes', methods=['GET'])
def get_storage_boxes():
    try:
        boxes = execute_query("""
            SELECT sb.box_id, sb.box_name, sb.capacity, sb.notes,
                   sl.lager_id, sl.lager_name
            FROM lab.storage_box sb
            LEFT JOIN lab.storage_lager sl ON sb.lager_id = sl.lager_id
            ORDER BY sb.box_name
        """, fetch_type='all')
        return jsonify(boxes), 200
    except Exception as e:
        print(f"Error fetching storage boxes: {e}")
        return jsonify({"error": "Failed to fetch storage boxes"}), 500

@app.route(f'{API_BASE_URL}/storage_boxes', methods=['POST'])
def add_storage_box():
    data = request.get_json()
    try:
        new_id = execute_query("""
            INSERT INTO lab.storage_box (box_name, lager_id, capacity, notes)
            VALUES (%s, %s, %s, %s) RETURNING box_id
        """, (data['box_name'], data['lager_id'], data.get('capacity'), data.get('notes')), fetch_type='one')
        return jsonify({"success": True, "message": "Box added successfully!", "box_id": new_id['box_id']}), 201
    except Exception as e:
        print(f"Error adding storage box: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@app.route(f'{API_BASE_URL}/storage_boxes/<int:box_id>', methods=['PUT'])
def update_storage_box(box_id):
    data = request.get_json()
    try:
        execute_query("""
            UPDATE lab.storage_box
            SET box_name = %s, lager_id = %s, capacity = %s, notes = %s
            WHERE box_id = %s
        """, (data['box_name'], data['lager_id'], data.get('capacity'), data.get('notes'), box_id))
        return jsonify({"success": True, "message": "Box updated successfully!"}), 200
    except Exception as e:
        print(f"Error updating storage box: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@app.route(f'{API_BASE_URL}/storage_boxes/<int:box_id>', methods=['DELETE'])
def delete_storage_box(box_id):
    try:
        execute_query("DELETE FROM lab.storage_box WHERE box_id = %s", (box_id,))
        return jsonify({"success": True, "message": "Box deleted successfully!"}), 200
    except Exception as e:
        print(f"Error deleting storage box: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@app.route(f'{API_BASE_URL}/stored_samples', methods=['GET'])
def get_stored_samples():
    try:
        stored_samples = execute_query("""
            SELECT
                sts.stored_sample_id, sts.position, sts.storage_date, sts.notes,
                s.sample_id, s.sample_name,
                loc.storage_location_id, loc.location_name,
                box.box_id, box.box_name
            FROM lab.stored_sample sts
            LEFT JOIN lab.samples s ON sts.sample_id = s.sample_id
            LEFT JOIN lab.storage_location loc ON sts.storage_location_id = loc.storage_location_id
            LEFT JOIN lab.storage_box box ON sts.box_id = box.box_id
            ORDER BY sts.stored_sample_id
        """, fetch_type='all')
        return jsonify(json.loads(json.dumps(stored_samples, default=json_serial))), 200
    except Exception as e:
        print(f"Error fetching stored samples: {e}")
        return jsonify({"error": "Failed to fetch stored samples"}), 500

@app.route(f'{API_BASE_URL}/stored_samples', methods=['POST'])
def add_stored_sample():
    data = request.get_json()
    try:
        new_id = execute_query("""
            INSERT INTO lab.stored_sample (sample_id, storage_location_id, box_id, position, storage_date, notes)
            VALUES (%s, %s, %s, %s, %s, %s) RETURNING stored_sample_id
        """, (data['sample_id'], data['storage_location_id'], data.get('box_id'),
              data.get('position'), data['storage_date'], data.get('notes')), fetch_type='one')
        return jsonify({"success": True, "message": "Stored sample added successfully!", "stored_sample_id": new_id['stored_sample_id']}), 201
    except Exception as e:
        print(f"Error adding stored sample: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@app.route(f'{API_BASE_URL}/stored_samples/<int:stored_sample_id>', methods=['PUT'])
def update_stored_sample(stored_sample_id):
    data = request.get_json()
    try:
        execute_query("""
            UPDATE lab.stored_sample
            SET sample_id = %s, storage_location_id = %s, box_id = %s, position = %s, storage_date = %s, notes = %s
            WHERE stored_sample_id = %s
        """, (data['sample_id'], data['storage_location_id'], data.get('box_id'),
              data.get('position'), data['storage_date'], data.get('notes'), stored_sample_id))
        return jsonify({"success": True, "message": "Stored sample updated successfully!"}), 200
    except Exception as e:
        print(f"Error updating stored sample: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@app.route(f'{API_BASE_URL}/stored_samples/<int:stored_sample_id>', methods=['DELETE'])
def delete_stored_sample(stored_sample_id):
    try:
        execute_query("DELETE FROM lab.stored_sample WHERE stored_sample_id = %s", (stored_sample_id,))
        return jsonify({"success": True, "message": "Stored sample deleted successfully!"}), 200
    except Exception as e:
        print(f"Error deleting stored sample: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

# --- Dashboard Metrics (Placeholder Implementations) ---
@app.route(f'{API_BASE_URL}/metrics/total_samples', methods=['GET'])
def get_total_samples():
    try:
        result = execute_query("SELECT COUNT(*) FROM lab.samples", fetch_type='one')
        return jsonify({"count": result['count'] if result else 0}), 200
    except Exception as e:
        print(f"Error fetching total samples metric: {e}")
        return jsonify({"error": "Failed to fetch total samples"}), 500

@app.route(f'{API_BASE_URL}/metrics/ongoing_experiments', methods=['GET'])
def get_ongoing_experiments():
    try:
        # Assuming 'Ongoing' is a status name in reference.experiment_status
        result = execute_query("""
            SELECT COUNT(*) FROM lab.experiments e
            JOIN reference.experiment_status es ON e.status_id = es.status_id
            WHERE es.status_name = 'Ongoing'
        """, fetch_type='one')
        return jsonify({"count": result['count'] if result else 0}), 200
    except Exception as e:
        print(f"Error fetching ongoing experiments metric: {e}")
        return jsonify({"error": "Failed to fetch ongoing experiments"}), 500

@app.route(f'{API_BASE_URL}/metrics/pending_tasks', methods=['GET'])
def get_pending_tasks():
    try:
        # This assumes a 'lab.tasks' table or similar, or you define what a 'task' is.
        # For now, let's assume it refers to processing records with 'Pending' status.
        result = execute_query("""
            SELECT COUNT(*) FROM lab.processing p
            JOIN reference.processing_status ps ON p.status_id = ps.status_id
            WHERE ps.status_name = 'Pending'
        """, fetch_type='one')
        return jsonify({"count": result['count'] if result else 0}), 200
    except Exception as e:
        print(f"Error fetching pending tasks metric: {e}")
        return jsonify({"error": "Failed to fetch pending tasks"}), 500

@app.route(f'{API_BASE_URL}/activity/recent', methods=['GET'])
def get_recent_activity():
    try:
        # This is a simplified example. In a real LIMS, you'd query an audit log or combine recent changes from multiple tables.
        # Example: Fetching last 5 sample additions and experiment completions
        recent_activities = execute_query("""
            (SELECT
                'sample_added' AS type,
                'Sample ID: ' || s.sample_id || ' (' || s.sample_name || ') added by ' || rp.full_name || '.' AS description,
                s.collection_date AS activity_date
            FROM lab.samples s
            LEFT JOIN reference.personal rp ON s.person_id = rp.person_id -- Assuming a person_id in samples
            ORDER BY s.collection_date DESC LIMIT 3)
            UNION ALL
            (SELECT
                'experiment_completed' AS type,
                'Experiment: ' || e.experiment_name || ' completed.' AS description,
                e.end_date AS activity_date
            FROM lab.experiments e
            JOIN reference.experiment_status es ON e.status_id = es.status_id
            WHERE es.status_name = 'Completed'
            ORDER BY e.end_date DESC LIMIT 2)
            ORDER BY activity_date DESC
        """, fetch_type='all')

        # Add 'time_ago' logic client-side or here if needed. For simplicity, we'll just return date.
        # The frontend will format 'time_ago' based on 'activity_date'
        return jsonify(json.loads(json.dumps(recent_activities, default=json_serial))), 200
    except Exception as e:
        print(f"Error fetching recent activity: {e}")
        return jsonify({"error": "Failed to fetch recent activity"}), 500

@app.route(f'{API_BASE_URL}/tasks/upcoming', methods=['GET'])
def get_upcoming_tasks():
    try:
        # This is a placeholder. You would query your actual task management table.
        # For now, let's return some hardcoded mock data or query processing records with a future end_date.
        # Assuming tasks are processing records that are 'Pending' and have a start_date in the near future.
        upcoming_tasks = execute_query("""
            SELECT
                pr.processing_id AS task_id,
                pr.notes AS description,
                pr.start_date AS due_date,
                p.project_name
            FROM lab.processing pr
            LEFT JOIN reference.processing_status ps ON pr.status_id = ps.status_id
            LEFT JOIN lab.samples s ON pr.sample_id = s.sample_id
            LEFT JOIN lab.projects p ON s.project_id = p.project_id
            WHERE ps.status_name = 'Pending' AND pr.start_date >= CURRENT_DATE
            ORDER BY pr.start_date ASC LIMIT 5
        """, fetch_type='all')

        # Add due_date_text and due_status logic
        formatted_tasks = []
        today = date.today()
        for task in upcoming_tasks:
            task_date = task['due_date']
            due_status = 'future'
            due_date_text = task_date.isoformat() # Default
            if task_date == today:
                due_status = 'today'
                due_date_text = 'Due Today'
            elif task_date == today + timedelta(days=1):
                due_status = 'tomorrow'
                due_date_text = 'Tomorrow'
            elif task_date < today: # Should not happen with WHERE clause, but for robustness
                due_status = 'past'
                due_date_text = 'Overdue'

            formatted_tasks.append({
                "task_id": task['task_id'],
                "description": task['description'],
                "due_date": task['due_date'].isoformat(),
                "project_name": task['project_name'] if task['project_name'] else 'N/A',
                "due_status": due_status,
                "due_date_text": due_date_text
            })
        return jsonify(formatted_tasks), 200
    except Exception as e:
        print(f"Error fetching upcoming tasks: {e}")
        return jsonify({"error": "Failed to fetch upcoming tasks"}), 500

# Dashboard Chart Data Endpoints
@app.route(f'{API_BASE_URL}/charts/samples_processed', methods=['GET'])
def get_samples_processed_chart_data():
    try:
        # Example: Samples processed per month (assuming collection_date is relevant)
        chart_data = execute_query("""
            SELECT
                TO_CHAR(collection_date, 'YYYY-MM') AS month,
                COUNT(*) AS count
            FROM lab.samples
            WHERE collection_date IS NOT NULL
            GROUP BY month
            ORDER BY month ASC
            LIMIT 6 -- Last 6 months
        """, fetch_type='all')

        labels = [d['month'] for d in chart_data]
        data = [d['count'] for d in chart_data]

        return jsonify({
            "labels": labels,
            "datasets": [{
                "label": "Samples Processed",
                "data": data
            }]
        }), 200
    except Exception as e:
        print(f"Error fetching samples processed chart data: {e}")
        return jsonify({"error": "Failed to fetch chart data"}), 500

@app.route(f'{API_BASE_URL}/charts/experiment_success_rate', methods=['GET'])
def get_experiment_success_rate_chart_data():
    try:
        # Assuming 'Completed' and 'Aborted' are status names in reference.experiment_status
        total_experiments = execute_query("SELECT COUNT(*) FROM lab.experiments", fetch_type='one')['count']
        completed_experiments = execute_query("""
            SELECT COUNT(*) FROM lab.experiments e
            JOIN reference.experiment_status es ON e.status_id = es.status_id
            WHERE es.status_name = 'Completed'
        """, fetch_type='one')['count']
        aborted_experiments = execute_query("""
            SELECT COUNT(*) FROM lab.experiments e
            JOIN reference.experiment_status es ON e.status_id = es.status_id
            WHERE es.status_name = 'Aborted'
        """, fetch_type='one')['count']

        success_rate = (completed_experiments / total_experiments * 100) if total_experiments > 0 else 0
        failure_rate = (aborted_experiments / total_experiments * 100) if total_experiments > 0 else 0
        other_rate = 100 - success_rate - failure_rate # For other statuses like 'Ongoing', 'Planned'

        return jsonify({
            "labels": ["Success", "Failure", "Other"],
            "datasets": [{
                "label": "Experiment Outcomes",
                "data": [round(success_rate, 2), round(failure_rate, 2), round(other_rate, 2)]
            }]
        }), 200
    except Exception as e:
        print(f"Error fetching experiment success rate chart data: {e}")
        return jsonify({"error": "Failed to fetch chart data"}), 500


if __name__ == '__main__':
    # For development, run with debug=True. In production, use a WSGI server (e.g., Gunicorn)
    # Ensure you have set the DATABASE_URL and FLASK_SECRET_KEY environment variables
    # Example:
    # export DATABASE_URL="postgresql://youruser:yourpassword@yourhost:5432/yourdatabase"
    # export FLASK_SECRET_KEY="a_very_long_and_random_secret_key"
    app.run(debug=True, port=5200)