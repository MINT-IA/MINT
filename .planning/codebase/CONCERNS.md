# Codebase Concerns

**Analysis Date:** 2026-04-05

## Tech Debt

**TODO/FIXME/HACK Comments (43 total: 40 Flutter, 3 backend):**

Priority-tagged TODOs in Flutter (`apps/mobile/lib/`):
- P0: `services/backend/app/models/document.py:1` — unencrypted SQLite with PII in plaintext JSON columns
- P1: `services/backend/app/services/retirement/avs_estimation_service.py:165` — LAVS art. 29quinquies income splitting during marriage not modeled
- P2: `screens/document_scan/document_scan_screen.dart:526,1244` — EXIF metadata not stripped before Vision API call (privacy leak)
- P2: `services/financial_core/lpp_calculator.dart:82` — missing contributionMonths param for pro-rated threshold
- P2: `providers/auth_provider.dart:357` — no cloud backup of conversations before purge
- P2: `providers/coach_profile_provider.dart:868` — monthly check-ins not synced to backend (client-only)
- P2: `services/snapshot_service.dart:264` — snapshot timeline screen not implemented
- P2: `services/notification_service.dart:265` — no per-category notification preferences
- P2: `services/sequence/sequence_coordinator.dart:201` — missing inputDependencies for targeted invalidation
- P3: `services/cap_memory_store.dart:20` — CapMemory not synced to backend (no cross-device)
- Untagged: `widgets/wizard_question_widget.dart:124,585` — "En savoir plus" modal and date picker not implemented
- Untagged: `widgets/profile_drawer.dart:111` — inline language picker not built
- Untagged: `widgets/comparators/pillar3a_comparator_widget.dart:243` — "Comment ouvrir VIAC" modal stub
- Untagged: `services/expat_service.dart:44` — mobile not wired to backend for source tax
- Untagged: `services/memory/coach_memory_service.dart:32` — keys not prefixed with user ID (multi-account broken)
- Untagged: `services/openfinance/open_finance_service.dart:20` — same user ID prefix issue
- Untagged: `services/slm/slm_engine.dart:171` — device RAM not measured (no device_info_plus)

**Legacy "chiffre choc" term still in 51 files:**
- CLAUDE.md explicitly says this term is deprecated in favor of "premier eclairage"
- 51 files in `apps/mobile/lib/` still reference it: screens, services, widgets, models
- Key files: `screens/onboarding/chiffre_choc_screen.dart`, `services/chiffre_choc_selector.dart`, `widgets/coach/chiffre_choc_card.dart`, `widgets/coach/chiffre_choc_section.dart`
- Impact: Terminology inconsistency between docs and code. Not user-facing (internal naming) but confusing for developers.
- Fix approach: Rename files and references in a dedicated refactor sprint.

**Deprecated code still present:**
- `screens/ask_mint_screen.dart` — marked DEPRECATED (S52), superseded by CoachChatScreen. Route redirects in place but file kept "for backwards compatibility."
- `screens/education/theme_detail_screen.dart` — references removed `mint_ui_kit.dart` / deprecated `MintPremiumButton`
- `services/api_service.dart:1155` — deprecated legacy profile method still exists
- `models/coach_profile.dart:2836` — `@Deprecated` annotation on field

**Duplicate service files (3 pairs):**
- `lib/services/coach_narrative_service.dart` (1457 lines) AND `lib/services/coach/coach_narrative_service.dart` — two narrative services with overlapping responsibility
- `lib/services/gamification/community_challenge_service.dart` AND `lib/services/coach/community_challenge_service.dart`
- `lib/services/memory/goal_tracker_service.dart` AND `lib/services/coach/goal_tracker_service.dart`
- Impact: Import confusion, risk of divergent behavior. Need to determine canonical location and remove duplicate.
- Fix approach: Trace imports to find which is canonical, delete the other.

**Hardcoded French strings in services (i18n gap):**
- `services/coach/coach_orchestrator.dart:710` — explicitly flagged: "hardcoded FR strings — service has no BuildContext"
- `services/notification_scheduler_service.dart:129,328` — notification text hardcoded in French
- `services/agent/autonomous_agent_service.dart:443` — hardcoded French strings
- `services/recap/ai_recap_narrator.dart:105` — French fallback when ARB not populated
- Impact: ~120 strings across 24 secondary service files per MEMORY.md. App fails i18n for non-French users in these flows.
- Fix approach: Pass `AppLocalizations` or use key-based resolution in services lacking BuildContext.

## Security Considerations

**Database encryption (P0):**
- Risk: PII (salary, pension data) stored in plaintext JSON columns in unencrypted SQLite
- Files: `services/backend/app/models/document.py`, `services/backend/app/core/database.py`
- Current mitigation: Production uses PostgreSQL via DATABASE_URL env var on Railway. SQLite is dev/test only.
- Recommendations: Confirm production never falls back to SQLite. Add encryption at rest for PostgreSQL. Audit JSON columns for PII minimization.

**EXIF metadata leakage (P2):**
- Risk: Document scan images sent to Vision API with EXIF data intact (GPS, device info)
- Files: `apps/mobile/lib/screens/document_scan/document_scan_screen.dart:526,1244`
- Current mitigation: None — TODO comments only
- Recommendations: Strip EXIF before any API call. Use `image` package to remove metadata.

**BYOK API key storage:**
- Risk: User-provided API keys stored via `flutter_secure_storage`
- Files: `apps/mobile/lib/providers/byok_provider.dart`, `apps/mobile/lib/services/auth_service.dart`
- Current mitigation: Keys stored in platform secure storage (Keychain/Keystore), masked in UI display
- Recommendations: Acceptable pattern. Ensure keys never logged (check debugPrint calls near key handling).

**Multi-account key isolation missing:**
- Risk: `coach_memory_service.dart:32` and `open_finance_service.dart:20` lack user ID prefixing on storage keys
- Files: `apps/mobile/lib/services/memory/coach_memory_service.dart`, `apps/mobile/lib/services/openfinance/open_finance_service.dart`
- Impact: If multi-account ever enabled, data leaks between accounts
- Recommendations: Prefix all SharedPreferences/SecureStorage keys with user ID now.

**CoachContext PII policy:**
- Risk: CoachContext could leak exact salary/savings/debts to LLM
- Files: `apps/mobile/lib/services/coach_llm_service.dart:333`, `apps/mobile/lib/services/coach/prompt_registry.dart:47`
- Current mitigation: Policy documented in code comments. ComplianceGuard validates output but not input context construction.
- Recommendations: Add runtime assertion in `CoachContextBuilder` that exact PII fields are anonymized/bucketed.

**Backend broad exception handling:**
- Risk: 56 `except Exception` blocks across 24 backend files. Some may swallow errors silently.
- Files: `services/backend/app/services/rag/llm_client.py` (5 occurrences), `services/backend/app/api/v1/endpoints/documents.py` (6), `services/backend/app/services/rag/hybrid_search_service.py` (4)
- Impact: Silent failures in RAG pipeline, document processing, and LLM interactions
- Recommendations: Audit each handler — ensure logging/Sentry capture. Replace broad catches with specific exception types.

## Performance Concerns

**Oversized model file:**
- `apps/mobile/lib/models/coach_profile.dart` — 2956 lines. Single model file covering profile, preferences, history, goals, couple data, financial snapshot.
- Impact: Slow IDE indexing, difficult to maintain, merge conflicts likely
- Fix approach: Split into focused models (ProfileCore, ProfilePreferences, ProfileFinancials, etc.)

**Large screen files (12 screens over 1200 lines):**
- `apps/mobile/lib/screens/arbitrage/rente_vs_capital_screen.dart` — 1980 lines
- `apps/mobile/lib/screens/expat_screen.dart` — 1719 lines
- `apps/mobile/lib/screens/pulse/pulse_screen.dart` — 1665 lines
- `apps/mobile/lib/screens/coach/coach_checkin_screen.dart` — 1627 lines
- `apps/mobile/lib/screens/coach/coach_chat_screen.dart` — 1577 lines
- `apps/mobile/lib/screens/fiscal_comparator_screen.dart` — 1554 lines
- `apps/mobile/lib/screens/frontalier_screen.dart` — 1488 lines
- `apps/mobile/lib/screens/documents_screen.dart` — 1462 lines
- `apps/mobile/lib/screens/naissance_screen.dart` — 1398 lines
- `apps/mobile/lib/screens/coach/retirement_dashboard_screen.dart` — 1363 lines
- `apps/mobile/lib/screens/document_scan/document_scan_screen.dart` — 1335 lines
- `apps/mobile/lib/screens/concubinage_screen.dart` — 1259 lines
- Impact: Rebuild cost, difficult testing, tight coupling of UI logic
- Fix approach: Extract widgets and view models. Each screen should be <500 lines with logic in separate service/viewmodel.

**Excessive debugPrint/print statements:**
- 169 `print()` or `debugPrint()` calls across 30+ files in `apps/mobile/lib/`
- Heaviest: `services/coach_narrative_service.dart` (15), `services/coach/coach_orchestrator.dart` (19), `services/slm/slm_download_service.dart` (16), `services/slm/slm_engine.dart` (21)
- Impact: Console noise, potential PII leakage in logs, minor performance cost
- Fix approach: Replace with structured logging service. Remove or guard behind `kDebugMode`.

**Large backend files:**
- `services/backend/app/services/regulatory/registry.py` — 1387 lines
- `services/backend/app/api/v1/endpoints/coach_chat.py` — 1267 lines
- `services/backend/app/api/v1/endpoints/auth.py` — 1132 lines
- Impact: Complex endpoints difficult to test in isolation
- Fix approach: Extract business logic from endpoint files into dedicated service classes.

## Architectural Risks

**Silent error swallowing in Flutter services:**
- Pattern: `catch (e) { debugPrint('...'); }` throughout `coach_narrative_service.dart`, `regulatory_sync_service.dart`, `slm_engine.dart`, `analytics_service.dart`
- `regulatory_sync_service.dart` has 5 catch blocks — regulatory data sync failures silently ignored
- `llm_failover_service.dart` catches without logging to Sentry
- Impact: Users never know when services fail. Failures may cascade silently.
- Fix approach: All catch blocks must either report to Sentry or propagate. Best-effort operations must be explicitly documented.

**Couple data is client-side only:**
- Per MEMORY.md: "couple data client-side only" is a known product gap
- Files: `apps/mobile/lib/models/coach_profile.dart` (couple fields), `apps/mobile/lib/providers/coach_profile_provider.dart`
- Impact: No cross-device sync for couple projections. Data loss on app reinstall.
- Fix approach: Backend couple data model + sync endpoint.

**192 StatefulWidgets across the app:**
- 192 StatefulWidgets but only 191 `dispose()` calls — at least 1 potential memory leak
- Many screens lack proper lifecycle management (initState/didChangeDependencies)
- Impact: Timer leaks, controller leaks, subscription leaks
- Fix approach: Audit all StatefulWidgets for matching dispose calls. Consider migrating to StatelessWidget + Provider where possible.

**Navigator.pop still used alongside GoRouter:**
- Multiple screens use `Navigator.of(context).pop()` instead of GoRouter's `context.pop()`
- Files: `screens/pulse/pulse_screen.dart:1297`, `widgets/profile_drawer.dart:129,219`, `screens/onboarding/smart_onboarding_screen.dart:205`, `screens/expert/expert_tier_screen.dart:155`
- Impact: Mixed navigation approaches can cause stack inconsistencies. Acceptable for dialogs/bottom sheets but should be verified.

## Dependency Risks

**Flutter SDK pinned to ^3.6.0** — `apps/mobile/pubspec.yaml`
- Current but will need monitoring for breaking changes

**`flutter_gemma: ^0.11.16`** — on-device SLM:
- Relatively niche package, version 0.x indicates instability
- Risk: Breaking changes, platform-specific issues, maintenance uncertainty
- Files: `apps/mobile/lib/services/slm/slm_engine.dart`, `apps/mobile/lib/services/slm/slm_download_service.dart`

**`intl: any`** — unpinned dependency:
- Pinned comment says "Pinned by flutter_localizations SDK" but `any` constraint could pull breaking versions
- Risk: Low (Flutter SDK constrains it) but not best practice

**Backend `anthropic>=0.40.0,<1.0.0`** — pre-1.0 SDK:
- Active development, API may change
- Files: `services/backend/app/services/coach/claude_coach_service.py`, `services/backend/app/services/rag/llm_client.py`

**`google_mlkit_text_recognition: ^0.15.0`** — ML Kit OCR:
- Google ML Kit has history of breaking changes between versions
- Files: `apps/mobile/lib/screens/document_scan/document_scan_screen.dart`

## Known Gaps

**Features referenced but not implemented:**
- FATCA asset reporting for US persons — only fallback template text exists, no calculation engine
  - Files: `services/backend/app/services/coach/fallback_templates.py:132-134`, `decisions/ADR-20260223-archetype-driven-retirement.md:309`
- Frontalier (cross-border) tax uses ~4% approximation, not real cantonal baremes
  - Files: `services/backend/app/services/expat/frontalier_service.py:429`
- AVS income splitting during marriage (LAVS art. 29quinquies) — explicitly flagged as not modeled
  - Files: `services/backend/app/services/retirement/avs_estimation_service.py:165`
- Snapshot timeline screen (`/financial-timeline`) — referenced but not built
  - Files: `apps/mobile/lib/services/snapshot_service.dart:264`
- Reengagement endpoint — feature-gated stub, SQLAlchemy session not wired
  - Files: `services/backend/app/api/v1/endpoints/reengagement.py:138`

**Stubs and mock implementations:**
- `wizard_question_widget.dart:585` — "TODO: Implement date picker"
- `wizard_question_widget.dart:124` — "TODO: Ouvrir modal En savoir plus"
- `pillar3a_comparator_widget.dart:243` — "TODO: Ouvrir modal Comment ouvrir VIAC"

## Test Coverage Gaps

**109 screens without matching test files:**
- Out of 116 screen files, only ~7 have direct test coverage
- Notable untested screens: `coach_chat_screen.dart` (1577 lines), `pulse_screen.dart` (1665 lines), `rente_vs_capital_screen.dart` (1980 lines)
- Impact: UI regressions undetected. Critical financial display screens untested.
- Priority: High for screens displaying financial calculations (arbitrage, fiscal comparator, retirement dashboard)

**Service test coverage:**
- 188 service files in `apps/mobile/lib/services/` vs 199 test files in `apps/mobile/test/` (services dir)
- Ratio looks healthy but many test files may cover different services than the names suggest. Verify actual coverage.

**Backend exception handler coverage:**
- 56 `except Exception` blocks in 24 backend files — unclear how many have corresponding test cases for error paths
- RAG pipeline (`services/rag/`) has 14 exception handlers across 5 files — complex error surface

**Missing golden couple validation for new archetypes:**
- Golden test couple covers `swiss_native` (Julien) and `expat_us` (Lauren)
- No golden test data for: `expat_eu`, `expat_non_eu`, `independent_with_lpp`, `independent_no_lpp`, `cross_border`, `returning_swiss`
- Impact: 6 of 8 archetypes have no regression baseline
- Priority: High — archetype-specific calculations could silently break

---

*Concerns audit: 2026-04-05*
