---
phase: mint-illogism-fixes
plan: 17
type: execute
wave: 14
depends_on: [mint-illogism-fixes-16]
files_modified:
  - apps/mobile/lib/screens/mariage_screen.dart
  - apps/mobile/lib/screens/explore/explorer_screen.dart
  - apps/mobile/lib/widgets/coach/coach_packet_insight_card.dart
  - apps/mobile/lib/app.dart
  - apps/mobile/lib/l10n/app_fr.arb
  - apps/mobile/lib/l10n/app_en.arb
  - apps/mobile/lib/l10n/app_de.arb
  - apps/mobile/lib/l10n/app_es.arb
  - apps/mobile/lib/l10n/app_it.arb
  - apps/mobile/lib/l10n/app_pt.arb
  - apps/mobile/test/screens/mariage_whatif_labels_test.dart
autonomous: true
requirements:
  - MATRIX-D9
  - MATRIX-D11
  - MATRIX-W5-i18n-hardcode
must_haves:
  truths:
    - "L'écran Mariage n'invente plus un conjoint fictif présenté comme un fait : « Revenu 2 : 60'000 » et « Pénalité +1'407/an » sont étiquetés hypothèses ÉDITABLES de l'outil what-if pour un profil sans état civil (D9)."
    - "Plus de clés brutes en labels a11y : « coach-context-point-de-depart » (coach_packet_insight_card.dart:18) et « ouvrir-profil-drawer » (explorer_screen.dart:29) remplacés par des labels localisés (D11)."
    - "« Document non disponible » (app.dart:1210) passe par AppLocalizations (NEVER #1)."
    - "Walkthrough sim de clôture de phase : les 5 vagues device-proofées."
  artifacts:
    - path: "apps/mobile/test/screens/mariage_whatif_labels_test.dart"
      provides: "Tests : profil sans état civil → hypothèses étiquetées + éditables sur l'écran mariage"
      min_lines: 30
  key_links:
    - from: "apps/mobile/lib/app.dart:1210"
      to: "AppLocalizations"
      via: "clé documentNonDisponible"
      pattern: "AppLocalizations"
---

<objective>
W5 — Surfaces honnêtes (hygiène strings/labels, dernière vague) : (1) D9 — l'écran Mariage fabrique un conjoint fictif pour un profil sans état civil ; un outil what-if a le droit d'hypothèses, pas de les présenter comme des faits : étiqueter + rendre éditables ; (2) D11 — fuites de clés brutes en labels a11y ; (3) « Document non disponible » hardcodé. Clôture de phase avec walkthrough complet.

Purpose: ferme D9, D11, le hardcodé i18n W5 — et termine la phase.
Output: what-if étiqueté + labels localisés + i18n conforme + device-proof final.
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/reports/MATRIX-illogismes-2026-06-09.md (D9, D11)

<interfaces>
Sites (vérifiés par grep) : explorer_screen.dart:29 `label: 'ouvrir-profil-drawer'` · coach_packet_insight_card.dart:18 `label: 'coach-context-point-de-depart'` · app.dart:1210 « Document non disponible ». Mariage : mariage_screen (le « Revenu 2 : 60'000 » + « Pénalité +1'407/an » de D9 — post-plan 06 l'état civil est demandé à l'onboarding, donc « état civil inconnu » devient rare mais reste possible pour les profils existants).
Post-plan 11 : pattern d'étiquetage « hypothèse » disponible — réutiliser.
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Mariage what-if — hypothèses étiquetées éditables (D9)</name>
  <files>apps/mobile/lib/screens/mariage_screen.dart, apps/mobile/lib/l10n/app_*.arb, apps/mobile/test/screens/mariage_whatif_labels_test.dart</files>
  <read_first>
    - apps/mobile/lib/screens/mariage_screen.dart (sites du Revenu 2 par défaut et du calcul de pénalité — localiser les valeurs 60000 et le rendu « Pénalité »)
    - Ligne matrice D9 + pattern « hypothèse » du plan 11
  </read_first>
  <behavior>
    - Test : profil sans conjoint connu → le « Revenu 2 » porte une étiquette hypothèse (clé ARB) et est un champ éditable ; la « pénalité » est présentée comme résultat du scénario saisi, pas comme un fait du profil.
    - Profil avec conjoint réel → valeurs réelles sans étiquette hypothèse.
  </behavior>
  <action>Étiqueter les défauts what-if de mariage_screen (réutiliser le widget/pattern « hypothèse » du plan 11 ; clés ARB ×6, formulation type « Hypothèse modifiable », accents, pas de termes bannis). Ne PAS supprimer la capacité what-if (c'est un outil de scénario légitime) — la rendre honnête. Écran modifié → panel design 4-personnes AVANT push.</action>
  <acceptance_criteria>
    - `cd apps/mobile && flutter test test/screens/mariage_whatif_labels_test.dart` exit 0.
    - Oracle D9 re-run sur sim : profil sans état civil → hypothèses visiblement étiquetées, capture citée.
    - `accent_lint_fr` exit 0 + `validate_arb_parity` + `check_banned_terms` clean ; panel design verdicts cités.
  </acceptance_criteria>
  <verify>
    <automated>cd apps/mobile && flutter test test/screens/mariage_whatif_labels_test.dart && flutter analyze</automated>
  </verify>
  <done>D9 fermé : l'outil what-if déclare ses hypothèses.</done>
</task>

<task type="auto">
  <name>Task 2: Labels a11y localisés + i18n hardcodé + walkthrough final de phase</name>
  <files>apps/mobile/lib/screens/explore/explorer_screen.dart, apps/mobile/lib/widgets/coach/coach_packet_insight_card.dart, apps/mobile/lib/app.dart, apps/mobile/lib/l10n/app_*.arb</files>
  <read_first>
    - explorer_screen.dart:25-35 · coach_packet_insight_card.dart:14-22 · app.dart:1205-1215
    - Ligne matrice D11
  </read_first>
  <action>(1) Remplacer les labels Semantics bruts par des clés AppLocalizations descriptives (ex. semantics « Ouvrir le profil », « Point de départ du contexte coach » — formulation FR exacte à la discrétion, accents corrects). (2) app.dart:1210 → `AppLocalizations.of(context)!.documentNonDisponible` (clé ARB ×6 + `flutter gen-l10n`). (3) Balayage final : `grep -rn "label: '[a-z-]*-[a-z-]*'" apps/mobile/lib/` pour débusquer d'autres clés brutes du même pattern — corriger celles trouvées (même cause racine). (4) Walkthrough sim de CLÔTURE DE PHASE : re-jouer les oracles device D1-D12 (annexe matrice) et consigner le verdict par ligne dans le SUMMARY ; captures `.planning/_walker/illogism-fixes/final/`.</action>
  <acceptance_criteria>
    - `grep -rn "ouvrir-profil-drawer\|coach-context-point-de-depart" apps/mobile/lib/` → 0.
    - `grep -n "Document non disponible" apps/mobile/lib/app.dart` → 0.
    - `cd apps/mobile && flutter gen-l10n && flutter analyze && flutter test` exit 0 ; `accent_lint_fr` + `validate_arb_parity` OK.
    - Flows `maestro test tools/simulator/flows/regression/bug__ILLOG01__rvc_fiction_defaults.yaml` et `bug__ILLOG02__rvc_ax_tree_empty.yaml` GREEN (gate de phase, re-run final).
    - Tableau D1-D12 re-vérifié sur sim avec verdict par ligne + captures citées (0-TRUST : la phase ne se déclare pas fermée sur tests verts).
  </acceptance_criteria>
  <verify>
    <automated>cd apps/mobile && flutter gen-l10n && flutter analyze && flutter test && python3 tools/checks/accent_lint_fr.py</automated>
    <human-check>Captures final/ : D1-D12 re-joués, verdicts consignés</human-check>
  </verify>
  <done>D11 + i18n fermés ; phase device-proofée de bout en bout, flows ILLOG01/02 GREEN cités.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries
| Boundary | Description |
|----------|-------------|
| what-if → perception utilisateur | hypothèse présentée comme fait = intégrité de présentation |
| labels a11y → technologies d'assistance | clés brutes = surface inutilisable VoiceOver |

## STRIDE Threat Register
| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-ILF-17-01 | Tampering (présentation) | conjoint fictif mariage | mitigate | étiquette hypothèse + champ éditable + test |
| T-ILF-17-02 | Denial of service (a11y) | labels bruts | mitigate | clés localisées + grep-gate |
</threat_model>

<verification>
- Suite complète + lints + flows ILLOG01/02 GREEN + tableau D1-D12 re-vérifié sim.
</verification>

<success_criteria>
- D9, D11, i18n fermés ; phase entière device-proofée (acceptance ROADMAP : chaque ligne fermée = oracle re-run vert + device-proof + aucun claim sans citation).
</success_criteria>

<output>
Create `.planning/phases/mint-illogism-fixes/mint-illogism-fixes-17-SUMMARY.md` + mise à jour VALIDATION.md Per-Task Map + rapport HTML `.planning/phases/mint-illogism-fixes/mint-illogism-fixes-VERIFICATION-REPORT.html` (règle mémoire feedback_html_evidence_report).
</output>
