# Plan 65 — Coach CHF Format Sweep

## Goal
Remove the remaining raw CHF interpolations found in coach-visible and coach-injected surfaces.

## Why
Plan 63 proved the runtime budget and 3a opener are now sane. Plan 64 fixed Budget Vivant amounts in the LLM context. A follow-up grep still found three raw CHF paths:

- `ContextInjectorService` EVI uncertainty line
- `RetirementHeroZone` delta since last visit
- `MicroActionCard` annual estimated impact

These paths should use the same CHF formatter as the rest of Mint.

## Scope
- Formatting only.
- No financial formula changes.
- Add tests first for the visible strings and injected context.

## Verification
- Focused Flutter tests for context and widgets.
- Flutter analyze on touched files.
- Source grep for raw CHF interpolation in coach paths.
- Wiki/compliance text lint.
- Commit and CI watch.
