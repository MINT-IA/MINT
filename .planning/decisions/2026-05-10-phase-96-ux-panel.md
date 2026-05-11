---
date: 2026-05-10
status: Proposed
authors: UX+Flutter panel (senior product designer + Flutter engineer, 1-shot brief)
panel: 2-pers (product-designer + flutter-engineer)
supersedes: —
superseded_by: —
description: Phase 96 UX/arch decisions — chat-tab kill, MintCardActionBar, 3-turn cap, SerializedCardContext, NarrativeSleeve, métaphore library, wave split.
related:
  - .planning/ROADMAP.md (Phase 96 entry)
  - .planning/decisions/2026-05-09-calc-first-llm-illumination.md
  - apps/mobile/lib/widgets/mint_shell.dart
  - apps/mobile/lib/screens/coach/coach_chat_screen.dart
  - services/backend/app/schemas/coach_chat.py
  - services/backend/app/services/coach/grounding_pack.py
  - docs/DESIGN_SYSTEM.md
  - docs/VOICE_SYSTEM.md
---

# Phase 96 MVP-CHAT-AS-VERB — UX + Architecture pre-GSD panel

## TLDR

Kill the chat tab from bottom nav behind a feature flag; surface 3 intent verbs (« explique / simule / rassure-moi ») as an animated inline action bar on each card; enforce a strict 3-turn cap server-side per card-session; propagate card context via a `SerializedCardContext` struct; wire the NarrativeSleeve linter as a backend response-middleware post-processor; and split execution into 3 waves (nav+UI / backend context / cap+metric).

---

## Context

Phase 96 is the final interaction-model pivot in the Chat-as-Verb chain (Phases 90–96). Its stated goal is to kill the chat tab as a destination and make cards the verb-invoking entry point. Dependencies confirmed: Phase 95 DAG-INVALIDATION must deliver fresh GroundingPack keys before Phase 96 surfaces numbers in overlays (grounding_pack.py is currently an empty stub `frozenset()`; Phase 95 populates it).

Current shell: `apps/mobile/lib/widgets/mint_shell.dart` — 4-tab `NavigationBar` with explicit `chat_bubble_outline` icon at index 2, using `l.tabCoach`. Removing the tab means removing index 2 from `destinations` and collapsing `StatefulShellRoute.indexedStack` from 4 branches to 3. Existing `CoachChatScreen` has ~57 imports and is the most complex screen in the codebase; it must be preserved as the backing route for the overlay (not deleted).

Industry reference: The 2026 fintech UX consensus (G&CO., eleken.co, stan.vision) is that chat is infrastructure, not destination. Samsung Galaxy AI and Capital One both demonstrate that conversational surfaces work best when triggered from content context, not as a top-level navigation destination. Separate Cleo-style research shows task-focused chatbots (3 most common user tasks) outperform open-ended chat tabs on conversion and retention.

---

## Decision

### Q1 — Kill the chat tab: how

**Decision: remove the tab from bottom nav, preserve the route.**

In `mint_shell.dart`, wrap the `NavigationDestination` for `tabCoach` (index 2) in a conditional gated on `FeatureFlags.chatTabVisible` (default `false`). When flag is `false`, the `destinations` list has 3 items and `goBranch` indices shift — Aujourd'hui=0, Mon Argent=1, Explorer=2. The `MintChatOverlay` opens as a modal route on top of whichever tab is active; it does not require the shell branch.

**State preservation for in-flight sessions:** `ConversationStore` (already imported in `coach_chat_screen.dart`) persists conversation history in memory per-session. When the tab disappears, any in-flight turn is preserved in the store. The overlay reopens with the same `ConversationStore` instance if the user returns to the same card within the session. Cross-session persistence is out of scope for Phase 96 (the 3-turn cap resets per card-invocation anyway).

**Emergency walkback:** flag `CHAT_TAB_VISIBLE=true` re-adds the tab at index 2 without any code change. No UI stub or redirect needed — the route stays registered in GoRouter.

### Q2 — Card-actions intent bar: component

**Decision: `MintCardActionBar` — animated inline row, revealed on card tap, 3 verbs.**

**Final FR verb-set (3 verbs, not 5):**
- « Explique-moi » — triggers a narrative explanation grounded in the card's facts
- « Simule » — opens the relevant simulator scene via deep-link (no chat turn consumed)
- « Rassure-moi » — triggers an empathic reframing of the card's risk posture

Rationale for 3 not 5: DESIGN_SYSTEM.md §1 mandates « Hiérarchie radicale. Un élément dominant par vue, le reste recule. » Five verbs create scanning paralysis on a 390px card. « Simule » deliberately does NOT open the overlay — it routes to Explorer (zero turns consumed), which also satisfies the ROADMAP's « deep-link to Explorer scene » requirement for the cap message.

**Component anatomy:**
```
MintCardActionBar (StatelessWidget)
  → AnimatedContainer (height: 0 → 48dp, curve: easeOut, 200ms)
  → Row (mainAxisAlignment: center, gap: MintSpacing.sm)
    → _VerbChip(label: l.verbExplique, icon: Icons.lightbulb_outline)
    → _VerbChip(label: l.verbSimule,   icon: Icons.tune_outlined)
    → _VerbChip(label: l.verbRassure,  icon: Icons.shield_outlined)
```

`_VerbChip` uses `MintColors.primary` border, `MintTextStyles.labelMedium`, transparent fill, 8dp radius. Never hardcoded colors. The bar mounts **inline at the card bottom** (not a bottom sheet) — the card itself expands by 48dp. This keeps the user in scroll context and avoids a modal layer for a non-modal action. ARB keys required: `verbExplique`, `verbSimule`, `verbRassure` across all 6 locales.

### Q3 — 3-turn cap: strict, per card-session, server-side

**Decision: strict server-side cap, 3 turns, reset per card-invocation, no extension.**

Rationale: a soft cap with "allow extend" trains users to click through every warning — it becomes noise. The hypothesis being tested is whether 3 turns are sufficient to illuminate a card's insight. If they're not, that's a signal the card's content or verb framing is broken, not that users need more turns. Collect that signal via `chat_overflow_turn_4` Sentry metric rather than papering over it.

**Reset criteria:** per `source_card_id` × session. Opening the overlay on LPP card resets independently from opening it on a 3a card in the same session. A new app launch resets all counts.

**Turn 3 terminal message (FR):** « Je vais m'arrêter là. Pour aller plus loin, explore la simulation depuis cette carte. » + a `TextButton` deep-linking to the relevant Explorer scene (derived from `source_card_id` → `explorer_route` mapping). This message is templated server-side, not LLM-generated. It carries no `{{cite:}}` placeholder — it is a static string in the response envelope.

**Backend enforcement:** a `turn_count` field is passed in `CoachChatRequest` (new field, additive). Server-side: if `turn_count >= 3`, return the templated terminal message immediately, skip the LLM call entirely (zero token cost). The extractor is also bypassed at turn ≥ 3.

### Q4 — Source-card context propagation: SerializedCardContext schema

**Decision: extend `CoachChatRequest` with a `source_card` optional struct; backend primes narrator system prompt with it.**

`CoachChatRequest` already accepts `profile_context: Optional[dict]`. We add a typed sibling:

```python
class SerializedCardContext(CoachChatBaseModel):
    card_id: str                          # e.g. "lpp_buyback", "pillar_3a"
    card_type: str                        # ResponseCardType enum name
    card_headline: str                    # The displayed headline
    computed_facts: dict[str, Any]        # financial_core output — calc values only
    grounding_keys: list[str]             # GroundingPack keys relevant to this card
    life_event: Optional[str] = None      # e.g. "new_baby", "job_change", "housing"
    canton: Optional[str] = None          # e.g. "VD", "ZH", "GE"
    archetype: Optional[str] = None       # e.g. "expat_eu", "independent_no_lpp"
```

`computed_facts` carries only values from `financial_core/` calculators — never LLM-synthesized numbers. This is the N1 contract from `2026-05-09-calc-first-llm-illumination.md`. The narrator system prompt receives the card snapshot as a prefixed block:

```
[SOURCE CARD: {{card_type}} — {{card_headline}}]
Faits calculés: {{computed_facts}}
Clés de citation disponibles: {{grounding_keys}}
```

Flutter side: the card widget (e.g. `CapCard`, `ResponseCardWidget`) serializes its own data into `SerializedCardContext` and passes it to the `MintChatOverlay` constructor. No new service layer needed — the card already holds the data.

### Q5 — NarrativeSleeve: 4 fields + linter wiring

**Decision: NarrativeSleeve is a backend response envelope field; linter runs as response middleware, not pre-commit.**

**4-field contract:**

| Field | Definition | Constraint |
|---|---|---|
| `hook` | Opening sentence of the narrator response | No digit, no `{{cite:}}` expansion — pure voice. Max 15 words. Regex: `^\D+$` (no numeral) |
| `caption` | The cited number(s) sentence — `{{cite:key}}` already substituted | Must contain ≥1 substituted value. Source of truth for numbers |
| `next_step` | One concrete action the user can take today | Max 12 words. Verb-first. No banned LSFin terms |
| `metaphor` | Archetype/canton/event-adapted metaphor (see Q6) | Optional. Max 20 words. Never a promise |

**No-num-in-hook regex:**
```python
import re
NO_NUM_IN_HOOK = re.compile(r'\d')

def lint_hook(hook: str) -> bool:
    return not NO_NUM_IN_HOOK.search(hook)
```

**Test fixture pattern:**
```python
# PASS
assert lint_hook("Ce n'est pas une urgence, mais une décision qui se prépare.") is True
# FAIL
assert lint_hook("Avec 539 CHF de rachat possible") is False
assert lint_hook("En 3 ans, tu pourrais") is False
```

**Linter wiring:** response middleware in `coach_chat.py` endpoint, after narrator returns but before streaming to client. If `lint_hook` fails: swap the hook with a neutral fallback (`"Voici ce que disent tes chiffres."`), log to Sentry as `narrative_lint_hook_swap`. Do NOT reject the full response — swapping is safer than a 500 error during a coached session. Pre-commit lint is not appropriate here because hook content is runtime-generated.

### Q6 — Métaphore library: structure + examples

**Decision: static TOML lookup table keyed by (archetype × canton × life_event), resolved server-side at narrator prompt construction.**

```toml
# services/backend/app/data/metaphor_library.toml
[[metaphors]]
key = "expat_us.any.any"
text = "Comme un compte 401(k) qu'on ne peut pas laisser dormir, chaque année compte."
tags = ["fatca", "expat_us"]

[[metaphors]]
key = "any.VD.any"
text = "Dans ce canton, les déductions sont claires — mieux vaut les connaître avant janvier."
tags = ["vaud", "tax"]

[[metaphors]]
key = "any.GE.any"
text = "Genève a l'une des charges fiscales les plus élevées de Suisse — chaque levier aide."
tags = ["geneve", "tax"]

[[metaphors]]
key = "any.any.new_baby"
text = "Un enfant change le calcul AVS — c'est souvent là qu'une lacune s'installe sans qu'on le voie."
tags = ["family", "avs_gap"]

[[metaphors]]
key = "any.any.job_change"
text = "Un nouveau poste, c'est souvent un certificat LPP qu'on oublie de transférer à temps."
tags = ["career", "lpp"]

[[metaphors]]
key = "expat_eu.any.any"
text = "Les accords de totalisation AVS couvrent ton passé européen — mais ils ne s'appliquent pas automatiquement."
tags = ["expat_eu", "avs"]

[[metaphors]]
key = "independent_no_lpp.any.any"
text = "Sans 2e pilier, le 3a devient ta seule marge de manœuvre fiscale — elle est limitée mais réelle."
tags = ["independent", "pillar3a"]
```

Resolution order: `archetype.canton.event` → `archetype.any.any` → `any.canton.any` → `any.any.event` → no metaphor (field omitted). The narrator receives the resolved text (or nothing) — it does not generate metaphors itself.

### Q7 — Wave split: 3 waves recommended

**Decision: 3 waves, not 4. The nav-kill and overlay are inseparable; backend NarrativeSleeve is independent.**

| Wave | Scope | Owner | Blocker |
|---|---|---|---|
| W1 — Nav + UI | `mint_shell.dart` flag-gate, `MintCardActionBar`, `MintChatOverlay` modal scaffold, ARB keys (3 new), Maestro flow stub | Flutter | None — can start immediately post-Phase 95 |
| W2 — Backend context | `SerializedCardContext` schema, `CoachChatRequest` extension, `source_card` → narrator system prompt injection, turn_count enforcement + terminal message, `chat_overflow_turn_4` metric | Backend | Phase 95 GroundingPack keys non-empty |
| W3 — NarrativeSleeve + métaphores | `NarrativeSleeve` response envelope, hook linter middleware, metaphor TOML library + resolver, Maestro flow `flow_card_action_intent_bar.yaml` full 3-turn + cap + deep-link | Cross-stack | W2 merged + turn_count flow exercised |

4-wave split (separating nav-kill from overlay widget) is over-engineered: the overlay IS the replacement for the tab — shipping nav-kill without the overlay leaves users with no coach access for the duration of W2. Keep them atomic in W1.

### Q8 — G2 device verification path

**Must-have flow for Julien's TestFlight run:**

1. Open app → confirm bottom nav has 3 tabs (Aujourd'hui / Mon Argent / Explorer), no chat tab
2. Navigate to a card on the Aujourd'hui screen (e.g. the CapCard or a ResponseCard strip item)
3. Tap the card → `MintCardActionBar` animates in with 3 verb chips
4. Tap « Explique-moi » → `MintChatOverlay` opens as modal, displays turn 1 response with cited numbers from the card
5. Send 2 more messages → confirm turn 3 response shows the terminal message (« Je vais m'arrêter là… ») + deep-link button to Explorer
6. Tap the deep-link → confirm navigation to the relevant Explorer scene
7. Return to Aujourd'hui → confirm card state is unchanged (no overlay auto-reopen)
8. Tap « Simule » on any card → confirm direct navigation to simulator (no overlay, zero turns consumed)

---

## Counter-arguments and data gaps

**Strongest opposing view — « Chat IS the product, don't kill the tab »:**
The 2026 fintech trend toward conversational interfaces as primary surfaces (Capital One, Cleo, Copilot) argues that a chat tab is the entry point users trust. Killing it risks disorienting the users who already built a habit around the Coach tab — especially early adopters who do multi-turn planning sessions. A card-action bar of 3 chips is a weaker surface than an open text field: it constrains expressivity, and real user needs are often outside the 3 verb taxonomy. The adversarial counter-thesis listed in `ROADMAP.md §Risks` is legitimate: if `chat_overflow_turn_4` fires at >40% within 7 days, the feature flag walkback is the only safety net, and a mid-TestFlight toggle is a bad user experience.

**What this decision does not address:**
- We have no quantitative data on how many MINT early-adopter sessions currently exceed 3 turns. The 40% threshold is hypothetical. If the real rate is 60%, the walkback path is activated immediately and Phase 96 effectively ships nothing.
- The `MintChatOverlay` inherits the full `CoachChatScreen` import graph (57 imports, ~900+ LOC). We have not audited whether a modal overlay version of that screen is architecturally lean or whether it drags the entire coach orchestration pipeline into every card render.
- The metaphor library is static TOML. It does not cover multi-axis intersections (e.g. `expat_us.GE.new_baby`) unless explicitly authored. At scale this becomes unmaintainable without tooling.
- ARB parity for 3 new verb keys across 6 locales (fr/en/de/es/it/pt) is assumed trivial but translation quality for « Rassure-moi » in German (`Beruhige mich` sounds clinical) needs a native review gate.

**What would change this conclusion:**
- If `chat_overflow_turn_4` >40% in the first 7-day soak: extend the cap to 5 turns and re-evaluate the tab kill.
- If `MintChatOverlay` profile shows widget-rebuild cost >16ms per frame on older iPhones (A14 target): split the overlay into a lazy-loaded separate route instead of inline modal.
- If Phase 95 GroundingPack delivery slips past W1 close: W1 can ship without computed_facts (overlay shows static card data only), but `SerializedCardContext.grounding_keys` must be empty-list-safe on the backend.

---

## Sources

- `apps/mobile/lib/widgets/mint_shell.dart` — current 4-tab shell (lines 46-67, chat at index 2)
- `apps/mobile/lib/screens/coach/coach_chat_screen.dart` — coach screen import graph
- `services/backend/app/schemas/coach_chat.py` — `CoachChatRequest` base schema
- `services/backend/app/services/coach/grounding_pack.py` — Phase 95 stub (currently empty)
- `.planning/ROADMAP.md` §Phase 96 (lines 231-245)
- `.planning/decisions/2026-05-09-calc-first-llm-illumination.md` §N1 closed-world numeric vocabulary
- `docs/DESIGN_SYSTEM.md` §1 (Hiérarchie radicale), §2.A (Hero Screens)
- `docs/VOICE_SYSTEM.md` §2 Tone by Context (Coach = conversationnel, complice)
- External — G&CO. « The Best UX Design Practices for Finance Apps in 2026 »: https://www.g-co.agency/insights/the-best-ux-design-practices-for-finance-apps (fetched 2026-05-10)
- External — eleken.co « Fintech UX Best Practices 2026 »: https://www.eleken.co/blog-posts/fintech-ux-best-practices (fetched 2026-05-10)
- External — neuronux.com « UX Design Best Practices for Conversational AI and Chatbots »: https://www.neuronux.com/post/ux-design-for-conversational-ai-and-chatbots (fetched 2026-05-10)
- External — layoutscene.com « Mastering Card UI Design Patterns for 2026 »: https://www.layoutscene.com/card-ui-design-patterns-guide-2026/ (fetched 2026-05-10)

---

## Status & follow-up

- Implementation tracking: Phase 96 GSD not yet opened. This document feeds `/gsd-discuss-phase 96 --auto`.
- Re-litigation triggers:
  - `chat_overflow_turn_4` >40% after 7-day soak → extend cap or restore tab
  - `MintChatOverlay` render budget >16ms → refactor to lazy route
  - Phase 95 slips → W1 ships with empty `grounding_keys`, W2 hard-blocked

---
*Panel v1 — 2026-05-10. 1-shot brief, pre-GSD-discuss. Karpathy Wiki Pattern practice 3 enforced.*
