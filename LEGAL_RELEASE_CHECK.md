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
