---
phase: mint-illogism-fixes
plan: 11
subsystem: ui
tags: [confidence-gate, hero, estime-badge, sot-5, d2, d12, jeune_diplome-5, arbitrage, strangler-fig, i18n, parity]

# Dependency graph
requires:
  - phase: mint-illogism-fixes-07
    provides: ArchetypePredicates + PrevoyanceProfile.lppEstimationBlocked (état « valeur réelle requise »)
  - phase: mint-illogism-fixes-10
    provides: RenteVsCapitalScreen sans défauts fiction (contrôleurs vides) — rend l'inversion fiction>réel observable
provides:
  - "ChatFactCard.FactConfidenceState (known/estimated/gated) appliquant SOT §5 Confidence Gate au hero fact card du coach/home"
  - "widget_renderer._buildFactCard câblé sur EnhancedConfidence.combined — un chiffre financier hero n'est plus jamais rendu nu sous le gate (anti-façade)"
  - "ArbitrageEngine.compareRenteVsCapital accepte canonicalConfidence — RvC affiche le score canonique du profil (un profil = un score)"
  - "_computeArbitrageConfidence : plancher trompeur 50.0 retiré → inversion fiction>réel fermée (D12)"
  - "premier_eclairage liquidité dérivée d'une épargne estimée → tag estimé + cadrage pédagogique (jeune_diplome-5)"
  - "5 clés ARB ×6 langues (gate/CTA/incertitude/hypothèse salarié/liquidité estimée)"
affects: [coach-hero, rente-vs-capital, mon-argent, confidence-surfaces, matrix-d2, matrix-d12]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Confidence Gate à 3 états sur le hero (FactConfidenceState) : gated<50 → demande de données ; estimated → valeur + badge « estimé » + bande d'incertitude (50-69) ; known>=70 → chiffre nu. Le défaut (known) est rétro-compatible pour les fact cards non-financières."
    - "Source de confiance unique par strangler-fig : RvC consomme EnhancedConfidence.combined via un paramètre canonicalConfidence optionnel ; le moteur d'arbitrage local est dégradé en fallback heuristique (pas de big-bang)."
    - "Le badge « estimé » du hero réutilise la clé ARB existante budgetQualityEstimated (pattern Mon Argent>Prévoyance généralisé)."

key-files:
  created:
    - apps/mobile/test/services/confidence/confidence_source_unification_test.dart
    - apps/mobile/test/widgets/home_hero_confidence_test.dart
  modified:
    - apps/mobile/lib/widgets/coach/rich_chat_widgets.dart
    - apps/mobile/lib/widgets/coach/widget_renderer.dart
    - apps/mobile/lib/services/financial_core/arbitrage_engine.dart
    - apps/mobile/lib/services/arbitrage_summary_service.dart
    - apps/mobile/lib/screens/arbitrage/rente_vs_capital_screen.dart
    - apps/mobile/lib/services/premier_eclairage_selector.dart
    - apps/mobile/lib/l10n/app_*.arb (6 langues) + app_localizations*.dart (7 générés)

key-decisions:
  - "D12 racine élucidée : l'incohérence 44/50/30 NE vient PAS de deux formules différentes (la NOTE SOT §3 est périmée — `ConfidenceBreakdown.overall` est aujourd'hui une moyenne géométrique 4-axes identique à `EnhancedConfidence.combined`, pas un pondéré 40/35/25). Elle vient de TROIS chemins de calcul distincts sur le même profil perçu."
  - "Source unique = EnhancedConfidence.combined. RvC reçoit cette valeur via canonicalConfidence ; le 3e moteur (_computeArbitrageConfidence) reste comme fallback pour les appelants sans profil mais perd son plancher trompeur de 50.0."
  - "Hero gate implémenté sur ChatFactCard (le widget qui rend « 43'691 Avoir LPP » via show_fact_card), pas sur RetirementHeroZone (qui a déjà des bandes d'incertitude). Câblage côté widget_renderer pour ne pas être une façade."
  - "jeune_diplome-5 : pas de nouveau code modèle (le flag estimatedFields existe déjà). On réutilise PremierEclairageConfidence.pedagogical + on tague la liquidité quand currentSavings est estimé (Karpathy #2)."

patterns-established:
  - "FactConfidenceState : un hero financier dérive son état de rendu de EnhancedConfidence.combined + de la source de la donnée, jamais un chiffre nu sous le gate SOT §5."

requirements-completed: [MATRIX-D2, MATRIX-D12, MATRIX-jeune_diplome-5]

# Metrics
metrics:
  duration: ~17 min
  completed: 2026-06-11
  tasks: 2
  commits: 4
  files_created: 2
  files_modified: 19
---

# Phase mint-illogism-fixes Plan 11: W3 Confidence Gate + tags estimé + source de confiance unique Summary

**One-liner :** Le hero fact card du coach/home applique désormais le Confidence Gate SOT §5 à 3 états (gated `<50` → demande de données au lieu d'un chiffre nu ; estimé → valeur + badge « estimé » + bande d'incertitude ; connu `≥70` → chiffre nu) câblé sur `EnhancedConfidence.combined` — fin du « 43'691 Avoir LPP » nu affiché avec Fiabilité 44% (D2) ; et l'incohérence de fiabilité 44/50/30 (D12) est élucidée — trois moteurs de calcul distincts, pas deux formules — puis unifiée : RvC consomme la confiance canonique du profil et le plancher trompeur de 50.0 (qui rendait la fiction plus « fiable » que le réel) est retiré.

## Performance

- **Duration:** ~17 min
- **Completed:** 2026-06-11
- **Tasks:** 2/2
- **Files touched:** 21 (2 créés, 19 modifiés dont 7 l10n générés)

## Accomplishments

### Task 1 — Source de confiance unique (D12)
- **Mécanisme 44/50/30 élucidé avec citations file:line** (exigence A_REPRODUIRE de la matrice) :
  - **44 % (Mon Argent / home)** = `ConfidenceScorer.scoreEnhanced(profile).combined` — moyenne géométrique 4-axes avec shift `(x+1)/101` (`confidence_scorer.dart:831-836`).
  - **50 % (RvC)** = `ArbitrageEngine._computeArbitrageConfidence` — un **3e moteur local à l'écran** (`arbitrage_engine.dart:38-56`) qui renvoyait un **plancher codé en dur de 50.0** quand `dataSources` est null/vide (`:42`, `:45`) et un ratio de couverture sinon.
  - **30 % (Marc, données réelles)** = ce même ratio de couverture sur un profil réel mais partiel — d'où l'**inversion** : après le plan 10 (fiction tuée → RvC vide), un écran vide retombe sur le `50.0` floor tandis qu'un profil réel partiel obtient un ratio `<50`.
  - Le 3e objet `ConfidenceBreakdown.overall` (`enhanced_confidence_service.dart:94`) est **orphelin en production** (aucun appelant hors tests) — et la NOTE SOT §3 qui le décrit comme « pondéré 40/35/25 » est **périmée** : il utilise aujourd'hui la même géométrique 4-axes que `combined`.
- **Fix strangler-fig** : `compareRenteVsCapital` accepte `canonicalConfidence` (optionnel). Quand fourni (= `EnhancedConfidence.combined` calculé sur le même profil), c'est CETTE valeur qui est rendue → un profil = un score sur toutes les surfaces. Câblé aux **2 sites production** : `arbitrage_summary_service._computeRenteVsCapital` + le fallback du `RenteVsCapitalScreen`.
- **Inversion fermée** : le plancher `50.0` pour l'absence de données est retiré du fallback heuristique (`0.0` quand `total==0`, `clamp(0,95)` sinon) — la fiction sans données ne peut plus dépasser un profil réel partiel.

### Task 2 — Hero 3 états + Confidence Gate + tag estimé (D2 + jeune_diplome-5)
- `ChatFactCard` étendu avec `FactConfidenceState { known, estimated, gated }` (défaut `known`, rétro-compatible) :
  - `gated` (`<50`) → titre « Donnée à compléter » + CTA « Complète ton profil pour voir ce chiffre » (`Key('hero_fact_gated_cta')`), **aucun chiffre nu** — l'inverse exact de D2.
  - `estimated` → valeur + badge « estimé » (`Key('hero_fact_estimated_badge')`, réutilise `budgetQualityEstimated`) + note d'incertitude (bande 50-69).
  - `known` (`≥70`) → chiffre nu autorisé.
- **Câblage anti-façade** : `widget_renderer._buildFactCard` dérive l'état via `_factConfidenceState` → lit `EnhancedConfidence.combined` du profil (`CoachProfileProvider`), applique le gate SOT §5, et tague toute source estimateur. Les fact cards non-financières (`is_financial` absent et pas de `source`) gardent le rendu nu.
- **jeune_diplome-5** : `premier_eclairage._buildLiquidityChoc` reçoit `savingsEstimated` (depuis `estimatedFields.contains('currentSavings')`) → quand l'épargne (donc les mois de liquidité) vient de l'estimateur âge×salaire (0 dur à 25 ans), le chiffre est tagué (note estimée) + `confidenceMode: pedagogical` — fin du « 0 mois » présenté comme mesuré.
- **5 clés ARB ×6 langues** : `heroFactGatedTitle`, `heroFactGatedCta`, `heroFactUncertaintyNote`, `heroFactEmploymentAssumption` (« hypothèse : salarié »), `liquidityEstimatedNote` + `flutter gen-l10n`.

## Task Commits

1. **Task 1 — Source de confiance unique (D12)**
   - `43f32b713` (test, RED) — reproduit l'incohérence 44/50/30 + l'inversion fiction>réel ; `canonicalConfidence` pas encore exposé
   - `e37c67ce5` (feat, GREEN) — `canonicalConfidence` sur `compareRenteVsCapital`, plancher 50.0 retiré, câblage aux 2 sites production
2. **Task 2 — Hero 3 états + Confidence Gate + tag estimé (D2 + jeune_diplome-5)**
   - `ad2e4c86e` (test, RED) — 4 cas (3 états + rétro-compat) ; `FactConfidenceState` pas encore défini
   - `fe676d0f2` (feat, GREEN) — `FactConfidenceState` + câblage `_buildFactCard` + tag liquidité + 5 clés ARB ×6 + gen-l10n

_Le SUMMARY + la mise à jour VALIDATION.md + deferred-items.md sont committés séparément (docs commit)._

## Files Created/Modified
- `confidence_source_unification_test.dart` (créé) — 3 cas D12 : RvC honore la confiance canonique ; inversion fiction>réel fermée ; monotonie du fallback préservée.
- `home_hero_confidence_test.dart` (créé) — 4 cas D2 : gated<50 → pas de chiffre nu ; estimé → badge ; connu → nu ; défaut rétro-compatible.
- `arbitrage_engine.dart` — `_computeArbitrageConfidence` honore `canonicalConfidence`, plancher 50.0 retiré ; `compareRenteVsCapital` accepte le paramètre.
- `arbitrage_summary_service.dart` + `rente_vs_capital_screen.dart` — calculent `EnhancedConfidence.combined` sur le profil et le passent à RvC.
- `rich_chat_widgets.dart` — `FactConfidenceState` enum + rendu 3 états de `ChatFactCard` (badge `_EstimatedBadge`, prompt `_GatedPrompt`).
- `widget_renderer.dart` — `_buildFactCard` câblé sur la confiance canonique via `_factConfidenceState`.
- `premier_eclairage_selector.dart` — `_buildLiquidityChoc` tague la liquidité estimée (jeune_diplome-5).
- `app_*.arb` (6) + `app_localizations*.dart` (7 générés) — 5 nouvelles clés.

## Decisions Made
- **D12 = trois moteurs, pas deux formules.** La matrice supposait (via SOT §3 NOTE) une double comptabilité géométrique-vs-pondéré. Réalité élucidée : `ConfidenceBreakdown.overall` est aujourd'hui aussi une géométrique 4-axes (NOTE périmée), et il est orphelin en production. La vraie divergence = RvC calcule un **3e** score local (`_computeArbitrageConfidence`) avec un plancher 50.0. Le fix cible ce moteur réel, pas le fantôme de la NOTE.
- **Strangler-fig, pas big-bang.** `canonicalConfidence` est optionnel : les appelants sans profil (harnais de test, prefill API brut) gardent le fallback heuristique (désormais sans plancher trompeur). Aucun élargissement de signature non requis (Karpathy #2/#3).
- **Gate sur ChatFactCard, pas RetirementHeroZone.** Le « 43'691 Avoir LPP » de D2 (capture ind-home.png) transite par `show_fact_card` → `ChatFactCard`. `RetirementHeroZone` (revenu/mois) a déjà des bandes d'incertitude et n'est pas la surface de D2.
- **Réutilisation du badge existant.** Le badge « estimé » réutilise `budgetQualityEstimated` (le pattern Mon Argent), pas une nouvelle clé — généralisation, pas duplication.

## Deviations from Plan

None — plan exécuté tel qu'écrit. Une clarification de scope : la NOTE SOT §3 (« ConfidenceBreakdown.overall pondéré 40/35/25 ») s'est révélée périmée à la lecture du code (`enhanced_confidence_service.dart:94` = géométrique 4-axes). Le plan anticipait « A_REPRODUIRE puis unifier » la double comptabilité géométrique-vs-pondéré ; la reproduction a montré que la divergence réelle est ailleurs (3e moteur d'arbitrage local avec plancher 50.0). Le fix livré ferme la divergence réelle observable (RvC vs Mon Argent + inversion fiction>réel) ; la NOTE SOT §3 reste à corriger dans un PR doc séparé (hors scope code de ce plan).

## Known Stubs

**`heroFactEmploymentAssumption` (« hypothèse : salarié ») est câblé côté ARB mais pas encore affiché par une surface dans ce plan.** La clé est prête (×6 langues, parité OK) ; l'affichage de l'étiquette « hypothèse : salarié » sur les chiffres archétype-dépendants quand le statut d'emploi est inconnu relève du même mécanisme que le gate hero (un `FactConfidenceState`/tag dérivé du profil). Le plan a livré le gate confiance + le badge estimé (les 3 états testés et câblés) ; l'étiquette d'hypothèse d'emploi est une extension du même pattern, prête à consommer dès qu'une surface expose un statut d'emploi non collecté. Ce n'est pas un stub bloquant : le hero ne rend déjà plus de chiffre archétype-dépendant nu sous le gate `<50` (le cas « statut inconnu » tombe dans le gate via une confiance dégradée). À surfacer explicitement si un besoin produit l'exige (plan 13 onboarding-truth est le candidat naturel).

## Verification Evidence (0-TRUST)

```
Evidence : flutter test test/services/confidence/confidence_source_unification_test.dart → "00:00 +3: All tests passed!"
Evidence : flutter test test/widgets/home_hero_confidence_test.dart → "00:00 +4: All tests passed!"
Evidence : flutter test test/services/financial_core/ → "00:03 +577: All tests passed!"
Evidence : flutter test (hero+confidence+arbitrage+premier_eclairage+renderer+smoke+rvc-defaults) → "00:02 +122: All tests passed!"
Evidence : flutter analyze (rich_chat_widgets + widget_renderer + arbitrage_engine + arbitrage_summary_service + rente_vs_capital_screen + premier_eclairage_selector) → "No issues found!"
Evidence : tools/checks/arb_parity.py → "OK — 6 locale(s) parity (reference=fr, 6904 keys each)" ; lefthook arb-parity-gate → "6909 keys each"
Evidence : tools/checks/banned_terms_arb.py → "OK — 6 locale(s) clean (no positive LSFin banned-term uses)"
Evidence : accent_lint_fr.py --file app_fr.arb → aucune des 5 nouvelles clés flaggée (clean)
Evidence : RED→GREEN documenté — 43f32b713 (RED, canonicalConfidence absent) → e37c67ce5 (GREEN) ; ad2e4c86e (RED, FactConfidenceState absent) → fe676d0f2 (GREEN)
Evidence : citations racine D12 — confidence_scorer.dart:831-836 (combined) ; arbitrage_engine.dart:38-56 (3e moteur, plancher 50.0 lignes 42/45) ; enhanced_confidence_service.dart:94 (overall orphelin) ; grep production callers de computeConfidence → seulement le fichier lui-même
Caveat   : end-to-end UNKNOWN — pas de walkthrough sim ; tests verts ≠ feature working (§9.2). Device-proof D2 inversé (profil 44% → hero gated) déféré à l'orchestrateur (build iOS impossible depuis worktree .nosync isolé, comme W1/W2 plans 05/06/07/08).
```

## Device-Proof Status

**DEFERRED-TO-ORCHESTRATOR.** Comme les W1/W2 précédents (`d755c06af`, plan 06 ; plan 07/08), un build iOS complet depuis ce worktree `.nosync` isolé n'est pas réalisable sans casser la provenance/codesign macOS. Le device-proof D2-inversé (sim : profil Fiabilité 44% → hero gaté, PAS de « Avoir LPP » nu ; badge « estimé » visible sur Mon Argent ET home ; capture `.planning/_walker/illogism-fixes/w3/`) tourne contre la branche d'intégration mergée. Le **panel design 4-personnes** sur les écrans modifiés (hero gated/estimé) est également à exécuter par l'orchestrateur au moment du device-proof (acceptance criterion Task 2). Per 0-TRUST §9 : aucune revendication « works »/« ready » — preuve déterministe = tests verts uniquement.

## Next Phase Readiness
- D2, D12, jeune_diplome-5 fermés au niveau code/test avec oracle re-run cité (RED→GREEN + citations file:line du mécanisme 44/50/30).
- `FactConfidenceState` est le point d'extension pour l'étiquette « hypothèse : salarié » (plan 13 onboarding-truth) et pour gater d'autres chiffres financiers hero.
- NOTE SOT §3 à corriger (PR doc) : `ConfidenceBreakdown.overall` n'est plus pondéré 40/35/25 mais géométrique 4-axes ; il est orphelin en production (candidat dépréciation).

## Self-Check: PASSED

- Created file exists: `apps/mobile/test/services/confidence/confidence_source_unification_test.dart`
- Created file exists: `apps/mobile/test/widgets/home_hero_confidence_test.dart`
- Created file exists: this SUMMARY.
- Commits exist: `43f32b713`, `e37c67ce5`, `ad2e4c86e`, `fe676d0f2`.

---
*Phase: mint-illogism-fixes*
*Completed: 2026-06-11*
