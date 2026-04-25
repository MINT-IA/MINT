"""Golden fixture: LPPCertificateExtractor MUST correctly read Julien's
real CPE Plan Maxi certificate.

This test is the ground-truth anchor for the extraction pipeline. Every
value below was read manually from the real PDF (CPE Caisse de Pension
Energie, certificat au 08.03.2026, Julien Battaglia, FMV SA, Plan Maxi).

If any regex change breaks one of these assertions, the test fails with
a clear diff so we know exactly which field drifted.

Failures of this test invalidate every downstream claim the coach makes
about Julien's situation — this is the fixture we can never regress.
"""

from pathlib import Path

import pytest

from app.services.docling.parser import DocumentParser
from app.services.docling.extractors.lpp_certificate import LPPCertificateExtractor


JULIEN_CERT = (
    Path(__file__).parent.parent.parent.parent
    / "test"
    / "golden"
    / "Julien"
    / "Télécharger le certificat de prévoyance.pdf"
)


@pytest.fixture(scope="module")
def extracted():
    if not JULIEN_CERT.is_file():
        pytest.skip("Real CPE cert fixture not present")
    with open(JULIEN_CERT, "rb") as fh:
        parsed = DocumentParser().parse_pdf(fh.read())
    tables = [t for page in parsed.pages for t in page.tables]
    return LPPCertificateExtractor().extract(parsed.full_text, tables)


def test_caisse_name_is_cpe_not_phone(extracted):
    """Caisse name must be the pension institution, never the phone line."""
    assert extracted.caisse_name is not None
    assert "Caisse de Pension" in extracted.caisse_name
    assert "Téléphone" not in extracted.caisse_name
    assert "+41" not in extracted.caisse_name


def test_avoir_vieillesse_total_reads_prestation_de_sortie(extracted):
    """CPE label 'Prestation de sortie au DATE' → avoir_vieillesse_total.

    Real PDF: 'Avoir de vieillesse 70'376.60' / 'Prestation de sortie au
    08.03.2026 70'376.60'. The extractor had been returning None because
    the regex only looked for 'avoir total' wording.
    """
    assert extracted.avoir_vieillesse_total == 70376.60


def test_salaire_assure_picks_base_column_not_bonus(extracted):
    """CPE bi-column layout: 'Bonus  Base' → Base is authoritative (91'967)."""
    # User confirmed: 91'967 is correct, 3'974.40 is the Bonus column.
    assert extracted.salaire_assure == 91967.0


def test_rachat_maximum_from_retraite_ordinaire_line(extracted):
    """Rachat max at age 65 (LPP art. 79b) = 539'413.70.

    Previously the extractor mis-labeled this number as capital_deces
    because it matched 'capital décès' in the règlement boilerplate and
    then grabbed the next number (which happened to be the rachat figure).
    """
    assert extracted.rachat_maximum == 539413.70


def test_capital_deces_not_confused_with_rachat(extracted):
    """CPE cert does NOT print a literal capital décès figure — the
    boilerplate says 'Les dispositions s'appliquent au capital décès',
    which must not be hijacked to steal the next unrelated amount."""
    # Either cleanly None (preferred — cert doesn't print a single figure)
    # or, if matched, must not be the rachat amount.
    if extracted.capital_deces is not None:
        assert extracted.capital_deces != 539413.70, (
            "Regression: capital_deces is matching the rachat number again."
        )


def test_rente_invalidite_picks_base_column(extracted):
    """Bonus 2'388 / Base 55'188 → Base is authoritative for projection."""
    assert extracted.rente_invalidite_annuelle == 55188.0


def test_rente_conjoint_picks_base_column(extracted):
    """Bonus 1'596 / Base 36'792 → Base is authoritative."""
    assert extracted.rente_conjoint_annuelle == 36792.0


def test_date_certificat_read_correctly(extracted):
    assert extracted.date_certificat == "08.03.2026"


def test_minimum_fields_extracted(extracted):
    """After the patches, a real certificate should yield >=7 fields."""
    assert extracted.extracted_fields_count >= 7
    assert extracted.confidence >= 0.55


# ── Coverage uplift 2026-04-25 ──────────────────────────────────────
# The 6 assertions below were added after running the extractor against
# the 6 PDF Julien golden corpus and finding 10/18 fields silently
# missed (assure_name, avoir_obligatoire, salaire_avs, taux_conversion,
# cotisations). All of them MUST now extract or the regression fires.


def test_assure_name_is_julien_battaglia(extracted):
    """Header heuristic: first 600 chars of cert contain 'Julien Battaglia'.

    Pre-fix, assure_name was always None — the extractor had no name
    pattern at all. Now extracted via header-line scan that excludes
    caisse / certificat noise tokens.
    """
    assert extracted.assure_name is not None
    name_norm = extracted.assure_name.lower()
    assert "julien" in name_norm
    assert "battaglia" in name_norm


def test_avoir_vieillesse_obligatoire_from_lpp_label(extracted):
    """CPE notes 'Avoir de vieillesse LPP 30'243.80' → obligatoire part.

    Pre-fix, the YAML/dict only matched 'avoir vieillesse obligatoire'
    keyword which never appears in CPE certs. The 'lpp' suffix variant
    is now in the dict.
    """
    assert extracted.avoir_vieillesse_obligatoire == 30243.80


def test_avoir_vieillesse_surobligatoire_derived(extracted):
    """Comptable identity: total - obligatoire = surobligatoire.

    CPE doesn't print this explicitly. The extractor derives it post-
    extraction. 70'376.60 - 30'243.80 = 40'132.80.
    """
    assert extracted.avoir_vieillesse_surobligatoire == 40132.80


def test_salaire_avs_from_salaire_determinant(extracted):
    """CPE label 'Salaire déterminant 0.00 122'206.80' → AVS gross.

    The 'Bonus | Base' bi-column means Base = 122'206.80 is the AVS
    gross. Pre-fix, this field was None — pattern only matched
    'salaire avs' literal which CPE never uses.
    """
    assert extracted.salaire_avs == 122206.80


def test_deduction_coordination_derived(extracted):
    """LPP art. 8 al. 2: déduction de coordination = AVS - assuré.

    122'206.80 - 91'967.00 = 30'239.80. Derived post-extraction since
    CPE doesn't print this number explicitly.
    """
    assert extracted.deduction_coordination == 30239.80


def test_taux_conversion_at_age_65(extracted):
    """CPE projection table row 'âge 65 5.00%' is the displayed
    conversion rate. Stored as taux_conversion_enveloppe since CPE
    doesn't separate obligatoire vs surobligatoire."""
    assert extracted.taux_conversion_enveloppe == 5.00
    # Must not pick the age-64 row by accident (was 4.87% — common bug).
    assert extracted.taux_conversion_enveloppe != 4.87


def test_cotisation_employe_sums_risque_plus_epargne(extracted):
    """CPE 'Cotisations du salarié par an' block:
        risque 91.80 + épargne 13'868.40 = 13'960.20 (Base column sum).
    """
    assert extracted.cotisation_employe_annuelle == 13960.20


def test_cotisation_employeur_sums_risque_plus_epargne(extracted):
    """CPE 'Cotisations de l'employeur par an' block:
        risque 138.00 + épargne 15'276.00 = 15'414.00 (Base column sum).
    """
    assert extracted.cotisation_employeur_annuelle == 15414.00


def test_full_certificate_yields_at_least_15_fields(extracted):
    """Coverage floor on the full Julien CPE cert: 15/18 fields.

    The 3 always-missing fields are by-design CPE limitations:
      - taux_conversion_obligatoire / surobligatoire (CPE folds them
        into a single rate displayed in the projection table)
      - capital_deces (CPE doesn't print a single figure for this)

    Anything below 15 is a regression.
    """
    assert extracted.extracted_fields_count >= 15, (
        f"coverage drop: {extracted.extracted_fields_count}/18 "
        f"(was 15/18 after 2026-04-25 uplift)"
    )
    assert extracted.confidence >= 0.94


# ── Unit tests for the new helpers (edge cases / coverage uplift) ───
# These exercise paths that the integration test on Julien's PDF doesn't
# hit (None returns, fallback ages, parser errors, role disambiguation).


class TestExtractAssureName:
    """Edge cases for `_extract_assure_name` static helper."""

    def test_returns_none_when_text_empty(self):
        assert LPPCertificateExtractor._extract_assure_name("") is None

    def test_returns_none_when_only_caisse_header(self):
        # All lines look like noise headers — must NOT pick anything.
        text = (
            "Caisse de Pension Energie\n"
            "Certificat de prévoyance\n"
            "Données personnelles\n"
        )
        assert LPPCertificateExtractor._extract_assure_name(text) is None

    def test_skips_lines_with_digits(self):
        text = (
            "Caisse de Pension Energie\n"
            "Téléphone 0212347688\n"
            "Some Person\n"
            "1950 Sion\n"
        )
        # "Some Person" matches 2-token capitalised, no digits → picked.
        assert LPPCertificateExtractor._extract_assure_name(text) == "Some Person"

    def test_ignores_three_token_lines(self):
        text = (
            "Caisse de Pension Energie\n"
            "Pierre Marc Dupont\n"  # 3 tokens — must be skipped
            "Anne Martin\n"  # 2 tokens — picked
        )
        assert LPPCertificateExtractor._extract_assure_name(text) == "Anne Martin"

    def test_only_first_600_chars_searched(self):
        text = "X\n" * 700 + "Anne Martin\n"
        # The "Anne Martin" line is past 600 chars, must NOT be matched.
        assert LPPCertificateExtractor._extract_assure_name(text) is None


class TestExtractAge65ConversionRate:
    """Edge cases for `_extract_age65_conversion_rate` static helper."""

    def test_returns_none_when_no_age_row(self):
        assert LPPCertificateExtractor._extract_age65_conversion_rate("") is None
        assert (
            LPPCertificateExtractor._extract_age65_conversion_rate(
                "no age row here"
            )
            is None
        )

    def test_picks_age_65_over_age_64(self):
        text = "âge 64 4.87%\nâge 65 5.00%"
        rate = LPPCertificateExtractor._extract_age65_conversion_rate(text)
        assert rate == 5.00

    def test_falls_back_to_age_64_when_65_absent(self):
        text = "âge 64 4.87%"
        rate = LPPCertificateExtractor._extract_age65_conversion_rate(text)
        assert rate == 4.87

    def test_range_guard_rejects_out_of_band_values(self):
        # 2.50% is below the 3% floor — must be rejected.
        text = "âge 65 2.50%"
        assert (
            LPPCertificateExtractor._extract_age65_conversion_rate(text) is None
        )
        # 9.00% above 8% ceiling — also rejected.
        text = "âge 65 9.00%"
        assert (
            LPPCertificateExtractor._extract_age65_conversion_rate(text) is None
        )

    def test_handles_comma_decimal_separator(self):
        text = "âge 65 5,25%"
        rate = LPPCertificateExtractor._extract_age65_conversion_rate(text)
        assert rate == 5.25

    def test_handles_german_alter_keyword(self):
        text = "Alter 65 5.00%"
        rate = LPPCertificateExtractor._extract_age65_conversion_rate(text)
        assert rate == 5.00


class TestExtractCpeCotisationBlock:
    """Edge cases for `_extract_cpe_cotisation_block` static helper."""

    def test_returns_none_when_role_invalid(self):
        text = "Cotisations du salarié par an\n  Cotisation de risque 4.20 91.80\n"
        # role argument restricted to 'salari' or 'employeur'.
        assert (
            LPPCertificateExtractor._extract_cpe_cotisation_block(
                text, role="bogus"
            )
            is None
        )

    def test_returns_none_when_header_absent(self):
        assert (
            LPPCertificateExtractor._extract_cpe_cotisation_block(
                "no cotisation block", role="salari"
            )
            is None
        )

    def test_employee_block_sums_base_column(self):
        text = (
            "Cotisations du salarié par an Bonus Base\n"
            "  Cotisation de risque  4.20  91.80\n"
            "  Cotisation d'épargne  0.00  13'868.40\n"
            "Cotisations de l'employeur par an Bonus Base\n"
            "  Cotisation de risque  6.00  138.00\n"
        )
        total = LPPCertificateExtractor._extract_cpe_cotisation_block(
            text, role="salari"
        )
        # Stops at next 'Cotisations … par an' header → only employee rows.
        assert total == 13960.20

    def test_employer_block_skipped_when_only_salari_present(self):
        text = (
            "Cotisations du salarié par an Bonus Base\n"
            "  Cotisation de risque  4.20  91.80\n"
        )
        # No employer header → returns None.
        assert (
            LPPCertificateExtractor._extract_cpe_cotisation_block(
                text, role="employeur"
            )
            is None
        )

    def test_returns_none_when_block_has_no_amount_rows(self):
        text = (
            "Cotisations du salarié par an Bonus Base\n"
            "  (no rows here)\n"
        )
        assert (
            LPPCertificateExtractor._extract_cpe_cotisation_block(
                text, role="salari"
            )
            is None
        )


class TestSurobligatoireDerivation:
    """The derivation in extract() runs post-extraction. Ensure it's
    skipped when surobligatoire is already present, and skipped when
    total <= obligatoire (would yield 0 or negative — bug indicator)."""

    def test_skipped_when_surobligatoire_already_set(self):
        # Build a fake text with EXPLICIT surobligatoire mention. The
        # extractor MUST keep that explicit value, not overwrite with
        # the derivation.
        text = (
            "Avoir de vieillesse total 100000\n"
            "Avoir de vieillesse obligatoire 30000\n"
            "Avoir de vieillesse surobligatoire 99999\n"
        )
        data = LPPCertificateExtractor().extract(text)
        # Explicit value wins over derivation.
        assert data.avoir_vieillesse_surobligatoire == 99999

    def test_derivation_skipped_when_total_le_obligatoire(self):
        # Pathological case: total < obligatoire (data corruption).
        # Extractor must not produce a negative surobligatoire.
        text = (
            "Avoir de vieillesse total 30000\n"
            "Avoir de vieillesse obligatoire 30000\n"
        )
        data = LPPCertificateExtractor().extract(text)
        assert data.avoir_vieillesse_surobligatoire is None


class TestDeductionCoordinationDerivation:
    def test_skipped_when_already_extracted(self):
        text = (
            "Salaire AVS 100000\n"
            "Salaire assuré 70000\n"
            "Déduction de coordination 25725\n"  # 25'725 = 2026 LPP value
        )
        data = LPPCertificateExtractor().extract(text)
        # Explicit coordination value wins.
        assert data.deduction_coordination == 25725

    def test_skipped_when_avs_le_assure(self):
        # Pathological: salaire_assure > salaire_avs (impossible per LPP).
        # Must NOT compute negative deduction.
        text = (
            "Salaire AVS 50000\n"
            "Salaire assuré 70000\n"
        )
        data = LPPCertificateExtractor().extract(text)
        assert data.deduction_coordination is None


# ── HOTELA / generic-cert patterns (PR S30.20) ──────────────────────


class TestHotelaCaissePatterns:
    """Regression: HOTELA uses 'Fondation LPP' as caisse type, has the
    date inline as 'Avoir total au DATE', and prints conversion rate
    as 'Taux de conversion (65 ans): X %'. None of these matched
    before 2026-04-25."""

    def test_caisse_name_matches_fondation_lpp(self):
        text = (
            "HOTELA Fondation LPP\n"
            "Certificat de prévoyance annuel 2026\n"
            "Salaire assuré: 40540 CHF\n"
        )
        data = LPPCertificateExtractor().extract(text)
        assert data.caisse_name is not None
        assert "Fondation LPP" in data.caisse_name

    def test_date_matches_avoir_total_au(self):
        text = (
            "Fondation LPP\n"
            "Avoir total au 31.12.2025: 19620 CHF\n"
        )
        data = LPPCertificateExtractor().extract(text)
        assert data.date_certificat == "31.12.2025"

    def test_avoir_total_without_vieillesse_word(self):
        """HOTELA omits 'vieillesse' between 'avoir' and 'total'."""
        text = (
            "HOTELA Fondation LPP\n"
            "Avoir total au 31.12.2025: 19'620 CHF\n"
        )
        data = LPPCertificateExtractor().extract(text)
        assert data.avoir_vieillesse_total == 19620.0

    def test_taux_conversion_with_age_in_parentheses(self):
        """HOTELA: 'Taux de conversion (65 ans): 6.8 %'."""
        text = (
            "Fondation LPP\n"
            "Taux de conversion (65 ans): 6.8 %\n"
        )
        data = LPPCertificateExtractor().extract(text)
        assert data.taux_conversion_enveloppe == 6.8

    def test_assure_name_skips_field_label_lines(self):
        """Lines with `:` are field labels, not names."""
        text = (
            "HOTELA Fondation LPP\n"
            "Certificat de prévoyance\n"
            "Canton: VS\n"
            "Marie Dupont\n"
            "Donnees salariales:\n"
        )
        data = LPPCertificateExtractor().extract(text)
        assert data.assure_name == "Marie Dupont"

    def test_assure_name_skips_short_acronym_tokens(self):
        """`VS Sion` should NOT be picked as name (`VS` is an acronym)."""
        text = (
            "HOTELA Fondation LPP\n"
            "VS Sion\n"
            "Marie Dupont\n"
        )
        data = LPPCertificateExtractor().extract(text)
        assert data.assure_name == "Marie Dupont"
