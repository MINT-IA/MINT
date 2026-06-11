---
phase: mint-illogism-fixes
plan: 10
type: execute
wave: 8
depends_on: [mint-illogism-fixes-09]
files_modified:
  - apps/mobile/lib/screens/arbitrage/rente_vs_capital_screen.dart
  - apps/mobile/lib/l10n/app_fr.arb
  - apps/mobile/lib/l10n/app_en.arb
  - apps/mobile/lib/l10n/app_de.arb
  - apps/mobile/lib/l10n/app_es.arb
  - apps/mobile/lib/l10n/app_it.arb
  - apps/mobile/lib/l10n/app_pt.arb
  - apps/mobile/test/screens/rente_vs_capital_defaults_test.dart
autonomous: true
requirements:
  - MATRIX-D5
must_haves:
  truths:
    - "RenteVsCapitalScreen n'a PLUS de défauts fiction (age '50', salaire '100000', LPP '350000' ; mode certificat 500000/150000/37000) : état vide explicite OU valeur profil taguée « estimé » via ProfileDataSource."
    - "Un indépendant sans LPP n'obtient plus « Capital estimé à 65 ans ~812'886 » sur une LPP fantôme (D5)."
    - "Le flow Maestro bug__ILLOG01__rvc_fiction_defaults.yaml passe GREEN (était OPEN-RED, gated par ILLOG02 — désormais débloqué par le plan 09)."
  artifacts:
    - path: "apps/mobile/test/screens/rente_vs_capital_defaults_test.dart"
      provides: "Tests : sans profil → état vide ; avec profil estimé → valeurs taguées hasEstimates"
      min_lines: 40
  key_links:
    - from: "apps/mobile/lib/screens/arbitrage/rente_vs_capital_screen.dart"
      to: "_autoFillFromProfile / ProfileDataSource"
      via: "seul chemin d'alimentation des champs (plus de constantes inline)"
      pattern: "_autoFillFromProfile|hasEstimates"
---

<objective>
W3 — Tuer les défauts fiction de RvC : les constantes hardcodées `rente_vs_capital_screen.dart:62-66` contournent `ProfileDataSource` (`hasEstimates` seulement sur prefill réel via `_autoFillFromProfile` :180-215) et rendent la fiction indiscernable d'un prefill réel. Device-prouvé D5 : indépendant sans LPP (seed) → « Capital estimé à 65 ans ~812'886 » sur LPP fantôme. États autorisés (lock CONTEXT W3) : état vide explicite OU valeur profil taguée.

Purpose: ferme D5 + le gate ILLOG-01.
Output: défauts supprimés + état vide localisé + flow ILLOG01 GREEN.
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/reports/MATRIX-illogismes-2026-06-09.md (annexe D5 + rétractation « âge prérempli » : le défaut '50' coïncidait avec l'âge des profils de test)
@tools/simulator/flows/regression/bug__ILLOG01__rvc_fiction_defaults.yaml

<interfaces>
Sites : rente_vs_capital_screen.dart:62-66 (défauts hardcodés age '50'/salaire '100000'/LPP '350000' + mode certificat 500000/150000/37000) ; :180-215 (`_autoFillFromProfile`, flag `hasEstimates` existant — le mécanisme correct que les défauts bypassent).
Post-plan 07 : un indépendant/divorcé sans valeur réelle n'a PAS d'avoir estimé — l'écran doit gérer ce cas (état vide, pas de fiction de remplacement).
SOT §4 : ProfileDataSource (estimated=0.25).
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Supprimer les défauts fiction — état vide explicite ou prefill tagué</name>
  <files>apps/mobile/lib/screens/arbitrage/rente_vs_capital_screen.dart, apps/mobile/lib/l10n/app_*.arb, apps/mobile/test/screens/rente_vs_capital_defaults_test.dart</files>
  <read_first>
    - apps/mobile/lib/screens/arbitrage/rente_vs_capital_screen.dart:40-230 (défauts + _autoFillFromProfile + hasEstimates)
    - Ligne matrice D5 + flow bug__ILLOG01 (assertions exactes à satisfaire)
    - SOT.md §4 (ProfileDataSource)
  </read_first>
  <behavior>
    - Test (RED) : écran ouvert SANS profil utilisable → aucun champ prérempli avec 50/100000/350000 ; un état vide localisé invite à compléter le profil ou saisir les valeurs.
    - Avec profil réel → prefill via _autoFillFromProfile, valeurs estimées affichées avec le tag « estimé » (hasEstimates).
    - Indépendant sans LPP (post-plan 07) → PAS de capital LPP projeté sur avoir fantôme.
  </behavior>
  <action>Supprimer les constantes :62-66 (les deux jeux : standard ET mode certificat). L'unique chemin d'alimentation devient `_autoFillFromProfile` (ProfileDataSource). Sans donnée : état vide explicite (nouvelle clé ARB ×6, FR accents corrects, pas de terme banni — formulation type « Complète ton profil ou saisis tes valeurs pour simuler ») avec champs vides éditables. Avec estimation : badge « estimé » (réutiliser le pattern Mon Argent>Prévoyance). Garder le calcul intact — seul le sourcing des inputs change (Karpathy #3).</action>
  <acceptance_criteria>
    - `grep -n "'50'\|100000\|350000\|500000\|150000\|37000" apps/mobile/lib/screens/arbitrage/rente_vs_capital_screen.dart` → 0 défaut inline restant (hors tests/constantes légitimes d'une autre sémantique — justifier chaque survivant).
    - `cd apps/mobile && flutter test test/screens/rente_vs_capital_defaults_test.dart` exit 0.
    - `python3 tools/checks/accent_lint_fr.py` exit 0 + `validate_arb_parity()` OK.
  </acceptance_criteria>
  <verify>
    <automated>cd apps/mobile && flutter test test/screens/rente_vs_capital_defaults_test.dart && flutter analyze</automated>
  </verify>
  <done>Plus de fiction indiscernable du réel sur RvC.</done>
</task>

<task type="auto">
  <name>Task 2: Gate mécanique — flow ILLOG01 GREEN + panel design</name>
  <files>tools/simulator/flows/regression/bug__ILLOG01__rvc_fiction_defaults.yaml (lecture/ajustement d'assertions si l'état vide change les labels attendus)</files>
  <read_first>
    - tools/simulator/flows/regression/bug__ILLOG01__rvc_fiction_defaults.yaml + _INDEX.md (convention D-36)
    - .planning/phases/mint-illogism-fixes/mint-illogism-fixes-RESEARCH.md §1.4 (build workaround)
  </read_first>
  <action>Build sim, reboot sim (mitigation crash), `maestro test tools/simulator/flows/regression/bug__ILLOG01__rvc_fiction_defaults.yaml` → GREEN. Si le fix a changé les labels attendus, ajuster le flow en conservant son INTENTION (détecter la fiction) — documenter tout ajustement dans _INDEX.md. RvC étant un écran modifié : panel design 4-personnes AVANT push (feedback_design_panel_before_push), verdicts cités.</action>
  <acceptance_criteria>
    - `maestro test tools/simulator/flows/regression/bug__ILLOG01__rvc_fiction_defaults.yaml` exit 0 (sortie citée).
    - `maestro test tools/simulator/flows/regression/bug__ILLOG02__rvc_ax_tree_empty.yaml` exit 0 (non-régression du plan 09).
    - Panel design 4-personnes exécuté, fixes critiques appliqués.
    - Capture device de l'état vide sous `.planning/_walker/illogism-fixes/w3/`.
  </acceptance_criteria>
  <verify>
    <automated>maestro test tools/simulator/flows/regression/bug__ILLOG01__rvc_fiction_defaults.yaml && maestro test tools/simulator/flows/regression/bug__ILLOG02__rvc_ax_tree_empty.yaml</automated>
  </verify>
  <done>D5 + ILLOG-01 fermés : les deux flows régression GREEN cités (gate du CONTEXT acceptance_contract).</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries
| Boundary | Description |
|----------|-------------|
| défauts UI → décision utilisateur | une projection sur données fictives présentée comme réelle = intégrité + LSFin |

## STRIDE Threat Register
| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-ILF-10-01 | Tampering (intégrité) | défauts fiction RvC | mitigate | suppression + ProfileDataSource seul chemin + flow régression permanent |
</threat_model>

<verification>
- Flows ILLOG01 + ILLOG02 GREEN ; `flutter analyze && flutter test` exit 0 ; lints ARB.
</verification>

<success_criteria>
- D5/ILLOG-01 fermés avec citations flow + capture.
</success_criteria>

<output>
Create `.planning/phases/mint-illogism-fixes/mint-illogism-fixes-10-SUMMARY.md` + mise à jour VALIDATION.md Per-Task Map.
</output>
