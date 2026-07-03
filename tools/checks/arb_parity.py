#!/usr/bin/env python3
"""Validate that the six primary Flutter ARB files expose the same keyset."""

from __future__ import annotations

import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
ARB_DIR = ROOT / "apps" / "mobile" / "lib" / "l10n"
LOCALES = ("fr", "en", "de", "es", "it", "pt")


def _message_keys(path: Path) -> set[str]:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise SystemExit(f"ERROR: invalid ARB JSON in {path}: {exc}") from exc
    if not isinstance(data, dict):
        raise SystemExit(f"ERROR: ARB root must be an object: {path}")
    return {key for key in data if not key.startswith("@")}


def main() -> int:
    files = {locale: ARB_DIR / f"app_{locale}.arb" for locale in LOCALES}
    missing_files = [str(path) for path in files.values() if not path.is_file()]
    if missing_files:
        print("ERROR: missing ARB files:")
        for path in missing_files:
            print(f"  - {path}")
        return 1

    keysets = {locale: _message_keys(path) for locale, path in files.items()}
    reference_locale = "fr"
    reference = keysets[reference_locale]
    failed = False

    for locale in LOCALES:
        if locale == reference_locale:
            continue
        missing = sorted(reference - keysets[locale])
        extra = sorted(keysets[locale] - reference)
        if missing or extra:
            failed = True
            print(f"ERROR: app_{locale}.arb differs from app_fr.arb")
            if missing:
                print(f"  missing ({len(missing)}): {', '.join(missing[:40])}")
            if extra:
                print(f"  extra ({len(extra)}): {', '.join(extra[:40])}")

    if failed:
        return 1

    print(
        "ARB parity OK: "
        + ", ".join(f"app_{locale}.arb={len(keysets[locale])}" for locale in LOCALES)
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
