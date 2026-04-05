# MINT — WIRE SPEC V2 : Le document de construction

> **V2** — Intègre : Wire Spec V1 + contre-audit (7 corrections) + itération créative
> (7 idées enrichies) + audit expert final (8 corrections de précision).
>
> **⚠️ LEGACY NOTE (2026-04-05):** Ce document utilise "chiffre choc" comme legacy term technique.
> Concept canonique : **"premier éclairage"** (voir `docs/MINT_IDENTITY.md`). Migration code à planifier.
>
> **Ce document n'est PAS un flowchart.** C'est une spec d'ingénierie.
> Chaque flèche = un appel de fonction. Chaque boîte = un état avec ses données.
> Chaque transition = un fichier source, une ligne, un objet typé.
> Chaque câble = un test d'acceptance qui prouve qu'il est connecté.
>
> **Règle** : si c'est pas dans ce document, ça n'existe pas dans l'app.

---

## TABLE DES MATIÈRES

1. [DELTA V1 → V2 — Ce qui change](#1-delta-v1--v2)
2. [ÉTAT ACTUEL — Ce qui existe dans le code](#2-état-actuel)
3. [STATE MACHINE — Chaque état, chaque transition](#3-state-machine)
4. [WIRE SPEC — Chaque câble, chaque objet, chaque test](#4-wire-spec)
5. [KILL LIST — Ce qu'on supprime](#5-kill-list)
6. [MIGRATION TABLE — Avant/Après routes](#6-migration-table)
7. [PROVIDER REFACTOR — 12 → 11](#7-provider-refactor)
8. [ACCEPTANCE TESTS — 34 wire tests](#8-acceptance-tests)
9. [PLAN D'EXÉCUTION — L'ordre exact](#9-plan-dexécution)
10. [VISION 2027-2030 — Les 3 paris stratégiques](#10-vision-2027-2030)

---

## 1. DELTA V1 → V2

### Ce qui change par rapport au V1

| # | Changement | Source | Raison |
|---|-----------|--------|--------|
| 1 | **3 tabs** (pas 2) | Contre-audit P1 | Coach mérite l'IndexedStack pour la persistance de conversation |
| 2 | **OnboardingProvider = seul writer/reader** | Contre-audit P2 | SharedPrefs directes = incohérence. Provider = API unique. |
| 3 | **Chiffre par pertinence** (pas rotation calendaire) | Contre-audit P3 | trigger > enrichment > CapEngine. Change quand le contexte change. |
| 4 | **Coach bottom sheet sur 5 simulateurs** (pas tous) | Contre-audit P4 | Scope réaliste. Pattern CoachAwareSimulator posé pour V2. |
| 5 | **P2 séquentiel strict** | Contre-audit P5 | P2.1→P2.2→P2.3 ne sont pas parallélisables. |
| 6 | **Flux retour utilisateur (S1-RETURN)** | Contre-audit P6 | Le trou le plus grave du V1. 4 tests ajoutés (W21-W24). |
| 7 | **Mini-consent mode libre** | Contre-audit P7 | nLPD : transparence même sans inscription. |
| 8 | **Chiffre vivant / GPS** | Itération créative, idée 1 | Delta depuis dernière visite + ETA retraite + itinéraire alternatif |
| 9 | **Coach interrupt (JITAI)** | Itération créative, idée 2 | Banner intelligent dans 5 simulateurs |
| 10 | **Onboarding Hinge** | Itération créative, idée 3 | 3 prompts émotionnels au lieu d'un formulaire |
| 11 | **Financial Wrapped** | Itération créative, idée 4 | Rétention annuelle (décembre) |
| 12 | **Scan Magique** | Itération créative, idée 5 | Moment Shazam = APRÈS la review |
| 13 | **Scan Corporel mensuel** | Itération créative, idée 6 | Mensuel (pas hebdo). Silence si rien ne change. |
| 14 | **Radar anticipatoire + coût du retard** | Itération créative, idée 7 + audit final | "Ce qui arrive" + "chaque mois te coûte X" |
| 15 | **Delta distingue inaction vs macro** | Audit final | Ne pas punir l'utilisateur pour le contexte |
| 16 | **Dismiss counter max 3** | Audit final | Après 3 [Plus tard], le coach se tait |
| 17 | **Wrapped CHF dans l'app, % si export** | Audit final (compromis) | L'émotion est en CHF, la sécurité en % |
| 18 | **Generative UI = templates contraints** | Audit final | Pas de génération libre. Tool calls + financial_core. |

### Compteurs

| Métrique | V1 | V2 |
|----------|----|----|
| Wire tests | 20 | **34** |
| Routes après kill | 42 | **43** (+/onboarding/promise) |
| Tabs | 2 (proposé) → 4 (actuel) | **3 + drawer** |
| Providers | 12 → 11 | **12 → 11** (inchangé) |
| Phases d'exécution | 5 | **5 + post-launch** |

---

## 2. ÉTAT ACTUEL

### 2.1 Routes (source : `app.dart:161-973`)

**70 routes GoRouter. 12 providers. 4 tabs.**

*(Identique au V1 — voir V1 §1.1 pour la liste complète)*

### 2.2 Providers actuels (source : `app.dart:1018-1080`)

*(Identique au V1 — voir V1 §1.2 pour le tableau)*

### 2.3 Les 3 problèmes structurels

*(Identiques au V1 — P1 double source profil, P2 onboarding via SharedPrefs, P3 coach entry point unique)*

### 2.4 Services proactifs — inventaire réel

| Service | Statut | Intégré à l'UI ? |
|---------|--------|-------------------|
| **CapEngine** | ✅ Opérationnel | ✅ Oui (MintStateEngine → Pulse) |
| **CapSequenceEngine** | ✅ Opérationnel | ✅ Oui (plans multi-étapes) |
| **ProactiveTriggerService** | ✅ Opérationnel | ✅ Oui (MintStateEngine → pendingTrigger) |
| **NudgeEngine** | ✅ Opérationnel | ✅ Oui (MintStateEngine → activeNudges) |
| **SessionSnapshotService** | ✅ Opérationnel | ❌ Non surfacé dans l'UI |
| **PrecomputedInsightsService** | ⚠️ Calcul OK, lecture non câblée | ❌ Non consommé par aucun écran |
| **DataDrivenOpenerService** | ⚠️ Implémenté | ❌ Non appelé |
| **JitaiNudgeService** | ❌ Dead code | ❌ Supersédé par NudgeEngine |
| **NotificationSchedulerService** | ⚠️ Dart = spec, Python = actif | ❌ Backend seulement |

**Conclusion** : 5 services sont opérationnels et intégrés. 3 sont implémentés mais non câblés. 1 est dead code. Le Wire Spec V2 câble les 3 services non connectés et réutilise le pattern du dead code (JitaiNudgeService) pour le CoachInterrupt.

---

## 3. STATE MACHINE

### 3.1 Notation

```
[ÉTAT]                     = un écran ou état de l'app
──{condition}──→           = transition avec condition
  📦 DataObject            = objet Dart qui transite
  📍 fichier.dart:ligne    = source code exacte
  🧪 test_name             = test d'acceptance
  🆕                       = nouveau en V2
```

### 3.2 Machine complète

```
                        ┌─────────────────────────────────────┐
                        │  [S0] APP_LAUNCH                    │
                        │                                     │
                        │  AuthProvider.checkAuth()            │
                        │  📍 app.dart:1020-1024              │
                        └──────────────┬──────────────────────┘
                                       │
                          ┌────────────┴────────────┐
                          │                         │
                   {isLoggedIn=true}         {isLoggedIn=false}
                          │                         │
                          ▼                         ▼
                 [S1-RETURN] 🆕              [S2] LANDING
                 (voir §3.4)                 (voir §3.3)
```

### 3.3 Onboarding Hinge (Landing → Chiffre Choc → Promesse → Home)

```
┌──────────────────────────────────────────────────────────────────────┐
│  [S2] LANDING — ONBOARDING HINGE 🆕                                 │
│                                                                      │
│  📍 screens/landing_screen.dart (REFACTORÉE)                         │
│  3 prompts plein-écran en swipe horizontal (pas un formulaire)       │
│                                                                      │
│  PROMPT 1 — "La retraite, pour toi, c'est dans..."                  │
│  ┌──────────────────────────────────────────────────────────────┐    │
│  │  Chips : [une éternité] [un moment] [demain]                │    │
│  │  Picker : année naissance (1960-2004)                        │    │
│  │  Le label s'adapte en temps réel à l'année choisie           │    │
│  │  → Capture : birthYear + anxietyLevel ('far'|'mid'|'close') │    │
│  └──────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  PROMPT 2 — "Combien tu gagnes ?"                                   │
│  ┌──────────────────────────────────────────────────────────────┐    │
│  │  Input : CHF _________ (clavier numérique)                  │    │
│  │  Micro-insight adaptatif au montant :                        │    │
│  │    >100k: "À la retraite, ~{60%} CHF/mois. Tu en vis       │    │
│  │            aujourd'hui avec ~{net}. Ça te suffirait ?"      │    │
│  │    <60k:  "À la retraite, ~{montant} CHF/mois.             │    │
│  │            Loyer + courses. Le reste, c'est serré."         │    │
│  │  → Capture : grossSalary + micro-insight vu                 │    │
│  └──────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  PROMPT 3 — "Chaque canton a ses règles."                           │
│  ┌──────────────────────────────────────────────────────────────┐    │
│  │  Picker : canton (26 cantons)                                │    │
│  │  Micro-insight cantonal immédiat :                           │    │
│  │    VS: "Impôt retrait capital parmi les plus bas."           │    │
│  │    GE: "Impôts parmi les plus élevés, mais les salaires     │    │
│  │         compensent largement."                               │    │
│  │    ZH: "Plus grand choix de caisses de prévoyance."         │    │
│  │  → Capture : canton + micro-insight vu                      │    │
│  └──────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  STOCKAGE : via OnboardingProvider (pas SharedPrefs directes) 🆕     │
│    context.read<OnboardingProvider>().setBirthYear(year);            │
│    context.read<OnboardingProvider>().setGrossSalary(salary);        │
│    context.read<OnboardingProvider>().setCanton(canton);             │
│                                                                      │
│  BOUTON : [Voir mon chiffre] → actif quand 3 prompts complétés     │
│                                                                      │
│  🧪 W30: test_hinge_prompt_1_adapts_label_to_birth_year             │
│  🧪 W31: test_hinge_prompt_2_microinsight_adapts_to_salary          │
│  🧪 W1: test_landing_passes_3_fields_to_chiffre_choc (maj.)        │
│                                                                      │
└──────────────────┬───────────────────────────────────────────────────┘
                   │
            {tap [Voir mon chiffre]}
                   │
                   ▼
┌──────────────────────────────────────────────────────────────────────┐
│  [S3] CHIFFRE CHOC INSTANT                                          │
│                                                                      │
│  📍 screens/onboarding/instant_chiffre_choc_screen.dart              │
│                                                                      │
│  ENTRÉE : lit OnboardingProvider (birthYear, grossSalary, canton)    │
│                                                                      │
│  TRAITEMENT :                                                        │
│  1. Construit MinimalProfileResult depuis OnboardingProvider         │
│  2. Appelle ChiffreChocSelector.select(profile)                     │
│     📍 chiffre_choc_selector.dart:30-68                              │
│  3. Reçoit ChiffreChoc { type, rawValue, title, subtitle }          │
│                                                                      │
│  AFFICHAGE — Révélation en 5 temps :                                 │
│  1. Setup text (350ms fade in)                                       │
│  2. Silence (800ms)                                                  │
│  3. CountUp digit par digit (600ms)                                  │
│  4. MintLigne (1px, 400ms)                                          │
│  5. Contexte + question ciblée (350ms)                               │
│                                                                      │
│  QUESTION CIBLÉE par ChiffreChocType :                               │
│  | Type              | Question                                     │
│  |-------------------|----------------------------------------------|
│  | compoundGrowth    | "Tu savais que le temps comptait autant ?"   │
│  | taxSaving3a       | "{amount} d'impôts en moins. 10 min ?"       │
│  | retirementGap     | "{amount} de moins par mois. Tu y pensais ?" │
│  | retirementIncome  | "{percent}%. Ça te suffit ?"                 │
│  | liquidityAlert    | "Moins de {months} mois de réserve."         │
│                                                                      │
│  CHIPS CONTEXTUELS (3 par type) :                                    │
│  retirementGap → [C'est flippant] [Je sais pas quoi faire]          │
│                  [Quels sont mes leviers ?]                           │
│                                                                      │
│  ⏳ 3.9s silence avant la question                                   │
│                                                                      │
│  CAPTURE ÉMOTION : via OnboardingProvider.setEmotion(chip/text)     │
│  CAPTURE CHOC : via OnboardingProvider.setChoc(type, value)         │
│                                                                      │
│  🧪 W2: test_chiffre_choc_stores_6_fields_in_onboarding_provider    │
│  🧪 W3: test_19yo_sees_compound_growth_not_retirement                │
│  🧪 W4: test_emotion_survives_registration                          │
│  🧪 W5: test_coach_receives_full_onboarding_context                 │
│                                                                      │
└──────────────────┬───────────────────────────────────────────────────┘
                   │
            {émotion capturée}
                   │
                   ▼
┌──────────────────────────────────────────────────────────────────────┐
│  [S4] PROMESSE                                                       │
│                                                                      │
│  📍 screens/onboarding/promise_screen.dart (À CRÉER)                 │
│  Route : /onboarding/promise                                         │
│                                                                      │
│  Lit OnboardingProvider.birthYear pour adapter le texte :            │
│  - 18-24 : "Ton premier job. Ton premier appart. Tes impôts."       │
│  - 25-34 : "Acheter ? Économiser ? On démêle tout ensemble."        │
│  - 35+ : "Retraite. Impôts. Patrimoine. Tes chiffres, tes choix."  │
│                                                                      │
│  Footer : "Gratuit. Tes données restent sur ton téléphone."         │
│                                                                      │
│  2 boutons :                                                         │
│    [Allons-y]             → S5 (Register)                            │
│    [Juste les chiffres]   → S6 (Mode libre)                          │
│                                                                      │
│  🧪 W6: test_register_no_duplicate_fields                            │
│                                                                      │
└────────┬─────────────────────┬───────────────────────────────────────┘
         │                     │
  {Allons-y}           {Juste les chiffres}
         │                     │
         ▼                     ▼
  [S5] REGISTER          [S6] MODE LIBRE
  Email/Apple/Google     Mini-consent nLPD 🆕
  Pas de champs           "Tes données restent
  âge/salaire/canton      sur ton téléphone."
  (déjà dans              [OK, compris]
   OnboardingProvider)    → Home (Explorer only)
         │                 Coach/mémoire/plan
         │                 désactivés
         │                     │
         └────────┬────────────┘
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
│  📍 screens/main_navigation_shell.dart (MODIFIÉ)                     │
│  Route : /home                                                       │
│                                                                      │
│  ARCHITECTURE : 3 tabs + drawer 🆕                                   │
│                                                                      │
│  Tab 0 : MINT Home (chiffre vivant + levier + signal + input bar)   │
│  Tab 1 : Coach (full conversation, IndexedStack preserved)           │
│  Tab 2 : Explorer (search-first + lifecycle adaptatif)               │
│  Drawer : Profil/Dossier (icône 👤 en haut à droite)               │
│                                                                      │
│  INPUT BAR sur Tab 0 : raccourci vers Tab 1 🆕                      │
│  Quand l'utilisateur tape dans l'input bar de MintHome,              │
│  ça SWITCH vers tab 1 (coach) et envoie le message.                 │
│  Pas de push vers /coach/chat → préserve l'IndexedStack.            │
│                                                                      │
│  🧪 W7: test_input_bar_switches_to_coach_tab                        │
│  🧪 W8: test_home_shows_chiffre_from_onboarding                     │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

### 3.4 Flux retour utilisateur 🆕

```
┌──────────────────────────────────────────────────────────────────────┐
│  [S1-RETURN] UTILISATEUR EXISTANT OUVRE L'APP                        │
│                                                                      │
│  CONDITION : AuthProvider.isLoggedIn == true                         │
│                                                                      │
│  TRAITEMENT (ordre) :                                                │
│  1. CoachProfileProvider.loadFromStorage()                           │
│  2. MintStateProvider.recompute(profile) incluant :                  │
│     a. SessionSnapshotService.loadPrevious() → previousSnapshot 🆕   │
│     b. SessionSnapshotService.computeDelta() → SessionDelta 🆕       │
│     c. ProactiveTriggerService.evaluate() → pendingTrigger           │
│     d. CapEngine.compute() → currentCap                              │
│     e. PrecomputedInsightsService.getCachedInsight() 🆕               │
│  3. UserActivityProvider.recordSession()                             │
│  4. ContextInjectorService.buildContext() (prépare contexte coach)   │
│                                                                      │
│  AFFICHAGE SUR MINT HOME :                                           │
│                                                                      │
│  Chiffre vivant 🆕 — le chiffre a-t-il changé ?                     │
│    SI delta.isSignificant :                                          │
│      Animation transition (ancien → nouveau CountUp)                 │
│      Delta affiché avec CAUSE :                                      │
│        SI delta.cause == 'inaction' :                                │
│          "↓ -47 CHF/mois (pas de versement 3a depuis 6 mois)"      │
│          Couleur : corailDiscret (rouge doux)                        │
│        SI delta.cause == 'macro' :                                   │
│          "↓ -23 CHF/mois (taux SARON +0.25% en mars)"              │
│          Couleur : ardoise (gris informatif)                         │
│        SI delta.cause == 'user_action' :                             │
│          "↑ +340 CHF/mois (rachat LPP enregistré)"                  │
│          Couleur : saugeClaire (vert positif)                        │
│    SI !delta.isSignificant :                                         │
│      Affichage statique (pas de re-reveal)                           │
│                                                                      │
│  Signal — nouveau signal ?                                           │
│    SI nouveau : badge "Nouveau"                                      │
│    SI même : compteur ("Jour 15 sans verser ton 3a")                │
│                                                                      │
│  Coach input bar — phrase d'accroche :                               │
│    SI absence > 7j : phrase de retour contextuelle                   │
│    SI action récente : "Regarde ce que ça change."                  │
│    SI rien : question ouverte depuis DataDrivenOpenerService 🆕      │
│                                                                      │
│  🧪 W21: test_returning_user_sees_updated_chiffre                   │
│  🧪 W22: test_returning_user_signal_counter_increments               │
│  🧪 W23: test_absence_7_days_changes_coach_opener                   │
│  🧪 W24: test_action_completed_updates_lever                        │
│  🧪 W25: test_chiffre_delta_shows_change_since_last_visit 🆕        │
│  🧪 W26: test_chiffre_delta_distinguishes_inaction_vs_macro 🆕      │
│  🧪 W27: test_chiffre_turns_green_after_user_action 🆕              │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

### 3.5 Tab 0 — MINT Home (le Chiffre Vivant / GPS) 🆕

```
┌──────────────────────────────────────────────────────────────────────┐
│  [S7a] MINT HOME                                                     │
│                                                                      │
│  📍 screens/main_tabs/mint_home_screen.dart (À CRÉER)                │
│                                                                      │
│  DONNÉES LUES :                                                      │
│  - MintStateProvider.state → MintUserState (enrichi)                 │
│  - CoachProfileProvider.profile → CoachProfile                       │
│  - UserActivityProvider.maturityLevel → int (1-5)                    │
│  - SessionSnapshotService.delta → SessionDelta 🆕                    │
│                                                                      │
│  ┌─ HEADER ─────────────────────────────────────────────────────┐    │
│  │  MINT                               [👤 drawer] [🔍 search] │    │
│  └──────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  ╔═══════════════════════════════════════════════════════════════╗    │
│  ║  🆕 CHIFFRE VIVANT / GPS                                    ║    │
│  ║                                                               ║    │
│  ║  RETRAITE DANS                                                ║    │
│  ║  16 ans, 3 mois                                               ║    │
│  ║  ━━━━━━━━━━━━━━━━━━━━━━━━━━━○                                ║    │
│  ║  1977                         2042                            ║    │
│  ║                                                               ║    │
│  ║  Revenu estimé à l'arrivée :                                  ║    │
│  ║  4'230 CHF/mois                                               ║    │
│  ║  ↓ -47 depuis le 21 mars (pas de versement 3a)               ║    │
│  ║                                                               ║    │
│  ║  Si tu ne fais rien :                                         ║    │
│  ║  4'183 dans 30j │ 3'948 dans 6 mois                          ║    │
│  ║                                                               ║    │
│  ║  Confiance : ●●●○○ 62%                                       ║    │
│  ║  "Scanne ton certificat LPP → 85%"                           ║    │
│  ║                                                               ║    │
│  ║  [tap] → switch vers Tab 1 (coach) avec contexte             ║    │
│  ║                                                               ║    │
│  ║  Source données :                                             ║    │
│  ║  - ETA : LifecyclePhaseService.yearsToRetirement              ║    │
│  ║  - Revenu : MintUserState.retirementMonthlyIncome             ║    │
│  ║  - Delta : SessionSnapshotService.delta 🆕                    ║    │
│  ║  - Projection 30j : extrapolation linéaire du delta 🆕       ║    │
│  ║  - Confiance : MintUserState.confidenceScore                  ║    │
│  ║  - Enrichment : MintUserState.enrichmentPrompts[0]            ║    │
│  ║                                                               ║    │
│  ╚═══════════════════════════════════════════════════════════════╝    │
│                                                                      │
│  ┌─ ITINÉRAIRE ALTERNATIF 🆕 ──────────────────────────────────┐    │
│  │                                                              │    │
│  │  📦 Source : CapEngine.compute() → CapDecision               │    │
│  │                                                              │    │
│  │  💡 Rachat LPP 50k → arrivée à 5'122 CHF/mois              │    │
│  │     (+892 CHF, soit +8 mois plus tôt)                        │    │
│  │     Impact fiscal : -12'400 CHF cette année                  │    │
│  │     ⚠️ Bloque EPL pendant 3 ans                              │    │
│  │                                                              │    │
│  │  onTap [Simuler] : → context.push(capDecision.ctaRoute)     │    │
│  │  onTap [En parler] : → switch tab 1 avec contexte           │    │
│  │                                                              │    │
│  │  Visible si : maturityLevel >= 2                             │    │
│  │                                                              │    │
│  └──────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  ┌─ SIGNAL PROACTIF ───────────────────────────────────────────┐    │
│  │                                                              │    │
│  │  📦 Source : MintUserState.pendingTrigger                    │    │
│  │            OU MintUserState.activeNudges[0]                  │    │
│  │                                                              │    │
│  │  🔔 "3a 2026 : 0/7'258 versé. Deadline 31 déc."            │    │
│  │     Économie si max : 1'800 CHF                              │    │
│  │                                                              │    │
│  │  Visible si : pendingTrigger != null OU activeNudges > 0    │    │
│  │  Max : 1 signal (le plus prioritaire)                        │    │
│  │                                                              │    │
│  └──────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  ┌─ 🆕 RADAR ANTICIPATOIRE ────────────────────────────────────┐    │
│  │                                                              │    │
│  │  📦 Source : NotificationSchedulerService.upcoming()         │    │
│  │            + LifecyclePhaseService.nextMilestone()            │    │
│  │                                                              │    │
│  │  🔮 CE QUI ARRIVE                                           │    │
│  │  Dans 3 mois — 50 ans, bonification LPP 15%→18%            │    │
│  │  "C'est le meilleur moment pour un rachat."                 │    │
│  │  Coût si tu attends 1 an : ~8'400 CHF 🆕                   │    │
│  │                                        [Préparer]            │    │
│  │                                                              │    │
│  │  Visible si : maturityLevel >= 3                             │    │
│  │  Max : 1 événement (le plus proche + impactant)             │    │
│  │                                                              │    │
│  └──────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  ─── MintLigne ───                                                   │
│                                                                      │
│  ┌─ COACH INPUT BAR ──────────────────────────────────────────┐     │
│  │                                                              │    │
│  │  💬 Phrase d'accroche (DataDrivenOpenerService) 🆕           │    │
│  │  "892 francs de plus par mois. On en parle ?"               │    │
│  │                                                              │    │
│  │  ┌──────────────────────────────────────────────────────┐   │    │
│  │  │  Pose ta question...                            🎤   │   │    │
│  │  └──────────────────────────────────────────────────────┘   │    │
│  │                                                              │    │
│  │  Chips contextuels :                                        │    │
│  │  [Rente ou capital ?] [Mon budget retraite] [Lauren aussi ?]│    │
│  │                                                              │    │
│  │  onSubmit : switch vers tab 1 + envoi message               │    │
│  │  onTap chip : switch vers tab 1 + envoi topic               │    │
│  │                                                              │    │
│  └──────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  🧪 W8: test_home_shows_chiffre_from_onboarding                     │
│  🧪 W9: test_home_shows_relevant_lever (maturity >= 2)              │
│  🧪 W10: test_home_coach_input_visible                              │
│  🧪 W11: test_lever_tap_routes_to_simulator                         │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

### 3.6 Tab 1 — Coach (plein écran, IndexedStack)

```
┌──────────────────────────────────────────────────────────────────────┐
│  [S8] COACH TAB (conservé de l'architecture actuelle)                │
│                                                                      │
│  📍 screens/coach/mint_coach_tab.dart → CoachChatScreen              │
│     (isEmbeddedInTab: true)                                          │
│                                                                      │
│  ENTRÉE enrichie 🆕 :                                                │
│  Quand l'utilisateur arrive depuis MintHome (input bar ou tap) :    │
│                                                                      │
│  📦 CoachEntryPayload {                                              │
│    source: 'home_chiffre' | 'home_lever' | 'home_chip' |           │
│            'home_input' | 'simulator' | 'bottom_sheet' |            │
│            'signal' | 'radar' | 'notification'                      │
│    topic: String?   // 'retirementGap', 'rachatLpp', etc.          │
│    data: Map?       // { 'value': 4200, 'confidence': 0.62, ... }  │
│    userMessage: String?  // message libre                           │
│  }                                                                   │
│  📍 lib/models/coach_entry_payload.dart (À CRÉER)                    │
│                                                                      │
│  TOOL CALLS EXÉCUTÉS CÔTÉ FLUTTER 🆕 :                              │
│                                                                      │
│  | Tool name              | Action                                  │
│  |------------------------|------------------------------------------|
│  | ROUTE_TO_SCREEN        | context.push(route) si route valide     │
│  | SHOW_FACT_CARD         | ResponseCard inline dans le chat        │
│  | SHOW_COMPARISON        | ArbitrageCard inline (side-by-side)     │
│  | SHOW_PROJECTION        | MiniChart inline                        │
│  | UPDATE_PROFILE         | CoachProfileProvider.updateField()      │
│  | REQUEST_DOCUMENT_SCAN  | ScanBottomSheet                        │
│  | SHOW_BUDGET_SNAPSHOT   | BudgetCard inline                      │
│  | SET_GOAL               | GoalTracker.addGoal()                   │
│  | SHOW_LEVER             | LeverCard inline                       │
│  | SCHEDULE_REMINDER      | NotificationScheduler.schedule()        │
│                                                                      │
│  Note : generative UI = templates contraints + financial_core 🆕     │
│  Le coach ne génère PAS de HTML/UI libre. Il sélectionne des        │
│  widgets prédéfinis et les remplit avec des données calculées        │
│  par les services existants. Compliance garanti.                     │
│                                                                      │
│  🧪 W12: test_tool_call_route_to_screen_pushes                      │
│  🧪 W13: test_tool_call_show_fact_card_renders_inline                │
│  🧪 W14: test_tool_call_update_profile_modifies_provider            │
│  🧪 W15: test_invalid_route_rejected                                │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

### 3.7 Tab 2 — Explorer + Drawer

*(Identiques au V1 §2.5 et §2.6. Explorer avec search-first + lifecycle ordering (déjà fait W17) + événements de vie. Drawer remplace DossierTab.)*

### 3.8 Coach Interrupt Banner (dans les simulateurs) 🆕

```
┌──────────────────────────────────────────────────────────────────────┐
│  [S11] COACH INTERRUPT BANNER                                        │
│                                                                      │
│  📍 widgets/coach_interrupt_banner.dart (À CRÉER)                    │
│  Affiché EN BAS des écrans simulateurs quand un seuil est franchi   │
│                                                                      │
│  📦 CoachInterrupt {                                                 │
│    condition: (values) => bool,  // évalue les valeurs du simulateur │
│    messageKey: String,           // clé ARB                          │
│    params: Map<String, String>,  // paramètres i18n                  │
│    ctaRoute: String?,            // route pour "Voir le calcul"      │
│    cooldown: Duration,           // pas plus d'1 par session         │
│    dismissCount: int,            // 🆕 compteur de dismiss           │
│  }                                                                   │
│                                                                      │
│  RÈGLE dismiss counter 🆕 :                                          │
│  - Après 3 [Plus tard] sur CE seuil → silence permanent             │
│  - Reset si le contexte change radicalement (nouveau profil, etc.)  │
│  - Le coach ne doit JAMAIS insister. Un conseiller qui insiste      │
│    4 fois perd sa crédibilité.                                       │
│                                                                      │
│  TIMING : apparaît quand l'utilisateur CHANGE une valeur            │
│  (pas au chargement de l'écran)                                     │
│                                                                      │
│  RESPECT maturityLevel :                                             │
│  - maturity 1 (1ère visite) : AUCUN interrupt                       │
│  - maturity 2-3 : interrupts basiques (3a, budget)                  │
│  - maturity 4-5 : tous les interrupts                               │
│                                                                      │
│  V1 — 5 SIMULATEURS :                                                │
│                                                                      │
│  | Simulateur      | Seuil                          | Message       │
│  |-----------------|--------------------------------|----------------|
│  | 3a              | annual < 7258 && annual > 0    | "Tu laisses    │
│  |                 |                                |  {delta}       │
│  |                 |                                |  d'impôts"     │
│  | Hypothèque      | charges > 33% revenu           | "Les banques   │
│  |                 |                                |  refuseront"   │
│  | Rente vs Capital| 100% capital && age > 60       | "0 rente       │
│  |                 |                                |  garantie"     │
│  | Rachat LPP      | rachat > 0 && years_to_ret < 3 | "Blocage EPL  │
│  |                 |                                |  3 ans"        │
│  | Budget          | expenses > income              | "Déficit de    │
│  |                 |                                |  {delta}/mois" │
│                                                                      │
│  PATTERN pour ajout futur :                                          │
│  abstract class CoachAwareSimulator {                                │
│    CoachEntryPayload buildCoachPayload();                            │
│    List<CoachInterrupt> evaluateInterrupts(Map<String, dynamic> v); │
│  }                                                                   │
│                                                                      │
│  🧪 W28: test_interrupt_appears_when_3a_under_max                    │
│  🧪 W29: test_interrupt_hidden_after_3_dismissals                    │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

### 3.9 Scan Magique — moment post-review 🆕

```
┌──────────────────────────────────────────────────────────────────────┐
│  [S12] SCAN POST-REVIEW INSIGHT                                      │
│                                                                      │
│  📍 screens/documents/scan_impact_screen.dart (ENRICHIR)             │
│  Quand : APRÈS que l'utilisateur a validé les données extraites     │
│                                                                      │
│  Le scan utilise Claude Vision (document_vision_service.py)          │
│  8 types de documents : LPP, AVS, tax, salary, payslip, lease,     │
│  insurance, LPP plan. Avec confidence scoring par champ.             │
│                                                                      │
│  FLOW :                                                              │
│  1. 📷 Scan → extraction Claude Vision (existant)                    │
│  2. 📝 Review → utilisateur vérifie/corrige (existant)              │
│  3. 🆕 IMPACT → moment Shazam post-review :                         │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐    │
│  │                                                              │    │
│  │  ✅ Certificat LPP importé                                   │    │
│  │                                                              │    │
│  │  Confiance : 62% → 87% (+25 points)                         │    │
│  │  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ (animation)              │    │
│  │                                                              │    │
│  │  Ce que ça change :                                          │    │
│  │  • Ta projection passe de estimation à certitude             │    │
│  │  • Ton rachat max : 539'414 CHF                              │    │
│  │  • Ton taux de conversion (5.8%) est surobligatoire          │    │
│  │    → c'est une bonne chose                                   │    │
│  │                                                              │    │
│  │  💬 "On regarde ce que ça change pour ta retraite ?"        │    │
│  │                                                              │    │
│  │  [Oui, allons-y] → switch tab 1 (coach) avec contexte scan │    │
│  │  [Plus tard]                                                 │    │
│  │                                                              │    │
│  └──────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  🧪 W32: test_scan_review_shows_confidence_delta                     │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 4. WIRE SPEC — Chaque câble

### 4.1-4.6 Câbles principaux

*(Identiques au V1 §3.1-3.6 avec les ajustements suivants :)*

- **§3.1** : Landing → Chiffre Choc : utilise `OnboardingProvider` au lieu de SharedPrefs
- **§3.2** : Chiffre Choc → Promesse : `OnboardingProvider.setEmotion()` au lieu de `prefs.setString()`
- **§3.4** : MintHome → Coach : `switch tab 1` au lieu de `context.push('/coach/chat')`
- **§3.6** : Tool calls : ajout note "templates contraints + financial_core"

### 4.7 Câble : SessionSnapshot → Chiffre Vivant 🆕

```
SOURCE     : services/session_snapshot_service.dart (EXISTANT)
WRITES     : 3 métriques à chaque AppLifecycleState.paused
             (confidence, retirementIncome, fhsScore)
READS      : Au lancement, computeDelta() → SessionDelta
CONSUMER   : MintHomeScreen → ChiffreVivantCard

📦 SessionDelta (enrichi) {
  double previousRetirementIncome;   // valeur à la dernière visite
  double currentRetirementIncome;    // valeur actuelle
  double delta;                      // current - previous
  DateTime previousVisitDate;        // quand
  Duration timeSinceLastVisit;       // combien de temps
  String cause; 🆕                   // 'inaction' | 'macro' | 'user_action'
  bool isSignificant;                // |delta| > 50 CHF
  double projected30d; 🆕            // extrapolation linéaire
  double projected6m; 🆕             // extrapolation linéaire
}

DÉTERMINATION DE LA CAUSE 🆕 :
  SI l'utilisateur a complété une action CapEngine depuis la dernière visite :
    cause = 'user_action'
  SINON SI des paramètres macro ont changé (SARON, inflation, loi) :
    cause = 'macro'
  SINON :
    cause = 'inaction'

🧪 W25: test_chiffre_delta_shows_change_since_last_visit
🧪 W26: test_chiffre_delta_distinguishes_inaction_vs_macro
🧪 W27: test_chiffre_turns_green_after_user_action
```

---

## 5. KILL LIST

*(Identique au V1 §4 — 30 routes supprimées, 42+1 gardées)*

Ajout : `/onboarding/promise` (route nouvelle) → **total 43 routes**

---

## 6. MIGRATION TABLE

### 6.1 MainNavigationShell : 4 tabs → 3 tabs + drawer

```
AVANT :
  Tab 0: PulseScreen       Tab 1: MintCoachTab
  Tab 2: ExploreTab        Tab 3: DossierTab

APRÈS :
  Tab 0: MintHomeScreen    Tab 1: CoachChatScreen(isEmbeddedInTab: true)
  Tab 2: ExploreTab        Drawer: ProfileDrawer

DEEP LINKS :
  /home?tab=0 → MintHome
  /home?tab=1 → Coach
  /home?tab=2 → Explorer
  /home?tab=3 → REDIRECT → /home?tab=0 + ouvre drawer
```

---

## 7. PROVIDER REFACTOR

*(Identique au V1 §6 avec la correction OnboardingProvider)*

```
SUPPRIMER (2) :
  - ProfileProvider      → absorbé par CoachProfileProvider
  - SlmProvider          → intégré dans ByokProvider

CRÉER (1) :
  - OnboardingProvider 🆕
    📦 OnboardingPayload {
      int? birthYear;
      double? grossSalary;
      String? canton;
      String? anxietyLevel;     // 🆕 'far'|'mid'|'close' (Hinge prompt 1)
      ChiffreChocType? chocType;
      double? chocValue;
      String? emotion;
    }

    SEUL WRITER/READER 🆕 :
    - Les screens appellent onboardingProvider.setBirthYear(1977)
    - JAMAIS prefs.setInt('onboarding_birth_year', 1977)
    - Le provider persiste en SharedPrefs EN INTERNE (survie app kill)
    - SharedPrefs = détail d'implémentation, invisible de l'extérieur

ENRICHIR (1) :
  - MintUserState 🆕 :
    + SessionDelta? sessionDelta        // delta depuis dernière visite
    + String? deltaFeedbackMessage      // message formaté avec cause
    + List<UpcomingEvent> radarEvents   // radar anticipatoire
    + double? projected30d              // projection 30 jours
    + double? projected6m               // projection 6 mois

RÉSULTAT : 12 → 11 providers
```

---

## 8. ACCEPTANCE TESTS — 34 wire tests

### Groupe 1 : Onboarding (W1-W6, W30-W31)

```
W1:  test_landing_passes_3_fields_via_onboarding_provider
W2:  test_chiffre_choc_stores_6_fields_in_onboarding_provider
W3:  test_19yo_sees_compound_growth_not_retirement
W4:  test_emotion_survives_registration
W5:  test_coach_receives_full_onboarding_context
W6:  test_register_no_duplicate_fields
W30: test_hinge_prompt_1_adapts_label_to_birth_year 🆕
W31: test_hinge_prompt_2_microinsight_adapts_to_salary 🆕
```

### Groupe 2 : MINT Home (W7-W11, W25-W27)

```
W7:  test_input_bar_switches_to_coach_tab (était: opens coach)
W8:  test_home_shows_chiffre_from_onboarding
W9:  test_home_shows_relevant_lever (maturity >= 2)
W10: test_home_coach_input_visible
W11: test_lever_tap_routes_to_simulator
W25: test_chiffre_delta_shows_change_since_last_visit 🆕
W26: test_chiffre_delta_distinguishes_inaction_vs_macro 🆕
W27: test_chiffre_turns_green_after_user_action 🆕
```

### Groupe 3 : Flux retour (W21-W24)

```
W21: test_returning_user_sees_updated_chiffre
W22: test_returning_user_signal_counter_increments
W23: test_absence_7_days_changes_coach_opener
W24: test_action_completed_updates_lever
```

### Groupe 4 : Coach & Tools (W12-W15)

```
W12: test_tool_call_route_to_screen_pushes
W13: test_tool_call_show_fact_card_renders_inline
W14: test_tool_call_update_profile_modifies_provider
W15: test_invalid_route_rejected
```

### Groupe 5 : Explorer (W16-W18)

```
W16: test_explorer_reorders_hubs_by_lifecycle
W17: test_retraite_hub_hides_rachat_if_phase_lt_acceleration
W18: test_explorer_search_finds_hypotheque
```

### Groupe 6 : Maturity (W19-W20)

```
W19: test_first_visit_shows_only_chiffre_no_lever
W20: test_visit_5_plus_shows_lever_card
```

### Groupe 7 : Coach Interrupt (W28-W29) 🆕

```
W28: test_interrupt_appears_when_3a_under_max
W29: test_interrupt_hidden_after_3_dismissals
```

### Groupe 8 : Scan & Radar (W32-W34) 🆕

```
W32: test_scan_review_shows_confidence_delta
W33: test_monthly_checkin_skips_if_nothing_changed
W34: test_radar_shows_upcoming_event_with_cost_of_delay
```

---

## 9. PLAN D'EXÉCUTION

### Phase 0 — Fondations (1 sprint)

```
P0.1  CoachEntryPayload model
      📍 lib/models/coach_entry_payload.dart
      🧪 test unitaire

P0.2  OnboardingProvider (SEUL writer/reader)
      📍 lib/providers/onboarding_provider.dart
      SharedPrefs = détail interne, invisible
      🧪 test: store + retrieve + clear

P0.3  MintUserState enrichi
      Ajouter : sessionDelta, projected30d, radarEvents
      SessionSnapshotService.delta → surfacé dans l'état
      Chiffre = pertinence (trigger > enrichment > CapEngine)
      Delta = cause identifiée (inaction | macro | user_action)
      🧪 W25, W26, W27

P0.4  CoachChatScreen accepte CoachEntryPayload
      Route extra: CoachEntryPayload
      Backward compat si extra null
      🧪 W12

P0.5  S1-RETURN : flux retour utilisateur
      SessionSnapshotService.loadPrevious() au lancement
      DataDrivenOpenerService.generate() câblé au greeting
      PrecomputedInsightsService.getCachedInsight() câblé
      🧪 W21-W24
```

### Phase 1 — MINT Home + 3 tabs (1 sprint)

```
P1.1  MintHomeScreen avec Chiffre Vivant / GPS
      📍 lib/screens/main_tabs/mint_home_screen.dart
      Sections : ChiffreVivantCard + ItineraireAlternatifCard +
                 SignalCard + RadarCard + CoachInputBar
      🧪 W7-W11, W25-W27

P1.2  ProfileDrawer
      📍 lib/widgets/profile_drawer.dart
      Remplace DossierTab

P1.3  MainNavigationShell : 3 tabs + drawer
      Tab 0: MintHome, Tab 1: Coach (GARDÉ), Tab 2: Explorer
      Input bar → switch vers tab 1 (pas push)
      Migration deep links /home?tab=
```

### Phase 2 — Onboarding réparé (1 sprint, SÉQUENTIEL)

```
P2.1  Landing refactorée en Onboarding Hinge
      3 prompts plein-écran (pas un formulaire)
      Micro-insights adaptatifs
      Utilise OnboardingProvider exclusivement
      🧪 W30, W31

P2.2  PromiseScreen
      📍 lib/screens/onboarding/promise_screen.dart
      Route : /onboarding/promise
      Texte adapté par LifecyclePhase
      DÉPEND DE P2.1

P2.3  Fix flux chiffre choc → promesse → register
      Post-émotion → context.push('/onboarding/promise')
      Register ne redemande PAS âge/salaire/canton
      DÉPEND DE P2.2

P2.4  Mode libre + mini-consent nLPD
      Auth guard modifié pour /home?mode=libre
      Mini-consent bottom sheet (1 fois)
      DÉPEND DE P2.3
      🧪 W1-W6
```

### Phase 3 — Coach omniprésent + features (1 sprint)

```
P3.1  Tool call execution Flutter
      Parser [TOOL_NAME:{json}] dans les réponses coach
      10 tool handlers (ROUTE_TO_SCREEN, SHOW_FACT_CARD, etc.)
      Templates contraints + financial_core (pas de generative UI libre)
      🧪 W12-W15

P3.2  Coach interrupt banner (5 simulateurs)
      📍 lib/widgets/coach_interrupt_banner.dart
      Pattern CoachAwareSimulator + evaluateInterrupts()
      Dismiss counter max 3, cooldown, respect maturityLevel
      🧪 W28, W29

P3.3  Explorer search bar
      SearchDelegate + index local
      🧪 W18

P3.4  Radar anticipatoire
      Section dans MintHome (maturity >= 3)
      Croise NotificationSchedulerService + LifecyclePhaseService
      Coût du retard affiché pour chaque événement
      🧪 W34

P3.5  Scan post-review insight
      Enrichir scan_impact_screen.dart
      Afficher delta confiance + insight immédiat
      🧪 W32
```

### Phase 4 — Kill + Clean (0.5 sprint)

```
P4.1  Supprimer 30 routes (KILL LIST §5)
P4.2  Supprimer ProfileProvider + SlmProvider
P4.3  Supprimer PulseScreen, MintCoachTab (ancien), DossierTab
P4.4  Audit final : flutter analyze + flutter test
P4.5  Vérifier les 34 wire tests tous verts
```

### Post-launch

```
DÉCEMBRE 2026 — Financial Wrapped
  "Ton Année Financière 2026"
  Compilé depuis UserActivityProvider + SessionSnapshotService + CapMemory
  Montants en CHF dans l'app (non-exportable)
  Export anonymisé disponible (pourcentages uniquement)

MENSUEL — Scan Corporel Financier
  Check-in mensuel (pas hebdomadaire)
  Uniquement si quelque chose a changé (silence = feature)
  Format : pilier par pilier, calme, séquentiel
  🧪 W33
```

---

## 10. VISION 2027-2030

### Les 3 paris stratégiques

**Pari 1 — Privacy nucléaire (2027-2028)**

Quand les LLM on-device seront assez puissants (Gemma 3, Phi-4, Apple Intelligence) :
- `financial_core` en Dart = **déjà on-device**
- Couche conversationnelle = migre vers LLM local
- Proposition : "Tes données ne quittent JAMAIS ton iPhone"
- C'est la proposition de valeur ultime pour un utilisateur suisse

**Pari 2 — L'app qui disparaît (2028-2029)**

Apple Intelligence / Siri pourra appeler MINT en background :
- "Siri, combien je peux racheter en 2e pilier ?"
- Siri interroge le moteur MINT sans ouvrir l'app
- MINT devient un **moteur financier suisse**, pas une app à écrans
- Architecture `financial_core` comme bibliothèque pure = prête pour ça
- Investir dans **App Intents** (Apple) dès 2027

**Pari 3 — Generative UI contrainte (2027-2028)**

Le coach génère l'interface dont l'utilisateur a besoin :
- "Compare rente et capital" → génère un ArbitrageCard inline avec MES chiffres
- Pas de génération HTML/UI libre (compliance impossible à garantir)
- Templates prédéfinis + données calculées par `financial_core`
- Le Lightning Menu actuel est l'embryon
- En V1 : tool calls `SHOW_FACT_CARD`, `SHOW_COMPARISON`
- En V2+ : bibliothèque de 20+ widgets inline, sélectionnés par le coach

### Préparation architecturale (dès maintenant)

| Action | Pourquoi | Quand |
|--------|----------|-------|
| Garder `financial_core` comme bibliothèque pure (zéro side effect) | Prêt pour on-device AI + Siri integration | Déjà fait |
| Exposer les calculateurs via des interfaces stables | Apple App Intents, Siri, widgets iOS | 2027 |
| Abstraire la couche LLM (cloud/on-device interchangeable) | Migration progressive vers on-device | 2027 |
| Documenter les tool calls comme une API publique interne | Generative UI consomme la même API | Maintenant |

---

## RÉSUMÉ EXÉCUTIF

Le Wire Spec V2 transforme MINT de **"une app avec un chat"** en **"un GPS financier suisse avec un coach qui parle"**.

**L'image mentale** : Google Maps pour ta vie financière.
- L'ETA = ta retraite (16 ans, 3 mois)
- La position = ton chiffre actuel (4'230 CHF/mois)
- Le delta = le recalcul d'itinéraire (-47 depuis ta dernière visite)
- L'itinéraire alternatif = le levier (#892 CHF avec rachat LPP)
- Le radar = ce qui arrive sur ta route (50 ans, 3a deadline, achat)
- Le coach = le copilote qui commente la route

**34 wire tests** prouvent que chaque câble est connecté.
**43 routes** (vs 70) après le kill.
**3 tabs + drawer** (vs 4 tabs).
**5 phases** d'exécution avec dépendances claires.
**3 paris stratégiques** pour 2027-2030.

Ce n'est plus un flowchart. C'est une partition.
