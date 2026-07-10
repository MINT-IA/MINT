#!/usr/bin/env python3
"""MINT OS preflight: make runtime tooling explicit and non-implicit."""
from __future__ import annotations

import argparse
import json
import os
import plistlib
import shutil
import subprocess
import sys
from dataclasses import asdict, dataclass
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from tools.checks import patrol_tooling_guard


@dataclass(frozen=True)
class CheckResult:
    name: str
    status: str
    detail: str


def _executable(path: Path) -> bool:
    return path.exists() and os.access(path, os.X_OK)


def _which_or_path(binary: str, fallback: Path | None = None) -> Path | None:
    if found := shutil.which(binary):
        return Path(found)
    if fallback is not None and _executable(fallback):
        return fallback
    return None


def _run_version(args: list[str], cwd: Path, timeout: int = 20) -> str:
    proc = subprocess.run(
        args,
        cwd=cwd,
        text=True,
        capture_output=True,
        timeout=timeout,
        check=False,
    )
    output = (proc.stdout or proc.stderr).strip().splitlines()
    if proc.returncode != 0:
        return f"exit {proc.returncode}: {output[0] if output else 'no output'}"
    return output[0] if output else "ok"


def _read_plist(path: Path) -> dict:
    try:
        with path.open("rb") as plist:
            data = plistlib.load(plist)
    except (OSError, plistlib.InvalidFileException):
        return {}
    return data if isinstance(data, dict) else {}


def _url_schemes(plist: dict) -> set[str]:
    schemes: set[str] = set()
    for entry in plist.get("CFBundleURLTypes", []):
        if not isinstance(entry, dict):
            continue
        for scheme in entry.get("CFBundleURLSchemes", []):
            if isinstance(scheme, str):
                schemes.add(scheme)
    return schemes


def _ios_plist_split_errors(root: Path) -> list[str]:
    release = _read_plist(root / "apps" / "mobile" / "ios" / "Runner" / "Info.plist")
    debug = _read_plist(root / "apps" / "mobile" / "ios" / "Runner" / "Info-Debug.plist")
    errors: list[str] = []
    if not release:
        errors.append("missing or invalid apps/mobile/ios/Runner/Info.plist")
    if not debug:
        errors.append("missing or invalid apps/mobile/ios/Runner/Info-Debug.plist")
    if errors:
        return errors

    debug_only_keys = ("NSBonjourServices", "NSLocalNetworkUsageDescription")
    for key in debug_only_keys:
        if key in release:
            errors.append(f"release Info.plist must not contain debug-only {key}")
        if key not in debug:
            errors.append(f"Info-Debug.plist must contain {key}")

    release_schemes = _url_schemes(release)
    debug_schemes = _url_schemes(debug)
    if not release_schemes:
        errors.append("release Info.plist must define at least one CFBundleURLScheme")
    elif release_schemes != debug_schemes:
        errors.append(f"Info-Debug.plist URL schemes {sorted(debug_schemes)} must match release {sorted(release_schemes)}")
    return errors


def check_repo(root: Path) -> list[CheckResult]:
    root = root.resolve()
    results: list[CheckResult] = []

    patrol_errors = patrol_tooling_guard.check(root, require_cli=False)
    results.append(
        CheckResult(
            "repo.patrol",
            "pass" if not patrol_errors else "fail",
            "Patrol dependency/config/test directory wired"
            if not patrol_errors
            else "; ".join(patrol_errors),
        )
    )

    repo_files = {
        "repo.maestro_env": root / "tools" / "simulator" / "maestro_env.sh",
        "repo.maestro_watchdog": root / "tools" / "simulator" / "maestro_with_watchdog.sh",
        "repo.mermaid_guard": root / "tools" / "checks" / "mermaid_render_guard.py",
        "repo.claude_audit_wrapper": root / "tools" / "checks" / "claude_external_audit.sh",
        "repo.agent_workflow": root / "docs" / "MINT_AGENT_WORKFLOW.md",
    }
    for name, path in repo_files.items():
        results.append(
            CheckResult(
                name,
                "pass" if path.exists() else "fail",
                str(path.relative_to(root)) if path.exists() else f"missing {path.relative_to(root)}",
            )
        )
    plist_errors = _ios_plist_split_errors(root)
    results.append(
        CheckResult(
            "repo.ios_plist_split",
            "pass" if not plist_errors else "fail",
            "Debug-only Flutter VM network keys stay out of release Info.plist"
            if not plist_errors
            else "; ".join(plist_errors),
        )
    )
    return results


def check_host(root: Path) -> list[CheckResult]:
    home = Path.home()
    results: list[CheckResult] = []

    patrol = _which_or_path("patrol", home / ".pub-cache" / "bin" / "patrol")
    results.append(
        CheckResult(
            "host.patrol_cli",
            "pass" if patrol else "fail",
            str(patrol) if patrol else "missing patrol CLI; expected $HOME/.pub-cache/bin/patrol",
        )
    )

    maestro = _which_or_path("maestro", home / ".maestro" / "bin" / "maestro")
    results.append(
        CheckResult(
            "host.maestro_cli",
            "pass" if maestro else "fail",
            str(maestro) if maestro else "missing Maestro CLI; expected $HOME/.maestro/bin/maestro",
        )
    )

    npx = _which_or_path("npx")
    results.append(
        CheckResult(
            "host.mermaid_cli",
            "pass" if npx else "fail",
            _run_version(["npx", "--yes", "@mermaid-js/mermaid-cli", "--version"], root)
            if npx
            else "missing npx for @mermaid-js/mermaid-cli",
        )
    )

    claude = _which_or_path("claude")
    results.append(
        CheckResult(
            "host.claude_cli",
            "pass" if claude else "fail",
            str(claude) if claude else "missing Claude CLI",
        )
    )

    beads = _which_or_path("bd")
    results.append(
        CheckResult(
            "host.beads_cli",
            "pass" if beads else "warn",
            _run_version([str(beads), "--version"], root) if beads else "not found; install with `brew install beads`",
        )
    )
    return results


def render(results: list[CheckResult], *, as_json: bool) -> None:
    if as_json:
        print(json.dumps([asdict(result) for result in results], indent=2, ensure_ascii=False))
        return
    width = max(len(result.name) for result in results)
    for result in results:
        print(f"{result.status.upper():4} {result.name.ljust(width)}  {result.detail}")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--repo-only", action="store_true", help="Skip host-specific binary checks.")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args(argv)

    root = args.root.resolve()
    results = check_repo(root)
    if not args.repo_only:
        results.extend(check_host(root))
    render(results, as_json=args.json)

    return 1 if any(result.status == "fail" for result in results) else 0


if __name__ == "__main__":
    sys.exit(main())
