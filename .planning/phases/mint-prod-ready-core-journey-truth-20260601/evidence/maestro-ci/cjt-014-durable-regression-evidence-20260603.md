---
description: Durable evidence note for CJT-014, replacing current regression flow /tmp screenshots with flow-local captures and proving the regression tier still passes.
date: 2026-06-03
status: verified
---

# CJT-014 — Durable Regression Evidence

## Scope

CJT-014 is closed for the current Maestro regression-gate evidence path.
This note does not rewrite historical `/tmp` citations in old index rows;
those remain provenance for older red/green runs. Current release-facing
regression flows now avoid `takeScreenshot: /tmp/...`.

## Change

Four active regression flow screenshots were changed from absolute `/tmp`
paths to Maestro-relative names. Maestro writes those relative captures
from the command working directory, so the generated screenshots from the
runtime proof were copied into a versioned evidence folder alongside the
compact sweep logs.

Changed files:

- `tools/simulator/flows/regression/bug__S002__maestro_cold_launch_fragment.yaml`
- `tools/simulator/flows/regression/bug__S003__mintapp_scheme_opens_app.yaml`
- `tools/simulator/flows/regression/bug__S004_F006_F007__universal_link_opens_app.yaml`
- `tools/simulator/flows/regression/bug__S005__landing_anonymous_cta_to_home.yaml`

## Mechanical Proof

Commands:

```bash
rg -n "^\s*-\s*takeScreenshot:\s*/tmp" tools/simulator/flows -g '*.yaml' || true
bash -n tools/simulator/maestro_sweep.sh tools/simulator/maestro_with_watchdog.sh tools/simulator/maestro_env.sh
python3 tools/checks/maestro_locator_audit.py
git diff --check
```

Results:

- No active `takeScreenshot: /tmp` entries remain in `tools/simulator/flows/**/*.yaml`.
- `maestro_locator_audit` scanned 35 flows / 345 locators and passed.
- Shell syntax and `git diff --check` passed.

Remaining `/tmp` mentions are comments, older historical proof rows, or
temporary build-workaround paths in evidence notes. They are not current
Maestro screenshot destinations.

## Runtime Proof

Command:

```bash
MAESTRO_HARD_LIMIT=600 MAESTRO_STALL_THRESHOLD=90 tools/simulator/maestro_sweep.sh --tier regression
```

Result:

- Runtime sweep dir: `.planning/_walker/sweep-20260603T074935`
- Durable copied evidence: `evidence/maestro-ci/cjt-014-regression-sweep-20260603T074935/`
- Flow count: 6
- Green: 6 / 6
- Red: 0 / 6
- Stalled: 0 / 6
- Hard-limit: 0 / 6

Per-flow results:

| Flow | Result |
|---|---|
| `bug__S005__landing_anonymous_cta_to_home` | pass |
| `bug__F001__chat_input_bar_exists` | pass |
| `bug__S001__cap_du_jour_action_bar_reachable` | pass |
| `bug__S002__maestro_cold_launch_fragment` | pass |
| `bug__P004__overlay_populated_on_open` | pass |
| `bug__F001_S001_combined__chat_via_cap_du_jour` | pass |

The S002 and S005 modified screenshot commands were executed during this
runtime sweep, completed with the new relative names, and were copied into
the durable evidence folder:

- `97-s002-aujourdhui-after-fragment`
- `96-s005-aujourdhui-landed`

Durable files copied from the runtime proof:

- `cjt-014-regression-sweep-20260603T074935/sweep-summary.md`
- `cjt-014-regression-sweep-20260603T074935/*/EXIT_CODE`
- `cjt-014-regression-sweep-20260603T074935/*/maestro.log`
- `cjt-014-regression-sweep-20260603T074935/97-s002-aujourdhui-after-fragment.png`
- `cjt-014-regression-sweep-20260603T074935/96-s005-aujourdhui-landed.png`

S003/S004 are part of the opt-in deeplink tier and remain governed by
CJT-015. They were changed mechanically to the same relative screenshot
style, but not used as release closure proof here.

## Closure Decision

CJT-014 is verified for the current local regression gate and durable
evidence convention. Future release claims should cite compact evidence
notes under `.planning/phases/.../evidence/` and avoid depending on
untracked `/tmp` artifacts.
