# Mint 2.0 First Experience Rente/Capital — Active Verification

Status: Active via router promotion. These checks describe the active contract.

## Planning Checks

```bash
git diff --check -- .planning/ACTIVE_CONTEXT.json .planning/phases/mint-2-0-first-experience-rente-capital
python3 tools/checks/no_legal_admission_in_public_docs.py --paths .planning/phases/mint-2-0-first-experience-rente-capital
git diff --name-only -- apps services tools docs rules.md AGENTS.md CLAUDE.md
python3 tools/checks/active_context_guard.py
python3 tools/checks/phase_contract_guard.py
python3 tools/checks/mint_rules_guard.py
python3 tools/checks/agent_reference_guard.py
python3 tools/checks/claude_hooks_guard.py
python3 tools/checks/verify_phase_acceptance.py
```

`verify_phase_acceptance.py` executes this active `SPEC.md` after router
promotion. Its deterministic tier is the planning promotion gate.

## Future Gates

G1 automated mobile: `flutter analyze`, focused Flutter tests,
`./tools/mint-routes check` if routes change, `flutter gen-l10n` and ARB parity
if user-facing text changes, Maestro first-entry flow, negative signalétique
tests.

G2 runtime and viewport: iPhone 13 mini simulator screenshot or UI snapshot;
real device remains required for Keychain/iCloud restore claims. PR #705
captured the first iPhone 13 mini route proof; rerun the flow for any behavior
change.

G3 calculation boundary: canonical L1 or L2-L4 source named; no UI calculation
copy; result receipt includes assumptions, sources, readiness, missing fields,
and version.

G4 dossier continuity: answer visible outside chat; reset/new discussion clears
local draft and conversation state; account handoff preserves or discards local
dossier only after explicit user choice. Local simulator coverage exists through
the Mint 2.0 quality gate; physical-device restore remains separate.

G5 language: no banned LSFin terms, no financial number without receipt, no tax
promise, future user-facing strings through ARB/i18n, French accents checked for
future FR copy.

## Slice 2 Plan Checks

The Slice 2 planning artifact must map every contract clause to a future test
file before product code starts:

- calculator boundary and fallback provenance;
- three axes at 375pt width;
- signalétique axes with zero calculator calls and zero financial numbers;
- chat navigation/orchestration only;
- dossier persistence without chat;
- versioned axis persistence and legacy intent migration;
- local-anonymous access before account handoff;
- ARB/i18n parity for future user-facing strings;
- clear-state first-entry Maestro proof on iPhone 13 mini.

## Open Blockers

The first Mint 2.0 runtime flow exists and landed through PR #705. PRs #710-#721
closed the local dossier/account handoff path, fresh anonymous financial residue
regression, and local quality gate. Remaining blocker: Keychain/iCloud restore
cannot be closed by simulator alone. Current physical-device preflight evidence:
`.planning/runtime-evidence/mint2-real-device-restore-gate-20260620T114221Z`
returned `BLOCKED_NO_AVAILABLE_DEVICE` for target `Jul`.
