# Verdict suisse — libellé du repère AVS `gap / 44`

Date de vérification : 2026-07-13
Scope : flow Expat AVS self-only à `e8c0263acb6d`; partenaire hors scope et
jamais synthétisé à zéro.

## Verdict

| Sévérité | Verdict |
|---|---|
| P0 | **0** |
| P1 | **0 dans ce flow borné** |
| P2 | **1 confirmé** — remplacer le cadrage « minimum / au moins » |

Le P2 Opus est fondé. `documentedGapYears / 44 * 100` n'est pas un
« minimum de réduction » de la rente personnelle. Ce n'est pas non plus un
« maximum » juridiquement calculé : avant le calcul de la caisse, c'est
seulement un **repère brut de durée de cotisation**.

L'OFAS indique qu'une année de cotisations finalement manquante réduit en
principe la rente partielle de `1/44`. Mais il indique aussi que la caisse
détermine d'abord si les lacunes peuvent être comblées, notamment avec des
cotisations avant 20 ans, certains mois de cotisation, des années d'appoint
pour des lacunes antérieures à 1979 et, sous conditions depuis 2024, des
cotisations d'activité après l'âge de référence. Les années de jeunesse
peuvent combler jusqu'à trois années. Le montant dépend ensuite aussi du
revenu annuel moyen déterminant et des bonifications reconnues.

Conséquence produit : un extrait CI peut rendre visibles des périodes à
examiner; il ne certifie pas à lui seul le nombre final d'années non comblées
retenu pour l'échelle. `ProfileDataSource.certificate` certifie la provenance
du document, pas une décision de caisse.

## Vocabulaire français exact

### Titre

> **Années à examiner d'après l'extrait CI : {years}**

### Corps recommandé

> **Repère brut de durée : {years} sur 44, soit {percent} %. Ce pourcentage
> n'est pas une réduction de ta rente. La caisse détermine d'abord quelles
> périodes peuvent être prises en compte, puis fixe l'échelle et le montant
> officiels. Le montant dépend aussi du revenu annuel moyen déterminant et des
> bonifications reconnues.**

À retirer de ce flow : « au moins 1/44 », « repère minimal », « réduction
minimale », « rente -X % » et toute perte en CHF dérivée localement.

## Sémantique de champ et de calcul

Renommages recommandés pour que le type exprime la limite de preuve :

| Actuel | Recommandé | Contrat |
|---|---|---|
| `documentedGapYears` | `ciObservedMissingContributionYears` | Nombre entier de périodes annuelles manquantes observées sur le CI; jamais une lacune finale statuée. |
| `conditionalMinimumScaleReductionPercent` | `rawContributionDurationGapPercent` | Repère éducatif brut, nullable; **pas** une réduction de rente. |
| `expatAvsDocumentedMinimumEffect` | `expatAvsCiRawDurationBenchmark` | Copie ci-dessus, sans minimum ni promesse d'effet. |

Formule autorisée pour le seul repère brut :

```text
rawContributionDurationGapPercent =
  ciObservedMissingContributionYears / 44 * 100
```

La formule doit rester `null` quand le fait CI est inconnu. Un futur champ
`officialRemainingGapYears` ou `officialPensionScale` ne peut être alimenté
que par un calcul/décompte officiel de la caisse; il ne doit jamais être
inféré du repère brut. Pour ce flow, il est préférable de ne pas appeler le
générique `reductionPercentageFromGap`, dont le nom promet un effet financier
que l'entrée ne permet pas d'établir.

## Cas de test déterministes

1. **CI absent** — `ciObservedMissingContributionYears = null` implique
   `rawContributionDurationGapPercent = null`; état « inconnu », aucun `0`,
   aucun pourcentage.
2. **CI sans période manquante** — une valeur self CI explicite `0` donne un
   repère brut `0.0`; elle n'est valide qu'avec provenance CI/certificate.
3. **Quatre années observées, compensation inconnue** — valeur `4` donne le
   seul repère brut `9.1 %`; la copie contient « n'est pas une réduction de ta
   rente » et ne contient ni « minimum », ni « au moins », ni « rente - ».
4. **Deux années observées et années de jeunesse potentiellement disponibles**
   — le repère brut reste `4.5 %`, tandis que l'effet final reste `null` tant
   que la caisse ne l'a pas déterminé; MINT ne transforme pas localement le
   potentiel de compensation en zéro.
5. **Partenaire absent** — le résultat self-only est identique; aucun champ
   partenaire n'est requis et aucune lacune partenaire n'est créée à `0`.

## Sources officielles vérifiées

- [OFAS — Lacunes d'assurance et de cotisations dans l'AVS, publié le
  03.06.2025](https://www.bsv.admin.ch/fr/lacunes-dassurance-et-de-cotisations-dans-lavs)
  — règle du `1/44`, mécanismes de comblement et décision par la caisse.
- [Centre d'information AVS/AI — Année de
  jeunesse](https://www.ahv-iv.ch/fr/Assurances-sociales/Glossaire/term/jugendjahre)
  — jusqu'à trois années utilisables pour combler des lacunes ultérieures.
- [Centre d'information AVS/AI — Rentes de
  vieillesse](https://www.ahv-iv.ch/fr/assurances-sociales/assurance-vieillesse-et-survivants-avs/rentes-de-vieillesse)
  — durée, revenu annuel moyen déterminant et bonifications.
- [Centre d'information AVS/AI — Demande d'extrait de
  compte](https://www.ahv-iv.ch/fr/Formulaires/Demande-dextrait-de-compte)
  — le CI enregistre revenus, périodes de cotisations et bonifications; il est
  la base du calcul, pas le calcul futur lui-même.
- [Mémento 3.08, état au
  01.01.2026](https://www.ahv-iv.ch/p/3.08.f)
  — conditions du comblement de lacunes par activité après l'âge de référence.

## Conclusion de gate

Le flow peut conserver son verdict global **PASS avec P2** parce qu'il ne
produit ni montant personnel, ni CHF, ni écriture, et conduit au calcul
officiel. Pour fermer le P2, remplacer le nom et la copie avant de qualifier
le wording AVS de final. Aucun besoin partenaire ne doit être ajouté.
