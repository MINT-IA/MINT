#!/usr/bin/env python3
"""Reject new bare SHA-256 hashes of audit/PII identifiers.

The allowed path for user-facing audit hashes is the peppered helper in
app/services/audit/hmac_pepper.py. This hook scans staged backend files and
fails if a new bare hashlib.sha256(...) call appears near sensitive names.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


HASH_RE = re.compile(r"hashlib\.sha256\s*\(")
SENSITIVE_RE = re.compile(
    r"\b(user_id|actor_email|ip_address|user_agent)\b",
    re.IGNORECASE,
)
ALLOWED_SUFFIX = "app/services/audit/hmac_pepper.py"


def _repo_relative(path: Path) -> str:
    try:
        return path.resolve().relative_to(Path.cwd().resolve()).as_posix()
    except ValueError:
        return path.as_posix()


def _load_baseline(path: Path | None) -> set[str]:
    if path is None or not path.exists():
        return set()
    return {
        line.strip()
        for line in path.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    }


def _baseline_keys(rel: str, lineno: int, snippet: str) -> set[str]:
    return {
        f"{rel}:{lineno}:{snippet}",
        f"{rel}:{snippet}",
        snippet,
    }


def _scan_file(path: Path, baseline: set[str]) -> list[str]:
    rel = _repo_relative(path)
    if not path.exists() or path.suffix != ".py":
        return []
    if rel.endswith(ALLOWED_SUFFIX):
        return []

    findings: list[str] = []
    for lineno, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if not HASH_RE.search(line) or not SENSITIVE_RE.search(line):
            continue
        snippet = line.strip()
        if _baseline_keys(rel, lineno, snippet) & baseline:
            continue
        findings.append(f"{rel}:{lineno}: {snippet}")
    return findings


def _self_test() -> int:
    sample = Path("__hmac_pepper_audit_selftest.py")
    sample.write_text(
        "import hashlib\nhashlib.sha256(user_id.encode()).hexdigest()\n",
        encoding="utf-8",
    )
    try:
        return 0 if _scan_file(sample, set()) else 1
    finally:
        sample.unlink(missing_ok=True)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("files", nargs="*")
    parser.add_argument("--baseline", type=Path)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args(argv)

    if args.self_test:
        return _self_test()

    baseline = _load_baseline(args.baseline)
    findings: list[str] = []
    for file_name in args.files:
        findings.extend(_scan_file(Path(file_name), baseline))

    if findings:
        print("New bare hashlib.sha256 audit/PII hash sites:", file=sys.stderr)
        for finding in findings:
            print(f"  {finding}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
