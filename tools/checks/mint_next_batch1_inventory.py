#!/usr/bin/env python3
"""Generate/check the exhaustive, hash-bound Batch 1 Handoff inventory."""
from __future__ import annotations

import argparse
import hashlib
import sys
from pathlib import Path

import yaml


OUTPUT = Path("product/mint_next/batch1/handoff-inventory.yaml")
ROOTS = {
    ".planning/handoff/2026-04-26-chat-vivant-services": (
        "ADAPT", "primary inspected Handoff; interaction ideas only, never authority"
    ),
    ".planning/handoff/2026-05-09-design-system-v8": (
        "RETIRE_FROM_PROMPTS", "later bundle contains duplicated Handoff and historical generated assets"
    ),
    ".planning/handoffs/chat-vivant-2026-04-19": (
        "RETIRE_FROM_PROMPTS", "superseded earlier generation"
    ),
    ".planning/handoff/pdfs": (
        "RETAIN_AS_HISTORY", "binary historical reference; not runtime or governing source"
    ),
    "docs/brand/mint-v2": (
        "ADAPT", "selected structural inspiration; shell, typography and skin rejected"
    ),
}


def build(root: Path) -> dict:
    entries = []
    for rel_root, (decision, reason) in ROOTS.items():
        base = root / rel_root
        for path in sorted(p for p in base.rglob("*") if p.is_file()):
            data = path.read_bytes()
            entries.append({
                "path": path.relative_to(root).as_posix(),
                "bytes": len(data),
                "sha256": hashlib.sha256(data).hexdigest(),
                "decision": decision,
                "reason": reason,
            })
    hashes: dict[str, list[str]] = {}
    for entry in entries:
        hashes.setdefault(entry["sha256"], []).append(entry["path"])
    duplicate_groups = [paths for paths in hashes.values() if len(paths) > 1]
    return {
        "schema_version": 1,
        "status": "exhaustive_for_declared_roots",
        "roots": list(ROOTS),
        "decision_vocabulary": ["REUSE", "ADAPT", "REWRITE", "RETIRE_FROM_PROMPTS", "RETAIN_AS_HISTORY"],
        "files": entries,
        "duplicate_groups": duplicate_groups,
        "summary": {
            "file_count": len(entries),
            "duplicate_group_count": len(duplicate_groups),
            "all_files_have_decision_reason_and_hash": True,
        },
    }


def render(data: dict) -> str:
    return yaml.safe_dump(data, sort_keys=False, allow_unicode=True, width=120)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()
    root = args.root.resolve()
    expected = render(build(root))
    output = root / OUTPUT
    if args.write:
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(expected, encoding="utf-8")
        print(f"WROTE {OUTPUT}")
        return 0
    try:
        actual = output.read_text(encoding="utf-8")
    except OSError as exc:
        print(f"ERROR inventory missing: {exc}", file=sys.stderr)
        return 1
    if actual != expected:
        print("ERROR Batch 1 Handoff inventory is stale or incomplete; run with --write", file=sys.stderr)
        return 1
    print("OK mint_next_batch1_inventory: every declared Handoff file is classified and hash-bound.", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
