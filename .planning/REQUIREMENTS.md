# Requirements: MINT v2.12 — Production-Ready Sim Validation

**Defined:** 2026-05-05
**Research artifacts:** Panel 4-pers (Sim QA + Observability + i18n + a11y) — locked spec
**Core Value:** Aucun TestFlight tant que Claude n'a pas validé que l'app tourne PARFAITEMENT sur simulator.

## Source de vérité — pourquoi v2.12 existe

v2.11 a wiré le contrat eclairage end-to-end (PRs #490-#496) mais **aucun walker n'a passé green sur 4 archetypes**. Le smoke run Phase 85 a hit un blocker bash 3.2 (fixed 8e148cd1) ; aucune validation runtime de l'app intégrée.

5 dettes empêchent de dire « production-ready » :
- 388 bare catches silencieux → walker peut « réussir » avec erreurs invisibles
- FIX-03 save_fact unsync, FIX-04 coach tab routing — non close
- Cross-language non-validé runtime
- Performance + a11y gates jamais mesurés sur sim
- Aucun « stamp » mécanique d'autorisation TestFlight

v2.12 ferme ces dettes via 4 phases sequential + 7-gate quality stamp.

## v2.12 Requirements (32 REQs, 4 phases)

### Phase 86 — Walker green réel 4 archetypes FR — `SIMQ-*`

- [ ] **SIMQ-01:** Walker green sur archetype `julien_swiss` FR exit 0, `--retry-once` allowed, runtime ≤ 4 min.
- [ ] **SIMQ-02:** Walker green sur `couple_acheteurs_lausanne` FR exit 0.
- [ ] **SIMQ-03:** Walker green sur `jeune_diplome_zurich` FR exit 0.
- [ ] **SIMQ-04:** Walker green sur `cadre_40_55_lpp_rachat` FR exit 0.
- [ ] **SIMQ-05:** `walker_premier_eclairage.sh --retry-once` flag implémenté + documenté dans `tools/simulator/README.md`.
- [ ] **SIMQ-06:** `walker_premier_eclairage.sh --record-trace` émet manifest JSON `walker-trace-<archetype>-<lang>-<timestamp>.json` avec event IDs Sentry par étape.
- [ ] **SIMQ-07:** `walker_premier_eclairage.sh --locale=<fr|de|en>` passe `--dart-define=APP_LOCALE=<lang>` à `flutter run` (cold restart, pas toggle settings).
- [ ] **SIMQ-08:** Calibration timing locked: `BOOT_WAIT=4s`, `FRAME_SETTLE=800ms`, `TAP_SETTLE=400ms` constants in walker shell, no magic numbers inline.

### Phase 87 — Bare-catches sweep Wave 1 (15 paths) — `OBSV-*`

- [ ] **OBSV-01:** Bucket (a) walker-path catches: 6 sites converted from bare catch to typed catch + Sentry `captureException` + breadcrumb (LandingScreen.cta, AnonymousChatScreen.send, EclairageCardController.tap, RegisterScreen.submit, deep-link handler, route guard).
- [ ] **OBSV-02:** Bucket (b) data-integrity catches: 5 sites (save_fact dispatcher, profile persistence, JWT refresh, secure storage read, OpenAPI client) — same pattern.
- [ ] **OBSV-03:** Bucket (c) UI-service catches: 3 sites (Coach ChangeNotifier, ComplianceGuard observer, Sentry beforeSend).
- [ ] **OBSV-04:** Bucket (d) top-1 ranked-by-walker-overlap catch wired (TBD via grep ranked).
- [ ] **OBSV-05:** `.planning/BARE_CATCH_DEBT.md` ledger created listing all remaining bare catches (file:line + grandfather rationale + target milestone).
- [ ] **OBSV-06:** Lint `tools/checks/no_new_bare_catch.py` blocks new bare catches outside ledger; pre-commit hook wired.
- [ ] **OBSV-07:** Wave 2 (next 50) explicitly deferred to v2.13 in `.planning/milestones/v2.13-ROADMAP.md` skeleton.
- [ ] **OBSV-08:** Each Wave-1 site has a unit test asserting Sentry capture fires on synthetic exception.

### Phase 88 — Cross-language 12 walks — `XLOC-*`

- [ ] **XLOC-01:** Walker green 4 archetypes × DE (cold-launch with `APP_LOCALE=de`), 0 retries.
- [ ] **XLOC-02:** Walker green 4 archetypes × EN, 0 retries.
- [ ] **XLOC-03:** 4 archetypes × FR re-run under 0-retry contract (regression vs Phase 86).
- [ ] **XLOC-04:** DE golden bake of 4-card éclairage screen separate from FR — `goldens/eclairage_4card_de.png` committed.
- [ ] **XLOC-05:** No-ellipsis assertion: 4-card éclairage in DE renders without `…` truncation on iPhone 17 Pro sim viewport (1206×2622).
- [ ] **XLOC-06:** ARB parity check (`validate_arb_parity()`) green on FR/DE/EN at PR-open and pre-commit.
- [ ] **XLOC-07:** Walker manifest aggregates 12 traces under `.planning/phases/88-xloc/walker-traces/<date>/`.
- [ ] **XLOC-08:** IT/ES/PT walker explicitly deferred to v2.13 with rationale in `.planning/phases/88-xloc/XLOC-08-deferral.md`.

### Phase 89 — Quality stamp 7-gate — `STAMP-*`

- [ ] **STAMP-01:** Gate 1 — 12 walks pass exit 0, 0 retries (re-run from Phase 88 manifest).
- [ ] **STAMP-02:** Gate 2 — cold-launch P50 ≤ 2.5s on iPhone 17 Pro sim over 5 boots, measured via `xcrun simctl spawn booted log stream --predicate 'process="Runner"'`.
- [ ] **STAMP-03:** Gate 3 — frame jank < 1% > 16ms on 4-card éclairage scroll-and-tap, 5s window, captured via `--enable-software-rendering` profile run.
- [ ] **STAMP-04:** Gate 4 — VoiceOver smoke on `julien_swiss` × FR/DE/EN éclairage flow, reading order asserted via `Semantics.sortKey` snapshot, no orphan focus.
- [ ] **STAMP-05:** Gate 5 — walker run on staging emits ≥ 8 distinct Sentry breadcrumb categories within 2 min (compliance.{pass,fail}, save_fact.{success,error}, feature_flags.refresh.{success,failure}, anon.intent.start, eclairage.card.tap).
- [ ] **STAMP-06:** Gate 6 — ARB parity 6-lang (`validate_arb_parity`) exits 0 at stamp time.
- [ ] **STAMP-07:** Gate 7 — `BARE_CATCH_DEBT.md` exists + lint `no_new_bare_catch.py` exits 0 + new catches outside ledger blocked.
- [ ] **STAMP-08:** Stamp report `.planning/phases/89-stamp/STAMP-PASS-<date>.html` generated with all 7 gates green ; TestFlight tag blocked until stamp PASS. Julien voit max 12 screenshots après stamp PASS (1 final par walk).

## Out of Scope (anti scope-creep, deferred to v2.13)

| Feature | Reason |
|---------|--------|
| Walker IT/ES/PT | ARB parity covers TI/ES/PT strings, visual gate hors scope v2.12 |
| Auth-tier regression archetype | v2.12 = anonymous-flow validation only |
| Wave 2 bare-catches (next 50) | Wave 1 = top 15, suffit pour observability gate ; Wave 2 → v2.13 |
| Couple mode wiring | Data layer cracked, 2-3 sem propre fix |
| iPhone SE / iPad viewports | Single sim target = iPhone 17 Pro v2.12 ; multi-device v2.13+ |
| Wiki coach v3 | Post-TestFlight |
| Banking + LPP API integration | v3.0+ |
| In-sim WCAG contrast verification | Lint `wcag_aa_all_touched.py` covers it |
| Screenshot diff for non-eclairage screens | Walker exit code covers other screens |

## Traceability (filled by roadmap)

| Requirement | Phase | Status |
|-------------|-------|--------|
| SIMQ-01..08 | 86 | Pending |
| OBSV-01..08 | 87 | Pending |
| XLOC-01..08 | 88 | Pending |
| STAMP-01..08 | 89 | Pending |

**Coverage:**
- v2.12 requirements: 32 total (8+8+8+8)
- Mapped to phases: 32/32 (100%)
- Phases: 4 (86 / 87 / 88 / 89)

## Constraints from Julien (operational)

- AUCUN TestFlight tant que STAMP-08 = PASS
- Claude valide tout via simulator iPhone 17 Pro (Mac mini)
- Image budget : max 12 screenshots à Julien après STAMP PASS (1 par walk)
- Walker = la machine de vérité (doctrine v2.11 reportée)
- Pré-requis : v2.11 PRs #490-#496 mergés à dev

---
*Requirements defined: 2026-05-05*
*Panel-locked: 4-pers Sim QA + Observability + i18n + a11y*
*Last updated: 2026-05-05 — v2.12 milestone open, roadmap pending*
