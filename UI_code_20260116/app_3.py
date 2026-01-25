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
import csv
import io
from datetime import datetime, date, timedelta, time as dtime
from functools import wraps
from typing import Any, Dict, List, Optional, Union, Tuple

# --- Flask & Server Imports ---
from flask import (
    Flask, request, jsonify, session, send_from_directory, 
    redirect, url_for, g, make_response, send_file
)
from flask.json.provider import DefaultJSONProvider
from flask_cors import CORS
from werkzeug.utils import secure_filename

# --- Database Imports ---
import psycopg2
from psycopg2 import pool, extras, sql

# ==============================================================================
# 1. CONFIGURATION & LOGGING
# ==============================================================================

# Configure Logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(module)s: %(message)s',
    handlers=[logging.StreamHandler(sys.stdout)]
)
logger = logging.getLogger("GenFishLIMS")

class Config:
    """Central Configuration."""
    # Security
    SECRET_KEY = os.environ.get('SECRET_KEY', 'dev-enterprise-key-998877')
    SESSION_COOKIE_HTTPONLY = True
    SESSION_COOKIE_SECURE = False # Set True in Production with HTTPS
    
    # Database Config
    DB_HOST = os.environ.get('DB_HOST', 'localhost')
    DB_PORT = os.environ.get('DB_PORT', '5432')
    DB_NAME = os.environ.get('DB_NAME', 'mylims_v5')
    DB_USER = os.environ.get('DB_USER', 'postgres')
    DB_PASS = os.environ.get('DB_PASS', 'password')
    
    # Connection Pool Settings
    DB_MIN_CONN = 5
    DB_MAX_CONN = 50
    
    # File Storage
    UPLOAD_FOLDER = os.path.join(os.getcwd(), 'uploads')
    TEMP_FOLDER = os.path.join(os.getcwd(), 'temp')
    MAX_CONTENT_LENGTH = 500 * 1024 * 1024  # 500MB Limit
    ALLOWED_EXTENSIONS = {'txt', 'pdf', 'png', 'jpg', 'jpeg', 'gif', 'csv', 'xlsx', 'fastq', 'fasta', 'bam', 'vcf', 'json'}

# Ensure directories exist
os.makedirs(Config.UPLOAD_FOLDER, exist_ok=True)
os.makedirs(Config.TEMP_FOLDER, exist_ok=True)

# ==============================================================================
# 2. UTILITIES & HELPERS
# ==============================================================================

class LIMSJSONProvider(DefaultJSONProvider):
    """
    Smart JSON Encoder to handle PostgreSQL specific types.
    """
    def default(self, obj):
        if isinstance(obj, (date, datetime)):
            return obj.isoformat()
        if isinstance(obj, dtime):
            return obj.strftime('%H:%M:%S')
        if isinstance(obj, (int, float)) and hasattr(obj, 'is_integer'): # Decimal
            return float(obj)
        if isinstance(obj, uuid.UUID):
            return str(obj)
        if isinstance(obj, memoryview):
            return "<binary_data>"
        if isinstance(obj, bytes):
            try:
                return obj.decode('utf-8')
            except:
                return "<binary_data>"
        return super().default(obj)

def allowed_file(filename):
    return '.' in filename and \
           filename.rsplit('.', 1)[1].lower() in Config.ALLOWED_EXTENSIONS

def generate_timestamp_id():
    """Generates a human-readable unique ID for files."""
    return datetime.now().strftime("%Y%m%d_%H%M%S")

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
    logger.info("✅ Database Connection Pool Initialized (Threaded).")
except Exception as e:
    logger.critical(f"❌ Failed to connect to DB: {e}")
    sys.exit(1)

from contextlib import contextmanager

@contextmanager
def get_db(commit=False):
    """
    Context Manager for DB connections.
    Usage:
        with get_db(commit=True) as (conn, cur):
            cur.execute(...)
    """
    conn = None
    try:
        conn = pg_pool.getconn()
        cur = conn.cursor()
        yield conn, cur
        if commit:
            conn.commit()
    except Exception as e:
        logger.error(f"DB Transaction Error: {e}")
        if conn:
            conn.rollback()
        raise e
    finally:
        if conn:
            cur.close()
            pg_pool.putconn(conn)

def execute_read(query, params=None):
    """Helper for simple SELECT queries."""
    with get_db() as (conn, cur):
        cur.execute(query, params)
        return cur.fetchall()

def execute_write(query, params=None):
    """Helper for simple INSERT/UPDATE queries."""
    with get_db(commit=True) as (conn, cur):
        cur.execute(query, params)
        # Attempt to return ID if it was an INSERT with RETURNING
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
            return jsonify({'error': 'Unauthorized', 'code': 401}), 401
        return f(*args, **kwargs)
    return decorated_function

def require_role(roles: List[str]):
    """
    Decorator to restrict endpoints to specific roles.
    Example: @require_role(['admin', 'manager'])
    """
    def decorator(f):
        @wraps(f)
        def wrapped(*args, **kwargs):
            if 'user_id' not in session:
                return jsonify({'error': 'Unauthorized'}), 401
            
            user_role = session.get('role', 'guest')
            if user_role not in roles and 'admin' not in roles:
                # If admin is not explicitly in list, we assume strict check.
                # Usually admins have access to everything.
                if user_role != 'admin':
                    return jsonify({'error': 'Forbidden: Insufficient privileges'}), 403
            return f(*args, **kwargs)
        return wrapped
    return decorator

def audit_log(action, target_table, target_id, details=None):
    """
    Writes an audit log entry to the audit.access_log table.
    """
    try:
        user_id = session.get('user_id')
        ip = request.remote_addr
        query = """
            INSERT INTO audit.access_log (user_id, action, ip_address, details) 
            VALUES (%s, %s, %s, %s)
        """
        # We run this in a separate short-lived connection or just fire-and-forget logic
        # For simplicity, we use execute_write here but suppress errors
        execute_write(query, (user_id, f"{action}:{target_table}:{target_id}", ip, json.dumps(details) if details else None))
    except Exception as e:
        logger.warning(f"Audit Log Failed: {e}")

# ==============================================================================
# 6. AUTHENTICATION MODULE
# ==============================================================================

@app.route('/api/auth/login', methods=['POST'])
def login():
    """Secure login with session management."""
    data = request.json
    email = data.get('email')
    password = data.get('password')

    if not email or not password:
        return jsonify({'error': 'Email and password required'}), 400

    query = """
        SELECT person_id, first_name, last_name, email, role, password_hash, active 
        FROM core.personnel 
        WHERE email = %s
    """
    
    try:
        with get_db() as (conn, cur):
            cur.execute(query, (email,))
            user = cur.fetchone()

            if not user:
                # Security: Don't reveal if user exists
                time.sleep(0.5) 
                return jsonify({'error': 'Invalid credentials'}), 401

            if not user['active']:
                return jsonify({'error': 'Account is disabled. Contact Admin.'}), 403

            if bcrypt.checkpw(password.encode('utf-8'), user['password_hash'].encode('utf-8')):
                session.clear()
                session.permanent = True
                session['user_id'] = user['person_id']
                session['role'] = user['role']
                session['user_name'] = f"{user['first_name']} {user['last_name']}"
                
                # Update last login
                cur.execute("UPDATE core.personnel SET last_login = NOW() WHERE person_id = %s", (user['person_id'],))
                conn.commit()
                
                audit_log('LOGIN', 'core.personnel', user['person_id'])
                
                return jsonify({
                    'success': True,
                    'user': {
                        'id': user['person_id'],
                        'name': session['user_name'],
                        'role': user['role'],
                        'email': user['email']
                    }
                })
            
            return jsonify({'error': 'Invalid credentials'}), 401
    except Exception as e:
        logger.error(f"Login Error: {e}")
        return jsonify({'error': 'Internal Server Error'}), 500

@app.route('/api/auth/logout', methods=['POST'])
def logout():
    audit_log('LOGOUT', 'core.personnel', session.get('user_id'))
    session.clear()
    return jsonify({'success': True})

@app.route('/api/auth/me', methods=['GET'])
def get_current_user():
    """Returns current session info."""
    if 'user_id' in session:
        return jsonify({
            'authenticated': True,
            'user': {
                'id': session['user_id'],
                'name': session.get('user_name'),
                'role': session.get('role')
            }
        })
    return jsonify({'authenticated': False}), 200

# ==============================================================================
# 7. CORE MODULE: PROJECTS & PERSONNEL
# ==============================================================================

@app.route('/api/core/projects', methods=['GET'])
@login_required
def get_projects():
    """List all projects with summary stats."""
    query = """
        SELECT p.project_id, p.project_name, p.status, p.start_date, 
               p.principal_investigator,
               (SELECT count(*) FROM bio_assets.samples s WHERE s.project_id = p.project_id) as sample_count
        FROM core.projects p
        ORDER BY p.created_at DESC
    """
    data = execute_read(query)
    return jsonify(data)

@app.route('/api/core/projects', methods=['POST'])
@login_required
@require_role(['admin', 'manager'])
def create_project():
    """Create a new project."""
    data = request.json
    try:
        query = """
            INSERT INTO core.projects (project_name, description, status, start_date, principal_investigator)
            VALUES (%s, %s, %s, %s, %s)
            RETURNING project_id
        """
        params = (
            data.get('project_name'),
            data.get('description'),
            data.get('status', 'ACTIVE'),
            data.get('start_date', datetime.now().date()),
            session.get('user_id') # Assign current user as PI if not specified? Or use ID
        )
        res = execute_write(query, params)
        audit_log('CREATE', 'core.projects', res['project_id'], data)
        return jsonify({'success': True, 'project_id': res['project_id']})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/core/personnel', methods=['GET'])
@login_required
def get_personnel():
    """List all users."""
    query = "SELECT person_id, first_name, last_name, email, role, active, last_login FROM core.personnel ORDER BY last_name"
    data = execute_read(query)
    return jsonify(data)

# ==============================================================================
# 8. BIO ASSETS MODULE: SAMPLES & GENEALOGY
# ==============================================================================

@app.route('/api/samples/list', methods=['GET'])
@login_required
def list_samples():
    """
    Advanced Sample Search & List
    Params: page, limit, project_id, species, search_term
    """
    page = int(request.args.get('page', 1))
    limit = int(request.args.get('limit', 50))
    offset = (page - 1) * limit
    
    search_term = request.args.get('search', '')
    project_id = request.args.get('project_id')
    
    where_clauses = ["1=1"]
    params = []
    
    if search_term:
        where_clauses.append("(s.sample_name ILIKE %s OR s.species ILIKE %s OR s.sample_type ILIKE %s)")
        term = f"%{search_term}%"
        params.extend([term, term, term])
        
    if project_id:
        where_clauses.append("s.project_id = %s")
        params.append(project_id)
        
    where_sql = " AND ".join(where_clauses)
    
    query = f"""
        SELECT s.*, p.project_name, 
               st.storage_label, st.parent_path
        FROM bio_assets.samples s
        LEFT JOIN core.projects p ON s.project_id = p.project_id
        LEFT JOIN lims.storage_locations st ON s.storage_loc_id = st.location_id
        WHERE {where_sql}
        ORDER BY s.created_at DESC
        LIMIT %s OFFSET %s
    """
    
    count_query = f"SELECT count(*) as total FROM bio_assets.samples s WHERE {where_sql}"
    
    try:
        with get_db() as (conn, cur):
            cur.execute(count_query, params)
            total = cur.fetchone()['total']
            
            cur.execute(query, params + [limit, offset])
            rows = cur.fetchall()
            
        return jsonify({
            'data': rows,
            'meta': {
                'total': total,
                'page': page,
                'pages': math.ceil(total/limit)
            }
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/samples', methods=['POST'])
@login_required
def create_sample():
    """Create a single sample."""
    data = request.json
    required = ['sample_name', 'project_id', 'sample_type']
    if not all(k in data for k in required):
        return jsonify({'error': 'Missing required fields'}), 400
        
    try:
        # Check duplicate name in project
        exists_q = "SELECT sample_id FROM bio_assets.samples WHERE sample_name = %s AND project_id = %s"
        existing = execute_read(exists_q, (data['sample_name'], data['project_id']))
        if existing:
            return jsonify({'error': 'Sample name already exists in this project'}), 409

        query = """
            INSERT INTO bio_assets.samples 
            (sample_name, alt_name, sample_type, species, collection_date, 
             project_id, storage_loc_id, parent_sample_id, comments, created_by)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING sample_id
        """
        params = (
            data['sample_name'],
            data.get('alt_name'),
            data['sample_type'],
            data.get('species'),
            data.get('collection_date'),
            data['project_id'],
            data.get('storage_loc_id'),
            data.get('parent_sample_id'),
            data.get('comments'),
            session['user_id']
        )
        res = execute_write(query, params)
        audit_log('CREATE', 'bio_assets.samples', res['sample_id'])
        return jsonify({'success': True, 'sample_id': res['sample_id']})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/samples/<uuid:sample_id>', methods=['GET'])
@login_required
def get_sample_details(sample_id):
    """
    Get full details including genealogy (parents/children) and history.
    """
    try:
        with get_db() as (conn, cur):
            # 1. Main Data
            cur.execute("""
                SELECT s.*, p.project_name, st.storage_label, st.location_type
                FROM bio_assets.samples s
                LEFT JOIN core.projects p ON s.project_id = p.project_id
                LEFT JOIN lims.storage_locations st ON s.storage_loc_id = st.location_id
                WHERE s.sample_id = %s
            """, (str(sample_id),))
            sample = cur.fetchone()
            
            if not sample:
                return jsonify({'error': 'Not Found'}), 404

            # 2. Children (Sub-samples)
            cur.execute("""
                SELECT sample_id, sample_name, sample_type, created_at 
                FROM bio_assets.samples 
                WHERE parent_sample_id = %s
            """, (str(sample_id),))
            children = cur.fetchall()

            # 3. Bio-analyses (BiologyFish)
            cur.execute("""
                SELECT measurement_id, measurement_type, value_num, unit
                FROM biologyfish.measurements
                WHERE sample_id = %s
            """, (str(sample_id),))
            measurements = cur.fetchall()
            
            # 4. Molecular Data
            cur.execute("""
                SELECT lib_id, library_name, index_i7, index_i5
                FROM moleculargenetics.library
                WHERE sample_id = %s
            """, (str(sample_id),))
            libraries = cur.fetchall()

            sample['children'] = children
            sample['measurements'] = measurements
            sample['libraries'] = libraries
            
            return jsonify(sample)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# ==============================================================================
# 9. STORAGE MODULE: SMART LOCATION MANAGEMENT
# ==============================================================================

@app.route('/api/storage/tree', methods=['GET'])
@login_required
def get_storage_tree():
    """
    Returns hierarchical storage data for UI Tree View.
    Uses Common Table Expression (CTE) or ltree if enabled, 
    here we use simple parent_id recursion logic or flattened list.
    """
    # Optimized: Get all locations, frontend builds tree
    query = """
        SELECT location_id, storage_label, location_type, parent_location_id, is_full
        FROM lims.storage_locations
        ORDER BY parent_location_id NULLS FIRST, storage_label
    """
    data = execute_read(query)
    return jsonify(data)

@app.route('/api/storage/box/<uuid:box_id>', methods=['GET'])
@login_required
def get_box_grid(box_id):
    """
    Returns a grid representation of a box (e.g., 9x9 or 8x12).
    """
    try:
        # Get Box Definition
        box_q = "SELECT location_id, storage_label, dimension_x, dimension_y FROM lims.storage_locations WHERE location_id = %s"
        box = execute_read(box_q, (str(box_id),))
        if not box: return jsonify({'error': 'Box not found'}), 404
        box = box[0]

        # Get Samples in this box
        samples_q = """
            SELECT sample_id, sample_name, box_position_x, box_position_y 
            FROM bio_assets.samples 
            WHERE storage_loc_id = %s
        """
        samples = execute_read(samples_q, (str(box_id),))
        
        # Construct Grid
        grid = []
        # Index samples by coordinate "X:Y"
        sample_map = {f"{s['box_position_x']}:{s['box_position_y']}": s for s in samples}

        return jsonify({
            'box_info': box,
            'samples': samples, # List format better for React
            'stats': {
                'total_slots': (box['dimension_x'] or 0) * (box['dimension_y'] or 0),
                'occupied': len(samples)
            }
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/storage/find_spot', methods=['POST'])
@login_required
def find_empty_spot():
    """
    Smart Function: Find first empty spot in a specific Freezer or Shelf.
    """
    parent_id = request.json.get('location_id')
    # Logic: Find boxes under this parent, check their capacity, return first slot.
    # This is a complex query simplified here.
    return jsonify({'message': 'Not implemented yet, requires complex recursion'})

# ==============================================================================
# 10. MOLECULAR WORKFLOW (Extraction -> Library -> Seq)
# ==============================================================================

@app.route('/api/molecular/extractions', methods=['POST'])
@login_required
def create_extraction_batch():
    """
    Batch process: DNA Extraction from Tissue Samples.
    Creates new 'DNA' samples from 'TISSUE' samples.
    """
    data = request.json
    source_sample_ids = data.get('sample_ids', [])
    protocol_id = data.get('protocol_id')
    
    if not source_sample_ids:
        return jsonify({'error': 'No samples provided'}), 400

    created_ids = []
    errors = []

    try:
        with get_db(commit=True) as (conn, cur):
            for sid in source_sample_ids:
                # 1. Get Source Info
                cur.execute("SELECT sample_name, project_id, species FROM bio_assets.samples WHERE sample_id = %s", (sid,))
                src = cur.fetchone()
                if not src:
                    errors.append(f"Sample {sid} not found")
                    continue
                
                # 2. Create DNA Entry
                new_name = f"{src['sample_name']}_DNA"
                cur.execute("""
                    INSERT INTO bio_assets.samples 
                    (sample_name, sample_type, parent_sample_id, project_id, species, created_by)
                    VALUES (%s, 'DNA', %s, %s, %s, %s)
                    RETURNING sample_id
                """, (new_name, sid, src['project_id'], src['species'], session['user_id']))
                new_sample = cur.fetchone()
                created_ids.append(new_sample['sample_id'])
                
                # 3. Log Extraction Event (Optional: dedicated extraction table)
                # cur.execute("INSERT INTO moleculargenetics.extractions ...")

        return jsonify({'success': True, 'created': len(created_ids), 'ids': created_ids, 'errors': errors})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/molecular/libraries', methods=['GET'])
@login_required
def list_libraries():
    """List prepared libraries ready for sequencing."""
    query = """
        SELECT l.*, s.sample_name, p.project_name
        FROM moleculargenetics.library l
        JOIN bio_assets.samples s ON l.sample_id = s.sample_id
        JOIN core.projects p ON s.project_id = p.project_id
        ORDER BY l.prep_date DESC
    """
    return jsonify(execute_read(query))

# ==============================================================================
# 11. BIOINFORMATICS MODULE
# ==============================================================================

@app.route('/api/bioinfo/jobs', methods=['GET', 'POST'])
@login_required
def manage_bioinfo_jobs():
    """
    GET: List active jobs.
    POST: Submit a new analysis job (mock).
    """
    if request.method == 'GET':
        query = """
            SELECT job_id, job_name, status, submitted_at, completed_at, 
                   (SELECT count(*) FROM bioinformatics.assignments a WHERE a.job_id = j.job_id) as sample_count
            FROM bioinformatics.jobs j
            ORDER BY submitted_at DESC
        """
        # Note: bioinformatics.jobs table might need creation in SQL if not exists, 
        # using generic structure here based on assignments
        
        # Fallback if jobs table doesn't exist, query assignments
        query_alt = """
            SELECT 'JOB-' || assignment_id as job_id, status, analysis_date 
            FROM bioinformatics.assignments 
            ORDER BY analysis_date DESC LIMIT 50
        """
        return jsonify(execute_read(query_alt))

    if request.method == 'POST':
        # Submit Job
        data = request.json
        # Mocking job submission to a cluster/cloud
        job_id = str(uuid.uuid4())
        return jsonify({'success': True, 'job_id': job_id, 'status': 'QUEUED', 'message': 'Sent to HPC Cluster'})

# ==============================================================================
# 12. ELN (ELECTRONIC LAB NOTEBOOK) MODULE
# ==============================================================================

@app.route('/api/eln/entries', methods=['GET'])
@login_required
def get_eln_entries():
    """Get recent notebook entries."""
    user_id = session['user_id']
    query = """
        SELECT entry_id, title, created_at, tags 
        FROM eln.entries 
        WHERE author_id = %s OR is_public = true
        ORDER BY created_at DESC
    """
    return jsonify(execute_read(query, (user_id,)))

@app.route('/api/eln/entry', methods=['POST'])
@login_required
def save_eln_entry():
    """
    Save a rich-text entry with JSONB data.
    """
    data = request.json
    title = data.get('title')
    content_json = data.get('content') # DraftJS or QuillJS JSON output
    tags = data.get('tags', [])
    
    query = """
        INSERT INTO eln.entries (title, content_data, tags, author_id, created_at)
        VALUES (%s, %s, %s, %s, NOW())
        RETURNING entry_id
    """
    try:
        res = execute_write(query, (title, json.dumps(content_json), tags, session['user_id']))
        return jsonify({'success': True, 'entry_id': res['entry_id']})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# ==============================================================================
# 13. BOOKING & CALENDAR MODULE
# ==============================================================================

@app.route('/api/booking/instruments', methods=['GET'])
@login_required
def get_instruments():
    """List instruments available for booking."""
    return jsonify(execute_read("SELECT * FROM lims.instruments WHERE active = true"))

@app.route('/api/booking/events', methods=['GET'])
@login_required
def get_calendar_events():
    """
    Get bookings for a date range.
    Params: start, end
    """
    start = request.args.get('start')
    end = request.args.get('end')
    query = """
        SELECT b.booking_id, b.start_time, b.end_time, i.instrument_name, 
               p.first_name || ' ' || p.last_name as user_name
        FROM lims.bookings b
        JOIN lims.instruments i ON b.instrument_id = i.instrument_id
        JOIN core.personnel p ON b.user_id = p.person_id
        WHERE b.start_time >= %s AND b.end_time <= %s
    """
    # Simple validation needed for dates
    return jsonify(execute_read(query, (start, end)))

@app.route('/api/booking/create', methods=['POST'])
@login_required
def create_booking():
    """
    Smart Booking: Check for conflicts before inserting.
    """
    data = request.json
    inst_id = data['instrument_id']
    start_str = data['start'] # ISO format
    end_str = data['end']
    
    # Conflict Check
    conflict_q = """
        SELECT booking_id FROM lims.bookings 
        WHERE instrument_id = %s 
        AND (
            (start_time <= %s AND end_time >= %s) OR
            (start_time <= %s AND end_time >= %s)
        )
    """
    if execute_read(conflict_q, (inst_id, start_str, start_str, end_str, end_str)):
        return jsonify({'error': 'Time slot already booked'}), 409
        
    query = """
        INSERT INTO lims.bookings (instrument_id, user_id, start_time, end_time, title)
        VALUES (%s, %s, %s, %s, %s)
        RETURNING booking_id
    """
    res = execute_write(query, (inst_id, session['user_id'], start_str, end_str, data.get('title', 'Booking')))
    return jsonify({'success': True, 'booking_id': res['booking_id']})

# ==============================================================================
# 14. FILE MANAGEMENT
# ==============================================================================

@app.route('/api/files/upload', methods=['POST'])
@login_required
def upload_file():
    """
    General purpose file uploader.
    Saves to disk and logs in 'core.files' (if table exists) or returns path.
    """
    if 'file' not in request.files:
        return jsonify({'error': 'No file'}), 400
    
    file = request.files['file']
    if file.filename == '':
        return jsonify({'error': 'No filename'}), 400
        
    if file and allowed_file(file.filename):
        filename = secure_filename(file.filename)
        # Unique name
        unique_name = f"{uuid.uuid4()}_{filename}"
        save_path = os.path.join(Config.UPLOAD_FOLDER, unique_name)
        file.save(save_path)
        
        return jsonify({
            'success': True,
            'filename': filename,
            'stored_name': unique_name,
            'path': save_path
        })
    return jsonify({'error': 'File type not allowed'}), 400

# ==============================================================================
# 15. SEARCH & REPORTING
# ==============================================================================

@app.route('/api/search/global', methods=['GET'])
@login_required
def global_search():
    """
    Enterprise Search: Queries multiple tables using UNION.
    """
    q = request.args.get('q', '')
    if len(q) < 2: return jsonify([])
    
    term = f"%{q}%"
    query = """
        SELECT 'Sample' as type, sample_name as label, sample_id::text as id, '/samples/' || sample_id as link 
        FROM bio_assets.samples WHERE sample_name ILIKE %s
        UNION ALL
        SELECT 'Project' as type, project_name as label, project_id::text as id, '/projects/' || project_id as link 
        FROM core.projects WHERE project_name ILIKE %s
        UNION ALL
        SELECT 'Person' as type, last_name || ', ' || first_name as label, person_id::text as id, '/users/' || person_id as link 
        FROM core.personnel WHERE last_name ILIKE %s OR email ILIKE %s
        LIMIT 20
    """
    return jsonify(execute_read(query, (term, term, term, term)))

@app.route('/api/reports/export_csv', methods=['POST'])
@login_required
def export_csv():
    """
    Generic CSV Export for datasets.
    """
    data = request.json
    table = data.get('table')
    if table not in ['samples', 'projects', 'library']:
        return jsonify({'error': 'Invalid table'}), 400
        
    # Security: whitelist columns or use predefined views
    if table == 'samples':
        query = "SELECT * FROM bio_assets.samples LIMIT 1000"
    
    rows = execute_read(query)
    if not rows:
        return jsonify({'error': 'No data'}), 404
        
    # Generate CSV in memory
    si = io.StringIO()
    cw = csv.writer(si)
    cw.writerow(rows[0].keys())
    for r in rows:
        cw.writerow(r.values())
        
    output = make_response(si.getvalue())
    output.headers["Content-Disposition"] = f"attachment; filename=export_{table}.csv"
    output.headers["Content-type"] = "text/csv"
    return output

# ==============================================================================
# 16. SERVER ENTRY
# ==============================================================================

@app.errorhandler(404)
def not_found(e):
    return jsonify({'error': 'Endpoint not found'}), 404

@app.errorhandler(500)
def server_error(e):
    logger.error(f"500 Error: {e}")
    return jsonify({'error': 'Internal Server Error'}), 500

if __name__ == '__main__':
    print("="*80)
    print(f" GENFISH ENTERPRISE LIMS v5.0 STARTING")
    print(f" Database: {Config.DB_HOST}:{Config.DB_PORT}/{Config.DB_NAME}")
    print(f" Pool Size: {Config.DB_MIN_CONN} - {Config.DB_MAX_CONN}")
    print(f" Modules: Core, BioAssets, Storage, Molecular, BioInfo, ELN, Booking")
    print("="*80)
    
    # Production Serving
    from waitress import serve
    serve(app, host='0.0.0.0', port=5000, threads=8)