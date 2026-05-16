---
name: phase-96-killed-2026-05-16
description: Julien-signed decision 2026-05-16 to KILL Phase 96 (MVP-CHAT-AS-VERB) outright, superseding the earlier 2026-05-14 PAUSE. Doctrine pivot back to chat-first with exploratory widget rendering ("Option C — Coach didactique vivant"), tab Coach reste, cards-home destination doctrine dropped.
status: Decided 2026-05-16 by Julien
date: 2026-05-16
authors: Claude (Product Lead, MINT) drafted ; Julien decided + signed in session 2026-05-16
metadata:
  type: decision
  topic_key: phase_96:status:killed
related:
  - [[calc-engine-matrix-2026-05-16]]
supersedes:
  - .planning/MILESTONE-CHAT-AS-VERB-2026-05-09.md
  - .planning/decisions/2026-05-14-phase-7-ship-or-pause.md (extends — PAUSE → KILL)
---

# Phase 96 KILLED — chat-first doctrine restored

## TLDR

Phase 96 « MVP-CHAT-AS-VERB » is KILLED outright. The « kill chat-tab, cards become home, chat becomes a verb » pivot proposed 2026-05-09 and PAUSED 2026-05-14 is no longer on the table. Direction restored : **tab Coach reste, chat est la porte d'entrée principale, avec un angle exploratoire via widgets rendus inline** (Option C from the 2026-05-14 /office-hours session — Coach didactique vivant).

## Counter-arguments and data gaps

**Counter-argument 1 :** « 4 phases (94, 95, 96, parts of 91-93) shipped under the chat-as-verb umbrella. Killing 96 wastes that investment. »
- Rebuttal : Phases 91 (extractor), 94 (citation gate), 95 (DAG invalidation), 93.5 (skill bundle compiler) are NOT chat-as-verb-specific. They are foundation infrastructure that survives the doctrinal change ; only the **kill-tab** + **cards-home destination** elements of Phase 96 die. The narrative-sleeve linter from 96-03 also survives — it's just framing-agnostic.

**Counter-argument 2 :** « North-star metric (turns/user/week DOWN) was the soul of Phase 96 — killing it loses the metric. »
- Rebuttal : the metric was a proxy for « less chat = more lucidity ». Coach-vivant achieves the same goal differently : each chat turn is denser (forced tool invocation + inline widgets + citation chips). Replace the metric with « citation-chip rate per turn » + « invariant-surfacing rate per turn » + « zero-citation hallucination rate ».

**Counter-argument 3 :** « Maybe Phase 96 was correct and Coach engagement metrics will eventually justify the kill-tab. Why decide now rather than wait for Wave 1c ship + measurement ? »
- Rebuttal : Julien explicit 2026-05-16 — « c'est un gros risque que j'ai pas envie de continuer à prendre ». Founder-signed risk veto. Continuing to plan under a paused doctrine creates drift between roadmap and code (already evident — ROADMAP.md line 64 said « completed 2026-05-11 » while `chatTabVisible = true` in the live app). Clean kill > dangling pause.

**Data gaps :**
- Did NOT measure Coach engagement metrics post-Wave-1c-A2.1 ship (the bet from the 2026-05-14 decision). Killing now without that data is acceptable because the kill-decision is risk-driven (founder doesn't want to bet that direction), not metric-driven.
- Did NOT survey users on the « chat-as-verb » prototype (was never built ; only the architectural plumbing shipped).

## Sequence of events

| Date | Event |
|---|---|
| 2026-05-09 | `MILESTONE-CHAT-AS-VERB-2026-05-09.md` synthesized by 4-expert panel ; Phase 96 added to ROADMAP. |
| 2026-05-09 → 05-11 | Phases 90, 91, 94, 95 and parts of 92-93 shipped under the chat-as-verb umbrella. Phase 96 itself (« kill chat-tab ») was the doctrinal apex. |
| 2026-05-11 | `chatTabVisible` flag added to `apps/mobile/lib/services/feature_flags.dart:116`, defaulted to `true`. No PR has flipped it to `false`. |
| 2026-05-14 | `/office-hours` session surfaces Option C (Coach didactique vivant + tool-using backend + render_widget inline). Julien signs `.planning/decisions/2026-05-14-phase-7-ship-or-pause.md` → Phase 96 **PAUSED** pending Wave-1c outcome. |
| 2026-05-16 | This decision. Julien explicit : « ce drift pour la phase 96 est à corriger absolument, ça veut dire je pense qu'on peut jeter carrément cette phase 96 ». PAUSE → **KILL**. |

## What's killed vs. what's preserved

### KILLED (no longer doctrine)

- « Kill the chat-tab ». The tab stays.
- « Cards become the home destination ». Home stays chat-first.
- « Chat as a verb invocable from card-actions only ». Chat is the porte d'entrée.
- « 3-turn cap » as a hard product constraint. Coach turns are governed by intent + lucidité, not by a count cap.
- The phrase « narrator LLM is mathematically incapable of emitting an un-cited number » is REWORDED — it survives as a discipline (citation gate Phase 94) but no longer as a doctrinal headline ; the chat-as-verb framing it was attached to is dead.
- ROADMAP.md line 14 milestone label « v2.9 Chat-as-Verb Pivot » must be renamed and superseded.

### PRESERVED (still active doctrine)

- Phase 91 extractor / narrator split. Coach is still 2-LLM architecture (extractor + narrator).
- Phase 94 citation gate (`{{cite:<key>}}` placeholders + post-hoc substitute + closed-world numeric vocabulary). This is THE LSFin lucidité contract.
- Phase 95 DAG invalidation (`inputs_hash` + `superseded_by` + `GroundingPack`). Foundation for the future « calc engine » phase.
- Phase 93.5 skill bundle compiler (pillar3a-optimizer, lpp-projector, etc.). Bundles concept is THE solution to the 57-calculator LLM-discoverability problem (see [[calc-engine-matrix-2026-05-16]]).
- The 4-level **lucidité** framework (L1 chiffrer / L2 comparer / L3 éclairer arbitrage caché / L4 surfacer invariants). LSFin-clean ; FINMA-compliant ; replaces the « chat-as-verb / cards-as-home » framing as the product doctrine.
- All design lints from Phase 90.

### REWRITTEN

- The « turns / user / week DOWN » north-star metric is dropped. Replacement metric proposed for `mint-calc-engine-v1` discuss-phase : « citation-chip coverage per coach turn » + « hallucination rate (zero-citation numeric emission rate) » + « profile-grounded calc rate (calculator invocations that read real user profile vs hardcoded defaults — per hypothesis C in [[calc-engine-matrix-2026-05-16]]) ».

## Direction restored — Coach didactique vivant

- Chat is the entry point. Tab stays in 4-tab nav.
- The user types in chat AND can click widgets rendered inline by the coach to drill down.
- Widgets are produced by the calculator surface (the 57 calcs) and rendered by the narrator on its decision (« voici tes options 3a / rachat LPP / amortissement », chip-rendered).
- The « exploratory angle » = widgets are interactive, not static (filter by canton, change horizon, toggle property-owner status — and the narrator re-narrates).
- This makes the calculator engine + LLM tool registry + DAG invalidation the critical path, NOT the home-screen redesign.

## What this decision REQUIRES next

- **Update `ROADMAP.md`** :
  - Line 14 : `🟡 v2.9 Chat-as-Verb Pivot — KILLED 2026-05-16, see decisions/2026-05-16-phase-96-killed.md. Foundation phases (91/93.5/94/95) preserved as `v2.9 Lucidité Foundation` ; chat-as-verb destination doctrine dropped.`
  - Line 64 : `[~] Phase 96 KILLED 2026-05-16 — kill-tab + cards-home doctrine dropped ; narrative-sleeve linter from 96-03 survives as a framing-agnostic discipline ; intent-bar UI scaffolding (96-01) becomes vestigial pending re-evaluation.`
- **Update `feature_flags.dart`** : `chatTabVisible` default stays `true` (already correct), but the comment block above the flag should be rewritten from « pending Phase 96 ship » to « doctrine restored — tab is the porte d'entrée per decision 2026-05-16 ».
- **Open `mint-calc-engine-v1` discuss-phase** : the next milestone is the calculator + lucidité engine, not chat-redesign. See [[calc-engine-matrix-2026-05-16]] for the 4 problem areas to scope.
- **Audit hypothesis C** (real-profile grounding) before any planning under the new direction. If broadly true, all 57 calculators ship garbage outputs until a profile-fill layer is added.
- **Rename `MILESTONE-CHAT-AS-VERB-2026-05-09.md`** to `MILESTONE-CHAT-AS-VERB-2026-05-09.archive.md` with a top banner « SUPERSEDED 2026-05-16 — see decisions/2026-05-16-phase-96-killed.md ».

## Sources

- Julien 2026-05-16 verbatim (this session) : « ce drift pour la phase 96 est à corriger absolument, ça veut dire je pense qu'on peut jeter carrément cette phase 96. En tout cas c'est un gros risque que j'ai pas envie de continuer à prendre. »
- `.planning/decisions/2026-05-14-phase-7-ship-or-pause.md` (Julien-signed PAUSE — this decision EXTENDS that one from PAUSE to KILL).
- `.planning/MILESTONE-CHAT-AS-VERB-2026-05-09.md` (the 2026-05-09 panel doctrine — now superseded).
- `apps/mobile/lib/services/feature_flags.dart:116` (`chatTabVisible = true` — the « tab stays » code reality already correct).
- `.planning/ROADMAP.md` lines 14 + 46-65 (the stale ROADMAP entries to be rewritten).
- Engram memory `feedback_critical_pm_mode` — founder-signed risk veto > metric-driven measurement when founder explicit risk threshold is hit.
