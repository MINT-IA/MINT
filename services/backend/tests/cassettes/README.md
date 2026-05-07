# VCR Cassettes — Anthropic LLM Replay Fixtures

**Phase 95 Plan 95-04 / TEST-05.** Closes doctrine 2026-05-06 §7 ship-gate item *"Banned-term + accent + PII lint over committed VCR cassettes"*.

This directory holds deterministic YAML cassettes recorded once against staging-live Anthropic and replayed thereafter. Tests opt in via `@pytest.mark.vcr_anthropic`. Cassettes are committed transparently — every contributor and reviewer can read them in PR diffs.

---

## Layout

```
services/backend/tests/cassettes/
  <test_module>/
    <test_function>.yaml
```

The path is enforced by `pytest-recording`'s default layout. The smoke test ships with one cassette at `test_anthropic_vcr_smoke/test_anonymous_chat_anthropic_roundtrip.yaml`.

---

## Recording protocol — authoring a NEW cassette

```bash
# 1. Pull the staging Anthropic key from 1Password (never committed).
export ANTHROPIC_API_KEY="$(op read 'op://Engineering/anthropic-staging/key')"
export STAGING_API_URL="https://mint-staging.up.railway.app/api/v1"

# 2. Set record mode and run the test that owns the cassette.
VCR_RECORD_MODE=once \
  python -m pytest services/backend/tests/test_anthropic_vcr_smoke.py \
                   -m vcr_anthropic -q

# 3. Manually verify the resulting YAML — eyeball pre-lint.
ls services/backend/tests/cassettes/<test_module>/
$EDITOR services/backend/tests/cassettes/<test_module>/<test_function>.yaml

# 4. Run the hygiene lint locally.
python3 tools/checks/cassette_hygiene_lint.py

# 5. Stage and commit.
git add services/backend/tests/cassettes/
git commit -m "test(<test_module>): record VCR cassette"
```

Per memory `feedback_app_targets_staging_always.md`, **never** record against a local backend — staging is the source of truth for what the model emits.

Per memory `feedback_blockers_ask_dont_defer.md`, if you cannot record live (no Anthropic key in env, no staging access), pause and ask Julien — do **not** silently commit a placeholder.

---

## Replay default — CI

```bash
# CI runs this implicitly via pytest. No env vars needed.
python -m pytest services/backend/tests/test_anthropic_vcr_smoke.py \
                 -m vcr_anthropic
```

Replay mode (`VCR_RECORD_MODE=none`) is the implicit default. Tests fail loud if the cassette is missing — they never reach for live Anthropic. This guarantees **$0/run replay cost** and **deterministic CI timing** (Plan 95-04 Experiment C: 3 consecutive runs identical within ±200 ms).

---

## Redact contract

Every cassette MUST be readable by humans without leaking secrets, PII, or internal request metadata. Defense-in-depth across three layers:

1. **`vcr_config.filter_headers`** in `tests/conftest.py` — strips `authorization`, `x-api-key`, `anthropic-api-key`, `anthropic-version`, `x-anonymous-session`, `cookie`, `set-cookie` to literal `REDACTED` before the cassette is written.
2. **`before_record_response` hook** in `tests/conftest.py` — recursively walks the JSON body and runs `app.services.privacy.pii_scrubber.scrub` on every string leaf. Drops `request-id` / `sentry-trace` / `baggage` headers entirely.
3. **`tools/checks/cassette_hygiene_lint.py`** — repo-level regex gate that fails CI if a committed cassette contains a JWT, an Anthropic API key (`sk-ant-api...`), an IBAN (`CH##...`), an AVS (`756.####.####.##`), an unredacted `authorization:` header value, or any banned term from `app.services.coach.compliance_guard.BANNED_TERMS` (FR + DE + IT). The lint is the authoritative ship-gate; the fixture hooks are belt-and-suspenders.

---

## Static fixture model

Cassettes are **static fixtures**:

- Recorded once on staging-live (or hand-authored stub for the initial scaffold).
- Committed to repo (binary-clean YAML, stable diff).
- Re-recorded on demand by contributors as Anthropic-calling tests grow.

Nightly drift detection lives at `.github/workflows/vcr_nightly_rewrite.yml` but **ships DISABLED at v2.14**. The workflow's top-of-file comment block holds the activation runbook (uncomment `schedule:`, flip `if: false` → `true`, ensure Anthropic budget cap on Railway). Cost at ship: **$0/mo**. Cost when activated: **~$45/mo Anthropic**. See doctrine §6 cost objection 1.

---

## When to add a new cassette

Add a `@pytest.mark.vcr_anthropic` test + cassette when:

- You ship a new code path that reaches Anthropic (coach turn, eclairage scoring, vision OCR LLM hand-off).
- You need to assert behaviour that is NOT covered by promptfoo evals (TEST-01) — promptfoo grades quality at the model boundary; VCR pins the *exact* response your code receives, so you can test client-side parsing, fallback paths, banned-term post-filter, etc.

Don't use VCR for:

- Prompt-quality grading — use promptfoo (TEST-01).
- Cross-archetype variance — use promptfoo datasets.
- Schema regression — use Pact (TEST-02).
