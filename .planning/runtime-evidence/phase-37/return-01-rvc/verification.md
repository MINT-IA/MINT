# G1-RETURN-01 RVC LPP bounded verification

## Verdict

**Bounded atom: PASS. Global G1-RETURN-01: still `ticket_only`. Global G1: NO-GO.**

## Exact runtime

Source SHA: `bc839242abc3e2c376363359cd77994355d77190`.

The canonical simulator runner completed with `patrolResult=passed` and
`maestroResult=passed`. Patrol executed one native journey with zero failures
and asserted:

1. real RVC → IndicatifBanner → LPP DataBlock navigation;
2. typed opaque `scanReturnId` only at `/scan`;
3. exact linked `{scanSessionId, scanReturnId}` at Review and Impact;
4. exact synthetic certificate SHA;
5. canonical LPP write-back CHF 143'287.50 replacing seed CHF 350'000;
6. exact-once intent consumption and literal `/rente-vs-capital` return.

Maestro and simctl captured the final returned screen independently. Both PNGs
were inspected at original resolution; see `visual-review.md`.

## Supporting gates

- full Mint Doctor: PASS immediately before the accepted runtime;
- focused Flutter runtime contracts: PASS (2 structural + native wrapper skip);
- RVC origin suite: 52 pass + 1 intentional native skip;
- RVC Review/Impact suite: 54/54 pass;
- focused Flutter analyze: no issues;
- runtime orchestrator contract: 2/2 pass;
- Opus code first pass, Sonnet code rerun, Opus code final confirmation and
  Opus product-domain audit: PASS, no unresolved P0/P1.

The bounded proof does not cover all six P0 loop save/cancel/error exits, so it
cannot promote the registry row or change the 24/31 inventory.
