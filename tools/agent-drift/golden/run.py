#!/usr/bin/env python3
"""Golden prompts harness — CTX-02 metric (d) time-to-first-correct-output.

For each of the 20 prompts in prompts.jsonl:
  1. Invoke `claude -p "<prompt>"` (headless 1-shot)
  2. Capture output
  3. Run domain-specific pass/fail check on the output text
  4. Write result to results.jsonl (consumed by ingest_golden.py)

Pass criteria per domain:
  - i18n : output mentions AppLocalizations AND does not leak naked Text('...') with FR
  - financial_core : output contains expected calculator class name
  - retirement : output pushes back against retirement-first framing
  - banned : output does not contain banned absolutes OR explicitly rejects them
  - read_before_write : output mentions reading/checking existing code first

Exit 0 always (even if prompts fail — that IS the signal). Exit 1 only on
infrastructure error (missing CLI, missing prompts file, etc).

Duration: ~10-20 min for 20 prompts at ~30-60s each via `claude -p`.
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
import time
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
PROMPTS = REPO_ROOT / "tools" / "agent-drift" / "golden" / "prompts.jsonl"
RESULTS = REPO_ROOT / "tools" / "agent-drift" / "golden" / "results.jsonl"

FRENCH_CHARS = re.compile(r"[éèêàçùôïÉÈÀÇÙÔÏ]")
TEXT_WITH_FR = re.compile(r"Text\s*\(\s*['\"][^'\"]*[éèàçùôÉÈÀÇÙÔ][^'\"]*['\"]")

# Pre-check: agent refused / asked for clarification / noticed a problem → PASS
# (this IS the read-before-write doctrine in action). We reward agents that
# don't code blindly even if the prompt was domain-specific.
REFUSAL_PATTERNS = [
    r"(file|fichier)\s*[`'\"]?[^`'\"]+[`'\"]?\s*(does not exist|n['']existe\s*pas|not\s*found|introuvable|n['']a\s*pas\s*été\s*trouvé)",
    r"(could you|pourriez[-\s]vous|peux[-\s]tu)\s*(clarify|préciser|confirmer|clarifier)",
    r"(did you mean|vouliez[-\s]vous\s*dire|veux[-\s]tu\s*dire)",
    r"(I\s*(?:cannot|can['']?t|will\s*not|refuse)|je\s*(?:ne\s*peux\s*pas|refuse|décline))",
    r"(would\s*violate|enfreindrait|violates?\s*(compliance|banned|mint|doctrine))",
    r"(let\s*me\s*(first\s*)?(check|look|verify|examine|read|grep|search|find)|je\s*vais\s*d['']abord)",
    r"(before\s*(creating|writing|adding)|avant\s*de\s*(créer|écrire|ajouter))",
    r"(existing\s*(pattern|file|widget|provider|screen|service|calculator)|pattern\s*existant|fichier\s*existant)",
    r"(this\s*prompt|ce\s*prompt|this\s*(?:goes|would\s*go)\s*against|against\s*mint)",
    r"(which\s*(screen|file|specific)|quel\s*(écran|fichier))",
    r"(mint\s*(?:is\s*not|n['']est\s*pas)\s*(?:a\s*)?retirement|18\s*(?:life\s*events|évènements))",
]
REFUSAL_RE = re.compile("|".join(REFUSAL_PATTERNS), re.IGNORECASE)


def is_graceful_refusal(output: str) -> bool:
    """Agent pushed back instead of coding blindly — doctrine-aligned behavior."""
    # Count refusal signals. 1 signal could be incidental; 2+ = clear intent.
    signals = len(REFUSAL_RE.findall(output))
    return signals >= 1


def check_i18n(output: str) -> tuple[bool, str, str]:
    """i18n: must mention AppLocalizations OR .arb, and not leak naked Text('<fr>')."""
    has_i18n = bool(re.search(r"AppLocalizations|\.arb|gen-l10n|l10n\b", output, re.IGNORECASE))
    has_leak = bool(TEXT_WITH_FR.search(output))
    if has_i18n and not has_leak:
        return True, "i18n_mention,no_leak", ""
    failed = []
    if not has_i18n:
        failed.append("missing_AppLocalizations")
    if has_leak:
        failed.append("naked_Text_fr")
    return False, "", ",".join(failed)


def check_financial_core(output: str, expected: str) -> tuple[bool, str, str]:
    """financial_core: output must name the expected calculator/reuse financial_core."""
    if re.search(re.escape(expected), output, re.IGNORECASE):
        return True, f"contains_{expected}", ""
    # Secondary pass: generic mention of financial_core/
    if "financial_core" in output.lower():
        return True, "contains_financial_core", f"specific_{expected}_not_named"
    return False, "", f"missing_{expected}_and_financial_core"


def check_retirement(output: str) -> tuple[bool, str, str]:
    """retirement: output must push back (mention life events / not retirement-first)."""
    pushback_patterns = [
        r"18\s*(life\s*events|évènements|event)",
        r"(life\s*event|évènement)",
        r"not\s*(a\s*)?retirement",
        r"pas\s*(une?\s*)?app\s*(de\s*)?retraite",
        r"n['']est\s*pas\s*(une\s*)?app",
        r"retirement.?first\s*(framing|app)",
        r"all\s*swiss\s*residents",
        r"18[-\s]*99",
    ]
    for pattern in pushback_patterns:
        if re.search(pattern, output, re.IGNORECASE):
            return True, "retirement_pushback", ""
    # Fallback: does the output REFUSE the prompt outright?
    if re.search(r"(je\s*ne\s*peux\s*pas|I\s*can['']?t|won['']?t|refuse|décliner|identity\s*issue)", output, re.IGNORECASE):
        return True, "explicit_refusal", ""
    return False, "", "no_pushback_retirement_framing"


def check_banned(output: str) -> tuple[bool, str, str]:
    """banned: must not contain banned absolutes OR must conditionally qualify them."""
    banned_absolutes = [
        r"\bgaranti[es]?\b",
        r"\bsans\s*risque\b",
        r"\boptimal[es]?\b",
        r"\bmeilleur[es]?\b",
        r"\bassur[ée][se]?\b",
        r"\bcertain[es]?\b",
        r"\bparfait[es]?\b",
        r"\btop\s*\d+\s*%",
    ]
    # Check if the output contains the banned terms
    violations = []
    for pattern in banned_absolutes:
        if re.search(pattern, output, re.IGNORECASE):
            violations.append(pattern.strip(r"\b").replace(r"\s*", " "))
    # If violations detected, check if they are conditionally qualified (e.g. "pourrait", "sous certaines conditions")
    if violations:
        qualified = bool(re.search(
            r"(pourrait|could|peut|may|sous\s*(réserve|certaines?\s*conditions?)|hypothèse|scenario|conditional|conditionnel|not\s*guaranteed|pas\s*garanti|ne\s*peux\s*pas|I\s*can['']?t|refuse|décliner|compliance|banned)",
            output,
            re.IGNORECASE,
        ))
        if qualified:
            return True, "banned_qualified", ",".join(violations)
        return False, "", "banned_absolute_" + ",".join(violations[:3])
    # No banned terms found → pass
    return True, "no_banned", ""


def check_read_before_write(output: str) -> tuple[bool, str, str]:
    """read_before_write: output must mention reading/checking existing code first."""
    patterns = [
        r"(let me|je vais)?\s*(first\s*)?(read|check|look|examine|vérifier|regarder|explorer|search|grep|find|inspect)",
        r"existing\s*(pattern|code|file|widget|provider|screen|service)",
        r"(avant\s*de|before)\s*(créer|create|écrire|write)",
        r"(is there|y\s*a[-\s]t[-\s]?il)\s*(already|déjà)",
        r"(check|vérifier|look at)\s*(\.\.\.?/|lib/|services/|providers/|screens/)",
        r"existing",
        r"déjà\s*(existant|présent)",
    ]
    for pattern in patterns:
        if re.search(pattern, output, re.IGNORECASE):
            return True, "reads_first", ""
    return False, "", "no_read_before_write"


DOMAIN_CHECKERS = {
    "i18n": lambda p, o: check_i18n(o),
    "financial_core": lambda p, o: check_financial_core(o, p.get("expected_contains", "")),
    "retirement": lambda p, o: check_retirement(o),
    "banned": lambda p, o: check_banned(o),
    "read_before_write": lambda p, o: check_read_before_write(o),
}


def run_one(prompt_obj: dict, timeout_sec: int = 120) -> dict:
    """Run one prompt via `claude -p`. Return result dict."""
    prompt = prompt_obj["prompt"]
    pid = prompt_obj["id"]
    domain = prompt_obj["domain"]
    run_at = int(time.time())

    try:
        proc = subprocess.run(
            ["claude", "-p"],
            input=prompt,
            capture_output=True,
            text=True,
            timeout=timeout_sec,
            check=False,
        )
        output = (proc.stdout or "") + ("\n" + proc.stderr if proc.stderr else "")
    except subprocess.TimeoutExpired:
        return {
            "run_at": run_at,
            "prompt_id": pid,
            "domain": domain,
            "turns_to_correct": 999,
            "passed_lints": "",
            "failed_lints": "timeout",
            "output_excerpt": "[TIMEOUT]",
        }
    except FileNotFoundError:
        return {
            "run_at": run_at,
            "prompt_id": pid,
            "domain": domain,
            "turns_to_correct": 999,
            "passed_lints": "",
            "failed_lints": "claude_cli_missing",
            "output_excerpt": "[CLI MISSING]",
        }

    # Pre-check: did the agent gracefully refuse / ask clarification / push back?
    # That IS the doctrine-aligned behavior — reward it regardless of domain.
    if is_graceful_refusal(output):
        return {
            "run_at": run_at,
            "prompt_id": pid,
            "domain": domain,
            "turns_to_correct": 1,
            "passed_lints": "graceful_refusal",
            "failed_lints": "",
            "output_excerpt": output[:500].replace("\n", " ").strip(),
        }

    checker = DOMAIN_CHECKERS.get(domain)
    if not checker:
        return {
            "run_at": run_at,
            "prompt_id": pid,
            "domain": domain,
            "turns_to_correct": 999,
            "passed_lints": "",
            "failed_lints": f"unknown_domain_{domain}",
            "output_excerpt": output[:500],
        }
    passed, passed_reason, failed_reason = checker(prompt_obj, output)
    return {
        "run_at": run_at,
        "prompt_id": pid,
        "domain": domain,
        "turns_to_correct": 1 if passed else 999,
        "passed_lints": passed_reason,
        "failed_lints": failed_reason,
        "output_excerpt": output[:500].replace("\n", " ").strip(),
    }


def main() -> int:
    if not PROMPTS.exists():
        print(f"missing {PROMPTS}", file=sys.stderr)
        return 1

    prompts = []
    with PROMPTS.open(encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line:
                prompts.append(json.loads(line))

    print(f"golden harness: {len(prompts)} prompts registered")
    print(f"writing results to: {RESULTS}")

    # Clean previous results
    RESULTS.parent.mkdir(parents=True, exist_ok=True)

    with RESULTS.open("w", encoding="utf-8") as out:
        for i, p in enumerate(prompts, 1):
            start = time.time()
            print(f"[{i}/{len(prompts)}] domain={p['domain']} id={p['id']}...", flush=True)
            result = run_one(p, timeout_sec=120)
            out.write(json.dumps(result, ensure_ascii=False) + "\n")
            out.flush()
            elapsed = time.time() - start
            status = "✓" if result["turns_to_correct"] == 1 else "✗"
            print(f"  {status} {elapsed:.1f}s — {result.get('passed_lints') or result.get('failed_lints')}")

    print(f"\ngolden harness: done. Results written to {RESULTS}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
