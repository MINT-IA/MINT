# Technology Stack — v2.5 Transformation Additions

**Project:** MINT v2.5 Transformation
**Researched:** 2026-04-12
**Scope:** Stack additions ONLY for new features. Existing validated stack is NOT repeated.

## What Already Exists (DO NOT add again)

| Capability | Already In Stack | Status |
|------------|-----------------|--------|
| Rate limiting | `slowapi>=0.1.9` + `app/core/rate_limit.py` (IP-based, Redis-ready) | Wired to ALL endpoints |
| Local notifications | `flutter_local_notifications: ^18.0.1` + `notification_scheduler_service.dart` | 3-tier system (calendar/event/BYOK) |
| In-app purchase (Apple) | `in_app_purchase: ^3.2.0` + `ios_iap_service.dart` | StoreKit2 wired, server-verify via `/billing/apple/verify` |
| Stripe billing | Backend billing_service.py + billing endpoints | Checkout, portal, webhooks, entitlements |
| Billing models | `SubscriptionModel`, `EntitlementModel`, `BillingTransactionModel` | 4-tier matrix (free/starter/premium/couple_plus) |
| Household/couple model | `HouseholdModel` + `HouseholdMemberModel` | Owner/partner, invitation codes, status lifecycle |
| Timeline widgets | 5+ timeline widgets in `widgets/coach/` and `widgets/dashboard/` | Various chart types |
| Auth with anonymous fallback | `get_current_user` returns `None` if no token | Anonymous mode exists |
| Secure storage | `flutter_secure_storage: ^9.0.0` | JWT + BYOK storage |
| Animations | Flutter built-in `AnimationController`, `CustomPainter` | Used extensively |

## Recommended Stack Additions

### 1. Anonymous Chat Endpoint — NO new dependencies

**Verdict: Zero additions needed.**

The anonymous chat endpoint needs:
- **Rate limiting**: `slowapi` already installed and wired. The `rate_limit.py` already supports Redis via `REDIS_URL` env var. For anonymous endpoints, use IP-based limiting (already the default `_get_real_client_ip` function). Apply stricter limits: `"3/minute"` for anonymous vs `"20/minute"` for authenticated.
- **Session tracking**: Use a client-generated UUID stored in `shared_preferences` (already in pubspec). Backend stores anonymous conversations keyed by this session ID. No new package needed.
- **Conversation transfer**: On auth, POST to a new `/auth/claim-anonymous` endpoint that re-parents anonymous messages to the authenticated user. Pure backend logic using existing SQLAlchemy models.

**Why NOT add Redis now**: Railway's in-memory rate limiting is sufficient for a single-instance deployment. Add Redis only when scaling to multiple instances (P4 timeframe). The code is already Redis-ready via `REDIS_URL`.

| Component | Solution | Package | Status |
|-----------|----------|---------|--------|
| Rate limiting (anon) | Stricter slowapi decorator on anon endpoint | `slowapi` (existing) | Ready |
| Session ID | Client UUID via `shared_preferences` | `shared_preferences` (existing) | Ready |
| Conversation transfer | New endpoint, SQLAlchemy UPDATE query | `sqlalchemy` (existing) | Ready |

---

### 2. Commitment Devices (Implementation Intentions, Fresh-Start, Pre-mortem) — ONE upgrade

**Verdict: Upgrade `flutter_local_notifications` to `^19.0.0`. No other additions.**

Commitment devices need scheduled notifications for implementation intentions (WHEN/WHERE/IF-THEN reminders). The existing `notification_scheduler_service.dart` generates `ScheduledNotification` objects but is calendar-focused (3a deadlines, tax dates). Commitment reminders need user-defined schedules.

| Component | Solution | Package | Status |
|-----------|----------|---------|--------|
| Scheduled reminders | `flutter_local_notifications` `zonedSchedule()` | Upgrade `^18.0.1` to `^19.0.0` | Upgrade needed |
| Timezone handling | `timezone` package for `TZDateTime` | `timezone: ^0.10.1` (existing) | Ready |
| Persistence | Store commitments in `sqflite_sqlcipher` | `sqflite_sqlcipher` (existing) | Ready |
| Backend sync | Store in profile/dossier via existing sync endpoints | `sqlalchemy` (existing) | Ready |

**Why upgrade `flutter_local_notifications`**: Version 19.x improves iOS exact scheduling reliability and fixes background delivery edge cases. The jump from 18.x to 19.x is non-breaking for the existing notification_service.dart consumer. Version 19.5.0 is latest as of April 2026.

**Why NOT add a push notification service (FCM/APNs)**: Commitment reminders are local by design. The user sets a personal intention; MINT reminds them locally. No server-push needed. Push notifications are a P3 feature for coach-initiated nudges.

**iOS caveat (64-notification limit)**: iOS caps scheduled local notifications at 64. The existing calendar notifications use ~15 slots. Commitment devices should cap at 10 active intentions, leaving headroom. Document this limit in the service.

---

### 3. Mode Couple Dissymetrique — NO new dependencies

**Verdict: Zero additions needed.**

The couple mode is architecturally about the PRIMARY user answering questions about their partner, NOT about two users sharing data. This is "dissymetrique" — one partner opens MINT, describes the other via coach conversation.

| Component | Solution | Package | Status |
|-----------|----------|---------|--------|
| Partner data model | `HouseholdModel` + `HouseholdMemberModel` already exist | `sqlalchemy` (existing) | Ready |
| Partner profile fields | Add to existing `profile_model.py` (partner_age, partner_salary, partner_lpp, etc.) | `sqlalchemy` (existing) | Ready |
| Coach questionnaire | System prompt injection via `context_injector_service.dart` | No package needed | Ready |
| Couple calculations | `avs_calculator.dart` already has `computeCouple()` | Financial core (existing) | Ready |
| Earmarking (money tagging) | `conversation_memory_service` stores implicit tags | Existing services | Ready |

**Why NOT add a real-time sync library (e.g., WebSockets, Firebase)**: The couple mode is explicitly asymmetric. Only one user opens MINT. The partner's data is entered BY the primary user through coach conversation. No real-time sync needed. If symmetric couple mode is ever needed (P4), that is a separate architectural decision.

**Why NOT add a separate partner table**: The `HouseholdMemberModel` already has `user_id`, `role`, `status`, `invitation_code`. For dissymmetric mode, the partner may not even have an account. Store partner financial data as JSON fields on the primary user's profile or as a dedicated `partner_financial_snapshot` table (simple migration, no new package).

---

### 4. Premium Gate — REPLACE `in_app_purchase` with RevenueCat

**Verdict: Replace `in_app_purchase` + `in_app_purchase_platform_interface` with `purchases_flutter: ^9.16.0`. Add `purchases_ui_flutter: ^9.16.0` for paywall UI.**

| Component | Solution | Package | Version |
|-----------|----------|---------|---------|
| Cross-platform subscriptions | RevenueCat SDK handles Apple + Google + Web | `purchases_flutter` | `^9.16.0` |
| Paywall UI (optional) | Pre-built paywall templates, customizable | `purchases_ui_flutter` | `^9.16.0` |
| Server-side validation | RevenueCat webhooks to existing `/billing/webhooks/` | No new backend package | -- |
| Entitlement checking | RevenueCat `CustomerInfo` maps to existing `EntitlementModel` | No new backend package | -- |

**Why RevenueCat over raw `in_app_purchase`**:
1. **The existing `ios_iap_service.dart` is iOS-only** (158 lines of StoreKit ceremony). RevenueCat abstracts iOS + Android + Web in one API.
2. **Server-side receipt validation is already half-built** (`billing.py` has Apple verify + Stripe checkout). RevenueCat handles validation server-side, eliminating the need to maintain Apple/Google receipt verification code.
3. **The billing tier matrix already exists** (`TIER_FEATURE_MATRIX` in `billing_service.py`). RevenueCat's entitlements map 1:1 to this matrix.
4. **Analytics**: RevenueCat provides subscription analytics (MRR, churn, trial conversion) out of the box. Critical for a 15 CHF/month product.
5. **Web support**: `purchases_flutter` 9.x supports Flutter Web, matching MINT's cross-platform ambition.

**Migration path**:
- Remove `in_app_purchase: ^3.2.0` and `in_app_purchase_platform_interface: ^1.4.0` from pubspec
- Add `purchases_flutter: ^9.16.0` and `purchases_ui_flutter: ^9.16.0`
- Replace `ios_iap_service.dart` with a `revenuecat_service.dart` (~50 lines vs 158)
- Backend: Add RevenueCat webhook handler alongside existing Stripe/Apple webhooks
- RevenueCat forwards to your existing Stripe/Apple webhook logic or replaces it entirely

**Backend addition**: RevenueCat sends webhooks to your server. The existing `billing.py` webhook pattern handles this. Add a new `POST /billing/webhooks/revenuecat` endpoint. No new Python package needed -- RevenueCat webhooks are standard JSON POSTs verified by shared secret (same pattern as Apple webhook).

**Cost**: RevenueCat is free up to $2,500/month MTR (Monthly Tracked Revenue). At 15 CHF/month, that is ~166 paying users before any cost. Well within early-stage runway.

**Why NOT keep raw `in_app_purchase`**:
- Google Play Billing v7+ compliance requires server-side validation. Raw `in_app_purchase` does not do this.
- Maintaining separate Apple + Google + Web purchase flows is 3x the code and 3x the bugs.
- RevenueCat's paywall A/B testing is free and critical for conversion optimization.

---

### 5. Living Timeline — NO new dependencies

**Verdict: Build custom with Flutter's built-in animation framework. Zero additions.**

| Component | Solution | Package | Status |
|-----------|----------|---------|--------|
| Timeline layout | `CustomPainter` + `AnimationController` | Flutter SDK (existing) | Ready |
| Scroll interaction | `CustomScrollView` + `SliverList` | Flutter SDK (existing) | Ready |
| Charts within timeline | `fl_chart: ^0.70.0` for data points | `fl_chart` (existing) | Ready |
| Tension indicators | `CustomPainter` with gradient fills | Flutter SDK (existing) | Ready |
| Hero animations | `Hero` widget for screen transitions | Flutter SDK (existing) | Ready |

**Why NOT add a timeline library** (`timeline_tile`, `timelines`, `animated_scrollable_timeline`):
1. MINT's "living timeline" is NOT a standard event list. It is a tension-based home screen where financial events pulse/glow based on urgency. No library matches this UX.
2. Existing codebase already has 5+ custom timeline widgets (`couple_timeline_chart.dart`, `couple_narrative_timeline.dart`, `horizon_line_widget.dart`, `mint_trajectory_chart.dart`, `couple_phase_timeline.dart`). The pattern is established.
3. Flutter's `AnimationController` + `CustomPainter` gives full control over the tension-pulse-glow aesthetic. A library would constrain the creative direction.
4. External timeline libraries add 50-200KB for features MINT will not use (drag-to-reorder, event editing, calendar views).

**Architecture approach**: Build `TensionTimelineWidget` as a new widget in `widgets/home/` that composes:
- `CustomScrollView` for the scrollable timeline
- `CustomPainter` for the tension line (gradient red/orange/green based on urgency)
- `AnimationController` for pulse/glow on actionable items
- `fl_chart` `LineChart` for mini-sparklines within timeline events

---

## Summary: Net Changes to pubspec.yaml

```yaml
# REMOVE
# in_app_purchase: ^3.2.0                    # Replaced by RevenueCat
# in_app_purchase_platform_interface: ^1.4.0  # Replaced by RevenueCat

# ADD
purchases_flutter: ^9.16.0          # RevenueCat — cross-platform subscriptions
purchases_ui_flutter: ^9.16.0       # RevenueCat — paywall UI components

# UPGRADE
flutter_local_notifications: ^19.0.0  # Was ^18.0.1 — improved iOS scheduling
```

## Summary: Net Changes to pyproject.toml

```toml
# NO CHANGES — all backend needs are met by existing dependencies
# slowapi, sqlalchemy, pyjwt, anthropic — all sufficient
```

## What NOT to Add

| Temptation | Why Not |
|------------|---------|
| Firebase Cloud Messaging | Push notifications are P3. Local notifications cover commitment devices. |
| WebSockets / Socket.IO | Couple mode is asymmetric. No real-time sync needed. |
| Redis (as hard dependency) | In-memory rate limiting sufficient for single-instance Railway. Code is already Redis-ready. |
| `stripe` Python package | Backend already uses Stripe via direct HTTP (billing_service.py). No SDK needed. |
| Timeline libraries | Custom widget matches MINT's tension-based UX better than any library. |
| `firebase_auth` | Magic link + Apple Sign-In already working. Do not add auth complexity. |
| `riverpod` / `bloc` | Provider is the established pattern across 9000+ tests. Do not migrate mid-milestone. |
| `hive` / `drift` | `sqflite_sqlcipher` is encrypted and established. Do not add a second local DB. |

## Installation

```bash
# Flutter (in apps/mobile/)
flutter pub remove in_app_purchase in_app_purchase_platform_interface
flutter pub add purchases_flutter:^9.16.0 purchases_ui_flutter:^9.16.0
# Manually update flutter_local_notifications version in pubspec.yaml to ^19.0.0
flutter pub get

# Backend — no changes needed
```

## Confidence Assessment

| Decision | Confidence | Rationale |
|----------|------------|-----------|
| No new deps for anonymous chat | HIGH | Existing slowapi + shared_preferences + SQLAlchemy cover all needs |
| Upgrade flutter_local_notifications | HIGH | 19.x is stable, non-breaking from 18.x, improved iOS scheduling |
| No new deps for couple mode | HIGH | HouseholdModel exists, dissymmetric = no sync needed |
| RevenueCat over raw IAP | HIGH | Industry standard, free tier sufficient, eliminates 3x receipt validation code |
| Custom timeline over library | MEDIUM | Creative direction demands custom; could revisit if timeline scope shrinks |

## Sources

- [purchases_flutter on pub.dev](https://pub.dev/packages/purchases_flutter) — v9.16.1, verified publisher
- [purchases_ui_flutter on pub.dev](https://pub.dev/packages/purchases_ui_flutter) — v9.16.1
- [RevenueCat Flutter installation docs](https://www.revenuecat.com/docs/getting-started/installation/flutter)
- [flutter_local_notifications on pub.dev](https://pub.dev/packages/flutter_local_notifications) — v19.5.0
- [slowapi GitHub](https://github.com/laurentS/slowapi) — Redis storage support
- [Flutter timeline packages overview](https://fluttergems.dev/timeline/)
- [RevenueCat pricing](https://www.revenuecat.com/platform/flutter-in-app-purchases/) — free up to $2,500 MTR
