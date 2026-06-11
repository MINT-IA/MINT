---
phase: mint-illogism-fixes
plan: 12
subsystem: ui
tags: [flutter, divorce, lpp, split-prevoyance, cc-122, lflp-22a, life-events, i18n, parity, tdd]

# Dependency graph
requires:
  - phase: mint-illogism-fixes-07
    provides: gate divorcé (avoirLppTotal=null + lppEstimationBlocked) — un divorcé n'a déjà plus d'avoir LPP estimé inflaté à pré-remplir
  - phase: mint-illogism-fixes-11
    provides: doctrine « valeur réelle requise / badge estimé » — cadrage repris pour l'état « donnée requise » du split
provides:
  - "DivorceService split LPP borné à la part acquise PENDANT le mariage (CC art. 122 / LFLP art. 22a) — plus jamais sur l'avoir total"
  - "DivorceInput.avoirAuMariage1/2 (nullable) + LppSplitResult.acquisConjoint1/2 + LppSplitResult.isIncomplete"
  - "UI simulateur divorce : champ « avoir au mariage » par conjoint + état « donnée requise » quand la donnée manque"
  - "Pré-remplissage LPP conditionné à une valeur réelle (isLppFromCertificate) — jamais l'estimation âge×salaire"
  - "5 clés ARB ×6 langues (avoirAuMariage1/2, hint CC 122, donnée requise, non renseigné)"
affects: [coach-divorce-archetype, life-events-succession]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Calcul de partage de prévoyance borné mariage : acquis_i = max(0, avoir actuel_i − avoir au mariage_i) ; transfert = (acquis_1 − acquis_2).abs() / 2 — la part pré-mariage est exclue (CC art. 122 / LFLP art. 22a)"
    - "Résultat de calcul à état explicite « incomplet » (LppSplitResult.isIncomplete) quand une donnée requise manque — l'UI demande la donnée plutôt que d'afficher un nombre fabriqué (cohérent avec le Confidence Gate du plan 11)"
    - "Pré-remplissage d'un simulateur conditionné à une SOURCE RÉELLE (isLppFromCertificate) — une estimation âge×salaire ne peut jamais alimenter un calcul présenté comme certain"

key-files:
  created:
    - apps/mobile/test/services/life_events_divorce_test.dart
    - apps/mobile/test/screens/divorce_simulator_screen_test.dart
  modified:
    - apps/mobile/lib/services/life_events_service.dart
    - apps/mobile/lib/screens/divorce_simulator_screen.dart
    - apps/mobile/lib/l10n/app_*.arb (6 langues) + app_localizations*.dart (7 générés)
    - apps/mobile/test/services/life_events_service_test.dart

key-decisions:
  - "Split borné mariage, jamais sur le total : acquis_i = max(0, avoir actuel_i − avoir au mariage_i) puis transfert = (acquis_1 − acquis_2)/2. Le finding cadre_divorce_hypo-5 splittait l'avoir total (incluant l'acquis pré-mariage) → surestimation systématique. clamp(0, ∞) borne la part acquise à 0 (jamais négative)."
  - "avoir au mariage manquant → résultat marqué incomplet (isIncomplete=true), PAS de split silencieux sur le total. L'UI affiche « donnée requise » plutôt qu'un transfert fabriqué — cohérent avec la doctrine lucidité (chiffre fabriqué = trust collapse)."
  - "Pré-remplissage LPP gated sur isLppFromCertificate : seule une valeur réelle (certificat scanné) alimente le simulateur. Post-plan 07 un divorcé a déjà avoirLppTotal=null, donc ce gate est une ceinture-et-bretelles contre l'injection d'une estimation pour les autres archétypes."
  - "Champs LPP existants relabellés « avoir actuel » : le label disait « (pendant le mariage) » alors que le champ tient l'avoir total d'aujourd'hui — ambiguïté supprimée, le « pendant le mariage » est désormais le calcul, pas le label de l'input."

patterns-established:
  - "Calcul de partage de prévoyance borné mariage (CC art. 122 / LFLP art. 22a), cas chiffrés en test"
  - "État incomplet explicite sur un résultat de calcul + rendu UI « donnée requise »"

requirements-completed: [MATRIX-cadre_divorce_hypo-5]

# Metrics
duration: ~24min
completed: 2026-06-11
---

# Phase mint-illogism-fixes Plan 12: W4 Split divorce conforme CC art. 122 / LFLP art. 22a Summary

**Le simulateur divorce ne splitte plus l'avoir LPP TOTAL : le partage 50/50 ne porte désormais que sur la part acquise PENDANT le mariage (acquis_i = max(0, avoir actuel_i − avoir au mariage_i), transfert = (acquis_1 − acquis_2)/2). Un champ « avoir au mariage » par conjoint câble cette donnée au calcul ; sans elle, le simulateur affiche « donnée requise » au lieu d'un transfert fabriqué ; et le pré-remplissage LPP est conditionné à une valeur réelle de certificat, jamais l'estimation âge×salaire inflatée. Double erreur cadre_divorce_hypo-5 (split sur total + pré-fill inflaté) fermée.**

## Performance

- **Duration:** ~24 min
- **Started:** 2026-06-11T17:14Z (approx)
- **Completed:** 2026-06-11T17:38Z (approx)
- **Tasks:** 2/2
- **Files modified:** 16 (2 tests créés, 1 service + 1 screen + 6 ARB + 7 l10n générés + 1 test existant)

## Accomplishments

- `DivorceService.simulate` : split LPP borné à la part-mariage. Ancien : `totalLpp = lpp1+lpp2 ; transfer = |lpp1−lpp2|/2`. Nouveau : `acquis_i = (avoir actuel_i − avoir au mariage_i).clamp(0, ∞) ; transfer = (acquis_1 − acquis_2).abs()/2`, direction par signe de `(acquis_1 − acquis_2)`.
- `DivorceInput` étendu : `avoirAuMariage1`/`avoirAuMariage2` (nullable, const-constructible → rétro-compat des appelants).
- `LppSplitResult` étendu : `acquisConjoint1`/`acquisConjoint2` (part acquise = base de partage) + `isIncomplete` (consommable par l'UI).
- Commentaire :115 corrigé : cite CC art. 122 / LFLP art. 22a, formulation neutre (public-repo discipline, pas de langage d'admission).
- UI : 2 champs « avoir au mariage » (un par conjoint) sous chaque champ « avoir actuel », + hint citant CC art. 122. Câblés sur `avoirAuMariage1/2` du service.
- LPP split card : branche `isIncomplete` → rendu « donnée requise » (avec `Semantics` pour les lecteurs d'écran) à la place du transfert.
- Pré-remplissage `_lppConjoint1` :86-90 conditionné à `isLppFromCertificate` (valeur réelle) — l'estimation ne pré-remplit plus.
- 5 clés ARB ×6 langues + `flutter gen-l10n` ; parité 6914 keys × 6 locales.

## Task Commits

1. **Task 1 — Calcul de split borné à la part-mariage (TDD)**
   - `ac7b1efc7` (test, RED) — `life_events_divorce_test.dart` : cas chiffré 416250 (200000 au mariage) + 80000 (0) → transfert 68125, plus jamais 168125 ; null → incomplet ; clamp à 0. API `acquisConjoint1/2` + `isIncomplete` non encore définie → RED.
   - `b142e235a` (feat, GREEN) — formule bornée mariage + `DivorceInput.avoirAuMariage1/2` + `LppSplitResult.acquisConjoint1/2`/`isIncomplete` + commentaire CC 122 corrigé + tests existants mis à jour (avoirAuMariage=0 préserve les attentes chiffrées historiques). 46/46 verts, analyze clean.
2. **Task 2 — UI input « avoir au mariage » + pré-remplissage assaini (TDD)**
   - `86d6d7b1a` (test, RED) — `divorce_simulator_screen_test.dart` : champ présent par conjoint + état « donnée requise » sans saisie. Clés ARB non définies → RED.
   - `21d791005` (feat, GREEN) — 2 champs « avoir au mariage » + LPP card état incomplet + pré-fill gated `isLppFromCertificate` + relabel « avoir actuel » + 4 clés ARB ×6 + gen-l10n. 48/48 divorce + 877 screens + 5870 services verts.

_Le SUMMARY + la mise à jour VALIDATION.md sont committés séparément (docs commit) ; STATE.md / ROADMAP.md sont écrits par l'orchestrateur (hors scope de cet exécuteur)._

## Files Created/Modified

- `life_events_service.dart` — split LPP borné mariage ; `DivorceInput.avoirAuMariage1/2` (nullable) ; `LppSplitResult.acquisConjoint1/2` + `isIncomplete` ; branche `lppIncomplete` (null → résultat incomplet, pas de split sur le total) ; commentaire :115 → CC art. 122 / LFLP art. 22a.
- `divorce_simulator_screen.dart` — état `_avoirAuMariage1/2` (nullable) ; 2 `MintAmountField` « avoir au mariage » (rendu « Non renseigné » si null) + hint ; câblage `avoirAuMariage1/2` dans `DivorceInput` ; pré-fill LPP gated `isLppFromCertificate` ; LPP card branche `isIncomplete` → « donnée requise ».
- `app_*.arb` (6) + `app_localizations*.dart` (7 générés) — `divorceAvoirAuMariage1/2`, `divorceAvoirAuMariageHint`, `divorceSplitDonneeRequise`, `divorceNonRenseigne` ; relabel `divorceLppConjoint1/2` + `divorcePrevoyanceSubtitle`.
- `life_events_divorce_test.dart` (créé) — 5 cas du split borné mariage.
- `divorce_simulator_screen_test.dart` (créé) — 2 widget tests (champ présent + état incomplet).
- `life_events_service_test.dart` — 3 tests du groupe « LPP Split » mis à jour vers la nouvelle API (avoirAuMariage=0).

## Decisions Made

- **Split borné mariage, jamais sur le total.** Le finding splittait l'avoir total (acquis pré-mariage inclus) → surestimation. La formule cible isole la part acquise pendant le mariage. `clamp(0, ∞)` garantit qu'une part acquise négative (avoir actuel < avoir au mariage, ex. après un retrait) est bornée à 0, jamais retranchée du transfert.
- **Donnée manquante → état incomplet, pas de fabrication.** Sans avoir au mariage, on ne peut pas isoler la part-mariage. Plutôt que de retomber silencieusement sur le total (re-introduisant le bug), le service renvoie `isIncomplete=true` et l'UI demande la donnée. Aligné sur la doctrine lucidité et le Confidence Gate du plan 11.
- **Pré-fill gated source réelle.** Post-plan 07, un divorcé a déjà `avoirLppTotal=null` (donc le pré-fill existant ne l'injectait plus). Le gate `isLppFromCertificate` généralise la protection : aucun archétype ne reçoit une estimation âge×salaire pré-remplie dans le simulateur divorce.
- **Relabel « avoir actuel ».** Le label LPP disait « (pendant le mariage) » alors que le champ tient l'avoir total d'aujourd'hui. Ambiguïté levée : l'input = avoir actuel, le « pendant le mariage » est le résultat du calcul.

## Deviations from Plan

None — plan exécuté tel qu'écrit. Une seule adaptation de présentation (non-déviation fonctionnelle) : `MintAmountField` ne supporte pas nativement une valeur null, donc l'état « non renseigné » est rendu via une closure `formatValue` qui affiche `divorceNonRenseigne` quand le nullable backing est null (`value: _avoirAuMariage ?? 0`). La sémantique nullable transite correctement jusqu'au service (`avoirAuMariage1/2` peut être null → `isIncomplete`). Karpathy #2 : pas de nouveau widget, réutilisation du champ existant.

## Design Panel

**Revue 4-lentilles appliquée inline par l'exécuteur** (UX / a11y / adversariale / engineering-wiring) — les sous-agents de panel (`frontend-developer`, `mobile-developer`, `ui-designer`, `accessibility-expert`) ne sont pas spawnables depuis ce contexte d'exécuteur (pas de tool Task exposé). 0-TRUST : pas de revendication d'avoir convoqué les sous-agents ; la revue a été conduite par l'exécuteur selon les 4 lentilles, verdicts ci-dessous, à re-passer par l'orchestrateur si un panel formel est exigé avant merge.

- **UX** : relabel « avoir actuel » (lève l'ambiguïté du label « pendant le mariage » sur un champ qui tenait le total) ; champs « avoir au mariage » appairés visuellement sous chaque « avoir actuel » + hint CC 122. Défaut = non renseigné (nudge vers la saisie), jamais 0 (sinon re-split sur total).
- **A11y** : chaque champ a un label sémantique distinct ; l'état « donnée requise » est enveloppé d'un `Semantics(label: …)` pour être annoncé (pas de silence). Cibles tap héritées de `MintAmountField`.
- **Adversariale** : `avoirAuMariage` ne défaute jamais à 0 silencieusement (état nullable + rendu « Non renseigné ») ; pré-fill gated `isLppFromCertificate` empêche l'injection d'une estimation ; clamp(0,∞) empêche une part acquise négative.
- **Engineering/wiring** : la donnée nullable transite screen → `DivorceInput` → calcul → `isIncomplete` → rendu. Aucun nouveau widget (réutilisation `MintAmountField`). Câblage anti-façade vérifié par grep (`avoirAuMariage` présent aux 4 sites screen + service).

## Verification Evidence (0-TRUST)

```
Evidence : flutter test test/services/life_events_divorce_test.dart → "00:00 +5: All tests passed!"
Evidence : flutter test test/screens/divorce_simulator_screen_test.dart → "00:00 +2: All tests passed!"
Evidence : flutter test (divorce + service existant) → "00:00 +46: All tests passed!"
Evidence : flutter test test/screens/ → "00:19 +877 ~8: All tests passed!"
Evidence : flutter test test/services/ → "00:59 +5870: All tests passed!"
Evidence : flutter analyze lib → "No issues found! (ran in 6.8s)"
Evidence : grep "totalLpp / 2 | (lpp1 + lpp2)" life_events_service.dart → "(none — split borné mariage)"
Evidence : tools/checks/arb_parity.py → "OK — 6 locale(s) parity (reference=fr, 6914 keys each)"
Evidence : tools/checks/banned_terms_arb.py → "OK — 6 locale(s) clean"
Evidence : tools/checks/accent_lint_fr.py --file app_fr.arb → exit 0 ; --file divorce_simulator_screen.dart → exit 0
Evidence : RED→GREEN documenté — ac7b1efc7 (RED 168125 attendu→fail) → b142e235a (GREEN 68125) ; 86d6d7b1a (RED clés ARB indéfinies) → 21d791005 (GREEN champs + donnée requise)
Caveat   : end-to-end UNKNOWN — pas de walkthrough sim (aucun simulateur booté : `xcrun simctl list devices booted` → NO_BOOTED_SIM). Tests verts ≠ feature working (§9.2). Device-proof + capture w4/ déférés à l'orchestrateur (build iOS impossible depuis le worktree .nosync, comme plans 05/06/07).
```

## Device-Proof Status

**DEFERRED-TO-ORCHESTRATOR.** `xcrun simctl list devices booted` → `NO_BOOTED_SIM` au moment de l'exécution. Comme les plans 05/06/07, un build iOS depuis ce working tree `.nosync` n'est pas réalisable sans casser la provenance/codesign macOS. La capture demandée sous `.planning/_walker/illogism-fixes/w4/` (simulateur avec le nouveau champ « avoir au mariage » + état « donnée requise ») tourne contre la branche d'intégration. Per 0-TRUST §9 : aucune revendication « works »/« ready » — preuve déterministe = tests verts uniquement, end-to-end UNKNOWN.

## Threat Surface

- **T-ILF-12-01 (Tampering / intégrité du split)** : MITIGÉ — formule bornée mariage + cas chiffrés en test (`life_events_divorce_test.dart`). `grep "totalLpp / 2 | (lpp1 + lpp2)"` → aucun split sur le total.
- **T-ILF-12-02 (Information disclosure / avoir au mariage PII)** : MITIGÉ — aucun `print`/`debugPrint`/`log` de `avoirAuMariage` (`grep` → vide) ; la donnée reste dans l'état du widget, pas de log.

Aucune nouvelle surface de menace hors `<threat_model>` introduite (pas de nouvel endpoint, pas de nouveau chemin auth, pas de changement de schéma de persistance).

## Known Stubs

Aucun. Le calcul borné mariage est complet côté service ET côté UI (champ d'entrée + état incomplet câblés). Pas de valeur fabriquée résiduelle.

## Self-Check: PASSED

- Created files exist: `apps/mobile/test/services/life_events_divorce_test.dart`, `apps/mobile/test/screens/divorce_simulator_screen_test.dart`
- Commits exist: `ac7b1efc7`, `b142e235a`, `86d6d7b1a`, `21d791005`
- SUMMARY exists: this file.

---
*Phase: mint-illogism-fixes*
*Completed: 2026-06-11*
