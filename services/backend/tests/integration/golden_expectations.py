"""Per-fixture expected outcomes for the Phase 30 golden document flow.

Each entry describes what ``understand_document`` MUST produce for the
corresponding fixture (documents/) + cassette (vision_responses/). The
parametrised test in ``test_golden_document_flow.py`` iterates over
``GOLDEN_EXPECTATIONS`` and asserts each invariant.

Conventions:
    - ``critical_field_assertions`` maps ``field_name -> (lo, hi)`` inclusive
      numeric range. The field MUST exist AND be numeric AND within range.
    - ``expect_response_locale`` drives a crude language-leak heuristic
      on ``summary`` (German tokens rejected when "fr").
    - ``max_cost_usd`` / ``max_latency_seconds`` are per-fixture budgets.
      The session-scoped aggregator also asserts avg cost < $0.05 and
      p95 latency < 10s across ALL fixtures.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Dict, List, Optional, Tuple


@dataclass(frozen=True)
class GoldenExpectation:
    fixture_name: str                      # basename w/o extension
    expected_render_mode: str              # confirm | ask | narrative | reject
    expected_document_class: str
    expected_extraction_status: str
    critical_field_assertions: Dict[str, Tuple[float, float]] = field(default_factory=dict)
    expect_third_party: bool = False
    expect_third_party_name: Optional[str] = None
    expect_response_locale: str = "fr"
    max_cost_usd: float = 0.05
    max_latency_seconds: float = 10.0
    cassette_name: Optional[str] = None    # defaults to fixture_name
    is_adversarial: bool = False
    expect_prompt_injection_ignored: bool = False
    expect_sanity_verdict: Optional[str] = None  # reject | human_review | None
    expect_guard_blocked: Optional[bool] = None  # None = don't assert
    user_canton: str = "VS"


GOLDEN_EXPECTATIONS: List[GoldenExpectation] = [
    # ---------------------------------------------------------------- primary
    GoldenExpectation(
        fixture_name="cpe_plan_maxi_julien",
        expected_render_mode="confirm",
        expected_document_class="lpp_certificate",
        expected_extraction_status="success",
        critical_field_assertions={
            "avoir_vieillesse_lpp": (70000, 71000),
            "salaire_assure": (91000, 93000),
            "rachat_maximum": (539000, 540000),
        },
    ),
    GoldenExpectation(
        fixture_name="hotela_lauren",
        expected_render_mode="confirm",
        expected_document_class="lpp_certificate",
        expected_extraction_status="success",
        critical_field_assertions={
            "avoir_vieillesse_lpp": (19000, 20500),
            "rachat_maximum": (52000, 53000),
        },
        # Third-party detection fires because the cassette source_text
        # contains "Marie Testuser" and the caller passes Jean's profile.
        expect_third_party=True,
        expect_third_party_name="Marie Testuser",
    ),
    GoldenExpectation(
        fixture_name="avs_ik_extract",
        expected_render_mode="ask",
        expected_document_class="avs_extract",
        expected_extraction_status="partial",
        critical_field_assertions={
            "annees_cotisees": (10, 10),
        },
    ),
    GoldenExpectation(
        fixture_name="salary_certificate_afc",
        expected_render_mode="confirm",
        expected_document_class="salary_certificate",
        expected_extraction_status="success",
        critical_field_assertions={
            "salaire_brut_annuel": (122000, 123000),
            "salaire_net_annuel": (98000, 99000),
        },
    ),
    GoldenExpectation(
        fixture_name="tax_declaration_vs_julien",
        expected_render_mode="confirm",
        expected_document_class="tax_declaration",
        expected_extraction_status="success",
        critical_field_assertions={
            "revenu_imposable": (112000, 113000),
            "fortune_imposable": (247000, 249000),
        },
    ),
    GoldenExpectation(
        fixture_name="us_w2_lauren",
        expected_render_mode="reject",
        expected_document_class="non_financial",
        expected_extraction_status="non_financial",
    ),
    GoldenExpectation(
        fixture_name="crumpled_scan",
        expected_render_mode="ask",
        expected_document_class="lpp_certificate",
        expected_extraction_status="partial",
        critical_field_assertions={
            "avoir_vieillesse_lpp": (69000, 71000),
        },
    ),
    GoldenExpectation(
        fixture_name="angled_photo_iban",
        expected_render_mode="confirm",
        expected_document_class="bank_statement",
        expected_extraction_status="success",
        critical_field_assertions={
            "solde_compte": (12430, 12431),
        },
    ),
    GoldenExpectation(
        fixture_name="mobile_banking_screenshot",
        expected_render_mode="narrative",
        expected_document_class="bank_statement",
        expected_extraction_status="partial",
    ),
    GoldenExpectation(
        fixture_name="german_insurance_letter",
        expected_render_mode="narrative",
        expected_document_class="insurance_policy",
        expected_extraction_status="success",
        critical_field_assertions={
            "prime_annuelle": (1199, 1201),
        },
        expect_response_locale="fr",
    ),

    # ------------------------------------------------------ adversarial (29-04)
    GoldenExpectation(
        fixture_name="prompt_injection_white_on_white",
        expected_render_mode="narrative",   # guard blocks → narrative swap
        expected_document_class="lpp_certificate",
        expected_extraction_status="success",
        is_adversarial=True,
        expect_prompt_injection_ignored=True,
        expect_guard_blocked=True,
    ),
    GoldenExpectation(
        fixture_name="prompt_injection_metadata",
        expected_render_mode="narrative",
        expected_document_class="lpp_certificate",
        expected_extraction_status="success",
        is_adversarial=True,
        expect_prompt_injection_ignored=True,
        expect_guard_blocked=True,
    ),
    GoldenExpectation(
        fixture_name="prompt_injection_svg_overlay",
        expected_render_mode="narrative",
        expected_document_class="lpp_certificate",
        expected_extraction_status="success",
        is_adversarial=True,
        expect_prompt_injection_ignored=True,
        expect_guard_blocked=True,
    ),
    GoldenExpectation(
        fixture_name="sanity_rendement_15pct",
        expected_render_mode="reject",
        expected_document_class="lpp_certificate",
        # After sanity force-reject, extraction_status is downgraded from
        # success to parse_error (see understand_document step 5a).
        expected_extraction_status="parse_error",
        is_adversarial=True,
        expect_sanity_verdict="reject",
    ),
    GoldenExpectation(
        fixture_name="sanity_salaire_3M",
        expected_render_mode="reject",
        expected_document_class="salary_certificate",
        expected_extraction_status="parse_error",
        is_adversarial=True,
        expect_sanity_verdict="reject",
    ),
    GoldenExpectation(
        fixture_name="sanity_taux_conv_8pct",
        expected_render_mode="reject",
        expected_document_class="lpp_certificate",
        expected_extraction_status="parse_error",
        is_adversarial=True,
        expect_sanity_verdict="reject",
    ),
    GoldenExpectation(
        fixture_name="sanity_avoir_lpp_7M",
        # 7M avoir is legal but rare — flagged human_review, NOT rejected.
        expected_render_mode="confirm",  # overall 0.88 + all high-conf + ≤8 fields → confirm
        expected_document_class="lpp_certificate",
        expected_extraction_status="success",
        is_adversarial=True,
        expect_sanity_verdict="human_review",
    ),
]


__all__ = ["GoldenExpectation", "GOLDEN_EXPECTATIONS"]
