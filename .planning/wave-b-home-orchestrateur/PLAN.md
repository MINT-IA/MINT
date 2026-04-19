# PLAN — Wave B-prime : Home "Aujourd'hui" orchestrateur (MINIMAL)

**Version** : 2 (post 3-panel review 2026-04-18, voir `REVIEW-PLAN.md`)
**Branche** : `feature/wave-b-home-orchestrateur` (à créer depuis dev après merge PR #353)
**Base prévue** : `dev` + PRIV-07 hotfix mergé
**Durée estimée** : 6-7h (4 commits atomiques)
**PR cible** : `feature/wave-b-home-orchestrateur` → `dev` (merge-commit)

## Changelog v1 → v2

Les 3 panels review ont tranché :
- **Panel archi** : SPLIT (B-prime-1 + B-prime-2), prereq A2 MintStateProvider proxy, B6 scope étendu à CapEngine (10 call-sites)
- **Panel adversaire** : 5 bugs prod (logout, JITAI I/O loop, weekly API divergence, CapEngine age, Milestone timing)
- **Panel iconoclaste** : Wave B-MINIMAL 3-commit. KILL B2/B3/B5 (violations doctrine lucidité / territoire Cleo / registre Duolingo). Defer B4 → Wave C, B6-étendu + B7 → Wave E.

Convergence : **Wave B ship uniquement B0 + B1 + B6-minimal** avec garde-fous archi (proxy, range check) et adversaire (CapEngine migration age). Ship-and-observe 5 jours avant Wave B'.

## Goal

Le tab Aujourd'hui passe de **landing redirect pour non-logged** à **écran vivant avec cap du jour dynamique**.

Non-goals explicites (deferred) :
- JITAI nudges → ADR "killed for doctrine violation" + service conservé en code
- MilestoneCelebrationSheet → ADR "killed for doctrine violation"
- StreakService → ADR "killed for doctrine violation"
- WeeklyRecap → Wave C (après event plumbing scan→coach)
- Widgets secondaires `profile.age` migration (25+ call-sites coach_narrative, etc.) → Wave E
- Orphan providers delete (UserActivity/ContextualCard/CoachEntryPayload) → Wave E
- Goldens 4 profils → Wave F (1 golden Julien post-commit suffit)

## Les 4 commits atomiques

### B0 — Unblock tab Aujourd'hui + empty-state partial-onboarded (1.5h)

**Problème** :
- `app.dart:336-338` → `auth.isLoggedIn ? AujourdhuiScreen : LandingScreen`
- `AuthProvider.dart:87` comment intent `isLoggedIn || isLocalMode`
- Wave 0 walkthrough : fresh anonymous → tap tab Aujourd'hui → landing redirect
- Panel archi A5 : profile vide → écran presque vide, friction UX honnête

**Fix** :
- `app.dart:336-338` : remplacer par `return (auth.isLoggedIn || auth.isLocalMode) ? AujourdhuiScreen : LandingScreen`
- `AujourdhuiScreen` : ajouter widget empty-state "Pour commencer" visible si `profile.confidence < 0.3` avec 3 CTA : Scanner un doc / Parle au coach / Complète ton profil
- Empty-state auto-hide dès confidence ≥ 0.3
- Cold launch reste `initialLocation: '/'` → LandingScreen (panel iconoclaste : "Wave 0 findings = tab cassé, pas cold launch")

**Fichiers** :
- `apps/mobile/lib/app.dart:336-338`
- `apps/mobile/lib/screens/aujourdhui/aujourdhui_screen.dart` (ajout section empty-state)
- `apps/mobile/lib/widgets/aujourdhui/partial_onboarded_empty_state.dart` (nouveau)

**Tests** :
- `test/app_routing_home_gate_test.dart` (nouveau) :
  - `isLoggedIn=false, isLocalMode=true` → AujourdhuiScreen rendered (pas landing)
  - `isLoggedIn=false, isLocalMode=false` → LandingScreen rendered
  - Logout scenario (isLoggedIn=true puis logout) → `auth_local_mode=false` persisted, router → Landing
  - Profile confidence=0.1 → empty-state widget visible
  - Profile confidence=0.5 → empty-state widget hidden

**Gate B0** : Tests passants, fresh install tap tab Aujourd'hui → AujourdhuiScreen + empty-state CTA visible.

---

### B6-minimal — `profile.ageOrNull` + CapEngine migration + backend range check (2h)

**Problème** :
- Panel archi R1 : `CoachProfile.age` clamp à 0 sur invalid birthYear, 30+ call-sites consomment sans guard
- Panel adversaire BUG 4 : CapEngine.dart a 10 `profile.age` (lignes 150, 192, 224, 274, 288, 318, 358, 569, 926, 1139). Age=0 sentinel fait silencieusement `age >= 45 → false`, supprime lpp_buyback cap pour 48yo sans birthYear. **B1 shippe un cap du jour silencieusement faux si B6 pas fait avant.**
- Panel archi A3 : backend `_coerce_fact_value` (coach_chat.py:1004) n'a aucun range check numérique, `save_fact birthYear=2099` persiste silencieusement

**Fix** :
- `CoachProfile.ageOrNull` getter returns `int?` (null si birthYear/dateOfBirth invalides/absents/futurs)
- `cap_engine.dart` 10 call-sites migrent vers `profile.ageOrNull` :
  - Si `ageOrNull == null` → la règle concernée SKIP avec log `logger.info('cap rule X skipped: age unknown')`
  - Le cap fallback "Parle-moi de toi" devient prioritaire si règles âge-dépendantes skipped
- `services/backend/app/api/v1/endpoints/coach_chat.py:_coerce_fact_value` :
  - `if key == "birthYear": if value < 1900 or value > currentYear + 1: return None`
  - Même pattern pour `spouseBirthYear`, `dateOfBirth` (YYYY-MM-DD range check)
- 5 simulateurs bloquants (libre_passage / provider_comparator / rachat_echelonne / independant / ijm) migrent aussi vers `ageOrNull` + bannière "Âge inconnu — complète ton profil" (reporté d'original plan v1 B6, scope restant car prereq direct B1)

**Fichiers** :
- `apps/mobile/lib/models/coach_profile.dart` (ageOrNull getter)
- `apps/mobile/lib/services/cap_engine.dart` (10 call-sites)
- `apps/mobile/lib/screens/pillar_3a_deep/provider_comparator_screen.dart:49`
- `apps/mobile/lib/screens/rachat_echelonne_screen.dart:186` (vérifier path exact)
- `apps/mobile/lib/screens/independant_screen.dart:68`
- `apps/mobile/lib/screens/ijm_screen.dart:45`
- `apps/mobile/lib/screens/libre_passage_screen.dart` (path à vérifier)
- `services/backend/app/api/v1/endpoints/coach_chat.py:_coerce_fact_value`

**Tests** :
- `test/models/coach_profile_age_null_test.dart` :
  - birthYear=null → ageOrNull=null
  - birthYear=2099 → ageOrNull=null (future)
  - birthYear=1800 → ageOrNull=null (too old)
  - birthYear=1977 → ageOrNull=49
  - dateOfBirth="2099-01-01" → ageOrNull=null
- `test/services/cap_engine_age_skip_test.dart` :
  - profile ageOrNull=null → règles age-dependent skip, cap fallback "Parle-moi de toi" returned
  - profile ageOrNull=49 → règles normales (ex: lpp_buyback priorisé pour Julien)
- `services/backend/tests/test_save_fact_birthYear_range.py` :
  - save_fact birthYear=2099 → None returned, not persisted
  - save_fact birthYear=1800 → None returned
  - save_fact birthYear=1977 → persisted
- Widget tests 5 simulateurs : profile sans âge → bannière "Âge inconnu" visible

**Gate B6-minimal** : flutter analyze 0 err, nouveaux tests green, 5 simulateurs + CapEngine gracieux sans âge, backend birthYear 2099 rejeté.

---

### A2+B1 — MintStateProvider proxy + CapEngine top banner (2.5h)

**Problème** :
- Panel archi R1 : `MintStateProvider` est `ChangeNotifierProvider` plain (`app.dart:1251`), pas proxy sur `CoachProfileProvider`. `mint_state_engine.currentCap` cached mais jamais refresh sur profile change. Si user save_fact canton=VS → cap stale (ZH fallback).
- Panel daily-loop : home affiche 3 TensionCards statiques + pas de cap du jour. CapEngine (1333 lignes) jamais branché home.

**Fix** :
- `app.dart` : convertir `ChangeNotifierProvider<MintStateProvider>` en `ChangeNotifierProxyProvider<CoachProfileProvider, MintStateProvider>` avec `update: (ctx, profileProv, state) => state!..recompute(profileProv.profile)`
- `AujourdhuiScreen` : ajouter `SliverToBoxAdapter` top banner "Cap du jour" qui `context.watch<MintStateProvider>()` et affiche `state.currentCap`
- Nouveau widget `CapDuJourBanner` réutilisable :
  - Titre (icon + label cap)
  - 1 ligne description (`cap.message`)
  - 1 CTA vers route (`cap.routeHint` ex: `/rachat-lpp`)
  - Fallback si `currentCap == null` : "Aide-moi à mieux t'aiguiller. Parle-moi de toi."
- Position sur home : au-dessus des TensionCards existantes (garde TensionCards en place, additif pur)

**Fichiers** :
- `apps/mobile/lib/app.dart:1251` (proxy provider conversion)
- `apps/mobile/lib/providers/mint_state_provider.dart` (vérifier `recompute` existe, sinon ajouter)
- `apps/mobile/lib/screens/aujourdhui/aujourdhui_screen.dart` (nouveau SliverToBoxAdapter cap banner)
- `apps/mobile/lib/widgets/aujourdhui/cap_du_jour_banner.dart` (nouveau)

**Tests** :
- `test/providers/mint_state_provider_proxy_test.dart` (nouveau) :
  - Init → recompute called with initial profile
  - CoachProfileProvider.notifyListeners() → recompute called again with new profile
  - Stale cap scenario : save_fact canton=VS → currentCap refreshed (prouve R1 fixé)
  - Concurrent recompute (10 notifyListeners rapid) → final state matches last profile
- `test/widgets/aujourdhui/cap_du_jour_banner_test.dart` (nouveau) :
  - Profile Julien (VS 49 LPP 70k) → cap `lpp_buyback` ou `pillar_3a` affiché
  - Profile fresh anonymous → fallback "Parle-moi de toi"
  - Tap CTA → navigation vers `/rachat-lpp` via GoRouter (mock)
- Golden test `aujourdhui_julien_golden.dart` (1 seul pour Wave B-minimal, les 3 autres profils en Wave F)

**Gate A2+B1** : flutter analyze 0 err, stale cap test green, golden test Julien pass, device walkthrough home Julien → cap `lpp_buyback` visible + CTA fonctionne.

---

### B-ship — Device walkthrough + PR (0.5h)

**Procedure** :
- Build iPhone 17 Pro sim staging : `flutter build ios --simulator --debug --no-codesign --dart-define=API_BASE_URL=https://mint-staging.up.railway.app/api/v1`
- Install + launch
- Scenarios :
  1. Cold launch → LandingScreen (inchangé)
  2. Tap CTA "Parle à Mint" → choice-of-tone + coach chat
  3. Tap tab Aujourd'hui → **AujourdhuiScreen avec empty-state CTA** (pas landing redirect — prouve B0)
  4. Manuellement save_fact via coach : "j'ai 49 ans, je vis à Sion avec 122k CHF brut, LPP 70k" → attendre 3-5 save_fact
  5. Tap tab Aujourd'hui → cap du jour banner visible avec cap `lpp_buyback` ou `pillar_3a` (prouve A2+B1 + B6-minimal)
  6. Tap cap CTA → navigation vers simulateur cible
- AX tree ≤ 3 screenshots : empty-state, cap banner Julien, cap banner fresh
- Log dans `.planning/wave-b-home-orchestrateur/EXECUTION-LOG.md` + findings dans `.planning/wave-b-home-orchestrateur/DEVICE-WALKTHROUGH.md`

**PR creation** :
- `gh pr create --base dev --head feature/wave-b-home-orchestrateur` avec description narrative :
  - Wave B-minimal : 4 commits, ship-and-observe
  - Refs : REVIEW-PLAN.md (3 panels) + ADR-20260418-wave-order-daily-loop
  - Post-merge : 5 jours observation + ADR-20260419 killed layers (B2/B3/B5)
- Attendre CI 10/10 green, merge merge-commit

**Gate B-ship** : CI green, PR mergée, MEMORY.md handoff updated.

---

## Gates mécaniques sortie Wave B-minimal (17 points)

1-14. (inchangés de Wave A) : flutter analyze / tests / ARB / CI / banned / sentinels / catch / façade / device walkthrough / MEMORY.md / no_chiffre_choc / OpenAPI / Alembic / Regression baseline
15. **Logout regression test** : fresh login → logout → router → LandingScreen (auth_local_mode=false persisté)
16. **MintStateProvider refresh test** : save_fact canton=VS → currentCap refreshed
17. **Empty-state partial-onboarded** : profile.confidence<0.3 → CTA visible + no crash

## Risques identifiés

| Risque | Mitigation | Source |
|---|---|---|
| B0 fix casse logout (BUG 1 adversaire) | Test explicite logout + fallback defensive si purge ratée | Panel adversaire |
| R1 CapEngine stale cache | A2 proxy provider (B1 prereq) | Panel archi |
| CapEngine age=0 silencieux (BUG 4) | B6-minimal migration 10 call-sites cap_engine.dart + skip-with-log | Panel adversaire |
| Backend birthYear=2099 (A3) | _coerce_fact_value range check | Panel archi |
| LandingScreen code mort | Iconoclaste prouve que cold launch reste Landing — pas besoin de flag | Panel iconoclaste |
| Empty-state widget sur fresh → écran vide | Empty-state avec 3 CTA concrets (scan, coach, profile) | Panel archi A5 |
| Scope creep Wave B-minimal | Strict 4 commits, ADR follow-up pour tout kill | Panel iconoclaste |

## Verification plan (goal-backward)

**Goal Wave B-minimal** : Julien (après PRIV-07 mergé + Wave B-minimal mergé) ouvre MINT pour la 3e fois (profile chargé avec canton+age+salaire+LPP). Il tape tab Aujourd'hui. Voit :
1. Un écran vivant AujourdhuiScreen (pas landing)
2. Banner cap du jour : "Ton rachat LPP max ~539k CHF. En VS, 50k/an économise ~13k d'impôts. Tu veux simuler ?" + CTA `/rachat-lpp`
3. Timeline en bas avec ses commitments/scans passés

Si tap CTA → simulateur avec prefill profile → math correct.

Si profile est encore vide → empty-state "Pour commencer" avec 3 CTA clairs.

## Après Wave B-minimal

- Merge → dev via merge-commit
- MEMORY.md handoff : "Wave B-minimal shipped (4 commits), home vivant, cap du jour fonctionnel"
- 5 jours observation via device Julien
- Rédiger `ADR-20260419-killed-gamification-layers.md` : justification doctrine lucidité incompatible avec JITAI creepy / Milestone Duolingo / Streak Duolingo
- Décision Wave B' : enrichissements selon signal Julien réel OU sauter directement Wave A-prime (notifs wiring)

## ADR follow-up (post-Wave-B)

- `ADR-20260419-killed-gamification-layers.md` : kills B2 JITAI creepy triggers, B3 MilestoneCelebrationSheet, B5 StreakService visibility. Justification panel iconoclaste + doctrine pivot 2026-04-12 "lucidité pas protection/dopamine". Services conservés en code (réutilisation potentielle autres contextes), mais non-câblés home.
