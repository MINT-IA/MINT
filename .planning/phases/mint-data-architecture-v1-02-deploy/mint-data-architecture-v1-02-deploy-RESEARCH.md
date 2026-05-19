---
phase: mint-data-architecture-v1-02-deploy
type: phase-research
status: ready-for-planning
research_date: 2026-05-19
researcher: gsd-phase-researcher
confidence: HIGH
response_language: fr
description: |
  Recherche pour la phase opérationnelle de cutover du substrat Phase 02
  (event-log + fact_event + fact_current + DEK envelope + parity audit
  p118/p119 + projection_diff). Le code est sur dev (HEAD 5210bf07) et
  promu sur staging (HEAD 45fbc5a8) ; le déploiement Railway staging a
  appliqué la chaîne alembic jusqu'à p119_phase02_parity_cont (vérifié
  2026-05-19 ~19:00 UTC). Prod reste à 29_05_magic_link_tokens — gap
  d'au moins 14 révisions documenté.
canonical_refs:
  - .planning/phases/mint-data-architecture-v1-02-deploy/CONTEXT.md
  - .planning/phases/mint-data-architecture-v1-02-deploy/HANDOFF-2026-05-19.md
  - .planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-projection-SUMMARY.md
  - .planning/phases/mint-data-architecture-v1-02-event-log-projection/deferred-items.md
  - .planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-03-migration-5pr-sequence-PLAN.md
  - .planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-04-close-out-counters-runbooks-PLAN.md
  - services/backend/scripts/railway_pre_deploy_migrate.py
  - services/backend/Procfile
  - services/backend/alembic/env.py
  - services/backend/alembic/versions/p98_fact_event_projection.py
  - services/backend/app/services/projector/fact_projector.py
  - services/backend/app/observability/counters.py
  - services/backend/app/cron/continuous_drift_sampler.py
  - .github/workflows/deploy-backend.yml
  - .github/workflows/pg-soak-nightly.yml
  - engram obs #233 #239 #249 (substrate gap + caplog + staging-landed)
---

# Phase mint-data-architecture-v1-02-deploy — RESEARCH

**Researched :** 2026-05-19
**Domain :** Opérations DB (alembic chain catch-up Railway staging+prod) · cutover SnapshotModel→fact_current · close-out Plan 02-04 · Mobile L1 device wiring · observabilité counters/Sentry/Prometheus.
**Confidence :** HIGH (substrate code lu en place ; chaîne alembic résolue déterministiquement via `ScriptDirectory.walk_revisions` ; Procfile + workflows GitHub Actions inspectés ; obs engram cités).

## Summary

Phase 02-deploy est l'inverse opérationnel du substrat Phase 02 : tout le code est **déjà sur dev et déjà sur staging**, mais l'application des migrations + le cutover des reads + le retrait du SnapshotModel + le câblage Mobile L1 device + 5 FLAGs sec/arch + 3 runbooks + un counter manquant n'ont pas encore atterri en environnement déployé. Le **flux d'auto-déploiement Railway** (`Procfile: web: sh -c 'python scripts/railway_pre_deploy_migrate.py && gunicorn ...'`) applique `alembic upgrade head` à chaque deploy : staging a donc bien convergé sur `p119_phase02_parity_cont` lors du merge PR #660 (18:58 UTC), tandis que **prod restera à `29_05_magic_link_tokens` jusqu'au prochain merge `staging→main`**. Le gap prod n'est donc PAS un fork — c'est simplement l'absence de merge dans main depuis 2026-04-21 (devops finding HANDOFF).

La chaîne alembic depuis prod head (`29_05_magic_link_tokens`) jusqu'à dev head (`p119_phase02_parity_cont`) comporte **14 révisions linéaires** dont un seul nœud de merge (`p98_merge_p86_eclairage` qui résorbe le double-head DEFERRED-02-01-A). Aucune migration date-préfixée n'est antérieure à `29_05` — la convention de naming a basculé en `pXX_` mid-phase. C'est cosmétique, pas un fork.

Le risque opérationnel principal n'est pas la chaîne (claire), c'est : (a) la régression JSONB cast `_json_bind` qui bind un `str` JSON à une colonne `JSONB` réelle (SQLite masque, Postgres explose à l'UPSERT) ; (b) la sémantique D-27 idempotence qui CONTEXT.md décrit comme « event_id ≤ latest_event_id » alors que le projector émet des UUID4 random (non monotones) ; (c) l'absence du counter `mint_snapshot_fact_current_drift_total` (référencé par 4+ plans mais jamais déclaré dans `services/backend/app/observability/counters.py`) ; (d) la **REVOKE UPDATE, DELETE ON fact_event FROM PUBLIC** de p98 qui requiert un rôle superuser ou GRANT-équivalent sur Railway — non-vérifié à ce jour.

**Primary recommendation :** séquencer **4-PR cleanup (A2 → A3 → B → D) AVANT toute Wave 1 prod-side**, puis exécuter `Wave 0 → Wave 1 (staging déjà à p119, donc focus sur Task 2a) → Wave 2 cutover → Wave 3 close-out → Wave 4 prod`. Le `railway_pre_deploy_migrate.py` au démarrage de **chaque** worker rend l'opération « apply migrations » triviale **à condition** que la PR ait été préalablement validée sur staging (parité dual-write + idempotence backfill + projection_diff zéro). Le risque vrai est dans le code, pas dans l'alembic.

## User Constraints (from CONTEXT.md)

### Locked Decisions

(reportées verbatim de CONTEXT.md — Phase 02-deploy hérite des 33 D-XX du substrat Phase 02, plus les décisions ci-dessous lockées dans le HANDOFF.)

1. **Phase 02 SPLIT** : substrat = code sur dev (PR #653 + #657 + #656 + #655 + #658) ; cutover opérationnel = ce phase sibling. Pas de re-litigation.
2. **D-27 skip semantics = EXACT-EQUALITY** (pas « event_id ≤ latest_event_id » que CONTEXT.md cite — UUID4 n'est pas monotone). Mobile L1 fournit des UUID stables pour le retry path.
3. **D-27 implementation** : le PK composite `(event_id, user_id)` du `fact_event` satisfait DÉJÀ la natural-key UNIQUE ; PR A2 n'ajoute QUE la colonne `latest_event_id String(36) NULL` sur `fact_current` + le `IntegrityError` catch dans `project_event`.
4. **caplog flake fix** : approche root-cause via `disable_existing_loggers=False` dans `alembic/env.py` + autouse conftest fixture (déjà shipped via PR #658, à valider en regression).
5. **Sibling phase status** : Phase 02-deploy = phase à part entière dans ROADMAP, pas un Plan de Phase 02.
6. **PR ordering pre-Wave-1** : `A2 → A3 → A4 → B → D` séquentiellement. **Pas de parallélisme A2/A3** (les deux touchent `fact_projector.py`). A4 (Mobile L1) peut migrer dans Wave 3.
7. **iOS entitlement isolation** (memory `feedback_ios_entitlements_block_testflight`) : tout `com.apple.developer.*` nouveau = PR isolée, jamais bundlée.
8. **Design panel obligatoire** (memory `feedback_design_panel_before_push`) avant push de toute modif `apps/mobile/lib/screens/**` — applicable à Mobile L1 main.dart wiring (DEFERRED-02-02-E).
9. **5-gate exit contract** (memory `feedback_perimeter_5_gates`) : G1 Maestro sim + G2 Julien device + G3 dev CI green + G4 regression + G5 LSFin/accent/ARB lint avant tout claim « ready ».
10. **0-trust §9** : aucun « shipped/ready/works/closed » sans citation déterministe (sha + commande output + Julien confirm) dans le même message.

### Claude's Discretion

- Ordre exact intra-wave : Claude choisit l'enchaînement précis dans une wave.
- Sélection de l'instrumentation Prometheus : Grafana Cloud free / Sentry metrics / Railway log-grep — Claude tranche selon ce qui est déjà câblé.
- Format des runbooks `docs/operations/*` : Claude choisit le template.
- Stratégie de retention `_phase02_parity_audit_continuous` : Claude propose un TTL.

### Deferred Ideas (OUT OF SCOPE)

- Migration UUID4 → UUID7 sur `fact_event.event_id` (arch FLAG-2) — décrochée pour Phase 03.
- DEK rotation effective (Phase 04 par D-07 ; runbook only ici).
- Audit hash pepper rotation effective (Phase 04 ; runbook only ici).
- DEK tombstone backend iter-2 A1 (DEFERRED-02-02-B — risque LOW, semantically duplicate de revoke_dek).
- True-concurrency variant iter-2 A8 (DEFERRED-02-02-G — segfault local Mac Python 3.9.6).

## Project Constraints (from CLAUDE.md)

| Directive | Source | Application Phase 02-deploy |
|-----------|--------|------------------------------|
| Banned terms LSFin (« garanti », « optimal », « meilleur »…) | §1 TOP/BOTTOM | Runbooks `docs/operations/*` et PR bodies sécurisés via `check_banned_terms` MCP + `banned_terms_python` lint (déjà étendu Plan 02-04 Task 2 à scanner JSONB payload). |
| Accents FR 100% mandatory | §2 TOP/BOTTOM | Tout doc opérationnel passe `accent_lint_fr.py`. Les SUMMARY/HANDOFF/RESEARCH.md de cette phase doivent être français accentué. |
| MINT ≠ retirement app | §3 TOP/BOTTOM | N/A — phase ops backend pure. |
| financial_core reuse | §4 TOP/BOTTOM | N/A direct ; **invariant à préserver** : aucune migration ou patch ici ne doit ré-implémenter L1 mobile ou L2-L4 backend. La Phase 02-deploy touche `fact_event/fact_current` (substrat), pas les services L1/L2-L4. |
| i18n required | §5 TOP/BOTTOM | Applicable à PR A4 Mobile L1 wiring uniquement (DEFERRED-02-02-D/E/F). Tout `Text(...)` doit passer `AppLocalizations.of(context)!.key` + ARB parity. |
| 0-TRUST §9 | §6 TOP/BOTTOM + §9 detail | **CRITIQUE pour cette phase.** Aucune wave ne se conclut sans citation déterministe (alembic head post-deploy + projection_diff stdout + counters /metrics + pg_dump filename + sim screenshot Maestro). Le post-merge sim sweep est obligatoire après PR A4 + Wave 4 prod. |
| Karpathy 4 | §7 | Surface les tradeoffs (#1) ; minimum code (#2) ; touch only what you must (#3) ; success criteria + verify per step (#4). Ce phase est par nature ops — coller au plan, pas de drive-by refactor. |
| Wiki schema lint | §8 | Chaque ADR/decisions générée par le panel doit contenir Counter-arguments + Data gaps (HARD lint). RESEARCH.md inclut sa section dédiée. |
| Pre-push checklist (memory) | mem `feedback_pre_push_checklist` | Avant chaque PR de cette phase : (1) `grep -rn '<func>('` callers ; (2) regen OpenAPI canonical OU `flutter gen-l10n` si touché ; (3) `pytest -q` complet OU `flutter test`. Pas de claim « clean » avant les 3. |
| Design panel before push | mem `feedback_design_panel_before_push` | Obligatoire pour PR A4 (Mobile L1 main.dart wiring touche bootstrap). 4-person panel : UX + a11y + adversarial + engineering. |
| HTML evidence report per phase | mem `feedback_html_evidence_report` | `.planning/phases/mint-data-architecture-v1-02-deploy/mint-data-architecture-v1-02-deploy-VERIFICATION-REPORT.html` à maintenir par wave + roll-up vers `.planning/reports/SESSION-YYYY-MM-DD.html`. |
| Sim crash mitigation | mem `feedback_sim_crash_mitigation` | Maestro G1 sweep post-A4 : reboot sim avant chaque pass ; skip S003/S004 si Safari-invoking. |

## Phase Requirements

Phase 02-deploy n'a **pas de REQ-IDs nouveaux** — elle livre les exigences déjà exprimées dans le substrat Phase 02 CONTEXT.md (D-01..D-33). Les requirements actifs cette phase :

| ID hérité | Description | Support recherche |
|-----------|-------------|---------------------|
| D-05 | 6-PR migration sequence | Reusable depuis Plan 02-03 iter-2 (PR-0/1/2/3a code-shipped ; PR-3b/4/5 à livrer ici) |
| D-06 | Q6 CI staging-down policy (STAGING-MALFORMED + scheduled-only aging + override label) | Plan 02-04 Task 2 à exécuter |
| D-07 | Audit retention 10y + pepper-rotation runbook | Plan 02-04 Task 4 runbook à écrire |
| D-09 | S12 alias removal (FrontalierService = FrontalierSegmentService) | Plan 02-04 Task 1 — gated sur PR-3b allowlist |
| D-10 | D-MOB-01 PR-A3 dead-fields + allowlist cleanup | Plan 02-04 Task 1 — gated sur PR-3b |
| D-12 | parity-lint SOFT→HARD atomic avec PR-3b | Plan 02-03 PR-3b ici |
| D-21 | Mobile L1 audit observer + OfflineAuditQueue + InMemoryAuditBufferDb | DEFERRED-02-02-C/D/E/F à câbler ici |
| D-27 | fact_event UNIQUE + idempotency | **Redéfini** EXACT-EQUALITY ici (PR A2) |
| D-31 | parity-lint promotion atomique 7-day soak | Plan 02-03 PR-3b ici |
| D-32 | 5-gate mechanical exit | Wave 4 final panel |
| D-33 | 8 counters declared + ASSERTED firing | Plan 02-04 Task 3 + déclaration manquante `mint_snapshot_fact_current_drift_total` (PR B) |

## Standard Stack

### Core

| Composant | Version | Rôle | Source recherche |
|-----------|---------|------|---------------------|
| Python | 3.12-slim | Backend Railway runtime | `services/backend/Dockerfile` lignes 6 + 24 [VERIFIED: file inspection 2026-05-19] |
| Alembic | (transitive via SQLAlchemy 2.x) | Migrations | `services/backend/alembic/env.py` + `requirements.txt` [VERIFIED] |
| SQLAlchemy | 2.x (sync) | ORM + raw SQL via `text()` | `fact_projector.py` `_json_bind` pattern [VERIFIED] |
| psycopg2 | (binary, transitive) | Postgres driver | `Dockerfile` libpq-dev + libpq5 [VERIFIED] |
| PostgreSQL | 15+ (Railway managed) | DB staging + prod | postgres-pro panel finding p98 FK partition rule (Postgres ≥ 14 requires partition col in PK) [CITED: panel HANDOFF + obs #239] |
| gunicorn | (transitive) | WSGI worker | `Procfile`: `gunicorn app.main:app -w 1 -k uvicorn.workers.UvicornWorker` [VERIFIED] |
| prometheus_client | (transitive ; soft-import) | Compteurs métrologie | `counters.py` lignes 24-46 fallback NoOp si absent [VERIFIED] |
| pytest | (dev extras) | Test framework | `Dockerfile` deploy-backend.yml install `.[dev]` [VERIFIED] |
| testcontainers-postgres | (dev extras) | pg_fixture | DEFERRED-02-02-G + Plan 02-01 Task 1 [CITED: deferred-items.md] |
| Railway CLI | `npm install -g @railway/cli` | Deploy verification | `deploy-backend.yml:104` [VERIFIED] |

### Supporting

| Composant | Version | Rôle | Quand l'utiliser |
|-----------|---------|------|---------------------|
| `railway_pre_deploy_migrate.py` | n/a | Bootstrap baseline + `alembic upgrade head` à chaque worker start | **Déjà câblé sur staging + prod via Procfile** ; PR B doit garder la même invocation (cf. §Don't Hand-Roll) |
| `psycopg2.extras.Json` adapter | psycopg2 2.9+ | Bind dict → JSONB natif | **Alternative à `_json_bind` string-bind** pour PR A3 (cf. §Common Pitfalls #2) [CITED: [SQLAlchemy issue #11994](https://github.com/sqlalchemy/sqlalchemy/issues/11994)] |
| `sqflite_sqlcipher` 3.1+ | Flutter | Persistance Mobile L1 chiffrée | DEFERRED-02-02-D ; **PR isolée avec iOS entitlement** [CITED: [pub.dev sqflite_sqlcipher](https://pub.dev/packages/sqflite_sqlcipher)] |
| `connectivity_plus` | Flutter | Gating drain OfflineAuditQueue | DEFERRED-02-02-F ; intégration via main.dart caller, pas dans `OfflineAuditQueue` (Karpathy #3, deferred-items.md L88) |
| `flutter_secure_storage` | Flutter | Passphrase SQLCipher iOS Keychain | Dépendance de `sqflite_sqlcipher` iOS [CITED: [Medium tutorial](https://medium.com/@sumaiah.mitu/secure-sqlite-database-in-flutter-using-sqflite-sqlcipher-ffccbb008743)] |
| `pg_dump` / `pg_restore` (CLI) | Postgres 15 client | Baseline + rollback | Wave 0 + Wave 4 ; **script `tools/db/railway_pg_dump.sh` à écrire** (PR B) [CITED: [Railway pg-dump help station](https://station.railway.com/questions/pg-dump-and-pg-migrate-to-a-new-deployme-62d7d60e)] |
| GitHub Actions `schedule` cron | n/a | `pg-soak-nightly.yml` activation | Cron disabled by default — uncomment à PR-3a merge, re-comment à PR-3b merge [VERIFIED: pg-soak-nightly.yml:21-23] |

### Alternatives Considered

| Au lieu de | On pourrait utiliser | Tradeoff |
|------------|-----------------------|------------|
| `railway_pre_deploy_migrate.py` (en boot worker) | Railway native **Pre-Deploy Command** | Pre-deploy command est plus propre (1 run, pas N workers) — *mais c'est une feature 2025-01 ([Railway changelog](https://railway.com/changelog/2025-01-10-pre-deploy-command))*. Migration vers ce pattern = **scope creep** pour Phase 02-deploy. Décision : garder l'existant (`-w 1` gunicorn rend la race condition no-op), filer comme follow-up. |
| `pg_dump` shell script | Postgres Migrator template Railway | Migrator = full restore tool ; on veut juste baseline backup → script shell suffit. [CITED: [Railway Deploy postgres-migrator](https://railway.com/deploy/postgres-migrator)] |
| string-bind JSON dans `text()` | `JSONB(astext_type=Text())` ORM column avec cast `::jsonb` explicite | Cast explicite `:value_enc::jsonb` est dialect-branché et survivable SQLite ; adapter `psycopg2.extras.Json` plus propre mais demande hook engine-level [CITED: [SQLAlchemy issue #11994](https://github.com/sqlalchemy/sqlalchemy/issues/11994)]. Recommandation A3 : cast `::jsonb` (1 ligne, surface réduite). |
| GitHub Actions cron pour drift sampler | Railway native cron | GH Actions cron disponible aujourd'hui et déjà câblé dans `pg-soak-nightly.yml` ; pas de raison de switcher pour cette phase. |
| Sentry pour alerte drift | Prometheus Alertmanager + Grafana | Sentry déjà câblé pour erreurs MINT ; ajouter une alert metric-based = 5 min UI config (Julien-only task) vs setup full Alertmanager. Choix : Sentry (memory `project_remote_control`). |
| `mem_save` pour journal phase | Discussion blob | engram donne `prior_finding_refs` pour compounding cross-session. Use pour chaque finding important. |

**Installation (nouvelles deps phase 02-deploy uniquement) :**

```bash
# PR A4 Mobile L1
cd apps/mobile
flutter pub add sqflite_sqlcipher connectivity_plus flutter_secure_storage
# iOS pod: requires Xcode 15.x + iOS deployment target 14.0+ ; isolated PR pour com.apple.developer.* keys

# PR B observability infra : pas de nouvelle dep Python — tout est déjà dans prometheus_client + sentry-sdk
# Verify
cd services/backend
python3 -c "import prometheus_client; print('prom', prometheus_client.__version__)"
```

**Version verification (2026-05-19) :**

```bash
# Backend (déjà installé)
cd services/backend && python3 -c "import sqlalchemy, alembic, psycopg2; print(sqlalchemy.__version__, alembic.__version__, psycopg2.__version__)"
# attendu : ≥ 2.0, ≥ 1.13, ≥ 2.9

# Postgres staging (déjà verified)
railway ssh -e staging --service MINT 'python3 -c "import psycopg2,os; c=psycopg2.connect(os.getenv(\"DATABASE_URL\")); print(c.server_version)"'
```

## Architecture Patterns

### Project Structure (zones touchées par cette phase)

```
services/backend/
├── alembic/
│   ├── env.py                                                  # disable_existing_loggers=False déjà OK
│   └── versions/
│       ├── 29_05_magic_link_tokens.py                          # PROD head (2026-04-21)
│       ├── 29_04 → p10 → p15 → 5f7922bff82b (merge) → ...     # 14 révisions vers dev head
│       ├── p98_fact_event_projection.py                        # substrat Phase 02
│       ├── p118_phase02_parity_audit_table.py
│       ├── p119_phase02_parity_audit_continuous.py             # DEV + STAGING head depuis 2026-05-19
│       ├── p120_fact_event_idempotency.py                      # NEW PR A2 — latest_event_id col
│       └── p117_drop_snapshot_legacy.py                        # NEW PR-5 Wave 2 — drop SnapshotModel
├── app/
│   ├── api/v1/endpoints/projection.py                          # PR-3b read-cutover ici
│   ├── api/v1/endpoints/audit_mobile.py                        # PR A2 bonus event_id wire-through
│   ├── cron/continuous_drift_sampler.py                        # cron à activer PR-3a merge
│   ├── models/{fact_current.py,fact_event.py,snapshot.py}      # snapshot.py supprimé PR-5
│   ├── observability/counters.py                               # +mint_snapshot_fact_current_drift_total (PR B)
│   ├── services/feature_flags.py                               # FF_FACT_EVENT_DUAL_WRITE retiré PR-4
│   ├── services/projector/fact_projector.py                    # PR A2 catch IntegrityError + A3 JSONB cast
│   └── services/snapshots/snapshot_service.py                  # dual-write branch retirée PR-4
├── scripts/
│   ├── backfill_snapshot_to_fact_event.py                      # invoqué Wave 1 + Wave 4
│   ├── preflight_zero_user_gate.py                             # invoqué pre-Wave-4
│   └── railway_pre_deploy_migrate.py                           # auto-applique alembic à chaque deploy
└── tests/
    ├── integration/                                            # 3 nouveaux tests PR A2 + 2 PR A3
    └── observability/test_phase02_counters.py                  # PR B declared_counters_must_fire

tools/
├── checks/
│   ├── alembic_partition_safety_lint.py                        # NEW PR B (~50 LOC AST)
│   ├── declared_counters_must_fire.py                          # Plan 02-04 Task 3
│   ├── no_mobile_fact_current_regulatory_read.py               # DEFERRED-02-02-C lefthook wiring
│   └── profile_safe_fields_parity.py                           # SOFT→HARD PR-3b
├── db/
│   ├── railway_pg_dump.sh                                      # NEW PR B
│   └── pre_pr3b_pg_dump.sql                                    # snapshot pré-cutover (commité dans PR-3b)
└── parity/projection_diff.py                                   # invoqué Wave 1 + Wave 4

.github/workflows/
├── deploy-backend.yml                                          # déjà câblé staging/prod
├── pg-soak-nightly.yml                                         # cron à activer PR-3a merge
└── regulatory-codegen.yml                                      # Plan 02-04 Task 2 STAGING-MALFORMED

apps/mobile/lib/
├── main.dart                                                   # DEFERRED-02-02-E observer wiring
└── services/audit/
    ├── audit_buffer_db.dart                                    # abstract — DEFERRED-02-02-D prod impl
    └── offline_audit_queue.dart                                # connectivity_plus integration DEFERRED-02-02-F
```

### Pattern 1 — Railway auto-deploy + alembic at boot

```python
# Source: services/backend/Procfile (verified 2026-05-19)
web: sh -c 'python scripts/railway_pre_deploy_migrate.py && gunicorn app.main:app -w 1 -k uvicorn.workers.UvicornWorker --bind 0.0.0.0:${PORT:-8080} --timeout 120'

# Source: services/backend/scripts/railway_pre_deploy_migrate.py
def main() -> int:
    _bootstrap_alembic_if_needed(database_url)   # stamp baseline si table users existe sans alembic_version
    _run_alembic_upgrade_head()                  # subprocess.run(['alembic', 'upgrade', 'head'], check=True)
    return 0
```

**What :** Chaque deploy Railway = chaque worker = applique migrations au boot. Gunicorn `-w 1` (workers=1 par décision PR Phase 97 W7) ⇒ pas de race condition multi-worker. Le bootstrap stamp gère le cas « DB existait avant alembic » (cas baseline `d73dcc3968c9` sentinel sur tables `users`, `audit_events`, `profiles`).
**When to use :** Toute migration commitée sur dev → staging via merge dev→staging (déclenche `deploy-backend.yml deploy-staging` qui attend 30s de Railway auto-deploy). Toute migration sur main via merge staging→main.
**Pitfall :** Si une migration échoue, `subprocess.run(..., check=True)` raise → `_run_alembic_upgrade_head()` raise → `main()` return 1 → gunicorn ne démarre PAS. Railway garde la version précédente (rollback automatique). **C'est notre filet rollback.**

### Pattern 2 — Partition-safe PK on Postgres ≥ 14

```sql
-- Source: services/backend/alembic/versions/p98_fact_event_projection.py (verified 2026-05-19)
CREATE TABLE fact_event (
    event_id        UUID NOT NULL,
    user_id         VARCHAR NOT NULL,
    ...
    PRIMARY KEY (event_id, user_id)             -- ★ partition col DOIT être dans PK
) PARTITION BY HASH (user_id);
```

**What :** Postgres v14+ exige que toute contrainte UNIQUE ou PRIMARY KEY sur une table partitionnée inclue **toutes** les colonnes de la clé de partitionnement. Le PK composite `(event_id, user_id)` est fonctionnellement équivalent à UNIQUE sur `event_id` seul puisque l'event_id est UUID (collisions cross-user pratiquement impossibles), tout en satisfaisant la règle.
**Why :** Sans cette règle, l'erreur Postgres est cryptique (`unique constraint must include all partitioning columns`) et le code SQLite (où la règle n'existe pas) passe — c'est exactement le bug masqué par SQLite que postgres-pro a flagué en panel (obs #239).
**Lint à écrire (PR B) :** `tools/checks/alembic_partition_safety_lint.py` parse via `ast` les migrations cherchant `PARTITION BY` et vérifie que le PK contient les colonnes de partition.

### Pattern 3 — D-27 idempotency redéfinie EXACT-EQUALITY (PR A2)

```python
# Source: HANDOFF.md décision lockée + postgres-pro design
# fact_current.latest_event_id (NEW colonne PR A2, NULLable, String(36))
# Sémantique : idempotency via PK collision sur fact_event.

def project_event(session, event):
    try:
        # ── 1. Append-only INSERT into fact_event (PK = event_id + user_id) ──
        fe = FactEvent(event_id=event_id, user_id=event.user_id, ...)
        session.add(fe)
        session.flush()
    except IntegrityError as ie:
        # PK collision = replay du même event_id → skip cleanly
        if 'fact_event_pkey' in str(ie.orig):
            mint_projector_idempotency_skip_total.inc()
            session.rollback()
            return event_id  # idempotent return
        raise
    # ── 2. UPSERT fact_current + update latest_event_id = fe.event_id ─────
    # ── 3. ... reste inchangé
```

**What :** Au lieu de comparer `event_id ≤ latest_event_id` (impossible sur UUID4), on laisse Postgres trancher via le PK collision. Mobile L1 fournit un UUID stable pour ses retries (Mobile-side patch dans PR A2 bonus). Le counter `mint_projector_idempotency_skip_total` enregistre les replays.
**When :** Mobile L1 audit POST `/v1/audit_mobile` qui peut retry sur 5xx ; backfill rejoué une 2e fois pour idempotence proof Task 2a.
**Bonus PR A2 (postgres-pro recommandation, +20 LOC) :** ajouter `event_id: Optional[str] = None` au `project_event` signature et au `/v1/audit_mobile` endpoint. Sinon D-27 ne couvre que le backfill path.

### Pattern 4 — JSONB cast safe across dialects (PR A3)

```python
# Source: fact_projector.py:117-149 (current — bug masked by SQLite)
# AVANT (string-bind, échoue sur Postgres JSONB) :
session.execute(text("""INSERT INTO fact_current (..., value_enc, ...) VALUES (..., :value_enc, ...)"""),
                {"value_enc": _json_bind(event.value_enc)})  # _json_bind retourne str

# APRÈS (PR A3 fix) :
if session.bind.dialect.name == 'postgresql':
    sql = """INSERT INTO fact_current (..., value_enc, ...) VALUES (..., CAST(:value_enc AS jsonb), ...)"""
else:
    sql = """INSERT INTO fact_current (..., value_enc, ...) VALUES (..., :value_enc, ...)"""
session.execute(text(sql), {"value_enc": _json_bind(event.value_enc)})
```

**What :** Sur Postgres, le bind d'un `str` JSON dans une colonne JSONB échoue (« column "value_enc" is of type jsonb but expression is of type text »). SQLite (où JSONB n'existe pas, stocké TEXT) masque l'erreur. Solution : cast explicite `CAST(:value_enc AS jsonb)` branché par dialect, OU adapter `psycopg2.extras.Json` enregistré au niveau engine.
**Why :** [SQLAlchemy issue #11994](https://github.com/sqlalchemy/sqlalchemy/issues/11994) documente exactement ce pattern (« missing type cast for jsonb in values for postgres »). [SQLAlchemy PG docs](https://docs.sqlalchemy.org/en/21/dialects/postgresql.html) recommandent `register_default_jsonb` au niveau dialect — mais c'est plus invasif que le cast inline.
**Recommandation :** cast inline `::jsonb` (Karpathy #2 simplest change).
**Test à ajouter PR A3 :** `test_dual_write_failure_rollback.py` avec pg_fixture (testcontainers) DEK-revoked mid-loop → snapshot rolls back atomiquement (cf. déjà spec HANDOFF).

### Pattern 5 — Continuous drift sampler 7-day soak

```yaml
# Source: .github/workflows/pg-soak-nightly.yml (verified 2026-05-19)
on:
  # schedule:
  #   - cron: '*/30 * * * *'   # ★ COMMENTÉ par défaut, à activer PR-3a merge
  workflow_dispatch:
    inputs:
      sample_size: { default: '100' }
      dry_run:     { default: 'false' }
```

```python
# Source: services/backend/app/cron/continuous_drift_sampler.py (verified)
def _pick_random_user_ids(db_url, sample_size):
    # Postgres TABLESAMPLE BERNOULLI ou ORDER BY random() LIMIT
    ...
# Pour chaque user : fetch /v1/projection (new) + /v1/projection?legacy=true → projection_diff
# Insert dans _phase02_parity_audit_continuous avec sampler_run_id UUID4
```

**What :** Cron toutes les 30 min × 100 users × 7 jours = ~10 000 échantillons. Persiste dans `_phase02_parity_audit_continuous` (alembic p119). Task 2b query : `SELECT count(*) FILTER (WHERE diff_count > 0) FROM _phase02_parity_audit_continuous WHERE sampled_at > now() - interval '24 hours'` doit retourner 0 sur ≥ 24h consécutives adjacent au merge proposé.
**When :** Activé manuellement (uncomment cron block + push) au moment du merge PR-3a sur dev. Désactivé (re-comment) au moment du merge PR-3b.
**0-user-prod override (per iter-2 B20)** : 7 jours minimum / 14 cible. Le 0-user-prod premise (2 test accts) justifie potentiellement un override par Julien — **à documenter dans le PR-3b body** comme « override per CONTEXT.md§Open-Q #4 + memory feedback_blockers_ask_dont_defer ».

### Pattern 6 — alembic env.py disable_existing_loggers=False

```python
# Source: services/backend/alembic/env.py:25-30 (verified)
if config.config_file_name is not None:
    fileConfig(config.config_file_name, disable_existing_loggers=False)  # ★ critical
```

**What :** Sans `disable_existing_loggers=False`, Alembic `fileConfig` marque TOUS les loggers nommés pré-existants comme `disabled=True`. Effet : `Logger.callHandlers()` short-circuit avant tout handler dispatch → caplog perd les records → tests caplog flake en cascade selon l'ordre d'exécution (engram obs #239).
**Lint à écrire (PR B) :** lefthook rule grep `fileConfig\(` qui exige `disable_existing_loggers=False` sur la même ligne ou ligne suivante.
**Conftest fixture à écrire (PR B) :** assertion session-scope `app.services.* loggers .disabled is False` au début de chaque session pytest pour catcher toute régression future.

### Anti-Patterns to Avoid

- **Forcer `alembic upgrade head` manuellement via `railway ssh` plutôt que via deploy** : le pipeline Railway auto-deploy applique déjà au boot. Manuel = peut diverger de ce que Railway va faire au prochain boot (deux versions de la chaîne en flight). Toujours commiter→push→merger→laisser le pipeline.
- **Bundler iOS entitlement avec PR features** : memory `feedback_ios_entitlements_block_testflight` : tout `com.apple.developer.*` nouveau = PR isolée. PR A4 doit splitter Mobile L1 wiring en (a) sqflite_sqlcipher + Dart-side code, (b) iOS Runner.entitlements + fastlane match.
- **Tester JSONB binding uniquement avec SQLite** : SQLite stocke JSONB comme TEXT et accepte tout. Toute migration touchant JSONB binding doit avoir un test pg_fixture (testcontainers) — bug masqué sinon (Phase 02 substrate Postgres BOOLEAN DEFAULT bug `fe52ba31`, obs #188).
- **Lire le drift counter sans declared_counters_must_fire** : Plan 02-04 Task 3 lint asserte que les 8 counters incrementent ≥ 1 dans un scenario test représentatif. Sans ce lint, un counter déclaré peut rester silencieusement zéro (regression).
- **Modifier `services/backend/app/services/projector/fact_projector.py` ligne 151-181 (sec FLAG-1 post-write divergence assertion)** : c'est du code defense-in-depth contre ContextVar leak. PR D propose de le supprimer (« defense-against-impossible »). **NE PAS supprimer dans cette phase** — c'est un filet utile pendant la cutover ; à reconsidérer en Phase 03 quand event-log est stable depuis 30 jours.

## Don't Hand-Roll

| Problème | Ne pas construire | Utiliser à la place | Pourquoi |
|----------|---------------------|------------------------|----------|
| Postgres backup baseline | Script SQL ad-hoc qui `COPY ... TO` table-by-table | `pg_dump --schema-only --data-only` invoqué via `railway ssh` (script `tools/db/railway_pg_dump.sh`) | pg_dump gère séquences, constraints deferred, partitions, owners. Hand-roll oublie toujours quelque chose. [CITED: [Railway pg-dump help station](https://station.railway.com/questions/pg-dump-and-pg-migrate-to-a-new-deployme-62d7d60e)] |
| Alembic stamp baseline | `UPDATE alembic_version SET version_num=...` SQL direct | `alembic stamp <rev>` CLI OU `_bootstrap_alembic_if_needed()` (déjà câblé) | Le bootstrap script vérifie SENTINEL_TABLES présence + handle table absence. Hand-roll = stamp incorrect = future migrations partent du mauvais point. |
| JSONB serialization | `json.dumps()` + bind comme string | `psycopg2.extras.Json` adapter au niveau engine OR cast inline `::jsonb` | psycopg2 a un adapter natif depuis 2.7. Hand-roll string-bind masqué par SQLite (cas actuel `_json_bind`). [CITED: [SQLAlchemy issue #11994](https://github.com/sqlalchemy/sqlalchemy/issues/11994)] |
| SQLCipher passphrase derivation | Hash maison salt+pepper | `flutter_secure_storage` + iOS Keychain | iOS Keychain donne hardware-backed key isolation. Maison = stockage NSUserDefaults = trivially readable post-jailbreak. [CITED: [Medium tutorial](https://medium.com/@sumaiah.mitu/secure-sqlite-database-in-flutter-using-sqflite-sqlcipher-ffccbb008743)] |
| Prometheus scrape sur Railway | Endpoint custom `/scrape` qui aggrège | `/metrics` standard prometheus_client + Grafana Cloud free tier scrape job | prometheus_client expose déjà `/metrics`. Hand-roll aggregator = un de plus à monitorer + scope creep. |
| Sentry alert metric-based | Code custom qui poll `/metrics` et appelle Sentry SDK | Sentry « Metrics Alert » UI rule (Julien-only task, 5 min config) | Sentry a une fonctionnalité Metric Alert depuis 2024 ; UI rule = moins de code à maintenir. |
| Per-test caplog mock | Patch `caplog` dans chaque test | Root-cause fix `disable_existing_loggers=False` + autouse conftest fixture (déjà shipped PR #658) | Per-test patches = N×O(maintenance) ; root-cause = 1 ligne env.py + 1 fixture. (engram obs #239) |
| Mobile connectivity in OfflineAuditQueue | `connectivity_plus.Connectivity().onConnectivityChanged.listen` dans queue impl | Caller (main.dart) listens, calls `audit.flush()` on restore | Karpathy #3 surgical — surface minimale, integration point unique. (deferred-items.md L88) |

**Key insight :** Cette phase est **ops + close-out**, pas du greenfield. La majorité des « tentations hand-roll » viennent du fait que le code substrat fonctionne sur SQLite et qu'on est tenté de rallonger un pattern existant plutôt que de lever le cas Postgres-réel. Le test pg_fixture (testcontainers) déjà en place dans Plan 02-01 est notre rempart contre toutes ces tentations. **Aucune PR de cette phase ne doit se merger sans avoir prouvé son comportement sur pg_fixture quand elle touche une migration ou un raw SQL `text()`.**

## Runtime State Inventory

> Phase 02-deploy est une cutover/migration phase. Les 5 catégories Runtime State sont applicables.

| Catégorie | Items trouvés | Action requise |
|-----------|-------------------|---------------------|
| **Stored data** | (1) `_phase02_parity_audit` (Postgres staging — table créée p118) — vide à ce jour, sera populée Task 2a. (2) `_phase02_parity_audit_continuous` (Postgres staging — p119) — vide. (3) `fact_event` / `fact_current` (staging) — vides, à populer par backfill Wave 1. (4) `alembic_version` (staging) = `p119_phase02_parity_cont` ✓ verified. (5) `alembic_version` (prod) = `29_05_magic_link_tokens` (lag 14 revs). (6) `dek_vault` (staging) — supposée présente via Phase 02 substrate ; à vérifier dans Wave 0 audit. (7) ChromaDB `/data/chromadb` volume Railway prod — pas touchée par cette phase mais à NE PAS perdre lors de pg_restore éventuel. | Wave 0 audit liste ; Wave 1 populate (staging) ; Wave 4 populate (prod). |
| **Live service config** | (1) `FF_FACT_EVENT_DUAL_WRITE` env var Railway staging — **à activer Wave 1 step 3** via `railway variables set`. Prod = unset (rester OFF jusqu'à Wave 4 + soak complet). (2) `MINT_AUDIT_HASH_PEPPER` — pre-flight checklist item #3/#4 (non-empty + >20 chars) sur staging + prod. (3) `KMS_KEY_ID` vs `MINT_KMS_KEY_ID` — naming inconsistency audit PR B (devops finding HANDOFF). (4) `STAGING_BASE_URL` + `STAGING_DATABASE_URL` GH Actions secrets pour `pg-soak-nightly.yml` — required, non-vérifié. (5) Railway « orphan staging Postgres service » à supprimer (devops PR D step 8 — confirmer no MINT vars y reference). | Wave 1 enable FF ; PR B audit naming ; PR D delete orphan ; Wave 0 verify pepper + secrets. |
| **OS-registered state** | (1) GitHub Actions workflow `deploy-backend.yml` — auto-trigger on PR merge to staging/main, déjà câblé. (2) `pg-soak-nightly.yml` cron disabled by default — **uncomment cron block** lors du merge PR-3a, **re-comment** lors du merge PR-3b. (3) Sentry alert rules (Julien dashboard) — `mint_snapshot_fact_current_drift_total > 0 in 24h` à créer (Julien-only task, PR B documents la procédure). (4) Branch protection rule sur `dev` — `pg-integration (testcontainers)` à promouvoir « required check » (postgres-pro E1, PR B). (5) iOS provisioning profile via fastlane match — à mettre à jour si DEFERRED-02-02-D ajoute Keychain entitlement (PR isolée). | Wave 2 cron toggle ; PR B branch protection + Sentry doc ; PR A4 iOS provisioning. |
| **Secrets and env vars** | (1) `ANTHROPIC_API_KEY` Railway — non-touché cette phase mais ne PAS perdre (memory `feedback_anthropic_key_on_railway`). (2) `MINT_AUDIT_HASH_PEPPER` Railway staging + prod — **rotation déferrée Phase 04**, runbook only ici. (3) `KMS_KEY_ID` / `MINT_KMS_KEY_ID` (per env) — audit naming PR B. (4) `RAILWAY_TOKEN`, `PROJECT_STAGING_TOKEN`, service IDs — déjà câblés (verifyed `deploy-backend.yml`). (5) `SENTRY_DSN_STAGING` — pas requis pour ship (memory `project_testflight_ship_path`). | PR B audit naming ; Wave 4 prod pepper verify ; runbooks Task 4. |
| **Build artifacts / installed packages** | (1) Dockerfile multi-stage : `services/backend/Dockerfile` copie `alembic/`, `scripts/`, `app/` — pas de stale artifact connu. (2) iOS pod `sqflite_sqlcipher` non-installé → PR A4 `pod install` après pubspec update. (3) `python -m pytest tests/` smoke à chaque deploy — déjà câblé dans `deploy-backend.yml:test` job avec `TESTING=1` + `DATABASE_URL=sqlite:///./test.db`. (4) `flutter analyze` + `flutter test` à ajouter au pre-push hook pour PR A4 (memory `feedback_pre_push_checklist`). | PR A4 pod install + test runs ; rien d'autre. |

**Canonique question Karpathy :** *Après que chaque fichier du repo est à jour, quels systèmes runtime tiennent encore l'ancien état ?*

Réponse cette phase : (a) **prod alembic_version** (jusqu'à Wave 4 ; pas un état stale, juste un lag temporel) ; (b) **`FF_FACT_EVENT_DUAL_WRITE` Railway env var** (devra être unset prod jusqu'à Wave 4 + soak complet — actuellement unset, donc rien à reset, juste à NE PAS set par erreur) ; (c) **`pg-soak-nightly.yml` cron schedule** (disabled actuellement ; uncomment+re-comment manual cycle) ; (d) **Sentry alert rules** (UI state pas dans git, à créer Julien-only).

## Environment Availability

| Dépendance | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Python 3.12 | Backend Railway | ✓ | 3.12-slim Docker | — |
| PostgreSQL ≥ 14 | Substrate p98 partition rule | ✓ | Railway managed (staging + prod) | — |
| psycopg2 ≥ 2.9 | JSONB adapter / pg driver | ✓ | binary install via Dockerfile | — |
| testcontainers-postgres | pg_fixture intégration tests | ✓ | dev extras | — |
| Railway CLI | deploy verification + `railway ssh` | ✓ | npm install -g @railway/cli | — |
| `pg_dump` / `pg_restore` | Wave 0 baseline + Wave 4 rollback | ✓ (host machine + Railway shell) | Postgres 15 client | — |
| GitHub Actions cron | pg-soak-nightly | ✓ | natif GH | — |
| Sentry Metric Alert UI | drift counter alert | ✓ (Julien dashboard) | n/a | — |
| Maestro | G1 sim walker (Wave 4 close-out) | ✓ (memory `reference_maestro_setup`) | tools/simulator/* | — |
| `idb` | sim describe-all evidence | ✓ (memory `feedback_device_gates`) | iOS CLI | — |
| Flutter SDK | Mobile L1 wiring | ✓ | apps/mobile/ | — |
| iOS Xcode 15.x + iOS 14+ target | sqflite_sqlcipher pod | ✓ (Apple Developer portal verified per memory) | n/a | — |
| `flutter_secure_storage` | SQLCipher passphrase iOS Keychain | ✗ (pubspec add à faire PR A4) | n/a | — |
| Grafana Cloud free tier | Prometheus scrape | ✗ (à câbler PR B OU choisir Sentry/Railway log-grep alternative) | n/a | Sentry Metric Alert (déjà câblé) |
| Railway native Pre-Deploy Command (2025-01) | Migration race elimination | ✓ feature available | n/a | Garder Procfile pattern existant (Karpathy #3) |

**Missing dependencies with fallback :**
- `flutter_secure_storage` → ajouter via `flutter pub add` dans PR A4 (pas un blocker, juste à câbler).
- Grafana Cloud → fallback Sentry Metric Alert (déjà choisi dans Routing rules — voir Pattern Sentry section).

**Missing dependencies with no fallback :** Aucune. Phase 02-deploy est totalement réalisable avec l'infra existante.

## Common Pitfalls

### Pitfall 1 — `_json_bind` masqué par SQLite (HIGH severity, PR A3)
**What goes wrong :** L'UPSERT dans `fact_current` via `text()` bind `value_enc` comme string JSON. SQLite (où JSONB est TEXT) accepte. Postgres réel : `ERROR: column "value_enc" is of type jsonb but expression is of type text`.
**Why it happens :** `_json_bind` retourne `json.dumps(...)` qui est `str` ; psycopg2 ne fait pas auto-cast string→jsonb (contrairement à json→jsonb via adapter natif).
**How to avoid :** PR A3 cast inline `CAST(:value_enc AS jsonb)` branché par `session.bind.dialect.name == 'postgresql'`. OR enregistrer `psycopg2.extras.Json` au niveau engine via `engine.dialect.dbapi.extras.register_default_jsonb` event.
**Warning signs :** Test `test_dual_write_failure_rollback.py` avec pg_fixture qui retourne erreur Postgres ; counter `mint_fact_event_insert_total` reste à 0 en staging deploy malgré dual-write enabled.

### Pitfall 2 — Partitioned FK validation Postgres 15+ (engram obs #239, MEDIUM)
**What goes wrong :** `ALTER TABLE fact_event ADD CONSTRAINT fk_user FOREIGN KEY (user_id) REFERENCES users(id) NOT VALID` puis `ALTER TABLE fact_event VALIDATE CONSTRAINT fk_user` — sur table partitionnée, l'instruction VALIDATE doit être appliquée **par partition**, pas sur la table parent.
**Why it happens :** Postgres traite le parent partitionné différemment ; la VALIDATE sur parent ne propage pas aux 8 partitions hash. Bug masqué par tests SQLite (pas de partitions).
**How to avoid :** p98 a déjà été patché (PR #658) pour boucler sur les 8 partitions. **Lint à écrire PR B :** `alembic_partition_safety_lint.py` AST-walk les migrations cherchant `ADD CONSTRAINT ... FOREIGN KEY` sur tables partitionnées.
**Warning signs :** Alembic upgrade head sur staging réussit mais FK orphan une fois user supprimé. Pre-flight checklist item #11 (« Confirm p98 REVOKE DDL Railway role privilege ») et l'audit FK appartiennent à Wave 0.

### Pitfall 3 — Procfile prestart race condition multi-worker (LOW — actuellement neutralisé)
**What goes wrong :** Si gunicorn passait à `-w 2+`, chaque worker exécuterait `python scripts/railway_pre_deploy_migrate.py && gunicorn ...` au start → 2 workers font `alembic upgrade head` en parallèle → premier prend le lock, second échoue ou race condition sur `alembic_version` table.
**Why it happens :** Le Procfile invoque le pre-deploy script inline avec gunicorn. C'est neutralisé par `-w 1` (Phase 97 W7 #1, B001 fix turn_cap).
**How to avoid :** **Ne pas augmenter `-w` sans migrer vers Railway native Pre-Deploy Command** (2025-01 feature, [Railway changelog](https://railway.com/changelog/2025-01-10-pre-deploy-command)). Phase 02-deploy garde `-w 1`. **Tracker comme follow-up Phase 03+** : migrer Procfile→nixpacks.toml + `[pre-deploy] cmd = "python scripts/railway_pre_deploy_migrate.py"` séparé de start.cmd.
**Warning signs :** Si Julien revert `-w 2` un jour : Railway logs montrent `alembic.util.exc.CommandError: Multiple version traversals not allowed` ou `relation "alembic_version" deadlock detected`.

### Pitfall 4 — REVOKE UPDATE, DELETE sur Railway role insuffisant (HIGH — verified Wave 0)
**What goes wrong :** p98 ligne (substrat) émet `REVOKE UPDATE, DELETE ON fact_event FROM PUBLIC` pour append-only enforcement. Si le rôle Railway connect-as n'est PAS superuser, le REVOKE peut échouer (« must be owner of table fact_event »).
**Why it happens :** Railway managed Postgres expose un user-level role, pas root. La table appartient à ce role, donc REVOKE devrait passer — **mais non-vérifié**. Pre-flight checklist item #11 explicitement.
**How to avoid :** Wave 0 step 1 : `railway ssh -e staging --service MINT 'psql $DATABASE_URL -c "\\dp fact_event"'` pour voir privileges + `psql -c "SELECT current_user"`. Si REVOKE a échoué silencieusement (alembic upgrade success mais grants pas modifiés), shipper hotfix migration qui supprime la REVOKE et documente l'enforcement app-layer-only (FactProjector empêche tout autre write).
**Warning signs :** `psql -c "\\dp fact_event"` montre `=rwUDxt/...` pour role PUBLIC alors qu'on attendait `=r/...` seul (READ only).

### Pitfall 5 — 7-day soak « override » par 0-user-prod sans documentation (MEDIUM)
**What goes wrong :** Julien override le 7-day continuous_drift_sampler clean window verbalement, on merge PR-3b, plus tard une régression apparait et personne ne se souvient que l'override était scopé « parce que 2 test accounts uniquement ».
**Why it happens :** iter-2 B20 réconcilie 7-day min / 14-day target. Le 0-user-prod premise (CONTEXT.md Open-Q #4) légitime un override mais demande une trace écrite.
**How to avoid :** Si override choisi → écrire dans PR-3b body : « override per CONTEXT.md§Open-Q #4 — 2 prod test accounts (Julien + Lauren), confirmed by [memory project_byok_scope + preflight_zero_user_gate stdout], soak shortened to N days from 7-day minimum ». Lier obs engram. PR-3b commit message inclus.
**Warning signs :** PR-3b body sans rationale explicite ; futur dev voit le pattern et override « parce qu'on l'a déjà fait ».

### Pitfall 6 — `mint_snapshot_fact_current_drift_total` counter référencé mais jamais déclaré (HIGH, PR B step 1)
**What goes wrong :** 4+ plans (Plan 02-03 PR-2 truths, Plan 02-04 Sentry alert, Pattern 5 above) référencent ce counter. **Inspection 2026-05-19 :** `grep -rn "mint_snapshot_fact_current_drift_total" services/backend/` retourne ZÉRO match. Le counter n'a jamais été déclaré.
**Why it happens :** Counter référencé conceptuellement dans plans, jamais propagé à `counters.py`. Audit observability HANDOFF B-1 le flag.
**How to avoid :** **PR B step 1 obligatoire** : `mint_snapshot_fact_current_drift_total = Counter('mint_snapshot_fact_current_drift_total', 'Drift events between SnapshotModel and fact_current post-cutover', labelnames=['field_key'])` dans `counters.py` ; export via `__all__`. Wire dans `continuous_drift_sampler.py` après chaque diff détecté. `declared_counters_must_fire` Task 3 monte à **9 counters** (8 + ce nouveau).
**Warning signs :** Sentry alert rule créée mais ne fire jamais → counter introuvable → debug 2h.

### Pitfall 7 — Forme « event_id <= latest_event_id » UUID4 (medium — déjà résolu)
**What goes wrong :** CONTEXT.md ligne ~D-27 cite « event_id sequence-number monotonicity » comme sémantique idempotence. UUID4 est **random** (123 bits entropy), pas monotone. Le predicate `<=` n'a aucun sens.
**Why it happens :** Mauvais transfert depuis design draft où l'idempotence était basée sur `created_at` (monotone).
**How to avoid :** HANDOFF lock #2 : **EXACT-EQUALITY via PK collision** (Pattern 3 above). Mobile L1 supply stable UUIDs for retry semantics. Documenter EXPLICITEMENT dans PR A2 commit message.
**Warning signs :** Test `test_projector_idempotency_replay_skip.py` qui passe sur SQLite ORDER BY mais échoue dès qu'on a 2 UUID lex-désordonnés.

### Pitfall 8 — iOS entitlement bundlé avec PR features (HIGH — memory)
**What goes wrong :** `sqflite_sqlcipher` iOS production impl requiert Keychain entitlement (`com.apple.developer.*`) dans `Runner.entitlements`. Si bundlé avec autres changes Mobile L1 dans même PR, fastlane match profile update + Apple Developer portal coordination devient bloquant pour autre logique non-iOS.
**Why it happens :** memory `feedback_ios_entitlements_block_testflight` document explicitement le risque (release-blocking).
**How to avoid :** PR A4 splittée :
- **A4a** : Dart-side (`audit_buffer_db.dart` prod impl avec sqflite_sqlcipher, `main.dart` observer wiring, connectivity_plus integration). Pas de plist change.
- **A4b** : iOS Runner.entitlements + fastlane match profile update — **PR isolée**, mergée avant ou après A4a au choix de Julien sur la fenêtre Apple Developer portal.
**Warning signs :** PR A4 modifie `apps/mobile/ios/Runner/Runner.entitlements` ET `apps/mobile/lib/main.dart` ensemble.

## Code Examples

### Pattern A — `alembic` chain audit programmatique (Wave 0)

```python
# Source: services/backend/alembic.ini + ScriptDirectory API (verified 2026-05-19)
from alembic.config import Config
from alembic.script import ScriptDirectory

cfg = Config('services/backend/alembic.ini')
script = ScriptDirectory.from_config(cfg)

print('HEADS:', script.get_heads())                                # ['p119_phase02_parity_cont']

# Chaîne prod→dev déterministe
prod_head = '29_05_magic_link_tokens'
dev_head  = 'p119_phase02_parity_cont'
gap = list(script.iterate_revisions(dev_head, prod_head))           # 14 revisions à appliquer
for rev in gap:
    print(rev.revision, rev.doc.split('\n')[0])
```

Cette commande **doit être runnée Wave 0 step 1**. Output = artifact de l'audit, à coller dans `01-alembic-chain-audit-PLAN.md` + `VERIFICATION-REPORT.html`.

### Pattern B — Railway DB state probe (run pre-each-wave)

```bash
# Source: HANDOFF-2026-05-19.md Next-session entry command (verified)
railway ssh -e staging --service MINT 'python3 -c "
import os, psycopg2
url = os.getenv(\"DATABASE_URL\")
c = psycopg2.connect(url); cur = c.cursor()
cur.execute(\"SELECT version_num FROM alembic_version\")
print(\"alembic head:\", cur.fetchone())
cur.execute(\"SELECT EXISTS(SELECT 1 FROM pg_tables WHERE tablename=\\047fact_event\\047)\")
print(\"fact_event:\", cur.fetchone())
cur.execute(\"SELECT EXISTS(SELECT 1 FROM pg_tables WHERE tablename=\\047fact_current\\047)\")
print(\"fact_current:\", cur.fetchone())
cur.execute(\"SELECT current_user, current_database()\")
print(\"identity:\", cur.fetchone())
cur.execute(\"SELECT n_live_tup FROM pg_stat_user_tables WHERE relname IN (\\047fact_event\\047, \\047fact_current\\047, \\047snapshots\\047)\")
print(\"row counts:\", cur.fetchall())
"'
```

Évidence déterministique post-Wave-N : sauvegarder stdout dans `.planning/phases/.../wave-N-probe-YYYY-MM-DD.txt` + cite obs engram.

### Pattern C — Task 2a operational gate sequence (Wave 1)

```bash
# 1. Verify staging deploy outcome (carry from this session)
railway ssh -e staging --service MINT 'echo $FF_FACT_EVENT_DUAL_WRITE'   # → empty (unset, OK)

# 2. Run preflight_zero_user_gate against staging
DATABASE_URL=$STAGING_DATABASE_URL python3 services/backend/scripts/preflight_zero_user_gate.py
# Expected: BLOCKED if staging has 131 users (CONTEXT.md ligne 40)
# → DOCUMENT override : "staging has 131 test users, justification = pre-launch staging premise"

# 3. Set FF on staging (NOT prod)
railway variables set FF_FACT_EVENT_DUAL_WRITE=on --environment staging --service MINT

# 4. Wait Railway re-deploy (~30-60s)
gh run watch  # OR sleep 60 + curl /metrics

# 5. Run backfill — first pass
railway ssh -e staging --service MINT 'cd /app && python scripts/backfill_snapshot_to_fact_event.py --apply' > /tmp/backfill_run1.log
N_RUN1=$(railway ssh -e staging --service MINT 'psql $DATABASE_URL -tAc "SELECT count(*) FROM fact_event WHERE source_type='\''snapshot_backfill'\''"')

# 6. Run backfill — second pass (idempotence proof)
railway ssh -e staging --service MINT 'cd /app && python scripts/backfill_snapshot_to_fact_event.py --apply' > /tmp/backfill_run2.log
N_RUN2=$(railway ssh -e staging --service MINT 'psql $DATABASE_URL -tAc "SELECT count(*) FROM fact_event WHERE source_type='\''snapshot_backfill'\''"')
test "$N_RUN1" = "$N_RUN2"  # idempotent assertion

# 7. Run projection_diff full audit
railway ssh -e staging --service MINT 'cd /app && DATABASE_URL=$DATABASE_URL python -m tools.parity.projection_diff --audit-all-users --persist-to _phase02_parity_audit' > /tmp/full_parity_audit.log

# 8. Verify zero diff
USERS_WITH_DIFF=$(railway ssh -e staging --service MINT 'psql $DATABASE_URL -tAc "SELECT count(*) FROM _phase02_parity_audit WHERE diff_detected"')
test "$USERS_WITH_DIFF" = "0"  # acceptance criterion

# 9. Check idempotency counter
curl -sf https://mint-staging.up.railway.app/metrics | grep mint_projector_idempotency_skip_total
# Expected: ≥ N_RUN1 (one skip per backfilled row on re-run)

# 10. Julien gate signal
echo "approved PR-3a — backfill idempotent, 100% staging-user parity audit zero diff, projection_diff.py deterministic"
```

### Pattern D — D-27 idempotency dans `project_event` (PR A2)

```python
# Source: HANDOFF panel design + Pattern 3 above
# services/backend/app/services/projector/fact_projector.py

from sqlalchemy.exc import IntegrityError
from app.observability.counters import mint_projector_idempotency_skip_total

def project_event(session, event):
    event_id = event.event_id or str(uuid4())
    if session.in_transaction():
        ctx = session.begin_nested()
    else:
        ctx = session.begin()
    try:
        with ctx:
            fe = FactEvent(event_id=event_id, user_id=event.user_id, ...)
            session.add(fe)
            session.flush()  # surface IntegrityError now, before UPSERT
            # ... UPSERT fact_current ... (existing pattern)
            # NEW : update fact_current.latest_event_id = event_id
    except IntegrityError as ie:
        # PK collision on (event_id, user_id) = replay → idempotent skip
        if 'fact_event_pkey' in str(getattr(ie.orig, 'pgerror', '')) or 'UNIQUE constraint failed: fact_event' in str(ie.orig):
            mint_projector_idempotency_skip_total.inc()
            return event_id
        raise

    return event_id
```

### Pattern E — alembic head verification dans CI

```yaml
# Source: .github/workflows/deploy-backend.yml extension (PR B step 5)
- name: Verify alembic upgrade succeeded post-deploy
  if: github.event.pull_request.base.ref == 'staging' || github.event.pull_request.base.ref == 'main'
  env:
    RAILWAY_TOKEN: ${{ secrets.PROJECT_STAGING_TOKEN }}
  run: |
    npm install -g @railway/cli
    EXPECTED=$(cd services/backend && python -c "from alembic.config import Config; from alembic.script import ScriptDirectory; print(ScriptDirectory.from_config(Config('alembic.ini')).get_current_head())")
    ACTUAL=$(railway ssh -e staging --service MINT 'python -c "import os,psycopg2; c=psycopg2.connect(os.getenv(\"DATABASE_URL\")); cur=c.cursor(); cur.execute(\"SELECT version_num FROM alembic_version\"); print(cur.fetchone()[0])"')
    test "$EXPECTED" = "$ACTUAL" || (echo "::error::alembic mismatch expected=$EXPECTED actual=$ACTUAL"; exit 1)
```

À adopter dans **PR B**. Filet déterministe : si Railway deploy passe mais migrations échouent silencieusement, ce check le détecte.

## State of the Art

| Old Approach | Current Approach | Quand a changé | Impact |
|--------------|------------------|------------------|--------|
| Bitemporal substrate (with `transaction_time` column) | Event-log + projection (`fact_event` append + `fact_current` UPSERT) | 2026-05-17 ADR `2026-05-17-data-architecture-event-log-vs-bitemporal.md` | Plus simple + crypto-shred natif via DEK envelope ; coût = projection rebuild si schema change. |
| SnapshotModel keyed sur inputs_hash | fact_event source-of-truth + fact_current denormalised PK (user_id, field_key) | Phase 02 substrate 2026-05-19 | Cache élimination ; eligible LSFin audit trail ; point-in-time queries via fact_event. |
| `psycopg2` adapter `register_default_jsonb` global | Cast inline `::jsonb` dans `text()` raw SQL | SQLAlchemy 2.0+ best practice | Plus dialect-portable ; le global adapter peut surprendre du code legacy. [CITED: [SQLAlchemy issue #11994](https://github.com/sqlalchemy/sqlalchemy/issues/11994)] |
| Railway gunicorn prestart inline | Railway native **Pre-Deploy Command** | Feature shipped 2025-01-10 ([Railway changelog](https://railway.com/changelog/2025-01-10-pre-deploy-command)) | Sépare migration run de gunicorn boot — élimine race condition multi-worker. **Pas adopté cette phase** (Karpathy #3) ; follow-up Phase 03. |
| `disable_existing_loggers` defaulting True | `fileConfig(..., disable_existing_loggers=False)` | Phase 02 substrate PR #658 (root-cause fix) | Élimine la cascade caplog flake systémique. |
| Manual per-test caplog mock | Root-cause env.py + autouse conftest fixture | Plan 02-02 + PR #658 | Réduit surface maintenance ; tests deviennent robustes au-delà de Phase 02. |
| In-memory AuditBufferDb (Mobile L1 dev) | sqflite_sqlcipher persistent buffer + Keychain passphrase | DEFERRED-02-02-D landing PR A4 | iOS production-grade : audit events survivent cold-start, chiffrement at-rest. |

**Deprecated / outdated :**
- `register_default_jsonb` global engine-level adapter : viable mais discouraged en faveur de cast inline pour réduire surprise factor (cf. [SQLAlchemy discussions #10944](https://github.com/sqlalchemy/sqlalchemy/discussions/10944)).
- gunicorn `-w 2+` sur Railway sans Pre-Deploy Command séparé : race condition migration.
- `SnapshotModel` (sera dropped PR-5).
- `feature_flags.FF_FACT_EVENT_DUAL_WRITE` env var (sera retiré PR-4).
- `tools/checks/profile_safe_fields_parity_allowlist.txt` (sera supprimé Plan 02-04 Task 1 / D-10).

## Validation Architecture

> Phase 02-deploy ne désactive PAS `workflow.nyquist_validation` (config absent = enabled). Section incluse.

### Test Framework
| Property | Value |
|----------|-------|
| Backend framework | pytest 7+ avec testcontainers-postgres extras |
| Backend config | `services/backend/pyproject.toml` (extras `[dev]` + `[rag]` + `[docling]`) |
| Backend quick run | `cd services/backend && python3 -m pytest tests/ -q -k "not pg and not slow"` |
| Backend full suite | `cd services/backend && python3 -m pytest tests/ -q` (run sur SQLite par défaut ; testcontainers active via pg_fixture pytest marker `requires_pg`) |
| Mobile framework | flutter test (Dart VM) + flutter integration_test (sim) |
| Mobile quick | `cd apps/mobile && flutter analyze && flutter test test/<scope>` |
| Mobile full | `cd apps/mobile && flutter test` |
| Phase gate | suite Full backend green + flutter test green + 5-gate panel evidence captured |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists ? |
|--------|----------|-----------|-------------------------|-------------|
| D-27 (redéfini) | `project_event` skip propre sur PK collision | integration pg | `pytest tests/integration/test_projector_idempotency_replay_skip.py -q` | ❌ Wave 0 (PR A2 NEW) |
| D-27 (extension Mobile) | `/v1/audit_mobile` accept caller-supplied event_id | integration | `pytest tests/integration/test_audit_mobile_event_id_passthrough.py -q` | ❌ Wave 0 (PR A2 bonus) |
| JSONB cast | `_json_bind` value survit sur Postgres réel | integration pg | `pytest tests/integration/test_fact_projector_jsonb_postgres.py -q -k pg` | ❌ Wave 0 (PR A3 NEW) |
| Dual-write rollback | DEK revoked mid-loop → rollback atomique | integration pg | `pytest tests/integration/test_dual_write_failure_rollback.py -q -k pg` | ❌ Wave 0 (PR A3 NEW) |
| HMAC pepper rotation | `monkeypatch.setenv` + `lru_cache` interaction | integration pg | `pytest tests/integration/test_hmac_pepper_rotation.py -q -k pg` | ❌ Wave 0 (PR A3 NEW) |
| D-05 PR-3a backfill idempotence | row-count delta = 0 sur 2e run | integration pg + manual smoke staging | `pytest tests/integration/test_backfill_idempotent.py -q -k pg` + Pattern C steps 5-6 | ✅ exists (Plan 02-03 substrate) |
| D-05 PR-3a parity audit | 100% staging-user zero diff | manual + integration | `pytest tools/parity/tests/test_projection_diff.py -q` + Pattern C step 7-8 | ✅ exists |
| D-05 PR-3b read-cutover | `/v1/projection` reads from fact_current | integration | `pytest tests/integration/test_read_cutover.py -q` | ✅ shipped Plan 02-03 substrate |
| D-12/D-31 parity-lint HARD | `profile_safe_fields_parity.py --hard` exit 0 | lint | `python3 tools/checks/profile_safe_fields_parity.py --hard --allowlist tools/checks/profile_safe_fields_parity_allowlist.txt` | ✅ exists |
| D-05 PR-4 FF removal | `git grep FF_FACT_EVENT_DUAL_WRITE` returns 0 | grep | `git grep -nF "FF_FACT_EVENT_DUAL_WRITE" services/backend/app/ \| wc -l` ⇒ 0 | n/a |
| D-05 PR-5 SnapshotModel drop | alembic p117 applies + ORM removed | migration | `pytest tests/integration/test_snapshot_drop.py -q -k pg` | ✅ exists |
| D-33 declared counters fire | all 9 counters increment ≥ 1 in scenario | lint + integration | `python3 tools/checks/declared_counters_must_fire.py` | ❌ Wave 0 (Plan 02-04 Task 3) |
| `mint_snapshot_fact_current_drift_total` declared | counter visible in /metrics | grep + smoke | `curl -sf $STAGING_BASE_URL/metrics \| grep mint_snapshot_fact_current_drift_total` | ❌ PR B step 1 |
| Continuous drift sampler 7-day clean | 0 dirty rows in 24h adjacent merge | sql | Pattern in PLAN.md Task 2b how-to-verify step 2 | ✅ infra exists |
| DEFERRED-02-02-C lefthook wired | `no_mobile_fact_current_regulatory_read.py` pre-commit | lefthook | `lefthook run pre-commit -f` on a violating mobile file | ❌ Wave 3 (PR A4 wiring) |
| DEFERRED-02-02-D sqflite_sqlcipher | open db with passphrase, write+read cycle | flutter integration | `flutter test integration_test/audit_buffer_db_sqlcipher_test.dart` | ❌ Wave 3 (PR A4) |
| DEFERRED-02-02-E main.dart observer | `recordColdStart()` fires on bootstrap | flutter test | `flutter test test/services/mobile_l1_lifecycle_test.dart` | ❌ Wave 3 (PR A4) |
| DEFERRED-02-02-F connectivity_plus | drain triggered on connectivity restore | flutter test | `flutter test test/services/offline_audit_queue_connectivity_test.dart` | ❌ Wave 3 (PR A4) |
| Q6 CI STAGING-MALFORMED | distinguish 200-malformed from 503-down | workflow self-test | `python3 .github/workflows/_self_test/staging_status_test.py` | ❌ Wave 3 (Plan 02-04 Task 2) |
| sec FLAG-2 scenario_inputs_hash | quasi-identifier scrubbed in event_log | lint | `pytest tests/compliance/test_event_log_no_quasi_identifier.py -q` | ❌ Wave 3 |
| sec FLAG-4 DSAR manifest event_log | `/v1/users/dsar` includes fact_event entries | integration | `pytest tests/integration/test_dsar_event_log_inclusion.py -q -k pg` | ❌ Wave 3 |
| sec FLAG-5 pre-existing baseline trim | event_log size bounded for pre-Phase-02 users | integration pg | `pytest tests/integration/test_event_log_baseline_trim.py -q -k pg` | ❌ Wave 3 |
| arch FLAG-3 subject_type forward-lint | lint catches `subject_type='user'` without registry check | lint | `python3 tools/checks/subject_type_forward_lint.py` | ❌ Wave 3 |

### Sampling Rate

- **Per task commit :** `cd services/backend && python3 -m pytest tests/ -q -k "not pg and not slow"` (~20s SQLite-only).
- **Per wave merge :** `cd services/backend && python3 -m pytest tests/ -q` (full suite, includes pg_fixture tests, ~3 min).
- **Mobile (PR A4) per push :** `cd apps/mobile && flutter analyze && flutter test`.
- **Phase gate (Wave 4 close-out) :** full suite green + 5-gate panel evidence + Maestro G1 sweep on Mobile L1 wired surface + Julien G2 device sign-off.

### Wave 0 Gaps

- [ ] `services/backend/tests/integration/test_projector_idempotency_replay_skip.py` — couvre D-27 EXACT-EQUALITY (PR A2).
- [ ] `services/backend/tests/integration/test_projector_natural_key_pk_collision.py` — exerce PK collision path (PR A2).
- [ ] `services/backend/tests/integration/test_dual_write_replay_safe.py` — full integration via snapshot_service (PR A2).
- [ ] `services/backend/tests/integration/test_audit_mobile_event_id_passthrough.py` — Mobile L1 retry stable UUIDs (PR A2 bonus).
- [ ] `services/backend/tests/integration/test_fact_projector_jsonb_postgres.py` — JSONB cast survival (PR A3).
- [ ] `services/backend/tests/integration/test_dual_write_failure_rollback.py` — DEK revoked → atomic rollback (PR A3).
- [ ] `services/backend/tests/integration/test_hmac_pepper_rotation.py` — `lru_cache` interaction (PR A3).
- [ ] `apps/mobile/integration_test/audit_buffer_db_sqlcipher_test.dart` — passphrase + write/read cycle (PR A4).
- [ ] `apps/mobile/test/services/mobile_l1_lifecycle_test.dart` — `recordColdStart()` fires (PR A4).
- [ ] `apps/mobile/test/services/offline_audit_queue_connectivity_test.dart` — drain on restore (PR A4).
- [ ] `tools/checks/alembic_partition_safety_lint.py` — AST walk migrations (PR B).
- [ ] `tools/checks/tests/test_alembic_partition_safety_lint.py` — fixture good+bad migration AST (PR B).
- [ ] `tools/checks/declared_counters_must_fire.py` — assert 9 counters fire (Plan 02-04 Task 3).
- [ ] `services/backend/tests/integration/test_dsar_event_log_inclusion.py` — sec FLAG-4 (Wave 3).
- [ ] `services/backend/tests/compliance/test_event_log_no_quasi_identifier.py` — sec FLAG-2 (Wave 3).
- [ ] `services/backend/tests/integration/test_event_log_baseline_trim.py` — sec FLAG-5 (Wave 3).
- [ ] `tools/checks/subject_type_forward_lint.py` — arch FLAG-3 (Wave 3).
- [ ] `tools/db/railway_pg_dump.sh` — baseline capture (PR B).
- [ ] `tools/db/pre_pr3b_pg_dump.sql` — committed dans PR-3b branch (Wave 2 step capture).

## Security Domain

> `security_enforcement` n'est pas explicitement `false` dans config → section incluse.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|--------------------|
| V2 Authentication | yes | Existing Phase 01 magic-link + session middleware (pas touché ici) |
| V3 Session Management | yes | Existing session/auth — pas modifié cette phase |
| V4 Access Control | yes | Substrate p98 REVOKE UPDATE,DELETE ON fact_event FROM PUBLIC + RLS sur user_id (à verifier Wave 0) |
| V5 Input Validation | yes | Pydantic v2 schemas (`projection.py`, `audit_mobile.py`) ; `_FACT_TYPE_MAP` allow-list dans backfill ; `tools/checks/banned_terms_python.py` étendu fact_event payload |
| V6 Cryptography | yes | DEK envelope encryption via `key_vault.py` + `encrypt_value/decrypt_value` helpers ; **never hand-roll** (HKDF + AES-GCM standard) ; HMAC pepper via `hmac_pepper.py` ; Mobile L1 sqflite_sqlcipher + Keychain passphrase |
| V7 Error Handling | yes | `IntegrityError` skip path PR A2 NE doit pas leak constraint name to client (production safety) |
| V8 Data Protection | yes | Audit retention 10y (D-07 runbook Task 4) ; DSAR manifest event_log inclusion (sec FLAG-4 Wave 3) |
| V10 Malicious Code | yes | LSFin banned-terms lint extended to JSONB payload Phase 02 (Plan 02-04 Task 2 already shipped) |

### Known Threat Patterns for Postgres + Railway + Mobile L1 stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|------------------------|
| SQL injection via raw `text()` bind | Tampering | Parameterized binds (`:value_enc`) — déjà OK. Vigilance sur tout nouveau `text()` ajouté (PR A3 cast inline check). |
| Drift sampler exposes user_id_hash linkage | Information disclosure | `_phase02_parity_audit_continuous.user_id_hash` = HMAC(pepper, user_id), pas user_id clair. Pepper rotation = Phase 04 runbook. |
| FF_FACT_EVENT_DUAL_WRITE set on prod accidentally | Spoofing/Tampering | Railway variables CLI requires `--environment` flag + Wave 1 Pattern C uses `--environment staging` explicitly ; pre-flight checklist item #7 verifies. |
| pg_dump file commited contains secrets | Information disclosure | `pg_dump --no-comments --no-owner --no-privileges` + greps for `password\|api_key\|secret` before commit. Document in `tools/db/railway_pg_dump.sh`. |
| Backfill exhausts Railway connection pool | DoS | Throttled pool `pool_size=2, max_overflow=0` (iter-2 B15 — déjà shipped Plan 02-03 substrate). |
| Mobile L1 audit buffer leak post-uninstall | Information disclosure | sqflite_sqlcipher passphrase derived from Keychain (iOS) — passphrase deleted on uninstall, DB unreadable. |
| iOS entitlement misconfig grants too much | Tampering | Isolated PR A4b for entitlements ; security-auditor + mobile-security-coder review (per routing rules). |
| Cron sampler hits prod accidentally | Tampering | `STAGING_BASE_URL` + `STAGING_DATABASE_URL` env vars only ; sampler `_resolve_required_env` raises on absent (verified `continuous_drift_sampler.py:48-50`). |
| `_phase02_parity_audit*` tables contain decrypted projections | Information disclosure | These tables store **diff metadata only** (count, summary) ; full payloads stay in encrypted `fact_event.value_enc`. Verify via grep of column definitions PR B audit. |

## Counter-arguments + data gaps

(Per CLAUDE.md §8 wiki-lint convention — bias-check against echo-chamber.)

### Counter-arguments considered

1. **« On peut tout exécuter en une seule wave + Wave 4 = duplication. »**
   Rejeté. Staging-first pattern n'est pas duplication — c'est le filet déterministe. Wave 1 (staging) + Wave 4 (prod) sont **deux runs distincts** avec deux baseline pg_dumps. Si Wave 1 trouve une régression non-prévue, on patch et on re-run sans toucher prod. Compresser = perdre cette safety.

2. **« Le 4-PR cleanup (A2/A3/B/D) appartient à Phase 02 substrate, pas à Phase 02-deploy. »**
   Discutable. Argument pour : ce sont des fixes au substrat qui sont nés post-merge. Argument contre : (a) le substrat est gelé (« code-shipped on dev » selon SUMMARY.md), réouvrir invalide la close-out vérifiée ; (b) PR A2 (D-27 idempotency) est **bloquant pour Task 2a Wave 1** — sa place naturelle est en pré-requis Wave 1, pas dans une re-ouverture du substrat. Décision : garder en Phase 02-deploy pre-Wave-1.

3. **« Pourquoi 7-day soak alors que prod a 2 test accounts ? »**
   Tradeoff valide. iter-2 B20 documente 7-min/14-target. Le 0-user-prod premise (CONTEXT.md §Open-Q #4) légitime un override **DOCUMENTÉ** (Pitfall 5 above). Recommandation : ne pas réduire en-dessous de 24h consécutives clean — c'est le minimum pour qu'un bug cron-de-30min ait l'opportunité d'apparaître au moins 48 fois.

4. **« On devrait migrer Procfile vers Railway Pre-Deploy Command maintenant. »**
   Rejeté pour cette phase (Karpathy #3 surgical). La feature 2025-01 est viable, mais migrer Procfile→nixpacks.toml dans Phase 02-deploy ajoute une surface de risque (un changement deploy mechanism pendant qu'on cutover SnapshotModel = deux variables en flight). Track comme follow-up Phase 03.

5. **« sqflite_sqlcipher pourrait être déféré post-launch ; in-memory marche. »**
   Rejeté. memory `feedback_design_panel_before_push` + DEFERRED-02-02-D risk = HIGH pour TestFlight (audit events lost on cold-start). Sans Mobile L1 device-side persistent buffer, le contrat `/v1/audit_mobile` est cassé end-to-end. Bundling A4 dans cette phase **ferme le contrat substrate**.

6. **« Le drift counter manquant n'est pas un bloqueur. »**
   Rejeté. Sentry alert dépend de ce counter ; PR-4 FF removal + PR-5 SnapshotModel drop dépendent du soak window ; le soak dépend de l'observabilité du drift. Pas de counter = pas de soak vérifiable. PR B step 1 = bloqueur dur.

7. **« On pourrait scriptifier l'override Sentry alert au lieu d'UI Julien-only. »**
   Tradeoff. Sentry a une API mais aussi des changements UI. Le coût d'écrire un script idempotent qui crée/maintient l'alert rule > le coût Julien de 5 min UI. Karpathy #2 simplest. Décision : runbook documenté, Julien execute.

### Data gaps (require investigation before plans)

- **Pourquoi prod alembic est à `29_05_magic_link_tokens` exactement.** HANDOFF devops résolu : pas un fork, juste « no merges to main since 2026-04-21 ». **Validation Wave 0 step 0** : `git log origin/main --oneline --since="2026-04-21"` doit retourner 0 commits backend-touching depuis cette date.
- **Privilèges du role Railway sur staging+prod Postgres.** Pre-flight checklist item #11. Wave 0 step 1 : `\\dp fact_event` pour voir si REVOKE p98 a réussi.
- **Existence + état de `dek_vault` sur staging post-PR-#660 deploy.** Verifyer present + non-empty (chaque user existant doit avoir une row DEK envelope encrypted).
- **Validation pg_fixture (testcontainers) sur CI runner.** Si le runner GH Actions n'a pas Docker-in-Docker, les tests `-k pg` skipent silencieusement. Run un sanity check Wave 0 + promote `pg-integration` to required check (PR B).
- **Compatibilité sqflite_sqlcipher 3.x avec Xcode 16.x (si Julien upgrade).** Le pubspec recommande Xcode 15.x ; si Xcode 16 est dispo, vérifier compat avant PR A4. [CITED: [pub.dev sqflite_sqlcipher](https://pub.dev/packages/sqflite_sqlcipher)]
- **État des 2 prod users (Julien + Lauren test accounts).** Vérifier qu'aucune row dans `snapshots` ou tables intersectant la chaîne migration prod→dev. CONTEXT.md §Data gaps item 3 — non-vérifié à ce jour.
- **Si `pg-soak-nightly.yml` a déjà été activé une fois.** Greppable via GH Actions run history — si oui, comprendre pourquoi désactivé et si rows polluent `_phase02_parity_audit_continuous`.
- **Si `mint_snapshot_fact_current_drift_total` est référencé dans un test qui assume sa déclaration.** `grep -rn "mint_snapshot_fact_current_drift_total" services/backend/tests/` — si oui, ces tests fail silencieusement aujourd'hui (le counter `_NoOp()` no-op `.inc()` ne raise pas).

## Assumptions Log

| # | Claim | Section | Risk si faux |
|---|-------|---------|---------------|
| A1 | Le 7-day soak override est acceptable car 0-user-prod (2 test accounts) | Pitfall 5 + Counter-arg #3 | Si Julien veut soak strict, ajoute 6-13 jours wall-clock à Wave 2. [ASSUMED] |
| A2 | Railway `-w 1` gunicorn neutralise la race condition `prestart && start` | Pattern 1 + Pitfall 3 | Si Julien revert à `-w 2`, migrations race condition. Phase 03+ follow-up. [ASSUMED] |
| A3 | La REVOKE p98 sur Railway managed role a réussi | Pitfall 4 | Si échouée, hotfix migration nécessaire ; pas un blocker mais à confirmer Wave 0. [ASSUMED — Wave 0 step 1 verifies] |
| A4 | Le 4-PR cleanup (A2/A3/B/D) appartient en pre-Wave-1, pas en re-ouverture substrat | Counter-arg #2 | Si on les pousse en re-open Phase 02 substrate, la close-out audit log Phase 02 devient invalide. [ASSUMED — décision lockée HANDOFF] |
| A5 | Sentry Metric Alert UI est viable pour drift counter alert | Don't Hand-Roll + Pattern Sentry | Si Sentry plan tier ne supporte pas metric alerts, fallback Grafana Cloud. [ASSUMED — Julien plan unknown] |
| A6 | sqflite_sqlcipher 3.x compatible avec Xcode actuel + iOS 14+ target | Standard Stack + Pitfall 8 | Si incompat, scope creep Mobile sur PR A4. [CITED: pub.dev] |
| A7 | Prod 14-rev gap est purement temporel (no merges to main since 2026-04-21), pas un fork ni un schema diverged | Summary + Counter-arg | Si fork detected Wave 0, Wave 4 strategy doit changer (rebase migration chain sur prod head). [ASSUMED — devops resolved per HANDOFF] |
| A8 | Le counter `mint_snapshot_fact_current_drift_total` n'a JAMAIS été déclaré nulle part dans backend | Pitfall 6 | Si déclaré ailleurs (e.g., un autre module), PR B step 1 cause double-declaration. [VERIFIED: grep returns 0 matches 2026-05-19] |
| A9 | Le panel design 4-person review pour PR A4 est exécutable en une session GSD (spawn parallèle) | CLAUDE.md routing rules | Si panel timeline > session, A4 spans 2 sessions. [ASSUMED — historical precedent in Phase 01-02 panel runs] |
| A10 | Le post-deploy alembic head check (Pattern E) est trivialement ajoutable à `deploy-backend.yml` | Pattern E + PR B | Si GH Actions secrets manquants pour `railway ssh` from action runner, refactor needed. [ASSUMED — RAILWAY_TOKEN already there] |

## Open Questions

1. **Faut-il bundler PR A2 + le `/v1/audit_mobile` event_id wire-through (+20 LOC) ?**
   What we know : postgres-pro recommande oui (sinon D-27 ne couvre que backfill path, pas Mobile L1 retries).
   What's unclear : Julien call HANDOFF Open-Q #1.
   Recommandation : **bundler** dans PR A2 — surface +20 LOC, gain = D-27 complet end-to-end. Pas de raison de splitter sauf si Julien préfère commits surgicaux.

2. **Faut-il shipper PR B (railway_pg_dump.sh) AVANT Wave 1, OU se reposer sur Railway built-in rollback ?**
   What we know : Railway garde la version précédente si deploy échoue ; mais ce n'est PAS un point-in-time DB snapshot.
   What's unclear : si une migration applique partiellement (e.g., p120 ajoute col fact_current.latest_event_id mais p120's data fill échoue), Railway rollback retire le **code** mais pas la colonne (alembic n'a pas downgrade run).
   Recommandation : **PR B avant Wave 1**. Le baseline pg_dump est notre seul filet contre data corruption mid-migration.

3. **7-day soak override pour PR-3b — strict ou shortcut ?**
   What we know : iter-2 B20 = 7-min/14-target. 0-user-prod = 2 test accounts.
   What's unclear : combien de jours minimum pour qu'un override soit Julien-defensible ?
   Recommandation : **24h consécutives clean adjacent au merge OU 48h continuous_drift_sampler clean** (48 ticks × 30min = 48 opportunities to surface a bug). Documenter explicitement dans PR-3b body.

4. **Sentry alert wiring — Julien-only task timing ?**
   What we know : Julien dashboard task ; 5 min UI ; runbook Plan 02-04 Task 4.
   What's unclear : avant Wave 2 PR-3b OU après PR-4 ?
   Recommandation : **avant Wave 2** — si drift apparaît pendant le 7-day soak, on veut être alerté en temps réel, pas découvrir au merge PR-3b.

5. **PR D step 7 « delete defense-against-impossible code »** (sec FLAG-1 post-write divergence assertion ligne 151-181 fact_projector) — adopter ou rejeter ?
   What we know : Code defense-in-depth, +1 SELECT/`project_event` call. PR D recommande supprimer.
   What's unclear : si supprimé, on perd un filet contre ContextVar leak mid-cutover.
   Recommandation : **NE PAS supprimer dans cette phase** (Anti-Patterns to Avoid). Reconsidérer Phase 03 après 30j stable event-log.

6. **PR D step 8 « delete orphan staging Postgres service »** — confirmer no MINT vars reference cette service AVANT delete.
   What we know : devops finding HANDOFF.
   What's unclear : si quelque secret Railway ou env var pointe vers cette service.
   Recommandation : Wave 0 step 0 inclut un `railway variables --service MINT --environment staging | grep -i postgres` audit. Si zero match, safe to delete in PR D.

7. **Mobile drift baseline 40 vs 15 (DEFERRED-02-01-B)** — PR-A3 drop 3 allowlistés OU close full 40-field gap ?
   What we know : DEFERRED-02-01-B + DEFERRED-02-01-C documentent que le lint a un blind-spot static-analysis.
   What's unclear : option (a) extend lint (bigger surgery), option (b) duplicate emission in 4 inline blocks (mechanical).
   Recommandation : **option (b)** dans cette phase (mechanical, fits Karpathy #2), tracker (a) en backlog Phase 03+ refactor lint.

## Sources

### Primary (HIGH confidence)

- `services/backend/Procfile` — verified 2026-05-19 (Railway deploy entrypoint).
- `services/backend/Dockerfile` — Python 3.12-slim, libpq-dev, `pip install ".[rag,docling]"`.
- `services/backend/scripts/railway_pre_deploy_migrate.py` — bootstrap baseline stamp + `alembic upgrade head` subprocess.
- `services/backend/alembic/env.py` — `disable_existing_loggers=False` already in place + import models from `app.models`.
- `services/backend/alembic/versions/p98_fact_event_projection.py` — partition BY HASH + composite PK + REVOKE pattern (lignes 1-120).
- `services/backend/app/services/projector/fact_projector.py` — `_json_bind` string-bind pattern (ligne 186-195) + sec FLAG-1 post-write assertion (ligne 151-181).
- `services/backend/app/observability/counters.py` — 8 counters declared (ligne 54-103) ; `mint_snapshot_fact_current_drift_total` NOT declared.
- `services/backend/app/cron/continuous_drift_sampler.py` — Railway cron script (verified imports + behavior).
- `.github/workflows/deploy-backend.yml` — auto-deploy on PR merge staging/main (lignes 22-180).
- `.github/workflows/pg-soak-nightly.yml` — cron `*/30 * * * *` commented by default (ligne 21-23).
- `.planning/phases/mint-data-architecture-v1-02-deploy/CONTEXT.md` + `HANDOFF-2026-05-19.md`.
- `.planning/phases/mint-data-architecture-v1-02-event-log-projection/{SUMMARY.md, deferred-items.md, 03-PLAN.md, 04-PLAN.md}` — substrate close-out + deferred items.
- ScriptDirectory.walk_revisions API run 2026-05-19 — 14-rev chain prod→dev resolved deterministically.
- engram obs #233 (operational substrate gap) + #239 (fact_event PK + caplog) + #249 (staging-landed) [VERIFIED via mem_search this session].

### Secondary (MEDIUM confidence)

- [SQLAlchemy 2.1 PostgreSQL dialect](https://docs.sqlalchemy.org/en/21/dialects/postgresql.html) — JSONB best practices + `register_default_jsonb` pattern.
- [SQLAlchemy issue #11994 missing type cast for jsonb in values](https://github.com/sqlalchemy/sqlalchemy/issues/11994) — exact bug pattern for PR A3.
- [Railway Pre-Deploy Command docs](https://docs.railway.com/deployments/pre-deploy-command) — 2025-01 feature, follow-up Phase 03.
- [Railway changelog 2025-01-10](https://railway.com/changelog/2025-01-10-pre-deploy-command) — confirms feature shipped.
- [Railway pg-dump help station](https://station.railway.com/questions/pg-dump-and-pg-migrate-to-a-new-deployme-62d7d60e) — pg_dump/pg_restore on Railway.
- [pub.dev sqflite_sqlcipher](https://pub.dev/packages/sqflite_sqlcipher) — pubspec setup + iOS deployment target.
- [Medium SQLCipher Flutter tutorial](https://medium.com/@sumaiah.mitu/secure-sqlite-database-in-flutter-using-sqflite-sqlcipher-ffccbb008743) — Keychain passphrase derivation pattern.
- [Alembic Best Practices schema migration](https://www.pingcap.com/article/best-practices-alembic-schema-migration/) — rollback design patterns.

### Tertiary (LOW confidence — needs validation)

- [SQLAlchemy discussions #10944 JSONB serialization](https://github.com/sqlalchemy/sqlalchemy/discussions/10944) — alternative adapters ; not verified against current code.
- [oneuptime alembic migrations guide 2025](https://oneuptime.com/blog/post/2025-07-02-python-alembic-migrations/view) — general patterns ; not Railway-specific.

## Metadata

**Confidence breakdown :**

- Standard stack : HIGH — toutes versions/pkgs vérifiées dans pyproject/Dockerfile/Procfile/file inspection 2026-05-19.
- Architecture patterns : HIGH — patterns 1-6 tirés directement du code en place ou des plans iter-2 sourced (cités ligne par ligne).
- Don't hand-roll : HIGH — table dérivée de pratiques industry standard + memory `feedback_pre_push_checklist` + `feedback_no_micro_pauses` + skills SKILL.md.
- Common pitfalls : HIGH — chaque pitfall ancré sur un finding panel HANDOFF + obs engram (#233, #239) + inspection code, sauf P5 (override soak) qui dépend de Julien call (MEDIUM).
- Runtime State Inventory : HIGH — 5 catégories explicitement répondues, items vérifiés contre code + CONTEXT.md + HANDOFF + plans iter-2.
- Environment Availability : HIGH — toutes dépendances probes effectuées ou cited from previous session.
- Validation Architecture : HIGH — chaque REQ mappé à une commande test concrète ; 19 Wave 0 gaps listés exhaustivement.
- Security domain : HIGH — ASVS mapping standard + threat patterns spécifiques stack ; aucune fabrication.
- Counter-arguments + data gaps : MEDIUM — 7 counter-args + 8 data gaps surfacés, mais résolution effective dépend de Julien decision (Q1/Q3/Q4) + Wave 0 audit (Q2/Q5/Q7).
- Open questions : MEDIUM-HIGH — 7 Open-Qs typées avec recommendation Claude, à locker dans `/gsd-discuss-phase` step.

**Research date :** 2026-05-19
**Valid until :** 2026-06-19 (estimation — stable infra ; **invalider immédiatement** si Railway change Procfile/Pre-Deploy semantics, ou si Postgres major upgrade, ou si Phase 03 commence et touche `services/backend/app/services/projector/`).

## RESEARCH COMPLETE

**Phase :** mint-data-architecture-v1-02-deploy
**Confidence :** HIGH

### Key Findings

- **Chaîne alembic prod→dev = 14 révisions linéaires** (pas un fork — devops resolved per HANDOFF). Résolu déterministiquement via `ScriptDirectory.walk_revisions` API ; un seul nœud merge (`p98_merge_p86_eclairage` qui résorbe DEFERRED-02-01-A double-head).
- **Railway auto-deploy applique `alembic upgrade head` au boot worker** via `Procfile: web: sh -c 'python scripts/railway_pre_deploy_migrate.py && gunicorn ... -w 1'`. Race condition neutralisée par `-w 1`. Pas de Pre-Deploy Command séparé (follow-up Phase 03).
- **3 bugs systémiques détectés dans le substrat code (BLOCKING pre-Wave-1) :** (a) `_json_bind` string-bind à JSONB column masqué par SQLite (PR A3) ; (b) D-27 « event_id ≤ latest_event_id » impossible sur UUID4 random — redéfinir EXACT-EQUALITY via PK collision (PR A2) ; (c) `mint_snapshot_fact_current_drift_total` référencé par 4+ plans mais jamais déclaré dans `counters.py` (PR B step 1).
- **4-PR cleanup ordering locké :** A2 → A3 → B → D avant Wave 1 ; A4 (Mobile L1) appartient à Wave 3 avec design panel obligatoire + iOS entitlement isolé en sub-PR A4b.
- **0-trust §9 application stricte :** chaque Wave produit une évidence déterministe (alembic head post-deploy + projection_diff stdout + counters /metrics + pg_dump filename + Maestro sweep + Julien G2 device sign-off Wave 4).

### File Created

`.planning/phases/mint-data-architecture-v1-02-deploy/mint-data-architecture-v1-02-deploy-RESEARCH.md` (this file)

### Confidence Assessment

| Area | Level | Reason |
|------|-------|--------|
| Standard Stack | HIGH | Dockerfile / Procfile / pyproject vérifiés ligne-par-ligne |
| Architecture | HIGH | 6 patterns ancrés sur code en place + plans iter-2 cités |
| Pitfalls | HIGH | 8 pitfalls sourcés (panel HANDOFF + obs engram + grep verifs) |
| Validation Map | HIGH | 19 Wave 0 gaps + per-REQ test commands |
| Security | HIGH | ASVS standard + threat patterns stack-specific |
| Open Questions | MEDIUM-HIGH | 7 Open-Qs typées, résolution = `/gsd-discuss-phase` |

### Open Questions (for /gsd-discuss-phase)

7 Open-Qs surfacés (cf. § Open Questions ci-dessus). Recommandations Claude par défaut documentées ; le `/gsd-discuss-phase` step doit locker chaque réponse dans `DISCUSS.md` ou `CONTEXT.md addendum` avant `/gsd-plan-phase`.

### Ready for Planning

Recherche complète. **Next step** : `/gsd-discuss-phase mint-data-architecture-v1-02-deploy` pour résoudre les 7 Open-Qs, puis `/gsd-plan-phase mint-data-architecture-v1-02-deploy` pour générer les 4 PLAN.md par wave (`01-alembic-chain-audit`, `02-staging-migration-apply`, `03-cutover-PR3b-PR4-PR5`, `04-plan-02-04-tasks`) + VALIDATION.md.

Le planner peut commencer immédiatement avec :
- Section « User Constraints » comme contraintes invariantes.
- Section « Phase Requirements » comme REQ→PLAN map.
- Section « Validation Architecture » comme contrat Nyquist Dimension 8 / VALIDATION.md.
- Section « Common Pitfalls » comme verification steps obligatoires.
- Section « Don't Hand-Roll » comme guardrail anti-scope-creep.
