# Mint 2.0 First Experience Rente/Capital — Verification

## Planning Verification

Status: open.

Required before product code:

- `docs/MINT_AGENT_WORKFLOW.md` exists and links the agent/GSD/Claude/Codex workflow.
- Claude red-team review of workflow doc has no unresolved P1.
- `STATE-TABLE.md` exists.
- `golden-onboarding-archetypes.md` exists.
- Public-doc legal/admission lint passes for changed public docs.
- French accent lint passes for changed French docs.

## Implementation Verification Gates

G1 — Automated mobile path:

- Flutter analyze.
- Flutter tests for changed providers/screens/calculators.
- `./tools/mint-routes check` if routes touched.
- `flutter gen-l10n` and ARB parity if user-facing text touched.
- Maestro entry flow on simulator for first open -> three axes -> rente/capital -> result or missing-fields answer.
- The entry flow must start with `launchApp: { clearState: true }`.
- Existing row17 `/rente-vs-capital` deeplink flows are regression coverage for the pre-existing result surface only; they do not close the Mint 2.0 entry gate.
- Signalétique axes must have negative coverage: no amount, no simulation, no detailed unused collection.

G2 — Human/device:

- Julien or explicit owner tests on iPhone 13 mini or TestFlight.
- Keychain/iCloud restore risks remain open until real-device evidence exists.

G3 — Runtime/backend equivalence:

- staging or local equivalent named;
- backend pytest/ruff if backend touched;
- no simulator-only claim for Apple Sign In or Keychain deletion.

G4 — Regression:

- reset/new discussion/cold start still works;
- account keep/start-over handoff still works;
- old anonymous conversation does not resurrect after reset.

G5 — Compliance and product language:

- no banned LSFin terms;
- no financial number without provenance;
- no tax promise;
- no user-facing string outside ARB in product code.

## Current Planning Checks

To run after editing docs:

```bash
git diff --check -- docs/MINT_AGENT_WORKFLOW.md .planning/phases/mint-2-0-first-experience-rente-capital
python3 tools/checks/no_legal_admission_in_public_docs.py --paths docs/MINT_AGENT_WORKFLOW.md .planning/phases/mint-2-0-first-experience-rente-capital
python3 tools/checks/accent_lint_fr.py --file docs/MINT_AGENT_WORKFLOW.md
```

## Open Risks

- Existing dirty workspace contains unrelated auth/onboarding/reset changes.
- No product-code implementation for Mint 2.0 has started in this phase.
- The current phase does not close G2; it only defines how G2 will close later.
