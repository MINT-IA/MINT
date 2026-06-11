---
phase: mint-illogism-fixes
plan: 16
type: execute
wave: 13
depends_on: [mint-illogism-fixes-11]
files_modified:
  - apps/mobile/lib/screens/coach/retirement_dashboard_screen.dart
  - apps/mobile/lib/l10n/app_fr.arb
  - apps/mobile/lib/l10n/app_en.arb
  - apps/mobile/lib/l10n/app_de.arb
  - apps/mobile/lib/l10n/app_es.arb
  - apps/mobile/lib/l10n/app_it.arb
  - apps/mobile/lib/l10n/app_pt.arb
  - apps/mobile/test/screens/retirement_dashboard_profile_test.dart
autonomous: true
requirements:
  - MATRIX-D7
  - MATRIX-D8
must_haves:
  truths:
    - "Le tableau retraite lit le MÊME profil que /home : fin de la contradiction « 43'691 Avoir LPP » (/home) vs « 4 infos suffisent » (/retraite) dans la même minute (D7)."
    - "Le CTA « Commencer — 2 min » mène à un parcours qui pose RÉELLEMENT des questions (les scènes d'onboarding du plan 06 ou le formulaire profil), plus jamais vers le home coach sans formulaire (D8, CTA mort)."
    - "L'état vide du tableau n'apparaît QUE si le profil est réellement vide (cohérent avec les 3 états du plan 11)."
  artifacts:
    - path: "apps/mobile/test/screens/retirement_dashboard_profile_test.dart"
      provides: "Tests : profil hydraté → dashboard peuplé ; profil vide → CTA vers parcours réel"
      min_lines: 30
  key_links:
    - from: "apps/mobile/lib/screens/coach/retirement_dashboard_screen.dart"
      to: "CoachProfileProvider (le provider que /home lit)"
      via: "même source de données"
      pattern: "CoachProfileProvider"
---

<objective>
W5 — Vérité du tableau retraite : D7 prouve que /retraite ne lit pas le profil que /home lit (deux moteurs/champs) ; D8 prouve que son CTA d'état vide est mort (« Commencer — 2 min » → home coach, aucun formulaire, aucune question). Post-plan 11, /home est honnête — ce plan aligne le tableau sur la même source et re-câble le CTA vers un parcours réel.

Purpose: ferme D7 et D8.
Output: dashboard sur la source profil canonique + CTA câblé.
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/reports/MATRIX-illogismes-2026-06-09.md (D7, D8 — captures ind-home.png vs ind-projection.png, ind-proj-form.png)

<interfaces>
Écran : apps/mobile/lib/screens/coach/retirement_dashboard_screen.dart (dashboard 3 états A/B/C par confiance — cf. skill mint-flutter-dev Chantier 2). Source /home : CoachProfileProvider (hydraté SecureWizardStore).
Post-plan 06 : le parcours de questions EXISTE (/onb scènes statut/état civil/lacunes) — cible naturelle du CTA.
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Diagnostiquer la divergence de source (D7)</name>
  <files>aucune modification — diagnostic</files>
  <read_first>
    - apps/mobile/lib/screens/coach/retirement_dashboard_screen.dart (quelle source/provider il lit, quel prédicat déclenche « 4 infos suffisent »)
    - Le widget /home hero (source CoachProfileProvider) — comparer les deux chemins de lecture
    - Lignes matrice D7, D8
  </read_first>
  <action>Tracer pourquoi /home voit un avoir (43'691) pendant que /retraite se déclare vide : provider différent ? champ différent ? cache ? Citer file:line des deux chemins dans le SUMMARY avant fix (pas de fix au hasard). Identifier aussi la cible actuelle du CTA « Commencer — 2 min » et pourquoi elle n'affiche aucun formulaire.</action>
  <acceptance_criteria>
    - Cause racine D7 citée file:line (les deux chemins de lecture) + cause D8 (route cible du CTA).
  </acceptance_criteria>
  <verify>
    <automated>grep -n "Provider\|provider" apps/mobile/lib/screens/coach/retirement_dashboard_screen.dart | head -10</automated>
  </verify>
  <done>Diagnostic déterministe documenté.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Aligner la source + re-câbler le CTA</name>
  <files>apps/mobile/lib/screens/coach/retirement_dashboard_screen.dart, apps/mobile/lib/l10n/app_*.arb, apps/mobile/test/screens/retirement_dashboard_profile_test.dart</files>
  <read_first>
    - Le diagnostic Task 1
    - apps/mobile/lib/app.dart (routes existantes vers /onb et le formulaire profil — GoRouter, jamais Navigator.push)
  </read_first>
  <behavior>
    - Test : profil hydraté avec avoir LPP → le dashboard rend les données (plus de « 4 infos suffisent » à tort).
    - Profil réellement vide → état vide + CTA `context.go` vers le parcours de questions (route /onb ou formulaire) ; le widget cible contient des champs de saisie (testé).
    - Les 3 états de confiance A/B/C du dashboard restent cohérents avec la source unique du plan 11.
  </behavior>
  <action>Brancher le dashboard sur la même source que /home (diagnostic Task 1 — probablement CoachProfileProvider) ; corriger le prédicat d'état vide ; pointer le CTA vers le parcours réel (GoRouter). Strings nouvelles via ARB ×6 si nécessaires. Écran modifié → panel design 4-personnes AVANT push. Device-proof : re-jouer la séquence D7 exacte (même profil, /home puis /retraite dans la même minute) → cohérence ; et D8 (tap CTA → questions visibles) ; captures `.planning/_walker/illogism-fixes/w5/`.</action>
  <acceptance_criteria>
    - `cd apps/mobile && flutter test test/screens/retirement_dashboard_profile_test.dart` exit 0.
    - Oracles D7/D8 re-run sur sim : contradiction disparue + CTA mène à des questions ; captures citées.
    - `accent_lint_fr` + `validate_arb_parity` OK ; panel design exécuté, verdicts cités.
  </acceptance_criteria>
  <verify>
    <automated>cd apps/mobile && flutter test && flutter analyze && python3 tools/checks/accent_lint_fr.py</automated>
    <human-check>Captures w5/ : /home et /retraite cohérents, CTA vivant</human-check>
  </verify>
  <done>D7 + D8 fermés avec citations device.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries
| Boundary | Description |
|----------|-------------|
| surfaces → utilisateur | deux surfaces qui se contredisent dans la même minute = effondrement de confiance |

## STRIDE Threat Register
| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-ILF-16-01 | Tampering (intégrité inter-surfaces) | dashboard retraite | mitigate | source profil unique + test + device-proof |
| T-ILF-16-02 | Denial of service (CTA mort) | parcours d'entrée | mitigate | cible de route testée (widget avec champs) |
</threat_model>

<verification>
- `cd apps/mobile && flutter analyze && flutter test` + lints ; séquences D7/D8 re-jouées sur sim.
</verification>

<success_criteria>
- D7, D8 fermés avec captures citées.
</success_criteria>

<output>
Create `.planning/phases/mint-illogism-fixes/mint-illogism-fixes-16-SUMMARY.md` + mise à jour VALIDATION.md Per-Task Map.
</output>
