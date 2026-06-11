---
phase: mint-illogism-fixes
plan: 14
type: execute
wave: 12
depends_on: [mint-illogism-fixes-04, mint-illogism-fixes-11]
files_modified:
  - apps/mobile/lib/services/budget_living_engine.dart
  - apps/mobile/test/services/suggestion_3a_cap_test.dart
autonomous: true
requirements:
  - MATRIX-D10
must_haves:
  truths:
    - "Toute suggestion « tu pourrais verser X CHF en 3a » est plafonnée au plafond légal annuel RESTANT (plafond canonique du plan 04 − versements déjà effectués), pro-raté sur les mois restants."
    - "Plus jamais 1462-1541 CHF/mois (≈2.4× le plafond 7258/an) suggéré sans mention du plafond (D10, reproduit sur 2 profils)."
  artifacts:
    - path: "apps/mobile/test/services/suggestion_3a_cap_test.dart"
      provides: "Tests : marge libre haute → suggestion ≤ plafond restant/mois ; plafond atteint → 0 ou réorientation"
      min_lines: 30
  key_links:
    - from: "moteur de suggestion 3a (site à localiser, voir Task 1)"
      to: "tax_calculator annualCeiling (plan 04)"
      via: "clamp au plafond restant"
      pattern: "annualCeiling|plafond"
---

<objective>
W4 — Suggestion 3a plafonnée : la suggestion mensuelle 3a est aujourd'hui dérivée de la marge libre sans référence au plafond légal (device-prouvé D10 : « verser 1541 CHF/mois » Marc, « 1462 » profil 2 — ×12 ≈ 2.4× le plafond 7258, jamais mentionné). Le plafond canonique existe (plan 04) ; ce plan câble le clamp.

NOTE files_modified : le site exact de la suggestion est à confirmer en Task 1 (p17-monargent.png + ind-futur.png pointent vers la surface Mon Argent/futur — moteur probable : budget_living_engine ou le contenu du tiroir futur). Si le site réel diffère, l'étendre et le documenter dans le SUMMARY.

Purpose: ferme D10.
Output: clamp au plafond restant + test.
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/reports/MATRIX-illogismes-2026-06-09.md (D10)

<interfaces>
Plafond canonique : `estimate3aTaxImpact(...).annualCeiling` (tax_calculator.dart, base nette post-plan 04 ; 7258 avec LPP / min(net×0.20, 36288) sans).
Surface device : Mon Argent (p17-monargent.png) + tiroir futur (ind-futur.png) — la suggestion vient de la réallocation de marge libre.
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Localiser le(s) site(s) de suggestion 3a (oracle grep)</name>
  <files>aucune modification — diagnostic</files>
  <read_first>
    - Ligne matrice D10 (montants exacts 1541/1462 et surfaces)
    - `grep -rn "verser\|3a" apps/mobile/lib/widgets/ apps/mobile/lib/services/budget_living_engine.dart apps/mobile/lib/services/response_card_service.dart | grep -i "sugg\|realloc\|marge\|free"` (point de départ)
  </read_first>
  <action>Tracer le chemin exact : surface Mon Argent/futur → widget → service qui calcule le montant suggéré depuis la marge libre. Citer file:line dans le SUMMARY. Vérifier s'il existe PLUSIEURS sites de suggestion (home, coach cards) — D10 a été reproduit sur 2 surfaces ; tous les sites doivent être clampés.</action>
  <acceptance_criteria>
    - Site(s) cités file:line avec le calcul actuel reproduit (valeur 1541 retrouvée par calcul statique sur le profil Marc ou équivalent).
  </acceptance_criteria>
  <verify>
    <automated>grep -rn "marge\|monthlyFree" apps/mobile/lib/services/budget_living_engine.dart | head -5</automated>
  </verify>
  <done>Diagnostic déterministe — pas de fix au hasard.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Clamp au plafond légal restant</name>
  <files>apps/mobile/lib/services/budget_living_engine.dart (ou site réel localisé), apps/mobile/test/services/suggestion_3a_cap_test.dart</files>
  <read_first>
    - Le(s) site(s) de la Task 1
    - apps/mobile/lib/services/financial_core/tax_calculator.dart:540-560 (annualCeiling)
  </read_first>
  <behavior>
    - Test (RED) : marge libre 1541/mois, plafond 7258, déjà versé 0 → suggestion ≤ 7258/12 ≈ 604/mois (ou plafond restant / mois restants de l'année si le moteur est calendaire — suivre la sémantique existante).
    - Déjà versé 7258 → suggestion 3a = 0 (et la marge restante n'est pas perdue : la suggestion peut mentionner d'autres véhicules SANS promesse — pas de « meilleur placement »).
    - Indépendant sans LPP → clamp sur SON plafond (net×0.20 ≤ 36288), pas 7258.
  </behavior>
  <action>Au(x) site(s) localisé(s) : `suggestion = min(margeDisponible, plafondRestant / moisRestants)` où plafondRestant = annualCeiling (canonique, archétype-aware post-plans 04/08) − contributions 3a de l'année connues du profil. Aucun nouveau string nécessaire si le montant seul change ; si une mention du plafond est ajoutée, clé ARB ×6 + lints (et dans ce cas vérifier la non-collision de vague avec le plan 15 — pas de fichier ARB partagé en wave 12 : si ARB requis, le déplacer en wave 13 en le notant au SUMMARY).</action>
  <acceptance_criteria>
    - `cd apps/mobile && flutter test test/services/suggestion_3a_cap_test.dart` exit 0.
    - Oracle D10 re-run sur sim : profil Marc-like → suggestion ≤ 605/mois, capture `.planning/_walker/illogism-fixes/w4/` citée.
  </acceptance_criteria>
  <verify>
    <automated>cd apps/mobile && flutter test test/services/suggestion_3a_cap_test.dart && flutter analyze</automated>
  </verify>
  <done>D10 fermé : suggestion mensuelle ×12 ≤ plafond légal, prouvé device.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries
| Boundary | Description |
|----------|-------------|
| moteur de suggestion → action utilisateur | suggérer un versement illégal (2.4× plafond) = conseil faux, risque fiscal utilisateur |

## STRIDE Threat Register
| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-ILF-14-01 | Tampering (intégrité du conseil) | suggestion 3a | mitigate | clamp plafond canonique + test + device-proof |
</threat_model>

<verification>
- `cd apps/mobile && flutter analyze && flutter test` exit 0 ; device-proof D10 inversé.
</verification>

<success_criteria>
- D10 fermé avec citation + capture.
</success_criteria>

<output>
Create `.planning/phases/mint-illogism-fixes/mint-illogism-fixes-14-SUMMARY.md` + mise à jour VALIDATION.md Per-Task Map.
</output>
