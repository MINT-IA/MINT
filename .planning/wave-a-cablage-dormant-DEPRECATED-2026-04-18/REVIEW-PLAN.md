# REVIEW-PLAN — Wave A : consolidation 3 panels

**Date** : 2026-04-18
**Panels** : Architecture (Stripe/Anthropic/fintech mobile), Adversaire ("200 IQ autistic"), Iconoclaste (Linear/Things 3/Swiss fintech)

## Verdicts bruts

| Panel | Verdict | Angle |
|---|---|---|
| Architecture | REWORK (1-2h rework avant EXECUTE) | Correctness technique, scope sous-estimé |
| Adversaire | REWORK (4/7 commits défauts reproductibles) | Bugs prod spécifiques, edge cases |
| Iconoclaste | REWORK FUNDAMENTAL (Wave B avant Wave A) | Prémisse : ordre des Waves |

**Verdict consolidé : REWORK profond.** Pas juste ajustements techniques, mais **réordonnancement** des Waves.

## Matrice des enjeux croisés

| Enjeu | Archi | Adversaire | Iconoclaste |
|---|---|---|---|
| `InsightType.event` manquant (A1 migration schema) | ✗ | — | — |
| `profile.age` scope 30+ call-sites pas 5 | ✗ | — | ✗ (belong B) |
| `WeeklyRecapService` class name collision | ✗ | — | — |
| A2+A4 fusion via single-entry | ✓ | ✓ | — |
| A2 fires greet-and-bounce (worst retention bug) | — | ✗ | ✗ (home mort) |
| `cancelAll` wipes retention notifs A3 | — | ✗ | — |
| A5 redaction defeated by LLM return string | ✗ (pii_scrubber) | ✗ (Sentry/DB/SDK) | ✗ (orthogonal, hotfix) |
| Negative age (2099) upstream not validated | — | ✗ | — |
| Dedup J+30 ignore scan freshness (FIFO 50 + 12mo stale) | — | ✗ | — |
| **Ordre Wave A vs Wave B** | — | — | ✗ (TRANCHÉ) |
| Wave 0 walkthrough 90 min avant code | — | — | ✓ |

## Décisions architecturales tranchées

### D1 — Réordonnancement Waves (ADR à écrire)

**Wave 0 "Walkthrough de vérité"** (90 min max) →
**Wave B-prime** (home orchestrateur + profile.age guard + WeeklyRecap consolidation) →
**Wave A-prime** (notifs wiring + scan event + dedup + cliff) →
**Wave C** (scan handoff, inchangé) →
**Wave D** (FRI + couple narrative, inchangé) →
**Wave E** (perfection gap, inchangé) →
**Wave F** (device release, inchangé)

**Justification** :
- Panel iconoclaste, preuve code : home mort (301 lignes, 0 CapEngine) vs CapEngine prêt (1333 lignes)
- Hiérarchie fintech gagnante : home vivant > push. Push sur home mort = CTR brûlé + session brûlée.
- Prerequisite cascade : A6 appartient à Wave B (CapEngine consomme profile.age). A3 dedup dépend du home affichant scan age. A5 est orthogonal (hotfix).

### D2 — Hotfix P0 compliance hors Wave

**`save_fact` PII redaction** devient un **commit chirurgical P0** séparé, 20-30 min, AVANT Wave 0 :
- Via `services/backend/app/services/privacy/pii_scrubber.py` existant (réutilisation)
- Deny-by-default avec allowlist `_SAFE_LOG_FACT_KEYS = {'canton', 'commune', 'employmentStatus', 'householdType', 'nationality', 'linguisticRegion', 'etatCivil', 'targetRetirementAge', 'archetype'}`
- Redact dans **logger.info ET return string** (LLM reçoit confirmation `f"Fait enregistré : {fact_key}"` sans valeur — la valeur est déjà dans son tool input history)
- Feature flag backend `ENABLE_SAVE_FACT_REDACTION=true` (default true en prod, false en test)
- Tests : grep test suite → 0 valeur salaire/LPP dans logs

### D3 — Notification scheduling : `cancel(id)` per-ID, pas `cancelAll`

**`scheduleCoachingReminders` réécrit pour utiliser `cancel(id)` per-ID** :
- 7 IDs fixes enumérés (`_idRetentionDay1`, `_idRetentionDay7`, `_idRetentionDay30`, `_idCheckinReminder5d`, `_idMonthlyCheckin`, `_idWeeklyRecap`, `_idStreakProtection`)
- Plus de collision avec `scheduleRetentionNotifications` ou `scheduleCheckinReminder`
- Ordre d'appel devient non-critique

### D4 — Scheduling gated on profile completeness triad

**Avant tout schedule, gate mécanique** :
```dart
bool _shouldSchedule(CoachProfile profile) =>
    profile.birthYear != null &&
    profile.canton.isNotEmpty &&
    (profile.salaireBrutMensuel ?? 0) > 0;
```

- Si triad incomplet → early return + Sentry breadcrumb `"notifications skipped: incomplete profile"`
- Évite le "greet-and-bounce" → user qui tape "Salut" n'a pas le triad → pas de notif schedulée → pas de churn

### D5 — Wave A-prime commits définitifs

1. **A1a** (30 min) : `InsightType.event` enum + backend `CoachInsightRecord` schema migration (Alembic si enum Postgres)
2. **A1b** (30 min) : Scan LPP → `CoachInsight(type=event, topic=scan, summary="...", date=now)`
3. **A2** (60 min) : `scheduleCoachingReminders` réécrit (cancel per-ID + profile triad gate + `_scheduleWeeklyEngagementPing`) + caller wired on profile-ready (pas _markOnboardingCompletedIfNeeded seul)
4. **A3** (30 min) : `scheduleRetentionNotifications(taxSaving3a)` avec vraie valeur, J+7 skip si taxSaving3a<=0 avec log, J+30 dedup si CoachInsight scan event `< 365d` **AND** present
5. **A6a** (90 min) : `profile.ageOrNull` getter + `save_fact birthYear` range check (`1900 <= birthYear <= currentYear-10`) + 5 simulateurs bloquants (libre_passage/provider_comparator/rachat_echelonne/independant/ijm) migration ageOrNull
6. **A7 → Wave E** : weekly_recap consolidation reportée (risque régression, pas prerequisite B)

**5 commits, ~4h.** A6b/A6c (coach_narrative 13 calls, widgets secondaires 15+) → Wave E.

### D6 — Wave B-prime commits (prévus, pas détaillés ici)

Wave B inclura maintenant :
- B1 : `CapEngine.compute(profile)` dans `aujourdhui_screen.dart` avec `profile.ageOrNull` guard
- B2 : `JitaiNudgeService.evaluateNudges` banner secondaire
- B3 : `MilestoneDetectionService.detectNew()` post-scan/checkin
- B4 : `WeeklyRecapService` consolidation + caller (fusion ex-A7)
- B5 : `StreakService` streak 0-30j compact
- B6 : Golden tests Aujourd'hui dynamique 4 profils
- B7 : Cleanup orphan providers (UserActivity/ContextualCard/CoachEntryPayload)
- B8 : `profile.age` guards sur coach_narrative_service.dart 13 call-sites (ex-A6b)

Nouvelle estimation Wave B-prime : 10-12h.

## Gates mécaniques révisés (14 points)

1-11. (inchangés) flutter analyze / flutter test / pytest / ARB parity / CI / banned terms / sentinels / catch silencieux / façade / device walkthrough / MEMORY.md handoff
12. `python3 tools/checks/no_chiffre_choc.py` → 0 hit
13. `python3 tools/openapi/generate_canonical.py` + diff check → 0 drift (A1a event type si exposé via endpoint)
14. Alembic migration dry-run si backend schema touché (A1a)

## Tests adversariels non-négociables (6 cas)

1. A1 : profile `birthYear=null, canton=null` → saveInsight scan ne crash pas, summary "caisse inconnue"
2. A2 : `scheduleCoachingReminders` appelée 3× dans 500ms → idempotent, pas de duplicate
3. A2 : profile triad incomplet → early return + breadcrumb (pas de notif schedulée)
4. A3 : `taxSaving3a = -500` (overfunded) → J+7 skip avec log, pas de nag "tu laisses -500"
5. A3 : scan insight présent mais `> 365d ancien` → J+30 nag fires (scan stale, re-scan demandé)
6. A5 : LLM passe `fact_key='canton', fact_value='je vis à Sion avec 120k'` → `_coerce_fact_value` rejette AVANT log, return `[save_fact ÉCHEC]`
7. A6 : profile `dateOfBirth = 2099-01-01` → ageOrNull null ET save_fact rejette en upstream (pas juste symptôme clampé)

## Feature flags (rollback path)

- **Backend** : `ENABLE_SAVE_FACT_REDACTION=true` (env var)
- **Flutter** : `RemoteConfig.getBool('notifications.weekly_engagement_enabled', default: true)`
- **Flutter** : `CoachMemory.persist_events=true` (fallback silencieux si crash schema)

## Décision finale : ordre d'exécution

1. **Hotfix P0 compliance** (save_fact PII) — 20 min — commit isolé sur feature/wave-a hotfix-save-fact-pii, PR séparée
2. **Wave 0 walkthrough de vérité** — 90 min max — iPhone 17 Pro sim, golden Julien+Lauren, 12 flows AX tree + screenshots, livrable `.planning/walkthrough-0-verite/FINDINGS.md`
3. **ADR-20260418-wave-order-daily-loop** — justifier réordonnancement B avant A
4. **Wave B-prime** — home orchestrateur — 10-12h, PR feature/wave-b-home-orchestrateur → dev
5. **Wave A-prime** — notifs wiring — 4h, PR feature/wave-a-notifs-wiring → dev
6. Puis Wave C, D, E, F comme prévu

## Impact sur roadmap

ROADMAP.md à mettre à jour pour refléter ce réordonnancement. La roadmap reste 6 Waves (+ Wave 0 walkthrough + 1 hotfix P0), durée totale inchangée (~35-45h).
