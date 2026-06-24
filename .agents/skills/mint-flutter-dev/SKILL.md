---
name: mint-flutter-dev
description: Flutter development for Mint mobile app. Use for any change under apps/mobile/.
---

# Mint Flutter Development

## Scope

Work only in `apps/mobile/` unless the user explicitly asks for a cross-layer
change. Do not edit backend code from this skill.

## Read First

- `AGENTS.md`
- `CLAUDE.md`
- `.agents/skills/mint-operating-gates/SKILL.md`
- `apps/mobile/lib/app.dart` for routing/auth redirects.
- `docs/data-flow.md` for profile persistence.
- `docs/calculator-graph.md` before touching financial outputs.

Run the relevant grep from `AGENTS.md` before changing code.

## Implementation Rules

- TDD first: failing test or failing runtime contract before production code.
- Use existing Provider/go_router patterns.
- User-facing strings go through ARB localization.
- No naked financial numbers.
- No new route without route metadata/checks.
- No fallback masking for impossible states.
- Feature flags or kill switches for new paths.

## Runtime Proof

For auth/onboarding/profile/delete/navigation changes, a passing widget test is
not enough. Add or run a simulator/runtime proof through Patrol, Maestro, or the
existing runtime debug tooling.

Use a rich persona when profile readiness matters:
`cadre_salarie_lpp_suisse_ready`.

## Minimum Verification

From `apps/mobile/`:

```bash
flutter analyze
flutter test <targeted tests>
```

For risky user-facing flows, also run the relevant simulator/Patrol/Maestro
gate from repo root.
