# MINT promptfoo eval suite — Phase 95 Plan 95-01 (TEST-01)

Real, code-graded LLM eval gate. **160 prompts × 4 archetypes** run
against Railway staging Anthropic Sonnet 4.5 on every PR matching
`services/backend/evals/**` or `services/backend/app/services/coach/**`.

Closes doctrine [W2 — Code-graded LLM evals](../../../.planning/decisions/2026-05-06-test-theater-post-mortem-doctrine.md)
and [TEST-01](../../../.planning/REQUIREMENTS.md).

## Doctrine §3 — author-and-grade-same-session banned

The single most important property of this suite is the **physical split**
between prompt-authoring and assertion-authoring:

| Directory                  | Authored in   | Lint guard                                                 |
|----------------------------|---------------|------------------------------------------------------------|
| `evals/datasets/**`        | one PR (this) | `tools/checks/no_same_pr_prompts_and_assertions.py`        |
| `evals/assertions/**`      | a later PR    | same lint — fails CI if a single PR touches both           |

The lint runs on every PR and exits non-zero if `git diff --name-only
origin/<base_ref>...HEAD` returns paths under both directories,
*unless* the most recent commit body contains a `[doctrine-override:
<reason>]` token (escape hatch for cross-cutting refactors).

Why: for 5 months the « walker GREEN » signal was theatre because
fixtures and assertions were authored by the same agent in the same
session. Splitting authorship by PR (and ideally by agent) makes that
class of self-grading impossible.

## 4 archetypes (must match `coach_profile.dart` enum)

| Slug                       | Maps to                | Locale axis | Why chosen                                          |
|----------------------------|------------------------|-------------|-----------------------------------------------------|
| `julien_swiss`             | `swiss_native` VD/GE   | fr/de       | Default Swiss employee w/ LPP                        |
| `lauren_expat_us`          | `expat_us`             | fr/en       | FATCA handoff path — 30 trigger-phrase variants     |
| `sofia_ticino_it`          | `swiss_native` TI      | it/fr       | Italian-locale Swiss + frontalier IT                 |
| `kai_independent_no_lpp`   | `independent_no_lpp`   | de/fr       | Stresses « no LPP » branch of FRI calculator        |

## Prompt distribution (160 total)

```
                       eclairage  coach  simulators  banned  fatca  total
julien_swiss               10       10        8         5      —     33
lauren_expat_us            10       10        6         5     30     61
sofia_ticino_it            10       10        8         5      —     33
kai_independent_no_lpp     10       10        8         5      —     33
                                                                    ───
                                                                    160
```

Lauren's simulator count is trimmed to 6 (instead of 8) to absorb the
+30 FATCA file and land at exactly 160.

## Local invocation

```bash
# install (npm-global; promptfoo is node-based)
npm install -g promptfoo@0.x   # version pinned in workflow after first CI green

# run against staging (Railway env vars required)
export STAGING_API_URL=https://mint-staging.up.railway.app/api/v1
export ANTHROPIC_API_KEY=$STAGING_ANTHROPIC_KEY  # NEVER commit this

cd services/backend/evals
RUN_ID=$(date +%s) promptfoo eval --config promptfooconfig.yaml \
    --output runs/$RUN_ID.json
```

## Cost ledger

| Item                                | Value               |
|-------------------------------------|---------------------|
| Expected $ / run                    | ~$1.92              |
| Hard cap (CI fails above)           | $2.50               |
| Frequency on PRs                    | path-filtered only  |
| Nightly cron                        | **DISABLED at ship**|
| Monthly cost at ship                | **$0 / mo**         |

Activation of the nightly cron requires (a) Julien's manual flag flip in
`.github/workflows/promptfoo_eval.yml` and (b) an Anthropic budget alert
on Railway / Anthropic console. Doctrine §6 objection 1 mitigation.

## SOT references (text-only — never SHA-pinned)

Assertion authors (separate PR) should reference these symbolic names,
not commit SHAs (so they cannot rationalize their assertions against
the prompt fixtures' history):

* `services/backend/app/services/coach/compliance_guard.py:BANNED_TERMS`
* `services/backend/app/services/coach/doctrine_checks.py:EXPAT_US_HANDOFF_TRIGGERS`
* `apps/mobile/lib/services/financial_core/social_insurance.dart:pilier3aPlafondAvecLpp`
* `apps/mobile/lib/services/financial_core/social_insurance.dart:pilier3aPlafondSansLpp`

## SOT-sync drill (when `compliance_guard.BANNED_TERMS` changes)

1. Open a Python REPL in `services/backend/`.
2. `from app.services.coach.compliance_guard import ComplianceGuard; print(ComplianceGuard.BANNED_TERMS)`
3. Copy the list verbatim into `evals/assertions/banned_terms.yaml`
   under the documented `not-contains-any` block.
4. Open the regenerate as a stand-alone PR — **do not** bundle with
   prompt-fixture changes (doctrine §3).
