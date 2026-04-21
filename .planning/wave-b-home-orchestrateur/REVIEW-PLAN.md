# REVIEW-PLAN — Wave B-prime : consolidation 3 panels

**Date** : 2026-04-18
**Panels** : Architecture (Stripe/Flutter Google/fintech mobile), Adversaire ("200 IQ autistic"), Iconoclaste (Arc/Things 3/Swiss fintech)

## Verdicts bruts

| Panel | Verdict | Position |
|---|---|---|
| Architecture | **SPLIT** (B-prime-1 + B-prime-2) + 2 REWORKS | Scope trop large, B0 sémantique fragile, CapEngine stale cache R1, test weekly_recap R2 |
| Adversaire | **REWORK** | 5 bugs prod concrets : logout R1, JITAI boucle I/O R2, weekly API divergence R3, CapEngine age 10 call-sites R4, Milestone overlap R5 |
| Iconoclaste | **Wave B-MINIMAL 3 commits** | Violation identitaire B3/B5, territoire Cleo B2, B4 fade sans event plumbing Wave C, B6/B7 technique pure Wave E |

**Verdict consolidé : REWORK PROFOND → Wave B-minimal enrichi (4-5 commits).**

Les 3 panels convergent : **B2, B3, B5 sont du bruit**, certains même dangereux (violation doctrine lucidité, territoire Cleo). Les seuls signaux vrais sont **B0 (unblock) + B1 (CapEngine)**, avec **B6-minimal** en prerequisite technique pour que B1 ne ship pas de caps silencieusement faux.

## Matrice des enjeux croisés

| Enjeu | Archi | Adversaire | Iconoclaste |
|---|---|---|---|
| B0 `isLoggedIn \|\| isLocalMode` | ✗ régresse Landing | ✗ logout bug (purge partielle) | ✓ tel quel OK car landing via cold launch |
| A2 MintStateProvider → proxy (R1) | ✗ prereq critique | — | — |
| B1 CapEngine top banner | ✓ si proxy | ✗ age stale sur 10 cap_engine.dart call-sites | ✓ le seul widget qui justifie le tab |
| B2 JITAI evaluate | — memoize | ✗ boucle I/O 30rebuild/s | **KILL** territoire Cleo, birthday trigger creepy |
| B3 MilestoneCelebrationSheet | — | ✗ overlap timing premier_eclairage 20s | **KILL** violation doctrine "VZ brain + Aesop" |
| B4 WeeklyRecap consolidation | ✗ test coach/ cassé | ✗ API divergente `generate` vs `generateRecap` | Defer Wave C (fade sans events) |
| B5 StreakService compact | — | — | **KILL** registre Duolingo |
| B6 ageOrNull | ✗ enforce upstream backend `_coerce_fact_value` | ✗ **CapEngine 10 call-sites DOIT être dans Wave B avant B1** | Defer Wave E |
| B7 orphan providers | ✗ delete + update tests (pas commenter) | ✗ side-effect `loadAll()` chain | Defer Wave E |
| B8 golden 4 profils | ✗ scope 2h, 4 refresh si Wave évolue | — | 1 profil post-ship, pas 4 pré-stabilisation |
| Empty-state partial-onboarded | ✗ ajouter pour Julien "fresh anonymous" | — | — |

## Décisions tranchées

### D1 — Wave B redéfinie : Wave B-minimal (4 commits, ~6-7h)

**Garde** :
- B0 (fix gate)
- A2 (MintStateProvider proxy, prereq R1 archi) — **prereq de B1, fusionné en un commit avec B1** pour shipper le couple proxy+consumer
- B6-minimal (ageOrNull + CapEngine migration 10 call-sites + backend range check)
- B1 (CapEngine top banner, dépend de A2 + B6-minimal)

**Kill/Defer** :
- B2 JITAI → **ADR follow-up "JITAI deferred, doctrine review required"**
- B3 MilestoneSheet → **ADR follow-up "gamification incompatible MINT doctrine lucidité"**
- B4 WeeklyRecap → **Wave C** (après event plumbing scan→coach)
- B5 StreakService → **ADR follow-up "streak registre Duolingo incompatible"**
- B6 widgets secondaires (25+ call-sites coach_narrative + widgets) → **Wave E**
- B7 orphan providers → **Wave E** (pure hygiène technique)
- B8 goldens 4 profils → **1 profil Julien post-commit, goldens 4 profils en Wave F**

### D2 — Risques mitigés

**R1 archi (CapEngine stale cache)** : A2 commit → `ChangeNotifierProxyProvider<CoachProfileProvider, MintStateProvider>` avec `update` qui appelle `recompute(profileProv.profile)` à chaque notifyListeners. Test regression : save_fact canton → state.currentCap refreshed.

**R1 adversaire (logout bug)** : B0 commit ajoute test logout scenario (`_isLoggedIn=false, _isLocalMode=false après logout`), asserte `prefs.auth_local_mode=false` persisted. Si prefs.clear() fail, fallback defensive : guard `if _purgePartialFailed { router → LandingScreen anyway }`.

**R4 adversaire (CapEngine age)** : B6-minimal migre les 10 call-sites de `cap_engine.dart` : `profile.age` → `profile.ageOrNull ?? _defaultAge` avec `_defaultAge` = valeur explicite documentée par règle (ex: 40 pour `age >= 45` early-warning). Sinon : cap supprimée silencieusement via `ageOrNull == null → skip rule`. Ajouter assertion dans CapEngine que `ageOrNull == null → skip_rule_with_log`.

**A3 archi (backend range check)** : B6 commit ajoute `if key == "birthYear": if value < 1900 or value > current_year + 1: return None` dans `_coerce_fact_value` coach_chat.py:1004.

**R3 adversaire (weekly_recap API divergence)** : **B4 déplacé en Wave C**. Wave B ne touche plus weekly_recap.

**Landing preservation (archi A1)** : Iconoclaste a raison — cold-launch (`initialLocation: '/'`) AFFICHE toujours LandingScreen. B0 ne touche QUE le behavior du tab `/home`. LandingScreen reste vivante. **Pas besoin de flag `first_seen_landing`.** Décision : B0 reste simple `isLoggedIn || isLocalMode`.

### D3 — Plan final Wave B-minimal (4 commits)

**B0** (1.5h) — Unblock tab Aujourd'hui + logout safe
- `app.dart:336-338` → `(auth.isLoggedIn || auth.isLocalMode) ? AujourdhuiScreen : LandingScreen`
- AujourdhuiScreen : ajouter empty-state widget "Pour commencer" visible si `profile.confidence < 0.3` (3 CTA : scan / parle coach / finis profile)
- Tests : logout scenario, fresh anonymous scenario, empty-state visibility

**B6-minimal** (2h) — ageOrNull + CapEngine migration + backend range check
- `CoachProfile.ageOrNull` getter (returns `int?`)
- `cap_engine.dart` : 10 call-sites migrent `profile.age` → `profile.ageOrNull`, chaque règle documente fallback explicite ou skip-with-log
- `coach_chat.py:_coerce_fact_value` : range check birthYear (1900 ≤ value ≤ currentYear+1)
- Tests : birthYear=null/2099/1977 → null/null/49, save_fact birthYear=2099 rejected, CapEngine skip_rule si ageOrNull null

**A2+B1** (2.5h) — MintStateProvider proxy + CapEngine top banner
- `app.dart:1251` : `ChangeNotifierProxyProvider<CoachProfileProvider, MintStateProvider>` avec `update: (ctx, p, state) => state!..recompute(p.profile)`
- `AujourdhuiScreen` : top banner "Cap du jour" alimenté par `mintState.currentCap` via `context.watch<MintStateProvider>()`
- Widget : `cap_du_jour_banner.dart` réutilisable (titre + 1 ligne + 1 CTA vers route `cap.routeHint`)
- Tests : save_fact canton=VS → state.currentCap refreshed (R1 archi), golden test Julien→cap `lpp_buyback` ou `pillar_3a`

**B-ship** (0.5h) — Device walkthrough iPhone 17 Pro + PR
- Cold launch, tap CTA, tap tab Aujourd'hui → AujourdhuiScreen visible (pas landing redirect)
- Avec profile Julien préloaded (via manual save_fact côté coach) → cap visible, CTA fonctionne
- AX tree + 2 screenshots min
- PR `feature/wave-b-home-orchestrateur` → dev merge-commit

## Gates mécaniques révisés (14 points)

Inchangés (1-14) vs plan précédent. Ajout :
15. **Logout regression test** : fresh install + login + logout → LandingScreen (pas AujourdhuiScreen avec data fantôme)
16. **MintStateProvider refresh test** : save_fact canton=VS → currentCap != currentCap_before (state frais)
17. **Empty-state visible test** : profile sans confidence → "Pour commencer" section visible sur AujourdhuiScreen

## Tests adversariels non-négociables

1. Logout scenario : user login VS → logout → router → LandingScreen. prefs.auth_local_mode=false.
2. Backend birthYear range : save_fact birthYear=2099 → coerce returns None, profile unchanged.
3. MintStateProvider concurrent recompute : 10 rapid save_fact → final state matches last profile.
4. CapEngine age skip : profile ageOrNull=null → règles age-dependent skip sans crash, cap fallback rendu.
5. Partial onboarded : profile vide + isLocalMode=true → AujourdhuiScreen + empty-state CTA + 0 crash.

## Feature flags (rollback)

- `RemoteConfig.getBool('home.unblock_local_mode', default: true)` : kill-switch pour réactiver landing gate.
- Pas de feature flag pour CapEngine wiring (trop intrusif à rollback).

## Décision finale exécution

1. **Attendre merge PR #353 hotfix PRIV-07** dans dev
2. **Créer branche `feature/wave-b-home-orchestrateur` depuis dev frais**
3. EXECUTE Wave B-minimal 4 commits dans l'ordre B0 → B6-minimal → A2+B1 → B-ship
4. 4 panels audit post-exec
5. Fixes si findings
6. Ship

**Post-Wave-B** : 5 jours d'observation + feedback Julien avant de lancer Wave C. Entre-temps, rédiger ADR follow-up tuant B2/B3/B5 avec justification doctrine.

## ADR follow-up à rédiger

- `ADR-20260419-killed-gamification-layers.md` : tue JITAI creepy triggers (birthday/anniversary/salary_day), MilestoneSheet Duolingo, StreakService Duolingo. Justification : doctrine lucidité 2026-04-12 incompatible avec dopamine loop. Services conservés en code (ne pas delete, potentiellement réutilisables pour d'autres contextes), mais désactivés côté home.
