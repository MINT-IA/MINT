"""Sentry `before_send` PII scrubber for the MINT FastAPI backend.

Swiss-compliance panel non-negotiable for nLPD + LSFin. Mirrors the
mobile-side `MintSentryScrub` so a Sentry event from either client or
server carries the same redaction contract.

What it does:
    - Strips known Swiss PII shapes (AVS, IBAN_CH, email, phone +41,
      generic EU IBAN) from event message + extra + breadcrumb data.
    - Drops the entire VALUE of any key whose name matches a Claude /
      free-text payload pattern (prompt, completion, messages, response,
      coach_*, claude_*, user_message, user_input, free_text,
      chat_history).
    - Drops `request.data` wholesale because we cannot guarantee the
      backend doesn't accept user-supplied financial values inline.

What it does NOT touch:
    - Stack frames (file paths, function names are non-PII per Sentry).
    - SDK-populated metadata (release, env, timestamps).
    - Sentry tags surfaced for triage (`mint_request_id`, env labels).

Contract tests live in
`services/backend/tests/test_sentry_scrub.py`.
"""

from __future__ import annotations

import re
from typing import Any, Mapping

REDACTED = "<<REDACTED>>"

# Anchored key pattern — exact match only. `is_prompt_eligible` and
# similar substrings must NOT trigger the drop.
#
# Negative-lookahead on `claude_request_id` / `claude_model` /
# `claude_token_usage` — non-PII triage identifiers needed to correlate
# a Sentry crash with Anthropic's server-side log (`msg_01ABCDEF`).
# Per code-review feedback I3 the prior wildcard `claude_.*` was over-greedy.
_FORBIDDEN_KEY_RE = re.compile(
    r"^("
    r"prompt|completion|messages|response|coach_text|coach_response|"
    r"claude_(?!request_id$|model$|token_usage$).*"
    r"|user_message|user_input|free_text|chat_history|"
    # Phase mint-data-architecture-v1-02 Plan 02-02 W1 — strip Phase 02
    # encryption envelopes from any breadcrumb / extra / event payload.
    # value_enc rows are the D-26 JSONB ciphertexts; _dek_cache is the
    # KeyVaultService plaintext-DEK cache (iter-2 A5 Sentry redaction).
    r"value_enc|_dek_cache"
    r")$",
    re.IGNORECASE,
)

# Separator classes include dot, space, dash, NBSP. Per code-review C1+C2,
# the original « dot only » AVS pattern and « space only » IBAN pattern
# missed realistic real-world inputs (Postfinance UI emits dashed IBAN ;
# PDFs paste with NBSP). Aligns with the prior-art recognizer at
# `services/backend/app/services/privacy/recognizers_ch.py:101`.
_PII_PATTERNS: list[re.Pattern[str]] = [
    # Swiss AVS-13 (canonical with separators + no-separator variant).
    re.compile(r"\b756[.\s\-\xa0]?\d{4}[.\s\-\xa0]?\d{4}[.\s\-\xa0]?\d{2}\b"),
    re.compile(r"\b756\d{10}\b"),
    # Swiss IBAN (CH + 2 check + 4×4 + 1). Accepts space, dash, NBSP.
    re.compile(r"\bCH\d{2}[\s\-\xa0]?(?:\d{4}[\s\-\xa0]?){4}\d{1}\b"),
    # Generic IBAN narrowed to MINT's 6-locale plus close-neighbour set
    # (per code-review M2 — avoid false-positive on stack-frame hex blobs).
    re.compile(
        r"\b(?:FR|DE|IT|ES|PT|BE|NL|LU|AT|LI)\d{2}[\s\-\xa0]?"
        r"[A-Z0-9]{11,30}\b"
    ),
    re.compile(r"[\w.+-]+@[\w-]+\.[\w.-]+"),              # email
    re.compile(r"(\+41|0041|0)\s?[1-9]\d(?:[\s.\-]?\d{2,3}){3}"),  # phone
]


def _scrub_string(s: str) -> str:
    out = s
    for p in _PII_PATTERNS:
        out = p.sub(REDACTED, out)
    return out


def _scrub_any(value: Any) -> Any:
    if isinstance(value, str):
        return _scrub_string(value)
    if isinstance(value, Mapping):
        return _scrub_mapping(value)
    if isinstance(value, list):
        return [_scrub_any(v) for v in value]
    return value


def _scrub_mapping(m: Mapping[str, Any]) -> dict[str, Any]:
    out: dict[str, Any] = {}
    for key, value in m.items():
        if isinstance(key, str) and _FORBIDDEN_KEY_RE.match(key):
            out[key] = REDACTED
            continue
        out[key] = _scrub_any(value)
    return out


def _scrub_breadcrumb(b: dict[str, Any]) -> dict[str, Any]:
    out = dict(b)
    if isinstance(out.get("message"), str):
        out["message"] = _scrub_string(out["message"])
    if isinstance(out.get("data"), Mapping):
        out["data"] = _scrub_mapping(out["data"])
    return out


def before_send(event: dict[str, Any], hint: dict[str, Any]) -> dict[str, Any] | None:
    """Sentry `before_send` hook.

    Returns the (mutated) event to forward to Sentry, or `None` to drop
    the event entirely (we never currently drop — the panel asked for
    scrub, not block).
    """
    # 1. Scrub extras (anchored key pattern + nested PII).
    if isinstance(event.get("extra"), Mapping):
        event["extra"] = _scrub_mapping(event["extra"])

    # 2. Scrub breadcrumbs.
    crumbs = event.get("breadcrumbs")
    if isinstance(crumbs, Mapping) and isinstance(crumbs.get("values"), list):
        crumbs["values"] = [_scrub_breadcrumb(c) for c in crumbs["values"]]
    elif isinstance(crumbs, list):
        # Older SDK shape — just a list of breadcrumbs.
        event["breadcrumbs"] = [_scrub_breadcrumb(c) for c in crumbs]

    # 3. Scrub message strings.
    msg = event.get("message")
    if isinstance(msg, str):
        event["message"] = _scrub_string(msg)
    elif isinstance(msg, Mapping) and isinstance(msg.get("formatted"), str):
        # SentryMessage shape on the wire.
        msg["formatted"] = _scrub_string(msg["formatted"])

    # 4. Drop request body / headers / cookies wholesale — we cannot
    # trust user-supplied financial values inline. Keep URL + method
    # for triage.
    req = event.get("request")
    if isinstance(req, Mapping):
        event["request"] = {
            "url": req.get("url"),
            "method": req.get("method"),
            # data, headers, cookies, query_string deliberately dropped
        }

    # 5. Scrub exception value strings AND stack-frame local variables.
    # `sentry-sdk[fastapi]` defaults to include_local_variables=True;
    # a function with a local `iban = "CH93..."` would ship the raw
    # value to Sentry without this pass. File path + function name on
    # frames are non-PII (per Sentry's own classification) and are
    # left untouched.
    exc = event.get("exception")
    if isinstance(exc, Mapping) and isinstance(exc.get("values"), list):
        for v in exc["values"]:
            if isinstance(v.get("value"), str):
                v["value"] = _scrub_string(v["value"])
            # Per code-review I5 — scrub `frames[*].vars` deeply.
            stacktrace = v.get("stacktrace")
            if isinstance(stacktrace, Mapping) and isinstance(
                stacktrace.get("frames"), list
            ):
                for frame in stacktrace["frames"]:
                    if isinstance(frame, Mapping):
                        local_vars = frame.get("vars")
                        if isinstance(local_vars, Mapping):
                            frame["vars"] = _scrub_mapping(local_vars)

    # 6. Scrub tag VALUES (defence-in-depth — tags are typically system
    # identifiers but a future contributor adding `set_tag('user_input',
    # x)` would bypass the rest of the scrubber). Per code-review M6.
    # Keys are not redacted (tag-name lookup must stay stable for
    # Sentry's UI). Values pass through the PII regex set.
    tags = event.get("tags")
    if isinstance(tags, Mapping):
        event["tags"] = {
            k: (_scrub_string(v) if isinstance(v, str) else v)
            for k, v in tags.items()
        }

    return event
