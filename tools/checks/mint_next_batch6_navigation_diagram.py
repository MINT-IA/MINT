#!/usr/bin/env python3
"""Generate/check the human-readable Mermaid view of the canonical Batch 6 graph."""

from __future__ import annotations

import argparse
import hashlib
import re
from pathlib import Path

import yaml


ROOT = Path(__file__).resolve().parents[2]
CONTRACT = ROOT / "product/mint_next/batch6/navigation.yaml"
DIAGRAM = ROOT / "product/mint_next/batch6/navigation.mmd"


def mermaid_id(value: str) -> str:
    return re.sub(r"[^A-Za-z0-9_]", "_", value)


def render() -> str:
    raw = CONTRACT.read_bytes()
    data = yaml.safe_load(raw)
    nodes = data["nodes"]
    lines = [
        f"%% GENERATED from navigation.yaml sha256={hashlib.sha256(raw).hexdigest()}",
        "%% Do not edit manually; run tools/checks/mint_next_batch6_navigation_diagram.py --write",
        "flowchart TD",
        '  overlay_return_to_invoker(["return to invoking screen"])',
    ]
    for node_id, node in nodes.items():
        shape_left, shape_right = ("[[", "]]" ) if node.get("terminal") else ("[", "]")
        lines.append(f'  {mermaid_id(node_id)}{shape_left}"{node_id}"{shape_right}')
    for source, node in nodes.items():
        for action_id, action in node.get("actions", {}).items():
            rendered = False
            if action.get("to"):
                lines.append(f'  {mermaid_id(source)} -->|"{action_id}"| {mermaid_id(action["to"])}')
                rendered = True
            for outcome, target in action.get("outcomes", {}).items():
                lines.append(f'  {mermaid_id(source)} -->|"{action_id}:{outcome}"| {mermaid_id(target)}')
                rendered = True
            if action.get("overlay"):
                overlay_id = f"overlay_{action['overlay']}"
                lines.append(f'  {mermaid_id(source)} -.->|"{action_id}"| {mermaid_id(overlay_id)}')
                rendered = True
            if action.get("operation") == "history_back":
                for predecessor in action.get("allowed_predecessors", []):
                    lines.append(f'  {mermaid_id(source)} -.->|"{action_id}:history"| {mermaid_id(predecessor)}')
                rendered = True
            if not rendered and (action.get("mutation") or action.get("operation")):
                lines.append(f'  {mermaid_id(source)} -->|"{action_id}:state"| {mermaid_id(source)}')
    for overlay_id, overlay in data.get("overlays", {}).items():
        lines.append(f'  {mermaid_id("overlay_" + overlay_id)}{{{{"overlay:{overlay_id}"}}}}')
        source = mermaid_id("overlay_" + overlay_id)
        for action_id, action in overlay.get("actions", {}).items():
            if action.get("to"):
                lines.append(f'  {source} -->|"{action_id}"| {mermaid_id(action["to"])}')
            elif action.get("operation") == "close":
                lines.append(f'  {source} -.->|"{action_id}:close"| overlay_return_to_invoker')
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()
    expected = render()
    if args.write:
        DIAGRAM.write_text(expected, encoding="utf-8")
        print(f"WROTE {DIAGRAM.relative_to(ROOT)}")
        return 0
    actual = DIAGRAM.read_text(encoding="utf-8") if DIAGRAM.is_file() else ""
    if actual != expected:
        print("ERROR: navigation.mmd is missing or stale")
        return 1
    print("OK mint_next_batch6_navigation_diagram: Mermaid matches canonical YAML.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
