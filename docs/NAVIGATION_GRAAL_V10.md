# NAVIGATION GRAAL V10 — MINT

> Statut : cible produit / UX / information architecture
> Horizon : 2026-2027
> Portée : mobile app MINT
> Compagnons : `docs/UX_V2_COACH_CONVERSATIONNEL.md`, `docs/DESIGN_SYSTEM.md`, `docs/BLUEPRINT_COACH_AI_LAYER.md`
> Révision : cette version intègre un audit contradictoire sur iOS patterns, profondeur Explore, ordre de migration et capacité réelle du coach à orchestrer.

---

## 1. Décision centrale

### Ce que MINT ne doit pas devenir
- Une app `chat-only`.
- Un catalogue d'outils structuré selon la logique de l'équipe.
- Une expérience où l'IA remplace la preuve, le contrôle et la lisibilité.

### Ce que MINT doit devenir
- **Coach-first, UI-assisted**.
- Plus précisément : **AI-as-layer**, pas **chat-as-product**.
- L'IA personnalise, priorise, relie et explique.
- Les écrans structurés restent la surface de confiance.
- Les outils deviennent des capacités appelées par contexte.

### Formule cible
```text
Today = synthèse
Coach = orchestration progressive
Explore = navigation autonome
Dossier = vérité personnelle
Capture = entrée de données à fort effet
```

---

## 2. Diagnostic de l'existant

### Ce qui est juste dans l'audit
- La base technique est saine.
- La surface UX est trop éclatée.
- La taxonomie visible est trop dev-centric.
- Le shell 3 tabs n'absorbe pas proprement la profondeur métier.
- Le coach n'est pas encore capable d'orchestration large à lui seul.

### Symptômes
- Trop de familles de routes techniques visibles : `arbitrage`, `simulator`, `segments`, `lpp-deep`, `3a-deep`.
- Des hubs qui se marchent dessus : Pulse, Coach, Ask Mint, Tools, Profile, Financial Summary, Documents.
- Une hiérarchie produit qui reflète davantage les modules du code que les intentions utilisateur.

---

## 3. Principe d'architecture cible

L'architecture cible doit suivre 6 règles :

1. **4 destinations top-level maximum**.
2. **Pas de FAB global persistant cross-platform**.
3. **Le coach ouvre les flows, mais n'est pas un prérequis de navigation**.
4. **Explore doit être complet sans passer par le coach**.
5. **Les taxonomies internes disparaissent de la navigation visible**.
6. **Chaque écran appartient à une classe claire : destination, flow, tool, alias**.

---

## 4. Schéma cible

```text
/
├─ /welcome
├─ /onboarding
│  ├─ /quick-start
│  ├─ /first-impact
│  └─ /progressive-enrichment
└─ /app
   ├─ /today
   ├─ /coach
   ├─ /explore
   └─ /dossier
```

### Les 4 piliers
- **Aujourd'hui** : où j'en suis, qu'est-ce qui compte maintenant
- **Coach** : aide-moi à comprendre, arbitrer, décider
- **Explorer** : je veux reprendre la main par parcours
- **Dossier** : mes données, mes documents, mes accès

### Capture
`Capture` n'est pas une destination top-level.

`Capture` est une **capacité transversale contextuelle** :
- dans `Aujourd'hui`
- dans `Coach`
- dans `Dossier`

---

## 5. Shell final

```text
Bottom navigation
[Aujourd'hui] [Coach] [Explorer] [Dossier]
```

### Décision iOS / Android
- Pas de FAB global persistant.
- iOS : bouton contextuel dans le contenu ou action de top bar selon le contexte.
- Android : CTA contextuel proéminent acceptable, mais pas imposé comme geste global permanent.

### Labels retenus
- `Aujourd'hui`
- `Coach`
- `Explorer`
- `Dossier`

---

## 6. Wireflows cibles

## 6.1 Aujourd'hui

```text
Aujourd'hui
├─ 1 phrase personnalisée
├─ 1 chiffre dominant
├─ 1 action prioritaire
├─ 2 signaux secondaires max
└─ 1 sortie vers Coach ou Capture
```

### Contrat UX strict
- 1 phrase
- 1 chiffre
- 1 action
- 2 signaux max

### Ce que Aujourd'hui ne doit pas être
- Un ancien `Pulse` légèrement renommé.
- Une pile de 6 sections.
- Une entrée vers tous les modules.

### Ce qui descend ailleurs
- focus selector 2x2
- badges parasites
- anneaux décoratifs
- blocs secondaires non urgents
- exploration libre

---

## 6.2 Coach

```text
Coach
├─ Chat texte
├─ Mode voix
├─ Prompt chips contextuels
├─ Cards inline
├─ Historique
└─ Handoff vers flow structuré
```

### Rôle
- Entrée émotionnelle et intelligente.
- Complément actif aux flows, pas remplacement.

### Règle produit
- Le coach doit pouvoir répondre.
- Le coach doit pouvoir clarifier.
- Le coach doit pouvoir ouvrir un flow.
- Le coach doit pouvoir demander une donnée.
- Le coach doit pouvoir proposer une capture.

### Réalité roadmap
- Phase 1 : coach utile, mais orchestration limitée.
- Phase 2 : coach-orchestrator via classifier d'intention + routing table robuste.
- La fusion finale `Ask Mint` -> `Coach` n'intervient qu'après cette phase.

---

## 6.3 Explorer

```text
Explorer
├─ Recherche / launcher
├─ Retraite
├─ Famille
├─ Travail & Statut
├─ Logement
├─ Fiscalité
├─ Patrimoine & Succession
└─ Santé & Protection
```

### Décision
`Explorer` contient **7 hubs**.

Ce nombre est plus élevé que l'idéal abstrait, mais il reflète mieux le codebase réel et les modèles mentaux utilisateurs.

### Règle de structure
- 3 parcours vedettes par hub
- "Voir tout" en second niveau
- pas de liste plate de 15 outils
- éducatif lié au hub, pas isolé comme bibliothèque abstraite

---

## 6.4 Dossier

```text
Dossier
├─ Profil
├─ Confiance / complétude
├─ Documents
├─ Couple
├─ Consentements
├─ Connexions
└─ Réglages IA et app
```

### Rôle
- Être l'unique destination mentale pour "gérer mon dossier".
- Fusionner ce qui est aujourd'hui dispersé entre profile, bilan, documents, couple, consent, BYOK, SLM.

---

## 6.5 Capture contextuelle

```text
Capture
├─ Scanner un document
├─ Importer un relevé
├─ Ajouter une donnée manuelle
└─ Poser une question avec photo
```

### Décision
Pas de bouton flottant global.

La capture est une **sheet contextuelle** ou une **entrée intégrée** :
- CTA proéminent dans `Aujourd'hui`
- action d'attachement dans `Coach`
- action "ajouter une source" dans `Dossier`

### Sortie attendue
- ce qui a changé
- ce que cela débloque
- prochaine meilleure action

---

## 7. Taxonomie visible cible

### Visible
- Aujourd'hui
- Coach
- Explorer
- Dossier
- Retraite
- Famille
- Travail & Statut
- Logement
- Fiscalité
- Patrimoine & Succession
- Santé & Protection

### Invisible pour l'utilisateur
- Arbitrage
- Simulator
- Segments
- LPP deep
- 3a deep
- Advisor
- Report v2
- Ask Mint
- Open Banking comme destination top-level

---

## 8. Inventory : garder, fusionner, retirer

## 8.1 Destinations top-level

| Destination | Statut |
|---|---|
| Aujourd'hui | Créer |
| Coach | Garder et renforcer |
| Explorer | Créer |
| Dossier | Créer |

## 8.2 Écrans à garder comme destinations visibles

| Écran / route | Futur emplacement |
|---|---|
| Landing / Welcome | `/welcome` |
| Onboarding Quick Start | `/onboarding/quick-start` |
| Chiffre-Choc | `/onboarding/first-impact` |
| Coach Chat | `/app/coach` |
| Conversation History | `Coach > Historique` |
| Documents | `Dossier > Documents` |
| Profile | `Dossier > Profil` |
| Household / Couple | `Dossier > Couple` |
| Consent Dashboard | `Dossier > Consentements` |
| BYOK Settings | `Dossier > Connexions IA` |
| SLM Settings | `Dossier > IA locale` |

## 8.3 Flows à garder

### Retraite
- Retirement Dashboard
- Rente vs Capital
- Rachat LPP
- EPL
- Décaissement
- Libre Passage
- Pilier 3a
- Comparator 3a
- Real Return
- Staggered Withdrawal
- Retroactive 3a

### Famille
- Mariage
- Divorce
- Naissance
- Concubinage
- Décès proche

### Travail & Statut
- First Job
- Unemployment
- Expat
- Job Comparison
- Independant Screen
- AVS Cotisations
- Dividende vs Salaire
- LPP Volontaire
- Frontalier
- Gender Gap

### Logement
- Affordability
- Amortization
- EPL Combined
- Imputed Rental
- Saron vs Fixed
- Housing Sale
- Location vs Propriété

### Fiscalité
- Fiscal Comparator
- Cantonal Benchmark
- Déménagement cantonal
- 3a fiscal entrypoints

### Patrimoine & Succession
- Donation
- Succession
- Arbitrage Bilan
- Allocation Annuelle
- Rente vs Capital selon arbitrage final de positionnement

### Santé & Protection
- Disability Gap
- Disability Insurance
- Disability Self-Employed
- LAMal Franchise
- Coverage Check
- IJM

### Budget & Dettes
Le hub n'est pas top-level dans la navigation globale, mais c'est un sous-hub important d'Explorer si retenu comme hub additionnel dans l'implémentation. Dans la version cible finale, ses flows restent :
- Budget
- Debt Risk Check
- Debt Ratio
- Help Resources
- Repayment
- Consumer Credit
- Leasing

### Capture
- Document Scan
- AVS Guide
- Extraction Review
- Document Impact
- Bank Import
- Data Block Enrichment

## 8.4 Écrans à fusionner

| Existant | Cible |
|---|---|
| `PulseScreen` + partie de `RetirementDashboardScreen` | Aujourd'hui |
| `AskMintScreen` + `CoachChatScreen` | Coach, après intent routing |
| `ProfileScreen` + `FinancialSummaryScreen` | Dossier |
| `DocumentsScreen` + partie de `OpenBankingHubScreen` | Dossier > Sources |
| `ToolsLibraryScreen` + `ComprendreHubScreen` | Explorer |
| scan + import + enrich manuel launcher | Capture contextuelle |

## 8.5 Écrans à retirer de la navigation visible

| Existant | Sort |
|---|---|
| Tools Library | absorbé ou retiré |
| Ask Mint | absorbé en phase 2 |
| Portfolio | revalider |
| Timeline | revalider |
| Achievements | secondaire ou retiré |
| Weekly Recap | invisible tant qu'incomplet |
| Admin screens | hors navigation prod |

---

## 9. Mapping canonique des routes

## 9.1 Auth et onboarding

| Routes actuelles | Décision |
|---|---|
| `/` | garder |
| `/auth/login` | garder |
| `/auth/register` | garder |
| `/auth/forgot-password` | garder |
| `/auth/verify-email` | garder |
| `/onboarding/quick` | garder |
| `/onboarding/chiffre-choc` | garder |
| `/data-block/:type` | garder |
| `/advisor/*`, `/onboarding/smart`, `/onboarding/minimal`, `/onboarding/enrichment` | redirects techniques uniquement |

## 9.2 Aujourd'hui

| Routes actuelles | Décision |
|---|---|
| `/home` | devient shell app |
| `/retraite` | flow lié à Aujourd'hui ou Explorer selon contexte |
| `/rapport` | flow résultat / rapport |
| `/score-reveal` | moment de transition vers Aujourd'hui |

## 9.3 Coach

| Routes actuelles | Décision |
|---|---|
| `/coach/chat` | canonique |
| `/ask-mint` | absorbé en phase 2 |
| `/coach/history` | garder |
| `/coach/checkin` | garder |
| `/coach/refresh` | garder |
| `/coach/cockpit` | sous-flow coach |

## 9.4 Explorer

| Famille de routes | Décision |
|---|---|
| `/rente-vs-capital`, `/rachat-lpp`, `/epl`, `/decaissement`, `/libre-passage` | Retraite |
| `/pilier-3a`, `/3a-deep/*`, `/fiscal`, `/cantonal-benchmark`, `/life-event/demenagement-cantonal` | Fiscalité |
| `/hypotheque`, `/mortgage/*`, `/arbitrage/location-vs-propriete`, `/life-event/housing-sale` | Logement |
| `/mariage`, `/divorce`, `/naissance`, `/concubinage`, `/life-event/deces-proche` | Famille |
| `/unemployment`, `/first-job`, `/expatriation`, `/simulator/job-comparison`, `/segments/*`, `/independants/*` hors IJM | Travail & Statut |
| `/invalidite`, `/disability/*`, `/assurances/*`, `/independants/ijm` | Santé & Protection |
| `/life-event/donation`, `/succession`, `/arbitrage/bilan`, `/arbitrage/allocation-annuelle` | Patrimoine & Succession |
| `/education/hub`, `/education/theme/:id` | éducatif lié aux hubs, pas destination isolée |

## 9.5 Dossier

| Routes actuelles | Décision |
|---|---|
| `/profile` | canonique |
| `/profile/bilan` | fusionner dans Dossier |
| `/profile/consent` | garder |
| `/profile/byok` | garder |
| `/profile/slm` | garder |
| `/documents`, `/documents/:id` | garder |
| `/couple`, `/couple/accept`, `/household/*` | garder |
| `/open-banking`, `/open-banking/transactions`, `/open-banking/consents` | Dossier > Connexions |

## 9.6 Capture contextuelle

| Routes actuelles | Décision |
|---|---|
| `/scan` | canonique de scan |
| `/scan/avs-guide` | garder |
| `/scan/review` | garder |
| `/scan/impact` | garder |
| `/bank-import` | accessible via Capture et Dossier |
| `/data-block/:type` | accessible via Capture ou Dossier |

---

## 10. Classification des écrans

### Destination
Un écran qui mérite d'exister dans la carte mentale utilisateur.

### Flow
Un écran ou une suite d'écrans déclenchés par intention.

### Tool
Une capacité interne ouverte contextuellement.

### Alias legacy
Une route de compatibilité, invisible dans le langage produit.

---

## 11. Modèle d'orchestration IA

## 11.1 Vision

Le coach doit progressivement :
- comprendre l'intention,
- choisir la bonne forme de réponse,
- ouvrir le bon flow,
- contextualiser les résultats,
- renvoyer vers Aujourd'hui avec un sentiment de progrès.

## 11.2 Typologie des réponses

- Réponse courte
- Réponse + card
- Réponse + flow
- Réponse + capture

## 11.3 Règle roadmap

```text
Phase 1
Navigation directe autonome

Phase 2
Intent classifier + routing table

Phase 3
Coach-orchestrator fiable
```

Le nouveau shell ne doit pas dépendre de la maturité du coach.

---

## 12. Mode voix

Le mode voix vit dans Coach.

### Objectifs
- faible friction
- latence basse
- continuité texte / voix
- possibilité de basculer vers un flow

### Condition de wow
- la voix mène à une action ou à une compréhension meilleure
- la voix n'est pas un gadget isolé

---

## 13. Aujourd'hui comme boucle de progrès

```text
1. Aujourd'hui montre la priorité
2. L'utilisateur ouvre Coach ou Capture
3. Il agit
4. MINT calcule ce que cela change
5. Aujourd'hui se met à jour
```

### Sorties attendues
- "Ta simulation retraite est plus fiable qu'hier"
- "Ton dossier AVS débloque une analyse plus précise"
- "Tu peux maintenant comparer rente et capital avec moins d'incertitude"

---

## 14. Explorer comme anti-catalogue

Chaque hub suit ce pattern :

```text
Hub
├─ intro courte
├─ 3 parcours vedettes
├─ voir tout
├─ bloc éducatif lié
└─ entrée vers Coach
```

### Interdits
- 12 cartes plates sans hiérarchie
- juxtaposition de calculateurs sans contexte
- doublons entre hubs
- routes techniques visibles

---

## 15. Dossier comme vérité personnelle

Le Dossier n'est pas "Settings".

Le Dossier est :
- la vérité de la donnée
- la gouvernance de la confidentialité
- la preuve documentaire
- le centre de contrôle des connexions

### Sous-sections retenues
- Profil
- Confiance / complétude
- Documents
- Couple
- Consentements
- Connexions bancaires et IA
- Réglages

---

## 16. Capture comme geste signature

Le geste signature de MINT est :
**capturer une donnée réelle et voir immédiatement l'impact**.

### Conditions minimales
- entrée contextuelle claire
- choix du type d'entrée
- retour immédiat après traitement
- explication de l'impact
- prochaine action

---

## 17. Plan de migration

## Phase 1 — Shell

Objectif :
- introduire `Aujourd'hui / Coach / Explorer / Dossier`
- conserver toutes les routes existantes
- garder tous les deep links

Chantiers :
- nouveau shell
- pas de FAB global persistant
- `/home` pointe vers le nouveau shell

## Phase 2 — Aujourd'hui

Objectif :
- transformer réellement Pulse en Aujourd'hui

Chantiers :
- 1 phrase
- 1 chiffre
- 1 action
- 2 signaux max

## Phase 3 — Explorer et Dossier

Objectif :
- construire les 7 hubs
- regrouper tout le pilotage personnel dans Dossier

Chantiers :
- absorption de Tools / Comprendre
- rationalisation Profile + Documents + Couple + Consent + IA

## Phase 4 — Coach intent + Capture

Objectif :
- coach-orchestrator
- capture contextuelle unifiée

Chantiers :
- intent classifier
- routing table
- handoffs Coach -> flow
- retour vers Aujourd'hui
- fusion finale Ask Mint -> Coach

## Phase 5 — Nettoyage legacy

Objectif :
- simplifier la dette sémantique

Chantiers :
- retirer les labels techniques
- conserver les redirects nécessaires

---

## 18. 10 itérations de convergence

### Itération 1
- rejet du `chatbot-first`

### Itération 2
- adoption du `coach-first`

### Itération 3
- rejet du shell 3 tabs comme horizon final

### Itération 4
- création d'Explorer

### Itération 5
- création de Dossier

### Itération 6
- apparition de Capture comme capacité transversale

### Itération 7
- retrait des taxonomies internes visibles

### Itération 8
- classification destination / flow / tool / alias

### Itération 9
- Aujourd'hui devient boucle de progrès

### Itération 10
- révision post-audit contradictoire :
  - pas de FAB global
  - 7 hubs
  - navigation autonome avant coach-orchestrator
  - Aujourd'hui radicalement simplifié

---

## 19. Règles de décision produit

Avant d'ajouter une nouvelle route visible :

1. Est-ce une destination mentale réelle ?
2. Est-ce plutôt un flow ?
3. Est-ce plutôt un tool ouvert contextuellement ?
4. Un hub existant peut-il l'absorber ?
5. Sommes-nous en train d'exposer une taxonomie interne ?

Si 5 = oui, la route ne doit pas devenir visible.

---

## 20. Références externes

- Apple : tabs = top-level content, navigation familière, pas de confusion hiérarchique
  `https://developer.apple.com/videos/play/wwdc2022/10001/`
- Android : navigation bar primaire sur mobile compact, une seule action proéminente à la fois
  `https://developer.android.com/design/ui/mobile/guides/layout-and-content/layout-and-nav-patterns`
- OpenAI : conversation + interfaces interactives, pas conversation seule
  `https://openai.com/index/introducing-apps-in-chatgpt/`
- OpenAI Realtime : montée en puissance de la voix et des agents temps réel
  `https://developers.openai.com/api/docs/models/gpt-realtime`

---

## 21. Décision finale

La navigation cible de MINT est :

```text
Aujourd'hui
Coach
Explorer
Dossier
Capture contextuelle
```

C'est le meilleur compromis entre :
- clarté mobile
- ambition IA
- compatibilité iOS / Android
- profondeur métier
- confiance utilisateur
- faisabilité réelle à partir du codebase actuel
