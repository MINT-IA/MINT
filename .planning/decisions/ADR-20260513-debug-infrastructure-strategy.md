---
date: 2026-05-13
status: Proposed
authors: Claude (Opus 4.7, 1M ctx) + 5-expert panel
panel: 5-pers — mobile-obs / E2E-reliability / fintech-architecture / Swiss-compliance / critical-PM
supersedes: —
superseded_by: —
description: 5-day plan — close Tier 2, ship Sentry v0 + Maestro stall detector + minimal cassure classifier, then STOP and ship TestFlight
related:
  - .planning/decisions/ADR-20260223-unified-financial-engine.md
  - docs/AGENTS/flutter.md
  - apps/mobile/lib/debug/debug_server.dart
  - apps/mobile/pubspec.yaml
---

# Debug infrastructure strategy — finish what's open, add the cheapest 80%-value layer, then ship

## TLDR

We close Tier 2 with the 3 review fixes, wire `sentry_flutter` + backend `sentry_sdk` (EU region, PII-scrubbed, mint_request_id-tagged), add a Maestro stall-detector + minimal cassure classifier, then HARD STOP debug infra investment and ship TestFlight. Total budget : 5 dev-days. Anything more buys instrumentation for users who do not yet exist.

## Context

Julien asked « build the best possible debug infrastructure for MINT. » Five experts panelled in parallel (mobile-obs, E2E-reliability, fintech-architecture, Swiss-compliance, critical-PM) returned with strong convergence on 3 priorities and one strong dissent (PM challenger : « observability for an app with no observers »).

Current state :
- Tier 1 obs spine (X-MINT-Req-Id correlation) MERGED — PR #592.
- Tier 2 `/debug/state` HTTP endpoint pushed on `feature/S97-tier2-debug-state-endpoint`, code-review complete (3 Critical to fix), PR not yet opened.
- `sentry_flutter: 9.14.0` installed in pubspec, **NOT wired**. Backend has no Sentry.
- Maestro arsenal (~6 walker scripts) battle-tested but no stall detection — last session lost 30 min on `bo1o442ww` silent hang.
- No crash reporting in flight today → every TestFlight crash will be invisible.

## Decision

### Phase 1 — Close Tier 2 (Day 0, ~3-4h)
Fix C1 (delete `_logsSurface` + `debug_log_zone.dart` — out of Tier 2 scope, dormant PII trap), C2 (emit real `file.path` + iOS-sim retrieval doc), C3 (write `tools/checks/no_debug_endpoint_in_release.sh` + wire in `testflight.yml` after `flutter build ios --release`, before Fastlane sign+upload — lefthook is the wrong integration point because there's no release binary at commit time). Open PR. Merge.

### Phase 2 — Sentry v0 (Day 1, ~1 dev-day total)
**EU region (Frankfurt) selected at org creation — irrevocable.** Per Swiss-compliance panel : non-negotiable for Swiss data-residency defence.

Mobile (`apps/mobile/lib/main.dart`) :
```dart
SentryFlutter.init((options) {
  options.dsn = const String.fromEnvironment('SENTRY_DSN');
  options.release = '<bundleId>@<version>+<build>';
  options.environment = const String.fromEnvironment('SENTRY_ENVIRONMENT', defaultValue: 'staging');
  options.tracesSampleRate = 0.2;
  options.profilesSampleRate = 0.0;          // OFF v0
  options.attachScreenshot = false;          // PII surface — CHF amounts on screen
  options.attachViewHierarchy = false;       // PII surface — field labels + values in JSON dump
  options.sendDefaultPii = false;            // LSFin hard-required
  options.beforeSend = _mintBeforeSend;      // strips IBAN/AVS/email/phone/Claude payloads
  // Session Replay : DISABLED v0 — defer to post-TestFlight with masking allow-list
}, appRunner: () => runApp(const MintApp()));
```

Wire `mint_request_id` tag in `MintHttpClient.send` :
```dart
Sentry.configureScope((s) => s.setTag('mint_request_id', requestId));
```

Backend (`services/backend/app/main.py`) :
```python
sentry_sdk.init(
    dsn=os.getenv("SENTRY_DSN_BACKEND"),
    environment=os.getenv("RAILWAY_ENVIRONMENT", "staging"),
    traces_sample_rate=0.1,
    profiles_sample_rate=0.0,
    send_default_pii=False,
    before_send=_mint_before_send_backend,   # SCRUB_PATTERNS regex set
    integrations=[FastApiIntegration(transaction_style="endpoint")],
)
```

Wire `set_tag('mint_request_id', request_trace_id)` in existing `LoggingMiddleware`.

Fastlane dSYM upload in `testflight.yml` post-`build_app`. Add to App Store Privacy Nutrition Label : « Diagnostics → Crash Data → App Functionality, Not linked to user ».

`_mintBeforeSend` regex (per Swiss-compliance panel) :
- `\b756\.\d{4}\.\d{4}\.\d{2}\b` → `<<AVS>>`
- `\bCH\d{2}[ ]?(?:\d{4}[ ]?){4}\d{1}\b` → `<<IBAN_CH>>`
- `[\w.+-]+@[\w-]+\.[\w.-]+` → `<<EMAIL>>`
- `(\+41|0041|0)[\s]?[1-9]\d(?:[\s.-]?\d{2,3}){3}` → `<<PHONE_CH>>`
- Drop entire string if key matches `^(prompt|completion|messages|response|coach_text|claude_.*)$` — Claude payloads are forbidden class.
- Run `check_banned_terms()` MCP as second-line; if a banned term survives, strip + tag `lsfin_leak_detected: true`.

**Acceptance evidence** : deliberately throw an exception in a dev build → event lands in Sentry EU with `mint_request_id` tag → click trace → Railway backend logs filtered by same trace_id show matching request.

### Phase 3 — Maestro stall detector (Day 2 morning, ~4h)
Extend `walker.sh` with watchdog (per E2E expert recipe) :
```bash
MAESTRO_HARD_LIMIT=${MAESTRO_HARD_LIMIT:-900}  # 15 min
STALL_PROBE_INTERVAL=30
( while sleep $STALL_PROBE_INTERVAL; do
    [ -f "$DEBUG_OUT/last_screen.png" ] && find "$DEBUG_OUT" -newer /tmp/.maestro_alive -type f | grep -q . \
      || { echo "[stall] auto-dumping"; "$REPO/tools/debug/cassure-classifier.sh" --stall; kill -TERM "$MAESTRO_PID"; exit 124; }
    touch /tmp/.maestro_alive
  done ) &
timeout --kill-after=30 "$MAESTRO_HARD_LIMIT" maestro test "$@" & MAESTRO_PID=$!
wait $MAESTRO_PID
```

**Acceptance evidence** : run a deliberate-hang Maestro flow, watchdog fires at 30s, cassure-classifier produces report, Maestro killed, exit 124.

### Phase 4 — Cassure classifier minimal (Day 2 afternoon, ~4h)
`tools/debug/cassure-classifier.sh` — bash only, NO LLM synthesis :
1. `curl /debug/state` snapshot → `cassure-report.json` (`{state, build, route}`)
2. `xcrun simctl spawn booted log show --predicate 'subsystem CONTAINS "mint"' --last 5m` → `oslog.txt`
3. If `REQ_ID` known : `railway logs --json | jq 'select(.trace_id == "...")'` → `backend.json`
4. `git log --since="2 hours ago" --name-only` → `blast_radius.txt`
5. Heuristic match : if `state.prefs.anonymous_message_count != expected` → hypothesis « counter not persisted ». Etc.

**Acceptance evidence** : reproduce cassure #4 with classifier → report names `anonymous_chat_screen.dart` in blast_radius + correct hypothesis.

### Phase 5 — HARD STOP. Ship TestFlight (Day 3-5)
- pubspec version bump.
- 10 Maestro golden flows pass on Julien's physical iPhone (not just sim).
- App Store metadata, screenshots, privacy nutrition label.
- dev → staging merge → testflight.yml fires.
- 20 beta invites sent.

### What we explicitly DO NOT BUILD
- Sentry Session Replay (defer post-TF, large PII surface).
- Backend distributed tracing UI (request-id tag suffices).
- Patrol migration (defer to v2.3+, MINT's Maestro stack works).
- Tier 3 endpoint expansion (more surfaces, admin endpoints).
- Second multi-panel audit on Tier 2 (this code review IS that audit).
- Self-hosted Sentry (justified only at FINMA pressure or Series A).
- Performance budgets in CI beyond existing Maestro frame-jank / cold-launch (Maestro already covers).

## Counter-arguments and data gaps

**Strongest opposing view (steel-manned).** The PM challenger's case : MINT has zero users. Sentry, classifier, stall detector are infra-org tools. The *real* bottleneck pre-TestFlight is shipping the app — Swiss compliance review, 18-life-event framing audit, App Store metadata, physical-device gold flows, beta recruiting. Two weeks of debug infra is borrowing against MINT's runway against a problem that may never materialize in its imagined form. Paul Graham's *Do Things That Don't Scale* applies : the asymmetric bet is ship → learn → iterate, not instrument an empty stadium. Honest reading : a 2-hour minimal `sentry_flutter` init + nothing else covers the actual TF-readiness bar. Everything beyond that is engineer-showpiece.

**Why we still ship the plan above (not the 2-hour minimum).** Three reasons : (1) Sentry minimal alone gives crash reporting but not the request-id correlation that makes a crash diagnosable in <10 min — and the wiring delta is half a day, not a week ; (2) the stall detector specifically recovers 30 min lost *today* on cassure #7 hunt — pre-TF Julien still iterates on cassures heavily ; (3) the classifier is 4h and compounds with #1 + #2 for every future cassure. We accept the PM challenger's framing on Phase 5 hard stop : once these 4 phases close, no more debug infra until paying users exist.

**What this decision does not address.**
- We have no measurement of how often Maestro actually stalls — `bo1o442ww` is n=1. The stall-detector ROI assumption (« 30 min recovered per stall ») may be wrong if stalls are rare.
- No data on whether Julien (or Claude-as-agent) will actually open `/debug/state` ≥5 times in the next 4 weeks. If not, Tier 2 is a museum exhibit (fintech-architecture panel call).
- Sentry quota burn rate at TestFlight scale unknown — free tier holds to ~500 DAU per Sentry-expert panel ; not validated for MINT's chatty client.

**What would change this conclusion.**
- If Julien onboards 20 beta users in week 1 and ≥3 hit silent crashes Sentry catches : Phase 2 was clearly worth it ; consider modest Phase 6 (alerting rules, release-health Slack ping).
- If Maestro never stalls again in next 5 walker runs : Phase 3 was overkill ; demote to a Linear ticket, do not maintain.
- If a Swiss user reports a leaked banned-term in a Sentry event : `beforeSend` regex insufficient — escalate to whitelist-only payload model, possibly self-hosted Sentry.
- If FINMA changes its FinTech licence guidance to require in-country observability data : re-litigate self-host vs SaaS.

## Sources

- Code-review subagent on PR `bac24a58` (in this session)
- Mobile-obs expert subagent (Sentry Flutter docs, sentry.io/pricing, Sentry EU FAQ, sentry-fastlane-plugin)
- E2E-reliability expert subagent (Maestro issues #1252 #2628 #3254, Patrol docs, Maestro flaky-tests playbook)
- Fintech-architecture expert subagent (Sauce Labs 2026, Embrace mobile obs, Honeycomb APM, Monzo/N26 eng blogs)
- Swiss-compliance expert subagent (nFADP, FinSA Art. 7-10, Sentry DPA 5.1.0, Swiss-US DPF adequacy, EDOEB, Apple TN3179)
- Critical-PM challenger subagent (Karpathy #2 from CLAUDE.md §7, Paul Graham *Do Things That Don't Scale*)
- /Users/julienbattaglia/Desktop/MINT.nosync/CLAUDE.md §7 #2 (Simplicity First), §9 (0-trust)
- Memory : feedback_zero_trust_protocol, feedback_critical_pm_mode, feedback_expert_panel_pattern, feedback_decisiveness, feedback_perimeter_5_gates
- Hand-off doc from prior agent session 2026-05-13 (post Tier 1 + Tier 2 push)

## Status & follow-up

- **Implementation tracking** : Phase 1 → PR on `feature/S97-tier2-debug-state-endpoint` ; Phases 2-4 → 3 atomic PRs on `feature/S98-debug-infra-v0` (or split per phase if CI gets noisy).
- **Re-litigation triggers** :
  - First TestFlight crash invisible to Sentry → Phase 2 incomplete.
  - Maestro stalls > once/week post-Phase 3 → revisit Patrol migration.
  - Anthropic releases EU residency for Claude API → re-evaluate sub-processor declaration.
  - 100 DAU reached → re-open « scale-out observability » ADR (alerting rules, release-health gating).
- **Hard stop signal** : after Phase 5 ship, NO new debug-infra phase without an explicit Julien decision linked to a real user-reported issue.
