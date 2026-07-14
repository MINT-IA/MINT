All 71 tests pass. The registry fallback log (`lpp.entry_threshold → 22680.0`, `avs.contribution_rate_employee → 0.053`) also confirms Swiss constants are registry-governed, not hardcoded in this diff. I have enough to render the verdict.

---

Product/domain verdict: PASS

This change (`G1-PROV-01`) is a data-ledger/provenance-spine change, not a new user flow. It is métier-coherent, fixes a real data-loss bug, preserves Swiss non-fabrication rules for AVS, and touches no legal/advice surface or domain constant. No P0 or P1.

## P0 findings
None.

## P1 findings
None. Reasons the risky candidates do *not* reach P1:
- **AVS pension non-fabrication is preserved.** `mergeAnswers` forces `prevoyance.renteAVSEstimeeMensuelle`/`prevoyance.ramd` to `estimated` on generic writes (`coach_profile_provider.dart:790-796`), and only `updateFromAvsExtraction` (a real document scan) may upgrade RAMD/rente to `certificate`. The changed test assertion `prevoyance.ramd → certificate` (`coach_profile_provider_test.dart:735`) is the *scanned* field; unrelated persisted AVS values (`anneesContribuees`=userInput, `lacunesAVS`/`rente`=estimated) correctly stay non-certified. This is the correct Swiss behavior: a declared/estimated AVS gap or pension never becomes a certified year.
- **No duplicated source of truth introduced.** `__provenance` is the new canonical envelope; `_coach_data_timestamps` is explicitly dual-written as legacy migration input and documented as such (`docs/data-flow.md` G1-PROV-01 section, verified). Reconstruction fails closed on malformed canonical entries (`coach_profile.dart:3190-3210`), proven by the `partial canonical envelope falls back field-by-field and fails closed` test.
- **Privacy boundary respected.** `_syncToBackend` strips `__provenance` before the backend push (`coach_profile_provider.dart` `_syncToBackend`), and the doc states backend per-field provenance is deliberately not mirrored.

## P2 findings
1. **`sourceDate` is fully plumbed but never populated by any production writer (facade/scaffolding).** Model slot, JSON, provider API, `__provenance.sourceDate`, and tests all exist, but every production call passes `sourceDate: null` (`coach_profile_provider.dart:809, 1985, 2260, 2465, 2718, 2950`; `applySaveFact` from `coach_chat_screen.dart:1038` and `fact_extraction_fallback.dart` pass no date). The only `sourceDate: now` (`extraction_review_screen.dart:718`) feeds the *separate* BiographyFact system and uses scan-time, not the document's own date. Swiss impact: freshness/staleness is still measured from save date, so an old LPP/AVS/tax certificate (which carries a "situation au …" date) scanned today reads as fresh. No regression (freshness already used save timestamps), but the one thing `sourceDate` was built for — dated-certificate staleness — is not delivered. Wire document extraction to emit the certificate's own date into `sourceDate` next.
2. **`inferDataSources: false` on every `copyWith` (`coach_profile.dart:2330`) silently drops source auto-inference for in-session mutations.** Durable reads are safe (reload goes through `fromWizardAnswers`/`__provenance`, which re-derive), and extraction paths now stamp explicitly via `_withStampedProvenance`, so risk is low. Verify no in-memory-only flow (e.g. annual refresh, partner LPP) relied on `copyWith` re-tagging a mutated field as `certificate`.
3. **Persistence error handling removed.** `updateInline` and `updateFromOpenBanking` dropped their `try/catch` around `saveAnswers` (old `debugPrint` fallback gone). A persistence throw now propagates uncaught and aborts the write before `_profile`/notify — correct "fail closed" for the captured-but-not-saved bug class, but confirm inline-edit/open-banking callers handle the thrown future.
4. **`updateFromPartnerLppExtraction` was not migrated to `_withStampedProvenance`** (unlike self LPP/AVS/salary). Conjoint prevoyance provenance remains on the old path; consistency debt, no correctness harm.

## Swiss domain review
- **AVS (1st pillar):** Correctly handled. Rente/RAMD never certified via generic merge; only document scan upgrades them. New `bonificationsEducatives` (LAVS art. 29sexies, child-rearing credit years) is parsed as int years from `_coach_avs_bonifications_educatives` and round-trips (`coach_profile.dart:417, 2998`) — coherent.
- **LPP (2nd pillar):** Field-level certificate provenance for `avoirLpp*`, `salaireAssure`, `tauxConversion*`, `rachatMaximum`, `rendementCaisse` now persists atomically. LPP entry threshold (22'680) is registry-backed (fallback log), not touched here.
- **3a / tax / mortgage / insurance:** Provenance keys added for `epargne3a`, fiscal, `dettes.hypotheque`, `depenses.*`; no thresholds, scales, or affordability rules changed. Mortgage alias/canonical chronology resolution preserved (mortgage-clear test passes).
- **Succession / disability / inheritance / donation:** Not affected by this diff.
- **Salary (certificat de salaire):** Real bug fixed — extraction previously wrote `q_monthly_gross_salary_chf`/`q_salary_months`, which `fromWizardAnswers` never reads (data lost on relaunch). Now writes `q_gross_salary_annual = monthly × q_nombre_mois` + `q_nombre_mois` + `q_bonus_percentage`, all of which are read (`coach_profile.dart:2813, 2815, 2836`), and no longer fabricates `q_net_income_period_chf`. Domain-correct.

## Mint product logic review
This moves Mint firmly toward the ledger → DataQuest → scenario → dossier spine. It hardens the **one source of truth** (`wizard_answers_v2` + canonical `__provenance`), enforces **atomic write-before-publish** (tests assert zero notifications before `saveAnswers` completes, closing the "UI says captured, profile empty at relaunch" class that killed the MVP walkthrough), and sharpens the known/estimated/certificate/open-banking distinction the dossier and scenario gates depend on. The unbuilt piece for a specialist-ready dossier is document-date capture (P2 #1): a handoff PDF should show that an LPP/AVS certificate is dated e.g. 2021, not merely "scanned this week" — until `sourceDate` is wired, the dossier's freshness caveat is weaker than the domain requires.
