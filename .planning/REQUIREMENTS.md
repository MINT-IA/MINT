# Requirements: MINT v2.3 Simplification Radicale

**Defined:** 2026-04-09
**Core Value:** A user opens MINT and within 3 minutes receives a personalized, surprising insight about their financial situation that they couldn't have found elsewhere — then knows exactly what to do next.

**2 founding principles (apply to every requirement):**
1. **3-second no-finance-human test** — replaces all UI ship gates
2. **Chat EST l'app (chat-as-shell inversion)** — every destination screen is suspect

**Inputs:**
- `.planning/v2.3-handoff/HANDOFF.md`
- `.planning/v2.3-handoff/screenshots/WALKTHROUGH_NOTES.md`
- `docs/NAVIGATION_MAP_v2.2_REALITY.md`
- `docs/AESTHETIC_AUDIT_v2.2_BRUTAL.md`

## v1 Requirements

Requirements for v2.3 release. Each maps to roadmap phases.

### Navigation Architecture (NAV)

Clean the route graph. Make scope leaks and cycles impossible by construction, not by review.

- [ ] **NAV-01**: GoRouter routes are tagged with explicit scope (`public` / `onboarding` / `authenticated`) and the redirect guard enforces scope-based protection (not operation-based whitelist)
- [ ] **NAV-02**: ProfileDrawer is mounted only inside the authenticated scope; it is unreachable from any public or onboarding route
- [ ] **NAV-03**: Every onboarding-scope link to legal pages (CGU, politique de confidentialité) opens an inline public-scope screen, never the authenticated shell
- [ ] **NAV-04**: The route graph contains zero non-trivial cycles; the only legitimate bidirectional edges are explicitly whitelisted
- [ ] **NAV-05**: Every reachable route has at least one forward exit edge to `/coach/chat` (no dead-end widgets)
- [ ] **NAV-06**: All `Navigator.push` / `Navigator.of(context).push` legacy calls are removed in favor of `context.go` / `context.push` through GoRouter

### CI Mechanical Gates (GATE)

The 5 mechanical tests that would have caught the 4 P0 bugs before ship. Become permanent CI gates blocking merge.

- [ ] **GATE-01**: Cycle DFS test runs in CI on the route graph and fails the build on any non-whitelisted strongly-connected component
- [ ] **GATE-02**: Scope-leak test runs in CI and fails the build on any edge crossing from public/onboarding scope into authenticated scope
- [ ] **GATE-03**: Empty-state-with-payload test runs in CI and verifies that any screen receiving a navigation payload consumes it before short-circuiting to an empty state
- [ ] **GATE-04**: Guard-list snapshot test runs in CI and fails on any unreviewed change to the auth guard's protected scopes
- [ ] **GATE-05**: Doctrine-string lint runs in CI on every routed widget and flags banned terms (gamified completion %, level numbering exposed, social comparison, raw nLPD article references in user-facing copy)

### Radical Deletion (KILL)

Delete destination screens that fail the 3s test. Don't redesign them.

- [ ] **KILL-01**: `/onboarding/intent` screen is deleted; the conversation IS the diagnostic
- [ ] **KILL-02**: `CoachEmptyState` widget ("Faire mon diagnostic") is deleted; coach chat handles its own empty state by starting the conversation
- [ ] **KILL-03**: `/profile/consent` Centre de contrôle is deleted as a destination route; consent management becomes contextual
- [ ] **KILL-04**: Moi dashboard gamification (`0% — il manque...`, `+15%`, `+10%` badges) is deleted; replaced with neutral state language respecting anti-shame doctrine
- [ ] **KILL-05**: Account creation as a mandatory onboarding step is deleted; cloud sync becomes an optional flow the chat surfaces only when the user expresses intent for it
- [ ] **KILL-06**: Internal voice cursor naming (`N1 — Tranquille`, `N2 — Clair`, `N3 — Direct` radio buttons) is removed from any user-facing surface
- [ ] **KILL-07**: Explorer hub screens that exist purely as navigation destinations (without their own value moment) are removed from the navigation surface; underlying calculators remain reachable as drawers via the chat

### Chat-as-Shell (CHAT)

The chat becomes the entry, the distributor, the planner. Every former destination becomes a contextual drawer.

- [ ] **CHAT-01**: Cold start (post-landing) routes the user directly into `coach_chat_screen.dart` with a context-appropriate opener; there is no intent picker between landing and chat
- [ ] **CHAT-02**: The chat exposes a `summon` mechanism (bottom sheet / overlay) that opens contextual drawers (calculators, simulators, profile, document upload) on demand; drawers dismiss back to the conversation
- [ ] **CHAT-03**: Consent requests are asked inline in the chat at the moment the feature is invoked, one at a time, with one human sentence each — never as a standalone screen
- [ ] **CHAT-04**: Profile data entry happens through chat conversation, not through the deleted Moi dashboard form fields
- [ ] **CHAT-05**: Tone preference ("Doux / Direct / Non filtré") is asked once contextually inside the chat (not as an onboarding bottom sheet) and stored on `Profile.voiceCursorPreference`

### P0 Bug Repair (BUG)

Bugs that don't dissolve via deletion still need explicit mechanical fixes.

- [ ] **BUG-01**: Bug 2 infinite loop fixed at `coach_chat_screen.dart:1317` — chat consumes the navigation payload before any `_hasProfile` short-circuit; a freshly-registered or anonymous user lands on a working conversation, never on an empty state that loops back
- [ ] **BUG-02**: Bug 1 auth leak verified gone — deleted Centre de contrôle plus scope-based guards (NAV-01, NAV-02) make the leak impossible to reintroduce; integration test proves CGU link from a public scope cannot reach `/profile/*` `/home` `/explore/*`
- [ ] **BUG-03**: i18n diacritic regression on Centre de contrôle text path is rooted-out — `Donnees`, `necessaires`, `Execution`, `agregees`, `ameliorer`, `federale` etc. trace back to the encoding/font fallback bug and fix is applied wherever else it leaks
- [ ] **BUG-04**: "Ton de Mint" segmented control truncation is fixed — bottom sheet either drops subtitles or stacks vertically (whichever survives KILL/CHAT)

### Sober Visual (POLISH)

Visual polish comes last, on a sane base. No Aesop chase. Sober is the goal.

- [ ] **POLISH-01**: S0 Landing is rebuilt minimaliste — 1 promesse (≤2 lignes), 1 CTA, 1 footer légal; passes the 3s test
- [ ] **POLISH-02**: Coach chat surface inherits the breathing room freed by deletions — generous vertical rhythm, clear focal point per turn, no competing UI chrome
- [ ] **POLISH-03**: Banned visual fragments removed from surviving surfaces — 3D logo cube on signup (deleted with KILL-05), bordered gray ghost chips on intent (deleted with KILL-01), generic Material 3 admin styling on any drawer
- [ ] **POLISH-04**: Color/typography tokens audit — every surviving surface uses `MintColors.*` and Montserrat/Inter only, zero hardcoded `Color(0xFF...)`, zero remaining `Outfit` font references

### Creator Device Gate (DEVICE)

Gate 0 is non-negotiable. Tests green ≠ app functional.

- [ ] **DEVICE-01**: Every phase ships with creator-device annotated screenshots (iPhone, real TestFlight build) demonstrating the user reaches the value moment; PR cannot merge without them
- [ ] **DEVICE-02**: The full v2.3 onboarding flow (cold start → first coach turn) is walked end-to-end on device by Julien at the end of the milestone, with zero P0/P1 issues, before the v2.3 → staging promotion PR

## v2 Requirements

Deferred to future release.

### Voice & Personalization (defer to v2.4)

- **VOICE-01**: ACCESS-01 a11y partner sessions (3 live tests minimum)
- **VOICE-02**: Krippendorff α≥0.67 weighted ordinal validation of voice cursor spec (15-tester pool)
- **VOICE-03**: Reverse-Krippendorff classifier on coach generation (≥70% N4 classification)

### Performance (defer to v2.4)

- **PERF-01**: Galaxy A14 Android-in-CI automation (Firebase Test Lab investigation)
- **PERF-02**: Cold start, scroll FPS, MTC bloom timing as automated regression gates

## Out of Scope

Explicitly excluded for v2.3.

| Feature | Reason |
|---------|--------|
| Aesthetic perfection chase (Aesop / Things 3 / Arc references) | Audit is signal "pas ça", not target. Visual stays sober. Refonte fine = v2.4+. |
| New life events, calculators, or coach capabilities | Repair milestone, no additions |
| Backend changes beyond bug fixes | Coach service, voice cursor, MTC, regional voice, compliance guard work; intouchés |
| Re-introducing destination screens | Contradicts Principe #2 chat-as-shell |
| Multi-LLM routing | Phase 3 strategic roadmap |
| bLink production / cloud sync / B2B / money movement | Compliance + Phase 3+ |
| Refonte visuelle des écrans supprimés | On supprime, on ne refait pas |
| Touching surfaces unrelated to the 4 P0 + 7 deletions | Surgical milestone, no opportunistic refactors |

## Traceability

Each v1 requirement maps to exactly one phase.

| Requirement | Phase | Status |
|-------------|-------|--------|
| NAV-01 | Phase 1 | Pending |
| NAV-02 | Phase 1 | Pending |
| NAV-03 | Phase 4 | Pending |
| NAV-04 | Phase 4 | Pending |
| NAV-05 | Phase 4 | Pending |
| NAV-06 | Phase 4 | Pending |
| GATE-01 | Phase 1 | Pending |
| GATE-02 | Phase 1 | Pending |
| GATE-03 | Phase 1 | Pending |
| GATE-04 | Phase 1 | Pending |
| GATE-05 | Phase 1 | Pending |
| KILL-01 | Phase 2 | Pending |
| KILL-02 | Phase 2 | Pending |
| KILL-03 | Phase 2 | Pending |
| KILL-04 | Phase 2 | Pending |
| KILL-05 | Phase 2 | Pending |
| KILL-06 | Phase 2 | Pending |
| KILL-07 | Phase 2 | Pending |
| CHAT-01 | Phase 3 | Pending |
| CHAT-02 | Phase 3 | Pending |
| CHAT-03 | Phase 3 | Pending |
| CHAT-04 | Phase 3 | Pending |
| CHAT-05 | Phase 3 | Pending |
| BUG-01 | Phase 2 | Pending |
| BUG-02 | Phase 2 | Pending |
| BUG-03 | Phase 4 | Pending |
| BUG-04 | Phase 4 | Pending |
| POLISH-01 | Phase 5 | Pending |
| POLISH-02 | Phase 5 | Pending |
| POLISH-03 | Phase 5 | Pending |
| POLISH-04 | Phase 5 | Pending |
| DEVICE-01 | Phase 1 (recurring Gate 0 in Phases 1-5) | Pending |
| DEVICE-02 | Phase 6 | Pending |

**Coverage:**
- v1 requirements: 33 total (NAV 6, GATE 5, KILL 7, CHAT 5, BUG 4, POLISH 4, DEVICE 2)
- Mapped to phases: 33
- Unmapped: 0 ✓

---
*Requirements defined: 2026-04-09*
*Last updated: 2026-04-09 — traceability filled by gsd-roadmapper*
