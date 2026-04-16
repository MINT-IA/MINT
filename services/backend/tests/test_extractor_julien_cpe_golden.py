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
