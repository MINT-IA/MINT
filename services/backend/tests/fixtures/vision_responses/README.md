# Vision response cassettes — Phase 30 golden flow

Pre-recorded Anthropic Messages-API `tool_use` payloads for each fixture in
`../documents/`. Cassettes let the golden flow run **offline** — no
`ANTHROPIC_API_KEY` required, no billing, no flake.

## Shape

Every cassette mirrors the shape of `anthropic.types.Message` produced by
`understand_document`'s fused `route_and_extract` tool call:

```json
{
  "id": "msg_fixture_<name>",
  "type": "message",
  "role": "assistant",
  "model": "claude-sonnet-4-5-20250929",
  "stop_reason": "tool_use",
  "usage": {"input_tokens": <int>, "output_tokens": <int>},
  "content": [
    {
      "type": "tool_use",
      "id": "toolu_fixture_<name>",
      "name": "route_and_extract",
      "input": { ... tool input conforming to ROUTE_AND_EXTRACT_TOOL ... }
    }
  ]
}
```

The golden-flow test loads the cassette, builds a SimpleNamespace matching
what `response.content[i]` and `response.usage` expose, then feeds it
through `document_vision_service._ti_to_result()` (same pipeline as the
real path).

## Regeneration (future work)

A `record.py` script to re-record cassettes from a real Vision call is
**out of scope** for Phase 30. To refresh a cassette manually:

1. Hand-edit the JSON: change `input.extracted_fields`, `overall_confidence`,
   etc.
2. Ensure the combination passes through `_select_render_mode()` to the
   `expected_render_mode` in `golden_expectations.py`.
3. Re-run `pytest tests/integration/test_golden_document_flow.py -v`.

## Cassette inventory

### Primary corpus (Phase 30 / GATE-03)

| Cassette                            | documentClass      | extractionStatus | overall | → render_mode |
|-------------------------------------|--------------------|------------------|---------|---------------|
| `cpe_plan_maxi_julien.json`         | lpp_certificate    | success          | 0.93    | confirm       |
| `hotela_lauren.json`                | lpp_certificate    | success          | 0.92    | confirm       |
| `avs_ik_extract.json`               | avs_extract        | partial          | 0.80    | ask           |
| `salary_certificate_afc.json`       | salary_certificate | success          | 0.92    | confirm       |
| `tax_declaration_vs_julien.json`    | tax_declaration    | success          | 0.91    | confirm       |
| `us_w2_lauren.json`                 | non_financial      | non_financial    | 0.40    | reject        |
| `crumpled_scan.json`                | lpp_certificate    | partial          | 0.80    | ask           |
| `angled_photo_iban.json`            | bank_statement     | success          | 0.92    | confirm       |
| `mobile_banking_screenshot.json`    | bank_statement     | partial          | 0.65    | narrative     |
| `german_insurance_letter.json`      | insurance_policy   | success          | 0.68    | narrative     |

### Adversarial corpus (Phase 29-04, reused here)

| Cassette                                  | Expected disposition                                |
|-------------------------------------------|------------------------------------------------------|
| `prompt_injection_white_on_white.json`    | Guard blocks, payload scrubbed, render=narrative    |
| `prompt_injection_metadata.json`          | Guard blocks, payload scrubbed, render=narrative    |
| `prompt_injection_svg_overlay.json`       | Guard blocks, payload scrubbed, render=narrative    |
| `sanity_rendement_15pct.json`             | NumericSanity rejects → render=reject               |
| `sanity_salaire_3M.json`                  | NumericSanity rejects → render=reject               |
| `sanity_taux_conv_8pct.json`              | NumericSanity rejects → render=reject               |
| `sanity_avoir_lpp_7M.json`                | NumericSanity human_review, render != reject       |
