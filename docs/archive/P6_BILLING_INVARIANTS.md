# P6 Billing Invariants — Frozen Reference

> **Status**: FROZEN. Any change requires explicit user approval.
> **Branch**: `feature/P6-billing-household`
> **Date**: 2026-03-01

---

## 1. Tier Architecture

### Before (current)
```
free  → onboarding + simulators read-only
coach → all 11 COACH_FEATURES
```

### After (P6)
```
free        → onboarding + simulators read-only + education
starter     → dashboard + check-in + alerts + couple basic (4.90 CHF/mo)
premium     → IA coach + Monte Carlo + exports + couple advanced (9.90 CHF/mo)
couple_plus → 2 active logins + joint optimization (14.90 CHF/mo)
```

### TIER_FEATURE_MATRIX (replaces all-or-nothing COACH_FEATURES)

| Feature | free | starter | premium | couple_plus |
|---------|------|---------|---------|-------------|
| dashboard | - | Y | Y | Y |
| forecast | - | Y | Y | Y |
| checkin | - | Y | Y | Y |
| scoreEvolution | - | - | Y | Y |
| alertesProactives | - | Y | Y | Y |
| historique | - | - | Y | Y |
| profilCouple | - | basic | full | full |
| coachLlm | - | - | Y | Y |
| scenariosEtSi | - | - | Y | Y |
| exportPdf | - | - | Y | Y |
| vault | - | - | Y | Y |
| monteCarlo | - | - | Y | Y |
| arbitrageModules | - | - | Y | Y |

---

## 2. Ownership Invariants (household_owner vs billing_owner)

### INV-1: Separation of concerns
- `household_owner_user_id` = manages household (invite, revoke, transfer)
- `billing_owner_user_id` = pays the subscription
- These CAN be different users

### INV-2: Both owners must be active members
- `household_owner_user_id` MUST be an `active` member of the household
- `billing_owner_user_id` MUST be an `active` member of the household
- Enforced by DB CHECK constraint

### INV-3: Entitlements propagate from billing_owner
- `recompute_entitlements(user_id)`:
  1. Check user's direct subscription tier
  2. If member of a household → inherit `billing_owner_user_id`'s tier
  3. Higher tier wins (direct vs inherited)
- NEVER propagate from `household_owner_user_id`

### INV-4: Max 1 household per user
- `HouseholdMemberModel.user_id` has UNIQUE constraint
- A user cannot be in 2 households simultaneously

### INV-5: Max 2 active members per household
- Enforced by DB trigger or CHECK constraint (not just app-level)
- Any `INSERT` with `status='active'` where count >= 2 → reject

### INV-6: Cooldown 30 days
- After leaving/being revoked from a household, user cannot join another for 30 days
- `cooldown_override` admin endpoint for legitimate cases (see INV-10)

---

## 3. Webhook Idempotence Invariants

### INV-7: Event deduplication
- Table `billing_webhook_events`:
  - `event_id` (UNIQUE) = Apple `originalTransactionId` / Stripe `event.id` / Google `purchaseToken`
  - Before processing: `SELECT WHERE event_id = :id` → if exists, return 200 OK, no reprocessing
  - Column `outcome`: `applied` | `skipped_duplicate` | `skipped_stale`

### INV-8: Monotone timestamp
- `SubscriptionModel.last_event_at` column (new)
- Webhook with timestamp < `last_event_at` → ignored (outcome = `skipped_stale`)
- Protects against out-of-order event delivery

### INV-9: Replay-safe handlers
- `recompute_entitlements()` is idempotent (recomputes from current state, not incremental)
- All webhook handlers call `recompute_entitlements()`, never direct mutations
- Same event processed 2x = same result

---

## 4. Kill Switch (enableCouplePlusTier)

### INV-10: Server-side source of truth
- Backend endpoint: `GET /api/v1/config/feature-flags` returns `{ enableCouplePlusTier: bool }`
- Flutter polls at launch + every 6h
- NOT Firebase Remote Config (single source, not two)

### INV-11: Graceful degradation
- If `enableCouplePlusTier = false`:
  - Paywall shows 2 columns (Starter + Premium), not 3
  - Existing Couple+ users retain access via backend entitlements
  - Household management UI hidden but data preserved

---

## 5. Admin Security Invariants

### INV-12: RBAC strict
- `POST /api/v1/admin/household/override-cooldown` requires `support_admin` role
- Role assigned manually in DB, not auto-assignable
- Rate limit: max 10 overrides/hour per admin

### INV-13: Immutable audit log
- Table `admin_audit_events`: NO UPDATE/DELETE permissions
- Fields: `admin_user_id`, `action`, `target_user_id`, `reason` (NOT NULL, min 10 chars), `ip_address`
- Retention: **10 years** (CO art. 958f — financial records conservation)
- Hot storage (PostgreSQL): 2 years. Cold storage (encrypted archive): years 3-10.

### INV-14: Alerting
- Each admin override → Slack `#security-alerts` + email `security@mint.ch`
- >3 overrides/24h by same admin → escalation alert

---

## 5b. Regulatory Feature Isolation (FATCA)

### INV-15: Two-dimensional feature access
- Effective access = `tier_entitlement(feature) AND regulatory_permission(user, feature)`
- FATCA partner (`isFatcaResident=true`): 3a features suppressed regardless of tier
- Features affected: `arbitrageModules` (3a arm), `checkin` (3a reminder), `scenariosEtSi` (3a scenario)
- Enforcement: Flutter checks `profile.prevoyance.canContribute3a` before rendering 3a UI
- Backend: `recompute_entitlements()` returns `restricted_features: Set<String>` based on archetype

### INV-16: Household ↔ ConjointProfile bridge
- `ConjointProfile.linkedUserId` (nullable) — set when partner accepts household invite
- When `linkedUserId != null`: ForecasterService reads partner's own CoachProfile (live data)
- When `linkedUserId == null`: ForecasterService reads embedded `conjoint.*` fields (manual data)
- On household dissolution: `linkedUserId` nullified, user prompted to update civil status

### INV-17: Partner onboarding
- Partner MUST complete their own 3-question onboarding before household features activate
- No auto-profile creation from ConjointProfile data (LPD compliance)
- `partner_profile_status` field on household: `none | pending | complete`

---

## 6. E2E Test Gate (merge blocker)

### 5 Billing Scenarios
| # | Scenario | Expected |
|---|----------|----------|
| E1 | Owner purchases couple_plus | Entitlements activated, household created |
| E2 | Owner invites partner | Partner receives pending invitation |
| E3 | Partner accepts → propagation | Partner has same features as billing_owner |
| E4 | Restore purchase | Entitlements restored after reinstall |
| E5 | Downgrade/cancel | Partner loses access (7-day grace) |

### 2 Webhook Scenarios
| # | Scenario | Expected |
|---|----------|----------|
| W1 | Same event_id sent 2x | 2nd = 200 OK, no double mutation |
| W2 | Stale event (timestamp < last_event_at) | Ignored, entitlements unchanged |

### 4 Concurrency Scenarios
| # | Scenario | Expected |
|---|----------|----------|
| C1 | 2 simultaneous accepts (same code) | 1 succeeds, 1 gets 409 |
| C2 | Accept during transfer | Isolation guaranteed, no corruption |
| C3 | Webhook downgrade during accept | Member added then notified (grace 7d) |
| C4 | Concurrent revoke on same user | Idempotent (200 OK both) |

### Anti-Abuse Rules
| # | Rule | Expected |
|---|------|----------|
| A1 | Invitation expires after 72h | Auto-expired, owner can resend |
| A2 | Accept expired code | 410 Gone |
| A3 | Accept on full household | 409 Conflict |
| A4 | Join new household within 30d cooldown | 403 Forbidden |

**GATE: ALL 13 tests must pass before merge to main.**

---

## 7. DB Schema (frozen)

```sql
-- Household
CREATE TABLE households (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    household_owner_user_id VARCHAR NOT NULL REFERENCES users(id),
    billing_owner_user_id VARCHAR NOT NULL REFERENCES users(id),
    created_at TIMESTAMP DEFAULT now(),
    updated_at TIMESTAMP DEFAULT now(),
    CHECK (household_owner_user_id IS NOT NULL),
    CHECK (billing_owner_user_id IS NOT NULL)
);

-- Household Members
CREATE TABLE household_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    household_id UUID NOT NULL REFERENCES households(id),
    user_id VARCHAR NOT NULL UNIQUE REFERENCES users(id),
    role VARCHAR NOT NULL CHECK (role IN ('owner', 'partner')),
    status VARCHAR NOT NULL CHECK (status IN ('pending', 'active', 'revoked')),
    invited_at TIMESTAMP DEFAULT now(),
    accepted_at TIMESTAMP,
    cooldown_override BOOLEAN DEFAULT false
);

-- Webhook dedup (extend existing)
ALTER TABLE billing_webhook_events ADD COLUMN subscription_id UUID REFERENCES subscriptions(id);
ALTER TABLE billing_webhook_events ADD COLUMN outcome VARCHAR DEFAULT 'applied';
ALTER TABLE subscriptions ADD COLUMN last_event_at TIMESTAMP;

-- Admin audit
CREATE TABLE admin_audit_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_user_id VARCHAR NOT NULL REFERENCES users(id),
    action VARCHAR NOT NULL,
    target_user_id VARCHAR NOT NULL,
    reason VARCHAR NOT NULL CHECK (length(reason) >= 10),
    ip_address VARCHAR,
    user_agent VARCHAR,
    created_at TIMESTAMP DEFAULT now()
);
-- REVOKE UPDATE, DELETE ON admin_audit_events FROM app_role;
```

---

## 8. API Endpoints (frozen)

```
POST   /api/v1/household/invite              { email }           → 201
POST   /api/v1/household/accept              { invitation_code } → 200
DELETE /api/v1/household/member/{user_id}                         → 200
GET    /api/v1/household                                          → 200
PUT    /api/v1/household/transfer             { new_owner_id }    → 200
POST   /api/v1/admin/household/override-cooldown { user_id }     → 200
GET    /api/v1/config/feature-flags                               → 200
```

---

## 9. Flutter Enums (frozen)

```dart
enum SubscriptionTier { free, starter, premium, couplePlus }
// Replaces: enum SubscriptionTier { free, coach }

// Product IDs
static const appleProducts = {
  'ch.mint.starter.monthly',
  'ch.mint.premium.monthly',
  'ch.mint.couple_plus.monthly',
  'ch.mint.starter.annual',
  'ch.mint.premium.annual',
  'ch.mint.couple_plus.annual',
};
```

---

## 10. App Store Pricing (frozen)

| Tier | Monthly | Annual (17% off) |
|------|---------|-------------------|
| Starter | 4.90 CHF | 48.90 CHF |
| Premium | 9.90 CHF | 98.90 CHF |
| Couple+ | 14.90 CHF | 148.90 CHF |

One-time purchases (future):
- Rapport fiscal: 14.90 CHF
- Plan retrait couple: 29.90 CHF
- Rachat LPP: 9.90 CHF
- Scenario proprio: 19.90 CHF
