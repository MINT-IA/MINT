# Row 26 iPhone 16e Regression Sweep

Date: 2026-06-06
Rows: 26 primary, 6/20/21 support signals
Bug: CJT-060
Status: local simulator regression gate evidence, not release closure

## Purpose

After CJT-059 made normal simulator builds and the iPhone 16e runtime target
reliable, this sweep checks whether the curated non-deeplink regression tier
still passes on the less premium iPhone 16e simulator.

## Command

```bash
MAESTRO_HARD_LIMIT=420 MAESTRO_STALL_THRESHOLD=90 \
tools/simulator/maestro_sweep.sh --tier regression
```

The sweep script rebooted the only booted simulator before running:

```text
iPhone 16e - iOS 26.2 - 9C9E9AAE-C3CF-49B8-B06D-625004880A9B
```

## Result

```text
Green:   6 / 6
Red:     0 / 6
Stalled: 0 / 6
Hard:    0 / 6
```

Per-flow results:

| Flow | Exit | Scope |
|---|---:|---|
| `bug__S005__landing_anonymous_cta_to_home` | 0 | Anonymous landing CTA reaches Home/Aujourd'hui with `card_cap_du_jour` and action bar. |
| `bug__F001__chat_input_bar_exists` | 0 | Cap-du-jour chat overlay exposes input/send/counter anchors and one sent turn. |
| `bug__S001__cap_du_jour_action_bar_reachable` | 0 | Cap-du-jour action bar exposes the three verbs and opens the chat overlay. |
| `bug__S002__maestro_cold_launch_fragment` | 0 | Shared cold-launch fragment reaches Aujourd'hui. |
| `bug__P004__overlay_populated_on_open` | 0 | Explain overlay opens with populated narrative/input copy, not raw command leakage. |
| `bug__F001_S001_combined__chat_via_cap_du_jour` | 0 | Combined cold-launch/Home/action-bar/chat reachability remains structurally green. |

Artifacts:

- `sweep-summary.md`
- per-flow `EXIT_CODE`
- per-flow `maestro.log`

## Scope Limit

This proof supports Row 26 as `PARTIAL`: local iOS simulator automation can
catch the named non-deeplink regression flows on iPhone 16e. It does not prove
signed-device/TestFlight behavior, Universal Links, deeplinks, FATCA/persona
flows, live LLM semantic quality, account/cloud continuity, production backend
cutover, PDF export, VoiceOver traversal, or full product readiness.
