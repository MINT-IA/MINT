# UX REDESIGN — MINT Coach: Du Catalogue au Coach Financier

**Date** : 13 fevrier 2026
**Auteur** : Equipe UX Creative MINT
**Statut** : Spec V1 — Pour validation fondateur

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

## METRIQUES DE SUCCES

| Metrique | Free | Coach |
|----------|------|-------|
| Retention J7 | 30% | 60% |
| Retention J30 | 15% | 45% |
| Check-in mensuel (Coach) | N/A | 70% |
| NPS | 40+ | 65+ |
| Conversion Free → Coach | — | 8-12% |
| LTV Coach (12 mois) | 0 | 52.80 CHF |

### North Star Metric (evoluee)

**Ancien** : "Action Conversion 14j" (combien implementent 1 action)
**Nouveau** : "Monthly Active Coached Users" — combien font le check-in mensuel

---

## PLANNING D'IMPLEMENTATION

```
Sprint   Duree   Livrable
─────────────────────────────────────────────────
C1       2 sem   Profil persistant etendu + ConjointProfile
C2       2 sem   Financial Fitness Score (calcul + widget MintScoreGauge)
C3       3 sem   Forecaster Service (moteur de projection 3 scenarios)
C4       2 sem   Trajectory Chart (CustomPainter interactif)
C5       2 sem   Dashboard redesign (Tab 1 : score + trajectoire + coach alert)
C6       2 sem   Check-in mensuel (ecran + storage + score update)
C7       2 sem   Tab Agir (timeline enrichie + calendrier actions)
C8       2 sem   Coach LLM (BYOK + orchestrateur + guardrails)
C9       1 sem   Paywall + subscription (RevenueCat / in-app purchase)
C10      1 sem   Navigation refonte (4 tabs + routes)
C11      1 sem   Tests + polish + beta
─────────────────────────────────────────────────
TOTAL    ~20 sem  MINT Coach v1
```

---

## RISQUES ET MITIGATIONS

| Risque | Mitigation |
|--------|------------|
| Forecast trop imprecis → perte de confiance | Toujours 3 scenarios + disclaimers + badge precision |
| Utilisateur ne fait pas le check-in | Notification push douce + streak non-culpabilisant |
| LLM hallucine sur un calcul | LLM interdit de calculer. Rules_engine seul. Post-filter. |
| FATCA/US person mal gere | Flag explicite dans le profil, restrictions visibles |
| 4.90 CHF trop bas pour etre rentable | Monitorer CAC vs LTV. Ajuster si besoin (BYOK = 0 cout LLM) |
| Complexite dev trop haute pour 1 personne | Dream team multi-agents. Sprints de 2 semaines. MVP first. |

---

## CONCLUSION

MINT Coach transforme l'app d'un **catalogue de simulateurs** en un **coach financier personnel** — exactement comme TrainerRoad a transforme le velo d'interieur d'un "outil d'entrainement" en un "coach d'entrainement adaptatif".

La cle : **chaque mois, l'utilisateur revient, confirme ses actions, voit sa progression, et ajuste sa trajectoire.**

Le catalogue existant (30+ simulateurs, 18 evenements de vie, 26 cantons) devient le **moteur** sous le capot — mais l'experience utilisateur est desormais centree sur **la trajectoire et le coaching**.

Le LLM est la cerise sur le gateau : il rend le moteur **conversationnel**. Mais meme sans LLM, le dashboard + forecast + check-in est deja un produit transformateur.

**Prix** : 4.90 CHF/mois pour un outil qui genere 15'000+ CHF/an de valeur.
C'est un no-brainer.
