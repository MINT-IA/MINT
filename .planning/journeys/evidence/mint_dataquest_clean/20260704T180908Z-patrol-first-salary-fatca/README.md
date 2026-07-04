# First Salary FATCA 3a Patrol Proof

Date: 2026-07-04T18:09:08Z

Branch: `codex/mint-dataquest-transmit-property-clean`

Device: iPhone 17 Pro simulator, iOS 26.2, UDID `B03E429D-0422-4357-B754-536637D979F9`

Command:

```bash
MINT_PATROL_CLEAN_BUILD=1 bash tools/checks/mint_lucidity_gate.sh mobile-first-salary-fatca-patrol B03E429D-0422-4357-B754-536637D979F9
```

Result: passed, 1 test, 0 failures.

Proof artifact:

- `xcresult-summary.json`

Contract proven:

- `nationality=US` remains the single FATCA source fact.
- No duplicate FATCA answer key is required.
- `/pilier-3a` renders the non-contributable 3a state.
- The 3a basis semantics expose `can_contribute_3a=false` and `plafond_3a=CHF 0`.

