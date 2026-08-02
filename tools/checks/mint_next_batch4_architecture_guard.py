#!/usr/bin/env python3
"""Fail-closed structural guard for the canonical MINT Next Batch 4 maps.

This guard validates architecture consistency.  It does not establish that the
financial content is correct, complete, user-tested, or compliant.
"""
from __future__ import annotations

import argparse
import sys
from collections import defaultdict, deque
from pathlib import Path
from typing import Any

import yaml


BASE = Path("product/mint_next/batch4")
FILES = (
    "batch.yaml",
    "audience.yaml",
    "concepts.yaml",
    "decisions.yaml",
    "experience_graph.yaml",
    "claims_and_data.yaml",
    "legacy_reuse.yaml",
)
DECISION_FIELDS = (
    "id",
    "human_question",
    "triggers",
    "concept_ids",
    "eligibility",
    "minimum_input_ids",
    "missing_data_behavior",
    "scenario_ids",
    "tradeoffs",
    "calculation_contract",
    "compliance_boundary",
    "receipt",
    "next_decision_ids",
    "next_action",
    "return_and_correction",
    "not_applicable_behavior",
)
EDGE_FIELDS = (
    "action_id",
    "source",
    "destination",
    "visible_label_intent",
    "guard",
    "data_effect",
    "back_semantics",
    "fallback",
)
LEGACY_DISPOSITIONS = {
    "reuse_as_is",
    "adapt_behind_adapter",
    "rewrite",
    "retire",
    "unknown",
}
SAFE_TERMINALS = {"success", "safe_exit", "saved"}


def _load(root: Path, name: str, errors: list[str]) -> dict[str, Any]:
    path = root / BASE / name
    if not path.is_file():
        errors.append(f"missing registry: {BASE / name}")
        return {}
    try:
        value = yaml.safe_load(path.read_text())
    except Exception as exc:
        errors.append(f"unable to load {name}: {exc}")
        return {}
    if not isinstance(value, dict):
        errors.append(f"{name} must contain a YAML mapping")
        return {}
    if name == "batch.yaml" and value.get("schema_version") != 1:
        errors.append(f"{name} schema_version must be 1")
    return value


def _items(document: dict[str, Any], key: str, name: str, errors: list[str]) -> list[dict[str, Any]]:
    value = document.get(key)
    if not isinstance(value, list):
        errors.append(f"{name}.{key} must be a list")
        return []
    result: list[dict[str, Any]] = []
    for index, item in enumerate(value):
        if not isinstance(item, dict):
            errors.append(f"{name}.{key}[{index}] must be a mapping")
        else:
            result.append(item)
    return result


def _index(items: list[dict[str, Any]], kind: str, errors: list[str]) -> dict[str, dict[str, Any]]:
    result: dict[str, dict[str, Any]] = {}
    for item in items:
        identifier = item.get("id")
        if not isinstance(identifier, str) or not identifier.strip():
            errors.append(f"{kind} has missing or empty id")
            continue
        if identifier in result:
            errors.append(f"duplicate {kind} id: {identifier}")
        else:
            result[identifier] = item
    return result


def _list_of_strings(item: dict[str, Any], field: str, context: str, errors: list[str]) -> list[str]:
    value = item.get(field)
    if not isinstance(value, list) or any(not isinstance(entry, str) or not entry for entry in value):
        errors.append(f"{context}.{field} must be a list of non-empty strings")
        return []
    return value


def _validate_concepts(concepts: dict[str, dict[str, Any]], errors: list[str]) -> None:
    prerequisites: dict[str, list[str]] = {}
    for identifier, concept in concepts.items():
        refs = _list_of_strings(concept, "prerequisites", f"concept {identifier}", errors)
        prerequisites[identifier] = refs
        for ref in refs:
            if ref not in concepts:
                errors.append(f"unknown concept prerequisite: {identifier} -> {ref}")

    colour: dict[str, int] = {}

    def visit(identifier: str) -> None:
        if colour.get(identifier) == 1:
            errors.append(f"concept prerequisite cycle includes: {identifier}")
            return
        if colour.get(identifier) == 2:
            return
        colour[identifier] = 1
        for ref in prerequisites.get(identifier, []):
            if ref in concepts:
                visit(ref)
        colour[identifier] = 2

    for identifier in concepts:
        visit(identifier)


def _validate_decisions(
    decisions: dict[str, dict[str, Any]],
    concepts: dict[str, dict[str, Any]],
    data_ids: set[str],
    errors: list[str],
) -> None:
    for identifier, decision in decisions.items():
        for field in DECISION_FIELDS:
            if field not in decision:
                errors.append(f"decision {identifier} missing required field: {field}")
        for field in (
            "human_question", "eligibility", "missing_data_behavior", "calculation_contract",
            "compliance_boundary", "receipt", "next_action", "return_and_correction",
            "not_applicable_behavior",
        ):
            if field in decision and (not isinstance(decision[field], str) or not decision[field].strip()):
                errors.append(f"decision {identifier}.{field} must be a non-empty string")
        for field in ("triggers", "concept_ids", "minimum_input_ids", "scenario_ids", "tradeoffs", "next_decision_ids"):
            if field in decision:
                refs = _list_of_strings(decision, field, f"decision {identifier}", errors)
                if field == "concept_ids":
                    for ref in refs:
                        if ref not in concepts:
                            errors.append(f"unknown concept reference: decision {identifier} -> {ref}")
                elif field == "minimum_input_ids":
                    for ref in refs:
                        if ref not in data_ids:
                            errors.append(f"unknown data input reference: decision {identifier} -> {ref}")
                elif field == "next_decision_ids":
                    for ref in refs:
                        if ref not in decisions:
                            errors.append(f"unknown next decision reference: {identifier} -> {ref}")


def _validate_graph(document: dict[str, Any], errors: list[str]) -> None:
    nodes = _index(_items(document, "nodes", "experience_graph.yaml", errors), "graph node", errors)
    edges = _items(document, "edges", "experience_graph.yaml", errors)
    entries = document.get("entry_node_ids")
    if not isinstance(entries, list) or not entries or any(not isinstance(x, str) or not x for x in entries):
        errors.append("experience_graph entry_node_ids must be a non-empty string list")
        entries = []
    for entry in entries:
        if entry not in nodes:
            errors.append(f"unknown graph entry: {entry}")

    outgoing: dict[str, list[str]] = defaultdict(list)
    incoming: dict[str, list[str]] = defaultdict(list)
    action_ids: set[str] = set()
    for index, edge in enumerate(edges):
        context = f"edge[{index}]"
        for field in EDGE_FIELDS:
            if field not in edge:
                errors.append(f"{context} missing required field: {field}")
        action = edge.get("action_id")
        if not isinstance(action, str) or not action:
            errors.append(f"{context} action_id must be non-empty")
        elif action in action_ids:
            errors.append(f"duplicate graph action id: {action}")
        else:
            action_ids.add(action)
        source, destination = edge.get("source"), edge.get("destination")
        if source not in nodes:
            errors.append(f"unknown edge source: {source}")
        if destination not in nodes:
            errors.append(f"unknown edge destination: {destination}")
        fallback = edge.get("fallback")
        if fallback not in nodes:
            errors.append(f"unknown edge fallback: {fallback}")
        if source in nodes and destination in nodes:
            outgoing[source].append(destination)
            incoming[destination].append(source)
        if not isinstance(edge.get("visible_label_intent"), str) or not edge.get("visible_label_intent", "").strip():
            errors.append(f"{context} visible label must be non-empty")
        for field in ("guard", "data_effect", "back_semantics"):
            if field in edge and (not isinstance(edge[field], str) or not edge[field].strip()):
                errors.append(f"{context}.{field} must be non-empty")

    terminal_kinds = document.get("terminal_kinds")
    if not isinstance(terminal_kinds, list) or not terminal_kinds or any(not isinstance(x, str) or not x for x in terminal_kinds):
        errors.append("experience_graph terminal_kinds must be a non-empty string list")
        terminal_kinds = []
    for identifier, node in nodes.items():
        for field in ("purpose", "learning_outcome", "kind", "view_binding"):
            if not isinstance(node.get(field), str) or not node.get(field, "").strip():
                errors.append(f"graph node {identifier}.{field} must be non-empty")
        _list_of_strings(node, "modes", f"graph node {identifier}", errors)
        terminal_kind = node.get("kind")
        if terminal_kind not in terminal_kinds and not outgoing.get(identifier):
            errors.append(f"nonterminal node has no visible action: {identifier}")

    reachable: set[str] = set()
    queue = deque(entry for entry in entries if entry in nodes)
    while queue:
        node = queue.popleft()
        if node in reachable:
            continue
        reachable.add(node)
        queue.extend(outgoing[node])
    for identifier in nodes.keys() - reachable:
        errors.append(f"unreachable graph node: {identifier}")

    safe = {identifier for identifier, node in nodes.items() if node.get("kind") in terminal_kinds}
    can_exit = set(safe)
    queue = deque(safe)
    while queue:
        node = queue.popleft()
        for predecessor in incoming[node]:
            if predecessor not in can_exit:
                can_exit.add(predecessor)
                queue.append(predecessor)
    for identifier in reachable - can_exit:
        errors.append(f"graph node cannot reach a safe terminal: {identifier}")

    chat = document.get("chat")
    if not isinstance(chat, dict):
        errors.append("experience_graph chat must be a mapping")
        chat = {}
    chat_actions = chat.get("allowed_action_ids")
    if not isinstance(chat_actions, list) or any(not isinstance(x, str) or not x for x in chat_actions):
        errors.append("experience_graph chat_action_ids must be a string list")
    else:
        for action in chat_actions:
            if action not in action_ids:
                errors.append(f"unregistered chat action: {action}")


def validate(root: Path) -> list[str]:
    errors: list[str] = []
    documents = {name: _load(root, name, errors) for name in FILES}

    audience = documents["audience.yaml"]
    for field in ("audience_hypothesis", "universal_floor", "progressive_depth", "expert_escape", "comprehension_evidence", "forbidden_patterns"):
        if field not in audience:
            errors.append(f"audience.yaml missing required field: {field}")
    _index(_items(audience, "progressive_depth", "audience.yaml", errors), "progressive depth", errors)
    concepts = _index(_items(documents["concepts.yaml"], "concepts", "concepts.yaml", errors), "concept", errors)
    _validate_concepts(concepts, errors)

    data = _index(
        _items(documents["claims_and_data.yaml"], "items", "claims_and_data.yaml", errors),
        "claim/data",
        errors,
    )
    for identifier, item in data.items():
        for field, label in (
            ("provenance", "provenance"),
            ("missing_behavior", "missing behavior"),
        ):
            if not isinstance(item.get(field), str) or not item.get(field, "").strip():
                errors.append(f"claim/data {identifier} requires non-empty {label}")
        freshness = item.get("freshness_days")
        if not isinstance(freshness, int) or isinstance(freshness, bool) or freshness < 0:
            errors.append(f"claim/data {identifier} requires non-negative freshness_days")

    decisions = _index(_items(documents["decisions.yaml"], "decisions", "decisions.yaml", errors), "decision", errors)
    _validate_decisions(decisions, concepts, set(data), errors)
    _validate_graph(documents["experience_graph.yaml"], errors)

    dependencies = _index(
        _items(documents["legacy_reuse.yaml"], "assets", "legacy_reuse.yaml", errors),
        "legacy dependency",
        errors,
    )
    for identifier, dependency in dependencies.items():
        disposition = dependency.get("disposition")
        if disposition not in LEGACY_DISPOSITIONS:
            errors.append(f"invalid legacy disposition for {identifier}: {disposition}")
        if not isinstance(dependency.get("evidence"), str) or not dependency.get("evidence", "").strip():
            errors.append(f"legacy dependency {identifier} requires evidence")
        for field in ("path", "forbidden_dependency", "status"):
            if not isinstance(dependency.get(field), str) or not dependency.get(field, "").strip():
                errors.append(f"legacy dependency {identifier} requires non-empty {field}")
        if disposition == "unknown" and dependency.get("status") != "not_reused":
            errors.append(f"unknown dependency used by Next: {identifier}")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path.cwd())
    args = parser.parse_args()
    errors = validate(args.root.resolve())
    if errors:
        for error in errors:
            print(f"ERROR mint_next_batch4_architecture_guard: {error}", file=sys.stderr)
        return 1
    print("OK mint_next_batch4_architecture_guard: structural registries are internally closed.", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
