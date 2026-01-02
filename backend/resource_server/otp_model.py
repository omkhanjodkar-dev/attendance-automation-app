from sqlalchemy import Column, Integer, String, Boolean, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from database import Base


class SessionOTP(Base):
    """
    Table to store One-Time Passwords (OTPs) for attendance sessions.
    Each active session generates a unique OTP that students use to verify proximity.
    """
    __tablename__ = "session_otps"

    id = Column(Integer, primary_key=True, index=True)
    session_id = Column(Integer, ForeignKey('active_sessions.id', ondelete='CASCADE'), nullable=False)
    otp_code = Column(String(6), unique=True, index=True, nullable=False)
    created_at = Column(DateTime, server_default=func.now())
    expires_at = Column(DateTime, nullable=False)
    is_used = Column(Boolean, default=False)
    
    # Relationship to the attendance session
    # session = relationship("AttendanceSession", back_populates="otp")
