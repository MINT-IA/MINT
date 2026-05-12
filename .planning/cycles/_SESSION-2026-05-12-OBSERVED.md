---
description: Pillar 0.a SCOUT walkthrough — observations from iPhone 17 Pro sim on staging build, 2026-05-12T19:30Z. Captured per MDM v1 Pillar 0.a discipline (sim-first, breadth-first, categorise BLOCKER / DEGRADED / COSMETIC, do NOT fix mid-scout).
type: session-observed
created: 2026-05-12
archetype: anonymous_wedge (julien_swiss seed)
sim_device: iPhone 17 Pro (B03E429D-0422-4357-B754-536637D979F9) iOS 26.2
backend: Railway staging `mint-staging.up.railway.app` (post P003 + B023b + hotfixes, health 200)
build_under_test: post-PR-#574 staging container (commit 41ff6d81 ; alembic head p97_snapshots_fk_defaults)
flows_run:
  - tools/simulator/flows/regression/bug__S005__landing_anonymous_cta_to_home.yaml (1/1 Passed, 9s)
  - tools/simulator/flows/regression/bug__F001_S001_combined__chat_via_cap_du_jour.yaml (1/1 Passed, 10s)
final_screenshot: /tmp/scout_post_chained_flow.png
---

# SCOUT walkthrough — 2026-05-12T19:30Z

Maestro regression flows passed (structural assertions GREEN). Manual end-state inspection of the sim surfaces 4 defects the flows do NOT catch — SEMANTIC defects (« overlay opens but shows nothing useful ») vs STRUCTURAL defects (« overlay opens »). Validates CLAUDE.md §9.2 « tests passing ≠ feature working ».

## Defects

### BLOCKER — none

S005 + F001_S001_combined both passed end-to-end (cold-launch → landing → « Continuer sans compte » → /home → CapDuJourBanner → MintCardActionBar → « Explique-moi » tap → MintChatOverlay opens). No hard blocker stops the user reaching the overlay.

### DEGRADED — D1 — MintChatOverlay body is empty after « Explique-moi » tap

**Observed** : overlay opens with header « explain » + turn counter « 0 / 3 » + bare input « Tape ton message... ». Body between header and input is COMPLETELY EMPTY. No coach opener, no source_card acknowledgement, no narrative_sleeve auto-render.

**Expected (per Phase 96 D-13..D-17)** : on intent=explain tap, narrator should auto-fire turn 1 using source_card (computed_facts + grounding_keys + life_event + canton + archetype) to render an opening narrative_sleeve. User lands in populated overlay.

**Maestro coverage gap** : flows assert structural visibility (overlay opens, ID present) but NOT that the overlay contains a coach opener message. Pass despite the semantic failure.

**Hypothesis** : (a) auto-fire-turn-1 on overlay open not wired in client, OR (b) backend returns empty (same pattern as P003 dim-3 ambiguous result), OR (c) source_card is None on this trajectory (CapDuJourBanner not populating SerializedCardContext).

**Severity** : DEGRADED — user CAN still type manually. But « chat-as-verb » value prop collapses : « Explique-moi » functionally identical to « tap Coach tab ». Differentiation lost.

**File** : new registry row P004 or F009 for Phase 97.5 R2.

### DEGRADED — D2 — Overlay header is bare technical label « explain »

**Observed** : header shows raw intent enum value `explain` (lowercase English).

**Expected** : human FR label per VOICE_SYSTEM. e.g. « Explique-moi le cap du jour » mirroring the verb. Today leaks API enum to user-facing UI.

**Severity** : DEGRADED — breaks « apparition humaine » MINT_IDENTITY §3. Voice-system violation.

### DEGRADED — D3 — Coach tab still visible in BottomNav

**Observed** : 4-tab nav (Aujourd'hui | Mon argent | Coach | Explorer).

**Expected (per Phase 96 D-21 + MILESTONE-CHAT-AS-VERB doctrine)** : `chatTabVisible=false` flag should be flipped on staging once chat-as-verb path is solid. Today the flag flip hasn't happened — gated on D1 working.

**Severity** : DEGRADED. Milestone-gate dependency.

### COSMETIC — C1 — TextField placeholder « Tape ton message... » too directive

**Observed** : placeholder « Tape ton message... » (tu-form imperative).

**Expected** : VOICE_SYSTEM N2-aligned register. « Écris ton message... » or « Que veux-tu savoir ? » or just « Message... ».

**Severity** : COSMETIC. Defer to v2.10 voice-system sweep.

## Triage outcome

- 0 BLOCKER → no cycle interruption needed.
- 3 DEGRADED → file as new registry rows for Phase 97.5 R2.
- 1 COSMETIC → defer to v2.10.

**Highest-impact DEGRADED in v2.9 critical path = D1 (empty overlay)**. Without D1 fixed, chat-as-verb pivot has no visible value prop, and the « kill chat-tab » flag flip (D3) cannot proceed.

## Why this SCOUT was load-bearing

Regression flows passed (junit `failures=0`). Today's P003 fix landed cleanly. CI green. Without manual SCOUT discipline, the team would have assumed « post-P003 = chat-as-verb works » and moved on. The SCOUT surfaced that the overlay opens but is empty — structural plumbing correct, semantic content missing. Validates Julien's 2026-05-12T09:30Z directive (sim-first) mechanically. Without observation-first, structural-tests-only signal masks this defect indefinitely.

## Next cycle picks (Phase 97.5 R2 input)

- D1 → P004 (empty chat-as-verb overlay) — highest-impact, gates v2.9 ship.
- D2 → COSMETIC bundled with D1's PR (narrow scope, same widget).
- D3 → flag-flip readiness, gated on D1.
- C1 → v2.10 voice-system sweep.
