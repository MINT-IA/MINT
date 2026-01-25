# Insert: q_has_leasing (Leasing ?)

## Metadata
```yaml
questionId: "q_has_leasing"
phase: "Niveau 1"
status: "READY"
```

## Trigger
- Réponse "Oui" à `q_has_leasing`.

## Inputs
- Mensualité
- Apport
- Valeur de rachat

## Outputs
- Coût total réel (Propriété vs Leasing).
- Surcoût estimé du leasing.

## Hypothèses
- Kilométrage standard respecté.
- Pas de frais de remise en état excessifs.

## Limites
- Ne prend pas en compte la flexibilité (avantage leasing).
- Comparaison purement financière.

## Disclaimer
"Estimation basée sur des taux de marché standards. Le coût final dépend de votre contrat spécifique."

## Action
"Comparer Achat vs Leasing"

## Reminder
"Fin de contrat - 6 mois: Évaluer rachat ou restitution."

## Safe Mode
Considéré comme dette si ratio d'endettement > 33%.
