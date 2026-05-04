# PANEL ADVERSAIRE — Wave C scan handoff PLAN review

Reviewer : 200 IQ autistic dev hostile au PLAN.
Base dev : f35ec8ff (post Wave E-PRIME).
Méthode : lecture code source, diff PLAN vs réalité, chasse au bug.

---

## Verdict

**REWORK FUNDAMENTAL.** Le PLAN ne peut pas être exécuté tel quel sans introduire
au moins 4 nouveaux bugs prod (un P0 critique de façade sur C1, un P0 cold-start
sur C4, un null-ref FRESH INSTALL sur C4, un drift état sur C1). Le PLAN est
construit sur une série d'assumptions mécaniques factuellement fausses :

1. **C1** assume `GoRoute('/coach/chat')` accepte `extra: CoachEntryPayload`. **Faux**. Le builder lit uniquement `?topic=` (app.dart:370-384) et ignore `state.extra`. Payload silencieusement droppé.
2. **C1** assume la source enum à créer s'appelle `scanResult`. **Faux**. L'enum `CoachEntrySource` contient DÉJÀ `scanInsight` (coach_entry_payload.dart:45). Le PLAN va dupliquer un enum et l'autre mourir orphelin.
3. **C1** assume que la persistence `saveEvent` suffit à "remplacer le silent opener". **Faux**. `CoachMemoryService.debugGetEvents` est `@visibleForTesting`, zéro consumer prod lit `_coach_events`. C'est une façade neuve (hard-stop doctrine Julien 2026-04-18).
4. **C2** parle de "regex suggestion-chip". **Faux**. Il n'y a PAS DE REGEX dans `coach_chat_screen._extractRouteChips` (L1460). Les chips viennent de `route_to_screen` tool_use `context_message`. Le PLAN se trompe de mécanisme et de fichier.
5. **C4** assume `CoachProfileProvider.isOnboarded` existe. **Faux**. Il n'existe que `hasProfile` (L110, sync sur un nullable). Le vrai flag est `ReportPersistenceService.isMiniOnboardingCompleted()` — Future<bool>, donc inutilisable dans un `redirect` GoRouter synchrone.
6. **C3** assume un `CoachMemoryService.fetchMemoryBlock` timeout 2s. **Faux**. La cible réelle est `ContextInjectorService.buildContext()` (coach_chat_screen.dart:768). Le PLAN retry sur le mauvais étage.

Le PLAN doit être ré-écrit sur la base du code réel avant tout exec. Les 5
commits "atomiques" prévus reposent sur 6 mensonges structuraux.

---

## Les 8 scénarios adversaires obligatoires

### Scénario 1 — User scan un document illisible → extraction échoue

**Breakage point** : `document_impact_screen.dart:144` appelle `CoachMemoryService.saveEvent(topic, summary)` systématiquement, que le scan ait "réussi" ou non. Le CTA "En parler à Mint" (C1 nouveau) navigue vers le coach avec un `entryPayload.data.source = scanResult` rempli de `fields` vides ou confidence=0.

- Opener contextuel PLAN : "On a lu ton certificat CPE. Voici ce que ça change pour toi."
- Scan réel : `overallConfidence = 0.12`, 1 champ extrait sur 8, warnings ≠ [].
- Résultat : **MINT ment au user**. Le coach affirme avoir compris quelque chose qu'il n'a pas compris. Violation doctrine (CLAUDE.md §1 "Mint explicite, n'accuse pas" + `feedback_no_vague_language` "be concrete or shut up" + `feedback_never_retirement_framing` hon no-guess rule).

**Fix requis** : gate sur `widget.result.overallConfidence < 0.6 || widget.result.fields.isEmpty` → désactiver le CTA contextuel (fallback au CTA "Continuer" générique) OU changer l'opener en "On a eu du mal à lire ton document. Tu veux qu'on regarde ensemble ce qui a coincé ?" — mais alors tracker explicitement ce mode dans `payload.data['scan_quality']` pour éviter le coach hallucine des chiffres.

**Fichier/line** : `document_impact_screen.dart:690-739` (CTA) + `document_impact_screen.dart:79-125` (échec silencieux `_fetchPremierEclairage`).

---

### Scénario 2 — User scan history de 5 documents → plusieurs events empilés

**Breakage point** : `CoachMemoryService.saveEvent` dédupe par (topic, local-day) à L230-236. Donc un user qui scan LPP + 3a + tax + AVS + salaire le même jour produit 5 events distincts, tous récents.

Si C1 implémente "opener contextuel remplace silent opener générique si entry_payload présent", lequel prévaut ? Le PLAN est muet. Le code devra choisir :
- Le plus récent (FIFO insert at 0 → events[0])
- Celui matching le topic du `entryPayload` (mais `entryPayload.topic='scan_lpp'` ne matche pas le topic persisté qui est aussi `scan_lpp` → collision sémantique : où lit-on ?)
- Aucun (opener = silent) — fallback safe mais contredit le PLAN.

**Pire cas** : C1 implémenteur lit `CoachMemoryService.debugGetEvents` (visibleForTesting) en prod → on rebaptise l'API → fuite du marqueur @visibleForTesting en prod → doctrine façade-sans-câblage L263-266 violée.

**Fix requis** : décider une politique explicite dans le PLAN :
1. Ouvrir un `getEventsForContextInjection({int limit = 3})` prod-only,
2. Matcher par `topic` exact avec fallback au dernier event,
3. Tester explicitement le scénario 5-scans-mêmes-jour.

**Fichier/line** : `coach_memory_service.dart:214-261` (saveEvent), L263-273 (debugGetEvents @visibleForTesting).

---

### Scénario 3 — User se déconnecte après onboarding → C4 skip landing → comment re-authentifier ?

**Breakage point** : PLAN C4 "si `isOnboarded` true → `initialLocation: '/home'` + redirect `/landing` → `/home`". Mais `AuthProvider.logout()` (auth_provider.dart:543-561) appelle `_purgeLocalData()` qui fait `prefs.clear()` (L598). Ça flush `mini_onboarding_completed` SharedPreferences key. Donc après logout :
- `isMiniOnboardingCompleted()` → false
- Redirect C4 n'active pas → user voit `/landing` correctement.

MAIS : `AuthProvider.isLocalMode` après logout = false (L553). User sur landing tape "Continuer en mode local" → `isLocalMode=true`, `_isLoggedIn=false`. Redirect `authenticated` scope passe (L253-259 : `isLoggedIn || isLocalMode`). User à `/home` → AujourdhuiScreen. Sauf que `CoachProfileProvider._profile = null` (le wizard n'a pas été rechargé, les answers ont été wiped par `prefs.clear()`). `AujourdhuiScreen` rebuild avec profile null → risque de null-ref.

Autre cas : user logout en mode authenticated et ré-ouvre app cold-start. `AuthProvider.checkAuth()` async, `isLoading=true`. PLAN C4 : `initialLocation` dépend de `isOnboarded`. Lu AVANT checkAuth complet → false (cleared) → landing. **OK**. Mais si le user était marqué onboarded via un écran oublié qui sauvegarde hors `_purgeLocalData()` (ex: cloud-synced flag), drift.

**Fix requis** : C4 doit tester AU MINIMUM :
1. Cold-start fresh install → landing ✓
2. Cold-start post-onboarded en local mode → home ✓
3. Cold-start post-logout en mode authenticated → landing (onboarding flag flushed) ✓
4. Cold-start user qui clear le flag manuellement via Settings → landing

**Fichier/line** : `auth_provider.dart:543-620` (logout + purge), `report_persistence_service.dart:705` (remove key).

---

### Scénario 4 — User sur avion Flight mode → C3 retry ne fait rien → UX silencieuse

**Breakage point** : C3 PLAN ajoute "retry 1× back-off 500ms" sur `ContextInjectorService.buildContext()` (timeout actuel 2s). Mais :

1. `ContextInjectorService.buildContext()` ne fait PAS d'I/O réseau (context_injector_service.dart:128-250). C'est majoritairement du `SharedPreferences.getInstance()` + calculs purs. Un timeout >1s en flight mode indique un DEADLOCK ou un I/O Flutter bloqué, PAS une latence réseau. Retry ne corrige rien.

2. Le PLAN dit "Log debugPrint retry attempt pour debug device". `debugPrint` en release build = noop. Observabilité = zéro.

3. **Total latence post-C3** : 2s + 500ms + 2s = **4.5s** avant fallback. Le user tape "bonjour", attend 4.5s avant que le LLM reçoive le premier token. Régression UX severe.

4. Scénario timezone : si C3 (non documenté dans PLAN mais mentionné dans brief reviewer) persiste un "last-attempt timestamp" via SharedPreferences et `DateTime.now()` sans `.toUtc()`, user qui change de timezone (avion Suisse → Japon) verra des back-offs absurdes. Pattern identique au bug dédup saveEvent déjà corrigé à L223-235 (d'où le précédent).

**Fix requis** :
1. Classifier l'erreur : `TimeoutException` vs `IOException` vs autre. Ne retry que `TimeoutException`.
2. Backoff exponentiel (500ms → 1s), jamais plus de 1 retry.
3. Si persistence timestamp → `DateTime.now().toUtc()` systématique.
4. `debugPrint` ≠ observabilité. Émettre un breadcrumb Sentry (`SentryBreadcrumbService` existe déjà en backend, voir prod monitoring).
5. Surtout : **remettre en cause la nécessité du retry**. Un timeout 2s sur du pur SharedPreferences indique un bug Flutter framework, pas un retry.

**Fichier/line** : `coach_chat_screen.dart:768-778`, `context_injector_service.dart:128-250`.

---

### Scénario 5 — LLM hallucine un `life_event` non présent dans le regex → C2 renvoie quoi ?

**Breakage point** : C2 PLAN mentionne "regex suggestion-chip" mais **il n'y a pas de regex** dans le code. L'extraction de chips est faite par :

1. `coach_chat_screen._extractRouteChips()` (L1460) qui lit `call.input['context_message']` pour chaque tool_call `route_to_screen`.
2. `ChatToolDispatcher.resolveRouteFromIntent()` (chat_tool_dispatcher.dart:109) qui passe par `MintScreenRegistry.findByIntentStatic()`.

Si le LLM hallucine `intent='life_event_mortgage_refinance'` (pas dans `ROUTE_TO_SCREEN_INTENT_TAGS` backend, pas dans Flutter registry) :
- `resolveRouteFromIntent` retourne null (L111-112),
- `_extractRouteChips` affiche quand même la chip (L1466-1473) car elle n'utilise que `context_message`, pas la validation route,
- Tap sur la chip → `_routeForAction` (L1478) tente un matching keyword-based puis fallback à `null` → **chip inerte, tap no-op, dead-end UX**.

Même bug actuel (pré-C2). C2 prétendument élargit le regex ; en réalité C2 doit :
1. Ajouter les 7 intent tags orphelins identifiés Panel B (compound_interest, debt_check, etc.) ⇒ mais PLAN explicite "Wave C n'ajoute pas de nouveaux intents orphelins". Contradiction avec l'objectif "18 life events".
2. Aligner les noms (life_event_unemployment backend ≠ life_event_job_loss Flutter).
3. Valider le chip au render, pas juste au tap. Si l'intent n'est pas résolvable, la chip ne doit pas s'afficher.

**Fix requis** : C2 doit faire **deux choses** :
1. Ajouter un test `test_route_to_screen_intents_parity` qui boucle sur `ROUTE_TO_SCREEN_INTENT_TAGS` côté backend ET sur le dump de `MintScreenRegistry.allIntents`, assert égalité.
2. Filtrer dans `_extractRouteChips` : si la tool_call intent ne résout pas via `resolveRouteFromIntent`, DROP la chip. Ne pas l'afficher.

Sinon C2 livre plus d'orphelins avec un comptage de succès "18 life events mappés".

**Fichier/line** : `coach_chat_screen.dart:1460-1475`, `chat_tool_dispatcher.dart:109-117`, `coach_tools.py:108-133`.

**Bonus adversaire** : "regex catastrophic backtracking" n'est pas un risque du code actuel (pas de regex). Mais SI C2 implémenteur décide d'ajouter un regex greedy (ex: `(?:mariage|divorce|naissance).*(?:emploi|job|travail)`) sur le texte LLM plein — sur un message de 10k chars hallucinant → backtracking exponentiel → UI frozen. **Interdire explicitement dans C2 tout regex avec `.*` ou `.+` non-ancré**.

---

### Scénario 6 — User complete le triad via save_fact au middle d'une session existante → onboarded flag flip en cours → router réagit comment ?

**Breakage point** : La route `/coach/chat` a scope `RouteScope.public` (app.dart:368), donc pas d'auth-gate sur elle. Mais C4 ajoute un redirect `/landing → /home si onboarded`. Le `refreshListenable` du router est `_authNotifier`, pas `CoachProfileProvider` ni `ReportPersistenceService`.

Flow :
1. User sur `/coach/chat`, pas onboarded.
2. User tape "je gagne 7600 par mois" → LLM appelle `save_fact` → backend persist → triad condition check → `ProfileModel.isOnboarded=true` côté backend.
3. Côté Flutter : `CoachProfileProvider.syncFromBackend()` tire `/profiles/me` → merge → `isMiniOnboardingCompleted` flag **NE CHANGE PAS** (aucun call-site observé à `setMiniOnboardingCompleted(true)` depuis le coach ; seul `login_screen` et `coach_chat_screen._markOnboardingCompletedIfNeeded` le font, et ce dernier exige `CoachEntrySource.onboardingIntent` payload).
4. Donc même si backend triad est complet, côté mobile `isMiniOnboardingCompleted=false`. C4 redirect inopérant. State drift **permanent**.

**Pire variante** : si C4 implémente le check via `CoachProfileProvider.hasProfile`, celui-ci devient `true` après merge → router redirect inactif pendant la session courante (pas de `refreshListenable`), mais au **cold-start suivant**, il s'active brutalement. User tape `/landing` dans l'URL (web deep-link) → redirect `/home` instant. Soit OK, soit abrupt si le user voulait revoir la landing pour une raison X.

**Fix requis** :
1. Wire explicite : le handler `save_fact` backend qui bascule `isOnboarded` côté server doit retourner un signal dans `response.meta` → Flutter lit → `ReportPersistenceService.setMiniOnboardingCompleted(true)` + `_authNotifier.notifyListeners()` → router ré-évalue.
2. OU : extraire `isOnboarded` du `CoachProfileProvider` via `ChangeNotifierProxyProvider`, câbler au `refreshListenable`.
3. Tester cold-start-mid-triad : user avec backend-onboarded + mobile-pas-onboarded → décider qui gagne (recommandation : backend source de vérité, Flutter pull + sync).

**Fichier/line** : `coach_profile_provider.dart:183-198` (syncFromBackend), `report_persistence_service.dart:75-84`, `app.dart:175` (refreshListenable).

---

### Scénario 7 — Entry payload scanResult contient salaire PII → C1 injecte dans system prompt → fuite vers Anthropic

**Breakage point** : PLAN C1 dit "`context.go('/coach/chat', extra: CoachEntryPayload(source: scanResult, topic: 'scan_<doc_type>'))`" et "Entry payload → injecte contexte système prompt : 'On a lu ton certificat CPE. Voici ce que ça change pour toi.'"

Le code actuel `CoachEntryPayload.toContextInjection()` (coach_entry_payload.dart:93-111) sérialise `data.entries.map((e) => '${e.key}=${e.value}')`. Donc si C1 met `data: {'salary': 7600, 'avoirLpp': 70377, 'caisse': 'CPE', 'institution_id': '...'}`, **tous ces champs partent verbatim dans `memoryBlock` envoyé à Anthropic** (coach_chat_screen.dart:782).

Violations :
- `CLAUDE.md §6.7` : "Never log identifiable data (IBANs, names, SSN, employer)". Employeur via caisse ≈ identifiable.
- `rules.md` privacy : salaire exact = PII tier 1.
- `feedback_never_retirement_framing` + `PANEL B-WIDGET-TOOLS.md` §P0-1 : `save_fact` PRIV-07 redaction est déjà un garde-fou, bypasser par une injection raw annule l'effort Wave A PRIV-07.
- **Précédent déjà mitigé** : `document_impact_screen._bucketizeAvoir()` (L213-226) arrondit à 10k CHF avant persistence. C1 doit appliquer la même règle AVANT injection.

Pire : le `source: scanResult` + `topic: 'scan_lpp'` transmis tel quel au backend peut devenir un log aggregator signature identifiant l'user (topic rare + scan_lpp à timestamp précis sur un endpoint non-scrubbed Sentry).

**Fix requis** :
1. Interdire explicitement dans C1 l'injection de `scanResult.fields` ou `overallConfidence` numériques dans `entryPayload.data`.
2. N'injecter que des fields bucketisés (via `_bucketizeAvoir` ou équivalent) ou des noms catégoriques (`'lpp_avoir_high' | 'medium' | 'low'`).
3. Test : `test_scan_entry_payload_no_raw_salary` qui vérifie que `toContextInjection()` sur un payload scanResult ne contient aucun `r'\d{5,}'` (= chiffre ≥ 5 digits = CHF 10k+).
4. Reformuler : opener LLM reçoit `"Le user vient de scanner un certificat de prévoyance (avoir: bucket ~70'000, caisse: CPE). Il veut en parler."` PAS `"avoirLpp=70377.00,salaire=7600.00,..."`.

**Fichier/line** : `coach_entry_payload.dart:93-111`, `document_impact_screen.dart:213-226` (précédent), `coach_chat_screen.dart:780-784`.

---

### Scénario 8 — Two coach tabs ouverts simultanément (iPad) → entry payload consumé 1×

**Breakage point** : `CapCoachBridge.pendingPrompt` (cap_card.dart:229) est une `static String?` globale. `consume()` (L232-236) lit + clear. Non-atomique.

Si user iPad scan une fois et a deux coach tabs (multi-window iOS 14+), les deux tabs `initState` → `_consumeCapCoachBridge()` (coach_chat_screen.dart:206). Le premier consume → le second voit `null`. **Race gagnée = dépend de l'ordre d'init des State, non-déterministe**.

Plus grave : si C1 ajoute un `CoachEntryPayload` via `GoRouter.extra`, celui-ci n'est visible que sur le StatefulShellBranch où la navigation a eu lieu. L'autre branche (autre coach tab iPad ? non-applicable car shell singleton) n'a pas ce problème. MAIS : si deux `GoRouter` instances (multi-window iPad = deux `_router` singletons ? Non, c'est un singleton Dart-level top-level `_router`), **ils partagent la state**. Donc les deux coach tabs iPad lisent le même `_router` → même state. Le payload `extra` est transitoire dans `GoRouterState.extra`, donc le second tab ne le voit pas du tout.

Résumé scénario iPad :
- Scan tab A → tap CTA → push `/coach/chat` avec extra → tab A ouvre coach avec payload (si extra fonctionnait, cf scénario C1).
- Tab B (coach déjà ouvert) : ne voit rien.
- Refresh tab B (manuel) : `extra` consumé/expiré → rien.

**Fix requis** :
1. Transformer `CapCoachBridge` en queue (FIFO list) avec `consume()` pop le head.
2. Transformer le hand-off scan→coach en event via `ScreenCompletionTracker.stream` (déjà broadcast — les deux tabs reçoivent) PLUS persistence dans SharedPreferences pour le late-subscriber.
3. Test explicite multi-tab iPad.

**Fichier/line** : `cap_card.dart:227-237`, `screen_completion_tracker.dart:40-46` (stream broadcast, pas buffered — scenario stream-miss aussi, cf nouveau findings ci-dessous).

---

## Nouveaux scénarios adversaires (découverts en lisant le code)

### Scénario 9 — ScreenCompletionTracker stream miss : CRITIQUE

`ScreenCompletionTracker._controller = StreamController<ScreenReturn>.broadcast()` (screen_completion_tracker.dart:40). **Broadcast stream sans replay.**

Flow actuel (pré-Wave-C) :
1. `document_impact_screen.dart:709` → `ScreenCompletionTracker.markCompletedWithReturn('document_scan', ...)` → emit sur le stream.
2. Listener : `CoachChatScreen._subscribeToScreenReturns()` (coach_chat_screen.dart:400) mais appelé seulement dans `initState` de CoachChatScreen.
3. Scan → emit → **CoachChatScreen n'est pas encore mounted** → event perdu.
4. User tape CTA → push `/coach/chat` → CoachChatScreen.initState → `listen()` → stream déjà vidé → `_entryPayloadContext` jamais set.

**C'est pourquoi le scan "pre-existing" n'informe JAMAIS le coach aujourd'hui.** PLAN Wave C n'est pas "câbler ce qui existe déjà" — le câblage a été mal fait à l'origine et personne ne l'a vu (nouveau P0 de plus à ajouter au tableau Panel B).

**Fix requis** avant C1 :
1. Persister `ScreenReturn` last-emitted dans SharedPreferences (déjà partiellement fait via `_writeReturn` L77).
2. Au `initState` de CoachChatScreen : lire le dernier ScreenReturn persisté + timestamp, si récent (< 5 min) → injecter comme `_entryPayloadContext` AU LIEU de seulement subscribe au stream future.
3. Test explicite `test_coach_receives_scan_context_even_if_opened_after_scan`.

**Fichier/line** : `screen_completion_tracker.dart:40`, `coach_chat_screen.dart:400-413`.

---

### Scénario 10 — Memory leak sur `_screenReturnSub` dans navigation rebuilds

`_screenReturnSub` est cancelled dans `dispose()` (coach_chat_screen.dart:381). Bien. MAIS : `CoachChatScreen` est construit dans `StatefulShellBranch` (Tab 2 du shell). Le branch est `IndexedStack` (indexedStack builder L308). Switching tabs **ne dispose pas le branch**, mais le `build` est appelé à chaque rebuild du shell.

Si C1 introduit un flag instanciant un nouveau `CoachChatScreen` à chaque `entryPayload` (ex: `key: ValueKey(payload.hashCode)`), chaque switch tabs avec un nouveau payload recrée le State → nouveau `listen()` → **ancien Subscription cancelled à dispose, OK**. Mais si l'implémenteur oublie le key pattern et garde la même State, le payload change sans rebuild → pas d'effet.

Pire : `WidgetsBinding.instance.addPostFrameCallback` dans `didChangeDependencies` (L334, 340, 352) → pas de mécanisme d'annulation. Si le widget est disposé avant le callback, il peut appeler `_sendMessage` sur un State disposed → `mounted` check dans `_sendMessage` existe → OK mais lock encore une fois sur `mounted`.

**Fix requis** : tester explicitement nav-shell rebuild avec entry payload change. Ajouter assertion `assert(mounted)` au début de tous les callbacks post-frame.

**Fichier/line** : `coach_chat_screen.dart:300-365`, `dispose` L380-387.

---

### Scénario 11 — Null-ref CoachProfile mi-onboarding pour le opener contextuel

`CoachChatScreen.didChangeDependencies` L310-314 : `if (!_profileInitialized) { ... if (coachProvider.hasProfile) { _profile = coachProvider.profile!; ... } }`.

Si un user scan en mode fresh install (anon, `hasProfile=false`) → `_profile = null` → L322 `if (widget.entryPayload != null)` peut s'exécuter → `_markOnboardingCompletedIfNeeded` attend `CoachEntrySource.onboardingIntent` (OK). Mais le `payload.topic=='scan_lpp'` pousse vers L363 `_entryPayloadContext = payload.toContextInjection()`.

Plus tard, `_sendMessage` L789 : `if (_profile == null) { final provider = context.read<CoachProfileProvider>(); if (provider.hasProfile) { _profile = provider.profile; } else { _profile = CoachProfile.defaults(); } }`. Fallback propre.

MAIS : `ContextInjectorService.buildContext(profile: _profile, ...)` L769 — `_profile` à ce stade est encore null si `didChangeDependencies` n'a pas remis `_profile` (cas first message after scan avant le sync backend). Vérification : `buildContext` accepte `profile: null` (context_injector_service.dart:129 `CoachProfile? profile`). OK.

**Mais** : si C1 ajoute un opener contextuel type "On a lu ton certificat (CPE, ~70k)" qui référence `_profile.identite.prenom` (pour personnalisation) sans null-check, **null-ref crash cold-open**.

**Fix requis** : C1 doit forcer l'opener à fonctionner sans accès à `_profile` (le scan a produit des données, l'opener peut être source-based pas profile-based). Tester opener cold-start `_profile=null`.

**Fichier/line** : `coach_chat_screen.dart:310-365`, `coach_chat_screen.dart:510-580` (_computeKeyNumber null-safe precedent).

---

### Scénario 12 — Compliance violation : "On a lu ton certificat" = affirmation non-vérifiée

Opener PLAN : "On a lu ton certificat CPE. Voici ce que ça change pour toi."

Problèmes doctrine :
1. **"ton certificat CPE"** : si l'user scanne un 3a attestation UBS par erreur marqué `lppCertificate` (mis-classification OCR), MINT affirme "CPE" alors que le user a scanné UBS. **Mint ment**.
2. **"On a lu"** : si le scan confidence < 0.6, on n'a PAS lu — on a tenté de lire.
3. **"Voici ce que ça change pour toi"** : promise implicite qu'il y a un changement. Doctrine `feedback_no_vague_language` : be concrete or shut up.

Banned terms check (CLAUDE.md §6.3) : OK — pas de "garanti/optimal/meilleur".
Terme "chiffre choc" : OK — absent.
Neutrality archetype : **PAS OK**. Un user `expat_us` (FATCA) avec certificat CPE a des implications TRÈS différentes qu'un `swiss_native`. Opener indifférencié = risque de conseil inadapté.

**Fix requis** :
1. Wording conditionnel : "Tu viens de partager un document de prévoyance. On regarde ensemble ?"
2. Si confidence < 0.6 : "J'ai eu du mal à lire certains champs. Tu veux qu'on reprenne ?"
3. Injecter l'archetype dans l'opener via `payload.data['archetype']` si connu, sinon opener neutre.
4. Test : compliance gate via `ComplianceGuard` SUR l'opener généré LLM, pas seulement sur la première réponse.

**Fichier/line** : opener PLAN §C1 wording, `CLAUDE.md §6.3` banned terms, `ComplianceGuard` backend.

---

### Scénario 13 — C4 router cold-start flash landing

PLAN §C4 Risques mentionne cette race mais ne propose qu'un mitigation "tester un cold-start avec SharedPreferences mock" — insuffisant.

Flow précis :
1. `main.dart` → `runApp(MyApp())`.
2. `app.dart` build → `_router` construit avec `initialLocation: '/'` ou `/home` (PLAN C4 conditionnel). Si conditionnel sur `isMiniOnboardingCompleted()` **qui est async**, le `initialLocation` doit être résolu BEFORE router build.
3. Option A : `main.dart` await `isMiniOnboardingCompleted()` puis build MaterialApp.router avec bon initialLocation → blocage démarrage de l'app tant que SharedPreferences ne répond pas. Impact cold-start ≈ 150-300ms supplémentaires. Flash blanc.
4. Option B : démarrer sur `/` toujours, mettre la logique dans `redirect` callback (SYNC). Mais `redirect` ne peut pas await. Doit lire un ChangeNotifier pré-rempli.
5. Option C : demarrer sur `/`, le LandingScreen lui-même check async et `context.go('/home')` si onboarded → **flash landing garanti** (300-800ms).

Option C est ce que PLAN insinue ("redirect GoRouter si user tape `/landing` alors que onboarded → `/home`") → mais le redirect GoRouter est sync, donc on retombe sur B avec ChangeNotifier.

**Fix requis** : Option A ou B strictement. Option B nécessite :
1. Un `OnboardingStatusNotifier` qui load dès `main()` et `notifyListeners()` quand résolu.
2. `_router.refreshListenable = Listenable.merge([_authNotifier, _onboardingNotifier])`.
3. Route redirect lit `_onboardingNotifier.value`.

Le PLAN actuel ne mentionne RIEN de ça. C4 "30min" est sous-estimé d'un facteur 4.

**Fichier/line** : `app.dart:169-260`, `main.dart:37-50`.

---

### Scénario 14 — C3 sur le mauvais étage

Le brief reviewer dit "C3 retry back-off + SharedPreferences last-attempt timestamp". Le PLAN dit "CoachMemoryService.fetchMemoryBlock timeout 2s". Le code dit `ContextInjectorService.buildContext` avec timeout 2s.

Il n'existe AUCUNE méthode `fetchMemoryBlock` dans `CoachMemoryService`. PLAN pointe vers un fichier inexistant. Implémenteur va :
1. Ouvrir `CoachMemoryService.dart` → rien trouver → créer la méthode → créer un orphan service.
2. Ou corriger le fichier cible en `ContextInjectorService.buildContext` → mais C3 scope 30min n'anticipe pas la complexité.

De plus : `buildContext` appelle `Future.wait([memoryFuture, goalsFuture, activeGoalsFuture])` (context_injector_service.dart:147). Retry global re-fire les trois sub-futures → triple I/O SharedPreferences pour un seul qui a timeout. Optimisation : retry que le sub-future qui a failed. PLAN n'en parle pas.

**Fix requis** : Re-écrire C3 avec :
1. Fichier cible correct : `context_injector_service.dart`.
2. Retry sélectif par sub-future.
3. Backoff `Duration(milliseconds: 500)` ou `ExponentialBackoff(initial: 200ms, max: 1s)`.
4. Pas de persistence SharedPreferences "last-attempt timestamp" sauf si on peut prouver un usage (principe façade).

**Fichier/line** : `context_injector_service.dart:128-250`.

---

### Scénario 15 — Logout rétro-gamifié via C1 event persisté

`saveEvent` (coach_memory_service.dart:214) persiste dans SharedPreferences sous clé `${_eventsBaseKey}_$uid`. Dédupe par local-day.

User A scan LPP le lundi. User A logout. User B login sur même device. User B scan LPP le mardi.
- `_eventsKey` dépend de `AuthService.getUserId()` → user-namespaced. User B ne voit PAS events de User A ✓.
- Mais : si User A jamais authentifié (scan en local mode, anon), l'event persiste sous `___anon` namespace. User A créer un compte → `AuthService.getUserId()` retourne un vrai id → `_keyFor` retourne `${_baseKey}_realuid` → **les events anon ne sont jamais migrés**. Sont perdus UX-wise mais restent dans `___anon` comme ghost data.

PLAN C1 opener contextuel lit les events via nouveau getter → user post-register ne voit pas "tu as scanné LPP hier" → dissonance.

**Fix requis** :
1. Lors du `register`, migrer `___anon` events vers le nouveau namespace user (ou les purger explicitement).
2. Actuellement seulement `clear()` fait au logout, pas au register.

**Fichier/line** : `coach_memory_service.dart:72-82`, `auth_provider.dart` register flow.

---

## Patches minimum requis AVANT exec

Ordre de priorité. Sans ces patches, PLAN ne peut pas être exécuté sans régression.

### P0 — Bloquant

1. **Re-écrire C1** : fixer le fait que `GoRoute('/coach/chat')` builder ignore `state.extra`. Deux options :
   - A) Modifier le builder app.dart:369-385 pour lire `state.extra as CoachEntryPayload?` en priorité sur `?topic=`.
   - B) Passer le payload via `CapCoachBridge` (global static) → mais scénario 8 (iPad) reste ouvert.
   - Option A préférée. C1 doit être explicitement : "modify `/coach/chat` route builder to read `state.extra` as `CoachEntryPayload`".

2. **Corriger le scope C1 pour inclure la reader API events** : `CoachMemoryService.getEventsForOpener({int limit=3})` prod (non-@visibleForTesting). Câbler consumer dans `coach_chat_screen._addInitialGreeting` ou `_computeKeyNumber`. Sinon Wave A saveEvent reste dead code.

3. **Fixer C4 : l'état `isOnboarded` n'existe pas** : introduire `OnboardingStatusNotifier` chargé async au démarrage app, merger dans `_router.refreshListenable`. Sinon router race cold-start = flash landing.

4. **PII bucket avant injection system prompt (C1)** : ajouter test `test_entry_payload_no_raw_salary` + bucketize avant `toContextInjection()`.

5. **ScreenCompletionTracker miss stream** : persister last-emitted + lire au CoachChatScreen.initState. P0 indépendant de Wave C mais C1 en dépend.

### P1 — Strong recommend

6. **C2 filtrer chips par intent résolvable** : drop les tool_calls `route_to_screen` dont l'intent n'est pas résolvable côté Flutter registry. Sinon le LLM peut hallucier des chips inertes.

7. **C3 cible correcte** : `context_injector_service.dart:128-250`, pas `CoachMemoryService`. Retry sélectif par sub-future, classification erreur `TimeoutException` only.

8. **C1 opener conditionnel** : wording qui dégrade proprement si `overallConfidence < 0.6`. Jamais affirmer "on a lu" si on n'a pas lu.

9. **Test parité intent tags** : `test_route_to_screen_intents_parity` Python + Dart. Aurait catché les 7 orphelins Panel B.

10. **iPad multi-tab test** : scénario 8 explicite. Transformer `CapCoachBridge` en FIFO queue.

### P2 — Nice-to-have

11. Migration events `___anon` → user-namespace au register (scénario 15).
12. Doc mise à jour `coach_profile_provider.dart:183` (commentaire menteur — Panel B §P2-1).
13. Compliance gate sur l'opener via `ComplianceGuard` backend (scénario 12).

---

## Résumé compteurs

| Métrique | Valeur |
|---|---|
| P0 bloquants | **5** |
| P1 strong | **5** |
| P2 nice | **3** |
| Scénarios testés | **15** (8 demandés + 7 découverts) |
| Façades nouvelles créées par PLAN si exec as-is | **3** (C1 events reader, C1 payload via extra, C4 non-refreshing flag) |
| Heures sous-estimées | **~4h** (PLAN dit 4-6h total, réaliste est 8-10h post-corrections) |

---

## Doctrine alignment

- `feedback_facade_sans_cablage_absolu.md` (doctrine hard-stop 2026-04-18) : **violé** sur 3 points distincts (events reader, payload route, refresh notifier). **PLAN doit être stoppé** tant que les patches P0 ne sont pas intégrés au plan écrit.
- `feedback_no_shortcuts_ever.md` : C3 retry blind = raccourci. Doit être classifié par type d'erreur.
- `feedback_never_retirement_framing.md` : opener "certificat CPE" alors que le user peut avoir scanné 3a → assumption retraite. C1 opener doit être document-type-agnostic.
- `feedback_audit_read_error_paths.md` : PLAN scenarios table §Risques ne lit QUE les happy paths ("tester un cold-start") — ignore le path où `isOnboarded` change MID-session.
- `feedback_audit_inter_layer_contracts.md` : PLAN C1 suppose le contrat route builder accepte `extra` — zéro check inter-couche fait au préalable. Check B "caller passes correct params" violé par-design.

---

## Verdict final

**REWORK FUNDAMENTAL** requis. Le PLAN actuel est une shopping list d'intentions,
pas un plan d'exécution. Il est construit sur une lecture superficielle du code
(regex C2 inexistant, flag C4 inexistant, fichier C3 faux nom, extra C1 ignoré,
events C1 sans reader prod). Exécuter as-is = livrer 3 nouvelles façades et au
moins 2 régressions UX (flash landing C4, latence C3).

Aucune urgence métier ne justifie de shipper Wave C ce weekend. Prendre 1h pour
réécrire le PLAN sur la base du code réel (ce panel en liste les points) vaut
mieux que 4-6h d'exec puis post-mortem + Wave C-fix.

Hard-stop PLAN Wave C. Patch list P0 d'abord.
