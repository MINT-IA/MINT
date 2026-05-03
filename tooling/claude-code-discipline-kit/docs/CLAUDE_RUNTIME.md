# Claude Runtime Notes

> Valid for: **Claude Opus 4.7 (1M context)** and **Claude Sonnet 4.6** as of May 2026. This document rots faster than the discipline doc — re-validate quarterly.

## Context window mechanics

| Model | Context | Cache write (5min) | Cache write (1h) | Cache read |
|---|---|---|---|---|
| Opus 4.7 | 1M tokens | 1.25× base | 2× base | 0.1× base |
| Sonnet 4.6 | 200K tokens | 1.25× base ($3.75) | 2× base ($6) | 0.1× base ($0.30) |
| Haiku 4.5 | 200K tokens | 1.25× base ($1.25) | 2× base ($2) | 0.1× base ($0.10) |

Implications for discipline 8 (< 40% utilization):
- Sonnet 4.6: stay below 80K tokens for "comfortable" zone
- Opus 4.7: 400K tokens is still safe but cache amortization matters even more

## Server-side compaction APIs

```python
context_management = {
    "edits": [{
        "type": "compact_20260112",
        "trigger": {"type": "input_tokens", "value": 150_000},
        "instructions": (
            "Summarize this transcript. Preserve every quantitative fact "
            "with its source, and note which documents have been read. "
            "Wrap the summary in <summary></summary>."
        ),
    }]
}
response = client.beta.messages.create(
    model="claude-sonnet-4-6",
    messages=messages,
    context_management=context_management,
    betas=["compact-2026-01-12"],
)
```

```python
context_management = {
    "edits": [{
        "type": "clear_tool_uses_20250919",
        "trigger": {"type": "input_tokens", "value": 30_000},
        "keep": {"type": "tool_uses", "value": 4},
        "clear_at_least": {"type": "input_tokens", "value": 10_000},
        "exclude_tools": ["memory"],
    }]
}
```

## Skill auto-trigger semantics

Claude Code skills with auto-trigger fire on every turn when the model's heuristic considers them relevant. Two auto-trigger skills both claiming "always relevant" produce nondeterministic ordering and double context injection.

This kit ships its skill as **manual-trigger only** (`/claude-code-discipline` slash command). Reasons:
1. Avoids collision with `obra/superpowers/using-superpowers` which is the canonical auto-trigger for engineering disciplines
2. Lets the user explicitly recite the disciplines at session start (which is itself discipline 11)
3. Reduces token waste

If you WANT auto-trigger behavior, add to your project's `CLAUDE.md`:

```markdown
At session start, invoke /claude-code-discipline to load discipline rules.
```

The model will treat that as an instruction.

## Memory tool (persistent cross-session)

```python
tools = [
    {"type": "memory_20250818", "name": "memory"},
    # ... other tools
]
```

Use cases for the memory tool in a project context:
- Persist "what we tried that didn't work" across debug sessions (discipline 12 — keep errors in context, even across sessions)
- Persist user preferences and feedback corrections
- Persist tool census results so they don't have to be re-computed

## Sub-agent dispatching

The Anthropic-recommended threshold: **≥ 10 files OR ≥ 3 independent pieces of work** → dispatch a sub-agent.

Pattern:
1. Main agent prepares a clear task description with context budget for the sub-agent (~10K tokens budget).
2. Sub-agent does the deep exploration / writes / reviews.
3. Sub-agent returns a structured 1-2K token summary.
4. Main agent integrates the summary, never re-reads the sub-agent's exploration.

The kit's `tool-census.sh` is itself a candidate for sub-agent dispatch on large projects: sub-agent enumerates 100+ tools, returns top 10 underused.
