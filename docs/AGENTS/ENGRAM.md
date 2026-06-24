# Engram — Memory Doctrine for MINT Agents

> Engram is MINT's persistent memory MCP server. Each subagent has its own memory namespace; all observations live in one shared database (`~/.engram/engram.db`) accessible by every agent. This file is the source-of-truth for **what we save**, **how we tag it**, and **how agents reference each other's findings**.

## TL;DR

- **Save** : decisions, bug patterns, panel verdicts, post-execution outcomes, gotchas, conventions.
- **Don't save** : code patterns derivable from `git blame`, ephemeral state, content already in `CLAUDE.md`/`docs/`.
- **Tag** : `topic_key: <phase-or-area>:<sub-area>:<specific>` (e.g. `wave-1a:00:backend-architect:review`).
- **Link** : every save cites `prior_finding_refs: [obs_id, ...]` when building on past work — this is the **compounding observable** gated 2026-05-21 for vibe-coding Phase 1.
- **Use MCP first** : `mem_*` tools are the normal path. Do not stop because a
  private `MEMORY.md` file is missing; recover with `mem_context` /
  `mem_search`, then report the gap.

## 1. What goes IN

### 1.1 Decisions (most common)

A locked architectural / strategic / scope decision worth re-finding next session.

```yaml
type: decision
title: "wave-1a launch strategy: wave-0 calibration + supplementation pattern"
topic_key: wave-1a:launch:strategy
```

Body : **What** + **Why** + **Where** + **Learned** (Anthropic structured format).

### 1.2 Bug patterns (cross-plan / cross-phase)

A pattern that affected ≥2 plans / files / surfaces. Single-file typos go in commit message, not engram.

```yaml
type: bugfix
title: "wave-1a cross-plan audit: profile_id→user_id drift in plans 01-04"
topic_key: wave-1a:cross-plan:audit
```

### 1.3 Panel verdicts (REVIEW-ONLY agent output)

Pre-execution panel from `backend-architect`, `fastapi-pro`, `python-pro`, etc. — saves the verdict + concerns + recommendations.

```yaml
type: decision
title: "backend-architect verdict on wave-1a-02 retirement_projection"
topic_key: wave-1a:02:backend-architect:review
```

Always includes Decision (APPROVE / APPROVE_WITH_NOTES / BLOCK), Confidence (0.0–1.0), Concerns, Recommendations, `prior_finding_refs`.

### 1.4 Outcomes (post-execution)

What actually shipped after gsd-executor runs, with 0-trust receipts.

```yaml
type: decision
title: "wave-1a-02 EXECUTED — replacement_ratio percent→ratio fix shipped"
topic_key: wave-1a:02:outcome
```

Should cite the pre-execution panel obs_ids via `prior_finding_refs`.

### 1.5 Discoveries / gotchas

Non-obvious findings that future-you would want surfaced.

```yaml
type: discovery
title: "Mint agents cite prior findings through Engram before changing runtime gates"
topic_key: vibe-coding:agents:mint-engram-continuity
```

### 1.6 Conventions / patterns established

Naming, structure, recurring approaches. E.g. : *"flat-file `tests/test_coach_tools_<tool>.py` instead of `tests/test_coach_tools/test_<tool>.py` due to collision with pre-existing test file."*

## 2. What stays OUT

- ❌ Code patterns derivable from `git blame` / `git log`.
- ❌ Ephemeral task state — that's `TodoWrite`'s job.
- ❌ Anything already documented in `CLAUDE.md`, `docs/AGENTS/`, `docs/MINT_IDENTITY.md`.
- ❌ Speculative agent-generated drafts (the collective memory must stay trustable).
- ❌ Per-PR summary chatter (commit messages already serve that).
- ❌ Verbatim code listings (link to file:line instead).

## 3. `topic_key` convention

Format : `<area>:<sub-area>:<specific>` (lowercase, kebab-case, colon-separated).

| Area | Examples |
|---|---|
| Phase work | `wave-1a:00:outcome`, `phase-96-w3:narrative-sleeve:lint`, `wave-1b:plan-02:panel-synthesis` |
| Cross-plan / cross-phase patterns | `wave-1a:cross-plan:audit`, `phase-92.5:calc-rigor:byte-identity` |
| Infrastructure / vibe-coding | `vibe-coding:archi:36-specialists-shipped`, `vibe-coding:agents:gaps-inventory` |
| Per-agent reviews | `wave-1a:01:backend-architect:review`, `wave-1a:02:python-pro:review` |
| Per-agent outcomes | `wave-1a:00:code-reviewer:post-execution` |
| Domain knowledge | `swiss-brain:lpp:conversion-rate`, `financial-core:rounding:half-up` |

**Rules** :

1. Always start with the **bounded surface** (phase number, wave name, milestone, infra area).
2. Sub-area = either a plan id or a subsystem (`scaffolding`, `dispatcher`, `parity`, `migration`).
3. Specific suffix = the concrete output type or finding.
4. **Re-using a `topic_key` upserts** the latest observation — use this for evolving facts (e.g. `wave-1a:00:outcome` updates as the phase progresses, while `wave-1a:00:backend-architect:review` stays pinned to one verdict).

## 4. `prior_finding_refs` — the compounding contract

Every panel verdict + outcome SHOULD cite ≥1 prior `obs_id` it builds on. This is what makes engram a knowledge graph instead of an append-only log.

```yaml
prior_finding_refs:
  - obs-d518b856d7e4fe1a  # plan-01 backend-architect BLOCK
  - obs-fed17e4eb07fa156  # cross-plan audit
  - obs-8f8f4320fbb9a6f2  # plan-02 outcome
```

**Compounding observable** : chaque agent Mint permanent peut citer les observations Engram qu'il réutilise ; on mesure la continuité quand `prior_finding_refs` non-null cite des obs de PRs antérieures.

## 5. Conflicts — `mem_judge` heuristic

After every `mem_save`, the engram envelope may return `judgment_required: true` with candidate conflicts. Iterate `candidates[]` and call `mem_judge(judgment_id, relation, reason)` once per candidate.

| Confidence | Relation in {`supersedes`, `conflicts_with`} ? | Type in {`architecture`, `policy`, `decision`} ? | Action |
|---|---|---|---|
| ≥ 0.7 | No | — | Resolve silently as `related` / `compatible` / `not_conflict` |
| < 0.7 | Any | Any | Ask the user before judging |
| Any | Yes | Yes | Ask the user before judging |
| Any | Any | Any other | Resolve silently |

In practice, ~95% of conflict candidates this session were `related` (sibling panel verdicts on different plans) and resolved silently.

## 6. Per-agent memory — current state

The checked-in Mint agents use Engram through the orchestrator or MCP tools. No
vendor/GSD agent catalog is checked into `.claude/agents/`.

## 7. Lifecycle

1. **Session start** : engram auto-injects `mem_context` with recent observations (visible in the SessionStart hook).
2. **Per task** : agent calls `mem_search` to load prior context, references obs_ids in its work.
3. **Per finding** : agent calls `mem_save` with the right type + topic_key + prior_finding_refs. Conflicts are auto-judged silently when low-stakes.
4. **Session end** : `mem_session_summary` records goal + discoveries + accomplished + next steps + relevant files.

If private curator memory is missing or stale, that is a recoverable context
gap, not a default STOP. Current repo files and deterministic evidence remain
authoritative; Engram MCP supplies the durable memory fallback.

## 8. Where the data lives

- **Database** : `~/.engram/engram.db` (local, used by `engram serve` + `engram mcp` daemons — integrity-check OK). Note : legacy `/Volumes/FUN2/engram/engram.db` is abandoned/corrupted as of 2026-05-16 — `ENGRAM_DATA_DIR=/Volumes/FUN2/engram` is still set in `~/.zshrc` so the CLI fails ; the MCP daemons ignore the env var and work fine. Prefer `mem_save` MCP tool over `engram save` CLI until env var is removed.
- **Project scope** : auto-detected from `git remote` → `mint`.
- **Personal scope** : separate namespace for cross-project insights about Julien's workflow.
- **Weekly digest** : posted to Discord `#engram-exports` (Phase 1, PR #603).

## 9. When something goes wrong

- If a recalled memory contradicts current code, **trust what you observe now**. Update the memory via `mem_update` or save a superseding observation.
- If `mem_save` returns `judgment_required: true` and you can't decide, **ask the user** rather than guess.
- If you save twice with the same `topic_key`, the upsert is intentional — earlier content is replaced. Use a more specific `topic_key` if you want to keep both.
- If engram is unreachable (Mac mini offline), the MCP call fails fast — fall back to file-based notes in `.planning/notes/` and re-sync later via `mem_save`.

---

**Last updated** : 2026-05-14 (post Wave 1a plans 00–02 + plan-03 BLOCK decision).
**Owner** : Julien (product) + orchestrator (technical).
**Related** : `docs/AGENTS/VIBE-CODING-INFRA.md` (infra setup), `CLAUDE.md §3` (MCP tools surface), `CLAUDE.md §3.5` (team agents + routing).
