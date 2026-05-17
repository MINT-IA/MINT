# tests/scripts — manual capture utilities (Phase 92.5 CALC-03)

> Source decisions : CONTEXT 92.5 [D-11, D-12, D-13] (`.planning/phases/92.5-mvp-calc-rigor-foundations/92.5-CONTEXT.md`).

## Purpose

Manual / out-of-CI scripts that maintain the **frozen oracle fixtures** consumed by `services/backend/tests/test_estv_oracle.py`. These scripts are NOT run by CI ; they are run by Julien on a slow cadence (typically annual) and the resulting JSONL artefacts are committed.

## `capture_estv_oracle.py` — ESTV calculator scraper

Captures 50 `(input_profile, expected_tax)` vectors from `swisstaxcalculator.estv.admin.ch` per CONTEXT D-12 :

- 5 cantons : `ZH`, `VD`, `GE`, `BE`, `BS`
- 5 marital/income combos : `single_60k`, `single_100k`, `married_100k`, `married_150k`, `married_200k`
- 2 ages : `40`, `60`
- Total : **5 x 5 x 2 = 50 vectors**.

### Cadence

**Nov-Dec each year** when the ESTV publishes new tarifs (typically the December update for the following tax year). Re-capture is also triggered if the ESTV oracle pytest matcher (`test_estv_oracle.py`) starts FAILing — but the default presumption per CONTEXT specifics line 171 is that a divergence indicates a stale federal/cantonal constant in `app/constants/social_insurance.py`, NOT a stale ESTV vector. The freshness lint (`tools/checks/estv_oracle_freshness.py`) emits a WARN once any vector crosses the 14-month staleness threshold.

### Pre-requisites

```bash
cd services/backend
pip install ".[oracle]"
playwright install chromium
```

The `[oracle]` extra is intentionally NOT part of `[dev]` (CONTEXT D-11 — lean dev install ; Playwright is heavy).

### First-run scaffold

When the fixture file is empty (first commit lifecycle, per CONTEXT D-09 / 0-trust §9), generate 50 skeleton vectors with `expected_tax_chf = null` :

```bash
cd services/backend
python3 -m tests.scripts.capture_estv_oracle --scaffold-only \
  --output tests/fixtures/estv_oracle_2025.jsonl
```

This emits 50 lines with the locked matrix shape but no captured tax values. `test_estv_oracle.py` cleanly skips per-vector matchers when `expected_tax_chf` is null, so CI stays green until Julien drives a real capture.

### Real capture

```bash
cd services/backend
python3 -m tests.scripts.capture_estv_oracle \
  --output tests/fixtures/estv_oracle_2025.jsonl
```

Expected duration : ~5 min for 50 vectors (network-bound).

**First-run NOTE :** the form-filling logic in the script is intentionally a scaffold with `TODO(operator)` markers. On first invocation, open the ESTV SPA in Playwright Inspector via `page.goto(ESTV_URL); page.pause()` and replace the placeholder selector strings with the actual canton-dropdown / income-input / age-input / marital-radio selectors observed live on the SPA. This is by design — automated form filling on the ESTV SPA is brittle and hand-tuning is the explicit trade-off chosen in CONTEXT D-11.

### Failure modes

- **ESTV SPA down** — re-try later. The annual cadence has plenty of slack ; the freshness lint stays WARN-only per CONTEXT D-13 so CI does not flap.
- **ESTV captcha / anti-bot heuristic trips** — the user-agent string and `playwright-stealth` extra are the primary mitigations ; if the SPA blocks the headless run, try a headed `--scaffold-only` first (no captcha, no Playwright runtime needed) and capture vectors manually with a browser session, pasting numbers into the JSONL by hand.
- **DOM selector drift** — ESTV occasionally restructures the SPA. When the script's `TODO(operator)` selectors no longer match, re-inspect via `page.pause()` and re-tune. This is the « annual maintenance » cost we explicitly accept in CONTEXT D-11.

### Commit prefix

After capture, commit the resulting JSONL with the dedicated lifecycle prefix per CONTEXT D-10 :

```
fix(estv-oracle): re-capture 2026-12 ESTV publication cycle (50 vectors)
```

A dedicated prefix lets the freshness lint and audit log distinguish oracle re-captures from ordinary feature commits.

### 0-trust note (CLAUDE.md §9)

This script is a **scaffold**. The 50-vector populated fixture only exists after Julien drives a real capture session. The fixture file `services/backend/tests/fixtures/estv_oracle_2025.jsonl` is shipped EMPTY on first commit (CALC-03 plan 92.5-03) ; the pytest runner auto-skips per-vector matchers until vectors with non-null `expected_tax_chf` are present. We do NOT claim « ESTV oracle ready » without a real Julien-driven capture run.
