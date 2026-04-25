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
