# Journey Priority Rubric

Journey OS chooses work by falsifiable priority, not by intuition.

Each record carries a `priority` object. Scores use integers from `0` to `5`.
The generated priority score is:

```text
trust_blast_radius
+ release_blocker_weight
+ user_frequency
+ evidence_gap
+ route_centrality
+ compliance_risk
+ learning_value
- proof_cost
```

T0 journeys must score at least `15` and include a concrete `rationale`.

## Criteria

| Field | Meaning |
|---|---|
| `trust_blast_radius` | How badly Mint trust breaks if the journey fails. |
| `release_blocker_weight` | Whether beta/release should stop without this proof. |
| `user_frequency` | Expected frequency or entry-path importance. |
| `evidence_gap` | Missing/red proof raises priority; strong recent proof lowers it. |
| `route_centrality` | How many core routes/surfaces depend on it. |
| `compliance_risk` | Legal, privacy, LSFin, or data-control exposure. |
| `learning_value` | Whether proving it teaches reusable system truth. |
| `proof_cost` | Cost/risk to produce durable evidence; this subtracts from priority. |

## Decision Rule

- A `missing` or `red` T0 beats a `partial` T0 when scores are close.
- A new T0 must explain why it beats or joins the existing T0 set.
- A product PR should pick the highest-scoring `missing` or `red` T0 unless
  the PR description names the explicit override.
- A journey with no durable evidence is a priority hypothesis, not a proven
  operating fact.
