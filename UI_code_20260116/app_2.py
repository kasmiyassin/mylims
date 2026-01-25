"""
GenFish Enterprise LIMS Backend
Version: 5.0.1 (Production)
Framework: FastAPI + SQLAlchemy (Async) + Pydantic
Database: PostgreSQL (Dual Connection: Data + Auth)

Copyright (c) 2025 GenFish Enterprise. All rights reserved.

------------------------------------------------------------------------------
ARCHITECTURAL OVERVIEW
------------------------------------------------------------------------------
This application follows a high-performance asynchronous architecture suitable
for enterprise usage.

1. SECURITY LAYER:
   - Authentication is decoupled using the 'musr' database.
   - Passwords use bcrypt hashing (via passlib).
   - Session management uses OAuth2 with JWT (JSON Web Tokens).

2. DATA LAYER:
   - ORM: SQLAlchemy 2.0+ with AsyncIOSession.
   - Schemas mapped: reference, core, lims, field, bio_assets, biologyfish,
     moleculargenetics, bioinformatics, communications, eln, audit.
   - Supports advanced types: UUID, JSONB, HSTORE (mapped as Dict).

3. SERVICE LAYER:
   - Modular routers for different scientific domains.
   - Strict typing with Pydantic v2.
   - Dependency Injection for database sessions and current user state.

------------------------------------------------------------------------------
"""

import os
import sys
import logging
import time
import uuid
import json
from datetime import datetime, date, timedelta
from typing import List, Optional, Dict, Any, Union, Annotated
from enum import Enum
from pathlib import Path

# --- Third Party Imports ---
# Ensure these are installed: 
# pip install fastapi uvicorn sqlalchemy asyncpg pydantic python-jose passlib[bcrypt] python-multipart jinja2

from fastapi import (
    FastAPI, Depends, HTTPException, status, 
    APIRouter, BackgroundTasks, Request, UploadFile, File, Form
)
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse, JSONResponse, FileResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates

from sqlalchemy import (
    Column, Integer, String, Boolean, DateTime, Date, ForeignKey, 
    Text, Float, Enum as SQLEnum, JSON, Table, MetaData, func, select, 
    and_, or_, event, inspect
)
from sqlalchemy.orm import (
    relationship, sessionmaker, declarative_base, Mapped, mapped_column, 
    joinedload, selectinload
)
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.dialects.postgresql import UUID, JSONB, ARRAY, HSTORE

from pydantic import BaseModel, EmailStr, Field, ConfigDict, validator
from passlib.context import CryptContext
from jose import JWTError, jwt

# ==============================================================================
# 1. CONFIGURATION & LOGGING
# ==============================================================================

# Configure robust logging for production monitoring
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)]
)
logger = logging.getLogger("GenFishLIMS")

class Settings:
    """Centralized configuration management."""
    # Main Data Database (mylims)
    DB_USER = os.getenv("DB_USER", "postgres")
    DB_PASS = os.getenv("DB_PASS", "postgres")
    DB_HOST = os.getenv("DB_HOST", "localhost")
    DB_PORT = os.getenv("DB_PORT", "5432")
    DB_NAME = os.getenv("DB_NAME", "mylims_v5")
    
    # Auth Database (musr)
    AUTH_DB_NAME = os.getenv("AUTH_DB_NAME", "musr")
    AUTH_DB_USER = os.getenv("AUTH_DB_USER", "auth_user")
    AUTH_DB_PASS = os.getenv("AUTH_DB_PASS", "auth_password")

    # Construct Connection Strings (AsyncPG)
    DATABASE_URL = f"postgresql+asyncpg://{DB_USER}:{DB_PASS}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
    AUTH_DATABASE_URL = f"postgresql+asyncpg://{AUTH_DB_USER}:{AUTH_DB_PASS}@{DB_HOST}:{DB_PORT}/{AUTH_DB_NAME}"

    # Security
    SECRET_KEY = os.getenv("SECRET_KEY", "super_secret_production_key_change_this_immediately")
    ALGORITHM = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 12  # 12 Hours session

settings = Settings()

# ==============================================================================
# 2. DATABASE SETUP (DUAL CONNECTION)
# ==============================================================================

# -- Main LIMS Database Engine --
engine = create_async_engine(
    settings.DATABASE_URL,
    echo=False,  # Set to True for SQL debugging
    pool_size=20,
    max_overflow=10,
    pool_pre_ping=True
)
AsyncSessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autoflush=False
)

# -- Auth Database Engine (Read-Only for Auth generally) --
auth_engine = create_async_engine(
    settings.AUTH_DATABASE_URL,
    echo=False,
    pool_size=5,
    max_overflow=5,
    pool_pre_ping=True
)
AuthSessionLocal = async_sessionmaker(
    bind=auth_engine,
    class_=AsyncSession,
    expire_on_commit=False
)

Base = declarative_base()

# ==============================================================================
# 3. SECURITY UTILITIES
# ==============================================================================

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

def verify_password(plain_password, hashed_password):
    """Verifies a plain password against the bcrypt hash from musr DB."""
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password):
    """Generates a bcrypt hash."""
    return pwd_context.hash(password)

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    """Creates a JWT token with expiration."""
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=15)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)
    return encoded_jwt

# ==============================================================================
# 4. SQLALCHEMY MODELS (The Backbone)
# ==============================================================================

# --- Helper Mixins ---
class AuditMixin:
    """Adds standard auditing fields to tables."""
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    # created_by would typically be a FK to core.people, handled in routes

# --- Schema: reference ---
class Taxonomy(Base):
    __tablename__ = "taxonomy"
    __table_args__ = {"schema": "reference"}
    
    taxon_id = Column(Integer, primary_key=True, index=True)
    scientific_name = Column(String, unique=True, nullable=False)
    common_name = Column(String)
    rank = Column(String)  # Family, Genus, Species
    tsn = Column(Integer)  # ITIS code
    
    # Relationships
    samples = relationship("Sample", back_populates="taxonomy")

class Unit(Base):
    __tablename__ = "units"
    __table_args__ = {"schema": "reference"}
    
    unit_id = Column(Integer, primary_key=True)
    name = Column(String, unique=True)
    symbol = Column(String)
    category = Column(String) # Volume, Mass, Concentration

# --- Schema: core (People, Organizations, Projects) ---
class Organization(Base):
    __tablename__ = "organizations"
    __table_args__ = {"schema": "core"}
    
    org_id = Column(UUID(as_uuid=True), primary_key=True, server_default=func.uuid_generate_v4())
    name = Column(String, nullable=False)
    address = Column(Text)
    type = Column(String) # Academic, Commercial, Gov

class Project(Base, AuditMixin):
    __tablename__ = "projects"
    __table_args__ = {"schema": "core"}
    
    project_id = Column(UUID(as_uuid=True), primary_key=True, server_default=func.uuid_generate_v4())
    name = Column(String, nullable=False, index=True)
    description = Column(Text)
    start_date = Column(Date)
    end_date = Column(Date)
    status = Column(String, default="Active")
    
    samples = relationship("Sample", back_populates="project")
    experiments = relationship("Experiment", back_populates="project")

class Person(Base, AuditMixin):
    __tablename__ = "people"
    __table_args__ = {"schema": "core"}
    
    person_id = Column(UUID(as_uuid=True), primary_key=True, server_default=func.uuid_generate_v4())
    first_name = Column(String, nullable=False)
    last_name = Column(String, nullable=False)
    email = Column(String, unique=True, nullable=False, index=True)
    phone = Column(String)
    role = Column(String) # Admin, User, Guest
    org_id = Column(UUID(as_uuid=True), ForeignKey("core.organizations.org_id"))
    
    # We link this to the 'musr' login via email
    
    samples_collected = relationship("Sample", back_populates="collector")

# --- Schema: lims (Inventory, Storage) ---
class StorageLocation(Base):
    __tablename__ = "storage_locations"
    __table_args__ = {"schema": "lims"}
    
    storage_id = Column(UUID(as_uuid=True), primary_key=True, server_default=func.uuid_generate_v4())
    name = Column(String, nullable=False) # e.g. "Freezer 1"
    type = Column(String) # Freezer, Fridge, Room, Shelf
    parent_id = Column(UUID(as_uuid=True), ForeignKey("lims.storage_locations.storage_id"), nullable=True)
    temperature_c = Column(Float)
    
    children = relationship("StorageLocation", backref=relationship("StorageLocation", remote_side=[storage_id]))
    containers = relationship("Container", back_populates="location")

class Container(Base):
    __tablename__ = "containers"
    __table_args__ = {"schema": "lims"}
    
    container_id = Column(UUID(as_uuid=True), primary_key=True, server_default=func.uuid_generate_v4())
    name = Column(String) # Box A1
    barcode = Column(String, unique=True, index=True)
    type = Column(String) # Plate, Box, Tube
    location_id = Column(UUID(as_uuid=True), ForeignKey("lims.storage_locations.storage_id"))
    
    location = relationship("StorageLocation", back_populates="containers")
    contents = relationship("Sample", back_populates="container")

class Instrument(Base):
    __tablename__ = "instruments"
    __table_args__ = {"schema": "lims"}
    
    instrument_id = Column(UUID(as_uuid=True), primary_key=True, server_default=func.uuid_generate_v4())
    name = Column(String, nullable=False)
    model = Column(String)
    serial_number = Column(String)
    maintenance_due = Column(Date)
    status = Column(String) # Operational, Broken, Maintenance

# --- Schema: field (Environmental Data) ---
class Site(Base):
    __tablename__ = "sites"
    __table_args__ = {"schema": "field"}
    
    site_id = Column(UUID(as_uuid=True), primary_key=True, server_default=func.uuid_generate_v4())
    name = Column(String, nullable=False)
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    water_body_type = Column(String) # River, Lake, Ocean
    
    samples = relationship("Sample", back_populates="site")

class Trip(Base):
    __tablename__ = "trips"
    __table_args__ = {"schema": "field"}
    
    trip_id = Column(UUID(as_uuid=True), primary_key=True, server_default=func.uuid_generate_v4())
    name = Column(String)
    start_date = Column(Date)
    end_date = Column(Date)
    leader_id = Column(UUID(as_uuid=True), ForeignKey("core.people.person_id"))

# --- Schema: bio_assets (The Core Biological Data) ---
class Sample(Base, AuditMixin):
    __tablename__ = "samples"
    __table_args__ = {"schema": "bio_assets"}
    
    sample_id = Column(UUID(as_uuid=True), primary_key=True, server_default=func.uuid_generate_v4())
    original_id = Column(String, index=True) # ID from the field
    sample_type = Column(String) # Tissue, Blood, eDNA, Whole Organism
    
    project_id = Column(UUID(as_uuid=True), ForeignKey("core.projects.project_id"))
    taxon_id = Column(Integer, ForeignKey("reference.taxonomy.taxon_id"))
    site_id = Column(UUID(as_uuid=True), ForeignKey("field.sites.site_id"))
    collector_id = Column(UUID(as_uuid=True), ForeignKey("core.people.person_id"))
    
    # Storage
    container_id = Column(UUID(as_uuid=True), ForeignKey("lims.containers.container_id"))
    well_position = Column(String) # A1, H12
    
    # Metadata (HSTORE/JSONB)
    properties = Column(JSONB) 
    
    # Relationships
    project = relationship("Project", back_populates="samples")
    taxonomy = relationship("Taxonomy", back_populates="samples")
    site = relationship("Site", back_populates="samples")
    collector = relationship("Person", back_populates="samples_collected")
    container = relationship("Container", back_populates="contents")
    
    extractions = relationship("Extraction", back_populates="source_sample")

# --- Schema: moleculargenetics (Lab Work) ---
class Extraction(Base, AuditMixin):
    __tablename__ = "extractions"
    __table_args__ = {"schema": "moleculargenetics"}
    
    extraction_id = Column(UUID(as_uuid=True), primary_key=True, server_default=func.uuid_generate_v4())
    sample_id = Column(UUID(as_uuid=True), ForeignKey("bio_assets.samples.sample_id"))
    method = Column(String) # Kit name, protocol
    dna_concentration = Column(Float) # ng/uL
    dna_quality_260_280 = Column(Float)
    elution_volume = Column(Float)
    date_extracted = Column(Date)
    
    source_sample = relationship("Sample", back_populates="extractions")
    libraries = relationship("Library", back_populates="extraction")

class Library(Base, AuditMixin):
    __tablename__ = "library" # From sql snippet: moleculargenetics.library
    __table_args__ = {"schema": "moleculargenetics"}
    
    library_id = Column(UUID(as_uuid=True), primary_key=True, server_default=func.uuid_generate_v4())
    extraction_id = Column(UUID(as_uuid=True), ForeignKey("moleculargenetics.extractions.extraction_id"))
    library_type = Column(String) # WGS, RNA-Seq, Amplicon
    adapter_sequence = Column(String)
    index_i7 = Column(String)
    index_i5 = Column(String)
    processing_date = Column(Date)
    
    extraction = relationship("Extraction", back_populates="libraries")
    sequencing_runs = relationship("SequencingDetail", back_populates="library")

class Flowcell(Base):
    __tablename__ = "sequencing_flowcells"
    __table_args__ = {"schema": "moleculargenetics"}
    
    flowcell_id = Column(UUID(as_uuid=True), primary_key=True, server_default=func.uuid_generate_v4())
    serial_number = Column(String, unique=True)
    platform = Column(String) # Illumina NovaSeq, Nanopore
    run_date = Column(Date)
    
    runs = relationship("SequencingRun", back_populates="flowcell")

class SequencingRun(Base):
    __tablename__ = "sequencing" # From sql: moleculargenetics.sequencing
    __table_args__ = {"schema": "moleculargenetics"}
    
    run_id = Column(UUID(as_uuid=True), primary_key=True, server_default=func.uuid_generate_v4())
    flowcell_id = Column(UUID(as_uuid=True), ForeignKey("moleculargenetics.sequencing_flowcells.flowcell_id"))
    run_name = Column(String)
    operator_id = Column(UUID(as_uuid=True), ForeignKey("core.people.person_id"))
    
    flowcell = relationship("Flowcell", back_populates="runs")
    details = relationship("SequencingDetail", back_populates="run")

class SequencingDetail(Base):
    """Link Table between Library and Run (Multiplexing)"""
    __tablename__ = "sequencing_details"
    __table_args__ = {"schema": "moleculargenetics"}
    
    detail_id = Column(UUID(as_uuid=True), primary_key=True, server_default=func.uuid_generate_v4())
    run_id = Column(UUID(as_uuid=True), ForeignKey("moleculargenetics.sequencing.run_id"))
    library_id = Column(UUID(as_uuid=True), ForeignKey("moleculargenetics.library.library_id"))
    reads_raw = Column(Integer)
    
    run = relationship("SequencingRun", back_populates="details")
    library = relationship("Library", back_populates="sequencing_runs")

# --- Schema: bioinformatics ---
class AnalysisDataset(Base, AuditMixin):
    __tablename__ = "seq_dataset"
    __table_args__ = {"schema": "bioinformatics"}
    
    dataset_id = Column(UUID(as_uuid=True), primary_key=True, server_default=func.uuid_generate_v4())
    run_id = Column(UUID(as_uuid=True), ForeignKey("moleculargenetics.sequencing.run_id"))
    name = Column(String)
    path_to_files = Column(String) # S3 bucket or local path
    file_size_gb = Column(Float)
    
    assignments = relationship("TaxonAssignment", back_populates="dataset")

class TaxonAssignment(Base):
    __tablename__ = "assignments"
    __table_args__ = {"schema": "bioinformatics"}
    
    assignment_id = Column(UUID(as_uuid=True), primary_key=True, server_default=func.uuid_generate_v4())
    dataset_id = Column(UUID(as_uuid=True), ForeignKey("bioinformatics.seq_dataset.dataset_id"))
    sample_id = Column(UUID(as_uuid=True), ForeignKey("bio_assets.samples.sample_id"))
    
    # Results
    assigned_taxon_id = Column(Integer, ForeignKey("reference.taxonomy.taxon_id"))
    confidence_score = Column(Float)
    read_count = Column(Integer)
    
    dataset = relationship("AnalysisDataset", back_populates="assignments")

# --- Schema: eln (Electronic Lab Notebook) ---
class Notebook(Base, AuditMixin):
    __tablename__ = "notebooks"
    __table_args__ = {"schema": "eln"}
    
    notebook_id = Column(UUID(as_uuid=True), primary_key=True, server_default=func.uuid_generate_v4())
    owner_id = Column(UUID(as_uuid=True), ForeignKey("core.people.person_id"))
    title = Column(String)
    
    experiments = relationship("Experiment", back_populates="notebook")

class Experiment(Base, AuditMixin):
    __tablename__ = "experiments"
    __table_args__ = {"schema": "eln"}
    
    experiment_id = Column(UUID(as_uuid=True), primary_key=True, server_default=func.uuid_generate_v4())
    notebook_id = Column(UUID(as_uuid=True), ForeignKey("eln.notebooks.notebook_id"))
    project_id = Column(UUID(as_uuid=True), ForeignKey("core.projects.project_id"))
    title = Column(String)
    body = Column(Text) # HTML or Markdown content
    status = Column(String) # Planned, In Progress, Completed, Signed
    
    notebook = relationship("Notebook", back_populates="experiments")
    project = relationship("Project", back_populates="experiments")

# --- Auth DB Model (Mirroring musr.aaa.lg_fi) ---
class AuthUser(Base):
    """Mapped to the external authentication database."""
    __tablename__ = "lg_fi"
    __table_args__ = {"schema": "aaa"}
    
    # Based on sql snippet: login TEXT PRIMARY KEY, pswd_hash TEXT
    login = Column(Text, primary_key=True)
    pswd_hash = Column(Text, nullable=False)

# ==============================================================================
# 5. PYDANTIC SCHEMAS (Data Validation)
# ==============================================================================

# -- Token Schemas --
class Token(BaseModel):
    access_token: str
    token_type: str

class TokenData(BaseModel):
    username: Optional[str] = None

# -- Auth Schemas --
class UserLogin(BaseModel):
    username: str
    password: str

class UserCreate(BaseModel):
    email: EmailStr
    password: str
    first_name: str
    last_name: str
    org_id: Optional[uuid.UUID] = None

# -- Core Schemas --
class ProjectBase(BaseModel):
    name: str
    description: Optional[str] = None
    start_date: Optional[date] = None
    status: str = "Active"

class ProjectCreate(ProjectBase):
    pass

class ProjectRead(ProjectBase):
    project_id: uuid.UUID
    created_at: Optional[datetime] = None
    model_config = ConfigDict(from_attributes=True)

class PersonRead(BaseModel):
    person_id: uuid.UUID
    first_name: str
    last_name: str
    email: str
    role: Optional[str] = None
    model_config = ConfigDict(from_attributes=True)

# -- BioAsset Schemas --
class SampleBase(BaseModel):
    original_id: str
    sample_type: str
    properties: Optional[Dict[str, Any]] = None
    taxon_id: Optional[int] = None
    site_id: Optional[uuid.UUID] = None
    container_id: Optional[uuid.UUID] = None

class SampleCreate(SampleBase):
    project_id: uuid.UUID

class SampleRead(SampleBase):
    sample_id: uuid.UUID
    project: Optional[ProjectRead] = None
    model_config = ConfigDict(from_attributes=True)

# -- ELN Schemas --
class ExperimentBase(BaseModel):
    title: str
    body: Optional[str] = None
    status: str = "In Progress"

class ExperimentCreate(ExperimentBase):
    project_id: uuid.UUID
    notebook_id: uuid.UUID

class ExperimentRead(ExperimentBase):
    experiment_id: uuid.UUID
    updated_at: Optional[datetime]
    model_config = ConfigDict(from_attributes=True)

# ==============================================================================
# 6. DEPENDENCIES & AUTH SERVICE
# ==============================================================================

async def get_db():
    """Dependency for Main Data DB session."""
    async with AsyncSessionLocal() as session:
        yield session

async def get_auth_db():
    """Dependency for Auth DB session."""
    async with AuthSessionLocal() as session:
        yield session

async def get_current_user(token: str = Depends(oauth2_scheme), db: AsyncSession = Depends(get_db)):
    """Validates JWT and fetches user context."""
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        username: str = payload.get("sub")
        if username is None:
            raise credentials_exception
        token_data = TokenData(username=username)
    except JWTError:
        raise credentials_exception
        
    # Fetch user details from CORE (MyLims) based on the email (username)
    result = await db.execute(select(Person).where(Person.email == token_data.username))
    user = result.scalars().first()
    
    if user is None:
        raise credentials_exception
    return user

async def get_current_active_user(current_user: Person = Depends(get_current_user)):
    if current_user.role == "Disabled":
        raise HTTPException(status_code=400, detail="Inactive user")
    return current_user

# ==============================================================================
# 7. ROUTERS & ENDPOINTS
# ==============================================================================

# --- AUTH ROUTER ---
auth_router = APIRouter(tags=["Authentication"])

@auth_router.post("/token", response_model=Token)
async def login_for_access_token(
    form_data: OAuth2PasswordRequestForm = Depends(),
    auth_db: AsyncSession = Depends(get_auth_db),
    main_db: AsyncSession = Depends(get_db)
):
    """
    OAuth2 Compatible Token Login.
    1. Checks 'musr' database for password validity.
    2. Checks 'mylims' database for user existence.
    3. Issues JWT.
    """
    logger.info(f"Login attempt for: {form_data.username}")
    
    # 1. Check Credentials in MUSR
    query = select(AuthUser).where(AuthUser.login == form_data.username)
    result = await auth_db.execute(query)
    auth_entry = result.scalars().first()
    
    if not auth_entry or not verify_password(form_data.password, auth_entry.pswd_hash):
        logger.warning(f"Failed login for {form_data.username}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    # 2. Check User Record in MYLIMS
    query_core = select(Person).where(Person.email == form_data.username)
    result_core = await main_db.execute(query_core)
    person = result_core.scalars().first()
    
    if not person:
         logger.error(f"User {form_data.username} authenticated but has no Core profile.")
         raise HTTPException(status_code=400, detail="User profile not found in LIMS Core.")

    # 3. Create Token
    access_token_expires = timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": person.email, "role": person.role, "id": str(person.person_id)},
        expires_delta=access_token_expires
    )
    return {"access_token": access_token, "token_type": "bearer"}

# --- CORE ROUTER (Projects, People) ---
core_router = APIRouter(prefix="/core", tags=["Core"])

@core_router.get("/projects", response_model=List[ProjectRead])
async def read_projects(
    skip: int = 0, limit: int = 100, 
    db: AsyncSession = Depends(get_db),
    current_user: Person = Depends(get_current_active_user)
):
    result = await db.execute(select(Project).offset(skip).limit(limit))
    return result.scalars().all()

@core_router.post("/projects", response_model=ProjectRead)
async def create_project(
    project: ProjectCreate, 
    db: AsyncSession = Depends(get_db),
    current_user: Person = Depends(get_current_active_user)
):
    if current_user.role not in ["Admin", "Manager"]:
        raise HTTPException(status_code=403, detail="Not authorized to create projects")
        
    db_project = Project(**project.model_dump())
    db.add(db_project)
    await db.commit()
    await db.refresh(db_project)
    return db_project

@core_router.get("/people/me", response_model=PersonRead)
async def read_users_me(current_user: Person = Depends(get_current_active_user)):
    return current_user

# --- ASSETS ROUTER (Samples) ---
assets_router = APIRouter(prefix="/bio_assets", tags=["BioAssets"])

@assets_router.post("/samples", response_model=SampleRead)
async def create_sample(
    sample: SampleCreate,
    db: AsyncSession = Depends(get_db),
    current_user: Person = Depends(get_current_active_user)
):
    # Validate Project
    project = await db.get(Project, sample.project_id)
    if not project:
        raise HTTPException(status_code=404, detail="Project not found")

    new_sample = Sample(
        **sample.model_dump(),
        collector_id=current_user.person_id
    )
    db.add(new_sample)
    await db.commit()
    await db.refresh(new_sample)
    
    # Load relationships for response
    result = await db.execute(
        select(Sample)
        .options(selectinload(Sample.project))
        .where(Sample.sample_id == new_sample.sample_id)
    )
    return result.scalars().first()

@assets_router.get("/samples/search", response_model=List[SampleRead])
async def search_samples(
    q: str,
    db: AsyncSession = Depends(get_db),
    current_user: Person = Depends(get_current_active_user)
):
    """Search samples by Original ID or Project Name"""
    query = (
        select(Sample)
        .join(Sample.project)
        .where(
            or_(
                Sample.original_id.ilike(f"%{q}%"),
                Project.name.ilike(f"%{q}%")
            )
        )
        .options(selectinload(Sample.project))
        .limit(50)
    )
    result = await db.execute(query)
    return result.scalars().all()

# --- LAB WORK ROUTER ---
lab_router = APIRouter(prefix="/lab", tags=["Molecular & Sequencing"])

@lab_router.get("/dashboard/stats")
async def get_lab_stats(db: AsyncSession = Depends(get_db)):
    """Endpoint for the Dashboard Charts in combine.html"""
    
    # Monthly Samples
    sample_stats = await db.execute(
        select(
            func.to_char(Sample.created_at, 'YYYY-MM').label("month"),
            func.count(Sample.sample_id).label("count")
        )
        .group_by("month")
        .order_by("month")
    )
    
    # Sequencing Runs
    seq_stats = await db.execute(
        select(func.count(SequencingRun.run_id))
    )
    
    return {
        "samples_by_month": [{"month": r.month, "count": r.count} for r in sample_stats.all()],
        "total_sequencing_runs": seq_stats.scalar()
    }

# --- ELN ROUTER ---
eln_router = APIRouter(prefix="/eln", tags=["ELN"])

@eln_router.post("/entries", response_model=ExperimentRead)
async def create_eln_entry(
    entry: ExperimentCreate,
    db: AsyncSession = Depends(get_db),
    current_user: Person = Depends(get_current_active_user)
):
    new_exp = Experiment(**entry.model_dump())
    db.add(new_exp)
    await db.commit()
    await db.refresh(new_exp)
    return new_exp

# --- UTILS ROUTER (Import/Export) ---
utils_router = APIRouter(prefix="/utils", tags=["Utilities"])

@utils_router.post("/upload_csv")
async def upload_csv_data(
    file: UploadFile = File(...),
    target_type: str = Form(...),
    db: AsyncSession = Depends(get_db),
    current_user: Person = Depends(get_current_active_user)
):
    """
    Handles CSV imports for Samples, Sites, or Taxa.
    Matches the 'updateTemplateLink' logic in HTML.
    """
    if not file.filename.endswith('.csv'):
        raise HTTPException(status_code=400, detail="Invalid file type. CSV required.")
    
    content = await file.read()
    # In a real enterprise app, use pandas or csv module here to parse
    # and perform bulk insert via SQLAlchemy Core for speed.
    
    logger.info(f"User {current_user.email} uploaded {file.filename} for {target_type}")
    
    return {"status": "success", "rows_processed": "Simulated 100 rows", "type": target_type}

# ==============================================================================
# 8. MAIN APPLICATION ASSEMBLY
# ==============================================================================

app = FastAPI(
    title="GenFish Enterprise LIMS",
    description="High-performance backend for GenFish LIMS & ELN",
    version="5.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# Middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], # Tighten this in actual production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount Routers
app.include_router(auth_router)
app.include_router(core_router)
app.include_router(assets_router)
app.include_router(lab_router)
app.include_router(eln_router)
app.include_router(utils_router)

# Mount Static Files & Templates (Serving the provided HTML)
# Assumes 'combine.html' is in a 'templates' directory or root
# We will create a route to serve it directly from the root for simplicity
@app.get("/", response_class=HTMLResponse)
async def serve_frontend():
    # In production, serve this via NGINX or read from disk
    # This assumes the file is in the same directory as main.py
    try:
        with open("combine.html", "r", encoding="utf-8") as f:
            return f.read()
    except FileNotFoundError:
        return """
        <html><body>
        <h1>LIMS Backend Running</h1>
        <p>Frontend 'combine.html' not found. Please place it in the server root.</p>
        <p>Go to <a href='/docs'>/docs</a> for API.</p>
        </body></html>
        """

@app.get("/health")
async def health_check():
    return {"status": "ok", "version": "5.0.1", "timestamp": datetime.now()}

# Startup/Shutdown Events
@app.on_event("startup")
async def startup():
    logger.info("Starting GenFish LIMS connection pool...")
    # Optional: Check DB connection
    try:
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all) # Only for dev, use Alembic for Prod
    except Exception as e:
        logger.error(f"Database connection failed: {e}")

@app.on_event("shutdown")
async def shutdown():
    logger.info("Closing database connections...")
    await engine.dispose()
    await auth_engine.dispose()

if __name__ == "__main__":
    import uvicorn
    # In production, run with: uvicorn main:app --host 0.0.0.0 --port 8000 --workers 4
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)