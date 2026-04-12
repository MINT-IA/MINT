---
id: avs_rente_calcul
title: Comment la rente AVS est calculée — RAMD et échelle 44
trigger: simulation rente AVS, calcul rente, RAMD, échelle 44, durée cotisation
tags: [avs, rente, calcul, ramd, echelle44, cotisation, lavs]
---

## Trigger
L'utilisateur veut comprendre comment sa rente AVS est calculée, consulte une simulation de rente, ou se demande pourquoi sa rente est inférieure à la rente maximale.

## Premier Éclairage
La rente AVS maximale est de CHF 2'520/mois (CHF 30'240/an en 2025). Mais seule 1 personne sur 8 environ la touche au maximum — la majorité reçoit moins à cause de lacunes de cotisation ou d'un revenu annuel moyen déterminant (RAMD) insuffisant.

## Niveau 0
Imagine un escalier avec 44 marches. Chaque année où tu cotises à l'AVS entre 21 et 65 ans, tu montes une marche. Si tu rates une année (voyage, études à l'étranger sans cotisation), tu as une marche en moins — et ta rente sera réduite proportionnellement.

Ensuite, on regarde combien tu as gagné en moyenne pendant toutes ces années. C'est ton "revenu annuel moyen déterminant" (RAMD). Plus il est élevé, plus ta rente est haute — mais il y a un plafond. Au-delà d'un certain revenu moyen (~CHF 88'200/an), ta rente n'augmente plus.

Limite de l'analogie : les bonifications pour tâches éducatives ou d'assistance peuvent "gonfler" ton RAMD sans que tu aies gagné ce revenu. C'est un bonus pour ceux qui ont élevé des enfants ou pris soin de proches.

## Niveau 1
Le calcul de la rente AVS repose sur deux facteurs principaux (LAVS art. 29 ss) :

**1. Durée de cotisation (échelle 44)**
- Durée complète : 44 ans de cotisation (de 21 à 65 ans) = rente complète (échelle 44).
- Chaque année manquante réduit la rente d'environ 1/44e (~2.27 %).
- Les tables de rentes de l'OFAS définissent le montant exact par échelon (échelle 1 à 44).

**2. Revenu annuel moyen déterminant (RAMD)**
- Somme de tous les revenus soumis à cotisation, divisée par le nombre d'années de cotisation.
- Revalorisé selon un facteur d'adaptation (pour tenir compte de l'inflation).
- Bonifications éducatives (LAVS art. 29sexies) : ajoutées au RAMD si tu as élevé des enfants < 16 ans.
- Bonifications d'assistance (LAVS art. 29septies) : ajoutées si tu as pris soin de proches dépendants.

**Formule simplifiée** :
`Rente mensuelle = Rente max × (RAMD / RAMD plafond) × (années cotisées / 44)`

**Barème 2025** :
- RAMD minimum (rente min) : CHF 15'120 → rente CHF 1'260/mois
- RAMD maximum (rente max) : CHF 88'200 → rente CHF 2'520/mois
- Entre les deux : interpolation selon les tables OFAS

Le splitting (LAVS art. 29quinquies) redistribue les revenus des couples mariés à 50/50 pendant les années de mariage.

## Sources
- LAVS art. 29 (conditions d'octroi de la rente de vieillesse)
- LAVS art. 29bis-29quinquies (calcul du RAMD, splitting)
- LAVS art. 29sexies (bonifications pour tâches éducatives)
- LAVS art. 29septies (bonifications pour tâches d'assistance)
- LAVS art. 34 (barème des rentes — rente minimale et maximale)
- Tables de rentes OFAS (mises à jour périodiquement)

## Disclaimer
Information à caractère éducatif — ne constitue pas un conseil en prévoyance au sens de la LSFin. Le calcul exact dépend de ton historique complet de cotisations. Commande ton extrait de compte individuel (IK) pour connaître ta situation réelle.
