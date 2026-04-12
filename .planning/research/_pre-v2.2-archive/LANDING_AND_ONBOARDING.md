# LANDING & ONBOARDING — Audit + Redesign Brief (v2.2 La Beauté de Mint)

**Researched:** 2026-04-07
**Scope:** Two surfaces NOT covered in `MINT_DESIGN_BRIEF_v0.2.3.md` Layer 1 (S1–S5):
1. `apps/mobile/lib/screens/landing_screen.dart` — the public door
2. `apps/mobile/lib/screens/onboarding/*` — the 7 screens between landing and `/home`

**Verdict in one sentence:** The landing IS a retirement quick-calc dressed in calm coral, in direct violation of `CLAUDE.md §1` and `docs/MINT_IDENTITY.md`; the onboarding is a 7-screen pipeline whose first half (landing → instant-chiffre-choc → promise) and second half (intent → quick-start → chiffre-choc → plan) are **two parallel onboardings glued at `promise_screen`**, with the legacy term `chiffre_choc` baked into 174 files. Both surfaces must be **rebuilt**, not iterated, and the brief v0.2.3 needs to add **L1.7 Landing v2** + **L1.8 Onboarding v2** + a **chiffre_choc rename sweep** as Phase 0 prerequisite.

---

## Part A — Landing audit

### A.1 — Factual extraction

**File:** `apps/mobile/lib/screens/landing_screen.dart` (862 lines, single file).

**Imports that betray retirement-default doctrine violation:**
```dart
import '.../financial_core/avs_calculator.dart';   // L11
import '.../financial_core/lpp_calculator.dart';   // L12
import '.../financial_core/tax_calculator.dart';   // L17
import '.../constants/social_insurance.dart';     // L13
```
A landing page has **no business importing AVS / LPP / RetirementTaxCalculator**. The file itself is the smoking gun.

**Inputs collected (confirmed L35–47):**
- `_birthYear` (int) — Cupertino picker 1940–2010
- `_grossSalary` (double) — TextField CHF
- `_canton` (String, 26 codes)

**Calculators called in `_onCalculate()` (L486–533):**
1. `AvsCalculator.computeMonthlyRente(currentAge, retirementAge: 65, grossAnnualSalary)` — pure retirement projection
2. `LppCalculator.computeSalaireCoordonne` + manual loop using `getLppBonificationRate(a)` and `lppTauxConversionMinDecimal` — second-pillar projection to 65
3. Computes `replacementPercent = (totalMonthly / netMonthly) * 100`
4. Pushes to **`/chiffre-choc-instant`** with `{monthlyTotal, replacementPercent, canton, grossSalary, birthYear}`

In `_buildCouplePreview()` (L615–716): also calls `RetirementTaxCalculator.estimateMonthlyIncomeTax(...)` three times to estimate the **"pénalité mariage"** — assuming a fictional partner at 60% of user salary. Pure retirement-tax framing on a landing page.

**CTA copy and routing:**
- Primary CTA `landingCtaCommencer` = **"Commencer"** (`app_fr.arb` L2420)
- `_onCtaTap()` (L85–102): if quick-calc filled → `_onCalculate()` (= retirement projection) ; otherwise → `/onboarding/intent` (or `/home` if completed)
- Quick-calc CTA `landingCalculate` = **"Voir mon chiffre"**
- Couple CTA `landingCoupleAction` = **"Voir le mode couple"** → `/auth/register?intent=couple`

**Animation sequence (L54–73):**
- `_heroController` 800ms — fires immediately on `initState`
- `_translatorController` 600ms — `Future.delayed(500ms)` then forward; per-card stagger 0–25%, 25–50%, 50–75% of curve
- `_footerController` 600ms — `Future.delayed(900ms)` then forward, drives `_buildHiddenNumber` AND `_buildQuickCalc` (same controller, no separate reveal)

**ARB strings actually rendered (verbatim from `app_fr.arb`):**

| Key | Line | French text |
|---|---|---|
| `landingPunchline1` | 2408 | « Le système financier suisse est puissant. » |
| `landingPunchline2` | 2409 | « Si tu le comprends. » |
| `landingHiddenAmount` | 6252 | « Montant masqué » |
| `landingHiddenSubtitle` | 6253 | « Crée un compte pour voir tes chiffres » |
| `landingQuickCalcTitle` | 10126 | « Ton chiffre en 30 secondes » |
| `landingQuickCalcSubtitle` | 10127 | « Aucun compte. Rien n'est stocké. Calcul éphémère. » |
| `landingBirthYear` | 10128 | « Année de naissance » |
| `landingSalary` | 10129 | « Salaire brut annuel (CHF) » |
| `landingCanton` | 10130 | « Canton » |
| `landingCalculate` | 10131 | « Voir mon chiffre » |
| `landingTransparency` | 10192 | « Ce qui se passe quand tu tapes ton salaire : le calcul est fait sur ton téléphone. Rien n'est envoyé. Rien n'est stocké. Quand tu fermes cette page, les chiffres disparaissent. » |
| `landingVzComparison` | 10133 | « 30 secondes pour ton premier chiffre. Pas de rendez-vous, pas de frais. » |
| `landingCoupleTitle` | 10181 | « En couple ? MINT optimise à deux. » |
| `landingCouplePersonalized` | 10182 | « Avec ton revenu, la pénalité mariage estimée est de CHF {penalty}/an. 3 leviers existent pour la réduire. » |
| `landingCoupleGeneric` | 10191 | « Les couples mariés perdent jusqu'à CHF 8'000/an en optimisations manquées. » |
| `landingCoupleAction` | 10190 | « Voir le mode couple » |
| `landingCtaCommencer` | 2420 | « Commencer » |
| `landingTrustSwiss` | 641 | « Conçu en Suisse » |
| `landingTrustPrivate` | 642 | « 100 % privé » |
| `landingTrustNoCommitment` | 643 | « Sans engagement » |
| `landingLegalFooterShort` | 2421 | « Outil éducatif. Ne constitue pas un conseil financier (LSFin). Données sur ton appareil. » |

The 3 "translator" pairs (`landingJargon1/4/3` ↔ `landingClear1/4/3`) reference **« Déduction de coordination », « Lacune de prévoyance », « Taux marginal »** — three concepts from the retirement / 2nd-pillar / tax bubble. Not one term about housing, debt, family, expat, disability, or any of the **18 life events**.

### A.2 — 5-axis copy ratings

| Element | Generic vs Mint (1 gen → 5 Mint) | Retirement-centric (1 rent → 5 agnostic) | Chiffre choc framing (1 choc → 5 éclairage) | 18-99 inclusive (1 skewed → 5 incl) | Bateau / cliché (1 bateau → 5 original) |
|---|---|---|---|---|---|
| Punchline « Le système financier suisse est puissant. Si tu le comprends. » | **3** — accurate but anyone could write it | **3** — agnostic-ish but framed as gnose | **3** — neutral | **4** — works 18-99 | **2** — sounds like a Raiffeisen white paper |
| `landingQuickCalcTitle` « Ton chiffre en 30 secondes » | **2** | **1** — the quick-calc IS retirement | **1** — literal "chiffre" | **2** — a 22-year-old with no LPP gets a fake number | **1** — the exact "chiffre choc" hook MINT pivoted away from |
| `landingQuickCalcSubtitle` « Aucun compte. Rien n'est stocké. Calcul éphémère. » | **4** — a real Mint differentiator | **5** | **5** | **5** | **4** — strong, keep |
| `landingHiddenAmount` « Montant masqué » + « Crée un compte pour voir tes chiffres » | **1** — Robinhood teaser pattern | **1** — assumes the value is *the number* | **1** | **2** | **1** — gating + dark pattern, kills trust |
| `landingTransparency` (the "ce qui se passe quand tu tapes ton salaire" paragraph) | **5** | **5** | **5** | **5** | **5** — this is the only paragraph that sounds like Mint. |
| `landingVzComparison` « 30 secondes pour ton premier chiffre. Pas de rendez-vous, pas de frais. » | **2** | **2** — implicit retirement | **2** | **3** | **2** — VZ-envy framing |
| `landingCoupleTitle` + Personalized « pénalité mariage estimée CHF X/an » | **3** | **2** — pure tax optim | **2** | **3** | **3** — clever but assumes married = optimization target |
| `landingCtaCommencer` « Commencer » | **1** | **5** | **5** | **5** | **1** — *the* generic SaaS button word |
| Translator pairs (déduction coord., lacune prévoyance, taux marginal) | **3** | **1** — three retirement/tax terms | **3** | **2** — a 22-year-old has zero of these | **2** — Linear-style "we translate jargon" pattern, executed on retirement vocab only |

**Aggregate axis scores** (mean):
- Generic vs Mint-specific: **2.7** — barely Mint
- Retirement-centric: **2.5** — heavily skewed retirement
- Chiffre choc framing: **3.0** — split, but quick-calc + hidden amount = pure choc
- 18-99 inclusive: **3.4** — passable but biased to 35-55 with LPP
- Bateau / cliché: **2.3** — Julien is right

### A.3 — Verbal clichés to kill (Julien's "verbe bateau" list)

| Cliché actuel | Pourquoi c'est bateau | Alternative doctrine-aligned |
|---|---|---|
| « Commencer » | Mot CTA générique #1 du SaaS mondial | « Voir ce que personne n'a intérêt à me dire » · « Allume une lumière » · « Continuer (sans compte) » |
| « Ton chiffre en 30 secondes » | Promesse Cleo-style + chiffre choc déguisé | À supprimer. Pas de promesse de chiffre. « Trois respirations, pas trois questions. » |
| « Voir mon chiffre » | Cf. supra | « Voir ce que ça implique » · « M'éclairer » |
| « Le système financier suisse est puissant. Si tu le comprends. » | Wisdom-porn bancaire. Aurait pu être écrit par Raiffeisen. | « Personne n'a intérêt à t'expliquer comment ça marche vraiment. C'est pour ça qu'on existe. » (= la mission verbatim de `MINT_IDENTITY.md`) |
| « Montant masqué / Crée un compte pour voir tes chiffres » | Dark pattern + suppose que la valeur de Mint = un chiffre derrière un paywall | À supprimer entièrement. Mint **ne cache rien** ; c'est l'inverse de la doctrine. |
| « En couple ? MINT optimise à deux. » | Verbe « optimise », promesse de gain, cadrage couple-marié-tax | « En couple, certaines décisions ne sont jamais expliquées aux deux. » |
| « Pénalité mariage estimée CHF X/an » | C'est un calcul retraite/fisc avant qu'on connaisse l'utilisateur | À supprimer du landing. JIT en conversation. |
| « 30 secondes pour ton premier chiffre. Pas de rendez-vous, pas de frais. » (vs VZ) | Comparaison VZ implicite. La doctrine dit Mint ≠ "VZ democratized en Cleo clone" mais aussi : ne nomme pas les concurrents | À supprimer. |
| « Conçu en Suisse · 100 % privé · Sans engagement » | Trust-bar SaaS standard | Garder « Privé » mais reformulé : « Rien ne sort de ton téléphone tant que tu ne le décides pas. » |

### A.4 — Verdict

**REBUILD.** Justification :

1. **Doctrine violation structurelle, pas textuelle.** Le landing importe `avs_calculator`, `lpp_calculator`, `tax_calculator`, demande `birthYear + grossSalary + canton`, calcule un taux de remplacement, et pousse vers `/chiffre-choc-instant`. Renommer les ARB ne corrige rien : le **fichier entier est un quick-calc retraite**. C'est exactement le piège « façade sans câblage » inverse — le câblage trahit le verbe.
2. **Le rename « chiffre choc » → « premier éclairage » a été fait dans certains strings UI mais pas dans les fichiers, les routes (`/chiffre-choc-instant`), les classes (`ChiffreChocScreen`, `InstantChiffreChocScreen`, `ChiffreChocSelector`), ni les analytics (`chiffre_choc_viewed`).** 174 fichiers × 719 occurrences (cf. §C.4).
3. **L'unique paragraphe excellent (`landingTransparency`)** mérite de survivre comme phrase mère de la nouvelle version.
4. Itérer sur ce fichier revient à repeindre une voiture qui a un mauvais moteur. Le geste juste : un nouveau fichier `landing_screen.dart` (one screen, one idea, one action) + suppression des imports financial_core + suppression de `/chiffre-choc-instant` du routing.

---

## Part B — Onboarding flow audit

### B.1 — File-by-file map

| # | File | Route | What user does | Persists | Reachable | Chiffre choc filename? |
|---|---|---|---|---|---|---|
| 0 | `landing_screen.dart` | `/` | (cf. Part A) — quick-calc retraite OU CTA → `/onboarding/intent` | rien (éphémère) | OUI (root) | non, mais route enfant `/chiffre-choc-instant` |
| 1 | `instant_chiffre_choc_screen.dart` | `/chiffre-choc-instant` | Voit AVS+LPP big number, lit canton context, attend 3.9s, tape une émotion, → `/onboarding/promise` | `OnboardingProvider.setEmotion/setBirthYear/setGrossSalary/setCanton/setChoc` | OUI (push depuis landing `_onCalculate`) | **OUI — `instant_chiffre_choc_screen.dart`** |
| 2 | `promise_screen.dart` | `/onboarding/promise` | Lit headline « MINT reste avec toi. » + body adapté à l'âge (3 brackets : <25 / 25-34 / 35+), tape « Commencer » → `/auth/login` | rien | OUI | non |
| 3 | `intent_screen.dart` | `/onboarding/intent` | Tape 1 chip parmi 9 (3a / Bilan / Prévoyance / Fiscalité / Projet / Changement / Premier emploi / Nouvel emploi / Autre) → `/onboarding/quick-start` | `ReportPersistenceService.setSelectedOnboardingIntent(chipKey)` | OUI | non (mais importe `chiffre_choc_selector` L15) |
| 4 | `quick_start_screen.dart` | `/onboarding/quick-start` | Dialogue de consentement nLPD (block until accept), prénom, picker année, salaire, canton, voit live preview retraite (avs+lpp+ratio+verdict), → `/onboarding/chiffre-choc` | `CoachProfileProvider.updateFromSmartFlow` + `ApiService.createProfile` (best-effort) + `SharedPreferences.onboarding_*` | OUI | non |
| 5 | `chiffre_choc_screen.dart` | `/onboarding/chiffre-choc` | Voit gros chiffre (API ou local fallback), avant/après collapsible, attend 3.9s, tape une émotion, → `/onboarding/plan` (clic Continuer) ou `/coach/chat?prompt=` (clic flèche TextField) | `ApiService.computeOnboardingChiffreChoc` (no persist) | OUI | **OUI — `chiffre_choc_screen.dart`** |
| 6 | `plan_screen.dart` | `/onboarding/plan` | Lit 4 étapes hardcodées (« Comprendre ton premier salaire » / « Configurer ton 3a » / « Vérifier ta couverture assurance » / « Connaître tes droits AVS »), tape « Voir mon plan » → `/home?tab=1` | `ReportPersistenceService.setMiniOnboardingCompleted(true)` + `CoachEntryPayloadProvider.setPayload(...)` | OUI | non |
| 7 | `data_block_enrichment_screen.dart` | `/data-block/<type>` | Approfondit un bloc (revenu/lpp/avs/3a/patrimoine/fisc/objectif/ménage). N'EST PAS dans le golden path d'onboarding, ouvert ad-hoc depuis le profil. | `CoachProfile` via providers | OUI mais hors flow | non |

### B.2 — Le graphe réel — DEUX onboardings parallèles soudés à `promise_screen`

```
                                           ┌── (vide)
/  (landing)
  │
  ├─ CTA "Commencer" sans data ──────────► /onboarding/intent ──► /onboarding/quick-start ──► /onboarding/chiffre-choc ──┬─► /onboarding/plan ──► /home?tab=1
  │                                              [chip]              [3 questions + form]        [API premier éclairage]   │     [4 étapes]
  │                                                                                                                       └─► /coach/chat?prompt=...  (BYPASS plan + completion flag !)
  │
  └─ CTA "Voir mon chiffre" (avec birthYear+salaire+canton) ──► /chiffre-choc-instant ──► /onboarding/promise ──► /auth/login ──► (?? — ré-entre par /onboarding/intent ?)
                                                                  [hero number éphémère]    [3 brackets âge]       [auth]
```

**Findings critiques :**

1. **Deux pipelines distincts qui ne se rejoignent jamais.** Le « path A » (CTA vide → intent) ne touche **jamais** ni `instant_chiffre_choc_screen` ni `promise_screen`. Le « path B » (quick-calc → instant-choc → promise → login) ne touche **jamais** ni `intent_screen` ni `quick_start_screen` ni `plan_screen`. Aucun lien dans le code ne fait passer un utilisateur du path B au path A après login. C'est **deux produits** dans un seul dossier `onboarding/`.

2. **Dead-end probable post-login.** `promise_screen` route en dur vers `/auth/login`. Une fois loggé, plus rien ne ramène l'utilisateur dans un flow d'onboarding cohérent — il va probablement échouer sur `/home` sans CoachProfile structuré. À vérifier dans les guards de `app.dart`, mais le code de `instant_chiffre_choc_screen._navigateToPromise` ne pré-remplit que `OnboardingProvider`, pas `CoachProfileProvider` — donc post-login, `quick_start_screen` n'est jamais rejoué.

3. **`chiffre_choc_screen` a deux sorties divergentes** (L231–246) :
   - Bouton flèche dans le TextField → `/coach/chat?prompt=$userFeeling` (push, **PAS de `setMiniOnboardingCompleted`**) — l'utilisateur termine en chat sans que `mini_onboarding_completed` soit `true`. Au prochain démarrage, il sera renvoyé en onboarding. **Bug d'UX confirmé.**
   - Bouton « Continuer » → `/onboarding/plan` (qui set le flag).

4. **Doublon `chiffre_choc_screen` / `instant_chiffre_choc_screen`** : deux fichiers, deux routes, deux animations identiques (mêmes 3.9s + 4.7s reveals, même `MintHeroNumber`, même `_responseController`), un appelle l'API + a `_avantApresExpanded`, l'autre est éphémère et a le `_cantonContext` switch hardcodé en 3 langues (français/allemand/italien). C'est **deux écrans qui font 90% la même chose** sur deux chemins parallèles.

5. **Le chip `intentChipPremierEmploi` / `intentChipNouvelEmploi`** est ajouté à `intent_screen` (chips 7 et 8) mais les deux clés ARB sont à des positions très éloignées (10524, 10525) — patch tardif, pas la liste originale.

6. **`promise_screen` segmente par âge** (3 brackets : `<25`, `25-34`, `35+`) — **violation directe de CLAUDE.md §1** : « **Segmentation: By life event and lifecycle phase, NEVER by age or demographics**. » Cet écran est techniquement non-conforme à la doctrine identité.

7. **`plan_screen` est bidon** : `_stepsForIntent` ignore l'intent reçu et retourne **toujours** les 4 mêmes étapes (« premier salaire » / « 3a » / « assurance » / « AVS »). Le commentaire L54 dit littéralement « Currently all intents show the same foundational steps. Future: customize per intent ». C'est de la façade.

### B.3 — Delta avec « 3 questions » (souvenir Julien)

Julien se souvient « 3 questions ». Voici le delta réel selon le path :

| Path B (quick-calc landing) | Path A (CTA vide) |
|---|---|
| Landing : 3 inputs (year, salary, canton) | `/onboarding/intent` : 1 chip |
| → instant-chiffre-choc : 1 input émotion | → quick-start : 4 inputs (firstName + year + salary + canton) **après dialog consentement** |
| → promise : 0 input, 1 tap | → chiffre-choc : 1 input émotion |
| → login : N inputs auth | → plan : 0 input, 1 tap |
| **Total : 4 questions + auth** | **Total : 6 inputs (consentement + 4 form + 1 émotion) + 1 chip** |

Donc : « 3 questions » est un fantôme. La réalité est **4 questions sur path B** et **6 sur path A**, avec en bonus un dialog consentement bloquant et une auth obligatoire sur path B. L'estimation de Julien était optimiste de ~50%.

### B.4 — Friction audit : champs à dégager

| Champ actuel | Friction | Signal apporté | JIT-able ? |
|---|---|---|---|
| `firstName` (`quick_start`) | Faible mais inutile à ce stade | 0 (pas utilisé pour le calcul) | OUI — demander au coach quand il salue |
| `birthYear` (landing + quick-start) | Cupertino picker = 2-3 secondes | Indispensable pour AVS/LPP | **NON, mais peut être différé** : MINT n'a pas besoin d'âge tant qu'on ne calcule pas une projection. La promesse + l'intent + l'éclairage qualitatif ne demandent rien. |
| `grossSalary` (landing + quick-start) | C'est le champ « tendu » — saisir son salaire = barrière de confiance | Indispensable pour LPP/3a/fisc | OUI — différer en JIT au moment exact où le coach a *besoin* du salaire |
| `canton` (landing + quick-start) | 26 items dropdown | Régionalité voix + fiscalité | OUI — peut être pré-rempli par geo si autorisé, sinon JIT |
| `intent chip` (intent_screen) | 1 tap | Le SEUL champ qui qualifie le besoin | **NON — c'est la vraie première question** |
| `émotion libre` (chiffre-choc) | Texte libre 3 lignes après attente 4.7s | Émotionnel, non-quantitatif | **NON, c'est précieux** mais doit venir APRÈS l'éclairage, pas en milieu de pipeline |
| `consentement nLPD dialog bloquant` (quick-start) | Modal barrierDismissible: false | Légal | OUI — banner non-bloquant comme `AnalyticsConsentBanner` qu'on a déjà sur landing |
| `dataBlockEnrichmentScreen` (8 blocs) | Hors flow | Profile depth | OUI — déjà JIT |

**Conclusion friction :** sur les 6 inputs pré-éclairage, **un seul est indispensable** (intent chip). Tous les autres peuvent être différés à la première fois où le coach en a réellement besoin. La règle de Stripe : *« Never ask before you need it »*.

---

## Part C — Redesign brief

### C.1 — Practitioners — what they actually do

**Wise (TransferWise)** — first screen post-install : un seul écran qui dit « **Send money worldwide.** » + un bouton « Get started ». Pas de calcul, pas de chiffre, pas de demande de revenu. Wise pose **zéro question financière** avant que tu n'aies besoin de faire un transfert. Le KYC arrive *quand tu en as besoin*. **Pattern à voler : la promesse est un verbe d'usage, pas un chiffre projeté.**

**Linear** — landing = un manifeste. « Linear is a purpose-built tool for modern product development. » Un seul paragraphe, une seule action. Pas de feature list, pas de témoignage en above-the-fold. **Pattern : autorité tranquille ; le produit s'explique en lui-même.**

**Stripe** — onboarding totalement contextuel. Tu peux créer un compte Stripe sans qu'on te demande ton numéro de TVA. La TVA arrive *au moment précis* où tu actives une feature qui en a besoin. **Pattern : "JIT data collection" — collecte au plus tard responsable.**

**Headspace** — première session : 3 questions sur ce que tu ressens (« What brings you to Headspace? — Stress / Sleep / Focus / Anxiety… ») + une session de 2 minutes. **Aucune** question démographique. **Pattern à voler verbatim** : remplacer « age + revenu + canton » par « **qu'est-ce qui te tend en ce moment quand tu penses à l'argent ?** ». Cette question est l'équivalent direct du chip intent — mais elle passe avant.

**iA Writer** — premier launch = un paragraphe, un bouton « Start writing ». Pas d'onboarding. Le produit fait sa propre démonstration. **Pattern : zéro onboarding est aussi une option.**

**Cleo** (rappel : ne pas copier la personnalité) — la structure est à voler : la première interaction est *déjà* un message du coach dans le chat, pas un formulaire. Le coach pose la première question, l'utilisateur tape la réponse, le coach calcule en fond. **Pattern : la conversation EST le formulaire.**

**VZ Vermögenszentrum** — le first-meet d'un prospect VZ est un **rendez-vous physique en agence avec un conseiller humain**, gratuit, sans engagement, durée 1h. Le client n'a rien à préparer ; il vient avec ses papiers ou pas. Le conseiller pose des questions, prend des notes, et envoie un dossier sous 2-3 semaines. **Pattern à voler : la version digitale doit recréer cette absence de pression initiale. Pas de formulaire à remplir avant le premier contact.** MINT doit être « le conseiller VZ au moment où tu en as besoin », pas « le formulaire VZ avant que tu en aies besoin ».

**Anti-pattern explicite à NE PAS reproduire :**
- Robinhood/Lemon (gating par « Create account to see your number »)
- N26/Revolut (questionnaire KYC avant la value prop)
- Tout neobank qui demande revenu+canton+âge+ID en 4 écrans avant de montrer quoi que ce soit
- Toute landing qui a un calculateur intégré (Yuh, Selma, Frankly — tous l'ont, tous ont raté la doctrine éducation-first)

### C.2 — Landing v2 spec

**Principe :** 1 écran. 1 idée. 1 action. Zéro champ. Zéro chiffre. Zéro projection.

**Layout :**
```
┌────────────────────────────────────────┐
│   MINT                          Login  │   (ghost)
│                                        │
│                                        │
│                                        │
│   [paragraphe-mère, ~30 mots]          │
│                                        │
│                                        │
│   ┌──────────────────────────────────┐ │
│   │  Continuer  (sans compte)       →│ │   pill, primary
│   └──────────────────────────────────┘ │
│                                        │
│   « Rien ne sort de ton téléphone      │   micro
│     tant que tu ne le décides pas. »   │
│                                        │
│   Outil éducatif. Ne constitue pas     │   legal
│   un conseil financier (LSFin).        │
└────────────────────────────────────────┘
```

**Trois variantes de paragraphe-mère testables :**

**Variante A — Mission verbatim (la plus sûre) :**
> « Mint te dit ce que personne n'a intérêt à te dire.
> Sur tes assurances, ton 3a, ton salaire, ton bail, ton couple, tes impôts.
> Calmement. Sans te vendre quoi que ce soit. »

**Variante B — Sensorielle (la plus piquante) :**
> « Tu as déjà signé un contrat sans tout comprendre.
> Tout le monde l'a fait.
> Mint relit avec toi — avant la prochaine fois. »

**Variante C — Inversée (la plus radicale, façon Linear) :**
> « Mint n'est pas une appli de retraite.
> Mint n'est pas un calculateur.
> Mint n'est pas un dashboard.
> Mint est l'ami qui a lu tes contrats avant toi. »

Note : Variante C reprend littéralement la liste « NOT a » de `CLAUDE.md §1`. Risque : trop méta. Force : ancre la doctrine. **Recommandation : tester A vs C en split sur landing-page web ; B en réserve comme A/B follow-up.**

**CTA copy options (à tester) :**
1. « Continuer (sans compte) » — recommandé, honnête sur le « no friction » Wise-style
2. « Voir comment ça marche » — neutre
3. « Allume une lumière » — métaphore « éclairage » poétique mais risque cliché
4. ❌ **Bannir : « Commencer », « Démarrer », « Découvrir », « Explorer »** (`feedback_no_cliche_ever`)

**Anti-patterns explicites pour la nouvelle landing :**
- ❌ aucun champ de saisie (pas même un picker)
- ❌ aucun chiffre, ni masqué, ni teasé, ni calculé
- ❌ aucun import de `financial_core/*`
- ❌ aucun mot « retraite », « LPP », « AVS », « 3a », « pension »
- ❌ aucune comparaison nominative ou implicite (VZ, Yuh, Frankly, Cleo)
- ❌ aucune segmentation par âge, état civil, ou démographie
- ❌ aucun trust-bar SaaS standard (« 100% privé · Sans engagement · Conçu en Suisse ») — **garder UNE phrase honnête**, pas trois badges
- ❌ aucun « moment de silence » ici — c'est trop tôt
- ❌ aucun témoignage, score, étoile, logo presse
- ❌ pas de « hidden amount / créer un compte » (= dark pattern)

### C.3 — Onboarding v2 spec — 3 alternatives rangées par friction

**Postulat commun à toutes les variantes :** après le CTA landing, on n'arrive PAS sur un formulaire. On arrive sur **`intent_screen` v2** — la première et seule question vraiment nécessaire avant le premier éclairage.

**Variante 1 (recommandée — friction minimale, "Headspace + Wise") — 1 question avant l'éclairage**

```
Landing → /onboarding/intent (1 chip parmi 9) → coach chat live (le coach calcule en fond ce qu'il peut, demande JIT ce qu'il manque)
```

- Aucun formulaire intermédiaire.
- Le coach démarre par une phrase qui utilise le chip choisi (« Tu m'as dit "ma situation change". Raconte-moi en deux phrases ce qui change. »)
- Lorsque le coach a besoin de l'âge (= au premier calcul AVS/LPP/EPL/3a), il demande dans le chat : « Tu es né en quelle année ? » + un date picker inline.
- Idem pour salaire, canton.
- **Premier « éclairage » qualitatif** rendu *immédiatement* après la 2e ou 3e réponse libre, pas après un formulaire.
- Inputs avant éclairage : **1 chip + 1 phrase libre**.

**Variante 2 (compromis — "intent + sensoriel") — 2 questions avant l'éclairage**

```
Landing → /onboarding/intent (chip) → /onboarding/sensoriel (1 phrase libre : « Qu'est-ce qui te tend en ce moment quand tu penses à l'argent ? ») → coach chat
```

- Réintroduit le « moment Headspace » avant le coach.
- Le coach reçoit `{intent, emotion}` et démarre une vraie conversation.
- Inputs : **1 chip + 1 phrase libre**, en 2 écrans plutôt qu'1.

**Variante 3 (minimal-form — "intent + canton") — pour utilisateurs qui veulent un chiffre tout de suite**

```
Landing → /onboarding/intent (chip) → /onboarding/canton-only (1 picker canton) → coach chat (qui peut citer le canton en première phrase, voix régionale immédiate)
```

- Friction très faible (1 chip + 1 picker)
- Le canton sert IMMÉDIATEMENT à activer la `RegionalVoiceService` — la voix est régionale dès la 1re phrase du coach.
- Pas d'âge, pas de salaire, pas de date de naissance.
- Inputs : **1 chip + 1 picker**.

**Recommandation :** **Variante 1**. Justification :
- Aligne avec la doctrine « la conversation EST le produit » (`feedback_chat_is_everything`)
- Permet à `intent_screen` de rester S1 immuable (cf. brief v0.2.3)
- Compatible avec le « curseur d'intensité » : le curseur peut être posé après la 1re phrase libre du user, dans le chat
- Plus extensible : si on veut ajouter le sensoriel plus tard, on peut le faire dans le chat sans toucher au flow
- Permet à V3 de ressusciter en plan B si métriques montrent que la voix régionale immédiate est un wow décisif

**Friction comparée :**

| | Variante 1 | Variante 2 | Variante 3 | Actuel path A | Actuel path B |
|---|---|---|---|---|---|
| Écrans avant 1er insight | 2 | 3 | 3 | 5 (intent + quick-start + chiffre-choc + plan + home) | 4 (landing+ICC + promise + login) |
| Champs saisis | 1 (chip) | 1 chip + 1 phrase | 1 chip + 1 picker | 1 chip + 4 form + 1 phrase + consent dialog | 3 form + 1 phrase + auth |
| Temps estimé | 15s | 25s | 20s | 90-120s | 60-90s |
| Premier éclairage est un | Insight qualitatif live coach | Insight qualitatif live coach | Salutation régionale + insight | Chiffre choc retraite | Chiffre choc retraite |

### C.4 — Sweep `chiffre_choc` rename — fichier-by-fichier scope

**État actuel :** 719 occurrences dans **174 fichiers**. Dont :

| Catégorie | Fichiers | Action |
|---|---|---|
| Filenames Dart | `apps/mobile/lib/screens/onboarding/chiffre_choc_screen.dart`, `instant_chiffre_choc_screen.dart`, `apps/mobile/lib/services/chiffre_choc_selector.dart`, `apps/mobile/lib/widgets/coach/chiffre_choc_section.dart`, `apps/mobile/lib/widgets/coach/chiffre_choc_card.dart` | `git mv` → `premier_eclairage_screen.dart`, `instant_premier_eclairage_screen.dart`, `premier_eclairage_selector.dart`, `premier_eclairage_section.dart`, `premier_eclairage_card.dart` |
| Filenames Python | `services/backend/app/services/onboarding/chiffre_choc_selector.py`, `services/backend/tests/test_chiffre_choc.py` | `git mv` |
| Routes GoRouter | `/chiffre-choc-instant`, `/onboarding/chiffre-choc` | renommer ou supprimer (cf. décision Variante 1 → on supprime les deux) |
| Class names | `ChiffreChocScreen`, `InstantChiffreChocScreen`, `ChiffreChocSelector`, `ChiffreChoc`, `ChiffreChocType` (enum), `ChiffreChocSection`, `ChiffreChocCard` | rename refactor |
| ARB keys | `chiffreChocSilenceQuestion`, `chiffreChocSilenceHint`, `chiffreChocBack`, `chiffreChocConfidenceSimple`, `chiffreChocAvantApres*` (~12 keys), `chocQuestion*` (~6 keys), `instantChiffreChoc*` (~3 keys), 6 fichiers ARB × ~25 keys = **~150 ARB lines** | rename + `flutter gen-l10n` |
| Analytics events | `chiffre_choc_viewed`, `cta_quick_calc` | rename — coordonner avec dashboards admin (`admin_analytics_screen.dart`) |
| Backend API path | `/onboarding/minimal-profile`, `/onboarding/chiffre-choc` (cf. `services/backend/app/api/v1/endpoints/onboarding.py`) | renommer + bump OpenAPI |
| Tests Dart | 8 journey golden_path_test files + `chiffre_choc_selector_test.dart` + `screen_registry_test.dart` | rename + assertions |
| Tests Python | `test_chiffre_choc.py` (34 occurrences), `test_pillar_3a_retroactive.py`, `test_donation.py`, etc. | rename |
| Docs | `docs/WIRE_SPEC_V2.md`, `docs/MINT_SCREEN_BOARD_101.md`, `docs/W17_*`, `docs/ONBOARDING_ARCHITECTURE.md`, `decisions/`, `.planning/milestones/v2.0-phases/01-le-parcours-parfait/*` | rename — sed-friendly |
| **CLAUDE.md** | 1 occurrence (la note legacy) | OK déjà annotée |

**Estimation coût (pessimiste) :**
- ~3h pour `git mv` + class rename (IDE refactor sécurisé) sur Dart
- ~2h pour Python equivalent
- ~2h pour ARB keys × 6 langues + `flutter gen-l10n`
- ~1h pour routes + redirects de compatibilité
- ~2h pour OpenAPI + backend endpoints + Pydantic schemas
- ~2h pour tests rename + assertion update
- ~1h pour docs sed
- **Total : ~13h sur une seule personne, ~1 jour-homme**.

**Quand le faire :** **Phase 0** de v2.2 (avant L1.0). Sinon tout chantier qui touche à l'onboarding ou à l'éclairage va régénérer du legacy. C'est un gel-debt obligatoire.

### C.5 — Implications pour le brief v0.2.3 — recommandation explicite

Le brief liste 5 surfaces immuables :
- S1 = `intent_screen.dart`
- S2 = `home`
- S3 = `bubble coach`
- S4 = `carte résultat calculateur`
- S5 = `MintAlertObject`

**Problème :** le brief ne mentionne ni le landing, ni `quick_start_screen`, ni `promise_screen`, ni les deux `chiffre_choc_screen`, ni `plan_screen`. **Six écrans qui sont sur le chemin critique avant S1 sont hors-radar.**

**Recommandation explicite (ne pas dodge) :**

1. **Garder les 5 surfaces immuables S1–S5 telles quelles.** Elles sont conceptuellement justes.
2. **Ajouter une 6e surface immuable : `S0 = landing_screen.dart` (rebuild)** — c'est la porte. Elle mérite une chantier dédié, pas un sous-bullet.
3. **Ne PAS ajouter `quick_start_screen` / `chiffre_choc_screen` / `plan_screen` / `instant_chiffre_choc_screen` / `promise_screen` aux surfaces immuables.** Au contraire : les **supprimer** dans la Variante 1. Leur seul rôle dans le nouveau monde est leur absence.
4. **Ouvrir deux chantiers Layer 1 supplémentaires :**
   - **L1.7 — Landing v2** (rebuild de `landing_screen.dart` selon §C.2). Dépendance : aucune. Peut démarrer en parallèle avec L1.0.
   - **L1.8 — Onboarding v2** (suppression des 5 écrans intermédiaires + rebranchement intent_screen → coach chat direct, selon §C.3 Variante 1). Dépendance : L1.7 (sinon le landing pousse vers du vide), + Phase 0 rename sweep.
5. **Phase 0 obligatoire : `chiffre_choc` rename sweep** (cf. §C.4). C'est un prérequis non-négociable de toute action sur S1, L1.7, L1.8. Le faire avant S1 garantit que le chip `intent_screen` ne renvoie pas vers une route au nom legacy.
6. **Auditer S1 (`intent_screen.dart`) pour 2 corrections immédiates :**
   - Supprimer l'import `chiffre_choc_selector` (L15) — la sélection d'éclairage doit déménager dans le coach service, pas vivre dans intent
   - Vérifier que la branche `_isFromOnboarding == true` (golden path) ne route plus vers `/onboarding/quick-start` mais directement vers le coach chat avec payload, pour Variante 1

**Phrase à insérer dans le brief v0.2.4 (proposition) :**

> **Layer 1 — surfaces immuables (v0.2.4) : six chantiers, six surfaces.**
> S0 landing (rebuild) · S1 intent_screen (audit) · S2 home · S3 bubble coach · S4 carte résultat · S5 MintAlertObject.
>
> **Phase 0 (prérequis non-négociable) :** sweep `chiffre_choc` → `premier_eclairage` (174 fichiers, ~13h, gel-debt obligatoire).
>
> **Suppressions actées :** `quick_start_screen.dart`, `chiffre_choc_screen.dart`, `instant_chiffre_choc_screen.dart`, `promise_screen.dart`, `plan_screen.dart`, route `/chiffre-choc-instant`, route `/onboarding/chiffre-choc`, route `/onboarding/quick-start`, route `/onboarding/promise`, route `/onboarding/plan`. Le golden path Layer 1 = landing → intent → coach. Trois écrans, pas huit.

---

## Annexe — quick references

**Files audited (absolute paths):**
- `/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/screens/landing_screen.dart`
- `/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/screens/onboarding/promise_screen.dart`
- `/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/screens/onboarding/intent_screen.dart`
- `/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/screens/onboarding/quick_start_screen.dart`
- `/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/screens/onboarding/chiffre_choc_screen.dart`
- `/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/screens/onboarding/instant_chiffre_choc_screen.dart`
- `/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/screens/onboarding/data_block_enrichment_screen.dart`
- `/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/screens/onboarding/plan_screen.dart`
- `/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/l10n/app_fr.arb`
- `/Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/app.dart` (routes 192, 853–878, 927–929)

**Confidence levels:**
- A.1 factual extraction — **HIGH** (grep + line-quoted)
- A.2 5-axis ratings — **MEDIUM** (subjective but evidence-anchored)
- B.1 file map — **HIGH** (read line-by-line)
- B.2 graph — **HIGH** (direct trace of `context.go`/`context.push` calls)
- C.1 practitioners — **MEDIUM** (training-data, not re-verified live; patterns are well-known and stable)
- C.2/C.3 redesign specs — **OPINIONATED**, not "true/false" — to be decided by Julien
- C.4 sweep file count — **HIGH** (`grep -c` aggregate = 719 in 174 files, verified)
- C.5 brief implications — **HIGH** (cross-referenced with brief v0.2.3 §149)

**Key open questions for synthesizer / planner:**
- Variante 1 vs 2 vs 3 — décision Julien obligatoire avant L1.8 plan
- Variante A vs B vs C de paragraphe-mère — testable en split, pas bloquant
- Garder ou supprimer `data_block_enrichment_screen.dart` ? (hors flow onboarding mais utilisé en JIT depuis profil — recommandation : **garder**, c'est le mécanisme JIT déjà en place)
- Que faire de `OnboardingProvider` (utilisé par instant + promise) si on supprime ces deux écrans ? Recommandation : déprécier le provider, migrer vers `CoachProfileProvider` + `CapMemoryStore`
