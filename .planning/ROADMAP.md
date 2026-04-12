# Roadmap: MINT

## Milestones

- ✅ **v1.0 MVP** - Phases 1-8 (shipped 2026-03-20)
- ✅ **v2.0 Systeme Vivant** - Phases 1-6 (shipped 2026-04-07)
- ✅ **v2.1 Stabilisation** - Phase 7 (shipped 2026-04-07)
- ✅ **v2.4 Fondation** - Phases 9-12 (shipped 2026-04-12)
- 🚧 **v2.5 Transformation** - Phases 13-18 (in progress)

<details>
<summary>Previous milestones (v1.0, v2.0, v2.1, v2.4) -- see MILESTONES.md</summary>

All previous milestone phases (1-12) are documented in `.planning/MILESTONES.md` and the v2.4 section below.
Phase numbering continues from v2.4's last phase (Phase 12).

### v2.4 Fondation (Phases 9-12)

- [x] **Phase 9: Les tuyaux** - Backend infra hardening (2/2 plans, completed 2026-04-12)
- [x] **Phase 10: Les connexions** - Front-back wiring (1/1 plan, completed 2026-04-12)
- [x] **Phase 11: La navigation** - Shell architecture (2/2 plans, completed 2026-04-12)
- [ ] **Phase 12: La preuve** - End-to-end human validation on real iPhone

</details>

## Overview

MINT's infrastructure works (v2.4). Now it must become a product. v2.5 transforms MINT from working plumbing into a living experience: an anonymous stranger opens the app, feels something, gets a surprising response, creates an account to keep it, and returns monthly because MINT knows things nobody else knows about their financial life. Six phases deliver this in dependency order: anonymous hook first (user acquisition), commitment devices second (behavioral moat), coach intelligence third (relational depth), couple mode fourth (Swiss-specific value), then living timeline in two stages (the home screen that makes everything visible).

## Phases

**Phase Numbering:**
- Phases 13-18 belong to milestone v2.5 (continuing from v2.4 Phase 12)
- Decimal phases (13.1, 14.1): Urgent insertions if needed

- [x] **Phase 13: Anonymous Hook & Auth Bridge** - Anonymous user gets value in 20 seconds, converts without losing conversation (completed 2026-04-12)
- [x] **Phase 14: Commitment Devices** - Implementation intentions, fresh-start anchors, pre-mortem -- behavioral moat no competitor has (completed 2026-04-12)
- [x] **Phase 15: Coach Intelligence** - Provenance journal and implicit earmarking via conversation -- coach becomes relationally aware (completed 2026-04-12)
- [x] **Phase 16: Couple Mode Dissymetrique** - One partner enters estimates, gets 5 questions to ask, couple projections with honest confidence (completed 2026-04-12)
- [ ] **Phase 17: Living Timeline -- 3 Tensions** - Aujourd'hui shows 3 tension cards (past/present/future) as living placeholder
- [ ] **Phase 18: Living Timeline -- Full Timeline** - Single-screen center of gravity aggregating all previous phases into timeline nodes

## Phase Details

### Phase 13: Anonymous Hook & Auth Bridge
**Goal**: A stranger opens MINT, taps a felt-state pill, gets a premier eclairage that surprises them, and converts to an authenticated user without losing a single message
**Depends on**: Phase 12 (v2.4 foundation must be validated)
**Requirements**: ANON-01, ANON-02, ANON-03, ANON-04, ANON-05, ANON-06, LOOP-01 (partial)
**Success Criteria** (what must be TRUE):
  1. Anonymous user can send 3 messages to coach and receive meaningful responses without creating an account
  2. Tapping a felt-state pill on the intent screen opens coach chat with that intent as conversation context (not a blank chat)
  3. After the 3rd value exchange, MINT surfaces a natural auth prompt ("Je peux garder tout ca en memoire pour toi") -- not a wall, not a popup
  4. User who creates an account sees their entire anonymous conversation preserved in their chat history (zero message loss)
  5. A second anonymous session from the same device cannot bypass the 3-message rate limit (device-scoped session token in SecureStorage)
**Plans**: 4 plans

Plans:
- [x] 13-01-PLAN.md -- Backend anonymous chat endpoint with rate limiting and discovery system prompt
- [x] 13-02-PLAN.md -- Frontend anonymous chat screen, session service, and auth gate UX
- [x] 13-03-PLAN.md -- Conversation migration on auth and device verification
- [x] 13-04-PLAN.md -- Gap closure: eager message persistence to fix broken migration path

### Phase 14: Commitment Devices
**Goal**: MINT transforms insights into action -- every Layer 4 response includes a concrete implementation intention, landmark dates trigger proactive messages, and irrevocable decisions get a pre-mortem
**Depends on**: Phase 13 (requires authenticated users with persistent conversations)
**Requirements**: CMIT-01, CMIT-02, CMIT-03, CMIT-04, CMIT-05, CMIT-06, LOOP-01 (partial), LOOP-02 (partial)
**Success Criteria** (what must be TRUE):
  1. Coach response to a financial question includes an editable WHEN/WHERE/IF-THEN implementation intention that the user can accept, edit, or dismiss
  2. Accepted implementation intention triggers a local notification reminder at the scheduled time
  3. On a landmark date (birthday, month-1, year-start), user receives a single proactive MINT message anchored to their financial situation
  4. Before an irrevocable decision (EPL, capital withdrawal, 3a closure), coach surfaces a pre-mortem prompt and stores the user's response in the dossier
  5. Pre-mortem responses from past decisions are referenced when the user revisits related topics ("En mars tu avais dit craindre que...")
**Plans**: 3 plans

Plans:
- [x] 14-01-PLAN.md -- Backend: DB models, migrations, system prompt directives, internal tools, CoachContext injection
- [x] 14-02-PLAN.md -- Frontend: CommitmentCard widget, persistence endpoint, notification scheduling
- [x] 14-03-PLAN.md -- Fresh-start anchors: landmark detection, personalized messages, proactive notifications

### Phase 15: Coach Intelligence
**Goal**: Coach becomes relationally aware -- tracks who recommended what financial product and respects that users mentally separate their monies, without ever asking form-style questions
**Depends on**: Phase 14 (commitment devices provide the persistence patterns reused here)
**Requirements**: INTL-01, INTL-02, INTL-03, INTL-04, LOOP-01 (partial), LOOP-02 (partial)
**Success Criteria** (what must be TRUE):
  1. Coach naturally asks provenance questions in conversation flow ("au fait, ce 3a, c'est qui qui te l'a propose ?") -- not as a form, not as interrogation
  2. In a subsequent conversation, coach references stored provenance ("le 3a que ton banquier t'a propose chez UBS...") without the user having to repeat it
  3. When user mentions money with relational meaning ("l'argent de mamie"), coach stores an earmark tag and never aggregates that money into generic "patrimoine total"
  4. Financial analyses and projections respect earmark boundaries -- earmarked funds appear separately, not merged
**Plans**: 2 plans

Plans:
- [x] 15-01-PLAN.md -- Backend: DB models, migrations, system prompt directives, internal tools, CoachContext memory injection
- [x] 15-02-PLAN.md -- Integration tests, round-trip verification, full suite validation

### Phase 16: Couple Mode Dissymetrique
**Goal**: One partner uses MINT alone and gets couple-aware projections using estimates of their partner's situation -- private, honest about uncertainty, and actionable via "5 questions to ask"
**Depends on**: Phase 15 (provenance infrastructure enriches couple context; coach intelligence enables relational partner data)
**Requirements**: COUP-01, COUP-02, COUP-03, COUP-04
**Success Criteria** (what must be TRUE):
  1. User can declare "Je suis en couple" and enter estimated partner data (salary, LPP, age, 3a) via coach conversation or dedicated entry
  2. MINT generates 5 specific questions for the user to ask their partner, based on gaps in the estimation ("Demande-lui son salaire assure LPP")
  3. Couple projections (AVS married cap, combined tax, combined mortgage capacity) use partner estimates with visibly degraded confidence scores
  4. Partner data is stored locally only -- never sent to backend, never visible in CoachContext sent to LLM
**Plans**: 2 plans

Plans:
- [x] 16-01-PLAN.md -- Backend: save_partner_estimate/update_partner_estimate internal tools, system prompt directive, ack-only handlers
- [x] 16-02-PLAN.md -- Flutter: PartnerEstimateService (SecureStorage), CoupleQuestionGenerator, tool call interception, couple projection confidence degradation

### Phase 17: Living Timeline -- 3 Tensions
**Goal**: Aujourd'hui tab comes alive with 3 tension cards that reflect the user's actual financial state -- past earned, present pulsing, future ghosted -- replacing the static landing screen
**Depends on**: Phase 14 (commitment devices feed tension cards), Phase 15 (provenance/earmarks feed context)
**Requirements**: TIME-01, TIME-02, LOOP-03 (partial)
**Success Criteria** (what must be TRUE):
  1. Aujourd'hui screen shows exactly 3 tension cards: one earned (past achievement), one pulsing (active tension), one ghosted (future projection)
  2. Tension cards update dynamically when user uploads a document, completes a coach conversation, or accepts a commitment intention -- not static, not hardcoded
**Plans**: TBD
**UI hint**: yes

Plans:
- [ ] 17-01: TBD

### Phase 18: Living Timeline -- Full Timeline
**Goal**: Aujourd'hui becomes a single-screen center of gravity -- a living timeline with tappable nodes that aggregates documents, conversations, commitments, couple data, and projections into one coherent view
**Depends on**: Phase 16 (couple data), Phase 17 (3-tensions foundation)
**Requirements**: TIME-03, TIME-04, TIME-05, LOOP-03 (partial)
**Success Criteria** (what must be TRUE):
  1. Aujourd'hui tab shows a living timeline replacing the 3-tensions placeholder, with tappable nodes organized by past/present/future
  2. Documents, chat history, accepted implementation intentions, and couple estimates each appear as distinct node types on the timeline
  3. Past nodes show earned achievements (completed actions, uploaded documents), present nodes pulse with active tensions, future nodes appear ghosted with projected scenarios
  4. Timeline renders smoothly on older iPhones (no jank on scroll, lazy-loaded nodes)
**Plans**: TBD
**UI hint**: yes

Plans:
- [ ] 18-01: TBD
- [ ] 18-02: TBD

## Progress

**Execution Order:**
Phases execute sequentially: 13 -> 14 -> 15 -> 16 -> 17 -> 18
Each phase must pass device gate before the next begins.

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 13. Anonymous Hook & Auth Bridge | v2.5 | 4/4 | Complete    | 2026-04-12 |
| 14. Commitment Devices | v2.5 | 3/3 | Complete    | 2026-04-12 |
| 15. Coach Intelligence | v2.5 | 2/2 | Complete    | 2026-04-12 |
| 16. Couple Mode Dissymetrique | v2.5 | 2/2 | Complete    | 2026-04-12 |
| 17. Living Timeline -- 3 Tensions | v2.5 | 0/TBD | Not started | - |
| 18. Living Timeline -- Full Timeline | v2.5 | 0/TBD | Not started | - |

---
*Roadmap created: 2026-04-12*
*Last updated: 2026-04-12*
