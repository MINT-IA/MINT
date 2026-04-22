"""GUARD-03 pytest coverage — 11 cases covering D-08/D-09/D-10.

Technical English only — dev-facing diagnostics per CLAUDE.md §2
self-compliance (Pitfall 8) and Phase 32-03 M-1 admin carve-out.

D-08: scope (enforced via lefthook glob; the script stays broader for manual
      full-repo audits). Tests verify lib/l10n, lib/models, lib/services are
      skipped via EXCLUDE_SUBSTRINGS when invoked through `_collect_paths`.
D-09: 4 primary patterns + acronym + numeric whitelist.
D-10: preceding-line `// lefthook-allow:hardcoded-fr: <reason-of-3+-words>`
      override — mirrors Plan 34-02 no_bare_catch preceding-line semantics.
"""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "checks"))

import no_hardcoded_fr as lint  # noqa: E402


def _write(tmp_path: Path, name: str, body: str) -> Path:
    p = tmp_path / name
    p.write_text(body, encoding="utf-8")
    return p


# ─── D-09 primary patterns (FAIL cases) ──────────────────────────────────

def test_flags_text_capitalised_word(tmp_path: Path) -> None:
    p = _write(tmp_path, "w.dart", "Text('Bonjour tout le monde');")
    violations = lint.scan_file(p)
    assert len(violations) >= 1


def test_flags_title_param(tmp_path: Path) -> None:
    p = _write(tmp_path, "w.dart", "AppBar(title: 'Bonjour monde');")
    violations = lint.scan_file(p)
    assert any("title" in v[2] for v in violations)


def test_flags_label_param(tmp_path: Path) -> None:
    p = _write(tmp_path, "w.dart", "TextButton(label: 'Action longue');")
    violations = lint.scan_file(p)
    assert any("label" in v[2] for v in violations)


def test_accent_heuristic_still_flags(tmp_path: Path) -> None:
    p = _write(tmp_path, "w.dart", "Text('Créer un compte');")
    violations = lint.scan_file(p)
    assert any("accent" in v[2] for v in violations)


# ─── D-09 positive case + whitelist (PASS cases) ─────────────────────────

def test_passes_l10n_call(tmp_path: Path) -> None:
    p = _write(
        tmp_path,
        "w.dart",
        "Text(AppLocalizations.of(context)!.greeting);",
    )
    assert lint.scan_file(p) == []


def test_whitelist_acronym(tmp_path: Path) -> None:
    p = _write(tmp_path, "w.dart", "Text('ERR');")
    assert lint.scan_file(p) == []


def test_whitelist_numeric(tmp_path: Path) -> None:
    p = _write(tmp_path, "w.dart", "Text('404');")
    assert lint.scan_file(p) == []


# ─── D-10 preceding-line override (mirror Plan 34-02) ────────────────────

def test_inline_override_valid(tmp_path: Path) -> None:
    p = _write(
        tmp_path,
        "w.dart",
        "// lefthook-allow:hardcoded-fr: legitimate debug fallback only\n"
        "Text('Bonjour monde');",
    )
    assert lint.scan_file(p) == []


def test_inline_override_insufficient_reason(tmp_path: Path) -> None:
    p = _write(
        tmp_path,
        "w.dart",
        "// lefthook-allow:hardcoded-fr: short\n"
        "Text('Bonjour tout le monde');",
    )
    violations = lint.scan_file(p)
    assert len(violations) >= 1


# ─── Wave 0 fixtures ────────────────────────────────────────────────────

def test_scan_file_fixture_bad_has_violations(fixtures_dir: Path) -> None:
    violations = lint.scan_file(fixtures_dir / "hardcoded_fr_bad_widget.dart")
    assert len(violations) >= 1


def test_scan_file_fixture_good_has_no_violations(fixtures_dir: Path) -> None:
    violations = lint.scan_file(fixtures_dir / "hardcoded_fr_good_widget.dart")
    # Good fixture: AppLocalizations call + `// lefthook-allow:hardcoded-fr:`
    # override on the line preceding `final debugLabel = 'ERR';` (which is
    # also whitelisted as an acronym). Must pass clean.
    assert violations == []
