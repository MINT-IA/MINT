# Copy & UX — Anonymous Coach Hook

**Date:** 2026-04-11
**Voice reference:** `docs/VOICE_SYSTEM.md` — 5 pillars: calme, précis, fin, rassurant, net.

---

## Voice reminders (non-negotiable)

- **Never** "vous" — always "tu"
- **Never** "retirement" framing — Mint is for 18 life events
- **Never** anxiety language ("Vous avez atteint votre limite", "Vous devez vous connecter")
- **Always** soft, inviting, "viens avec moi" energy
- **Never** the banned terms: garanti, optimal, meilleur, parfait, certain
- **Regional**: default Suisse Romande voice (anonymous users don't have canton yet)

---

## Copy strings by UI state

### State 1 — Initial coach screen (unchanged from current)

Shows the current "silent opener" with the key number or intent text.
No changes to this screen as part of this milestone.

### State 2 — Messages remaining counter (new, subtle)

**Location:** Just above the input bar, on the right side, 11pt italic, 50% opacity.

```
FR: "2 conversations avant que Mint te perde de vue"
DE: "2 Gespräche, bevor Mint dich aus den Augen verliert"
EN: "2 conversations before Mint loses track of you"
IT: "2 conversazioni prima che Mint ti perda di vista"
ES: "2 conversaciones antes de que Mint te pierda de vista"
PT: "2 conversas antes de Mint te perder de vista"
```

**Countdown variants:**
- 3 left: `"3 conversations avant que Mint te perde de vue"` (barely visible)
- 2 left: same copy, slightly more visible
- 1 left: `"Dernière conversation avant que Mint te perde de vue"` (warmer color, still soft)
- 0 left (after message 3 sent): hide the counter — the inline paywall card takes over

**Why this copy:** Frames the cost as "Mint will lose you" (emotional, relational) instead of "you will lose access" (transactional, aggressive).

### State 3 — Inline soft paywall (after 3rd message)

**Location:** Rendered inline below the 3rd assistant message, like a ResponseCard.

**Card header:**
```
FR: "Garde-moi dans ta poche"
```

**Card body:**
```
FR: "On vient d'avoir 3 bonnes conversations, toi et moi. 
     Si tu te connectes maintenant, je me souviens de tout : 
     ce qu'on a dit, ce qui compte pour toi, ce qu'on doit creuser.
     Sinon, tout repart à zéro à la prochaine ouverture."
```

**Primary button:** "Garde-les avec Apple" (Apple logo inline)
**Secondary button:** "Email"
**Tertiary (text link):** "Plus tard — je ferme l'app"

**Why this copy:**
- "Garde-moi dans ta poche" — intimate, ownership reversed (you own Mint, not the other way)
- "toi et moi" — creates a we
- "tout repart à zéro" — concrete consequence, not abstract
- "Plus tard — je ferme l'app" — honest about the choice, not guilt-trippy

### State 4 — Hard paywall (modal bottom sheet, message 4+ attempt)

**Appears when:** user sends a 4th message. Bottom sheet slides up, can't be dismissed by swipe-down (only by "Close app" or signing in).

**Header:**
```
FR: "On est rendus à un moment"
```

**Body:**
```
FR: "Tu as eu 3 conversations avec moi. Tu as vu ce que je peux faire.
     Maintenant, soit tu me laisses te suivre vraiment (et je garde 
     tout ce qu'on a dit), soit tu me laisses ici et je redeviens 
     un inconnu à la prochaine ouverture.
     
     Aucune carte bancaire. Juste un nom pour que je sache à qui je parle."
```

**Primary button (dominant, 56px tall):**
`"Sign in with Apple"` (Apple logo)

**Secondary button:**
`"Recevoir un lien par email"`

**Text link (bottom):**
`"Fermer l'app"` (dismisses the sheet and closes the coach screen)

**Why this copy:**
- "On est rendus à un moment" — marks a transition, not a block
- "soit tu me laisses te suivre vraiment" — choice is about relationship, not access
- "je redeviens un inconnu" — the consequence is mutual (Mint loses, you lose)
- "Aucune carte bancaire" — removes the "is this paid?" anxiety

### State 5 — Post-signup confirmation toast

**Appears when:** User completes Apple Sign-In or magic link verification, and the silent `claim-anonymous` API call succeeds.

**Toast (top of screen, 3 seconds):**
```
FR: "On se retrouve. Mint se souvient de toi maintenant."
```

**Why this copy:**
- "On se retrouve" — celebration of reunion, not "success"
- Present tense — Mint already remembers, it's not a promise

### State 6 — Claim failure (silent, no UI)

If `/auth/claim-anonymous` fails silently (404, 409, etc.), the Flutter app should **not** show an error. The user just signed in — don't ruin the moment. Log the failure for debugging, move on.

The user will have a fresh conversation history in their account. The 3 anonymous messages are lost. Acceptable trade-off for not blocking signup.

### State 7 — Error states

**Network error during anonymous chat:**
```
FR: "On dirait que la connexion fait des siennes. 
     Réessaie dans un instant."
```

**Rate limit (IP, 429):**
```
FR: "Trop de questions d'un coup. Laisse-moi respirer 
     une minute et reviens."
```

**Backend down (503):**
```
FR: "Mint fait une petite pause technique. 
     Reviens dans quelques minutes."
```

---

## UX Patterns

### Counter display timing

- **Fade in** after the FIRST assistant message is rendered (not before — we don't want to scare them on arrival)
- **Fade out** when the inline soft paywall appears (after 3rd message)
- **Never** on screens other than coach chat
- **Never** if user is authenticated (no counter for logged-in users)

### Soft paywall card animation

- Slide up from bottom of the message, 300ms ease-out
- Appears ~500ms after the 3rd assistant message renders (let them read it first)
- Inside the scrollable message list, not fixed (user can scroll past it)
- Dismissing with "Plus tard" collapses the card, user can still scroll history

### Hard paywall bottom sheet

- Slides up from bottom, 400ms ease-in-out
- Full width, ~60% screen height
- Backdrop blur + 30% dark overlay
- **No close button** — forces a choice (sign in or close app)
- Apple button: 56px tall, full width, haptic feedback on tap
- Close app link: very small, bottom, 12pt, text-muted
- Background scroll locked

### Post-signup flow

1. User taps "Sign in with Apple"
2. Native Apple Sign-In sheet opens (iOS native)
3. User authenticates
4. Apple returns JWT payload
5. App sends `POST /auth/apple/verify` → gets backend JWT
6. App sends `POST /auth/claim-anonymous` (silent, background)
7. Toast "On se retrouve. Mint se souvient de toi maintenant."
8. Bottom sheet dismisses
9. Coach chat continues as authenticated (no page change)

---

## Accessibility

- Counter text: 11pt minimum, contrast ratio 4.5:1 against background
- Paywall card: keyboard focusable, screen reader announces "Inline suggestion: save your conversation with Apple Sign-In"
- Bottom sheet: screen reader trap (TalkBack / VoiceOver) — focus stays inside until action taken
- All buttons: minimum 44x44 hit target

---

## i18n keys to add (all 6 ARB files)

```
anonymousCoachCounter3: "3 conversations avant que Mint te perde de vue"
anonymousCoachCounter2: "2 conversations avant que Mint te perde de vue"
anonymousCoachCounter1: "Dernière conversation avant que Mint te perde de vue"
anonymousCoachSoftPaywallHeader: "Garde-moi dans ta poche"
anonymousCoachSoftPaywallBody: "On vient d'avoir 3 bonnes conversations..."
anonymousCoachSoftPaywallApple: "Garde-les avec Apple"
anonymousCoachSoftPaywallEmail: "Email"
anonymousCoachSoftPaywallLater: "Plus tard — je ferme l'app"
anonymousCoachHardPaywallHeader: "On est rendus à un moment"
anonymousCoachHardPaywallBody: "Tu as eu 3 conversations avec moi..."
anonymousCoachHardPaywallApple: "Sign in with Apple"
anonymousCoachHardPaywallMagicLink: "Recevoir un lien par email"
anonymousCoachHardPaywallCloseApp: "Fermer l'app"
anonymousCoachReunionToast: "On se retrouve. Mint se souvient de toi maintenant."
anonymousCoachNetworkError: "On dirait que la connexion fait des siennes. Réessaie dans un instant."
anonymousCoachRateLimitError: "Trop de questions d'un coup. Laisse-moi respirer une minute et reviens."
anonymousCoachBackendError: "Mint fait une petite pause technique. Reviens dans quelques minutes."
```

All keys must be translated to DE, EN, IT, ES, PT. Run `flutter gen-l10n` after adding.

---

## Compliance notes

- **Disclaimer still shown** at the end of each anonymous response (same as authenticated path)
- **Sources still displayed** (RAG citations visible to anonymous users)
- **No guarantee language** in any copy
- **No "meilleur", "optimal", "parfait"** in any copy
- **No retirement framing** anywhere — the default assumption is "user has a life question"

---

## Out of scope for this milestone

- A/B testing different counter/paywall copy (add measurement first, iterate later)
- Localized paywall images or illustrations
- Progress indicator ("conversation 2 of 3") visible during message 1 and 2 — we decided to only show counter passively, not actively
- Allowing the user to pre-preview "what I'll get by signing in" — keep the magic, don't explain it
