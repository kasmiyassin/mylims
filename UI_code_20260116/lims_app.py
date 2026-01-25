import os
import json
import decimal
import datetime
import pandas as pd
import psycopg2
from psycopg2.extras import RealDictCursor
from flask import Flask, render_template, request, redirect, url_for, flash, jsonify, session, g, send_file
from flask_login import LoginManager, UserMixin, login_user, login_required, logout_user, current_user
from werkzeug.security import check_password_hash, generate_password_hash
from werkzeug.utils import secure_filename

# ==========================================
# CONFIGURATION
# ==========================================
class Config:
    # Security
    SECRET_KEY = os.getenv('SECRET_KEY', 'genfish-secret-key-2026')
    TIFI_COMMON_PASS = os.getenv('TIFI_PASS', 'admin') # Shared Secret
    
    # File Uploads
    UPLOAD_FOLDER = os.path.join(os.getcwd(), 'uploads')
    MAX_CONTENT_LENGTH = 16 * 1024 * 1024 # 16MB

    # Database 1: Main LIMS Data (mylims)
    DB_HOST = os.getenv('DB_HOST', 'localhost')
    DB_NAME = os.getenv('DB_NAME', 'mylims')
    DB_USER = os.getenv('DB_USER', 'web_admin')
    DB_PASS = os.getenv('DB_PASS', 'password')

    # Database 2: Authentication (musr)
    AUTH_HOST = os.getenv('AUTH_DB_HOST', 'localhost')
    AUTH_NAME = os.getenv('AUTH_DB_NAME', 'musr')
    AUTH_USER = os.getenv('AUTH_DB_USER', 'auth_user')
    AUTH_PASS = os.getenv('AUTH_DB_PASS', 'auth_password')

# ==========================================
# APP SETUP
# ==========================================
app = Flask(__name__, template_folder='templates', static_folder='static')
app.config.from_object(Config)
os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)

login_manager = LoginManager()
login_manager.init_app(app)
login_manager.login_view = 'login'

# --- JSON SERIALIZER ---
class CustomJSONEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, (datetime.date, datetime.datetime)):
            return obj.isoformat()
        if isinstance(obj, decimal.Decimal):
            return float(obj)
        return super().default(obj)
app.json_encoder = CustomJSONEncoder

# ==========================================
# DATABASE HELPERS
# ==========================================
def get_lims_db():
    if 'db_lims' not in g:
        g.db_lims = psycopg2.connect(
            host=app.config['DB_HOST'], database=app.config['DB_NAME'],
            user=app.config['DB_USER'], password=app.config['DB_PASS'],
            cursor_factory=RealDictCursor
        )
    return g.db_lims

def get_auth_db():
    if 'db_auth' not in g:
        g.db_auth = psycopg2.connect(
            host=app.config['AUTH_HOST'], database=app.config['AUTH_NAME'],
            user=app.config['AUTH_USER'], password=app.config['AUTH_PASS'],
            cursor_factory=RealDictCursor
        )
    return g.db_auth

@app.teardown_appcontext
def close_dbs(error):
    if 'db_lims' in g: g.db_lims.close()
    if 'db_auth' in g: g.db_auth.close()

def query_db(db_func, query, args=(), one=False):
    conn = db_func()
    with conn.cursor() as cur:
        cur.execute(query, args)
        rv = cur.fetchall()
    return (rv[0] if rv else None) if one else rv

def execute_db(db_func, query, args=()):
    conn = db_func()
    try:
        with conn.cursor() as cur:
            cur.execute(query, args)
        conn.commit()
        return True
    except Exception as e:
        conn.rollback()
        print(f"DB Error: {e}")
        return False

# ==========================================
# AUTHENTICATION
# ==========================================
class User(UserMixin):
    def __init__(self, user_id, email, name, role, initials):
        self.id = user_id
        self.email = email
        self.name = name
        self.role = role
        self.initials = initials

@login_manager.user_loader
def load_user(user_id):
    # Retrieve user by internal UUID
    u = query_db(get_lims_db, """
        SELECT u.user_id, p.email, p.first_name || ' ' || p.last_name as name, 
               r.role_name, p.initials
        FROM core.users u
        JOIN core.persons p ON u.person_id = p.person_id
        JOIN reference.roles r ON u.role_id = r.role_id
        WHERE u.user_id = %s
    """, (user_id,), one=True)
    if u:
        return User(u['user_id'], u['email'], u['name'], u['role_name'], u['initials'])
    return None

@app.route('/', methods=['GET', 'POST'])
def login():
    if current_user.is_authenticated:
        return redirect(url_for('dashboard'))
        
    if request.method == 'POST':
        login_id = request.form.get('login_id') # Can be email or user ID
        password = request.form.get('password')
        tifi_pass = request.form.get('tifi_password')
        
        # 1. Check TIFI Shared Secret
        if tifi_pass != app.config['TIFI_COMMON_PASS']:
             flash("Invalid TIFI Password.", "danger")
             return render_template('login.html')

        # 2. Check Auth DB (musr)
        # Assuming 'login' column in aaa.lg_fi stores the identifier (email or ID)
        auth = query_db(get_auth_db, "SELECT pswd_hash FROM aaa.lg_fi WHERE login = %s", (login_id,), one=True)
        
        if auth and check_password_hash(auth['pswd_hash'], password):
            # 3. Check LIMS Profile (mylims)
            # We check if the provided login_id matches either email OR user_id (as string)
            # This requires casting user_id to text for comparison
            user_data = query_db(get_lims_db, """
                SELECT u.user_id, p.email, p.first_name || ' ' || p.last_name as name, 
                       r.role_name, p.initials
                FROM core.users u
                JOIN core.persons p ON u.person_id = p.person_id
                JOIN reference.roles r ON u.role_id = r.role_id
                WHERE (p.email = %s OR u.user_id::text = %s) AND u.is_active = TRUE
            """, (login_id, login_id), one=True)
            
            if user_data:
                user = User(user_data['user_id'], user_data['email'], user_data['name'], 
                           user_data['role_name'], user_data['initials'])
                login_user(user)
                execute_db(get_lims_db, "INSERT INTO audit.logged_actions (app_user, action, table_name, row_data) VALUES (%s, 'LOGIN', 'auth', 'Web Login')", (login_id,))
                return redirect(url_for('dashboard'))
            else:
                flash("User profile not found or inactive in LIMS Core.", "danger")
        else:
            flash("Invalid credentials.", "danger")
            
    return render_template('login.html')

@app.route('/logout')
@login_required
def logout():
    logout_user()
    return redirect(url_for('login'))

# ==========================================
# MODULES ROUTES
# ==========================================

@app.route('/dashboard')
@login_required
def dashboard():
    kpi = query_db(get_lims_db, """
        SELECT 
            (SELECT COUNT(*) FROM bio_assets.samples_root) as samples,
            (SELECT COUNT(*) FROM bio_assets.samples_root WHERE created_at > NOW() - INTERVAL '30 days') as samples_delta,
            (SELECT COUNT(*) FROM lims.projects WHERE status_id = 'Active') as projects,
            (SELECT COUNT(*) FROM eln.batch WHERE status = 'In Progress') as batches
    """, one=True)
    kpi['reads'] = "14.2" # Placeholder
    
    alerts = query_db(get_lims_db, "SELECT * FROM lims.view_reagent_alerts")
    instruments = query_db(get_lims_db, "SELECT * FROM eln.bookable_resources ORDER BY name")
    for i in instruments:
        i['dot_class'] = 'dot-active' if i['is_active'] else 'dot-error'
        i['status_text'] = 'Online' if i['is_active'] else 'Maintenance'

    audit_log = query_db(get_lims_db, "SELECT action_tstamp_tx as time_ago, app_user as actor, action, table_name, row_data as details FROM audit.logged_actions ORDER BY action_tstamp_tx DESC LIMIT 5")
    chart_data = {"labels": ["Jan", "Feb", "Mar", "Apr", "May"], "datasets": [{"label": "Throughput", "data": [10, 20, 15, 30, 45], "borderColor": "#3498db", "fill": False}]}

    return render_template('dashboard.html', kpi=kpi, alerts=alerts, instruments=instruments, audit_log=audit_log, chart_data=chart_data, session_user_initials=current_user.initials)

@app.route('/samples')
@login_required
def samples():
    samples_data = query_db(get_lims_db, "SELECT * FROM bio_assets.samples_root ORDER BY created_at DESC LIMIT 500")
    projects = [p['project_id'] for p in query_db(get_lims_db, "SELECT project_id FROM lims.projects")]
    types = [t['sample_type_id'] for t in query_db(get_lims_db, "SELECT sample_type_id FROM reference.sample_type")]
    return render_template('samples_registry.html', samples_json=json.dumps(samples_data, cls=CustomJSONEncoder), projects=projects, sample_types=types)

@app.route('/samples/save_grid', methods=['POST'])
@login_required
def save_samples_grid():
    data = request.json.get('data')
    count = 0
    for row in data:
        sid = row.get('sample_id')
        exists = query_db(get_lims_db, "SELECT 1 FROM bio_assets.samples_root WHERE sample_id = %s", (sid,), one=True)
        if exists:
            execute_db(get_lims_db, "UPDATE bio_assets.samples_root SET external_id=%s, sample_type_id=%s, project_id=%s, collection_date=%s, storage_location=%s, status_id=%s WHERE sample_id=%s", 
                       (row.get('external_id'), row.get('sample_type_id'), row.get('project_id'), row.get('collection_date'), row.get('storage_location'), row.get('status_id'), sid))
        else:
            execute_db(get_lims_db, "INSERT INTO bio_assets.samples_root (sample_id, external_id, sample_type_id, project_id, collection_date, storage_location, status_id) VALUES (%s, %s, %s, %s, %s, %s, %s)", 
                       (sid, row.get('external_id'), row.get('sample_type_id'), row.get('project_id'), row.get('collection_date'), row.get('storage_location'), row.get('status_id')))
        count += 1
    return jsonify({"success": True, "count": count})

@app.route('/storage')
@login_required
def storage():
    rooms = query_db(get_lims_db, "SELECT * FROM lims.storage WHERE location_type = 'Room'")
    tree = []
    for r in rooms:
        node = {'id': r['storage_id'], 'name': r['name'], 'children': []}
        freezers = query_db(get_lims_db, "SELECT * FROM lims.storage WHERE parent_storage_id = %s", (r['storage_id'],))
        for f in freezers:
            f_node = {'id': f['storage_id'], 'name': f['name'], 'children': []}
            shelves = query_db(get_lims_db, "SELECT * FROM lims.storage WHERE parent_storage_id = %s", (f['storage_id'],))
            for s in shelves:
                f_node['children'].append({'id': s['storage_id'], 'name': s['name']})
            node['children'].append(f_node)
        tree.append(node)
    
    reagents = query_db(get_lims_db, "SELECT *, (expiry_date - CURRENT_DATE) as days_left, (quantity_current / quantity_initial * 100)::int as percent_remaining FROM lims.reagents")
    alerts = [r for r in reagents if r['days_left'] is not None and r['days_left'] < 30]
    
    return render_template('storage_reagents.html', storage_tree=tree, reagents=reagents, alerts=alerts, current_box=None)

@app.route('/molecular')
@login_required
def molecular():
    batches = query_db(get_lims_db, "SELECT * FROM eln.batch WHERE status != 'Completed'")
    curr_batch = None
    if request.args.get('batch_id'):
        curr_batch = query_db(get_lims_db, "SELECT * FROM eln.batch WHERE batch_id=%s", (request.args.get('batch_id'),), one=True)
    return render_template('molecular_biology.html', batches=batches, current_batch=curr_batch, plate_data={}, qc_samples=[], qpcr_results=[], libraries=[], sequencing_runs=[])

@app.route('/field')
@login_required
def field():
    cruises = query_db(get_lims_db, "SELECT * FROM field.cruises")
    stats = {'active_cruises': len(cruises), 'events_count': 0}
    return render_template('field_events.html', cruises=cruises, stats=stats, catch_stats=[])

@app.route('/bioinformatics')
@login_required
def bioinformatics():
    runs = query_db(get_lims_db, "SELECT run_id, status_id FROM moleculargenetics.sequencing ORDER BY run_date DESC")
    return render_template('bioinformatics.html', runs=runs, current_run_id=None, kpi={}, active_jobs=[], assignments=[])

@app.route('/projects')
@login_required
def projects():
    all_projects = query_db(get_lims_db, "SELECT project_id as id, title as name, status_id as status FROM lims.projects")
    return render_template('project_collaboration.html', projects=all_projects, current_project=None, tasks=[], chat_messages=[], users=[], permits=[], documents=[])

@app.route('/eln')
@login_required
def eln():
    resources = query_db(get_lims_db, "SELECT * FROM eln.bookable_resources WHERE is_active = TRUE")
    runs = query_db(get_lims_db, "SELECT * FROM eln.protocols_run ORDER BY run_date DESC LIMIT 10")
    protocols = query_db(get_lims_db, "SELECT * FROM eln.protocols")
    bookings = query_db(get_lims_db, "SELECT booking_id as id, 'Booking' as title, start_time as start, end_time as end FROM eln.bookings")
    projects = query_db(get_lims_db, "SELECT * FROM lims.projects")
    sops = query_db(get_lims_db, "SELECT * FROM lims.sop")
    return render_template('eln_booking.html', resources=resources, booking_events=bookings, notebook_runs=runs, protocols=protocols, sops=sops, projects=projects)

@app.route('/reservations')
@login_required
def reservations():
    res = query_db(get_lims_db, "SELECT * FROM bio_assets.samples_reservation ORDER BY planned_date DESC")
    projs = query_db(get_lims_db, "SELECT * FROM lims.projects")
    types = query_db(get_lims_db, "SELECT * FROM reference.sample_type")
    return render_template('sample_reservation.html', reservations=res, projects=projs, sample_types=types, stats={})

@app.route('/biology')
@login_required
def biology():
    return render_template('biology_fish.html', specimen=None, sub_samples=[], otolith={}, prey_items=[], indices={})

@app.route('/search')
@login_required
def search():
    query = request.args.get('q', '')
    results = []
    if query:
        results = query_db(get_lims_db, "SELECT * FROM dashboard.fn_global_search(%s)", (query,))
    return render_template('search_page.html', query=query, results=results)

@app.route('/settings')
@login_required
def settings():
    logs = query_db(get_lims_db, "SELECT * FROM audit.logged_actions ORDER BY action_tstamp_tx DESC LIMIT 50")
    all_users = []
    if current_user.role == 'Admin':
        all_users = query_db(get_lims_db, """
            SELECT u.is_active, p.email, p.first_name || ' ' || p.last_name as name, r.role_name as role, p.initials
            FROM core.users u JOIN core.persons p ON u.person_id = p.person_id
            JOIN reference.roles r ON u.role_id = r.role_id
        """)
    return render_template('settings.html', audit_logs=logs, all_users=all_users)

@app.route('/settings/change_password', methods=['POST'])
@login_required
def change_password():
    current_pw = request.form.get('current_password')
    new_pw = request.form.get('new_password')
    
    auth = query_db(get_auth_db, "SELECT pswd_hash FROM aaa.lg_fi WHERE login = %s", (current_user.email,), one=True)
    if auth and check_password_hash(auth['pswd_hash'], current_pw):
        new_hash = generate_password_hash(new_pw)
        execute_db(get_auth_db, "UPDATE aaa.lg_fi SET pswd_hash = %s WHERE login = %s", (new_hash, current_user.email))
        flash("Password updated successfully.", "success")
    else:
        flash("Incorrect current password.", "danger")
    return redirect(url_for('settings'))

# --- UNIVERSAL IMPORT ---
@app.route('/<module>/import', methods=['POST'])
@login_required
def generic_import(module):
    file = request.files['file']
    target = request.form.get('target_table')
    if file:
        filename = secure_filename(file.filename)
        path = os.path.join(app.config['UPLOAD_FOLDER'], filename)
        file.save(path)
        try:
            df = pd.read_excel(path) if filename.endswith('.xlsx') else pd.read_csv(path)
            # In production: df.to_sql or generate queries based on target
            flash(f"Loaded {len(df)} rows. DB update simulation complete for {target}.", "success")
        except Exception as e:
            flash(f"Error: {e}", "danger")
    return redirect(request.referrer)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)