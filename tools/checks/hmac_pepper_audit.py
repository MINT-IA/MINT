#!/usr/bin/env python3
"""HARD lefthook lint — Phase mint-data-architecture-v1-02 W0 Plan 02-01 (D-24).

Refuses bare `hashlib.sha256(user_id | actor_email | ip_address | user_agent)`
calls outside the canonical entry `app/services/audit/hmac_pepper.py::hmac_user_id()`.

Rationale (security-auditor obs #175) : audit-PII hashes are rainbow-table-
reversible without a pepper. The canonical `hmac_user_id()` mixes a server-side
pepper byte string into HMAC-SHA256 to render the hash unguessable.

iter-2 supports `--baseline FILE` to carry pre-existing sites as known-debt :
new sites outside the baseline are HARD-rejected ; baselined sites are
silently skipped. Plan 02-02 W1 D-14/D-15 progressively shrinks the baseline ;
Plan 02-02 close requires the baseline to be empty.

Self-exempt :
    * this script
    * `services/backend/tests/fixtures/bad_audit_writer.py` (lint fixture)
    * `services/backend/app/services/audit/hmac_pepper.py` (canonical entry,
       seeded with a stub here ; real implementation lands in Plan 02-02 W1)

Exit codes :
    0 — no violations outside baseline + self-exempt
    1 — at least one NEW violation outside baseline

Usage :
    python3 tools/checks/hmac_pepper_audit.py [paths...] [--baseline FILE]
    python3 tools/checks/hmac_pepper_audit.py --self-test
"""
from __future__ import annotations

import argparse
import re
import sys
import unicodedata
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parent.parent.parent
_SELF_PATH = Path(__file__).resolve()
_BAD_FIXTURE = (
    _REPO_ROOT / "services" / "backend" / "tests" / "fixtures" / "bad_audit_writer.py"
)
_CANONICAL_ENTRY = (
    _REPO_ROOT
    / "services"
    / "backend"
    / "app"
    / "services"
    / "audit"
    / "hmac_pepper.py"
)

_DEFAULT_SCAN_DIR = _REPO_ROOT / "services" / "backend" / "app"

# Pattern : `hashlib.sha256(...user_id... | ...actor_email... | ...ip_address... | ...user_agent...)`.
# The PII identifier may be a bare name, a dotted attribute, or a function call.
# We match within the immediate argument list of the hashlib.sha256 call.
_HASHLIB_CALL_RE = re.compile(
    r"hashlib\s*\.\s*sha256\s*\(([^()]*(?:\([^()]*\)[^()]*)*)\)",
    re.IGNORECASE,
)
_PII_TOKEN_RE = re.compile(
    r"\b(user_id|actor_email|ip_address|user_agent)\b",
    re.IGNORECASE,
)


def _is_self_exempt(path: Path) -> bool:
    resolved = path.resolve()
    return resolved in {_SELF_PATH, _BAD_FIXTURE, _CANONICAL_ENTRY}


def scan_file(path: Path) -> list[tuple[int, str]]:
    """Return [(lineno, pii_token), ...] for every bare-hashlib-on-PII match."""
    if _is_self_exempt(path):
        return []
    try:
        source = path.read_text(encoding="utf-8")
    except (UnicodeDecodeError, OSError):
        return []
    # NFKC normalize (defense vs U+212A KELVIN SIGN / fullwidth tricks).
    source = unicodedata.normalize("NFKC", source)
    violations: list[tuple[int, str]] = []
    for match in _HASHLIB_CALL_RE.finditer(source):
        inside = match.group(1)
        pii_match = _PII_TOKEN_RE.search(inside)
        if pii_match:
            # Line number = number of \n before match.start() + 1.
            lineno = source.count("\n", 0, match.start()) + 1
            violations.append((lineno, pii_match.group(1).lower()))
    return violations


def _iter_paths(paths: list[str]) -> list[Path]:
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
    if not path.exists():
        return set()
    entries: set[str] = set()
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        token = line.split()[0]
        if ":" in token:
            entries.add(token)
    return entries


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="HARD lint — bare hashlib.sha256 on audit PII (D-24).",
    )
    parser.add_argument(
        "paths",
        nargs="*",
        help="Files or directories to scan. Default: services/backend/app/.",
    )
    parser.add_argument(
        "--self-test",
        action="store_true",
        help="Scan tests/fixtures/bad_audit_writer.py and assert ≥ 1 violation.",
    )
    parser.add_argument(
        "--baseline",
        type=str,
        default=None,
        help=(
            "Path to a baseline file (one `path:lineno` per line) of pre-existing "
            "sites to skip. NEW sites outside the baseline are HARD-rejected."
        ),
    )
    args = parser.parse_args(argv)

    if args.self_test:
        if not _BAD_FIXTURE.exists():
            print(f"ERROR: self-test fixture missing : {_BAD_FIXTURE}", file=sys.stderr)
            return 2
        # Temporarily disable the self-exempt for the fixture so we can scan it.
        original_exempts = {_SELF_PATH, _BAD_FIXTURE, _CANONICAL_ENTRY}

        def _scan_without_fixture_exempt(p: Path) -> list[tuple[int, str]]:
            resolved = p.resolve()
            if resolved in (_SELF_PATH, _CANONICAL_ENTRY):
                return []
            try:
                source = p.read_text(encoding="utf-8")
            except (UnicodeDecodeError, OSError):
                return []
            source = unicodedata.normalize("NFKC", source)
            violations: list[tuple[int, str]] = []
            for match in _HASHLIB_CALL_RE.finditer(source):
                inside = match.group(1)
                pii_match = _PII_TOKEN_RE.search(inside)
                if pii_match:
                    lineno = source.count("\n", 0, match.start()) + 1
                    violations.append((lineno, pii_match.group(1).lower()))
            return violations

        fixture_violations = _scan_without_fixture_exempt(_BAD_FIXTURE)
        if not fixture_violations:
            print(
                f"ERROR: self-test expected ≥ 1 violation in "
                f"{_BAD_FIXTURE.relative_to(_REPO_ROOT)}, got 0.",
                file=sys.stderr,
            )
            return 1
        # Also verify baseline-skip behavior : if baseline lists the fixture site,
        # main loop should skip it.
        baseline_file = (
            _REPO_ROOT / "tools" / "checks" / "_baseline_hmac_sites_at_p112.txt"
        )
        baseline = _read_baseline(baseline_file)
        # Verify the existing app/ tree contains no NEW violations outside baseline.
        scan_paths = _iter_paths([str(_DEFAULT_SCAN_DIR)])
        new_violations: list[tuple[str, int, str]] = []
        for p in scan_paths:
            for lineno, pii in scan_file(p):
                rel = str(p.relative_to(_REPO_ROOT))
                if f"{rel}:{lineno}" in baseline:
                    continue
                new_violations.append((rel, lineno, pii))
        if new_violations:
            print(
                f"ERROR: self-test expected clean app/ tree (after baseline), "
                f"got {len(new_violations)} NEW violations :",
                file=sys.stderr,
            )
            for rel, lineno, pii in new_violations:
                print(f"  {rel}:{lineno} — hashlib.sha256({pii}, ...)", file=sys.stderr)
            return 1
        print(
            f"OK hmac_pepper_audit --self-test : "
            f"caught {len(fixture_violations)} fixture violations, "
            f"existing app/ tree clean (baseline : {len(baseline)} sites)."
        )
        return 0

    paths = args.paths or [str(_DEFAULT_SCAN_DIR)]
    scan_paths = _iter_paths(paths)
    baseline = _read_baseline(Path(args.baseline)) if args.baseline else set()
    total_new = 0
    total_baselined = 0
    for p in scan_paths:
        for lineno, pii in scan_file(p):
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
                f"{key}  Use app.services.audit.hmac_pepper.hmac_user_id() "
                f"instead of bare hashlib.sha256({pii}, ...) — D-24 / "
                f"security-auditor obs #175 (rainbow-table reversible).",
                file=sys.stderr,
            )
    if total_new > 0:
        if baseline:
            print(
                f"\n{total_new} NEW violation(s) outside baseline "
                f"(baselined : {total_baselined}).",
                file=sys.stderr,
            )
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
