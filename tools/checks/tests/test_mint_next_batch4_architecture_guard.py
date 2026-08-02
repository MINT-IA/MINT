from __future__ import annotations

import copy
import subprocess
import sys
from pathlib import Path

import pytest
import yaml


REPO = Path(__file__).resolve().parents[3]
SCRIPT = REPO / "tools/checks/mint_next_batch4_architecture_guard.py"
BASE = Path("product/mint_next/batch4")


def valid_documents() -> dict[str, dict]:
    return {
        "batch.yaml": {"schema_version": 1, "status": "draft_unproven"},
        "audience.yaml": {
            "audience_hypothesis": {"status": "hypothesis", "statement": "Works under stress"},
            "universal_floor": {"sequence": ["consequence"]},
            "progressive_depth": [{"id": "n0", "intent": "consequence"}],
            "expert_escape": ["sources"],
            "comprehension_evidence": ["choice"],
            "forbidden_patterns": ["shaming"],
        },
        "concepts.yaml": {
            "schema_version": 1,
            "concepts": [
                {"id": "cashflow", "prerequisites": []},
                {"id": "tax", "prerequisites": ["cashflow"]},
            ],
        },
        "decisions.yaml": {
            "schema_version": 1,
            "decisions": [
                {
                    "id": "fund_3a",
                    "human_question": "Should I fund 3a?",
                    "triggers": ["annual_review"],
                    "concept_ids": ["tax"],
                    "eligibility": "resident_ch",
                    "minimum_input_ids": ["income"],
                    "missing_data_behavior": "withhold",
                    "scenario_ids": ["with_without"],
                    "tradeoffs": ["liquidity"],
                    "calculation_contract": "deterministic_tax_delta",
                    "compliance_boundary": "education_not_advice",
                    "receipt": "decision_receipt",
                    "next_decision_ids": [],
                    "next_action": "one action",
                    "return_and_correction": "preserve",
                    "not_applicable_behavior": "record reason",
                }
            ],
        },
        "experience_graph.yaml": {
            "schema_version": 1,
            "entry_node_ids": ["start"],
            "terminal_kinds": ["safe_exit", "success"],
            "nodes": [
                {
                    "id": "start",
                    "purpose": "Orient",
                    "learning_outcome": "Know the question",
                    "kind": "entry",
                    "view_binding": "next.start",
                    "modes": ["example", "missing", "error", "offline", "stale"],
                },
                {
                    "id": "safe_exit",
                    "purpose": "Leave safely",
                    "learning_outcome": "Know what remains",
                    "kind": "safe_exit",
                    "view_binding": "next.exit",
                    "modes": ["saved"],
                },
            ],
            "edges": [
                {
                    "action_id": "exit_safely",
                    "source": "start",
                    "destination": "safe_exit",
                    "visible_label_intent": "Stop for now",
                    "guard": "always",
                    "data_effect": "none",
                    "back_semantics": "return_to_start",
                    "fallback": "safe_exit",
                }
            ],
            "chat": {"allowed_action_ids": ["exit_safely"]},
        },
        "claims_and_data.yaml": {
            "items": [
                {
                    "id": "income",
                    "provenance": "user_declared",
                    "freshness_days": 365,
                    "missing_behavior": "ask_or_use_labeled_example",
                }
            ],
        },
        "legacy_reuse.yaml": {
            "boundary": {"next_imports_legacy_ui": False},
            "assets": [
                {
                    "id": "tax_engine",
                    "disposition": "adapt_behind_adapter",
                    "path": "legacy/tax_engine",
                    "evidence": "targeted audit required",
                    "forbidden_dependency": "legacy UI",
                    "status": "candidate_not_reuse_approved",
                }
            ],
        },
    }


def write_documents(root: Path, documents: dict[str, dict]) -> None:
    base = root / BASE
    base.mkdir(parents=True)
    for name, document in documents.items():
        (base / name).write_text(yaml.safe_dump(document, sort_keys=False))


def run(root: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(SCRIPT), "--root", str(root)],
        capture_output=True,
        text=True,
    )


def test_accepts_complete_closed_graph(tmp_path: Path) -> None:
    write_documents(tmp_path, valid_documents())
    result = run(tmp_path)
    assert result.returncode == 0, result.stderr


@pytest.mark.parametrize(
    ("mutation", "message"),
    [
        (lambda d: d.pop("concepts.yaml"), "missing registry"),
        (lambda d: d["concepts.yaml"]["concepts"].append({"id": "tax", "prerequisites": []}), "duplicate concept id"),
        (lambda d: d["concepts.yaml"]["concepts"][1].update(prerequisites=["ghost"]), "unknown concept prerequisite"),
        (lambda d: d["concepts.yaml"]["concepts"][0].update(prerequisites=["tax"]), "concept prerequisite cycle"),
        (lambda d: d["decisions.yaml"]["decisions"][0].pop("tradeoffs"), "missing required field"),
        (lambda d: d["decisions.yaml"]["decisions"][0].update(concept_ids=["ghost"]), "unknown concept reference"),
        (lambda d: d["experience_graph.yaml"]["entry_node_ids"].append("ghost"), "unknown graph entry"),
        (lambda d: d["experience_graph.yaml"]["edges"][0].update(destination="ghost"), "unknown edge destination"),
        (lambda d: d["experience_graph.yaml"]["edges"][0].update(fallback="ghost"), "unknown edge fallback"),
        (lambda d: d["experience_graph.yaml"]["nodes"].append({"id": "orphan", "purpose": "x", "learning_outcome": "x", "kind": "safe_exit", "view_binding": "next.orphan", "modes": ["saved"]}), "unreachable graph node"),
        (lambda d: d["experience_graph.yaml"]["edges"].clear(), "nonterminal node has no visible action"),
        (lambda d: d["experience_graph.yaml"]["nodes"][1].update(kind="entry"), "cannot reach a safe terminal"),
        (lambda d: d["experience_graph.yaml"]["edges"][0].update(visible_label_intent=""), "visible label"),
        (lambda d: d["claims_and_data.yaml"]["items"][0].pop("provenance"), "provenance"),
        (lambda d: d["claims_and_data.yaml"]["items"][0].pop("freshness_days"), "freshness"),
        (lambda d: d["claims_and_data.yaml"]["items"][0].pop("missing_behavior"), "missing behavior"),
        (lambda d: d["legacy_reuse.yaml"]["assets"][0].update(disposition="unknown"), "unknown dependency used by next"),
        (lambda d: d["legacy_reuse.yaml"]["assets"][0].update(disposition="magically_safe"), "invalid legacy disposition"),
        (lambda d: d["experience_graph.yaml"].update(chat={"allowed_action_ids": ["invented"]}), "unregistered chat action"),
    ],
)
def test_rejects_hostile_mutations(tmp_path: Path, mutation, message: str) -> None:
    documents = copy.deepcopy(valid_documents())
    mutation(documents)
    write_documents(tmp_path, documents)
    result = run(tmp_path)
    assert result.returncode == 1
    assert message in result.stderr.lower(), result.stderr


def test_rejects_non_mapping_yaml_and_wrong_schema(tmp_path: Path) -> None:
    documents = valid_documents()
    documents["audience.yaml"] = []  # type: ignore[assignment]
    documents["batch.yaml"]["schema_version"] = 2
    write_documents(tmp_path, documents)
    result = run(tmp_path)
    assert result.returncode == 1
    assert "yaml mapping" in result.stderr.lower()
    assert "schema_version" in result.stderr
