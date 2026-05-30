# Phase 09 Verification — Claude Review Harness

## Commands

```bash
bash -n tools/claude_review.sh
python3 -m py_compile tools/agent-drift/golden/run.py
```

Result: pass.

```bash
printf 'Réponds uniquement: ok\n' \
  | claude -p --model sonnet --tools '' --no-session-persistence
```

Result: `ok`.

```bash
python3 - <<'PY'
import json, importlib.util
spec = importlib.util.spec_from_file_location(
    'golden_run', 'tools/agent-drift/golden/run.py'
)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
res = mod.run_one(
    {'prompt': 'Réponds uniquement: ok', 'id': 'smoke', 'domain': 'unknown'},
    timeout_sec=30,
)
print(json.dumps({k: res[k] for k in ['prompt_id', 'failed_lints', 'output_excerpt']}, ensure_ascii=False))
PY
```

Result: Claude returned `ok`.

```bash
MINT_CLAUDE_TIMEOUT=60 MINT_CLAUDE_MAX_BYTES=500 \
  tools/claude_review.sh apps/mobile/lib/domain/budget/budget_inputs.dart
```

Result: Claude review completed and produced actionable findings.

```bash
bash -n tools/claude_review.sh
MINT_CLAUDE_TIMEOUT=120 MINT_CLAUDE_MAX_BYTES=6000 MINT_CLAUDE_MODEL=opus \
  tools/claude_review.sh -- services/backend/tests/test_narrator_refuses_uncited_numbers.py
```

Result: wrapper completed with non-empty JSON `.result` parsed as:
`No blocking findings.`

```bash
cd apps/mobile
flutter test test/domain/budget/budget_service_test.dart \
  --plain-name 'fromMap accepts persisted numeric strings'
flutter test test/domain/budget/budget_service_test.dart \
  --plain-name 'fromMap ignores zero legacy income when periodic income exists'
flutter test test/domain/budget/budget_service_test.dart \
  --plain-name 'fromMap prefers canonical income when both income keys exist'
flutter test test/services/wizard_service_test.dart \
  --plain-name 'prefers canonical period income when both income keys exist'
flutter test test/domain/budget/budget_service_test.dart \
  --plain-name 'fromMap accepts Swiss apostrophe numeric strings'
flutter test test/domain/budget/budget_service_test.dart \
  --plain-name 'fromMap treats housing and debt amounts as monthly'
flutter test test/services/wizard_service_test.dart \
  --plain-name 'explicit zero canonical income overrides stale legacy income'
```

Result: regression tests pass after fixes.

```bash
cd apps/mobile
flutter test \
  test/providers/budget/budget_provider_test.dart \
  test/screens/budget_setup_screen_test.dart \
  test/screens/budget_screen_smoke_test.dart \
  test/screens/mon_argent_screen_test.dart \
  test/screens/advisor_banking_smoke_test.dart \
  test/domain/budget/budget_service_test.dart \
  test/services/wizard_service_test.dart
```

Result: 169 tests pass.
