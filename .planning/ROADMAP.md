# Roadmap: MINT v2.3 Simplification Radicale

**Milestone:** v2.3 Simplification Radicale
**Created:** 2026-04-09
**Granularity:** standard
**Phase numbering:** Reset to 1 (v2.2 phases archived to `.planning/milestones/v2.2-phases/`)
**Coverage:** 33/33 v1 requirements mapped

## Founding principles (apply to every phase)

1. **3-second no-finance-human test** — replaces all UI ship gates
2. **Chat EST l'app** — every destination screen is a drawer or is deleted
3. **Gate 0 (DEVICE-01)** — creator-device annotated screenshots per phase, non-skippable

## Priority order (immutable)

1. Architecture & nav clean → 2. Radical deletion → 3. Chat-as-shell rebuild → 4. Lingering bugs & i18n → 5. Sober visual → 6. End-to-end device walkthrough

## Phases

- [x] **Phase 1: Architectural foundation** — Scope-tagged routes, scope-based guard, 5 CI mechanical gates
- [ ] **Phase 2: Deletion spree** — Kill dead destinations + fix loop + verify auth leak gone
- [ ] **Phase 3: Chat-as-shell rebuild** — Chat becomes the entry, distributor, consent surface
- [ ] **Phase 4: Residual bugs & i18n hygiene** — Diacritics, Navigator.push cleanup, legal public pages, final nav verification
- [ ] **Phase 5: Sober visual polish** — Minimaliste S0, chat breathing room, token audit, banned fragments removed
- [ ] **Phase 6: End-to-end device walkthrough & ship gate** — Full E2E on iPhone, zero P0/P1, promotion-ready

## Phase Details

### Phase 1: Architectural foundation
**Plans:** 1 plan
**Goal**: Make scope leaks and nav regressions mechanically impossible before any deletion begins. This is the safety net for everything that follows.
**Depends on**: Nothing (first phase)
**Requirements**: NAV-01, NAV-02, GATE-01, GATE-02, GATE-03, GATE-04, GATE-05, DEVICE-01
**Success Criteria** (what must be TRUE):
  1. Every GoRoute carries an explicit scope tag (`public` / `onboarding` / `authenticated`); the redirect guard denies any unauthenticated access to `authenticated` scope routes
  2. ProfileDrawer is only mounted inside authenticated scope (unreachable from landing, register, onboarding, or any public/onboarding route)
  3. Running `flutter test` on the new nav suite fails the build on: any non-whitelisted route cycle, any cross-scope edge into `authenticated`, any screen ignoring a navigation payload, any unreviewed change to the auth guard snapshot, any banned doctrine string in routed widgets
  4. Creator-device screenshots show that a cold-started unauthenticated user cannot reach `/profile/*`, `/home`, or `/explore/*` through any tap path (including legal links from register)
**Plans**:
- [x] 01-01-PLAN.md — Scope-tagged routes + scope-based guard + 5 mechanical CI gates with would-have-fired fixtures

### Phase 2: Deletion spree
**Plans:** 1 plan
**Goal**: Remove ~70% of v2.2 destination surface area. Bug 1 and Bug 3 dissolve as side effect; Bug 2 is fixed mechanically at its file:line root cause.
**Depends on**: Phase 1 (safety net must exist before destructive changes)
**Requirements**: KILL-01, KILL-02, KILL-03, KILL-04, KILL-05, KILL-06, KILL-07, BUG-01, BUG-02
**Success Criteria** (what must be TRUE):
  1. `/onboarding/intent`, `CoachEmptyState`, `/profile/consent` as a destination, Moi-dashboard gamification, mandatory account creation, internal voice-cursor naming (`N1/N2/N3`), and Explorer-hub destination screens are all deleted from the codebase and route graph
  2. A freshly-registered or anonymous user entering `/coach/chat` with a `CoachEntryPayload` lands on a working conversation (no empty-state short-circuit at `coach_chat_screen.dart:1317`, no loop back to intent)
  3. An integration test proves the CGU / privacy link from register cannot reach any authenticated route (Bug 1 auth leak gone by construction)
  4. Creator-device Gate 0 screenshots demonstrate the shrunken surface: cold-start → chat, no intent picker, no Moi dashboard, no Centre de contrôle as destination
**Plans**:
- [x] 02-01-PLAN.md — 8-task deletion spree: KILL-01..07 + BUG-01 verify + BUG-02 tombstone test + golden snapshot update

### Phase 3: Chat-as-shell rebuild
**Plans:** 2 plans
**Goal**: The chat becomes the entry, the distributor, the consent surface, the data-capture surface, the tone-setter. Every former destination becomes a chat-summoned contextual drawer.
**Depends on**: Phase 2 (destinations must be gone before chat can absorb their responsibilities)
**Requirements**: CHAT-01, CHAT-02, CHAT-03, CHAT-04, CHAT-05
**Success Criteria** (what must be TRUE):
  1. Cold start (post-landing) routes the user directly into `coach_chat_screen.dart` with a context-appropriate opener — no intent picker between landing and chat
  2. A `summon` mechanism in the chat opens contextual drawers (calculators, simulators, profile, document upload) on demand and dismisses back to the conversation
  3. Consents are asked inline in the chat, one at a time, one human sentence each, at the moment the feature needs them — never as a standalone screen
  4. Profile data entry and tone preference (`voiceCursorPreference`) are captured through chat conversation (not through a form or an onboarding bottom sheet)
  5. Creator-device Gate 0 screenshots demonstrate a full cold-start → first insight flow that never leaves the chat surface except to open a drawer and return
**Plans**:
- [ ] 03-01-PLAN.md — Cold-start verification + drawer summon mechanism (CHAT-01, CHAT-02)
- [ ] 03-02-PLAN.md — Inline consent + data capture + tone preference (CHAT-03, CHAT-04, CHAT-05)
**UI hint**: yes

### Phase 4: Residual bugs & i18n hygiene
**Plans:** 1 plan
**Goal**: Close the bugs that did not dissolve via deletion and finish the nav cleanup that the deletion spree started.
**Depends on**: Phase 3
**Requirements**: BUG-03, BUG-04, NAV-03, NAV-04, NAV-05, NAV-06
**Success Criteria** (what must be TRUE):
  1. The diacritic encoding regression (`Donnees`, `necessaires`, `Execution`, `agregees`, `ameliorer`, `federale`) is root-caused and fixed wherever it leaks; no user-facing French string ships without its diacritics
  2. The "Ton de Mint" segmented-control truncation is fixed (or the surface is deleted by KILL/CHAT and the requirement is closed as dissolved)
  3. Legal pages (CGU, politique de confidentialité) are public-scope screens reachable inline from register via `context.push`, never through the authenticated shell
  4. Final route-graph verification: zero non-whitelisted cycles, every reachable route has at least one forward exit edge to `/coach/chat`, zero `Navigator.push` / `Navigator.of(context).push` legacy calls remain
  5. Creator-device Gate 0 screenshots confirm French diacritics render correctly on every surviving surface and every tone/consent moment behaves as specified
Plans:
- [x] 04-01-PLAN.md — Verify-and-fix: diacritics (BUG-03), TonChooser deletion (BUG-04), legal scope (NAV-03), cycle gate (NAV-04), reachability gate (NAV-05), Navigator.push cleanup (NAV-06)

### Phase 5: Sober visual polish
**Plans:** 1 plan
**Goal**: On a sane architecture, apply sober visual polish only to surviving surfaces. No Aesop chase. Sober is the goal.
**Depends on**: Phase 4
**Requirements**: POLISH-01, POLISH-02, POLISH-03, POLISH-04
**Success Criteria** (what must be TRUE):
  1. S0 Landing is rebuilt minimaliste: 1 promesse (≤2 lignes), 1 CTA, 1 legal footer — passes the 3-second no-finance-human test
  2. Coach chat surface inherits the breath freed by deletions — generous vertical rhythm, one clear focal point per turn, no competing chrome
  3. Banned visual fragments are removed from every surviving surface (3D logo cube, bordered gray ghost chips, generic Material 3 admin drawer styling)
  4. Token audit passes: every surviving surface uses `MintColors.*` and Montserrat/Inter only; zero hardcoded `Color(0xFF...)`, zero `Outfit` font references
  5. Creator-device Gate 0 screenshots demonstrate each polished surface and confirm the 3-second test passes on landing and chat
**Plans**:
- [x] 05-01-PLAN.md — Landing rebuild + chat breathing room + banned fragments removal + token audit (POLISH-01..04)
**UI hint**: yes

### Phase 6: End-to-end device walkthrough & ship gate
**Goal**: Julien walks the full v2.3 onboarding flow (cold start → first coach turn) end-to-end on a real iPhone TestFlight build with zero P0/P1 issues, clearing the v2.3 → staging promotion.
**Depends on**: Phase 5
**Requirements**: DEVICE-02
**Success Criteria** (what must be TRUE):
  1. A fresh TestFlight build is installed on iPhone; cold start → first coach value moment completes with zero P0 and zero P1 findings
  2. Annotated screenshots for every step of the flow are attached to the promotion PR
  3. All Phase 1 CI gates (cycle, scope-leak, empty-state-with-payload, guard snapshot, doctrine-string) remain green on `dev`
  4. Staging promotion PR is opened and ready for merge
**Plans**: TBD

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Architectural foundation | 3/3 | Complete | 2026-04-09 |
| 2. Deletion spree | 0/1 | Planned | - |
| 3. Chat-as-shell rebuild | 0/2 | Planned | - |
| 4. Residual bugs & i18n hygiene | 0/1 | Planned | - |
| 5. Sober visual polish | 0/1 | Planned | - |
| 6. End-to-end device walkthrough & ship gate | 0/0 | Not started | - |

## Coverage

- v1 requirements: 33 (NAV 6, GATE 5, KILL 7, CHAT 5, BUG 4, POLISH 4, DEVICE 2)
- Mapped: 33/33
- Unmapped: 0

Note: DEVICE-01 is formally owned by Phase 1 for traceability, but operates as a **recurring success criterion** ("Gate 0 — creator-device annotated screenshots, non-skippable") on every phase 1-5. DEVICE-02 is the final E2E ship gate owned by Phase 6.

---
*Roadmap created 2026-04-09 by gsd-roadmapper*
