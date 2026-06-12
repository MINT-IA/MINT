---
date: 2026-06-12
status: Proposed
authors: docs-architect (subagent) + Julien review pending
phase: mint-etat-des-lieux-20260612
description: Documentation corpus audit — coherence with founder vision, contradiction table, gap analysis, PRODUCT-SPINE skeleton, optimised doc-set proposal, founder-challenge.
---

# MINT Docs Audit — État des lieux 2026-06-12

## TLDR

The ~10 steering documents that agents and the founder actually read are structurally sound but **three years behind the product's reality** and **silent on four pillars of the current founder vision**: per-user data spine, arbitrage algorithms, generative widgets, and document-upload lifecycle. A single "PRODUCT-SPINE" document does not exist; its absence forces agents to triangulate across IDENTITY + ROADMAP_V2 + SOT + DESIGN_SYSTEM + CLAUDE.md, producing coverage gaps and contradictions. The recommended fix is a two-step triage: (1) patch four documents this sprint to remove contradictions that bite agents today; (2) author a PRODUCT-SPINE.md as the new north-star steering doc, replacing ROADMAP_V2 as the primary product vision reference.

---

## 1. Per-Doc Verdict Table

| Doc | Last substantive update | Freshness | Agent-steering role | Key contradictions / gaps |
|---|---|---|---|---|
| `docs/MINT_IDENTITY.md` | 2026-04-05 | Stale 68 days | Brand voice, compliance messaging, taglines | Missing accents throughout (« Mint n'accuse pas. Mint eclaire. » — every é missing); framing limited to document-upload analysis and pillar-3a-type scenarios; **silent on budget tracking, simulation lifecycle, arbitrage algorithms, generative widgets**; taglines don't mention lucidité or lifelong companionship |
| `docs/ROADMAP_V2.md` | 2026-03-25 (header), note 2026-04-05 | Stale 79 days | Product phases, sprint objectives, KPIs, monetisation | All 4 phases flagged `shipped` at 90-100% — a **misleading signal** since dozens of services are `foundation` or `partial`; voice AI is stub-only; pgvector not activated; agent autonome not wired. North-star metrics (5K active users by Phase 1 end) have no accountability owner. The doc has become a historical snapshot, not a steering tool. Autoresearch agent schedule in §§ Phase 1-3 is aspirational infrastructure that never shipped as described. No mention of per-user data spine (event-log), DEK vault, or projection invalidation — all three are architectural decisions from May 2026. |
| `SOT.md` | 2026-03-25 | Stale 79 days | Domain object contracts (Profile, SessionReport, EnhancedConfidence) | `SessionReport` is missing `confidenceScore`, `chiffreChoc`, `alertes`, `simulationAssumptions` (self-documented as "NOT YET IMPLEMENTED"). The `CoachProfile.archetype` contract says "computed property from nationality+arrivalAge+employmentStatus+residencePermit" but ADR 2026-05-17 surfaced that archetype gating on 6/8 archetypes is broken. `ProfileDataSource.openBanking` weight = 1.00 implies bLink is live — it is not (Phase 4 "foundation"). **No mention of the event-log model** decided 2026-05-17. |
| `docs/DESIGN_SYSTEM.md` | 2026-04-05 (partially patched 2026-05-14) | Partially current | Visual tokens, component categories, screen grammar | §1 anti-dashboard vs one-number tension formally resolved in ADR `2026-05-14-aujourdhui-doctrine.md` but the inline note in DESIGN_SYSTEM.md §1 is a passive "see ADR" pointer — **the directive text itself is not updated**. Screen categories B (Simulator) include budget as a calculator, noting it "would migrate" to category A if it becomes a tracker — that migration is exactly what the founder's vision demands (budget tracking + evolution), and the doc treats it as hypothetical. §6 ConfidenceBand mandatory rule is good. Typography spec (Supreme/Gambarino) is post-Phase-92 and current. |
| `docs/VOICE_SYSTEM.md` | 2026-04-05 | Stale 68 days | Editorial tone, microcopy patterns, audience adaption | Solid on tone pillars and DO/DON'T. Missing accents in legacy note ("premier éclairage" note carries correct accents, body text does not in several places). The "Moment produit" table has `Dossier` as "neutre, fonctionnel" — this clashes with the founder's vision of a centralised financial life through document upload, where Dossier should have a narrative, not a neutral label. No guidance on coach tool-call outputs (citation chips, confidence bands rendered in conversation). |
| `CLAUDE.md` | 2026-06-xx (live, continuously updated) | Current | Agent rules, architecture constraints, team routing, 0-trust protocol | Most current document in the corpus. Rule 4 (financial_core reuse) has well-maintained inline markers. Rule 3 (18 life events) correctly enforces anti-retraite-first framing. **Gap**: the §1 architecture section says `financial_core` = "offline-capable, bundle-size validated" but is silent on what happens when a user's stored event-log data drives recalculation (the ADR-decided model). §3 MCP tools section is accurate but the engram CLI note ("prefer MCP over CLI until env var removed") has been live for >25 days without the env var fix being tracked. |
| `.planning/decisions/2026-05-17-data-architecture-event-log-vs-bitemporal.md` | 2026-05-17 | Current | L1/L2 calc boundary, event-log model, DEK vault | Status "Decided (calc-engine portion); Proposed (event-log + coach-extractor)". The calc-engine split is the most important architectural decision since April 2026 — it is not yet reflected in ROADMAP_V2, SOT, or DESIGN_SYSTEM. The event-log portion remains "Proposed" with no downstream GSD discuss-phase opened as of 2026-06-12. **The per-user data spine — the backbone of the founder's "crucial data in DB" vision — is architecturally decided but not implemented, not tracked, and not visible in any steering doc.** |
| `.planning/decisions/2026-05-20-audit-01-bar-and-scope.md` | 2026-05-20 | Current | Beta-1 bar, archetype gating, audit scope | Good. Surfaced P0 blockers (archetype HARD GATE, semantic banned-term sweep, DSAR manifest, forced tool-invocation). These are still open as of this audit — none is referenced in ROADMAP_V2 or any milestone tracker. |
| `docs/AGENTS/swiss-brain.md` | 2026-04-xx (pivot note) | Partially current | Compliance rules, archetypes, Swiss constants | Pivot note "messaging hiérarchie à revoir avec MINT_IDENTITY.md reconciliation (deferred v2.9+)" has been deferred since April 2026. The reconciliation has never happened. |
| `docs/AGENTS/flutter.md`, `backend.md` | Not read in detail | Unknown | Agent role specs | Not audited deeply — out of scope for product-docs audit. Recommend a separate technical agent audit. |

---

## 2. Contradiction / Staleness / Gap Table (Actionable)

| ID | Type | Location A | Location B | Description | Severity |
|---|---|---|---|---|---|
| C-01 | Contradiction | `ROADMAP_V2.md` phase status "SHIPPED 100%" | `ROADMAP_V2.md` §"What is foundation/partial" | Voice AI, pgvector, agent autonome, expert tier, advanced gamification are all partial/stub — yet phase headers say "SHIPPED". Agents reading the header make wrong assumptions. | HIGH — misleads sprint planning |
| C-02 | Contradiction | `DESIGN_SYSTEM.md §1` "MINT = l'anti-dashboard" (old text) | `ADR 2026-05-14-aujourdhui-doctrine.md` director-dashboard one-number | The §1 note is a passive pointer; the §1 directive text was partially but not fully updated. An agent reading §1 without the ADR gets wrong framing. | MEDIUM — resolved in ADR but doc not clean |
| C-03 | Staleness | `SOT.md` `ProfileDataSource.openBanking weight=1.00` | Reality: bLink not live, Phase 4 "foundation" | openBanking weight implies production source; will skew confidence scores if a future agent reads SOT as authoritative for ConfidenceScore tuning. | MEDIUM |
| C-04 | Gap | All docs | Founder vision: per-user event-log as DB spine | No steering doc describes the event-log model as THE data architecture. ADR 2026-05-17 decided it but it's not in SOT, ROADMAP_V2, or CLAUDE.md §1. | HIGH — architectural invisibility |
| C-05 | Gap | All docs | Founder vision: arbitrage algorithms guiding users lifelong | `financial_core/arbitrage_engine.dart` exists (2116 LOC) but the concept of "algorithms that guide users across life events, not just simulate one scenario" is mentioned nowhere as a product principle. ROADMAP_V2 mentions "Arbitrage" only as a calculator name in S52 sprint status. | HIGH — product pillar undocumented |
| C-06 | Gap | All docs | Founder vision: generative widgets / graphs / tables rendered in conversation | Coach chat tool-call rendering (widget → conversation) exists in backend architecture (ROADMAP_V2 S56) but no doc describes the design grammar for in-chat rendered artefacts: what a widget looks like in a message, what tables are allowed, what graphs. VOICE_SYSTEM.md ignores this surface entirely. | HIGH — UX surface unspecified |
| C-07 | Gap | All docs | Founder vision: document upload as financial life centralisation | `MINT_IDENTITY.md §Zones grises` mentions doc upload as a use case but frames it defensively (« Mint extrait les faits sans juger l'emetteur »). The proactive vision — upload a LPP cert → MINT auto-updates your data spine, triggers recalculation, surfaces new arbitrage — is nowhere documented as an intended flow. | HIGH — feature intent undocumented |
| C-08 | Gap | All docs | Founder vision: budget tracking evolution (happy/unhappy events) | DESIGN_SYSTEM.md §B acknowledges budget "would migrate" to Category A if it becomes a tracker. ROADMAP_V2 has no sprint for real-time budget tracking. Yet the founder describes "budget tracking/evolution, happy/unhappy events" as a core loop. The gap between the aspirational track (daily financial pulse) and current product reality (budget simulator only) is undocumented. | HIGH — roadmap gap |
| C-09 | Staleness | `MINT_IDENTITY.md` | Current mission | Identity doc has no accents in FR body text — a document about a product that strictly enforces FR accents violates its own rule. This is symbolic but also a practical problem: agents pattern-match from this doc. | LOW — cosmetic but embarrassing |
| C-10 | Contradiction | `MINT_IDENTITY.md §Ce que MINT n'est PAS` "Un conseiller en placement (pas de recommandation personnalisée)" | Founder vision "les aiguiller financièrement" / "arbitrage algorithms guiding users" | The identity doc positions MINT as non-advisory to stay LSFin-compliant. The founder's language uses directional verbs (guider, aiguiller) that read closer to advisory. This is the central legal-product tension in the company — it must be named and resolved, not papered over. (See §5 below.) | CRITICAL — unresolved strategic tension |
| C-11 | Gap | `SOT.md` | Event-log projection model (ADR 2026-05-17) | SOT defines `SessionReport`, `EnhancedConfidence`, `ProfileDataSource` but has no objects for `FactEvent`, `ProjectionSnapshot`, `DEKVault` — the three new model classes decided in the May 2026 data architecture. | HIGH — SOT is incomplete for the decided architecture |
| C-12 | Staleness | `ROADMAP_V2.md` §NORTH STAR METRICS "5K active users by Phase 1 end" | Current reality: app not yet on TestFlight | Phase 1 completion date was meant to be ~6 months after production v1.0. The app has not reached first beta users as of June 2026. KPI table baseline "staging" is unchanged 79+ days. | MEDIUM — planning artifact stale |

---

## 3. The Missing North-Star: PRODUCT-SPINE

### Does it exist?

No. The closest approximation is the intersection of ROADMAP_V2 (phases) + MINT_IDENTITY.md (brand/legal positioning) + SOT.md (domain objects) + DESIGN_SYSTEM.md (screen grammar). These four documents are not mutually consistent, are not updated in sync, and were written at different dates by different sessions with different frame of reference. No agent can synthesise them into a single coherent product description.

### What PRODUCT-SPINE should contain

A PRODUCT-SPINE is not a roadmap and not a brand doc. It is the **definitive product description**: what MINT does, how it does it, for whom, through which technical primitives, with which invariants. It answers in one place:

- Life events × user data: which 18 events, what data is captured for each, which calculators are triggered
- User data spine: what lives in the event-log vs the profile snapshot vs the projection cache
- Calculators × arbitrage: what each L1 calculator produces, which arbitrage algorithms aggregate them, what "guidance" means technically
- Surfaces: coach conversation (text + in-chat rendered artefacts), screens (18 screen categories), Dossier (document store + extraction)
- Compliance invariants: the concrete constraints that separate "education" from "conseil" in practice (not just the abstract ban)

### Skeleton (fillable from existing docs — gaps marked)

```
# PRODUCT-SPINE — MINT

> Source of truth for the product as a complete system.
> Supersedes ROADMAP_V2.md as the product vision reference.
> ROADMAP_V2 becomes execution history (what shipped when).
> SOT.md becomes the domain object registry (data contracts).
> PRODUCT-SPINE is the answer to "what is MINT".

## 1. MISSION
"Le meilleur coach de lucidité financière dans sa poche, tout au long de sa vie."
Technically: store user's financial life → simulate → surface numbers → arbitrage
algorithms guide towards better decisions across all 18 Swiss life events.

## 2. THE 18 LIFE EVENTS
[Fillable from swiss-brain.md archetype table + ROADMAP_V2 S53 + DESIGN_SYSTEM §C]
Each event maps to: trigger signal → data captured → calculators fired → arbitrage output.
TABLE: event × data_fields × calculators × arbitrage_flags

## 3. PER-USER DATA SPINE
[Gap — ADR 2026-05-17 decided event-log + projection + DEK but implementation is "Proposed"]
a. FactEvent log: append-only. Source = (user input, OCR scan, LPP cert, future bLink)
b. CurrentState projection: denormalised, keyed on inputs_hash + constants_version_hash
c. DEK envelope: per-user encryption key, crypto-shred on GDPR erasure
d. SwissConstantsRegistry: versioned (effective_from/to), source_url, source_pdf_sha256

## 4. CALCULATORS (L1) AND ARBITRAGE ALGORITHMS (L1 aggregate)
[Partially fillable from ROADMAP_V2 §codebase + financial_core/]
11 L1 calculators: AVS, LPP, Tax, FRI, MonteCarlo, Arbitrage, Confidence,
WithdrawalSequencing, TornadoSensitivity, HousingCost, CoachReasoner.
ArbitrageEngine.dart: [GAP — no doc describes what the arbitrage algorithm optimises,
what its inputs are, what its output lifecycle means for the user]
Output: scenario (Bas/Moyen/Haut) + ConfidenceBand + EnrichmentPrompts

## 5. L2-L4 BACKEND INTELLIGENCE
[Gap — backend services described in ROADMAP_V2 S56-S68 but no product-level
description of what L2 comparison, L3 illumination, L4 invariants mean to the user]

## 6. SURFACES
### 6a. Coach Conversation
- Text: voice/tone per VOICE_SYSTEM.md
- In-chat rendered artefacts: [GAP — no spec for widget grammar in conversation]
  Needed: what is a "rendered widget" in chat? A Flutter widget? An HTML card?
  What types: number cards, simulation summaries, arbitrage comparison tables, graphs?
- Tool call chain: extractor LLM → financial_core → narrator LLM → citation gate → user
### 6b. Screens (18 categories per DESIGN_SYSTEM.md)
- Screen grammar: per DESIGN_SYSTEM §2 (Hero / Simulator / Life Event / ...)
- ConfidenceBand mandatory on all projected numbers
### 6c. Dossier (Document Upload → Financial Life Centralisation)
- Upload flow: OCR extraction → FactEvent creation → CurrentState projection refresh
  → new arbitrage surface → Coach notification
- Document types: LPP cert, AVS extract, tax declaration, salary slip, insurance policy
- [GAP — proactive data-spine update flow not documented anywhere]
### 6d. Budget Tracker (evolution tracking)
- [GAP — daily pulse / happy-unhappy event tracking not in any doc]
- Design: Category A hero screen (per DESIGN_SYSTEM §B note), real-time not simulator

## 7. COMPLIANCE INVARIANTS (what separates lucidité from conseil)
[Fillable from MINT_IDENTITY.md §Cadre de messaging + swiss-brain.md §1 + VOICE_SYSTEM §DO/DON'T]
- Never: direct recommendation ("tu devrais"), ranking ("le meilleur"), promise ("garantira")
- Always: scenario (Bas/Moyen/Haut), ConfidenceBand, editables hypotheses, disclaimer footer
- Arbitrage output framing: "voici les implications" not "voici le choix à faire"
- [Gap: the line between "algorithme d'arbitrage qui guide" (founder language) and
  "recommandation personnalisée" (LSFin art. 8 forbidden) must be explicitly drawn]

## 8. QUALITY BAR (VZ and beyond)
VZ = https://www.vermoegenszentrum.ch — Swiss financial planning reference.
"Beyond VZ" = same depth + conversational AI + proactive lifetime guidance.
[Gap: no concrete feature parity analysis against VZ has been documented]

## 9. APPENDIX — DOC REGISTRY
[Links to ROADMAP_V2 (execution history), SOT (domain contracts), DESIGN_SYSTEM, VOICE_SYSTEM, swiss-brain, IDENTITY]
```

---

## 4. Optimised Doc-Set Proposal

### Current set (10 docs + CLAUDE.md)

| Doc | Current role | Problem |
|---|---|---|
| `MINT_IDENTITY.md` | Brand/legal positioning | Stale, no accents, silent on data/arbitrage/widgets |
| `ROADMAP_V2.md` | Product phases + KPIs | Misleading "SHIPPED" statuses, stale architecture |
| `SOT.md` | Domain object contracts | Missing event-log model, bLink weight wrong |
| `DESIGN_SYSTEM.md` | Visual tokens, screen grammar | Partially patched via ADR pointer, budget tracking gap |
| `VOICE_SYSTEM.md` | Editorial tone, microcopy | Good but no in-chat widget guidance |
| `CLAUDE.md` | Agent rules (live) | Most current; event-log not in §1 architecture |
| `docs/AGENTS/swiss-brain.md` | Compliance/archetypes | Pivot reconciliation deferred since April 2026 |
| `decisions/2026-05-17-*` | L1/L2 data architecture | Decided but not propagated to steering docs |
| `decisions/2026-05-20-*` | Audit bar and scope | Current; P0 blockers not tracked in ROADMAP_V2 |
| `.planning/codebase/CONCERNS.md` | Tech debt | Stale since 2026-04-22 |

### Proposed optimised set

| Action | Doc | Rationale |
|---|---|---|
| **CREATE** | `docs/PRODUCT-SPINE.md` | North-star document the codebase lacks. Supersedes ROADMAP_V2 as vision reference. See §3 skeleton. |
| **REWRITE** | `ROADMAP_V2.md` | Rename to `docs/EXECUTION-HISTORY.md` or add large-print header: "This is the execution log. Product vision is in PRODUCT-SPINE.md." Purge misleading "SHIPPED" phase headers. Convert §codebase state to a diff-against-PRODUCT-SPINE view. |
| **UPDATE** | `SOT.md` | Add FactEvent, ProjectionSnapshot, DEKVault objects from ADR 2026-05-17. Fix bLink weight note to "planned, not live". Mark SessionReport gaps as explicit TODO tickets not just inline notes. |
| **UPDATE** | `DESIGN_SYSTEM.md §1` | Remove the passive ADR pointer; rewrite §1 text directly to "anti-cockpit-d-avion, one-number hero" doctrine. Add §6b stub: "In-chat rendered artefacts — grammar TBD in PRODUCT-SPINE §6a." |
| **UPDATE** | `MINT_IDENTITY.md` | Fix all missing accents in body text. Add §Arbitrage to "Ce que MINT est": "Un moteur d'arbitrage qui rend visibles les implications de chaque choix de vie." Update taglines to include "lucidité financière tout au long de la vie." |
| **UPDATE** | `docs/AGENTS/swiss-brain.md` | Do the deferred messaging reconciliation with MINT_IDENTITY.md. Close the "deferred v2.9+" note. |
| **KEEP** | `VOICE_SYSTEM.md` | Good as-is. Add one section: "In-chat artefact voice: numbers in rendered widgets follow the same ConfidenceBand + no-bare-number rule. Widget text uses bodySupreme15Regular, not editorial copy." |
| **KEEP** | `CLAUDE.md` | Already live. Add §1 architecture note: "per-user data spine = event-log + CurrentState projection (ADR 2026-05-17); recalculation chain starts from FactEvent, not raw Profile." |
| **UPDATE** | `.planning/codebase/CONCERNS.md` | Restamp with 2026-06-12 date. Add the 4 P0 blockers from ADR 2026-05-20. Flag god-files as pre-beta-1 tech debt. |
| **KILL/ARCHIVE** | `ROADMAP_V2.md §AUTORESEARCH AGENT DEPLOYMENT SCHEDULE` | This schedule describes nightly agents that were aspirational infrastructure. It never ran as described. Archive to `_archive/` to avoid misleading future planning agents. |

### Maintenance contract (leveraging CLAUDE.md §8 wiki conventions)

The wiki conventions already exist and work. The problem is not process — it is that four docs have been written asynchronously with no common update trigger. The fix is a **co-update rule**:

> When any of (PRODUCT-SPINE, SOT, ROADMAP_V2/EXECUTION-HISTORY, CLAUDE.md §1 architecture) changes, the other three MUST be updated in the same PR or the PR is blocked by `wiki_lint.py`.

Specifically add to `tools/checks/wiki_lint.py`:
- Rule: if `SOT.md` is modified, check that `docs/PRODUCT-SPINE.md §3` (data spine section) has a `last_synced` date ≥ SOT modification date.
- Rule: if a new `decisions/*.md` with `status: Decided` is created, check that at least one steering doc (PRODUCT-SPINE, SOT, CLAUDE.md, DESIGN_SYSTEM, VOICE_SYSTEM) has been touched in the same PR.

This is cheap to implement (2 Python rules on top of existing lint) and mechanically prevents the "decision decided but never propagated" pattern that has created C-04, C-05, C-06, C-07, C-08, C-11 in the current corpus.

---

## 5. Founder Challenge — Tensions That Must Be Resolved

These are not documentation problems. They are strategic contradictions between the founder's stated vision and existing commitments. Documenting them honestly is more useful than a smooth narrative.

### Tension 1 (CRITICAL): "Guider / aiguiller" vs LSFin no-recommendation

**Founder language**: "arbitrage algorithms guiding users lifelong", "les aiguiller financièrement", "le meilleur coach de lucidité financière".

**Existing commitment**: `MINT_IDENTITY.md §Ce que MINT n'est PAS` — "Un conseiller en placement (pas de recommandation personnalisée sur des instruments)". LSFin art. 8 is real: presenting an investment as suitable for a specific person = regulated advice.

**The tension**: "guider" in Swiss financial law is a spectrum. Showing a user that their LPP rachats would save 8'400 CHF/yr in taxes (factual calculation) is education. Telling them "you should do this rachat before year-end" (directional instruction) is advice. The current compliance architecture draws the line through banned-terms and the "no direct recommendation" rule. The arbitrage engine outputs scenarios, not instructions. 

**What is NOT resolved**: the founder's lifelong-guidance ambition implies MINT will eventually say "act now". The in-chat citation-gate + forced-tool-invocation pattern (Phase 94) gets MINT very close to that line on numerical claims. As MINT gets smarter at arbitrage, the product pressure to say "do this" will intensify. The documentation never addresses what the compliance ceiling is for arbitrage output language — just the floor (banned terms). That ceiling must be explicitly documented in PRODUCT-SPINE §7.

**Proposed resolution**: PRODUCT-SPINE §7 should define three output tiers:
- Tier 1 (always allowed): factual extraction from user documents
- Tier 2 (always allowed): scenario calculation with editables + ConfidenceBand
- Tier 3 (requires explicit LSFin review per case): prioritised action sequence ("sur la base de tes chiffres, voici l'ordre d'actions le plus favorable" — this is the frontier)

### Tension 2 (HIGH): Lifelong coach vs 0-TRUST "never claim works"

**Founder ambition**: "tout au long de sa vie" — a product that compounds knowledge of the user over years, surfaces better guidance as their situation evolves.

**Current reality**: ConversationMemoryService is not semantic cross-session recall. The vector store is not activated in production. The event-log architecture is "Proposed". The coach has no memory of what it told a user 6 months ago.

**The tension**: The marketing positioning ("lifelong coach") is ahead of the architecture by 12-18 months. No document names this gap explicitly. ROADMAP_V2 implies memory is "shipped" (S58 `shipped` status); the Notes column admits "Vector store memory not yet implemented."

**Proposed resolution**: PRODUCT-SPINE §3 should explicitly date-stamp which memory tier is live and which is planned. A beta user should not be told MINT "remembers everything" when it currently has keyword-based session history only.

### Tension 3 (MEDIUM): VZ quality bar vs service-layer facade pattern

**Founder ambition**: "qualité VZ et au-delà" — the gold standard for Swiss financial planning.

**Existing codebase reality**: CONCERNS.md documents 20+ files that bypass the financial_core barrel (ADR violation). `SessionReport` is missing 5 fields documented in SOT as "NOT YET IMPLEMENTED". The Expert Tier has no real advisors. Voice AI is stub-only.

**The tension**: the product is far from VZ quality on the advisor-level features (expert tier, voice, semantic memory). It may be at or near VZ quality on depth of Swiss-specific calculation (26 cantons, 8 archetypes, 11 calculators, citation gate). The doc corpus never makes this distinction — it implies uniform quality. 

**Proposed resolution**: PRODUCT-SPINE §8 should contain a concrete VZ parity matrix: feature X vs VZ capability vs MINT status. This forces honest assessment and prevents agents from assuming parity that does not exist.

### Tension 4 (MEDIUM): Document upload as centralisation vs read-only posture

**Founder ambition**: documents as the spine of the user's financial life (LPP certs, tax declarations, insurance policies all living in MINT).

**Current posture**: MINT is "read-only" (no money movement, no product sales, no data to third parties). Document upload fits the read-only posture technically. But storing long-term financial documents creates a different compliance surface: data residency (nLPD), retention policy, DSAR export, deletion cascade. 

**The tension**: the Dossier tab stores documents today. The audit P0-3 (ADR 2026-05-20) flagged `DSAR fact_event manifest fix (privacy.py:327-352)` as a P0 blocker because `coach_insights` are not in the export manifest. If document storage grows (user uploads 5 years of LPP certs, tax returns, salary slips), the DSAR/deletion surface grows materially. 

**Proposed resolution**: PRODUCT-SPINE §6c (Dossier section) must document the data lifecycle for uploaded documents: retention period, DSAR export schema, deletion cascade, encryption tier (DEK). This is not currently in any doc.

---

## 6. Immediate Actions (Priority Order)

| Priority | Action | Owner | Effort |
|---|---|---|---|
| P0 | Draft PRODUCT-SPINE.md §1-4 (Mission, 18 events, Data spine, Calculators) using the skeleton in §3 above | docs-architect or Julien | M |
| P0 | Update `CLAUDE.md §1` architecture section: add event-log model reference, remove misleading "offline-capable" implication for L2-L4 | Claude agent | S |
| P0 | Update `SOT.md`: add FactEvent, ProjectionSnapshot, DEKVault; fix bLink weight note | Claude agent | S |
| P1 | Rewrite `ROADMAP_V2.md` phase headers: replace "SHIPPED 100%" with accurate status table matching the §foundation/partial text; add header "This is execution history, not vision" | Claude agent | M |
| P1 | Fix `MINT_IDENTITY.md`: restore all FR accents, add §Arbitrage to "Ce que MINT est" | Claude agent | S |
| P1 | Update `DESIGN_SYSTEM.md §1`: rewrite directive text (remove passive ADR pointer) | Claude agent | S |
| P2 | Add co-update rule to `wiki_lint.py`: new `status: Decided` ADR must touch a steering doc in same PR | Claude agent | S |
| P2 | Draft PRODUCT-SPINE §5-8 (L2-L4 intelligence, Surfaces, Compliance ceiling, VZ parity matrix) | Requires Julien input on §7 compliance ceiling | L |
| P2 | Close swiss-brain.md deferred pivot reconciliation | Claude agent | M |
| P3 | Restamp `CONCERNS.md` with 2026-06-12, add P0 blockers from ADR 2026-05-20 | Claude agent | S |

---

*Doc generated by docs-architect subagent, 2026-06-12. Read-only audit — no code changed.*
*Counter-arguments mandatory per CLAUDE.md §8: see §5 above.*
*Co-update maintenance contract leverages existing wiki_lint.py per CLAUDE.md §8 "Maintenance contract" — not reinvented.*
