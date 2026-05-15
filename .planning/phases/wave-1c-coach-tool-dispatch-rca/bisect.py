"""
Wave 1c context-layer bisection script (engram obs id 74).

Consumes a captured-from-staging Anthropic payload (from a single
WAVE1C_PAYLOAD log line) and replays it against the Anthropic API while
progressively dropping context layers. The first drop that restores
`stop_reason="tool_use"` names the culprit.

Drop order (cheapest-to-rebuild first):
  1. messages.conversation_history (drop everything except last user message)
  2. system.bundle_fragments (heuristic: strip blocks marked
     « # === bundle: <name> === » or similar markers)
  3. system.profile_context_inline (strip the « <profile_context> ... »
     XML-tagged block)
  4. system.rag_chunks (strip « <retrieval> ... » or « <faq> ... » blocks)
  5. system.legacy_doctrine (strip « Ne cite JAMAIS un chiffre que tu ne
     peux pas sourcer depuis le contexte fourni »)

If after all 5 drops the LLM STILL refuses, the culprit is in
get_narrator_llm_tools() schemas themselves (e.g. tool description text
that biases refusal). That would be a tools-side fix.

Inputs:
  - tools.json (already on disk)
  - <captured>.json — paste the WAVE1C_PAYLOAD JSON line into this file
    after `railway logs --service mint-staging | grep WAVE1C_PAYLOAD`

Outputs:
  - bisect_results.json — per-step result + named culprit

Run: railway run --service MINT --environment staging -- python3 \
       .planning/phases/wave-1c-coach-tool-dispatch-rca/bisect.py
"""
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path
from typing import Any

from anthropic import Anthropic

HERE = Path(__file__).resolve().parent
CAPTURED_PATH = HERE / "captured_staging_payload.json"
RESULTS_PATH = HERE / "bisect_results.json"

MODEL = "claude-sonnet-4-5-20250929"
MAX_TOKENS = 600

# Drop layers in order. Each layer is (label, transform-callable).
# transform takes the current `payload` dict and returns a new dict with the
# given layer stripped. The bisect harness calls each in sequence until
# the LLM emits tool_use OR all layers are exhausted.

_BUNDLE_BLOCK_RE = re.compile(
    r"#\s*===\s*bundle:\s*[\w_\-]+\s*===.*?(?=#\s*===|\Z)",
    re.DOTALL | re.IGNORECASE,
)
_PROFILE_CTX_RE = re.compile(
    r"<profile[_ ]context>.*?</profile[_ ]context>",
    re.DOTALL | re.IGNORECASE,
)
_RAG_RE = re.compile(
    r"<(retrieval|faq|grounding[_ ]pack|rag)>.*?</\1>",
    re.DOTALL | re.IGNORECASE,
)
_LEGACY_DOCTRINE_RE = re.compile(
    r"Ne cite JAMAIS un chiffre que tu ne peux pas sourcer[^.\n]*[.\n]",
)


def drop_history(p: dict) -> dict:
    p = {**p}
    msgs = p.get("messages", [])
    p["messages"] = msgs[-1:] if msgs else []
    return p


def drop_bundles(p: dict) -> dict:
    p = {**p}
    sys_str = p.get("system", "")
    p["system"] = _BUNDLE_BLOCK_RE.sub("", sys_str)
    return p


def drop_profile_ctx(p: dict) -> dict:
    p = {**p}
    sys_str = p.get("system", "")
    p["system"] = _PROFILE_CTX_RE.sub("", sys_str)
    return p


def drop_rag(p: dict) -> dict:
    p = {**p}
    sys_str = p.get("system", "")
    p["system"] = _RAG_RE.sub("", sys_str)
    return p


def drop_legacy_doctrine(p: dict) -> dict:
    p = {**p}
    sys_str = p.get("system", "")
    p["system"] = _LEGACY_DOCTRINE_RE.sub("", sys_str)
    return p


LAYERS = [
    ("drop_history", drop_history),
    ("drop_bundles", drop_bundles),
    ("drop_profile_ctx", drop_profile_ctx),
    ("drop_rag", drop_rag),
    ("drop_legacy_doctrine", drop_legacy_doctrine),
]


def call_anthropic(client: Anthropic, payload: dict) -> dict:
    resp = client.messages.create(
        model=MODEL,
        max_tokens=MAX_TOKENS,
        system=payload.get("system", ""),
        tools=payload.get("tools", []),
        tool_choice=payload.get("tool_choice", {"type": "auto"}),
        messages=payload.get("messages", []),
    )
    return {
        "stop_reason": resp.stop_reason,
        "input_tokens": resp.usage.input_tokens,
        "output_tokens": resp.usage.output_tokens,
        "block_types": [b.type for b in resp.content],
        "tool_use": [
            {"name": b.name, "input": b.input}
            for b in resp.content if b.type == "tool_use"
        ],
        "text_preview": next(
            (b.text[:300] for b in resp.content if b.type == "text"), None
        ),
    }


def main() -> int:
    if not CAPTURED_PATH.exists():
        print(
            f"ERROR: {CAPTURED_PATH} missing.\n"
            "Capture step:\n"
            "  1. railway variable set --service MINT --environment staging "
            "WAVE1C_INSTRUMENT_ENABLED=true\n"
            "  2. railway restart --service MINT --yes\n"
            "  3. (fire one /coach/chat probe with a budget/retirement question)\n"
            "  4. railway logs --service mint-staging | grep WAVE1C_PAYLOAD | "
            "tail -1 | sed -E 's/.*WAVE1C_PAYLOAD //' "
            f"> {CAPTURED_PATH}",
            file=sys.stderr,
        )
        return 2

    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        print("ERROR: ANTHROPIC_API_KEY missing. Run via `railway run`.", file=sys.stderr)
        return 2

    captured = json.loads(CAPTURED_PATH.read_text(encoding="utf-8"))
    print(f"# captured input_tokens estimate: {len(captured.get('system', '')) // 4 + sum(len(m.get('content', '')) for m in captured.get('messages', [])) // 4} (rough)")
    print(f"# captured tool_count: {len(captured.get('tools', []))}")
    print(f"# captured tool_choice: {captured.get('tool_choice')}")
    print(f"# captured messages count: {len(captured.get('messages', []))}")
    print()

    client = Anthropic(api_key=api_key)
    results: dict[str, Any] = {"baseline": None, "layers": []}

    print("========== BASELINE (full captured payload) ==========")
    baseline = call_anthropic(client, captured)
    results["baseline"] = baseline
    print(json.dumps(baseline, indent=2, ensure_ascii=False))
    if baseline["tool_use"]:
        print(
            "\nUNEXPECTED: baseline emits tool_use. Either the capture is from "
            "a different code path, or the bug is intermittent. Bisection skipped."
        )
        RESULTS_PATH.write_text(json.dumps(results, indent=2, ensure_ascii=False), encoding="utf-8")
        return 0

    current = dict(captured)
    culprit = None
    for label, transform in LAYERS:
        current = transform(current)
        print(f"\n========== AFTER {label} ==========")
        step = call_anthropic(client, current)
        step["label"] = label
        step["system_len"] = len(current.get("system", ""))
        step["messages_count"] = len(current.get("messages", []))
        results["layers"].append(step)
        print(json.dumps(step, indent=2, ensure_ascii=False))
        if step["tool_use"]:
            culprit = label
            print(f"\nVERDICT: {label} restored tool_use. Culprit = layer dropped by {label}.")
            break

    if not culprit:
        print(
            "\nVERDICT: tool_use never restored across all 5 drop layers. "
            "Suspect the get_narrator_llm_tools() tool description text itself "
            "(or another invariant of the request). Manual inspection needed."
        )

    results["culprit"] = culprit
    RESULTS_PATH.write_text(json.dumps(results, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"\nResults saved to {RESULTS_PATH}")
    return 0 if culprit else 1


if __name__ == "__main__":
    sys.exit(main())
