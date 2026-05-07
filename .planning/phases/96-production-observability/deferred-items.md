# Phase 96 — Deferred Items

## Out-of-scope discoveries during Plan 96-03

### `test_compliance_wording.py::test_no_banned_words` pre-existing self-flag

- **Discovered:** 2026-05-07 during Plan 96-03 full-suite pre-push run.
- **Surface:** `services/backend/app/api/v1/endpoints/anonymous_chat.py:169`
- **Cause:** the discovery-prompt system instruction enumerates the banned LSFin
  vocabulary (« garanti », « optimal », ... ) as a META prompt to the LLM
  (« Vocabulaire LSFin interdit : ... »). The lint scans for those exact
  substrings and trips on the meta-prompt. Pre-existing on `main` — confirmed
  via `git stash` round-trip; last touched in commit `cb5a8bdc` (Phase 94-01).
- **Why deferred:** out of Plan 96-03 scope (the prompt's file-surface limits
  Plan 96-03 to `sentry_audit_tags.py` + helper plumbing + tests). Fixing the
  lint regex to allow « banned-word lists when prefixed by ‘interdit’ » is a
  Phase 94-XX or 95-XX follow-up.
- **Suggested fix:** extend `tools/checks/...` (or whatever drives
  `test_compliance_wording.py`) to skip lines matching the
  ``interdit\s*:\s*« .* »`` enumeration pattern, OR move the meta-prompt
  vocabulary list out of the f-string and into a pure constant referenced
  by name.
- **Counts:** 2 violations, 1 file. Does NOT affect /coach/chat or
  /anonymous/chat behaviour at runtime — it is a static-text lint failure
  on the prompt template itself.
