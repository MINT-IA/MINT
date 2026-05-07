"""
Test configuration and fixtures.
"""

import os
from unittest.mock import MagicMock

# Disable rate limiting in tests
os.environ["TESTING"] = "1"

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from app.main import app
from app.core.auth import get_current_user, require_current_user
from app.core.database import Base, get_db


def _fake_user():
    """Return a mock user for auth dependency override in tests."""
    from datetime import datetime
    user = MagicMock()
    user.id = "test-user-id"
    user.email = "test@mint.ch"
    user.display_name = "Test User"
    user.created_at = datetime(2025, 1, 1)
    return user

# Create in-memory SQLite database for tests with StaticPool
# StaticPool ensures all connections use the same in-memory database
SQLALCHEMY_TEST_DATABASE_URL = "sqlite:///:memory:"

engine = create_engine(
    SQLALCHEMY_TEST_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,  # Use StaticPool to share in-memory database across connections
)

TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def override_get_db():
    """Override database dependency for tests."""
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()


# Create tables once at module level
@pytest.fixture(scope="session", autouse=True)
def setup_test_database():
    """Create database tables once for all tests."""
    # Import models to ensure they're registered with SQLAlchemy before create_all
    import app.models.user  # noqa: F401
    import app.models  # noqa: F401
    from app.models.banking_consent import BankingConsentModel  # noqa: F401
    from app.models.external_data_source import ExternalDataSourceModel  # noqa: F401
    from app.models.token_blacklist import TokenBlacklist  # noqa: F401
    from app.models.document import DocumentModel  # noqa: F401

    Base.metadata.create_all(bind=engine)
    yield
    Base.metadata.drop_all(bind=engine)


@pytest.fixture(scope="function", autouse=True)
def clean_database():
    """Clean all tables before each test."""
    # Delete all data from tables before each test
    from app.models import (
        AnalyticsEvent,
        SessionModel,
        ProfileModel,
        User,
        LoginSecurityStateModel,
        PasswordResetTokenModel,
        EmailVerificationTokenModel,
        SubscriptionModel,
        EntitlementModel,
        BillingTransactionModel,
        BillingWebhookEventModel,
        AuditEventModel,
        HouseholdModel,
        HouseholdMemberModel,
        AdminAuditEventModel,
        SnapshotModel,
        ConsentModel,
    )
    from app.models.banking_consent import BankingConsentModel
    from app.models.external_data_source import ExternalDataSourceModel
    from app.models.token_blacklist import TokenBlacklist
    from app.models.document import DocumentModel  # noqa: F811
    from app.models.scenario import ScenarioModel
    db = TestingSessionLocal()
    try:
        db.query(ScenarioModel).delete()
        db.query(DocumentModel).delete()
        db.query(TokenBlacklist).delete()
        db.query(ExternalDataSourceModel).delete()
        db.query(BankingConsentModel).delete()
        db.query(SnapshotModel).delete()
        db.query(ConsentModel).delete()
        db.query(BillingWebhookEventModel).delete()
        db.query(EmailVerificationTokenModel).delete()
        db.query(PasswordResetTokenModel).delete()
        db.query(LoginSecurityStateModel).delete()
        db.query(AdminAuditEventModel).delete()
        db.query(AuditEventModel).delete()
        db.query(BillingTransactionModel).delete()
        db.query(EntitlementModel).delete()
        db.query(SubscriptionModel).delete()
        db.query(HouseholdMemberModel).delete()
        db.query(HouseholdModel).delete()
        db.query(AnalyticsEvent).delete()
        db.query(SessionModel).delete()
        db.query(ProfileModel).delete()
        db.query(User).delete()
        db.commit()
    finally:
        db.close()


@pytest.fixture
def client():
    """Test client with test database and auth override."""
    # Override the database and auth dependencies
    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[require_current_user] = _fake_user
    app.dependency_overrides[get_current_user] = _fake_user

    with TestClient(app) as test_client:
        yield test_client

    # Clean up
    app.dependency_overrides.clear()


# ---------------------------------------------------------------------------
# Phase 95 Plan 95-03 / TEST-04 — testcontainers-Postgres opt-in fixtures.
#
# Additive only: nothing above this line is touched. Tests opt in via
#     pytestmark = pytest.mark.postgres
# AND by requesting `pg_engine` / `pg_db` explicitly. Tests that don't ask
# for those fixtures keep using the in-memory SQLite path.
#
# Local dev: needs Docker Desktop running. When Docker is unavailable
# (CI without DinD, local laptop without Docker) the fixture skips with a
# clear reason — never raises (Karpathy 3 / surgical: keep the SQLite
# fast-path green for the 99% of tests that don't need Postgres).
#
# CI: the .github/workflows/ci.yml `alembic-check` job uses a sidecar
# `services: postgres` container instead of testcontainers (managed by
# GH Actions, faster than Docker-from-pytest in the runner). Both code
# paths converge on `DATABASE_URL` / SQLAlchemy create_engine.
# ---------------------------------------------------------------------------


def _external_postgres_url():
    """Return DATABASE_URL if it already points at a Postgres instance.

    Returns ``str`` when an external Postgres URL is configured, ``None``
    otherwise.

    CI runs the `alembic-check` job with a `services: postgres` sidecar
    and exports DATABASE_URL up-front; in that case we reuse the sidecar
    instead of spinning a second container via testcontainers (avoids
    Docker-in-Docker complications + halves the test runtime).
    """
    import os

    url = os.environ.get("DATABASE_URL")
    if url and url.startswith(("postgresql://", "postgresql+psycopg2://", "postgres://")):
        return url
    return None


@pytest.fixture(scope="session")
def postgres_container():
    """Spin up a fresh `postgres:15-alpine` container per pytest session.

    Two code paths converge on the same `pg_engine` URL contract:
      1. CI (alembic-check job) — DATABASE_URL already points at the
         GH Actions Postgres sidecar; we yield a tiny shim object so
         pg_engine reads `.get_connection_url()` without spawning a
         second Docker container.
      2. Local dev — testcontainers spawns postgres:15-alpine via
         Docker. Skips with a clear reason if Docker is not reachable
         (no daemon, no socket, permission denied) so non-Postgres
         tests on a Docker-less laptop still run green.
    """
    external_url = _external_postgres_url()
    if external_url is not None:
        # CI sidecar path — no Docker spawn.
        class _ExternalPg:
            def get_connection_url(self) -> str:
                return external_url

        yield _ExternalPg()
        return

    try:
        # Defer import so the dev dep is only required when the fixture
        # is actually requested. Tests that never ask for `pg_*` don't
        # pay the import cost (or the install cost, since the suite
        # tolerates `testcontainers` being absent in minimal envs).
        from testcontainers.postgres import PostgresContainer
    except ImportError as exc:  # pragma: no cover - dev-extras-not-installed branch
        pytest.skip(
            f"testcontainers[postgres] not installed: {exc}. "
            "Install with `pip install -e .[dev]` from services/backend/."
        )

    try:
        import docker  # type: ignore  # transitive dep of testcontainers

        # Cheap probe — raises DockerException if the daemon is unreachable.
        docker.from_env().ping()
    except Exception as exc:  # pragma: no cover - non-Docker dev laptops
        pytest.skip(f"Docker unavailable, skipping Postgres fixture: {exc}")

    pg = PostgresContainer("postgres:15-alpine")
    pg.start()
    try:
        yield pg
    finally:
        # Container teardown: log + rethrow on failure (never silently
        # swallow per CLAUDE.md / no-bare-catches discipline).
        try:
            pg.stop()
        except Exception:
            import logging

            logging.exception(
                "[Phase95/TEST-04] PostgresContainer teardown failed; "
                "container may be left running. Manual cleanup may be needed."
            )
            raise


@pytest.fixture(scope="session")
def pg_engine(postgres_container):
    """Session-scoped SQLAlchemy engine bound to the Postgres container.

    Runs `alembic upgrade head` once per session so the schema is at
    HEAD before any opt-in test executes. Tests that need to walk the
    full ladder (forward/rollback/check) call alembic.command.* directly
    against this engine — see test_alembic_full_chain.py.
    """
    from sqlalchemy import create_engine

    url = postgres_container.get_connection_url()
    eng = create_engine(url, future=True)

    # Run alembic upgrade head once per session, with DATABASE_URL pointing
    # at the testcontainers instance so env.py picks up the right URL.
    import os

    from alembic import command
    from alembic.config import Config

    backend_dir = os.path.abspath(
        os.path.join(os.path.dirname(__file__), os.pardir)
    )
    cfg = Config(os.path.join(backend_dir, "alembic.ini"))
    # alembic.ini lives in services/backend; script_location is relative
    # to %(here)s so it already resolves correctly when we point Config
    # at the absolute path above.
    cfg.set_main_option("sqlalchemy.url", url)

    prev_db_url = os.environ.get("DATABASE_URL")
    os.environ["DATABASE_URL"] = url
    try:
        command.upgrade(cfg, "head")
    finally:
        if prev_db_url is None:
            os.environ.pop("DATABASE_URL", None)
        else:
            os.environ["DATABASE_URL"] = prev_db_url

    try:
        yield eng
    finally:
        eng.dispose()


@pytest.fixture(scope="function")
def pg_db(pg_engine):
    """Per-test session bound to the testcontainers-Postgres engine.

    Wraps the test in an outer transaction + SAVEPOINT and rolls back
    on teardown so each test sees a clean slate without paying for a
    full `drop_all + create_all` cycle (too slow on Postgres).
    """
    from sqlalchemy.orm import sessionmaker

    connection = pg_engine.connect()
    transaction = connection.begin()
    SessionPg = sessionmaker(bind=connection, autocommit=False, autoflush=False)
    session = SessionPg()
    try:
        yield session
    finally:
        session.close()
        try:
            transaction.rollback()
        finally:
            connection.close()


# ---------------------------------------------------------------------------
# Phase 95 Plan 95-04 / TEST-05 — VCR cassettes for Anthropic LLM calls.
#
# Additive only: nothing above this line is touched. Tests opt in via
#     @pytest.mark.vcr_anthropic
# AND get redacted recording / replay through the `vcr_config` fixture
# below. Tests that don't carry the marker keep using the existing
# fixtures (in-memory SQLite or testcontainers-Postgres) untouched.
#
# Redact contract (defense-in-depth, doctrine 2026-05-06 §7 ship-gate):
#   1. `filter_headers` — auth + API-key headers replaced with REDACTED
#      BEFORE the cassette is written to disk.
#   2. `before_record_response` — recursively walks the JSON body and
#      runs `pii_scrubber.scrub` on every string leaf. Strips Set-Cookie
#      + request-id + sentry-trace + baggage headers entirely.
#   3. `tools/checks/cassette_hygiene_lint.py` — repo-level regex gate
#      that blocks commits leaking JWTs / Anthropic keys / IBAN / AVS
#      / banned terms regardless of (1) and (2). The lint is the
#      authoritative ship-gate; the fixture hooks are belt-and-suspenders.
#
# pii_scrubber lives at app.services.privacy.pii_scrubber (Phase 29-06,
# PRIV-07). The plan text mentioned app.utils.pii_scrubber — actual
# import path corrected here per the working tree (Karpathy 1: state
# the assumption; the SOT is the codebase, not the plan text).
#
# Recording protocol (executor / future contributors):
#     VCR_RECORD_MODE=once \
#         python -m pytest tests/test_anthropic_vcr_smoke.py \
#                          -m vcr_anthropic
# Replay default (CI):
#     python -m pytest tests/test_anthropic_vcr_smoke.py -m vcr_anthropic
# Nightly rewrite (DISABLED at ship — see .github/workflows/
# vcr_nightly_rewrite.yml ACTIVATION RUNBOOK).
# ---------------------------------------------------------------------------


def _vcr_scrub_pii(value):  # pragma: no cover - exercised via vcr replay
    """Best-effort PII scrub on string leaves of a recorded response body.

    Lazy-imports `pii_scrubber` so the scrubber only loads when a VCR
    test is actually exercised (avoids paying the Presidio import cost
    in the SQLite-only fast path). Falls back to identity on import
    failure with a logged warning — VCR redaction must never silently
    drop a recording, but it must also never break replay because of
    an optional dep gap on a contributor laptop.

    Per CLAUDE.md no-bare-catches: ImportError is logged and rethrown
    on the recording path (where the scrubber must work) and swallowed
    only on the replay path (where redaction already happened at
    record-time). The `recording` flag is sourced from VCR_RECORD_MODE.
    """
    if not isinstance(value, str) or not value:
        return value
    import os
    try:
        from app.services.privacy.pii_scrubber import scrub
    except ImportError as exc:
        import logging
        recording_mode = os.environ.get("VCR_RECORD_MODE", "none")
        if recording_mode in {"once", "all", "new_episodes"}:
            logging.exception(
                "[Phase95/TEST-05] pii_scrubber unavailable while RECORDING "
                "VCR cassette (VCR_RECORD_MODE=%s). Refusing to write an "
                "unscrubbed cassette to disk.",
                recording_mode,
            )
            raise
        logging.debug("pii_scrubber unavailable on replay path: %s", exc)
        return value
    return scrub(value)


def _vcr_scrub_obj(obj):  # pragma: no cover - exercised via vcr replay
    """Recursively scrub PII out of a decoded JSON value.

    Walks dict / list / tuple containers; runs `_vcr_scrub_pii` on every
    string leaf. Non-string scalars (int / float / bool / None) pass
    through untouched — Anthropic API responses encode all PII as
    strings inside `content[*].text` / `system` / `messages[*].content`
    so this scope is sufficient.
    """
    if isinstance(obj, str):
        return _vcr_scrub_pii(obj)
    if isinstance(obj, dict):
        return {k: _vcr_scrub_obj(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [_vcr_scrub_obj(v) for v in obj]
    if isinstance(obj, tuple):
        return tuple(_vcr_scrub_obj(v) for v in obj)
    return obj


def _vcr_before_record_response(response):  # pragma: no cover - vcr hook
    """VCR hook: scrub PII + drop ephemeral headers BEFORE writing cassette.

    1. Drop Set-Cookie / request-id / sentry-trace / baggage headers
       entirely (no value should ever land in the cassette).
    2. Decode the response body as JSON (Anthropic always returns
       application/json), recursively scrub string leaves, re-encode.
    3. If the body is not JSON, leave it unchanged — the hygiene lint
       still runs at the repo level so any plain-text leak is caught
       at PR time.
    """
    import json
    import logging

    headers = response.get("headers") or {}
    drop_keys = {
        "set-cookie", "Set-Cookie",
        "request-id", "Request-Id", "x-request-id", "X-Request-Id",
        "sentry-trace", "Sentry-Trace",
        "baggage", "Baggage",
    }
    for key in list(headers.keys()):
        if key in drop_keys or key.lower() in drop_keys:
            headers.pop(key, None)
    response["headers"] = headers

    body = response.get("body", {})
    raw = body.get("string") if isinstance(body, dict) else None
    if isinstance(raw, (bytes, bytearray)):
        try:
            decoded = raw.decode("utf-8")
        except UnicodeDecodeError as exc:
            logging.warning(
                "[Phase95/TEST-05] cassette body not utf-8 (%s); "
                "leaving untouched, hygiene lint must catch any leak.",
                exc,
            )
            return response
    elif isinstance(raw, str):
        decoded = raw
    else:
        return response

    try:
        parsed = json.loads(decoded)
    except (ValueError, TypeError):
        # Not JSON; leave as-is. Lint catches plain-text leaks downstream.
        return response

    scrubbed = _vcr_scrub_obj(parsed)
    re_encoded = json.dumps(scrubbed, ensure_ascii=False)
    if isinstance(raw, (bytes, bytearray)):
        body["string"] = re_encoded.encode("utf-8")
    else:
        body["string"] = re_encoded
    response["body"] = body
    return response


@pytest.fixture(scope="module")
def vcr_config():
    """pytest-recording configuration for VCR_anthropic-marked tests.

    Single source of redact rules (vs per-test repetition) — mirrors the
    `setup_test_database` shared-fixture pattern. Module-scoped so a
    test module re-recording its cassettes doesn't redo header
    filter setup on every test function.

    Returns a dict consumed by `pytest-recording` to construct the
    underlying `vcrpy.VCR` instance. Reference:
    https://pytest-recording.readthedocs.io/en/latest/#vcr-configuration
    """
    return {
        "filter_headers": [
            ("authorization", "REDACTED"),
            ("Authorization", "REDACTED"),
            ("x-api-key", "REDACTED"),
            ("X-Api-Key", "REDACTED"),
            ("anthropic-api-key", "REDACTED"),
            ("Anthropic-Api-Key", "REDACTED"),
            ("anthropic-version", "REDACTED"),
            ("Anthropic-Version", "REDACTED"),
            ("x-anonymous-session", "REDACTED"),
            ("X-Anonymous-Session", "REDACTED"),
            ("cookie", "REDACTED"),
            ("Cookie", "REDACTED"),
            ("set-cookie", "REDACTED"),
            ("Set-Cookie", "REDACTED"),
        ],
        "filter_query_parameters": [
            ("api_key", "REDACTED"),
            ("apikey", "REDACTED"),
            ("token", "REDACTED"),
        ],
        "before_record_response": _vcr_before_record_response,
        "decode_compressed_response": True,
        "match_on": ["method", "scheme", "host", "port", "path", "query"],
    }
