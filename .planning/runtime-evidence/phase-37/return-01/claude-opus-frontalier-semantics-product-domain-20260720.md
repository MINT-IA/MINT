I have enough to render a verdict. The diff is small and additive; the domain model it surfaces is already sound and I've verified it.

## Product/domain verdict: PASS

The change is a targeted accessibility/test-harness addition: it wraps the FR/CH/GE "known" state card in `Semantics(identifier: 'frontier_jurisdiction_known_state')` (`frontalier_screen.dart:325-334`) so a native runtime id is discoverable, and adds two widget tests asserting both the semantics identifier and the `Key` resolve. No Swiss business logic, constants, routing, or compliance copy changed. The underlying frontalier classification it exposes is conservative and correct.

### P0
- None.

### P1
- None. The classification logic behind the surfaced card is correct: FR→GE is routed to `cdi1966Article17` (Geneva's source-taxation special case, correctly *excluded* from the accord), and the 1983 accord set is exactly the eight cantons BE, SO, BS, BL, VD, VS, NE, JU (`coach_profile.dart:4822-4831`). Everything else cross-border falls through to `specialistOnly` (`coach_profile.dart:4842-4847`), which is the safe default. Instruments are labeled "candidate," and the copy explicitly refuses to conclude a regime or amount.

### P2
- Asymmetric instrumentation: only `_knownState` gets a `Semantics(identifier:)` wrapper; `_staleState`, `_domesticState`, and `_specialistOnlyState` still rely on `Key` alone (`frontalier_screen.dart:256, 294, 363`). If native-runtime discovery is a general requirement, the other four states will need the same treatment for parity — otherwise this is a one-off that future readers may find inconsistent.
- The new card wrapper carries an identifier but not `button: true` (unlike `_actionableDropdown` at `frontalier_screen.dart:188-194`). Correct here (the card is not interactive), just noting the intentional difference.
- Verification command not run in this environment: `flutter test apps/mobile/test/screens/frontalier_ledger_quarantine_test.dart` would confirm the two new assertions and that wrapping the card in an extra `Semantics` node did not collapse/duplicate the `MintSurface` semantics node.

### Swiss domain review
- **Tax (frontalier):** Correct and current-practice coherent. GE→Art. 17 CDI 1966 (source taxation in Geneva) vs. the eight-canton 1983 accord amiable (taxation in France/residence) is the real Swiss split, and GE is properly kept out of the accord set. The "private salaried employment" nuance in the CDI copy correctly signals the public-sector (Art. 19) exception without asserting it. Framed as *candidate* instruments pending employment type, return frequency, and residence certificate — appropriately unconcluded.
- **AVS/LPP/3a:** Not computed. The screen only flags social-insurance affiliation as an open specialist question (`_socialInsuranceCard`, `frontalierSocialDescription`) and lists the A1 certificate question — coherent for a cross-border affiliation edge case; no pension math asserted.
- **Mortgage / insurance / succession / disability:** Not touched by this flow; no incorrect cross-claims introduced.

### Mint product logic review
- **Ledger single source of truth:** Preserved. Facts are read from `CoachProfile` and written back only via `mergeAnswers` with canonical `q_*` keys (`frontalier_screen.dart:107-163`); failures are absorbed without route or profile drift, and the tests assert no duplicate/stale writes.
- **DataQuest → scenario:** Progressive collection intact — missing/stale/known/domestic/specialist states are distinguished, and the stale state offers reconfirmation rather than re-asking blindly (`frontalier_screen.dart:266-281`).
- **Dossier spine:** The specialist-questions card enumerates the open questions a specialist would need (residence, employment, employer, A1). This change advances the ledger→DataQuest→scenario→dossier spine only marginally (test/a11y hardening), but does not regress it. The remaining gap toward a true handoff is a generated specialist PDF carrying these facts/caveats — out of scope for this diff, worth a follow-up.
