import uvicorn
from fastapi import FastAPI, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional
from . import models, database

# --- Pydantic Models for Data Validation ---

class Login(BaseModel):
    status: bool

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

# --- App Initialization ---

# Create tables if they don't exist
models.Base.metadata.create_all(bind=database.engine)

app = FastAPI(
    title="Attendance Automation App",
    description="A simple app for marking your college attendance.",
    version="2.3"
)

# --- API Endpoints ---

@app.get("/", tags=["General"])
async def root():
    return {"message": "Attendance Automation App is running. Visit /docs for Swagger UI."}

@app.post("/check_student_login", response_model=Login, tags=["Authentication"])
async def check_student_login(username: str, password: str, db: Session = Depends(database.get_db)):
    student = db.query(models.Student).filter(
        models.Student.username == username,
        models.Student.password == password
    ).first()
    
    return {"status": True if student else False}

@app.post("/check_faculty_login", response_model=Login, tags=["Authentication"])
async def check_faculty_login(username: str, password: str, db: Session = Depends(database.get_db)):
    faculty = db.query(models.Faculty).filter(
        models.Faculty.username == username,
        models.Faculty.password == password
    ).first()
    
    return {"status": True if faculty else False}

@app.get("/get_class_ssid", response_model=SSIDResponse, tags=["Authentication"])
async def get_class_ssid(section: str, db: Session = Depends(database.get_db)):
    valid_hotspot = db.query(models.ClassHotspot).filter(
        models.ClassHotspot.section == section,
    ).first()
    
    return {"ssid": valid_hotspot.ssid if valid_hotspot else None}

@app.get("/check_attendance_session", response_model=AttendanceSession, tags=["Authentication"])
async def check_attendance_session(section: str, db: Session = Depends(database.get_db)):
    session = db.query(models.AttendanceSession).filter(
        models.AttendanceSession.section == section,
        models.AttendanceSession.is_active == True
    ).first()
    
    return {"status": True if session else False}

@app.post("/add_attendance", response_model=AttendanceAdd, tags=["Attendance"])
async def add_attendance(section : str, username : str, subject : str, date : str, time : str, db: Session = Depends(database.get_db)):
    # Parse date and time strings to Python objects
    from datetime import datetime
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

@app.get("/get_current_class", response_model=CurrentClassResponse, tags=["Attendance"])
async def get_current_class(section: str, db: Session = Depends(database.get_db)):
    session = db.query(models.AttendanceSession).filter(
        models.AttendanceSession.section == section,
        models.AttendanceSession.is_active == True
    ).first()
    
    if session:
        return {"status": True, "subject": session.subject}
    else:
        return {"status": False, "subject": None}

@app.post("/start_attendance_session", response_model=AttendanceSession, tags=["Attendance"])
async def start_attendance_session(section: str, subject: str, db: Session = Depends(database.get_db)):
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

@app.post("/stop_attendance_session", response_model=AttendanceSession, tags=["Attendance"])
async def stop_attendance_session(section: str, db: Session = Depends(database.get_db)):
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
    print("Starting server on http://localhost:8000")
    print("Documentation available at http://localhost:8000/docs")
    uvicorn.run(app, host="0.0.0.0", port=8000)