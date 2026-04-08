---
phase: 01-p0a-code-unblockers
plan: 02
type: execute
wave: 2
depends_on: ["01-01"]
files_modified:
  - services/backend/app/services/onboarding/chiffre_choc_selector.py
  - services/backend/app/services/onboarding/premier_eclairage_selector.py
  - services/backend/tests/test_chiffre_choc.py
  - services/backend/tests/test_premier_eclairage.py
  - services/backend/app/schemas/
  - tools/openapi/openapi.json
  - apps/mobile/lib/screens/onboarding/chiffre_choc_screen.dart
  - apps/mobile/lib/screens/onboarding/instant_chiffre_choc_screen.dart
  - apps/mobile/lib/screens/onboarding/premier_eclairage_screen.dart
  - apps/mobile/lib/screens/onboarding/instant_premier_eclairage_screen.dart
  - apps/mobile/lib/services/chiffre_choc_selector.dart
  - apps/mobile/lib/services/premier_eclairage_selector.dart
  - apps/mobile/test/services/chiffre_choc_selector_test.dart
  - apps/mobile/test/services/premier_eclairage_selector_test.dart
  - apps/mobile/lib/l10n/app_fr.arb
  - apps/mobile/lib/l10n/app_en.arb
  - apps/mobile/lib/l10n/app_de.arb
  - apps/mobile/lib/l10n/app_es.arb
  - apps/mobile/lib/l10n/app_it.arb
  - apps/mobile/lib/l10n/app_pt.arb
  - apps/mobile/lib/services/analytics_events.dart
  - tools/checks/no_chiffre_choc.py
  - CLAUDE.md
autonomous: true
requirements: [STAB-20]
must_haves:
  truths:
    - "Backend has no live chiffre_choc symbol; pytest green"
    - "OpenAPI schema regenerated, contains no chiffre_choc field"
    - "Flutter sources renamed; flutter analyze + test green"
    - "6 ARB files renamed + gen-l10n regenerated"
    - "Analytics events renamed"
    - "CI grep gate script exists and passes on current tree"
    - "CLAUDE.md legacy note flipped to 'rename completed'"
  artifacts:
    - path: tools/checks/no_chiffre_choc.py
      provides: "CI grep gate blocking chiffre_choc regressions in live surfaces"
    - path: services/backend/app/services/onboarding/premier_eclairage_selector.py
      provides: "Renamed backend selector"
    - path: apps/mobile/lib/services/premier_eclairage_selector.dart
      provides: "Renamed Flutter selector"
  key_links:
    - from: tools/checks/no_chiffre_choc.py
      to: apps/mobile/lib/ services/backend/app/ apps/mobile/lib/l10n/ tools/openapi/
      via: "grep gate excluding .planning/ docs/archive/ apps/mobile/archive/ CLAUDE.md"
      pattern: "chiffre_?choc|chiffreChoc"
---

<objective>
Execute STAB-20 per D-02 (CONTEXT.md): rename `chiffre_choc` → `premier_eclairage` across 719 live-surface occurrences as an atomic layered sequence of 7 commits (L1-L7), each independently revertable, each landing `flutter analyze 0 + flutter test green + pytest green` (where applicable) before the next.

Purpose: Unblock Phase 2+ and enforce new MINT identity doctrine (CLAUDE.md legacy note).
Output: 7 commits, green CI grep gate, flipped legacy note, regenerated OpenAPI.
</objective>

<context>
@.planning/phases/01-p0a-code-unblockers/01-CONTEXT.md
@.planning/REQUIREMENTS.md
@CLAUDE.md
</context>

<git_discipline>
Per CLAUDE.md §4:
- Work on a feature branch (e.g., `feature/01-stab20-rename-premier-eclairage`) off `dev`.
- Each task below = one atomic commit. Do NOT squash locally.
- Never force-push. `git pull --rebase` only.
- Between each commit, run the task's acceptance commands. If red, fix inside the same task (do not roll into next commit).
- If a commit lands red and can't be fixed quickly → `git reset --hard HEAD~1` and restart the task.
</git_discipline>

<tasks>

<task type="auto">
  <name>Task 1 (Commit L1): Backend source + tests rename</name>
  <files>services/backend/app/services/onboarding/chiffre_choc_selector.py, services/backend/app/services/onboarding/premier_eclairage_selector.py, services/backend/tests/test_chiffre_choc.py, services/backend/tests/test_premier_eclairage.py</files>
  <action>
1. `git mv services/backend/app/services/onboarding/chiffre_choc_selector.py services/backend/app/services/onboarding/premier_eclairage_selector.py`
2. `git mv services/backend/tests/test_chiffre_choc.py services/backend/tests/test_premier_eclairage.py`
3. Inside both files: rename classes, functions, and symbol names (`ChiffreChocSelector` → `PremierEclairageSelector`, `select_chiffre_choc` → `select_premier_eclairage`, etc.). Rename all internal variables `chiffre_choc` → `premier_eclairage`.
4. Update any backend imports referencing the old module path. Grep: `git grep -l 'chiffre_choc_selector\|ChiffreChocSelector\|select_chiffre_choc' services/backend/` and fix each hit.
5. Do NOT touch Pydantic schemas or OpenAPI yet — that is L2.
6. Commit: `refactor(stab-20): L1 backend selector + tests rename chiffre_choc → premier_eclairage`
  </action>
  <verify>
    <automated>cd services/backend &amp;&amp; ruff check app/ tests/ &amp;&amp; python3 -m pytest tests/ -q</automated>
  </verify>
  <done>
- Both files renamed via `git mv` (git history preserved)
- `ruff check` = 0
- `pytest -q` = green
- No `ChiffreChocSelector` or `chiffre_choc_selector` symbol left in `services/backend/app/services/`
- Commit landed
  </done>
  <rollback>`git reset --hard HEAD~1`</rollback>
</task>

<task type="auto">
  <name>Task 2 (Commit L2): Backend API schemas + OpenAPI regen</name>
  <files>services/backend/app/schemas/, tools/openapi/openapi.json</files>
  <action>
1. Grep all Pydantic schemas: `git grep -n 'chiffre_choc\|chiffreChoc\|ChiffreChoc' services/backend/app/schemas/ services/backend/app/api/`
2. Rename every field, alias, class, and docstring. Respect Pydantic v2 camelCase alias convention (`premier_eclairage` Python, `premierEclairage` alias).
3. Rename any endpoint paths containing `chiffre-choc` → `premier-eclairage` in `services/backend/app/api/v1/endpoints/`.
4. Regenerate OpenAPI: follow the existing `tools/openapi/` regen pipeline (typically `python -m app.main` export or a `make openapi` / `scripts/` command — inspect `tools/openapi/` README first).
5. Commit the regenerated `tools/openapi/openapi.json` in the same commit (CI drift guard requirement).
6. Commit: `refactor(stab-20): L2 backend schemas + OpenAPI regen`
  </action>
  <verify>
    <automated>cd services/backend &amp;&amp; ruff check app/ &amp;&amp; python3 -m pytest tests/ -q &amp;&amp; cd ../.. &amp;&amp; git grep -n 'chiffre_choc\|chiffreChoc\|ChiffreChoc' services/backend/app/ tools/openapi/openapi.json; test $? -eq 1</automated>
  </verify>
  <done>
- 0 hits of `chiffre_choc|chiffreChoc|ChiffreChoc` in `services/backend/app/` and `tools/openapi/openapi.json`
- pytest green, ruff 0
- OpenAPI diff committed
- Commit landed
  </done>
  <rollback>`git reset --hard HEAD~1` — L1 still stands.</rollback>
</task>

<task type="auto">
  <name>Task 3 (Commit L3): Flutter sources rename (filenames + classes + imports + routes)</name>
  <files>apps/mobile/lib/screens/onboarding/chiffre_choc_screen.dart, apps/mobile/lib/screens/onboarding/instant_chiffre_choc_screen.dart, apps/mobile/lib/services/chiffre_choc_selector.dart, apps/mobile/test/services/chiffre_choc_selector_test.dart (and their new names)</files>
  <action>
1. `git mv` each of the 4 files to their `premier_eclairage` equivalents:
   - `apps/mobile/lib/screens/onboarding/chiffre_choc_screen.dart` → `premier_eclairage_screen.dart`
   - `apps/mobile/lib/screens/onboarding/instant_chiffre_choc_screen.dart` → `instant_premier_eclairage_screen.dart`
   - `apps/mobile/lib/services/chiffre_choc_selector.dart` → `premier_eclairage_selector.dart`
   - `apps/mobile/test/services/chiffre_choc_selector_test.dart` → `premier_eclairage_selector_test.dart`
2. Inside each file: rename Dart classes (`ChiffreChocScreen` → `PremierEclairageScreen`, `InstantChiffreChocScreen` → `InstantPremierEclairageScreen`, `ChiffreChocSelector` → `PremierEclairageSelector`), all internal identifiers, all comments.
3. Update GoRouter routes: grep `git grep -n "chiffre[_-]choc" apps/mobile/lib/router/ apps/mobile/lib/app.dart` — rename route paths and `name:` fields (e.g., `/onboarding/chiffre-choc` → `/onboarding/premier-eclairage`). Note: these routes are scheduled for deletion in Phase 10 (ONB-02, ONB-03) but MUST be renamed here to keep the grep gate green.
4. Update all Dart imports referencing the old filenames: `git grep -l "chiffre_choc_screen\|instant_chiffre_choc\|chiffre_choc_selector" apps/mobile/lib/ apps/mobile/test/` → fix each.
5. Do NOT touch ARB files yet (L4) and do NOT touch analytics (L5).
6. **Claude's discretion per D-02:** if the combined `git mv` + import rewrite exceeds ~40 file touch, split into sub-commits L3a (filenames + git mv only) and L3b (import + class rename). Otherwise keep as one L3 commit.
7. Commit: `refactor(stab-20): L3 Flutter sources rename chiffre_choc → premier_eclairage`
  </action>
  <verify>
    <automated>cd apps/mobile &amp;&amp; flutter analyze lib/ &amp;&amp; flutter test &amp;&amp; cd ../.. &amp;&amp; git grep -n 'chiffre_choc\|chiffreChoc\|ChiffreChoc' apps/mobile/lib/ apps/mobile/test/ --glob='!apps/mobile/lib/l10n/*' --glob='!apps/mobile/lib/services/analytics_events.dart'; test $? -eq 1</automated>
  </verify>
  <done>
- `flutter analyze lib/` = 0 errors
- `flutter test` = green
- 0 hits of `chiffre_choc|chiffreChoc|ChiffreChoc` in `apps/mobile/lib/` and `apps/mobile/test/`, EXCLUDING `lib/l10n/` (L4) and `lib/services/analytics_events.dart` (L5)
- Commit(s) landed
  </done>
  <rollback>`git reset --hard HEAD~1` (or ~2 if split L3a/L3b).</rollback>
</task>

<task type="auto">
  <name>Task 4 (Commit L4): ARB keys rename + gen-l10n</name>
  <files>apps/mobile/lib/l10n/app_fr.arb, app_en.arb, app_de.arb, app_es.arb, app_it.arb, app_pt.arb</files>
  <action>
1. In each of the 6 ARB files, rename every key matching `chiffreChoc*` → `premierEclairage*` (preserve camelCase suffix). Update each corresponding `@chiffreChoc*` metadata block.
2. CRITICAL: Do NOT alter French diacritics (é, è, ê, etc.) — CLAUDE.md §7 rule.
3. Run `cd apps/mobile && flutter gen-l10n` to regenerate `app_localizations*.dart`.
4. Commit the regenerated Dart files in the same commit.
5. Commit: `refactor(stab-20): L4 ARB keys rename + gen-l10n`
  </action>
  <verify>
    <automated>cd apps/mobile &amp;&amp; flutter gen-l10n &amp;&amp; flutter analyze lib/ &amp;&amp; flutter test &amp;&amp; cd ../.. &amp;&amp; git grep -n 'chiffreChoc\|chiffre_choc\|chiffre-choc' apps/mobile/lib/l10n/; test $? -eq 1</automated>
  </verify>
  <done>
- `flutter gen-l10n` succeeds (no missing-key errors across 6 languages)
- `flutter analyze lib/` = 0 errors
- `flutter test` = green
- 0 hits in `apps/mobile/lib/l10n/`
- Generated `app_localizations*.dart` committed
  </done>
  <rollback>`git reset --hard HEAD~1`</rollback>
</task>

<task type="auto">
  <name>Task 5 (Commit L5): Analytics events rename</name>
  <files>apps/mobile/lib/services/analytics_events.dart</files>
  <action>
1. Per D-02: hard rename (no dual-emit) — no production warehouse contract, pre-launch telemetry only.
2. In `apps/mobile/lib/services/analytics_events.dart`: rename the 2 hits (event name constants + any helper method). Example: `chiffreChocShown` → `premierEclairageShown`.
3. Grep for any consumers of the renamed constants and update them (expected: 0 after L3/L4, but verify).
4. Commit: `refactor(stab-20): L5 analytics events rename (pre-launch hard rename, no dual-emit)`
  </action>
  <verify>
    <automated>cd apps/mobile &amp;&amp; flutter analyze lib/ &amp;&amp; flutter test &amp;&amp; cd ../.. &amp;&amp; git grep -n 'chiffre_choc\|chiffreChoc\|ChiffreChoc' apps/mobile/lib/services/analytics_events.dart; test $? -eq 1</automated>
  </verify>
  <done>
- 0 hits in `analytics_events.dart`
- flutter analyze + test green
- Commit landed
  </done>
  <rollback>`git reset --hard HEAD~1`</rollback>
</task>

<task type="auto">
  <name>Task 6 (Commit L6): Residue sweep + CI grep gate</name>
  <files>tools/checks/no_chiffre_choc.py</files>
  <action>
1. Create `tools/checks/no_chiffre_choc.py`. It MUST:
   - Use only Python stdlib (subprocess + git grep, or os.walk + re). Pattern: `r'chiffre_?choc|chiffreChoc|ChiffreChoc'` (case-insensitive where appropriate, but keep the regex explicit).
   - Scan these directories:
     - `apps/mobile/lib/`
     - `services/backend/app/`
     - `apps/mobile/lib/l10n/`
     - `tools/openapi/`
   - Exclude these paths (baked in):
     - `.planning/**`
     - `docs/archive/**`
     - `apps/mobile/archive/**`
     - `CLAUDE.md` (legacy note line is allowed until L7 flips it; script stays permissive on this file forever so it survives historical audits)
   - Exit 0 if 0 hits; exit 1 with a human-readable list of file:line:match otherwise.
   - Include a top-level docstring referencing STAB-20, D-02, Phase 1.
2. Run the script locally against the current tree — it MUST exit 0. If it reports residue, fix each hit in the same commit (do NOT defer).
3. Wire the script into the CI pipeline: search `.github/workflows/` for an existing lint/check job (e.g., `ci.yml`, `flutter.yml`) and add a step:
   ```yaml
   - name: chiffre_choc grep gate (STAB-20)
     run: python3 tools/checks/no_chiffre_choc.py
   ```
   Claude's discretion per D-02: choose the job best aligned with other `tools/checks/` invocations (look for `no_llm_alert` precedent if it exists).
4. Commit: `refactor(stab-20): L6 residue sweep + CI grep gate (no_chiffre_choc.py)`
  </action>
  <verify>
    <automated>python3 tools/checks/no_chiffre_choc.py &amp;&amp; cd apps/mobile &amp;&amp; flutter analyze lib/ &amp;&amp; flutter test &amp;&amp; cd ../../services/backend &amp;&amp; python3 -m pytest tests/ -q</automated>
  </verify>
  <done>
- Script exists, is executable, exits 0
- Script wired into a CI workflow
- flutter analyze + test + pytest all green
- Commit landed
  </done>
  <rollback>`git reset --hard HEAD~1`</rollback>
</task>

<task type="auto">
  <name>Task 7 (Commit L7): CLAUDE.md legacy note flip + docs sweep</name>
  <files>CLAUDE.md</files>
  <action>
1. In `CLAUDE.md` line 3, replace the current legacy note:
   ```
   > **⚠️ LEGACY NOTE (2026-04-05):** Uses "chiffre choc" (legacy term → "premier éclairage", see `docs/MINT_IDENTITY.md`).
   ```
   with:
   ```
   > **LEGACY NOTE (2026-04-07):** `chiffre_choc` → `premier_eclairage` rename completed (STAB-20, Phase 1). Legacy term retained in archives only (`.planning/`, `docs/archive/`, `apps/mobile/archive/`). See `docs/MINT_IDENTITY.md`.
   ```
2. Grep `docs/` (excluding `docs/archive/`) for any remaining `chiffre_choc` references in live docs — fix each in this commit.
3. Do NOT touch `.planning/`, `docs/archive/`, `apps/mobile/archive/` — those are historical records per D-02 specifics.
4. Commit: `docs(stab-20): L7 flip CLAUDE.md legacy note — rename completed`
  </action>
  <verify>
    <automated>python3 tools/checks/no_chiffre_choc.py &amp;&amp; git grep -n 'chiffre_choc\|chiffreChoc\|ChiffreChoc' docs/ --glob='!docs/archive/**'; test $? -eq 1</automated>
  </verify>
  <done>
- CLAUDE.md legacy note flipped
- 0 hits in live `docs/` (excluding archive)
- `no_chiffre_choc.py` still exits 0
- Commit landed
  </done>
  <rollback>`git reset --hard HEAD~1`</rollback>
</task>

</tasks>

<verification>
Full Phase 1 STAB-20 acceptance gate (per ROADMAP success criterion #3):

```bash
git grep -E 'chiffre_?choc|chiffreChoc' apps/mobile/lib/ services/backend/app/ apps/mobile/lib/l10n/ tools/openapi/
# MUST return 0 hits

python3 tools/checks/no_chiffre_choc.py
# MUST exit 0

cd apps/mobile && flutter analyze lib/ && flutter test
cd services/backend && python3 -m pytest tests/ -q
# ALL green
```

Rollback chain: each L-commit is independently revertable. If L7 fails, revert L7; L6 still stands as the gate. If L4 fails, revert L4+L5+L6+L7 in reverse order (L3 backend/Flutter sources still valid).
</verification>

<success_criteria>
STAB-20 closed per ROADMAP Phase 1 success criterion #3:
- CI grep gate `git grep -E 'chiffre_?choc|chiffreChoc' apps/mobile/lib/ services/backend/app/ apps/mobile/lib/l10n/` returns 0
- `tools/checks/no_chiffre_choc.py` wired into CI
- 7 atomic commits in git log, each independently revertable
- CLAUDE.md legacy note flipped
</success_criteria>

<output>
After completion, create `.planning/phases/01-p0a-code-unblockers/01-02-SUMMARY.md` listing:
- The 7 commit SHAs + messages
- Final grep gate output (0 hits)
- OpenAPI diff stats
- Any Claude's-discretion decisions taken (L3 split, CI job choice)
</output>
