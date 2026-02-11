# Insert: q_canton (Canton de residence)

## Metadata
```yaml
questionId: "q_canton"
phase: "Niveau 1"
status: "READY"
```

## Trigger
- L'utilisateur selectionne son canton de residence dans le wizard.

## Inputs
- Canton de residence
- Revenu imposable (si disponible)

## Outputs
- Positionnement fiscal du canton (bas, moyen, eleve)
- Comparaison avec la moyenne suisse
- Deductions cantonales specifiques

## Hypothèses
- Commune chef-lieu pour les taux communaux.
- Statut celibataire par defaut (si non encore precise dans le wizard).

## Limites
- Le taux effectif depend de la commune, pas seulement du canton.
- Les baremes cantonaux changent chaque annee.
- Les deductions specifiques (frais medicaux, garde d'enfants) varient enormement.

## Chiffre Choc
"Pour un revenu de 100'000 CHF, l'impot varie de ~8% a Zoug a ~30% a Geneve — soit une difference de plus de 22'000 CHF par an. Ton canton est le premier levier fiscal en Suisse."

## Learning Goals
- Comprendre que la Suisse a 3 niveaux d'imposition : federal (fixe), cantonal et communal (variables).
- Savoir que le taux effectif d'imposition varie enormement d'un canton a l'autre (et meme d'une commune a l'autre).
- Decouvrir que les deductions (3a, LPP, frais medicaux, enfants) varient aussi par canton.
- Comprendre que la fortune est imposee annuellement au niveau cantonal (pas au niveau federal).
- Savoir que les 26 cantons ont leurs propres baremes, allocations familiales et primes LAMal.

## Disclaimer
"Information a caractere educatif. Les taux d'imposition dependent de la commune, du revenu et de la situation familiale. Consulte l'administration fiscale de ton canton pour un calcul precis."

## Sources
- LIFD (Impot federal direct)
- LHID (Loi sur l'harmonisation des impots directs)
- Lois cantonales sur les impots directs (26 lois)
- OFS Statistique fiscale de la Suisse

## Action
"Comparer la fiscalite des 26 cantons"

## Reminder
"Si tu demenages, pense a recalculer tes impots et primes LAMal — le gain peut etre significatif."

## Safe Mode
Si dette critique detectee : la fiscalite est un levier d'optimisation, mais la priorite reste le desendettement.
