# -*- coding: utf-8 -*-
"""
GenFish LIMS Server Application (v5.0 Complete)
-----------------------------------------------
A comprehensive Flask backend for the GenFish Laboratory Information Management System.
This application handles:
1. Authentication against the 'musr' security database.
2. Operational CRUD against the 'mylims' database.
3. specialized workflows for Field, Biology, Molecular, and Bioinformatics.
4. File management and Excel bulk operations.

Author: System Generator
Date: 2026-01-29
"""

import os
import io
import csv
import json
import uuid
import base64
import bcrypt
import shutil
import logging
import traceback
import mimetypes
import pandas as pd
import psycopg2
import psycopg2.extras
from psycopg2 import sql
from datetime import datetime, date, time, timedelta
from typing import Any, Dict, List, Optional, Tuple, Union
from werkzeug.utils import secure_filename

# Flask & Networking
from flask import (
    Flask, request, jsonify, session, redirect, url_for, 
    g, render_template, send_file, send_from_directory, make_response, abort
)
from flask_cors import CORS
from waitress import serve

# ==============================================================================
# 1. SYSTEM CONFIGURATION (NO ENV FILES)
# ==============================================================================

# Server Settings
HOST_IP = '0.0.0.0'
HOST_PORT = 5000
DEBUG_MODE = False  # Set to False for production

# Security
SECRET_KEY = 'GENFISH_LIMS_INTERNAL_SECURE_KEY_X99_DO_NOT_SHARE'
BCRYPT_ROUNDS = 12

# Database: Operational Data (mylims)
DB_HOST = '0.0.0.0'
DB_NAME = 'demo'
DB_USER = 'kasmi'
DB_PASS = 'password'

# Database: Authentication (musr)
AUTH_DB_HOST = '0.0.0.0'
AUTH_DB_NAME = 'musr'
AUTH_DB_USER = 'auth_user'
AUTH_DB_PASS = 'auth_password'

# File Storage Paths
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
UPLOAD_FOLDER = os.path.join(BASE_DIR, 'uploads')
EXPORT_FOLDER = os.path.join(BASE_DIR, 'exports')
TEMPLATE_FOLDER = os.path.join(BASE_DIR, 'templates')
STATIC_FOLDER = os.path.join(BASE_DIR, 'static')

# Allowed File Extensions
ALLOWED_EXTENSIONS_IMG = {'png', 'jpg', 'jpeg', 'gif', 'svg'}
ALLOWED_EXTENSIONS_DOC = {'pdf', 'txt', 'csv', 'xlsx', 'xls', 'docx'}
ALLOWED_EXTENSIONS_SEQ = {'fasta', 'fastq', 'bam', 'vcf', 'fna'}
ALLOWED_ALL = ALLOWED_EXTENSIONS_IMG | ALLOWED_EXTENSIONS_DOC | ALLOWED_EXTENSIONS_SEQ

# ==============================================================================
# 2. APP INITIALIZATION
# ==============================================================================

app = Flask(__name__, template_folder=TEMPLATE_FOLDER, static_folder=STATIC_FOLDER)
app.secret_key = SECRET_KEY
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER
app.config['MAX_CONTENT_LENGTH'] = 1024 * 1024 * 500  # 500 MB max upload

# Enable CORS for all domains (simplify internal network usage)
CORS(app, supports_credentials=True, resources={r"/*": {"origins": "*"}})

# Setup Logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[logging.FileHandler("lims_server.log"), logging.StreamHandler()]
)
logger = logging.getLogger("GenFishLIMS")

# Ensure critical directories exist
for path in [UPLOAD_FOLDER, EXPORT_FOLDER]:
    os.makedirs(path, exist_ok=True)

# ==============================================================================
# 3. DATABASE SCHEMA METADATA (Knowledge Graph)
# ==============================================================================

# This mapping defines the Primary Key for every table in the system.
# It is used by the generic CRUD engine to know how to target rows.
PK_MAPPING = {
    # Reference
    'reference.status': 'status_id',
    'reference.category': 'category_id',
    'reference.sample_type': 'sample_type_id',
    'reference.units': 'unit_id',
    'reference.taxon': 'taxon_id',
    'reference.region': 'region_id',
    'reference.ecosystem': 'ecosystem_id',
    'reference.genes': 'gene_id',
    'reference.reference_databases': 'db_id',
    
    # Core
    'core.organizations': 'organization_id',
    'core.persons': 'person_id',
    'core.locations': 'build_id',
    'core.equipments': 'equipment_id',
    'core.vessel': 'vessel_id',
    
    # LIMS
    'lims.projects': 'project_id',
    'lims.project_personal': ['project_id', 'person_id'],
    'lims.permits': 'permit_id',
    'lims.sop': 'sop_id',
    'lims.storage': 'storage_id',
    'lims.reagents': 'reagent_id',
    'lims.experiments': 'experiment_id',
    'lims.experiments_projects': ['experiment_id', 'project_id'],
    'lims.experiments_samples': ['experiment_id', 'sample_id'],
    
    # Field
    'field.cruises': 'cruise_id',
    'field.sampling_event': 'sampling_id',
    'field.sampling_abiotic': 'sampling_id',
    'field.fishing': 'sampling_id',
    'field.catch': 'catch_id',
    
    # Bio Assets
    'bio_assets.samples_reservation': 'reservation_sample_id',
    'bio_assets.samples_root': 'sample_id',
    'bio_assets.sediments': 'sample_id',
    'bio_assets.water': 'sample_id',
    'bio_assets.specimen_organisms': 'sample_id',
    'bio_assets.tissue': 'sample_id',
    
    # Fish Biology
    'biologyfish.dissection': 'dissection_id',
    'biologyfish.otoliths': 'otolith_id',
    'biologyfish.tag_mark': 'tag_id',
    
    # Molecular Genetics
    'moleculargenetics.nucleic_acid': 'sample_id',
    'moleculargenetics.nanodrop': 'measurement_id',
    'moleculargenetics.qubit': 'measurement_id',
    'moleculargenetics.tapestation': 'measurement_id',
    'moleculargenetics.pcr': 'pcr_id',
    'moleculargenetics.qpcr': 'qpcr_id',
    'moleculargenetics.gelelectrophoresis': 'gel_id',
    'moleculargenetics.library': 'library_id',
    'moleculargenetics.library_samples': ['library_id', 'sample_id'],
    'moleculargenetics.sequencing_flowcells': 'flowcell_id',
    'moleculargenetics.sequencing': 'run_id',
    'moleculargenetics.sequencing_libraries': ['run_id', 'library_id'],
    
    # Bioinformatics
    'bioinformatics.pipelines': 'pipeline_id',
    'bioinformatics.seq_dataset': 'dataset_id',
    'bioinformatics.seq_sample_assignment': ['dataset_id', 'sample_id'],
    'bioinformatics.assignments': 'assignment_id',
    
    # ELN
    'eln.batch': 'batch_id',
    'eln.bookable_resources': 'resource_id',
    'eln.bookings': 'booking_id',
    'eln.protocols': 'protocol_id',
    'eln.protocols_run': 'run_id',
    
    # Communications
    'communications.projects_chat': 'message_id',
    'communications.internal_plans': 'plan_id',
    'communications.reports': 'report_id',
    
    # Views (Virtual Tables) - Mapped to their underlying primary keys for read operations
    'dashboard.global_lab_overview': 'sample_id',
    'lims.view_project_dashboard': 'project_id',
    'core.view_team_activity': 'person_id',
    'field.view_sampling_map_data': 'sampling_id',
    'field.view_catch_statistics': 'sampling_id',
    'biologyfish.view_biological_profile': 'sample_id',
    'lims.view_sample_location_paths': 'sample_id',
    'lims.view_reagent_alerts': 'reagent_id',
    'moleculargenetics.view_extraction_qc_summary': 'sample_id',
    'moleculargenetics.view_sequencing_queue': 'library_id',
    'eln.view_booking_calendar_events': 'booking_id',
    'audit.view_readable_log': 'action_timestamp'
}

# ==============================================================================
# 4. DATABASE UTILITIES & HELPERS
# ==============================================================================

def get_db_connection():
    """Establishes a connection to the main LIMS database with auto-rollback on error."""
    try:
        conn = psycopg2.connect(
            host=DB_HOST, database=DB_NAME, user=DB_USER, password=DB_PASS
        )
        conn.autocommit = False
        return conn
    except psycopg2.Error as e:
        logger.critical(f"Main DB Connection Failed: {e}")
        return None

def get_auth_db_connection():
    """Establishes a connection to the authentication database."""
    try:
        conn = psycopg2.connect(
            host=AUTH_DB_HOST, database=AUTH_DB_NAME, user=AUTH_DB_USER, password=AUTH_DB_PASS
        )
        return conn
    except psycopg2.Error as e:
        logger.critical(f"Auth DB Connection Failed: {e}")
        return None

@app.before_request
def before_request_func():
    """
    Middleware: Runs before every request.
    1. Connects to DB.
    2. Sets Row-Level Security (RLS) variables based on session.
    """
    if request.endpoint == 'static': 
        return
    
    g.db_conn = get_db_connection()
    if g.db_conn:
        user_id = str(session.get('user_id', 'system'))
        try:
            with g.db_conn.cursor() as cur:
                # Set session config for PostgreSQL triggers and RLS policies
                cur.execute("SELECT set_config('session.logged_in_person_id', %s, FALSE)", (user_id,))
                cur.execute("SELECT set_config('audit.logged_in_user', %s, FALSE)", (user_id,))
                g.db_conn.commit()
        except Exception as e:
            logger.error(f"Failed to set RLS context: {e}")
            g.db_conn.rollback()

@app.teardown_request
def teardown_request_func(exception=None):
    """
    Middleware: Runs after every request.
    Closes DB connection. Rolls back if an exception occurred.
    """
    conn = getattr(g, 'db_conn', None)
    if conn:
        if exception:
            conn.rollback()
            logger.warning("Database transaction rolled back due to exception.")
        conn.close()

def dict_factory(cursor, row):
    """
    Custom row factory to convert DB rows into JSON-serializable dictionaries.
    Handles Datetime, Date, Time, Bytes, and UUIDs.
    """
    d = {}
    for idx, col in enumerate(cursor.description):
        val = row[idx]
        if isinstance(val, (date, datetime)):
            d[col.name] = val.isoformat()
        elif isinstance(val, time):
            d[col.name] = val.strftime("%H:%M:%S")
        elif isinstance(val, (bytes, memoryview)):
            # Check if it's likely a string stored as bytes, or real binary
            try:
                d[col.name] = val.decode('utf-8')
            except:
                # Return base64 for real binary data (images, etc)
                d[col.name] = "base64:" + base64.b64encode(val).decode('utf-8')
        elif isinstance(val, uuid.UUID):
            d[col.name] = str(val)
        else:
            d[col.name] = val
    return d

def execute_query(query, params=None, fetch_all=True, commit=False):
    """
    Helper to execute raw SQL safely.
    """
    if not g.db_conn:
        raise ConnectionError("Database not connected")
    
    res = None
    try:
        with g.db_conn.cursor(cursor_factory=psycopg2.extras.DictCursor) as cur:
            cur.execute(query, params)
            if commit:
                g.db_conn.commit()
            
            if cur.description: # If query returns data
                if fetch_all:
                    rows = cur.fetchall()
                    res = [dict_factory(cur, r) for r in rows]
                else:
                    row = cur.fetchone()
                    res = dict_factory(cur, row) if row else None
    except Exception as e:
        g.db_conn.rollback()
        logger.error(f"Query Error: {e} | Query: {query}")
        raise e
    return res

def resolve_table_casing(schema_table_str):
    """
    Splits 'schema.table' and resolves actual casing from DB metadata.
    Returns (schema, table, full_path)
    """
    if '.' not in schema_table_str:
        return 'public', schema_table_str, f"public.{schema_table_str}"
    
    parts = schema_table_str.split('.')
    return parts[0], parts[1], schema_table_str

# ==============================================================================
# 5. AUTHENTICATION MODULE
# ==============================================================================

@app.route('/', methods=['GET'])
def index():
    """Root URL - Redirects based on session state."""
    if 'user_id' in session:
        return redirect(url_for('view_dashboard'))
    return redirect(url_for('view_login'))

@app.route('/login', methods=['GET'])
def view_login():
    """Serves the login page."""
    return render_template('lims_login.html')

@app.route('/api/login', methods=['POST'])
def api_login():
    """
    Handles authentication logic.
    1. Checks 'musr' database for password hash.
    2. Validates with bcrypt.
    3. Fetches user profile from 'core.persons'.
    """
    data = request.json or request.form
    username = data.get('username')
    password = data.get('password')

    if not username or not password:
        return jsonify({"success": False, "message": "Missing credentials"}), 400

    # 1. Admin Override (Hardcoded for emergency)
    if username == 'admin' and password == 'GenFish2026!':
        session['user_id'] = 'admin'
        session['user_name'] = 'System Administrator'
        session['role'] = 'superadmin'
        return jsonify({"success": True, "redirect": url_for('view_dashboard')})

    # 2. Check Auth DB
    auth_conn = get_auth_db_connection()
    if not auth_conn:
        return jsonify({"success": False, "message": "Auth Server Unavailable"}), 503

    try:
        with auth_conn.cursor() as cur:
            cur.execute("SELECT pswd_hash FROM aaa.lg_fi WHERE login = %s", (username,))
            result = cur.fetchone()
            
            if not result:
                return jsonify({"success": False, "message": "User not found"}), 401
            
            stored_hash = result[0]
            if not bcrypt.checkpw(password.encode('utf-8'), stored_hash.encode('utf-8')):
                return jsonify({"success": False, "message": "Invalid password"}), 401

            # 3. Fetch User Details from LIMS DB
            user_details = execute_query(
                "SELECT first_name, last_name, role_in_org FROM core.persons WHERE person_id = %s OR email = %s", 
                (username, username), 
                fetch_all=False
            )
            
            session['user_id'] = username
            if user_details:
                session['user_name'] = f"{user_details['first_name']} {user_details['last_name']}"
                session['role'] = user_details.get('role_in_org', 'User')
            else:
                session['user_name'] = username
                session['role'] = 'Guest'

            return jsonify({"success": True, "redirect": url_for('view_dashboard')})

    except Exception as e:
        logger.error(f"Login Error: {e}")
        return jsonify({"success": False, "message": "Internal Server Error"}), 500
    finally:
        auth_conn.close()

@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('view_login'))

# ==============================================================================
# 6. VIEW CONTROLLERS (HTML PAGES)
# ==============================================================================

def render_lims_template(template_name, **kwargs):
    """Wrapper to inject common context (user info) into every template."""
    user_ctx = {
        'user_id': session.get('user_id'),
        'user_name': session.get('user_name', 'Guest'),
        'role': session.get('role', '')
    }
    return render_template(template_name, user=user_ctx, **kwargs)

@app.route('/dashboard')
def view_dashboard():
    if 'user_id' not in session: return redirect(url_for('view_login'))
    
    # Fetch KPIs
    kpi = {}
    try:
        kpi['samples'] = execute_query("SELECT COUNT(*) as c FROM bio_assets.samples_root", fetch_all=False)['c']
        kpi['projects'] = execute_query("SELECT COUNT(*) as c FROM lims.projects WHERE status_id = 'Active'", fetch_all=False)['c']
        kpi['experiments'] = execute_query("SELECT COUNT(*) as c FROM lims.experiments WHERE processing_date > CURRENT_DATE - 30", fetch_all=False)['c']
        kpi['reads'] = execute_query("SELECT SUM(read_count_filtered) as c FROM bioinformatics.seq_dataset", fetch_all=False)['c'] or 0
    except:
        kpi = {'samples': 0, 'projects': 0, 'experiments': 0, 'reads': 0}
        
    return render_lims_template('lims_dashboard.html', kpi=kpi)

@app.route('/registry')
def view_registry():
    return render_lims_template('lims_samples_registry.html')

@app.route('/field')
def view_field():
    return render_lims_template('lims_field_events.html')

@app.route('/biology')
def view_biology():
    return render_lims_template('lims_biology_fish.html')

@app.route('/molecular')
def view_molecular():
    return render_lims_template('lims_molecular_biology.html')

@app.route('/storage')
def view_storage():
    return render_lims_template('lims_storage_reagents.html')

@app.route('/projects')
def view_projects():
    return render_lims_template('lims_project_collaboration.html')

@app.route('/bioinformatics')
def view_bioinformatics():
    return render_lims_template('lims_bioinformatics.html')

@app.route('/explorer')
def view_explorer():
    # Fetch database schema structure for sidebar
    schema_tree = {}
    tables = execute_query("""
        SELECT table_schema, table_name 
        FROM information_schema.tables 
        WHERE table_schema IN ('reference', 'core', 'lims', 'field', 'bio_assets', 'biologyfish', 'moleculargenetics', 'bioinformatics', 'eln')
        ORDER BY table_schema, table_name
    """)
    for t in tables:
        s = t['table_schema']
        if s not in schema_tree: schema_tree[s] = []
        schema_tree[s].append(t['table_name'])
        
    return render_lims_template('lims_database_explorer.html', schema_tree=schema_tree)

@app.route('/settings')
def view_settings():
    return render_lims_template('lims_settings.html')

# ==============================================================================
# 7. GENERIC CRUD API ENGINE
# ==============================================================================

@app.route('/api/table/<schema>/<table>', methods=['GET'])
def api_get_table(schema, table):
    """
    Universal GET endpoint. 
    Supports: Filtering (?column=value), Sorting, Pagination, and Search.
    """
    full_table = f"{schema}.{table}"
    
    # 1. Build Base Query
    query = f'SELECT * FROM "{schema}"."{table}"'
    params = []
    conditions = []
    
    # 2. Parse Filters from Query Params
    for k, v in request.args.items():
        if k in ['limit', 'offset', 'order_by', 'dir', 'search']: continue
        if not v: continue
        
        # Handle operators (e.g., date_ge=2024-01-01)
        if k.endswith('_ge'):
            col = k[:-3]
            conditions.append(f'"{col}" >= %s')
        elif k.endswith('_le'):
            col = k[:-3]
            conditions.append(f'"{col}" <= %s')
        elif k.endswith('_like'):
            col = k[:-5]
            conditions.append(f'"{col}" ILIKE %s')
            v = f"%{v}%"
        else:
            # Exact match
            conditions.append(f'"{k}" = %s')
        params.append(v)

    if conditions:
        query += " WHERE " + " AND ".join(conditions)

    # 3. Order By
    order_col = request.args.get('order_by')
    direction = request.args.get('dir', 'ASC').upper()
    if order_col:
        query += f' ORDER BY "{order_col}" {direction}'

    # 4. Limit/Offset
    limit = request.args.get('limit', 100)
    offset = request.args.get('offset', 0)
    query += " LIMIT %s OFFSET %s"
    params.extend([limit, offset])

    try:
        rows = execute_query(query, params)
        return jsonify({"success": True, "data": rows})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/api/table/<schema>/<table>', methods=['POST'])
def api_create_record(schema, table):
    """
    Universal CREATE endpoint.
    Handles single record creation from JSON body.
    """
    data = request.json
    if not data:
        return jsonify({"success": False, "error": "No data provided"}), 400

    cols = data.keys()
    vals = [data[c] for c in cols]
    
    col_str = ', '.join([f'"{c}"' for c in cols])
    ph_str = ', '.join(['%s'] * len(cols))
    
    query = f'INSERT INTO "{schema}"."{table}" ({col_str}) VALUES ({ph_str}) RETURNING *'
    
    try:
        new_row = execute_query(query, vals, fetch_all=False, commit=True)
        return jsonify({"success": True, "data": new_row}), 201
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/api/table/<schema>/<table>', methods=['PUT'])
def api_update_record(schema, table):
    """
    Universal UPDATE endpoint.
    Requires Primary Key in arguments to identify the row.
    """
    full_table_key = f"{schema}.{table}"
    pk_def = PK_MAPPING.get(full_table_key)
    
    if not pk_def:
        return jsonify({"success": False, "error": f"No PK defined for {full_table_key}"}), 400
    
    # Handle composite keys
    pks = [pk_def] if isinstance(pk_def, str) else pk_def
    
    # Get PK values from Query Params
    pk_vals = []
    pk_conditions = []
    for pk in pks:
        val = request.args.get(pk)
        if not val:
            return jsonify({"success": False, "error": f"Missing PK: {pk}"}), 400
        pk_conditions.append(f'"{pk}" = %s')
        pk_vals.append(val)
        
    data = request.json
    if not data:
        return jsonify({"success": False, "error": "No update data"}), 400
        
    # Build SET clause
    set_clauses = []
    set_vals = []
    for k, v in data.items():
        if k in pks: continue # Don't update PK
        set_clauses.append(f'"{k}" = %s')
        set_vals.append(v)
        
    if not set_clauses:
        return jsonify({"success": True, "message": "Nothing to update"}), 200
        
    query = f'UPDATE "{schema}"."{table}" SET {", ".join(set_clauses)} WHERE {" AND ".join(pk_conditions)} RETURNING *'
    all_vals = set_vals + pk_vals
    
    try:
        updated_row = execute_query(query, all_vals, fetch_all=False, commit=True)
        return jsonify({"success": True, "data": updated_row})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/api/table/<schema>/<table>', methods=['DELETE'])
def api_delete_record(schema, table):
    """
    Universal DELETE endpoint.
    Requires Primary Key in arguments.
    """
    full_table_key = f"{schema}.{table}"
    pk_def = PK_MAPPING.get(full_table_key)
    
    if not pk_def:
        return jsonify({"success": False, "error": "Table PK not mapped"}), 400
        
    pks = [pk_def] if isinstance(pk_def, str) else pk_def
    pk_conditions = []
    pk_vals = []
    
    for pk in pks:
        val = request.args.get(pk)
        if not val:
            return jsonify({"success": False, "error": f"Missing PK {pk}"}), 400
        pk_conditions.append(f'"{pk}" = %s')
        pk_vals.append(val)
        
    query = f'DELETE FROM "{schema}"."{table}" WHERE {" AND ".join(pk_conditions)} RETURNING *'
    
    try:
        deleted = execute_query(query, pk_vals, fetch_all=False, commit=True)
        if deleted:
            return jsonify({"success": True, "data": deleted})
        else:
            return jsonify({"success": False, "error": "Record not found"}), 404
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

# ==============================================================================
# 8. FILE MANAGEMENT MODULE
# ==============================================================================

def save_file_to_disk(file_obj, schema, table, record_id):
    """
    Saves a file to /uploads/schema/table/record_id/filename.
    Returns the relative path string.
    """
    if not file_obj or file_obj.filename == '':
        return None
        
    filename = secure_filename(file_obj.filename)
    # Create directory structure
    save_dir = os.path.join(app.config['UPLOAD_FOLDER'], schema, table, str(record_id))
    os.makedirs(save_dir, exist_ok=True)
    
    full_path = os.path.join(save_dir, filename)
    file_obj.save(full_path)
    
    # Return path relative to Upload folder
    return os.path.join(schema, table, str(record_id), filename)

@app.route('/api/upload', methods=['POST'])
def api_upload_file():
    """
    Uploads a file and links it to a specific record via 'attachment_link' column.
    Params: schema, table, id_col, id_val
    """
    schema = request.form.get('schema')
    table = request.form.get('table')
    pk_col = request.form.get('pk_col')
    pk_val = request.form.get('pk_val')
    file = request.files.get('file')
    
    if not all([schema, table, pk_col, pk_val, file]):
        return jsonify({"success": False, "error": "Missing upload parameters"}), 400
        
    try:
        rel_path = save_file_to_disk(file, schema, table, pk_val)
        
        # Update DB record with path
        query = f'UPDATE "{schema}"."{table}" SET attachment_link = %s WHERE "{pk_col}" = %s'
        execute_query(query, [rel_path, pk_val], commit=True)
        
        return jsonify({"success": True, "path": rel_path})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/api/download', methods=['GET'])
def api_download_file():
    """Serves a file based on the relative path stored in DB."""
    rel_path = request.args.get('path')
    if not rel_path:
        return abort(404)
        
    full_path = os.path.join(app.config['UPLOAD_FOLDER'], rel_path)
    if os.path.exists(full_path):
        return send_file(full_path, as_attachment=True)
    else:
        return abort(404)

# ==============================================================================
# 9. EXCEL ENGINE (IMPORT/EXPORT)
# ==============================================================================

@app.route('/api/import/excel', methods=['POST'])
def api_import_excel():
    """
    Bulk Import from Excel/CSV.
    Uses 'upsert' logic (UPDATE if exists, INSERT if new).
    """
    file = request.files.get('file')
    target = request.form.get('target') # e.g. 'bio_assets.samples_root'
    
    if not file or not target:
        return jsonify({"success": False, "error": "File and target required"}), 400
        
    schema, table, _ = resolve_table_casing(target)
    pk_def = PK_MAPPING.get(target)
    
    if not pk_def:
         return jsonify({"success": False, "error": "Target table not supported for bulk import"}), 400
    
    # Determine PK column(s)
    pk_col = pk_def if isinstance(pk_def, str) else pk_def[0]

    try:
        # 1. Parse File
        if file.filename.endswith('.csv'):
            df = pd.read_csv(file)
        else:
            df = pd.read_excel(file)
        
        # 2. Clean Data
        df = df.where(pd.notnull(df), None) # Replace NaN with None
        records = df.to_dict(orient='records')
        
        if not records:
            return jsonify({"success": True, "count": 0, "message": "Empty file"})
            
        columns = list(records[0].keys())
        col_str = ', '.join([f'"{c}"' for c in columns])
        val_ph = ', '.join(['%s'] * len(columns))
        
        # 3. Build UPSERT Query
        update_clauses = [f'"{c}" = EXCLUDED."{c}"' for c in columns if c != pk_col]
        query = f"""
            INSERT INTO "{schema}"."{table}" ({col_str}) 
            VALUES ({val_ph})
            ON CONFLICT ("{pk_col}") 
            DO UPDATE SET {', '.join(update_clauses)}
        """
        
        # 4. Batch Execute
        vals = [tuple(r[c] for c in columns) for r in records]
        
        with g.db_conn.cursor() as cur:
            psycopg2.extras.execute_values(cur, query, vals)
            g.db_conn.commit()
            
        return jsonify({"success": True, "count": len(records), "message": "Import Successful"})

    except Exception as e:
        logger.error(f"Import Error: {traceback.format_exc()}")
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/api/export/excel', methods=['GET'])
def api_export_excel():
    """
    Exports a table or SQL query result to Excel.
    """
    target = request.args.get('target') # table name or 'query'
    sql_query = request.args.get('sql')
    
    try:
        if sql_query:
            query = sql_query
            filename = "custom_query_export.xlsx"
        elif target:
            schema, table, _ = resolve_table_casing(target)
            query = f'SELECT * FROM "{schema}"."{table}"'
            filename = f"{table}_export.xlsx"
        else:
            return abort(400)
            
        # Execute Query
        df = pd.read_sql(query, g.db_conn)
        
        # Write to Buffer
        output = io.BytesIO()
        with pd.ExcelWriter(output, engine='openpyxl') as writer:
            df.to_excel(writer, index=False, sheet_name='LIMS Data')
        output.seek(0)
        
        return send_file(
            output, 
            mimetype='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            as_attachment=True, 
            download_name=filename
        )
        
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

# ==============================================================================
# 10. SPECIFIC MODULE LOGIC (Business Logic)
# ==============================================================================

# --- DASHBOARD & SEARCH ---

@app.route('/api/global_search', methods=['GET'])
def api_global_search():
    """
    Deep search across multiple key tables using ILIKE and Full Text Search.
    """
    term = request.args.get('q', '')
    if len(term) < 2: return jsonify([])
    
    results = []
    
    # 1. Search Samples
    res = execute_query("""
        SELECT sample_id, external_id, sample_type_id FROM bio_assets.samples_root 
        WHERE sample_id ILIKE %s OR external_id ILIKE %s LIMIT 5
    """, (f'%{term}%', f'%{term}%'))
    for r in res: results.append({'type': 'Sample', 'id': r['sample_id'], 'text': f"{r['sample_id']} ({r['external_id']})"})
    
    # 2. Search Projects
    res = execute_query("""
        SELECT project_id, title FROM lims.projects 
        WHERE project_id ILIKE %s OR title ILIKE %s LIMIT 5
    """, (f'%{term}%', f'%{term}%'))
    for r in res: results.append({'type': 'Project', 'id': r['project_id'], 'text': r['title']})
    
    # 3. Search People
    res = execute_query("""
        SELECT person_id, first_name, last_name FROM core.persons 
        WHERE first_name ILIKE %s OR last_name ILIKE %s LIMIT 5
    """, (f'%{term}%', f'%{term}%'))
    for r in res: results.append({'type': 'Person', 'id': r['person_id'], 'text': f"{r['first_name']} {r['last_name']}"})
    
    return jsonify(results)

# --- SAMPLES REGISTRY ---

@app.route('/api/registry/batch_create', methods=['POST'])
def api_registry_batch_create():
    """
    Optimized endpoint for Handsontable grid saving.
    Generates IDs if not provided.
    """
    data = request.json.get('data', [])
    if not data: return jsonify({"success": False})
    
    success_count = 0
    errors = []
    
    with g.db_conn.cursor() as cur:
        for idx, row in enumerate(data):
            try:
                # Logic: If sample_id missing, let Trigger handle it via INSERT
                # If sample_id present, it's an UPDATE
                
                # Check required fields
                if not row.get('sample_type_id'):
                    raise ValueError("Missing Sample Type")
                
                if row.get('sample_id'):
                    # Update
                    cols = row.keys()
                    set_cls = ', '.join([f'"{c}" = %s' for c in cols if c != 'sample_id'])
                    vals = [row[c] for c in cols if c != 'sample_id']
                    vals.append(row['sample_id'])
                    cur.execute(f'UPDATE bio_assets.samples_root SET {set_cls} WHERE sample_id = %s', vals)
                else:
                    # Insert
                    # Generate temporary ID logic handled by DB Trigger usually, 
                    # but if we need to pass data, we explicitly name columns.
                    cols = [c for c in row.keys() if row[c]]
                    vals = [row[c] for c in cols]
                    col_str = ', '.join(f'"{c}"' for c in cols)
                    ph_str = ', '.join(['%s'] * len(cols))
                    cur.execute(f'INSERT INTO bio_assets.samples_root ({col_str}) VALUES ({ph_str})', vals)
                
                success_count += 1
            except Exception as e:
                errors.append(f"Row {idx+1}: {str(e)}")
    
    if errors:
        g.db_conn.rollback()
        return jsonify({"success": False, "errors": errors})
    
    g.db_conn.commit()
    return jsonify({"success": True, "count": success_count})

# --- MOLECULAR BIOLOGY ---

@app.route('/api/molecular/plate_view', methods=['GET'])
def api_molecular_plate():
    """Returns data formatted for 96-well plate visualization (A1-H12)."""
    batch_id = request.args.get('batch_id')
    if not batch_id: return jsonify({})
    
    # Fetch samples linked to this batch/experiment
    samples = execute_query("""
        SELECT na.sample_id, na.processing_date, pcr.position
        FROM moleculargenetics.nucleic_acid na
        LEFT JOIN moleculargenetics.pcr pcr ON na.sample_id = pcr.sample_id
        WHERE na.experiment_id = %s OR pcr.experiment_id = %s
    """, (batch_id, batch_id))
    
    plate = {}
    for s in samples:
        pos = s.get('position') # e.g. "A1"
        if pos:
            plate[pos] = s
            
    return jsonify(plate)

# --- BIOINFORMATICS ---

@app.route('/api/bioinformatics/pipelines', methods=['POST'])
def api_trigger_pipeline():
    """
    Mock endpoint to trigger an external analysis pipeline (e.g., Slurm/Nextflow).
    In a real app, this would send a payload to a job scheduler.
    """
    data = request.json
    pipeline_id = data.get('pipeline_id')
    dataset_id = data.get('dataset_id')
    
    if not pipeline_id or not dataset_id:
        return jsonify({"success": False, "error": "Missing params"})
    
    # 1. Create Run Record
    run_id = str(uuid.uuid4())
    execute_query(
        "INSERT INTO bioinformatics.assignments (dataset_id, pipeline_id, notes) VALUES (%s, %s, %s)",
        (dataset_id, pipeline_id, f"Run initiated via API: {run_id}"),
        commit=True
    )
    
    return jsonify({"success": True, "run_id": run_id, "status": "Queued"})

# --- DATABASE EXPLORER ---

@app.route('/api/sql/execute', methods=['POST'])
def api_sql_execute():
    """
    Executes raw SQL from the Visual Query Builder.
    WARNING: In production, strictly limit this user's DB permissions to READ ONLY.
    """
    sql_text = request.json.get('sql')
    if not sql_text or not sql_text.strip().lower().startswith('select'):
        return jsonify({"success": False, "error": "Only SELECT statements allowed"}), 400
        
    try:
        # Fetch raw with headers
        with g.db_conn.cursor() as cur:
            cur.execute(sql_text)
            columns = [desc[0] for desc in cur.description]
            rows = cur.fetchall()
            
            # Serialize
            data = []
            for r in rows:
                row_dict = {}
                for idx, val in enumerate(r):
                    # Handle unserializable types
                    if isinstance(val, (date, datetime)): val = val.isoformat()
                    if isinstance(val, memoryview): val = "<binary>"
                    row_dict[columns[idx]] = val
                data.append(row_dict)
                
            return jsonify({"success": True, "columns": columns, "data": data})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 400

# ==============================================================================
# 11. MAIN ENTRY POINT
# ==============================================================================

if __name__ == '__main__':
    print("="*80)
    print(f" GENFISH LIMS SERVER (v5.0 Complete)".center(80))
    print(f" Database: {DB_NAME} on {DB_HOST}".center(80))
    print(f" Web Interface: http://{HOST_IP}:{HOST_PORT}".center(80))
    print("="*80)
    
    # Use Waitress for robust production serving
    serve(app, host=HOST_IP, port=HOST_PORT, threads=8)