# Summary 43 — 3a semantic copy lint

## Outcome

Mint now blocks ARB copy that presents the 3a contribution ceiling as a tax
saving.

## Changes

- New lint and self-test in `tools/checks/`.
- New pre-commit hook and CI workflow.

## Verification

- Red test first: missing lint script failed as expected.
- `python3 tools/checks/test_no_3a_ceiling_as_tax_saving.py`
- `python3 tools/checks/no_3a_ceiling_as_tax_saving.py`
- `python3 tools/checks/test_banned_terms_arb.py`
- `python3 tools/checks/banned_terms_arb.py`
- `python3 tools/checks/arb_parity.py`
- `lefthook run pre-commit --job no-3a-ceiling-as-tax-saving-gate --file apps/mobile/lib/l10n/app_fr.arb --force`
- YAML parse check for workflow and `lefthook.yml`
