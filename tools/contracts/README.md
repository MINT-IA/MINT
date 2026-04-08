# tools/contracts/

Single source of truth for cross-stack contracts. Edit the JSON, regenerate, commit
both generated files. CI fails the build on drift.

## VoiceCursorContract (v0.5.0)

Drives MINT's voice intensity cursor (N1..N5) across Dart (mobile) and Python (backend).

### Files

| File | Role |
|---|---|
| `voice_cursor.json` | **Source of truth.** 5 levels × 3 gravities × 3 relations × 3 preferences + caps + sensitive topics + narrator wall exemptions + precedence cascade. Schema frozen at v0.5.0. |
| `generate_dart.py` | Hand-rolled emitter → `apps/mobile/lib/services/voice/voice_cursor_contract.g.dart` |
| `generate_python.py` | Hand-rolled emitter → `services/backend/app/schemas/voice_cursor.py` |
| `regenerate.sh` | Runs both generators. Prints `OK` on success. |

### Workflow

```bash
# 1. Edit the JSON
$EDITOR tools/contracts/voice_cursor.json

# 2. Regenerate consumers
bash tools/contracts/regenerate.sh

# 3. Verify nothing else broke
cd apps/mobile && flutter test test/services/voice/voice_cursor_contract_test.dart
cd services/backend && python3 -m pytest tests/test_voice_cursor_schema.py -q

# 4. Commit ALL three files together
git add tools/contracts/voice_cursor.json \
        apps/mobile/lib/services/voice/voice_cursor_contract.g.dart \
        services/backend/app/schemas/voice_cursor.py
git commit -m "feat(voice): bump VoiceCursorContract to vX.Y.Z"
```

### Why hand-rolled emitters (not `datamodel-code-generator`)

The contract is a frozen enum + matrix, not an evolving schema. Hand-rolled emitters
give:
- Deterministic output (no upstream formatting churn that constantly reds the drift gate).
- Hermetic toolchain (zero runtime deps beyond stdlib `json`).
- Full control over the public API surface (Dart `enum` names, Python `Enum` names,
  `Final[...]` annotations, banner format).

`datamodel-code-generator==0.25.*` is still pinned in `services/backend/requirements-dev.txt`
for ad-hoc schema exploration but is NOT invoked by `regenerate.sh`.

### Drift guard

`.github/workflows/ci.yml` runs `bash tools/contracts/regenerate.sh` then
`git diff --exit-code` against the three tracked files. Any diff fails the build with:

> Contracts drift detected — run `bash tools/contracts/regenerate.sh` and commit.

### Editing rules

- **Never** edit the `.g.dart` or `voice_cursor.py` files directly. They carry a
  `GENERATED — DO NOT EDIT` banner. The drift gate will revert your edits.
- **Never** add a new level (N6, N0). The 5-level scale is doctrinal (see
  `visions/MINT_DESIGN_BRIEF_v0.2.3.md` §L1.6).
- **Never** weaken the precedence cascade. Order is locked:
  1. `sensitivityGuard` — sensitive topics cap at N3.
  2. `fragilityCap` — fragile mode caps at N3.
  3. `n5WeeklyBudget` — downgrade N5 to N4 when budget exhausted.
  4. `gravityFloor` — G3 never below N2.
  5. `preferenceCap` — soft → N3, direct → N4 implicit, unfiltered → N5 allowed.
  6. `matrixDefault` — fall back to the matrix lookup.
- The Dart wrapper (`voice_cursor_contract.dart`, hand-written, imports `.g.dart`) is
  where `resolveLevel(...)` lives. Tests live in
  `apps/mobile/test/services/voice/voice_cursor_contract_test.dart`.
