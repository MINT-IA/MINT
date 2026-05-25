"""Tests for `tools/checks/profile_safe_fields_parity.py`.

Phase mint-calc-engine-v1 Plan 19 / W4 — Concern C parity lint.

The server canonical `_PROFILE_SAFE_FIELDS` set lives in
`services/backend/app/api/v1/endpoints/coach_chat.py`. The Flutter side
sends a `profile_context` map literal at multiple call-sites
(coach_orchestrator.dart, coach_chat_api_service.dart, coach_narrative_service.dart,
coaching_service.dart). Drift = silent grounding gap (server drops unknown
fields ; Flutter omits fields the server expects).

The lint extracts both sides + asserts equality. These tests verify the
extraction + comparison primitives are correct.

Tests load `profile_safe_fields_parity` via importlib so they are
independent of the package path of the test runner.
"""
from __future__ import annotations

import importlib.util
import subprocess
import sys
from pathlib import Path

import pytest

_REPO_ROOT = Path(__file__).resolve().parents[3]
_LINT_PATH = _REPO_ROOT / "tools" / "checks" / "profile_safe_fields_parity.py"


def _load_lint_module():
    spec = importlib.util.spec_from_file_location(
        "profile_safe_fields_parity", _LINT_PATH
    )
    assert spec is not None and spec.loader is not None
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


# ---------------------------------------------------------------------------
# Server-side AST extraction
# ---------------------------------------------------------------------------


def test_lint_module_exposes_extract_server_fields(tmp_path):
    """Extractor walks an AST and returns a `set[str]` of string literals."""
    mod = _load_lint_module()
    assert hasattr(mod, "extract_server_fields")

    fixture = tmp_path / "fake_server.py"
    fixture.write_text(
        '_PROFILE_SAFE_FIELDS = {"canton", "age", "fri_total", "has_debt"}\n'
    )
    result = mod.extract_server_fields(fixture)
    assert result == {"canton", "age", "fri_total", "has_debt"}


def test_extract_server_fields_handles_multiline_set(tmp_path):
    """Multi-line set literal with trailing comma + comments is handled."""
    mod = _load_lint_module()
    fixture = tmp_path / "fake_server.py"
    fixture.write_text(
        "# leading comment\n"
        "_PROFILE_SAFE_FIELDS = {\n"
        '    "archetype", "age",  # required\n'
        '    "canton",\n'
        "    # group: lpp\n"
        '    "lpp_capital", "avoir_lpp",\n'
        "}\n"
    )
    result = mod.extract_server_fields(fixture)
    assert result == {"archetype", "age", "canton", "lpp_capital", "avoir_lpp"}


def test_extract_server_fields_real_coach_chat_py_has_canton_and_age():
    """Sanity check against the LIVE server file — top fields present."""
    mod = _load_lint_module()
    real = _REPO_ROOT / "services" / "backend" / "app" / "api" / "v1" / "endpoints" / "coach_chat.py"
    fields = mod.extract_server_fields(real)
    # These are universally expected to be in _PROFILE_SAFE_FIELDS forever ;
    # they're the most basic profile keys.
    assert "canton" in fields
    assert "age" in fields
    assert "archetype" in fields
    # Sanity bound — current canonical set has ≥30 fields ; <10 means the
    # AST extractor matched the wrong symbol.
    assert len(fields) >= 30, f"Expected ≥30 server fields, got {len(fields)}: {sorted(fields)}"


# ---------------------------------------------------------------------------
# Flutter-side regex extraction
# ---------------------------------------------------------------------------


def test_lint_module_exposes_extract_flutter_fields(tmp_path):
    """Flutter extractor returns set of string keys used in profileContext maps."""
    mod = _load_lint_module()
    assert hasattr(mod, "extract_flutter_fields")

    # Single call-site, single key
    fixture = tmp_path / "fake_orch.dart"
    fixture.write_text(
        "void foo() {\n"
        "  ragService.query(\n"
        "    profileContext: {\n"
        "      'canton': ctx.canton,\n"
        "      'age': ctx.age,\n"
        "      'fri_total': ctx.friTotal,\n"
        "    },\n"
        "  );\n"
        "}\n"
    )
    result = mod.extract_flutter_fields([fixture])
    assert result == {"canton", "age", "fri_total"}


def test_extract_flutter_fields_multiple_files(tmp_path):
    """Union of keys across multiple Dart files."""
    mod = _load_lint_module()
    f1 = tmp_path / "a.dart"
    f1.write_text(
        "profileContext: {\n"
        "  'canton': c,\n"
        "  'has_debt': h,\n"
        "}\n"
    )
    f2 = tmp_path / "b.dart"
    f2.write_text(
        "profileContext: {\n"
        "  'age': a,\n"
        "  'archetype': arch,\n"
        "}\n"
    )
    result = mod.extract_flutter_fields([f1, f2])
    assert result == {"canton", "has_debt", "age", "archetype"}


def test_extract_flutter_fields_ignores_keys_outside_profilecontext(tmp_path):
    """Only keys inside `profileContext: { ... }` blocks count.

    Other map literals (e.g. body, conversation_history) are ignored.
    """
    mod = _load_lint_module()
    fixture = tmp_path / "noise.dart"
    fixture.write_text(
        "final body = {\n"
        "  'message': msg,\n"
        "  'unrelated_key': 1,\n"
        "};\n"
        "ragService.query(\n"
        "  profileContext: {\n"
        "    'canton': c,\n"
        "  },\n"
        ");\n"
        "final other = {\n"
        "  'should_not_match': 1,\n"
        "};\n"
    )
    result = mod.extract_flutter_fields([fixture])
    assert result == {"canton"}


def test_extract_flutter_fields_reads_profile_context_helper_return_map(tmp_path):
    """Keys in helper-returned profileContext maps count as sent fields."""
    mod = _load_lint_module()
    fixture = tmp_path / "helper_return.dart"
    fixture.write_text(
        "static Map<String, dynamic> _buildProfileContext(CoachContext ctx) {\n"
        "  return {\n"
        "    'canton': ctx.canton,\n"
        "    'age': ctx.age,\n"
        "    'fri_total': ctx.friTotal,\n"
        "  };\n"
        "}\n"
        "final other = {\n"
        "  'should_not_match': 1,\n"
        "};\n"
    )
    result = mod.extract_flutter_fields([fixture])
    assert result == {"canton", "age", "fri_total"}


def test_extract_flutter_fields_reads_profile_context_helper_result_map(tmp_path):
    """Keys in typed result maps inside profileContext helpers count too."""
    mod = _load_lint_module()
    fixture = tmp_path / "helper_result.dart"
    fixture.write_text(
        "static Map<String, dynamic> _buildProfileContextImpl(Profile p) {\n"
        "  final result = <String, dynamic>{\n"
        "    'monthly_income': p.income,\n"
        "    'lpp_capital': p.lpp,\n"
        "  };\n"
        "  return result;\n"
        "}\n"
        "Map<String, dynamic> _buildOtherContext(Profile p) {\n"
        "  return {'should_not_match': p.value};\n"
        "}\n"
    )
    result = mod.extract_flutter_fields([fixture])
    assert result == {"monthly_income", "lpp_capital"}


def test_extract_flutter_fields_real_orchestrator_has_canton():
    """Sanity check against the LIVE Flutter orchestrator — top fields present."""
    mod = _load_lint_module()
    real = _REPO_ROOT / "apps" / "mobile" / "lib" / "services" / "coach" / "coach_orchestrator.dart"
    fields = mod.extract_flutter_fields([real])
    assert "canton" in fields
    assert "age" in fields
    assert "fri_total" in fields


# ---------------------------------------------------------------------------
# End-to-end CLI behaviour
# ---------------------------------------------------------------------------


def test_cli_exits_zero_when_in_sync(tmp_path, monkeypatch):
    """When server set == flutter set, lint exits 0 with OK message."""
    server_file = tmp_path / "server.py"
    server_file.write_text('_PROFILE_SAFE_FIELDS = {"canton", "age"}\n')
    dart_file = tmp_path / "client.dart"
    dart_file.write_text(
        "profileContext: {\n"
        "  'canton': c,\n"
        "  'age': a,\n"
        "}\n"
    )

    result = subprocess.run(
        [
            sys.executable,
            str(_LINT_PATH),
            "--server",
            str(server_file),
            "--flutter",
            str(dart_file),
        ],
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, f"stdout={result.stdout!r} stderr={result.stderr!r}"
    assert "parity" in result.stdout.lower() and "ok" in result.stdout.lower()


def test_cli_exits_nonzero_when_server_has_field_flutter_missing(tmp_path):
    """Server-only field → exit 1 + diff message identifying the missing key."""
    server_file = tmp_path / "server.py"
    server_file.write_text(
        '_PROFILE_SAFE_FIELDS = {"canton", "age", "lpp_capital"}\n'
    )
    dart_file = tmp_path / "client.dart"
    dart_file.write_text(
        "profileContext: {\n"
        "  'canton': c,\n"
        "  'age': a,\n"
        "}\n"
    )

    result = subprocess.run(
        [
            sys.executable,
            str(_LINT_PATH),
            "--server",
            str(server_file),
            "--flutter",
            str(dart_file),
        ],
        capture_output=True,
        text=True,
    )
    assert result.returncode == 1
    combined = result.stdout + result.stderr
    assert "lpp_capital" in combined
    # Actionable error message identifies which SIDE is missing the field.
    assert "flutter" in combined.lower() or "dart" in combined.lower()


def test_cli_exits_nonzero_when_flutter_has_field_server_missing(tmp_path):
    """Flutter-only field → exit 1 + diff message identifying the extra key."""
    server_file = tmp_path / "server.py"
    server_file.write_text('_PROFILE_SAFE_FIELDS = {"canton"}\n')
    dart_file = tmp_path / "client.dart"
    dart_file.write_text(
        "profileContext: {\n"
        "  'canton': c,\n"
        "  'rogue_field': r,\n"
        "}\n"
    )

    result = subprocess.run(
        [
            sys.executable,
            str(_LINT_PATH),
            "--server",
            str(server_file),
            "--flutter",
            str(dart_file),
        ],
        capture_output=True,
        text=True,
    )
    assert result.returncode == 1
    combined = result.stdout + result.stderr
    assert "rogue_field" in combined
    assert "server" in combined.lower()


def test_cli_empty_set_edge_case(tmp_path):
    """Both sides empty → exit 0 (vacuously in-sync)."""
    server_file = tmp_path / "server.py"
    server_file.write_text("_PROFILE_SAFE_FIELDS = set()\n")
    dart_file = tmp_path / "client.dart"
    dart_file.write_text("// no profileContext anywhere\n")

    result = subprocess.run(
        [
            sys.executable,
            str(_LINT_PATH),
            "--server",
            str(server_file),
            "--flutter",
            str(dart_file),
        ],
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, f"stdout={result.stdout!r} stderr={result.stderr!r}"
