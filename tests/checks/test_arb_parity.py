"""Phase 34 GUARD-05 — pytest for ARB parity lint.

Exercises `tools/checks/arb_parity.py` against:
  1. The live `apps/mobile/lib/l10n/*.arb` (pristine HEAD — must exit 0,
     6 × 6747 keys parity).
  2. Synthetic ARBs in tmp_path with intentional drift — must exit 1.
  3. Single-locale mode (`--locale en`).
  4. Malformed JSON — must exit 2.
  5. Missing locale file — must exit 2.

Python 3.9-compatible, stdlib-only (matches the lint's own constraint).
"""
from __future__ import annotations

import json
import os
import stat
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
LINT = REPO_ROOT / "tools" / "checks" / "arb_parity.py"
LIVE_ARB_DIR = REPO_ROOT / "apps" / "mobile" / "lib" / "l10n"


def _run(args, timeout=30):
    return subprocess.run(
        [sys.executable, str(LINT)] + list(args),
        capture_output=True,
        text=True,
        cwd=str(REPO_ROOT),
        timeout=timeout,
    )


def _write_arbs(arb_dir: Path, keys_by_locale: dict) -> None:
    arb_dir.mkdir(parents=True, exist_ok=True)
    for locale, keys in keys_by_locale.items():
        body = {k: f"value-{locale}-{i}" for i, k in enumerate(sorted(keys))}
        body["@@locale"] = locale  # metadata key, excluded by the lint
        (arb_dir / f"app_{locale}.arb").write_text(
            json.dumps(body, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )


def test_lint_exists_and_executable():
    assert LINT.exists(), f"lint script missing: {LINT}"
    mode = LINT.stat().st_mode
    assert mode & stat.S_IXUSR, f"lint not executable: {LINT} mode={oct(mode)}"


def test_live_arbs_parity_clean():
    """Pristine HEAD — 6 ARB files must be in parity (6747 keys each as of W1)."""
    r = _run([])
    assert r.returncode == 0, (
        f"live ARB parity failed (expected 0, got {r.returncode}):\n"
        f"stdout:\n{r.stdout}\nstderr:\n{r.stderr}"
    )
    assert "OK" in r.stdout
    assert "parity" in r.stdout


def test_drift_detected_exit_1(tmp_path: Path):
    """Synthetic ARBs with one missing key must exit 1."""
    full = {"a", "b", "c"}
    keys = {l: full for l in ("fr", "en", "de", "es", "it", "pt")}
    keys["en"] = {"a", "b"}  # `c` missing in en
    _write_arbs(tmp_path, keys)
    r = _run(["--arb-dir", str(tmp_path)])
    assert r.returncode == 1, (
        f"expected exit 1 for drift, got {r.returncode}:\n"
        f"stdout:\n{r.stdout}\nstderr:\n{r.stderr}"
    )
    assert "drift" in r.stderr.lower()
    assert "[en]" in r.stderr


def test_extra_key_in_one_locale_is_drift(tmp_path: Path):
    """If a non-FR locale has a key FR doesn't — that's drift too."""
    full = {"a", "b"}
    keys = {l: full for l in ("fr", "en", "de", "es", "it", "pt")}
    keys["de"] = {"a", "b", "ghost_de_key"}
    _write_arbs(tmp_path, keys)
    r = _run(["--arb-dir", str(tmp_path)])
    assert r.returncode == 1
    assert "[de]" in r.stderr
    assert "extra" in r.stderr.lower()


def test_locale_filter_single(tmp_path: Path):
    """`--locale en` checks only EN against FR even if other locales drift."""
    full = {"a", "b"}
    keys = {l: full for l in ("fr", "en", "de", "es", "it", "pt")}
    keys["de"] = {"a"}  # de drifts but we only check en
    _write_arbs(tmp_path, keys)
    r = _run(["--arb-dir", str(tmp_path), "--locale", "en"])
    assert r.returncode == 0, (
        f"expected 0 (en is clean, de drift ignored), got {r.returncode}:\n"
        f"stdout:\n{r.stdout}\nstderr:\n{r.stderr}"
    )


def test_metadata_keys_excluded(tmp_path: Path):
    """`@`-prefixed and `_`-prefixed keys must not count toward parity."""
    arb_dir = tmp_path
    arb_dir.mkdir(exist_ok=True)
    base = {"a": "v", "b": "v", "@@locale": "fr"}
    fr = {**base, "@a": {"description": "fr only meta"}, "_internal_note": "skip me"}
    other = {**base, "@@locale": "en"}  # no @a or _internal_note
    (arb_dir / "app_fr.arb").write_text(json.dumps(fr), encoding="utf-8")
    for loc in ("en", "de", "es", "it", "pt"):
        body = dict(other)
        body["@@locale"] = loc
        (arb_dir / f"app_{loc}.arb").write_text(json.dumps(body), encoding="utf-8")
    r = _run(["--arb-dir", str(arb_dir)])
    assert r.returncode == 0, (
        f"metadata-only diff should NOT cause drift; got {r.returncode}:\n"
        f"stdout:\n{r.stdout}\nstderr:\n{r.stderr}"
    )


def test_malformed_json_exit_2(tmp_path: Path):
    arb_dir = tmp_path
    arb_dir.mkdir(exist_ok=True)
    full = {"a": "v"}
    for loc in ("en", "de", "es", "it", "pt"):
        (arb_dir / f"app_{loc}.arb").write_text(json.dumps(full), encoding="utf-8")
    (arb_dir / "app_fr.arb").write_text("{not json", encoding="utf-8")
    r = _run(["--arb-dir", str(arb_dir)])
    assert r.returncode == 2, f"expected 2 for malformed JSON, got {r.returncode}"
    assert "malformed" in r.stderr.lower()


def test_missing_locale_file_exit_2(tmp_path: Path):
    arb_dir = tmp_path
    arb_dir.mkdir(exist_ok=True)
    full = {"a": "v"}
    for loc in ("fr", "en", "de", "es", "it"):  # `pt` missing
        (arb_dir / f"app_{loc}.arb").write_text(json.dumps(full), encoding="utf-8")
    r = _run(["--arb-dir", str(arb_dir)])
    assert r.returncode == 2
    assert "missing" in r.stderr.lower()


def test_no_lsfin_banned_terms_in_lint_output():
    """The lint itself must not emit LSFin-banned vocab in its stderr/stdout."""
    r = _run([])
    combined = (r.stdout + r.stderr).lower()
    for banned in ("garanti", "guaranteed", "garantiert", "garantizado"):
        assert banned not in combined, f"banned term {banned!r} leaked into lint output"
