import os
import json
import asyncpg
import uvicorn
import jwt
import bcrypt
import logging
import shutil
from contextlib import asynccontextmanager
from datetime import datetime, timedelta, date
from typing import List, Optional, Dict, Any
from fastapi import FastAPI, HTTPException, Depends, Request, UploadFile, File, Query
from fastapi.security import OAuth2PasswordBearer
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

# ==============================================================================
# 1. CONFIGURATION & LOGGING
# ==============================================================================

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("uvicorn.error")

DB_CONFIG = {
    "dsn": "postgresql://kasmi:password@127.0.0.1/migfish_demo",
    "min_size": 1,
    "max_size": 20
}

AUTH_DB_CONFIG = {
    "dsn": "postgresql://auth_user:auth_password@127.0.0.1/musr",
    "min_size": 1,
    "max_size": 5
}

SECRET_KEY = "super-secret-key-change-this-in-production"
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 480 
UPLOAD_DIR = "upload"

# ==============================================================================
# 2. LIFESPAN MANAGER
# ==============================================================================

@asynccontextmanager
async def lifespan(app: FastAPI):
    try:
        logger.info("Initializing Database Pools...")
        app.state.db_pool = await asyncpg.create_pool(**DB_CONFIG)
        app.state.auth_pool = await asyncpg.create_pool(**AUTH_DB_CONFIG)
        
        # Ensure upload directory exists
        os.makedirs(UPLOAD_DIR, exist_ok=True)
        
        logger.info("Database Pools & Resources Ready.")
    except Exception as e:
        logger.error(f"CRITICAL: Failed to connect to database on startup: {e}")
    yield
    logger.info("Closing Database Pools...")
    if hasattr(app.state, 'db_pool') and app.state.db_pool:
        await app.state.db_pool.close()
    if hasattr(app.state, 'auth_pool') and app.state.auth_pool:
        await app.state.auth_pool.close()

app = FastAPI(title="TIFI LIMS (FastAPI)", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/auth/login")

# ==============================================================================
# 3. DATA MODELS & UTILS
# ==============================================================================

class LoginRequest(BaseModel):
    username: str
    password: str

class Token(BaseModel):
    access_token: str
    token_type: str
    user_info: dict

async def get_db_pool(request: Request):
    if not hasattr(request.app.state, 'db_pool') or not request.app.state.db_pool:
        try: request.app.state.db_pool = await asyncpg.create_pool(**DB_CONFIG)
        except Exception as e: raise HTTPException(500, f"LIMS DB Down: {e}")
    return request.app.state.db_pool

async def get_auth_pool(request: Request):
    if not hasattr(request.app.state, 'auth_pool') or not request.app.state.auth_pool:
        try: request.app.state.auth_pool = await asyncpg.create_pool(**AUTH_DB_CONFIG)
        except Exception as e: raise HTTPException(500, f"Auth DB Down: {e}")
    return request.app.state.auth_pool

def serialize_row(row):
    item = dict(row)
    for k, v in item.items():
        if isinstance(v, (date, datetime)):
            item[k] = v.isoformat()
        if isinstance(v, bytes):
            try: item[k] = v.decode('utf-8')
            except: item[k] = "<binary data>"
    return item

def parse_value_by_type(val, dtype):
    if val is None: return None
    if isinstance(val, str):
        val = val.strip()
        if val == "": return None
        if dtype == 'date':
            try: return date.fromisoformat(val)
            except: pass
        elif 'timestamp' in dtype:
            try: return datetime.fromisoformat(val.replace('Z', '+00:00'))
            except: pass
        elif dtype in ('integer', 'smallint', 'bigint'):
            try: return int(val)
            except: pass
        elif dtype in ('numeric', 'real', 'double precision'):
            try: return float(val.replace(',', '.'))
            except: pass
        elif dtype == 'boolean':
            if val.lower() in ('true', '1', 't', 'yes'): return True
            if val.lower() in ('false', '0', 'f', 'no'): return False
    return val

def create_access_token(data: dict):
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

async def get_current_user(token: str = Depends(oauth2_scheme)):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: str = payload.get("sub")
        if not user_id: raise HTTPException(401, "Invalid token")
        return {"user_id": user_id, "claims": payload}
    except Exception:
        raise HTTPException(401, "Invalid token")

# ==============================================================================
# 4. API ROUTES
# ==============================================================================

# --- AUTHENTICATION ---

@app.post("/api/login", response_model=Token)
@app.post("/api/auth/login", response_model=Token) 
async def login(creds: LoginRequest, request: Request):
    # Admin Bypass
    if creds.username == 'kasmi' and creds.password == 'password':
        token = create_access_token(data={"sub": "kasmi", "role": "admin"})
        return {"access_token": token, "token_type": "bearer", "user_info": {"person_id": "kasmi", "role": "admin"}}

    try:
        auth_pool = await get_auth_pool(request)
        async with auth_pool.acquire() as conn:
            row = await conn.fetchrow("SELECT pswd_hash FROM aaa.lg_fi WHERE login = $1", creds.username)
    except Exception as e:
        raise HTTPException(500, f"Auth DB Error: {e}")

    if not row: raise HTTPException(401, "User not found")
    
    try:
        stored_hash = row['pswd_hash']
        password_bytes = creds.password.encode('utf-8')
        if isinstance(stored_hash, str): hash_bytes = stored_hash.encode('utf-8')
        else: hash_bytes = stored_hash

        if not bcrypt.checkpw(password_bytes, hash_bytes):
            raise HTTPException(401, "Invalid password")
    except HTTPException: raise
    except Exception: raise HTTPException(500, "Auth Logic Error")
        
    token = create_access_token(data={"sub": creds.username, "role": "user"})
    return {"access_token": token, "token_type": "bearer", "user_info": {"person_id": creds.username}}

# --- FILE UPLOAD (New Feature) ---

@app.post("/api/upload")
async def upload_file(file: UploadFile = File(...), user: dict = Depends(get_current_user)):
    """Uploads a file and returns the relative URL. Useful for attachments."""
    try:
        file_location = os.path.join(UPLOAD_DIR, file.filename)
        # Avoid overwriting existing files by appending timestamp if needed (simple logic here)
        if os.path.exists(file_location):
            base, ext = os.path.splitext(file.filename)
            file_location = os.path.join(UPLOAD_DIR, f"{base}_{int(datetime.now().timestamp())}{ext}")
            
        with open(file_location, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
            
        # Return URL relative to server root
        return {"filename": os.path.basename(file_location), "url": f"/upload/{os.path.basename(file_location)}"}
    except Exception as e:
        raise HTTPException(500, f"File Upload Failed: {e}")

# --- DASHBOARD STATS (New Feature) ---

@app.get("/api/stats/count")
async def get_table_count(schema: str, table: str, db_pool = Depends(get_db_pool)):
    """Fast count of rows in a table."""
    if not schema.replace("_","").isalnum() or not table.replace("_","").isalnum():
        raise HTTPException(400, "Invalid name")
    
    async with db_pool.acquire() as conn:
        count = await conn.fetchval(f'SELECT COUNT(*) FROM "{schema}"."{table}"')
    return {"schema": schema, "table": table, "count": count}

@app.get("/api/stats/activity")
async def get_recent_activity(limit: int = 10, db_pool = Depends(get_db_pool)):
    """Fetches recent audit logs."""
    try:
        async with db_pool.acquire() as conn:
            # Assumes audit.audit_log structure from your SQL dump context
            rows = await conn.fetch(f"""
                SELECT action_tstamp_tx, action, table_name, logged_in_person_id
                FROM audit.audit_log
                ORDER BY action_tstamp_tx DESC
                LIMIT $1
            """, limit)
        return [serialize_row(row) for row in rows]
    except Exception as e:
        # Graceful fallback if audit table doesn't exist yet
        logger.warning(f"Audit log fetch failed: {e}")
        return []

# --- SCHEMA METADATA ---

@app.get("/api/table_names_for_forms")
async def list_all_tables(db_pool = Depends(get_db_pool)):
    async with db_pool.acquire() as conn:
        rows = await conn.fetch("""
            SELECT table_schema || '.' || table_name as full_name
            FROM information_schema.tables 
            WHERE table_schema IN ('core', 'lims', 'field', 'bio_assets', 'biologyfish', 'moleculargenetics', 'bioinformatics', 'eln')
            AND table_type = 'BASE TABLE'
            ORDER BY table_schema, table_name
        """)
    return [r['full_name'] for r in rows]

@app.get("/api/table/{schema}/{table}/schema")
async def get_table_meta(schema: str, table: str, db_pool = Depends(get_db_pool)):
    if not schema.replace("_","").isalnum() or not table.replace("_","").isalnum():
        raise HTTPException(400, "Invalid name")

    async with db_pool.acquire() as conn:
        # Basic Columns
        cols = await conn.fetch("""
            SELECT column_name, data_type, is_nullable
            FROM information_schema.columns 
            WHERE table_schema = $1 AND table_name = $2
            ORDER BY ordinal_position
        """, schema, table)
        
        # Primary Keys
        pk_rows = await conn.fetch("""
            SELECT a.attname
            FROM   pg_index i
            JOIN   pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY(i.indkey)
            WHERE  i.indrelid = (quote_ident($1) || '.' || quote_ident($2))::regclass
            AND    i.indisprimary;
        """, schema, table)
        pk_cols = [r['attname'] for r in pk_rows]

        # Foreign Keys
        fk_rows = await conn.fetch("""
            SELECT
                kcu.column_name,
                ccu.table_schema AS foreign_table_schema,
                ccu.table_name AS foreign_table_name,
                ccu.column_name AS foreign_column_name
            FROM
                information_schema.key_column_usage AS kcu
                JOIN information_schema.referential_constraints AS rc
                    ON kcu.constraint_name = rc.constraint_name
                JOIN information_schema.constraint_column_usage AS ccu
                    ON ccu.constraint_name = rc.constraint_name
            WHERE
                kcu.table_schema = $1 AND kcu.table_name = $2
        """, schema, table)
        
        fk_map = {r['column_name']: {'table': f"{r['foreign_table_schema']}.{r['foreign_table_name']}", 'col': r['foreign_column_name']} for r in fk_rows}
    
    return [
        {
            "column_name": c['column_name'], 
            "data_type": c['data_type'],
            "is_nullable": c['is_nullable'],
            "is_primary_key": c['column_name'] in pk_cols,
            "foreign_key": fk_map.get(c['column_name'])
        } 
        for c in cols
    ]

@app.get("/api/table/{schema}/{table}/distinct/{column}")
async def get_distinct_values(schema: str, table: str, column: str, db_pool = Depends(get_db_pool)):
    """Fetch unique values for a column. Useful for dropdowns."""
    if not schema.replace("_","").isalnum() or not table.replace("_","").isalnum() or not column.replace("_","").isalnum():
        raise HTTPException(400, "Invalid parameters")
        
    async with db_pool.acquire() as conn:
        exists = await conn.fetchval("""
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema=$1 AND table_name=$2 AND column_name=$3
        """, schema, table, column)
        if not exists: raise HTTPException(404, "Column not found")

        rows = await conn.fetch(f'SELECT DISTINCT "{column}" FROM "{schema}"."{table}" ORDER BY "{column}" LIMIT 500')
        
    return [r[column] for r in rows if r[column] is not None]

# --- DATA CRUD ---

@app.get("/api/table/{schema}/{table}")
async def get_table_data(
    schema: str, 
    table: str, 
    request: Request,
    limit: int = 1000, 
    offset: int = 0,
    sort_by: Optional[str] = None,
    sort_order: str = "asc",
    db_pool = Depends(get_db_pool)
):
    if not schema.replace("_","").isalnum() or not table.replace("_","").isalnum():
        raise HTTPException(400, "Invalid name")

    filters = {}
    for key, value in request.query_params.items():
        if key not in ['limit', 'offset', 'sort_by', 'sort_order']:
            if key.replace("_","").isalnum():
                filters[key] = value

    async with db_pool.acquire() as conn:
        query = f'SELECT * FROM "{schema}"."{table}"'
        params = []
        where_clauses = []
        
        idx = 1
        for col, val in filters.items():
            where_clauses.append(f'"{col}"::text ILIKE ${idx}')
            params.append(f"%{val}%")
            idx += 1
            
        if where_clauses:
            query += " WHERE " + " AND ".join(where_clauses)
            
        if sort_by and sort_by.replace("_","").isalnum():
            direction = "DESC" if sort_order.lower() == "desc" else "ASC"
            query += f' ORDER BY "{sort_by}" {direction}'
            
        query += f" LIMIT ${idx} OFFSET ${idx+1}"
        params.append(limit)
        params.append(offset)

        try:
            rows = await conn.fetch(query, *params)
        except Exception as e:
            raise HTTPException(400, f"Query Error: {e}")
    
    return [serialize_row(row) for row in rows]

@app.put("/api/table/{schema}/{table}")
async def update_record(schema: str, table: str, request: Request, user: dict = Depends(get_current_user), db_pool = Depends(get_db_pool)):
    params = dict(request.query_params)
    body = await request.json()
    
    if not params:
        raise HTTPException(400, "Primary Key required in URL parameters for update")

    set_items = []
    values = []
    idx = 1
    
    for col, val in body.items():
        if col == "attachment_link" and val == "": val = None
        set_items.append(f'"{col}" = ${idx}')
        values.append(val)
        idx += 1
        
    where_items = []
    for pk_col, pk_val in params.items():
        where_items.append(f'"{pk_col}" = ${idx}')
        values.append(pk_val)
        idx += 1
        
    query = f'UPDATE "{schema}"."{table}" SET {", ".join(set_items)} WHERE {" AND ".join(where_items)}'

    async with db_pool.acquire() as conn:
        await conn.execute(f"SELECT set_config('session.logged_in_person_id', '{user['user_id']}', false)")
        try:
            await conn.execute(query, *values)
        except Exception as e:
            logger.error(f"Update Error: {e}")
            raise HTTPException(500, str(e))
    return {**body}

@app.delete("/api/table/{schema}/{table}")
async def delete_record(schema: str, table: str, request: Request, user: dict = Depends(get_current_user), db_pool = Depends(get_db_pool)):
    params = dict(request.query_params)
    if not params:
        raise HTTPException(400, "Primary Key required for deletion")
        
    where_items = []
    values = []
    idx = 1
    for pk_col, pk_val in params.items():
        where_items.append(f'"{pk_col}" = ${idx}')
        values.append(pk_val)
        idx += 1
        
    query = f'DELETE FROM "{schema}"."{table}" WHERE {" AND ".join(where_items)}'
    
    async with db_pool.acquire() as conn:
        await conn.execute(f"SELECT set_config('session.logged_in_person_id', '{user['user_id']}', false)")
        try:
            result = await conn.execute(query, *values)
            if result == "DELETE 0":
                raise HTTPException(404, "Record not found or could not be deleted")
        except asyncpg.ForeignKeyViolationError:
            raise HTTPException(400, "Cannot delete: Record is referenced by other data")
        except Exception as e:
            raise HTTPException(500, str(e))
            
    return {"status": "success", "message": "Record deleted"}

# --- BATCH OPERATIONS ---

@app.post("/api/table/{schema}/{table}/batch_upload")
async def batch_upload(schema: str, table: str, payload: List[Dict[str, Any]], user: dict = Depends(get_current_user), db_pool = Depends(get_db_pool)):
    rows = payload
    if not rows: return {"count": 0}
    
    async with db_pool.acquire() as conn:
        col_meta = await conn.fetch("""
            SELECT column_name, data_type 
            FROM information_schema.columns 
            WHERE table_schema = $1 AND table_name = $2
        """, schema, table)
        type_map = {r['column_name']: r['data_type'] for r in col_meta}
        
        cols = list(rows[0].keys())
        col_str = ", ".join([f'"{c}"' for c in cols])
        
        records = []
        for r in rows:
            row_vals = []
            for c in cols:
                val = r.get(c)
                if val is not None and c in type_map:
                    val = parse_value_by_type(val, type_map[c])
                row_vals.append(val)
            records.append(row_vals)

        placeholders = "(" + ", ".join([f"${i+1}" for i in range(len(cols))]) + ")"
        query = f'INSERT INTO "{schema}"."{table}" ({col_str}) VALUES {placeholders}'
        
        await conn.execute(f"SELECT set_config('session.logged_in_person_id', '{user['user_id']}', false)")
        async with conn.transaction():
            await conn.executemany(query, records)
            
    return {"status": "success", "count": len(records)}

@app.post("/api/table/{schema}/{table}/batch_update")
async def batch_update(schema: str, table: str, payload: List[Dict[str, Any]], user: dict = Depends(get_current_user), db_pool = Depends(get_db_pool)):
    updated = 0
    async with db_pool.acquire() as conn:
        await conn.execute(f"SELECT set_config('session.logged_in_person_id', '{user['user_id']}', false)")
        pk_rows = await conn.fetch("""
            SELECT a.attname
            FROM   pg_index i
            JOIN   pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY(i.indkey)
            WHERE  i.indrelid = (quote_ident($1) || '.' || quote_ident($2))::regclass
            AND    i.indisprimary;
        """, schema, table)
        pk_cols = [r['attname'] for r in pk_rows]
        
        if not pk_cols: raise HTTPException(400, f"Cannot update {table}: No PK found")

        col_meta = await conn.fetch("""
            SELECT column_name, data_type 
            FROM information_schema.columns 
            WHERE table_schema = $1 AND table_name = $2
        """, schema, table)
        type_map = {r['column_name']: r['data_type'] for r in col_meta}

        async with conn.transaction():
            for row in payload:
                pks = {k: row[k] for k in pk_cols if k in row}
                data = {k: row[k] for k in row if k not in pk_cols}
                if not pks or not data: continue
                
                set_items = []
                values = []
                idx = 1
                for k, v in data.items():
                    if v == "": v = None
                    if v is not None and k in type_map: v = parse_value_by_type(v, type_map[k])
                    set_items.append(f'"{k}" = ${idx}')
                    values.append(v)
                    idx += 1
                
                where_items = []
                for k, v in pks.items():
                    if v is not None and k in type_map: v = parse_value_by_type(v, type_map[k])
                    where_items.append(f'"{k}" = ${idx}')
                    values.append(v)
                    idx += 1
                
                query = f'UPDATE "{schema}"."{table}" SET {", ".join(set_items)} WHERE {" AND ".join(where_items)}'
                await conn.execute(query, *values)
                updated += 1
    return {"status": "success", "count": updated}

# ==============================================================================
# 7. STATIC FILES & RUN
# ==============================================================================
os.makedirs("upload", exist_ok=True)
app.mount("/upload", StaticFiles(directory="upload"), name="upload")
app.mount("/", StaticFiles(directory=".", html=True), name="static")

if __name__ == "__main__":
    uvicorn.run("app:app", host="0.0.0.0", port=5600, reload=True)