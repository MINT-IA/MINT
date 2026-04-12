#!/usr/bin/env node
// Anti-shame + schema lint for tools/voice_corpus/frozen_phrases_v1.json
// Phase 5 Plan 02 — VOICE-02 (Krippendorff α frozen corpus)
//
// Mechanical gate for the 6 anti-shame checkpoints from
// feedback_anti_shame_situated_learning.md. Pure Node, no deps.
//
// Usage:
//   node tools/voice_corpus/lint_anti_shame.mjs [path/to/frozen_phrases_v1.json]
// Exit 0 on pass, 1 on failure (per-phrase report to stderr).

import { readFileSync, existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";

const __dirname = dirname(fileURLToPath(import.meta.url));
const DEFAULT_CORPUS = resolve(__dirname, "frozen_phrases_v1.json");
const corpusPath = process.argv[2] ? resolve(process.argv[2]) : DEFAULT_CORPUS;

const LEVELS = ["N1", "N2", "N3", "N4", "N5"];
const GRAVITIES = ["G1", "G2", "G3"];
const RELATIONS = ["new", "established", "intimate"];
const SENSITIVE_TOPICS = [
  "deuil",
  "divorce",
  "perteEmploi",
  "maladieGrave",
  "suicide",
  "violenceConjugale",
  "faillitePersonnelle",
  "endettementAbusif",
  "dependance",
  "handicapAcquis",
];
const LIFE_EVENTS = [
  "retirement",
  "housing",
  "marriage",
  "jobLoss",
  "birth",
  "inheritance",
  "tax",
  "debt",
];

// D-08 per-level distribution (sum = 10)
const EXPECTED_LIFE_EVENT_COUNTS = {
  retirement: 2,
  housing: 2,
  marriage: 1,
  jobLoss: 1,
  birth: 1,
  inheritance: 1,
  tax: 1,
  debt: 1,
};

const BANNED_TERMS = [
  { re: /\bgaranti(e|es|s)?\b/i, label: "garanti" },
  { re: /\bsans risque\b/i, label: "sans risque" },
  { re: /\bmeilleur(e|s|es)?\b/i, label: "meilleur" },
  { re: /\bparfait(e|s|es)?\b/i, label: "parfait" },
  { re: /\boptimale?s?\b/i, label: "optimal" },
  { re: /\bconseiller\b/i, label: "conseiller (use 'spécialiste')" },
  { re: /chiffre choc/i, label: "chiffre choc (legacy — use 'premier éclairage')" },
];

// Prescription without conditional softening.
// Flags "tu dois / il faut / tu devrais" UNLESS the same sentence contains a
// softener (pourrais, pourrait, envisager, peut-être, pourquoi pas, si tu veux).
const PRESCRIPTIVE_RE = /\b(tu\s+dois|il\s+faut|tu\s+devrais)\b/i;
const SOFTENER_RE = /\b(pourr?ais|pourrait|envisager|peut[-\s]?être|si\s+tu\s+veux|pourquoi\s+pas)\b/i;

// Non-breaking space enforcement: ! ? : ; % must be preceded by \u00a0
// (allow start-of-string and already-nbsp). We only flag an ASCII space or no
// space before the punctuation.
const BAD_NBSP_RE = /(?: )[!?:;%]/;

const errors = [];
function fail(id, msg) {
  errors.push(`  [${id}] ${msg}`);
}

if (!existsSync(corpusPath)) {
  console.error(`FATAL: corpus file not found: ${corpusPath}`);
  process.exit(1);
}

let doc;
try {
  doc = JSON.parse(readFileSync(corpusPath, "utf8"));
} catch (e) {
  console.error(`FATAL: cannot parse JSON: ${e.message}`);
  process.exit(1);
}

const phrases = Array.isArray(doc.phrases) ? doc.phrases : [];

// --- Global checks ---
if (phrases.length !== 50) {
  errors.push(`GLOBAL: expected 50 phrases, got ${phrases.length}`);
}

// Per-level counts
const byLevel = Object.fromEntries(LEVELS.map((l) => [l, []]));
for (const p of phrases) {
  if (LEVELS.includes(p.level)) byLevel[p.level].push(p);
}
for (const lvl of LEVELS) {
  if (byLevel[lvl].length !== 10) {
    errors.push(`GLOBAL: level ${lvl} has ${byLevel[lvl].length} phrases, expected 10`);
  }
}

// D-08 life-event distribution per level
for (const lvl of LEVELS) {
  const counts = {};
  for (const p of byLevel[lvl]) {
    counts[p.lifeEvent] = (counts[p.lifeEvent] || 0) + 1;
  }
  for (const [ev, expected] of Object.entries(EXPECTED_LIFE_EVENT_COUNTS)) {
    const got = counts[ev] || 0;
    // jobLoss is forbidden at N4/N5 (sensitive topic cap). Substitution allowed.
    if (ev === "jobLoss" && (lvl === "N4" || lvl === "N5")) continue;
    if (got < expected) {
      errors.push(
        `GLOBAL: level ${lvl} has ${got} ${ev} phrase(s), expected ≥ ${expected} (D-08)`
      );
    }
  }
}

// ID uniqueness
const ids = new Set();
for (const p of phrases) {
  if (ids.has(p.id)) errors.push(`GLOBAL: duplicate id ${p.id}`);
  ids.add(p.id);
}

// --- Per-phrase checks ---
const REQUIRED_FIELDS = [
  "id",
  "level",
  "lifeEvent",
  "gravity",
  "relation",
  "sensitiveTopic",
  "frText",
  "source",
  "rationale",
  "antiShameCheckpointsPassed",
];

for (const p of phrases) {
  const id = p.id || "(no id)";

  for (const f of REQUIRED_FIELDS) {
    if (!(f in p)) fail(id, `missing required field '${f}'`);
  }

  // id format N{1-5}-{001-010}
  if (p.id && !/^N[1-5]-0(0[1-9]|10)$/.test(p.id)) {
    fail(id, `id '${p.id}' does not match N{1-5}-{001-010}`);
  }
  if (p.level && !LEVELS.includes(p.level)) fail(id, `invalid level '${p.level}'`);
  if (p.gravity && !GRAVITIES.includes(p.gravity)) fail(id, `invalid gravity '${p.gravity}'`);
  if (p.relation && !RELATIONS.includes(p.relation)) fail(id, `invalid relation '${p.relation}'`);
  if (p.lifeEvent && !LIFE_EVENTS.includes(p.lifeEvent))
    fail(id, `invalid lifeEvent '${p.lifeEvent}'`);
  if (
    p.sensitiveTopic !== null &&
    p.sensitiveTopic !== undefined &&
    !SENSITIVE_TOPICS.includes(p.sensitiveTopic)
  ) {
    fail(id, `sensitiveTopic '${p.sensitiveTopic}' not in voice_cursor.json allowlist`);
  }

  // Anti-shame checkpoints must equal [1,2,3,4,5,6] exactly
  const cps = p.antiShameCheckpointsPassed;
  if (!Array.isArray(cps) || cps.length !== 6 || !cps.every((n, i) => n === i + 1)) {
    fail(id, `antiShameCheckpointsPassed must be [1,2,3,4,5,6]`);
  }

  // v0.5 §5 hard cap: sensitive topics forbidden at N4/N5
  if ((p.level === "N4" || p.level === "N5") && p.sensitiveTopic != null) {
    fail(id, `sensitiveTopic '${p.sensitiveTopic}' forbidden at ${p.level} (v0.5 §5 cap)`);
  }
  // v0.5 §3 relation cap: no 'new' relation at N4/N5
  if ((p.level === "N4" || p.level === "N5") && p.relation === "new") {
    fail(id, `relation 'new' forbidden at ${p.level} (v0.5 §3 relation cap)`);
  }

  // Banned terms
  const t = p.frText || "";
  for (const { re, label } of BANNED_TERMS) {
    if (re.test(t)) fail(id, `banned term '${label}' in frText`);
  }

  // Prescription without softener
  if (PRESCRIPTIVE_RE.test(t) && !SOFTENER_RE.test(t)) {
    fail(id, `prescriptive 'tu dois / il faut / tu devrais' without conditional softener`);
  }

  // Non-breaking space before ! ? : ; %
  if (BAD_NBSP_RE.test(t)) {
    fail(id, `missing non-breaking space (\\u00a0) before ! ? : ; or %`);
  }

  // Source format
  if (p.source && !/^(mined:|fresh:phase-5-plan-02$)/.test(p.source)) {
    fail(id, `source '${p.source}' must start with 'mined:' or equal 'fresh:phase-5-plan-02'`);
  }
}

// --- Report ---
if (errors.length === 0) {
  console.log(`OK: 50/50 phrases pass anti-shame checkpoints`);
  console.log(
    `     distribution: ${LEVELS.map((l) => `${l}=${byLevel[l].length}`).join(", ")}`
  );
  process.exit(0);
} else {
  console.error(`FAIL: ${errors.length} issue(s) in ${corpusPath}`);
  for (const e of errors) console.error(e);
  process.exit(1);
}
