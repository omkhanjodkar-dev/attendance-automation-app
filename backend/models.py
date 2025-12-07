from sqlalchemy import Column, Integer, String, Boolean, DateTime, Date, Time, ForeignKey
from sqlalchemy.sql import func
from .database import Base

# Table: students
class Student(Base):
    __tablename__ = "students"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String, unique=True, index=True)
    password = Column(String)

# Table: faculty
class Faculty(Base):
    __tablename__ = "faculty"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String, unique=True, index=True)
    password = Column(String)

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
    section = Column(String)
    username = Column(String)
    subject = Column(String)
    status = Column(String, default="Present")
    date = Column(Date)
    time = Column(Time)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
