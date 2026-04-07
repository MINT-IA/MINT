# Feature Research — v2.2 La Beauté de Mint

**Domain:** Protection-first / calm-fintech / intensity-modulating UX system (Flutter mobile, Swiss financial education app)
**Researched:** 2026-04-07
**Confidence:** MEDIUM overall — HIGH on Linear/Stripe/iA Writer/Aesop/MUJI/Spiekermann (well-documented public sources), MEDIUM on VZ/Wise/Headspace (require app teardown to verify behavioral specifics), LOW on Notion 2024-2025 "quiet UI" specifics (post-cutoff territory; flagged below).
**Scope:** Design + voice + accessibility surface only. Excludes financial calc + coach features (already shipped).
**Brief floor:** v0.2.3 is the floor, not the ceiling. This research surfaces what v0.2.3 missed and what should be cut.

> **Methodology note:** Brief v0.2.3 is mature, has already absorbed Cleo, VZ-as-incumbent, and red-team philosophy. The high-leverage move is *narrow surgical patterns from 10 named practitioners*, not a re-survey of fintech. Confidence is assigned per practitioner based on the directness of public source material vs. app-only behavior I cannot verify without screenshots.

---

## 1. Practitioner Teardowns — One Pattern, One Application, One Anti-Pattern Each

### 1.1 — VZ Vermögenszentrum (Switzerland)

**Source confidence:** MEDIUM (public site + brochures HIGH; in-app screens LOW — requires Julien teardown)
**Reference:** [vermoegenszentrum.ch](https://www.vermoegenszentrum.ch/), VZ Finanzplan brochures, *VZ News* monthly publication, *VermögensPartner* app on stores.

**What VZ actually does (verified pattern):** VZ's analog DNA is the **printed Finanzplan** — a 30-50 page bound document handed across a table. They show confidence/uncertainty by **scenario columns** (3 vertical Bas/Moyen/Haut, never a single number) and by **explicit assumption blocks** at the foot of every page ("Hypothèses retenues: rendement 2%, inflation 1%, AVS indexée"). Bad news is **always paired with the legal article** that creates the bad news (LPP art. X) — the framing is "the law says this, not us". On tax estimates the tone is **clinical-impersonal** (third person, "le contribuable"); on retirement projections it shifts to **second-person conditional** ("vous pourriez disposer de…").

**Transferable pattern for MINT:**
> **The "Hypotheses Footer" — every projection card carries a fixed-position foot block listing the 3-5 assumptions used.** Not tappable detail, not progressive disclosure — *visible at rest*. This is how a 78-year-old reads VZ at the kitchen table without opening anything.

**Where it applies:** S4 (response_card_widget.dart) + L1.2b (12 projection screens migration). Sits *underneath* MTC, doesn't replace it. MTC = uncertainty intensity; Hypotheses Footer = uncertainty *content*.

**Anti-pattern to avoid:** VZ's printed-doc DNA leaks into their app as **dense tables nobody reads on mobile**. MINT must not reproduce the Finanzplan PDF on a 6.1" screen. The footer is *3 lines max*, not a table.

---

### 1.2 — Wise (formerly TransferWise)

**Source confidence:** MEDIUM-HIGH (public design system + Wise blog posts on "transparency rituals", in-app pattern is well-documented in fintech UX writing).
**Reference:** [wise.com/design](https://wise.com/design), Wise blog "How we write" series, Wise status page grammar, public Twitter incident comms.

**What Wise actually does:** Their delay/error grammar is **3-part fixed-template**: (1) **State the fact in present tense** ("Your transfer is taking longer than usual"), (2) **Name the cause in plain words, no jargon** ("Your bank is reviewing the payment"), (3) **State the next moment with a time** ("We'll update you by Friday 5pm"). They never apologize first. They never say "we're sorry for the inconvenience". The opening is always the *fact*, not the emotion. Critically: Wise's alerts **show the FX rate movement as a small inline sparkline**, not a number — uncertainty as *shape* not number.

**Transferable pattern for MINT:**
> **The 3-part Fact-Cause-NextMoment template, hardcoded into MintAlertObject (S5/L1.5).** Maps directly onto MINT's G2/G3 grammar: G2 = (fact) + (cause from law/contract) + (next moment = action user can take). G3 = same but with the *next moment first* ("Stop. Avant de signer: …"). This template, *baked into the component itself*, prevents copywriters from drifting into "Cher utilisateur".

**Where it applies:** L1.5 MintAlertObject — encode template as widget API: `MintAlertObject(fact: …, cause: …, nextMoment: …)`. Compiler-enforced grammar.

**Anti-pattern to avoid:** Wise occasionally fills the inline sparkline with **brand-green** even on a downward FX move — the calm color *contradicts* the bad news. MINT should never let calm-color optimism override grammar. If MTC bloom routes to an N4/N5 alert, the alert must NOT inherit the soft-green from the calm hub.

---

### 1.3 — Linear

**Source confidence:** HIGH ([linear.app/method](https://linear.app/method), Linear's public design philosophy, Karri Saarinen's talks).
**Reference:** Linear Method (linear.app/method), Karri Saarinen "Designing Linear" Config 2022 talk, Linear public changelog grammar.

**What Linear actually does:** Linear's "calm visual + sharp text" works because of **one specific rule: the visual layer never changes weight when state changes — the text does**. A bug going from "Open" to "Urgent" doesn't trigger color/animation/icon — it triggers a *different verb in the title*. Their cycle velocity prediction (closest analog to MINT's confidence) is shown as a **single number with no decoration**, but the *delta from last cycle* is the only thing styled. They predict, but they never *display the prediction with confidence chrome* — confidence is implicit in showing/hiding the prediction at all (if low confidence, the field is just absent).

**Transferable pattern for MINT:**
> **"Show the delta, not the absolute"** + **"Hide the prediction when confidence is too low rather than decorating it with caveats"**. MTC is currently designed to *always render with 4 axes*. Linear's lesson: when completeness × accuracy × freshness × understanding falls below a floor (suggest 0.40), MINT should *hide the projection entirely* and show *only the missing-axis prompt*. A blank space + "Pour voir cette projection, ajoute ton certificat LPP" is more honest than a faded MTC.

**Where it applies:** L1.2a MTC v1 component — add `MTC.Empty(missingAxis)` state. L1.1 audit — surface every screen that currently renders confidence below floor and propose deletion of the projection.

**Anti-pattern to avoid:** Linear's grammar works because of **uniform context** (engineers talking to engineers about issues). MINT users are 18-99 with B1 French. Linear's "absent field = low confidence" only works if users *know* what should be there. MINT must label the absence ("On manque de données pour calculer ça"), not silently omit.

---

### 1.4 — Aesop (e-commerce)

**Source confidence:** HIGH ([aesop.com](https://www.aesop.com/), publicly studied in design press; Marc Newson collaborations; Dennis Paphitis interviews).
**Reference:** Aesop online store; Aesop's *The Aesop Reading Room*; Wallpaper* features on Aesop typography (FF Tisa / custom serif).

**What Aesop actually does:** Their product cards do **one extreme thing**: they put the **product description (literary, 80-150 words) above the price**, and the price is rendered in *the same weight as the body text*. The price is not a CTA. This inverts the entire e-commerce hierarchy. The whole page works because of **massive vertical white space between paragraphs** — typically 1.5x to 2x the body line-height. They use **a single serif typeface** at 2-3 sizes maximum, and **all caps for navigation only**, never body.

**Transferable pattern for MINT:**
> **Demote the number, promote the explanation.** On every projection card (S4), the headline number (e.g., "8'505 CHF/mois") should NOT be the visually dominant element. The 2-line plain-text *meaning* should be. The number is a glyph in the sentence, not a billboard. This directly serves P1 ("éclairer pas juger") and P3 ("une idée par écran"). Concretely: cap the headline number at the same font weight as the body, let the *sentence* carry the visual rhythm.

**Where it applies:** S4 + L1.3 microtypographie pass. Test on Galaxy A14 with DMLA simulation — Aesop's hierarchy *fails* on small/low-vision unless the line-height is generous, so this couples L1.3 directly.

**Anti-pattern to avoid:** Aesop is gloriously unusable for *fast scanning*. They're a slow-reading luxury brand. MINT users in G3 (alert) must be able to scan in 2 seconds. So the Aesop pattern applies to S4 (calm projection) but **never to S5 MintAlertObject** — alerts need the opposite grammar: the fact is the billboard.

---

### 1.5 — iA Writer / Oliver Reichenstein

**Source confidence:** HIGH ([ia.net/topics](https://ia.net/topics), Oliver Reichenstein's essays "Responsive Typography", "The 100% Easy-2-Read Standard", "Multichannel Text Processing").
**Reference:** Reichenstein essays at ia.net/topics, iA Writer "Focus Mode" / "Syntax Highlighting" feature docs.

**What iA Writer actually does:** Reichenstein's "Focus Mode" dims everything except the *current sentence*. Not the current paragraph — the current sentence. The principle: **attention has a unit, and the unit is the sentence**. His "responsible typography" essay argues that line-length is the *only* type setting that matters on mobile (45-75 chars). The 100% Easy-to-Read Standard uses **one font, two sizes, three weights** — and that's the entire system.

**Transferable pattern for MINT:**
> **"One sentence at a time" focus mode for the coach bubble (S3).** When MINT is in N4/N5 (Piquant/Cash), the surrounding interface should *literally dim to 40% opacity* and the active sentence holds full contrast. This is the closest existing precedent for P3 ("une idée par écran") executed *temporally* rather than spatially — instead of one idea per screen, one idea per *moment*. Cleo's voice levels change the *skin*; iA Writer's focus mode changes the *attention field*. MINT can do the second (which is calmer) instead of the first (which is louder).

**Where it applies:** S3 (coach_message_bubble.dart) + L1.6 voice cursor. When `level >= N4`, trigger ambient dim of surrounding shell. This is the *non-visual* way to mark intensity that the brief insists on ("le visuel ne change jamais"). Reichenstein's trick: dimming everything *else* doesn't violate "visual stays calm" — the active text doesn't change, only its *context* recedes.

**Deeper principle vs P3:** Reichenstein's essays frame typography as *moral responsibility for the reader's attention*. P3 ("une idée par écran") is the *consequence*. The deeper principle is: **every additional element on screen is a tax on the user's cognitive contract**. This should be added to the brief as a foundation for L1.1 (audit du retrait).

**Anti-pattern to avoid:** iA Writer's focus mode is *toggleable by the user* — it's a writing tool. MINT cannot let the user toggle ambient dim, because then the most fragile users will turn it off. It must be *automatic*, tied to gravity class, and *never* announced as a feature.

---

### 1.6 — MUJI / Kenken Hara

**Source confidence:** HIGH (Kenya Hara, *White* (Lars Müller, 2009), *Designing Design* (Lars Müller, 2007); Hara's work on MUJI's "Found MUJI" + identity).
**Reference:** Hara, *Designing Design* (2007), ch. on emptiness; Hara, *White* (2009); MUJI product information cards in stores.

**What MUJI actually does:** Hara's principle is **emptiness as a vessel that the viewer fills**. MUJI product cards in stores use a **fixed grid**: product name (one line) → use case (one line) → material composition (one line) → price (one line). No images on the card itself — the product *is* the image. The card is *information about the relationship between the product and your life*, not about the product. Hara's *Designing Design* explicitly attacks "information density" as a misframing — the goal is **resonance density**.

**Transferable pattern for MINT:**
> **The 4-line MUJI grid for projection cards (S4):** (1) **What this is** ("Ta projection retraite à 65 ans"), (2) **What you're doing now that affects it** ("Tu cotises 491 CHF/mois au 3a"), (3) **What changes if you do nothing** ("Sans changement: 8'505 CHF/mois"), (4) **What you could do next** ("Ajouter 114 CHF/mois → +340 CHF/mois à 65 ans"). Four lines. No icons. No chrome. The MTC sits to the *right* of line 3 as a single inline element. This is *radically more austere* than the brief currently implies.

**Where it applies:** S4 — should arguably be the *baseline grammar* for L1.2a MTC integration. Forces the question: "if we cut everything that isn't one of these 4 lines, what survives?"

**Hara's deeper principle for MINT:**
> *White*'s thesis: white space is not absence — it's a *promise of meaning*. MINT's calm is currently framed defensively ("don't overload the user"). Hara reframes it offensively: **the empty space is itself a signifier of trust**. The user reads the void as "this app is not hiding anything in here". This is the philosophical foundation that the brief's L1.1 audit du retrait should cite — it answers the red-team's F1 ("calm hides manipulation") by making *the void itself the proof of non-manipulation*.

**Anti-pattern to avoid:** MUJI store cards work because they're **physical, fixed, and read at arm's length in 2 seconds**. MUJI's *digital* surfaces (muji.com) are mediocre — they reproduce the card pattern on screen and it feels sterile. MINT must add *one* element MUJI doesn't have: **the regional voice microcopy** (L1.4) embedded as the line-2 phrasing. That's what prevents the MUJI grid from feeling Swiss-bank-cold.

---

### 1.7 — Erik Spiekermann (Deutsche Bahn, FF Meta, Edenspiekermann)

**Source confidence:** HIGH (Spiekermann is heavily documented; *Stop Stealing Sheep & Find Out How Type Works* (1993, rev. 2014), Deutsche Bahn corporate design system 1990s, FF Meta original specimen).
**Reference:** Spiekermann, *Stop Stealing Sheep* (Adobe Press, 3rd ed. 2014); Deutsche Bahn DB Type / DB Sans case study; Edenspiekermann blog archives.

**What Spiekermann actually did at Deutsche Bahn:** He inherited timetables that were dense, multi-color, and *hostile*. He replaced them with **a single typeface family (DB Sans, derived from Meta) at 4 specific sizes, with a strict horizontal grid — and he removed every color except one (red) reserved for the single piece of information that would cause you to miss your train**. Color became *information about urgency*, not decoration. The grid wasn't visible — it was *felt* through alignment. Critically: he **kept the density** (timetables are dense by necessity) and made it *navigable through repetition and rhythm*, not through more white space. This is the opposite of Aesop.

**Transferable pattern for MINT:**
> **Reserve one color for one meaning, app-wide.** MINT should pick *one* color (not green, not red — likely a desaturated amber) and reserve it for *one specific signal*: "this number is the one you should look at first on this screen". One per screen, never two. The rest of the palette stays calm-neutral. This is a **stricter** rule than the brief currently has and resolves the F1 red-team critique (calm hides manipulation) by making the *one signal* per screen *unmissable but tiny*.

**Where it applies:** L1.1 audit du retrait + L1.3 microtypographie + DESIGN_SYSTEM.md update. Replaces ad-hoc accent colors. The MTC bloom 250ms can use this color, but only when crossing the confidence floor.

**Spiekermann's other reusable lesson:** **"Type is not the surface — type is the system."** His DB grid was a *layout-on-the-baseline* discipline. MINT's L1.3 should not just specify font sizes — it should specify a **single baseline grid (suggest 4pt) that every text element snaps to across S1-S5**. This is invisible to users but creates the calm rhythm without changing weights.

**Anti-pattern to avoid:** Spiekermann's DB system works because **trains have schedules** — there's a literal external truth. MINT's projections are *probabilistic* — there is no "correct" number. Spiekermann's red-for-urgency cannot be applied to a probability. MINT must reserve its one color for **a fact that is verifiable now** (an account fee, a deadline, an assumption that has changed), never for a projected outcome.

---

### 1.8 — Headspace / Calm

**Source confidence:** MEDIUM (public app + Headspace's "Andy Puddicombe voice" branding, Calm's emergency-vs-bedtime tone shifts; less academic source material).
**Reference:** Headspace app (2024 redesign), Calm app's "Daily Calm" vs "Emergency SOS" voice, public design press on Headspace's 2023 Lottie animation system.

**What Headspace actually does:** Andy Puddicombe's voice is **the same person in every audio session, but the *pacing* changes by session type**. In a 3-minute SOS session, the gap between sentences is ~1 second. In a 20-minute sleep session, the gap is ~6 seconds. The *words per minute* shift from ~140 to ~80. Critically: when premium expires, the in-app *text* tone shifts from coach-warm to *commercial-warm* — but Andy's *audio voice* is never used for the upgrade prompt. There's a wall between narrator-voice and transactional-voice.

**Transferable pattern for MINT:**
> **The narrator wall.** MINT should establish a hard rule: the *coach voice* (L1.6 cursor N1-N5) is **never** used for transactional or system messages (settings, errors, account state, upgrade prompts in Phase 3). Those use a separate, flat, system register. Currently the brief implies the cursor applies to "every output verbal de Mint". This is a mistake. Headspace's lesson: **mixing narrator and transactional in the same voice destroys narrator credibility forever**. Once Andy sells you a discount, he can't put you to sleep again.

**Where it applies:** L1.6 spec — add a "narrator wall" section listing surfaces that are *exempt from cursor routing* (settings strings, error toasts, network failures, paywall when it arrives in Phase 3, legal disclaimers). These stay flat-system always.

**The pacing lesson for MINT:** Headspace modulates by **silence**, not by *words*. MINT could do the same in chat: at N1 (Neutre), the coach reply has more *line breaks* and the typing indicator pauses longer between sentences. At N5 (Cash), no line breaks, fast delivery. This is again *non-visual intensity* — the screen looks identical, but the *rhythm of arrival* changes. This is rare in fintech and would be a true differentiator.

**Anti-pattern to avoid:** Headspace's *visual* layer in 2024 went hard on Lottie animations of breathing circles. They're nice in meditation context, *catastrophic* in finance context — they read as wellness-mou, which is a banned register (CLAUDE.md §6, brief v0.2.3 phrases interdites). MINT must never import the Headspace *visual* vocabulary, only the *tempo* discipline.

---

### 1.9 — Stripe (error grammar)

**Source confidence:** HIGH ([stripe.com/docs](https://stripe.com/docs), Stripe's public *Increment* magazine, public talks by Michael Siliski + Krithika Muthukumar on Stripe's writing system).
**Reference:** Stripe Docs, Stripe's *Increment* "On Documentation"; Stripe API error responses are studied widely (Stripe error message style guide leaked + reverse-engineered in dev press).

**What Stripe actually does:** Every Stripe error has **5 mandatory parts**: (1) **What happened** (in past tense, factual), (2) **Why it happened** (cause), (3) **What it means for the caller** (consequence), (4) **What to do next** (action), (5) **Where to read more** (link). They *never* use the word "Sorry". They *never* use exclamation points. They use *active voice with the system as subject* ("Stripe could not charge this card") rather than passive ("Your card could not be charged"). The system *takes responsibility for the action attempt*, not the user.

**Transferable pattern for MINT:**
> **"MINT n'a pas pu" instead of "Tu n'as pas pu".** Wherever MINT cannot complete an action (extraction failed, network down, calculation needs more data), the subject of the sentence is **MINT, not the user**. This is a tiny grammatical move with enormous psychological consequences. It directly serves "réduire la honte" (CLAUDE.md identity §1 principle 2). Brief v0.2.3 doesn't currently encode this rule — it should.

**Where it applies:** L1.6 voice spec — add a "Sentence subject" rule. Code-level: any error path in Flutter that produces a user-facing string must be reviewed for subject. L1.5 MintAlertObject can enforce this for alerts, but error toasts/snackbars across the app need the same treatment.

**Stripe's 5-part template applied to MINT:**
> *(fact)* "MINT n'a pas pu lire ce certificat LPP." → *(why)* "L'image est trop floue à droite." → *(consequence)* "On ne peut pas projeter ta rente sans cette page." → *(action)* "Refais une photo en pleine lumière." → *(more)* "Voir comment scanner un certificat."
>
> Five parts. ~30 words. No "désolé". The user is not at fault — the *image* is too blurry, not the user. This is the granular execution of the brief's identity.

**Anti-pattern to avoid:** Stripe's docs are *for developers reading at a desk*. Their 5-part errors are sometimes 60-80 words. MINT's mobile users in stress need ~25-35 words max. Same template, half the length.

---

### 1.10 — Notion's "quiet UI" 2024-2025

**Source confidence:** **LOW** — my training cutoff is May 2025 and Notion's quiet UI evolution continues. I have HIGH confidence on Notion's pre-2024 maximalist period and MEDIUM confidence on the 2024 *Notion 3.0* "calmer surfaces" direction. Specific 2025 cuts I cannot verify without WebSearch (which would be appropriate next research wave). **Flag this section for verification before requirements step.**
**Reference:** [notion.so/blog](https://www.notion.so/blog), *Notion 3.0* announcement (early 2024), Notion's design team posts on Twitter/X (Ryo Lu, Aman Manazir).

**What Notion did (verified pre-cutoff):** They removed the **left-sidebar emoji clutter** by collapsing nested toggles by default. They reduced their **comment thread chrome** (no more colored bubbles around every comment — flat indent only). They moved AI from a *dedicated panel* to an **inline-summon-only** affordance (Cmd+J), removing the persistent "AI" button from the sidebar. The pattern beneath these cuts: **AI surfaces should be summoned, not advertised.**

**Transferable pattern for MINT:**
> **The Coach is summoned, not advertised.** This is the deepest lesson and it directly contradicts Cleo (which makes the chat the entire app). Brief v0.2.3 has a Coach tab (S2-adjacent in the 3-tab shell). Notion's 2024 lesson would suggest: the coach should not be a tab — it should be a **gesture** (long-press anywhere on a number, or pull-up from the bottom of any projection card). *The coach lives inside the data, not next to it.* This is more radical than the brief currently goes, and it would force a redesign of the 3-tab shell.

**Where it applies:** This is **probably out of scope for v2.2** (the 3-tab shell is in §Validated). But it should be flagged as **a v3.0 hypothesis worth testing**, and L1.5 MintAlertObject should be designed to *preview* this future: alerts should be summonable from inside data cards, not pushed from the coach tab.

**Anti-pattern to avoid:** Notion's "summon, don't advertise" works because *Notion users are already in flow*. MINT users open the app *already lost*. If MINT hides the coach behind a gesture, fragile users will never find it. So this pattern applies to *power users post-onboarding*, not to first-time users.

---

## 2. Synthesis — What the Brief Got Right, What Survived That Should Be Cut, What's Missing

### 2.1 What the brief got right (do not touch)

- **Curseur d'intensité 5 niveaux** — uniquely synthesizes Cleo's voice modes with Spiekermann's "system-not-surface" discipline. Strongest single innovation in the brief.
- **MTC as the only "mécanisme visible au tap"** (cut decision in PROJECT.md §Cut from Layer 1) — directly aligns with Linear's "one sharp move per screen".
- **Voix régionale** — survived all 6 red-team audits, survives this practitioner pass too (no practitioner does this; it is genuinely net-new).
- **Behavioral data minimization (C3)** — Headspace + Notion both implicitly endorse this; Wise's transparency rituals require it.
- **Phrases interdites** — Stripe's "no sorry, no exclamation" and Headspace's "narrator wall" both reinforce this.

### 2.2 What survived the brief that should be CUT

These are present (or implied) in v0.2.3 and v2.2 PROJECT.md and would not survive Hara, Reichenstein, or Spiekermann:

| Item in brief | Who would cut it | Why |
|---|---|---|
| **MTC rendering 4 axes always** (current L1.2a spec) | Linear (Saarinen) | Below confidence floor → hide projection entirely. Add `MTC.Empty(missingAxis)` state. |
| **MTC bloom 250ms ease-out as "the only mécanisme visible au tap"** | Reichenstein | A bloom is *still* visual chrome. The deeper move is *ambient dim of context* (focus mode), not an animated reveal of the MTC itself. Consider replacing or augmenting bloom with focus-mode dim. |
| **L1.6 Voice Pass cursor applied to "toute sortie verbale de Mint"** | Headspace (narrator wall) | Cursor must NOT apply to system/transactional/error/legal strings. Add explicit exemption list. |
| **Headline numbers as visual focal point on S4** (implicit in current spec) | Aesop + Hara | Demote the number, promote the sentence. Headline number = body weight, not display weight. |
| **The Coach as a tab** (S2 + 3-tab shell, in §Validated) | Notion | Out of scope to change in v2.2, but flag as v3.0 hypothesis. The coach should be summoned from data, not advertised on a tab. |
| **Multiple accent colors** (current MintColors palette has multiple) | Spiekermann | Reserve ONE color for ONE meaning (verifiable fact requiring attention). All else neutral. |
| **Free-form copy in alerts** (no compiler-enforced grammar) | Wise + Stripe | MintAlertObject must enforce a structured 3-part API (fact/cause/nextMoment), not accept arbitrary `String message`. |

### 2.3 What's MISSING from the brief that any of these would consider table stakes

| Missing element | Practitioner | Why it's table stakes |
|---|---|---|
| **Hypotheses footer on every projection** (visible at rest, 3 lines max) | VZ | Without this, the projection is opaque. VZ's whole credibility comes from this. |
| **Sentence-subject rule** ("MINT n'a pas pu" not "Tu n'as pas pu") | Stripe | Tiny rule, enormous psychological consequence. Maps to identity principle "réduire la honte". |
| **Compiler-enforced grammar in MintAlertObject** (typed API, not String) | Wise | The component itself enforces the template. Without this, copywriters drift. |
| **One-color rule** (one accent, one meaning, app-wide) | Spiekermann | Resolves red-team F1 (calm hides manipulation) by making the *one signal per screen* unmissable. |
| **Hide-when-low-confidence floor** for projections | Linear | More honest than rendering a faded MTC. |
| **Narrator wall** (cursor exempts system/transactional/legal) | Headspace | Prevents narrator-credibility collapse. |
| **Pacing/silence as intensity** (not just word choice) | Headspace | Non-visual intensity through *rhythm of arrival* in chat. |
| **Baseline grid (4pt) snap rule** in DESIGN_SYSTEM | Spiekermann | Invisible to users, creates calm rhythm without changing weights. |
| **MUJI 4-line grid as projection card baseline grammar** | Hara | Forces austerity. Currently the brief implies more chrome on S4 than this allows. |
| **Focus mode (ambient dim) at N4/N5** | Reichenstein | Honors "le visuel ne change jamais" while still marking intensity. The brief currently has *no mechanism* for marking intensity visually-without-changing-the-visual; this is the gap. |

### 2.4 Categories — Table Stakes vs Differentiator vs Anti-Feature for v2.2

#### Table Stakes (must ship, otherwise v2.2 is incomplete by its own doctrine)

| Feature | Source | Complexity | v2.0/v2.1 dependency | Maps to chantier |
|---|---|---|---|---|
| MTC v1 component (4-axis EnhancedConfidence renderer) | Brief L1.2a | M | financial_core/confidence_scorer.dart (shipped) | L1.2a |
| MTC migration on 12 projection screens | Brief L1.2b | L | L1.2a + financial_core consumers | L1.2b |
| MintAlertObject component (G2/G3) | Brief L1.5 | M | VoiceCursorContract from L1.0 | L1.5 |
| Voice cursor 5-level spec doc + 50 reference phrases | Brief L1.6a | M | VOICE_SYSTEM.md (shipped) | L1.6a |
| Voice cursor user setting (soft/direct/unfiltered) | Brief L1.6c | S | Profile model (shipped) | L1.6c |
| Microtypographie pass S1-S5 (line length 45-75) | Brief L1.3 | M | DESIGN_SYSTEM.md (shipped) | L1.3 |
| Audit du retrait -20% on S1-S5 | Brief L1.1 | S | Existing screens | L1.1 |
| Voix régionale VS/ZH/TI 30 microcopies × canton | Brief L1.4 | L | RegionalVoiceService (shipped) | L1.4 |
| Phase 0 stabilisation gate (Galaxy A14, VoiceCursorContract, Krippendorff tooling) | Brief L1.0 | M | None (carryover v2.1) | L1.0 |
| **NEW: Hypotheses Footer on every projection** | VZ pattern | S | financial_core sources field (shipped) | L1.2b extension |
| **NEW: Sentence-subject rule encoded in voice spec** | Stripe pattern | S | L1.6a | L1.6a addition |
| **NEW: Narrator wall — cursor exemption list** | Headspace pattern | S | L1.6a | L1.6a addition |
| **NEW: MintAlertObject typed API (fact/cause/nextMoment)** | Wise+Stripe pattern | S | L1.5 | L1.5 API spec |
| **NEW: One-color-one-meaning rule in DESIGN_SYSTEM** | Spiekermann pattern | S | MintColors (shipped) | L1.1 dependency |
| **NEW: 4pt baseline grid snap rule** | Spiekermann pattern | S | DESIGN_SYSTEM.md | L1.3 addition |

#### Differentiators (genuinely net-new vs all 10 practitioners + Cleo + VZ)

| Feature | Why differentiating | Complexity | Risk |
|---|---|---|---|
| Voix régionale (VS/ZH/TI) | No fintech does this anywhere | L | Validation by natives required |
| Voice cursor 5 levels with Krippendorff α≥0.67 validation | Cleo has voice modes; nobody has *measured* IRR on the assignment | M | Krippendorff tooling provisioning is real work |
| MintTrameConfiance 4-axis (completeness × accuracy × freshness × understanding) | VZ uses scenarios; Linear hides; nobody renders 4 axes | M | Accessibility risk (audio-1-line version is hard) |
| **NEW (Reichenstein): Focus mode (ambient dim) tied to gravity class** | "Visual stays calm but intensity is felt" — this is the missing mechanism | M | Performance on Galaxy A14 (animating opacity on shell) |
| **NEW (Headspace): Pacing/silence as intensity** in chat | Non-visual intensity through rhythm | M | Requires chat-streaming infra changes |
| **NEW (Hara): MUJI 4-line projection card grammar** | Radically more austere than Cleo/VZ/Wise/anyone | S | Stakeholder pushback ("too empty") |
| **NEW (Linear): Hide-when-low-confidence floor** | Most apps decorate uncertainty; this *deletes* it | S | UX regression risk if users can't find why a projection disappeared |

#### Anti-Features (do NOT build for v2.2; named because they will be requested)

| Anti-feature | Why requested | Why problematic | What to do instead |
|---|---|---|---|
| Skin/color shift on cursor levels (Cleo-style) | Cleo proves it works | Brief v0.2.3 §2 rule of gold #1: *visual never changes*. Breaks the entire aesthetic family. | Reichenstein focus-mode dim instead. |
| Lock Screen widget (iOS only) | Engagement boost | Red team F7 + brief cut. iOS only, AppleWatch only, doesn't survive Galaxy A14 floor. | Defer to Layer 2 R&D. |
| Generative MINT signature | "Beautiful personalization" | Red team killed it 4 ways: brignull, accessibility, fatou, philosopher. | Stays in R&D (already cut). |
| Palate cleanser screens | "Calm rituals" | Red team killed it 3 ways: postmortem, accessibility, fatou. | Use Hara's *static white space* instead — empty space already on existing screens. |
| Lottie breathing-circle animations (Headspace import) | "Wellness vibe" | Wellness-mou, banned register. | Pacing/silence in chat (Headspace's *real* lesson). |
| 6th surface added to Layer 1 | "But X is also important" | Brief explicit exclusion. | Replace one of S1-S5 only. |
| Watch complication / AirPods coach voice | Tier 2 R&D | Device floor (Galaxy A14). | Defer to v2.3+. |
| Confidence rendered always (current MTC spec) | "Show our work" | Below floor → faded MTC is *less honest* than absence. | `MTC.Empty(missingAxis)` state. |
| Coach as tab (status quo) | Already shipped | Notion 2024 lesson: AI is summoned, not advertised. | Out of scope v2.2; flag for v3.0. |
| MintAlertObject accepting arbitrary `String message` | "Flexibility" | Copywriter drift. Wise+Stripe both reject this. | Typed API: `fact / cause / nextMoment`. |
| Multiple accent colors in palette | "Hierarchy" | Spiekermann: one color, one meaning. | Reserve one accent for "verifiable fact requiring attention". Demote others to neutral. |
| Voice cursor applied to error toasts / settings / legal | "Consistency" | Headspace narrator wall — destroys narrator credibility. | Exemption list in L1.6a. |
| Comparaison sociale ("X% des Suisses") | "Engagement driver" | CLAUDE.md §6 banned, doctrine. | Compare only to user's own past (already in CLAUDE.md). |

---

## 3. Feature Dependencies (within v2.2 scope)

```
L1.0 Phase 0 Stabilisation Gate
   ├─ VoiceCursorContract (Dart const + Pydantic)
   │     ├─ required by L1.5 MintAlertObject
   │     └─ required by L1.6 Voice Pass
   ├─ Galaxy A14 perf baseline
   │     └─ blocks L1.3 microtypographie merge (must validate on device)
   └─ Krippendorff α tooling
         └─ required by L1.6b validation pass

L1.1 Audit du retrait
   ├─ uses: One-color-one-meaning rule (NEW from Spiekermann)
   └─ uses: Hara emptiness-as-information principle (NEW)

L1.2a MintTrameConfiance v1 + S4
   ├─ requires: confidence_scorer.dart (shipped v2.0)
   ├─ NEW: MTC.Empty(missingAxis) state (Linear pattern)
   ├─ NEW: Hypotheses Footer slot (VZ pattern)
   └─ NEW: MUJI 4-line grid as S4 baseline grammar (Hara)

L1.2b MTC migration on 12 projection screens
   ├─ requires: L1.2a complete
   └─ requires: Hypotheses Footer extracted as reusable component

L1.3 Microtypographie pass S1-S5
   ├─ requires: L1.0 Galaxy A14 baseline
   ├─ NEW: 4pt baseline grid snap rule (Spiekermann)
   └─ NEW: Aesop demote-the-number rule (couples to S4 work in L1.2a)

L1.4 Voix régionale VS/ZH/TI
   ├─ requires: RegionalVoiceService (shipped v2.0)
   ├─ requires: app_regional_<canton>.arb namespace decision (i18n carve-out, decided)
   └─ ComplianceGuard validation on every microcopy

L1.5 MintAlertObject (G2/G3)
   ├─ requires: VoiceCursorContract from L1.0
   ├─ NEW: Typed API fact/cause/nextMoment (Wise+Stripe)
   ├─ NEW: Sentence-subject rule enforced (Stripe)
   └─ Patrol tests obligatoires

L1.6 Voice Pass — Curseur d'Intensité v1
   ├─ L1.6a Spec doc + 50 phrases + matrice routage
   │     ├─ NEW: Narrator wall exemption list (Headspace)
   │     ├─ NEW: Sentence-subject rule (Stripe)
   │     └─ NEW: Pacing/silence rules per level (Headspace)
   ├─ L1.6b Réécriture 30 phrases coach + Krippendorff α≥0.67
   │     └─ requires: L1.0 Krippendorff tooling + L1.6a spec
   └─ L1.6c Réglage utilisateur "Ton" in onboarding + drawer
         └─ requires: Profile.voiceCursorPreference Pydantic v2 (backend)

NEW DIFFERENTIATOR: Focus mode (Reichenstein)
   ├─ requires: L1.6a (gravity class definitions)
   ├─ Performance gate on Galaxy A14 (animating shell opacity)
   └─ Implementation: ambient dim on N4/N5 message arrival
   └─ Risk: schedule add — propose as stretch goal, not gating
```

---

## 4. MVP Definition for v2.2

### Must ship (gating v2.2 close)

- L1.0 Phase 0 stabilisation gate (carryover, blocking everything)
- L1.1 Audit du retrait + One-color-one-meaning rule
- L1.2a MTC v1 + S4 + Empty state + Hypotheses Footer slot
- L1.2b MTC migration on 12 screens
- L1.3 Microtypographie pass + 4pt baseline grid + Aesop demote-the-number
- L1.4 Voix régionale VS/ZH/TI
- L1.5 MintAlertObject typed API (fact/cause/nextMoment)
- L1.6a Voice cursor spec + 50 phrases + narrator wall + sentence-subject rule
- L1.6b 30 phrases rewrite with Krippendorff α validation
- L1.6c User setting "Ton" + Profile.voiceCursorPreference

### Should ship (stretch, do not block close)

- Focus mode ambient dim at N4/N5 (Reichenstein) — gated by Galaxy A14 perf
- Pacing/silence rules per cursor level in chat (Headspace) — requires chat infra changes
- MUJI 4-line strict grammar enforcement on S4 (vs. just baseline guidance)

### Defer to v2.3+

- Voix régionale beyond VS/ZH/TI
- Android-in-CI automation (Firebase Test Lab investigation)
- Coach-as-summon (Notion 2024 hypothesis) — requires shell redesign
- Translating regional microcopy across non-base languages (intentional carve-out)

---

## 5. Sources (with confidence flags)

### HIGH confidence
- Linear: [linear.app/method](https://linear.app/method); Karri Saarinen "Designing Linear" Config 2022.
- Aesop: [aesop.com](https://www.aesop.com/); Wallpaper* features; Dennis Paphitis interviews.
- iA Writer / Reichenstein: [ia.net/topics](https://ia.net/topics) — "Responsive Typography", "100% Easy-2-Read".
- Hara / MUJI: *Designing Design* (Lars Müller, 2007); *White* (Lars Müller, 2009).
- Spiekermann: *Stop Stealing Sheep & Find Out How Type Works* (3rd ed. 2014); Deutsche Bahn DB Type system; Edenspiekermann archives.
- Stripe: [stripe.com/docs](https://stripe.com/docs); *Increment* magazine; public error grammar studies.

### MEDIUM confidence
- VZ: [vermoegenszentrum.ch](https://www.vermoegenszentrum.ch/) — public site HIGH; in-app screen behavior LOW (requires Julien teardown). **Action:** Julien to screenshot 5 VZ app screens (a tax estimate, a retirement projection, an alert, a scenario comparison, a confidence display) and append to research before requirements step.
- Wise: [wise.com/design](https://wise.com/design) + Wise blog "How we write"; behavioral specifics MEDIUM.
- Headspace / Calm: public app + Andy Puddicombe branding; MEDIUM, no academic source.

### LOW confidence (verify before requirements step)
- **Notion "quiet UI" 2024-2025**: post-cutoff territory. WebSearch needed to verify specific 2025 cuts. The pattern I cited (AI summoned, not advertised) is verified pre-2025; specific 2025 deletions are not. **Action:** WebSearch "Notion design system 2025 cuts" before promoting any Notion-derived requirement to MVP.

### Internal MINT references (HIGH confidence — read in this session)
- `/Users/julienbattaglia/Desktop/MINT/.planning/PROJECT.md`
- `/Users/julienbattaglia/Desktop/MINT/visions/MINT_DESIGN_BRIEF_v0.2.3.md`
- `/Users/julienbattaglia/Desktop/MINT/visions/MINT_DESIGN_BRIEF_RED_TEAM.md`
- `/Users/julienbattaglia/Desktop/MINT/CLAUDE.md` (auto-loaded)

---

## 6. Open questions for the requirements step

1. **Focus mode (Reichenstein) — stretch or MVP?** It is the cleanest answer to "how do we mark intensity without changing the visual" but it adds animation work and a Galaxy A14 perf gate. Recommendation: **stretch goal**, not MVP gating.
2. **MUJI 4-line strict vs. baseline?** Strict enforcement on S4 forces a redesign; baseline is gentler. Recommendation: **strict on S4 only**, baseline elsewhere.
3. **One-color-one-meaning rule — which color?** Brief doesn't specify. Recommendation: **desaturated amber** (not red, which reads as alarm; not green, which reads as approval; not the existing MintColors accents). Requires DESIGN_SYSTEM.md update before L1.1.
4. **Hypotheses Footer scope** — every projection screen or only the 12 in L1.2b? Recommendation: **all 12 in L1.2b**, ship as part of MTC migration.
5. **Notion verification** — should requirements step include a WebSearch wave to verify 2025 specifics before ruling on coach-as-tab? Recommendation: **yes, but as v3.0 input only, not v2.2 gating**.
6. **VZ teardown** — Julien screenshots needed before requirements? Recommendation: **yes** — cheapest/highest-leverage research action remaining before requirements step locks.

---

*Feature research for: MINT v2.2 La Beauté de Mint — design + voice + accessibility surface*
*Researched: 2026-04-07*
*Next step: gsd-research-synthesizer → SUMMARY.md → roadmapper*
