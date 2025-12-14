import os
from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from dotenv import load_dotenv

# Load .env from this directory (auth_server/.env)
load_dotenv()

# Get DB URL from environment variable (Cloud) or fallback to Localhost
SQLALCHEMY_DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres:Pass%401234@localhost:5432/auth_database")

# Fix for some cloud providers (like Render) using "postgres://" instead of "postgresql://"
if SQLALCHEMY_DATABASE_URL.startswith("postgres://"):
    SQLALCHEMY_DATABASE_URL = SQLALCHEMY_DATABASE_URL.replace("postgres://", "postgresql://", 1)

# Create engine with connection pool configuration for production
engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    pool_pre_ping=True,           # Test connections before using them
    pool_recycle=3600,             # Recycle connections after 1 hour
    pool_size=10,                  # Number of connections to maintain
    max_overflow=20,               # Allow up to 20 additional connections
    connect_args={
        "connect_timeout": 10,     # Connection timeout in seconds
        "options": "-c statement_timeout=30000"  # Query timeout (30 seconds)
    }
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()