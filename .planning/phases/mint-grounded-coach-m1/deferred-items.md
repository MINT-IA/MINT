# Deferred items — mint-grounded-coach-m1 (Codex post-review gap closure)

Out-of-scope discoveries logged during the Codex grounding-stack gap closure
(plans 01-05). Per the executor SCOPE BOUNDARY rule, these are NOT fixed here.

## DEF-1 — Pre-existing accent-lint violations in anonymous_chat.py

- **File:** `services/backend/app/api/v1/endpoints/anonymous_chat.py`
- **Lines (post-fix_6):** ~524, 526, 537
- **Flag:** `accent_lint_fr` reports `\beclairage\b -> éclairage` on the Python
  local variable name `eclairage` (bound to `EclairagePayload`).
- **Why deferred:** Pre-exists in HEAD (`67d0119`) — confirmed via
  `git show HEAD:…anonymous_chat.py | accent_lint_fr`. It is an identifier, not
  a user-facing string. Renaming touches the Premier-Éclairage payload contract
  (Phase 71b) which is outside the Codex grounding-stack review scope.
- **Suggested owner:** a focused accent-hygiene pass on the EclairagePayload
  variable naming, separate from the grounding fixes.
