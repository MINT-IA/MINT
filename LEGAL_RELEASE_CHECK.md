# LEGAL_RELEASE_CHECK (Mandatory)

This checklist must pass before any major release or merging features related to the Advisor Session & Report.

## 1. Promises & Language
- [x] No use of the word "garanti" or "assuré" regarding returns.
- [x] No use of "tu vas gagner" or similar absolute predictions.
- [x] Tone is educational/coaching ("Aide à la décision").

## 2. Product Specificity
- [x] No ISINs or Tickers (instruments) are mentioned in recommendations.
- [x] Recommendations refer to asset classes or strategy types only.

## 3. Disclaimers & Transparency
- [x] In-App Report contains at least 3 standard disclaimers at the bottom.
- [x] PDF Export contains identical disclaimers and the generated date.
- [x] Partner Handoff actions include a "Disclosure" text (commissions/referrals).
- [x] Every Partner Handoff has at least one non-partnered alternative presented.

## 4. Privacy & Logs
- [x] No sensitive free-text fields in the Wizard.
- [x] No sensitive data in server logs (check `uvicorn` output).
- [x] No sensitive identifiers (IBAN, Address) in the generated PDF.

## 5. System Invariants
- [x] App remains strictly "Read-Only" (no payment buttons).
- [x] All automated Backend Compliance Tests are passing.
- [x] SOT.md and OpenAPI contracts are perfectly synchronized.

## 6. Arbitrage Engine Compliance
- [ ] No option is presented as "better", "optimal", or "recommended".
- [ ] All comparisons show options side by side, never ranked.
- [ ] Hypotheses are visible and modifiable on every arbitrage screen.
- [ ] Sensitivity analysis is shown ("Si X change de Y%, le résultat s'inverse").
- [ ] Crossover point is displayed when trajectories intersect.
- [ ] Conditional language used throughout ("Dans ce scénario simulé...").
- [ ] Rente vs Capital ALWAYS shows mixed scenario (oblig/suroblig split).

## 7. Coach Layer Compliance (from S35+)
- [x] ComplianceGuard validates ALL LLM output before display.
- [x] HallucinationDetector verifies ALL numbers against financial_core.
- [x] Banned terms check catches ALL terms from CLAUDE.md banned list.
- [x] Prescriptive language check catches ALL imperative financial instructions.
- [x] Disclaimer auto-injected when LLM discusses projections.
- [ ] No social comparison in milestones or coaching ("top X%" → BANNED).
- [ ] BYOK consent screen shows exactly which data is sent to which provider.
- [x] Fallback templates produce compliant output without LLM.

## 8. Data Acquisition Compliance (from S42+)
- [ ] Document images NEVER stored (deleted after OCR extraction).
- [ ] On-device OCR by default (document never leaves phone).
- [ ] Cloud OCR requires explicit consent + data deleted after processing.
- [ ] Extracted values require user confirmation before profile injection.
- [ ] Source quality tracked per field (document vs manual vs estimated).
- [ ] Longitudinal snapshots require explicit opt-in consent (nLPD art. 5).
- [ ] User can delete all snapshots and extracted data at any time.
