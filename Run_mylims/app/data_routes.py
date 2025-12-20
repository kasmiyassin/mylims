# data_routes.py

from app import app, API_PREFIX, transform_row_for_json, get_pk_columns, _resolve_table_casing, _get_column_types, safe_date_parse, _parse_malformed_input
from flask import request, jsonify, g
import psycopg2
from psycopg2 import sql, extras
from datetime import datetime, date, time
import json
import base64
from typing import Any, Dict, List, Optional, Tuple, Union
import traceback

# --- Dashboard & Search Routes ---

@app.route(f'{API_PREFIX}/global-search/<string:search_term>', methods=['GET'])
def global_search(search_term: str):
    """Performs a global search across multiple tables."""
    # NOTE: Implementation remains the same as previous file versions.
    # It relies on existing search vector columns in your Postgres DB.
    ts_query_func = "plainto_tsquery('public.lims_english', %s)"
    search_pattern = f"%{search_term}%"
    results: Dict[str, List[Dict[str, Any]]] = {}
    
    queries: Dict[str, Tuple[str, Tuple[Any, ...]]] = {
        # ... [Queries defined here for projects, samples, experiments, etc.] ...
        "projects": (f'SELECT project_id, title FROM "lims"."projects" WHERE project_search_vector @@ {ts_query_func} OR "project_id" ILIKE %s OR "title" ILIKE %s LIMIT 5', (search_term, search_pattern, search_pattern)),
        "samples": (f'SELECT sample_id, external_name FROM "lab"."root_samples" WHERE sample_search_vector @@ {ts_query_func} OR "sample_id" ILIKE %s OR "external_name" ILIKE %s LIMIT 5', (search_term, search_pattern, search_pattern)),
        "experiments": (f'SELECT experiment_id, experiment_title FROM "lab"."experiments" WHERE experiment_search_vector @@ {ts_query_func} OR "experiment_id" ILIKE %s OR "experiment_title" ILIKE %s LIMIT 5', (search_term, search_pattern, search_pattern)),
        "sop": (f'SELECT sop_id, title FROM "lims"."sop" WHERE sop_search_vector @@ {ts_query_func} OR "sop_id" ILIKE %s OR "title" ILIKE %s LIMIT 5', (search_term, search_pattern, search_pattern)),
        "customers": (f'SELECT customer_id, customer_name FROM "lims"."customers" WHERE customer_search_vector @@ {ts_query_func} OR "customer_name" ILIKE %s LIMIT 5', (search_term, search_pattern)),
        "taxon": ('SELECT taxon_id, de_name, en_name FROM "reference"."taxon" WHERE "de_name" ILIKE %s OR "en_name" ILIKE %s LIMIT 5', (search_pattern, search_pattern)),
        "primers": ('SELECT primer_id, primer_sequence_fwd, primer_sequence_rev FROM "lims"."primers" WHERE "primer_id" ILIKE %s OR "primer_sequence_fwd" ILIKE %s OR "primer_sequence_rev" ILIKE %s LIMIT 5', (search_pattern, search_pattern, search_pattern)),
        "reagents": (f'SELECT reagent_id, reagent_complete_name, lot FROM "lims"."reagents" WHERE "reagent_search_vector" @@ {ts_query_func} OR "reagent_id" ILIKE %s OR "reagent_complete_name" ILIKE %s OR "lot" ILIKE %s LIMIT 5', (search_term, search_pattern, search_pattern, search_pattern)),
        "personal": ('SELECT person_id, full_name FROM "lims"."personal" WHERE "person_id" ILIKE %s OR "full_name" ILIKE %s LIMIT 5', (search_pattern, search_pattern)),
        "project_overview_view": ('SELECT project_id, title AS project_title FROM "lims"."project_comprehensive_summary_view" WHERE "project_id" ILIKE %s OR "title" ILIKE %s LIMIT 5', (search_pattern, search_pattern)),
        "analysis_results_summary_view": ('SELECT run_id, sample_id, taxon_en_name FROM "bioinformatics"."analysis_results_summary_view" WHERE "run_id" ILIKE %s OR "sample_id" ILIKE %s OR "taxon_en_name" ILIKE %s LIMIT 5', (search_pattern, search_pattern, search_pattern)),
    }
            
    try:
        conn = g.db_conn
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            for key, (query, params) in queries.items():
                try:
                    cur.execute(query, params)
                    results[key] = [transform_row_for_json(row) for row in cur.fetchall()]
                except Exception as inner_e:
                    print(f"Error executing search for {key}: {inner_e}")
                    results[key] = []
            return jsonify(results), 200
    except Exception as e:
        print(f"Global search error: {e}")
        return jsonify({"error": "An internal server error occurred during search."}), 500


@app.route(f'{API_PREFIX}/dashboard-stats', methods=['GET'])
def get_dashboard_stats():
    """Fetches key statistics for the dashboard."""
    # NOTE: Implementation remains the same as previous file versions.
    stats = {}
    try:
        conn = g.db_conn
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute("SELECT COUNT(*) AS active_projects FROM \"lims\".\"projects\" WHERE \"status_id\" = 'In Progress';")
            stats['active_projects'] = cur.fetchone()['active_projects']

            cur.execute("SELECT COUNT(*) AS total_samples FROM \"lab\".\"root_samples\";")
            stats['total_samples'] = cur.fetchone()['total_samples']

            current_month_start = datetime.now().replace(day=1, hour=0, minute=0, second=0, microsecond=0)
            cur.execute("""
                SELECT COUNT(*) AS experiments_this_month
                FROM "lab"."experiments"
                WHERE "experiment_date" >= %s;
            """, (current_month_start.date(),))
            stats['experiments_this_month'] = cur.fetchone()['experiments_this_month']

            cur.execute("""
                SELECT COUNT(*) AS active_orders
                FROM "lims"."orders"
                WHERE "status_id" = 'In Progress';
            """)
            stats['active_orders'] = cur.fetchone()['active_orders']

            cur.execute("""
                SELECT COUNT(DISTINCT storage_id) AS occupied_storage_units
                FROM "lab"."root_samples"
                WHERE storage_id IS NOT NULL;
            """)
            stats['occupied_storage_units'] = cur.fetchone()['occupied_storage_units']

            cur.execute("SELECT COUNT(*) AS total_sops FROM \"lims\".\"sop\";")
            stats['total_sops'] = cur.fetchone()['total_sops']
            
            cur.execute("SELECT COUNT(*) AS total_experiments FROM \"lab\".\"experiments\";")
            stats['total_experiments'] = cur.fetchone()['total_experiments']

            cur.execute("""
                SELECT COUNT(*) AS active_personnel
                FROM "lims"."personal"
                WHERE "status_id" != 'Destroyed' AND "status_id" != 'Archived';
            """)
            stats['active_personnel'] = cur.fetchone()['active_personnel']

        return jsonify(stats), 200
    except Exception as e:
        print(f"Dashboard stats error: {e}")
        return jsonify({"error": "An internal server error occurred while fetching dashboard stats."}), 500

# --- Table Metadata Routes ---

@app.route(f'{API_PREFIX}/table_names_for_forms', methods=['GET'])
def table_names_for_forms():
    """Returns a list of all table and view names in specified schemas."""
    try:
        conn = g.db_conn
        with conn.cursor() as cur:
            query = """
            SELECT table_schema || '.' || table_name
            FROM information_schema.tables
            WHERE table_schema IN ('lab', 'lims', 'reference', 'bioinformatics', 'audit', 'projects')
              AND table_type IN ('BASE TABLE', 'VIEW', 'MATERIALIZED VIEW')
              AND table_name NOT LIKE '%_seq'
              AND table_name NOT LIKE '%_y%'
              AND table_name NOT IN ('log', 'master_samples')
            ORDER BY table_schema, table_name;
            """
            cur.execute(query)
            tables = [row[0] for row in cur.fetchall()]
            return jsonify(tables), 200
    except Exception as e:
        print(f"Error fetching table names for forms: {e}")
        return jsonify({"error": str(e)}), 500

@app.route(f'{API_PREFIX}/table/<string:schema>/<string:table>/schema', methods=['GET'])
def get_table_schema(schema: str, table: str):
    """Fetches the schema (column names and data types) for a given table."""
    try:
        conn = g.db_conn
        resolved = _resolve_table_casing(conn, schema, table)
        if not resolved:
            return jsonify({"error": f"Table or view '{schema}.{table}' not found or inaccessible."}), 404
        
        actual_schema, actual_table, table_type_info = resolved

        query = """
            SELECT 
                c.column_name, 
                c.data_type, 
                c.is_nullable, 
                c.column_default
            FROM information_schema.columns c
            WHERE c.table_schema = %s AND c.table_name = %s
            ORDER BY c.ordinal_position;
        """
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute(query, (actual_schema, actual_table))
            columns = cur.fetchall()
        
        pk_columns = get_pk_columns(actual_schema, actual_table)
        for col in columns:
            col['is_primary_key'] = col['column_name'] in pk_columns
            col['table_type'] = table_type_info

        return jsonify(columns), 200
    except Exception as e:
        print(f"Error fetching schema for {schema}.{table}: {e}")
        return jsonify({"error": str(e)}), 500


@app.route(f'{API_PREFIX}/table/<string:schema>/<string:table>/distinct_values', methods=['GET'])
def get_distinct_column_values(schema: str, table: str):
    """Fetches a list of distinct, non-null values for a specified column."""
    conn = g.db_conn
    column_name = request.args.get('column')
    
    if not column_name:
        return jsonify({"error": "Missing 'column' parameter"}), 400

    try:
        resolved = _resolve_table_casing(conn, schema, table)
        if not resolved:
            return jsonify({"error": f"Table or view '{schema}.{table}' not found or inaccessible."}), 404
        actual_schema, actual_table, table_type = resolved
        
        column_types = _get_column_types(conn, actual_schema, actual_table)

        if column_name not in column_types:
            return jsonify({"error": f"Column '{column_name}' does not exist in {schema}.{table}"}), 404

        where_clauses: List[str] = []
        params: List[Any] = []
        
        for key, value in request.args.items():
            if key.startswith('filter_') and key != f'filter_{column_name}' and value:
                col_to_filter = key[len('filter_'):]
                
                if col_to_filter not in column_types:
                    continue 

                col_type = column_types[col_to_filter]
                
                if col_to_filter == 'planned_collection_date' and len(value) == 4 and value.isdigit():
                    try:
                        year = int(value)
                        start_date = date(year, 1, 1)
                        end_date = date(year + 1, 1, 1)
                        where_clauses.append(f'"{col_to_filter}" >= %s AND "{col_to_filter}" < %s')
                        params.extend([start_date, end_date])
                    except ValueError:
                        pass
                
                elif col_to_filter.endswith('_id') or col_to_filter == 'project_id' or col_type in ['integer', 'bigint', 'date']:
                    where_clauses.append(f'"{col_to_filter}" = %s')
                    params.append(value)
                
                elif col_type in ['text', 'character varying']:
                    where_clauses.append(f'"{col_to_filter}" ILIKE %s')
                    params.append(f'%{value}%')


        query_template = sql.SQL('SELECT DISTINCT {} FROM {}.{}')
        
        if where_clauses:
            query_template = sql.SQL('SELECT DISTINCT {} FROM {}.{} WHERE {}')

        query = query_template.format(
            sql.Identifier(column_name),
            sql.Identifier(actual_schema),
            sql.Identifier(actual_table),
            sql.SQL(' AND ').join(map(sql.SQL, where_clauses)) if where_clauses else sql.SQL('')
        )
        
        with conn.cursor() as cur:
            cur.execute(query, params)
            distinct_values = [row[0] for row in cur.fetchall() if row[0] is not None]
        
        return jsonify(distinct_values), 200
        
    except Exception as e:
        print(f"Error fetching distinct values for {schema}.{table}.{column_name}: {e}")
        return jsonify({"error": str(e)}), 500


# --- CRUD Routes (General) ---

@app.route(f'{API_PREFIX}/table/<string:schema>/<string:table>', methods=['GET'])
def get_table_data(schema: str, table: str):
    """Fetches data from a specified table or view, with optional filters, ordering, and pagination."""
    # NOTE: Implementation remains the same as previous file versions.
    conn = g.db_conn
    try:
        resolved = _resolve_table_casing(conn, schema, table)
        if not resolved: return jsonify({"error": f"Table or view '{schema}.{table}' not found or inaccessible."}), 404
        
        actual_schema, actual_table, table_type = resolved
        where_clauses: List[str] = []
        params: List[Any] = []
        
        filter_project_id_value = request.args.get('filter_project_id')
        filter_experiment_id_value = request.args.get('filter_experiment_id')
        filter_experiment_date_value = request.args.get('filter_experiment_date')
        filter_sample_id_value = request.args.get('filter_sample_id')
        filter_sample_creation_date_value = request.args.get('filter_sample_creation_date')
        filter_sampling_id_value = request.args.get('filter_sampling_id')
        filter_sampling_date_value = request.args.get('filter_sampling_date')
        filter_protocol_id_value = request.args.get('filter_protocol_id')
        exclude_status_id_value = request.args.get('exclude_status_id')
        filter_status_id_value = request.args.get('filter_status_id')
        filter_planned_collection_date_ge_value = request.args.get('filter_planned_collection_date_ge')
        filter_start_time_start_value = request.args.get('filter_start_time_start')
        filter_end_time_end_value = request.args.get('filter_end_time_end')
        
        column_types = _get_column_types(conn, actual_schema, actual_table)

        base_query_select = f'SELECT "{actual_table}".*'
        base_query_from = f'FROM "{actual_schema}"."{actual_table}"'
        
        def parse_date_filter(date_str): return safe_date_parse(date_str)
        def parse_datetime_filter(dt_str):
            try: return datetime.strptime(dt_str, '%Y-%m-%dT%H:%M')
            except (ValueError, TypeError):
                try: return datetime.fromisoformat(dt_str)
                except (ValueError, TypeError): return None

        if actual_table.lower() == 'booking':
            if filter_start_time_start_value:
                start_dt = parse_datetime_filter(filter_start_time_start_value)
                if start_dt:
                    where_clauses.append(f'"{actual_table}"."end_time" >= %s')
                    params.append(start_dt)
            if filter_end_time_end_value:
                end_dt = parse_datetime_filter(filter_end_time_end_value)
                if end_dt:
                    where_clauses.append(f'"{actual_table}"."start_time" < %s')
                    params.append(end_dt)

        if filter_planned_collection_date_ge_value and actual_table.lower() == 'reservation_samples':
            filter_date_obj = parse_date_filter(filter_planned_collection_date_ge_value)
            if filter_date_obj:
                where_clauses.append(f'"{actual_table}"."planned_collection_date" >= %s')
                params.append(filter_date_obj)

        if filter_experiment_id_value and filter_experiment_date_value:
            filter_exp_date_obj = parse_date_filter(filter_experiment_date_value)
            if 'experiment_id' in column_types and 'experiment_date' in column_types:
                where_clauses.append(f'"{actual_table}"."experiment_id" ILIKE %s')
                params.append(f'%{filter_experiment_id_value}%')
                where_clauses.append(f'"{actual_table}"."experiment_date" = %s')
                params.append(filter_exp_date_obj)

        if filter_sample_id_value:
            if 'sample_id' in column_types:
                where_clauses.append(f'"{actual_table}"."sample_id" ILIKE %s')
                params.append(f'%{filter_sample_id_value}%')
                if filter_sample_creation_date_value and 'sample_creation_date' in column_types:
                    filter_samp_create_date_obj = parse_date_filter(filter_sample_creation_date_value)
                    where_clauses.append(f'"{actual_table}"."sample_creation_date" = %s')
                    params.append(filter_samp_create_date_obj)

        if filter_sampling_id_value and filter_sampling_date_value:
            filter_samp_date_obj = parse_date_filter(filter_sampling_date_value)
            if 'sampling_id' in column_types and 'sampling_date' in column_types:
                where_clauses.append(f'"{actual_table}"."sampling_id" ILIKE %s')
                params.append(f'%{filter_sampling_id_value}%')
                where_clauses.append(f'"{actual_table}"."sampling_date" = %s')
                params.append(filter_samp_date_obj)

        if filter_project_id_value and 'project_id' in column_types:
            if column_types.get('project_id') in ['integer', 'bigint']:
                where_clauses.append(f'"{actual_table}"."project_id" = %s')
                params.append(filter_project_id_value)
            else:
                where_clauses.append(f'"{actual_table}"."project_id" ILIKE %s')
                params.append(f'%{filter_project_id_value}%')

        if 'filter_customer_id' in request.args:
            customer_id_value = request.args.get('filter_customer_id')
            if customer_id_value and 'customer_id' in column_types:
                where_clauses.append(f'"{actual_table}"."customer_id" = %s')
                params.append(customer_id_value) 

        if filter_protocol_id_value and 'protocol_id' in column_types:
            where_clauses.append(f'"{actual_table}"."protocol_id" = %s')
            params.append(filter_protocol_id_value)

        if exclude_status_id_value and 'status_id' in column_types:
            where_clauses.append(f'"{actual_table}"."status_id" != %s')
            params.append(exclude_status_id_value)
            
        if filter_status_id_value and 'status_id' in column_types:
            status_list = [s.strip() for s in filter_status_id_value.split(',') if s.strip()]
            if status_list:
                placeholders = ', '.join(['%s'] * len(status_list))
                where_clauses.append(f'"{actual_table}"."status_id" IN ({placeholders})')
                params.extend(status_list)

        order_by_column: Optional[str] = None
        order_direction: str = 'ASC'
        limit: Optional[int] = None
        offset: Optional[int] = None
        
        for key, value in request.args.items():
            if not value: continue
            
            if key in ['filter_project_id', 'filter_experiment_id', 'filter_experiment_date', 
                       'filter_sample_id', 'filter_sample_creation_date', 'filter_sampling_id',
                       'filter_sampling_date', 'filter_protocol_id', 'exclude_status_id', 
                       'filter_status_id', 'filter_planned_collection_date_ge', 
                       'filter_start_time_start', 'filter_end_time_end', 'filter_customer_id']:
                continue

            if key == 'limit': limit = int(value); continue
            elif key == 'offset': offset = int(value); continue
            elif key == 'order_by': order_by_column = value; continue
            elif key == 'order_direction':
                if value.upper() in ['ASC', 'DESC']: order_direction = value.upper()
                continue
            elif key == 'filter_expire_date_within_30_days' and value.lower() == 'true':
                if 'expire_date' in column_types: where_clauses.append(f'"expire_date" BETWEEN CURRENT_DATE AND CURRENT_DATE + interval \'30 day\'')
                continue

            if key.startswith('filter_') and not (key.endswith('_month') or key.endswith('_year')):
                col_name = key[len('filter_'):]
                if col_name in column_types:
                    if column_types.get(col_name) in ['text', 'character varying']:
                        where_clauses.append(f'"{col_name}" ILIKE %s')
                        params.append(f'%{value}%')
                    elif column_types.get(col_name) in ['integer', 'bigint', 'numeric']:
                        where_clauses.append(f'"{col_name}" = %s')
                        params.append(value)
                else:
                    print(f"Warning: Filter by non-existent or unfilterable column '{col_name}' skipped for {actual_schema}.{actual_table}.")
            else:
                if key in column_types:
                    where_clauses.append(f'"{key}" = %s')
                    params.append(value)


        query = f"{base_query_select} {base_query_from}"
        if where_clauses: query += f" WHERE {' AND '.join(where_clauses)}"
            
        if order_by_column:
            if order_by_column in column_types:
                quoted_order_by_column = f'"{actual_table}"."{order_by_column}"'
                query += f' ORDER BY {quoted_order_by_column} {order_direction}'
            else:
                print(f"Warning: Invalid order_by column '{order_by_column}' skipped.")
            
        if limit is not None:
            query += f" LIMIT %s"
            params.append(limit)
        if offset is not None:
            query += f" OFFSET %s"
            params.append(offset)

        query += ";"

        print(f"Executing GET query: {query} with params: {params}")
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute(query, params)
            data = cur.fetchall()
        
        processed_data = [transform_row_for_json(row) for row in data]
        
        return jsonify(processed_data), 200
    except Exception as e:
        print(f"Error fetching table data for {schema}.{table}: {e}")
        return jsonify({"error": str(e)}), 500
            
# --- CRUD Implementation (create_record, update_record, delete_record, batch_upload, batch_update) ---

def _parse_malformed_input(data: Dict[str, Any]) -> Dict[str, Any]:
    """Attempts to fix malformed single-key payloads."""
    # Logic for parsing malformed data
    try:
        if len(data) == 1 and isinstance(list(data.keys())[0], str) and ';' in list(data.keys())[0]:
            malformed_key = list(data.keys())[0]
            malformed_value = data[malformed_key]
            col_names = [k.strip() for k in malformed_key.split(';')]
            raw_col_values = malformed_value.split(';')
            col_names_filtered = [k.strip() for k in malformed_key.split(';')]
            if len(col_names_filtered) == len(raw_col_values) and len(col_names_filtered) > 1:
                new_data = {k: v for k, v in zip(col_names_filtered, raw_col_values) if k}
                return new_data
    except Exception:
        pass
    return data 

@app.route(f'{API_PREFIX}/table/<string:schema>/<string:table>', methods=['POST'])
def create_record(schema: str, table: str):
    """Creates a new record in the specified table. Handles file uploads and special linked records (e.g., projects and persons)."""
    conn = g.db_conn
    try:
        resolved = _resolve_table_casing(conn, schema, table)
        if not resolved:
            return jsonify({"error": f"Table '{schema}.{table}' not found or inaccessible."}), 404
        actual_schema, actual_table, table_type = resolved

        column_types = _get_column_types(conn, actual_schema, actual_table)

        data = {}
        files = request.files

        if request.is_json:
            data = request.get_json()
        elif request.form:
            data = request.form.to_dict()

        if not data and not files:
            return jsonify({"error": "No data provided"}), 400
        
        data = _parse_malformed_input(data)
            
        if 'attachment' in files and files['attachment'].filename != '':
            data['attachment'] = psycopg2.Binary(files['attachment'].read())
        elif 'attachment' in data and (data['attachment'] == '' or (isinstance(data['attachment'], dict) and not data['attachment'])):
            data['attachment'] = None
            
        if (actual_schema.lower() == 'lims' and actual_table.lower() in ['personal', 'customers', 'external_contacts']):
            data.pop('password', None)
            data.pop('password_hash', None)
            
        project_ids_str = None
        sample_ids_str = None
        linked_person_ids = None
        
        if actual_schema.lower() == 'lab' and actual_table.lower() == 'root_samples':
            if data.get('parent_sample_id') is None and data.get('project_id') is None and data.get('customer_id') is None:
                print("WARNING: Missing project_id/customer_id for new root sample. Using PROJ_FALLBACK.")
                data['project_id'] = 'Proj_BioMon'

        if actual_schema.lower() == 'lab' and actual_table.lower() == 'experiments':
            project_ids_str = data.pop('project_ids', None)
            sample_ids_str = data.pop('sample_ids', None)
        elif actual_schema.lower() == 'lims' and actual_table.lower() == 'projects':
            if 'linked_person_ids' in data:
                linked_person_ids_raw = data.pop('linked_person_ids', '')
                if isinstance(linked_person_ids_raw, str):
                    linked_person_ids = [p.strip() for p in linked_person_ids_raw.split(';') if p.strip()]
                elif isinstance(linked_person_ids_raw, list):
                    linked_person_ids = linked_person_ids_raw
                else:
                    linked_person_ids = []


        filtered_data = {}
        for k, v in data.items():
            if k == 'attachment':
                filtered_data[k] = v
            elif k == 'attachment_link' and v == '':
                filtered_data[k] = None
            elif v == '':
                filtered_data[k] = None
            elif k.endswith('_id') and (str(v).lower() == 'undefined' or str(v).lower() == 'null'):
                filtered_data[k] = None
            elif k.endswith('_id') and column_types.get(k) == 'integer' and v is not None:
                 try:
                     filtered_data[k] = int(v)
                 except ValueError:
                     filtered_data[k] = None
            elif column_types.get(k) == 'jsonb' and isinstance(v, str):
                try:
                    filtered_data[k] = json.loads(v)
                except json.JSONDecodeError:
                    print(f"WARNING: Invalid JSON for column '{k}'. Storing as None. Value: {v}")
                    filtered_data[k] = None
            elif column_types.get(k) == 'boolean':
                filtered_data[k] = str(v).lower() in ['true', 'on']
            elif column_types.get(k) == 'date' and isinstance(v, str) and v:
                filtered_data[k] = safe_date_parse(v) 
                if filtered_data[k] is None and v is not None:
                     print(f"WARNING: Invalid date format for column '{k}'. Storing as None. Value: {v}")
            elif column_types.get(k) == 'geometry' and isinstance(v, str) and v:
                 if v.upper().startswith('POINT(') and v.upper().endswith(')'):
                     filtered_data[k] = v
                 else:
                     try:
                         json.loads(v)
                         filtered_data[k] = v
                     except json.JSONDecodeError:
                         filtered_data[k] = None
            else:
                filtered_data[k] = v
            
        columns = [col for col in filtered_data.keys() if filtered_data.get(col) is not None]
        values = [filtered_data[col] for col in columns]
        
        col_identifiers = [sql.Identifier(col) for col in columns]

        insert_query = sql.SQL('INSERT INTO {schema}.{table} ({cols}) VALUES ({values}) RETURNING *').format(
            schema=sql.Identifier(actual_schema),
            table=sql.Identifier(actual_table),
            cols=sql.SQL(', ').join(col_identifiers),
            values=sql.SQL(', ').join([sql.Placeholder()] * len(values))
        )
        
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            print(f"Executing POST query (SQL): {insert_query.as_string(conn)} with values: {values}")
            cur.execute(insert_query, values)
            new_record = cur.fetchone()
            
            if actual_schema.lower() == 'lab' and actual_table.lower() == 'experiments' and new_record:
                experiment_id = new_record['experiment_id']
                experiment_date = new_record['experiment_date'] 
                
                if project_ids_str:
                    project_list = [p.strip() for p in project_ids_str.split(';') if p.strip()]
                    for project_id in project_list:
                        try:
                            cur.execute('INSERT INTO "lab"."experiments_projects" ("experiment_id", "experiment_date", "project_id") VALUES (%s, %s, %s);', (experiment_id, experiment_date, project_id))
                        except Exception as e:
                            print(f"  Warning: Could not link project {project_id} to experiment {experiment_id}: {e}")

                if sample_ids_str:
                    sample_list = [s.strip() for s in sample_ids_str.split(';') if s.strip()]
                    for sample_id in sample_list:
                        try:
                            cur.execute('SELECT "sample_creation_date" FROM "lab"."root_samples" WHERE "sample_id" = %s;', (sample_id,))
                            sample_creation_row = cur.fetchone()
                            if sample_creation_row is None:
                                print(f"  Warning: Root sample ID {sample_id} not found. Skipping link.")
                                continue
                            sample_creation_date = sample_creation_row['sample_creation_date'] 
                            cur.execute('INSERT INTO "lab"."experiments_samples" ("experiment_id", "experiment_date", "sample_id", "sample_creation_date") VALUES (%s, %s, %s, %s);', (experiment_id, experiment_date, sample_id, sample_creation_date))
                        except Exception as e:
                            print(f"  Warning: Could not link sample {sample_id} to experiment {experiment_id}: {e}")
            
            elif actual_schema.lower() == 'lims' and actual_table.lower() == 'projects' and new_record and linked_person_ids:
                project_id = new_record['project_id']
                for person_id in linked_person_ids:
                    try:
                        cur.execute('INSERT INTO "lims"."project_persons" ("project_id", "person_id", "link_date") VALUES (%s, %s, %s);', (project_id, person_id, date.today()))
                        print(f"  Linked person {person_id} to new project {project_id}")
                    except Exception as e:
                        print(f"  Warning: Could not link person {person_id} to new project {project_id}: {e}")
            
            conn.commit()
        return jsonify(transform_row_for_json(new_record)), 201
    except Exception as e:    
        if conn:
            conn.rollback()
        import traceback
        print(f"Error creating record in {schema}.{table}: {e}")
        print(traceback.format_exc())
        return jsonify({"error": str(e)}), 500


@app.route(f'{API_PREFIX}/table/<string:schema>/<string:table>', methods=['PUT'])
def update_record(schema: str, table: str):
    """Updates an existing record in the specified table identified by its primary key(s)."""
    conn = g.db_conn
    try:
        resolved = _resolve_table_casing(conn, schema, table)
        if not resolved:
            return jsonify({"error": f"Table '{schema}.{table}' not found or inaccessible."}), 404
        actual_schema, actual_table, table_type = resolved

        pk_columns = get_pk_columns(schema, table)
        column_types = _get_column_types(conn, actual_schema, actual_table)

        pk_values_from_request = {}
        for pk_col in pk_columns:
            pk_val = request.args.get(pk_col)
            if pk_val is None:
                return jsonify({"error": f"Missing primary key component: {pk_col}"}), 400
            
            if column_types.get(pk_col) == 'date':
                pk_values_from_request[pk_col] = safe_date_parse(pk_val) 
                if pk_values_from_request[pk_col] is None and pk_val is not None:
                    pk_values_from_request[pk_col] = pk_val
            else:
                pk_values_from_request[pk_col] = pk_val

        data = {}
        files = request.files

        if request.is_json:
            data = request.get_json()
        elif request.form:
            data = request.form.to_dict()

        if not data and not files:
            return jsonify({"error": "No data provided"}), 400

        if 'attachment' in files and files['attachment'].filename != '':
            data['attachment'] = psycopg2.Binary(files['attachment'].read())
        elif 'attachment' in data and (data['attachment'] == '' or (isinstance(data['attachment'], dict) and not data['attachment'])):
            data['attachment'] = None

        set_clauses: List[str] = []
        values: List[Any] = []
        
        if (actual_schema.lower() == 'lims' and actual_table.lower() in ['personal', 'customers', 'external_contacts']):
            data.pop('password', None)
            data.pop('password_hash', None)
            
        for key, val in data.items():
            if key in pk_columns or key in ['project_ids', 'sample_ids', 'linked_person_ids']:
                continue
            
            if isinstance(val, str) and val == '':
                if key != 'attachment_link':
                    continue
            
            elif key == 'attachment_link' and val == '':
                set_clauses.append(f'"{key}" = %s')
                values.append(None)
            elif key == 'attachment':
                 if isinstance(val, str) and val.startswith('data:'):
                    try:
                        base64_data = val.split(',')[1]
                        set_clauses.append(f'"{key}" = %s')
                        values.append(psycopg2.Binary(base64.b64decode(base64_data)))
                    except Exception as e:
                        print(f"WARNING: Could not decode base64 attachment for column '{key}'. Storing as None. Error: {e}")
                        set_clauses.append(f'"{key}" = %s')
                        values.append(None)
                 else:
                    set_clauses.append(f'"{key}" = %s')
                    values.append(None if val == '' else val)
            elif column_types.get(key) == 'jsonb' and isinstance(val, str):
                try:
                    set_clauses.append(f'"{key}" = %s')
                    values.append(json.loads(val))
                except json.JSONDecodeError:
                    print(f"WARNING: Invalid JSON for column '{key}'. Storing as None. Value: {val}")
                    set_clauses.append(f'"{key}" = %s')
                    values.append(None)
            elif column_types.get(key) == 'boolean':
                set_clauses.append(f'"{key}" = %s')
                values.append(str(val).lower() in ['true', 'on'])
            elif column_types.get(key) == 'date' and isinstance(val, str) and val:
                date_obj = safe_date_parse(val) 
                if date_obj is not None:
                    set_clauses.append(f'"{key}" = %s')
                    values.append(date_obj)
                else:
                    print(f"WARNING: Invalid date format for column '{key}'. Skipping update for this field. Value: {val}")
                    continue
            elif column_types.get(key) == 'timestamp with time zone' and isinstance(val, str) and val:
                try:
                    set_clauses.append(f'"{key}" = %s')
                    values.append(datetime.strptime(val, '%Y-%m-%dT%H:%M'))
                except ValueError:
                    print(f"WARNING: Invalid datetime format for column '{key}'. Skipping update for this field.")
                    continue
            else:
                set_clauses.append(f'"{key}" = %s')
                values.append(None if val == '' else val)
            
        if not set_clauses:
            return jsonify({"error": "No fields to update"}), 400

        pk_where_clauses = []
        pk_where_values: List[Any] = [] 
        for pk_col in pk_columns:
            pk_where_clauses.append(f'"{pk_col}" = %s')
            pk_val = pk_values_from_request[pk_col]
            if column_types.get(pk_col) == 'date' and pk_val is not None:
                if isinstance(pk_val, str):
                    pk_where_values.append(safe_date_parse(pk_val))
                else:
                    pk_where_values.append(pk_val)
            else:
                pk_where_values.append(pk_val)
        
        all_values = values + pk_where_values
        
        query = f'UPDATE "{actual_schema}"."{actual_table}" SET {", ".join(set_clauses)} WHERE {" AND ".join(pk_where_clauses)} RETURNING *;'
        
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            print(f"Executing PUT query: {query} with values: {all_values}")
            cur.execute(query, all_values)
            updated_record = cur.fetchone()
            conn.commit()
        if updated_record:
            return jsonify(transform_row_for_json(updated_record)), 200
        else:
            return jsonify({"error": "Record not found or no changes made."}), 404
    except Exception as e:    
        if conn:
            conn.rollback()
        print(f"Error updating record in {schema}.{table}: {e}")
        return jsonify({"error": str(e)}), 500


@app.route(f'{API_PREFIX}/table/<string:schema>/<string:table>', methods=['DELETE'])
def delete_record(schema: str, table: str):
    """Deletes a record from the specified table using its primary key(s) or filters."""
    conn = g.db_conn
    try:
        resolved = _resolve_table_casing(conn, schema, table)
        if not resolved:
            return jsonify({"error": f"Table '{schema}.{table}' not found or inaccessible."}), 404
        actual_schema, actual_table, table_type = resolved

        pk_columns = get_pk_columns(schema, table)
        column_types = _get_column_types(conn, actual_schema, actual_table)

        pk_values_for_query = []
        where_clauses = []
        
        mass_delete_params = {k: v for k, v in request.args.items() if k.startswith('filter_')}
        
        if mass_delete_params:
            for key, val in mass_delete_params.items():
                col_name = key[len('filter_'):]
                if col_name in column_types:
                    where_clauses.append(f'"{col_name}" = %s')
                    if column_types.get(col_name) == 'date':
                        pk_values_for_query.append(safe_date_parse(val)) 
                    else:
                        pk_values_for_query.append(val)
                else:
                    return jsonify({"error": f"Invalid filter column for deletion: {col_name}"}), 400
            
            if not where_clauses:
                 return jsonify({"error": "No valid filter criteria provided for mass deletion."}), 400

        else: # Standard PK-based single deletion
            for pk_col in pk_columns:
                pk_val = request.args.get(pk_col)
                if pk_val is None:
                    return jsonify({"error": f"Missing primary key component for deletion: {pk_col}"}), 400
                
                if column_types.get(pk_col) == 'date' and pk_val is not None:
                    pk_val = safe_date_parse(pk_val) 

                where_clauses.append(f'"{pk_col}" = %s')
                pk_values_for_query.append(pk_val)

        query = f'DELETE FROM "{actual_schema}"."{actual_table}" WHERE {" AND ".join(where_clauses)} RETURNING *;'
        
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            print(f"Executing DELETE query: {query} with params: {pk_values_for_query}")
            cur.execute(query, pk_values_for_query)
            
            if mass_delete_params:
                deleted_count = cur.rowcount
                conn.commit()
                return jsonify({"success": True, "message": f"Successfully deleted {deleted_count} records.", "deleted_count": deleted_count}), 200
            
            deleted_record = cur.fetchone()
            conn.commit()
        
        if deleted_record:
            return jsonify({"success": True, "message": "Record deleted successfully."}), 200
        else:
            return jsonify({"error": "Record not found or could not be deleted."}), 404
    except Exception as e:
        if conn:
            conn.rollback()
        print(f"Error deleting record from {schema}.{table}: {e}")
        return jsonify({"error": str(e)}), 500

@app.route(f'{API_PREFIX}/table/<string:schema>/<string:table>/batch_upload', methods=['POST'])
def batch_upload(schema: str, table: str):
    """Handles bulk insertion of records from a list of dictionaries (e.g., from CSV/JSON upload)."""
    conn = g.db_conn
    try:
        resolved = _resolve_table_casing(conn, schema, table)
        if not resolved:
            return jsonify({"error": f"Table '{schema}.{table}' not found or inaccessible."}), 404
        actual_schema, actual_table, table_type = resolved

        column_types = _get_column_types(conn, actual_schema, actual_table)

        records = request.get_json()
        if not records or not isinstance(records, list):
            return jsonify({"error": "Invalid data format. Expected a list of records."}), 400
            
        if not records:
            return jsonify({"success": True, "inserted_rows": 0}), 200

        inserted_count = 0
        
        if (actual_schema.lower() == 'lab' and actual_table.lower() == 'experiments') or \
           (actual_schema.lower() == 'lims' and actual_table.lower() == 'projects'):
            
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
                for record_data in records:
                    project_ids_str = record_data.pop('project_ids', None)
                    sample_ids_str = record_data.pop('sample_ids', None)
                    linked_person_ids_str = record_data.pop('linked_person_ids', None)

                    filtered_record = {}
                    for k, v in record_data.items():
                        if v == '':
                            filtered_record[k] = None
                        elif column_types.get(k) == 'jsonb' and isinstance(v, str):
                            try:
                                filtered_record[k] = json.loads(v)
                            except json.JSONDecodeError:
                                filtered_record[k] = None
                        elif column_types.get(k) == 'boolean':
                            filtered_record[k] = str(v).lower() in ['true', 'on']
                        elif column_types.get(k) == 'date' and isinstance(v, str) and v:
                            filtered_record[k] = safe_date_parse(v)
                            if filtered_record[k] is None and v is not None:
                                print(f"WARNING: Invalid date format for column '{k}' in batch. Storing as None. Value: {v}")
                        elif k == 'attachment' and isinstance(v, str) and (v.startswith('data:')):
                            try:
                                base64_data = v.split(',')[1]
                                filtered_record[k] = psycopg2.Binary(base64.b64decode(base64_data))
                            except Exception as e:
                                print(f"WARNING: Could not decode base64 attachment for column '{k}' in batch. Storing as None. Error: {e}")
                                filtered_record[k] = None
                        elif column_types.get(k) in ['integer', 'bigint', 'numeric'] and v is not None:
                             try:
                                 filtered_record[k] = float(v) if column_types.get(k) == 'numeric' else int(v)
                             except ValueError:
                                 filtered_record[k] = None
                        else:
                            filtered_record[k] = v

                    if (actual_schema.lower() == 'lims' and actual_table.lower() in ['personal', 'customers', 'external_contacts']):
                        filtered_record.pop('password', None)
                        filtered_record.pop('password_hash', None)
                            
                    columns = filtered_record.keys()
                    values = [filtered_record[col] for col in columns]

                    col_identifiers = [sql.Identifier(col) for col in columns]
                    insert_query = sql.SQL('INSERT INTO {schema}.{table} ({cols}) VALUES ({values}) RETURNING *').format(
                        schema=sql.Identifier(actual_schema),
                        table=sql.Identifier(actual_table),
                        cols=sql.SQL(', ').join(col_identifiers),
                        values=sql.SQL(', ').join([sql.Placeholder()] * len(values))
                    )
                    
                    try:
                        cur.execute(insert_query, values)
                        new_record = cur.fetchone()
                        if new_record:
                            inserted_count += 1
                            
                            if actual_table.lower() == 'experiments':
                                experiment_id = new_record['experiment_id']
                                experiment_date = new_record['experiment_date'] 

                                if project_ids_str:
                                    project_list = [p.strip() for p in project_ids_str.split(';') if p.strip()]
                                    for project_id in project_list:
                                        cur.execute('INSERT INTO "lab"."experiments_projects" ("experiment_id", "experiment_date", "project_id") VALUES (%s, %s, %s);', (experiment_id, experiment_date, project_id))

                                if sample_ids_str:
                                    sample_list = [s.strip() for s in sample_ids_str.split(';') if s.strip()]
                                    for sample_id in sample_list:
                                        cur.execute('SELECT "sample_creation_date" FROM "lab"."root_samples" WHERE "sample_id" = %s;', (sample_id,))
                                        sample_creation_row = cur.fetchone()
                                        if sample_creation_row is None:
                                            print(f"  Warning: Root sample ID {sample_id} not found during batch link. Skipping link.")
                                            continue
                                            
                                        sample_creation_date = sample_creation_row['sample_creation_date'] 
                                        cur.execute('INSERT INTO "lab"."experiments_samples" ("experiment_id", "experiment_date", "sample_id", "sample_creation_date") VALUES (%s, %s, %s, %s);', (experiment_id, experiment_date, sample_id, sample_creation_date))

                            elif actual_table.lower() == 'projects' and linked_person_ids_str:
                                project_id = new_record['project_id']
                                person_list = [p.strip() for p in linked_person_ids_str.split(';') if p.strip()]
                                for person_id in person_list:
                                    cur.execute('INSERT INTO "lims"."project_persons" ("project_id", "person_id", "link_date") VALUES (%s, %s, %s);', (project_id, person_id, date.today()))

                    except Exception as e:
                        print(f"Error inserting individual record in batch for {actual_schema}.{actual_table}: {e}")
                conn.commit()
        
        else:
            if records and isinstance(records, list) and len(records) > 0:
                first_record = records[0]
                if len(first_record) == 1 and isinstance(list(first_record.keys())[0], str) and ';' in list(first_record.keys())[0]:
                    print("CRITICAL: Batch upload detected malformed single-key JSON structure. Reformatting the entire batch.")
                    malformed_key = list(first_record.keys())[0]
                    headers = [k.strip() for k in malformed_key.split(';') if k.strip()]
                    new_records = []
                    for record in records:
                        if len(record) == 1 and list(record.keys())[0] == malformed_key:
                            values = record[malformed_key].split(';')
                            if len(headers) == len(values):
                                new_record = dict(zip(headers, values))
                                new_record = {k: v for k, v in new_record.items() if k}
                                new_records.append(new_record)
                            else:
                                print(f"WARNING: Skipping batch record due to header/value mismatch after parsing: {record}")
                        else:
                            new_records.append(record) 

                    records = new_records
                    if not records:
                        print("ERROR: All batch records failed manual parsing.")
                        return jsonify({"success": False, "error": "Batch processing failed: malformed data could not be parsed."}), 500

            first_record_keys = list(records[0].keys())
            processed_records_for_insertion = []

            for record in records:
                temp_record = record.copy()
                
                for k, v in temp_record.items():
                    if v == '':
                        temp_record[k] = None
                        continue

                    col_type = column_types.get(k)
                    if col_type == 'jsonb' and isinstance(v, str):
                        try:
                            temp_record[k] = json.loads(v)
                        except json.JSONDecodeError:
                            temp_record[k] = None
                    elif col_type == 'boolean':
                        temp_record[k] = str(v).lower() in ['true', 'on']
                    elif col_type == 'date':
                        temp_record[k] = safe_date_parse(v)
                    elif col_type in ['integer', 'bigint', 'numeric']:
                         try:
                             temp_record[k] = float(v) if col_type == 'numeric' else int(v)
                         except ValueError:
                             temp_record[k] = None
                    elif k == 'attachment' and isinstance(v, str) and v.startswith('data:'):
                        try:
                            base64_data = v.split(',')[1]
                            temp_record[k] = psycopg2.Binary(base64.b64decode(base64_data))
                        except Exception:
                            temp_record[k] = None
                    else:
                        temp_record[k] = v

                processed_records_for_insertion.append(temp_record)

            columns = list(processed_records_for_insertion[0].keys())
            column_names = ', '.join([f'"{col}"' for col in columns])
            
            data_tuples: List[Tuple[Any, ...]] = []
            for record_data in processed_records_for_insertion:
                row = []
                for col in columns:
                    row.append(record_data.get(col))
                data_tuples.append(tuple(row))

            query_template = f"INSERT INTO \"{actual_schema}\".\"{actual_table}\" ({column_names}) VALUES %s"
            
            with conn.cursor() as cur:
                print(f"Executing batch_upload query: {query_template} with {len(data_tuples)} records.")
                psycopg2.extras.execute_values(cur, query_template, data_tuples)
                conn.commit()
            inserted_count = len(records)
            
        return jsonify({"success": True, "inserted_rows": inserted_count}), 201
    except Exception as e:    
        if conn:
            conn.rollback()
        print(f"Error during batch upload for {schema}.{table}: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@app.route(f'{API_PREFIX}/table/<string:schema>/<string:table>/batch_update', methods=['PUT'])
def batch_update(schema: str, table: str):
    """Performs a bulk update of records."""
    conn = g.db_conn
    try:
        resolved = _resolve_table_casing(conn, schema, table)
        if not resolved:
            return jsonify({"error": f"Table '{schema}.{table}' not found or inaccessible."}), 404
        actual_schema, actual_table, table_type = resolved

        pk_columns = get_pk_columns(schema, table)
        if not pk_columns:
            return jsonify({"error": f"Primary key not defined for {schema}.{table}. Cannot perform batch update."}), 400

        column_types = _get_column_types(conn, actual_schema, actual_table)

        records_to_update = request.get_json()
        if not records_to_update or not isinstance(records_to_update, list):
            return jsonify({"error": "Invalid data format. Expected a list of records for batch update."}), 400

        if records_to_update and isinstance(records_to_update, list) and len(records_to_update) > 0:
            first_record = records_to_update[0]
            if len(first_record) == 1 and isinstance(list(first_record.keys())[0], str) and ';' in list(first_record.keys())[0]:
                print("CRITICAL: Batch UPDATE detected malformed single-key JSON structure. Reformatting the entire batch.")
                malformed_key = list(first_record.keys())[0]
                headers = [k.strip() for k in malformed_key.split(';') if k.strip()]
                new_records = []
                for record in records_to_update:
                    if len(record) == 1 and list(record.keys())[0] == malformed_key:
                        values = record[malformed_key].split(';')
                        if len(headers) == len(values):
                            new_record = {k: v for k, v in zip(headers, values) if k}
                            new_records.append(new_record)
                    else:
                        new_records.append(record) 
                
                records_to_update = new_records
                if not records_to_update:
                    print("ERROR: All batch update records failed manual parsing.")
                    return jsonify({"success": False, "error": "Batch update failed: malformed data could not be parsed."}), 500


        updated_count = 0
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            for record_data in records_to_update:
                set_clauses_parts: List[str] = []
                set_values: List[Any] = []
                pk_where_clauses_parts: List[str] = []
                pk_where_values: List[Any] = []

                update_fields = {k: v for k, v in record_data.items() if k not in pk_columns}
                pk_fields = {k: v for k, v in record_data.items() if k in pk_columns}

                if not all(pk_col in pk_fields for pk_col in pk_columns):
                    print(f"  Warning: Skipping record in batch update due to missing primary key(s): {pk_fields} in {record_data}")
                    continue
                
                if (actual_schema.lower() == 'lims' and actual_table.lower() in ['personal', 'customers', 'external_contacts']):
                    update_fields.pop('password', None)
                    update_fields.pop('password_hash', None)

                for key, val in update_fields.items():
                    if isinstance(val, str) and val == '':
                        if key != 'attachment_link':
                            continue
                    
                    if key == 'attachment_link' and val == '':
                        set_clauses_parts.append(f'"{key}" = %s')
                        set_values.append(None)
                    elif key == 'attachment':
                         if isinstance(val, str) and val.startswith('data:'):
                            try:
                                base64_data = val.split(',')[1]
                                set_clauses_parts.append(f'"{key}" = %s')
                                set_values.append(psycopg2.Binary(base64.b64decode(base64_data)))
                            except Exception as e:
                                print(f"WARNING: Could not decode base64 attachment for column '{key}'. Storing as None. Error: {e}")
                                set_clauses_parts.append(f'"{key}" = %s')
                                set_values.append(None)
                         else:
                            set_clauses_parts.append(f'"{key}" = %s')
                            set_values.append(None if val == '' else val)
                    elif column_types.get(key) == 'jsonb' and isinstance(val, str):
                        try:
                            set_clauses_parts.append(f'"{key}" = %s')
                            set_values.append(json.loads(val))
                        except json.JSONDecodeError:
                            set_clauses_parts.append(f'"{key}" = %s')
                            set_values.append(None)
                    elif column_types.get(key) == 'boolean':
                        set_clauses_parts.append(f'"{key}" = %s')
                        set_values.append(str(val).lower() in ['true', 'on'])
                    elif column_types.get(key) == 'date' and isinstance(val, str) and val:
                        date_obj = safe_date_parse(val) 
                        if date_obj is not None:
                            set_clauses_parts.append(f'"{key}" = %s')
                            set_values.append(date_obj)
                        else:
                            continue
                    elif column_types.get(key) in ['integer', 'bigint', 'numeric'] and val is not None:
                         try:
                             set_clauses_parts.append(f'"{key}" = %s')
                             set_values.append(float(val) if column_types.get(key) == 'numeric' else int(val))
                         except ValueError:
                             set_clauses_parts.append(f'"{key}" = %s')
                             set_values.append(None)
                    else:
                        set_clauses_parts.append(f'"{key}" = %s')
                        set_values.append(None if val == '' else val)
                
                if not set_clauses_parts:
                    print(f"  Warning: Skipping record in batch update as no update fields provided: {record_data}")
                    continue

                for pk_col in pk_columns:
                    pk_where_clauses_parts.append(f'"{pk_col}" = %s')
                    pk_val = pk_fields[pk_col]
                    
                    if column_types.get(pk_col) == 'date' and pk_val is not None:
                        if isinstance(pk_val, str):
                            pk_where_values.append(safe_date_parse(pk_val))
                        else:
                            pk_where_values.append(pk_val)
                    else:
                        pk_where_values.append(pk_val)
                
                all_values = set_values + pk_where_values
                
                update_query = f'UPDATE "{actual_schema}"."{actual_table}" SET {", ".join(set_clauses_parts)} WHERE {" AND ".join(pk_where_clauses_parts)} RETURNING *;'
                
                try:
                    cur.execute(update_query, all_values)
                    if cur.fetchone():
                        updated_count += 1
                    else:
                        print(f"  Warning: Record not found for update in batch: {record_data}")
                except Exception as e:
                    print(f"  Error updating record in batch for {actual_schema}.{actual_table} (PK: {pk_fields}): {e}")
            conn.commit()
            return jsonify({"success": True, "updated_rows": updated_count}), 200

    except Exception as e:
        if conn:
            conn.rollback()
        print(f"Error during batch update for {schema}.{table}: {e}")
        return jsonify({"success": False, "error": str(e)}), 500
