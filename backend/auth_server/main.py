# final backend
import uvicorn
from fastapi import FastAPI, Depends, HTTPException, Body
from auth_handler import sign_jwt

from sqlalchemy.orm import Session
from pydantic import BaseModel, Field
from typing import Optional
import models, database
import bcrypt
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# --- Pydantic Models for Data Validation ---

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
    description="Microservice for handling student and faculty authentication.",
    version="1.0"
)

# --- API Endpoints ---

@app.get("/", tags=["General"])
async def root():
    return {"message": "Attendance Auth Server is running. Visit /docs for Swagger UI."}

@app.post("/check_student_login", response_model=Login, tags=["Authentication"])
async def check_student_login(username: str, password: str, db: Session = Depends(database.get_db)):
    student = db.query(models.Student).filter(
        models.Student.username == username
    ).first()
    
    if student and bcrypt.checkpw(password.encode('utf-8'), student.password.encode('utf-8')):
        token_data = sign_jwt(username, "student")
        return {"status": True, "access_token": token_data["access_token"]}
    
    return {"status": False}

@app.post("/check_faculty_login", response_model=Login, tags=["Authentication"])
async def check_faculty_login(username: str, password: str, db: Session = Depends(database.get_db)):
    faculty = db.query(models.Faculty).filter(
        models.Faculty.username == username
    ).first()
    
    if faculty and bcrypt.checkpw(password.encode('utf-8'), faculty.password.encode('utf-8')):
        token_data = sign_jwt(username, "faculty")
        return {"status": True, "access_token": token_data["access_token"]}
    
    return {"status": False}

# --- Main ---

if __name__ == "__main__":
    print("Starting auth server on http://localhost:8000")
    print("Documentation available at http://localhost:8000/docs")
    uvicorn.run(app, host="0.0.0.0", port=8000)