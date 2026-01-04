# final backend
from typing import List
import uvicorn
from fastapi import FastAPI, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional
from datetime import datetime, timedelta
import models, database
from otp_model import SessionOTP
from auth_bearer import JWTBearer
from dotenv import load_dotenv
import random
import string

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

class AttendanceRecordResponse(BaseModel):
    date: str
    time: str
    username: str
    subject: str

class StudentStatsResponse(BaseModel):
    username: str
    subject: str
    attended: int
    total: int
    percentage: float

class OTPGenerateResponse(BaseModel):
    status: bool
    otp: Optional[str] = None
    expires_at: Optional[str] = None

class OTPVerifyRequest(BaseModel):
    section: str
    username: str
    otp: str
    date: str
    time: str

class OTPVerifyResponse(BaseModel):
    status: bool
    subject: Optional[str] = None
    message: Optional[str] = None

# --- Helper Functions ---

def generate_otp(length: int = 6) -> str:
    """Generate a random alphanumeric OTP code."""
    characters = string.ascii_uppercase + string.digits
    return ''.join(random.choice(characters) for _ in range(length))

# --- App Initialization ---

# Create tables if they don't exist
models.Base.metadata.create_all(bind=database.engine)
SessionOTP.metadata.create_all(bind=database.engine)

app = FastAPI(
    title="Attendance Resource Server",
    description="Handles attendance sessions, SSID management, and attendance records.",
    version="3.0"
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow all origins for development
    allow_credentials=True,
    allow_methods=["*"],  # Allow all methods
    allow_headers=["*"],  # Allow all headers
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

@app.post("/start_attendance_session", response_model=OTPGenerateResponse, tags=["Faculty"])
async def start_attendance_session(
    section: str,
    subject: str,
    credentials: dict = Depends(JWTBearer()),
    db: Session = Depends(database.get_db)
):
    """Start an attendance session and generate OTP. Faculty only."""
    # Check if user is faculty
    if credentials.get("role") != "faculty":
        raise HTTPException(status_code=403, detail="Only faculty can start attendance sessions")
    
    # 1. Close existing sessions
    existing = db.query(models.AttendanceSession).filter(
        models.AttendanceSession.section == section,
        models.AttendanceSession.is_active == True
    ).all()
    for s in existing:
        s.is_active = False
    
    # 2. Start new session
    new_session = models.AttendanceSession(
        section=section,
        subject=subject,
        is_active=True
    )
    db.add(new_session)
    db.commit()
    db.refresh(new_session)
    
    # 3. Generate OTP for this session
    otp_code = generate_otp(6)
    expires_at = datetime.now() + timedelta(minutes=10)
    
    new_otp = SessionOTP(
        session_id=new_session.id,
        otp_code=otp_code,
        expires_at=expires_at,
        is_used=False
    )
    db.add(new_otp)
    db.commit()
    
    return {
        "status": True,
        "otp": otp_code,
        "expires_at": expires_at.strftime("%Y-%m-%d %H:%M:%S")
    }

@app.post("/stop_attendance_session", response_model=AttendanceSession, tags=["Faculty"])
async def stop_attendance_session(
    section: str,
    credentials: dict = Depends(JWTBearer()),
    db: Session = Depends(database.get_db)
):
    """Stop an attendance session and invalidate OTP. Faculty only."""
    # Check if user is faculty
    if credentials.get("role") != "faculty":
        raise HTTPException(status_code=403, detail="Only faculty can stop attendance sessions")
    
    session = db.query(models.AttendanceSession).filter(
        models.AttendanceSession.section == section,
        models.AttendanceSession.is_active == True
    ).first()
    
    if session:
        session.is_active = False
        
        # VULN-015: Mark ALL associated OTPs as used/expired
        otps = db.query(SessionOTP).filter(
            SessionOTP.session_id == session.id,
            SessionOTP.is_used == False
        ).all()
        
        for otp in otps:
            otp.is_used = True
        
        db.commit()
    
    return {"status": False}

@app.post("/verify_otp", response_model=OTPVerifyResponse, tags=["Attendance"])
async def verify_otp(
    data: OTPVerifyRequest,
    credentials: dict = Depends(JWTBearer()),
    db: Session = Depends(database.get_db)
):
    """Verify OTP and mark attendance for student. Requires authentication."""
    
    # VULN-023: Validate student exists
    student = db.query(models.Student).filter(
        models.Student.username == data.username,
        models.Student.section == data.section
    ).first()
    
    if not student:
        raise HTTPException(
            status_code=404,
            detail=f"Student '{data.username}' not found in section {data.section}"
        )
    
    # 1. Find the OTP record
    otp_record = db.query(SessionOTP).filter(
        SessionOTP.otp_code == data.otp,
        SessionOTP.is_used == False
    ).first()
    
    if not otp_record:
        raise HTTPException(status_code=400, detail="Invalid or already used OTP")
    
    # 2. Check if OTP is expired
    if datetime.now() > otp_record.expires_at:
        raise HTTPException(status_code=400, detail="OTP has expired")
    
    # 3. Get the associated session
    session = db.query(models.AttendanceSession).filter(
        models.AttendanceSession.id == otp_record.session_id,
        models.AttendanceSession.section == data.section,
        models.AttendanceSession.is_active == True
    ).first()
    
    if not session:
        raise HTTPException(status_code=400, detail="No active session found for this OTP")
    
    # 4. Check if student already marked attendance for this session
    existing_attendance = db.query(models.AttendanceRecord).filter(
        models.AttendanceRecord.section == data.section,
        models.AttendanceRecord.username == data.username,
        models.AttendanceRecord.subject == session.subject,
        models.AttendanceRecord.date == datetime.strptime(data.date, "%Y-%m-%d").date()
    ).first()
    
    if existing_attendance:
        return {
            "status": True,
            "subject": session.subject,
            "message": "Attendance already marked for this session"
        }
    
    # 5. Mark attendance
    try:
        dt_date = datetime.strptime(data.date, "%Y-%m-%d").date()
        dt_time = datetime.strptime(data.time, "%H:%M:%S").time()
    except:
        raise HTTPException(status_code=400, detail="Invalid date/time format")
    
    new_record = models.AttendanceRecord(
        section=data.section,
        username=data.username,
        subject=session.subject,
        date=dt_date,
        time=dt_time,
        status="Present"
    )
    
    db.add(new_record)
    # Note: We don't mark OTP as used to allow multiple students to use the same OTP
    # OTP is only invalidated when session ends or expires
    db.commit()
    
    return {
        "status": True,
        "subject": session.subject,
        "message": "Attendance marked successfully"
    }


@app.get("/get_attendance_records", response_model=List[AttendanceRecordResponse], tags=["Attendance"])
async def get_attendance_records(
    section: str,
    credentials: dict = Depends(JWTBearer()),
    db: Session = Depends(database.get_db)
):
    """Get attendance records for a section. Requires authentication."""
    records = db.query(models.AttendanceRecord).filter(
        models.AttendanceRecord.section == section,
        models.AttendanceRecord.status == "Present"
    ).all()

    result = []
    for record in records:
        result.append({
            "date": record.date.strftime("%Y-%m-%d") if record.date else "",
            "time": record.time.strftime("%H:%M:%S") if record.time else "",
            "username": record.username,
            "subject": record.subject
        })
    
    return result

@app.get("/get_all_student_stats", response_model=List[StudentStatsResponse], tags=["Attendance"])
async def get_all_student_stats(
    section: str,
    credentials: dict = Depends(JWTBearer()),
    db: Session = Depends(database.get_db)
):
    """Get attendance statistics for all students in a section. Requires authentication."""
    
    # Get all attendance records for this section
    all_records = db.query(models.AttendanceRecord).filter(
        models.AttendanceRecord.section == section
    ).all()
    
    # Get all session records to calculate total classes per subject
    all_sessions = db.query(models.AttendanceSession).filter(
        models.AttendanceSession.section == section
    ).all()
    
    # Calculate total classes per subject
    subject_totals = {}
    for session in all_sessions:
        subject = session.subject
        subject_totals[subject] = subject_totals.get(subject, 0) + 1
    
    # Group attendance by username and subject
    stats_dict = {}
    for record in all_records:
        if record.status == "Present":
            key = (record.username, record.subject)
            stats_dict[key] = stats_dict.get(key, 0) + 1
    
    # Build the result
    result = []
    for (username, subject), attended in stats_dict.items():
        total = subject_totals.get(subject, 0)
        percentage = (attended / total * 100) if total > 0 else 0.0
        
        result.append({
            "username": username,
            "subject": subject,
            "attended": attended,
            "total": total,
            "percentage": round(percentage, 2)
        })
    
    return result

# --- Main ---

if __name__ == "__main__":
    print("Starting resource server on http://localhost:8001")
    print("Documentation available at http://localhost:8001/docs")
    uvicorn.run(app, host="0.0.0.0", port=8001)