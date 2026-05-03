# The 14 Disciplines

> Timeless rules for AI-assisted development. Language-agnostic, framework-agnostic, runtime-agnostic. The runtime-specific notes for Claude Opus 4.7 live in [CLAUDE_RUNTIME.md](CLAUDE_RUNTIME.md).

## Why these specific disciplines

The dominant failure mode of AI-assisted coding in 2026 is not bad code — it's **shallow code that looks done but isn't wired, tested, or honest about its state**. The 80% rule: if Claude is right 80% of the time per micro-decision and a feature has 20 decisions, the joint probability of correctness is ~1%. The disciplines below collapse those 20 ambiguous decisions into reviewed artifacts where each lands near 100%.

---

## Engineering Disciplines (1-7)

### 1. Plan-mode before code

**Rule:** any task with ≥ 3 distinct decisions OR ≥ 2 files to modify enters plan-mode BEFORE the first code edit.

A plan must answer:
- **Goal** — what we're trying to accomplish (not what we'll do)
- **Files** — exhaustive list, grep-verified
- **Decisions** — each ambiguity with explicit trade-off
- **Verification commands** — the lint/test commands that must turn green
- **Definition of done** — observable post-merge state

Anti-pattern: "I'll just edit this file quickly" without a plan = source #1 of surface code.

### 2. Iron Law: no fix without root-cause investigation

**Rule:** zero fixes proposed until the root cause is identified AND written (one sentence is enough, but it must exist).

Process: Investigation → Pattern Analysis → Hypothesis → Implementation.

**3-Fix Rule:** after 3 failed fix attempts, STOP and reassess the architecture. No "let me try one more thing".

Anti-pattern: patching a symptom ("I'll add a null-check here") without understanding why the null arrives.

### 3. Subagent-driven development

**Rule (Anthropic):** if a task touches ≥ 10 files OR contains ≥ 3 independent pieces, use subagents.

Pattern: 1 implementer + 1 spec-compliance reviewer + 1 code-quality reviewer (Superpowers two-stage). Subagents return condensed summaries (1-2K tokens) instead of polluting the main context with raw exploration (10K+ tokens).

Anti-pattern: doing everything in the main thread, context saturated, quality degrades after 30K tokens.

### 4. TDD inverted: RED-GREEN-REFACTOR (failing test FIRST)

**Rule:** write a FAILING test, watch it fail, then write minimal code to pass, then refactor, then commit.

LLMs naturally write implementation first then tests; that produces tests that confirm the code does what the code does, not what it should do. Inverting the order is the only way TDD actually compounds.

Anti-pattern: "I test after". Tests that come after the code prove nothing about correctness vs. requirement.

### 5. Verification-before-completion (evidence > assertions)

**Rule:** zero "done / fixed / passing" claims without having RUN the verification command in the same session AND read the output.

Pre-push checklist (universal):
1. `grep` for callers of any modified function/symbol → update them
2. Regenerate any code-gen artifact (OpenAPI, gen-l10n, etc.) if schemas changed
3. Run the FULL test suite, not just the changed file
4. Read the test output — don't trust exit codes alone

Anti-pattern: "I changed X, it compiles, I push." Source of multi-cycle CI failures.

### 6. Design / code-review panel before merge

**Rule:** any change touching UX, data flow, or external contract → 4-person panel (UX expert + accessibility expert + adversarial reviewer + wiring/integration expert) IN PARALLEL, apply critical fixes, THEN push.

Reviews happen BEFORE merge, not after. Codex / GPT / peer-LLM cross-review for adversarial perspective.

Anti-pattern: push a "small fix", skip review, drift accumulates silently.

### 7. HTML evidence per phase (durable memory)

**Rule:** every phase or significant work batch produces an HTML report logging PRs, panel verdicts, test counts, deferred items. Store under version control (e.g., `.planning/phases/<phase>/<phase>-VERIFICATION-REPORT.html`).

Cumulative `SESSION-YYYY-MM-DD.html` rolls them up.

Without persisted evidence, every session restarts from zero and reproduces the same errors.

Anti-pattern: store evidence in `/tmp/...` — lost across sessions.

---

## Context Engineering Disciplines (8-13)

> "Context is the new code" — Patrick Debois, QCon London 2026. Context deserves the same infrastructure code has: version control, review, testing, CI/CD, monitoring.

### 8. Context utilization < 40% in permanence

**Rule:** maintain context window utilization under 40% during execution. Above that, quality degrades silently (Liu 2024 "lost in the middle" + transformer context rot).

Mental measurement at every decision point. Above 40%, take ONE of:
- **Compaction** — `compact_20260112` Anthropic API (trigger 150K) or manual `<summary>` block
- **Tool result clearing** — `clear_tool_uses_20250919` (drop re-fetchable results, keep tool_use record)
- **Sub-agent dispatch** — isolate noisy task, return 1-2K condensed
- **Just-in-time retrieval** — store paths/URLs, load content via `head`/`tail` on demand

Anti-pattern: "I'll load all 5 files at once for context". No. Load 1, understand, decide what to load next.

Observed (Horthy 2025): teams under 40% ship 35K LOC in 7h on a 300K-line codebase. Above = thrashing.

### 9. Research / Plan / Implement as 3 separate artifacts

**Rule:** never mix what you discover with what you decide. Three artifacts:

| Artifact | Contents |
|---|---|
| RESEARCH | Files, lines, dependencies, canonical examples. **No decisions.** |
| PLAN | Goal, decisions, atomic tasks, verification, DoD. **No discovery.** |
| IMPLEMENTATION | The commits themselves. |

Mixing Research and Plan means the implementation re-reads all discovery → token cost + attention dilution.

If using GSD: `gsd-phase-researcher` produces RESEARCH.md consumed by `gsd-planner`. Use it.

### 10. KV-cache stability (production cost imperative)

**Rule (Manus production lessons):** KV-cache hit rate is the #1 production cost metric. Cached tokens are ~10× cheaper than uncached. Maintain hit rate > 60%.

Discipline:
- **Stable prompt prefix** — zero per-second timestamps, zero random tokens, zero variable hashes at start
- **Append-only context** — never edit past actions/observations (immediate cache invalidation)
- **Deterministic serialization** — `json.dumps(..., sort_keys=True)` and equivalents
- **Mask, don't remove tools** — to gate a tool, mask logits via state machine; don't remove the definition
- **Cache TTL 1h** explicit when sessions are bursty (mobile apps, async workflows)
- **Monitor** — log `cache_creation_input_tokens` + `cache_read_input_tokens` per response → alert if hit rate < 50%

### 11. Recitation pattern for long-running goals

**Rule:** in multi-PR phases or tasks > 50 tool calls, **rewrite the goal and current todo state at every step transition** in the model's recent attention window.

Concretely: TodoWrite at every step (already default), AND a short `## Current state` text block before each batch of actions.

Without recitation, the goal sits at the start of the context (early attention), the recent attention is on the last actions, and macro-drift accumulates.

Anti-pattern: chain 50 tool calls without ever re-asserting what we're trying to accomplish.

### 12. Keep errors in context (counter-intuitive, Manus)

**Rule:** do NOT clean past error traces from the context. The model implicitly learns from failures and shifts predictions.

Anti-pattern: "the test failed, I clean the transcript and retry" → reproduces the same error.

Pattern: leave error visible + add short diagnostic + retry informed.

Applies to debugging loops and the 3-Fix Rule (discipline 2).

### 13. Avoid few-shot drift on repetitive tasks

**Rule (Manus):** when processing N similar items (e.g., 144 templates, 6 i18n files × N keys), introduce controlled variation in serialization/order to prevent the model from falling into a mechanical pattern that drifts.

Concrete: vary section order, alternate canonical examples used, lightly randomize system prompts.

Anti-pattern: 144 templates generated in identical series → systematic undetected drift until a user reports.

---

## Discoverability Discipline (14)

### 14. Tool census + utilization tracking

**Rule:** the tools you don't know you have are the tools you can't use. Every project must inventory its discoverable tools (skills, scripts, MCP servers, hooks, lints) AND track utilization. Surface unused tools at session start.

Failure mode this kills: a project accumulates 100+ skills/lints/scripts over time. The active operator (you, or Claude) uses ~10%. The other 90% rot, then someone re-implements them poorly.

Implementation:
- `bin/tool-census.sh` enumerates all `.claude/skills/`, `tools/`, `scripts/`, `.mcp.json` entries
- Cross-references against last-invocation log (parsed from session transcripts or `.claude/usage/`)
- Outputs a sorted list: tools used in last 30 days vs. tools never used vs. tools used once
- At session start (skill auto-prompt), surface 3 underused tools relevant to the current goal

Anti-pattern: install superpowers, install gstack, install GSD, install kit-after-kit → never read the indexes → solve problems with grep when a perfect skill exists.

This discipline is the meta-discipline: it ensures the OTHER 13 are actually invoked.

---

## How disciplines compose with existing tooling

| If you have | The kit defers to | The kit adds |
|---|---|---|
| `obra/superpowers` | Disciplines 1-7 (TDD, plan, verification, subagent, debug) | Disciplines 8-14 + lint_status_audit + tool census |
| `muratcankoylan/Agent-Skills-for-Context-Engineering` | Disciplines 8-13 documentation | Enforcement infra (lint, hooks, tool census) |
| GSD framework | R/P/I (discipline 9) → gsd-discuss / gsd-plan / gsd-execute | Disciplines 8, 10-14 + composability skill |
| `gstack` | Voice triggers, lifecycle skills | Universal lints + bootstrap mechanics |
| Nothing yet | — | All 14 disciplines as default |

The kit detects what's installed via `bin/doctor.sh` and prints the precise composition map.
