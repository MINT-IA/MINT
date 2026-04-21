-- Phase 30.5 Plan 01 (CTX-02) — drift.db schema
-- Source: 30.5-RESEARCH.md §Code Examples Example 2 (verbatim)
-- Storage: SQLite local at .planning/agent-drift/drift.db (gitignored per D-10)

CREATE TABLE IF NOT EXISTS sessions (
  session_id    TEXT PRIMARY KEY,
  started_at    INTEGER NOT NULL,
  transcript    TEXT NOT NULL,
  total_input_tokens  INTEGER,
  total_output_tokens INTEGER,
  total_cache_creation INTEGER,
  total_cache_read     INTEGER
);

CREATE TABLE IF NOT EXISTS commits (
  sha          TEXT PRIMARY KEY,
  author       TEXT NOT NULL,
  committed_at INTEGER NOT NULL,
  subject      TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS violations (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  sha          TEXT NOT NULL,
  lint         TEXT NOT NULL,
  file_path    TEXT,
  line_number  INTEGER,
  snippet      TEXT,
  detected_at  INTEGER NOT NULL,
  FOREIGN KEY (sha) REFERENCES commits(sha)
);

CREATE TABLE IF NOT EXISTS context_hits (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  session_id   TEXT NOT NULL,
  hit_type     TEXT NOT NULL,
  rule_id      TEXT,
  tool_use_index INTEGER,
  detected_at  INTEGER NOT NULL,
  FOREIGN KEY (session_id) REFERENCES sessions(session_id)
);

CREATE TABLE IF NOT EXISTS golden_runs (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  run_at       INTEGER NOT NULL,
  prompt_id    INTEGER NOT NULL,
  turns_to_correct INTEGER,
  passed_lints TEXT,
  failed_lints TEXT,
  output_excerpt TEXT
);
