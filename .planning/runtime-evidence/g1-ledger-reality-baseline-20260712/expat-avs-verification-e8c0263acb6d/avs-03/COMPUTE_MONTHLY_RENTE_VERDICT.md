# G1-AVS-03 — verdict `AvsCalculator.computeMonthlyRente`

Date : 2026-07-14
Rôle : `mint-swiss-brain`
Scope : décision de domaine bornée; aucun changement de code.

## Conclusion

**`computeMonthlyRente` viole le prédicat G1-AVS-03 et doit être retiré de la
bibliothèque de production ou déplacé dans un support strictement test-only dès
ce ticket.** Son absence de caller de production réduit le risque de retrait;
elle ne crée pas une exemption.

## Raisonnement déterminant

1. **Le contrat accepte exactement les entrées interdites par AVS-03.**
   `lacunes` convertit directement un nombre d'années en CHF;
   `arrivalAge` transforme une histoire de résidence en années cotisées, puis
   en CHF. Aucun type ne prouve que la caisse a retenu ces périodes, fixé une
   échelle ou fourni un montant officiel.
2. **Les autres paramètres ne rendent pas le calcul officiel.**
   `grossAnnualSalary` est utilisé comme proxy du RAMD, alors que le RAMD est
   fondé sur l'historique de revenus revalorisés, les bonifications reconnues
   et, lorsque les conditions légales sont réunies, le splitting. Les
   bonifications éducatives sont elles-mêmes reconstruites localement. Le
   résultat est un `double` nu, sans source, date juridique, état partiel,
   intervalle ou autorité de décision.
3. **La durée et l'échelle sont simplifiées de manière juridiquement
   incompatible avec une rente personnelle.** Le helper impose
   `avs.full_contribution_years = 44`, soustrait `lacunes`, puis multiplie
   linéairement la rente de base par `effectiveYears / 44`. Les règles 2026
   comparent les années retenues avec la classe d'âge et appliquent l'échelle
   de l'art. 52 RAVS. Les femmes nées avant 1964 ont 43 années entières dans
   l'ordinogramme OFAS tout en pouvant obtenir une rente entière de l'échelle
   44. Une simple division ne remplace pas cette décision.
4. **Le caractère public est le risque.** Le grep trouve `0` caller dans
   `apps/mobile/lib` hors déclaration, mais `48` appels répartis dans `7`
   fichiers de test. Les tests ne constituent pas un câblage produit; ils
   pérennisent une façade prête à être appelée ultérieurement et normalisent
   des assertions telles que `arrivalAge -> 30/44` ou `4 lacunes -> 40/44`.
5. **Le ticket le vise textuellement.** G1-AVS-03 échoue lorsqu'un helper public
   permet de chiffrer un effet à partir d'un gap ou lorsqu'une donnée de
   résidence devient une rente. `computeMonthlyRente` fait les deux, même s'il
   demande aussi salaire et âges.

## Compatibilité avec G1-AVS-01

La décision ne remet pas en cause le contrat couple déjà accepté.
`computeCouplePensions` reçoit des pensions mensuelles et échelles
person-owned, échoue en état `pending` quand l'évidence officielle requise
manque et déclare explicitement qu'il ne dérive jamais une rente du salaire,
de l'âge ou d'une échelle par défaut. Retirer `computeMonthlyRente` renforce
cette frontière et empêche un futur caller de fabriquer les entrées AVS-01.

## Contrat d'implémentation sûr

- Ajouter `computeMonthlyRente` à l'inventaire statique interdit par
  `avs_unofficial_gap_effect_quarantine_test.dart`.
- Supprimer la méthode de `apps/mobile/lib/`.
- Les tests de l'âge de référence doivent appeler les primitives
  `avsReferenceAge*`.
- Les tests qui ont seulement besoin d'une valeur synthétique peuvent utiliser
  une fixture explicitement illustrative sous `apps/mobile/test/support/`,
  jamais exportée par le package de production. Les goldens qui affirment une
  rente personnelle depuis salaire/arrivée/lacunes doivent être supprimés ou
  réécrits contre le contrat officiel fail-closed; ils ne sont pas une preuve
  métier.
- Une future estimation individuelle ne pourrait revenir qu'avec un nouveau
  type exigeant au minimum l'échelle officielle, le RAMD ou montant officiel,
  la provenance, la date/source juridique et les états incomplets. Elle serait
  une autre décision produit, pas un renommage de ce helper.

`renteFromRAMD` sans paramètre de gap n'est pas tranché par cette décision
bornée; son éventuelle conservation doit rester sans caller capable d'y
réappliquer localement une durée ou des lacunes.

## Preuve de grep

```text
apps/mobile/lib : 1 occurrence, la déclaration elle-même; 0 caller
apps/mobile/test: 48 appels dans 7 fichiers
```

Fichiers de test concernés :

- `test/golden/golden_couple_validation_test.dart`
- `test/services/regulatory_sync_integration_test.dart`
- `test/services/onboarding_edge_cases_test.dart`
- `test/services/financial_core/golden_couple_integrated_test.dart`
- `test/services/financial_core/calculator_forge_test.dart`
- `test/services/financial_core/avs_calculator_test.dart`
- `test/services/financial_core/golden_couple_lauren_test.dart`

## Sources 2026 déjà vérifiées dans le dossier

Les sources checked-in de `SWISS_SONNET_FINDINGS_VERDICT.md` suffisent; aucun
nouveau browse n'était requis : LAVS art. 29ter, RAVS art. 52, Directives OFAS
état au 1er janvier 2026, ordinogramme OFAS 43/44 et mémento 3.08.
