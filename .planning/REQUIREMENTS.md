# Requirements: MINT Recovery

**Defined:** 2026-04-10
**Core Value:** A real user can cold-start MINT on their iPhone, talk to an AI coach, get correct financial insights, and navigate without dead ends.

## v1 Requirements

### Infrastructure (INFRA)

- [ ] **INFRA-01**: feature/cso-security-fixes merged to dev with CI green
- [ ] **INFRA-02**: dev merged to staging, TestFlight builds successfully
- [ ] **INFRA-03**: staging synced to main (resolve 674-commit divergence)

### Coach AI (COACH)

- [ ] **COACH-01**: User without BYOK key gets AI responses via server-side Anthropic key on Railway
- [ ] **COACH-02**: Coach responds with RAG-augmented, compliance-filtered, tool-calling responses end-to-end
- [ ] **COACH-03**: Coach works for ALL 18 life events — not just retirement framing
- [ ] **COACH-04**: Coach narrative endpoints return real generated content (not always used_fallback=True)

### Authentication (AUTH)

- [ ] **AUTH-01**: Login button is visible and discoverable on landing screen (not hidden behind long-press)
- [ ] **AUTH-02**: Logout calls AuthProvider.logout() and purges tokens, conversations, BYOK keys, profile data
- [ ] **AUTH-03**: Auth state persists across app restarts — checkAuth() called at startup, JWT restored from SecureStorage
- [ ] **AUTH-04**: Route guards work correctly — authenticated routes redirect to login when not logged in, persist after cold start

### Navigation (NAV)

- [ ] **NAV-01**: Zero dead routes — every context.go/push call resolves to an existing route in app.dart
- [ ] **NAV-02**: intent_router.dart — all 9 suggestedRoute values map to existing routes
- [ ] **NAV-03**: action_opportunity_detector.dart — all emitted routes exist (/documents/capture → /scan)
- [ ] **NAV-04**: progress_milestone_detector.dart — all emitted routes exist (/profile/privacy → /profile/privacy-control)
- [ ] **NAV-05**: hero_stat_resolver.dart — all emitted routes exist (/retirement/projection → /retraite)
- [ ] **NAV-06**: profile_drawer.dart — all navigation targets exist (remove or create /profile/consent, /profile/data-transparency)
- [ ] **NAV-07**: settings_sheet.dart — all navigation targets exist (remove or fix /profile/consent)
- [ ] **NAV-08**: screen_registry.dart — no entries for non-existent routes

### Financial Calculations (CALC)

- [ ] **CALC-01**: LPP projections correct when bonificationRateOverride combined with salaireAssureOverride (fix lpp_calculator.dart:67-123)
- [ ] **CALC-02**: Golden couple test 2a passes — Julien LPP rente = 33'892 CHF/an (not 45'954)
- [ ] **CALC-03**: Golden couple test 2b passes — Lauren LPP balance @65 = ~153'000 CHF (not 203'570)
- [ ] **CALC-04**: Golden couple test 4 passes — Taux remplacement couple = 65.5% (not 44.75%)
- [ ] **CALC-05**: All 19 golden couple tests pass (currently 16/19)

### Device Verification (GATE)

- [ ] **GATE-01**: Creator cold-starts app on iPhone via flutter run --release — landing screen loads
- [ ] **GATE-02**: Creator taps main CTA → coach opens, types message → gets AI response (not template)
- [ ] **GATE-03**: Creator navigates profile drawer — every menu item leads somewhere real
- [ ] **GATE-04**: Creator logs in, restarts app, state persists
- [ ] **GATE-05**: Creator logs out, all data purged, cannot access previous session

## v2 Requirements

### Data Integrity

- **DATA-01**: Minimal profile auto-creation (VD, 35yo) replaced with proper anonymous handling
- **DATA-02**: Feature flags persisted to SharedPreferences as fallback
- **DATA-03**: Orphan providers removed from MultiProvider

### Backend Hardening

- **BACK-01**: Reengagement consent persisted to database (not in-memory)
- **BACK-02**: Coach narrative endpoints generate real content
- **BACK-03**: Test coverage for untested endpoints (arbitrage, confidence, regulatory)

### UX Polish

- **UX-01**: Hardcoded French strings in tone chips extracted to ARB
- **UX-02**: Global keyboard dismiss policy implemented
- **UX-03**: safePop usage reduced — proper back stack for major flows

## Out of Scope

| Feature | Reason |
|---------|--------|
| New features (Monte Carlo UI, withdrawal sequencing, tornado charts) | Recovery only — no new capabilities |
| Onboarding flow redesign | Chat-first is design choice, not a bug |
| Tab navigation / home screen | Coach-as-shell is intentional architecture |
| i18n remaining ~120 strings | P2, not blocking core flows |
| Cloud conversation backup | P2, not blocking |
| Backend endpoint test coverage (26%) | P2, not blocking user-facing flows |
| SLM (on-device) integration | Works when model downloaded, not a regression |
| Regional voice identity | Enhancement, not a fix |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| INFRA-01 | Phase 1 | Pending |
| INFRA-02 | Phase 1 | Pending |
| INFRA-03 | Phase 1 | Pending |
| CALC-01 | Phase 2 | Pending |
| CALC-02 | Phase 2 | Pending |
| CALC-03 | Phase 2 | Pending |
| CALC-04 | Phase 2 | Pending |
| CALC-05 | Phase 2 | Pending |
| AUTH-01 | Phase 3 | Pending |
| AUTH-02 | Phase 3 | Pending |
| AUTH-03 | Phase 3 | Pending |
| AUTH-04 | Phase 3 | Pending |
| COACH-01 | Phase 4 | Pending |
| COACH-02 | Phase 4 | Pending |
| COACH-03 | Phase 4 | Pending |
| COACH-04 | Phase 4 | Pending |
| NAV-01 | Phase 5 | Pending |
| NAV-02 | Phase 5 | Pending |
| NAV-03 | Phase 5 | Pending |
| NAV-04 | Phase 5 | Pending |
| NAV-05 | Phase 5 | Pending |
| NAV-06 | Phase 6 | Pending |
| NAV-07 | Phase 6 | Pending |
| NAV-08 | Phase 6 | Pending |
| GATE-01 | Phase 7 | Pending |
| GATE-02 | Phase 7 | Pending |
| GATE-03 | Phase 7 | Pending |
| GATE-04 | Phase 7 | Pending |
| GATE-05 | Phase 7 | Pending |

**Coverage:**
- v1 requirements: 29 total
- Mapped to phases: 29
- Unmapped: 0 ✓

---
*Requirements defined: 2026-04-10*
*Last updated: 2026-04-10 after initialization*
