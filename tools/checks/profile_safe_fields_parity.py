#!/usr/bin/env python3
"""Concern C parity lint — Phase mint-calc-engine-v1 Plan 19 / W4.

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

Usage :
  python3 tools/checks/profile_safe_fields_parity.py
    [--server <path-to-coach_chat.py>]
    [--flutter <path1.dart> [<path2.dart> ...]]

  Default paths are the canonical MINT repo paths. Override only for
  unit tests / fixtures.

Exit codes :
  0 — server set == flutter union
  1 — drift detected (actionable diff printed)
  2 — extraction failed (server symbol not found, etc.)
"""
from __future__ import annotations

import argparse
import ast
import re
import sys
from pathlib import Path


_REPO_ROOT = Path(__file__).resolve().parents[2]

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

# Inside a profileContext block, match `'snake_case_key':` or `"snake_case_key":`.
# Snake-case lowercase only — Dart camelCase variable names like `ctx.canton`
# (values, RHS) won't match.
_KEY_IN_BLOCK_RE = re.compile(r"['\"]([a-z][a-z_0-9]*)['\"]\s*:")


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
            depth = 0
            end = start
            for i in range(start, len(source)):
                ch = source[i]
                if ch == "{":
                    depth += 1
                elif ch == "}":
                    depth -= 1
                    if depth == 0:
                        end = i
                        break
            block = source[start : end + 1]
            for key_match in _KEY_IN_BLOCK_RE.finditer(block):
                keys.add(key_match.group(1))

        # (2) In-place mutations.
        for mut_match in _PROFILECONTEXT_MUTATION_RE.finditer(source):
            keys.add(mut_match.group(1))

    return keys


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Concern C parity lint — server _PROFILE_SAFE_FIELDS vs Flutter "
            "profile_context call-sites. See module docstring for details."
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
    args = parser.parse_args(argv)

    if not args.server.exists():
        print(f"[parity] server file not found: {args.server}", file=sys.stderr)
        return 2

    try:
        server = extract_server_fields(args.server)
    except LookupError as e:
        print(f"[parity] {e}", file=sys.stderr)
        return 2

    flutter = extract_flutter_fields(args.flutter)

    if server == flutter:
        print(f"[parity] Concern C parity: OK ({len(server)} fields in sync)")
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
    return 1


if __name__ == "__main__":
    sys.exit(main())
