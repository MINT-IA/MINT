# Open Questions — Anonymous Coach Hook

**Date:** 2026-04-11
**Status:** These decisions need to be made (by Julien) before or during GSD new-milestone questioning phase.

---

## Q1 — How many free messages?

**Current proposal:** 3

**Alternatives:**
- **1 message**: Maximum pressure to convert. Risk: user leaves without having tasted enough
- **3 messages** (proposed): Enough to ask a question, follow-up, deep dive. Feels "complete"
- **5 messages**: More generous. Better for complex topics but higher cost
- **10 messages**: Cleo's approach. Feels like a real trial. Most expensive per user

**Cost comparison (per anonymous user):**
- 1 msg: ~$0.03
- 3 msgs: ~$0.10
- 5 msgs: ~$0.17
- 10 msgs: ~$0.34

**Decision needed:** Which number?

---

## Q2 — Lifetime limit or daily reset?

**Option A — Lifetime per device (proposed):** 3 messages ever, then must signup
- **Pro**: Forces conversion, clean signal
- **Con**: User who tests on day 1 can't come back on day 5 without signing up

**Option B — Daily reset:** 3 messages per day, resets at midnight UTC
- **Pro**: User can return over multiple days before committing
- **Con**: Less urgency to sign up, higher cost, no clean conversion signal

**Option C — Weekly reset:** 3 per week
- Middle ground

**Decision needed:** A, B, or C?

**Recommendation:** Start with **A (lifetime)**. If conversion is low, relax to weekly/daily.

---

## Q3 — Does anonymous coach have access to RAG?

**Current proposal:** Yes, full RAG access

**Alternative:** No RAG, pure LLM only (smaller system prompt, no vector retrieval)

**Trade-off:**
- With RAG: answers are grounded, cite Swiss law, more accurate. Cost: ~20% more compute (embedding lookups).
- Without RAG: generic LLM answers, less impressive, risk of hallucination. Cheaper.

**Julien's instinct from earlier conversation:** Keep RAG. Hallucinations lose users. Agreed.

**Decision needed:** Confirm RAG = yes?

---

## Q4 — Does anonymous coach have tool calling?

**Tools available:** `route_to_screen`, `generate_document`, `retrieve_memories`, etc.

**Options:**
- **All tools**: same as authenticated (but many tools don't make sense without profile/history)
- **Subset**: only `route_to_screen` (Claude can suggest navigating to a simulator)
- **None**: pure text response only

**Recommendation:** **Subset — only `route_to_screen`**. An anonymous user hitting the coach can be routed to a simulator (e.g., "Want to see your retirement projection? Open the 3a simulator" → tap → they see a calculator they can play with without login). Other tools require profile data they don't have.

**Decision needed:** Confirm subset?

---

## Q5 — Does anonymous coach have memory within the session?

**Meaning:** Between message 1, 2, and 3, does Claude remember the previous exchanges in the conversation?

**Options:**
- **Yes, within session**: Pass conversation history to each `/coach/chat/anonymous` call. Claude has context.
- **No, stateless**: Each message is independent. Cheaper, but feels broken.

**Recommendation:** **Yes — full session context**. Anonymous users interact for maybe 5 minutes. Passing 3-5 messages of history costs ~$0.01 extra. Worth it for quality.

**Decision needed:** Confirm yes?

**How does Flutter handle this?** The orchestrator already passes `history: List<ChatMessage>` to the server. No change needed. Anonymous endpoint just receives the same list.

---

## Q6 — What about the 4th+ message after they've signed in?

**Scenario:** User sends 3 anonymous messages → sees soft paywall → ignores it → sends 4th message → hard paywall → signs in with Apple → 5th message...

**Current design:** After signin, the `claim-anonymous` call transitions the device. 5th message goes via `/coach/chat` (authenticated). Normal flow.

**Edge case:** What if during the Apple Sign-In flow, they already had a draft of a 5th message in the input? After signin, do we auto-send it, or do they have to re-tap?

**Recommendation:** **Auto-send after signin.** If the user was clearly trying to send a message before the paywall, honor their intent after they authenticate. Small UX win.

**Decision needed:** Confirm auto-send?

---

## Q7 — What if magic link is used but email never arrives (SMTP not configured)?

**Current state:** Railway staging has no SMTP variables set. Magic link endpoint returns 200 but no email is sent.

**Options:**
- **Block magic link for now**: UI shows "Coming soon" badge, only Apple Sign-In is active
- **Hide magic link option**: Don't offer it, only Apple
- **Fix SMTP on Railway**: Setup SMTP provider (SendGrid/Mailgun/AWS SES)

**Recommendation:** **Fix SMTP.** Don't ship with a broken auth option. Either it works or it's hidden.

**Decision needed:** Who fixes SMTP? Creator needs to provision a service.

**Alternative for beta:** Show only Apple Sign-In, hide magic link until SMTP is live.

---

## Q8 — What happens on Android (no Apple Sign-In)?

**Current state:** Apple Sign-In is iOS only. No Android build yet.

**When Android ships:** The hard paywall shows only magic link + password options (no Apple button).

**For this milestone:** iOS only. Android is out of scope.

**Decision needed:** Confirm iOS-only scope for this milestone?

---

## Q9 — What do we show in the "silent opener" for anonymous users?

**Current state:** The coach chat shows a "key financial number" from the profile (replacement rate, FRI score, capital).

**Problem:** Anonymous users have no profile. What do we show?

**Options:**
- **Nothing**: Just a welcome message
- **Generic example**: "Un Suisse sur 3 arrive à 65 ans avec moins que prévu" (a stat, not personal)
- **Question**: "Qu'est-ce qui t'inquiète aujourd'hui ?" (opens the conversation)
- **Voice cursor prompt**: "Tu veux en parler ?" (current fallback)

**Recommendation:** **Question approach** — "Qu'est-ce qui t'inquiète aujourd'hui ?" or similar. Opens the dialogue, invites immediate typing.

**Decision needed:** Which opener?

---

## Q10 — Observability and conversion tracking

**Question:** Do we add analytics events for this flow in v1, or defer?

**Events to track (if enabled):**
- `anonymous_coach_message_sent` (count, by message_number)
- `anonymous_coach_soft_paywall_shown`
- `anonymous_coach_soft_paywall_dismissed`
- `anonymous_coach_hard_paywall_shown`
- `anonymous_coach_signed_up_from_paywall` (the conversion event)
- `anonymous_coach_closed_app_from_paywall`

**Privacy:** Already anonymous (device_id), add session_id, no PII.

**Recommendation:** **Add events in v1.** Without them we can't measure if it works. But log them locally only for v1 (no backend aggregation yet). In v2, aggregate in dashboard.

**Decision needed:** Events yes/no?

---

## Q11 — Migration of existing TestFlight users

**Question:** Current TestFlight users who have been using the app without an account — what happens to them when this ships?

**Answer:** They already don't have an account, so they'll hit the new flow on next app open. Their "conversation history" is already empty (coach was broken). They're effectively new users.

**Action required:** None. Ship it.

---

## Q12 — What about existing anonymous patterns in the codebase?

**Found during audit:** `coach_chat_screen.dart:342-347` has a "CHAT-01: Ensure a profile exists for the coach context. Anonymous users get a minimal profile on first message. (VD, 35 ans, 0 income)"

**Conflict with new design:** This minimal profile was a workaround for the broken state. With the new anonymous flow, we should **remove** this fake profile creation. Anonymous users genuinely have no profile, and the backend handles this via `profile_context: null`.

**Action:** Delete `CHAT-01` fake profile logic in `coach_chat_screen.dart:342-347` as part of this milestone.

**Decision needed:** Confirm deletion?

---

## Summary of decisions required (before GSD milestone questioning)

| # | Question | Recommended answer | Urgency |
|---|----------|-------------------|---------|
| 1 | Message count | 3 | Critical |
| 2 | Lifetime vs reset | Lifetime (A) | Critical |
| 3 | RAG access | Yes | Critical |
| 4 | Tool calling | Subset (route_to_screen only) | Important |
| 5 | Session memory | Yes | Important |
| 6 | Auto-send after signin | Yes | Nice-to-have |
| 7 | SMTP / magic link | Fix SMTP or hide option | Critical |
| 8 | iOS-only scope | Yes | Confirm |
| 9 | Silent opener copy | "Qu'est-ce qui t'inquiète aujourd'hui ?" | Important |
| 10 | Analytics events | Yes, local only | Nice-to-have |
| 11 | TestFlight migration | No action | Confirm |
| 12 | Remove fake minimal profile | Yes | Critical |

---

## How to use this document in GSD new-milestone

The new milestone's **questioning phase** (see `references/questioning.md`) should walk through these 12 questions with the user. Most have a clear recommendation — the user just needs to confirm or override.

**Don't** ask them as a checklist. Weave them into natural conversation. Lead with the emotional framing ("we want to hook users without locking them in"), then dig into the specifics as they come up.
