#!/usr/bin/env node
/**
 * MINT Context Monitor Hook (cherry-picked from GSD framework)
 *
 * Monitors context window usage and injects warnings when approaching limits.
 * Designed for MINT's autoresearch skills that run 50+ iterations.
 *
 * Architecture: PostToolUse hook that reads context data from stdin,
 * writes bridge file for cross-tool-call state, and injects warnings.
 *
 * Source: github.com/gsd-build/get-shit-done (hooks/gsd-context-monitor.js)
 * Adapted: Removed GSD-specific state management, kept core monitoring.
 */

const fs = require('fs');
const path = require('path');
const os = require('os');

// Tiers from GSD context-budget.md, adapted for MINT
const TIERS = {
  PEAK:      { max: 30, label: 'PEAK' },
  GOOD:      { max: 50, label: 'GOOD' },
  DEGRADING: { max: 70, label: 'DEGRADING' },
  POOR:      { max: 100, label: 'POOR' }
};

const WARNING_THRESHOLD = 35;   // % remaining → WARNING
const CRITICAL_THRESHOLD = 25;  // % remaining → CRITICAL
const DEBOUNCE_TOOL_USES = 5;   // minimum tool uses between repeated warnings
const STALE_SECONDS = 60;       // ignore metrics older than this
const AUTO_COMPACT_BUFFER = 16.5; // Claude auto-compacts at this %

function getTier(usedPct) {
  if (usedPct <= TIERS.PEAK.max) return TIERS.PEAK;
  if (usedPct <= TIERS.GOOD.max) return TIERS.GOOD;
  if (usedPct <= TIERS.DEGRADING.max) return TIERS.DEGRADING;
  return TIERS.POOR;
}

function getBridgePath(sessionId) {
  // Validate session ID against path traversal
  if (!sessionId || /[/\\]|\.\./.test(sessionId)) return null;
  return path.join(os.tmpdir(), `mint-ctx-${sessionId}.json`);
}

function getWarnStatePath(sessionId) {
  if (!sessionId || /[/\\]|\.\./.test(sessionId)) return null;
  return path.join(os.tmpdir(), `mint-ctx-${sessionId}-warned.json`);
}

function readWarnState(statePath) {
  try {
    if (fs.existsSync(statePath)) {
      return JSON.parse(fs.readFileSync(statePath, 'utf8'));
    }
  } catch { /* ignore */ }
  return { lastWarnedAt: 0, toolUsesSinceWarn: 0, lastSeverity: null };
}

function writeWarnState(statePath, state) {
  try {
    fs.writeFileSync(statePath, JSON.stringify(state), 'utf8');
  } catch { /* ignore */ }
}

async function main() {
  let input = '';

  // Read stdin with timeout
  const timeout = setTimeout(() => {
    process.stdout.write(JSON.stringify({ continue: true }));
    process.exit(0);
  }, 10000);

  process.stdin.setEncoding('utf8');
  for await (const chunk of process.stdin) {
    input += chunk;
  }
  clearTimeout(timeout);

  let data;
  try {
    data = JSON.parse(input);
  } catch {
    process.stdout.write(JSON.stringify({ continue: true }));
    return;
  }

  const sessionId = data.session_id || 'unknown';
  const bridgePath = getBridgePath(sessionId);
  const warnStatePath = getWarnStatePath(sessionId);

  if (!bridgePath || !warnStatePath) {
    process.stdout.write(JSON.stringify({ continue: true }));
    return;
  }

  // If context_window data is available, write bridge file
  if (data.context_window && typeof data.context_window.remaining_percentage === 'number') {
    const remaining = Math.max(0, data.context_window.remaining_percentage - AUTO_COMPACT_BUFFER);
    const used = 100 - remaining;
    const bridge = {
      session_id: sessionId,
      remaining_percentage: remaining,
      used_pct: used,
      timestamp: Date.now()
    };
    try {
      fs.writeFileSync(bridgePath, JSON.stringify(bridge), 'utf8');
    } catch { /* ignore */ }
  }

  // Read bridge file for current state
  let metrics;
  try {
    if (fs.existsSync(bridgePath)) {
      metrics = JSON.parse(fs.readFileSync(bridgePath, 'utf8'));
    }
  } catch { /* ignore */ }

  if (!metrics || (Date.now() - metrics.timestamp) > STALE_SECONDS * 1000) {
    process.stdout.write(JSON.stringify({ continue: true }));
    return;
  }

  const remaining = metrics.remaining_percentage;
  const used = metrics.used_pct;
  const tier = getTier(used);

  // Determine severity
  let severity = null;
  if (remaining <= CRITICAL_THRESHOLD) {
    severity = 'CRITICAL';
  } else if (remaining <= WARNING_THRESHOLD) {
    severity = 'WARNING';
  }

  if (!severity) {
    process.stdout.write(JSON.stringify({ continue: true }));
    return;
  }

  // Debounce: don't spam warnings
  const warnState = readWarnState(warnStatePath);
  warnState.toolUsesSinceWarn = (warnState.toolUsesSinceWarn || 0) + 1;

  const severityEscalated = severity === 'CRITICAL' && warnState.lastSeverity === 'WARNING';
  const debounceOk = warnState.toolUsesSinceWarn >= DEBOUNCE_TOOL_USES;

  if (!debounceOk && !severityEscalated) {
    writeWarnState(warnStatePath, warnState);
    process.stdout.write(JSON.stringify({ continue: true }));
    return;
  }

  // Estimate remaining iterations (~3% context per iteration)
  const estIterations = Math.max(1, Math.floor(remaining / 3));

  // Build warning message with behavioral tier instructions (GSD context-budget.md)
  let message;
  if (severity === 'CRITICAL') {
    message = [
      `⚠️ CONTEXT CRITICAL — ${remaining.toFixed(0)}% usable remaining (tier: ${tier.label}, ~${estIterations} iterations left)`,
      '',
      'STOP PROTOCOL (non-negotiable):',
      '1. STOP starting new iterations immediately',
      '2. Complete current iteration ONLY if near-done (< 2 steps left)',
      '3. Write experiment log + final report NOW',
      '4. Commit all current progress',
      '5. Do NOT read new files unless absolutely required for the report',
      '',
      'Degradation check — if ANY of these are true, you are already too late:',
      '- You skipped verification steps you would normally follow',
      '- You used vague language ("appropriate handling", "standard patterns") instead of specific code',
      '- Your last iteration had fewer steps than your first',
      '',
      'Context exhaustion = lost work. Every tool call costs ~0.5-1%. Finish and report.',
      '',
      '💡 HANDOFF: Tell the user to open a new chat with this starter:',
      '"On continue [chantier]. Lis docs/MINT_IDENTITY.md et MEMORY.md. Session précédente: [résumé]. Prochaine étape: [action]."'
    ].join('\n');
  } else {
    message = [
      `⚠️ CONTEXT WARNING — ${remaining.toFixed(0)}% usable remaining (tier: ${tier.label}, ~${estIterations} iterations left)`,
      '',
      'Behavioral adjustment (GSD DEGRADING tier):',
      '- Do NOT start exploratory reads or broad searches',
      '- Prefer targeted, single-file reads over multi-file exploration',
      '- Each iteration: diagnose → fix → verify → commit (no detours)',
      '- Plan your exit: at ~5 iterations left, write final report',
      '',
      'Degradation warning signs — STOP and assess if you notice:',
      '- Silent partial completion: claiming done but skipping verify steps',
      '- Increasing vagueness: "should work" instead of pasting test output',
      '- Skipped steps: iteration has 6 steps but you only report 4',
      '',
      'If ANY warning sign is present → write report NOW, do not start new iterations.'
    ].join('\n');
  }

  // Update warn state
  writeWarnState(warnStatePath, {
    lastWarnedAt: Date.now(),
    toolUsesSinceWarn: 0,
    lastSeverity: severity
  });

  // Output with additionalContext
  process.stdout.write(JSON.stringify({
    continue: true,
    hookSpecificOutput: {
      additionalContext: message
    }
  }));
}

main().catch(() => {
  process.stdout.write(JSON.stringify({ continue: true }));
});
