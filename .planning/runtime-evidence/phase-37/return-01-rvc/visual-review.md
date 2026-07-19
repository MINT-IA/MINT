# G1-RETURN-01 RVC LPP — visual review

- Runtime source SHA: `bc839242abc3e2c376363359cd77994355d77190`
- Runtime case: `G1-RETURN-01-RVC-LPP`
- Capture time: 2026-07-19 23:27 Europe/Zurich
- Synthetic data only; simulator identifier and host paths are redacted.

## Direct inspection

Both `runtime-bc839242ab-20260719T212504Z/final.png` (simctl) and
`runtime-bc839242ab-20260719T212504Z/maestro-final.png` (Maestro) were opened
at original resolution with Codex `view_image`.

Observed final state:

- title `Rente ou capital : ta décision` is visible;
- the Rente, Capital and Mixte education links are visible;
- the `Estimer pour moi` / `J'ai mon certificat` choice is rendered;
- age 50, retirement age 65 and annual salary CHF 108'000 are visible;
- current LPP is CHF 143'288; Patrol independently asserts the canonical
  provider value is CHF 143'287.50, proving the synthetic certificate write-back
  replaced the seeded CHF 350'000 value before the exact return;
- no scan/session/return identifier, filesystem path or personal identifier is
  visible;
- the Maestro capture is clean and readable; the simctl capture contains only
  the normal Dynamic Island overlay difference.

## Verdict

**PASS for the bounded final-state visual proof.** Patrol proves the exact
opaque pair, exact synthetic certificate SHA, canonical LPP write-back,
Review → Impact transition, exact-once consumption and literal RVC return.
Maestro and simctl independently capture the same returned RVC state. This does
not close G1 globally.
