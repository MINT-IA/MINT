# Slice 01 — Contract Before Code

## Goal

Lock the Mint 2.0 first-experience contract before implementation.

This slice deliberately writes no product code. It exists because the previous failures were not isolated widget bugs; they were contract failures:

- no clear live vs future axes;
- no rule for when to ask sensitive or rare questions;
- no hard gate against naked numbers;
- no iPhone 13 mini layout proof;
- no persistent answer/dossier model visible to the user.

## Deliverables

- `mint-2-0-first-experience-rente-capital-CONTEXT.md`
- `PLANS.md`
- `STATE-TABLE.md`
- `golden-onboarding-archetypes.md`
- `mint-2-0-first-experience-rente-capital-VERIFICATION.md`
- `mint-2-0-first-experience-rente-capital-SUMMARY.md`
- `VERIFICATION-REPORT.html`

## User Contract

On first open, the user must understand:

1. Mint helps them build a Swiss financial dossier.
2. Three areas exist: rente/capital, logement, impact fiscal.
3. Only rente/capital is active in this phase.
4. Mint asks for a field only when it changes the next answer.
5. Any number shown has a visible reason and provenance.
6. The user can continue, save, start over, or leave.

## First Flow Contract

Initial state:

- fresh install or reset local state;
- no account required;
- no prior dossier assumed;
- no Keychain-persisted secret trusted without reset checks.

Flow:

1. Landing or first screen frames Mint as dossier/navigation, not generic chat.
2. Three axes are visible.
3. User chooses `2e pilier : rente ou capital`.
4. Mint explains required data before asking:
   - age or birth date because retirement timing depends on it;
   - canton/tax residence only if the next answer needs it;
   - LPP amount or range only if the result needs a user-provided figure.
5. Mint shows readiness:
   - enough for education;
   - enough for estimate;
   - missing for amount.
6. Mint shows either:
   - qualitative answer with missing fields; or
   - personalized amount/range with provenance.
7. Dossier records the answer and can be revisited.

## Refusal Rules

- No FATCA/US tax screen before it is relevant.
- No default LPP amount.
- No replacement-rate number without a calculation source and required inputs.
- No account prompt before value.
- No clipped controls or text on iPhone 13 mini.
- No "later" axis collecting detailed data before it has an active use.

## Required Reviews

- Codex review: file-level diff, consistency with `docs/MINT_AGENT_WORKFLOW.md`, no public-doc legal admission.
- Claude CLI review: adversarial review of this phase contract before product code.
- Engram: save the workflow and Mint 2.0 phase decision with stable topic keys.

## Verification

Planning-only checks:

```bash
git diff --check -- docs/MINT_AGENT_WORKFLOW.md .planning/phases/mint-2-0-first-experience-rente-capital
python3 tools/checks/no_legal_admission_in_public_docs.py --paths docs/MINT_AGENT_WORKFLOW.md .planning/phases/mint-2-0-first-experience-rente-capital
python3 tools/checks/accent_lint_fr.py --file docs/MINT_AGENT_WORKFLOW.md
```

Product-code checks start in Slice 2.
