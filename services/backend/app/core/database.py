"""
Database setup and session management.
Supports PostgreSQL (production) and SQLite (dev/test).

Phase mint-data-architecture-v1-02 Plan 02-02 W1 continuation-4 P4 — iter-2
B12 + B15 wiring : `pool_timeout=10` (backfill must not exhaust pool
indefinitely) + `prepare_threshold=None` (PgBouncer transaction-pool
compat). The `get_backfill_engine()` helper returns a throttled engine
(`pool_size=2, max_overflow=0`) for Plan 02-03 PR-3a backfill scripts that
must NOT compete with serving traffic on the main pool.
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
elif "postgresql" in SQLALCHEMY_DATABASE_URL:  # pragma: no cover
    # PostgreSQL: enable connection pooling for production
    _engine_kwargs["pool_size"] = 20  # pragma: no cover
    _engine_kwargs["max_overflow"] = 20  # pragma: no cover
    _engine_kwargs["pool_recycle"] = 3600
    _engine_kwargs["pool_pre_ping"] = True
    # iter-2 B15 : pool_timeout=10s so backfill that grabs all connections
    # eventually surfaces a TimeoutError rather than blocking serving
    # traffic indefinitely.
    _engine_kwargs["pool_timeout"] = 10  # pragma: no cover
    # iter-2 B12 : prepare_threshold=None disables psycopg2 prepared-statement
    # caching so PgBouncer in transaction-pool mode (Railway default) does
    # NOT see « prepared statement \"S_1\" does not exist » errors. The
    # connection-level cache loses its prepared statements on each pool
    # checkout ; opting out of the cache avoids the mismatch.
    _engine_kwargs["connect_args"] = {  # pragma: no cover
        "prepare_threshold": None,
        "options": "-c application_name=mint-backend",
    }

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


def get_backfill_engine():  # pragma: no cover — exercised only by Plan 02-03 PR-3a
    """Return a throttled engine for backfill scripts (iter-2 B15).

    The main `engine` uses `pool_size=20, max_overflow=20` to serve
    traffic. A backfill that grabs all 40 connections starves serving
    requests. This helper returns a SEPARATE engine with
    `pool_size=2, max_overflow=0` so the backfill is bounded at 2
    concurrent connections.

    Callers (e.g., Plan 02-03 PR-3a `migrate_evidence_text_encrypt.py`)
    MUST use this engine — NOT the main `engine` — for any long-running
    batch UPDATE / INSERT operation that would otherwise saturate the
    serving pool.
    """
    backfill_kwargs: dict = {}
    if SQLALCHEMY_DATABASE_URL.startswith("sqlite"):
        backfill_kwargs["connect_args"] = {"check_same_thread": False}
    elif "postgresql" in SQLALCHEMY_DATABASE_URL:
        backfill_kwargs["pool_size"] = 2
        backfill_kwargs["max_overflow"] = 0
        backfill_kwargs["pool_recycle"] = 3600
        backfill_kwargs["pool_pre_ping"] = True
        backfill_kwargs["pool_timeout"] = 30  # longer ; backfill is not latency-sensitive
        backfill_kwargs["connect_args"] = {
            "prepare_threshold": None,
            "options": "-c application_name=mint-backfill",
        }
    return create_engine(SQLALCHEMY_DATABASE_URL, **backfill_kwargs)
