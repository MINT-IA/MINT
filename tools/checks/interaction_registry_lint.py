#!/usr/bin/env python3
"""Validate and generate the pilot MINT Interaction Registry artifacts."""
from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

try:
    import yaml
except ImportError:  # pragma: no cover - exercised only on fresh envs.
    yaml = None  # type: ignore[assignment]

INDEX_PATH = Path("interactions/INDEX.md")
GRAPH_PATH = Path(".planning/journeys/diagrams/interaction_graph.mmd")
ROUTE_METADATA = Path("apps/mobile/lib/routes/route_metadata.dart")
ANALYTICS_EVENTS = Path("apps/mobile/lib/services/analytics_events.dart")
APP_FR_ARB = Path("apps/mobile/lib/l10n/app_fr.arb")
ID_RE = re.compile(r"^[a-z]+[a-z0-9_]*\.(route|scene)\.[a-z0-9_]+$")
FLOW_RE = re.compile(r"^[a-z][a-z0-9_]*$")
EDGE_ID_RE = re.compile(r"^[a-z]+[a-z0-9_]*\.edge\.[a-z0-9_]+(?:\.[a-z0-9_]+)*$")
DOMAIN_EXTRA_BLOCKLIST = {
    "CoachProfile",
    "ExtractionResult",
    "Profile",
    "Result",
    "Object",
    "dynamic",
}
EXTRA_ALLOWLIST_EXACT = {"String", "int", "bool", "double"}
EXTRA_ALLOWLIST_RE = re.compile(
    r"^[A-Z][A-Za-z0-9_]*(Id|Ids|Key|Code|Token|Enum|Type|Selection|Slug)$",
)
BACK_TARGET_RE = re.compile(r"^(?:pop_to|reset_to)\(([^)]+)\)$")
DATA_BLOCK_NODE_RE = re.compile(r"^db\.route\.([a-z0-9_]+)$")


def _payload_type_is_allowed(type_name: str) -> bool:
    return (
        type_name in EXTRA_ALLOWLIST_EXACT
        or bool(EXTRA_ALLOWLIST_RE.match(type_name))
    )


@dataclass(frozen=True)
class RegistryDocument:
    path: Path
    data: dict[str, Any]

    @property
    def flow_id(self) -> str:
        flow = self.data.get("flow") or {}
        return str(flow.get("id", ""))

    @property
    def nodes(self) -> list[dict[str, Any]]:
        nodes = self.data.get("nodes")
        return nodes if isinstance(nodes, list) else []

    @property
    def edges(self) -> list[dict[str, Any]]:
        edges = self.data.get("edges")
        return edges if isinstance(edges, list) else []


def _rel(root: Path, path: Path) -> str:
    try:
        return str(path.relative_to(root))
    except ValueError:
        return str(path)


def _load_yaml(path: Path, root: Path) -> tuple[RegistryDocument | None, list[str]]:
    if yaml is None:
        return None, [
            "PyYAML is required for interaction registry lint; install with: python3 -m pip install pyyaml",
        ]
    try:
        data = yaml.safe_load(path.read_text(encoding="utf-8"))
    except Exception as exc:  # pragma: no cover - exact parser text is not stable.
        return None, [f"{_rel(root, path)}: cannot parse YAML: {exc}"]
    if not isinstance(data, dict):
        return None, [f"{_rel(root, path)}: root must be a YAML map"]
    return RegistryDocument(path=path, data=data), []


def _load_documents(root: Path) -> tuple[list[RegistryDocument], list[str]]:
    interactions_dir = root / "interactions"
    if not interactions_dir.is_dir():
        return [], ["interactions/ directory is missing"]
    docs: list[RegistryDocument] = []
    errors: list[str] = []
    for path in sorted(interactions_dir.glob("*.yaml")):
        doc, doc_errors = _load_yaml(path, root)
        errors.extend(doc_errors)
        if doc is not None:
            docs.append(doc)
    if not docs:
        errors.append("interactions/ contains no YAML flow")
    return docs, errors


def _route_registry(root: Path) -> set[str]:
    route_file = root / ROUTE_METADATA
    if not route_file.is_file():
        return set()
    text = route_file.read_text(encoding="utf-8")
    return set(re.findall(r"^\s*'([^']+)':\s*RouteMeta\(", text, flags=re.MULTILINE))


def _analytics_events(root: Path) -> set[str]:
    events_file = root / ANALYTICS_EVENTS
    if not events_file.is_file():
        return set()
    text = events_file.read_text(encoding="utf-8")
    return set(re.findall(r"=\s*'([^']+)';", text))


def _arb_keys(root: Path) -> set[str]:
    arb = root / APP_FR_ARB
    if not arb.is_file():
        return set()
    data = json.loads(arb.read_text(encoding="utf-8"))
    return {key for key in data if not key.startswith("@")}


def _data_block_instance_for_node(node: dict[str, Any]) -> str | None:
    if node.get("route") != "/data-block/:type":
        return None
    node_id = node.get("id")
    if not isinstance(node_id, str):
        return None
    match = DATA_BLOCK_NODE_RE.match(node_id)
    if not match:
        return None
    return f"/data-block/{match.group(1)}"


def _validate_data_block_edge_reference(
    root: Path,
    rel_path: str,
    edge_id: str,
    from_node: dict[str, Any],
    to_node: dict[str, Any],
    errors: list[str],
) -> None:
    expected_literal = _data_block_instance_for_node(to_node)
    if expected_literal is None:
        return
    widget = from_node.get("widget")
    if not isinstance(widget, str):
        return
    widget_path = root / "apps/mobile/lib" / widget
    if not widget_path.is_file():
        return
    text = widget_path.read_text(encoding="utf-8", errors="ignore")
    if expected_literal not in text:
        errors.append(
            f"{rel_path}: edge {edge_id} target instance {expected_literal} "
            f"is not referenced in source widget {widget}",
        )


def _validate_documents(root: Path, docs: list[RegistryDocument]) -> list[str]:
    routes = _route_registry(root)
    analytics = _analytics_events(root)
    arb_keys = _arb_keys(root)
    errors: list[str] = []
    seen_flow_ids: set[str] = set()
    seen_edge_ids: set[str] = set()

    for doc in docs:
        rel_path = _rel(root, doc.path)
        flow = doc.data.get("flow")
        if doc.data.get("schema_version") != 1:
            errors.append(f"{rel_path}: schema_version must be 1")
        if not isinstance(flow, dict):
            errors.append(f"{rel_path}: flow must be a map")
            flow = {}
        flow_id = str(flow.get("id", ""))
        if not FLOW_RE.match(flow_id):
            errors.append(f"{rel_path}: flow.id must be snake_case")
        if flow_id != doc.path.stem:
            errors.append(f"{rel_path}: flow.id must match file stem {doc.path.stem}")
        if flow_id in seen_flow_ids:
            errors.append(f"{rel_path}: duplicate flow id {flow_id}")
        seen_flow_ids.add(flow_id)

        nodes = doc.nodes
        edges = doc.edges
        if not nodes:
            errors.append(f"{rel_path}: nodes must contain at least one node")
        if not edges:
            errors.append(f"{rel_path}: edges must contain at least one edge")

        node_ids: set[str] = set()
        nodes_by_id: dict[str, dict[str, Any]] = {}
        incoming: dict[str, int] = {}
        outgoing: dict[str, int] = {}
        exits = flow.get("exits") or []
        if not isinstance(exits, list):
            errors.append(f"{rel_path}: flow.exits must be a list")
            exits = []
        for node in nodes:
            if not isinstance(node, dict):
                errors.append(f"{rel_path}: each node must be a map")
                continue
            node_id = str(node.get("id", ""))
            node_kind = node.get("kind")
            if not ID_RE.match(node_id):
                errors.append(f"{rel_path}: node id {node_id} has invalid format")
            if node_id in node_ids:
                errors.append(f"{rel_path}: duplicate node id {node_id}")
            node_ids.add(node_id)
            nodes_by_id[node_id] = node
            if node_kind not in ("route", "scene"):
                errors.append(f"{rel_path}: node {node_id} kind must be route or scene")
            if node_kind == "route":
                route = node.get("route")
                if not isinstance(route, str) or not route:
                    errors.append(f"{rel_path}: node {node_id} route is required")
                elif route not in routes:
                    errors.append(f"{rel_path}: unknown route {route}")
                elif route == "/data-block/:type" and _data_block_instance_for_node(node) is None:
                    errors.append(
                        f"{rel_path}: data-block node {node_id} must use id format db.route.<type>",
                    )
            if node_kind == "scene" and not node.get("parent"):
                errors.append(f"{rel_path}: scene {node_id} must declare parent")
            widget = node.get("widget")
            if not isinstance(widget, str) or not (root / "apps/mobile/lib" / widget).is_file():
                errors.append(f"{rel_path}: node {node_id} widget does not exist: {widget}")
            if not node.get("entries"):
                errors.append(f"{rel_path}: node {node_id} must declare entries")
            if not node.get("states"):
                errors.append(f"{rel_path}: node {node_id} must declare states")

        for exit_target in exits:
            if exit_target not in node_ids:
                errors.append(f"{rel_path}: undeclared exit {exit_target}")

        def validate_back_target(owner: str, back_value: Any) -> None:
            if not isinstance(back_value, str):
                return
            match = BACK_TARGET_RE.match(back_value)
            if match and match.group(1) not in node_ids:
                errors.append(f"{rel_path}: {owner} back target is undeclared: {match.group(1)}")

        for node in nodes:
            if not isinstance(node, dict):
                continue
            for entry in node.get("entries") or []:
                if isinstance(entry, dict):
                    validate_back_target(f"node {node.get('id')}", entry.get("back"))

        for edge in edges:
            if not isinstance(edge, dict):
                errors.append(f"{rel_path}: each edge must be a map")
                continue
            edge_id = str(edge.get("id", ""))
            if not EDGE_ID_RE.match(edge_id):
                errors.append(f"{rel_path}: edge id {edge_id} has invalid format")
            if edge_id in seen_edge_ids:
                errors.append(f"{rel_path}: duplicate edge id {edge_id}")
            seen_edge_ids.add(edge_id)
            from_node = edge.get("from")
            to_node = edge.get("to")
            if from_node not in node_ids:
                errors.append(f"{rel_path}: edge {edge_id} has unknown from node {from_node}")
            if to_node not in node_ids and to_node not in exits:
                errors.append(f"{rel_path}: edge {edge_id} has unknown target {to_node}")
            if isinstance(from_node, str):
                outgoing[from_node] = outgoing.get(from_node, 0) + 1
            if isinstance(to_node, str):
                incoming[to_node] = incoming.get(to_node, 0) + 1
            if isinstance(from_node, str) and isinstance(to_node, str):
                source_node = nodes_by_id.get(from_node)
                target_node = nodes_by_id.get(to_node)
                if source_node is not None and target_node is not None:
                    _validate_data_block_edge_reference(root, rel_path, edge_id, source_node, target_node, errors)
            if edge.get("trigger") not in ("tap", "swipe", "long_press", "submit", "system"):
                errors.append(f"{rel_path}: edge {edge_id} trigger is invalid")
            if edge.get("transition") not in (
                "push",
                "go",
                "replace",
                "reset_stack",
                "sheet",
                "dialog",
                "in_shell",
            ):
                errors.append(f"{rel_path}: edge {edge_id} transition is invalid")
            payload = edge.get("payload")
            if payload is not None and not isinstance(payload, dict):
                errors.append(f"{rel_path}: edge {edge_id} payload must be a map")
            extra = payload.get("extra") if isinstance(payload, dict) else None
            extra_type = extra.strip() if isinstance(extra, str) else ""
            extra_is_forbidden = (
                extra_type in DOMAIN_EXTRA_BLOCKLIST
                or extra_type.startswith("Map<")
                or extra_type.startswith("List<")
                or (
                    bool(extra_type)
                    and not _payload_type_is_allowed(extra_type)
                )
            )
            if extra_is_forbidden:
                errors.append(
                    f"{rel_path}: edge {edge_id} payload.extra must be an id, enum, code, "
                    f"token, or ephemeral selection, not {extra_type}",
                )
            if isinstance(payload, dict):
                for payload_key in ("path_params", "query_params"):
                    payload_params = payload.get(payload_key)
                    if payload_params is None:
                        continue
                    if not isinstance(payload_params, dict):
                        errors.append(f"{rel_path}: edge {edge_id} payload.{payload_key} must be a map")
                        continue
                    for param_name, param_type in payload_params.items():
                        type_name = param_type.strip() if isinstance(param_type, str) else ""
                        if not type_name or not _payload_type_is_allowed(type_name):
                            errors.append(
                                f"{rel_path}: edge {edge_id} payload.{payload_key}.{param_name} "
                                "must be an id, enum, code, token, type, or ephemeral selection, "
                                f"not {param_type}",
                            )
            validate_back_target(f"edge {edge_id}", edge.get("back"))
            analytics_event = edge.get("analytics")
            if analytics_event and analytics_event not in analytics:
                errors.append(f"{rel_path}: edge {edge_id} analytics event is unknown: {analytics_event}")
            a11y_label = edge.get("a11y_label")
            if a11y_label and a11y_label not in arb_keys:
                errors.append(f"{rel_path}: edge {edge_id} a11y_label is not an ARB key: {a11y_label}")
            test_ref = edge.get("test_ref")
            if not isinstance(test_ref, str) or not test_ref:
                errors.append(f"{rel_path}: edge {edge_id} test_ref is required")
            elif not test_ref.startswith("waived("):
                ref_path = test_ref.split("#", 1)[0]
                if not (root / ref_path).is_file():
                    errors.append(f"{rel_path}: edge {edge_id} test_ref does not exist: {test_ref}")

        for node_id in node_ids:
            node = next((item for item in nodes if isinstance(item, dict) and item.get("id") == node_id), {})
            if not node.get("entries") and incoming.get(node_id, 0) == 0:
                errors.append(f"{rel_path}: orphan node {node_id}")
            if outgoing.get(node_id, 0) == 0 and node_id not in exits:
                errors.append(f"{rel_path}: dead-end node {node_id}")
    return errors


def _sorted_edges(docs: list[RegistryDocument]) -> list[tuple[RegistryDocument, dict[str, Any]]]:
    result: list[tuple[RegistryDocument, dict[str, Any]]] = []
    for doc in sorted(docs, key=lambda item: item.flow_id):
        for edge in sorted(doc.edges, key=lambda item: str(item.get("id", ""))):
            result.append((doc, edge))
    return result


def _node_map(docs: list[RegistryDocument]) -> dict[str, dict[str, Any]]:
    nodes: dict[str, dict[str, Any]] = {}
    for doc in docs:
        for node in doc.nodes:
            if isinstance(node, dict) and isinstance(node.get("id"), str):
                nodes[node["id"]] = node
    return nodes


def generate_index(docs: list[RegistryDocument]) -> str:
    lines = [
        "# Interaction Registry Index",
        "",
        "<!-- Generated by tools/checks/interaction_registry_lint.py -- do not edit manually. -->",
        "",
        "| Flow | Edge | From -> To | Trigger | Transition | Runtime proof |",
        "|---|---|---|---|---|---|",
    ]
    for doc, edge in _sorted_edges(docs):
        lines.append(
            "| {flow} | `{edge}` | `{from_node} -> {to_node}` | `{trigger}` | `{transition}` | `{test}` |".format(
                flow=doc.flow_id,
                edge=edge.get("id", ""),
                from_node=edge.get("from", ""),
                to_node=edge.get("to", ""),
                trigger=edge.get("trigger", ""),
                transition=edge.get("transition", ""),
                test=edge.get("test_ref", ""),
            ),
        )
    return "\n".join(lines) + "\n"


def _mermaid_id(node_id: str) -> str:
    return re.sub(r"[^A-Za-z0-9_]", "_", node_id)


def generate_mermaid(docs: list[RegistryDocument]) -> str:
    nodes = _node_map(docs)
    lines = [
        "flowchart LR",
        "  %% Generated by tools/checks/interaction_registry_lint.py -- do not edit manually.",
        "  classDef route fill:#eef7f2,stroke:#0d7c66,stroke-width:1px,color:#10231f;",
        "  classDef scene fill:#fff7e8,stroke:#b7791f,stroke-width:1px,color:#2b2112;",
        "",
    ]
    for node_id in sorted(nodes):
        node = nodes[node_id]
        label_suffix = node.get("route") or node.get("parent") or node.get("kind", "")
        lines.append(f'  {_mermaid_id(node_id)}["{node_id}<br/>{label_suffix}"]:::{node.get("kind", "route")}')
    lines.append("")
    for _, edge in _sorted_edges(docs):
        edge_label = f'{edge.get("trigger", "")} / {edge.get("transition", "")}'
        lines.append(
            f'  {_mermaid_id(str(edge.get("from", "")))} -->|"{edge_label}"| '
            f'{_mermaid_id(str(edge.get("to", "")))}',
        )
    back_edges: set[tuple[str, str]] = set()
    for node_id, node in nodes.items():
        for entry in node.get("entries") or []:
            if isinstance(entry, dict):
                match = BACK_TARGET_RE.match(str(entry.get("back", "")))
                if match and match.group(1) != node_id:
                    back_edges.add((node_id, match.group(1)))
    if back_edges:
        lines.append("")
    for from_node, to_node in sorted(back_edges):
        lines.append(f'  {_mermaid_id(from_node)} -. "back" .-> {_mermaid_id(to_node)}')
    return "\n".join(lines) + "\n"


def write_generated_artifacts(root: Path) -> list[str]:
    docs, errors = _load_documents(root)
    if errors:
        return errors
    errors = _validate_documents(root, docs)
    if errors:
        return errors
    (root / INDEX_PATH).parent.mkdir(parents=True, exist_ok=True)
    (root / GRAPH_PATH).parent.mkdir(parents=True, exist_ok=True)
    (root / INDEX_PATH).write_text(generate_index(docs), encoding="utf-8")
    (root / GRAPH_PATH).write_text(generate_mermaid(docs), encoding="utf-8")
    return []


def check(root: Path) -> list[str]:
    root = root.resolve()
    docs, errors = _load_documents(root)
    if not errors:
        errors.extend(_validate_documents(root, docs))
    if errors:
        return errors
    expected = {
        INDEX_PATH: generate_index(docs),
        GRAPH_PATH: generate_mermaid(docs),
    }
    for rel_path, content in expected.items():
        path = root / rel_path
        if not path.is_file() or path.read_text(encoding="utf-8") != content:
            errors.append(
                f"{rel_path} is missing or stale; run tools/checks/interaction_registry_lint.py --write",
            )
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--write", action="store_true", help="rewrite generated index and Mermaid graph")
    args = parser.parse_args(argv)
    errors = write_generated_artifacts(args.root) if args.write else check(args.root)
    if not errors:
        action = "updated" if args.write else "valid"
        print(f"OK interaction_registry_lint: Interaction Registry is {action}.")
        return 0
    print("FAIL interaction_registry_lint: Interaction Registry contract failed.", file=sys.stderr)
    for error in errors:
        print(f"  - {error}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
