---
date: 2026-05-20
status: Decided
deciders: Julien (delegated) + 6-agent expert panel
phase: 01-mint-production-readiness-audit
topic: Bar, scope, method, sequencing, and output format for Phase 01 audit
panel_observations: engram #266 (PM) · #267 (QA) · #269 (Business) · #271 (Security) ; Architect + AI verdicts inlined in synthesis turn
context_doc: ../phases/01-mint-production-readiness-audit-identify-top-blockers-to-fir/01-CONTEXT.md
---

# ADR · Phase 01 Production-readiness audit — Bar and Scope

## Context

Phase 01's job is to identify top blockers to first beta users. The audit will drive 2-6 months of work. Wrong scope = thousands of LOC in wrong direction. Existing baseline (`.planning/codebase/CONCERNS.md`, 2026-04-22) is 28 days stale and predates two load-bearing events : ADR 2026-05-17 (L1/L2 calc-engine split) and Phase 02-deploy substrate (event-log + dual-write FF, 2026-05-18/19). The 17-question questionnaire (`01-QUESTIONS.json`) was authored to drive this decision but its options proved insufficient on 4 surfaces (audit axes, archetype gating, life-event-vs-corpus coupling, refusal-experience scoring).

## Decision

Run Phase 01 as a **walkthrough-grounded audit** producing a **delta against existing artifacts** (not a parallel rewrite), with 10 sub-phases sequenced user-flow-first.

### 1. Bar (Q-01/02/03)

- First-tester cohort : **10-30 NDA Geneva/Lausanne FR-native, no journalist exposure**.
- Mandatory end-to-end flow : **onboarding → coach chat emitting ≥1 cited number within 3 turns, tool-invocation trace required, L2 backend path enforced**.
- Hero number : **marge fiscale 3a annuelle** (single input = salary ; single output = CHF savable ; LIFD art. 38 grounded).
- Acceptable roughness : visual polish · i18n EN/DE/ES/IT/PT · non-priority archetypes (but **explicit « pas encore supporté » gate screens**, no silent fallback).
- Zero tolerance : LSFin banned-term emission · accent FR bugs · wrong-number-without-citation · crash on golden path.

### 2. Scope (Q-04/05/06)

- Full-stack audit (option d) **+ 3 panel-elevated axes** : L1/L2 boundary integrity · façade-without-wiring · coach-runtime.
- DESIGN/VOICE compliance sampled on 5 critical screens (onboarding wizard · coach chat · first-insight card · scanner result · refusal/error). **VOICE on coach surfaces = core, not polish.**
- i18n : FR-only beta-1 · structural ARB orphan cleanup (1864 known) · semantic banned-term sweep extended to 6 locales (not just FR).

### 3. Method (Q-07/08/09)

- Full `/gsd-map-codebase` refresh — 5 parallel mappers (tech · arch · quality · **boundary-integrity** · **coach-runtime**) + 6th synthesis pass.
- Maestro sweep on 2 archetypes (swiss_native + swiss_native_couple) + adversarial coach probes (refusal-bait · banned-term-bait · citation-missing · context-bloat regression per obs #74).

### 4. Coverage (Q-10/11/12)

- 2 archetypes (swiss_native + swiss_native_couple) + **HARD GATE** on other 6 → « pas encore supporté » screen + waitlist email capture.
- Top 6 Swiss axes (AVS / LPP / 3a / salaire / fortune / charges) + **HARD GATE** outside top-6 → scripted-soon copy (not LLM, corpus only covers 6).
- FR-only.

### 5. Sequencing (Q-13/14/15)

- User-flow ordering. Critical-path lens rejected.
- Mix : mini-phases for critical (onboarding→first-insight, L1/L2 strangler-fig) + bundled for polish (ARB cleanup, god-file splits, post-beta DESIGN/VOICE).
- 2-3 parallel sub-phases, file-overlap-guarded.

### 6. Output (Q-16/17)

- Dual : ROADMAP addendum (GSD entry points) + `.planning/backlog/PROD-READINESS-V1.md` (human-readable).
- T-shirt sizing (S/M/L/XL) per sub-phase. Day estimates rejected as fake precision.

### 7. Pre-beta P0 blockers (panel-surfaced, not in option set)

- P0-1 Archetype HARD GATE fix (`coach_profile.dart:96`)
- P0-2 Semantic banned-term sweep (banned_terms_arb.py · 6 locales · garanti-family-extension)
- P0-3 DSAR fact_event manifest fix (privacy.py:327-352)
- P0-4 Forced tool-invocation merge-blocker (obs #74)

## Counter-arguments and data gaps

### Counter-arguments considered

- **PM dissented on Q-01** : argued Julien-only bar (a) to avoid « audit-on-paper-not-device disease ». Rejected — 5 other panelists flagged real blockers that only surface with non-Julien testers (FATCA fallback, banned-term EN, coach suppression). PM's premise retained as METHOD (sub-phase 01.1 walkthrough-first) rather than BAR lowering.
- **Business analyst argued FR+DE coverage** for the 62.6 % DE-CH market. Rejected — DE without native voice consultant ships Hochdeutsch Google-Translate that violates VOICE_SYSTEM more decisively than any lint miss. Re-litigation trigger : DE-CH native voice consultant hired.
- **4-archetype coverage (architect + QA + security)** rejected on (i) FATCA modeling gap for expat_us ; (ii) LAVS art. 29quinquies frontalier TODO unresolved (`avs_estimation_service.py:165`) ; (iii) 6/8 archetypes have no golden test baseline (CONCERNS.md F3). Re-litigation trigger : archetype-gate validated + golden tests added.
- **Defer DESIGN/VOICE to post-beta polish (PM Q-05=c)** rejected for coach surfaces — banned-term emission or VOICE drift on the coach IS the product death. Polish stays only for non-coach UI.
- **Full 8-archetype Maestro sweep (Q-08=a unmodified)** rejected — sim-crash contamination per `feedback_sim_crash_mitigation` + sweeping 6 archetypes without golden = test theater.
- **Critical-path lens (Q-13=a)** rejected — `mint-calc-engine-v1` shipped 109 commits of substrate with USER VALUE DELIVERED = 0 (STATE.md line 76). User-flow ordering is the corrective.

### Data gaps surfaced by the panel (not yet closed)

- `apps/mobile/assets/config/personas.json` : 4 demo personas (young_professional / stressed_student / self_employed / family_plan) do NOT map to the 8 LSFin archetypes. Any QA claim citing personas.json is invalid evidence per 0-trust §9. **Action** : audit verifies + documents (01.2 quality mapper).
- `tools/simulator/goldens/manifest.json` : empty bake — manifest claims slots, none rendered. Coverage claim « 2 archetypes goldened » is half-true. **Action** : 01.10 verifies + closes.
- `avs_estimation_service.py:165` : LAVS art. 29quinquies TODO. **Action** : flagged in 01.3 boundary audit but NOT in beta-1 scope per Q-10 decision.
- `MILESTONE-CHAT-AS-VERB-2026-05-09` : referenced by architect ; location not visible in this synthesis. **Action** : verify in 01.2 quality mapper pass.
- `banned_terms_arb.py` docstring admits the « optimal / meilleur / parfait / sans risque / assuré » family is UNSCANNED across all 6 locales. **Action** : P0-2 closes.
- `apps/mobile/pubspec.yaml:130` Gambarino italic synthesis comment is outdated — Fontshare ships real 400i master ; current Flutter bundle synthesizes from regular. **Action** : P1-5 (license + bundle Gambarino-Italic.otf).

## Re-litigation triggers

- Archetype-gate built + validated → expand to 4 archetypes.
- DE-CH native voice consultant hired → reopen Q-12 (FR+DE).
- Sentry traffic appears post-beta-1 → switch lens from user-flow to Sentry-driven.
- Coach refusal-rate > 30 % on top-6 axes → reopen Q-11 coverage.
- `_to-MINT 4` design audit reveals systemic drift → Q-05 may need full per-screen scoring.

## Consequences

- Phase 01 timeline compresses from « ~4 weeks survey-driven » to « ~10-14 days walkthrough-grounded » (PM premise).
- Existing artifacts (CONCERNS.md, audit-facade-systemique, ADR 2026-05-17) stay canonical but get `superseded_by:` frontmatter where the audit produces deltas.
- 10 sub-phases declared in CONTEXT §8. Each routes through `/gsd-plan-phase 01.X` for its own DISCUSS → PLAN → EXEC → VERIFICATION stack.

— Decided 2026-05-20. Owner : Julien. Coordinator : Claude. Reviewers : 6-agent panel (see header).
