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

## DEF-2 — Pre-existing accent-lint violations in coach_orchestrator.dart

- **File:** `apps/mobile/lib/services/coach/coach_orchestrator.dart`
- **Lines:** ~125, 133, 139
- **Flag:** `accent_lint_fr` reports `\beclairage\b -> éclairage` in doc comments
  referencing the `MINT_E2E_FORCE_ECLAIRAGE_KIND` dart-define (E2E walker var).
- **Why deferred:** Pre-exists in HEAD (`67d0119`) — confirmed via
  `git show HEAD:…coach_orchestrator.dart | accent_lint_fr`. The token mirrors
  an UPPER_SNAKE dart-define identifier (`ECLAIRAGE_KIND`); "fixing" the comment
  to `éclairage` would desync it from the code symbol. Out of scope for the
  Codex grounding-stack review. My fix_2 changes added zero accent violations.
