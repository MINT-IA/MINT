---

## Product/domain verdict: PASS

The flow is Swiss-domain coherent and the test infrastructure changes are technically sound. No P0 or P1 issues. Three P2 items to track before user-facing release.

---

### P0 — None

### P1 — None confirmed

Two candidates dissolved on inspection:

**Birth year dual-key consistency** — `applySaveFact('dateOfBirth', …)` writes only to `q_date_of_birth`, but the merge path in `_mergeAnswers` calls `_authoritativeExactDateOfBirthFromAnswers` on the updated answer map, then sets `next['q_birth_year'] = exactDateOfBirth.year` and calls `_mirrorDateOfBirthAuthorityToBirthYear` to sync provenance envelopes (`coach_profile_provider.dart:2935-2938`). Since both test corpora seed `__provenance.dateOfBirth.source = userInput`, the guard passes and `q_birth_year` is kept coherent after mutation. No SoT violation in the tested code paths.

**Income not in `retirementNoLpp` fingerprint** — The dependency fingerprint for `retirementNoLpp` intentionally contains only `hasPensionFund` and `dateOfBirth` facts (`financial_plan_ledger_inputs.dart:270-274`). This is correct because `retirementNoLpp` is a pure savings-pace calculator (`monthlyTarget = goalAmount / months_to_retirement`): income is not an input to the calculation, so excluding it from the fingerprint is domain-correct. Income changes causing staleness would be false positives.

---

### P2 — Polish / future-release items

**P2-1: Feature is test-only in production — zero user-facing value until the dart-define ships**
`financialPlanSetupEnabled` is `const bool.fromEnvironment('MINT_TEST_FINANCIAL_PLAN_SETUP', defaultValue: false)` (`feature_flags.dart:77-81`). The docstring is explicit: "TEST-ONLY compile-time opt-in … so the backend cannot activate the unfinished G1 path." App Store builds never receive `--dart-define=MINT_TEST_FINANCIAL_PLAN_SETUP=true`, so the entire staleness-recovery UI is invisible to real users. This PR is pure test harness hardening for a feature behind a kill switch. That is a legitimate staged-rollout practice, but the product value is deferred. Track the release gate.

**P2-2: Amount parsing fallback introduces minor Swiss-number edge case**
`financial_plan_setup_card.dart` now falls back to `double.tryParse(normalizedAmount.replaceAll(',', '.'))`. Normalization already strips `'`, `'`, NBSP, and spaces, but does NOT strip commas. A user entering `1,500` with comma-as-thousands (non-standard Swiss) who fails the locale parser would get `1.5` via the fallback instead of `1500`. Impact is bounded — amounts below ~CHF 100 are obviously wrong for a retirement goal and fail the `amount <= 0` guard only if truly zero — but there is no minimum-amount validation. Consider a minimum (e.g., `amount < 1`) or explicit comma-stripping before the fallback for Swiss locales.

**P2-3: LPP regulatory fallback constants annotated "2025/2026"; federal 2026 ordinance not cited**
`social_insurance.dart:22680` (lppSeuilEntree), `26460` (déduction coordination), `90720` (salaire max) are stamped "Dernière mise à jour: 2026-03-26". The file asserts these are valid for 2025 and 2026, but the federal ordinance adjusting AHV/LPP thresholds for 2026 is not cited inline. The backend-sync architecture (`reg()` → `RegulatorySyncService`) provides live values so fallback staleness is low-risk in connected operation, but for the offline/degraded path an unverified 2026 threshold is unverified P1 by audit policy for `retirementLpp` branch calculations. Mark as **unverified / needs OFAS OPP2 2026 source** before `retirementLpp` ships to users.

**P2-4: `retirementNoLpp` plan does not project or deduct expected AVS rente from the monthly target**
The plan is goal-based: `monthlyTarget = goalAmount / months`. A user without LPP who receives AVS at 65 needs the dossier/PDF to clearly state that the monthly savings target does NOT already account for future AVS income, so the specialist can frame the complete picture. The mandatory disclaimer (`mandatoryMintPlanDisclaimer`) covers the generic caveat, but a branch-specific explanation of what is and is not included in the projection would improve specialist handoff quality.

---

### Swiss domain review

| Pillar | Status |
|---|---|
| **AVS (1er pilier)** | AVS 21 reference age correctly implemented with monthly cohort transitions for women born 1961–1963 (`avs_reference_age.dart`). `avsAgeReferenceFemme = 65` for 1964+ cohorts. ✓ |
| **LPP (2e pilier)** | `retirementNoLpp` branch correctly excludes LPP capital, insured salary, and conversion rate from the fingerprint and calculation. LPP constants used only in regulatory context hash. `legalContractValidUntil = 2027-01-01` gives a correct legal-schedule boundary. Fallback constants unverified against 2026 federal ordinance (P2-3). |
| **3a (3e pilier)** | Not touched by this diff. |
| **Tax / canton** | Not touched by this diff. |
| **Mortgage / insurance** | Not touched by this diff. |
| **Succession / donation** | Not touched by this diff. |
| **Gender-linked retirement age** | The test data uses no explicit gender field; `avsReferenceAge` defaults to the gender-neutral path (male = 65). Not a regression — the no-LPP plan goal is user-stated, not AVS-derived. |
| **Disability** | Not touched. |

---

### MINT product logic review

The diff moves MINT toward the **ledger → DataQuest → scenario → dossier** spine in these respects:

- **Ledger SoT preserved**: recovery flow proves zero reverse writes (`ledgerJsonBeforeRegeneration == ledgerJsonAfterRegeneration`). The ledger is read-only during plan recalculation. ✓
- **Right minimum variables for retirementNoLpp**: `hasPensionFund` (branch selector) + `dateOfBirth` (horizon). No premature income collection for this branch. ✓
- **Progressive collection**: retirement context step acknowledges the computed horizon from existing ledger data — it does not re-ask for a known fact, only confirms the user's awareness. ✓
- **No advice, no guarantee, no product recommendation**: `mandatoryMintPlanDisclaimer` is embedded in every generated plan; no new compliance-boundary crossings in the diff. ✓
- **Confidence level**: `retirementNoLpp` confidence is `_branchConfidence([affiliationFact, birthFact])`, not forced to 100. Source is `userInput` → 60 points — honest uncertainty. ✓
- **Specialist handoff gap (P2-4)**: the dossier monthly target does not caveat that future AVS income is excluded from the projection. Add a branch-specific note for the specialist handoff.

The semantic rename (`home_route` → `landing_route`) is a correctness fix, not a product change. The Maestro barrier (`assertVisible: landing_route` before `openLink: mint:///home`) correctly ensures the app is settled on the landing screen before navigating, preventing a race condition in cold-start E2E tests.
