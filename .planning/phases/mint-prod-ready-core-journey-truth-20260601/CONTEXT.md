---
description: Mission control context for the next MINT production-readiness push: one truth, coherent human journeys, Maestro-proven behavior, no new features.
status: active
date: 2026-06-01
owner: codex
---

# MINT Prod-Ready Core Journey Truth — Context

## Mission

Make MINT production-ready as a Swiss fintech lucidity coach app by fixing the core experience before adding anything new.

This phase is not a feature phase. It is a convergence phase:

- one user truth everywhere;
- no duplicate surfaces with unclear ownership;
- navigation that matches a human mental model;
- product storytelling that helps a user decide;
- Maestro and tests proving real app behavior, not only code paths.

The first releasable story is deliberately narrow:

> A French-speaking Swiss beta user in the supported native Swiss archetypes gives MINT their facts, sees the same money truth in Budget and Mon Argent, asks the Coach, receives a cited/current answer, and opens Rapport as a synthesis/proof surface with one next action.

Everything outside that story is either supporting infrastructure, a release blocker, or deferred.

## Non-Negotiables

- No new features.
- No hardcoded user-facing strings.
- No surface-only design polish before the screen role is clear.
- No facade without wiring.
- No claim of "done" without deterministic proof: tests, route contracts, screenshots, Maestro, or explicit user/device confirmation.
- Do not abandon salvage work already done; each step must preserve prior profile-truth and money-trust fixes.

## Current Ground Truth

Recent pushed branch head:

- `99f2c4505 Reposition rapport navigation contract`
- `2448d9724 Refocus rapport budget summary`
- `8e1aaecb5 Remove duplicate rapport budget total`
- `901f06a73 Stabilize mobile profile truth QA`
- `e3e632dba Harden profile truth write paths`

Recent conclusions:

- `/rapport` is not orphaned, but must be an explicit synthesis/report artifact, not a fallback, mini-dashboard, or daily money surface.
- Budget details belong to Budget and Mon Argent; Rapport may show only supporting proof or action synthesis.
- `financial_report` must not inject generic profile-prefill keys into a screen expecting wizard-shaped answers.
- `/report` and `/report/v2` are legacy aliases, not Coach destinations.
- Unknown coaching tips should stay in Coach, not open Rapport.

Current architectural backbone to protect:

`wizard_answers_v2` -> `CoachProfile` -> `MintStateEngine` -> `BudgetSnapshot/DataSpineSnapshot` -> `CoachContextPacket` -> backend sanitizer/tools.

Mobile owns deterministic L1 figures. Backend owns L2-L4 compare/explain/invariant payloads. Rapport, Coach, Budget, and Mon Argent must consume that spine, not invent competing truth.

## Supported Beta Scope

| Dimension | In scope for this phase | Policy |
|---|---|---|
| Language | French-first, with ARB parity when copy changes | No hardcoded user-facing copy |
| Archetypes | `swiss_native`, `swiss_native_couple` | Unsupported archetypes must be gated cleanly |
| Primary journeys | Profile truth, Money trust, Coach trust, Rapport synthesis | Maestro/runtime proof required |
| Life events | Only events already wired into the supported core story | No broad life-event expansion |
| Financial claims | Current/cited constants only, or explicit refusal | No stale 2024 numbers, no uncited Coach figures |

## Core Product Map

| Surface | Human job | Owns | Must not own |
|---|---|---|---|
| Coach | "I ask, clarify, and get guided to the next right surface." | conversation, fact capture, routing, explanations | duplicate dashboards |
| Mon Argent | "Where am I financially today?" | live money overview, budget state, confidence/readiness | detailed setup workflow |
| Budget | "How do I configure and understand my cashflow?" | budget inputs, categories, envelopes, fixed-charge detail | cross-domain synthesis |
| Rapport / Synthese | "What does MINT know, what matters, and what should I do next?" | generated synthesis, evidence, top decisions, export | daily dashboard, default fallback |
| Profile / Dossier | "What data does MINT know about me?" | user facts, provenance, completeness, correction | recommendations without context |
| Scan | "I add trusted documents." | extraction, review, profile update | silent profile mutation |
| Explorer / Simulators | "I explore a specific topic or decision." | domain-specific calculators, education, scenario canvases | global truth dashboard |

## Known Risk Families

| Risk | Symptom | Why it matters |
|---|---|---|
| Multiple truth sources | Same number differs across Budget, Mon Argent, Rapport, Coach | Trust collapse |
| Wrong route role | Screen opens from Coach but does not match user intent | User feels lost |
| Duplicate surfaces | Same information appears in several screens with different hierarchy | Product feels incoherent |
| Profile write/read drift | User gives a fact, but restart/Coach/screen shows old or partial truth | Core app promise breaks |
| Design before role | UI looks styled but tells no decision story | Polish hides confusion |
| Test-only proof | Widget tests pass but simulator flow fails | False readiness |
| Stale verifier docs | Agents run commands that no longer exist | Verification becomes theatre |
| Transient evidence | Screenshots/logs live only in `/tmp` | Future agents cannot audit closure |

## Exit Criteria

This phase is complete only when:

1. A Core Journey Truth Map exists and is current.
2. P0 duplicate/contradictory truth paths are fixed or explicitly deferred with evidence.
3. The money trust chain and profile truth chain are proven with Maestro or equivalent simulator evidence.
4. Coach trust is proven for one cited/current Swiss finance answer, or it refuses cleanly with no stale constants.
5. Every surviving core surface has a stated human job and route ownership.
6. A bug tracker lists open/closed state with persistent verification evidence under `.planning/`.
7. Phase 02 event-log/fact-current deployment/cutover risk is either closed or explicitly marked release-blocking.
8. The repo is clean and all pushed commits are atomic.
