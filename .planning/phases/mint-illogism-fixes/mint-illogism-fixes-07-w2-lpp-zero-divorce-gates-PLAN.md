---
phase: mint-illogism-fixes
plan: 07
type: execute
wave: 7
depends_on: [mint-illogism-fixes-06]
files_modified:
  - apps/mobile/lib/models/coach_profile.dart
  - apps/mobile/lib/services/minimal_profile_service.dart
  - apps/mobile/lib/services/financial_core/archetype_predicates.dart
  - apps/mobile/lib/l10n/app_fr.arb
  - apps/mobile/lib/l10n/app_en.arb
  - apps/mobile/lib/l10n/app_de.arb
  - apps/mobile/lib/l10n/app_es.arb
  - apps/mobile/lib/l10n/app_it.arb
  - apps/mobile/lib/l10n/app_pt.arb
  - apps/mobile/test/services/financial_parity_test.dart
autonomous: true
requirements:
  - MATRIX-independent_no_lpp-3
  - MATRIX-cadre_divorce_hypo-1
must_haves:
  truths:
    - "Un indépendant sans caisse a LPP=0 ENFORCED dans les DEUX moteurs de profil via UN prédicat partagé (plus jamais ~95k CHF de LPP fantôme via le gate q_has_pension_fund seul)."
    - "Un divorcé ne reçoit JAMAIS d'avoir LPP estimé par âge×salaire (partage CC art.122 = path-dependent) — fallback « valeur réelle requise — scanne ton certificat » + confiance dégradée."
    - "Le même profil donne le même verdict LPP sur minimal_profile_service ET coach_profile (prédicat unifié, parité testée)."
  artifacts:
    - path: "apps/mobile/lib/services/financial_core/archetype_predicates.dart"
      provides: "Prédicat partagé hasNoLpp(employmentStatus, hasPensionFund) + canEstimateLpp(civilStatus)"
      exports: ["ArchetypePredicates"]
  key_links:
    - from: "apps/mobile/lib/services/minimal_profile_service.dart"
      to: "apps/mobile/lib/services/financial_core/archetype_predicates.dart"
      via: "gate LPP=0"
      pattern: "ArchetypePredicates\\."
    - from: "apps/mobile/lib/models/coach_profile.dart"
      to: "apps/mobile/lib/services/financial_core/archetype_predicates.dart"
      via: "gate LPP=0 + gate divorcé avant _estimateLppAvoir"
      pattern: "ArchetypePredicates\\."
---

<objective>
W2 — Gates LPP : (1) unifier le prédicat LPP=0 entre `minimal_profile_service.dart:67-74` (gate sur employmentStatus) et `coach_profile.dart:2786, 2853-2859` (gate sur q_has_pension_fund — non équivalent : un indépendant qui répond « oui » à la question caisse reçoit un avoir fantôme ~95k) ; (2) interdire l'estimation LPP par âge×salaire pour un divorcé (CC art.122 : partage au divorce = path-dependent, inestimable).

Purpose: ferme independent_no_lpp-3 (DIVERGENT gates) et cadre_divorce_hypo-1 (ILLOGICAL_FOR_ARCHETYPE).
Output: ArchetypePredicates partagé + gate divorcé + fallback localisé.
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/mint-illogism-fixes/mint-illogism-fixes-CONTEXT.md (W2 gates)
@.planning/reports/MATRIX-illogismes-2026-06-09.md (independent_no_lpp-3, cadre_divorce_hypo-1)

<interfaces>
Sites : minimal_profile_service.dart:67-74 (`isIndependantNoLpp = employmentStatus=='independant'`) ; coach_profile.dart:2786, 2853-2859, 3420-3427 (`_parseBool(null)=false`, gate = `!hasPensionFund`) ; branche d'estimation coach_profile.dart:2850-2859 (ignore etatCivil).
Post-plan 06 : q_employment_status et q_civil_status sont peuplés à l'onboarding. CoachCivilStatus.divorce existe.
Sémantique unifiée (lock CONTEXT) : LPP=0 si l'archétype indépendant-sans-LPP s'applique — prédicat = employmentStatus=='independant' ET pas de caisse déclarée ; les deux moteurs consomment le MÊME prédicat.
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: ArchetypePredicates partagé + enforcement dans les deux moteurs</name>
  <files>apps/mobile/lib/services/financial_core/archetype_predicates.dart, apps/mobile/lib/services/minimal_profile_service.dart, apps/mobile/lib/models/coach_profile.dart, apps/mobile/test/services/financial_parity_test.dart</files>
  <read_first>
    - apps/mobile/lib/services/minimal_profile_service.dart:57-80
    - apps/mobile/lib/models/coach_profile.dart:2780-2870, 3415-3430 (gates actuels + _parseBool)
    - Ligne matrice independent_no_lpp-3 (le scénario exact du gate non-équivalent)
  </read_first>
  <behavior>
    - Test (RED) : profil q_employment_status='independant' + q_has_pension_fund=true → LPP estimée == 0 via coach_profile ET minimal_profile (aujourd'hui coach donne ~95249).
    - Indépendant déclarant une caisse AVEC valeur réelle saisie : la valeur saisie est conservée (le gate bloque l'ESTIMATION, pas la donnée réelle).
    - Salarié avec LPP : estimation inchangée (pas de régression W1).
  </behavior>
  <action>Créer `apps/mobile/lib/services/financial_core/archetype_predicates.dart` : `class ArchetypePredicates { static bool isIndependantSansLpp({required String? employmentStatus, required bool hasPensionFund}) }` — vrai si employmentStatus=='independant' && !hasPensionFund ; et règle d'or : si employmentStatus=='independant', l'ESTIMATION âge×salaire est interdite même si hasPensionFund==true (seule une valeur réelle saisie/scannée compte — c'est ce qui ferme le gate non-équivalent). Re-câbler minimal_profile_service:67-74 et coach_profile:2786/2853-2859 sur ce prédicat. Groupe de parité « Gates LPP ».</action>
  <acceptance_criteria>
    - `grep -c "ArchetypePredicates" apps/mobile/lib/models/coach_profile.dart` ≥ 1 et idem minimal_profile_service.dart.
    - `cd apps/mobile && flutter test test/services/financial_parity_test.dart` exit 0 (oracle re-run : indépendant mal-gaté → 0, plus 95249).
  </acceptance_criteria>
  <verify>
    <automated>cd apps/mobile && flutter test test/services/financial_parity_test.dart && flutter analyze</automated>
  </verify>
  <done>independent_no_lpp-3 fermé : un seul prédicat, deux moteurs alignés.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Gate divorcé — estimation LPP interdite + fallback scan</name>
  <files>apps/mobile/lib/models/coach_profile.dart, apps/mobile/lib/services/financial_core/archetype_predicates.dart, apps/mobile/lib/l10n/app_*.arb, apps/mobile/test/services/financial_parity_test.dart</files>
  <read_first>
    - apps/mobile/lib/models/coach_profile.dart:2850-2859 (branche estimation qui ignore etatCivil)
    - apps/mobile/lib/services/financial_core/confidence_scorer.dart (mécanisme de dégradation EnhancedConfidence)
    - Ligne matrice cadre_divorce_hypo-1
  </read_first>
  <behavior>
    - Test (RED) : profil divorcé 52 ans / 162000 sans valeur LPP saisie → avoirLppTotal estimé ABSENT (null/0 flaggé inestimable), plus jamais 416250.42.
    - Divorcé AVEC valeur réelle saisie/scannée → valeur conservée, confiance normale.
    - La confiance du profil divorcé sans valeur réelle est dégradée (axe completeness/accuracy).
  </behavior>
  <action>Ajouter `ArchetypePredicates.canEstimateLppByAgeSalary({required CoachCivilStatus? civilStatus})` → false pour divorce. Dans coach_profile:2850-2859 (et le chemin minimal_profile équivalent), brancher AVANT l'appel d'estimation : si interdit → pas d'estimation, exposer l'état « valeur réelle requise » consommable par l'UI (nouvelle clé ARB ×6, formulation FR du type « Valeur réelle requise — scanne ton certificat LPP », sans terme banni) + dégradation de confiance via le scorer existant. NE PAS construire d'écran ici (l'affichage hero états connu/estimé/inconnu = plan 10).</action>
  <acceptance_criteria>
    - `cd apps/mobile && flutter test test/services/financial_parity_test.dart` exit 0 (oracle cadre_divorce_hypo-1 re-run : divorcé → aucun avoir estimé).
    - `python3 tools/checks/accent_lint_fr.py` exit 0 + `validate_arb_parity()` OK + `check_banned_terms` clean sur la nouvelle string.
    - `cd apps/mobile && flutter analyze && flutter test` exit 0.
  </acceptance_criteria>
  <verify>
    <automated>cd apps/mobile && flutter test && flutter analyze</automated>
  </verify>
  <done>cadre_divorce_hypo-1 fermé : plus d'avoir certain de 416k pour un divorcé ; fallback localisé prêt pour le plan 10.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries
| Boundary | Description |
|----------|-------------|
| réponses wizard (PII état civil) → moteurs | l'état civil pilote des gates financiers — jamais loggé |
| moteurs → UI | LPP fantôme = intégrité des données financières |

## STRIDE Threat Register
| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-ILF-07-01 | Tampering (intégrité) | gates LPP divergents | mitigate | prédicat unique financial_core + parité |
| T-ILF-07-02 | Information disclosure | etatCivil dans le gate | mitigate | lecture depuis le modèle hydraté (SecureWizardStore), aucun log du statut |
</threat_model>

<verification>
- `cd apps/mobile && flutter analyze && flutter test` + lints ARB/accents/termes bannis.
</verification>

<success_criteria>
- independent_no_lpp-3 et cadre_divorce_hypo-1 fermés avec citations d'oracle re-run.
</success_criteria>

<output>
Create `.planning/phases/mint-illogism-fixes/mint-illogism-fixes-07-SUMMARY.md` + mise à jour VALIDATION.md Per-Task Map.
</output>
