"""
Wave 1c distinguishing experiment per 3-agent RCA consensus (engram obs id 73).

Replay probe v7 (Wave 1b G2 Run #2) directly against Anthropic API twice with
identical model + system prompt + tools + message, only `tool_choice` differs.

Reads tools from `tools.json` (dumped from `get_narrator_llm_tools()` to avoid
pulling psycopg2 + the full MINT backend into the runtime). Uses
ANTHROPIC_API_KEY from environment (inject via `railway run`).

Decision rule:
- Variant `tool_choice={"type":"any"}` returns `stop_reason="tool_use"` with
  >=1 tool_use content block -> fix is single-line at llm_client.py:227 +
  bundle prompt mandates (small wave-1c PR).
- Variant still `stop_reason="end_turn"` with text-only response -> doctrine
  rewrite needed (kill refusal escape hatch + wire forced-tool-invocation
  gate per memory project_coach_forced_tool_invocation).

Run: railway run --service MINT --environment staging -- python3 \
       .planning/phases/wave-1c-coach-tool-dispatch-rca/experiment.py
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

from anthropic import Anthropic

HERE = Path(__file__).resolve().parent
TOOLS_PATH = HERE / "tools.json"
OUT_PATH = HERE / "experiment_results.json"

USER_MESSAGE = (
    "Quelle sera ma rente AVS et LPP à 65 ans avec mon 3eme pilier actuel ? "
    "Donne-moi la projection chiffrée."
)

# Mirrors the staging "no MANDATE" condition: tools advertised, role + LSFin
# disclaimer + refusal-escape-hatch wording present, no «invoque OBLIGATOIREMENT»
# language. This approximates what staging actually sends in the legacy
# narrator path (when COACH_BUNDLE_COMPILER_ENABLED=False on staging, which
# per services/backend/app/core/config.py:71,80 is the default).
SYSTEM_PROMPT = (
    "Tu es Mint, un coach financier suisse. Tu accompagnes l'utilisateur sur "
    "ses décisions financières en français. Tu disposes d'outils pour récupérer "
    "les données du profil de l'utilisateur (get_budget_status, "
    "get_retirement_projection, get_cross_pillar_analysis, "
    "get_couple_optimization, get_cap_status, retrieve_memories). "
    "Respecte la LSFin : information générale uniquement, pas de conseil "
    "personnalisé garanti. En l'absence de donnée fiable, écris « Je n'ai pas "
    "cette donnée pour l'instant » plutôt que d'inventer un chiffre."
)

MODEL = "claude-sonnet-4-5-20250929"
MAX_TOKENS = 600

if not TOOLS_PATH.exists():
    sys.exit(
        f"tools.json missing at {TOOLS_PATH}. Run the tools dump first:\n"
        "  PYTHONPATH=services/backend python3 -c "
        "'import json; from app.services.coach.coach_tools import "
        "get_narrator_llm_tools; "
        f"json.dump(get_narrator_llm_tools(), open(\"{TOOLS_PATH}\", \"w\"), indent=2)'"
    )

tools = json.loads(TOOLS_PATH.read_text(encoding="utf-8"))
print(f"# tools advertised ({len(tools)}): {[t['name'] for t in tools]}\n")

api_key = os.environ.get("ANTHROPIC_API_KEY")
if not api_key:
    sys.exit("ANTHROPIC_API_KEY missing. Run via `railway run --service MINT --environment staging --`.")

client = Anthropic(api_key=api_key)
results = {}

for tag, choice in [("baseline_auto", {"type": "auto"}), ("variant_any", {"type": "any"})]:
    print(f"\n========== tool_choice = {choice} ({tag}) ==========")
    resp = client.messages.create(
        model=MODEL,
        max_tokens=MAX_TOKENS,
        system=SYSTEM_PROMPT,
        tools=tools,
        tool_choice=choice,
        messages=[{"role": "user", "content": USER_MESSAGE}],
    )
    summary = {
        "stop_reason": resp.stop_reason,
        "model": resp.model,
        "input_tokens": resp.usage.input_tokens,
        "output_tokens": resp.usage.output_tokens,
        "block_count": len(resp.content),
        "block_types": [b.type for b in resp.content],
        "tool_use_blocks": [
            {"name": b.name, "input": b.input}
            for b in resp.content if b.type == "tool_use"
        ],
        "text_preview": next(
            (b.text[:400] for b in resp.content if b.type == "text"), None
        ),
    }
    results[tag] = summary
    print(f"stop_reason: {summary['stop_reason']}")
    print(f"block_types: {summary['block_types']}")
    print(f"input/output tokens: {summary['input_tokens']}/{summary['output_tokens']}")
    print(f"tool_use_blocks: {len(summary['tool_use_blocks'])}")
    for b in summary["tool_use_blocks"]:
        print(f"  TOOL_USE: {b['name']}({json.dumps(b['input'])[:200]})")
    if summary["text_preview"]:
        print(f"text: {summary['text_preview']}")

print("\n========== VERDICT ==========")
baseline_tool_used = len(results["baseline_auto"]["tool_use_blocks"]) > 0
variant_tool_used = len(results["variant_any"]["tool_use_blocks"]) > 0
print(f"baseline_auto emitted tool_use: {baseline_tool_used}")
print(f"variant_any  emitted tool_use: {variant_tool_used}")

if not baseline_tool_used and variant_tool_used:
    print(
        "\nVERDICT: hypothesis CONFIRMED. tool_choice=auto suppresses tool_use; "
        "tool_choice=any forces it. Wave 1c fix path = small PR "
        "(llm_client.py:227 routing + bundle prompt mandates)."
    )
elif not baseline_tool_used and not variant_tool_used:
    print(
        "\nVERDICT: hypothesis FALSIFIED. Even tool_choice=any does NOT emit "
        "tool_use. Doctrine rewrite needed (refusal escape hatch wins). "
        "Wave 1c fix path = larger PR (kill refusal hatch + wire forced-tool gate)."
    )
elif baseline_tool_used:
    print(
        "\nVERDICT: hypothesis CONTRADICTED locally. tool_choice=auto DID "
        "emit tool_use here. Staging-specific suppression — likely bundle "
        "prompt fragment or system prompt difference. Need to fetch the "
        "exact staging-side system prompt + RAG context and re-test."
    )

OUT_PATH.write_text(json.dumps(results, indent=2, ensure_ascii=False), encoding="utf-8")
print(f"\nResults saved to {OUT_PATH}")
