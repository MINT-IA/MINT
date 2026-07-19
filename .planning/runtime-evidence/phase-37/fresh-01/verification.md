# G1-FRESH-01 verification

Accepted implementation SHA:
`32bec6a6af16c0198663e11f2799e55a0d5e9426`

- Ticket decision: **GREEN — bounded technical core**
- G1 score and decision: **8.2/10 — NO-GO**
- G2/G3 decision: **forbidden**
- Production activation: **not claimed**

## TDD and non-vacuous evidence

The implementation followed RED→GREEN locally. The first contract RED was a
compile-contract failure while the new API did not yet exist, so it is not
misrepresented as a Phase 37 semantic RED. Promotion instead uses the contract's
`baseline_green_controlled` mode:

- CONTROL on a physical archive of the accepted SHA: one isolated threshold
  mutation (`0.60` → `0.90`) made the identical command finish **31 passed / 2
  semantic failures**. Annual day 782 and volatile day 247 were wrongly stale.
- GREEN on the unmodified physical archive: the identical command passed
  **33/33**.
- The disposable mutation never touched the working tree or Git history.

Machine evidence: `control.json` and `green.json`.

## What the GREEN closes

- Exact matrix-derived registry: **61 generic policies + 4 specialist
  references**, with no tier conflict.
- Static/event-static have no calendar TTL; annual is current/stale at 782/783
  days; volatile at 247/248 days.
- Missing/future timestamps and unknown path/source/category fail closed while
  preserving the previous value.
- Certificate-only fields require evidence renewal; mixed-source fields can be
  reconfirmed as user input; `sourceDate` never refreshes `updatedAt`.
- The existing provider performs a same-value provenance restamp and preserves
  it over cold reload.
- The real Frontier consumer uses the canonical adapter.
- The document-scan writer delegates to the canonical tier SOT; its contradictory
  private tax/mortgage table is gone.

## Local, GitHub and Vercel clean-room proof

- Biography + document-scan affected suite: **349/349**.
- Repository contracts: **448/448**.
- Flutter analyze, repo-only Doctor, Mermaid render guard, Patrol tooling guard
  and Lefthook: **PASS**.
- GitHub Actions exact-SHA run
  [29679202008](https://github.com/MINT-IA/MINT/actions/runs/29679202008):
  **SUCCESS**, including Flutter services/screens/widgets, backend, repository
  contracts and final CI Gate.
- Duplicate run `29679201753` was canceled by concurrency; it is retained as a
  cancellation, not relabeled as a build failure.
- Vercel deployment `CoKhYfhxC8CE3xsG42EfCoZBwmNH`: **PASS**.

No new screen or route exists in this slice, so no new Maestro/Patrol journey is
claimed. The existing Frontier product caller and Patrol tooling guard are the
bounded runtime/wiring evidence.

## Claude wrapper audit lineage

All runs used `tools/checks/claude_external_audit.sh`:

1. Opus/high first pass: PASS, P0=0/P1=0; identified nonblocking dead-code and
   coverage notes.
2. Sonnet/high same-gate rerun: NO-GO with one real P1 — the scan writer's
   private table inverted tax and mortgage tiers.
3. The P1 was fixed TDD-first by canonical delegation.
4. Opus/high final code confirmation: PASS, P0=0/P1=0.
5. Opus/high product-domain: PASS, P0=0/P1=0.

The manifest accepts exactly the final code Opus and product-domain Opus runs;
the earlier lineage remains checked in for traceability, not as duplicate
accepted runs.

## Remaining boundary

This promotion closes only `G1-FRESH-01`. Fifty-eight generic policies still
lack a product reconfirmation surface, the Biography legacy annual default
remains a P2, and no G2 UI has been started. The canonical inventory becomes
**23 GREEN / 7 `ticket_only` / 1 `red_proven`**: **8 G1 hard floors remain
open**. G1 stays **8.2/10 — NO-GO**; G2 and G3 remain forbidden.
