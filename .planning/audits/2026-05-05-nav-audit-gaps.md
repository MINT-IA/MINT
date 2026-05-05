# Sprint 1 — Navigation audit — Gaps + Dead-ends (Étapes 3 + 4)

> Source : diff programmatique via `python3 tools/checks/screen_registry_parity.py --extract-only {app,registry}` + lecture des écrans utilisateur clés.
> Date : 2026-05-05.

---

## Étape 3 — Diff (gaps)

### a) Routes `app.dart` SANS `ScreenEntry` correspondant

**Compte : 0 gap structurel net** après application de l'allow-list `KNOWN-MISSES.md`. Le tool `screen_registry_parity.py` rapporte `[OK] 125 routes parity OK`.

Toutes les 21 routes sans ScreenEntry sont dans la catégorie A (`_NOT_CHAT_ROUTABLE`) ou catégorie B (`_NESTED_PROFILE_CHILDREN`) du KNOWN-MISSES, donc parity holds.

Liste explicite (déduite via `comm -23 app_paths registry_paths`) :

1. `/` — landing (allow-list A)
2. `/start` — anonymous wedge entry (allow-list A)
3. `/onb` — onboarding root (allow-list A)
4. `/auth/verify` — magic link verify (allow-list A)
5. `/anonymous/intent` — pre-chat (allow-list A)
6. `/anonymous/chat` — pre-chat (allow-list A)
7. `/admin/routes` — dev-only (allow-list A)
8. `/about` — public legal (allow-list A)
9. `/onboarding/enrichment` — onboarding shim (allow-list A)
10. `/onboarding/intent` — onboarding shim (allow-list A)
11. `/onboarding/minimal` — onboarding shim (allow-list A)
12. `/onboarding/plan` — onboarding shim (allow-list A)
13. `/onboarding/promise` — onboarding shim (allow-list A)
14. `/onboarding/quick-start` — onboarding shim (allow-list A)
15. `/onboarding/smart` — onboarding shim (allow-list A)
16. `admin-analytics` (segment nesting `/profile/admin-analytics`) — allow-list B
17. `admin-observability` (segment nesting) — allow-list B
18. `bilan` (segment nesting) — allow-list B
19. `byok` (segment nesting) — allow-list B
20. `privacy` (segment nesting) — allow-list B
21. `privacy-control` (segment nesting) — allow-list B
22. `slm` (segment nesting) — allow-list B

> Note : 22 entries listées — la 22e (`/about`) entrée à 2026-05-04 dans Phase 53. Pas de gap.

### b) `ScreenEntry` dont la `route` n'existe PAS dans `app.dart` (référence morte)

**Compte : 0 ghost après normalisation des `?topic=` shortcuts** (Phase 53 a fixé tous les ghosts précédents). Détail :

- 6 routes `_NESTED_PROFILE_CHILDREN` (`/profile/admin-*`, `/profile/byok`, `/profile/slm`, `/profile/bilan`, `/profile/privacy-control`) — déclarées dans `app.dart` lignes 1052–1086 sous le parent `/profile` → la regex `_GOROUTE_RE` ne capture que le segment relatif (`bilan`, `byok`, …) ; la registry a la forme composée. Ce n'est pas un ghost — c'est un artefact de regex documenté dans `KNOWN-MISSES.md` §B.

⚠️ MAIS : il y a **9 entries qui pointent sur des routes APP-DART qui sont REDIRECT-ONLY** — donc le ScreenEntry ne mène jamais à l'écran promis par son `intentTag`. Ce ne sont pas des ghosts au sens strict (la route existe), mais des **références-zombie sémantiques** :

1. `financial_cockpit` → `/coach/cockpit` (redirect → `/retraite`) — l'intent décrit un cockpit financier mais l'écran est le dashboard retraite.
2. `coach_checkin` → `/coach/checkin` (redirect → `/coach/chat`) — STAB-14 archived, l'intent reste affiché.
3. `coach_annual_refresh` → `/coach/refresh` (redirect → `/home`) — `preferFromChat: false` donc inerte mais pollue le registry.
4. `portfolio_overview` → `/portfolio` (redirect → `/home`) — `preferFromChat: true` ! Si LLM résout cet intent, user est déposé sur `/home` (Aujourd'hui) sans contexte.
5. `score_reveal` → `/score-reveal` (redirect → `/home`).
6. `ask_mint` → `/ask-mint` (redirect → `/coach/chat`) — `preferFromChat: true`, mais passe par 2 hops + perd le `?topic`.
7. `onboarding_quick` → `/onboarding/quick` (redirect → `/coach/chat`).
8. `onboarding_premier_eclairage` → `/onboarding/premier-eclairage` (redirect → `/coach/chat`).
9. `achievements` → `/achievements` (redirect → `/home`) — `preferFromChat: false`, inerte mais pollue.

Plus 26 « DUPLICATE-INTENT-SHIM » Phase 53-01 (lignes 1496–1833 dans le registry), tous pointent sur des routes redirect → canonique. Sémantique brouillée pour le LLM (deux intents pour le même écran).

### c) `ScreenEntry` avec `preferFromChat: true` mais sans `intentTag` connu

**Compte : 0.** Tous les `intentTag` de `ScreenEntry` sont uniques (validation enforced par convention). Lint mécanique = OK.

Cependant : le LLM résolveur d'intent (RoutePlanner) ne consomme actuellement que le sous-ensemble suggéré par les system prompts. Hors-scope du Sprint 1 ; à valider Sprint 4 (LLM evals).

### d) Life-event routes — direct vs SequenceCoordinator

Routes top-user-paths (« 18 life events » du framing MINT) classifiées :

| Route | Ouverte directement (`context.go` / `context.push`) ? | Routée via `SequenceCoordinator` ? | Verdict |
|---|---|---|---|
| `/mariage` | OUI (ExploreHubScreen → push) | NON | Direct only |
| `/naissance` | OUI | NON | Direct only |
| `/divorce` | OUI | NON | Direct only |
| `/concubinage` | OUI | NON | Direct only |
| `/retraite` | OUI (RetirementDashboardScreen) + via `topic=retraite` chat | NON (pas de template séquence trouvé) | Direct only |
| `/hypotheque` | OUI (Explorer hub Logement) | NON | Direct only |
| `/first-job` (« premier emploi ») | OUI (Explorer hub Travail) | NON | Direct only |
| `/onboarding/*` | tous redirect → `/coach/chat` | N/A (consommé par OnboardingShellScreen sur `/onb`) | Shim only |
| `/scan` | OUI (multiple call-sites) | NON | Direct only |
| `/coach` (alias `/coach/chat`) | OUI (shell tab 2) + redirects | OUI — `SequenceChatHandler` agit DANS le chat | Hybride |
| `/dossier` (alias `/profile/bilan`) | OUI (FinancialSummaryScreen via `/profile` redirect) | NON | Direct only |
| `/aujourdhui` (alias `/home`) | OUI (shell tab 0) | NON | Direct only |

**Conclusion d) :** AUCUN life event n'est ouvert via `SequenceCoordinator`. Le coordinator (`apps/mobile/lib/services/sequence/sequence_coordinator.dart:82` + `sequence_chat_handler.dart:45`) n'agit que SUR retours de RouteSuggestionCard depuis le coach chat — il n'orchestre pas les ouvertures depuis Explorer hubs ou notifications. C'est cohérent avec son design (« post-step routing only ») mais signifie que le « guided sequence » du framing MINT n'est PAS le mode d'entrée principal.

---

## Étape 4 — Top 5 parcours utilisateur — dead-ends

### Parcours 1 — Anonymous flow

**Trajectoire** : `/` (LandingScreen) → CTA `commencer` → `/start` redirect → `/anonymous/intent` (par défaut) ou `/onb` (si `enableMvpWedgeOnboarding`) → user pick a pill ou écrit du free-text → `/anonymous/chat?intent=…` → 3-msg auth gate → register/login.

**Vérifs :**

- **(a) FIX-01 status.** ✅ shipped. Landing CTA `app.dart:317` redirige vers `/anonymous/intent` (RouteScope.public) sans auth gate. `landing_screen.dart:176` `onPressed: () => context.go('/start')`. Cf. commit `746d1bb` (handoff2 sweep PR-2) + commit `6ab3dda` (handoff2 hero) + 30.9-fix-02-anonymous-cta.
- **(b) Exit vers compte.** Trois portes : (1) long-press wordmark MINT (`landing_screen.dart:112` → `/auth/login`) — découvrabilité = 0 sans tooltip ; (2) lien « Déjà un compte » (`landing_screen.dart:198` → `/auth/login`) ; (3) auth gate dans `anonymous_chat_screen.dart:232` après 3 messages user. Bouton CTA `/auth/register` à la fin du chat (`anonymous_chat_screen.dart:699`).
- **(c) Dead-end après 3 minutes sans inscription.** ⚠️ **Dead-end identifié.** Si l'user envoie 3 messages → auth gate verrouillé (`_isAuthGateLocked = true`). Le bouton back de l'AppBar (`anonymous_chat_screen.dart:294 onPressed: () => context.go('/')`) ramène à la Landing. Mais : le state `_messages` est PERDU (pas persisté), donc relancer `/anonymous/chat` ré-initialise une session vide. Aucun bouton « pas maintenant, reviens demain » sans inscription. **3-msg lock = 100% dead-end si user ne veut pas s'inscrire.** Conforme au design intentionnel (cf. `auth_gate_bottom_sheet`) mais c'est un dead-end fonctionnel.

### Parcours 2 — Coach chat

**Trajectoire** : `/coach/chat` (Tab 2) ouverte → user tape un message → réponse coach (LLM streaming) → `RouteSuggestionCard` éventuel → tap → `context.push(route)` → écran ouvert → user back-press → retour chat.

**Vérifs :**

- ScreenReturn → chat. ✅ Wired. `coach_chat_screen.dart:863 context.push(route)` retourne via `_handleRouteReturn` → `SequenceChatHandler.handleStepReturn` (Phase 54-02 PR-2 RouteSuggestionNavLock 500ms). `route_suggestion_card.dart:150` enforce `RouteSuggestionNavLock.tryAcquire()` avant push pour dedupe.
- **Dead-end potentiel #2A** ⚠️ : si la cible push est un screen avec sa propre AppBar `IconButton(arrow_back) → Navigator.pop()` standard (cf. `mariage_screen.dart:153`, etc.), le pop ramène au chat — OK. Mais certains écrans (e.g. `/scan/review` ligne 938) appellent `context.push('/scan/impact')` — la stack devient `chat → scan → review → impact`. Pop d'impact ramène à review, pas au chat. **PENDING-VERIFY** sur device : le user perçoit-il un retour vers chat ou un re-pop multiple ? Walker E2E Sprint 5.
- **Dead-end #2B** ⚠️ : `coach_chat_screen.dart:1859 context.push('/auth/register')` (auth gate dans le chat authentifié) — sur succès register, on est ramené au flow normal mais sur cancel / back, **on reste dans l'AuthScreen sans bouton « rester anonyme »**. À VÉRIFIER : `register_screen.dart` a-t-il un dismiss vers `/coach/chat` ? PENDING-VERIFY.

### Parcours 3 — Document scan KYC

**Trajectoire** : entry depuis `/coach/chat:2202 context.push('/scan')` ou Aujourd'hui card → `/scan` (`DocumentScanScreen`) → choix DocumentType → camera/galerie → consent → upload → vision extract → `context.push('/scan/review', extra: result)` → `ExtractionReviewScreen` → confirm → `context.push('/scan/impact', extra: {...})` → `DocumentImpactScreen` → CTA → retour.

**Vérifs :**

- PR #475 (consent ApiException catch) shipped → 401 fatal-crash résolu côté backend.
- Sprint 0 PR #478 (breadcrumb) shipped → trace OK.
- Stack manipulation : 4 push successifs = stack `coach/chat → scan → review → impact`. **Dead-end #3A** ⚠️ : sur `document_impact_screen.dart:730 / 778 context.go('/coach/chat')` — utilise `go` au lieu de `pop x3`. Conséquence : la BackButton stack est nettoyée correctement (go `clear-and-replace`), mais l'user perd l'historique du flow (e.g. retour à `review` impossible). Acceptable si flux terminal — à confirmer par UX intention.
- **Dead-end #3B** ⚠️ : `document_scan_screen.dart:1088 context.go('/auth/register')` — déclenché si auth requise. Pas de query `?redirect=` → le redirect callback global (`app.dart:299`) ne saura pas où ramener l'user après registration. **Bug latent** : la stack scan est complètement perdue.
- **Dead-end #3C** ⚠️ : `extraction_review_screen.dart:745 context.push('/scan/impact', extra: {...})` — si user dismiss avant impact, retour direct à review (Navigator.pop pop le push). Sans persistance offerte par `ReportPersistenceService`, **l'extraction est perdue** si l'user re-rentre via `/scan` (DocumentScanScreen.initState ne vérifie pas un éventuel state pending). PENDING-VERIFY.

### Parcours 4 — Onboarding (MVP wedge)

**Trajectoire** : `/onb` → `OnboardingShellScreen` (`onboarding_shell_screen.dart:29`) → 8 steps (entry → intents → age → canton → revenue → insight → scene → bifurcation) → `_BifurcationStepState._sealAndGo` → `router.go(deeper ? '/coach/chat' : '/home')`.

**Vérifs :**

- 8 étapes (la T9 « magicLink » a été retirée 2026-04-24 — cf. `onboarding_provider.dart:44` commentaire).
- Skip : aucun bouton « passer cette étape » visible dans le shell. Le user PEUT remonter via le state machine `OnboardingProvider.previousStep()` — à confirmer (PENDING-VERIFY le bouton est-il rendu dans `_StepScaffold` ?).
- **Dead-end #4A** ⚠️ : si user appuie sur le system-back hardware (Android) ou swipe-back (iOS) sur la première étape `_EntryStep`, **aucune route parente** (Onboarding est entrée par redirect depuis `/`). Le router go-back va probablement crash ou se comporter de manière indéfinie. PENDING-VERIFY device.
- **Dead-end #4B** ⚠️ : abandon mid-flow. Si l'user kill l'app au step 5 (revenue), `OnboardingProvider` est in-memory → reset complet à la relance. La sealing/flush ne se fait qu'au step 8. Donc **aucune persistence intermédiaire**. Re-rentrée = Onboarding from scratch. À confirmer mais acceptable pour MVP.
- ✅ Completion : `router.go('/coach/chat')` ou `router.go('/home')` côté ScopedGoRoute (RouteScope public pour `/coach/chat` permet l'entrée anonyme — cf. `app.dart:440 scope: RouteScope.public`).

### Parcours 5 — Dossier (3 piliers + budget + sécurité)

**Trajectoire** : `/profile/bilan` (canonique du « dossier ») → `FinancialSummaryScreen` → cards drill-down → screen specifique → back.

**Vérifs :**

- Pas de tabs explicites dans `FinancialSummaryScreen` (vérification rapide). Les piliers AVS/LPP/3a sont rendus côte-à-côte avec drill-down via `context.push(route)` (cf. `financial_summary_screen.dart:174 context.push('/scan')` + lignes 313, 337, 417).
- **Dead-end #5A** ⚠️ : `/dossier` (alias mental utilisé dans le prompt user) **N'EXISTE PAS** dans `app.dart`. Aucune redirection. Si un deep-link, notification, ou doc utilisateur référence `/dossier`, l'errorBuilder `_MintErrorScreen` (app.dart:218 et 1815) montre « Page introuvable » → bouton « Retour » → `/coach/chat`. C'est UN dead-end pour l'utilisateur final qui s'attend à `/dossier` (mockups, mots-clés Cleo-style). **À fix-or-redirect.**
- **Dead-end #5B** ⚠️ : back button depuis `/profile/bilan` rentré directement (e.g. notification). La route est sous le parent `/profile` qui n'a pas de tab dédié dans le shell — donc `Navigator.pop()` n'a pas où aller. `context.go('/coach/chat')` (financial_summary_screen.dart:92 onCta + 337) sont les exits primaires. PENDING-VERIFY device : visuellement acceptable ?
- ✅ Drill-down OK : `context.push` préserve la back-stack vers Profile/Bilan. Les commentaires `financial_summary_screen.dart:394` confirment le pattern.

---

## Synthèse étape 3+4

- **Gaps structurels app.dart ↔ registry : 0** (parity tool green).
- **Références-zombie sémantiques registry → redirect-only routes : 9** (catalogue §3.b) — `preferFromChat: true` only sur `portfolio_overview` et `ask_mint` → impact LLM réel.
- **Phase 53-01 DUPLICATE-INTENT-SHIM : 26 entries** dupliquant des routes canoniques via redirects → bruit dans la registry, à dédupliquer Sprint 5+.
- **Top dead-ends utilisateur (priorité TestFlight) :**
  1. `/dossier` route inexistante → 404 silencieux. **P1 — fix par redirect en 30min.**
  2. Anonymous chat 3-msg lock sans persistance → user volume perdu en backstack `/`. **P1 — UX choice + 1 fix possible.**
  3. Document-scan stack `chat → scan → review → impact` puis `auth/register` sans `?redirect=` → context perdu. **P2.**
  4. Onboarding system-back hardware → comportement non-défini. **P2 — PENDING-VERIFY device.**
  5. Coach RouteSuggestionCard → écran multi-push (e.g. scan), pop ne retourne pas au chat. **P3 — PENDING-VERIFY.**

Détail ETA + fichiers cible dans `.planning/phases/55-nav-audit/55-NAV-AUDIT-REPORT.html` §Pareto.
