#!/usr/bin/env python3
"""DATA_LEDGER.md §8.3 new-debt gate for ledger persistence bypasses."""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
APP_LIB = "apps/mobile/lib/"
ALLOWED = {
    "apps/mobile/lib/services/report_persistence_service.dart",
    "apps/mobile/lib/providers/coach_profile_provider.dart",
}
BUDGET_CACHE = "apps/mobile/lib/data/budget/budget_local_store.dart"
DOMAIN = set(
    "birthYear dateOfBirth canton commune householdType employmentStatus goal targetRetirementAge gender "
    "incomeNetMonthly incomeNetYearly incomeGrossMonthly incomeGrossYearly employmentRate annualBonus "
    "selfEmployedNetIncome lppInsuredSalary avoirLpp avoirLppObligatoire avoirLppSurobligatoire "
    "lppBuybackMax has2ndPillar hasVoluntaryLpp pillar3aAnnual pillar3aBalance savingsMonthly "
    "totalSavings wealthEstimate hasDebt totalDebt spouseBirthYear spouseIncomeNetMonthly "
    "spouseAvsContributionYears hasAvsGaps avsContributionYears"
    .split()
)
PREFIXES = (
    "q_",
    "_coach_",
    "fp:",
    "prevoyance.",
    "patrimoine.",
    "dettes.",
    "depenses.",
    "conjoint.",
    "goalA",
    "goalsB",
    "plannedContributions",
    "checkIns",
)
SETTER = re.compile(r"\.set(?:String|Double|Int|Bool|StringList)\s*\(\s*(?P<q>['\"])(?P<key>[^'\"]+)(?P=q)")


def _clean(path: str) -> str:
    return path.removeprefix("a/").removeprefix("b/").replace("\\", "/")


def _scoped(path: str) -> bool:
    rel = _clean(path)
    wrapped = f"/{rel}/"
    return rel.startswith(APP_LIB) and rel.endswith(".dart") and not rel.endswith(".g.dart") and "/test/" not in wrapped and "/tests/" not in wrapped


def _added(diff: str) -> list[tuple[str, int, str]]:
    out: list[tuple[str, int, str]] = []
    path: str | None = None
    line: int | None = None
    for raw in diff.splitlines():
        if raw.startswith("diff --git "):
            path = None
        elif raw.startswith("+++ "):
            marker = raw[4:].strip()
            path = None if marker == "/dev/null" else _clean(marker)
        elif raw.startswith("@@ "):
            match = re.search(r"\+(\d+)", raw)
            line = int(match.group(1)) if match else None
        elif line is None:
            continue
        elif raw.startswith("+") and not raw.startswith("+++"):
            if path and _scoped(path):
                out.append((path, line, raw[1:]))
            line += 1
        elif not (raw.startswith("-") and not raw.startswith("---")):
            line += 1
    return out


def _domain_key(key: str) -> bool:
    return key == "wizard_answers_v2" or key in DOMAIN or key.startswith(PREFIXES)


def _violation(path: str, text: str) -> str | None:
    if path not in ALLOWED and "SharedPreferences.getInstance()" in text and "/screens/" in f"/{path}/" and "simulator" in path.lower():
        return "simulator screen must use CoachProfileProvider.updateProfile(), not SharedPreferences"
    match = SETTER.search(text)
    if not match:
        return None
    key = match.group("key")
    if path == BUDGET_CACHE:
        return "budget_local_store.dart is a cache and must not write wizard_answers_v2" if key == "wizard_answers_v2" else None
    if path in ALLOWED or not _domain_key(key):
        return None
    return f"domain key '{key}' persisted outside CoachProfileProvider/report_persistence_service; use mergeAnswers/applySaveFact/updateProfile"


def _git_diff(args: list[str]) -> str:
    result = subprocess.run(["git", "diff", "--unified=0", "--no-ext-diff", *args, "--", APP_LIB], cwd=REPO, text=True, capture_output=True, check=False)
    if result.returncode:
        print(result.stderr.strip(), file=sys.stderr)
        raise SystemExit(result.returncode)
    return result.stdout


def _read(args: argparse.Namespace) -> str:
    if args.diff_file:
        return Path(args.diff_file).read_text(encoding="utf-8")
    if args.staged:
        return _git_diff(["--cached"])
    return _git_diff([f"{args.base_ref}...HEAD"] if args.base_ref else ["HEAD"])


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--diff-file")
    parser.add_argument("--staged", action="store_true")
    parser.add_argument("--base-ref")
    args = parser.parse_args()
    if sum(bool(v) for v in (args.diff_file, args.staged, args.base_ref)) > 1:
        parser.error("use only one of --diff-file, --staged, or --base-ref")
    failures = [(p, n, d, t.strip()) for p, n, t in _added(_read(args)) for d in [_violation(p, t)] if d]
    if failures:
        print("::error::no_bypass_persistence failed:")
        for path, line, detail, text in failures:
            print(f"{path}:{line}: {detail}: {text}")
        return 1
    print("OK no_bypass_persistence: no ledger persistence bypass in added Dart lines")
    return 0


if __name__ == "__main__":
    sys.exit(main())
