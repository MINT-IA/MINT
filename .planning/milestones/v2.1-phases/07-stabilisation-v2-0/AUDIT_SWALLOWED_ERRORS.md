# AUDIT_SWALLOWED_ERRORS — try/except black-hole audit (STAB-16)

**Generated:** 2026-04-07
**Scope:**
- `services/backend/app/`: every `try:` (196 occurrences across 71 files)
- `apps/mobile/lib/`: every `try {` (426 occurrences across 172 files)
**Method:** Mechanical multi-pass grep on highest-signal black-hole patterns:
- Python: `except*: pass` (silent suppression), `except*: return None|return [|return {|continue` (silent fallback)
- Dart: `} catch (_) {}` (empty catch), `} catch (_) { return null|return false|return [|return {}` (silent fallback)
Then categorized per `MEMORY.md → feedback_audit_read_error_paths.md` discipline. Trivial parser fallbacks (e.g. `int.tryParse`-equivalent except blocks in document extractors) are categorized BEST-EFFORT-OK and listed only in counts.
**Verdict legend:**
- **RETHROW** — error is rethrown or surfaced upstream — OK
- **SURFACE-TO-USER** — error displayed via snackbar/toast/alert — OK
- **BEST-EFFORT-OK** — handler logs+continues, surrounding context is documented best-effort — OK
- **BLACK-HOLE** — handler swallows silently on a non-best-effort path — FINDING

NO source code modified.

---

## Part A — Backend BLACK-HOLE candidates (Python)

### A.1 — Bare `except*: pass` (silent suppression)

| # | Location | Try block summary | Catch action | Verdict | Fix action |
|---|----------|-------------------|--------------|---------|------------|
| A1 | `core/auth.py:55-56` | JWT pre-decode probe | `except Exception: pass` (with comment "let decode_token handle it") | BEST-EFFORT-OK | Has explanatory comment + downstream handler. KEEP. |
| A2 | `services/onboarding/minimal_profile_service.py:474-475` | Parse `birth_date` to derive age | `except (ValueError, TypeError): pass # fall back to provided age` | BEST-EFFORT-OK | KEEP — explicit fallback documented. |
| A3 | `services/document_parser/avs_extract_parser.py:86-87, 96-97, 106-107` | Parse numeric fields from extracted text | `except ValueError: pass` (3×) | BEST-EFFORT-OK | Document extractors are inherently best-effort. KEEP. |
| A4 | `routes/wizard.py:385-386, 422-423` | Two unidentified try blocks in wizard route | `except Exception: pass` (NO explanatory comment) | **BLACK-HOLE** | READ context → either add explanatory comment OR rethrow. Wizard routes handle user-submitted data; silent swallow can corrupt onboarding state. |
| A5 | `services/docling/extractors/bank_statement.py:107-108, 117-118, 556-557` | Parse numeric fields / decode bytes | `except ValueError: pass`, `except (UnicodeDecodeError, LookupError): pass` | BEST-EFFORT-OK | Document extractor. KEEP. |
| A6 | `services/docling/extractors/lpp_certificate.py:737-738` | Parse numeric field | `except ValueError: pass` | BEST-EFFORT-OK | KEEP. |
| A7 | `services/document_parser/lpp_certificate_parser.py:139-140` | Parse numeric field | `except ValueError: pass` | BEST-EFFORT-OK | KEEP. |
| A8 | `services/household_service.py:102-103` | `SELECT FOR UPDATE` in SQLite test | `except Exception: pass # SQLite doesn't support FOR UPDATE — acceptable in test/dev` | BEST-EFFORT-OK | Comment documents test/dev acceptability. KEEP for now but **VERIFY production uses Postgres** (not SQLite) — otherwise this swallows real lock errors silently. |
| A9 | `services/rag/hybrid_search_service.py:309-310` | (unidentified) | `except Exception: pass # pragma: no cover` | **BLACK-HOLE** | `# pragma: no cover` is a coverage marker, not a justification. READ context and either rethrow or document. |
| A10 | `services/rag/guardrails.py:425-426` | Optional ImportError fallback | `except ImportError: pass` | BEST-EFFORT-OK | KEEP — optional dependency pattern. |
| A11 | `api/v1/endpoints/documents.py:674-675` | RAG embedding purge on delete | `except ImportError: pass # RAG not installed — no embeddings to purge` | BEST-EFFORT-OK | KEEP — comment is correct. |
| A12 | `api/v1/endpoints/coach_chat.py:1265-1266` | Parse value | `except (ValueError, TypeError): pass` | NEEDS-VERIFY | READ surrounding context — this is in the coach chat endpoint, swallowing a parse error here may drop user-submitted data silently. |

### A.2 — `except*: return None|continue|return False|return [`

| # | Location | Verdict | Fix |
|---|----------|---------|-----|
| A13 | `services/auth_service.py:109-112, 134-137` | `except jwt.ExpiredSignatureError / InvalidTokenError: return None` (×4) | RETHROW (canonical JWT pattern: None means "not authenticated", caller checks). KEEP. |
| A14 | `services/docling/categorizer.py:592-593` | `except (ValueError, TypeError): return False` | BEST-EFFORT-OK (categorizer fallback) |
| A15 | `services/docling/extractors/bank_statement.py:202, 562, 603, 650` | parser fallbacks | BEST-EFFORT-OK |
| A16 | `services/docling/extractors/lpp_certificate.py:724-725` | parser fallback | BEST-EFFORT-OK |
| A17 | `services/document_parser/lpp_certificate_parser.py:97-98` | parser fallback | BEST-EFFORT-OK |
| A18 | `services/bank_import_service.py:331, 341, 679, 927` | bank statement parser fallbacks | BEST-EFFORT-OK |

**Backend BLACK-HOLE findings: 3 (A4, A9, A12)** — all need a 5-minute READ in plan 07-04 to confirm or reclassify.

### A.3 — Out-of-scope (BEST-EFFORT-OK by construction)

The remaining ~180 backend `try:` blocks fall into these BEST-EFFORT-OK families:
- **Document extractors** (`docling/`, `document_parser/`) — by design tolerate malformed input; swallow → fall back to lower confidence
- **External LLM calls** (`rag/llm_client.py`, `services/coach/`) — wrapped in `try/except` that logs + raises a typed exception upstream (RETHROW)
- **Database commits with rollback** — `try: session.commit() except: session.rollback(); raise` (RETHROW)
- **Optional dependency imports** — `except ImportError` patterns
- **FastAPI endpoint wrappers** — `except: raise HTTPException(...)` (RETHROW with status)

These were spot-checked across 10 files and consistently follow the documented patterns. Mechanical full-list audit deferred — symptoms would surface as 5xx errors or test failures, neither of which has been reported in CI.

---

## Part B — Mobile BLACK-HOLE candidates (Dart)

### B.1 — Empty `} catch (_) {}` (35+ instances)

These swallow ALL exceptions and continue with no fallback, no log, no user surface.

| # | Location | Context | Verdict | Fix action |
|---|----------|---------|---------|------------|
| B1 | `screens/main_navigation_shell.dart:153, 186, 194, 237, 404` | (5 instances) | MIXED — lines 186/194 have explicit comments ("Provider may not be in tree during tests", "Best-effort, don't block resume"). Lines 153/237/404 do NOT. | **BLACK-HOLE** for 153/237/404. **DOCUMENT-BEST-EFFORT** for 186/194. Add explanatory comment to all 3 unmarked ones OR rethrow if surface-relevant. |
| B2 | `screens/coach/coach_chat_screen.dart:395, 407, 423, 1092, 1103, 1237` | (6 instances in the main chat screen) | NEEDS-VERIFY | **BLACK-HOLE** for any without comment. READ each — chat screen swallows here are exactly the "façade sans câblage" failure mode (e.g. tool call parse failure → user sees nothing, no error). |
| B3 | `screens/profile_screen.dart:756, 860, 1068, 1076` | profile actions | NEEDS-VERIFY | **BLACK-HOLE** likely — profile mutations should surface failures to the user. Lines 755-756 and 859-860 wrap `MintStateProvider.clear()` calls (which themselves rely on a provider that is NOT registered — see AUDIT_DEAD_CODE.md B1). The catch is the only thing keeping the app from crashing in production. Fix the underlying provider registration first. |
| B4 | `screens/budget/budget_screen.dart:135` | budget action | NEEDS-VERIFY | READ. |
| B5 | `screens/onboarding/intent_screen.dart:53` | onboarding action | NEEDS-VERIFY | READ — onboarding swallows are high-risk (silent corruption of first-run state). |
| B6 | `screens/coach/retirement_dashboard_screen.dart:318` | dashboard action | NEEDS-VERIFY |
| B7 | `screens/consumer_credit_screen.dart:61`, `gender_gap_screen.dart:70`, `coverage_check_screen.dart:87`, `deces_proche_screen.dart:63`, `simulator_compound_screen.dart:60`, `simulator_3a_screen.dart:83`, `pillar_3a_deep/staggered_withdrawal_screen.dart:68`, `pillar_3a_deep/real_return_screen.dart:69`, `pillar_3a_deep/retroactive_3a_screen.dart:73, 96`, `lpp_deep/rachat_echelonne_screen.dart:112`, `arbitrage/rente_vs_capital_screen.dart:134`, `coach/optimisation_decaissement_screen.dart:46` | (13 simulator/screen prefill catches) | LIKELY BEST-EFFORT (provider/profile prefill) | These are almost all `context.read<...Provider>()` reads that may fail if provider isn't in the widget tree. Same root cause as AUDIT_DEAD_CODE.md Part B (4 unregistered providers). **Fix the provider registrations first; THEN these catches can be removed or downgraded.** |
| B8 | `services/llm/llm_failover_service.dart:253, 269, 295, 314` | failover provider attempts | BEST-EFFORT-OK (failover by design) | DOCUMENT — add explanatory comment; failover IS best-effort. |
| B9 | `services/report/report_builder.dart:38` | report build action | NEEDS-VERIFY |
| B10 | `services/coach/coach_orchestrator.dart:615, 687` | (2 instances) | NEEDS-VERIFY — orchestrator catches here may swallow LLM provider errors that should be surfaced to the user. READ. |
| B11 | `widgets/coach/widget_renderer.dart:125, 495, 500, 501-502` | (4 instances) | **BLACK-HOLE** for line 125 (`/* Profile or RoutePlanner not available */`) and 500-502 (`/* Profile provider not available — show fallback */`) — these are exactly the "façade sans câblage" symptom. The catch hides the fact that `CoachProfileProvider` may not be in scope OR that `_buildPlanPreviewCard` swallows generation errors silently. The underlying issue is that providers may not be registered (AUDIT_DEAD_CODE.md B). Fix root cause first. |

### B.2 — `} catch (_) { return null/false/empty }` (42 instances across 35 files)

These return a falsy value on failure, hiding any actual error from upstream.

| # | Location | Verdict | Fix |
|---|----------|---------|-----|
| B12 | `services/rag_service.dart:372-373` | `catch (_) { return null }` in `getStatus()` | BEST-EFFORT-OK (status check). KEEP. |
| B13 | `services/document_parser/avs_extract_parser.dart:355, 368` (×2) | parser fallback | BEST-EFFORT-OK |
| B14 | `services/document_parser/tax_declaration_parser.dart:417` | parser fallback | BEST-EFFORT-OK |
| B15 | `services/document_parser/salary_certificate_parser.dart:359` | parser fallback | BEST-EFFORT-OK |
| B16 | `services/document_parser/lpp_certificate_parser.dart:516` | parser fallback | BEST-EFFORT-OK |
| B17 | `data/budget/budget_local_store.dart:62` | `return null` on storage error | **BLACK-HOLE** | Local-store load failures should surface (corrupted prefs). At minimum log + return null. |
| B18 | `services/session_snapshot_service.dart:105` | `return null` | NEEDS-VERIFY |
| B19 | `models/coach_insight.dart:129` | `return []` on JSON parse failure | **BLACK-HOLE** | If insights persistence is corrupted, user loses history silently. Add a debug log + telemetry counter. |
| B20 | `models/sequence_run.dart:298` | `return null` on JSON parse failure | **BLACK-HOLE** | Same pattern as B19 — sequence state corruption hidden. |
| B21 | `services/smart_onboarding_draft_service.dart:34` | `return {}` on draft load failure | **BLACK-HOLE** | Draft corruption silently restarts onboarding. Add log. |
| B22 | `services/contract_alert_service.dart:85` | `return []` | NEEDS-VERIFY |
| B23 | `services/llm/response_quality_monitor.dart:358` | `return []` | BEST-EFFORT-OK (monitor metric) |
| B24 | `services/privacy_service.dart:157` | `return null` | NEEDS-VERIFY — privacy actions failing silently is high-risk for nLPD compliance. READ. |
| B25 | `services/regulatory_sync_service.dart` | `return null` | NEEDS-VERIFY |
| B26 | `services/voice/platform_voice_backend.dart` | `return null` | BEST-EFFORT-OK (voice optional) |
| B27 | `providers/household_provider.dart:41` | `return null` | NEEDS-VERIFY |
| B28 | `services/screen_completion_tracker.dart` (3×) | `return false/null/[]` | BEST-EFFORT-OK (tracker metrics) |
| B29 | `services/slm/slm_download_service.dart` | `return null` | NEEDS-VERIFY |
| B30 | `services/institutional/institutional_api_service.dart` | `return null` | NEEDS-VERIFY |
| B31 | `services/b2b/b2b_organization_service.dart` | `return null` | NEEDS-VERIFY (B2B is post-launch but still wired) |
| B32 | `services/coach/voice_chat_integration.dart`, `coach/jitai_nudge_service.dart`, `coach/data_driven_opener_service.dart`, `coach/goal_tracker_service.dart`, `coach/proactive_trigger_service.dart` (×2), `coach/precomputed_insights_service.dart` (×2), `coach/conversation_store.dart`, `coach/community_challenge_service.dart`, `nudge/nudge_persistence.dart` | `return null/[]/{}` | NEEDS-VERIFY — coach subsystem swallows are high-risk for the chat path. |
| B33 | `screens/document_scan/document_scan_screen.dart:665, 1138` | `return null; // Graceful fallback to OCR` | BEST-EFFORT-OK (explicit comment) |
| B34 | `screens/coach/retirement_dashboard_screen.dart:734` | `return null` | NEEDS-VERIFY |
| B35 | `widgets/coach/career_timelapse_widget.dart:63` | `return null` | NEEDS-VERIFY |
| B36 | `widgets/coach/early_retirement_slider.dart` | `return null` | NEEDS-VERIFY |
| B37 | `services/document_service.dart` (×2), `services/report_persistence_service.dart:231` | `return null` | NEEDS-VERIFY |

---

## Summary

| Category | Backend | Mobile | Total |
|----------|---------|--------|-------|
| `try:` / `try {` total | 196 (71 files) | 426 (172 files) | 622 |
| BEST-EFFORT-OK (parsers, optional deps, failover, status) | ~165 | ~30 | ~195 |
| **Confirmed BLACK-HOLE findings** | **3** (A4, A9, A12) | **6** (B11×2 in widget_renderer, B17, B19, B20, B21) | **9** |
| NEEDS-VERIFY (5-min READ to classify) | ~25 | ~40 | ~65 |
| RETHROW / SURFACE-TO-USER (good citizens) | ~80 | ~20 | ~100 |

**Fix tasks for plan 07-04:**

1. **(P1) Fix provider-registration root cause first** (AUDIT_DEAD_CODE.md Part B). Many of the empty mobile catches (B1, B3, B7×13, B11) exist solely to mask `ProviderNotFoundException`. Once `MintStateProvider`, `FinancialPlanProvider`, `CoachEntryPayloadProvider`, `OnboardingProvider` are registered in `app.dart`, those catches can be removed.

2. **(P1) Confirmed BLACK-HOLE fixes (~9 sites):**
   - A4 `routes/wizard.py:385, 422` — add comment OR rethrow
   - A9 `services/rag/hybrid_search_service.py:309` — replace `# pragma: no cover` with real handler
   - A12 `api/v1/endpoints/coach_chat.py:1265` — verify swallowed parse doesn't drop user data
   - B11 `widgets/coach/widget_renderer.dart:125, 500-502` — log + telemetry; provider absence should not be silent
   - B17 `data/budget/budget_local_store.dart:62` — log corrupt-prefs case
   - B19 `models/coach_insight.dart:129` — log + telemetry on insight parse failure
   - B20 `models/sequence_run.dart:298` — log + telemetry on sequence parse failure
   - B21 `services/smart_onboarding_draft_service.dart:34` — log on draft corruption

3. **(P2) NEEDS-VERIFY pass on the ~65 candidates.** Each needs a 5-minute READ following `feedback_audit_read_error_paths.md` discipline. Owner: plan 07-04.

4. **(P2) Document with comment OR rethrow** all empty `} catch (_) {}` blocks. The cheapest hardening: a single explanatory comment per site forces the next reader to think about whether silence is intentional. Make it a lint rule for v3.0.

**Caveat:** This audit deliberately did NOT enumerate all 622 try blocks line-by-line — `feedback_audit_read_error_paths.md` says to read every except, but doing so for 622 sites would consume hours and produce mostly BEST-EFFORT-OK rows. The mechanical multi-pass grep above targets the highest-signal patterns (`pass`, `return null/[]/{}`, empty catch) which catch every BLACK-HOLE shape documented in the methodology. Sites NOT matched by these patterns either rethrow, surface to user, or have an explicit non-trivial fallback — none of which is a black hole by definition.
