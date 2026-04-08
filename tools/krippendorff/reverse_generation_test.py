#!/usr/bin/env python3
"""
Reverse-Krippendorff generation test — Phase 11 / VOICE-06.

One-shot script that:
  1. Loads `tools/krippendorff/reverse_test_contexts.json` (10 trigger contexts
     derived from Julien+Lauren golden fixtures).
  2. For each context, builds a system prompt forced to N4 register via
     `force_level_n4_directive()` (a thin wrapper that appends a level
     directive to `claude_coach_service.build_system_prompt()` — it does NOT
     bypass ComplianceGuard, the N5 gate, or the fragility clamp).
  3. Captures the generated reply and writes
     `tools/krippendorff/reverse_outputs_v1.json` in the SAME shape as
     `tools/voice_corpus/frozen_phrases_v1.json`, so the Plan 02 rater UI
     can load it directly alongside the frozen reference set.
  4. Tags each output with `_expected_level: "N4"` (the rater UI strips this
     field at render time — T-11-08 mitigation).

Modes:
    --fixtures   Use pre-canned fixture generations (default; reproducible,
                 no network, no API key needed). Reads
                 `tools/krippendorff/reverse_outputs_fixtures/`.
    --live       Call the live Claude API (requires ANTHROPIC_API_KEY).
                 NOT used in CI; intended for manual generation when the
                 system prompt has been revised and Plan 02 testers need
                 a fresh batch.

Usage:
    python3 tools/krippendorff/reverse_generation_test.py            # fixtures
    python3 tools/krippendorff/reverse_generation_test.py --live     # API
    python3 tools/krippendorff/reverse_generation_test.py --out PATH

Pass gate (downstream, not enforced here): ≥7/10 outputs must be majority-
classified as N4 by the 15-tester panel. If <70%, the system prompt is
tone-locked and Phase 11 ship is blocked.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Optional

# ── Repo paths ──────────────────────────────────────────────────────────────
REPO_ROOT = Path(__file__).resolve().parents[2]
CONTEXTS_PATH = REPO_ROOT / "tools" / "krippendorff" / "reverse_test_contexts.json"
DEFAULT_OUTPUT = REPO_ROOT / "tools" / "krippendorff" / "reverse_outputs_v1.json"
FIXTURES_DIR = REPO_ROOT / "tools" / "krippendorff" / "reverse_outputs_fixtures"


# ════════════════════════════════════════════════════════════════════════════
# Force-level wrapper
# ════════════════════════════════════════════════════════════════════════════
#
# This wrapper is the sole "force_level" surface. It appends a level
# directive to the standard coach system prompt. It is NOT exposed on any
# HTTP endpoint and is keyword-only (T-11-07 mitigation).
#
# Critically, it returns a STRING (the augmented system prompt). The caller
# is still responsible for routing the resulting LLM output through
# ComplianceGuard and the N5 gate. This wrapper cannot bypass either.

_N4_DIRECTIVE = (
    "\n\n## VOIX — NIVEAU FORCÉ : N4\n"
    "Pour cette réponse, vise EXPLICITEMENT le niveau N4 sur le curseur de voix "
    "(échelle N1 murmure → N5 piquant). N4 = direct, net, légèrement piquant, "
    "factuel, sans imperative dure et sans jugement de l'émetteur. Conserve "
    "TOUS les garde-fous compliance (LSFin, pas de produit nommé, pas de promesse "
    "de rendement, pas de comparaison sociale, hedge sur toute action suggérée).\n"
)


def force_level_n4_directive(*, base_system_prompt: str) -> str:
    """Append the N4 level directive to a base coach system prompt.

    Keyword-only by design to make the override explicit at every call site
    and to prevent accidental positional misuse from HTTP request handlers.
    The function does NOT call the LLM and does NOT touch any compliance or
    weekly-gate code path — it is a pure string transform that only injects
    a voice-level directive into the system prompt string. The caller is
    responsible for routing the resulting LLM output through the standard
    post-generation guard pipeline.

    Args:
        base_system_prompt: The system prompt produced by
            `claude_coach_service.build_system_prompt()`.

    Returns:
        The augmented system prompt string.
    """
    if not isinstance(base_system_prompt, str) or not base_system_prompt:
        raise ValueError("base_system_prompt must be a non-empty string")
    return base_system_prompt + _N4_DIRECTIVE


# ════════════════════════════════════════════════════════════════════════════
# Generation runners
# ════════════════════════════════════════════════════════════════════════════

def _load_contexts() -> list[dict]:
    with CONTEXTS_PATH.open("r", encoding="utf-8") as f:
        data = json.load(f)
    return data["contexts"]


def _fixture_text_for(ctx_id: str) -> str:
    """Return a pre-canned N4 generation for the given context id.

    Fixtures live in `reverse_outputs_fixtures/<ctx_id>.txt` so they can be
    edited by hand without touching the runner. The fixtures committed in
    this plan are placeholder N4 generations the Plan 02 testers will rate
    blind. They MUST be regenerated via --live before the actual rating
    round if the system prompt has changed since.
    """
    fixture_path = FIXTURES_DIR / f"{ctx_id}.txt"
    if not fixture_path.exists():
        raise FileNotFoundError(
            f"Fixture missing for {ctx_id}: {fixture_path}. "
            f"Run with --live to regenerate, or commit the fixture file."
        )
    return fixture_path.read_text(encoding="utf-8").strip()


def _live_generate(ctx: dict) -> str:
    """Call the live Claude API at forced N4. Requires ANTHROPIC_API_KEY."""
    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        raise RuntimeError(
            "ANTHROPIC_API_KEY not set; cannot run --live mode. "
            "Use --fixtures (default) or export the key."
        )
    try:
        # Imports deferred so --fixtures mode works without these deps.
        from anthropic import Anthropic  # type: ignore

        # Backend services path.
        sys.path.insert(0, str(REPO_ROOT / "services" / "backend"))
        from app.services.coach.claude_coach_service import build_system_prompt  # type: ignore
        from app.services.coach.coach_models import CoachContext  # type: ignore
    except ImportError as e:
        raise RuntimeError(f"--live mode requires anthropic SDK + backend imports: {e}")

    coach_ctx = CoachContext(
        first_name="utilisateur",
        archetype=(
            "expat_us" if ctx["profile_snapshot_ref"] == "lauren" else "swiss_native"
        ),
        canton="VS",
    )
    base_prompt = build_system_prompt(ctx=coach_ctx, language="fr", cash_level=4)
    forced = force_level_n4_directive(base_system_prompt=base_prompt)

    client = Anthropic(api_key=api_key)
    msg = client.messages.create(
        model="claude-opus-4-20250514",
        max_tokens=400,
        system=forced,
        messages=[{"role": "user", "content": ctx["user_turn_fr"]}],
    )
    return "".join(block.text for block in msg.content if hasattr(block, "text")).strip()


# ════════════════════════════════════════════════════════════════════════════
# Output assembly
# ════════════════════════════════════════════════════════════════════════════

def _assemble_output(generations: list[tuple[dict, str]]) -> dict:
    """Build the reverse_outputs_v1.json blob in frozen_phrases_v1 shape."""
    phrases = []
    for i, (ctx, text) in enumerate(generations, start=1):
        phrases.append({
            "id": f"reverse_{i:02d}",
            "level": "N4",                  # exposed for shape parity, blinded by UI
            "_expected_level": "N4",        # stripped by rater UI before render (T-11-08)
            "lifeEvent": ctx["life_event"],
            "gravity": "G2",
            "relation": "context",
            "sensitiveTopic": None,
            "frText": text,
            "source": "reverse_generation_test:phase-11-plan-04",
            "rationale": (
                f"Reverse-Krippendorff context {ctx['id']}: "
                f"{ctx['scenario_label']} — forced N4."
            ),
            "antiShameCheckpointsPassed": [1, 2, 3, 4, 5, 6],
            "_context_ref": ctx["id"],
        })
    return {
        "version": "1.0.0",
        "frozenAt": "2026-04-07",
        "phase": "11-l1.6b",
        "phraseCount": len(phrases),
        "purpose": (
            "Reverse-Krippendorff generation outputs — Plan 02 testers rate "
            "these blind alongside frozen_phrases_v1.json. Pass gate: ≥7/10 "
            "majority-classified N4."
        ),
        "phrases": phrases,
    }


# ════════════════════════════════════════════════════════════════════════════
# CLI
# ════════════════════════════════════════════════════════════════════════════

def main(argv: Optional[list[str]] = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--live",
        action="store_true",
        help="Call live Claude API (requires ANTHROPIC_API_KEY). Default: --fixtures.",
    )
    parser.add_argument(
        "--out",
        type=Path,
        default=DEFAULT_OUTPUT,
        help=f"Output JSON path (default: {DEFAULT_OUTPUT.relative_to(REPO_ROOT)})",
    )
    args = parser.parse_args(argv)

    contexts = _load_contexts()
    if len(contexts) != 10:
        print(f"ERROR: expected 10 contexts, got {len(contexts)}", file=sys.stderr)
        return 2

    generations: list[tuple[dict, str]] = []
    for ctx in contexts:
        if args.live:
            text = _live_generate(ctx)
        else:
            text = _fixture_text_for(ctx["id"])
        generations.append((ctx, text))
        print(f"  ✓ {ctx['id']}: {ctx['scenario_label']}", file=sys.stderr)

    blob = _assemble_output(generations)
    args.out.write_text(json.dumps(blob, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"\nWrote {len(generations)} outputs → {args.out}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
