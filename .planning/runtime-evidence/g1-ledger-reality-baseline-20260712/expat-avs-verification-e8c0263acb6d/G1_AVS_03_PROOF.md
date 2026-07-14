# G1-AVS-03 — Red → Green Proof

**Verdict:** `G1-AVS-03` is green at accepted SHA `3738568af9b01d34035c7b06344617b3f1995e03`. This closes only the quarantine of unofficial AVS gap effects. **G1 remains globally incomplete; G2/G3 are not authorized.**

## Red

- SHA: `9e10fb5920bbd1896a7cbb5583919fd530177888` (backend implementation commit; mobile quarantine not yet implemented).
- Artifact: [`red-mobile-quarantine.log`](avs-03/red-mobile-quarantine.log) — expected failure, exit 1, six quarantine assertions red.

## Green

- Backend commit: `9e10fb5920bbd1896a7cbb5583919fd530177888`; mobile/accepted commit: `3738568af9b01d34035c7b06344617b3f1995e03`.
- Canonical cross-stack contract: [`root-canonical-cross-stack-green.log`](avs-03/root-canonical-cross-stack-green.log) — 13 backend + 6 mobile assertions, exit 0.
- Full backend: [`green-full-pytest.log`](avs-03/green-full-pytest.log) — 6,072 passed, 6 skipped, exit 0.
- Flutter analyze: [`root-full-flutter-analyze.log`](avs-03/root-full-flutter-analyze.log) — zero issues.
- Policy hard floors: [`root-mobile-policy-gates.log`](avs-03/root-mobile-policy-gates.log) and [`root-lefthook-pre-commit-mobile-rerun.log`](avs-03/root-lefthook-pre-commit-mobile-rerun.log) — exit 0.

## Runtime at exact accepted SHA

Evidence: [`../runtime-exact-sha-3738568af`](runtime-exact-sha-3738568af/)

- MINT Doctor and Patrol tooling guard green.
- Patrol: 1/1 passed on iOS Simulator.
- Normal iOS simulator build/install: exit 0.
- Maestro: exit 0; count-only result, no personal CHF effect, both official AVS CTAs visible, screenshot captured.
- SHA `3738568af9b01d34035c7b06344617b3f1995e03` and clean status are identical before and after runtime.

## Global-suite caveat

The full Flutter suite reached 8,678 passed, 31 skipped, and 6 failed ([log](avs-03/root-full-flutter-test.log)). The same six failures were reproduced on clean baseline SHA `9e10fb5920bbd1896a7cbb5583919fd530177888` ([baseline reproduction](avs-03/root-full-suite-failures-targeted-clean-head.log)); they are global Flutter debt, not an AVS-03 regression. They remain open and prevent any claim that G1 is globally complete.

Machine-readable proof: [`g1-avs-03-machine-proof.json`](avs-03/g1-avs-03-machine-proof.json).
