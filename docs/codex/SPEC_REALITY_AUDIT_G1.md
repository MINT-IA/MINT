# G1 Spec Reality Audit

Audit date: 2026-07-07
Code baseline: `095eeaa32` on `claude/mint-swiss-coach-eu33i7`
Scope: the five `docs/codex` specs challenged against live code before product coding.

## Verdict

The five specs are the right architecture direction for Mint, but several claims were product targets, not live code. G1 corrects that drift and makes the corrected reality executable.

## Main Gaps

- `WIRING_GRAPH` I-1 is false: `/scan/review`, `/scan/impact`, `/rapport`, and `/confidence` still carry domain objects or maps through `state.extra`.
- I-2 is partial: scan routes still fall into `Document non disponible`; `/rapport` has persisted fallback but no timeout/error state.
- I-3 is false as written: `save_fact` is not the only sanctioned profile write path.
- I-4 is verified debt: Budget, Document, Household, FinancialPlan, and Timeline remain provider islands.
- I-5 is partial: legacy `ProfileProvider` still has 5 live consumers.
- Data Ledger: 18 backend-writable keys are ineffective locally, 11 unmapped plus 7 mapped to wizard keys that `CoachProfile.fromWizardAnswers` does not read.
- `DataQuest`/`Case` does not exist in code yet; biography/freshness primitives do.
- Maestro setup is partial: only F-2 is checked in, iOS has the `mint` URL scheme, Android lacks the intent-filter.

## Next Mechanical Correction

Start with ledger parity. Until backend facts reliably land in `CoachProfile`, Data Quest, Maestro, and simulator UX will all produce misleading confidence.
