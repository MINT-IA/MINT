# Wave 17 — AUDIT + STORYBOARD : Le flux réel vs le flux cible

> **⚠️ LEGACY NOTE (2026-04-05):** Sprint history. Uses "chiffre choc" (legacy → "premier éclairage", see `docs/MINT_IDENTITY.md`).
>
> Ce document est un AUDIT du code actuel + un STORYBOARD du flux cible.
> Chaque écran référence les fichiers, les lignes, les câbles coupés.
> Pas de fiction. Que du code.

---

## PARTIE 1 : LES 7 CÂBLES COUPÉS

### Câble 1 — Landing → QuickStart : données jetées
- **Fichier** : `apps/mobile/lib/screens/landing_screen.dart` ligne ~94
- **Code** : `context.go('/onboarding/quick')` — aucun `extra`, aucun query param
- **Impact** : L'utilisateur saisit (année, salaire, canton) sur le landing, puis on lui redemande sur QuickStart
- **Fix** : Passer `extra: {'birthYear': _birthYear, 'grossSalary': _grossSalary, 'canton': _canton}`

### Câble 2 — Instant chiffre choc : émotion perdue au register
- **Fichier** : `apps/mobile/lib/screens/onboarding/instant_chiffre_choc_screen.dart` lignes 119-128
- **Code** : `context.go('/auth/register?prompt=$userFeeling')` — register ignore ce param
- **Impact** : Le moment le plus intime (réaction au chiffre choc) meurt dans un formulaire d'inscription
- **Fix** : Stocker `userFeeling` dans un provider ou SharedPreferences, le récupérer post-register et le passer au coach

### Câble 3 — ChiffreChocSelector non utilisé par le flux instant
- **Fichier** : `apps/mobile/lib/screens/onboarding/instant_chiffre_choc_screen.dart`
- **Code** : Calcul direct AVS+LPP, pas d'appel à `ChiffreChocSelector.select()`
- **Impact** : Un utilisateur de 18 ans voit "CHF 2'642/mois à la retraite" — hors sujet total
- **Fix** : Appeler `ChiffreChocSelector.select()` avec un MinimalProfile construit depuis les 3 champs

### Câble 4 — Question post-chiffre-choc générique
- **Fichier** : `instant_chiffre_choc_screen.dart` + `chiffre_choc_screen.dart`
- **Code** : Clé ARB `chiffreChocSilenceQuestion` = "Qu'est-ce que tu ressens ?"
- **Impact** : "C'est ton chiffre. Qu'est-ce que tu en penses ?" — bateau, vide, aucune empathie
- **Fix** : Table de questions par profil (voir Partie 3)

### Câble 5 — Proactive services : 2'383 lignes de code mort
- **Fichiers** : `proactive_trigger_service.dart`, `jitai_nudge_service.dart`, `data_driven_opener_service.dart`, `precomputed_insights_service.dart`, `notification_scheduler_service.dart`
- **Impact** : Cleo "steps in before you fall behind" — MINT ne step in nulle part
- **Fix** : 4 points d'intégration (voir Partie 4)

### Câble 6 — Coach Flutter = single-shot (pas d'agent loop)
- **Fichier** : `apps/mobile/lib/services/coach/coach_orchestrator.dart` lignes 635-650
- **Code** : `tool_calls` converties en marqueurs texte `[ROUTE_TO_SCREEN:{...}]`, pas exécutées
- **Impact** : Le coach ne peut pas AGIR (router, afficher un widget, demander une info), il ne peut que PARLER
- **Fix** : Parser les marqueurs dans `coach_chat_screen.dart` et exécuter les tools côté Flutter

### Câble 7 — Pas d'écran "Promesse" entre chiffre choc et register
- **Fichier** : N'existe pas
- **Impact** : Après le chiffre choc, rien ne dit "MINT reste avec toi, on va y arriver ensemble"
- **Fix** : Créer un écran intermédiaire (voir Partie 2)

---

## PARTIE 2 : STORYBOARD PAR PERSONA — CODE vs CIBLE

### PERSONA A : EMMA, 19 ANS

#### Écran 1 — Landing (EXISTE)
- **Fichier** : `landing_screen.dart`
- **Voit** : 3 champs (année=2007, salaire=12'000, canton=VD)
- **Tape** : "Calculer"
- **Code actuel** : `_onCalculate()` → push `/chiffre-choc-instant` avec extra ✓

#### Écran 2 — Chiffre Choc Instant (EXISTE mais MAL CÂBLÉ)
- **Fichier** : `instant_chiffre_choc_screen.dart`
- **Voit aujourd'hui** : "CHF 2'642/mois à la retraite" ← FAUX pour 19 ans
- **Devrait voir** : Intérêts composés — "CHF 1'200 placés maintenant → CHF 9'847 à 65 ans"
- **Cause** : `ChiffreChocSelector` non appelé (Câble 3)
- **Fix** :
  ```dart
  // Dans instant_chiffre_choc_screen.dart, remplacer le calcul direct par :
  final profile = MinimalProfile(age: age, grossSalary: salary, canton: canton);
  final choc = ChiffreChocSelector.select(profile);
  // age < 28 → choc.type == compoundGrowth
  ```

#### Écran 2bis — Question ciblée (EXISTE mais GÉNÉRIQUE)
- **Voit aujourd'hui** : "Qu'est-ce que tu ressens ?" (Câble 4)
- **Devrait voir** : "Tu savais que le temps comptait autant ?"
- **Chips** : "Non, c'est dingue" / "Oui mais j'ai pas d'argent" / "Dis-moi quoi faire"
- **Fix** : Table de mapping `ChiffreChocType → questionKey` (voir Partie 3)

#### Écran 3 — La Promesse (N'EXISTE PAS — Câble 7)
- **Fichier à créer** : `promise_screen.dart`
- **Voit** :
  ```
  MINT reste avec toi.

  Ton premier job. Ton premier appart. Tes impôts.
  Chaque étape, je t'explique quoi faire.
  Sans jargon. Sans jugement. Sans te vendre quoi que ce soit.

  [Allons-y]

  Gratuit. Tes données restent sur ton téléphone.
  ```
- **Tape** : "Allons-y" → `/auth/register` (puis `/coach/chat` post-register)

#### Écran 4 — Coach (EXISTE mais NE SAIT RIEN)
- **Fichier** : `coach_chat_screen.dart`
- **Aujourd'hui** : Le coach ouvre avec un "silent opener" générique. Ne sait pas que l'utilisateur a vu un chiffre choc, a répondu, a 19 ans.
- **Devrait** : Recevoir `OnboardingPayload` (chiffreChocType, value, emotion, age, canton) et ouvrir avec :
  ```
  Bienvenue Emma.
  Tu viens de découvrir la magie des intérêts composés.
  À 19 ans, tu as un avantage que personne ne peut acheter : le temps.

  1. Ouvre un compte 3a (10 min sur ton téléphone, même CHF 10/mois)
  2. Vérifie si ton employeur cotise au 2e pilier (seuil: 22'680 CHF/an)
  3. Retiens ce chiffre : 7'258. C'est le max 3a/an.
  ```
- **Fix** : Créer `OnboardingPayload` dans un provider, le passer au coach via `ContextInjectorService`

---

### PERSONA B : MARCO, 35 ANS, EXPAT ITALIEN

#### Écran 2 — Chiffre Choc (avec ChiffreChocSelector câblé)
- **ChiffreChocSelector** retourne : `retirementGap` (38+ && replacement < 55%)
- **Voit** : "Il te manque CHF 2'310/mois à la retraite"
- **Sous-texte détecté par archetype** : "Tu as cotisé 7 ans en Suisse. Tes années en Italie comptent — mais pas automatiquement." ← nécessite `expat_eu` archetype detection
- **Câble manquant** : L'instant flow ne détecte PAS l'archetype (pas de question nationalité/arrivée)

#### Écran 4 — Coach
- **StructuredReasoningService** (backend) détecterait : `gap_warning` (replacement < 60%)
- **Agent loop** : Claude appellerait `get_retirement_projection` (tool interne) → résultat réinjecté → réponse enrichie
- **Fonctionne SI** : l'utilisateur passe par le BYOK (Claude API), PAS par le SLM (single-shot)

---

### PERSONA C : JULIEN, 49 ANS (Golden Couple)

#### Écran 2 — Chiffre Choc
- **ChiffreChocSelector** retourne : `retirementIncome` (age 49, replacement ~65.5%)
- **Voit** : "CHF 8'505/mois — 65.5% de votre revenu actuel"
- **Problème** : L'instant flow ne sait pas qu'il est marié → affiche individuel, pas couple
- **Câble manquant** : Pas de question "situation familiale" dans les 3 champs du landing

#### Écran 4 — Coach
- **StructuredReasoningService** détecterait : `rachat_opportunity` (rachat max CPE 539'414)
- **Agent loop** fonctionnel : Claude → `get_cross_pillar_analysis` → résultat → réponse avec 4 leviers
- **Fonctionne** ✓ (si BYOK configuré)

---

### PERSONA D : FRANÇOISE, 58 ANS, DIVORCÉE

#### Écran 2 — Chiffre Choc
- **ChiffreChocSelector** retourne : `retirementIncome` (age 58)
- **Voit** : "CHF 5'180/mois — 85% de ton revenu"
- **Problème** : Pas de mention du splitting AVS (pas de question divorce dans l'instant flow)
- **Câble manquant** : L'instant flow ne capture ni le statut civil ni les événements de vie

---

## PARTIE 3 : TABLES DE REMPLACEMENT

### Question post-chiffre-choc (remplace "Qu'est-ce que tu ressens ?")

| ChiffreChocType | Question | Clé ARB |
|----------------|----------|---------|
| `compoundGrowth` | "Tu savais que le temps comptait autant ?" | `chocQuestionCompoundGrowth` |
| `taxSaving3a` | "CHF {amount} d'impôts en moins. Ça vaut 10 minutes ?" | `chocQuestionTaxSaving` |
| `retirementGap` | "CHF {amount} de moins par mois. Tu y avais pensé ?" | `chocQuestionRetirementGap` |
| `retirementIncome` | "{percent}\u00a0%, ça te suffit ?" | `chocQuestionRetirementIncome` |
| `liquidityAlert` | "Moins de {months} mois de réserve. On en parle ?" | `chocQuestionLiquidity` |
| `hourlyRate` | "CHF {rate}/heure. C'est ce que tu vaux ?" | `chocQuestionHourlyRate` |

### Chips contextuels par type

| ChiffreChocType | Chip 1 | Chip 2 | Chip 3 |
|----------------|--------|--------|--------|
| `compoundGrowth` | "Non, c'est dingue" | "Oui mais j'ai pas d'argent" | "Dis-moi quoi faire" |
| `taxSaving3a` | "Je savais pas" | "J'ai déjà un 3a" | "Comment ça marche ?" |
| `retirementGap` | "C'est flippant" | "Je sais pas quoi faire" | "Quels sont mes leviers ?" |
| `retirementIncome` | "C'est pas assez" | "Ça me semble OK" | "On peut améliorer ?" |
| `liquidityAlert` | "C'est urgent ?" | "J'ai des dettes" | "Par où commencer ?" |

---

## PARTIE 4 : CÂBLAGE PROACTIF — 4 POINTS D'INTÉGRATION

### Point 1 : Coach greeting lit les insights pré-calculés
```
Fichier : coach_chat_screen.dart (greeting / silent opener)
Quoi : Appeler PrecomputedInsightsService.getCachedInsight()
Si résultat : afficher comme premier message coach (pas de LLM call)
Fallback : DataDrivenOpenerService.generate() synchrone
```

### Point 2 : Pending trigger affiché au coach
```
Fichier : coach_chat_screen.dart (init)
Quoi : Lire MintStateProvider.state.pendingTrigger
Si non null : afficher comme nudge card avant le premier message
Exemple : "Tu n'es pas venu depuis 8 jours. Ton 3a dort."
```

### Point 3 : Notifications calendrier à l'init
```
Fichier : main.dart ou app.dart (post-auth)
Quoi : NotificationSchedulerService.generateCalendarNotifications()
Pour chaque : NotificationService.schedule()
Consent : coaching_notifications vérifié
```

### Point 4 : Tool calls Flutter exécutées
```
Fichier : coach_chat_screen.dart (_addResponse ou équivalent)
Quoi : Parser [ROUTE_TO_SCREEN:{json}] dans le texte coach
Exécuter : context.push(routeFromJson)
Afficher : show_fact_card, show_budget_snapshot comme widgets inline
```

---

## PARTIE 5 : LE FLUX CIBLE (POST-W17)

```
                    LANDING
              (année, salaire, canton)
                      │
                ┌─────┴─────┐
           "Calculer"    "Commencer"
                │              │
                ▼              │
        CHIFFRE CHOC ADAPTÉ   │  ← ChiffreChocSelector.select()
        (type par âge/archi)  │     age<28 = compound growth
                │              │     28-38 = 3a tax saving
           3.9s silence       │     38+ = gap/income
                │              │
         Question ciblée      │  ← Table par ChiffreChocType
         + chips contextuels  │
                │              │
                ▼              │
           LA PROMESSE    ◄───┘  ← Nouvel écran
        "MINT reste avec toi"
        (texte adapté profil)
                │
            "Allons-y"
                │
                ▼
         CRÉATION COMPTE
        (email/Apple/Google)
                │
                ▼
             COACH
     (reçoit OnboardingPayload)
     (insight pré-calculé OU silent opener enrichi)
     (3 actions concrètes avec chiffres)
     (PAS de QuickStart — données déjà connues)
```

### Différences clés vs aujourd'hui

| Aujourd'hui | Après W17 |
|------------|-----------|
| "Commencer" → QuickStart (redemande tout) | "Commencer" → Promesse → Register → Coach (données transmises) |
| 18 ans voit retraite | 18 ans voit intérêts composés |
| "Qu'est-ce que tu ressens ?" | Question ciblée par type de choc |
| Émotion → /auth/register (perdue) | Émotion → provider → coach (transmise) |
| Coach = chatbot single-shot (SLM) | Coach = agent loop tools exécutés (BYOK) + SLM fallback |
| 2'383 lignes de proactif dormant | 4 points câblés : greeting, trigger, notifications, tool execution |
| Pas de promesse d'accompagnement | Écran "MINT reste avec toi" personnalisé |

---

## PARTIE 6 : PRIORITÉ D'IMPLÉMENTATION

| # | Tâche | Fichiers | Complexité | Impact |
|---|-------|---------|-----------|--------|
| 1 | Câbler ChiffreChocSelector dans instant flow | `instant_chiffre_choc_screen.dart` | Faible | 18 ans ne voit plus "retraite" |
| 2 | Questions ciblées (table par type) | 6 clés ARB + `instant_chiffre_choc_screen.dart` + `chiffre_choc_screen.dart` | Faible | Plus de "qu'est-ce que tu en penses" |
| 3 | Passer landing data à QuickStart/Promesse | `landing_screen.dart` ligne 94 | Trivial | Zéro double saisie |
| 4 | Créer OnboardingPayload provider | Nouveau : `onboarding_payload_provider.dart` | Moyen | Fil rouge de données |
| 5 | Créer écran Promesse | Nouveau : `promise_screen.dart` + route | Moyen | "MINT reste avec toi" |
| 6 | Émotion → coach (pas register) | `instant_chiffre_choc_screen.dart` + provider | Moyen | L'émotion arrive au coach |
| 7 | Coach greeting lit precomputed insights | `coach_chat_screen.dart` | Faible | Coach proactif dès l'ouverture |
| 8 | Parser tool_calls Flutter | `coach_chat_screen.dart` | Moyen | Coach peut AGIR (router, afficher) |
