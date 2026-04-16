# Insert: q_real_estate_project (Projet immobilier)

## Metadata
```yaml
questionId: "q_real_estate_project"
phase: "Niveau 2"
status: "READY"
```

## Trigger
- L'utilisateur indique qu'il a un projet d'achat immobilier.

## Inputs
- Prix du bien vise
- Epargne disponible pour l'apport
- Revenu brut annuel du menage
- Canton du bien

## Outputs
- Apport minimal requis (20% du prix)
- Capacite d'emprunt estimee (regle du 1/3)
- Charges mensuelles theoriques
- Sources d'apport possibles (epargne, 3a, EPL)

## Hypothèses
- Taux theorique de 5% pour le calcul de la capacite d'emprunt (ASB).
- Amortissement de 1%/an et frais accessoires de 1%/an.
- Bien a usage propre (residence principale).

## Limites
- Le calcul de capacite d'emprunt est theorique — les banques appliquent leurs propres criteres.
- Les frais de notaire et droits de mutation varient selon le canton (1-3% du prix).
- L'evaluation bancaire du bien peut differer du prix demande.

## Premier Éclairage
"Pour un bien a 800'000 CHF, il te faut 160'000 CHF d'apport personnel — dont maximum 80'000 CHF de ton 2e pilier. Tes charges mensuelles theoriques seront d'environ 4'670 CHF, soit un revenu brut minimum de 14'000 CHF/mois."

## Learning Goals
- Comprendre la regle des 20% d'apport : minimum 10% en cash ou 3a, max 10% du 2e pilier (FINMA circ. 2017/7).
- Savoir calculer la capacite d'emprunt : charges (5% interet theorique + 1% amortissement + 1% frais) max 1/3 du revenu brut.
- Decouvrir les 3 sources d'apport : epargne, 3a (retrait integral possible), LPP (EPL, max 50% ou 50'000 CHF apres 50 ans, LPP art. 30c).
- Comprendre la difference entre hypotheque 1er rang (max 65% de la valeur) et 2e rang (a amortir en 15 ans).
- Savoir que l'achat declenche des frais uniques : notaire (~1-3%), droits de mutation (selon canton), frais bancaires.

## Disclaimer
"Information a caractere educatif. Les conditions d'emprunt dependent de ta situation et de l'etablissement financier. Consulte un·e specialiste en financement immobilier."

## Sources
- FINMA circ. 2017/7 (Normes minimales hypothecaires)
- ASB Directives relatives aux exigences minimales pour les financements hypothecaires
- LPP art. 30c (EPL — encouragement a la propriete)
- OPP2 art. 30d-30g (Modalites EPL)
- LIFD art. 21 al. 1 let. b (Valeur locative)

## Action
"Simuler ma capacite d'emprunt"

## Reminder
"Si tu envisages un achat dans les 3-5 prochaines annees, commence a constituer ton apport maintenant (epargne + 3a dedie)."

## Safe Mode
Si dette critique detectee : priorite au desendettement avant tout projet immobilier.
