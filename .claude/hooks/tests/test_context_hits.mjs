// Wave 0 stub — Plan 01 CTX-02 metric (b) extension of gsd-prompt-guard.js
// will implement. Per D-11 (b): log violations detected PRE-1st-tool_use to
// .planning/agent-drift/context_hits.jsonl with schema:
//   {session_id, hit_type, rule_id, tool_use_index, detected_at}
import { test } from 'node:test';

test('gsd-prompt-guard extension logs violations to .planning/agent-drift/context_hits.jsonl', { skip: 'TODO Wave 1 Plan 01 Task 4: feed PreToolUse with content triggering injection pattern, expect context_hits.jsonl appended with {session_id, hit_type, rule_id, tool_use_index, detected_at}' }, () => {});

test('tool_use_index=0 captured on 1st tool_use before any other tool_use', { skip: 'TODO Wave 1 Plan 01 Task 4: index must be 0 for the very first tool_use of the session' }, () => {});
