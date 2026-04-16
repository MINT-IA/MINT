"""Tests for config.py fail-fast guards and new Settings fields.

Guards run at MODULE IMPORT TIME, so we use subprocess to test RuntimeError
scenarios (importlib.reload would also re-trigger guards in the current process).
"""

import json
import os
import subprocess
import sys

import pytest


PYTHON = sys.executable
BACKEND_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def _run_config_import(env_overrides: dict) -> subprocess.CompletedProcess:
    """Run a subprocess that imports config.py with given env vars."""
    env = {
        **os.environ,
        # Ensure clean state — remove vars that might interfere
        "ENVIRONMENT": "development",
        "DATABASE_URL": "sqlite:///./test.db",
        "JWT_SECRET_KEY": "test-secret-not-default",
        **env_overrides,
    }
    # Remove empty-string overrides that should be truly absent
    for k, v in list(env.items()):
        if v is None:
            del env[k]

    return subprocess.run(
        [
            PYTHON,
            "-c",
            "from app.core.config import settings; print('OK')",
        ],
        capture_output=True,
        text=True,
        cwd=BACKEND_DIR,
        env=env,
        timeout=30,
    )


class TestSQLiteFailFast:
    """P0-INFRA-1: SQLite must be rejected in staging/production."""

    def test_sqlite_failfast_raises_in_staging(self):
        result = _run_config_import({
            "ENVIRONMENT": "staging",
            "DATABASE_URL": "sqlite:///./test.db",
        })
        assert result.returncode != 0, "Should have crashed with RuntimeError"
        assert "DATABASE_URL must point to PostgreSQL" in result.stderr

    def test_sqlite_failfast_raises_in_production(self):
        result = _run_config_import({
            "ENVIRONMENT": "production",
            "DATABASE_URL": "sqlite:///./test.db",
        })
        assert result.returncode != 0, "Should have crashed with RuntimeError"
        assert "DATABASE_URL must point to PostgreSQL" in result.stderr

    def test_sqlite_failfast_ok_in_dev(self):
        result = _run_config_import({
            "ENVIRONMENT": "development",
            "DATABASE_URL": "sqlite:///./test.db",
        })
        assert result.returncode == 0, f"Should not crash in dev: {result.stderr}"
        assert "OK" in result.stdout

    def test_sqlite_failfast_ok_with_postgres(self):
        result = _run_config_import({
            "ENVIRONMENT": "staging",
            "DATABASE_URL": "postgresql://user:pass@host:5432/mintdb",
        })
        assert result.returncode == 0, f"Should not crash with postgres: {result.stderr}"
        assert "OK" in result.stdout


class TestOpenAIKeyWarning:
    """P1-INFRA-2: Missing OPENAI_API_KEY should produce a warning in staging."""

    def test_openai_key_warning_in_staging(self):
        result = _run_config_import({
            "ENVIRONMENT": "staging",
            "DATABASE_URL": "postgresql://user:pass@host:5432/mintdb",
            "OPENAI_API_KEY": "",
        })
        assert result.returncode == 0, f"Should not crash: {result.stderr}"
        assert "OPENAI_API_KEY not set" in result.stderr

    def test_openai_key_no_warning_when_set(self):
        result = _run_config_import({
            "ENVIRONMENT": "staging",
            "DATABASE_URL": "postgresql://user:pass@host:5432/mintdb",
            "OPENAI_API_KEY": "sk-test-key-12345",
        })
        assert result.returncode == 0, f"Should not crash: {result.stderr}"
        assert "OPENAI_API_KEY not set" not in result.stderr


class TestChromaDBPersistDir:
    """CHROMADB_PERSIST_DIR setting must be configurable via env var."""

    def test_chromadb_persist_dir_default(self):
        """Default value is 'data/chromadb'."""
        # Import directly — this runs in dev mode, no guards triggered
        import importlib
        from app.core import config

        # Save and clear env var if set
        original = os.environ.pop("CHROMADB_PERSIST_DIR", None)
        try:
            importlib.reload(config)
            assert config.settings.CHROMADB_PERSIST_DIR == "data/chromadb"
        finally:
            if original is not None:
                os.environ["CHROMADB_PERSIST_DIR"] = original

    def test_chromadb_persist_dir_from_env(self):
        """Env var overrides the default."""
        import importlib
        from app.core import config

        original = os.environ.get("CHROMADB_PERSIST_DIR")
        os.environ["CHROMADB_PERSIST_DIR"] = "/data/chromadb"
        try:
            importlib.reload(config)
            assert config.settings.CHROMADB_PERSIST_DIR == "/data/chromadb"
        finally:
            if original is not None:
                os.environ["CHROMADB_PERSIST_DIR"] = original
            else:
                os.environ.pop("CHROMADB_PERSIST_DIR", None)
