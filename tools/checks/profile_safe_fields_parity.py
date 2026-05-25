#!/usr/bin/env python3
"""Concern C parity lint — Phase mint-calc-engine-v1 Plan 19 / W4
+ Phase mint-data-architecture-v1-01-calc-engine-canonical Plan 05 (D-12).

PROFILE-SAFE-FIELDS MODE (W4 Plan 19 — HARD)
============================================
The server canonical `_PROFILE_SAFE_FIELDS` set at
`services/backend/app/api/v1/endpoints/coach_chat.py` is the source of
truth — anything NOT in this set is DROPPED to prevent PII leakage AND
to keep the LLM-context surface bounded.

The Flutter app sends a `profile_context` map at multiple call-sites :
  - `apps/mobile/lib/services/coach/coach_orchestrator.dart` (3 maps :
    BYOK /rag/query, BYOK /coach/chat, server-key /coach/chat)
  - `apps/mobile/lib/services/coach_narrative_service.dart`
  - `apps/mobile/lib/services/coaching_service.dart`
  - `apps/mobile/lib/services/coach/coach_chat_api_service.dart`
    (in-place mutation : `profileContext['partner_declared'] = ...`)

Drift between the two sides is a SILENT grounding gap :
  - Flutter sends fields the server drops → wasted bandwidth + LLM
    never sees them.
  - Server expects fields Flutter never sends → coach answers with stale
    or empty data and the grounding contract degrades.

The lint extracts the server canonical set via Python AST + the Flutter
keys via a `profileContext: { ... }` block-scoped regex, and asserts
equality. On drift, it prints an actionable diff (« missing in Dart » /
« missing in server ») and exits 1.

Concern C (per CONTEXT.md §Data gaps) : « W4 metrics wave adds a
lint-test that walks the canonical safe-fields list » — this script.

Wired into `lefthook.yml` pre-commit for the two glob-touched files.
CI fallback inherited per memory `feedback_ci_path_filter_blind_spots`.

CONSTANTS-DRIFT MODE (Plan 05 — SOFT-WARN, promotes to HARD via --hard)
=======================================================================
Reads the baked Dart version_hash from
`apps/mobile/lib/services/financial_core/generated/regulatory_constants.g.dart`
(Plan 04 artifact, may be absent during Plan 05 wave-3 execution) and
compares against `RegulatoryRegistry.instance().version_hash(date.today())`.

D-12 contract : SOFT-WARN in Phase 01 (exit 0 on drift unless --hard).
Phase 02 first-migration PR (Monte Carlo per D-11) promotes to HARD by
adding --hard to the lefthook + CI invocations.

Status codes (printed to stderr ; --json-status emits one JSON line per
mode invoked) :
  OK                       — both modes pass
  DRIFT-PROFILE-SAFE-FIELDS — profile-safe-fields drift (HARD, exit 1)
  DRIFT-CONSTANTS          — constants drift (SOFT exit 0 ; HARD exit 1)
  MISSING-GENERATED-FILE   — Plan 04 not merged ; informational, exit 0
  IMPORT-FAILURE           — backend import failed ; LOUD, exit 2

LOUD on import failure (codex MEDIUM #2) : sys.path hacks can mask env
issues, so we explicitly DO NOT silently degrade to warn-only.

Usage :
  python3 tools/checks/profile_safe_fields_parity.py
    [--mode {profile-safe-fields,constants-drift,all}]
    [--hard]
    [--json-status]
    [--server <path-to-coach_chat.py>]
    [--flutter <path1.dart> [<path2.dart> ...]]
    [--generated-dart <path-to-regulatory_constants.g.dart>]

  Default paths are the canonical MINT repo paths. Override only for
  unit tests / fixtures.

Exit codes (max of the two modes when --mode all) :
  0 — OK (or SOFT-WARN drift, or MISSING-GENERATED-FILE)
  1 — drift detected in HARD mode
  2 — extraction failed (server symbol not found, ImportError, etc.)
"""
from __future__ import annotations

import argparse
import ast
import json as _json
import os
import re
import sys
from pathlib import Path
from typing import List, Optional


_REPO_ROOT = Path(__file__).resolve().parents[2]

# Plan 04 artifact (may not exist during Plan 05 wave-3 execution).
DEFAULT_GENERATED_DART = (
    _REPO_ROOT
    / "apps"
    / "mobile"
    / "lib"
    / "services"
    / "financial_core"
    / "generated"
    / "regulatory_constants.g.dart"
)

# Regex that extracts the baked SHA-256 hex digest from the Plan 04 codegen
# output. Strict 64-hex match — manual tampering with garbage value triggers
# parse-failure → IMPORT-FAILURE (mitigation T-mintda-05-01 Tampering).
_DART_HASH_RE = re.compile(
    r"const\s+String\s+regulatoryConstantsVersionHash\s*=\s*'([0-9a-f]{64})';"
)

# Canonical Flutter call-sites that build a `profile_context` map. Adding a
# new call-site that sends `profile_context` to the backend → add it here.
# Memory: `feedback_ci_path_filter_blind_spots` — single list of truth.
DEFAULT_SERVER = _REPO_ROOT / "services" / "backend" / "app" / "api" / "v1" / "endpoints" / "coach_chat.py"
DEFAULT_FLUTTER = [
    _REPO_ROOT / "apps" / "mobile" / "lib" / "services" / "coach" / "coach_orchestrator.dart",
    _REPO_ROOT / "apps" / "mobile" / "lib" / "services" / "coach" / "coach_chat_api_service.dart",
    _REPO_ROOT / "apps" / "mobile" / "lib" / "services" / "coach_narrative_service.dart",
    _REPO_ROOT / "apps" / "mobile" / "lib" / "services" / "coaching_service.dart",
]

# Server symbol name — single source of truth ; if the server renames the
# constant, this lint fails LOUD (extract_server_fields returns empty set).
_SERVER_SYMBOL = "_PROFILE_SAFE_FIELDS"


# ---------------------------------------------------------------------------
# Server-side extraction (Python AST — robust)
# ---------------------------------------------------------------------------


def extract_server_fields(server_file: Path) -> set[str]:
    """Walk `server_file` AST, return the `_PROFILE_SAFE_FIELDS` literal as a set.

    Supports :
      - set literal       : `_PROFILE_SAFE_FIELDS = {"a", "b", "c"}`
      - list literal      : `_PROFILE_SAFE_FIELDS = ["a", "b", "c"]`
      - tuple literal     : `_PROFILE_SAFE_FIELDS = ("a", "b", "c")`
      - frozenset call    : `_PROFILE_SAFE_FIELDS = frozenset({"a", "b"})`
      - set() empty call  : `_PROFILE_SAFE_FIELDS = set()`

    Non-string elements (e.g. names, calls) are silently skipped — we only
    care about user-key strings.

    Raises `LookupError` if the symbol is not found OR the value shape
    cannot be statically extracted. The CLI catches this and returns 2
    (extractor failure). Returns an empty set if the symbol IS found and
    is genuinely empty (e.g. `set()` / `{}` placeholder).
    """
    source = server_file.read_text(encoding="utf-8")
    tree = ast.parse(source)
    for node in ast.walk(tree):
        if not isinstance(node, ast.Assign):
            continue
        for target in node.targets:
            if not (isinstance(target, ast.Name) and target.id == _SERVER_SYMBOL):
                continue
            value = node.value
            # Direct set / list / tuple literal.
            if isinstance(value, (ast.Set, ast.List, ast.Tuple)):
                return _strings_from_elts(value.elts)
            # `frozenset({...})` or `set()` call.
            if isinstance(value, ast.Call):
                # set() / frozenset() with no args → empty (genuine).
                if not value.args:
                    return set()
                arg0 = value.args[0]
                if isinstance(arg0, (ast.Set, ast.List, ast.Tuple)):
                    return _strings_from_elts(arg0.elts)
            # Symbol found but shape we don't understand — caller decides.
            raise LookupError(
                f"{_SERVER_SYMBOL} found in {server_file} but value shape "
                f"({type(value).__name__}) is not a literal collection. "
                "Refactor the symbol to a set/list/tuple/frozenset literal "
                "or extend extract_server_fields()."
            )
    raise LookupError(
        f"{_SERVER_SYMBOL} not found in {server_file}. "
        "Symbol renamed? File moved?"
    )


def _strings_from_elts(elts: list[ast.expr]) -> set[str]:
    """Filter `elts` to ast.Constant string values."""
    out: set[str] = set()
    for el in elts:
        if isinstance(el, ast.Constant) and isinstance(el.value, str):
            out.add(el.value)
    return out


# ---------------------------------------------------------------------------
# Flutter-side extraction (block-scoped regex)
# ---------------------------------------------------------------------------

# Match `profileContext: {` to its matching close-brace `}`. Dart Map literals
# use balanced braces ; we walk character-by-character to find the close so
# we don't get tripped by nested map literals.
_PROFILECONTEXT_START_RE = re.compile(r"profileContext\s*:\s*\{", re.MULTILINE)

# Match `profileContext['key']` mutation (e.g. partner_declared, partner_confidence
# at coach_chat_api_service.dart:94-97). These keys join the map AFTER
# construction and are sent to the backend.
_PROFILECONTEXT_MUTATION_RE = re.compile(
    r"profileContext\s*\[\s*['\"]([a-z][a-z_0-9]*)['\"]\s*\]\s*=",
    re.MULTILINE,
)

# Match helpers that construct profile_context maps before passing them to the
# actual HTTP/RAG call. Several MINT call-sites use
# `profileContext: _buildProfileContext(ctx)` rather than an inline map.
_PROFILECONTEXT_HELPER_RE = re.compile(
    r"(?:static\s+)?Map\s*<\s*String\s*,\s*dynamic\s*>\s+"
    r"(?:_buildProfileContext\w*|buildProfileContextForTest)\s*\([^)]*\)\s*\{",
    re.MULTILINE,
)

# Map literals inside those helpers. Keep this scoped to helper bodies so
# unrelated API response maps in the same files don't pollute the lint.
_RETURN_MAP_START_RE = re.compile(r"return\s*\{", re.MULTILINE)
_TYPED_MAP_START_RE = re.compile(
    r"(?:final|var)\s+\w+\s*=\s*<\s*String\s*,\s*dynamic\s*>\s*\{",
    re.MULTILINE,
)

# Inside a profileContext block, match `'snake_case_key':` or `"snake_case_key":`.
# Snake-case lowercase only — Dart camelCase variable names like `ctx.canton`
# (values, RHS) won't match.
_KEY_IN_BLOCK_RE = re.compile(r"['\"]([a-z][a-z_0-9]*)['\"]\s*:")


def _balanced_brace_block(source: str, open_brace_index: int) -> str:
    """Return source from `{` to its matching `}` using a simple brace walk."""
    depth = 0
    end = open_brace_index
    for i in range(open_brace_index, len(source)):
        ch = source[i]
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                end = i
                break
    return source[open_brace_index : end + 1]


def extract_flutter_fields(flutter_files: list[Path]) -> set[str]:
    """Union all `profile_context` map keys across the given Dart files.

    For each file :
      1. Find every `profileContext: { ... }` block-scoped via balanced-brace
         walk + extract snake_case string keys inside.
      2. Find every `profileContext['key'] = value` mutation + capture key.

    Returns the union set. Falsifies on drift when paired with server set.
    """
    keys: set[str] = set()
    for path in flutter_files:
        if not path.exists():
            continue  # tolerant — caller passes real list, missing file = skipped
        source = path.read_text(encoding="utf-8")

        # (1) Block-scoped map literals.
        for match in _PROFILECONTEXT_START_RE.finditer(source):
            # Walk braces from the opening `{` to find the matching close.
            start = match.end() - 1  # position of '{'
            block = _balanced_brace_block(source, start)
            for key_match in _KEY_IN_BLOCK_RE.finditer(block):
                keys.add(key_match.group(1))

        # (2) In-place mutations.
        for mut_match in _PROFILECONTEXT_MUTATION_RE.finditer(source):
            keys.add(mut_match.group(1))

        # (3) Helper-built maps passed as `profileContext: _buildProfileContext(...)`.
        for helper_match in _PROFILECONTEXT_HELPER_RE.finditer(source):
            helper_start = helper_match.end() - 1
            helper_block = _balanced_brace_block(source, helper_start)
            for map_re in (_RETURN_MAP_START_RE, _TYPED_MAP_START_RE):
                for map_match in map_re.finditer(helper_block):
                    map_start = map_match.end() - 1
                    block = _balanced_brace_block(helper_block, map_start)
                    for key_match in _KEY_IN_BLOCK_RE.finditer(block):
                        keys.add(key_match.group(1))

    return keys


# ---------------------------------------------------------------------------
# Status emitter (Plan 05 D-12)
# ---------------------------------------------------------------------------


def _emit_status(
    mode: str,
    status: str,
    exit_code: int,
    msg: Optional[str],
    json_status: bool,
) -> None:
    """Emit a human stderr line + optional machine-readable JSON line.

    The JSON line is a single JSON object with keys ``mode``, ``status``,
    ``exit_code`` — easy to parse from a CI gate or PR-summary script
    without scraping prose.
    """
    if msg:
        print(f"[{mode}] {status}: {msg}", file=sys.stderr)
    if json_status:
        print(
            _json.dumps({"mode": mode, "status": status, "exit_code": exit_code}),
            file=sys.stderr,
        )


# ---------------------------------------------------------------------------
# Profile-safe-fields check (W4 Plan 19 — UNCHANGED behaviour, extracted)
# ---------------------------------------------------------------------------


def _run_profile_safe_fields_check(args: argparse.Namespace) -> int:
    """Run the Concern C profile-safe-fields parity check.

    Extracted from the previous monolithic ``main()`` so the new ``--mode``
    dispatcher can call it without behaviour change. Returns the same exit
    codes as the pre-Plan-05 script : 0 OK, 1 drift, 2 extraction failure.
    """
    if not args.server.exists():
        print(f"[parity] server file not found: {args.server}", file=sys.stderr)
        _emit_status(
            "profile-safe-fields",
            "EXTRACTION-FAILURE",
            2,
            None,
            args.json_status,
        )
        return 2

    try:
        server = extract_server_fields(args.server)
    except LookupError as e:
        print(f"[parity] {e}", file=sys.stderr)
        _emit_status(
            "profile-safe-fields",
            "EXTRACTION-FAILURE",
            2,
            None,
            args.json_status,
        )
        return 2

    flutter = extract_flutter_fields(args.flutter)

    if server == flutter:
        print(f"[parity] Concern C parity: OK ({len(server)} fields in sync)")
        _emit_status(
            "profile-safe-fields",
            "OK",
            0,
            None,
            args.json_status,
        )
        return 0

    missing_in_flutter = sorted(server - flutter)
    extra_in_flutter = sorted(flutter - server)

    # If the operator opted into ignore-flutter-only AND the ONLY diff is
    # flutter-extra, treat as in-sync (rollout helper).
    if args.ignore_flutter_only and not missing_in_flutter:
        print(
            f"[parity] Concern C parity: OK (--ignore-flutter-only ; "
            f"{len(extra_in_flutter)} Flutter-only fields dropped server-side)"
        )
        _emit_status(
            "profile-safe-fields",
            "OK",
            0,
            None,
            args.json_status,
        )
        return 0

    print("[parity] Concern C parity FAIL — drift between server canonical "
          f"`{_SERVER_SYMBOL}` and Flutter `profile_context` call-sites.")
    print(f"  server  : {args.server}")
    print(f"  flutter : {[str(p) for p in args.flutter]}")
    if missing_in_flutter:
        print(
            f"  missing in Flutter ({len(missing_in_flutter)}) — "
            f"server expects these but no Dart call-site sends them:"
        )
        for f in missing_in_flutter:
            print(f"    - {f}")
    if extra_in_flutter:
        print(
            f"  missing in server ({len(extra_in_flutter)}) — "
            f"Flutter sends these but server drops them (PII / unknown field):"
        )
        for f in extra_in_flutter:
            print(f"    - {f}")
    print(
        "\n  Fix : add the field to the matching side, or remove the Flutter "
        "call-site key. If intentional drift, document in "
        ".planning/decisions/ + add the key to a per-side allowlist.",
    )
    _emit_status(
        "profile-safe-fields",
        "DRIFT-PROFILE-SAFE-FIELDS",
        1,
        None,
        args.json_status,
    )
    return 1


# ---------------------------------------------------------------------------
# Constants-drift check (Plan 05 D-12 — SOFT-WARN with --hard promotion)
# ---------------------------------------------------------------------------


def check_constants_drift(
    dart_file: Path,
    *,
    hard: bool,
    json_status: bool,
) -> int:
    """Compare baked Dart version_hash against backend RegulatoryRegistry.

    D-12 contract :
      - Missing Dart file (Plan 04 not merged) → status MISSING-GENERATED-FILE,
        exit 0 (graceful — wave 3 can ship before wave 4).
      - Backend ImportError → status IMPORT-FAILURE, exit 2 (LOUD per
        codex MEDIUM #2 — never silently degrade to warn-only).
      - Dart file malformed (no version_hash literal) → status IMPORT-FAILURE,
        exit 2 (codegen integrity broken, treat as env issue).
      - Hash equality → status OK, exit 0.
      - Hash drift in SOFT-WARN (no --hard) → status DRIFT-CONSTANTS, exit 0
        with stderr naming both hashes + codegen fix command.
      - Hash drift with --hard → status DRIFT-CONSTANTS, exit 1 (Phase 02
        first-migration PR uses this).
    """
    # ── Missing-file path : graceful (Plan 04 not yet merged). ────────────
    if not dart_file.exists():
        _emit_status(
            "constants-drift",
            "MISSING-GENERATED-FILE",
            0,
            (
                f"Generated Dart file not found at {dart_file} — "
                "Plan 04 not yet merged ; constants-drift check skipped."
            ),
            json_status,
        )
        return 0

    # ── Backend import : LOUD on failure (codex MEDIUM #2). ───────────────
    # Test-only seam : MINT_LINT_FORCE_IMPORT_FAILURE=1 simulates an
    # ImportError without poisoning the global sys.path. Used by
    # test_constants_drift_mode_import_failure_loud.
    force_fail = os.environ.get("MINT_LINT_FORCE_IMPORT_FAILURE") == "1"
    try:
        if force_fail:
            raise ImportError(
                "RegulatoryRegistry import simulated as failure via "
                "MINT_LINT_FORCE_IMPORT_FAILURE=1 env var (test-only seam)."
            )
        backend_root = _REPO_ROOT / "services" / "backend"
        if str(backend_root) not in sys.path:
            sys.path.insert(0, str(backend_root))
        from app.services.regulatory.registry import (  # noqa: WPS433
            RegulatoryRegistry,
        )
    except ImportError as exc:
        _emit_status(
            "constants-drift",
            "IMPORT-FAILURE",
            2,
            (
                f"Failed to import RegulatoryRegistry from services/backend "
                f"({exc}). Verify backend deps are installed and the registry "
                "module is importable (cd services/backend && pip install -e .)."
            ),
            json_status,
        )
        return 2

    # ── Parse the baked hash from the Dart file. ──────────────────────────
    dart_text = dart_file.read_text(encoding="utf-8")
    match = _DART_HASH_RE.search(dart_text)
    if not match:
        _emit_status(
            "constants-drift",
            "IMPORT-FAILURE",
            2,
            (
                f"Could not parse regulatoryConstantsVersionHash from "
                f"{dart_file} (expected `const String regulatoryConstantsVersionHash = '<64hex>';`). "
                "Re-run Plan 04 codegen : python3 tools/codegen/regulatory_constants_to_dart.py --source local --write"
            ),
            json_status,
        )
        return 2
    baked = match.group(1)

    # ── Compare to backend active snapshot at today. ──────────────────────
    from datetime import date  # local import — avoid module-load cost when unused

    backend_hash = RegulatoryRegistry.instance().version_hash(date.today())
    if baked == backend_hash:
        _emit_status("constants-drift", "OK", 0, None, json_status)
        return 0

    # ── Drift detected. SOFT in Phase 01 ; HARD when --hard. ──────────────
    exit_code = 1 if hard else 0
    suffix = (
        " (HARD)"
        if hard
        else " (SOFT-WARN — Phase 01 D-12 ; Phase 02 will promote to HARD via --hard)"
    )
    _emit_status(
        "constants-drift",
        "DRIFT-CONSTANTS",
        exit_code,
        (
            f"Drift detected{suffix}: Dart baked = {baked} ; "
            f"backend version_hash = {backend_hash}. "
            "Fix: python3 tools/codegen/regulatory_constants_to_dart.py --source local --write"
        ),
        json_status,
    )
    return exit_code


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Concern C parity lint — server _PROFILE_SAFE_FIELDS vs Flutter "
            "profile_context call-sites (W4 Plan 19) AND D-12 constants-drift "
            "between baked Dart version_hash and backend RegulatoryRegistry "
            "(Plan 05). See module docstring for details."
        ),
    )
    parser.add_argument(
        "--mode",
        choices=["profile-safe-fields", "constants-drift", "all"],
        default="all",
        help=(
            "Which parity check to run. `all` runs both ; "
            "`constants-drift` is SOFT-WARN in Phase 01 (D-12) ; "
            "`profile-safe-fields` is the W4 Plan 19 HARD gate."
        ),
    )
    parser.add_argument(
        "--hard",
        action="store_true",
        help=(
            "Promote constants-drift mode to HARD (exit 1 on drift). "
            "Phase 02 first-migration PR (Monte Carlo per D-11) uses this."
        ),
    )
    parser.add_argument(
        "--json-status",
        action="store_true",
        help=(
            "Emit a machine-readable JSON status line on stderr (one per "
            "mode invoked). Useful for CI parsing and PR-summary surfacing."
        ),
    )
    parser.add_argument(
        "--server",
        type=Path,
        default=DEFAULT_SERVER,
        help="Path to coach_chat.py (default: services/backend/app/api/v1/endpoints/coach_chat.py)",
    )
    parser.add_argument(
        "--flutter",
        type=Path,
        nargs="+",
        default=DEFAULT_FLUTTER,
        help="Path(s) to Dart files that send profile_context (default: 4 canonical call-sites)",
    )
    parser.add_argument(
        "--ignore-flutter-only",
        action="store_true",
        help=(
            "Tolerate Flutter-only keys (server doesn't expose them — server "
            "silently drops these, no PII risk). Useful during incremental "
            "rollout when Flutter adds a key BEFORE server. NOT recommended "
            "for the hard-gate path."
        ),
    )
    parser.add_argument(
        "--generated-dart",
        type=Path,
        default=DEFAULT_GENERATED_DART,
        help=(
            "Path to the generated Dart constants file (Plan 04 artifact). "
            "Default: apps/mobile/lib/services/financial_core/generated/"
            "regulatory_constants.g.dart. Missing-file is graceful (status "
            "MISSING-GENERATED-FILE, exit 0)."
        ),
    )
    args = parser.parse_args(argv)

    exit_code = 0

    if args.mode in ("profile-safe-fields", "all"):
        psf_exit = _run_profile_safe_fields_check(args)
        exit_code = max(exit_code, psf_exit)

    if args.mode in ("constants-drift", "all"):
        cd_exit = check_constants_drift(
            args.generated_dart,
            hard=args.hard,
            json_status=args.json_status,
        )
        exit_code = max(exit_code, cd_exit)

    return exit_code


if __name__ == "__main__":
    sys.exit(main())
