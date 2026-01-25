import os
import json
import pandas as pd
from datetime import datetime
from flask import Flask, render_template, request, jsonify, send_from_directory
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy import text, inspect
from sqlalchemy.ext.automap import automap_base
from werkzeug.utils import secure_filename

# --- CONFIGURATION ---
app = Flask(__name__)

# Database Connection (Update with your actual credentials)
app.config['SQLALCHEMY_DATABASE_URI'] = os.environ.get('DATABASE_URL', 'postgresql://genfish_user:secure_pass@localhost:5432/mylims_v5')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['UPLOAD_FOLDER'] = './uploads'
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024  # 16MB max upload

# Ensure directories exist
os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)
os.makedirs(os.path.join(app.config['UPLOAD_FOLDER'], 'gels'), exist_ok=True)
os.makedirs(os.path.join(app.config['UPLOAD_FOLDER'], 'otoliths'), exist_ok=True)
os.makedirs(os.path.join(app.config['UPLOAD_FOLDER'], 'docs'), exist_ok=True)

db = SQLAlchemy(app)

# --- DATABASE REFLECTION ---
# Automap allows simple ORM access, but we will primarily use raw SQL for complex multi-schema operations
Base = automap_base()

def reflect_db():
    with app.app_context():
        try:
            # Reflect all tables for basic ORM usage if needed
            Base.prepare(db.engine, reflect=True)
            print("Database Schema Reflected Successfully.")
        except Exception as e:
            print(f"Warning during reflection: {e}")

# Call reflection
try:
    reflect_db()
except Exception as e:
    print(f"DB Connection Error: {e}")


# --- HTML PAGE ROUTES ---

@app.route('/')
def index(): return render_template('lims_dashboard_design.html')

@app.route('/samples')
def samples_registry(): return render_template('lims_samples_registry.html')

@app.route('/field')
def field_events(): return render_template('lims_field_events.html')

@app.route('/molecular')
def molecular_lab(): return render_template('lims_molecular_biology.html')

@app.route('/biology')
def biology_fish(): return render_template('lims_biology_fish.html')

@app.route('/storage')
def storage(): return render_template('lims_storage_reagents.html')

@app.route('/bioinformatics')
def bioinformatics(): return render_template('lims_bioinformatics.html')

@app.route('/projects')
def projects(): return render_template('lims_project_collaboration.html')

@app.route('/eln')
def eln(): return render_template('lims_eln_booking.html')

@app.route('/explorer')
def db_explorer(): return render_template('lims_database_explorer.html')

@app.route('/settings')
def settings(): return render_template('lims_settings.html')


# --- API: CORE SYSTEM ---

@app.route('/api/schema')
def get_schema_info():
    """
    Dynamically returns the database structure (Schemas > Tables) 
    to populate the Database Explorer sidebar.
    """
    try:
        sql = text("""
            SELECT table_schema, table_name 
            FROM information_schema.tables 
            WHERE table_schema NOT IN ('information_schema', 'pg_catalog') 
            ORDER BY table_schema, table_name
        """)
        result = db.session.execute(sql).fetchall()
        
        schema_tree = {}
        for row in result:
            schema = row.table_schema
            table = row.table_name
            if schema not in schema_tree:
                schema_tree[schema] = []
            schema_tree[schema].append({'name': table, 'icon': 'fa-table'})
            
        return jsonify(schema_tree)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/search')
def global_search():
    """
    Executes the PL/pgSQL function dashboard.fn_global_search(:q)
    """
    query = request.args.get('q', '')
    if not query: return jsonify([])
    
    try:
        sql = text("SELECT * FROM dashboard.fn_global_search(:q)")
        # Execute and map result to dictionary
        results = db.session.execute(sql, {'q': query}).fetchall()
        data = [dict(row._mapping) for row in results]
        return jsonify(data)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/dashboard/kpis')
def get_dashboard_stats():
    """
    Aggregates stats from various schemas for the main dashboard.
    """
    try:
        kpis = {
            'samples': db.session.execute(text("SELECT COUNT(*) FROM bio_assets.samples_root WHERE status_id != 'Destroyed'")).scalar(),
            'projects': db.session.execute(text("SELECT COUNT(*) FROM lims.projects WHERE status_id = 'Active'")).scalar(),
            'batches': db.session.execute(text("SELECT COUNT(*) FROM eln.batch WHERE status_id = 'Open'")).scalar(),
            'reads': round((db.session.execute(text("SELECT COALESCE(SUM(read_count_filtered), 0) FROM bioinformatics.seq_dataset")).scalar() or 0) / 1000000, 1)
        }
        
        # Monthly throughput from materialized view
        # Ensure 'dashboard.monthly_lab_throughput_mv' exists in your SQL or create a fallback query
        try:
            tp_sql = text("SELECT * FROM dashboard.monthly_lab_throughput_mv ORDER BY month_period DESC LIMIT 6")
            throughput = [dict(row._mapping) for row in db.session.execute(tp_sql).fetchall()]
        except:
            throughput = [] # Fallback if view doesn't exist yet

        return jsonify({'kpis': kpis, 'throughput': throughput})
    except Exception as e:
        return jsonify({'error': str(e)}), 500


# --- API: DATA MANAGEMENT (CRUD & IMPORT) ---

@app.route('/api/table/<schema>/<table>', methods=['GET'])
def get_table_data(schema, table):
    """
    Generic table viewer with pagination/limit.
    """
    try:
        # Basic SQL injection protection (whitelist schemas if necessary)
        if schema not in ['bio_assets', 'field', 'biologyfish', 'moleculargenetics', 'bioinformatics', 'lims', 'core', 'reference', 'eln', 'communications', 'audit']:
            return jsonify({'error': 'Invalid schema'}), 403
            
        limit = request.args.get('limit', 1000)
        sql = text(f'SELECT * FROM "{schema}"."{table}" LIMIT :limit')
        result = db.session.execute(sql, {'limit': limit}).fetchall()
        
        # Handle UUIDs and Dates serialization by converting to simple dicts (Flask jsonify handles most types)
        data = [dict(row._mapping) for row in result]
        return jsonify(data)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/crud/<schema>/<table>', methods=['POST', 'PUT', 'DELETE'])
def generic_crud(schema, table):
    """
    Generic Insert/Update/Delete handler.
    Ideally, use specific routes for complex logic, but this serves the Database Explorer.
    """
    data = request.json
    try:
        if request.method == 'POST':
            # INSERT
            cols = data.keys()
            vals = [f":{c}" for c in cols]
            sql = text(f'INSERT INTO "{schema}"."{table}" ({", ".join(cols)}) VALUES ({", ".join(vals)}) RETURNING *')
            res = db.session.execute(sql, data)
            db.session.commit()
            return jsonify({'status': 'success', 'data': dict(res.fetchone()._mapping)}), 201

        elif request.method == 'PUT':
            # UPDATE (Expects 'pk_column' and 'pk_value' in query params, or infer from data)
            # Simplified: Assumes ID is in data payload and matches table name pattern or is generic 'id'
            # In production, use introspection to find PK.
            
            # Extract PK (simplistic approach)
            pk = next((k for k in data.keys() if 'id' in k), 'id')
            pk_val = data.pop(pk)
            
            updates = [f"{k} = :{k}" for k in data.keys()]
            sql = text(f'UPDATE "{schema}"."{table}" SET {", ".join(updates)} WHERE {pk} = :pk_val')
            data['pk_val'] = pk_val
            db.session.execute(sql, data)
            db.session.commit()
            return jsonify({'status': 'updated'}), 200
            
        elif request.method == 'DELETE':
            # DELETE
            pk = request.args.get('pk', 'id')
            val = request.args.get('val')
            sql = text(f'DELETE FROM "{schema}"."{table}" WHERE {pk} = :val')
            db.session.execute(sql, {'val': val})
            db.session.commit()
            return jsonify({'status': 'deleted'}), 200

    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@app.route('/api/import/bulk', methods=['POST'])
def bulk_import():
    """
    Advanced Import: Handles standard headers AND 2-row headers (Table/Column).
    """
    if 'file' not in request.files: return jsonify({'error': 'No file'}), 400
    file = request.files['file']
    if file.filename == '': return jsonify({'error': 'No selected file'}), 400

    import_format = request.form.get('format', 'flat') # 'flat' or '2row'
    mode = request.form.get('mode', 'upsert') 
    
    try:
        filename = secure_filename(file.filename)
        filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
        file.save(filepath)

        # 1. Handle Multi-Table Import (2-Row Header)
        if import_format == '2row':
            # Read header rows: Row 0 is Table Name, Row 1 is Column Name
            df = pd.read_excel(filepath, header=[0, 1])
            
            # Iterate through the top-level columns (Tables)
            tables = df.columns.get_level_values(0).unique()
            
            results = {}
            with db.engine.begin() as conn:
                for table_key in tables:
                    # Extract sub-dataframe for this table
                    sub_df = df[table_key].dropna(how='all') # Remove empty rows
                    if sub_df.empty: continue
                    
                    # Split schema.table
                    if '.' in table_key:
                        sch, tbl = table_key.split('.')
                    else:
                        sch, tbl = 'public', table_key
                    
                    # Insert logic
                    # Using pandas to_sql is easiest for 'append', custom SQL needed for 'upsert'
                    if mode == 'insert':
                        sub_df.to_sql(tbl, conn, schema=sch, if_exists='append', index=False)
                        results[table_key] = f"Inserted {len(sub_df)}"
                    else:
                        # For Upsert, we usually need a temp table strategy
                        temp_name = f"tmp_{tbl}_{int(datetime.now().timestamp())}"
                        sub_df.to_sql(temp_name, conn, schema=sch, if_exists='replace', index=False)
                        
                        # Construct Upsert SQL (On Conflict Do Update)
                        # NOTE: Requires knowing PK. This is a generic fallback.
                        columns = list(sub_df.columns)
                        pk_col = columns[0] # ASSUMPTION: First column is PK
                        update_set = ", ".join([f"{c} = EXCLUDED.{c}" for c in columns if c != pk_col])
                        
                        sql = text(f"""
                            INSERT INTO "{sch}"."{tbl}" ({", ".join(columns)})
                            SELECT {", ".join(columns)} FROM "{sch}"."{temp_name}"
                            ON CONFLICT ({pk_col}) DO UPDATE SET {update_set};
                            DROP TABLE "{sch}"."{temp_name}";
                        """)
                        conn.execute(sql)
                        results[table_key] = f"Upserted {len(sub_df)}"

            return jsonify({'message': 'Multi-table import successful', 'details': results})

        # 2. Handle Single Table Import (Flat Header)
        else:
            target_schema = request.form.get('schema', 'public')
            target_table = request.form.get('table')
            
            if filename.endswith('.csv'): df = pd.read_csv(filepath)
            else: df = pd.read_excel(filepath)
            
            df.to_sql(target_table, db.engine, schema=target_schema, if_exists='append', index=False)
            return jsonify({'message': f'Imported {len(df)} rows into {target_schema}.{target_table}'})

    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/upload', methods=['POST'])
def upload_file():
    """
    Generic file uploader for images/docs.
    Returns the file path relative to storage.
    """
    if 'file' not in request.files: return jsonify({'error': 'No file'}), 400
    file = request.files['file']
    category = request.form.get('category', 'docs') # gels, otoliths, docs
    
    if file:
        filename = secure_filename(f"{int(datetime.now().timestamp())}_{file.filename}")
        save_path = os.path.join(app.config['UPLOAD_FOLDER'], category, filename)
        file.save(save_path)
        
        # Return path for DB storage
        return jsonify({'path': save_path, 'filename': filename})
    return jsonify({'error': 'Upload failed'}), 500


# --- API: MODULE SPECIFICS ---

@app.route('/api/storage/tree')
def get_storage_tree_data():
    """
    Returns storage locations formatted for hierarchical view.
    Parsing 'ltree' path logic happens here or on client.
    """
    try:
        sql = text("SELECT storage_id, name, storage_type_id, path::text, parent_storage_id, current_capacity, total_capacity FROM lims.storage ORDER BY path")
        result = db.session.execute(sql).fetchall()
        data = [dict(row._mapping) for row in result]
        return jsonify(data)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/molecular/plate/<plate_id>')
def get_plate_data(plate_id):
    """
    Fetches samples associated with a specific plate/batch for the visualizer.
    """
    try:
        # Simplified query: assuming samples linked to batch or storage container
        sql = text("""
            SELECT s.sample_id, s.storage_id, na.conc_qubit, na.a260_280, p.well_position 
            FROM bio_assets.samples_root s
            JOIN moleculargenetics.nucleic_acid na ON s.sample_id = na.sample_id
            LEFT JOIN eln.plate_map p ON s.sample_id = p.sample_id
            WHERE p.plate_id = :pid
        """)
        result = db.session.execute(sql, {'pid': plate_id}).fetchall()
        return jsonify([dict(row._mapping) for row in result])
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# --- MAIN ---
if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)