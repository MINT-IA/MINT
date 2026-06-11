---
phase: mint-illogism-fixes
plan: 08
type: execute
wave: 8
depends_on: [mint-illogism-fixes-07]
files_modified:
  - apps/mobile/lib/app.dart
  - apps/mobile/lib/models/coach_profile.dart
  - apps/mobile/lib/services/minimal_profile_service.dart
  - apps/mobile/test/services/financial_parity_test.dart
  - apps/mobile/test/screens/fatca_gate_test.dart
autonomous: true
requirements:
  - MATRIX-expat_us-1
  - MATRIX-expat_us-2
  - MATRIX-frontalier-1
must_haves:
  truths:
    - "Un profil expatUs est redirigé vers /waitlist depuis TOUTE route rendant de la prévoyance (/home, /mon-argent, /profile/bilan, /explore/*) — gate GLOBAL GoRouter, plus point-defense sur /coach/chat seul."
    - "MinimalProfileService.compute() reçoit l'archétype : pour expatUs, AUCUN plafond 3a ni taxSaving3a n'est émis (canContribute3a==false cohérent avec le calcul)."
    - "Un frontalier NON quasi-résident ne voit ni plafond 3a déductible ni économie d'impôt sur le chemin générique (aligné sur segments_service.dart:494-520 qui gate déjà correctement)."
    - "Le walkthrough sim W2 prouve les 3 gates à l'écran (device-proof)."
  artifacts:
    - path: "apps/mobile/test/screens/fatca_gate_test.dart"
      provides: "Tests de redirect : expatUs + /profile/bilan, /mon-argent, /home → /waitlist"
      min_lines: 40
  key_links:
    - from: "apps/mobile/lib/app.dart"
      to: "evaluateCoachArchetypeGate / archétype profil"
      via: "branche archétype dans le redirect global GoRouter (:234-317)"
      pattern: "expatUs|evaluateCoachArchetypeGate"
    - from: "apps/mobile/lib/services/minimal_profile_service.dart"
      to: "archétype"
      via: "paramètre archetype/canContribute3a dans compute()"
      pattern: "archetype|canContribute3a"
---

<objective>
W2 — Gates 3a/FATCA : (1) FATCA passe de point-defense (`coach_chat_screen.dart:1828-1864`, seul site) à gate GLOBAL dans le redirect GoRouter (`app.dart:234-317`, pattern ScopedGoRoute existant) ; (2) `minimal_profile_service.compute()` devient archétype-aware (aujourd'hui aucune branche FATCA → plafond 7258 émis pour un US person alors que `canContribute3a==false`) ; (3) le 3a déductible frontalier est gaté sur le statut quasi-résident dans le chemin générique (`minimal_profile_service.dart:146-153` + `coach_profile.dart:2087-2095`), comme le hub `segments_service.dart:494-520` le fait déjà.

Purpose: ferme expat_us-1, expat_us-2, frontalier-1 (NEVER #7 : jamais présumer l'archétype).
Output: redirect global + compute archétype-aware + canContribute3a quasi-résident + device-proof W2.
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/reports/MATRIX-illogismes-2026-06-09.md (expat_us-1/-2, frontalier-1)

<interfaces>
Sites : app.dart:234-317 (redirect global, branche auth scope uniquement) ; coach_chat_screen.dart:1828-1864 (`evaluateCoachArchetypeGate(profile)` → /waitlist, seul gate actuel) ; coach_profile.dart:1992 (`usTaxPerson==true → FinancialArchetype.expatUs`) ; coach_profile.dart:2087-2095 (`canContribute3a` : `if (isCrossBorder && revenuBrutAnnuel > 0) return true;` — sans test quasi-résident) ; minimal_profile_service.dart:146-153 (plafond/taxSaving inconditionnels) ; segments_service.dart:494-520 (référence du gate quasi-résident GE).
Routes non gatées prouvées : /profile/bilan (app.dart:1360-1363), /mon-argent.
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Gate FATCA global dans le redirect GoRouter</name>
  <files>apps/mobile/lib/app.dart, apps/mobile/test/screens/fatca_gate_test.dart</files>
  <read_first>
    - apps/mobile/lib/app.dart:234-317 (mécanique exacte du redirect + accès au profil/provider depuis le redirect)
    - apps/mobile/lib/screens/coach/coach_chat_screen.dart:1828-1864 (evaluateCoachArchetypeGate — réutiliser cette logique, ne pas la dupliquer)
    - Ligne matrice expat_us-1 (liste des routes à gater)
  </read_first>
  <behavior>
    - Test (RED) : profil usTaxPerson=true authentifié naviguant vers /profile/bilan, /mon-argent, /home → redirect /waitlist.
    - Profil non-US → navigation inchangée (aucune régression sur les ScopedGoRoute existants).
    - /waitlist elle-même reste accessible (pas de boucle de redirect).
  </behavior>
  <action>Ajouter une branche archétype au redirect global app.dart:234-317 : si profil hydraté ET `evaluateCoachArchetypeGate` (réutilisé/extrait, PAS dupliqué) verdict expatUs → redirect /waitlist pour toute route rendant de la prévoyance (scope authenticated hors /waitlist et routes de profil/scan nécessaires à la correction du statut). Attention au cas profil non encore hydraté au boot : ne pas gater tant que l'archétype est inconnu (pas de flash-block des non-US). Le gate point-defense de coach_chat_screen reste (défense en profondeur).</action>
  <acceptance_criteria>
    - `cd apps/mobile && flutter test test/screens/fatca_gate_test.dart` exit 0 (≥3 routes testées + cas non-US + cas non-hydraté).
    - Oracle expat_us-1 re-run : le grep contrôle-de-flux montre une branche archétype dans app.dart:234-317 (`grep -n "expatUs\|ArchetypeGate" apps/mobile/lib/app.dart` ≥ 1 dans le redirect).
  </acceptance_criteria>
  <verify>
    <automated>cd apps/mobile && flutter test test/screens/fatca_gate_test.dart && flutter analyze</automated>
  </verify>
  <done>expat_us-1 fermé : gate global, plus de surface prévoyance atteignable par un expatUs.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: compute() archétype-aware + canContribute3a quasi-résident</name>
  <files>apps/mobile/lib/services/minimal_profile_service.dart, apps/mobile/lib/models/coach_profile.dart, apps/mobile/test/services/financial_parity_test.dart</files>
  <read_first>
    - apps/mobile/lib/services/minimal_profile_service.dart:135-153
    - apps/mobile/lib/models/coach_profile.dart:2087-2095 (canContribute3a)
    - apps/mobile/lib/services/segments_service.dart:494-520 (référence quasi-résident : GE conditionnel, non-GE « pas de déduction », isAlert)
    - Lignes matrice expat_us-2, frontalier-1
  </read_first>
  <behavior>
    - Test (RED) : compute() avec archétype expatUs → plafond3a et taxSaving3a absents/0 (plus jamais 7258 pour un US person).
    - Test (RED) : frontalier sans statut quasi-résident → canContribute3a==false ET compute() n'émet pas de taxSaving3a ; frontalier GE quasi-résident déclaré → comportement déductible conservé.
    - Salarié suisse standard → 7258 inchangé (contrôle négatif salarie_swiss-6).
  </behavior>
  <action>(1) `MinimalProfileService.compute()` gagne un paramètre archétype (ou canContribute3a précalculé) ; la branche :146-153 n'émet plafond/taxSaving que si l'archétype y a droit. (2) `coach_profile.canContribute3a` (:2087-2095) : la branche `isCrossBorder` exige le statut quasi-résident (même critère que segments_service:494-520 — réutiliser/extraire le prédicat, pas le recopier). Câbler tous les appelants de compute() (grep exhaustif AVANT modification de signature — règle pre-push checklist). Groupe de parité « Éligibilité 3a » dans financial_parity_test.dart.</action>
  <acceptance_criteria>
    - `grep -rn "MinimalProfileService\(\)\.compute\|MinimalProfileService.compute" apps/mobile/lib/ | wc -l` — TOUS les appelants mis à jour (aucun défaut silencieux « salarié »).
    - `cd apps/mobile && flutter test test/services/financial_parity_test.dart` exit 0 (oracles expat_us-2 + frontalier-1 re-run : 0/absent pour US person et frontalier non quasi-résident ; 7258 conservé pour salarié).
    - `cd apps/mobile && flutter analyze && flutter test` exit 0.
    - Device-proof clôture W2 : walkthrough sim — profil US → /waitlist depuis /mon-argent ; indépendant → LPP 0 ; captures sous `.planning/_walker/illogism-fixes/w2/`.
  </acceptance_criteria>
  <verify>
    <automated>cd apps/mobile && flutter test && flutter analyze</automated>
    <human-check>Captures w2/ : US person gaté globalement, frontalier sans 3a déductible</human-check>
  </verify>
  <done>expat_us-2 et frontalier-1 fermés ; la couche calc n'est plus FATCA-blind ; W2 device-proofed.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries
| Boundary | Description |
|----------|-------------|
| navigation → surfaces prévoyance | le gate FATCA est une frontière de conformité — bypass = exposition réglementaire |

## STRIDE Threat Register
| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-ILF-08-01 | Elevation of privilege (bypass de gate) | redirect GoRouter | mitigate | gate global + tests de redirect par route + défense en profondeur (gate coach conservé) |
| T-ILF-08-02 | Tampering (intégrité) | plafond 3a émis à tort | mitigate | compute() archétype-aware + contrôles négatifs |
| T-ILF-08-03 | Repudiation (régression FATCA) | futures routes | mitigate | test fatca_gate_test.dart comme harnais permanent |
</threat_model>

<verification>
- `cd apps/mobile && flutter analyze && flutter test` exit 0.
- Walkthrough sim W2 (gates visibles à l'écran).
</verification>

<success_criteria>
- expat_us-1/-2, frontalier-1 fermés avec citations ; W2 (10 ILLOGICAL_FOR_ARCHETYPE) entièrement adressée par plans 06-08.
</success_criteria>

<output>
Create `.planning/phases/mint-illogism-fixes/mint-illogism-fixes-08-SUMMARY.md` + mise à jour VALIDATION.md Per-Task Map.
</output>
