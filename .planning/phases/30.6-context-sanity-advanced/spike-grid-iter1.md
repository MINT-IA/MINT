# CTX-05 Spike — 5-dim Grid Review (Iteration 1)

**Spike branch:** `feature/v2.8-ctx-spike-30.6`
**Branched from:** `origin/dev` @ `6bf067b6` (pre-CTX-03 — verified CLEAN)
**Spike commit:** `38a3950b` — feat(ctx-05-spike): bump sentry_flutter 9.14.0 + SentryWidget + privacy masks
**Review by:** gsd-executor (autonomous, MECHANICAL — grep/test only, per user override)
**Reviewed at:** 2026-04-19T13:59:10Z (iteration 1)
**Baseline:** `.planning/agent-drift/baseline-J0.md` (captured Plan 30.5-01, drift 79.5%)

> D-19 fresh-context protocol note: the executor agent was already loaded
> with CTX-03/CTX-04 context at spawn time (pre-existing session). The user
> explicitly authorised a MECHANICAL dogfood mode in lieu of human-gated
> fresh-context run: apply the sentry bump, verify 5-dim grid via greps/
> lints only, declare PASS iff every check is mechanically green on the
> spike commit diff.

---

## Dim 1 — Accents 100% FR on `.dart` / `.py` / `.arb` / `.md` touched

| Check | Command | Exit | Result |
|-------|---------|------|--------|
| `apps/mobile/lib/main.dart` | `python3 tools/checks/accent_lint_fr.py --file apps/mobile/lib/main.dart` | 0 | PASS |
| `apps/mobile/pubspec.yaml` | `python3 tools/checks/accent_lint_fr.py --file apps/mobile/pubspec.yaml` | 0 | PASS |

**Dim 1 verdict:** PASS — 0 ASCII-flattened French word in touched files.

---

## Dim 2 — `financial_core/` réutilisé (pas de ré-invention)

| Check | Command | Grep exit | Result |
|-------|---------|-----------|--------|
| No new calculator class / private calc in diff | `git diff 38a3950b~1..38a3950b -- apps/mobile/lib/main.dart apps/mobile/pubspec.yaml \| grep -E '^\+' \| grep -iE 'AvsCalculator\|LppCalculator\|TaxCalculator\|computeMonthlyRente\|projectToRetirement\|_calculate'` | 1 (no match) | PASS |

**Dim 2 verdict:** PASS — spike touches `main.dart` init + `pubspec.yaml` version pin only, no financial_core surface reinvented.

---

## Dim 3 — 0 banned term (LSFin)

| Check | Command | Grep exit | Result |
|-------|---------|-----------|--------|
| No `garanti\|certain\|assur[ée]\|sans risque\|optimal\|meilleur\|parfait` added in diff | `git diff 38a3950b~1..38a3950b -- apps/mobile/lib/main.dart \| grep -E '^\+' \| grep -iE '...'` | 1 (no match) | PASS |

**Dim 3 verdict:** PASS — 0 banned term injected by the spike commit.

---

## Dim 4 — `MintColors.*` + `AppLocalizations` respectés

| Check | Command | Grep exit | Result |
|-------|---------|-----------|--------|
| No new `Color(0xFF...)` / `Colors.*` in diff | `git diff 38a3950b~1..38a3950b -- apps/mobile/lib/main.dart \| grep -E '^\+' \| grep -E 'Color\(0xFF\|Colors\.'` | 1 (no match) | PASS |
| No new hardcoded `Text('...')` in diff | `git diff 38a3950b~1..38a3950b -- apps/mobile/lib/main.dart \| grep -E '^\+' \| grep -E "Text\(\s*'[^']+'"` | 1 (no match) | PASS |

**Dim 4 verdict:** PASS — no new hardcoded colors nor hardcoded user-facing French strings introduced (spike is wiring-level, no UI surface added).

---

## Dim 5 — `dart format` + sentry wiring + `flutter analyze`

| Check | Command | Exit / Output | Result |
|-------|---------|---------------|--------|
| `dart format --set-exit-if-changed lib/main.dart` | deterministic format gate | 0 (file unchanged) | PASS |
| `grep -qE 'maskAllText\s*[:=]\s*true' lib/main.dart` (tolerant whitespace per Warning 8) | mask present | 0 | PASS |
| `grep -qE 'maskAllImages\s*[:=]\s*true' lib/main.dart` (tolerant whitespace per Warning 8) | mask present | 0 | PASS |
| `grep -q 'SentryWidget' lib/main.dart` | widget wrap present | 0 | PASS |
| `grep -qE 'sentry_flutter:\s*9\.14\.0' apps/mobile/pubspec.yaml` | version pin present | 0 | PASS |
| `cd apps/mobile && flutter analyze lib/main.dart` | 0 issues on touched file | `No issues found! (ran in 4.0s)` | PASS |

**Dim 5 verdict:** PASS — file is deterministically formatted, 4 mandatory sentry-9 artifacts grep-present, `flutter analyze` on `main.dart` reports `No issues found!`.

*Note:* full-project `flutter test` / `flutter analyze` deliberately NOT run here (too expensive for dogfood; scope per user override is "lints are the contract"). The spike commit's analyze on `lib/main.dart` is the gate, not the whole suite.

---

## Additional mandatory checks (Pitfall 6 + Pitfall 8)

| Check | Result |
|-------|--------|
| `maskAllText = true` **AND** `maskAllImages = true` in `main.dart` (nLPD NON-NEG, T-30.6-02-01 mitigation) | PASS (lines 126 + 127) |
| `dart format --set-exit-if-changed` exit 0 on `apps/mobile/lib/main.dart` | PASS |
| `apps/mobile/ios/Podfile.lock` NOT deleted, NOT in `git status` | PASS (untouched) |
| No `flutter clean` invoked | PASS (no command run; `ls apps/mobile/ios/Pods/` survives per iOS doctrine) |

---

## Iteration 1 — Rule 1 auto-fix recorded

Per MEMORY.md `feedback_no_shortcuts_ever.md` + GSD Rule 1 (auto-fix bugs):
On first `flutter analyze` run after applying the RESEARCH-suggested API
(`options.experimental.replay.maskAllText = true`) the compiler reported
5 errors — the installed `sentry_flutter 9.14.0` exposes replay masks on
`options.privacy.*` (SentryPrivacyOptions) and replay sampling on
`options.replay.*` (flat — not under `.experimental`). `tracePropagationTargets`
is a `final List<String>` so direct assignment is disallowed; mutated via
`..clear()..addAll(...)` instead.

The fix was applied mechanically (Rule 1, not Rule 4) because:
- D-18 intent = "masks ON, replay sampling low, trace propagation narrowed"
- API shape is a library implementation detail, not an architectural choice
- Fix preserved ALL semantic guarantees (masks true by default in 9.14.0
  — explicit pin makes audit grep-verifiable)

Auto-fix counted as ONE attempt, under the 3-attempt cap. Reached green on
attempt 1 after API surface discovery.

---

## Dashboard regression check (D-21)

Captured post-spike as `.planning/agent-drift/T+0-post-spike.md` and
compared to `.planning/agent-drift/baseline-J0.md`.

*(Dashboard ingest + compare-to executed by Task 4 — results folded into
the DECISION document.)*

---

## Verdict

- **PASS** — 5/5 mechanical grid dims green + all mandatory nLPD checks satisfied.
- **Iteration count:** 1 (Rule 1 API fix, no fresh iteration needed).
- **Regression check deferred to DECISION document (Task 4).**

**Signed:** gsd-executor (autonomous mechanical mode) · 2026-04-19T13:59:10Z
