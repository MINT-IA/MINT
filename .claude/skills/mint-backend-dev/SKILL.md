---
name: mint-backend-dev
description: Python/FastAPI backend development for MINT. Use when implementing rules_engine calculations, API endpoints, schemas, or fixing backend code in services/backend/. Enforces pure functions, Pydantic v2 schemas, pytest tests, and compliance guardrails.
compatibility: Requires Python 3.10+, FastAPI, pytest. Works in services/backend/ only.
metadata:
  author: mint-team
  version: "1.0"
---

# MINT Backend Development

## Scope

You work exclusively in `services/backend/`. Never touch `apps/mobile/`.

## Before Writing Any Code

Read these files first:
- `services/backend/app/services/rules_engine.py` — Core calculation engine
- `services/backend/app/schemas/` — All Pydantic v2 schemas
- `services/backend/app/api/v1/endpoints/` — API endpoints
- `tools/openapi/mint.openapi.canonical.json` — API contract (keep in sync)
- `SOT.md` — Source of Truth for data models
- `rules.md` — Project-wide rules

## Architecture

```
services/backend/
├── app/
│   ├── main.py              # FastAPI app
│   ├── core/config.py       # Settings
│   ├── api/v1/
│   │   ├── router.py        # Route aggregation
│   │   └── endpoints/       # REST endpoints
│   ├── schemas/             # Pydantic v2 models
│   │   ├── profile.py       # User profile
│   │   ├── scenario.py      # Simulation scenarios
│   │   ├── recommendation.py
│   │   └── session.py
│   ├── services/
│   │   └── rules_engine.py  # ALL financial calculations
│   └── routes/
│       └── wizard.py        # Wizard logic
└── tests/                   # pytest tests
```

## Rules Engine Patterns

### Pure Functions for Calculations
Every financial calculation must be a pure function (no side effects, deterministic):

```python
def compute_xxx(
    param1: float,
    param2: float,
    canton: str,
) -> dict:
    """
    Calculate XXX.

    Source: LPP art. XX / LIFD art. YY
    Hypotheses: [list assumptions]

    Returns:
        dict with result fields
    """
    # Calculation logic
    return {"result": value, "disclaimers": [...]}
```

### Adding a New Scenario

1. Add enum value in `schemas/scenario.py` → `ScenarioKind`
2. Create calculation function in `rules_engine.py`
3. Wire in `endpoints/scenarios.py` → `_compute_scenario_outputs()`
4. Add response schema in `schemas/scenario.py`
5. Write tests with hardcoded expected values
6. Update `tools/openapi/mint.openapi.canonical.json`
7. Update `SOT.md`

### Adding Profile Fields

1. Add to `ProfileBase` in `schemas/profile.py`
2. Add to `ProfileUpdate` if user-modifiable
3. Update `tools/openapi/mint.openapi.canonical.json`
4. Update `SOT.md`

## Testing Patterns

```python
# Test with hardcoded values (from swiss-brain specs)
class TestMyCalculation:
    def test_basic_case(self):
        result = compute_xxx(param1=100000, param2=0.068)
        assert result["value"] == 6800.0  # Exact expected value

    def test_edge_case(self):
        result = compute_xxx(param1=0, param2=0.068)
        assert result["value"] == 0.0
```

Use `TestClient(app)` for endpoint tests (NOT httpx.AsyncClient):
```python
from starlette.testclient import TestClient
from app.main import app

client = TestClient(app)
response = client.post("/api/v1/scenarios", json={...})
assert response.status_code == 200
```

## Compliance Guardrails

Every calculation function must:
1. Include source (law article) in docstring
2. Return `disclaimers: list[str]` in output
3. Never use words: "garanti", "optimal", "meilleur", "assuré"
4. Include "a titre indicatif" for estimations
5. Ranges/estimates clearly labeled as such

## Active Chantiers (read CLAUDE.md § STRATEGIC EVOLUTION DIGEST for full context)

### Chantier 1: Certificate → Profile Persistence
**Key endpoint**: `POST /document-parser/lpp` — extracts cert fields. Must wire to profile persistence.
**Key files**:
- `app/services/document_parser/lpp_certificate_parser.py` — LPP extraction
- `app/services/document_parser/avs_extract_parser.py` — AVS extraction
- `app/schemas/profile.py` — Profile schema (prevoyance fields)
- `app/api/v1/endpoints/document_parser.py` — Parser endpoints

### Chantier 2: Dashboard Data Endpoints
**Needed**: Unified `/retirement/dashboard` endpoint that returns:
- Income breakdown (AVS + LPP + 3a + Libre per source)
- Budget gap (income - tax - expenses)
- Top 3 arbitrage premiers éclairages
- Confidence score + enrichment prompts
- Couple phases (if applicable)
- Timeline/checklist items

### Golden Test Couple
Julien (50, CH, 100k) + Lauren (45, US/FATCA, 60k). Golden file: `test/golden/julien_lauren.xlsx`.

## Commands

```bash
# From services/backend/
ruff check .           # Lint
pytest -q              # Tests
pytest -q -x           # Stop at first failure
```

## Staging Promotion Authority

When Julien asks to promote a verified integration branch, backend agents may
help push to `staging` under CLAUDE.md §4.1: clean worktree, fetch + divergence
check, cited source verification, normal merge or fast-forward only, then plain
`git push origin staging`. Never force-push or rewrite `staging`, `dev`, or
`main`; if branch protection rejects direct push, open a PR into `staging`.

<!-- mint-data-architecture-v1-01-canonical:start -->
## Calc-engine ownership — L2-L4 backend-canonical (D-01..D-04, D-11)

`services/backend/app/services/` is the L2 comparer + L3 éclairer + L4 invariants canonical home — projection-class outputs with `constants_version_hash` audit trail, backend-canonical per Phase `mint-data-architecture-v1-01-calc-engine-canonical`. Boundary criterion = `services/backend/app/models/lucidity/_payload.py` discriminated type (L2ComparePayload / L3EclairePayload / L4InvariantPayload → backend ; L1ChiffrePayload → mobile).

### Regulatory source of truth

`services/backend/app/services/regulatory/registry.py` — `RegulatoryParameter` with `effective_from` / `effective_to` + active-version selection. Plan 03 exposes this via 2 endpoints :

- `GET /v1/regulatory/constants/version` — lightweight   `{active_version_hash, effective_from, last_updated}` for delta-check.
- `GET /v1/regulatory/constants/snapshot` — full 26-canton snapshot for the   Plan 04 build-time codegen consumer.

### Migration sequencing (D-CE-09 strangler-fig + D-CE-10 deprecation-shim)

Per-domain PRs (LPP, taxes, AVS, succession, divorce, frontalier …), each shipping :

1. Backend implementation of the migrated calc.
2. Mobile thin-client wrapper replacing the previous Dart implementation.
3. `@Deprecated` annotation on the old Dart class (1-release retention).
4. Parity test (mobile-wrapper vs backend output diff for a fixed scenario set).

Order : Monte Carlo + tornado sensitivity migrate FIRST (D-11 — highest LSFin audit risk, lowest UX coupling), then arbitrage engine, then withdrawal sequencing, then remaining L2+ calcs.

### Server-PRIMARY enforcement (D-CE-06)

All migrated L2-L4 calcs land in `services/backend/app/api/v1/endpoints/` with `Depends(get_profile_filled)` — the server is the PRIMARY enforcement layer for LSFin banned-terms + nLPD scrubbing ; mobile thin clients are presentation only, never re-implement calculator logic across the L1/L2 boundary.

<!-- mint-data-architecture-v1-01-canonical:end -->
