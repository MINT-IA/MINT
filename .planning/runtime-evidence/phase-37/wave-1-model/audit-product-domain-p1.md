---
mode: product-domain
model: opus
effort: high
command: CLAUDE_AUDIT_MAX_DIFF_LINES=4500 tools/checks/claude_external_audit.sh product-domain 3397d48b2
base_sha: 3397d48b2a71fd037766b7126c7f3cbb7af5a19b
head_sha: ef80e8cb80ca7908518d3ed9d46a4f0ff9cbafef
exit_code: 0
textual_verdict: PASS
gate_verdict: FAIL
accepted: false
unresolved_p0: 0
unresolved_p1: 3
p2: 3
---

# MINT External Audit — Product/Domain P1 Findings

The wrapper process exited 0 and the external auditor wrote `PASS`, but this
run is **not accepted** because its own report contains three unresolved P1
findings. Phase 37 requires zero unresolved P0/P1/critical/high findings.

## P1 findings

### P1-1 — User-estimated AVS gaps stamped `certificate`

`coach_profile.dart` unconditionally infers
`prevoyance.lacunesAVS = ProfileDataSource.certificate` whenever the value is
non-null. After this slice, `avsGaps` can be derived from wizard answers such as
`arrived_late`, `q_avs_years_abroad`, or explicit `no_gaps`; those values do not
come from a certificate.

Synthetic reproduction:

```text
fromWizardAnswers({
  'q_avs_lacunes_status': 'lived_abroad',
  'q_avs_years_abroad': 4,
})
```

This yields `lacunesAVS = 4` with a certificate-grade data source. The auditor
classifies that confidence as unjustified for a user estimate. Wizard-derived
gaps must retain their actual `userInput` source; `certificate` is reserved for
confirmed certificate/scan data.

### P1-2 — Typed fields have no production consumer

`pillar3aAnnualContribution`, `monthlySavingsContribution`, `hasPillar3a`, and
`avsGapStatus` are serialized and tested but are not read by production code.
Existing flows still read `plannedContributions`, `contribution3a`,
`prevoyance.nombre3a`, or `prevoyance.lacunesAVS`. A direct `copyWith` write can
therefore diverge from the older reader path. This is a facade-without-wiring
finding and blocks promotion while the typed fields remain unread.

### P1-3 — G1 matrix points canonical paths at unread fields

The G1 ledger matrix now names the four typed fields as canonical paths while
its live reader evidence still resolves through the older paths. The registry
and production code disagree about which field is actually consumed, so the
hard-floor real-consumer predicate is not met.

## P2 findings

1. Mortgage quarantine correctly returns unknown at model level, but the
   consuming housing/net-worth path must visibly ask the user to confirm the
   conflicting mortgage value rather than silently omit debt.
2. The current AVS gap start approximation uses `birthYear + 21`; the auditor
   notes the contribution obligation begins on 1 January after the twentieth
   birthday, creating an approximately one-year conservative offset.
3. `lived_abroad` years are treated one-for-one as AVS gaps. EU/AELE and other
   coordination cases require an estimate label rather than a certified fact.

## Positive domain changes retained

- Fabricated AVS gap defaults were removed.
- `no_gaps` is distinct from unknown.
- `unemployed`/`chomage`/`chômage` no longer fall back to salaried status.
- Display defaults no longer become known facts.
- Conflicting mortgage values quarantine instead of using map order.
- One canonical profile mutation has an exact-once recompute proof.

## Gate verdict

**FAIL — unresolved P1 = 3.** No audit manifest, ticket promotion, Phase 37-02
completion, or G2 authorization is permitted from this run.
