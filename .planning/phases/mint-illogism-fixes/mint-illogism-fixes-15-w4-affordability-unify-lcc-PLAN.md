---
phase: mint-illogism-fixes
plan: 15
type: execute
wave: 12
depends_on: [mint-illogism-fixes-05]
files_modified:
  - apps/mobile/lib/screens/mortgage/affordability_screen.dart
  - apps/mobile/test/screens/affordability_prefill_test.dart
  - services/backend/app/api/v1/endpoints/lucidity.py
autonomous: true
requirements:
  - MATRIX-couple_acheteurs-1
  - MATRIX-W4-citation-LCC
must_haves:
  truths:
    - "Les deux routes vers AffordabilityScreen (profil et coach-prefill) produisent le MÊME revenu de ménage : les 2 conjoints comptent, ×nombreDeMois (plus de ×13 hardcodé ni de conjoint déroulé) — fin du 1.02M vs 0.59M (−45.8%)."
    - "La citation légale fausse « LCC art. 28 » (lucidity.py:46) est corrigée vers la référence FINMA/ASB exacte — SEULE exception backend autorisée de la phase (one-liner doc)."
    - "Contrôle négatif intact : la règle des 10% durs et la règle du tiers (couple_acheteurs-5, SOURCED correct) ne régressent pas."
  artifacts:
    - path: "apps/mobile/test/screens/affordability_prefill_test.dart"
      provides: "Tests : même profil couple → même revenuBrut par les deux routes d'entrée"
      min_lines: 30
  key_links:
    - from: "route coach-prefill (affordability_screen.dart:115-121)"
      to: "construction revenu profil (:64-67)"
      via: "helper unique de revenu de ménage"
      pattern: "revenuMenage|_buildRevenu"
---

<objective>
W4 — Affordability unifiée : `affordability_screen.dart:64-67` (route profil : salaire×nombreDeMois + conjoint×nombreDeMois = 196'800) vs `:115-121` (route coach-prefill : salaire×13 hardcodé, conjoint DÉROULÉ = 106'600) → même écran, deux capacités d'achat (1'022'857 vs 593'333). La route coach contredit la directive ASB que le code cite lui-même (:62-63). Plus le one-liner backend : citation « LCC art. 28 » fausse (lucidity.py:46).

Purpose: ferme couple_acheteurs-1 + la correction de citation W4 du CONTEXT.
Output: helper revenu de ménage unique + citation corrigée.
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/reports/MATRIX-illogismes-2026-06-09.md (couple_acheteurs-1, couple_acheteurs-5 contrôle négatif)

<interfaces>
Sites : affordability_screen.dart:64-67 (référence : somme conjoint, ×nombreDeMois) vs :115-121 (coach prefill : `salaireBrut*13`, pas de conjoint). Constante nombreDeMois défaut 12.0 (coach_profile.dart:196).
Contrôle négatif : mortgage_service.dart:135-160 (10% durs + règle du tiers — CORRECT, ne pas toucher).
Backend : services/backend/app/api/v1/endpoints/lucidity.py:46 (« LCC art. 28 » → FINMA/ASB).
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Helper revenu de ménage unique pour les deux routes</name>
  <files>apps/mobile/lib/screens/mortgage/affordability_screen.dart, apps/mobile/test/screens/affordability_prefill_test.dart</files>
  <read_first>
    - apps/mobile/lib/screens/mortgage/affordability_screen.dart:55-130 (les deux chemins de pré-remplissage + commentaire ASB :62-63)
    - Ligne matrice couple_acheteurs-1 (oracle /tmp/prefill_oracle.py : path1=196800, path2=106600)
  </read_first>
  <behavior>
    - Test (RED) : couple 2×8200/mois, nombreDeMois=12 → revenuBrut == 196800 par la route profil ET par la route coach-prefill.
    - Profil solo → les deux routes égales aussi (pas de sur-comptage).
    - Le prefill coach qui fournit explicitement un revenu différent (paramètre GoRouter) reste prioritaire SEULEMENT s'il est complet — sinon compléter depuis le profil, jamais dérouler le conjoint silencieusement.
  </behavior>
  <action>Extraire un helper privé unique (ex. `double _revenuBrutMenageFromProfile(CoachProfile p)` = salaireBrutMensuel×nombreDeMois + conjoint×nombreDeMois) consommé par LES DEUX routes. Supprimer le `*13` hardcodé (:115-121) au profit de `nombreDeMois`. Ne PAS toucher mortgage_service.dart (couple_acheteurs-5 = contrôle négatif correct). Ajouter un test de non-régression sur prixMaxRevenu pour le cas matrice.</action>
  <acceptance_criteria>
    - `grep -n "\* 13\|\*13" apps/mobile/lib/screens/mortgage/affordability_screen.dart` → 0.
    - `cd apps/mobile && flutter test test/screens/affordability_prefill_test.dart` exit 0 (oracle re-run : 196800 par les deux routes).
    - Tests existants de mortgage_service inchangés et verts.
  </acceptance_criteria>
  <verify>
    <automated>cd apps/mobile && flutter test test/screens/affordability_prefill_test.dart && flutter analyze</automated>
  </verify>
  <done>couple_acheteurs-1 fermé : même personne, même écran, même réponse.</done>
</task>

<task type="auto">
  <name>Task 2: One-liner backend — citation LCC art. 28 corrigée (commit séparé)</name>
  <files>services/backend/app/api/v1/endpoints/lucidity.py</files>
  <read_first>
    - services/backend/app/api/v1/endpoints/lucidity.py:40-50 (le contexte exact de la citation)
  </read_first>
  <action>Remplacer la référence « LCC art. 28 » (fausse) par la référence correcte FINMA/ASB (directives ASB hypothécaires — vérifier le libellé exact du contenu concerné avant de citer). Commit SÉPARÉ (`docs(backend): fix legal citation in lucidity endpoint`) — c'est la seule exception backend autorisée de la phase et une cause racine distincte (petites PR, lock CONTEXT). Public-repo discipline : message de commit neutre, pas de langage d'admission.</action>
  <acceptance_criteria>
    - `grep -n "LCC" services/backend/app/api/v1/endpoints/lucidity.py` → 0 résultat.
    - `cd services/backend && python3 -m pytest tests/ -q` exit 0 (aucun test ne dépend du libellé — sinon mettre à jour).
  </acceptance_criteria>
  <verify>
    <automated>grep -c "LCC" services/backend/app/api/v1/endpoints/lucidity.py || echo "0 — clean"</automated>
  </verify>
  <done>Citation corrigée en commit isolé.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries
| Boundary | Description |
|----------|-------------|
| routes d'entrée → capacité d'achat affichée | capacité divergente de 430k CHF selon la route = intégrité |

## STRIDE Threat Register
| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-ILF-15-01 | Tampering (intégrité) | prefill affordability | mitigate | helper unique + test des deux routes |
| T-ILF-15-02 | Repudiation (citation légale fausse) | lucidity.py:46 | mitigate | référence vérifiée avant commit |
</threat_model>

<verification>
- `cd apps/mobile && flutter analyze && flutter test` + `cd services/backend && python3 -m pytest tests/ -q` exit 0.
</verification>

<success_criteria>
- couple_acheteurs-1 + citation LCC fermés ; couple_acheteurs-5 prouvé non-régressé.
</success_criteria>

<output>
Create `.planning/phases/mint-illogism-fixes/mint-illogism-fixes-15-SUMMARY.md` + mise à jour VALIDATION.md Per-Task Map.
</output>
