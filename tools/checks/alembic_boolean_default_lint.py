#!/usr/bin/env python3
"""HARD lefthook lint — Phase mint-data-architecture-v1-02 W0 Plan 02-01 (D-20).

Refuses any alembic migration adding `sa.Boolean(...)` with a
non-Boolean `server_default` value (the Hotfix B regression class :
`sa.Boolean` + `sa.text("0"|"1"|"true"|"false")` crashes Postgres with
`DatatypeMismatch` at upgrade time, see services/backend/alembic/versions/
p111_projection_audit.py:55 for the correct `sa.false()` pattern).

iter-2 Tier-A A7 expansion (postgres-pro HIGH-1) — also flags these 5
bypass shapes :

1. `server_default="0"` plain string (no `sa.text` wrapper).
2. `server_default=sa.literal_column("0")`.
3. `sa.text("FALSE" | "TRUE" | "'0'::int" | "'f'" | "'t'")`.
4. `sa.BOOLEAN()` uppercase (the original spec only checked title-case
   `sa.Boolean`).
5. `type_=sa.Boolean()` as a keyword arg (instead of positional).

Whitelisted (correct) patterns :
    sa.Column("flag", sa.Boolean(), server_default=sa.false())
    sa.Column("flag", sa.Boolean(), server_default=sa.true())

Self-exempt : this script + `services/backend/tests/fixtures/alembic_bad.py`
(the fixture is intentionally bad — used by `--self-test`).

Exit codes :
    0 — no violations outside exempted files
    1 — at least one violation, with file:line + reason

Usage :
    python3 tools/checks/alembic_boolean_default_lint.py [paths ...]
    python3 tools/checks/alembic_boolean_default_lint.py --self-test
"""
from __future__ import annotations

import argparse
import ast
import sys
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parent.parent.parent
_SELF_PATH = Path(__file__).resolve()
_BAD_FIXTURE = (
    _REPO_ROOT / "services" / "backend" / "tests" / "fixtures" / "alembic_bad.py"
)

_DEFAULT_SCAN_DIR = _REPO_ROOT / "services" / "backend" / "alembic" / "versions"


def _is_boolean_type(node: ast.AST) -> bool:
    """Match sa.Boolean() / sa.BOOLEAN() / Boolean() / BOOLEAN()."""
    if isinstance(node, ast.Call):
        node = node.func
    if isinstance(node, ast.Attribute):
        return node.attr in ("Boolean", "BOOLEAN")
    if isinstance(node, ast.Name):
        return node.id in ("Boolean", "BOOLEAN")
    return False


_BAD_STRING_LITERALS = {
    "0", "1", "true", "false", "TRUE", "FALSE",
    "'0'", "'1'", "'true'", "'false'",
}
# After lower+strip-outer-quotes normalization, these are the bad sa.text() args.
_BAD_TEXT_ARGS = {
    "0", "1", "false", "true", "f", "t",
    # ::int / ::integer / ::boolean explicit casts on numeric/string literals.
    "0::int", "1::int", "0::integer", "1::integer",
    "0::boolean", "1::boolean", "true::boolean", "false::boolean",
}


def _is_bad_server_default(node: ast.AST) -> tuple[bool, str]:
    """Returns (is_bad, reason) for a non-Boolean server_default on a Boolean column."""
    # Shape 1 : plain string "0" / "1" / "true" / "false" / etc.
    if isinstance(node, ast.Constant) and isinstance(node.value, str):
        if node.value in _BAD_STRING_LITERALS:
            return True, f"plain string {node.value!r} — use sa.false() / sa.true()"

    # Shape 2 : sa.text("...") / text("...") / sa.literal_column("...") / literal_column("...")
    if isinstance(node, ast.Call) and isinstance(node.func, (ast.Attribute, ast.Name)):
        func_name = (
            node.func.attr
            if isinstance(node.func, ast.Attribute)
            else node.func.id
        )
        if func_name == "text" and node.args and isinstance(node.args[0], ast.Constant):
            raw = node.args[0].value
            normalized = str(raw).strip().lower()
            # Strip outer single quotes if present : "'0'::int" → "0::int"
            stripped = normalized
            if stripped.startswith("'") and "'" in stripped[1:]:
                # Find the matching closing quote and strip the outer pair.
                close_idx = stripped.index("'", 1)
                stripped = stripped[1:close_idx] + stripped[close_idx + 1:]
            # Match either form : with-quotes or without-quotes
            if (
                normalized in _BAD_TEXT_ARGS
                or stripped in _BAD_TEXT_ARGS
                or raw in _BAD_STRING_LITERALS
            ):
                return (
                    True,
                    f"sa.text({raw!r}) — use sa.false() / sa.true() "
                    "(Postgres DatatypeMismatch class, Hotfix B 2026)",
                )
        if (
            func_name == "literal_column"
            and node.args
            and isinstance(node.args[0], ast.Constant)
        ):
            return (
                True,
                f"sa.literal_column({node.args[0].value!r}) — use sa.false() / sa.true()",
            )
    return False, ""


def _scan_column_call(call: ast.Call) -> list[tuple[int, str]]:
    """Scan a Column(...) call. Returns [(lineno, reason), ...] for each violation."""
    type_arg: ast.AST | None = None
    # Positional args : Column(name, type, ...) — search any arg that is a Boolean type.
    for arg in call.args:
        if _is_boolean_type(arg):
            type_arg = arg
            break
    # Keyword `type_=sa.Boolean()` — Shape 5.
    if type_arg is None:
        for kw in call.keywords:
            if kw.arg == "type_" and _is_boolean_type(kw.value):
                type_arg = kw.value
                break
    if type_arg is None:
        return []

    violations: list[tuple[int, str]] = []
    for kw in call.keywords:
        if kw.arg == "server_default":
            is_bad, reason = _is_bad_server_default(kw.value)
            if is_bad:
                violations.append((call.lineno, reason))
    return violations


def _is_column_call(call: ast.Call) -> bool:
    """Match `sa.Column(...)` / `Column(...)`."""
    if isinstance(call.func, ast.Attribute):
        return call.func.attr == "Column"
    if isinstance(call.func, ast.Name):
        return call.func.id == "Column"
    return False


def scan_file(path: Path) -> list[tuple[int, str]]:
    """Return [(lineno, reason), ...] for every Boolean-default violation in `path`."""
    if path.resolve() == _SELF_PATH:
        return []  # self-exempt
    try:
        source = path.read_text(encoding="utf-8")
    except (UnicodeDecodeError, OSError):
        return []
    try:
        tree = ast.parse(source, filename=str(path))
    except SyntaxError:
        return []

    violations: list[tuple[int, str]] = []
    for node in ast.walk(tree):
        if isinstance(node, ast.Call) and _is_column_call(node):
            violations.extend(_scan_column_call(node))
    return violations


def _iter_paths(paths: list[str]) -> list[Path]:
    """Expand argv paths to a list of `*.py` files."""
    result: list[Path] = []
    for raw in paths:
        p = Path(raw).resolve()
        if not p.exists():
            continue
        if p.is_dir():
            result.extend(sorted(p.rglob("*.py")))
        elif p.suffix == ".py":
            result.append(p)
    return result


def _read_baseline(path: Path) -> set[str]:
    """Read `path:line` entries from a baseline file. Empty lines / comments ignored."""
    if not path.exists():
        return set()
    entries: set[str] = set()
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        # Accept "path:lineno" or "path:lineno  ..."
        token = line.split()[0]
        if ":" in token:
            entries.add(token)
    return entries


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="HARD lint refusing Boolean + non-Boolean server_default combos (D-20).",
    )
    parser.add_argument(
        "paths", nargs="*", help="Files or directories to scan. Default: alembic/versions/.",
    )
    parser.add_argument(
        "--self-test",
        action="store_true",
        help="Self-test mode : scan tests/fixtures/alembic_bad.py and expect ≥ 6 violations.",
    )
    parser.add_argument(
        "--baseline",
        type=str,
        default=None,
        help=(
            "Path to a baseline file (one `path:lineno` per line) of pre-existing "
            "violations to ignore. NEW violations outside the baseline are HARD-rejected. "
            "Same pattern as hmac_pepper_audit.py baseline."
        ),
    )
    args = parser.parse_args(argv)

    if args.self_test:
        if not _BAD_FIXTURE.exists():
            print(f"ERROR: self-test fixture missing : {_BAD_FIXTURE}", file=sys.stderr)
            return 2
        violations = scan_file(_BAD_FIXTURE)
        if len(violations) < 6:
            print(
                f"ERROR: self-test expected ≥ 6 violations in {_BAD_FIXTURE.name}, "
                f"got {len(violations)} — lint is regressed.",
                file=sys.stderr,
            )
            for lineno, reason in violations:
                print(f"  {_BAD_FIXTURE.name}:{lineno} — {reason}", file=sys.stderr)
            return 1
        # Also verify the existing alembic tree is clean (regression sentinel),
        # subject to the baseline file (pre-existing sites carried as known-debt).
        baseline_path = (
            _REPO_ROOT / "tools" / "checks" / "_baseline_alembic_boolean_at_p112.txt"
        )
        baseline = _read_baseline(baseline_path)
        tree_paths = _iter_paths([str(_DEFAULT_SCAN_DIR)])
        new_tree_violations: list[tuple[str, int, str]] = []
        for p in tree_paths:
            for lineno, reason in scan_file(p):
                rel = str(p.relative_to(_REPO_ROOT))
                if f"{rel}:{lineno}" in baseline:
                    continue
                new_tree_violations.append((rel, lineno, reason))
        if new_tree_violations:
            print(
                f"ERROR: self-test expected clean existing alembic tree (after "
                f"baseline), got {len(new_tree_violations)} NEW violations :",
                file=sys.stderr,
            )
            for rel, lineno, reason in new_tree_violations:
                print(f"  {rel}:{lineno} — {reason}", file=sys.stderr)
            return 1
        print(
            f"OK alembic_boolean_default_lint --self-test : "
            f"caught {len(violations)} violations in {_BAD_FIXTURE.name}, "
            f"existing alembic tree clean."
        )
        return 0

    paths = args.paths or [str(_DEFAULT_SCAN_DIR)]
    scan_paths = _iter_paths(paths)
    baseline = _read_baseline(Path(args.baseline)) if args.baseline else set()
    total_new = 0
    total_baselined = 0
    for p in scan_paths:
        for lineno, reason in scan_file(p):
            try:
                rel = p.relative_to(_REPO_ROOT)
            except ValueError:
                rel = p
            key = f"{rel}:{lineno}"
            if key in baseline:
                total_baselined += 1
                continue
            total_new += 1
            print(
                f"{key}  BOOLEAN columns must use sa.false() / sa.true() — "
                f"{reason}. CLAUDE.md Hotfix B regression class.",
                file=sys.stderr,
            )
    if total_new > 0:
        if baseline:
            print(
                f"\n{total_new} NEW violation(s) outside baseline "
                f"(baselined : {total_baselined}). Add the new sites to "
                f"`{args.baseline}` ONLY if intentional ; otherwise fix them.",
                file=sys.stderr,
            )
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
