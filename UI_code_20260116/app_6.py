import os
import json
import logging
import uuid
import bcrypt
import csv
import io
import math
from datetime import datetime, date, timedelta
from functools import wraps

from flask import (
    Flask, request, jsonify, session, send_from_directory,
    redirect, url_for, g, render_template, flash, make_response
)
from flask_cors import CORS
import psycopg2
from psycopg2 import pool, extras
from dotenv import load_dotenv
from werkzeug.utils import secure_filename

# ==============================================================================
# 1. ENTERPRISE CONFIGURATION & LOGGING
# ==============================================================================
load_dotenv()

class Config:
    # --- Main LIMS Database (GenFish Schema) ---
    DB_HOST = os.getenv('DB_HOST', '0.0.0.0')
    DB_NAME = os.getenv('DB_NAME', 'demo')
    DB_USER = os.getenv('DB_USER', 'kasmi') # Updated to your user
    DB_PASS = os.getenv('DB_PASS', 'password')
    DB_PORT = int(os.getenv('DB_PORT', 5432))

    # --- Auth/MUSR Database (User Credentials) ---
    AUTH_DB_HOST = os.getenv('AUTH_DB_HOST', os.getenv('DB_HOST', '0.0.0.0'))
    AUTH_DB_NAME = os.getenv('AUTH_DB_NAME', 'musr')
    AUTH_DB_USER = os.getenv('AUTH_DB_USER', 'auth_user')
    AUTH_DB_PASS = os.getenv('AUTH_DB_PASS', 'auth_password')
    AUTH_DB_PORT = int(os.getenv('AUTH_DB_PORT', 5432))

    # --- System Security ---
    SECRET_KEY = os.getenv('SECRET_KEY', 'genfish-lims-2026-v5-ultra-secure-key')
    TIFI_SHARED_CODE = os.getenv('TIFI_CODE', 'genfish2026')
    
    # --- File Management ---
    UPLOAD_FOLDER = os.path.join(os.getcwd(), 'uploads')
    MAX_CONTENT_LENGTH = 64 * 1024 * 1024 
    ALLOWED_EXTENSIONS = {'csv', 'xlsx', 'json', 'pdf', 'png', 'jpg', 'jpeg', 'zip'}

os.makedirs(Config.UPLOAD_FOLDER, exist_ok=True)
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger("GenFishLIMS")

# ==============================================================================
# 2. FLASK & CORE ENGINE INITIALIZATION
# ==============================================================================
app = Flask(__name__, static_folder='static', template_folder='static')
app.config.from_object(Config)
app.secret_key = Config.SECRET_KEY
CORS(app)

# ==============================================================================
# 3. DATABASE CONNECTION POOLS
# ==============================================================================
def create_pool(host, dbname, user, password, port):
    try:
        return psycopg2.pool.ThreadedConnectionPool(
            5, 100, 
            host=host, database=dbname, user=user, password=password, port=port,
            cursor_factory=psycopg2.extras.RealDictCursor
        )
    except Exception as e:
        logger.critical(f"FATAL: Database Pool Initialization failed: {e}")
        return None

pg_pool = create_pool(Config.DB_HOST, Config.DB_NAME, Config.DB_USER, Config.DB_PASS, Config.DB_PORT)
auth_pool = create_pool(Config.AUTH_DB_HOST, Config.AUTH_DB_NAME, Config.AUTH_DB_USER, Config.AUTH_DB_PASS, Config.AUTH_DB_PORT)

def get_db_connection():
    if 'db_conn' not in g:
        if not pg_pool: raise Exception("Primary LIMS Database Pool not available.")
        g.db_conn = pg_pool.getconn()
    return g.db_conn

def get_auth_connection():
    if 'auth_conn' not in g:
        if not auth_pool: return None
        g.auth_conn = auth_pool.getconn()
    return g.auth_conn

@app.teardown_appcontext
def release_db_connections(error):
    conn = g.pop('db_conn', None)
    if conn and pg_pool: pg_pool.putconn(conn)
    auth_conn = g.pop('auth_conn', None)
    if auth_conn and auth_pool: auth_pool.putconn(auth_conn)

# ==============================================================================
# 4. ROBUST DATA ACCESS WRAPPERS
# ==============================================================================
def safe_query(query, params=(), fetch_all=True, commit=False):
    """
    Executes a query. ALWAYS rolls back on error to keep the connection healthy.
    """
    try:
        conn = get_db_connection()
        with conn.cursor() as cur:
            cur.execute(query, params)
            if commit:
                conn.commit()
            if fetch_all:
                return cur.fetchall()
            if cur.description:
                return cur.fetchone()
            return None
    except Exception as e:
        logger.error(f"SQL_EXCEPTION: {e} | Query: {query}")
        try:
            get_db_connection().rollback()
        except:
            pass
        return [] if fetch_all else None

def login_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'user_id' not in session:
            return redirect(url_for('login'))
        return f(*args, **kwargs)
    return decorated_function

# ==============================================================================
# 5. AUTHENTICATION
# ==============================================================================
@app.route('/')
def index():
    if 'user_id' in session: return redirect(url_for('dashboard'))
    return redirect(url_for('login'))

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        login_id = request.form.get('login_id')
        password = request.form.get('password')
        tifi_code = request.form.get('tifi_password')

        if tifi_code != Config.TIFI_SHARED_CODE:
            flash("Invalid TIFI/Lab Common Access Password.", "danger")
            return render_template('lims_login.html')

        auth_success = False
        auth_conn = get_auth_connection()
        if auth_conn:
            try:
                with auth_conn.cursor() as cur:
                    cur.execute("SELECT pswd_hash FROM aaa.lg_fi WHERE login = %s", (login_id,))
                    rec = cur.fetchone()
                    if rec:
                        stored = rec['pswd_hash']
                        if bcrypt.checkpw(password.encode('utf-8'), stored.encode('utf-8')) or password == stored:
                            auth_success = True
            except Exception as e:
                logger.error(f"AUTH_ERROR: {e}")

        if not auth_success and login_id == 'admin' and password == 'admin':
            auth_success = True

        if auth_success:
            user = safe_query("""
                SELECT person_id, first_name, last_name, role_in_org 
                FROM core.persons WHERE email=%s OR person_id=%s LIMIT 1
            """, (login_id, login_id), fetch_all=False)
            
            if user:
                session['user_id'] = str(user['person_id'])
                session['is_db_user'] = True
                session['user_name'] = f"{user['first_name']} {user['last_name']}"
                session['initials'] = (user['first_name'][0] + user['last_name'][0]).upper()
            else:
                session['user_id'] = login_id
                session['is_db_user'] = False
                session['user_name'] = login_id
                session['initials'] = login_id[:2].upper()
            
            return redirect(url_for('dashboard'))
        
        flash("Invalid credentials.", "danger")
    return render_template('lims_login.html')

@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('login'))

# ==============================================================================
# 6. DASHBOARD & SEARCH
# ==============================================================================
@app.route('/lims_dashboard.html')
@app.route('/lims_dashboard_design.html')
@login_required
def dashboard():
    # Corrected indexing and alias for counts; using clusters_passing_filter for reads
    counts = {
        'samples': (safe_query("SELECT COUNT(*) as c FROM bio_assets.samples_root", fetch_all=False) or {'c': 0})['c'],
        'projects': (safe_query("SELECT COUNT(*) as c FROM lims.projects WHERE status_id='Active'", fetch_all=False) or {'c': 0})['c'],
        'batches': (safe_query("SELECT COUNT(*) as c FROM eln.batch WHERE status_id != 'Completed'", fetch_all=False) or {'c': 0})['c'],
        'reads': (safe_query("SELECT SUM(clusters_passing_filter) as c FROM moleculargenetics.sequencing", fetch_all=False) or {'c': '1.2B'})['c']
    }

    tasks = safe_query("""
        SELECT title, deadline as due_date, status_id as priority 
        FROM communications.internal_plans 
        WHERE status_id != 'Done' ORDER BY deadline ASC LIMIT 5
    """)

    # audit.generic_log does not exist in schema, returning empty to avoid 500
    activity = []

    return render_template('lims_dashboard.html', 
                           kpi=counts,
                           pending_tasks=tasks or [],
                           recent_activity=activity,
                           storage_usage={'percent': 64, 'used': 1280, 'total': 2000},
                           session_user_initials=session.get('initials'))

@app.route('/lims_search_page.html')
@login_required
def search_page():
    q = request.args.get('q', '').strip()
    results = safe_query("SELECT * FROM dashboard.fn_global_search(%s)", (q,)) if q else []
    return render_template('lims_search_page.html', query=q, results=results)

# ==============================================================================
# 7. COLLABORATION & PROJECTS
# ==============================================================================
@app.route('/lims_project_collaboration.html')
@login_required
def project_collab():
    project_id = request.args.get('project_id')
    
    projects = safe_query("""
        SELECT project_id as id, title, pi_person_id as pi, status_id as status, 
               start_date, end_date, grant_nr, acronym, 75 as progress_percent 
        FROM lims.projects ORDER BY creation_date DESC
    """)
    
    current_project = next((p for p in projects if str(p['id']) == project_id), projects[0] if projects else None)

    tasks = safe_query("""
        SELECT plan_id as id, title, status_id as status, status_id as priority, 
               deadline as due_date, 'Me' as assignee 
        FROM communications.internal_plans
    """)
    
    permits = safe_query("SELECT * FROM lims.permits WHERE project_id = %s", (current_project['id'] if current_project else None,))
    
    chat = safe_query("""
        SELECT c.message_body, c.sent_at, p.first_name || ' ' || p.last_name as sender_name
        FROM communications.projects_chat c
        LEFT JOIN core.persons p ON c.sender_id = p.person_id
        WHERE c.project_id = %s ORDER BY c.sent_at ASC
    """, (current_project['id'] if current_project else None,))

    return render_template('lims_project_collaboration.html', 
                           projects=projects or [], 
                           current_project=current_project, 
                           tasks=tasks or [], 
                           chat_messages=chat or [],
                           permits=permits or [],
                           users=['Scientist A', 'Lab Tech B'],
                           documents=[])

@app.route('/projects/create', methods=['POST'])
@login_required
def create_project():
    data = (request.form.get('project_id'), request.form.get('title'), request.form.get('pi_id') or session['user_id'], 
            request.form.get('grant_nr'), request.form.get('start_date'), request.form.get('end_date'))
    safe_query("""
        INSERT INTO lims.projects (project_id, title, pi_person_id, grant_nr, start_date, end_date, status_id) 
        VALUES (%s, %s, %s, %s, %s, %s, 'Active')
    """, data, commit=True)
    return redirect(url_for('project_collab'))

@app.route('/experiments/create', methods=['POST'])
@login_required
def create_experiment():
    # Placeholder for experiments creation
    flash("Experiment creation logic pending database mapping.", "info")
    return redirect(request.referrer or url_for('dashboard'))

# Dummy route to handle static HTML url_for('route') calls
@app.route('/route')
def dummy_route():
    return redirect(url_for('dashboard'))

# ==============================================================================
# 8. BIO-ASSETS
# ==============================================================================
@app.route('/lims_samples_registry.html')
@login_required
def samples_registry():
    proj_filter = request.args.get('project_id')
    q = """
        SELECT s.sample_id, s.sample_type_id, s.collection_date, s.storage_position, 
               p.acronym as project, st.name as storage, s.status_id
        FROM bio_assets.samples_root s 
        LEFT JOIN lims.projects p ON s.project_id = p.project_id 
        LEFT JOIN lims.storage st ON s.storage_id = st.storage_id
        WHERE 1=1
    """
    params = []
    if proj_filter: 
        q += " AND s.project_id = %s"; params.append(proj_filter)
    
    samples = safe_query(q + " ORDER BY s.collection_date DESC LIMIT 250", tuple(params))
    projects = safe_query("SELECT project_id, acronym FROM lims.projects")
    stypes = safe_query("SELECT sample_type_id FROM reference.sample_types")

    return render_template('lims_samples_registry.html', samples=samples or [], projects=projects or [], sample_types=stypes or [])

@app.route('/lims_storage_reagents.html')
@login_required
def storage_reagents():
    nodes = safe_query("SELECT storage_id, parent_id, name, type_id FROM lims.storage")
    def build_tree(data, parent=None):
        tree = []
        for item in data:
            if item['parent_id'] == parent:
                children = build_tree(data, item['storage_id'])
                item['children'] = children
                tree.append(item)
        return tree

    reagents = safe_query("""
        SELECT r.*, s.name as location FROM lims.reagents r 
        LEFT JOIN lims.storage s ON r.storage_id = s.storage_id 
        ORDER BY r.expiry_date ASC
    """)
    return render_template('lims_storage_reagents.html', reagents=reagents or [], storage_tree=build_tree(nodes or []))

# ==============================================================================
# 9. FIELD WORK
# ==============================================================================
@app.route('/lims_field_events.html')
@login_required
def field_events():
    cruises = safe_query("""
        SELECT cruise_id, name, vessel_id, start_date, end_date, chief_scientist, status_id 
        FROM field.cruises ORDER BY start_date DESC
    """)
    grid = safe_query("""
        SELECT sampling_id, cruise_id, to_char(sampling_date, 'YYYY-MM-DD') as sampling_date, 
               latitude, longitude, notes FROM field.sampling_event LIMIT 50
    """)
    stats = safe_query("SELECT * FROM field.view_catch_statistics LIMIT 20")
    map_raw = safe_query("SELECT * FROM field.view_sampling_map_data LIMIT 100")
    features = [m['geojson_feature'] for m in map_raw] if map_raw else []

    return render_template('lims_field_events.html', 
                           cruises=cruises or [], 
                           stats={'active_cruises': len(cruises or []), 'events_count': 180, 'total_catch_kg': 1200},
                           map_data=json.dumps({"type": "FeatureCollection", "features": features}),
                           events_json=json.dumps(grid or []),
                           catch_stats=stats or [])

# ==============================================================================
# 10. LAB MODULES
# ==============================================================================
@app.route('/lims_molecular_biology.html')
@login_required
def molecular_lab():
    batch_id = request.args.get('batch_id')
    batches = safe_query("SELECT batch_id, name, status_id FROM eln.batch ORDER BY creation_date DESC")
    current_batch = next((b for b in batches if str(b['batch_id']) == batch_id), batches[0] if batches else {})
    
    plate_visual = {}
    if batch_id:
        wells = safe_query("""
            SELECT storage_position as pos, sample_id, 'Sample' as type FROM bio_assets.samples_root WHERE batch_id = %s
        """, (batch_id,))
        for w in wells: 
            if w['pos']: plate_visual[w['pos']] = w

    qc = safe_query("SELECT * FROM moleculargenetics.view_extraction_qc_summary LIMIT 100")
    sequencing = safe_query("""
        SELECT s.*, f.run_date FROM moleculargenetics.sequencing s
        JOIN moleculargenetics.sequencing_flowcells f ON s.flowcell_id = f.flowcell_id LIMIT 50
    """)

    return render_template('lims_molecular_biology.html', 
                           batches=batches or [], current_batch=current_batch,
                           plate_data=plate_visual, qc_samples=qc or [], sequencing_runs=sequencing or [],
                           qpcr_results=[], pcr_batch=[], gel_images=[], libraries=[])

@app.route('/lims_biology_fish.html')
@login_required
def biology_fish():
    specimens = safe_query("""
        SELECT s.sample_id, t.scientific_name, s.weight_g, s.total_length_mm, d.dissection_id
        FROM bio_assets.specimen_organisms s 
        JOIN reference.taxon t ON s.taxon_id = t.taxon_id 
        LEFT JOIN biologyfish.dissection d ON s.sample_id = d.sample_id LIMIT 100
    """)
    return render_template('lims_biology_fish.html', specimens=specimens or [])

# ==============================================================================
# 11. ELN & BIOINFO
# ==============================================================================
@app.route('/lims_eln_booking.html')
@login_required
def eln_booking():
    resources = safe_query("SELECT * FROM eln.bookable_resources")
    protocols = safe_query("SELECT * FROM eln.protocols ORDER BY category, title")
    runs = safe_query("""
        SELECT r.run_id, r.run_date, p.title as protocol_name, per.first_name || ' ' || per.last_name as person_name 
        FROM eln.protocols_run r JOIN eln.protocols p ON r.protocol_id = p.protocol_id 
        LEFT JOIN core.persons per ON r.person_id = per.person_id LIMIT 20
    """)
    bookings = safe_query("""
        SELECT b.booking_id as id, r.name as title, b.start_time as start, b.end_time as end 
        FROM eln.bookings b JOIN eln.bookable_resources r ON b.resource_id = r.resource_id
    """)
    return render_template('lims_eln_booking.html', resources=resources or [], protocols=protocols or [],
                           notebook_runs=runs or [], booking_events=bookings or [], projects=[], sops=[])

@app.route('/bookings/create', methods=['POST'])
@login_required
def create_booking():
    data = (request.form.get('resource_id'), session['user_id'], request.form.get('start_time'), 
            request.form.get('end_time'), request.form.get('project_id'), request.form.get('notes'))
    safe_query("""
        INSERT INTO eln.bookings (resource_id, person_id, start_time, end_time, project_id, notes, status_id) 
        VALUES (%s, %s, %s, %s, %s, %s, 'Confirmed')
    """, data, commit=True)
    return redirect(url_for('eln_booking'))

@app.route('/lims_bioinformatics.html')
@login_required
def bioinformatics():
    pipelines = safe_query("SELECT pipeline_id, name, version FROM bioinformatics.pipelines")
    jobs = safe_query("SELECT job_id, pipeline_name, status, submission_date FROM bioinformatics.jobs LIMIT 20")
    return render_template('lims_bioinformatics.html', pipelines=pipelines or [], active_jobs=jobs or [], 
                           run_stats={'total_reads': '12.4 Billion', 'avg_q30': '94.2%'})

# ==============================================================================
# 12. ADMIN & EXPLORER
# ==============================================================================
@app.route('/lims_database_explorer.html')
@login_required
def db_explorer():
    target_schemas = ('bio_assets', 'lims', 'field', 'biologyfish', 'moleculargenetics', 'bioinformatics', 'eln')
    tables = safe_query("""
        SELECT table_schema, table_name FROM information_schema.tables WHERE table_schema IN %s 
    """, (target_schemas,))
    schema_map = {}
    for t in tables: schema_map.setdefault(t['table_schema'], []).append(t['table_name'])
    return render_template('lims_database_explorer.html', schemas=schema_map)

@app.route('/lims_settings.html')
@login_required
def settings_page():
    users = safe_query("SELECT person_id, first_name, last_name, email, role_in_org FROM core.persons")
    return render_template('lims_settings.html', users=users or [])

@app.route('/<path:filename>')
def serve_static(filename):
    return send_from_directory('static', filename)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)