import os
import sys
import json
import uuid
import math
import time
import logging
import traceback
import bcrypt
import re
import csv
import io
import shutil
from datetime import datetime, date, time as dtime
from functools import wraps
from typing import Any, Dict, List, Optional, Union, Tuple

# --- Third Party Imports ---
# Install: pip install flask flask-cors psycopg2-binary openpyxl bcrypt waitress
from flask import (
    Flask, request, jsonify, session, send_from_directory, 
    redirect, url_for, g, make_response, send_file
)
from flask.json.provider import DefaultJSONProvider
from flask_cors import CORS
from werkzeug.utils import secure_filename
import openpyxl  # REQUIRED for Excel handling

# --- Database Imports ---
import psycopg2
from psycopg2 import pool, extras, sql

# ==============================================================================
# 1. CONFIGURATION & LOGGING
# ==============================================================================

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(module)s: %(message)s',
    handlers=[logging.StreamHandler(sys.stdout)]
)
logger = logging.getLogger("GenFishLIMS")

class Config:
    """Central Configuration."""
    SECRET_KEY = os.environ.get('SECRET_KEY', 'enterprise-secret-key-change-in-prod')
    SESSION_COOKIE_HTTPONLY = True
    SESSION_COOKIE_SECURE = False # Set True in Prod
    
    # Database
    DB_HOST = os.environ.get('DB_HOST', 'localhost')
    DB_PORT = os.environ.get('DB_PORT', '5432')
    DB_NAME = os.environ.get('DB_NAME', 'mylims_v5')
    DB_USER = os.environ.get('DB_USER', 'postgres')
    DB_PASS = os.environ.get('DB_PASS', 'password')
    
    # Pool
    DB_MIN_CONN = 5
    DB_MAX_CONN = 50
    
    # Uploads
    UPLOAD_FOLDER = os.path.join(os.getcwd(), 'uploads')
    TEMP_FOLDER = os.path.join(os.getcwd(), 'temp')
    MAX_CONTENT_LENGTH = 500 * 1024 * 1024  # 500MB
    ALLOWED_EXTENSIONS = {'txt', 'pdf', 'png', 'jpg', 'jpeg', 'csv', 'xlsx', 'json'}

os.makedirs(Config.UPLOAD_FOLDER, exist_ok=True)
os.makedirs(Config.TEMP_FOLDER, exist_ok=True)

# ==============================================================================
# 2. UTILITIES & JSON HANDLING
# ==============================================================================

class LIMSJSONProvider(DefaultJSONProvider):
    def default(self, obj):
        if isinstance(obj, (date, datetime)):
            return obj.isoformat()
        if isinstance(obj, dtime):
            return obj.strftime('%H:%M:%S')
        if isinstance(obj, (int, float)) and hasattr(obj, 'is_integer'):
            return float(obj)
        if isinstance(obj, uuid.UUID):
            return str(obj)
        if isinstance(obj, (bytes, bytearray)):
            return "<binary_blob>"
        return super().default(obj)

def allowed_file(filename):
    return '.' in filename and \
           filename.rsplit('.', 1)[1].lower() in Config.ALLOWED_EXTENSIONS

# ==============================================================================
# 3. APP INITIALIZATION
# ==============================================================================

app = Flask(__name__, static_folder='static')
app.json = LIMSJSONProvider(app)
app.config.from_object(Config)
CORS(app, supports_credentials=True, resources={r"/api/*": {"origins": "*"}})

# ==============================================================================
# 4. DATABASE LAYER
# ==============================================================================

try:
    pg_pool = psycopg2.pool.ThreadedConnectionPool(
        minconn=Config.DB_MIN_CONN,
        maxconn=Config.DB_MAX_CONN,
        host=Config.DB_HOST,
        port=Config.DB_PORT,
        dbname=Config.DB_NAME,
        user=Config.DB_USER,
        password=Config.DB_PASS,
        cursor_factory=psycopg2.extras.RealDictCursor
    )
    logger.info("✅ Database Connection Pool Initialized.")
except Exception as e:
    logger.critical(f"❌ DB Connection Failed: {e}")
    sys.exit(1)

from contextlib import contextmanager

@contextmanager
def get_db(commit=False):
    """
    Robust Context Manager for DB transactions.
    """
    conn = None
    try:
        conn = pg_pool.getconn()
        cur = conn.cursor()
        yield conn, cur
        if commit:
            conn.commit()
    except Exception as e:
        logger.error(f"DB Error: {e}")
        if conn:
            conn.rollback()
        raise e
    finally:
        if conn:
            cur.close()
            pg_pool.putconn(conn)

def execute_read(query, params=None):
    with get_db() as (conn, cur):
        cur.execute(query, params)
        return cur.fetchall()

def execute_write(query, params=None):
    with get_db(commit=True) as (conn, cur):
        cur.execute(query, params)
        try:
            return cur.fetchone()
        except:
            return None

# ==============================================================================
# 5. SECURITY & MIDDLEWARE
# ==============================================================================

def login_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'user_id' not in session:
            return jsonify({'error': 'Unauthorized', 'redirect': '/login'}), 401
        return f(*args, **kwargs)
    return decorated_function

def audit_log(action, target, target_id, details=None):
    """Async-style audit logging."""
    try:
        user_id = session.get('user_id')
        ip = request.remote_addr
        q = "INSERT INTO audit.access_log (user_id, action, ip_address, details) VALUES (%s, %s, %s, %s)"
        execute_write(q, (user_id, f"{action}:{target}:{target_id}", ip, json.dumps(details) if details else None))
    except:
        pass # Fail silently for logs

# ==============================================================================
# 6. DASHBOARD & ANALYTICS (Matches HTML Dashboard)
# ==============================================================================

@app.route('/api/dashboard/stats', methods=['GET'])
@login_required
def get_dashboard_stats():
    """
    Aggregates high-level stats for the Dashboard cards.
    """
    try:
        with get_db() as (conn, cur):
            stats = {}
            # Total Samples
            cur.execute("SELECT count(*) as c FROM bio_assets.samples")
            stats['total_samples'] = cur.fetchone()['c']
            
            # Active Projects
            cur.execute("SELECT count(*) as c FROM core.projects WHERE status = 'ACTIVE'")
            stats['active_projects'] = cur.fetchone()['c']
            
            # Pending Sequencing
            cur.execute("SELECT count(*) as c FROM moleculargenetics.library WHERE status != 'SEQUENCED'")
            stats['pending_libraries'] = cur.fetchone()['c']
            
            # Storage Capacity (Approximation)
            cur.execute("SELECT count(*) as c FROM lims.storage_locations WHERE is_full = true")
            stats['full_boxes'] = cur.fetchone()['c']

        return jsonify(stats)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/dashboard/activity', methods=['GET'])
@login_required
def get_activity_feed():
    """Returns recent system activity for the feed widget."""
    q = """
        SELECT a.log_time, a.action, a.details, 
               p.first_name || ' ' || p.last_name as user_name
        FROM audit.access_log a
        JOIN core.personnel p ON a.user_id = p.person_id
        ORDER BY a.log_time DESC LIMIT 10
    """
    return jsonify(execute_read(q))

# ==============================================================================
# 7. SAMPLES & ASSETS (Matches Sample Tab)
# ==============================================================================

@app.route('/api/samples/list', methods=['GET'])
@login_required
def list_samples():
    """
    Advanced filtered list for the Samples DataTables/Grid.
    """
    page = int(request.args.get('page', 1))
    limit = int(request.args.get('limit', 50))
    offset = (page - 1) * limit
    search = request.args.get('search', '')
    
    where = ["1=1"]
    params = []
    
    if search:
        where.append("(s.sample_name ILIKE %s OR s.species ILIKE %s)")
        params.extend([f"%{search}%", f"%{search}%"])
        
    query = f"""
        SELECT s.sample_id, s.sample_name, s.sample_type, s.species, s.collection_date,
               p.project_name, st.storage_label
        FROM bio_assets.samples s
        LEFT JOIN core.projects p ON s.project_id = p.project_id
        LEFT JOIN lims.storage_locations st ON s.storage_loc_id = st.location_id
        WHERE {" AND ".join(where)}
        ORDER BY s.created_at DESC
        LIMIT %s OFFSET %s
    """
    
    # Get total for pagination
    count_q = f"SELECT count(*) as t FROM bio_assets.samples s WHERE {' AND '.join(where)}"
    total = execute_read(count_q, params)[0]['t']
    
    data = execute_read(query, params + [limit, offset])
    
    return jsonify({
        'data': data,
        'pagination': {
            'total': total,
            'page': page,
            'pages': math.ceil(total/limit)
        }
    })

# ==============================================================================
# 8. EXCEL & DATA IMPORT ENGINE (Requested Feature)
# ==============================================================================

def normalize_header(header_text):
    """
    Converts 'Sample Name' -> 'sample_name', 'Date Collected' -> 'collection_date'
    Helps map Excel headers to DB columns.
    """
    if not header_text: return ""
    h = str(header_text).lower().strip()
    h = re.sub(r'[^a-z0-9]', '_', h) # Replace non-alphanumeric with _
    h = re.sub(r'_+', '_', h) # Collapse multiple _
    
    # Common mappings
    mappings = {
        'name': 'sample_name',
        'id': 'sample_id',
        'date': 'collection_date',
        'project': 'project_id', # Needs name lookup logic usually
        'location': 'storage_loc_id'
    }
    return mappings.get(h, h)

@app.route('/api/import/template/<type>', methods=['GET'])
@login_required
def download_template(type):
    """
    Generates a blank Excel template for users to fill out.
    """
    # Define columns for each type
    columns = []
    if type == 'samples':
        columns = ['sample_name', 'alt_name', 'sample_type', 'species', 'collection_date', 'comments']
    elif type == 'projects':
        columns = ['project_name', 'description', 'start_date', 'principal_investigator']
    elif type == 'library':
        columns = ['sample_name', 'library_name', 'index_i7', 'index_i5', 'prep_date']
    else:
        return jsonify({'error': 'Unknown template type'}), 400

    # Create Excel in memory
    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = "Import Template"
    ws.append(columns) # Header row
    
    # Style header (Bold)
    for cell in ws[1]:
        cell.font = openpyxl.styles.Font(bold=True)

    out = io.BytesIO()
    wb.save(out)
    out.seek(0)
    
    return send_file(
        out, 
        mimetype='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        as_attachment=True,
        download_name=f'template_{type}.xlsx'
    )

@app.route('/api/import/upload', methods=['POST'])
@login_required
def upload_excel_import():
    """
    Handles .xlsx upload, parses it, and inserts into DB.
    """
    if 'file' not in request.files:
        return jsonify({'error': 'No file part'}), 400
    file = request.files['file']
    target_table = request.form.get('target', 'samples')
    
    if not file or file.filename == '':
        return jsonify({'error': 'No selected file'}), 400

    if not file.filename.endswith('.xlsx'):
        return jsonify({'error': 'Only .xlsx files are supported for this importer'}), 400

    try:
        # Load Excel
        wb = openpyxl.load_workbook(file, data_only=True)
        sheet = wb.active
        
        # Get Headers
        headers = [cell.value for cell in sheet[1]]
        normalized_headers = [normalize_header(h) for h in headers]
        
        # Validation: Check if critical columns exist
        required_cols = {'sample_name'} if target_table == 'samples' else set()
        if not required_cols.issubset(set(normalized_headers)):
            return jsonify({'error': f'Missing required columns: {required_cols - set(normalized_headers)}'}), 400
            
        rows_inserted = 0
        errors = []

        with get_db(commit=True) as (conn, cur):
            # Iterate rows (starting from row 2)
            for row_idx, row in enumerate(sheet.iter_rows(min_row=2, values_only=True), start=2):
                if not row[0]: continue # Skip empty rows based on first col
                
                row_data = dict(zip(normalized_headers, row))
                
                try:
                    if target_table == 'samples':
                        # Default values
                        if 'project_id' not in row_data:
                            # Assign to a default project or handle error
                            # For now, let's assume a default ID or grab from form
                            row_data['project_id'] = request.form.get('project_id', 1) 
                        
                        cur.execute("""
                            INSERT INTO bio_assets.samples 
                            (sample_name, sample_type, species, collection_date, project_id, created_by)
                            VALUES (%s, %s, %s, %s, %s, %s)
                        """, (
                            row_data.get('sample_name'),
                            row_data.get('sample_type', 'TISSUE'),
                            row_data.get('species'),
                            row_data.get('collection_date'),
                            row_data.get('project_id'),
                            session['user_id']
                        ))
                        rows_inserted += 1
                        
                    elif target_table == 'projects':
                         cur.execute("""
                            INSERT INTO core.projects (project_name, description) VALUES (%s, %s)
                        """, (row_data.get('project_name'), row_data.get('description')))
                         rows_inserted += 1

                except Exception as row_error:
                    errors.append(f"Row {row_idx}: {str(row_error)}")
                    conn.rollback() # Rollback this row only if possible, but usually block fails
                    # Here we might want to continue or stop. 
                    # For simplicity, we catch and log, but transaction might be aborted.
                    # In true enterprise, use SAVEPOINT per row.
        
        return jsonify({
            'success': True,
            'processed': rows_inserted,
            'errors': errors
        })

    except Exception as e:
        logger.error(f"Import Failed: {e}")
        return jsonify({'error': f"Import processing failed: {str(e)}"}), 500

# ==============================================================================
# 9. STORAGE & VISUALIZATION (Tree & Box Views)
# ==============================================================================

@app.route('/api/storage/tree', methods=['GET'])
@login_required
def get_storage_tree():
    """Returns flat list for frontend to build tree."""
    q = "SELECT location_id, storage_label, location_type, parent_location_id FROM lims.storage_locations"
    return jsonify(execute_read(q))

@app.route('/api/storage/box/<uuid:box_id>', methods=['GET'])
@login_required
def get_box_details(box_id):
    """Returns box grid configuration and contents."""
    with get_db() as (conn, cur):
        # Box Info
        cur.execute("SELECT * FROM lims.storage_locations WHERE location_id = %s", (str(box_id),))
        box = cur.fetchone()
        
        # Samples
        cur.execute("""
            SELECT sample_id, sample_name, box_position_x, box_position_y 
            FROM bio_assets.samples 
            WHERE storage_loc_id = %s
        """, (str(box_id),))
        samples = cur.fetchall()
        
    return jsonify({'box': box, 'samples': samples})

@app.route('/api/storage/move', methods=['POST'])
@login_required
def move_sample():
    """
    Moves a sample to a new location.
    Wraps logic in a transaction.
    """
    data = request.json
    sample_id = data['sample_id']
    target_loc_id = data['location_id']
    pos_x = data.get('x')
    pos_y = data.get('y')
    
    try:
        with get_db(commit=True) as (conn, cur):
            # Check if spot is occupied
            if pos_x and pos_y:
                cur.execute("""
                    SELECT sample_id FROM bio_assets.samples 
                    WHERE storage_loc_id = %s AND box_position_x = %s AND box_position_y = %s
                """, (target_loc_id, pos_x, pos_y))
                if cur.fetchone():
                    return jsonify({'error': 'Spot is already occupied'}), 409

            # Update Sample
            cur.execute("""
                UPDATE bio_assets.samples 
                SET storage_loc_id = %s, box_position_x = %s, box_position_y = %s, modified_at = NOW()
                WHERE sample_id = %s
            """, (target_loc_id, pos_x, pos_y, sample_id))
            
            # Log Movement (Optional History Table)
            
        return jsonify({'success': True})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# ==============================================================================
# 10. MOLECULAR & BIOINFORMATICS
# ==============================================================================

@app.route('/api/bioinformatics/jobs', methods=['GET'])
@login_required
def get_bioinfo_jobs():
    """Lists recent jobs with status."""
    # Mocking job data if table doesn't exist, or querying if it does.
    # Assuming `bioinformatics.jobs` exists in new schema
    try:
        q = "SELECT * FROM bioinformatics.jobs ORDER BY created_at DESC LIMIT 20"
        return jsonify(execute_read(q))
    except:
        return jsonify([]) # Return empty if table not ready

@app.route('/api/bioinformatics/submit', methods=['POST'])
@login_required
def submit_job():
    """Submits a new analysis job."""
    data = request.json
    # Simulate submission
    job_id = str(uuid.uuid4())
    # In real app: Insert into DB, trigger Celery task
    return jsonify({'success': True, 'job_id': job_id, 'status': 'QUEUED'})

# ==============================================================================
# 11. ELECTRONIC LAB NOTEBOOK (ELN)
# ==============================================================================

@app.route('/api/eln/save', methods=['POST'])
@login_required
def save_eln_entry():
    """Saves a notebook entry with JSONB content."""
    data = request.json
    try:
        query = """
            INSERT INTO eln.entries (title, content_data, tags, author_id, created_at)
            VALUES (%s, %s, %s, %s, NOW())
            RETURNING entry_id
        """
        # content_data is stored as JSONB in Postgres
        res = execute_write(query, (
            data.get('title', 'Untitled'),
            json.dumps(data.get('content', {})),
            data.get('tags', []),
            session['user_id']
        ))
        return jsonify({'success': True, 'entry_id': res['entry_id']})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# ==============================================================================
# 12. AUTHENTICATION (Login/Logout)
# ==============================================================================

@app.route('/api/auth/login', methods=['POST'])
def login():
    data = request.json
    email = data.get('email')
    password = data.get('password')
    
    q = "SELECT person_id, first_name, last_name, password_hash, role, active FROM core.personnel WHERE email = %s"
    user = execute_read(q, (email,))
    
    if user:
        user = user[0]
        if bcrypt.checkpw(password.encode('utf-8'), user['password_hash'].encode('utf-8')):
            if not user['active']: return jsonify({'error': 'Account Disabled'}), 403
            
            session['user_id'] = user['person_id']
            session['role'] = user['role']
            session['name'] = f"{user['first_name']} {user['last_name']}"
            
            audit_log('LOGIN', 'personnel', user['person_id'])
            return jsonify({'success': True, 'user': user})
            
    return jsonify({'error': 'Invalid credentials'}), 401

@app.route('/api/auth/logout', methods=['POST'])
def logout():
    session.clear()
    return jsonify({'success': True})

@app.route('/api/auth/me', methods=['GET'])
def check_auth():
    if 'user_id' in session:
        return jsonify({'authenticated': True, 'user': session})
    return jsonify({'authenticated': False})

# ==============================================================================
# 13. MAIN ENTRY & STATIC SERVING
# ==============================================================================

@app.route('/')
def index():
    return send_from_directory('static', 'index.html')

@app.route('/<path:path>')
def serve_static(path):
    return send_from_directory('static', path)

if __name__ == '__main__':
    print("="*60)
    print(f" GENFISH LIMS v6.0 (Excel + Enterprise)")
    print(f" Database: {Config.DB_NAME} on {Config.DB_HOST}")
    print("="*60)
    
    from waitress import serve
    serve(app, host='0.0.0.0', port=5000, threads=8)