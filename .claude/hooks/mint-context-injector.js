#!/usr/bin/env node
// mint-context-injector — UserPromptSubmit hook (CTX-04, Phase 30.6)
// Injects MINT-specific context snippets when user_prompt matches D-14 patterns.
//
// Contract:
//   stdin  = { session_id, tool_name, user_prompt, ... } (UserPromptSubmit event)
//   stdout = { hookSpecificOutput: { hookEventName: "UserPromptSubmit",
//                                    additionalContext: "📌 MINT context — N rules apply\n\n..." } }
//          OR empty (no match / override / error / timeout) — never blocks.
//
// Decisions implemented:
//   D-13 Node.js convention (.claude/hooks/*.js)
//   D-14 5 regex patterns ordered by priority
//   D-15 Top-3 dedup when >3 match; total worst case ≤800 tokens
//   D-16 Snippets live in .claude/context-snippets/*.md (lazy read)
//   D-17 Env override MINT_NO_CONTEXT_INJECT=1 → exit 0 no-op
//   Patch 4 (post-split 2026-04-19) 500ms internal AbortController fail-open hard cap.
//   Pitfall 3 all failure paths append to .planning/agent-drift/hook_failures.jsonl.
//
// Never-block philosophy: catch { process.exit(0) }. stderr routes to
// /tmp/mint-context-injector-error.log, never bubbles to Claude Code UI.
//
// Pattern reference: .claude/hooks/gsd-prompt-guard.js (v1.33.0).

'use strict';

const fs = require('fs');
const path = require('path');

// ---------- Patch 4 — hard cap fail-open (500ms) ----------
// If anything — including the rest of this file — takes longer than 500ms,
// we exit 0 with no stdout. Agents stay unblocked.
const FAIL_OPEN_MS = 500;
const failOpenTimer = setTimeout(() => {
  try {
    logFailure('fail_open_timeout', { ms: FAIL_OPEN_MS });
  } catch {
    /* silent */
  }
  process.exit(0);
}, FAIL_OPEN_MS);
// Keep ref but allow Node to exit when main pipeline finishes normally.
failOpenTimer.unref?.();

// ---------- D-17 env override ----------
if (process.env.MINT_NO_CONTEXT_INJECT === '1') {
  clearTimeout(failOpenTimer);
  process.exit(0);
}

// ---------- D-14 5 patterns (priority order = source order) ----------
const PATTERNS = [
  { id: 'arb',        snippet: 'arb.md',        regex: /\.arb\b/i },
  { id: 'screens',    snippet: 'screens.md',    regex: /(?:screens\/[^\n]*\.dart\b|\.dart\b[^\n]*screens\/)/i },
  { id: 'calculator', snippet: 'calculator.md', regex: /\b(calcul|calculator|simulator|projection|rente|capital|tax)\b/i },
  { id: 'commit',     snippet: 'commit.md',     regex: /\bcommit\b/i },
  { id: 'new-dart',   snippet: 'new-dart.md',   regex: /\b(nouveau\s+\.dart|create[^\n]*\.dart)\b/i },
];

const SNIPPETS_DIR = path.join(__dirname, '..', 'context-snippets');
const FAILURES_LOG = path.join(__dirname, '..', '..', '.planning', 'agent-drift', 'hook_failures.jsonl');
const ERROR_LOG = '/tmp/mint-context-injector-error.log';

function logFailure(reason, detail) {
  try {
    fs.mkdirSync(path.dirname(FAILURES_LOG), { recursive: true });
    const row = {
      ts: Math.floor(Date.now() / 1000),
      reason,
      detail: detail || null,
    };
    fs.appendFileSync(FAILURES_LOG, JSON.stringify(row) + '\n');
  } catch (err) {
    // Never surface to stderr/stdout — route to /tmp log.
    try {
      fs.appendFileSync(
        ERROR_LOG,
        `[${new Date().toISOString()}] logFailure(${reason}): ${err && err.message}\n`
      );
    } catch {
      /* silent */
    }
  }
}

// ---------- stdin read with short timeout (Patch 4 outer cap still wins) ----------
let input = '';
const stdinTimer = setTimeout(() => {
  // No data in — treat as no-op (fail-open, no stdout).
  clearTimeout(failOpenTimer);
  process.exit(0);
}, 400);
stdinTimer.unref?.();

process.stdin.setEncoding('utf8');
process.stdin.on('data', (chunk) => {
  input += chunk;
});
process.stdin.on('end', () => {
  clearTimeout(stdinTimer);
  try {
    if (!input || !input.trim()) {
      clearTimeout(failOpenTimer);
      process.exit(0);
    }

    let data;
    try {
      data = JSON.parse(input);
    } catch (err) {
      // Pitfall 3 — malformed JSON: log + exit 0.
      logFailure('parse_error', { err: err && err.message });
      clearTimeout(failOpenTimer);
      process.exit(0);
    }

    const userPrompt = (data && (data.user_prompt || data.prompt)) || '';
    if (!userPrompt) {
      clearTimeout(failOpenTimer);
      process.exit(0);
    }

    // ---------- D-14 match + D-15 top-3 dedup ----------
    const matches = PATTERNS.filter((p) => {
      try {
        return p.regex.test(userPrompt);
      } catch (err) {
        logFailure('regex_error', { id: p.id, err: err && err.message });
        return false;
      }
    });
    if (matches.length === 0) {
      clearTimeout(failOpenTimer);
      process.exit(0);
    }

    const top3 = matches.slice(0, 3);
    const sections = [];
    for (const m of top3) {
      try {
        const snippetPath = path.join(SNIPPETS_DIR, m.snippet);
        const snippet = fs.readFileSync(snippetPath, 'utf8');
        sections.push(snippet.trim());
      } catch (err) {
        logFailure('snippet_missing', { id: m.id, snippet: m.snippet, err: err && err.message });
      }
    }

    if (sections.length === 0) {
      // All snippets missing — silent no-op (logged).
      clearTimeout(failOpenTimer);
      process.exit(0);
    }

    const count = sections.length;
    const header = `📌 MINT context — ${count} rule${count > 1 ? 's' : ''} apply`;
    const body = [header, '', ...sections].join('\n\n');

    const out = {
      hookSpecificOutput: {
        hookEventName: 'UserPromptSubmit',
        additionalContext: body,
      },
    };

    process.stdout.write(JSON.stringify(out));
    clearTimeout(failOpenTimer);
    process.exit(0);
  } catch (err) {
    logFailure('runtime_error', { err: err && err.message });
    clearTimeout(failOpenTimer);
    process.exit(0);
  }
});

process.stdin.on('error', (err) => {
  logFailure('stdin_error', { err: err && err.message });
  clearTimeout(failOpenTimer);
  process.exit(0);
});
