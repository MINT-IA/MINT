# PLAN — Wave A-MINIMAL : Scan event + deadline notifs only

**Version** : 2 (post 3-panel review 2026-04-18, voir `REVIEW-PLAN.md`)
**Branche** : `feature/wave-a-notifs-wiring` (créée depuis dev @ 91628ada post Wave B merge)
**Durée estimée** : 2h30 (4 commits : A0 backend + A1 Dart event + A2 minimal schedule + A3 device)
**PR cible** : `feature/wave-a-notifs-wiring` → `dev` (merge-commit)

## Changelog v1 → v2

3 panels ont tranché pour **Wave A-MINIMAL** :
- Panel archi : `_idWeeklyRecap` n'existe pas (plan v1 factuellement faux), backend tests enum fermé
- Panel adversaire : 5 bugs prod-bound dont B1 backend `coach_tools.py:470` rejette `event`
- Panel iconoclaste : J+1/J+7/J+30 + weekly engagement = Duolingo-redéguisé, violation doctrine lucidité + ADR-20260419

**Supprimés** : J+1/J+7/J+30 retention notifs, weekly engagement lundi 19h, RemoteConfig stub, ARB 6 langs new keys.
**Conservés** : scan → CoachInsight event (valeur composée mémoire), 3a deadlines, tax deadlines, monthly check-in (services réels où user perd argent).

## Goal

1. Coach se souvient du scan LPP : quand Julien revient 3 jours après avoir scanné, le coach peut dire "tu as scanné ton certificat CPE mardi — on parle de rachat ?"
2. Julien reçoit des rappels sur ses deadlines fiscales réelles (3a 31/12, tax 15/03) s'il n'a pas check-in ce mois.

## Non-goals (explicites)

- Retention notifs J+1/J+7/J+30 → killed ADR follow-up
- Weekly engagement push lundi 19h → killed (pointe vers écran vide Wave C)
- RemoteConfig flag → non nécessaire (pas de code kill-switchable dans cette Wave)
- Sync events vers backend → v1 local-only
- coach_narrative_service.dart 13 `profile.age` call-sites → Wave E
- weekly_recap double consolidation → Wave E

## Pre-flight validé

| Pré-requis | État |
|---|---|
| `profile.ageOrNull` | ✓ Wave B 7a28fbeb |
| save_fact PII | ✓ PRIV-07 583b5e6d |
| Backend `CoachInsightRecord.insight_type` = `Column(String)` | ✓ accepte String libre, pas de migration |
| Backend `coach_tools.py:470` save_insight enum | **BLOQUANT** : `["goal","decision","concern","fact"]`, doit accepter `event` — commit A0 |
| Backend tests enum fermé | `test_profile_extractor.py:231`, `test_coach_tools_categories.py:309-315` — commit A0 |
| IDs NotificationService | 7 IDs concrets : `_idCheckinMonthly=1000`, `_idCheckinReminder5d=1001`, `_idStreakProtection=2000`, `_id3aDeadlineBase=3000`, `_idTaxDeadlineBase=4000` |
| `CoachMemoryService.hasInsight/hasEvent` | À ajouter dans A1 |

## Les 4 commits atomiques

### A0 — Backend `coach_tools.py` enum accepte `event` (15 min)

**Finding** : Panel adversaire B1 — Anthropic API rejette tool_use `save_insight(type="event")` si schema enum ne contient pas `event`. Panel archi AJ-2 — tests backend asserts enum fermé.

**Scope** :
- `services/backend/app/services/coach/coach_tools.py:470` → dans `save_insight.input_schema.properties.type.enum`, ajouter `"event"`. Documenter dans description "event = structured event the user experienced (scan, life event)".
- `services/backend/tests/test_coach_tools_categories.py:309-315` → update allowlist set to `{"goal", "decision", "concern", "fact", "event"}`.
- `services/backend/tests/test_profile_extractor.py:231` → update assertion `{fact, decision, preference, concern}` → `{fact, decision, preference, concern, event}`.
- `services/backend/app/services/rag/insight_embedder.py:37` → update doc comment to list 5 values.

**Fichiers** :
- `services/backend/app/services/coach/coach_tools.py`
- `services/backend/tests/test_coach_tools_categories.py`
- `services/backend/tests/test_profile_extractor.py`
- `services/backend/app/services/rag/insight_embedder.py` (doc comment only)

**Tests** :
- Existing tests updated, pytest full coach/ privacy/ green.
- New test in `test_coach_tools_categories.py` asserting `"event" in enum` for save_insight (regression guard).

**Gate A0** : pytest `tests/coach/ tests/test_coach_tools_categories.py tests/test_profile_extractor.py tests/privacy/` → 100% green. Anthropic API CI test (if exists) passes with a mock `save_insight(type="event")` call.

---

### A1 — `InsightType.event` + scan → saveEvent non-pruned namespace (50 min)

**Findings** :
- Panel simulation : `document_impact_screen.dart` n'appelle pas saveInsight — coach ne peut jamais référencer le scan
- Panel adversaire B5 : FIFO 50 évince le scan event après ~1 semaine d'activité (claude_coach_service.py system prompt ordonne save_insight à chaque info clé)
- Panel archi AJ-2 : events local-only (pas de sync backend) = simplification

**Scope** :
- `apps/mobile/lib/models/coach_insight.dart:24-36` → add `event` to `InsightType` enum after `fact`
- `apps/mobile/lib/services/memory/coach_memory_service.dart` :
  - New private key `_eventsKeyFor(userId) => '_coach_events_$userId'`
  - New `saveEvent(String topic, String summary, {DateTime? date})` — persist to `_coach_events_$uid` SharedPreferences list, no pruning, dedup by (topic + date-day)
  - New `hasEvent(String topic, {int maxAgeDays = 365})` — read list, return true if any matching topic within age
- `apps/mobile/lib/screens/document_scan/document_impact_screen.dart` :
  - After `_fetchPremierEclairage` returns success (regardless of whether eclairage itself is non-empty), call `CoachMemoryService.saveEvent(topic: 'scan_lpp', summary: _buildSummary(profile))`
  - `_buildSummary` returns `'{caisse} — {avoirFormatted} CHF'` with fallbacks for null caisse/avoir ("certificat LPP scanné — caisse inconnue" or "...avoir inconnu")
- Do NOT sync events to backend (flag `syncToBackend=false`). v1 local-only. Documented in saveEvent.

**Fichiers** :
- `apps/mobile/lib/models/coach_insight.dart`
- `apps/mobile/lib/services/memory/coach_memory_service.dart`
- `apps/mobile/lib/screens/document_scan/document_impact_screen.dart`

**Tests** :
- `test/models/coach_insight_event_test.dart` : enum round-trip event → event, orElse fallback `fact` for unknown
- `test/services/memory/coach_memory_event_test.dart` :
  - saveEvent → hasEvent(topic, maxAgeDays=30) true
  - saveEvent 2× same topic same day → 1 stored (dedup)
  - saveEvent 400 days ago → hasEvent(topic, maxAgeDays=365) false
  - fact insights don't show up in hasEvent queries (namespace isolation)
  - pushing 100 fact insights doesn't evict events (separate FIFO)
- `test/screens/document_scan/document_impact_event_save_test.dart` : widgetTest scan success → saveEvent called once with correct topic

**Gate A1** : flutter analyze 0 new issues, 10+ new tests green, device walkthrough scan → local storage has event entry.

---

### A2 — `scheduleCoachingReminders` wired (minimal set) (75 min)

**Findings** :
- Panel archi AJ-1 : liste 7 IDs concrets (pas `_idWeeklyRecap` fictif), `_cancelCoachingIds()` helper
- Panel adversaire B2+B3 : `_markOnboardingCompletedIfNeeded` fire ONCE, save_fact re-trigger nécessaire via CoachProfileProvider listener
- Panel iconoclaste : garder uniquement deadlines + monthly check-in (services), kill retention + weekly engagement

**Scope** :
- `apps/mobile/lib/services/notification_service.dart` :
  - Remove `cancelAll()` call in `scheduleCoachingReminders` (line 309), replace with `_cancelCoachingIds()`:
    ```dart
    Future<void> _cancelCoachingIds() async {
      if (_plugin == null) return;
      await _plugin!.cancel(_idCheckinMonthly);
      await _plugin!.cancel(_idCheckinReminder5d);
      await _plugin!.cancel(_idStreakProtection);
      for (int i = 0; i < 4; i++) await _plugin!.cancel(_id3aDeadlineBase + i);
      for (int i = 0; i < 3; i++) await _plugin!.cancel(_idTaxDeadlineBase + i);
    }
    ```
  - Remove calls to `_scheduleWeeklyRecap` and any retention scheduling inside `scheduleCoachingReminders`
  - Keep : `_scheduleMonthlyCheckin(profile, now, s)` + `_schedule3aDeadlines(profile, now, s)` + `_scheduleTaxDeadlines(now, s)`
  - Add triad gate at top (after consent check):
    ```dart
    if (profile.birthYear < 1900 ||
        profile.canton.isEmpty ||
        profile.salaireBrutMensuel <= 0) {
      logger.info('scheduleCoachingReminders skipped: incomplete triad');
      return;
    }
    ```
- `apps/mobile/lib/app.dart` :
  - In MultiProvider tree, after `CoachProfileProvider`, add a `_NotificationsWiringObserver` widget or Consumer that listens to profile changes, debounces 500ms, and calls `NotificationService.scheduleCoachingReminders(profile)` when triad transitions false→true
  - Pattern : `Consumer<CoachProfileProvider>` with `builder` that calls via WidgetsBinding.instance.addPostFrameCallback + debouncer service instance
- `apps/mobile/lib/screens/coach/coach_chat_screen.dart:252` : keep existing `_markOnboardingCompletedIfNeeded` call to schedule (defensive redundant wiring for onboarding intent path)
- NO new ARB keys (existing 3a/tax/checkin localization already shipped)

**Fichiers** :
- `apps/mobile/lib/services/notification_service.dart` (refactor)
- `apps/mobile/lib/app.dart` (add listener wiring)
- `apps/mobile/lib/screens/coach/coach_chat_screen.dart` (light edit to ensure call path)

**Tests** :
- `test/services/notification_triad_gate_test.dart` :
  - profile birthYear=0 → schedule short-circuit, no plugin calls
  - profile canton='' → short-circuit
  - profile salaireBrut=0 → short-circuit
  - triad complete → `_cancelCoachingIds` called + `_scheduleMonthlyCheckin` + `_schedule3aDeadlines` + `_scheduleTaxDeadlines` called
- `test/services/notification_cancel_per_id_test.dart` :
  - Before refactor : mock plugin records cancelAll called
  - After refactor : mock plugin records 3 + 4 + 3 cancel(id) calls (10 total), not cancelAll
  - Commitments/freshStarts scheduled separately remain after re-schedule (regression guard against cancelAll regression)
- `test/app/coach_profile_listener_reschedule_test.dart` :
  - Mount MultiProvider, CoachProfileProvider with triad incomplete, advance time 500ms → no schedule
  - Update profile (save_fact canton) → triad complete → after 500ms debounce, schedule called
  - Update profile again (irrelevant field like `nombreEnfants`) → no re-schedule (triad already scheduled signature unchanged)

**Gate A2** : flutter analyze 0 new issues, new tests green, cap_engine existing tests unchanged (57 pass), home_gate_contract tests green.

---

### A3 — Device walkthrough + commit + PR (20 min)

**Procedure** :
- Build iOS sim staging
- Fresh install anonymous
- Open coach, tap CTA Parle à Mint
- Via coach : "j'ai 49 ans, je vis à Sion, je gagne 122 000 brut par an" → 3× save_fact
- Verify via logger/Sentry breadcrumb that `scheduleCoachingReminders` fired after 3rd save_fact (500ms debounce)
- Tap tab Aujourd'hui → cap banner visible (Wave B)
- Navigate to `/scan`, trigger mock scan or bypass via debug menu
- Verify SharedPreferences key `_coach_events_${userId}` has scan_lpp entry
- Exit + reopen app → verify notifications are scheduled (iOS simctl: `xcrun simctl spawn <udid> notifyutil -d` or similar)
- AX tree capture + 2 screenshots (scan debrief + home with cap)

**Commit + push + PR** :
- Final commit for any last polish
- `gh pr create --base dev --head feature/wave-a-notifs-wiring` with full description
- Wait CI green, merge merge-commit
- Update MEMORY.md handoff

**Gate A3** : PR CI 10/10 green, device walkthrough validated, memory updated.

---

## Gates mécaniques sortie Wave A-MINIMAL (16 points)

1-14 : (hérités Wave B) flutter analyze / tests / ARB / CI / banned / sentinels / catch / façade / device / MEMORY.md / no_chiffre_choc / OpenAPI / regression
15. **Triad gate contract** : profile incomplet → 0 schedule fired + log
16. **Backend enum extended** : save_insight type='event' accepted + tests regenerated

## Risques résiduels

| Risque | Mitigation |
|---|---|
| CoachProfileProvider listener cascade rebuilds | debounce 500ms + track last-scheduled-triad signature (skip if unchanged) |
| saveEvent 2× same scan same day | dedup dans saveEvent (topic+date-day) |
| A0 merge before A1 Dart for Anthropic CI compat | A0 + A1 dans **même PR**, même commit tête (A0) → gate "backend tests pass" avant A1 push |
| `_cancelCoachingIds` oublie un ID | test enumère explicitement les 7 expected cancels + regression guard "no cancelAll" |
| Device walkthrough sans time-travel | logger/Sentry breadcrumb suffit pour valider l'appel, algo testé en unit |
| iOS Background Refresh disabled | fallback log explicite, doc dans commit message |

## Verification plan (goal-backward)

**Goal** : Julien fresh install → ouvre coach → save_fact age/canton/salaire via conversation → scheduleCoachingReminders fire automatiquement (via CoachProfileProvider listener debounce) → 31 déc approche, notif "Ton 3a : dernier jour" fire. 15 mars approche, notif tax fire. Le 1er de chaque mois, check-in reminder fire.

En parallèle : Julien scanne certificat CPE → saveEvent persisté dans `_coach_events_` local storage → 3 jours plus tard coach ouvert → `hasEvent(scan_lpp, 30d)` true → coach peut référencer "tu as scanné hier" dans réponse (via `retrieve_memories` tool backend, si sync-backend enabled plus tard; pour v1 local-only, l'event vit dans le profil mobile et peut informer coach via context).

Si tous commits shipped + gates green + device walkthrough réussi → goal atteint.

## Post Wave A-MINIMAL

- Merge → dev merge-commit
- MEMORY.md handoff : "Wave A-MINIMAL shipped, deadlines + scan event only, retention/weekly killed"
- Observer 14 jours, collecter signal Julien
- Si besoin : Wave A' ajouter retention avec contenu net personnalisé
- Démarrer Wave C (scan handoff coach + suggestion chip regex)

## ADR follow-up à rédiger

- `ADR-20260419-killed-retention-notifs.md` : kill J+1/J+7/J+30 retention + weekly engagement. Same doctrine : ADR-20260419 tué Duolingo layers, ADR follow-up confirme retention nag = registre doublon. Services (`NotificationService.scheduleRetentionNotifications`, `_scheduleWeeklyEngagementPing`) conservés en code mais non-câblés home/coach.
