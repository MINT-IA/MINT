"""Live coach doctrine bench — Wave 6.5 companion.

Runs the 10 evaluation fixtures through the real Claude coach and scores
responses against the 6 mechanical doctrine checks. Not in CI (it hits
the Anthropic API). Invoke manually when we need to validate that the
amended rule actually drives live output past the 80 % gate.

Usage:
    export ANTHROPIC_API_KEY=sk-ant-...
    cd services/backend
    python3 scripts/bench_coach_doctrine.py                 # all fixtures
    python3 scripts/bench_coach_doctrine.py divorce_existential

Output:
    .planning/coach-doctrine-bench/<iso>-<sha>.md
    with per-fixture score, failures, and a population gate verdict.

The bench does NOT modify the system prompt or any code; it just exercises
`build_system_prompt` and feeds one user turn per fixture.
"""

from __future__ import annotations

import argparse
import asyncio
import json
import os
import subprocess
from dataclasses import asdict
from datetime import datetime, timezone
from pathlib import Path

import anthropic

from app.services.coach.claude_coach_service import build_system_prompt
from app.services.coach.coach_models import CoachContext
from app.services.coach.doctrine_checks import (
    QuestionMeta,
    score_response,
)

FIXTURE_PATH = (
    Path(__file__).parent.parent / "tests" / "fixtures" / "coach_doctrine_eval.json"
)
POPULATION_GATE = 80.0
OUT_DIR = Path(__file__).parent.parent.parent.parent / ".planning" / "coach-doctrine-bench"


def _git_sha() -> str:
    try:
        return subprocess.check_output(
            ["git", "rev-parse", "--short", "HEAD"],
            cwd=Path(__file__).parent,
            text=True,
        ).strip()
    except subprocess.SubprocessError:
        return "nogit"


def _ctx_for(meta: dict) -> CoachContext:
    return CoachContext(
        archetype=meta.get("archetype"),
        canton="VS",  # golden couple canton; swap per fixture later if needed
        has_debt=False,
        intent=None,
    )


async def _run_one(
    client: anthropic.AsyncAnthropic,
    case: dict,
    model: str,
) -> tuple[str, dict]:
    ctx = _ctx_for(case["meta"])
    system = build_system_prompt(ctx=ctx, language="fr", cash_level=3)
    resp = await client.messages.create(
        model=model,
        system=system,
        max_tokens=600,
        temperature=0.4,
        messages=[{"role": "user", "content": case["question"]}],
    )
    text = "".join(block.text for block in resp.content if block.type == "text")
    qmeta = QuestionMeta(
        archetype=case["meta"]["archetype"],
        life_event=case["meta"]["life_event"],
        irreversible=case["meta"]["irreversible"],
        existential=case["meta"]["existential"],
    )
    report = score_response(text, qmeta)
    return text, {
        "id": case["id"],
        "question": case["question"],
        "meta": case["meta"],
        "response": text,
        "score": report.score,
        "passed": report.passed_count,
        "total": report.total,
        "failures": [asdict(c) for c in report.failures()],
    }


async def main(selector: str | None = None) -> int:
    with FIXTURE_PATH.open(encoding="utf-8") as f:
        data = json.load(f)
    fixtures = data["fixtures"]
    if selector:
        fixtures = [f for f in fixtures if f["id"] == selector]
        if not fixtures:
            print(f"No fixture matches id={selector}")
            return 2

    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        print("ANTHROPIC_API_KEY missing — cannot run live bench.")
        return 1

    client = anthropic.AsyncAnthropic(api_key=api_key)
    model = os.environ.get(
        "MINT_ANTHROPIC_SONNET_MODEL_ID", "claude-sonnet-4-5-20251022"
    )

    results: list[dict] = []
    for case in fixtures:
        text, r = await _run_one(client, case, model)
        results.append(r)
        status = "PASS" if r["score"] >= POPULATION_GATE else "FAIL"
        print(f"[{status}] {r['id']:<30s} {r['score']:5.1f}%  failures={len(r['failures'])}")

    avg = sum(r["score"] for r in results) / len(results) if results else 0.0
    gate = "PASS" if avg >= POPULATION_GATE else "FAIL"

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    out_path = OUT_DIR / f"{stamp}-{_git_sha()}.md"

    lines = [
        "# Coach doctrine live bench",
        f"*model: {model}, fixtures: {len(results)}, population gate: {POPULATION_GATE}%*",
        "",
        f"**Population score: {avg:.1f}% — {gate}**",
        "",
    ]
    for r in results:
        lines.append(f"## {r['id']} ({r['score']:.0f}%)")
        lines.append(f"**Q:** {r['question']}")
        lines.append("")
        lines.append(f"**A:**\n{r['response']}")
        lines.append("")
        if r["failures"]:
            lines.append("**Failures:**")
            for f in r["failures"]:
                lines.append(f"- {f['name']}: {f['reason']}")
        lines.append("---")
    out_path.write_text("\n".join(lines), encoding="utf-8")
    print(f"\nReport written to {out_path}")
    return 0 if avg >= POPULATION_GATE else 1


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("fixture_id", nargs="?", default=None)
    args = parser.parse_args()
    exit_code = asyncio.run(main(args.fixture_id))
    raise SystemExit(exit_code)
