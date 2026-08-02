#!/usr/bin/env python3
"""Fail-closed structural guard for the canonical MINT Next Batch 4 maps.

This guard validates architecture consistency.  It does not establish that the
financial content is correct, complete, user-tested, or compliant.
"""
from __future__ import annotations

import argparse
import hashlib
import re
import sys
from collections import defaultdict, deque
from pathlib import Path
from typing import Any

import yaml


BASE = Path("product/mint_next/batch4")
FILES = (
    "batch.yaml",
    "source-inventory.yaml",
    "architecture_conflicts.yaml",
    "calculation_contracts.yaml",
    "formula_contracts.yaml",
    "official_sources.yaml",
    "regulatory_boundaries.yaml",
    "domain_coverage.yaml",
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
    "analytics_event",
    "visible_label",
)
LEGACY_DISPOSITIONS = {
    "reuse_as_is",
    "adapt_behind_adapter",
    "rewrite",
    "retire",
    "unknown",
}
SAFE_TERMINALS = {"success", "safe_exit", "saved"}
REQUIRED_NONTERMINAL_MODES = {
    "example", "personal", "missing", "stale", "offline", "error", "corrected", "saved",
}
UNIVERSAL_SEQUENCE = ["concrete_consequence", "chf_example", "one_cause_effect", "one_action_or_choice", "visible_limits"]
PROGRESSIVE_DEPTH = {
    "n0": "consequence", "n1": "simple_why", "n2": "visual_comparison",
    "n3": "editable_assumptions", "n4": "calculation_sources_limits",
}
REQUIRED_EXPERT_ESCAPES = {"see_calculation", "edit_assumptions", "see_sources", "compare_scenarios"}
LEARNING_VARIANT_BY_DECISION = {
    "annual_tax": "planning", "pillar_3a": "planning", "free_investing": "planning",
    "home_purchase": "planning", "lpp_buyback": "planning", "retirement_prepare": "planning",
    "retirement_live": "planning", "stability_first": "urgent", "work_incapacity": "urgent",
    "unemployment_pause": "urgent", "salary_protection": "protection", "child_or_dependent": "protection",
    "employer_change": "protection", "self_employment": "protection", "couple_change": "sensitive_life_event",
    "separation_divorce": "sensitive_life_event", "inheritance_received": "sensitive_life_event",
    "estate_incapacity": "sensitive_life_event",
}
EXPECTED_LEGACY_BOUNDARY = {
    "next_imports_legacy_ui": False,
    "legacy_imports_next": False,
    "next_default_enabled": False,
    "kill_switch_required": True,
    "fallback_until_equivalence_and_rollback_proven": True,
}


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
        for field in ("plain_language_question", "mental_model", "simple_why", "chf_example", "visual"):
            if not isinstance(concept.get(field), str) or not concept.get(field, "").strip():
                errors.append(f"concept {identifier}.{field} must be non-empty")
        if not _list_of_strings(concept, "misconceptions", f"concept {identifier}", errors):
            errors.append(f"concept {identifier}.misconceptions must not be empty")
        example = concept.get("chf_example", "")
        if isinstance(example, str) and len(re.findall(r"CHF\s*[0-9][0-9’'.,]*", example)) < 2:
            errors.append(f"concept {identifier}.chf_example requires CHF and at least two numeric amounts")
        glossary = concept.get("glossary_terms")
        if not isinstance(glossary, list) or not glossary:
            errors.append(f"concept {identifier}.glossary_terms must be a non-empty list")
        else:
            for index, term in enumerate(glossary):
                if not isinstance(term, dict) or not all(isinstance(term.get(x), str) and term.get(x).strip() for x in ("term", "plain_language")):
                    errors.append(f"concept {identifier}.glossary_terms[{index}] is incomplete")
        evidence = concept.get("comprehension_evidence")
        if not isinstance(evidence, dict) or not all(
            isinstance(evidence.get(x), str) and evidence.get(x).strip() for x in ("prompt", "acceptable_answer")
        ) or evidence.get("never_score_or_label") is not True:
            errors.append(f"concept {identifier}.comprehension_evidence is incomplete")
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
    edge_by_action: dict[str, dict[str, Any]] = {}
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
            edge_by_action[action] = edge
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
        for field in ("guard", "data_effect", "back_semantics", "analytics_event", "visible_label"):
            if field in edge and (not isinstance(edge[field], str) or not edge[field].strip()):
                errors.append(f"{context}.{field} must be non-empty")

    terminal_kinds = document.get("terminal_kinds")
    if not isinstance(terminal_kinds, list) or not terminal_kinds or any(not isinstance(x, str) or not x for x in terminal_kinds):
        errors.append("experience_graph terminal_kinds must be a non-empty string list")
        terminal_kinds = []
    view_bindings: set[str] = set()
    for identifier, node in nodes.items():
        for field in ("purpose", "learning_outcome", "kind", "view_binding"):
            if not isinstance(node.get(field), str) or not node.get(field, "").strip():
                errors.append(f"graph node {identifier}.{field} must be non-empty")
        modes = set(_list_of_strings(node, "modes", f"graph node {identifier}", errors))
        binding = node.get("view_binding")
        if binding in view_bindings:
            errors.append(f"duplicate graph view_binding: {binding}")
        elif isinstance(binding, str):
            view_bindings.add(binding)
        terminal_kind = node.get("kind")
        if node.get("terminal_kind") != (terminal_kind if terminal_kind in terminal_kinds else "nonterminal"):
            errors.append(f"graph node {identifier} terminal_kind contradicts kind")
        if terminal_kind not in terminal_kinds and not REQUIRED_NONTERMINAL_MODES.issubset(modes):
            missing_modes = sorted(REQUIRED_NONTERMINAL_MODES - modes)
            errors.append(f"graph node {identifier} missing required modes: {missing_modes}")
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

    required_actions = {
        "leave_question": ("question", "safe_exit", "none"),
        "explain_simply": ("question", "simple_why", "none"),
        "show_contextual_example": ("simple_why", "example", "none"),
        "expert_details_now": ("question", "receipt", "none"),
        "return_today_without_pressure": ("safe_exit", "today_entry", "none"),
        "choose_reminder": ("safe_exit", "today_entry", "explicit_save_or_edit"),
        "dismiss_suggestion": ("safe_exit", "today_entry", "explicit_save_or_edit"),
        "change_subject": ("safe_exit", "today_entry", "none"),
    }
    for action, contract in required_actions.items():
        edge = edge_by_action.get(action)
        if not edge or (edge.get("source"), edge.get("destination"), edge.get("data_effect")) != contract:
            errors.append(f"required pedagogy/soft-exit action contract mismatch: {action}")

    chat = document.get("chat")
    if not isinstance(chat, dict):
        errors.append("experience_graph chat must be a mapping")
        chat = {}
    chat_actions = chat.get("allowed_action_ids")
    if not isinstance(chat_actions, list) or any(not isinstance(x, str) or not x for x in chat_actions):
        errors.append("experience_graph chat_action_ids must be a string list")
    else:
        if len(chat_actions) != len(set(chat_actions)):
            errors.append("duplicate registered chat action")
        for action in chat_actions:
            if action not in action_ids:
                errors.append(f"unregistered chat action: {action}")
        policy = chat.get("action_policy")
        if not isinstance(policy, dict):
            errors.append("experience_graph chat.action_policy must be a mapping")
        else:
            categories = ("read_only", "navigation_only", "requires_explicit_user_confirmation")
            categorized: list[str] = []
            for category in categories:
                categorized.extend(_list_of_strings(policy, category, "chat.action_policy", errors))
            if len(categorized) != len(set(categorized)):
                errors.append("chat actions must belong to exactly one policy category")
            if set(categorized) != set(chat_actions):
                errors.append("chat action policy must classify every and only allowed action")
            navigation = set(policy.get("navigation_only", []))
            confirmed = set(policy.get("requires_explicit_user_confirmation", []))
            if "leave_question" not in navigation or "leave_question" in confirmed:
                errors.append("leave_question must be frictionless navigation without confirmation")
            allowed_effects = set(_list_of_strings(policy, "allowed_data_effects", "chat.action_policy", errors))
            for action in chat_actions:
                edge = edge_by_action.get(action, {})
                if edge.get("data_effect") not in allowed_effects:
                    errors.append(f"chat action has forbidden data effect: {action}")
            non_writing = set(policy.get("read_only", [])) | set(policy.get("navigation_only", []))
            confirmed = set(policy.get("requires_explicit_user_confirmation", []))
            for action in non_writing:
                if edge_by_action.get(action, {}).get("data_effect") != "none":
                    errors.append(f"unconfirmed chat action writes state: {action}")
            for action in confirmed:
                if edge_by_action.get(action, {}).get("data_effect") != "explicit_save_or_edit":
                    errors.append(f"confirmed chat action lacks explicit write effect: {action}")
            for field in ("authorization",):
                if not isinstance(policy.get(field), str) or not policy.get(field, "").strip():
                    errors.append(f"chat.action_policy.{field} must be non-empty")
            _list_of_strings(policy, "continuity_fields", "chat.action_policy", errors)


def _validate_sources(root: Path, document: dict[str, Any], errors: list[str]) -> set[str]:
    if document.get("schema_version") != 1:
        errors.append("source-inventory.yaml schema_version must be 1")
    sources = _items(document, "sources", "source-inventory.yaml", errors)
    seen: set[str] = set()
    for index, source in enumerate(sources):
        path, expected, role = source.get("path"), source.get("sha256"), source.get("role")
        if not isinstance(path, str) or not path or path in seen:
            errors.append(f"source[{index}] path must be unique and non-empty")
            continue
        seen.add(path)
        target = root / path
        if not target.is_file():
            errors.append(f"source inventory path missing: {path}")
        elif not isinstance(expected, str) or hashlib.sha256(target.read_bytes()).hexdigest() != expected:
            errors.append(f"source inventory hash drift: {path}")
        if not isinstance(role, str) or not role.strip():
            errors.append(f"source inventory role missing: {path}")
    return seen


def _validate_conflicts(
    document: dict[str, Any], promoted: bool, source_paths: set[str], errors: list[str]
) -> None:
    if document.get("schema_version") != 1:
        errors.append("architecture_conflicts.yaml schema_version must be 1")
    conflicts = _index(_items(document, "conflicts", "architecture_conflicts.yaml", errors), "architecture conflict", errors)
    for identifier, conflict in conflicts.items():
        for field in ("severity", "status", "conflict", "resolution_required"):
            if not isinstance(conflict.get(field), str) or not conflict.get(field, "").strip():
                errors.append(f"architecture conflict {identifier}.{field} must be non-empty")
        for path in _list_of_strings(conflict, "authority_paths", f"architecture conflict {identifier}", errors):
            if path not in source_paths:
                errors.append(f"architecture conflict authority absent from source inventory: {identifier} -> {path}")
        if promoted and conflict.get("status") != "resolved":
            errors.append(f"promotion blocked by unresolved architecture conflict: {identifier}")


def _validate_domain_contracts(
    documents: dict[str, dict[str, Any]], decisions: dict[str, dict[str, Any]], data_ids: set[str], errors: list[str]
) -> None:
    source_doc = documents["official_sources.yaml"]
    sources = _index(_items(source_doc, "sources", "official_sources.yaml", errors), "official source", errors)
    if not sources:
        errors.append("official source registry must not be empty")
    for identifier, source in sources.items():
        for field in ("authority", "title", "jurisdiction", "version_basis"):
            if not isinstance(source.get(field), str) or not source.get(field, "").strip():
                errors.append(f"official source {identifier}.{field} must be non-empty")
        locations = [source.get("url"), source.get("url_template")]
        if sum(isinstance(x, str) and bool(x.strip()) for x in locations) != 1:
            errors.append(f"official source {identifier} requires exactly one url or url_template")

    regulatory = documents["regulatory_boundaries.yaml"]
    boundaries = _index(_items(regulatory, "boundaries", "regulatory_boundaries.yaml", errors), "regulatory boundary", errors)
    for source_id in _list_of_strings(regulatory, "source_ids", "regulatory_boundaries.yaml", errors):
        if source_id not in sources:
            errors.append(f"unknown regulatory source: {source_id}")

    contracts_doc = documents["calculation_contracts.yaml"]
    formula_doc = documents["formula_contracts.yaml"]
    formulas = _index(_items(formula_doc, "formulas", "formula_contracts.yaml", errors), "formula contract", errors)
    if not formulas:
        errors.append("formula contract registry must not be empty")
    for identifier, formula in formulas.items():
        if formula.get("status") not in {"unimplemented_blocking", "implemented_reviewed"}:
            errors.append(f"invalid formula status: {identifier}")
        for field in ("owner", "input_units", "output_units", "rounding", "implementation_gate"):
            if not isinstance(formula.get(field), str) or not formula.get(field, "").strip():
                errors.append(f"formula contract {identifier}.{field} must be non-empty")
        if not _list_of_strings(formula, "invariants", f"formula contract {identifier}", errors):
            errors.append(f"formula contract {identifier}.invariants must not be empty")
    contracts = _index(_items(contracts_doc, "contracts", "calculation_contracts.yaml", errors), "calculation contract", errors)
    bound_decisions: dict[str, str] = {}
    for identifier, contract in contracts.items():
        refs: list[str] = []
        if "decision_id" in contract:
            refs = [contract.get("decision_id")] if isinstance(contract.get("decision_id"), str) else []
        elif "decision_ids" in contract:
            refs = _list_of_strings(contract, "decision_ids", f"calculation contract {identifier}", errors)
        if not refs:
            errors.append(f"calculation contract {identifier} requires decision_id(s)")
        for decision_id in refs:
            if decision_id not in decisions:
                errors.append(f"unknown calculation decision: {identifier} -> {decision_id}")
            elif decision_id in bound_decisions:
                errors.append(f"decision has multiple calculation contracts: {decision_id}")
            else:
                bound_decisions[decision_id] = identifier
        for input_id in _list_of_strings(contract, "required_inputs", f"calculation contract {identifier}", errors):
            if input_id not in data_ids:
                errors.append(f"unknown calculation input: {identifier} -> {input_id}")
        for source_id in _list_of_strings(contract, "source_ids", f"calculation contract {identifier}", errors):
            if source_id not in sources:
                errors.append(f"unknown calculation source: {identifier} -> {source_id}")
        for field in ("outputs", "formula_ids"):
            values = _list_of_strings(contract, field, f"calculation contract {identifier}", errors)
            if not values:
                errors.append(f"calculation contract {identifier}.{field} must not be empty")
            if field == "formula_ids":
                for formula_id in values:
                    if formula_id not in formulas:
                        errors.append(f"unknown formula contract: {identifier} -> {formula_id}")
    for decision_id, decision in decisions.items():
        contract_id = decision.get("calculation_contract")
        if contract_id not in contracts or bound_decisions.get(decision_id) != contract_id:
            errors.append(f"decision calculation contract mismatch: {decision_id} -> {contract_id}")
        elif not set(contracts[contract_id].get("required_inputs", [])) <= set(decision.get("minimum_input_ids", [])):
            errors.append(f"decision minimum inputs do not cover calculation contract: {decision_id}")
        if decision.get("compliance_boundary") not in boundaries:
            errors.append(f"unknown decision regulatory boundary: {decision_id} -> {decision.get('compliance_boundary')}")

    domain_doc = documents["domain_coverage.yaml"]
    allowed = set(_list_of_strings(domain_doc, "dispositions", "domain_coverage.yaml", errors))
    domains = _index(_items(domain_doc, "domains", "domain_coverage.yaml", errors), "domain", errors)
    if not domains:
        errors.append("domain coverage registry must not be empty")
    for identifier, domain in domains.items():
        if domain.get("disposition") not in allowed:
            errors.append(f"invalid domain disposition: {identifier}")
        decision_refs = _list_of_strings(domain, "decision_ids", f"domain {identifier}", errors)
        for decision_id in decision_refs:
            if decision_id not in decisions:
                errors.append(f"unknown domain decision: {identifier} -> {decision_id}")
        if domain.get("disposition") == "covered_by_decision" and not decision_refs:
            errors.append(f"covered domain lacks decision: {identifier}")
        if domain.get("disposition") != "covered_by_decision" and not domain.get("missing_contract"):
            errors.append(f"non-covered domain lacks explicit missing_contract: {identifier}")


def validate(root: Path) -> list[str]:
    errors: list[str] = []
    documents = {name: _load(root, name, errors) for name in FILES}
    batch = documents["batch.yaml"]
    status = batch.get("status")
    if status not in {"draft_unproven", "promoted"}:
        errors.append(f"invalid batch status: {status}")
    promoted = status == "promoted"
    receipt = batch.get("promotion_receipt")
    if promoted and (not isinstance(receipt, dict) or not receipt.get("exact_head")):
        errors.append("promoted batch requires promotion_receipt.exact_head")
    source_paths = _validate_sources(root, documents["source-inventory.yaml"], errors)
    _validate_conflicts(documents["architecture_conflicts.yaml"], promoted, source_paths, errors)

    audience = documents["audience.yaml"]
    for field in ("audience_hypothesis", "universal_floor", "progressive_depth", "expert_escape", "comprehension_evidence", "forbidden_patterns"):
        if field not in audience:
            errors.append(f"audience.yaml missing required field: {field}")
    floor = audience.get("universal_floor")
    if not isinstance(floor, dict):
        errors.append("audience universal_floor must be a mapping")
        floor = {}
    if floor.get("sequence") != UNIVERSAL_SEQUENCE:
        errors.append("audience universal_floor.sequence must match the canonical order")
    maximum = floor.get("max_primary_numbers")
    if not isinstance(maximum, int) or isinstance(maximum, bool) or not 1 <= maximum <= 3:
        errors.append("audience universal_floor.max_primary_numbers must be between 1 and 3")
    for flag in ("amounts_before_percentages", "example_before_personalization", "color_never_only_signal",
                 "plain_language_before_technical_term", "sensitive_event_examples_must_be_contextual"):
        if floor.get(flag) is not True:
            errors.append(f"audience universal_floor.{flag} must be true")
    depths = _index(_items(audience, "progressive_depth", "audience.yaml", errors), "progressive depth", errors)
    if {identifier: item.get("intent") for identifier, item in depths.items()} != PROGRESSIVE_DEPTH:
        errors.append("audience progressive_depth must define canonical n0..n4 intents")
    escapes = set(_list_of_strings(audience, "expert_escape", "audience", errors))
    if not REQUIRED_EXPERT_ESCAPES <= escapes:
        errors.append("audience expert_escape lacks required one-gesture capabilities")
    falsification = audience.get("falsification_protocol")
    if not isinstance(falsification, dict):
        errors.append("audience falsification_protocol must be a mapping")
    else:
        for field in ("unit_of_analysis", "thresholds"):
            if not isinstance(falsification.get(field), str) or not falsification.get(field, "").strip():
                errors.append(f"audience falsification_protocol.{field} must be non-empty")
        for field in ("participant_coverage", "rejection_conditions", "privacy"):
            if not _list_of_strings(falsification, field, "audience falsification_protocol", errors):
                errors.append(f"audience falsification_protocol.{field} must not be empty")
        signals = _index(_items(falsification, "signals", "falsification_protocol", errors), "falsification signal", errors)
        if not signals:
            errors.append("audience falsification signals must not be empty")
        for identifier, signal in signals.items():
            if not isinstance(signal.get("measure"), str) or not signal.get("measure", "").strip():
                errors.append(f"falsification signal {identifier}.measure must be non-empty")
    concepts = _index(_items(documents["concepts.yaml"], "concepts", "concepts.yaml", errors), "concept", errors)
    if not concepts:
        errors.append("concept registry must not be empty")
    _validate_concepts(concepts, errors)

    data = _index(
        _items(documents["claims_and_data.yaml"], "items", "claims_and_data.yaml", errors),
        "claim/data",
        errors,
    )
    if not data:
        errors.append("claims/data registry must not be empty")
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
    if not decisions:
        errors.append("decision registry must not be empty")
    _validate_decisions(decisions, concepts, set(data), errors)
    _validate_domain_contracts(documents, decisions, set(data), errors)
    graph = documents["experience_graph.yaml"]
    _validate_graph(graph, errors)
    template = graph.get("decision_template")
    if not isinstance(template, dict):
        errors.append("experience_graph decision_template must be a mapping")
    else:
        bound = set(_list_of_strings(template, "applies_to_decision_ids", "decision_template", errors))
        if bound != set(decisions):
            errors.append("decision_template must bind every and only registered decision")
        for field in ("binding_contract", "unbound_decision_behavior"):
            if not isinstance(template.get(field), str) or not template.get(field, "").strip():
                errors.append(f"decision_template.{field} must be non-empty")
        _list_of_strings(template, "required_context", "decision_template", errors)
    variants = graph.get("learning_variants")
    if not isinstance(variants, dict) or not variants:
        errors.append("experience_graph learning_variants must be a non-empty mapping")
        variants = {}
    for identifier, variant in variants.items():
        if not isinstance(variant, dict) or not all(
            isinstance(variant.get(field), str) and variant.get(field).strip()
            for field in ("example_intent", "tone")
        ):
            errors.append(f"learning variant is incomplete: {identifier}")
    for decision_id, decision in decisions.items():
        if decision.get("learning_variant") not in variants:
            errors.append(f"unknown decision learning variant: {decision_id} -> {decision.get('learning_variant')}")
        expected_variant = LEARNING_VARIANT_BY_DECISION.get(decision_id)
        if expected_variant is not None and decision.get("learning_variant") != expected_variant:
            errors.append(f"decision learning variant mapping mismatch: {decision_id} must be {expected_variant}")

    legacy = documents["legacy_reuse.yaml"]
    boundary = legacy.get("boundary")
    if not isinstance(boundary, dict):
        errors.append("legacy_reuse boundary must be a mapping")
        boundary = {}
    for field, expected in EXPECTED_LEGACY_BOUNDARY.items():
        if boundary.get(field) is not expected:
            errors.append(f"legacy boundary violation: {field} must be {expected}")
    dependencies = _index(
        _items(legacy, "assets", "legacy_reuse.yaml", errors),
        "legacy dependency",
        errors,
    )
    if not dependencies:
        errors.append("legacy dependency registry must not be empty")
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
        if disposition == "reuse_as_is" and dependency.get("status") != boundary.get("approved_reuse_status"):
            errors.append(f"legacy reuse_as_is lacks approved exact evidence: {identifier}")
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
