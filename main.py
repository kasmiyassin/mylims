import os
import jwt
import asyncpg
import bcrypt
import json
from datetime import date, datetime, timedelta
from typing import Optional, List, Dict, Any, Union
from fastapi import FastAPI, Depends, HTTPException, status, Request, Response
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

# --- CONFIGURATION ---
SECRET_KEY = os.getenv("SECRET_KEY", "SUPER_SECRET_LAB_KEY_2025_SECURE_HASH_V5.1_UPDATED")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 480

# Database Credentials
DB_HOST = os.getenv('DB_HOST', '0.0.0.0') # Changed default to 0.0.0.0 based on user preference
DB_NAME = os.getenv('DB_NAME', 'migfish_demo') 
DB_USER = os.getenv('DB_USER', 'kasmi')
DB_PASS = os.getenv('DB_PASS', 'password')

AUTH_DB_HOST = os.getenv('AUTH_DB_HOST', '0.0.0.0')
AUTH_DB_NAME = os.getenv('AUTH_DB_NAME', 'musr')
AUTH_DB_USER = os.getenv('AUTH_DB_USER', 'auth_user')
AUTH_DB_PASS = os.getenv('AUTH_DB_PASS', 'auth_password')

# Connection Strings
MUSR_DSN = f"postgresql://{AUTH_DB_USER}:{AUTH_DB_PASS}@{AUTH_DB_HOST}/{AUTH_DB_NAME}"
MYLIMS_DSN = f"postgresql://{DB_USER}:{DB_PASS}@{DB_HOST}/{DB_NAME}"

app = FastAPI(title="MyLIMS V5.1 API")

# Enable CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- DATABASE POOLS ---
pools = {}

@app.on_event("startup")
async def startup():
    try:
        pools['musr'] = await asyncpg.create_pool(MUSR_DSN)
        pools['lims'] = await asyncpg.create_pool(MYLIMS_DSN)
        print("✅ Database pools initialized.")
    except Exception as e:
        print(f"❌ Database connection failed: {e}")

@app.on_event("shutdown")
async def shutdown():
    for pool in pools.values():
        await pool.close()

# --- UTILITIES ---
def verify_password(plain_password, hashed_password):
    return bcrypt.checkpw(plain_password.encode('utf-8'), hashed_password.encode('utf-8'))

def create_access_token(data: dict):
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

class CustomJSONResponse(JSONResponse):
    def render(self, content: Any) -> bytes:
        return json.dumps(
            content,
            ensure_ascii=False,
            allow_nan=False,
            indent=None,
            separators=(",", ":"),
            default=self.json_serializer,
        ).encode("utf-8")

    @staticmethod
    def json_serializer(obj):
        if isinstance(obj, (date, datetime)):
            return obj.isoformat()
        if hasattr(obj, "__str__"): 
            return str(obj)
        raise TypeError(f"Type {type(obj)} not serializable")

# --- CORE LOGIC (Decoupled from API Request) ---
async def fetch_db_records(conn, schema: str, table: str, filters: Dict[str, Any], limit: int = 100, offset: int = 0):
    """
    Core function to fetch records dynamically from any table.
    Handles filtering logic without relying on Starlette Request objects.
    """
    where_parts = []
    values = []
    idx = 1

    # Basic Sanitization (In prod, validate against information_schema)
    if not schema.replace("_", "").isalnum() or not table.replace("_", "").isalnum():
        raise ValueError(f"Invalid schema ({schema}) or table ({table}) name")

    for key, val in filters.items():
        if key in ['limit', 'offset', 'sort_by', 'order']: continue
        # Basic SQL injection prevention for column names
        if not key.replace("_", "").isalnum(): continue
        
        where_parts.append(f'"{key}" = ${idx}')
        values.append(val)
        idx += 1
    
    where_clause = "WHERE " + " AND ".join(where_parts) if where_parts else ""
    
    query = f'SELECT * FROM "{schema}"."{table}" {where_clause} LIMIT ${idx} OFFSET ${idx+1}'
    values.extend([limit, offset])
    
    rows = await conn.fetch(query, *values)
    return rows

# --- MODELS ---
class LoginRequest(BaseModel):
    username: str
    password: str

class GenericRecord(BaseModel):
    data: Dict[str, Any]

class BatchImportRequest(BaseModel):
    schema_name: str
    table_name: str
    records: List[Dict[str, Any]]
    update_existing: bool = False
    pk_field: str = "id"

# --- API ENDPOINTS ---

@app.post("/api/auth/login")
async def login(req: LoginRequest):
    async with pools['musr'].acquire() as conn:
        user = await conn.fetchrow("SELECT login, pswd_hash FROM aaa.lg_fi WHERE login = $1", req.username)
        
        if not user or not verify_password(req.password, user['pswd_hash']):
            raise HTTPException(status_code=401, detail="Invalid credentials")
        
        # Get person details from LIMS
        async with pools['lims'].acquire() as lims_conn:
            person = await lims_conn.fetchrow(
                "SELECT first_name, last_name, role_in_org FROM core.persons WHERE person_id = $1 OR email = $1", 
                req.username
            )
            
        token = create_access_token({"sub": req.username})
        return {
            "access_token": token, 
            "token_type": "bearer",
            "user": {
                "id": req.username,
                "name": f"{person['first_name']} {person['last_name']}" if person else req.username,
                "role": person['role_in_org'] if person else "User"
            }
        }

@app.get("/api/dashboard/stats")
async def get_stats():
    async with pools['lims'].acquire() as conn:
        try:
            # Using standard COUNT queries for robustness
            # These tables are assumed based on your SQL snippet
            projects = await conn.fetchval("SELECT COUNT(*) FROM lims.projects")
            samples = await conn.fetchval("SELECT COUNT(*) FROM bio_assets.samples_root")
            
            # Use try/except inside to handle potential missing tables if schema varied
            try: events = await conn.fetchval("SELECT COUNT(*) FROM field.sampling_event")
            except: events = 0
            
            try: equipment = await conn.fetchval("SELECT COUNT(*) FROM core.equipments")
            except: equipment = 0
            
            return {
                "projects": projects,
                "samples": samples,
                "events": events,
                "equipment": equipment
            }
        except Exception as e:
            print(f"Stats Error: {e}")
            return {"projects": 0, "samples": 0, "events": 0, "equipment": 0}

# --- GENERIC METADATA ENDPOINTS ---

@app.get("/api/meta/columns/{schema}/{table}")
async def get_table_columns(schema: str, table: str):
    """Fetches column metadata to build dynamic forms on frontend"""
    async with pools['lims'].acquire() as conn:
        rows = await conn.fetch("""
            SELECT column_name, data_type, is_nullable, column_default
            FROM information_schema.columns 
            WHERE table_schema = $1 AND table_name = $2
            ORDER BY ordinal_position
        """, schema, table)
        return [dict(r) for r in rows]

# --- GENERIC CRUD ENDPOINTS ---

@app.get("/api/generic/{schema}/{table}", response_class=CustomJSONResponse)
async def list_records_endpoint(schema: str, table: str, request: Request, limit: int = 100, offset: int = 0):
    async with pools['lims'].acquire() as conn:
        try:
            filters = dict(request.query_params)
            # Remove pagination params from filters dict
            filters.pop('limit', None)
            filters.pop('offset', None)
            
            rows = await fetch_db_records(conn, schema, table, filters, limit, offset)
            return [dict(r) for r in rows]
        except Exception as e:
            raise HTTPException(status_code=400, detail=str(e))

@app.post("/api/generic/{schema}/{table}")
async def create_record_endpoint(schema: str, table: str, record: GenericRecord):
    async with pools['lims'].acquire() as conn:
        cols = record.data.keys()
        vals = list(record.data.values())
        placeholders = [f"${i+1}" for i in range(len(vals))]
        
        col_str = ", ".join([f'"{c}"' for c in cols])
        val_str = ", ".join(placeholders)
        
        query = f'INSERT INTO "{schema}"."{table}" ({col_str}) VALUES ({val_str}) RETURNING *'
        
        try:
            row = await conn.fetchrow(query, *vals)
            return {"message": "Record created", "data": dict(row)}
        except Exception as e:
            raise HTTPException(status_code=400, detail=str(e))

@app.put("/api/generic/{schema}/{table}/{pk_col}/{pk_val}")
async def update_record_endpoint(schema: str, table: str, pk_col: str, pk_val: str, record: GenericRecord):
    async with pools['lims'].acquire() as conn:
        updates = []
        vals = []
        idx = 1
        
        for key, val in record.data.items():
            updates.append(f'"{key}" = ${idx}')
            vals.append(val)
            idx += 1
            
        vals.append(pk_val)
        update_str = ", ".join(updates)
        
        query = f'UPDATE "{schema}"."{table}" SET {update_str} WHERE "{pk_col}" = ${idx} RETURNING *'
        
        try:
            row = await conn.fetchrow(query, *vals)
            if not row:
                raise HTTPException(status_code=404, detail="Record not found")
            return {"message": "Record updated", "data": dict(row)}
        except Exception as e:
            raise HTTPException(status_code=400, detail=str(e))

# --- BATCH IMPORT ENDPOINT ---

@app.post("/api/batch/import")
async def batch_import(req: BatchImportRequest):
    async with pools['lims'].acquire() as conn:
        success_count = 0
        errors = []
        
        async with conn.transaction():
            for i, record in enumerate(req.records):
                try:
                    cols = list(record.keys())
                    vals = list(record.values())
                    
                    if req.update_existing and req.pk_field in record:
                        # --- UPDATE LOGIC ---
                        pk_val = record[req.pk_field]
                        
                        updates = [f'"{k}" = ${j+1}' for j, k in enumerate(cols)]
                        update_str = ", ".join(updates)
                        
                        query_vals = list(vals)
                        query_vals.append(pk_val)
                        
                        query = f'''
                            UPDATE "{req.schema_name}"."{req.table_name}" 
                            SET {update_str} 
                            WHERE "{req.pk_field}" = ${len(vals)+1}
                        '''
                        
                        # We use execute here. If 0 rows updated, we could optionally insert, 
                        # but standard behavior for 'update_existing' implies we update if present.
                        status_msg = await conn.execute(query, *query_vals)
                        # e.g. "UPDATE 1" or "UPDATE 0"
                        if status_msg == "UPDATE 1":
                            success_count += 1
                            continue 
                        # If update 0, we fall through to INSERT logic below

                    # --- INSERT LOGIC ---
                    placeholders = [f"${n+1}" for n in range(len(vals))]
                    col_str = ", ".join([f'"{c}"' for c in cols])
                    val_str = ", ".join(placeholders)
                    
                    query = f'''
                        INSERT INTO "{req.schema_name}"."{req.table_name}" ({col_str}) 
                        VALUES ({val_str})
                    '''
                    
                    if req.update_existing:
                        # Upsert attempt
                        set_clause = ", ".join([f'"{c}" = EXCLUDED."{c}"' for c in cols if c != req.pk_field])
                        if set_clause:
                            query += f' ON CONFLICT ("{req.pk_field}") DO UPDATE SET {set_clause}'
                        else:
                            query += f' ON CONFLICT ("{req.pk_field}") DO NOTHING'
                            
                    await conn.execute(query, *vals)
                    success_count += 1
                    
                except Exception as e:
                    errors.append(f"Row {i}: {str(e)}")
        
        return {
            "success": True, 
            "imported": success_count, 
            "errors": errors[:10] 
        }

# --- HELPER ENDPOINTS (Corrected to use internal logic) ---

@app.get("/api/projects", response_class=CustomJSONResponse)
async def list_projects_specific():
    """Specific optimized endpoint for projects view"""
    # Fix: Use fetch_db_records directly, no Request object
    async with pools['lims'].acquire() as conn:
        rows = await fetch_db_records(conn, "lims", "projects", {}, limit=1000)
        return [dict(r) for r in rows]

@app.get("/api/samples/recent", response_class=CustomJSONResponse)
async def recent_samples():
    async with pools['lims'].acquire() as conn:
        try:
            # Adjusted to standard join if necessary, or just simple select
            rows = await conn.fetch("""
                SELECT * FROM bio_assets.samples_root 
                ORDER BY collection_date DESC NULLS LAST LIMIT 20
            """)
            return [dict(r) for r in rows]
        except Exception as e:
            print(f"Error fetching recent samples: {e}")
            return []

@app.get("/api/aux/sample_types", response_class=CustomJSONResponse)
async def list_sample_types():
    # Fix: Use fetch_db_records directly, no Request object
    async with pools['lims'].acquire() as conn:
        rows = await fetch_db_records(conn, "reference", "sample_type", {}, limit=1000)
        return [dict(r) for r in rows]

@app.get("/api/search")
async def global_search(q: str):
    async with pools['lims'].acquire() as conn:
        try:
            rows = await conn.fetch("SELECT * FROM dashboard.fn_global_search($1)", q)
            return [dict(r) for r in rows]
        except:
            return []

@app.get("/", response_class=HTMLResponse)
async def get_index():
    if os.path.exists("index.html"):
        with open("index.html", "r") as f:
            return f.read()
    return "Frontend not found. Please upload index.html"

if __name__ == "__main__":
    import uvicorn
    # Run on 0.0.0.0 to allow external access, Port 5000 as requested
    uvicorn.run(app, host="0.0.0.0", port=5000)