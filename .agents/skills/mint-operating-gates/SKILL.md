---
name: mint-operating-gates
description: Mandatory operating gate for Mint auth, onboarding, privacy, runtime, release, and workflow cleanup work.
---

# Mint Operating Gates

## Rule

No user-facing Mint work is done until the relevant gate is named.

TestFlight is not a discovery tool. Local tests and simulator/runtime evidence
come first.

## Default Gate

For auth, onboarding, profile, privacy, deletion, navigation, or financial
surface work, prove this before merge:

1. The exact user flow is named.
2. The seeded persona is named, or the flow is explicitly empty-profile.
3. A failing unit/widget/provider/router/runtime contract exists first.
4. The fix changes the canonical path, not a fallback.
5. `flutter analyze` and targeted tests pass.
6. A simulator/runtime proof runs through the changed path.
7. The diff is read before commit.

## Critical Persona

Default rich persona: `cadre_salarie_lpp_suisse_ready`.

Minimum facts:

- Switzerland resident with canton.
- Salaried.
- Income, e.g. monthly/net or annual/gross.
- LPP affiliated.
- LPP insured salary or explicit unknown.
- LPP balance or explicit unknown.
- Age or birth year.
- Civil status.
- 3a status.
- Housing, LAMal, and base monthly costs.
- Cash/savings status.

This persona must be materially usable by `Aujourd'hui`, `Mon argent`,
`Coach`, and `Explorer`.

## Refuse

- New plan files for ordinary bug fixes.
- Broad rewrites without a failing gate.
- TestFlight as first proof.
- Any “done” claim without cited command output or runtime artifact.
- Deleting dirty worktrees or branches with unmerged work.

## External Baseline

Use these as June 2026 baseline standards:

- OWASP MASVS / MASTG for mobile security.
- OWASP Mobile Top 10 2024 for mobile risk classes.
- Apple account deletion, privacy, and HIG guidance for iOS UX/compliance.
- Flutter official unit/widget/integration testing docs for the test pyramid.
- Patrol for native E2E where widget tests cannot prove the path.
- Maestro for existing smoke/runtime flows.
- NIST SSDF and DORA principles for secure software and operational resilience.
