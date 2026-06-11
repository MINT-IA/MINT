---
phase: mint-illogism-fixes
plan: 06
type: execute
wave: 6
depends_on: [mint-illogism-fixes-05]
files_modified:
  - apps/mobile/lib/screens/onboarding/mvp_wedge/onboarding_shell_screen.dart
  - apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_statut_emploi.dart
  - apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_etat_civil.dart
  - apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_lacunes_avs.dart
  - apps/mobile/lib/l10n/app_fr.arb
  - apps/mobile/lib/l10n/app_en.arb
  - apps/mobile/lib/l10n/app_de.arb
  - apps/mobile/lib/l10n/app_es.arb
  - apps/mobile/lib/l10n/app_it.arb
  - apps/mobile/lib/l10n/app_pt.arb
autonomous: true
requirements:
  - MATRIX-D1
must_haves:
  truths:
    - "L'onboarding /onb demande le statut d'emploi (salarié / indépendant / sans activité), l'état civil (incl. divorcé) et les lacunes AVS (années à l'étranger)."
    - "Les réponses peuplent les clés wizard EXISTANTES (q_employment_status, q_civil_status, q_avs_lacunes_status, q_avs_arrival_year) déjà lues par coach_profile.dart:2667-2827 — aucun nouveau champ de schéma."
    - "Les réponses sont stockées via SecureWizardStore (chiffré) et n'apparaissent JAMAIS dans les logs ni l'analytics (PII : état civil, statut)."
    - "Toutes les nouvelles strings passent par AppLocalizations (6 ARB, accents FR stricts, zéro terme banni)."
  artifacts:
    - path: "apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_statut_emploi.dart"
      provides: "Scène statut d'emploi (pattern MintScene* existant)"
      min_lines: 40
    - path: "apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_etat_civil.dart"
      provides: "Scène état civil (CoachCivilStatus incl. divorce)"
      min_lines: 40
    - path: "apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_lacunes_avs.dart"
      provides: "Scène lacunes AVS (années à l'étranger → q_avs_arrival_year)"
      min_lines: 40
  key_links:
    - from: "apps/mobile/lib/screens/onboarding/mvp_wedge/onboarding_shell_screen.dart"
      to: "scenes statut/état civil/lacunes"
      via: "enregistrement dans le flux T1-T9"
      pattern: "MintSceneStatutEmploi|MintSceneEtatCivil|MintSceneLacunesAvs"
    - from: "scenes"
      to: "SecureWizardStore"
      via: "écriture q_employment_status / q_civil_status / q_avs_lacunes_status / q_avs_arrival_year"
      pattern: "q_employment_status"
---

<objective>
W2 — Vérité d'archétype : ajouter à l'onboarding les 3 questions qui rendent l'archétype connaissable (statut d'emploi, état civil, lacunes AVS). Le plumbing aval existe ENTIÈREMENT (clés q_* lues par coach_profile, schéma backend SOT §1) — ce plan ajoute uniquement les étapes UI qui peuplent des champs déjà câblés. C'est la racine D1 des ~10 ILLOGICAL_FOR_ARCHETYPE.

Purpose: sans ces réponses, MINT présume « salarié-avec-LPP marié-jamais-divorcé carrière-complète » (NEVER #7).
Output: 3 scènes wedge + shell mis à jour + ARB ×6.
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/mint-illogism-fixes/mint-illogism-fixes-CONTEXT.md (W2)
@.claude/skills/mint-flutter-dev/SKILL.md (MintUI kit, GoRouter, Provider, checklist écran)

<interfaces>
Clés wizard déjà lues (vérifié) : coach_profile.dart:2667-2668 `q_civil_status`/`q_civil_status_choice` · :2702 `q_employment_status` · :2801 `q_avs_lacunes_status` · :2809 `q_avs_arrival_year`. Modèle : `CoachCivilStatus` incl. `divorce`.
Pattern scène : apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/ (mint_scene_3a_levier.dart, mint_scene_capacite_achat.dart, mint_scene_rente_trouee.dart, us_tax_person_screen.dart — ce dernier est le précédent exact d'une question d'archétype dans le wedge).
Stockage : SecureWizardStore (hydratation CoachProfileProvider → CoachProfile.fromWizardAnswers).
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Scènes statut d'emploi + état civil</name>
  <files>apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_statut_emploi.dart, apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_etat_civil.dart, apps/mobile/lib/l10n/app_*.arb</files>
  <read_first>
    - apps/mobile/lib/screens/onboarding/mvp_wedge/onboarding_shell_screen.dart (flux T1-T9, mécanique d'enregistrement des scènes et d'écriture SecureWizardStore)
    - apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/us_tax_person_screen.dart (précédent exact : question d'archétype)
    - apps/mobile/lib/models/coach_profile.dart:2667-2710 (valeurs attendues EXACTES par le parser pour q_employment_status et q_civil_status — utiliser ces valeurs, ne pas en inventer)
  </read_first>
  <behavior>
    - Widget test : sélectionner « indépendant » écrit q_employment_status avec la valeur exacte que coach_profile.dart:2702 parse ; sélectionner « divorcé » écrit q_civil_status parsé en CoachCivilStatus.divorce.
    - Smoke test par scène (Scaffold render + tap chaque option).
  </behavior>
  <action>Créer 2 scènes suivant le pattern us_tax_person_screen : statut d'emploi (3 options : salarié / indépendant / sans activité) et état civil (options du modèle CoachCivilStatus, incl. divorcé). Strings via AppLocalizations uniquement (6 ARB, `flutter gen-l10n`), formulation FR avec accents corrects, AUCUN terme banni (vérifier via `check_banned_terms`). MintColors/MintUI kit. Les valeurs écrites doivent matcher EXACTEMENT ce que fromWizardAnswers parse (lire d'abord). Pas de framing retraite (NEVER #4) : formuler en « ta situation », pas « ta retraite ».</action>
  <acceptance_criteria>
    - `grep -rn "Text('" apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_statut_emploi.dart mint_scene_etat_civil.dart` → 0 string user-facing hardcodée.
    - `python3 tools/checks/accent_lint_fr.py` exit 0 ; `validate_arb_parity()` OK (6 langues).
    - `cd apps/mobile && flutter test test/screens/` exit 0 (widget tests des 2 scènes verts).
  </acceptance_criteria>
  <verify>
    <automated>cd apps/mobile && flutter gen-l10n && flutter analyze && flutter test test/screens/</automated>
  </verify>
  <done>2 scènes fonctionnelles écrivant les clés q_* exactes.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Scène lacunes AVS + intégration au flux + panel design</name>
  <files>apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_lacunes_avs.dart, apps/mobile/lib/screens/onboarding/mvp_wedge/onboarding_shell_screen.dart, apps/mobile/lib/l10n/app_*.arb</files>
  <read_first>
    - apps/mobile/lib/models/coach_profile.dart:2801-2827 (parsing exact q_avs_lacunes_status + q_avs_arrival_year) et :1511 (dérivation arrivalAge)
    - apps/mobile/lib/screens/onboarding/mvp_wedge/onboarding_shell_screen.dart (ordre du flux)
  </read_first>
  <behavior>
    - Widget test : répondre « oui, X années à l'étranger / arrivé en YYYY » écrit q_avs_lacunes_status + q_avs_arrival_year parsables par :2809.
    - Test d'intégration shell : le flux T1-T9 inclut les 3 nouvelles scènes dans un ordre logique (statut → état civil → lacunes) sans casser les scènes existantes.
  </behavior>
  <action>Créer la scène lacunes AVS (question : années passées hors de Suisse → année d'arrivée), l'enregistrer avec les 2 autres dans onboarding_shell_screen. AVANT push : exécuter le panel design 4-personnes (UX + a11y + adversarial + engineering/wiring — règle mémoire feedback_design_panel_before_push, aucune exception) sur les 3 scènes et appliquer les fixes critiques. Verdicts du panel cités dans le SUMMARY.</action>
  <acceptance_criteria>
    - Le flux /onb contient les 3 questions (test d'intégration vert).
    - Panel design 4-personnes exécuté AVANT push — 4 verdicts cités dans le SUMMARY, fixes critiques appliqués.
    - `grep -rn "q_employment_status\|q_civil_status\|q_avs_lacunes_status" apps/mobile/lib/screens/onboarding/mvp_wedge/` ≥ 3 sites d'écriture.
    - Aucune des nouvelles réponses n'apparaît dans un appel de log/analytics : `grep -rn "q_civil_status\|q_employment_status" apps/mobile/lib/ | grep -i "log\|analytic\|sentry"` → 0.
    - Device-proof : walkthrough sim /onb complet, capture des 3 nouvelles scènes sous `.planning/_walker/illogism-fixes/w2/`.
  </acceptance_criteria>
  <verify>
    <automated>cd apps/mobile && flutter analyze && flutter test && python3 tools/checks/accent_lint_fr.py</automated>
  </verify>
  <done>D1 fermé : l'onboarding établit la vérité d'archétype ; les 3 réponses hydratent CoachProfile via les clés existantes (preuve : coach profile post-onboarding reflète indépendant/divorcé/lacunes).</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries
| Boundary | Description |
|----------|-------------|
| saisie utilisateur → SecureWizardStore | PII sensible (état civil, statut d'emploi, années à l'étranger) |
| store → logs/analytics | fuite PII interdite |

## STRIDE Threat Register
| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-ILF-06-01 | Information disclosure | nouvelles réponses onboarding | mitigate | SecureWizardStore chiffré uniquement ; grep-gate zéro log/analytics sur les clés q_* (critère d'acceptation) |
| T-ILF-06-02 | Spoofing | aucune surface auth touchée | accept | scènes purement locales, pas de nouvel endpoint |
</threat_model>

<verification>
- `cd apps/mobile && flutter analyze && flutter test` + `accent_lint_fr` + `validate_arb_parity` + `check_banned_terms` sur les nouvelles strings.
- Walkthrough sim /onb (captures w2/).
</verification>

<success_criteria>
- D1 fermé avec device-proof ; les plans 07-08 disposent de la vérité d'archétype en entrée.
</success_criteria>

<output>
Create `.planning/phases/mint-illogism-fixes/mint-illogism-fixes-06-SUMMARY.md` + mise à jour VALIDATION.md Per-Task Map.
</output>
