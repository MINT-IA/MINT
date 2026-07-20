Both orchestrator tests pass and no stale `.*` patterns remain anywhere in the tree. My analysis is complete.

## Audit: `codex/g1-capital-native-proof-20260718`

### Scope
Three-file worktree change tightening the Frontalier Maestro black-box proof: replacing loose regex matchers `France.*FR` / `Suisse.*CH` with exact literals `France \(FR\)` / `Suisse \(CH\)`, plus the two harness tests that assert the flow's shape.

### Verification performed
1. **UI text ground-truth** — The production screen renders country labels via `_countryLabel` → l10n (`apps/mobile/lib/screens/frontalier_screen.dart:213,218-226`). FR locale resolves to exactly `France (FR)` and `Suisse (CH)` (`app_localizations_fr.dart:6383,6386`). The new literal matchers match the real rendered strings; the change is a correctness improvement (the old `France.*FR` would not fully-match `France (FR)` under Maestro's anchored regex due to the trailing `)`).
2. **Escaping consistency across the three files** — YAML bytes are `text: "France \\(FR\\)"` (`g1_return01_frontalier_inline.yaml:31`), YAML-parsed to regex `France \(FR\)`. The Dart (`\\\\(FR\\\\)`) and Python (`\\\\(FR\\\\)`) search literals both resolve to `\\(FR\\)`, exactly matching the YAML bytes. Confirmed by reading the file directly.
3. **No stale references** — `Grep` for `France\.\*FR|Suisse\.\*CH` across the repo: zero matches. No other flow or test still asserts the old pattern.
4. **Tests executed** — `pytest ...test_g1_return01_six_origin_orchestrator.py -k "frontalier or only_housing"` → **2 passed**, confirming the Python guard matches the current YAML bytes.
5. **No facade / integrity** — The flow drives real production widgets (`frontier_residence_country_field`), does a genuine `stopApp` + `clearState: false` cold relaunch + readback, and the forbidden-token guards (`SharedPreferences`, `inputText:`, `runScript:`, `wizard_answers_v2`, …) are preserved, preventing the proof from being faked via direct storage writes. The orchestrator uninstalls for `frontalier_inline` (reset case), consistent with the flow's own `clearState: true` seed step. No regression in locale-locking (the FR-only match pre-existed).

### Findings
- **P0:** none
- **P1:** none
- **P2:** none. Note (non-blocking): the flow remains implicitly locale-locked to French (`Suisse (CH)` will not match EN `Switzerland (CH)`). This is pre-existing behavior, not introduced or worsened by this diff; flag only if the simulator locale is ever changed to non-FR.

### Verdict
**PASS**
