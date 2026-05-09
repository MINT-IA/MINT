# Phase 91 G2 Device Walkthrough — Sign-off

**Date :** 2026-05-09 23:21 Europe/Zurich
**Build :** `git rev-parse HEAD` = `edfdfe775bc455274846382fbbd5c9e0ca1e98dd` (branch `docs/phase-2-extractor-v2-research`, dev simulator debug build)
**Device :** iPhone 17 Pro simulator iOS 26.2 — UDID `B03E429D-0422-4357-B754-536637D979F9` (sim qualifies for G2 per memory `feedback_device_gates.md`)
**Backend :** Railway staging (`https://mint-staging.up.railway.app`)
**Narrator model :** `sonnet` per Stage 3 Decision (`narrator=sonnet` kill-policy fallback per ADR-20260419-v2.8 ; commit `d9eb435c` Task 5.3)
**Executor :** PM Claude (autonomous walkthrough per memory `feedback_device_gates.md` ; sim + idb wired so Claude does device walkthroughs)

## Verdict

**PASS (partial)**

Resume signal Julien (verbatim) : `g2=pass partial="(1) multi-turn discontinuity in anonymous chat is by D-04 design — surface as Phase 96 input ; (2) sim latency 6.3s above 5s spec — monitor in production via Phase 94 CITATION-GATE telemetry; production p50 expected lower"`

Concerns partiels documentés — ne bloquent pas le close-out Phase 91. Routés vers Phase 96 (multi-turn continuité) et Phase 94 (latence télémétrie).

## Step-by-step results

| Step | Criterion | Result | Notes / Evidence |
|------|-----------|--------|-------|
| 3.1 | No banned LSFin terms | PASS | Maestro `assertNotVisible` for `garanti`, `optimal`, `sans risque` all COMPLETED (`maestro.log:23:21:40-42`). Visual confirmation in `g2-02-turn2.png` + `g2-04-final.png` (read by PM Claude — none of the 7 banned terms present). |
| 3.2 | FR accents corrects | PASS | Visual : `g2-02-turn2.png` shows `Né`, `déjà`, `côté`, `générale` all properly accented ; `g2-04-final.png` shows `prêt·e`, `réel`, `érosion`. No ASCII fallback observed. |
| 3.3 | No phantom tool emissions | PASS | Maestro `assertNotVisible` for `save_fact(`, `save_insight(`, `<function_calls>`, `<tool_use>` all COMPLETED (`maestro.log:23:21:38-40`). Visual confirmation : no « j'enregistre… » / « je note… » phrases either. |
| 3.4 | MINT voice (lucidite > protection) | PASS (PM Claude assessment, awaits Julien confirmation) | Turn-1 framing : « 3e pilier A » as « optimisation fiscale » + concrete numbers (« 7'258 CHF/an », « 60'000 CHF économisés »), not as « préparez votre retraite ». Turn-2 framing : « érosion lens » + Cleo-style mirror question (« Quel degré d'érosion suis-je prêt·e à accepter ? »). |
| 3.5 | Acknowledge les 3 facts (turn-1) | PASS | `g2-02-turn2.png` shows turn-1 reply contains : (a) « taux marginal Vaud 25-28% » → canton VD acknowledged ; (b) « 7'258 CHF/an » → 3a plafond computed per 80k income context ; (c) « Né en 1990, tu as 35 ans » → birthYear acknowledged. All 3 facts surfaced. |
| 4   | Multi-turn continuité | **FAIL EXPECTED** (anonymous = stateless per D-04) | Turn-2 reply does NOT reference Lausanne / 80k / 1990. Drift to general « érosion d'épargne » discourse. **Per D-04, anonymous chat = request-scoped extractor state, no persistence across turns at narrator level.** This is by design. Awaits Julien judgment whether acceptable for MVP ship. |
| 5   | Latency feel | MARGINAL (6.3s turn-1 / 5.8s turn-2) | Above 5s « concern » spec. Sim cellular + streaming render explains. Production p50 expected lower (sonnet baseline ~2-4s per Stage 3 eval). Awaits Julien judgment. |

## Screenshots (Evidence per CLAUDE.md §9.6)

- **Turn 1 (early capture, streaming) :** `.planning/phases/91-mvp-extractor-v2/g2-evidence/g2-01-turn1.png`
  - Shows : user message « j'ai 80k de salaire à Lausanne, je suis né en 1990 » sent ; 3-dots typing indicator ; disclaimer « Information générale, pas un conseil financier personnalisé. » footer.
- **Turn 2 input (turn-1 reply rendered fully) :** `.planning/phases/91-mvp-extractor-v2/g2-evidence/g2-02-turn2.png`
  - Shows : full turn-1 coach reply with 3 facts acknowledged ; user follow-up « et toi, qu'est-ce que tu en penses ? » sent ; 3-dots typing.
- **Final (turn-2 reply rendered fully) :** `.planning/phases/91-mvp-extractor-v2/g2-evidence/g2-04-final.png`
  - Shows : full turn-2 coach reply with érosion-lens framing ; LSFin disclaimer ; composer ready for next message.
- **Drawer :** N/A (anonymous chat does not expose profile drawer per D-04 — `runFlow` conditional skipped gracefully ; not a defect).

## On-brand verdict (D-06 4e critère)

**PM Claude pre-assessment (PENDING Julien confirmation) :**

> The turn-1 narrator reply is on-brand per VOICE_SYSTEM.md : it frames the 3a optimization as a tax mechanism with concrete CHF numbers (« 7'258 CHF/an plafond 2025 », « 60'000 CHF économisés cumulés ») rather than as a generic « prépare ta retraite » prescription. It mirrors the user's phrasing (« tu utilises déjà cette optimisation fiscale, ou tu découvres cette mécanique ? ») and asks a tense, curious question rather than telling. Turn-2 maintains the lucidite frame (« érosion », « pouvoir d'achat réel », « *Quel degré d'érosion suis-je prêt·e à accepter ?* »).
>
> Two flags for Julien :
> 1. **Multi-turn discontinuity** : turn-2 does not reference Lausanne / 80k / 1990. This is the documented D-04 stateless design for anonymous chat, but UX-wise it's a regression for a returning user who expects continuity. Whether this is acceptable for MVP ship or needs Phase 96 / chat-as-verb work to fix is a Julien call.
> 2. **Latency 6s on sim** : above the 5s spec but consistent ; production should be faster. Whether the « feels » test passes or fails is a Julien call (PM Claude has no embodied sense of « slow »).

## Caveat (per CLAUDE.md §9.6)

**What was NOT verified :**

- **No real device walkthrough** — sim only (iPhone 17 Pro iOS 26.2 on Mac mini). Per memory `feedback_device_gates.md` this qualifies as G2 ; per CLAUDE.md §9.5 this is the « post-merge sim » row, not the « real iPhone in user's hand » row. TestFlight install was explicitly skipped per Julien preference 2026-05-09 « Sim for both G1 and G2 » (per orchestrator objective).
- **No `_user` registered flow** — anonymous chat path only. The `persistence_consent` path + LPP scan path + FATCA archetype path are NOT exercised by this G2.
- **Drawer profile assertion N/A** — anonymous chat doesn't expose the drawer (D-04). The « profile reflects 3 facts » criterion was structurally inapplicable. If a registered-user G2 is required, that's a separate plan (out of scope for 91-06).
- **Production cost trajectory NOT measured** — depends on Phase 96 (chat-as-verb 3-turn cap) ; can't be measured in 91-06.
- **Latency on real device, real cellular NOT measured** — sim wifi only (Mac mini ethernet → Railway).
- **Multi-turn continuity gap is by-design** — D-04 documents anonymous as request-scoped stateless. The turn-2 discontinuity is NOT a regression vs spec ; it's the spec. But a journalist or Julien-on-his-iPhone would experience it as a UX gap.
- **API direct text capture failed (401)** — `/api/v1/coach/chat` rejected unauthenticated curl from PM Claude's CLI. Visual capture (screenshot OCR via image read) substitutes for the text grep — equally deterministic per CLAUDE.md §9.6 (image content read by Claude is a citation type).
- **Maestro `takeScreenshot` early-capture quirk** — the first `takeScreenshot` in the flow fired ~7s after user input, before the streaming reply finished rendering, hence g2-01 shows typing indicator only. Subsequent screenshots (g2-02, g2-04) capture fully-rendered replies. This is a flow timing limitation documented in `mechanical-checks.json` ; the deterministic citation chain holds.

---

## Julien Sign-off (2026-05-09)

**Resume signal reçu (verbatim) :**

```
g2=pass partial="(1) multi-turn discontinuity in anonymous chat is by D-04 design — surface as Phase 96 input ; (2) sim latency 6.3s above 5s spec — monitor in production via Phase 94 CITATION-GATE telemetry; production p50 expected lower"
```

**Routing downstream :**

1. **Multi-turn discontinuité** (concern 1) → Phase 96 MVP-CHAT-AS-VERB (3-turn cap + profile context injection dans le narrator loop anonymous).
2. **Latence sim 6.3s** (concern 2) → Phase 94 MVP-CITATION-GATE (narrator p50 tracking + télémétrie production).

**Phase 91 close-out :** G2 PASS partial. `91-VERIFICATION.md` frontmatter flippé à `status: verified`, `gaps: []`, score 7/7 (plan 91-06 Task 6.3). 5-gate exit contract complet.
