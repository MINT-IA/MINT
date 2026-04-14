# Legal review checklist — Phase 29 (compliance & privacy)

> **DRAFT — awaiting Walder Wyss / MLL Legal review.**
> Purpose: single-page consolidation of every open legal item produced by the
> Phase 29 implementation. Julien walks into the avocat's office with this
> document. Each row has a plan reference, recommended reviewer firm, and a
> `status` column for the avocat to update.

Last updated: 2026-04-14 · Phase 29 closed · v2.7 milestone.

## How to use this checklist

- **One row per legal checkpoint.** Items were sourced from the 6 plans of
  Phase 29 (29-01 through 29-06) and their respective SUMMARY files.
- **Status values:** `pending_review` → `approved` → `approved_with_changes` →
  `blocked`. Update in place.
- **Reviewer firm** is a recommendation, not a mandate. Julien decides.

---

## Checklist

| # | Checkpoint                                                                                   | Plan ref | Reviewer firm (recommendation) | Status          | Notes |
|---|----------------------------------------------------------------------------------------------|----------|--------------------------------|-----------------|-------|
| 1 | `ConsentReceipt` JSON schema conforms to ISO/IEC 29184:2020 §6                               | 29-02    | Walder Wyss                    | pending_review  | Verify all required fields present; confirm signature scheme is acceptable. |
| 2 | Privacy policy version hash stored; red-line diff shown to user on change                    | 29-02    | Walder Wyss                    | pending_review  | Regulatory framing under nLPD art. 19 et seq. |
| 3 | Merkle-chained consent receipts admissible as audit evidence in CH                           | 29-02    | Walder Wyss                    | pending_review  | HMAC + `previousReceiptHash`; confirm evidentiary value. |
| 4 | Envelope encryption (AES-256-GCM) + DEK crypto-shredding satisfies nLPD art. 8 deletion obligation | 29-01 | MLL Legal (DPO specialists)   | pending_review  | Confirm crypto-shred = "deletion" for regulatory purposes. |
| 5 | Fact-key allowlist is a defensible scope limitation under nLPD art. 6(3) (data minimisation) | 29-03    | MLL Legal                      | pending_review  | Allowlist enumerated in `fact_key_allowlist.py`. |
| 6 | FPE-tokenised log tier (365-day retention) qualifies as pseudonymisation                     | 29-03    | MLL Legal                      | pending_review  | Per nLPD art. 5(c); GDPR art. 4(5). |
| 7 | VisionGuard fail-closed behaviour is acceptable under LSFin art. 7–10 (no advice without qualification) | 29-04 | Walder Wyss                  | pending_review  | Haiku-judge fail-closed returns safe fallback text. |
| 8 | Nominative third-party declaration opposability under CO art. 28 + nLPD art. 19              | 29-05    | Walder Wyss                    | pending_review  | Signed attestation per `ConsentPurpose.THIRD_PARTY_ATTESTATION`. |
| 9 | "Modèle info tiers" (art. 19 nLPD) — validate standard wording                              | 29-05    | Walder Wyss                    | pending_review  | Draft text in ARB files; French primary. |
| 10 | DPA technical annex — validate TOM completeness, sub-processor list accuracy                | 29-06    | MLL Legal + Walder Wyss        | pending_review  | See `docs/DPA_TECHNICAL_ANNEX.md`. |
| 11 | Swiss-US DPF (Anthropic) certification verified on dataprivacyframework.gov                 | 29-06    | Julien (ops) → Walder Wyss sign-off | pending_review | Must be verified **before** any prod traffic to Anthropic direct. |
| 12 | Bedrock primary flip conditions — shadow-mode quality threshold + user notice required?     | 29-06    | Walder Wyss                    | pending_review  | Can the switch be silent, or does nLPD art. 19 require notice? |
| 13 | LSFin educational framing preserved end-to-end — no advice, always scenarios                 | all      | Walder Wyss (LSFin specialist) | pending_review  | Spot-check `docs/VOICE_SYSTEM.md` and live coach output. |
| 14 | AWS EMEA SARL sub-processor agreement (art. 28 GDPR / nLPD art. 9)                           | 29-06    | MLL Legal                      | pending_review  | Confirm executed DPA; map roles. |
| 15 | TIA on file for Anthropic US fallback path                                                   | 29-06    | MLL Legal                      | pending_review  | See `docs/DPA_TECHNICAL_ANNEX.md` §6. |
| 16 | Two-stage masking (`mask_pii_regions`) is not a pre-condition for lawfulness — is it?        | 29-06    | MLL Legal                      | pending_review  | If answer is "yes", must default ON at ship. |
| 17 | Notice period (30 days) for sub-processor change aligned with GDPR art. 28(2)                | 29-06    | MLL Legal                      | pending_review  | Standard but confirm. |
| 18 | User export format (JSON) satisfies right-to-portability under nLPD art. 28 + GDPR art. 20  | all      | MLL Legal                      | pending_review  | Full dossier federation deferred; interim JSON acceptable? |

---

## Out-of-scope for this review

- Marketing / landing-page compliance copy.
- B2B / caisse-partner DPAs (Phase 4 milestone).
- Banking licence or LSFin registration (MINT is explicitly out of scope by design).

---

*Return this document updated. MINT will implement any `approved_with_changes` items in v2.8.*
