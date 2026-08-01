# MINT Next — Batch 2

Batch 2 proves one Vaud 2026 tax fixture. It does not build a new tax engine,
select a Batch 1 UX direction, or connect a result to the product.

The fixture starts from declared **taxable** ICC/IFD income. Gross salary is
deliberately absent because the official Vaud calculator requires taxable
income and a salary-to-taxable shortcut would manufacture personalization.

The official evidence is a canonical normalized JSON receipt, not a raw HTML
hash. Raw calculator pages contain mutable chrome. The opt-in replay below
reposts the two synthetic inputs and compares every normalized value. It is a
manual audit tool only: never CI, never a product API, and never evidence of a
licensed/supported Vaud integration. The counterfactual also assumes the
eligible 3a contribution is credited during tax year 2026.

Run:

```bash
python3 tools/checks/mint_next_batch2_guard.py --live-work-tracking
pytest -q tools/checks/tests/test_mint_next_batch2_guard.py
# Manual network evidence replay only:
python3 product/mint_next/batch2/evidence/verify_vd_calculator_receipt.py --live
```
