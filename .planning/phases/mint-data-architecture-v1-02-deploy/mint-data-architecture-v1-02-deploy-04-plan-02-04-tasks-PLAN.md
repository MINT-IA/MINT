---
phase: mint-data-architecture-v1-02-deploy
plan: 04
type: execute
wave: 3
depends_on: [01, 02, 03]
files_modified:
  # Plan 02-04 Task 1 — D-09 + D-10 + allowlist cleanup
  - services/backend/app/services/expat/frontalier_service.py
  - services/backend/app/services/expat/__init__.py
  - services/backend/app/api/v1/endpoints/expat.py
  - services/backend/tests/test_expat.py
  - apps/mobile/lib/services/coach_narrative_service.dart
  - apps/mobile/test/services/coach_narrative_profile_context_test.dart
  - tools/checks/profile_safe_fields_parity_allowlist.txt
  - lefthook.yml
  - .github/workflows/design-lints.yml
  # Plan 02-04 Task 2 — Q6 CI mechanical fixes
  - .github/workflows/regulatory-codegen.yml
  - .github/workflows/_self_test/staging_status_test.py
  - .github/workflows/_self_test/cron_scheduled_only.py
  - .github/CODEOWNERS
  - docs/operations/staging-down-override.md
  # Plan 02-04 Task 3 — declared_counters_must_fire HARD gate + Phase 02 LSFin extension
  - tools/checks/declared_counters_must_fire.py
  - tools/checks/tests/test_declared_counters_must_fire.py
  - services/backend/tests/observability/test_phase02_counters.py
  - services/backend/tests/compliance/test_event_log_banned_terms.py
  - tools/checks/banned_terms_python.py
  # Plan 02-04 Task 4 — 3 forward-deferred runbooks + Sentry alert + branch protection
  - docs/operations/fact-event-partition-split.md
  - docs/operations/dek-rotation-phase04.md
  - docs/operations/audit-pepper-rotation.md
  - docs/operations/sentry-alert-config.md
  - docs/operations/branch-protection-config.md
  - services/backend/README.md
  # Mobile L1 sub-PR A4a (DEFERRED-02-02-C/E/F)
  - apps/mobile/lib/main.dart
  - apps/mobile/lib/services/audit/offline_audit_queue.dart
  - apps/mobile/pubspec.yaml
  - .planning/phases/mint-data-architecture-v1-02-deploy/mobile-l1-design-panel-verdict.md
  # Mobile L1 sub-PR A4b (DEFERRED-02-02-D + iOS entitlement)
  - apps/mobile/lib/services/audit/audit_buffer_db.dart
  - apps/mobile/ios/Runner/Runner.entitlements
  - apps/mobile/ios/fastlane/Matchfile
  # 5 sec/arch FLAGs
  - services/backend/tests/compliance/test_event_log_no_quasi_identifier.py
  - services/backend/tests/integration/test_dsar_event_log_inclusion.py
  - services/backend/tests/integration/test_event_log_baseline_trim.py
  - tools/checks/subject_type_forward_lint.py
  - tools/checks/tests/test_subject_type_forward_lint.py
  # DEFERRED-02-01-A merge migration (if not absorbed by p98_merge node)
  - services/backend/alembic/versions/p122_merge_p86_eclairage_into_p120.py
  # PR D polish absorbed
  - services/backend/app/models/audit_event.py
  - services/backend/app/services/feature_flags.py
  - services/backend/app/services/projector/fact_projector.py
  - services/backend/app/services/snapshots/snapshot_service.py
  # Wave 4 prod close-out
  - .planning/phases/mint-data-architecture-v1-02-deploy/prod-task-2a-evidence.txt
  - .planning/phases/mint-data-architecture-v1-02-deploy/prod-final-5-gate-evidence.txt
  - .planning/phases/mint-data-architecture-v1-02-deploy/mint-data-architecture-v1-02-deploy-VERIFICATION-REPORT.html
  - .planning/phases/mint-data-architecture-v1-02-deploy/mint-data-architecture-v1-02-deploy-SUMMARY.md
  - .planning/ROADMAP.md
  - .planning/STATE.md
  - PERIMETERS.md
autonomous: false
requirements:
  - D-06
  - D-07
  - D-09
  - D-10
  - D-21
  - D-32
  - D-33
requirements_addressed:
  - Plan-02-04#Task-1 D-09 S12 alias removal + D-10 PR-A3 dead-fields + allowlist cleanup
  - Plan-02-04#Task-2 Q6 CI mechanical fixes (D-06)
  - Plan-02-04#Task-3 declared_counters_must_fire HARD gate (D-32 G3 + D-33) + Phase 02 LSFin banned-terms extension (D-32 G5)
  - Plan-02-04#Task-4 3 forward-deferred runbooks (D-07)
  - HANDOFF#PR-A4 Mobile L1 device wiring (DEFERRED-02-02-C + D + E + F + iOS entitlement isolation)
  - QA-Panel-#655#sec-FLAG-2 scenario_inputs_hash quasi-identifier scrub
  - QA-Panel-#655#sec-FLAG-4 DSAR manifest event_log inclusion
  - QA-Panel-#655#sec-FLAG-5 pre-existing baseline trim
  - QA-Panel-#655#arch-FLAG-2 UUID4→UUID7 decoupled forward-defer Phase 03
  - QA-Panel-#655#arch-FLAG-3 subject_type forward-lint
  - DEFERRED-02-01-A alembic dual-head merge (verify absorbed by p98_merge_p86_eclairage OR ship explicit merge migration)
  - DEFERRED-02-01-C profile_safe_fields_parity static-analysis enhancement (deferred to Phase 03 backlog)
  - PR-D-polish absorbed (TIMESTAMPTZ + rename + feature_flags double-resolution + duplicate output_hash + project_event refactor + create_snapshot refactor + orphan staging Postgres delete)
  - HANDOFF#Wave-4 prod migration apply + final 5-gate panel + VERIFICATION-REPORT.html + SUMMARY.md
threat_model_ref: mint-data-architecture-v1-02-deploy-RESEARCH#Security-Domain + engram #194 deep audit (DSAR, UUID7 forward-compat, Mobile L1 buffer integrity, iOS entitlement scope, baseline trim, quasi-identifier)

decisions_locked:
  - id: open-q-5
    locked: "iOS entitlement isolation : sub-PR A4b ships AFTER sub-PR A4a per locked decision HANDOFF + memory `feedback_ios_entitlements_block_testflight`. A4a = DEFERRED-02-02-C lefthook + DEFERRED-02-02-E observer + DEFERRED-02-02-F connectivity_plus (Dart-only, no plist change) ; A4b = sqflite_sqlcipher prod impl + Runner.entitlements + fastlane match (iOS only)."
    rationale: "Phase-decision-lock orchestrator instruction #5 + memory feedback_ios_entitlements_block_testflight (any com.apple.developer.* = release-blocking + isolated PR)."
  - id: open-q-6
    locked: "Sentry alert rule = Julien-only Sentry dashboard UI task (not Claude-actionable). Claude ships docs/operations/sentry-alert-config.md runbook in Task 4 of this plan ; Julien configures BEFORE Wave 4 prod cutover. Already pre-required before Wave 2 PR-3b CHECKPOINT (locked decision Plan 03 #5)."
    rationale: "Phase-decision-lock orchestrator instruction #6."
  - id: open-q-7
    locked: "Mobile parity-lint drift baseline scope = PR-A3 drops ONLY 3 allowlisted fields. Full 40-field closure (DEFERRED-02-01-B) deferred to backlog. Reasoning : Karpathy #3 surgical scope discipline ; Phase 02-deploy is operational cutover not Flutter audit."
    rationale: "Phase-decision-lock orchestrator instruction #7 + CONTEXT line 33-34 DEFERRED-02-01-B baseline 40 vs 15."
  - id: pr-d-polish
    locked: "PR D polish absorbed into Wave 3 Plan 04 final-wave tasks (NOT a separate plan per Phase-decision-lock). Items : TIMESTAMPTZ → DateTime(timezone=True) + rename read_monthly_gross_income → read_gross_income_fact + consolidate feature_flags double-resolution + drop _payload_hashes duplicate output_hash + refactor fact_projector.project_event (103 LOC → 50) + refactor snapshot_service.create_snapshot (150 LOC → 3 functions) + delete defense-against-impossible sec FLAG-1 (NOT in this phase per RESEARCH §Anti-Patterns) + DELETE orphan staging Postgres service (Julien-confirms-no-MINT-vars-reference-it first)."
    rationale: "Phase-decision-lock orchestrator instruction §PR-D-Polish + RESEARCH §Anti-Patterns (sec FLAG-1 NOT deleted in this phase, kept for Phase 03)."
  - id: sec-flag-1-preservation
    locked: "sec FLAG-1 post-write divergence assertion in fact_projector.py lines 151-181 is NOT deleted in Phase 02-deploy ; revisit Phase 03 after 30j stable event-log per RESEARCH §Anti-Patterns. Conflicts with PR D step 7 — PR D step 7 IS NOT APPLIED."
    rationale: "RESEARCH §Anti-Patterns to Avoid + §Open-Questions Q5 recommendation."
  - id: deferred-02-01-a-resolution
    locked: "DEFERRED-02-01-A alembic dual-head (p86_eclairage_delivered) : verify via `alembic heads` whether already absorbed by `p98_merge_p86_eclairage` (the merge node identified in Plan 01 Task 4 chain-audit.txt). If absorbed = no action ; if not = ship explicit `p122_merge_p86_eclairage_into_p120.py` migration."
    rationale: "RESEARCH §Summary 14-rev chain analysis + Plan 01 Task 4 chain-audit.txt outcome."

must_haves:
  truths:
    # Plan 02-04 Tasks
    - "S12 PR-2 alias removed : FrontalierService = FrontalierSegmentService line deleted from frontalier_service.py ; all live importers use FrontalierSegmentService directly (D-09)."
    - "D-MOB-01 PR-A3 dead-field drop : 3 Flutter-only fields removed from _buildProfileContext ; profile_safe_fields_parity_allowlist.txt deleted ; HARD lint passes WITHOUT --allowlist flag (D-10)."
    - "Q6 CI mechanical fixes : STAGING-MALFORMED detection step + scheduled-only aging-state writes + STAGING-DOWN-OVERRIDE label CODEOWNER-gated (D-06)."
    - "declared_counters_must_fire.py HARD close-out gate active : asserts all 9 declared counters fire ≥ 1 in representative test scenario (8 existing + mint_snapshot_fact_current_drift_total from Plan 01 PR B = 9) AND grep-in-app/ source for at least 1 increment site per counter (B16 patch)."
    - "Phase 02 LSFin banned-terms extension : banned_terms_python.py --scan-jsonb-payload mode scans fact_event.value_enc + writer-level scan in project_event blocks insertion (D-32 G5)."
    - "3 forward-deferred runbooks shipped : fact-event-partition-split.md (≥50 lines + concrete thresholds) + dek-rotation-phase04.md (≥40 lines) + audit-pepper-rotation.md (≥50 lines + B7 PR-ordering rule)."
    # Mobile L1 (HANDOFF PR-A4 split into A4a + A4b)
    - "Sub-PR A4a ships : DEFERRED-02-02-C lefthook wiring for no_mobile_fact_current_regulatory_read.py + DEFERRED-02-02-E main.dart MobileL1AuditLifecycleObserver wiring + DEFERRED-02-02-F connectivity_plus integration. 4-person design panel verdict recorded BEFORE push per memory `feedback_design_panel_before_push`."
    - "Sub-PR A4b ships : DEFERRED-02-02-D sqflite_sqlcipher production AuditBufferDb impl + Runner.entitlements + fastlane match profile update. ISOLATED PR per memory `feedback_ios_entitlements_block_testflight`."
    # 5 sec/arch FLAGs
    - "sec FLAG-2 scenario_inputs_hash : test_event_log_no_quasi_identifier.py asserts no quasi-identifier (postal_code + birth_date + canton) appears in fact_event payload."
    - "sec FLAG-4 DSAR manifest : test_dsar_event_log_inclusion.py asserts /v1/users/dsar response includes fact_event entries for the user."
    - "sec FLAG-5 baseline trim : test_event_log_baseline_trim.py asserts event_log size bounded for pre-Phase-02 users (no balloon-on-cutover)."
    - "arch FLAG-2 UUID4→UUID7 : DECOUPLED Phase 03 (decision documented + audit-pepper-rotation.md runbook references the forward-compat path)."
    - "arch FLAG-3 subject_type forward-lint : subject_type_forward_lint.py catches `subject_type='user'` without registry check ; HARD lefthook."
    # Wave 4
    - "Production migration applied : prod alembic head = current dev head (p121_drop_snapshot_legacy or later post-Wave-3 merges) ; fact_event + fact_current + dek_envelope tables exist on prod ; FF_FACT_EVENT_DUAL_WRITE never set on prod (skipped per 0-user-prod premise + Wave 2 cutover semantically COMPLETE-on-staging-and-by-construction-on-prod)."
    - "Prod baseline pg_dump captured (`tools/db/baselines/production-{date}-pre-deploy.sql.gz` from Plan 01 OR fresh capture Wave 4)."
    - "Final 5-gate panel : G1 Maestro PASS + G2 Julien device sign-off + G3 dev CI green + G4 regression suite + G5 lints (LSFin + accent + ARB + constants drift + hmac_pepper_audit + alembic_partition_safety + declared_counters_must_fire + no_ff_fact_event_dual_write)."
    - "VERIFICATION-REPORT.html (≥200 lines) + SUMMARY.md (≥180 lines) + ROADMAP + STATE + PROJECT.md updated to ◆ Phase 02-deploy COMPLETE (or appropriate status per 0-trust §9.5 stage labeling)."
  artifacts:
    - path: "tools/checks/declared_counters_must_fire.py"
      provides: "HARD close-out gate asserting all 9 declared counters fire + grep-in-app/ source check (B16)"
      min_lines: 80
    - path: "tools/checks/subject_type_forward_lint.py"
      provides: "arch FLAG-3 lint catching subject_type without registry check"
      min_lines: 40
    - path: "docs/operations/fact-event-partition-split.md"
      provides: "Forward-deferred partition-split runbook with concrete thresholds + ATTACH PARTITION procedure"
      min_lines: 50
    - path: "docs/operations/dek-rotation-phase04.md"
      provides: "Phase 04 DEK rotation runbook"
      min_lines: 40
    - path: "docs/operations/audit-pepper-rotation.md"
      provides: "Pepper rotation runbook + B7 PR-ordering rule"
      min_lines: 50
    - path: "docs/operations/sentry-alert-config.md"
      provides: "Sentry alert rule config runbook (Julien-only UI task)"
      min_lines: 30
    - path: "docs/operations/staging-down-override.md"
      provides: "C8 STAGING-DOWN-OVERRIDE label contract + audit trail"
      min_lines: 30
    - path: "docs/operations/branch-protection-config.md"
      provides: "Branch protection rule promotion runbook (pg-integration required check + STAGING-DOWN-OVERRIDE required check)"
      min_lines: 30
    - path: "apps/mobile/lib/services/audit/audit_buffer_db.dart"
      provides: "Sub-PR A4b sqflite_sqlcipher production AuditBufferDb impl (replaces InMemoryAuditBufferDb)"
      min_lines: 80
    - path: ".planning/phases/mint-data-architecture-v1-02-deploy/mobile-l1-design-panel-verdict.md"
      provides: "4-person design panel verdict (UX + a11y + adversarial + engineering) signed BEFORE sub-PR A4a push"
      min_lines: 40
    - path: ".planning/phases/mint-data-architecture-v1-02-deploy/mint-data-architecture-v1-02-deploy-VERIFICATION-REPORT.html"
      provides: "Phase-level VERIFICATION report with 5-gate panel + per-wave rollup + cumulative metric snapshot"
      min_lines: 200
    - path: ".planning/phases/mint-data-architecture-v1-02-deploy/mint-data-architecture-v1-02-deploy-SUMMARY.md"
      provides: "Phase-level SUMMARY with per-D-XX disposition + counter-arguments + lessons learned"
      min_lines: 180
  key_links:
    - from: "lefthook.yml"
      to: "tools/checks/declared_counters_must_fire.py"
      via: "pre-push HARD gate on services/backend/app/observability/*.py changes"
      pattern: "declared_counters_must_fire"
    - from: "apps/mobile/lib/main.dart"
      to: "apps/mobile/lib/services/audit/mobile_l1_audit_lifecycle_observer.dart"
      via: "WidgetsBinding.instance.addObserver(lifecycle) + await lifecycle.recordColdStart() on bootstrap"
      pattern: "MobileL1AuditLifecycleObserver"
    - from: "apps/mobile/lib/services/audit/offline_audit_queue.dart"
      to: "connectivity_plus"
      via: "Main.dart caller listens to connectivity stream + invokes audit.flush() on restore"
      pattern: "connectivity_plus"
    - from: "apps/mobile/lib/services/audit/audit_buffer_db.dart"
      to: "sqflite_sqlcipher + flutter_secure_storage"
      via: "Persistent encrypted buffer with iOS Keychain-derived passphrase"
      pattern: "sqflite_sqlcipher"
    - from: ".planning/ROADMAP.md"
      to: ".planning/phases/mint-data-architecture-v1-02-deploy/mint-data-architecture-v1-02-deploy-SUMMARY.md"
      via: "Wave 4 close-out flips ROADMAP Phase 02-deploy status from 📋 OPEN → ◆ COMPLETE-on-dev-pending-G2 (per 0-trust §9.5)"
      pattern: "◆ code-shipped on dev, pending operational gates"
---

<objective>
Wave 3 + Wave 4 — close-out de Phase 02-deploy.

Wave 3 délivre : Plan 02-04 Task 1-4 (D-09 alias + D-10 dead-fields + Q6 CI + declared_counters HARD + 3 runbooks) + Mobile L1 device wiring (sub-PR A4a Dart + sub-PR A4b iOS isolated) + 5 sec/arch FLAGs + DEFERRED-02-01-A vérification + PR D polish absorbée + 2 runbooks supplémentaires (sentry-alert + branch-protection).

Wave 4 délivre : prod migration apply (réutilise Wave 1 sequence mais sur production env) + final 5-gate panel + VERIFICATION-REPORT.html + SUMMARY.md + ROADMAP + STATE + PROJECT.md flip.

Purpose : fermer Phase 02-deploy de manière complète + auditable. Chaque D-XX a une disposition. Chaque DEFERRED-02-0X-Y est soit shipped soit re-deferred avec rationale. La 5-gate exit panel est documentée déterministiquement (G1 + G2 + G3 + G4 + G5 chacun avec citation evidence par 0-trust §9).

Type : `autonomous: false` — 2 Julien CHECKPOINTS critiques (Mobile L1 design panel BEFORE push + Wave 4 prod migration apply + final close-out G2 device sign-off).

Output : 11 fichiers code modifiés + 8 docs runbooks + 5 nouveaux tests FLAGs + 1 sub-PR A4b isolated iOS + 1 design panel verdict + Wave 4 phase-close artifacts (HTML report + SUMMARY).

Scope alert (critique) : ce plan est large MAIS contraint par Karpathy #3 surgical. Chaque tâche cite son D-XX / DEFERRED-02-0X-Y / FLAG d'origine. Aucun drive-by refactor en dehors du PR-D-polish explicitement scopé. PR D step 7 (delete sec FLAG-1) EXCLU par locked decision #sec-flag-1-preservation.

Out of scope this plan :
- Phase 03 (coach extractor) — Phase 03 ouvrira après Wave 4 close.
- UUID4 → UUID7 migration effective (arch FLAG-2 décrochée Phase 03).
- DEK rotation EXECUTION (Phase 04 ; runbook only).
- DEFERRED-02-01-B Mobile _buildProfileContext 40-field drift closure (backlog ; locked decision #7).
- DEFERRED-02-01-C profile_safe_fields_parity static-analysis enhancement (backlog Phase 03 lint refactor).
- DEFERRED-02-02-B DEK tombstone backend (LOW risk, semantically duplicate ; revisit Phase 04).
- DEFERRED-02-02-G True-concurrency variant iter-2 A8 (CI-only test, Plan 02-04 Task 4 close-out per existing deferred-items).
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/mint-data-architecture-v1-02-deploy/CONTEXT.md
@.planning/phases/mint-data-architecture-v1-02-deploy/HANDOFF-2026-05-19.md
@.planning/phases/mint-data-architecture-v1-02-deploy/mint-data-architecture-v1-02-deploy-RESEARCH.md
@.planning/phases/mint-data-architecture-v1-02-deploy/mint-data-architecture-v1-02-deploy-VALIDATION.md
@.planning/phases/mint-data-architecture-v1-02-deploy/mint-data-architecture-v1-02-deploy-01-alembic-chain-audit-PLAN.md
@.planning/phases/mint-data-architecture-v1-02-deploy/mint-data-architecture-v1-02-deploy-02-staging-migration-apply-PLAN.md
@.planning/phases/mint-data-architecture-v1-02-deploy/mint-data-architecture-v1-02-deploy-03-cutover-PR3b-PR4-PR5-PLAN.md
@.planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-04-close-out-counters-runbooks-PLAN.md
@.planning/phases/mint-data-architecture-v1-02-event-log-projection/deferred-items.md
@.planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-projection-SUMMARY.md
@services/backend/app/services/expat/frontalier_service.py
@apps/mobile/lib/services/coach_narrative_service.dart
@tools/checks/profile_safe_fields_parity.py
@tools/checks/banned_terms_python.py
@.github/workflows/regulatory-codegen.yml
@services/backend/app/observability/counters.py
@apps/mobile/lib/main.dart
@apps/mobile/lib/services/audit/

<interfaces>
<!-- State after Plans 01 + 02 + 03 land (post-PR-5 dev-merged). -->

Backend post-PR-5 :
- app/models/snapshot.py DELETED
- app/api/v1/endpoints/projection.py + snapshots.py read exclusively from FactCurrent (no `?legacy=true`)
- tools/checks/profile_safe_fields_parity.py runs `--hard` mode in lefthook + CI (PR-3b flip)
- tools/checks/profile_safe_fields_parity_allowlist.txt has EXACTLY 3 Flutter-only field names (Task 1 of THIS plan deletes the file + drops the 3 fields)
- 9 counters declared in app/observability/counters.py :
  1. mint_fact_event_insert_total
  2. mint_fact_current_read_latency_ms
  3. mint_dek_envelope_status_total
  4. mint_anonymous_session_link_total
  5. mint_projector_idempotency_skip_total
  6. mint_constants_version_mismatch_total
  7. mint_kms_backend_failure_total (iter-2 A4)
  8. mint_dek_cache_size_total (iter-2 A5)
  9. mint_snapshot_fact_current_drift_total (Plan 01 PR B step 1)
- FF_FACT_EVENT_DUAL_WRITE removed from feature_flags.py (PR-4)
- DeprecationWarning on SnapshotModel writer — but writer file deleted (PR-5) so DeprecationWarning is on the call sites if any remain (review needed)
- p98_merge_p86_eclairage merge node confirmed via Plan 01 Task 4 chain-audit.txt (or NOT — verify Task 4 of this plan)

S12 alias state (post-Plan-02-01) :
- app/services/expat/frontalier_service.py contains `class FrontalierSegmentService:` + trailing `FrontalierService = FrontalierSegmentService` alias line
- app/services/expat/__init__.py re-exports both names
- app/api/v1/endpoints/expat.py uses `as FrontalierService` local-alias
- Task 1 of this plan removes all 3 alias touches.

D-MOB-01 dead-fields state (post-PR-3b allowlist) :
- tools/checks/profile_safe_fields_parity_allowlist.txt contains 3 Flutter-only field names
- apps/mobile/lib/services/coach_narrative_service.dart `_buildProfileContext` emits those 3 fields
- Task 1 of this plan : drop the 3 emissions + delete the allowlist file + run `--hard` WITHOUT allowlist green.

Q6 CI workflow state (.github/workflows/regulatory-codegen.yml) :
- Phase 01 D-16 baseline (tiered 7/14/28-day escalation)
- Task 2 of this plan extends : STAGING-MALFORMED detection + scheduled-only aging + STAGING-DOWN-OVERRIDE CODEOWNER-gated.

Mobile L1 state (post-Plan-02-02 substrate) :
- AuditBufferDb abstract + InMemoryAuditBufferDb shipped
- MobileL1AuditLifecycleObserver class shipped but NOT wired in main.dart (DEFERRED-02-02-E)
- OfflineAuditQueue shipped but no connectivity_plus integration (DEFERRED-02-02-F)
- no_mobile_fact_current_regulatory_read.py lint shipped but not in lefthook (DEFERRED-02-02-C)
- sqflite_sqlcipher production AuditBufferDb impl NOT shipped (DEFERRED-02-02-D)
- iOS entitlement for SQLCipher Keychain access NOT in Runner.entitlements (release-blocking per memory)

5 sec/arch FLAGs state (from QA panel #655 / engram #194) :
- sec FLAG-2 : scenario_inputs_hash CAN contain quasi-identifier ; test missing
- sec FLAG-4 : DSAR endpoint doesn't include fact_event entries ; test missing
- sec FLAG-5 : pre-existing baseline trim for event_log ; test missing
- arch FLAG-2 : UUID4 used (random) ; UUID7 migration documented Phase 03 forward-compat
- arch FLAG-3 : subject_type='user' string-based ; registry check forward-lint missing

DEFERRED-02-01-A status :
- Plan 01 Task 4 chain-audit.txt should document whether p98_merge_p86_eclairage node already absorbs the dual-head
- If YES : no action in this plan
- If NO : ship p122_merge_p86_eclairage_into_p120.py merge migration in Task 5 of this plan
</interfaces>
</context>

<decision_locked>
- **Open-Q #5 (iOS entitlement ordering)** — LOCKED : Sub-PR A4a ships first (Dart-only) ; sub-PR A4b ships AFTER (iOS entitlement isolated). Per memory `feedback_ios_entitlements_block_testflight`.
- **Open-Q #6 (Sentry alert wiring)** — LOCKED : Julien-only UI task ; Claude ships runbook in Task 4 ; Julien configures BEFORE Wave 4 prod cutover (already required before Plan 03 Task 3 CHECKPOINT).
- **Open-Q #7 (Mobile parity-lint drift scope)** — LOCKED : PR-A3 drops 3 allowlisted fields only ; full 40-field closure deferred (DEFERRED-02-01-B backlog).
- **PR D polish absorbed** — LOCKED : items 1-6 + 8 applied in this plan ; item 7 (delete sec FLAG-1) NOT applied per locked decision #sec-flag-1-preservation.
- **DEFERRED-02-01-A resolution** — LOCKED : verify via `alembic heads` whether absorbed by p98_merge ; if not, ship explicit p122 merge migration in Task 5.
</decision_locked>

<tasks>

<task type="auto">
  <name>Task 1 (Plan 02-04 Task 1) : S12 PR-2 alias removal (D-09) + D-MOB-01 PR-A3 dead-field drop (D-10) + allowlist cleanup</name>
  <files>
    services/backend/app/services/expat/frontalier_service.py,
    services/backend/app/services/expat/__init__.py,
    services/backend/app/api/v1/endpoints/expat.py,
    services/backend/tests/test_expat.py,
    apps/mobile/lib/services/coach_narrative_service.dart,
    apps/mobile/test/services/coach_narrative_profile_context_test.dart,
    tools/checks/profile_safe_fields_parity_allowlist.txt,
    lefthook.yml,
    .github/workflows/design-lints.yml
  </files>
  <read_first>
    services/backend/app/services/expat/frontalier_service.py (post-Plan-02-01 state — trailing alias line),
    services/backend/app/services/expat/__init__.py (re-export surface),
    services/backend/app/api/v1/endpoints/expat.py (line 54 local-alias import),
    apps/mobile/lib/services/coach_narrative_service.dart (lines 1161-1208 _buildProfileContext + the 3 fields whitelisted in Plan 03 PR-3b),
    tools/checks/profile_safe_fields_parity_allowlist.txt (3 field names to drop),
    .planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-04-close-out-counters-runbooks-PLAN.md (Task 1 spec lines 160-213)
  </read_first>
  <action>
1. **S12 PR-2 alias removal (D-09)** :
   - `git grep -rn "FrontalierService" services/backend apps/mobile/lib | grep -v "FrontalierSegmentService"` to identify ALL live importers.
   - Update each to use `FrontalierSegmentService` directly :
     - `services/backend/app/api/v1/endpoints/expat.py:54` : `from app.services.expat.frontalier_service import FrontalierSegmentService as FrontalierService` → `from app.services.expat.frontalier_service import FrontalierSegmentService` + replace ALL usages in file.
     - `services/backend/tests/test_expat.py` : same pattern.
   - `app/services/expat/frontalier_service.py` : REMOVE trailing `FrontalierService = FrontalierSegmentService` alias line.
   - `app/services/expat/__init__.py` : REMOVE `from app.services.expat.frontalier_service import FrontalierService` ; KEEP `FrontalierSegmentService` re-export.
   - DO NOT touch :
     - `app/services/frontalier_service.py` (S12 façade with different class — keeps `FrontalierService` name forever per D-08).
     - `apps/mobile/lib/services/segments_service.dart` (mobile Flutter `class FrontalierService` is a Dart class in a different layer — unrelated to Python S23 rename).

2. **D-MOB-01 PR-A3 dead-field drop (D-10)** :
   - Read `tools/checks/profile_safe_fields_parity_allowlist.txt` to get 3 Flutter-only field names (created Plan 03 Task 2).
   - In `apps/mobile/lib/services/coach_narrative_service.dart::_buildProfileContext` : REMOVE the `result['<key>'] = profile.<getter>;` lines for those 3 fields.
   - Update `apps/mobile/test/services/coach_narrative_profile_context_test.dart` : remove corresponding `expect(result.containsKey('<key>'), isTrue)` assertions.
   - DELETE `tools/checks/profile_safe_fields_parity_allowlist.txt`.
   - Update `lefthook.yml` + `.github/workflows/design-lints.yml` : remove `--allowlist tools/checks/profile_safe_fields_parity_allowlist.txt` flag from EVERY invocation of `profile_safe_fields_parity.py`. HARD lint now runs with ZERO allowlist.

3. **Verify HARD lint without allowlist** :

```bash
python3 tools/checks/profile_safe_fields_parity.py --hard
# Expected : exit 0 (the 3 fields are dropped, no remaining drift)
echo $?
```

4. **Pre-push checklist** :
   - `git grep -rn "FrontalierService" services/backend apps/mobile/lib | grep -v "FrontalierSegmentService"` returns 0 lines (except S12 façade + mobile Dart class).
   - `cd services/backend && python3 -m pytest tests/test_expat.py tests/test_s12_frontalier_rename.py -q` exits 0.
   - `cd apps/mobile && flutter analyze && flutter test test/services/coach_narrative_profile_context_test.dart` exits 0.
   - `python3 tools/checks/banned_terms_python.py services/backend/app/services/expat/` + `python3 tools/checks/accent_lint_fr.py --scope backend` + `python3 tools/checks/validate_arb_parity.py` exit 0.
   - `python3 services/backend/scripts/generate_canonical.py` exits 0 (if endpoint changed).
   - `cd services/backend && python3 -m pytest tests/ -q --timeout=180` exits 0.
  </action>
  <verify>
    <automated>cd /Users/julienbattaglia/Desktop/MINT.nosync && [ $(git grep -rn "FrontalierService = FrontalierSegmentService" services/backend/app/services/expat/frontalier_service.py | wc -l) -eq 0 ] && [ $(git grep -rn "^from app.services.expat.frontalier_service import FrontalierService\b" services/backend/ | wc -l) -eq 0 ] && [ $(git grep -n "class FrontalierService" services/backend/app/services/expat/ | wc -l) -eq 0 ] && [ $(git grep -n "class FrontalierService" services/backend/app/services/frontalier_service.py | wc -l) -eq 1 ] && cd services/backend && python3 -m pytest tests/test_expat.py -q && python3 -m pytest tests/ -q --timeout=180 && cd /Users/julienbattaglia/Desktop/MINT.nosync && python3 tools/checks/profile_safe_fields_parity.py --hard && [ ! -f tools/checks/profile_safe_fields_parity_allowlist.txt ] && cd apps/mobile && flutter analyze && flutter test test/services/coach_narrative_profile_context_test.dart -q && cd /Users/julienbattaglia/Desktop/MINT.nosync && python3 tools/checks/banned_terms_python.py services/backend/app/services/expat/ && python3 tools/checks/accent_lint_fr.py --scope backend</automated>
  </verify>
  <acceptance_criteria>
    - `git grep -n "FrontalierService = FrontalierSegmentService" services/backend/app/services/expat/frontalier_service.py` returns 0 hits.
    - `git grep -rn "^from app.services.expat.frontalier_service import FrontalierService\\b" services/backend/` returns 0 hits.
    - `git grep -n "class FrontalierService" services/backend/app/services/expat/` returns 0 hits.
    - `git grep -n "class FrontalierService" services/backend/app/services/frontalier_service.py` returns 1 hit (S12 façade preserved).
    - `cd services/backend && python3 -m pytest tests/test_expat.py tests/test_s12_frontalier_rename.py tests/test_segments.py -q` exits 0.
    - `python3 tools/checks/profile_safe_fields_parity.py --hard` exits 0 WITHOUT `--allowlist` flag.
    - `[ ! -f tools/checks/profile_safe_fields_parity_allowlist.txt ]` returns 0 (file deleted).
    - `grep -c "profile_safe_fields_parity_allowlist" lefthook.yml .github/workflows/design-lints.yml 2>/dev/null` returns 0 (flag removed everywhere).
    - `cd apps/mobile && flutter analyze && flutter test` exits 0.
    - `cd services/backend && python3 -m pytest tests/ -q --timeout=180` exits 0 (full regression).
  </acceptance_criteria>
  <done>
    Plan 02-04 Task 1 closed : D-09 S12 alias removed ; all live importers use FrontalierSegmentService directly. D-10 D-MOB-01 PR-A3 drops 3 dead Flutter-only fields. profile_safe_fields_parity HARD lint passes WITHOUT allowlist. Plan 02-01 + Plan 02-03 carry-over completions all closed.
  </done>
</task>

</tasks>

<task type="auto">
  <name>Task 2 (Plan 02-04 Task 2 + iter-2 C8) : Q6 CI mechanical fixes — STAGING-MALFORMED + scheduled-only aging + STAGING-DOWN-OVERRIDE CODEOWNER-gated + branch protection runbook (D-06)</name>
  <files>
    .github/workflows/regulatory-codegen.yml,
    .github/workflows/_self_test/staging_status_test.py,
    .github/workflows/_self_test/cron_scheduled_only.py,
    .github/CODEOWNERS,
    docs/operations/staging-down-override.md,
    docs/operations/branch-protection-config.md
  </files>
  <read_first>
    .github/workflows/regulatory-codegen.yml (Phase 01 D-16 baseline tiered escalation — extend with STAGING-MALFORMED + scheduled-only aging + override label),
    .github/CODEOWNERS (current state if exists ; create if absent),
    .planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-04-close-out-counters-runbooks-PLAN.md (Task 2 spec lines 215-267 + iter-2 C8 patch lines 590-619)
  </read_first>
  <action>
1. **STAGING-MALFORMED detection step in regulatory-codegen.yml** : two-pass check (verbatim per Plan 02-04 Task 2 spec) :

```yaml
- name: Staging health check (two-pass)
  id: staging_status
  run: |
    if curl -sf -m 10 https://mint-staging.up.railway.app/v1/regulatory/constants > /tmp/payload.json; then
      if python3 -c "import json,sys; data=json.load(open('/tmp/payload.json')); assert 'effective_on' in data" 2>/dev/null; then
        echo "STAGING_STATUS=ok" >> $GITHUB_ENV
      else
        echo "STAGING_STATUS=malformed" >> $GITHUB_ENV
      fi
    else
      echo "STAGING_STATUS=down" >> $GITHUB_ENV
    fi
```

2. **Separate counters via env var + mint_staging_status_total{status}** (Plan 02-02 declared, asserts firing here if backend reachable).

3. **Scheduled-only aging writes** : wrap aging-state write step in `if: github.event_name == 'schedule'`.

4. **HARD-mode STAGING-DOWN-OVERRIDE label CODEOWNER-gated** :

```yaml
- name: STAGING-DOWN-OVERRIDE gate
  if: env.STAGING_STATUS == 'down' || env.STAGING_STATUS == 'malformed'
  run: |
    if [[ "${{ github.event.pull_request.user.login }}" != "julienbattaglia" ]]; then
      echo "::error::STAGING is ${STAGING_STATUS} but PR author is not a CODEOWNER for override"
      exit 1
    fi
    if [[ ! "${{ join(github.event.pull_request.labels.*.name, ',') }}" =~ "STAGING-DOWN-OVERRIDE" ]]; then
      echo "::error::STAGING is ${STAGING_STATUS}; require STAGING-DOWN-OVERRIDE label to proceed"
      exit 1
    fi
    echo "::warning::STAGING-DOWN-OVERRIDE label applied by julienbattaglia — proceeding with cached fixture"
```

5. **`.github/CODEOWNERS`** : if exists, add `.github/workflows/regulatory-codegen.yml @julienbattaglia` ; else create file with that line + comment header.

6. **`.github/workflows/_self_test/staging_status_test.py` (NEW)** — workflow_dispatch input `mode=staging-malformed-test` exercises 3 branches (down / malformed / ok) via local HTTP server.

7. **`.github/workflows/_self_test/cron_scheduled_only.py` (NEW)** — asserts aging-state write step gated on `github.event_name == 'schedule'`.

8. **`docs/operations/staging-down-override.md` (NEW, ≥30 lines)** (per iter-2 C8 patch) : surfaces 2-key invariant + override audit-trail.

9. **`docs/operations/branch-protection-config.md` (NEW, ≥30 lines)** : runbook for Julien to promote `pg-integration (testcontainers)` to required check on dev + `regulatory-codegen / staging-check` to required check on dev + main.
  </action>
  <verify>
    <automated>grep -cE "STAGING_STATUS=down|STAGING_STATUS=malformed|STAGING_STATUS=ok" .github/workflows/regulatory-codegen.yml && grep -cE "STAGING-DOWN-OVERRIDE" .github/workflows/regulatory-codegen.yml && grep "github.event_name == 'schedule'" .github/workflows/regulatory-codegen.yml && grep "julienbattaglia" .github/CODEOWNERS && python3 .github/workflows/_self_test/staging_status_test.py && python3 .github/workflows/_self_test/cron_scheduled_only.py && [ $(wc -l < docs/operations/staging-down-override.md) -ge 30 ] && [ $(wc -l < docs/operations/branch-protection-config.md) -ge 30 ] && python3 tools/checks/banned_terms_python.py .github/workflows/_self_test/ && python3 tools/checks/accent_lint_fr.py docs/operations/</automated>
  </verify>
  <acceptance_criteria>
    - `grep -cE "STAGING_STATUS=down\|STAGING_STATUS=malformed\|STAGING_STATUS=ok" .github/workflows/regulatory-codegen.yml` ≥ 3.
    - `grep -cE "STAGING-DOWN-OVERRIDE" .github/workflows/regulatory-codegen.yml` ≥ 2.
    - `grep "github.event_name == 'schedule'" .github/workflows/regulatory-codegen.yml` returns ≥ 1 hit.
    - `grep "julienbattaglia" .github/CODEOWNERS` returns ≥ 1 hit.
    - `python3 .github/workflows/_self_test/staging_status_test.py` exits 0 (all 3 branches exercised).
    - `python3 .github/workflows/_self_test/cron_scheduled_only.py` exits 0.
    - `wc -l docs/operations/staging-down-override.md` ≥ 30.
    - `wc -l docs/operations/branch-protection-config.md` ≥ 30.
  </acceptance_criteria>
  <done>
    Plan 02-04 Task 2 closed : Q6 CI mechanical fixes (D-06) shipped + STAGING-DOWN-OVERRIDE label runbook + branch-protection runbook. STAGING-MALFORMED is distinct from STAGING-DOWN. Aging-state writes scheduled-only. Override CODEOWNER-gated.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 3 (Plan 02-04 Task 3 + iter-2 B16) : declared_counters_must_fire.py HARD close-out gate + Phase 02 LSFin banned-terms JSONB extension</name>
  <files>
    tools/checks/declared_counters_must_fire.py,
    tools/checks/tests/test_declared_counters_must_fire.py,
    services/backend/tests/observability/test_phase02_counters.py,
    services/backend/tests/compliance/test_event_log_banned_terms.py,
    tools/checks/banned_terms_python.py,
    lefthook.yml
  </files>
  <read_first>
    services/backend/app/observability/counters.py (9 declared counters post-Plan-01 PR B),
    services/backend/app/services/projector/fact_projector.py (counter increment sites),
    services/backend/app/api/v1/endpoints/audit_mobile.py (counter increment sites),
    services/backend/app/cron/continuous_drift_sampler.py (mint_snapshot_fact_current_drift_total increment site),
    tools/checks/banned_terms_python.py (Phase 02 extended state — JSONB payload scan to add),
    .planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-04-close-out-counters-runbooks-PLAN.md (Task 3 spec lines 269-340 + iter-2 B16 patch lines 525-562)
  </read_first>
  <behavior>
    - `declared_counters_must_fire.py --all` : parses counters.py AST → collects 9 counter names → runs `test_phase02_counters.py` scenario test → asserts each counter delta ≥ 1 → ALSO greps services/backend/app/ for each counter name → asserts each has ≥ 1 increment site outside counters.py.
    - `test_phase02_counters.py` : pg_fixture scenario exercising all 9 counters in one test (project_event x2 idempotent + dek create + dek revoke + fact_current read + audit_mobile session-link + regulatory version mismatch + drift_sampler diff + kms_backend_failure simulation + dek_cache_size measurement).
    - `banned_terms_python.py --scan-jsonb-payload` mode : scans fixture JSONB file for `value_enc.payload` banned terms ; seed `{"text": "rendement garanti"}` → exit 1.
    - `test_event_log_banned_terms.py` : asserts fact_event row written with banned-term payload raises BannedTermsViolation at writer level.
  </behavior>
  <action>
1. **`tools/checks/declared_counters_must_fire.py` (NEW, ~120 LOC)** — verbatim per Plan 02-04 Task 3 spec + iter-2 B16 patch (Step 3.5 grep-in-app/ source check) :

```python
"""declared_counters_must_fire.py — HARD close-out gate.

Asserts every Counter/Histogram/Gauge declared in services/backend/app/observability/counters.py :
1. Has at least 1 increment site in services/backend/app/ (not just counters.py + tests).
2. Fires ≥ 1 in the representative test scenario tests/observability/test_phase02_counters.py.

Exit 0 if all 9 counters pass both checks ; exit 1 with the list of unfired or unwired.
"""
import ast
import shutil
import subprocess
import sys
from pathlib import Path

COUNTERS_FILE = Path("services/backend/app/observability/counters.py")
APP_ROOT = "services/backend/app/"

# Step 1 : extract declared counter names via AST
tree = ast.parse(COUNTERS_FILE.read_text())
DECLARED_COUNTERS = []
for node in ast.walk(tree):
    if isinstance(node, ast.Assign):
        for target in node.targets:
            if isinstance(target, ast.Name) and target.id.startswith("mint_"):
                if isinstance(node.value, ast.Call):
                    func_name = getattr(node.value.func, "id", "") or getattr(node.value.func, "attr", "")
                    if func_name in ("Counter", "Histogram", "Gauge"):
                        DECLARED_COUNTERS.append(target.id)

print(f"Declared counters : {len(DECLARED_COUNTERS)}")
for c in DECLARED_COUNTERS:
    print(f"  - {c}")

# Step 2 : grep-in-app/ source for at least 1 increment site
unwired = []
for counter_name in DECLARED_COUNTERS:
    cmd = ["rg", "-c", "--type", "py", "-l", counter_name, APP_ROOT] if shutil.which("rg") else ["git", "grep", "-rln", counter_name, APP_ROOT]
    result = subprocess.run(cmd, capture_output=True, text=True)
    found_files = [f for f in result.stdout.strip().split("\n") if f and not f.endswith("counters.py")]
    if not found_files:
        unwired.append(counter_name)

if unwired:
    print(f"\nBLOCKED : {len(unwired)} declared counters have ZERO increment sites in {APP_ROOT}:")
    for c in unwired:
        print(f"  - {c}")
    sys.exit(1)

# Step 3 : run scenario test + assert delta ≥ 1 for each counter
result = subprocess.run(
    ["python3", "-m", "pytest", "services/backend/tests/observability/test_phase02_counters.py", "-q", "-k", "pg"],
    capture_output=True,
    text=True,
)
if result.returncode != 0:
    print(f"\nBLOCKED : test_phase02_counters.py failed :\n{result.stdout}\n{result.stderr}")
    sys.exit(1)

print(f"\nOK : {len(DECLARED_COUNTERS)} counters declared + wired + firing in representative scenario.")
sys.exit(0)
```

2. **`services/backend/tests/observability/test_phase02_counters.py` (NEW, ≥150 LOC, `@pytest.mark.requires_pg`)** : single pytest scenario exercising all 9 counters per behavior contract above. Captures `_value.get()` before/after for each counter, asserts delta ≥ 1.

3. **`tools/checks/tests/test_declared_counters_must_fire.py` (NEW)** : self-test fixture (fake counters.py with 1 unwired counter → expect exit 1 with the name).

4. **`tools/checks/banned_terms_python.py` extension** : add `--scan-jsonb-payload` mode :

```python
# In tools/checks/banned_terms_python.py
def scan_jsonb_payload(payload_file: str) -> int:
    """Scan a JSONB payload fixture file for banned terms in `value_enc.payload` + `confidence.enrichmentPrompts`."""
    import json
    data = json.loads(Path(payload_file).read_text())
    violations = []
    # Traverse value_enc.payload recursively
    payload = data.get("value_enc", {}).get("payload", {})
    text_blob = json.dumps(payload) + json.dumps(data.get("confidence", {}).get("enrichmentPrompts", []))
    for term in BANNED_TERMS:
        if term.lower() in text_blob.lower():
            violations.append(term)
    if violations:
        print(f"VIOLATION : banned terms in JSONB payload : {violations}")
        return 1
    return 0
```

5. **`services/backend/tests/compliance/test_event_log_banned_terms.py` (NEW)** : asserts fact_event row written with banned-term payload raises BannedTermsViolation at writer level (per Plan 02-04 Task 3 step 5 spec).

6. **lefthook.yml pre-push hook (~30s budget)** :

```yaml
pre-push:
  commands:
    declared-counters-must-fire:
      run: python3 tools/checks/declared_counters_must_fire.py
      glob: "services/backend/app/observability/*.py"
      fail_text: "A declared counter has no increment site OR doesn't fire in the representative scenario. Wire its site or mark fire-exempt with justification comment."
```

7. **Pre-push checklist** :
   - `python3 tools/checks/declared_counters_must_fire.py` exits 0 (all 9 counters fire + wired).
   - `cd services/backend && python3 -m pytest tests/observability/test_phase02_counters.py tests/compliance/test_event_log_banned_terms.py -q -k pg` exits 0.
   - `python3 tools/checks/banned_terms_python.py --scan-jsonb-payload services/backend/tests/fixtures/banned_payload.json` exits 1 (negative test on a seeded fixture).
   - Full backend pytest exits 0.
  </action>
  <verify>
    <automated>cd /Users/julienbattaglia/Desktop/MINT.nosync && python3 tools/checks/declared_counters_must_fire.py && cd services/backend && python3 -m pytest tests/observability/test_phase02_counters.py tests/compliance/test_event_log_banned_terms.py -q -k pg --timeout=120 && python3 -m pytest tests/ -q --timeout=180 && cd /Users/julienbattaglia/Desktop/MINT.nosync && python3 -m pytest tools/checks/tests/test_declared_counters_must_fire.py -q && grep -c "declared-counters-must-fire" lefthook.yml && python3 tools/checks/banned_terms_python.py services/backend/app/services/projector/</automated>
  </verify>
  <acceptance_criteria>
    - `python3 tools/checks/declared_counters_must_fire.py` exits 0 (9 counters fire ≥1 + wired in app/).
    - `cd services/backend && python3 -m pytest tests/observability/test_phase02_counters.py -q -k pg` exits 0.
    - `python3 -m pytest tools/checks/tests/test_declared_counters_must_fire.py -q` exits 0 (self-test).
    - `grep -c "declared-counters-must-fire" lefthook.yml` ≥ 1 (registered on pre-push).
    - `cd services/backend && python3 -m pytest tests/compliance/test_event_log_banned_terms.py -q -k pg` exits 0 (writer-level scan present).
    - `cd services/backend && python3 -m pytest tests/ -q --timeout=180` exits 0 (full regression).
    - `python3 tools/checks/banned_terms_python.py services/backend/app/` exits 0 (no banned terms in production code).
    - `grep -c "mint_snapshot_fact_current_drift_total" services/backend/app/cron/continuous_drift_sampler.py` ≥ 1 (counter wired in sampler from Plan 01 PR B — regression check).
  </acceptance_criteria>
  <done>
    Plan 02-04 Task 3 closed : declared_counters_must_fire HARD gate active ; 9 counters fire + wired ; LSFin banned-terms extended to fact_event JSONB ; writer-level scan blocks insertion.
  </done>
</task>

<task type="auto">
  <name>Task 4 (Plan 02-04 Task 4 + iter-2 B7 + C1) : 3 forward-deferred runbooks + Sentry alert runbook + Docker dep doc + sentry-alert-config + Backend README addendum</name>
  <files>
    docs/operations/fact-event-partition-split.md,
    docs/operations/dek-rotation-phase04.md,
    docs/operations/audit-pepper-rotation.md,
    docs/operations/sentry-alert-config.md,
    services/backend/README.md
  </files>
  <read_first>
    .planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-04-close-out-counters-runbooks-PLAN.md (Task 4 step 1-3 specs + iter-2 B7 PR-ordering rule lines 564-588 + iter-2 C1 Docker docs lines 622-654),
    docs/decisions/2026-05-17-data-architecture-event-log-vs-bitemporal.md (D-01 ADR),
    services/backend/scripts/preflight_zero_user_gate.py (referenced from audit-pepper-rotation rollback procedure)
  </read_first>
  <action>
1. **`docs/operations/fact-event-partition-split.md` (NEW, ≥50 lines + iter-2 C1 Docker addendum)** : verbatim per Plan 02-04 Task 4 step 1 spec — TL;DR + concrete thresholds (5M rows OR p99 > 15ms 7d sustained) + step-by-step CREATE PARTITION procedure + Prometheus alert spec + Rollback procedure + Counter-arguments and data gaps + iter-2 C1 Local development prerequisites (Docker availability check).

2. **`docs/operations/dek-rotation-phase04.md` (NEW, ≥40 lines)** : per Plan 02-04 Task 4 step 2 + RESEARCH §Open Q 4. Sections : TL;DR (Phase 02 stores dek_id per row for forward-compat ; rotation EXECUTION is Phase 04) + Trigger (EDÖB/FINMA inquiry, Railway FIPS 140-2 attestation, 1st paying CH user >100K CHF) + Step-by-step (generate MK v2 + iterate dek_vault rotate + decrypt path via dek_vault.kms_key_ref) + Rehearsal (Plan 02-02 Task 1 documents no-op rotation) + Counter-arguments + data gaps.

3. **`docs/operations/audit-pepper-rotation.md` (NEW, ≥50 lines + iter-2 B7 PR-ordering)** : per Plan 02-04 Task 4 step 3 + iter-2 B7 patch.
   - Sections : TL;DR + Trigger + Step-by-step + Rehearsal + PR-ordering rule (3-PR strict order : backfill → dual-read → drop+rename) + Freeze contract (FF_AUDIT_PEPPER_ROTATION_IN_PROGRESS=on during backfill window) + Rollback procedure + Counter-arguments + data gaps.

4. **`docs/operations/sentry-alert-config.md` (NEW, ≥30 lines)** (locked decision #5 — Julien-only UI task runbook) :

```markdown
# Sentry Alert Rule Configuration Runbook (Phase 02-deploy)

## TL;DR
Julien-only UI task. Configure Sentry alert rule for `mint_snapshot_fact_current_drift_total > 0 in 24h window` BEFORE Wave 2 PR-3b CHECKPOINT (Plan 03 Task 3) AND BEFORE Wave 4 prod cutover.

## Steps (Julien dashboard)
1. Open Sentry dashboard → Alerts → Metric Alerts → Create New Rule.
2. Metric : `mint_snapshot_fact_current_drift_total` (sum across labels).
3. Condition : `>` `0` in `24 hour window`.
4. Threshold : Trigger on first hit (no minimum dwell time).
5. Notification : Julien email + on-call team channel (per memory `feedback_pre_push_checklist`).
6. Save + verify : Sentry confirms rule active.

## Acceptance evidence
- Sentry rule URL captured in PERIMETERS.md ledger.
- Test invocation : manually emit a drift event via dev backend ; verify Sentry alert fires within 5 min.

## When to disable
After Phase 02-deploy completes + 30-day stable operation, the drift counter is expected to remain at 0. The alert rule stays ARMED indefinitely (low maintenance cost) as canary for any future regression.

## Counter-arguments and data gaps
- « We could automate this via Sentry API. » Tradeoff : 5min UI > 1h API setup + maintenance. Karpathy #2.
- Data gap : Sentry Metric Alert tier (depends on plan) — verify Julien plan supports metric alerts.
```

5. **`services/backend/README.md` extension** (per iter-2 C1) : add « Test harness setup (Phase 02 D-22) » section pointing to fact-event-partition-split.md for Docker dependency.

6. **wiki_lint compliance** : every new doc passes `python3 tools/checks/wiki_lint.py lint --strict` (counter-arguments + data gaps blocks present).

7. **Pre-push checklist** :
   - `python3 tools/checks/wiki_lint.py lint --strict` exits 0.
   - `python3 tools/checks/accent_lint_fr.py docs/operations/` exits 0.
   - `python3 tools/checks/banned_terms_python.py docs/operations/` exits 0.
   - `python3 tools/checks/no_legal_admission_in_public_docs.py docs/operations/` exits 0 (public-repo discipline per memory).
   - All 5 docs ≥ minimum line counts.
  </action>
  <verify>
    <automated>cd /Users/julienbattaglia/Desktop/MINT.nosync && python3 tools/checks/wiki_lint.py lint --strict && [ $(wc -l < docs/operations/fact-event-partition-split.md) -ge 50 ] && [ $(wc -l < docs/operations/dek-rotation-phase04.md) -ge 40 ] && [ $(wc -l < docs/operations/audit-pepper-rotation.md) -ge 50 ] && [ $(wc -l < docs/operations/sentry-alert-config.md) -ge 30 ] && python3 tools/checks/accent_lint_fr.py docs/operations/ && python3 tools/checks/banned_terms_python.py docs/operations/ && grep -q "PR-ordering rule" docs/operations/audit-pepper-rotation.md && grep -q "Test harness setup" services/backend/README.md && grep -q "Counter-arguments" docs/operations/fact-event-partition-split.md</automated>
  </verify>
  <acceptance_criteria>
    - `wc -l docs/operations/fact-event-partition-split.md` ≥ 50.
    - `wc -l docs/operations/dek-rotation-phase04.md` ≥ 40.
    - `wc -l docs/operations/audit-pepper-rotation.md` ≥ 50.
    - `wc -l docs/operations/sentry-alert-config.md` ≥ 30.
    - `grep -q "PR-ordering rule" docs/operations/audit-pepper-rotation.md` returns 0 (iter-2 B7 patch present).
    - `grep -q "Test harness setup" services/backend/README.md` returns 0 (iter-2 C1 addendum).
    - `grep -q "Counter-arguments" docs/operations/fact-event-partition-split.md` returns 0 (Karpathy wiki practice 2).
    - `python3 tools/checks/wiki_lint.py lint --strict` exits 0 (full-suite pass over .planning/ + docs/).
    - `python3 tools/checks/accent_lint_fr.py docs/operations/` exits 0.
    - `python3 tools/checks/no_legal_admission_in_public_docs.py docs/operations/` exits 0 (public-repo discipline).
  </acceptance_criteria>
  <done>
    Plan 02-04 Task 4 closed : 3 forward-deferred runbooks (partition + DEK + pepper) + Sentry alert runbook + Backend README harness setup section. All wiki_lint + accent + LSFin + public-repo lints green.
  </done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <name>Task 5 (Mobile L1 design panel BEFORE push) : 4-person design panel verdict for sub-PR A4a per memory `feedback_design_panel_before_push`</name>
  <files>N/A — checkpoint task ; no file mutation by Claude. Julien runs verification steps + types resume-signal.</files>
  <what-built>
    Pre-built : design panel input package for the 4-person review (UX + a11y + adversarial + engineering) covering :
    - DEFERRED-02-02-C : 1-line lefthook wiring for `no_mobile_fact_current_regulatory_read.py` HARD pre-commit gate
    - DEFERRED-02-02-E : `apps/mobile/lib/main.dart` MobileL1AuditLifecycleObserver wiring + `WidgetsBinding.instance.addObserver(lifecycle)` + `await lifecycle.recordColdStart()` on bootstrap
    - DEFERRED-02-02-F : connectivity_plus integration via main.dart caller (listens to stream + invokes `audit.flush()` on connectivity restore)

    Out of scope for THIS sub-PR (A4a) : sqflite_sqlcipher production AuditBufferDb (sub-PR A4b isolated per locked decision #5 + memory `feedback_ios_entitlements_block_testflight`).
  </what-built>
  <action>
    Checkpoint task — Claude executes no file mutation here. The atomic
    operations (PR builds, evidence file generation, code commits) all live
    in the preceding `type="auto"` tasks of this plan. This checkpoint task
    pauses execution until Julien types the `resume-signal` after running
    the verification steps listed in `<how-to-verify>` below.
  </action>
  <how-to-verify>
    **Julien spawns 4-person design panel** (per memory `feedback_design_panel_before_push`, parallel sub-agent invocation) :

    1. **UX panel agent** (`frontend-developer` + `mobile-developer`) :
       - Review main.dart bootstrap sequence : does `recordColdStart()` block the splash screen?
       - Review connectivity_plus listener placement : is `audit.flush()` debounced to avoid burst writes on flapping connectivity?
       - Verdict : PASS / BLOCKED with concerns.

    2. **a11y panel agent** (`accessibility-expert`) :
       - Any user-facing string change? (Should be ZERO — Mobile L1 audit is non-visual.)
       - Verify no telemetry emissions occur during accessibility-tooling navigation modes.
       - Verdict : PASS / BLOCKED.

    3. **Adversarial panel agent** (`security-auditor` + `threat-modeling-expert`) :
       - Threat : can a malicious connectivity_plus event trigger audit drain on attacker-controlled network?
       - Threat : main.dart observer wiring order — does it run BEFORE or AFTER Sentry init?
       - Verify offline queue does NOT contain PII (per RESEARCH §Security Domain row 6).
       - Verdict : PASS / BLOCKED.

    4. **Engineering panel agent** (`architect-review`) :
       - Wiring quality : does main.dart respect existing observer chain order?
       - Surface minimality : 1-line lefthook addition OK per DEFERRED-02-02-C reason-out-of-scope rationale.
       - Tests : 3 new flutter test files (lifecycle_observer + connectivity_drain + sqlite_buffer_full per Plan 02-04 Task 5 D-30 race tests).
       - Verdict : PASS / BLOCKED.

    5. **Record verdict in `.planning/phases/mint-data-architecture-v1-02-deploy/mobile-l1-design-panel-verdict.md`** :

```markdown
# Mobile L1 Sub-PR A4a — 4-Person Design Panel Verdict ($(date -u +%Y-%m-%d))

Per memory `feedback_design_panel_before_push` — verdict recorded BEFORE push.

## Panel members
1. UX : {frontend-developer + mobile-developer} — Verdict : PASS / BLOCKED ({rationale})
2. a11y : {accessibility-expert} — Verdict : PASS / BLOCKED ({rationale})
3. Adversarial : {security-auditor + threat-modeling-expert} — Verdict : PASS / BLOCKED ({rationale})
4. Engineering : {architect-review} — Verdict : PASS / BLOCKED ({rationale})

## Overall verdict
{PASS / BLOCKED}

If any panel BLOCKED : Claude applies fix-up commits before push.

## Engram observation
prior_finding_refs : Plan 02-02 substrate Mobile L1 obs, DEFERRED-02-02-C/D/E/F items
```

    **Gate decision** :
    - All 4 PASS → Julien types `approved mobile-L1 sub-PR A4a — 4-panel verdict PASS` → Claude opens sub-PR A4a + pushes.
    - Any BLOCKED → describe + Claude applies fix-up commits + re-runs panel → returns to this CHECKPOINT.
  </how-to-verify>
  <verify>
    <automated>echo "Checkpoint task — verification is manual by Julien per <how-to-verify> ; this <verify> stub is a structural placeholder. Resume blocked until <resume-signal> received."</automated>
  </verify>
  <done>
    Julien types the resume-signal after running the <how-to-verify> steps successfully. Claude proceeds to the next task (or records sign-off in PERIMETERS.md per task spec).
  </done>
  <resume-signal>
    Type "approved mobile-L1 sub-PR A4a — 4-panel verdict PASS" OR describe panel BLOCKED issues for fix-up.
  </resume-signal>
</task>

<task type="auto" tdd="true">
  <name>Task 6 (Sub-PR A4a) : Mobile L1 device wiring Dart-only — DEFERRED-02-02-C lefthook + DEFERRED-02-02-E main.dart observer + DEFERRED-02-02-F connectivity_plus + D-30 race tests</name>
  <files>
    apps/mobile/lib/main.dart,
    apps/mobile/lib/services/audit/offline_audit_queue.dart,
    apps/mobile/pubspec.yaml,
    lefthook.yml,
    apps/mobile/test/services/audit/test_two_device_offline_to_online.dart,
    apps/mobile/test/services/audit/test_clock_skew_uuid7_ordering.dart,
    apps/mobile/test/services/audit/test_anonymous_session_reinstall_orphan.dart,
    apps/mobile/test/services/audit/test_sqlite_buffer_full_low_storage.dart,
    services/backend/tests/integration/test_projector_out_of_order_event_id.py,
    services/backend/tests/integration/test_anonymous_session_reinstall_orphan_backend.py
  </files>
  <read_first>
    apps/mobile/lib/main.dart (current bootstrap sequence — observer chain order to respect),
    apps/mobile/lib/services/audit/mobile_l1_audit_lifecycle_observer.dart (Plan 02-02 — class shipped, NOT wired),
    apps/mobile/lib/services/audit/offline_audit_queue.dart (Plan 02-02 — connectivity-agnostic drain),
    apps/mobile/pubspec.yaml (add connectivity_plus + flutter_secure_storage),
    tools/checks/no_mobile_fact_current_regulatory_read.py (DEFERRED-02-02-C lint),
    .planning/phases/mint-data-architecture-v1-02-deploy/mobile-l1-design-panel-verdict.md (panel PASS verdict from Task 5),
    .planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-04-close-out-counters-runbooks-PLAN.md (iter-2 Task 5 D-30 race tests spec lines 657-697)
  </read_first>
  <behavior>
    - test_two_device_offline_to_online : 2 devices offline → both queue events → both online simultaneously → server UNIQUE constraint blocks dups + both batches return 200.
    - test_clock_skew_uuid7_ordering : clock skews backward 1h → UUID v7 inversion → projector skips per event_id ≤ latest_event_id (trade-off documented).
    - test_anonymous_session_reinstall_orphan : app wipe + reinstall → new UUID v7 generated → no re-link of old session.
    - test_sqlite_buffer_full_low_storage : SQLite full → audit row LOST gracefully + counter increment + no crash.
    - test_projector_out_of_order_event_id : backend-side clock-skew inversion test.
    - test_anonymous_session_reinstall_orphan_backend : orphan row stays with user_id_hash=NULL.
  </behavior>
  <action>
1. **Verify Task 5 panel verdict PASS** :

```bash
grep -q "approved mobile-L1 sub-PR A4a — 4-panel verdict PASS" .planning/phases/mint-data-architecture-v1-02-deploy/mobile-l1-design-panel-verdict.md || { echo "BLOCKED: panel verdict not PASS" ; exit 1 ; }
```

2. **Open sub-PR A4a branch** :

```bash
git checkout -b feat/p02-deploy-mobile-l1-a4a-dart-wiring
```

3. **DEFERRED-02-02-C lefthook wiring** (1-line addition) :

```yaml
# lefthook.yml — pre-commit
no-mobile-fact-current-regulatory-read:
  glob: "apps/mobile/lib/**/*.dart"
  run: python3 tools/checks/no_mobile_fact_current_regulatory_read.py
  fail_text: "Mobile L1 audit boundary : do not read fact_current/regulatory_constants from Dart layer — use coach API only."
```

4. **DEFERRED-02-02-E main.dart observer wiring** — verbatim per Plan 02-04 iter-2 spec :

```dart
// apps/mobile/lib/main.dart
import 'package:flutter/widgets.dart';
import 'package:mint/services/audit/mobile_l1_audit_lifecycle_observer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // ... existing init (Sentry, Engram, FeatureFlags) ...

  final auditLifecycle = MobileL1AuditLifecycleObserver();
  WidgetsBinding.instance.addObserver(auditLifecycle);
  await auditLifecycle.recordColdStart();

  // ... existing runApp(...) ...
}
```

5. **DEFERRED-02-02-F connectivity_plus integration** (caller-side, NOT inside OfflineAuditQueue per Karpathy #3) :

```dart
// apps/mobile/lib/main.dart (after observer wiring)
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:mint/services/audit/offline_audit_queue.dart';

Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
  if (result != ConnectivityResult.none) {
    OfflineAuditQueue.instance.flush();  // debounced internally
  }
});
```

6. **`apps/mobile/pubspec.yaml`** : `flutter pub add connectivity_plus flutter_secure_storage` (the secure_storage is needed for sub-PR A4b BUT shipped in A4a pubspec to avoid late dep update — flutter_secure_storage doesn't add iOS entitlement on its own).

7. **D-30 race tests (iter-2 Task 5)** : ship the 4 Flutter + 2 Python tests per verbatim spec.

8. **flutter gen-l10n** : run if any new ARB key added (likely zero — Mobile L1 is non-visual).

9. **Pre-push checklist** :
   - `cd apps/mobile && flutter analyze && flutter test` exits 0.
   - `cd apps/mobile && flutter test test/services/audit/ -r expanded` exits 0 (all 4 D-30 tests pass).
   - `cd services/backend && python3 -m pytest tests/integration/test_projector_out_of_order_event_id.py tests/integration/test_anonymous_session_reinstall_orphan_backend.py -q -k pg` exits 0.
   - `python3 tools/checks/validate_arb_parity.py` exits 0 (no ARB regression).
   - `python3 tools/checks/no_mobile_fact_current_regulatory_read.py apps/mobile/lib/` exits 0 (regression check).
   - `git grep -n "WidgetsBinding.instance.addObserver(auditLifecycle)" apps/mobile/lib/main.dart` returns 1 hit.
   - `git grep -n "connectivity_plus" apps/mobile/lib/main.dart apps/mobile/pubspec.yaml` returns ≥ 2 hits.

10. **Commit + open sub-PR A4a** :

```bash
git add lefthook.yml apps/mobile/lib/main.dart apps/mobile/lib/services/audit/offline_audit_queue.dart apps/mobile/pubspec.yaml apps/mobile/test/services/audit/ services/backend/tests/integration/test_projector_out_of_order_event_id.py services/backend/tests/integration/test_anonymous_session_reinstall_orphan_backend.py
git commit -m "feat(p02-deploy): sub-PR A4a Mobile L1 Dart wiring (DEFERRED-02-02-C/E/F + D-30 race tests)

Per locked decision Open-Q #5 + memory feedback_ios_entitlements_block_testflight :
- A4a = Dart-only wiring (NO iOS plist change)
- A4b = sqflite_sqlcipher prod impl + Runner.entitlements (ISOLATED PR, ships next)

4-person design panel verdict PASS (UX + a11y + adversarial + engineering)
recorded in .planning/phases/mint-data-architecture-v1-02-deploy/mobile-l1-design-panel-verdict.md.

Closes :
- DEFERRED-02-02-C (lefthook wiring for no_mobile_fact_current_regulatory_read.py)
- DEFERRED-02-02-E (main.dart MobileL1AuditLifecycleObserver wiring + recordColdStart)
- DEFERRED-02-02-F (connectivity_plus listener in main.dart caller)
- D-30 race tests (4 Flutter + 2 Python — Pitfall 3/5/6 from RESEARCH)

Engram prior_finding_refs : Plan 02-02 Mobile L1 substrate obs, panel verdict, #194."
gh pr create --base dev --head feat/p02-deploy-mobile-l1-a4a-dart-wiring --title "feat(p02-deploy): sub-PR A4a Mobile L1 Dart wiring (DEFERRED-02-02-C/E/F + D-30 race tests)" --body "..."
```
  </action>
  <verify>
    <automated>cd /Users/julienbattaglia/Desktop/MINT.nosync && grep -q "approved mobile-L1 sub-PR A4a" .planning/phases/mint-data-architecture-v1-02-deploy/mobile-l1-design-panel-verdict.md && cd apps/mobile && flutter analyze && flutter test -r expanded 2>&1 | tail -20 && cd /Users/julienbattaglia/Desktop/MINT.nosync && cd services/backend && python3 -m pytest tests/integration/test_projector_out_of_order_event_id.py tests/integration/test_anonymous_session_reinstall_orphan_backend.py -q -k pg --timeout=120 && cd /Users/julienbattaglia/Desktop/MINT.nosync && python3 tools/checks/validate_arb_parity.py && python3 tools/checks/no_mobile_fact_current_regulatory_read.py apps/mobile/lib/ && git grep -c "WidgetsBinding.instance.addObserver" apps/mobile/lib/main.dart && git grep -c "connectivity_plus" apps/mobile/pubspec.yaml</automated>
  </verify>
  <acceptance_criteria>
    - `grep "approved mobile-L1 sub-PR A4a — 4-panel verdict PASS" .planning/phases/mint-data-architecture-v1-02-deploy/mobile-l1-design-panel-verdict.md` returns 0 (verdict recorded).
    - `grep -c "WidgetsBinding.instance.addObserver" apps/mobile/lib/main.dart` ≥ 1 (observer wired).
    - `grep -c "recordColdStart" apps/mobile/lib/main.dart` ≥ 1 (called on bootstrap).
    - `grep -c "connectivity_plus" apps/mobile/lib/main.dart` ≥ 1 (listener in main.dart).
    - `grep -c "connectivity_plus" apps/mobile/pubspec.yaml` ≥ 1 (dep added).
    - `grep -c "no-mobile-fact-current-regulatory-read" lefthook.yml` ≥ 1 (lint registered).
    - `cd apps/mobile && flutter analyze && flutter test` exits 0.
    - 4 Flutter test files in `apps/mobile/test/services/audit/` exit 0 (test_two_device + test_clock_skew + test_anonymous_session_reinstall + test_sqlite_buffer_full).
    - 2 Python integration test files in `services/backend/tests/integration/` exit 0 with `-k pg`.
    - `python3 tools/checks/validate_arb_parity.py` exits 0.
    - `python3 tools/checks/no_mobile_fact_current_regulatory_read.py apps/mobile/lib/` exits 0 (lint passes against current code — no regulatory_constants reads in Dart).
    - **NO iOS plist change in this PR** — `git diff apps/mobile/ios/` shows 0 changes to Runner.entitlements + Info.plist (deferred to sub-PR A4b).
    - sub-PR A4a PR opened.
  </acceptance_criteria>
  <done>
    Sub-PR A4a shipped : DEFERRED-02-02-C/E/F + D-30 race tests + 4-panel verdict PASS. NO iOS plist change. Sub-PR A4b (sqflite_sqlcipher + iOS entitlement isolated) ships next.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 7 (Sub-PR A4b ISOLATED iOS) : DEFERRED-02-02-D sqflite_sqlcipher production AuditBufferDb + Runner.entitlements + fastlane match</name>
  <files>
    apps/mobile/lib/services/audit/audit_buffer_db.dart,
    apps/mobile/ios/Runner/Runner.entitlements,
    apps/mobile/ios/fastlane/Matchfile,
    apps/mobile/integration_test/audit_buffer_db_sqlcipher_test.dart
  </files>
  <read_first>
    apps/mobile/lib/services/audit/audit_buffer_db.dart (Plan 02-02 — abstract interface + InMemoryAuditBufferDb fallback ; Task 7 ships sqflite_sqlcipher backed prod impl),
    apps/mobile/ios/Runner/Runner.entitlements (current — no Keychain entitlement),
    apps/mobile/ios/fastlane/Matchfile (current — needs profile update),
    .planning/phases/mint-data-architecture-v1-02-deploy/mint-data-architecture-v1-02-deploy-RESEARCH.md (§Pattern Don't-Hand-Roll sqflite_sqlcipher + flutter_secure_storage row),
    .planning/phases/mint-data-architecture-v1-02-event-log-projection/deferred-items.md (DEFERRED-02-02-D 'iOS production deploy requires (a) CocoaPods spec validation, (b) Keychain entitlement, (c) physical-device verification')
  </read_first>
  <behavior>
    - test_audit_buffer_db_sqlcipher : open SQLCipher db with Keychain-derived passphrase → write 100 audit events → close db → reopen → read same 100 events → assert content preserved + DB encrypted-at-rest (raw file does NOT contain plaintext event content).
  </behavior>
  <action>
1. **Verify sub-PR A4a merged on dev** :

```bash
gh pr view <A4a-PR-NUM> --json mergedAt --jq '.mergedAt' | grep -qE "^[0-9]" || exit 1
```

2. **Open sub-PR A4b ISOLATED branch** :

```bash
git checkout -b feat/p02-deploy-mobile-l1-a4b-ios-entitlement
```

3. **Ship `apps/mobile/lib/services/audit/audit_buffer_db.dart` production impl** (replaces InMemoryAuditBufferDb as default) :

```dart
// SqliteSqlcipherAuditBufferDb extends AuditBufferDb (abstract)
// Uses sqflite_sqlcipher + flutter_secure_storage for Keychain passphrase.

class SqliteSqlcipherAuditBufferDb implements AuditBufferDb {
  static const String _passphraseKey = 'mint_audit_buffer_passphrase_v1';
  late Database _db;

  Future<void> open() async {
    final secureStorage = FlutterSecureStorage();
    String? passphrase = await secureStorage.read(key: _passphraseKey);
    if (passphrase == null) {
      passphrase = _generateRandomPassphrase();  // 32-byte secure random
      await secureStorage.write(key: _passphraseKey, value: passphrase);
    }
    _db = await openDatabase(
      'mint_audit_buffer.db',
      password: passphrase,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('CREATE TABLE audit_events (id INTEGER PRIMARY KEY AUTOINCREMENT, event_id TEXT NOT NULL, payload TEXT NOT NULL, created_at INTEGER NOT NULL)');
      },
    );
  }

  // ... insert / drain / close methods ...
}
```

4. **`apps/mobile/ios/Runner/Runner.entitlements`** : add Keychain access entitlement :

```xml
<dict>
  <!-- Existing entitlements -->
  <key>keychain-access-groups</key>
  <array>
    <string>$(AppIdentifierPrefix)com.mint.app</string>
  </array>
  <!-- com.apple.developer.* if any specific Apple-domain entitlement (review per Apple Developer portal) -->
</dict>
```

5. **`apps/mobile/ios/fastlane/Matchfile`** : update profile reference for the new entitlement (per memory `feedback_ios_entitlements_block_testflight`).

6. **`apps/mobile/integration_test/audit_buffer_db_sqlcipher_test.dart`** : end-to-end SQLCipher test on iOS sim (Maestro for device verification optional).

7. **CRITICAL Julien manual step** (sub-PR A4b body explicitly states) :
   - Julien must update Apple Developer portal capability sheet (add Keychain access).
   - Julien must run `bundle exec fastlane match development` to regenerate provisioning profile.
   - Sub-PR A4b CANNOT merge until both portal + match are updated.

8. **Pre-push checklist** :
   - `cd apps/mobile && flutter pub get` exits 0.
   - `cd apps/mobile && flutter analyze && flutter test` exits 0.
   - `cd apps/mobile && flutter test integration_test/audit_buffer_db_sqlcipher_test.dart` exits 0 (requires sim booted ; mark deferred if not booted).
   - `git diff apps/mobile/ios/` shows ONLY entitlement + matchfile changes (no other ios/ changes).

9. **Commit + open sub-PR A4b** :

```bash
git add apps/mobile/lib/services/audit/audit_buffer_db.dart apps/mobile/ios/Runner/Runner.entitlements apps/mobile/ios/fastlane/Matchfile apps/mobile/integration_test/audit_buffer_db_sqlcipher_test.dart
git commit -m "feat(p02-deploy): sub-PR A4b ISOLATED — sqflite_sqlcipher prod AuditBufferDb + iOS Keychain entitlement

ISOLATED PR per memory feedback_ios_entitlements_block_testflight + locked
decision Open-Q #5 :
- Adds com.apple.security.application-groups + keychain-access-groups entitlement
- Updates fastlane match profile reference
- Replaces InMemoryAuditBufferDb default with SqliteSqlcipherAuditBufferDb

JULIEN MANUAL STEPS REQUIRED BEFORE MERGE :
1. Apple Developer portal → add Keychain capability to com.mint.app App ID
2. bundle exec fastlane match development (regenerates provisioning profile)
3. Verify match profile checked in (apps/mobile/ios/fastlane/Matchfile updated)

DOES NOT MERGE WITHOUT JULIEN MANUAL STEPS COMPLETE.

Closes DEFERRED-02-02-D. Engram : prior_finding_refs sub-PR A4a obs, design panel verdict, #194."
gh pr create --base dev --head feat/p02-deploy-mobile-l1-a4b-ios-entitlement --title "feat(p02-deploy): sub-PR A4b ISOLATED — sqflite_sqlcipher prod + iOS entitlement (JULIEN MANUAL STEPS)" --body "$(cat <<EOF
## Summary
Isolated PR per memory \`feedback_ios_entitlements_block_testflight\` — any new \`com.apple.developer.*\` key or Keychain entitlement is release-blocking and must ship in own PR.

## JULIEN MANUAL STEPS REQUIRED BEFORE MERGE
1. Apple Developer portal → add Keychain access capability to com.mint.app App ID
2. \`bundle exec fastlane match development\` to regenerate provisioning profile
3. Verify match profile updated + committed

## Tests
- flutter test integration_test/audit_buffer_db_sqlcipher_test.dart (requires sim booted ; DEFERRED if no sim)
EOF
)"
```
  </action>
  <verify>
    <automated>cd /Users/julienbattaglia/Desktop/MINT.nosync && [ -f apps/mobile/lib/services/audit/audit_buffer_db.dart ] && grep -c "SqliteSqlcipherAuditBufferDb\|sqflite_sqlcipher" apps/mobile/lib/services/audit/audit_buffer_db.dart && grep -c "keychain-access-groups" apps/mobile/ios/Runner/Runner.entitlements && cd apps/mobile && flutter pub get && flutter analyze && flutter test && cd /Users/julienbattaglia/Desktop/MINT.nosync && [ $(git diff apps/mobile/ios/ | grep -E "^\+" | grep -v "keychain-access-groups\|Matchfile" | wc -l) -lt 10 ]</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "SqliteSqlcipherAuditBufferDb" apps/mobile/lib/services/audit/audit_buffer_db.dart` ≥ 1.
    - `grep -c "sqflite_sqlcipher" apps/mobile/pubspec.yaml` ≥ 1.
    - `grep -c "flutter_secure_storage" apps/mobile/pubspec.yaml` ≥ 1.
    - `grep -c "keychain-access-groups" apps/mobile/ios/Runner/Runner.entitlements` ≥ 1.
    - `cd apps/mobile && flutter analyze && flutter test` exits 0.
    - PR body explicitly lists Julien manual steps (Apple Developer portal + fastlane match).
    - PR is ISOLATED — `git diff apps/mobile/ios/` shows ONLY entitlement + Matchfile changes (no other Runner.swift or AppDelegate edits).
    - Sub-PR A4b PR opened.
    - PR body cites memory `feedback_ios_entitlements_block_testflight`.
  </acceptance_criteria>
  <done>
    Sub-PR A4b ISOLATED shipped : sqflite_sqlcipher prod impl + Keychain entitlement + fastlane Matchfile update. JULIEN manual steps documented in PR body — merge requires Julien Apple Developer portal action + fastlane match regen.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 8 (5 sec/arch FLAGs) : sec FLAG-2 + sec FLAG-4 + sec FLAG-5 + arch FLAG-3 (FLAG-2 UUID7 doc-only)</name>
  <files>
    services/backend/tests/compliance/test_event_log_no_quasi_identifier.py,
    services/backend/tests/integration/test_dsar_event_log_inclusion.py,
    services/backend/tests/integration/test_event_log_baseline_trim.py,
    tools/checks/subject_type_forward_lint.py,
    tools/checks/tests/test_subject_type_forward_lint.py,
    lefthook.yml,
    docs/operations/audit-pepper-rotation.md
  </files>
  <read_first>
    .planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-REVIEWS.md (QA panel #655 FLAGs detail),
    services/backend/app/services/projector/fact_projector.py (fact_event payload write site for sec FLAG-2),
    services/backend/app/api/v1/endpoints/users.py (DSAR endpoint for sec FLAG-4),
    .planning/phases/mint-data-architecture-v1-02-deploy/mint-data-architecture-v1-02-deploy-RESEARCH.md (§Security-Domain + threat patterns)
  </read_first>
  <behavior>
    - sec FLAG-2 test_event_log_no_quasi_identifier : seed fact_event with payload `{"postal_code": "1003", "birth_date": "1985-01-01", "canton": "VD"}` → assert writer either scrubs or rejects.
    - sec FLAG-4 test_dsar_event_log_inclusion : POST /v1/users/dsar for user U → response includes fact_event entries for U.
    - sec FLAG-5 test_event_log_baseline_trim : for pre-Phase-02 users (created before fact_event substrate), assert event_log size bounded ≤ N (no balloon-on-cutover).
    - arch FLAG-3 subject_type_forward_lint : AST walk → catches `subject_type='user'` literal without registry check ; HARD lefthook ; self-test fixtures.
  </behavior>
  <action>
1. **sec FLAG-2** : create `services/backend/tests/compliance/test_event_log_no_quasi_identifier.py` — verify writer scrubs/rejects quasi-identifier payloads.

2. **sec FLAG-4** : create `services/backend/tests/integration/test_dsar_event_log_inclusion.py` (`@pytest.mark.requires_pg`). If endpoint MISSING the inclusion : extend `services/backend/app/api/v1/endpoints/users.py` DSAR handler to include `SELECT * FROM fact_event WHERE user_id = :u` rows.

3. **sec FLAG-5** : create `services/backend/tests/integration/test_event_log_baseline_trim.py` — for pre-Phase-02 user, assert fact_event row count ≤ expected bound.

4. **arch FLAG-2 (UUID4→UUID7 DOC-ONLY)** : DECOUPLED Phase 03 per locked decision. Audit-pepper-rotation.md runbook references forward-compat path. NO code change.

5. **arch FLAG-3** : create `tools/checks/subject_type_forward_lint.py` AST lint :

```python
# Scans services/backend/ for `subject_type='user'` or `subject_type="user"` string literals
# without preceding/following registry lookup (e.g., REGISTRY[subject_type]).
# Exit 1 with file:line hits, 0 if clean.
```

6. **Self-tests** : `tools/checks/tests/test_subject_type_forward_lint.py` good + bad fixtures.

7. **lefthook.yml** : add `subject-type-forward-lint` pre-commit rule.

8. **Pre-push checklist** :
   - `cd services/backend && python3 -m pytest tests/compliance/test_event_log_no_quasi_identifier.py tests/integration/test_dsar_event_log_inclusion.py tests/integration/test_event_log_baseline_trim.py -q -k pg` exits 0.
   - `python3 tools/checks/subject_type_forward_lint.py services/backend/` exits 0.
   - `python3 -m pytest tools/checks/tests/test_subject_type_forward_lint.py -q` exits 0.
   - `grep -c "subject-type-forward-lint" lefthook.yml` ≥ 1.
   - Full backend pytest exits 0.
  </action>
  <verify>
    <automated>cd /Users/julienbattaglia/Desktop/MINT.nosync && cd services/backend && python3 -m pytest tests/compliance/test_event_log_no_quasi_identifier.py tests/integration/test_dsar_event_log_inclusion.py tests/integration/test_event_log_baseline_trim.py -q -k pg --timeout=120 && cd /Users/julienbattaglia/Desktop/MINT.nosync && python3 tools/checks/subject_type_forward_lint.py services/backend/ && python3 -m pytest tools/checks/tests/test_subject_type_forward_lint.py -q && grep -c "subject-type-forward-lint" lefthook.yml && grep -q "UUID v7" docs/operations/audit-pepper-rotation.md && cd services/backend && python3 -m pytest tests/ -q --timeout=180</automated>
  </verify>
  <acceptance_criteria>
    - 3 sec FLAG tests exit 0 with `-k pg`.
    - `python3 tools/checks/subject_type_forward_lint.py services/backend/` exits 0 (existing code clean) OR exit 1 with documented violations to fix.
    - `python3 -m pytest tools/checks/tests/test_subject_type_forward_lint.py -q` exits 0 (self-test green).
    - `grep -c "subject-type-forward-lint" lefthook.yml` ≥ 1.
    - arch FLAG-2 UUID4 → UUID7 forward-compat documented in `docs/operations/audit-pepper-rotation.md` (or `dek-rotation-phase04.md`).
    - Full backend pytest exits 0.
  </acceptance_criteria>
  <done>
    5 sec/arch FLAGs disposed : sec FLAG-2/4/5 + arch FLAG-3 shipped via tests + lint ; arch FLAG-2 UUID4→UUID7 decoupled to Phase 03 with doc reference in runbooks.
  </done>
</task>

<task type="auto">
  <name>Task 9 (DEFERRED-02-01-A verification + PR D polish absorbed) : Alembic dual-head merge check + 6 PR-D polish items (excluding sec FLAG-1 deletion)</name>
  <files>
    services/backend/alembic/versions/p122_merge_p86_eclairage_into_p120.py,
    services/backend/app/services/projector/fact_projector.py,
    services/backend/app/services/snapshots/snapshot_service.py,
    services/backend/app/services/feature_flags.py,
    services/backend/app/models/audit_event.py
  </files>
  <read_first>
    .planning/phases/mint-data-architecture-v1-02-deploy/chain-audit.txt (Plan 01 Task 4 output — confirms whether p98_merge_p86_eclairage already absorbs the dual-head),
    services/backend/alembic/versions/ (full inventory to check current heads),
    .planning/phases/mint-data-architecture-v1-02-deploy/HANDOFF-2026-05-19.md (PR D items 1-8 — item 7 EXCLUDED),
    services/backend/app/services/projector/fact_projector.py (sec FLAG-1 lines 151-181 — DO NOT TOUCH per locked decision #sec-flag-1-preservation)
  </read_first>
  <action>
1. **DEFERRED-02-01-A check** :

```bash
cd services/backend
alembic heads | tee /tmp/alembic_heads.txt
# Expected : single head ; if 2 heads, merge needed.

if [ $(wc -l < /tmp/alembic_heads.txt) -gt 1 ]; then
  echo "Two heads present — shipping p122 merge migration"
  # Create p122_merge_p86_eclairage_into_p120.py
else
  echo "Single head — DEFERRED-02-01-A already absorbed by p98_merge_p86_eclairage (Plan 01 Task 4 confirmed)"
  # No code change ; document in SUMMARY
fi
```

2. **PR D polish items 1-6 + 8** (item 7 sec FLAG-1 deletion EXCLUDED) :

   a. **TIMESTAMPTZ → DateTime(timezone=True) in p98 ORM** (postgres-pro MED soft) : update `services/backend/app/models/fact_event.py` if applicable.

   b. **Rename `read_monthly_gross_income` → `read_gross_income_fact`** in FactCurrent ORM + grep all callers + update + regen OpenAPI canonical.

   c. **Consolidate `feature_flags.py` double resolution path** — verify single resolution path post-PR-4 FF removal.

   d. **Drop `_payload_hashes` duplicate output_hash** in fact_projector — surface review needed (likely SAFE).

   e. **Refactor `fact_projector.project_event` (103 LOC → ~50)** — hoist `import json` to module level + extract helper functions. **DO NOT touch lines 151-181 sec FLAG-1 per locked decision.**

   f. **Refactor `snapshot_service.create_snapshot` (150 LOC → 3 functions)** — extract `_validate_inputs()` + `_persist_snapshot()` + `_invalidate_cache()` helpers.

   g. **DELETE orphan staging Postgres service** — Julien-only operational task ; surface in SUMMARY with audit step (`railway variables -e staging --service MINT | grep -i postgres-orphan-service-name` returns 0 lines) + Julien runs `railway service delete <orphan-service-id>` after confirmation.

3. **Skipped** : Item 7 (delete sec FLAG-1 post-write divergence assertion) per locked decision #sec-flag-1-preservation.

4. **Pre-push checklist per item** :
   - Each refactor preserves behavior : full pytest exits 0 BEFORE and AFTER.
   - `grep -rn "read_monthly_gross_income" services/backend apps/mobile` returns 0 hits post-rename (all callers updated).
   - `python3 services/backend/scripts/generate_canonical.py` exits 0 (OpenAPI regen).
  </action>
  <verify>
    <automated>cd /Users/julienbattaglia/Desktop/MINT.nosync && cd services/backend && alembic heads | wc -l && python3 -m pytest tests/ -q --timeout=180 && cd /Users/julienbattaglia/Desktop/MINT.nosync && [ $(git grep -rn "read_monthly_gross_income" services/backend apps/mobile | wc -l) -eq 0 ] && grep -c "post-write divergence" services/backend/app/services/projector/fact_projector.py && python3 services/backend/scripts/generate_canonical.py</automated>
  </verify>
  <acceptance_criteria>
    - `alembic heads` returns single head (either pre-existing or after p122 merge).
    - `git grep -rn "read_monthly_gross_income" services/backend apps/mobile` returns 0 hits (rename complete).
    - `grep -c "post-write divergence" services/backend/app/services/projector/fact_projector.py` ≥ 1 (sec FLAG-1 PRESERVED per locked decision).
    - `services/backend/app/services/projector/fact_projector.py` LOC ≤ original count (refactor reduced surface).
    - `services/backend/app/services/snapshots/snapshot_service.py` `create_snapshot` function ≤ 50 LOC (extracted helpers).
    - `services/backend/app/services/feature_flags.py` has SINGLE resolution path (post-PR-4 FF removal).
    - Full backend pytest exits 0 (no behavior regression).
    - `python3 services/backend/scripts/generate_canonical.py` exits 0 (OpenAPI canonical regenerated).
    - SUMMARY surfaces orphan staging Postgres delete as outstanding Julien manual task.
  </acceptance_criteria>
  <done>
    DEFERRED-02-01-A verified (single head OR p122 merge shipped). PR D polish items 1-6 + 8 absorbed (item 7 sec FLAG-1 EXCLUDED per locked decision). Refactors preserve behavior. Orphan staging Postgres delete surfaced.
  </done>
</task>

<task type="auto">
  <name>Task 10 (Wave 4 prod migration apply) : Apply alembic chain to production + Task 2a-equivalent operational gate against prod</name>
  <files>
    .planning/phases/mint-data-architecture-v1-02-deploy/prod-task-2a-evidence.txt,
    tools/db/baselines/production-{date}-pre-deploy.sql.gz
  </files>
  <read_first>
    .planning/phases/mint-data-architecture-v1-02-deploy/chain-audit.txt (Plan 01 Task 4 — 14 revs prod→dev),
    .planning/phases/mint-data-architecture-v1-02-deploy/mint-data-architecture-v1-02-deploy-02-staging-migration-apply-PLAN.md (Wave 1 sequence — repeat against prod),
    tools/db/railway_pg_dump.sh (Plan 01 PR B),
    services/backend/scripts/preflight_zero_user_gate.py (will return BLOCKED with 2 prod users — Julien override documented per CONTEXT line 41)
  </read_first>
  <action>
1. **Verify all Wave 3 PRs merged** :
   - Plan 04 Task 1 (S12 + dead-fields)
   - Task 2 (Q6 CI)
   - Task 3 (declared_counters)
   - Task 4 (runbooks)
   - Sub-PR A4a + A4b (Mobile L1)
   - Task 8 (5 FLAGs)
   - Task 9 (DEFERRED-02-01-A + PR D polish)

```bash
gh pr list --state merged --search "p02-deploy" --json mergedAt,title | jq length
# Expected : 8+ PRs merged
```

2. **Capture fresh pre-Wave-4 prod baseline pg_dump** (Plan 01 captured early but re-capture immediately pre-deploy is safer) :

```bash
./tools/db/railway_pg_dump.sh production
# Output : tools/db/baselines/production-{date}-pre-deploy.sql.gz
```

3. **dev → staging → main promotion** (Wave 4 trigger) :

```bash
git checkout main
git pull origin main
git merge --no-ff staging
git push origin main
# This triggers Railway production deploy with the full chain (14 revs from 29_05_magic_link_tokens → p121_drop_snapshot_legacy + p122_merge if applicable + post-Wave-3 migrations).
# railway_pre_deploy_migrate.py runs at boot ; subprocess.run(['alembic', 'upgrade', 'head'], check=True) applies all 14+ migrations.
```

4. **Monitor prod deploy** :

```bash
gh run watch  # follow GH Actions deploy-backend.yml job
# OR poll Railway dashboard
```

5. **Probe prod state post-deploy** (mirror Wave 1 Task 1 probe sequence) :

```bash
echo "# Phase 02-deploy Wave 4 prod migration apply evidence ($(date -u +%Y-%m-%dT%H:%M:%SZ))" > .planning/phases/mint-data-architecture-v1-02-deploy/prod-task-2a-evidence.txt

railway ssh -e production --service MINT 'python3 -c "
import os, psycopg2
url = os.getenv(\"DATABASE_URL\")
c = psycopg2.connect(url); cur = c.cursor()
cur.execute(\"SELECT version_num FROM alembic_version\")
print(\"alembic head:\", cur.fetchone())
for table in [\"fact_event\", \"fact_current\", \"dek_envelope\"]:
    cur.execute(f\"SELECT EXISTS(SELECT 1 FROM pg_tables WHERE tablename=%s)\", (table,))
    print(f\"{table}:\", cur.fetchone()[0])
cur.execute(\"SELECT count(*) FROM users\")
print(\"users:\", cur.fetchone()[0])
"' | tee -a .planning/phases/mint-data-architecture-v1-02-deploy/prod-task-2a-evidence.txt
```

6. **FF stays UNSET on prod** : NO `FF_FACT_EVENT_DUAL_WRITE=on` on production. Per locked decision Plan 02 + 0-user-prod premise + PR-4 already removed FF code, the dual-write path is automatic post-PR-5 (no FF gate exists anymore).

7. **No backfill needed on prod** : prod has 0 snapshots per CONTEXT (similar to staging) ; backfill is a no-op. Forward-write dual-write populates fact_event as new snapshots are created.

8. **projection_diff full audit against prod (vacuous but persist path proven)** :

```bash
railway ssh -e production --service MINT 'cd /app && python3 -m tools.parity.projection_diff --audit-all-users --persist-to _phase02_parity_audit' 2>&1 | tee -a .planning/phases/mint-data-architecture-v1-02-deploy/prod-task-2a-evidence.txt
# Expected : USERS_AUDITED=2, USERS_WITH_DIFF=0 (2 test accounts)
```

9. **Document in evidence file** : alembic head + table existence + user count + projection_diff output + Sentry alert rule confirmed active.
  </action>
  <verify>
    <automated>cd /Users/julienbattaglia/Desktop/MINT.nosync && [ -f tools/db/baselines/production-*-pre-deploy.sql.gz ] && [ -f .planning/phases/mint-data-architecture-v1-02-deploy/prod-task-2a-evidence.txt ] && grep -q "alembic head:" .planning/phases/mint-data-architecture-v1-02-deploy/prod-task-2a-evidence.txt && grep -q "fact_event: True" .planning/phases/mint-data-architecture-v1-02-deploy/prod-task-2a-evidence.txt && grep -q "fact_current: True" .planning/phases/mint-data-architecture-v1-02-deploy/prod-task-2a-evidence.txt && grep -qE "USERS_WITH_DIFF=0|USERS_AUDITED=" .planning/phases/mint-data-architecture-v1-02-deploy/prod-task-2a-evidence.txt</automated>
  </verify>
  <acceptance_criteria>
    - `[ -f tools/db/baselines/production-*-pre-deploy.sql.gz ]` returns 0 (baseline captured).
    - Prod alembic head = current dev head (post-Wave-3 merges).
    - `grep -E "fact_event: True" prod-task-2a-evidence.txt` returns 1 hit.
    - `grep -E "fact_current: True" prod-task-2a-evidence.txt` returns 1 hit.
    - `grep -E "users: 2|users: [0-9]+" prod-task-2a-evidence.txt` returns ≥ 1 hit (2 test accounts per CONTEXT).
    - `grep -E "USERS_AUDITED=2, USERS_WITH_DIFF=0" prod-task-2a-evidence.txt` returns 1 hit (vacuous but proven).
    - `railway variables -e production --service MINT | grep FF_FACT_EVENT_DUAL_WRITE` returns 0 lines (FF stays unset).
    - Sentry alert rule confirmed active (Julien verifies dashboard).
  </acceptance_criteria>
  <done>
    Prod migration applied + post-deploy probe documented + baseline captured. fact_event + fact_current + dek_envelope all present on prod. 0 diff vacuously verified. FF stays unset on prod. Ready for final 5-gate panel (Task 11).
  </done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <name>Task 11 (Final 5-gate panel + Wave 4 close-out) : G1 Maestro + G2 Julien device + G3 dev CI + G4 regression + G5 lints + VERIFICATION-REPORT.html + SUMMARY.md + ROADMAP + STATE flip</name>
  <files>N/A — checkpoint task ; no file mutation by Claude. Julien runs verification steps + types resume-signal.</files>
  <what-built>
    Tasks 1-10 deliver :
    - Plan 02-04 Task 1-4 shipped (D-06, D-07, D-09, D-10, D-32 G3, D-33).
    - Mobile L1 device wiring shipped (sub-PR A4a + A4b).
    - 5 sec/arch FLAGs disposed.
    - DEFERRED-02-01-A verified ; PR D polish absorbed.
    - Prod migration applied + post-deploy probe documented.
    - All Wave 3 PRs + Wave 4 prod deploy committed.

    Task 11 produces :
    - `mint-data-architecture-v1-02-deploy-VERIFICATION-REPORT.html` (≥200 lines)
    - `mint-data-architecture-v1-02-deploy-SUMMARY.md` (≥180 lines)
    - ROADMAP.md + STATE.md + PROJECT.md updates flipping Phase 02-deploy status.
    - PERIMETERS.md final entry.
  </what-built>
  <action>
    Checkpoint task — Claude executes no file mutation here. The atomic
    operations (PR builds, evidence file generation, code commits) all live
    in the preceding `type="auto"` tasks of this plan. This checkpoint task
    pauses execution until Julien types the `resume-signal` after running
    the verification steps listed in `<how-to-verify>` below.
  </action>
  <how-to-verify>
    **Julien runs final 5-gate panel evidence collection (~30 min)** :

    1. **G1 Maestro sweep on staging + prod Mobile L1 wired surface** :
       ```bash
       tools/simulator/walker.sh --env staging
       tools/simulator/walker.sh --env production
       # Output committed to .planning/reports/wave-4-maestro-sweep-{date}.html
       ```
       Assert : both sweeps PASS or document DEFERRED if sim crash issues per memory `feedback_sim_crash_mitigation`.

    2. **G2 Julien device sign-off** :
       - Julien runs the wired Mobile L1 surface on real iPhone (post-prod-deploy).
       - Verifies : MobileL1AuditLifecycleObserver fires on bootstrap, OfflineAuditQueue drains on connectivity restore, SQLCipher buffer persists across cold-start.
       - Records confirmation in PERIMETERS.md ledger.

    3. **G3 dev CI green commit sha trail** :
       ```bash
       gh run list --branch dev --workflow deploy-backend.yml --limit 10
       gh run list --branch main --workflow deploy-backend.yml --limit 5
       # All jobs ≠ fail, ≠ pending
       ```

    4. **G4 regression suite** :
       ```bash
       cd services/backend && python3 -m pytest tests/ -q --timeout=180
       # Expected : ≥ 7600 passed (Plan 01 +9 tests + Plan 03 +3 tests + Plan 04 +20+ tests = +30+ vs substrate baseline 7515)
       ```

    5. **G5 lints all green** :
       ```bash
       python3 tools/checks/banned_terms_python.py services/backend/app/
       python3 tools/checks/accent_lint_fr.py --scope all
       python3 tools/checks/validate_arb_parity.py
       python3 tools/checks/profile_safe_fields_parity.py --hard
       python3 tools/checks/hmac_pepper_audit.py services/backend/app/
       python3 tools/checks/alembic_partition_safety_lint.py
       python3 tools/checks/declared_counters_must_fire.py
       python3 tools/checks/no_ff_fact_event_dual_write.py
       python3 tools/checks/subject_type_forward_lint.py services/backend/
       python3 tools/checks/wiki_lint.py lint --strict
       python3 tools/checks/no_legal_admission_in_public_docs.py docs/
       # All exit 0
       ```

    6. **Claude generates close-out artifacts** :
       - `mint-data-architecture-v1-02-deploy-VERIFICATION-REPORT.html` (≥200 lines, follow Phase 01 W4 Plan 20 reference structure) :
         - Phase-level header (status : ◆ code-shipped on dev, pending operational gates OR ◆ COMPLETE per stage 4 of CLAUDE.md §9.5 after G2 sign-off)
         - Per-wave rollup (Wave 0 + 1 + 2 + 3 + 4)
         - 5-gate exit panel (G1/G2/G3/G4/G5 each with citation evidence)
         - Cumulative metric snapshot (alembic head, fact_event row count, fact_current row count, dek_envelope row count, 9 declared counters list)
         - Deferred items (DEFERRED-02-01-B Mobile parity-lint 40-field drift + DEFERRED-02-02-B DEK tombstone + UUID4→UUID7 Phase 03 + sec FLAG-1 reconsider Phase 03 + Phase 03 coach extractor pointer)
         - Lessons learned (≥5 entries from this phase)
         - Engram doctrine roll-up (per-wave obs)
       - `mint-data-architecture-v1-02-deploy-SUMMARY.md` (≥180 lines, follow Phase 01 W4 Plan 20 SUMMARY structure) :
         - Frontmatter (phase, plans=4, status, exit_gate, commit_count)
         - TLDR
         - Per-plan summary (4 plans)
         - Per-D-XX disposition (all Phase 02 D-XX redux + Wave 3 additions D-06/D-07/D-09/D-10/D-32/D-33)
         - Counter-arguments + data gaps
         - Cumulative metric snapshot
         - Lessons learned
         - 0-trust §9.6 Evidence + Caveat block
         - Self-Check
       - `.planning/ROADMAP.md` Phase 02-deploy entry : flip status (📋 OPEN → ◆ code-shipped on dev, pending G2 OR ◆ COMPLETE post-G2)
       - `.planning/STATE.md` frontmatter : `stopped_at` → `Phase mint-data-architecture-v1-02-deploy — ◆ code-shipped on dev, pending operational gates`
       - PROJECT.md : update current focus pointer to Phase 03 if Julien confirms moving on
       - `PERIMETERS.md` final Wave 4 sign-off entry

    7. **Type gate decision**.

    **Gate decision** :
    - All 5 gates evidenced (G1/G2/G3/G4/G5 each citation-backed) → `approved Phase 02-deploy close-out — 5-gate panel green, all D-XX disposed, ready for Phase 03` → Claude commits the close-out artifacts (single phase-close commit per Phase 01 W4 reference) + records final PERIMETERS.md entry.
    - G2 device verification reveals issue → Claude opens fix-up plan (potentially new phase if blocking).
    - G1 Maestro fails → document DEFERRED per memory `feedback_sim_crash_mitigation` and ship close-out with caveat.

    **After approval** :
    - Phase 02-deploy CLOSED (Stage 4 of 4 per CLAUDE.md §9.5).
    - Phase 03 (coach extractor) unblocked.
    - Engram `mem_save` with `topic_key: mint-data-architecture-v1-02-deploy:phase-close:shipped-pending-G2-or-COMPLETE` + `prior_finding_refs` ≥ 10 obs (Phase 02-deploy waves + Phase 02 substrate carry-over).
  </how-to-verify>
  <verify>
    <automated>echo "Checkpoint task — verification is manual by Julien per <how-to-verify> ; this <verify> stub is a structural placeholder. Resume blocked until <resume-signal> received."</automated>
  </verify>
  <done>
    Julien types the resume-signal after running the <how-to-verify> steps successfully. Claude proceeds to the next task (or records sign-off in PERIMETERS.md per task spec).
  </done>
  <resume-signal>
    Type "approved Phase 02-deploy close-out — 5-gate panel green, all D-XX disposed, ready for Phase 03" OR describe failure mode for fix-up.
  </resume-signal>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Mobile L1 sub-PR A4b iOS entitlement | ANY `keychain-access-groups` or `com.apple.developer.*` is release-blocking + requires fastlane match + Apple Developer portal updates ; isolated PR per memory. |
| Mobile L1 design panel verdict | Pre-push gate ; 4-person verdict recorded as JSON-like document with each panel signature. |
| `declared_counters_must_fire.py` HARD gate | Pre-push gate ; if a counter regression slips, push fails locally + CI re-runs. |
| Prod migration apply | Single-point-of-impact mutation ; baseline pg_dump from Plan 01 + fresh capture from this Task 10 = 2 rollback anchors. |
| Final close-out artifacts | Phase 02-deploy → Phase 03 handoff ; integrity depends on accurate D-XX disposition + Wave 4 prod state probe. |

## STRIDE Threat Register (ASVS L1 + engram #194 deep audit)

| Threat ID | Category | Component | Severity | Disposition | Mitigation |
|-----------|----------|-----------|----------|-------------|------------|
| T-04-01 | Tampering | Sub-PR A4a + A4b bundled together (iOS entitlement leak through Dart-only PR) | high | mitigate | Locked decision #5 + memory `feedback_ios_entitlements_block_testflight` + Task 6 acceptance criteria explicit `git diff apps/mobile/ios/` shows 0 changes. |
| T-04-02 | Spoofing | Mobile L1 design panel verdict forged | medium | mitigate | Verdict document recorded with each panel signature + commit attribution to Julien ; Task 5 CHECKPOINT cannot be self-cleared. |
| T-04-03 | Information disclosure | SQLCipher passphrase stored in iOS Keychain compromised | high | mitigate | Hardware-backed Keychain (per `flutter_secure_storage` contract) ; passphrase derived once per install ; cleared on uninstall. |
| T-04-04 | Tampering | UUID v7 not adopted (arch FLAG-2 forward-defer) → clock skew inversion in projector | medium | accept | Documented trade-off in `audit-pepper-rotation.md` runbook + Task 8 test_clock_skew_uuid7_ordering documents the accepted race. |
| T-04-05 | Information disclosure | DSAR endpoint doesn't include fact_event entries (sec FLAG-4 BLOCKING per FADP) | high | mitigate | Task 8 sec FLAG-4 test extends DSAR endpoint to include fact_event rows ; test_dsar_event_log_inclusion asserts response shape. |
| T-04-06 | Information disclosure | Quasi-identifier (postal_code + birth_date + canton) in fact_event payload re-identifies anonymized user (sec FLAG-2) | high | mitigate | Task 8 sec FLAG-2 test asserts writer scrubs/rejects ; banned-terms LSFin lint extension (Task 3) catches at write time. |
| T-04-07 | DoS | Event log baseline trim missing (sec FLAG-5) → unbounded growth for pre-Phase-02 users | medium | mitigate | Task 8 sec FLAG-5 test asserts size bounded ; partition-split runbook (Task 4) documents threshold-triggered remediation. |
| T-04-08 | Tampering | Subject_type='user' string-based without registry check (arch FLAG-3) | medium | mitigate | Task 8 subject_type_forward_lint.py + lefthook HARD gate. |
| T-04-09 | Tampering | sec FLAG-1 post-write divergence assertion deleted accidentally (PR D step 7 conflict) | high | mitigate | Locked decision #sec-flag-1-preservation excludes PR D step 7 ; Task 9 acceptance criteria explicit `grep -c "post-write divergence" fact_projector.py ≥ 1`. |
| T-04-10 | Tampering | Prod migration interrupts mid-chain (14 revs deep) | high | mitigate | Plan 01 Task 4 captured pre-prod baseline ; Task 10 captures fresh pre-Wave-4 baseline ; Railway auto-rollback if alembic upgrade fails (gunicorn doesn't start, previous deploy retained per RESEARCH §Pattern 1 Pitfall). |
| T-04-11 | Tampering | Sentry alert rule not configured + drift undetected post-prod-cutover | high | mitigate | Locked decision #6 + Task 4 sentry-alert-config.md runbook + Task 11 G2 verification confirms rule active. |
| T-04-12 | Repudiation | Final close-out artifacts (VERIFICATION-REPORT + SUMMARY) miss a D-XX disposition | medium | mitigate | Task 11 acceptance asserts 33+ D-XX dispositions present (Phase 02 substrate D-01..D-33 + Wave 3 D-06/D-07/D-09/D-10 closures). |
| T-04-13 | Information disclosure | Mobile L1 audit_events SQLite buffer (sqflite_sqlcipher) leaks plaintext events to backup | high | mitigate | Encrypted-at-rest via SQLCipher passphrase ; integration test asserts raw file does NOT contain plaintext. |
| T-04-14 | Information disclosure | Orphan staging Postgres service (devops finding) leaks data | low | accept | Task 9 surfaces as Julien manual delete ; service has no active reads per devops audit. |
| T-04-15 | Tampering | DEFERRED-02-01-A dual-head still present at Wave 4 → prod migration ambiguous head | high | mitigate | Task 9 Step 1 verifies `alembic heads` returns single head ; if not, ship p122 merge before Task 10. |
</threat_model>

<verification>
**Phase-level checks for this plan :**

1. **`autonomous: false`** — 2 critical Julien CHECKPOINTS : Task 5 (Mobile L1 design panel BEFORE push) + Task 11 (final 5-gate panel close-out).
2. **Wave 3 + Wave 4 strict ordering** : Tasks 1-9 (Wave 3) MUST complete before Task 10 (Wave 4 prod migration). Task 11 (close-out) MUST complete after Task 10.
3. **Sub-PR A4a/A4b strict ordering** : A4a (Dart-only) ships first ; A4b (iOS entitlement) ships AFTER A4a per locked decision #5 + memory `feedback_ios_entitlements_block_testflight`.
4. **Sec FLAG-1 preservation** : Task 9 PR D polish item 7 EXPLICITLY EXCLUDED ; acceptance criteria asserts `grep -c "post-write divergence" fact_projector.py ≥ 1`.
5. **0-trust §9 strict at close-out** : Task 11 G2 evidence (Julien device sign-off) is the deterministic citation required for « COMPLETE » claim ; without G2 (e.g., G2 DEFERRED), status reads `◆ code-shipped on dev, pending G2` per CLAUDE.md §9.5 Stage 3 of 4.
6. **Engram contract per task** : `mem_save` at end of each major task + `prior_finding_refs` chaining accumulates.
7. **Pre-push checklist per refactor** (Task 9 + per-task) : grep callers + regen OpenAPI/flutter gen-l10n + full pytest BEFORE push.
8. **Public-repo discipline** : `no_legal_admission_in_public_docs.py` on all runbook + SUMMARY content (Task 4 + Task 11 acceptance).
9. **Wiki schema lint HARD** (Task 4 + Task 11 close-out artifacts) : counter-arguments + data gaps blocks present in every new `.md`.
</verification>

<success_criteria>
- [ ] Plan 02-04 Task 1 (D-09 alias + D-10 dead-fields) closed (Task 1).
- [ ] Plan 02-04 Task 2 (Q6 CI D-06) closed + 2 sub-runbooks (staging-down-override + branch-protection) shipped (Task 2).
- [ ] Plan 02-04 Task 3 (declared_counters_must_fire + LSFin JSONB extension) closed (Task 3).
- [ ] Plan 02-04 Task 4 (3 runbooks + sentry-alert-config + Backend README) closed (Task 4).
- [ ] Mobile L1 sub-PR A4a (DEFERRED-02-02-C/E/F + D-30 race tests) shipped after 4-panel verdict PASS (Tasks 5-6).
- [ ] Mobile L1 sub-PR A4b ISOLATED (DEFERRED-02-02-D sqflite_sqlcipher + iOS entitlement + fastlane match) opened with Julien manual steps documented (Task 7).
- [ ] 5 sec/arch FLAGs disposed : sec FLAG-2 + sec FLAG-4 + sec FLAG-5 shipped via tests ; arch FLAG-2 UUID4→UUID7 decoupled Phase 03 ; arch FLAG-3 subject_type_forward_lint shipped (Task 8).
- [ ] DEFERRED-02-01-A verified single head (or p122 merge shipped) ; PR D polish items 1-6 + 8 absorbed (item 7 sec FLAG-1 EXCLUDED) (Task 9).
- [ ] Prod migration applied : alembic head = current dev head + fact_event/fact_current/dek_envelope on prod + 2 prod test accts audit zero diff (Task 10).
- [ ] Final 5-gate panel evidence captured : G1 Maestro (or DEFERRED) + G2 Julien device + G3 dev CI + G4 regression + G5 lints (Task 11).
- [ ] VERIFICATION-REPORT.html ≥ 200 lines + SUMMARY.md ≥ 180 lines (Task 11).
- [ ] ROADMAP + STATE + PROJECT + PERIMETERS updated (Task 11).
- [ ] All 33+ D-XX dispositions present in SUMMARY.
- [ ] All threats in STRIDE register have a disposition.
- [ ] Engram observations saved per-task with prior_finding_refs ≥ 10 obs at close.
- [ ] 0-trust §9.6 Evidence + Caveat block in SUMMARY uses honest stage labeling (Stage 3 or 4 of 4 per CLAUDE.md §9.5).
- [ ] Wiki schema lint HARD green on all `.planning/phases/mint-data-architecture-v1-02-deploy/` content + `docs/operations/`.
</success_criteria>

<output>
After completion, ensure :
- `.planning/phases/mint-data-architecture-v1-02-deploy/mint-data-architecture-v1-02-deploy-04-plan-02-04-tasks-SUMMARY.md` (per-task receipt) exists.
- `.planning/phases/mint-data-architecture-v1-02-deploy/mint-data-architecture-v1-02-deploy-VERIFICATION-REPORT.html` (phase-level, written by Task 11) ≥ 200 lines.
- `.planning/phases/mint-data-architecture-v1-02-deploy/mint-data-architecture-v1-02-deploy-SUMMARY.md` (phase-level, Task 11) ≥ 180 lines.
- ROADMAP.md Phase 02-deploy entry flipped + Plan 04 checkbox ticked.
- STATE.md frontmatter updated.
- PROJECT.md current-focus updated to Phase 03 if Julien confirms.
- PERIMETERS.md final Wave 4 sign-off entry.
- 10 evidence/artifact files committed across the 11 tasks.
- `mem_save` at phase-close with `topic_key: mint-data-architecture-v1-02-deploy:phase-close:shipped-{or-COMPLETE}-{date}` + `prior_finding_refs` ≥ 10 obs (Phase 02 substrate close-out + Wave 0/1/2/3/4 obs + Plan 02-04 Task obs + Mobile L1 panel verdict + Wave 4 prod-deploy obs).
- Phase 03 entry in ROADMAP unblocked.
- Forward-deferred items list :
  - DEFERRED-02-01-B Mobile parity-lint 40-field drift closure (backlog Phase 03).
  - DEFERRED-02-01-C profile_safe_fields_parity static-analysis enhancement (backlog Phase 03).
  - DEFERRED-02-02-B DEK tombstone backend (revisit Phase 04).
  - UUID4→UUID7 forward-compat (Phase 03 arch FLAG-2 closure).
  - sec FLAG-1 post-write divergence assertion reconsideration (Phase 03 after 30-day stable event-log).
  - Sentry alert rule monitoring + tuning (ongoing operational task).
  - Orphan staging Postgres service delete (Julien manual confirmation step).
</output>
