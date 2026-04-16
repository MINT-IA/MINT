# MINT document corpus — Phase 30 golden fixtures (GATE-03)

Reproducible, **PII-clean** corpus driving the Phase 30 mocked-Vision
golden flow (`tests/integration/test_golden_document_flow.py`).

## How to regenerate

```bash
cd services/backend
.venv/bin/python tests/fixtures/documents/generate_corpus_fixtures.py
.venv/bin/python tests/fixtures/documents/generate_corpus_fixtures.py --verify
```

`pymupdf` + `Pillow` are already in the backend venv (Phase 28-01 and
earlier). No extra dependency is required.

## Anonymisation protocol

Every fixture uses synthetic identifiers from reserved test ranges:

| Identifier | Synthetic value              | Why safe                                  |
|------------|------------------------------|-------------------------------------------|
| Name       | `Jean TESTUSER`              | Placeholder, no match in CH population    |
| Name (2)   | `Marie TESTUSER-SECOND`      | Placeholder, no match in CH population    |
| AVS no.    | `756.0000.0000.01`           | Valid mod-11 checksum, unassigned reserve |
| IBAN       | `CH93 0076 2011 6238 5295 7` | Valid mod-97, test-doc IBAN               |
| Employer   | `Employeur Test 1..10`       | Pure placeholder                          |
| SSN (W-2)  | `XXX-XX-0000`                | Obvious synthetic                         |
| Address    | (omitted)                    | Never included                            |
| Phone      | (omitted)                    | Never included                            |

All financial values are synthetic but plausible (matching the Julien +
Lauren golden couple in `CLAUDE.md §8` so downstream tests can assert
ranges like `avoir_vieillesse ∈ [70000, 71000]`).

## Primary corpus (this directory, Phase 30 / GATE-03)

| # | Fixture                            | Class                | Expected render_mode | Key fields                                             |
|---|------------------------------------|----------------------|----------------------|--------------------------------------------------------|
| 1 | `cpe_plan_maxi_julien.pdf`         | lpp_certificate      | confirm              | avoir 70'377, salaire assuré 91'967, rachat 539'414    |
| 2 | `hotela_lauren.pdf`                | lpp_certificate      | confirm              | avoir 19'620, rachat 52'949, **third-party trigger**   |
| 3 | `avs_ik_extract.pdf`               | avs_extract          | ask                  | 10 years × employer × amount                           |
| 4 | `salary_certificate_afc.pdf`       | salary_certificate   | confirm              | brut 122'207, net 98'340                               |
| 5 | `tax_declaration_vs_julien.pdf`    | tax_declaration      | confirm              | fortune 248'000, revenu 112'400 (multi-page)           |
| 6 | `us_w2_lauren.pdf`                 | non_financial        | reject               | US W-2, not a Swiss document                           |
| 7 | `crumpled_scan.jpg`                | lpp_certificate      | ask                  | noisy scan, some low-conf fields                       |
| 8 | `angled_photo_iban.jpg`            | bank_statement       | confirm              | IBAN present → **PII scrub asserted downstream**       |
| 9 | `mobile_banking_screenshot.png`    | bank_statement       | narrative            | iPhone screenshot, short summary                       |
| 10 | `german_insurance_letter.pdf`     | insurance_policy     | narrative            | DE source → **FR response asserted**                   |

## Adversarial corpus (Phase 29-04, NOT owned here)

The following fixtures live in this directory but are produced by
`services/backend/scripts/generate_adversarial_fixtures.py`. **Do NOT
regenerate them from this script** — content and assertions belong to
Phase 29-04 / PRIV-05.

- `prompt_injection_white_on_white.pdf`
- `prompt_injection_metadata.pdf`
- `prompt_injection_svg_overlay.pdf`
- `sanity_rendement_15pct.pdf`
- `sanity_salaire_3M.pdf`
- `sanity_taux_conv_8pct.pdf`
- `sanity_avoir_lpp_7M.pdf`

Phase 30 **reuses them** via JSON cassettes in `../vision_responses/`
rather than regenerating the PDFs.

## Size budget

All fixtures < 200 KB (verified by `--verify`). Current footprint:
~160 KB total for the 10 primary fixtures.

## Byte-stability note

`pymupdf` serialises with embedded timestamps, so PDFs are not
byte-identical across regens (content is stable — the golden flow
asserts **content**, not hash). PNGs/JPGs from Pillow are
byte-identical across regens when the inputs are identical.
