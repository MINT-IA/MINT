# MVP Wedge — refonte design (2026-04-24)

**Source:** design panel 2026-04-24 on P0-4 (Julien screenshots of 18:36 flow).

**Panel:** ex-Cleo designer, ex-Cleo growth marketer, Swiss fintech product lead, conversational UX lead.

**Context:** Feature flag `enableMvpWedgeOnboarding` is **OFF by default**. This doc specs the refonte of the existing MVP wedge storyboard for when Julien decides to flip the flag. PR 30.17 ships the *minimal* kill of the most egregious scene (T9 email-demain). Remaining scene-level refonte work is specified here for a follow-up PR.

---

## What shipped in PR 30.17 (this PR)

**Kill** of the T9 "Laisse-moi un email, je te retrouve demain" step:
- `OnboardingStep.magicLink` removed from enum
- `_MagicLinkStep` widget deleted (~150 LOC)
- `_email` field + `setEmail` method removed from provider
- `_BifurcationStep` (T8) becomes **terminal**:
  - "Creuser" → flush + navigate `/coach/chat`
  - "Plus tard" → flush + navigate `/home`
- Tests updated 7/7 green, flutter analyze clean
- Auth conversion still happens via existing `auth_gate_bottom_sheet` after 3 anonymous coach messages (unchanged)

**Rationale:** "Email demain" was the most egregious pattern — user-eject at peak value. Killing this alone removes the most obvious retention killer. Flag stays OFF so zero user impact in prod.

---

## What the panel recommended (not in this PR)

### 1. Scene "Ta retraite projetée" — Refonte from prediction → levier

**Current state (T7 scène for `OnboardingIntent.retraite`):** shows "CHF 4'653 – 6'210 / mois dès 65 ans" + slider âge d'espérance de vie + cumulé 20 ans.

**Problems (panel verdict):**
1. **False precision over 31 years.** 1.5-3.5% rendement compound on 31 years = real range CHF 2k-CHF 12k. The displayed range lies about uncertainty.
2. **Retraite-first even when intent = retraite.** Rule 3 violation by normalising: even an opt-in retraite intent should get *present-day agency*, not a 31-year-out prediction.
3. **No confidence band.** Phase 36 FIX-09 requires EnhancedConfidence 4-axis on any projection — absent here.
4. **No levier actionable.** "Slide life expectancy" is passive. User walks away with a number, not with something to do this month.

**Target design (Cleo-DNA applied):**
- Hero line: **what can move this month**, not 31 years out. Example for intent=retraite at 34yo: *"Cette année, tu peux mettre CHF 7'056 en 3a. Tu cotises X, l'écart c'est ton espace de choix."*
- Dashed-border "hypothèse" line (micro italics, discreet): *"Si tu continues à ce rythme, tu arriveras à 65 entre CHF X et Y/mois — fourchette large, on affinera."* Only shown if user taps "me montrer la projection quand même".
- Confidence chip (4-axis EnhancedConfidence): visible, not negotiable.
- No slider, no cumulated-20-years number. If user wants to play with scenarios, route to existing `/retirement` screen (already exists, has proper confidence treatment).

**Scope:** 1 new widget `MintSceneLevierPresent`, replaces `MintSceneRenteTrouee` for intent=retraite. ~1 day design + 2 days Flutter.

---

### 2. Dossier — Rename "Intention: Ma retraite" → open-ended tag

**Current state:** First line of dossier strip = "Intention · Ma retraite" (hierarchical title).

**Problem:** Reinforces retraite-first even when user just picked it as one interest among many. Makes it feel "locked in" rather than "we started here, we can pivot."

**Target design:**
- Top of dossier becomes "Ton contexte" (neutral)
- First tag: small pill, not hierarchical title, text like "tu m'as parlé de retraite" (conversational, past tense, reversible)
- User can tap the pill to change/remove (surfaces an intent re-selector)

**Scope:** Refactor `dossier_strip.dart` intent entry. ~0.5 day.

---

### 3. Conversion moment — Apple/Google inline in chat, not as a step

**Current state:** MVP wedge tries to collect email. Anonymous chat (`/anonymous/chat`) already has an `auth_gate_bottom_sheet` that appears after 3 messages.

**Target design:**
- Unify both flows : MVP wedge flush → land in /coach/chat (**shipped in this PR**).
- Continue relying on existing `auth_gate_bottom_sheet` for conversion.
- Sheet copy to audit : today's copy is likely generic ; Cleo-grade copy = *"Tu veux qu'on garde ce qu'on vient de faire ?"* + Apple/Google buttons. No email field anywhere.

**Scope:** Audit `auth_gate_bottom_sheet.dart` copy, possibly 1 ARB copy change ×6 langs. ~0.5 day.

---

### 4. Out of scope for wedge refonte (but surfaced by panel)

- **v2.9 Chat Vivant** alignment — inline scenes in chat bubbles instead of full-screen storyboard. Big rewrite (5-7 days per v2.9 audit), post-Phase 36.
- **Cleo-style tone switch** — "doux / direct / sans filtre" already exists as `VoicePreference` enum in profile.py. Wire into wedge copy ? Defer to v2.9.
- **Roastable moments** — Cleo's viral growth lever. MINT-Swiss-compliant version TBD with Julien.

---

## Follow-up PRs

| Scope | Effort | Depends on |
|-------|--------|------------|
| Scene "Levier présent" refonte (§1) | 3-4 days | Julien approval of copy |
| Dossier pill refactor (§2) | 0.5 day | — |
| Auth gate copy audit (§3) | 0.5 day | ARB parity pattern (established) |
| Flip `enableMvpWedgeOnboarding = true` | 0 dev | All 3 above shipped + creator-device gate |

---

## Decisions locked in this PR

1. ✅ T9 email-demain **KILLED** (code deleted, tests updated).
2. ✅ T8 bifurcation is **terminal** (flush + navigate).
3. ✅ Auth conversion stays in existing `auth_gate_bottom_sheet` after 3 coach messages.
4. ⏳ Scenes T7 refonte **SPEC'D** here, implementation pending Julien approval.

## Decisions deferred to Julien

- Approve "Levier présent" scene design (§1) — go/iterate/kill.
- Approve dossier pill refactor (§2) — nice-to-have or P0.
- Timing of `enableMvpWedgeOnboarding = true` flip.
