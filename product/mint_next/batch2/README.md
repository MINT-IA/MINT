# MINT Next — Batch 2

Batch 2 proves one Vaud 2026 tax fixture. It does not build a new tax engine,
select a Batch 1 UX direction, or connect a result to the product.

The fixture starts from declared **taxable** ICC/IFD income. Gross salary is
deliberately absent because the official Vaud calculator requires taxable
income and a salary-to-taxable shortcut would manufacture personalization.

Run:

```bash
python3 tools/checks/mint_next_batch2_guard.py --live-work-tracking
pytest -q tools/checks/tests/test_mint_next_batch2_guard.py
```
