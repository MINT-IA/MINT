from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

from tools.checks import mint2_vz_route_contract_guard

REPO_ROOT = Path(__file__).resolve().parents[3]
SCRIPT = REPO_ROOT / "tools/checks/mint2_vz_route_contract_guard.py"


def _run(root: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(SCRIPT), "--root", str(root)],
        capture_output=True,
        text=True,
    )


def _write_fixture(root: Path) -> None:
    (root / "apps/mobile/lib/routes").mkdir(parents=True)
    (root / "apps/mobile/lib/services/financial_core").mkdir(parents=True)
    (root / "services/backend/app/services/coach").mkdir(parents=True)
    (root / ".planning/journeys/records").mkdir(parents=True)
    (
        root
        / ".planning/phases/mint-2-0-first-experience-rente-capital/route_contracts"
    ).mkdir(parents=True)
    (root / "artifacts").mkdir()
    (root / "docs").mkdir()
    (root / "docs/data-flow.md").write_text("# Data flow\n", encoding="utf-8")
    (root / "artifacts/result.xml").write_text("<testsuite />", encoding="utf-8")
    (root / "apps/mobile/lib/routes/route_metadata.dart").write_text(
        """
const Map<String, RouteMeta> kRouteRegistry = <String, RouteMeta>{
  '/budget': RouteMeta(path: '/budget', category: RouteCategory.destination, owner: RouteOwner.budget, requiresAuth: true),
  '/coach/chat': RouteMeta(path: '/coach/chat', category: RouteCategory.destination, owner: RouteOwner.coach, requiresAuth: false),
  '/legacy/budget': RouteMeta(path: '/legacy/budget', category: RouteCategory.alias, owner: RouteOwner.system, requiresAuth: true, description: 'Legacy redirect -> /budget'),
};
""",
        encoding="utf-8",
    )
    _write_record(root)
    _write_contract(root)


def _write_record(root: Path, **updates: object) -> None:
    data: dict[str, object] = {
        "schema_version": 1,
        "id": "money_truth_spine",
        "title": "Money truth spine",
        "tier": "T0",
        "status": "live_proven",
        "route_paths": ["/budget", "/coach/chat"],
        "evidence": [
            {
                "kind": "runtime",
                "status": "green",
                "artifact": "artifacts/result.xml",
            }
        ],
    }
    data.update(updates)
    (root / ".planning/journeys/records/money_truth_spine.json").write_text(
        json.dumps(data),
        encoding="utf-8",
    )


def _contract(**updates: object) -> dict[str, object]:
    data: dict[str, object] = {
        "schema_version": 1,
        "journey_id": "money_truth_spine",
        "tier": "T0",
        "human_question": "Are my money numbers consistent?",
        "primary_routes": ["/budget"],
        "supporting_routes": ["/coach/chat"],
        "legacy_alias_routes": ["/legacy/budget"],
        "owner_domains": ["budget", "coach"],
        "route_domain": "money_truth",
        "route_role": "truth_spine",
        "auth_scope": "mixed",
        "persona_scope": ["cadre_salarie_lpp_suisse_ready"],
        "required_inputs": [
            {
                "key": "budget_snapshot",
                "blocks_value": True,
                "reason": "The route cannot emit consistent money values without the budget snapshot.",
            }
        ],
        "optional_inputs": [],
        "missing_data_behavior": "Name missing fields and block personalized values.",
        "calculation_boundary": {
            "level": "L1",
            "l1_source": "apps/mobile/lib/services/financial_core/",
            "l2_l4_source": "none",
            "may_emit_financial_number": True,
        },
        "value_receipt_required": True,
        "receipt_fields": [
            "sources",
            "assumptions",
            "confidence",
            "missing_fields",
            "version",
        ],
        "signal_axis": False,
        "compliance_invariants": [
            "no_banned_lsfin_terms",
            "no_financial_number_without_receipt",
            "no_absurd_captured_value_leak",
            "no_shadow_money_snapshot",
        ],
        "proof_pointer": "artifacts/result.xml",
        "source_refs": ["docs/data-flow.md"],
    }
    data.update(updates)
    return data


def _write_contract(root: Path, **updates: object) -> None:
    path = (
        root
        / ".planning/phases/mint-2-0-first-experience-rente-capital/route_contracts/money_truth_spine.json"
    )
    path.write_text(json.dumps(_contract(**updates)), encoding="utf-8")


def test_route_contract_guard_passes_for_coherent_fixture(tmp_path: Path) -> None:
    _write_fixture(tmp_path)

    assert mint2_vz_route_contract_guard.check(tmp_path) == []
    proc = _run(tmp_path)

    assert proc.returncode == 0
    assert "OK mint2_vz_route_contract_guard" in proc.stdout


def test_route_contract_guard_passes_for_repo_contracts() -> None:
    assert mint2_vz_route_contract_guard.check(REPO_ROOT) == []


def test_route_contract_guard_fails_when_t0_record_has_no_contract(
    tmp_path: Path,
) -> None:
    _write_fixture(tmp_path)
    (
        tmp_path
        / ".planning/phases/mint-2-0-first-experience-rente-capital/route_contracts/money_truth_spine.json"
    ).unlink()

    errors = mint2_vz_route_contract_guard.check(tmp_path)

    assert any("missing route contract for money_truth_spine" in error for error in errors)


def test_route_contract_guard_fails_when_primary_route_is_alias(
    tmp_path: Path,
) -> None:
    _write_fixture(tmp_path)
    _write_record(tmp_path, route_paths=["/legacy/budget", "/coach/chat"])
    _write_contract(
        tmp_path,
        primary_routes=["/legacy/budget"],
        supporting_routes=["/coach/chat"],
        legacy_alias_routes=[],
    )

    errors = mint2_vz_route_contract_guard.check(tmp_path)

    assert any("cannot be primary_routes" in error for error in errors)


def test_route_contract_guard_fails_when_value_route_lacks_receipt_fields(
    tmp_path: Path,
) -> None:
    _write_fixture(tmp_path)
    _write_contract(
        tmp_path,
        receipt_fields=["sources", "assumptions", "missing_fields", "version"],
    )

    errors = mint2_vz_route_contract_guard.check(tmp_path)

    assert any("missing receipt_fields" in error and "confidence" in error for error in errors)


def test_route_contract_guard_fails_when_signal_axis_emits_financial_number(
    tmp_path: Path,
) -> None:
    _write_fixture(tmp_path)
    _write_contract(tmp_path, signal_axis=True)

    errors = mint2_vz_route_contract_guard.check(tmp_path)

    assert any("signal_axis routes cannot emit financial numbers" in error for error in errors)


def test_route_contract_guard_fails_when_proof_pointer_is_not_green(
    tmp_path: Path,
) -> None:
    _write_fixture(tmp_path)
    (tmp_path / "artifacts/other.xml").write_text("<testsuite />", encoding="utf-8")
    _write_contract(tmp_path, proof_pointer="artifacts/other.xml")

    errors = mint2_vz_route_contract_guard.check(tmp_path)

    assert any("proof_pointer must match a green Journey OS evidence" in error for error in errors)


def test_route_contract_guard_fails_when_journey_route_is_uncovered(
    tmp_path: Path,
) -> None:
    _write_fixture(tmp_path)
    _write_contract(tmp_path, supporting_routes=[])

    errors = mint2_vz_route_contract_guard.check(tmp_path)

    assert any("does not cover Journey OS routes" in error for error in errors)


def test_route_contract_guard_requires_contract_for_t1_record(tmp_path: Path) -> None:
    _write_fixture(tmp_path)
    data = {
        "schema_version": 1,
        "id": "future_tax_route",
        "title": "Future tax route",
        "tier": "T1",
        "status": "partial",
        "route_paths": ["/budget"],
        "evidence": [
            {
                "kind": "runtime",
                "status": "green",
                "artifact": "artifacts/result.xml",
            }
        ],
    }
    (tmp_path / ".planning/journeys/records/future_tax_route.json").write_text(
        json.dumps(data),
        encoding="utf-8",
    )

    errors = mint2_vz_route_contract_guard.check(tmp_path)

    assert any("missing route contract for future_tax_route" in error for error in errors)


def test_route_contract_guard_fails_when_journey_os_routes_through_legacy_alias(
    tmp_path: Path,
) -> None:
    _write_fixture(tmp_path)
    _write_record(tmp_path, route_paths=["/budget", "/coach/chat", "/legacy/budget"])

    errors = mint2_vz_route_contract_guard.check(tmp_path)

    assert any("Journey OS must not route through legacy aliases" in error for error in errors)


def test_route_contract_guard_fails_when_owner_domain_misses_route_owner(
    tmp_path: Path,
) -> None:
    _write_fixture(tmp_path)
    _write_contract(tmp_path, owner_domains=["coach"])

    errors = mint2_vz_route_contract_guard.check(tmp_path)

    assert any("owner budget is not listed in owner_domains" in error for error in errors)


def test_route_contract_guard_fails_when_l2_l4_source_is_missing(
    tmp_path: Path,
) -> None:
    _write_fixture(tmp_path)
    _write_contract(
        tmp_path,
        calculation_boundary={
            "level": "L2-L4",
            "l1_source": "none",
            "l2_l4_source": "none",
            "may_emit_financial_number": True,
        },
    )

    errors = mint2_vz_route_contract_guard.check(tmp_path)

    assert any("L2-L4 value route must declare" in error for error in errors)


def test_route_contract_guard_fails_when_non_value_route_declares_value_boundary(
    tmp_path: Path,
) -> None:
    _write_fixture(tmp_path)
    _write_contract(
        tmp_path,
        calculation_boundary={
            "level": "L1",
            "l1_source": "apps/mobile/lib/services/financial_core/",
            "l2_l4_source": "none",
            "may_emit_financial_number": False,
        },
        value_receipt_required=True,
    )

    errors = mint2_vz_route_contract_guard.check(tmp_path)

    assert any("non-value route calculation_boundary.level must be none" in error for error in errors)
    assert any("non-value route must not require a value receipt" in error for error in errors)


def test_route_contract_guard_fails_when_source_ref_is_missing(
    tmp_path: Path,
) -> None:
    _write_fixture(tmp_path)
    _write_contract(tmp_path, source_refs=["docs/missing.md"])

    errors = mint2_vz_route_contract_guard.check(tmp_path)

    assert any("source_ref does not exist" in error for error in errors)


def test_route_contract_guard_fails_on_duplicate_journey_id(
    tmp_path: Path,
) -> None:
    _write_fixture(tmp_path)
    duplicate = (
        tmp_path
        / ".planning/phases/mint-2-0-first-experience-rente-capital/route_contracts/duplicate.json"
    )
    duplicate.write_text(json.dumps(_contract()), encoding="utf-8")

    errors = mint2_vz_route_contract_guard.check(tmp_path)

    assert any("duplicate route contract for journey_id money_truth_spine" in error for error in errors)


def test_route_contract_guard_fails_on_unknown_compliance_invariant(
    tmp_path: Path,
) -> None:
    _write_fixture(tmp_path)
    _write_contract(
        tmp_path,
        compliance_invariants=[
            "no_banned_lsfin_terms",
            "no_financial_number_without_receipt",
            "no_typo_that_sounds_safe",
        ],
    )

    errors = mint2_vz_route_contract_guard.check(tmp_path)

    assert any("unknown compliance_invariants" in error for error in errors)


def test_route_contract_guard_fails_on_unsupported_calculation_level(
    tmp_path: Path,
) -> None:
    _write_fixture(tmp_path)
    _write_contract(
        tmp_path,
        calculation_boundary={
            "level": "L1-L2-L4",
            "l1_source": "apps/mobile/lib/services/financial_core/",
            "l2_l4_source": "services/backend/app/services/coach/",
            "may_emit_financial_number": True,
        },
    )

    errors = mint2_vz_route_contract_guard.check(tmp_path)

    assert any("calculation_boundary.level is unsupported" in error for error in errors)


def test_route_contract_guard_fails_when_green_proof_file_is_absent(
    tmp_path: Path,
) -> None:
    _write_fixture(tmp_path)
    _write_record(
        tmp_path,
        evidence=[
            {
                "kind": "runtime",
                "status": "green",
                "artifact": "artifacts/missing.xml",
            }
        ],
    )
    _write_contract(tmp_path, proof_pointer="artifacts/missing.xml")

    errors = mint2_vz_route_contract_guard.check(tmp_path)

    assert any("proof_pointer artifact is not accessible" in error for error in errors)


def test_route_contract_guard_fails_on_unknown_journey_record(
    tmp_path: Path,
) -> None:
    _write_fixture(tmp_path)
    _write_contract(tmp_path, journey_id="unknown_route")

    errors = mint2_vz_route_contract_guard.check(tmp_path)

    assert any("references unknown Journey OS record unknown_route" in error for error in errors)


def test_route_contract_guard_fails_on_tier_mismatch(
    tmp_path: Path,
) -> None:
    _write_fixture(tmp_path)
    _write_contract(tmp_path, tier="T1")

    errors = mint2_vz_route_contract_guard.check(tmp_path)

    assert any("tier must match Journey OS record" in error for error in errors)


def test_route_contract_guard_fails_on_duplicate_route_within_field(
    tmp_path: Path,
) -> None:
    _write_fixture(tmp_path)
    _write_contract(tmp_path, primary_routes=["/budget", "/budget"])

    errors = mint2_vz_route_contract_guard.check(tmp_path)

    assert any("primary_routes contains duplicate routes" in error for error in errors)


def test_route_contract_guard_fails_when_primary_route_has_multiple_claims(
    tmp_path: Path,
) -> None:
    _write_fixture(tmp_path)
    second_record = {
        "schema_version": 1,
        "id": "second_money_route",
        "title": "Second money route",
        "tier": "T0",
        "status": "partial",
        "route_paths": ["/budget"],
        "evidence": [
            {
                "kind": "runtime",
                "status": "green",
                "artifact": "artifacts/result.xml",
            }
        ],
    }
    (tmp_path / ".planning/journeys/records/second_money_route.json").write_text(
        json.dumps(second_record),
        encoding="utf-8",
    )
    second_contract = _contract(
        journey_id="second_money_route",
        primary_routes=["/budget"],
        supporting_routes=[],
        legacy_alias_routes=[],
    )
    (
        tmp_path
        / ".planning/phases/mint-2-0-first-experience-rente-capital/route_contracts/second_money_route.json"
    ).write_text(json.dumps(second_contract), encoding="utf-8")

    errors = mint2_vz_route_contract_guard.check(tmp_path)

    assert any("claimed as primary by multiple route contracts" in error for error in errors)


def test_route_contract_guard_fails_when_value_route_disables_receipt(
    tmp_path: Path,
) -> None:
    _write_fixture(tmp_path)
    _write_contract(tmp_path, value_receipt_required=False)

    errors = mint2_vz_route_contract_guard.check(tmp_path)

    assert any("value route must set value_receipt_required=true" in error for error in errors)


def test_route_contract_guard_fails_when_lsfin_invariant_is_missing(
    tmp_path: Path,
) -> None:
    _write_fixture(tmp_path)
    _write_contract(
        tmp_path,
        compliance_invariants=["no_financial_number_without_receipt"],
    )

    errors = mint2_vz_route_contract_guard.check(tmp_path)

    assert any("must include no_banned_lsfin_terms" in error for error in errors)


def test_route_contract_guard_fails_when_role_required_invariant_is_missing(
    tmp_path: Path,
) -> None:
    _write_fixture(tmp_path)
    _write_contract(
        tmp_path,
        route_role="account_lifecycle",
        route_domain="auth_privacy",
        compliance_invariants=[
            "no_banned_lsfin_terms",
            "no_financial_number_without_receipt",
            "no_pii_leakage_after_delete",
            "no_post_delete_authenticated_surface",
        ],
    )

    errors = mint2_vz_route_contract_guard.check(tmp_path)

    assert any("no_destructive_action_without_confirmation" in error for error in errors)


def test_route_contract_guard_fails_when_contract_references_unguarded_tier(
    tmp_path: Path,
) -> None:
    _write_fixture(tmp_path)
    _write_record(tmp_path, tier="T2")
    _write_contract(tmp_path, tier="T2")

    errors = mint2_vz_route_contract_guard.check(tmp_path)

    assert any("references unguarded tier" in error for error in errors)


def test_route_contract_guard_fails_on_unknown_contract_vocabulary(
    tmp_path: Path,
) -> None:
    _write_fixture(tmp_path)
    _write_contract(
        tmp_path,
        auth_scope="mixedd",
        route_domain="retreat",
        route_role="decison",
        persona_scope=["unknown_persona"],
    )

    errors = mint2_vz_route_contract_guard.check(tmp_path)

    assert any("auth_scope is unsupported" in error for error in errors)
    assert any("route_domain is unsupported" in error for error in errors)
    assert any("route_role is unsupported" in error for error in errors)
    assert any("persona_scope contains unknown personas" in error for error in errors)


def test_route_contract_guard_fails_on_malformed_input_shape(
    tmp_path: Path,
) -> None:
    _write_fixture(tmp_path)
    _write_contract(
        tmp_path,
        required_inputs=[
            {
                "key": "",
                "blocks_value": "yes",
            }
        ],
    )

    errors = mint2_vz_route_contract_guard.check(tmp_path)

    assert any("required_inputs[0] missing key" in error for error in errors)
    assert any("required_inputs[0] blocks_value must be boolean" in error for error in errors)
    assert any("required_inputs[0] missing reason" in error for error in errors)


def test_route_contract_guard_fails_when_calculation_source_does_not_exist(
    tmp_path: Path,
) -> None:
    _write_fixture(tmp_path)
    _write_contract(
        tmp_path,
        calculation_boundary={
            "level": "L1",
            "l1_source": "apps/mobile/lib/services/financial_core/missing.dart",
            "l2_l4_source": "none",
            "may_emit_financial_number": True,
        },
    )

    errors = mint2_vz_route_contract_guard.check(tmp_path)

    assert any("calculation_boundary.l1_source does not exist" in error for error in errors)


def test_route_contract_guard_fails_when_public_scope_contains_auth_route(
    tmp_path: Path,
) -> None:
    _write_fixture(tmp_path)
    _write_contract(tmp_path, auth_scope="public")

    errors = mint2_vz_route_contract_guard.check(tmp_path)

    assert any("auth_scope public cannot include requiresAuth=true routes" in error for error in errors)


def test_route_contract_guard_fails_when_authenticated_scope_contains_public_route(
    tmp_path: Path,
) -> None:
    _write_fixture(tmp_path)
    _write_contract(tmp_path, auth_scope="authenticated")

    errors = mint2_vz_route_contract_guard.check(tmp_path)

    assert any("auth_scope authenticated cannot include requiresAuth=false routes" in error for error in errors)


def test_route_contract_guard_fails_when_onboarding_primary_requires_auth(
    tmp_path: Path,
) -> None:
    _write_fixture(tmp_path)
    _write_contract(tmp_path, auth_scope="onboarding")

    errors = mint2_vz_route_contract_guard.check(tmp_path)

    assert any("auth_scope onboarding primary routes must not require auth" in error for error in errors)


def test_route_contract_guard_fails_when_mixed_scope_is_not_mixed(
    tmp_path: Path,
) -> None:
    _write_fixture(tmp_path)
    _write_record(tmp_path, route_paths=["/budget"])
    _write_contract(tmp_path, supporting_routes=[])

    errors = mint2_vz_route_contract_guard.check(tmp_path)

    assert any("auth_scope mixed must include both" in error for error in errors)


def test_route_contract_guard_fails_when_non_value_route_has_receipt_fields(
    tmp_path: Path,
) -> None:
    _write_fixture(tmp_path)
    _write_contract(
        tmp_path,
        calculation_boundary={
            "level": "none",
            "l1_source": "none",
            "l2_l4_source": "none",
            "may_emit_financial_number": False,
        },
        value_receipt_required=False,
        receipt_fields=["sources"],
    )

    errors = mint2_vz_route_contract_guard.check(tmp_path)

    assert any("non-value route must keep receipt_fields empty" in error for error in errors)


def test_route_contract_guard_fails_when_route_lists_overlap(
    tmp_path: Path,
) -> None:
    _write_fixture(tmp_path)
    _write_contract(tmp_path, supporting_routes=["/coach/chat", "/budget"])

    errors = mint2_vz_route_contract_guard.check(tmp_path)

    assert any("routes cannot appear in both primary_routes and supporting_routes" in error for error in errors)


def test_route_contract_guard_fails_when_source_ref_escapes_repo(
    tmp_path: Path,
) -> None:
    _write_fixture(tmp_path)
    _write_contract(tmp_path, source_refs=["../outside.md"])

    errors = mint2_vz_route_contract_guard.check(tmp_path)

    assert any("source_ref must not contain '..'" in error for error in errors)


def test_route_contract_guard_fails_when_proof_pointer_is_absolute(
    tmp_path: Path,
) -> None:
    _write_fixture(tmp_path)
    _write_contract(tmp_path, proof_pointer="/tmp/result.xml")

    errors = mint2_vz_route_contract_guard.check(tmp_path)

    assert any("proof_pointer must be repo-relative" in error for error in errors)


def test_route_contract_guard_fails_when_calculation_source_escapes_repo(
    tmp_path: Path,
) -> None:
    _write_fixture(tmp_path)
    _write_contract(
        tmp_path,
        calculation_boundary={
            "level": "L1",
            "l1_source": "../financial_core",
            "l2_l4_source": "none",
            "may_emit_financial_number": True,
        },
    )

    errors = mint2_vz_route_contract_guard.check(tmp_path)

    assert any("calculation_boundary.l1_source must not contain '..'" in error for error in errors)


def test_route_contract_guard_fails_when_signal_axis_is_not_boolean(
    tmp_path: Path,
) -> None:
    _write_fixture(tmp_path)
    _write_contract(tmp_path, signal_axis="true")

    errors = mint2_vz_route_contract_guard.check(tmp_path)

    assert any("signal_axis must be boolean" in error for error in errors)


def test_route_contract_guard_fails_when_calculation_boundary_is_not_object(
    tmp_path: Path,
) -> None:
    _write_fixture(tmp_path)
    _write_contract(tmp_path, calculation_boundary="L1")

    errors = mint2_vz_route_contract_guard.check(tmp_path)

    assert any("calculation_boundary must be an object" in error for error in errors)


def test_route_contract_guard_fails_when_may_emit_flag_is_not_boolean(
    tmp_path: Path,
) -> None:
    _write_fixture(tmp_path)
    _write_contract(
        tmp_path,
        calculation_boundary={
            "level": "L1",
            "l1_source": "apps/mobile/lib/services/financial_core/",
            "l2_l4_source": "none",
            "may_emit_financial_number": "yes",
        },
    )

    errors = mint2_vz_route_contract_guard.check(tmp_path)

    assert any("may_emit_financial_number must be boolean" in error for error in errors)
