---
phase: mint-runtime-debug-tooling-m1
status: complete
created: 2026-06-22
---

# Mint Runtime Debug Tooling M1 — Research

This research is intentionally narrow. The question is not "what is the best
testing tool in general?" The question is "what lets Mint prove first
experience, account state, reset/delete, local residue, network sync, and
financial-value boundaries faster than manual TestFlight screenshots?"

## Findings

### Patrol

Patrol is the right first addition for the critical runtime gate. It keeps tests
in Dart/Flutter, can interact with native surfaces, and is better aligned with
relaunch/lifecycle/device interaction than pure widget tests or Maestro YAML.

Use it for:

- first open and onboarding route proof;
- debug/admin gate verification in non-release builds;
- reset/delete and relaunch proof;
- state-driven assertions through Debug Spine labels or test-only service hooks;
- screenshots on failure.

Do not use it for:

- every UI smoke flow;
- broad visual regression;
- replacing widget/provider tests.

### Maestro

Maestro remains useful for cheap smoke coverage and quick route checks. It
should not be the authoritative gate for the flows where Mint has already seen
AX/tap divergence on iPhone 13 mini.

Use it for:

- "app boots and core entry screen exists";
- simple public navigation;
- existing quality gate continuity.

Do not use it for:

- deciding whether a hidden/inactive Flutter CTA is tappable;
- final proof of account lifecycle, relaunch, or reset residue.

### Debug Spine

Debug Spine is the local truth layer. Runtime automation must not infer state
from UI alone when the bug class is "the UI looks empty but stale data still
exists" or "the UI shows values from unclear storage".

Use it for:

- counts;
- booleans;
- corruption flags;
- namespace presence;
- release/debug gate assertions.

Do not expose:

- raw wizard answers;
- raw financial values;
- real user text;
- tokens, device ids, or emails.

### Quern / Mobile MCP

Quern-like tooling is promising for M2 because it gives agents one local
interface for logs, network, screenshots, UI state, and control. That is close
to Mint's desired agent feedback loop.

M1 should not depend on Quern. Add a follow-up spike only after Patrol + Debug
Spine produce a stable local command.

### Langfuse

Langfuse fits the coach/LLM side later because it supports self-hosted traces,
metadata, evals, and dashboards. For Mint, the first acceptable scope is
synthetic coach eval traces, not production user prompts.

M1 should only define the trace boundary and redaction rules; implementation is
M2 unless the Patrol path finishes early.

### Sentry Session Replay

Session replay can help support and production debugging, but it is sensitive
for Mint because screens may contain financial facts. It belongs after local
debug evidence and redaction policy are mature.

M1 does not enable it.

## Recommendation

M1 should implement a local command:

```bash
tools/checks/mint_runtime_debug_tooling_gate.sh
```

The command should run the minimum deterministic stack:

1. static admin/debug gate;
2. Patrol critical flow;
3. Debug Spine evidence export;
4. network-sync redaction/assertion;
5. evidence completeness check.

That gives agents a reliable loop before adding heavier MCP or observability
tools.
