# Architecture Patterns — v2.5 Transformation

**Domain:** Feature integration into existing Flutter + FastAPI app
**Researched:** 2026-04-12
**Scope:** How 6 new capabilities (anonymous flow, commitment devices, couple mode, coach provenance, premium gate, living timeline) integrate with existing GoRouter/Provider/FastAPI architecture.

---

## Existing Architecture Inventory (Integration-Relevant)

### Router (GoRouter)
- **Scope model**: `ScopedGoRoute` with `RouteScope.{public, onboarding, authenticated}` — fail-closed (default = authenticated)
- **Auth guard**: Top-level `redirect` reads `AuthProvider.isLoggedIn`, redirects unauthenticated to `/auth/register?redirect=...`
- **Shell**: `StatefulShellRoute.indexedStack` with 3 branches (Home, Coach, Explorer) inside `MintShell`
- **Anonymous entry**: `/` routes to `AnonymousIntentScreen` when `!isLoggedIn`, `LandingScreen` when logged in
- **Key constraint**: Anonymous users currently navigate to `/coach/chat?prompt=...` which sits INSIDE the `StatefulShellRoute` (authenticated scope) — this is a blocker for anonymous chat

### Auth (AuthProvider + backend JWT)
- **Backend**: `get_current_user()` returns `Optional[User]` — already supports `None` for anonymous
- **Backend**: `require_current_user()` raises 401 if no user — used on `/coach/chat`
- **Flutter**: `AuthProvider` has `_migrateLocalDataIfNeeded()` — already pushes wizard answers to backend on login via `ApiService.claimLocalData()`
- **Conversation isolation**: `ConversationStore.setCurrentUserId()` prefixes keys per user

### Coach Chat
- **Backend endpoint**: `POST /api/v1/coach/chat` requires `require_current_user`
- **Agent loop**: system prompt + tools + RAG retrieval + compliance guard
- **Tools**: `ToolCategory.{NAVIGATE, READ, WRITE, SEARCH}` — WRITE tools include `set_goal`, `mark_step_completed`, `save_insight`
- **Internal tools**: `retrieve_memories`, `get_budget_status`, `get_retirement_projection` — backend-only, never forwarded to Flutter
- **Rate limiting**: slowapi `@limiter.limit("30/minute")` per IP

### Data Layer
- **CoachProfile**: Built from wizard answers, lives in `CoachProfileProvider` (SharedPreferences + backend sync)
- **BiographyRepository**: Encrypted SQLite (sqflite_sqlcipher), stores `BiographyFact` with `FactType`, `FactSource`, `fieldPath`
- **ConversationStore**: SharedPreferences-based, max 20 conversations, user-scoped keys
- **CoachMemoryService**: Local insight persistence

### Subscription
- **4 tiers**: `free`, `starter`, `premium`, `couplePlus`
- **TierFeatureMatrix**: 13 features gated by tier — `coachLlm` requires `premium+`
- **IAP products**: Apple IAP identifiers defined (`ch.mint.{tier}.{period}`)
- **Billing backend**: Stripe checkout + Apple IAP verification endpoints exist
- **SubscriptionProvider**: Reactive wrapper, `isPaid` / `hasAccess(feature)` API

### Household (Couple)
- **HouseholdProvider**: `invitePartner(email)`, `acceptInvitation(code)`, `partner` getter
- **Backend**: `household_service.py` with invite/accept/revoke/transfer/dissolve
- **Current model**: Invitation-based, symmetric — both partners need accounts

---

## Integration Architecture per Feature

### 1. Anonymous → Auth Conversion

**Problem**: AnonymousIntentScreen navigates to `/coach/chat` which requires auth. Backend endpoint requires `require_current_user`.

**Architecture**:

```
                    AnonymousIntentScreen
                           |
                     pill tap / free text
                           |
                    POST /api/v1/coach/anonymous
                    (new endpoint, no auth required)
                    IP rate-limited: 3 turns/session, 10/day
                           |
                    AnonymousChatScreen (new)
                    (simplified chat, no shell/tabs)
                    stores messages in ephemeral local state
                           |
                    after 3 turns → conversion CTA
                           |
                    /auth/register?redirect=/coach/chat
                           |
                    AuthProvider.register() →
                    _migrateAnonymousConversation() (new)
                    transfers ephemeral messages to ConversationStore
```

**New Components**:

| Component | Layer | Type | Purpose |
|-----------|-------|------|---------|
| `AnonymousChatScreen` | Flutter | Screen | Simplified chat without shell, 3-turn limit |
| `anonymous_chat.py` | Backend | Endpoint | `POST /api/v1/coach/anonymous` — no auth, IP rate-limited |
| `AnonymousSessionStore` | Flutter | Service | Ephemeral in-memory conversation buffer (not persisted) |
| `RouteScope.anonymous` | Flutter | Enum value | New scope: accessible without auth, limited features |

**Modified Components**:

| Component | Change |
|-----------|--------|
| `route_scope.dart` | Add `RouteScope.anonymous` |
| `app.dart` redirect | Handle `anonymous` scope — allow access, no redirect |
| `app.dart` routes | Add `/coach/anonymous` route with `RouteScope.anonymous` |
| `auth_provider.dart` | Add `_migrateAnonymousConversation()` called post-register/login |
| `coach_chat.py` | Extract shared logic into `_handle_chat_turn()` reusable by both endpoints |
| `rate_limit.py` | Add stricter anonymous limits (3 turns/session via session cookie, 10/day via IP) |

**Data Flow**:
```
Anonymous: pill text → POST /anonymous (IP key) → Claude (reduced tools: READ only, no WRITE) → response
Auth:      register → _migrateAnonymousConversation() → ConversationStore.save() → full /coach/chat
```

**Key Decision**: Anonymous chat gets a SEPARATE endpoint, not a flag on the existing one. Reason: different auth dependency (`get_current_user` vs none), different rate limits, different tool set (read-only), different compliance context. Mixing them in one endpoint creates security surface.

### 2. Commitment Devices (Implementation Intentions, Fresh-Start Anchors, Pre-Mortem)

**Problem**: These are behavioral nudges that need to be created during coach conversations, persisted, and surfaced at the right time.

**Architecture**:

```
Coach conversation
    |
    LLM decides to set an intention → tool_use: set_implementation_intention
    |
    Backend saves to user's commitment_devices table
    |
    WHEN trigger fires (date, app open on fresh-start, pre-action) →
    CommitmentDeviceService checks pending devices →
    surfaces via coach greeting or home screen card
```

**New Components**:

| Component | Layer | Type | Purpose |
|-----------|-------|------|---------|
| `commitment_device.py` | Backend | Model | SQLAlchemy model: `{id, user_id, type, trigger_condition, action_plan, if_then_rule, created_at, status, next_fire_at}` |
| `commitment_device_service.py` | Backend | Service | CRUD + trigger evaluation + next-fire computation |
| `set_implementation_intention` | Backend | Coach Tool | New WRITE tool: `{when, where, if_obstacle, then_action, review_date}` |
| `set_fresh_start_anchor` | Backend | Coach Tool | New WRITE tool: `{anchor_date, commitment, reason}` |
| `set_pre_mortem` | Backend | Coach Tool | New WRITE tool: `{goal, failure_scenarios[], mitigations[]}` |
| `CommitmentDeviceProvider` | Flutter | Provider | Fetches pending devices, surfaces in UI |
| `commitment_card.dart` | Flutter | Widget | Home screen card for due commitment devices |

**Modified Components**:

| Component | Change |
|-----------|--------|
| `coach_tools.py` | Add 3 new WRITE tools to `COACH_TOOLS` list |
| `claude_coach_service.py` | Add commitment device instructions to system prompt |
| `coach_chat.py` | Handle new tool execution in agent loop |
| `landing_screen.dart` | Add commitment device card section |
| `LandingScreen` / Home tab | Query `CommitmentDeviceProvider` for pending devices |

**Data Model**:
```sql
CREATE TABLE commitment_devices (
    id UUID PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    type VARCHAR(30),  -- 'implementation_intention' | 'fresh_start' | 'pre_mortem'
    trigger_json JSONB,  -- {when, where, if_obstacle, then_action} or {anchor_date, ...}
    status VARCHAR(20),  -- 'active' | 'completed' | 'expired' | 'dismissed'
    next_fire_at TIMESTAMP,
    created_at TIMESTAMP,
    completed_at TIMESTAMP NULL
);
```

### 3. Mode Couple Dissymetrique

**Problem**: Current `HouseholdProvider` assumes symmetric model (both partners have accounts). Dissymmetric mode means ONE partner opens MINT and answers questions ABOUT the other.

**Architecture**:

```
Coach asks about partner → tool_use: ask_user_input (partner data fields)
    |
    User answers in chat → data stored in CoachProfile.partnerEstimate
    |
    financial_core calculators receive both profiles
    |
    Projections show couple view (married AVS cap, combined mortgage capacity, etc.)
```

**New Components**:

| Component | Layer | Type | Purpose |
|-----------|-------|------|---------|
| `PartnerEstimate` | Flutter | Model | `{age, income, canton, lppAvoir, lppSalaireAssure, p3aCapital, archetype}` |
| `partner_estimate_service.dart` | Flutter | Service | Persist/load partner estimates from SharedPreferences |
| `CoupleProjectionService` | Flutter | Service | Wraps financial_core calculators with couple logic |

**Modified Components**:

| Component | Change |
|-----------|--------|
| `coach_profile.dart` (model) | Add `PartnerEstimate? partnerEstimate` field |
| `coach_profile_provider.dart` | Add `updatePartnerEstimate()` method |
| `coach_context_builder.py` | Add partner fields to `CoachContext` |
| `claude_coach_service.py` | System prompt: couple awareness, dissymmetric mode instructions |
| `coach_tools.py` | Add `capture_partner_data` tool for structured partner data collection |
| `avs_calculator.dart` | Already has `computeCouple()` — wire partner data in |
| `lpp_calculator.dart` | Add couple projection method |
| `tax_calculator.dart` | Add couple tax estimation |

**Key Decision**: Partner data lives in `CoachProfile` as an estimate, NOT in `HouseholdProvider`. Reason: dissymmetric mode means only one person has MINT. The existing household model is for when BOTH partners have accounts (Couple+ tier). These are two different concepts:
- `CoachProfile.partnerEstimate` = "what I know about my partner" (always available)
- `HouseholdProvider` = "my partner also has MINT" (Couple+ tier only)

### 4. Coach Provenance Tracking (Journal via Conversation)

**Problem**: MINT learns about the user's relationship to money through conversation. "Grandma's money", "the 3a from Uncle Patrick" — these mental earmarks need to be captured and recalled.

**Architecture**:

```
User says something revealing → LLM detects provenance signal
    |
    tool_use: save_provenance_tag {asset, label, emotional_context, source_conversation_id}
    |
    Backend stores in provenance_tags table
    |
    Next conversation → retrieve_memories includes provenance context
    |
    Coach references: "ton 3a chez Patrick" instead of "ton pilier 3a"
```

**New Components**:

| Component | Layer | Type | Purpose |
|-----------|-------|------|---------|
| `provenance_tag.py` | Backend | Model | `{id, user_id, asset_type, label, emotional_context, source_message, created_at}` |
| `provenance_service.py` | Backend | Service | CRUD + retrieval for coach context injection |
| `save_provenance_tag` | Backend | Coach Tool | New WRITE tool (internal — backend-only execution, never forwarded to Flutter) |

**Modified Components**:

| Component | Change |
|-----------|--------|
| `coach_tools.py` | Add `save_provenance_tag` to COACH_TOOLS + INTERNAL_TOOL_NAMES |
| `coach_context_builder.py` | Inject provenance tags into `memory_block` |
| `claude_coach_service.py` | System prompt: provenance awareness, non-fungible money instructions |
| `coach_chat.py` | Handle `save_provenance_tag` execution in internal tool loop |

**Key Decision**: Provenance is a backend-only concept. The Flutter app never sees raw provenance tags. They flow into the coach's context window as part of `memory_block`, and the LLM uses them naturally. No new Flutter components needed.

### 5. Premium Gate Wiring

**Problem**: `TierFeatureMatrix` exists with 13 features and 4 tiers, but the gate enforcement in the UI is inconsistent. Need clear free/premium boundary.

**Architecture**:

```
User taps gated feature
    |
    Widget checks context.watch<SubscriptionProvider>().hasAccess(feature)
    |
    if no access → PremiumGateSheet (bottom sheet with value prop + CTA)
    |
    CTA → SubscriptionProvider.upgrade() → Apple IAP / Stripe flow
    |
    Success → SubscriptionProvider.refreshFromBackend() → UI unlocks
```

**New Components**:

| Component | Layer | Type | Purpose |
|-----------|-------|------|---------|
| `PremiumGateSheet` | Flutter | Widget | Bottom sheet: what you get, price, CTA — replaces scattered gate UIs |
| `PremiumGateWrapper` | Flutter | Widget | Declarative wrapper: `PremiumGateWrapper(feature: .coachLlm, child: ...)` |
| `FreeTrialBanner` | Flutter | Widget | Persistent banner showing trial days remaining |

**Modified Components**:

| Component | Change |
|-----------|--------|
| `coach_chat_screen.dart` | Wrap LLM chat behind `PremiumGateWrapper(feature: .coachLlm)` |
| `subscription_service.dart` | Wire actual RevenueCat/StoreKit purchase flow (currently mock) |
| `billing.py` | Already has Stripe + Apple verification — verify it works end-to-end |
| `landing_screen.dart` | Add `FreeTrialBanner` when trial active |
| Multiple screens | Add `PremiumGateWrapper` around premium features |

**Key Decision**: Single `PremiumGateSheet` component for ALL gates. No per-feature paywall screens. The sheet receives `CoachFeature` and renders the appropriate value proposition. Consistency + less code.

**Free vs Premium Boundary** (from existing `TierFeatureMatrix`):

| Feature | Free | Starter | Premium |
|---------|------|---------|---------|
| Anonymous chat (3 turns) | YES | YES | YES |
| Premier eclairage | YES | YES | YES |
| Coach LLM (full) | NO | NO | YES |
| Score evolution | NO | NO | YES |
| Export PDF | NO | NO | YES |
| Monte Carlo | NO | NO | YES |
| Scenarios et-si | NO | NO | YES |
| Dashboard | NO | YES | YES |
| Forecast | NO | YES | YES |
| Alertes proactives | NO | YES | YES |

### 6. Living Timeline (Tension-Based Home Screen)

**Problem**: Current `LandingScreen` is static. Need a dynamic home that shows "what matters now" based on the user's dossier.

**Architecture**:

```
User opens Home tab
    |
    TimelineProvider.loadTensions()
    |
    Queries: CommitmentDeviceProvider (pending devices)
           + BiographyProvider (stale facts)
           + CoachProfileProvider (profile completeness)
           + SubscriptionProvider (trial status)
           + Backend: /api/v1/tensions (new endpoint)
    |
    Renders: ordered list of TensionCard widgets
    |
    Each card has a CTA → routes to relevant screen or opens coach with prompt
```

**New Components**:

| Component | Layer | Type | Purpose |
|-----------|-------|------|---------|
| `TimelineProvider` | Flutter | Provider | Aggregates tensions from multiple sources, sorts by priority |
| `TensionCard` | Flutter | Widget | Generic card: icon + headline + body + CTA |
| `tensions.py` | Backend | Endpoint | `GET /api/v1/tensions` — returns personalized tension list |
| `tension_engine.py` | Backend | Service | Computes tensions from user profile, deadlines, stale data |

**Modified Components**:

| Component | Change |
|-----------|--------|
| `landing_screen.dart` | Replace static content with `TimelineProvider`-driven card list |
| `app.dart` | Register `TimelineProvider` in provider tree |

**Tension Types** (priority ordered):
1. **Urgent deadline**: 3a deadline approaching, tax filing, contract expiry
2. **Commitment due**: Implementation intention trigger fired
3. **Stale data**: Biography facts needing refresh (BiographyRefreshDetector already exists)
4. **Profile gap**: Missing data that blocks a projection
5. **Insight available**: New insight from recent document upload
6. **Trial expiring**: X days left on free trial

---

## Component Boundaries (New + Modified)

### New Backend Components

| Component | Depends On | Depended On By |
|-----------|-----------|----------------|
| `anonymous_chat.py` (endpoint) | `claude_coach_service`, `compliance_guard`, `rate_limit` | Flutter `AnonymousChatScreen` |
| `commitment_device.py` (model) | SQLAlchemy | `commitment_device_service` |
| `commitment_device_service.py` | `commitment_device` model, `User` | `coach_chat.py`, `tensions.py` |
| `provenance_tag.py` (model) | SQLAlchemy | `provenance_service` |
| `provenance_service.py` | `provenance_tag` model | `coach_context_builder`, `coach_chat.py` |
| `tension_engine.py` | profile, commitment devices, provenance | `tensions.py` endpoint |
| `tensions.py` (endpoint) | `tension_engine`, `require_current_user` | Flutter `TimelineProvider` |

### New Flutter Components

| Component | Depends On | Depended On By |
|-----------|-----------|----------------|
| `AnonymousChatScreen` | `ApiService`, local state | `app.dart` router |
| `AnonymousSessionStore` | Nothing (in-memory) | `AnonymousChatScreen`, `AuthProvider` |
| `CommitmentDeviceProvider` | `ApiService` | `TimelineProvider`, `LandingScreen` |
| `PartnerEstimate` (model) | Nothing | `CoachProfile`, `CoupleProjectionService` |
| `PremiumGateSheet` | `SubscriptionProvider` | Multiple screens |
| `PremiumGateWrapper` | `SubscriptionProvider`, `PremiumGateSheet` | Multiple screens |
| `TimelineProvider` | `CommitmentDeviceProvider`, `BiographyProvider`, `CoachProfileProvider` | `LandingScreen` |
| `TensionCard` | Nothing | `LandingScreen` |

---

## Data Flow Changes

### Anonymous → Authenticated Transition

```
BEFORE:  AnonymousIntentScreen → (blocked by auth guard) → /auth/register
AFTER:   AnonymousIntentScreen → /coach/anonymous (3 turns) → conversion CTA → /auth/register
         → AuthProvider._migrateAnonymousConversation() → ConversationStore
         → /coach/chat (full, with history preserved)
```

### Commitment Device Lifecycle

```
CREATE:  Coach conversation → LLM tool_use → commitment_device_service.create()
STORE:   PostgreSQL commitment_devices table
TRIGGER: tension_engine evaluates next_fire_at on each /tensions request
SURFACE: TimelineProvider → TensionCard on home screen
RESOLVE: User taps card → opens coach with context → mark_step_completed tool
```

### Provenance Flow

```
CAPTURE: User says "l'argent de mamie" → LLM detects → save_provenance_tag (internal tool)
STORE:   PostgreSQL provenance_tags table
INJECT:  coach_context_builder adds provenance to memory_block
RECALL:  Next conversation, LLM says "ton 3a, celui de mamie" naturally
```

---

## Suggested Build Order (Dependency-Driven)

```
Phase 1: Anonymous Flow
  - Backend: anonymous_chat.py endpoint (extract shared logic from coach_chat.py)
  - Flutter: AnonymousChatScreen + AnonymousSessionStore
  - Flutter: RouteScope.anonymous + router wiring
  - Flutter: AuthProvider._migrateAnonymousConversation()
  WHY FIRST: This is the user acquisition funnel. Without it, no one tries MINT.

Phase 2: Premium Gate
  - Flutter: PremiumGateSheet + PremiumGateWrapper
  - Flutter: Wire gates on existing screens (coachLlm, monteCarlo, etc.)
  - Backend: Verify billing endpoints work end-to-end
  - Flutter: FreeTrialBanner
  WHY SECOND: Must exist before coach intelligence features (which are premium).

Phase 3: Commitment Devices
  - Backend: commitment_device model + service + migration
  - Backend: 3 new coach tools
  - Backend: coach_chat.py tool execution
  - Flutter: CommitmentDeviceProvider
  WHY THIRD: Foundation for living timeline. Coach needs tools before timeline shows results.

Phase 4: Coach Provenance
  - Backend: provenance_tag model + service + migration
  - Backend: save_provenance_tag internal tool
  - Backend: coach_context_builder injection
  WHY FOURTH: Pure backend work, no Flutter changes. LLM starts using it immediately.

Phase 5: Couple Mode Dissymetrique
  - Flutter: PartnerEstimate model + service
  - Flutter: CoachProfile.partnerEstimate field
  - Backend: coach_context_builder partner fields
  - Backend: capture_partner_data tool
  WHY FIFTH: Requires coach provenance to work well (partner's money tagging).

Phase 6: Living Timeline
  - Backend: tension_engine + tensions endpoint
  - Flutter: TimelineProvider + TensionCard
  - Flutter: LandingScreen rewrite
  WHY LAST: Aggregates ALL previous features. Commitment cards, stale data, trial status.
```

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Anonymous Chat as Flag on Authenticated Endpoint
**What:** Adding `is_anonymous: bool` param to `POST /coach/chat`
**Why bad:** Mixes auth contexts, creates security surface (what if flag is spoofed?), different rate limits impossible
**Instead:** Separate endpoint with different dependency injection (no auth dep)

### Anti-Pattern 2: Partner Data in HouseholdProvider
**What:** Storing dissymmetric partner estimates alongside the symmetric household model
**Why bad:** Household = both partners have accounts. Dissymmetric = one partner's estimate. Different lifecycle, different data sources.
**Instead:** `CoachProfile.partnerEstimate` for estimates, `HouseholdProvider` for linked accounts

### Anti-Pattern 3: Per-Feature Paywall Screens
**What:** Building a custom paywall screen for each premium feature
**Why bad:** Inconsistent UX, duplicated code, maintenance nightmare
**Instead:** Single `PremiumGateSheet` parameterized by `CoachFeature`

### Anti-Pattern 4: Provenance Tags in Flutter
**What:** Syncing provenance tags to Flutter for display
**Why bad:** Provenance is coach context, not UI data. Users should never see "provenance_tag: mamie" — they should see the coach naturally saying "ton 3a, celui de mamie"
**Instead:** Backend-only, injected into LLM context window

### Anti-Pattern 5: Living Timeline as Static Widget List
**What:** Hardcoding card types and order in the landing screen
**Why bad:** Cannot adapt to user context, cannot A/B test, cannot add new tension types
**Instead:** `TensionEngine` returns ordered list, `TimelineProvider` renders generically

---

## Scalability Notes

| Concern | Now (100 users) | At 10K users | At 1M users |
|---------|-----------------|--------------|-------------|
| Anonymous rate limiting | In-memory slowapi | Redis-backed slowapi | Redis cluster + fingerprinting |
| Commitment device triggers | Evaluate on request | Background cron job | Event-driven (Celery/SQS) |
| Provenance storage | PostgreSQL JSONB | PostgreSQL JSONB | Consider vector embeddings for semantic search |
| Tension computation | Inline per request | Cache with 5-min TTL | Pre-compute on profile change events |

---

## Sources

- Codebase analysis: `apps/mobile/lib/app.dart` (router), `lib/router/` (scoping), `lib/providers/` (state)
- Backend: `services/backend/app/core/auth.py`, `services/backend/app/api/v1/endpoints/coach_chat.py`
- Existing models: `subscription_service.dart` (tier matrix), `household.py` (couple)
- Project context: `.planning/PROJECT.md`, `CLAUDE.md` (compliance, architecture)
- Audit decisions: `.planning/architecture/13-AUDIT.md` (5 innovations adopted)
