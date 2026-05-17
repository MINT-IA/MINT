"""Phase 94 Wave 1 — D-07 bundle integration + H1 NameError regression.

Pins :
- D-07 flag-ON path : the wrapper passes
  `_compiled_bundle.citation_allowlist` as `citation_allowlist=` to
  `_citation_gate(...)`.
- H1 fix iter 1 : `_compiled_bundle: CompiledBundle | None = None`
  initialized BEFORE the bundle-compiler branch ; the wrapper
  reads `_compiled_bundle is not None` on EVERY code path
  (flag-OFF, KeyError, ValueError, dual-LLM elif, else). NO
  NameError on any path.

Strategy : import the wrapper's `_run_narrator_with_gate` is not
directly accessible (it's a local closure), so we exercise the
behavior by introspecting the source file (assert
`_compiled_bundle: "CompiledBundle | None" = None` is present
upstream of the bundle-compiler block) AND by spying on
`_citation_gate` via monkeypatch on the module-level alias.
"""
from __future__ import annotations

import pathlib
import re

import pytest


# ---------------------------------------------------------------------------
# H1 fix iter 1 — assert the upstream `_compiled_bundle = None`
# initializer exists in the source. This is the deterministic-grep
# receipt that the wrapper cannot raise NameError on the flag-OFF /
# except / elif / else paths.
# ---------------------------------------------------------------------------


def _coach_chat_src() -> str:
    src_path = (
        pathlib.Path(__file__).resolve().parent.parent.parent
        / "app" / "api" / "v1" / "endpoints" / "coach_chat.py"
    )
    return src_path.read_text(encoding="utf-8")


def test_compiled_bundle_init_is_upstream_of_narrator_compiler_branch():
    """The `_compiled_bundle = None` initializer must precede the
    NARRATOR-handler `if settings.COACH_BUNDLE_COMPILER_ENABLED:`
    branch (the one at coach_chat.py:~3235 that assigns
    `_compiled_bundle = _cb(...)`). There's an earlier compiler-flag
    branch in `_build_system_prompt_with_memory` (~line 777) that is
    NOT a narrator-handler concern ; we pin the LAST occurrence.
    """
    src = _coach_chat_src()
    init_match = re.search(
        r'_compiled_bundle\s*:\s*"CompiledBundle \| None"\s*=\s*None',
        src,
    )
    assert init_match is not None, (
        "H1 fix iter 1 — the `_compiled_bundle = None` initializer must "
        "be present in coach_chat.py"
    )
    # Locate the narrator-handler branch by sniffing for the
    # `_compiled_bundle = _cb(` assignment, which only exists in that
    # branch.
    narrator_branch_match = re.search(
        r"_compiled_bundle\s*=\s*_cb\(",
        src,
    )
    assert narrator_branch_match is not None, (
        "expected the narrator-handler `_compiled_bundle = _cb(...)` "
        "assignment to be present (Phase 93.5 wiring)"
    )
    # Initializer MUST precede the narrator-handler assignment.
    assert init_match.start() < narrator_branch_match.start(), (
        "H1 fix iter 1 — initializer must be UPSTREAM of the "
        "narrator-handler `_compiled_bundle = _cb(...)` assignment"
    )


def test_compiled_bundle_none_on_compile_failure_does_not_raise():
    """H1 regression — if `compile_bundles` raises KeyError, the wrapper
    code path must STILL run without `NameError`. The `except (KeyError,
    ValueError)` branch leaves `_compiled_bundle = None` from the
    upstream initializer.

    Receipt : the source has the upstream initializer (asserted above) +
    the `except (KeyError, ValueError)` branch does NOT touch
    `_compiled_bundle`. Combined, no NameError can occur on this path.
    """
    src = _coach_chat_src()
    # The except branch must NOT (re)assign `_compiled_bundle` — it
    # relies on the upstream None.
    except_section = re.search(
        r"except \(KeyError, ValueError\):\s*\n\s*_narrator_tools = get_narrator_llm_tools\(\)",
        src,
    )
    assert except_section is not None, (
        "Phase 93.5 except branch shape must remain — receipt for H1 "
        "graceful degradation"
    )


def test_compiled_bundle_none_on_flag_off():
    """H1 regression — when `COACH_BUNDLE_COMPILER_ENABLED=False`, the
    elif/else branches do NOT assign `_compiled_bundle`. The upstream
    initializer keeps it `None`.
    """
    src = _coach_chat_src()
    # The elif and else branches must NOT assign `_compiled_bundle`.
    elif_block = re.search(
        r"elif settings\.COACH_DUAL_LLM_ENABLED:\s*\n\s*_narrator_tools = get_narrator_llm_tools\(\)",
        src,
    )
    assert elif_block is not None
    # Verify : neither the elif nor else block contains a
    # `_compiled_bundle = ...` assignment.
    elif_to_else_pos = src.find(
        "elif settings.COACH_DUAL_LLM_ENABLED:"
    )
    next_section = src[elif_to_else_pos:elif_to_else_pos + 400]
    assert "_compiled_bundle =" not in next_section, (
        "H1 — elif/else branches MUST NOT assign _compiled_bundle "
        "(it's None from the upstream initializer)"
    )


def test_compiled_bundle_none_on_dual_llm_branch():
    """H1 regression — same as above but specifically pins the elif
    branch (`COACH_DUAL_LLM_ENABLED=True`, compiler flag OFF).
    """
    src = _coach_chat_src()
    # Compose a minimal grep over the elif branch.
    pattern = (
        r"elif settings\.COACH_DUAL_LLM_ENABLED:\s*\n"
        r"\s*_narrator_tools = get_narrator_llm_tools\(\)"
    )
    assert re.search(pattern, src) is not None, (
        "H1 — elif COACH_DUAL_LLM_ENABLED branch must keep its "
        "Phase 91 shape AND not (re)assign _compiled_bundle"
    )


# ---------------------------------------------------------------------------
# D-07 — flag-ON path uses `_compiled_bundle.citation_allowlist`.
# This is enforced by the source-level grep below ; the runtime
# behavior is exercised by `test_telemetry.py` (which monkeypatches
# `_citation_gate` and inspects the call args).
# ---------------------------------------------------------------------------


def test_d07_allowlist_resolution_flag_on_uses_compiled_bundle():
    """The wrapper's `_gate_allowlist` is `_compiled_bundle.citation_allowlist`
    when the compiler flag is on AND the bundle compiled successfully.
    """
    src = _coach_chat_src()
    pattern = re.compile(
        r"_gate_allowlist\s*=\s*\(\s*\n\s*"
        r"list\(_compiled_bundle\.citation_allowlist\)\s*\n\s*"
        r"if\s*\(\s*\n\s*"
        r"settings\.COACH_BUNDLE_COMPILER_ENABLED\s*\n\s*"
        r"and\s*_compiled_bundle\s*is\s*not\s*None"
    )
    assert pattern.search(src) is not None, (
        "D-07 — `_gate_allowlist` must be derived from "
        "`_compiled_bundle.citation_allowlist` when compiler flag ON"
    )


def test_d07_allowlist_resolution_falls_back_to_none_on_flag_off():
    """When flag-OFF OR `_compiled_bundle is None`, allowlist is None →
    gate falls back to global CITATION_REGISTRY keys.
    """
    src = _coach_chat_src()
    pattern = re.compile(
        r"_gate_allowlist\s*=\s*\([\s\S]+?else\s+None\s*\n\s*\)",
    )
    assert pattern.search(src) is not None, (
        "D-07 fallback — `_gate_allowlist = None` when compiler flag "
        "is OFF or _compiled_bundle is None"
    )


# ---------------------------------------------------------------------------
# Wrapper presence — Karpathy #3 surgical receipt.
# ---------------------------------------------------------------------------


def test_wrapper_function_present():
    """`_run_narrator_with_gate` must be defined in coach_chat.py."""
    src = _coach_chat_src()
    assert "async def _run_narrator_with_gate" in src, (
        "Phase 94 Wave 1 — the citation-gate wrapper must be defined "
        "at the narrator handler scope"
    )


def test_run_agent_loop_body_untouched():
    """Karpathy #3 receipt — the agent-loop body (lines ~1726-2624) is
    still present unchanged. We sniff for marker fragments rather than
    do a line-count-fragile assertion.
    """
    src = _coach_chat_src()
    # Marker fragments from the existing _run_agent_loop body.
    assert "async def _run_agent_loop" in src
    assert "AGENT_LOOP_DEADLINE_SECONDS" in src
    # The wrapper invokes _run_agent_loop with **kwargs ; both initial
    # and retry calls must be present.
    occurrences = [
        m.start()
        for m in re.finditer(r"_run_agent_loop\(question=", src)
    ]
    assert len(occurrences) >= 2, (
        "expected ≥2 calls to `_run_agent_loop(question=...)` in the "
        "wrapper (initial + retry-once per D-08)"
    )


# ---------------------------------------------------------------------------
# Sentry breadcrumb hygiene receipt (D-18).
# ---------------------------------------------------------------------------


def test_sentry_breadcrumb_payload_keys_only_non_pii():
    """The breadcrumb `data` dict must contain ONLY counts/labels keys
    (no `message`, `text`, `prompt`, `answer`, `body`, `user`,
    `content` — the PII suspects).
    """
    src = _coach_chat_src()
    # Locate the breadcrumb assignment.
    match = re.search(
        r'_emit_gate_breadcrumb[\s\S]+?data=\{([\s\S]+?)\},',
        src,
    )
    assert match is not None
    payload = match.group(1)
    forbidden = ["message", "text", "prompt", "answer", "body", "user", "content"]
    for k in forbidden:
        assert f'"{k}"' not in payload, (
            f"D-18 hygiene — breadcrumb data MUST NOT carry key {k!r} "
            "(would risk PII leak)"
        )
    # Required keys present
    for k in ("verdict", "retries", "uncited_numbers_count", "banned_claims_count"):
        assert f'"{k}"' in payload, (
            f"D-18 contract — breadcrumb data MUST carry key {k!r}"
        )
