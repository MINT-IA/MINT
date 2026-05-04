#!/usr/bin/env node
// tool-usage-logger.js — Discipline 14 (tool discoverability) PostToolUse hook
//
// Appends one ISO-8601 line per tool invocation to .claude/usage/invocations.log
// in the canonical census id format (skill:NAME, bin:NAME, script:NAME, lint:NAME,
// mcp:SERVER). Other tools (Read/Edit/Write/Glob/Grep/...) are skipped to keep
// the log focused on what bin/tool-census.sh actually tracks.
//
// Format: "<ISO-8601 UTC> <census-id>\n"
// Example: "2026-05-04T08:30:00Z skill:autoresearch-i18n"
//
// Always exits 0; never blocks the tool call. Failures are silent.

const fs = require('fs');
const path = require('path');

const LOG_DIR = path.join(process.cwd(), '.claude', 'usage');
const LOG_FILE = path.join(LOG_DIR, 'invocations.log');

let input = '';

const stdinTimeout = setTimeout(() => process.exit(0), 5000);
process.stdin.setEncoding('utf8');
process.stdin.on('data', (chunk) => { input += chunk; });
process.stdin.on('end', () => {
  clearTimeout(stdinTimeout);
  try {
    const data = JSON.parse(input || '{}');
    const id = censusIdFor(data.tool_name, data.tool_input);
    if (!id) {
      process.exit(0);
    }
    fs.mkdirSync(LOG_DIR, { recursive: true });
    const ts = new Date().toISOString().replace(/\.\d{3}Z$/, 'Z');
    fs.appendFileSync(LOG_FILE, `${ts} ${id}\n`, 'utf8');
  } catch {
    /* never block on logger errors */
  }
  process.exit(0);
});

function censusIdFor(toolName, toolInput) {
  if (!toolName) return null;

  // MCP tool name format: mcp__<server>__<method>
  if (toolName.startsWith('mcp__')) {
    const parts = toolName.split('__');
    if (parts.length >= 2 && parts[1]) return `mcp:${parts[1]}`;
    return null;
  }

  if (toolName === 'Skill') {
    const skill = toolInput && (toolInput.skill || toolInput.skill_name || toolInput.name);
    if (typeof skill === 'string' && skill.length > 0) return `skill:${skill}`;
    return null;
  }

  if (toolName === 'Bash') {
    const cmd = toolInput && typeof toolInput.command === 'string' ? toolInput.command : '';
    return censusIdFromBashCommand(cmd);
  }

  // Skip Read/Edit/Write/Glob/Grep/Agent/Task/etc — too noisy and not in census surface.
  return null;
}

function censusIdFromBashCommand(cmd) {
  if (!cmd) return null;
  // Strip leading env-var assignments and `cd ...; ` prefixes by scanning words.
  // Look for the first token that points at a project script or python/bash invocation.
  // Order matters — match the most specific patterns first.

  // python3|python tools/checks/<name>.py  -> lint:<name>.py
  let m = cmd.match(/(?:^|[\s;&|])(?:python3?|ruff|pytest)\s+(?:-m\s+\S+\s+)?tools\/checks\/([\w.\-]+\.(?:py|sh|dart))\b/);
  if (m) return `lint:${m[1]}`;

  // bash tools/checks/<name>.sh
  m = cmd.match(/(?:^|[\s;&|])(?:bash|sh|zsh)\s+(?:\.\/)?tools\/checks\/([\w.\-]+\.(?:sh|py|dart))\b/);
  if (m) return `lint:${m[1]}`;

  // direct invocation: tools/checks/<name>
  m = cmd.match(/(?:^|[\s;&|])(?:\.\/)?tools\/checks\/([\w.\-]+\.(?:sh|py|dart))\b/);
  if (m) return `lint:${m[1]}`;

  // bash bin/<name>  or  ./bin/<name>
  m = cmd.match(/(?:^|[\s;&|])(?:bash|sh|zsh)\s+(?:\.\/)?bin\/([\w.\-]+)\b/);
  if (m) return `bin:${m[1]}`;
  m = cmd.match(/(?:^|[\s;&|])(?:\.\/)?bin\/([\w.\-]+)\b/);
  if (m) return `bin:${m[1]}`;

  // bash scripts/<name>  or  ./scripts/<name>
  m = cmd.match(/(?:^|[\s;&|])(?:bash|sh|zsh)\s+(?:\.\/)?scripts\/([\w.\-]+)\b/);
  if (m) return `script:${m[1]}`;
  m = cmd.match(/(?:^|[\s;&|])(?:\.\/)?scripts\/([\w.\-]+)\b/);
  if (m) return `script:${m[1]}`;

  // node .claude/hooks/<name>  -> meta hook, skip (would self-log forever otherwise)
  return null;
}
