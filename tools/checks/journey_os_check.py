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
    # Suppression clés mortes l10n — purge de la liste d'audit statique.
    "apps/mobile/test/l10n/fiscal_trust_copy_test.dart",
    "apps/mobile/test/services/coach/de_it_terminology_test.dart",
    str(JOURNEYS / "README.md"),
    str(JOURNEYS / "PRIORITY_RUBRIC.md"),
    str(journey_os_generate.SUMMARY),
    str(journey_os_generate.BOARD),
    str(journey_os_generate.TODAY),
    str(journey_os_generate.CARDS),
    str(OPENAPI),
    # --- ops: sha de deploy dans /api/v1/health (vérification post-promotion) ---
    "services/backend/app/api/v1/endpoints/health.py",
    "services/backend/app/schemas/common.py",
    "services/backend/app/schemas/coaching.py",
    "services/backend/app/models/coach_tools/cross_pillar.py",
    "services/backend/tests/test_coach_tools_cross_pillar.py",
    "services/backend/tests/test_health.py",
    # --- doctrine 2026-08-10 : BRIEF partagé Claude×Codex (contexte lu à chaque
    # session — ADR 2026-08-10-jumeau-financier-et-collaboration-codex.md). ---
    "product/mint_next/BRIEF.md",
    # --- PR B correctifs CI (2026-08-11) : relabel « MA SITUATION » dans le
    # flow legacy (renommage financialSummaryTitle porté par la fondation). ---
    "tools/simulator/flows/maestro-perfect-set/flow_mint2_lpp_dossier_account_claim.yaml",
    "tools/simulator/flows/maestro-perfect-set/flow_drawer_navigation_smoke.yaml",
    "apps/mobile/test/app_router_observers_test.dart",
    "tools/runtime/mint_next_versements_3a_lifecycle.sh",
    "tools/simulator/flows/maestro-perfect-set/flow_mint_next_versements_3a_lifecycle.yaml",
    "apps/mobile/test/screens/mint_next_versements_3a/mint_next_versements_3a_screen_test.dart",
    "apps/mobile/test/screens/mon_argent_versements_3a_fact_test.dart",
    "apps/mobile/lib/screens/mint_next_versements_3a/mint_next_versements_3a_screen.dart",
    "apps/mobile/test/providers/coach_profile_provider_versements_3a_fact_test.dart",
    "apps/mobile/lib/models/mint_next_versements_3a_fact.dart",
    "apps/mobile/test/models/mint_next_versements_3a_fact_test.dart",
    "product/mint_next/storyboard/versements_3a.storyboard.json",
    ".planning/phases/mint-next-user-twin-foundation-20260808/evidence/versements-3a-lifecycle/01-created-visible.png",
    ".planning/phases/mint-next-user-twin-foundation-20260808/evidence/versements-3a-lifecycle/02-cold-relaunch-visible.png",
    ".planning/phases/mint-next-user-twin-foundation-20260808/evidence/versements-3a-lifecycle/03-edited-visible.png",
    ".planning/phases/mint-next-user-twin-foundation-20260808/evidence/versements-3a-lifecycle/04-deleted-absent.png",
    ".planning/phases/mint-next-user-twin-foundation-20260808/evidence/versements-3a-lifecycle/05-delete-survives-relaunch.png",
    ".planning/phases/mint-next-user-twin-foundation-20260808/evidence/versements-3a-lifecycle/runtime.json",
    ".planning/phases/mint-next-user-twin-foundation-20260808/evidence/lpp-affiliation-lifecycle/01-created-visible.png",
    ".planning/phases/mint-next-user-twin-foundation-20260808/evidence/lpp-affiliation-lifecycle/02-cold-relaunch-visible.png",
    ".planning/phases/mint-next-user-twin-foundation-20260808/evidence/lpp-affiliation-lifecycle/03-edited-visible.png",
    ".planning/phases/mint-next-user-twin-foundation-20260808/evidence/lpp-affiliation-lifecycle/04-deleted-absent.png",
    ".planning/phases/mint-next-user-twin-foundation-20260808/evidence/lpp-affiliation-lifecycle/05-delete-survives-relaunch.png",
    ".planning/phases/mint-next-user-twin-foundation-20260808/evidence/lpp-affiliation-lifecycle/runtime.json",
    "tools/runtime/mint_next_lpp_affiliation_lifecycle.sh",
    "tools/simulator/flows/maestro-perfect-set/flow_mint_next_lpp_affiliation_lifecycle.yaml",
    "apps/mobile/lib/screens/mint_next_lpp_affiliation/mint_next_lpp_affiliation_screen.dart",
    "apps/mobile/test/screens/mint_next_lpp_affiliation/mint_next_lpp_affiliation_screen_test.dart",
    "apps/mobile/test/screens/mon_argent_lpp_affiliation_fact_test.dart",
    "apps/mobile/test/providers/coach_profile_provider_lpp_affiliation_fact_test.dart",
    "apps/mobile/lib/models/mint_next_lpp_affiliation_fact.dart",
    "apps/mobile/test/models/mint_next_lpp_affiliation_fact_test.dart",
    "product/mint_next/storyboard/lpp_affiliation.storyboard.json",
    ".planning/phases/mint-next-user-twin-foundation-20260808/evidence/revenu-lifecycle/01-created-visible.png",
    ".planning/phases/mint-next-user-twin-foundation-20260808/evidence/revenu-lifecycle/02-cold-relaunch-visible.png",
    ".planning/phases/mint-next-user-twin-foundation-20260808/evidence/revenu-lifecycle/03-edited-visible.png",
    ".planning/phases/mint-next-user-twin-foundation-20260808/evidence/revenu-lifecycle/04-deleted-absent.png",
    ".planning/phases/mint-next-user-twin-foundation-20260808/evidence/revenu-lifecycle/05-delete-survives-relaunch.png",
    ".planning/phases/mint-next-user-twin-foundation-20260808/evidence/revenu-lifecycle/runtime.json",
    "tools/runtime/mint_next_revenu_lifecycle.sh",
    "tools/simulator/flows/maestro-perfect-set/flow_mint_next_revenu_lifecycle.yaml",
    "apps/mobile/lib/screens/mint_next_revenu/mint_next_revenu_screen.dart",
    "apps/mobile/test/screens/mint_next_revenu/mint_next_revenu_screen_test.dart",
    "apps/mobile/test/screens/mon_argent_revenu_fact_test.dart",
    "apps/mobile/test/providers/coach_profile_provider_revenu_fact_test.dart",
    "apps/mobile/lib/models/mint_next_revenu_fact.dart",
    "apps/mobile/test/models/mint_next_revenu_fact_test.dart",
    "product/mint_next/storyboard/revenu.storyboard.json",
    "apps/mobile/lib/services/auth_service.dart",
    ".planning/phases/mint-next-user-twin-foundation-20260808/evidence/etat-civil-lifecycle/01-created-visible.png",
    ".planning/phases/mint-next-user-twin-foundation-20260808/evidence/etat-civil-lifecycle/02-cold-relaunch-visible.png",
    ".planning/phases/mint-next-user-twin-foundation-20260808/evidence/etat-civil-lifecycle/03-edited-visible.png",
    ".planning/phases/mint-next-user-twin-foundation-20260808/evidence/etat-civil-lifecycle/04-deleted-absent.png",
    ".planning/phases/mint-next-user-twin-foundation-20260808/evidence/etat-civil-lifecycle/05-delete-survives-relaunch.png",
    ".planning/phases/mint-next-user-twin-foundation-20260808/evidence/etat-civil-lifecycle/runtime.json",
    "tools/runtime/mint_next_etat_civil_lifecycle.sh",
    "tools/simulator/flows/maestro-perfect-set/flow_mint_next_etat_civil_lifecycle.yaml",
    "apps/mobile/lib/screens/onboarding/mvp_wedge/onboarding_provider.dart",
    "apps/mobile/lib/screens/mint_next_etat_civil/mint_next_etat_civil_screen.dart",
    "apps/mobile/test/screens/mint_next_etat_civil/mint_next_etat_civil_screen_test.dart",
    "apps/mobile/test/screens/mon_argent_etat_civil_fact_test.dart",
    "apps/mobile/test/services/coach_profile_test.dart",
    "apps/mobile/test/providers/coach_profile_provider_civil_status_fact_test.dart",
    "apps/mobile/lib/models/mint_next_civil_status_fact.dart",
    "apps/mobile/test/models/mint_next_civil_status_fact_test.dart",
    "product/mint_next/storyboard/etat_civil.storyboard.json",
    ".planning/phases/mint-next-user-twin-foundation-20260808/evidence/domicile-lifecycle/01-created-visible.png",
    ".planning/phases/mint-next-user-twin-foundation-20260808/evidence/domicile-lifecycle/02-cold-relaunch-visible.png",
    ".planning/phases/mint-next-user-twin-foundation-20260808/evidence/domicile-lifecycle/03-edited-visible.png",
    ".planning/phases/mint-next-user-twin-foundation-20260808/evidence/domicile-lifecycle/04-deleted-absent.png",
    ".planning/phases/mint-next-user-twin-foundation-20260808/evidence/domicile-lifecycle/05-delete-survives-relaunch.png",
    ".planning/phases/mint-next-user-twin-foundation-20260808/evidence/domicile-lifecycle/runtime.json",
    "tools/runtime/mint_next_domicile_lifecycle.sh",
    "tools/simulator/flows/maestro-perfect-set/flow_mint_next_domicile_lifecycle.yaml",
    "apps/mobile/test/screens/mon_argent_domicile_fact_test.dart",
    ".planning/reports/hermeneutique/index.html",
    "apps/mobile/lib/screens/mint_next_domicile/mint_next_domicile_screen.dart",
    "apps/mobile/test/models/mint_next_3a_fiscal_context_domicile_test.dart",
    "apps/mobile/test/screens/mint_next_domicile/mint_next_domicile_screen_test.dart",
    # --- Lego 1 domicile fiscal (2026-08-11) : fait canonique domicile
    # (mini-storyboard, modèle, provider, écran, consommateur 3a). ---
    "apps/mobile/lib/models/mint_next_domicile_fact.dart",
    "apps/mobile/test/models/mint_next_domicile_fact_test.dart",
    "apps/mobile/test/providers/coach_profile_provider_domicile_fact_test.dart",
    "product/mint_next/storyboard/domicile_fiscal.storyboard.json",
    # --- atterrissage PR C (cadrage n°1, 2026-08-11) : shell 3a minimal —
    # handoff screen/card, route gate, store 3a, tax boundary + delta engine,
    # machinerie flag fail-closed, tests dédiés. Flag OFF partout. ---
    "apps/mobile/lib/models/mint_next_3a_tax_boundary.dart",
    "apps/mobile/lib/routes/mint_next_3a_route_gate.dart",
    "apps/mobile/lib/screens/mint_next_3a/mint_next_3a_handoff_screen.dart",
    "apps/mobile/lib/services/mint_next_3a_task_store.dart",
    "apps/mobile/lib/services/mint_next_3a_tax_delta_engine.dart",
    "apps/mobile/lib/widgets/aujourdhui/mint_next_3a_handoff_card.dart",
    "apps/mobile/test/patrol/mint_next_3a_flag_off_task_test.dart",
    "apps/mobile/test/patrol/mint_next_3a_product_handoff_test.dart",
    "apps/mobile/test/screens/mint_next_3a/mint_next_3a_product_handoff_test.dart",
    "apps/mobile/test/services/install_lifecycle_service_test.dart",
    "apps/mobile/test/services/mint_next_3a_task_store_test.dart",
    "apps/mobile/test/services/mint_next_3a_tax_boundary_test.dart",
    # --- atterrissage PR B (cadrage n°1, 2026-08-10) : fondation canonique
    # prouvée — cycle de vie du fait logement (modèle, écran, carte
    # Aujourd'hui, transaction coordonnée SecureWizardStore, Ma situation),
    # phase jumeau + évidence runtime, garde capture, flags OFF, ARB 6 langues,
    # observabilité routes privées. Shell 3a strippé (PR C). ---
    ".planning/phases/mint-next-user-twin-foundation-20260808/CONTEXT.md",
    ".planning/phases/mint-next-user-twin-foundation-20260808/PLAN.md",
    ".planning/phases/mint-next-user-twin-foundation-20260808/SPEC.md",
    ".planning/phases/mint-next-user-twin-foundation-20260808/VERIFICATION.md",
    ".planning/phases/mint-next-user-twin-foundation-20260808/evidence/housing-lifecycle/01-created-visible.png",
    ".planning/phases/mint-next-user-twin-foundation-20260808/evidence/housing-lifecycle/02-cold-relaunch-visible.png",
    ".planning/phases/mint-next-user-twin-foundation-20260808/evidence/housing-lifecycle/03-edited-visible.png",
    ".planning/phases/mint-next-user-twin-foundation-20260808/evidence/housing-lifecycle/04-deleted-absent.png",
    ".planning/phases/mint-next-user-twin-foundation-20260808/evidence/housing-lifecycle/05-delete-survives-relaunch.png",
    ".planning/phases/mint-next-user-twin-foundation-20260808/evidence/housing-lifecycle/maestro.log",
    ".planning/phases/mint-next-user-twin-foundation-20260808/evidence/housing-lifecycle/runtime.json",
    "apps/mobile/lib/models/financial_plan.dart",
    "apps/mobile/lib/models/mint_next_housing_fact.dart",
    "apps/mobile/lib/screens/mint_next_housing/mint_next_housing_screen.dart",
    "apps/mobile/lib/screens/mint_next_housing/mint_next_housing_screen.dart.capture.json",
    "apps/mobile/lib/services/analytics_observer.dart",
    "apps/mobile/lib/services/e2e_runtime_flags.dart",
    "apps/mobile/lib/services/feature_flags.dart",
    "apps/mobile/lib/services/install_lifecycle_service.dart",
    "apps/mobile/lib/services/observability/private_route_telemetry.dart",
    "apps/mobile/lib/services/observability/sentry_scrub.dart",
    "apps/mobile/lib/widgets/aujourdhui/mint_next_housing_card.dart",
    "apps/mobile/test/models/financial_plan_test.dart",
    "apps/mobile/test/models/mint_next_housing_fact_test.dart",
    "apps/mobile/test/providers/coach_profile_provider_housing_fact_test.dart",
    "apps/mobile/test/providers/coach_profile_provider_secure_failure_test.dart",
    "apps/mobile/test/providers/financial_plan_provider_test.dart",
    "apps/mobile/test/screens/mint_next_housing/mint_next_housing_screen_test.dart",
    "apps/mobile/test/screens/mon_argent_screen_test.dart",
    "apps/mobile/test/screens/onboarding/mvp_wedge/mint2_first_experience_intent_migration_test.dart",
    "apps/mobile/test/screens/onboarding/mvp_wedge/onboarding_archetype_flow_test.dart",
    "apps/mobile/test/services/e2e_runtime_flags_test.dart",
    "apps/mobile/test/services/feature_flags_test.dart",
    "apps/mobile/test/services/observability/private_route_telemetry_test.dart",
    "apps/mobile/test/services/observability/sentry_scrub_test.dart",
    "apps/mobile/test/services/report_persistence_service_test.dart",
    "apps/mobile/test/widgets/aujourdhui/mint_next_housing_card_test.dart",
    "tools/checks/tests/test_mint_next_housing_lifecycle_runtime.py",
    "tools/checks/tests/test_user_data_capture_contract.py",
    "tools/checks/user_data_capture_contract.py",
    "tools/runtime/mint_next_housing_lifecycle.sh",
    "tools/simulator/flows/maestro-perfect-set/flow_mint_next_housing_lifecycle.yaml",
    # --- atterrissage PR A (cadrage n°1, 2026-08-10) : vérité produit de la
    # fondation MINT Next — ADR jumeau, phase Golden 3a (SPEC amendé sans
    # cérémonie B0-B5, contrats substantiels, annexes provenance, schémas),
    # storyboard + garde + renderer, autorité design mint-v2, outillage
    # provenance sources officielles. ---
    ".planning/phases/mint-next-vertical01-3a-20260802/CONTEXT.md",
    ".planning/phases/mint-next-vertical01-3a-20260802/PLAN.md",
    ".planning/phases/mint-next-vertical01-3a-20260802/SPEC.md",
    ".planning/phases/mint-next-vertical01-3a-20260802/VERIFICATION.md",
    ".planning/phases/mint-next-vertical01-3a-20260802/annexes/aipd-processing-inventory.json",
    ".planning/phases/mint-next-vertical01-3a-20260802/annexes/authority-receipts.yaml",
    ".planning/phases/mint-next-vertical01-3a-20260802/annexes/bundle.yaml",
    ".planning/phases/mint-next-vertical01-3a-20260802/annexes/calculation-oracle-goldens.json",
    ".planning/phases/mint-next-vertical01-3a-20260802/annexes/content-review-receipt.yaml",
    ".planning/phases/mint-next-vertical01-3a-20260802/annexes/golden-fixtures.json",
    ".planning/phases/mint-next-vertical01-3a-20260802/annexes/legacy-harvest-corpus.json",
    ".planning/phases/mint-next-vertical01-3a-20260802/annexes/legal-authority-sources.json",
    ".planning/phases/mint-next-vertical01-3a-20260802/annexes/normalized-ruleset.yaml",
    ".planning/phases/mint-next-vertical01-3a-20260802/annexes/parser-version-manifest.yaml",
    ".planning/phases/mint-next-vertical01-3a-20260802/annexes/persona-case-matrix.yaml",
    ".planning/phases/mint-next-vertical01-3a-20260802/annexes/source-authority-manifest.yaml",
    ".planning/phases/mint-next-vertical01-3a-20260802/annexes/source-extractions.json",
    ".planning/phases/mint-next-vertical01-3a-20260802/annexes/threat-model-risk-register.json",
    ".planning/phases/mint-next-vertical01-3a-20260802/contracts/aipd-screening.yaml",
    ".planning/phases/mint-next-vertical01-3a-20260802/contracts/anti-pii.yaml",
    ".planning/phases/mint-next-vertical01-3a-20260802/contracts/calculation-contract.yaml",
    ".planning/phases/mint-next-vertical01-3a-20260802/contracts/fact-minimum-set.yaml",
    ".planning/phases/mint-next-vertical01-3a-20260802/contracts/feature-flag-kill-switch.yaml",
    ".planning/phases/mint-next-vertical01-3a-20260802/contracts/key-contract.yaml",
    ".planning/phases/mint-next-vertical01-3a-20260802/contracts/legacy-harvest.yaml",
    ".planning/phases/mint-next-vertical01-3a-20260802/contracts/legal-memo.md",
    ".planning/phases/mint-next-vertical01-3a-20260802/contracts/navigation-graph.yaml",
    ".planning/phases/mint-next-vertical01-3a-20260802/contracts/privacy-contract.yaml",
    ".planning/phases/mint-next-vertical01-3a-20260802/contracts/regulatory-applicability.yaml",
    ".planning/phases/mint-next-vertical01-3a-20260802/contracts/retention-export-deletion.yaml",
    ".planning/phases/mint-next-vertical01-3a-20260802/contracts/state-machine.yaml",
    ".planning/phases/mint-next-vertical01-3a-20260802/contracts/threat-model.yaml",
    ".planning/phases/mint-next-vertical01-3a-20260802/decisions/3a-authority-adr.md",
    ".planning/phases/mint-next-vertical01-3a-20260802/migrations/fact-migrations.yaml",
    ".planning/phases/mint-next-vertical01-3a-20260802/migrations/plan-migrations.yaml",
    ".planning/phases/mint-next-vertical01-3a-20260802/migrations/schema-migration-fixtures.json",
    ".planning/phases/mint-next-vertical01-3a-20260802/schemas/dependency.schema.json",
    ".planning/phases/mint-next-vertical01-3a-20260802/schemas/fact.schema.json",
    ".planning/phases/mint-next-vertical01-3a-20260802/schemas/plan.schema.json",
    "product/mint_next/storyboard/index.html",
    "product/mint_next/storyboard/storyboard.contract.schema.json",
    "product/mint_next/storyboard/three_a.storyboard.json",
    "tools/authority/normalize_three_a_2026_sources.py",
    "tools/authority/tests/test_normalize_three_a_2026_sources.py",
    "tools/checks/mint_next_storyboard_guard.py",
    "tools/checks/mint_next_three_a_goal_annexes_guard.py",
    "tools/checks/tests/test_mint_next_storyboard_guard.py",
    "tools/checks/tests/test_mint_next_three_a_goal_annexes_guard.py",
    "tools/storyboard/render_mint_storyboard.py",
    # --- prep Flutter 3.44.8 : ancêtre Material pour les tiles en carte colorée
    # (assertion debug ListTile._debugCheckBackgroundIsHidden). Écrans/widgets
    # partagés touchés, hors whitelist Journey OS existante. ---
    "apps/mobile/lib/screens/job_comparison_screen.dart",
    "apps/mobile/lib/screens/simulator_compound_screen.dart",
    "apps/mobile/lib/widgets/collapsible_section.dart",
    "apps/mobile/lib/widgets/educational/educational_insert_widget.dart",
    # --- fix(retraite) : honorer la rente AVS DÉCLARÉE dans les deux moteurs de
    # projection (RPS + Forecaster) pour un retraité (salaire 0) au lieu de la
    # recalculer depuis renteFromRAMD(0)=0. Preuve runtime dashboard /retraite. ---
    "apps/mobile/lib/services/retirement_projection_service.dart",
    "apps/mobile/lib/services/forecaster_service.dart",
    "apps/mobile/test/services/retirement_declared_avs_test.dart",
    "apps/mobile/test/screens/retraite_dashboard_declared_avs_test.dart",
    "apps/mobile/test/screens/coach/retirement_dashboard_test.dart",
    # --- fix(e2e) : fallback de scellement debug/E2E-only dans SecureWizardStore
    # (double-gardé kReleaseMode + MINT_E2E_SEAL_FALLBACK). Sans lui, le seal
    # keychain échoue sur build sim --no-codesign (-34018) → /retraite retombe en
    # State C dans le harnais. Chemin release byte-inaccessible, contrat privacy
    # secure_failure_test intact. Branche codex/journey-os-e2e-seal-fallback. ---
    "apps/mobile/lib/services/secure_wizard_store.dart",
    "apps/mobile/test/services/secure_wizard_store_test.dart",
    ".claude/AGENT_BOOTSTRAP.md",
    ".github/pull_request_template.md",
    # Fix namespace-shadowing CI 2026-08-04 : tools/ devient un paquet régulier.
    "tools/__init__.py",
    "tools/checks/__init__.py",
    # Décision S4-F1 (2026-08-04) : §4.8 vocabulaire de la confiance —
    # trame vs courbe, acte l'écart majeur de l'audit de fidélité #1185.
    "docs/DESIGN_SYSTEM.md",
    ".github/workflows/ai-workflow-guards.yml",
    ".github/workflows/journey-os-runtime-replay.yml",
    # Batch 19 R1 (2026-08-03) : exécuteur CI neutre des preuves RED + job
    # release-attestation dispatch-only (check_git=True non-waivé).
    ".github/workflows/mint-next-proofs.yml",
    # Garde du contrat de navigation MINT Next (2026-08-04) : gate CI mécanique
    # bidirectionnel entre product/mint_next/batch6/navigation.yaml et le Design
    # Lab. No-op vert tant que le contenu mint_next n'est pas sur cette base.
    "tools/checks/mint_next_navigation_contract.py",
    "tools/checks/mint_next_navigation_contract_waitlist.yaml",
    "tools/checks/tests/test_mint_next_navigation_contract.py",
    # Spike upgrade Flutter 3.44.8 (ADR AX iOS 26.2 Étape 4) : pins CI unifiés.
    ".github/workflows/testflight.yml",
    ".github/workflows/play-store.yml",
    ".github/workflows/web.yml",
    ".github/workflows/walker_nightly.yml",
    "apps/mobile/pubspec.lock",
    # Candidat TestFlight 2.13.0 (2026-08-01) : bump du version name pubspec
    # (2.12.4 -> 2.13.0) pour la promotion staging. Fichier release/ops,
    # orthogonal au périmètre Journey OS — même statut que pubspec.lock ci-dessus
    # et testflight.yml plus haut.
    "apps/mobile/pubspec.yaml",
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
    "legal/PRIVACY.md",
    "docs/legal/privacy_policy_v2.3.0.md",
    "docs/legal/privacy_policy_v2.4.0.md",
    "decisions/ADR-20260223-simulator-enrichment.md",
    "decisions/ADR-20260111-wizard-progression-clarte.md",
    "docs/AGENTS/flutter.md",
    "apps/mobile/lib/services/consent/consent_service.dart",
    "services/backend/app/schemas/consent_receipt.py",
    "services/backend/tests/test_purpose_label_coverage.py",
    "services/backend/app/services/coach/claude_coach_service.py",
    "services/backend/tests/test_claude_coach.py",
    "apps/mobile/lib/services/financial_core/arbitrage_engine.dart",
    "apps/mobile/lib/services/financial_core/withdrawal_sequencing_service.dart",
    "apps/mobile/lib/services/financial_core/monte_carlo_service.dart",
    "apps/mobile/lib/services/financial_core/mortality_ofs.dart",
    "apps/mobile/test/services/financial_core/mortality_ofs_test.dart",
    "docs/calculator-graph.md",
    "apps/mobile/lib/services/api_service.dart",
    "apps/mobile/test/services/api_service_capital_epuise_test.dart",
    "apps/mobile/test/simulators/rente_vs_capital_test.dart",
    # -a6e : chaîne morte lpp_buyback_advanced (façade jamais montée ; la
    # logique 79b -okl vit désormais dans le flux live RachatEchelonne)
    "apps/mobile/lib/widgets/simulators/lpp_buyback_advanced_widget.dart",
    "apps/mobile/lib/services/simulators/lpp_buyback_advanced_simulator.dart",
    "apps/mobile/test/simulators/lpp_buyback_advanced_simulator_test.dart",
    "apps/mobile/test/services/financial_core/arbitrage_engine_mixed_deflation_test.dart",
    "services/backend/app/services/pillar_3a_deep/retroactive_3a_service.py",
    "services/backend/tests/test_pillar_3a_retroactive.py",
    "services/backend/app/services/coach/tool_registry/anthropic_defer_loading_adapter.py",
    "apps/mobile/lib/services/retroactive_3a_calculator.dart",
    "apps/mobile/test/services/retroactive_3a_calculator_test.dart",
    "apps/mobile/test/services/phase5_production_bugs_test.dart",
    ".github/workflows/ci.yml",
    # -dj3 : évolution doctrine 6 fichiers (UI Kit réel + fiscal v2)
    "CLAUDE.md",
    # --- feat(agents) : roster élargi selon handoff 2026-08-03 §11.2/§11.4 —
    # deux agents permanents ajoutés au roster canonique .claude/agents/. ---
    ".claude/agents/mint-experience.md",
    ".claude/agents/mint-integrations-security.md",
    "docs/AGENTS/flutter.md",
    "docs/AGENTS/backend.md",
    # --- docs(doctrine) 2026-08-03 : neutralisation des couches doctrinales
    # contradictoires (bandeau SUPERSEDED sur ROADMAP_V2, étalon ESTV dans
    # swiss-brain §3). Carte :
    # .planning/audit-etat-des-lieux-2026-07/carte-contradictions-doctrinales.md ---
    "docs/ROADMAP_V2.md",
    "docs/AGENTS/swiss-brain.md",
    ".claude/skills/mint-flutter-dev/SKILL.md",
    ".claude/skills/mint-backend-dev/SKILL.md",
    ".planning/decisions/2026-05-17-data-architecture-event-log-vs-bitemporal.md",
    "tools/checks/create_or_update_mint_skills.py",
    # -dwr : posture LSFin du tip rachat échelonné (copie x6 + garde)
    "apps/mobile/test/l10n/rachat_echelonne_posture_test.dart",
    # campagne-A privacy server geo (2026-07-24)
    "tools/checks/no_false_privacy_attestation.py",
    "lefthook.yml",
    ".github/workflows/ai-workflow-guards.yml",
    ".planning/decisions/2026-07-24-campagne-contenu-officiel-garanti.md",
    # ADR Atlas des écrans + mémos d'état de l'art (2026-08-05)
    ".planning/decisions/2026-08-05-atlas-ecrans-construit-pas-adopte.md",
    ".planning/audit/2026-08-05-atlas-ecosysteme-flutter.md",
    ".planning/audit/2026-08-05-atlas-etat-de-lart-hors-flutter.md",
    # -b6k : littéral lppReturn -> reg() avec fallback
    "apps/mobile/test/screens/arbitrage/rvc_lpp_return_registry_test.dart",
    "tools/checks/ci_gate_aggregation_check.py",
    "services/backend/app/constants/social_insurance.py",
    "services/backend/app/services/independants/avs_cotisations_service.py",
    # Cluster 12D V2-1 (#1163 suite) : impôt sur le bénéfice dans le comparateur
    # dividende — étalon backend (miroir mobile + parité déjà whitelistés).
    "services/backend/app/services/independants/dividende_vs_salaire_service.py",
    "services/backend/app/services/independant_service.py",
    "services/backend/tests/test_independants.py",
    "services/backend/tests/test_independant_service.py",
    "services/backend/tests/test_segments.py",
    "apps/mobile/lib/services/independants_service.dart",
    "apps/mobile/lib/constants/social_insurance.dart",
    # -b9c : sémantique taux AVS combinés + provenance taux min LPP
    "services/backend/tests/test_b9c_avs_combined_semantics.py",
    # codex/journey-os-libre-passage-i18n (#1125) : legalRef extrait en ARB +
    # aligné sur LFLP art. 4 al. 2 (le délai 6 mois n'est pas art. 3).
    "apps/mobile/lib/screens/lpp_deep/libre_passage_screen.dart",
    "apps/mobile/test/screens/lpp_deep/libre_passage_screen_test.dart",
    # -dy0 : contraste AA — sites texte greenDark -> greenForest
    "apps/mobile/lib/screens/lpp_deep/rachat_echelonne_screen.dart",
    "apps/mobile/lib/screens/pillar_3a_deep/staggered_withdrawal_screen.dart",
    # fix(i18n) device-evidence : les 3 écrans 3a profonds passent `l` au
    # simulateur (disclaimer localisé au lieu du fallback ASCII) ; le
    # comparateur localise aussi name/description/warning. staggered était
    # déjà whitelisté ci-dessus.
    "apps/mobile/lib/screens/pillar_3a_deep/provider_comparator_screen.dart",
    "apps/mobile/lib/screens/pillar_3a_deep/real_return_screen.dart",
    "apps/mobile/lib/screens/household/household_screen.dart",
    "apps/mobile/lib/widgets/educational/leasing_cost_insert_widget.dart",
    "apps/mobile/lib/theme/colors.dart",
    "apps/mobile/test/accessibility/green_dark_text_contrast_test.dart",
    "apps/mobile/lib/screens/open_banking/open_banking_hub_screen.dart",
    # -5up PR A : couple_optimizer backend -> modèle fiscal v2
    "services/backend/app/services/couple_optimizer/couple_optimizer.py",
    "services/backend/tests/test_5up_couple_v2_identity.py",
    # journey-os AVS échelle 44 : couple_optimizer délègue à rente_from_ramd canonique
    "services/backend/tests/test_couple_optimizer.py",
    # campagne-A : mariage_service -> moteur fiscal canonique + double-activité LIFD 33 al.2
    "services/backend/app/services/family/mariage_service.py",
    "services/backend/tests/test_family.py",
    # campagne-A : naissance_service -> déductions IFD 2026 enfant/garde + article 33 al.3
    "services/backend/app/services/family/naissance_service.py",
    "services/backend/app/api/v1/endpoints/family.py",
    # succession concubinage : retrait du montant ET du taux d'impôt successoral
    # (base fausse depuis la révision du droit successoral au 1.1.2023 ; taux plat
    # par canton démenti sur au moins deux cantons) + citation CC 462 corrigée
    "services/backend/app/services/family/concubinage_service.py",
    "services/backend/app/schemas/family.py",
    "services/backend/tests/test_anthropic_defer_loading_adapter.py",
    "services/backend/tests/test_tool_search_round_trip.py",
    "services/backend/tests/test_canton_required_grounding.py",
    "services/backend/tests/test_blank_profile_422_contract.py",
    # campagne-A : déduction enfant/garde 2026 servie partout (mobile + corpus)
    "apps/mobile/lib/services/family_service.dart",
    "apps/mobile/lib/widgets/coach/fiscal_superpower_widget.dart",
    "apps/mobile/test/services/family_service_test.dart",
    "apps/mobile/test/services/financial_report_service_test.dart",
    "apps/mobile/test/widgets/coach/fiscal_superpower_widget_test.dart",
    "education/inserts/q_naissance.md",
    "education/inserts/q_mariage.md",
    "education/inserts/concepts/naissance_impact_financier.md",
    "education/inserts/concepts/fiscal_deductions_courantes.md",
    "services/backend/education_inserts/q_naissance.md",
    "services/backend/education_inserts/q_mariage.md",
    "services/backend/education_inserts/concepts/naissance_impact_financier.md",
    "services/backend/education_inserts/concepts/fiscal_deductions_courantes.md",
    # campagne-A : allocations familiales LAFam 2026 (table OFAS/BSV, 26 cantons)
    "apps/mobile/lib/widgets/visualizations/canton_allocation_map.dart",
    "education/inserts/q_canton_move.md",
    "services/backend/education_inserts/q_canton_move.md",
    # -8p4 : tax_calculator.dart chemin revenu -> modèle v2 (PR B)
    "apps/mobile/lib/services/financial_core/tax_calculator.dart",
    "apps/mobile/test/services/financial_core/tax_calculator_v2_identity_test.dart",
    "apps/mobile/test/services/tax_calculator_extended_test.dart",
    "apps/mobile/test/golden/golden_couple_validation_test.dart",
    "apps/mobile/test/services/financial_core/golden_couple_lauren_test.dart",
    "apps/mobile/test/services/life_events_service_test.dart",
    "apps/mobile/test/services/coaching_service_test.dart",
    "apps/mobile/test/services/financial_parity_test.dart",
    # -2b7 : FiscalService mobile -> modèle v2 (dernier vestige v1)
    "apps/mobile/lib/services/fiscal_service.dart",
    "apps/mobile/lib/services/financial_core/income_tax_model_v2.dart",
    "apps/mobile/lib/screens/expat_screen.dart",
    "apps/mobile/test/services/fiscal_service_test.dart",
    # -7vv : IndicatifBanner — trame réelle, CTA audible, fiscalite routable
    "apps/mobile/test/services/independants_service_test.dart",
    # Cluster 12D V2-1 : drains D2 (parité backend) + confidence D10 dividende.
    "apps/mobile/lib/screens/independants/dividende_vs_salaire_screen.dart",
    "apps/mobile/test/screens/independants/dividende_vs_salaire_screen_test.dart",
    "apps/mobile/test/services/independants_backend_parity_test.dart",
    ".planning/phases/mint-utilisable-12d-vague2/V2-1-INDEPENDANTS-INVENTORY.md",
    "apps/mobile/lib/services/segments_service.dart",
    "apps/mobile/test/services/segments_service_test.dart",
    "apps/mobile/lib/screens/independants/avs_cotisations_screen.dart",
    "apps/mobile/lib/screens/donation_screen.dart",
    "apps/mobile/test/screens/donation_profile_seed_test.dart",
    "apps/mobile/lib/widgets/situation/situation_gate.dart",
    "apps/mobile/test/screens/donation_gate_test.dart",
    "apps/mobile/test/screens/donation_i18n_wiring_test.dart",
    "apps/mobile/test/screens/life_event_screens_v2_smoke_test.dart",
    "apps/mobile/lib/screens/first_job_screen.dart",
    "apps/mobile/test/screens/first_job_gate_test.dart",
    "apps/mobile/test/screens/first_job_lucidite_test.dart",
    "apps/mobile/test/screens/first_job_badge_overflow_test.dart",
    # AX pilote (ADR 2026-07-30) : verrou SemanticsTester rvc (contrat inverse).
    "apps/mobile/test/screens/rente_vs_capital_semantics_test.dart",
    "apps/mobile/lib/screens/naissance_screen.dart",
    "apps/mobile/lib/screens/mariage_screen.dart",
    "apps/mobile/test/screens/mariage_gate_test.dart",
    "apps/mobile/lib/widgets/coach/couple_narrative_timeline.dart",
    "apps/mobile/test/screens/naissance_gate_test.dart",
    "apps/mobile/test/screens/life_event_screens_additional_smoke_test.dart",
    "apps/mobile/lib/screens/divorce_simulator_screen.dart",
    "apps/mobile/test/screens/divorce_gate_test.dart",
    "apps/mobile/lib/screens/concubinage_screen.dart",
    "apps/mobile/test/screens/concubinage_gate_test.dart",
    "apps/mobile/lib/widgets/visualizations/concubinage_decision_matrix.dart",
    # Renommage : la jauge « pénalité du mariage » devient une comparaison
    # d'impôt du ménage. Les deux chemins sont listés le temps que le
    # renommage soit derrière nous.
    "apps/mobile/lib/widgets/visualizations/marriage_penalty_gauge.dart",
    "apps/mobile/lib/widgets/visualizations/marriage_tax_comparison.dart",
    "tools/checks/no_hardcoded_fr.py",
    "tools/collect_estv.py",
    "tools/checks/accent_lint_fr.py",
    "tools/checks/_baseline_diff.py",
    "tools/checks/no_cantonal_rate_table.py",
    "services/backend/app/services/coaching_engine.py",
    "services/backend/app/services/first_job/onboarding_service.py",
    "tools/checks/prefer_mint_cta.py",
    "tools/checks/prefer_mint_text_style.py",
    "tools/checks/prefer_mint_fonts.py",
    "tools/checks/prefer_mint_radius.py",
    "tools/checks/prefer_mint_color_token.py",
    ".github/workflows/design-lints.yml",
    "apps/mobile/lib/widgets/premium/mint_amount_field.dart",
    "apps/mobile/test/widgets/premium/mint_amount_field_test.dart",
    "lefthook.yml",
    "tools/checks/baselines/prefer_mint_text_style.baseline.txt",
    "apps/mobile/lib/screens/gender_gap_screen.dart",
    "apps/mobile/test/screens/gender_gap_gate_test.dart",
    ".planning/reports/SESSION-2026-07-26-p2-gate-dur.html",
    ".planning/reports/SESSION-2026-07-26-etat-des-lieux.html",
    ".planning/reports/SESSION-2026-07-28-plan-de-fusion.html",
    ".planning/reports/SESSION-2026-07-28-plan-de-fusion.md",
    ".planning/reports/SESSION-2026-07-30.html",
    ".planning/reports/SESSION-2026-07-30.md",
    ".planning/reports/SESSION-2026-07-31.html",
    ".planning/reports/SESSION-2026-07-31.md",
    ".planning/audit/2026-07-26-advisor-lens-simulators.md",
    "tools/checks/generate_theme_maps.py",
    "tools/checks/nav_graph.py",
    "apps/mobile/test/screens/simulator_screens_smoke_test.dart",
    "apps/mobile/lib/services/life_events_service.dart",
    "apps/mobile/test/services/life_events_divorce_test.dart",
    "apps/mobile/lib/widgets/coach/divorce_film_widget.dart",
    "apps/mobile/test/widgets/coach/divorce_film_widget_test.dart",
    ".planning/decisions/2026-07-25-p2-simulator-result-gating.md",
    ".planning/reports/SESSION-2026-07-25-p2-gate-dur.html",
    "apps/mobile/lib/screens/independants/pillar_3a_indep_screen.dart",
    "apps/mobile/lib/screens/independants/lpp_volontaire_screen.dart",
    "apps/mobile/test/screens/indep_profile_seed_test.dart",
    "apps/mobile/lib/services/simulators/lpp_buyback_advanced_simulator.dart",
    "apps/mobile/test/simulators/lpp_buyback_advanced_simulator_test.dart",
    "apps/mobile/test/services/financial_core/arbitrage_engine_blocage_lpp_test.dart",
    "services/backend/app/services/arbitrage/allocation_annuelle.py",
    "services/backend/app/services/arbitrage/rachat_vs_marche.py",
    "services/backend/app/services/pillar_3a_deep/multi_account_service.py",
    "services/backend/app/schemas/pillar_3a_deep.py",
    "services/backend/app/api/v1/endpoints/pillar_3a_deep.py",
    "services/backend/tests/test_pillar_3a_deep.py",
    "tools/openapi/openapi.json",
    "services/backend/app/services/consent/consent_service.py",
    "services/backend/app/models/consent.py",
    "services/backend/alembic/versions/p125_consent_shred_pending.py",
    "services/backend/tests/services/consent/test_consent_service.py",
    "services/backend/tests/fixtures/test_pg_fixture_self.py",
    "services/backend/app/services/consent/shred_sweep.py",
    "services/backend/app/main.py",
    "services/backend/app/services/document_memory_service.py",
    "services/backend/app/services/document_vision_service.py",
    "services/backend/app/api/v1/endpoints/documents.py",
    "services/backend/tests/services/document/test_nlpd_gates_enforce.py",
    "services/backend/tests/services/consent/test_consent_service_extensions.py",
    "apps/mobile/lib/screens/profile/privacy_control_screen.dart",
    "apps/mobile/test/screens/profile/privacy_control_screen_test.dart",
    "apps/mobile/test/golden_screenshots/goldens/privacy_15_fr.png",
    "apps/mobile/test/golden_screenshots/goldens/privacy_se_fr.png",
    "apps/mobile/lib/screens/expat_screen.dart",
    "apps/mobile/lib/widgets/coach/top_cantons_widget.dart",
    "apps/mobile/test/screens/expat_top_cantons_real_test.dart",
    "apps/mobile/test/screens/arbitrage/rvc_layer4_prompts_test.dart",
    "apps/mobile/test/widgets/coach/smart_default_indicatif_test.dart",
    # -4ip : scan PII réel armé sur logs staging
    "scripts/check_pii_in_logs.py",
    ".github/workflows/ci.yml",
    "services/backend/tests/test_allocation_annuelle.py",
    "services/backend/tests/test_arbitrage_allocation_annuelle_grounding.py",
    "services/backend/education_inserts/concepts/avs_cotisations_independants.md",
    "education/inserts/concepts/avs_cotisations_independants.md",
    "services/backend/education_inserts/concepts/lpp_salaire_coordonne.md",
    "education/inserts/concepts/lpp_salaire_coordonne.md",
    "services/backend/education_inserts/concepts/donation_entre_vifs.md",
    "education/inserts/concepts/donation_entre_vifs.md",
    "services/backend/tests/test_education_inserts_truth.py",
    # campagne-A bead A2 : montants LPP/AVS périmés alignés sur registry (2026-07-24)
    "education/inserts/concepts/avs_bonifications_educatives.md",
    "services/backend/education_inserts/concepts/avs_bonifications_educatives.md",
    "education/inserts/concepts/avs_rente_calcul.md",
    "education/inserts/concepts/deduction_coordination.md",
    "education/inserts/concepts/lpp_1e_plans.md",
    "education/inserts/concepts/lpp_bonifications_age.md",
    "education/inserts/concepts/lpp_surobligatoire_role.md",
    "education/inserts/concepts/retraite_taux_remplacement.md",
    "education/inserts/concepts/surobligatoire_vs_obligatoire.md",
    "education/inserts/concepts/taux_conversion_lpp.md",
    "education/inserts/q_avs_gaps.md",
    "education/inserts/q_avs_gaps_de.md",
    "education/inserts/q_has_pension_fund.md",
    "education/inserts/q_has_pension_fund_de.md",
    "services/backend/education_inserts/concepts/avs_rente_calcul.md",
    "services/backend/education_inserts/concepts/deduction_coordination.md",
    "services/backend/education_inserts/concepts/lpp_1e_plans.md",
    "services/backend/education_inserts/concepts/lpp_bonifications_age.md",
    "services/backend/education_inserts/concepts/lpp_surobligatoire_role.md",
    "services/backend/education_inserts/concepts/retraite_taux_remplacement.md",
    "services/backend/education_inserts/concepts/surobligatoire_vs_obligatoire.md",
    "services/backend/education_inserts/concepts/taux_conversion_lpp.md",
    "services/backend/education_inserts/q_avs_gaps.md",
    "services/backend/education_inserts/q_avs_gaps_de.md",
    "services/backend/education_inserts/q_has_pension_fund.md",
    "services/backend/education_inserts/q_has_pension_fund_de.md",
    "services/backend/tests/test_coach_eu_routing.py",
    "services/backend/tests/test_rvc_certificate_receipt.py",
    "services/backend/tests/test_rente_vs_capital.py",
    "services/backend/tests/test_rvc_premier_eclairage_totals.py",
    "services/backend/tests/documents/test_sse_third_party_gate.py",
    "services/backend/app/services/document_memory_service.py",
    "services/backend/app/services/document_vision_service.py",
    "services/backend/app/services/document_stream.py",
    "services/backend/app/core/config.py",
    "services/backend/tests/conftest.py",
    "services/backend/tests/test_consent_gate_default_hard_block.py",
    "services/backend/tests/test_consent_guards.py",
    "services/backend/tests/test_coach_chat_endpoint.py",
    "services/backend/tests/test_retrieve_memories.py",
    "services/backend/tests/test_narrator_refuses_uncited_numbers.py",
    "apps/mobile/lib/services/coach/coach_chat_api_service.dart",
    "apps/mobile/lib/screens/coach/coach_chat_screen.dart",
    "apps/mobile/test/services/coach_chat_api_service_consent_gate_test.dart",
    "apps/mobile/lib/services/consent/consent_service.dart",
    "apps/mobile/test/screens/coach/coach_consent_gate_flow_test.dart",
    "apps/mobile/lib/screens/debt_prevention/repayment_screen.dart",
    "apps/mobile/test/screens/debt_prevention/repayment_hydration_test.dart",
    "apps/mobile/lib/screens/debt_prevention/debt_ratio_screen.dart",
    "apps/mobile/test/screens/debt_prevention/debt_ratio_hydration_test.dart",
    "apps/mobile/lib/widgets/couple/conjoint_missing_hint.dart",
    "apps/mobile/test/widgets/couple/conjoint_missing_hint_test.dart",
    # PR constants-truth (bead -zaw) : audit factuel variables métier 2026
    "apps/mobile/lib/services/coach/hallucination_detector.dart",
    "apps/mobile/lib/services/financial_core/generated/regulatory_constants.g.dart",
    "apps/mobile/test/retirement_projection_service_test.dart",
    "apps/mobile/test/services/avs_logic_test.dart",
    "apps/mobile/test/services/financial_core/avs_calculator_test.dart",
    "apps/mobile/test/services/financial_core/calculator_forge_test.dart",
    "apps/mobile/test/services/financial_core/golden_couple_integrated_test.dart",
    "apps/mobile/test/services/regulatory_sync_integration_test.dart",
    "services/backend/app/services/fiscal/cantonal_comparator.py",
    "services/backend/app/services/fiscal/sensibilite_3a_service.py",
    "services/backend/app/services/fiscal/civil_status.py",
    "services/backend/app/models/lucidity/_payload.py",
    "services/backend/tests/test_sensibilite_3a_menage.py",
    "services/backend/tests/test_coaching.py",
    "services/backend/tests/test_fiscal_low_nodes.py",
    "services/backend/app/services/regulatory/registry.py",
    "services/backend/tests/fixtures/coach_tools_parity_v1.jsonl",
    "services/backend/tests/test_minimal_profile.py",
    "apps/mobile/lib/services/document_parser/avs_extract_parser.dart",
    "apps/mobile/lib/services/financial_core/avs_calculator.dart",
    "apps/mobile/test/golden/golden_couple_validation_test.dart",
    "services/backend/app/services/couple_optimizer/couple_optimizer.py",
    "services/backend/app/services/document_parser/avs_extract_parser.py",
    "services/backend/app/services/onboarding/minimal_profile_service.py",
    "services/backend/app/services/onboarding/premier_eclairage_selector.py",
    "services/backend/app/services/retirement/avs_estimation_service.py",
    "services/backend/tests/test_golden_julien_lauren.py",
    "services/backend/tests/test_fiscal.py",
    # -jzk : couche-4 top-prompt étendue (helper central IndicatifBanner)
    "apps/mobile/lib/screens/arbitrage/location_vs_propriete_screen.dart",
    "apps/mobile/lib/screens/arbitrage/allocation_annuelle_screen.dart",
    "apps/mobile/lib/screens/arbitrage/rente_vs_capital_screen.dart",
    "apps/mobile/lib/widgets/coach/indicatif_banner.dart",
    "apps/mobile/test/screens/arbitrage/layer4_prompts_extension_test.dart",
    "apps/mobile/test/screens/arbitrage/rvc_layer4_prompts_test.dart",
    "services/backend/tests/test_regulatory_registry.py",
    # PR rvc-single-truth (bead -axj) : parité croisée RvC
    "apps/mobile/test/services/financial_core/rvc_parity_fixture_test.dart",
    "services/backend/tests/test_rvc_parity_fixture.py",
    "tools/fixtures/rvc_parity_v1.json",
    # PR tax-model-v2 (beads -97h/-81n) : modèle fiscal v2 partagé
    "apps/mobile/lib/services/financial_core/income_tax_model_v2.dart",
    "apps/mobile/test/services/rachat_parity_fixture_test.dart",
    "services/backend/app/services/lpp_deep/rachat_echelonne_service.py",
    "services/backend/tests/test_rachat_parity_fixture.py",
    # PR lpp-conversion-canonical (bead -amq) : 4e moteur RvC au modèle v2
    "services/backend/app/services/retirement/lpp_conversion_service.py",
    "services/backend/tests/test_retirement.py",
    "services/backend/app/services/retirement/retirement_projection_service.py",
    "services/backend/tests/fixtures/coach_tools_parity_v1.jsonl",
    "services/backend/tests/test_coach_tools_parity.py",
    "tools/fixtures/rachat_parity_v1.json",
    # PR capital-tax-v2-model (bead -2i2) : modèle capital v2 disponible
    "apps/mobile/test/services/financial_core/capital_tax_parity_fixture_test.dart",
    "services/backend/tests/test_capital_tax_parity_fixture.py",
    "tools/fixtures/capital_tax_parity_v1.json",
    # PR capital-v2-switch (bead -2i2 PR B) : bascule des consommateurs
    "apps/mobile/lib/services/financial_core/tax_calculator.dart",
    "services/backend/app/services/lpp_deep/epl_service.py",
    "services/backend/app/services/mortgage/epl_combined_service.py",
    "apps/mobile/lib/services/financial_core/lpp_calculator.dart",
    "apps/mobile/lib/services/mortgage_service.dart",
    "apps/mobile/lib/services/pillar_3a_deep_service.dart",
    "apps/mobile/lib/services/retirement_service.dart",
    "apps/mobile/test/services/pillar_3a_deep_service_test.dart",
    "apps/mobile/test/services/retirement_service_test.dart",
    "apps/mobile/test/screens/debt_prevention/repayment_g5v_test.dart",
    "apps/mobile/test/services/financial_core/golden_couple_lauren_test.dart",
    "apps/mobile/test/services/financial_core/tax_calculator_test.dart",
    "apps/mobile/test/services/lpp_deep_service_test.dart",
    "apps/mobile/test/services/tax_calculator_extended_test.dart",
    "services/backend/tests/test_calendrier_retraits.py",
    "services/backend/tests/test_lpp_deep.py",
    # PR rachat-79b-window (bead -a6e) : fenêtre art. 79b al. 3 flux live
    "apps/mobile/lib/screens/lpp_deep/rachat_echelonne_screen.dart",
    "apps/mobile/lib/services/lpp_deep_service.dart",
    "apps/mobile/test/screens/lpp_deep/rachat_echelonne_screen_test.dart",
    "apps/mobile/test/services/rachat_echelonne_fenetre_79b_test.dart",
    "apps/mobile/test/test_gaps.json",
    # PR report-honest-spouse (bead -pd4) : fin de la substitution conjoint
    "apps/mobile/lib/services/financial_report_service.dart",
    # PR mortgage-alert-honest (bead -irm) : alerte Tragbarkeit honnête
    "apps/mobile/lib/services/cross_validation_service.dart",
    "apps/mobile/test/services/cross_validation_service_test.dart",
    # PR ac-bareme-officiel (bead -4za) : barème LACI art. 27 corrigé
    "apps/mobile/lib/screens/unemployment_screen.dart",
    "apps/mobile/lib/services/unemployment_service.dart",
    "apps/mobile/lib/widgets/coach/unemployment_counter_widget.dart",
    "apps/mobile/test/services/unemployment_service_test.dart",
    # campagne-B W1 : preuve runtime rendu-calculé triade Travail (job_comparison leg)
    "apps/mobile/test/screens/life_event_screens_additional_smoke_test.dart",
    ".planning/audit/2026-07-w1-travail-triade-runtime-proof.md",
    "tools/checks/mint_variable_contract_extract.py",
    "tools/checks/tests/test_mint_variable_contract_extract.py",
    ".planning/phases/mint-2-0-first-experience-rente-capital/mint-2-0-first-experience-rente-capital-02b-existing-variable-coverage-map-PLAN.md",
    ".planning/phases/mint-2-0-first-experience-rente-capital/mint-2-0-first-experience-rente-capital-02c-variable-contract-lints-implementation-PLAN.md",
    # Tranche verticale firstJob (Phase 1') : spec 12D + flow d'acceptation
    # ROUGE par construction (voir header du flow — hors runners verts).
    ".planning/phases/mint-2-0-first-experience-rente-capital/TRANCHE-FIRSTJOB-SPEC.md",
    # Tier B smoke — cadrage des 18 life events (plan MINT utilisable v2.1,
    # 2026-07-30). Page de cadrage, PAS d'implémentation.
    ".planning/phases/mint-utilisable-tier-b-smoke/00-CADRAGE.md",
    # Vague 2 revue 12D — cadrage clusters ordonnés (registre 12D rafraîchi,
    # 2026-07-31). Page de cadrage/pilotage, PAS d'implémentation.
    ".planning/phases/mint-utilisable-12d-vague2/00-CADRAGE.md",
    # PR calc-registry-freshness (bead -5u4) : gate fraîcheur du registre
    "services/backend/app/calculators/_registry.py",
    "services/backend/tests/test_calc_registry.py",
    # PR married-discount-canton (bead -ku6) : fin du 0.85 uniforme
    "services/backend/app/services/rules_engine.py",
    "services/backend/app/services/arbitrage/rachat_vs_marche.py",
    "services/backend/app/services/arbitrage/calendrier_retraits.py",
    "services/backend/app/services/arbitrage/cross_pillar_service.py",
    "services/backend/tests/test_rules_engine.py",
    "services/backend/tests/test_w16_logic_gaps.py",
    # Lint prescriptions (ADR 2026-07-28-prescriptions U1-U4)
    "services/backend/app/services/coach/prescription_vocab.py",
    "services/backend/tests/test_prescription_vocab.py",
    "tools/checks/product_prescription_lint.py",
    "tools/checks/_baseline_prescription_sites.txt",
    # Purge attribution fortune (ADR 2026-07-28-fortune U1)
    "services/backend/app/services/fiscal/wealth_tax_service.py",
    "apps/mobile/lib/services/wealth_tax_service.dart",
    "services/backend/app/api/v1/endpoints/wealth_tax.py",
    # Fix remploi méthode absolue (ADR 2026-07-28-remplacements P2)
    "services/backend/app/services/housing_sale_service.py",
    "services/backend/tests/test_housing_sale.py",
    "apps/mobile/lib/services/housing_sale_service.dart",
    "apps/mobile/test/services/housing_sale_service_test.dart",
    # LAMal frontalier par pays de résidence (ADR 2026-07-28-remplacements P3)
    # + suppression du champ base_rate mort (ADR 2026-07-28-remplacements P1)
    "services/backend/app/services/expat/frontalier_service.py",
    "services/backend/tests/test_expat.py",
    # Purge de la solidarité AC abolie au 1.1.2023 (LACI art. 90c al. 4) :
    # miroir dart du calcul frontalier (parité py↔dart).
    "apps/mobile/lib/services/expat_service.dart",
    # Cluster 12D V2-2 « Segments risque » : drain i18n Tab 2 expat (LOT 3) +
    # labels charges frontalier + bandes de confiance MTC (D10).
    "apps/mobile/lib/screens/frontalier_screen.dart",
    "apps/mobile/test/screens/expat_v22_i18n_test.dart",
    "apps/mobile/test/screens/frontalier_v22_test.dart",
    ".planning/phases/mint-utilisable-12d-vague2/V2-2-INVENTORY.md",
    # Drain fiscal divorce vers l'étalon (hand-off 2026-07-27 §3.4)
    "services/backend/app/services/divorce_simulator.py",
    "services/backend/tests/test_divorce_simulator.py",
    "services/backend/tests/test_life_events.py",
    # Citation CC des réserves héréditaires (hand-off 2026-07-27 §3.5)
    "services/backend/app/services/coach/bundles/succession_divorce_bundle.py",
    "services/backend/tests/bundles/test_succession_divorce_bundle.py",
    # Drain des taux marginaux vers l'étalon (hand-off 2026-07-27 §3.1b)
    "services/backend/app/services/precision/precision_service.py",
    "services/backend/tests/test_precision.py",
    # ADR des décisions déléguées (panels 2026-07-28)
    ".planning/decisions/2026-07-28-fortune-recalibrage-estv.md",
    ".planning/decisions/2026-07-28-prescriptions-ligne-et-mecanisme.md",
    ".planning/decisions/2026-07-28-remplacements-succession-donation-immo-lamal.md",
    "services/backend/tests/test_calc_diff_harness.py",
    "services/backend/tests/test_cross_platform.py",
    "services/backend/tests/test_estv_oracle.py",
    ".github/workflows/calc-rigor-failure-comment.md",
    "services/backend/tests/fixtures/estv_oracle.SCHEMA.md",
    # Réveil de l'oracle ESTV (capture hors-nœuds + garde anti-partiel).
    "services/backend/tests/fixtures/estv_oracle_2025.jsonl",
    "services/backend/tests/scripts/capture_estv_oracle.py",
    "services/backend/tests/scripts/README.md",
    "services/backend/pyproject.toml",
    # -ku6 : addenda de résolution datés sur les archives de phase 92.5
    # (répertoire déplacé vers phases-archive/ le 2026-07-29)
    ".planning/phases-archive/92.5-mvp-calc-rigor-foundations/92.5-01-differential-harness-PLAN.md",
    ".planning/phases-archive/92.5-mvp-calc-rigor-foundations/92.5-03-estv-oracle-PLAN.md",
    ".planning/phases-archive/92.5-mvp-calc-rigor-foundations/92.5-03-estv-oracle-SUMMARY.md",
    ".planning/phases-archive/92.5-mvp-calc-rigor-foundations/92.5-04-g6-gate-wiring-PLAN.md",
    "apps/mobile/lib/screens/mortgage/affordability_screen.dart",
    "apps/mobile/lib/screens/expat_screen.dart",
    "apps/mobile/lib/screens/household/household_screen.dart",
    "apps/mobile/lib/screens/coach/retirement_dashboard_screen.dart",
    "apps/mobile/lib/models/coach_profile.dart",
    "apps/mobile/test/screens/debt_prevention_screens_smoke_test.dart",
    "services/backend/app/services/arbitrage/rente_vs_capital.py",
    "services/backend/app/api/v1/endpoints/arbitrage.py",
    # -uwv : is_married exposé dans les 4 API retrait capital
    "services/backend/app/api/v1/endpoints/lpp_deep.py",
    "services/backend/app/api/v1/endpoints/mortgage.py",
    "services/backend/app/api/v1/endpoints/retirement.py",
    "services/backend/app/schemas/lpp_deep.py",
    "services/backend/app/schemas/mortgage.py",
    "services/backend/app/schemas/retirement.py",
    "services/backend/tests/test_uwv_married_capital_apis.py",
    # #1095 : recalibrage capital MARIÉ vers l'étalon ESTV (drain du rabais)
    "services/backend/tests/test_capital_marie_calibration.py",
    "services/backend/tests/test_capital_tax_property.py",
    "apps/mobile/test/services/financial_core/withdrawal_sequencing_test.dart",
    # -337 : provenance des 39 clés fiscales du registre
    "services/backend/app/services/regulatory/registry.py",
    "services/backend/tests/test_337_fiscal_provenance.py",
    # -cm4 : migration des 2 proxys heuristiques fiscaux vers v2
    "services/backend/app/services/arbitrage/location_vs_propriete.py",
    "services/backend/tests/test_cm4_proxy_migrations.py",
    # -glq : gardes mécaniques câblées (sentry privacy) + ADR amendé
    "lefthook.yml",
    ".github/workflows/ai-workflow-guards.yml",
    "decisions/ADR-20260419-v2.8-kill-policy.md",
    # compare-v2 : écran comparaison cantonale migré sur le modèle v2
    "services/backend/app/services/fiscal/__init__.py",
    "services/backend/tests/test_compare_v2_identity.py",
    "services/backend/tests/test_fiscal.py",
    "services/backend/app/schemas/arbitrage.py",
    "tools/openapi/mint.openapi.canonical.json",
    "tools/openapi/openapi.json",
    "apps/mobile/lib/services/financial_core/arbitrage_models.dart",
    "apps/mobile/test/services/financial_core/rvc_certificate_receipt_test.dart",
    "apps/mobile/test/services/financial_core/arbitrage_engine_rvc_boundary_test.dart",
    # rente-survivant base légale unifiée (art. 21 al. 1 taux / art. 20a concubin) :
    # le taux 60 % du conjoint était cité art. 19 (conditions) à plusieurs endroits.
    "apps/mobile/lib/widgets/coach/survivor_pension_widget.dart",
    "apps/mobile/test/services/financial_core/arbitrage_engine_fields_test.dart",
    "apps/mobile/test/services/financial_core/arbitrage_engine_hero_fields_test.dart",
    "services/backend/app/services/rag/llm_client.py",
    "services/backend/app/api/v1/endpoints/anonymous_chat.py",
    "services/backend/app/api/v1/endpoints/coach_chat.py",
    "services/backend/app/services/rag/orchestrator.py",
    "services/backend/app/services/llm/bedrock_client.py",
    "apps/mobile/test/services/financial_core/arbitrage_capital_epuise_age_test.dart",
    "apps/mobile/test/services/financial_core/withdrawal_sequencing_gendered_refage_test.dart",
    ".gitignore",
    ".planning/phases/remediation-audit-2026-07/CONTEXT.md",
    ".planning/phases/remediation-audit-2026-07/AUTHORIZED_FILES.md",
    ".planning/phases/remediation-audit-2026-07/BACKLOG-DEV-VERIFIED.html",
    # Clôture du P0 T11-F01 (/auth/apple/verify) : réel au SHA gelé, déjà
    # corrigé dans dev (vérification JWKS) + durcissement e-mail non vérifié.
    ".planning/audit-etat-des-lieux-2026-07/T11-F01-apple-verify-cloture.md",
    # Résiduel actuariel P1 (#1144) : contrat de statut de l'avoir LPP —
    # verdict d'ambiguïté + plan (double comptage rente retraité), page d'audit.
    ".planning/audit-etat-des-lieux-2026-07/contrat-avoir-lpp-retraite.md",
    # --- end remediation audit 2026-07 ---
    "apps/mobile/lib/app.dart",
    "apps/mobile/lib/models/screen_return.dart",
    "apps/mobile/lib/providers/auth_provider.dart",
    # --- Tier B smoke Lot B5 : seed E2E cross_border / frontalier_geneve
    # (persona manquante bloquant le smoke C2 par cadrage
    # mint-utilisable-tier-b-smoke). kReleaseMode-gardée, hors prod. ---
    "apps/mobile/lib/services/coach/coach_profile_seeds.dart",
    "apps/mobile/test/services/coach_profile_seeds_test.dart",
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
    # --- Tranche firstJob PR-D: /home -> /first-job life-event entry ---
    "apps/mobile/lib/screens/aujourdhui/home_life_events.dart",
    "apps/mobile/lib/widgets/life_event_suggestions.dart",
    "apps/mobile/test/screens/aujourdhui/home_life_events_test.dart",
    "apps/mobile/test/screens/aujourdhui/aujourdhui_first_job_entry_test.dart",
    "apps/mobile/test/widgets/life_event_suggestions_home_entry_test.dart",
    "apps/mobile/lib/screens/budget/budget_setup_screen.dart",
    "apps/mobile/test/screens/budget_setup_screen_test.dart",
    "apps/mobile/lib/screens/debug/debug_mint2_account_claim_screen.dart",
    "apps/mobile/lib/screens/mon_argent/mon_argent_screen.dart",
    "apps/mobile/lib/screens/onboarding/data_block_enrichment_screen.dart",
    "apps/mobile/lib/screens/onboarding/mvp_wedge/onboarding_shell_screen.dart",
    "apps/mobile/lib/screens/coach/chat_as_verb_demo_screen.dart",
    "apps/mobile/lib/screens/coach/coach_chat_screen.dart",
    "apps/mobile/lib/screens/coach/retirement_dashboard_screen.dart",
    # P2 #1144 — libellé honnête continuité vs taux de remplacement (retraité).
    "apps/mobile/lib/widgets/coach/retirement_hero_zone.dart",
    "apps/mobile/test/screens/coach/retirement_income_continuity_label_test.dart",
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
    "services/backend/app/services/coach/hallucination_detector.py",
    "services/backend/tests/test_hallucination_guard_wired.py",
    "services/backend/app/api/v1/endpoints/auth.py",
    "services/backend/app/schemas/auth.py",
    "services/backend/app/services/coach/compliance_guard.py",
    "services/backend/app/services/coach/structured_reasoning.py",
    "services/backend/app/services/coach/_route_intents_generated.py",
    # codex/journey-os-coach-intent-couple-forcage (2026-08) : forçage de
    # get_couple_optimization sur l'intent couple / prévoyance-à-deux
    # (coach_chat.py déjà whitelisté ci-dessus). Ajout test-only.
    "services/backend/tests/test_coach_couple_intent_force.py",
    "services/backend/app/services/llm/router.py",
    "services/backend/app/services/rag/guardrails.py",
    "services/backend/app/services/rag/hybrid_search_service.py",
    "services/backend/app/services/rag/llm_client.py",
    "services/backend/app/services/rag/orchestrator.py",
    "services/backend/app/services/llm/bedrock_client.py",
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
    # P0 2026-08-03 : cycle de vie du compte (suppression nLPD complète +
    # reconnexion Apple propre après suppression).
    "services/backend/tests/test_auth_apple_lifecycle.py",
    ".planning/audit/2026-08-03-nlpd-suppression-compte-apple.md",
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
    "tools/simulator/flows/travail_triad.yaml",
    "tools/simulator/flows/famille_parcours.yaml",
    "tools/simulator/flows/logement_succession_parcours.yaml",
    "tools/simulator/flows/parcours_secondaires.yaml",
    ".planning/audit/2026-07-life-event-screens-a11y-gap.md",
    # a11y ILLOG-02 contract : screen-root Semantics sur 3 écrans life-event premium
    "apps/mobile/lib/screens/disability/disability_gap_screen.dart",
    # Drain 12D V2-2 : service invalidité UNIQUE (fin du doublon 3-têtes).
    # `DisabilityService` (domain) miroir de disability_gap_service.py ; les 3
    # écrans invalidité consomment le service ; goldens de parité + widget.
    "apps/mobile/lib/domain/disability_gap_calculator.dart",
    "apps/mobile/lib/screens/disability/disability_insurance_screen.dart",
    "apps/mobile/lib/screens/disability/disability_self_employed_screen.dart",
    "apps/mobile/test/domain/disability_service_parity_test.dart",
    "apps/mobile/test/screens/disability/disability_screens_service_test.dart",
    "apps/mobile/lib/screens/deces_proche_screen.dart",
    "apps/mobile/test/screens/deces_gate_test.dart",
    "apps/mobile/lib/screens/demenagement_cantonal_screen.dart",
    "apps/mobile/test/screens/demenagement_gate_test.dart",
    "apps/mobile/test/screens/expat_gate_test.dart",
    "apps/mobile/test/screens/life_event_premium_a11y_test.dart",
    "tools/checks/baselines/prefer_mint_cta.baseline.txt",
    "tools/simulator/flows/maestro-perfect-set/flow_row24_privacy_control_runtime.yaml",
    "tools/simulator/flows/maestro-perfect-set/flow_jos001_account_lifecycle_seeded_delete.yaml",
    "tools/simulator/flows/maestro-perfect-set/flow_jos004_coach_advice_turn_runtime.yaml",
    "tools/simulator/flows/maestro-perfect-set/flow_landing_to_diagnostic_onboarding.yaml",
    "tools/simulator/flows/maestro-perfect-set/_fragment_cold_launch_to_aujourdhui.yaml",
    "tools/simulator/flows/maestro-perfect-set/flow_hardgate_expat_us.yaml",
    "tools/simulator/flows/maestro-perfect-set/flow_hero_marge_fiscale_3a.yaml",
    "tools/simulator/flows/maestro-perfect-set/flow_mint2_first_experience_rente_capital_entry.yaml",
    "tools/simulator/flows/maestro-perfect-set/flow_row22_profile_dossier_production_profile.yaml",
    # AX pilote (ADR 2026-07-30) : re-gate des ancres d'arrivee sur ids INTERNES
    # apres retrait des Semantics RACINE (coach_chat_screen / rente_vs_capital_screen
    # effondraient l'arbre AX iOS 26.2). Substitution mecanique arrival-gate ->
    # coach_input_field / rvc_route_state / titre AppBar. Cf. diagnostic
    # project_ios26_ax_tree_collapse.
    "tools/simulator/flows/maestro-perfect-set/flow_mint2_content_quality_surfaces.yaml",
    "tools/simulator/flows/maestro-perfect-set/flow_mon_argent_budget_setup_spine.yaml",
    "tools/simulator/flows/maestro-perfect-set/flow_money_trust_chain_3a_contributing.yaml",
    "tools/simulator/flows/maestro-perfect-set/flow_money_trust_chain_budget_mon_argent_rapport_coach.yaml",
    "tools/simulator/flows/maestro-perfect-set/flow_row16_coach_route_to_screen_runtime.yaml",
    "tools/simulator/flows/maestro-perfect-set/flow_row20_coach_history_resume.yaml",
    "tools/simulator/flows/maestro-perfect-set/flow_row22_primary_screen_visual_crawl.yaml",
    "tools/simulator/flows/maestro-perfect-set/flow_row23_independent_no_lpp_coach_chat_runtime.yaml",
    "tools/simulator/flows/regression/bug__P004__overlay_populated_on_open.yaml",
    "tools/simulator/flows/regression/bug__S005__landing_anonymous_cta_to_home.yaml",
    "tools/simulator/flows/salvage01_retraite_onboarding_coach.yaml",
    # Tranche firstJob : flow d'acceptation CORE (promu _red->CORE, ADR AX iOS
    # 26.2 Etape 2, 2026-07-30) — seed jeune_diplome_zurich, tier sweep dedie.
    # Debloque par la migration SliverAppBar->AppBar (arbre AX stable au scroll),
    # VERT bout en bout (maestro hierarchy iPhone 16e/26.2 cite).
    "tools/simulator/flows/maestro-perfect-set/flow_firstjob_tranche_acceptance_seeded.yaml",
    # Tier B smoke lot B1 Famille (cadrage mint-utilisable-tier-b-smoke) : 4 flows
    # seedes julien_swiss remplacant la dependance aux legacy deeplink racine.
    # Runtime iPhone 16e/26.2 : C1/C3/C4/C5 verts, C2 rouge documente (sortie
    # calculee gatee P2 sur seed celibataire — defaut ecran) — table C1-C5 en PR.
    "tools/simulator/flows/maestro-perfect-set/flow_tierb_famille_mariage.yaml",
    "tools/simulator/flows/maestro-perfect-set/flow_tierb_famille_naissance.yaml",
    "tools/simulator/flows/maestro-perfect-set/flow_tierb_famille_divorce.yaml",
    "tools/simulator/flows/maestro-perfect-set/flow_tierb_famille_concubinage.yaml",
    # Tier B smoke lot B1 Famille SEEDÉ (famille_bern, #1135) : variantes assertant
    # le RÉSULTAT C2 chiffré (ancre <event>-result) débloqué par le seed couple/enfant.
    "tools/simulator/flows/maestro-perfect-set/flow_tierb_famille_seeded_mariage.yaml",
    "tools/simulator/flows/maestro-perfect-set/flow_tierb_famille_seeded_naissance.yaml",
    "tools/simulator/flows/maestro-perfect-set/flow_tierb_famille_seeded_divorce.yaml",
    "tools/simulator/flows/maestro-perfect-set/flow_tierb_famille_seeded_concubinage.yaml",
    # Preuve d'ancre C1 (Semantics identifier <event>-anchor) des 4 ecrans famille.
    "apps/mobile/test/screens/tierb_famille_anchors_test.dart",
    # Preuve d'ancre C2 (Semantics identifier <event>-result) sous seed famille_bern.
    "apps/mobile/test/screens/tierb_famille_seeded_result_anchors_test.dart",
    # Tier B smoke lot B2 Travail (julien_swiss salarie) : flows seedes newJob /
    # jobLoss / selfEmployment ciblant l'ecran-event canonique. La persona salariee
    # atteint C2 chiffre sur les 3 (indemnite chomage / verdict compare / perte Jour J).
    "tools/simulator/flows/maestro-perfect-set/flow_tierb_travail_job_comparison.yaml",
    "tools/simulator/flows/maestro-perfect-set/flow_tierb_travail_unemployment.yaml",
    "tools/simulator/flows/maestro-perfect-set/flow_tierb_travail_independant.yaml",
    # Preuve d'ancres C1/C2/C4 (Semantics identifier <event>-anchor/-result/-back)
    # des 3 ecrans Travail sous seed julien_swiss.
    "apps/mobile/test/screens/tierb_travail_anchors_test.dart",
    # Tier B smoke lot B3 Logement & Patrimoine (julien_swiss) : flows seedes
    # housingPurchase / inheritance / housingSale / donation. hypotheque +
    # succession chiffrent au repos ; housing-sale + donation apres « Calculer »
    # (donation gate fiscal ouvert seed-alone via le canton du profil).
    "tools/simulator/flows/maestro-perfect-set/flow_tierb_logement_hypotheque.yaml",
    "tools/simulator/flows/maestro-perfect-set/flow_tierb_logement_succession.yaml",
    "tools/simulator/flows/maestro-perfect-set/flow_tierb_logement_housing_sale.yaml",
    "tools/simulator/flows/maestro-perfect-set/flow_tierb_logement_donation.yaml",
    # Ancre C1/C2/C4 : ecran succession (les 3 autres ecrans B3 sont deja dans ALLOW).
    "apps/mobile/lib/screens/coach/succession_patrimoine_screen.dart",
    # Preuve d'ancres C1/C2/C4 des 4 ecrans Patrimoine sous seed julien_swiss.
    "apps/mobile/test/screens/tierb_logement_anchors_test.dart",
    # Tier B smoke — lots B5 (crise / international) + retraite : 3 flows seedes
    # (debtCrisis=julien_swiss, countryMove=julien_swiss [frontalier_geneve est
    # waitlisted par la cohorte produit], retirement=retraite_lausanne). Les 3
    # ecrans-evenements sont deja dans ALLOW.
    "tools/simulator/flows/maestro-perfect-set/flow_tierb_debt_ratio.yaml",
    "tools/simulator/flows/maestro-perfect-set/flow_tierb_expat.yaml",
    "tools/simulator/flows/maestro-perfect-set/flow_tierb_retraite.yaml",
    # Preuve d'ancres C1/C2/C4 des 3 ecrans B5+retraite sous leurs seeds.
    "apps/mobile/test/screens/tierb_b5_anchors_test.dart",
    # Tier B smoke lot B4 Décès/Santé/Mobilité (julien_swiss) : flows seedes
    # deathOfRelative / disability / cantonMove. deces/demenagement = AppBar FIXE
    # (deces NON-VIDE au repos, chiffré CHF touch-only prouve au widget test ;
    # demenagement chiffre apres 2 touches id-ciblees) ; invalidite = motif
    # firstJob (CustomScrollView + SliverAppBar + wrapper racine) → C5/C1 rouges
    # ATTENDUS = SIGNAL AX du cadrage (dette AX, non masque). Les 3 ecrans B4 sont
    # deja dans ALLOW ci-dessus (bloc a11y ILLOG-02).
    "tools/simulator/flows/maestro-perfect-set/flow_tierb_b4_deces.yaml",
    "tools/simulator/flows/maestro-perfect-set/flow_tierb_b4_demenagement.yaml",
    "tools/simulator/flows/maestro-perfect-set/flow_tierb_b4_invalidite.yaml",
    # Preuve d'ancres C1/C2/C4 des 3 ecrans B4 sous seed julien_swiss.
    "apps/mobile/test/screens/tierb_b4_anchors_test.dart",
    # Runner sweep : nouveau tier `firstjob` (seed dedie, hors sweep normal).
    "tools/simulator/maestro_sweep.sh",
    "tools/simulator/journey_os_runtime_replay.sh",
    "tools/claude_review.py",
    "tools/claude_review.sh",
    "tools/checks/active_context_guard.py",
    "tools/checks/education_facts_check.py",
    "legal/APP_STORE_PRIVACY_LABELS.md",
    # cluster B W0 : Retroactive3a — retrait du faux chevron (façade sans câblage)
    "apps/mobile/test/screens/pillar_3a_deep/retroactive_3a_screen_test.dart",
    # cluster B W0 : TransactionList — filtre période mort câblé (façade contrôle)
    "apps/mobile/lib/screens/open_banking/transaction_list_screen.dart",
    "apps/mobile/test/screens/open_banking/transaction_list_screen_test.dart",
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
    # P5 gains immobiliers calibres (ADR 2026-07-28, branche
    # codex/journey-os-gains-immo-calibres) : drainage de la table fabriquee
    # TAUX_PLUS_VALUE_IMMOBILIERE vers l'etalon ZH/VD/GE.
    "services/backend/app/services/fiscal/gains_immobiliers_calibres.py",
    "services/backend/tests/test_gains_immobiliers_calibres.py",
    "services/backend/app/services/housing_sale_service.py",
    "services/backend/app/schemas/life_events.py",
    "services/backend/app/api/v1/endpoints/life_events.py",
    "services/backend/tests/test_housing_sale.py",
    "apps/mobile/lib/services/housing_sale_service.dart",
    "apps/mobile/test/services/housing_sale_service_test.dart",
    "apps/mobile/lib/screens/housing_sale_screen.dart",
    # Socle succession/donation (ADR 2026-07-28 P4) : drain des tables de
    # taux plats succession+donation vers le socle 3-champs ESTV 1.1.2025
    # (statut / plage sourcée / mécanismes), backend + miroirs Dart.
    "services/backend/app/services/fiscal/succession_donation_socle.py",
    "services/backend/tests/test_succession_donation_socle.py",
    "services/backend/app/services/succession_simulator.py",
    "services/backend/tests/test_succession_simulator.py",
    "services/backend/app/services/donation_service.py",
    "services/backend/tests/test_donation.py",
    "services/backend/tests/test_donation_service.py",
    "services/backend/tests/test_life_events.py",
    "services/backend/app/schemas/life_events.py",
    "services/backend/app/api/v1/endpoints/life_events.py",
    "apps/mobile/lib/services/succession_donation_socle.dart",
    "apps/mobile/test/services/succession_donation_socle_test.dart",
    "apps/mobile/lib/services/donation_service.dart",
    "apps/mobile/test/services/donation_service_test.dart",
    # --- LOT-3 réécriture prescriptions produit DART (ADR 2026-07-28-prescriptions) ---
    "apps/mobile/lib/models/age_band_policy.dart",
    "apps/mobile/lib/models/clarity_state.dart",
    "apps/mobile/lib/services/coaching_service.dart",
    "apps/mobile/lib/services/first_job_service.dart",
    "apps/mobile/lib/services/report/report_builder.dart",
    "apps/mobile/lib/widgets/coach/disability_countdown_widget.dart",
    # LOT-2 réécriture prescriptions produit BACKEND (ADR 2026-07-28-prescriptions)
    "services/backend/app/routes/wizard.py",
    "services/backend/app/services/coach/coach_tools.py",
    "services/backend/app/services/coaching_engine.py",
    "services/backend/app/services/coverage_checklist_service.py",
    "services/backend/app/services/educational_content_service.py",
    "services/backend/app/services/first_job/onboarding_service.py",
    "services/backend/app/services/gender_gap_service.py",
    "services/backend/app/services/job_comparator.py",
    "services/backend/app/services/pillar_3a_deep/provider_comparator_service.py",
    "services/backend/app/services/precision/precision_service.py",
    # LOT-1 réécriture prescriptions produit ARB (ADR 2026-07-28-prescriptions)
    # — impératifs d'achat 3a/assurance drainés vers des actes de lucidité.
    "apps/mobile/lib/l10n/app_fr.arb",
    "apps/mobile/lib/l10n/app_en.arb",
    "apps/mobile/lib/l10n/app_de.arb",
    "apps/mobile/lib/l10n/app_es.arb",
    "apps/mobile/lib/l10n/app_it.arb",
    "apps/mobile/lib/l10n/app_pt.arb",
    "apps/mobile/lib/l10n_regional/app_regional_vs.arb",
    "apps/mobile/lib/l10n/app_localizations.dart",
    "apps/mobile/lib/l10n/app_localizations_fr.dart",
    "apps/mobile/lib/l10n/app_localizations_en.dart",
    "apps/mobile/lib/l10n/app_localizations_de.dart",
    "apps/mobile/lib/l10n/app_localizations_es.dart",
    "apps/mobile/lib/l10n/app_localizations_it.dart",
    "apps/mobile/lib/l10n/app_localizations_pt.dart",
    # Réconciliation plans 2026-07-29 : blocs de clôture datés sur les
    # artefacts principaux des 8 phases de-facto closes + wiki lint/INDEX.
    ".planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-CONTEXT.md",
    ".planning/phases/mint-data-spine-plan-vivant-v1/CONTEXT.md",
    ".planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-CONTEXT.md",
    ".planning/phases/mint-grounded-coach-m1/mint-grounded-coach-m1-CONTEXT.md",
    ".planning/phases/mint-illogism-fixes/mint-illogism-fixes-CONTEXT.md",
    ".planning/phases/01.5-archetype-hard-gate-fatca/01.5-CONTEXT.md",
    ".planning/phases/wave-1c-coach-tool-dispatch-rca/wave-1c-CONTEXT.md",
    ".planning/phases/97-mvp-parfait-maestro-full-power-maestro-driven-on-device-grou/97-CONTEXT.md",
    "tools/checks/wiki_lint.py",
    ".planning/INDEX.md",
    # P1 triage AnnAssign (#1095) : purge du taux marginal cantonal fabriqué
    # injecté au coach par le RAG. Le taux dépend du revenu — le coach est
    # dirigé vers l'étalon fiscal (cantonal_comparator.estimate_marginal_rate)
    # plutôt que de recevoir un scalaire cantonal démenti par l'écran.
    # Second volet : la directive n'est mandatée que si l'outil fiscal est
    # réellement atteignable dans la requête (rag.py ne relaie que les tools
    # annoncés par le client) — sinon variante sans outil + renvoi simulation.
    "services/backend/app/services/rag/cantonal_knowledge.py",
    "services/backend/tests/test_cantonal_knowledge.py",
    "services/backend/tests/test_rag_s67_wiring.py",
    "services/backend/app/api/v1/endpoints/rag.py",
    # PR-B MoneyTruthReceipt v1 (tranche firstJob, SPEC TRANCHE-FIRSTJOB §4/§6) :
    # contrat de vérité chiffrée backend + miroir Dart + fixtures de parité
    # cross-language (py<->dart). Receipt INTERNE (portage API = PR-E).
    "services/backend/app/models/lucidity/__init__.py",
    "services/backend/app/models/lucidity/money_truth_receipt.py",
    "services/backend/tests/test_money_truth_receipt.py",
    "services/backend/tests/test_money_truth_receipt_parity.py",
    "apps/mobile/lib/services/financial_core/money_truth_receipt.dart",
    "apps/mobile/test/services/financial_core/money_truth_receipt_test.dart",
    "apps/mobile/test/services/financial_core/money_truth_receipt_parity_test.dart",
    "tools/fixtures/money_truth_receipt_v1.json",
    # PR-B addendum (revue Codex) : correction légale AC — le pour-cent de
    # solidarité (>148'200) a été aboli au 1.1.2023 ; test firstJob adapté.
    "apps/mobile/test/services/first_job_service_test.dart",
    # PR-F états réseau/vide/offline + anti-critère (SPEC TRANCHE-FIRSTJOB
    # §2.3/A4) : indicateur de chargement borné sur /first-job, dégradation
    # coach NOMMÉE et re-tentable (`coach-offline-degradation`), cohérence
    # checklist « premier » emploi (items libre passage gatés sur avoir LPP
    # antérieur). ChatMessage porte l'ancre a11y transitoire ; SystemMessageBubble
    # rend l'état + le retry. Le net first-job reste L1 (survit staging coupé).
    "apps/mobile/lib/services/coach_llm_service.dart",
    "apps/mobile/test/screens/first_job_states_test.dart",
    "apps/mobile/test/widgets/coach/system_message_bubble_offline_test.dart",
    # PR-F addendum (revue Codex, P1) : la checklist conditionnelle change de
    # taille (2↔4 items) pendant que le State persiste → RangeError sans
    # `didUpdateWidget` qui re-dimensionne `_checked` en préservant les cochages
    # par identité (`legalRef`).
    "apps/mobile/lib/widgets/coach/job_change_checklist_widget.dart",
    # PR-E (E1) handoff /first-job -> coach porteur du MoneyTruthReceipt
    # (tranche firstJob, SPEC TRANCHE-FIRSTJOB §4.3) : store/resolve backend
    # owner-scoped (idempotence + accès croisé + pending + TTL) + câblage
    # coach (CoachChatRequest reçoit receiptId/inputsHash, résolution
    # server-side). Portage API exposé => regen OpenAPI canonical + brut.
    "services/backend/app/models/money_truth_receipt_record.py",
    "services/backend/app/services/lucidity/__init__.py",
    "services/backend/app/services/lucidity/receipt_store.py",
    "services/backend/app/schemas/money_truth_receipt_api.py",
    "services/backend/app/api/v1/endpoints/lucidity_receipts.py",
    "services/backend/app/api/v1/router.py",
    "services/backend/app/schemas/coach_chat.py",
    "services/backend/tests/test_money_truth_receipt_store.py",
    "services/backend/alembic/versions/p126_money_truth_receipts.py",
    # PR-E (E2) mobile — CTA firstjob-ask-coach (RED-2) + propagation
    # receiptId/inputsHash au backend via l'entrée coach (SPEC §1 T5 / §4.3).
    "apps/mobile/lib/models/coach_entry_payload.dart",
    "apps/mobile/lib/services/coach/e2e_coach_route_fixture.dart",
    "apps/mobile/test/screens/first_job_ask_coach_cta_test.dart",
    # PR-E (E2, revue Codex P1) — fermeture de la façade du handoff : store
    # POST du receipt AVANT la nav (ceinture 1) + receiptInputs dans la requête
    # coach (ceinture 2). Le coach grounde vraiment (resolved OU pending).
    "apps/mobile/lib/services/coach/money_truth_receipt_api_service.dart",
    "apps/mobile/test/services/money_truth_receipt_handoff_test.dart",
    # PR-E (revue Codex CI) — mocks OrchestratorChatFn existants mis à jour à la
    # signature étendue (receiptId/inputsHash/receiptInputs) + heads alembic
    # attendus incluent p126.
    "apps/mobile/test/services/coach_context_packet_payload_test.dart",
    # V2-4 (cluster Retraite deep + receipt) — propagation du MoneyTruthReceipt
    # firstJob → retirement_dashboard + rente_vs_capital : chaque écran scelle son
    # chiffre L1 affiché en receipt et le porte au coach (CTA retraite-ask-coach /
    # rvc-ask-coach). Producteurs + CTA + parité écran↔receipt.
    "apps/mobile/test/services/forecaster_retirement_receipt_test.dart",
    "apps/mobile/test/services/financial_core/rvc_money_truth_receipt_test.dart",
    "apps/mobile/test/screens/coach/retirement_ask_coach_cta_test.dart",
    "apps/mobile/test/screens/arbitrage/rvc_ask_coach_cta_test.dart",
    # Phase 3' — harnais de parité coach × MoneyTruthReceipt contre STAGING réel
    # (SPEC TRANCHE-FIRSTJOB §4.3 / §4.4). Test integration_staging skippé par
    # défaut (opt-in MINT_STAGING_PARITY=1) : rejoue profil firstJob × questions
    # chiffrées, grade la grille 8 points côté client, isole la casse de chaîne.
    "services/backend/tests/test_coach_receipt_parity_staging.py",
    "services/backend/pytest.ini",
    # P0 #1114 — consommation du MoneyTruthReceipt dans le contexte/prompt coach
    # (SPEC TRANCHE-FIRSTJOB §4.3) : le receipt résolu/pending atteint désormais
    # le system prompt via CoachContext.money_truth_receipt + bloc de grounding,
    # et la valeur grounded est exemptée du gate citations (extract_gated_
    # number_tokens). Fermeture de la façade « clé écrite une fois, lue zéro ».
    "services/backend/app/services/coach/coach_models.py",
    "services/backend/app/services/coach/citation_parser.py",
    "services/backend/tests/coach/test_coach_receipt_grounding.py",
    # P0 #1114 (suite, 2026-07-30) — raccourci DÉTERMINISTE du MoneyTruthReceipt
    # sur le handoff /first-job : le narrateur LLM ne rendait pas la valeur
    # (grounding noyé + dérivés gate-rejetés -> FALLBACK, parité staging 0/8), on
    # rend la valeur canonique sans LLM ni gate quand le tour porte un receipt
    # résolu + une question « salaire net ». Test du chemin LIVE (endpoint réel).
    "services/backend/tests/coach/test_coach_receipt_deterministic.py",
    # P0 #1118 (hotfix, 2026-07-30) — le raccourci déterministe faisait 500 sur
    # staging : banned_terms_runtime.py résolvait son vocabulaire LSFin via
    # `parents[5]` (IndexError sous Railway WORKDIR=/app + `tools/` hors image).
    # Résolution de racine robuste au conteneur (belt 1 marqueur borné, belt 2
    # copie inline packagée côté app) + fail-closed du scan dans coach_chat.
    "services/backend/app/services/encryption/banned_terms_runtime.py",
    "services/backend/tests/test_banned_terms_runtime_container.py",
    "services/backend/tests/test_compliance_wording.py",
    # P0 #1120 (résidu, 2026-07-30) — rendu PENDING déterministe : sur le chemin
    # pending (receiptInputs présents, receipt non résolu) + question « net », le
    # narrateur retombait sur le fallback nu « Je n'ai pas cette donnée »
    # (violation douce SPEC §4.3:242-245). On rend un accusé de réception
    # déterministe depuis les inputs VALIDÉS (allowlist #1116), sans forger de
    # net (décision Reading A), sans LLM ni gate. Même patron que #1118.
    "services/backend/tests/coach/test_coach_receipt_pending_deterministic.py",
    # fix(l10n) OLP art. 10 (2026-07-30) — base légale de la police de libre
    # passage corrigée (OPP2 art. 10 = devoir d'info employeur ≠ formes de
    # maintien ; formes = OLP art. 10, épargne-titres = OLP art. 19a). Écran
    # (via ARB) + widget partagé (disclaimer extrait en ARB) + carte indépendant
    # (institution supplétive → LFLP art. 4 al. 2).
    "apps/mobile/lib/widgets/coach/lpp_rescue_widget.dart",
    "apps/mobile/lib/screens/independant_screen.dart",
    "apps/mobile/test/widgets/coach/lpp_rescue_widget_test.dart",
    # fix(i18n) résidus FR (codex/journey-os-fr-residuals) : les LppTransferOption
    # passés par independant_screen au widget partagé portaient label/description/
    # legalRef en FR codé en dur (dette « débit du CALLER » #1190) → extraits en
    # ARB 6 langues. Preuve de vraie localisation (EN-locale) dans ce test dédié.
    "apps/mobile/test/screens/independant_lpp_rescue_i18n_test.dart",
    # Tranche AX 3 (ADR 2026-07-30, patron #1127/#1140/#1146) : migration
    # SliverAppBar → AppBar classique fixe sur 7 ecrans a route poussee
    # (CustomScrollView, barre titre-seule, sans expandedHeight/flexibleSpace).
    # conversation_history retire en plus son wrapper Semantics racine
    # `coach_history_screen` (double frontiere ModalRoute). debt_ratio +
    # repayment deja dans ALLOW ; flows row20 + debt_ratio deja dans ALLOW,
    # re-armes (row20 gate sur ancre interne, debt_ratio back par id).
    "apps/mobile/lib/screens/document_scan/document_scan_screen.dart",
    "apps/mobile/lib/screens/document_scan/avs_guide_screen.dart",
    "apps/mobile/lib/screens/document_scan/extraction_review_screen.dart",
    "apps/mobile/lib/screens/debt_prevention/help_resources_screen.dart",
    "apps/mobile/lib/screens/coach/conversation_history_screen.dart",
    "apps/mobile/test/screens/coach/conversation_history_screen_test.dart",
    # --- D4 vérités (2026-07-31) : la landing dit vrai (« Éclaire ma situation »
    # remplace « Parle à Mint », qui promettait une conversation que le flux ne
    # délivre pas — /start → /onb, cold-open chat anonyme retiré) + le coach
    # guide l'entrée (3 chips de démarrage adaptées au profil sous l'ouverture).
    # Le renommage du libellé propage aux tests widget + flows Maestro qui
    # tapaient « Parle à Mint » par texte. ---
    "apps/mobile/test/screens/core_app_screens_smoke_test.dart",
    "apps/mobile/test/screens/landing_screen_test.dart",
    "apps/mobile/test/widget_test.dart",
    "apps/mobile/test/screens/coach/coach_starter_suggestions_test.dart",
    "tools/simulator/walker.sh",
    "tools/simulator/flows/e2e/flow_e2e_new_user_full_journey.yaml",
    "tools/simulator/flows/julien_swiss.yaml",
    "tools/simulator/flows/lauren_expat_us.yaml",
    "tools/simulator/flows/maestro-perfect-set/flow_b14_debt_intent_no_mortgage.yaml",
    "tools/simulator/flows/maestro-perfect-set/flow_b15_concrete_facts_chips.yaml",
    "tools/simulator/flows/maestro-perfect-set/flow_diagnostic_situation_scene.yaml",
    "tools/simulator/flows/maestro-perfect-set/flow_extractor_captures_age_canton.yaml",
    "tools/simulator/flows/maestro-perfect-set/flow_g2_julien_walkthrough.yaml",
    "tools/simulator/flows/maestro-perfect-set/flow_landing_to_register.yaml",
    "tools/simulator/flows/maestro-perfect-set/flow_narrator_refuses_uncited_numbers.yaml",
    # codex/journey-os-d5-evolution : socle « évolution visible » (North Star
    # D5). Historise le score de confiance 4 axes (un point daté / jour) pour
    # rendre possible la courbe « toi d'avant vs toi maintenant ». Stockage
    # local pur, câblé au contrat de reset. Widget de courbe = unité suivante.
    "apps/mobile/lib/models/confidence_point.dart",
    "apps/mobile/lib/services/confidence/confidence_history_service.dart",
    "apps/mobile/lib/providers/coach_profile_provider.dart",
    "apps/mobile/lib/services/report_persistence_service.dart",
    "apps/mobile/test/services/confidence/confidence_history_service_test.dart",
    "apps/mobile/test/providers/coach_profile_provider_confidence_history_test.dart",
    "docs/data-flow.md",
    ".planning/design/2026-07-31-d5-confidence-curve.md",
    # feat/d5-confidence-curve : la courbe « toi d'avant vs toi maintenant »
    # rendue visible en tête de « Ton histoire » (aujourdhui_screen). Lit le
    # socle ci-dessus ; monotonie running-max au rendu (le service reste brut).
    "apps/mobile/lib/widgets/aujourdhui/confidence_evolution_card.dart",
    "apps/mobile/test/widgets/aujourdhui/confidence_evolution_card_test.dart",
    # codex/journey-os-p0-gate-3a : P0 device (2026-08-03) — le gate dette
    # (SafeMode, isInDebtCrisis Signal C) verrouillait à tort les écrans 3a
    # profonds pour un profil salarié PARTIEL (épargne/charges non saisies lues
    # comme coussin nul + base de charges fabriquée). Correctif faux positif +
    # le mur explique (provenance), laisse corriger la donnée et offre toujours
    # « Continuer quand même ». coach_profile.dart et les ARB sont déjà couverts.
    "apps/mobile/lib/widgets/common/safe_mode_gate.dart",
    "apps/mobile/test/models/coach_profile_safe_mode_test.dart",
    "apps/mobile/test/safe_mode_gate_test.dart",
    # Même P0 : le fix du faux positif ouvre le gate pour un profil partiel et
    # DÉMASQUE deux bugs pré-existants de l'écran rachat échelonné (overflow
    # horizontal 320pt iPhone SE + plan annuel 79b sous le pli d'un
    # CustomScrollView paresseux). Correctif responsive + a11y (état sélectionné,
    # cible 44pt) + test qui scrolle vers le contenu paresseux réel.
    "apps/mobile/lib/screens/lpp_deep/rachat_echelonne_screen.dart",
    "apps/mobile/test/screens/lpp_deep/rachat_echelonne_screen_test.dart",
    # codex/journey-os-sweep-320pt-safemode : extension systémique de la leçon
    # #1177. Le fix du faux positif ouvre le SafeModeGate pour un profil partiel
    # et rend PLEINE HAUTEUR les autres écrans 3a/LPP profonds — jamais couverts
    # par un test 320pt. Sweep : overflows RenderFlex horizontaux confirmés puis
    # corrigés (Expanded/Flexible sur libellés, isExpanded sur dropdown, FittedBox
    # sur chiffres, Flexible sur colonnes). epl_screen n'était pas encore
    # whitelisté ; les autres écrans le sont déjà (lignes ci-dessus). Le widget
    # partagé LppRescueWidget (hors gate, i18n en dette) est documenté, non touché.
    "apps/mobile/lib/screens/lpp_deep/epl_screen.dart",
    "apps/mobile/test/screens/sweep320_safemode_deep_test.dart",
    # codex/journey-os-mx-fidelite-design : audit de fidélité au design validé
    # (mint-experience, 5e lentille) sur les 4 surfaces ci-dessus + login/3a.
    # Constat sans patch — aucune surface modifiée, un seul artefact d'audit.
    ".planning/audit/2026-08-04-fidelite-design-mint-experience.md",
}
DELETION_ALLOW = {
    # -axj : 3e moteur RvC orphelin supprimé (aucun appelant prod, garde
    # boundary conservée contre la réintroduction)
    "apps/mobile/lib/domain/rente_vs_capital_calculator.dart",
    "apps/mobile/test/simulators/rente_vs_capital_test.dart",
    # -a6e : chaîne morte lpp_buyback_advanced (façade jamais montée ; la
    # logique 79b -okl vit désormais dans le flux live RachatEchelonne)
    "apps/mobile/lib/widgets/simulators/lpp_buyback_advanced_widget.dart",
    "apps/mobile/lib/services/simulators/lpp_buyback_advanced_simulator.dart",
    "apps/mobile/test/simulators/lpp_buyback_advanced_simulator_test.dart",
    "apps/mobile/test/services/coach/chat_drawer_summon_test.dart",
    # Tranche firstJob (ADR AX iOS 26.2 Etape 2, 2026-07-30) : promotion
    # _red->CORE. La variante REELLE _red.yaml est INJOUABLE (testIDs onb-*
    # absents, cablage hors-tranche SPEC §3.1) -> retiree. La variante SEEDED
    # est deplacee vers maestro-perfect-set/flow_firstjob_tranche_acceptance_seeded.yaml
    # (promue CORE, VERT bout en bout cite).
    "tools/simulator/flows/firstjob_tranche_acceptance_red.yaml",
    "tools/simulator/flows/firstjob_tranche_acceptance_seeded.yaml",
}
IGNORED_GENERATED_PREFIXES = (
    "services/backend/mint_backend.egg-info/",
    # Cartographie navigation (audit 2026-07, demande Julien 2026-07-23) :
    # artefacts d'analyse .planning, pas du code Journey OS.
    ".planning/audit-etat-des-lieux-2026-07/",
    # ADRs de décision (panels/synthèses) : artefacts .planning, pas du code Journey OS.
    ".planning/decisions/",
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

def _unquote_git_path(line: str) -> str:
    """git (core.quotePath) cite en C-style les chemins non-ASCII :
    `"...\\342\\235\\214..."`. Sans dé-quotage, ces chemins ne matchent
    jamais les préfixes du whitelist (bug latent révélé par l'archivage
    2026-07-29 d'un screenshot Maestro nommé avec un emoji)."""
    if not (line.startswith('"') and line.endswith('"') and len(line) >= 2):
        return line
    try:
        return (
            line[1:-1]
            .encode("ascii")
            .decode("unicode_escape")
            .encode("latin-1")
            .decode("utf-8")
        )
    except (UnicodeDecodeError, UnicodeEncodeError):
        return line

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
            _unquote_git_path(line)
            for output in outputs
            for line in output.splitlines()
            if line and not _is_ignored_generated(_unquote_git_path(line))
        }
    ), []

def _archive_counterpart(path: str) -> str | None:
    """Réconciliation plans 2026-07-29 : chemin archivé équivalent d'un
    receipt de phase (ou de PERIMETERS.md) déplacé vers phases-archive/."""
    if path.startswith(".planning/phases/"):
        return ".planning/phases-archive/" + path[len(".planning/phases/"):]
    if path == ".planning/PERIMETERS.md":
        return ".planning/phases-archive/PERIMETERS.md"
    return None


def _scope_errors(root: Path, changed: list[str]) -> list[str]:
    errors: list[str] = []
    for path in changed:
        if path in DELETION_ALLOW and not (root / path).exists():
            continue
        # Réconciliation plans 2026-07-29 : un déplacement git mv vers
        # .planning/phases-archive/ n'est pas une suppression — l'ancien
        # chemin est autorisé si (et seulement si) la copie archivée existe.
        counterpart = _archive_counterpart(path)
        if counterpart is not None and not (root / path).exists() and (root / counterpart).exists():
            continue
        allowed_record = path.startswith(str(RECORDS) + "/") and path.endswith(".json") and "/" not in path[len(str(RECORDS)) + 1 :]
        allowed_issue = path.startswith(str(ISSUES) + "/") and path.endswith(".json") and "/" not in path[len(str(ISSUES)) + 1 :]
        allowed_diagram = path.startswith(str(journey_os_generate.DIAGRAMS) + "/") and path.endswith(".mmd") and "/" not in path[len(str(journey_os_generate.DIAGRAMS)) + 1 :]
        allowed_route_contract = path.startswith(str(ROUTE_CONTRACTS) + "/") and path.endswith(".json") and "/" not in path[len(str(ROUTE_CONTRACTS)) + 1 :]
        # Cartes de navigation par thème : générées par
        # tools/checks/generate_theme_maps.py (mécanique, régénérable) — on
        # autorise le répertoire plutôt que de figer chaque thème.
        allowed_architecture = path.startswith(".planning/architecture/") and path.endswith(".md")
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
        # Réconciliation plans 2026-07-29 : les receipts archivés sous
        # .planning/phases-archive/ sont des feuilles mortes hors routing —
        # leur maintenance (bannières datées, index) reste autorisée.
        allowed_archive = path.startswith(".planning/phases-archive/")
        if not (path in ALLOW or allowed_record or allowed_issue or allowed_diagram or allowed_evidence or allowed_route_contract or allowed_architecture or allowed_archive):
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
