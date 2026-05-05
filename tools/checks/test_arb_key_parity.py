#!/usr/bin/env python3
"""Phase 84 LANG-03 — unit tests for :mod:`tools.checks.arb_parity`.

Synthesises throwaway ARB fixtures inside ``tmp_path`` so tests never touch
the real ``apps/mobile/lib/l10n/`` files. Verifies:

* Equal key sets across 6 locales → exit 0, ``has_drift=False``.
* Missing key in one locale → exit 1 with that key in ``drift[locale]['missing']``.
* Extra key in one locale → exit 1 with that key in ``drift[locale]['extra']``.
* ``@@locale`` and ``@<key>`` metadata are parity-exempt.
* ``--baseline`` grandfathers known drift.
* ``--exit-code 0`` runs as warning-only.
* Real repo ARB files pass (smoke).

Run::

    python3 tools/checks/test_arb_key_parity.py
    # or
    python3 -m pytest tools/checks/test_arb_key_parity.py -v
"""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

import pytest

# Make the lint module importable without packaging.
_HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(_HERE))

from arb_parity import compute_parity, main, _load_snapshot  # noqa: E402


# ---------------------------------------------------------------------------
# Fixture helpers
# ---------------------------------------------------------------------------


_TEMPLATE_KEYS = {"hello": "Bonjour", "goodbye": "Au revoir", "yes": "Oui"}


def _write_arb(dir_path: Path, locale: str, content: dict) -> Path:
    payload = {"@@locale": locale, **content}
    p = dir_path / f"app_{locale}.arb"
    p.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    return p


def _make_full_set(dir_path: Path) -> None:
    """Six locales sharing the same key set."""
    for locale in ("fr", "en", "de", "it", "es", "pt"):
        _write_arb(dir_path, locale, _TEMPLATE_KEYS)


# ---------------------------------------------------------------------------
# Unit tests on compute_parity
# ---------------------------------------------------------------------------


def test_full_parity_no_drift(tmp_path):
    _make_full_set(tmp_path)
    snaps = [_load_snapshot(p) for p in sorted(tmp_path.glob("app_*.arb"))]
    report = compute_parity(snaps, reference="fr")
    assert not report.has_drift
    assert report.drift == {}


def test_missing_key_in_one_locale_is_flagged(tmp_path):
    _make_full_set(tmp_path)
    # Strip "yes" from German.
    de_path = tmp_path / "app_de.arb"
    payload = json.loads(de_path.read_text(encoding="utf-8"))
    del payload["yes"]
    de_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")

    snaps = [_load_snapshot(p) for p in sorted(tmp_path.glob("app_*.arb"))]
    report = compute_parity(snaps, reference="fr")
    assert report.has_drift
    assert "de" in report.drift
    assert "yes" in report.drift["de"]["missing"]
    assert report.drift["de"]["extra"] == []


def test_extra_key_in_one_locale_is_flagged(tmp_path):
    _make_full_set(tmp_path)
    en_path = tmp_path / "app_en.arb"
    payload = json.loads(en_path.read_text(encoding="utf-8"))
    payload["englishOnly"] = "Hello world"
    en_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")

    snaps = [_load_snapshot(p) for p in sorted(tmp_path.glob("app_*.arb"))]
    report = compute_parity(snaps, reference="fr")
    assert report.has_drift
    assert "en" in report.drift
    assert "englishOnly" in report.drift["en"]["extra"]
    assert report.drift["en"]["missing"] == []


def test_metadata_keys_are_parity_exempt(tmp_path):
    """@<key> entries (description metadata) are not part of content parity."""
    _make_full_set(tmp_path)
    fr_path = tmp_path / "app_fr.arb"
    payload = json.loads(fr_path.read_text(encoding="utf-8"))
    # Add metadata only to FR — should not trigger drift.
    payload["@hello"] = {"description": "FR-only metadata"}
    fr_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")

    snaps = [_load_snapshot(p) for p in sorted(tmp_path.glob("app_*.arb"))]
    report = compute_parity(snaps, reference="fr")
    assert not report.has_drift, (
        f"Metadata keys must be exempt from content parity, drift={report.drift}"
    )


def test_baseline_grandfathers_known_drift(tmp_path):
    _make_full_set(tmp_path)
    # Manually introduce drift on de.
    de_path = tmp_path / "app_de.arb"
    payload = json.loads(de_path.read_text(encoding="utf-8"))
    del payload["yes"]
    de_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")

    baseline = {"de": {"missing": ["yes"], "extra": []}}
    snaps = [_load_snapshot(p) for p in sorted(tmp_path.glob("app_*.arb"))]
    report = compute_parity(snaps, reference="fr", baseline=baseline)
    assert not report.has_drift
    assert "de" in report.grandfathered
    assert "yes" in report.grandfathered["de"]["missing"]


def test_baseline_does_not_swallow_new_drift(tmp_path):
    _make_full_set(tmp_path)
    de_path = tmp_path / "app_de.arb"
    payload = json.loads(de_path.read_text(encoding="utf-8"))
    del payload["yes"]
    del payload["hello"]  # NEW drift not in baseline
    de_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")

    baseline = {"de": {"missing": ["yes"], "extra": []}}
    snaps = [_load_snapshot(p) for p in sorted(tmp_path.glob("app_*.arb"))]
    report = compute_parity(snaps, reference="fr", baseline=baseline)
    assert report.has_drift
    assert "hello" in report.drift["de"]["missing"]
    assert "yes" not in report.drift["de"]["missing"]  # still grandfathered


# ---------------------------------------------------------------------------
# CLI tests via main()
# ---------------------------------------------------------------------------


def test_cli_exit_zero_when_clean(tmp_path, capsys):
    _make_full_set(tmp_path)
    rc = main(["--paths", str(tmp_path)])
    assert rc == 0
    captured = capsys.readouterr()
    assert "OK" in captured.out


def test_cli_exit_one_on_drift(tmp_path, capsys):
    _make_full_set(tmp_path)
    de_path = tmp_path / "app_de.arb"
    payload = json.loads(de_path.read_text(encoding="utf-8"))
    del payload["yes"]
    de_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")

    rc = main(["--paths", str(tmp_path)])
    assert rc == 1
    captured = capsys.readouterr()
    assert "DRIFT" in captured.err


def test_cli_warning_only_mode(tmp_path, capsys):
    """--exit-code 0 lets drift surface as a warning without failing the build."""
    _make_full_set(tmp_path)
    de_path = tmp_path / "app_de.arb"
    payload = json.loads(de_path.read_text(encoding="utf-8"))
    del payload["yes"]
    de_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")

    rc = main(["--paths", str(tmp_path), "--exit-code", "0"])
    assert rc == 0


def test_cli_json_output(tmp_path, capsys):
    _make_full_set(tmp_path)
    rc = main(["--paths", str(tmp_path), "--json"])
    assert rc == 0
    payload = json.loads(capsys.readouterr().out)
    assert payload["has_drift"] is False
    assert sorted(payload["locales"]) == ["de", "en", "es", "fr", "it", "pt"]


def test_cli_baseline_file_grandfathers(tmp_path, capsys):
    _make_full_set(tmp_path)
    de_path = tmp_path / "app_de.arb"
    payload = json.loads(de_path.read_text(encoding="utf-8"))
    del payload["yes"]
    de_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")

    baseline = tmp_path / "baseline.json"
    baseline.write_text(
        json.dumps({"de": {"missing": ["yes"], "extra": []}}),
        encoding="utf-8",
    )
    rc = main(["--paths", str(tmp_path), "--baseline", str(baseline)])
    assert rc == 0


# ---------------------------------------------------------------------------
# Repo smoke test — current 6 ARB files must pass.
# ---------------------------------------------------------------------------


def test_real_repo_arbs_currently_pass():
    """The Phase 84 baseline scan: live 6 ARBs should be in parity. If this
    starts failing, something genuinely drifted on dev — fix the locale,
    don't soften the gate."""
    repo_root = Path(__file__).resolve().parents[2]
    arb_dir = repo_root / "apps" / "mobile" / "lib" / "l10n"
    if not arb_dir.is_dir():
        pytest.skip("Not running inside a checkout of the MINT app")

    snaps = [_load_snapshot(p) for p in sorted(arb_dir.glob("app_*.arb"))]
    report = compute_parity(snaps, reference="fr")
    assert not report.has_drift, (
        f"Phase 84 baseline expected zero drift, got: {report.drift!r}"
    )


def test_arb_key_parity_shim_runs():
    """The REQ-spec'd alias path executes without error and returns 0."""
    repo_root = Path(__file__).resolve().parents[2]
    shim = repo_root / "tools" / "checks" / "arb_key_parity.py"
    assert shim.is_file(), f"shim missing: {shim}"
    proc = subprocess.run(
        [sys.executable, str(shim)],
        capture_output=True,
        text=True,
        cwd=str(repo_root),
        timeout=30,
    )
    assert proc.returncode == 0, (
        f"shim exited {proc.returncode}\nstdout:{proc.stdout}\nstderr:{proc.stderr}"
    )


if __name__ == "__main__":
    raise SystemExit(pytest.main([__file__, "-v"]))
