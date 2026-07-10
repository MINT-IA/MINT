#!/usr/bin/env python3
"""Validate proposed MINT interaction registry flow files.

The registry is intentionally non-codegen for now: this lint only proves that
declared interactions reference live routes, widgets, ARB keys, analytics
events, and test artifacts. Source files are YAML; today they are kept
JSON-compatible so repository contract tests do not need PyYAML.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from collections import deque
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
INTERACTIONS_DIR = ROOT / "interactions"

ID_RE = re.compile(r"^[a-z]+\.(route|scene)\.[a-z0-9_]+$")
FLOW_REF_RE = re.compile(r"^[a-z][a-z0-9_]*\.flow\.[a-z0-9_]+$")
FLOW_ID_RE = re.compile(r"^[a-z][a-z0-9_]*$")
ROUTE_KEY_RE = re.compile(
    r"""^\s*(?P<q>['"])(?P<path>[^'"]+?)(?P=q)\s*:\s*RouteMeta\(""",
    re.MULTILINE,
)
ANALYTICS_RE = re.compile(r"const\s+String\s+\w+\s*=\s*'([^']+)';")
DOMAIN_EXTRA_RE = re.compile(
    r"CoachProfile|MintUserState|ExtractionResult|ConfidenceResult|"
    r"wizardAnswers|BudgetSnapshot|ProfileModel|Map<|List<",
)
ALLOWED_PAYLOAD_KEYS = {"path_params", "extra"}


def _read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except OSError as exc:
        raise ValueError(f"{path}: unreadable: {exc}") from exc


def _load_flow(path: Path) -> dict[str, Any]:
    text = _read_text(path)
    try:
        data = json.loads(text)
    except json.JSONDecodeError as json_exc:
        try:
            import yaml  # type: ignore
        except Exception as yaml_exc:
            raise ValueError(
                f"{path}: not JSON-compatible YAML and PyYAML is unavailable "
                f"({json_exc.msg})"
            ) from yaml_exc
        loaded = yaml.safe_load(text)
        if not isinstance(loaded, dict):
            raise ValueError(f"{path}: top-level YAML must be a mapping")
        data = loaded
    if not isinstance(data, dict):
        raise ValueError(f"{path}: top-level registry document must be a mapping")
    return data


def _registry_routes(root: Path) -> set[str]:
    path = root / "apps/mobile/lib/routes/route_metadata.dart"
    return {m.group("path") for m in ROUTE_KEY_RE.finditer(_read_text(path))}


def _arb_keys(root: Path) -> set[str]:
    data = json.loads(_read_text(root / "apps/mobile/lib/l10n/app_fr.arb"))
    return {key for key in data if not key.startswith("@")}


def _analytics_events(root: Path) -> set[str]:
    path = root / "apps/mobile/lib/services/analytics_events.dart"
    return set(ANALYTICS_RE.findall(_read_text(path)))


def _widget_exists(root: Path, widget: str) -> bool:
    return (root / "apps/mobile/lib" / widget).is_file()


def _test_ref_exists(root: Path, test_ref: str, edge_id: str) -> bool:
    path_text, _, anchor = test_ref.partition("#")
    path = root / path_text
    if not path.is_file():
        return False
    if anchor and path.suffix != ".yaml":
        text = _read_text(path)
        return edge_id in text or anchor in text
    return True


def _list(value: Any) -> list[Any]:
    return value if isinstance(value, list) else []


def _dict(value: Any) -> dict[str, Any]:
    return value if isinstance(value, dict) else {}


def _validate_node(
    node: Any,
    *,
    root: Path,
    path: Path,
    routes: set[str],
    node_ids: set[str],
) -> list[str]:
    errors: list[str] = []
    if not isinstance(node, dict):
        return [f"{path}: node entries must be mappings"]
    node_id = node.get("id")
    kind = node.get("kind")
    if not isinstance(node_id, str) or not ID_RE.match(node_id):
        errors.append(f"{path}: node id must match {ID_RE.pattern}: {node_id!r}")
    if kind not in {"route", "scene"}:
        errors.append(f"{path}:{node_id}: kind must be route or scene")
    if kind == "route":
        route = node.get("route")
        if not isinstance(route, str) or route not in routes:
            errors.append(f"{path}:{node_id}: unknown route {route!r}")
    if kind == "scene":
        parent = node.get("parent")
        if not isinstance(parent, str) or parent not in node_ids:
            errors.append(f"{path}:{node_id}: scene parent must reference a node")
    widget = node.get("widget")
    if not isinstance(widget, str) or not _widget_exists(root, widget):
        errors.append(f"{path}:{node_id}: widget path not found: {widget!r}")
    entries = _list(node.get("entries"))
    for entry in entries:
        if not isinstance(entry, dict) or "via" not in entry or "back" not in entry:
            errors.append(f"{path}:{node_id}: entries require via and back")
    states = _list(node.get("states"))
    if not states and "states_waived" not in node:
        errors.append(f"{path}:{node_id}: states required or explicitly waived")
    return errors


def _validate_payload_extra(path: Path, edge_id: str, payload: dict[str, Any]) -> list[str]:
    unknown = sorted(set(payload) - ALLOWED_PAYLOAD_KEYS)
    if unknown:
        return [f"{path}:{edge_id}: unknown payload key(s): {', '.join(unknown)}"]
    extra = payload.get("extra")
    if extra is None:
        return []
    extra_text = json.dumps(extra, sort_keys=True)
    if DOMAIN_EXTRA_RE.search(extra_text):
        return [
            f"{path}:{edge_id}: payload.extra must not carry domain data "
            f"({extra_text})"
        ]
    return []


def _validate_edge(
    edge: Any,
    *,
    root: Path,
    path: Path,
    node_ids: set[str],
    action_ids: set[str],
    exits: set[str],
    arb_keys: set[str],
    analytics_events: set[str],
) -> list[str]:
    errors: list[str] = []
    if not isinstance(edge, dict):
        return [f"{path}: edge entries must be mappings"]
    edge_id = edge.get("id")
    if not isinstance(edge_id, str) or ".edge." not in edge_id:
        errors.append(f"{path}: edge id must include .edge.: {edge_id!r}")
        edge_id = str(edge_id)
    if edge.get("from") not in node_ids:
        errors.append(f"{path}:{edge_id}: from references unknown node")
    target = edge.get("to")
    if (
        target not in node_ids
        and target not in action_ids
        and target not in exits
        and not (isinstance(target, str) and FLOW_REF_RE.match(target))
    ):
        errors.append(f"{path}:{edge_id}: to references unknown target {target!r}")
    if edge.get("trigger") not in {"tap", "swipe", "long_press", "submit", "system"}:
        errors.append(f"{path}:{edge_id}: trigger is invalid")
    if edge.get("transition") not in {
        "push",
        "replace",
        "reset_stack",
        "sheet",
        "dialog",
        "in_shell",
    }:
        errors.append(f"{path}:{edge_id}: transition is invalid")
    payload = _dict(edge.get("payload"))
    errors.extend(_validate_payload_extra(path, edge_id, payload))
    analytics = edge.get("analytics")
    if analytics is not None and analytics not in analytics_events:
        errors.append(f"{path}:{edge_id}: unknown analytics event {analytics!r}")
    a11y_label = edge.get("a11y_label")
    if a11y_label is not None and a11y_label not in arb_keys:
        errors.append(f"{path}:{edge_id}: a11y_label is not an ARB key: {a11y_label!r}")
    test_ref = edge.get("test_ref")
    if not isinstance(test_ref, str) or not _test_ref_exists(root, test_ref, edge_id):
        errors.append(f"{path}:{edge_id}: test_ref not found or unanchored: {test_ref!r}")
    return errors


def _reachable_depth(
    nodes: list[dict[str, Any]],
    edges: list[dict[str, Any]],
    exits: set[str],
) -> tuple[set[str], int, set[str]]:
    node_ids = {node["id"] for node in nodes if isinstance(node.get("id"), str)}
    entry_nodes = {
        node["id"]
        for node in nodes
        if isinstance(node.get("id"), str) and _list(node.get("entries"))
    }
    adjacency: dict[str, set[str]] = {node_id: set() for node_id in node_ids}
    incoming: set[str] = set()
    for edge in edges:
        source = edge.get("from")
        target = edge.get("to")
        if source in adjacency and target in node_ids:
            adjacency[source].add(target)
            if target != source:
                incoming.add(target)
    roots = (node_ids - incoming) or set(node_ids)
    seen: set[str] = set()
    max_depth = 0
    queue: deque[tuple[str, int]] = deque((root, 0) for root in roots)
    while queue:
        node_id, depth = queue.popleft()
        if node_id in seen:
            continue
        seen.add(node_id)
        max_depth = max(max_depth, depth)
        for target in adjacency.get(node_id, set()):
            queue.append((target, depth + 1))
    dead_ends = {
        node_id
        for node_id in node_ids
        if not adjacency.get(node_id) and node_id not in exits
    }
    orphaned = {
        node_id
        for node_id in node_ids
        if node_id not in entry_nodes and node_id not in incoming
    }
    return orphaned, max_depth, dead_ends


def validate_file(
    path: Path,
    *,
    root: Path = ROOT,
    routes: set[str],
    arb_keys: set[str],
    analytics_events: set[str],
) -> list[str]:
    errors: list[str] = []
    try:
        data = _load_flow(path)
    except ValueError as exc:
        return [str(exc)]
    if data.get("schema_version") != 1:
        errors.append(f"{path}: schema_version must be 1")
    flow = _dict(data.get("flow"))
    flow_id = flow.get("id")
    if not isinstance(flow_id, str) or not FLOW_ID_RE.match(flow_id):
        errors.append(f"{path}: flow.id must be snake_case")
    elif path.stem != flow_id:
        errors.append(f"{path}: file stem must match flow.id {flow_id!r}")
    if not isinstance(flow.get("title"), str) or not flow["title"].strip():
        errors.append(f"{path}: flow.title is required")
    exits = set(str(item) for item in _list(flow.get("exits")))
    invariants = _dict(flow.get("invariants"))
    nodes = [node for node in _list(data.get("nodes")) if isinstance(node, dict)]
    edges = [edge for edge in _list(data.get("edges")) if isinstance(edge, dict)]
    if not nodes:
        errors.append(f"{path}: at least one node is required")
    if not edges:
        errors.append(f"{path}: at least one edge is required")
    node_ids = {str(node.get("id")) for node in nodes if isinstance(node.get("id"), str)}
    action_ids = {
        str(action.get("id"))
        for action in _list(data.get("actions"))
        if isinstance(action, dict) and isinstance(action.get("id"), str)
    }
    for exit_id in sorted(exits):
        if exit_id not in node_ids and not FLOW_REF_RE.match(exit_id):
            errors.append(f"{path}: exit references unknown node or flow ref {exit_id!r}")
    for node in nodes:
        errors.extend(
            _validate_node(
                node,
                root=root,
                path=path,
                routes=routes,
                node_ids=node_ids,
            )
        )
    for edge in edges:
        errors.extend(
            _validate_edge(
                edge,
                root=root,
                path=path,
                node_ids=node_ids,
                action_ids=action_ids,
                exits=exits,
                arb_keys=arb_keys,
                analytics_events=analytics_events,
            )
        )
    orphaned, max_depth, dead_ends = _reachable_depth(nodes, edges, exits)
    for node_id in sorted(orphaned):
        errors.append(f"{path}:{node_id}: orphan node")
    for node_id in sorted(dead_ends):
        errors.append(f"{path}:{node_id}: dead end without flow exit")
    declared_depth = invariants.get("max_depth")
    if isinstance(declared_depth, int) and max_depth > declared_depth:
        errors.append(f"{path}: max depth {max_depth} exceeds {declared_depth}")
    return errors


def emit_index(files: list[Path]) -> str:
    lines = [
        "# Interaction Registry Index",
        "",
        "> Generated view. Source of truth: `interactions/*.yaml`.",
        "",
        "| flow | edge | from | to | trigger | transition | proof |",
        "|---|---|---|---|---|---|---|",
    ]
    for path in files:
        data = _load_flow(path)
        flow = _dict(data.get("flow"))
        flow_id = str(flow.get("id", path.stem))
        for edge in _list(data.get("edges")):
            if not isinstance(edge, dict):
                continue
            lines.append(
                "| {flow} | `{edge}` | `{source}` | `{target}` | {trigger} | "
                "{transition} | `{proof}` |".format(
                    flow=flow_id,
                    edge=edge.get("id", ""),
                    source=edge.get("from", ""),
                    target=edge.get("to", ""),
                    trigger=edge.get("trigger", ""),
                    transition=edge.get("transition", ""),
                    proof=edge.get("test_ref", ""),
                )
            )
    return "\n".join(lines) + "\n"


def _flow_files(root: Path) -> list[Path]:
    directory = root / "interactions"
    if not directory.is_dir():
        return []
    return sorted(directory.glob("*.yaml"))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--file", type=Path, action="append")
    parser.add_argument("--emit-index", action="store_true")
    args = parser.parse_args(argv)
    root = args.root.resolve()
    files = [path if path.is_absolute() else root / path for path in args.file or []]
    if not files:
        files = _flow_files(root)
    routes = _registry_routes(root)
    arb_keys = _arb_keys(root)
    analytics_events = _analytics_events(root)
    errors: list[str] = []
    for path in files:
        errors.extend(
            validate_file(
                path,
                root=root,
                routes=routes,
                arb_keys=arb_keys,
                analytics_events=analytics_events,
            )
        )
    if errors:
        print("FAIL interaction_registry_lint:", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        return 1
    if args.emit_index:
        print(emit_index(files), end="")
        return 0
    print(f"OK interaction_registry_lint: {len(files)} flow file(s) validated.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
