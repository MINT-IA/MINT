---
phase: mint-illogism-fixes
plan: 09
type: execute
wave: 7
depends_on: [mint-illogism-fixes-05]
files_modified:
  - apps/mobile/lib/screens/arbitrage/rente_vs_capital_screen.dart
  - apps/mobile/test/screens/rente_vs_capital_semantics_test.dart
autonomous: true
requirements:
  - MATRIX-D6
must_haves:
  truths:
    - "L'arbre AX de RenteVsCapitalScreen est peuplé : chaque valeur financière, slider et CTA de l'écran est exposé aux technologies d'assistance (plus d'écran à 1 élément idb)."
    - "Le flow Maestro bug__ILLOG02__rvc_ax_tree_empty.yaml passe GREEN (était OPEN-RED, reproduit froid+chaud)."
    - "Les assertions Maestro sur cet écran deviennent possibles — débloque le gate du plan 11 (ILLOG-01, dépendance inter-vagues explicite)."
  artifacts:
    - path: "apps/mobile/test/screens/rente_vs_capital_semantics_test.dart"
      provides: "Test SemanticsTester : l'arbre contient les nœuds attendus (titres, valeurs, CTA)"
      min_lines: 30
  key_links:
    - from: "tools/simulator/flows/regression/bug__ILLOG02__rvc_ax_tree_empty.yaml"
      to: "apps/mobile/lib/screens/arbitrage/rente_vs_capital_screen.dart"
      via: "assertions Maestro sur les labels rendus"
      pattern: "assertVisible"
---

<objective>
W5/ILLOG-02 (P1, exécuté TÔT) — `RenteVsCapitalScreen` rend les pixels mais son arbre accessibilité est (quasi) vide : triangulé Maestro (assert fail sur écran visible) + idb (1 élément) + screenshot, reproduit froid+chaud. Tant que l'arbre AX est vide, AUCUNE assertion Maestro ne peut tourner sur cet écran — ce plan débloque mécaniquement le gate ILLOG-01 du plan 11 (dépendance inter-vagues du CONTEXT).

CONTRAINTE de parallélisme : ce plan ne touche AUCUN fichier ARB (réutiliser les strings localisées existantes comme labels sémantiques) — il tourne en parallèle du plan 07.

Purpose: ferme D6 / ILLOG-02.
Output: arbre AX peuplé + test Semantics + flow GREEN.
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/reports/MATRIX-illogismes-2026-06-09.md (annexe D6)
@tools/simulator/flows/regression/bug__ILLOG02__rvc_ax_tree_empty.yaml
@tools/simulator/flows/regression/_INDEX.md

<interfaces>
Écran : apps/mobile/lib/screens/arbitrage/rente_vs_capital_screen.dart (défauts :62-66 et _autoFillFromProfile :180-215 appartiennent au plan 11 — NE PAS y toucher ici, fichier partagé en waves successives).
Repro device : run ~/.maestro/tests/2026-06-11_065259 ; flow bug__ILLOG02 OPEN-RED.
Causes plausibles d'un arbre AX vide avec pixels OK : ExcludeSemantics / BlockSemantics ancestral, CustomPaint sans Semantics, RepaintBoundary+Opacity mal composés, `Semantics(container:)` manquant sur du contenu canvas, ou un package de chart qui peint sans nœuds sémantiques.
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Diagnostiquer la cause racine de l'arbre AX vide</name>
  <files>apps/mobile/lib/screens/arbitrage/rente_vs_capital_screen.dart (lecture + instrumentation temporaire)</files>
  <read_first>
    - apps/mobile/lib/screens/arbitrage/rente_vs_capital_screen.dart (intégralité — chercher ExcludeSemantics/BlockSemantics/CustomPaint/charts)
    - Ligne matrice D6 (triangulation exacte)
  </read_first>
  <action>Reproduire d'abord : widget test avec `SemanticsTester` (flutter_test) qui dump l'arbre sémantique de l'écran — confirmer le quasi-vide en environnement de test (pas seulement sim). Identifier le widget ancêtre qui supprime/omet les nœuds. Documenter la cause racine (file:line) dans le SUMMARY avant de fixer. Si la cause est dans un widget partagé (hors RvC), STOP et le signaler — le scope fichier de ce plan devra être étendu explicitement.</action>
  <acceptance_criteria>
    - Cause racine identifiée et citée `file:line` (pas de fix au hasard).
    - Test SemanticsTester RED committé reproduisant l'arbre vide.
  </acceptance_criteria>
  <verify>
    <automated>cd apps/mobile && flutter test test/screens/rente_vs_capital_semantics_test.dart 2>&1 | tail -5</automated>
  </verify>
  <done>Diagnostic déterministe en place (RED reproductible hors sim).</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Fix Semantics + flow ILLOG02 GREEN</name>
  <files>apps/mobile/lib/screens/arbitrage/rente_vs_capital_screen.dart, apps/mobile/test/screens/rente_vs_capital_semantics_test.dart</files>
  <read_first>
    - Le diagnostic Task 1
    - tools/simulator/flows/regression/bug__ILLOG02__rvc_ax_tree_empty.yaml (les assertions exactes que le fix doit satisfaire)
  </read_first>
  <behavior>
    - Test SemanticsTester GREEN : l'arbre contient des nœuds pour le titre de l'écran, les valeurs rente/capital affichées et les contrôles interactifs.
    - Les labels sémantiques réutilisent les strings AppLocalizations DÉJÀ rendues visuellement (pas de nouvelle clé ARB dans ce plan).
  </behavior>
  <action>Corriger la cause racine (retirer/scoper l'ExcludeSemantics fautif, ou ajouter `Semantics(label:, value:)`/`MergeSemantics` sur les blocs peints sans nœuds). Pas de sur-ingénierie : exposer ce qui est visible, rien de plus (Karpathy #2). Puis : build sim (workaround `/tmp/mint_build_ios`), `maestro test tools/simulator/flows/regression/bug__ILLOG02__rvc_ax_tree_empty.yaml` → GREEN, froid ET chaud (la repro D6 était froid+chaud ; redémarrer le sim avant le run froid — règle sim-crash mitigation).</action>
  <acceptance_criteria>
    - `cd apps/mobile && flutter test test/screens/rente_vs_capital_semantics_test.dart` exit 0.
    - `maestro test tools/simulator/flows/regression/bug__ILLOG02__rvc_ax_tree_empty.yaml` exit 0 (sortie citée — gate mécanique du CONTEXT).
    - `idb ui describe-all` sur l'écran RvC montre > 5 éléments (citation snapshot dans le SUMMARY).
    - `git diff --stat` ne montre AUCUN fichier ARB modifié (contrainte de parallélisme wave 7).
  </acceptance_criteria>
  <verify>
    <automated>cd apps/mobile && flutter test test/screens/rente_vs_capital_semantics_test.dart && flutter analyze</automated>
  </verify>
  <done>D6/ILLOG-02 fermé : flow GREEN cité, arbre AX peuplé, gate Maestro du plan 11 débloqué.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries
| Boundary | Description |
|----------|-------------|
| écran → technologies d'assistance | un écran financier muet pour VoiceOver = exclusion d'utilisateurs + invérifiabilité Maestro |

## STRIDE Threat Register
| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-ILF-09-01 | Denial of service (a11y) | arbre AX RvC | mitigate | Semantics + test SemanticsTester permanent + flow régression |
| T-ILF-09-02 | Information disclosure | labels sémantiques | accept | n'exposent que ce qui est déjà visible à l'écran |
</threat_model>

<verification>
- `cd apps/mobile && flutter analyze && flutter test` exit 0 ; flow ILLOG02 GREEN froid+chaud.
</verification>

<success_criteria>
- D6 fermé ; plan 11 (ILLOG-01) exécutable.
</success_criteria>

<output>
Create `.planning/phases/mint-illogism-fixes/mint-illogism-fixes-09-SUMMARY.md` + mise à jour VALIDATION.md Per-Task Map.
</output>
