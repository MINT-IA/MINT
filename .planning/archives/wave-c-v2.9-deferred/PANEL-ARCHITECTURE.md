# PANEL ARCHITECTURE — Wave C pre-exec review

**Panel**: Staff Engineer Stripe + Flutter Google mobile architect + fintech mobile lead
**Date**: 2026-04-18
**Base**: dev f35ec8ff (post Wave E-PRIME)
**Cible auditée**: `.planning/wave-c-scan-handoff/PLAN.md`

---

## VERDICT

**PROCEED WITH MODIFICATIONS** — et les modifs ne sont pas cosmétiques.

Le PLAN a le bon instinct produit (scan -> conversation = bonne direction) mais
il est rédigé par-dessus un code qui n'a pas été relu. Trois des cinq commits
ciblent des mécanismes qui n'existent pas sous les noms cités ou qui ont été
supprimés en Wave E-PRIME. Deux commits sur cinq risquent un scope drift :
C1 ressemble à du câblage mais empile un deuxième mécanisme de transfert de
contexte à côté d'un qui fonctionne déjà (doctrine façade). C4 propose un
redirect router async qui va créer un flash landing->home chez l'utilisateur
réel si écrit comme dans le PLAN.

**Ce qui est sain** :
- C2 identifie une vraie lacune (regex chip tronquée à 6 familles).
- C3 pointe une robustesse acceptable à améliorer (mais pas là où le PLAN le dit).
- C5 (ADR no-onboarding) est la bonne décision doctrinale.

**Ce qui doit changer avant exec** :
- C1 doit passer par le mécanisme existant (`ScreenCompletionTracker` +
  `entryPayload` via query param), PAS via `extra:` (silencieusement ignoré
  par le router — cf. preuve §Risque #1).
- C3 doit cibler le bon service (`fetchMemoryBlock` n'existe pas — l'IO
  réseau du memory est `_syncToBackend` fire-and-forget, qui n'a pas de
  timeout à rallonger).
- C4 doit choisir entre redirect router sync (impossible car
  SharedPreferences est async) ou splash guard dans `LandingScreen`
  (existant, mais verrouillé par CI no-imports).

---

## TOP 3 RISQUES

### Risque #1 — C1 `extra: CoachEntryPayload(...)` serait silencieusement ignoré

**Fichier** : `apps/mobile/lib/app.dart:366-386` (route `/coach/chat` builder)

**Preuve** :
```dart
ScopedGoRoute(
  path: '/coach/chat',
  scope: RouteScope.public,
  builder: (context, state) {
    final topic = state.uri.queryParameters['topic'];
    final conversationId = state.uri.queryParameters['conversationId'];
    final CoachEntryPayload? entryPayload = topic != null
        ? CoachEntryPayload(source: CoachEntrySource.direct, topic: topic)
        : null;
    return CoachChatScreen(entryPayload: entryPayload, ...);
  },
),
```

Le builder ne lit JAMAIS `state.extra`. Il re-construit un
`CoachEntryPayload` depuis `queryParameters['topic']` seulement, et force
`source: CoachEntrySource.direct`. Le PLAN propose :
```
context.go('/coach/chat', extra: CoachEntryPayload(source: scanResult, topic: 'scan_<doc_type>'))
```
=> l'`extra` est dropé par le builder, `source` reste `direct`, et
`CoachEntrySource.scanInsight` (qui existe DÉJÀ dans l'enum —
`coach_entry_payload.dart:44`) n'est jamais atteint. L'opener contextuel
demandé par le PLAN ne s'affiche JAMAIS. Façade classique.

**Impact** : C1 livré = 0 effet observable utilisateur. Tests PASS (car ils
testent la couche mockée). Device walkthrough : "Continuer" renommé en
"En parler à Mint", tap, coach rend son greeting générique, PII persisted
via `saveEvent` (déjà fait depuis Wave A A1), mais ZÉRO opener scan-aware.

**Remédiation** — deux options valables, choisir :

*Option A (recommandée, minimale)* : utiliser le chemin `ScreenCompletionTracker` DÉJÀ CÂBLÉ.
- `document_impact_screen.dart:709-720` appelle déjà
  `ScreenCompletionTracker.markCompletedWithReturn('document_scan', ScreenReturn.completed(...))`.
- `coach_chat_screen.dart:400-413` subscribe déjà à ce stream et injecte un
  `_entryPayloadContext` ("L'utilisateur vient de terminer une simulation...").
- Modif réelle = enrichir le `ScreenReturn.updatedFields` + écrire un
  opener contextuel dédié dans le handler `_subscribeToScreenReturns`
  quand `route == '/scan/impact'`. Aucune nouvelle plomberie.
- Bénef : un seul chemin canonique, zéro risque de consommation double.

*Option B (si on veut vraiment une source enum propre)* : router reads
`state.extra as CoachEntryPayload?` et fallback sur le topic query param.
Commit + test dédié. Change le contrat de la route publique (deep links
ne peuvent pas passer d'extra, donc contrat asymétrique — acceptable
mais à documenter).

---

### Risque #2 — C3 cible un service qui ne fait pas d'IO réseau

**Fichier** : `apps/mobile/lib/services/memory/coach_memory_service.dart`

**Preuve** : le service n'a AUCUN timeout. Zéro occurrence de `timeout`,
`retry`, `TimeoutException` dans tout le fichier (grep vérifié). La méthode
citée par le PLAN, `fetchMemoryBlock()`, **n'existe pas** (le PLAN lui-même
met "(ou nom similaire)" — c'est un drapeau rouge pré-exec).

Ce qui existe :
- `saveInsight(...)` → `_syncToBackend(...)` fire-and-forget HTTP POST,
  fallback silent (debugPrint). Pas de timeout explicite, utilise le
  default `http.Client()` qui n'en a pas.
- `getInsights(...)` / `getInsightsForTopic(...)` → lectures
  SharedPreferences pures, pas d'IO réseau, retry inutile.
- `saveEvent(...)` → idem, écriture locale, pas de réseau.

**Impact** : Si C3 livre un "retry 1× back-off 500ms" sur
`saveInsight._syncToBackend`, ça ajoute un délai de 500ms au path heureux
qui échoue silencieusement de toute façon. Zéro observabilité gagnée,
latence perçue dégradée.

**Remédiation** — le vrai trou de robustesse est ailleurs :
1. Ajouter un timeout explicite (5-8s) sur le `http.post` de
   `_syncToBackend` — sans timeout, une connection stuck peut garder le
   `Future` pendu indéfiniment et allonger le tracking post-exit.
2. Logger un Sentry breadcrumb quand le POST échoue (actuellement
   `debugPrint` seulement — invisible en TestFlight/prod).
3. PAS de retry : `saveInsight` est appelé en rafale par le coach, un
   retry amplifie le bruit réseau et ne corrige rien (le fact est déjà
   persisté localement).

Si le PLAN visait `saveEvent` (plus récent, Wave A-MINIMAL), même
conclusion : events sont local-only en v1 par décision panel archi AJ-2
(cf. `coach_memory_service.dart:202-209`). Pas de réseau à retry.

---

### Risque #3 — C4 router redirect async = flash landing->home

**Fichier** : `apps/mobile/lib/app.dart:171-261` (GoRouter + redirect)

**Preuve** :
- `initialLocation: '/'` (pas `/landing` comme le PLAN l'affirme — le path
  est `/`, vérifié `apps/mobile/lib/app.dart:264-268`).
- Le redirect est `FutureOr<String?>`, mais `GoRouter` n'await pas un
  `Future` non résolu pour le synchrone — il bounce vers la cible, puis
  re-bounce quand le `refreshListenable` tick.
- `isMiniOnboardingCompleted()` (`report_persistence_service.dart:81-84`)
  est `Future<bool>` car `SharedPreferences.getInstance()` est async.
- L'équivalent du flag existant vit dans `CoachProfileProvider` (l.385) et
  dans `ReportPersistenceService` (l.54). Le PLAN cite
  `CoachProfileProvider.isOnboarded` : ce getter n'existe pas (grep
  confirme 0 match sur `isOnboarded`). Le provider a `hasProfile` et
  consomme `isMiniOnboardingCompleted` à l.385 pour un autre usage.

**Impact** : si écrit comme dans le PLAN ("Router lit
`CoachProfileProvider.isOnboarded`. Si true → `initialLocation: '/home'`"),
deux bugs utilisateurs :
1. Flash landing visible 200-400ms avant que le provider charge, puis
   redirect — inacceptable pour un écran "calm promise surface".
2. Cold-start avec network slow : le `CoachProfileProvider` ne garantit
   pas d'avoir fini `loadProfile()` au premier rebuild du router.

**Remédiation**:
*Option A (correcte)* : utiliser un splash `FutureBuilder` dans
`LandingScreen` avant l'animation `_controller.forward()` :
```dart
Future<void> _checkOnboarded() async {
  final done = await ReportPersistenceService.isMiniOnboardingCompleted();
  if (done && mounted) context.go('/coach/chat');
  else _controller.forward();
}
```
MAIS — blocage CI: `landing_screen.dart:1-9` a une invariant explicite
"No services/providers/models imports". Il faut un ADR pour l'assouplir
OU placer le check dans un wrapper autour de `LandingScreen` dans le
builder de `/`.

*Option B (plus propre)* : Le builder de `/` devient un
`FutureBuilder<bool>` qui `return LandingScreen() | return
CoachChatRedirect()`. LandingScreen garde son invariant intact.

*Option C (défausse acceptable)* : **descoper C4 de Wave C**. L'UX
"landing re-wordmarkée à chaque cold-start onboarded" est un papercut,
pas un P0. Le coût d'implémentation correct dépasse le budget 30min du
PLAN ; faire un ADR Wave D séparé.

---

## RECOMMANDATIONS PAR COMMIT

### C1 — Post-scan auto-handoff coach

**Verdict commit** : REWORK — la direction est bonne, le chemin est faux.

**À faire** :
1. Abandonner le `extra: CoachEntryPayload(...)`. Le router ne le lit pas
   (Risque #1).
2. Utiliser le stream `ScreenCompletionTracker` déjà câblé. Le scan emet
   déjà un `ScreenReturn.completed(route: '/scan/impact', updatedFields:
   {scannedDocument, confidenceDelta, newConfidence})` — il suffit
   d'enrichir `updatedFields` avec les 2-3 champs utiles (ex.
   `caisse`, `bucket_avoir`) et de modifier `_subscribeToScreenReturns`
   dans `coach_chat_screen.dart:400-413` pour produire un opener
   contextuel dédié quand `route == '/scan/impact'` au lieu du
   `contextLine` générique actuel.
3. Renommer le CTA "Continuer"/"Retourner au tableau de bord" existant
   en "En parler à Mint" via nouvelles clés ARB 6 langs — OK conforme
   PLAN mais attention : il existe DÉJÀ un *deuxième* CTA en dessous
   (`_buildCoachCta`) qui fait LITTÉRALEMENT la même action
   (`context.go('/coach/chat')`, `document_impact_screen.dart:760-786`).
   **Fusionner les deux CTA** avant d'en renommer un seul, sinon on se
   retrouve avec deux boutons qui font la même chose. Panel UX.
4. Opener contextuel : respecter doctrine chat-silent. Ton conditionnel
   ("Tu viens de scanner ton certificat CPE, je l'ai lu. Tu veux
   comprendre ce que ça change ?") + option "Pas maintenant" dans les
   chips. Pas de "Voici ce que ça change pour toi" affirmatif —
   anti-silent.

**Tests à ajouter** :
- Widget test : tap CTA sur `DocumentImpactScreen` emet bien un
  `ScreenReturn` avec les champs enrichis.
- Widget test : `CoachChatScreen` consomme le stream et renomme
  `_entryPayloadContext` avec le contenu scan-aware (golden string).
- Integration : cold-start vide → scan mock → CTA tap → coach rendu
  avec opener scan-aware visible à l'œil (pumpAndSettle + find.textContaining).

---

### C2 — Suggestion-chip regex étendu 18 life events

**Verdict commit** : REWORK — le PLAN confond deux mécanismes.

**Cibles réelles** dans `coach_chat_screen.dart` :
- `_inferSuggestedActions(...)` (l.1417-1452) : a 6 familles regex
  (3a, LPP, retraite, impôt, budget, immobilier). ZÉRO life event actuel.
- `_routeForAction(...)` (l.1477-1523) : 7 labels mappés vers routes
  + 7 substring fallbacks. ZÉRO life event.
- `_extractRouteChips(...)` (l.1460-1475) : **ne contient pas de regex**
  — extrait juste `context_message` des tool calls. Le PLAN se trompe
  d'endroit (cf. §"État actuel" C2 PLAN qui cite ce mec spécifique).

**À faire** :
1. Étendre `_inferSuggestedActions` avec 6 nouveaux matchers :
   divorce, mariage, naissance, perte emploi, invalidité, déménagement
   canton/pays. (12 life events du CLAUDE.md §Life Events moins ceux
   qui mapent sur existants : firstJob/newJob/selfEmployment ~ emploi,
   retirement ~ retraite déjà couvert, housingPurchase/housingSale ~
   immobilier déjà couvert, death/donation/inheritance ~ succession
   à ajouter).
2. Ajouter les 6 labels ARB correspondants (x6 langs).
3. Ajouter le mapping `_routeForAction` ou un mapping dédié vers les
   intent tags existants (`life_event_divorce`, `life_event_marriage`,
   `life_event_birth`, `life_event_job_loss`, `disability_gap`,
   `life_event_canton_move`, `life_event_country_move`).

**Attention P1 confirmé** : `ROUTE_TO_SCREEN_INTENT_TAGS` backend
(`coach_tools.py:108-133`) a `life_event_unemployment`. Flutter
`ScreenRegistry` (recensement grep ci-dessus) a `life_event_job_loss`.
**Drift confirmé**. Le PLAN le liste en "hors scope / Wave E main" —
OK tant que C2 ne référence pas ce tag orphelin. Vérifier au commit
que la liste ajoutée est alignée sur les intent tags *côté Flutter*
(pas backend), sinon la chip tappée résout `null` via
`resolveRouteFromIntent` (`chat_tool_dispatcher.dart:109-117`).

**Tests à ajouter** :
- Unit test par life event : `_inferSuggestedActions("j'ai divorcé", "...")`
  retourne le label FR attendu.
- Test mapping intent: tapper chip "Je viens de divorcer" ouvre
  `/divorce-simulator` (intent `life_event_divorce` → route via registry).
- Test neutralité doctrine : aucune chip "perte emploi" ne déclenche
  scope retraite (anti-retirement-framing CLAUDE.md §9.16).

---

### C3 — Memory retry back-off

**Verdict commit** : REWORK CIBLE — le problème est réel mais pas là où le PLAN dit.

**À faire** :
1. Supprimer la proposition "retry 1× back-off 500ms" — techniquement
   malsaine sur un fire-and-forget local (Risque #2).
2. Ajouter un `timeout(Duration(seconds: 5))` au `http.post` de
   `_syncToBackend` dans `coach_memory_service.dart:126-140`. Sans ça,
   un socket stuck peut garder le Future pendu.
3. Idem pour `_syncRemoveToBackend` l.156-159.
4. Remplacer le `debugPrint` par un appel à Sentry `addBreadcrumb`
   (ou équivalent analytics logger déjà en place — `analytics_service.dart`
   a `trackEvent`) pour visibilité TestFlight/prod.

**Tests à ajouter** :
- Unit test : `_syncToBackend` avec `MockClient` qui pend 10s ne bloque
  pas `saveInsight` au-delà de 5s.
- Unit test : breadcrumb Sentry émis sur échec (mock Sentry client).

---

### C4 — Landing skip si onboarded

**Verdict commit** : REWORK ARCHITECTURE OU DESCOPE.

**À faire** — choisir UNE option, pas mélanger :
- Option A : Wrapper builder `/` autour de `LandingScreen` avec
  `FutureBuilder<bool>` sur `ReportPersistenceService.isMiniOnboardingCompleted()`.
  Pendant load → splash écran identique `MintColors.warmWhite` (zéro flash
  visible). Complété=true → `context.go('/coach/chat')` via
  `addPostFrameCallback` pour éviter le rebuild-during-build. LandingScreen
  reste intact, invariant CI respecté.
- Option B : **DESCOPE Wave C**. Écrire un ADR ou TODO dans `.planning/`
  et traiter en Wave D après qu'un vrai utilisateur se plaint. L'UX
  "landing s'affiche 3s puis CTA vers /coach/chat" n'est pas bloquant.

**Rejeter** : la version PLAN "Router lit `CoachProfileProvider.isOnboarded`
(ou équivalent)" — ce getter n'existe pas, et le router async + flash
landing sont des anti-patterns UX.

**Tests à ajouter (si option A retenue)** :
- Widget test cold-start : SharedPreferences mock avec
  `mini_onboarding_completed=true` → ne voit jamais LandingScreen
  (`find.byType(LandingScreen), findsNothing` après `pumpAndSettle`).
- Widget test cold-start fresh : SharedPreferences vide → LandingScreen
  rendu, animation joue.
- Race test : provider met 200ms à charger, s'assurer du splash pendant
  l'attente (pas de flash blanc ni wordmark visible).

---

### C5 — ADR no-formal-onboarding

**Verdict commit** : PROCEED AS-IS — c'est la bonne décision.

**Recommandations rédaction** :
1. Titre proposé par le PLAN `ADR-20260419-no-formal-onboarding.md` — OK.
2. Ajouter section "Décision récente liée" pointant vers :
   - `decisions/ADR-20260419-killed-gamification-layers.md` (même famille)
   - Doctrine `feedback_chat_must_be_silent.md` (user memory)
   - Wave B-minimal PR #354 (CapDuJourBanner sans widget intrusif) —
     preuve que le chat peut porter la capture sans onboarding explicite.
3. Section "Alternatives rejetées" : inclure l'option "1-question gate
   (ex. canton uniquement)" et expliquer pourquoi même ça est trop —
   save_fact triad via chat a déjà la structure.
4. **NE PAS** promettre que le chat capture toujours correctement la triad
   — c'est un risque connu. Ajouter section "Risques acceptés" :
   conversations qui ne convergent pas sur birthYear/canton/salary dans
   les 15 premiers tours restent à 0% onboarding complete. Métrique à
   suivre = `analytics.kEventOnboardingCompleted` rate sur 30j.

**Pas de tests** (ADR uniquement) — OK conforme PLAN.

---

## TESTS ADDITIONNELS TRANSVERSES

Couverture proposée par le PLAN (tests pour C1/C2/C3) insuffisante sur :

1. **Path critique PII scan** — `document_impact_screen._persistScanEvent`
   appelle `CoachMemoryService.saveEvent` qui écrit un summary bucketizé
   à 10k CHF. Test manquant : scan avec valeur `69'999` → bucket
   `~70'000 CHF` (arrondi, pas de leak PII). Golden existant ne couvre
   pas les bordures.

2. **Race `setState` post-scan** — le fix A2-fix 2026-04-18
   (cf. `document_impact_screen.dart:97-125`) persist l'event AVANT le
   `mounted` check. Test manquant : unmount pendant `_fetchPremierEclairage`
   → event persisté quand même, pas de StateError.

3. **Contrat screen_return** — `ScreenReturn.updatedFields` est
   `Map<String, dynamic>?`. Si Wave C enrichit le map avec des objets
   non sérialisables, `_writeReturn` (`screen_completion_tracker.dart:225-257`)
   crash en `jsonEncode`. Test manquant : enrichir updatedFields avec
   des primitives uniquement, type-assert dans un test dédié.

4. **Consommation double `_entryPayloadContext`** — la string est mise à
   `null` après première consommation (l.783 "one-shot: clear after first
   use"). Si Wave C empile ScreenReturn stream + entryPayload query param,
   test d'ordre : lequel gagne ? Documenter le contrat (pas le découvrir
   en device walkthrough).

5. **Device walkthrough non-mockable** — Wave A a shipé 4 PR sans que le
   device walkthrough attrape le ProxyProvider lazy (panel A2-fix).
   Gate de sortie doit inclure : scan réel iPhone 17 Pro → event visible
   dans `CoachMemoryService.debugGetEvents` via un hook debug + opener
   contextuel rendu en FR/DE/IT minimum.

---

## SCOPE DRIFT — À SURVEILLER

| Commit | Scope drift détecté | Gravité |
|---|---|---|
| C1 | Propose "ajouter source `scanResult` enum" alors que `CoachEntrySource.scanInsight` existe déjà (coach_entry_payload.dart:44). Re-ajouter = dette nominale. | Mineur — renommer dans le PLAN |
| C1 | Propose "CapCoachBridge existant" qui n'existe PAS (grep confirme 0 match). Pas de drift d'ajout mais PLAN basé sur fiction. | Majeur — rééditer PLAN |
| C1 | Un second CTA `_buildCoachCta` fait déjà `context.go('/coach/chat')`. Renommer seulement le premier = UX 2-CTA identiques. | Majeur — fusion à décider |
| C2 | PLAN cible `_extractRouteChips` (faux endroit). Le vrai lieu est `_inferSuggestedActions`. Scope ne drift pas, mais l'exec risque de modifier le mauvais fichier. | Majeur — rééditer cible |
| C3 | Propose retry sur méthode inexistante. Si exec suit PLAN, on ajoute retry sur un appel local SharedPreferences = débilité. | Bloquant — rééditer PLAN |
| C4 | Propose lecture `CoachProfileProvider.isOnboarded` inexistant. Le flag réel est `ReportPersistenceService.isMiniOnboardingCompleted()`. | Majeur — corriger cible |
| C5 | ADR = bonne scope. RAS. | OK |

---

## ORDRE D'EXÉCUTION RECOMMANDÉ (révisé)

1. **C5** d'abord (ADR uniquement — débloque la doctrine, zéro risque).
2. **C2** avec cible corrigée (`_inferSuggestedActions` + `_routeForAction`).
   Isolé, testable unitairement, PR autonome.
3. **C3** avec cible corrigée (`timeout + breadcrumb` sur
   `_syncToBackend`). Isolé.
4. **C1** après rework (Option A : enrichir
   `ScreenCompletionTracker._subscribeToScreenReturns`). Fusionner les
   2 CTA du document_impact_screen en passant.
5. **C4** — descope proposé sauf exigence explicite fondateur. Si exigé :
   Option A uniquement, jamais la version PLAN actuelle.

---

## GATES DE SORTIE (révisés)

En plus des gates du PLAN, ajouter :

- [ ] **Pas de façade** : `CoachEntrySource.scanInsight` doit avoir au
      moins un call site de production après Wave C (sinon le fix C1 est
      mort — doctrine `feedback_facade_sans_cablage_absolu.md`).
- [ ] **1 opener contextuel testé sur device** : scan réel → opener
      visible différent du silent opener par défaut, sur au moins 2
      locales (FR + DE).
- [ ] **Pas de regression ARB** : ajout des 6 life event labels C2
      parité 6 langs + `flutter gen-l10n` clean.
- [ ] **Pas d'IO fire-and-forget muet** : après C3, le POST échoué
      `_syncToBackend` génère un event analytics observable (pas
      seulement debugPrint).
- [ ] **Deux CTA document_impact_screen** : fusionnés en UN seul OU
      différenciés explicitement (action vs. renvoi neutre) — panel
      UX confirme à la review PR.

---

## SIGNATURE PANEL

Panel Architecture — audit sources validées :
- `apps/mobile/lib/screens/document_scan/document_impact_screen.dart` (931 lignes — CTA L.690-740, coach CTA L.760-786, scan event persist L.127-151)
- `apps/mobile/lib/screens/coach/coach_chat_screen.dart` (L.300-376 didChangeDependencies, L.400-413 stream sub, L.1417-1523 chip inference, L.781-783 one-shot consume)
- `apps/mobile/lib/models/coach_entry_payload.dart` (intégral — `scanInsight` source L.44 existe)
- `apps/mobile/lib/services/memory/coach_memory_service.dart` (intégral — 0 timeout/retry, 0 fetchMemoryBlock, saveEvent L.214-261)
- `apps/mobile/lib/services/screen_completion_tracker.dart` (intégral — stream L.40-46, markCompletedWithReturn L.67-78)
- `apps/mobile/lib/services/coach/chat_tool_dispatcher.dart` (L.80-117 resolve intent → route)
- `apps/mobile/lib/services/navigation/screen_registry.dart` (118 intent tags recensés, dont 11 `life_event_*`)
- `apps/mobile/lib/services/navigation/route_planner.dart` (L.1-60 contrat)
- `apps/mobile/lib/app.dart` (L.171-261 router redirect, L.362-388 route `/coach/chat` builder, initialLocation `/` L.174)
- `apps/mobile/lib/screens/landing_screen.dart` (intégral — invariant CI L.1-9)
- `services/backend/app/services/coach/coach_tools.py` (L.108-133 intent tags canoniques)
- `apps/mobile/lib/services/report_persistence_service.dart` (L.54-84 flag miniOnboardingCompleted)

**CapCoachBridge cité par le PLAN : n'existe pas** (grep 0 match dans `/apps/mobile`).
**`CoachProfileProvider.isOnboarded` cité par le PLAN : n'existe pas** (grep 0 match).
**`fetchMemoryBlock` cité par le PLAN : n'existe pas** (grep 0 match).
**`/landing` cité par le PLAN : n'existe pas** (route path = `/`).

Le PLAN doit être ré-édité sur la base du code réel avant exec.
