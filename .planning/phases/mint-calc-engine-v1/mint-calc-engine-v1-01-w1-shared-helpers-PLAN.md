---
phase: mint-calc-engine-v1
plan: 01
wave: 1
title: W1 — Shared profile-resolver helpers + client_with_blank_profile fixture
type: execute
depends_on: [A3-merge-or-cherry-pick]
files_modified:
  - services/backend/app/core/profile_resolver.py
  - services/backend/app/models/coach_tools/_response.py
  - services/backend/app/models/coach_tools/__init__.py
  - services/backend/tests/conftest.py
  - services/backend/tests/test_profile_resolver.py
  - services/backend/tests/test_get_profile_filled.py
autonomous: true
requirements: [D-CE-04, D-CE-06, D-CE-07, D-CE-08, D-CE-19, D-CE-20]
estimated_duration: 6
must_haves:
  truths:
    - "`_resolve_defaults(profile, body, schema_class)` returns merged dict honoring body > profile > default precedence and `model_fields_set` distinction"
    - "`get_profile_filled` FastAPI dependency reads `_user.profile.data` once per request and returns `dict[str, Any]`"
    - "`raise_incomplete_as_422` produces HTTPException(422) carrying `CoachToolIncomplete` envelope verbatim from A3 (D-CE-04 inheritance)"
    - "`client_with_blank_profile()` pytest fixture exists in `conftest.py` and yields a TestClient whose authenticated user has `profile.data == {}` (Concern D)"
  artifacts:
    - path: services/backend/app/core/profile_resolver.py
      provides: "_resolve_defaults + _required_profile_fields_missing + raise_incomplete_as_422 + get_profile_filled"
      min_lines: 60
    - path: services/backend/app/models/coach_tools/_response.py
      provides: "A3 envelope cherry-picked or inherited — CoachToolOk + CoachToolIncomplete + CoachToolPolicyBlocked + CoachToolResponse"
      min_lines: 70
    - path: services/backend/tests/test_profile_resolver.py
      provides: "≥6 unit tests covering precedence + explicit-None vs unset + missing-fields cap=3 + envelope shape"
      min_lines: 100
    - path: services/backend/tests/conftest.py
      provides: "client_with_blank_profile fixture appended (idempotent — must not break existing fixtures)"
  key_links:
    - from: services/backend/app/core/profile_resolver.py
      to: services/backend/app/models/coach_tools/_response.py
      via: "from app.models.coach_tools._response import CoachToolIncomplete"
      pattern: "from app.models.coach_tools._response import"
    - from: services/backend/app/core/profile_resolver.py
      to: services/backend/app/core/auth.py
      via: "from app.core.auth import require_current_user"
      pattern: "require_current_user"
    - from: services/backend/tests/conftest.py
      to: services/backend/app/models/profile_model.py
      via: "ProfileModel insert with data={}"
      pattern: "profile.*data.*{}|ProfileModel\\("
---

<objective>
Ship the foundation helpers W1 plans 02-06 (and all W2-W4) depend on. Three primitives + one pytest fixture, isolated in 4 files, no endpoint surface touched yet.

Purpose: D-CE-07 + D-CE-06 + D-CE-08 require a SHARED `_resolve_defaults` helper, a SHARED FastAPI dependency `get_profile_filled`, and a SHARED `raise_incomplete_as_422` function that wraps A3's `CoachToolIncomplete` envelope (D-CE-04 doctrine unity). Concern D requires a `client_with_blank_profile()` fixture to reproduce-the-bug-first per Karpathy #4 — without it, happy-path test fixtures pass the 422 check while real users hit the bug.

Output: 1 new helper module + A3 envelope copy + 2 new test files + 1 fixture extension on `conftest.py`.
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
</execution_context>

<context>
@.planning/STATE.md
@.planning/ROADMAP.md
@.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-CONTEXT.md
@.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-RESEARCH.md
@.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-VALIDATION.md

# A3 envelope IS the contract — D-CE-04
@services/backend/app/services/coach/coach_tools.py
@services/backend/app/api/v1/endpoints/coach_chat.py
@services/backend/app/core/auth.py
@services/backend/app/models/profile_model.py
</context>

<interfaces>
<!-- Extracted from A3 branch (sha 2e1060a5) services/backend/app/models/coach_tools/_response.py -->
<!-- Executor MUST copy this verbatim — D-CE-04 doctrine unity, no rewrite -->

From feature/wave-1c-A3-missing-fields-handshake:services/backend/app/models/coach_tools/_response.py:

```python
from __future__ import annotations
from typing import Annotated, Any, Literal, Union
from pydantic import BaseModel, ConfigDict, Field, RootModel, field_validator
from pydantic.alias_generators import to_camel

_MAX_MISSING_FIELDS = 3  # D-A3-01 conversational handshake cap

class _Base(BaseModel):
    model_config = ConfigDict(populate_by_name=True, alias_generator=to_camel, frozen=True)

class CoachToolOk(_Base):
    status: Literal["ok"] = "ok"
    data: dict[str, Any]

class CoachToolIncomplete(_Base):
    status: Literal["incomplete"] = "incomplete"
    missing_fields: list[str] = Field(..., min_length=1)
    hint_fr: str = Field(..., min_length=10)

    @field_validator("missing_fields")
    @classmethod
    def _cap_missing_fields(cls, v: list[str]) -> list[str]:
        if len(v) > _MAX_MISSING_FIELDS:
            raise ValueError(...)
        return v

class CoachToolPolicyBlocked(_Base):
    status: Literal["policy_blocked"] = "policy_blocked"
    reason_code: str
    message_fr: str

CoachToolResponse = RootModel[Annotated[
    Union[CoachToolOk, CoachToolIncomplete, CoachToolPolicyBlocked],
    Field(discriminator="status"),
]]
```

From services/backend/app/core/auth.py:111 (verified by RESEARCH §Q-B):
```python
def require_current_user(...) -> User: ...
```

From services/backend/app/core/database.py:35 (verified):
```python
def get_db() -> Session: ...  # yield-style dependency
```

From services/backend/app/models/profile_model.py:37 (verified):
```python
class ProfileModel(Base):
    data: MutableDict.as_mutable(JSONEncodedDict)  # dict[str, Any]
```
</interfaces>

<tasks>

<task id="W1-01-00" type="auto" tdd="false">
  <name>Task 0: Cherry-pick or merge A3 envelope to dev</name>
  <files>services/backend/app/models/coach_tools/_response.py, services/backend/app/models/coach_tools/__init__.py</files>
  <read_first>
    - .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-CONTEXT.md (D-CE-04, D-CE-19 Parallel Change)
    - .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-RESEARCH.md §Q-B (envelope shape)
    - services/backend/app/models/coach_tools/__init__.py (current empty marker — line 1-7)
    - feature/wave-1c-A3-missing-fields-handshake:services/backend/app/models/coach_tools/_response.py (the source-of-truth blob)
  </read_first>
  <action>
    Check `git log --oneline -- services/backend/app/models/coach_tools/_response.py` on `dev`. Two paths:

    **Path A (preferred) — A3 PR #643 already merged to dev:**
    1. `git pull origin dev`
    2. Verify file exists: `test -f services/backend/app/models/coach_tools/_response.py && head -5 services/backend/app/models/coach_tools/_response.py`
    3. If exists with the 4-class envelope (CoachToolOk + CoachToolIncomplete + CoachToolPolicyBlocked + CoachToolResponse RootModel), skip to Task 1.

    **Path B — A3 not yet merged (D-CE-19 Parallel Change cherry-pick):**
    1. `git fetch origin feature/wave-1c-A3-missing-fields-handshake`
    2. `git checkout origin/feature/wave-1c-A3-missing-fields-handshake -- services/backend/app/models/coach_tools/_response.py`
    3. Update `services/backend/app/models/coach_tools/__init__.py` to export the envelope:
       ```python
       """Wave 1a coach-tools response models + Wave 1c-A3 envelope (D-CE-04)."""
       from app.models.coach_tools._response import (
           CoachToolOk,
           CoachToolIncomplete,
           CoachToolPolicyBlocked,
           CoachToolResponse,
       )
       __all__ = [
           "CoachToolOk",
           "CoachToolIncomplete",
           "CoachToolPolicyBlocked",
           "CoachToolResponse",
       ]
       ```
    4. Commit: `cherry-pick(wave-1c-A3): bring CoachToolResponse envelope into mint-calc-engine-v1 W1 base per D-CE-04 + D-CE-19 Parallel Change`

    DO NOT modify the envelope structure — D-CE-04 mandates verbatim inheritance. If the A3 branch envelope differs from the RESEARCH.md interface block above, use the A3 branch version (it is the source of truth).
  </action>
  <verify>
    <automated>test -f services/backend/app/models/coach_tools/_response.py && python3 -c "from app.models.coach_tools import CoachToolIncomplete, CoachToolOk, CoachToolResponse; print('OK')" || echo "ENVELOPE MISSING"</automated>
  </verify>
  <acceptance_criteria>
    - `services/backend/app/models/coach_tools/_response.py` exists with 4 classes (`CoachToolOk`, `CoachToolIncomplete`, `CoachToolPolicyBlocked`) + `CoachToolResponse = RootModel[Annotated[Union[...], Field(discriminator="status")]]`
    - `grep -c "class CoachToolIncomplete" services/backend/app/models/coach_tools/_response.py` returns `1`
    - `grep -c "_MAX_MISSING_FIELDS = 3" services/backend/app/models/coach_tools/_response.py` returns `1`
    - `python3 -c "from app.models.coach_tools._response import CoachToolIncomplete; m = CoachToolIncomplete(missing_fields=['canton'], hint_fr='J ai besoin de ton canton pour calculer.'); print(m.model_dump(by_alias=True))"` prints a dict with `status`, `missingFields`, `hintFr` keys (camelCase verified)
    - `python3 -m pytest services/backend/tests/ -q -x -k "test_coach_tool_response or test_a3_envelope" 2>&1 | tail -5` exits 0 (if A3 tests already exist) OR no-collect (if not yet merged)
  </acceptance_criteria>
  <done>A3 envelope present on the W1 branch + importable from `app.models.coach_tools`</done>
</task>

<task id="W1-01-01" type="auto" tdd="true">
  <name>Task 1: Write _resolve_defaults helper + tests (RED then GREEN)</name>
  <files>services/backend/app/core/profile_resolver.py, services/backend/tests/test_profile_resolver.py</files>
  <read_first>
    - .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-RESEARCH.md §Q-B (canonical implementation lines 282-340 + model_fields_set semantics)
    - .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-VALIDATION.md (W1-01-01..03 verify map)
    - services/backend/app/models/coach_tools/_response.py (CoachToolIncomplete signature)
    - services/backend/app/core/auth.py:111 (require_current_user signature)
    - services/backend/app/core/database.py (get_db signature)
    - services/backend/app/models/profile_model.py:37 (ProfileModel.data type)
  </read_first>
  <behavior>
    - Test 1: `_resolve_defaults(profile={"canton": "GE"}, body=Req(canton=None), schema=Req)` returns `{"canton": None}` because body explicitly set canton (in `model_fields_set`) — body wins even when None (explicit clear).
    - Test 2: `_resolve_defaults(profile={"canton": "GE"}, body=Req(), schema=Req)` returns `{"canton": "GE"}` because body did NOT set canton (NOT in `model_fields_set`), so profile fills via `json_schema_extra={"from_profile": "canton"}`.
    - Test 3: `_resolve_defaults(profile={}, body=Req(), schema=Req)` returns `{"canton": None}` because no profile mapping → falls through to Pydantic default.
    - Test 4: `_resolve_defaults(profile=None, body=Req(canton="VD"), schema=Req)` returns `{"canton": "VD"}` — None profile treated as empty dict.
    - Test 5: `_required_profile_fields_missing` returns the profile-key list (NOT body-field list) capped at 3.
    - Test 6: `_required_profile_fields_missing` only flags fields with `json_schema_extra={"from_profile": ...}` — fields without the marker are NOT considered required-via-profile.
    - Test 7: `raise_incomplete_as_422(missing_fields=["canton"], hint_fr="...")` with `PROFILE_GROUNDING_STRICT_MODE=true` raises `HTTPException(status_code=422)` whose `detail` is a dict matching `CoachToolIncomplete.model_dump(by_alias=True)` shape (camelCase: `status`, `missingFields`, `hintFr`).
    - Test 8: `raise_incomplete_as_422(missing_fields=["a","b","c","d"], hint_fr="...")` raises `ValueError` from the `CoachToolIncomplete._cap_missing_fields` validator (4 > 3 cap inherited from A3 D-A3-01) — the helper must NOT silently truncate ; the cap belongs to the envelope. Test runs in BOTH strict and non-strict modes (cap is envelope-level, mode-independent).
    - Test 9 (D-CE-08 non-strict graceful fallback): `raise_incomplete_as_422(missing_fields=["canton"], hint_fr="...", resolved_body={"x":1}, endpoint="/foo")` with `PROFILE_GROUNDING_STRICT_MODE=false` does NOT raise — returns `{"x":1}` (the resolved_body passthrough) AND emits a `logger.warning` with `extra={endpoint, missing_fields, hint_fr}`. Use `caplog.records` fixture to assert the warning + extra dict shape.
    - Test 10 (D-CE-08 default ENV value): `os.getenv("PROFILE_GROUNDING_STRICT_MODE", "false")` defaults to `"false"` — running pytest WITHOUT setting the env var puts the helper in non-strict mode. Strict mode requires explicit opt-in.
  </behavior>
  <action>
    Create `services/backend/app/core/profile_resolver.py` matching RESEARCH §Q-B lines 282-403 verbatim. Use this signature contract:

    ```python
    # services/backend/app/core/profile_resolver.py
    import logging
    import os
    from typing import Any
    from fastapi import HTTPException, Depends, status
    from pydantic import BaseModel
    from sqlalchemy.orm import Session
    from app.core.auth import require_current_user
    from app.core.database import get_db
    from app.models.user import User
    from app.models.profile_model import ProfileModel
    from app.models.coach_tools._response import CoachToolIncomplete


    def _resolve_defaults(
        profile_data: dict[str, Any] | None,
        body: BaseModel,
        schema_class: type[BaseModel],
    ) -> dict[str, Any]:
        """Merge body > profile > default. See RESEARCH §Q-B for precedence rules.

        Verified semantics:
          - field in body.model_fields_set → respect body value (even None = explicit clear)
          - field NOT in body.model_fields_set AND json_schema_extra.from_profile present AND profile has key → fill from profile
          - otherwise → fall through to Pydantic default (typically None)
        """
        if profile_data is None:
            profile_data = {}
        resolved: dict[str, Any] = {}
        body_set = body.model_fields_set
        for name, field_info in schema_class.model_fields.items():
            if name in body_set:
                resolved[name] = getattr(body, name)
                continue
            extra = field_info.json_schema_extra or {}
            profile_key = extra.get("from_profile") if isinstance(extra, dict) else None
            if profile_key and profile_key in profile_data and profile_data[profile_key] is not None:
                resolved[name] = profile_data[profile_key]
            else:
                resolved[name] = getattr(body, name)
        return resolved


    def _required_profile_fields_missing(
        resolved: dict[str, Any],
        schema_class: type[BaseModel],
    ) -> list[str]:
        """Report PROFILE KEYS (not body field names) that resolved to None, capped at 3."""
        missing: list[str] = []
        for name, field_info in schema_class.model_fields.items():
            extra = field_info.json_schema_extra or {}
            if isinstance(extra, dict) and "from_profile" in extra:
                if resolved.get(name) is None:
                    missing.append(extra["from_profile"])
        return missing[:3]


    # D-CE-08 feature flag for graceful Flutter rollout
    # rollout : staging strict=true → prod strict=false (1 release) → prod strict=true
    PROFILE_GROUNDING_STRICT_MODE: bool = (
        os.getenv("PROFILE_GROUNDING_STRICT_MODE", "false").lower() == "true"
    )

    _logger = logging.getLogger(__name__)


    def raise_incomplete_as_422(
        missing_fields: list[str],
        hint_fr: str,
        *,
        resolved_body: dict[str, Any] | None = None,
        endpoint: str | None = None,
    ) -> dict[str, Any]:
        """D-CE-08: raise HTTPException(422) carrying CoachToolIncomplete envelope (D-CE-04)
        if PROFILE_GROUNDING_STRICT_MODE; otherwise emit warning + return resolved_body (graceful fallback).

        Returns the body dict ONLY in non-strict path — caller must use the return value
        to continue computation in the legacy hardcoded-defaults branch. In strict path,
        the function never returns (raises HTTPException).
        """
        incomplete = CoachToolIncomplete(missing_fields=missing_fields, hint_fr=hint_fr)
        if PROFILE_GROUNDING_STRICT_MODE:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=incomplete.model_dump(by_alias=True),
            )
        # graceful fallback : log + return resolved body (legacy behavior continues)
        _logger.warning(
            "profile_grounding_incomplete_non_strict",
            extra={
                "endpoint": endpoint or "unknown",
                "missing_fields": missing_fields,
                "hint_fr": hint_fr,
            },
        )
        return resolved_body or {}


    def get_profile_filled(
        user: User = Depends(require_current_user),
        db: Session = Depends(get_db),
    ) -> dict[str, Any]:
        """FastAPI dep: return authenticated user's profile.data dict (or {} if none)."""
        profile = (
            db.query(ProfileModel)
            .filter(ProfileModel.user_id == user.id)
            .order_by(ProfileModel.updated_at.desc())
            .first()
        )
        return profile.data if profile and profile.data else {}
    ```

    Then write `services/backend/tests/test_profile_resolver.py` with the 10 unit tests from the `<behavior>` block above. Use the FLAT `tests/test_*.py` convention (Wave 1c-A3 precedent — per RESEARCH §Q-I). Define a small `_TestRequest(BaseModel)` schema inline with `canton: Optional[str] = Field(default=None, json_schema_extra={"from_profile": "canton"})` for precedence tests. For Tests 9-10 (D-CE-08 strict-mode branching), use `monkeypatch.setenv("PROFILE_GROUNDING_STRICT_MODE", "true"/"false")` + `caplog.set_level(logging.WARNING)` + reload the module (`importlib.reload(profile_resolver)`) so the env-time-set flag re-evaluates.

    DO NOT instantiate the FastAPI app or use TestClient — these are pure-Python unit tests. `get_profile_filled` integration test ships in Task 2.

    LSFin: hint_fr fixtures use « J'ai besoin de ton canton pour estimer... » — no banned terms.
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/test_profile_resolver.py -q -x</automated>
  </verify>
  <acceptance_criteria>
    - `services/backend/app/core/profile_resolver.py` exists, ≥60 lines
    - `grep -c "def _resolve_defaults" services/backend/app/core/profile_resolver.py` returns `1`
    - `grep -c "def _required_profile_fields_missing" services/backend/app/core/profile_resolver.py` returns `1`
    - `grep -c "def raise_incomplete_as_422" services/backend/app/core/profile_resolver.py` returns `1`
    - `grep -c "def get_profile_filled" services/backend/app/core/profile_resolver.py` returns `1`
    - `grep -c "PROFILE_GROUNDING_STRICT_MODE" services/backend/app/core/profile_resolver.py` returns `≥2` (declaration + branch in `raise_incomplete_as_422`) — D-CE-08 feature flag wired
    - `grep "from app.models.coach_tools._response import CoachToolIncomplete" services/backend/app/core/profile_resolver.py` returns 1 match
    - `cd services/backend && python3 -m pytest tests/test_profile_resolver.py -q -x` exits 0 with ≥10 tests passed (8 base + Test 9 non-strict graceful fallback + Test 10 ENV default)
    - `python3 tools/checks/banned_terms_python.py services/backend/app/core/profile_resolver.py services/backend/tests/test_profile_resolver.py` exits 0
    - `python3 tools/checks/accent_lint_fr.py --scope backend 2>&1 | grep profile_resolver` returns no errors
  </acceptance_criteria>
  <done>Helper module shipped + 8 unit tests green</done>
</task>

<task id="W1-01-02" type="auto" tdd="true">
  <name>Task 2: get_profile_filled FastAPI integration test</name>
  <files>services/backend/tests/test_get_profile_filled.py</files>
  <read_first>
    - .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-RESEARCH.md §Q-B Endpoint integration pattern
    - services/backend/app/core/profile_resolver.py (just created in Task 1)
    - services/backend/tests/conftest.py (existing fixtures — pattern reuse, DO NOT modify yet)
    - services/backend/app/main.py (FastAPI app instantiation)
    - services/backend/tests/coach/test_claude_retry.py:30-60 (AsyncMock + patch precedent)
  </read_first>
  <behavior>
    - Test 1: When `_user` has a profile with `data={"canton": "GE", "age": 35}`, `get_profile_filled` returns exactly `{"canton": "GE", "age": 35}`.
    - Test 2: When `_user` has a profile with `data=None`, `get_profile_filled` returns `{}`.
    - Test 3: When `_user` has NO profile row, `get_profile_filled` returns `{}`.
    - Test 4: When 2 profiles exist for the same user (race), the most recent by `updated_at DESC` wins.
    - Test 5: A mini probe endpoint declared inside the test fixture using `Depends(get_profile_filled)` returns the dict via JSON 200 (proves the dep chains under FastAPI's resolver).
  </behavior>
  <action>
    Write `services/backend/tests/test_get_profile_filled.py`. Use a minimal `FastAPI()` test app instantiated inside fixtures (NOT the production app — keeps test isolated). Insert ProfileModel rows directly via the test session.

    Pattern:
    ```python
    import pytest
    from fastapi import Depends, FastAPI
    from fastapi.testclient import TestClient
    from app.core.profile_resolver import get_profile_filled
    from app.models.profile_model import ProfileModel
    from app.models.user import User

    def _make_probe_app():
        app = FastAPI()
        @app.get("/_probe/profile")
        def probe(profile=Depends(get_profile_filled)):
            return profile
        return app

    def test_returns_profile_data_dict(test_db_session, authed_user):
        # Insert profile with data={"canton": "GE"}
        ...

    def test_returns_empty_dict_when_no_profile(test_db_session, authed_user):
        ...

    def test_picks_most_recent_when_multiple(test_db_session, authed_user):
        ...
    ```

    Reuse the existing `test_db_session` + `authed_user` fixtures from `conftest.py`. If unsure of their exact names, grep `services/backend/tests/conftest.py | grep "^def "` to confirm.
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/test_get_profile_filled.py -q -x</automated>
  </verify>
  <acceptance_criteria>
    - `services/backend/tests/test_get_profile_filled.py` exists with ≥5 tests
    - `cd services/backend && python3 -m pytest tests/test_get_profile_filled.py -q -x` exits 0
    - `grep -c "Depends(get_profile_filled)" services/backend/tests/test_get_profile_filled.py` returns ≥1
  </acceptance_criteria>
  <done>FastAPI-resolver integration test green, proves dep chain works under real app</done>
</task>

<task id="W1-01-04" type="auto" tdd="false">
  <name>Task 3: client_with_blank_profile pytest fixture (Concern D)</name>
  <files>services/backend/tests/conftest.py</files>
  <read_first>
    - .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-CONTEXT.md §Concern D (Karpathy #4 reproduce-the-bug-first)
    - .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-RESEARCH.md §Q-I Wave 0 Gaps
    - services/backend/tests/conftest.py (current state — DO NOT break existing fixtures)
    - services/backend/app/models/profile_model.py (data column type)
  </read_first>
  <action>
    APPEND (not overwrite) to `services/backend/tests/conftest.py`. The new fixture creates an authenticated user whose `ProfileModel.data == {}` — this is the « blank profile » state W1-06 contract tests use to assert 422 fires.

    ```python
    @pytest.fixture
    def client_with_blank_profile(test_db_session):
        """Concern D — Karpathy #4 reproduce-the-bug-first.

        Yields a TestClient authenticated as a user whose profile.data == {}.
        Use in 1 contract test per Wave-1-fixed endpoint to assert 422 fires
        when profile fields are missing (D-CE-08).
        """
        from app.main import app
        from app.models.user import User
        from app.models.profile_model import ProfileModel
        from fastapi.testclient import TestClient
        # Create user + blank profile
        user = User(email="blank-profile@test.mint", ...)
        test_db_session.add(user)
        test_db_session.flush()
        profile = ProfileModel(user_id=user.id, data={})
        test_db_session.add(profile)
        test_db_session.commit()
        # Auth header injection (reuse existing pattern from authed_client fixture)
        client = TestClient(app)
        client.headers.update({"Authorization": f"Bearer {_issue_jwt(user)}"})
        try:
            yield client
        finally:
            test_db_session.delete(profile)
            test_db_session.delete(user)
            test_db_session.commit()
    ```

    Reuse the existing JWT issuance helper (likely `_issue_jwt` or similar — grep `conftest.py | grep -i jwt` to find). DO NOT duplicate JWT logic.

    Surgical change rule (Karpathy #3): only APPEND the new fixture + any minimal imports. DO NOT reformat existing fixtures.
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/conftest.py --collect-only 2>&1 | grep -E "client_with_blank_profile|fixture" | head -3 ; cd services/backend && python3 -m pytest tests/ -q -x --co 2>&1 | tail -3</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "def client_with_blank_profile" services/backend/tests/conftest.py` returns `1`
    - `cd services/backend && python3 -m pytest tests/ -q --co 2>&1 | tail -3` shows collection success (no fixture-resolution errors)
    - `python3 tools/checks/banned_terms_python.py services/backend/tests/conftest.py` exits 0
    - Existing fixture count is preserved: `grep -cE "^def [a-z_]+\(|^@pytest.fixture" services/backend/tests/conftest.py` is ≥ baseline pre-task
  </acceptance_criteria>
  <done>Fixture appended, existing test suite still collects cleanly</done>
</task>

<task id="W1-01-99" type="auto" tdd="false">
  <name>Task 4: Full suite regression check + engram memory save</name>
  <files>services/backend/tests/</files>
  <read_first>
    - .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-CONTEXT.md §Memory Contract (Concern F)
    - .planning/STATE.md (last known pytest baseline ~6900+ tests per Plan wave-1b-08 receipt)
  </read_first>
  <action>
    Run full backend suite to confirm zero regression. Baseline per STATE.md: 6898 passed / 62 skipped / 1 xfailed (Plan wave-1b-08 close-out 2026-05-15).

    Expected post-plan: previous baseline + 8 (test_profile_resolver) + 5 (test_get_profile_filled) = ~6911 passed. Skipped count unchanged.

    Then save engram observation:
    - `topic_key: calc_engine:w1:foundation:profile_resolver_helpers_shipped`
    - `type: discovery`
    - `prior_finding_refs: [#89 (A3 envelope), #103 (panel synthesis), #104-107 (W0 audit)]`
    - Content: « `_resolve_defaults` + `get_profile_filled` + `raise_incomplete_as_422` shipped at `services/backend/app/core/profile_resolver.py`. A3 envelope cherry-picked. Plans W1-02..W1-06 + all W2-W4 grounding work can now `from app.core.profile_resolver import _resolve_defaults`. Concern D fixture `client_with_blank_profile` lands in `conftest.py`. »
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/ -q 2>&1 | tail -3</automated>
  </verify>
  <acceptance_criteria>
    - Full suite: `cd services/backend && python3 -m pytest tests/ -q` exits 0
    - Test count: passed count is ≥ baseline (per STATE.md 6898) + new tests created in W1-01-01 + W1-01-02 (≥13 new). Allow ±2 tolerance for cross-baseline drift.
    - Lints: `python3 tools/checks/banned_terms_python.py services/backend/app/core/profile_resolver.py services/backend/tests/test_profile_resolver.py services/backend/tests/test_get_profile_filled.py services/backend/tests/conftest.py` exits 0
    - Accent FR: `python3 tools/checks/accent_lint_fr.py --scope backend 2>&1 | grep -E "profile_resolver|test_profile_resolver" | grep -i error` returns 0 hits
    - Engram saved: response from `mem_save` shows `obs_id` returned
  </acceptance_criteria>
  <done>Full suite green, lints green, engram observation persisted with prior_finding_refs</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Client → REST endpoint | Body crosses untrusted boundary. `_resolve_defaults` MUST respect body.model_fields_set (explicit-None signal preserved) |
| REST endpoint → ProfileModel | `_user.profile` read via SQLAlchemy session. Authoritative source-of-truth for profile fields. |
| profile_resolver helper → CoachToolIncomplete | Envelope inherited verbatim from A3 (D-CE-04) — single contract for REST + coach dispatcher |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-mint-calc-01-01 | Spoofing | get_profile_filled dep | mitigate | `Depends(require_current_user)` already 401's anonymous users (verified at `app/core/auth.py:111`). Helper only reads `user.id` — no profile-id spoofing surface. |
| T-mint-calc-01-02 | Tampering | _resolve_defaults body override | mitigate | body.model_fields_set distinguishes « client sent null » from « client omitted » — naive `if body.X is not None` would let attacker silently bypass profile-grounding by omitting field. Test W1-01-01 Test 2 covers this. |
| T-mint-calc-01-03 | Information disclosure | raise_incomplete_as_422 detail | mitigate | `missing_fields` returns PROFILE KEYS (canonical field names), NOT profile VALUES. Hint_fr is generic FR text, no PII leak. CoachToolIncomplete cap=3 limits leak surface even on attacker-crafted requests. |
| T-mint-calc-01-04 | Repudiation | client_with_blank_profile fixture | accept | Test-only fixture, never reaches production. No audit log needed. |
| T-mint-calc-01-05 | DoS | get_profile_filled DB read | accept | 1 indexed query per request (`user_id` + `updated_at DESC LIMIT 1`). Existing ProfileModel queries follow same pattern. No new DoS vector. |
| T-mint-calc-01-06 | Elevation of privilege | profile data read | accept | Helper reads ONLY the authenticated user's own profile (filter `ProfileModel.user_id == user.id`). No cross-user access path added. |
| T-mint-calc-01-07 | LSFin banned terms | hint_fr fixtures | mitigate | `banned_terms_python.py` lint runs on every commit per CLAUDE.md §1. Test docstrings use « pourrait / envisager / adapté » vocabulary. |
</threat_model>

<verification>
- Full backend suite green (≥6911 passed, see Task 4 acceptance criteria)
- 4 new files created, 1 file appended (conftest.py)
- All acceptance criteria for tasks 0-4 met
- Lints exit 0 on touched files
</verification>

<success_criteria>
- `_resolve_defaults`, `_required_profile_fields_missing`, `raise_incomplete_as_422`, `get_profile_filled` callable from `app.core.profile_resolver` import path
- `CoachToolIncomplete` envelope identical to A3 branch (D-CE-04 verbatim inheritance)
- `client_with_blank_profile` fixture available in `conftest.py` for W1-02..W1-06 contract tests
- ≥13 new tests, full suite green
- Engram observation saved with `topic_key: calc_engine:w1:foundation:*` + prior_finding_refs to #89/#103/#104-107
</success_criteria>

<a3_state as_of="2026-05-16T12:50Z">
**A3 PR #643 status at plan-lock time (engram obs #116, founder-confirmed in chat):**
- PR `https://github.com/MINT-IA/MINT/pull/643` is **OPEN against `dev`**, NOT yet merged.
- Branch `feature/wave-1c-A3-missing-fields-handshake` pushed, mergeable=MERGEABLE.
- **5/5 pre-push panel D-A3-10 verdict = CLEAN** (1 MAJOR token-budget documented + 4 MINOR acknowledged + 0 BLOCKED). The `CoachToolResponse` envelope contract is panel-verified stable.
- CI in progress: 8 fast PASS, 5 lourd pending (backend tests, mint-routes, G6 ESTV + differential + property, PII log).
- Per 0-TRUST §9 : **A3 is NOT YET SHIPPED** (PR opened ≠ shipped — merge to dev required first).

**Execute-time decision tree:**
- **If A3 PR #643 merged to dev by W1-01 open time** → Task 0 Path A (verify import, no cherry-pick needed).
- **If A3 PR #643 still open or CI red** → Task 0 Path B (cherry-pick per D-CE-19 Parallel Change). Envelope contract is stable per panel CLEAN → migration risk is bounded ≤80 LOC.

D-CE-19 « Option B in progress » (W1 parallel with A3 ship) is the founder-endorsed track. W1 does NOT block on A3 merge ; Plan 01 Task 0 absorbs the dependency cleanly via Path A/B selection.
</a3_state>

<risks>
- **A3 merge dependency (degraded to LOW after panel CLEAN, 2026-05-16).** A3 PR #643 OPEN, panel 5/5 CLEAN, CI pending. Path B cherry-pick remains the safe default; Path A becomes the path of least resistance once A3 merges to dev. Either way, the envelope contract is stable and W1 proceeds without re-design risk. Surface a deferral to orchestrator only if cherry-pick is blocked by branch protection rules.
- **conftest.py fixture-name collision.** If a fixture named `client_with_blank_profile` already exists (unlikely, grep first), rename to `client_w1_blank_profile` and update VALIDATION.md task-ID acceptance text downstream.
- **Pydantic version pin.** `json_schema_extra` and `model_fields_set` runtime semantics require Pydantic v2.6+ (verified in MINT pyproject.toml). If a downgrade ships, this entire plan fails — flag as P0 blocker.
</risks>

<output>
After completion, create `.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-01-w1-shared-helpers-SUMMARY.md` per execute-plan template. Include:
- Engram obs_id from Task 4
- Commit shas
- Pytest pass/fail delta (Plan wave-1b-08 close-out baseline 6898 → new baseline)
- A3 merge state (Path A merged / Path B cherry-picked)
</output>
