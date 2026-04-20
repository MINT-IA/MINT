---
phase: 32
plan: 0
plan_number: 00
slug: reconcile
type: execute
wave: 0
status: pending
depends_on: []
files_modified:
  - apps/mobile/test/routes/route_metadata_test.dart
  - apps/mobile/test/routes/route_meta_json_test.dart
  - apps/mobile/test/routes/legacy_redirect_breadcrumb_test.dart
  - apps/mobile/test/screens/admin/admin_shell_gate_test.dart
  - apps/mobile/test/screens/admin/routes_registry_screen_test.dart
  - apps/mobile/test/screens/admin/routes_registry_breadcrumb_test.dart
  - tests/tools/test_mint_routes.py
  - tests/tools/fixtures/sentry_health_response.json
  - tests/checks/fixtures/parity_drift.dart
  - tests/checks/fixtures/parity_known_miss.dart
  - tools/checks/route_registry_parity-KNOWN-MISSES.md
  - .planning/phases/32-cartographier/32-00-RECONCILE-REPORT.md
requirements:
  - MAP-01
  - MAP-04
  - MAP-05
threats: []
autonomous: true
must_haves:
  truths:
    - "Empirical grep confirms exactly 147 GoRoute/ScopedGoRoute path declarations in app.dart"
    - "Empirical grep confirms exactly 43 redirect call-sites in app.dart"
    - "RECONCILE-REPORT.md enumerates each of the 43 redirect call-sites with line number, source path, target path, branch count, and null-pass-through branch count (M-3 fix: replaces fragile `grep -c == 43` total with per-site expected breadcrumb emissions)"
    - "KNOWN-MISSES.md lists every regex-unparsable pattern observed in app.dart with file:line refs"
    - "Every downstream test file exists as a skipped stub referencing the right requirement ID"
    - "DRY_RUN fixture seeds 147-route response shape with zero live Sentry dependency"
  artifacts:
    - path: "apps/mobile/test/routes/route_metadata_test.dart"
      provides: "Stub for MAP-01 entry count + enum integrity"
    - path: "apps/mobile/test/routes/route_meta_json_test.dart"
      provides: "Stub for MAP-01 JSON shape stability"
    - path: "apps/mobile/test/routes/legacy_redirect_breadcrumb_test.dart"
      provides: "Stub for MAP-05 breadcrumb shape"
    - path: "apps/mobile/test/screens/admin/admin_shell_gate_test.dart"
      provides: "Stub for MAP-02b compile+runtime gate"
    - path: "apps/mobile/test/screens/admin/routes_registry_screen_test.dart"
      provides: "Stub for MAP-02b render"
    - path: "apps/mobile/test/screens/admin/routes_registry_breadcrumb_test.dart"
      provides: "Stub for D-09 §4 admin-access breadcrumb"
    - path: "tests/tools/test_mint_routes.py"
      provides: "12+ pytest stubs enumerated in VALIDATION.md"
    - path: "tests/tools/fixtures/sentry_health_response.json"
      provides: "147-route DRY_RUN fixture"
    - path: "tools/checks/route_registry_parity-KNOWN-MISSES.md"
      provides: "Regex-unparsable catalog from live app.dart grep"
    - path: ".planning/phases/32-cartographier/32-00-RECONCILE-REPORT.md"
      provides: "Recorded empirical counts + extraction sha + 43-redirect per-site enumeration + any drift findings"
  key_links:
    - from: "Wave 0 grep counts"
      to: "Wave 1 kRouteRegistry size assertion (147)"
      via: "tests/routes/route_metadata_test.dart expects 147"
      pattern: "kRouteRegistry.length == 147"
    - from: "Wave 0 RECONCILE-REPORT.md §Redirect Call-Site Inventory"
      to: "Wave 3 per-site breadcrumb coverage test"
      via: "tests/tools/test_redirect_breadcrumb_coverage.py asserts expected call counts per site"
      pattern: "sum of expected emissions across 43 sites matches MintBreadcrumbs.legacyRedirectHit grep count"
    - from: "Wave 0 KNOWN-MISSES.md examples"
      to: "Wave 4 parity lint KNOWN-MISSES fixture"
      via: "tests/checks/fixtures/parity_known_miss.dart sourced from real patterns"
      pattern: "parity_known_miss fixture cases match KNOWN-MISSES categories"
---

<objective>
Wave 0 reconciliation gate — empirically verify 147 routes + 43 redirects in `apps/mobile/lib/app.dart`, extract every regex-unparsable pattern into `KNOWN-MISSES.md`, enumerate each of the 43 redirect call-sites with branch structure (M-3 fix for breadcrumb coverage), and scaffold every downstream test + fixture Wave 1-4 depends on (11 files). Blocks Wave 1 until green. Single atomic commit before any production code is written. Maps to ROADMAP Success Criterion 1 (registry foundation) + Success Criterion 5 (parity lint foundation) + Success Criterion 6 (redirect foundation).
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT/.claude/get-shit-done/workflows/execute-plan.md
@/Users/julienbattaglia/Desktop/MINT/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/ROADMAP.md
@.planning/REQUIREMENTS.md
@.planning/STATE.md
@.planning/phases/32-cartographier/32-CONTEXT.md
@.planning/phases/32-cartographier/32-RESEARCH.md
@.planning/phases/32-cartographier/32-VALIDATION.md
@apps/mobile/lib/app.dart
@CLAUDE.md

<interfaces>
<!-- From apps/mobile/lib/app.dart: existing GoRoute/ScopedGoRoute shape -->

ScopedGoRoute(
  path: '/auth/login',
  scope: RouteScope.public,
  builder: (context, state) => const LoginScreen(),
)

GoRoute(
  path: '/home',
  builder: (context, state) { ... }
)

// Redirect call-site shape (43 instances, may have 1+ branches each):
ScopedGoRoute(path: '/report', redirect: (_, __) => '/rapport'),

// Multi-branch redirect (null pass-through — counts as 1 site, 1 breadcrumb emission only when redirect taken):
ScopedGoRoute(path: '/profile', redirect: (_, state) {
  if (state.uri.path == '/profile') return '/profile/bilan';
  return null; // pass-through; NO breadcrumb emission
})

<!-- Phase 31 D-03 breadcrumb naming convention (for legacy_redirect test stub): -->
// mint.<domain>.<subject>.<outcome>
// Wave 3 will ship: mint.routing.legacy_redirect.hit
</interfaces>
</context>

<threat_model>
No new threats introduced by Wave 0 — test scaffolds only. Threats T-32-01..05 enter at Waves 1-4.
</threat_model>

<tasks>

<task type="auto">
  <name>Task 1: Empirical reconciliation grep (147 routes + 43 redirects) + per-site redirect enumeration + RECONCILE-REPORT.md</name>
  <files>.planning/phases/32-cartographier/32-00-RECONCILE-REPORT.md</files>
  <read_first>
    - /Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/app.dart (current state, 147 GoRoute + 43 redirect source of truth)
    - /Users/julienbattaglia/Desktop/MINT/.planning/phases/32-cartographier/32-CONTEXT.md (D-01 owner ambiguity, D-04 known-miss categories, D-05 redirect count)
    - /Users/julienbattaglia/Desktop/MINT/.planning/phases/32-cartographier/32-RESEARCH.md §4 Parity lint (regex, wave-0 extraction flow, lines 622-676)
    - /Users/julienbattaglia/Desktop/MINT/.planning/phases/32-cartographier/32-VALIDATION.md Per-Task Verification Map (tasks 32-00-01..03)
  </read_first>
  <action>
    Produce `.planning/phases/32-cartographier/32-00-RECONCILE-REPORT.md` capturing empirical counts against current app.dart. Structure:

    ```markdown
    # Phase 32 Wave 0 — Reconciliation Report
    **Date:** {YYYY-MM-DD}
    **app.dart SHA:** {`git log -n 1 --pretty=format:%h apps/mobile/lib/app.dart`}

    ## Route count (MAP-01 foundation)
    Command: `grep -cE "^\s*(GoRoute|ScopedGoRoute)\(" apps/mobile/lib/app.dart`
    Result: 147  (expected 147 per CONTEXT v4)
    Drift: NONE  (or: +/- N with explanation)

    ## Redirect count (MAP-05 foundation)
    Command: `grep -cE "redirect:\s*\(_,\s*_?_?\)" apps/mobile/lib/app.dart`
    Result: 43  (expected 43 per CONTEXT v4)
    Drift: NONE

    ## Redirect Call-Site Inventory (M-3 fix — per-site breadcrumb coverage contract)

    This table is the CONTRACT that Plan 03 Task 2 consumes. For each of the 43 redirect
    call-sites: the line number, source-path pattern, target path(s), number of
    redirect-taking branches (each emits 1 breadcrumb when taken), and number of
    null-pass-through branches (emit 0 breadcrumbs — go_router continues matching).

    The sum of `redirect_branches` across all 43 rows = expected TOTAL breadcrumb
    emissions if every branch were taken exactly once. A simple drive-through test
    won't hit every branch, so Plan 03 Task 2 asserts:

    1. Each call-site's callback BODY contains exactly `redirect_branches` calls to
       `MintBreadcrumbs.legacyRedirectHit` (static count, AST-free via regex).
    2. Sum of `grep -c "MintBreadcrumbs.legacyRedirectHit" app.dart` >= 43
       (loose lower bound — some sites have multiple branches).

    | # | line | source pattern | target(s) | redirect_branches | null_pass_through | callback signature |
    |---|------|----------------|-----------|-------------------|-------------------|--------------------|
    | 1 | {L}  | `/report`      | `/rapport` | 1 | 0 | `(_, __) => '/rapport'` |
    | 2 | {L}  | `/report/v2`   | `/rapport` | 1 | 0 | `(_, __) => '/rapport'` |
    | ... | ... | ... | ... | ... | ... | ... |
    | 42 | {L} | `/profile` + sub-routes | `/profile/bilan` (only when path == '/profile') | 1 | 1 | `(_, state) { if (…) return '/profile/bilan'; return null; }` |
    | 43 | {L} | ... | ... | ... | ... | ... |

    **Totals:**
    - Total sites: 43
    - Total `redirect_branches` (expected MintBreadcrumbs.legacyRedirectHit source-call count in app.dart): {SUM, e.g., 43 if all single-branch, >43 if any multi-branch}
    - Total `null_pass_through` branches: {SUM} (informational — these emit zero breadcrumbs)

    ## Extracted paths (full list for Wave 1 kRouteRegistry)
    ```
    /
    /auth/login
    /auth/register
    ...
    ```

    ## Known-miss patterns found (for D-04 KNOWN-MISSES.md)
    | Category | app.dart line | Pattern snippet | Parity lint behavior |
    |----------|---------------|-----------------|----------------------|
    | Multi-line constructor | 281-285 | ScopedGoRoute(\n  path: '/',\n  ... | DOTALL regex handles |
    | Ternary path | - | - | (none observed OR: line X) |
    | Dynamic builder | - | - | (none observed OR: line X) |
    | Conditional route list | 905-925 | Profile sub-routes inside parent route's `routes: [...]` | Parent captured, children nested |

    ## Owner assignment pre-audit (D-01 v4 first-segment-wins)
    List any ambiguous route where first-segment rule produces counterintuitive owner:
    - /explore/retraite → owner=explore (NOT retraite) — intentional per D-01
    - ...

    ## Verdict
    [ ] Counts match CONTEXT v4 — proceed to Wave 1
    [ ] Counts drift — STOP, amend CONTEXT first
    ```

    Procedure (execute in this order, capture every output):

    1. Run `git log -n 1 --pretty=format:%h apps/mobile/lib/app.dart` — record SHA.
    2. Run `grep -cE "^\s*(GoRoute|ScopedGoRoute)\(" apps/mobile/lib/app.dart` — record count. MUST equal 147; if not, STOP, do not proceed to later tasks, report to user.
    3. Run `grep -cE "redirect:\s*\(_,\s*_?_?\)" apps/mobile/lib/app.dart` — record count. MUST equal 43; if not, STOP and report.
    4. Run `grep -nE "^\s*(GoRoute|ScopedGoRoute)\(" apps/mobile/lib/app.dart | wc -l` to verify line-anchored match count matches step 2 (should equal).
    5. Extract ALL path literals: `python3 -c "import re; src=open('apps/mobile/lib/app.dart').read(); m=re.findall(r'''(?:GoRoute|ScopedGoRoute)\s*\([^)]*?path\s*:\s*(['\"])([^'\"]+)\1''', src, re.DOTALL); print('\n'.join(sorted(set(p[1] for p in m))))"` — redirect paths ARE included (they use `path:` too). Capture full list into the report.
    6. **Per-site redirect enumeration (M-3 fix).** For each of the 43 redirect call-sites:
       - Locate the `ScopedGoRoute(path: 'X', redirect: …)` block (grep -n; pair with next `)`).
       - Count `return '<path>';` statements inside the callback — that is `redirect_branches`.
       - Count `return null;` statements — that is `null_pass_through`.
       - Record the callback signature literally (e.g., `(_, __) => '/rapport'` for arrow form, or `(_, state) { … }` for block form).
       - For the profile sub-route case (app.dart:906-912 per CONTEXT v4), expect `redirect_branches=1, null_pass_through=1`.
       - Fill the inventory table row by row (43 rows total).
    7. Inspect for each D-04 known-miss category (ternary `? :`, dynamic `_buildPath`, nested `routes: [...]`). Cite line numbers. If any multi-line constructor uses comments between `(` and `path:`, note it (DOTALL handles basic cases).
    8. Audit owner-ambiguity edge cases: grep for `/explore/retraite`, `/coach/chat/from-budget` and any multi-segment path whose second segment matches an enum value. Document first-segment-winner per D-01 v4.
    9. Write the report using the structure above with real values, then commit.

    Language: all code-comments/log-prose in French-respecting ASCII-only for clarity; the report is technical English (no user-facing FR strings, no banned LSFin terms). No hardcoded paths — always relative to repo root.

    No production code modified — this task produces a markdown artifact only.
  </action>
  <verify>
    <automated>test -f /Users/julienbattaglia/Desktop/MINT/.planning/phases/32-cartographier/32-00-RECONCILE-REPORT.md && grep -q "Result: 147" /Users/julienbattaglia/Desktop/MINT/.planning/phases/32-cartographier/32-00-RECONCILE-REPORT.md && grep -q "Result: 43" /Users/julienbattaglia/Desktop/MINT/.planning/phases/32-cartographier/32-00-RECONCILE-REPORT.md && grep -q "Redirect Call-Site Inventory" /Users/julienbattaglia/Desktop/MINT/.planning/phases/32-cartographier/32-00-RECONCILE-REPORT.md</automated>
  </verify>
  <acceptance_criteria>
    - `.planning/phases/32-cartographier/32-00-RECONCILE-REPORT.md` exists
    - Report contains literal strings "Result: 147" AND "Result: 43"
    - Report contains "Redirect Call-Site Inventory" section with a table containing exactly 43 enumerated rows (one per call-site)
    - Every inventory row has: line number, source pattern, target(s), redirect_branches (int), null_pass_through (int), callback signature
    - Report contains "Totals:" with an explicit sum of `redirect_branches` across all 43 rows — this sum is the expected source-call count of `MintBreadcrumbs.legacyRedirectHit` that Plan 03 Task 2 asserts
    - Report contains app.dart SHA (short hash, 7+ chars)
    - Report contains extracted path list ≥147 lines
    - Report contains a "Verdict" section with one checkbox marked
    - If drift detected, report explicitly says "STOP" and lists drifts
  </acceptance_criteria>
  <done>Empirical counts captured, per-site redirect branch structure enumerated (M-3 contract), known-miss categories audited, report committed. Wave 1 can trust the 147/43 contract AND Wave 3 can assert per-site breadcrumb coverage.</done>
</task>

<task type="auto">
  <name>Task 2: Populate KNOWN-MISSES.md from real app.dart patterns</name>
  <files>tools/checks/route_registry_parity-KNOWN-MISSES.md</files>
  <read_first>
    - /Users/julienbattaglia/Desktop/MINT/.planning/phases/32-cartographier/32-00-RECONCILE-REPORT.md (just produced by Task 1)
    - /Users/julienbattaglia/Desktop/MINT/.planning/phases/32-cartographier/32-CONTEXT.md (D-04)
    - /Users/julienbattaglia/Desktop/MINT/.planning/phases/32-cartographier/32-RESEARCH.md §4 known-miss categories (lines 641-656)
    - /Users/julienbattaglia/Desktop/MINT/apps/mobile/lib/app.dart (cite exact lines)
    - /Users/julienbattaglia/Desktop/MINT/tools/checks/accent_lint_fr.py (existing lint style — argparse + stdlib shape)
  </read_first>
  <action>
    Create `tools/checks/route_registry_parity-KNOWN-MISSES.md`. Structure (copy verbatim, fill from Task 1 report):

    ```markdown
    # Route Registry Parity — Known Regex Misses

    Purpose: document every `GoRoute`/`ScopedGoRoute` path declaration in `apps/mobile/lib/app.dart`
    that `tools/checks/route_registry_parity.py` intentionally skips because its regex cannot
    safely extract the path without a full Dart AST parser.

    Parity lint contract: paths listed here are **silently ignored** — they are not treated
    as missing from `kRouteRegistry`. Maintainers MUST update this file when a new unparsable
    pattern is introduced, or the parity lint gate will false-positive and block CI.

    ## Category 1 — Multi-line constructor with intervening comments
    The `re.DOTALL` flag handles simple multi-line cases. If a comment block sits between
    `(` and `path:` with a `)` literal inside a string, the regex may truncate early.

    Current occurrences:
    - {line X}: <paste snippet from app.dart>  (or "none observed in HEAD-{sha}")

    ## Category 2 — Ternary path expression
    Regex cannot trace `path: isNew ? '/v2' : '/legacy'`.

    Current occurrences:
    - {line X}: <paste snippet>  (or "none observed")

    ## Category 3 — Dynamic path builder
    Regex cannot trace `path: _buildPath(segment)` or similar.

    Current occurrences:
    - {line X}: <paste>  (or "none observed")

    ## Category 4 — Conditional route list (if/else branch containing GoRoute)
    The route is captured, but the conditional context is lost. Parity lint treats as
    "exists". Acceptable per D-04.

    Current occurrences:
    - {line X}: <paste>  (or "none observed")

    ## Category 5 — Nested `routes: [...]` inside parent `ScopedGoRoute`
    Parent route's own `path:` is captured normally; nested children inherit prefix at
    runtime (e.g., `/profile` + `admin-observability` → `/profile/admin-observability`).
    Parity lint treats nested entries as plain paths when `path: 'admin-observability'`
    declared under parent with `path: '/profile'`. Maintainers MUST register the full
    composed path in `kRouteRegistry` (e.g., `/profile/admin-observability`) — the
    parity lint has a hint mode for this (see `--resolve-nested` flag, Wave 4).

    Current occurrences (paste 3-5 representative pairs from app.dart):
    - parent L906 `/profile` + child L915 `admin-observability` → `/profile/admin-observability`
    - parent L{X} `{Y}` + child L{Z} `{W}` → `{Y}/{W}`
    - ...

    ## Maintenance policy
    When `tools/checks/route_registry_parity.py` reports an unexpected miss on `main`:
    1. Reproduce locally: `python3 tools/checks/route_registry_parity.py`.
    2. Classify the pattern into a category above (or add a new numbered category).
    3. Append the snippet with file:line reference.
    4. Re-run the lint; it should exit 0.
    5. Commit `KNOWN-MISSES.md` change + production change together.
    ```

    Fill all `{line X}` / `{Y}` placeholders using data from Task 1 report. Every category gets either a real example from app.dart OR the literal string "none observed in HEAD-{SHA7}". Do not leave any `{placeholder}` unfilled.

    Accent rule: all comments/prose in ASCII-only English — this is a developer doc, not user-facing.
  </action>
  <verify>
    <automated>test -f /Users/julienbattaglia/Desktop/MINT/tools/checks/route_registry_parity-KNOWN-MISSES.md && grep -q "Category 5" /Users/julienbattaglia/Desktop/MINT/tools/checks/route_registry_parity-KNOWN-MISSES.md && ! grep -q "{line X}\|{Y}\|{Z}\|{SHA7}\|{placeholder}" /Users/julienbattaglia/Desktop/MINT/tools/checks/route_registry_parity-KNOWN-MISSES.md</automated>
  </verify>
  <acceptance_criteria>
    - `tools/checks/route_registry_parity-KNOWN-MISSES.md` exists
    - File contains 5 numbered categories + Maintenance policy section
    - No unfilled `{placeholder}` strings remain
    - Every category lists either specific file:line examples OR the literal "none observed"
    - Category 5 cites at least 1 nested route example from app.dart (lines 906-925 has `/profile/admin-observability` pattern)
  </acceptance_criteria>
  <done>KNOWN-MISSES doctrine documented from empirical evidence. Wave 4 parity lint has a ground truth to respect.</done>
</task>

<task type="auto">
  <name>Task 3: Scaffold 6 Flutter test stubs + 4 fixture files + 1 Python test stub</name>
  <files>apps/mobile/test/routes/route_metadata_test.dart, apps/mobile/test/routes/route_meta_json_test.dart, apps/mobile/test/routes/legacy_redirect_breadcrumb_test.dart, apps/mobile/test/screens/admin/admin_shell_gate_test.dart, apps/mobile/test/screens/admin/routes_registry_screen_test.dart, apps/mobile/test/screens/admin/routes_registry_breadcrumb_test.dart, tests/tools/test_mint_routes.py, tests/tools/fixtures/sentry_health_response.json, tests/checks/fixtures/parity_drift.dart, tests/checks/fixtures/parity_known_miss.dart</files>
  <read_first>
    - /Users/julienbattaglia/Desktop/MINT/.planning/phases/32-cartographier/32-VALIDATION.md Wave 0 Requirements + Per-Task Verification Map
    - /Users/julienbattaglia/Desktop/MINT/.planning/phases/32-cartographier/32-RESEARCH.md §Environment Availability (Python 3.9-compat requirement)
    - /Users/julienbattaglia/Desktop/MINT/.planning/phases/31-instrumenter/31-CONTEXT.md (Wave 0 scaffolding pattern — 31-00-PLAN precedent)
    - /Users/julienbattaglia/Desktop/MINT/apps/mobile/test/ (existing test style — flutter_test imports, group/test structure)
    - /Users/julienbattaglia/Desktop/MINT/services/backend/tests/ (existing pytest style — if any sample shows pytest.skip("Wave 1 implements") pattern)
  </read_first>
  <action>
    Create 10 scaffold files. Every test is SKIPPED with a reason message pointing to the Wave/Plan that implements it. Zero production code imported (the production files don't exist yet). Tests must COMPILE green but RUN as "skipped".

    **File 1 — `apps/mobile/test/routes/route_metadata_test.dart`:**
    ```dart
    // Phase 32 Wave 0 stub — MAP-01 entry count + enum integrity.
    // Implementation: Plan 32-01 Wave 1.
    import 'package:flutter_test/flutter_test.dart';

    void main() {
      group('kRouteRegistry (MAP-01)', () {
        test('has exactly 147 entries', () {
          // Will import kRouteRegistry from apps/mobile/lib/routes/route_metadata.dart
          // and assert kRouteRegistry.length == 147.
        }, skip: 'Plan 32-01 Wave 1 implements route_metadata.dart');

        test('all 15 RouteOwner enum values are used at least once', () {
        }, skip: 'Plan 32-01 Wave 1');

        test('every RouteCategory enum value has entries', () {
        }, skip: 'Plan 32-01 Wave 1');

        test('owner ambiguity rule: /explore/retraite owner=explore (D-01 v4 first-segment)', () {
        }, skip: 'Plan 32-01 Wave 1');
      });
    }
    ```

    **File 2 — `apps/mobile/test/routes/route_meta_json_test.dart`:**
    ```dart
    // Phase 32 Wave 0 stub — MAP-01 JSON shape stability + schemaVersion:1 contract.
    // Implementation: Plan 32-01 Wave 1 + Plan 32-02 Wave 2 (schema publication).
    import 'package:flutter_test/flutter_test.dart';

    void main() {
      group('RouteHealthJsonContract (MAP-03)', () {
        test('kRouteHealthSchemaVersion == 1 (byte-stable across builds)', () {
        }, skip: 'Plan 32-02 Wave 2 publishes route_health_schema.dart');

        test('emitted JSON matches documented contract example', () {
        }, skip: 'Plan 32-02 Wave 2');
      });
    }
    ```

    **File 3 — `apps/mobile/test/routes/legacy_redirect_breadcrumb_test.dart`:**
    ```dart
    // Phase 32 Wave 0 stub — MAP-05: 43 redirects emit mint.routing.legacy_redirect.hit.
    // Implementation: Plan 32-03 Wave 3.
    import 'package:flutter_test/flutter_test.dart';

    void main() {
      group('legacyRedirectHit breadcrumb (MAP-05)', () {
        test('redirect /report -> /rapport emits category mint.routing.legacy_redirect.hit', () {
        }, skip: 'Plan 32-03 Wave 3 wires legacyRedirectHit in app.dart');

        test('breadcrumb data contains from+to paths, NO query params, NO user context', () {
        }, skip: 'Plan 32-03 Wave 3 (D-09 §2 redaction)');
      });
    }
    ```

    **File 4 — `apps/mobile/test/screens/admin/admin_shell_gate_test.dart`:**
    ```dart
    // Phase 32 Wave 0 stub — MAP-02b gate: ENABLE_ADMIN=1 AND FeatureFlags.isAdmin.
    // Implementation: Plan 32-03 Wave 3.
    import 'package:flutter_test/flutter_test.dart';

    void main() {
      group('AdminGate (MAP-02b, D-10)', () {
        test('AdminGate.isAvailable=false when ENABLE_ADMIN=0', () {
        }, skip: 'Plan 32-03 Wave 3 implements AdminGate');

        test('AdminGate.isAvailable=true only when both compile-time + runtime flags set', () {
        }, skip: 'Plan 32-03 Wave 3');
      });
    }
    ```

    **File 5 — `apps/mobile/test/screens/admin/routes_registry_screen_test.dart`:**
    ```dart
    // Phase 32 Wave 0 stub — MAP-02b render: 147 routes grouped by 15 owner buckets.
    // Implementation: Plan 32-03 Wave 3.
    import 'package:flutter_test/flutter_test.dart';

    void main() {
      group('RoutesRegistryScreen (MAP-02b)', () {
        test('renders 147 route rows total', () {
        }, skip: 'Plan 32-03 Wave 3');

        test('groups rendered as 15 collapsible owner buckets', () {
        }, skip: 'Plan 32-03 Wave 3');

        test('empty-state text when kRouteRegistry.isEmpty', () {
        }, skip: 'Plan 32-03 Wave 3');

        test('footer note points to CLI for live health', () {
        }, skip: 'Plan 32-03 Wave 3 (D-06 footer)');
      });
    }
    ```

    **File 6 — `apps/mobile/test/screens/admin/routes_registry_breadcrumb_test.dart`:**
    ```dart
    // Phase 32 Wave 0 stub — D-09 §4: adminRoutesViewed aggregates only, no PII.
    // Implementation: Plan 32-03 Wave 3.
    import 'package:flutter_test/flutter_test.dart';

    void main() {
      group('MintBreadcrumbs.adminRoutesViewed (D-09 §4)', () {
        test('emits mint.admin.routes.viewed category', () {
        }, skip: 'Plan 32-03 Wave 3');

        test('data contains route_count, feature_flags_enabled_count, snapshot_age_minutes', () {
        }, skip: 'Plan 32-03 Wave 3');

        test('data has NO user.id, NO email, NO route-specific keys', () {
        }, skip: 'Plan 32-03 Wave 3 (nLPD Art. 12 aggregates only)');
      });
    }
    ```

    **File 7 — `tests/tools/test_mint_routes.py`** (Python 3.9-compatible syntax per executor_discretion_pre_locked item 4 — use `Optional[X]`, `Union[X, Y]`, NO `match/case`, NO `dict | dict` merge, NO PEP 604 `X | Y`):
    ```python
    """Phase 32 Wave 0 stub — 12+ pytest cases for MAP-02a CLI behavior.

    Implementation: Plan 32-02 Wave 2.
    Python version: 3.9-compatible (dev machine has 3.9.6; CI runs 3.11).
    """

    import pytest


    @pytest.mark.skip(reason="Plan 32-02 Wave 2 implements CLI")
    def test_health_dry_run():
        """MINT_ROUTES_DRY_RUN=1 reads fixture, emits JSON matching schema."""
        pass


    @pytest.mark.skip(reason="Plan 32-02 Wave 2")
    def test_exit_codes():
        """Exit codes match sysexits.h: 0, 2, 71, 75, 78."""
        pass


    @pytest.mark.skip(reason="Plan 32-02 Wave 2 (D-09 §2 redaction)")
    def test_pii_redaction():
        """Redacts IBAN (CH/all), CHF>100, email, user.{id,email,ip,username}, AVS 756.xxxx.xxxx.xx."""
        pass


    @pytest.mark.skip(reason="Plan 32-02 Wave 2 (no-color.org compliance)")
    def test_no_color():
        """--no-color flag AND NO_COLOR env both suppress ANSI."""
        pass


    @pytest.mark.skip(reason="Plan 32-02 Wave 2")
    def test_keychain_fallback():
        """Env var wins; else subprocess.run(['security','find-generic-password','-s','SENTRY_AUTH_TOKEN','-w'])."""
        pass


    @pytest.mark.skip(reason="Plan 32-02 Wave 2")
    def test_batch_chunking():
        """147 routes split into chunks of 30 -> 5 chunks."""
        pass


    @pytest.mark.skip(reason="Plan 32-02 Wave 2")
    def test_status_classification():
        """classify(route, sentry_24h, ff_state, last_visit) -> green/yellow/red/dead."""
        pass


    @pytest.mark.skip(reason="Plan 32-02 Wave 2")
    def test_json_output_schema():
        """--json emits newline-delimited JSON matching route_health_schema.dart contract."""
        pass


    @pytest.mark.skip(reason="Plan 32-02 Wave 2")
    def test_schema_contract_parity():
        """Python JSON output vs Dart kRouteHealthSchemaVersion=1 contract — drift check."""
        pass


    @pytest.mark.skip(reason="Plan 32-02 Wave 2")
    def test_redirects_aggregation():
        """CLI `redirects` subcommand aggregates 30d breadcrumb hits per legacy path."""
        pass


    @pytest.mark.skip(reason="Plan 32-02 Wave 2 (D-09 §3 retention)")
    def test_cache_ttl():
        """7-day auto-delete on startup + purge-cache command."""
        pass


    @pytest.mark.skip(reason="Plan 32-02 Wave 2 (D-02 error differentiation)")
    def test_sentry_error_mapping():
        """401 -> exit 78 token invalid; 403+'scope' -> exit 78 missing scope; 429 -> exit 75 after backoff; timeout -> exit 75."""
        pass
    ```

    **File 8 — `tests/tools/fixtures/sentry_health_response.json`** (147-route DRY_RUN fixture. Use Task 1 extracted path list to produce 147 entries. Shape follows Sentry Issues API response):
    ```json
    {
      "_meta": {
        "fixture_version": 1,
        "generated_by": "Phase 32 Wave 0 (plan 32-00)",
        "route_count": 147,
        "notes": "DRY_RUN fixture. Covers status classification edge cases: green/yellow/red/dead."
      },
      "issues": [
        {"transaction": "/", "count_24h": 0, "last_seen": null, "level": "info"},
        {"transaction": "/auth/login", "count_24h": 0, "last_seen": null, "level": "info"},
        {"transaction": "/coach/chat", "count_24h": 3, "last_seen": "2026-04-20T10:00:00Z", "level": "warning"},
        {"transaction": "/budget", "count_24h": 15, "last_seen": "2026-04-20T11:00:00Z", "level": "error"},
        ...147 entries total covering every path from Task 1 report...
      ]
    }
    ```

    Populate `issues[]` with exactly 147 objects, one per extracted path. Distribute `count_24h` values to hit all 4 status classes:
    - 3 entries with count_24h >= 10 (red status)
    - 5 entries with count_24h in [1, 9] (yellow)
    - 139 entries with count_24h == 0 AND last_seen within 30d (green)
    - (dead class tested separately via last_seen=null paths in the same fixture)

    **File 9 — `tests/checks/fixtures/parity_drift.dart`:**
    ```dart
    // Phase 32 Wave 0 fixture — parity lint drift test case.
    // Used by tools/checks/route_registry_parity.py --dry-run-fixture.
    // Expected behavior: parity lint MUST exit non-zero when
    // app.dart has a GoRoute absent from kRouteRegistry.

    // Simulated app.dart snippet (has routes):
    // GoRoute(path: '/a', ...)
    // GoRoute(path: '/b', ...)
    // GoRoute(path: '/c-drift-only-in-code', ...)  // <-- drift

    // Simulated kRouteRegistry keys: ['/a', '/b']
    // Expected: lint exits 1, stderr mentions '/c-drift-only-in-code'.
    ```

    **File 10 — `tests/checks/fixtures/parity_known_miss.dart`:**
    ```dart
    // Phase 32 Wave 0 fixture — parity lint KNOWN-MISSES respect test.
    // Expected behavior: parity lint MUST exit 0 when the only "missing"
    // paths are documented in KNOWN-MISSES.md categories (ternary, dynamic).

    // Simulated app.dart snippet (unparsable):
    // GoRoute(path: isNew ? '/v2' : '/legacy', ...)     // Category 2 ternary
    // GoRoute(path: _buildDynamicPath(seg), ...)        // Category 3 dynamic

    // Simulated kRouteRegistry keys: []
    // Expected: lint exits 0, stderr lists these as known-miss acknowledged.
    ```

    After creating all 10 files, run compilation smoke:
    - Flutter stubs: `cd apps/mobile && flutter test test/routes/ test/screens/admin/ 2>&1 | grep -E "All tests passed|skipped"` — all should be skipped, none failed.
    - Python stub: `python3 -c "import tests.tools.test_mint_routes; print('OK')"` — must import cleanly.
    - JSON fixture: `python3 -c "import json; d=json.load(open('tests/tools/fixtures/sentry_health_response.json')); assert d['_meta']['route_count']==147; assert len(d['issues'])==147; print('OK 147 entries')"`.

    Record all three results in the RECONCILE-REPORT.md §Scaffolding section (append-edit, no re-write).
  </action>
  <verify>
    <automated>cd /Users/julienbattaglia/Desktop/MINT && python3 -c "import json; d=json.load(open('tests/tools/fixtures/sentry_health_response.json')); assert d['_meta']['route_count']==147 and len(d['issues'])==147, f'expected 147 got meta={d[\"_meta\"][\"route_count\"]} issues={len(d[\"issues\"])}'; print('OK')" && (cd apps/mobile && flutter test test/routes/route_metadata_test.dart test/routes/route_meta_json_test.dart test/routes/legacy_redirect_breadcrumb_test.dart test/screens/admin/ 2>&1 | tail -5)</automated>
  </verify>
  <acceptance_criteria>
    - All 10 files exist at specified paths (`ls` confirms)
    - `tests/tools/fixtures/sentry_health_response.json` has `_meta.route_count=147` AND `len(issues)==147`
    - Flutter test stubs compile (no analyzer errors) AND all report "skipped"
    - Python stub imports cleanly via `python3 -c "import tests.tools.test_mint_routes"` (or direct file execute via `python3 -m pytest tests/tools/test_mint_routes.py --collect-only -q` shows 12 collected)
    - Every `pytest.mark.skip(...)` has non-empty `reason=` string
    - Every Flutter `skip:` has non-empty reason pointing to a Plan number
  </acceptance_criteria>
  <done>11 scaffolding artifacts land as single atomic commit. Wave 1-4 have a test bed to flip skip→green as implementation lands.</done>
</task>

</tasks>

<verification>
End-of-plan gate (must be green before Wave 1 starts):
- `.planning/phases/32-cartographier/32-00-RECONCILE-REPORT.md` exists with 147/43 counts recorded AND 43-row Redirect Call-Site Inventory populated.
- `tools/checks/route_registry_parity-KNOWN-MISSES.md` exists with 5 categories populated from real evidence.
- 6 Flutter test stubs + 1 Python pytest stub + 1 JSON fixture + 2 Dart parity fixtures committed.
- All Flutter test stubs run and report "skipped" (0 failures, 0 compilation errors).
- Python pytest stub collects 12 tests (all skipped).

Single commit: `feat(32): Wave 0 reconciliation + test scaffolds (147 routes / 43 redirects / 12 pytest stubs)`.
</verification>

<success_criteria>
- Empirical grep proves CONTEXT v4 counts (147 routes, 43 redirects) — OR drift escalated to user
- 43-row Redirect Call-Site Inventory published (M-3 fix — Plan 03 Task 2 consumes this as its contract instead of a fragile `== 43` total assertion)
- KNOWN-MISSES.md catalog built from live evidence, not speculation
- 11 test/fixture scaffolds land so Wave 1-4 can ship incrementally without "test harness missing" blockers
- Zero production code written yet — Wave 0 is pure reconciliation + scaffolding per feedback_facade_sans_cablage
</success_criteria>

<output>
After Wave 0 completion, create `.planning/phases/32-cartographier/32-00-SUMMARY.md` with:
- Empirical counts (paste from RECONCILE-REPORT.md)
- 43-row Redirect Call-Site Inventory summary (totals only)
- Files created (list all 10 scaffolds + 2 reports)
- Commit SHA
- Wave 1 unblock confirmation
</output>
</content>
