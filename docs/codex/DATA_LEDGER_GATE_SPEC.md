# DATA_LEDGER Phase 1 Gate Spec

This spec defines the binary gates that must exist before the MINT lucidity
variable registry can be accepted. It is owned by `mint-data-ledger-architect`
with Swiss numerical arbitration by `mint-swiss-brain`.

## Phase 1 Task 0: Baseline Audit

Before typed-contract implementation, produce:

`.planning/runtime-evidence/mint-lucidity-phase1-<timestamp>/DATA_LEDGER_BASELINE_AUDIT.md`

The audit must list:

- dead ledger keys: keys documented in `docs/codex/DATA_LEDGER.md` but not
  accepted, stored, read, or rendered anywhere
- undocumented live keys: keys accepted by backend/mobile but missing from
  `DATA_LEDGER.md`
- conflicting semantics: same key used with different type, unit, domain, or
  lifecycle meaning
- provenance gaps: keys that can affect a P0 case without source/confidence
  metadata

Minimum commands:

- `python3 -m pytest tools/checks/tests/test_codex_ledger_parity.py -q`
- `rg "save_fact|answers\\[|q_" services/backend apps/mobile docs/codex`
- `npx -y @mermaid-js/mermaid-cli -i docs/codex/WIRING_GRAPH.mmd -o <evidence>/WIRING_GRAPH.svg`

Phase 1 code work cannot start until this audit exists.

## Phase 1 Runtime Scope

Phase 1 accepts the three P0 product slices only within their documented runtime
proof scope:

- `first_salary_tax` is runtime-accepted through Patrol real-input proof on the
  local `/data-block/revenu` → `/pilier-3a` route pair; its
  `maestro_flow_id` remains `pending` until a separate Maestro proof can mutate
  the same fields without launch-argument seeds.
- `first_salary_tax` also has a Patrol FATCA variant: `nationality=US` is
  written as the single durable source (`q_nationality`), no
  `isFatcaResident` answer key is created, and `/pilier-3a` renders the derived
  non-contributable 3a state before exposing contribution controls.
- `buy_property` is runtime-accepted through Patrol real-input proof on the
  local `/data-block/revenu` → `/data-block/patrimoine` → `/hypotheque` route
  path; its `maestro_flow_id` remains `pending` for the same reason.
- `transmit_property` is runtime-accepted through the `/succession` runtime
  path, with Maestro coverage for the seeded screen proof and Patrol coverage
  for real owned-property input chronology.

These acceptances do not prove Android parity, production auth, full app shell
navigation, or persistence across restart. They prove that the accepted P0
variables are collected once, written through the ledger path, reused
chronologically, and rendered by the target product surface without duplicate
keys.

Until production account creation is accepted, local product proofs use a
device-local `profile_owner_id` generated once by
`LocalProfileOwnerService`. The secure store is the authority
(Keychain/Keystore through `flutter_secure_storage`); `SharedPreferences` is a
development/simulator fallback only. The id is persisted as
`_coach_profile_owner_id` alongside ledger metadata so dossiers and runtime
proof strips can tie collected variables to one local owner without inventing a
duplicate account model.

## Runtime Proof Build Policy

Phase 1 runtime proof may use debug/simulator launch arguments for deterministic
fixtures. Normal release and TestFlight builds must not expose a runtime-args
channel. On iOS the channel is available only under
`#if DEBUG || targetEnvironment(simulator)`. On Android it is controlled by
`BuildConfig.ENABLE_RUNTIME_ARGS_CHANNEL`, true only for debug.

For a non-debug QA device proof, the build must use a dedicated QA variant or a
compile-time define such as `--dart-define=MINT_ENABLE_RUNTIME_PROOF_SEMANTICS=true`.
The evidence must record the binary build mode, fixture source, and whether the
runtime-args channel was absent. Android production acceptance remains blocked
until an Android SDK/emulator proof runs the same gate on device or simulator.

## Gate 1: Backend Allowlist

Input:

- every variable key in `docs/codex/DATA_LEDGER.md`
- backend `save_fact` allowlist / accepted keys
- backend scenario service reads

Assertion:

- every backend-writeable key is declared in `DATA_LEDGER.md`
- no backend scenario reads a key absent from `DATA_LEDGER.md`
- any deliberate backend-only internal key is explicitly marked non-user-ledger

Pass/fail:

- pass when a pytest or check script exits 0 and reports zero undeclared
  backend-writeable user keys
- fail on any undeclared user key, orphan read, or silently accepted key

## Gate 2: Mobile Answer Switch

Input:

- every `DATA_LEDGER.md` key that has mobile source or mobile consumer
- `apps/mobile/lib/models/coach_profile.dart`
- `apps/mobile/lib/providers/coach_profile_provider.dart`

Assertion:

- every mobile-source key maps to a typed local field or `answers[...]` entry
- every mapped key has a write path and a read path
- every missing key has an explicit reason: backend-only, derived-only,
  future/P1, or removed

Pass/fail:

- pass when a Flutter/provider test or static check exits 0 and reports zero
  unclassified mobile-source keys
- fail on any key that can be written but not read, read but not written, or
  silently dropped

## Gate 3: Model Reads

Input:

- P0 case variable requirements
- backend scenario model/service reads
- Flutter `financial_core` and screen/provider reads

Assertion:

- every P0 required variable is either read by a scenario/calculator or
  explicitly marked as a guard-only question
- every calculation read has type, unit, confidence, and missing-value behavior
- every missing or stale value produces a degraded output, not a crash or a
  placeholder

Pass/fail:

- pass when targeted pytest/Flutter tests prove known, missing, and stale
  states for each P0 case
- fail on placeholder output, untyped read, unhandled missing value, or dead
  required variable

## Gate 4: Screen Consumers

Input:

- P0 route/screen contracts
- `docs/codex/SCREEN_CONTRACTS.md`
- route metadata and Flutter screens

Assertion:

- every P0 scenario output has a rendering target
- every known/estimated/stale/missing state has a visible affordance
- every next-question prompt is tied to a ledger key and case benefit
- no route is registered without a meaningful renderer

Pass/fail:

- pass when route/widget tests and at least one Maestro flow prove the visible
  state transition required by the phase
- fail on facade routes, static copy without live data, or hidden missing-data
  states

## Cross-Stack Fixture Schema

When backend and Flutter can compute or display the same financial result, the
fixture must use this minimum schema:

```json
{
  "fixture_id": "p0_first_salary_tax_vd_001",
  "case_id": "first_salary_tax",
  "profile_owner_id": "fixture-owner",
  "scenario_id": "fixture-scenario",
  "inputs": {
    "canton": "VD",
    "gross_salary_chf": 90000
  },
  "input_provenance": {
    "canton": {
      "source": "userInput",
      "confidence": "high",
      "source_date": null
    },
    "gross_salary_chf": {
      "source": "certificate",
      "confidence": "high",
      "source_date": "2026-01-31"
    }
  },
  "expected": {
    "computed.taxableIncome": {
      "value": 81200,
      "unit": "CHF",
      "tolerance": 1
    }
  },
  "authority": {
    "agent": "mint-swiss-brain",
    "source_refs": ["docs/codex/DATA_LEDGER.md"],
    "rationale": "canonical fixture value for backend/mobile parity"
  },
  "stack_paths": {
    "backend": "services/backend/...",
    "mobile": "apps/mobile/..."
  }
}
```

Rules:

- `mint-swiss-brain` owns the canonical Swiss value when stacks diverge.
- `mint-data-ledger-architect` owns the fixture schema and updates the ledger
  contract.
- backend/mobile adapt to the fixture; neither stack silently changes the
  canonical value.
- every fixture includes tolerance, unit, authority, source references, and
  input provenance `{source, confidence, source_date}` for every input.
- every P0 fixture `case_id` and input key must resolve through
  `docs/codex/P0_CASE_VARIABLE_REGISTRY.json`; scenario-specific assumptions
  are allowed only when the registry gives a reason and missing-value behavior.
