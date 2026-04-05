# MINT — Carte de navigation réelle (tracée depuis le code)

> Chaque flèche = un `context.go()` ou `context.push()` vérifié dans le code.
> Les conditions sont les vrais `if` du code, pas de la fiction.

---

## VUE D'ENSEMBLE — Le labyrinthe actuel

```
                                ┌──────────────────────────────────────────────────────────┐
                                │                    ZONE PUBLIQUE                          │
                                │                  (pas d'auth requise)                     │
                                │                                                          │
                                │  ┌─────────────────────────────────────────────────┐     │
                                │  │              LANDING SCREEN (/)                  │     │
                                │  │                                                 │     │
                                │  │  ┌─────────┐  ┌──────────┐  ┌───────────────┐  │     │
                                │  │  │ Année   │  │ Salaire  │  │ Canton        │  │     │
                                │  │  │ naiss.  │  │ brut     │  │               │  │     │
                                │  │  └─────────┘  └──────────┘  └───────────────┘  │     │
                                │  │                                                 │     │
                                │  │  ┌──────────────┐       ┌──────────────────┐   │     │
                                │  │  │  CALCULER    │       │   COMMENCER      │   │     │
                                │  │  │  (données OK)│       │                  │   │     │
                                │  │  └──────┬───────┘       └────────┬─────────┘   │     │
                                │  │         │                        │              │     │
                                │  └─────────│────────────────────────│──────────────┘     │
                                │            │                        │                     │
                                │            ▼                        │                     │
                                │  ┌─────────────────────┐           │                     │
                                │  │ CHIFFRE CHOC INSTANT │           │                     │
                                │  │ (/chiffre-choc-      │           │                     │
                                │  │  instant)             │           │                     │
                                │  │                       │           │                     │
                                │  │ Voit:                 │           │                     │
                                │  │ - < 28 ans: compound  │           │                     │
                                │  │   growth              │           │                     │
                                │  │ - 28-38: 3a tax       │           │                     │
                                │  │ - 38+: retirement gap │           │                     │
                                │  │                       │           │                     │
                                │  │ 3.9s silence...       │           │                     │
                                │  │ Question ciblée       │           │                     │
                                │  │ Émotion saisie        │           │                     │
                                │  │                       │           │                     │
                                │  │ [Sauve dans SharedPrefs]          │                     │
                                │  │ - onboarding_emotion  │           │                     │
                                │  │ - onboarding_birth_yr │           │                     │
                                │  │ - onboarding_salary   │           │                     │
                                │  │ - onboarding_canton   │           │                     │
                                │  │ - onboarding_choc_*   │           │                     │
                                │  └──────────┬────────────┘           │                     │
                                │             │                        │                     │
                                │             ▼                        │                     │
                                │  ┌─────────────────────┐            │                     │
                                │  │  REGISTER SCREEN     │            │                     │
                                │  │  (/auth/register)    │◄───────────┘ (si pas de données  │
                                │  │                      │   ET pas de profil existant)     │
                                │  │  Email + mot de passe│                                  │
                                │  │                      │                                  │
                                │  │  OU "Continuer sans  │──────┐                           │
                                │  │  compte"             │      │                           │
                                │  └──────────┬───────────┘      │                           │
                                │             │                   │                           │
                                └─────────────│───────────────────│───────────────────────────┘
                                              │                   │
                       ┌──────────────────────┤                   │
                       │                      │                   │
                       ▼                      ▼                   ▼
            ┌──────────────────┐   ┌──────────────┐   ┌──────────────────────┐
            │ VERIFY EMAIL     │   │   /home      │   │ QUICK START          │
            │ (/auth/verify-   │   │  (AUTH WALL) │   │ (/onboarding/quick)  │
            │  email)          │   │              │   │                      │
            │                  │   │  SI PAS      │   │ Consent nLPD         │
            │ Attend confirm.  │   │  LOGUÉ:      │   │ → Decline: retour /  │
            │                  │   │  REDIRIGE    │   │ → Accept: continue   │
            │ Si OK + logué:   │   │  VERS        │   │                      │
            │ → /home          │   │  /auth/      │   │ 3 champs:            │
            │                  │   │  register    │   │ - Âge (default: 30)  │
            │ Si OK + pas logué│   │  ?redirect=  │   │ - Salaire (60k)      │
            │ → /auth/login    │   │  /home       │   │ - Canton (ZH)        │
            └──────────────────┘   │              │   │                      │
                                   │              │   │ Pre-fill depuis:     │
                                   │              │   │ 1. Route extra       │
                                   │              │   │ 2. SharedPreferences │
                                   │              │   │ 3. CoachProfile      │
                                   │              │   │ 4. Defaults          │
                                   │              │   │                      │
                                   │              │   │ "Continuer"          │
                                   │              │   │ → /home?tab=0        │
                                   │              │   │ (AUTH WALL AUSSI!)   │
                                   │              │   └──────────┬───────────┘
                                   │              │              │
                                   │              │              │
                                   └──────┬───────┘              │
                                          │                      │
                                          │◄─────────────────────┘
                                          │
    ══════════════════════════════════════════════════════════════════════════
                         ZONE PROTÉGÉE (auth requise)
    ══════════════════════════════════════════════════════════════════════════
                                          │
                                          ▼
                          ┌───────────────────────────────────┐
                          │         HOME (/home)               │
                          │     MainNavigationShell            │
                          │                                    │
                          │  ┌────────┬────────┬────────┐     │
                          │  │ Tab 0  │ Tab 1  │ Tab 2  │Tab 3│
                          │  │PULSE   │COACH   │EXPLORER│DOSS.│
                          │  │Aujour- │Chat AI │7 hubs  │Profil
                          │  │d'hui   │        │        │Docs │
                          │  └───┬────┴───┬────┴───┬────┴──┬──┘
                          │      │        │        │       │   │
                          └──────│────────│────────│───────│───┘
                                 │        │        │       │
              ┌──────────────────┘        │        │       └──────────────────┐
              ▼                           ▼        ▼                          ▼
   ┌──────────────────┐      ┌─────────────┐  ┌──────────┐      ┌──────────────────┐
   │    PULSE          │      │ COACH CHAT  │  │ EXPLORE  │      │    DOSSIER       │
   │                   │      │             │  │ TAB      │      │                  │
   │ Hero number:      │      │ Embedded    │  │          │      │ Profile card     │
   │ - Budget (default)│      │ in tab      │  │ Ordonnée │      │ Documents        │
   │ - Housing         │      │             │  │ par      │      │ Couple           │
   │ - Retirement      │      │ Reçoit:     │  │ lifecycle│      │ Timeline         │
   │                   │      │ - emotion   │  │          │      │                  │
   │ Goal selector     │      │ - choc type │  │ demarrage│      │ → /profile       │
   │ chips             │      │ - context   │  │ → travail│      │ → /documents     │
   │                   │      │   injecteur │  │   #1     │      │ → /couple        │
   │ Cap card          │      │             │  │          │      │ → /profile/byok  │
   │ 2 signals         │      │ Tool calls: │  │ consoli- │      │ → /profile/slm   │
   │                   │      │ [ROUTE_TO_  │  │ dation   │      │ → /profile/      │
   │ → /budget         │      │  SCREEN:{}] │  │ → retrait│      │   consent        │
   │ → /scan           │      │ = TEXTE,    │  │   e #1   │      │                  │
   │ → /retraite       │      │   PAS       │  │          │      │                  │
   │ → /coach/chat     │      │   EXÉCUTÉS  │  │ 7 hubs → │      │                  │
   └──────────────────┘      │ (!!!!)      │  └────┬─────┘      └──────────────────┘
                              └─────────────┘       │
                                                    ▼
                              ┌──────────────────────────────────────────────┐
                              │            7 HUB SCREENS                     │
                              │                                              │
                              │  /explore/retraite ─────→ 9 outils          │
                              │    (content gating: rachat LPP, décaissement│
                              │     masqués si phase < accélération)         │
                              │                                              │
                              │  /explore/famille ──────→ divorce, mariage,  │
                              │                           naissance, etc.    │
                              │                                              │
                              │  /explore/travail ──────→ first-job, chômage,│
                              │                           expat, indép.      │
                              │                                              │
                              │  /explore/logement ─────→ hypothèque,        │
                              │                           amortissement      │
                              │                                              │
                              │  /explore/fiscalite ────→ 3a, fiscal,        │
                              │                           3a rétroactif      │
                              │                                              │
                              │  /explore/patrimoine ───→ succession,        │
                              │    (content gating: succession masquée       │
                              │     si phase < accélération)                 │
                              │                                              │
                              │  /explore/sante ────────→ invalidité,        │
                              │                           LAMal, couverture  │
                              └──────────────────────────────────────────────┘
```

---

## LES BOUCLES ABSURDES (trouvées dans le code)

### Boucle 1 : "Commencer sans données → Quick Start → /home → AUTH WALL"

```
  Landing                Quick Start              Auth Guard              Register
  ┌─────┐  "Commencer"  ┌──────────┐  "Continuer" ┌──────────┐          ┌──────────┐
  │  /  │ ──────────────→│/onboard- │ ────────────→│  /home   │─BLOQUÉ──→│/auth/    │
  │     │  (pas de       │ ing/quick│  context.go  │          │ pas logué│register  │
  │     │   données)     │          │  ('/home')   │ AUTH WALL│ redirect=│?redirect=│
  └─────┘                └──────────┘              └──────────┘ /home    │/home     │
                                                                         └────┬─────┘
                                                                              │
                                   ┌──────────────────────────────────────────┘
                                   │ Après register:
                                   ▼
                              ┌──────────┐
                              │  /home   │ ← ENFIN ! Mais le profil a été créé
                              │          │   AVANT le register. Données dans
                              │          │   CoachProfileProvider mais PAS liées
                              │          │   au compte utilisateur.
                              └──────────┘

  PROBLÈME: L'utilisateur remplit Quick Start (3 champs),
  puis se fait BLOQUER par le auth wall, puis doit s'inscrire,
  puis arrive enfin sur /home. Il a saisi ses données DEUX FOIS
  (Quick Start + Register qui redemande prénom + date naissance).
```

### Boucle 2 : "Calculer → Chiffre Choc → Register → Verify Email → ???"

```
  Landing         Chiffre Choc       Register          Verify Email
  ┌─────┐         ┌──────────┐       ┌──────────┐      ┌──────────┐
  │     │─Calc──→│ emotion  │─────→│ Register │─────→│ Verify   │
  │     │         │ stockée  │ go() │ (pas de  │ go() │ email    │
  └─────┘         │ en prefs │      │ redirect │      │ (pas de  │
                  └──────────┘      │ param!)  │      │ redirect │
                                    └──────────┘      │ param!)  │
                                                      └────┬─────┘
                                                           │
                                    Si email confirmé + logué:
                                    → /home (pas de redirect param, default)

                                    Si email confirmé + PAS logué:
                                    → /auth/login (REBOUCLE !)

                                    Si ferme l'app pendant verify:
                                    → Au relancement, coincé sur verify-email

  PROBLÈME CRITIQUE: Quand on navigue de chiffre-choc-instant vers
  /auth/register, on fait context.go('/auth/register') SANS paramètre
  redirect. Donc après register, le redirect est null → /home par défaut.
  Mais si verify email est requis, le redirect est aussi null → /auth/login.
  L'utilisateur fait: chiffre choc → register → verify → login → home.
  4 ÉCRANS D'AUTH pour voir son résultat !
```

### Boucle 3 : "Profile → Quick Start → /home (PERD le contexte profile)"

```
  Dossier Tab       Profile            Quick Start          Home
  ┌─────────┐       ┌──────────┐       ┌──────────┐       ┌──────────┐
  │ Tab 3   │──────→│ /profile │──────→│/onboard- │──────→│  /home   │
  │         │ push()│          │ go()  │ing/quick │ go()  │  ?tab=0  │
  │         │       │ Edit     │ sect= │?section= │       │          │
  └─────────┘       │ "revenu" │ income│income    │       │ PULSE !  │
                    └──────────┘       └──────────┘       └──────────┘

  PROBLÈME: L'utilisateur éditait son profil (Tab 3 → Profile).
  Il clique "Éditer revenu" → Quick Start avec section=income.
  Quick Start fait context.go('/home?tab=0') → il se retrouve sur
  PULSE (Tab 0), PAS sur le profil (Tab 3) d'où il venait !
  Il a perdu son contexte. Il doit re-naviguer vers Tab 3 > Profile.
```

---

## TABLEAU RÉCAPITULATIF DES ÉCRANS

### Écrans du flux principal (ce que 95% des utilisateurs voient)

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                     │
│   LANDING ──→ CHIFFRE CHOC ──→ REGISTER ──→ HOME (4 tabs)         │
│      │                                         │                    │
│      └──→ QUICK START ──→ (AUTH WALL) ──→ HOME │                    │
│                                                 │                    │
│   HOME contient:                                │                    │
│   ├── PULSE (budget/retirement hero)            │                    │
│   ├── COACH CHAT (AI embedded)                  │                    │
│   ├── EXPLORER (7 hubs → 60+ simulateurs)       │                    │
│   └── DOSSIER (profile, docs, couple)           │                    │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Écrans secondaires (depuis les hubs Explorer)

```
RETRAITE HUB          FAMILLE HUB         TRAVAIL HUB
├── Dashboard         ├── Divorce          ├── Premier emploi
├── Rente vs Capital  ├── Mariage          ├── Chômage
├── Rachat LPP        ├── Naissance        ├── Expat
├── EPL               ├── Concubinage      ├── Comparaison jobs
├── Décaissement      └── Décès proche     └── Indépendants (6)
├── Succession
├── Libre passage     LOGEMENT HUB         FISCALITÉ HUB
├── 3a simulateur     ├── Hypothèque       ├── Pilier 3a
├── 3a comparateur    ├── Amortissement    ├── 3a comparateur
├── 3a rendement réel ├── EPL combiné      ├── 3a rendement
├── 3a échelonné      ├── Valeur locative  ├── 3a échelonné
└── 3a rétroactif     └── SARON vs Fixe    ├── 3a rétroactif
                                           └── Fiscal comparateur
PATRIMOINE HUB        SANTÉ HUB
├── Succession        ├── Invalidité          OUTILS DIVERS
├── Donation          ├── Assurance inval.    ├── Budget
├── Vente immob.      ├── Inval. indép.       ├── Debt check
├── Arbitrage bilan   ├── LAMal franchise     ├── Portfolio
├── Allocation ann.   └── Couverture          ├── Timeline
└── Location vs                               ├── Achievements
    Propriété                                 ├── Weekly recap
                                              ├── Cantonal benchmark
                                              └── Ask MINT
```

### Écrans orphelins / rarement visités

```
FEATURE-FLAGGED (pas visibles)    LEGACY REDIRECTS (40+)
├── Expert Tier                   ├── /coach/dashboard → /retraite
├── B2B Hub                       ├── /retirement → /retraite
├── Open Banking (3)              ├── /lpp-deep/rachat → /rachat-lpp
├── Pension Fund Connect          ├── /simulator/3a → /pilier-3a
└── Admin screens (2)             └── etc.

DOUBLONS / CONFUSION
├── Bank Import V1 + V2 (2 versions)
├── Education Hub + Comprendre Hub (même concept ?)
├── Confidence Dashboard + Score Reveal (même métrique ?)
```

---

## COMPTAGE FINAL

| Catégorie | Nombre d'écrans |
|-----------|----------------|
| Flux principal (landing → home → 4 tabs) | **8** |
| Hub Retraite + simulateurs | **12** |
| Hub Fiscalité (3a deep) | **6** |
| Hub Logement (mortgage) | **5** |
| Hub Famille (life events) | **5** |
| Hub Travail (emploi) | **10** |
| Hub Patrimoine | **6** |
| Hub Santé | **5** |
| Budget / Debt | **5** |
| Auth / Onboarding | **9** |
| Profile / Settings | **7** |
| Documents / Scan | **6** |
| Coach / Coaching | **8** |
| Outils divers | **15** |
| Feature-flagged | **5** |
| Éducation | **3** |
| **TOTAL** | **~127** |
| Dont activement utilisés | **~50** |
| Dont rarement visités | **~40** |
| Dont feature-flagged | **~5** |
| Dont legacy/doublons | **~30** |
