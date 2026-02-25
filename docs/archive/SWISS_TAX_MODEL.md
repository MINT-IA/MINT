# Modèle Fiscal & Juridique Suisse (MINT MVP)

> **Philosophie** : "Swiss Law First". Le code civil et fiscal suisse structure toute la logique financière de l'application.

## 1. La Matrice Cantonale
Nous utilisons un modèle heuristique basé sur 3 profils de pression fiscale pour estimer les impôts sans API fédérale lourde.

### Référentiel
Voir `lib/data/cantonal_data.dart`.
- **Low Tax** : ZG, SZ (Coeff 0.7)
- **Medium Tax** : ZH, VS, FR (Coeff 1.0)
- **High Tax** : VD, GE, BE, NE (Coeff 1.25)

## 2. Règles d'Estimation Fiscale (Heuristique)
Pour le MVP, nous utilisons une formule d'approximation basée sur le revenu brut estimé (Revenu Net x 1.15) et des courbes progressives simplifiées.

### Formule de Base
`Taxe_Estimee = (Revenu_Brut_Annuel * Taux_Progressif_Base) * Multiplicateur_Canton * Multiplicateur_Civil`

### Taux Progressif Base (Moyenne CH)
- < 50k : 8%
- 50k-80k : 12%
- 80k-120k : 16%
- 120k-180k : 22%
- > 180k : 28% (Plafond progressivité moyenne)

### Multiplicateur Civil (Situation Familiale)
- **Célibataire / Concubin** : 1.0 (Taxation individuelle pleine)
- **Marié (Double revenu)** : 0.95 (Splitting fédéral, mais pénalisation cantonale souvent présente)
- **Marié (Revenu unique)** : 0.80 (Avantage quotient familial)
- **Enfants** : -2% de taux effectif par enfant (approx. déductions 10k/enfant).

## 3. Règles Juridiques (Concubinage vs Mariage)
Le système doit alerter sur les risques juridiques ("Death & Divorce").

### Le Concubinage (Risque Maximum)
- **Succession** : Taux 50% entre non-parents (sauf cantons rares). Pas d'héritage légal.
- **AVS** : Pas de rente de veuf/veuve.
- **LPP** : Rente de partenaire survivant conditionnelle (souvent requiert 5 ans vie commune).

### Action MINT
Si `Status == 'cohabiting'`:
1.  Alerte rouge sur écran Protection.
2.  Recommandation : "Rédiger un Testament" + "Annoncer concubin à la Caisse de Pension".

## 4. Intégration Budget
L'impôt est souvent la dépense #1 oubliée.
- Si User ne saisit pas d'impôt source ou acomptes -> **Injection automatique de l'estimation fiscale** comme dépense "Provision Impôts".
