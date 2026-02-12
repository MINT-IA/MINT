# Insert: q_retirement (Retraite)

## Metadata
```yaml
questionId: "q_retirement"
phase: "Niveau 2"
status: "READY"
lifeEvent: "retirement"
```

## Trigger
- L'utilisateur a plus de 55 ans.
- Question sur la retraite, l'AVS ou le retrait du 2e/3e pilier.
- Simulation de rente ou de capital.

## Inputs
- Age actuel
- Salaire brut actuel
- Avoir LPP accumule
- Nombre de comptes 3a et soldes
- Nombre d'annees de cotisation AVS
- Etat civil (impact sur le splitting AVS)
- Canton de domicile

## Outputs
- Estimation de la rente AVS (1er pilier).
- Projection de la rente LPP ou du capital (2e pilier).
- Comparaison capital vs rente.
- Impact fiscal du retrait en capital.
- Taux de remplacement estime (revenus retraite / dernier salaire).

## Chiffre choc
"En moyenne, la rente AVS + LPP ne couvre que 60% du dernier salaire -- le 3e pilier et l'epargne libre doivent combler le reste."

## Contenu educatif

### Les 3 piliers de la retraite suisse
Le systeme suisse repose sur 3 piliers complementaires :
1. **1er pilier (AVS)** : rente de base, financee par repartition. Rente max individuelle : **CHF 30'240/an** (pour 44 annees de cotisation completes).
2. **2e pilier (LPP)** : prevoyance professionnelle, financee par capitalisation. Le taux de conversion minimum est de **6.8%** sur la part legale (LPP art. 14).
3. **3e pilier (3a)** : epargne individuelle facultative, deductible fiscalement.

### Retraite anticipee (LAVS art. 40)
Tu peux anticiper ta retraite AVS de **1 ou 2 ans** (des 63 ans pour les femmes, des 63 ans pour les hommes).
- **Reduction** : la rente est reduite de **6.8% par annee** d'anticipation. Exemple : 2 ans d'anticipation = -13.6% de rente, a vie.
- Le 2e pilier peut aussi etre pris en avance (selon le reglement de ta caisse, generalement des 58 ans).

### Ajournement de la retraite (LAVS art. 39)
Tu peux reporter ta retraite AVS de **1 a 5 ans** (jusqu'a 70 ans).
- **Supplement** : la rente est augmentee de **5.2% a 31.5%** selon la duree de l'ajournement.
- Attention : tu continues a cotiser sur ton salaire, mais ces cotisations ne comptent plus pour le calcul de la rente.

### Capital vs rente (2e pilier)
C'est l'une des decisions financieres les plus importantes :
- **Rente** : revenu regulier a vie, impose comme revenu. Avantage : securite, previsibilite. Inconvenient : pas de transmission aux heritiers (sauf rente de survivant).
- **Capital** : verse en une fois, impose separement du revenu (taux reduit). Avantage : flexibilite, transmission aux heritiers. Inconvenient : risque de placement, pas de revenu regulier.
- **Mixte** : la plupart des caisses permettent un retrait partiel en capital (25-100% selon le reglement).

### Imposition du retrait en capital
Le capital retire du 2e et 3e pilier est impose **separement** du revenu ordinaire, a un taux reduit :
- Le taux varie fortement selon le canton et le montant.
- Strategie d'echelonnement : retire tes comptes 3a sur plusieurs annees fiscales pour rester dans des tranches basses.
- Delai : annonce le retrait en capital a ta caisse de pension au moins **3 ans** avant la retraite (certaines caisses demandent plus).

### Lacunes AVS : chaque annee compte
- Pour la rente AVS maximale, il faut avoir cotise **44 annees** (homme) ou **43 annees** (femme, des 2025).
- Chaque annee manquante reduit ta rente d'environ **1/44e** (soit ~CHF 688/an de rente en moins).
- Tu peux racheter les lacunes des **5 dernieres annees** aupres de ta caisse cantonale AVS (LAVS art. 16).

### Ce que tu peux faire
1. Demande un extrait de compte AVS (gratuit sur ahv-iv.ch) pour verifier tes annees de cotisation.
2. Demande un certificat de prevoyance a ta caisse LPP pour connaitre ton avoir et ta rente projetee.
3. Simule les scenarios capital vs rente dans l'outil MINT.
4. Planifie l'echelonnement de tes retraits 3a (idealement sur 3 a 5 annees fiscales differentes).
5. Consulte un-e specialiste en prevoyance pour un bilan retraite complet.

## Hypothèses
- Rente AVS calculee sur 44 annees de cotisation completes (echelle 44).
- Taux de conversion LPP minimum de 6.8% (part legale uniquement).
- Imposition du capital basee sur les baremes cantonaux simplifies.
- Pas de prise en compte du surobligatoire (les caisses appliquent souvent un taux inferieur a 6.8%).

## Limites
- Le taux de conversion reel peut etre inferieur a 6.8% sur la part surobligatoire (souvent 5.0-5.5%).
- La projection de rente LPP ne prend pas en compte les eventuelles modifications du reglement de la caisse.
- L'esperance de vie reelle influence fortement le choix capital vs rente -- un calcul personnalise est indispensable.
- Les regles de l'ajournement et de l'anticipation evoluent (reforme AVS 21 en vigueur depuis 2024).

## Disclaimer
"Estimation simplifiee a but educatif -- ne constitue pas un conseil en prevoyance. Les montants reels dependent de ta caisse de pension, de tes annees de cotisation et de nombreux facteurs individuels. Consulte un-e specialiste en prevoyance pour un bilan personnalise."

## Sources
- LAVS art. 29 (conditions d'octroi de la rente AVS)
- LAVS art. 16 (rachat d'annees manquantes)
- LAVS art. 39 (ajournement de la rente)
- LAVS art. 40 (anticipation de la rente)
- LPP art. 13 (age de la retraite)
- LPP art. 14 (taux de conversion minimum 6.8%)
- LPP art. 16 (bonifications de vieillesse)
- LPP art. 37 (forme de la prestation : rente ou capital)
- OPP3 art. 3 (retrait du 3e pilier)
- LIFD art. 38 (imposition separee des prestations en capital)

## Action
"Simule ta rente et compare les scenarios capital vs rente dans l'outil retraite MINT."

## Reminder
"55 ans: Commence la planification concrete. 60 ans: Annonce le retrait en capital a ta caisse. 63-65 ans: Decision finale capital vs rente."

## Safe Mode
Si dette critique detectee : la planification retraite reste pertinente, mais le desendettement est prioritaire.
