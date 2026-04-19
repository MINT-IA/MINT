# AGENTS — Backend role (MINT)

> Loaded on-demand quand l'agent travaille dans `services/backend/` et détecte un contexte FastAPI/Python.
> Tier 2 (project-specific). Tier 1 = `rules.md`.
> Compagnon opérationnel : `.claude/skills/mint-backend-dev/SKILL.md`.

## 1. Architecture

```
services/backend/
├── app/
│   ├── main.py              # FastAPI app
│   ├── core/config.py       # Settings
│   ├── api/v1/
│   │   ├── router.py        # Route aggregation
│   │   └── endpoints/       # REST endpoints
│   ├── schemas/             # Pydantic v2 models (camelCase alias)
│   ├── services/
│   │   └── rules_engine.py  # ALL financial calculations
│   └── routes/
│       └── wizard.py        # Wizard logic
└── tests/                   # pytest suite
```

## 2. Commands

```bash
cd services/backend
python3 -m pytest tests/ -q          # Run all tests
pytest -q -x                          # Stop at first failure
uvicorn app.main:app --reload         # Dev server
ruff check app/                       # Linter
```

## 3. Backend Conventions

- **Pure functions** pour tous les calculs (déterministes, testables, no side effects).
- **Pydantic v2** : `ConfigDict(populate_by_name=True)`, `alias_generator = to_camel`.
- **Backend = source of truth** pour constants et formulas. Flutter mirrors, jamais n'invente.
- **Contract change** → update `tools/openapi/mint.openapi.canonical.json` + `SOT.md`.
- Backend enforce les banned terms compliance via `ComplianceGuard` avant réponse LLM.

## 4. Pydantic v2 pattern

```python
from pydantic import BaseModel, ConfigDict
from pydantic.alias_generators import to_camel

class ProjectionRequest(BaseModel):
    model_config = ConfigDict(
        populate_by_name=True,
        alias_generator=to_camel,
    )
    profile_id: UUID
    target_age: int
```

## 5. Rules Engine Patterns

Chaque calcul financier = fonction pure avec docstring normalisée :

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
        dict with result fields + disclaimer + sources
    """
    return {"result": value, "disclaimers": [...], "sources": [...]}
```

### Adding a New Scenario
1. Add enum value in `schemas/scenario.py` → `ScenarioKind`
2. Create calculation function in `rules_engine.py`
3. Wire in `endpoints/scenarios.py` → `_compute_scenario_outputs()`
4. Add response schema in `schemas/scenario.py`
5. Write tests avec valeurs attendues hardcodées
6. Update `tools/openapi/mint.openapi.canonical.json` + `SOT.md`

### Adding Profile Fields
1. Add to `ProfileBase` in `schemas/profile.py`
2. Add to `ProfileUpdate` si modifiable par user
3. Update `tools/openapi/mint.openapi.canonical.json` + `SOT.md`

## 6. Testing

- **Service files** : minimum 10 unit tests (edge cases + compliance).
- **Golden couple** : Julien + Lauren tested against known expected values (`test/golden/julien_lauren.xlsx`).
- **Pre-commit** : `pytest tests/ -q` green.
- **Post-commit** : CI runs `tools/checks/*.py` grep gates.
- Utiliser `TestClient(app)` depuis `starlette.testclient` (pas `httpx.AsyncClient`).

```python
class TestMyCalculation:
    def test_basic_case(self):
        result = compute_xxx(param1=100000, param2=0.068)
        assert result["value"] == 6800.0

    def test_edge_case(self):
        result = compute_xxx(param1=0, param2=0.068)
        assert result["value"] == 0.0
```

## 7. Compliance (backend outputs)

Chaque calculator/service output DOIT inclure :
- `disclaimer` — « outil éducatif », « ne constitue pas un conseil », « LSFin ».
- `sources` — Legal references (LPP art. X, LIFD art. Y).
- `premier_eclairage` — First personalized insight (replaces legacy `chiffre_choc`).
- `alertes` — Warnings quand thresholds crossed.

Banned words dans texte backend user-facing : « garanti », « optimal », « meilleur », « assuré », « certain ». Voir `docs/AGENTS/swiss-brain.md` §1.

## 8. Swiss law references (backend enforces)

LPP art. 7 / 8 / 14-16 / 79b | LAVS art. 21-40 / 35 | LIFD art. 22 / 38 | OPP2 art. 5 / OPP3 art. 7.

## 9. Key constants source

`services/backend/app/constants/` — backend est source of truth. Flutter `lib/constants/social_insurance.dart` miroir.

Phase 30.6 (cette phase) exposera via MCP tool `get_swiss_constants(category)`.

## 10. Error handling (pre-Phase 31)

- Current : 56 bare catches in backend (CLAUDE.md anti-pattern, Phase 36 FIX-05 target).
- Pre-Phase 31 : no new bare catches allowed (GUARD-02 lint enforce in Phase 34).
- Logging : structured JSON, include trace_id quand available.

## 11. FastAPI patterns

- Global exception handler à `app/main.py:169-180` — Phase 31 étend avec trace_id + sentry_event_id (OBS-03).
- `LoggingMiddleware` existant — preserve backward compat.
- Health endpoint `/health` requis pour Railway deploys.
- Env vars : `ANTHROPIC_API_KEY` sur les deux Railway environments.

## 12. Active Chantiers (references)

- **Certificate → Profile persistence** : `POST /document-parser/lpp`, wire vers `CoachProfile.prevoyance`.
  Files : `app/services/document_parser/*.py`, `app/schemas/profile.py`.
- **Dashboard Data Endpoints** : unified `/retirement/dashboard` endpoint (AVS + LPP + 3a + Libre, confidence, top-3 arbitrages).

## 13. Reference docs for Backend work

- `SOT.md` — data contracts (Profile, SessionReport, EnhancedConfidence).
- `tools/openapi/mint.openapi.canonical.json` — API contract canonique.
- `.claude/skills/mint-backend-dev/SKILL.md` — skill opérationnel (chantiers, patterns concrets).
- `LEGAL_RELEASE_CHECK.md` — pre-release compliance gate.
