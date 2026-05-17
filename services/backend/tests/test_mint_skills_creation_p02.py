"""Tests for Phase mint-data-architecture-v1-01 Plan 02 — Task 2 (MINT skill SKILL.md
creation via idempotent create-or-update script).

Verifies :
- both .claude/skills/mint-{flutter,backend}-dev/SKILL.md files exist
- doctrine wording L1/L2 split present
- exactly 1 marker pair per file
- canonical refs present (financial_core, lucidity._payload, regulatory/registry.py)
- script is idempotent — invoked twice in a row, exit 0 both times ; preserves
  content outside the marker block ; overwrites content inside the marker block

Codex MEDIUM resolved : NEVER abort on existing dir/file ; always update in place.
"""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path


def _repo_root() -> Path:
    # tests/ lives at services/backend/tests/, repo root is 3 parents up.
    return Path(__file__).resolve().parents[3]


def _skill_path(name: str) -> Path:
    return _repo_root() / ".claude" / "skills" / name / "SKILL.md"


def _run_script() -> subprocess.CompletedProcess:
    script = _repo_root() / "tools" / "checks" / "create_or_update_mint_skills.py"
    return subprocess.run(
        [sys.executable, str(script)],
        cwd=str(_repo_root()),
        capture_output=True,
        text=True,
    )


def test_mint_flutter_dev_skill_exists() -> None:
    assert _skill_path("mint-flutter-dev").is_file(), (
        ".claude/skills/mint-flutter-dev/SKILL.md missing — Task 2 not landed."
    )


def test_mint_backend_dev_skill_exists() -> None:
    assert _skill_path("mint-backend-dev").is_file(), (
        ".claude/skills/mint-backend-dev/SKILL.md missing — Task 2 not landed."
    )


def test_skills_carry_l1_l2_doctrine() -> None:
    flutter_src = _skill_path("mint-flutter-dev").read_text(encoding="utf-8")
    backend_src = _skill_path("mint-backend-dev").read_text(encoding="utf-8")

    assert "L1 chiffrer" in flutter_src, (
        "mint-flutter-dev SKILL.md must mention « L1 chiffrer »."
    )
    assert "mobile-canonical" in flutter_src, (
        "mint-flutter-dev SKILL.md must mention « mobile-canonical »."
    )
    assert "L2-L4" in backend_src, (
        "mint-backend-dev SKILL.md must mention « L2-L4 »."
    )
    assert "backend-canonical" in backend_src, (
        "mint-backend-dev SKILL.md must mention « backend-canonical »."
    )


def test_skills_marker_blocks_present() -> None:
    start = "<!-- mint-data-architecture-v1-01-canonical:start -->"
    end = "<!-- mint-data-architecture-v1-01-canonical:end -->"

    for name in ("mint-flutter-dev", "mint-backend-dev"):
        src = _skill_path(name).read_text(encoding="utf-8")
        s_count = src.count(start)
        e_count = src.count(end)
        assert s_count == 1, (
            f"{name}/SKILL.md must contain exactly 1 marker:start ; got {s_count}."
        )
        assert e_count == 1, (
            f"{name}/SKILL.md must contain exactly 1 marker:end ; got {e_count}."
        )


def test_skills_cross_link_canonical_files() -> None:
    flutter_src = _skill_path("mint-flutter-dev").read_text(encoding="utf-8")
    backend_src = _skill_path("mint-backend-dev").read_text(encoding="utf-8")

    assert "apps/mobile/lib/services/financial_core/" in flutter_src, (
        "mint-flutter-dev SKILL.md must cite apps/mobile/lib/services/financial_core/."
    )
    assert "services/backend/app/models/lucidity/_payload.py" in flutter_src, (
        "mint-flutter-dev SKILL.md must cite the lucidity._payload boundary file."
    )
    assert "services/backend/app/services/regulatory/registry.py" in backend_src, (
        "mint-backend-dev SKILL.md must cite the regulatory registry."
    )


def test_idempotent_no_abort_when_present() -> None:
    """Idempotency probe : script must (a) exit 0 twice in a row, (b) preserve
    content outside the marker block, (c) overwrite content inside the marker block.
    """
    # First invocation : establishes the marker block (already done by Task 2 ship,
    # but re-run is safe — that's the whole point).
    first = _run_script()
    assert first.returncode == 0, (
        f"create_or_update_mint_skills.py first invocation failed (exit "
        f"{first.returncode}) : {first.stderr}"
    )

    # Inject a probe BEFORE the marker block ; re-run ; assert probe survives.
    flutter_path = _skill_path("mint-flutter-dev")
    probe_outside = "<!-- probe-outside-marker-2026-05-17-p02 -->"
    src = flutter_path.read_text(encoding="utf-8")
    marker_start = "<!-- mint-data-architecture-v1-01-canonical:start -->"
    insert_pos = src.find(marker_start)
    assert insert_pos > 0, "marker:start not found — Task 2 not landed."
    new_src = src[:insert_pos] + probe_outside + "\n\n" + src[insert_pos:]
    flutter_path.write_text(new_src, encoding="utf-8")

    # Inject a probe INSIDE the marker block ; re-run ; assert probe is overwritten.
    src2 = flutter_path.read_text(encoding="utf-8")
    probe_inside = "<!-- probe-inside-marker-2026-05-17-p02 -->"
    marker_end = "<!-- mint-data-architecture-v1-01-canonical:end -->"
    end_pos = src2.find(marker_end)
    assert end_pos > 0, "marker:end not found."
    new_src2 = src2[:end_pos] + probe_inside + "\n" + src2[end_pos:]
    flutter_path.write_text(new_src2, encoding="utf-8")

    second = _run_script()
    assert second.returncode == 0, (
        f"create_or_update_mint_skills.py second invocation failed (exit "
        f"{second.returncode}) : {second.stderr}"
    )

    final_src = flutter_path.read_text(encoding="utf-8")
    assert probe_outside in final_src, (
        "Probe outside the marker block was deleted — idempotency violated "
        "(script must only touch content INSIDE markers)."
    )
    assert probe_inside not in final_src, (
        "Probe inside the marker block survived re-run — script did NOT rewrite "
        "the marker block contents."
    )

    # Cleanup : run script one more time after stripping the outside probe so the
    # committed state stays clean for subsequent test runs.
    cleaned = final_src.replace(probe_outside + "\n\n", "")
    flutter_path.write_text(cleaned, encoding="utf-8")
    third = _run_script()
    assert third.returncode == 0, "Cleanup re-run failed."
