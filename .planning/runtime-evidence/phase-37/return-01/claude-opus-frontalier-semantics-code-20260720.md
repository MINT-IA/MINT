## MINT Audit — `codex/g1-capital-native-proof-20260718`

**Scope:** Unstaged worktree changes to `frontalier_screen.dart` (+3/−4 effective) and `frontalier_ledger_quarantine_test.dart` (+20). Well within the 500-line budget.

### What the change does
- `frontalier_screen.dart:325-334` — wraps the known-state card in `Semantics(identifier: 'frontier_jurisdiction_known_state')`, exposing a native/accessibility runtime id while preserving the existing `Key('frontier_jurisdiction_known_state')`.
- Test adds `FR CH GE known state exposes its native runtime id`, asserting both `find.bySemanticsIdentifier(...)` and `find.byKey(...)` resolve.

### Verification (not trusting the diff alone)
- `flutter test test/screens/frontalier_ledger_quarantine_test.dart` → **15/15 pass**, including the new native-runtime-id test.
- `flutter analyze` on both touched files → **No issues found**.
- The identifier `frontier_jurisdiction_known_state` is unique; no collision with the three dropdown field identifiers or other state cards.

### Findings

**P0 — none.**

**P1 — none.**

**P2 (non-blocking):**
- Inconsistent native-id coverage. Only `_knownState` gets a `Semantics(identifier:)` wrapper. The sibling state cards — `frontier_jurisdiction_stale_state`, `frontier_jurisdiction_domestic_state`, `frontier_jurisdiction_specialist_only_state` (`frontalier_screen.dart` `_staleState`/`_domesticState`/`_specialistOnlyState`) — still expose only a Flutter `Key`, which is not queryable from the native runtime. If the "native proof" goal is uniform accessibility exposure across jurisdiction states, these remain gaps. Not a correctness/privacy/routing risk; consistent with the branch's incremental scope.

### Assessment
- **Routing:** unchanged; the existing "no route drift" assertions still hold and pass.
- **Privacy/compliance:** no data, persistence, or PII paths touched.
- **Facade-without-wiring:** not a facade — the identifier is genuinely present in the semantics tree and covered by a passing test asserting the real node.
- **Tests:** real and green.

### Verdict
**PASS**
