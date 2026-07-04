# JOS-005 iPhone 17 Pro Maestro Proof

Date: `2026-07-04T20:31:33Z`

Branch: `codex/mint-dataquest-transmit-property-clean`

Device: iPhone 17 Pro simulator, iOS 26.2, UDID `B03E429D-0422-4357-B754-536637D979F9`

Command:

```sh
bash tools/simulator/maestro_with_watchdog.sh test apps/mobile/.maestro/jos005_rente_vs_capital_before_account.yaml --format junit --output /tmp/mint-jos005-iphone17.xml
```

Result: passed, 1 flow, 0 failures, 14s.

Artifacts:

- `result.xml`
- `maestro.log`

Contract proven:

- `/rente-vs-capital` is reachable before account creation via runtime launch argument.
- `rente_vs_capital_screen` and `rvc_route_state` render.
- Account creation CTAs and generic error states are absent.

Device policy:

- This supersedes the earlier JOS-005 compact legacy iPhone proof as active evidence.
- Compact legacy iPhone targets remain historical evidence only, not acceptance targets.
