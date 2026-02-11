# Insert: q_donation (Donation entre vifs)

## Metadata
```yaml
questionId: "q_donation"
phase: "Niveau 2"
status: "READY"
lifeEvent: "donation"
```

## Trigger
- L'utilisateur indique qu'il souhaite faire une donation.
- Ou: utilisateur > 55 ans avec fortune > 500k (suggestion proactive de planification successorale).
- Ou: utilisateur qui hérite et envisage de redistribuer.

## Inputs
- Montant de la donation
- Lien de parenté (conjoint, descendant, fratrie, concubin, tiers)
- Canton
- Type de donation (espèces, immobilier, titres)
- Nombre d'enfants (pour calcul des réserves)
- Fortune totale estimée du donateur

## Outputs
- Impôt de donation estimé (taux cantonal par degré de parenté)
- Impact sur les réserves héréditaires
- Quotité disponible restante
- Alerte si la donation dépasse la quotité disponible

## Hypothèses
- Taux cantonaux simplifiés (6 cantons principaux + SZ à 0%).
- Régime matrimonial par défaut : participation aux acquêts.
- Nouveau droit des successions 2023 appliqué (réserves réduites).

## Limites
- L'impôt réel peut varier selon la commune.
- Les abattements cantonaux spécifiques ne sont pas tous modélisés.
- Le rapport successoral (avancement d'hoirie) dépend du contrat de donation.
- Ne remplace pas un conseil notarial pour les donations immobilières.

## Chiffre Choc
"Une donation de {montant} CHF à ton {lien} dans le canton de {canton} coûte {impot} CHF d'impôt ({taux}%). À Schwyz ou Obwald, le même geste serait à 0%."

## Learning Goals
- Comprendre que chaque canton a ses propres taux de donation (0% à 30+%).
- Découvrir la distinction entre donation hors part et avancement d'hoirie (CC art. 626).
- Savoir que les réserves héréditaires ont changé en 2023 (CC art. 471).
- Comprendre que le concubin paie un impôt très élevé (pas d'exonération comme le conjoint).
- Savoir qu'une donation immobilière nécessite un acte notarié.

## Disclaimer
"Estimation indicative. L'impôt réel dépend du canton, de la commune et des circonstances personnelles. La planification successorale nécessite l'accompagnement d'un·e notaire ou spécialiste en droit des successions."

## Sources
- CC art. 239-252 (Donation)
- CC art. 457-640 (Droit des successions)
- CC art. 470-471 (Réserves héréditaires, révision 2023)
- CC art. 626 (Rapport successoral / avancement d'hoirie)
- Lois cantonales sur les impôts de succession et donation
- OPP3 art. 2 (Clause bénéficiaire 3a)

## Action
"Calculer l'impôt et l'impact successoral de ma donation"

## Reminder
"Avant toute donation importante, informe les autres héritiers réservataires et consulte un·e notaire."

## Safe Mode
Si dette critique détectée : la donation est déconseillée. Priorité au désendettement.
