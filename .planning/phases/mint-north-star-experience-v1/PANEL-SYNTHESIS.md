# Mint North Star Experience v1 - Panel Synthesis

Date: 2026-06-13
Mode: read-only expert panel, no product code edited.

## Consensus

Mint should not present itself as a chat app. Mint should become a living Swiss financial lucidity dossier: it shows what changes for the user, what Mint knows, what Mint assumes, what is missing, where each fact lives, and what can be checked next.

The coach is a voice, explanation, routing, and enrichment layer over structured surfaces. It is not the shell, the source of truth, the calculator, or the only escape route.

## Expert Signals

- Product: the core promise is "what changes for you, what we know, what we assume, what to check next." Generic chat, catalogue exploration, achievements, score reveal, and broad centralisation promises should be demoted.
- UX research: first value must happen before account creation. Account means "save this dossier", not "unlock the product." Reset and restore must be visible, explicit, and testable.
- Design system: Mint should feel like a Swiss financial instrument, not a dashboard. One consequence, one next action, quiet evidence underneath. Use semantic surfaces rather than card buffet.
- Architecture: do not do a blind rewrite. Do a targeted core rebuild: typed data spine, single write pipeline, explicit account/cloud states, calculation ownership, route/flag governance.
- AI: surface-first, coach-as-layer. Deterministic state/calculators own truth; LLMs can detect intent, explain, ask missing questions, summarize, and route.
- Trust/security: every financial fact needs source, freshness, confidence, storage state, sync state, AI-sharing state, and delete consequence. Launch trust depends on evidence for auth, deletion semantics, payload disclosure, and Keychain restore behavior.

## Local Evidence

- Current route surface is oversized: `156` route declarations were observed in `apps/mobile/lib/app.dart`.
- Current screen surface is oversized: `122` Flutter screen files and `191` screen classes were observed under `apps/mobile/lib/screens`.
- Docs conflict: identity/design docs already say anti-chat and anti-cockpit, while older vision/docs still promote chat-first and many screens.
- `DataSpineSnapshot` already exists in `apps/mobile/lib/models/data_spine_snapshot.dart`; the next step is to harden it, not create a competing spine.
- Current onboarding/auth/reset/restore work is directionally correct, but it is only one slice of a larger state-spine problem.

## Decision

Design Mint as if rebuilding the product around the dossier/state spine. Implement with a strangler strategy: preserve reliable foundations, isolate the new spine behind flags, migrate flows one by one, and cut legacy surfaces only when reachable replacements are verified.
