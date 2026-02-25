# STRATÉGIE UX — RADAR PERSONNEL

**Date** : 9 février 2026
**Statut** : Document de référence pour la dream team
**Principe** : MINT ne montre que ce qui TE concerne, MAINTENANT

---

## PROBLÈME

MINT a 18 événements de vie, 8 blocs thématiques, 15+ simulateurs.
Montrer tout = noyer tout le monde. Un utilisateur de 24 ans n'a que faire de la retraite.
Un indépendant de 45 ans n'a pas besoin du module "premier emploi".

## SOLUTION : ARCHITECTURE À 3 NIVEAUX

### Niveau 1 — RADAR (écran principal)

L'utilisateur voit **1-3 items MAX**, personnalisés à SON profil.

**Algorithme de sélection** : `AgeBand × statut pro × réponses wizard × saison × Safe Mode`

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│              TON RADAR FINANCIER                        │
│                                                         │
│     ┌─────────────────────────────────────────┐         │
│     │ ⚠ ALERTE                                │         │
│     │ "Tu perds 7'258 CHF d'économie fiscale  │         │
│     │  cette année sans 3a"                    │         │
│     │                     [Agir maintenant →] │         │
│     └─────────────────────────────────────────┘         │
│                                                         │
│     ┌──────────────────┐  ┌──────────────────┐         │
│     │ Action du mois   │  │ Opportunité      │         │
│     │ "Verse ton 3a"   │  │ "Rachète LPP"    │         │
│     │ [Simuler →]      │  │ [Simuler →]      │         │
│     └──────────────────┘  └──────────────────┘         │
│                                                         │
│  [ Mon événement de vie ]        [ Explorer tout → ]   │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**Règles de priorité du Radar** :

| Priorité | Condition | Affichage |
|----------|-----------|-----------|
| P0 — CRISE | Safe Mode actif (dette détectée) | 1 seul item : aide dette |
| P1 — URGENT | Deadline < 30 jours (3a fin année, hypothèque) | Alerte rouge |
| P2 — IMPACT | Chiffre choc > 5'000 CHF/an identifié | Carte action |
| P3 — SAISON | Notification saisonnière pertinente | Suggestion |
| P4 — EXPLORE | Rien d'urgent → suggestion proactive | Opportunité |

### Niveau 2 — ÉVÉNEMENT DE VIE (accès contextuel)

Pas de liste de 18 événements. Un champ de recherche intelligent + 4-5 suggestions basées sur le profil.

```
┌─────────────────────────────────────────┐
│  Qu'est-ce qui change dans ta vie ?     │
│                                         │
│  [_________________________________]    │
│                                         │
│  Suggestions pour toi :                 │
│  ┌───────┐ ┌───────┐ ┌───────┐         │
│  │ Achat │ │Mariage│ │Nouveau│         │
│  │ immo  │ │       │ │  job  │         │
│  └───────┘ └───────┘ └───────┘         │
│                                         │
│  Voir tous les événements ▾             │
└─────────────────────────────────────────┘
```

Chaque événement déclenche un **parcours linéaire** :
1. 3-6 questions ciblées (delta questions)
2. Résultat chiffré immédiat (le "chiffre choc")
3. Checklist d'actions concrètes
4. Liens vers simulateurs détaillés si l'utilisateur veut creuser

### Niveau 3 — EXPLORATEUR (pour les curieux)

Accès volontaire via "Explorer tout". Organisé par **besoin**, pas par module technique.

```
Protéger          Optimiser          Planifier         Comprendre
─────────         ──────────         ──────────        ──────────
Safe Mode         3a Deep            Retraite          Fiche salaire
Invalidité        Impôts             Achat immo        Glossaire
Assurances        Rachat LPP         Succession        Éducation
Caritas           Hypothèque         Budget            Ask MINT
```

---

## LE CHIFFRE CHOC — PRINCIPE FONDAMENTAL

Chaque fonctionnalité s'ouvre avec **UN chiffre personnalisé** qui crée le déclic cognitif.
Pas de texte explicatif d'abord. Le chiffre d'abord. L'explication ensuite.

| Situation utilisateur | Chiffre choc |
|----------------------|-------------|
| Pas de 3a, 25 ans | "Tu perds **7'258 CHF** d'économie fiscale cette année" |
| Concubin sans testament | "Ton partenaire hérite de **0 CHF** sans testament" |
| Indépendant sans IJM | "Si tu tombes malade demain : **0 CHF** de revenu après 30 jours" |
| Locataire VD, revenu 100k | "Tu économiserais **8'400 CHF/an** en déménageant à ZH" |
| Hypothèque taux fixe 2.8% | "Tu paies **4'200 CHF/an** de trop vs SARON actuel" |
| Pas de rachat LPP, taux marginal 35% | "Tu perds **12'000 CHF** d'économie fiscale cette année" |
| 1 seul compte 3a, 55 ans | "**15'000 CHF** d'impôt en plus au retrait vs échelonnement" |
| Assurance 3a, 25 ans | "Tu perds **45'000 CHF** de rendement sur 40 ans vs fintech" |
| Dettes > 30% revenus | "Ton ratio dette/revenu est à **35%** — seuil critique dépassé" |

**Implémentation** : Chaque service backend retourne un champ `chiffreChoc` (montant + texte)
que le Flutter affiche en premier, en gros, avec la couleur appropriée.

---

## UX ADAPTATIVE PAR SEGMENT

### Par tranche d'âge (AgeBand)

| Segment | Ton | Densité | Priorité Radar | Design |
|---------|-----|---------|----------------|--------|
| 18-25 (premier emploi) | Tutoiement, simple, zéro jargon | 1 action à la fois | 3a fintech, budget, dette | Cards simples, illustrations |
| 26-35 (stabilisation) | Direct, comparatif | 2-3 options | Achat immo, mariage, naissance | Comparateurs visuels |
| 36-49 (optimisation) | Précis, chiffré | Tableaux, simulations | Rachat LPP, impôts, divorce | Dashboards détaillés |
| 50-65 (pré-retraite) | Rassurant, structuré | Scénarios multiples | Retraite, succession, 3a retrait | Timeline + scénarios |

### Par statut professionnel

| Segment | Modules prioritaires | Alertes spécifiques |
|---------|---------------------|---------------------|
| Salarié | LPP, 3a, impôts, budget | Rachat LPP, franchise LAMal |
| Indépendant | AVS, IJM, 3a grand, forme juridique | URGENCE couverture |
| Frontalier | Impôt source, quasi-résident, LPP cross-border | Rectification 120k |
| Temps partiel | Déduction coordination, gender gap | Impact retraite chiffré |
| Chômeur | LACI, budget survie, libre passage | Safe Mode light |

---

## SAFE MODE — UX RÉINVENTÉE

Quand dette détectée (ratio > 30% ou réponses wizard), MINT bascule entièrement :

```
MODE NORMAL                           SAFE MODE
──────────────                        ──────────
Radar : 3a, LPP, immo                Radar : 1 seule chose → "Réduis ta dette"
Explorer : tout visible               Explorer : budget + remboursement seulement
Simulateurs : tous                    Simulateurs : remboursement dette uniquement
Ton : "optimise tes finances"         Ton : "protège-toi d'abord"
Palette : vert Mint / bleu           Palette : orange warm / neutre
Liens : fintech, banques             Liens : Caritas, Dettes Conseils, ORP
Chiffre choc : économies             Chiffre choc : "libéré de dettes dans X mois"
```

**Sortie du Safe Mode** : automatique quand ratio dette < 20% + aucun retard paiement.
Pas de bouton "ignorer". L'utilisateur doit améliorer sa situation pour débloquer.

---

## NOTIFICATIONS INTELLIGENTES

### Matrice saisonnière

| Mois | Notification | Condition |
|------|-------------|-----------|
| Janvier | "Vérifie tes bénéficiaires 3a/LPP" | Tous |
| Mars | "Déclaration d'impôts : tes déductions ?" | Tous sauf impôt source |
| Juin | "Mi-année : dans les temps pour ton 3a ?" | Has 3a = true |
| Septembre | "Franchise LAMal : change avant le 30 nov" | Tous |
| Novembre | "Rachat LPP + 3a avant le 31 déc" | Revenus > 80k |
| Décembre | "Dernier jour 3a ! Verse maintenant" | Has 3a = true |

### Notifications proactives (profil-based)

| Condition | Notification | Urgence |
|-----------|-------------|---------|
| 24 ans + pas de 3a | "Chaque année sans 3a = X CHF perdus" | Haute |
| Concubin + pas de testament | "Ton partenaire hérite de RIEN" | Critique |
| Hypothèque fin < 180j | "Compare les offres maintenant" | Haute |
| Indépendant + pas de IJM | "ZÉRO couverture perte de gain" | Critique |
| Revenus > 120k + impôt source | "Rectification avantageuse possible" | Moyenne |
| Dettes > 30% revenus | "Ratio endettement élevé" | Critique |
| 10 ans avant retraite + 1 compte 3a | "Ouvre 2 comptes 3a pour échelonner" | Haute |

---

## RÈGLES POUR LA DREAM TEAM

### Backend
- Chaque service retourne un champ `chiffre_choc: { montant, texte, couleur }`
- Chaque réponse inclut un `priority_score` (0-100) pour le Radar
- Le backend filtre par AgeBand + statut pro avant d'envoyer au Flutter
- Les calculs Safe Mode sont vérifiés en premier (court-circuit si dette)

### Flutter
- Le Radar affiche MAX 3 items (1 alerte + 2 actions)
- Chaque carte = chiffre choc en premier, explication en second
- Les couleurs suivent le code : vert (opportunité), orange (attention), rouge (urgence)
- Pas de scroll infini. Pas de catalogue. Parcours guidé.
- Le niveau 3 (Explorateur) est accessible mais jamais imposé

### Compliance
- Le chiffre choc est toujours une ESTIMATION avec disclaimer
- Jamais de "vous économiserez X" → "Économie estimée : X CHF*"
- Le disclaimer est visible mais ne noie pas le chiffre
- Safe Mode ne "bloque" pas l'accès — il "priorise" la dette

---

**Ce document est la référence UX pour tous les sprints S16+.**
**Chaque nouveau module doit implémenter : Chiffre choc + Priority score + Safe Mode check.**
