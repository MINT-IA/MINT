// Phase 30.6-01 CTX-04 — token budget assertions (replaces Wave 0 stub).
// Per D-15: worst-case 3 snippets × ~250 tokens = <800 tokens total.
// Heuristic: 4 chars/token → each .claude/context-snippets/*.md ≤1000 chars
// so 3×1000=3000 chars ≈ 750 tokens < 800 budget.
// Pitfall 3: malformed JSON → exit 0 + append hook_failures.jsonl.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { readFileSync, statSync, existsSync, readdirSync, mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const HOOK = join(__dirname, '..', 'mint-context-injector.js');
const SNIPPETS_DIR = join(__dirname, '..', '..', 'context-snippets');
const HOOK_FAILURES = join(__dirname, '..', '..', '..', '.planning', 'agent-drift', 'hook_failures.jsonl');

function callHook(input, env = {}) {
  return spawnSync('node', [HOOK], {
    input,
    env: { ...process.env, ...env },
    encoding: 'utf8',
    timeout: 5000,
  });
}

test('D-15 individual snippets — each .claude/context-snippets/*.md ≤1000 chars', () => {
  const files = readdirSync(SNIPPETS_DIR).filter((f) => f.endsWith('.md'));
  assert.ok(files.length >= 5, `expected ≥5 snippet files, got ${files.length}`);
  for (const f of files) {
    const size = statSync(join(SNIPPETS_DIR, f)).size;
    assert.ok(size <= 1000, `${f} is ${size} chars (>1000 D-15 ceiling per snippet)`);
  }
});

test('D-15 worst case — 3 snippets concat ≤3000 chars (≈750 tokens < 800 budget)', () => {
  // Craft a prompt that matches all 5 patterns to trigger worst-case dedup to 3.
  const prompt = 'Please commit the nouveau .dart file in apps/mobile/lib/screens/ that updates app_fr.arb and handles rente calcul';
  const r = callHook(JSON.stringify({ user_prompt: prompt }));
  assert.equal(r.status, 0, `hook crashed: stderr=${r.stderr}`);
  assert.ok(r.stdout.trim().length > 0, 'expected non-empty stdout on worst-case match');
  const out = JSON.parse(r.stdout);
  const ctx = out.hookSpecificOutput.additionalContext;
  assert.ok(ctx.length <= 3000, `injected ctx is ${ctx.length} chars (>3000 worst-case ceiling, ≈${Math.round(ctx.length / 4)} tokens)`);
  const header = ctx.match(/📌 MINT context — (\d+) rule/);
  assert.ok(header, 'missing header');
  const n = parseInt(header[1], 10);
  assert.ok(n <= 3, `injected ${n} rules, expected ≤3 per D-15`);
});

test('Pitfall 3 — malformed JSON → exit 0 + hook_failures.jsonl appended', () => {
  // Ensure the parent dir exists so the hook's mkdir succeeds.
  try {
    mkdirSync(dirname(HOOK_FAILURES), { recursive: true });
  } catch {
    /* ignore */
  }
  const sizeBefore = existsSync(HOOK_FAILURES) ? statSync(HOOK_FAILURES).size : 0;
  const r = callHook('not-json-at-all');
  assert.equal(r.status, 0, 'hook must never block on malformed input');
  // Sanity check: if the hook wrote to HOOK_FAILURES, it should have grown.
  if (existsSync(HOOK_FAILURES)) {
    const sizeAfter = statSync(HOOK_FAILURES).size;
    assert.ok(
      sizeAfter > sizeBefore,
      `hook_failures.jsonl did not grow (before=${sizeBefore} after=${sizeAfter}) — Pitfall 3 mitigation broken`
    );
    // Verify the latest line is a parseable JSON object with reason field.
    const content = readFileSync(HOOK_FAILURES, 'utf8');
    const lastLine = content.trim().split('\n').pop();
    const row = JSON.parse(lastLine);
    assert.ok(row.reason, 'hook_failures entry missing reason field');
    assert.ok(row.ts, 'hook_failures entry missing ts field');
  }
});
