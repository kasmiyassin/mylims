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
    SECRET_KEY = os.getenv('SECRET_KEY', 'genfish-secret-key-2026')
    TIFI_COMMON_PASS = os.getenv('TIFI_PASS', 'admin') # Shared Secret Gate
    
    UPLOAD_FOLDER = os.path.join(os.getcwd(), 'uploads')
    MAX_CONTENT_LENGTH = 32 * 1024 * 1024 # 32MB

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

app = Flask(__name__)
app.config.from_object(Config)
os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)

# --- JSON SERIALIZER ---
class CustomJSONEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, (datetime.date, datetime.datetime)):
            return obj.isoformat()
        if isinstance(obj, decimal.Decimal):
            return float(obj)
        if isinstance(obj, datetime.timedelta):
            return str(obj)
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
login_manager = LoginManager()
login_manager.init_app(app)
login_manager.login_view = 'login'

class User(UserMixin):
    def __init__(self, user_id, email, first_name, last_name, role, initials):
        self.id = user_id
        self.email = email
        self.first_name = first_name
        self.last_name = last_name
        self.name = f"{first_name} {last_name}"
        self.role = role
        self.initials = initials

@login_manager.user_loader
def load_user(user_id):
    # Cross-reference 'musr' login with 'mylims' profile
    u = query_db(get_lims_db, """
        SELECT p.person_id, p.email, p.first_name, p.last_name, p.role_in_org as role
        FROM core.persons p
        WHERE p.person_id::text = %s OR p.email = %s
    """, (user_id, user_id), one=True)
    if u:
        initials = f"{u['first_name'][0]}{u['last_name'][0]}" if u['first_name'] else "U"
        return User(u['person_id'], u['email'], u['first_name'], u['last_name'], u['role'], initials)
    return None

@app.route('/', methods=['GET', 'POST'])
def login():
    if current_user.is_authenticated:
        return redirect(url_for('dashboard'))
        
    if request.method == 'POST':
        login_id = request.form.get('login_id')
        password = request.form.get('password')
        tifi_pass = request.form.get('tifi_password')
        
        if tifi_pass != app.config['TIFI_COMMON_PASS']:
             flash("Invalid TIFI Common Password.", "danger")
             return render_template('lims_login.html')

        # Auth DB Check
        auth = query_db(get_auth_db, "SELECT pswd_hash FROM aaa.lg_fi WHERE login = %s", (login_id,), one=True)
        if auth and check_password_hash(auth['pswd_hash'], password):
            user = load_user(login_id)
            if user:
                login_user(user)
                execute_db(get_lims_db, "INSERT INTO audit.logged_actions (app_user, action, table_name, row_data) VALUES (%s, 'LOGIN', 'core.persons', 'Web Login')", (user.email,))
                return redirect(url_for('dashboard'))
            flash("User profile not found in LIMS database.", "warning")
        else:
            flash("Invalid credentials.", "danger")
            
    return render_template('lims_login.html')

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
            (SELECT COUNT(*) FROM lims.projects WHERE status_id = 'Active') as projects,
            (SELECT COUNT(*) FROM eln.protocols_run) as batches,
            '14.2' as reads
    """, one=True)
    
    alerts = query_db(get_lims_db, "SELECT * FROM lims.view_reagent_alerts LIMIT 5")
    instruments = query_db(get_lims_db, "SELECT name, is_active FROM eln.bookable_resources ORDER BY name")
    for i in instruments:
        i['dot_class'] = 'dot-active' if i['is_active'] else 'dot-offline'
        i['status_text'] = 'Online' if i['is_active'] else 'Maintenance'

    audit_log = query_db(get_lims_db, "SELECT action_tstamp_tx as time_ago, app_user as actor, action, table_name FROM audit.logged_actions ORDER BY action_tstamp_tx DESC LIMIT 5")
    
    chart_data = {
        "labels": ["Jan", "Feb", "Mar", "Apr", "May", "Jun"],
        "datasets": [{"label": "Throughput", "data": [10, 25, 18, 40, 35, 50], "borderColor": "#3498db"}]
    }

    return render_template('lims_dashboard.html', kpi=kpi, alerts=alerts, instruments=instruments, audit_log=audit_log, chart_data=chart_data)

@app.route('/samples')
@login_required
def samples():
    samples_data = query_db(get_lims_db, "SELECT * FROM bio_assets.samples_root ORDER BY collection_date DESC LIMIT 500")
    projects = [p['project_id'] for p in query_db(get_lims_db, "SELECT project_id FROM lims.projects")]
    types = [t['sample_type_id'] for t in query_db(get_lims_db, "SELECT sample_type_id FROM reference.sample_type")]
    return render_template('lims_samples_registry.html', samples_json=json.dumps(samples_data, cls=CustomJSONEncoder), projects=projects, sample_types=types)

@app.route('/samples/lineage/<sample_id>')
@login_required
def lineage(sample_id):
    # Calls the recursive view in mylims_v5.sql
    data = query_db(get_lims_db, "SELECT * FROM bio_assets.view_downstream_lineage WHERE ancestor_sample_id = %s", (sample_id,))
    html = f"<ul><li><div class='lineage-node'><strong>{sample_id}</strong> <span class='badge bg-primary'>Root</span></div>"
    if data:
        html += "<ul>"
        for item in data:
            html += f"<li><div class='lineage-node'><strong>{item['descendant_sample_id']}</strong> <span class='badge bg-info'>{item['descendant_type']}</span></div></li>"
        html += "</ul>"
    html += "</li></ul>"
    return jsonify(success=True, html=html)

@app.route('/storage')
@login_required
def storage():
    rooms = query_db(get_lims_db, "SELECT * FROM lims.storage WHERE parent_storage_id IS NULL")
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
    
    reagents = query_db(get_lims_db, "SELECT *, (expiry_date - CURRENT_DATE) as days_left FROM lims.reagents")
    return render_template('lims_storage_reagents.html', storage_tree=tree, reagents=reagents, alerts=[r for r in reagents if r['days_left'] and r['days_left'] < 30])

@app.route('/field')
@login_required
def field():
    cruises = query_db(get_lims_db, "SELECT * FROM field.cruises")
    events = query_db(get_lims_db, "SELECT sampling_id, latitude, longitude, sampling_date FROM field.sampling_event")
    map_features = []
    for e in events:
        map_features.append({
            "type": "Feature",
            "geometry": {"type": "Point", "coordinates": [e['longitude'], e['latitude']]},
            "properties": {"id": e['sampling_id'], "date": str(e['sampling_date'])}
        })
    return render_template('lims_field_events.html', cruises=cruises, map_data=json.dumps(map_features))

@app.route('/biology')
@login_required
def biology():
    # Logic for Fish Biology module
    specimens = query_db(get_lims_db, "SELECT * FROM biologyfish.specimen LIMIT 100")
    return render_template('lims_biology_fish.html', specimens=specimens)

@app.route('/molecular')
@login_required
def molecular():
    batches = query_db(get_lims_db, "SELECT * FROM eln.protocols_run ORDER BY run_date DESC")
    return render_template('lims_molecular_biology.html', batches=batches)

@app.route('/explorer')
@login_required
def explorer():
    # List available schemas for the explorer sidebar
    schemas = ['bio_assets', 'lims', 'moleculargenetics', 'biologyfish', 'field', 'bioinformatics', 'core']
    return render_template('lims_database_explorer.html', schemas=schemas)

@app.route('/explorer/data/<table>')
@login_required
def explorer_data(table):
    # Dynamic table querying for explorer
    schema, tname = table.split('.')
    data = query_db(get_lims_db, f"SELECT * FROM {schema}.{tname} LIMIT 200")
    return jsonify(data)

@app.route('/search')
@login_required
def search():
    query = request.args.get('q', '')
    results = []
    if query:
        # Integrated with SQL global search function
        results = query_db(get_lims_db, "SELECT * FROM dashboard.fn_global_search(%s)", (query,))
    return render_template('lims_search_page.html', query=query, results=results)

@app.route('/settings')
@login_required
def settings():
    logs = query_db(get_lims_db, "SELECT * FROM audit.logged_actions ORDER BY action_tstamp_tx DESC LIMIT 100")
    return render_template('lims_settings.html', audit_logs=logs)

# ==========================================
# UPLOAD / IMPORT VIEW
# ==========================================
@app.route('/<module>/import', methods=['POST'])
@login_required
def generic_import(module):
    """
    Handles file uploads for any module.
    Maps Excel/CSV columns to database tables.
    """
    file = request.files.get('file')
    target = request.form.get('target_table') # e.g. 'bio_assets.samples_root'
    
    if not file or not target:
        flash("Missing file or target table selection.", "danger")
        return redirect(request.referrer)

    filename = secure_filename(file.filename)
    filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
    file.save(filepath)

    try:
        df = pd.read_excel(filepath) if filename.endswith('.xlsx') else pd.read_csv(filepath)
        # Convert NaN to None for SQL
        df = df.where(pd.notnull(df), None)
        
        conn = get_lims_db()
        with conn.cursor() as cur:
            for _, row in df.iterrows():
                columns = row.index.tolist()
                values = row.values.tolist()
                
                query = f"INSERT INTO {target} ({', '.join(columns)}) VALUES ({', '.join(['%s']*len(values))}) "
                query += "ON CONFLICT DO UPDATE SET " + ", ".join([f"{col}=EXCLUDED.{col}" for col in columns])
                
                cur.execute(query, values)
            conn.commit()
            
        flash(f"Successfully processed {len(df)} records into {target}.", "success")
    except Exception as e:
        flash(f"Import Error: {str(e)}", "danger")
        
    return redirect(request.referrer)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)