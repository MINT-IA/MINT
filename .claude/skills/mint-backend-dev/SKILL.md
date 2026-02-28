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
- `tools/openapi/mint.openapi.yaml` — API contract (keep in sync)
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
6. Update `tools/openapi/mint.openapi.yaml`
7. Update `SOT.md`

### Adding Profile Fields

1. Add to `ProfileBase` in `schemas/profile.py`
2. Add to `ProfileUpdate` if user-modifiable
3. Update `tools/openapi/mint.openapi.yaml`
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
- Top 3 arbitrage chiffres chocs
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
