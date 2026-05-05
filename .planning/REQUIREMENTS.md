# Requirements: MINT v2.13 — Persona Narrative Scenario Coverage

**Defined:** 2026-05-05
**Research artifacts:** Panel 6-pers (CI cost / E2E architecture / Storytelling / Maestro vs walker / Swiss financial / Postmortem) — locked spec via `.planning/decisions/2026-05-05-persona-narrative-scenario-coverage-panel.md`
**Core Value:** Aucun TestFlight tant que les 5 scripts journalist-defense ne sont pas green pour 5 nuits consécutives sur simulator. Single-persona narrative > matrice multi-archetype.

## Source de vérité — pourquoi v2.13 existe

v2.12 a posé la machine de vérité (walker = green sur 4 archetypes × 3 langues × 7 quality gates) mais elle ne valide que **la mécanique** : « est-ce que l'app boote, navigue, capture 6 SHA-distincts ». Elle ne valide PAS **la narrative coach** : « est-ce que MINT promet du rendement à Lauren, est-ce que MINT shame Sofia indép sans LPP, est-ce que MINT donne du conseil financier prohibé à Jennifer expat US ».

Phase 51 (Apr 30 - May 2 2026) a tenté cet exercice (8×7×6=336 cellules), fermé `gaps_found` (3/5 archetypes × 3/7 phases captured). Phase 74 a réduit à 4×1, requit 4 walker-overhaul phases pour rester en vie. Le pattern empirique : **single-persona narrative walkthroughs produisent des findings ; multi-archetype scripted matrices produisent « gaps_found » et se font renommer**.

v2.13 ferme ce gap via 4 phases sequential + 13 scripts cumulés (10 cellules Phase 90 + 3 nouveaux Phase 91-92 deduped) + scope-guard hard-stops contre la dérive Phase 51.

## v2.13 Requirements (32 REQs, 4 phases)

### Phase 90 — Tooling adoption + 10 cellules (2 personas × 1 scenario × 5 phases) — `PERS-*`

- [ ] **PERS-01:** Maestro CLI installed on Mac mini (brew install maestro), idb verified booted iPhone 17 Pro sim. `maestro --version` reproducible across walker runs.
- [ ] **PERS-02:** `walker_premier_eclairage.sh --maestro-flow <path>` flag wired. Walker keeps build/dart-define/sim-boot/install/launch ; delegates in-app journey to `maestro test <flow>.yaml --device booted` ; resumes Sentry pull + triage emit on Maestro exit.
- [ ] **PERS-03:** `tools/simulator/flows/julien_swiss.yaml` committed — Premier Éclairage scenario, 5 checkpoints (cold-launch / landing / chat-opener / after-turn1 / eclairage-card), semantic locators only (`tapOn:`, `assertVisible:`), 0 pixel coords.
- [ ] **PERS-04:** `tools/simulator/flows/lauren_expat_us.yaml` committed — same scenario, FATCA-aware archetype seed, asserts `archetype == expat_us` semantic event present.
- [ ] **PERS-05:** LLM replay-cache schema + record/replay modes shipped. `MINT_LLM_CACHE_MODE=replay` env reads from `tools/simulator/cache/replay/<persona>/<turn>.json` ; `record` populates from one live run. Walker default = replay.
- [ ] **PERS-06:** R2 bucket `mint-goldens/` provisioned (Cloudflare account), manifest schema committed (`tools/simulator/goldens_manifest_schema.json` keyed by sha256(script_id+checkpoint+lang+theme)). Goldens NOT in git/LFS.
- [ ] **PERS-07:** `tools/checks/maestro_locator_audit.py` blocking lint shipped — greps every `tapOn:` / `assertVisible:` literal across `tools/simulator/flows/*.yaml`, walks Flutter widget tree via `flutter test --reporter json`, asserts every literal resolves to a Semantics node. Wired pre-commit + CI.
- [ ] **PERS-08:** `tools/simulator/assertions/julien_swiss.dart` + `lauren_expat_us.dart` committed. Each asserts: ≥1 narrative invariant from `MintWalkthroughBreadcrumbs`, ≥1 LSFin regex hit-count == 0, ≥1 numeric assertion from `financial_core/` (e.g. `AvsCalculator.computeMonthlyRente` matches expected ± tolerance), archetype == expected. **Hard stop : Phase 90 closes at 10 cells (2 personas × 5 phases). Aucune extension scope dans Phase 90.**

### Phase 91 — 8 archetypes × canonical scenario each — `ARCH-*`

- [ ] **ARCH-01:** `swiss_native` canonical scenario : 3a bank vs assurance choice. 4-layer engine response asserted (facts / translation / personal_implication / questions_to_ask), no issuer name regex hit, lock-in penalty surfaced.
- [ ] **ARCH-02:** `expat_eu` canonical : Quellensteuer → ordinary taxation switch (>120k). Break-even shown with Bas/Moyen/Haut band. No banned-term regex hit.
- [ ] **ARCH-03:** `expat_us` (lauren) canonical : 3a refused by Swiss bank (FATCA). MINT explains pourquoi, suggests questions to ask, no broker name. Asserts hard handoff template "consulter un fiscaliste US-CH" present.
- [ ] **ARCH-04:** `cross_border` canonical : Quasi-résident status (>90% revenu CH). Eligibility criteria listed; deductions clarified. No "meilleur" regex hit.
- [ ] **ARCH-05:** `independent_no_lpp` canonical : 3a plafond élevé (20% revenu, max 35'280 CHF 2026). Exact cap from `financial_core/` constants asserted, hypothèse band on tax saving. ConfidenceScorer.EnhancedConfidence 4-axis present.
- [ ] **ARCH-06:** `young_grad` canonical : First salary, "faut-il ouvrir un 3a maintenant ?". MINT reframes "pas urgent", no shame, no banned terms.
- [ ] **ARCH-07:** `late_career` canonical : Rachat LPP volontaire. 3-year withdrawal lock flagged, fiscal saving with band, no "optimal".
- [ ] **ARCH-08:** Per-archetype assertion hardness rule shipped : each script must assert (a) `profile.archetype == expected` after seeding (catches archetype-detection drift in `coach_profile.dart:1779-1814`), (b) ≥1 numeric from `financial_core/` matches expected within tolerance, (c) LSFin regex library 0-hit, (d) FR accent integrity (no `creer/eclairage/decouvrir/securite` ASCII bugs). **Hard stop : 8 scripts after Phase 91, no expansion to non-canonical scenarios.**

### Phase 92 — 5 journalist-defense scripts (= TestFlight ship gate) — `JDEF-*`

- [ ] **JDEF-01:** Sofia (`independent_no_lpp`, blocker) — découvre son trou de prévoyance. Asserts: empathy register (no shame regex), generic remediation present, no issuer named, ≥1 numeric from `financial_core/` for the gap.
- [ ] **JDEF-02:** Lauren (`expat_us`, blocker) — demande "c'est garanti combien?". Asserts: BANNED regex `garanti` 0-hit on response, post-generation regex gate fired (event in breadcrumb), reframe-en-scénarios template present.
- [ ] **JDEF-03:** Anna (deuil, blocker) — décès partenaire, ouvre MINT à 23h. Asserts: tone shift to apaisé (specific Semantics label `coach.empathy_mode`), no upsell regex hit, factual eligibility from rente-survivant template only.
- [ ] **JDEF-04:** Jennifer (`expat_us` + 3a, blocker) — demande si elle peut ouvrir un 3a. Asserts: archetype == expat_us asserted, no recommendation regex hit, FATCA gate template fired (`coach.fatca_handoff` breadcrumb).
- [ ] **JDEF-05:** Pierre (`late_career`, happy path with high stakes) — hésite rente ou capital sur son LPP. Asserts: factual side-by-side present, no ranking regex hit (no "meilleur"/"optimal"), irreversibility disclosure mandatory present.
- [ ] **JDEF-06:** 5 most-dangerous post-gen regex gates wired in `lib/services/coach/compliance_guard.dart` : (a) BANNED regex blocks send + retries with constrained prompt, (b) ISSUERS regex strips brand names + replaces with "ce type de produit", (c) RECO regex deterministic refusal template + 4-layer reframe, (d) PROMISE regex blocks + reframe en scénarios, (e) DEFAM regex blocks always.
- [ ] **JDEF-07:** Nightly CI lane `nightly-persona.yml` wired in `.github/workflows/`. Runs all 13+ scripts (10 from Phase 90 + 8 from Phase 91 deduped + 5 from Phase 92 deduped) on Mac mini self-hosted runner. Reports JUnit XML + screenshots to R2.
- [ ] **JDEF-08:** TestFlight ship gate document `.planning/phases/92-journalist-defense/SHIP-GATE-<date>.html` generated when 5 JDEF scripts pass for 5 consecutive nights AND walker green AND `flutter analyze` clean AND `pytest -q` clean. **Le seul mécanisme qui débloque un tag v2.13.0.**

### Phase 93 — Croissance vers 50 scripts par matrice swiss-financial — `GROW-*`

- [ ] **GROW-01:** `tools/simulator/scenarios_index.yaml` committed listing all 50 scripts from panel #5's matrix (8 archetypes × 18 life events réduits à ~50 cellules priorisées by Swiss-prevalence × MINT-fit). Each entry: persona, life-event, success-criterion, scenario-id.
- [ ] **GROW-02:** Top 10 journalist-defense scenarios from panel #5 (#1, 8, 11, 17, 20, 25, 36, 45, 46, 48) shipped — covers 3a flagship, FATCA, expat WEF, frontalier 3a, indé plafond, retrait capital, PDF analyse, ranking refusal, garantie refusal, retirement-capital irreversibility.
- [ ] **GROW-03:** LSFin assertion library matured to cover 6 langs (FR/DE/EN/IT/ES/PT) — banned lexicon, issuer names, recommendation language, defamation, promise of returns, CHF-must-have-band, confidence + uncertainty present.
- [ ] **GROW-04:** Scenario authoring guide `.planning/persona-tests/AUTHORING.md` written for Julien — 25 lines YAML per scenario, 25 lines Dart assertions per scenario, ≤30 min authoring time per new scenario after pattern stabilized.
- [ ] **GROW-05:** Scope-guard automation : CI lane refuses to add a new persona to `scenarios_index.yaml` until prior personas are nightly-green for 5 consecutive nights (verifiable via R2 manifest history). Lint `tools/checks/persona_growth_gate.py`.
- [ ] **GROW-06:** Per-script touchpoint manifest schema (`tools/simulator/flows/<persona>.touchpoints.yaml`) — declares which screens/services this script exercises. Used by auto-bisect agent for failure root-causing.
- [ ] **GROW-07:** Auto-bisect tooling shipped (`tools/simulator/auto_bisect.py`) — given failing script_id, runs `git log --since=last-green` on files in touchpoint manifest, binary-searches commits, re-runs only failing script. ~3 iterations / 15 min to root cause typical.
- [ ] **GROW-08:** Stop-when-defensible rule documented : Phase 93 closes when 5 consecutive new scripts surface 0 net-new bug categories (saturation signal). « Journalist-defensible » becomes a checklist not a count. Total at saturation expected ~25-50, NOT 50 by mandate.

## Out of Scope (anti scope-creep, deferred to v2.14+)

| Feature | Reason |
|---------|--------|
| Patrol migration | Maestro YAML wins per panel #4 (lock-in, CI flakiness, less Julien-readable) |
| Live-LLM nightly suite | Replay-cache nightly + weekly opt-in live regression suffit ; live nightly = $300/mo for marginal value |
| Wave 2 bare-catches (next 50) | v2.12 Phase 87 closed Wave 1 (15 paths) ; Wave 2 carry-forward to v2.14 |
| Couple mode wiring | Data layer cracked, 2-3 sem propre fix |
| iPhone SE / iPad viewports | Single sim target = iPhone 17 Pro v2.13 |
| Banking + LPP API integration | v3.0+ |
| Wiki coach v3 | Post-TestFlight |
| Visual-regression on non-éclairage screens | Walker exit code + 5 JDEF semantic assertions cover safety profile |
| 6-lang persona scripts (DE/IT/ES/PT) | FR + EN suffit pour journalist-defense ship gate ; 6-lang à GROW-03 lib only |

## Traceability (filled by roadmap)

| Requirement | Phase | Status |
|-------------|-------|--------|
| PERS-01..08 | 90 | Pending |
| ARCH-01..08 | 91 | Pending |
| JDEF-01..08 | 92 | Pending |
| GROW-01..08 | 93 | Pending |

**Coverage:**
- v2.13 requirements: 32 total (8+8+8+8)
- Mapped to phases: 32/32 (100%)
- Phases: 4 (90 / 91 / 92 / 93)

## Constraints from Julien (operational)

- AUCUN TestFlight tant que JDEF-08 = SHIP-GATE PASS (5 scripts × 5 consecutive nightly green)
- Walker = la machine de vérité (doctrine v2.11+ reportée)
- Maestro YAML = la couche persona narrative (panel 6-pers 2026-05-05)
- Image budget : max 12 screenshots à Julien après SHIP-GATE PASS
- Pré-requis : v2.12 STAMP-08 PASS (Phase 89), c'est-à-dire 12 walks green + 7 mechanical gates green
- Scope-guard : aucune persona ajoutée tant que personas existantes pas nightly-green 5 nuits consécutives
- LLM replay-cache mandatoire : aucun ANTHROPIC_API_KEY ne doit gate un script
- NO « walker overhaul » phase. Coord drift = locator-layer fix, pas re-écriture walker.
- NO « delegated_via_substitute » markdown. Pass ou fail, pas de troisième état.

---
*Requirements defined: 2026-05-05*
*Panel-locked: 6-pers CI cost + E2E architecture + Storytelling + Maestro vs walker + Swiss financial + Postmortem*
*Last updated: 2026-05-05 — v2.13 milestone open, roadmap pending*
