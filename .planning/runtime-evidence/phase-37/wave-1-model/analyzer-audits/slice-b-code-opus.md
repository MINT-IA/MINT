## MINT External Audit — Phase 37 (code mode)

**Scope:** `e266da836` vs base `be42b9e6e` — 16 files, +39/−44 lines. Commit `refactor(mobile): clean analyzer widget tests`. **Zero production (`lib/`) files touched**; the diff is entirely test-file analyzer cleanup.

### Verification performed
- **Removed imports are genuinely unused** — `dart analyze` clean on all 15 changed files after `flutter pub get --offline`. Verified `minimal_profile_models.dart` (sophie/thomas), `coach_profile.dart` (chat_data_capture), `go_router` (core_app_screens), and `dart:ui` (error_boundary) are not referenced. The `dart:ui` removal was the one real compile-break risk (file uses `ErrorCallback`/`PlatformDispatcher`); confirmed empirically it still compiles — `ErrorCallback` resolves transitively (`error_boundary_ordering_test.dart` → `No issues found!`).
- **`final`→`const` conversions** (`annual`, `nonce`, `conversationId`, widget ctors, `fields` lists) are all valid compile-time constants — analyzer clean, no identity-semantics test relies on instance uniqueness.
- **Private→public local renames** (`_cardWithConfidence`→`cardWithConfidence`, `_expectAllKeys`→`expectAllKeys`, `tester_passes`→`testerPasses`) have all call sites updated in-diff.
- **No coverage loss** — no `test(...)` blocks removed or skipped; the only removed body content is 5 import lines (net −5 matches diff stat). Accent/comment edits (`premier éclairage`) are cosmetic and touch no assertion logic.
- **Runtime proof** — ran a representative subset (journeys, apple_sign_in, error_boundary ordering, chat_data_capture, commitment_card, batch/confirm bubbles, confidence_score_card, mint_trame_confiance): **138/138 passed.**

### Findings

**P0:** none.

**P1:** none.

**P2 (pre-existing, not introduced by this diff — informational):**
- `test/screens/calculator_prefill_writeback_test.dart:235` and `:247` — `dead_code` warnings from `const hasUserInteracted = false; if (!hasUserInteracted) return; writeBackFired = true;`. Confirmed present at base ref `be42b9e6e` (analyzed the base copy — same two warnings). This commit neither introduces nor fixes them. Optional cleanup: use a runtime `bool` instead of `const` so the guard branch is live.

### Verdict

**PASS**

Test-only cleanup with no production impact. No correctness, privacy, compliance, routing, or facade-without-wiring risk. All removed imports verified unused, all conversions verified valid, and the highest-risk change (`dart:ui` removal) confirmed to still compile and the affected test to pass. The only analyzer noise is a pair of pre-existing dead-code warnings unrelated to this diff.
