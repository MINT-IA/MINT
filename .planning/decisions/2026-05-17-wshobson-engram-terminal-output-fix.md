---
date: 2026-05-17
status: Proposed
authors: Julien Battaglia (PM) + Claude (executor)
panel: solo (postmortem-driven, no panel run)
supersedes: —
superseded_by: —
description: Wshobson + VoltAgent agent body template inverted to prose-first / mem_save-second to fix 2026-05-17 panel verdict-loss bug before next adversarial panel spawns
related:
  - .claude/agents/
  - .planning/decisions/2026-05-17-data-architecture-event-log-vs-bitemporal.md
  - docs/AGENTS/VIBE-CODING-INFRA.md
---

# Wshobson + VoltAgent engram contract: prose-first, mem_save second

## TLDR

Patches the engram contract block prepended to 56 wshobson + VoltAgent agent files in `.claude/agents/` so the agent's terminal text output to the orchestrator carries the verdict prose first, with `mem_save` as a side-channel afterwards. Closes a systemic bug observed on 2026-05-17 where `database-architect` returned only a save receipt during the data-architecture panel, losing its verdict to the session.

## Context

On 2026-05-17, an adversarial 5-agent panel was spawned to challenge a data-architecture proposal (the panel that produced ADR [`2026-05-17-data-architecture-event-log-vs-bitemporal.md`](2026-05-17-data-architecture-event-log-vs-bitemporal.md)). Four of five agents returned their verdict as the orchestrator-readable terminal output; `database-architect` returned `"Saved as obs_id 150 / sync_id obs-75b231310387bea8 under topic_key 'data-architecture:user-facts:schema-pattern'..."` as its final message. The actual verdict prose (recommendation, top-3 risks, concrete alternative, fintech benchmark) was never materialised in any channel the orchestrator could read.

Investigation showed:
1. Engram obs #150 contained only a one-line decision title (`"User-facts layer: prefer event-log+projection+crypto-shred over Snodgrass bitemporal"`), no body prose.
2. The agent body template instructed `mem_save` "after each non-trivial finding" without specifying that the orchestrator only sees the LAST text block.
3. Recovery via `SendMessage` to the same agent worked (the agent re-emitted the verdict when asked explicitly) — costing a round-trip and proving the bug is in the contract wording, not the agent's capability.

The bug is dormant until the next adversarial panel spawns. The next such panel is the GSD discuss-phase « calc engine canonical » (Phase 1, depends on `mint-calc-engine-v1` Stage 3 close). This ADR ships the contract fix **before** that panel.

The fix was queued in [memory `project_wshobson_engram_contract_fix_queued`](../../) on the day of the bug (2026-05-17), trigger window « juste avant engine-v1 close ». Engine-v1 closed today; the queued fix is now applied.

## Decision (Proposed)

Replace the `## Persistent memory (engram MCP)` block prepended to all 56 wshobson + VoltAgent agent files in `.claude/agents/` with an inverted-ordering version. Four substantive changes:

1. **Output contract (new section)** — terminal output IS the prose verdict; `mem_save` is side-channel. The orchestrator only sees the last text block — if that block is a save receipt, the verdict is lost.
2. **Correct ordering for non-trivial findings (new numbered list)** — (i) produce + return prose, (ii) THEN `mem_save` with substantive payload, (iii) silent exit (no confirmation message after the save).
3. **`mem_save` payload requirements (new sub-list)** — `decision` / `architecture` must carry ≥150 words including rationale + alternatives + re-litigation triggers (not a one-line slogan); `bugfix` / `pattern` / `discovery` ≥50 words with `file:line` citation if applicable.
4. **Panel-mode caveat (new paragraph)** — when the orchestrator spawns multiple adversarial agents in parallel, the orchestrator NEEDS prose to synthesize across the panel; returning a save receipt alone makes the agent invisible to the synthesis. Anti-ritualisation explicit.

Pre-existing fields kept unchanged: `mem_search` before, `prior_finding_refs` chain, Compounding observable gate, MINT project context pointer.

The 21 GSD orchestrator agents (`gsd-*`) are NOT touched — they do not have the engram block (they orchestrate, do not write findings themselves).

Application: one-shot Python script (`/tmp/patch_wshobson_engram.py`, not committed to repo) that does a textual find-and-replace on the exact old block (56 / 56 files patched, 21 skipped correctly, 0 already-patched). Idempotent: re-running the script after patch is a no-op because the OLD block no longer matches.

## Counter-arguments and data gaps

### What does the strongest opposing view say?

> *"The bug observed on 2026-05-17 was a one-off interpretation drift, not a contract issue. The contract wording was already clear if read carefully: `mem_save` 'after' a finding implies the finding (prose) comes first, save second. Adding 600 words of clarification to 56 agent files inflates the system prompt for every subagent invocation across the project (token cost × N agents × every spawn) and may itself crowd out other context the agents need. A single-file fix to a shared template — or a runtime check in the orchestrator that detects 'last message is a save receipt' and retries — would be lower-blast-radius."*

This is partially fair. Counter-counter: (a) the contract was NOT clear enough — 4 agents got it right but 1 didn't, and the 1 that didn't was the one with the highest-value verdict; (b) there is no shared-template indirection in the current setup — each agent file is standalone, so a "shared template" doesn't exist without refactoring the wshobson/VoltAgent ingestion pipeline; (c) the token cost of ~400 words × 56 agents is real but bounded (~22 kB total across the catalog, ~0.4 kB per invocation since only one agent loads per spawn), and well below the cost of one lost-verdict round-trip; (d) a runtime detection would be a band-aid over a contract bug — fixing the contract is the surgical move.

### What does this source not address?

- **No live A/B test.** This ADR applies the patch and proceeds; no spawn-test of a patched vs unpatched agent was run side-by-side. The patch's behavioural effect will be observed at the next adversarial panel (Phase 1 GSD discuss-phase « calc engine canonical »).
- **Generalisation to other catalogs.** Future agents adopted from upstream catalogs (e.g. additional VoltAgent imports) will arrive without the patch and reproduce the original bug. A lint or template-injection in the adoption pipeline is the right structural fix; not done here.
- **Cross-session compounding metric.** The Phase 1 gate 2026-05-21 (≥3 of first 5 PRs reviewed cite a prior `obs_id`) is unchanged by this ADR — the patch doesn't materially affect that metric one way or the other; just makes the verdicts retrievable when the panel pattern is used.
- **Token-cost telemetry.** No before/after measurement of subagent prompt tokens; the assertion that ~400 extra words is "well below" the round-trip cost is qualitative, not measured.

### What would change this conclusion?

- **A future panel STILL loses prose despite this patch.** Re-litigate — the bug is deeper than wording, possibly in the agent's internal habit of treating `mem_save` as a terminal action regardless of contract clarity. Mitigation candidates: runtime orchestrator-side detection, or model-level fine-tuning instruction shipped at spawn time.
- **Anthropic ships a new sub-agent return-channel** that decouples engram side-channel writes from the orchestrator-readable output. The contract wording becomes moot.
- **The 56-file count drifts** (new wshobson or VoltAgent agents adopted without the patched block, or someone refactors agents into a shared template). Re-apply with the same script + audit on adoption.
- **A lint is added to the adoption pipeline** that auto-injects the patched block — supersedes this manual-patch decision.

## Sources

- This conversation (2026-05-17) — the data-architecture panel where the bug surfaced.
- Engram obs #150 — the title-only observation that proved the bug ("User-facts layer: prefer event-log+projection+crypto-shred over Snodgrass bitemporal").
- Memory `project_wshobson_engram_contract_fix_queued` (created 2026-05-17) — the queued reco that this ADR closes.
- [Related ADR — data architecture event-log + projection + DEK envelope](2026-05-17-data-architecture-event-log-vs-bitemporal.md) — the panel that triggered this fix.
- Patched files (56 total): all `.claude/agents/*.md` except the 21 `gsd-*` orchestrator agents.
- [CLAUDE.md §3.5](../../CLAUDE.md) — wshobson + VoltAgent team registration + memory contract.
- [docs/AGENTS/VIBE-CODING-INFRA.md](../../docs/AGENTS/VIBE-CODING-INFRA.md) — engram setup and conventions.

## Status & follow-up

### Implementation tracking

- Branch: `tooling/wshobson-engram-contract-fix-2026-05-17`
- Commit: created in same change as this ADR.
- PR: to be opened as a regular PR (not Draft) — no gating needed, the change is additive to agent metadata and does not affect application code or CI behaviour.

### Re-litigation triggers (listed above)

- Future panel STILL loses prose → contract bug is deeper, re-investigate.
- Anthropic sub-agent return-channel changes → wording may become moot.
- 56-file count drifts (new agents) → re-apply patch.
- Lint added to adoption pipeline → this manual-patch decision is superseded.
