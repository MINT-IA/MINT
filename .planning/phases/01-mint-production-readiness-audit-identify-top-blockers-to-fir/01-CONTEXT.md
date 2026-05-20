---
phase: 01-mint-production-readiness-audit
title: Phase 01 — production-readiness audit, CONTEXT (panel-synthesized)
status: Decided 2026-05-20
panel_session: 2026-05-20 evening, 6-agent parallel (product-manager · architect-review · qa-expert · business-analyst · ai-engineer · security-auditor)
panel_observations: engram obs #266 (PM), #267 (QA), #269 (Business), #271 (Security) ; Architect + AI verdicts inlined in this session
supersedes: none (this is the first CONTEXT for phase 01)
related_adr: .planning/decisions/2026-05-20-audit-01-bar-and-scope.md
---

# Phase 01 — Production-readiness audit — CONTEXT

> Goal of this document : freeze the **scope · bar · method · sequencing · output format** of the audit, so `/gsd-plan-phase 01` can be invoked with grounded inputs. Decisions below override the bare option-set in `01-QUESTIONS.json` where the panel surfaced a better path.

## 0. Where this phase lives in the bigger picture

MINT today : staging is the test loop (no real prod users yet), 7 Sentry hotfixes shipped 2026-05-19/20, pgvector RAG live with 103 docs embedded, app icon menthe « m. » shipped on PR #663. The pivot 2026-04-12 to « lucidité, pas protection » + ADR 2026-05-17 (L1 mobile-canonical / L2-L4 backend-canonical) landed AFTER the existing `.planning/codebase/CONCERNS.md` was written (2026-04-22). That makes CONCERNS.md materially stale on the load-bearing architectural axis.

The 17-question panel exists because Phase 01's output drives 2-6 months of work. Wrong scope = a few thousand lines of code in wrong direction.

## 1. Bar — what « usable » means for first beta users (Q-01 → Q-03)

- **Q-01 — First testers** : **closed beta of 10-30, NDA, FR-native, Geneva/Lausanne, no journalist exposure.**
  Panel : 5/6 agents picked (b). PM dissented with (a) « Julien+friends » arguing the lower bar avoids audit-on-paper-not-device disease. Synthesis : **PM's premise is integrated as method (§3 walkthrough-first), not as bar lowering.** Bar stays (b) because anything lower lets coach trust-failures, archetype silent-fallback, and LSFin banned-term leaks ship undetected (security + AI + business all flagged blockers that don't surface with Julien-only testing).
- **Q-02 — Flows that MUST work end-to-end** : **onboarding → coach chat that emits ≥1 cited number within 3 turns, with tool-invocation trace + L2 backend path enforced.**
  Hero number = **marge fiscale 3a annuelle** (PM proposal) : single input (salary), single output (CHF savable), LIFD art. 38 grounded, no LSFin verb minefield. Implementation must go through L2 backend (architect) and trigger forced tool-invocation (AI engineer, obs #74). Scanner + scenes deferred to Phase 02+.
- **Q-03 — Acceptable roughness** : **visual polish · i18n EN/DE/ES/IT/PT · non-priority archetypes can be rough — but must show explicit « pas encore supporté » gate screens, not silent fallback.** Zero tolerance on : LSFin banned-term emission, accent FR bugs, wrong-number-without-citation, crash on golden path.

## 2. Scope — what the audit covers (Q-04 → Q-06)

- **Q-04 — Audit axes** : **full-stack (d) + 3 axes the option set missed**.
  Core (option d) : code · infra · Sentry remainders · UX-live via Maestro · DESIGN/VOICE/i18n/archetypes.
  **Added axes (panel-elevated)** :
  - **A1 · L1/L2 boundary integrity** (architect) — grep every cross-layer `_calculate*` / `simulate*` / sensitivity logic against `services/backend/app/models/lucidity/_payload.py` discriminator. Each L2-class calculation found mobile-side = P0 strangler-fig finding.
  - **A2 · Façade-without-wiring** (architect) — every backend endpoint / coach tool / public Dart API → grep opposite-layer callers ; zero callers = façade.
  - **A3 · Coach-runtime** (AI engineer) — prompt assembly, RAG corpus coverage, citation-gate enforcement, banned-term sanitizer regressions, refusal-with-context vs trust-collapse paths.
- **Q-05 — DESIGN/VOICE compliance** : **sample 5 critical screens** (onboarding wizard · coach chat · first-insight card · scanner result · refusal/error state). VOICE on coach screens is **NOT polish** (AI engineer reclassed it as core scope, not deferrable). PM-proposed full deferral rejected.
- **Q-06 — i18n parity** : **FR-only beta + structural ARB orphan cleanup (1864 known) + 120 hardcoded-string scan**. Multilingual user-facing parity defers to a dedicated post-beta phase. **BUT** : semantic banned-term sweep (security, see §6 hot items) extends to ALL 6 ARB locales now, because the public-repo discipline means any leak is one grep away from a journalist.

## 3. Method — how to identify gaps (Q-07 → Q-09)

- **Q-07 — Refresh CONCERNS.md** : **full refresh via `/gsd-map-codebase` (option a) — unanimous panel call**. Reasons : (i) 28-day staleness ; (ii) ADR 2026-05-17 (L1/L2 split) post-dates CONCERNS.md ; (iii) Phase 02-deploy substrate (event-log + dual-write FF) landed 2026-05-18/19 ; (iv) Wave 1c coach suppression bug discovered 2026-05-15. Treating stale CONCERNS.md as canonical = re-litigating settled boundaries while missing new drift.
- **Q-08 — Maestro sim walkthrough** : **partial sweep × 2 archetypes + adversarial coach probes**. Sweep : swiss_native + swiss_native_couple end-to-end on onboarding → coach → first-insight. Coach adversarial probes added : refusal-bait, banned-term-bait, citation-missing, context-bloat regression (obs #74). Full 8-archetype sweep rejected (sim-crash contamination per `feedback_sim_crash_mitigation` + golden-test gap for 6/8 archetypes).
- **Q-09 — Parallel mappers** : **5 parallel mappers** = tech · arch · quality · **boundary-integrity** (new, architect) · **coach-runtime** (new, AI engineer). Sequential synthesis at end via 6th mapper.

## 4. Coverage targets (Q-10 → Q-12)

- **Q-10 — Archetypes** : **swiss_native + swiss_native_couple ONLY + HARD GATE on the other 6 → « pas encore supporté » screen + waitlist**.
  Panel split 4/3 (b vs c). Decisive arguments for (b-modified) :
  - **Business analyst** : `coach_profile.dart:96` silently falls back to `swiss_native` when archetype-detection signals are ambiguous. An expat_us hitting that fallback triggers a 3a recommendation that **violates FATCA + LSFin art. 8/10**. This is a P0 legal blocker that pre-empts other audit work.
  - **AI engineer** : RAG corpus is FR-only swiss-finance, 6/8 archetypes have no grounded knowledge graph entries.
  - **QA** : F3 in CONCERNS.md confirms only 2 archetypes have golden tests.
- **Q-11 — Life events** : **top 6 Swiss axes (AVS / LPP / 3a / salaire / fortune / charges)** + **HARD GATE** : life events outside top-6 route to scripted-soon copy, NOT to LLM (coach corpus only knows 6 axes, per AI engineer). Other 12 life events listed in deferred-list with stub screens flagged in coverage matrix.
- **Q-12 — Languages** : **FR-only beta-1** (5/6 panel). Security minority pick was b (FR+EN) — addressed by §6 hot items semantic-banned-term sweep extension covering all 6 locales structurally even while UI stays FR.

## 5. Sequencing strategy (Q-13 → Q-15)

- **Q-13 — Priority lens** : **user-flow ordering** (unanimous). Critical-path = STATE.md line 76 « 109 commits shipped substrate, USER VALUE DELIVERED: 0 » disease. Sentry-driven moot at N=0 users. Effort-leverage inside flows OK, never between.
- **Q-14 — Granularity** : **mix — mini-phases for critical perimeters (onboarding→first-insight + L1/L2 strangler-fig start) ; bundled phases for polish (ARB cleanup, god-file splits, DESIGN/VOICE per-screen post-beta).**
- **Q-15 — Parallel sub-phases** : **2-3 max, gated by file-overlap check.** Mobile-only ARB cleanup CAN parallel a backend service migration. Two sub-phases both touching `coach_chat.py` CANNOT.

## 6. Hot items the option set missed (panel-surfaced, pre-empt other work)

These are findings the panel raised that aren't in the 17 questions. They go to Phase 01 backlog as **P0 (pre-beta)** or **P1 (within audit method)**.

### P0 · pre-beta blockers (cannot ship beta-1 without)

- **P0-1 — Archetype HARD GATE** (business + security) : fix `apps/mobile/lib/models/coach_profile.dart:96` silent fallback. Ambiguous detection → « pas encore supporté » screen. Pre-empts FATCA + LSFin art. 10 exposure. **T-shirt M**.
- **P0-2 — Semantic banned-term sweep** (security) : `tools/checks/banned_terms_arb.py` only covers garanti-family. « optimal/meilleur/parfait/sans risque/assuré » UNSCANNED in all 6 ARB locales (tool docstring admits). EN « optimal allocation » passes current lint, fails LSFin art. 9. Extend to all 6 locales before beta user #1. **T-shirt S**.
- **P0-3 — DSAR fact_event manifest gap** (security, obs #220 FLAG-4) : `services/backend/app/api/v1/endpoints/privacy.py:327-352` omits `fact_event` rows from nLPD art. 32 DSAR receipt. Required before first non-Julien user. **T-shirt S**.
- **P0-4 — Forced tool-invocation merge-blocker** (AI engineer, obs #74) : if coach number not preceded by `tool_use` trace, REJECT/retry with scripted fallback. Wave 1c proved feasible. Currently a hot suppression bug per `claude_coach_service.py:660` doctrine + null `profile_context` interaction. **T-shirt M**.

### P1 · audit-method line items

- **P1-1 — Q-00 (architect)** : audit produces a **DELTA** against existing artifacts (`.planning/codebase/CONCERNS.md`, `.planning/audit-facade-systemique-2026-04-18/`, ADR 2026-05-17), not a parallel rewrite. Stale artifacts get `superseded_by:` frontmatter, not deletion.
- **P1-2 — Coach trust monitor instrumentation** (AI engineer) : (a) banned-term-fired counter (ComplianceGuard already counts, expose to dashboard), (b) numbers-emitted-without-citation (HallucinationDetector signal), (c) tool_use-rate per intent (suppression detector — alarms if `get_retirement_projection` fires < 90 % on retirement queries). Required before beta opens.
- **P1-3 — Replay corpus** (AI engineer) : ≥20 prompts × 2 archetypes, probing refusal-bait + banned-term-bait + citation-missing + obs-#74 context-bloat regression. Each replay must assert : `stop_reason=tool_use` OR cited number OR scripted refusal — never free-text « Je n'ai pas cette donnée ». **T-shirt L**.
- **P1-4 — `_to-MINT 4` design pack alignment audit** (added 2026-05-20 per Julien request) : check `~/Downloads/_to-MINT 4/` design specs against current Flutter screens. Sample 5 critical screens from §2-Q-05. Output : screens-vs-design alignment matrix. **T-shirt M**.
- **P1-5 — Gambarino italic font drift** (surfaced 2026-05-20 during icon integration) : `apps/mobile/pubspec.yaml:130` documents « Gambarino italic is synthesized via style: italic; Fontshare only ships Gambarino-Regular upright ». Empirical evidence from the icon-pack integration session : Fontshare's CDN serves `gambarino@400i` as a distinct master (visually validated against the designer's `flat-1024.png` reference, hash-different from synthesized-italic-from-regular). **The pubspec comment is outdated** and every in-app Gambarino italic text shows Flutter's synthesized slant, not the real cursive italic — creating brand drift between the new app icon (real 400i) and every screen using Gambarino italic. Fix path : license + bundle `Gambarino-Italic.otf` from Fontshare, update pubspec fonts block. **T-shirt S** (font license + 1 file + pubspec edit). Surface in 01.9 design alignment audit.

## 7. Output format (Q-16 → Q-17)

- **Q-16 — Output** : **both** : ROADMAP addendum (GSD entry points, machine-actionable) + `.planning/backlog/PROD-READINESS-V1.md` (human-readable inventory Julien can scan in 5 min). Unanimous panel call.
- **Q-17 — Cost estimates** : **t-shirt sizes S/M/L/XL** per sub-phase. Day-precision rejected (fake precision per Karpathy #1). No-estimate rejected (defeats sequencing).

## 8. Phase 01 sub-phases — emerging from synthesis

Provisional decomposition (to be refined by `/gsd-plan-phase 01.X` per sub-phase) :

| Sub-phase | T-shirt | Lens | Goal |
|---|---|---|---|
| 01.1 — Walkthrough-first grounding | M | user-flow | Run onboarding → first-insight on staging (post-icon merge) ; document blockers via Maestro + Julien observations. **PRE-AUDIT** : grounds the audit in observed reality, not abstract grep. |
| 01.2 — /gsd-map-codebase refresh (5 mappers) | XL | method | tech / arch / quality / boundary-integrity / coach-runtime in parallel. Output : 5 fresh `.planning/codebase/` docs supersede stale CONCERNS.md. |
| 01.3 — L1/L2 boundary integrity audit | L | architecture | Grep cross-layer `_calculate*` + façade-without-wiring + barrel-bypass. Output : P0 strangler-fig finding list ordered per ADR D-CE-09 (Monte Carlo first). |
| 01.4 — Coach-runtime audit + trust monitor + replay corpus | XL | AI/coach | Build replay corpus 20 prompts × 2 archetypes. Wire trust monitor telemetry (P1-2). Force-tool-invocation merge-blocker (P0-4). |
| 01.5 — Archetype HARD GATE fix | M | security | `coach_profile.dart:96` silent-fallback fix + waitlist screen. (P0-1) |
| 01.6 — Semantic banned-term sweep + ARB cleanup | M | compliance | banned_terms_arb.py extension to 6 locales + garanti-family-extension + 1864 ARB orphan cleanup. (P0-2) |
| 01.7 — DSAR fact_event manifest fix | S | privacy | privacy.py:327-352. (P0-3) |
| 01.8 — Maestro assertion-grammar refactor | M | QA | Tier-1 grounded-values, tier-2 non-crash, tier-3 exploratory. Currently flows assert presence not correctness. |
| 01.9 — `_to-MINT 4` design alignment audit | M | UX | Screens-vs-design matrix on 5 critical screens. (P1-4) |
| 01.10 — Maestro sweep × 2 archetypes + adversarial coach probes | L | QA | Q-08 execution. Includes coach-runtime adversarial probes. |

**Critical path** : 01.1 → (01.5 + 01.6 + 01.7) in parallel → (01.2 + 01.3 + 01.4 + 01.9) in parallel → (01.8 + 01.10) → Phase 02 plan.

## 9. Counter-arguments (CLAUDE.md §8 wiki schema requirement)

- **« Why 2 archetypes not 4 ? »** — Business analyst's expat_eu/frontalier expansion (Q-10=c) was rejected on FATCA + LAVS art. 29quinquies modeling gaps + 6/8 golden-test gap. If a competitor ships frontalier-credible MINT-clone first, this hurts ; mitigation = 01.5 includes a « waitlist with email capture » so we measure latent demand without shipping wrong numbers.
- **« Why FR-only when DE = 62.6 % market ? »** — Business analyst flagged this. Rejected because DE without native voice consultant ships Google-Translate Hochdeutsch that breaks VOICE_SYSTEM more decisively than any banned-term lint miss. Re-litigation trigger : if a DE-CH native voice consultant is hired.
- **« Why VOICE on coach is core, not polish ? »** — AI engineer reclass. Counter : VOICE is subjective ; polish-now-VOICE-later is the standard pattern. Rejected because banned-term emission in beta = brand-defining failure on first contact + LSFin liability ; VOICE drift on coach = product death (the coach IS the product).
- **« Why 10-30 beta and not Julien+friends ? »** — PM's (a) was the most-contested call. PM argument : audit-on-paper-not-device disease. Counter : 5 other panelists flagged that Julien-only testing hides FATCA fallback + coach suppression + banned-term emission in EN ARB. Resolution : keep bar at 10-30 NDA but make audit walkthrough-first (sub-phase 01.1) per PM premise.

## 10. Data gaps (CLAUDE.md §8 wiki schema requirement)

- **`apps/mobile/assets/config/personas.json`** contains 4 demo personas (young_professional / stressed_student / self_employed / family_plan) that **do NOT map to the 8 LSFin archetypes** (per business analyst, obs #269). Any QA claim citing personas.json is invalid evidence per CLAUDE.md §9 0-trust. **Action** : either update personas.json to map to archetypes or document it as demo-only.
- **`tools/simulator/goldens/manifest.json`** : QA expert flagged as empty bake (manifest claims slots, none rendered). Coverage claim « 2 archetypes goldened » is half-true. **Action** : 01.10 verifies + closes.
- **`services/backend/app/services/retirement/avs_estimation_service.py:165`** has a TODO on LAVS art. 29quinquies (frontalier bilateral). Confirmed by business analyst. **Action** : flagged in 01.3 boundary audit but not in beta-1 scope per Q-10 decision.
- **`MILESTONE-CHAT-AS-VERB-2026-05-09`** is referenced by architect but not visible in this CONTEXT's read path. **Action** : verify location during 01.2 quality mapper pass.

## 11. Re-litigation triggers (when to revisit Phase 01 decisions)

- Archetype-gate (P0-1) gets built and validated → reconsider Q-10 = c (4 archetypes).
- DE-CH native voice consultant hired → reconsider Q-12 = b (FR+DE).
- Real Sentry traffic appears post-beta-1 → switch Q-13 lens from user-flow to Sentry-driven.
- Coach trust monitor (P1-2) reveals refusal-rate > 30 % on top-6 axes → reopen Q-11 (top-6 coverage may be too narrow).
- `_to-MINT 4` design audit (01.9) reveals systemic drift → Q-05 may need full per-screen scoring (not sample-5).

## 12. Inputs for `/gsd-plan-phase 01` and per-sub-phase planning

The above scope is the **goal** layer. `/gsd-plan-phase 01.1` (walkthrough-first) starts the execution layer. Each sub-phase has its own DISCUSS → PLAN → EXEC → VERIFICATION artifact stack per CLAUDE.md §8.

**Engram observations to cite as prior_finding_refs in downstream phases** :
- #74 (Wave 1c coach context-bloat suppression — AI engineer)
- #220 (Phase 02 QA Security Audit FLAG-4 DSAR — security)
- #266 (PM panel verdict)
- #267 (QA panel verdict)
- #269 (Business analyst panel verdict — FATCA exposure)
- #271 (Security auditor panel verdict)
- #43, #67 (prior security wave passes — security)

— Decided 2026-05-20. Next step : `/gsd-plan-phase 01.1` once PR #663 (icon) merges and reaches staging.
