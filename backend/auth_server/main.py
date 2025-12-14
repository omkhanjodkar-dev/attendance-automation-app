# final backend
import uvicorn
import time
from datetime import datetime, timedelta
from fastapi import FastAPI, Depends, HTTPException
from auth_handler import sign_jwt, decode_token, ACCESS_TOKEN_EXPIRE_MINUTES, REFRESH_TOKEN_EXPIRE_DAYS, JWT_SECRET, JWT_ALGORITHM
import jwt

from sqlalchemy.orm import Session
from pydantic import BaseModel, Field
from typing import Optional
import models, database
import bcrypt
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# --- Pydantic Models for Data Validation ---

class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"

class RefreshRequest(BaseModel):
    refresh_token: str

class LogoutRequest(BaseModel):
    refresh_token: str

# Legacy model for backward compatibility (not used in new endpoints)
class Login(BaseModel):
    status: bool
    access_token: Optional[str] = None

class UserSchema(BaseModel):
    username: str = Field(...)
    password: str = Field(...)

class UserLoginSchema(BaseModel):
    username: str = Field(...)
    password: str = Field(...)

# --- App Initialization ---

# Create tables if they don't exist
models.Base.metadata.create_all(bind=database.engine)

app = FastAPI(
    title="Attendance Auth Server",
    description="Microservice for handling student and faculty authentication with refresh tokens.",
    version="2.0"
)

# --- API Endpoints ---

@app.get("/", tags=["General"])
async def root():
    return {"message": "Attendance Auth Server v2.0 with Refresh Tokens. Visit /docs for Swagger UI."}

@app.post("/check_student_login", response_model=TokenResponse, tags=["Authentication"])
async def check_student_login(username: str, password: str, db: Session = Depends(database.get_db)):
    """Student login - returns access token and refresh token"""
    student = db.query(models.Student).filter(
        models.Student.username == username
    ).first()
    
    if student and bcrypt.checkpw(password.encode('utf-8'), student.password.encode('utf-8')):
        # Generate both tokens
        tokens = sign_jwt(username, "student")
        
        # Store refresh token in database
        expires_at = datetime.utcnow() + timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)
        db_refresh_token = models.RefreshToken(
            token=tokens["refresh_token"],
            user_id=username,
            role="student",
            expires_at=expires_at
        )
        db.add(db_refresh_token)
        db.commit()
        
        return tokens
    
    raise HTTPException(status_code=401, detail="Invalid credentials")

@app.post("/check_faculty_login", response_model=TokenResponse, tags=["Authentication"])
async def check_faculty_login(username: str, password: str, db: Session = Depends(database.get_db)):
    """Faculty login - returns access token and refresh token"""
    faculty = db.query(models.Faculty).filter(
        models.Faculty.username == username
    ).first()
    
    if faculty and bcrypt.checkpw(password.encode('utf-8'), faculty.password.encode('utf-8')):
        # Generate both tokens
        tokens = sign_jwt(username, "faculty")
        
        # Store refresh token in database
        expires_at = datetime.utcnow() + timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)
        db_refresh_token = models.RefreshToken(
            token=tokens["refresh_token"],
            user_id=username,
            role="faculty",
            expires_at=expires_at
        )
        db.add(db_refresh_token)
        db.commit()
        
        return tokens
    
    raise HTTPException(status_code=401, detail="Invalid credentials")

@app.post("/refresh", response_model=TokenResponse, tags=["Token Management"])
async def refresh_access_token(request: RefreshRequest, db: Session = Depends(database.get_db)):
    """Exchange refresh token for new access token"""
    # Decode the refresh token
    decoded = decode_token(request.refresh_token)
    
    if not decoded or decoded.get("type") != "refresh":
        raise HTTPException(status_code=401, detail="Invalid refresh token")
    
    # Check if token exists in database and is not revoked
    db_token = db.query(models.RefreshToken).filter(
        models.RefreshToken.token == request.refresh_token,
        models.RefreshToken.is_revoked == False
    ).first()
    
    if not db_token:
        raise HTTPException(status_code=401, detail="Refresh token revoked or not found")
    
    # Check if token is expired
    if db_token.expires_at < datetime.utcnow():
        raise HTTPException(status_code=401, detail="Refresh token expired")
    
    # Generate new access token (keep same refresh token)
    access_payload = {
        "user_id": decoded["user_id"],
        "role": decoded["role"],
        "expiry": time.time() + ACCESS_TOKEN_EXPIRE_MINUTES * 60,
        "type": "access"
    }
    new_access_token = jwt.encode(access_payload, JWT_SECRET, algorithm=JWT_ALGORITHM)
    
    return {
        "access_token": new_access_token,
        "refresh_token": request.refresh_token,  # Return same refresh token
        "token_type": "bearer"
    }

@app.post("/logout", tags=["Token Management"])
async def logout(request: LogoutRequest, db: Session = Depends(database.get_db)):
    """Revoke refresh token (logout)"""
    # Revoke the refresh token
    db_token = db.query(models.RefreshToken).filter(
        models.RefreshToken.token == request.refresh_token
    ).first()
    
    if db_token:
        db_token.is_revoked = True
        db.commit()
    
    return {"status": "success", "message": "Logged out successfully"}

# --- Main ---

if __name__ == "__main__":
    print("Starting auth server v2.0 on http://localhost:8000")
    print("Documentation available at http://localhost:8000/docs")
    uvicorn.run(app, host="0.0.0.0", port=8000)
