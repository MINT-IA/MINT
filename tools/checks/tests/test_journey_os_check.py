from __future__ import annotations

import json
import subprocess
from pathlib import Path
import pytest
from tools.checks import journey_os_check, journey_os_generate

GOOD_XML = """<?xml version='1.0' encoding='UTF-8'?><testsuites><testsuite tests="1" failures="0" errors="0"><testcase name="ok"/></testsuite></testsuites>"""
FAILING_XML = """<?xml version='1.0' encoding='UTF-8'?><testsuites><testsuite tests="1" failures="1" errors="0"><testcase name="x"><failure>boom</failure></testcase></testsuite></testsuites>"""
SKIPPED_XML = """<?xml version='1.0' encoding='UTF-8'?><testsuites><testsuite tests="1" failures="0" errors="0" skipped="1"><testcase name="skipped"><skipped/></testcase></testsuite></testsuites>"""
SHA_A = "a" * 40
SHA_B = "b" * 40

def _root(tmp_path: Path) -> Path:
    (tmp_path / "apps/mobile/lib/routes").mkdir(parents=True)
    (tmp_path / "tools/openapi").mkdir(parents=True)
    (tmp_path / "tools/simulator/flows/maestro-perfect-set").mkdir(parents=True)
    (tmp_path / ".planning/phases/mint-2-0-first-experience-rente-capital").mkdir(parents=True)
    (tmp_path / ".planning/journeys/records").mkdir(parents=True)
    (tmp_path / ".planning/journeys/issues").mkdir(parents=True)
    (tmp_path / ".planning/journeys/journey.schema.json").write_text(
        (journey_os_check.REPO_ROOT / ".planning/journeys/journey.schema.json").read_text(encoding="utf-8"),
        encoding="utf-8",
    )
    (tmp_path / ".planning/journeys/issue.schema.json").write_text(
        (journey_os_check.REPO_ROOT / ".planning/journeys/issue.schema.json").read_text(encoding="utf-8"),
        encoding="utf-8",
    )
    (tmp_path / "artifacts").mkdir()
    (tmp_path / "artifacts/result.xml").write_text(GOOD_XML, encoding="utf-8")
    (tmp_path / "tools/simulator/flows/maestro-perfect-set/flow_money_trust_chain_budget_mon_argent_rapport_coach.yaml").write_text(
        "appId: ch.mint.app\n---\n- launchApp\n",
        encoding="utf-8",
    )
    (tmp_path / ".planning/phases/mint-2-0-first-experience-rente-capital/SPEC.md").write_text(
        "# Fixture SPEC\n",
        encoding="utf-8",
    )
    routes = ["/budget", "/mon-argent", "/rapport", "/coach/chat", "/profile", "/profile/bilan"]
    (tmp_path / "apps/mobile/lib/routes/route_metadata.dart").write_text(
        "\n".join(
            [
                "const Map<String, RouteMeta> kRouteRegistry = <String, RouteMeta>{",
                *[
                    "  '{route}': RouteMeta(path: '{route}', category: RouteCategory.destination, owner: RouteOwner.system, requiresAuth: true),".format(
                        route=route
                    )
                    for route in routes
                ],
                "  '/legacy/budget': RouteMeta(path: '/legacy/budget', category: RouteCategory.alias, owner: RouteOwner.system, requiresAuth: true, description: 'Legacy redirect -> /budget'),",
                "};",
            ]
        ),
        encoding="utf-8",
    )
    (tmp_path / "apps/mobile/lib/app.dart").write_text(
        "\n".join(
            [
                "final routes = [",
                "  ScopedGoRoute(path: '/budget', builder: (_, __) => Screen()),",
                "  ScopedGoRoute(path: '/coach/chat', scope: RouteScope.public, builder: (_, __) => Screen()),",
                "  ScopedGoRoute(path: '/legacy/budget', scope: RouteScope.onboarding, redirect: (_, __) => '/budget'),",
                "  ScopedGoRoute(",
                "    path: '/profile',",
                "    routes: [",
                "      ScopedGoRoute(",
                "        path: 'bilan',",
                "        // scope: RouteScope.authenticated must not override the runtime arg below.",
                "        scope: RouteScope.public,",
                "        builder: (_, __) => Screen(),",
                "      ),",
                "    ],",
                "  ),",
                "];",
            ]
        ),
        encoding="utf-8",
    )
    (tmp_path / "tools/openapi/mint.openapi.canonical.json").write_text(
        json.dumps(
            {
                "openapi": "3.1.0",
                "paths": {
                    "/api/v1/coach/chat": {"post": {}},
                    "/api/v1/privacy/export": {"post": {}},
                },
            }
        ),
        encoding="utf-8",
    )
    return tmp_path

def _record(root: Path, **updates: object) -> None:
    data: dict[str, object] = {
        "schema_version": 1,
        "id": "money_truth_spine",
        "title": "Money truth spine",
        "tier": "T0",
        "status": "partial",
        "human_promise": "My money numbers are consistent.",
        "accountable_team": "mint-quality-gate",
        "personas": ["cadre_salarie_lpp_suisse_ready"],
        "entry_state": "Authenticated or local-mode user opens a money surface with seeded Swiss profile facts.",
        "account_state": "Authenticated or local mode; no account creation prompt may replace the value path.",
        "success_state": "Budget, Mon argent, Rapport, and Coach read the same money truth snapshot.",
        "negative_assertions": ["No stale profile value can override the latest runtime proof."],
        "source_spec_refs": [".planning/phases/mint-2-0-first-experience-rente-capital/SPEC.md"],
        "proof_owner": "mint-quality-gate",
        "fix_owner": "mint-mobile",
        "runtime_replay": {
            "flow": "tools/simulator/flows/maestro-perfect-set/flow_money_trust_chain_budget_mon_argent_rapport_coach.yaml",
            "sets": ["core"],
            "device": "MINT iPhone 13 mini RvC",
            "build_defines": ["MINT_DISABLE_BETA_MODAL=true"],
            "requires_auth": False,
            "order": 10,
        },
        "route_paths": ["/budget", "/mon-argent", "/rapport", "/coach/chat", "/profile", "/profile/bilan"],
        "surfaces": ["BudgetSnapshot", "DataSpineSnapshot"],
        "external_apis": [],
        "issues": ["JOS-001"],
        "priority": {
            "trust_blast_radius": 5,
            "release_blocker_weight": 5,
            "user_frequency": 5,
            "evidence_gap": 2,
            "route_centrality": 5,
            "compliance_risk": 4,
            "learning_value": 5,
            "proof_cost": 3,
            "rationale": "Money consistency is the central Mint trust promise.",
        },
        "evidence": [
            {
                "kind": "runtime",
                "status": "green",
                "command": "maestro test flow.yaml",
                "artifact": "artifacts/result.xml",
                "verified_at": "2026-06-26T00:00:00Z",
                "verified_commit": SHA_A,
            }
        ],
    }
    stem = str(updates.pop("_stem", data["id"]))
    data.update(updates)
    (root / f".planning/journeys/records/{stem}.json").write_text(json.dumps(data), encoding="utf-8")

def _issue(root: Path, **updates: object) -> None:
    data: dict[str, object] = {
        "schema_version": 1,
        "id": "JOS-001",
        "title": "Prove money truth spine",
        "journey_id": "money_truth_spine",
        "status": "verified",
        "owner": "mint-quality-gate",
        "severity": "P0",
        "evidence_status": "green",
        "next_action": "Create the next deterministic runtime proof for the highest-scoring journey.",
        "source": "CJT-003",
    }
    data.update(updates)
    (root / f".planning/journeys/issues/{data['id']}.json").write_text(json.dumps(data), encoding="utf-8")

def _errors(root: Path, changed: list[str] | None = None) -> list[str]:
    return journey_os_check.check(root, changed or ["tools/checks/journey_os_check.py"])

def test_valid_fixture_passes(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(root)
    _issue(root)
    journey_os_generate.write(root)
    assert _errors(root) == []

def test_missing_baseline_fails_closed(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(root)
    _issue(root)
    journey_os_generate.write(root)
    assert any("origin/dev" in error or "baseline" in error for error in journey_os_check.check(root, []))

def test_changed_file_outside_whitelist_fails(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(root)
    _issue(root)
    journey_os_generate.write(root)
    assert any(
        "outside Journey OS whitelist" in error
        for error in _errors(root, ["apps/mobile/lib/unscoped_surface.dart"])
    )

def test_active_context_branch_authorization_is_in_scope(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(root)
    _issue(root)
    journey_os_generate.write(root)

    errors = _errors(
        root,
        [
            ".planning/ACTIVE_CONTEXT.md",
            ".planning/ACTIVE_CONTEXT.json",
        ],
    )

    assert not any("outside Journey OS whitelist" in error for error in errors)

def test_diagnostic_entry_files_are_in_scope(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(root)
    _issue(root)
    journey_os_generate.write(root)

    errors = _errors(
        root,
        [
            "apps/mobile/lib/screens/auth/login_screen.dart",
            "apps/mobile/lib/widgets/onboarding/premier_eclairage_card.dart",
            "apps/mobile/test/screens/auth_magic_link_verify_handoff_test.dart",
            "apps/mobile/test/widgets/onboarding/premier_eclairage_card_test.dart",
            "tools/simulator/flows/maestro-perfect-set/flow_landing_to_diagnostic_onboarding.yaml",
        ],
    )

    assert not any("outside Journey OS whitelist" in error for error in errors)

def test_journey_os_workflow_files_are_in_scope(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(root)
    _issue(root)
    journey_os_generate.write(root)

    errors = _errors(
        root,
        [
            ".claude/AGENT_BOOTSTRAP.md",
            ".github/pull_request_template.md",
            ".github/workflows/ai-workflow-guards.yml",
            ".planning/ROADMAP.md",
            "AGENTS.md",
            "docs/MINT_AGENT_WORKFLOW.md",
            "lefthook.yml",
            "rules.md",
            "tools/claude_review.py",
            "tools/claude_review.sh",
            "tools/checks/active_context_guard.py",
            "tools/checks/mint_rules_guard.py",
            "tools/checks/tests/test_active_context_guard.py",
            "tools/checks/tests/test_claude_review.py",
            "tools/checks/tests/test_mint_rules_guard.py",
        ],
    )

    assert not any("outside Journey OS whitelist" in error for error in errors)


def test_codex_executable_specs_are_in_scope(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(root)
    _issue(root)
    journey_os_generate.write(root)

    errors = _errors(
        root,
        [
            "docs/codex/DATA_LEDGER.md",
            "docs/codex/SCREEN_CONTRACTS.md",
            "docs/codex/WIRING_GRAPH.mmd",
            "docs/codex/DATA_QUEST.md",
            "docs/codex/MAESTRO_FLOWS.md",
            "docs/codex/P0_CASE_VARIABLE_REGISTRY.json",
            "docs/codex/dossier_stubs/dossier_transmit_property.schema.json",
            "docs/codex/dossier_stubs/dossier_first_salary_tax.schema.json",
            "docs/codex/dossier_stubs/dossier_buy_property.schema.json",
        ],
    )

    assert not any("outside Journey OS whitelist" in error for error in errors)


def test_mint2_vz_route_architecture_doc_is_in_scope(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(root)
    _issue(root)
    journey_os_generate.write(root)

    errors = _errors(
        root,
        [
            ".planning/phases/mint-2-0-first-experience-rente-capital/VZ_ROUTE_ARCHITECTURE.md",
        ],
    )

    assert not any("outside Journey OS whitelist" in error for error in errors)


def test_coach_advice_backend_files_are_in_scope(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(root)
    _issue(root)
    journey_os_generate.write(root)

    errors = _errors(
        root,
        [
            "services/backend/app/api/v1/endpoints/coach_chat.py",
            "services/backend/app/services/coach/structured_reasoning.py",
            "services/backend/tests/test_coach_chat_endpoint.py",
            "services/backend/tests/test_e2e_coach_pipeline.py",
            "services/backend/tests/test_structured_reasoning.py",
        ],
    )

    assert not any("outside Journey OS whitelist" in error for error in errors)


def test_coach_rag_runtime_hotfix_files_are_in_scope(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(root)
    _issue(root)
    journey_os_generate.write(root)

    errors = _errors(
        root,
        [
            "services/backend/app/services/rag/hybrid_search_service.py",
            "services/backend/app/services/rag/retriever.py",
            "services/backend/app/services/rag/vector_store.py",
            "services/backend/tests/test_main_coverage.py",
        ],
    )

    assert not any("outside Journey OS whitelist" in error for error in errors)


def test_python_editable_install_egg_info_is_ignored(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(root)
    _issue(root)
    journey_os_generate.write(root)

    errors = _errors(
        root,
        [
            "services/backend/mint_backend.egg-info/PKG-INFO",
            "services/backend/mint_backend.egg-info/SOURCES.txt",
            "services/backend/mint_backend.egg-info/requires.txt",
        ],
    )

    assert not any("outside Journey OS whitelist" in error for error in errors)

def test_row24_privacy_runtime_flow_is_in_scope(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(root)
    _issue(root)
    journey_os_generate.write(root)

    errors = _errors(
        root,
        [
            "tools/simulator/flows/maestro-perfect-set/flow_row24_privacy_control_runtime.yaml",
        ],
    )

    assert not any("outside Journey OS whitelist" in error for error in errors)

def test_jos004_coach_advice_runtime_flow_is_in_scope(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(root)
    _issue(root)
    journey_os_generate.write(root)

    errors = _errors(
        root,
        [
            "tools/simulator/flows/maestro-perfect-set/flow_jos004_coach_advice_turn_runtime.yaml",
        ],
    )

    assert not any("outside Journey OS whitelist" in error for error in errors)

def test_jos004_coach_level_runtime_gate_scope_is_in_scope(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(root)
    _issue(root)
    journey_os_generate.write(root)

    errors = _errors(
        root,
        [
            "services/backend/app/api/v1/endpoints/coach_chat.py",
            "services/backend/app/services/coach/compliance_guard.py",
            "services/backend/app/services/rag/guardrails.py",
            "services/backend/app/services/rag/orchestrator.py",
            "services/backend/tests/test_coach_chat_endpoint.py",
            "services/backend/tests/test_compliance_guard.py",
            "services/backend/tests/test_guardrails_coverage.py",
            "services/backend/tests/test_rag_orchestrator_empty_text_no_fallback.py",
        ],
    )

    assert not any("outside Journey OS whitelist" in error for error in errors)

def test_jos005_first_value_hotfix_scope_is_in_scope(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(root)
    _issue(root)
    journey_os_generate.write(root)

    errors = _errors(
        root,
        [
            "apps/mobile/lib/app.dart",
            "apps/mobile/lib/providers/auth_provider.dart",
            "apps/mobile/lib/routes/route_metadata.dart",
            "apps/mobile/lib/screens/landing_screen.dart",
            "apps/mobile/lib/screens/debug/debug_mint2_account_claim_screen.dart",
            "apps/mobile/lib/screens/onboarding/mvp_wedge/onboarding_shell_screen.dart",
            "apps/mobile/lib/services/coach/_valid_routes_generated.dart",
            "apps/mobile/lib/services/coach/chat_tool_dispatcher.dart",
            "apps/mobile/lib/services/navigation/route_planner.dart",
            "apps/mobile/lib/services/navigation/screen_registry.dart",
            "apps/mobile/test/architecture/route_guard_snapshot.golden.txt",
            "apps/mobile/test/architecture/route_guard_snapshot_test.dart",
            "apps/mobile/test/navigation/account_lifecycle_public_entry_redirect_test.dart",
            "apps/mobile/test/navigation/goroute_health_test.dart",
            "apps/mobile/test/navigation/rvc_real_route_public_test.dart",
            "apps/mobile/test/providers/auth_provider_test.dart",
            "apps/mobile/test/screens/debug/debug_mint2_account_claim_screen_test.dart",
            "apps/mobile/test/screens/onboarding/mvp_wedge/mint2_first_experience_route_scope_test.dart",
            "apps/mobile/test/screens/onboarding/mvp_wedge/mint2_first_experience_signal_axes_test.dart",
            "apps/mobile/test/screens/onboarding/mvp_wedge_storyboard_test.dart",
            "apps/mobile/test/services/coach/chat_tool_dispatcher_test.dart",
            "apps/mobile/test/services/navigation/route_planner_test.dart",
            "apps/mobile/test/services/navigation/screen_registry_test.dart",
            "docs/ROUTE_POLICY.md",
            "services/backend/app/services/coach/_route_intents_generated.py",
            "services/backend/tests/fixtures/narrator_legacy_snapshots/_load.py",
            "services/backend/tests/fixtures/narrator_legacy_snapshots/snapshot_canton_vs_de_cash3.txt",
            "services/backend/tests/fixtures/narrator_legacy_snapshots/snapshot_couple_dissymetrique_fr_cash5.txt",
            "services/backend/tests/fixtures/narrator_legacy_snapshots/snapshot_default_ctx_fr_cash3.txt",
            "services/backend/tests/fixtures/narrator_legacy_snapshots/snapshot_minimal_ctx_en_cash1.txt",
            "services/backend/tests/fixtures/narrator_legacy_snapshots/snapshot_safe_mode_has_debt_fr_cash2.txt",
            "services/backend/tests/test_citation_gate/test_byte_identity_flag_off.py",
            "services/backend/tests/test_coach_tools.py",
            "tools/contracts/regen_screen_registry_contract.py",
            "tools/contracts/screen_registry.json",
            "tools/simulator/mint2_quality_gate.sh",
            "tools/simulator/test_mint2_quality_gate.py",
        ],
    )

    assert not any("outside Journey OS whitelist" in error for error in errors)


def test_auth_l10n_hotfix_scope_is_in_scope(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(root)
    _issue(root)
    journey_os_generate.write(root)

    errors = _errors(
        root,
        [
            "apps/mobile/lib/providers/auth_provider.dart",
            "apps/mobile/lib/l10n/app_de.arb",
            "apps/mobile/lib/l10n/app_en.arb",
            "apps/mobile/lib/l10n/app_es.arb",
            "apps/mobile/lib/l10n/app_fr.arb",
            "apps/mobile/lib/l10n/app_it.arb",
            "apps/mobile/lib/l10n/app_pt.arb",
            "apps/mobile/lib/l10n/app_localizations.dart",
            "apps/mobile/lib/l10n/app_localizations_de.dart",
            "apps/mobile/lib/l10n/app_localizations_en.dart",
            "apps/mobile/lib/l10n/app_localizations_es.dart",
            "apps/mobile/lib/l10n/app_localizations_fr.dart",
            "apps/mobile/lib/l10n/app_localizations_it.dart",
            "apps/mobile/lib/l10n/app_localizations_pt.dart",
        ],
    )

    assert not any("outside Journey OS whitelist" in error for error in errors)


def test_jos006_coach_cta_stack_contract_scope_is_in_scope(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(root)
    _issue(root)
    journey_os_generate.write(root)

    errors = _errors(
        root,
        [
            ".planning/decisions/2026-05-09-perimeter-b7-cascade-empty-state/STUB.md",
            "apps/mobile/lib/screens/advisor/financial_report_screen_v2.dart",
            "apps/mobile/lib/screens/aujourdhui/aujourdhui_screen.dart",
            "apps/mobile/lib/screens/budget/budget_setup_screen.dart",
            "apps/mobile/test/screens/budget_setup_screen_test.dart",
            "apps/mobile/lib/screens/mon_argent/mon_argent_screen.dart",
            "apps/mobile/lib/screens/pillar_3a_deep/retroactive_3a_screen.dart",
            "apps/mobile/lib/screens/pillar_3a_deep/staggered_withdrawal_screen.dart",
            "apps/mobile/lib/widgets/aujourdhui/commitments_and_checkins_card.dart",
            "apps/mobile/test/architecture/navigation_push_doctrine_test.dart",
        ],
    )

    assert not any("outside Journey OS whitelist" in error for error in errors)


def test_jos014_coach_zombie_alias_hotfix_scope_is_in_scope(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(root)
    _issue(root)
    journey_os_generate.write(root)

    errors = _errors(
        root,
        [
            "apps/mobile/lib/screens/coach/retirement_dashboard_screen.dart",
            "apps/mobile/lib/screens/coach/chat_as_verb_demo_screen.dart",
            "apps/mobile/lib/screens/onboarding/data_block_enrichment_screen.dart",
            "apps/mobile/lib/widgets/aujourdhui/cap_du_jour_banner.dart",
            "apps/mobile/lib/widgets/coach/early_retirement_comparison.dart",
            "apps/mobile/lib/widgets/coach/explore_hub.dart",
            "apps/mobile/lib/widgets/coach/smart_shortcuts.dart",
            "apps/mobile/lib/widgets/coach/trajectory_card.dart",
            "apps/mobile/test/architecture/navigation_push_doctrine_test.dart",
        ],
    )

    assert not any("outside Journey OS whitelist" in error for error in errors)


def test_jos015_notification_route_canonical_hotfix_scope_is_in_scope(
    tmp_path: Path,
) -> None:
    root = _root(tmp_path)
    _record(root)
    _issue(root)
    journey_os_generate.write(root)

    errors = _errors(
        root,
        [
            "apps/mobile/lib/app.dart",
            "apps/mobile/lib/services/notification_deeplinks.dart",
            "apps/mobile/lib/services/notification_scheduler_service.dart",
            "apps/mobile/lib/services/notification_service.dart",
            "apps/mobile/test/services/check_in_notification_test.dart",
            "apps/mobile/test/services/notification_scheduler_service_test.dart",
            "apps/mobile/test/services/notification_service_test.dart",
            "tools/checks/journey_os_check.py",
            "tools/checks/tests/test_journey_os_check.py",
        ],
    )

    assert not any("outside Journey OS whitelist" in error for error in errors)


def test_jos016_dynamic_navigation_sink_scope_is_in_scope(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(root)
    _issue(root)
    journey_os_generate.write(root)

    errors = _errors(
        root,
        [
            "apps/mobile/lib/screens/coach/coach_chat_screen.dart",
            "apps/mobile/lib/services/navigation/mint_nav.dart",
            "apps/mobile/lib/widgets/coach/response_card_widget.dart",
            "apps/mobile/lib/widgets/coach/route_suggestion_card.dart",
            "apps/mobile/lib/widgets/coach/widget_renderer.dart",
            "apps/mobile/lib/widgets/pulse/cap_card.dart",
            "apps/mobile/test/architecture/navigation_push_doctrine_test.dart",
            "apps/mobile/test/services/navigation/mint_nav_test.dart",
            "tools/checks/journey_os_check.py",
            "tools/checks/tests/test_journey_os_check.py",
        ],
    )

    assert not any("outside Journey OS whitelist" in error for error in errors)


def test_coach_chat_widget_regression_scope_is_in_scope(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(root)
    _issue(root)
    journey_os_generate.write(root)

    errors = _errors(
        root,
        [
            "apps/mobile/test/screens/coach/coach_chat_test.dart",
        ],
    )

    assert not any("outside Journey OS whitelist" in error for error in errors)


def test_jos004_runtime_flow_completes_first_experience_before_coach() -> None:
    flow = (
        journey_os_check.REPO_ROOT
        / "tools/simulator/flows/maestro-perfect-set/"
        "flow_jos004_coach_advice_turn_runtime.yaml"
    ).read_text(encoding="utf-8")

    login = "mintapp:///auth/login?redirect=%2Fcoach%2Fchat"
    fixture = (
        "mintapp:///__e2e/row23-independent-no-lpp-profile?"
        "slug=cadre_salarie_lpp_suisse_ready"
    )
    coach = 'openLink: "mintapp:///coach/chat?'

    assert login in flow
    assert fixture in flow
    assert 'id: "e2e_profile_fixture_applied"' in flow
    assert flow.index(login) < flow.index(fixture) < flow.index(coach)

def test_onboarding_first_value_tracks_mint2_route_and_issue() -> None:
    record = json.loads(
        (
            journey_os_check.REPO_ROOT
            / ".planning/journeys/records/onboarding_first_value.json"
        ).read_text(encoding="utf-8")
    )

    assert "/retraite/rente-vs-capital" in record["route_paths"]
    assert "JOS-005" in record["issues"]

def test_journey_evidence_artifacts_are_in_scope(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(root)
    _issue(root)
    evidence_dir = root / ".planning/journeys/evidence/money_truth_spine/20260626T120000Z"
    evidence_dir.mkdir(parents=True)
    (evidence_dir / "result.xml").write_text("<testsuite/>", encoding="utf-8")
    journey_os_generate.write(root)

    errors = _errors(
        root,
        [
            ".planning/journeys/evidence/money_truth_spine/20260626T120000Z/result.xml",
        ],
    )

    assert not any("outside Journey OS whitelist" in error for error in errors)
    assert not any("unsupported Journey OS generated view" in error for error in errors)

def test_runtime_replay_raw_debug_artifacts_are_not_in_scope(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(root)
    _issue(root)
    raw_log = root / ".planning/journeys/evidence/runtime_replay/20260626T120000Z/money_truth_spine/debug/maestro.log"
    raw_log.parent.mkdir(parents=True)
    raw_log.write_text("[Failed] Assertion is false\n", encoding="utf-8")
    journey_os_generate.write(root)

    errors = _errors(
        root,
        [
            ".planning/journeys/evidence/runtime_replay/20260626T120000Z/money_truth_spine/debug/maestro.log",
        ],
    )

    assert any("outside Journey OS whitelist" in error for error in errors)

@pytest.mark.parametrize(
    "secret_text",
    [
        "signed in as staging@example.com\n",
        "MINT_E2E_PASSWORD=super-secret\n",
        "Authorization: Bearer abcdefghijklmnopqrstuvwxyz123456\n",
        "Bearer abcdefghijklmnopqrstuvwxyz123456\n",
    ],
)
def test_evidence_secret_lint_rejects_sensitive_patterns(tmp_path: Path, secret_text: str) -> None:
    root = _root(tmp_path)
    _record(root)
    _issue(root)
    evidence = root / ".planning/journeys/evidence/money_truth_spine/20260626T120000Z/result.txt"
    evidence.parent.mkdir(parents=True)
    evidence.write_text(secret_text, encoding="utf-8")
    journey_os_generate.write(root)

    errors = _errors(root, [str(evidence.relative_to(root))])

    assert any("forbidden evidence secret/PII marker" in error for error in errors)

def test_changed_includes_local_tracked_worktree_changes(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(root)
    _issue(root)
    journey_os_generate.write(root)
    (root / "rules.md").write_text("before\n", encoding="utf-8")

    subprocess.run(["git", "init"], cwd=root, check=True, capture_output=True)
    subprocess.run(
        ["git", "config", "user.email", "test@example.invalid"],
        cwd=root,
        check=True,
        capture_output=True,
    )
    subprocess.run(
        ["git", "config", "user.name", "Test"],
        cwd=root,
        check=True,
        capture_output=True,
    )
    subprocess.run(["git", "add", "."], cwd=root, check=True, capture_output=True)
    subprocess.run(
        ["git", "commit", "-m", "baseline"],
        cwd=root,
        check=True,
        capture_output=True,
    )
    sha = subprocess.run(
        ["git", "rev-parse", "HEAD"],
        cwd=root,
        check=True,
        text=True,
        capture_output=True,
    ).stdout.strip()
    record_path = root / ".planning/journeys/records/money_truth_spine.json"
    record = json.loads(record_path.read_text(encoding="utf-8"))
    record["evidence"][0]["verified_commit"] = sha
    record_path.write_text(json.dumps(record), encoding="utf-8")
    journey_os_generate.write(root)
    subprocess.run(["git", "add", "."], cwd=root, check=True, capture_output=True)
    subprocess.run(
        ["git", "commit", "-m", "valid provenance"],
        cwd=root,
        check=True,
        capture_output=True,
    )
    subprocess.run(
        ["git", "update-ref", "refs/remotes/origin/dev", "HEAD"],
        cwd=root,
        check=True,
        capture_output=True,
    )

    (root / "rules.md").write_text("after\n", encoding="utf-8")

    changed, errors = journey_os_check._changed(root, "origin/dev")

    assert errors == []
    assert "rules.md" in changed
    assert journey_os_check.check(root, base_ref="origin/dev") == []

def test_jos_issue_refs_require_registry_files(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(root)
    journey_os_generate.write(root)
    assert any("missing Journey OS issue" in error for error in _errors(root))

def test_issue_registry_and_generated_board(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(root, external_apis=["POST /api/v1/coach/chat"])
    _issue(root)
    journey_os_generate.write(root)
    assert _errors(root) == []
    board = (root / ".planning/journeys/BOARD.md").read_text(encoding="utf-8")
    today = (root / ".planning/journeys/TODAY.md").read_text(encoding="utf-8")
    system_map = (root / ".planning/journeys/diagrams/system_map.mmd").read_text(encoding="utf-8")
    assert "Next Journey OS Work" in board
    assert "Latest proof" in board
    assert "JOS-001" in board
    assert "money_truth_spine" in board
    assert "Journey OS Today" in today
    assert "flowchart LR" in system_map
    assert "route_coach_chat" in system_map
    assert "api_POST_api_v1_coach_chat" in system_map
    assert "classDef green" in system_map
    assert "classDef api" in system_map
    assert "\\n" not in system_map
    cards = (root / ".planning/journeys/CARDS.md").read_text(encoding="utf-8")
    state = (root / ".planning/journeys/diagrams/journey_state.mmd").read_text(encoding="utf-8")
    route_topology = (root / ".planning/journeys/diagrams/route_topology.mmd").read_text(encoding="utf-8")
    sequence = (root / ".planning/journeys/diagrams/money_truth_spine_sequence.mmd").read_text(encoding="utf-8")
    assert "## money_truth_spine" in cards
    assert "Persona" in cards
    assert "Entry state" in cards
    assert "Negative assertions" in cards
    assert "stateDiagram-v2" in state
    assert "sequenceDiagram" in sequence
    assert "Surfaces->>APIs" in sequence
    assert "APIs-->>Surfaces" in sequence
    assert "flowchart LR" in route_topology
    assert "route__budget" in route_topology
    assert "route__legacy_budget" in route_topology
    assert 'route__coach_chat["/coach/chat<br/>destination/system<br/>public"]' in route_topology
    assert 'route__mon_argent["/mon-argent<br/>destination/system<br/>authenticated"]' in route_topology
    assert 'route__profile["/profile<br/>destination/system<br/>authenticated"]' in route_topology
    assert 'route__profile_bilan["/profile/bilan<br/>destination/system<br/>public"]' in route_topology
    assert 'route__legacy_budget["/legacy/budget<br/>alias/system<br/>onboarding"]' in route_topology
    assert "class route__coach_chat public" in route_topology
    assert "class route__mon_argent auth" in route_topology
    assert "class route__profile auth" in route_topology
    assert "class route__profile_bilan public" in route_topology
    assert "class route__legacy_budget onboarding" in route_topology
    assert "route__legacy_budget -. redirects .-> route__budget" in route_topology

def test_external_apis_must_match_canonical_openapi(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(root, external_apis=["POST /auth/register"])
    _issue(root)
    journey_os_generate.write(root)

    assert any("external_api is not in canonical OpenAPI" in error for error in _errors(root))

def test_canonical_openapi_must_be_readable_json_with_operations(tmp_path: Path) -> None:
    root = _root(tmp_path)
    (root / "tools/openapi/mint.openapi.canonical.json").unlink()
    _record(root, external_apis=["POST /api/v1/coach/chat"])
    _issue(root)
    journey_os_generate.write(root)
    assert any("unable to read canonical OpenAPI" in error for error in _errors(root))

    root = _root(tmp_path / "invalid")
    (root / "tools/openapi/mint.openapi.canonical.json").write_text("{", encoding="utf-8")
    _record(root, external_apis=["POST /api/v1/coach/chat"])
    _issue(root)
    journey_os_generate.write(root)
    assert any("invalid JSON" in error for error in _errors(root))

    root = _root(tmp_path / "empty")
    (root / "tools/openapi/mint.openapi.canonical.json").write_text(
        json.dumps({"paths": {"/ping": {}}}),
        encoding="utf-8",
    )
    _record(root, external_apis=["POST /api/v1/coach/chat"])
    _issue(root)
    journey_os_generate.write(root)
    assert any("contains no executable operations" in error for error in _errors(root))

def test_external_apis_accept_parameterized_canonical_openapi_paths(tmp_path: Path) -> None:
    root = _root(tmp_path)
    openapi = json.loads((root / "tools/openapi/mint.openapi.canonical.json").read_text(encoding="utf-8"))
    openapi["paths"]["/api/v1/privacy/exports/{export_id}"] = {"get": {}}
    (root / "tools/openapi/mint.openapi.canonical.json").write_text(json.dumps(openapi), encoding="utf-8")
    _record(root, external_apis=["GET /api/v1/privacy/exports/{export_id}"])
    _issue(root)
    journey_os_generate.write(root)

    assert _errors(root) == []

def test_journey_contract_fields_are_required(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(root)
    path = root / ".planning/journeys/records/money_truth_spine.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    del data["entry_state"]
    data["negative_assertions"] = []
    path.write_text(json.dumps(data), encoding="utf-8")
    _issue(root)
    journey_os_generate.write(root)

    errors = _errors(root)
    assert any("entry_state" in error for error in errors)
    assert any("negative_assertions" in error for error in errors)

def test_source_spec_refs_must_be_existing_repo_relative_paths(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(root, source_spec_refs=["/tmp/not-a-mint-spec.md", "../escape.md", "missing/SPEC.md"])
    _issue(root)
    journey_os_generate.write(root)

    errors = _errors(root)
    assert sum("source_spec_ref must be an existing repo-relative path" in error for error in errors) == 3

def test_proof_and_fix_owners_must_be_mint_roster_entries(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(root, proof_owner="external-consultant", fix_owner="not-a-team")
    _issue(root)
    journey_os_generate.write(root)

    errors = _errors(root)
    assert any("proof_owner must be a Mint roster entry" in error for error in errors)
    assert any("fix_owner must be a Mint roster entry" in error for error in errors)

def test_runtime_replay_contract_is_required_and_executable(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(root)
    path = root / ".planning/journeys/records/money_truth_spine.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    del data["runtime_replay"]
    path.write_text(json.dumps(data), encoding="utf-8")
    _issue(root)
    journey_os_generate.write(root)

    assert any("runtime_replay" in error for error in _errors(root))

    root = _root(tmp_path / "missing_flow")
    _record(
        root,
        runtime_replay={
            "flow": "tools/simulator/flows/missing.yaml",
            "sets": ["core"],
            "device": "MINT iPhone 13 mini RvC",
            "build_defines": ["MINT_DISABLE_BETA_MODAL=true"],
            "requires_auth": False,
            "order": 10,
        },
    )
    _issue(root)
    journey_os_generate.write(root)

    assert any("runtime_replay.flow does not exist" in error for error in _errors(root))

def test_authenticated_runtime_replay_cannot_live_in_secretless_set(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(
        root,
        runtime_replay={
            "flow": "tools/simulator/flows/maestro-perfect-set/flow_money_trust_chain_budget_mon_argent_rapport_coach.yaml",
            "sets": ["core"],
            "device": "MINT iPhone 13 mini RvC",
            "build_defines": ["MINT_DISABLE_BETA_MODAL=true"],
            "requires_auth": True,
            "order": 10,
        },
    )
    _issue(root)
    journey_os_generate.write(root)

    assert any("authenticated runtime_replay must be in authenticated or account_lifecycle set" in error for error in _errors(root))

def test_top_journey_issue_requires_top_runtime_replay_set(tmp_path: Path) -> None:
    root = _root(tmp_path)
    (root / "artifacts/red.xml").write_text(FAILING_XML, encoding="utf-8")
    _record(
        root,
        id="onboarding_first_value",
        title="Onboarding first value",
        _stem="onboarding_first_value",
        issues=["JOS-005"],
        evidence=[
            {
                "kind": "runtime",
                "status": "red",
                "command": "maestro test onboarding.yaml",
                "artifact": "artifacts/red.xml",
                "verified_at": "2026-06-27T00:00:00Z",
                "verified_commit": SHA_A,
            }
        ],
        runtime_replay={
            "flow": "tools/simulator/flows/maestro-perfect-set/flow_money_trust_chain_budget_mon_argent_rapport_coach.yaml",
            "sets": ["core"],
            "device": "MINT iPhone 13 mini RvC",
            "build_defines": ["MINT_DISABLE_BETA_MODAL=true"],
            "requires_auth": False,
            "order": 10,
        },
    )
    _issue(root, id="JOS-005", journey_id="onboarding_first_value", status="regressed", evidence_status="red")
    journey_os_generate.write(root)

    assert any("runtime_replay.sets top" in error for error in _errors(root))

def test_live_proven_external_apis_need_exact_evidence_text(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(root, status="live_proven", external_apis=["POST /api/v1/coach/chat"])
    _issue(root, status="verified", evidence_status="green")
    journey_os_generate.write(root)

    assert any("external_api lacks exact evidence text" in error for error in _errors(root))

    root = _root(tmp_path / "with_exact_api")
    _record(
        root,
        status="live_proven",
        external_apis=["POST /api/v1/coach/chat"],
        evidence=[
            {
                "kind": "runtime",
                "status": "green",
                "command": "maestro test flow.yaml && curl -X POST /api/v1/coach/chat",
                "artifact": "artifacts/result.xml",
                "verified_at": "2026-06-26T00:00:00Z",
                "verified_commit": SHA_A,
            }
        ],
    )
    _issue(root, status="verified", evidence_status="green")
    journey_os_generate.write(root)

    assert _errors(root) == []

def test_today_does_not_promote_green_issue_when_no_actionable_work(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(root, status="live_proven")
    _issue(root, status="verified", evidence_status="green")
    journey_os_generate.write(root)
    today = (root / ".planning/journeys/TODAY.md").read_text(encoding="utf-8")

    assert "No red, missing, or baselined Journey OS issue is currently queued." in today
    assert "| JOS-001 |" not in today

def test_today_routes_red_before_higher_priority_baselined_issue(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(
        root,
        id="coach_advice_turn",
        title="Coach advice turn",
        _stem="coach_advice_turn",
        issues=["JOS-001"],
        evidence=[
            {
                "kind": "runtime",
                "status": "baselined",
                "command": "maestro test coach.yaml",
                "artifact": "artifacts/result.xml",
                "debt_ref": "JOS-001",
                "verified_at": "2026-06-27T00:00:00Z",
                "verified_commit": SHA_A,
            }
        ],
    )
    _issue(root, id="JOS-001", journey_id="coach_advice_turn", evidence_status="baselined")
    (root / "artifacts/red.xml").write_text(FAILING_XML, encoding="utf-8")
    _record(
        root,
        id="onboarding_first_value",
        title="Onboarding first value",
        _stem="onboarding_first_value",
        issues=["JOS-002"],
        priority={
            "trust_blast_radius": 4,
            "release_blocker_weight": 4,
            "user_frequency": 4,
            "evidence_gap": 2,
            "route_centrality": 4,
            "compliance_risk": 2,
            "learning_value": 4,
            "proof_cost": 3,
            "rationale": "Lower priority red issue must still route before baselined work.",
        },
        runtime_replay={
            "flow": "tools/simulator/flows/maestro-perfect-set/flow_money_trust_chain_budget_mon_argent_rapport_coach.yaml",
            "sets": ["top"],
            "device": "MINT iPhone 13 mini RvC",
            "build_defines": ["MINT_DISABLE_BETA_MODAL=true"],
            "requires_auth": False,
            "order": 10,
        },
        evidence=[
            {
                "kind": "runtime",
                "status": "red",
                "command": "maestro test onboarding.yaml",
                "artifact": "artifacts/red.xml",
                "verified_at": "2026-06-27T00:00:00Z",
                "verified_commit": SHA_B,
            }
        ],
    )
    _issue(root, id="JOS-002", journey_id="onboarding_first_value", status="regressed", evidence_status="red")
    journey_os_generate.write(root)
    today = (root / ".planning/journeys/TODAY.md").read_text(encoding="utf-8")

    assert "| JOS-002 | P0 | regressed | onboarding_first_value |" in today
    assert "| JOS-001 |" not in today

def test_issue_status_tracks_referenced_record_evidence(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(root)
    _issue(root, status="triaged", evidence_status="missing")
    journey_os_generate.write(root)
    errors = _errors(root)
    assert any("cannot stay triaged" in error for error in errors)
    assert any("cannot stay missing" in error for error in errors)
    root = _root(tmp_path / "overclaim")
    _record(root, evidence=[{"kind": "runtime", "status": "missing", "command": None, "artifact": None}])
    _issue(root, status="proof_needed", evidence_status="green")
    journey_os_generate.write(root)
    assert any("cannot be green" in error for error in _errors(root))

def test_issue_registry_shape_rules(tmp_path: Path) -> None:
    cases = [
        ({"journey_id": "missing_journey"}, "journey_id"),
        ({"status": "new"}, "status"),
        ({"owner": "vendor-agent"}, "owner"),
        ({"severity": "S0"}, "severity"),
        ({"evidence_status": "unknown"}, "evidence_status"),
        ({"id": "BUG-1"}, "JOS-###"),
        ({"next_action": "Too short"}, "next_action"),
    ]
    for update, expected in cases:
        root = _root(tmp_path / expected)
        _record(root)
        _issue(root, **update)
        journey_os_generate.write(root)
        assert any(expected in error for error in _errors(root)), expected

def test_route_owner_status_and_artifact_rules(tmp_path: Path) -> None:
    cases = [
        ({"route_paths": ["/budget", "DELETE /auth/account"]}, "not a registered route"),
        ({"accountable_team": "vendor-agent"}, "accountable_team"),
        ({"evidence": [{"kind": "runtime", "command": "x", "artifact": "artifacts/result.xml"}]}, "status"),
        ({"evidence": [{"kind": "runtime", "status": "green", "command": "x", "artifact": "/tmp/x.xml"}]}, "durable"),
        ({"evidence": [{"kind": "unit", "status": "baselined", "command": "pytest", "artifact": "artifacts/result.xml"}]}, "debt_ref"),
        ({"status": "live_proven", "evidence": [{"kind": "runtime", "status": "red", "command": "x", "artifact": "artifacts/result.xml"}]}, "live_proven"),
    ]
    for update, expected in cases:
        root = _root(tmp_path / expected.replace("/", "_"))
        _record(root, **update)
        _issue(root)
        assert any(expected in error for error in _errors(root)), expected

def test_shape_filename_and_generated_view_rules(tmp_path: Path) -> None:
    cases = [
        ({"title": ""}, "title"),
        ({"tier": "P0"}, "tier"),
        ({"surfaces": ["Budget", 3]}, "surfaces"),
        ({"unknown": True}, "unknown field"),
        ({"_stem": "other_id"}, "filename stem"),
        ({"priority": {"rationale": "too small"}}, "priority missing"),
        ({"priority": {"trust_blast_radius": 1, "release_blocker_weight": 1, "user_frequency": 1, "evidence_gap": 1, "route_centrality": 1, "compliance_risk": 1, "learning_value": 1, "proof_cost": 5, "rationale": "This T0 score is intentionally below the threshold."}}, "T0 priority score"),
    ]
    for update, expected in cases:
        root = _root(tmp_path / expected.replace(" ", "_"))
        _record(root, **update)
        _issue(root)
        assert any(expected in error for error in _errors(root)), expected
    root = _root(tmp_path / "mermaid")
    _record(root)
    _issue(root)
    readme = root / ".planning/journeys/README.md"
    readme.write_text("```mermaid\ngraph TD\n```", encoding="utf-8")
    assert any("Mermaid" in error for error in _errors(root, [".planning/journeys/README.md"]))

def test_generated_views_are_required_and_current(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(root)
    _issue(root)
    assert any("missing generated" in error for error in _errors(root))
    journey_os_generate.write(root)
    (root / ".planning/journeys/JOURNEYS.md").write_text("stale\n", encoding="utf-8")
    assert any("stale generated" in error for error in _errors(root))

def test_generated_mermaid_views_are_required_and_current(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(root)
    _issue(root)
    journey_os_generate.write(root)

    (root / ".planning/journeys/diagrams/system_map.mmd").unlink()
    assert any("missing generated" in error for error in _errors(root))

    journey_os_generate.write(root)
    (root / ".planning/journeys/diagrams/money_truth_spine.mmd").write_text("stale\n", encoding="utf-8")
    assert any("stale generated" in error for error in _errors(root))

    journey_os_generate.write(root)
    (root / ".planning/journeys/diagrams/orphan.mmd").write_text("flowchart TD\n", encoding="utf-8")
    assert any("orphan generated" in error for error in _errors(root))

def test_schema_files_are_executed(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(root)
    _issue(root)
    journey_os_generate.write(root)
    schema_path = root / ".planning/journeys/journey.schema.json"
    schema = json.loads(schema_path.read_text(encoding="utf-8"))
    schema["required"].append("schema_only_field")
    schema_path.write_text(json.dumps(schema), encoding="utf-8")

    assert any("schema_only_field" in error for error in _errors(root))

def test_green_runtime_xml_artifact_cannot_report_failures(tmp_path: Path) -> None:
    root = _root(tmp_path)
    (root / "artifacts/result.xml").write_text(FAILING_XML, encoding="utf-8")
    _record(root)
    _issue(root)
    journey_os_generate.write(root)

    assert any("green but JUnit artifact reports failures" in error for error in _errors(root))

def test_green_runtime_xml_artifact_cannot_be_vacuous(tmp_path: Path) -> None:
    root = _root(tmp_path)
    (root / "artifacts/result.xml").write_text("<testsuite/>", encoding="utf-8")
    _record(root)
    _issue(root)
    journey_os_generate.write(root)

    assert any("zero executed tests" in error for error in _errors(root))

def test_green_runtime_xml_artifact_cannot_be_all_skipped(tmp_path: Path) -> None:
    root = _root(tmp_path)
    (root / "artifacts/result.xml").write_text(SKIPPED_XML, encoding="utf-8")
    _record(root)
    _issue(root)
    journey_os_generate.write(root)

    assert any("zero executed tests" in error for error in _errors(root))

def test_baselined_runtime_xml_artifact_cannot_be_vacuous(tmp_path: Path) -> None:
    root = _root(tmp_path)
    (root / "artifacts/result.xml").write_text("<testsuite/>", encoding="utf-8")
    _record(
        root,
        evidence=[
            {
                "kind": "runtime",
                "status": "baselined",
                "command": "maestro test flow.yaml",
                "artifact": "artifacts/result.xml",
                "debt_ref": "JOS-TEST",
                "verified_at": "2026-06-26T00:00:00Z",
                "verified_commit": SHA_A,
            }
        ],
    )
    _issue(root, evidence_status="baselined")
    journey_os_generate.write(root)

    assert any("zero executed tests" in error for error in _errors(root))

def test_runtime_evidence_requires_verified_provenance(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(
        root,
        evidence=[{"kind": "runtime", "status": "green", "command": "maestro test flow.yaml", "artifact": "artifacts/result.xml"}],
    )
    _issue(root)
    journey_os_generate.write(root)

    errors = _errors(root)
    assert any("requires verified_at" in error for error in errors)
    assert any("requires verified_commit" in error for error in errors)

def test_runtime_evidence_rejects_future_verified_at(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(
        root,
        evidence=[
            {
                "kind": "runtime",
                "status": "green",
                "command": "maestro test flow.yaml",
                "artifact": "artifacts/result.xml",
                "verified_at": "2999-01-01T00:00:00Z",
                "verified_commit": SHA_A,
            }
        ],
    )
    _issue(root)
    journey_os_generate.write(root)

    assert any("requires verified_at" in error for error in _errors(root))

def test_runtime_evidence_requires_full_sha(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(
        root,
        evidence=[
            {
                "kind": "runtime",
                "status": "green",
                "command": "maestro test flow.yaml",
                "artifact": "artifacts/result.xml",
                "verified_at": "2026-06-26T00:00:00Z",
                "verified_commit": "abc123",
            }
        ],
    )
    _issue(root)
    journey_os_generate.write(root)

    assert any("full SHA" in error for error in _errors(root))

def test_runtime_evidence_requires_existing_git_commit(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(
        root,
        evidence=[
            {
                "kind": "runtime",
                "status": "green",
                "command": "maestro test flow.yaml",
                "artifact": "artifacts/result.xml",
                "verified_at": "2026-06-26T00:00:00Z",
                "verified_commit": "f" * 40,
            }
        ],
    )
    _issue(root)
    journey_os_generate.write(root)

    subprocess.run(["git", "init"], cwd=root, check=True, capture_output=True)
    subprocess.run(
        ["git", "config", "user.email", "test@example.invalid"],
        cwd=root,
        check=True,
        capture_output=True,
    )
    subprocess.run(
        ["git", "config", "user.name", "Test"],
        cwd=root,
        check=True,
        capture_output=True,
    )
    subprocess.run(["git", "add", "."], cwd=root, check=True, capture_output=True)
    subprocess.run(
        ["git", "commit", "-m", "baseline"],
        cwd=root,
        check=True,
        capture_output=True,
    )

    assert any("exists in git history" in error for error in _errors(root))

def test_runtime_evidence_rejects_commit_outside_current_head_history(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(root)
    _issue(root)
    journey_os_generate.write(root)

    subprocess.run(["git", "init"], cwd=root, check=True, capture_output=True)
    subprocess.run(
        ["git", "config", "user.email", "test@example.invalid"],
        cwd=root,
        check=True,
        capture_output=True,
    )
    subprocess.run(
        ["git", "config", "user.name", "Test"],
        cwd=root,
        check=True,
        capture_output=True,
    )
    subprocess.run(["git", "add", "."], cwd=root, check=True, capture_output=True)
    subprocess.run(
        ["git", "commit", "-m", "baseline"],
        cwd=root,
        check=True,
        capture_output=True,
    )
    base_branch = subprocess.run(
        ["git", "branch", "--show-current"],
        cwd=root,
        check=True,
        text=True,
        capture_output=True,
    ).stdout.strip()
    subprocess.run(["git", "switch", "-c", "side-proof"], cwd=root, check=True, capture_output=True)
    (root / "side-proof.txt").write_text("side only\n", encoding="utf-8")
    subprocess.run(["git", "add", "side-proof.txt"], cwd=root, check=True, capture_output=True)
    subprocess.run(
        ["git", "commit", "-m", "side proof"],
        cwd=root,
        check=True,
        capture_output=True,
    )
    side_sha = subprocess.run(
        ["git", "rev-parse", "HEAD"],
        cwd=root,
        check=True,
        text=True,
        capture_output=True,
    ).stdout.strip()
    subprocess.run(["git", "switch", base_branch], cwd=root, check=True, capture_output=True)

    _record(
        root,
        evidence=[
            {
                "kind": "runtime",
                "status": "green",
                "command": "maestro test flow.yaml",
                "artifact": "artifacts/result.xml",
                "verified_at": "2026-06-26T00:00:00Z",
                "verified_commit": side_sha,
            }
        ],
    )
    _issue(root)
    journey_os_generate.write(root)

    assert any("current HEAD history" in error for error in _errors(root))

def test_red_runtime_xml_artifact_requires_failure(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(
        root,
        evidence=[
            {
                "kind": "runtime",
                "status": "red",
                "command": "maestro test flow.yaml",
                "artifact": "artifacts/result.xml",
                "verified_at": "2026-06-26T00:00:00Z",
                "verified_commit": SHA_A,
            }
        ],
    )
    _issue(root, evidence_status="red")
    journey_os_generate.write(root)

    assert any("red but JUnit artifact reports no failures" in error for error in _errors(root))

def test_runtime_replay_evidence_requires_clean_manifest(tmp_path: Path) -> None:
    root = _root(tmp_path)
    artifact = root / ".planning/journeys/evidence/runtime_replay/20260626T120000Z/money_truth_spine/result.xml"
    artifact.parent.mkdir(parents=True)
    artifact.write_text(FAILING_XML, encoding="utf-8")
    _record(
        root,
        evidence=[
            {
                "kind": "runtime",
                "status": "red",
                "command": "bash tools/simulator/journey_os_runtime_replay.sh --set core",
                "artifact": str(artifact.relative_to(root)),
                "verified_at": "2026-06-26T00:00:00Z",
                "verified_commit": SHA_A,
            }
        ],
    )
    _issue(root, status="regressed", evidence_status="red")
    journey_os_generate.write(root)

    assert any("runtime_replay evidence requires sibling manifest" in error for error in _errors(root))

def test_runtime_replay_manifest_must_match_evidence_commit_and_result(tmp_path: Path) -> None:
    root = _root(tmp_path)
    artifact = root / ".planning/journeys/evidence/runtime_replay/20260626T120000Z/money_truth_spine/result.xml"
    artifact.parent.mkdir(parents=True)
    artifact.write_text(FAILING_XML, encoding="utf-8")
    (artifact.parents[1] / "manifest.json").write_text(
        json.dumps(
            {
                "schema_version": 1,
                "created_at": "20260626T120000Z",
                "runtime_set": "core",
                "git_head": SHA_A,
                "git_dirty": False,
                "git_status_porcelain": "",
                "git_status_sha256": journey_os_check.EMPTY_SHA256,
                "git_diff_sha256": journey_os_check.EMPTY_SHA256,
                "replay_script_sha256": "2" * 64,
                "journeys": [
                    {
                        "journey": "money_truth_spine",
                        "flow": "tools/simulator/flows/maestro-perfect-set/flow_money_trust_chain_budget_mon_argent_rapport_coach.yaml",
                        "flow_sha256": "3" * 64,
                        "result": {"status": "failed", "exit_code": 1},
                    }
                ],
            }
        ),
        encoding="utf-8",
    )
    _record(
        root,
        evidence=[
            {
                "kind": "runtime",
                "status": "red",
                "command": "bash tools/simulator/journey_os_runtime_replay.sh --set core",
                "artifact": str(artifact.relative_to(root)),
                "verified_at": "2026-06-26T00:00:00Z",
                "verified_commit": SHA_A,
            }
        ],
    )
    _issue(root, status="regressed", evidence_status="red")
    journey_os_generate.write(root)

    assert not any("runtime_replay manifest" in error for error in _errors(root))

def _runtime_replay_manifest_fixture(
    root: Path,
    *,
    evidence_status: str = "red",
    result_status: str = "failed",
    manifest_updates: dict[str, object] | None = None,
    journey_updates: dict[str, object] | None = None,
) -> None:
    artifact = root / ".planning/journeys/evidence/runtime_replay/20260626T120000Z/money_truth_spine/result.xml"
    artifact.parent.mkdir(parents=True)
    artifact.write_text(FAILING_XML if evidence_status == "red" else GOOD_XML, encoding="utf-8")
    journey = {
        "journey": "money_truth_spine",
        "flow": "tools/simulator/flows/maestro-perfect-set/flow_money_trust_chain_budget_mon_argent_rapport_coach.yaml",
        "flow_sha256": "3" * 64,
        "result": {"status": result_status, "exit_code": 1 if result_status == "failed" else 0},
    }
    if journey_updates:
        journey.update(journey_updates)
    manifest: dict[str, object] = {
        "schema_version": 1,
        "created_at": "20260626T120000Z",
        "runtime_set": "core",
        "git_head": SHA_A,
        "git_dirty": False,
        "git_status_porcelain": "",
        "git_status_sha256": journey_os_check.EMPTY_SHA256,
        "git_diff_sha256": journey_os_check.EMPTY_SHA256,
        "replay_script_sha256": "2" * 64,
        "journeys": [journey],
    }
    if manifest_updates:
        manifest.update(manifest_updates)
    (artifact.parents[1] / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
    _record(
        root,
        evidence=[
            {
                "kind": "runtime",
                "status": evidence_status,
                "command": "bash tools/simulator/journey_os_runtime_replay.sh --set core",
                "artifact": str(artifact.relative_to(root)),
                "verified_at": "2026-06-26T00:00:00Z",
                "verified_commit": SHA_A,
            }
        ],
    )
    _issue(
        root,
        status="regressed" if evidence_status == "red" else "verified",
        evidence_status=evidence_status,
    )
    journey_os_generate.write(root)

@pytest.mark.parametrize(
    ("manifest_updates", "expected"),
    [
        ({"git_head": SHA_B}, "manifest git_head must match verified_commit"),
        ({"git_dirty": True}, "manifest must prove git_dirty=false"),
        ({"git_status_porcelain": " M tools/simulator/journey_os_runtime_replay.sh"}, "empty git_status_porcelain"),
        ({"git_status_sha256": "1" * 64}, "empty git_status_sha256"),
        ({"git_diff_sha256": "1" * 64}, "empty git_diff_sha256"),
        ({"replay_script_sha256": "not-a-sha"}, "missing replay_script_sha256"),
    ],
)
def test_runtime_replay_manifest_negative_provenance_checks(
    tmp_path: Path,
    manifest_updates: dict[str, object],
    expected: str,
) -> None:
    root = _root(tmp_path)
    _runtime_replay_manifest_fixture(root, manifest_updates=manifest_updates)

    assert any(expected in error for error in _errors(root))

@pytest.mark.parametrize(
    ("evidence_status", "result_status", "expected"),
    [
        ("red", "passed", "red runtime_replay evidence requires failed manifest result"),
        ("green", "failed", "green runtime_replay evidence requires passed manifest result"),
    ],
)
def test_runtime_replay_manifest_result_must_match_evidence_status(
    tmp_path: Path,
    evidence_status: str,
    result_status: str,
    expected: str,
) -> None:
    root = _root(tmp_path)
    _runtime_replay_manifest_fixture(root, evidence_status=evidence_status, result_status=result_status)

    assert any(expected in error for error in _errors(root))

def test_green_text_artifact_cannot_contain_failure_marker(tmp_path: Path) -> None:
    root = _root(tmp_path)
    artifact = root / ".planning/journeys/evidence/money_truth_spine/20260626T120000Z/result.txt"
    artifact.parent.mkdir(parents=True)
    artifact.write_text("[Failed] Assertion is false\n", encoding="utf-8")
    _record(
        root,
        evidence=[
            {
                "kind": "runtime",
                "status": "green",
                "command": "maestro test flow.yaml",
                "artifact": str(artifact.relative_to(root)),
                "verified_at": "2026-06-26T00:00:00Z",
                "verified_commit": SHA_A,
            }
        ],
    )
    _issue(root)
    journey_os_generate.write(root)

    assert any("text artifact contains failure markers" in error for error in _errors(root))

def test_green_text_artifact_needs_success_marker(tmp_path: Path) -> None:
    root = _root(tmp_path)
    artifact = root / ".planning/journeys/evidence/money_truth_spine/20260626T120000Z/result.txt"
    artifact.parent.mkdir(parents=True)
    artifact.write_text("Assert that id: money_screen is visible... COMPLETED\n", encoding="utf-8")
    _record(
        root,
        evidence=[
            {
                "kind": "runtime",
                "status": "green",
                "command": "maestro test flow.yaml",
                "artifact": str(artifact.relative_to(root)),
                "verified_at": "2026-06-26T00:00:00Z",
                "verified_commit": SHA_A,
            }
        ],
    )
    _issue(root)
    journey_os_generate.write(root)

    assert any("needs an explicit success marker" in error for error in _errors(root))

def test_runtime_evidence_rejects_arbitrary_artifact_type(tmp_path: Path) -> None:
    root = _root(tmp_path)
    source_artifact = root / "apps/mobile/lib/routes/route_metadata.dart"
    _record(
        root,
        evidence=[
            {
                "kind": "runtime",
                "status": "green",
                "command": "maestro test flow.yaml",
                "artifact": str(source_artifact.relative_to(root)),
                "verified_at": "2026-06-26T00:00:00Z",
                "verified_commit": SHA_A,
            }
        ],
    )
    _issue(root)
    journey_os_generate.write(root)

    assert any("runtime evidence must use a parseable" in error for error in _errors(root))

def test_scope_allows_mint2_route_contract_json(tmp_path: Path) -> None:
    root = _root(tmp_path)
    _record(root)
    _issue(root)
    journey_os_generate.write(root)
    contract = (
        root
        / ".planning/phases/mint-2-0-first-experience-rente-capital/route_contracts/money_truth_spine.json"
    )
    contract.parent.mkdir(parents=True)
    contract.write_text("{}", encoding="utf-8")

    errors = _errors(
        root,
        [
            ".planning/phases/mint-2-0-first-experience-rente-capital/route_contracts/money_truth_spine.json"
        ],
    )

    assert not any("changed file outside Journey OS whitelist" in error for error in errors)

def test_red_text_artifact_requires_failure_marker(tmp_path: Path) -> None:
    root = _root(tmp_path)
    artifact = root / ".planning/journeys/evidence/money_truth_spine/20260626T120000Z/result.txt"
    artifact.parent.mkdir(parents=True)
    artifact.write_text("No structured failure marker\n", encoding="utf-8")
    _record(
        root,
        evidence=[
            {
                "kind": "runtime",
                "status": "red",
                "command": "maestro test flow.yaml",
                "artifact": str(artifact.relative_to(root)),
                "verified_at": "2026-06-26T00:00:00Z",
                "verified_commit": SHA_A,
            }
        ],
    )
    _issue(root, evidence_status="red")
    journey_os_generate.write(root)

    assert any("text artifact has no failure marker" in error for error in _errors(root))

def test_green_issue_rejects_latest_red_evidence(tmp_path: Path) -> None:
    root = _root(tmp_path)
    (root / "artifacts/green.xml").write_text(GOOD_XML, encoding="utf-8")
    (root / "artifacts/red.xml").write_text(FAILING_XML, encoding="utf-8")
    _record(
        root,
        evidence=[
            {
                "kind": "runtime",
                "status": "green",
                "command": "maestro test flow.yaml",
                "artifact": "artifacts/green.xml",
                "verified_at": "2026-06-26T00:00:00Z",
                "verified_commit": SHA_A,
            },
            {
                "kind": "runtime",
                "status": "red",
                "command": "maestro test flow.yaml",
                "artifact": "artifacts/red.xml",
                "verified_at": "2026-06-27T00:00:00Z",
                "verified_commit": SHA_B,
            },
        ],
    )
    _issue(root, status="verified", evidence_status="green")
    journey_os_generate.write(root)

    assert any("latest evidence" in error for error in _errors(root))

def test_green_issue_rejects_latest_baselined_evidence(tmp_path: Path) -> None:
    root = _root(tmp_path)
    (root / "artifacts/green.xml").write_text(GOOD_XML, encoding="utf-8")
    _record(
        root,
        evidence=[
            {
                "kind": "runtime",
                "status": "green",
                "command": "maestro test flow.yaml",
                "artifact": "artifacts/green.xml",
                "verified_at": "2026-06-26T00:00:00Z",
                "verified_commit": SHA_A,
            },
            {
                "kind": "runtime",
                "status": "baselined",
                "command": "maestro test flow.yaml",
                "artifact": "artifacts/result.xml",
                "debt_ref": "JOS-TEST",
                "verified_at": "2026-06-27T00:00:00Z",
                "verified_commit": SHA_B,
            },
        ],
    )
    _issue(root, status="verified", evidence_status="green")
    journey_os_generate.write(root)

    assert any("latest evidence" in error and "baselined" in error for error in _errors(root))

def test_live_proven_rejects_latest_red_runtime_evidence(tmp_path: Path) -> None:
    root = _root(tmp_path)
    (root / "artifacts/green.xml").write_text(GOOD_XML, encoding="utf-8")
    (root / "artifacts/red.xml").write_text(FAILING_XML, encoding="utf-8")
    _record(
        root,
        status="live_proven",
        evidence=[
            {
                "kind": "runtime",
                "status": "green",
                "command": "maestro test flow.yaml",
                "artifact": "artifacts/green.xml",
                "verified_at": "2026-06-26T00:00:00Z",
                "verified_commit": SHA_A,
            },
            {
                "kind": "runtime",
                "status": "red",
                "command": "maestro test flow.yaml",
                "artifact": "artifacts/red.xml",
                "verified_at": "2026-06-27T00:00:00Z",
                "verified_commit": SHA_B,
            },
        ],
    )
    _issue(root, evidence_status="red")
    journey_os_generate.write(root)

    assert any("latest runtime evidence" in error for error in _errors(root))

def test_latest_evidence_tiebreak_uses_append_order(tmp_path: Path) -> None:
    root = _root(tmp_path)
    (root / "artifacts/green.xml").write_text(GOOD_XML, encoding="utf-8")
    (root / "artifacts/red.xml").write_text(FAILING_XML, encoding="utf-8")
    _record(
        root,
        evidence=[
            {
                "kind": "runtime",
                "status": "green",
                "command": "maestro test flow.yaml",
                "artifact": "artifacts/green.xml",
                "verified_at": "2026-06-27T00:00:00Z",
                "verified_commit": SHA_A,
            },
            {
                "kind": "runtime",
                "status": "red",
                "command": "maestro test flow.yaml",
                "artifact": "artifacts/red.xml",
                "verified_at": "2026-06-27T00:00:00Z",
                "verified_commit": SHA_B,
            },
        ],
    )
    _issue(root, status="regressed", evidence_status="red")
    journey_os_generate.write(root)
    board = (root / ".planning/journeys/BOARD.md").read_text(encoding="utf-8")

    assert "red / runtime / 2026-06-27T00:00:00Z / bbbbbbbb" in board
    assert not any("latest evidence" in error for error in _errors(root))

def test_latest_evidence_timestamp_beats_append_order(tmp_path: Path) -> None:
    root = _root(tmp_path)
    (root / "artifacts/green.xml").write_text(GOOD_XML, encoding="utf-8")
    (root / "artifacts/red.xml").write_text(FAILING_XML, encoding="utf-8")
    _record(
        root,
        evidence=[
            {
                "kind": "runtime",
                "status": "green",
                "command": "maestro test flow.yaml",
                "artifact": "artifacts/green.xml",
                "verified_at": "2026-06-27T00:00:00Z",
                "verified_commit": SHA_A,
            },
            {
                "kind": "runtime",
                "status": "red",
                "command": "maestro test flow.yaml",
                "artifact": "artifacts/red.xml",
                "verified_at": "2026-06-26T00:00:00Z",
                "verified_commit": SHA_B,
            },
        ],
    )
    _issue(root, status="verified", evidence_status="green")
    journey_os_generate.write(root)
    board = (root / ".planning/journeys/BOARD.md").read_text(encoding="utf-8")

    assert "green / runtime / 2026-06-27T00:00:00Z / aaaaaaaa" in board
    assert not any("latest evidence" in error for error in _errors(root))
