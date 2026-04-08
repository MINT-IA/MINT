#!/usr/bin/env python3
"""Mine the 30 most-used coach phrases from ARB + claude_coach_service.

Plan 11-01 / VOICE-04. See `.planning/phases/11-l1.6b-phrase-rewrite-krippendorff/11-CONTEXT.md` D-01.

Strategy:
1. Parse `apps/mobile/lib/l10n/app_fr.arb` for coach-scoped keys
   (prefixes: coach*, chat*, insight*, greeting*, fallback*).
2. Parse `services/backend/app/services/coach/claude_coach_service.py` for
   user-facing string literals embedded in fallback/few-shot blocks
   (we deliberately skip the system-prompt LLM directives — those are
   internal English-style instructions, not user-facing phrases).
3. For each ARB key, grep call sites in `apps/mobile/lib/**` to score usage.
4. Rank by usage count DESC, stratify by category, select top 30 with
   strata minimums per D-01.
5. Emit `tools/voice_corpus/phrase_mining_report.json`.

Run: `python3 tools/voice_corpus/mine_phrases.py`
Dry-run: `python3 tools/voice_corpus/mine_phrases.py --dry-run`
    (still writes the JSON; --dry-run only suppresses stdout chatter)
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ARB_FR = ROOT / "apps/mobile/lib/l10n/app_fr.arb"
COACH_PY = ROOT / "services/backend/app/services/coach/claude_coach_service.py"
MOBILE_LIB = ROOT / "apps/mobile/lib"
BACKEND_APP = ROOT / "services/backend/app"
OUTPUT = ROOT / "tools/voice_corpus/phrase_mining_report.json"

KEY_PREFIXES = ("coach", "chat", "insight", "greeting", "fallback", "messageCoach", "intentChip")

# Category routing rules — applied in order, first match wins.
CATEGORY_RULES = [
    ("error_fallback", re.compile(r"(?i)(error|fallback|empty|invalid|unavailable|fail|technique)")),
    ("greetings",     re.compile(r"(?i)(greeting|salut|bonjour|welcome|briefingFallbackGreeting|home|hello|input)")),
    ("warning",       re.compile(r"(?i)(disclaimer|warning|alert|attention|risk|compliance|caution)")),
    ("question",      re.compile(r"(?i)(suggest|ask|prompt|question|hint|input|inputHint)")),
    ("validation",    re.compile(r"(?i)(confirm|valider|done|success|tooltip|badge|label|button|step)")),
    ("insight_opener",re.compile(r"(?i)(insight|loading|trajectory|shock|fact|message|brief|coaching|score|impact)")),
    ("transition",    re.compile(r"(?i)(next|continue|skip|then|change|update)")),
    ("closing",       re.compile(r"(?i)(close|cancel|exit|end|finish|sources|source|gate|unlock)")),
]


def categorize(key: str) -> str:
    for label, rx in CATEGORY_RULES:
        if rx.search(key):
            return label
    return "insight_opener"


def parse_arb_keys(arb_path: Path) -> dict[str, dict]:
    """Return {key: {value: str, line: int}} for coach-scoped keys."""
    out: dict[str, dict] = {}
    line_re = re.compile(r'^\s*"([^"@]+)"\s*:\s*"((?:[^"\\]|\\.)*)"\s*,?\s*$')
    with arb_path.open(encoding="utf-8") as f:
        for lineno, line in enumerate(f, start=1):
            m = line_re.match(line)
            if not m:
                continue
            k, v = m.group(1), m.group(2)
            if k.startswith(KEY_PREFIXES):
                # ARB stores literal UTF-8 + JSON \uXXXX escapes (e.g. \u00a0).
                # Decode only the \uXXXX escapes, leave UTF-8 bytes intact.
                v_dec = re.sub(
                    r"\\u([0-9a-fA-F]{4})",
                    lambda m: chr(int(m.group(1), 16)),
                    v,
                )
                out[k] = {"value": v_dec, "line": lineno}
    return out


def count_arb_usage(key: str) -> int:
    """Count call sites of an ARB key under apps/mobile/lib (rough but reproducible)."""
    try:
        result = subprocess.run(
            ["grep", "-rE", "--include=*.dart", rf"\b{key}\b", str(MOBILE_LIB)],
            capture_output=True, text=True, check=False,
        )
        if result.returncode not in (0, 1):
            return 0
        # subtract the ARB-self definition if any (none, since .dart only)
        return len([ln for ln in result.stdout.splitlines() if ln.strip()])
    except Exception:
        return 0


def parse_coach_py_phrases(path: Path) -> list[dict]:
    """Extract user-facing French string literals embedded in claude_coach_service.py.

    Heuristic: lines containing French diacritics OR a non-breaking space marker
    (\\u00a0), inside triple-quoted blocks. We capture short user-facing-style
    sentences (< 200 chars) — these are mostly the example phrases inside the
    CHECK-IN, FOUR-LAYER and FIRST_JOB blocks.
    """
    text = path.read_text(encoding="utf-8")
    out: list[dict] = []
    # Lines that look like example phrases (start with Example: or quoted French)
    line_re = re.compile(r'^\s*(?:Example\s*:\s*)?"([^"\n]{8,200})"\s*$', re.MULTILINE)
    for m in line_re.finditer(text):
        s = m.group(1)
        if any(c in s for c in "éèêàçùôîâï") or "\\u00a0" in s:
            lineno = text[: m.start()].count("\n") + 1
            out.append({"value": s, "line": lineno})
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    arb_keys = parse_arb_keys(ARB_FR)
    coach_phrases = parse_coach_py_phrases(COACH_PY)

    if not args.dry_run:
        print(f"Scanned {len(arb_keys)} ARB candidate keys, "
              f"{len(coach_phrases)} coach.py phrases", file=sys.stderr)

    # Score ARB keys by usage
    scored: list[dict] = []
    for k, info in arb_keys.items():
        usage = count_arb_usage(k)
        scored.append({
            "id": k,
            "source": "arb",
            "arb_key": k,
            "file": "apps/mobile/lib/l10n/app_fr.arb",
            "line": info["line"],
            "usage_count": usage,
            "category": categorize(k),
            "current_fr": info["value"],
        })

    # Add a small set of coach.py phrases as additional candidates (low priority)
    for ph in coach_phrases[:8]:
        scored.append({
            "id": f"coach_py_L{ph['line']}",
            "source": "prompt",
            "arb_key": None,
            "file": "services/backend/app/services/coach/claude_coach_service.py",
            "line": ph["line"],
            "usage_count": 1,  # by definition, embedded in 1 location
            "category": "insight_opener",
            "current_fr": ph["value"],
        })

    # Sort by usage DESC, then alpha for determinism
    scored.sort(key=lambda x: (-x["usage_count"], x["id"]))

    # Stratified top-30 selection.
    # Strata minimums (D-01): ≥4 greetings, ≥4 insight_opener, ≥4 question,
    # ≥4 warning, ≥4 validation, ≥4 transition, ≥4 closing, ≥2 error_fallback.
    # If a stratum can't reach its minimum, we relax (best-effort) and log.
    minimums = {
        "greetings": 4, "insight_opener": 4, "question": 4, "warning": 4,
        "validation": 4, "transition": 4, "closing": 4, "error_fallback": 2,
    }
    selected: list[dict] = []
    by_cat: dict[str, list[dict]] = {c: [] for c in minimums}
    for entry in scored:
        by_cat.setdefault(entry["category"], []).append(entry)

    # First pass: fill minimums
    for cat, mn in minimums.items():
        for e in by_cat.get(cat, [])[:mn]:
            selected.append(e)
    # Second pass: top-up to 30 by usage from remaining pool
    chosen_ids = {e["id"] for e in selected}
    for entry in scored:
        if len(selected) >= 30:
            break
        if entry["id"] in chosen_ids:
            continue
        selected.append(entry)
        chosen_ids.add(entry["id"])
    selected = selected[:30]

    # Re-sort selected by usage DESC for ranking, assign rank
    selected.sort(key=lambda x: (-x["usage_count"], x["category"], x["id"]))
    for i, e in enumerate(selected, start=1):
        e["rank"] = i
        e["proposed_level"] = None
        e["proposed_rewrite_fr"] = None
        e["checkpoints"] = None

    payload = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "total_candidates_scanned": len(scored),
        "strata_minimums": minimums,
        "phrases": selected,
    }

    OUTPUT.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    if not args.dry_run:
        print(f"Wrote {OUTPUT.relative_to(ROOT)} with {len(selected)} phrases", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
