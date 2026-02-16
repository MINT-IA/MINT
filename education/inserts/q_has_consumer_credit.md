# Insert: q_has_consumer_credit (Crédit Consommation)

## Metadata
```yaml
questionId: "q_has_consumer_credit"
phase: "Niveau 1"
status: "READY"
```

## Trigger
- Réponse "Oui" à la question `q_has_consumer_credit`.
- Montant > 0.

## Inputs
- Montant emprunté
- Taux effectif (TAEG)
- Durée restante

## Outputs
- Coût total des intérêts restants.
- Comparaison avec un placement d'épargne.

## Hypothèses
- Taux effectif global annuel (TAEG) fourni par l'utilisateur.
- Remboursement mensuel constant (simplification).
- Pas de pénalité de remboursement anticipé (standard LCC).

## Limites
- Ne prend pas en compte les frais de dossier éventuels ou les assurances solde de dette.
- Le calcul est une estimation linéaire.

## Disclaimer
"Calcul simplifié basé sur un remboursement linéaire. Le coût réel peut varier selon les conditions de votre contrat. Ceci n'est pas un calcul officiel."

## Action
"Si ce crédit te coûte cher, alors il peut être pertinent de le prioriser dans ton plan — selon ta situation et tes autres engagements."

## Reminder
"Dans 6 mois: Vérifier le solde restant."

## Safe Mode
Si ce crédit est détecté → Active Safe Mode et priorise le remboursement sur toute épargne.
