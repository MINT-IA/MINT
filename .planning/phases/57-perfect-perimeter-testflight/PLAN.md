---
phase: 57-perfect-perimeter-testflight
plan: master
type: execute
wave: 1
status: proposed
target_milestone: v2.10.0 (TestFlight cut)
target_pubspec: 2.10.0+1
target_branch: feat/phase-57-perfect-perimeter
target_window: 7-10 jours (J1 = 2026-05-05, TestFlight submit J7-J10)
depends_on:
  - PR #479 (sprint-1 nav audit) — merged into dev
  - PR #478 (sprint-0 401 breadcrumb) — merged into dev
  - PR #475 (consent ApiException) — already shipped
autonomous: false  # day 5 + day 7 contiennent device gates Julien
files_modified:
  - apps/mobile/lib/screens/landing/landing_screen.dart
  - apps/mobile/lib/screens/anonymous/anonymous_chat_screen.dart
  - apps/mobile/lib/screens/anonymous/anonymous_intent_screen.dart
  - apps/mobile/lib/services/anonymous_chat_persistence.dart  # NEW
  - apps/mobile/lib/services/coach/anonymous_first_eclairage_orchestrator.dart  # NEW
  - apps/mobile/lib/screens/auth/register_screen.dart
  - apps/mobile/lib/app.dart
  - apps/mobile/lib/l10n/app_*.arb  # 6 fichiers
  - services/backend/app/api/coach_chat.py
  - services/backend/app/services/coach/anonymous_eclairage_prompt.py  # NEW
  - tools/simulator/walker.sh
  - tools/simulator/walker_first_eclairage_journey.sh  # NEW
  - apps/mobile/test/screens/anonymous/*.dart
  - apps/mobile/test/services/anonymous_chat_persistence_test.dart
  - apps/mobile/test/golden/anonymous_first_eclairage_test.dart
  - apps/mobile/integration_test/anonymous_first_eclairage_e2e.dart
  - .planning/phases/57-perfect-perimeter-testflight/57-VERIFICATION-REPORT.html
  - apps/mobile/pubspec.yaml
requirements:
  - PERIM-57-01  # Landing→Intent CTA frictionless (<2s tap-to-pill)
  - PERIM-57-02  # Anonymous chat persistence (kill 3-msg dead-end)
  - PERIM-57-03  # Premier éclairage payload backend (lucidité, pas retraite)
  - PERIM-57-04  # Auth gate ?redirect= round-trip preserve context
  - PERIM-57-05  # Walker E2E green sur 4 archétypes (julien_swiss / lauren_expat_us / fatih_cross_border / sarah_indep_no_lpp)
  - PERIM-57-06  # Golden tests visuels green sur 2 viewports + 2 locales (FR/EN)
  - PERIM-57-07  # Panel-before-push design verdict ARCHIVED dans VERIFICATION-REPORT
  - PERIM-57-08  # TestFlight build 2.10.0 dispo + journaliste-defensible
must_haves:
  truths:
    - "Un visiteur anonyme tape le CTA sur Landing et arrive sur intent picker en <2s sans flash"
    - "Le visiteur choisit un intent (pill ou free-text), envoie 1-3 messages, reçoit un premier éclairage personnalisé en streaming sous 8s"
    - "Le premier éclairage parle de SA situation (canton implicite, life event sélectionné), pas de copy générique retraite"
    - "Si le visiteur quitte avant inscription, ses messages sont persistés localement et reviennent intacts à la prochaine ouverture (jusqu'à 7j)"
    - "Si le visiteur tape register au moment du auth-gate, après inscription il revient sur le chat anonyme converti, pas sur Landing"
    - "Le walker E2E peut compléter le parcours bout-en-bout sans intervention humaine sur 4 archétypes différents"
    - "Aucune string hardcodée FR ; toutes via AppLocalizations.of(context)!.key (parité 6 ARB)"
    - "Aucun banned-term LSFin (validate via check_banned_terms MCP)"
  artifacts:
    - path: "apps/mobile/lib/services/anonymous_chat_persistence.dart"
      provides: "SharedPreferences-backed persistence pour _messages avec TTL 7j + clear-on-register"
      min_lines: 80
    - path: "services/backend/app/services/coach/anonymous_eclairage_prompt.py"
      provides: "System prompt + few-shot dédié anonymous pre-register, lucidité-first, jamais de retraite-first hero"
      min_lines: 120
    - path: "apps/mobile/integration_test/anonymous_first_eclairage_e2e.dart"
      provides: "E2E parcours complet Landing→Intent→Chat→3msg→AuthGate avec 4 archetypes"
      min_lines: 150
    - path: "tools/simulator/walker_first_eclairage_journey.sh"
      provides: "Walker scriptable bout-en-bout sur sim iOS, capture 12 screenshots horodatés"
      min_lines: 200
    - path: ".planning/phases/57-perfect-perimeter-testflight/57-VERIFICATION-REPORT.html"
      provides: "Rapport HTML cumulatif: PRs / panel verdicts / test counts / walker captures / TestFlight build link"
      contains: "TestFlight build 2.10.0"
  key_links:
    - from: "apps/mobile/lib/screens/landing/landing_screen.dart"
      to: "/start → /anonymous/intent"
      via: "context.go('/start') sans auth gate"
      pattern: "context\\.go\\('/start'\\)"
    - from: "apps/mobile/lib/screens/anonymous/anonymous_chat_screen.dart"
      to: "AnonymousChatPersistence.save() / load() / clear()"
      via: "initState() loads, _onMessageSent() saves, _onRegisterSuccess() clears"
      pattern: "AnonymousChatPersistence"
    - from: "apps/mobile/lib/screens/anonymous/anonymous_chat_screen.dart"
      to: "/auth/register?redirect=/anonymous/chat"
      via: "auth_gate CTA preserves redirect"
      pattern: "context\\.go\\('/auth/register\\?redirect="
    - from: "services/backend/app/api/coach_chat.py"
      to: "anonymous_eclairage_prompt.build_system_prompt()"
      via: "if request.is_anonymous: use anonymous prompt"
      pattern: "is_anonymous.*anonymous_eclairage"
    - from: "tools/simulator/walker_first_eclairage_journey.sh"
      to: "apps/mobile/integration_test/anonymous_first_eclairage_e2e.dart"
      via: "flutter drive --target=integration_test/anonymous_first_eclairage_e2e.dart --device-id=<sim>"
      pattern: "flutter drive.*anonymous_first_eclairage_e2e"
---

# Phase 57 — Perfect Perimeter for TestFlight 2.10.0

> **Decision authority:** Julien. Synthèse par Claude en mode Product Leader autonome.
> **Origine:** post-Sprint-1 nav-audit (PR #479) — décision « scope serré, parfait dans 1 périmètre, TestFlight 7-10j ».
> **Méthodologie:** panel mental 5 candidats journey scorés, A retenu (Anonymous → Premier éclairage → Register).

## 1. Goal

> **Goal :** sur 7-10 jours, livrer un parcours **« Anonymous → Premier éclairage → Register »** PARFAIT (tap-walkthrough sans glitch, panel-validated, walker E2E vert sur 4 archétypes, TestFlight 2.10.0 build dispo).

**Critère de réussite mesurable (Definition of Done résumée — détail §8) :**

- Walker E2E completes parcours bout-en-bout sur 4 archétypes (`julien_swiss`, `lauren_expat_us`, `fatih_cross_border`, `sarah_indep_no_lpp`) en <90s par archétype, 0 dead-end.
- Golden screenshot tests green sur 2 viewports (iPhone 16 Pro + Pixel 8) × 2 locales (FR + EN) = 4 baselines.
- 0 banned-term LSFin (`check_banned_terms` MCP exit 0 sur les 6 ARB + le system prompt anonymous).
- Parité ARB 6 langues (`validate_arb_parity` MCP exit 0).
- TestFlight build 2.10.0 visible dans App Store Connect, signé, ready-to-distribute.
- 4-person design panel (UX + a11y + adversarial + engineering) verdict ARCHIVED dans `57-VERIFICATION-REPORT.html` AVANT push final.

---

## 2. Définition du périmètre

### 2.1 IN — surface unique livrée parfaite

**User journey end-to-end : « Anonymous → Premier éclairage → Register »**

```
LandingScreen
   │  tap CTA « Commencer »
   ▼
/start → redirect → /anonymous/intent  (RouteScope.public, sans auth)
   │  user pick a pill OU free-text
   ▼
/anonymous/chat?intent=<picked>
   │  message #1 user → réponse coach #1 (streaming, <8s, prompt anonymous-spécifique)
   │  message #2 user → réponse coach #2 (lucidité-first, pas retraite-first)
   │  message #3 user → auth gate apparaît (bottom sheet)
   │   │
   │   ├── « Pas maintenant » → back to / (Landing) MAIS messages persistés (load au retour)
   │   │
   │   └── « Créer mon compte » → /auth/register?redirect=/anonymous/chat
   │           │  user enter email + password OR Apple SSO
   │           ▼
   │           AuthSuccess → router redirect callback honors ?redirect= → /anonymous/chat
   │                        │  AnonymousChatPersistence.clear() (anti-leak)
   │                        │  messages anonymous → migrés vers session authentifiée
   │                        ▼
   │                        /coach/chat (Tab 2) avec contexte préservé
```

**Surfaces critiques (exhaustif — tout reste OUT) :**

1. `LandingScreen` (`apps/mobile/lib/screens/landing/landing_screen.dart`) — CTA principal + long-press wordmark
2. `AnonymousIntentScreen` (`apps/mobile/lib/screens/anonymous/anonymous_intent_screen.dart`) — pills + free-text
3. `AnonymousChatScreen` (`apps/mobile/lib/screens/anonymous/anonymous_chat_screen.dart`) — bubbles + auth gate + persistence
4. `RegisterScreen` (`apps/mobile/lib/screens/auth/register_screen.dart`) — honors ?redirect=
5. Backend `coach_chat.py` + nouveau `anonymous_eclairage_prompt.py`

### 2.2 OUT — backlog explicite (NE PAS toucher)

> Tout ce qui suit est consciemment EXCLU du périmètre Phase 57. Documenté pour ne pas se faire détourner.

| Sujet | Pourquoi OUT | Quand revenir | Réf |
|---|---|---|---|
| **Coach chat tab routing stale (FIX-04)** | Hors funnel d'entrée — un user qui crash sur Tab 2 a déjà signé up, hors target conversion | Phase 58 | `STATE.md:219` |
| **save_fact backend↔Flutter unsync (FIX-03)** | Path post-onboarding ; le journey 57 n'écrit jamais de fact backend (anonymous = local only) | Phase 58 ou 33 | `STATE.md:218` |
| **Couple mode façade (calculs financial_core jamais wirés UI)** | Data layer cassé (Engineering Reviewer Phase 54 panel) — 2-3 sem de fix avant que ce soit shippable | v2.11+ | `STATE.md:222` |
| **388 bare catches → 0** | Couvert par Phase 36 Finissage E2E (non-empruntable) — pas le scope d'un sprint TestFlight | Phase 36 | `STATE.md:215` |
| **Document scan stack (chat → scan → review → impact)** | Scope >4h fix + auth-gate sans redirect ; impact secondaire pour conversion anonymous→register | Phase 58 (P3 nav-audit) | `2026-05-05-nav-audit-gaps.md §3` |
| **Onboarding system-back hardware (P4)** | PENDING-VERIFY device, pas un blocker journey 57 (onboarding wedge n'est PAS le funnel anonymous) | Phase 58 | `2026-05-05-nav-audit-gaps.md §4A` |
| **DUPLICATE-INTENT-SHIM cleanup (26 entries P5)** | LLM clarity, pas un blocker walker | Phase 58+ | nav-audit P5 |
| **Wiki coach** | Spécifiquement demandé out-of-scope par l'orchestrateur — un wiki n'est ni de la lucidité ni un funnel ; risque scope-creep majeur | v2.12 ou jamais | request explicite |
| **Coach chat life-event redesign** | Hors funnel premier-touch | v2.11+ | — |
| **PrecomputedInsight on chat-open (Phase 54-02)** | Déjà shippé ; on peut le consommer mais on ne touche pas | déjà fait | PR #452 |
| **AUDIT_TAP_RENDER 56 rows** | Walker ciblé sur le journey 57 only ; le tap-render audit complet attendra Phase 36 | Phase 36 | — |
| **Voice STT/TTS** | S63 backlog | post-TestFlight | ROADMAP_V2 |
| **Bank+LPP API integrations (Cleo-style)** | v3.0+ scope | post-TestFlight | mission Julien |

### 2.3 Worktree discipline

Travail sur le worktree `MINT.sprint1-nav.nosync` (current). Les autres worktrees actifs (`MINT.nosync`, `MINT.phase56-pr3.nosync`, `MINT.sprint0-401.nosync`) ne reçoivent **aucun commit** Phase 57. Branche : `feat/phase-57-perfect-perimeter` créée depuis `dev` après merge de #478 + #479.

---

## 3. Stratégie

### 3.1 Pourquoi CE journey, pas un autre

**Heuristique panel scorée (5 candidats × 5 critères, 1-5) :**

| Candidat | Conv impact | Lucidité visible | Effort | Risk évité | Signal CH | Total |
|---|---|---|---|---|---|---|
| **A. Anonymous → Premier éclairage → Register** | 5 | 5 | 3 | 4 | 4 | **21** ← retenu |
| B. Document scan → impact → coach plan | 4 | 5 | 2 | 2 | 5 | 18 |
| D. Onboarding wedge → bifurcation → home | 3 | 3 | 4 | 4 | 3 | 17 |
| C. Coach chat life-event → screen → return | 3 | 4 | 3 | 3 | 3 | 16 |
| E. Couple mode wiring | 4 | 4 | 1 | 1 | 4 | 14 |

**Justification (1 paragraphe) :** A est le seul journey qui touche **TOUS** les paliers du funnel d'acquisition (Landing → conversion). Il sera le premier contact que la presse, les early adopters et les TestFlight beta users auront avec MINT. Si CE parcours n'est pas parfait, rien d'autre ne compte. C'est aussi le seul journey où la promesse de pivot 2026-04-12 (« lucidité, pas protection, 18-99 ans ») se DÉMONTRE en moins de 60 secondes : le visiteur tape 1-3 messages, reçoit un premier éclairage qui parle de SA situation, et décide en connaissance de cause s'il veut s'inscrire. B (doc scan) est plus impressionnant mais nécessite que l'user ait déjà téléchargé un document — ce n'est pas le first-touch. C (life-event chat) suppose un user déjà inscrit. D (onboarding wedge) bifurcation reste post-register. E (couple) a un data layer cassé qui demanderait 2-3 sem de fix avant shippable. Le Sprint 1 nav-audit a déjà identifié 3 des 5 fixes Pareto sur le journey A (P1 `/dossier`, P2 anonymous persistence, P3 ?redirect=) — la dette technique est connue, scope-able, et compatible avec un sprint 7-10j.

### 3.2 Signal de positionnement

**Promesse delivered au journaliste / early adopter en 60s :**

> « Tu ouvres MINT, tu tapes 'commencer', tu choisis 'je viens de signer mon premier contrat de travail', tu tapes 1 question, MINT te répond avec 3 implications concrètes pour TA situation (canton détecté du device locale, life event sélectionné, pas de bla-bla retraite). Tu n'as pas créé de compte. Tu peux fermer l'app. Quand tu reviens, tes messages sont là. »

C'est le toilet test (`MINT_IDENTITY.md §53`) : 20s, fatigue OK, jamais pompeux, jamais scolaire. C'est aussi ce que **Cleo $250M ARR** fait (chat-first, pas account-first). MINT-suisse différenciation : segmentation par life event (pas par âge), respect LSFin (pas de « optimal » / « garanti » / « meilleur »), accents FR 100%.

### 3.3 Lien identité

| Principe `MINT_IDENTITY.md` | Comment le journey 57 le matérialise |
|---|---|
| Mission « ce que personne n'a intérêt à te dire » | Le premier éclairage anonymous est gratuit, sans paywall, sans création de compte — preuve qu'on ne vend rien |
| « Mint éclaire, n'accuse pas » | System prompt anonymous interdit explicitement les comparatifs nominaux et les jugements |
| Couche 1-4 (extraction → traduction → perspective → questions) | Réponse coach #1 doit suivre exactement cette structure (golden test l'enforce) |
| Toilet test 20s | Walker E2E mesure le `tap-to-first-response` en <8s, parcours complet <90s |
| MINT n'est PAS une app de retraite | Lint sur le system prompt anonymous ban des mots `retraite|retirement|65 ans|pilier 2|LPP` dans le PREMIER éclairage |

---

## 4. Architecture sprint — 4 PRs séquencés

```
PR-A (data layer)        ── J1-J2 ──► merge to dev
   │
   ├──► PR-B (UX wiring)  ── J2-J4 ──► merge to dev      ┐
   │                                                       │
   └──► PR-C (backend prompt) ── J3-J4 ──► merge to dev   ├──► PR-D (E2E + walker + golden)
                                                           │      ── J5-J7 ──► merge to dev
                                                           ┘
                                                                  │
                                                                  ▼
                                                          ── J7-J10 ──► staging → testflight.yml CI
                                                                                    → TestFlight 2.10.0
```

### 4.1 PRs (séquence + parallélisation)

| PR | Branche | Scope | Dépend de | Parallélisable avec | Owner-lens |
|---|---|---|---|---|---|
| **PR-A** | `feat/phase-57-pr-a-anon-persistence` | `AnonymousChatPersistence` service + tests + flag-guard | — | — | Engineering |
| **PR-B** | `feat/phase-57-pr-b-anon-ux-wiring` | Wire persistence dans `AnonymousChatScreen` + `?redirect=` sur auth gate + ARB updates | PR-A merged | PR-C | UX wiring |
| **PR-C** | `feat/phase-57-pr-c-backend-anon-prompt` | `anonymous_eclairage_prompt.py` + branche `is_anonymous` dans `coach_chat.py` + system prompt FR/EN | — | PR-B | Backend |
| **PR-D** | `feat/phase-57-pr-d-walker-golden-e2e` | Walker `walker_first_eclairage_journey.sh` + `integration_test/*` + golden tests + 4 archetypes | PR-A + PR-B + PR-C | — | QA / Walker |

**Cut TestFlight = J7-J10 sur `dev` après PR-D merged + golden ARCHIVED + walker green.**

---

## 5. Day-by-day (J1 → J10)

### J1 (lundi 2026-05-05) — Data layer + branche

**Tâches :**

- [ ] Créer branche `feat/phase-57-perfect-perimeter` from `dev` (after #478 merged) — **commande** : `git fetch origin && git checkout -b feat/phase-57-perfect-perimeter origin/dev`
- [ ] **PR-A.T1** : Créer `apps/mobile/lib/services/anonymous_chat_persistence.dart` (~80 LOC)
  - Fields : `messages: List<ChatMessage>`, `expiresAt: DateTime` (TTL 7j), `intent: String?`
  - Methods : `Future<void> save(List<ChatMessage>)`, `Future<List<ChatMessage>?> load()`, `Future<void> clear()`, `Future<bool> isExpired()`
  - Storage : `SharedPreferences` key `mint.anonymous.chat.v1` (versioned for future migration)
  - Encryption : NONE (pas de PII anonymous user-side ; storage local seulement)
  - Anti-leak : `clear()` appelé sur `register_success` event + `expiresAt` automatique
- [ ] **PR-A.T2** : Tests unitaires `apps/mobile/test/services/anonymous_chat_persistence_test.dart` (~100 LOC)
  - 6 tests : save/load round-trip, TTL expiry, clear semantics, intent preservation, malformed data graceful, version mismatch graceful
- [ ] **PR-A.T3** : Wire `AnonymousChatPersistence` provider dans `app.dart` MultiProvider
- [ ] **PR-A.T4** : Open PR-A draft, run `flutter test test/services/anonymous_chat_persistence_test.dart`, commit, push, mark ready-for-review

**Files :** `anonymous_chat_persistence.dart` (NEW) + test (NEW) + `app.dart` (MultiProvider line ~150)

**Gates J1 :**
- ✅ `flutter analyze lib/services/anonymous_chat_persistence.dart` 0 warnings
- ✅ 6/6 unit tests green
- ✅ PR-A draft open, CI green
- 📋 `57-VERIFICATION-REPORT.html` initialized with PR-A row

---

### J2 (mardi) — UX wiring + Backend prompt parallel

**Track 1 — PR-B (UX) :**

- [ ] **PR-B.T1** : Modifier `anonymous_chat_screen.dart`
  - `initState()` : `await persistence.load()` ; if non-null + non-expired, hydrate `_messages`
  - `_onMessageSent(message)` : `await persistence.save([..._messages, message])`
  - `_onAuthGateRegister()` : `context.go('/auth/register?redirect=/anonymous/chat')` (au lieu de `/auth/register` nu)
  - `_onAuthGatePostpone()` : `context.go('/')` (Landing) — messages restent en persistence
  - Listener `register_success` event → `await persistence.clear()` + push to `/coach/chat` avec messages migrés
- [ ] **PR-B.T2** : Modifier `register_screen.dart` pour honorer `?redirect=` query param
  - Parse `redirect` from `GoRouterState.uri.queryParameters['redirect']`
  - Default fallback : `/coach/chat`
  - Validation : redirect doit matcher whitelist `/anonymous/chat|/coach/chat|/home|/onb` (anti open-redirect)
- [ ] **PR-B.T3** : Update `app.dart` redirect callback line ~261 pour propager `?redirect=` sur les auth-gate paths

**Track 2 — PR-C (Backend) parallèle :**

- [ ] **PR-C.T1** : Créer `services/backend/app/services/coach/anonymous_eclairage_prompt.py` (~120 LOC)
  - `build_system_prompt(intent: str, locale: str, canton_hint: str | None) -> str`
  - System prompt enforce : couches 1-4 du moteur MINT, ban `retraite|LPP|65 ans` dans la PREMIÈRE réponse, ban LSFin terms, max 220 mots, 2-3 paragraphes, finit par 1 question
  - Few-shot : 3 exemples par locale (FR, EN, DE) — Lea (firstJob/VD), Marc (mariage/GE), Sofia (achat-logement/ZH)
- [ ] **PR-C.T2** : Modifier `services/backend/app/api/coach_chat.py` route `/coach/chat`
  - Add `is_anonymous: bool` field to `CoachChatRequest`
  - Branche : `if request.is_anonymous: system_prompt = anonymous_eclairage_prompt.build_system_prompt(...)`
  - Disable tool calls when `is_anonymous=True` (pas de `route_to_screen`, pas de `save_fact` — anonymous = read-only)
  - Add rate-limit : 5 req/IP/15min on anonymous path (anti-abuse)
- [ ] **PR-C.T3** : Tests pytest
  - `tests/services/coach/test_anonymous_eclairage_prompt.py` : 3 tests par locale = 9 tests
  - `tests/test_coach_chat_anonymous.py` : 4 tests (is_anonymous routing, no tool calls, rate-limit, banned-term grep)

**Files PR-B :** `anonymous_chat_screen.dart` (~50 lignes diff), `register_screen.dart` (~30 lignes), `app.dart` (~10 lignes)

**Files PR-C :** `anonymous_eclairage_prompt.py` (NEW ~120 LOC), `coach_chat.py` (~30 lignes diff), `pyproject.toml` (no change), 2 test files (NEW)

**Gates J2 :**
- ✅ PR-B draft open, `flutter analyze` 0 warnings, widget test smoke green
- ✅ PR-C draft open, pytest backend `pytest services/backend/tests/services/coach/test_anonymous_eclairage_prompt.py -q` green
- ✅ MCP `check_banned_terms(system_prompt)` exit 0 sur les 3 system prompts (FR/EN/DE)
- 📋 `57-VERIFICATION-REPORT.html` updated avec rangée PR-B + PR-C

---

### J3 (mercredi) — i18n + ARB sweep + integration

- [ ] **PR-B.T4** : Update 6 ARB files (`apps/mobile/lib/l10n/app_{fr,en,de,es,it,pt}.arb`)
  - 8 nouvelles keys : `anonymousChatAuthGateTitle`, `anonymousChatAuthGateBody`, `anonymousChatAuthGateRegisterCta`, `anonymousChatAuthGatePostponeCta`, `anonymousChatRestoredBanner`, `anonymousChatPersistenceExpired`, `anonymousChatErrorRetry`, `anonymousChatPlaceholder`
  - Toutes traductions FR avec accents 100% (`creer → créer`, `eclairage → éclairage`)
  - Run `flutter gen-l10n` → vérifier 0 ARB parity warning
- [ ] **PR-B.T5** : MCP gates
  - `validate_arb_parity()` exit 0 (6 fichiers parity)
  - `check_accent_patterns(arb_fr)` exit 0
  - `check_banned_terms(arb_fr)` exit 0 sur tous les 6 fichiers
- [ ] **PR-C.T4** : Backend integration test
  - `tests/integration/test_anonymous_journey_e2e.py` : POST `/coach/chat` avec `is_anonymous=True` + intent → assert response shape (couches 1-4 présentes), no tool calls, banned-term grep on response
- [ ] **Cross-PR check** : merge PR-A first (deps), then run PR-B against merged PR-A locally
- [ ] **PR-A merged to dev** (review by Claude self + 1 expert agent verdict)

**Files J3 :** 6 ARB files, 1 backend integration test

**Gates J3 :**
- ✅ 3 MCP gates green sur ARB FR
- ✅ Backend integration test green
- ✅ PR-A merged to dev
- ✅ `flutter gen-l10n` 0 warnings
- 📋 `57-VERIFICATION-REPORT.html` ARB sweep row added

---

### J4 (jeudi) — Design panel + iterate

> **Critique : panel-before-push sur les screens redesignés** (`feedback_design_panel_before_push.md`).

- [ ] **Panel mental 4 personas** sur `AnonymousChatScreen` + `AnonymousIntentScreen` + `RegisterScreen`
  - **UX Reviewer** : tap targets ≥44pt, contrast WCAG AA, hierarchy clear, 20s toilet test passed
  - **A11y Reviewer** : VoiceOver/TalkBack labels présents, semantic order respecté, dynamic type tested 100%-200%
  - **Adversarial Reviewer** : que se passe-t-il si network fail mid-stream ? si auth gate cancelled mid-register ? si redirect= forge un path malveillant ? si TTL expire pendant que screen monté ?
  - **Engineering / Wiring Reviewer** : tous les câblages sont-ils end-to-end OU s'arrête-t-on à une façade ? (registry, breadcrumb, sentry, persistence, feature flag, route)
- [ ] Apply critical fixes from panel (bloquant : a11y missing labels, adversarial network-fail crash, wiring façade)
- [ ] **PR-B + PR-C merged to dev** (after panel green)
- [ ] Verdict panel **archived** dans `57-VERIFICATION-REPORT.html` (4 lignes par expert : verdict + critical / non-critical findings)

**Gates J4 :**
- ✅ Panel verdict ARCHIVED (4 personas × verdict)
- ✅ Critical fixes applied + commit pushed
- ✅ PR-B + PR-C merged to dev
- 📋 `57-VERIFICATION-REPORT.html` panel-verdict section completed

---

### J5 (vendredi) — Walker + golden tests

**Track 1 — Walker E2E (PR-D first half) :**

- [ ] **PR-D.T1** : Créer `tools/simulator/walker_first_eclairage_journey.sh` (~200 LOC)
  - Diff line-by-line vs `tools/simulator/walker.sh` (do NOT reconstruct from memory — `feedback_diff_against_existing_tool.md`)
  - Préserver `--no-codesign` flag (provenance xattrs)
  - Préserver `to()` portable wrapper (gtimeout/timeout/bare)
  - Préserver `MINT_WALKER_DRY_RUN=1` short-circuit
  - **Add** : `--archetype=<julien_swiss|lauren_expat_us|fatih_cross_border|sarah_indep_no_lpp>` flag
  - **Add** : 12 capture points horodatés dans `.planning/phases/57-perfect-perimeter-testflight/walker-captures-{archetype}/`
- [ ] **PR-D.T2** : Lancer walker DRY_RUN sur 1 archétype (julien_swiss) — exit 0 attendu

**Track 2 — Golden tests (PR-D second half) :**

- [ ] **PR-D.T3** : Créer `apps/mobile/test/golden/anonymous_first_eclairage_test.dart`
  - 4 baselines : iPhone 16 Pro × FR, iPhone 16 Pro × EN, Pixel 8 × FR, Pixel 8 × EN
  - 3 frames par baseline : (a) Intent picker avec pill sélectionnée, (b) Chat avec 2 messages user + 2 réponses coach, (c) Auth gate bottom sheet
  - Tolerance : 1.5% (existant Phase 6 comparator)
- [ ] Generate golden baselines : `flutter test --update-goldens test/golden/anonymous_first_eclairage_test.dart`
- [ ] Visual review baselines (Julien-eye + adversarial Claude-eye) avant commit

**Files J5 :** `walker_first_eclairage_journey.sh` (NEW), `anonymous_first_eclairage_test.dart` (NEW), 12 golden PNG baselines

**Gates J5 :**
- ✅ Walker DRY_RUN exit 0 sur 1 archétype
- ✅ 12 golden baselines générées + visual reviewed
- 📋 `57-VERIFICATION-REPORT.html` walker + golden sections initialized

---

### J6 (samedi) — Walker green sur 4 archétypes + integration_test

- [ ] **PR-D.T4** : Créer `apps/mobile/integration_test/anonymous_first_eclairage_e2e.dart` (~150 LOC)
  - 4 archetype profiles fixtures (réutiliser `DocumentFactory` patterns Phase 6)
  - Pour chaque archétype : run full parcours Landing→Intent→Chat→AuthGate→back-to-Landing→reload→messages-restored
  - Assertions : `tap-to-first-response < 8s`, `total_journey < 90s`, `0 dead-end`, `messages_persisted`
- [ ] Lancer walker LIVE (pas DRY_RUN) sur 4 archétypes séquentiellement
  - `bash tools/simulator/walker_first_eclairage_journey.sh --archetype=julien_swiss`
  - `bash tools/simulator/walker_first_eclairage_journey.sh --archetype=lauren_expat_us`
  - `bash tools/simulator/walker_first_eclairage_journey.sh --archetype=fatih_cross_border`
  - `bash tools/simulator/walker_first_eclairage_journey.sh --archetype=sarah_indep_no_lpp`
- [ ] Triage tout FAIL : si écran X dead-end sur archétype Y, fix immédiatement (pas reporter)
- [ ] Capture screenshots × 4 archétypes × 12 frames = 48 PNGs dans `.planning/phases/57-.../walker-captures/`

**Files J6 :** `anonymous_first_eclairage_e2e.dart` (NEW), 48 screenshots

**Gates J6 :**
- ✅ Walker exit 0 × 4 archétypes
- ✅ `flutter test integration_test/anonymous_first_eclairage_e2e.dart` green sur sim iOS + Android emulator
- ✅ 0 dead-end observé visuellement sur les 48 captures
- 📋 `57-VERIFICATION-REPORT.html` walker section complete avec liens vers captures

---

### J7 (dimanche) — Pre-push checklist + bump pubspec + PR-D merge

- [ ] **Pre-push checklist mandatory** (`feedback_pre_push_checklist.md`) :
  - (1) Si signature de fonction changée OU schéma OpenAPI modifié OU dispatcher branch ajoutée OU nouvelle ARB key : `grep -rn '<func>('` ALL callers + update
  - (2) Si OpenAPI schema touché : `python3 services/backend/scripts/generate_canonical.py` + commit
  - (3) Si ARB touché : `flutter gen-l10n` + commit
  - (4) Full pytest : `cd services/backend && python3 -m pytest tests/ -q` → 0 fail
  - (5) Full flutter test : `cd apps/mobile && flutter test` → 0 fail
  - (6) `flutter analyze` → 0 errors / 0 warnings
  - (7) MCP gates : `check_banned_terms` + `check_accent_patterns` + `validate_arb_parity` × all touched files
- [ ] **PR-D merge to dev** (Claude self-review + 1 adversarial expert pass)
- [ ] Bump `apps/mobile/pubspec.yaml` : `2.9.0+1` → `2.10.0+1`
- [ ] Update `.planning/MILESTONES.md` : add v2.10.0 « Perfect Perimeter Anonymous » section
- [ ] Tag dev : `git tag v2.10.0-rc1` (release candidate)

**Gates J7 :**
- ✅ Pre-push checklist 7/7 PASS
- ✅ PR-D merged to dev
- ✅ pubspec bumped to 2.10.0+1
- ✅ Tag v2.10.0-rc1 pushed
- 📋 `57-VERIFICATION-REPORT.html` pre-push checklist row 7/7 ✅

---

### J8 (lundi+1) — Staging deploy + smoke

- [ ] Push `dev` → Railway staging auto-deploys backend
- [ ] Run staging smoke : `bash tools/simulator/walker_first_eclairage_journey.sh --staging --archetype=julien_swiss`
  - Asserts : staging URL `mint-staging.up.railway.app` reachable, `/coach/chat` 200 with `is_anonymous=true`, no banned terms in response
- [ ] **Device gate Julien #1** (iPhone 16 Pro) : Julien runs the journey personnally, free-form, while Claude observes via remote breadcrumbs (Sentry replay maskAllText=true honored)
  - Walk : Landing → tap CTA → pick pill → 3 msg → close app → reopen → messages back → tap register → email + password → success → /coach/chat
  - Time budget : 5 min walkthrough
  - Verdict : PASS / FAIL with bug list
- [ ] If FAIL : triage same day, fix, re-deploy staging, re-run device gate

**Gates J8 :**
- ✅ Staging deploy green
- ✅ Staging walker exit 0
- ✅ Device gate Julien iPhone PASS
- 📋 `57-VERIFICATION-REPORT.html` staging + device-gate-iPhone rows

---

### J9 (mardi+1) — Android device gate + TestFlight build trigger

- [ ] **Device gate Julien #2** (Pixel 8 emulator OR physical) : same walk as J8 mais sur Android
  - Verdict PASS / FAIL
- [ ] If both device gates PASS : trigger `.github/workflows/testflight.yml` manually via `gh workflow run testflight.yml`
- [ ] Workflow steps observed : build iOS .ipa, sign, upload to App Store Connect, TestFlight processing (~30 min)
- [ ] If FAIL on iOS build : standard issues = bundle ID drift, provisioning profile expired, Xcode version. Fix, re-run.

**Gates J9 :**
- ✅ Device gate Julien Android PASS
- ✅ TestFlight workflow triggered + build artifact uploaded
- 📋 `57-VERIFICATION-REPORT.html` android-gate + testflight-trigger rows

---

### J10 (mercredi+1) — TestFlight live + close-out

- [ ] Confirm TestFlight build 2.10.0 visible in App Store Connect
- [ ] Internal testing group : Julien installs from TestFlight on real iPhone
- [ ] Final E2E walk on TestFlight build (real network, real Apple sandbox)
- [ ] **Phase 57 close-out panel** (`feedback_post_phase_panel_loop.md`) — 5 experts spawn
  - Roadmap Sequencer : phase 58 target ?
  - Engineering Reviewer : tech debt added vs paid down ?
  - Adversarial : where can a journalist break this ?
  - Coach Intelligence : what's the next moat ?
  - Production Readiness : what's the next TestFlight blocker ?
- [ ] Synthesize verdict → `.planning/decisions/2026-05-{15}-phase-58-target.md`
- [ ] Close PR-D + PRs A, B, C (already merged), tag `v2.10.0`
- [ ] Final `57-VERIFICATION-REPORT.html` ARCHIVED with TestFlight URL + screenshots

**Gates J10 :**
- ✅ TestFlight build 2.10.0 live + installable
- ✅ Real-device walk PASS
- ✅ Phase 58 target decided + archived
- ✅ Tag v2.10.0
- 📋 `57-VERIFICATION-REPORT.html` final ARCHIVED

---

## 6. Verification matrix

### 6.1 Tests

| Layer | Test files | Count | Command |
|---|---|---|---|
| Unit (Flutter) | `test/services/anonymous_chat_persistence_test.dart` | 6 | `flutter test test/services/anonymous_chat_persistence_test.dart` |
| Widget (Flutter) | `test/screens/anonymous/anonymous_chat_screen_persistence_test.dart` | 4 | `flutter test test/screens/anonymous/` |
| Golden (Flutter) | `test/golden/anonymous_first_eclairage_test.dart` | 12 (4 baselines × 3 frames) | `flutter test test/golden/anonymous_first_eclairage_test.dart` |
| Integration (Flutter) | `integration_test/anonymous_first_eclairage_e2e.dart` | 4 (×archetype) | `flutter drive --target=integration_test/anonymous_first_eclairage_e2e.dart` |
| Unit (backend) | `tests/services/coach/test_anonymous_eclairage_prompt.py` | 9 (3×locale) | `pytest tests/services/coach/test_anonymous_eclairage_prompt.py -q` |
| Endpoint (backend) | `tests/test_coach_chat_anonymous.py` | 4 | `pytest tests/test_coach_chat_anonymous.py -q` |
| Integration (backend) | `tests/integration/test_anonymous_journey_e2e.py` | 3 | `pytest tests/integration/test_anonymous_journey_e2e.py -q` |
| **Total nouveaux tests** | | **42** | |

### 6.2 Walker E2E

| Archétype | Profile | Path | Expected outcome |
|---|---|---|---|
| `julien_swiss` | Swiss native, 32, GE, employed CHF 7'500/mo | firstJob/optimization | First éclairage parle de 3a déductible canton GE, ban « retraite » |
| `lauren_expat_us` | US expat, 28, ZH, FATCA flagged | foreign-pension/tax | First éclairage parle de FATCA implications + 3a éligibilité, ban « retraite » |
| `fatih_cross_border` | Frontalier FR, 41, GE, employed FR | cross-border-tax | First éclairage parle de quasi-résident statut + accord double-imposition CH-FR |
| `sarah_indep_no_lpp` | Indépendante, 36, VD, no LPP | self-employed/3a | First éclairage parle de 3a-grand (CHF 36'288 plafond 2026) + LPP volontaire |

Walker pour chaque archétype : 12 capture points = Landing / Intent picker / Pill selected / Free-text typed / First message sent / First response streaming / First response complete / Second message sent / Second response / Auth gate / Postpone tapped / Reload-restore.

### 6.3 Panel-before-push design verdict (mandatory archive)

| Persona | Critères | Verdict cible | Archive |
|---|---|---|---|
| UX Reviewer | tap targets ≥44pt, contrast WCAG AA, hierarchy, 20s toilet test | PASS | `57-VERIFICATION-REPORT.html` §panel.ux |
| A11y Reviewer | VoiceOver/TalkBack labels, semantic order, dynamic type 100-200% | PASS | `57-VERIFICATION-REPORT.html` §panel.a11y |
| Adversarial Reviewer | network fail, auth cancel, redirect forge, TTL race | PASS w/ mitigations | `57-VERIFICATION-REPORT.html` §panel.adversarial |
| Engineering/Wiring | breadcrumb, sentry, persistence, feature flag, route, no façade | PASS | `57-VERIFICATION-REPORT.html` §panel.engineering |

### 6.4 Pre-push checklist (J7 J9)

| # | Step | Trigger | Command |
|---|---|---|---|
| 1 | grep callers | function/schema/dispatcher changed | `grep -rn '<func>(' apps/mobile/lib services/backend/app` |
| 2 | regen canonical | OpenAPI changed | `python3 services/backend/scripts/generate_canonical.py` |
| 3 | gen ARB | new ARB key | `flutter gen-l10n` |
| 4 | full pytest | always | `cd services/backend && python3 -m pytest tests/ -q` |
| 5 | full flutter test | always | `cd apps/mobile && flutter test` |
| 6 | flutter analyze | always | `cd apps/mobile && flutter analyze` |
| 7 | MCP gates | always | `check_banned_terms` + `check_accent_patterns` + `validate_arb_parity` |

### 6.5 MCP gates (CLAUDE.md mandatory)

```bash
# Sur tous les ARB FR + system prompts FR
mcp check_banned_terms       → exit 0 (0 banned LSFin terms)
mcp check_accent_patterns    → exit 0 (0 accent ASCII drift)
mcp validate_arb_parity      → exit 0 (6 ARB parity)
mcp get_swiss_constants      → optional, used in tests fixtures
```

---

## 7. Risques + mitigations (top 5)

| # | Risque | Probabilité | Impact | Mitigation |
|---|---|---|---|---|
| **R1** | Backend rate-limit 5 req/IP/15min trop strict → TestFlight reviewers Apple bloqués | Médium | High (rejet TestFlight review) | Allowlist Apple test IPs `17.0.0.0/8` dans middleware ; bypass rate-limit si `User-Agent` matches `TestFlight*`. Tested in pytest |
| **R2** | Anonymous SharedPreferences pas chiffré → si device compromis, leak des questions financières du visiteur | Médium | Médium (pas de PII strict, mais informations sensibles) | TTL court (7j), clear-on-register agressif, no AVS no IBAN no email saved. Documented in privacy policy section. nLPD audit Phase 29 templates réutilisés |
| **R3** | First response coach >8s sur archétype `lauren_expat_us` (FATCA prompt complexity) → user abandonne | Médium | High (conversion kill) | Streaming TTFT <1.5s mandatory ; if backend latency > 3s p95, fall back to Haiku (Phase 27 LLMRouter pattern). Walker mesure et FAIL si >8s |
| **R4** | Apple TestFlight review rejette pour « anonymous flow without privacy disclosure » | Low | High (block 7-14j) | Privacy nutrition label updated (Phase 29 templates) + visible `mint://privacy` link in anonymous chat screen header. nLPD ART. 5/6/7/9/12 mapping in App Store Connect form |
| **R5** | Golden tests fail-flake sur 2nd CI run (font rendering différent macOS Linux) | High | Médium (CI red, perte velocity) | Use `flutter_test` `goldenFileComparator` with 1.5% tolerance (existant Phase 6) ; CI Linux uniquement pour golden (pas dual-OS) ; baseline regen quarterly |

---

## 8. Definition of Done (checklist mécanique TestFlight 2.10.0)

> Aucun item « subjectif ». Tout est mécaniquement vérifiable.

### 8.1 Code

- [ ] PR-A merged to dev (J3)
- [ ] PR-B merged to dev (J4)
- [ ] PR-C merged to dev (J4)
- [ ] PR-D merged to dev (J7)
- [ ] `apps/mobile/pubspec.yaml` version = `2.10.0+1`
- [ ] Tag `v2.10.0-rc1` push to origin
- [ ] Branche `feat/phase-57-perfect-perimeter` deletable (squash-merged)

### 8.2 Tests

- [ ] 42 nouveaux tests green (6 unit + 4 widget + 12 golden + 4 integration mobile + 9 unit backend + 4 endpoint backend + 3 integration backend)
- [ ] `flutter test` ALL green (current ~13'040 + 42 = ~13'082)
- [ ] `pytest -q` ALL green (current ~5'958 + 16 = ~5'974)
- [ ] `flutter analyze` 0 errors 0 warnings
- [ ] `ruff check services/backend` 0 errors

### 8.3 Walker E2E

- [ ] `walker_first_eclairage_journey.sh --archetype=julien_swiss` exit 0
- [ ] `walker_first_eclairage_journey.sh --archetype=lauren_expat_us` exit 0
- [ ] `walker_first_eclairage_journey.sh --archetype=fatih_cross_border` exit 0
- [ ] `walker_first_eclairage_journey.sh --archetype=sarah_indep_no_lpp` exit 0
- [ ] 48 screenshots (4 archetype × 12 frames) committed
- [ ] `tap-to-first-response < 8s` mesuré sur 4 archétypes
- [ ] `total_journey < 90s` mesuré sur 4 archétypes

### 8.4 Compliance

- [ ] MCP `check_banned_terms` exit 0 sur `app_fr.arb` + 3 system prompts (FR/EN/DE)
- [ ] MCP `check_accent_patterns` exit 0 sur `app_fr.arb`
- [ ] MCP `validate_arb_parity` exit 0 (6 ARB synchronized)
- [ ] No `Text('...')` hardcoded user-facing in modified files (`grep -E "Text\('[^']*[a-zA-Z]" apps/mobile/lib/screens/anonymous/`)
- [ ] No `Color(0x*)` hardcoded in modified files
- [ ] Privacy nutrition label updated in App Store Connect (anonymous SharedPreferences disclosed)

### 8.5 Panel-before-push

- [ ] 4 personas verdict ARCHIVED dans `57-VERIFICATION-REPORT.html`
- [ ] All critical findings addressed before merge

### 8.6 Device gates

- [ ] Julien iPhone 16 Pro device gate PASS (J8)
- [ ] Julien Android (Pixel 8) device gate PASS (J9)

### 8.7 TestFlight

- [ ] Build `2.10.0+1` visible in App Store Connect
- [ ] Build status = `Ready to Submit` ou `Ready for Test`
- [ ] Build installable on real iPhone via TestFlight app
- [ ] Real-device E2E walk PASS (J10)

### 8.8 Documentation

- [ ] `57-VERIFICATION-REPORT.html` ARCHIVED with all sections complete
- [ ] `MILESTONES.md` updated with v2.10.0 entry
- [ ] `STATE.md` updated with phase 57 status: `shipped`
- [ ] Phase 58 target decision archived to `.planning/decisions/2026-05-{15}-phase-58-target.md`
- [ ] Cumulative session report `SESSION-2026-05-{15}.html` rolls up Phase 57

### 8.9 Git hygiene

- [ ] Repo public discipline respected (no legal-admission language in commits/PRs/docs)
- [ ] No `--no-verify` skip on hooks
- [ ] No force-push on main / dev
- [ ] Co-Authored-By trailer present on all commits

---

## 9. Backlog explicite (NOT in Phase 57)

> Ces items sont consciemment EXCLUS du périmètre. Documenté pour résister aux scope-creep tentations.

### 9.1 Issues nav-audit déférées

- **P3 nav-audit** : Document scan auth-gate `?redirect=` (séparé de notre PERIM-57-04 qui ne couvre QUE l'anonymous chat path) → Phase 58
- **P4 nav-audit** : Document scan extraction persistence in `ReportPersistenceService` → Phase 58
- **P5 nav-audit** : 9 references-zombie + 26 DUPLICATE-INTENT-SHIM cleanup → Phase 58
- **P6 nav-audit** : Onboarding system-back hardware verification → Phase 58 walker E2E
- **P7 nav-audit** : Multi-push back-stack from RouteSuggestionCard targets → Phase 58 walker E2E

### 9.2 FIXes deferred

- **FIX-03** : `save_fact backend↔Flutter unsync` (`responseMeta.profileInvalidated` missing) → Phase 58 (post-anonymous-funnel)
- **FIX-04** : Coach tab routing stale → Phase 58
- **FIX-couple** : Couple mode façade (calculs financial_core jamais wirés UI) → v2.11+ ou Phase 36

### 9.3 v2.8 phase 36 work

- 388 bare catches → 0 (Phase 36 Finissage E2E, non-empruntable, 2-3 sem)
- 4 P0 kill flags actually wired in production

### 9.4 Demandes implicites Julien EXCLUES (justification)

- **Wiki coach** : explicitement out-of-scope par l'orchestrateur. Un wiki n'est ni de la lucidité (lecture passive) ni un funnel (pas de conversion). Risque scope-creep majeur. Si revisité : v2.12+
- **Coach chat redesign** : hors funnel premier-touch. Le user est déjà inscrit ; sa retention dépend du Phase 1 (Le Conversationnel) déjà SHIPPED. Pas un blocker TestFlight 2.10.0
- **AUDIT_TAP_RENDER 56 rows** : audit complet 3 tabs + drawer. Walker Phase 57 cible UNIQUEMENT le journey 57. Audit complet attendra Phase 36 ou un Sprint dédié
- **Bank API + LPP API integrations (Cleo-style)** : roadmap v3.0+. Non-shippable en 7-10j

### 9.5 Pourquoi cette discipline

Si on essaie de tout shipper, on shippe rien de parfait. Le scope serré Phase 57 garantit que **UN parcours** sera le proof-of-product le 2026-05-15 (J10). Tout le reste est légitimement urgent mais relevé après. Le close-out panel J10 décidera Phase 58 target sur la base des verdicts experts, pas d'une liste TODO arbitraire.

---

## 10. Methodologie + sources

**Inputs canoniques lus avant planning :**
1. `docs/MINT_IDENTITY.md` (mission, principes, toilet test, couches 1-4)
2. `SOT.md` (Profile schema, EnhancedConfidence, ProfileDataSource)
3. `docs/ROADMAP_V2.md` (Phase 1 SHIPPED, Phase 2 SHIPPED, monétisation, KPIs, North Star)
4. `.planning/MILESTONES.md` (v2.7/v2.8 close-outs, carryover STAB-17)
5. `.planning/STATE.md` (v2.8 progress, decisions, blockers, foundations)
6. `.planning/audits/2026-05-05-nav-audit-gaps.md` (5 dead-ends Pareto, /dossier 404, anonymous 3-msg lock, ?redirect= missing)
7. `.planning/phases/55-nav-audit/55-NAV-AUDIT-REPORT.html` (Pareto plan + verification log)
8. `.planning/decisions/2026-05-04-phase-54-target.md` (sequencing principles)
9. `CLAUDE.md` (5 rules critiques, 10 NEVER triplets, MCP tools)

**Méthodologie :** Product Leader autonomous mode (`feedback_post_phase_panel_loop.md`). Panel mental 5-candidats journey scorés sur 5 critères, A retenu, scope serré 7-10j. Pas de scope-creep. Pas de pause pour direction Julien tant qu'aucun blocker genuine. Device gates Julien planifiés J8 + J9 (workflow attendu).

**Discipline :**
- Repo public : no legal-admission language (`feedback_public_repo_discipline.md`)
- Pre-push checklist mandatory J7 + J9 (`feedback_pre_push_checklist.md`)
- Panel-before-push design J4 (`feedback_design_panel_before_push.md`)
- HTML evidence report `57-VERIFICATION-REPORT.html` cumulative (`feedback_html_evidence_report.md`)
- Diff against existing tool when porting walker (`feedback_diff_against_existing_tool.md`)
- App targets staging always (`feedback_app_targets_staging_always.md`) — pas de local backend pour E2E

---

## 11. Phase close-out trigger

Quand DoD §8 100% green :
1. Spawn 5-expert close-out panel (Roadmap Sequencer, Engineering Reviewer, Adversarial, Coach Intelligence, Production Readiness)
2. Synthesize Phase 58 target → `.planning/decisions/2026-05-15-phase-58-target.md`
3. Tag `v2.10.0`, archive Phase 57
4. Open Phase 58 GSD plan, execute, repeat (`feedback_post_phase_panel_loop.md`)

**Loop only stops when MINT is journalist-defensible AND TestFlight users are converting >X% from anonymous → register.**
