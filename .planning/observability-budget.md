---
phase: 31
req: OBS-07
created: 2026-04-19
updated: 2026-04-19
tier_locked: D-04 Business ($80/mo)
dsn_strategy: D-02 Option A — single Sentry project + env tag
cap_monthly_usd: 160
alert_monthly_usd: 120
region: EU (nLPD)
owner: julien
status: locked
---

# MINT v2.8 — Observability Budget

**Fetched:** 2026-04-19 — see [`.planning/research/SENTRY_PRICING_2026_04.md`](./research/SENTRY_PRICING_2026_04.md) (A3 assumption VERIFIED — Business tier still $80/mo).
**Target users:** ~5 000 MAU at v2.8 ship.
**Kill-gate:** prod `sessionSampleRate` remains `0.0` per CONTEXT.md D-01 Option C until (a) [`.planning/research/SENTRY_REPLAY_REDACTION_AUDIT.md`](./research/SENTRY_REPLAY_REDACTION_AUDIT.md) is signed AND (b) a separate future decision explicitly flips it. This budget artefact does NOT authorise a prod flip; it costs-out the sampling regime that is already locked.

## Sentry tier decision

**Business Tier at $80/mo base — locked by CONTEXT.md D-04 (2026-04-19).** Rationale:

- **Replay quota (500/mo default inclusion)** — required for `onErrorSampleRate=1.0` capturing ~2 000 replays/mo at 5k MAU × 0.5% crash baseline. Team tier's 50-session inclusion would overage on day one.
- **Cross-project linking (90-day Insights lookback)** — Business-exclusive. OBS-04 needs this so a mobile event pushed by `sentry-trace` + `baggage` headers (Plan 31-01) links visually to the backend transaction in the Sentry UI. Team tier doesn't render the trace panel linkage we need.
- **EU data residency** — Swiss fintech under nLPD, GDPR-adjacent. All Sentry paid tiers support EU org placement; Business gets SAML + SCIM in the same org envelope which we may want once the team grows past solo-Julien.
- **Advanced quota management** — the in-UI spend cap + alert mechanism lives in Business tier's quota panel. This is what enforces the $160/mo ceiling below.
- **Performance units budget** — 100k traces/mo included is compatible with `tracesSampleRate=0.1` at 5k MAU (~50k txns/mo, see Quota projection below).

EU region pin: the org must be placed in the EU data residency zone (Sentry UI → Organization Settings → Data Residency). Screenshot reference + org placement proof lives in [`SENTRY_REPLAY_REDACTION_AUDIT.md`](./research/SENTRY_REPLAY_REDACTION_AUDIT.md) §Sentry org configuration.

**Spend cap $160/mo hard ceiling** (CONTEXT.md D-04). Rationale: any overage beyond $160/mo means a systemic code issue (bare-catch swallowing errors stopped swallowing, infinite retry loop, bad deploy amplifying error rate, etc.) — not "pay Sentry more". At $160, the remediation is **fix the code**, not raise the cap. Sentry org-level spend cap enforces this programmatically (auto-stops event ingestion past ceiling). See §Alerting below for the $120/mo 75% warning that precedes the cap.

## DSN strategy

**CONTEXT.md D-02 Option A locked:** single Sentry project named `mint` with events tagged via the `environment` attribute set to `development` / `staging` / `production`.

**Wiring:**
- **Mobile** reads `SENTRY_DSN` via `--dart-define=SENTRY_DSN=...` at build time. CI workflows `testflight.yml` + `play-store.yml` inject from GitHub secrets per the existing pattern (Plan 31-00 Task 1 inventoried the existing secret).
- **Backend** reads `SENTRY_DSN` from Railway environment variable — already set on both staging (`mint-staging.up.railway.app`) and production (`mint-production-3a41.up.railway.app`) environments.
- **Environment tag** on mobile comes from `--dart-define=MINT_ENV=staging` (default production when unset) via the existing `MintEnv.current` resolver (Plan 31-01 Task 2 confirmed). Backend resolves from the Railway service environment (existing `Settings.environment` field in `services/backend/app/core/config.py`).

**Three-way environment tag values:** `development` (local + simulator `--dart-define=MINT_ENV=development`) / `staging` (simulator + TestFlight pointing at Railway staging) / `production` (prod TestFlight + Play Store release).

**Why NOT Option B (2 separate projects `mint-staging` + `mint-production`):** Julien is solo-dev. 2 projects doubles:
- Alert rule configuration (each rule duplicated per project).
- DSN token rotation work (2 sets of secrets to rotate).
- Dashboard context switching (no cross-project query unless dashboards are rewritten per-project).
- Trace stitching burden (cross-project trace propagation works within an org but UX is cleaner with a single project + env filter).

Env tag is the Sentry-native mechanism for this separation, supports all alert/filter/dashboard queries, and costs zero extra infrastructure. Option A is the industry default for solo-dev and small-team orgs.

**DSN secret paths:**
- `SENTRY_DSN_STAGING` — Railway env var (staging service) + macOS Keychain on dev host for walker.sh local builds.
- `SENTRY_DSN_PROD` — Railway env var (prod service) + **not** on dev host (production DSN never leaves CI + Railway).
- `SENTRY_DSN_MOBILE` — GitHub Actions secret, injected via `--dart-define` in `testflight.yml` and `play-store.yml` at build time. Same DSN is used for mobile targeting this one project; env disambiguation happens via the `MINT_ENV` dart-define.

## Quota projection

5 000 MAU × 30-day month × current locked sample rates (CONTEXT.md D-01 Option C + existing CTX-05).

| Product | Sample rate (prod) | Projected volume/mo | Included in Business | Overage risk |
|---------|--------------------|---------------------|----------------------|--------------|
| Errors | 100% on crash (`onErrorSampleRate=1.0`) | ~2 000 | 50K base + prepaid raisable | $0 |
| Transactions (performance) | `tracesSampleRate=0.1` | ~50 000 | 100K | $0 |
| Replay (session) | `sessionSampleRate=0.0` (D-01 Option C prod) | 0 | 500 | $0 |
| Replay (on-error) | `onErrorSampleRate=1.0` | ~2 000 (shares Replay quota) | 500 | **Spike risk — see detail** |
| Profiling | `profilesSampleRate=0.1` | ~50 000 | 100K | $0 |

**Replay quota detail.** Prod `sessionSampleRate=0.0` means only error-triggered replays count against the 500-session inclusion. At 2k crashes/mo, the 500 inclusion covers ~25% of on-error replays; the other ~1 500 are overage candidates. Three mitigations stack:

1. **Sentry org spend-cap $160/mo** (Business tier feature). Hard stop regardless of any per-product overage math. This is the definitive ceiling.
2. **`onErrorSampleRate` knob.** If replay overage dominates the bill, lower `onErrorSampleRate` from `1.0` to `0.25` — captures one in four crashes instead of all of them. This is the first programmatic lever to pull.
3. **Phase 36 bare-catch migration (FIX-05).** Reduces error event volume at source — a bare `except:` that swallowed an exception today becomes a logged-and-surfaced error. The net volume post-FIX-05 drops because we stop double-firing Sentry events from code paths that previously retried silently.

**Staging: `sessionSampleRate=0.10` + `onErrorSampleRate=1.0`.** Debugging-friendly full-replay sample at low user count (~5 internal testers). Monthly projected cost impact: <$5 under Business-tier PAYG rates, negligible against the $80 base.

**Dev local: `sessionSampleRate=1.0` + `onErrorSampleRate=1.0`.** No quota impact (SDK writes to local DSN which is the staging project anyway; dev-host traffic is an order of magnitude below staging-tester traffic).

## Sample rate reference

Locked in `apps/mobile/lib/main.dart` per Plan 31-01 (env-dispatched via `MintEnv.current`):

| Option | prod | staging | development | Source |
|--------|------|---------|-------------|--------|
| `sessionSampleRate` | **0.0** | 0.10 | 1.0 | CONTEXT.md D-01 Option C |
| `onErrorSampleRate` | 1.0 | 1.0 | 1.0 | CONTEXT.md D-01 locked (crash-capture non-negotiable) |
| `maskAllText` | true | true | true | nLPD + OBS-06 kill-gate |
| `maskAllImages` | true | true | true | nLPD + OBS-06 kill-gate |
| `tracesSampleRate` | 0.1 | 0.1 | 0.1 | CTX-05 existing |
| `profilesSampleRate` | 0.1 | 0.1 | 0.1 | Aligned with traces, <5% frame budget impact per STACK.md |
| `sendDefaultPii` | false | false | false | nLPD mandatory (CTX-05 + backend parity) |
| `tracePropagationTargets` | narrow allowlist | narrow allowlist | narrow allowlist | Explicit: `api.mint.app`, `mint-staging.up.railway.app`, `mint-production-3a41.up.railway.app` — prevents leak to 3rd parties |

**Non-negotiable invariants** (enforced by `tools/checks/verify_sentry_init.py`):
- `sessionSampleRate=0.0` prod until OBS-06 audit signed + separate authorisation.
- `sendDefaultPii=false` in all envs both mobile + backend.
- `maskAllText=true` + `maskAllImages=true` in all envs (not just prod).
- `tracePropagationTargets` cannot be `.*` (wildcard would leak to 3rd parties).

## Alerting

- **Sentry org spend alert at $120/mo (75% of $160 ceiling)** — email Julien. Configured via Sentry UI → Organization Settings → Billing → Usage Alerts → "Alert when monthly spend exceeds $120". This is the first warning tier.
- **Phase 35 dogfood boucle** (future) invokes `tools/simulator/sentry_quota_smoke.sh` nightly and alerts if cumulative MTD usage exceeds 70% of monthly quota before day-20 of the month. This nightly pull is a preventive signal that complements the 75% Sentry-native email.
- **Calendar reminder Julien day-5 each month** — manual check via Sentry UI → Stats → Usage tab. The day-5 manual review catches anomalies that the nightly probe's heuristic might have missed (e.g., mid-month PAYG rate changes pushed by Sentry without an error-rate trigger).
- **Spend cap auto-stop at $160/mo** — Sentry org setting (Business tier feature). When the cap is hit, Sentry stops ingesting new events (drops them at the API edge, does not bill). This is a HARD stop — no bypass. The remediation on cap-hit is: investigate what drove the overage, fix the code, then either wait for the next billing cycle OR manually raise the cap if an ADR justifies it.

## Revisit triggers

Each trigger below, if fired, reopens D-04 for re-evaluation and may cascade into CONTEXT.md revision or an ADR:

1. **MAU > 10 000** — the Business tier's 50K error inclusion still holds but the quota headroom shrinks. Re-evaluate whether to (a) stay on Business + prepay additional data volume, or (b) upgrade to Enterprise for TAM + dedicated support + custom volume pricing. Also re-evaluate `tracesSampleRate` — at 10k MAU × 0.1 rate = 100k txns/mo exactly matches the Business inclusion, so any spike overflows.
2. **>3 overage months consecutive** — systemic signal that the sampling regime is mis-calibrated. Descope path: drop `onErrorSampleRate` from `1.0` to `0.25` (fewer replays on crashes) OR remove Replay entirely (set both replay rates to `0.0`) until the overage source is fixed. The descope is a lever, not a permanent setting.
3. **A1 critical found (PII leak in replay frame)** — nLPD incident. Immediate action:
   - Flip `sessionSampleRate=0.0` AND `onErrorSampleRate=0.0` in prod via code + hotfix deploy.
   - Re-audit [`SENTRY_REPLAY_REDACTION_AUDIT.md`](./research/SENTRY_REPLAY_REDACTION_AUDIT.md) — identify the leaking surface, add mask wrapper, re-run simulator walkthrough.
   - File nLPD incident per legal playbook.
   - Only re-enable `onErrorSampleRate>0` after re-audit signed.
4. **Sentry pricing changes by >20%** — either base $/mo OR included quota per dollar. Auto-detected at next quarterly re-fetch (commit `SENTRY_PRICING_YYYY_MM.md` + diff against `SENTRY_PRICING_2026_04.md`). If triggered, update CONTEXT.md D-04 anchor values, recompute this budget artefact, and — if the $160 ceiling no longer covers baseline + 2× spike — raise an ADR before touching prod sample rates.

## Secrets inventory

| Secret | Location | Scope | Rotation | Notes |
|--------|----------|-------|----------|-------|
| `SENTRY_DSN` (backend) | Railway env var (staging + prod) | per-environment | Annual | Set manually per service in Railway UI. Existing from CTX-05. |
| `SENTRY_DSN_MOBILE` | GitHub Actions secret | CI-only | Annual | Injected via `--dart-define=SENTRY_DSN=...` in `.github/workflows/testflight.yml` + `play-store.yml`. |
| `SENTRY_AUTH_TOKEN` | Dev host macOS Keychain + GitHub Actions secret | CI + dev-host CLI | Annual | Scopes: `org:read project:read event:read` (read-only). Provisioned per Plan 31-00 Task 1. Used by `tools/simulator/sentry_quota_smoke.sh` (this plan Task 2) and Phase 35 dogfood nightly. |

**Invariants (grep-enforceable):**
- No raw DSN value in any file under `.planning/`, `docs/`, or source code. Env-var names only.
- No `SENTRY_AUTH_TOKEN` value ever printed to stdout/stderr by any tool. Scripts echo `(present, length=N)` when debug output is needed.
- No secrets in `.env.example` files. Example files document variable names with placeholder values like `<your-sentry-dsn>`.

## Related artefacts

- [`.planning/research/SENTRY_PRICING_2026_04.md`](./research/SENTRY_PRICING_2026_04.md) — pricing fetch proof, A3 assumption mitigation. VERIFIED at fetch date 2026-04-19 (Business = $80/mo confirmed).
- [`.planning/research/SENTRY_REPLAY_REDACTION_AUDIT.md`](./research/SENTRY_REPLAY_REDACTION_AUDIT.md) — OBS-06 kill-gate. Signed `automated (pre-creator-device) — 2026-04-19` (Plan 31-03). Any `sessionSampleRate > 0` decision in prod requires this artefact re-signed + fresh device walkthrough.
- [`.planning/research/CRITICAL_JOURNEYS.md`](./research/CRITICAL_JOURNEYS.md) — 5 named transactions allowlist (A6 over-instrumentation mitigation). Shipped in Plan 31-03 Task 1. Any new `mint.journey.<name>` beyond the allowlist requires an ADR + an update to this file bumping the count.
- `tools/simulator/sentry_quota_smoke.sh` — the live quota probe operationalising the nightly half of the Alerting section above. Upgraded from stub in this plan Task 2.
- Future: `TRACE_PROPAGATION_TEST.md` — optional follow-up artefact from Plan 31-02 if a full real-HTTP round-trip test is ever productionised. Not shipped in Phase 31; linked here for forward reference.

## Sign-off

owner: julien | reviewed: claude-planner (Phase 31 OBS-07)

---

*Locked: 2026-04-19 per CONTEXT.md D-02 Option A + D-04.*
*Next review: 2026-07-19 (quarterly cadence) OR on any trigger firing above.*
