#!/usr/bin/env python3
"""Generate/check the exhaustive, hash-bound Batch 1 Handoff inventory."""
from __future__ import annotations

import argparse
import hashlib
import sys
from pathlib import Path

import yaml


OUTPUT = Path("product/mint_next/batch1/handoff-inventory.yaml")
ROOTS = [
    ".planning/handoff/2026-04-26-chat-vivant-services",
    ".planning/handoff/2026-05-09-design-system-v8",
    ".planning/handoffs/chat-vivant-2026-04-19",
    ".planning/handoff/pdfs",
    "docs/brand/mint-v2",
]


def classify(rel: str) -> tuple[str, str]:
    name = Path(rel).name.lower()
    if rel.startswith(".planning/handoffs/chat-vivant-2026-04-19"):
        return "RETIRE_FROM_PROMPTS", "superseded generation; exact useful duplicates are retained from the inspected April 26 root"
    if rel.startswith(".planning/handoff/pdfs"):
        return "RETAIN_AS_HISTORY", "binary historical reference requiring visual provenance; never runtime or governing authority"
    if rel.startswith(".planning/handoff/2026-05-09-design-system-v8"):
        if "prompt" in name:
            return "RETIRE_FROM_PROMPTS", "model-specific implementation prompt would reintroduce Claude-like framing"
        if "/handoff/" in rel or "/docs/brand/" in rel:
            return "RETIRE_FROM_PROMPTS", "hash inventory shows this generated bundle duplicates inspected Handoff/brand material"
        return "RETAIN_AS_HISTORY", "installation asset or binary retained only to explain the historical delivery bundle"
    if rel.startswith(".planning/handoff/2026-04-26-chat-vivant-services"):
        if name == "prompts.md":
            return "RETIRE_FROM_PROMPTS", "prompt instructions are not design evidence and bias new agents toward the old solution"
        if name.startswith("02-") or name.startswith("03-") or name.startswith("05-"):
            return "REWRITE", "service/component/integration contract conflicts with current deterministic finance and runtime boundaries"
        if name.startswith("01-"):
            return "ADAPT", "retain scene/canvas/artifact interaction concepts; reject explicit Claude equivalence and visual skin"
        if name.startswith("04-"):
            return "ADAPT", "motion intent may inform prototypes only after reduced-motion and accessibility review"
        if name.startswith("06-"):
            return "ADAPT", "test scenarios are inputs to the new comparable protocol, not inherited acceptance evidence"
        if name.endswith((".html", ".jsx", ".css")):
            return "ADAPT", "visual prototype is inspectable inspiration; shell, tokens, typography and calculations are rejected"
        return "RETAIN_AS_HISTORY", "architecture/readme receipt explains intent but does not govern Batch 1"
    if rel.startswith("docs/brand/mint-v2"):
        if name.startswith("screen-") or name == "primitives.jsx":
            return "ADAPT", "selected structure can inspire hierarchy; generic fintech assembly and old shell are rejected"
        if name.endswith((".css", ".html")) or name in {"app.jsx", "components.jsx"}:
            return "REWRITE", "combined demo implementation cannot be reused without current tokens, routing and accessibility contracts"
        return "RETAIN_AS_HISTORY", "supporting brand artifact retained for provenance rather than prompt authority"
    raise ValueError(f"unclassified Handoff artifact: {rel}")


def build(root: Path) -> dict:
    entries = []
    for rel_root in ROOTS:
        base = root / rel_root
        for path in sorted(p for p in base.rglob("*") if p.is_file()):
            data = path.read_bytes()
            rel = path.relative_to(root).as_posix()
            decision, reason = classify(rel)
            entries.append({
                "path": rel,
                "bytes": len(data),
                "sha256": hashlib.sha256(data).hexdigest(),
                "decision": decision,
                "reason": reason,
            })
    hashes: dict[str, list[str]] = {}
    for entry in entries:
        hashes.setdefault(entry["sha256"], []).append(entry["path"])
    duplicate_groups = [paths for paths in hashes.values() if len(paths) > 1]
    # Identical bytes are one piece of evidence. A filename must never make the
    # same artifact acquire contradictory semantic dispositions.
    by_path = {entry["path"]: entry for entry in entries}
    for paths in duplicate_groups:
        canonical = by_path[paths[0]]
        if Path(paths[0]).suffix.lower() in {".png", ".jpg", ".jpeg", ".gif"}:
            decision = "ADAPT"
            reason = "byte-identical visual reference; inspect hierarchy only and reject inherited shell, copy, and authority"
        else:
            decision = canonical["decision"]
            reason = f"byte-identical artifact group canonicalized from {paths[0]}; {canonical['reason']}"
        for path in paths:
            by_path[path]["decision"] = decision
            by_path[path]["reason"] = reason
    return {
        "schema_version": 1,
        "status": "exhaustive_for_declared_roots",
        "roots": ROOTS,
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
