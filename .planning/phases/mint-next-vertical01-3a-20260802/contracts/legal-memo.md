```json legal-memo-contract
{
  "authority_manifest_path": ".planning/phases/mint-next-vertical01-3a-20260802/annexes/legal-authority-sources.json",
  "authority_manifest_sha256": "6897f765a5fe0c537e7de6be977bc8440986bfe4e6930882bd95491773680d5c",
  "coverage": {
    "regimes": [
      "anti_money_laundering",
      "data_protection",
      "finsa",
      "insurance_intermediation",
      "prudential_licensing",
      "substantive_3a_tax",
      "tax_legal_professional_boundary",
      "unfair_competition"
    ],
    "surfaces": [
      "amount_choice",
      "coach_narrative",
      "coach_typed_intent",
      "confirmation_refusal",
      "contradiction_resolution",
      "fact_proposal",
      "fact_review",
      "notification",
      "plan_confirmation",
      "plan_status",
      "result_widget_contribution",
      "result_widget_liquidity",
      "result_widget_tax_reduction",
      "result_widget_withdrawal_tax",
      "revoke_delete_export",
      "rules_unavailable_explanation",
      "secure_failure_recovery",
      "situation_read_model",
      "stale_refresh",
      "telemetry_crash_evidence",
      "today_opportunity",
      "unsupported_explanation"
    ],
    "triggers": [
      "account_opening_or_referral",
      "automated_legally_significant_decision",
      "claim_of_finma_approval_or_supervision",
      "commission_or_affiliate_remuneration",
      "cross_border_user_or_service",
      "custody_or_money_movement",
      "data_leaves_device_or_new_recipient_or_transfer",
      "imperative_financial_action",
      "insurance_product_comparison",
      "llm_free_text_outside_allowlist",
      "observed_transaction_or_daily_monitoring_claim",
      "order_execution_or_transmission",
      "personalized_recommendation",
      "portfolio_allocation_or_rebalancing",
      "provider_or_product_ranking",
      "sold_human_advice_escalation",
      "specific_provider_or_instrument",
      "stale_or_unreviewed_authority",
      "suitability_best_optimal_language",
      "tax_filing_submission_or_representation",
      "unsupported_persona_canton_year_or_taxation"
    ]
  },
  "document_id": "mint_next_three_a_internal_legal_issue_spotting_v1",
  "document_status": "internal_issue_spotting_pending_independent_swiss_legal_review",
  "does_not_activate_runtime": true,
  "does_not_close_B0": true,
  "external_legal_review": {
    "receipt": null,
    "reviewer": null,
    "status": "pending"
  },
  "legal_effect": "none_internal_questions_only",
  "prepared_by": "MINT internal product and engineering issue-spotting",
  "prepared_on": "2026-08-10",
  "real_user_exposure": "forbidden",
  "regime_questions": {
    "anti_money_laundering": "Does behavior receive, hold, transfer, or control third-party money or assets?",
    "data_protection": "Does behavior process personal data, add a recipient or transfer, use new technology, or make a legally significant automated decision?",
    "finsa": "Does behavior provide a financial service, investment recommendation, or client-adviser activity professionally in Switzerland?",
    "insurance_intermediation": "Does behavior propose, compare, recommend, or intermediate a specific insurance product?",
    "prudential_licensing": "Does behavior accept deposits, hold assets, manage portfolios, execute or transmit orders, or operate another licensable financial-market activity?",
    "substantive_3a_tax": "Are OPP3 and federal, cantonal, communal tax rules current and applicable to the exact supported facts and year?",
    "tax_legal_professional_boundary": "Could personalized wording be understood as tax or legal advice or create professional or civil reliance?",
    "unfair_competition": "Could wording, ranking, omission, remuneration, or a quantified promise mislead a user commercially?"
  },
  "regulatory_applicability_path": ".planning/phases/mint-next-vertical01-3a-20260802/contracts/regulatory-applicability.yaml",
  "regulatory_applicability_sha256": "7243da5af384cd1c9eaff1fe6c75dcedf03de3b822e54fd76a06ed724115df25",
  "review_by": "2026-11-08",
  "runtime_binding": "none",
  "schema_version": 1,
  "source_use": "citation_only_no_source_content_or_runtime_fetch"
}
```

## Legal memo

MINT Next 3a — internal legal issue-spotting memo.

## Status and limits

This internal artifact records questions and stop conditions for the frozen Lausanne/VD/2026 3a vertical. It is not an opinion, external review, regulatory classification, activation decision, or evidence that B0 is complete. Independent Swiss counsel review is pending. Real-user exposure remains forbidden and the feature flag remains off.

## Supported behavior under review

The bounded behavior is neutral education, user-controlled factual review, a deterministic non-binding estimate only when its separate calculation contract permits it, a free amount choice including CHF 0, and a user-confirmed local mini-plan. The coach may navigate and explain; it may not create canonical facts, calculate, select a provider, move money, file taxes, or make a suitability decision.

The supported context is one adult aged 18–65, single without children, resident in Lausanne for all of 2026, under ordinary taxation, salaried with AVS income and active LPP, ordinary 2026 pillar 3a, and an exhaustively confirmed provider inventory. Any contextual change is a stop condition rather than an inferred extension.

## Regime questions

The eight questions in the contract metadata are issue-spotting prompts. A question does not establish that a regime applies or does not apply.

- `finsa`: classify actual service behavior, personalization, financial instruments, professional delivery and client-adviser activity.
- `prudential_licensing`: classify custody, deposits, portfolio management, execution, transmission and other potentially licensable activity.
- `insurance_intermediation`: classify proposing, comparing, recommending or intermediating a specific insurance product.
- `anti_money_laundering`: classify receipt, holding, transfer or control of third-party money or assets.
- `data_protection`: classify purposes, data categories, recipients, transfers, new technology, profiling and automated decisions; a separate AIPD screening owns the risk decision.
- `substantive_3a_tax`: check OPP 3 and federal, cantonal and communal rules against the exact facts and year.
- `unfair_competition`: inspect wording, omissions, quantified claims, ranking and remuneration for misleading commercial effects.
- `tax_legal_professional_boundary`: assess whether personalized wording, filing assistance or escalation could create reliance on tax or legal services.

All unresolved mapped questions keep the most restrictive outcome from the RegulatoryApplicabilityContract. A disclaimer cannot change the classification of product behavior.

## Surface and trigger coverage

The structured metadata binds all 22 current surfaces and all 21 current triggers from `regulatory-applicability.yaml`. The dependency hash makes any contract change invalidate this memo. The mappings themselves remain canonical in that contract and are not copied into prose.

Before any surface is exposed, independent Swiss counsel must review the behavior of that surface together with every mapped regime and present trigger. Unknown surface, trigger, field, context or claim class fails closed. Product labels, educational language and disclaimers do not replace behavior-based review.

## Allowed internal posture

During pre-activation work, MINT may retain neutral education, user factual control, dated source attribution and explicit uncertainty. Personalized output remains conditional on the calculation and applicability contracts. No provider ranking, referral, account opening, insurance comparison, order flow, custody, money movement, portfolio management, tax filing or cross-border extension is included.

This memo supplies no answer of “applicable” or “not applicable” for any regime. It records only the questions, sources and stop conditions that an independent reviewer must assess against the implemented behavior.

## Open questions for independent Swiss counsel

1. Does each implemented 3a surface remain neutral education, or does any behavior amount to a financial service, investment recommendation or client-adviser activity?
2. Could the personalized tax estimate, amount choice or mini-plan create regulated or professional reliance despite the user retaining free choice?
3. Do any future provider names, comparisons, referrals, remuneration or hand-offs change the FinSA, prudential, insurance-intermediation or unfair-competition analysis?
4. Does any present or future receipt, custody, execution, transmission or control of assets change the prudential or anti-money-laundering analysis?
5. Are the purposes, notices, legal bases where required, recipients, transfers, retention, export, deletion and automated-decision handling sufficient under the FADP for the exact architecture?
6. Does the separate AIPD screening correctly assess high-risk processing and any residual-risk consultation duty before exposure?
7. Are the OPP 3 and Lausanne/VD/2026 tax assumptions and user-facing limits adequate for a non-binding model estimate?
8. What exact product, code, source and ruleset hashes must the external receipt bind, and what changes invalidate that review?

## Stop conditions

Exposure remains forbidden while external counsel identity, scope, date, reviewed product hash, conflicts declaration, findings and signed receipt are absent. It also remains forbidden when any authority is stale, any mapped question is unresolved, the supported context changes, data processing changes without reassessment, or a blocked trigger appears.

A later external reviewer artifact must be independently authored and mechanically bound. This internal memo cannot be renamed, promoted or cited as that receipt.

## Sources

The separately versioned `legal-authority-sources.json` contains official Fedlex, FINMA, PFPDT and Federal Tax Administration citations only. Source text is not copied into this memo and is never fetched at runtime. The citations help locate issues; they do not turn internal engineering analysis into legal review.
