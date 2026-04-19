// Phase 30.6-01 CTX-04 — real assertions (replaces Wave 0 stub from Plan 30.5-00).
// Verifies mint-context-injector.js per D-13 (Node.js), D-14 (5 patterns, priority order),
// D-15 (top-3 dedup), D-17 (env override MINT_NO_CONTEXT_INJECT=1), Patch 4 (500ms fail-open).
//
// Pattern reference: .claude/hooks/gsd-prompt-guard.js (stdin JSON → stdout JSON
// via hookSpecificOutput.additionalContext), never-block philosophy
// (catch { process.exit(0); }).

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { existsSync, statSync, mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const HOOK = join(__dirname, '..', 'mint-context-injector.js');
const HOOK_FAILURES = join(__dirname, '..', '..', '..', '.planning', 'agent-drift', 'hook_failures.jsonl');

function callHook(stdinJson, env = {}) {
  const envVars = { ...process.env, ...env };
  return spawnSync('node', [HOOK], {
    input: stdinJson,
    env: envVars,
    encoding: 'utf8',
    timeout: 5000,
  });
}

test('D-14 pattern 1 — .arb edited → arb snippet injected', () => {
  const r = callHook(JSON.stringify({ user_prompt: 'Please edit apps/mobile/lib/l10n/app_fr.arb' }));
  assert.equal(r.status, 0, `exit=${r.status} stderr=${r.stderr}`);
  assert.ok(r.stdout.trim().length > 0, 'expected non-empty stdout on match');
  const out = JSON.parse(r.stdout);
  assert.equal(out.hookSpecificOutput.hookEventName, 'UserPromptSubmit');
  const ctx = out.hookSpecificOutput.additionalContext;
  assert.match(ctx, /📌 MINT context — 1 rule/);
  assert.match(ctx, /ARB|6 lang|flutter gen-l10n/i);
});

test('D-14 pattern 2 — .dart in screens/ → screens snippet injected', () => {
  const r = callHook(JSON.stringify({ user_prompt: 'Update apps/mobile/lib/screens/retirement_screen.dart' }));
  assert.equal(r.status, 0);
  const out = JSON.parse(r.stdout);
  const ctx = out.hookSpecificOutput.additionalContext;
  assert.match(ctx, /AppLocalizations|MintColors/);
});

test('D-14 pattern 3 — calcul keyword → calculator snippet injected', () => {
  const r = callHook(JSON.stringify({ user_prompt: 'Add a new calcul for rente projection' }));
  assert.equal(r.status, 0);
  const out = JSON.parse(r.stdout);
  const ctx = out.hookSpecificOutput.additionalContext;
  assert.match(ctx, /financial_core/);
});

test('D-14 pattern 4 — commit verb → commit snippet injected', () => {
  const r = callHook(JSON.stringify({ user_prompt: 'Please commit these changes' }));
  assert.equal(r.status, 0);
  const out = JSON.parse(r.stdout);
  const ctx = out.hookSpecificOutput.additionalContext;
  assert.match(ctx, /feature\/|conventional|LEFTHOOK_BYPASS|branch/i);
});

test('D-14 pattern 5 — nouveau .dart → new-dart snippet injected', () => {
  const r = callHook(JSON.stringify({ user_prompt: 'Create a nouveau .dart file for the widget' }));
  assert.equal(r.status, 0);
  const out = JSON.parse(r.stdout);
  const ctx = out.hookSpecificOutput.additionalContext;
  assert.match(ctx, /grep|lis avant|façade|facade/i);
});

test('D-15 dedup — prompt matching all 5 patterns yields exactly 3 snippets', () => {
  // Crafted to match all 5 patterns: .arb, .dart in screens/, calcul, commit, nouveau .dart
  const prompt = 'I need to commit the nouveau .dart file in apps/mobile/lib/screens/ that updates app_fr.arb and handles rente calcul';
  const r = callHook(JSON.stringify({ user_prompt: prompt }));
  assert.equal(r.status, 0);
  const out = JSON.parse(r.stdout);
  const ctx = out.hookSpecificOutput.additionalContext;
  const headerMatch = ctx.match(/📌 MINT context — (\d+) rule/);
  assert.ok(headerMatch, `header missing in: ${ctx.slice(0, 100)}`);
  const n = parseInt(headerMatch[1], 10);
  assert.ok(n <= 3, `injected ${n} rules, expected ≤3 per D-15`);
  assert.equal(n, 3, `expected exactly 3 for worst-case match, got ${n}`);
});

test('D-17 override — MINT_NO_CONTEXT_INJECT=1 produces empty stdout and exit 0', () => {
  const r = callHook(
    JSON.stringify({ user_prompt: 'Edit app_fr.arb and add a calcul' }),
    { MINT_NO_CONTEXT_INJECT: '1' }
  );
  assert.equal(r.status, 0);
  assert.equal(r.stdout.trim(), '', `expected empty stdout, got: ${r.stdout}`);
});

test('No match — plain prompt yields empty stdout and exit 0', () => {
  const r = callHook(JSON.stringify({ user_prompt: 'hello world, what time is it' }));
  assert.equal(r.status, 0);
  assert.equal(r.stdout.trim(), '');
});

test('Empty prompt — empty stdout and exit 0', () => {
  const r = callHook(JSON.stringify({ user_prompt: '' }));
  assert.equal(r.status, 0);
  assert.equal(r.stdout.trim(), '');
});

test('Malformed JSON → exit 0 AND hook_failures.jsonl grows (Pitfall 3)', () => {
  // Ensure parent dir exists so the hook has a writable target.
  try {
    mkdirSync(dirname(HOOK_FAILURES), { recursive: true });
  } catch {
    /* ignore */
  }
  const sizeBefore = existsSync(HOOK_FAILURES) ? statSync(HOOK_FAILURES).size : 0;
  const r = callHook('not-json-at-all');
  assert.equal(r.status, 0, 'hook must never block on malformed input');
  // If HOOK_FAILURES exists post-run, it should have grown.
  if (existsSync(HOOK_FAILURES)) {
    const sizeAfter = statSync(HOOK_FAILURES).size;
    assert.ok(sizeAfter > sizeBefore, `hook_failures.jsonl size did not grow (before=${sizeBefore} after=${sizeAfter})`);
  }
});

test('Patch 4 — hook exits 0 within 1s on empty stdin (fail-open AbortController)', () => {
  const r = spawnSync('node', [HOOK], {
    input: '',
    encoding: 'utf8',
    timeout: 1500,
  });
  assert.equal(r.status, 0, `expected exit 0, got ${r.status} stderr=${r.stderr}`);
  assert.equal(r.stdout.trim(), '', `expected no stdout on empty stdin, got: ${r.stdout}`);
});
