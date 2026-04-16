# MINT UX — Senior Review & Redesign

**Author role:** Senior UX Designer (15y in financial products — Mint/Intuit, YNAB, Cleo, Klarna, Wise, N26).
**Brief source:** `CLAUDE.md`, `docs/MINT_IDENTITY.md`, `docs/VOICE_SYSTEM.md`, `docs/MINT_UX_GRAAL_MASTERPLAN.md`, `.planning/SCREEN_MAP.md`.
**Date:** 2026-04-11.
**Tone of this doc:** opinionated, blunt where needed, concrete. The team is frustrated. They need decisions, not frameworks.

---

## 0. Framing — what I saw in 30 minutes

MINT has the rarest thing in fintech: a voice and a doctrine worth defending. "Mint te dit ce que personne n'a intérêt à te dire" is a genuine positioning, not a slogan. The 4-layer engine (fact → translation → personal implication → questions to ask) is editorial gold. The 5 voice pillars (calme, précis, fin, rassurant, net) are mature.

And the product ships every user into a navigation maze that contradicts all of it.

Reading `SCREEN_MAP.md`, the diagnosis is clear and painful:

- **95 screens, 203 navigation actions, 40+ shimmed routes, 1 confirmed infinite loop (Budget), 21 `safePop` sites that all dump to `/coach/chat` when the stack is empty.**
- **The chat is simultaneously the hub, the shell, the fallback, the router, and the onboarding.** A Swiss Army knife with no handle.
- **There is no mental model.** The user is expected to intuit that "tap the lightning, then a card, then a drawer, then a back button that may or may not bring you home" is the way.
- **Facade screens exist** (`BudgetContainerScreen` is the canonical example) — empty states whose only action sends the user back to the exact message that opened them. That is not a bug. That is an architecture that never closed the loop between "where data is displayed" and "where data is collected."

This is a **mental-model crisis**, not a visual one. No amount of color tokens will fix it. Before I propose personas, I want to name the root cause plainly:

> **MINT mixes up "the chat is the product" with "the chat is the router." These are different claims. The first is a UX decision. The second is a technical shortcut that leaks into UX and produces dead ends.**

Every fix below comes back to this. Let's go.

---

## Deliverable A — 3 personas, 3 first-session walkthroughs

MINT is segmented by life moment, not age. Good. So are my personas.

### Persona 1 — "Le découvreur" (Camille, install cold)

**Context:** 31, Lausanne, product manager. A friend mentioned MINT at dinner. Installs it on the tram the next morning. Knows nothing about 2e pilier. Has 4 minutes before the stop.

**What she brings:** curiosity, zero data, low trust, a latent shame about not knowing her own finances.

**What she must NOT see:** a form, a login wall, an "add your certificat LPP" empty state, a chart, a 7-hub grid, or the word "dashboard."

#### Ideal first 3 minutes

| Second | Screen | What happens | Why |
|--------|--------|--------------|-----|
| 0 | `LandingScreen` | Single sentence: *"Mint te dit ce que personne n'a intérêt à te dire."* One CTA: **"Commencer"**. No signup, no email. | Trust is earned on the first breath. Asking for email first is a 40% drop. |
| 3 | `CoachChatScreen` (silent opener mode) | A single line lands: *"On commence simple. Donne-moi 3 choses et je te montre un chiffre que tu ne connais pas sur toi."* | The promise is concrete (a chiffre) and the price is known (3 things). No slider wall. |
| 10 | Inline chat tap-to-type | Input 1: *"Tu es née en quelle année ?"* — numeric keyboard, 1 tap done. | Progressive disclosure, rule of 3. |
| 25 | Inline | Input 2: *"Ton salaire brut annuel, à la louche ?"* — tolerant input, accepts "95k", "95000", "95'000". | Low-friction, respects her shame threshold. |
| 45 | Inline | Input 3: *"Tu es dans quel canton ?"* — chip list of 26 + "autre". | Canton is needed for voice tuning + tax; framed as a logistical detail. |
| 60 | Chat | Silent opener transforms into the **Premier Éclairage**. Big number, one sentence below. Example: *"**63%**. C'est ce qu'il te resterait de ton niveau de vie actuel si tu partais à 65 ans demain, sans rien changer."* Under it: *"Tu veux que je te dise pourquoi, ou tu préfères voir un autre angle ?"* | This is the moment of value. One number. No chart. No disclaimer pop. Silence around the number (Voice System §4, "Laisser le silence parler"). |
| 90 | Chat | Two suggestion chips: *"Pourquoi 63% ?"* / *"Et si je change de job ?"*. Plus a free-text input. | She now has agency. She can go deep, lateral, or just read. |
| 120 | Chat | She taps *"Pourquoi 63% ?"*. Coach responds with a 4-layer answer: (1) the fact, (2) the translation, (3) what it means for her specifically, (4) one question to ask her employer. | The doctrine shows up, unmistakably, on minute 2. |
| 180 | Chat | At the bottom of that answer, one small line: *"Si tu veux affiner ce chiffre, j'ai besoin de ton certificat LPP. Ça prend 20 secondes quand tu l'as sous la main."* | Friction is introduced only AFTER value is felt. No gate. |

**Acceptable friction:** typing 3 answers. Choosing canton.
**Unacceptable friction (currently shipped):** email signup, tab shell before value, empty hubs, LPP certificate upload before seeing a number, the Budget facade.

**Win condition:** minute 3, Camille can quote one number about herself she didn't know 180 seconds ago. That is the only KPI that matters for session 1.

---

### Persona 2 — "L'utilisateur en crise" (Marco, specific pain)

**Context:** 42, Genève, just got a separation letter from his employer. Has 60 days of notice. Opens MINT because a colleague said "it's a Swiss thing, try it." He doesn't care about MINT's identity. He wants to know: *am I going to be OK?*

**What he brings:** urgency, anxiety, a concrete event, probably his LPP certificate in a drawer somewhere.

**What he must NOT see:** a 3-minute onboarding asking about canton and birth year. A hub grid. A generic greeting.

#### Ideal first 3 minutes

| Second | Screen | What happens | Why |
|--------|--------|--------------|-----|
| 0 | `LandingScreen` | Same minimal landing. He taps "Commencer". | Consistency. |
| 3 | `CoachChatScreen` | **Silent opener variant for crisis intent:** *"Dis-moi en une phrase ce qui se passe. Je m'occupe du reste."* Free text + 6 suggestion chips: *"J'ai perdu mon job"*, *"Je me sépare"*, *"Je veux acheter"*, *"Je démarre un job"*, *"Je deviens indé"*, *"Autre"*. | Direct path. He taps "J'ai perdu mon job". Zero typing. |
| 8 | Chat | Coach answers calmly (Voice §2 Axe 1 "Stress"): *"D'accord. C'est un moment difficile, on reste là. Trois choses urgentes cette semaine, dans l'ordre."* Then 3 lines, numbered. No chart. No projection yet. | This is the crisis mode from VOICE_SYSTEM.md applied literally. Short sentences. Action over explanation. |
| 25 | Chat | The 3 lines: (1) *"Ton LPP part en libre passage dans 30 jours. Je t'explique où le garder."* (2) *"Tes droits au chômage commencent dès le dernier jour. Voici ce qu'il faut déposer."* (3) *"Ton 3a reste à toi. On le touche pas tout de suite."* Under each, a small *"Creuser ça →"*. | The doctrine: danger avoided, piege éclairé, prochain geste. Four layers compressed into three bullets. |
| 60 | Chat | He taps *"Creuser ça"* on line 1. Drawer bottom sheet opens with the libre passage flow — **not a full-screen push.** The chat remains visible behind. | Preserves his thread. He never "leaves" the conversation that saved him. |
| 120 | Drawer | He fills in his last salary (optional), picks a canton. Drawer shows: *"Tu as environ 45 jours pour choisir. Voici les 2 familles de solutions, sans nommer d'émetteur, avec les questions à poser avant de signer."* | 4-layer engine, explicit. |
| 180 | Drawer dismiss | He swipes down. Chat still there. A new message from the coach: *"Quand tu veux, on passe à la ligne 2 (chômage). Pas d'urgence, ça peut attendre ce soir."* | Respect his rhythm. No auto-advance. |

**Acceptable friction:** picking his event from 6 chips (1 tap).
**Unacceptable friction (currently shipped):** the fact that `/unemployment` is a simulator screen reached via push, with a `safePop` back button. He doesn't need a simulator. He needs a checklist.

**Win condition:** minute 3, Marco knows his next 3 actions and feels less alone. He did not fill a form. He did not see a graph.

---

### Persona 3 — "Le retour régulier" (Nadia, progress check)

**Context:** 35, Zürich, used MINT for 2 weeks after a first job change. Hasn't opened it in 6 days. Has a half-filled profile (salary, age, canton, no LPP certificate). Reopens it to see "where I am".

**What she brings:** a history, some expectations, decaying trust ("is this still useful?").

**What she must NOT see:** the silent opener again. A generic greeting. A request to complete her profile for the 5th time. A streak counter. A "you missed 6 days" shame trigger.

#### Ideal first 3 minutes

| Second | Screen | What happens | Why |
|--------|--------|--------------|-----|
| 0 | `LandingScreen` **skipped** | App opens directly on last conversation or on a lightweight "Today" surface (NOT a dashboard). | Returning users pay a tax of 1 tap per session. Don't charge it. |
| 1 | Chat or Today surface | A single line at the top: *"Content de te revoir. Depuis la dernière fois, **un chiffre a bougé**."* Under it: the changed number + delta. Example: *"Ton taux est passé de 63% à 65%. Parce que ton nouveau salaire est entré dans la caisse."* | Memory proves the system is alive. The "un chiffre a bougé" pattern is what Cleo does well and Wise does cleanly. |
| 10 | Same surface | Under the changed number: one card, *"Prochain geste suggéré"* — the same one as last session if she didn't complete it, or a new one if she did. | No shame about the unfinished task. It's just "still on the table". |
| 20 | Tap the chip *"Reprendre la conversation"* | Returns to the last chat thread, exactly where she left it, with a soft separator "**6 jours plus tard**". | Conversations are durable. This is mandatory. |
| 60 | Chat free use | She asks a new question. The coach remembers her salary, her canton, her intent. Proof of memory. | This is the Loop: memory → freshness → trust. |

**Acceptable friction:** zero. She's already a customer.
**Unacceptable friction (currently shipped):** cold-start on `CoachChatScreen` with silent opener because she's "anonymous" by system logic even though her profile exists. The system confuses "no login" with "no memory".

**Win condition:** minute 1, Nadia sees that MINT remembers her AND that something moved. If nothing moved, MINT says so honestly: *"Rien n'a bougé depuis la semaine dernière. C'est normal. On peut creuser un angle nouveau si tu veux."*

---

## Deliverable B — The 5 moments of truth

In financial products there are ~5 moments where you either win a user for years or lose them forever. Here they are for MINT, ranked by cost of failure.

### Moment 1 — The first number (minute 1-2 of session 1)

**Currently:** silent opener waits for user input. If the user doesn't type (half of them won't — discovery anxiety), nothing happens. The promise of a "first chiffre" is conditional on effort the user hasn't decided to invest yet.

**Ideal:** the silent opener delivers the first number **as soon as the 3 cheap inputs are collected** (age, salary, canton — 45 seconds). That number is the Premier Éclairage. It is a single, large, unadorned statement. No chart, no disclaimer in the viewport (disclaimer lives in a small "i" under it).

**Rule:** a user must never reach minute 2 without a number *about them*. If the system can't produce one, it's broken.

**Anti-pattern to kill:** the current coach greeting "Bonjour Julien, comment puis-je t'aider aujourd'hui ?" — too generic, breaks feedback_chat_must_be_silent.md.

### Moment 2 — The first time we ask for personal data

**Currently:** data capture is interleaved with chat via CHAT-04, which is good in principle. But the LPP certificate request currently appears too early and as a blocker dressed as an optional.

**Ideal:** every data request follows the template:
> *"J'ai assez pour [what we can show]. Si tu veux [what we could show more], il me faut [one specific thing]. Ça prend [time]."*

**Never:** "Complète ton profil pour débloquer…". That word "débloquer" is shame-coded and paywall-coded. Ban it.

**Rule:** value precedes ask. Always. The first "I need X" must come AFTER the user has felt at least one useful truth.

### Moment 3 — The first "you're doing badly" insight

This is the most fragile moment in a financial product. Mint (Intuit) mishandled it for 10 years ("You spent 40% more than last month!"). Cleo turns it into humor. YNAB turns it into penance. **MINT must turn it into a 4-layer answer.**

**Ideal pattern** (Voice System + Identity doctrine):
1. **Fact, neutral:** *"Ton 3a est à zéro cette année."*
2. **Translation:** *"Concrètement, ça veut dire que tu laisses sur la table environ 2'000 CHF d'impôt."*
3. **Personal implication:** *"À ton niveau de salaire, et en Valais, la somme va là où tu ne la récupères jamais. C'est la seule chose que je te signale aujourd'hui."*
4. **Question to ask / next step:** *"Si tu veux, je te montre comment rattraper ça avant le 31 décembre, sans que ça change ton mois."*

**Forbidden:** red icons, exclamation marks, "Attention !", "Tu as un problème", progress bars in deficit red. Shame triggers are banned by CLAUDE.md §6 and feedback_anti_shame_situated_learning.md.

**Rule:** never use red for user state. Red is for alerts on external contracts, never on the user's own numbers.

### Moment 4 — The first paywall / signup wall

**Currently:** there isn't one (good) but the `/auth` screens exist and are reachable. If the team adds a signup wall in the wrong place, it will murder session 2 retention.

**Ideal:** the ONLY legitimate moment to ask for an account is when the user does something that *requires persistence across devices*: save a conversation, sync a couple, export a PDF. Frame it as:
> *"Tu veux retrouver ça sur un autre appareil ? Donne-moi juste un mail, je te renvoie un lien. Pas de mot de passe."*

**Never:** signup wall before value. Signup wall to "save your progress" on session 1. Signup wall to see a number.

**Rule:** signup wall = a cost I levy on the user in exchange for a service I provide. If I have nothing to provide, I can't ask. Magic link by default. Password only if the user opts in.

### Moment 5 — The first time they want to leave the app

This is the most underrated moment in UX. Every designer forgets it. **What happens when Camille closes the app at minute 4?**

**Ideal:** nothing happens. No push notification asking her back. No "Tu nous manques !" email. Silence.

**Then, 2 days later**, a single push: a **continuation of the last thought**. Not a reminder, a continuation.
> *"Hier tu regardais ton taux de remplacement. Si tu veux, j'ai trouvé un angle qu'on n'a pas exploré : le jour où tu quittes la Suisse."*

Not "Reviens !". Not "Tu as laissé des choses en plan !". A thought, picked up where it was dropped. That is the difference between a companion and a chatbot.

**Rule:** notifications are the voice of MINT in absence. They must follow the same 5 voice pillars as on-screen copy. No notification should contain the word "nouveau", "offert", "bravo" or any emoji.

---

## Deliverable C — Critique of the current MINT UX (top 10 failures, with fixes)

Based on `SCREEN_MAP.md` and the screen files I read. Brutal but specific.

### Failure 1 — The Budget infinite loop (LOOP-01)

**What it is:** chat → Budget card → `/budget` (facade) → "Faire mon diagnostic" → `/coach/chat?prompt=budget` → same card → loop.

**Why it happens:** `BudgetContainerScreen` has no data collection — its only CTA is to send the user back to the message that opened it.

**Fix:** the Budget card should **never** route to a "container" screen. It should open a **bottom sheet flow** with 3 sliders or tap-to-type inputs (revenu mensuel, charges fixes, envies). Drawer dismiss → the chat now has a Budget B anchor. Delete `BudgetContainerScreen`.

**Deeper fix:** no card should route to an empty-state screen. If the data isn't there, the card offers to collect it inline. A card is a promise; a facade is a betrayal.

### Failure 2 — `safePop` as a universal fallback (NAV-01)

**What it is:** 21 screens pop to `/coach/chat` when the stack is empty.

**Why it fails:** the mental model becomes "home is the chat" but the chat itself pops to "nothing" (ligne 1377: no-op back button). Users hit the system-level back gesture and get no feedback. Worst case in UX.

**Fix:**
- Typed fallback per screen category: crisis-flow screens fallback to `/coach/chat`, exploration screens fallback to `/` (landing), tool screens fallback to the chat.
- Add `safePop(context, {fallback: Route})` with explicit per-call site.
- For the chat itself: back gesture exits the app (standard iOS/Android behavior). Stop trying to protect the user from leaving; trust the OS.

### Failure 3 — Facade screens (FAC-01, and suspect others)

**What it is:** screens whose only job is to redirect.

**Fix:** delete all facades. Replace with:
- **Either** a real collection flow (bottom sheet).
- **Or** no screen at all; the card itself handles the state.

**Rule of thumb:** if a screen has <80 lines and one button, it's a facade. Kill it.

### Failure 4 — No "Today" surface

**What it is:** returning users land on the raw chat. There is no "where did I leave off / what moved / what's next" surface.

**Fix:** a minimal Today surface (one screen, ~5 components max):
- "Un chiffre a bougé" card (or "rien n'a bougé" honesty line)
- "Le fil de ta dernière conversation" with continue button
- 1 suggested next step (CapEngine output)
- Silence otherwise. No grid. No hubs.

This is NOT a dashboard. This is a **homecoming surface**. It must feel like "ah, il se souvient."

### Failure 5 — The 7-hub Explorer grid

**What it is:** `Explorer` tab with 7 hubs (Retraite, Famille, Travail & Statut, Logement, Fiscalité, Patrimoine & Succession, Santé & Protection).

**Why it fails:** this is IA for the team, not for the user. A user with a job loss doesn't know whether that belongs to "Travail" or "Protection" or "Patrimoine". It's a taxonomy, and taxonomies are the opposite of a companion.

**Fix:** replace the grid with a **search-first surface**. One input: *"Qu'est-ce que tu veux comprendre ?"* with 8-10 chips that match **life moments**, not categories. The chips are the ones from the crisis persona walkthrough. A user types "j'achète un appart" and gets dropped in the chat with that intent pre-loaded.

If the team insists on keeping hubs, fine — but make them secondary, below the search, and label them by **user question**, not category: *"Je veux acheter"*, *"Je prépare une transition"*, *"Je veux comprendre un document"*, *"Je me protège"*. That's the anti-taxonomy move.

### Failure 6 — 40+ shimmed/redirect routes

**What it is:** legacy routes that redirect to `/coach/chat`, creating the illusion of pages that don't exist.

**Why it fails:** dev velocity tax. Each redirect is a trap for a new team member, a test that's hard to write, a possible infinite loop waiting to happen.

**Fix:** one cleanup sprint. For each shimmed route:
- If it's reachable from the current UI, replace with a real destination.
- If it's dead, delete it.
- If it's a deep-link for external compatibility, document it in `route_registry.dart` with an expiry date.

### Failure 7 — The back button is a lottery

**What it is:** the back button does different things depending on how you got to a screen. Sometimes it pops to chat, sometimes to landing, sometimes no-ops.

**Fix:** one universal rule, enforced by one helper: **back always moves one level up in the mental hierarchy**. Mental hierarchy:
1. Landing (anonymous welcome)
2. Chat (conversation)
3. Drawer/bottom sheet (tool or flow inside chat)
4. Sub-page of a tool

Back from 4 → 3. Back from 3 → 2 (dismiss drawer). Back from 2 → exits app on Android, no-ops on iOS (system-level). Back from 1 → exits app. No other rules. No per-screen config. No `safePop` fallback soup.

### Failure 8 — No empty-state discipline

**What it is:** empty states across the app use different patterns (icon + text + button, or illustration + 2 buttons, or just blank).

**Fix:** one empty-state component, 3 variants:
- **Virgin** (no data at all): 1 sentence + 1 action, action opens inline collection.
- **Partial** (some data): 1 sentence that says what we know + 1 action to add more.
- **Waiting** (data exists but not ready): 1 sentence + 1 action to continue last thread.

Never the word "débloquer". Never the word "complet". Never a percentage of profile completeness ("profile à 45%" is a shame trigger — feedback_anti_shame_situated_learning.md).

### Failure 9 — Lightning menu confusion

**What it is:** the lightning (⚡) menu shows contextual tools. Fine in principle. But users don't know it exists until they tap it. And what's inside changes based on context they don't understand.

**Fix:**
- Rename from "lightning" (ambiguous) to a text label: *"Outils"* or, better, a subtle affordance that says *"J'ai 4 outils pour ce que tu racontes"* **in the conversation itself** when the coach detects relevance. The lightning icon stays as a shortcut, but the primary affordance is conversational.
- The menu itself should be a list with labels, not icons-only. Each item: name + 1-line description. No visual clutter.

### Failure 10 — No visible "I am being remembered" signal

**What it is:** the app has `ConversationMemoryService` but the user has no visual proof that MINT remembers them. Trust leaks.

**Fix:** three micro-moments to make memory visible:
- On session 2+ landing: *"Depuis la dernière fois: [change]"* (see Persona 3).
- In any simulator or drawer: pre-filled fields are marked with a soft *"on a déjà ça"* chip that's dismissible.
- In chat, when the coach uses a memorized fact, it says so: *"Vu ton canton (Valais) et ton salaire à peu près connu, voici…"*. Showing = trust.

---

## Deliverable D — The anti-shame framework applied to navigation

CLAUDE.md says financial shame is the structural enemy. Most anti-shame work happens in copy. But navigation is shame too — every dead-end, every "complete your profile", every "restricted" screen is a shame signal disguised as information architecture.

### Navigation patterns that CREATE shame (to avoid)

1. **Profile completion percentages.** "Ton profil à 35%" = you are 65% incomplete = you are behind.
2. **Locked icons on features.** Anything with a padlock says "you're not worthy yet". Never.
3. **"Débloquer" as a verb.** Implies the user is currently blocked by their own incompetence.
4. **Progress bars that stall.** A stalled progress bar is a daily reminder of inaction.
5. **Streak counters that break.** The day the streak breaks, the user deletes the app. YNAB learned this the hard way.
6. **Red numbers for user state.** Red should be reserved for alerts on external risks (contract, deadline), never on "your own situation".
7. **Empty hubs that say "rien à afficher pour l'instant".** The user reads "rien à afficher" as "tu n'as rien fait de ta vie".
8. **"Vous avez loupé X".** Any framing that implies a missed opportunity is a shame trigger.
9. **Comparisons, even flattering ones.** "Tu fais mieux que la moyenne" is still a comparison and still banned (CLAUDE.md §6).
10. **Dead ends with no path forward.** A dead end is the navigation equivalent of "you don't belong here".

### Navigation patterns that REDUCE shame (to embrace)

1. **Honest silence.** When there's nothing to say, say nothing. "Rien n'a bougé cette semaine. C'est OK." is more respectful than confetti.
2. **Continuation, not progress.** Instead of "you are at step 3 of 7", say "on en était là la dernière fois". No bar, no count.
3. **Inline data collection.** Never send a user to a separate "profile setup" screen. Collect what you need, when you need it, in the flow.
4. **Pre-filled everything.** Every field MINT already knows should be pre-filled, visibly, with the soft option to correct. Never ask twice.
5. **Reversibility.** Every action has an undo. Every input can be edited. Never trap the user in a choice.
6. **"On" instead of "tu dois".** "On regarde ça ensemble" carries the user. "Tu devrais" shames the user for not already.
7. **Conditional language for all projections.** "Pourrait", "environ", "si" — never "tu auras" or "tu n'auras pas".
8. **Intent-first navigation.** The user names their situation ("j'achète un appart"), the system routes. The user never has to know the product's taxonomy.
9. **Memory of the last session** made visible on return. Shows the system cares.
10. **Exits without questions.** The user leaves the app without being asked why, without a "are you sure?" dialog, without a dark-pattern retention screen. Respect = no friction on exit.

---

## Deliverable E — Suggested mental model (one sentence)

Rejected candidates:
- *"MINT est un coach financier dans ta poche."* — too generic, describes 200 apps.
- *"MINT est ton dashboard financier suisse."* — lies, MINT is not a dashboard.
- *"MINT est ton assistant AI pour la finance."* — flat, commodity.
- *"MINT, c'est une conversation qui se souvient de toi."* — closer but too abstract.

**My recommendation:**

> **MINT, c'est une conversation calme avec quelqu'un qui connaît le système suisse et qui prend ton parti. Tu parles, il traduit, il te montre ce qu'on ne te dit pas. Tout le reste (outils, calculs, documents) vient à toi quand tu en as besoin — jamais avant.**

One sentence, a little long, on purpose. It encodes:
- **Conversation** as the primary object (not tabs, not hubs).
- **Calme** (voice pillar 1).
- **Suisse specificity** (non-negotiable differentiator).
- **"Prend ton parti"** (the identity doctrine, verbatim).
- **Translation**, not advice (compliance-safe, doctrine-aligned).
- **"Ce qu'on ne te dit pas"** (the tagline, embedded).
- **Tools come to you** (inversion: the chat invokes tools, not the other way around).
- **"Quand tu en as besoin, jamais avant"** (anti-grid, anti-dashboard).

Short version for onboarding copy: **"Tu parles. Je traduis. Je te montre ce qu'on ne t'explique pas."**

---

## Closing — what I'd ship first if I were running this sprint

Not a roadmap. A priority order, because the team asked for concrete.

1. **Kill the Budget loop this week.** Delete `BudgetContainerScreen`, replace the ResponseCard target with a bottom-sheet inline collector. (1 day.)
2. **Rewrite `safePop` with typed fallbacks.** Audit the 21 call sites. Back button becomes predictable. (2 days.)
3. **Ship the Today surface for returning users.** One screen, one "chose qui a bougé", one continuation button. (3 days.)
4. **Rename and restructure Explorer.** Replace the 7-hub grid with a search + 8 life-moment chips. Hubs become secondary. (3 days.)
5. **Empty state discipline.** One component, 3 variants, applied across the ~15 screens that have custom empty states. (2 days.)
6. **Delete the 40 shimmed routes.** Mechanical cleanup, no judgment calls. (1 day.)

That's a 2-week sprint. It will not rebuild the visual system. It will not add a feature. It will give MINT back its mental model.

After that, and only after, touch the visuals.

**End of review.**
