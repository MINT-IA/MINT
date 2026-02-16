# Diagrammes de Flux - Statut d'Emploi & 2e Pilier

## Vue d'ensemble

Ce document présente les diagrammes de flux pour visualiser la logique conditionnelle du wizard selon le statut d'emploi et la présence du 2e pilier.

---

## 📊 Diagramme 1 : Flux Principal du Wizard

```
┌─────────────────────────────────────────────────────────────────────┐
│                     DÉBUT DU WIZARD                                 │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│  NOYAU COMMUN (Questions 1-13)                                      │
│  - Canton, Âge, Situation familiale                                 │
│  - q_employment_status ⭐ PIVOT                                     │
│  - q_has_2nd_pillar ⭐ PIVOT (si != étudiant/retraité)             │
│  - Objectif, Horizon, Revenu, Épargne                               │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ q_employment_   │
                    │    status ?     │
                    └─────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┬─────────────────┐
        │                     │                     │                 │
        ▼                     ▼                     ▼                 ▼
   ┌─────────┐          ┌─────────┐          ┌─────────┐      ┌──────────┐
   │ Salarié │          │Indépen- │          │  Mixte  │      │Étudiant/ │
   │         │          │  dant   │          │         │      │ Retraité │
   └─────────┘          └─────────┘          └─────────┘      └──────────┘
        │                     │                     │                 │
        ▼                     ▼                     ▼                 ▼
   ┌─────────┐          ┌─────────┐          ┌─────────┐      ┌──────────┐
   │q_has_2nd│          │q_has_2nd│          │q_has_2nd│      │  Fin     │
   │_pillar? │          │_pillar? │          │_pillar? │      │ branche  │
   └─────────┘          └─────────┘          └─────────┘      └──────────┘
        │                     │                     │
   ┌────┴────┐           ┌────┴────┐           ┌────┴────┐
   │         │           │         │           │         │
   ▼         ▼           ▼         ▼           ▼         ▼
 Oui       Non         Oui       Non         Oui       Non
   │         │           │         │           │         │
   ▼         ▼           ▼         ▼           ▼         ▼
┌──────┐ ┌──────┐   ┌──────┐ ┌──────┐   ┌──────┐ ┌──────┐
│Branch│ │Branch│   │Branch│ │Branch│   │Branch│ │Branch│
│  A   │ │  -   │   │  C   │ │  B   │   │  D   │ │  E   │
└──────┘ └──────┘   └──────┘ └──────┘   └──────┘ └──────┘
   │         │           │         │           │         │
   └─────────┴───────────┴─────────┴───────────┴─────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│  SUITE DU WIZARD (Logement, Dettes, Prévoyance, etc.)              │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│  GÉNÉRATION DU PLAN MINT                                            │
│  - Calcul plafond 3a selon le profil                                │
│  - Création timeline items spécifiques                              │
│  - Recommandations adaptées                                         │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 📊 Diagramme 2 : Branche A - Salarié avec LPP

```
┌─────────────────────────────────────────────────────────────────────┐
│  BRANCHE A : Salarié avec LPP                                       │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│  q_employee_lpp_certificate                                         │
│  "As-tu ton certificat LPP disponible pour upload ?"                │
│  Options : Oui / Non                                                │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│  q_employee_job_change_planned                                      │
│  "Changement d'employeur prévu dans les 12 prochains mois ?"       │
│  Options : Oui / Non / Incertain                                    │
└─────────────────────────────────────────────────────────────────────┘
                              │
                    ┌─────────┴─────────┐
                    │                   │
                    ▼                   ▼
                  Oui                 Non/Incertain
                    │                   │
                    ▼                   ▼
┌─────────────────────────────┐   ┌─────────────────────────────┐
│  q_employee_job_change_date │   │  Fin branche A              │
│  "Date prévue du changement"│   │  → Suite du wizard          │
└─────────────────────────────┘   └─────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Timeline Item Créé :                                               │
│  "Préparer transfert LPP + mise à jour 3a" (30 jours avant)        │
└─────────────────────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Fin branche A → Suite du wizard                                    │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│  PLAFOND 3a : CHF 7'258/an (fixe)                                   │
│  TIMELINE ITEMS RÉCURRENTS :                                        │
│  - Décembre : "Optimiser versement 3a"                              │
│  - Annuel : "Évaluer potentiel rachat LPP"                          │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 📊 Diagramme 3 : Branche B - Indépendant sans LPP

```
┌─────────────────────────────────────────────────────────────────────┐
│  BRANCHE B : Indépendant sans LPP                                   │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│  q_self_employed_legal_form                                         │
│  "Forme juridique de ton activité ?"                                │
│  Options : Raison individuelle / Sàrl / SA / Autre                  │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│  q_self_employed_net_income                                         │
│  "Revenu net annuel issu de l'activité indépendante ?"              │
│  Input : CHF (ex: 80000)                                            │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│  q_self_employed_voluntary_lpp                                      │
│  "As-tu rejoint une solution LPP via une association/fondation ?"   │
│  Options : Oui / Non / Je ne sais pas                               │
└─────────────────────────────────────────────────────────────────────┘
                              │
                    ┌─────────┴─────────┐
                    │                   │
                    ▼                   ▼
                  Non                 Oui/NSP
                    │                   │
                    ▼                   ▼
┌─────────────────────────────┐   ┌─────────────────────────────┐
│q_self_employed_protection_  │   │  Fin branche B              │
│gap (Message d'alerte)       │   │  → Suite du wizard          │
│"Sans LPP, pas de couverture │   │                             │
│automatique décès/invalidité"│   │                             │
└─────────────────────────────┘   └─────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Timeline Item Créé :                                               │
│  "Évaluer couverture protection (décès/invalidité)"                 │
└─────────────────────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Fin branche B → Suite du wizard                                    │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│  PLAFOND 3a : 20% du revenu net, max CHF 36'288/an                  │
│  TIMELINE ITEMS RÉCURRENTS :                                        │
│  - Décembre : "Optimiser montant 3a (20% net, plafond)"             │
│  - Annuel : "Revoir couverture protection (décès/invalidité)"       │
│  - Tous les 2 ans : "Évaluer opportunité affiliation LPP volontaire"│
└─────────────────────────────────────────────────────────────────────┘
```

---

## 📊 Diagramme 4 : Branche D - Mixte avec LPP

```
┌─────────────────────────────────────────────────────────────────────┐
│  BRANCHE D : Mixte (Salarié + Indépendant) avec LPP                │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│  q_mixed_primary_activity                                           │
│  "Quelle est ton activité principale ?"                             │
│  Options : Activité salariée / Activité indépendante                │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│  q_mixed_employee_has_lpp                                           │
│  "As-tu une caisse LPP via ton activité salariée ?"                 │
│  Options : Oui / Non                                                │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│  q_mixed_self_employed_net_income                                   │
│  "Revenu net annuel de l'activité indépendante ?"                   │
│  Input : CHF (ex: 30000)                                            │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│  q_mixed_3a_calculation_note (Message d'information)                │
│  "Ton plafond 3a dépend de ton activité principale et de ta LPP"    │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Fin branche D → Suite du wizard                                    │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│  PLAFOND 3a : CHF 7'258/an (car LPP via emploi salarié)             │
│  TIMELINE ITEMS RÉCURRENTS :                                        │
│  - Novembre : "Vérifier calcul correct plafond 3a (statut mixte)"   │
│  - Annuel : "Bilan fiscal complexe (revenus multiples)"             │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 📊 Diagramme 5 : Calcul du Plafond 3a

```
┌─────────────────────────────────────────────────────────────────────┐
│  CALCUL DU PLAFOND 3a                                               │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ q_employment_   │
                    │    status ?     │
                    └─────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┬─────────────────┐
        │                     │                     │                 │
        ▼                     ▼                     ▼                 ▼
   Salarié              Indépendant              Mixte         Étudiant/Retraité
        │                     │                     │                 │
        ▼                     ▼                     ▼                 ▼
   ┌─────────┐          ┌─────────┐          ┌─────────┐      ┌──────────┐
   │q_has_2nd│          │q_has_2nd│          │q_has_2nd│      │Plafond = │
   │_pillar? │          │_pillar? │          │_pillar? │      │    0     │
   └─────────┘          └─────────┘          └─────────┘      └──────────┘
        │                     │                     │
   ┌────┴────┐           ┌────┴────┐           ┌────┴────┐
   │         │           │         │           │         │
   ▼         ▼           ▼         ▼           ▼         ▼
 Oui       Non         Oui       Non         Oui       Non
   │         │           │         │           │         │
   ▼         ▼           ▼         ▼           ▼         ▼
┌──────┐ ┌──────┐   ┌──────┐ ┌──────┐   ┌──────┐ ┌──────┐
│7'258 │ │36'288│   │7'258 │ │20% net│   │7'258 │ │20% net│
│ CHF  │ │ CHF  │   │ CHF  │ │max    │   │ CHF  │ │max    │
│(fixe)│ │(20% │   │(fixe)│ │36'288 │   │(fixe)│ │36'288 │
│      │ │ net) │   │      │ │ CHF   │   │      │ │ CHF   │
└──────┘ └──────┘   └──────┘ └──────┘   └──────┘ └──────┘

┌─────────────────────────────────────────────────────────────────────┐
│  FORMULE POUR 20% NET :                                             │
│  plafond = min(revenu_net_AVS * 0.20, 36'288)                       │
│                                                                     │
│  EXEMPLE :                                                          │
│  - Revenu net = CHF 80'000 → 20% = CHF 16'000 ✓                    │
│  - Revenu net = CHF 200'000 → 20% = CHF 40'000 → Plafonné CHF 36'288│
└─────────────────────────────────────────────────────────────────────┘
```

---

## 📊 Diagramme 6 : Création de Timeline Items

```
┌─────────────────────────────────────────────────────────────────────┐
│  CRÉATION DE TIMELINE ITEMS                                         │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│  ITEMS COMMUNS (Tous les profils)                                  │
│  - Décembre : "Optimiser versement 3a"                              │
│  - Janvier : "Revue plan + bénéficiaires/assurances"                │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ q_employment_   │
                    │    status ?     │
                    └─────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
        ▼                     ▼                     ▼
   Salarié              Indépendant              Mixte
        │                     │                     │
        ▼                     ▼                     ▼
   ┌─────────┐          ┌─────────┐          ┌─────────┐
   │q_has_2nd│          │q_has_2nd│          │q_has_2nd│
   │_pillar? │          │_pillar? │          │_pillar? │
   └─────────┘          └─────────┘          └─────────┘
        │                     │                     │
   ┌────┴────┐           ┌────┴────┐           ┌────┴────┐
   │         │           │         │           │         │
   ▼         ▼           ▼         ▼           ▼         ▼
 Oui       Non         Oui       Non         Oui       Non
   │         │           │         │           │         │
   ▼         ▼           ▼         ▼           ▼         ▼
┌──────┐ ┌──────┐   ┌──────┐ ┌──────┐   ┌──────┐ ┌──────┐
│Items │ │Items │   │Items │ │Items │   │Items │ │Items │
│  A   │ │  -   │   │  C   │ │  B   │   │  D   │ │  E   │
└──────┘ └──────┘   └──────┘ └──────┘   └──────┘ └──────┘

┌─────────────────────────────────────────────────────────────────────┐
│  ITEMS A (Salarié + LPP) :                                          │
│  - Annuel : "Évaluer potentiel rachat LPP"                          │
│  - Si changement prévu : "Préparer transfert LPP" (30j avant)       │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│  ITEMS B (Indépendant - LPP) :                                      │
│  - Décembre : "Optimiser montant 3a (20% net, plafond)"             │
│  - Annuel : "Revoir couverture protection (décès/invalidité)"       │
│  - Tous les 2 ans : "Évaluer opportunité affiliation LPP volontaire"│
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│  ITEMS D (Mixte + LPP) :                                            │
│  - Novembre : "Vérifier calcul correct plafond 3a (statut mixte)"   │
│  - Annuel : "Bilan fiscal complexe (revenus multiples)"             │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 📊 Diagramme 7 : Événements de Vie

```
┌─────────────────────────────────────────────────────────────────────┐
│  ÉVÉNEMENTS DE VIE LIÉS AU STATUT D'EMPLOI                          │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │  Type d'événe-  │
                    │     ment ?      │
                    └─────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┬─────────────────┐
        │                     │                     │                 │
        ▼                     ▼                     ▼                 ▼
   newJob            employmentStatus     lppAffiliation    lppDisaffiliation
                         Change
        │                     │                     │                 │
        ▼                     ▼                     ▼                 ▼
┌──────────────┐    ┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│Delta-session │    │Delta-session │    │Delta-session │    │Delta-session │
│(3-6 Q)       │    │(3-6 Q)       │    │(3-6 Q)       │    │(3-6 Q)       │
│              │    │              │    │              │    │              │
│- Nouveau     │    │- Nouveau     │    │- Type        │    │- Raison      │
│  revenu      │    │  statut      │    │  affiliation │    │  sortie      │
│- Certificat  │    │- Date        │    │- Date        │    │- Capital à   │
│  LPP         │    │  effective   │    │  affiliation │    │  transférer  │
│- Date début  │    │- Impact LPP  │    │- Certificat  │    │- Nouvelle    │
│- Transfert   │    │- Impact      │    │  reçu        │    │  activité    │
│  LPP         │    │  revenus     │    │              │    │              │
└──────────────┘    └──────────────┘    └──────────────┘    └──────────────┘
        │                     │                     │                 │
        ▼                     ▼                     ▼                 ▼
┌──────────────┐    ┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│Timeline Items│    │Timeline Items│    │Timeline Items│    │Timeline Items│
│              │    │              │    │              │    │              │
│- Transférer  │    │- Mettre à    │    │- Mettre à    │    │- Mettre à    │
│  LPP (30j)   │    │  jour        │    │  jour plafond│    │  jour plafond│
│- Vérifier 3a │    │  prévoyance  │    │  3a (immédiat│    │  3a (immédiat│
│  (60j)       │    │  (30j)       │    │- Upload      │    │- Évaluer     │
│- Mettre à    │    │- Revoir      │    │  certificat  │    │  couverture  │
│  jour        │    │  assurances  │    │  (30j)       │    │  (30j)       │
│  bénéficiaires│   │  (60j)       │    │              │    │              │
│  (90j)       │    │- Bilan fiscal│    │              │    │              │
│              │    │  (90j)       │    │              │    │              │
└──────────────┘    └──────────────┘    └──────────────┘    └──────────────┘
```

---

## 📝 Légende

### Symboles
- `⭐` : Question pivot (détermine le parcours)
- `▼` : Flux séquentiel
- `┌─┐` : Boîte de décision ou action
- `│` : Connexion verticale
- `─` : Connexion horizontale

### Types de Questions
- **Question standard** : Choix unique ou input
- **Question conditionnelle** : Affichée uniquement si condition remplie
- **Message d'information** : Affichage d'une alerte ou note (pas de réponse)

### Branches
- **Branche A** : Salarié avec LPP
- **Branche B** : Indépendant sans LPP
- **Branche C** : Indépendant avec LPP (volontaire)
- **Branche D** : Mixte avec LPP
- **Branche E** : Mixte sans LPP

---

## 🎯 Utilisation des Diagrammes

### Pour les Product Managers
- Visualiser le parcours utilisateur complet
- Identifier les points de décision clés
- Valider la logique conditionnelle

### Pour les Designers
- Comprendre les différents parcours possibles
- Concevoir les écrans pour chaque branche
- Optimiser l'UX selon les profils

### Pour les Développeurs
- Implémenter la logique conditionnelle
- Créer les tests pour chaque branche
- Débugger les parcours complexes

---

**Document créé le** : 2026-01-11  
**Dernière mise à jour** : 2026-01-11  
**Auteur** : Antigravity (Google Deepmind)
