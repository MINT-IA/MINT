---
date: 2026-05-17
status: Decided (calc-engine portion) ; Proposed (event-log + coach-extractor)
authors: Julien Battaglia (PM) + Claude (panel orchestration)
panel: 5-pers (architect-review, database-architect, ai-engineer, security-auditor, backend-architect — wshobson + VoltAgent adversarial)
supersedes: .planning/decisions/2026-05-06-personal-financial-wiki-v3-candidate.md
superseded_by: —
description: 5-agent adversarial panel converges on event-log + projection + per-user DEK envelope; rejects Snodgrass SCD2 bitemporal and Karpathy coach-memory wiki
related:
  - .planning/decisions/2026-08-03-doctrine-reconstruction-mint.md
  - docs/AGENTS/backend.md
  - docs/AGENTS/swiss-brain.md
  - apps/mobile/lib/services/financial_core/
  - services/backend/app/services/regulatory/registry.py
  - services/backend/app/models/coach_insight.py
  - services/backend/app/models/snapshot.py
  - services/backend/app/services/cache/
  - services/backend/app/services/dek_vault.py
---

# Data architecture: event-log + projection + DEK envelope (panel-converged shape)

## TLDR

A 5-agent adversarial panel converged on a single data-layer shape for MINT user-facts: append-only event log + denormalised current-state projection + per-user DEK crypto-shred envelope. Snodgrass SCD2 bitemporal rejected. Karpathy-style coach-memory wiki rejected in favour of structured rows with extraction-time guardrails. Status `Proposed` until a downstream GSD discuss-phase resolves the prerequisite mobile-vs-backend calc-engine ownership question.

## Context

### What triggered this

Julien asked Claude to read [Karpathy's LLM Wiki gist](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f) (2026-05-17) and analyse where the pattern would and would not fit MINT — both for the user-facing application and for the agent debugging infrastructure (`.planning/`). The discussion narrowed to a candidate split of the application data layer into three or four patterns. Rather than commit to that split, Julien chose to run an adversarial expert panel (per memory `feedback_expert_panel_pattern`) before handing the verdict to a GSD discuss-phase for implementation planning.

### Initial proposal challenged by the panel

The orchestrator (Claude) proposed a 3-pattern split, with a 4th optional:

- **Pattern A — Versioned constants registry** for Swiss legal values (rente AVS minimum, plafond 3a, LIFD capital-withdrawal rates) with `effective_from / effective_to / source_url / source_pdf_sha256`. Described as "50% done" via the existing `get_swiss_constants()` MCP tool.
- **Pattern B — Bitemporal user-facts DB** in the Snodgrass / SCD type 2 style: `{user_id, fact_type, value, source_type, source_id, observed_at, valid_from, valid_to, superseded_by, confidence}`. Designed for PDF upload + future bank API + future LPP API as streaming fact sources.
- **Pattern C — Projections recomputed on-demand** via `financial_core/`, never stored. Cache keyed on `hash(profile + constants_version)`.
- **Pattern D (optional) — Per-user coach-memory wiki** in the Karpathy style: scoped narrow, subjective, non-user-visible, output still routed through banned-terms + financial_core.

### Panel composition (adversarial)

Five specialist agents spawned in parallel with explicit instruction to *try to break* the proposal, not validate it; ≤ 400 words each; no writes; WebSearch allowed for external benchmarking:

| Agent | Angle |
|---|---|
| `architect-review` (wshobson) | Service boundaries, anti-facade, `financial_core` integration |
| `database-architect` (wshobson) | Bitemporal schema, alternatives, multi-tenant scale, query patterns |
| `ai-engineer` (wshobson) | Coach wiki design, LLM grounding, hallucination / self-poisoning prevention |
| `security-auditor` (wshobson) | LSFin compliance, Swiss data-protection law (nLPD), multi-tenant isolation |
| `backend-architect` (wshobson) | API contracts, financial_core integration, Pydantic v2 + camelCase, service boundaries |

### Findings that shifted the diagnosis

1. **The 3-pattern split sidestepped a load-bearing upstream conflict.** [CLAUDE.md triplet #3](../../CLAUDE.md) declares `apps/mobile/lib/services/financial_core/` the source of truth; `docs/AGENTS/backend.md:39` declares the backend the source of truth. Both ship today (~10 279 LOC of mobile calculators + 76 backend services + an auto-generated `_registry.py` acting as bridge). No data architecture can be defined cleanly until calc-engine ownership is resolved.
2. **Pattern A misclassified as "50% done".** Backend [`regulatory/registry.py`](../../services/backend/app/services/regulatory/registry.py) has `effective_from/to` and active-version selection (~80% done). But the mobile side still has `static const double` constants in [`lpp_calculator.dart`](../../apps/mobile/lib/services/financial_core/lpp_calculator.dart) (e.g. `safeWithdrawalRate = 0.04`, `survivorSpouseRate = 0.60`). There is no sync mechanism — mobile is 0% done. The real gap is "kill hardcoded mobile constants", not "harden the backend registry".
3. **Pattern D already ships, with a compliance gap.** [`CoachInsightRecord`](../../services/backend/app/models/coach_insight.py) is live with `insight_type="concern"` rows (e.g. "a des dettes/emprunts") written automatically by the coach's `save_insight` tool. `CONSENT_CATEGORIES` in `privacy_service.py` has no corresponding entry, `export_user_data()` does not export coach insights, and the deletion path is unclear. This is a compliance gap to fix immediately on a hot-fix branch — independent of any architecture decision.
4. **Pattern C lacks an advice audit trail.** [`SnapshotModel`](../../services/backend/app/models/snapshot.py) stores projection outputs but carries no `constants_version_hash`. The regulatory snapshot used at projection time cannot be reconstructed from persisted data. LSFin documentation requirements are not currently satisfied for stored projections.
5. **Three of five agents independently converged on the same target shape** (event log + denormalised projection + per-user DEK envelope), via different reasoning paths: `architect-review` from anti-facade and service boundaries; `database-architect` from query latency and crypto-shred opacity; `security-auditor` from existing `DEKVault` infrastructure and erasure compliance. Cross-route convergence is strong signal.

## Decision (Decided 2026-05-17 — calc-engine portion ; event-log + coach-extractor remain Proposed)

### Target data-layer shape

Three tables, one unified schema:

```
fact_event (append-only event log)
  - event_id (PK)
  - subject_type ('regulatory' | 'user')
  - subject_id
  - fact_type
  - value_enc (JSONB; ciphertext when subject_type='user')
  - source_type ('pdf' | 'bank_api' | 'lpp_api' | 'user_input' | 'coach_inference' | 'legal_pdf')
  - source_id
  - source_pdf_sha256
  - observed_at
  - recorded_at
  - confidence (EnhancedConfidence 4-axis, JSONB)
  - supersedes_event_id (FK, nullable)
  - correction_reason
  - visibility ('user_visible' | 'internal')
  - archetype_tags (JSONB, for 8-archetype routing)
  Hash-partitioned by subject_id (16-32 partitions); analytics queries respect partition pruning.

fact_current (denormalised projection)
  - subject_type, subject_id, fact_type (PK composite)
  - value_enc
  - latest_event_id (FK)
  - confidence
  - visibility
  Rebuilt from fact_event via trigger or async projector. Sub-1ms point reads via PK index.

user_dek (per-user crypto-shred envelope)
  - user_id (PK)
  - dek_ciphertext (KMS-wrapped data-encryption key)
  - status ('active' | 'shredded')
  - created_at
  - shredded_at
  Erasure = NULL the dek_ciphertext. All downstream value_enc rows become permanently opaque.
```

The original four patterns collapse as follows:
- Pattern A (constants) = `fact_event` rows with `subject_type='regulatory'`, `source_type='legal_pdf'`. No encryption (constants are public).
- Pattern B (user facts) = `fact_event` rows with `subject_type='user'`, encrypted via the user's DEK envelope.
- Pattern C (projections) = a materialised view of `fact_current` keyed on `inputs_hash`, invalidated by trigger when `fact_current` rows of `subject_type='regulatory'` change. Recompute on cache miss via the resolved calc engine.
- Pattern D (coach memory) = `fact_event` rows with `source_type='coach_inference'`, `visibility='internal'`. No separate wiki.

### Coach inference pathway (rejects Karpathy wiki)

The coach LLM does **not** write its own observation rows. A separate post-turn extractor LLM (different model parameters, schema-constrained, low temperature) proposes `coach_inference` rows from session transcripts. Each proposed row requires:

- **Evidence quote** — a verbatim user utterance from the transcript that grounds the inference. No quote → row rejected at extraction time. Matches Anthropic's recommended grounding pattern for hallucination reduction.
- **Interpretive-vocabulary banlist** enforced at extraction time. Extends the LSFin banned-terms lint to coach-internal notes: words like *fragile*, *anxieux*, *irrationnel* are blocked from coach-written rows even though they are LSFin-clean in user-facing output.
- **Decay policy** — TTL based on session count or prompt-version major bump. When the coach prompt evolves, older inferences expire and must be re-derived under the current voice. Prevents prompt-version drift from contaminating new reasoning.
- **User-visible review surface** — users can list, inspect, and delete coach inferences about themselves. Satisfies Swiss data-protection law right-of-access and right-of-rectification, and disincentivises low-quality inferences (the user sees them).

This split (coach reads, separate extractor writes) is designed to prevent the self-poisoning loop documented in [MemoryGraft (arXiv:2512.16962)](https://arxiv.org/html/2512.16962v1), which empirically demonstrates ~50% retrieval contamination from a small number of poisoned entries in agentic LLM memory systems.

### Audit trail for advice documentation

A separate append-only table for LSFin documentation:

```
projection_audit_record
  - record_id (PK)
  - user_id_hash (SHA-256, not plaintext — keeps audit retention independent of user erasure)
  - computed_at
  - constants_version_hash (SHA-256 of active regulatory subject_type rows at compute time)
  - scenario_inputs_hash (SHA-256 of user facts used)
  - output_hash (SHA-256 of projection output)
  - lsfin_disclaimer_shown (bool)
  Postgres-enforced REVOKE UPDATE, DELETE ON projection_audit_record FROM app_role.
```

Every projection output stores `constants_version_hash` alongside its `scenario_inputs_hash`. Constants updates (rare, government-driven) trigger materialised-view invalidation; existing projections are not re-disclosed unless a banned-terms doctrine guarantee was specifically made (which the existing LSFin lint already prevents).

### Calc-engine integration (deferred to GSD discuss-phase 1)

<!-- mint-data-architecture-v1-01-canonical:start -->
**RESOLVED 2026-05-17** by Phase `mint-data-architecture-v1-01-calc-engine-canonical`. See the phase CONTEXT.md for the 16 D-XX decisions : split-with-arbiter L1 mobile-canonical + L2-L4 backend-canonical, `services/backend/app/models/lucidity/_payload.py` as discriminator boundary, D-CE-09 strangler-fig migration sequence (Monte Carlo + tornado sensitivity migrate FIRST per D-11), and codegen-based regulatory-constants sync (D-08, D-15, D-16). Plan 02 of that phase landed the doctrine PR carrying this status flip atomically — the D-04 atomicity gate at `tools/checks/doctrine_atomicity_gate.py` enforces that the 6 doctrine files (CLAUDE.md + docs/AGENTS/{backend,flutter}.md + 2 SKILL.md + this ADR) co-modify in the same diff range. The shape above is REFINED : the ADR's original « backend-canonical full-stack » assumption becomes « L2-L4 backend-canonical, L1 mobile-canonical », with mobile owning offline L1 chiffrer via codegen-baked constants snapshot.

**Operational extension 2026-05-27** : the same 6-file doctrine set now also records guarded `staging` push authority. Agents may push to `staging` only via CLAUDE.md §4.1: clean worktree, fetch/divergence check, cited source verification, normal merge or fast-forward, and plain `git push origin staging`; never force-push or rewrite `staging`, `dev`, or `main`. If branch protection rejects direct push, use a PR into `staging`.

**Operational extension 2026-06-24** : the same 6-file doctrine set now also
records the Mint-specific operating roster and skill authority. Default routing
uses `mint-lead`, `mint-quality-gate`, `mint-mobile`, `mint-backend`, and
`mint-swiss-brain`; no vendor agent catalog is checked in. External specialists
require an explicit named gap. Canonical cross-tool skills live in
`.agents/skills/mint-*`; `.claude/skills` entries are compatibility mirrors
whose doctrine blocks are restored by `tools/checks/create_or_update_mint_skills.py`.
<!-- mint-data-architecture-v1-01-canonical:end -->

The shape above assumes a **backend-canonical** calc engine: `financial_core/` calculators live in backend services; mobile becomes a thin renderer that fetches projections via versioned REST. The mobile-canonical alternative (delete backend calc layer, mobile owns calculators, backend syncs facts) is viable but requires a different sync target architecture. **This decision is upstream of every detail above and must be resolved first.**

## Counter-arguments and data gaps

### What does the strongest opposing view say?

Steel-man for keeping Snodgrass SCD2 over event-log + projection:

> *"Event-log + projection is two systems to keep in sync; one canonical bitemporal table is operationally simpler. SCD2 is well-understood, every ORM has support, audit trail is trivially the same table. Adding a projection layer and a crypto-shred envelope introduces three failure modes (event-log corruption, projection drift, DEK loss) where SCD2 has one. For MINT's scale (N users, not millions), SCD2 query latency holds and the GiST tstzrange indexing pays for itself. The panel's fintech benchmark (no consumer fintech publicly runs Snodgrass for user profile) is selection bias — fintechs that do use bitemporal don't blog about it. Karpathy-style coach wiki is rejected too quickly: a small per-user wiki with evidence-quote requirement and TTL would give richer coach personalisation than a SCD-rows-with-tags model, and the self-poisoning risk is overstated for one-user-one-wiki scopes."*

This argument carries weight. The dominant mitigation is that effective erasure is not optional under Swiss data-protection law — and once value columns become opaque ciphertext to satisfy erasure, SCD2's predicate-query advantage evaporates and a separate decrypted projection becomes necessary anyway. The end state is event-log + projection + DEK envelope either way; the question is whether to design for it now or after 18 months of iteration pain.

Steel-man for keeping a Karpathy-style coach wiki:

> *"The extractor-LLM-writes pattern is itself an LLM in the loop; calling it 'not self-poisoning' is sleight of hand. The real protection is the evidence-quote requirement plus user-visible review — both of which work equally well in a wiki schema. A markdown wiki is human-inspectable, version-controllable via git, and naturally supports the cross-references that Karpathy emphasises as the source of compounding value. Collapsing coach memory into structured rows loses the narrative density that justifies the pattern."*

This argument is partly addressed by the user-visible review surface (which makes structured rows just as human-inspectable as a wiki); it is not addressed by anything except the empirical observation that no production fintech runs wiki-style coach memory, and cross-references at N=1 are degenerate.

### What does this source not address?

- **No latency benchmarks on realistic MINT load.** Panel estimates are heuristic (`fact_current` PK reads "sub-1ms", history scans "die at 10M rows"). Quantification required before commitment.
- **Migration cost from current schema** (`SnapshotModel` + `CoachInsightRecord` + `RegulatoryParameter`) to the new shape is not estimated. Deferred to GSD discuss-phase 2.
- **KMS provider choice** (Railway-native vs. AWS KMS via integration vs. self-hosted Vault) is open. Operational and cost implications not analysed.
- **Mobile vs. backend calc-engine ownership** is the upstream decision. The ADR assumes backend-canonical; the inverse path is not specified.
- **Operational cost of a separate decrypted projection** for analytics (under consent-bound time-windowed key release) is not modelled.
- **Partial DEK shred** (user requests erasure of specific fact categories rather than full account closure) is not modelled. Swiss data-protection law permits granular erasure; the proposed envelope is all-or-nothing per user.
- **Constants change propagation policy** — when the government updates `plafond_3a`, should historical projections be re-flagged to the user, or treated as point-in-time advice? Policy not decided.
- **Failure mode coverage**: projector lag, event-log corruption recovery, DEK rotation, audit-record reconciliation drift are all unspecified.
- **The Karpathy gist itself does not enumerate "practices 1–6"** as numbered items. [CLAUDE.md §8](../../CLAUDE.md) and the `_TEMPLATE.md` reference "Karpathy Wiki Pattern practice 3" — this numbering is the MINT team's interpretation, not a direct citation. Worth surfacing because it indicates our internal mental model is slightly de-anchored from source.

### What would change this conclusion?

- **GSD discuss-phase 1 decides calc engine = mobile-canonical.** The data layer then moves toward client-side SQLite + cloud sync; backend collapses to a sync target. The ADR shape above assumes backend-canonical and would need substantial revision.
- **Realistic load benchmark shows `fact_current` PK reads p99 > 50 ms.** Indexing or partitioning strategy must be re-designed (possibly Citus, possibly per-tenant schemas).
- **Postgres releases first-class envelope-encrypted temporal tables** (currently theoretical). The event-log + projection split may collapse to a single table with native temporal + envelope semantics.
- **FINMA publishes guidance** that hashed `user_id` in audit logs is insufficient (currently allowed in interpretation). `projection_audit_record` PK design needs revision.
- **mint-calc-engine-v1 Stage 3 Maestro UAT surfaces a finding** that materially contradicts panel assumptions about how calculators are actually consumed (e.g. the mobile path is never hit in practice, or vice versa). Re-open panel before proceeding.
- **Cleo or another consumer fintech publishes a post-mortem** of a Karpathy-style coach-memory wiki running in production. Strong signal to revisit Pattern D rejection.

## Sources

- [Karpathy LLM Wiki gist](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f) — fetched 2026-05-17, primary stimulus for the discussion.
- Panel agent outputs (this conversation, 2026-05-17):
  - `architect-review` — challenged 3-pattern split, recommended unified `facts` table.
  - `database-architect` — recommended event-log + projection + DEK envelope; verdict retrieved via `SendMessage` retry after initial run wrote only a title-stub to engram obs #150 (panel-contract failure flagged separately).
  - `ai-engineer` — rejected wiki for coach memory; cited MemoryGraft self-poisoning evidence; benchmarked Cleo, Moneyguide, RightCapital.
  - `security-auditor` — surfaced LSFin advice-audit gap and Swiss data-protection consent gap on coach insights; verified DEKVault crypto-shred mechanism already implemented.
  - `backend-architect` — surfaced mobile-vs-backend calc-engine ownership conflict; recommended collapse to one calc home.
- [Cleo — Memory as a step toward more human AI](https://web.meetcleo.com/blog/memory-as-a-step-toward-more-human-ai) — Cleo uses RAG + semantic insights, not a wiki.
- [Cleo — Building a financial agent on top of commodified LLMs](https://web.meetcleo.com/blog/building-a-financial-agent-on-top-of-commodified-llms)
- [MemoryGraft — persistent memory poisoning in LLM agents (arXiv:2512.16962)](https://arxiv.org/html/2512.16962v1)
- [SSGM — governing evolving memory in LLM agents (arXiv:2603.11768)](https://arxiv.org/html/2603.11768v1)
- [Martin Fowler — Bitemporal History](https://martinfowler.com/articles/bitemporal-history.html)
- [Tiger Data — Handling billions of rows in PostgreSQL](https://www.tigerdata.com/blog/handling-billions-of-rows-in-postgresql)
- [Conduktor — GDPR + Kafka erasure](https://www.conduktor.io/blog/gdpr-kafka-right-to-erasure)
- [Icon Solutions — CQRS in Financial Services](https://iconsolutions.com/blog/cqrs-event-sourcing)
- [SecuPi — counter-argument on crypto-shredding limits](https://secupi.com/crypto-shredding-is-not-nirvana-for-right-of-erasure-or-rtbf-compliance/)
- MINT codebase grounding (2026-05-17 panel reads):
  - [services/backend/app/services/regulatory/registry.py](../../services/backend/app/services/regulatory/registry.py) — `RegulatoryParameter` with `effective_from/to`, active selection.
  - [apps/mobile/lib/services/financial_core/lpp_calculator.dart](../../apps/mobile/lib/services/financial_core/lpp_calculator.dart) — `static const` constants drift surface.
  - [services/backend/app/models/coach_insight.py](../../services/backend/app/models/coach_insight.py) — `CoachInsightRecord` with `insight_type="concern"`.
  - [services/backend/app/models/snapshot.py](../../services/backend/app/models/snapshot.py) — no `constants_version_hash`.
  - [services/backend/app/services/cache/](../../services/backend/app/services/cache/) — existing `superseded_by` chain + `inputs_hash` keying.
  - [services/backend/app/services/dek_vault.py](../../services/backend/app/services/dek_vault.py) — crypto-shred mechanism implemented.
- Related ADRs:
  - [.planning/decisions/2026-05-06-personal-financial-wiki-v3-candidate.md](2026-05-06-personal-financial-wiki-v3-candidate.md) — this ADR supersedes the wiki framing for user profile data; coach-internal memory framing also revised.

## Status & follow-up

### Implementation tracking

- **Phase 0 (hot-fix, separate from GSD)** — branch `hotfix/compliance-2026-05-17` addresses the immediate compliance gaps surfaced by `security-auditor`: `coach_insights` consent + export + delete paths; `SnapshotModel.constants_version_hash` + `projection_audit_record` table; DEK shred at `delete_user_data()` invocation; `AuditEventModel.user_id_hash`. **Merge gated on `mint-calc-engine-v1` Stage 3 close** to avoid race conditions on `SnapshotModel` during Maestro UAT.
- **Phase 1 (GSD discuss-phase, pending)** — calc-engine canonical (mobile vs backend). Required prerequisite to Phase 2.
- **Phase 2 (GSD discuss-phase, depends Phase 1)** — event-log + projection schema migration from `SnapshotModel` + `CoachInsightRecord` + `RegulatoryParameter`.
- **Phase 3 (GSD discuss-phase, depends Phase 2)** — coach-extractor LLM + guardrails (banlist, TTL, evidence quote, user-visible review surface).

### 2026-05-17 — Calc-engine portion Decided

Phase `mint-data-architecture-v1-01-calc-engine-canonical` resolved the prerequisite calc-engine ownership question (16 D-XX decisions locked in CONTEXT.md ; doctrine rewrite + ADR flip landed atomically in Plan 02 — see `.planning/phases/mint-data-architecture-v1-01-calc-engine-canonical/01-02-SUMMARY.md`). Refined verdict : split-with-arbiter (L1 mobile-canonical / L2-L4 backend-canonical) with `lucidity._payload` discriminator as boundary, D-CE-09 strangler-fig migration (Monte Carlo first per D-11), build-time Dart codegen for regulatory constants (D-08, D-16). The event-log + projection schema migration (originally framed as Phase 2 above) AND the coach-extractor LLM guardrails (Phase 3) remain **Proposed** ; they will be discussed in their own GSD phases gated on this phase's ship.

### Re-litigation triggers

- GSD discuss-phase 1 decides calc engine = mobile-canonical (full ADR revision required).
- Realistic load benchmark shows `fact_current` PK reads p99 > 50 ms.
- Postgres releases native envelope-encrypted temporal tables.
- FINMA publishes new guidance on audit-log PII requirements.
- `mint-calc-engine-v1` Stage 3 Maestro UAT surfaces a finding materially contradicting panel assumptions.
- A consumer fintech publishes a production post-mortem of Karpathy-style coach-memory wiki.

### Panel-contract finding (out-of-scope but flagged)

The `database-architect` agent's initial run wrote only a title-stub to engram obs #150 (no reasoning, no risks, no alternative) and returned a save receipt as its terminal output. The wshobson agent body template appears to auto-`mem_save` at end in a way that consumes the terminal-output slot. Mitigation in future panel runs: instruct agents to return verdict prose as their final text and treat `mem_save` as side-channel. Possible template fix worth filing as its own ADR or contract update.

### Addendum 2026-07-24 — volet fiscal du calc-engine complété (statut : constat)

Le domaine fiscal L2 est backend-canonique en pratique : modèles v2
revenu/capital/rente calibrés sur l'API ESTV (130 points — revenu : PR
#988 ; capital : PRs #990/#991 ; proxys restants : #995 ; comparaison
cantonale : #997 ; provenance du registre : #994), dernier consommateur
du modèle v1
(`EFFECTIVE_RATES_100K_SINGLE`) supprimé, parités croisées gelées par
fixtures partagées (`tools/fixtures/`). Reste hors périmètre : copie privée
`_INCOME_ADJUSTMENT` de couple_optimizer (beads MINT_nosync-5up).

### Addendum 2026-08-03 — roster agents élargi (statut : constat)

Roster permanent élargi selon le handoff 2026-08-03 §11.2/§11.4 :
`mint-experience` (journey, architecture d'information, microcopy
pédagogique, accessibilité, critères de compréhension) et
`mint-integrations-security` (consentement, provenance, connecteurs
externes, sécurité, récupération) rejoignent les 5 agents existants sous
`.claude/agents/`. Doctrine canonique de référence :
`.planning/decisions/2026-08-03-doctrine-reconstruction-mint.md`. Rappel
transversal : sortie d'agent = finding, jamais vérité — reproduction
mécanique exigée avant toute promotion.
