#!/usr/bin/env python3
"""Validate Mint Journey OS records, scope, and generated views."""
from __future__ import annotations

import argparse, hashlib, json, re, subprocess, sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from xml.etree import ElementTree

try:
    from jsonschema import Draft202012Validator, exceptions as jsonschema_exceptions
except ImportError:  # pragma: no cover - exercised only on incomplete local envs.
    Draft202012Validator = None
    jsonschema_exceptions = None
REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))
from tools.checks import journey_os_generate
from tools.checks.route_registry_parity import extract_registry_keys
JOURNEYS = Path(".planning/journeys")
RECORDS = JOURNEYS / "records"
ISSUES = JOURNEYS / "issues"
SCHEMA = JOURNEYS / "journey.schema.json"
ISSUE_SCHEMA = JOURNEYS / "issue.schema.json"
ROUTES = Path("apps/mobile/lib/routes/route_metadata.dart")
OPENAPI = Path("tools/openapi/mint.openapi.canonical.json")
ROUTE_CONTRACTS = Path(".planning/phases/mint-2-0-first-experience-rente-capital/route_contracts")
ALLOW = {
    str(SCHEMA),
    str(ISSUE_SCHEMA),
    str(JOURNEYS / "README.md"),
    str(JOURNEYS / "PRIORITY_RUBRIC.md"),
    str(journey_os_generate.SUMMARY),
    str(journey_os_generate.BOARD),
    str(journey_os_generate.TODAY),
    str(journey_os_generate.CARDS),
    str(OPENAPI),
    ".claude/AGENT_BOOTSTRAP.md",
    ".github/pull_request_template.md",
    ".github/workflows/ai-workflow-guards.yml",
    ".github/workflows/journey-os-runtime-replay.yml",
    ".planning/ACTIVE_CONTEXT.md",
    ".planning/ACTIVE_CONTEXT.json",
    ".planning/decisions/2026-05-09-perimeter-b7-cascade-empty-state/STUB.md",
    ".planning/phases/wave-1c-coach-tool-dispatch-rca/.gitignore",
    ".planning/phases/wave-1c-coach-tool-dispatch-rca/captured_staging_payload_hydrated.json",
    ".planning/phases/wave-1c-coach-tool-dispatch-rca/probe-evidence/payload-2026-05-15-A2-2219.jsonl",
    ".planning/phases/wave-1c-coach-tool-dispatch-rca/probe-evidence/probe-2026-05-15-1958-payload.jsonl",
    ".planning/phases/wave-1c-coach-tool-dispatch-rca/probe-evidence/user_message_a1_2105.txt",
    ".planning/phases/mint-2-0-first-experience-rente-capital/VZ_ROUTE_ARCHITECTURE.md",
    ".planning/ROADMAP.md",
    ".planning/STATE.md",
    "AGENTS.md",
    "docs/MINT_AGENT_WORKFLOW.md",
    "lefthook.yml",
    "rules.md",
    # --- Remediation audit 2026-07 (dedicated phase, see .planning/phases/remediation-audit-2026-07) ---
    "tools/checks/journey_os_check.py",
    "tools/checks/no_false_privacy_attestation.py",
    "PRIVACY.md",
    "LEGAL_RELEASE_CHECK.md",
    "docs/DATA_ACQUISITION_STRATEGY.md",
    "apps/mobile/lib/services/financial_core/arbitrage_engine.dart",
    "apps/mobile/test/simulators/rente_vs_capital_test.dart",
    "apps/mobile/test/services/financial_core/arbitrage_engine_mixed_deflation_test.dart",
    "services/backend/app/services/pillar_3a_deep/retroactive_3a_service.py",
    "services/backend/tests/test_pillar_3a_retroactive.py",
    "services/backend/app/services/coach/tool_registry/anthropic_defer_loading_adapter.py",
    ".gitignore",
    ".planning/phases/remediation-audit-2026-07/CONTEXT.md",
    ".planning/phases/remediation-audit-2026-07/AUTHORIZED_FILES.md",
    ".planning/phases/remediation-audit-2026-07/BACKLOG-DEV-VERIFIED.html",
    # --- end remediation audit 2026-07 ---
    "apps/mobile/lib/app.dart",
    "apps/mobile/lib/models/screen_return.dart",
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
    "apps/mobile/lib/screens/auth/auth_redirect.dart",
    "apps/mobile/lib/screens/auth/login_screen.dart",
    "apps/mobile/lib/routes/coach_chat_entry_payload.dart",
    "apps/mobile/lib/routes/route_metadata.dart",
    "apps/mobile/lib/screens/auth/register_screen.dart",
    "apps/mobile/lib/screens/landing_screen.dart",
    "apps/mobile/lib/screens/profile/financial_summary_screen.dart",
    "apps/mobile/lib/screens/advisor/financial_report_screen_v2.dart",
    "apps/mobile/lib/screens/arbitrage/rente_vs_capital_screen.dart",
    "apps/mobile/lib/screens/aujourdhui/aujourdhui_screen.dart",
    "apps/mobile/lib/screens/budget/budget_setup_screen.dart",
    "apps/mobile/test/screens/budget_setup_screen_test.dart",
    "apps/mobile/lib/screens/debug/debug_mint2_account_claim_screen.dart",
    "apps/mobile/lib/screens/mon_argent/mon_argent_screen.dart",
    "apps/mobile/lib/screens/onboarding/data_block_enrichment_screen.dart",
    "apps/mobile/lib/screens/onboarding/mvp_wedge/onboarding_shell_screen.dart",
    "apps/mobile/lib/screens/coach/chat_as_verb_demo_screen.dart",
    "apps/mobile/lib/screens/coach/coach_chat_screen.dart",
    "apps/mobile/lib/screens/coach/retirement_dashboard_screen.dart",
    "apps/mobile/lib/screens/pillar_3a_deep/retroactive_3a_screen.dart",
    "apps/mobile/lib/screens/pillar_3a_deep/staggered_withdrawal_screen.dart",
    "apps/mobile/lib/services/apple_sign_in_service.dart",
    "apps/mobile/lib/services/api_service.dart",
    "apps/mobile/lib/services/arbitrage_summary_service.dart",
    "apps/mobile/lib/services/cap_engine.dart",
    "apps/mobile/lib/services/cap_sequence_engine.dart",
    "apps/mobile/lib/services/notification_deeplinks.dart",
    "apps/mobile/lib/services/notification_scheduler_service.dart",
    "apps/mobile/lib/services/notification_service.dart",
    "apps/mobile/lib/services/coach/_valid_routes_generated.dart",
    "apps/mobile/lib/services/coach/chat_tool_dispatcher.dart",
    "apps/mobile/lib/services/coach/coach_orchestrator.dart",
    "apps/mobile/lib/services/coach/intent_router.dart",
    "apps/mobile/lib/services/coach/local_fallback_service.dart",
    "apps/mobile/lib/services/navigation/mint_nav.dart",
    "apps/mobile/lib/services/navigation/route_planner.dart",
    "apps/mobile/lib/services/navigation/safe_pop.dart",
    "apps/mobile/lib/services/navigation/screen_registry.dart",
    "apps/mobile/lib/services/response_card_service.dart",
    "apps/mobile/lib/widgets/aujourdhui/cap_du_jour_banner.dart",
    "apps/mobile/lib/widgets/aujourdhui/commitments_and_checkins_card.dart",
    "apps/mobile/lib/widgets/coach/chat_drawer_host.dart",
    "apps/mobile/lib/widgets/coach/early_retirement_comparison.dart",
    "apps/mobile/lib/widgets/coach/explore_hub.dart",
    "apps/mobile/lib/widgets/coach/coach_helpers.dart",
    "apps/mobile/lib/widgets/coach/coach_message_bubble.dart",
    "apps/mobile/lib/widgets/coach/response_card_widget.dart",
    "apps/mobile/lib/widgets/coach/route_suggestion_card.dart",
    "apps/mobile/lib/widgets/coach/smart_shortcuts.dart",
    "apps/mobile/lib/widgets/coach/trajectory_card.dart",
    "apps/mobile/lib/widgets/coach/widget_renderer.dart",
    "apps/mobile/lib/widgets/onboarding/premier_eclairage_card.dart",
    "apps/mobile/lib/widgets/fullscreen_chart_wrapper.dart",
    "apps/mobile/lib/widgets/dashboard/couple_action_plan.dart",
    "apps/mobile/lib/widgets/dashboard/retirement_checklist_card.dart",
    "apps/mobile/lib/widgets/pulse/cap_card.dart",
    "apps/mobile/lib/widgets/pulse/comprendre_section.dart",
    "apps/mobile/test/integration/coach_tool_choreography_test.dart",
    "apps/mobile/test/journeys/anna_golden_path_test.dart",
    "apps/mobile/test/journeys/newjob_journey_test.dart",
    "apps/mobile/test/models/screen_return_test.dart",
    "apps/mobile/test/architecture/route_guard_snapshot.golden.txt",
    "apps/mobile/test/architecture/route_guard_snapshot_test.dart",
    "apps/mobile/test/architecture/navigation_push_doctrine_test.dart",
    "apps/mobile/test/navigation/account_lifecycle_public_entry_redirect_test.dart",
    "apps/mobile/test/navigation/goroute_health_test.dart",
    "apps/mobile/test/providers/auth_provider_test.dart",
    "apps/mobile/test/screens/login_apple_recreate_opt_in_test.dart",
    "apps/mobile/test/routes/route_metadata_test.dart",
    "apps/mobile/test/routes/coach_chat_entry_payload_test.dart",
    "apps/mobile/test/navigation/rvc_real_route_public_test.dart",
    "apps/mobile/test/screens/auth_screens_smoke_test.dart",
    "apps/mobile/test/screens/auth_magic_link_verify_handoff_test.dart",
    "apps/mobile/test/screens/login_redirect_resolver_test.dart",
    "apps/mobile/test/screens/register_account_entry_test.dart",
    "apps/mobile/test/screens/profile/financial_summary_screen_test.dart",
    "apps/mobile/test/widgets/onboarding/premier_eclairage_card_test.dart",
    "apps/mobile/test/screens/admin/routes_registry_screen_test.dart",
    "apps/mobile/test/screens/arbitrage/rente_vs_capital_receipt_gate_test.dart",
    "apps/mobile/test/screens/arbitrage/rente_vs_capital_route_state_anchor_test.dart",
    "apps/mobile/test/screens/data_block_enrichment_screen_test.dart",
    "apps/mobile/test/screens/debug/debug_mint2_account_claim_screen_test.dart",
    "apps/mobile/test/screens/coach/coach_chat_test.dart",
    "apps/mobile/test/screens/onboarding/mvp_wedge/mint2_first_experience_route_scope_test.dart",
    "apps/mobile/test/screens/onboarding/mvp_wedge/mint2_chat_navigation_guard_test.dart",
    "apps/mobile/test/screens/onboarding/mvp_wedge/mint2_first_experience_signal_axes_test.dart",
    "apps/mobile/test/screens/onboarding/mvp_wedge_storyboard_test.dart",
    "apps/mobile/test/screens/rente_vs_capital_prefill_test.dart",
    "apps/mobile/test/services/api_service_test.dart",
    "apps/mobile/test/services/check_in_notification_test.dart",
    "apps/mobile/test/services/coach/chat_tool_dispatcher_test.dart",
    "apps/mobile/test/services/coach/local_fallback_service_test.dart",
    "apps/mobile/test/services/coach_orchestrator_test.dart",
    "apps/mobile/test/services/navigation/mint_nav_test.dart",
    "apps/mobile/test/services/navigation/readiness_gate_test.dart",
    "apps/mobile/test/services/navigation/route_planner_test.dart",
    "apps/mobile/test/services/navigation/screen_registry_test.dart",
    "apps/mobile/test/services/notification_scheduler_service_test.dart",
    "apps/mobile/test/services/notification_service_test.dart",
    "apps/mobile/test/services/response_card_service_test.dart",
    "apps/mobile/test/services/screen_completion_tracker_test.dart",
    "apps/mobile/test/widgets/coach/coach_message_bubble_test.dart",
    "apps/mobile/test/widgets/coach/chat_drawer_summon_test.dart",
    "apps/mobile/test/widgets/coach/route_suggestion_card_test.dart",
    "apps/mobile/test/widgets/coach/widget_renderer_test.dart",
    "apps/mobile/test/widgets/fullscreen_chart_wrapper_test.dart",
    "apps/mobile/test/widgets/pulse/pulse_widgets_test.dart",
    "docs/ROUTE_POLICY.md",
    "services/backend/app/api/v1/endpoints/coach_chat.py",
    "services/backend/app/api/v1/endpoints/auth.py",
    "services/backend/app/schemas/auth.py",
    "services/backend/app/services/coach/compliance_guard.py",
    "services/backend/app/services/coach/structured_reasoning.py",
    "services/backend/app/services/coach/_route_intents_generated.py",
    "services/backend/app/services/llm/router.py",
    "services/backend/app/services/rag/guardrails.py",
    "services/backend/app/services/rag/hybrid_search_service.py",
    "services/backend/app/services/rag/llm_client.py",
    "services/backend/app/services/rag/orchestrator.py",
    "services/backend/app/services/rag/retriever.py",
    "services/backend/app/services/rag/vector_store.py",
    "services/backend/tests/fixtures/narrator_legacy_snapshots/_load.py",
    "services/backend/tests/fixtures/narrator_legacy_snapshots/snapshot_canton_vs_de_cash3.txt",
    "services/backend/tests/fixtures/narrator_legacy_snapshots/snapshot_couple_dissymetrique_fr_cash5.txt",
    "services/backend/tests/fixtures/narrator_legacy_snapshots/snapshot_default_ctx_fr_cash3.txt",
    "services/backend/tests/fixtures/narrator_legacy_snapshots/snapshot_minimal_ctx_en_cash1.txt",
    "services/backend/tests/fixtures/narrator_legacy_snapshots/snapshot_safe_mode_has_debt_fr_cash2.txt",
    "services/backend/tests/services/llm/test_wave1c_instrumentation_removed.py",
    "services/backend/tests/test_citation_gate/test_byte_identity_flag_off.py",
    "services/backend/tests/test_coach_chat_endpoint.py",
    "services/backend/tests/test_auth_apple.py",
    "services/backend/tests/test_compliance_guard.py",
    "services/backend/tests/test_coach_tools.py",
    "services/backend/tests/test_e2e_coach_pipeline.py",
    "services/backend/tests/test_guardrails_coverage.py",
    "services/backend/tests/test_main_coverage.py",
    "services/backend/tests/test_rag_orchestrator_empty_text_no_fallback.py",
    "services/backend/tests/test_structured_reasoning.py",
    "tools/contracts/regen_screen_registry_contract.py",
    "tools/simulator/mint2_quality_gate.sh",
    "tools/simulator/test_mint2_quality_gate.py",
    "tools/contracts/screen_registry.json",
    "tools/simulator/flows/maestro-perfect-set/flow_row24_privacy_control_runtime.yaml",
    "tools/simulator/flows/maestro-perfect-set/flow_jos001_account_lifecycle_seeded_delete.yaml",
    "tools/simulator/flows/maestro-perfect-set/flow_jos004_coach_advice_turn_runtime.yaml",
    "tools/simulator/flows/maestro-perfect-set/flow_landing_to_diagnostic_onboarding.yaml",
    "tools/simulator/flows/maestro-perfect-set/_fragment_cold_launch_to_aujourdhui.yaml",
    "tools/simulator/flows/maestro-perfect-set/flow_hardgate_expat_us.yaml",
    "tools/simulator/flows/maestro-perfect-set/flow_hero_marge_fiscale_3a.yaml",
    "tools/simulator/flows/maestro-perfect-set/flow_mint2_first_experience_rente_capital_entry.yaml",
    "tools/simulator/flows/maestro-perfect-set/flow_row22_profile_dossier_production_profile.yaml",
    "tools/simulator/flows/regression/bug__P004__overlay_populated_on_open.yaml",
    "tools/simulator/flows/regression/bug__S005__landing_anonymous_cta_to_home.yaml",
    "tools/simulator/flows/salvage01_retraite_onboarding_coach.yaml",
    "tools/simulator/journey_os_runtime_replay.sh",
    "tools/claude_review.py",
    "tools/claude_review.sh",
    "tools/checks/active_context_guard.py",
    "tools/checks/journey_os_check.py",
    "tools/checks/journey_os_generate.py",
    "tools/checks/maestro_locator_audit.py",
    "tools/checks/mermaid_render_guard.py",
    "tools/checks/mint2_navigation_spine_guard.py",
    "tools/checks/mint2_vz_route_contract_guard.py",
    "tools/checks/mint_rules_guard.py",
    "tools/checks/screen_registry_parity-KNOWN-MISSES.md",
    "tools/checks/screen_registry_parity.py",
    "tools/checks/workflow_contract_guard.py",
    "tests/tools/test_mint_routes.py",
    "tools/checks/tests/test_active_context_guard.py",
    "tools/checks/tests/test_claude_review.py",
    "tools/checks/tests/test_journey_os_check.py",
    "tools/checks/tests/test_journey_os_runtime_replay.py",
    "tools/checks/tests/test_maestro_locator_audit.py",
    "tools/checks/tests/test_mermaid_render_guard.py",
    "tools/checks/tests/test_mint2_navigation_spine_guard.py",
    "tools/checks/tests/test_mint2_vz_route_contract_guard.py",
    "tools/checks/tests/test_mint_rules_guard.py",
    "tools/checks/tests/test_workflow_contract_guard.py",
}
DELETION_ALLOW = {
    "apps/mobile/test/services/coach/chat_drawer_summon_test.dart",
}
IGNORED_GENERATED_PREFIXES = (
    "services/backend/mint_backend.egg-info/",
)
TEAMS = {"mint-lead", "mint-quality-gate", "mint-mobile", "mint-backend", "mint-swiss-brain"}
STATUS = {"draft", "partial", "live_proven", "blocked", "deferred", "out_of_beta"}
ISSUE_STATUS = {"found", "triaged", "assigned", "fixing", "proof_needed", "verified", "merged", "regressed", "blocked"}
SEVERITY = {"P0", "P1", "P2", "P3"}
TIERS = {"T0", "T1", "T2", "T3"}
KINDS = {"unit", "widget", "static_guard", "runtime", "manual", "external"}
ESTATUS = {"green", "red", "missing", "baselined"}
CONTRACT_FIELDS = {"personas", "entry_state", "account_state", "success_state", "negative_assertions", "source_spec_refs", "proof_owner", "fix_owner", "runtime_replay"}
TOP = {"schema_version", "id", "title", "tier", "status", "human_promise", "accountable_team", "route_paths", "surfaces", "external_apis", "issues", "priority", "evidence"} | CONTRACT_FIELDS
REQ = TOP
ARRAYS = {"route_paths", "surfaces", "external_apis", "issues", "personas", "negative_assertions", "source_spec_refs"}
NON_EMPTY_ARRAYS = {"personas", "negative_assertions", "source_spec_refs"}
ITOP = {"schema_version", "id", "title", "journey_id", "status", "owner", "severity", "evidence_status", "next_action", "source"}
IREQ = ITOP
EKEYS = {"kind", "status", "command", "artifact", "reason", "debt_ref", "verified_at", "verified_commit"}
PRIORITY_POSITIVE = {"trust_blast_radius", "release_blocker_weight", "user_frequency", "evidence_gap", "route_centrality", "compliance_risk", "learning_value"}
PRIORITY_KEYS = PRIORITY_POSITIVE | {"proof_cost", "rationale"}
REPLAY_SETS = {"core", "top", "authenticated", "account_lifecycle"}
REPLAY_KEYS = {"flow", "sets", "device", "build_defines", "requires_auth", "order"}
TEXT_FAILURE_MARKERS = ("[Failed]", "Flow Failed", "FAILED", "Assertion is false", "EXIT — maestro returned 1")
TEXT_SUCCESS_MARKERS = ("[Passed]", "Flow Passed")
FULL_SHA_RE = re.compile(r"^[0-9a-f]{40}$")
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
EMPTY_SHA256 = hashlib.sha256(b"").hexdigest()
EVIDENCE_SECRET_PATTERNS = (
    (re.compile(r"MINT_E2E_PASSWORD\s*="), "MINT_E2E_PASSWORD"),
    (re.compile(r"Authorization:\s*Bearer\s+", re.IGNORECASE), "Authorization bearer token"),
    (re.compile(r"\bBearer\s+[A-Za-z0-9._~+/\-]{20,}"), "bearer token"),
    (re.compile(r"[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}"), "raw email address"),
)

def _is_ignored_generated(path: str) -> bool:
    return any(path.startswith(prefix) for prefix in IGNORED_GENERATED_PREFIXES)

def _changed(root: Path, base: str) -> tuple[list[str], list[str]]:
    proc = subprocess.run(["git", "diff", "--name-only", f"{base}...HEAD"], cwd=root, text=True, capture_output=True)
    if proc.returncode:
        return [], [f"baseline {base} unavailable: {proc.stderr.strip() or proc.stdout.strip()}"]
    outputs = [proc.stdout]
    for args, label in (
        (["git", "diff", "--name-only"], "working tree changes"),
        (["git", "diff", "--cached", "--name-only"], "staged changes"),
        (["git", "ls-files", "--others", "--exclude-standard"], "untracked files"),
    ):
        extra = subprocess.run(args, cwd=root, text=True, capture_output=True)
        if extra.returncode:
            return [], [f"unable to resolve {label}: {extra.stderr.strip() or extra.stdout.strip()}"]
        outputs.append(extra.stdout)
    return sorted(
        {
            line
            for output in outputs
            for line in output.splitlines()
            if line and not _is_ignored_generated(line)
        }
    ), []

def _scope_errors(root: Path, changed: list[str]) -> list[str]:
    errors: list[str] = []
    for path in changed:
        if path in DELETION_ALLOW and not (root / path).exists():
            continue
        allowed_record = path.startswith(str(RECORDS) + "/") and path.endswith(".json") and "/" not in path[len(str(RECORDS)) + 1 :]
        allowed_issue = path.startswith(str(ISSUES) + "/") and path.endswith(".json") and "/" not in path[len(str(ISSUES)) + 1 :]
        allowed_diagram = path.startswith(str(journey_os_generate.DIAGRAMS) + "/") and path.endswith(".mmd") and "/" not in path[len(str(journey_os_generate.DIAGRAMS)) + 1 :]
        allowed_route_contract = path.startswith(str(ROUTE_CONTRACTS) + "/") and path.endswith(".json") and "/" not in path[len(str(ROUTE_CONTRACTS)) + 1 :]
        evidence_path = Path(path)
        runtime_replay_evidence = path.startswith(str(JOURNEYS / "evidence" / "runtime_replay") + "/")
        allowed_evidence = path.startswith(str(JOURNEYS / "evidence") + "/") and ".." not in evidence_path.parts and (
            (
                runtime_replay_evidence
                and evidence_path.name in {"manifest.json", "result.xml"}
                and evidence_path.suffix in {".json", ".xml"}
            )
            or (
                not runtime_replay_evidence
                and evidence_path.suffix in {".md", ".txt", ".xml", ".json"}
            )
        )
        if not (path in ALLOW or allowed_record or allowed_issue or allowed_diagram or allowed_evidence or allowed_route_contract):
            errors.append(f"changed file outside Journey OS whitelist: {path}")
        suffix = Path(path).suffix
        if path.startswith(str(JOURNEYS) + "/") and not allowed_evidence and (suffix in {".svg", ".html"} or (suffix == ".md" and path not in ALLOW)):
            errors.append(f"unsupported Journey OS generated view: {path}")
    readme = root / JOURNEYS / "README.md"
    if readme.exists() and "```mermaid" in readme.read_text(encoding="utf-8", errors="ignore").lower():
        errors.append("Mermaid fenced blocks are forbidden in .planning/journeys/README.md")
    return errors

def _evidence_secret_errors(root: Path, changed: list[str]) -> list[str]:
    errors: list[str] = []
    evidence_prefix = str(JOURNEYS / "evidence") + "/"
    for rel in changed:
        if not rel.startswith(evidence_prefix):
            continue
        suffix = Path(rel).suffix
        if suffix not in {".json", ".md", ".txt", ".xml"}:
            continue
        path = root / rel
        if not path.exists() or path.stat().st_size > 2_000_000:
            continue
        text = path.read_text(encoding="utf-8", errors="ignore")
        for pattern, label in EVIDENCE_SECRET_PATTERNS:
            if pattern.search(text):
                errors.append(f"{rel} contains forbidden evidence secret/PII marker: {label}")
    return errors

def _generated_errors(root: Path) -> list[str]:
    errors: list[str] = []
    expected = journey_os_generate.expected(root)
    for rel, content in expected.items():
        path = root / rel
        if not path.exists():
            errors.append(f"missing generated Journey OS view: {rel}")
        elif path.read_text(encoding="utf-8") != content:
            errors.append(f"stale generated Journey OS view: {rel}")
    expected_paths = {str(path) for path in expected}
    for path in (root / journey_os_generate.DIAGRAMS).glob("*.mmd"):
        rel = str(path.relative_to(root))
        if rel not in expected_paths:
            errors.append(f"orphan generated Journey OS diagram: {rel}")
    return errors

def _schema_validation_errors(root: Path, records: list[tuple[Path, dict[str, Any]]], issues: list[tuple[Path, dict[str, Any]]]) -> list[str]:
    errors: list[str] = []
    if Draft202012Validator is None or jsonschema_exceptions is None:
        return ["python package jsonschema is required for Journey OS schema validation"]
    schema_specs = (
        (SCHEMA, "Journey OS record", records),
        (ISSUE_SCHEMA, "Journey OS issue", issues),
    )
    for rel_schema, label, items in schema_specs:
        path = root / rel_schema
        try:
            schema = json.loads(path.read_text(encoding="utf-8"))
            Draft202012Validator.check_schema(schema)
        except (OSError, json.JSONDecodeError, jsonschema_exceptions.SchemaError) as exc:
            errors.append(f"{rel_schema} is not an executable JSON schema: {exc}")
            continue
        required = schema.get("required")
        if not isinstance(required, list) or len(required) < 5:
            errors.append(f"{rel_schema} must define a non-trivial required field list")
            continue
        validator = Draft202012Validator(schema)
        for item_path, data in items:
            for error in sorted(validator.iter_errors(data), key=lambda err: list(err.path)):
                errors.append(f"{item_path.relative_to(root)} schema violation ({label}): {error.message}")
    return errors

def _load_records(root: Path) -> tuple[list[tuple[Path, dict[str, Any]]], list[str]]:
    errors: list[str] = []
    if not (root / SCHEMA).exists():
        errors.append(f"missing {SCHEMA}")
    records: list[tuple[Path, dict[str, Any]]] = []
    for path in sorted((root / RECORDS).glob("*.json")):
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            errors.append(f"{path.relative_to(root)} invalid JSON: {exc}")
            continue
        if not isinstance(data, dict):
            errors.append(f"{path.relative_to(root)} root must be an object")
            continue
        records.append((path, data))
    return records, errors

def _load_issues(root: Path) -> tuple[list[tuple[Path, dict[str, Any]]], list[str]]:
    errors: list[str] = []
    if not (root / ISSUE_SCHEMA).exists():
        errors.append(f"missing {ISSUE_SCHEMA}")
    issues: list[tuple[Path, dict[str, Any]]] = []
    for path in sorted((root / ISSUES).glob("*.json")):
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            errors.append(f"{path.relative_to(root)} invalid JSON: {exc}")
            continue
        if not isinstance(data, dict):
            errors.append(f"{path.relative_to(root)} root must be an object")
            continue
        issues.append((path, data))
    return issues, errors

def _openapi_operations(root: Path) -> tuple[set[str], list[str]]:
    path = root / OPENAPI
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except OSError as exc:
        return set(), [f"unable to read canonical OpenAPI: {exc}"]
    except json.JSONDecodeError as exc:
        return set(), [f"{OPENAPI} invalid JSON: {exc}"]
    paths = data.get("paths")
    if not isinstance(paths, dict):
        return set(), [f"{OPENAPI} must expose a paths object"]
    operations: set[str] = set()
    for route, methods in paths.items():
        if not isinstance(route, str) or not isinstance(methods, dict):
            continue
        for method in ("get", "post", "put", "patch", "delete", "options", "head"):
            if method in methods:
                operations.add(f"{method.upper()} {route}")
    if not operations:
        return set(), [f"{OPENAPI} contains no executable operations"]
    return operations, []

def _artifact_ok(root: Path, value: Any) -> bool:
    if not isinstance(value, str) or not value or value.startswith("/tmp"):
        return False
    path = Path(value)
    if path.is_absolute() or ".." in path.parts or "tmp" in path.parts:
        return False
    return (root / path).exists()

def _junit_counts(path: Path) -> tuple[int, int, int, int, int]:
    root = ElementTree.parse(path).getroot()
    declared_tests = sum(int(node.attrib.get("tests", "0") or 0) for node in root.iter() if node.tag.endswith("testsuite"))
    testcase_nodes = sum(1 for node in root.iter() if node.tag.endswith("testcase"))
    tests = max(declared_tests, testcase_nodes)
    failures = sum(int(node.attrib.get("failures", "0") or 0) for node in root.iter() if node.tag.endswith("testsuite"))
    errors = sum(int(node.attrib.get("errors", "0") or 0) for node in root.iter() if node.tag.endswith("testsuite"))
    failure_nodes = sum(1 for node in root.iter() if node.tag.endswith("failure") or node.tag.endswith("error"))
    declared_skipped = sum(int(node.attrib.get("skipped", "0") or 0) for node in root.iter() if node.tag.endswith("testsuite"))
    skipped_nodes = sum(1 for node in root.iter() if node.tag.endswith("skipped"))
    skipped = max(declared_skipped, skipped_nodes)
    return tests, failures, errors, failure_nodes, skipped

def _valid_verified_at(value: Any) -> bool:
    if not isinstance(value, str) or not value.endswith("Z"):
        return False
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return False
    now = datetime.now(timezone.utc)
    return parsed.tzinfo == timezone.utc and parsed <= now

def _valid_verified_commit(root: Path, value: Any) -> bool:
    if not isinstance(value, str) or not FULL_SHA_RE.fullmatch(value):
        return False
    inside = subprocess.run(
        ["git", "rev-parse", "--is-inside-work-tree"],
        cwd=root,
        text=True,
        capture_output=True,
    )
    if inside.returncode or inside.stdout.strip() != "true":
        return True
    commit_exists = subprocess.run(
        ["git", "cat-file", "-e", f"{value}^{{commit}}"],
        cwd=root,
        text=True,
        capture_output=True,
    )
    if commit_exists.returncode:
        return False
    reachable_from_head = subprocess.run(
        ["git", "merge-base", "--is-ancestor", value, "HEAD"],
        cwd=root,
        text=True,
        capture_output=True,
    )
    return reachable_from_head.returncode == 0

def _blob_sha256_at_commit(root: Path, commit: Any, rel_path: Any) -> str | None:
    if not isinstance(commit, str) or not FULL_SHA_RE.fullmatch(commit):
        return None
    if not isinstance(rel_path, str) or not rel_path or Path(rel_path).is_absolute() or ".." in Path(rel_path).parts:
        return None
    inside = subprocess.run(
        ["git", "rev-parse", "--is-inside-work-tree"],
        cwd=root,
        text=True,
        capture_output=True,
    )
    if inside.returncode or inside.stdout.strip() != "true":
        return None
    proc = subprocess.run(
        ["git", "show", f"{commit}:{rel_path}"],
        cwd=root,
        capture_output=True,
    )
    if proc.returncode:
        return None
    return hashlib.sha256(proc.stdout).hexdigest()

def _artifact_status_errors(root: Path, label: str, item: dict[str, Any]) -> list[str]:
    status = item.get("status")
    artifact = item.get("artifact")
    kind = item.get("kind")
    if status not in {"green", "red", "baselined"} or not _artifact_ok(root, artifact):
        return []
    artifact_path = root / str(artifact)
    errors: list[str] = []
    if kind == "runtime" and artifact_path.suffix not in {".xml", ".txt"}:
        errors.append(f"{label} runtime evidence must use a parseable .xml or .txt result artifact")
    if kind == "runtime" and artifact_path.suffix == ".txt" and not str(artifact).startswith(str(JOURNEYS / "evidence") + "/"):
        errors.append(f"{label} runtime text evidence must live under .planning/journeys/evidence/")
    if artifact_path.suffix == ".xml":
        try:
            tests, failures, junit_errors, failure_nodes, skipped = _junit_counts(artifact_path)
        except (OSError, ElementTree.ParseError, ValueError) as exc:
            return [f"{label} has unreadable JUnit artifact: {exc}"]
        failed = failures > 0 or junit_errors > 0 or failure_nodes > 0
        executed = max(tests - skipped, 0)
        if kind == "runtime" and executed == 0:
            errors.append(f"{label} runtime JUnit artifact reports zero executed tests")
        if status == "green" and failed:
            errors.append(f"{label} is green but JUnit artifact reports failures/errors")
        if status == "red" and not failed:
            errors.append(f"{label} is red but JUnit artifact reports no failures/errors")
    elif artifact_path.suffix == ".txt" and str(artifact).startswith(str(JOURNEYS / "evidence") + "/"):
        text = artifact_path.read_text(encoding="utf-8", errors="ignore")
        has_failure = any(marker in text for marker in TEXT_FAILURE_MARKERS)
        has_success = any(marker in text for marker in TEXT_SUCCESS_MARKERS)
        if status == "green" and has_failure:
            errors.append(f"{label} is green but text artifact contains failure markers")
        if status == "red" and not has_failure:
            errors.append(f"{label} is red but text artifact has no failure marker")
        if status == "green" and not has_success:
            errors.append(f"{label} green text artifact needs an explicit success marker")
    errors += _runtime_replay_manifest_errors(root, label, item)
    return errors

def _runtime_replay_manifest_errors(root: Path, label: str, item: dict[str, Any]) -> list[str]:
    artifact = item.get("artifact")
    if not isinstance(artifact, str):
        return []
    artifact_path = Path(artifact)
    parts = artifact_path.parts
    prefix = (".planning", "journeys", "evidence", "runtime_replay")
    if len(parts) < len(prefix) + 2 or parts[: len(prefix)] != prefix:
        return []
    manifest_rel = Path(*parts[: len(prefix) + 1]) / "manifest.json"
    manifest_path = root / manifest_rel
    if not manifest_path.exists():
        return [f"{label} runtime_replay evidence requires sibling manifest: {manifest_rel}"]
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"{label} runtime_replay manifest is unreadable: {exc}"]
    errors: list[str] = []
    verified_commit = item.get("verified_commit")
    if manifest.get("git_head") != verified_commit:
        errors.append(f"{label} runtime_replay manifest git_head must match verified_commit")
    if manifest.get("git_dirty") is not False:
        errors.append(f"{label} runtime_replay manifest must prove git_dirty=false")
    if manifest.get("git_status_porcelain") != "":
        errors.append(f"{label} runtime_replay manifest must have empty git_status_porcelain")
    for key in ("git_diff_sha256", "git_status_sha256", "replay_script_sha256"):
        if not isinstance(manifest.get(key), str) or not SHA256_RE.fullmatch(manifest[key]):
            errors.append(f"{label} runtime_replay manifest missing {key}")
    if manifest.get("git_dirty") is False:
        if manifest.get("git_status_sha256") != EMPTY_SHA256:
            errors.append(f"{label} runtime_replay clean manifest must have empty git_status_sha256")
        if manifest.get("git_diff_sha256") != EMPTY_SHA256:
            errors.append(f"{label} runtime_replay clean manifest must have empty git_diff_sha256")
    script_hash = _blob_sha256_at_commit(root, verified_commit, "tools/simulator/journey_os_runtime_replay.sh")
    if script_hash is not None and manifest.get("replay_script_sha256") != script_hash:
        errors.append(f"{label} runtime_replay manifest replay_script_sha256 does not match verified_commit")
    journeys = manifest.get("journeys")
    if not isinstance(journeys, list):
        errors.append(f"{label} runtime_replay manifest journeys must be an array")
        return errors
    journey_name = parts[len(prefix) + 1] if len(parts) > len(prefix) + 1 else ""
    matching = [entry for entry in journeys if isinstance(entry, dict) and entry.get("journey") == journey_name]
    if not matching:
        errors.append(f"{label} runtime_replay manifest lacks journey result for {journey_name}")
        return errors
    entry = matching[0]
    if not isinstance(entry.get("flow_sha256"), str) or not SHA256_RE.fullmatch(entry["flow_sha256"]):
        errors.append(f"{label} runtime_replay manifest journey missing flow_sha256")
    flow_hash = _blob_sha256_at_commit(root, verified_commit, entry.get("flow"))
    if flow_hash is not None and entry.get("flow_sha256") != flow_hash:
        errors.append(f"{label} runtime_replay manifest flow_sha256 does not match verified_commit")
    result = entry.get("result")
    if not isinstance(result, dict):
        errors.append(f"{label} runtime_replay manifest journey missing result")
    elif item.get("status") in {"green", "red"}:
        result_status = result.get("status")
        if item.get("status") == "green" and result_status != "passed":
            errors.append(f"{label} green runtime_replay evidence requires passed manifest result")
        if item.get("status") == "red" and result_status != "failed":
            errors.append(f"{label} red runtime_replay evidence requires failed manifest result")
    return errors

def _latest_evidence(data: dict[str, Any]) -> dict[str, Any] | None:
    latest = journey_os_generate._latest_evidence(data)
    return latest or None

def _latest_runtime_evidence(data: dict[str, Any]) -> dict[str, Any] | None:
    items = [
        item
        for item in data.get("evidence", [])
        if isinstance(item, dict) and item.get("kind") == "runtime"
    ]
    if not items:
        return None
    return journey_os_generate._latest_evidence({"evidence": items}) or None

def _priority_score(priority: dict[str, Any]) -> int:
    return sum(int(priority[key]) for key in PRIORITY_POSITIVE) - int(priority["proof_cost"])

def _priority_errors(rel: Path, data: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    priority = data.get("priority")
    if not isinstance(priority, dict):
        return [f"{rel} priority must be an object"]
    extra = set(priority) - PRIORITY_KEYS
    if extra:
        errors.append(f"{rel} priority unknown field(s): {', '.join(sorted(extra))}")
    for key in sorted(PRIORITY_KEYS):
        if key not in priority:
            errors.append(f"{rel} priority missing field: {key}")
    for key in sorted(PRIORITY_POSITIVE | {"proof_cost"}):
        value = priority.get(key)
        if isinstance(value, bool) or not isinstance(value, int) or value < 0 or value > 5:
            errors.append(f"{rel} priority.{key} must be an integer from 0 to 5")
    rationale = priority.get("rationale")
    if not isinstance(rationale, str) or len(rationale.strip()) < 20:
        errors.append(f"{rel} priority.rationale must explain the ranking")
    if data.get("tier") == "T0" and not errors and _priority_score(priority) < 15:
        errors.append(f"{rel} T0 priority score must be at least 15")
    return errors

def _runtime_replay_errors(root: Path, rel: Path, data: dict[str, Any]) -> list[str]:
    replay = data.get("runtime_replay")
    if not isinstance(replay, dict):
        return [f"{rel} runtime_replay must be an object"]
    errors: list[str] = []
    extra = set(replay) - REPLAY_KEYS
    if extra:
        errors.append(f"{rel} runtime_replay unknown field(s): {', '.join(sorted(extra))}")
    for key in sorted(REPLAY_KEYS):
        if key not in replay:
            errors.append(f"{rel} runtime_replay missing field: {key}")

    flow = replay.get("flow")
    if not isinstance(flow, str) or not flow.strip():
        errors.append(f"{rel} runtime_replay.flow must be a non-empty string")
    else:
        flow_path = Path(flow)
        if flow_path.is_absolute() or ".." in flow_path.parts:
            errors.append(f"{rel} runtime_replay.flow must be repo-relative")
        elif flow_path.suffix != ".yaml":
            errors.append(f"{rel} runtime_replay.flow must point to a Maestro .yaml flow")
        elif not str(flow).startswith("tools/simulator/flows/"):
            errors.append(f"{rel} runtime_replay.flow must live under tools/simulator/flows/")
        elif not (root / flow_path).exists():
            errors.append(f"{rel} runtime_replay.flow does not exist: {flow}")

    sets = replay.get("sets")
    if not isinstance(sets, list) or not sets or any(not isinstance(item, str) for item in sets):
        errors.append(f"{rel} runtime_replay.sets must be a non-empty string array")
    else:
        unknown_sets = sorted(set(sets) - REPLAY_SETS)
        if unknown_sets:
            errors.append(f"{rel} runtime_replay.sets unknown value(s): {', '.join(unknown_sets)}")

    if not isinstance(replay.get("device"), str) or not str(replay.get("device")).strip():
        errors.append(f"{rel} runtime_replay.device must be a non-empty string")
    defines = replay.get("build_defines")
    if not isinstance(defines, list) or any(not isinstance(item, str) or not item.strip() or "=" not in item for item in defines):
        errors.append(f"{rel} runtime_replay.build_defines must be KEY=VALUE strings")
    if not isinstance(replay.get("requires_auth"), bool):
        errors.append(f"{rel} runtime_replay.requires_auth must be a boolean")
    if isinstance(replay.get("requires_auth"), bool) and replay["requires_auth"]:
        allowed_auth_sets = set(replay.get("sets") or [])
        if not (allowed_auth_sets & {"authenticated", "account_lifecycle"}):
            errors.append(f"{rel} authenticated runtime_replay must be in authenticated or account_lifecycle set")
    order = replay.get("order")
    if isinstance(order, bool) or not isinstance(order, int) or order < 0 or order > 100:
        errors.append(f"{rel} runtime_replay.order must be an integer from 0 to 100")
    return errors

def _evidence_text(data: dict[str, Any]) -> str:
    fragments: list[str] = []
    for item in data.get("evidence", []) if isinstance(data.get("evidence"), list) else []:
        if not isinstance(item, dict):
            continue
        for key in ("command", "reason"):
            value = item.get(key)
            if isinstance(value, str):
                fragments.append(value)
    return "\n".join(fragments)

def _record_errors(root: Path, path: Path, data: dict[str, Any], routes: set[str], openapi_ops: set[str]) -> list[str]:
    rel = path.relative_to(root)
    errors: list[str] = []
    unknown = set(data) - TOP
    if unknown:
        errors.append(f"{rel} unknown field(s): {', '.join(sorted(unknown))}")
    for key in sorted(REQ):
        if key not in data:
            errors.append(f"{rel} missing required field: {key}")
    for key in ("id", "title", "human_promise", "entry_state", "account_state", "success_state"):
        if not isinstance(data.get(key), str) or not str(data.get(key)).strip():
            errors.append(f"{rel} {key} must be a non-empty string")
    if data.get("schema_version") != 1:
        errors.append(f"{rel} schema_version must be 1")
    if data.get("tier") not in TIERS:
        errors.append(f"{rel} tier has unknown enum: {data.get('tier')}")
    if data.get("status") not in STATUS:
        errors.append(f"{rel} status has unknown enum: {data.get('status')}")
    if data.get("accountable_team") not in TEAMS:
        errors.append(f"{rel} accountable_team must be a Mint roster entry")
    for key in ("proof_owner", "fix_owner"):
        if data.get(key) not in TEAMS:
            errors.append(f"{rel} {key} must be a Mint roster entry")
    if path.stem != data.get("id"):
        errors.append(f"{rel} filename stem must match id")
    for key in ARRAYS:
        value = data.get(key)
        if not isinstance(value, list) or any(not isinstance(item, str) for item in value):
            errors.append(f"{rel} {key} must be an array of strings")
        if key in NON_EMPTY_ARRAYS and (not isinstance(value, list) or not value or any(not str(item).strip() for item in value if isinstance(item, str))):
            errors.append(f"{rel} {key} must be a non-empty array of non-empty strings")
    errors += _priority_errors(rel, data)
    errors += _runtime_replay_errors(root, rel, data)
    for route in data.get("route_paths", []) if isinstance(data.get("route_paths"), list) else []:
        if not isinstance(route, str) or route not in routes:
            errors.append(f"{rel} route_path is not a registered route: {route}")
    for api in data.get("external_apis", []) if isinstance(data.get("external_apis"), list) else []:
        if not isinstance(api, str):
            continue
        if api and api not in openapi_ops:
            errors.append(f"{rel} external_api is not in canonical OpenAPI: {api}")
    for ref in data.get("source_spec_refs", []) if isinstance(data.get("source_spec_refs"), list) else []:
        ref_path = Path(ref)
        if ref_path.is_absolute() or ".." in ref_path.parts or not (root / ref_path).exists():
            errors.append(f"{rel} source_spec_ref must be an existing repo-relative path: {ref}")
    evidence = data.get("evidence")
    if not isinstance(evidence, list) or not evidence:
        errors.append(f"{rel} evidence must be a non-empty array")
        return errors
    for index, item in enumerate(evidence):
        label = f"{rel} evidence[{index}]"
        if not isinstance(item, dict):
            errors.append(f"{label} must be an object")
            continue
        extra = set(item) - EKEYS
        if extra:
            errors.append(f"{label} unknown field(s): {', '.join(sorted(extra))}")
        for key in ("kind", "status", "command", "artifact"):
            if key not in item:
                errors.append(f"{label} missing required field: {key}")
        kind, status = item.get("kind"), item.get("status")
        if kind not in KINDS:
            errors.append(f"{label} kind has unknown enum: {kind}")
        if status not in ESTATUS:
            errors.append(f"{label} status has unknown enum: {status}")
        has_artifact = _artifact_ok(root, item.get("artifact"))
        if status in {"green", "red", "baselined"}:
            if not isinstance(item.get("command"), str) or not item["command"].strip() or not has_artifact:
                errors.append(f"{label} {status} evidence needs command and durable repo-relative artifact")
        if kind == "runtime" and status in {"green", "red", "baselined"} and has_artifact:
            if not _valid_verified_at(item.get("verified_at")):
                errors.append(f"{label} durable runtime evidence requires verified_at as UTC ISO timestamp")
            if not _valid_verified_commit(root, item.get("verified_commit")):
                errors.append(
                    f"{label} durable runtime evidence requires verified_commit as a full SHA that exists in git history and current HEAD history"
                )
        if status == "baselined" and not item.get("debt_ref"):
            errors.append(f"{label} baselined evidence requires debt_ref")
        if status == "missing" and item.get("artifact") is not None:
            errors.append(f"{label} missing evidence cannot have an artifact")
        errors += _artifact_status_errors(root, label, item)
    if data.get("status") == "live_proven":
        latest_runtime = _latest_runtime_evidence(data)
        if not latest_runtime:
            errors.append(f"{rel} live_proven requires runtime evidence")
        elif (
            latest_runtime.get("status") != "green"
            or not _artifact_ok(root, latest_runtime.get("artifact"))
            or not latest_runtime.get("verified_at")
            or not latest_runtime.get("verified_commit")
        ):
            errors.append(f"{rel} live_proven requires latest runtime evidence to be green with verified_at and verified_commit")
        evidence_text = _evidence_text(data)
        for api in data.get("external_apis", []) if isinstance(data.get("external_apis"), list) else []:
            if isinstance(api, str) and api and api not in evidence_text:
                errors.append(f"{rel} live_proven external_api lacks exact evidence text: {api}")
    return errors

def _issue_errors(root: Path, path: Path, data: dict[str, Any], journey_ids: set[str]) -> list[str]:
    rel = path.relative_to(root)
    errors: list[str] = []
    unknown = set(data) - ITOP
    if unknown:
        errors.append(f"{rel} unknown field(s): {', '.join(sorted(unknown))}")
    for key in sorted(IREQ):
        if key not in data:
            errors.append(f"{rel} missing required field: {key}")
    for key in ("id", "title", "next_action", "source"):
        if not isinstance(data.get(key), str) or not str(data.get(key)).strip():
            errors.append(f"{rel} {key} must be a non-empty string")
    iid = data.get("id")
    if not (isinstance(iid, str) and iid.startswith("JOS-") and len(iid) == 7 and iid[4:].isdigit()):
        errors.append(f"{rel} id must match JOS-###")
    if isinstance(data.get("next_action"), str) and len(str(data["next_action"]).strip()) < 20:
        errors.append(f"{rel} next_action must explain the next step")
    if data.get("schema_version") != 1:
        errors.append(f"{rel} schema_version must be 1")
    if path.stem != data.get("id"):
        errors.append(f"{rel} filename stem must match id")
    if data.get("journey_id") not in journey_ids:
        errors.append(f"{rel} journey_id must reference a Journey OS record")
    if data.get("status") not in ISSUE_STATUS:
        errors.append(f"{rel} status has unknown enum: {data.get('status')}")
    if data.get("owner") not in TEAMS:
        errors.append(f"{rel} owner must be a Mint roster entry")
    if data.get("severity") not in SEVERITY:
        errors.append(f"{rel} severity has unknown enum: {data.get('severity')}")
    if data.get("evidence_status") not in ESTATUS:
        errors.append(f"{rel} evidence_status has unknown enum: {data.get('evidence_status')}")
    return errors

def _issue_progress_errors(root: Path, records: list[tuple[Path, dict[str, Any]]], issues: list[tuple[Path, dict[str, Any]]]) -> list[str]:
    has_green_evidence: set[str] = set()
    latest_by_journey: dict[str, dict[str, Any]] = {}
    for _path, data in records:
        if not isinstance(data.get("id"), str):
            continue
        evidence = data.get("evidence")
        if not isinstance(evidence, list):
            continue
        if any(isinstance(item, dict) and item.get("status") == "green" and _artifact_ok(root, item.get("artifact")) for item in evidence):
            has_green_evidence.add(str(data["id"]))
        latest = _latest_evidence(data)
        if latest:
            latest_by_journey[str(data["id"])] = latest
    errors: list[str] = []
    for path, data in issues:
        has_green = data.get("journey_id") in has_green_evidence
        rel = path.relative_to(root)
        if data.get("evidence_status") == "green" and not has_green:
            errors.append(f"{rel} cannot be green without durable green evidence on referenced journey")
        latest = latest_by_journey.get(str(data.get("journey_id")))
        if latest and data.get("evidence_status") != latest.get("status"):
            errors.append(f"{rel} evidence_status must match latest evidence status {latest.get('status')}")
        if data.get("status") == "verified" and data.get("evidence_status") != "green":
            errors.append(f"{rel} verified issues must have green evidence_status")
        if not has_green:
            continue
        if data.get("status") in {"found", "triaged"}:
            errors.append(f"{rel} cannot stay {data.get('status')} after referenced journey has durable green evidence")
        if data.get("evidence_status") == "missing":
            errors.append(f"{rel} cannot stay missing after referenced journey has durable green evidence")
    return errors

def _runtime_replay_coverage_errors(records: list[tuple[Path, dict[str, Any]]], issues: list[tuple[Path, dict[str, Any]]]) -> list[str]:
    by_id = {str(data.get("id")): data for _path, data in records if isinstance(data.get("id"), str)}
    ranked = journey_os_generate._ranked_issues(list(by_id.values()), [data for _path, data in issues])
    # The `top` set is a moving diagnostic pointer: after the current red issue
    # closes, the next red/missing/baselined issue must explicitly opt into it.
    # The runtime workflow classifies whether that set needs staging secrets.
    top_issue = next(
        (
            issue for issue in ranked
            if issue.get("evidence_status") in {"missing", "red", "baselined"}
            or issue.get("status") in {"proof_needed", "regressed", "blocked"}
        ),
        None,
    )
    if not top_issue:
        return []
    journey = by_id.get(str(top_issue.get("journey_id")))
    if not isinstance(journey, dict):
        return []
    replay = journey.get("runtime_replay")
    sets = replay.get("sets") if isinstance(replay, dict) else []
    if not isinstance(sets, list) or "top" not in sets:
        return [f"top Journey OS issue {top_issue.get('id')} must be replayable through runtime_replay.sets top"]
    return []

def check(root: Path, changed_files: list[str] | None = None, base_ref: str = "origin/dev") -> list[str]:
    root = root.resolve()
    changed, errors = (changed_files, []) if changed_files else _changed(root, base_ref)
    changed = [path for path in changed if not _is_ignored_generated(path)]
    errors += _scope_errors(root, changed)
    errors += _evidence_secret_errors(root, changed)
    records, load_errors = _load_records(root)
    errors += load_errors
    issues, issue_load_errors = _load_issues(root)
    errors += issue_load_errors
    errors += _schema_validation_errors(root, records, issues)
    try:
        routes = extract_registry_keys((root / ROUTES).read_text(encoding="utf-8"))
    except OSError as exc:
        return errors + [f"unable to read route registry: {exc}"]
    openapi_ops, openapi_errors = _openapi_operations(root)
    errors += openapi_errors
    seen: set[str] = set()
    for path, data in records:
        rid = data.get("id")
        if isinstance(rid, str) and rid in seen:
            errors.append(f"duplicate journey id: {rid}")
        if isinstance(rid, str):
            seen.add(rid)
        errors += _record_errors(root, path, data, routes, openapi_ops)
    issue_ids: set[str] = set()
    for path, data in issues:
        iid = data.get("id")
        if isinstance(iid, str) and iid in issue_ids:
            errors.append(f"duplicate Journey OS issue id: {iid}")
        if isinstance(iid, str):
            issue_ids.add(iid)
        errors += _issue_errors(root, path, data, seen)
    errors += _issue_progress_errors(root, records, issues)
    for path, data in records:
        rel = path.relative_to(root)
        for issue in data.get("issues", []) if isinstance(data.get("issues"), list) else []:
            if isinstance(issue, str) and issue.startswith("JOS-") and issue not in issue_ids:
                errors.append(f"{rel} missing Journey OS issue: {issue}")
    errors += _runtime_replay_coverage_errors(records, issues)
    errors += _generated_errors(root)
    return errors

def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--base-ref", default="origin/dev")
    parser.add_argument("--changed-file", action="append")
    args = parser.parse_args(argv)
    errors = check(args.root, args.changed_file, args.base_ref)
    if errors:
        print("FAIL journey_os_check", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        return 1
    print("OK journey_os_check")
    return 0

if __name__ == "__main__":
    sys.exit(main())
