---
phase: mint-illogism-fixes
plan: 12
type: execute
wave: 10
depends_on: [mint-illogism-fixes-07, mint-illogism-fixes-11]
files_modified:
  - apps/mobile/lib/services/life_events_service.dart
  - apps/mobile/lib/screens/divorce_simulator_screen.dart
  - apps/mobile/lib/l10n/app_fr.arb
  - apps/mobile/lib/l10n/app_en.arb
  - apps/mobile/lib/l10n/app_de.arb
  - apps/mobile/lib/l10n/app_es.arb
  - apps/mobile/lib/l10n/app_it.arb
  - apps/mobile/lib/l10n/app_pt.arb
  - apps/mobile/test/services/life_events_divorce_test.dart
autonomous: true
requirements:
  - MATRIX-cadre_divorce_hypo-5
must_haves:
  truths:
    - "Le simulateur divorce ne splitte QUE la prévoyance acquise PENDANT le mariage (CC art.122 / LFLP art.22a) — plus jamais l'avoir total."
    - "L'écran demande « avoir au mariage » pour chaque conjoint ; sans cette donnée, le simulateur n'affiche pas de montant de transfert certain."
    - "Le pré-remplissage n'utilise PLUS l'estimation âge×salaire inflatée (divorce_simulator_screen.dart:86-87) — post-plan 07, un divorcé n'a de toute façon plus d'avoir estimé."
  artifacts:
    - path: "apps/mobile/test/services/life_events_divorce_test.dart"
      provides: "Tests : split = (acquis-mariage-1 − acquis-mariage-2)/2 ; avoir pré-mariage exclu"
      min_lines: 40
  key_links:
    - from: "apps/mobile/lib/screens/divorce_simulator_screen.dart"
      to: "apps/mobile/lib/services/life_events_service.dart"
      via: "passage avoirAuMariage1/2 au calcul de split"
      pattern: "avoirAuMariage|acquiredDuringMarriage"
---

<objective>
W4 — Split divorce conforme : `life_events_service.dart:114-130` splitte aujourd'hui l'avoir TOTAL (`halfLpp = (lpp1+lpp2)/2`, commentaire :115 sans borne mariage). CC art.122 / LFLP art.22a : seule la part acquise pendant le mariage est partagée. Double erreur en contexte (cadre_divorce_hypo-5) : split sur total + pré-rempli avec l'estimation inflatée.

Purpose: ferme cadre_divorce_hypo-5.
Output: calcul borné mariage + input « avoir au mariage » + pré-remplissage assaini.
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/reports/MATRIX-illogismes-2026-06-09.md (cadre_divorce_hypo-5)

<interfaces>
Sites : life_events_service.dart:114-130 (`totalLpp = lpp1+lpp2 ; split = totalLpp/2 ; transfer = |lpp1-lpp2|/2`) ; divorce_simulator_screen.dart:86-87 (`_lppConjoint1 = profile.prevoyance.avoirLppTotal` — l'estimation inflatée du finding cadre_divorce_hypo-2, neutralisée par les plans 01+07).
Formule cible : acquis_i = max(0, avoirActuel_i − avoirAuMariage_i) ; transfert = (acquis_1 − acquis_2)/2 (signe = sens du transfert).
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Calcul de split borné à la part-mariage</name>
  <files>apps/mobile/lib/services/life_events_service.dart, apps/mobile/test/services/life_events_divorce_test.dart</files>
  <read_first>
    - apps/mobile/lib/services/life_events_service.dart:100-140 (calcul + commentaire :115 + structure des inputs)
    - Ligne matrice cadre_divorce_hypo-5
  </read_first>
  <behavior>
    - Test (RED) : avoir1=416250 dont 200000 au mariage, avoir2=80000 dont 0 au mariage → acquis1=216250, acquis2=80000, transfert=(216250−80000)/2=68125 (plus jamais |416250−80000|/2=168125).
    - avoirAuMariage absent (null) → le service signale « donnée requise », pas de split silencieux sur le total.
    - Rétro-compat : appelants existants mis à jour (grep exhaustif avant changement de signature).
  </behavior>
  <action>Étendre l'API de split divorce de life_events_service avec `avoirAuMariage1`/`avoirAuMariage2` (nullable) ; calcul = part acquise pendant le mariage uniquement ; null → résultat marqué incomplet (consommable par l'UI). Corriger le commentaire :115 (citer CC art.122/LFLP art.22a). Public-repo discipline : formulation neutre du commentaire (pas de langage d'admission).</action>
  <acceptance_criteria>
    - `cd apps/mobile && flutter test test/services/life_events_divorce_test.dart` exit 0 (cas chiffrés ci-dessus).
    - `grep -n "totalLpp / 2\|(lpp1 + lpp2)" apps/mobile/lib/services/life_events_service.dart` → plus de split sur total.
  </acceptance_criteria>
  <verify>
    <automated>cd apps/mobile && flutter test test/services/life_events_divorce_test.dart && flutter analyze</automated>
  </verify>
  <done>Calcul conforme CC art.122 testé.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: UI — input « avoir au mariage » + pré-remplissage assaini</name>
  <files>apps/mobile/lib/screens/divorce_simulator_screen.dart, apps/mobile/lib/l10n/app_*.arb</files>
  <read_first>
    - apps/mobile/lib/screens/divorce_simulator_screen.dart:70-120 (pré-remplissage + structure du formulaire)
  </read_first>
  <behavior>
    - Widget test : champ « avoir au mariage » présent par conjoint ; sans saisie → pas de montant de transfert affiché comme certain (état « donnée requise »).
    - Le pré-remplissage de _lppConjoint1 n'injecte une valeur QUE si elle est réelle (saisie/scannée) — pas d'estimation (cohérent plans 07/11 : badge estimé sinon).
  </behavior>
  <action>Ajouter les champs « avoir au mariage » (clés ARB ×6, accents, pas de terme banni), câbler au service Task 1, conditionner le pré-remplissage :86-87 à une source réelle (ProfileDataSource non-estimée). Écran modifié → panel design 4-personnes AVANT push. Device-proof : capture du simulateur avec le nouveau champ sous `.planning/_walker/illogism-fixes/w4/`.</action>
  <acceptance_criteria>
    - `cd apps/mobile && flutter test test/screens/` exit 0 (widget test du formulaire).
    - `python3 tools/checks/accent_lint_fr.py` exit 0 + `validate_arb_parity()` OK.
    - Panel design exécuté, verdicts cités ; capture w4/ citée dans le SUMMARY.
  </acceptance_criteria>
  <verify>
    <automated>cd apps/mobile && flutter test && flutter analyze && python3 tools/checks/accent_lint_fr.py</automated>
  </verify>
  <done>cadre_divorce_hypo-5 fermé (oracle re-run + device-proof cités).</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries
| Boundary | Description |
|----------|-------------|
| simulateur → décision divorce | montant de transfert juridiquement faux = dommage utilisateur réel |

## STRIDE Threat Register
| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-ILF-12-01 | Tampering (intégrité) | split divorce | mitigate | formule bornée mariage + cas chiffrés en test |
| T-ILF-12-02 | Information disclosure | avoir au mariage (PII financière) | mitigate | stockage profil chiffré existant, pas de log |
</threat_model>

<verification>
- `cd apps/mobile && flutter analyze && flutter test` + lints ARB/accents.
</verification>

<success_criteria>
- cadre_divorce_hypo-5 fermé avec citations.
</success_criteria>

<output>
Create `.planning/phases/mint-illogism-fixes/mint-illogism-fixes-12-SUMMARY.md` + mise à jour VALIDATION.md Per-Task Map.
</output>
