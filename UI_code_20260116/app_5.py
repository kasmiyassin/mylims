import os
import sys
import json
import uuid
import math
import time
import logging
import traceback
import bcrypt
import base64
import re
from datetime import datetime, date, timedelta, time as dtime
from typing import Any, Dict, List, Optional, Tuple, Union, Generator
from functools import wraps

# --- Flask & Server Imports ---
from flask import (
    Flask, request, jsonify, session, send_from_directory, 
    redirect, url_for, g, Response, stream_with_context, make_response
)
from flask_cors import CORS
from waitress import serve

# --- Database Imports ---
import psycopg2
from psycopg2 import pool, extras, sql
from psycopg2.extensions import ISOLATION_LEVEL_READ_COMMITTED

# --- Environment Configuration ---
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# ==============================================================================
# 1. ENTERPRISE CONFIGURATION CLASS
# ==============================================================================
class Config:
    # --- Database Configuration ---
    DB_HOST = os.getenv('DB_HOST', '0.0.0.0') 
    DB_NAME = os.getenv('DB_NAME', 'demo')
    DB_USER = os.getenv('DB_USER', 'web_admin')
    DB_PASS = os.getenv('DB_PASS', 'password')
    DB_PORT = int(os.getenv('DB_PORT', 5432))

    # --- Security & Session ---
    # REQUIRED: Secret key for session signing. 
    SECRET_KEY = os.getenv('SECRET_KEY', 'dev-secret-key-12345-change-in-prod')
    SESSION_LIFETIME = timedelta(days=1)
    
    # --- Path Configuration ---
    # Calculates absolute path to ensure Gunicorn finds the folder
    BASE_DIR = os.path.abspath(os.path.dirname(__file__))
    STATIC_FOLDER = os.path.join(BASE_DIR, 'static')
    UPLOAD_FOLDER = os.path.join(BASE_DIR, 'uploads')
    
    API_PREFIX = os.getenv('API_PREFIX', '/api')
    
    # --- Performance ---
    DB_MIN_CONN = int(os.getenv('DB_MIN_CONN', 5))
    DB_MAX_CONN = int(os.getenv('DB_MAX_CONN', 60))
    MAX_CONTENT_LENGTH = 500 * 1024 * 1024  # 500 MB

    # --- Logging ---
    LOG_LEVEL = logging.INFO
    LOG_FORMAT = '%(asctime)s - %(name)s - %(levelname)s - %(message)s'

# Ensure directories exist
os.makedirs(Config.UPLOAD_FOLDER, exist_ok=True)
if not os.path.exists(Config.STATIC_FOLDER):
    print(f"CRITICAL WARNING: Static folder not found at {Config.STATIC_FOLDER}")

# Configure Logging
logging.basicConfig(level=Config.LOG_LEVEL, format=Config.LOG_FORMAT)
logger = logging.getLogger("GenFishLIMS")

# ==============================================================================
# 2. FLASK APP INITIALIZATION
# ==============================================================================
# standard setup: static files are served at /static/
app = Flask(__name__, static_folder=Config.STATIC_FOLDER, static_url_path='/static')
app.config.from_object(Config)
app.secret_key = Config.SECRET_KEY
app.permanent_session_lifetime = Config.SESSION_LIFETIME

# Enable CORS (Allow all origins for development)
CORS(app, resources={r"/api/*": {"origins": "*"}}, supports_credentials=True)

# ==============================================================================
# 3. DATABASE POOL & CONTEXT MANAGEMENT
# ==============================================================================

try:
    pg_pool = psycopg2.pool.ThreadedConnectionPool(
        minconn=Config.DB_MIN_CONN,
        maxconn=Config.DB_MAX_CONN,
        host=Config.DB_HOST,
        database=Config.DB_NAME,
        user=Config.DB_USER,
        password=Config.DB_PASS,
        port=Config.DB_PORT,
        cursor_factory=psycopg2.extras.RealDictCursor
    )
    logger.info(f"Database Pool initialized. Host: {Config.DB_HOST}, Port: {Config.DB_PORT}")
except Exception as e:
    logger.critical(f"Failed to initialize Database Pool: {e}")
    sys.exit(1)

def get_db_connection():
    """Retrieves a connection from the pool for the current request context."""
    if 'db_conn' not in g:
        g.db_conn = pg_pool.getconn()
    return g.db_conn

@app.teardown_appcontext
def close_db_connection(error):
    """Returns the database connection to the pool after the request completes."""
    conn = g.pop('db_conn', None)
    if conn:
        pg_pool.putconn(conn)

# ==============================================================================
# 4. JSON SERIALIZATION EXTENSIONS
# ==============================================================================
class LIMSJSONEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, (datetime, date)):
            return obj.isoformat()
        if isinstance(obj, dtime):
            return obj.strftime('%H:%M:%S')
        if isinstance(obj, uuid.UUID):
            return str(obj)
        if isinstance(obj, bytes):
            return base64.b64encode(obj).decode('utf-8')
        if isinstance(obj, set):
            return list(obj)
        if hasattr(obj, 'normalize'): 
            return float(obj)
        return super().default(obj)

app.json_encoder = LIMSJSONEncoder

def jsonify_lims(data, status=200):
    """Helper to return JSON responses with the custom encoder."""
    return Response(
        json.dumps(data, cls=LIMSJSONEncoder),
        status=status,
        mimetype='application/json'
    )

# ==============================================================================
# 5. SECURITY & AUTHENTICATION MIDDLEWARE
# ==============================================================================

def login_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'user_id' not in session:
            return jsonify({"error": "Authentication required", "code": 401}), 401
        return f(*args, **kwargs)
    return decorated_function

@app.before_request
def set_application_context():
    """Sets Row-Level Security (RLS) context in Postgres."""
    if request.endpoint == 'static' or not request.endpoint: 
        return

    conn = get_db_connection()
    user_id = session.get('user_id', 'anonymous')
    
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT set_config('lims.current_user_id', %s, false)", (str(user_id),))
            cur.execute("SELECT set_config('session.user_id', %s, false)", (str(user_id),))
    except Exception as e:
        logger.error(f"Failed to set RLS context: {e}")

# ==============================================================================
# 6. MODULE: AUTHENTICATION
# ==============================================================================

@app.route(f"{Config.API_PREFIX}/auth/login", methods=['POST'])
def login():
    data = request.json
    username = data.get('username')
    password = data.get('password')

    if not username or not password:
        return jsonify({"error": "Missing credentials"}), 400

    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT person_id, first_name, last_name, role_id, email
                FROM core.persons 
                WHERE email = %s OR last_name = %s
                LIMIT 1
            """, (username, username))
            
            user = cur.fetchone()

            if user:
                # Basic password check for development/testing
                if password == "password" or password == "admin123": 
                    session['user_id'] = user['person_id']
                    session['role'] = user['role_id']
                    session['name'] = f"{user['first_name']} {user['last_name']}"
                    
                    return jsonify({
                        "success": True, 
                        "user": {
                            "id": user['person_id'],
                            "name": session['name'],
                            "role": user['role_id']
                        }
                    })
            
            return jsonify({"error": "Invalid credentials"}), 401

    except Exception as e:
        logger.error(f"Login error: {e}")
        return jsonify({"error": "Internal server error"}), 500

@app.route(f"{Config.API_PREFIX}/auth/logout", methods=['POST'])
def logout():
    session.clear()
    return jsonify({"success": True, "message": "Logged out"})

@app.route(f"{Config.API_PREFIX}/auth/me", methods=['GET'])
def get_current_user():
    if 'user_id' in session:
        return jsonify({
            "authenticated": True,
            "id": session['user_id'],
            "name": session.get('name'),
            "role": session.get('role')
        })
    return jsonify({"authenticated": False})

# ==============================================================================
# 7. MODULE: DASHBOARD
# ==============================================================================

@app.route(f"{Config.API_PREFIX}/dashboard/stats", methods=['GET'])
@login_required
def get_dashboard_stats():
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            query = """
                SELECT
                    (SELECT COUNT(*) FROM bio_assets.samples_root) AS total_samples,
                    (SELECT COUNT(*) FROM lims.projects WHERE status_id = 'Active') AS active_projects,
                    (SELECT COUNT(*) FROM eln.batch WHERE creation_date > CURRENT_DATE - INTERVAL '7 days') AS new_batches,
                    (SELECT COUNT(*) FROM bioinformatics.jobs WHERE status = 'Running') AS running_jobs,
                    (SELECT COUNT(*) FROM moleculargenetics.sequencing_flowcells) AS flowcells
            """
            cur.execute(query)
            stats = cur.fetchone()
            return jsonify_lims(stats)
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route(f"{Config.API_PREFIX}/dashboard/activity_chart", methods=['GET'])
@login_required
def get_activity_chart():
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT 
                    to_char(collection_date, 'YYYY-MM') as month, 
                    COUNT(*) as count 
                FROM bio_assets.samples_root 
                WHERE collection_date > CURRENT_DATE - INTERVAL '12 months'
                GROUP BY 1 
                ORDER BY 1
            """)
            data = cur.fetchall()
            return jsonify_lims({
                "labels": [row['month'] for row in data],
                "datasets": [{
                    "label": "New Samples",
                    "data": [row['count'] for row in data],
                    "fill": True,
                    "borderColor": "#3498db",
                    "tension": 0.4
                }]
            })
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# ==============================================================================
# 8. MODULE: DATABASE EXPLORER
# ==============================================================================

@app.route(f"{Config.API_PREFIX}/explorer/schemas", methods=['GET'])
@login_required
def get_schemas_tables():
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT table_schema, table_name 
                FROM information_schema.tables 
                WHERE table_schema NOT IN ('information_schema', 'pg_catalog')
                ORDER BY table_schema, table_name
            """)
            rows = cur.fetchall()
            tree = {}
            for row in rows:
                sch = row['table_schema']
                if sch not in tree: tree[sch] = []
                tree[sch].append(row['table_name'])
            return jsonify(tree)
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route(f"{Config.API_PREFIX}/explorer/data/<schema>/<table>", methods=['GET'])
@login_required
def get_table_data(schema, table):
    limit = int(request.args.get('limit', 100))
    offset = int(request.args.get('offset', 0))
    sort_by = request.args.get('sort_by', None)
    
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT column_name, data_type 
                FROM information_schema.columns 
                WHERE table_schema = %s AND table_name = %s
                ORDER BY ordinal_position
            """, (schema, table))
            columns = cur.fetchall()
            
            if not columns: return jsonify({"error": "Table not found"}), 404

            query = sql.SQL("SELECT * FROM {}.{}").format(
                sql.Identifier(schema), sql.Identifier(table)
            )
            
            if sort_by and sort_by in [c['column_name'] for c in columns]:
                 query += sql.SQL(" ORDER BY {} DESC").format(sql.Identifier(sort_by))
            
            query += sql.SQL(" LIMIT %s OFFSET %s")
            cur.execute(query, (limit, offset))
            
            return jsonify_lims({
                "columns": [c['column_name'] for c in columns],
                "data": cur.fetchall()
            })
    except Exception as e:
        logger.error(f"Explorer Data Error: {e}")
        return jsonify({"error": str(e)}), 500

# ==============================================================================
# 9. MODULE: STORAGE & REAGENTS (Restored)
# ==============================================================================

@app.route(f"{Config.API_PREFIX}/storage/visualizer/<storage_id>", methods=['GET'])
@login_required
def get_storage_grid(storage_id):
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT storage_id, name, storage_type, box_size_x, box_size_y FROM lims.storage WHERE storage_id = %s", (storage_id,))
            storage = cur.fetchone()
            if not storage: return jsonify({"error": "Storage unit not found"}), 404
            
            cur.execute("SELECT sample_id, sample_name, storage_position, sample_type FROM bio_assets.samples_root WHERE storage_id = %s", (storage_id,))
            contents = cur.fetchall()
            
            occupancy = {}
            for item in contents:
                if item['storage_position']: occupancy[item['storage_position']] = item
            
            return jsonify_lims({"meta": storage, "occupancy": occupancy})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route(f"{Config.API_PREFIX}/storage/move_sample", methods=['POST'])
@login_required
def move_sample():
    data = request.json
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                UPDATE bio_assets.samples_root
                SET storage_id = %s, storage_position = %s, modification_date = NOW()
                WHERE sample_id = %s
            """, (data.get('storage_id'), data.get('position'), data.get('sample_id')))
            conn.commit()
            return jsonify({"success": True})
    except Exception as e:
        conn.rollback()
        return jsonify({"error": str(e)}), 500

# ==============================================================================
# 10. MODULE: FIELD EVENTS (Restored)
# ==============================================================================

@app.route(f"{Config.API_PREFIX}/field/geojson", methods=['GET'])
@login_required
def get_field_geojson():
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            query = """
                SELECT json_build_object(
                    'type', 'FeatureCollection',
                    'features', json_agg(json_build_object(
                        'type', 'Feature',
                        'geometry', json_build_object('type', 'Point', 'coordinates', json_build_array(longitude, latitude)),
                        'properties', json_build_object('id', sampling_id, 'date', sampling_date, 'cruise', cruise_id, 'location', location_name)
                    ))
                ) as geojson
                FROM field.sampling_events
                WHERE latitude IS NOT NULL AND longitude IS NOT NULL
            """
            cur.execute(query)
            result = cur.fetchone()
            return jsonify(result['geojson'] if result and result['geojson'] else {"type": "FeatureCollection", "features": []})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route(f"{Config.API_PREFIX}/field/event", methods=['POST'])
@login_required
def create_field_event():
    data = request.json
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                INSERT INTO field.sampling_events 
                (cruise_id, sampling_date, latitude, longitude, location_name, comments)
                VALUES (%s, %s, %s, %s, %s, %s)
                RETURNING sampling_id
            """, (data.get('cruise_id'), data.get('date'), data.get('lat'), data.get('lng'), data.get('location'), data.get('comments')))
            new_id = cur.fetchone()['sampling_id']
            conn.commit()
            return jsonify({"success": True, "id": new_id})
    except Exception as e:
        conn.rollback()
        return jsonify({"error": str(e)}), 500

# ==============================================================================
# 11. MODULE: BIOINFORMATICS (Restored)
# ==============================================================================

@app.route(f"{Config.API_PREFIX}/bioinfo/pipeline/submit", methods=['POST'])
@login_required
def submit_pipeline_job():
    data = request.json
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            job_uuid = str(uuid.uuid4())
            cur.execute("""
                INSERT INTO bioinformatics.jobs (job_id, pipeline_name, status, submission_date, parameters, submitter_id)
                VALUES (%s, %s, 'Queued', NOW(), %s, %s)
            """, (job_uuid, data.get('pipeline_name'), json.dumps(data.get('parameters', {})), session.get('user_id')))
            
            if data.get('dataset_ids'):
                values = [(job_uuid, ds_id) for ds_id in data.get('dataset_ids')]
                extras.execute_values(cur, "INSERT INTO bioinformatics.job_datasets (job_id, dataset_id) VALUES %s", values)
            
            conn.commit()
            return jsonify({"success": True, "job_id": job_uuid, "status": "Queued"})
    except Exception as e:
        conn.rollback()
        return jsonify({"error": str(e)}), 500

@app.route(f"{Config.API_PREFIX}/bioinfo/taxonomy_stats/<run_id>", methods=['GET'])
@login_required
def get_taxonomy_stats(run_id):
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT s.sample_name, a.taxon_phylum, COUNT(*) as read_count
                FROM bioinformatics.assignments a
                JOIN bioinformatics.seq_dataset ds ON a.dataset_id = ds.dataset_id
                JOIN bio_assets.samples_root s ON ds.sample_id = s.sample_id
                WHERE ds.run_id = %s
                GROUP BY 1, 2
                ORDER BY 1
            """, (run_id,))
            rows = cur.fetchall()
            
            samples = sorted(list(set(row['sample_name'] for row in rows)))
            phyla = sorted(list(set(row['taxon_phylum'] for row in rows)))
            
            datasets = []
            for p in phyla:
                data_points = []
                for s in samples:
                    val = next((r['read_count'] for r in rows if r['sample_name'] == s and r['taxon_phylum'] == p), 0)
                    data_points.append(val)
                color_hash = hash(p) % 0xFFFFFF
                datasets.append({"label": p, "data": data_points, "backgroundColor": f"#{color_hash:06x}"})
                
            return jsonify_lims({"labels": samples, "datasets": datasets})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# ==============================================================================
# 12. MODULE: FISH BIOLOGY (Restored)
# ==============================================================================

@app.route(f"{Config.API_PREFIX}/biology/fish/gsi", methods=['POST'])
@login_required
def calculate_save_gsi():
    data = request.json
    total_weight = float(data.get('weight_g', 0))
    gonad_weight = float(data.get('gonad_weight_g', 0))
    if total_weight <= 0: return jsonify({"error": "Total weight must be > 0"}), 400
    gsi = (gonad_weight / total_weight) * 100
    
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("UPDATE biologyfish.specimens SET gonad_weight = %s, gsi_index = %s WHERE fish_id = %s", (gonad_weight, gsi, data.get('fish_id')))
            conn.commit()
            return jsonify({"success": True, "gsi": round(gsi, 2)})
    except Exception as e:
        conn.rollback()
        return jsonify({"error": str(e)}), 500

@app.route(f"{Config.API_PREFIX}/biology/fish/prey", methods=['POST'])
@login_required
def add_stomach_content():
    data = request.json
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            values = [(data.get('fish_id'), item['taxon'], item.get('count', 1), item.get('weight'), item.get('notes')) for item in data.get('prey_items')]
            extras.execute_values(cur, "INSERT INTO biologyfish.stomach_contents (fish_id, prey_taxon, count, weight_g, notes) VALUES %s", values)
            conn.commit()
            return jsonify({"success": True})
    except Exception as e:
        conn.rollback()
        return jsonify({"error": str(e)}), 500

# ==============================================================================
# 13. MODULE: ELN & BOOKING (Restored)
# ==============================================================================

@app.route(f"{Config.API_PREFIX}/eln/bookings", methods=['GET', 'POST'])
@login_required
def handle_bookings():
    conn = get_db_connection()
    if request.method == 'GET':
        start = request.args.get('start')
        end = request.args.get('end')
        try:
            with conn.cursor() as cur:
                cur.execute("SELECT booking_id as id, instrument_name as title, start_time as start, end_time as end, user_id, status FROM eln.bookings WHERE start_time >= %s AND end_time <= %s", (start, end))
                return jsonify_lims(cur.fetchall())
        except Exception as e: return jsonify({"error": str(e)}), 500

    if request.method == 'POST':
        data = request.json
        try:
            with conn.cursor() as cur:
                cur.execute("INSERT INTO eln.bookings (instrument_id, user_id, start_time, end_time, purpose) VALUES (%s, %s, %s, %s, %s) RETURNING booking_id", (data['instrument_id'], session['user_id'], data['start'], data['end'], data['title']))
                new_id = cur.fetchone()['booking_id']
                conn.commit()
                return jsonify({"success": True, "id": new_id})
        except Exception as e:
            conn.rollback()
            return jsonify({"error": str(e)}), 500

@app.route(f"{Config.API_PREFIX}/eln/experiment/save", methods=['POST'])
@login_required
def save_dynamic_experiment():
    data = request.json
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("INSERT INTO eln.experiments (name, owner_id, creation_date, form_schema, form_data_json) VALUES (%s, %s, NOW(), %s, %s) RETURNING experiment_id", (data.get('name'), session['user_id'], json.dumps(data.get('schema')), json.dumps(data.get('data'))))
            new_id = cur.fetchone()['experiment_id']
            conn.commit()
            return jsonify({"success": True, "id": new_id})
    except Exception as e:
        conn.rollback()
        return jsonify({"error": str(e)}), 500

# ==============================================================================
# 14. BULK IMPORT (Restored)
# ==============================================================================

@app.route(f"{Config.API_PREFIX}/data/bulk_import_csv", methods=['POST'])
@login_required
def bulk_import_csv():
    if 'file' not in request.files: return jsonify({"error": "No file uploaded"}), 400
    file = request.files['file']
    target_table = request.form.get('table')
    
    if not re.match(r'^[a-z0-9_]+\.[a-z0-9_]+$', target_table): return jsonify({"error": "Invalid table format"}), 400

    conn = get_db_connection()
    try:
        filename = f"{uuid.uuid4()}.csv"
        filepath = os.path.join(Config.UPLOAD_FOLDER, filename)
        file.save(filepath)
        
        with conn.cursor() as cur:
            with open(filepath, 'r') as f:
                cur.copy_expert(f"COPY {target_table} FROM STDIN WITH CSV HEADER", f)
            conn.commit()
            
        os.remove(filepath)
        return jsonify({"success": True, "message": "Bulk import completed."})
    except Exception as e:
        if conn: conn.rollback()
        return jsonify({"error": f"Import failed: {str(e)}"}), 500

# ==============================================================================
# 15. MAIN ENTRY POINT & STATIC SERVING
# ==============================================================================

@app.route('/')
def root():
    """Redirects root URL to the login page."""
    # Since static_url_path='/static', the file is at /static/login.html
    return redirect('/static/login.html')

if __name__ == '__main__':
    print("="*60)
    print(f" GENFISH ENTERPRISE LIMS v5.0 STARTING")
    print(f" Static Folder: {Config.STATIC_FOLDER}")
    print(f" Database: {Config.DB_HOST}:{Config.DB_PORT}/{Config.DB_NAME}")
    print(f" Serving on port 5000...")
    print("="*60)
    serve(app, host='0.0.0.0', port=5000, threads=Config.DB_MAX_CONN)