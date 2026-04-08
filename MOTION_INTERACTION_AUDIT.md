# MINT — Motion & Interaction Creative Audit

**Prepared for**: MINT Founder & Product
**Discipline**: Motion Design & Interaction Architecture
**Horizon**: 3 layers (v2.1 → v3.0 → v4.0+)
**Date**: 2026-04-07

---

## 1. DIAGNOSIS: THE OPPORTUNITY (250 words)

### What's Strong

MINT's design system shows clarity and restraint—Montserrat + Inter, white cards on soft surfaces, minimal color, generous spacing. The philosophy is right: "L'air est un composant." The voice layer (calm, never prescriptive, regionally rooted) has deep soul. The architecture (Plan-first, Coach-as-layer) rejects dashboard noise.

But.

**The motion and interaction language is nearly invisible.** Reading the design system and navigation spec, there are almost no motion verbs: no choreography, no entry/exit strategy, no gesture language, no haptic pairing, no scroll behavior, no timing model, no easing vocabulary. There is one paragraph ("apparition douce, transitions de couches, graphes qui se dessinent calmement, microparallax très léger") that points toward something alive—and then nothing.

### The Missed Opportunity

A financial protection app built on intimate coaching has motion as its primary tool for **emotional continuity**. When a number appears (a new insight, a simulated future, a risk revealed), *how it appears* determines whether the user trusts it or ignores it. When a user moves from Coach to action to result, the *spatial continuity* determines whether they feel guided or tossed.

MINT's strongest asset is being **whispered intelligence**—the voice of someone who knows you in the room. Motion can make that whisper audible without saying a word.

**Biggest missed opportunity**: MINT has built a conversational AI layer but choreographed it like a calculator. No handoff grammar. No reveal ritual. No sense that information is arriving, being considered, settling into understanding. The app feels *helpful but mechanical*.

---

## 2. NINE IDEAS: THREE PER LAYER

### LAYER 1: Surgical Elevation (v2.1, Weeks)
#### Perfect motion details, same grammar.

**1. The Premier Éclairage Arrival Ritual**

When a key insight card enters the screen, it doesn't fade in or slide up—it **breathes into existence**. The card appears at 0.4 opacity, scale 0.92, over 200ms with a cubic-bezier(0.34, 1.56, 0.64, 1) ease-out (subtle bounce, no overshoot). The background tint (20% black) layers beneath it, slightly delayed (80ms), creating a subtle depth stack. The headline number scales up and settles first (180ms), then the secondary text fades in (140ms staggered start), then a small `confidence` badge slides in from the right edge (100ms delayed), landing with a micro-bounce at the 20ms mark. Total: 320ms feel-good sequence, not frenetic.

**Reference**: Apple's iOS notification center arrival; Calm app's daily meditation reveal; Linear's notification toast system.

**2. The Handoff Choreography: Coach → Action → Result**

When a user taps "Voir les scénarios" in Coach, the message doesn't vanish. It transforms. The chat bubble shrinks and pins to a timeline on the left, becoming an evidence artifact. The screen transitions via a **vertical wipe** (not a modal push, not a fade)—the new simulator screen grows from beneath the keyboard, carrying the user's intent upward. When they return, the reverse choreography plays: the result card animates down and reintegrates into the chat thread, anchored below the original question. This grammar makes every flow feel like a *continuation*, not a detour.

**Reference**: Superhuman's email-to-action transitions; Arc Browser's space-switching choreography; Craft's documentation block reveals.

**3. The Confidence Score Settling**

When a score first appears (e.g., a retirement projection confidence at 67%), the number doesn't snap into place. It **counts up** from 0 to 67 over 800ms with an ease-out-cubic, but at 400ms in, a subtle 1px white glow passes across the digits (like a light flare), suggesting certainty arriving. The percentage symbol trails by 60ms. The underlying progress arc grows from 0° to its endpoint in lockstep. Below, a small "plus précis demain" label fades in at 600ms, suggesting the score is *still settling*—inviting the user to feed more data without pressure. Total feel: a measurement becoming more confident, not a final judgment.

**Reference**: Stripe's payment success animation; Activity Ring in Apple Watch; Data visualization in Observable notebooks.

---

### LAYER 2: Bold Reinvention (v3.0, ~6 months)
#### New motion language, unique to MINT.

**4. Contextual Scroll Breathing**

The core screens (Aujourd'hui, Coach, Explore hubs) use a **variable-friction scroll** that subtly responds to semantic zones. When scrolling through Aujourd'hui, the opening hero section (1 phrase + 1 chiffre) resists scroll slightly—friction coefficient 1.3x normal—inviting the user to *really see* before scrolling away. Below the fold, normal friction. When scrolling a hub page in Explorer, action cards (tools, calculators) trigger a **snap-point** that locks the scroll if you're within 40px of the card center, allowing momentary pause without requiring a tap. This is invisible but felt: the app "suggests" where to stop and breathe.

**Reference**: iOS Safari's bounce-back; Medium's clap button micro-friction; Good Notes' gesture-based scroll damping.

**5. The Regional Voice as Motion Signature**

Each canton gets a motion micro-accent. For Suisse Romande (VD, GE, VS), enter animations use a **dry, measured pace**: 240ms, cubic-bezier(0.25, 0.46, 0.45, 0.94)—rational, no bounce. For Deutschschweiz (ZH, BE), animations are **slightly snappier and warmer**: 220ms with a subtle 1.05 scale overshoot, feeling practical and friendly. For Svizzera Italiana (TI), a **relaxed, leisurely timing**: 280ms with a gentle ease-in-out, almost Mediterranean. The user never sees a label, but they feel *recognized*. The app's motion tempo is locally rooted, like the voice.

**Reference**: Apple's regional design variations (subtle, never overdone); Spotify's region-specific color palettes; Figma's regional cursor speeds.

**6. The Insight Layering: Complexity Disclosed Progressively via Motion**

When opening a complex flow (e.g., Rente vs Capital), the screen doesn't dump all three scenarios at once. The base scenario (full annuity) appears first with a light scale-in. A 400ms delay, the second scenario (full capital) enters from the right with a slide. Another 300ms delay, the mixed scenario slides in. But critically: each scenario card has a subtle **left-to-right gradient mask** that reveals detail over 600ms *after* the card enters, so the eye reads headline first, then sub-headline, then numbers, then a subtle success/warning badge. This staggered disclosure lets complexity feel *navigable* instead of overwhelming.

**Reference**: Framer's component reveal system; Loom's playhead scrubbing feel; Medium's marginal note reveals.

---

### LAYER 3: Visionary Disruption (v4.0+, 2027-2028)
#### Rethink interaction itself.

**7. The Invisible Gesture: Swipe-to-Simulate**

On any number card (a projected retirement amount, a tax bill, a savings milestone), a **subtle animated hint** appears once: a light swipe-right arrow that fades in and out over 2 seconds. If the user swipes right on the number, it triggers a **scrubber mode**: the number becomes a slider. Swiping left/right changes the underlying assumption (e.g., swiping on "30'000/year" assumes different spending; swiping on "65" assumes different retirement age). The number updates in real-time as they swipe, snapping to round figures with a tiny haptic pulse at each snap point. Swipe up to confirm, down to cancel. This is *gesture as calculation*, not buttons as proxies—pure interaction choreography.

**Reference**: Apple Maps' 3D tilt gesture; Spotify's swipe-to-skip; the original iPhone's momentum scroll; Drawing apps' brush stroke feedback.

**8. The Coach as Spatial Presence, Not Just Text**

The Coach chat interface evolves into a **spatial audio/visual duet**. Coach responses appear not just as text but as an animated **voice orb**—a breathing, softly pulsing accent shape (maybe a circle, maybe a subtle wave) that sits at the top of each response. When the coach is "thinking" (waiting for Claude API), the orb **breathes slowly** (expand/contract over 2 seconds). When the response arrives, the orb settles and becomes a **tactile playback button** for the voice version. Tapping it plays the coach's voice *from that spatial anchor*, not from a generic speaker. The visual rhythm (breath → settle → play) makes the coach feel like a *presence in the room*, not a chatbot.

**Reference**: Replika app's avatar system; Woebot's conversational rhythm; the *Her* film's spatial audio design; Bluetooth speaker pairing choreography.

**9. The Temporal Clarity: Time as Visual Hierarchy**

When comparing scenarios (Bas/Moyen/Haut projections spanning 20 years), time doesn't just appear as an X-axis. Instead, **the screen's horizontal scroll position encodes year**—scrolling left is the past, right is the future. But the kicker: the **background gradually shifts in lightness and temperature** as you scroll right. Past years are warm and dark (grounded). Current year is neutral. Future years are cool and progressively lighter (uncertain). A subtle **vertical shimmer line** marks "today" and persists as you scroll. This makes time *spatial and felt*, not abstract. Users can navigate futures not with clicks but with their fingers, feeling time's arrow through haptics and chromatics.

**Reference**: Behance's infinite scroll reveal; the film *Dunkirk*'s three-timeline structure; D3.js temporal visualizations; Apple's timeline scrubber in Pro Display design.

---

## 3. THE ONE THING (150 words)

**MINT's motion language must embody *considered arrival*, not instant appearance.**

Every insight, number, question, and action in MINT represents *financial clarity that someone is risking their future on*. It must never feel instant or cheap. The motion grammar must communicate: *"This has been thought through for you. Take a breath. Read it. Trust it."*

Concretely: **Replace all fade-ins and snap-ins with a two-layer arrival system.** First, the *container* appears with a soft scale and cubic-bezier ease (180-240ms). Second, the *content* (text, number, visual) populates inside with 80-120ms staggered delays. This creates a spatial sense of something *settling into place*, not appearing from nowhere.

Apply this to every emergence: premier éclairage cards, simulation results, chat responses, Coach insights, alert notifications. Couple it with the regional motion tempo. Bind it to haptic feedback (subtle tap or pulse on settle). This single rhythm—**arrival-as-settling**—becomes MINT's signature. Users will feel it before consciously noticing it. And they will trust it.

---

## 4. REFERENCES (12 specific)

1. **Apple's Rubber Band Physics (iOS)** — The archetype for motion that feels physical, not digital. Overshoot without excess. See: pull-to-refresh, momentum scroll, elastic bounds.

2. **Linear's Command Palette** — The single best example of motion clarity in fintech-adjacent design. Enter via scale + fade, blur background subtly, exit snaps cleanly. Timing: 150ms. Teaches restraint.

3. **Arc Browser's Spaces Switching** — Spatial continuity done right. Switching between "spaces" (browser windows) uses a horizontal slide with slight perspective, making each space feel like a *room* you're entering, not a tab you're switching.

4. **Calm App's Meditation Reveal** — The daily meditation card *breathes in*—subtle scale and opacity over 300ms. When tapped, it expands and the background blooms. Pure emotion through motion.

5. **Stripe's Payment Success Animation** — A checkmark that doesn't just appear: it animates in, the circle around it draws itself, and the whole thing subtly bounces. 800ms total. Teaches trust-building through multi-layer timing.

6. **Headspace's Progress Animations** — When you complete a task, a visual rhythm plays: the stat moves, a subtle glow passes, a micro-achievement unlocks. Never loud. Always felt. This is how MINT should celebrate confidence score improvements.

7. **Framer's Gesture-Driven Reveals** — Components appear in response to scroll position or swipe. No buttons. Pure kinematics. Reference for the Swipe-to-Simulate concept.

8. **Figma's Collaboration Cursor Choreography** — When another user's cursor appears, it doesn't snap in—it *slides into existence* with a soft easing, feeling like a presence arriving. Apply this to Coach responses.

9. **Apple Maps' 3D Tilt Gesture** — Two-finger swipe pulls the map into perspective. The motion is intuitive, physical, and *felt* rather than seen. Gold standard for invisible gesture.

10. **Superhuman's Email-to-Action Transitions** — Messages animate to the archive, snooze becomes a time-picker that grows from the button. Every action has spatial continuity. Nothing feels disconnected.

11. **Good Notes' Gesture-Based Scroll Damping** — Friction adapts to context. Scrolling fast? It's snappy. Slow? It's weighted. This is the model for Contextual Scroll Breathing.

12. **Observable's Data Visualization Rendering** — Numbers and charts animate in as data loads, not all at once. Staggered, eased, felt. Apply this to all MINT simulators and projections.

---

## 5. THE CONTRARIAN MOVE (100 words)

**MINT must NOT use micro-interactions as praise or reward.**

No confetti. No bounce cascades on achievement. No "you crushed it!" celebrate animations. Financial clarity is not a gamification moment.

When a user hits a savings milestone or completes their profile, the only motion should be **a single, subtle visual state change**: a small glow or badge highlight. The celebration is *internal and financial*, not external and theatrical. The user's own realization is the motion—MINT's job is to get out of the way.

The same applies to error states. Never bounce a shake animation to say "wrong!" Instead, subtle color shift + gentle slide of the misaligned field + clear, calm text. The user's *understanding* is the motion; the app is just the guide.

**Restraint is the competitive advantage.**

---

## 6. NEXT STEPS

1. **Audit current implementation** against the Design System's motion rules (§ none exist; build them).
2. **Prototype Layer 1 ideas** (Arrival Ritual, Handoff Choreography, Confidence Settling) in Framer or Flutter's animation framework.
3. **Establish motion constants** in code: easing curves, durations, stagger delays—a small, reusable animation library.
4. **Test with regional variations** (separate timing + easing for each linguistic region).
5. **Measure perceived trust** via user research: does arrived-motion increase confidence in projections vs. instant appearance?

---

## References in MINT Codebase

- `docs/DESIGN_SYSTEM.md` — currently silent on motion
- `docs/VOICE_SYSTEM.md` — tone is strong; motion is absent
- `docs/NAVIGATION_GRAAL_V10.md` — interaction structure is clear; choreography is not
- `lib/theme/colors.dart` — visual tokens exist; motion tokens do not
- `lib/services/financial_core/` — calculations are deterministic; their reveal rhythm is random

**Recommendation**: Create `docs/MOTION_SYSTEM.md` as a peer to DESIGN_SYSTEM.md, establishing motion constants, easing functions, duration rules, and a gestural vocabulary specific to MINT's protection-first philosophy.
