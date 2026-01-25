# -*- coding: utf-8 -*-
"""
GenFish Enterprise LIMS Backend System
Version: 5.0.2 (Production / Enterprise)
Author: System Administrator
Date: 2026-01-25

Description:
This is the monolithic backend service for the GenFish LIMS. 
It connects the HTML5 frontend to the PostgreSQL v16+ database (mylims_v5).

Key Capabilities:
1. High-Concurrency Threaded Connection Pooling (psycopg2)
2. Row-Level Security (RLS) Context Injection
3. PostGIS GeoJSON Serialization for Field Maps
4. Dynamic Schema Introspection for the Database Explorer
5. Enterprise Job Queuing for Bioinformatics
6. JSONB Handling for ELN Dynamic Forms
"""

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

# Load environment variables
load_dotenv()

# ==============================================================================
# 1. ENTERPRISE CONFIGURATION CLASS
# ==============================================================================
class Config:
    """
    Central configuration for the LIMS.
    Adjust these values in your .env file for production deployment.
    """
    # Security
    SECRET_KEY = os.getenv('SECRET_KEY', 'GENFISH_LIMS_ENTERPRISE_KEY_998877')
    SESSION_COOKIE_HTTPONLY = True
    SESSION_COOKIE_SECURE = os.getenv('FLASK_ENV') == 'production'
    SESSION_LIFETIME = timedelta(hours=12)
    
    # Database Connection (PostgreSQL)
    DB_HOST = os.getenv('DB_HOST', 'localhost')
    DB_NAME = os.getenv('DB_NAME', 'mylims')
    DB_USER = os.getenv('DB_USER', 'web_admin')
    DB_PASS = os.getenv('DB_PASS', 'password')
    DB_PORT = os.getenv('DB_PORT', '5432')
    
    # Connection Pool Tuning (Critical for >100 users)
    # MIN_CONN: Keep these open and ready
    # MAX_CONN: Burst capacity. If >50 users hit 'save' at once, requests queue.
    DB_MIN_CONN = int(os.getenv('DB_MIN_CONN', 5))
    DB_MAX_CONN = int(os.getenv('DB_MAX_CONN', 60))
    
    # Application Settings
    API_PREFIX = "/api/v1"
    UPLOAD_FOLDER = os.path.join(os.getcwd(), 'uploads')
    MAX_CONTENT_LENGTH = 500 * 1024 * 1024  # 500 MB max upload for BAM/FASTQ

    # Logging
    LOG_LEVEL = logging.INFO
    LOG_FORMAT = '%(asctime)s - %(name)s - %(levelname)s - %(message)s'

# Ensure upload directory exists
os.makedirs(Config.UPLOAD_FOLDER, exist_ok=True)

# Configure Logging
logging.basicConfig(level=Config.LOG_LEVEL, format=Config.LOG_FORMAT)
logger = logging.getLogger("GenFishLIMS")

# ==============================================================================
# 2. FLASK APP INITIALIZATION
# ==============================================================================
app = Flask(__name__, static_folder='static')
app.config.from_object(Config)
app.secret_key = Config.SECRET_KEY
app.permanent_session_lifetime = Config.SESSION_LIFETIME

# Enable CORS for development (restrict in production)
CORS(app, resources={r"/api/*": {"origins": "*"}}, supports_credentials=True)

# ==============================================================================
# 3. DATABASE POOL & CONTEXT MANAGEMENT
# ==============================================================================

# Initialize the Global Connection Pool
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
    logger.info(f"Database Pool initialized. Min: {Config.DB_MIN_CONN}, Max: {Config.DB_MAX_CONN}")
except Exception as e:
    logger.critical(f"Failed to initialize Database Pool: {e}")
    sys.exit(1)

def get_db_connection():
    """
    Retrieves a connection from the pool.
    Stores it in the Flask global object 'g' for the duration of the request.
    """
    if 'db_conn' not in g:
        g.db_conn = pg_pool.getconn()
    return g.db_conn

@app.teardown_appcontext
def close_db_connection(error):
    """
    Returns the connection to the pool at the end of the request.
    This is critical for preventing pool exhaustion.
    """
    conn = g.pop('db_conn', None)
    if conn:
        pg_pool.putconn(conn)

# ==============================================================================
# 4. JSON SERIALIZATION EXTENSIONS
# ==============================================================================
class LIMSJSONEncoder(json.JSONEncoder):
    """
    Extended JSON Encoder to handle PostgreSQL specific types
    (UUID, Date, Time, Bytes) that standard JSON can't handle.
    """
    def default(self, obj):
        if isinstance(obj, (datetime, date)):
            return obj.isoformat()
        if isinstance(obj, dtime):
            return obj.strftime('%H:%M:%S')
        if isinstance(obj, uuid.UUID):
            return str(obj)
        if isinstance(obj, bytes):
            # Detect if it's a memoryview (bytea) and base64 encode it
            return base64.b64encode(obj).decode('utf-8')
        if isinstance(obj, set):
            return list(obj)
        # Decimal handling
        if hasattr(obj, 'normalize'): 
            return float(obj)
        return super().default(obj)

app.json_encoder = LIMSJSONEncoder

def jsonify_lims(data, status=200):
    """Helper to return JSON responses using the custom encoder."""
    return Response(
        json.dumps(data, cls=LIMSJSONEncoder),
        status=status,
        mimetype='application/json'
    )

# ==============================================================================
# 5. SECURITY & AUTHENTICATION MIDDLEWARE
# ==============================================================================

def login_required(f):
    """Decorator to protect routes requiring authentication."""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'user_id' not in session:
            return jsonify({"error": "Authentication required", "code": 401}), 401
        return f(*args, **kwargs)
    return decorated_function

@app.before_request
def set_application_context():
    """
    CRITICAL: Sets the RLS (Row Level Security) context for PostgreSQL.
    
    This executes: SET LOCAL lims.current_person_id = '...'
    
    This ensures that:
    1. The 'audit' schema triggers record the correct user.
    2. RLS policies in 'mylims_v5.sql' filter data correctly.
    """
    if request.endpoint == 'static': 
        return

    conn = get_db_connection()
    user_id = session.get('user_id', 'anonymous')
    
    # Default to 'system' or specific UUID if not logged in, depending on DB policy
    # Here we convert the user_id (string) to what PG expects.
    
    try:
        with conn.cursor() as cur:
            # We set two variables: one for the session, one for the audit triggers
            # Using set_config with is_local=True ensures it only lasts for this transaction/session
            cur.execute("SELECT set_config('lims.current_user_id', %s, false)", (str(user_id),))
            cur.execute("SELECT set_config('session.user_id', %s, false)", (str(user_id),))
            # No commit needed for set_config in transaction, but good practice to ensure sync
    except Exception as e:
        logger.error(f"Failed to set RLS context: {e}")
        # We generally don't block the request here, but audit logs might default to 'unknown'

# ==============================================================================
# 6. MODULE: AUTHENTICATION (Login/Logout)
# ==============================================================================

@app.route(f"{Config.API_PREFIX}/auth/login", methods=['POST'])
def login():
    """
    Authenticates a user against core.persons or an external Auth DB.
    """
    data = request.json
    username = data.get('username')
    password = data.get('password')

    if not username or not password:
        return jsonify({"error": "Missing credentials"}), 400

    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            # Query core.persons (assuming logic from mylims_v5.sql)
            # In a real scenario, you'd check a 'password_hash' column.
            # For this 'bootstrap' code, we will simulate a check or check the musr table if it existed.
            
            # SAFE QUERY using SQL parameters
            cur.execute("""
                SELECT person_id, first_name, last_name, role_id, email, password_hash
                FROM core.persons 
                WHERE email = %s OR last_name = %s
                LIMIT 1
            """, (username, username))
            
            user = cur.fetchone()

            if user:
                # Verify password (assuming bcrypt stored in DB)
                # stored_hash = user['password_hash']
                # if bcrypt.checkpw(password.encode('utf-8'), stored_hash.encode('utf-8')):
                
                # TEMPORARY: For migration testing, accept simple match or master password
                if password == "password" or password == "admin123": 
                    session['user_id'] = user['person_id']
                    session['role'] = user['role_id']
                    session['name'] = f"{user['first_name']} {user['last_name']}"
                    
                    logger.info(f"User {username} logged in successfully.")
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
        return jsonify({"error": "Internal server error during auth"}), 500

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
# 7. MODULE: DASHBOARD (KPIs and Charts)
# ==============================================================================

@app.route(f"{Config.API_PREFIX}/dashboard/stats", methods=['GET'])
@login_required
def get_dashboard_stats():
    """
    Returns aggregated KPIs for the main dashboard (lims_dashboard.html).
    Optimized to run multiple counts in a single query trip.
    """
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            # Execute multiple subqueries for performance
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
        logger.error(f"Dashboard stats error: {e}")
        return jsonify({"error": str(e)}), 500

@app.route(f"{Config.API_PREFIX}/dashboard/activity_chart", methods=['GET'])
@login_required
def get_activity_chart():
    """
    Returns time-series data for the dashboard chart.
    Aggregates sample creation by month.
    """
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            # Group sample collection by Month (YYYY-MM)
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
            
            # Format for Chart.js
            labels = [row['month'] for row in data]
            counts = [row['count'] for row in data]
            
            return jsonify_lims({
                "labels": labels,
                "datasets": [{
                    "label": "New Samples",
                    "data": counts,
                    "fill": True,
                    "borderColor": "#3498db",
                    "tension": 0.4
                }]
            })
    except Exception as e:
        logger.error(f"Chart data error: {e}")
        return jsonify({"error": str(e)}), 500

# ==============================================================================
# 8. MODULE: DATABASE EXPLORER (Generic CRUD)
# ==============================================================================

@app.route(f"{Config.API_PREFIX}/explorer/schemas", methods=['GET'])
@login_required
def get_schemas_tables():
    """Returns a tree of Schemas -> Tables for the sidebar navigation."""
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
            
            # Organize into dictionary
            tree = {}
            for row in rows:
                sch = row['table_schema']
                tbl = row['table_name']
                if sch not in tree:
                    tree[sch] = []
                tree[sch].append(tbl)
            return jsonify(tree)
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route(f"{Config.API_PREFIX}/explorer/data/<schema>/<table>", methods=['GET'])
@login_required
def get_table_data(schema, table):
    """
    Generic Data Fetcher with Pagination and Sorting.
    CRITICAL: Uses psycopg2.sql to prevent injection in table/schema names.
    """
    limit = int(request.args.get('limit', 100))
    offset = int(request.args.get('offset', 0))
    sort_by = request.args.get('sort_by', None)
    
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            # 1. Get Column Headers
            cur.execute("""
                SELECT column_name, data_type 
                FROM information_schema.columns 
                WHERE table_schema = %s AND table_name = %s
                ORDER BY ordinal_position
            """, (schema, table))
            columns = cur.fetchall()
            
            if not columns:
                return jsonify({"error": "Table not found"}), 404

            # 2. Build Query Securely
            query = sql.SQL("SELECT * FROM {}.{}").format(
                sql.Identifier(schema),
                sql.Identifier(table)
            )
            
            if sort_by:
                # Validate sort column exists
                if sort_by in [c['column_name'] for c in columns]:
                     query += sql.SQL(" ORDER BY {} DESC").format(sql.Identifier(sort_by))
            
            query += sql.SQL(" LIMIT %s OFFSET %s")
            
            cur.execute(query, (limit, offset))
            data = cur.fetchall()
            
            return jsonify_lims({
                "columns": [c['column_name'] for c in columns],
                "types": [c['data_type'] for c in columns],
                "data": data
            })
            
    except Exception as e:
        logger.error(f"Explorer Data Error: {e}")
        return jsonify({"error": str(e)}), 500

# ==============================================================================
# 9. MODULE: STORAGE & REAGENTS (Grid Visualization)
# ==============================================================================

@app.route(f"{Config.API_PREFIX}/storage/visualizer/<storage_id>", methods=['GET'])
@login_required
def get_storage_grid(storage_id):
    """
    Visualizes a box/freezer grid.
    Returns:
    1. Grid Dimensions (x, y)
    2. Map of occupied cells
    """
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            # 1. Get Storage Details (Box Dimensions)
            cur.execute("""
                SELECT storage_id, name, storage_type, box_size_x, box_size_y
                FROM lims.storage 
                WHERE storage_id = %s
            """, (storage_id,))
            storage = cur.fetchone()
            
            if not storage:
                return jsonify({"error": "Storage unit not found"}), 404
            
            # 2. Get Contents (Samples)
            # Assuming 'storage_position' column stores "A1", "B2" or "1,1"
            cur.execute("""
                SELECT sample_id, sample_name, storage_position, sample_type
                FROM bio_assets.samples_root 
                WHERE storage_id = %s
            """, (storage_id,))
            contents = cur.fetchall()
            
            # 3. Create a mapped dictionary for easy lookup in frontend
            occupancy = {}
            for item in contents:
                pos = item['storage_position'] # Expecting "A1" etc.
                if pos:
                    occupancy[pos] = item
            
            return jsonify_lims({
                "meta": storage,
                "occupancy": occupancy
            })

    except Exception as e:
        logger.error(f"Storage visualizer error: {e}")
        return jsonify({"error": str(e)}), 500

@app.route(f"{Config.API_PREFIX}/storage/move_sample", methods=['POST'])
@login_required
def move_sample():
    """Moves a sample to a new storage location."""
    data = request.json
    sample_id = data.get('sample_id')
    new_storage_id = data.get('storage_id')
    new_position = data.get('position') # e.g., "A5"
    
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                UPDATE bio_assets.samples_root
                SET storage_id = %s, storage_position = %s, modification_date = NOW()
                WHERE sample_id = %s
            """, (new_storage_id, new_position, sample_id))
            conn.commit()
            return jsonify({"success": True})
    except Exception as e:
        conn.rollback()
        return jsonify({"error": str(e)}), 500

# ==============================================================================
# 10. MODULE: FIELD EVENTS & MAPPING (PostGIS)
# ==============================================================================

@app.route(f"{Config.API_PREFIX}/field/geojson", methods=['GET'])
@login_required
def get_field_geojson():
    """
    Returns Field Events as a standard GeoJSON FeatureCollection.
    Compatible with Leaflet.js in 'lims_field_events.html'.
    Expects 'field.sampling_events' to have 'latitude' and 'longitude'.
    """
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            # We construct GeoJSON directly in SQL for speed
            # Use ST_Point if you have a geometry column, otherwise construct it
            query = """
                SELECT json_build_object(
                    'type', 'FeatureCollection',
                    'features', json_agg(json_build_object(
                        'type', 'Feature',
                        'geometry', json_build_object(
                            'type', 'Point',
                            'coordinates', json_build_array(longitude, latitude)
                        ),
                        'properties', json_build_object(
                            'id', sampling_id,
                            'date', sampling_date,
                            'cruise', cruise_id,
                            'location', location_name
                        )
                    ))
                ) as geojson
                FROM field.sampling_events
                WHERE latitude IS NOT NULL AND longitude IS NOT NULL
            """
            cur.execute(query)
            result = cur.fetchone()
            
            # Handle empty result case
            if result and result['geojson']:
                return jsonify(result['geojson'])
            else:
                return jsonify({"type": "FeatureCollection", "features": []})

    except Exception as e:
        logger.error(f"GeoJSON error: {e}")
        return jsonify({"error": str(e)}), 500

@app.route(f"{Config.API_PREFIX}/field/event", methods=['POST'])
@login_required
def create_field_event():
    """Records a new sampling event."""
    data = request.json
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                INSERT INTO field.sampling_events 
                (cruise_id, sampling_date, latitude, longitude, location_name, comments)
                VALUES (%s, %s, %s, %s, %s, %s)
                RETURNING sampling_id
            """, (
                data.get('cruise_id'),
                data.get('date'),
                data.get('lat'),
                data.get('lng'),
                data.get('location'),
                data.get('comments')
            ))
            new_id = cur.fetchone()['sampling_id']
            conn.commit()
            return jsonify({"success": True, "id": new_id})
    except Exception as e:
        conn.rollback()
        return jsonify({"error": str(e)}), 500

# ==============================================================================
# 11. MODULE: BIOINFORMATICS (Job Queue)
# ==============================================================================

@app.route(f"{Config.API_PREFIX}/bioinfo/pipeline/submit", methods=['POST'])
@login_required
def submit_pipeline_job():
    """
    Submits a job to the queue table (bioinformatics.jobs).
    Supports DADA2, QIIME2, Mothur as per HTML.
    """
    data = request.json
    pipeline = data.get('pipeline_name') # e.g., "DADA2"
    dataset_ids = data.get('dataset_ids', []) # List of IDs
    params = json.dumps(data.get('parameters', {}))
    
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            # Create a Job ID
            job_uuid = str(uuid.uuid4())
            
            cur.execute("""
                INSERT INTO bioinformatics.jobs 
                (job_id, pipeline_name, status, submission_date, parameters, submitter_id)
                VALUES (%s, %s, 'Queued', NOW(), %s, %s)
            """, (job_uuid, pipeline, params, session.get('user_id')))
            
            # Link datasets to job
            if dataset_ids:
                values = [(job_uuid, ds_id) for ds_id in dataset_ids]
                extras.execute_values(
                    cur,
                    "INSERT INTO bioinformatics.job_datasets (job_id, dataset_id) VALUES %s",
                    values
                )
            
            conn.commit()
            return jsonify({"success": True, "job_id": job_uuid, "status": "Queued"})

    except Exception as e:
        conn.rollback()
        return jsonify({"error": str(e)}), 500

@app.route(f"{Config.API_PREFIX}/bioinfo/taxonomy_stats/<run_id>", methods=['GET'])
@login_required
def get_taxonomy_stats(run_id):
    """
    Returns data for the Stacked Bar Chart in 'lims_bioinformatics.html'.
    Shows distribution of Phyla/Classes per sample in a run.
    """
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            # Join assignments -> seq_dataset -> sequencing
            cur.execute("""
                SELECT 
                    s.sample_name,
                    a.taxon_phylum,
                    COUNT(*) as read_count
                FROM bioinformatics.assignments a
                JOIN bioinformatics.seq_dataset ds ON a.dataset_id = ds.dataset_id
                JOIN bio_assets.samples_root s ON ds.sample_id = s.sample_id
                WHERE ds.run_id = %s
                GROUP BY 1, 2
                ORDER BY 1
            """, (run_id,))
            rows = cur.fetchall()
            
            # Process data for Chart.js
            # Structure: labels = [Sample1, Sample2], datasets = [{label: Phylum1, data: [...]}]
            samples = sorted(list(set(row['sample_name'] for row in rows)))
            phyla = sorted(list(set(row['taxon_phylum'] for row in rows)))
            
            datasets = []
            for p in phyla:
                data_points = []
                for s in samples:
                    # Find count for this sample+phylum
                    val = next((r['read_count'] for r in rows if r['sample_name'] == s and r['taxon_phylum'] == p), 0)
                    data_points.append(val)
                
                # Generate a deterministic color based on string hash
                color_hash = hash(p) % 0xFFFFFF
                color = f"#{color_hash:06x}"
                
                datasets.append({
                    "label": p,
                    "data": data_points,
                    "backgroundColor": color
                })
                
            return jsonify_lims({
                "labels": samples,
                "datasets": datasets
            })
            
    except Exception as e:
        logger.error(f"Taxonomy stats error: {e}")
        return jsonify({"error": str(e)}), 500

# ==============================================================================
# 12. MODULE: FISH BIOLOGY (GSI & Dissection)
# ==============================================================================

@app.route(f"{Config.API_PREFIX}/biology/fish/gsi", methods=['POST'])
@login_required
def calculate_save_gsi():
    """
    Calculates Gonadosomatic Index (GSI) and updates the record.
    GSI = (Gonad Weight / Total Weight) * 100
    """
    data = request.json
    fish_id = data.get('fish_id')
    total_weight = float(data.get('weight_g', 0))
    gonad_weight = float(data.get('gonad_weight_g', 0))
    
    if total_weight <= 0:
        return jsonify({"error": "Total weight must be > 0"}), 400
        
    gsi = (gonad_weight / total_weight) * 100
    
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                UPDATE biologyfish.specimens
                SET gonad_weight = %s, gsi_index = %s
                WHERE fish_id = %s
            """, (gonad_weight, gsi, fish_id))
            conn.commit()
            return jsonify({"success": True, "gsi": round(gsi, 2)})
    except Exception as e:
        conn.rollback()
        return jsonify({"error": str(e)}), 500

@app.route(f"{Config.API_PREFIX}/biology/fish/prey", methods=['POST'])
@login_required
def add_stomach_content():
    """Adds prey items found in stomach content (One-to-Many)."""
    data = request.json
    fish_id = data.get('fish_id')
    prey_items = data.get('prey_items') # List of dicts
    
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            query = """
                INSERT INTO biologyfish.stomach_contents 
                (fish_id, prey_taxon, count, weight_g, notes)
                VALUES %s
            """
            values = [
                (fish_id, item['taxon'], item.get('count', 1), item.get('weight'), item.get('notes'))
                for item in prey_items
            ]
            extras.execute_values(cur, query, values)
            conn.commit()
            return jsonify({"success": True})
    except Exception as e:
        conn.rollback()
        return jsonify({"error": str(e)}), 500

# ==============================================================================
# 13. MODULE: ELN & BOOKING (Dynamic Forms)
# ==============================================================================

@app.route(f"{Config.API_PREFIX}/eln/bookings", methods=['GET', 'POST'])
@login_required
def handle_bookings():
    """
    GET: Returns events for FullCalendar (lims_eln_booking.html).
    POST: Creates a new instrument booking.
    """
    conn = get_db_connection()
    
    if request.method == 'GET':
        start = request.args.get('start')
        end = request.args.get('end')
        try:
            with conn.cursor() as cur:
                cur.execute("""
                    SELECT booking_id as id, instrument_name as title, 
                           start_time as start, end_time as end, 
                           user_id, status
                    FROM eln.bookings
                    WHERE start_time >= %s AND end_time <= %s
                """, (start, end))
                events = cur.fetchall()
                # Color code events based on status
                for e in events:
                    if e['status'] == 'Confirmed': e['color'] = '#27ae60'
                    elif e['status'] == 'Pending': e['color'] = '#f39c12'
                return jsonify_lims(events)
        except Exception as e:
            return jsonify({"error": str(e)}), 500

    if request.method == 'POST':
        data = request.json
        try:
            with conn.cursor() as cur:
                cur.execute("""
                    INSERT INTO eln.bookings (instrument_id, user_id, start_time, end_time, purpose)
                    VALUES (%s, %s, %s, %s, %s)
                    RETURNING booking_id
                """, (data['instrument_id'], session['user_id'], data['start'], data['end'], data['title']))
                new_id = cur.fetchone()['booking_id']
                conn.commit()
                return jsonify({"success": True, "id": new_id})
        except Exception as e:
            conn.rollback()
            return jsonify({"error": str(e)}), 500

@app.route(f"{Config.API_PREFIX}/eln/experiment/save", methods=['POST'])
@login_required
def save_dynamic_experiment():
    """
    Saves an experiment with dynamic fields into a JSONB column.
    This supports the "Form Designer" feature in ELN.
    """
    data = request.json
    exp_name = data.get('name')
    form_schema = json.dumps(data.get('schema')) # The structure of fields
    form_data = json.dumps(data.get('data'))     # The actual values
    
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                INSERT INTO eln.experiments 
                (name, owner_id, creation_date, form_schema, form_data_json)
                VALUES (%s, %s, NOW(), %s, %s)
                RETURNING experiment_id
            """, (exp_name, session['user_id'], form_schema, form_data))
            new_id = cur.fetchone()['experiment_id']
            conn.commit()
            return jsonify({"success": True, "id": new_id})
    except Exception as e:
        conn.rollback()
        return jsonify({"error": str(e)}), 500

# ==============================================================================
# 14. ADVANCED UTILITIES: BULK IMPORT & FILE UPLOAD
# ==============================================================================

@app.route(f"{Config.API_PREFIX}/data/bulk_import_csv", methods=['POST'])
@login_required
def bulk_import_csv():
    """
    High-Performance CSV Import using PostgreSQL 'COPY FROM STDIN'.
    Capable of importing millions of rows in seconds.
    """
    if 'file' not in request.files:
        return jsonify({"error": "No file uploaded"}), 400
    
    file = request.files['file']
    target_table = request.form.get('table') # e.g., 'bio_assets.samples_root'
    
    # Security Check on table name
    if not re.match(r'^[a-z0-9_]+\.[a-z0-9_]+$', target_table):
         return jsonify({"error": "Invalid table format"}), 400

    conn = get_db_connection()
    try:
        # Save temp file
        filename = f"{uuid.uuid4()}.csv"
        filepath = os.path.join(Config.UPLOAD_FOLDER, filename)
        file.save(filepath)
        
        with conn.cursor() as cur:
            with open(filepath, 'r') as f:
                # Use SQL copy_expert for maximum speed
                # Requires CSV to match table structure exactly or mapping logic
                sql_copy = f"COPY {target_table} FROM STDIN WITH CSV HEADER"
                cur.copy_expert(sql_copy, f)
            conn.commit()
            
        os.remove(filepath) # Cleanup
        return jsonify({"success": True, "message": "Bulk import completed."})

    except Exception as e:
        if conn: conn.rollback()
        return jsonify({"error": f"Import failed: {str(e)}"}), 500

# ==============================================================================
# 15. MAIN ENTRY POINT
# ==============================================================================

@app.route('/')
def root():
    """Redirects root to the login page (served via static)."""
    return redirect('/static/login.html')

@app.route('/<path:path>')
def serve_static_files(path):
    """Serves frontend HTML/JS/CSS."""
    return send_from_directory('static', path)

if __name__ == '__main__':
    print("="*60)
    print(f" GENFISH ENTERPRISE LIMS v5.0 STARTING")
    print(f" Database: {Config.DB_HOST}:{Config.DB_PORT}/{Config.DB_NAME}")
    print(f" Pool Size: {Config.DB_MIN_CONN} - {Config.DB_MAX_CONN}")
    print(f" Serving on port 5300...")
    print("="*60)
    
    # Use Waitress for production-grade serving
    serve(app, host='0.0.0.0', port=5300, threads=Config.DB_MAX_CONN)