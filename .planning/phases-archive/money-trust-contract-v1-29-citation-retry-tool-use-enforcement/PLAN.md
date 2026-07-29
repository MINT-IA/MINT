# Phase 29 — Citation Retry Tool-Use Enforcement

## Goal

Ensure a retry response that cites a tool citation cannot pass unless the matching tool call exists in that same response.

## Audit Finding

The endpoint-level fallback test covered two uncited failures, but not the repaired retry path. QA recommended testing both:

- retry succeeds with a cited tool answer and matching tool call;
- retry falls back when the answer cites `tool_budget_snapshot` without a `get_budget_status` tool call.

## Scope

- Add endpoint tests for repaired retry success and missing-tool fallback.
- Enforce tool-use citations on raw LLM text before citation substitution.
- Apply this to both the initial-pass tool-use retry path and the citation-gate retry path.
