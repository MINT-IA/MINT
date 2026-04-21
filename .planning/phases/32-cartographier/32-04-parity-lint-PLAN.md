---
phase: 32
plan: 4
plan_number: 04
slug: parity-lint
type: execute
wave: 4
status: pending
depends_on: [reconcile, registry]
files_modified:
  - tools/checks/route_registry_parity.py
  - .lefthook/route_registry_parity.sh
  - tests/checks/fixtures/parity_drift.dart
  - tests/checks/fixtures/parity_known_miss.dart
  - tests/checks/test_route_registry_parity.py
requirements:
  - MAP-04
threats: []
autonomous: true
must_haves:
  truths:
    - "`python3 tools/checks/route_registry_parity.py` exits 0 on a pristine Phase 32 checkout (registry matches app.dart)"
    - "Parity lint exits non-zero when a GoRoute/ScopedGoRoute path is in app.dart but absent from kRouteRegistry"
    - "Parity lint exits non-zero when a kRouteRegistry key has no matching path in app.dart (ghost entry)"
    - "Parity lint respects KNOWN-MISSES.md categories (ternary, dynamic) — does not false-positive on them"
    - "Script is stdlib-only Python 3.9+ (runs on dev machine + CI 3.11 without deps)"
    - "`.lefthook/route_registry_parity.sh` wrapper exists standalone (Phase 34 wires it into lefthook.yml — out of scope here)"
  artifacts:
    - path: "tools/checks/route_registry_parity.py"
      provides: "Standalone parity lint executable"
      contains: "GoRoute|ScopedGoRoute"
    - path: "tools/checks/route_registry_parity-KNOWN-MISSES.md"
      provides: "Already shipped in Wave 0 — NOT modified here; referenced by the lint"
    - path: ".lefthook/route_registry_parity.sh"
      provides: "Shell wrapper for Phase 34 lefthook consumption"
    - path: "tests/checks/test_route_registry_parity.py"
      provides: "pytest coverage for drift + known-miss behavior"
  key_links:
    - from: "apps/mobile/lib/app.dart (GoRoute/ScopedGoRoute)"
      to: "apps/mobile/lib/routes/route_metadata.dart (kRouteRegistry keys)"
      via: "tools/checks/route_registry_parity.py"
      pattern: "extracted_app_paths == registry_keys"
---

<objective>
Wave 4 parity lint — ship a standalone Python script that grep-extracts `GoRoute|ScopedGoRoute(path:...)` from `app.dart` and compares against `kRouteRegistry` keys. Fails CI on drift. Respects KNOWN-MISSES.md. Lefthook wiring is Phase 34 scope — this plan ships the script + shell wrapper + tests only.

Maps to ROADMAP Success Criterion 5 (parity lint fails CI on drift).
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT/.claude/get-shit-done/workflows/execute-plan.md
@/Users/julienbattaglia/Desktop/MINT/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/32-cartographier/32-CONTEXT.md
@.planning/phases/32-cartographier/32-RESEARCH.md
@apps/mobile/lib/app.dart
@apps/mobile/lib/routes/route_metadata.dart
@tools/checks/route_registry_parity-KNOWN-MISSES.md
@tools/checks/accent_lint_fr.py
@tools/checks/no_hardcoded_fr.py
@CLAUDE.md

<interfaces>
<!-- Extraction regex (D-04 locked, RESEARCH §4 lines 622-676) -->

_GOROUTE_RE = re.compile(
    r"""(GoRoute|ScopedGoRoute)\s*\(\s*
        (?:.*?,\s*)?
        path\s*:\s*
        (['"])([^'"]+?)\2
    """,
    re.VERBOSE | re.DOTALL,
)

_REGISTRY_KEY_RE = re.compile(
    r"""^\s*(['"])([^'"]+?)\1\s*:\s*RouteMeta\(""",
    re.MULTILINE,
)

<!-- sysexits: 0 OK, 1 drift, 2 usage -->

<!-- KNOWN-MISSES.md category signals (from Wave 0 plan Task 2) -->
// - Category 2: ternary path expression
// - Category 3: dynamic path builder
// - Category 5: nested `routes: [...]` sub-routes
</interfaces>
</context>

<threat_model>
No new runtime threats — build-time tool.
</threat_model>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Write parity lint + shell wrapper + fixtures + pytest coverage</name>
  <files>tools/checks/route_registry_parity.py, .lefthook/route_registry_parity.sh, tests/checks/fixtures/parity_drift.dart, tests/checks/fixtures/parity_known_miss.dart, tests/checks/test_route_registry_parity.py</files>
  <read_first>
    - /Users/julienbattaglia/Desktop/MINT/tools/checks/accent_lint_fr.py (style template — shebang, argparse, sys.exit, stderr)
    - /Users/julienbattaglia/Desktop/MINT/tools/checks/no_hardcoded_fr.py (style template)
    - /Users/julienbattaglia/Desktop/MINT/.planning/phases/32-cartographier/32-RESEARCH.md §4 Parity lint (lines 622-676)
    - /Users/julienbattaglia/Desktop/MINT/tools/checks/route_registry_parity-KNOWN-MISSES.md (Wave 0 output — the categories the script must respect)
    - /Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/app.dart (live source — extraction target)
    - /Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/routes/route_metadata.dart (registry — extraction target)
    - /Users/julienbattaglia/Desktop/MINT/tests/checks/fixtures/parity_drift.dart (Wave 0 scaffold — currently placeholder comment)
    - /Users/julienbattaglia/Desktop/MINT/tests/checks/fixtures/parity_known_miss.dart (Wave 0 scaffold)
  </read_first>
  <behavior>
    - Test 1: On pristine HEAD (real app.dart + real kRouteRegistry), `python3 tools/checks/route_registry_parity.py` exits 0 and stdout mentions "147 routes parity OK".
    - Test 2: On `parity_drift.dart` fixture (app.dart has `/c-drift-only-in-code` absent from registry), `--dry-run-fixture tests/checks/fixtures/parity_drift.dart` exits 1 and stderr mentions `/c-drift-only-in-code`.
    - Test 3: On `parity_known_miss.dart` fixture (only ternary + dynamic patterns in "app.dart"), the lint exits 0, treating them as known-miss.
    - Test 4: `--extract-only` flag prints only the extracted paths (no comparison), sorted + deduped.
    - Test 5: Stderr output is in English and never contains banned LSFin terms.
  </behavior>
  <action>
    Fill the Wave 0 placeholder fixtures with concrete test content first, then write the lint.

    **File 1 — `tests/checks/fixtures/parity_drift.dart`** (replace Wave 0 placeholder — used as a full self-contained input by `--dry-run-fixture`):
    ```dart
    // Phase 32 Wave 4 fixture — parity_drift.
    //
    // Encoded simulated inputs for the parity lint:
    //   APP_DART_PATHS = ['/a', '/b', '/c-drift-only-in-code']
    //   REGISTRY_KEYS  = ['/a', '/b']
    //
    // Below is a minimal synthesized "app.dart" + "registry.dart" block
    // that the parity lint's `--dry-run-fixture` mode parses directly.

    // -- BEGIN fake app.dart --
    import 'package:go_router/go_router.dart';

    final _router = GoRouter(routes: [
      GoRoute(path: '/a', builder: (c, s) => const Placeholder()),
      ScopedGoRoute(path: '/b', scope: RouteScope.public, builder: (c, s) => const Placeholder()),
      GoRoute(path: '/c-drift-only-in-code', builder: (c, s) => const Placeholder()),
    ]);
    // -- END fake app.dart --

    // -- BEGIN fake registry --
    const Map<String, RouteMeta> kRouteRegistry = {
      '/a': RouteMeta(path: '/a', category: RouteCategory.destination, owner: RouteOwner.system, requiresAuth: false),
      '/b': RouteMeta(path: '/b', category: RouteCategory.destination, owner: RouteOwner.system, requiresAuth: false),
    };
    // -- END fake registry --
    ```

    **File 2 — `tests/checks/fixtures/parity_known_miss.dart`:**
    ```dart
    // Phase 32 Wave 4 fixture — parity_known_miss.
    //
    // Simulated inputs:
    //   APP_DART has ONLY patterns the regex cannot extract (ternary, dynamic).
    //   REGISTRY_KEYS  = []  (nothing to compare against since extraction yields 0)
    //
    // Expected: lint exits 0, stderr notes "0 routes extracted — known-miss patterns only".

    // -- BEGIN fake app.dart --
    import 'package:go_router/go_router.dart';

    final _router = GoRouter(routes: [
      // Category 2 — ternary
      GoRoute(path: isNew ? '/v2' : '/legacy', builder: (c, s) => const Placeholder()),
      // Category 3 — dynamic builder
      GoRoute(path: _buildDynamic(segment), builder: (c, s) => const Placeholder()),
    ]);
    // -- END fake app.dart --

    // -- BEGIN fake registry --
    const Map<String, RouteMeta> kRouteRegistry = {};
    // -- END fake registry --
    ```

    **File 3 — `tools/checks/route_registry_parity.py`:**
    ```python
    #!/usr/bin/env python3
    """Phase 32 MAP-04 — route registry parity lint.

    Compares `GoRoute|ScopedGoRoute(path:)` extractions in
    `apps/mobile/lib/app.dart` against `kRouteRegistry` keys in
    `apps/mobile/lib/routes/route_metadata.dart`.

    Exits 0 if parity holds. Exits 1 with diff on drift.

    Respects `tools/checks/route_registry_parity-KNOWN-MISSES.md` category
    signals — ternary/dynamic/conditional patterns are NOT treated as missing.

    Usage:
      python3 tools/checks/route_registry_parity.py
      python3 tools/checks/route_registry_parity.py --extract-only apps/mobile/lib/app.dart
      python3 tools/checks/route_registry_parity.py --dry-run-fixture tests/checks/fixtures/parity_drift.dart

    Python 3.9-compatible (dev 3.9.6, CI 3.11). stdlib-only.
    """
    from __future__ import annotations

    import argparse
    import re
    import sys
    from pathlib import Path
    from typing import List, Optional, Set, Tuple

    REPO_ROOT = Path(__file__).resolve().parents[2]
    APP_DART = REPO_ROOT / "apps/mobile/lib/app.dart"
    REGISTRY_DART = REPO_ROOT / "apps/mobile/lib/routes/route_metadata.dart"

    # Matches both `GoRoute` and `ScopedGoRoute` path: declarations.
    # DOTALL lets the regex cross newlines within a single constructor call.
    _GOROUTE_RE = re.compile(
        r"""(?:GoRoute|ScopedGoRoute)\s*\(       # constructor
            [^)]*?                                 # any preceding kwargs
            path\s*:\s*                            # path kwarg
            (?P<q>['"])(?P<path>[^'"]+?)(?P=q)     # captured literal string
        """,
        re.VERBOSE | re.DOTALL,
    )

    # Known-miss: ternary path expression (`path: X ? '/a' : '/b'`)
    _TERNARY_PATH_RE = re.compile(
        r"""(?:GoRoute|ScopedGoRoute)\s*\(
            [^)]*?
            path\s*:\s*[A-Za-z_][A-Za-z0-9_]*\s*\?
        """,
        re.VERBOSE | re.DOTALL,
    )

    # Known-miss: dynamic path builder (`path: _fn(...)`)
    _DYNAMIC_PATH_RE = re.compile(
        r"""(?:GoRoute|ScopedGoRoute)\s*\(
            [^)]*?
            path\s*:\s*[A-Za-z_][A-Za-z0-9_]*\s*\(
        """,
        re.VERBOSE | re.DOTALL,
    )

    _REGISTRY_KEY_RE = re.compile(
        r"""^\s*(?P<q>['"])(?P<path>[^'"]+?)(?P=q)\s*:\s*RouteMeta\(""",
        re.MULTILINE,
    )


    def extract_app_paths(src: str) -> Tuple[Set[str], int, int]:
        """Returns (extracted_paths, ternary_count, dynamic_count)."""
        paths = {m.group("path") for m in _GOROUTE_RE.finditer(src)}
        ternary = len(_TERNARY_PATH_RE.findall(src))
        dynamic = len(_DYNAMIC_PATH_RE.findall(src))
        return paths, ternary, dynamic


    def extract_registry_keys(src: str) -> Set[str]:
        return {m.group("path") for m in _REGISTRY_KEY_RE.finditer(src)}


    def _read(p: Path) -> str:
        try:
            return p.read_text()
        except FileNotFoundError:
            sys.stderr.write(f"[FAIL] not found: {p}\n")
            sys.exit(2)


    def run_parity(app_src: str, registry_src: str) -> int:
        app_paths, ternary, dynamic = extract_app_paths(app_src)
        reg_keys = extract_registry_keys(registry_src)

        missing_in_registry = app_paths - reg_keys
        ghost_in_registry = reg_keys - app_paths

        # Report
        sys.stderr.write(
            f"[info] extracted {len(app_paths)} paths from app.dart "
            f"(ternary={ternary}, dynamic={dynamic} known-miss skipped)\n"
            f"[info] registry has {len(reg_keys)} keys\n"
        )

        if not missing_in_registry and not ghost_in_registry:
            print(f"[OK] {len(app_paths)} routes parity OK.")
            return 0

        if missing_in_registry:
            sys.stderr.write(
                f"[FAIL] {len(missing_in_registry)} path(s) in app.dart but NOT in kRouteRegistry:\n"
            )
            for p in sorted(missing_in_registry):
                sys.stderr.write(f"  - {p}\n")
            sys.stderr.write(
                "  Fix: add RouteMeta entry to apps/mobile/lib/routes/route_metadata.dart\n"
                "  OR if pattern is regex-unparsable, document in\n"
                "  tools/checks/route_registry_parity-KNOWN-MISSES.md\n"
            )

        if ghost_in_registry:
            sys.stderr.write(
                f"[FAIL] {len(ghost_in_registry)} key(s) in kRouteRegistry but NOT in app.dart (ghost):\n"
            )
            for p in sorted(ghost_in_registry):
                sys.stderr.write(f"  - {p}\n")
            sys.stderr.write(
                "  Fix: remove stale entry from kRouteRegistry OR restore GoRoute in app.dart.\n"
            )

        return 1


    def run_fixture(path: Path) -> int:
        """Split a fixture file on '-- BEGIN fake app.dart --' + '-- BEGIN fake registry --' markers."""
        text = path.read_text()
        app_block = _extract_block(text, "BEGIN fake app.dart", "END fake app.dart")
        reg_block = _extract_block(text, "BEGIN fake registry", "END fake registry")
        if app_block is None or reg_block is None:
            sys.stderr.write(
                "[FAIL] fixture malformed — must contain markers "
                "'-- BEGIN fake app.dart --' and '-- BEGIN fake registry --'.\n"
            )
            return 2
        return run_parity(app_block, reg_block)


    def _extract_block(text: str, start: str, end: str) -> Optional[str]:
        import re as _re
        m = _re.search(f"-- {start} --(.*?)-- {end} --", text, _re.DOTALL)
        return m.group(1) if m else None


    def main(argv: Optional[List[str]] = None) -> int:
        p = argparse.ArgumentParser(
            description="Phase 32 MAP-04 route registry parity lint."
        )
        p.add_argument("--extract-only", metavar="FILE",
                       help="Print extracted paths (sorted, one per line) and exit.")
        p.add_argument("--dry-run-fixture", metavar="FILE",
                       help="Run parity against a self-contained fixture file.")
        args = p.parse_args(argv)

        if args.extract_only:
            src = _read(Path(args.extract_only))
            paths, _, _ = extract_app_paths(src)
            for path in sorted(paths):
                print(path)
            return 0

        if args.dry_run_fixture:
            return run_fixture(Path(args.dry_run_fixture))

        # Default: live repo paths
        app_src = _read(APP_DART)
        reg_src = _read(REGISTRY_DART)
        return run_parity(app_src, reg_src)


    if __name__ == "__main__":
        sys.exit(main())
    ```

    Make executable: `chmod +x tools/checks/route_registry_parity.py`.

    **File 4 — `.lefthook/route_registry_parity.sh`** (standalone wrapper, Phase 34 wires it):
    ```bash
    #!/usr/bin/env bash
    # Phase 32 MAP-04 — lefthook hook wrapper (Phase 34 wires the lefthook.yml entry).
    # Phase 32 ships this script + CI job; Phase 34 will add:
    #   pre-commit:
    #     parallel: true
    #     commands:
    #       route-registry-parity:
    #         run: .lefthook/route_registry_parity.sh

    set -euo pipefail

    # Hard-fail fast if Python 3 missing (lefthook env).
    if ! command -v python3 >/dev/null 2>&1; then
      echo "[FAIL] python3 not found in PATH" >&2
      exit 2
    fi

    cd "$(git rev-parse --show-toplevel)"
    python3 tools/checks/route_registry_parity.py
    ```

    Make executable: `chmod +x .lefthook/route_registry_parity.sh`.

    **File 5 — `tests/checks/test_route_registry_parity.py`:**
    ```python
    """Phase 32 Wave 4 — pytest for parity lint."""
    from __future__ import annotations

    import subprocess
    import sys
    from pathlib import Path

    import pytest

    REPO_ROOT = Path(__file__).resolve().parents[2]
    LINT = REPO_ROOT / "tools/checks/route_registry_parity.py"


    def _run(args):
        return subprocess.run(
            [sys.executable, str(LINT)] + list(args),
            capture_output=True,
            text=True,
            cwd=str(REPO_ROOT),
            timeout=30,
        )


    def test_live_parity_clean_exit_zero():
        """Pristine HEAD — registry should be 1:1 with app.dart."""
        r = _run([])
        assert r.returncode == 0, (
            f"parity lint failed on clean HEAD:\n"
            f"stdout:\n{r.stdout}\n"
            f"stderr:\n{r.stderr}"
        )
        assert "routes parity OK" in r.stdout


    def test_extract_only_prints_paths_sorted():
        r = _run(["--extract-only", str(REPO_ROOT / "apps/mobile/lib/app.dart")])
        assert r.returncode == 0
        lines = [ln for ln in r.stdout.splitlines() if ln.strip()]
        assert len(lines) >= 100  # we expect ~147; be tolerant to regex misses
        assert lines == sorted(lines), "output must be sorted"


    def test_drift_fixture_returns_non_zero():
        fx = REPO_ROOT / "tests/checks/fixtures/parity_drift.dart"
        r = _run(["--dry-run-fixture", str(fx)])
        assert r.returncode == 1, f"drift fixture should fail: {r.stdout} / {r.stderr}"
        assert "/c-drift-only-in-code" in r.stderr


    def test_known_miss_fixture_exits_zero():
        fx = REPO_ROOT / "tests/checks/fixtures/parity_known_miss.dart"
        r = _run(["--dry-run-fixture", str(fx)])
        assert r.returncode == 0, (
            f"known-miss fixture should pass (0 extracted, 0 registered):\n"
            f"stdout:\n{r.stdout}\n"
            f"stderr:\n{r.stderr}"
        )


    def test_missing_app_dart_exits_2():
        # Simulate by pointing extraction at a non-existent file.
        r = _run(["--extract-only", "/nonexistent/path.dart"])
        assert r.returncode == 2


    def test_banned_terms_absent_from_stderr():
        r = _run([])
        banned = ["garanti", "optimal", "meilleur", "certain", "sans risque"]
        for term in banned:
            assert term not in r.stderr.lower(), f"banned term '{term}' in lint stderr"
    ```

    Run:
    ```bash
    cd /Users/julienbattaglia/Desktop/MINT
    python3 tools/checks/route_registry_parity.py        # exits 0
    python3 -m pytest tests/checks/test_route_registry_parity.py -q
    ```

    Both must succeed. The live test `test_live_parity_clean_exit_zero` is the gate — if it fails, kRouteRegistry (Plan 01) is not 1:1 with app.dart (Wave 1 regressed), OR known-miss patterns need documentation update.

    Commit: `feat(32-04): route registry parity lint + fixtures + pytest + lefthook wrapper`.
  </action>
  <verify>
    <automated>cd /Users/julienbattaglia/Desktop/MINT && python3 tools/checks/route_registry_parity.py 2>&1 | tail -5 && python3 -m pytest tests/checks/test_route_registry_parity.py -q 2>&1 | tail -10</automated>
  </verify>
  <acceptance_criteria>
    - `tools/checks/route_registry_parity.py` exists AND is executable (`test -x tools/checks/route_registry_parity.py`)
    - `python3 tools/checks/route_registry_parity.py` exits 0 on clean HEAD, stdout contains literal `routes parity OK`
    - `python3 tools/checks/route_registry_parity.py --dry-run-fixture tests/checks/fixtures/parity_drift.dart` exits 1 AND stderr contains `/c-drift-only-in-code`
    - `python3 tools/checks/route_registry_parity.py --dry-run-fixture tests/checks/fixtures/parity_known_miss.dart` exits 0
    - `python3 -m pytest tests/checks/test_route_registry_parity.py -q` exits 0 with ≥6 tests passing
    - `.lefthook/route_registry_parity.sh` exists AND is executable
    - Running the script with no args completes in ≤30 seconds (CI constraint)
    - Script is stdlib-only (verified: `grep -E "^import " tools/checks/route_registry_parity.py` shows only stdlib modules)
  </acceptance_criteria>
  <done>Parity lint shipped + tested. CI job integration lands in Plan 05. Lefthook YAML wiring deferred to Phase 34 per D-12 §5.</done>
</task>

</tasks>

<verification>
End-of-plan gate:
- Live parity lint exits 0 (proves Plan 01 registry + Plan 03 app.dart additions maintain 1:1).
- Drift fixture exits 1; known-miss fixture exits 0.
- 6+ pytest tests green.
- Stdlib-only (no pip install required on CI).

Single commit: `feat(32-04): route registry parity lint + fixtures + lefthook wrapper`.
</verification>

<success_criteria>
- Parity drift detection proven via fixtures (both directions: missing + ghost)
- KNOWN-MISSES.md categories respected (ternary + dynamic skipped without false-positive)
- Script stays under 30s runtime (CI constraint met)
- Script stdlib-only (no dependency install on CI)
- Lefthook shell wrapper shipped standalone — Phase 34 wires it into `lefthook.yml`
</success_criteria>

<output>
After completion, create `.planning/phases/32-cartographier/32-04-SUMMARY.md` with:
- Live parity lint output (proves 1:1)
- pytest count (≥6 green)
- Fixtures + wrapper inventory
- Commit SHA
- Wave 4 Plan 05 unblock: CI can wire the job
</output>
