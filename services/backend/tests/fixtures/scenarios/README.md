# Scenario Fixtures

## Property Transmission Freshness

`property_transmission_raiffeisen.json` is the canonical Phase 1 runtime
fixture for the Raiffeisen article case. Its input provenance intentionally
uses `source_date: null` so backend, mobile, Maestro, and the scorecard exercise
the degraded freshness branch: `missing_source_dates`.

`property_transmission_raiffeisen_source_dates.json` is the companion happy-path
freshness fixture. It carries explicit source dates and must keep exercising
`current_source_dates`.

Do not "fix" the primary fixture by adding source dates unless the runtime proof
is intentionally moved to the happy-path freshness contract in the same change.
