# Vision: Features — MINT

## 1. Life Timeline (Home = Timeline + Proposition de valeur)
**"Juste quand il faut: une explication, une action, un rappel."**

L’accueil est une timeline de moments financiers qui déclenchent des micro-décisions.
Chaque carte respecte “1 écran = 1 intention”: une seule question, une seule action principale, et un suivi sous forme de rappel.

### In-app JIT Tutorial (30–60 secondes)
Le tutorial fait vivre la boucle JIT en 4 écrans: (1) Question, (2) mini-explication (1 phrase), (3) action immédiate (mini-simulateur), (4) rappel timeline (opt-in).
- **Onboarding Alternatif: Stress Check**: Un départ rapide de 30 secondes pour identifier le "levier n°1" (Budget, Dettes, Impôts, Retraite) et décharger immédiatement la charge mentale en proposant l'action la plus impactante.
- **Adaptation Safe Mode**: si dette, priorité budget/dette et ton stabilisation; optimisation repoussée.
- **Sortie**: Le tutorial se termine par un mini-plan: 3 actions max en “Si… alors…”.

### Timeline Mechanics
Instead of a static dashboard, Mint displays a chronological view of financial milestones:
- **Immediate (This Year)**: Pillar 3a, Tax optimization, Budget/Emergency Fund.
- **Short-Term (12-36 months)**: Family planning, Income drop prep, Housing deposit growth.
- **Mid-Term (5-10 years)**: LPP Staggered Buybacks (Tax optimization), Real Estate Feasibility check, Risk insurance coverage.
- **Each event triggers a "Delta Session"**: Updating only what changed.

## 2. Incremental FactFind (Depth Index)
- **FactFind UI**: Progress bar showing "Report Precision %".
- **Semantic Data Pulls**: "Give us your LPP salary to unlock 3 more precise recommendations."
- **Data Completeness**: Salary (Gross/Net), LPP info, 3a history, Housing status, Debt details.
- **Advanced Modules**: Staggered Buyback Simulator & Real Interest Calculator (Unlocked only if Solvent).

## 3. The Statement of Advice (Report v2)
The `SessionReport` is upgraded to a professional-grade document:
- **Profile Summary**: What we know vs what we assumed.
- **Assumptions & Limits**: Explicitly stating what the report can and cannot do.
- **Conflict Disclosure**: "We are partnered with Bank X for 3a; here are 2 non-partner alternatives."
- **Top 3 Actions**: Structured "If-Then" logic for empowerment.

## 4. Écosystème de connectivité financière

### 4.1 Open Banking "Consent Dashboard" (bLink/SFTI — S14, implémenté)
- **Reward Flow**: Suggest connection *after* the first interactive report.
- **Visibility**: Single screen showing: "Who sees what" (Partner X, Partner Y) + Global "Revoke All" button.
- **9 banques suisses**: UBS, PostFinance, Raiffeisen, Credit Suisse (UBS), BCV, BCGE, ZKB, Neon, Yuh.
- **Données obtenues**: Soldes, transactions, catégorisation marchands suisses, détection salaire/hypothèque.
- **Gate FINMA**: Mode sandbox actif. Production nécessite consultation réglementaire formelle.
- **nLPD**: Opt-in explicite, scopes granulaires, 90j max, révocation immédiate, audit log.

### 4.2 APIs Institutionnelles (S47+, vision long terme)

#### Écran: Connexions Institutionnelles Hub
| Field | Value |
|-------|-------|
| **Intention** | Connecter ses comptes de prévoyance directement aux institutions |
| **Widgets** | `InstitutionConnectionCard`, `ConfidenceImpactBadge`, `ConsentScopeSelector` |
| **Events** | `onConnectInstitution(institutionId)`, `onDisconnect(institutionId)` |
| **Data Written** | `profile.institutionalConnections[]` |
| **CTA Label** | "Connecter ma caisse de pension" |

#### Écran: Données Caisse de Pension (LPP temps réel)
| Field | Value |
|-------|-------|
| **Intention** | Afficher les données LPP réelles importées depuis la caisse |
| **Widgets** | `LppRealDataCard`, `ObligSurobligSplitChart`, `BuybackPotentialGauge`, `ConfidenceBoostBanner` |
| **Events** | `onRefreshData()`, `onDisconnect()` |
| **Data Written** | `profile.lpp_obligatoire`, `profile.lpp_surobligatoire`, `profile.conversion_rate_oblig`, `profile.buyback_potential` |
| **CTA Label** | "Rafraîchir mes données" |

#### Écran: Extrait AVS Guidé
| Field | Value |
|-------|-------|
| **Intention** | Guider l'utilisateur pour obtenir et importer son extrait CI |
| **Widgets** | `AvsGuideSteps`, `PdfUploader`, `ExtractionReviewForm`, `ConfidenceImpactBadge` |
| **Events** | `onRequestExtract()` (lien www.ahv-iv.ch), `onUploadPdf()`, `onConfirmExtraction()` |
| **Data Written** | `profile.avs_contribution_years`, `profile.avs_ramd`, `profile.avs_gaps` |
| **CTA Label** | "Importer mon extrait AVS" |

#### Parcours de connectivité (flux utilisateur)
```
1. Hub "Mes connexions"
   ├── Open Banking (bLink) — banques et comptes
   ├── Caisse de pension — LPP temps réel
   ├── Extrait AVS — compte individuel
   └── Documents scannés — certificats, attestations

2. Pour chaque connexion:
   ├── Explication de la valeur ajoutée ("+30 points de précision")
   ├── Sélection des scopes (lecture seule, explicite)
   ├── Authentification (portail institutionnel ou eID)
   ├── Import et revue des données
   └── Impact visible ("Ta confiance est passée de 55% à 87%")

3. Gestion centralisée:
   ├── Statut de chaque connexion (active, expirée, révoquée)
   ├── Date de dernière synchronisation
   ├── Bouton "Déconnecter" par institution
   └── Export/suppression de toutes les données importées
```

#### Caisses de pension ciblées pour le pilote
| Caisse | Type | Marché | Valeur pour MINT |
|--------|------|--------|-----------------|
| **Publica** | Public (Confédération) | National | Portail existant, plus grande caisse publique |
| **BVK** | Public (Zurich) | Alémanique | Portail membre existant |
| **CPEV** | Public (Vaud) | Romand | Marché francophone |
| **Swisscanto** | Privé | National | Large base, infrastructure digitale |
| **Tellco** | Infrastructure | Multi-caisses | Fournisseur de plateforme pension |
| **Profond** | Privé | National | Innovation-friendly |
| **CPEG** | Public (Genève) | Romand | Marché genevois |

#### Modèle B2B (proposition de valeur pour les caisses)
- **Offre**: MINT comme outil "financial wellness" en marque blanche
- **Prix**: 5-15 CHF/employé/an (licence annuelle)
- **Valeur pour la caisse**: Engagement des assurés, réduction des appels support, outil d'éducation 2e pilier
- **Valeur pour MINT**: Accès API aux données LPP, distribution via base d'assurés
- **En échange**: Feed API temps réel des données de prévoyance (solde, taux, rachat, rente projetée)

## 5. Safe Mode (Debt & Risk)
Proactive protection for the 22-35 segment:
- **Feature Blocking**: Advanced optimization tools (3a/LPP boosters) are HIDDEN or DISABLED if debt signals are active. Priority is always debt reduction.
- **Anti-Leasing Engine**: Total cost of ownership comparison.
- **Overdraft Alerts**: Identifying signaux faibles (e.g., gambling, consistent credit card interest).
- **Resource Bridge**: Direct links to Caritas, Dettes Conseils, or support structures.
- **Rights Checker**: Basic "Prestations Complémentaires" eligibility check for low-income profiles (Informational only).

---

## 6. Screen Contracts (Option A — 1 Minute + Timeline)

Chaque écran respecte le principe **1 écran = 1 intention = 1 CTA principal**.

### O1 StressSelectorScreen
| Field | Value |
|-------|-------|
| **Intention** | Identifier le levier prioritaire en 10 secondes |
| **Widgets** | `StressSelectorGrid` |
| **Events** | `onStressSelected(StressType)` |
| **Data Written** | `profile.primaryStressType` |
| **CTA Label** | (Implicit: tap on stress tile) |

### O2 FourQuestionsScreen
| Field | Value |
|-------|-------|
| **Intention** | Collecter les 4 questions d'or (Canton, Âge, Revenu, Statut) |
| **Widgets** | `FactFindFourQuestionsForm`, `PrecisionBadge` |
| **Events** | `onFormComplete(answers)` |
| **Data Written** | `profile.canton`, `profile.birthYear`, `profile.netIncome`, `profile.employmentStatus` |
| **CTA Label** | "Continuer" |

### O3 FirstJITCardScreen
| Field | Value |
|-------|-------|
| **Intention** | Afficher la première carte JIT adaptée au stress type |
| **Widgets** | `JITCard` |
| **Events** | `onActionTap(route)` |
| **Data Written** | – |
| **CTA Label** | Dynamique (voir Locked Mappings §7) |

### O4 MiniReportScreen
| Field | Value |
|-------|-------|
| **Intention** | Présenter Top 3 actions + 1 unlock precision |
| **Widgets** | `Top3ActionsList`, `UnlockPrecisionRow`, `PrecisionBadge` |
| **Events** | `onActionTap(actionId)`, `onUnlockTap()` |
| **Data Written** | – |
| **CTA Label** | "Voir mon plan" |

### T1 TimelineHomeScreen
| Field | Value |
|-------|-------|
| **Intention** | Afficher max 6 moments financiers actionnables |
| **Widgets** | `TimelineMomentCard` (×6 max) |
| **Events** | `onMomentTap(momentId)` |
| **Data Written** | – |
| **CTA Label** | (Per-card: "Agir maintenant") |

### P1 PlanScreen
| Field | Value |
|-------|-------|
| **Intention** | Exécuter une action du plan |
| **Widgets** | Simulator or Learn module |
| **Events** | `onComplete()` |
| **Data Written** | `plan.actions[id].status` |
| **CTA Label** | "Terminer" |

### C1 ComprendreHubScreen ("J'y comprends rien")
| Field | Value |
|-------|-------|
| **Intention** | Point d'entrée vers les thèmes éducatifs |
| **Widgets** | Theme list |
| **Events** | `onThemeTap(themeId)` |
| **Data Written** | – |
| **CTA Label** | (Per-theme: "Explorer") |

### C2 ThemeFlowScreen
| Field | Value |
|-------|-------|
| **Intention** | Deep-dive sur un thème éducatif |
| **Widgets** | Educational content + `JITCard` |
| **Events** | `onActionTap(route)` |
| **Data Written** | – |
| **CTA Label** | Dynamique selon thème |

### PR1 ProfileScreen
| Field | Value |
|-------|-------|
| **Intention** | Gérer les données utilisateur |
| **Widgets** | Profile form |
| **Events** | `onSave()` |
| **Data Written** | `profile.*` |
| **CTA Label** | "Sauvegarder" |

---

## 7. Locked Stress Mappings

### A) StressType = BUDGET_DEBT

**O3 FirstJITCard**
- **Question**: "Ton reste à vivre te semble serré ce mois-ci ?"
- **Micro-insert**: "On commence par une estimation simple. Tu pourras affiner ensuite."
- **Primary Action**: "Estimer mon reste à vivre"
- **Route**: `/simulators/just_available` (read-only)

**O4 Top 3 Actions** (IF/THEN)
1. "Si ton reste à vivre estimé est bas, alors définis un objectif fonds d'urgence."
2. "Si tu as une dette coûteuse (crédit/leasing), alors estime le coût total et mets-la en priorité dans ton plan."
3. "Si tout est stable, alors choisis une micro-épargne mensuelle (planification seulement)."

**Unlock Precision**
- "Ajoute ton loyer/charges logement (CHF/mois) → reste à vivre plus précis."

---

### B) StressType = TAXES

**O3 FirstJITCard**
- **Question**: "As-tu déjà un pilier 3a ?"
- **Micro-insert**: "Le 3a peut réduire l'impôt, mais l'impact dépend de ton canton et de tes déductions."
- **Primary Action**: "Estimer l'impact 3a"
- **Route**: `/simulators/tax_impact_3a`

**O4 Top 3 Actions** (IF/THEN)
1. "Si tu n'as pas de 3a, alors note 'ouvrir un 3a' comme prochaine étape (sans choisir de produit)."
2. "Si tu as un 3a, alors définis un montant cible réaliste cette année."
3. "Si tu veux affiner, alors vérifie 1–2 déductions principales (checklist)."

**Unlock Precision**
- "Ajoute: statut LPP (oui/non) → plafond 3a plus précis."

---

### C) StressType = RETIREMENT

**O3 FirstJITCard**
- **Question**: "Sais-tu si tu as une caisse de pension (LPP) ?"
- **Micro-insert**: "Ton statut LPP change ton plafond 3a et la structure de ta retraite."
- **Primary Action**: "Comprendre LPP → plafond 3a"
- **Route**: `/learn/lpp_vs_3a_cap`

**O4 Top 3 Actions** (IF/THEN)
1. "Si tu es affilié LPP, alors utilise le plafond 3a 'avec LPP' comme repère."
2. "Si tu n'es pas affilié LPP, alors utilise la règle '20% du revenu' comme repère (estimation)."
3. "Si tu veux un plan retraite plus fiable, alors récupère ton certificat LPP (ou confirme 'pas de LPP')."

**Unlock Precision**
- "Ajoute ton salaire assuré LPP (ou ton certificat) → recommandations plus précises."

---

### D) StressType = PROJECT (housing/family)

**O3 FirstJITCard**
- **Question**: "Ton projet est-il dans les 12–36 mois ?"
- **Micro-insert**: "On convertit un objectif en effort mensuel estimé."
- **Primary Action**: "Estimer l'effort d'épargne"
- **Route**: `/simulators/savings_target`

**O4 Top 3 Actions** (IF/THEN)
1. "Si ton horizon est < 36 mois, alors privilégie sécurité/liquidité (planification)."
2. "Si ton effort mensuel estimé est trop élevé, alors ajuste objectif/horizon et refais le calcul."
3. "Si tu vises un achat, alors ouvre le comparateur hypothèque (fixe vs SARON) pour comprendre le risque."

**Unlock Precision**
- "Ajoute ton objectif (CHF) + horizon (mois) → plan plus précis."

---

## 8. Widget Contracts

### StressSelectorGrid
| Field | Value |
|-------|-------|
| **Props** | `List<StressOption> options` |
| **Emits** | `onSelected(StressType)` |
| **Reads** | – |
| **Writes** | – |
| **Primary CTA** | (Implicit: tile tap) |

### FactFindFourQuestionsForm
| Field | Value |
|-------|-------|
| **Props** | `Map<String, dynamic> initialAnswers` |
| **Emits** | `onComplete(Map<String, dynamic> answers)` |
| **Reads** | – |
| **Writes** | – |
| **Primary CTA** | "Continuer" |

### PrecisionBadge
| Field | Value |
|-------|-------|
| **Props** | `int precisionPercent`, `String label` |
| **Emits** | `onTap()` (optional info) |
| **Reads** | – |
| **Writes** | – |
| **Primary CTA** | – |

### JITCard
| Field | Value |
|-------|-------|
| **Props** | `String question`, `String microInsert`, `String actionLabel`, `String route` |
| **Emits** | `onActionTap(String route)` |
| **Reads** | – |
| **Writes** | – |
| **Primary CTA** | `actionLabel` |

### Top3ActionsList
| Field | Value |
|-------|-------|
| **Props** | `List<ActionItem> actions` (exactly 3) |
| **Emits** | `onActionTap(String actionId)` |
| **Reads** | – |
| **Writes** | – |
| **Primary CTA** | Per-action button |

### UnlockPrecisionRow
| Field | Value |
|-------|-------|
| **Props** | `String unlockLabel`, `String unlockField` |
| **Emits** | `onUnlockTap()` |
| **Reads** | – |
| **Writes** | – |
| **Primary CTA** | "Débloquer" |

### TimelineMomentCard
| Field | Value |
|-------|-------|
| **Props** | `TimelineMoment moment` |
| **Emits** | `onTap()`, `onRemind()` |
| **Reads** | – |
| **Writes** | – |
| **Primary CTA** | "Agir maintenant" |

---

## 9. Routes (Locked)

| Route | Description |
|-------|-------------|
| `/simulators/just_available` | Calculateur reste à vivre (read-only) |
| `/simulators/emergency_fund` | Calculateur fonds d'urgence |
| `/simulators/tax_impact_3a` | Simulateur impact fiscal 3a |
| `/learn/lpp_vs_3a_cap` | Explainer LPP vs plafond 3a |
| `/simulators/savings_target` | Calculateur objectif épargne |
| `/simulators/leasing_vs_buy` | Comparateur leasing vs achat |
| `/simulators/mortgage_strategy` | Comparateur Fixe vs SARON |
| `/resources/debt_counseling` | Ressources conseil dettes |
