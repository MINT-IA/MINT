# G3 Claude CLI Re-Audit — 2026-07-08

Command:

```bash
claude -p --model opus --effort max < /tmp/mint_g3_reaudit_prompt.txt
```

Verdict: **GO** to implement the first code slice, conditioned on branching from a base that includes #851/#852.

Claude verified that the four previous blockers are resolved at spec level:

1. The spec no longer treats plain `mergeAnswers()` as a sufficient confirm path; it requires a provider method that advances and persists field-path timestamps.
2. The spec maps `q_gross_salary_annual` to `salaireBrutMensuel` and `q_canton` to `canton`, with freshness classification on field paths.
3. Birth year is collect-only/static and never produces a stale reconfirm ask.
4. The false i18n reuse claim was removed; G3 requires real ARB keys.

Remaining implementation constraints:

- `BiographyRefreshDetector.detectStaleFields()` already exists. The implementation must reuse it where practical or justify a tiny adapter that converts `CoachProfile.dataTimestamps` to the same `BiographyFact` freshness shape without creating a new decay model.
- `confirmFreshness` must persist the advanced timestamp into `_coach_data_timestamps`; an in-memory-only update is not sufficient.
- If `mergeAnswers()` is broadened instead of adding a dedicated confirm method, chat/budget/save_fact regression tests are mandatory. The preferred slice keeps the blast radius to a dedicated `confirmFreshness` method.

Blocking tests for implementation:

- stale annual field -> `AskMode.reconfirm`;
- fresh annual field -> no ask;
- missing salary -> `AskMode.collect`;
- static birth-year/`age` path never emits reconfirm;
- after confirm, classifier returns no ask;
- a new provider/profile reloading persisted answers still sees the advanced timestamp;
- `/data-block/revenu` shows exactly one reconfirm card and removes it after confirm.
