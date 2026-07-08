# G3 Claude CLI Audit — 2026-07-08

Command:

```bash
claude -p --model opus --effort max < /tmp/mint_g3_audit_prompt.txt
```

Verdict: **NO-GO as written**.

Claude agreed the G3 direction is the right next product slice after the infra gates, but found four blockers in the first spec draft:

1. Confirming a stale value through `mergeAnswers()` would be a facade because the method does not advance or persist `dataTimestamps`; the same stale card would reappear.
2. Freshness must be evaluated on field paths (`salaireBrutMensuel`, `canton`, `age`), not raw wizard keys (`q_*`).
3. Birth year is static identity data and must never decay into a stale reconfirm ask.
4. The proposed `freshnessConfirm` / `freshnessStale` i18n reuse claim is false; real ARB keys must be added.

Required implementation shape from the audit:

- Add a small provider method, preferably `confirmFreshness(...)`, that writes through the provider and persists the advanced field-path timestamp.
- Add only a minimal `DataQuest` model/service for `collect` and `reconfirm`; no Case registry in this slice.
- Classify missing values from answer presence/user-provided evidence, but classify staleness from field-path timestamps.
- Render exactly one reconfirm card above the existing revenue collector.
- Keep the first implementation to salary and canton stale checks; birth year remains collect-only if missing.

Required anti-facade tests:

- annual stale field becomes `AskMode.reconfirm`;
- fresh annual field produces no ask;
- static birth-year path never produces a reconfirm ask;
- after confirm, the classifier returns no ask for that field;
- the advanced timestamp survives reload through `_coach_data_timestamps`;
- the `/data-block/revenu` widget shows one stale card and removes it after confirm.
