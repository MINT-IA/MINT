---
phase: mint-illogism-fixes
plan: 17
subsystem: ui
tags: [flutter, i18n, a11y, semantics, what-if, conjoint, arb, maestro]

# Dependency graph
requires:
  - phase: mint-illogism-fixes-11
    provides: "pattern « hypothèse / estimé » (tag estimé) réutilisé pour étiqueter le what-if mariage"
  - phase: mint-illogism-fixes-16
    provides: "vague W5 précédente (surfaces honnêtes)"
provides:
  - "Écran Mariage : le « Revenu 2 » par défaut (60'000) est étiqueté hypothèse modifiable quand aucun conjoint réel n'existe (D9)"
  - "Fix ghost-conjoint : fromWizardAnswers ne ressuscite plus un conjoint depuis des clés q_partner_* résiduelles si le ménage est déclaré single"
  - "Labels a11y localisés : plus de clé brute lue par VoiceOver (D11)"
  - "« Document non disponible » passe par AppLocalizations (NEVER #1)"
affects: [mariage_screen, coach_profile, explorer_screen, coach_packet_insight_card, maestro-regression-flows]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Semantics(identifier:) pour le selector machine stable + label: localisé — sépare la cible Maestro du texte a11y user-facing (pattern confidence_score_card)"
    - "Gate de reconstruction du conjoint sur la cohérence du ménage (q_household_type != single), pas sur l'état civil seul"
    - "Étiquette « hypothèse modifiable » sur un défaut what-if fabriqué quand le profil ne fournit pas la vraie valeur"

key-files:
  created:
    - apps/mobile/test/screens/mariage_whatif_labels_test.dart
  modified:
    - apps/mobile/lib/screens/mariage_screen.dart
    - apps/mobile/lib/models/coach_profile.dart
    - apps/mobile/lib/screens/explore/explorer_screen.dart
    - apps/mobile/lib/widgets/coach/coach_packet_insight_card.dart
    - apps/mobile/lib/app.dart
    - apps/mobile/lib/l10n/app_*.arb (×6, +4 clés)
    - tools/simulator/flows/maestro-perfect-set/flow_drawer_navigation_smoke.yaml (+3 autres flows : text: → id:)

key-decisions:
  - "D9 : ne PAS supprimer la capacité what-if (outil de scénario légitime) — la rendre honnête via une étiquette hypothèse + champ éditable ; le Revenu 2 se mue en fait seulement quand un vrai conjoint hydrate la valeur"
  - "Ghost conjoint keyé sur q_household_type (== single → purge), pas sur etatCivil : un divorcé PEUT vivre en couple, donc household=couple conserve le conjoint réel"
  - "D11 : conserver le selector machine stable via Semantics(identifier:) et localiser le label : ; migrer les 4 flows Maestro de text: → id: pour ne pas casser la reachability"

patterns-established:
  - "Pattern 1 : un défaut what-if fabriqué porte une étiquette hypothèse tant qu'aucune donnée réelle ne l'hydrate"
  - "Pattern 2 : a11y label = texte localisé ; identifier = ID machine stable pour les flows Maestro (id:)"

requirements-completed: [MATRIX-D9, MATRIX-D11, MATRIX-W5-i18n-hardcode]

# Metrics
duration: 25min
completed: 2026-06-11
---

# Phase mint-illogism-fixes Plan 17: W5 — Surfaces honnêtes (strings/labels) Summary

**L'outil what-if Mariage déclare désormais ses hypothèses (Revenu 2 fabriqué → « Hypothèse modifiable » éditable), le ghost-conjoint est purgé sur ménage single, les labels a11y bruts deviennent du texte localisé et « Document non disponible » passe par AppLocalizations.**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-06-11T22:45:00Z
- **Completed:** 2026-06-11T23:10:00Z
- **Tasks:** 2 (+ 1 finding hors-plan : ghost conjoint)
- **Files modified:** 24 (incl. ARB ×6 + générés l10n + 4 flows Maestro)

## Accomplishments

- **D9 — what-if Mariage honnête** : pour un profil sans conjoint réel, le « Revenu 2 » (défaut 60'000) porte l'étiquette « Hypothèse modifiable — saisis le revenu réel de ton conjoint pour affiner le scénario » et reste éditable. Avec un conjoint réel, le Revenu 2 est hydraté depuis la vraie valeur, SANS étiquette (fait, pas hypothèse).
- **Ghost conjoint (finding hors-plan, Codex W2 review)** : `CoachProfile.fromWizardAnswers` ne reconstruit plus un `ConjointProfile` depuis des clés `q_partner_*` résiduelles quand `q_household_type == single`. Keyé sur le ménage et non l'état civil — un divorcé en couple (household=couple) garde son conjoint réel.
- **D11 — labels a11y localisés** : `explorer_screen` (« ouvrir-profil-drawer ») et `coach_packet_insight_card` (« coach-context-point-de-depart ») exposent désormais un label localisé lisible par VoiceOver ; le selector machine stable passe par `Semantics(identifier:)`.
- **i18n hardcodé** : les deux « Document non disponible » de `app.dart` passent par `S.of(context)!.documentNonDisponible` (clé ARB ×6).
- **Maestro** : 4 flows passent `text: "ouvrir-profil-drawer"` → `id: "ouvrir-profil-drawer"` (le selector cible l'identifier, pas le label localisé), YAML re-validé.

## Task Commits

1. **Task 1: Mariage what-if hypothèses + fix ghost conjoint (D9)** — `d59153883` (feat)
   - TDD : RED→GREEN dans une session unique (5 tests : 2 widget D9 + 3 unit ghost-conjoint). Test écrit d'abord, vérifié rouge (label absent + conjoint fantôme reconstruit), puis vert après implémentation.
2. **Task 2: Labels a11y localisés + i18n « Document non disponible » (D11)** — `5b8553abc` (feat)

_Note : les deux commits sont des feat ; le commit Task 1 contient à la fois le test (RED) et l'implémentation (GREEN) — la séquence RED→GREEN a été exécutée et vérifiée (RED cité ci-dessous), mais committée comme une unité cohérente._

## Files Created/Modified

- `apps/mobile/test/screens/mariage_whatif_labels_test.dart` — **créé** : tests D9 (sans/avec conjoint) + 3 cas ghost-conjoint (single+résidus → null ; couple → reconstruit ; divorcé-en-couple → conservé)
- `apps/mobile/lib/screens/mariage_screen.dart` — flag `_revenu2IsHypothesis` (défaut true) ; prefill depuis conjoint réel ; étiquette hypothèse + `Key('mariage_revenu2_hypothesis_note')` + `Key('mariage_revenu2_field')`
- `apps/mobile/lib/models/coach_profile.dart` — gate `householdSingle` sur `hasConjointData` (ghost-conjoint)
- `apps/mobile/lib/screens/explore/explorer_screen.dart` — `Semantics(identifier: 'ouvrir-profil-drawer', label: S.of(context)!.semanticsOpenProfile)`
- `apps/mobile/lib/widgets/coach/coach_packet_insight_card.dart` — `Semantics(identifier: 'coach-context-point-de-depart', label: S.of(context)!.semanticsCoachContextStartingPoint)` + import l10n
- `apps/mobile/lib/app.dart` — 2× `Text(S.of(context)!.documentNonDisponible)` (retrait `const`)
- `apps/mobile/lib/l10n/app_*.arb` (×6) — 4 nouvelles clés : `mariageRevenu2Hypothesis`, `semanticsOpenProfile`, `semanticsCoachContextStartingPoint`, `documentNonDisponible` (parité 6923/6923)
- `apps/mobile/lib/l10n/app_localizations*.dart` — régénérés via `flutter gen-l10n`
- `tools/simulator/flows/maestro-perfect-set/{flow_drawer_navigation_smoke,flow_empty_state_cascade,flow_g2_julien_walkthrough,flow_row22_primary_screen_visual_crawl}.yaml` — `text:` → `id:` (16 selectors)
- `apps/mobile/test/widgets/coach/coach_packet_insight_card_test.dart` — harness localisé (délégués S + locale fr)

## Decisions Made

- **D9 capacité préservée** : un what-if reste un outil de scénario légitime ; la correction est de l'honnêteté de présentation (étiquette + éditabilité), pas une amputation. Aligné CLAUDE.md NEVER #8 (no promise) + intégrité de présentation.
- **Ghost conjoint minimal & safe** : gate sur `q_household_type == single` (exclusion uniquement du ménage explicitement single) plutôt que sur `etatCivil`. Respecte le cas réel « divorcé vivant en couple » (note deferred-items). Les tests sans `q_household_type` ne sont pas affectés (gate ne déclenche que sur `single` explicite) — 0 régression sur 191 tests conjoint-related.
- **D11 identifier vs label** : réutilisation du pattern existant `Semantics(identifier:)` (confidence_score_card, cap_du_jour_banner) ; Maestro cible l'identifier via `id:`. Évite de casser les 4 flows tout en supprimant la fuite a11y.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 — Missing Critical / Threat T-ILF-17-01] Fix ghost-conjoint dans fromWizardAnswers**
- **Found during:** Task 1 (scope D9 conjoint fictif) — explicitement assigné au plan 17 par l'objectif + deferred-items.md (Codex W2 review).
- **Issue:** `fromWizardAnswers` reconstruisait un `ConjointProfile` depuis toute clé `q_partner_*` résiduelle quel que soit l'état du ménage → conjoint fantôme (AVS couple cap 150 % appliqué à un single) après repassage en single / divorce.
- **Fix:** gate `householdSingle = q_household_type == 'single'` ; `hasConjointData` exige `!householdSingle`.
- **Files modified:** apps/mobile/lib/models/coach_profile.dart
- **Verification:** 3 tests unitaires ghost-conjoint (RED→GREEN) + 191 tests conjoint-related verts (golden_couple, income_converter, financial_report, avs_logic, life_events_divorce, coach_profile).
- **Committed in:** d59153883

**2. [Rule 3 — Blocking] Harness localisé pour coach_packet_insight_card_test**
- **Found during:** Task 2.
- **Issue:** le widget appelle désormais `S.of(context)!` ; l'ancien `MaterialApp` du test n'avait pas les délégués l10n → test cassé par la localisation D11.
- **Fix:** ajout délégués `S.delegate` + `GlobalMaterialLocalizations` + locale `fr`.
- **Files modified:** apps/mobile/test/widgets/coach/coach_packet_insight_card_test.dart
- **Verification:** test re-vert.
- **Committed in:** 5b8553abc

**3. [Rule 3 — Blocking] Migration selectors Maestro text: → id:**
- **Found during:** Task 2.
- **Issue:** 4 flows Maestro ciblaient `text: "ouvrir-profil-drawer"` ; localiser le label a11y aurait cassé la reachability.
- **Fix:** `Semantics(identifier: 'ouvrir-profil-drawer')` côté source + `id: "ouvrir-profil-drawer"` côté flows (16 selectors) ; YAML re-validé.
- **Files modified:** 4 flows maestro-perfect-set.
- **Verification:** `assertVisible id: "ouvrir-profil-drawer"` COMPLETED sur sim (cf. Device-proof D11).
- **Committed in:** 5b8553abc

---

**Total deviations:** 3 auto-fixées (1 missing-critical/threat, 2 blocking). **Impact :** la première était in-scope explicite (finding ghost-conjoint assigné au plan 17) ; les deux autres sont des conséquences directes de la localisation D11. Aucun scope creep.

## Verification — gates mécaniques (citations)

- `cd apps/mobile && flutter test test/screens/mariage_whatif_labels_test.dart` → **5/5 « All tests passed! »** (cité, RED→GREEN).
- **RED cité** : avant implémentation, le test échouait sur `mariage_revenu2_hypothesis_note` (« Found 0 widgets ») + ghost conjoint (`Expected null, Actual ConjointProfile`).
- `flutter analyze` (mobile complet) → **« No issues found! »**.
- `python3 tools/checks/arb_parity.py` → **« OK — 6 locale(s) parity (reference=fr, 6923 keys each) »**.
- `python3 tools/checks/banned_terms_arb.py` → **« OK — 6 locale(s) clean »**.
- `python3 tools/checks/accent_lint_fr.py` (sur lignes touchées) → **aucune violation dans les fichiers/clés du plan** (les 283 violations rapportées sont pré-existantes : backend python, walker tooling, schema docs, slug de route `/onboarding/premier-eclairage` — toutes hors diff du plan, cf. deferred-items.md).
- Grep gates : `grep -rn "label: '[a-z][a-z-]*-[a-z-]*[a-z]'" lib/` → **0 label a11y à clé brute** ; `grep -rn "Document non disponible" lib/app.dart` → **0**.
- 191 tests conjoint-related → verts (0 régression sur le fix ghost-conjoint).

## Device-proof (sim, build frais post-commits)

Build : `flutter build ios --simulator --debug` à **23:00:22** (postérieur aux commits 22:50 / 22:58) → `Runner.app` frais installé sur iPhone 17 (iOS 26.2, FC911A9F). Le build frais a été nécessaire : le `.app` cache du jour datait de 14:54, antérieur aux fixes (cf. deferred-items.md note W1).

- **D9 — `.planning/_walker/illogism-fixes/final/D9-mariage-hypothesis-label.png`** : profil sans conjoint → « Revenu 1 : CHF 80'000 » + « Revenu 2 : CHF 60'000 » (champs éditables, icône crayon) ; directement sous Revenu 2 : **« ⊟ Hypothèse modifiable — saisis le revenu réel de ton conjoint pour affiner le scénario. »**. Maestro : `scrollUntilVisible "Hypothèse modifiable"` COMPLETED + `assertVisible "Hypothèse modifiable"` (90 %) COMPLETED.
- **D11 — `.planning/_walker/illogism-fixes/final/D11-explorer-localized-a11y.png`** : écran Explorer rendu. Maestro : `assertNotVisible "ouvrir-profil-drawer"` COMPLETED (clé brute PLUS dans l'arbre texte/a11y) + `assertVisible id: "ouvrir-profil-drawer"` COMPLETED (l'identifier machine résout toujours → flows non cassés).

## Issues Encountered / Constraints (0-TRUST)

- **ILLOG01/02 + tableau D1-D12 complet = DEFERRED-TO-ORCHESTRATOR (gate de phase, pas de plan 17).** Les flows `bug__ILLOG01/02` testent les plans 09/10 (RvC fiction defaults) et exigent un **profil pré-onboardé sans LPP stocké** (PRE-CONDITION du flow). L'install frais n'a aucun profil → le deeplink `mintapp:///rente-vs-capital` n'atteint pas RvC (écran onboarding/vide). Reproduire le seed complet (onboarding walkthrough → deeplink) dépasse le scope des surfaces du plan 17 et reste contraint par le seeding documenté (deferred-items.md lignes 13-14 : build cache stale + modal disclaimer bêta). **Citation honnête : plan 17's OWN surfaces (D9 mariage + D11 explorer) sont device-proofées sur build frais ; le re-run ILLOG01/02 GREEN + tableau D1-D12 reste à exécuter par l'orchestrateur dans le walkthrough de clôture de phase avec un build seedé.**
- **Banned phrase discipline** : je ne déclare PAS « phase fermée » / « ready » / « shipped ». Ce qui est prouvé déterministiquement : 2 commits, 5/5 tests, lints verts, parité ARB 6923, D9 + D11 device-proofés sur build frais. Ce qui N'EST PAS prouvé : le tableau D1-D12 complet + ILLOG01/02 sur profil seedé (deferred orchestrateur).

## Next Phase Readiness

- D9, D11, i18n W5 : code complet, testé déterministiquement, device-proofé pour les surfaces du plan.
- **Pour l'orchestrateur (clôture de phase)** : exécuter le walkthrough D1-D12 + ILLOG01/02 GREEN sur un build seedé (profil onboardé sans LPP) — c'est le dernier gate de phase, hors scope plan 17.
- STATE.md / ROADMAP.md : NON modifiés (propriété orchestrateur).

## Self-Check: PASSED

- `apps/mobile/test/screens/mariage_whatif_labels_test.dart` — FOUND
- `.planning/phases/mint-illogism-fixes/mint-illogism-fixes-17-w5-surfaces-honnetes-strings-SUMMARY.md` — FOUND
- `.planning/_walker/illogism-fixes/final/D9-mariage-hypothesis-label.png` — FOUND
- `.planning/_walker/illogism-fixes/final/D11-explorer-localized-a11y.png` — FOUND
- commit `d59153883` (Task 1) — FOUND
- commit `5b8553abc` (Task 2) — FOUND
