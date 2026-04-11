# Product Brief — Anonymous Coach Hook

**Milestone name:** Anonymous Coach Hook (3 free messages)
**Date:** 2026-04-11
**Author:** Julien (creator) + Claude (recovery session)
**Status:** Ready for GSD new-milestone

---

## The Problem

**Current broken flow:**
1. User opens MINT for the first time from TestFlight
2. Sees landing page "On éclaire. Tu décides." → taps "Parle à Mint"
3. Arrives on empty coach chat screen with "Tu veux en parler ?"
4. Types their question
5. **Waits 25 seconds, sees "Le coach IA n'est pas disponible pour le moment"**
6. **Closes the app. Never comes back.**

**Root cause (confirmed 2026-04-11 during recovery session):**
The backend `/api/v1/coach/chat` endpoint (and also `/rag/query`) requires JWT authentication via `require_current_user`. But the Flutter app marks `/coach/chat` as `RouteScope.public` (KILL-05 decision) — users can reach the chat without logging in. Contradiction: Flutter says "chat is public", backend says "chat requires auth". Result: anonymous users always hit the static fallback template.

**Why this matters:**
MINT's core hook is the AI coach. It's the reason someone downloads the app. If the first interaction fails, we lose the user forever. Current conversion to "I'll install MINT" → "I'll use MINT" is effectively 0% for unauthenticated users, which is 100% of new installs.

---

## The Solution

**Give every new user 3 real AI conversations before asking them to sign in.**

After 3 messages of genuine, RAG-backed, Claude-powered responses, surface a soft paywall: "MINT can keep learning your situation if you sign in — 1 tap with Apple ID". The user has already experienced the value; now they have a reason to commit.

---

## Design Principles

1. **Zero friction on first contact.** No account, no email, no wizard. Tap → chat → answer.
2. **Real quality, not a demo.** The 3 free messages must use the full RAG + Claude pipeline. No downgraded model, no canned responses. If we give them a cheap taste, we lose them.
3. **Never frustrate.** The 4th message doesn't say "blocked" — it says "you've had 3 great conversations, want to keep them? Sign in."
4. **Economically sustainable.** 3 messages × Claude Sonnet 4.5 = ~$0.05-0.15 per anonymous user. Acceptable cost per lead if conversion to signup is >10%.
5. **Abuse-resistant.** Device-ID based with IP-level fallback. Not NSA-proof, but stops casual scraping.

---

## User Flow (desired)

```
COLD START (new user, TestFlight install)
  ↓
Landing screen: "On éclaire. Tu décides." + "Parle à Mint" button
  ↓
Coach chat screen (no login required)
  ↓
User types: "C'est quoi les 3 piliers suisses ?"
  ↓
[TYPING INDICATOR ~3s]
  ↓
Real Claude response with RAG sources + compliance disclaimer
  [Message 1/3 used — displayed subtly in the UI, not anxiety-inducing]
  ↓
User types: "Comment optimiser mon 3e pilier ?"
  ↓
Real answer
  [Message 2/3]
  ↓
User types: "Je gagne 80k, je dois cotiser combien ?"
  ↓
Real answer + soft nudge at the end:
  "Tu as 1 conversation restante. Pour que Mint se souvienne de toi
   et personnalise ses conseils, sauve ta conversation en 1 tap."
  [Inline CTA: "Sauver avec Apple" | "Sauver avec email"]
  ↓
If user types a 4th message:
  Response arrives → ends with firmer CTA:
  "Cette conversation restera ici si tu la sauves maintenant.
   Sinon Mint oubliera tout à la fermeture de l'app."
  [Full-width CTA button: "Sauver mes 4 conversations"]
  ↓
If user ignores and types 5th message:
  NO response. Bottom sheet appears:
  "Pour continuer avec Mint, crée ton espace gratuit.
   Apple Sign-In • Magic link • Mot de passe"
  [Primary CTA: "Sign in with Apple"]
```

---

## Scope

### In scope (v1 of this milestone)

- [ ] Backend: anonymous coach endpoint (same RAG + Claude pipeline as authenticated)
- [ ] Backend: device_id-based rate limiting (3 messages per device, persistent counter)
- [ ] Backend: IP-level rate limiting (abuse protection)
- [ ] Backend: migration table for anonymous usage tracking
- [ ] Flutter: send device_id header on coach requests when no JWT
- [ ] Flutter: UI for "X messages remaining" counter (subtle, not anxious)
- [ ] Flutter: inline CTA at message 3 (soft prompt)
- [ ] Flutter: blocking bottom sheet at message 4+ (hard stop)
- [ ] Flutter: merge anonymous conversation into account on login
- [ ] End-to-end test on TestFlight (creator verifies on iPhone)

### Out of scope (defer to later)

- Multi-device conversation sync
- Anonymous conversation persistence across app kill (v1 is in-memory only — if they close the app, conversations are lost AND this is intentional to push signup)
- Referral / invite codes
- A/B testing of different paywall copy
- Analytics funnel dashboard (track signup conversion rate) — we'll add this after we see the flow works
- GDPR consent for anonymous device tracking — needs compliance review separately

---

## Success Criteria

**Technical:**
- New user on TestFlight can send 3 messages and get real Claude responses
- 4th message attempt triggers the upgrade flow
- After Apple Sign-In, the 3 previous messages persist in the account
- Rate limiting prevents >3 messages per device (verified by resetting and retrying)
- Backend handles 10 concurrent anonymous users without errors

**Product:**
- Creator (Julien) cold-starts the app on iPhone and feels the flow "just works"
- Copy at each stage doesn't feel like a paywall — feels like "MINT wants to remember you"
- Transition to signup is 1 tap (Apple Sign-In) or 2 taps (magic link)

**Economic:**
- Cost per anonymous user < $0.20 (3 messages max, short responses, no image generation)
- Rate limit prevents any single IP from burning >100 requests/day

---

## Explicit Non-Goals

1. **Not an onboarding flow.** We don't ask for age/canton/salary before the first chat. That's the previous failed approach.
2. **Not a demo mode.** Anonymous coach has access to the same RAG, the same Claude Sonnet model, the same compliance guard. The ONLY difference is persistence (in-memory) and count (3 messages).
3. **Not a retirement framing.** Per CLAUDE.md rules, anonymous coach must handle all 18 life events — housing, career, tax, debt, family — not just retirement.
4. **Not bypass-able by reinstalling.** IP-level rate limit means a motivated bad actor needs a new IP every 3 messages. That's expensive enough.

---

## Dependencies on Recovery Session

This milestone depends on these already being deployed:
- ✓ Phase 4 (coach AI server-key tier via /coach/chat) — already merged in PR #306/307
- ✓ Railway staging properly connected to staging branch (fixed during recovery session)
- ✓ Apple Sign-In endpoint working (`/auth/apple/verify` returns 400 not 404)
- ✓ Magic link endpoints exist on backend

Known issues NOT blocking this milestone (but affect UX):
- Keyboard stuck at top of screen (separate bug)
- Back button from coach doesn't return to landing (separate bug)
- "Recevoir un lien magique" button text overflows (layout bug)
- SMTP not configured on Railway staging (magic link will succeed-silently without sending email)

These should be addressed in the next milestone after this one.

---

## Reference Documents (read these)

- `CLAUDE.md` — MINT identity, compliance rules, 18 life events
- `.planning/briefs/anonymous-coach-hook/02-TECHNICAL-SPEC.md` — detailed technical design
- `.planning/briefs/anonymous-coach-hook/03-API-CONTRACT.md` — backend API changes
- `.planning/briefs/anonymous-coach-hook/04-COPY-AND-UX.md` — exact copy for each UI state
- `.planning/briefs/anonymous-coach-hook/05-OPEN-QUESTIONS.md` — decisions still pending
- `.planning/INCIDENT_DIAGNOSTIC_2026-04-10.md` — full context of why we're here
