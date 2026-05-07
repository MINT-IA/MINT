# Phase 96: Production Observability — Context

**Gathered:** 2026-05-06
**Status:** Ready for planning
**Mode:** Auto-generated from milestone synthesis (REQUIREMENTS.md OBS-01..03 + doctrine W4 closure `2026-05-06-test-theater-post-mortem-doctrine.md`)

<domain>
## Phase Boundary

Production telemetry today is **half-wired**: `services/backend/app/main.py:25` initialises `sentry_sdk` with `traces_sample_rate=0.1` + `send_default_pii=False`, and `apps/mobile/lib/main.dart:141` calls `SentryFlutter.init(...)` with Session Replay masks — but there is **no release-health alert rule, no synthetic uptime probe, and no per-response Sentry tag**. A staging crash (or a 503 storm on `/anonymous/chat`) would be visible in Sentry's UI only if Julien happens to open the dashboard ; nobody is paged. A FINMA inspector asking « show me which of yesterday's 100 coach responses contained a banned term » must SQL the `coach_message_audits` table directly — Sentry holds the same signal but the tags aren't plumbed, so it can't be filtered there. Doctrine W4 (`2026-05-06-test-theater-post-mortem-doctrine.md` §4 Week 4) is explicit : « Sentry events tag every `/anonymous/chat` response with `eval_score`, `banned_term_hit`, `eclairage_kind`. Walker becomes optional dev tool ; production is the source of truth. »

Phase 96 closes that gap by wiring **3 production-grade observability surfaces** : (1) **Sentry release-health alert** firing PagerDuty/Slack when crash-free sessions drop below 99.5% over a rolling 1h window (closes the pre-TestFlight ship gate item « Sentry crash-free-sessions ≥ 99.5% over the last staging build's 24h ») ; (2) **Checkly synthetic probes** on `/anonymous/chat`, `/auth/login`, `/documents/upload`, `/health` at 5-min cadence (closes ship-gate item « Synthetic anon-chat probe 100% over last 6h on Checkly ») ; (3) **per-response Sentry event tagging** with `eval_score` (from Phase 95 promptfoo runtime), `banned_term_hit` (already computed at `coach_chat.py:2739`, just plumb to Sentry instead of only DB), `eclairage_kind` (already computed at `anonymous_chat.py:367`). All three rely on infra Phase 93 + 95 already shipped — **no new SDK installs**, only configuration, alert rules, a thin tagging helper, and a Checkly project.

Out of scope: Maestro E2E mobile suite (Phase 97 SHIP-01), TestFlight Internal cohort + counsel sign-off (Phase 97 SHIP-02/04), Datadog/Grafana « LSFin compliance score » 30-day trend dashboard (doctrine §4 W4 mentions Grafana but the auditor artefact is a Sentry dashboard query screenshot — Grafana deferred), `coach_message_audits` retention purge cron (the `retained_until` column exists per `coach_message_audit.py:76` ; the actual purge job is post-MVP — see `<deferred>`). **Doctrine W4 is the load-bearing context for every decision below.**
</domain>

<decisions>
## Implementation Decisions

### OBS-01 — Sentry release-health alert (crash-free sessions < 99.5%, 1h rolling, page within 15 min)

- **Sentry workspace exists.** Backend init at `services/backend/app/main.py:24-31` with `settings.SENTRY_DSN` from `core/config.py:40`. Mobile init at `apps/mobile/lib/main.dart:141-187` (D-02 Option A — single Sentry project, env tag drives `development` / `staging` / `production` split). Both DSNs already plumbed via Railway env (backend) + dart-define (mobile, see `MINT_ENV_DART_DEFINE` contract `.planning/phases/31-instrumenter/31-01-SUMMARY.md`). **No new project creation needed.**
- **Alert rule scope: mobile only for OBS-01.** Crash-free *sessions* is a mobile SDK metric (Sentry release-health is session-tracking on Flutter/iOS/Android). Backend uses crash-free *requests* — different metric, different alert (Plan 96-01 wires both : OBS-01a mobile sessions, OBS-01b backend HTTP 5xx rate as sister alert).
- **Threshold + window: < 99.5% crash-free sessions over rolling 60 min**, on the `staging` and `production` Sentry environment tags only (skip `development`). Cooldown: 30 min between repeat fires of the same alert (prevents storm during incident).
- **Alert rule provisioned via Sentry web UI** (Sentry Alert Rules API exists but Plan 96-01 uses UI provisioning — single-time, screenshot in `96-VERIFICATION-REPORT.html` is the auditor artefact ; doctrine §4 W4 « Sentry dashboard query » pattern). UI path: *Sentry → Alerts → Create Alert → « Crash-Free Session Rate » metric → < 99.5% over 1h → environment is `staging` or `production`*.
- **Notification routing: Sentry → Slack (primary) + Sentry → PagerDuty (sister, deferred).** Doctrine §8 stack table budgets PagerDuty ≈ $0/$21/mo (free tier covers 5 users + 1 schedule, sufficient for solo founder). **Slack-first because zero new vendor onboarding** — Sentry has a native Slack integration (1-click OAuth in Sentry settings, no webhook plumbing). Slack channel: `#mint-alerts` (create if absent ; Plan 96-01 task). PagerDuty as a sister alert receiver added in Plan 96-01 only if the Sentry « Team » plan tier confirmed (see Open Questions).
- **Verification (success criterion 1 — « test crash → notification within 15 min »):** Plan 96-01 final task ships a `tools/scripts/sentry_crash_canary.dart` script that runs against a `staging` Flutter build, throws `SentryCrashCanaryException` on tap, confirms Slack notification arrives within 15 min. Screenshot + timestamp captured in `96-VERIFICATION-REPORT.html`. The canary file is gated by `kDebugMode || const bool.fromEnvironment('MINT_SENTRY_CANARY')` so it's strip-on-release per the production-safety lint pattern from Phase 93-04.
- **Sentry plan tier:** Sentry release-health + Slack integration are available on the **Free Developer plan** (1 user, 5K errors/mo, 10K performance units/mo). Backend + mobile combined session volume ≈ a few hundred/day in staging — well under the cap. **No paid upgrade required for OBS-01.** If volume grows past Free-plan limits during TestFlight Internal cohort, upgrade to Team ($26/mo) is one-click and changes nothing in the alert config.

### OBS-02 — Checkly synthetic probes (4 staging endpoints, 5-min cron, page on failure)

- **Account creation needed.** Checkly is an external SaaS — no existing wiring. Plan 96-02 first task: Julien creates a Checkly account at `checklyhq.com`, generates an API token, stores in `CHECKLY_API_KEY` GitHub secret + Railway env (the Railway plumbing is for the « checkly-as-code » CLI invoked from CI to keep checks in version control). **Decision required (Julien): Checkly Hobby tier ($0, 10K runs/mo) vs Team tier ($30/mo, 50K runs/mo).** 4 endpoints × 5-min cron × 30 days ≈ 35K runs/mo — **Hobby tier insufficient**, Team tier required. See Open Questions.
- **Checks-as-code via `checkly-cli`.** Mirror the `terraform`-style pattern doctrine §8 implies. Repo path: `tools/checkly/` (new dir) with `checkly.config.ts` + `checks/*.check.ts`. CI workflow `.github/workflows/checkly_deploy.yml` runs `checkly deploy` on push to `main` (mirrors how `deploy-backend.yml:142` plumbs `STAGING_API_URL`). Checks live in git, reviewable in PR diff.
- **4 endpoint definitions (matching ROADMAP.md line 181 exactly):**
  | Endpoint | Path on staging | Method | Expect | Notes |
  |---|---|---|---|---|
  | Health | `https://mint-staging.up.railway.app/api/v1/health` | GET | 200 + JSON `{"status": "ok"}` | Verified live at `services/backend/app/api/v1/endpoints/health.py:18`. |
  | Auth login | `https://mint-staging.up.railway.app/api/v1/auth/login` | POST | 200 + `access_token` field | Verified at `services/backend/app/api/v1/endpoints/auth.py:313`. Uses dedicated `checkly@mint.test` synthetic user (Plan 96-02 creates + stores creds in Checkly env vars — never in repo per `feedback_app_targets_staging_always.md`). |
  | Anonymous chat | `https://mint-staging.up.railway.app/api/v1/anonymous/chat` | POST | 200 + non-empty `message` field | Verified at `services/backend/app/api/v1/endpoints/anonymous_chat.py:238`. Uses anon-session cookie pattern (Checkly preserves cookies across browser checks ; for API checks we stub the `X-Anonymous-Session` header). |
  | Documents upload | `https://mint-staging.up.railway.app/api/v1/documents/upload` | POST | 200 + `document_id` field | Verified at `services/backend/app/api/v1/endpoints/documents.py:392`. Uses 1-pixel JPEG fixture committed at `tools/checkly/fixtures/probe.jpg`. Auth header reuses the OBS-02 synthetic user JWT, refreshed in a Checkly « setup » script per run. |
- **Cron: 5-min interval globally.** All 4 checks scheduled identically. Run from Frankfurt + Dublin Checkly regions (closest to Railway EU), require BOTH to pass before declaring green (catches single-region carrier issues, doctrine §3 mistake #4 « tests pass conflated with product correct » — single probe is theater).
- **Alert routing: Checkly → same Slack `#mint-alerts` channel as OBS-01.** Single channel = single page of glass for incidents. Checkly has native Slack webhook support, no custom relay needed. PagerDuty sister-route deferred to same trigger as OBS-01.
- **Verification (success criterion 2 — « deliberate staging downtime drill »):** Plan 96-02 final task takes `mint-staging.up.railway.app` to maintenance mode for 7 min via Railway dashboard (covers > 1 cron interval = guaranteed probe failure on next run). Verify Slack notification arrives within 10 min of first failed probe. Screenshot + Slack message timestamp captured in `96-VERIFICATION-REPORT.html`. Restore staging within 10 min total of taking down (no user impact — TestFlight cohort doesn't exist yet).

### OBS-03 — Sentry events tag every coach response with `eval_score`, `banned_term_hit`, `eclairage_kind`

- **OBS-03 is implementable today.** Phase 93-01 already computes `banned_term_hit` (`coach_chat.py:2739`) + `eclairage_kind` (`anonymous_chat.py:367`) and persists them to `coach_message_audits`. Phase 95 ships promptfoo runtime which produces `eval_score` ; **OBS-03 reuses the same scoring function locally (in-process, not full eval — single-prompt pass-rate check)**. So OBS-03 plumbs already-computed values into Sentry tags ; no new business logic.
- **Tagging location: end of response handler, AFTER audit row insert, BEFORE `return CoachChatResponse(...)`.** Two sites :
  - `services/backend/app/api/v1/endpoints/coach_chat.py:2728-2768` (authed `/coach/chat` final audit + tag block) — currently sets `audit_emitted: true` only ; extend to set `eclairage_kind`, `banned_term_hit`, `eval_score` on the same `sentry_sdk.set_tag(...)` calls.
  - `services/backend/app/api/v1/endpoints/anonymous_chat.py:357-376` (anon `/anonymous/chat` final audit block) — currently NO Sentry tag call ; add the same 3 tags after `db.commit()`.
  - Plan 96-03 extracts a `_emit_sentry_audit_tags(*, eclairage_kind, banned_term_hit, eval_score, archetype)` helper to `services/backend/app/utils/sentry_audit_tags.py` so both endpoints call one function (DRY, single source of truth, future-proof for `/coach/chat` FATCA-handoff path at `coach_chat.py:2536-2541` which currently sets only `audit_emitted`).
- **`eval_score` computation: in-process per response, NOT a full promptfoo run.** Reuses the assertions defined in Phase 95 `services/backend/evals/assertions/*.yaml` but invoked as a Python lib call against the response only (no LLM-as-judge — that's doctrine §4 W3, deferred). Score = pass-count / total-assertions across (banned-term FR/DE/IT × numeric-bound × JSON-schema). Range: `[0.0, 1.0]`, float, capped to 2 decimals. **Cost: $0** (lexical + numeric only, no LLM invocation in hot path).
- **Tag value contracts:**
  - `eval_score`: float as string, `"0.97"`. Sentry tags are string-typed.
  - `banned_term_hit`: `"true"` / `"false"` (lowercase, matches existing `audit_emitted` style).
  - `eclairage_kind`: snake_case string from `EclairagePayload.kind` (e.g. `"fiscal_margin_3a"`, `"fatca_handoff"`) or `"none"` when no eclairage emitted.
  - `archetype`: piggy-back the same call to set `archetype` tag (already in audit row ; cheap to mirror) — enables Sentry dashboard slicing « banned-term hits per archetype × locale ».
- **Sampling: 100%.** Per response. Sentry's `traces_sample_rate=0.1` is for *performance* spans, not custom events — `set_tag` runs on the in-flight transaction always. Tag overhead ≈ 4 × `set_tag` calls × ~µs each, no perf concern. **Disagreement with `traces_sample_rate=0.1` is intentional** : we want every banned-term hit visible in Sentry, not 10% of them. Volume is still bounded by request rate (TestFlight Internal cohort = 5 users, ~50 coach responses/day max).
- **Verification (success criterion 3 — « Sentry dashboard query + sample 10 events from staging »):** Plan 96-03 final task hits staging coach via 10 deliberate prompts (1 banned-term canary, 1 fiscal_margin_3a trigger, 1 FATCA-handoff trigger, 7 normal). Open Sentry dashboard, filter by `eclairage_kind:fatca_handoff` → expect 1 event ; filter by `banned_term_hit:true` → expect 1 event ; filter by `eval_score:>0.9` → expect 9+ events. Screenshot of each filter result captured in `96-VERIFICATION-REPORT.html`.

### Claude's discretion

- **Slack as primary alert channel + PagerDuty as deferred sister:** zero new vendor onboarding, free tier sufficient. PagerDuty added when (a) Julien wants on-call rotation + escalation, (b) volume justifies the $21/mo. Until then Slack alone is the page of glass.
- **Checkly checks-as-code under `tools/checkly/`** (NOT `.github/checkly/`): mirrors the `tools/checks/` discipline for lints. Aligns with `feedback_pre_push_checklist.md` mental model — operational scripts live under `tools/`.
- **`eval_score` as in-process lexical/numeric subset, NOT a full promptfoo invocation per response:** doctrine §6 cost-discipline objection (« $200-500/mo if walker runs on every PR ») applies double-edged to per-response evals — would push Anthropic test bill to thousands. Lexical-only is $0, captures 80% of the LSFin signal, and degrades cleanly if the assertion lib is missing (try/except → `eval_score = 1.0` default + Sentry breadcrumb « eval_score_unavailable »).
- **Single Sentry project across mobile + backend** (already established by D-02 Option A in Phase 31-01) — OBS-03 backend tags + OBS-01 mobile alerts share one project, one alert UI, one dashboard. Splitting into two projects deferred forever unless cross-team org chart forces it.
- **OBS-01 alert window: 60 min rolling (NOT 15 min):** doctrine W4 + ROADMAP.md line 180 specify « rolling 1h window ». 15-min sub-windows risk false positives during deploys (cold-start crashes spike during Railway redeploy, doctrine-aligned to absorb that into the 1h smoothing).
- **OBS-02 region pair: Frankfurt + Dublin:** EU coverage, low Railway latency, Checkly Hobby tier supports both. North-American region not added — adding a 3rd region triples runs/mo without product-relevant signal (no NA users on TestFlight Internal yet).

</decisions>

<code_context>
## Existing Code Insights

### Reusable assets

- `services/backend/app/main.py:24-31` — backend Sentry init with `traces_sample_rate=0.1`, `send_default_pii=False`, environment tag from `settings.ENVIRONMENT`. **OBS-01 backend alert reuses this DSN + env split unchanged.**
- `apps/mobile/lib/main.dart:141-187` — mobile Sentry init with Session Replay (D-01 Option C), env tag (D-02 Option A — `MINT_ENV` dart-define), tracePropagation allowlist for `mint-staging.up.railway.app`. **OBS-01 mobile alert reads sessions from this exact init — no SDK changes.**
- `services/backend/app/api/v1/endpoints/coach_chat.py:2728-2768` (audit insert + `set_tag("audit_emitted", "true")`) and `anonymous_chat.py:357-376` (audit insert, no tag yet) — **OBS-03 plumbs into these exact blocks**, additive only, never breaks the existing audit-on-best-effort contract.
- `services/backend/app/services/rag/guardrails.py:288-347` — `ComplianceGuardrails.filter_response()` already returns `banned_terms_filtered: bool` ; `coach_chat.py:2738` already calls it for `_banned_hit`. **OBS-03 reuses `_banned_hit` as the `banned_term_hit` tag value — zero new computation.**
- `services/backend/app/models/coach_message_audit.py` — `eclairage_kind` column + `_default_retained_until` (now + 10y). **OBS-03 mirrors `eclairage_kind` from the audit row (or computes once per response, identical result).**
- `services/backend/evals/assertions/*.yaml` (lands in Phase 95 Plan 95-01b) — banned-term + numeric-bound + JSON-schema lexical assertions. **OBS-03 in-process `eval_score` reuses these YAMLs via a thin `evals.assertions.score(response_text, archetype, language)` Python wrapper added in Plan 96-03.**
- `.github/workflows/walker_nightly.yml` — nightly cron pattern with Railway secret injection. **OBS-02 `checkly_deploy.yml` inherits the same secret-plumbing shape** (different secret, same pattern).
- `tools/checks/sentry_capture_single_source.py` (referenced at `apps/mobile/lib/main.dart:41`) — existing Sentry-related lint. OBS-03 may add a sibling `tools/checks/sentry_audit_tags_present.py` ensuring every audit insert call site also calls `_emit_sentry_audit_tags(...)` (drift-prevention).

### Established patterns

- Sentry tagging in MINT uses `sentry_sdk.set_tag(name, value_str)` inside a `try: import sentry_sdk … except: pass` guard (best-effort, never break the response). All OBS-03 tag calls follow this exact shape — see `coach_chat.py:2536-2541` for the canonical template (`audit_emitted` tag).
- Sentry breadcrumbs (vs tags) used for one-off events (« fatca_handoff_emitted » at `coach_chat.py:2509-2516`). OBS-03 extends the breadcrumb pattern only for `eval_score_unavailable` fallback ; canonical signals stay as tags (filterable in dashboard).
- Railway secrets follow `STAGING_*` / `PROD_*` prefix per `deploy-backend.yml:18`. New secrets for Phase 96: `CHECKLY_API_KEY`, `CHECKLY_PROBE_USER_PASSWORD` (synthetic auth user). Both stored on Railway + GH Secrets.
- Auditor artefacts per phase land at `.planning/phases/96-production-observability/96-VERIFICATION-REPORT.html` per memory `feedback_html_evidence_report.md`.

### Integration points

- **OBS-01 (Sentry alert rule):** zero code change. Configuration in Sentry web UI ; canary script under `tools/scripts/sentry_crash_canary.dart` (mobile-side) + a sister `tools/scripts/sentry_backend_canary.py` (backend-side, throws on `/health/canary` route gated by `MINT_SENTRY_CANARY=1` env).
- **OBS-02 (Checkly):** new dir `tools/checkly/` (config + 4 check files) + new workflow `.github/workflows/checkly_deploy.yml` + new Checkly account (Julien-owned, paid tier). Zero backend code change.
- **OBS-03 (Sentry tags):** new `services/backend/app/utils/sentry_audit_tags.py` helper (~30 lines) + 3 call sites updated (`coach_chat.py:2509`, `coach_chat.py:2728`, `anonymous_chat.py:357`) + new `services/backend/evals/scoring.py` module wrapping the assertion YAMLs as a single `score(...)` function (~50 lines, depends on Phase 95 lib).

</code_context>

<specifics>
## Specific Ideas

- **PagerDuty integration via Sentry-PagerDuty native bridge (NOT a custom webhook):** Sentry has a 1-click PagerDuty integration in *Settings → Integrations → PagerDuty* that owns the routing key + service mapping. Rolling our own webhook (Sentry → AWS Lambda → PagerDuty Events API v2) is an antipattern at this scale ; defer custom relay forever unless Sentry deprecates the native bridge. (For now Slack-first, PagerDuty deferred — but when added, use the native bridge.)
- **Checkly « setup » script reuse for synthetic auth:** Checkly browser/API checks support a per-check setup hook (TS code that runs before the assert phase). Plan 96-02's `auth-login` and `documents-upload` checks share a `setup/auth.ts` script that posts to `/auth/login` and caches the JWT for 50 min (under JWT TTL). Documented at `tools/checkly/setup/README.md` with the exact rotation policy.
- **Sentry tag plumbing in MIDDLEWARE, NOT endpoint code (rejected for OBS-03):** A FastAPI middleware reading the response body, parsing it, computing `eval_score` post-flight has 2 problems : (a) middleware doesn't see the LLM `archetype`/`eclairage_kind` decision context, only the JSON response (b) parsing the response twice doubles latency on the hot path. Endpoint-level tagging at the existing audit-insert blocks is correct — local context + already-computed signals.
- **Sentry alert rule lives in Sentry, NOT in repo (rejected « alerts-as-code »):** Sentry has a `sentry-cli` alerts API but it's underdocumented and the rule is created once. UI provisioning + screenshot in `96-VERIFICATION-REPORT.html` is the auditor artefact. If we ever need to recreate the rule from scratch, the screenshot + a written runbook at `docs/runbooks/sentry-alerts.md` is the source of truth. **Tradeoff accepted: 5 min of UI clicks vs 4h of API plumbing for a one-time setup.**
- **Doctrine §4 W4 « Sentry compliance dashboard » = saved query, NOT a separate Grafana:** the auditor artefact is a Sentry dashboard with 3 widgets — (1) `eclairage_kind` distribution last 7d, (2) `banned_term_hit:true` count last 7d, (3) `eval_score` p50/p95 last 7d. Saved as a Sentry Dashboard URL committed to `docs/EVIDENCE.md` row « Sentry compliance dashboard URL ». Grafana deferred (see `<deferred>`).

</specifics>

<deferred>
## Deferred Ideas

- **PagerDuty paid tier ($21/mo) + on-call schedule:** defer until (a) Julien wants escalation rotation, (b) TestFlight External cohort grows past 50 users. Until then Slack `#mint-alerts` is the single channel, Julien is the on-call. Sister-route to PagerDuty wired in Plan 96-01 only as commented-out config — flip when needed.
- **Datadog / Grafana « LSFin compliance score » 30-day trend dashboard:** doctrine §4 W4 mentions Grafana, but the auditor artefact for Phase 96 is a Sentry saved-query dashboard URL (see `<specifics>`). Full Grafana wiring (Loki for logs, Prometheus for metrics, custom dashboards) deferred to v2.16 post-launch ; adds a 4th vendor + ~$50/mo Grafana Cloud Pro for marginal signal over Sentry's native dashboards on a 5-tester cohort.
- **Sentry Session Replay flip from `0.0` to `>0` in production:** mobile init at `main.dart:168-170` keeps prod Replay sample rate at 0.0 pending OBS-06 PII audit sign-off (per the inline comment). OBS-06 is post-MVP — doesn't gate Phase 96.
- **`coach_message_audits` retention purge cron:** the `retained_until` column exists per `coach_message_audit.py:76` (default now + 10y). The actual hard-delete cron (« nightly job purges rows where `retained_until < now()` ») is not in OBS-01..03 ; doctrine W4 doesn't require it for MVP. Defer to v2.15 as a `purge_audit_log.py` GitHub Action.
- **Schemathesis on `/openapi.json` as a 5th synthetic probe:** OBS-02 explicitly scopes 4 endpoints. Property-based fuzz on the OpenAPI surface is doctrine §7 ship-gate item 2 but already deferred from Phase 95 to Phase 97 (see Phase 95-CONTEXT `<deferred>`). Not in 96 either.
- **Checkly browser checks (vs API checks):** OBS-02 ships API checks only (faster, cheaper, sufficient for endpoint-uptime signal). Browser checks (full Chromium navigating `/anonymous/chat` UI) are richer but cost ~10× more runs/mo and are post-Maestro-Cloud (Phase 97 SHIP-01) territory. Defer to v2.16.
- **`eval_score` upgraded to LLM-as-judge (Claude Haiku 3.5 grading « personalized advice ? »):** doctrine §4 W3 work, NOT W4. Phase 96 stays lexical + numeric (0-cost, deterministic). LLM-as-judge layered on in a future phase as a separate `eval_score_llm` tag, kept distinct from the rule-based `eval_score`.

</deferred>
