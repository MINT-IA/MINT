# Insert: q_housing_sale (Vente immobilière)

## Metadata
```yaml
questionId: "q_housing_sale"
phase: "Niveau 2"
status: "READY"
lifeEvent: "housingSale"
```

## Trigger
- L'utilisateur indique qu'il envisage de vendre un bien immobilier.
- Ou: propriétaire depuis > 15 ans (suggestion proactive de planification fiscale).

## Inputs
- Prix d'achat initial
- Prix de vente estimé
- Année d'achat
- Canton du bien
- Travaux de plus-value réalisés
- EPL (LPP / 3a) utilisé à l'achat
- Hypothèque restante
- Projet de rachat (remploi)

## Outputs
- Plus-value imposable estimée
- Impôt sur les gains immobiliers (taux cantonal dégressif selon durée)
- Économie si remploi (report d'impôt)
- Produit net après remboursements (hypothèque + EPL)

## Hypothèses
- Valeurs saisies par l'utilisateur (pas de données cadastrales réelles).
- Taux simplifiés pour 6 cantons principaux (ZH, BE, VD, GE, LU, BS).
- Frais de notaire et courtage non inclus par défaut.

## Limites
- L'impôt réel dépend de la commune et du barème progressif cantonal exact.
- Les investissements de plus-value doivent être documentés (factures).
- Le remploi doit intervenir dans un délai de 2 ans (selon canton).

## Chiffre Choc
"En vendant après {X} ans dans le canton de {canton}, tu paies {taux}% d'impôt sur la plus-value — soit {montant} CHF. Si tu rachètes un bien, cet impôt peut être reporté."

## Learning Goals
- Comprendre que la plus-value immobilière est imposée (≠ plus-value mobilière en Suisse).
- Découvrir le mécanisme de remploi (report d'impôt si rachat).
- Savoir que l'EPL doit être remboursé (obligation légale OPP2 art. 30d).
- Comprendre la dégressivité du taux selon la durée de détention.

## Disclaimer
"Estimation indicative basée sur les barèmes cantonaux simplifiés. L'impôt réel dépend de la commune et des circonstances. Consulte un·e notaire pour un calcul précis."

## Sources
- LIFD art. 12 (Gains immobiliers)
- Lois cantonales sur l'impôt sur les gains immobiliers (LIGI/LGGI selon canton)
- OPP2 art. 30d (Remboursement EPL)
- LPP art. 30d (Encouragement à la propriété du logement)
- CC art. 793ss (Registre foncier, hypothèques)

## Action
"Simuler le produit net de ma vente"

## Reminder
"Si tu envisages un remploi, commence les recherches AVANT la vente pour sécuriser le report d'impôt."

## Safe Mode
Si dette critique détectée : priorité au remboursement des dettes avant tout réinvestissement immobilier.
