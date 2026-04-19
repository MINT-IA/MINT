// Wave 0 stub — Plan 04 CTX-04 task (Phase 30.6 Advanced) will implement.
// Verifies mint-context-injector.js per D-14 (5 patterns), D-15 (top-3 dedup),
// D-17 (env override). All tests are test.skip() until Phase 30.6.
//
// Pattern reference: .claude/hooks/gsd-prompt-guard.js (stdin JSON → stdout JSON
// via hookSpecificOutput.additionalContext), never-block philosophy
// (catch { process.exit(0); }).
import { test } from 'node:test';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const HOOK = join(__dirname, '..', 'mint-context-injector.js');
const FIXTURE = join(__dirname, 'fixtures', 'prompt.json');

// Keep references used so lint/analyzers see the intent.
void HOOK;
void FIXTURE;
void readFileSync;

test('matches D-14 pattern 1: .arb file edited injects arb snippet', { skip: 'TODO Wave 4 Plan 04 Task 2 (Phase 30.6): feed fixture with ".arb" mention, expect stdout JSON with arb snippet' }, () => {});

test('matches D-14 pattern 2: .dart in screens/ injects screens snippet', { skip: 'TODO Wave 4 Plan 04 Task 2 (Phase 30.6)' }, () => {});

test('matches D-14 pattern 3: calcul|calculator|simulator injects calculator snippet', { skip: 'TODO Wave 4 Plan 04 Task 2 (Phase 30.6)' }, () => {});

test('matches D-14 pattern 4: commit verb injects commit snippet', { skip: 'TODO Wave 4 Plan 04 Task 2 (Phase 30.6)' }, () => {});

test('matches D-14 pattern 5: nouveau .dart|create .dart injects new-dart snippet', { skip: 'TODO Wave 4 Plan 04 Task 2 (Phase 30.6)' }, () => {});

test('D-15 dedup: 5 matches caps to top-3 by priority order', { skip: 'TODO Wave 4 Plan 04 Task 2 (Phase 30.6): synthetic prompt matching all 5 patterns, expect exactly 3 snippets in output' }, () => {});

test('D-17 override: MINT_NO_CONTEXT_INJECT=1 no-ops hook', { skip: 'TODO Wave 4 Plan 04 Task 4 (Phase 30.6)' }, () => {});

test('header format: stdout additionalContext starts with "MINT context — N rule(s) apply"', { skip: 'TODO Wave 4 Plan 04 Task 2 (Phase 30.6)' }, () => {});
