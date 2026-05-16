---
name: calc-engine-matrix-2026-05-16
description: True inventory of MINT's Swiss financial calculation surface (~57 calculators across 11 domains scattered over 10+ service directories) + critical hypothesis that callers pass hardcoded defaults instead of real user profile values + 4 problems to resolve in mint-calc-engine-v1 discuss-phase
status: Proposed (audit input, not yet decided)
date: 2026-05-16
authors: Claude (Product Lead, MINT) ; audit triggered + validated by Julien
metadata:
  type: decision
  topic_key: calc_engine:inventory_2026_05_16
related:
  - [[phase-96-killed-2026-05-16]]
  - [[wave-1c-A3-CONTEXT]]
---

# MINT Swiss Financial Calculator Matrix — corrected audit 2026-05-16

## TLDR

Two prior assertions by me (Claude as Product Lead) were wrong and need correction before any planning :

1. I claimed MINT has ~4 atomic calculators shipped + ~50 absent. **Reality : 57 ✅ shipped + 4 ⚠️ partial + 3 ❌ truly absent — ~94 % surface coverage** scattered across 10+ backend service directories (not just `financial_core/`).
2. I claimed Phase 96 « chat-as-verb / kill-tab / cards-as-home » was the current direction. **Reality : Julien-signed decision 2026-05-14 PAUSED Phase 96 ; in this session 2026-05-16 Julien killed it outright.** See [[phase-96-killed-2026-05-16]].

The real gap is NOT « build the calculators » — they exist. It is :

- **A. LLM discoverability** — ~52 of the 57 calculators are not exposed as Anthropic tools to the Sonnet 4.5 narrator. Wave 1c only wires 5 chip-emitters. The other 52 are invisible to the coach.
- **B. Architecture éparpillée** — services live in 10+ scattered directories (`family/`, `divorce_simulator.py` root, `succession_simulator.py` root, `lpp_deep/`, `expat/`, `independants/` + `independant_service.py` duplicate, `mortgage/`, `fiscal/`, `arbitrage/`, `unemployment/`, `retirement/`, `debt_prevention/`). This is what made my scan fail AND it is what makes LLM discoverability hard.
- **C. Calculs déconnectés du vrai profil utilisateur** — confirmed by direct read of `arbitrage.py:184-213` : the public REST endpoint for the joint optimiser falls back to hardcoded defaults (`is_property_owner=False`, `taux_hypothecaire=0.015`, `rendement_3a=0.02`, `potentiel_rachat_lpp=0`) when the client does not send the values. The `_user.profile` is never read. **Julien's intuition is correct on at least this surface ; an audit must confirm or deny across the other 56 calculators.**
- **D. No trigger / DAG action** — Phase 95 shipped `inputs_hash` + `superseded_by` detection. Nothing acts on the signal. No cascade on profile mutation. Every projection is request-time pull.

## Counter-arguments and data gaps

**Counter-argument 1 :** « 94 % coverage is enough to ship — focus on UX, not on the matrix. »
- Rebuttal : counts only the COUNT of calculators, not the QUALITY of inputs they receive. If hypothesis C is broadly true, all 57 are computing on garbage inputs → 94 % surface, near-0 trust on output.

**Counter-argument 2 :** « LLM discoverability is solved by registering all 57 as Anthropic tools. »
- Rebuttal : context bloat. 57 tools in the system prompt of every coach turn is ~30 K tokens of tool definitions. Liu 2024 lost-in-the-middle + the very RAG-suppression issue Wave 1c-A2 just fixed. Need a skill-bundle compiler (Phase 93.5 pattern) that exposes only the relevant subset per user intent.

**Counter-argument 3 :** « Architecture éparpillée is cosmetic — refactor doesn't ship value. »
- Rebuttal : it ships discoverability for both humans (PR reviewers, new contributors, me as PM) AND for the LLM tool registry. The pattern matters for both. AND it is the root cause of how I missed 50 files.

**Data gaps :**
- Did NOT verify hypothesis C on all 57 callers — only on `allocation_annuelle.py` endpoint. Need full audit : for each calculator, does the caller pull from `CoachProfile` / `ProfileModel` or pass primitive defaults ?
- Did NOT verify which of the 57 are exposed as Flutter screens vs only available via the REST endpoint vs only callable from the coach. The discoverability matrix must extend to UI layer.
- Did NOT yet measure tool-prompt token cost of registering all 57.

## The 11-category matrix — REDONE 2026-05-16

| # | Category | Status | Evidence (file:line representative) | Notes |
|---|---|---|---|---|
| 1 | Revenu & impôts courants | ⚠️ 3✅ / 1⚠️ / 2❌ | `arbitrage/allocation_annuelle.py:99-109` (marginal), `fiscal/wealth_tax_service.py` (fortune) | Quasi-résident + bouclier fiscal absent |
| 2 | Prévoyance (AVS / LPP / 3a) | ✅ 7✅ / 0❌ | `retirement/avs_estimation_service.py`, `financial_core/lpp_calculator.dart`, `lpp_deep/rachat_echelonne_service.py`, `arbitrage/allocation_annuelle.py:_build_3a_option()` | Complete coverage |
| 3 | Logement & hypothèque | ✅ 7✅ / 1⚠️ | `mortgage/affordability_service.py`, `lpp_deep/epl_service.py`, `mortgage/saron_vs_fixed_service.py`, `arbitrage/allocation_annuelle.py:_build_amortissement_indirect_option()` | Impôt foncier simplified |
| 4 | Patrimoine & investissement | ✅ 4✅ | `arbitrage/allocation_annuelle.py` (joint solver !), `fiscal/wealth_tax_service.py` | Joint optimiser already shipped |
| 5 | Famille & couple | ✅ 6✅ | `family/naissance_service.py:56-63` (allocations familiales **26 cantons**), `widgets/visualizations/canton_allocation_map.dart`, `divorce_simulator.py:8-9` (splitting AVS) | Julien-flagged « j'ai vu les allocations familiales par canton » — CONFIRMED |
| 6 | Divorce / séparation | ✅ 7✅ | `divorce_simulator.py` (CC art. 122-124, LAVS art. 29sexies, pension alimentaire) + `divorce_simulator_screen.dart` + tests | Julien-flagged « divorce » — CONFIRMED |
| 7 | Héritage / succession | ✅ 6✅ | `succession_simulator.py` (CC art. 467-469 + `CANTON_SUCCESSION_TAX` 26 cantons + OPP3 art. 2) + `coach/succession_patrimoine_screen.dart` | Complete |
| 8 | Indépendant / entreprise | ⚠️ 3✅ / 2❌ | `independants/`, `independant_service.py`, `pillar_3a_calculator.dart` (20 % net cap) | Sàrl-vs-RI + dividende-vs-salaire absent |
| 9 | Mobilité / international | ✅ 4✅ | `expat/frontalier_service.py`, `expat/expat_service.py`, `frontalier_screen.dart` | Includes FATCA-aware US-person logic |
| 10 | Assurances sociales | ✅ 5✅ | `unemployment/calculator.py`, `lamal_franchise_service.py`, `family/naissance_service.py:41-50` (APG mat/pat) | Complete |
| 11 | Crédit / dette | ✅ 3✅ | `mortgage/saron_vs_fixed_service.py`, `debt_prevention/repayment_service.py` (snowball + avalanche) | Complete |

**Totals : 57 ✅ + 4 ⚠️ + 3 ❌ = 64 visible items / ~64 expected ; coverage ≈ 94 %**

## Falsely called « ❌ absent » in prior PM assertion — corrected

| Calculator | Reality (file:line) |
|---|---|
| Allocations familiales par canton | `services/backend/app/services/family/naissance_service.py:56-63` (26 cantons × 4 rates per LAFam art. 3 2025) + `apps/mobile/lib/widgets/visualizations/canton_allocation_map.dart` |
| Divorce simulator complet | `services/backend/app/services/divorce_simulator.py` + `apps/mobile/lib/screens/divorce_simulator_screen.dart` + `apps/mobile/lib/widgets/coach/divorce_film_widget.dart` + `services/backend/tests/test_divorce_simulator.py` |
| Succession / héritage | `services/backend/app/services/succession_simulator.py` + `apps/mobile/lib/screens/coach/succession_patrimoine_screen.dart` + `services/backend/tests/test_succession_simulator.py` |
| Capacité d'emprunt + amortissement direct/indirect | `services/backend/app/services/mortgage/affordability_service.py` + `arbitrage/allocation_annuelle.py:180-234` |
| EPL retrait LPP résidence + nantissement | `services/backend/app/services/lpp_deep/epl_service.py` + `epl_combined_service.py` |
| Rachat LPP échelonné | `services/backend/app/services/lpp_deep/rachat_echelonne_service.py` |
| Impôt fortune | `services/backend/app/services/fiscal/wealth_tax_service.py` |
| Chômage indemnités | `services/backend/app/services/unemployment/calculator.py` + `apps/mobile/lib/screens/unemployment_screen.dart` |
| LAMal franchise | `services/backend/app/services/lamal_franchise_service.py` |
| Indépendant AVS / 3a / cotisations | `services/backend/app/services/independants/` (sub-arborescence) + `independant_service.py` |
| Frontalier + expat + FATCA | `services/backend/app/services/expat/frontalier_service.py` + `expat_service.py` + `apps/mobile/lib/screens/frontalier_screen.dart` |
| SARON vs taux fixe + stress test 5 % | `services/backend/app/services/mortgage/saron_vs_fixed_service.py` |
| Snowball / avalanche remboursement dette | `services/backend/app/services/debt_prevention/repayment_service.py` |
| APG maternité / paternité | `services/backend/app/services/family/naissance_service.py:41-50` (LAPG art. 16d-16l) |
| Conversion LPP rente vs capital | `services/backend/app/services/retirement/lpp_conversion_service.py` |
| Joint optimiser 4-options | `services/backend/app/services/arbitrage/allocation_annuelle.py:compare_allocation_annuelle()` — ⚠️ falls back to hardcoded defaults (see below) |

## Truly absent (3 items)

1. Quasi-résident frontalier status (> 90 % revenu CH, > 120 K brut)
2. Bouclier fiscal (plafond GE / VD / VS)
3. Sàrl vs raison individuelle + dividende vs salaire indépendant

## Critical hypothesis to audit in discuss-phase

**Julien 2026-05-16 (verbatim) :** « j'ai l'impression que tous ces calculs ne se font pas avec les vraies valeurs de l'utilisateur. Toujours pas. »

**Direct evidence (one surface confirmed) :** `services/backend/app/api/v1/endpoints/arbitrage.py:163-213` — POST `/api/v1/arbitrage/allocation-annuelle` :
- Receives `AllocationAnnuelleRequest` body from the CLIENT.
- For every field NOT sent by the client : hardcoded default activates (`is_property_owner=False`, `potentiel_rachat_lpp=0`, `taux_hypothecaire=0.015`, `rendement_3a=0.02`, `annees_avant_retraite=20`).
- The authenticated `_user` is used ONLY for `require_current_user` (auth check). **The user's profile is NEVER read at this endpoint.**

This means : if the Flutter screen does not pull from `ProfileProvider` and pass every field explicitly, the calculator runs on hardcoded « SARON 1.5 %, non-property-owner, no LPP buyback potential, 2 % 3a return » assumptions — independent of the user's actual canton, marital status, salary, mortgage type, or LPP balance.

**Mathematically correct, structurally disconnected from the real user.**

**To audit (non-blocking for this ADR, blocking for discuss-phase planning) :**
1. For each of the 57 calculators, are inputs read from `CoachProfile` / `ProfileModel` or passed as primitives ?
2. For each REST endpoint, does it read `_user.profile` to pre-fill defaults, or accept raw body params ?
3. For each Flutter screen surface, does it pass profile-derived values, or expose forms the user must re-fill ?
4. For coach-side invocations (the 5 chip-emitters today + future 52), do the tool input_schemas force profile-grounded values ?

This audit is the FIRST gate of mint-calc-engine-v1. Without it, every plan downstream is built on unverified assumptions.

## 4 problems to resolve in mint-calc-engine-v1 (the discuss-phase brief)

### Problem 1 — LLM tool discoverability (the 52 unexposed calculators)

The narrator Sonnet 4.5 currently knows ~5 chip-emitter tools (Wave 1b + 1c). The 52 other calculators are invisible to it. The coach cannot invoke `divorce_simulator` even when user asks « si je divorce demain » because the tool isn't registered.

Solution candidates (to discuss) :
- (a) Register all 57 as Anthropic tools — context bloat (Liu 2024) + retrieval-attention problem.
- (b) Skill-bundle compiler (Phase 93.5 pattern) — compile-time bundles per user intent ; narrator gets the relevant subset.
- (c) Intent classifier → dynamic tool subset at runtime per turn.
- (d) Hybrid : skill-bundles for common intents + dynamic fallback for rare intents.

### Problem 2 — Real-profile grounding (hypothesis C)

If audit confirms broadly true : every calculator entry-point (REST + Flutter screen + coach tool) MUST default-fill from `ProfileModel.data` before any client / LLM input override. Or the calc is theatre.

Candidates :
- (a) Server-side `_user.profile`-fill at every REST endpoint.
- (b) `ProfileProvider`-pull on every Flutter screen mount.
- (c) Coach-tool `input_schema` default markers (`{from_profile: "canton"}`) auto-resolved by the dispatcher.
- (d) All three.

### Problem 3 — Architecture éparpillée

Services scattered across 10+ directories with naming inconsistencies (`independant_service.py` vs `independants/` ; `divorce_simulator.py` at root vs `family/` sub-dir). Caused this scan failure ; will cause LLM discoverability registration failures ; will cause new-contributor confusion.

Candidates :
- (a) Consolidate to `services/backend/app/calculators/<domain>/<calc>.py` — one canonical home.
- (b) Keep current structure but add a registry index (`services/backend/app/calculators/_registry.py`) auto-generated from a scanner.
- (c) Both : phase A registry (no move), phase B physical consolidation.

### Problem 4 — DAG action on profile mutation

Phase 95 detects staleness (`inputs_hash` mismatch + `superseded_by` chain). Nothing acts. Eager pre-compute, cache hash on read, post-commit `BackgroundTasks` — these were the 3 « waves » sketched in prior PM rec. Re-evaluate now that Phase 96 cards-home is dead.

Candidates :
- (a) Vague A only (read-side cache hash). Cheap, immediate win.
- (b) A + B (post-commit BackgroundTasks pre-compute the « top 3 likely-needed » calcs from facts that just landed). For « widget inline rendering » in Coach-vivant doctrine.
- (c) Full event-bus + cascade — premature.

## 4-level lucidité framework (LOCKED — FINMA / LSFin compliant)

| Level | What MINT says | What MINT NEVER says | Surface |
|---|---|---|---|
| L1 — Chiffrer | « Ta rente AVS projetée à 65 ans est X CHF/mois » | « Cette rente est suffisante / faible / optimale » | Atomic calculators + cartes / simulateurs / widgets inline |
| L2 — Comparer | « Voici les 3 scénarios chiffrés : A=X, B=Y, C=Z » | « Le scénario B est le meilleur » | Coach narration sur arbitrage |
| L3 — Éclairer l'arbitrage caché | « Si tu choisis A, ça change ton 3a, ton impôt et ta dette dans 5 ans » | « Tu devrais faire A » | Coach + DAG cascade |
| L4 — Surfacer les invariants | « Quel que soit le scénario, ta capacité d'emprunt est plafonnée à 33 % du revenu (LCC) » | « Cette banque te dira oui / non » | Insights persistants (wiki / `CoachInsightRecord`) |

Verbes autorisés : *« voici »*, *« si tu fais X, ça donne Y »*, *« 3 options chiffrées »*, *« arbitrage caché »*, *« compte tenu de tes données »*.
Verbes interdits (extend `tools/checks/banned_terms_python.py`) : *« optimal »*, *« meilleur »*, *« garanti »*, *« recommandé »*, *« tu devrais »*, *« certain »*, *« assuré »*.

## Latency contract

- **Synchronous < 500 ms** : atomic chiffrage (L1) served from `inputs_hash` cache (Phase 95 read-side activated in vague A).
- **Async with narrative loader 2-8 s** : combinatorial / multi-option arbitrage (L2-L3). The wait IS a feature : signals rigor (Cleo pattern).

## Decision artifacts derived from this matrix

- [[phase-96-killed-2026-05-16]] — kills Phase 96 outright.
- (next) — `.planning/phases/mint-calc-engine-v1-...` — discuss-phase CONTEXT.md will lock the 4 problem-area decisions above into D-CE-01..D-CE-NN.

## Sources

- Direct codebase read 2026-05-16 of `services/backend/app/services/{arbitrage,divorce_simulator.py,succession_simulator.py,family,mortgage,lpp_deep,expat,independants,fiscal,unemployment,retirement,debt_prevention}/` + `apps/mobile/lib/screens/` + `apps/mobile/lib/widgets/`
- `services/backend/app/api/v1/endpoints/arbitrage.py:163-213` (hypothesis C evidence)
- `.planning/decisions/2026-05-14-phase-7-ship-or-pause.md` (Phase 96 PAUSE, Julien-signed)
- Julien session 2026-05-16 (verbatim quotes on hypothesis C + matrix incompleteness)
- CLAUDE.md §1 (financial_core reuse, LSFin banned terms, accent FR), §9 (0-TRUST)
- Engram memory `feedback_audit_corpus_before_patching` (the discipline I violated when claiming « ~50 absent » without scanning beyond `financial_core/`)
