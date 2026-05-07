"""Phase 95 Plan 95-04 / TEST-05 — VCR Anthropic smoke test.

Replays a stub Anthropic Messages API response from a committed cassette
under ``services/backend/tests/cassettes/test_anthropic_vcr_smoke/``.
Closes TEST-05 smoke + doctrine 2026-05-06 §7 ship-gate item.

Run modes:
  VCR_RECORD_MODE=once → records new cassette (authoring path; needs
                        ANTHROPIC_API_KEY + STAGING_API_URL in env).
  VCR_RECORD_MODE=none → replay-only (CI default; this is what `pytest`
                        does without further configuration).
  VCR_RECORD_MODE=all  → nightly rewrite (gated by the DISABLED cron in
                        ``.github/workflows/vcr_nightly_rewrite.yml``).

The test deliberately uses ``urllib.request`` against api.anthropic.com
rather than the ``anthropic`` SDK or our own backend's
``/api/v1/anonymous/chat`` endpoint. VCR intercepts at the HTTP-stack
layer (urllib, httpx, requests) so the cassette is decoupled from any
particular Python client; this keeps the smoke test fast and lets the
fixture be exercised without standing up the FastAPI app.

The hand-authored initial cassette captures one redacted happy-path
response (single ``content[0].text`` block with a B1-readable lucidity
sentence in French, no banned terms, no PII). Future contributors who
add Anthropic-calling tests should re-record their cassettes against
staging-live per the recording protocol in
``services/backend/tests/cassettes/README.md``.
"""

from __future__ import annotations

import json
import os
import urllib.error
import urllib.request

import pytest


pytestmark = pytest.mark.vcr_anthropic


@pytest.mark.vcr
def test_anthropic_messages_replay_from_cassette(vcr_config):
    """Replay a committed Anthropic Messages cassette and assert shape.

    The committed cassette redacts every secret-bearing header to the
    literal ``REDACTED`` (per ``vcr_config.filter_headers``). The
    response body is a hand-authored happy-path Anthropic
    ``messages.create`` reply: 1 ``content`` block, ``stop_reason ==
    'end_turn'``, FR text without any banned term.

    Assertions are intentionally **shape-only** — promptfoo (TEST-01)
    grades response quality, Pact (TEST-02) grades schema. VCR's job
    here is to prove the wiring: cassette loads, body decodes, shape
    matches what our coach pipeline expects.
    """
    # vcr_config is consumed by pytest-recording via the fixture lookup;
    # passing the dict here ensures the test fails loud if the fixture
    # ever returns something unexpected.
    assert isinstance(vcr_config, dict)
    assert "filter_headers" in vcr_config
    assert ("authorization", "REDACTED") in vcr_config["filter_headers"]

    request = urllib.request.Request(
        url="https://api.anthropic.com/v1/messages",
        method="POST",
        data=json.dumps(
            {
                "model": "claude-sonnet-4-5",
                "max_tokens": 256,
                "system": "Tu es MINT, l'assistant de lucidité financière suisse.",
                "messages": [
                    {"role": "user", "content": "Bonjour"},
                ],
            }
        ).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "Anthropic-Version": "2023-06-01",
            # Replay mode never reads this; record mode would read from
            # env. Either way VCR redacts it before writing the cassette.
            "X-Api-Key": os.environ.get("ANTHROPIC_API_KEY", "REDACTED"),
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=10) as resp:
            payload = json.loads(resp.read().decode("utf-8"))
            status = resp.status
    except urllib.error.HTTPError as exc:
        # Cassette could legitimately encode a 4xx if the staging-live
        # recording captured one — surface the body so the failure is
        # actionable (no bare except per CLAUDE.md).
        body = exc.read().decode("utf-8", errors="replace") if exc.fp else ""
        raise AssertionError(
            f"Anthropic replay returned HTTP {exc.code}: {body[:400]}"
        ) from exc

    # Shape assertions — Anthropic Messages API canonical envelope.
    assert status == 200
    assert payload["type"] == "message"
    assert payload["role"] == "assistant"
    assert payload["model"].startswith("claude-")
    assert isinstance(payload["content"], list)
    assert len(payload["content"]) >= 1

    first_block = payload["content"][0]
    assert first_block["type"] == "text"
    text = first_block["text"]
    assert isinstance(text, str)
    assert len(text) > 0

    # Soft compliance smoke (the authoritative gate is the hygiene
    # lint at tools/checks/cassette_hygiene_lint.py — this is local
    # belt-and-suspenders so a regression in the lint is caught at
    # pytest time too).
    lower = text.lower()
    for banned in ("garanti", "optimal", "sicher", "best", "migliore"):
        assert banned not in lower, (
            f"Cassette response leaked banned term {banned!r}; "
            "re-record + re-scrub before committing."
        )

    assert payload["stop_reason"] in {"end_turn", "max_tokens", "stop_sequence"}
