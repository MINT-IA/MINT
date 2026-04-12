# tools/regional — Regional Voice Codegen

Phase 6 / REGIONAL-04 + REGIONAL-05.

## What this is

Single source of truth for the **backend regional voice layer**. The
script `regional_microcopy_codegen.py` reads the 3 canton ARB carve-outs
shipped by Plan 06-03:

- `apps/mobile/lib/l10n_regional/app_regional_vs.arb` (fr-CH, anchor for **Romande**)
- `apps/mobile/lib/l10n_regional/app_regional_zh.arb` (de-CH, anchor for **Deutschschweiz**)
- `apps/mobile/lib/l10n_regional/app_regional_ti.arb` (it-CH, anchor for **Italiana**)

…and emits a deterministic Python module at:

- `services/backend/app/services/coach/regional_microcopy.py`

This module exposes a single class `RegionalMicrocopy` that replaces the
legacy hand-coded dual-system (`REGIONAL_MAP` + `_REGIONAL_IDENTITY`)
previously living inside `claude_coach_service.py`. The coach service
now imports the class and calls `RegionalMicrocopy.identity_block(canton)`
at a single injection point.

## D-05 routing flip

Per Phase 6 CONTEXT.md decision **D-05**, **VS is the Romande anchor**,
not VD. This means:

| Canton group | Cantons | Anchor |
|--------------|---------|--------|
| Romande      | VS, VD, GE, NE, JU, FR | **VS** |
| Deutschschweiz | ZH, BE, LU, AG, SG, TG, SO, SH, AR, AI, OW, NW, GL, SZ, UR, ZG, BL, BS | **ZH** |
| Italiana     | TI, GR | **TI** |

`CANTON_TO_PRIMARY` (inside the generated module) encodes the secondary
mappings. `RegionalMicrocopy.resolve()` returns the anchor canton.
Unknown / `None` → `None` → neutral fallback identity block.

## Run the codegen

```bash
python3 tools/regional/regional_microcopy_codegen.py
```

Determinism is a hard requirement: running the script twice MUST produce
byte-identical output. The CI drift guard relies on this.

## Drift guard

`tools/checks/regional_microcopy_drift.py` re-runs the codegen and
diffs the generated file against the committed copy. CI invokes it on
every PR touching `services/backend/**` or `apps/mobile/lib/l10n_regional/**`
(see `.github/workflows/ci.yml`).

If you ever need to change the regional identity blocks:

1. Edit the **ARB carve-outs** (`apps/mobile/lib/l10n_regional/app_regional_*.arb`),
   not the generated Python file.
2. If the change requires a new template (different keys, different
   format), edit `regional_microcopy_codegen.py` itself.
3. Run the codegen.
4. Commit the regenerated `regional_microcopy.py` along with the ARB
   change in the same PR.

Never hand-edit `services/backend/app/services/coach/regional_microcopy.py` —
the file header explicitly forbids it and the drift guard will fail the
build.

## Why codegen and not a runtime read?

- **Determinism in tests** — backend unit tests don't need to load Flutter
  ARB files at runtime.
- **No coupling** — backend builds work even if the mobile workspace is
  not checked out.
- **CI grep guard** — `git grep 'REGIONAL_MAP\s*=' services/backend/`
  can be enforced to return zero (REGIONAL-05).
- **Single source of truth** — one ARB edit, one regenerated file,
  one PR, one approval.
