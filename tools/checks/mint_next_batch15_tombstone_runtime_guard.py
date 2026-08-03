#!/usr/bin/env python3
"""Fail closed on the hidden Batch15 tombstone runtime contract."""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LAB = ROOT / "product/mint_next/batch7/design_lab"
MODEL_TEST = LAB / "test/multi_provider_amount_draft_test.dart"
RUNTIME_TEST = LAB / "test/design_lab_multi_provider_runtime_test.dart"
LOCALES = ("fr", "en", "de", "it", "es", "pt")

REQUIRED_TESTS = (
    "multiple tombstones remain independent and expose no retired values",
    "tombstones occupy capacity until finalize and purge retires every token",
    "stale remove callback cannot remove a restored generation",
    "empty removal skips a neighbouring tombstone for focus",
    "finalize skips preceding tombstones and focuses next rendered active row",
    "active field errors precede the first tombstone error",
    "tombstone survives safe-exit resume and reversible correction",
    "tombstone survives help Back and terminal leave removes its UI",
)


def validate_static() -> list[str]:
    errors: list[str] = []
    tests = MODEL_TEST.read_text(encoding="utf-8") + RUNTIME_TEST.read_text(encoding="utf-8")
    for name in REQUIRED_TESTS:
        if name not in tests:
            errors.append(f"required hostile test missing: {name}")

    key_sets: dict[str, set[str]] = {}
    for locale in LOCALES:
        path = LAB / f"lib/l10n/app_{locale}.arb"
        data = json.loads(path.read_text(encoding="utf-8"))
        key_sets[locale] = {key for key in data if not key.startswith("@")}
        for key in (
            "batch15TombstoneLabel",
            "batch15UndoRemoval",
            "batch15FinalizeRemoval",
            "batch15TombstonedAnnouncement",
            "batch15RestoredAnnouncement",
            "batch15ResolveTombstoneError",
        ):
            if key not in data:
                errors.append(f"{locale} missing {key}")
    if any(keys != key_sets["fr"] for keys in key_sets.values()):
        errors.append("Batch15 locale key parity drift")
    return errors


def main() -> int:
    errors = validate_static()
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1
    commands = (
        ["flutter", "analyze"],
        ["flutter", "test", "--no-pub", str(MODEL_TEST), str(RUNTIME_TEST)],
    )
    env = os.environ.copy()
    # A Git hook exports its own repository context. Flutter shells out to Git
    # to identify its SDK; inheriting these values makes the SDK look like MINT
    # and reports version 0.0.0-unknown.
    for name in (
        "GIT_DIR",
        "GIT_WORK_TREE",
        "GIT_INDEX_FILE",
        "GIT_OBJECT_DIRECTORY",
        "GIT_ALTERNATE_OBJECT_DIRECTORIES",
        "GIT_PREFIX",
    ):
        env.pop(name, None)
    for command in commands:
        result = subprocess.run(command, cwd=LAB, check=False, env=env)
        if result.returncode:
            return result.returncode
    print("OK mint_next_batch15_tombstone_runtime_guard: hidden tombstone cycle is mechanically covered.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
