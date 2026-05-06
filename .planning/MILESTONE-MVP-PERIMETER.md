# MILESTONE — MVP Perimeter (minimum that's *alive*)

> **Author** : Claude (Senior Eng synthesis, autonomous Product Leader per `feedback_post_phase_panel_loop.md`).
> **Date** : 2026-05-06.
> **Status** : Proposed.
> **Path note** : brief referenced `MINT.phaseA.nosync` — that path does not exist on disk. Doc written against `/Users/julienbattaglia/Desktop/MINT.nosync` (HEAD `6c7d1491`).

---

## 1. « Living MVP » — definition

A MINT MVP is *alive* iff **all five** are true on a fresh-install device, single 20-min session :

1. **Proactive coach** — chat opens itself. 7 triggers ship (`proactive_trigger_service.dart`, `MASTERPLAN:179`) + tone chips (`coach_chat_screen.dart:2340`), but opener spec (`MVP-PLAN:75-83`) NOT in empty-state.
2. **Real data ingestion** — « j'ai 34 ans, 7'500 brut à Lausanne » persists. `save_fact` LLM-tool **dead for anon** (`coach_chat.py:1963-1966` strips `INTERNAL_TOOL_NAMES`). Dart regex fallback ships (`fact_extraction_fallback.dart:38`).
3. **Real calculations** — `lib/services/financial_core/` 16 calculators (AVS/LPP/FRI/tax/MC). DONE.
4. **Real UX loop** — `Action → Mémoire + Confiance + Projections → Aujourd'hui` (`MASTERPLAN:144-158`). CapEngine + CapMemoryStore + ActionSuccess ship (`:172-174`).
5. **Real audit trail** — banned-terms lint (commit `76178a7f`) ; walker nightly CI (PR #453) ; walker never *run* (`decisions/2026-05-04-...:32`).

---

## 2. The 7 must-have features (ranked)

| # | Feature | One-line user value | Endpoint | Screen(s) | LSFin gate | Shipped | Validate (h) | Acceptance test |
|---|---|---|---|---|---|---|---|---|
| 1 | **Anon chat remembers** | Âge/canton/salaire dits → retenus sans compte. | `POST /coach/anonymous-chat` + `save_fact` mirror | `coach_chat_screen.dart`, `landing_screen.dart` | 8 al.6 | **N** — `coach_chat.py:1963-1966` strips anon. | 4 | Maestro `anon_data_capture.yaml` : « j'ai 34 ans », kill, reopen → `q_birth_year=1992`. |
| 2 | **Opener + 4 chips** | Chat à froid → MINT ouvre la conversation. | same as #1 (system-prompt) | `coach_chat_screen.dart` empty-state | 7 | **N** — spec'd, not gated on `hasSeenPremierEclairage`. | 3 | `coach_opener_first_contact_test.dart` : fresh prefs → opener + 4 chips ; chip-1 → `/document_scan`. |
| 3 | **Premier-Éclairage** Hero Plan | Profil > 33% → 1 chiffre + 1 levier + 1 action. | `POST /fri/compute` + `/coaching/snapshot` | `aujourdhui/`, `premier_eclairage_screen.dart` | 8 (no perso reco) | **Y partiel** — Hero Plan ships (S52, `MASTERPLAN:744`) ; reframing not test-asserted. | 4 | promptfoo `premier_eclairage_no_promise.yaml` : 20 fixtures → 1 num + 1 lever + 1 action + 0 banned. |
| 4 | **Doc scan → extract** | Photo paie/LPP → extraction + 2 implications. | `POST /documents/parse` | `document_scan/`, `scan_review_screen.dart`, `scan_impact_screen.dart` | 7 ; `MINT_IDENTITY:84` | **Y partiel** — endpoint+screens ship ; walker not run E2E. | 4 | Maestro `scan_lpp_certificate.yaml` : Scan → LPP fixture → `q_lpp_avoir_chf` saved + Hero Plan recompute. |
| 5 | **Budget 7-form** | Poser charges = 7 cases en 2 min. | `POST /budget/setup` | `budget/budget_setup_screen.dart` | 7 | **Y** — `MVP-PLAN:179`. | 2 | pytest `test_budget_setup_persists_seven_fields.py` + Maestro `budget_setup.yaml`. |
| 6 | **Cap + ActionSuccess** | Action terminée → delta + prochain Cap. | `POST /coaching/cap` (heuristic) | `aujourdhui/cap_card.dart`, `action_success_sheet.dart` | 8 (no promise) | **Y** — `MASTERPLAN:172-174`. | 3 | `cap_recompute_after_action_test.dart` : completed → next cap differs + impact rendered. |
| 7 | **Confidence (4-axis)** | Projection → score 0-100 + incertitude + amélioration. | `POST /confidence/compute` | `confidence_dashboard_screen.dart`, Hero Plan footers | `SOT.md:111` | **Y partiel** — ships (`SOT.md:82-92`) ; surfacing not asserted. | 3 | `confidence_band_renders_when_low.dart` : `combined=45` → band on `retirement_dashboard_screen.dart`. |

**Total validate-budget : 23h** (~3 days). Anything beyond = kill list (§6).

---

## 3. The 3 dimensions where MINT must beat VZ

VZ ([vermoegenszentrum.ch](https://www.vermoegenszentrum.ch)) baseline : *« télécharge le PDF, prends rdv, attends 2 semaines, paie 250 CHF/h »*.

| Dimension | MINT bar | VZ baseline |
|---|---|---|
| **Speed** | First lucid output ≤ 60s app-open. Hero Plan ≤ 4s. | « rdv personnalisé, devis sur demande ». |
| **Personalization** | 8 archetypes (`coach_profile.dart:1784`) wired into every projection (`fri_computation_service.dart:216` FATCA path). | Generic Swiss-resident default ; FATCA/frontalier are advisory add-ons. |
| **Trust** | LSFin disclaimer landing (`landing_screen.dart:166`), confidence visible every projection, banned-term lint blocking CI. | FINMA-licensed advisor signature (paper, slow). |

**Acceptance bars** : (Speed) `lighthouse-mobile.json` TTFP < 4s on staging build ; (Perso) `archetype_coverage_test.dart` asserts 8 archetypes use distinct FRI formula path ; (Trust) `banned_terms_arb.py` blocking in `ci.yml` + every Hero Plan renders an `EnhancedConfidence` component (`golden_test_hero_plan_confidence.dart`).

---

## 4. The 3 things that make Cleo « vivant », which MINT can copy structurally

Cleo's living-system feel : [meetcleo.com](https://meetcleo.com) + analysis `MASTERPLAN:119-130`.

| Cleo trait | MINT current | Decision |
|---|---|---|
| **Proactive opener** | 7 triggers + orchestrator ship ; empty-state of `coach_chat_screen.dart` doesn't call them. | Wire as Feature #2, gated `hasSeenPremierEclairage`. |
| **Persona / roast** = system-prompt contract | Chips ship (`:2346`), log at `:898` ; no test asserts LLM shifts. | Keep chips, add 1 widget test on `coach_llm_service` branch. No new UI. |
| **Memory / continuity** | `ConversationMemoryService` persists (`:69`) ; recall = keyword, not vector. | Ship as-is : keyword enough for J+1 opener. Vector = post-MVP (`MASTERPLAN:188`). |

---

## 5. The 1 thing that makes MINT structurally better

**11 Top-10-Suisse situations** (`MASTERPLAN:90-102`) × **`financial_core` SOT** (16 calculators) × **LSFin discipline** (banned-term lint, FATCA gating, no-promise per FINMA Rapport 2024/2025 art. 8 al. 6 [finma.ch](https://www.finma.ch)) = a moat neither Cleo (US/UK consumer, no Swiss) nor VZ (Swiss but paper-only) matches in 6 months.

**UX claim** : *« MINT est le seul produit qui te dit, en moins de 60 secondes et sans rendez-vous, ce que ton certificat LPP implique pour toi en tant que [frontalier / expat US / indépendant], avec la projection chiffrée et l'incertitude visible. »*

---

## 6. Kill-list (cut from MVP)

- Niveau 3 canvas (`decisions/2026-05-04-...:14-16`) — highest-value UX, NOT a TestFlight blocker.
- RAG v2 vector (`MASTERPLAN:188`) ; 13e rente AVS (`:189`) ; STT/TTS real (`:190`) ; Expert tier (`:191`, Phase 7) ; Agent autonome form pre-fill (`:192`, Phase 68).
- BYOK QA (`feedback_byok_scope.md`) — out-of-scope per Julien.
- Audit UI « mes faits captés » (`MVP-PLAN:213`, P2) ; send-button 44×44 (`MVP-FLOW:104`, P1) ; tonality chips → Settings (`MVP-PLAN:113`, P1).

---

## 7. The 14-day execution plan

- **D1** — run walker `walker_audit_tap_render.sh --no-dry-run --archetype swiss_native --all` vs staging. Publish `AUDIT_TAP_RENDER_RESULTS.md` ; FAIL = 1 ticket each.
- **D2** — Maestro `julien_full_walkthrough.yaml` : landing→opener→5-msg→LPP scan→budget→Hero Plan→kill→reopen→all persisted.
- **D3** — burn top-3 D1 FAILs + close `coach_chat.py:1963` (mirror `save_fact` for anon, dead-since-2026-04-21).
- **D4** — ship Feature #2 (opener + 4 chips) per `MVP-PLAN:115-122`.
- **D5** — wire `ConversationMemoryService` recall into J+1 opener (`MVP-PLAN:94-99`).
- **D6** — persona-tone widget test asserts system-prompt flavor switches.
- **D7** — design panel + walker re-run (`feedback_design_panel_before_push.md`).
- **D8** — flip `banned_terms_arb.py` blocking in `ci.yml` + FATCA-archetype widget test (`decisions/...:70`).
- **D9** — assert `EnhancedConfidence` band on every Hero Plan ; close §2 #7.
- **D10** — LSFin pre-Premier-Éclairage disclosure modal (FINMA art. 8 al. 6).
- **D11** — `evals/premier_eclairage_no_promise.yaml` (20 fixtures, banned + structure). promptfoo advisory in `ci.yml`.
- **D12** — Schemathesis vs staging OpenAPI ; fix drift.
- **D13** — pubspec 2.9.0+1 → 2.10.0+1, staging push, `testflight.yml` fires. Invite 5 NDA testers.
- **D14** — 24h soak. Triage. Cut 2.10.0 (or 2.10.1 if critical).

---

## 8. « If I were Julien » Monday

> `cd /Users/julienbattaglia/Desktop/MINT.nosync && git checkout dev && git pull --rebase && bash tools/walker/walker_audit_tap_render.sh --no-dry-run --archetype swiss_native --all > .planning/phases/54-testflight-gate-closure/triage/AUDIT_TAP_RENDER_RESULTS_$(date +%F).md 2>&1 && open .planning/phases/54-testflight-gate-closure/triage/`

Single line unblocks Plan 54-03, closes GATE-01, produces journalist-test evidence.

---

## TL;DR — if Julien reads only this paragraph

The MVP is alive when 7 features work end-to-end on a fresh-install device : (1) anon chat that *actually* remembers, (2) coach opener + 4 chips, (3) Premier-Éclairage Hero Plan, (4) doc-scan → fact extraction, (5) budget 7-fields form, (6) Cap-du-jour + ActionSuccess loop, (7) 4-axis confidence visible. Six are partially shipped ; the only true blocker is the `save_fact` anon-session dead-code path (`coach_chat.py:1963-1966`). The walker has shipped but never run — running it Monday morning is the literal critical path to TestFlight. The kill-list cuts Niveau-3 canvas, vector RAG, voice, expert tier, agent autonome — not because they don't matter but because they don't unblock the journalist-defensible TestFlight that closes this 5-month chapter.

---

## External citations

- Cleo « living system » UX : [meetcleo.com](https://meetcleo.com) + `MASTERPLAN:119-130`.
- VZ paper-heavy advisory : [vermoegenszentrum.ch](https://www.vermoegenszentrum.ch).
- FINMA Rapport 2024/2025 + LSFin art. 8 al. 6 : [finma.ch](https://www.finma.ch) ; cf. `MINT_IDENTITY:165`.

## File:line index (audit)

- `coach_chat.py:1963-1966` (filter strips `save_fact` for anon — broken) ; `:1182` (`save_fact` in `INTERNAL_TOOL_NAMES`).
- `coach_chat_screen.dart:1301` (regex fallback) ; `:2340-2400` (tone chips) ; `:898` (tone log).
- `fact_extraction_fallback.dart:38` ; `landing_screen.dart:166` (LSFin) ; `coach_profile.dart:1784` (8 archetypes) ; `fri_computation_service.dart:216` (FATCA path).
- `MASTERPLAN:90-102` (Top-10-Suisse) / `:144-158` (boucle) / `:172-179` (CapEngine etc.) / `:188-192` (deferred).
- `SOT.md:82-92` (EnhancedConfidence) / `:111` (Confidence Gate). `MINT_IDENTITY:84-95` (4-couche).
- `MVP-PLAN-2026-04-21.md:13-23` (save_fact post-mortem) / `:75-122` (opener spec) / `:179-185` (budget spec). `MVP-FLOW:200-211` (blocker matrix). `decisions/2026-05-04-post-handoff2-sweep-panel.md:14-91`.
- Shipped commits : `76178a7f`, `0426e914`, `83529a6b`, `cacdcf1f`, `131b1a10` ; dead-code commit `2360e3d3`.
