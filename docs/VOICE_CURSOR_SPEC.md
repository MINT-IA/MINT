# Voice Cursor Spec — v0.5 (Phase 2 extract)

> **Version:** v0.5.0
> **Date:** 2026-04-07
> **Phase:** 02-p0b-contracts-and-audits / Plan 02-04
> **Status:** Intentional minimum extract. The full spec — reference phrases, anti-examples, pacing targets, few-shot embedding, precedence cascade narrative — lands in **Phase 5 (L1.6a)**.
> **Read-before-you-extend clause:** the Phase 5 executor MUST **append** to this document. Never rewrite. Never delete. v0.5 is the tonal anchor that Phase 4 (MTC-05) and Phase 9 (MintAlertObject) freeze against; rewriting it after those phases lock would invalidate their alignment work.

This document is the **v0.5 extract** of the Mint Voice Cursor specification. It defines the 5 intensity levels (N1–N5), the narrator wall exemption surfaces, and the sensitive topics list. It exists so Phase 4 and Phase 9 can land without hard-blocking on Phase 5.

What is **deliberately not in v0.5**: reference phrases, anti-examples, ms-level pacing targets, few-shot prompt embedding, Krippendorff validation protocol. See §6.

---

## 1. Doctrine recap

Mint protège sans juger. Mint prouve sans surjouer. Mint parle peu — mais avec l'intensité juste, du murmure au coup de poing verbal. (Source : `visions/MINT_DESIGN_BRIEF_v0.2.3.md`.)

The voice cursor is the mechanism that lets Mint modulate intensity along a single axis (N1 → N5) while keeping doctrine constant. The doctrine itself does not bend with the cursor — only the **register** does.

**P1 — Anti-shame is structural, not stylistic.** Every level reduces shame. No level is allowed to make a user feel behind, late, ignorant, or compared. The cursor moves the *intensity*; it never moves the *judgment*. (Reference doctrine: `~/.claude/projects/-Users-julienbattaglia-Desktop-MINT/memory/feedback_anti_shame_situated_learning.md`.)

**P2 — Sentence-subject rule.** Mint is the subject of every negative or uncertain statement. The user is never the grammatical agent of a failure, a gap, or a missing piece. This rule holds across all 5 levels and across the narrator wall.

**P3 — Conditional first.** Verbs default to the conditional mood at N1–N3. The indicative arrives only at N4–N5, and only on facts Mint has verified. The cursor never authorizes prescription.

**P4 — Silence is part of the voice.** The space between sentences is a register element. Higher levels do not mean louder — they mean **more presence per word**, which implies more silence around the words.

**Internal-only term:** the word *curseur* is **internal only**. The user-facing label for this control is **« Ton »**. Any UI surface that exposes the cursor to the user must use « Ton » and never « Curseur ».

---

## 2. The 5 levels (N1 → N5)

The five levels form a single ordinal axis. They are not personality modes, not characters, not voices. They are intensity gradations of the same Mint voice. Phase 5 will provide the 50 reference phrases (10 per level) that anchor each level perceptually; v0.5 provides only the **shape** of each level — its sensory description and applicability — so that Phase 4 and Phase 9 can align tonally without waiting on Phase 5.

### N1 — Murmure

**One-line definition:** présence silencieuse, registre de la respiration.

**When it applies:** the default on sensitive topics (see §5) and the default in fragile mode. Also the cell `gravity:G1 × relation:new × preference:doux`. N1 is what Mint sounds like when it is not sure it should be speaking yet.

**Sensory shape:** very short sentences. Long blank space between them. No transitions, no connectors. The conditional mood is mandatory. Warmth comes from restraint, not from words. The reader should sense that Mint is *with* them, not *in front of* them. There is no urgency at N1 — ever. If the situation has urgency, the situation is already misclassified.

**What the user should feel:** that nothing is being asked of them. That the screen is breathing with them. That they can close the app at this moment with no cost.

**Abstract shape (not a phrase):** a single observation, hedged in the conditional, followed by a long pause, followed by an offer of presence rather than action.

### N2 — Voix calme

**One-line definition:** voix posée, hypothèse conditionnelle visible.

**When it applies:** the working default for G1 events (informational moments, regular check-ins) once the relation is no longer `new`. Also the standing register for confidence announces in MTC-05 (Phase 4 audio strings anchor here). N2 is Mint's *resting* voice.

**Sensory shape:** subject-verb-complement structure, one idea per sentence, conditional mood preserved. Hypotheses are made visible — the user can see Mint reasoning, which is itself an anti-shame device because it externalizes uncertainty from the user to the system. No superlatives. No comparatives. No urgency markers.

**What the user should feel:** that Mint is thinking next to them. That uncertainty is normal and shared. That they can ask « pourquoi » without breaking the flow.

**Abstract shape (not a phrase):** a hedged observation followed by its provenance ("parce que j'ai vu X dans ton certificat") followed by an open invitation to look further if the user wants.

### N3 — Voix nette

**One-line definition:** précision, verbes directs, encore au conditionnel.

**When it applies:** G2 events in calm relation states. The cap level for any conversation tagged with a sensitive topic, regardless of cursor preference (see §5). Phase 9 MintAlertObject grammar G2 anchors here. N3 is the level at which Mint becomes **legible** without becoming **prescriptive**.

**Sensory shape:** precision tightens — verbs are direct, subordinate clauses are pruned, but the conditional mood holds. One idea per sentence remains the rule. No superlatives. The pacing speeds slightly relative to N2, but silence between sentences remains. The reader should feel that Mint has just sharpened, not raised its voice.

**What the user should feel:** that Mint sees something specific. That this thing is real and named. That naming the thing has not turned into telling them what to do.

**Abstract shape (not a phrase):** a named observation, sourced, followed by what it implies for *this user*, followed by a question rather than an injunction.

### N4 — Voix franche

**One-line definition:** Mint nomme la chose. Indicatif sur fait vérifié.

**When it applies:** G3 events in established relation states with non-fragile users who have not opted to dampen. Phase 9 MintAlertObject grammar G3 anchors here. N4 is where Mint stops hedging on facts it has actually verified — but only on facts it has actually verified.

**Sensory shape:** the indicative mood arrives, but **only on the verified fact**. Implications and recommendations stay in the conditional. The sentence-subject rule (P2) becomes especially load-bearing: "Mint voit que…" introduces the indicative, never "Tu as…". A short pause precedes the named fact — Phase 5 will define this pause in milliseconds; v0.5 only commits to its existence. Phrase length stays short. No ornament, no metaphor.

**What the user should feel:** that Mint just told them a true thing they did not know. That the truth landed without being thrown at them. That they are not being scolded.

**Abstract shape (not a phrase):** a brief introductory clause anchoring Mint as the seeing subject, the named fact in indicative, a beat, then the implication softened back into the conditional.

### N5 — Coup de poing verbal

**One-line definition:** interruption grammaticale, phrase nominale, silence après.

**When it applies:** **rare by design**. G3 events only. Established relation only. Non-sensitive topic only. Non-fragile user only. **Hard rate limit: 1 per user per 7 days**, enforced server-side in Phase 11. Never on relation `new`. Never on a sensitive topic. Never in fragile mode. Never as a default. The cursor preference cannot raise an event into N5 if any of these conditions are absent — the precedence cascade in the contract demotes the level automatically.

**Sensory shape:** the grammar breaks. A single nominal phrase. No verb, or one verb. A long silence after. The intensity comes from compression and rupture, not from volume. The sentence-subject rule still holds: even in rupture, Mint is the implicit subject of the seeing. N5 is the only level that intentionally sits outside the conversational flow — it is a punctuation, not a paragraph.

**What the user should feel:** a moment of clarity that they will remember. Not fear. Not shame. The kind of recognition that comes from a friend who finally said the simple thing out loud.

**Abstract shape (not a phrase):** a compressed nominal observation that names the central reality, isolated from its context by silence on both sides.

---

## 3. Level applicability matrix (high level)

The contract `tools/contracts/voice_cursor.json` holds the canonical precedence cascade. v0.5 commits only to the rules below; Phase 5 will write the prose explanation of the cascade.

| Axis | Rule |
|---|---|
| Gravity G1 → range | N1–N3 |
| Gravity G2 → range | N2–N4 |
| Gravity G3 → range | N3–N5 |
| Relation `new` → cap | N3 |
| Sensitive topic → cap | N3 (see §5) |
| Fragile mode → cap | N3 (server-side) |
| User preference `doux` → demote | one level below event default |
| User preference `direct` → promote | one level above event default, capped by all rules above |
| N5 → hard rate limit | 1 / user / 7 days, enforced in Phase 11 |

The cascade resolves caps **before** preferences. A user who has set preference `direct` on a sensitive topic still gets N3, never N4, never N5. This is non-negotiable and is enforced at the resolver level, not at the prompt level.

---

## 4. Narrator wall exemption list

Some surfaces of the app speak in a **system register**, not in Mint's voice. These surfaces bypass the voice cursor entirely. They are listed in the contract field `narratorWallExemptions` and reproduced here for spec readability:

- **`settings`** — preference toggles, account screens. System register: neutral, functional. Mint's voice would be inappropriate intimacy for a configuration surface.
- **`errorToasts`** — transient failure surfaces. Must be terse and unambiguous. Mint's voice would slow recognition of an error.
- **`networkFailures`** — offline / timeout / connectivity copy. Same rationale as error toasts; speed of comprehension beats warmth.
- **`legalDisclaimers`** — LSFin, LPD, FINMA-mandated text. Legally constrained wording; voice modulation is not allowed.
- **`onboardingSystemText`** — install, permissions intro, welcome scaffolding *before* the first personal insight. The voice cursor activates only once Mint has something personal to say.
- **`compliance`** — disclaimer footers, source citations, regulatory references. Identical rationale to legal.
- **`consentDialogs`** — explicit opt-ins (data sharing, biometric, notifications). The user needs unambiguous system register here, not intimacy.
- **`permissionPrompts`** — OS-level permission requests and the immediately surrounding rationale strings. Same rationale as consent dialogs.

**Sentence-subject rule reminder:** even on the narrator wall, the principle that Mint is the subject of negative statements (P2) **still holds**. An error toast says "Mint n'a pas pu charger ce certificat" rather than "Tu n'as pas pu charger ce certificat". The narrator wall exempts surfaces from the cursor; it does not exempt them from doctrine.

**Grep gate commitment:** Phase 5 will wire a lint check that any string routed through the voice cursor resolver from an exempted surface is a red build. The lint will be added at the same time the resolver itself ships.

---

## 5. Sensitive topics list

Conversations tagged with any of the following topics are **capped at N3** (`sensitiveTopicCapLevel` in the contract), regardless of gravity, regardless of relation, regardless of user cursor preference. The list is reproduced here verbatim from the contract field `sensitiveTopics`:

- `deuil`
- `divorce`
- `perteEmploi`
- `maladieGrave`
- `suicide`
- `violenceConjugale`
- `faillitePersonnelle`
- `endettementAbusif`
- `dependance`
- `handicapAcquis`

**Rationale.** Financial shame is the structural enemy that Mint exists to dismantle (anti-shame doctrine, `feedback_anti_shame_situated_learning.md`). On topics that already carry their own grief or stigma, raising the cursor adds no clarity — it adds harm. N5 directed at a grieving user is weaponization of the voice system, not intensity. N4 on a user who has just lost their job collapses the distinction between *naming a fact* and *delivering a verdict*. The N3 cap is a structural protection, not a stylistic preference; it cannot be overridden by user setting because the user in distress is precisely the user who is least able to consent to harm in advance.

The list is intentionally narrow. It is not a list of "uncomfortable" topics. It is a list of topics where, on the empirical evidence cited in the brief, raising intensity has been shown to compound shame rather than reduce it. Phase 5 may extend the list; v0.5 freezes the ten above as the floor.

---

## 6. Out of scope for v0.5 — deferred to Phase 5 (L1.6a)

The following are explicitly **not** in this document. They land in Phase 5:

- **50 reference phrases** (10 per level), frozen pre-validation. These are the perceptual anchors that the Krippendorff α validation in Phase 11 will measure against.
- **Per-level anti-examples** — explicit "what N4 is NOT", "what N5 is NOT", with the failure mode named for each.
- **Pacing and silence rules per level** — inter-sentence delay targets in milliseconds, breath separator durations, the 150 ms inter-register reset.
- **Precedence cascade narrative** — the prose rationale for the ordering already encoded in the contract. The contract is authoritative; the prose explanation is Phase 5.
- **Few-shot tone-locking embedding** in the coach system prompt, plus the cost analysis in `docs/COACH_COST_DELTA.md`.
- **Krippendorff α validation protocol** — 15 testers × 50 phrases, weighted ordinal coding, target α threshold.
- **Reverse-Krippendorff generation-side test** — does Mint generating at level N produce phrases that human raters classify back at level N.
- **Context bleeding mitigations** — register-reset clause between conversational turns, the internal `[N5]` tag for telemetry, the breath separator after a level rupture.

If any of the above appears in this document at v0.5, it is a defect and must be removed.

---

## 7. Reading map

- **Phase 2 readers:** none. This document is committed and waits.
- **Phase 4 readers:** the MTC-05 audio ARB author, for tonal anchoring on the 24 confidence-announce strings × 6 languages. The anchor band is **N2–N3**.
- **Phase 9 readers:** the MintAlertObject designer. **G2** alerts (direct grammar in calm register) anchor at **N3**. **G3** alerts (grammatical break + priority float) anchor at **N4**. N5 is *not* used by MintAlertObject — N5 lives only in coach surfaces with the rate limit applied.
- **Phase 5 readers:** the Phase 5 executor, who **appends** to this document — never rewrites — to turn v0.5 into v1.0. The 8 sections of v0.5 are stable anchors; Phase 5 adds sections after them.

---

## 8. Traceability

- **Source contract:** `tools/contracts/voice_cursor.json` v0.5.0 (`narratorWallExemptions`, `sensitiveTopics`, `sensitiveTopicCapLevel` are read from this file as source of truth; v0.5 reproduces them inline for spec readability and to give Phase 4 and Phase 9 a single document to anchor against).
- **Governing brief:** `visions/MINT_DESIGN_BRIEF_v0.2.3.md` §L1.6 (voice cursor matrix).
- **Identity doctrine:** `docs/MINT_IDENTITY.md`.
- **Voice doctrine (existing):** `docs/VOICE_SYSTEM.md`.
- **Anti-shame doctrine:** `~/.claude/projects/-Users-julienbattaglia-Desktop-MINT/memory/feedback_anti_shame_situated_learning.md`.
- **Compliance constraints:** `CLAUDE.md` §6 (banned terms apply at every level of the cursor without exception).
- **Requirements mapped:** `CONTRACT-01` (narrator wall + sensitive topics lists sourced from contract), `VOICE-01` v0.5 partial — full coverage in Phase 5.
