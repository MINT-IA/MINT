"""
Database setup and session management.
Supports PostgreSQL (production) and SQLite (dev/test).
"""

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, DeclarativeBase
from app.core.config import settings

SQLALCHEMY_DATABASE_URL = settings.DATABASE_URL


def engine_options_for_url(database_url: str) -> dict[str, object]:
    """Return the production engine contract for a database URL."""
    if database_url.startswith("sqlite"):
        return {"connect_args": {"check_same_thread": False}}
    if "postgresql" in database_url:
        return {
            "pool_size": 20,
            "max_overflow": 20,
            "pool_recycle": 3600,
            "pool_pre_ping": True,
            "isolation_level": "READ COMMITTED",
        }
    return {}


_engine_kwargs = engine_options_for_url(SQLALCHEMY_DATABASE_URL)

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
