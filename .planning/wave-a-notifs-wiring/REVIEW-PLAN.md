# REVIEW-PLAN — Wave A-prime : consolidation 3 panels

**Date** : 2026-04-18
**Panels** : Architecture (Stripe/Flutter Google/fintech mobile), Adversaire ("200 IQ autistic"), Iconoclaste (Arc/Things 3/Swiss fintech)

## Verdicts bruts

| Panel | Verdict | Angle |
|---|---|---|
| Architecture | REWORK (3 ajustements, 1 bloquant `_idWeeklyRecap`) | Factuel : IDs réels, backend tests enum fermé, time-travel iOS |
| Adversaire | REWORK (5 bugs prod bound) | B1 backend coach_tools.py:470 rejette event, B2+B3 save_fact ne re-trigger pas, B4 null precedence, B5 FIFO 50 évincé |
| Iconoclaste | Wave A-MINIMAL 3 commits (kill retention + weekly engagement) | Doctrine : Things 3 philosophy, ADR-20260419 pareil registre, Wave B weekly_recap différé Wave C |

**Verdict consolidé** : **Wave A-MINIMAL 3 commits**. Les 3 panels convergent : tuer J+1/J+7/J+30/weekly engagement résout simultanément les findings techniques ET les findings doctrine.

## Matrice des enjeux

| Enjeu | Archi | Adversaire | Iconoclaste |
|---|---|---|---|
| `_idWeeklyRecap` inventé dans plan | ✗ bloquant | — | — |
| Backend coach_tools.py:470 enum ferme event | — | ✗ B1 bloquant Anthropic reject | — |
| Backend tests enum fermé (test_profile_extractor, test_coach_tools_categories) | ✗ AJ-2 | ✗ B1 | — |
| `_markOnboardingCompletedIfNeeded` fire once, save_fact ne re-trigger pas | — | ✗ B2+B3 gros gap | — |
| `taxSaving3a` null precedence bug | — | ✗ B4 runtime crash | — |
| FIFO 50 évinçage scan event en 1 semaine | ✗ AJ-3 indirect | ✗ B5 | — |
| Time-travel iOS impossible pour tester J+N | ✗ AJ-3 | — | — |
| ARB 6 langs weekly engagement piège | — | ✗ piège Claude | ✗ supprime le besoin |
| J+7 "tax nag" = Cleo cliché | — | — | ✗ KILL |
| Weekly engagement lundi 19h = Duolingo registre | — | — | ✗ KILL (doublon J+7) |
| J+30 re-scan nag = calendrier arbitraire | — | — | ✗ KILL |
| Scan → CoachInsight event | ✓ garder | ✓ garder (avec namespace fix) | ✓ garder ABSOLU |
| Deadlines 3a + tax + monthly check-in | ✓ garder | ✓ garder | ✓ garder (services réels) |

## Décisions architecturales tranchées

### D1 — Wave A redéfinie : **Wave A-MINIMAL** (3 commits, ~2h30)

**Garde** :
- A0 : backend `coach_tools.py:470` enum + tests — résout B1 adversaire
- A1 : `InsightType.event` Dart + scan → saveInsight **namespace dédié** (`_coach_events_` SharedPreferences key, non-FIFO) — résout B5 adversaire
- A2 : `scheduleCoachingReminders` wired avec UNIQUEMENT 3a + tax + monthly check-in, triad gate + `CoachProfileProvider` listener, `cancel(id)` per-ID sur les 7 IDs connus

**Kill/Defer** :
- `_scheduleWeeklyEngagementPing` → **kill** (Duolingo registre, pointe vers écran vide)
- `scheduleRetentionNotifications(J+1/J+7/J+30)` → **kill** (Cleo guilt marketing, manque-à-gagner déjà dans home Wave B)
- ARB 6 langs weekly engagement keys → **supprimé** (pas de clé ajoutée)
- RemoteConfig feature flag A4 → **kill** (rien à flagger)
- A3 scheduleRetentionNotifications → **kill**
- Wave A5 device walkthrough → **garde**, reduit en A3

### D2 — Backend enum `event` — AVANT A1 Dart

Sinon Anthropic API rejette `save_insight(type="event")` tool_use call. Séquence obligatoire : **commit backend A0 MERGE FIRST via PR séparée OR inclure dans A0 commit tête de cette PR** avec :
- `services/backend/app/services/coach/coach_tools.py:470` → ajouter `"event"` à save_insight input_schema enum
- `services/backend/tests/test_coach_tools_categories.py:309-315` → update assert set
- `services/backend/tests/test_profile_extractor.py:231` → update allowlist

### D3 — Event insights hors FIFO 50

`CoachMemoryService` nouvelle méthode `saveEvent(topic, summary, date)` + `hasEvent(topic, maxAgeDays)` qui utilisent SharedPreferences key `_coach_events_${uid}` sans pruning. Les events sont rares et structurants (scan LPP, EPL, achat immo) — ne doivent pas être écrasés par bavardage `fact`.

**Flag `syncToBackend=false` pour events** : panel archi AJ-2 — events = local-only pour v1. Évite cascade de fix tests backend + endpoint `/coach/sync-insight` validator. Peut migrer plus tard si besoin.

### D4 — `CoachProfileProvider` listener pour reschedule

Panel adversaire B2+B3 : save_fact flow doit re-trigger `scheduleCoachingReminders` quand triad passe incomplet → complet. Solution : provider top-level dans app.dart écoute `CoachProfileProvider`, quand triad change de false→true appelle `NotificationService().scheduleCoachingReminders(profile)` avec debounce 500ms.

Pattern : dans `app.dart` MultiProvider, ajouter un `_NotificationsWiringObserver` qui fait `context.read<CoachProfileProvider>()`.addListener avec check triad.

### D5 — `cancel(id)` per-ID spec corrigée (AJ-1 archi)

7 IDs coaching à cancel (confirmés code) :
- `_idCheckinMonthly = 1000`
- `_idCheckinReminder5d = 1001`
- `_idStreakProtection = 2000`
- `_id3aDeadlineBase = 3000` (+ offsets 0-3 pour 4 dates) → boucle `3000..3003`
- `_idTaxDeadlineBase = 4000` (+ offsets 0-2 pour 3 dates) → boucle `4000..4002`

Fonction helper `_cancelCoachingIds()` qui cancel ces ranges. Pas de `_idWeeklyRecap` (le plan précédent l'avait inventé). Pas de cancel des `_idCommitmentBase=5000` / `_idFreshStartBase=6000` / retention 9001/7/30 puisqu'on les abandonne dans cette Wave.

### D6 — Time-travel iOS impossible (AJ-3 archi)

Le walkthrough ne peut PAS attendre 24h. Solution : tests unit TZDateTime calc vérifient que l'algo de scheduling est correct, walkthrough vérifie seulement que `scheduleCoachingReminders` est APPELÉE après triad (via `logger.info` + Sentry breadcrumb + debug mode flag pour reduce days→minutes).

## Plan final Wave A-MINIMAL (3 commits, ~2h30)

**A0 — Backend save_insight enum accepte `event`** (15 min)
- `coach_tools.py:470` add `"event"` à input_schema.enum
- `test_coach_tools_categories.py:309-315` update allowlist
- `test_profile_extractor.py:231` update allowlist
- Pytest green → merge

**A1 — Dart InsightType.event + scan → saveEvent non-pruned** (50 min)
- `coach_insight.dart` add `InsightType.event`
- `coach_memory_service.dart` new `saveEvent(topic, summary, date)` + `hasEvent(topic, maxAgeDays)` using `_coach_events_${uid}` prefs key, no pruning
- `document_impact_screen.dart` post-scan success → `saveEvent(topic='scan_lpp', summary='{caisse} — {avoir} CHF')`
- Skip `syncToBackend` for events — local-only v1
- Tests : enum round-trip + scan → event persisté + hasEvent freshness

**A2 — scheduleCoachingReminders wired (minimal set)** (75 min)
- Delete `_scheduleWeeklyRecap` + retention calls from `scheduleCoachingReminders`
- Keep only : `_scheduleMonthlyCheckin` + `_schedule3aDeadlines` + `_scheduleTaxDeadlines`
- Replace `cancelAll()` → `_cancelCoachingIds()` helper with 7 IDs per D5
- Triad gate early return if `birthYear < 1900 || canton.isEmpty || salaireBrutMensuel <= 0`
- New listener in `app.dart` on `CoachProfileProvider` with debounce 500ms : if triad change false→true → schedule
- Also `_markOnboardingCompletedIfNeeded` keeps schedule call (defensive redundant)
- ARB : aucune nouvelle clé (deadline strings existent déjà)
- Tests : triad gate, idempotence 3× rapid, cancel-per-ID scope

**A3 — Device walkthrough + commit + PR** (20 min)
- Build iOS sim staging
- Fresh install, save_fact triad via coach
- Verify breadcrumb "scheduled 3a/tax/checkin" via logger + AX tree
- Scan document → verify saveEvent → hasEvent returns true
- Commit final, push, create PR

## Gates mécaniques sortie (16 points)

1-14. (inchangés Wave B) : flutter analyze / tests / ARB / CI / banned / sentinels / catch / façade / device / MEMORY.md / no_chiffre_choc / OpenAPI / regression
15. **Triad gate test** : profile sans birthYear/canton/salaire → 0 schedule, log explicite
16. **Backend enum test** : save_insight type='event' round-trip OK, tests regenerated

## Risques résiduels

| Risque | Mitigation |
|---|---|
| CoachProfileProvider listener boucle sur notifyListeners | debounce 500ms + track last-scheduled-triad signature |
| saveEvent 2× même scan | dedup check dans saveEvent (topic+source) |
| Backend enum A0 timing | merge A0 PR AVANT A1 commit dans CI — ou inclure A0 en tête de même PR avec backend test suite green gate |
| device walkthrough sans time-travel | breadcrumb log suffit, unit tests couvrent algo |

## Post Wave A-MINIMAL

- Merge → dev
- Observer 14 jours ; si Julien signale "je veux plus de rappels" → Wave A' ajoute retention avec contenu net (pas "On a calculé quelque chose")
- Wave C enchaîne : scan handoff coach + suggestion chip regex
