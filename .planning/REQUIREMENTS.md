# Requirements: MINT v2.5 Transformation

**Defined:** 2026-04-12
**Core Value:** Un inconnu ouvre MINT, ressent quelque chose, tape sur une phrase, reçoit une réponse qui le surprend, crée un compte pour ne pas perdre ça, et revient chaque mois parce que MINT sait des choses que personne d'autre ne sait sur sa vie financière.

## v2.5 Requirements

Requirements for the Transformation milestone. Each maps to roadmap phases.

### Anonymous Hook & Auth Bridge

- [ ] **ANON-01**: Anonymous user can send messages to coach via rate-limited public endpoint (3 messages/session by IP)
- [ ] **ANON-02**: Anonymous user tapping a felt-state pill on intent screen arrives in coach chat with that intent as context
- [ ] **ANON-03**: After 3 value exchanges, MINT surfaces a natural auth gate ("Je peux garder tout ça en mémoire pour toi")
- [ ] **ANON-04**: Anonymous conversation history is transferred to persistent storage after user creates account (zero message loss)
- [ ] **ANON-05**: Backend anonymous endpoint uses "mode découverte" system prompt (respond to intent, don't ask for profile)
- [ ] **ANON-06**: Anonymous session is device-scoped (SecureStorage session token) to prevent rate-limit evasion

### Commitment Devices

- [ ] **CMIT-01**: Each Layer 4 insight includes an implementation intention (WHEN/WHERE/IF-THEN) that user can accept or edit
- [ ] **CMIT-02**: Accepted implementation intentions are persisted and surfaced as reminders via notification scheduler
- [ ] **CMIT-03**: Fresh-start anchor detector identifies landmark dates (birthday, month-1, year-start, 1-year anniversary) from user profile
- [ ] **CMIT-04**: Fresh-start anchors trigger ONE proactive MINT message at each landmark date
- [ ] **CMIT-05**: Pre-mortem prompt appears before irrevocable decisions (EPL, capital withdrawal, 3a closure) — "Imagine qu'on est en 2027 et que cette décision s'est mal passée"
- [ ] **CMIT-06**: Pre-mortem free-text response is stored in dossier and referenced in future related conversations

### Coach Intelligence

- [ ] **INTL-01**: Coach asks provenance questions naturally in conversation ("au fait, ce 3a, c'est qui qui te l'a proposé ?")
- [ ] **INTL-02**: Provenance tags are stored in backend and injected into CoachContext for future conversations
- [ ] **INTL-03**: Coach detects implicit earmarks in conversation ("ça c'est l'argent de mamie") and stores them via conversation_memory_service
- [ ] **INTL-04**: Earmark tags are respected in all future financial analyses (never aggregate earmarked monies into "patrimoine total")

### Couple Mode Dissymétrique

- [ ] **COUP-01**: User can declare "Je suis en couple" and enter what they know about their partner (estimated salary, LPP, age, 3a)
- [ ] **COUP-02**: MINT generates 5 questions to ask the partner based on gaps in the estimation ("Demande-lui son salaire assuré LPP")
- [ ] **COUP-03**: Couple projections use partner estimates with explicit confidence degradation (estimated data = lower confidence)
- [ ] **COUP-04**: Partner data is stored locally only (not shared) — privacy by architecture

### Living Timeline (3 tensions card → full timeline)

- [ ] **TIME-01**: Aujourd'hui screen shows 3 tension cards (past earned, present pulsing, future ghosted) as living placeholder
- [ ] **TIME-02**: Tension cards update dynamically based on user interactions, documents uploaded, and coach conversations
- [ ] **TIME-03**: Full living timeline replaces Aujourd'hui tab — single-screen center of gravity with nodes (tap to reveal)
- [ ] **TIME-04**: Documents, chat history, commitment intentions, couple data feed into timeline nodes
- [ ] **TIME-05**: Timeline shows earned achievements (past), active tensions (present, pulsing), and projected scenarios (future, ghosted)

## v2.6+ Requirements (Deferred)

### Premium & Monetisation

- **PREM-01**: RevenueCat integration with Apple IAP and Google Play Billing
- **PREM-02**: Paywall UI with gratuit/premium feature matrix
- **PREM-03**: 15 CHF/mois pricing with VZ anchor ("94% moins cher qu'un forfait VZ")
- **PREM-04**: Premium gates on document upload, 4-layer insights, implementation intentions, couple mode

### Long-term Directions

- **GRAD-01**: Graduation Protocol — concept mastery tracking, guided exercises after 3rd engagement
- **DOSS-01**: Dossier Federation — portable open-format dossier, user-owned
- **POLI-01**: Political Pocket — 5th layer collective_action (FRC, FINMA, parliamentary initiatives)

## Out of Scope

| Feature | Reason |
|---------|--------|
| Premium payments / Stripe / RevenueCat | Too early — zero external users yet. Deferred to v2.6. |
| Voice AI | Phase 3 roadmap (v2.7+) |
| Multi-LLM / model switching | Phase 3 roadmap (v2.7+) |
| Bidirectional couple mode | Both-partners-on-MINT is rare. Dissymmetric only for v2.5. |
| Push notifications infrastructure | Commitment devices degrade gracefully with local notifications. Push = v2.6. |
| Full Graduation Protocol | Direction long-terme, not a v2.5 deliverable. |
| Dossier Federation | Direction long-terme, not a v2.5 deliverable. |
| Political Pocket | Direction existentielle, not a v2.5 deliverable. |
| Budget tracking | Exists but not in scope for v2.5 improvements. |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| ANON-01 | — | Pending |
| ANON-02 | — | Pending |
| ANON-03 | — | Pending |
| ANON-04 | — | Pending |
| ANON-05 | — | Pending |
| ANON-06 | — | Pending |
| CMIT-01 | — | Pending |
| CMIT-02 | — | Pending |
| CMIT-03 | — | Pending |
| CMIT-04 | — | Pending |
| CMIT-05 | — | Pending |
| CMIT-06 | — | Pending |
| INTL-01 | — | Pending |
| INTL-02 | — | Pending |
| INTL-03 | — | Pending |
| INTL-04 | — | Pending |
| COUP-01 | — | Pending |
| COUP-02 | — | Pending |
| COUP-03 | — | Pending |
| COUP-04 | — | Pending |
| TIME-01 | — | Pending |
| TIME-02 | — | Pending |
| TIME-03 | — | Pending |
| TIME-04 | — | Pending |
| TIME-05 | — | Pending |

**Coverage:**
- v2.5 requirements: 25 total
- Mapped to phases: 0
- Unmapped: 25 ⚠️

---
*Requirements defined: 2026-04-12*
*Last updated: 2026-04-12 after milestone v2.5 start*
