# Phase 93: Compliance Hardening — Audit Log + FATCA + Confidence — Context

**Gathered:** 2026-05-06
**Status:** Ready for planning
**Mode:** Auto-generated from milestone synthesis (REQUIREMENTS.md COMP-01/03/04 + walkthrough BUG #18 P0 / #21 P1 / #22 P1)

<domain>
## Phase Boundary

Today, every coach response (`/coach/chat` + `/anonymous/chat`) is generated, returned, and lost — no auditable persistence per OAR-G art. 24 / FINMA Guidance 8/2024 §VI; the 5 « lourd » simulators (`simulator_3a`, `divorce`, `frontalier`, `compound`, `leasing`) ship a hero CHF number with zero confidence surfacing per CLAUDE.md règle 9; and an `expat_us` user asking about 3a / PFIC / treaty receives a generic 3a impératif with no FATCA hand-off (existing `fallback_templates.fatca_fbar_guidance` + `doctrine_checks` archetype rule are post-filters / advisory, never gating the LLM call).

Phase 93 closes the 3 inspector-test gaps with: (1) a `coach_message_audit` Postgres table + best-effort insert hook in both endpoints, (2) `MintTrameConfiance.inline` mounted on each of 5 simulator result sections following the established `futur_projection_card.dart:143` pattern, (3) a pre-emission gate in `coach_chat.py` Step 2 (BEFORE `_run_agent_loop` / orchestrator call) that short-circuits to a FATCA hand-off card when archetype + topic match.

Out of scope: real-time audit-log streaming, OAR-G batch report generation, additional archetypes beyond `expat_us`, EN locale FinSA sweep (Phase 94), benchmark literal `7000` constant (Phase 94).

</domain>

<decisions>
## Implementation Decisions

### COMP-01 — Coach message audit log table

- **Table name:** `coach_message_audits` (matches existing `coach_*` model namespace, plural per `audit_events` / `document_audit_logs` precedent).
- **SQLAlchemy model:** new file `services/backend/app/models/coach_message_audit.py`, mirroring the structure of `services/backend/app/models/audit_event.py` (existing minimal pattern: `id` UUID PK, `created_at` indexed, `Text` JSON for details).
- **Columns (all `nullable=False` except retention timestamps and `*_hash` for safety):**
  - `id` String UUID PK (default `lambda: str(uuid4())`)
  - `session_id` String, indexed (UUID for anonymous, user_id for authed — single column, hashed if authed)
  - `archetype` String (default `"swiss_native"`, nullable=True for anonymous)
  - `prompt_hash` String (SHA-256 hex of user prompt; never store raw prompt — nLPD)
  - `response_hash` String (SHA-256 hex of LLM response text)
  - `banned_term_hit` Boolean (default `False`; from `ComplianceGuard.BANNED_TERMS` filter result)
  - `eclairage_kind` String, nullable=True (e.g. `fiscal_margin_3a`, `default_premier`; null when no eclairage emitted)
  - `created_at` DateTime UTC, indexed (default `lambda: datetime.now(timezone.utc)`)
  - `retained_until` DateTime UTC, nullable=True (default `now + timedelta(days=3653)` ≈ 10 years per OAR-G art. 24)
- **Alembic migration filename:** `services/backend/alembic/versions/p93_coach_message_audit.py`. Revision ID `p93_coach_message_audit`. `down_revision = "p86_eclairage_delivered"` (current head). Idempotent guard via `inspector.get_columns` / `get_table_names` like p86. Verified forward+rollback in tests (Phase 95 will add `alembic check` CI gate; we ship the migration green here).
- **Hook insertion points (best-effort, never break the response — `try/except` + `Sentry.capture_exception`):**
  - `services/backend/app/api/v1/endpoints/coach_chat.py:2622` — RIGHT BEFORE `return CoachChatResponse(...)`. We have `loop_result["answer"]`, `safe_profile["archetype"]`, `_user.id`, `body.session_id` (or fallback to `str(_user.id)`), `sanitized_message`, and the `degraded`/`tool_calls` metadata. `banned_term_hit` derives from `loop_result.get("compliance_meta", {}).get("banned_terms_filtered", False)` (extend `ComplianceGuard` to surface it if not yet exposed).
  - `services/backend/app/api/v1/endpoints/anonymous_chat.py:347` — RIGHT BEFORE `db.commit()` so the audit row commits in the same transaction as `eclairage_delivered`. We have `result["answer"]`, `clean_message`, `session_id`, `eclairage` (kind = `eclairage.kind` if set else `None`). `archetype` is unknown for anonymous → store `"anonymous"`.
- **Hash helper:** new util `services/backend/app/utils/audit_hash.py` exposing `hash_for_audit(text: str) -> str` (SHA-256 hex truncated to 64 chars) + `prompt_hash_with_salt(text: str) -> str` if a per-tenant salt is configured. v1: unsalted SHA-256, salt deferred to v2.15.
- **Retention enforcement:** column-only for now; hard-delete cron job is Phase 96 territory. The point per FINMA inspector test is « can you show me the rows? » not « did you auto-purge at 10y+1d? ».

### COMP-03 — `ConfidenceBadge` on 5 simulators

There is **no `ConfidenceBadge` widget** today — `extraction_review_screen.dart:193 _buildOverallConfidenceBadge()` is a one-off inline helper, not a reusable primitive. The canonical 4-axis surface is `MintTrameConfiance` (`apps/mobile/lib/widgets/trust/mint_trame_confiance.dart`) with constructor `.inline(confidence: EnhancedConfidence, bloomStrategy: BloomStrategy.firstAppearance)`.

**Decision:** wire `MintTrameConfiance.inline` (NOT a new `ConfidenceBadge`) in each of the 5 simulator result sections. CLAUDE.md règle 9 requires « EnhancedConfidence + uncertainty band + enrichmentPrompts » — `MintTrameConfiance` already encodes all three (D-04 weakest-axis rendering, D-11 SemanticsService announce, axisPrompts). The phrase « ConfidenceBadge » in REQUIREMENTS.md COMP-03 is shorthand; the binding artifact is MTC.

- **Mounting pattern:** copy `apps/mobile/lib/widgets/profile/futur_projection_card.dart:143-149`:
  ```dart
  Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    child: MintTrameConfiance.inline(
      confidence: _resolvedConfidence,
      bloomStrategy: BloomStrategy.firstAppearance,
    ),
  ),
  ```
- **5 file paths + insertion lines:**
  | Simulator | File | Mount inside |
  |---|---|---|
  | 3a | `apps/mobile/lib/screens/simulator_3a_screen.dart` | `_buildResultSection()` line 600 — after `_buildImpactRow(... totalTaxSavedOverPeriod)` |
  | divorce | `apps/mobile/lib/screens/divorce_simulator_screen.dart` | inside the `MintResultHeroCard` result block (TBD by planner — search for hero result widget) |
  | frontalier | `apps/mobile/lib/screens/frontalier_screen.dart` | end of result column (TBD by planner) |
  | compound | `apps/mobile/lib/screens/simulator_compound_screen.dart` | after the displayMedium hero number at line 226 |
  | leasing | `apps/mobile/lib/screens/simulator_leasing_screen.dart` | end of result column (TBD by planner) |
- **Confidence source:** call `EnhancedConfidenceService.computeConfidence(coachProfile)` (reads from `CoachProfileProvider` via `Provider.of<CoachProfileProvider>(context).profile`) and pass result. When `coachProfile` is null/empty (anonymous flow), fallback to `EnhancedConfidence.fromBareScore(0.5)` so the trame still renders « low completeness » with axisPrompts inviting the user to fill profile.
- **Golden tests:** 5 widget golden files in `apps/mobile/test/screens/simulators/` — each renders the simulator with a fixed `CoachProfile` fixture and asserts MTC bloom region pixel-stable. Reuse `MintTrameConfiance` golden infra from Plan 04 (existing `mtc_golden_test.dart` covers the widget itself; we golden the integration).

### COMP-04 — FATCA pre-emission gating

- **Insertion point:** `services/backend/app/api/v1/endpoints/coach_chat.py` between line 2469 (`prompt_len = len(system_prompt)` log) and line 2474 (`orchestrator = await _get_orchestrator()`). New section header `# Step 2.5: FATCA pre-emission gate (COMP-04)`.
- **Gate logic (tightly scoped to avoid false positives on `expat_us` budget questions):**
  ```python
  if (coach_ctx and coach_ctx.archetype == "expat_us"
      and _topic_is_fatca_sensitive(sanitized_message)):
      handoff = build_fatca_handoff_card(language=body.language)
      # ... emit audit row with banned_term_hit=False, eclairage_kind="fatca_handoff"
      return CoachChatResponse(message=handoff.message, tool_calls=[handoff.tool_call], ...)
  ```
- **Topic detection helper (new `services/backend/app/services/coach/fatca_gate.py`):**
  - `_topic_is_fatca_sensitive(text: str) -> bool` — case-insensitive regex match on the sanitized message AGAINST a curated tight list:
    - `\b(3a|3eme pilier|troisi[eè]me pilier|pillar\s*3a|pilier\s*3a)\b`
    - `\bPFIC\b`
    - `\b(treaty|convention\s+(CH-US|fiscale\s+US|bilat[eé]rale\s+US))\b`
    - `\b(foreign\s+trust|form\s+3520|fbar)\b`
  - Returns `True` only if the user message contains a 3a/PFIC/treaty token. Mortgage / budget / divorce / AVS questions for `expat_us` users pass through unchanged.
- **Hand-off card builder (new `build_fatca_handoff_card(language)` in `services/coach/fatca_gate.py`):**
  - Returns a `FatcaHandoffPayload` (Pydantic model with `.message: str`, `.tool_call: dict` mirroring existing `route_to_screen` shape).
  - Message text: derived from `fallback_templates.FATCA_FBAR_GUIDANCE` (already exists, `fallback_templates.py:127-157`) with the trailing impératif replaced by an explicit hand-off : « Cette situation demande un·e spécialiste US-CH cross-border. Prends rendez-vous avant tout versement 3a. »
  - 6-locale support : reuse `_LANGUAGE_NAMES` map from `claude_coach_service.py` ; ARB keys `fatcaHandoffTitle`, `fatcaHandoffBody`, `fatcaHandoffCta` (3 new keys × 6 locales = 18 ARB entries; `validate_arb_parity()` MCP must pass).
  - `tool_call` routes to a new screen ID `/handoff/fatca-specialist` OR (lighter) reuses existing `/advisor` screen with a `?context=fatca` query param. Planner picks based on `apps/mobile/lib/screens/advisor/` survey.
- **Audit emission for FATCA gate:** the gated response still writes a `coach_message_audits` row with `eclairage_kind="fatca_handoff"`, `response_hash` of the canned text, `banned_term_hit=False`. The inspector must see this gate fired.
- **Sentry breadcrumb:** `Sentry.add_breadcrumb({"category": "compliance.fatca_gate", "data": {"archetype": "expat_us", "topic_match": <regex_label>}})` so we can audit gate fire-rate vs `expat_us` traffic and verify the gate isn't over- or under-triggering.

### Claude's discretion

- Hand-off screen route choice: new `/handoff/fatca-specialist` (cleaner, isolates compliance UX from existing `/advisor` matching) vs. reusing `/advisor?context=fatca` (lower diff, but advisor screen may not exist in MVP). Planner surveys `screens/advisor/` and picks lighter option.
- Whether to surface MTC inside `MintResultHeroCard` (used by divorce/leasing) as a slot prop OR as a sibling widget after the card. Prefer slot prop if `MintResultHeroCard` already accepts a `confidenceSlot` param; otherwise sibling.
- `prompt_hash` salt: per-process random salt vs config-driven secret. v1 ships unsalted (FINMA cares about presence, not unlinkability); add salt env var `AUDIT_PROMPT_SALT` in Phase 96.

</decisions>

<code_context>
## Existing Code Insights

### Reusable assets

- `services/backend/app/models/audit_event.py` — minimal SQLAlchemy `Base` audit-row pattern (id UUID PK, indexed user_id + event_type + created_at, JSON `details_json`). Direct template for `CoachMessageAudit`.
- `services/backend/app/models/document_audit_logs.py` — already implements 730-day retention via `retained_until` column with `+ timedelta(days=730)` default; we extend pattern to 3653 days for OAR-G 10y.
- `services/backend/app/services/coach/fallback_templates.py:127-157` — `fatca_fbar_guidance(ctx)` produces the 4-paragraph FATCA/FBAR/PFIC/CH-US-treaty content. Reuse text body, swap closing impératif for hand-off CTA.
- `services/backend/app/services/coach/doctrine_checks.py:291-296` — `expat_us` archetype regex requirements (`FATCA`, `PFIC` MUST appear in response). Confirms our pre-emission gate aligns with existing post-validation rule.
- `apps/mobile/lib/widgets/trust/mint_trame_confiance.dart` — 4-axis confidence renderer with `.inline` constructor + `BloomStrategy.firstAppearance` + a11y semantics. The actual badge.
- `apps/mobile/lib/services/financial_core/confidence_scorer.dart:755 EnhancedConfidenceService.computeConfidence(profile)` — builds `EnhancedConfidence` from a `CoachProfile`. Single source of truth.
- `apps/mobile/lib/widgets/profile/futur_projection_card.dart:143` — canonical mounting pattern (Padding + MintTrameConfiance.inline). Copy verbatim into 5 simulator screens.

### Established patterns

- Alembic migrations under `services/backend/alembic/versions/` use `pNN_<slug>.py` naming (p86 most recent; p93 next slot). Idempotent upgrades via `inspect(bind).get_columns(...)` guard before `op.add_column` / `op.create_table`. `down_revision` chains explicitly.
- Best-effort audit writes wrap the entire block in `try/except Exception` + `logger.warning` + optional `Sentry.capture_exception`. Pattern proven in `coach_chat.py:2305-2365` (profile_extractor block).
- New backend services live in `services/backend/app/services/coach/<name>.py` with explicit `__all__` and pytest twin in `services/backend/tests/test_<name>.py`.
- Mobile new ARB keys go to all 6 of `lib/l10n/app_{fr,en,de,it,es,pt}.arb` simultaneously, then `flutter gen-l10n` regenerates `app_localizations*.dart`. `validate_arb_parity()` MCP must be green pre-PR.

### Integration points

- `coach_chat.py:2622` (just before `return CoachChatResponse`) — audit hook A.
- `anonymous_chat.py:347` (just before `db.commit()`) — audit hook B.
- `coach_chat.py:2470-2474` (between system_prompt log and orchestrator init) — FATCA gate.
- 5 simulator screens, each at the bottom of their result section — MTC mount.

</code_context>

<specifics>
## Specific Ideas

- **Test fixture for FATCA gate:** `services/backend/tests/test_fatca_pre_emission_gating.py` — table-driven cases: `(archetype, message) → expected_gate_fires_bool`. Cover: `expat_us + "j'ai 70k de 3a"` → True, `expat_us + "j'ai 700 CHF de courses ce mois"` → False (negative test, prevents over-blocking), `swiss_native + "je veux discuter PFIC"` → False (archetype gate), `expat_us + "PFIC obligation?"` → True.
- **Promptfoo cross-coverage:** when Phase 95 ships promptfoo, add 4 fixtures under `evals/fatca_handoff/` so FATCA gate is asserted in eval suite, not just unit. Out of scope for Phase 93 but flag in plan handoff notes.
- **FINMA paragraph references in code comments:** every audit-related function gets a docstring `"""...per OAR-G art. 24 + FINMA Guidance 8/2024 §VI."""` so a Phase 97 counsel review traces the control to the legal source. Same pattern as compliance_guard `LSFin art. 3/8 (quality of financial information)` reference (`compliance_guard.py:14`).
- **Sentry tag rollup:** every `coach_message_audits` insert also fires `Sentry.set_tag("audit_emitted", "true")` on the current scope. Phase 96 dashboard then queries audit-emission rate vs response rate; ratio < 1.0 = lost audit row = P0 page.

</specifics>

<deferred>
## Deferred Ideas

- Real-time audit-log streaming to a SIEM (defer to v2.16+ when a SIEM is selected; Postgres rows + nightly export are sufficient for FINMA inspector test).
- Automatic OAR-G periodic report generation (`services/backend/app/services/compliance/oar_g_report.py`) — not required for MVP, defer to v2.15.
- Additional archetypes for FATCA-style gating (e.g. `cross_border` permis G with `assurance maladie LAMal vs CMU` topic, `independent_no_lpp` with `LPP volontaire OPP2`) — defer to v2.15 once we observe `expat_us` gate fire-rate.
- Auto-purge cron at retained_until expiry — defer to Phase 96 Production Observability (needs scheduler infra).
- FINMA Control Matrix row for COMP-01/03/04 — Phase 97 ships the matrix; we just produce the implementing controls here.

</deferred>
