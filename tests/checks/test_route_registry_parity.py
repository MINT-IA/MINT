"""Phase 32 Wave 4 Plan 32-04 — pytest for route registry parity lint.

Exercises `tools/checks/route_registry_parity.py` against:
  1. The live `apps/mobile/lib/app.dart` + `apps/mobile/lib/routes/route_metadata.dart`
     (pristine HEAD — must exit 0, proving Plan 01 + Plan 03 kept parity 1:1).
  2. `tests/checks/fixtures/parity_drift.dart` — must exit 1 with diff.
  3. `tests/checks/fixtures/parity_known_miss.dart` — must exit 0.
  4. Extraction-only mode (list sorted, deduped, non-empty).
  5. Banned-terms (LSFin) absent from stderr output.

Python 3.9-compatible, stdlib-only (matches the lint's own constraint).
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
LINT = REPO_ROOT / "tools" / "checks" / "route_registry_parity.py"
APP_DART = REPO_ROOT / "apps" / "mobile" / "lib" / "app.dart"
DRIFT_FX = REPO_ROOT / "tests" / "checks" / "fixtures" / "parity_drift.dart"
KNOWN_MISS_FX = REPO_ROOT / "tests" / "checks" / "fixtures" / "parity_known_miss.dart"


def _run(args, timeout=30):
    return subprocess.run(
        [sys.executable, str(LINT)] + list(args),
        capture_output=True,
        text=True,
        cwd=str(REPO_ROOT),
        timeout=timeout,
    )


def test_lint_script_exists_and_is_executable():
    """Lint file must exist AND be marked executable (chmod +x)."""
    import os
    import stat
    assert LINT.exists(), f"lint script missing: {LINT}"
    mode = LINT.stat().st_mode
    assert mode & stat.S_IXUSR, (
        f"lint script not executable (chmod +x needed): {LINT} mode={oct(mode)}"
    )


def test_live_parity_clean_exit_zero():
    """Pristine HEAD — registry should be 1:1 with app.dart after KNOWN-MISSES exemption."""
    r = _run([])
    assert r.returncode == 0, (
        f"parity lint failed on clean HEAD (expected 0, got {r.returncode}):\n"
        f"stdout:\n{r.stdout}\n"
        f"stderr:\n{r.stderr}"
    )
    assert "routes parity OK" in r.stdout, (
        f"expected 'routes parity OK' in stdout, got:\nstdout:\n{r.stdout}"
    )


def test_extract_only_prints_sorted_deduped_paths():
    r = _run(["--extract-only", str(APP_DART)])
    assert r.returncode == 0, f"extract-only failed:\nstdout:\n{r.stdout}\nstderr:\n{r.stderr}"
    lines = [ln for ln in r.stdout.splitlines() if ln.strip()]
    # Expect ~148 extractions (147 registry + /admin/routes compile-conditional).
    assert len(lines) >= 100, f"expected >=100 extracted paths, got {len(lines)}"
    assert lines == sorted(lines), "--extract-only output must be sorted"
    assert len(lines) == len(set(lines)), "--extract-only output must be deduped"


def test_drift_fixture_exits_one_with_diff():
    r = _run(["--dry-run-fixture", str(DRIFT_FX)])
    assert r.returncode == 1, (
        f"drift fixture should exit 1, got {r.returncode}:\n"
        f"stdout:\n{r.stdout}\n"
        f"stderr:\n{r.stderr}"
    )
    assert "/c-drift-only-in-code" in r.stderr, (
        f"drift path '/c-drift-only-in-code' missing from stderr:\n{r.stderr}"
    )


def test_known_miss_fixture_exits_zero():
    r = _run(["--dry-run-fixture", str(KNOWN_MISS_FX)])
    assert r.returncode == 0, (
        f"known-miss fixture should pass (ternary + dynamic are regex-unparsable, "
        f"treated as zero extracted, registry is empty, parity trivially holds):\n"
        f"stdout:\n{r.stdout}\n"
        f"stderr:\n{r.stderr}"
    )


def test_missing_fixture_exits_two():
    """argparse / missing-file error → exit 2 per sysexits.h EX_USAGE."""
    r = _run(["--dry-run-fixture", "/nonexistent/fixture.dart"])
    assert r.returncode == 2, (
        f"missing fixture should exit 2, got {r.returncode}:\n"
        f"stdout:\n{r.stdout}\n"
        f"stderr:\n{r.stderr}"
    )


def test_banned_terms_absent_from_all_output():
    """LSFin-banned terms must not appear in the lint's English output."""
    r = _run([])
    combined = (r.stdout + "\n" + r.stderr).lower()
    banned = ["garanti", "optimal", "meilleur", "certain",
              "sans risque", "parfait", "assure"]
    for term in banned:
        assert term not in combined, (
            f"banned LSFin term '{term}' appeared in lint output:\n"
            f"stdout:\n{r.stdout}\n"
            f"stderr:\n{r.stderr}"
        )


def test_shell_wrapper_exists_and_is_executable():
    """The standalone lefthook shell wrapper must ship executable."""
    import stat
    wrapper = REPO_ROOT / ".lefthook" / "route_registry_parity.sh"
    assert wrapper.exists(), f"wrapper missing: {wrapper}"
    mode = wrapper.stat().st_mode
    assert mode & stat.S_IXUSR, (
        f"wrapper not executable (chmod +x needed): {wrapper} mode={oct(mode)}"
    )


def test_shell_wrapper_invokes_lint_and_propagates_exit_code():
    """Wrapper must actually run the lint (not be a façade)."""
    wrapper = REPO_ROOT / ".lefthook" / "route_registry_parity.sh"
    r = subprocess.run(
        ["bash", str(wrapper)],
        capture_output=True,
        text=True,
        cwd=str(REPO_ROOT),
        timeout=30,
    )
    # On pristine HEAD the wrapper must succeed (exit 0) and the lint's
    # parity-OK line must reach stdout via the wrapper.
    assert r.returncode == 0, (
        f"wrapper exit non-zero on clean HEAD (got {r.returncode}):\n"
        f"stdout:\n{r.stdout}\nstderr:\n{r.stderr}"
    )
    assert "routes parity OK" in r.stdout, (
        f"wrapper did not forward lint stdout:\n{r.stdout}"
    )
