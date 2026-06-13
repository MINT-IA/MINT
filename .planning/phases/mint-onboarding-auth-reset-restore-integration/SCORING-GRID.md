# Scoring Grid

Goal: prove the structured path beats the `chat vide` baseline without turning
Mint into personalized financial advice.

Protocol: a reviewer distinct from the implementer scores baseline first, then
structured path. Each fixture gets screenshots or `idb ui describe-all`. G2
human separately validates readability and cognitive load.

Binary criteria:

| Criterion | Pass | Fail |
|---|---|---|
| Intention detected | Main event/intent is reflected without free-text guessing | Empty input or unrelated choice |
| Data state visible | Anonymous/connected and local retention are visible | Data status hidden |
| Next action clear | Continue, create account, restart, or exit is obvious | Competing/no CTA |
| No personal advice | Educational text and `check_banned_terms` clean | Action is recommended or framed as pertinent for the user |
| Amount provenance | Any amount has `financial_core` L1 or backend L2-L4 trace | Plausible number without engine trace |
| Exit/reset accessible | Exit/restart visible without trap | User is stuck |
| Readability | Text fits, simple vocabulary, no dense block | Truncation, overlap, jargon |
| Low cognitive load | G2 understands in under two minutes | User must infer app architecture |

Critical fixtures: all 8 canonical archetype fixtures plus the insufficient-data
fixture in `golden-onboarding-archetypes.json`; any fixture can opt out only with
`critical:false` and reviewer approval. Pass threshold: every critical fixture
must pass every binary criterion, beat baseline by at least 3 points, and always
pass `No personal advice`, `Amount provenance`, and `Exit/reset accessible`.
Insufficient data stays qualitative.
