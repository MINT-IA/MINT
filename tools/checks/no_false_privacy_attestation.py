#!/usr/bin/env python3
"""GATE: forbid false "document never leaves phone" privacy attestations.

Audit état-des-lieux 2026-07 (T16-F02/F34/F36) found user- and release-facing
docs asserting on-device-only document handling while the canonical privacy
policy discloses a real transfer of the document to Anthropic Vision (US). That
is an internally-contradictory, materially false public/compliance attestation.

This check fails (exit 1) if any scanned attestation doc still carries an
absolute on-device promise WHILE the canonical policy discloses the US transfer.
Wire it into CI/lefthook so the false claim cannot be re-introduced.

Design (anti-façade): it is RED on the current tree by construction — it proves
the defect exists — and stays GREEN only once the docs tell the truth.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]

# Docs that make user/release-facing privacy attestations.
ATTESTATION_DOCS = [
    "LEGAL_RELEASE_CHECK.md",
    "docs/DATA_ACQUISITION_STRATEGY.md",
    "PRIVACY.md",
]

# The canonical honest disclosure of the US transfer (source of truth).
CANONICAL_POLICY = "docs/legal/privacy_policy_v2.3.0.md"
TRANSFER_MARKER = "transfer_us_anthropic"

# Absolute on-device promises that are false once a US transfer exists.
# Each pattern is matched case-insensitively on a per-line basis.
FALSE_PROMISE_PATTERNS = [
    r"document never leaves (the |your |ton )?phone",
    r"on-device ocr by default",
    r"aucun document ne (sera|transite|quitte)",
    r"(traitement|parsing).{0,40}(int[ée]gralement|integralement).{0,20}(sur )?ton appareil",
    r"toutes tes donn[ée]es personnelles restent sur ton appareil",
]

_COMPILED = [re.compile(p, re.IGNORECASE) for p in FALSE_PROMISE_PATTERNS]


def _read(rel: str) -> list[str] | None:
    path = REPO_ROOT / rel
    if not path.exists():
        return None
    return path.read_text(encoding="utf-8", errors="replace").splitlines()


def main() -> int:
    policy = _read(CANONICAL_POLICY)
    us_transfer_disclosed = bool(policy) and any(
        TRANSFER_MARKER in line for line in policy
    )

    hits: list[str] = []
    for rel in ATTESTATION_DOCS:
        lines = _read(rel)
        if lines is None:
            continue
        for i, line in enumerate(lines, start=1):
            for rx in _COMPILED:
                if rx.search(line):
                    hits.append(f"{rel}:{i}: {line.strip()}")
                    break

    if hits and us_transfer_disclosed:
        print(
            "FALSE PRIVACY ATTESTATION — these docs promise on-device-only "
            f"document handling, but {CANONICAL_POLICY} discloses a real US "
            f"transfer ({TRANSFER_MARKER}). Align the attestation with reality:\n"
        )
        for h in hits:
            print(f"  ✗ {h}")
        print(
            "\nFix: state that document OCR runs server-side via Anthropic "
            "Vision (US) with PII masking when possible (see "
            f"{CANONICAL_POLICY} §3.3), or remove the false claim."
        )
        return 1

    if hits and not us_transfer_disclosed:
        # No disclosed transfer => the on-device promise may be truthful. Warn only.
        print(
            "WARN: on-device promises present but no US-transfer disclosure "
            f"found in {CANONICAL_POLICY}; verify the promise is actually true."
        )
        return 0

    print("OK: no false on-device privacy attestation.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
