# Insert: q_3a_annual_amount (Économie Fiscale 3a)

## Metadata
```yaml
questionId: "q_3a_annual_amount"
phase: "Niveau 1"
status: "READY"
```

## Trigger
- Réponse > 0 à la question `q_3a_annual_amount`.

## Inputs
- Montant versé 3a
- Revenu imposable
- Canton de résidence

## Outputs
- Économie d'impôt estimée (CHF)
- Effort d'épargne net (Versé - Économie)

## Hypothèses
- Taux marginal d'imposition estimé (fourchette moyenne du canton).
- Statut célibataire par défaut (si non précisé).

## Limites
- Ne prend pas en compte les autres déductions possibles.
- Les taux fiscaux peuvent changer chaque année.

## Disclaimer
"Estimation indicative basée sur des hypothèses. Ceci n’est pas un calcul officiel."

## Action
"Simuler la croissance"

## Reminder
"Novembre: Rappel pour optimiser le versement avant fin d'année."

## Safe Mode
Désactivé si dettes détectées (priorité au remboursement).
