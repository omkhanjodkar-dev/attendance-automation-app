# final backend
import uvicorn
from fastapi import FastAPI, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional
from datetime import datetime
import models, database
from auth_bearer import JWTBearer
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# --- Pydantic Models for Data Validation ---

class Validated(BaseModel):
    status: bool

class SSIDResponse(BaseModel):
    ssid: Optional[str]

class CurrentClassResponse(BaseModel):
    status: bool
    subject: Optional[str] = None

class AttendanceSession(BaseModel):
    status: bool

class AttendanceAdd(BaseModel):
    status: bool

class UpdateSSID(BaseModel):
    section: str
    ssid: str

# --- App Initialization ---

# Create tables if they don't exist
models.Base.metadata.create_all(bind=database.engine)

app = FastAPI(
    title="Attendance Resource Server",
    description="Handles attendance sessions, SSID management, and attendance records.",
    version="3.0"
)

# --- API Endpoints ---

@app.get("/", tags=["General"])
async def root():
    return {"message": "Attendance Resource Server is running. Visit /docs for Swagger UI."}

@app.get("/get_class_ssid", response_model=SSIDResponse, tags=["Resources"])
async def get_class_ssid(
    section: str, 
    credentials: dict = Depends(JWTBearer()),
    db: Session = Depends(database.get_db)
):
    """Get the WiFi SSID for a class section. Requires authentication."""
    valid_hotspot = db.query(models.ClassHotspot).filter(
        models.ClassHotspot.section == section,
    ).first()
    
    return {"ssid": valid_hotspot.ssid if valid_hotspot else None}

@app.post("/update_class_ssid", response_model=Validated, tags=["Faculty"])
async def update_class_ssid(
    data: UpdateSSID,
    credentials: dict = Depends(JWTBearer()),
    db: Session = Depends(database.get_db)
):
    """Update WiFi SSID for a class section. Faculty only."""
    # Check if user is faculty
    if credentials.get("role") != "faculty":
        raise HTTPException(status_code=403, detail="Only faculty can update SSID")
    
    hotspot = db.query(models.ClassHotspot).filter(
        models.ClassHotspot.section == data.section
    ).first()
    
    if hotspot:
        hotspot.ssid = data.ssid
    else:
        new_hotspot = models.ClassHotspot(section=data.section, ssid=data.ssid)
        db.add(new_hotspot)
    
    db.commit()
    return {"status": True}

@app.get("/check_attendance_session", response_model=AttendanceSession, tags=["Resources"])
async def check_attendance_session(
    section: str,
    credentials: dict = Depends(JWTBearer()),
    db: Session = Depends(database.get_db)
):
    """Check if an attendance session is active. Requires authentication."""
    session = db.query(models.AttendanceSession).filter(
        models.AttendanceSession.section == section,
        models.AttendanceSession.is_active == True
    ).first()
    
    return {"status": True if session else False}

@app.post("/add_attendance", response_model=AttendanceAdd, tags=["Attendance"])
async def add_attendance(
    section: str,
    username: str,
    subject: str,
    date: str,
    time: str,
    credentials: dict = Depends(JWTBearer()),
    db: Session = Depends(database.get_db)
):
    """Mark attendance for a student. Requires authentication."""
    # Parse date and time strings to Python objects
    try:
        dt_date = datetime.strptime(date, "%Y-%m-%d").date()
    except:
        dt_date = None
    
    try:
        dt_time = datetime.strptime(time, "%H:%M:%S").time() 
    except:
         dt_time = None

    new_record = models.AttendanceRecord(
        section=section,
        username=username,
        subject=subject,
        date=dt_date,
        time=dt_time
    )

    db.add(new_record)
    db.commit()
    return {"status": True}

@app.get("/get_current_class", response_model=CurrentClassResponse, tags=["Resources"])
async def get_current_class(
    section: str,
    credentials: dict = Depends(JWTBearer()),
    db: Session = Depends(database.get_db)
):
    """Get current active class subject. Requires authentication."""
    session = db.query(models.AttendanceSession).filter(
        models.AttendanceSession.section == section,
        models.AttendanceSession.is_active == True
    ).first()
    
    if session:
        return {"status": True, "subject": session.subject}
    else:
        return {"status": False, "subject": None}

@app.post("/start_attendance_session", response_model=AttendanceSession, tags=["Faculty"])
async def start_attendance_session(
    section: str,
    subject: str,
    credentials: dict = Depends(JWTBearer()),
    db: Session = Depends(database.get_db)
):
    """Start an attendance session. Faculty only."""
    # Check if user is faculty
    if credentials.get("role") != "faculty":
        raise HTTPException(status_code=403, detail="Only faculty can start attendance sessions")
    
    # 1. Close existing
    existing = db.query(models.AttendanceSession).filter(
        models.AttendanceSession.section == section,
        models.AttendanceSession.is_active == True
    ).all()
    for s in existing:
        s.is_active = False
    
    # 2. Start new
    new_session = models.AttendanceSession(
        section=section,
        subject=subject,
        is_active=True
    )
    db.add(new_session)
    db.commit()
    
    return {"status": True}

@app.post("/stop_attendance_session", response_model=AttendanceSession, tags=["Faculty"])
async def stop_attendance_session(
    section: str,
    credentials: dict = Depends(JWTBearer()),
    db: Session = Depends(database.get_db)
):
    """Stop an attendance session. Faculty only."""
    # Check if user is faculty
    if credentials.get("role") != "faculty":
        raise HTTPException(status_code=403, detail="Only faculty can stop attendance sessions")
    
    session = db.query(models.AttendanceSession).filter(
        models.AttendanceSession.section == section,
        models.AttendanceSession.is_active == True
    ).first()
    
    if session:
        session.is_active = False
        db.commit()
    
    return {"status": False}

# --- Main ---

if __name__ == "__main__":
    print("Starting resource server on http://localhost:8001")
    print("Documentation available at http://localhost:8001/docs")
    uvicorn.run(app, host="0.0.0.0", port=8001)