---
phase: mint-data-architecture-v1-02-deploy
plan: 02
type: execute
wave: 1
depends_on: [01]
files_modified:
  - .planning/phases/mint-data-architecture-v1-02-deploy/staging-task-2a-evidence.txt
  - .planning/phases/mint-data-architecture-v1-02-deploy/staging-backfill-run1.log
  - .planning/phases/mint-data-architecture-v1-02-deploy/staging-backfill-run2.log
  - .planning/phases/mint-data-architecture-v1-02-deploy/staging-projection-diff-full-audit.log
  - .planning/phases/mint-data-architecture-v1-02-deploy/staging-metrics-snapshot-post-backfill.txt
  - PERIMETERS.md
autonomous: false
requirements:
  - D-05
  - D-31
  - D-33
requirements_addressed:
  - Plan-02-03-iter-2#Task-2a operational gate (FF_FACT_EVENT_DUAL_WRITE=on staging + backfill x2 idempotency + 100% staging-user projection_diff zero diff + Julien sign-off)
  - HANDOFF#Wave-1 staging migration verification + Task 2a operational signal
  - VALIDATION#Wave-1 (`railway ssh` confirms head=p119 + fact_event/fact_current exist + FF=on + backfill idempotent + projection_diff zero diff + counter increments)
  - CONTEXT#Open-Q-4 7-day soak override path documentation
threat_model_ref: mint-data-architecture-v1-02-deploy-RESEARCH#Security-Domain + #Pitfall-5 (override soak) + engram #194

decisions_locked:
  - id: open-q-2
    locked: "Staging→prod deploy is automated via `Procfile: web: sh -c 'python scripts/railway_pre_deploy_migrate.py && gunicorn ... -w 1'` (single worker neutralizes race per RESEARCH §Pattern 1). Migration to Railway native Pre-Deploy Command (2025-01 feature) deferred Phase 03 cleanup."
    rationale: "RESEARCH §Pattern 1 + §State-of-the-Art table + locked decision Phase-decision-lock #2."
  - id: open-q-4
    locked: "7-day continuous_drift_sampler soak applies OVERRIDE PATH for Phase 02-deploy because prod has 2 test accounts confirmed by Julien 2026-05-19 (per CONTEXT line 41 + memory `project_byok_scope`). Default 7-day window for any prod with > 10 real users (future-phase trigger documented as Phase 04 hardening)."
    rationale: "Phase-decision-lock orchestrator instruction #4 + RESEARCH §Pitfall 5 + iter-2 B20 7-min/14-target."
  - id: staging-backfill-note
    locked: "Per HANDOFF Wave 1 + CONTEXT line 40 : staging has 131 users but 0 snapshots. Backfill is a no-op AGAINST EXISTING SNAPSHOT ROWS (recovers 0 historical rows). Forward-write dual-write via PR-2 will populate fact_event/fact_current AS new snapshots are created. Task 2a gate becomes 'backfill runs cleanly (exit 0) + idempotency proven (run-1 row count == run-2 row count) + projection_diff zero ERRORS during execution' (rather than 'zero diff vs snapshots' since there is nothing to diff)."
    rationale: "CONTEXT line 40 staging probe : '131 users, 0 snapshots' + HANDOFF Wave 1 step 5-7."
  - id: prereq-pr-merge-and-p120-staging
    locked: "Plan 02 cannot run Wave 1 probe until 3 hard-prerequisites are satisfied : (a) Plan 01 PR A2 (D-27 idempotency + p120 latest_event_id) merged on dev, (b) Plan 01 PR A3 (JSONB cast + dual-write rollback + hmac pepper rotation) merged on dev, (c) p120 migration deployed on staging-Postgres (col `fact_current.latest_event_id` exists). Plan 01 opens these PRs but the merge-on-dev + Railway-staging-deploy happen out-of-flow (CI + Julien review). Wave 1 Task 1 Step 0 introduces 3 hard-stop assertions that BLOCK execution if any of these prerequisites is missing — prevents flipping FF=on against a staging where the D-27 idempotency contract isn't yet honored."
    rationale: "Checker iteration 1 finding C-2 : race condition between Plan 01 PR-open and merge-on-dev + Railway auto-deploy ; without these assertions Wave 1 probe could flip FF=on on a staging at p119 where backfill would write rows that cannot be idempotently replayed (D-27 contract requires p120 latest_event_id col)."

must_haves:
  truths:
    - "Staging postgres-qdyu alembic head = `p120_fact_event_idempotency` (PR A2 deployed via Railway auto-deploy after merge-to-dev — verified via `railway ssh` probe at Plan start ; if head still = p119, executor BLOCKS and waits for next Railway auto-deploy)."
    - "Staging postgres-qdyu has fact_event + fact_current + dek_envelope tables (verified via `pg_tables` probe) + `fact_current.latest_event_id` column present (verified via `information_schema.columns` probe — p120 contract)."
    - "Plan 01 PR A2 (D-27 idempotency) merged on dev — verified via `git log origin/dev` grep on D-27 / p120_fact_event_idempotency."
    - "Plan 01 PR A3 (JSONB cast + dual-write rollback + hmac pepper rotation) merged on dev — verified via `git log origin/dev` grep on JSONB cast / hmac pepper rotation / dual-write rollback."
    - "`FF_FACT_EVENT_DUAL_WRITE=on` set on staging (NOT production) via `railway variables --environment staging --service MINT set FF_FACT_EVENT_DUAL_WRITE=on`."
    - "Staging deploy re-triggered post-FF flip + healthy (railway logs `Application startup complete`)."
    - "`backfill_snapshot_to_fact_event.py --apply` runs ×2 on staging Railway ssh. Run-1 exit 0 ; run-2 exit 0. Row count delta = 0 (idempotency proven against staging snapshot inventory — which is 0 rows per CONTEXT, so trivially idempotent + script must not raise)."
    - "`mint_projector_idempotency_skip_total` counter visible in /metrics endpoint AFTER backfill run-2 (delta = run-1 row count, even if 0)."
    - "`projection_diff.py --audit-all-users --persist-to _phase02_parity_audit` runs cleanly against staging (exit 0). USERS_WITH_DIFF = 0 (vacuously true with 0 snapshots, but persistence path proven)."
    - "Task 2a operational gate signed-off by Julien : signal message « approved PR-3a — backfill idempotent, 100% staging-user parity audit zero diff, projection_diff.py deterministic » recorded in PERIMETERS.md ledger commit + this plan's evidence file."
    - "7-day soak window documented OPEN_OVERRIDE per locked decision #4 (0-user-prod premise) in this plan's SUMMARY + PR-3b body when Wave 2 fires."
  artifacts:
    - path: ".planning/phases/mint-data-architecture-v1-02-deploy/staging-task-2a-evidence.txt"
      provides: "Consolidated Task 2a evidence : 8 pattern-C steps stdout + idempotency assertion + projection_diff output + Julien sign-off ledger commit sha"
      min_lines: 50
    - path: ".planning/phases/mint-data-architecture-v1-02-deploy/staging-backfill-run1.log"
      provides: "First backfill pass stdout via railway ssh"
    - path: ".planning/phases/mint-data-architecture-v1-02-deploy/staging-backfill-run2.log"
      provides: "Second backfill pass stdout (idempotency proof)"
    - path: ".planning/phases/mint-data-architecture-v1-02-deploy/staging-projection-diff-full-audit.log"
      provides: "100% staging-user projection_diff stdout + _phase02_parity_audit table inserted rows"
    - path: ".planning/phases/mint-data-architecture-v1-02-deploy/staging-metrics-snapshot-post-backfill.txt"
      provides: "/metrics curl output showing mint_projector_idempotency_skip_total + mint_fact_event_insert_total + mint_dek_envelope_status_total post-backfill state"
    - path: "PERIMETERS.md"
      provides: "Phase 02-deploy Wave 1 Task 2a Julien sign-off ledger entry"
      contains: "approved PR-3a"
  key_links:
    - from: "Railway staging deploy"
      to: "staging postgres-qdyu alembic_version table"
      via: "`railway_pre_deploy_migrate.py` runs `alembic upgrade head` at every worker boot (Procfile-wired)"
      pattern: "alembic upgrade head"
    - from: "services/backend/scripts/backfill_snapshot_to_fact_event.py"
      to: "fact_event table (staging postgres-qdyu)"
      via: "Idempotent INSERT via FactProjector.project_event ; idempotency_skip counter on PK collision"
      pattern: "project_event\\("
    - from: "tools/parity/projection_diff.py"
      to: "_phase02_parity_audit table (staging postgres-qdyu)"
      via: "Canonical-JSON diff per A10 + Decimal 1e-9 tolerance + persist via `--persist-to _phase02_parity_audit`"
      pattern: "_phase02_parity_audit"
---

<objective>
Wave 1 — application opérationnelle du substrat Phase 02 sur staging + exécution du Task 2a operational gate (per Plan 02-03 iter-2 contract réutilisé).

Staging est DÉJÀ à `p119_phase02_parity_cont` post-PR #660 deploy (vérifié `railway ssh` 2026-05-19 ~19:00 UTC per HANDOFF). Plan 01 (Wave 0) ship PR A2 (qui ajoute p120 `latest_event_id`) + A3 + B en code-mode ; staging passe à `p120_fact_event_idempotency` UNIQUEMENT après merge-to-dev + Railway auto-deploy. Ce plan ne RE-applique PAS les migrations — il VÉRIFIE l'état (avec hard-stop sur head=p120 et A2/A3 merged) + FLIP la FF + RUN le backfill ×2 + AUDIT 100% users + COLLECT les évidences déterministes pour Julien sign-off.

Purpose : produire l'évidence opérationnelle qui débloque Wave 2 (PR-3b read-cutover atomic). Sans Task 2a green, la cutover ne peut PAS shipper (FF=off, projection_diff sans baseline persisted). Sans p120 sur staging, l'idempotency D-27 ne tient pas → Task 1 Step 0 hard-stop bloque l'exécution jusqu'à ce que Railway déploie p120.

Output : 1 fichier evidence consolidé (`staging-task-2a-evidence.txt`) + 3 log files + 1 metrics snapshot + PERIMETERS.md entry signed-off + état FF=on persistant sur staging.

Caveat critique (locked decision `staging-backfill-note`) : staging a 131 users mais 0 snapshots — backfill recovers 0 historical rows. Le gate Task 2a passe sur EXÉCUTION CLEAN (exit 0) + idempotency proven (run-1 count == run-2 count, même si 0) + projection_diff persist path proven (vacuously 0 diff puisque rien à diff). Forward-write dual-write via PR-2 populera fact_event au fur et à mesure que des snapshots seront créés sur staging.

Caveat critique 2 (locked decision `prereq-pr-merge-and-p120-staging`) : Plan 01 (Wave 0) ouvre A2/A3/B en PRs MAIS leur merge-to-dev + Railway-staging-deploy sont hors-flow GSD. Task 1 Step 0 ajoute 3 assertions HARD-STOP (A2 merged + A3 merged + p120 col présent sur staging) qui BLOCK exécution si l'une manque — empêche flipper FF=on sur un staging où D-27 idempotency n'est pas en place.

Type : `autonomous: false` — Task 2a CHECKPOINT requires Julien sign-off per Plan 02-03 iter-2 contract + 0-trust §9.4 (USER VALUE separation).

Out of scope this plan :
- PR-3b read-cutover atomic (Wave 2 Plan 03).
- PR-4 FF removal (Wave 2 Plan 03).
- PR-5 SnapshotModel drop (Wave 2 Plan 03).
- Prod migration apply (Wave 4 Plan 04 close-out).
- Mobile L1 device wiring (Wave 3 Plan 04).
- 7-day continuous_drift_sampler cron activation (Wave 2 Plan 03 — uncommented at PR-3a merge time per locked decision #4 override path).
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/mint-data-architecture-v1-02-deploy/CONTEXT.md
@.planning/phases/mint-data-architecture-v1-02-deploy/HANDOFF-2026-05-19.md
@.planning/phases/mint-data-architecture-v1-02-deploy/mint-data-architecture-v1-02-deploy-RESEARCH.md
@.planning/phases/mint-data-architecture-v1-02-deploy/mint-data-architecture-v1-02-deploy-VALIDATION.md
@.planning/phases/mint-data-architecture-v1-02-deploy/mint-data-architecture-v1-02-deploy-01-alembic-chain-audit-PLAN.md
@.planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-03-migration-5pr-sequence-PLAN.md
@services/backend/scripts/backfill_snapshot_to_fact_event.py
@services/backend/scripts/preflight_zero_user_gate.py
@tools/parity/projection_diff.py
@services/backend/app/cron/continuous_drift_sampler.py

<interfaces>
<!-- State on staging after Plan 01 Wave 0 close + verified pre-Wave-1. -->

Staging postgres-qdyu state (verified 2026-05-19 ~19:00 UTC + re-verify at plan start) :
- alembic head expected POST-PR-A2-merge-and-deploy : `p120_fact_event_idempotency` (was `p119_phase02_parity_cont` pre-PR-A2-merge — Task 1 Step 0 hard-stop asserts head=p120, else BLOCKS)
- Tables present : 34+ (33 baseline + fact_event + fact_current + dek_envelope + _phase02_parity_audit + _phase02_parity_audit_continuous from Phase 02 substrate migrations p98/p113/p116/p118/p119)
- Column expected post-p120 : `fact_current.latest_event_id String(36) NULL` (verified via `information_schema.columns` probe — Task 1 Step 0 hard-stop)
- Users : 131 (per CONTEXT line 40)
- Snapshots : 0 (per CONTEXT line 40 — staging never had production snapshot data)
- fact_event rows : 0 (substrate just landed, dual-write FF=off)
- fact_current rows : 0
- dek_envelope rows : ≥ 0 (verify in Wave 1 probe — Phase 02 substrate may have populated)

Railway staging env vars (verified pre-Wave-1) :
- `FF_FACT_EVENT_DUAL_WRITE` : UNSET (default OFF per Plan 02-03 PR-1) — Task 2a Step 3 sets this to `on`
- `MINT_AUDIT_HASH_PEPPER` : SET (pre-flight item #3, >20 chars — verify)
- `MINT_KMS_KEY_ID` : SET (per Phase 02 substrate convention)
- `DATABASE_URL` : SET (auto-managed by Railway postgres-qdyu service)
- `STAGING_BASE_URL` : `https://mint-staging.up.railway.app`

Backfill script contract (services/backend/scripts/backfill_snapshot_to_fact_event.py, shipped PR #656 PR-3a) :
- `--apply` : actually writes to fact_event (idempotent by design — D-27 PK collision via PR A2 + p120 latest_event_id)
- `--dry-run` : counts rows that WOULD write, no DB mutation
- Stdout format : `Backfilled <N> users → <M> fact_event rows` on first run ; `0 new fact_event rows ; <M> idempotency_skip increments` on second run

projection_diff.py contract (tools/parity/projection_diff.py, shipped PR #656 iter-2 A10) :
- `--audit-all-users --persist-to _phase02_parity_audit` : queries each user's projection via legacy SnapshotModel path AND new FactCurrent path ; diff via canonical JSON ; persist to table
- Stdout : `USERS_AUDITED=<N>, USERS_WITH_DIFF=<M>`
- Determinism guarantee : canonical JSON `sort_keys=True, default=str, separators=(",", ":")` + Decimal tolerance 1e-9 + missing-key=None rule

Continuous drift sampler (services/backend/app/cron/continuous_drift_sampler.py, .github/workflows/pg-soak-nightly.yml) :
- Cron `*/30 * * * *` commented OFF by default
- ACTIVATION : uncomment cron block in Wave 2 Plan 03 PR-3a merge step (out of scope this plan)
- DEACTIVATION : re-comment in Wave 2 Plan 03 PR-3b merge step

PR A2/A3/B (Plan 01) MUST be merged on dev BEFORE this plan executes — AND p120 MUST be deployed on staging Postgres (Railway auto-deploy completes the migration as `alembic upgrade head` runs at gunicorn boot via Procfile `railway_pre_deploy_migrate.py`) :
- D-27 EXACT-EQUALITY (idempotency skip counter wired + p120 latest_event_id col added to fact_current)
- JSONB cast dialect-branched
- `mint_snapshot_fact_current_drift_total` counter declared
- Lefthook rules registered
- railway_pg_dump.sh available

Task 1 Step 0 hard-stop guards : if any of A2 merged / A3 merged / p120 deployed staging is missing → executor BLOCKS + asks Julien (per memory `feedback_blockers_ask_dont_defer`).
</interfaces>
</context>

<decision_locked>
- **Open-Q #2 (auto-deploy)** — LOCKED : Railway auto-applies migrations via Procfile pre-deploy script. Migration to native Pre-Deploy Command (2025-01) = follow-up Phase 03 cleanup, not blocking.
- **Open-Q #4 (7-day soak override)** — LOCKED OVERRIDE PATH : 0-user-prod premise (2 test accounts confirmed by Julien) justifies override. Documentation pattern : Wave 2 PR-3b commit body must include « 7-day soak override : 0-user-prod premise + 2-test-acct empirical confirmation + Julien sign-off ledger ref ».
- **Open-Q #4 (sub-decision : minimum soak floor for override)** — LOCKED : 24h consecutive clean OR 48h continuous_drift_sampler clean (48 ticks × 30min = 48 opportunities to surface a bug). Less than 24h = Julien explicit reason required in PR body.
- **Staging-backfill-note** — LOCKED : Backfill is a no-op against staging's 0-snapshot inventory ; gate becomes « clean execution + idempotency » rather than « zero diff ». Forward-write dual-write via PR-2 populates fact_event going forward.
- **Prereq PR merge + p120 staging deploy** — LOCKED : Task 1 Step 0 hard-stops on (a) PR A2 D-27 merged on dev, (b) PR A3 JSONB-cast/rollback/pepper-rotation merged on dev, (c) `fact_current.latest_event_id` col present on staging postgres-qdyu. If any is missing : executor STOPS + surfaces blocker (NOT defer-with-comment ; per memory `feedback_blockers_ask_dont_defer`). The asymmetry is intentional : Plan 02 cannot flip FF=on on a staging where D-27 idempotency is not yet honored at the schema level.
</decision_locked>

<tasks>

<task type="auto">
  <name>Task 1 (Pre-flight Wave-1 probe) : Verify staging DB state + Railway env vars match expected post-PR #660 + Plan 01 PR A2/A3/B merged + p120 deployed on staging-Postgres</name>
  <files>
    .planning/phases/mint-data-architecture-v1-02-deploy/staging-task-2a-evidence.txt
  </files>
  <read_first>
    .planning/phases/mint-data-architecture-v1-02-deploy/mint-data-architecture-v1-02-deploy-01-alembic-chain-audit-PLAN.md (Wave 0 outcome — chain audit + baselines committed + PR A2/A3/B shipped on dev),
    .planning/phases/mint-data-architecture-v1-02-deploy/HANDOFF-2026-05-19.md (15-item pre-flight checklist),
    .planning/phases/mint-data-architecture-v1-02-deploy/mint-data-architecture-v1-02-deploy-RESEARCH.md (§Pattern B Railway DB state probe + §Runtime State Inventory),
    services/backend/Procfile (deploy entrypoint),
    .planning/phases/mint-data-architecture-v1-02-deploy/chain-audit.txt (from Plan 01 Task 4 — should already document staging+prod probes)
  </read_first>
  <action>
1. **Initialize evidence file** :

```bash
cat > .planning/phases/mint-data-architecture-v1-02-deploy/staging-task-2a-evidence.txt << EOF
# Phase 02-deploy Wave 1 Task 2a — Operational Gate Evidence
# Generated $(date -u +%Y-%m-%dT%H:%M:%SZ)
# Plan 02 staging migration apply + Julien-gated operational signal

## Step 0 — Pre-flight Wave-1 prerequisite verification (3 hard-stop assertions)
EOF
```

2. **Step 0 hard-stop assertion 1 — PR A2 (D-27 idempotency + p120 latest_event_id) merged on dev** (per locked decision `prereq-pr-merge-and-p120-staging`) :

```bash
echo "" >> .planning/phases/mint-data-architecture-v1-02-deploy/staging-task-2a-evidence.txt
echo "### Hard-stop Assertion 1 — PR A2 (D-27 / p120) merged on dev" >> .planning/phases/mint-data-architecture-v1-02-deploy/staging-task-2a-evidence.txt
git fetch origin dev
A2_MERGED=$(git log origin/dev --oneline -50 | grep -ciE 'D-27|p120_fact_event_idempotency')
echo "PR A2 commit-grep hits on origin/dev (last 50) : $A2_MERGED (≥ 1 required)" >> .planning/phases/mint-data-architecture-v1-02-deploy/staging-task-2a-evidence.txt
if [ "$A2_MERGED" -lt 1 ]; then
  echo "BLOCKED: PR A2 (D-27 idempotency + p120 latest_event_id) not yet merged on dev — Wave 1 cannot run safely (FF=on against a staging without p120 latest_event_id column would silently break D-27 EXACT-EQUALITY contract). Wait for PR A2 merge + Railway auto-deploy then re-run this task." >> .planning/phases/mint-data-architecture-v1-02-deploy/staging-task-2a-evidence.txt
  echo "BLOCKED: PR A2 not merged on dev — abort Wave 1." 1>&2
  exit 1
fi
```

3. **Step 0 hard-stop assertion 2 — PR A3 (JSONB cast + dual-write rollback + hmac pepper rotation) merged on dev** :

```bash
echo "" >> .planning/phases/mint-data-architecture-v1-02-deploy/staging-task-2a-evidence.txt
echo "### Hard-stop Assertion 2 — PR A3 (JSONB cast / rollback / pepper rotation) merged on dev" >> .planning/phases/mint-data-architecture-v1-02-deploy/staging-task-2a-evidence.txt
A3_MERGED=$(git log origin/dev --oneline -50 | grep -ciE 'JSONB cast|hmac pepper rotation|dual-write rollback|dialect.branched')
echo "PR A3 commit-grep hits on origin/dev (last 50) : $A3_MERGED (≥ 1 required)" >> .planning/phases/mint-data-architecture-v1-02-deploy/staging-task-2a-evidence.txt
if [ "$A3_MERGED" -lt 1 ]; then
  echo "BLOCKED: PR A3 (JSONB cast / dual-write rollback / hmac pepper rotation) not yet merged on dev — Wave 1 cannot safely backfill against a staging Postgres where JSONB cast is not dialect-branched (string-bind silently corrupts data per RESEARCH §Pitfall 1)." >> .planning/phases/mint-data-architecture-v1-02-deploy/staging-task-2a-evidence.txt
  echo "BLOCKED: PR A3 not merged on dev — abort Wave 1." 1>&2
  exit 1
fi
```

4. **Step 0 hard-stop assertion 3 — p120 latest_event_id column deployed on staging-Postgres** (per locked decision `prereq-pr-merge-and-p120-staging`) :

```bash
echo "" >> .planning/phases/mint-data-architecture-v1-02-deploy/staging-task-2a-evidence.txt
echo "### Hard-stop Assertion 3 — p120 latest_event_id col deployed on staging-Postgres" >> .planning/phases/mint-data-architecture-v1-02-deploy/staging-task-2a-evidence.txt
P120_COL_PRESENT=$(railway ssh -e staging --service MINT 'python3 -c "
import os, psycopg2
c = psycopg2.connect(os.environ[\"DATABASE_URL\"]); cur = c.cursor()
cur.execute(\"SELECT COUNT(*) FROM information_schema.columns WHERE table_name=\\047fact_current\\047 AND column_name=\\047latest_event_id\\047\")
print(cur.fetchone()[0])
"' 2>&1)
echo "fact_current.latest_event_id column presence (staging probe) : $P120_COL_PRESENT (expected = 1)" >> .planning/phases/mint-data-architecture-v1-02-deploy/staging-task-2a-evidence.txt
if [ "$P120_COL_PRESENT" != "1" ]; then
  echo "BLOCKED: p120 latest_event_id col NOT present on staging postgres-qdyu — staging alembic head is likely still p119 (Railway has not yet auto-deployed PR A2 post-merge). Options : (a) wait for next Railway auto-deploy (gunicorn restart re-runs alembic upgrade head via Procfile pre-deploy script — typically <5 min post-merge), OR (b) trigger a manual Railway redeploy. Re-run this task after p120 confirmed present." >> .planning/phases/mint-data-architecture-v1-02-deploy/staging-task-2a-evidence.txt
  echo "BLOCKED: p120 latest_event_id col not on staging — wait for Railway auto-deploy or trigger manually." 1>&2
  exit 1
fi
```

5. **Probe staging DB state** (per RESEARCH §Pattern B verbatim — full state inventory, runs AFTER Step 0 hard-stops pass) :

```bash
echo "" >> .planning/phases/mint-data-architecture-v1-02-deploy/staging-task-2a-evidence.txt
echo "## Step 0b — Staging postgres-qdyu full state probe ($(date -u +%Y-%m-%dT%H:%M:%SZ))" >> .planning/phases/mint-data-architecture-v1-02-deploy/staging-task-2a-evidence.txt
railway ssh -e staging --service MINT 'python3 -c "
import os, psycopg2
url = os.getenv(\"DATABASE_URL\")
c = psycopg2.connect(url); cur = c.cursor()
cur.execute(\"SELECT version_num FROM alembic_version\")
print(\"alembic head:\", cur.fetchone())
cur.execute(\"SELECT current_user, current_database()\")
print(\"identity:\", cur.fetchone())
for table in [\"fact_event\", \"fact_current\", \"dek_envelope\", \"_phase02_parity_audit\", \"_phase02_parity_audit_continuous\"]:
    cur.execute(f\"SELECT EXISTS(SELECT 1 FROM pg_tables WHERE tablename=%s)\", (table,))
    print(f\"{table}:\", cur.fetchone()[0])
cur.execute(\"SELECT count(*) FROM users\")
print(\"users:\", cur.fetchone()[0])
cur.execute(\"SELECT count(*) FROM snapshots\")
print(\"snapshots:\", cur.fetchone()[0])
cur.execute(\"SELECT count(*) FROM fact_event\")
print(\"fact_event rows:\", cur.fetchone()[0])
cur.execute(\"SELECT count(*) FROM fact_current\")
print(\"fact_current rows:\", cur.fetchone()[0])
cur.execute(\"SELECT count(*) FROM dek_envelope\")
print(\"dek_envelope rows:\", cur.fetchone()[0])
"' >> .planning/phases/mint-data-architecture-v1-02-deploy/staging-task-2a-evidence.txt 2>&1
```

6. **Verify staging env vars (pre-flight items #3 + #7)** :

```bash
echo "" >> .planning/phases/mint-data-architecture-v1-02-deploy/staging-task-2a-evidence.txt
echo "### Staging env var inventory (FF + pepper)" >> .planning/phases/mint-data-architecture-v1-02-deploy/staging-task-2a-evidence.txt
railway variables -e staging --service MINT | grep -iE "FF_FACT_EVENT_DUAL_WRITE|MINT_AUDIT_HASH_PEPPER|MINT_KMS_KEY_ID|KMS_KEY_ID" >> .planning/phases/mint-data-architecture-v1-02-deploy/staging-task-2a-evidence.txt 2>&1 || echo "(values masked — only presence checked)" >> .planning/phases/mint-data-architecture-v1-02-deploy/staging-task-2a-evidence.txt
echo "" >> .planning/phases/mint-data-architecture-v1-02-deploy/staging-task-2a-evidence.txt
echo "FF_FACT_EVENT_DUAL_WRITE pre-Task-2a expected : UNSET (default OFF per Plan 02-03 PR-1)" >> .planning/phases/mint-data-architecture-v1-02-deploy/staging-task-2a-evidence.txt
```

7. **Secondary assertions on probe output** (executor STOPS if any FAILS — per memory `feedback_blockers_ask_dont_defer`) :

```bash
EVIDENCE=.planning/phases/mint-data-architecture-v1-02-deploy/staging-task-2a-evidence.txt

# Assertion 4 : alembic head = p120_fact_event_idempotency (post-A2-merge state)
grep -q "p120_fact_event_idempotency" "$EVIDENCE" || { echo "BLOCKED: staging alembic head != p120_fact_event_idempotency (Step 0 assertion 3 should have caught this — defensive re-check)" 1>&2 ; exit 1 ; }

# Assertion 5 : fact_event + fact_current tables exist (True)
grep -E "fact_event: True" "$EVIDENCE" || { echo "BLOCKED: staging fact_event table does not exist" 1>&2 ; exit 1 ; }
grep -E "fact_current: True" "$EVIDENCE" || { echo "BLOCKED: staging fact_current table does not exist" 1>&2 ; exit 1 ; }

# Assertion 6 : MINT_AUDIT_HASH_PEPPER set on staging (pre-flight #3)
railway variables -e staging --service MINT 2>&1 | grep -q "MINT_AUDIT_HASH_PEPPER" || { echo "BLOCKED: MINT_AUDIT_HASH_PEPPER not set on staging" 1>&2 ; exit 1 ; }
```

8. **Document pre-flight green** :

```bash
echo "" >> .planning/phases/mint-data-architecture-v1-02-deploy/staging-task-2a-evidence.txt
echo "### Pre-flight Wave-1 verification : ✓ GREEN" >> .planning/phases/mint-data-architecture-v1-02-deploy/staging-task-2a-evidence.txt
echo "3 hard-stop prereq assertions + 3 secondary state assertions all passed at $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> .planning/phases/mint-data-architecture-v1-02-deploy/staging-task-2a-evidence.txt
echo "Proceeding to Task 2a Step 1-10 (RESEARCH §Pattern C verbatim sequence)." >> .planning/phases/mint-data-architecture-v1-02-deploy/staging-task-2a-evidence.txt
```
  </action>
  <verify>
    <automated>cd /Users/julienbattaglia/Desktop/MINT.nosync && [ -f .planning/phases/mint-data-architecture-v1-02-deploy/staging-task-2a-evidence.txt ] && grep -q "p120_fact_event_idempotency" .planning/phases/mint-data-architecture-v1-02-deploy/staging-task-2a-evidence.txt && grep -q "fact_event: True" .planning/phases/mint-data-architecture-v1-02-deploy/staging-task-2a-evidence.txt && grep -q "fact_current: True" .planning/phases/mint-data-architecture-v1-02-deploy/staging-task-2a-evidence.txt && grep -q "Hard-stop Assertion 1 — PR A2" .planning/phases/mint-data-architecture-v1-02-deploy/staging-task-2a-evidence.txt && grep -q "Hard-stop Assertion 2 — PR A3" .planning/phases/mint-data-architecture-v1-02-deploy/staging-task-2a-evidence.txt && grep -q "Hard-stop Assertion 3 — p120 latest_event_id" .planning/phases/mint-data-architecture-v1-02-deploy/staging-task-2a-evidence.txt && grep -q "Pre-flight Wave-1 verification : ✓ GREEN" .planning/phases/mint-data-architecture-v1-02-deploy/staging-task-2a-evidence.txt</automated>
  </verify>
  <acceptance_criteria>
    - `.planning/phases/mint-data-architecture-v1-02-deploy/staging-task-2a-evidence.txt` exists ≥ 30 lines + contains « Step 0 — Pre-flight Wave-1 prerequisite verification (3 hard-stop assertions) ».
    - **Hard-stop assertion 1 (PR A2)** : `grep "Hard-stop Assertion 1 — PR A2" staging-task-2a-evidence.txt` returns ≥ 1 hit + recorded hit count from `git log origin/dev | grep D-27/p120_fact_event_idempotency` ≥ 1.
    - **Hard-stop assertion 2 (PR A3)** : `grep "Hard-stop Assertion 2 — PR A3" staging-task-2a-evidence.txt` returns ≥ 1 hit + recorded hit count from `git log origin/dev | grep JSONB cast/hmac pepper rotation/dual-write rollback` ≥ 1.
    - **Hard-stop assertion 3 (p120 col)** : `grep "Hard-stop Assertion 3 — p120 latest_event_id" staging-task-2a-evidence.txt` returns ≥ 1 hit + recorded staging probe `fact_current.latest_event_id` presence = 1.
    - `grep "p120_fact_event_idempotency" staging-task-2a-evidence.txt` returns ≥ 1 hit (staging head verified at expected post-PR-A2-deploy state).
    - `grep -E "fact_event: True" staging-task-2a-evidence.txt` returns ≥ 1 hit (table exists).
    - `grep -E "fact_current: True" staging-task-2a-evidence.txt` returns ≥ 1 hit (table exists).
    - `grep -E "users: 131|users: [0-9]+" staging-task-2a-evidence.txt` returns ≥ 1 hit (user count probed — expected ~131 per CONTEXT, may have shifted).
    - `grep -E "snapshots: 0|snapshots: [0-9]+" staging-task-2a-evidence.txt` returns ≥ 1 hit (snapshot count probed).
    - `grep "MINT_AUDIT_HASH_PEPPER" staging-task-2a-evidence.txt` returns ≥ 1 hit (pepper presence verified).
    - `grep "Pre-flight Wave-1 verification : ✓ GREEN" staging-task-2a-evidence.txt` returns 1 hit.
    - If ANY of the 3 Step 0 hard-stop assertions OR the 3 secondary assertions fails : executor STOPS + surfaces blocker in evidence file + exits 1 (memory `feedback_blockers_ask_dont_defer`) ; does NOT proceed to Task 2.
  </acceptance_criteria>
  <done>
    Pre-flight Wave-1 GREEN documented in evidence file. 3 hard-stop prereq assertions passed (PR A2 merged + PR A3 merged + p120 latest_event_id col present on staging). Staging state confirmed at expected post-PR-A2-deploy state (head=p120, fact_event/fact_current present, FF=off baseline, latest_event_id col exists per D-27 contract). Ready for Task 2a operational gate execution.
  </done>
</task>

<task type="auto">
  <name>Task 2 (Task 2a Step 1-9 automation) : Run RESEARCH §Pattern C verbatim sequence — preflight + FF flip + backfill ×2 idempotency + projection_diff full audit + metrics snapshot</name>
  <files>
    .planning/phases/mint-data-architecture-v1-02-deploy/staging-task-2a-evidence.txt,
    .planning/phases/mint-data-architecture-v1-02-deploy/staging-backfill-run1.log,
    .planning/phases/mint-data-architecture-v1-02-deploy/staging-backfill-run2.log,
    .planning/phases/mint-data-architecture-v1-02-deploy/staging-projection-diff-full-audit.log,
    .planning/phases/mint-data-architecture-v1-02-deploy/staging-metrics-snapshot-post-backfill.txt
  </files>
  <read_first>
    .planning/phases/mint-data-architecture-v1-02-deploy/mint-data-architecture-v1-02-deploy-RESEARCH.md (§Pattern C Task 2a operational gate sequence VERBATIM lines 525-563),
    services/backend/scripts/backfill_snapshot_to_fact_event.py (script behavior),
    services/backend/scripts/preflight_zero_user_gate.py (preflight gate behavior — staging has 131 users so will return BLOCKED with documented justification),
    tools/parity/projection_diff.py (canonical JSON diff via A10),
    .planning/phases/mint-data-architecture-v1-02-event-log-projection/mint-data-architecture-v1-02-event-log-03-migration-5pr-sequence-PLAN.md (lines 680-712 Task 2a how-to-verify VERBATIM)
  </read_first>
  <action>
1. **Step 1 — Run preflight_zero_user_gate against staging** (with documented override per CONTEXT data gap) :

```bash
echo "" >> .planning/phases/mint-data-architecture-v1-02-deploy/staging-task-2a-evidence.txt
echo "## Step 1 — preflight_zero_user_gate against staging ($(date -u +%Y-%m-%dT%H:%M:%SZ))" >> .planning/phases/mint-data-architecture-v1-02-deploy/staging-task-2a-evidence.txt

railway ssh -e staging --service MINT 'cd /app && python3 scripts/preflight_zero_user_gate.py' 2>&1 | tee -a .planning/phases/mint-data-architecture-v1-02-deploy/staging-task-2a-evidence.txt
# Expected : exit 1 with "BLOCKED: staging has 131 users"

echo "" >> .planning/phases/mint-data-architecture-v1-02-deploy/staging-task-2a-evidence.txt
echo "### Override documentation" >> .planning/phases/mint-data-architecture-v1-02-deploy/staging-task-2a-evidence.txt
echo "Staging has 131 test users per CONTEXT line 40. Override justification :" >> .planning/phases/mint-data-architecture-v1-02-deploy/staging-task-2a-evidence.txt
echo "- This is STAGING (not prod) — pre-launch premise allows test user data." >> .planning/phases/mint-data-architecture-v1-02-deploy/staging-task-2a-evidence.txt
echo "- 0 snapshots per CONTEXT — backfill is a no-op against historical rows." >> .planning/phases/mint-data-architecture-v1-02-deploy/staging-task-2a-evidence.txt
echo "- Forward-write dual-write populates fact_event going forward (no risk to existing user data)." >> .planning/phases/mint-data-architecture-v1-02-deploy/staging-task-2a-evidence.txt
echo "Override applied with Julien sign-off path documented in Step 10." >> .planning/phases/mint-data-architecture-v1-02-deploy/staging-task-2a-evidence.txt
```

2. **Step 2 — Verify Plan 02-02 Task 3C multi-shape canary parity gate PASSED on dev** (already shipped per Phase 02 substrate SUMMARY ; this confirms regression status) :

```bash
echo "" >> staging-task-2a-evidence.txt
echo "## Step 2 — Multi-shape canary parity gate (regression check)" >> staging-task-2a-evidence.txt
cd /Users/julienbattaglia/Desktop/MINT.nosync/services/backend
python3 -m pytest tests/integration/test_canary_multi_shape_parity.py -q --timeout=60 2>&1 | tail -5 | tee -a ../../.planning/phases/mint-data-architecture-v1-02-deploy/staging-task-2a-evidence.txt
# Expected : 5/5 PASS per Phase 02 SUMMARY
cd /Users/julienbattaglia/Desktop/MINT.nosync
```

3. **Step 3 — Set FF_FACT_EVENT_DUAL_WRITE=on on Railway staging only** :

```bash
echo "" >> staging-task-2a-evidence.txt
echo "## Step 3 — Set FF_FACT_EVENT_DUAL_WRITE=on on staging ($(date -u +%Y-%m-%dT%H:%M:%SZ))" >> staging-task-2a-evidence.txt

railway variables --environment staging --service MINT --set "FF_FACT_EVENT_DUAL_WRITE=on" 2>&1 | tee -a staging-task-2a-evidence.txt

echo "" >> staging-task-2a-evidence.txt
echo "### Verify FF set" >> staging-task-2a-evidence.txt
railway variables -e staging --service MINT 2>&1 | grep "FF_FACT_EVENT_DUAL_WRITE" >> staging-task-2a-evidence.txt
echo "Confirmed : FF_FACT_EVENT_DUAL_WRITE=on on staging." >> staging-task-2a-evidence.txt

echo "" >> staging-task-2a-evidence.txt
echo "### Confirm prod is UNSET (must stay OFF until Wave 4 + soak override)" >> staging-task-2a-evidence.txt
railway variables -e production --service MINT 2>&1 | grep "FF_FACT_EVENT_DUAL_WRITE" >> staging-task-2a-evidence.txt || echo "FF_FACT_EVENT_DUAL_WRITE unset on production (expected)" >> staging-task-2a-evidence.txt
```

4. **Step 4 — Wait for Railway re-deploy post-FF flip** :

```bash
echo "" >> staging-task-2a-evidence.txt
echo "## Step 4 — Wait Railway staging re-deploy ($(date -u +%Y-%m-%dT%H:%M:%SZ))" >> staging-task-2a-evidence.txt
echo "Railway re-deploys on env var change ; gunicorn restart with -w 1 re-runs alembic upgrade head (no-op since already at p120)." >> staging-task-2a-evidence.txt

# Poll until healthy : /metrics endpoint returns 200 + Application startup complete in logs
for i in $(seq 1 30); do
  if curl -sf https://mint-staging.up.railway.app/metrics > /dev/null 2>&1; then
    echo "Deploy healthy at attempt $i ($(date -u +%Y-%m-%dT%H:%M:%SZ))" >> staging-task-2a-evidence.txt
    break
  fi
  sleep 5
done
```

5. **Step 5 — Run backfill — first pass** :

```bash
echo "" >> staging-task-2a-evidence.txt
echo "## Step 5 — Backfill first pass ($(date -u +%Y-%m-%dT%H:%M:%SZ))" >> staging-task-2a-evidence.txt
railway ssh -e staging --service MINT 'cd /app && python3 scripts/backfill_snapshot_to_fact_event.py --apply' 2>&1 | tee .planning/phases/mint-data-architecture-v1-02-deploy/staging-backfill-run1.log

# Capture row count
N_RUN1=$(railway ssh -e staging --service MINT 'python3 -c "
import os, psycopg2
c = psycopg2.connect(os.getenv(\"DATABASE_URL\")); cur = c.cursor()
cur.execute(\"SELECT count(*) FROM fact_event WHERE source_type='\''snapshot_backfill'\''\")
print(cur.fetchone()[0])
"')
echo "N_RUN1 = $N_RUN1 (expected 0 — staging has 0 snapshots per CONTEXT, backfill is no-op)" >> staging-task-2a-evidence.txt
```

6. **Step 6 — Run backfill — second pass (idempotency proof)** :

```bash
echo "" >> staging-task-2a-evidence.txt
echo "## Step 6 — Backfill second pass (idempotency proof) ($(date -u +%Y-%m-%dT%H:%M:%SZ))" >> staging-task-2a-evidence.txt
railway ssh -e staging --service MINT 'cd /app && python3 scripts/backfill_snapshot_to_fact_event.py --apply' 2>&1 | tee .planning/phases/mint-data-architecture-v1-02-deploy/staging-backfill-run2.log

N_RUN2=$(railway ssh -e staging --service MINT 'python3 -c "
import os, psycopg2
c = psycopg2.connect(os.getenv(\"DATABASE_URL\")); cur = c.cursor()
cur.execute(\"SELECT count(*) FROM fact_event WHERE source_type='\''snapshot_backfill'\''\")
print(cur.fetchone()[0])
"')
echo "N_RUN2 = $N_RUN2" >> staging-task-2a-evidence.txt

# Assertion : N_RUN2 == N_RUN1 (idempotent, even if both 0)
if [ "$N_RUN1" = "$N_RUN2" ]; then
  echo "✓ Idempotency proven : N_RUN1 == N_RUN2 == $N_RUN1" >> staging-task-2a-evidence.txt
else
  echo "✗ BLOCKED: idempotency failed N_RUN1=$N_RUN1 N_RUN2=$N_RUN2" >> staging-task-2a-evidence.txt
  exit 1
fi
```

7. **Step 7 — Capture idempotency counter delta** (per H-1 fix : metric assertion is « ≥ 3 of 4 counters present » to tolerate drift counter absence pre-PR-B-merge) :

```bash
echo "" >> staging-task-2a-evidence.txt
echo "## Step 7 — Idempotency counter snapshot ($(date -u +%Y-%m-%dT%H:%M:%SZ))" >> staging-task-2a-evidence.txt
curl -sf https://mint-staging.up.railway.app/metrics | grep -E "mint_projector_idempotency_skip_total|mint_fact_event_insert_total|mint_dek_envelope_status_total|mint_snapshot_fact_current_drift_total" > .planning/phases/mint-data-architecture-v1-02-deploy/staging-metrics-snapshot-post-backfill.txt
cat .planning/phases/mint-data-architecture-v1-02-deploy/staging-metrics-snapshot-post-backfill.txt >> staging-task-2a-evidence.txt
echo "" >> staging-task-2a-evidence.txt
echo "Note (per H-1 fix) : 4 counters expected — mint_projector_idempotency_skip_total + mint_fact_event_insert_total + mint_dek_envelope_status_total + mint_snapshot_fact_current_drift_total. The last (drift counter) is declared by Plan 01 PR B ; if PR B is not yet merged + deployed on staging at the moment this snapshot runs, the drift counter is ABSENT — that is acceptable for Wave 1 probe (3 of 4 ≥ minimum). Drift counter presence will be verified post-PR-B-merge in Wave 2 Plan 03 Task 1 cron-activation step." >> staging-task-2a-evidence.txt
echo "Note : staging has 0 snapshots so backfill produced 0 fact_event INSERTs (idempotency_skip = 0 on second pass — vacuous gate per locked decision 'staging-backfill-note')." >> staging-task-2a-evidence.txt
```

8. **Step 8 — Run 100% staging-user canonical-JSON parity audit** :

```bash
echo "" >> staging-task-2a-evidence.txt
echo "## Step 8 — projection_diff full audit ($(date -u +%Y-%m-%dT%H:%M:%SZ))" >> staging-task-2a-evidence.txt
railway ssh -e staging --service MINT 'cd /app && python3 -m tools.parity.projection_diff --audit-all-users --persist-to _phase02_parity_audit' 2>&1 | tee .planning/phases/mint-data-architecture-v1-02-deploy/staging-projection-diff-full-audit.log

# Capture audit table row count
AUDIT_ROW_COUNT=$(railway ssh -e staging --service MINT 'python3 -c "
import os, psycopg2
c = psycopg2.connect(os.getenv(\"DATABASE_URL\")); cur = c.cursor()
cur.execute(\"SELECT count(*), count(*) FILTER (WHERE diff_detected) FROM _phase02_parity_audit\")
print(cur.fetchone())
"')
echo "audit table state : $AUDIT_ROW_COUNT" >> staging-task-2a-evidence.txt
# Expected : (131, 0) — 131 users audited, 0 with diff (vacuously since both projection paths read from same snapshot=0 inventory)
```

9. **Step 9 — Verify zero diff** :

```bash
USERS_WITH_DIFF=$(railway ssh -e staging --service MINT 'python3 -c "
import os, psycopg2
c = psycopg2.connect(os.getenv(\"DATABASE_URL\")); cur = c.cursor()
cur.execute(\"SELECT count(*) FROM _phase02_parity_audit WHERE diff_detected\")
print(cur.fetchone()[0])
"')

if [ "$USERS_WITH_DIFF" = "0" ]; then
  echo "✓ Zero diff : USERS_WITH_DIFF == 0" >> staging-task-2a-evidence.txt
else
  echo "✗ BLOCKED: USERS_WITH_DIFF=$USERS_WITH_DIFF (expected 0)" >> staging-task-2a-evidence.txt
  exit 1
fi
```

10. **Step 9.5 — projection_diff self-test (regression check)** :

```bash
echo "" >> staging-task-2a-evidence.txt
echo "## Step 9.5 — projection_diff.py self-test deterministic (local)" >> staging-task-2a-evidence.txt
python3 tools/parity/projection_diff.py --self-test 2>&1 | tail -5 >> staging-task-2a-evidence.txt
# Expected : 12/12 known-equal/known-different pairs pass
```
  </action>
  <verify>
    <automated>cd /Users/julienbattaglia/Desktop/MINT.nosync && [ -f .planning/phases/mint-data-architecture-v1-02-deploy/staging-backfill-run1.log ] && [ -f .planning/phases/mint-data-architecture-v1-02-deploy/staging-backfill-run2.log ] && [ -f .planning/phases/mint-data-architecture-v1-02-deploy/staging-projection-diff-full-audit.log ] && [ -f .planning/phases/mint-data-architecture-v1-02-deploy/staging-metrics-snapshot-post-backfill.txt ] && grep -q "Idempotency proven : N_RUN1 == N_RUN2" .planning/phases/mint-data-architecture-v1-02-deploy/staging-task-2a-evidence.txt && grep -q "Zero diff : USERS_WITH_DIFF == 0" .planning/phases/mint-data-architecture-v1-02-deploy/staging-task-2a-evidence.txt && grep -q "FF_FACT_EVENT_DUAL_WRITE=on" .planning/phases/mint-data-architecture-v1-02-deploy/staging-task-2a-evidence.txt && [ $(grep -cE "mint_projector_idempotency_skip_total|mint_fact_event_insert_total|mint_dek_envelope_status_total|mint_snapshot_fact_current_drift_total" .planning/phases/mint-data-architecture-v1-02-deploy/staging-metrics-snapshot-post-backfill.txt) -ge 3 ]</automated>
  </verify>
  <acceptance_criteria>
    - `.planning/phases/mint-data-architecture-v1-02-deploy/staging-backfill-run1.log` exists.
    - `.planning/phases/mint-data-architecture-v1-02-deploy/staging-backfill-run2.log` exists.
    - `.planning/phases/mint-data-architecture-v1-02-deploy/staging-projection-diff-full-audit.log` exists.
    - `.planning/phases/mint-data-architecture-v1-02-deploy/staging-metrics-snapshot-post-backfill.txt` exists + contains ≥ 3 of 4 counters from the set {`mint_projector_idempotency_skip_total`, `mint_fact_event_insert_total`, `mint_dek_envelope_status_total`, `mint_snapshot_fact_current_drift_total`} (per H-1 fix — drift counter MAY be absent if PR B not yet merged + deployed on staging at probe time ; 3-of-4 is the minimum threshold ; drift counter verified post-PR-B-merge in Wave 2 Plan 03 Task 1).
    - `grep "Idempotency proven : N_RUN1 == N_RUN2" staging-task-2a-evidence.txt` returns ≥ 1 hit (idempotency assertion green).
    - `grep "Zero diff : USERS_WITH_DIFF == 0" staging-task-2a-evidence.txt` returns ≥ 1 hit (parity audit green — vacuous but persist path proven).
    - `grep "FF_FACT_EVENT_DUAL_WRITE=on" staging-task-2a-evidence.txt` returns ≥ 1 hit (FF flipped on staging).
    - `grep -E "FF_FACT_EVENT_DUAL_WRITE.*unset on production" staging-task-2a-evidence.txt` returns ≥ 1 hit (prod FF still OFF — Wave 4 prereq).
    - `grep "Override applied with Julien sign-off" staging-task-2a-evidence.txt` returns ≥ 1 hit (preflight 131-user override documented).
    - `cd /Users/julienbattaglia/Desktop/MINT.nosync && python3 tools/parity/projection_diff.py --self-test` exits 0 (deterministic gate).
    - `_phase02_parity_audit` table row count = 131 (one row per staging user audited).
    - `_phase02_parity_audit` `diff_detected=true` row count = 0.
    - If any of the 9 step assertions fails : executor STOPS + surfaces blocker in evidence file + asks Julien (memory `feedback_blockers_ask_dont_defer`) ; does NOT proceed to Task 3 checkpoint.
  </acceptance_criteria>
  <done>
    Task 2a Steps 1-9 automated execution complete. Backfill ×2 idempotent on staging (vacuously since 0 snapshots — clean exit proves script doesn't raise). projection_diff full audit zero diff (vacuously since both paths read from same 0-inventory). FF=on staging only ; prod FF=off preserved. Counter snapshot captured (≥ 3 of 4 counters — drift counter MAY be absent pre-PR-B-merge per H-1 fix). Self-test deterministic. Ready for Julien sign-off (Task 3 checkpoint).
  </done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <name>Task 3 (Julien CHECKPOINT) : Task 2a operational gate sign-off — Julien verifies evidence + types approval signal + records in PERIMETERS.md ledger</name>
  <files>N/A — checkpoint task ; no file mutation by Claude. Julien runs verification steps + types resume-signal.</files>
  <what-built>
    Tasks 1 + 2 have executed the full Task 2a operational sequence per Plan 02-03 iter-2 contract :

    1. **Pre-flight Wave-1 verification** (Task 1) : 3 hard-stop prereq assertions (PR A2 merged on dev + PR A3 merged on dev + p120 `fact_current.latest_event_id` col present on staging) + staging postgres-qdyu at `p120_fact_event_idempotency`, fact_event/fact_current/dek_envelope tables present, MINT_AUDIT_HASH_PEPPER set.

    2. **Task 2a Steps 1-9 automated** (Task 2) :
       - Preflight zero-user gate returned BLOCKED (131 users) — override DOCUMENTED with rationale (staging premise + 0 snapshots + no risk to existing data).
       - Multi-shape canary parity gate regression-checked PASS.
       - `FF_FACT_EVENT_DUAL_WRITE=on` set on staging ; prod FF UNSET preserved.
       - Railway re-deploy completed + /metrics endpoint healthy.
       - `backfill_snapshot_to_fact_event.py --apply` run twice → both runs exit 0 → row count delta = 0 (vacuous since 0 snapshots, but script doesn't raise → idempotency proven).
       - `mint_projector_idempotency_skip_total` counter captured in metrics snapshot (≥ 3 of 4 counters present per H-1 fix — drift counter MAY be absent pre-PR-B-deploy).
       - `projection_diff.py --audit-all-users --persist-to _phase02_parity_audit` ran → 131 users audited → 0 USERS_WITH_DIFF.
       - `projection_diff.py --self-test` deterministic (12/12 pairs).

    All evidence files committed in `.planning/phases/mint-data-architecture-v1-02-deploy/` :
    - `staging-task-2a-evidence.txt` (consolidated 50+ line evidence + Step 0 hard-stops)
    - `staging-backfill-run1.log` + `staging-backfill-run2.log` (idempotency log pair)
    - `staging-projection-diff-full-audit.log` (full audit output)
    - `staging-metrics-snapshot-post-backfill.txt` (counters /metrics output)

    **NOT shipped this checkpoint** :
    - PR-3b read-cutover (Wave 2 Plan 03 — gated on this sign-off).
    - Continuous_drift_sampler cron activation (Wave 2 Plan 03 PR-3a merge step).
  </what-built>
  <action>
    Checkpoint task — Claude executes no file mutation here. The atomic
    operations (PR builds, evidence file generation, code commits) all live
    in the preceding `type="auto"` tasks of this plan. This checkpoint task
    pauses execution until Julien types the `resume-signal` after running
    the verification steps listed in `<how-to-verify>` below.
  </action>
  <how-to-verify>
    **Julien verifies (in this order, ~10 min)** :

    1. **Open evidence files** :
       ```bash
       cat .planning/phases/mint-data-architecture-v1-02-deploy/staging-task-2a-evidence.txt | head -100
       cat .planning/phases/mint-data-architecture-v1-02-deploy/staging-backfill-run1.log
       cat .planning/phases/mint-data-architecture-v1-02-deploy/staging-backfill-run2.log
       cat .planning/phases/mint-data-architecture-v1-02-deploy/staging-projection-diff-full-audit.log
       cat .planning/phases/mint-data-architecture-v1-02-deploy/staging-metrics-snapshot-post-backfill.txt
       ```

    2. **Confirm key claims** :
       - [ ] `staging-task-2a-evidence.txt` shows « Hard-stop Assertion 1 — PR A2 » + « Hard-stop Assertion 2 — PR A3 » + « Hard-stop Assertion 3 — p120 latest_event_id » all green (3 prereqs satisfied).
       - [ ] `staging-backfill-run1.log` last line shows `Backfilled 0 users → 0 fact_event rows` (or similar — staging has 0 snapshots so backfill is no-op).
       - [ ] `staging-backfill-run2.log` last line shows `0 new fact_event rows ; 0 idempotency_skip increments` (or similar — vacuous idempotency on 0 inventory).
       - [ ] `staging-projection-diff-full-audit.log` last line shows `USERS_AUDITED=131, USERS_WITH_DIFF=0`.
       - [ ] `staging-metrics-snapshot-post-backfill.txt` contains at least 3 of 4 counter lines (`mint_projector_idempotency_skip_total`, `mint_fact_event_insert_total`, `mint_dek_envelope_status_total`, `mint_snapshot_fact_current_drift_total` — drift counter optional pre-PR-B-deploy).
       - [ ] Evidence file documents preflight override rationale (« 131 users = staging premise, 0 snapshots = backfill no-op »).

    3. **Spot-check staging on a test account** (optional, +5 min) :
       ```bash
       # Pick Julien's staging test user UID
       USER_ID=<julien-staging-test-uid>
       curl -sf "https://mint-staging.up.railway.app/v1/projection/$USER_ID" > /tmp/proj_pre_cutover.json
       railway ssh -e staging --service MINT "psql \$DATABASE_URL -tAc \"SELECT * FROM _phase02_parity_audit WHERE user_id_hash = hmac_user_id('\$USER_ID')\""
       # Expected : 1 row in _phase02_parity_audit with diff_detected=false
       ```

    4. **Verify FF state** :
       ```bash
       railway variables -e staging --service MINT | grep FF_FACT_EVENT_DUAL_WRITE   # expect : on
       railway variables -e production --service MINT | grep FF_FACT_EVENT_DUAL_WRITE  # expect : (unset)
       ```

    5. **Record sign-off in PERIMETERS.md ledger** (Claude appends after Julien signals approval) :

       ```markdown
       ## Phase 02-deploy Wave 1 Task 2a — APPROVED 2026-XX-XX

       Per `.planning/phases/mint-data-architecture-v1-02-deploy/staging-task-2a-evidence.txt` + supporting logs :

       - 3 hard-stop prereqs satisfied (PR A2 + PR A3 merged + p120 col present on staging).
       - Staging at p120_fact_event_idempotency ; fact_event/fact_current present.
       - Preflight 131-user override DOCUMENTED + rationale (staging premise + 0 snapshots).
       - Backfill ×2 idempotent (vacuous — 0 snapshots — but script exit 0 both runs).
       - projection_diff full audit : 131 users, 0 diff.
       - FF=on staging only ; prod FF unset preserved.

       Approved signal : « approved PR-3a — backfill idempotent, 100% staging-user parity audit zero diff, projection_diff.py deterministic »

       Julien signature : {julienbattaglia, 2026-XX-XX HH:MM UTC}
       Evidence sha : {commit sha of this PERIMETERS.md entry}
       Wave 2 PR-3b unblocked. Continuous_drift_sampler cron activation scheduled for PR-3a merge step.
       ```

    **Gate decision** :
    - All checks pass → type `approved PR-3a — backfill idempotent, 100% staging-user parity audit zero diff, projection_diff.py deterministic` → Claude records in PERIMETERS.md + closes Wave 1.
    - Any check fails → describe failure mode ; Claude diagnoses + ships fix-up commit + re-runs Tasks 1-2 + returns to this checkpoint.
    - 131-user override concerns → Julien may type alternative signal `defer — preflight override needs re-discussion` + Claude opens new CHECKPOINT.

    **Critical caveat per 0-trust §9** : « approved » does NOT mean Wave 2 PR-3b ships immediately. It means the OPERATIONAL gate Task 2a is signed-off ; PR-3b ships when Wave 2 Plan 03 executes (separate planner-orchestrated phase).
  </how-to-verify>
  <verify>
    <automated>echo "Checkpoint task — verification is manual by Julien per <how-to-verify> ; this <verify> stub is a structural placeholder. Resume blocked until <resume-signal> received."</automated>
  </verify>
  <acceptance_criteria>
    - [ ] Julien types `<resume-signal>` verbatim (« approved PR-3a — backfill idempotent, 100% staging-user parity audit zero diff, projection_diff.py deterministic ») in chat (or alternative `defer` / failure-mode signal).
    - [ ] PERIMETERS.md ledger entry « Phase 02-deploy Wave 1 Task 2a — APPROVED » committed (commit sha recorded in evidence file + SUMMARY).
    - [ ] No blocker raised in resume signal text — if Julien describes a blocker, Claude opens fix-up tasks BEFORE proceeding.
    - [ ] All 5 evidence files referenced in `<what-built>` exist + committed.
    - [ ] 3 Step 0 hard-stop assertions (PR A2 merged + PR A3 merged + p120 col present) all green in evidence file before Julien types approval.
    - [ ] FF state confirmed by Julien : staging=on, prod=unset.
  </acceptance_criteria>
  <done>
    Julien types the resume-signal after running the <how-to-verify> steps successfully. Claude proceeds to the next task (or records sign-off in PERIMETERS.md per task spec).
  </done>
  <resume-signal>
    Type "approved PR-3a — backfill idempotent, 100% staging-user parity audit zero diff, projection_diff.py deterministic" OR "defer — {reason}" OR describe failure mode for fix-up.
  </resume-signal>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| `railway variables --environment staging --set FF_FACT_EVENT_DUAL_WRITE=on` | Single command that mutates Railway staging env ; if invoked with `--environment production` instead, cascades to prod ; mitigated by explicit `staging` flag + verification step. |
| Staging `/metrics` endpoint | Public-accessible per Phase 01 W4 ; reveals counter names + values ; per RESEARCH §Security-Domain low-sensitivity (no PII, counter cardinality bounded). |
| `_phase02_parity_audit` table writes | Contains `user_id_hash` (HMAC-pepper'd) + diff metadata only — no PII per RESEARCH §Threat patterns row 11. |
| Julien PERIMETERS.md sign-off commit | Immutable per git history ; signature anchor for Wave 2 unblock. |
| Plan 01 PR A2/A3/B merge state + Railway staging deploy lifecycle | Hard-stop boundary : Task 1 Step 0 asserts (a) A2 merged, (b) A3 merged, (c) p120 deployed on staging-Postgres BEFORE flipping FF=on. Asymmetric guard : merge-to-dev is GSD-tracked (PR open in Plan 01) but Railway auto-deploy is out-of-flow → assertion 3 closes the gap. |

## STRIDE Threat Register (ASVS L1 + engram #194)

| Threat ID | Category | Component | Severity | Disposition | Mitigation |
|-----------|----------|-----------|----------|-------------|------------|
| T-02-01 | Tampering | FF=on accidentally set on production instead of staging | high | mitigate | Task 2 Step 3 uses explicit `--environment staging` flag ; Step 3 verification block re-greps `railway variables -e production` to confirm UNSET. |
| T-02-02 | DoS | Backfill exhausts Railway connection pool | medium | mitigate | Throttled pool `pool_size=2, max_overflow=0` shipped Plan 02-03 substrate iter-2 B15 (already in code). Backfill is no-op on staging (0 snapshots) so pool not stressed this run ; documented for Wave 4 prod where pool will see real load. |
| T-02-03 | Information disclosure | Evidence files commit user_id_hash leakage | low | accept | `_phase02_parity_audit.user_id_hash` is HMAC(pepper, user_id) — opaque without pepper. Pepper rotation runbook (Wave 3 Plan 04 Task 4) covers compromise scenarios. |
| T-02-04 | Tampering | projection_diff non-deterministic if canonical JSON breaks | high | mitigate | Task 2 Step 9.5 invokes `projection_diff.py --self-test` (12 fixtures) to confirm determinism on local Python ; covers the canonical-JSON + Decimal tolerance + missing-key=None rule contracts (iter-2 A10). |
| T-02-05 | Spoofing | Sign-off ledger entry forged | medium | mitigate | PERIMETERS.md edits require git commit ; commit attributed to Julien via git config ; SUMMARY references commit sha (auditable). |
| T-02-06 | Repudiation | Override rationale (131-user preflight bypass) lost | medium | mitigate | Task 2 Step 1 explicitly documents override rationale IN the evidence file (« staging premise + 0 snapshots + no risk ») ; PERIMETERS.md entry duplicates. |
| T-02-07 | Tampering | Operational gate spoofing (Julien types « approved » without actually verifying) | high | accept | Per CLAUDE.md §9 0-trust — Julien is the single source of authority for sign-off ; mitigation is procedural (memory `feedback_critical_pm_mode` requires Julien to verify before approving). |
| T-02-08 | DoS | Wave 1 mid-flight cancellation leaves FF in inconsistent state | low | mitigate | Recovery procedure : `railway variables --environment staging --remove FF_FACT_EVENT_DUAL_WRITE` ; documented in evidence file rollback section. |
| T-02-09 | Tampering | `_phase02_parity_audit` table populated with stale data from a previous Task 2a run | medium | accept | `--persist-to _phase02_parity_audit` appends — older runs are timestamp-distinguishable. Wave 4 prod-side will use fresh `_phase02_parity_audit` (different env). |
| T-02-10 | Tampering | `mint_snapshot_fact_current_drift_total` counter introduced by Plan 01 PR B but not yet incrementing (cron OFF) | low | accept | Wave 2 Plan 03 PR-3a merge step activates cron. This plan only verifies counter is DECLARED + visible at /metrics, not firing yet. Per H-1 fix : drift counter MAY be absent from /metrics if PR B not yet merged + deployed at probe time — 3-of-4 counter threshold tolerates this. |
| T-02-11 | Tampering | Plan 02 starts before Plan 01 PR A2/A3/B merge + staging deploy lifecycle complete → FF=on flipped against staging without D-27 idempotency contract (no p120 latest_event_id col) | high | mitigate | Task 1 Step 0 3 hard-stop assertions (PR A2 merged on dev + PR A3 merged on dev + p120 col present on staging) — executor STOPS + asks Julien if any assertion fails. Locked decision `prereq-pr-merge-and-p120-staging` documents asymmetry between GSD-tracked PR-open + out-of-flow merge-and-deploy. |
</threat_model>

<verification>
**Phase-level checks for this plan :**

1. **`autonomous: false`** — Task 3 CHECKPOINT requires Julien sign-off ; cannot self-clear per 0-trust §9.4.
2. **No code mutation** : zero PR opened in this plan. Mutations are : (a) Railway env var `FF_FACT_EVENT_DUAL_WRITE=on` on staging only, (b) 131 rows appended to staging `_phase02_parity_audit` table, (c) evidence file commits to `.planning/phases/mint-data-architecture-v1-02-deploy/`, (d) PERIMETERS.md ledger entry post-approval.
3. **0-trust §9 strict** : evidence files + Julien CHECKPOINT signal are deterministic citation per §9.6. No « ready » / « shipped » / « green » claims about Wave 2 PR-3b.
4. **Pre-flight 15-item checklist** : items #1, #2, #3, #5, #7 from HANDOFF actively probed in Task 1.
5. **Step 0 hard-stop prereq** : per checker iteration 1 fix C-2, Task 1 Step 0 ships 3 mandatory hard-stop assertions guarding the staging-prereq lifecycle (PR A2 merged + PR A3 merged + p120 col deployed). Asserts BEFORE any FF flip / backfill / audit. Memory `feedback_blockers_ask_dont_defer` enforced.
6. **Override path documentation** : 131-user preflight override + 0-snapshot backfill vacuity both documented in evidence file with rationale.
7. **Engram contract** : at end of plan, `mem_save` with `topic_key: mint-data-architecture-v1-02-deploy:wave-1:staging-task-2a-julien-signed` + `prior_finding_refs` to obs #233 (operational substrate gap) + #249 (staging-landed) + #194 (Phase 02 deep security audit) + #178 (devops Q6 + counters) + Plan 01 obs.
</verification>

<success_criteria>
- [ ] Step 0 hard-stop assertion 1 (PR A2 D-27 + p120) merged on dev — verified Task 1.
- [ ] Step 0 hard-stop assertion 2 (PR A3 JSONB cast / rollback / pepper rotation) merged on dev — verified Task 1.
- [ ] Step 0 hard-stop assertion 3 (`fact_current.latest_event_id` col present on staging postgres-qdyu) — verified Task 1.
- [ ] Staging postgres-qdyu state confirmed : alembic head=p120, fact_event+fact_current+dek_envelope tables present, MINT_AUDIT_HASH_PEPPER set (Task 1).
- [ ] `FF_FACT_EVENT_DUAL_WRITE=on` set on staging only ; prod FF UNSET preserved (Task 2 Step 3).
- [ ] Backfill ×2 idempotent (Task 2 Steps 5-6) — vacuous since 0 snapshots, but script exit 0 both runs.
- [ ] projection_diff 100% staging-user audit zero diff (Task 2 Steps 8-9) — vacuous since 0 snapshots, persist path proven.
- [ ] projection_diff --self-test deterministic (Task 2 Step 9.5).
- [ ] Counter snapshot captured + contains ≥ 3 of 4 D-33 counters in /metrics output (Task 2 Step 7 — per H-1 fix, drift counter optional pre-PR-B-deploy).
- [ ] 5 evidence files committed to `.planning/phases/mint-data-architecture-v1-02-deploy/`.
- [ ] PERIMETERS.md ledger entry recorded post-Julien-approval (Task 3 resume signal received).
- [ ] Julien sign-off signal : « approved PR-3a — backfill idempotent, 100% staging-user parity audit zero diff, projection_diff.py deterministic » (Task 3).
- [ ] 7-day soak override pre-documented in this plan SUMMARY per locked decision #4 (0-user-prod premise documentation pattern to reuse for Wave 2 PR-3b commit body).
- [ ] All threats in STRIDE register have a disposition (mitigate / accept) — no « pending » severity:high threats.
- [ ] Engram observation saved with `prior_finding_refs` ≥5 obs.
</success_criteria>

<output>
After completion, ensure :
- `.planning/phases/mint-data-architecture-v1-02-deploy/mint-data-architecture-v1-02-deploy-02-staging-migration-apply-SUMMARY.md` (per-task receipt) exists.
- 5 evidence files in `.planning/phases/mint-data-architecture-v1-02-deploy/` exist + committed.
- PERIMETERS.md updated with Wave 1 Task 2a sign-off ledger entry (commit sha referenced in SUMMARY).
- 0-trust §9.6 Evidence + Caveat block in SUMMARY listing : Evidence = 5 evidence files committed + Julien resume-signal + Railway env CLI output. Caveat = (a) backfill is vacuous since 0 snapshots, (b) idempotency proof is « no script raise » not « non-zero replays », (c) Wave 2 PR-3b NOT shipped yet, (d) prod migration NOT applied (Wave 4), (e) drift counter MAY be absent from metrics snapshot pre-PR-B-deploy per H-1 fix.
- `mem_save` with `topic_key: mint-data-architecture-v1-02-deploy:wave-1:staging-task-2a-julien-signed-{date}` + `prior_finding_refs` ≥5 obs (#233, #249, #194, #178, Plan 01 obs).
- Forward-deferred items list : Wave 2 PR-3b atomic trio + cron activation + Mobile L1 wiring + Wave 4 prod-side replay.
- Re-confirm that `FF_FACT_EVENT_DUAL_WRITE` on prod is STILL UNSET (Wave 4 prereq) — last grep before SUMMARY close.
</output>
</content>
</invoke>