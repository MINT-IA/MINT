#!/usr/bin/env python3
"""Phase 96 D-17 — metaphor TOML byte-equality + value-poisoning lint.

Compares `apps/mobile/assets/metaphors.toml` and
`services/backend/app/data/metaphors.toml` — must be byte-equal (sha256).

With ``--scan-values``, also walks every metaphor string value for :
- LSFin banned terms (« garanti », « optimal », « parfait », « meilleur »,
  « certain », « assuré », « sans risque ») in non-negated context.
- PII patterns (email, phone, IBAN prefix).

Exit codes :
  0 — clean
  1 — parity violation OR poisoned value
"""
from __future__ import annotations

import hashlib
import re
import sys
from pathlib import Path

# tomllib is stdlib on Python 3.11+. On older interpreters (e.g. local dev
# workstation still on 3.9), fall back to the `tomli` backport when
# available ; otherwise raise a clear error at runtime.
try:
    import tomllib  # type: ignore[import-not-found]
except ModuleNotFoundError:  # Python ≤ 3.10
    try:
        import tomli as tomllib  # type: ignore[no-redef,import-not-found]
    except ModuleNotFoundError as exc:  # pragma: no cover
        raise SystemExit(
            "metaphor_parity requires Python 3.11+ (stdlib tomllib) or "
            "the `tomli` backport on older interpreters. Install via "
            "`pip install tomli` or upgrade Python."
        ) from exc

# Repo-root-anchored — `tools/checks/metaphor_parity.py` is 2 levels
# below the repo root.  Resolves correctly from any CWD when invoked
# directly OR via lefthook (lefthook always cd's to repo root).
_REPO_ROOT = Path(__file__).resolve().parent.parent.parent
MOBILE = _REPO_ROOT / "apps" / "mobile" / "assets" / "metaphors.toml"
BACKEND = _REPO_ROOT / "services" / "backend" / "app" / "data" / "metaphors.toml"

# LSFin banned roots — matches `banned_terms_python.py` family with FR
# inflections enumerated. Case-insensitive substring match.
_BANNED_LSFIN: tuple[str, ...] = (
    "garanti",
    "garantie",
    "garantis",
    "optimal",
    "optimale",
    "optimaux",
    "parfait",
    "parfaite",
    "meilleur",
    "meilleure",
    "certain",
    "certaine",
    "assuré",
    "assurée",
    "sans risque",
)

# PII regexes — compiled at module import.
_PII_REGEXES: tuple[re.Pattern[str], ...] = (
    re.compile(r"[\w.+-]+@[\w-]+\.[\w.-]+"),       # email
    re.compile(r"\+?\d{10,15}"),                    # phone (E.164-ish)
    re.compile(r"CH\d{2}\s?\d{4}\s?\d{4}"),         # Swiss IBAN prefix
)


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _walk_metaphors(data: dict) -> list[tuple[str, str]]:
    """Yields (dotted_key, metaphor_value) tuples from the 3-level TOML."""
    out: list[tuple[str, str]] = []
    for archetype, cantons in data.items():
        if not isinstance(cantons, dict):
            continue
        for canton, events in cantons.items():
            if not isinstance(events, dict):
                continue
            for event, payload in events.items():
                if not isinstance(payload, dict):
                    continue
                m = payload.get("metaphor", "")
                if isinstance(m, str):
                    out.append((f"{archetype}.{canton}.{event}", m))
    return out


def scan_values(path: Path) -> list[str]:
    """Return a list of human-readable violation strings (empty on clean)."""
    violations: list[str] = []
    try:
        data = tomllib.loads(path.read_text(encoding="utf-8"))
    except tomllib.TOMLDecodeError as exc:
        return [f"{path}: TOML decode error — {exc}"]

    for dotted, metaphor in _walk_metaphors(data):
        lower = metaphor.lower()
        for banned in _BANNED_LSFIN:
            if banned in lower:
                violations.append(
                    f"{dotted}: LSFin banned term « {banned} » in metaphor"
                )
        for regex in _PII_REGEXES:
            if regex.search(metaphor):
                violations.append(f"{dotted}: PII pattern detected")
    return violations


def main(argv: list[str]) -> int:
    if not MOBILE.exists():
        print(f"ERROR: {MOBILE} not found", file=sys.stderr)
        return 1
    if not BACKEND.exists():
        print(f"ERROR: {BACKEND} not found", file=sys.stderr)
        return 1

    mobile_sha = _sha256(MOBILE)
    backend_sha = _sha256(BACKEND)
    if mobile_sha != backend_sha:
        print("ERROR: mobile + backend metaphors.toml diverged", file=sys.stderr)
        print(f"  mobile : {mobile_sha}", file=sys.stderr)
        print(f"  backend: {backend_sha}", file=sys.stderr)
        return 1

    if "--scan-values" in argv:
        violations = scan_values(MOBILE)
        if violations:
            for v in violations:
                print(f"ERROR: {v}", file=sys.stderr)
            return 1

    print(f"OK metaphor_parity: sha256 match ({mobile_sha[:12]}…)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
