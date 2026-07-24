#!/usr/bin/env python3
"""Idempotent create-or-update for the 2 MINT skill SKILL.md files.

Phase mint-data-architecture-v1-01 Plan 02 Task 2. Codex MEDIUM #2 closed :
NEVER aborts when the file/dir already exists. The marker block is rewritten in
place ; content outside the markers is preserved ; the file (and its parent
dir) is created if absent.

Targets :
  .claude/skills/mint-flutter-dev/SKILL.md
  .claude/skills/mint-backend-dev/SKILL.md

Usage : python3 tools/checks/create_or_update_mint_skills.py
Exit codes :
  0 — success (always, unless an I/O error makes write impossible)
  2 — argparse / I/O hard failure
"""

from __future__ import annotations

import sys
from pathlib import Path
from typing import Dict, Tuple

_MARKER_START = "<!-- mint-data-architecture-v1-01-canonical:start -->"
_MARKER_END = "<!-- mint-data-architecture-v1-01-canonical:end -->"

_REPO_ROOT = Path(__file__).resolve().parents[2]

# Minimal frontmatter + H1 skeleton used ONLY when the file does not yet exist.
_FLUTTER_SKELETON = """\
---
name: mint-flutter-dev
description: Flutter/Dart development for MINT mobile app. Use when creating screens, widgets, simulators, or fixing Flutter code in apps/mobile/. Enforces MintUI kit, GoRouter navigation, Provider state management, and project conventions.
compatibility: Requires Flutter SDK, Dart. Works in apps/mobile/ only.
metadata:
  author: mint-team
  version: "1.0"
---

# MINT Flutter Development

## Scope

You work exclusively in `apps/mobile/`. Never touch `services/backend/`.
"""

_BACKEND_SKELETON = """\
---
name: mint-backend-dev
description: Python/FastAPI backend development for MINT. Use when implementing rules_engine calculations, API endpoints, schemas, or fixing backend code in services/backend/. Enforces pure functions, Pydantic v2 schemas, pytest tests, and compliance guardrails.
compatibility: Requires Python 3.10+, FastAPI, pytest. Works in services/backend/ only.
metadata:
  author: mint-team
  version: "1.0"
---

# MINT Backend Development

## Scope

You work exclusively in `services/backend/`. Never touch `apps/mobile/`.
"""

# The body of the marker block — these are the bits Plan 02 Task 2 owns.
_FLUTTER_MARKER_BODY = """\
## Calc-engine ownership — L1 mobile-canonical (D-01..D-04, D-13)

`apps/mobile/lib/services/financial_core/` is the L1 chiffrer canonical home — \
single-number deterministic outputs from `(profile, constants_snapshot)`, \
offline-capable, mobile-canonical per Phase \
`mint-data-architecture-v1-01-calc-engine-canonical`. Boundary criterion = \
`services/backend/app/models/lucidity/_payload.py` discriminated type \
(`L1ChiffrePayload` → mobile ; `L2ComparePayload` / `L3EclairePayload` / \
`L4InvariantPayload` → backend).

### Stays mobile (per D-03 — UX-bound, no LSFin output)

- `apps/mobile/lib/services/financial_core/confidence_scorer.dart`
- `apps/mobile/lib/services/financial_core/bayesian_enricher.dart`
- `apps/mobile/lib/services/financial_core/coach_reasoner.dart`

### Migrates backend (per D-03 + D-11 — projection-class)

- `apps/mobile/lib/services/financial_core/monte_carlo_service.dart` (FIRST per D-11)
- `apps/mobile/lib/services/financial_core/tornado_sensitivity_service.dart`
- `apps/mobile/lib/services/financial_core/withdrawal_sequencing_service.dart`
- `apps/mobile/lib/services/financial_core/arbitrage_engine.dart`

### Regulatory vs MINT-doctrinal constants (D-13)

Regulatory constants (`plafond_3a`, AVS rentes, LIFD brackets, canton tax …) \
sync via Plan 04 build-time codegen → \
`apps/mobile/lib/services/financial_core/generated/regulatory_constants.g.dart`. \
MINT-doctrinal constants (`safeWithdrawalRate = 4%`, expected returns, \
mortality tables) stay Dart-side with their OWN version field, distinct from \
regulatory constants — two version trails, two audit chains.

### Bundle-size budget (D-14)

Validated 4509 gzip bytes / 95.6% headroom vs 100 KB ceiling per \
`.planning/phases/mint-data-architecture-v1-01-calc-engine-canonical/01-01-BUNDLE-SIZE-REPORT.md`. \
Re-litigate the bake-all-26-cantons posture only if compressed snapshot > 100 KB.

### UI Kit réel (beads -dj3)

Widgets réutilisables de `lib/widgets/premium/` : MintAmountField, \
MintPickerTile, MintChoiceCard, MintBottomSheet, MintDialog, MintEntrance, \
MintHeroNumber, MintCountUp, MintConfidenceNotice. Les anciens noms \
MintCard / MintSection / MintPremiumButton / MintGlassCard n'existent pas \
dans le code — ne pas les citer ni les recréer.
"""

_BACKEND_MARKER_BODY = """\
## Calc-engine ownership — L2-L4 backend-canonical (D-01..D-04, D-11)

`services/backend/app/services/` is the L2 comparer + L3 éclairer + \
L4 invariants canonical home — projection-class outputs with \
`constants_version_hash` audit trail, backend-canonical per Phase \
`mint-data-architecture-v1-01-calc-engine-canonical`. Boundary criterion = \
`services/backend/app/models/lucidity/_payload.py` discriminated type \
(L2ComparePayload / L3EclairePayload / L4InvariantPayload → backend ; \
L1ChiffrePayload → mobile).

### Regulatory source of truth

`services/backend/app/services/regulatory/registry.py` — `RegulatoryParameter` \
with `effective_from` / `effective_to` + active-version selection. Plan 03 \
exposes this via 2 endpoints :

- `GET /v1/regulatory/constants/version` — lightweight \
  `{active_version_hash, effective_from, last_updated}` for delta-check.
- `GET /v1/regulatory/constants/snapshot` — full 26-canton snapshot for the \
  Plan 04 build-time codegen consumer.

### Migration sequencing (D-CE-09 strangler-fig + D-CE-10 deprecation-shim)

Per-domain PRs (LPP, taxes, AVS, succession, divorce, frontalier …), each \
shipping :

1. Backend implementation of the migrated calc.
2. Mobile thin-client wrapper replacing the previous Dart implementation.
3. `@Deprecated` annotation on the old Dart class (1-release retention).
4. Parity test (mobile-wrapper vs backend output diff for a fixed scenario set).

Order : Monte Carlo + tornado sensitivity migrate FIRST (D-11 — highest LSFin \
audit risk, lowest UX coupling), then arbitrage engine, then withdrawal \
sequencing, then remaining L2+ calcs.

### Server-PRIMARY enforcement (D-CE-06)

All migrated L2-L4 calcs land in `services/backend/app/api/v1/endpoints/` with \
`Depends(get_profile_filled)` — the server is the PRIMARY enforcement layer \
for LSFin banned-terms + nLPD scrubbing ; mobile thin clients are presentation \
only, never re-implement calculator logic across the L1/L2 boundary.

### Modèles fiscaux canoniques (v2, calibrés ESTV — 2026-07)

`app/services/fiscal/cantonal_comparator.py` : estimate_income_tax(_parts), \
estimate_income_tax_on_rente, estimate_capital_withdrawal_tax (IFD exact + \
interpolation ESTV, marié par canton) ; fortune : wealth_tax_service. Ne \
jamais recomposer un taux plat ni un proxy heuristique — parités croisées \
gelées au centime (tools/fixtures/*.json). Modèle v1 supprimé.
"""


def _ensure_marker(content: str, body: str) -> str:
    """Return new content with the marker block guaranteed.

    - If markers exist : replace inner content (between them) with `body`.
    - If markers absent : append `\\n<marker_start>\\n<body>\\n<marker_end>\\n` at end.

    Content outside the markers is never touched.
    """
    start_idx = content.find(_MARKER_START)
    end_idx = content.find(_MARKER_END)

    if start_idx >= 0 and end_idx > start_idx:
        # Replace inner block (from after the start marker line to the end marker).
        # We rebuild as : prefix + start_marker + "\n" + body + "\n" + end_marker + suffix
        # where suffix is whatever was after the end marker (including its terminating
        # newline if present).
        prefix = content[:start_idx]
        suffix_pos = end_idx + len(_MARKER_END)
        suffix = content[suffix_pos:]
        return f"{prefix}{_MARKER_START}\n{body}\n{_MARKER_END}{suffix}"

    # Markers absent — append at end, separated by a blank line if file has content.
    sep = "" if content.endswith("\n\n") else ("\n" if content.endswith("\n") else "\n\n")
    return f"{content}{sep}{_MARKER_START}\n{body}\n{_MARKER_END}\n"


def _process_one(target: Path, skeleton: str, body: str) -> Tuple[bool, str]:
    """Create or update one SKILL.md file. Returns (changed, message)."""
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists():
        existing = target.read_text(encoding="utf-8")
    else:
        existing = skeleton

    updated = _ensure_marker(existing, body)
    if updated != (target.read_text(encoding="utf-8") if target.exists() else ""):
        target.write_text(updated, encoding="utf-8")
        return True, f"updated {target.relative_to(_REPO_ROOT)}"
    return False, f"unchanged {target.relative_to(_REPO_ROOT)}"


def main(argv: list = None) -> int:
    targets: Dict[str, Tuple[str, str]] = {
        "mint-flutter-dev": (_FLUTTER_SKELETON, _FLUTTER_MARKER_BODY),
        "mint-backend-dev": (_BACKEND_SKELETON, _BACKEND_MARKER_BODY),
    }

    changed_count = 0
    for name, (skeleton, body) in targets.items():
        target = _REPO_ROOT / ".claude" / "skills" / name / "SKILL.md"
        try:
            changed, msg = _process_one(target, skeleton, body)
        except OSError as exc:
            print(f"ERROR : {target} — {exc}", file=sys.stderr)
            return 2
        if changed:
            changed_count += 1
        print(msg)

    print(f"create_or_update_mint_skills : {changed_count}/2 files modified.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
