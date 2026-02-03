import os
import jwt
import asyncpg
import bcrypt
from datetime import date, datetime, timedelta
from typing import Optional, List, Dict, Any
from fastapi import FastAPI, Depends, HTTPException, status, Request, Form
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.security import OAuth2PasswordBearer
from pydantic import BaseModel
from fastapi.middleware.cors import CORSMiddleware

# --- CONFIGURATION ---
# Updated key to 32+ bytes to fix InsecureKeyLengthWarning
SECRET_KEY = "SUPER_SECRET_LAB_KEY_2025_SECURE_HASH_V5.1_UPDATED" 
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 480

# Database Connection Strings
MUSR_DSN = "postgresql://auth_user:auth_password@localhost/musr"
MYLIMS_DSN = "postgresql://kasmi:password@localhost/migfish_demo"

app = FastAPI(title="MyLIMS V5.1 API")

# Enable CORS for the SPA
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
    pools['musr'] = await asyncpg.create_pool(MUSR_DSN)
    pools['lims'] = await asyncpg.create_pool(MYLIMS_DSN)

@app.on_event("shutdown")
async def shutdown():
    await pools['musr'].close()
    await pools['lims'].close()

# --- AUTH UTILITIES ---
def verify_password(plain_password, hashed_password):
    return bcrypt.checkpw(plain_password.encode('utf-8'), hashed_password.encode('utf-8'))

def create_access_token(data: dict):
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

# --- MODELS ---
class LoginRequest(BaseModel):
    username: str
    password: str

class ProjectCreate(BaseModel):
    project_id: str
    title: str
    acronym: str
    start_date: Optional[date] = None
    status_id: str = 'Active'

class ProjectUpdate(BaseModel):
    title: Optional[str] = None
    acronym: Optional[str] = None
    status_id: Optional[str] = None

class SampleCreate(BaseModel):
    sample_type_id: str
    project_id: str
    collection_date: Optional[date] = None
    status_id: str = 'Planned'
    external_id: Optional[str] = None
    notes: Optional[str] = None

class SampleUpdate(BaseModel):
    collection_date: Optional[date] = None
    status_id: Optional[str] = None
    external_id: Optional[str] = None
    notes: Optional[str] = None

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
        counts = await conn.fetchrow("""
            SELECT 
                (SELECT COUNT(*) FROM lims.projects) as projects,
                (SELECT COUNT(*) FROM bio_assets.samples_root) as samples,
                (SELECT COUNT(*) FROM field.sampling_event) as events,
                (SELECT COUNT(*) FROM core.equipments) as equipment
        """)
        return dict(counts)

@app.get("/api/aux/sample_types")
async def list_sample_types():
    async with pools['lims'].acquire() as conn:
        rows = await conn.fetch("SELECT sample_type_id, abbreviation, notes FROM reference.sample_type ORDER BY sample_type_id")
        return [dict(r) for r in rows]

# --- PROJECTS CRUD ---

@app.get("/api/projects")
async def list_projects():
    async with pools['lims'].acquire() as conn:
        rows = await conn.fetch("SELECT project_id, title, acronym, status_id, start_date FROM lims.projects ORDER BY start_date DESC")
        return [dict(r) for r in rows]

@app.post("/api/projects")
async def create_project(p: ProjectCreate):
    async with pools['lims'].acquire() as conn:
        try:
            await conn.execute("""
                INSERT INTO lims.projects (project_id, title, acronym, start_date, status_id)
                VALUES ($1, $2, $3, $4, $5)
            """, p.project_id, p.title, p.acronym, p.start_date or date.today(), p.status_id)
            return {"message": "Project created", "id": p.project_id}
        except asyncpg.UniqueViolationError:
            raise HTTPException(status_code=400, detail="Project ID already exists")

@app.put("/api/projects/{project_id}")
async def update_project(project_id: str, p: ProjectUpdate):
    async with pools['lims'].acquire() as conn:
        # Build dynamic update query
        fields = []
        values = []
        idx = 1
        if p.title:
            fields.append(f"title = ${idx}"); values.append(p.title); idx += 1
        if p.acronym:
            fields.append(f"acronym = ${idx}"); values.append(p.acronym); idx += 1
        if p.status_id:
            fields.append(f"status_id = ${idx}"); values.append(p.status_id); idx += 1
            
        if not fields:
            return {"message": "No changes requested"}
            
        values.append(project_id)
        query = f"UPDATE lims.projects SET {', '.join(fields)} WHERE project_id = ${idx}"
        await conn.execute(query, *values)
        return {"message": "Project updated"}

# --- SAMPLES CRUD ---

@app.get("/api/samples/recent")
async def recent_samples():
    async with pools['lims'].acquire() as conn:
        rows = await conn.fetch("""
            SELECT sample_id, sample_type_id, project_id, collection_date, status_id, external_id, notes
            FROM bio_assets.samples_root 
            ORDER BY collection_date DESC LIMIT 20
        """)
        return [dict(r) for r in rows]

@app.post("/api/samples")
async def create_sample(s: SampleCreate):
    async with pools['lims'].acquire() as conn:
        # sample_id is generated by DB trigger (fn_generate_hierarchical_sample_id)
        # We pass NULL/DEFAULT to let trigger handle it
        try:
            # We select the generated ID using RETURNING
            row = await conn.fetchrow("""
                INSERT INTO bio_assets.samples_root 
                (sample_type_id, project_id, collection_date, status_id, external_id, notes, is_active)
                VALUES ($1, $2, $3, $4, $5, $6, true)
                RETURNING sample_id
            """, s.sample_type_id, s.project_id, s.collection_date or date.today(), s.status_id, s.external_id, s.notes)
            return {"message": "Sample registered", "sample_id": row['sample_id']}
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))

@app.put("/api/samples/{sample_id}")
async def update_sample(sample_id: str, s: SampleUpdate):
    async with pools['lims'].acquire() as conn:
        fields = []
        values = []
        idx = 1
        if s.collection_date:
            fields.append(f"collection_date = ${idx}"); values.append(s.collection_date); idx += 1
        if s.status_id:
            fields.append(f"status_id = ${idx}"); values.append(s.status_id); idx += 1
        if s.external_id:
            fields.append(f"external_id = ${idx}"); values.append(s.external_id); idx += 1
        if s.notes:
            fields.append(f"notes = ${idx}"); values.append(s.notes); idx += 1
            
        if not fields:
            return {"message": "No changes requested"}
            
        values.append(sample_id)
        query = f"UPDATE bio_assets.samples_root SET {', '.join(fields)} WHERE sample_id = ${idx}"
        await conn.execute(query, *values)
        return {"message": "Sample updated"}

@app.get("/api/search")
async def global_search(q: str):
    async with pools['lims'].acquire() as conn:
        # Utilizing the provided dashboard.fn_global_search function
        rows = await conn.fetch("SELECT * FROM dashboard.fn_global_search($1)", q)
        return [dict(r) for r in rows]

@app.get("/", response_class=HTMLResponse)
async def get_index():
    with open("index.html", "r") as f:
        return f.read()

if __name__ == "__main__":
    import uvicorn
    # Run on 0.0.0.0 to allow external access, Port 5000 as requested
    uvicorn.run(app, host="0.0.0.0", port=5000)

# To run with Gunicorn: gunicorn -w 4 -k uvicorn.workers.UvicornWorker main:app --bind 0.0.0.0:5000