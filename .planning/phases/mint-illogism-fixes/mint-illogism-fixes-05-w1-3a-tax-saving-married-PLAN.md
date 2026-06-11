---
phase: mint-illogism-fixes
plan: 05
type: execute
wave: 5
depends_on: [mint-illogism-fixes-04]
files_modified:
  - apps/mobile/lib/services/minimal_profile_service.dart
  - apps/mobile/test/services/financial_parity_test.dart
autonomous: true
requirements:
  - MATRIX-salarie_swiss-2
  - MATRIX-salarie_swiss-3
must_haves:
  truths:
    - "L'économie d'impôt 3a d'un marié utilise le barème marié sur TOUS les chemins (fin de la surestimation +17.6% / 211 CHF)."
    - "Onboarding (minimal_profile) et response card affichent la MÊME économie 3a pour le même profil marié (1194 CHF, plus jamais 1405 vs 1194)."
    - "Walkthrough sim de clôture W1 : les 5 quantités re-câblées rendent des valeurs uniques à l'écran (device-proof 0-TRUST, pas seulement tests verts)."
  artifacts:
    - path: "apps/mobile/test/services/financial_parity_test.dart"
      provides: "Groupe « Économie 3a » : isMarried/children transmis sur tous les chemins"
      contains: "conomie 3a"
  key_links:
    - from: "apps/mobile/lib/services/minimal_profile_service.dart"
      to: "apps/mobile/lib/services/financial_core/tax_calculator.dart"
      via: "estimate3aTaxImpact(isMarried:, children:)"
      pattern: "isMarried"
---

<objective>
W1 quantité #5 — Économie d'impôt 3a : `minimal_profile_service.dart:136-141` doit transmettre `isMarried`/`children` à `estimate3aTaxImpact` (la fonction les accepte, l'appelant les omet — l'info householdType existe lignes 50-51 et est perdue à l'appel). `response_card_service.dart:674-678` le fait déjà (référence). Clôture de la vague W1 avec device-proof sim.

Purpose: ferme salarie_swiss-2 (ILLOGICAL_FOR_ARCHETYPE) et salarie_swiss-3 (DIVERGENT inter-écran).
Output: appel corrigé + groupe de parité + walkthrough sim W1.
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/reports/MATRIX-illogismes-2026-06-09.md (salarie_swiss-2/-3)

<interfaces>
`estimate3aTaxImpact(..., bool isMarried = false, int children = 0, ...)` (tax_calculator.dart:535, vérifié). Barème : familyAdjustment tax_calculator.dart:412-423, marie_sans_enfant=0.85 (:373).
Appelant fautif : minimal_profile_service.dart:136-141 (omet isMarried/children alors que householdType est connu :50-51).
Référence : response_card_service.dart:674-678 (passe `isMarried: etatCivil == marie`).
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Transmettre isMarried/children depuis minimal_profile_service</name>
  <files>apps/mobile/lib/services/minimal_profile_service.dart, apps/mobile/test/services/financial_parity_test.dart</files>
  <read_first>
    - apps/mobile/lib/services/minimal_profile_service.dart:45-60 (householdType) et :135-152 (appel)
    - apps/mobile/lib/services/response_card_service.dart:670-680 (pattern de référence)
    - Lignes matrice salarie_swiss-2/-3
  </read_first>
  <behavior>
    - Test (RED) : profil marié VD, brut 102000, contribution 7258 → économie 3a IDENTIQUE via minimal_profile et via le chemin response_card (≈1194 CHF barème marié, plus 1405 célibataire).
    - Profil célibataire → comportement inchangé (pas de régression).
  </behavior>
  <action>Dans minimal_profile_service:136-141, passer `isMarried: householdType == 'couple'` (aligné sur la sémantique des lignes 50-51 — lire le code exact pour la valeur de comparaison) et `children:` si le champ est disponible dans les inputs du service (sinon laisser 0 et le documenter). Ajouter le groupe de parité « Économie 3a ».</action>
  <acceptance_criteria>
    - `grep -n "isMarried" apps/mobile/lib/services/minimal_profile_service.dart` ≥ 1 dans le bloc d'appel estimate3aTaxImpact.
    - `cd apps/mobile && flutter test test/services/financial_parity_test.dart` exit 0 (oracle re-run : marié VD 102000 → une seule économie 3a sur les deux chemins).
  </acceptance_criteria>
  <verify>
    <automated>cd apps/mobile && flutter test test/services/financial_parity_test.dart && flutter analyze</automated>
  </verify>
  <done>salarie_swiss-2 et salarie_swiss-3 fermés avec citation.</done>
</task>

<task type="auto">
  <name>Task 2: Device-proof de clôture W1 (walkthrough sim)</name>
  <files>.planning/_walker/illogism-fixes/w1/ (captures)</files>
  <read_first>
    - .planning/phases/mint-illogism-fixes/mint-illogism-fixes-RESEARCH.md §1.4 (workaround build : `ln -s /tmp/mint_build_ios apps/mobile/build` puis `flutter build ios --simulator --no-codesign --dart-define=API_BASE_URL=https://mint-staging.up.railway.app/api/v1`)
    - tools/simulator/walker.sh (invocation Maestro existante — diff textuel, ne pas reconstruire de mémoire)
  </read_first>
  <action>Builder le sim (workaround engram #1595), dérouler un profil marié salarié (102000) et un indépendant net 86400 jusqu'aux surfaces : home hero, mon-argent, response cards, mariage. Capturer (budget screenshots : uniquement les surfaces preuves, pas chaque étape) : avoir LPP identique inter-écrans, rente unique, taux de remplacement unique, plafond 17280/7258 selon archétype, économie 3a barème marié. Captures sous `.planning/_walker/illogism-fixes/w1/`.</action>
  <acceptance_criteria>
    - ≥3 captures nommées citées dans le SUMMARY prouvant les valeurs uniques à l'écran (0-TRUST §9.2 : tests verts ≠ feature working).
    - Aucune des 5 quantités W1 n'affiche deux valeurs différentes pour le même input dans la même session.
  </acceptance_criteria>
  <verify>
    <automated>ls .planning/_walker/illogism-fixes/w1/*.png | head -5</automated>
    <human-check>Captures montrent des valeurs cohérentes inter-écrans</human-check>
  </verify>
  <done>W1 device-proofed ; SUMMARY cite captures + commandes.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries
| Boundary | Description |
|----------|-------------|
| moteur fiscal → UI | économie d'impôt surévaluée +17.6% pour un marié = promesse fiscale fausse (LSFin) |

## STRIDE Threat Register
| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-ILF-05-01 | Tampering (intégrité) | appel estimate3aTaxImpact | mitigate | paramètres transmis + parité inter-écrans |
</threat_model>

<verification>
- `cd apps/mobile && flutter analyze && flutter test` exit 0 + lints lefthook.
- Walkthrough sim W1 (VALIDATION.md « After every plan wave »).
</verification>

<success_criteria>
- salarie_swiss-2/-3 fermés ; W1 entière device-proofed (27 findings DIVERGENT adressés par plans 01-05).
</success_criteria>

<output>
Create `.planning/phases/mint-illogism-fixes/mint-illogism-fixes-05-SUMMARY.md` + mise à jour VALIDATION.md Per-Task Map.
</output>
