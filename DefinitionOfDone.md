# Definition of Done — Mint

A feature or PR is considered "Done" if:

- **Quality & Standards**:
  - Backend: `ruff check .` passes.
  - Mobile: `flutter analyze` passes.
  - Code follows project standards (linting, modular structure).

- **Verification & Tests**:
  - Backend: `pytest -q` passes.
  - Mobile: `flutter test` passes.
  - Financial calculations are covered by unit tests.

- **Documentation & Contracts**:
  - Vision documents updated (if applicable).
  - `mint.openapi.yaml` + `SOT.md` updated and perfectly synchronized.

- **Compliance & Security**:
  - **LEGAL_RELEASE_CHECK.md must pass.**
  - No secrets committed.
  - No sensitive logs (financial data, private IDs).
  - Read-Only MVP respect confirmed.

- **Completion**:
  - Walkthrough.md updated with proof of work (screenshots/recordings).
  - ADR created if major structural decisions were made.
