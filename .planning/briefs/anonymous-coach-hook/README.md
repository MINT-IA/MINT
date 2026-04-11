# Brief — Anonymous Coach Hook

**For:** A new GSD session that will run `/gsd-new-milestone` in a separate window.
**Goal:** This folder contains everything needed to start the milestone without any prior context.

## How to use this in the new GSD window

1. Open a fresh Claude Code session in `/Users/julienbattaglia/Desktop/MINT`
2. Start with this command:
   ```
   /gsd-new-milestone @.planning/briefs/anonymous-coach-hook/
   ```
3. GSD will read all files in this folder and use them as context.
4. The questioning phase will walk through `05-OPEN-QUESTIONS.md` decisions.
5. Once questioning is complete, GSD generates milestone + phases + plans automatically.

## Files in this brief

| File | Purpose |
|------|---------|
| `README.md` (this file) | Entry point for new session |
| `01-PRODUCT-BRIEF.md` | The why: problem, solution, user flow, scope, success criteria |
| `02-TECHNICAL-SPEC.md` | Architecture, database schema, Flutter/backend changes |
| `03-API-CONTRACT.md` | Exact endpoint signatures, request/response formats, cURL examples |
| `04-COPY-AND-UX.md` | Exact UI copy for every state, animations, i18n keys |
| `05-OPEN-QUESTIONS.md` | 12 decisions needed before implementation, with recommendations |

## Read order

1. `01-PRODUCT-BRIEF.md` — understand why we're doing this
2. `05-OPEN-QUESTIONS.md` — see what's undecided
3. `02-TECHNICAL-SPEC.md` — understand the technical shape
4. `03-API-CONTRACT.md` — reference during implementation
5. `04-COPY-AND-UX.md` — reference during implementation

## Context that the new session will NOT have

This brief was written at the end of a recovery session on 2026-04-11 that fixed several critical bugs in MINT:
- Coach AI server-key tier (wired but auth-gated — this milestone removes the auth gate for 3 messages)
- Auth fixes (logout purge, checkAuth at startup, visible login link)
- LPP calculations fix (ForecasterService was ignoring certificate overrides)
- 12 dead routes purged from navigation
- Test suite cleanup (deleted 40+ change-detector tests)

These fixes are in PR #306 (merged to dev) and PR #307 (merged to staging). TestFlight staging builds successfully. Backend is correctly deployed on Railway staging after fixing a misconfigured source branch.

**Known bugs NOT fixed during recovery session** (may affect this milestone's TestFlight testing):
- Keyboard stays at top of screen
- Back button from coach doesn't return to landing (no real stack)
- "Recevoir un lien magique" button text overflows
- No SMTP configured on Railway staging (magic link succeeds silently without sending email)

These are P2 bugs, not blockers for this milestone, but the user should know.

**Reference documents to consult if stuck:**
- `CLAUDE.md` — MINT identity, compliance, 18 life events
- `.planning/INCIDENT_DIAGNOSTIC_2026-04-10.md` — full audit of pre-recovery state
- `.planning/PROJECT.md` — current recovery project state
- `docs/CICD_ARCHITECTURE.md` — deployment architecture (BUT note: doc says TestFlight only on main; reality is push-to-staging also triggers TestFlight staging)
- `docs/VOICE_SYSTEM.md` — editorial voice rules

## What to NOT do in the new session

- Do not re-audit the app. The audit is done.
- Do not re-plan the recovery project. It's done.
- Do not touch any of the existing phases 1-8 in `.planning/phases/`. They are complete.
- Do not merge this milestone's PRs to main without testing in TestFlight staging first.
- Do not modify files outside the scope of this milestone without explicit approval.

## Definition of Done for this milestone

- [ ] Backend endpoint `/coach/chat/anonymous` deployed to Railway staging
- [ ] Backend endpoint `/auth/claim-anonymous` deployed
- [ ] Database migration applied
- [ ] Flutter code sends device_id header, routes to anonymous endpoint when no JWT
- [ ] UI displays message counter, soft paywall, hard paywall per `04-COPY-AND-UX.md`
- [ ] All 6 ARB files updated with new i18n keys
- [ ] Unit + integration tests pass
- [ ] TestFlight staging build succeeds
- [ ] Creator validates on iPhone: 3 messages → soft paywall → 4th blocked → signin → claim → authenticated chat works
- [ ] PR merged to dev, then staging, verified green
- [ ] Staging → main merge scheduled (not automatic, creator decides)
