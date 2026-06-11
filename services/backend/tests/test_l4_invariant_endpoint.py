"""Phase mint-calc-engine-v1 Plan 04 — L4 wedge endpoint contract tests.

Finding 5 of CONTEXT.md : L4 invariants ship FIRST in W1 as the wedge for
L2/L3 (which carry higher LSFin risk). The « 33% plafond de charge » mortgage-cap
invariant is pure information générale + legal article reference (Directives ASB,
FINMA) — lowest LSFin-risk surface, highest user-value surface.

Tests :
  1. GET returns 200 with L4InvariantPayload-shaped JSON (camelCase aliasing).
  2. Response body validates against `L4InvariantPayload.model_validate(...)`
     (schema round-trip proof).
  3. `conditionTextFr` contains no banned LSFin term (manual grep guard).
  4. Auth required : authenticated client returns 200.
  5. Spoofing guard : anonymous client returns 401.
"""
from __future__ import annotations

from fastapi.testclient import TestClient

from app.core.auth import get_current_user, require_current_user
from app.main import app
from app.models.lucidity import L4InvariantPayload


L4_MORTGAGE_CAP_URL = "/api/v1/lucidity/invariants/mortgage-cap"


# ---------------------------------------------------------------------------
# Test 1 — happy path returns 200 + L4 envelope
# ---------------------------------------------------------------------------


def test_l4_mortgage_cap_returns_200_with_l4_envelope(client: TestClient) -> None:
    """Authenticated GET returns the L4 wedge envelope.

    Pydantic v2 serialisation : `level` (Literal["L4"]) renders as the
    `LucidityLevel.L4` enum value « L4 ». Field names render as-is
    (this endpoint does NOT inherit the coach_tools alias_generator,
    so JSON keys are snake_case from the FastAPI default).
    """
    resp = client.get(L4_MORTGAGE_CAP_URL)
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["level"] == "L4"
    assert body["legal_article_ref"] == "Directives ASB (FINMA)"
    assert "33%" in body["condition_text_fr"]
    assert "ASB" in body["condition_text_fr"]
    # The 33% mortgage-charge cap does NOT derive from the LCC (which excludes
    # mortgage credit, LCC art. 7) — guard against the prior false citation.
    assert "LCC" not in body["condition_text_fr"]


# ---------------------------------------------------------------------------
# Test 2 — response body validates against L4InvariantPayload (schema round-trip)
# ---------------------------------------------------------------------------


def test_l4_mortgage_cap_body_validates_against_l4_payload(client: TestClient) -> None:
    """The endpoint's JSON body parses cleanly via L4InvariantPayload.

    Round-trip proves the FastAPI `response_model=L4InvariantPayload` wiring
    serialises exactly what the Pydantic model accepts back.
    """
    resp = client.get(L4_MORTGAGE_CAP_URL)
    assert resp.status_code == 200
    payload = L4InvariantPayload.model_validate(resp.json())
    assert payload.level.value == "L4"
    assert payload.legal_article_ref == "Directives ASB (FINMA)"
    assert len(payload.condition_text_fr) >= 20  # min_length floor


# ---------------------------------------------------------------------------
# Test 3 — conditionTextFr does NOT contain any LSFin banned term
# ---------------------------------------------------------------------------


def test_l4_mortgage_cap_condition_text_is_lsfin_clean(client: TestClient) -> None:
    """The hard-coded FR text MUST be free of LSFin banned verbs.

    The lint `tools/checks/banned_terms_python.py` is the source of truth
    on the banned-root list — this test imports the canonical tuples at
    runtime (no verbatim re-listing in source — which would itself trip
    the lint on this test file). Defense-in-depth : even if a future
    source-file docstring exempts a banned term via the lint marker, the
    actual response payload cannot contain one.
    """
    resp = client.get(L4_MORTGAGE_CAP_URL)
    assert resp.status_code == 200
    condition_text = resp.json()["condition_text_fr"].lower()

    # Load canonical banned-root + banned-phrase tuples from the lint
    # script. Avoids verbatim quoting of banned roots in this test file
    # (which would itself trip banned_terms_python.py on this file).
    import importlib.util
    import re
    from pathlib import Path

    lint_path = (
        Path(__file__).resolve().parents[3]
        / "tools" / "checks" / "banned_terms_python.py"
    )
    spec = importlib.util.spec_from_file_location("_banned_lint", lint_path)
    assert spec is not None and spec.loader is not None
    lint_mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(lint_mod)

    for root in lint_mod._WORD_BOUNDARY_BANNED:
        assert not re.search(r"\b" + re.escape(root) + r"\b", condition_text), (
            f"L4 condition_text_fr contains banned root {root!r} : "
            f"{condition_text!r}"
        )
    for phrase in lint_mod._PHRASE_BANNED:
        assert phrase not in condition_text, (
            f"L4 condition_text_fr contains banned phrase {phrase!r} : "
            f"{condition_text!r}"
        )


# ---------------------------------------------------------------------------
# Test 4 — authenticated client returns 200 (happy path auth proof)
# ---------------------------------------------------------------------------


def test_l4_mortgage_cap_authenticated_returns_200(client: TestClient) -> None:
    """The `client` fixture overrides `require_current_user` with `_fake_user`.

    Explicit assertion that the auth-overridden client gets 200 — the
    counterpart to Test 5's anonymous 401 guard. Together they prove
    auth is required and enforced.
    """
    resp = client.get(L4_MORTGAGE_CAP_URL)
    assert resp.status_code == 200, (
        f"Authenticated client should reach endpoint ; got {resp.status_code}: "
        f"{resp.text}"
    )


# ---------------------------------------------------------------------------
# Test 5 — anonymous client returns 401 (Spoofing guard, threat T-04-04)
# ---------------------------------------------------------------------------


def test_l4_mortgage_cap_anonymous_returns_401() -> None:
    """No auth → 401. Threat T-mint-calc-04-04 (Spoofing) mitigated.

    Bypasses the conftest `client` fixture (which overrides `require_current_user`
    with `_fake_user`) by constructing a fresh TestClient with the auth
    overrides explicitly cleared. The endpoint's `Depends(require_current_user)`
    raises 401 when no JWT is supplied.
    """
    # Clear auth overrides on the shared `app` so this test's TestClient sees
    # the real `require_current_user` dependency.
    app.dependency_overrides.pop(require_current_user, None)
    app.dependency_overrides.pop(get_current_user, None)
    try:
        with TestClient(app) as anon_client:
            resp = anon_client.get(L4_MORTGAGE_CAP_URL)
        assert resp.status_code == 401, (
            f"Expected 401 for anonymous GET ; got {resp.status_code}: "
            f"{resp.text}"
        )
    finally:
        # Restore the conftest overrides for any subsequent tests in this
        # module (defensive — the autouse `clean_database` fixture also
        # rebinds, but explicit is better).
        from tests.conftest import _fake_user  # noqa: WPS433  (test helper)
        app.dependency_overrides[require_current_user] = _fake_user
        app.dependency_overrides[get_current_user] = _fake_user
