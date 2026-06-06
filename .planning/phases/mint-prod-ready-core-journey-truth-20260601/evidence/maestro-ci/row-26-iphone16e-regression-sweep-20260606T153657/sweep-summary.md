# Maestro sweep — 20260606T153657

**Tier:** regression
**Flow count:** 6
**Watchdog stall threshold:** 90s
**Watchdog hard limit:** 420s
**Sweep dir:** `/Users/julienbattaglia/Desktop/MINT.nosync/.planning/_walker/sweep-20260606T153657`

## Per-flow results

| Exit | Flow | Hypothesis | Suspect file |
|---:|:---|:---|:---|
| ✅ | `bug__S005__landing_anonymous_cta_to_home` | — | `—` |
| ✅ | `bug__F001__chat_input_bar_exists` | — | `—` |
| ✅ | `bug__S001__cap_du_jour_action_bar_reachable` | — | `—` |
| ✅ | `bug__S002__maestro_cold_launch_fragment` | — | `—` |
| ✅ | `bug__P004__overlay_populated_on_open` | — | `—` |
| ✅ | `bug__F001_S001_combined__chat_via_cap_du_jour` | — | `—` |

## Totals

- ✅ green: 6 / 6
- ❌ red: 0 / 6
- ⏸️ stalled: 0 / 6
- 🛑 hard-limit: 0 / 6

## Next steps

Selected tier `regression` is green.

Scope note: `default` and `all` intentionally exclude opt-in
deeplink/Universal Link flows, and they exclude FATCA unless
the dedicated `fatca` tier is run against an expat_us build.
Do not use this summary alone as signed device/TestFlight or
store-signing evidence.
