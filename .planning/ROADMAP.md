# Roadmap: MINT

## Milestones

- ✅ **v1.0 MVP** — Phases 1-8 (shipped 2026-03-20)
- ✅ **v2.0 Systeme Vivant** — Phases 1-6 (shipped 2026-04-07)
- ✅ **v2.1 Stabilisation** — Phase 7 (shipped 2026-04-07)
- ✅ **v2.4 Fondation** — Phases 9-12 (shipped 2026-04-12)
- ✅ **v2.5 Transformation** — Phases 13-18 (shipped 2026-04-13)
- ✅ **v2.6 Le Coach Qui Marche** — Phases 19-26 (shipped 2026-04-13)
- 🟡 **v2.7 Coach Stabilisation + Document Digestion** — Phases 27-30 (code-complete, awaiting device gate)
- 🔵 **v2.8 L'Oracle & La Boucle** — Phases 30.5, 30.6, 30.7, 31-36 (shipped with gaps 2026-04-25)
- 🌱 **v2.9 Chat Vivant** — planted 2026-04-19, deferred (re-deferred again at v2.12 gate)
- 🟢 **v2.10 / v2.11** — wiring milestones (PRs #470-#496 merged)
- 🟡 **v2.12 Production-Ready Sim Validation** — opened 2026-05-05, in flight (Phase 86 julien_swiss GREEN, Phase 87 SHIPPED, 88-89 pending)
- 🌱 **v2.13 Persona Narrative Scenario Coverage** — planted 2026-05-05, panel-locked

<details>
<summary>Previous milestones (v1.0 → v2.7) — see MILESTONES.md + collapsed v2.5-v2.7 detail below</summary>

Full phase detail for v2.5 (Phases 13-18), v2.6 (Phases 19-26), v2.7 (Phases 27-30) preserved in git history of this file (pre-2026-04-19 revisions) + `.planning/MILESTONES.md`.

</details>

---

## v2.8 L'Oracle & La Boucle — SHIPPED 2026-04-25 (with gaps)

<details>
<summary>v2.8 phase detail (collapsed — full archive in milestones/v2.8-ROADMAP.md)</summary>

5 phases shipped + 13 decimal patches :
- 30.5 Context Sanity Core ✓ · 30.6 Context Sanity Advanced ✓ · 30.7 Tools Déterministes ✓ · 31 Instrumenter ✓ · 32 Cartographier ✓
- 30.8-30.20 : tactical fixes (LAND-01, FIX-02, anonymous CTA, error mapping, accent_lint exclusions, doc extraction uplift…)

Phases unshipped (carried forward to v2.9) :
- 33 Kill-switches (4 P0 flags)
- 34 Guardrails — workflow design failed, lessons learned
- 35 Boucle Daily — automation, defer
- 36 Finissage E2E — spirit absorbed into v2.9 « Coach Visuel Hybride »

Full audit: [milestones/v2.8-MILESTONE-AUDIT.md](milestones/v2.8-MILESTONE-AUDIT.md) · 28/48 reqs · 5/9 phases.

</details>

---

## v2.9 Coach Visuel Hybride — Overview (deferred again at v2.12 gate)

**Goal:** Verticale « Onboarding-to-First-Insight » : un user qui arrive sur MINT a, en moins de 20 min, son profil financier sur les 6 axes suisses + un hero number actionnable + un coach qui balance vignettes / scènes / canvas pour explorer les arbitrages.

**Status (2026-05-05) :** Re-deferred. v2.12 sim-validation + v2.13 persona-narrative coverage take precedence. v2.9 phases 40-43 remain as backlog.

---

## v2.12 — Production-Ready Sim Validation (opened 2026-05-05, in flight)

**Goal :** Aucun TestFlight tant que Claude n'a pas validé que l'app tourne PARFAITEMENT sur simulator. Walker = machine de vérité ; Julien fait zéro test. STAMP-08 PASS = autorisation tag.

**Critère de done :** `.planning/phases/89-stamp/STAMP-PASS-<date>.html` avec 7/7 quality gates green.

**4 phases sequential, ~9d effort :**

| # | Phase | REQs | Effort | Status |
|---|---|---|---|---|
| 86 | Walker green réel 4 archetypes (FR) | SIMQ-01..08 (8) | 3.0d | julien_swiss GREEN (8d3c127a) ; 3 archetypes pending |
| 87 | Bare-catches sweep Wave 1 (15 paths) | OBSV-01..08 (8) | 2.0d | SHIPPED (PR #498) |
| 88 | Cross-language 12 walks FR+DE+EN | XLOC-01..08 (8) | 2.0d | Pending |
| 89 | Quality stamp 7-gate (LAST gate) | STAMP-01..08 (8) | 2.0d | Pending |

**Critical path :** 86 → 87 → 88 → 89. NO parallelization. Sequential merges to dev.

**Coverage :** 32/32 REQs mapped (100%). Voir `.planning/REQUIREMENTS.md` v2.12 traceability.

---

## v2.13 — Persona Narrative Scenario Coverage (opened 2026-05-05, panel-locked)

**Goal :** Bâtir la couche de validation narrative au-dessus de v2.12 — un suite de scripts persona-driven exécutés nightly sur simulator, avec assertions sémantiques (Sentry breadcrumbs + LSFin regex + financial_core numeric) plutôt que pixel-SHA. KPI = pass rate, pas screenshot-distinct.

**Critère de done (TestFlight ship gate) :** `.planning/phases/92-journalist-defense/SHIP-GATE-<date>.html` avec 5 journalist-defense scripts pass for 5 consecutive nights AND walker green (carry-forward v2.12) AND `flutter analyze` clean AND `pytest -q` clean.

**Doctrine v2.13 (panel-locked 6-pers, 2026-05-05) :**
1. Single-persona narrative > multi-archetype matrix (Phase 51 + 74 postmortem evidence)
2. Cap initialement 2 personas × 1 scenario × 5 phases = 10 cellules ; grandir uniquement après 5 nuits nightly-green consécutives
3. LLM mocked via replay-cache ; ANTHROPIC_API_KEY ne gate jamais un script
4. Maestro YAML pour choreography + walker.sh pour build/seed/Sentry + Dart assertions post-run
5. NO walker overhaul phase ; coord drift = locator-layer fix
6. NO « delegated_via_substitute » markdown ; pass ou fail, pas de troisième état

**Architecture 3-layer :**
- L0 walker_premier_eclairage.sh (existing, KEPT)
- L1 Maestro YAML flows `tools/simulator/flows/<persona>.yaml`
- L2 Dart assertions `tools/simulator/assertions/<persona>.dart`

**4 phases sequential, ~13d effort :**

| # | Phase | REQs | Effort | Pre-req |
|---|---|---|---|---|
| 90 | 2 personas × 1 scenario × 5 phases (10 cells) + tooling adoption | PERS-01..08 (8) | 4.0d | v2.12 STAMP-PASS |
| 91 | 8 archetypes × canonical scenario each | ARCH-01..08 (8) | 3.0d | Phase 90 nightly-green 5 nuits |
| 92 | 5 journalist-defense scripts (= ship gate) | JDEF-01..08 (8) | 2.0d | Phase 91 closed |
| 93 | Croissance vers 50 par matrice swiss-financial | GROW-01..08 (8) | 4.0d | Phase 92 SHIP-GATE PASS |

**Critical path :** 90 → 91 → 92 → 93. NO parallelization. Sequential merges to dev.

**5 journalist-defense scripts (Phase 92 ship gate) :**
1. **Sofia** (`independent_no_lpp`, blocker) — découvre son trou de prévoyance. Empathy register, no shame.
2. **Lauren** (`expat_us`, blocker) — « c'est garanti combien ? ». Banned-term gate fires. Reframe-en-scénarios.
3. **Anna** (deuil, blocker) — décès partenaire à 23h. Apaisé tone, no upsell.
4. **Jennifer** (`expat_us` + 3a, blocker) — peut-elle ouvrir un 3a ? FATCA gate, no recommendation.
5. **Pierre** (`late_career`, happy) — rente vs capital LPP. No ranking, irreversibility disclosure.

**Quality gates v2.13 (Phase 92 ship-gate) :**
1. 5 journalist-defense scripts pass for 5 consecutive nights
2. Walker green 12 walks (carry-forward v2.12 STAMP-01)
3. `flutter analyze` clean + `pytest -q` green
4. LSFin regex library: 0 banned-term hits across all 13+ scripts
5. Per-script: ≥1 narrative invariant + ≥1 numeric assertion + ≥1 LSFin assertion + ≥1 archetype assertion
6. Suite-level flake budget : ≤3% per script, auto-retry once, quarantine after 3 consecutive flakes
7. Locator audit lint exits 0

**Tooling adoption (Phase 90) :**
- Maestro CLI install (`brew install maestro`) + idb verify
- `walker.sh --maestro-flow` shell-out
- LLM replay-cache (`tools/simulator/cache/replay/`) — record/replay modes
- R2 bucket `mint-goldens/` provisioned
- `tools/checks/maestro_locator_audit.py` blocking lint

**Coverage :** 32/32 REQs mapped (100%). Voir `.planning/REQUIREMENTS.md` v2.13 traceability (PERS-* / ARCH-* / JDEF-* / GROW-*).

**Hard scope guards (anti-Phase-51 trap) :**
1. NO new persona before all current are nightly-green for 5 nights.
2. NO life-events × archetypes matrix expansion before 10 cells stable.
3. ANY backend dependency MUST have a recorded-fixture mock.
4. NO « walker overhaul » phase. Coord drift = locator-layer fix.
5. NO « delegated_via_substitute » markdown.
6. Each phase has HARD STOP at scope cap.

**Pré-requis :** v2.12 STAMP-08 PASS (Phase 89), c'est-à-dire 12 walks green + 7 mechanical gates green.

**Sources :**
- `.planning/decisions/2026-05-05-persona-narrative-scenario-coverage-panel.md`
- `.planning/deep-audit-2026-04-17/02-persona-journeys.md`
- `.planning/walker/` (36 run dirs Phase 51 corpse)
- `.planning/wave-0-walkthrough-verite/PLAN.md`

**Out of scope (deferred to v2.14+) :** Patrol migration, live-LLM nightly suite, Wave 2 bare-catches, couple mode wiring, iPhone SE / iPad viewports, banking + LPP API, Wiki coach v3, 6-lang persona scripts.

---
*Updated 2026-05-05 — v2.12 in flight (Phase 86 julien_swiss GREEN, 87 shipped) ; v2.13 opened, panel-locked 6-pers.*
