---
phase: 31
locked_by: D-03
created: 2026-04-19
owner: julien
status: locked
---

# Critical Journeys — 5 Named Transactions Allowlist (A6 Mitigation)

## Purpose

Over-instrumentation is the canonical Pitfall 7 in our Phase 31 research. If every GoRouter push, every HTTP call, every orchestrator step becomes a named Sentry transaction, the replay/trace panels drown in signal-free noise, spend quota on non-critical flows, and push the PII audit surface beyond what OBS-06 can reasonably mask (every new surface = a new `CustomPaint` risk). To stay honest to D-03 (hierarchical naming `mint.<surface>.<action>.<outcome>`) and D-04 ($160/mo hard ceiling), this document locks exactly **5 named transactions** — the ones that carry user-visible money/decision weight. Anything else that wants a canonical name must pass the deny-list gate below before landing.

## Allowlist — 5 critical journeys

The only 5 transaction names authorised in `apps/mobile/` and `services/backend/` code. Any of these names grep-ped in production code must resolve to exactly one start and one end boundary.

1. **`mint.journey.anonymous_onboarding`** — landing → felt-state → coach MSG1 → premier éclairage.
   - **Start trigger:** `/landing` route push (GoRouter observer emits `didPush`).
   - **End trigger:** `/onboarding/complete` redirect OR Firebase/BYOK auth success, whichever fires first.
   - **Why critical:** first 60 seconds of a user's relationship with MINT. Drop-off here kills everything downstream.

2. **`mint.journey.coach_turn`** — user message send → backend → LLM → tool calls → coach reply render.
   - **Start trigger:** `CoachOrchestrator.sendMessage` call.
   - **End trigger:** rendered response widget commit (first full AssistantBubble frame).
   - **Why critical:** the single most-hit money-carrying path in the app; 1 broken turn = 1 lost user.

3. **`mint.journey.document_upload`** — camera/PDF pick → Vision extract → DUR render → confirmation chip.
   - **Start trigger:** `DocumentScanScreen` mount.
   - **End trigger:** `ExtractionReviewSheet` dismiss (either confirm OR cancel).
   - **Why critical:** PII-heavy path (AVS, IBAN, certificats LPP). Any failure here leaves the user with a half-parsed document stuck in limbo.

4. **`mint.journey.scan_handoff_to_profile`** — confirm chip → ProfileProvider merge → breadcrumb `mint.coach.save_fact.success`.
   - **Start trigger:** extraction-confirm chip tap.
   - **End trigger:** ProfileProvider state change (verified via `mint.coach.save_fact.success` breadcrumb — literal locked by D-03, no `tool` intermediate token).
   - **Why critical:** the hand-off where "seen a document" becomes "known by MINT". Silent drop here = ghost data (cf. Wave E-prime findings: `save_fact` silent-drop was a P0).

5. **`mint.journey.tab_nav_core_loop`** — top-level 3-tab navigation (Aujourd'hui ↔ Coach ↔ Explorer).
   - **Start trigger:** any tab push on the Shell3Tabs.
   - **End trigger:** destination route build complete (first full frame of the destination tab body).
   - **Why critical:** the app-level "does MINT feel fast and trustworthy" signal. Slow or janky tab transitions compound every other user frustration.

## Deny-list

Any transaction whose `name` is NOT in the allowlist above requires:

1. A commit message prefixed `instrument: <journey_name>` (makes the addition grep-able).
2. A justification line in the PR description explaining why the journey deserves canonical transaction naming (vs a plain breadcrumb under the existing `mint.<surface>.<action>.<outcome>` scheme).
3. An update to this file bumping the allowlist to N+1 entries, or an ADR documenting the expansion.

Rationale: transaction names are the coarse signal Sentry rolls up by default in the performance dashboard. Every new one dilutes the signal and shifts quota.

### Examples of things that are NOT journeys (on purpose)

- Individual screen mounts outside the 5 flows above → breadcrumb via `SentryNavigatorObserver`, not a transaction.
- Individual HTTP calls → auto-trace span under the parent journey, not a standalone transaction.
- Feature flag refreshes → breadcrumb `mint.feature_flags.refresh.<outcome>`, not a transaction.
- ComplianceGuard pass/fail → breadcrumb `mint.compliance.guard.<outcome>`, not a transaction.

## Sign-off

signed: julien — pending (reviewed + locked at Phase 31-03 Task 1 ship time)

---

*Locked: 2026-04-19 per CONTEXT.md D-03 + RESEARCH.md §Pitfall 7 (over-instrumentation) + §D-06 (default-deny surface discipline).*
