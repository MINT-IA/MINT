from __future__ import annotations

import copy
import hashlib
import subprocess
import sys
from pathlib import Path

import pytest
import yaml


REPO = Path(__file__).resolve().parents[3]
SCRIPT = REPO / "tools/checks/mint_next_batch4_architecture_guard.py"
BASE = Path("product/mint_next/batch4")


def valid_documents() -> dict[str, dict]:
    documents = {
        "batch.yaml": {"schema_version": 1, "status": "draft_unproven", "promotion_receipt": None},
        "source-inventory.yaml": {
            "schema_version": 1,
            "sources": [{"path": "SOURCE.txt", "sha256": hashlib.sha256(b"source\n").hexdigest(), "role": "test_authority"}],
        },
        "architecture_conflicts.yaml": {"schema_version": 1, "conflicts": []},
        "official_sources.yaml": {"sources": [{
            "id": "tax_law", "authority": "Authority", "title": "Law", "url": "https://example.test/law",
            "jurisdiction": "CH", "version_basis": "effective_date",
        }]},
        "regulatory_boundaries.yaml": {
            "boundaries": [{"id": "education_only"}], "source_ids": ["tax_law"],
        },
        "calculation_contracts.yaml": {"contracts": [{
            "id": "tax_calc", "decision_id": "pillar_3a", "required_inputs": ["income"],
            "outputs": ["tax_delta"], "formula_ids": ["tax_v1"], "source_ids": ["tax_law"],
        }]},
        "formula_contracts.yaml": {"formulas": [{
            "id": "tax_v1", "status": "unimplemented_blocking", "owner": "test", "input_units": "CHF",
            "output_units": "CHF", "rounding": "none", "invariants": ["no personal output"],
            "implementation_gate": "review",
        }]},
        "domain_coverage.yaml": {
            "dispositions": ["covered_by_decision", "official_handoff"],
            "domains": [{"id": "tax", "disposition": "covered_by_decision", "decision_ids": ["pillar_3a"], "missing_contract": None}],
        },
        "audience.yaml": {
            "audience_hypothesis": {"status": "hypothesis", "statement": "Works under stress"},
            "universal_floor": {
                "sequence": ["concrete_consequence", "chf_example", "one_cause_effect", "one_action_or_choice", "visible_limits"],
                "max_primary_numbers": 3, "amounts_before_percentages": True,
                "example_before_personalization": True, "color_never_only_signal": True,
                "plain_language_before_technical_term": True, "sensitive_event_examples_must_be_contextual": True,
            },
            "progressive_depth": [
                {"id": "n0", "intent": "consequence"}, {"id": "n1", "intent": "simple_why"},
                {"id": "n2", "intent": "visual_comparison"}, {"id": "n3", "intent": "editable_assumptions"},
                {"id": "n4", "intent": "calculation_sources_limits"},
            ],
            "expert_escape": ["see_calculation", "edit_assumptions", "see_sources", "compare_scenarios"],
            "comprehension_evidence": ["choice"],
            "forbidden_patterns": ["shaming"],
            "falsification_protocol": {
                "unit_of_analysis": "task", "thresholds": "preregister",
                "participant_coverage": ["low confidence"], "rejection_conditions": ["cannot explain"],
                "privacy": ["aggregate only"], "signals": [{"id": "understood", "measure": "teach back"}],
            },
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
                    "id": "pillar_3a",
                    "human_question": "Should I fund 3a?",
                    "triggers": ["annual_review"],
                    "concept_ids": ["tax"],
                    "eligibility": "resident_ch",
                    "minimum_input_ids": ["income"],
                    "missing_data_behavior": "withhold",
                    "scenario_ids": ["with_without"],
                    "tradeoffs": ["liquidity"],
                    "calculation_contract": "tax_calc",
                    "compliance_boundary": "education_only",
                    "receipt": "decision_receipt",
                    "next_decision_ids": [],
                    "next_action": "one action",
                    "return_and_correction": "preserve",
                    "not_applicable_behavior": "record reason",
                    "learning_variant": "planning",
                }
            ],
        },
        "experience_graph.yaml": {
            "schema_version": 1,
            "entry_node_ids": ["today_entry"],
            "terminal_kinds": ["safe_exit", "success"],
            "nodes": [
                {
                    "id": "today_entry",
                    "purpose": "Orient",
                    "learning_outcome": "Know the question",
                    "kind": "entry",
                    "view_binding": "next.start",
                    "modes": ["example", "personal", "missing", "stale", "offline", "error", "corrected", "saved"],
                    "terminal_kind": "nonterminal",
                },
                {
                    "id": "safe_exit",
                    "purpose": "Leave safely",
                    "learning_outcome": "Know what remains",
                    "kind": "safe_exit",
                    "view_binding": "next.exit",
                    "modes": ["saved"],
                    "terminal_kind": "safe_exit",
                },
            ],
            "edges": [
                {
                    "action_id": "exit_safely",
                    "source": "today_entry",
                    "destination": "safe_exit",
                    "visible_label_intent": "Stop for now",
                    "guard": "always",
                    "data_effect": "none",
                    "back_semantics": "return_to_start",
                    "fallback": "safe_exit",
                    "analytics_event": "exit_safely",
                    "visible_label": "Stop for now",
                }
            ],
            "chat": {
                "allowed_action_ids": ["exit_safely"],
                "action_policy": {
                    "read_only": [],
                    "navigation_only": ["exit_safely"],
                    "requires_explicit_user_confirmation": [],
                    "allowed_data_effects": ["none"],
                    "authorization": "same user",
                    "continuity_fields": ["decision_id"],
                },
            },
            "decision_template": {
                "applies_to_decision_ids": ["pillar_3a"],
                "binding_contract": "persist decision",
                "required_context": ["decision_id"],
                "unbound_decision_behavior": "not reachable",
            },
            "learning_variants": {"planning": {"example_intent": "CHF example", "tone": "neutral"}},
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
            "boundary": {
                "next_imports_legacy_ui": False,
                "legacy_imports_next": False,
                "next_default_enabled": False,
                "kill_switch_required": True,
                "fallback_until_equivalence_and_rollback_proven": True,
                "approved_reuse_status": "reuse_approved_with_exact_evidence",
            },
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
    for concept in documents["concepts.yaml"]["concepts"]:
        concept.update({
            "plain_language_question": "What changes?", "mental_model": "Simple model", "simple_why": "Because cash changes",
            "chf_example": "CHF 100 becomes CHF 80", "visual": "one bar", "misconceptions": ["wrong assumption"],
            "glossary_terms": [{"term": "cash", "plain_language": "money"}],
            "comprehension_evidence": {"prompt": "What remains?", "acceptable_answer": "CHF 80", "never_score_or_label": True},
        })
    graph = documents["experience_graph.yaml"]
    mode = ["example", "personal", "missing", "stale", "offline", "error", "corrected", "saved"]
    for node_id in ("question", "simple_why", "example", "receipt"):
        graph["nodes"].append({"id": node_id, "purpose": node_id, "learning_outcome": node_id,
                               "kind": "learning", "view_binding": f"next.{node_id}", "modes": mode,
                               "terminal_kind": "nonterminal"})
    def edge(action: str, source: str, destination: str, effect: str = "none") -> dict:
        return {"action_id": action, "source": source, "destination": destination,
                "visible_label_intent": action, "visible_label": action, "guard": "always",
                "data_effect": effect, "back_semantics": "preserve", "fallback": "safe_exit",
                "analytics_event": action}
    graph["edges"] += [
        edge("open_question", "today_entry", "question"), edge("explain_simply", "question", "simple_why"),
        edge("leave_question", "question", "safe_exit"),
        edge("show_contextual_example", "simple_why", "example"), edge("finish_example", "example", "safe_exit"),
        edge("expert_details_now", "question", "receipt"), edge("finish_receipt", "receipt", "safe_exit"),
        edge("return_today_without_pressure", "safe_exit", "today_entry"),
        edge("choose_reminder", "safe_exit", "today_entry", "explicit_save_or_edit"),
        edge("dismiss_suggestion", "safe_exit", "today_entry", "explicit_save_or_edit"),
        edge("change_subject", "safe_exit", "today_entry"),
    ]
    graph["chat"]["allowed_action_ids"].append("leave_question")
    graph["chat"]["action_policy"]["navigation_only"].append("leave_question")
    return documents


def write_documents(root: Path, documents: dict[str, dict]) -> None:
    base = root / BASE
    base.mkdir(parents=True, exist_ok=True)
    (root / "SOURCE.txt").write_text("source\n")
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
        (lambda d: d["concepts.yaml"].update(concepts=[]), "concept registry must not be empty"),
        (lambda d: d["decisions.yaml"].update(decisions=[]), "decision registry must not be empty"),
        (lambda d: d["claims_and_data.yaml"].update(items=[]), "claims/data registry must not be empty"),
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
        (lambda d: d["experience_graph.yaml"]["edges"][0].pop("analytics_event"), "analytics_event"),
        (lambda d: d["experience_graph.yaml"]["nodes"][0].update(modes=["nonsense"]), "missing required modes"),
        (lambda d: d["experience_graph.yaml"]["decision_template"].update(applies_to_decision_ids=[]), "bind every and only"),
        (lambda d: d["claims_and_data.yaml"]["items"][0].pop("provenance"), "provenance"),
        (lambda d: d["claims_and_data.yaml"]["items"][0].pop("freshness_days"), "freshness"),
        (lambda d: d["claims_and_data.yaml"]["items"][0].pop("missing_behavior"), "missing behavior"),
        (lambda d: d["legacy_reuse.yaml"]["assets"][0].update(disposition="unknown"), "unknown dependency used by next"),
        (lambda d: d["legacy_reuse.yaml"]["assets"][0].update(disposition="magically_safe"), "invalid legacy disposition"),
        (lambda d: d["legacy_reuse.yaml"]["boundary"].update(next_imports_legacy_ui=True), "legacy boundary violation"),
        (lambda d: d["legacy_reuse.yaml"].update(assets=[]), "legacy dependency registry must not be empty"),
        (lambda d: d["experience_graph.yaml"].update(chat={"allowed_action_ids": ["invented"]}), "unregistered chat action"),
        (lambda d: d["source-inventory.yaml"]["sources"][0].update(sha256="0" * 64), "source inventory hash drift"),
        (lambda d: d["batch.yaml"].update(status="promoted"), "promotion_receipt.exact_head"),
        (lambda d: d["calculation_contracts.yaml"]["contracts"][0].update(required_inputs=["ghost"]), "unknown calculation input"),
        (lambda d: d["calculation_contracts.yaml"]["contracts"][0].update(source_ids=["ghost"]), "unknown calculation source"),
        (lambda d: d["decisions.yaml"]["decisions"][0].update(calculation_contract="ghost"), "decision calculation contract mismatch"),
        (lambda d: d["decisions.yaml"]["decisions"][0].update(compliance_boundary="ghost"), "unknown decision regulatory boundary"),
        (lambda d: d["domain_coverage.yaml"]["domains"][0].update(decision_ids=["ghost"]), "unknown domain decision"),
        (lambda d: d["official_sources.yaml"]["sources"][0].pop("version_basis"), "version_basis"),
        (lambda d: d["experience_graph.yaml"]["edges"][0].update(data_effect="explicit_save_or_edit"), "unconfirmed chat action writes state"),
        (lambda d: d["calculation_contracts.yaml"]["contracts"][0].update(formula_ids=["ghost"]), "unknown formula contract"),
        (lambda d: d["formula_contracts.yaml"]["formulas"][0].update(status="magic"), "invalid formula status"),
        (lambda d: d["decisions.yaml"]["decisions"][0].update(minimum_input_ids=[]), "minimum inputs do not cover"),
        (lambda d: d["decisions.yaml"]["decisions"][0].update(learning_variant="ghost"), "unknown decision learning variant"),
        (lambda d: d["decisions.yaml"]["decisions"][0].update(learning_variant="urgent"), "learning variant mapping mismatch"),
        (lambda d: d["audience.yaml"].pop("falsification_protocol"), "falsification_protocol"),
        (lambda d: d["concepts.yaml"]["concepts"][0].pop("simple_why"), "simple_why"),
        (lambda d: d["experience_graph.yaml"]["edges"][-3].update(data_effect="none"), "choose_reminder"),
        (lambda d: d["audience.yaml"]["universal_floor"].update(sequence=[]), "canonical order"),
        (lambda d: d["audience.yaml"]["universal_floor"].update(max_primary_numbers=999), "between 1 and 3"),
        (lambda d: d["audience.yaml"]["universal_floor"].update(example_before_personalization=False), "example_before_personalization"),
        (lambda d: d["audience.yaml"].update(expert_escape=[]), "expert_escape lacks"),
        (lambda d: d["audience.yaml"]["progressive_depth"].pop(), "canonical n0..n4"),
        (lambda d: d["audience.yaml"]["falsification_protocol"]["signals"][0].pop("measure"), "signal understood.measure"),
        (lambda d: d["concepts.yaml"]["concepts"][0].update(glossary_terms=[]), "glossary_terms must be a non-empty"),
        (lambda d: d["concepts.yaml"]["concepts"][0].update(chf_example="CHF only once"), "at least two numeric amounts"),
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


def test_rejects_coordinated_coercive_leave_question(tmp_path: Path) -> None:
    documents = valid_documents()
    graph = documents["experience_graph.yaml"]
    edge = next(item for item in graph["edges"] if item["action_id"] == "leave_question")
    edge["data_effect"] = "explicit_save_or_edit"
    policy = graph["chat"]["action_policy"]
    policy["navigation_only"].remove("leave_question")
    policy["requires_explicit_user_confirmation"].append("leave_question")
    write_documents(tmp_path, documents)
    result = run(tmp_path)
    assert result.returncode == 1
    assert "leave_question" in result.stderr


def test_draft_may_record_conflict_but_promotion_fails_closed(tmp_path: Path) -> None:
    documents = valid_documents()
    documents["architecture_conflicts.yaml"]["conflicts"] = [{
        "id": "active_context_conflict",
        "severity": "blocker",
        "status": "unresolved",
        "conflict": "old authority disagrees",
        "resolution_required": "replace authority separately",
        "authority_paths": ["SOURCE.txt"],
    }]
    write_documents(tmp_path, documents)
    assert run(tmp_path).returncode == 0
    documents["batch.yaml"].update(status="promoted", promotion_receipt={"exact_head": "abc"})
    write_documents(tmp_path, documents)
    result = run(tmp_path)
    assert result.returncode == 1
    assert "unresolved architecture conflict" in result.stderr
