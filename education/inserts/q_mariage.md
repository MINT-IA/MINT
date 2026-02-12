# Insert: q_mariage (Impact fiscal du mariage)

## Metadata
```yaml
questionId: "q_mariage"
phase: "Niveau 2"
status: "READY"
lifeEvent: "marriage"
```

## Trigger
- Question sur le mariage ou l'union civile.
- Changement d'etat civil vers "marie-e".

## Inputs
- Revenu imposable personne 1
- Revenu imposable personne 2
- Canton de domicile
- Nombre d'enfants

## Outputs
- Comparaison fiscale : 2 celibataires vs couple marie.
- Montant de la penalite ou du bonus mariage.
- Detail des deductions accessibles aux maries.

## Chiffre choc
"Un couple marie avec 2 revenus peut payer jusqu'a CHF 3'000 de plus par an qu'en concubinage -- c'est la fameuse 'penalite de mariage'."

## Contenu educatif

### Declaration commune (LIFD art. 9)
En te mariant, tu passes a une **declaration fiscale commune**. Les revenus des deux conjoints sont additionnes, ce qui peut te faire monter dans une tranche d'imposition plus elevee. C'est le principe de la "penalite de mariage" qui touche environ 700'000 couples en Suisse.

### Splitting (LIFD art. 36 al. 2)
Pour compenser l'effet de la declaration commune, la Confederation applique un **bareme pour personnes mariees** (splitting). Concretement, le revenu imposable est divise par un facteur avant d'appliquer le bareme. Ca reduit l'impot, mais pas toujours suffisamment pour compenser la declaration commune.

### Penalite ou bonus ?
- **Penalite de mariage** : quand les deux conjoints ont des revenus similaires et eleves, l'addition des revenus pousse le couple dans une tranche superieure. Resultat : tu paies plus a deux que la somme de ce que vous paieriez separement.
- **Bonus de mariage** : quand un seul conjoint travaille (ou qu'il y a un gros ecart de revenus), le splitting est avantageux. Tu paies moins a deux que si tu etais celibataire.

### Deductions specifiques aux maries
- **Deduction pour couple marie** : CHF 2'700 (LIFD)
- **Deduction pour double revenu** : CHF 2'800 si les deux conjoints travaillent (LIFD art. 33 al. 2)
- **Deduction assurance** : CHF 3'600 (vs CHF 1'800 pour un celibataire)
- **Deduction par enfant** : CHF 6'700 (LIFD art. 35 al. 1 let. a)

### Ce que tu peux faire
- Utilise le simulateur MINT pour comparer ta situation avant/apres mariage.
- Si la penalite est importante, discute avec un-e specialiste des strategies possibles (rachat LPP, echelonnement du 3e pilier, etc.).
- Le Tribunal federal a juge cette penalite anticonstitutionnelle en 1984 -- mais elle n'a toujours pas ete corrigee par le legislateur.

## Hypotheses
- Taux d'imposition simplifies (taux effectif cantonal a 100k revenu).
- Deductions forfaitaires standard (pas de deductions specifiques supplementaires).
- Bareme federal + cantonal combine.

## Limites
- Le calcul ne prend pas en compte les deductions communales specifiques.
- Les impots cantonaux varient fortement selon la commune de residence.
- Le taux marginal exact depend de la fortune et d'autres elements.

## Disclaimer
"Estimation simplifiee a but educatif -- ne constitue pas un conseil fiscal ou juridique. Les montants reels dependent de nombreux facteurs (commune, fortune, deductions specifiques). Consulte un-e specialiste fiscal-e pour un calcul personnalise."

## Sources
- LIFD art. 9 (declaration commune des epoux)
- LIFD art. 33 al. 2 (deduction double revenu)
- LIFD art. 35 al. 1 let. a (deduction par enfant)
- LIFD art. 36 al. 2 (bareme marie / splitting)
- CC art. 159 ss (effets du mariage)
- CC art. 181 ss (regime matrimonial)

## Action
"Simule ta situation dans l'onglet Impots pour voir si le mariage te coute ou t'avantage fiscalement."

## Reminder
"Janvier: Pense a ta premiere declaration commune si tu t'es marie-e cette annee."

## Safe Mode
Non concerne.
