# CJT-018 -- Current T6 AX capture

## Scope

This is a diagnostic capture only. It does not close CJT-018 and does not identify a new root cause.

## Runtime

- Built/installed current app on iPhone 17 Pro simulator `B03E429D-0422-4357-B754-536637D979F9`.
- Ran `cjt018_current_stop_at_t6.yaml`.
- Maestro JUnit passed: `cjt018_current_stop_at_t6`, `failures=0`, `time=23s`.
- Visual screenshots are stored in `cjt-018-current-t6-ax-capture-20260603T183126/`.

## AX Result

`idb ui describe-all` and point probes at the previously observed bad/visible CTA coordinates both returned a single empty `0x0` accessibility node:

- `idb-describe-all.txt`
- `idb-point-67-205.txt`
- `idb-point-201-610.txt`

This means this capture is useful as tool-state evidence only. It should not be used to infer that the T6 CTA is absent or fixed.

## Next Use

Use this alongside the earlier CJT-018 probes when comparing `idb`/MCP AX reliability against Maestro behavior. A future useful proof still needs a non-empty hierarchy on the same T6 screen, or a separate AX capture tool that can see the Flutter tree consistently.
