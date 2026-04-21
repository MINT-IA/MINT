<!-- MINT PR template — fill each section before asking for review.
     The boxes are not ceremony — they are the mechanism that stops the
     « coded in the dark » pattern. If you can't check a box, reopen the
     task before asking humans or agents to review. -->

## Summary

<!-- 1-3 lines. WHAT changed and WHY (not HOW). -->


## Scope — what subsystem this touches

<!-- Check at most 2-3. If you'd check 5, split the PR. -->

- [ ] Coach chat (routing / tools / narrative)
- [ ] CoachProfile / data flow / extraction
- [ ] Financial calculators (`financial_core/`)
- [ ] Scan pipeline (document parser / extraction review)
- [ ] Budget (setup / summary card / plan)
- [ ] Navigation (routes / shell / deep links)
- [ ] Compliance / LSFin / PII
- [ ] UI polish / accents / i18n
- [ ] Backend endpoint / model / migration
- [ ] DevEx (tooling / tests / docs)

## Before-you-ask-review protocol

### 1 — You read the map

Before the first code change in this PR, you read the relevant row of
[`AGENTS.md`](../AGENTS.md). State which doc you consulted:

- [ ] [`docs/data-flow.md`](../docs/data-flow.md) — data capture / storage keys
- [ ] [`docs/coach-tool-routing.md`](../docs/coach-tool-routing.md) — LLM tools
- [ ] [`docs/calculator-graph.md`](../docs/calculator-graph.md) — financial_core
- [ ] N/A — change doesn't touch those subsystems (explain in summary)

### 2 — You ran the grep verification

- [ ] I grepped every symbol I named in this PR in the current session
      (no memory-based coding).
- [ ] If this PR adds a new tool / fact key / route / calculator,
      **I updated the corresponding `docs/*.md` in this same PR**.

### 3 — You ran the tests locally

Copy-paste the shard you ran and the result (`N tests passed`):

```
$ flutter test test/...
…
```

- [ ] `flutter analyze <files touched>` — no new errors
- [ ] Tests relevant to the shard green locally (not just CI)
- [ ] If LLM-dependent code: golden I/O pairs still match

### 4 — You walked the feature

- [ ] Built on iPhone 17 Pro simulator (or real device for device-only
      bugs) and did the end-to-end flow relevant to the change.
- [ ] Verified SharedPreferences persistence (plist dump) if the change
      writes user data.
- [ ] Verified no `PlatformException(-34018)` in device logs if the
      change touches Keychain / SecureStorage.

### 5 — Size + revertability

- [ ] `git diff --shortstat origin/dev...HEAD` is **under 300 lines** of
      real code (excluding generated l10n + lockfiles). If over, I
      justified why in the summary.
- [ ] This PR is **atomically revertable**. `git revert <sha>` wouldn't
      break an orthogonal feature.

### 6 — Anti-patterns I did NOT introduce

- [ ] No helper / abstraction for 2 duplicates
- [ ] No `try/catch` fallback for an impossible case
- [ ] No service without a caller, widget without a consumer, route
      without a renderer (façade sans câblage)
- [ ] No comment restating what the code does (only WHY)
- [ ] No test that asserts LLM mock output

### 7 — CLAUDE.md top rules

- [ ] No banned LSFin term (garanti / optimal / meilleur / certain / sans risque)
- [ ] All user-facing strings via `AppLocalizations` (6 ARB files in sync)
- [ ] All French text has correct accents (no `creer`, `decouvrir`, `eclairage`)
- [ ] No retirement-first framing
- [ ] No duplicated `_calculate*` outside `financial_core/`

## Screenshots / repro / Sentry

<!-- If UI changes: before + after screenshots on iPhone 17 Pro sim.
     If bug fix: link Sentry event or repro steps.
     If backend change: curl example. -->


## Rollback plan

<!-- One line. How does one revert this if it causes prod issues?
     If gated by a FeatureFlag, name the flag + dashboard URL. -->


## References

<!-- Link ADR / triage doc / panel expert synthesis that justified the
     choice. -->

- ADR: 
- Triage:
- Related PR:

---

🤖 Generated-with-agent? Delete this line AND add `[LLM-assisted]` to
the title so reviewers know to cross-check the diff (not just the agent
summary).
