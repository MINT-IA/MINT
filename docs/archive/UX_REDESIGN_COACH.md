# UX REDESIGN — MINT Coach: Du Catalogue au Coach Financier

> **Scope**: Design UX et experience utilisateur pour la transformation Coach.
> **Companions**: BLUEPRINT_COACH_AI_LAYER.md (architecture technique), MINT_COACH_VIVANT_ROADMAP.md (plan d'execution sprint).

**Date** : 19 fevrier 2026 (mise a jour)
**Auteur** : Equipe UX Creative MINT
**Statut** : Spec V2 — Plan consolide Phase 1-4

---

## LE PIVOT

### Avant (MINT Catalogue)
```
Utilisateur → Wizard → Rapport → Simulateurs → ...et apres ?
```
L'app est un **catalogue de simulateurs** : puissant, dense, educatif — mais passif.
L'utilisateur fait un bilan, lit un rapport, explore 2-3 simulateurs, puis... quitte.
Pas de raison de revenir demain. Pas de progression. Pas de "coach".

### Apres (MINT Coach)
```
Utilisateur → Profil persistant → Trajectoire → Coach mensuel → LLM contextuel
```
L'app devient un **coach financier personnel** avec :
- Un **Goal A** (retraite, achat immo, independance) avec deadline
- Des **activites mensuelles** qui alimentent un forecast
- Un **score de progression** visible en permanence
- Des **alertes proactives** ("tu derives", "bravo tu es en avance")
- Un **LLM** qui repond en contexte ("et si on achetait a Lisbonne?")

### L'analogie sportive (TrainerRoad / Humango)

| Concept Sport | Equivalent MINT |
|---------------|-----------------|
| Objectif A (course, FTP) | Goal A : retraite a 65, achat immo, etc. |
| Activite (sortie velo) | Check-in mensuel (versements, depenses) |
| TSS / Fitness Score | Financial Fitness Score (FFS) |
| Forecast (projection FTP) | Forecast retraite / capital projete |
| Coach ("tu es on-track") | Alertes proactives + coaching tips |
| Calendrier d'entrainement | Timeline financiere (3a dec, impots, etc.) |
| Zones d'entrainement | Piliers : Budget > Prevoyance > Patrimoine |

---

## NOUVELLE ARCHITECTURE DE L'INFORMATION

### Navigation Bottom Tabs (5 → 4 tabs)

```
┌─────────────────────────────────────────────────────────┐
│                    MINT Coach                            │
│                                                          │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌─────────┐ │
│  │ TABLEAU   │  │ AGIR     │  │ APPRENDRE│  │ PROFIL  │ │
│  │ DE BORD   │  │          │  │          │  │         │ │
│  └──────────┘  └──────────┘  └──────────┘  └─────────┘ │
│   Dashboard     Actions       Edu+Simul     Mon profil  │
│   (HOME)        Timeline      Catalogue     + Coach LLM │
└─────────────────────────────────────────────────────────┘
```

#### Tab 1 : TABLEAU DE BORD (Home) — "Ma trajectoire"
Le coeur de la refonte. C'est la premiere chose qu'on voit.
- Financial Fitness Score (jauge animee)
- Graphique de trajectoire (projection 3 scenarios)
- Prochaines actions (max 3)
- Alerte coach (si derive detectee)

#### Tab 2 : AGIR — "Mes actions"
La timeline d'actions financieres, comme un calendrier d'entrainement.
- Actions du mois (3a, rachat LPP, check budget)
- Timeline des rappels (hypotheque, leasing, impots)
- Check-in mensuel (confirmer les versements)
- Historique des actions completees

#### Tab 3 : APPRENDRE — "Explorer"
Le catalogue existant, reorganise par pertinence.
- Simulateurs (fiscal, LPP, hypotheque, etc.)
- Evenements de vie (18 types)
- Contenu educatif (inserts, themes)
- "J'y comprends rien" (education hub)

#### Tab 4 : PROFIL — "Mon espace"
- Profil financier complet (evolutif)
- Coach LLM (conversation)
- Mes documents (certificats, releves)
- Parametres, export, partage

### Hierarchie des ecrans

```
ONBOARDING (premiere fois)
├── Stress Check (30 sec)
├── 4 Questions d'Or (canton, age, revenu, statut)
├── Goal A Selection (quel est ton objectif principal ?)
├── Quick Forecast (premiere projection)
└── → Dashboard

DASHBOARD (tab 1 — home)
├── Financial Fitness Score
│   ├── Score global (0-100)
│   ├── Sous-scores : Budget | Prevoyance | Patrimoine
│   └── Tendance (↑ ↓ →) vs mois precedent
├── Trajectoire Graph
│   ├── 3 scenarios (prudent / base / optimiste)
│   ├── Position actuelle (point sur la courbe)
│   └── Goal A marker (avec date)
├── Coach Alert Card
│   ├── "Tu es sur la bonne trajectoire" ✅
│   ├── "Attention : 3a non verse ce mois" ⚠️
│   └── "Derive detectee : depenses +15%" 🔴
└── Quick Actions (3 max)
    ├── "Verser 3a (il reste 2 mois)"
    ├── "Check-in mensuel"
    └── "Explorer : rachat LPP"

AGIR (tab 2)
├── Ce mois
│   ├── [ ] Versement 3a Julien : 604.83 CHF
│   ├── [ ] Versement 3a Lauren : 604.83 CHF
│   ├── [ ] Rachat LPP Julien : 1000 CHF
│   ├── [ ] Rachat LPP Lauren : 500 CHF
│   └── [ ] Check-in budget
├── Timeline
│   ├── Dec 2026 : Dernier jour versement 3a
│   ├── Mar 2027 : Declaration impots VS
│   ├── Nov 2027 : Franchise LAMal (changer?)
│   └── 2042 : Retraite Julien (65 ans)
└── Historique
    ├── Jan 2026 : 3a verse ✅ | LPP 1000 ✅
    ├── Fev 2026 : 3a verse ✅ | LPP 1000 ✅
    └── ...

APPRENDRE (tab 3)
├── Recommandes pour toi
│   ├── Simulateur rachat LPP (pertinent: 300k lacune)
│   ├── Comparateur rente vs capital
│   └── Impact FATCA pour Lauren
├── Tous les simulateurs
│   ├── Fiscalite (26 cantons, demenagement, etc.)
│   ├── Prevoyance (3a, LPP, AVS, invalidite)
│   ├── Immobilier (hypotheque, EPL)
│   └── Vie courante (budget, dette, LAMal)
├── Evenements de vie (18)
└── J'y comprends rien (education hub)

PROFIL (tab 4)
├── Mon profil financier
│   ├── Identite (nom, age, canton, commune)
│   ├── Couple (conjoint, statut)
│   ├── Revenus (salaires, bonus)
│   ├── Depenses fixes
│   ├── Prevoyance (AVS, LPP, 3a)
│   ├── Patrimoine (epargne, investissements)
│   └── Dettes (credit, leasing)
├── Coach LLM 💬
│   ├── Conversation contextuelle
│   ├── "Et si on prenait la retraite au Portugal?"
│   └── "Lauren devrait-elle racheter ses 50k LPP?"
├── Mes documents
│   ├── Certificat LPP Julien
│   ├── Certificat LPP Lauren
│   └── Releves bancaires
└── Parametres
    ├── Cle API LLM (BYOK)
    ├── Langue
    ├── Notifications
    └── Export / Suppression donnees
```

---

## ECRAN 1 : LE TABLEAU DE BORD (Piece maitresse)

### Maquette conceptuelle

```
┌─────────────────────────────────────────────┐
│ ░░░░░░░░░░░░ MINT ░░░░░░░░░░░░░░░░░░░░░░░ │
│                                              │
│  Bonjour Julien                              │
│  "Tu es sur la bonne trajectoire"  ✅        │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │     FINANCIAL FITNESS SCORE            │  │
│  │                                        │  │
│  │         ┌─────────┐                    │  │
│  │         │   72    │  ↑ +3 vs janv.    │  │
│  │         │  /100   │                    │  │
│  │         └─────────┘                    │  │
│  │                                        │  │
│  │  Budget    Prevoyance    Patrimoine    │  │
│  │  ██████░░  █████████░░   ████░░░░░░   │  │
│  │    78        85              52        │  │
│  └────────────────────────────────────────┘  │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │  MA TRAJECTOIRE RETRAITE              │  │
│  │                                        │  │
│  │  Capital projete a 65 ans :            │  │
│  │  CHF 1'234'000 (scenario base)         │  │
│  │                                        │  │
│  │  ╱──── Optimiste : 1'456'000          │  │
│  │  ╱                                     │  │
│  │  ╱──── Base : 1'234'000               │  │
│  │  ╱                                     │  │
│  │  ╱──── Prudent : 987'000              │  │
│  │  ●                                     │  │
│  │  Aujourd'hui          2042 (65 ans)    │  │
│  │                                        │  │
│  │  Taux de remplacement estime : 72%     │  │
│  │  (Cible recommandee : 70-80%)    ✅    │  │
│  └────────────────────────────────────────┘  │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │  💡 COACH ALERT                       │  │
│  │                                        │  │
│  │  "Lauren a un trou AVS de 14 ans.      │  │
│  │   Impact estime : -8'400 CHF/an de     │  │
│  │   rente. Action : verifier les         │  │
│  │   possibilites de rachat AVS."         │  │
│  │                                        │  │
│  │  [Explorer →]                          │  │
│  └────────────────────────────────────────┘  │
│                                              │
│  ACTIONS RAPIDES                             │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐    │
│  │ Check-in │ │ Verser   │ │ Simuler  │    │
│  │ mensuel  │ │ 3a       │ │ rachat   │    │
│  └──────────┘ └──────────┘ └──────────┘    │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │  ⚖️ DISCLAIMER                        │  │
│  │  Estimations educatives — ne constitue │  │
│  │  pas un conseil financier. LSFin.      │  │
│  └────────────────────────────────────────┘  │
│                                              │
│  [Dashboard]  [Agir]  [Apprendre]  [Profil] │
└─────────────────────────────────────────────┘
```

### Financial Fitness Score (FFS) — Calcul

Le score est un composite de 3 sous-scores (0-100 chacun) :

```dart
class FinancialFitnessScore {
  final int budget;      // 0-100
  final int prevoyance;  // 0-100
  final int patrimoine;  // 0-100

  int get global => ((budget * 0.35) + (prevoyance * 0.40) + (patrimoine * 0.25)).round();
}
```

#### Sous-score Budget (poids: 35%)

| Critere | Points | Max |
|---------|--------|-----|
| Reste a vivre > 20% du revenu | 0-25 | 25 |
| Fonds d'urgence >= 3 mois | 0-25 | 25 |
| Pas de dette consommation | 0 ou 25 | 25 |
| Budget tenu (depenses < prevu) | 0-25 | 25 |

#### Sous-score Prevoyance (poids: 40%)

| Critere | Points | Max |
|---------|--------|-----|
| 3a maximise (7'258 CHF/an) | 0-25 | 25 |
| LPP : rachat en cours ou complete | 0-25 | 25 |
| Pas de lacune AVS critique | 0-25 | 25 |
| Couverture invalidite adequte | 0-25 | 25 |

#### Sous-score Patrimoine (poids: 25%)

| Critere | Points | Max |
|---------|--------|-----|
| Epargne investie (pas que compte) | 0-25 | 25 |
| Diversification (pas tout en 1 asset) | 0-25 | 25 |
| Croissance nette positive vs N-1 | 0-25 | 25 |
| Objectif patrimoine sur trajectoire | 0-25 | 25 |

#### Tendance et feedback coach

| Score | Couleur | Message Coach |
|-------|---------|---------------|
| 80-100 | Vert | "Excellent ! Tu es en avance sur ta trajectoire." |
| 60-79 | Vert clair | "Bien ! Tu es sur la bonne voie." |
| 40-59 | Orange | "Attention : quelques points a ameliorer." |
| 0-39 | Rouge | "Priorite : stabilisons tes bases." |

---

## ECRAN 2 : LA TRAJECTOIRE (Le graphique qui change tout)

### Le concept "Forecast adaptatif"

Comme TrainerRoad projette ton FTP futur a partir de tes entrainements,
MINT projette ton **capital retraite** (ou autre Goal A) a partir de tes versements reels.

```
MOTEUR DE PROJECTION

Inputs mensuels :
  - Salaire brut Julien : 9'080 × 13 + 7% bonus = ~126'300 CHF/an
  - Salaire brut Lauren : 5'000 × 12 = 60'000 CHF/an
  - 3a Julien : 604.83 CHF/mois (→ 7'258/an)
  - 3a Lauren : 604.83 CHF/mois (→ 7'258/an)
  - Rachat LPP Julien : 1'000 CHF/mois
  - Rachat LPP Lauren : 500 CHF/mois
  - Epargne IB Julien : 1'000 CHF/mois
  - Epargne Lauren : 500 CHF/mois

Hypotheses de rendement (3 scenarios) :
  Prudent : LPP 1%, 3a 2%, IB 3%
  Base    : LPP 2%, 3a 4%, IB 6%
  Optimiste : LPP 3%, 3a 6%, IB 9%

Projection a 65 ans (Julien, 16 ans) :
  AVS couple : ~43'000 CHF/an (avec lacunes Lauren)
  LPP Julien : rente ou capital (~500-800k selon rachat)
  LPP Lauren : rente minimale (~200-300k)
  3a Julien : 5 comptes → retrait echelonne
  3a Lauren : impossible (US citizen) → epargne libre
  IB Julien : ~100k + 1000/mois × 16 ans + rendement
  Epargne Lauren : ~500/mois × 16 ans

Output : Capital total projete + Revenu annuel retraite + Taux de remplacement
```

### Interaction avec le graphique

```
GESTES :
- Swipe horizontal : naviguer dans le temps (2026 → 2042)
- Tap sur un point : voir le detail a cette date
- Pinch : zoom in/out sur une periode
- Tap sur scenario : basculer prudent/base/optimiste
- Slider "Et si..." : modifier un parametre et voir l'impact en temps reel

EXEMPLES "ET SI..." :
- "Et si j'augmente mon rachat LPP a 2000/mois ?"
  → La courbe se met a jour en live
- "Et si les marches font -20% en 2027 ?"
  → Impact visible immediatement
- "Et si Lauren commence a investir via ETF ?"
  → Voir l'impact US citizen sur les options
```

---

## ECRAN 3 : LE CHECK-IN MENSUEL (L'activite)

### Le concept

Chaque mois, l'utilisateur "enregistre son activite financiere" — comme
on enregistre une sortie velo sur Strava. Ca prend 2 minutes.

### Flow du check-in

```
┌─────────────────────────────────────────────┐
│  CHECK-IN FEVRIER 2026                       │
│                                              │
│  Confirme tes versements du mois :           │
│                                              │
│  3a Julien (VIAC)     [604.83] ✅ Auto      │
│  3a Lauren             [604.83] ✅ Auto      │
│  Rachat LPP Julien    [1'000]  ✅ Auto      │
│  Rachat LPP Lauren    [500]    ✅ Auto      │
│  Epargne IB Julien    [1'000]  ⬜ Manuel    │
│  Epargne Lauren       [500]    ⬜ Manuel    │
│                                              │
│  Depenses exceptionnelles ?                  │
│  [+ Ajouter]                                 │
│                                              │
│  Revenus exceptionnels ?                     │
│  Bonus annuel : [_______] (si applicable)    │
│                                              │
│  [Valider le check-in]                       │
└─────────────────────────────────────────────┘

          ↓ Apres validation ↓

┌─────────────────────────────────────────────┐
│  BRAVO ! Check-in fevrier complete ✅        │
│                                              │
│  Score du mois : 92/100 (+4 vs janvier)      │
│                                              │
│  📈 Impact sur ta trajectoire :              │
│  Capital projete +2'104 CHF ce mois          │
│  (dont +604 3a, +1000 LPP, +500 epargne)    │
│                                              │
│  🏆 Serie : 2 mois consecutifs on-track !    │
│                                              │
│  💡 Tip du coach :                           │
│  "Ton bonus annuel arrive bientot (~8'841).  │
│   Si tu en affectes 50% au rachat LPP,       │
│   tu gagnes ~1'325 CHF d'economie fiscale."  │
│                                              │
│  [Voir ma trajectoire mise a jour]           │
└─────────────────────────────────────────────┘
```

### Gamification (subtile, pas infantilisante)

| Element | Inspiration | MINT |
|---------|-------------|------|
| Streak | Duolingo / Strava | "X mois consecutifs on-track" |
| Milestone | TrainerRoad | "100k CHF de capital prevoyance atteint" |
| Comparaison | Strava segments | "Ton taux d'epargne est dans le top 20% pour ton age" |
| Badge | Apple Watch | "3a maximise 3 annees de suite" |

**Regle d'or** : Jamais de comparaison sociale avec d'autres utilisateurs.
Uniquement comparaison avec soi-meme et avec les moyennes statistiques OFS.

---

## ECRAN 4 : LE COACH LLM

### UX du coach

Le coach est accessible depuis Tab 4 (Profil) via un bouton flottant
ou une section dediee. Ce n'est PAS un chatbot generique — c'est un
**conseiller contextuel** qui a acces a tout le profil et au moteur de calcul.

### Architecture LLM

```
┌──────────────────────────────────────────────┐
│  UTILISATEUR                                  │
│  "Lauren devrait-elle racheter ses 50k LPP?"  │
└──────────────────┬───────────────────────────┘
                   │
┌──────────────────▼───────────────────────────┐
│  ORCHESTRATEUR MINT                           │
│                                               │
│  1. Extraction contexte :                     │
│     - Lauren, 45 ans, canton VS               │
│     - Caisse Hotela, minimum LPP              │
│     - Rachat possible : 50k                   │
│     - Salaire brut : 60k/an                   │
│     - US citizen (FATCA)                       │
│                                               │
│  2. Calcul deterministe (rules_engine) :      │
│     - Economie fiscale rachat 50k en VS :     │
│       ~50'000 × ~30% taux marginal = ~15'000  │
│     - Mais echelonne sur 3-5 ans :            │
│       Annee 1: 10k → eco ~3'000               │
│       Annee 2: 10k → eco ~3'000               │
│       ...                                     │
│     - Rendement LPP Hotela : ~1-2%            │
│     - Contrainte : blocage 3 ans (art. 79b)   │
│                                               │
│  3. Contexte legal (RAG) :                    │
│     - LPP art. 79b al. 3 (blocage)            │
│     - LIFD art. 33 (deduction)                │
│     - FATCA : pas d'impact sur LPP suisse     │
│                                               │
│  4. Prompt LLM (BYOK) :                       │
│     System: "Tu es un educateur financier..."  │
│     Context: [profil + calculs + sources]      │
│     Question: "Lauren devrait-elle racheter?"  │
│                                               │
│  5. Guardrails post-generation :              │
│     - Pas de "garanti", "certain"             │
│     - Disclaimer present                       │
│     - Sources citees                           │
│     - Chiffres valides vs rules_engine         │
└──────────────────┬───────────────────────────┘
                   │
┌──────────────────▼───────────────────────────┐
│  REPONSE COACH                                │
│                                               │
│  "Le rachat LPP de Lauren presente un         │
│   levier fiscal interessant en Valais          │
│   (taux marginal estime ~30%).                 │
│                                               │
│   Scenario echelonne sur 5 ans :               │
│   - 10'000 CHF/an de rachat                   │
│   - ~3'000 CHF/an d'economie fiscale          │
│   - Total economie : ~15'000 CHF sur 5 ans    │
│                                               │
│   Points d'attention :                         │
│   - Rendement Hotela tres bas (~1-2%)          │
│   - Blocage EPL 3 ans apres rachat            │
│   - Le 3a n'est pas une option pour Lauren    │
│     (US citizen → FATCA)                       │
│   - Le rachat LPP est donc l'un des rares     │
│     leviers fiscaux disponibles pour elle      │
│                                               │
│   Sources : LPP art. 79b, LIFD art. 33"       │
│                                               │
│   [Voir l'impact sur la trajectoire]          │
│                                               │
│   ⚖️ Ne constitue pas un conseil financier.   │
│   Consulte un·e specialiste pour valider.      │
└──────────────────────────────────────────────┘
```

### Exemples de questions contextuelles

Le coach propose des questions basees sur le profil :

```
QUESTIONS SUGGEREES (basees sur le profil Julien+Lauren) :

📊 "Quel sera notre revenu a la retraite ?"
🏠 "Peut-on acheter un bien a Sion dans 5 ans ?"
✈️  "Et si on prenait la retraite au Portugal ?"
💰 "Comment optimiser le bonus annuel ?"
🇺🇸 "Quelles sont les options d'investissement pour Lauren (US citizen) ?"
📈 "Vaut-il mieux accelerer le rachat LPP ou investir en ETF ?"
🏥 "Que se passe-t-il si l'un de nous tombe malade ?"
```

---

## MODELE FREEMIUM — MINT Free vs MINT Coach

### MINT Free (0 CHF — perpetuel)

Tout le catalogue existant reste gratuit :
- Wizard + rapport de base
- Tous les simulateurs (fiscal, LPP, hypotheque, etc.)
- Contenu educatif complet
- Score de base (ponctuel, pas evolutif)
- 18 evenements de vie
- Comparateur 26 cantons
- Budget (sans historique)

**Valeur** : MINT Free est deja plus complet que 90% des outils du marche.
C'est le "hook" — il prouve la valeur avant de demander quoi que ce soit.

### MINT Coach (4.90 CHF/mois)

Le passage de "calculatrice" a "coach" :

| Feature | Free | Coach |
|---------|------|-------|
| Simulateurs | ✅ Tous | ✅ Tous |
| Rapport ponctuel | ✅ | ✅ |
| Score ponctuel | ✅ | ✅ |
| **Dashboard trajectoire** | ❌ | ✅ |
| **Forecast adaptatif** | ❌ | ✅ |
| **Check-in mensuel** | ❌ | ✅ |
| **Score evolutif + tendance** | ❌ | ✅ |
| **Alertes proactives** | ❌ | ✅ |
| **Historique progression** | ❌ | ✅ |
| **Profil couple** | ❌ | ✅ |
| **Coach LLM** | ❌ | ✅ (BYOK) |
| **Scenarios "Et si..."** | ❌ | ✅ |
| **Export PDF rapport** | ❌ | ✅ |

### Justification du prix

```
4.90 CHF/mois = 58.80 CHF/an

Valeur generee (cas Julien+Lauren) :
- Economie fiscale 3a : ~4'300 CHF/an (x2 = ~8'600)
- Economie fiscale rachat LPP : ~3'000-4'000/an
- Optimisation franchise LAMal : ~500-1'000/an
- Visibilite sur lacunes AVS Lauren : prevention ~8'400/an de gap

ROI : 58.80 CHF → 15'000+ CHF de valeur annuelle
     = ROI > 250x
```

### Paywall UX — Le "Aha Moment"

Le paywall se declenche APRES que l'utilisateur a vecu la valeur :

```
FLOW :

1. Wizard gratuit → Rapport gratuit → Score ponctuel
   "Tu as un score de 72/100. Voici tes 3 priorites."

2. L'utilisateur explore 2-3 simulateurs gratuits
   "Ton rachat LPP genererait ~3'000 CHF d'economie/an"

3. MOMENT CLE : L'utilisateur veut SUIVRE sa progression
   → "Pour voir comment ton score evolue mois apres mois
      et recevoir des alertes quand tu derives..."
   → [Debloquer MINT Coach — 4.90/mois]
   → Essai gratuit 14 jours

4. Alternative : L'utilisateur veut poser une question au LLM
   → "Pour discuter avec ton coach financier personnel..."
   → [Debloquer MINT Coach — 4.90/mois]
```

**Regle** : Jamais de paywall avant que l'utilisateur ait obtenu
au moins 1 insight actionnable gratuit.

---

## PROFIL FINANCIER PERSISTANT — Structure de donnees

### Modele `FinancialProfile` (evolutif)

```dart
class FinancialProfile {
  // === IDENTITE ===
  String? firstName;
  int birthYear;
  String canton;
  String? commune;
  String etatCivil; // celibataire, marie, divorce, veuf
  int nombreEnfants;

  // === CONJOINT (si marie/concubinage) ===
  ConjointProfile? conjoint;

  // === REVENUS ===
  double salaireBrutMensuel;
  int nombreDeMois; // 12, 13, 13.5
  double? bonusPourcentage;
  String employmentStatus; // salarie, independant, chomage, retraite

  // === DEPENSES FIXES ===
  double loyer;
  double assuranceMaladie;
  double? electricite;
  double? transport;
  double? telecom;
  double? fraisMedicaux;
  double? autresDepensesFixes;

  // === PREVOYANCE ===
  PrevoyanceProfile prevoyance;

  // === PATRIMOINE ===
  PatrimoineProfile patrimoine;

  // === DETTES ===
  DetteProfile dettes;

  // === OBJECTIFS ===
  GoalA goalA; // Objectif principal
  List<GoalB> goalsB; // Objectifs secondaires

  // === HISTORIQUE ===
  List<MonthlyCheckIn> checkIns;
  List<FinancialFitnessScore> scoreHistory;
}

class ConjointProfile {
  String? firstName;
  int? birthYear;
  double? salaireBrutMensuel;
  String? nationality; // important pour FATCA
  bool? canInvest3a; // false si US citizen
  PrevoyanceProfile? prevoyance;
}

class PrevoyanceProfile {
  // AVS
  int? anneesContribuees;
  int? lacunesAVS; // annees manquantes
  double? renteAVSEstimee;

  // LPP
  String? nomCaisse;
  double? avoirObligatoire;
  double? avoirSurobligatoire;
  double? rachatMaximum;
  double? rachatEffectue;
  double tauxConversion;
  double rendementCaisse;

  // 3a
  int nombre3a;
  double totalEpargne3a;
  List<Compte3a>? comptes3a;
  bool canContribute3a; // false si US citizen
}

class PatrimoineProfile {
  double epargneLiquide;
  double? investissements;
  double? immobilier;
  String? deviseInvestissements; // CHF, USD, EUR
  String? plateformeInvestissement; // Interactive Brokers, etc.
}

class GoalA {
  String type; // 'retraite', 'achatImmo', 'independance', 'custom'
  DateTime targetDate;
  double? targetAmount;
  String label;
}

class GoalB {
  String label; // 'voyage', 'voiture', 'formation', etc.
  double targetAmount;
  DateTime? targetDate;
  int priority;
}

class MonthlyCheckIn {
  DateTime month;
  Map<String, double> versements; // '3a_julien': 604.83, etc.
  double? depensesExceptionnelles;
  double? revenusExceptionnels;
  String? note;
  DateTime completedAt;
}
```

---

## MOTEUR DE PROJECTION (Forecaster)

### Architecture du service

```dart
class ForecasterService {
  /// Projette le capital total a une date cible
  /// avec 3 scenarios (prudent, base, optimiste)
  static ProjectionResult project({
    required FinancialProfile profile,
    required DateTime targetDate,
  });
}

class ProjectionResult {
  final ProjectionScenario prudent;
  final ProjectionScenario base;
  final ProjectionScenario optimiste;
  final double tauxRemplacementBase; // % du revenu actuel
  final List<ProjectionMilestone> milestones;
}

class ProjectionScenario {
  final String label;
  final List<ProjectionPoint> points; // mensuels
  final double capitalFinal;
  final double revenuAnnuelRetraite;
  final Map<String, double> decomposition;
  // { 'avs': 43000, 'lpp': 24000, '3a': 8000, 'libre': 12000 }
}

class ProjectionPoint {
  final DateTime date;
  final double capitalCumule;
  final double contributionMensuelle;
  final double rendementCumule;
}

class ProjectionMilestone {
  final DateTime date;
  final String label;
  final double amount;
  // ex: "100k de capital prevoyance", "3a rempli 5eme annee"
}
```

### Formules de projection

```
Pour chaque mois M de maintenant a targetDate :

1. AVS :
   rente_avs_julien = min(30'240, rente_base × facteur_annees)
   rente_avs_lauren = min(30'240, rente_base × facteur_annees_lauren)
   rente_couple = min(rente_avs_julien + rente_avs_lauren, 30'240 × 1.5)
   Note: Lauren a ~14 ans de lacune → impact significatif

2. LPP :
   avoir_lpp[M] = avoir_lpp[M-1] + cotisation_mensuelle + rachat_mensuel
   avoir_lpp[M] *= (1 + rendement_annuel/12)
   capital_lpp_final = avoir_lpp[targetDate]
   rente_lpp = capital_lpp_final × taux_conversion

3. 3a :
   pour chaque compte :
     solde_3a[M] = solde_3a[M-1] + versement_mensuel
     solde_3a[M] *= (1 + rendement_3a/12)
   capital_3a_final = somme des comptes

4. Epargne libre :
   epargne[M] = epargne[M-1] + versement_mensuel
   epargne[M] *= (1 + rendement/12)
   Attention IB Julien : rendement en USD → risque de change

5. Capital total :
   capital = capital_lpp + capital_3a + epargne_libre
   revenu_retraite = rente_avs + rente_lpp + retrait_3a_annualise + rendement_libre
   taux_remplacement = revenu_retraite / revenu_actuel_net
```

### Hypotheses de rendement par scenario

| Asset | Prudent | Base | Optimiste |
|-------|---------|------|-----------|
| LPP (caisse) | 1.0% | 2.0% | 3.0% |
| 3a VIAC/Finpens | 2.0% | 4.5% | 7.0% |
| Interactive Brokers | 3.0% | 6.0% | 9.0% |
| Epargne compte | 0.5% | 1.0% | 1.5% |
| Inflation | 1.5% | 1.5% | 1.5% |

---

## COMMENT L'EXISTANT S'INTEGRE

### Mapping MINT actuel → MINT Coach

| Existant | Nouveau role |
|----------|-------------|
| Wizard (onboarding) | Alimente le profil initial |
| Rapport financier | Devient la "photo" a l'instant T (gratuit) |
| Simulateurs | Restent dans Tab "Apprendre" (gratuits) |
| Timeline service | Evolue en "Calendrier d'actions" (Tab Agir) |
| Coaching engine | Alimente les alertes du Dashboard |
| Circle Score | Evolue en Financial Fitness Score |
| Goal Templates | Devient le Goal A + Goals B |
| Budget module | S'integre au check-in mensuel |
| Educational inserts | Restent contextuels dans les simulateurs |
| Fiscal comparator | Reste dans Tab "Apprendre" |
| Safe Mode | Toujours actif — bloque les features premium si dette |

### Ce qui est NOUVEAU

| Feature | Effort estime |
|---------|--------------|
| Financial Fitness Score (calcul + widget) | 1 sprint |
| Trajectory Graph (CustomPainter) | 2 sprints |
| Forecaster Service (moteur de projection) | 2 sprints |
| Check-in mensuel (ecran + storage) | 1 sprint |
| Profil persistant etendu | 1 sprint |
| Coach LLM integration (BYOK) | 2 sprints |
| Dashboard redesign | 1 sprint |
| Tab Agir (timeline enrichie) | 1 sprint |
| Paywall + subscription | 1 sprint |
| **TOTAL** | **~12 sprints** |

---

## PERSONA WALKTHROUGH : JULIEN & LAUREN

### Premier lancement

```
1. STRESS CHECK : "Securiser ma retraite" → pension
2. 4 QUESTIONS D'OR :
   - Canton : VS (Sion)
   - Age : 49
   - Revenu brut : 9'080/mois × 13 + 7% bonus
   - Statut : Marie

3. GOAL A : "Retraite a 65 ans avec 70% du revenu"
   → Date : 2042
   → Revenu cible : ~8'600 CHF/mois (70% de ~12'300 net)

4. RAPPORT INITIAL (gratuit) :
   Score ponctuel : 68/100
   - Budget : 75 (bon reste a vivre)
   - Prevoyance : 62 (lacunes AVS Lauren, caisse LPP Hotela faible)
   - Patrimoine : 58 (IB bien, mais Lauren ne peut pas investir)

5. → "Pour suivre ta progression mois apres mois..."
   → MINT Coach 4.90/mois → Essai 14 jours
```

### Premier check-in (mars 2026)

```
- 3a Julien : 604.83 ✅
- 3a Lauren : 604.83 ✅
- Rachat LPP Julien : 1'000 ✅
- Rachat LPP Lauren : 500 ✅
- IB Julien : 1'000 ✅
- Epargne Lauren : 500 ✅

Score : 71/100 (+3 vs initial)
Trajectoire : capital projete 1'234'000 (base)
Coach : "Super debut ! Serie de 1 mois. Le rachat LPP de
         Lauren est strategique vu qu'elle n'a pas acces au 3a."
```

### Apres 6 mois (septembre 2026)

```
Score : 76/100 (+8)
Trajectoire : capital projete 1'267'000 (+33k vs mars)
Milestone : "50k d'epargne 3a atteint !"
Coach : "Tu approches du moment ideal pour ouvrir un 6eme
         compte 3a (retrait echelonne). On en parle ?"
```

### Question au coach LLM

```
Julien : "Et si on achetait un appartement a Sion ?"

Coach : "Voici l'analyse basee sur votre profil :

Capacite d'emprunt estimee :
- Revenu brut couple : ~186'300 CHF/an
- Fonds propres disponibles :
  • Epargne liquide : ~15'000
  • 3a Julien (retirable EPL) : ~42'000
  • LPP Julien (EPL max) : variable
  • IB : 100k+ (mais en USD)
  • 3a Lauren : ~7'800 (faible)

- Prix max avec 20% fonds propres : ~600-700k
- Prix median Sion 4.5 pieces : ~650-750k
- Capacite theorie (5%+1%+1%) : ~680k max

⚠️ Points d'attention :
- Retirer du LPP = reduire la rente retraite
- Blocage rachat LPP 3 ans apres EPL
- IB en USD → risque de change + fiscalite

Impact sur ta trajectoire retraite :
→ Capital retraite -80k si EPL 3a+LPP
→ Mais : economie loyer ~1'980/mois = ~23'760/an
→ + valeur locative (deductible partiellement)
→ Break-even vs location : ~15 ans

Source : OPP2 art. 5, LIFD art. 33 ter"
```

---

## DESIGN SYSTEM — EVOLUTION

### Palette etendue (MintColors v2)

La palette actuelle (neo-sober anthracite) reste. On ajoute :

```dart
// Trajectory colors
static const Color trajectoryOptimiste = Color(0xFF24B14D); // success
static const Color trajectoryBase = Color(0xFF007AFF);       // info blue
static const Color trajectoryPrudent = Color(0xFFFF9F0A);    // warning

// Score gradient
static const Color scoreExcellent = Color(0xFF24B14D);
static const Color scoreBon = Color(0xFF8BC34A);
static const Color scoreAttention = Color(0xFFFF9F0A);
static const Color scoreCritique = Color(0xFFFF453A);

// Coach
static const Color coachBubble = Color(0xFFF0F7FF);
static const Color coachAccent = Color(0xFF007AFF);
```

### Nouveaux widgets

```
MintScoreGauge      — Jauge circulaire animee (CustomPainter)
MintTrajectoryChart — Graphique de projection (CustomPainter)
MintCheckInCard     — Carte de confirmation de versement
MintCoachBubble     — Bulle de message du coach
MintGoalCard        — Carte d'objectif avec progression
MintStreakBadge     — Badge de serie (subtil)
MintPaywallSheet    — Bottom sheet pour upgrade Coach
```

---

## PLAN CONSOLIDE PHASE 1-4

### PHASE 1 — Foundations (MVP data + onboarding + baseline)

**Objectif** : passer de "questionnaire" a "diagnostic actionnable en 3 minutes".

**Scope produit**
- Onboarding V3 en 4 etapes: minimum vital, stress check, objectif principal, baseline visuelle.
- Profil persistant etendu (single/couple, statut emploi, prevoyance, dettes, devises).
- Snapshot "Etat actuel si rien ne change" + 3 priorites automatiques.
- Dashboard minimal: score global, 1 graphe baseline, 3 actions.

**Scope technique**
- Contrats de donnees alignes `SOT.md`.
- Reutilisation du forecaster deterministe pour calcul baseline (pas de calcul LLM).
- Instrumentation analytics initiale (events onboarding, baseline, first action).

**Definition of Done**
- `flutter analyze` sans nouvelles erreurs.
- Tests de calcul critiques onboarding/baseline.
- Wording conforme `LEGAL_RELEASE_CHECK.md`.

### PHASE 2 — Coach Loop (Dashboard + Agir + check-in mensuel)

**Objectif** : installer la boucle de progression mensuelle.

**Scope produit**
- Dashboard "Now vs With MINT actions".
- Tab Agir priorise par impact CHF, effort, urgence.
- Check-in mensuel 2 minutes avec impact immediat sur projection.
- Alertes proactives (derive budget, 3a manquant, rachat non execute).

**Scope technique**
- Timeline unifiee actions/rappels/evenements.
- Moteur de priorisation (impact net retraite + reduction risque).
- Tests e2e de boucle: check-in -> recalcul -> dashboard.

**Definition of Done**
- 1 test smoke par ecran coeur (`Dashboard`, `Agir`, `Profil`).
- 1 suite d'assertions numeriques sur les widgets de synthese.
- 0 regression sur simulateurs existants.

### PHASE 3 — Simulation Lab (sliders, couples, rente vs capital)

**Objectif** : rendre la simulation continue, lisible, et decisionnelle.

**Scope produit**
- Sliders temps reel: epargne, rachat LPP, retraite anticipee, rendement, inflation.
- Toggle rente vs capital + mode mixte.
- Vue couple: trou AVS, plafond couple, timeline survivant.
- Tableau detaille par source (AVS/LPP/3a/libre) avec decomposition.

**Scope technique**
- Orchestrateur de scenarios prudent/base/optimiste.
- Shared calculation engine pour ecrans + export.
- Suite de tests limites: revenus 0, montants tres eleves, ages bornes, statuts incoherents.

**Definition of Done**
- Precision stable des projections sur cas de reference.
- Performance mobile acceptable (pas de stutter visible sur ecrans graphe).
- Explications pedagogiques contextuelles reliees aux donnees simulees.

### PHASE 4 — BYOK + Docs/RAG + Industrialisation

**Objectif** : ajouter un coach conversationnel fiable et gouverne.

**Scope produit**
- BYOK in-app (gestion cle, validation, mode degrade).
- Coach LLM contextuel relie au profil et aux simulations.
- Reponses structurees: synthese, options, risques, disclaimer.
- Export rapport decisionnel PDF.

**Scope technique**
- LLM strictement non-calculateur: chiffres issus des services deterministes.
- Pipeline docs/RAG traceable: source, version, date de validite, citations.
- Post-guardrails compliance (mots interdits, promesses, certitudes).
- Observabilite: taux d'erreurs BYOK, latence, qualite reponses.

**Definition of Done**
- Journalisation des sources utilisees par reponse.
- Tests de garde-fous legal/compliance.
- Fallback robuste si BYOK indisponible.

---

## INTEGRATION BYOK + DOCS (CADRE OPERATIONNEL)

### Principes non-negociables
- Le moteur de calcul MINT reste la source numerique unique.
- Le LLM explique, reformule, priorise; il ne compute jamais seul.
- Chaque affirmation metier cite la source doc/juridique quand applicable.

### Sources et gouvernance documentaire
- Contrats de donnees et schemas: `SOT.md`.
- Exigences qualite: `DefinitionOfDone.md`.
- Guardrails wording: `LEGAL_RELEASE_CHECK.md`.
- Vision produit/UX: `visions/vision_product.md`, `visions/vision_features.md`.
- Couverture evenements: `docs/ROADMAP_EVENEMENTS_VIE.md`.

### Flux reponse coach (resume)
1. Recuperer contexte utilisateur (profil + etat financier + scenario actif).
2. Calcul deterministe (services MINT).
3. Selection d'extraits doc/sources (RAG controle).
4. Generation LLM BYOK.
5. Verification post-generation (coherence chiffres, langage, disclaimer).

---

## PERSONAS PRIORITAIRES (3)

### Persona A — Couple CH/US pre-retraite (49/45)
- Enjeu: arbitrage rachat LPP vs marche, trou AVS conjoint, rente vs capital.
- UX attendue: comparateur de strategies avec point d'equilibre et risque survivant.
- KPI persona: % couples qui activent une action de prevoyance sous 7 jours.

### Persona B — Jeune actif sur-endette (20 ans, ZH)
- Enjeu: cashflow negatif, consommation financee, risque dette toxique.
- UX attendue: visualisation choc "trajectoire actuelle" vs "trajectoire corrigee".
- KPI persona: baisse du ratio charges fixes/revenu en 30 jours.

### Persona C — Jeune diplome mal equipe (25 ans, contrat 3a assurance rigide)
- Enjeu: manque de litteratie financiere, mauvais produit longue duree.
- UX attendue: education guidee + simulateur cout d'opportunite clair.
- KPI persona: comprehension des options et activation d'une action documentee.

---

## KPI FRAMEWORK (PRODUIT + IMPACT)

### Acquisition et activation
- Time-to-first-aha < 3 minutes.
- Completion onboarding > 70%.
- First action rate (J+1) > 35%.

### Engagement coach
- Monthly Active Coached Users (north star).
- Check-in mensuel complete > 60%.
- Retour mensuel M+1 > 50% (segment coach).

### Impact financier utilisateur
- % utilisateurs avec projection retraite amelioree a 90 jours.
- Reduction mediane du deficit retraite projete.
- Augmentation mediane de l'effort d'epargne utile (pas brute).

### Fiabilite et confiance
- 0 erreur critique de calcul en production.
- Taux de divergence API/UI < 1%.
- Taux de reponses LLM avec sources + disclaimer > 98%.

---

## PILOTAGE OPERATIONNEL V3 (RACI LEGER + JALONS)

### RACI simplifie (roles)
- `Product Lead`: priorisation, scope, arbitrages go/no-go.
- `Mobile Lead`: UX mobile, widgets, perf rendering, instrumentation front.
- `Backend Lead`: calculs deterministes, contrats API, tests metier.
- `Swiss/Compliance Lead`: validation legal wording + coherence finance suisse.

### Plan d'execution par phase

| Phase | Owner principal | Dependances critiques | Date cible (proposee) | Gate go/no-go | KPI cible par phase |
|------|------------------|-----------------------|------------------------|---------------|---------------------|
| Phase 1 Foundations | Product + Mobile | Contrats `SOT.md`, baseline forecaster stable, wording legal | 30 avril 2026 | Onboarding < 6 min, baseline affichee, tests critiques pass | Principal: completion onboarding > 70%. Risque: taux d'abandon avant baseline < 20%. |
| Phase 2 Coach Loop | Mobile + Backend | Priorisation actions, check-in persistant, events analytics | 30 juin 2026 | Boucle check-in -> recalcul -> dashboard fiable en prod | Principal: check-in mensuel complete > 60%. Risque: echec recalcul post check-in < 1%. |
| Phase 3 Simulation Lab | Backend + Mobile | Moteur scenario shared, perfs chart, jeux de tests limites | 31 aout 2026 | Sliders live sans stutter + precision projections stable | Principal: first simulation interaction rate > 55%. Risque: latence p95 recalcul sliders < 250 ms. |
| Phase 4 BYOK + Docs/RAG | Backend + Compliance | RAG versionne, guardrails post-gen, fallback BYOK | 31 octobre 2026 | Reponses sourcees + disclaimer + 0 calcul hors moteur | Principal: adoption coach BYOK (users eligibles) > 25%. Risque: reponses sans source/disclaimer < 2%. |

### Definition de done par jalon (pilotage)
- `M1 (15 mars 2026)`: schema profil v3 fige, events analytics v1 instrumentes.
- `M2 (15 mai 2026)`: dashboard now-vs-future en beta interne, alertes de base actives.
- `M3 (15 juillet 2026)`: check-in mensuel + priorisation ROI disponibles en beta testeurs.
- `M4 (15 septembre 2026)`: simulation lab couple/single avec tests extremes verts.
- `M5 (15 novembre 2026)`: coach BYOK/doc traceable actif avec guardrails compliance.

### Regles de gouvernance sprint
- Aucun sprint ferme si test numerique critique en echec.
- Aucun wording user-facing merge sans validation `LEGAL_RELEASE_CHECK.md`.
- Toute evolution contrat API implique revue de parite API/UI dans le meme sprint.
- Les hypotheses de projection (rendement, inflation, taux conversion) sont versionnees et datees.

---

## ETAT D'EXECUTION ONBOARDING (19 FEVRIER 2026)

### Deja en place
- Mini-onboarding en 4 etapes avec preview de trajectoire avant activation dashboard.
- Profil partiel persistant (precision ~15%) et dashboard partiel exploitable immediatement.
- Instrumentation onboarding (start, step, durations, completion, abandonment, CTA).
- Architecture i18n active (FR/EN/DE/ES/IT/PT) sans hardcode bloqueur sur les nouveaux ecrans.
- Reset granulaire disponible (diagnostic vs historique coach).

### Ajout immediate (state of the art)
- Assignation A/B persistente pour le mini-onboarding (`control` vs `challenge`).
- Event d'exposition experimentale trace une seule fois par utilisateur.
- Tous les events onboarding enrichis avec contexte `experiment + variant`.
- Variante `challenge` qui modifie la priorisation visuelle des cartes Step 1
  pour mesurer l'impact sur completion et first action.
- Step 2/3 en mode friction reduite: quick picks annee de naissance + revenus
  pour limiter la saisie clavier et accelerer le time-to-first-aha.
- Instrumentation usage presets vs saisie manuelle pour lire le vrai levier UX.
- Step 2 "A-ha card" live (age + canton) avec copy factuelle vs emotionnelle
  selon variante pour tester l'effet sur progression vers Step 3/4.
- Exit-rescue modal contextuelle (anti-abandon) + autosave progressif a chaque
  transition d'etape pour reprise sans friction.
- Panel d'observabilite onboarding in-app (icone insights) avec KPI locaux
  par variante: completion, stay rate sortie, conversion A-ha Step2 -> Step3.
- ETA predicitive en temps reel (restant en secondes) basee sur durees
  historiques par etape et variante.
- Interception du back systeme (hardware gesture) avec meme logique anti-abandon
  que le bouton fermer.

### KPI d'experimentation onboarding (v1)
- `completion_rate_by_variant` : completion mini-onboarding par variante.
- `drop_off_step_by_variant` : abandon par etape et variante.
- `time_to_complete_by_variant` : mediane secondes jusqu'a completion.
- `wizard_upgrade_rate_by_variant` : taux d'upsell vers diagnostic complet.
- `first_action_j1_by_variant` : action J+1 apres mini-onboarding.
- `step2_aha_to_step3_rate_by_variant` : taux de passage Step 2 -> Step 3
  apres affichage du bloc A-ha.
- `exit_prompt_stay_rate_by_variant` : part des utilisateurs qui choisissent
  "Continuer" apres affichage du prompt de sortie.

### Gate de decision (A/B)
- Garder la variante gagnante si:
  - +5 points de completion rate minimum, et
  - pas de degradation du `first_action_j1` (> -1 point max).
- Sinon rollback sur `control` et lancer iteration UX suivante.

---

## RISQUES ET MITIGATIONS

| Risque | Mitigation |
|--------|------------|
| Forecast percu comme "boite noire" | Afficher hypotheses, sensibilites et decomposition par pilier |
| Effet anxiogene sur profils fragiles | UX graduelle + priorites limitees + ton non culpabilisant |
| Hallucination LLM / texte non conforme | Calcul deterministe, RAG trace, post-guardrails stricts |
| Cas FATCA/US mal traites | Flag explicite, parcours dedie, options restreintes visibles |
| Dette toxique ignoree au profit d'optimisation | Safe Mode prioritaire: dette avant optimisation fiscale |
| Dette technique et regressions UX | Tests numeriques + smoke multi-ecrans + audit trimestriel |

---

## CONCLUSION EXECUTIVE

La refonte doit etre pilotee par une logique simple:
1. Montrer la realite actuelle sans filtre.
2. Donner 3 actions a plus fort impact.
3. Prouver visuellement l'effet de chaque action.
4. Installer une boucle mensuelle durable.

Le plan Phase 1-4 permet de livrer vite une valeur tangible, puis d'industrialiser
le coach BYOK/docs sans compromettre la fiabilite des calculs ni la compliance.

---

## ONBOARDING REMEDIATION P0-P3 (MOBILE) — ETAT AU 19 FEVRIER 2026

### P0 (livre)
- Debug metrics panel masque hors debug build (icone desactivee en prod).
- ETA corrige:
  - etape 4 affiche 0s restant.
  - etapes 1-3 utilisent `reste = 50% etape courante + etapes suivantes`.
- Simplification CTA:
  - Step 1 garde un seul CTA secondaire (resume wizard OU full diagnostic).
  - Completion sheet garde un seul secondaire (`Activer mon dashboard`).
- Correctif robustesse lifecycle:
  - snapshot mini-onboarding en `dispose()` ne depend plus de `Localizations`.
- Regression test:
  - ajout assertion Step 4 pour eviter preview `CHF 0` avec inputs complets.

### P1 (prochaine tranche, 1 sprint)
- Decouper `advisor_onboarding_screen.dart` en composants:
  - `onboarding_top_bar.dart`
  - `onboarding_eta_hint.dart`
  - `onboarding_step_indicator.dart`
  - `onboarding_completion_sheet.dart`
  - `onboarding_preview_card.dart`
- Introduire `AdvisorMiniOnboardingController` (state + validation + save/restore)
  pour sortir la logique metier de l'ecran.
- Cible: fichier ecran < 1000 lignes, couverture smoke inchangée.

### P2 (explicabilite finance, 1 sprint)
- Bloc "Hypotheses de projection" sur Step 4:
  - horizon,
  - statut emploi suppose,
  - epargne estimee (si profil partiel),
  - nature indicative des scenarios.
- Lien "Pourquoi ce chiffre?" ouvrant un bottom-sheet pedagogique.
- Events analytics additionnels:
  - `preview_hypothesis_opened`
  - `preview_hypothesis_dismissed`
  - `preview_assumption_changed`

### P3 (prod hardening i18n + a11y, 1 sprint)
- Zero string user-facing hardcodee dans onboarding.
- VoiceOver/TalkBack:
  - labels semantiques sur cards,
  - annonce etape courante,
  - hint explicite sur CTA principal.
- Navigation clavier:
  - `textInputAction`,
  - `onSubmitted`,
  - focus order coherent.
- Gate release:
  - smoke onboarding green,
  - a11y basic checks green,
  - aucun warning nouveau onboarding.
