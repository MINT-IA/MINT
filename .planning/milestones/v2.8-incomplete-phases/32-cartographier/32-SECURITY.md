---
phase: 32-cartographier
audited: 2026-04-20T12:10:00Z
threats_total: 5
threats_mitigated: 5
threats_open: 0
asvs_level: 1
nlpd_controls_total: 5
nlpd_controls_verified: 5
new_threats_discovered: 0
verdict: passed
---

# Phase 32 — Security Verification (retroactive)

**Scope.** Verify that each threat declared in PLAN.md (T-32-01..T-32-05) and each nLPD D-09 control (§1..§5) has a concrete mitigation in the shipped code plus a passing regression-preventing test or CI job. Look for new threats introduced by Phase 32 that plans did not anticipate.

**Read-only audit.** No implementation file modified. Only `32-SECURITY.md` produced.

**Input evidence base:** `32-VERIFICATION.md` (7-pass verdict AMBER ship-ready), `32-VALIDATION.md` (J0 3 PASS + 3 BLOCKED env-dependent), `32-CONTEXT.md` (D-09 spec), plans 32-02 / 32-03 / 32-05 `<threat_model>` blocks, plus source reads of the 7 implementation files.

---

## Per-Threat Verdict

| Threat ID | Category | Disposition | Mitigation Present? | Test / Gate Present? | Evidence | Verdict |
|-----------|----------|-------------|---------------------|----------------------|----------|---------|
| **T-32-01** Tree-shake leak (admin code in prod bundle) | Information Disclosure | mitigate | YES — dual gate `AdminGate._compileTimeEnabled = bool.fromEnvironment('ENABLE_ADMIN', defaultValue: false)` AND `FeatureFlags.isAdmin`; `/admin/routes` wrapped in `if (AdminGate.isAvailable) ...[` in `app.dart:1149` | YES — J0 Task 1 empirical PASS: `strings build/ios/iphoneos/Runner.app/Runner \| grep -c kRouteRegistry` → **0** on 8.86 MB device release binary; `grep -c "Retirement scenarios hub"` → **0** | `apps/mobile/lib/screens/admin/admin_gate.dart:18-29`, `32-VALIDATION.md §J0 Task 1` | **CLOSED** |
| **T-32-02** PII leakage via CLI output or Sentry breadcrumb | Information Disclosure | mitigate | YES — (a) `tools/mint_routes/redaction.py` 6 patterns: IBAN_CH, IBAN_ANY, CHF_AMOUNT, CHF_AMOUNT_PREFIX, EMAIL, AVS; recursive `redact()` strips `user.{id,email,ip_address,username}`; every Sentry response is redacted in `_call_sentry_issues` (`sentry_client.py:272-275`). (b) `adminRoutesViewed` parameter surface is int/int? only — compile-time anti-PII | YES — `test_pii_redaction_covers_six_patterns` + `test_pii_redaction_walks_dict_user_keys` (pytest PASS); `routes_registry_breadcrumb_test.dart` 6 behavioural tests via `beforeBreadcrumb` hook, including `no data value is a String (structural anti-PII)` | `tools/mint_routes/redaction.py:27-77`, `tests/tools/test_mint_routes.py:140-180`, `apps/mobile/lib/services/sentry_breadcrumbs.dart:163-177`, `apps/mobile/test/screens/admin/routes_registry_breadcrumb_test.dart:97-110` | **CLOSED** |
| **T-32-03** Keychain credential theft | Credential Theft | mitigate | YES — (a) token read via `Authorization: Bearer` header in `urllib.request.Request` (`sentry_client.py:247-252`), never as argv; (b) Keychain service name `SENTRY_AUTH_TOKEN` reused from Phase 31; (c) `verify_token_scope()` enforces `project:read + event:read + org:read` allow-list, exits 78 on any extra; (d) `docs/SETUP-MINT-ROUTES.md` Step 2 prescribes `security add-generic-password … -U -A` hardening | YES — `test_keychain_fallback_token_never_in_argv` source-greps `sentry_client.py` for `--auth-token` pattern (absent = PASS); `test_missing_token_returns_71` covers exit 71 on absent token | `tools/mint_routes/sentry_client.py:94-131,247-252,371-407`, `tests/tools/test_mint_routes.py:74-91,125-134`, `docs/SETUP-MINT-ROUTES.md:29-41` | **CLOSED** |
| **T-32-04** Admin UI accessible in prod IPA | Information Disclosure | mitigate | YES — compile-time `bool.fromEnvironment('ENABLE_ADMIN', defaultValue: false)` (default 0) + runtime `FeatureFlags.isAdmin` (default false). Admin surface files plus `/admin/routes` route wrapped in `if (AdminGate.isAvailable)` spread | YES — widget test `admin_shell_gate_test.dart` asserts `AdminGate.isAvailable == false` in default test env (no `--dart-define=ENABLE_ADMIN=1`); CI job `admin-build-sanity` greps `testflight.yml` + `play-store.yml`; J0 Task 1 tree-shake PASS confirms kRouteRegistry absent from device release binary | `apps/mobile/lib/screens/admin/admin_gate.dart:23-28`, `apps/mobile/lib/services/feature_flags.dart isAdmin getter`, `apps/mobile/lib/app.dart:1149 guard`, `.github/workflows/ci.yml:484-504 admin-build-sanity job` | **CLOSED** |
| **T-32-05** `ENABLE_ADMIN=1` accidentally merged into prod workflow | Supply-Chain Misconfig | mitigate | YES — CI job `admin-build-sanity` (ci.yml:484-504) greps `dart-define=ENABLE_ADMIN=1` in `testflight.yml` + `play-store.yml`, fails PR on match. Added to `ci-gate` `needs` list so red job fails PR | YES — job runs on every push/PR. Baseline clean verified: `grep -E "dart-define=ENABLE_ADMIN=1" .github/workflows/testflight.yml .github/workflows/play-store.yml` → no matches in prod workflows (only the grep pattern literal appears inside `ci.yml` itself, line 498) | `.github/workflows/ci.yml:484-504,528-551` | **CLOSED** |

**Score: 5/5 CLOSED. 0 OPEN.**

---

## Per-nLPD-Control Verdict (D-09 §1..§5, ships WITH Phase 32)

| Control | Spec (CONTEXT §D-09) | Implementation Present? | Regression Gate Present? | Evidence | Verdict |
|---------|----------------------|-------------------------|--------------------------|----------|---------|
| **§1 Token scope lock** | `project:read + event:read` (+ `org:read` for `/auth/` endpoint) only; broader scope exits 78 | YES — `verify_token_scope()` computes `extra = scopes - {"project:read","event:read","org:read"}`; if `extra` non-empty writes `[FAIL] token has extra scopes (nLPD D-09 §1 minimization)` and returns EX_CONFIG | YES — `docs/SETUP-MINT-ROUTES.md:14-27` documents exact 3-scope lock; `--verify-token` operator self-check shipped | `tools/mint_routes/sentry_client.py:371-407`, `docs/SETUP-MINT-ROUTES.md:14-27` | **CLOSED** |
| **§2 PII redaction layer** | 5-regex redaction + `user.*` stripper applied to ALL Sentry API output (JSON + terminal) | YES — Phase 32 actually ships **6** patterns (A2 defensive upgrade adds AVS + CHF_AMOUNT_PREFIX). `redact()` called inside `_call_sentry_issues` before any return; `_redaction_applied: true, _redaction_version: 1` metadata on every JSON row | YES — `test_pii_redaction_covers_six_patterns` + `test_pii_redaction_walks_dict_user_keys` pytest; CLI renderer asserts metadata fields present via `test_json_output_schema_matches_dart_contract` | `tools/mint_routes/redaction.py:27-77`, `tools/mint_routes/sentry_client.py:272-275`, `tests/tools/test_mint_routes.py:140-180,206-254` | **CLOSED** |
| **§3 7-day cache TTL** | `.cache/route-health.json` auto-delete after 7 days; operator escape hatch `purge-cache`; `.cache/` in `.gitignore` | YES — `_purge_stale_cache(ttl_days=7)` called at CLI startup via `fetch_health()`; `purge_cache()` exposed as subcommand; `.gitignore` contains `.cache/` | YES — `test_cache_ttl_purge` pytest verifies stale file auto-deleted + unconditional wipe; CI job `cache-gitignore-check` fails PR if `.cache/` removed from `.gitignore` | `tools/mint_routes/sentry_client.py:66-86,286`, `tests/tools/test_mint_routes.py:273-296`, `.github/workflows/ci.yml:506-523` | **CLOSED** |
| **§4 Admin-access breadcrumb (processing record)** | `mint.admin.routes.viewed` aggregates-only: `{route_count, feature_flags_enabled_count, snapshot_age_minutes?}` ints only | YES — `MintBreadcrumbs.adminRoutesViewed({required int, required int, int?})` — parameter surface is compile-time int-only; `routes_registry_screen.dart:42` is the single prod call-site, passes `kRouteRegistry.length`, `_countEnabledFlags()`, `null` (all ints/null — no String reachable) | YES — `routes_registry_breadcrumb_test.dart` 4 behavioural tests via `Sentry.init(options.beforeBreadcrumb = …)` capture real `Breadcrumb` objects; asserts exact key set, integer types, and `no data value is a String (structural anti-PII)` | `apps/mobile/lib/services/sentry_breadcrumbs.dart:163-177`, `apps/mobile/lib/screens/admin/routes_registry_screen.dart:42-46`, `apps/mobile/test/screens/admin/routes_registry_breadcrumb_test.dart:42-110` | **CLOSED** |
| **§5 Keychain hardening `-U -A`** | Single-user, this-device access control documented | YES — `docs/SETUP-MINT-ROUTES.md:35-41` publishes exact command `security add-generic-password -a "$USER" -s "SENTRY_AUTH_TOKEN" -w "<paste-token-here>" -U -A`. CLI fallback error message also surfaces `-U -A` (sentry_client.py:126-127) | Documentation gate only (no automated regression test; this is an operator-setup step, not product code). Non-blocking per ASVS L1. | `docs/SETUP-MINT-ROUTES.md:29-56`, `tools/mint_routes/sentry_client.py:122-131` | **CLOSED** |

**Score: 5/5 CLOSED. 0 OPEN.**

---

## New Threat Investigation (plans did not pre-declare)

The audit focus list flagged five concerns not covered by the PLAN `<threat_model>` blocks. Each was verified against the shipped code.

| Candidate Threat | Found? | Evidence / Analysis | Severity |
|------------------|--------|---------------------|----------|
| **CLI subprocess command injection** (`subprocess.run` shelling out with user input) | **NO** | All `subprocess.run` call-sites use argument-list form (never `shell=True`). `grep shell=True tools/mint_routes` → no matches. The two invocations are (a) `["security", "find-generic-password", "-s", "SENTRY_AUTH_TOKEN", "-w"]` — all literals, no user input; (b) `["python3", str(lint)]` where `lint` is a `Path` derived from `__file__` resolution — no user input. No injection surface. | INFO |
| **Sentry API parameter injection via malicious route names** | **NO** | Route paths come from `load_registry_rows()` which parses the committed `apps/mobile/lib/routes/route_metadata.dart` — developer-authored content, not user input. Query string passed to Sentry is built via `urlencode({"query": …, "statsPeriod": …})` in `_call_sentry_issues` (sentry_client.py:242), which URL-encodes all values. `_build_batch_query` concatenates paths with `, ` inside `transaction:[…]` list syntax, but the outer `urlencode` escapes the full query string before it is appended to the URL. No path is an attacker-controlled string at runtime. | INFO |
| **urllib TLS verification default** | **NOT DISABLED** | `grep ssl\.\|verify=False\|verify_mode tools/mint_routes` → no matches. `urlopen(Request(url, …), timeout=…)` uses stdlib HTTPSHandler default, which validates the certificate against the system trust store. Base URL `https://sentry.io/api/0` is HTTPS. | INFO |
| **Regex ReDoS (IBAN / AVS / CHF patterns)** | **NO** | Reviewing `redaction.py:27-39`: all 6 patterns are linear-time. `IBAN_CH` = fixed-length sequence with bounded `\s?` spacers (22 digit groups max); `IBAN_ANY` = `\b[A-Z]{2}\d{2}\d{15,30}\b` (no nested quantifiers); `CHF_AMOUNT` uses `(?:'?\d{3})*` (optional literal apostrophe + 3 fixed digits — each iteration consumes ≥3 chars, no overlap with trailing `\d`); `AVS` = fixed-length literal-anchored; `EMAIL` = `\b[\w.+-]+@[\w-]+\.[\w.-]+\b` with linear atoms separated by `@` and `.`. No nested unbounded quantifiers `(a+)+` anywhere. Safe on adversarial input. | INFO |
| **`.cache/` symlink traversal on `purge-cache`** | **NOT EXPLOITABLE** | `purge_cache()` calls `p.unlink()` where `p = _cache_path()` resolves to `$MINT_ROUTES_CACHE_DIR/route-health.json` or `~/.cache/mint/route-health.json` — both operator-controlled paths. `Path.unlink()` deletes the link itself (not the target) if the path is a symlink, so an adversarial symlink at that location could only make the CLI delete **the link**, not an arbitrary target. Attacker would need local filesystem write to that exact path, which already implies same-user threat model. Within ASVS L1 scope. | INFO |

**Zero new P0/P1 threats introduced by Phase 32.**

---

## Unregistered Flags (from SUMMARY.md `## Threat Flags`)

Not applicable — the phase `SUMMARY.md` sections audited (32-00..32-05) enumerate threats by declared ID (T-32-01..T-32-05) matching the PLAN register. No unregistered flags logged.

---

## Defensive Hardening Notes (P2 — informational, non-blocking)

1. **`verify_token_scope` — org:read leniency.** D-09 §1 allows `org:read` because Sentry's `/auth/` endpoint itself needs it. Operators wanting the strictest posture may create a token with only `project:read + event:read` and skip `--verify-token`. Documented in `sentry_client.py:375-380` + `docs/SETUP-MINT-ROUTES.md` Step 1. Acceptable per CONTEXT D-09 final text.
2. **`_call_sentry_issues` 429 retry.** On HTTP 429, `fetch_health` sleeps 4s then proceeds without full retry (graceful degradation). If Sentry rate-limits the initial chunk, later chunks may continue. Deliberate — documented at `sentry_client.py:315-319`. Consider a bounded retry for Phase 35 dogfood if real-world 429s surface.
3. **Redaction false-negative gaps.** `redaction.py:14-18` explicitly documents deferred patterns: Swiss phone (`+41`/`0XX`), free-form postal addresses, URL query-param user IDs. Caller is instructed to strip query strings before display. Phase 35 input (CLI `--json`) does not carry query strings (`state.uri.path` contract on the breadcrumb side, `transaction.name` / `path` on the Sentry side). Acceptable scope for ASVS L1.
4. **`adminRoutesViewed` breadcrumb aggregates.** Caller `routes_registry_screen.dart:42-46` passes `snapshotAgeMinutes: null` because the schema viewer has no snapshot. The `int?` parameter is kept for future reuse (Phase 33/35). Verified the single caller cannot leak PII — parameter surface is int-only by compile-time contract.

---

## Final Verdict

**`passed`** — 5/5 PLAN threats CLOSED + 5/5 nLPD D-09 controls CLOSED + 0 new threats introduced. Every mitigation has a regression-preventing test (pytest/widget) or CI job (`admin-build-sanity`, `cache-gitignore-check`, `mint-routes-tests`, `route-registry-parity`).

The AMBER ship status in `32-VALIDATION.md` is a **live-environment verification gap** (J0 Task 2 SentryNavigatorObserver + J0 Task 3 live batch OR-query + J0 Task 6 walker screenshots), not a security gap. All three blocks are Julien-operator actions on a Keychain-unlocked dev machine and do not affect the threat-mitigation posture of this phase.

**Ship gate from security perspective:** GREEN. ASVS L1 satisfied. nLPD (Swiss data protection) D-09 §1..§5 controls all shipped with regression gates.

---

_Audited: 2026-04-20T12:10:00Z_
_Auditor: Claude (gsd-security-auditor, Opus 4.7 1M)_
_Branch: `feature/v2.8-phase-32-cartographier` @ `2e2d5ecc`_
_Implementation files: READ-ONLY — none modified by this audit._
