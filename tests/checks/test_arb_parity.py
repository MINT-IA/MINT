"""GUARD-05 pytest coverage — D-13 key + placeholder parity, Pitfall 3.

Covers Plan 34-04 validation matrix cases 34-04-01..04 (missing key, extra key,
placeholder type mismatch, baseline 6707 keys × 6 langs PASS) plus ICU
placeholder extraction edge cases (Pitfall 3 — plural/select/typed not
false-positive).

Technical English only (Pitfall 8 — tests must not fire accent_lint_fr against
themselves when staged on the lint's own diff).
"""
from __future__ import annotations

import json
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "checks"))

import arb_parity as lint  # noqa: E402


# ---------------------------------------------------------------------------
# check_parity() — end-to-end fixture scenarios (Validation Matrix 34-04-01..04)
# ---------------------------------------------------------------------------
def test_fixture_parity_pass_green(fixtures_dir: Path):
    """Wave 0 happy fixture: 6 langs share { hello, goodbye } + fr @hello."""
    rc, msgs = lint.check_parity(fixtures_dir / "arb_parity_pass")
    assert rc == 0, "expected pass on clean fixture; got messages: {}".format(msgs)


def test_fixture_missing_key_fail(fixtures_dir: Path):
    """34-04-01: `goodbye` exists in fr/en/es/it/pt but missing in de."""
    rc, msgs = lint.check_parity(fixtures_dir / "arb_drift_missing")
    assert rc == 1
    joined = "\n".join(msgs)
    assert "goodbye" in joined, (
        "expected 'goodbye' key mentioned in failure output; got: {}".format(joined)
    )
    assert "app_de.arb" in joined, (
        "expected 'app_de.arb' mentioned; got: {}".format(joined)
    )


def test_fixture_extra_key_fail(tmp_path: Path):
    """34-04-02: key present only in it — must fail on fr + others missing it."""
    langs = {
        "fr": {"@@locale": "fr", "hello": "Bonjour"},
        "en": {"@@locale": "en", "hello": "Hello"},
        "de": {"@@locale": "de", "hello": "Hallo"},
        "es": {"@@locale": "es", "hello": "Hola"},
        "it": {"@@locale": "it", "hello": "Ciao", "extra_it_only": "soltanto"},
        "pt": {"@@locale": "pt", "hello": "Ola"},
    }
    for code, content in langs.items():
        (tmp_path / "app_{}.arb".format(code)).write_text(
            json.dumps(content), encoding="utf-8"
        )
    rc, msgs = lint.check_parity(tmp_path)
    assert rc == 1
    joined = "\n".join(msgs)
    assert "extra_it_only" in joined, (
        "expected extra key mentioned on the non-it side; got: {}".format(joined)
    )


def test_fixture_placeholder_drift_fail(tmp_path: Path):
    """34-04-03: fr declares {name}, en uses {n} -> placeholder drift fails."""
    fr_content = {
        "@@locale": "fr",
        "welcome": "Bienvenue {name}",
        "@welcome": {"placeholders": {"name": {"type": "String"}}},
    }
    en_content = {"@@locale": "en", "welcome": "Welcome {n}"}
    other = lambda code: {"@@locale": code, "welcome": "ok {name}"}
    (tmp_path / "app_fr.arb").write_text(json.dumps(fr_content), encoding="utf-8")
    (tmp_path / "app_en.arb").write_text(json.dumps(en_content), encoding="utf-8")
    for code in ("de", "es", "it", "pt"):
        (tmp_path / "app_{}.arb".format(code)).write_text(
            json.dumps(other(code)), encoding="utf-8"
        )
    rc, msgs = lint.check_parity(tmp_path)
    assert rc == 1
    joined = "\n".join(msgs)
    assert "welcome" in joined and "app_en.arb" in joined, (
        "expected welcome placeholder drift in app_en.arb; got: {}".format(joined)
    )


# ---------------------------------------------------------------------------
# extract_placeholders() — ICU name extraction (Pitfall 3 regression guards)
# ---------------------------------------------------------------------------
def test_extract_placeholders_simple():
    assert lint.extract_placeholders("Bonjour {name}") == {"name"}


def test_extract_placeholders_plural():
    """Plural keyword filtered; `item`/`items` are literals, not names.
    Inner `{count}` re-uses outer placeholder -> dedupes via set semantics.
    """
    result = lint.extract_placeholders(
        "{count, plural, one {1 item} other {{count} items}}"
    )
    assert result == {"count"}, "expected {{'count'}}, got {}".format(result)


def test_extract_placeholders_select():
    result = lint.extract_placeholders(
        "{sex, select, male {il} female {elle} other {iel}}"
    )
    assert result == {"sex"}, "expected {{'sex'}}, got {}".format(result)


def test_extract_placeholders_typed():
    result = lint.extract_placeholders("{amount, number, currency}")
    assert result == {"amount"}, "expected {{'amount'}}, got {}".format(result)


def test_extract_placeholders_multiple():
    assert lint.extract_placeholders("{a} and {b}") == {"a", "b"}


def test_extract_placeholders_empty():
    assert lint.extract_placeholders("no placeholders here") == set()


def test_extract_placeholders_datetime():
    """RESEARCH Pattern 4 table row 5 — DateTime form."""
    assert lint.extract_placeholders("{timestamp, DateTime, yMd}") == {"timestamp"}


# ---------------------------------------------------------------------------
# Baseline integration (34-04-04) — the big one
# ---------------------------------------------------------------------------
def test_production_arb_files_parity():
    """Baseline: current apps/mobile/lib/l10n/ must PASS today.

    If this fails the team has introduced an ARB drift PRE-Phase-34. RESEARCH
    §ARB Parity Baseline (lines 388-410) empirically verified 6707 keys × 6
    langs = clean.
    """
    prod_dir = ROOT / "apps" / "mobile" / "lib" / "l10n"
    rc, msgs = lint.check_parity(prod_dir)
    if rc != 0:
        print("\n".join(msgs))
    assert rc == 0, (
        "Production ARB files must be parity-clean at start of Phase 34. "
        "If this fails, land a pre-Phase-34 backfill PR first."
    )


def test_main_missing_file_fails_gracefully(tmp_path: Path):
    """Defensive: missing a lang file -> return code 1 with readable message."""
    # Only write 5 files, omit de.
    for code in ("fr", "en", "es", "it", "pt"):
        (tmp_path / "app_{}.arb".format(code)).write_text(
            json.dumps({"@@locale": code, "k": "v"}), encoding="utf-8"
        )
    rc, msgs = lint.check_parity(tmp_path)
    assert rc == 1
    joined = "\n".join(msgs)
    assert "app_de.arb" in joined, (
        "expected missing-file diagnostic to name app_de.arb; got: {}".format(joined)
    )


def test_main_malformed_json_fails_gracefully(tmp_path: Path):
    """Defensive: malformed JSON -> return code 1 with file-path diagnostic."""
    (tmp_path / "app_fr.arb").write_text("{not valid json", encoding="utf-8")
    for code in ("en", "de", "es", "it", "pt"):
        (tmp_path / "app_{}.arb".format(code)).write_text(
            json.dumps({"@@locale": code}), encoding="utf-8"
        )
    rc, msgs = lint.check_parity(tmp_path)
    assert rc == 1
    joined = "\n".join(msgs)
    assert "app_fr.arb" in joined, (
        "expected malformed-JSON diagnostic to name app_fr.arb; got: {}".format(joined)
    )
