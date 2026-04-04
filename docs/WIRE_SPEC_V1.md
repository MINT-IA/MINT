# MINT — WIRE SPEC V1 : Le document de construction

> **Ce document n'est PAS un flowchart.** C'est une spec d'ingénierie.
> Chaque flèche = un appel de fonction. Chaque boîte = un état avec ses données.
> Chaque transition = un fichier source, une ligne, un objet typé.
> Chaque câble = un test d'acceptance qui prouve qu'il est connecté.
>
> **Règle** : si c'est pas dans ce document, ça n'existe pas dans l'app.

---

## TABLE DES MATIÈRES

1. [ÉTAT ACTUEL — Ce qui existe dans le code](#1-état-actuel)
2. [STATE MACHINE — Chaque état, chaque transition](#2-state-machine)
3. [WIRE SPEC — Chaque câble, chaque objet, chaque test](#3-wire-spec)
4. [KILL LIST — Ce qu'on supprime](#4-kill-list)
5. [MIGRATION TABLE — Avant/Après routes](#5-migration-table)
6. [PROVIDER REFACTOR — 12 → 8](#6-provider-refactor)
7. [ACCEPTANCE TESTS — La preuve que c'est construit](#7-acceptance-tests)
8. [PLAN D'EXÉCUTION — L'ordre exact](#8-plan-dexécution)

---

## 1. ÉTAT ACTUEL

### 1.1 Routes (source : `app.dart:161-973`)

**70 routes GoRouter. 12 providers. 4 tabs.**

```
ROUTES PUBLIQUES (pas d'auth requise):
  /                          → LandingScreen
  /chiffre-choc-instant      → InstantChiffreChocScreen
  /auth/login                → LoginScreen
  /auth/register             → RegisterScreen
  /auth/forgot-password      → ForgotPasswordScreen
  /auth/verify-email         → VerifyEmailScreen
  /onboarding/quick          → QuickStartScreen
  /onboarding/chiffre-choc   → ChiffreChocScreen

ROUTES PROTÉGÉES (auth guard dans app.dart:166-221):
  /home                      → MainNavigationShell (4 tabs)
    tab 0: PulseScreen       (Aujourd'hui)
    tab 1: MintCoachTab      (Coach)
    tab 2: ExploreTab        (Explorer)
    tab 3: DossierTab        (Dossier)

  /coach/chat                → CoachChatScreen(initialPrompt?, conversationId?)
  /coach/history             → CoachHistoryScreen
  + 60 routes de simulateurs/outils (voir §4 KILL LIST)
```

### 1.2 Providers actuels (source : `app.dart:1018-1080`)

| # | Provider | Type | Dépendances |
|---|----------|------|-------------|
| 1 | AuthProvider | ChangeNotifier | Aucune |
| 2 | ProfileProvider | ChangeNotifier | Aucune |
| 3 | CoachProfileProvider | ChangeNotifier | Aucune (load from wizard) |
| 4 | BudgetProvider | ProxyProvider | ← CoachProfileProvider |
| 5 | ByokProvider | ChangeNotifier | Aucune (load saved key) |
| 6 | DocumentProvider | ChangeNotifier | Aucune |
| 7 | SubscriptionProvider | ChangeNotifier | Aucune |
| 8 | HouseholdProvider | ChangeNotifier | Aucune |
| 9 | MintStateProvider | ProxyProvider | ← CoachProfileProvider |
| 10 | LocaleProvider | ChangeNotifier | Aucune |
| 11 | UserActivityProvider | ChangeNotifier | Aucune |
| 12 | SlmProvider | ChangeNotifier | Aucune |

### 1.3 Les 3 problèmes structurels

**P1 — Double source de profil** : `ProfileProvider` ET `CoachProfileProvider` gèrent le profil utilisateur. `BudgetProvider` et `MintStateProvider` dépendent de `CoachProfileProvider`. `ProfileProvider` est quasi-orphelin.

**P2 — Onboarding via SharedPreferences** : 6 clés `onboarding_*` stockées en SharedPreferences au lieu d'un Provider typé. Consommées une seule fois par `ContextInjectorService` puis effacées. Fragile, non testable, invisible dans le widget tree.

**P3 — Coach entry point unique** : `CoachChatScreen` n'accepte que `initialPrompt: String?` et `conversationId: String?`. Impossible de lui passer un contexte structuré (quel écran source, quel sujet, quelles données). Le coach ne sait pas POURQUOI l'utilisateur arrive.

---

## 2. STATE MACHINE

### 2.1 Notation

```
[ÉTAT]                     = un écran ou état de l'app
──{condition}──→           = transition avec condition
  📦 DataObject            = objet Dart qui transite
  📍 fichier.dart:ligne    = source code exacte
  🧪 test_name             = test d'acceptance
```

### 2.2 Machine complète : Premier contact → Coach

```
                        ┌─────────────────────────────────────┐
                        │  [S0] APP_LAUNCH                    │
                        │                                     │
                        │  État initial.                      │
                        │  AuthProvider.checkAuth() appelé.   │
                        │  📍 app.dart:1020-1024              │
                        └──────────────┬──────────────────────┘
                                       │
                          ┌────────────┴────────────┐
                          │                         │
                   {isLoggedIn=true}         {isLoggedIn=false}
                          │                         │
                          ▼                         ▼
                   [S1] HOME                 [S2] LANDING
                   (voir §2.3)               (voir ci-dessous)
                                             │
                                             │
┌────────────────────────────────────────────┴───────────────────────────┐
│  [S2] LANDING                                                          │
│                                                                        │
│  📍 screens/landing_screen.dart                                        │
│  Écran : 3 champs (année naissance, salaire brut, canton)              │
│  État interne :                                                        │
│    _birthYear: int?                                                    │
│    _grossSalary: double?                                               │
│    _canton: String?                                                    │
│    _isValid: bool (les 3 champs remplis)                               │
│                                                                        │
│  2 boutons :                                                           │
│    [CALCULER] → actif si _isValid=true                                 │
│    [COMMENCER] → toujours actif                                        │
│                                                                        │
└──────────┬───────────────────────────────────────┬─────────────────────┘
           │                                       │
    {tap CALCULER}                          {tap COMMENCER}
    {_isValid=true}                                │
           │                                       │
           │                                       │
           ▼                                       │
┌──────────────────────────────────────────────┐   │
│  [S3] CHIFFRE_CHOC_INSTANT                   │   │
│                                              │   │
│  📍 screens/onboarding/                      │   │
│     instant_chiffre_choc_screen.dart         │   │
│                                              │   │
│  ENTRÉE (route extra depuis landing) :       │   │
│  📦 {                                        │   │
│    'birthYear': int,                         │   │
│    'grossSalary': double,                    │   │
│    'canton': String                          │   │
│  }                                           │   │
│                                              │   │
│  TRAITEMENT :                                │   │
│  1. Construit MinimalProfileResult           │   │
│  2. Appelle ChiffreChocSelector.select()     │   │
│     📍 chiffre_choc_selector.dart:30-68      │   │
│  3. Reçoit ChiffreChoc {                     │   │
│       type: ChiffreChocType,                 │   │
│       rawValue: double,                      │   │
│       title: String,                         │   │
│       subtitle: String                       │   │
│     }                                        │   │
│                                              │   │
│  AFFICHAGE :                                 │   │
│  - Révélation 5 temps (setup→silence→        │   │
│    countup→ligne→contexte)                   │   │
│  - 3.9s silence                              │   │
│  - Question ciblée par ChiffreChocType       │   │
│  - Chips contextuels (3 options)             │   │
│                                              │   │
│  CAPTURE :                                   │   │
│  - L'utilisateur choisit un chip OU tape     │   │
│  - _userEmotion: String capturée             │   │
│                                              │   │
│  STOCKAGE (SharedPreferences) :              │   │
│    onboarding_birth_year   → int             │   │
│    onboarding_gross_salary → double          │   │
│    onboarding_canton       → String          │   │
│    onboarding_choc_type    → String          │   │
│    onboarding_choc_value   → double          │   │
│    onboarding_emotion      → String          │   │
│                                              │   │
│  🧪 test_chiffre_choc_19yo_sees_compound     │   │
│  🧪 test_chiffre_choc_35yo_sees_tax_saving   │   │
│  🧪 test_chiffre_choc_49yo_sees_gap          │   │
│  🧪 test_emotion_stored_in_prefs             │   │
│  🧪 test_choc_selector_called_not_direct     │   │
│                                              │   │
└──────────────────┬───────────────────────────┘   │
                   │                               │
            {emotion capturée}                     │
                   │                               │
                   ▼                               │
┌──────────────────────────────────────────────┐   │
│  [S4] PROMESSE                               │   │
│                                              │   │
│  📍 screens/onboarding/promise_screen.dart   │   │
│  (À CRÉER)                                   │   │
│                                              │   │
│  ENTRÉE :                                    │   │
│  Pas d'entrée de données. Lit SharedPrefs    │   │
│  pour adapter le texte au profil.            │   │
│                                              │   │
│  AFFICHAGE :                                 │   │
│  Texte adapté par LifecyclePhase :           │   │
│  - demarrage (18-24) :                       │   │
│    "MINT reste avec toi.                     │   │
│     Ton premier job. Ton premier appart.     │   │
│     Tes impôts. Chaque étape, on t'explique."│   │
│  - construction (25-34) :                    │   │
│    "MINT reste avec toi.                     │   │
│     Acheter ? Économiser ? Investir ?        │   │
│     On démêle tout ça ensemble."             │   │
│  - acceleration+ (35+) :                     │   │
│    "MINT reste avec toi.                     │   │
│     Retraite. Impôts. Patrimoine.            │   │
│     Tes chiffres, tes décisions."            │   │
│                                              │   │
│  Footer : "Gratuit. Tes données restent      │   │
│  sur ton téléphone."                         │   │
│                                              │   │
│  2 boutons :                                 │   │
│    [Allons-y]         → S5 (Register)        │   │
│    [Juste les chiffres] → S6 (Mode libre)    │   │
│                                              │   │
│  🧪 test_promise_text_adapts_to_age          │   │
│  🧪 test_mode_libre_skips_registration       │   │
│                                              │   │
└────────┬─────────────────────┬───────────────┘   │
         │                     │                   │
  {tap Allons-y}        {tap Juste les chiffres}   │
         │                     │                   │
         ▼                     ▼                   │
┌─────────────────┐  ┌──────────────────────┐      │
│  [S5] REGISTER  │  │  [S6] MODE LIBRE     │      │
│                 │  │                      │      │
│  📍 screens/    │  │  📍 À DÉFINIR        │      │
│  auth/          │  │                      │      │
│  register_      │  │  Pas d'inscription.  │      │
│  screen.dart    │  │  Profil local.       │      │
│                 │  │  CoachProfileProvider │      │
│  Email/Apple/   │  │  initialisé depuis   │      │
│  Google         │  │  SharedPrefs.        │      │
│                 │  │                      │      │
│  NE DEMANDE     │  │  Accès :             │      │
│  PLUS âge,      │  │  ✅ Explorer (7 hubs)│      │
│  salaire,       │  │  ✅ Simulateurs (60+)│      │
│  canton.        │  │  ❌ Coach personnalisé│◄─────┘
│  On sait déjà.  │  │  ❌ Mémoire/plan     │  {COMMENCER
│                 │  │  ❌ Signaux proactifs │   sans données}
│  Post-register: │  │                      │
│  Auth OK →      │  │  Bandeau discret :   │
│  redirect vers  │  │  "Crée ton compte    │
│  S7 (HOME)      │  │   → plan sur mesure" │
│                 │  │                      │
│  📦 Aucun       │  │  → S7 HOME           │
│  nouveau param. │  │  (avec fonctions     │
│  SharedPrefs    │  │   limitées)          │
│  déjà remplies. │  │                      │
│                 │  └──────────────────────┘
│  🧪 test_       │
│  register_no_   │
│  duplicate_     │
│  fields         │
│                 │
│  🧪 test_       │
│  register_      │
│  preserves_     │
│  shared_prefs   │
│                 │
└────────┬────────┘
         │
   {auth success}
         │
         ▼

═══════════════════════════════════════════════════════════════════
                     ZONE PROTÉGÉE
═══════════════════════════════════════════════════════════════════
         │
         ▼
┌──────────────────────────────────────────────────────────────────────┐
│  [S7] HOME — MainNavigationShell                                     │
│                                                                      │
│  📍 screens/main_navigation_shell.dart                               │
│  📍 Route : /home (avec ?tab=0|1 query param)                       │
│                                                                      │
│  ARCHITECTURE CIBLE : 2 tabs (au lieu de 4)                          │
│                                                                      │
│  ┌───────────────────────────────────────────────────────────────┐   │
│  │                                                               │   │
│  │  Tab 0 : MINT HOME (fusionne Pulse + Coach input)             │   │
│  │  Tab 1 : EXPLORER (search-first + 7 hubs adaptatifs)          │   │
│  │                                                               │   │
│  │  Profil/Dossier : tiroir latéral via icône 👤                 │   │
│  │  Recherche : icône 🔍 → ouvre Explorer tab 1 avec focus search│   │
│  │                                                               │   │
│  └───────────────────────────────────────────────────────────────┘   │
│                                                                      │
│  PREMIÈRE OUVERTURE POST-ONBOARDING :                                │
│  1. CoachProfileProvider.loadFromWizard() déjà appelé (app.dart)     │
│  2. SharedPrefs contiennent onboarding_* (âge, salaire, canton,      │
│     émotion, choc_type, choc_value)                                  │
│  3. MintStateProvider.recompute() triggered par CoachProfileProvider  │
│  4. Tab 0 (MINT Home) affiche immédiatement :                        │
│     - Le chiffre du jour (= le chiffre choc vu en onboarding)        │
│     - Le levier #1 (calculé par CapEngine)                           │
│     - Le signal proactif (3a non versé, certificat à scanner...)     │
│                                                                      │
│  🧪 test_home_shows_chiffre_from_onboarding                         │
│  🧪 test_home_shows_relevant_lever                                   │
│  🧪 test_home_coach_input_visible                                    │
│                                                                      │
└──────────┬───────────────────────────────────────────┬───────────────┘
           │                                           │
     {tab 0 sélectionné}                        {tab 1 sélectionné}
           │                                           │
           ▼                                           ▼
```

### 2.3 Tab 0 — MINT Home (State Machine interne)

```
┌──────────────────────────────────────────────────────────────────────┐
│  [S7a] MINT HOME                                                     │
│                                                                      │
│  📍 screens/main_tabs/mint_home_screen.dart (À CRÉER)                │
│  Fusionne : PulseScreen + coach input + signaux                      │
│                                                                      │
│  DONNÉES LUES (providers) :                                          │
│  - CoachProfileProvider.profile → CoachProfile                       │
│  - MintStateProvider.state → MintUserState                           │
│    .chiffreDuJour → ChiffreChoc                                      │
│    .topLever → CapRecommendation                                     │
│    .signals → List<ProactiveSignal>                                  │
│    .confidenceScore → EnhancedConfidence                             │
│  - BudgetProvider.snapshot → BudgetSnapshot                          │
│  - UserActivityProvider.maturityLevel → int (1-5)                    │
│                                                                      │
│  STRUCTURE VISUELLE (scroll vertical) :                              │
│                                                                      │
│  ┌─ HEADER ─────────────────────────────────────────────────────┐    │
│  │  MINT                               [👤 profil] [🔍 search] │    │
│  └──────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  ┌─ CHIFFRE DU JOUR ───────────────────────────────────────────┐    │
│  │                                                              │    │
│  │  📦 Widget: ChiffreDuJourCard                                │    │
│  │  Source: MintStateProvider.state.chiffreDuJour                │    │
│  │                                                              │    │
│  │  Rotation quotidienne :                                      │    │
│  │  Lun=retirementGap, Mar=taxOptimization, Mer=budgetFree,     │    │
│  │  Jeu=lppProjection, Ven=topLever, Sam=netWorth, Dim=progress │    │
│  │                                                              │    │
│  │  Affiche :                                                   │    │
│  │  - Le nombre (CountUp animation, accélère avec maturity)     │    │
│  │  - La MintLigne (1px, 400ms)                                 │    │
│  │  - Le contexte (1 phrase)                                    │    │
│  │  - La barre de confiance (●●●○○ 62%)                        │    │
│  │  - L'enrichment prompt (#1 ranked by EVI)                    │    │
│  │                                                              │    │
│  │  onTap: → [S8] CONVERSATION                                 │    │
│  │  📦 CoachEntryPayload(                                       │    │
│  │    source: 'home_chiffre',                                   │    │
│  │    topic: chiffreDuJour.type.name,                           │    │
│  │    data: { 'value': rawValue, 'confidence': score }          │    │
│  │  )                                                           │    │
│  │                                                              │    │
│  │  🧪 test_chiffre_du_jour_rotates_daily                      │    │
│  │  🧪 test_chiffre_tap_opens_coach_with_context                │    │
│  │  🧪 test_confidence_bar_reflects_profile_completeness        │    │
│  │                                                              │    │
│  └──────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  ┌─ LEVIER DU JOUR ────────────────────────────────────────────┐    │
│  │                                                              │    │
│  │  📦 Widget: LeverDuJourCard                                  │    │
│  │  Source: MintStateProvider.state.topLever                     │    │
│  │  (calculé par CapEngine / CapSequenceEngine)                  │    │
│  │                                                              │    │
│  │  Affiche :                                                   │    │
│  │  - Le levier (ex: "Rachat LPP")                              │    │
│  │  - L'impact CHF (ex: "+892 CHF/mois retraite")               │    │
│  │  - L'impact fiscal (ex: "-12'400 CHF impôts cette année")    │    │
│  │  - Le trade-off (ex: "Bloque EPL 3 ans")                     │    │
│  │                                                              │    │
│  │  onTap [Simuler]: → context.push('/rachat-lpp')              │    │
│  │  OU                                                          │    │
│  │  onTap [En savoir +]: → [S8] CONVERSATION avec               │    │
│  │  📦 CoachEntryPayload(                                       │    │
│  │    source: 'home_lever',                                     │    │
│  │    topic: topLever.type,                                     │    │
│  │    data: topLever.toJson()                                   │    │
│  │  )                                                           │    │
│  │                                                              │    │
│  │  Visible si : maturityLevel >= 2 (pas à la 1ère visite)     │    │
│  │                                                              │    │
│  │  🧪 test_lever_shows_chf_impact                              │    │
│  │  🧪 test_lever_hidden_first_visit                            │    │
│  │  🧪 test_lever_tap_routes_to_simulator                       │    │
│  │                                                              │    │
│  └──────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  ┌─ SIGNAL PROACTIF ───────────────────────────────────────────┐    │
│  │                                                              │    │
│  │  📦 Widget: SignalCard                                       │    │
│  │  Source: MintStateProvider.state.signals.first                │    │
│  │  (ProactiveTriggerService + PrecomputedInsightsService)       │    │
│  │                                                              │    │
│  │  Exemples de signaux :                                       │    │
│  │  - "3a 2026 : 0/7'258 versé. Deadline 31 déc."             │    │
│  │  - "Certificat LPP 2026 disponible. Scanne-le."            │    │
│  │  - "Tu passes à 18% de bonification en mars."               │    │
│  │  - "SARON a bougé de +0.25%. Impact: +47 CHF/mois."        │    │
│  │                                                              │    │
│  │  onTap [Agir]: → action spécifique au signal                │    │
│  │    3a → context.push('/pilier-3a')                           │    │
│  │    scan → context.push('/scan')                              │    │
│  │    info → [S8] CONVERSATION avec contexte signal             │    │
│  │                                                              │    │
│  │  Visible si : signal.priority > 0 (pas de signal vide)      │    │
│  │  Max affiché : 1 signal (le plus prioritaire)               │    │
│  │  Si 0 signals : section absente (pas de placeholder vide)   │    │
│  │                                                              │    │
│  │  🧪 test_signal_3a_shows_deadline                            │    │
│  │  🧪 test_signal_tap_routes_to_action                         │    │
│  │  🧪 test_no_signal_section_hidden                            │    │
│  │                                                              │    │
│  └──────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  ─── SÉPARATEUR MintLigne ───                                        │
│                                                                      │
│  ┌─ COACH INPUT ───────────────────────────────────────────────┐    │
│  │                                                              │    │
│  │  💬 Phrase d'accroche contextuelle :                         │    │
│  │  Source: DataDrivenOpenerService.generate(profile, state)    │    │
│  │  Ex: "65%, ça te suffit ?"                                   │    │
│  │  Ex: "Tu as 3 leviers. On commence par lequel ?"            │    │
│  │  Ex: "Ton certificat LPP changerait tout."                  │    │
│  │                                                              │    │
│  │  ┌──────────────────────────────────────────────────────┐   │    │
│  │  │  Pose ta question...                            🎤   │   │    │
│  │  └──────────────────────────────────────────────────────┘   │    │
│  │                                                              │    │
│  │  Suggestion chips (contextuels, pas statiques) :            │    │
│  │  Source: ContextInjectorService.relevantScreens +            │    │
│  │          MintStateProvider.enrichmentPrompts                  │    │
│  │  Ex: [Rente ou capital ?] [Mon budget retraite] [Lauren ?]  │    │
│  │                                                              │    │
│  │  onTap chip: → [S8] CONVERSATION avec                       │    │
│  │  📦 CoachEntryPayload(                                       │    │
│  │    source: 'home_chip',                                     │    │
│  │    topic: chip.topic,                                       │    │
│  │    data: chip.contextData                                   │    │
│  │  )                                                           │    │
│  │                                                              │    │
│  │  onSubmit text: → [S8] CONVERSATION avec                    │    │
│  │  📦 CoachEntryPayload(                                       │    │
│  │    source: 'home_input',                                    │    │
│  │    topic: null,                                             │    │
│  │    data: { 'userMessage': text }                            │    │
│  │  )                                                           │    │
│  │                                                              │    │
│  │  🧪 test_coach_input_always_visible                          │    │
│  │  🧪 test_chips_are_contextual_not_static                    │    │
│  │  🧪 test_chip_tap_passes_payload_to_coach                   │    │
│  │  🧪 test_text_submit_opens_conversation                     │    │
│  │                                                              │    │
│  └──────────────────────────────────────────────────────────────┘    │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

### 2.4 État S8 — CONVERSATION (Coach full-screen)

```
┌──────────────────────────────────────────────────────────────────────┐
│  [S8] CONVERSATION                                                   │
│                                                                      │
│  📍 screens/coach/coach_chat_screen.dart                             │
│  📍 Route : /coach/chat (push, PAS go — conserve le back stack)      │
│                                                                      │
│  ENTRÉE (REFACTORÉE — plus un simple String) :                       │
│                                                                      │
│  📦 CoachEntryPayload {                                              │
│    final String source;          // 'home_chiffre', 'home_lever',    │
│                                  // 'home_chip', 'home_input',       │
│                                  // 'explorer_hub', 'simulator',     │
│                                  // 'signal', 'notification',        │
│                                  // 'bottom_sheet'                   │
│    final String? topic;          // 'retirementGap', 'rachatLpp',    │
│                                  // 'budget', 'hypotheque', etc.     │
│    final Map<String, dynamic>?   // données contextuelles            │
│          data;                   // { 'value': 4200, ... }           │
│    final String? userMessage;    // message libre tapé par l'user    │
│  }                                                                   │
│                                                                      │
│  📍 Déclaration : lib/models/coach_entry_payload.dart (À CRÉER)      │
│                                                                      │
│  TRAITEMENT INITIAL :                                                │
│  1. ContextInjectorService.buildContext() appelé                     │
│     → récupère lifecycle, memory, goals, nudges, budget, etc.        │
│  2. SI payload.source == 'home_chiffre' :                            │
│     → injecte "L'utilisateur a tapé sur son chiffre du jour          │
│        ({topic}={data.value}). Explique ce chiffre et ses leviers."  │
│  3. SI payload.userMessage != null :                                 │
│     → envoie comme premier message utilisateur                       │
│  4. SI payload.topic != null && payload.userMessage == null :        │
│     → génère un prompt contextuel automatique                        │
│                                                                      │
│  MODES DU COACH :                                                    │
│  - BYOK (Claude API) : agent loop avec tool_calls exécutés          │
│  - SLM (on-device) : single-shot, pas de tools                      │
│  - Fallback : templates statiques si ni BYOK ni SLM                 │
│                                                                      │
│  TOOL CALLS EXÉCUTÉS (côté Flutter, pas juste texte) :               │
│                                                                      │
│  📦 ToolCall { name: String, arguments: Map }                        │
│                                                                      │
│  | Tool name              | Action Flutter                          │
│  |------------------------|------------------------------------------|
│  | ROUTE_TO_SCREEN        | context.push(route)                     │
│  | SHOW_FACT_CARD         | affiche ResponseCard inline             │
│  | SHOW_COMPARISON        | affiche ArbitrageCard inline            │
│  | SHOW_PROJECTION        | affiche MiniChart inline                │
│  | UPDATE_PROFILE         | CoachProfileProvider.update(field, val)  │
│  | REQUEST_DOCUMENT_SCAN  | ouvre bottom sheet scan                 │
│  | SHOW_BUDGET_SNAPSHOT   | affiche BudgetCard inline               │
│  | SET_GOAL               | GoalTracker.addGoal(goal)               │
│  | SHOW_LEVER             | affiche LeverCard inline                │
│  | SCHEDULE_REMINDER      | NotificationSchedulerService.schedule() │
│                                                                      │
│  📍 Parsing : coach_chat_screen.dart (dans _addResponse)             │
│  Pattern : [TOOL_NAME:{json}] dans le texte → extrait + exécute     │
│                                                                      │
│  RETOUR :                                                            │
│  - ← (back button) : retour à l'écran précédent (MINT Home, etc.)   │
│  - Pas de context.go('/home') — préserve la navigation stack         │
│                                                                      │
│  🧪 test_coach_receives_entry_payload                                │
│  🧪 test_coach_chiffre_source_explains_number                       │
│  🧪 test_tool_call_route_to_screen_pushes                           │
│  🧪 test_tool_call_show_fact_card_renders_inline                    │
│  🧪 test_tool_call_update_profile_modifies_provider                 │
│  🧪 test_back_button_returns_to_source                              │
│  🧪 test_coach_works_without_byok_slm_fallback                     │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

### 2.5 Tab 1 — Explorer

```
┌──────────────────────────────────────────────────────────────────────┐
│  [S9] EXPLORER                                                       │
│                                                                      │
│  📍 screens/main_tabs/explore_tab.dart (REFACTORÉE)                  │
│                                                                      │
│  DONNÉES LUES :                                                      │
│  - LifecyclePhaseService.detect(profile) → LifecyclePhaseResult      │
│  - ContentAdapterService.adapt(phase) → ContentAdaptation            │
│  - CoachProfileProvider.profile → pour adapter l'affichage           │
│                                                                      │
│  STRUCTURE :                                                         │
│                                                                      │
│  ┌─ SEARCH BAR ────────────────────────────────────────────────┐    │
│  │  🔍 Chercher dans MINT...                                   │    │
│  │  Recherche full-text sur : noms de hubs, noms d'outils,     │    │
│  │  mots-clés (divorce, 3a, hypothèque, retraite...)          │    │
│  │  📍 Implémentation : SearchDelegate + index local           │    │
│  └──────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  ┌─ QUICK TAGS ────────────────────────────────────────────────┐    │
│  │  [3a] [Retraite] [Hypothèque] [Impôts] [Divorce]           │    │
│  │  Statiques. Raccourcis vers les outils les plus utilisés.   │    │
│  │  onTap: → context.push(toolRoute)                           │    │
│  └──────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  ┌─ TON PARCOURS (lifecycle adaptatif) ────────────────────────┐    │
│  │                                                              │    │
│  │  Titre: "Ton parcours" + badge phase                        │    │
│  │  Affiche 3 hubs prioritaires selon LifecyclePhaseResult     │    │
│  │  .priorities (top 3)                                         │    │
│  │                                                              │    │
│  │  Si phase=demarrage : [Travail] [Logement] [Épargne]       │    │
│  │  Si phase=consolidation : [Logement] [Famille] [Fiscalité]  │    │
│  │  Si phase=acceleration : [Retraite] [Fiscalité] [Patrimoine]│    │
│  │  Si phase=transition : [Retraite] [Patrimoine] [Santé]      │    │
│  │                                                              │    │
│  │  Chaque card affiche :                                       │    │
│  │  - Icône + nom du hub                                        │    │
│  │  - Nombre d'outils dans ce hub                               │    │
│  │  - Badge alerte si signal actif (⚠️ "1 alerte")             │    │
│  │                                                              │    │
│  │  onTap: → context.push('/explore/{hub}')                    │    │
│  │                                                              │    │
│  └──────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  ┌─ ÉVÉNEMENTS DE VIE ────────────────────────────────────────┐     │
│  │                                                              │    │
│  │  "Quelque chose change dans ta vie ?"                       │    │
│  │  Chips : [J'achète] [Divorce] [Bébé] [Je pars]             │    │
│  │          [Nouveau job] [Héritage] [Retraite] [+ tout]       │    │
│  │                                                              │    │
│  │  onTap: → context.push('/life-event/{eventType}')           │    │
│  │  OU → [S8] CONVERSATION avec topic=eventType                │    │
│  │                                                              │    │
│  └──────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  ┌─ TOUS LES DOMAINES (7 hubs complets) ──────────────────────┐    │
│  │                                                              │    │
│  │  Grille 2×4 :                                                │    │
│  │  [Retraite(12)] [Famille(5)]  [Travail(10)] [Logement(5)]  │    │
│  │  [Fiscalité(6)] [Patrimoine(6)] [Santé(5)]                 │    │
│  │                                                              │    │
│  │  Chiffre = nombre d'outils dans le hub                      │    │
│  │  Content gating : certains outils masqués si phase <        │    │
│  │  seuil (ex: rachat LPP masqué si phase < acceleration)      │    │
│  │                                                              │    │
│  │  onTap: → context.push('/explore/{hub}')                    │    │
│  │  → Hub screen avec liste d'outils + content gating          │    │
│  │                                                              │    │
│  └──────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  🧪 test_explorer_search_finds_hypotheque                           │
│  🧪 test_explorer_lifecycle_reorders_hubs                           │
│  🧪 test_explorer_demarrage_hides_succession                       │
│  🧪 test_explorer_life_events_route_correctly                       │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

### 2.6 Tiroir Profil/Dossier

```
┌──────────────────────────────────────────────────────────────────────┐
│  [S10] PROFIL DRAWER                                                 │
│                                                                      │
│  📍 widgets/profile_drawer.dart (À CRÉER)                            │
│  Ouverture : icône 👤 dans le header de MINT Home                    │
│  Type : Drawer (tiroir latéral droite) ou bottom sheet               │
│                                                                      │
│  SECTIONS :                                                          │
│                                                                      │
│  ── Mon profil ──                                                    │
│  Source: CoachProfileProvider.profile                                 │
│  Affiche : nom, âge, canton, salaire, statut marital                │
│  onTap [✏️] : → context.push('/profile')                             │
│  Confiance : barre ●●●○○ + enrichment prompt                       │
│                                                                      │
│  ── Mon plan ──                                                      │
│  Source: GoalTracker.activeGoals                                     │
│  Affiche : checklist d'actions (✅ done, ⏳ pending, 📋 todo)       │
│  onTap : → context.push('/coach/chat?topic=plan')                   │
│                                                                      │
│  ── Couple ──                                                        │
│  Source: HouseholdProvider.partner                                    │
│  Affiche : infos partenaire si renseignées                          │
│  Visible si : profile.maritalStatus != single                       │
│  onTap : → context.push('/couple')                                  │
│                                                                      │
│  ── Mes documents ──                                                 │
│  Source: DocumentProvider.documents                                   │
│  Affiche : liste docs scannés + bouton [📷 Scanner]                 │
│  onTap doc : → context.push('/documents/{id}')                      │
│  onTap scanner : → context.push('/scan')                            │
│                                                                      │
│  ── Paramètres ──                                                    │
│  [Clé API (BYOK)] → /profile/byok                                   │
│  [Notifications] → /profile/notifications                            │
│  [Confidentialité] → /profile/consent                                │
│  [Langue] → changement locale inline                                 │
│  [Intensité coach] → slider 1-5                                      │
│  [Se déconnecter] → AuthProvider.logout()                            │
│                                                                      │
│  🧪 test_drawer_opens_from_header_icon                               │
│  🧪 test_drawer_shows_profile_data                                   │
│  🧪 test_drawer_couple_hidden_if_single                             │
│  🧪 test_drawer_documents_shows_scanned                             │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

### 2.7 Coach omniprésent (Bottom Sheet depuis n'importe quel écran)

```
┌──────────────────────────────────────────────────────────────────────┐
│  [S11] COACH BOTTOM SHEET                                            │
│                                                                      │
│  📍 widgets/coach_bottom_sheet.dart (À CRÉER)                        │
│  Disponible depuis : tout écran de simulateur/hub                    │
│  Trigger : bouton flottant 💬 en bas à droite OU swipe up           │
│                                                                      │
│  ENTRÉE :                                                            │
│  📦 CoachEntryPayload(                                               │
│    source: 'bottom_sheet',                                           │
│    topic: currentScreen.topic,  // ex: 'hypotheque', 'rachat_lpp'   │
│    data: currentScreen.currentValues  // les valeurs du simulateur   │
│  )                                                                   │
│                                                                      │
│  COMPORTEMENT :                                                      │
│  - Demi-écran (50% height) avec le chat coach                       │
│  - Le simulateur reste visible en arrière-plan                       │
│  - Le coach CONNAÎT le contexte du simulateur                        │
│  - "Avec ces chiffres, ta charge est à 38%. Les banques refuseront."│
│                                                                      │
│  EXPAND :                                                            │
│  - Swipe up → full screen = [S8] CONVERSATION                       │
│  - Le contexte est préservé                                          │
│                                                                      │
│  🧪 test_bottom_sheet_receives_simulator_context                     │
│  🧪 test_bottom_sheet_expands_to_full_conversation                  │
│  🧪 test_bottom_sheet_available_on_all_simulators                   │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 3. WIRE SPEC — Chaque câble

### 3.1 Câble : Landing → Chiffre Choc Instant

```
SOURCE     : screens/landing_screen.dart
FONCTION   : _onCalculate()
DESTINATION: screens/onboarding/instant_chiffre_choc_screen.dart
MÉTHODE    : context.push('/chiffre-choc-instant', extra: payload)

📦 PAYLOAD :
{
  'birthYear': _birthYear!,          // int (ex: 1977)
  'grossSalary': _grossSalary!,      // double (ex: 122207.0)
  'canton': _canton!,                // String (ex: 'VS')
}

RÉCEPTION :
  final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
  _birthYear = extra?['birthYear'] as int?;
  _grossSalary = extra?['grossSalary'] as double?;
  _canton = extra?['canton'] as String?;

🧪 TEST :
  testWidgets('landing passes 3 fields to chiffre choc', (tester) async {
    // Remplir les 3 champs
    // Tap "Calculer"
    // Vérifier que InstantChiffreChocScreen reçoit les 3 valeurs
    // Vérifier que ChiffreChocSelector.select() est appelé (pas de calcul direct)
  });
```

### 3.2 Câble : Chiffre Choc → Promesse

```
SOURCE     : screens/onboarding/instant_chiffre_choc_screen.dart
FONCTION   : _onEmotionCaptured()
DESTINATION: screens/onboarding/promise_screen.dart (À CRÉER)
MÉTHODE    : context.push('/onboarding/promise')

📦 PAYLOAD :
  Aucun paramètre direct.
  Données dans SharedPreferences (déjà écrites) :
  - onboarding_birth_year
  - onboarding_gross_salary
  - onboarding_canton
  - onboarding_choc_type
  - onboarding_choc_value
  - onboarding_emotion

PRÉ-CONDITION :
  SharedPreferences contient les 6 clés (écrites juste avant le push).

🧪 TEST :
  testWidgets('chiffre choc stores emotion then pushes promise', (tester) async {
    // Simuler le flow complet
    // Vérifier SharedPrefs contiennent les 6 clés
    // Vérifier navigation vers /onboarding/promise
  });
```

### 3.3 Câble : Promesse → Register OU Mode Libre

```
SOURCE     : screens/onboarding/promise_screen.dart (À CRÉER)
DESTINATION A : screens/auth/register_screen.dart
DESTINATION B : /home (en mode limité)

MÉTHODE A (Allons-y) :
  context.go('/auth/register?redirect=/home');
  // Le register NE redemande PAS âge/salaire/canton.
  // Ces données sont DÉJÀ dans SharedPreferences.
  // Post-register → redirect /home → CoachProfileProvider.loadFromWizard()
  //   qui lit SharedPrefs et hydrate le profil.

MÉTHODE B (Juste les chiffres) :
  // CoachProfileProvider est hydraté depuis SharedPrefs (local uniquement)
  // AuthProvider.isLoggedIn reste false
  // Navigation vers /home (mode libre = explorer seulement)
  // Auth guard modifié : /home accessible en mode libre
  //   MAIS coach/plan/mémoire requièrent auth
  context.go('/home?mode=libre');

📦 PAYLOAD : aucun (SharedPrefs suffisent)

🧪 TESTS :
  testWidgets('promise allons-y routes to register with redirect', ...);
  testWidgets('promise mode libre routes to home without auth', ...);
  testWidgets('register screen does NOT show age salary canton fields', ...);
```

### 3.4 Câble : MINT Home → Conversation (tap chiffre)

```
SOURCE     : screens/main_tabs/mint_home_screen.dart (À CRÉER)
WIDGET     : ChiffreDuJourCard.onTap
DESTINATION: screens/coach/coach_chat_screen.dart
MÉTHODE    : context.push('/coach/chat', extra: payload)

📦 PAYLOAD :
  CoachEntryPayload(
    source: 'home_chiffre',
    topic: mintState.chiffreDuJour.type.name,  // ex: 'retirementGap'
    data: {
      'value': mintState.chiffreDuJour.rawValue,      // ex: 4200.0
      'formatted': mintState.chiffreDuJour.value,      // ex: "4'200"
      'confidence': mintState.confidenceScore.overall,  // ex: 0.62
    },
  )

RÉCEPTION par CoachChatScreen :
  final payload = GoRouterState.of(context).extra as CoachEntryPayload?;
  if (payload != null) {
    // Injecte dans le system prompt via ContextInjectorService
    // "L'utilisateur a tapé sur son chiffre du jour (retirementGap = 4200).
    //  Explique ce chiffre et propose ses leviers."
    _sendInitialPrompt(_buildContextualPrompt(payload));
  }

🧪 TESTS :
  testWidgets('tap chiffre du jour opens coach with retirement context', ...);
  testWidgets('coach first message references the tapped number', ...);
```

### 3.5 Câble : Simulateur → Coach Bottom Sheet

```
SOURCE     : N'importe quel écran simulateur (ex: rachat_lpp_screen.dart)
WIDGET     : FloatingActionButton 💬
DESTINATION: widgets/coach_bottom_sheet.dart (À CRÉER)
MÉTHODE    : showModalBottomSheet(context, builder: CoachBottomSheet(payload))

📦 PAYLOAD :
  CoachEntryPayload(
    source: 'simulator',
    topic: 'rachat_lpp',
    data: {
      'currentAmount': _rachatAmount,
      'projectedImpact': _projectedMonthlyGain,
      'taxSaving': _taxSaving,
      'eplBlocked': _eplBlocked,
    },
  )

🧪 TEST :
  testWidgets('simulator FAB opens coach with current simulation values', ...);
```

### 3.6 Câble : Coach tool_call → Exécution Flutter

```
SOURCE     : Backend Claude response (tool_use blocks)
PARSING    : screens/coach/coach_chat_screen.dart → _parseToolCalls()
PATTERN    : [TOOL_NAME:{json}] dans le texte de réponse

📦 TOOL REGISTRY :

  static final Map<String, Function(Map<String, dynamic>)> _toolHandlers = {
    'ROUTE_TO_SCREEN': (args) {
      final route = args['route'] as String;
      if (_isValidRoute(route)) {
        context.push(route);
      }
    },
    'SHOW_FACT_CARD': (args) {
      _addWidget(ResponseCard(
        title: args['title'],
        value: args['value'],
        subtitle: args['subtitle'],
        sources: args['sources'],
      ));
    },
    'SHOW_COMPARISON': (args) {
      _addWidget(ArbitrageCard(
        optionA: args['optionA'],
        optionB: args['optionB'],
        // toujours side-by-side, jamais ranked
      ));
    },
    'UPDATE_PROFILE': (args) {
      final provider = context.read<CoachProfileProvider>();
      provider.updateField(args['field'], args['value']);
    },
    'REQUEST_DOCUMENT_SCAN': (args) {
      showModalBottomSheet(context, builder: (_) => ScanBottomSheet(
        documentType: args['type'],
        hint: args['hint'],
      ));
    },
  };

🧪 TESTS :
  testWidgets('ROUTE_TO_SCREEN tool pushes correct route', ...);
  testWidgets('SHOW_FACT_CARD renders ResponseCard in chat', ...);
  testWidgets('UPDATE_PROFILE modifies CoachProfileProvider', ...);
  testWidgets('invalid route in ROUTE_TO_SCREEN is rejected', ...);
```

---

## 4. KILL LIST

### 4.1 Routes à SUPPRIMER (legacy, doublons, feature-flagged)

```
SUPPRIMER (30 routes) :

  LEGACY REDIRECTS (déjà des redirects, plus besoin) :
  /coach/dashboard       → était redirect vers /retraite
  /retirement            → était redirect vers /retraite
  /lpp-deep/rachat       → était redirect vers /rachat-lpp
  /simulator/3a          → était redirect vers /pilier-3a

  DOUBLONS :
  /bank-import           → garder /bank-import-v2 uniquement
  /education/hub         → fusionner dans Explorer
  /education/theme/:id   → fusionner dans Explorer
  /confidence            → intégré dans MINT Home (barre de confiance)
  /score-reveal          → intégré dans MINT Home (barre de confiance)

  FEATURE-FLAGGED (pas dans V1) :
  /expert-tier           → P3
  /b2b                   → P4
  /open-banking          → P2
  /open-banking/*        → P2
  /pension-fund-connect  → P4
  /profile/admin-*       → dev-only, pas en prod

  DÉPLACÉS (plus des routes top-level, deviennent des sous-écrans) :
  /onboarding/quick      → supprimé (onboarding = chat ou landing)
  /onboarding/chiffre-choc → supprimé (unifié dans /chiffre-choc-instant)
  /coach/history         → déplacé dans tiroir profil
  /coach/checkin         → supprimé (remplacé par signaux proactifs)
  /coach/refresh         → supprimé (fonctionnalité inutile)
  /coach/cockpit         → supprimé (données dans MINT Home)
  /ask-mint              → supprimé (le coach EST ask-mint)
  /tools                 → supprimé (outils dans Explorer)
  /portfolio             → intégré dans tiroir profil (patrimoine)
  /timeline              → intégré dans tiroir profil (Mon Plan)
  /achievements          → intégré dans tiroir profil
  /weekly-recap          → devient un signal proactif dans MINT Home
  /cantonal-benchmark    → intégré dans Explorer > Fiscalité
```

### 4.2 Routes à GARDER (40 routes)

```
GARDER (routes actives post-refactor) :

  ONBOARDING (4) :
  /                          → LandingScreen
  /chiffre-choc-instant      → InstantChiffreChocScreen
  /onboarding/promise        → PromiseScreen (NOUVEAU)
  /auth/register             → RegisterScreen

  AUTH (3) :
  /auth/login                → LoginScreen
  /auth/forgot-password      → ForgotPasswordScreen
  /auth/verify-email         → VerifyEmailScreen

  MAIN (1) :
  /home                      → MainNavigationShell (2 tabs)

  COACH (1) :
  /coach/chat                → CoachChatScreen

  EXPLORER HUBS (7) :
  /explore/retraite          → RetraiteHubScreen
  /explore/famille           → FamilleHubScreen
  /explore/travail           → TravailHubScreen
  /explore/logement          → LogementHubScreen
  /explore/fiscalite         → FiscaliteHubScreen
  /explore/patrimoine        → PatrimoineHubScreen
  /explore/sante             → SanteHubScreen

  SIMULATEURS RETRAITE (7) :
  /retraite                  → RetirementDashboard
  /rente-vs-capital          → RenteVsCapitalScreen
  /rachat-lpp                → RachatLppScreen
  /epl                       → EplScreen
  /decaissement              → DecaissementScreen
  /succession                → SuccessionScreen
  /libre-passage             → LibrePassageScreen

  SIMULATEURS FISCALITÉ (5) :
  /pilier-3a                 → Pilier3aScreen
  /3a-deep/comparateur       → Comparateur3aScreen
  /3a-deep/rendement         → Rendement3aScreen
  /3a-deep/echelonne         → Echelonne3aScreen
  /3a-deep/retroactif        → Retroactif3aScreen

  SIMULATEURS LOGEMENT (4) :
  /hypotheque                → HypothequeScreen
  /mortgage/amortissement    → AmortissementScreen
  /mortgage/valeur-locative  → ValeurLocativeScreen
  /mortgage/saron-vs-fixe    → SaronVsFixeScreen

  SIMULATEURS FAMILLE/TRAVAIL/SANTÉ (9) :
  /divorce, /mariage, /naissance, /concubinage
  /unemployment, /first-job, /expatriation
  /invalidite, /assurances/lamal

  PROFIL & DOCS (5) :
  /profile                   → ProfileScreen
  /profile/byok              → ByokScreen
  /profile/consent           → ConsentScreen
  /scan                      → ScanScreen
  /documents                 → DocumentsScreen

  COUPLE (1) :
  /couple                    → CoupleScreen

  TOTAL : ~42 routes (vs 70 actuellement)
```

---

## 5. MIGRATION TABLE

### 5.1 MainNavigationShell : 4 tabs → 2 tabs + drawer

```
AVANT (main_navigation_shell.dart:54-59) :
  static const List<Widget> _tabs = [
    PulseScreen(),     // 0
    MintCoachTab(),    // 1
    ExploreTab(),      // 2
    DossierTab(),      // 3
  ];

APRÈS :
  static const List<Widget> _tabs = [
    MintHomeScreen(),  // 0 (fusionne Pulse + coach input + signaux)
    ExploreTab(),      // 1 (refactored: search-first + lifecycle)
  ];

  // DossierTab → ProfileDrawer (tiroir latéral)
  // MintCoachTab → supprimé (coach = input field dans MintHome
  //                + bottom sheet + full screen /coach/chat)

MIGRATION :
  1. Créer MintHomeScreen (nouveau fichier)
  2. Refactorer ExploreTab (ajouter search, lifecycle ordering)
  3. Créer ProfileDrawer (nouveau widget)
  4. Modifier MainNavigationShell : 2 tabs + drawer
  5. Mettre à jour les deep links /home?tab=
     /home?tab=0 → MINT Home
     /home?tab=1 → Explorer
     /home?tab=2 → ⚠️ REDIRECT vers /home?tab=1
     /home?tab=3 → ⚠️ ouvre le drawer
```

### 5.2 Query params tab= : migration

```
AVANT :
  /home?tab=0  → Pulse
  /home?tab=1  → Coach
  /home?tab=2  → Explorer
  /home?tab=3  → Dossier

APRÈS :
  /home?tab=0  → MINT Home (inchangé, contenu différent)
  /home?tab=1  → Explorer (était tab 2)
  /home?tab=2  → REDIRECT → /home?tab=1 (pour compat)
  /home?tab=3  → REDIRECT → /home?tab=0 + ouvre drawer

TOUS les context.go('/home?tab=X') dans le code doivent être mis à jour.
```

---

## 6. PROVIDER REFACTOR

### 6.1 Changements

```
SUPPRIMER (2) :
  - ProfileProvider        → fonctions absorbées par CoachProfileProvider
  - SlmProvider            → intégré dans ByokProvider (SlmProvider.init()
                             appelé dans ByokProvider.loadSavedKey())

CRÉER (1) :
  - OnboardingProvider     → remplace les 6 clés SharedPreferences
    📦 OnboardingPayload {
      int? birthYear;
      double? grossSalary;
      String? canton;
      ChiffreChocType? chocType;
      double? chocValue;
      String? emotion;
      bool get isComplete => birthYear != null && grossSalary != null;
    }
    PERSISTE en SharedPreferences (pour survie app kill)
    MAIS exposé comme Provider typé (testable, visible dans widget tree)

MODIFIER (2) :
  - CoachProfileProvider   → absorbe ProfileProvider
  - MintStateProvider      → ajoute chiffreDuJour, topLever, signals
    📦 MintUserState (enrichi) {
      ChiffreChoc chiffreDuJour;         // rotation quotidienne
      CapRecommendation topLever;         // meilleur levier
      List<ProactiveSignal> signals;      // alertes actives
      EnhancedConfidence confidenceScore; // score global
      BudgetSnapshot budgetSnapshot;      // budget A, B, gap
    }

RÉSULTAT :

  AVANT (12 providers) :
  AuthProvider, ProfileProvider, CoachProfileProvider, BudgetProvider,
  ByokProvider, DocumentProvider, SubscriptionProvider, HouseholdProvider,
  MintStateProvider, LocaleProvider, UserActivityProvider, SlmProvider

  APRÈS (11 providers) :
  AuthProvider, CoachProfileProvider (enrichi), BudgetProvider,
  ByokProvider (inclut SLM), DocumentProvider, SubscriptionProvider,
  HouseholdProvider, MintStateProvider (enrichi), LocaleProvider,
  UserActivityProvider, OnboardingProvider (nouveau)
```

---

## 7. ACCEPTANCE TESTS

### 7.1 Tests de CÂBLAGE (prouvent que les fils sont connectés)

Chaque test vérifie qu'un objet Dart transite correctement d'un point A à un point B.

```dart
// ══════════════════════════════════════════════════
// FICHIER : test/wire/onboarding_wire_test.dart
// ══════════════════════════════════════════════════

group('Onboarding → Coach wire', () {

  testWidgets('W1: Landing passes 3 fields to ChiffreChocInstant', (t) async {
    // GIVEN: landing with birthYear=1977, salary=122207, canton=VS
    // WHEN: tap "Calculer"
    // THEN: InstantChiffreChocScreen receives these 3 values via route extra
    // AND: ChiffreChocSelector.select() is called (not direct AVS calc)
  });

  testWidgets('W2: ChiffreChoc stores 6 keys in SharedPreferences', (t) async {
    // GIVEN: InstantChiffreChocScreen with profile data
    // WHEN: user selects emotion chip
    // THEN: SharedPreferences contains all 6 onboarding_* keys
    // AND: values match what was entered/calculated
  });

  testWidgets('W3: 19yo sees compound growth, not retirement', (t) async {
    // GIVEN: birthYear=2007 (age 19)
    // WHEN: ChiffreChocSelector.select(profile)
    // THEN: result.type == ChiffreChocType.compoundGrowth
    // AND: displayed text contains "intérêts composés" not "retraite"
  });

  testWidgets('W4: Emotion survives registration', (t) async {
    // GIVEN: user completed chiffre choc with emotion="C'est flippant"
    // WHEN: user registers (email/password)
    // THEN: SharedPreferences still contains onboarding_emotion
    // AND: coach's first context includes the emotion
  });

  testWidgets('W5: Coach receives full onboarding context', (t) async {
    // GIVEN: SharedPrefs with all 6 onboarding keys
    // WHEN: CoachChatScreen opens for the first time
    // THEN: ContextInjectorService._buildOnboardingBlock() returns non-empty
    // AND: block contains chocType, chocValue, emotion
    // AND: keys are cleared after first read (one-shot)
  });

  testWidgets('W6: Register does NOT ask for age/salary/canton', (t) async {
    // GIVEN: SharedPrefs with onboarding data
    // WHEN: RegisterScreen builds
    // THEN: no TextFormField for birthYear, salary, or canton
    // AND: only email + password fields present
  });

});

// ══════════════════════════════════════════════════
// FICHIER : test/wire/home_wire_test.dart
// ══════════════════════════════════════════════════

group('MINT Home → Coach wire', () {

  testWidgets('W7: Tap chiffre du jour opens coach with context', (t) async {
    // GIVEN: MintHome showing chiffreDuJour (retirementGap, 4200)
    // WHEN: tap on ChiffreDuJourCard
    // THEN: navigates to /coach/chat
    // AND: CoachChatScreen receives CoachEntryPayload with:
    //   source='home_chiffre', topic='retirementGap', data.value=4200
  });

  testWidgets('W8: Suggestion chips pass topic to coach', (t) async {
    // GIVEN: MintHome showing chip "Rente ou capital ?"
    // WHEN: tap chip
    // THEN: navigates to /coach/chat with topic='rente_vs_capital'
  });

  testWidgets('W9: Text input opens coach with user message', (t) async {
    // GIVEN: MintHome with coach input field
    // WHEN: type "combien à la retraite" + submit
    // THEN: navigates to /coach/chat
    // AND: first message = "combien à la retraite"
  });

  testWidgets('W10: Lever card routes to simulator', (t) async {
    // GIVEN: MintHome showing lever "Rachat LPP"
    // WHEN: tap [Simuler]
    // THEN: navigates to /rachat-lpp
  });

  testWidgets('W11: Signal card routes to action', (t) async {
    // GIVEN: MintHome showing signal "3a non versé"
    // WHEN: tap [Agir]
    // THEN: navigates to /pilier-3a
  });

});

// ══════════════════════════════════════════════════
// FICHIER : test/wire/coach_tools_wire_test.dart
// ══════════════════════════════════════════════════

group('Coach tool execution wire', () {

  testWidgets('W12: ROUTE_TO_SCREEN pushes valid route', (t) async {
    // GIVEN: coach response contains [ROUTE_TO_SCREEN:{"route":"/rachat-lpp"}]
    // WHEN: response is parsed
    // THEN: context.push('/rachat-lpp') is called
  });

  testWidgets('W13: SHOW_FACT_CARD renders inline widget', (t) async {
    // GIVEN: coach response contains [SHOW_FACT_CARD:{...}]
    // WHEN: response is parsed
    // THEN: ResponseCard widget appears in chat list
  });

  testWidgets('W14: UPDATE_PROFILE modifies provider', (t) async {
    // GIVEN: coach response contains [UPDATE_PROFILE:{"field":"salary","value":130000}]
    // WHEN: response is parsed
    // THEN: CoachProfileProvider.profile.grossSalary == 130000
  });

  testWidgets('W15: Invalid route in ROUTE_TO_SCREEN is rejected', (t) async {
    // GIVEN: coach response contains [ROUTE_TO_SCREEN:{"route":"https://evil.com"}]
    // WHEN: response is parsed
    // THEN: navigation does NOT happen
    // AND: error is logged
  });

});

// ══════════════════════════════════════════════════
// FICHIER : test/wire/explorer_wire_test.dart
// ══════════════════════════════════════════════════

group('Explorer lifecycle wire', () {

  testWidgets('W16: Explorer reorders hubs by lifecycle phase', (t) async {
    // GIVEN: profile with age=25 (phase=construction)
    // WHEN: ExploreTab builds
    // THEN: first 3 hubs = [Logement, Famille, Fiscalité] (not Retraite)
  });

  testWidgets('W17: Retraite hub hides rachat if phase < acceleration', (t) async {
    // GIVEN: profile with age=28 (phase=construction)
    // WHEN: RetraiteHubScreen builds
    // THEN: "Rachat LPP" item is NOT visible
  });

  testWidgets('W18: Search finds hypotheque', (t) async {
    // GIVEN: Explorer with search bar
    // WHEN: type "hypoth"
    // THEN: results include "Hypothèque" with route /hypotheque
  });

});

// ══════════════════════════════════════════════════
// FICHIER : test/wire/maturity_wire_test.dart
// ══════════════════════════════════════════════════

group('Maturity progressive wire', () {

  testWidgets('W19: First visit shows only chiffre, no lever', (t) async {
    // GIVEN: UserActivityProvider.sessionCount == 1
    // WHEN: MintHome builds
    // THEN: ChiffreDuJourCard is visible
    // AND: LeverDuJourCard is NOT visible
    // AND: animations are slow (maturityLevel=1)
  });

  testWidgets('W20: Visit 5+ shows lever card', (t) async {
    // GIVEN: UserActivityProvider.sessionCount == 5
    // WHEN: MintHome builds
    // THEN: LeverDuJourCard IS visible
    // AND: ChiffreDuJourCard has chart below number
  });

});
```

---

## 8. PLAN D'EXÉCUTION

### L'ORDRE EXACT (dépendances respectées)

```
PHASE 0 — FONDATIONS (pas d'UI, que du plumbing)
═══════════════════════════════════════════════════
Durée estimée : 1 sprint

  P0.1 — Créer CoachEntryPayload
         📍 lib/models/coach_entry_payload.dart
         📦 { source, topic, data, userMessage }
         Impacte : rien encore (aucun écran ne l'utilise)
         🧪 test unitaire du model

  P0.2 — Créer OnboardingProvider
         📍 lib/providers/onboarding_provider.dart
         Remplace les 6 clés SharedPreferences par un Provider typé
         Persiste en SharedPrefs (survie app kill)
         🧪 test: store + retrieve + clear

  P0.3 — Enrichir MintStateProvider
         Ajouter : chiffreDuJour, topLever, signals
         chiffreDuJour = ChiffreChocSelector.select(profile) avec rotation
         topLever = CapEngine.topRecommendation(profile)
         signals = ProactiveTriggerService.evaluate(profile)
         🧪 test: recompute produit chiffreDuJour correct

  P0.4 — Refactorer CoachChatScreen pour accepter CoachEntryPayload
         Route extra: CoachEntryPayload au lieu de String? prompt
         Backward compat: si extra est null, comportement actuel
         🧪 test W7, W8, W9


PHASE 1 — MINT HOME (le nouvel écran principal)
═══════════════════════════════════════════════════
Durée estimée : 1 sprint
Dépend de : P0 complète

  P1.1 — Créer MintHomeScreen
         📍 lib/screens/main_tabs/mint_home_screen.dart
         Sections : ChiffreDuJourCard + LeverDuJourCard +
                    SignalCard + CoachInputBar + SuggestionChips
         Lit : MintStateProvider, CoachProfileProvider, UserActivityProvider
         🧪 tests W7-W11, W19-W20

  P1.2 — Créer ProfileDrawer
         📍 lib/widgets/profile_drawer.dart
         Sections : profil, plan, couple, docs, paramètres
         Remplace DossierTab
         🧪 test drawer opens, shows data

  P1.3 — Modifier MainNavigationShell : 4 tabs → 2 tabs + drawer
         📍 main_navigation_shell.dart
         _tabs = [MintHomeScreen, ExploreTab]
         Ajouter drawer trigger sur icône 👤
         Migration des deep links /home?tab=
         🧪 test navigation 2 tabs


PHASE 2 — ONBOARDING RÉPARÉ
═══════════════════════════════════════════════════
Durée estimée : 1 sprint
Dépend de : P0.2 (OnboardingProvider)

  P2.1 — Créer PromiseScreen
         📍 lib/screens/onboarding/promise_screen.dart
         Route : /onboarding/promise
         Texte adapté par LifecyclePhase (3 variantes min)
         2 boutons : Allons-y → register, Juste les chiffres → home libre
         🧪 tests W6, promise_text_adapts_to_age

  P2.2 — Réparer le flux Chiffre Choc → Promesse → Register
         Modifier instant_chiffre_choc_screen.dart :
           post-émotion → context.push('/onboarding/promise')
           (au lieu de context.go('/auth/register'))
         Modifier register_screen.dart :
           supprimer champs âge/salaire/canton si déjà dans SharedPrefs
         🧪 tests W1-W6

  P2.3 — Mode libre (sans inscription)
         Modifier auth guard dans app.dart :
           si path == '/home' && queryParam mode=libre → pas de redirect
           limiter accès : /coach/chat requiert auth
         🧪 test mode_libre_accesses_explorer


PHASE 3 — EXPLORER REFACTORED
═══════════════════════════════════════════════════
Durée estimée : 1 sprint
Dépend de : P1.3 (2 tabs)

  P3.1 — Ajouter SearchBar à ExploreTab
         SearchDelegate avec index local des routes + mots-clés
         🧪 test W18

  P3.2 — Lifecycle ordering des hubs
         ExploreTab lit LifecyclePhaseService.detect()
         Section "Ton parcours" avec top 3 hubs
         🧪 tests W16, W17

  P3.3 — Section "Événements de vie"
         Chips pour les 18 life events
         onTap → route vers le bon écran
         🧪 test life_events_route_correctly


PHASE 4 — COACH OMNIPRÉSENT
═══════════════════════════════════════════════════
Durée estimée : 1 sprint
Dépend de : P0.4 (CoachEntryPayload), P1.1 (MintHome)

  P4.1 — CoachBottomSheet
         📍 lib/widgets/coach_bottom_sheet.dart
         Demi-écran, reçoit CoachEntryPayload du simulateur courant
         Expand → full screen /coach/chat
         🧪 test W15 (bottom_sheet_receives_simulator_context)

  P4.2 — Tool call execution côté Flutter
         Parser [TOOL_NAME:{json}] dans les réponses coach
         Exécuter : ROUTE_TO_SCREEN, SHOW_FACT_CARD, UPDATE_PROFILE, etc.
         🧪 tests W12-W15

  P4.3 — FAB coach sur tous les simulateurs
         Ajouter FloatingActionButton 💬 sur chaque écran simulateur
         onTap: showModalBottomSheet(CoachBottomSheet(payload))
         Payload construit depuis les valeurs courantes du simulateur


PHASE 5 — KILL + CLEAN
═══════════════════════════════════════════════════
Durée estimée : 0.5 sprint
Dépend de : P1-P4 complètes

  P5.1 — Supprimer les 30 routes de la KILL LIST (§4.1)
         Supprimer les fichiers écrans correspondants
         Mettre à jour app.dart

  P5.2 — Supprimer ProfileProvider et SlmProvider
         Migrer les consommateurs vers CoachProfileProvider et ByokProvider
         Mettre à jour MultiProvider dans app.dart

  P5.3 — Supprimer les écrans orphelins
         PulseScreen → remplacé par MintHomeScreen
         MintCoachTab → remplacé par coach input dans MintHome
         DossierTab → remplacé par ProfileDrawer

  P5.4 — Audit final
         flutter analyze (0 issues)
         flutter test (0 failures)
         Vérifier les 20 wire tests (W1-W20) tous verts
```

---

## RÉSUMÉ : Ce qu'on produit vs ce qu'on produisait

| Avant (façade) | Maintenant (construction) |
|---|---|
| "Le coach reçoit l'émotion" | `OnboardingProvider.emotion → ContextInjectorService._buildOnboardingBlock() → coach system prompt line 427` |
| "Tap → conversation" | `ChiffreDuJourCard.onTap → context.push('/coach/chat', extra: CoachEntryPayload(source: 'home_chiffre', topic: chiffreDuJour.type.name))` |
| "Explorer adaptatif" | `ExploreTab.build() → LifecyclePhaseService.detect(profile).priorities.take(3) → reorder _hubs` |
| "Coach exécute des tools" | `_parseToolCalls(response) → _toolHandlers['ROUTE_TO_SCREEN'](args) → context.push(route)` |
| "L'interface évolue" | `UserActivityProvider.maturityLevel → if (level < 2) hide(LeverDuJourCard)` |
| "On teste" | `testWidgets('W7: Tap chiffre opens coach with context', ...)` — 20 wire tests nommés |

**La différence** : chaque phrase de design est maintenant un fichier source, une ligne, un type Dart, et un test nommé. Pas de marge d'interprétation. Pas de façade possible.
