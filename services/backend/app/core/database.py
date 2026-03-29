"""
Database setup and session management.
Supports PostgreSQL (production) and SQLite (dev/test).
"""

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, DeclarativeBase
from app.core.config import settings

SQLALCHEMY_DATABASE_URL = settings.DATABASE_URL

# Build engine kwargs based on database type
_engine_kwargs: dict = {}

if SQLALCHEMY_DATABASE_URL.startswith("sqlite"):
    # SQLite: needs check_same_thread=False, no connection pooling params
    _engine_kwargs["connect_args"] = {"check_same_thread": False}
elif "postgresql" in SQLALCHEMY_DATABASE_URL:
    # PostgreSQL: enable connection pooling for production
    _engine_kwargs["pool_size"] = 20
    _engine_kwargs["max_overflow"] = 20
    _engine_kwargs["pool_recycle"] = 3600
    _engine_kwargs["pool_pre_ping"] = True

engine = create_engine(SQLALCHEMY_DATABASE_URL, **_engine_kwargs)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


class Base(DeclarativeBase):
    """Base class for all database models."""
    pass


def get_db():
    """Dependency to get database session."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
