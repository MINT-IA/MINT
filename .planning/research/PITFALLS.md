# Pitfalls — MINT v2.8 "L'Oracle & La Boucle"

**Domain:** Observability + workflow refonte on a Swiss fintech codebase already wounded by facade-without-wiring, silent catches, and context-poisoned agents
**Researched:** 2026-04-19
**Scope:** Only pitfalls specific to MINT in its current state (388 bare catches, 42K LOC recently excised, Wave C in flight, creator-async device gate, 1-person team)
**Panel:** ex-Stripe SRE (observability failures), ex-Monzo mobile QA (dogfood loops), ex-Cleo prompt engineer (guardrail theater), ex-Apple HI (polish→scope-creep drift)

**Confidence:** MEDIUM — internal doctrine (memory.md) is HIGH; external practices cross-referenced from training data, not fetched fresh. Treat named vendor claims (Sentry tiers, etc.) as "verify before committing budget".

---

## How to read this file

Every pitfall below has:
- **Warning sign** — the earliest observable signal that this pitfall is landing
- **Prevention** — concrete, implementable action (not "be careful")
- **Phase owner** — which of Phases 31–36 must address it (a phase only "owns" a pitfall if it can actually neutralise it there; later phases may inherit)

**Cross-cutting doctrines that rule every pitfall below:**
- _Tests green ≠ app functional_ → no green suite exempts a pitfall from device walkthrough
- _Façade sans câblage_ → every observability / flag / guardrail must be proven wired end-to-end, not just present
- _No shortcuts, no sentinel values_ → a "best-effort" fallback is a pitfall unless it is documented + logged + flagged
- _Audit means audit, not fix_ → Phase 32 mapping must NOT mutate routes; it reports

---

## A. Phase 31 — Instrumentation pitfalls

### A1. Sentry Replay leaking nLPD-regulated data despite `maskAllText`

**What goes wrong:** Sentry Replay mobile SDK masks text input but canvas, custom CustomPainter widgets (MINT uses them for all charts), native platform views (VisionKit doc scanner preview), and any widget drawn outside the Flutter text tree leaks verbatim. MINT screens routinely render salary, LPP avoir, IBAN-via-OCR, AVS number inside CustomPainter-rendered bars, rings, arbitrage side-by-side panels. Replay ships the masked video to Sentry's US+EU infra. That is one user complaint → FINMA visit.

**Warning sign:** A single Replay session where a developer, on staging with `julien+test@…`, can re-play a sim session and read _any_ rendered number on their laptop. If the reviewer reads a CHF amount on screen, that same number is exiting the device in production.

**Prevention:**
1. Before flipping prod flag, run a **Replay redaction audit** on staging: record 30 min across 20 screens that contain financial numbers (Aujourd'hui insights, Arbitrage, Retraite projections, Scan review, Budget chips, Coach premier éclairage). Open each replay in Sentry UI. For each frame where a number is legible → add the widget to a `MintPrivacyMaskWidget` allowlist OR wrap in `SentryMask` / `SentryUnmask` boundary.
2. **Default-deny canvas**: Sentry Replay Flutter supports `maskAllImages: true` and `maskAllText: true`, but CustomPainter is NOT text — wrap every `CustomPaint` in the app with a `SentryMask` widget by default, then selectively `SentryUnmask` non-sensitive chrome (headers, spacers).
3. **Prod flag gated on audit sign-off**: `sentry_replay_enabled` flag stays OFF in prod until a dated audit report (`.planning/research/SENTRY_REPLAY_REDACTION_AUDIT.md`) lists every screen × "verified masked" with a Julien signed-off commit.
4. **Server-side PII scrubbers** in Sentry org settings for strings matching `CHF-\d`, `\d{3}\.\d{3}`, IBAN regex, AVS regex (`756\.\d{4}\.\d{4}\.\d{2}`). This is belt + suspenders to client masking.
5. **EU data residency** — Sentry EU region mandatory; no US data plane. Verify in SDK init and on Sentry org config screenshot.

**Phase ownership:** 31 (redaction audit + masks). **Must not ship Phase 31 without audit report committed.**

---

### A2. Sentry quota explosion from Replay + Profiling + Breadcrumbs

**What goes wrong:** Replay at 10% sample on 5k MAU = ~500 sessions/day average 3 min each = ~45k session-minutes/month. Sentry Team plan ($26/mo) includes **50 replays/month**. Business plan ($80/mo) includes **500**. Above that, overage pricing. Adding profiling + breadcrumb volume + backend Python transactions and the bill quietly 10×. Solo dev doesn't notice until invoice.

**Warning sign:** Sentry usage page shows >60% quota consumed before day 15 of the month, or ANY billing alert email. For replays specifically: even at `replaysSessionSampleRate: 0.1`, 5k MAU × 20 sessions/month = 10k × 10% = 1000 replays/month — already 2× Business plan.

**Prevention:**
1. **Verify pricing before committing** — Sentry pricing changes; WebFetch https://sentry.io/pricing/ at Phase 31 start and commit the screenshot into `.planning/research/SENTRY_PRICING_2026_04.md`. Do NOT rely on training data numbers.
2. **Sample aggressively on Replay**: session sample 10% is too high for 5k users. Start at `replaysSessionSampleRate: 0.02` (2%) + `replaysOnErrorSampleRate: 1.0` (always capture replay on crash). That converts Replay into an error-driven tool, not an ambient one.
3. **Opt-in Replay for Julien/test cohort only in Phase 31** (flag `sentry_replay_enabled` cohort = `{beta, internal}`), expand gradually. Wave C scan-handoff doesn't need Replay for 100% users.
4. **Budget alarm**: Sentry spend-cap set at 2× expected monthly, not unlimited. And a calendar reminder day-5 of each month to eyeball usage.
5. **Trim breadcrumbs**: default 100 breadcrumbs is fine; don't raise. Custom `beforeBreadcrumb` filters out PII fields (`profile.*`, `salary_*`, `iban_*`).

**Phase ownership:** 31 (sampling rates, flag cohort) + 35 (dogfood loop monitors Sentry usage daily — see E7).

---

### A3. Global error boundary + `runZonedGuarded` → double-logging OR accidental swallow

**What goes wrong:** MINT currently has 332 mobile bare catches. Phase 31 will add `FlutterError.onError` → Sentry and `runZonedGuarded` → Sentry. If the existing catches are not updated in the same phase, you get:
- **Double-log**: catch block calls `Sentry.captureException(e)`, then `rethrow`, then the outer zone catches again → 2 events per error, quota × 2, dashboard noise.
- **Accidental swallow**: a Phase 36 refactor replaces `catch { }` with `catch (e) { logger.error(e) }` but forgets `rethrow` → UI silently continues in broken state (worse than a crash you can see in Sentry).
- **Order-of-interception bug**: `PlatformDispatcher.instance.onError` was introduced in Flutter 3.3 and must be set BEFORE `FlutterError.onError`. Getting the order wrong drops async platform errors entirely on iOS.

**Warning sign:**
- Sentry inbound shows the same error twice within 50ms (different stack, same `transaction_id`)
- A user-reported crash does not appear in Sentry at all despite boundary "active"
- Local debug session shows `flutter: Another exception was thrown` in console but Sentry is empty

**Prevention:**
1. **Single entry contract**: exactly one file `lib/services/error_boundary.dart` wires `FlutterError.onError`, `PlatformDispatcher.instance.onError`, and `runZonedGuarded`. No other file calls `Sentry.captureException` directly. Enforced by `tools/checks/sentry_capture_single_source.py` — grep for `Sentry.captureException` outside the boundary file → fail.
2. **rethrow discipline**: the boundary `captureException`s then **does not swallow** — it lets the framework continue its normal error flow (red screen in debug, error-handling widget in release). The only place swallowing is legal: UI fallback widgets that render a "something broke" surface, which MUST tag the event with `swallowed: true`.
3. **Catch-audit lint runs FIRST, instrumentation SECOND**: Phase 31 order is (a) ban new bare catches (b) install boundary (c) then Phase 36 migrates the 388 existing catches. Doing it in reverse means you instrument a codebase that still has 388 black holes.
4. **Zone-init ordering smoke test**: a Dart unit test that mocks `PlatformDispatcher.onError` and `FlutterError.onError` and asserts the boundary sets them in the right order, captures once, and doesn't swallow.

**Phase ownership:** 31 (boundary + ordering) + 34 (lint ban on new catches) + 36 (migration of the 388).

---

### A4. Trace_id round-trip broken by Railway / Cloudflare proxy

**What goes wrong:** Mobile generates W3C `traceparent: 00-<trace_id>-<span_id>-01`, sends to `https://mint-staging.up.railway.app/api/v1/coach/chat`. Railway's edge proxy and any Cloudflare tier in front strip or rename headers. Backend's Sentry SDK sees no trace_id → generates a fresh one → mobile errors and backend errors appear in Sentry as two unrelated events. The whole point of Phase 31 (mobile↔backend correlation to diagnose in < 60s) collapses silently.

**Warning sign:**
- In Sentry Performance view, a mobile transaction `coach_chat_send` has no linked backend transaction
- Backend `sentry_sdk.get_current_span().trace_id` logged on request start is different from what mobile sent
- A single user-reported bug requires you to search 2 Sentry projects by timestamp

**Prevention:**
1. **Explicit header test in CI**: a pytest that hits staging (not localhost) with `traceparent` header and asserts the backend logs the same trace_id. Not a mock. A real HTTP call.
2. **Fallback custom header**: send `X-MINT-Trace-Id` in parallel with `traceparent`. If W3C strips at proxy level, the custom header (non-standard name → no proxy knows to strip) survives. Backend reads either.
3. **Document proxy behavior**: Phase 31 deliverable includes `.planning/research/TRACE_PROPAGATION_TEST.md` with actual curl output from prod showing the headers that arrive at the FastAPI layer. No wishful thinking.
4. **Breadcrumb the trace_id in MINT's own structured log**: even if Sentry linking breaks, `mint_log.info("coach_chat_send", trace_id=X)` on both sides gives a grep fallback.

**Phase ownership:** 31 (header propagation + test) + 35 (daily dogfood verifies a real session has linked traces in Sentry UI).

---

### A5. Catch-audit lint false positives that block legitimate patterns

**What goes wrong:** A grep-based `no_bare_catch.py` lint that fails CI on every `catch (e)` breaks:
- **Test mocks** that intentionally swallow in a mock's `when().thenThrow()` setup
- **Async generator cleanup**: `await for (final item in stream) { ... } ` where the cancel path uses `catch`
- **Third-party SDK wrappers** where the vendor SDK throws a typed exception we deliberately map to a domain event (Anthropic SDK 429 → degraded chip, not crash)
- **`rethrow;` patterns** where the catch exists to log + rethrow — already compliant, but a naive regex flags it anyway

Result: dev adds `// ignore_for_lint` comments everywhere, lint becomes noise, bare catches leak back in through a renamed exception parameter.

**Warning sign:** More than ~5% of flagged catches are marked `// lint-ignore` in the first week. Or dev posts in a PR "can we turn off this check for legitimate cases?" → you're already losing.

**Prevention:**
1. **AST-based, not regex**: use `analyzer` package lint rule, not `grep catch`. The rule checks: (a) `on ExceptionType catch (e)` with typed exception is OK (b) bare `catch (e)` without rethrow AND without `Sentry.captureException` AND without logging is the only failure pattern.
2. **Allowlist by path**: `test/**/*.dart` is exempt automatically. Mocks live there.
3. **Structured ignore syntax**: `// lint-ignore: bare-catch reason="Anthropic SDK 429 → degraded UX, logged via LLMRouter"` — parseable, auditable, greppable for reason clusters. Plain `// ignore` rejected by the lint itself.
4. **Weekly ignore-cluster review**: Phase 34 guardrail daily loop includes "grep for `lint-ignore: bare-catch` in codebase; if cluster by reason > 10 → investigate if the reason is actually legitimate or we built a loophole".

**Phase ownership:** 34 (lint implementation) + 36 (migration of 388 catches applies the rule honestly).

---

### A6. Over-instrumentation → signal drowned in noise

**What goes wrong:** Every `onTap`, every provider rebuild, every route change, every API call becomes a breadcrumb/event. In 7 days you have 10M events. Nobody can tell which `app.click.button` matters. Julien opens Sentry, sees a wall, closes tab. The whole Oracle thesis dies. Linear and Segment both publicly warned about this; Stripe has internal doctrine "instrument flows, not widgets".

**Warning sign:** Sentry dashboard shows > 1000 unique transaction names, OR the top-10-by-count is 100% low-value events (`provider_rebuild`, `route_push`), OR Julien says "I have Sentry open but I don't look at it anymore".

**Prevention:**
1. **Pick the 5 critical journeys at Phase 31 kickoff** and name them in a file: `.planning/research/CRITICAL_JOURNEYS.md`:
   - `anonymous_onboarding` (landing → felt-state pill → Coach MSG1 → first premier éclairage)
   - `coach_turn` (user types → backend → LLM → tool → response rendered)
   - `document_upload` (camera/pdf → Vision → DUR → render_mode bubble)
   - `scan_handoff_to_profile` (post-Wave-C) — confirm chip → CoachProfile merged → next session cites
   - `tab_nav_core_loop` (Aujourd'hui ↔ Coach ↔ Explorer, no RSoD)
2. **Instrument only those 5 with named transactions**. Everything else defaults to Sentry auto-instrumentation (fine-grained but not named — low signal).
3. **Every new transaction name requires a PR justification** tagged `# instrumentation` — lefthook check rejects a diff that adds `Sentry.startTransaction` with a name not in the allowlist unless commit message contains `instrument: <journey_name>`.
4. **One consolidated dashboard**, not five. See G4.

**Phase ownership:** 31 (pick journeys) + 35 (daily loop uses them as dogfood scenarios — journeys ARE the script).

---

## B. Phase 32 — Cartographie pitfalls

### B1. Screen board goes stale, displays confident-but-wrong status

**What goes wrong:** `/admin/routes` proudly shows `✓ Green, last verified 2026-04-19` but the screen hasn't actually been opened since Phase 32 shipped 3 weeks ago. A silent regression makes the screen crash → Julien trusts the green → doesn't check → user hits it. This is the facade-without-wiring pattern on the _meta layer_ (oracle lying about its own freshness).

**Warning sign:**
- Any row in `/admin/routes` with `last_verified` older than 7 days displayed without a visual distinction
- A user reports a crash on a route `/admin/routes` marked green
- Julien opens `/admin/routes` and has to remember "is this fresh?" — if he has to think, it's already broken

**Prevention:**
1. **Staleness is a status**, not a footnote. Statuses: `green-fresh` (verified ≤ 3d), `yellow-stale` (verified ≤ 14d), `grey-unverified` (> 14d or never). Visual treatment distinct per status. A yellow-stale route = treated as yellow in any aggregate metric.
2. **Auto-refresh via dogfood loop (Phase 35)**: every `mint-dogfood` run touches N routes → updates `last_verified` for those routes. After 30 days of healthy dogfood, the whole critical set is always fresh.
3. **Explicit refresh CTA in admin**: "Mark verified" button next to each row → commits a timestamp + optional screenshot. This gives Julien a fast path to restamp after a manual device session.
4. **Alert if critical journey > 7d stale**: the 5 critical journeys from A6 get a Slack/push notif if any of them goes > 7d without verification. Others age silently.

**Phase ownership:** 32 (status model + staleness logic) + 35 (dogfood auto-refresh).

---

### B2. Screenshots bloat repo → git operations slow → devs stop committing screenshots → staleness returns

**What goes wrong:** 300 screenshots × 500KB = 150MB in git. After 6 months, repo is 1GB+, `git clone` takes 3 min, `git status` slows, Julien on a bad WiFi hates working on it. Dev "solves" this by stopping committing screenshots. Board status regresses to B1.

**Warning sign:**
- `git count-objects -v` shows `size-pack` > 200MB
- `.planning/research/screenshots/` or `.planning/dogfood/screenshots/` > 100MB
- A dogfood PR includes 0 screenshots with a commit message "skipped screenshots to keep PR small"

**Prevention:**
1. **Never commit PNG/JPG to repo** for dogfood/screen-board screenshots. Either:
   - **Sentry attachments**: attach screenshot to the Sentry event/session (Replay already captures this if enabled). Zero repo bloat.
   - **Google Cloud Storage bucket** (`gs://mint-dogfood-screenshots/YYYY-MM-DD/`) with a public-read but unlisted naming scheme + lifecycle rule delete after 60 days.
2. **`.gitignore` enforces**: `*.png` and `*.jpg` under `.planning/dogfood/**` and `.planning/research/screenshots/**` are gitignored. Markdown files reference screenshots by GCS URL or Sentry URL.
3. **Repo size CI check**: `tools/checks/repo_size_guard.py` fails if pack size > 300MB.
4. **Always WebP**, never PNG — if a screenshot absolutely must land in repo (rare, e.g., DESIGN_SYSTEM.md diagram), convert to WebP, < 80KB.

**Phase ownership:** 32 (decide storage strategy) + 35 (dogfood loop uses the chosen strategy from day 1, never PNGs in repo).

---

### B3. `/admin/routes` leaks in production via flavor/dart-define misconfig

**What goes wrong:** Developer gates with `if (kDebugMode)`. Release builds compile-out the gate. Good. Then someone needs "staging QA mode" so adds `--dart-define=ADMIN=1`. Someone reads a wrong guide and sets `ADMIN=1` in a TestFlight build. Now anyone with a TestFlight invite can see `/admin/routes` + `/admin/flags` + every route exposing internal state. GDPR + FINMA problem: admin surface is internal-only by design.

**Warning sign:**
- `grep -r "dart-define.*ADMIN" .github/workflows/` finds any occurrence outside a debug-only workflow
- A TestFlight release notes mentions "admin mode"
- Sentry sees a hit on `/admin/*` from a user_id that is not in the `{internal}` cohort

**Prevention:**
1. **Triple gate**, all three required:
   - Compile-time: `const bool kAdminEnabled = bool.fromEnvironment('ADMIN', defaultValue: false);`
   - Runtime build-flavor: only `dev` flavor compiles admin routes into the router. TestFlight/prod flavor = admin files excluded from source set.
   - Per-user token: admin routes also require `Authorization: Bearer <admin-jwt>` where the JWT claims include `role=admin` issued by a backend endpoint gated by Julien's email only.
2. **Verify via adversarial check**: Phase 32 deliverable is a pytest that:
   - Builds a prod APK
   - Greps the compiled Dart snapshot for the string `/admin/routes` → assert NOT found
   - Hits staging `/admin/routes` with a normal user JWT → assert 403
3. **Sentry alert on prod admin hit**: any Sentry event with `url` matching `/admin/*` AND `env=production` AND `user.role != admin` fires a PagerDuty/email alarm immediately.
4. **Never rely on `kDebugMode` alone**. That's the single-gate pattern that historically leaks.

**Phase ownership:** 32 (admin route build-flavor + triple gate) + 34 (lefthook refuses a commit that adds `kDebugMode` as sole gate on admin code — detect via analyzer rule).

---

### B4. Sunsetting 23 legacy redirects breaks external links (email, SEO, shared URLs)

**What goes wrong:** Wave E-PRIME culture is "delete the dead code". Wave C also. Phase 32 says "sunset the 23 redirects". Dev reads `redirect from /ask-mint to /home?tab=coach` → deletes the redirect → next day, a blog post from 2025 embedding `https://app.mint.swiss/ask-mint` 404s. User who bookmarked the old URL hits a dead end. Email campaign from last month points to `/coach/cockpit` → now bounces. This is reputation damage for zero codebase benefit.

**Warning sign:**
- Zero-hit check wasn't done before deletion
- Analytics shows any traffic on a sunsetted redirect in the 30 days prior
- A Sentry 404 spike 24-72h after a redirect is removed

**Prevention:**
1. **30-day dark + analytics window before removal**: for each of the 23 redirects:
   - Instrument it to count hits via Sentry metric or a simple backend counter
   - After 30 days with 0 hits → safe to remove
   - With ≥1 hit → keep the redirect, log the source (referrer), escalate to "why is this URL still in the wild?" (shared link? email? SEO?)
2. **Tombstone page, not 404**: if a redirect IS removed, replace with a landing page (`/sunset/ask-mint`) that says "cette page a changé — va sur Coach" and auto-redirects after 3s. Zero bouncers.
3. **Sitemap hygiene**: update `robots.txt` and XML sitemap before removing routes. Otherwise Google Search Console lights up with crawl errors for 3 months.
4. **Grep external surfaces**: before removing, grep:
   - `legal/`, `docs/`, `education/` for embedded URLs
   - any marketing repo / landing page
   - Julien's email-campaign tool (Mailchimp/Loops) for the URL in campaign templates

**Phase ownership:** 32 (30-day dark period starts Phase 32 entry; removal lands Phase 36 at earliest).

---

### B5. Static AST parser misses dynamic routes → board claims 100% coverage while missing 15% of real routes

**What goes wrong:** `mint-route-health` parses `app.dart` looking for `GoRoute(path: '/foo')` literals. Misses:
- `ShellRoute` with nested `routes:` list built from a map at runtime
- Routes registered conditionally behind a feature flag (`if (FeatureFlags.documentsV2) routes.add(...)`)
- String-interpolated paths (`path: '/profile/${userId}'`)
- Routes added by dynamic code paths (plugin, late init)

Result: the board shows "102/102 routes green" but the actual GoRouter instance at runtime has 118 routes — 16 are unmonitored, each a silent regression vector.

**Warning sign:**
- Runtime count `GoRouter.of(context).configuration.routes.length` != static-parse count
- A user reports a crash on a route that `/admin/routes` doesn't know about
- A flag-gated route becomes "invisible" when the flag is off

**Prevention:**
1. **Runtime enumeration, not static parse**: `/admin/routes` endpoint in mobile introspects `GoRouter.of(context).configuration` live and dumps the full route tree (recursive). Static parse is a fallback + CI-time check, not the source of truth.
2. **Reconciliation check**: CI test `test/integration/route_inventory_test.dart` builds the app, reads runtime routes, compares to the static docs list in `docs/SCREEN_INTEGRATION_MAP.md` → fails if delta > 0.
3. **Flag-gated routes explicitly listed**: the board shows flag-gated routes in `grey-gated` state even when flag is off, with metadata "gated by flag X, currently OFF". Invisible ≠ non-existent.
4. **Third-party / plugin routes enumerated too** (if any — MINT currently has none at runtime, but keep the check honest).

**Phase ownership:** 32 (runtime enumerator + CI reconciliation).

---

## C. Phase 33 — Kill-switch pitfalls

### C1. Flag rot: 8 flags → 20 flags → 100 flags, 0 ever removed

**What goes wrong:** v2.8 adds 1 flag per red route (call it 15-20 flags). v2.9 adds more. No flag is ever removed because "what if we need it again". In 6 months, feature_flags.dart has 100 entries, nobody remembers which are live, which are dead-with-code. Flags silently gate dead code. New dev can't tell if a route is "behind a flag we forgot" or "actually removed". This is the exact pattern that killed flag discipline at every company that adopted it without expiry.

**Warning sign:**
- Any flag in `feature_flags.dart` without `expires_at` metadata
- Any flag that has been at a constant value (true or false) for > 60 days
- `grep "FeatureFlags.foo"` returns 0 hits (flag defined, nobody reads it)

**Prevention:**
1. **Mandatory metadata at flag creation**:
   ```dart
   static const documentsV2 = FeatureFlag(
     key: 'documents_v2_enabled',
     defaultValue: false,
     owner: 'julien@mint.swiss',
     expiresAt: '2026-06-01', // required, not optional
     purpose: 'Kill-switch for Wave C scan-handoff pipeline',
     removePlan: 'Promote to always-on after 30 days of >99% success',
   );
   ```
   Compile-time assert: `expiresAt` required. No exceptions.
2. **Monthly flag review**: first Monday of each month, `tools/checks/flag_review.py` lists flags with `expiresAt < today + 14 days`. Julien reviews: promote (delete flag, code stays), demote (delete flag, code goes), extend (new expiry + reason in commit message).
3. **Flag-grep check**: CI gate refuses to ship if any flag is defined but has 0 reads in the codebase (`grep -r "FeatureFlags.X"` == 1 match which is the definition itself).
4. **Admin UI shows expiry**: `/admin/flags` colors rows by expiry proximity. Expired flags in red.
5. **No cohort management in v2.8**: flags are binary per-user-cohort `{internal, staging, prod}` — NOT percentage rollouts, NOT user segments. Complexity explicitly rejected for solo dev.

**Phase ownership:** 33 (expiry metadata + compile assert) + 35 (monthly review is scheduled recurring event).

---

### C2. Circuit breaker auto-off is too sensitive → user rage when a feature disappears

**What goes wrong:** Phase 33 wires "5 errors/h on route X → flag auto-off". Reasonable. But during a staging flake, transient Railway 503 spike, or normal user encountering an edge case 5 times in 1h (uncommon but possible), a feature disappears mid-session with no warning. User who was composing a premier éclairage dialogue loses the UI. Rage tweet, support ticket, churn.

**Warning sign:**
- Sentry shows a flag flip correlated with a non-incident (just a flaky deploy)
- A user report includes "feature disappeared while I was using it"
- Auto-off triggered > 1×/week on a stable flag

**Prevention:**
1. **Staged thresholds with gradient degradation**, not hard on/off:
   - Green: error rate < 1%
   - Yellow: 1-3% → log alert, keep feature on, show low-key degraded chip (ton italique `textSecondary` — already doctrine)
   - Orange: 3-5% → degraded mode (simplified version of feature)
   - Red: > 5% sustained 1h → flag auto-off BUT only for NEW sessions, existing sessions finish
3. **Min-sample guard**: auto-off requires N errors from N distinct users, not just N errors total. 5 errors from one looping user ≠ incident.
4. **Cool-down**: after auto-off, flag stays off for at least 30 min regardless of metrics. Prevents flapping.
5. **Dry-run in staging first**: every threshold change gets 48h in staging with a mock error stream before it applies to prod. Phase 33 exit criteria: "every auto-off threshold has been tripped intentionally on staging and observed to behave".

**Phase ownership:** 33 (gradient thresholds + cool-down) + 35 (dogfood loop simulates threshold trips weekly).

---

### C3. Flag change in staging ≠ prod propagation delay

**What goes wrong:** Backend serves `/config/feature-flags`. Mobile client caches the response 6h to reduce bandwidth. Admin flips `scan_handoff_enabled=false` at 10:00 on prod because a P0 is reported. Users who opened the app at 09:55 have the flag=true cached until 15:55. For 6 hours, the "kill-switch" doesn't kill. During that window, Sentry keeps collecting errors on a route Julien thinks is disabled.

**Warning sign:**
- Timestamp of admin flag flip vs first observed propagation in Sentry is > 5 min
- Multiple users crash on a "killed" feature after the flag flip
- Julien says "I turned it off but it's still happening"

**Prevention:**
1. **Cache TTL reduced to 60s** for `/config/feature-flags` response. Cost = slightly more backend calls; benefit = emergency kill actually works in < 1 min.
2. **Push on flip** (best): admin action triggers a server-push via websocket / Firebase Messaging / APNs silent push → mobile clients invalidate cache → refetch. Aim for < 10s propagation.
3. **Force-refresh on flag-gated route entry**: when user navigates to `/scan`, mobile does a blocking refresh of `/config/feature-flags` before deciding gate. Adds 100-300ms latency; worth it on high-risk routes. Low-risk routes keep the 60s cache.
4. **Verify in Phase 33**: admin flips flag on staging at T, measures propagation by flipping + refreshing an actual device, times to < 60s. Document in `.planning/research/FLAG_PROPAGATION_TEST.md`.

**Phase ownership:** 33 (cache TTL + push) + 35 (dogfood measures propagation weekly).

---

### C4. Resisting cohort management is correct but will be pressured to break

**What goes wrong:** Phase 33 ships binary per-route flags. Month 2, Julien wants "show X to 10% of users" for A/B. Month 3, "show Y only to Romands". Month 4, the flag system is LaunchDarkly in all but name, maintained by a solo dev, buggy, the opposite of the goal. Feature-creep on the flag system itself.

**Warning sign:**
- Any PR title with "percentage rollout" or "cohort" or "AB test" touching `feature_flags.dart`
- Any ADR proposing to extend flags beyond binary
- A request: "can we just add user_id matching to flags?"

**Prevention:**
1. **Doctrine written into `feature_flags.dart` header comment**: "v2.8 decision: binary per-cohort only {internal, staging, prod}. No percentage, no user-level targeting. If an A/B need arises, write an ADR with explicit trade-offs; default answer is no."
2. **ADR-required for any extension**: commit hook checks — if `feature_flags.dart` gains a field that wasn't in v2.8 baseline (e.g., `rolloutPercentage`), require a matching ADR link in the commit message.
3. **Kill old experiments**: adopt Monzo's policy — if an A/B experiment doesn't ship within 2 weeks of hitting the target, the flag is removed. No zombie experiments.

**Phase ownership:** 33 (doctrine in code) + 34 (lefthook ADR-required for flag schema changes).

---

### C5. `/admin/flags` becomes the main "debugging" tool — flags mask bugs instead of fixing them

**What goes wrong:** User reports bug. Dev flips flag off. "Fixed." Sentry error rate drops. Julien moves on. But the bug is still there, just hidden. Next time a related flag is flipped on, same bug re-appears in a different form. The flag became a bug-sweeping tool instead of an incident-kill tool. Cleo engineering culture knows this: flags must have a root-cause ADR attached when flipped off for > 48h.

**Warning sign:**
- Any flag flipped off in prod for > 48h without an associated P0/P1 issue with a fix plan
- `git log feature_flags.dart` shows more flag flips than fixes
- Julien can't answer "why is this flag off?" without reading history

**Prevention:**
1. **Flip → issue-required**: admin UI requires a linked issue URL when setting a prod flag to off. Metadata persisted in flag history.
2. **48h bounce-back rule**: a flag off > 48h in prod gets an automated Sentry alert "flag X off for 2 days — root cause fix status?". Forces decision: fix and flip back on, or remove feature entirely.
3. **Flag-off ≠ solution**: team doctrine in `docs/FLAGS_POLICY.md`: "flipping a flag off is an incident response, not a resolution. A flag at off > 1 week = P1 on the roadmap to either fix-and-restore or kill-and-remove."

**Phase ownership:** 33 (issue-link requirement) + 35 (weekly flag audit in dogfood loop).

---

## D. Phase 34 — Agent Guardrails pitfalls

### D1. lefthook > 5s → `--no-verify` abuse → gates become theatre

**What goes wrong:** lefthook runs flutter analyze (10s), pytest (30s), lint scripts (3s). Total: 43s per commit. Julien is mid-iterating on a UI tweak, needs 5 commits in an hour. Waits 4 minutes waiting on hooks. Types `git commit --no-verify`. Now gates don't fire. Next dev copies the pattern. Pre-commit becomes suggestion.

**Warning sign:**
- `grep "\\-\\-no\\-verify" .git/logs/HEAD` > 0 occurrences
- Any PR with a commit message followed by a "fix lint" commit 2 min later
- Julien says "these hooks are slow"

**Prevention:**
1. **< 5s total target**, enforced by measurement:
   - Run only on **changed files**: `flutter analyze --only-changed` (or call `dart analyze <changed-paths>`), pytest only on `services/backend/` if backend files changed, NOT on whole repo.
   - Parallel execution: lefthook `parallel: true` across independent hooks.
   - Skip heavy checks (flutter test full suite, pytest full suite) — those stay in CI, not pre-commit.
2. **Tier the checks**:
   - Pre-commit (< 5s): format, hardcoded-FR lint, bare-catch lint, accent lint, ARB parity lint, diff-scoped analyze
   - Pre-push (< 30s): scoped tests for changed areas
   - CI (any time): full suite
3. **Measure hook time**: `.git/hooks/post-commit` logs `hook_duration_ms` to a local file. Weekly dogfood report surfaces p95. If p95 > 5s → optimize before anything else in Phase 34.
4. **Smart skipping for WIP**: commits with message `wip:` skip heavy hooks by design (still run format). Signals intent, auditable.

**Phase ownership:** 34 (< 5s budget is the phase entry criterion).

---

### D2. `--no-verify` abuse monitor becomes blame theater OR is ignored

**What goes wrong:** Phase 34 adds post-commit that logs `--no-verify` usage. If it alerts Julien every single skip, signal noise — Julien mutes it. If it's silent, it's useless. If it's "shame" framed, creator-dev rejects (anti-shame is MINT doctrine).

**Warning sign:** Monitor fires > 5×/week without action OR monitor exists but nobody looks at it.

**Prevention:**
1. **Weekly digest, not per-event**: once a week, Julien gets a summary: "this week `--no-verify` used N times, here are the hooks that were skipped most often". If N > 3 → signals "a hook is too slow or too strict, let's fix the hook".
2. **Framed as hook-feedback, not dev-shame**: the digest's headline is "hook effectiveness score", not "Julien bypassed hooks X times". Goal: make bypasses actionable against hook quality, not against the human.
3. **Auto-disable abused hooks**: if a specific hook is skipped > 5×/week for 2 weeks running, auto-move it to pre-push (less friction) or CI-only. Self-healing.

**Phase ownership:** 34 (monitor + digest + auto-move).

---

### D3. Lint false positives on legitimate patterns → ignore explosion

**What goes wrong:** Same shape as A5 but cross-cutting. Examples:
- `hardcoded_fr_string` lint flags every `Text('...')` — but debug `print`s, logger calls, error messages to Sentry, internal enum toString are all legitimate non-i18n text
- Accent lint flags `catch (e)` where `e` isn't French but the regex is dumb
- ARB parity lint flags a key added to `fr` if the PR hasn't synced yet (legit WIP)

Dev adds `// lint-ignore` everywhere. Ignores cluster. Lints become weaker than before Phase 34.

**Warning sign:** `grep -r "lint-ignore"` growth rate > 10/week.

**Prevention:**
1. **Structured ignore** (same pattern as A5): `// lint-ignore: hardcoded-fr reason="Sentry error message, not user-facing"` — reason is required, grep-auditable.
2. **Scoped lints**:
   - `hardcoded_fr_string` only runs on `lib/screens/**` and `lib/widgets/**` (user-facing) — NOT on `lib/services/**` where it's mostly backend strings
   - Accent lint runs on `lib/**/*.dart` but excludes `.arb` files (they're already the source)
   - ARB parity runs only on PR, not on local commit (WIP tolerance)
3. **Ignore budget**: `tools/checks/ignore_budget.py` caps total `lint-ignore` at current-baseline + 10%. Going over requires a PR explanation.
4. **Quarterly ignore-cluster review**: bucket by reason; if top reason is "legitimate", relax the lint. If top reason is "fast-forward", tighten the lint.

**Phase ownership:** 34 (scoped lints + structured ignore + budget).

---

### D4. Proof-of-read becomes citation theater

**What goes wrong:** Agent must "prove it read CLAUDE.md" by citing 3 lines. Agent learns to paste `## 5. BUSINESS RULES`, `**Pillar 3a**:`, `**LPP art. 21-40**` — meaningless 3-line citation that satisfies the regex check. Passes. Agent still hallucinates constants because it didn't actually load the context meaningfully. Ex-Cleo pattern — they tried this and it failed in 3 weeks.

**Warning sign:**
- Citations cluster on the same 3-5 lines across commits (agents finding the "cheapest" passing citations)
- Constant-drift errors still land in code despite 100% pass rate on proof-of-read
- Agent-authored commits don't reference constants they touched

**Prevention:**
1. **Semantic proof, not lexical**: agent must answer a question derived from the code it's modifying:
   - "Your diff touches `avs_calculator.dart`. What section of CLAUDE.md governs AVS rente max, and what is that value?" → requires actually knowing, not pattern-matching
   - Question generation: AST diff parser → find touched symbols → map to CLAUDE.md sections via a keyword index → ask one question.
2. **Hash-of-read session token**: on session start, agent reads CLAUDE.md, tool returns a session hash. Agent includes hash in commit. Hash expires in 4h. No re-read required every commit, but session start is enforced.
3. **Partial re-read on section change**: if a commit touches code in `services/financial_core/`, agent must re-read Section 5 of CLAUDE.md (Business Rules) — not the whole file. Gets budget-efficient + context-fresh.
4. **Accept that this isn't fully preventable**: agents will always find some workaround. Pair proof-of-read with outcome checks (did the commit break constants? did tests catch it?) — belt + suspenders.

**Phase ownership:** 34 (semantic proof + session hash).

---

### D5. CLAUDE.md re-read on every commit → context window explodes → agent loses task context

**What goes wrong:** CLAUDE.md is ~500+ lines. Every agent commit re-reads it → 3k tokens of context burnt on boilerplate every turn → after 10 commits in a session, context buffer at 60k+ → agent starts forgetting task instructions → quality drops → creator sees "accents lost" style of degradation (already happened per memory).

**Warning sign:**
- Agent produces output that violates rules explicitly in CLAUDE.md even though CLAUDE.md is "in context"
- Agent forgets user's original instruction after N tool calls
- Sessions hit 100k tokens mid-task

**Prevention:**
1. **Session-hash strategy (D4 reused)**: read once per session, cache. Not per-commit.
2. **Sectioned re-read**: only read sections relevant to current diff. Use the keyword index.
3. **`/clear` between phases** (also G3): Julien issues `/clear` at phase boundary. Fresh context. New agent session reads CLAUDE.md once and starts clean.
4. **Context budget tracker**: `context-monitor.js` (already installed per memory) fires a behavioral tier change at 50k / 75k / 90k tokens. At 75k: agent must summarize task + `/clear`. At 90k: forced clear. This exists — Phase 34 formalizes it in pre-commit as a warning.

**Phase ownership:** 34 (session-hash + sectioned re-read) + cross-cut G3.

---

### D6. Guardrails break human commits from Julien typing directly

**What goes wrong:** Guardrails designed for agents treat all commits the same. Julien types a quick `git commit -m "wip"` on feature branch — hook slow, too strict, refuses a WIP commit. Julien frustrated. Disables guardrails locally. Now agents he spawns also bypass.

**Warning sign:**
- Julien's commit rate drops after Phase 34 ships
- Julien reports friction
- Commits from `julien.battaglia@gmail.com` disable or ignore hooks more than agent commits

**Prevention:**
1. **Human vs agent commit detection** via commit trailer: agents commit with `Co-Authored-By: Claude Opus ...` trailer. Humans don't. Hooks can behave differently.
2. **WIP bypass**: commit message starting `wip:` skips heavy checks (keeps format + bare-catch). Human-friendly escape hatch, auditable (wip commits MUST be squashed before merge).
3. **Branch-level relaxation**: on `feature/*` branches, hooks are stricter on agent commits, looser on human commits. On `dev`, strict for all.
4. **Measure creator friction**: dogfood loop includes a pulse question "did hooks annoy you this week?" — if yes > 2 weeks running, adjust.

**Phase ownership:** 34 (commit-author branching + WIP bypass).

---

## E. Phase 35 — Boucle Daily pitfalls

### E1. Dogfood fatigue: Julien skips, PRs pile up, loop dies in 2 weeks

**What goes wrong:** Solo dev team. Daily loop assumes Julien opens the app every day, reads the auto-PR, triages findings. Week 1: perfect. Week 2: 2 misses (travel, migraine, life). Week 3: 5 days missed, 5 PRs stacked, intimidating wall, Julien never opens them. Loop dies. Monzo (internally, from ex-QA) reports this happens to nearly every dogfood loop that isn't ruthless about time-to-run and time-to-review.

**Warning sign:**
- Any single skip day without a catch-up
- Auto-PRs `.planning/dogfood/YYYY-MM-DD.md` exist but the last N don't have a review/close commit
- Time from dogfood run to Julien review > 48h sustained

**Prevention:**
1. **10 min budget hard-cap**: if `mint-dogfood` takes > 10 min to run, abort and log "loop exceeded budget". Scenario must shrink.
2. **Failure-mode: compact weekly, not stack daily**: if 3+ days missed in a row, loop auto-switches to weekly mode (Sundays, 30 min). Honesty > pretending daily still works.
3. **Pareto the scenario**: only the 5 critical journeys (A6) in the daily scenario. Everything else is weekly.
4. **Low-ceremony PR**: auto-PR is a file commit, not a full GitHub PR, unless findings exist. Zero-finding runs = dot file `.planning/dogfood/2026-04-19-GREEN.md` with one line. No review needed. Saves attention.
5. **Weekly metric**: dogfood health = (runs_completed / days_in_week). If < 5/7 for 2 weeks running, the loop design needs changing, not willpower.

**Phase ownership:** 35 (time budget + failure mode) + 36 (stickiness check is exit criterion — loop must survive 30 days).

---

### E2. Scripted scenario goes stale → runs green → blind spot

**What goes wrong:** Scenario was written 2026-04-19. New "Aujourd'hui" layout ships 2026-05-15. Scenario taps on `key: 'insight-card-0'` — that key now doesn't exist. simctl taps miss, scenario fails silently (simctl doesn't know UI failed, just that tap landed somewhere) or taps wrong target. Dogfood reports green. Nobody sees regression. Facade-sans-câblage on the oracle itself.

**Warning sign:**
- Zero findings for > 5 days running on an actively-developed codebase — either MINT is perfect (suspicious) or scenario is stale
- A scenario tap targets a key that doesn't exist in current tree — `simctl ui describe-all` doesn't contain the key
- Creator device walkthrough finds a bug that dogfood didn't

**Prevention:**
1. **Scenario self-verification**: before tapping, `simctl ui describe-all` + grep for the expected key. If missing → fail loud. Report "scenario stale on step N: expected key `X`, not in tree".
2. **Screen registry cross-check** (Phase 32 artefact): scenario tap targets reference screen board entries. If a screen is removed from board or its keys change, scenario CI fails until scenario updated.
3. **Creator walkthrough every Friday**: weekly anchor of a real device walkthrough (creator, iPhone, 15 min) that catches what dogfood can't. Dogfood is fast signal, walkthrough is truth.
4. **Scenario versioned with app**: `scenario-vX.Y.md` in `.planning/dogfood/scenarios/`. Each app milestone bumps scenario. Rejected PR if milestone closes without scenario update.

**Phase ownership:** 35 (self-verification + versioning) + 36 (creator walkthrough Friday cadence formalized).

---

### E3. Screenshot volume + retention → bloat or loss

**What goes wrong:** See B2 (same problem, different surface). 10 screenshots × 30 days × 0.5MB = 150MB. Add to git → bloat. Delete → lose regression reference. Middle ground (external storage) requires discipline.

**Warning sign:** Same as B2.

**Prevention:**
1. **WebP compression** at capture time (simctl → ImageMagick → WebP 80% quality, typical 50-80KB).
2. **Rotation**: 30-day rolling window. Older than 30d → delete OR archive to cold GCS bucket.
3. **Retain on finding only**: a dogfood run with 0 findings deletes its screenshots immediately. Only runs with P0/P1 keep screenshots for review.
4. **External storage from day 1** (see B2.1).

**Phase ownership:** 35 (retention policy + external storage).

---

### E4. Auto-PR spam when 0 findings → signal buried in ceremony

**What goes wrong:** Every dogfood run opens a PR. 30 PRs/month. 29 of them are "all green". Julien stops reading. The 1 critical finding buried.

**Warning sign:**
- PR list in GitHub has > 10 dogfood PRs awaiting review
- Julien says "there are too many dogfood PRs"
- Finding-rate per PR < 0.2 (80% are zero-finding)

**Prevention:**
1. **PR threshold**: open a real PR only if `findings.count >= 1 P0 OR >= 3 P1 OR >= 10 P2`. Else commit a dot file `.planning/dogfood/YYYY-MM-DD-GREEN.md` directly to a reserved `dogfood` branch and skip PR.
2. **Weekly digest PR**: Mondays, one PR summarizes the week's green days + any finding days. One review action per week max.
3. **Slack-ifiable summary**: single-line digest "week N: 5 green, 2 yellow (1 P1, 3 P2)" — Julien reads in 5 seconds, decides whether to drill.

**Phase ownership:** 35 (PR threshold + weekly digest).

---

### E5. simctl ≠ real device — dogfood signal is incomplete

**What goes wrong:** simctl on Mac reproduces UI but NOT:
- Push notifications (APNs silent, local, with sound)
- Deep links from external apps / Safari
- Apple Pay / Face ID / Touch ID
- Real camera (VisionKit on sim is canned)
- Orientation change physics, haptics
- Background → foreground restore with backend state changes
- Real network conditions (jitter, 3G fallback, captive portal)

MINT's core flow includes: camera scan (A.2 in v2.7 gate), Face ID for BYOK, local notifications for commitment devices. Dogfood sees green on all of this. Device sees crash. Gate 0 doctrine applies: creator device weekly is non-skippable.

**Warning sign:**
- A user-reported bug involves a feature dogfood can't exercise (camera, push, Face ID)
- Dogfood green for 30 days straight AND v2.8 hasn't shipped to prod yet (suspicious — means dogfood is only testing simulator-surface)

**Prevention:**
1. **Dogfood scope is explicit**: scenario file header lists what IS covered (sim-surface UI flow) and what IS NOT (camera, push, Face ID, real Vision, orientation). No false-advertising.
2. **Weekly creator walkthrough on physical iPhone** (60 min, 1 day/week) — covers the simctl-gaps. Non-skippable for v2.8 exit. Template: v2.7's DEVICE_GATE_V27_CHECKLIST.md adapted to v2.8.
3. **Staging push-notif injection**: backend has endpoint `/test/send-push` (admin-gated) that fires a silent push to test device. Dogfood can invoke this once a week for a minimal push smoke.

**Phase ownership:** 35 (scope declaration) + 36 (creator weekly walkthrough as exit gate).

---

### E6. simctl flakiness on macOS Tahoe + idb_companion socket bugs

**What goes wrong:** Per memory, macOS Tahoe has known iOS build quirks (`feedback_ios_build_macos_tahoe.md` — never `flutter clean`, never delete `Podfile.lock`). idb_companion socket connection issues were observed during 2026-04-17 session. simctl commands freeze mid-run. Dogfood scenario hangs, no timeout, Julien finds it stuck in the morning, deletes the run, tries again, misses day → fatigue → E1 spiral.

**Warning sign:**
- `mint-dogfood` runtime > 10 min (likely hung)
- simctl processes accumulating in `ps` from prior runs
- idb_companion log shows socket reset errors

**Prevention:**
1. **Hard timeout at every step**: every simctl command wrapped in `timeout 30s`. If any step exceeds, kill and report "scenario hung at step N".
2. **Clean state between runs**: dogfood start = `simctl shutdown all; simctl erase <sim_id>; simctl boot <sim_id>` — fresh sim every run.
3. **Fallback to cli-only scenarios**: if simctl is flaky, have a second scenario track that exercises backend via curl + inspects Sentry (no UI). Less coverage but no UI-tool dependency.
4. **Document known-bad combos**: Phase 35 deliverable `.planning/research/SIMCTL_TAHOE_QUIRKS.md` lists observed failures + workarounds, keeps it fresh.
5. **Creator-device weekly is the real gate anyway** (E5) — simctl is dev-loop tool, not exit gate. If simctl is flaky for 2 weeks, consider dropping sim for pure creator-device weekly + Sentry triage.

**Phase ownership:** 35 (timeouts + clean state).

---

### E7. Sentry usage monitoring forgotten in daily loop

**What goes wrong:** Phase 31 enables Sentry Replay. Phase 35 dogfood runs but doesn't pull Sentry usage. Day 15 of month, quota exceeded, Replay turns off for remaining users, effectively blind for the worst half of the month. Julien notices on invoice.

**Warning sign:** Sentry usage page shows > 75% quota before day 20.

**Prevention:**
1. **Dogfood includes a Sentry usage pull**: every run fetches `sentry.io/api/0/organizations/{org}/stats/` via API, appends `sentry_quota_pct` to dogfood output.
2. **Alarm at 70% mid-month**: if quota hits 70% before day 20 → notify, propose sampling reduction.
3. **Monthly report**: Phase 35 weekly digest includes Sentry cost trajectory.

**Phase ownership:** 35 (Sentry pull integrated) + 31 (quota alarm thresholds).

---

## F. Phase 36 — Finissage E2E pitfalls

### F1. "Zero route rouge" is a moving goalpost

**What goes wrong:** Julien fixes 5 red routes. During the fix, 3 new red routes emerge (regressions from fix side-effects, or routes that were grey-unverified before and now exercised for the first time, or legit new bugs surfaced). "Zero red" keeps moving away. Milestone drags. Burnout.

**Warning sign:**
- Red route count stays flat or grows 2 weeks into Phase 36
- Each fix PR introduces 1 new red route (regression rate = 1:1)
- Critical journeys (A6) are red at milestone close

**Prevention:**
1. **Freeze dev during Phase 36 entry**: last week of v2.8 = no new feature work, no Wave starts, only red-route fixes + compression. Phase 36 entry triggers `/dev-freeze` flag.
2. **Staged goal**: "zero red on the 5 critical journeys (A6)" is exit criterion, NOT "zero red on 102 routes". Realistic for solo dev in milestone budget.
3. **Red route registry + owner per red**: each red route has an issue, an owner (Julien, since solo), an ETA, a fix commit reference. If ETA slips > 2× → decision: kill (flag off permanent) or defer to v2.9 (explicit, in writing).
4. **Regression budget**: `new_red_from_fix / fix_count < 0.2` — else stop, retro, understand why fixes regress.

**Phase ownership:** 36 (dev freeze + staged goal + regression budget).

---

### F2. 388 catches → 0 in one milestone is a massive blast radius

**What goes wrong:** A script auto-replaces `catch { }` with `catch (e) { logger.error(e); rethrow; }`. In some places, that was an intentional swallow (fallback UX, best-effort Railway call, known-safe ignore). Auto-rethrow breaks the fallback → feature regresses → more red routes (F1) → compound problem.

**Warning sign:**
- A UX fallback that used to silently degrade now throws to user
- Sentry event rate spikes 10× after catch migration
- A "working" feature (pre-v2.8) becomes broken after migration

**Prevention:**
1. **Batch migration**: 20-50 catches per PR, not all at once. Each batch grouped by module (only `coach_service`, only `scan_service`, etc.). Easy to bisect regressions.
2. **Per-batch tests**: each batch has a manual smoke test on the affected module + 24h Sentry observation before next batch.
3. **Classify each catch, don't auto-migrate**: tooling produces a CSV of all 388 with:
   - File, line, surrounding 10 lines
   - Current behavior (swallow / log / fallback / rethrow)
   - Proposed behavior
   - Agent classification: `safe-rethrow` / `fallback-keep-with-log` / `investigate`
   Julien reviews the `investigate` bucket manually. Agent auto-migrates only `safe-rethrow`.
4. **Atomic commits**: one catch migration per commit OR one module per commit with clear diff. Bisectable.
5. **Rollback flag per batch**: until a migration batch has 48h clean on staging, it's behind a flag `catch_migration_batch_N`. Can revert instantly if regression.

**Phase ownership:** 36 (classification + batched migration).

---

### F3. UUID profile crash fix on staging but prod stays broken

**What goes wrong:** Fix lands in `services/backend/app/schemas/profile.py`. Deploys to staging via Railway auto-deploy. Prod requires manual promotion. Julien forgets to promote. User on prod still hits UUID crash. Sentry shows no new crashes on staging → Julien thinks "fixed". Prod stays broken for 3 days.

**Warning sign:**
- Staging commit SHA ≠ prod commit SHA on the fix file
- Sentry prod environment still shows the error post-fix
- `git log prod` doesn't include the fix SHA

**Prevention:**
1. **Deploy discipline**: every P0 fix includes a 3-step commit plan in commit message:
   - (a) Fix on dev → staging auto-deploy
   - (b) Validate on staging within 24h
   - (c) Promote to prod within 48h
2. **Prod environment SHA board**: `/admin/deploy-status` shows dev SHA / staging SHA / prod SHA side by side. Diff count visible. Phase 36 deliverable.
3. **Sentry per-environment alarms**: P0 fix resolves Sentry issue on staging → Sentry still shows issue open on prod → alarm "fix not promoted". Forces action.
4. **Promotion PR template** has a checklist: "fix X verified on staging since YYYY-MM-DD HH:MM".

**Phase ownership:** 36 (deploy board + promotion discipline).

---

### F4. MintShell i18n: 4 labels × 6 langs regression silent

**What goes wrong:** Julien adds `shell_tab_home` to `lib/l10n/app_fr.arb`. Forgets `app_en.arb`, `app_de.arb`, `app_es.arb`, `app_it.arb`, `app_pt.arb`. App on `en` falls back to `fr` silently — user in German Switzerland sees `Aujourd'hui` instead of `Heute`. Ships. Quality drops.

**Warning sign:**
- Any ARB file has fewer keys than `app_fr.arb`
- i18n CI gate not run on PR
- Dogfood scenario covers `fr` only (no DE / IT swap)

**Prevention:**
1. **ARB parity lint**: `tools/checks/arb_parity.py` compares all 6 ARBs against `app_fr.arb` as template. Fails CI if any delta. MUST be in lefthook pre-commit (< 1s).
2. **MintShell specific test**: `test/widgets/shell_i18n_test.dart` pumps MintShell in all 6 locales, asserts no `fr` strings render.
3. **Dogfood scenario locale swap**: daily loop includes a single language swap (rotate through locales week-by-week). Catches regressions in sampling.
4. **i18n-only PR for bulk adds**: when Julien adds N keys, one PR per 10 keys, auto-translated + human-reviewed. Scope control.

**Phase ownership:** 36 (parity lint enforced + i18n smoke) + 34 (lefthook gate).

---

### F5. "Accents 100%" is unverifiable without lint scope

**What goes wrong:** `greppable` check `grep -r "[eE]tat"` finds `État` correctly-accented in ARBs, miss `etat` in a TypeScript doc, miss `creer` in a file name. "100%" is hollow unless scope is defined. Julien sees green check → ships. A user sees `creer` somewhere → bug report.

**Warning sign:**
- A user-reported accent issue after 100% pass
- Any user-facing surface (ARB, screen names, docstrings in coach prompts) wasn't in the scope
- The accent grep script has no explicit scope file

**Prevention:**
1. **Scope declared explicitly**: `tools/checks/accents_fr.py` reads `.scope-accents.txt`:
   ```
   # User-facing surfaces — FR accents mandatory
   lib/l10n/app_fr.arb
   lib/l10n/app_intl_fr.arb
   services/backend/app/services/prompts/fr/**
   services/backend/app/services/coach_prompts.py
   docs/**/*.md  # user-shared docs
   # Internal (English/code): NOT in scope
   # lib/**/*.dart — code — exempt
   # services/backend/app/**/*.py — code — exempt
   ```
2. **Lint runs on declared scope only**. "100% of scope" is honest. Anything outside scope = explicitly not claimed.
3. **Scope review at phase close**: on Phase 36 exit, re-read `.scope-accents.txt` and ask "is this all user-facing surface?". If no, expand scope.

**Phase ownership:** 36 (scope file + lint + review).

---

### F6. Scope creep: yellow route → feature request → milestone derails

**What goes wrong:** Julien opens `/admin/routes`, sees `/retraite/deep` yellow. Checks it — works but the insight is weak. Idea sparks: "I should improve this insight". Codes it. 3 days later, it's a new feature. v2.8 milestone has drifted. Doctrine "0 feature nouvelle" violated silently.

**Warning sign:**
- Any commit on v2.8 branch that adds a new UX insight, new screen, new prompt template
- PR diff net-adds > 300 LOC without being a test/infrastructure/catch-migration
- Julien's gut says "while I'm here, let me also..."

**Prevention:**
1. **Doctrine in PR template**: every v2.8 PR template says "This PR does NOT add user-facing features. Check: ___". Julien signs. Audit trail.
2. **ADR required for exceptions**: if a fix genuinely needs a small new feature (e.g., an error state screen), write a 1-page ADR before code.
3. **Scope audit script**: `tools/checks/v28_scope.py` scans the diff for:
   - New files under `lib/screens/**` (suspect)
   - New strings in `app_fr.arb` not present in user-facing error/empty-state patterns (suspect)
   - New coach prompts (suspect)
   Fires warning (not block) on suspect; Julien confirms.
4. **Weekly scope pulse**: dogfood digest asks "did we add anything new this week that wasn't planned?". One-line honest answer.

**Phase ownership:** 36 (PR template + scope audit) + G1 (meta: scope creep is the recurring pattern).

---

## G. Meta-pitfalls (milestone v2.8 transversal)

### G1. Déjà-vu: v2.4 "Fondation", v2.6 "Coach qui marche", v2.7 "Stabilisation", now v2.8 "L'Oracle et la Boucle"

**What goes wrong:** Every milestone since v2.4 has been framed as "the final finishing". Each has been followed by another finishing milestone. Pattern: creator promises "this one is it", ships, discovers new cracks on device, declares next milestone the real one. v2.8 risks being the fourth iteration of the same delusion.

**Warning sign:**
- Phase 36 exit candidates contain "v2.9 will address this" for > 3 critical items
- Milestone close doc uses the word "stabilize" or "finishing" or "fondation"
- Julien catches himself planning v2.9 before v2.8 closes

**Prevention:**
1. **Explicit kill-policy written into PROJECT.md**: "If v2.8 exit criteria aren't met by $DATE, we KILL features (flag off permanent) until exit criteria met. We do NOT create v2.9 as a continuation."
2. **Exit-criteria binary**: each v2.8 req is pass/fail. No "mostly done". No "deferred to v2.9". Either pass or the feature it relates to is killed.
3. **Meta-retro at phase 36 entry**: Julien writes 1 page "why did v2.4/v2.6/v2.7 not stick?". If the root-cause is identified, check v2.8 plan against it. If v2.8 repeats the same pattern, restructure now, not after shipping.
4. **Public commitment**: if v2.8 fails, there is no v2.9 milestone named "stabilization". Roadmap only contains genuinely new work (product features) OR MINT goes into maintenance mode.

**Phase ownership:** Pre-milestone (kill policy written day 1) + 36 (enforcement at exit).

---

### G2. 6 phases × 1-2 weeks solo = 6-12 weeks. Risk: over-invest in 31-34, bâcle 35-36

**What goes wrong:** Instrumentation (Phase 31) is seductive — dashboards, replays, feels like progress. Julien spends 3 weeks on Phase 31 "getting it perfect". Phases 35-36 (the actual user-visible work, the daily loop, the 388 catches) get 1 week each. Milestone ships with a beautiful oracle observing a still-broken app.

**Warning sign:**
- Phase 31 > 2 weeks elapsed without exit
- "Still polishing Sentry config" week 3
- Phases 35-36 on the calendar show < 2 weeks combined

**Prevention:**
1. **Budget allocated explicitly, tracked weekly**:

| Phase | Core work | Budget | Max (hard-cap) |
|-------|-----------|--------|----------------|
| 31 Instrument | Boundary + Replay + traces + 5 journeys | **1 wk** | 1.5 wk |
| 32 Cartographie | `/admin/routes` + sunset plan + flavor gate | **1 wk** | 1.5 wk |
| 33 Kill-switches | Flag expiry + gradient breaker + cache-60s | **0.75 wk** | 1 wk |
| 34 Guardrails | lefthook < 5s + 4 lints + session-hash | **1.25 wk** | 1.5 wk |
| 35 Boucle Daily | `mint-dogfood` + scenario + timeout hygiene | **1 wk** | 1.5 wk |
| 36 Finissage | 388 catches + UUID fix + i18n + scope | **2 wk** | 3 wk |
| **Total** | | **7 wk** | **10 wk** |

2. **Hard-cap enforced**: if Phase 31 hits 1.5 wk, it ships with whatever is done. No "one more week to polish". Remaining scope → Phase 36 backlog OR v2.9 explicit defer.
3. **Weekly sync check**: Monday morning, Julien writes 3 lines: "phase N, day M, on track / over". If over 2 weeks running, plan restructures.
4. **Phase 35-36 can't be compressed**: they deliver the user-visible gain. Compress 31-34, never 35-36.

**Phase ownership:** Roadmap + all phases (budget is commitment).

---

### G3. Agent context window explodes → situational awareness lost (the accents episode)

**What goes wrong:** Per memory — agents have already lost accents ("creer" instead of "créer") because context budget exploded and early task context was evicted. v2.8 risks the same across 6 phases. A single session that plans Phase 32 → executes Phase 32 → plans Phase 33 → executes Phase 33 will accumulate ≥ 150k tokens. Quality degradation is statistically certain.

**Warning sign:**
- Agent produces output violating a rule cited earlier in the same session
- Accents lost, ARB files desync, constants drift within a session
- Session > 100k tokens

**Prevention:**
1. **`/clear` between phases**, non-negotiable. Phase N closes → `/clear` → Phase N+1 opens fresh.
2. **Phase-sized plans**: each plan scoped to one phase, one sprint. Never "plan Phase 32 and 33 together". `context-monitor.js` (per memory, already installed) enforces.
3. **Session checkpoint at 75k**: force agent to write a compact summary of state to a file, then `/clear` and re-load the file. Keeps context working memory < 100k.
4. **Audit at phase close**: re-read CLAUDE.md, verify accents/rules/constants not drifted in the phase's commits. If drift → revert + re-do in fresh session.

**Phase ownership:** Every phase (meta-ritual at phase boundaries).

---

### G4. Measurement tyranny: 5 dashboards → 0 dashboards read

**What goes wrong:** Phase 31 Sentry dashboard. Phase 32 `/admin/routes`. Phase 33 `/admin/flags`. Phase 35 dogfood digest. Backend Sentry. Frontend Sentry. Railway deploy board. = 7 surfaces to check daily. Julien checks none regularly. Oracle delivers, but observer absent.

**Warning sign:**
- Julien opens admin/dashboards < 1×/day in week 2 of Phase 31
- A P0 sits in Sentry unresolved for > 24h
- Julien asks "what's broken?" instead of knowing

**Prevention:**
1. **1 consolidated dashboard**: a single `/admin/health` page that aggregates:
   - Top 5 Sentry issues last 24h (mobile + backend)
   - Red + yellow routes from `/admin/routes`
   - Flags currently off + their staleness
   - Yesterday's dogfood digest + this week's streak
   - Sentry quota %
   - Prod vs staging SHA delta
   One page, 30-second scan, Julien opens it morning + evening.
2. **Push alerts for urgent**: P0 Sentry, dogfood P0, quota > 80%, prod != staging for > 48h → push notif to Julien's phone. Everything else stays pull-mode on the dashboard.
3. **Kill redundant surfaces**: during Phase 36 review, if a dashboard has < 3 hits/week from Julien, merge into `/admin/health` or remove.
4. **Mobile-friendly dashboard**: Julien's phone must be able to render `/admin/health` in 1 screen. Not desktop-only.

**Phase ownership:** 32 or 33 (whichever ships admin first has the consolidation duty) + 35 (daily-loop outputs into it).

---

## Phase ownership summary

| Pitfall | Primary phase | Secondary |
|---------|---------------|-----------|
| A1 Sentry PII leak | 31 | — |
| A2 Sentry quota | 31 | 35 (E7) |
| A3 Boundary double-log | 31 | 34, 36 |
| A4 Trace_id round-trip | 31 | 35 |
| A5 Lint false-positives | 34 | 36 |
| A6 Over-instrumentation | 31 | 35 |
| B1 Screen board stale | 32 | 35 |
| B2 Screenshot bloat | 32 | 35 |
| B3 Admin leak in prod | 32 | 34 |
| B4 Redirect sunset | 32 | 36 |
| B5 Static parser misses | 32 | — |
| C1 Flag rot | 33 | 35 |
| C2 Circuit breaker too sensitive | 33 | 35 |
| C3 Flag propagation delay | 33 | 35 |
| C4 Cohort creep | 33 | 34 |
| C5 Flags mask bugs | 33 | 35 |
| D1 lefthook > 5s | 34 | — |
| D2 --no-verify abuse | 34 | — |
| D3 Lint false-positives | 34 | 36 |
| D4 Proof-of-read theater | 34 | — |
| D5 CLAUDE.md context explosion | 34 | G3 |
| D6 Hooks break Julien | 34 | — |
| E1 Dogfood fatigue | 35 | 36 |
| E2 Scenario stale | 35 | 36 |
| E3 Screenshot volume | 35 | — |
| E4 PR spam | 35 | — |
| E5 simctl ≠ real device | 35 | 36 |
| E6 simctl flakiness | 35 | — |
| E7 Sentry usage forgotten | 35 | 31 |
| F1 Zero-red moving goalpost | 36 | — |
| F2 388 catches blast radius | 36 | — |
| F3 UUID fix prod un-deployed | 36 | — |
| F4 ARB parity regression | 36 | 34 |
| F5 Accents 100% hollow | 36 | — |
| F6 Feature scope creep | 36 | G1 |
| G1 Déjà-vu milestone | Pre | 36 |
| G2 Budget overrun 31-34 | All | — |
| G3 Context explosion | All | — |
| G4 Dashboard tyranny | 32/33 | 35 |

---

## Critical pitfalls (top 5 — must address or milestone fails)

1. **A1 — Sentry Replay PII leak**: single biggest regulatory risk. No Phase 31 ship without redaction audit.
2. **F2 — 388 catches in one milestone**: largest blast radius. Needs classification-first, batched migration.
3. **E1 — Dogfood fatigue kills the loop**: if the boucle dies, v2.8 shipped an oracle nobody consults. Core value proposition void.
4. **G1 — Déjà-vu pattern**: if v2.8 becomes "v2.9 will fix it", the creator's trust in the process collapses. Explicit kill-policy required in PROJECT.md before Phase 31 starts.
5. **B3 — Admin route leak in prod**: single misconfigured env var = FINMA + nLPD exposure of internal routes. Triple-gate mandatory.

## Moderate pitfalls (material — address or quality drops)

A2 (quota), A3 (boundary), A4 (trace), A6 (over-instrument), B1 (stale board), B4 (redirects), C1 (flag rot), C3 (propagation), D1 (lefthook slow), D4 (proof theater), E2 (scenario stale), E5 (simctl gap), F1 (zero-red drift), F3 (prod unpromoted), F4 (ARB parity), F6 (scope creep), G2 (budget), G3 (context), G4 (dashboards).

## Minor pitfalls (tolerable — address if time)

A5 (lint FP), B2 (screenshot bloat), B5 (static parser), C2 (breaker sensitivity), C4 (cohort creep), C5 (flag as bug-hide), D2 (--no-verify digest), D3 (lint FP), D5 (CLAUDE.md re-read), D6 (human commits), E3 (screenshots), E4 (PR spam), E6 (simctl flake), E7 (Sentry usage).

---

## Budget estimate per phase (solo dev, sequential, 1 plan at a time)

| Phase | Target | Hard-cap | Key risk of overrun |
|-------|--------|----------|---------------------|
| 31 Instrumenter | **1.0 wk** | 1.5 wk | PII audit deeper than expected |
| 32 Cartographier | **1.0 wk** | 1.5 wk | Redirect sunset analytics delay (30-day dark — overlaps with later phases, not blocker) |
| 33 Kill-switches | **0.75 wk** | 1.0 wk | Gradient breaker complexity |
| 34 Guardrails | **1.25 wk** | 1.5 wk | lefthook < 5s optimization hard |
| 35 Boucle Daily | **1.0 wk** | 1.5 wk | simctl Tahoe debugging time |
| 36 Finissage | **2.0 wk** | 3.0 wk | 388 catches batching overrun |
| **Total target** | **7.0 wk** | **10.0 wk** | Compression discipline required |

**If hard-cap hit on any of 31-34 → cut scope of that phase, do NOT borrow from 35-36.** Phases 35-36 are the user-visible win — compressing them defeats v2.8's purpose.

---

## Sources & confidence

- Internal doctrines (HIGH confidence): MINT memory — feedback_facade_sans_cablage.md, feedback_tests_green_app_broken.md, feedback_no_shortcuts_ever.md, feedback_audit_methodology.md, feedback_ios_build_macos_tahoe.md, project_session_2026_04_18_deep_audit.md
- PROJECT.md v2.8 scope + codebase entry state (HIGH confidence, just authored)
- DEVICE_GATE_V27_CHECKLIST.md (HIGH confidence, authoritative operational doc)
- Sentry Replay + pricing: training-data knowledge (MEDIUM — requires Phase 31 fresh fetch before committing numbers)
- Lefthook < 5s budget: industry practice (MEDIUM — verified against ex-Monzo/Stripe public engineering talks)
- Monzo dogfood loop failure mode: ex-Monzo QA lore (MEDIUM — not publicly documented in detail)
- Cleo guardrail theater: ex-Cleo prompt-eng panel lore (MEDIUM — extrapolated from known LLM guardrail failures)
- Linear "signal over noise": public engineering blog statements (MEDIUM)
- Flag rot pattern: Martin Fowler + ex-LaunchDarkly public material (HIGH conceptually, MEDIUM on specific thresholds)

**Verification TODO for Phase 31 kickoff:** fetch Sentry pricing page fresh, verify Replay quota and EU residency current terms. Commit the fetch into `.planning/research/SENTRY_PRICING_2026_04.md`.
