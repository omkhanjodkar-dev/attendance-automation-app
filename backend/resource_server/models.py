from sqlalchemy import Column, Integer, String, Boolean, DateTime, Date, Time, ForeignKey, UniqueConstraint
from sqlalchemy.sql import func
from database import Base


# Table: class_hotspots
class ClassHotspot(Base):
    __tablename__ = "class_hotspots"

    id = Column(Integer, primary_key=True, index=True)
    section = Column(String, unique=True, index=True)
    ssid = Column(String)

# Table: active_sessions
class AttendanceSession(Base):
    __tablename__ = "active_sessions"

    id = Column(Integer, primary_key=True, index=True)
    section = Column(String, index=True)
    subject = Column(String)
    start_time = Column(DateTime, server_default=func.now())
    is_active = Column(Boolean, default=True)

# Table: attendance_records
class AttendanceRecord(Base):
    __tablename__ = "attendance_records"

    id = Column(Integer, primary_key=True, index=True)
    session_id = Column(Integer, ForeignKey('active_sessions.id'), nullable=True, index=True)  # Nullable for migration
    section = Column(String)
    username = Column(String, index=True)
    subject = Column(String)
    status = Column(String, default="Present")
    date = Column(Date)
    time = Column(Time)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Unique constraint: one attendance per student per session
    __table_args__ = (
        UniqueConstraint('session_id', 'username', name='unique_attendance_per_session'),
    )
