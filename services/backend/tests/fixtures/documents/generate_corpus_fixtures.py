"""Generate the 10 primary Phase 30 corpus fixtures (GATE-03).

Reproducible, PII-clean. Reruns produce byte-similar output (pymupdf embeds
timestamps so bytes are not identical, but the CONTENT is stable — our CI
asserts content, not hash).

All identifiers are synthetic / reserved test ranges:
    - AVS 756.0000.0000.01 — valid mod-11 but unassigned (reserved test)
    - IBAN CH93 0076 2011 6238 5295 7 — valid mod-97 (test-doc reserved)
    - Names: "Jean TESTUSER", "Marie TESTUSER-SECOND" — never match real humans

Rebuild::

    cd services/backend
    .venv/bin/python tests/fixtures/documents/generate_corpus_fixtures.py

Verify (list all fixtures)::

    .venv/bin/python tests/fixtures/documents/generate_corpus_fixtures.py --verify

The adversarial fixtures (prompt_injection_*.pdf, sanity_*.pdf) are owned
by Phase 29-04 (``scripts/generate_adversarial_fixtures.py``) and must
NOT be regenerated here.
"""
from __future__ import annotations

import os
import sys
from io import BytesIO
from typing import Callable

import pymupdf  # type: ignore
from PIL import Image, ImageDraw, ImageFilter, ImageFont

FIXTURE_DIR = os.path.abspath(os.path.dirname(__file__))

# ---------------------------------------------------------------------------
# Synthetic identifiers — all PII-clean. Documented in README.md.
# ---------------------------------------------------------------------------

DUMMY_NAME_JULIEN = "Jean TESTUSER"
DUMMY_NAME_LAUREN = "Marie TESTUSER-SECOND"
DUMMY_AVS = "756.0000.0000.01"  # valid mod-11 checksum, reserved test range
DUMMY_IBAN = "CH93 0076 2011 6238 5295 7"  # valid mod-97, reserved test doc IBAN
DUMMY_EMPLOYER_PREFIX = "Employeur Test"

PRIMARY_FIXTURES = [
    "cpe_plan_maxi_julien.pdf",
    "hotela_lauren.pdf",
    "avs_ik_extract.pdf",
    "salary_certificate_afc.pdf",
    "tax_declaration_vs_julien.pdf",
    "us_w2_lauren.pdf",
    "crumpled_scan.jpg",
    "angled_photo_iban.jpg",
    "mobile_banking_screenshot.png",
    "german_insurance_letter.pdf",
]


# ---------------------------------------------------------------------------
# PDF helpers — mirrors scripts/generate_adversarial_fixtures.py conventions.
# ---------------------------------------------------------------------------


def _new_doc(meta_extra: dict | None = None) -> pymupdf.Document:
    doc = pymupdf.open()
    meta = {
        "title": "MINT synthetic corpus fixture",
        "author": "MINT corpus generator",
        "subject": "Phase 30 golden flow fixture",
        "keywords": "synthetic; fixture; phase30",
        "creator": "MINT corpus generator",
        "producer": "pymupdf",
    }
    if meta_extra:
        meta.update(meta_extra)
    doc.set_metadata(meta)
    return doc


def _write_block(page: pymupdf.Page, text: str, *, y0: int = 72, fontsize: int = 11,
                 color=(0, 0, 0), fontname: str = "helv") -> None:
    rect = pymupdf.Rect(50, y0, page.rect.width - 50, page.rect.height - 40)
    page.insert_textbox(rect, text, fontsize=fontsize, color=color, fontname=fontname)


# ---------------------------------------------------------------------------
# 1. CPE Plan Maxi — Julien LPP certificate (Romande)
# ---------------------------------------------------------------------------


def build_cpe_plan_maxi_julien(path: str) -> None:
    body = (
        "Caisse de Pensions de l'Etat (CPE) — Plan Maxi\n"
        "Certificat de prevoyance annuel 2026\n"
        "\n"
        f"Assure: {DUMMY_NAME_JULIEN}\n"
        f"No AVS: {DUMMY_AVS}\n"
        "Date de naissance: 12.01.1977\n"
        "Canton: Valais (VS)\n"
        "Plan: CPE Plan Maxi (rémunération 5 %)\n"
        "\n"
        "Donnees salariales:\n"
        "  Salaire annuel declare: 122'207 CHF\n"
        "  Salaire assure LPP:      91'967 CHF\n"
        "  Part obligatoire:        62'475 CHF\n"
        "  Part surobligatoire:     29'492 CHF\n"
        "\n"
        "Avoir de vieillesse:\n"
        "  Avoir total au 31.12.2025:  70'377 CHF\n"
        "  dont part obligatoire:      52'000 CHF\n"
        "  dont part surobligatoire:   18'377 CHF\n"
        "\n"
        "Bonification de vieillesse: 24 % (Plan Maxi)\n"
        "Taux de conversion (65 ans): 6.8 %\n"
        "Rachat maximum possible:      539'414 CHF\n"
        "\n"
        "Hypothese de rendement utilisee: 5.0 % p.a.\n"
        "Sources: LPP art. 14-16, OPP2 art. 5.\n"
        "\n"
        "(Fixture synthetique MINT — aucune donnee reelle.)"
    )
    doc = _new_doc({"title": "CPE Plan Maxi — certificat 2026"})
    page = doc.new_page(width=595, height=842)
    _write_block(page, body, y0=60, fontsize=10)
    doc.save(path)
    doc.close()


# ---------------------------------------------------------------------------
# 2. HOTELA Lauren — LPP certificate with US citizen marker (FATCA)
# ---------------------------------------------------------------------------


def build_hotela_lauren(path: str) -> None:
    body = (
        "HOTELA Fondation LPP\n"
        "Certificat de prevoyance annuel 2026\n"
        "\n"
        f"Assuree: {DUMMY_NAME_LAUREN}\n"
        f"No AVS: {DUMMY_AVS}\n"
        "Date de naissance: 23.06.1982\n"
        "Canton: Valais (VS)\n"
        "Nationalite: USA (FATCA declaree)\n"
        "\n"
        "Donnees salariales:\n"
        "  Salaire annuel:   67'000 CHF\n"
        "  Salaire assure:   40'540 CHF\n"
        "\n"
        "Avoir de vieillesse:\n"
        "  Avoir total au 31.12.2025: 19'620 CHF\n"
        "  Rachat maximum possible:   52'949 CHF\n"
        "\n"
        "Bonification de vieillesse: 10 %\n"
        "Taux de conversion (65 ans): 6.8 %\n"
        "\n"
        "Marqueur FATCA: contribuable US. Reporting IRS requis.\n"
        "Sources: LPP art. 14-16.\n"
        "\n"
        "(Fixture synthetique MINT — aucune donnee reelle.)"
    )
    doc = _new_doc({"title": "HOTELA — certificat LPP 2026"})
    page = doc.new_page(width=595, height=842)
    _write_block(page, body, y0=60, fontsize=10)
    doc.save(path)
    doc.close()


# ---------------------------------------------------------------------------
# 3. AVS IK extract — Office cantonal VS
# ---------------------------------------------------------------------------


def build_avs_ik_extract(path: str) -> None:
    lines = [
        "Office cantonal des assurances sociales — Etat du Valais",
        "Extrait du compte individuel AVS (IK)",
        "",
        f"Titulaire: {DUMMY_NAME_JULIEN}",
        f"No AVS: {DUMMY_AVS}",
        "",
        "Annee | Employeur                  | Revenu cotisant (CHF)",
        "------+----------------------------+----------------------",
    ]
    amounts = [95000, 97500, 100000, 103500, 108000, 111000, 114500, 117000, 119500, 122207]
    for idx, (year, amount) in enumerate(zip(range(2016, 2026), amounts), start=1):
        emp = f"{DUMMY_EMPLOYER_PREFIX} {idx}".ljust(27)
        lines.append(f" {year} | {emp}|          {amount:>7}")
    lines.extend([
        "",
        "Total cotisations sur 10 annees: verifiable a l'inscription.",
        "Sources: LAVS art. 30ter, OAVS art. 141.",
        "",
        "(Fixture synthetique MINT — aucune donnee reelle.)",
    ])
    body = "\n".join(lines)
    doc = _new_doc({"title": "Extrait AVS IK — VS"})
    page = doc.new_page(width=595, height=842)
    _write_block(page, body, y0=60, fontsize=10, fontname="cour")
    doc.save(path)
    doc.close()


# ---------------------------------------------------------------------------
# 4. Salary certificate AFC 2025
# ---------------------------------------------------------------------------


def build_salary_certificate_afc(path: str) -> None:
    body = (
        "Administration federale des contributions (AFC)\n"
        "Certificat de salaire annuel 2025\n"
        "\n"
        f"Titulaire: {DUMMY_NAME_JULIEN}\n"
        f"No AVS: {DUMMY_AVS}\n"
        "Canton: VS\n"
        f"Employeur: {DUMMY_EMPLOYER_PREFIX} 10\n"
        "\n"
        "Donnees annuelles:\n"
        "  Salaire brut:              122'207 CHF\n"
        "  AVS / AI / APG (5.30 %):     6'473 CHF\n"
        "  LPP (cotisation employe):    9'197 CHF\n"
        "  Assurance maladie / accident: 1'250 CHF\n"
        "  Impot a la source:               0 CHF\n"
        "  Salaire net:                98'340 CHF\n"
        "\n"
        "Sources: LIFD art. 17, OFAS certificat salaire.\n"
        "\n"
        "(Fixture synthetique MINT — aucune donnee reelle.)"
    )
    doc = _new_doc({"title": "Certificat salaire AFC 2025"})
    page = doc.new_page(width=595, height=842)
    _write_block(page, body, y0=60, fontsize=10)
    doc.save(path)
    doc.close()


# ---------------------------------------------------------------------------
# 5. Tax declaration VS — multi-page
# ---------------------------------------------------------------------------


def build_tax_declaration_vs_julien(path: str) -> None:
    doc = _new_doc({"title": "Declaration fiscale VS 2025"})
    page1 = doc.new_page(width=595, height=842)
    _write_block(
        page1,
        "Service cantonal des contributions — Valais\n"
        "Declaration d'impot 2025 — personne physique\n"
        "\n"
        f"Contribuable: {DUMMY_NAME_JULIEN}\n"
        f"No AVS: {DUMMY_AVS}\n"
        "Etat civil: marie\n"
        "Canton: VS (Sion)\n"
        "\n"
        "Page 1 / 3 — identite et situation familiale.\n"
        "\n"
        "Conjoint: declare.\n"
        "Enfants a charge: 0.\n"
        "\n"
        "(Fixture synthetique MINT.)",
        fontsize=10,
    )
    page2 = doc.new_page(width=595, height=842)
    _write_block(
        page2,
        "Page 2 / 3 — revenus.\n"
        "\n"
        "Revenu brut du travail:       122'207 CHF\n"
        "Allocations familiales:             0 CHF\n"
        "Rentes / pensions:                  0 CHF\n"
        "Revenus immobiliers:                0 CHF\n"
        "\n"
        "Deductions:\n"
        "  3e pilier A (LIFD art. 33):   7'258 CHF\n"
        "  LPP rachat volontaire:       20'000 CHF\n"
        "  Frais professionnels:         3'000 CHF\n"
        "  Primes assurance maladie:     4'800 CHF\n"
        "\n"
        "Revenu imposable: 112'400 CHF.\n",
        fontsize=10,
    )
    page3 = doc.new_page(width=595, height=842)
    _write_block(
        page3,
        "Page 3 / 3 — fortune.\n"
        "\n"
        "Epargne bancaire:             28'500 CHF\n"
        "Avoirs 3e pilier A:           32'000 CHF\n"
        "Titres et placements:         88'500 CHF\n"
        "Vehicule:                      9'000 CHF\n"
        "Assurance-vie rachat:         90'000 CHF\n"
        "\n"
        "Fortune imposable: 248'000 CHF.\n"
        "\n"
        "Sources: LIFD art. 7, LI-VS art. 12-15.\n"
        "\n"
        "(Fixture synthetique MINT.)",
        fontsize=10,
    )
    doc.save(path)
    doc.close()


# ---------------------------------------------------------------------------
# 6. US W-2 — Lauren (non-Swiss, expected reject)
# ---------------------------------------------------------------------------


def build_us_w2_lauren(path: str) -> None:
    body = (
        "FORM W-2 — Wage and Tax Statement (2025)\n"
        "Internal Revenue Service — Department of the Treasury\n"
        "\n"
        f"Employee: {DUMMY_NAME_LAUREN}\n"
        "SSN: XXX-XX-0000 (synthetic)\n"
        "Employer: Testcorp LLC, New York, NY (EIN 00-0000000)\n"
        "\n"
        "Box 1  Wages, tips, other compensation: 72'000 USD\n"
        "Box 2  Federal income tax withheld:     11'200 USD\n"
        "Box 3  Social security wages:           72'000 USD\n"
        "Box 4  Social security tax withheld:     4'464 USD\n"
        "Box 5  Medicare wages:                  72'000 USD\n"
        "Box 15 State: NY\n"
        "Box 17 State income tax:                 3'825 USD\n"
        "\n"
        "This is a United States tax document. It is not a Swiss financial\n"
        "document. MINT cannot structure US tax forms.\n"
        "\n"
        "(Fixture synthetique MINT — aucune donnee reelle.)"
    )
    doc = _new_doc({"title": "US W-2 2025 — synthetic"})
    page = doc.new_page(width=595, height=842)
    _write_block(page, body, y0=60, fontsize=10)
    doc.save(path)
    doc.close()


# ---------------------------------------------------------------------------
# Image helpers (Pillow)
# ---------------------------------------------------------------------------


def _load_font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    # Try a commonly-installed TTF; fall back to PIL default bitmap font.
    for candidate in (
        "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    ):
        if os.path.exists(candidate):
            try:
                return ImageFont.truetype(candidate, size)
            except Exception:
                pass
    return ImageFont.load_default()


def _draw_text(img: Image.Image, text: str, *, xy=(40, 40), fontsize: int = 20,
               fill=(20, 20, 20)) -> None:
    draw = ImageDraw.Draw(img)
    font = _load_font(fontsize)
    draw.multiline_text(xy, text, fill=fill, font=font, spacing=4)


# ---------------------------------------------------------------------------
# 7. Crumpled scan (JPEG, noisy + rotated)
# ---------------------------------------------------------------------------


def build_crumpled_scan(path: str) -> None:
    img = Image.new("RGB", (1200, 1600), (245, 241, 234))  # off-white
    body = (
        "Caisse de Pensions Cantonale\n"
        "Certificat LPP 2026 — copie scannee\n"
        "\n"
        f"Assure: {DUMMY_NAME_JULIEN}\n"
        f"No AVS: {DUMMY_AVS}\n"
        "\n"
        "Salaire assure:         91'967 CHF\n"
        "Avoir de vieillesse:    70'000 CHF (approx.)\n"
        "Taux de conversion:     6.8 %\n"
        "Bonification:           20 %\n"
        "\n"
        "(Fixture synthetique MINT — scan froisse.)"
    )
    _draw_text(img, body, xy=(80, 120), fontsize=28)
    # Noise overlay (deterministic checkerboard-like pattern, no RNG)
    pixels = img.load()
    for y in range(0, img.height, 7):
        for x in range(0, img.width, 9):
            if (x * y) % 37 == 0:
                pixels[x, y] = (230, 224, 214)
    # Mild blur + slight rotation to simulate a phone-scanned doc.
    img = img.filter(ImageFilter.GaussianBlur(radius=0.8))
    img = img.rotate(-3, resample=Image.BICUBIC, fillcolor=(252, 250, 246))
    img.save(path, "JPEG", quality=72, optimize=True)


# ---------------------------------------------------------------------------
# 8. Angled photo with IBAN visible
# ---------------------------------------------------------------------------


def build_angled_photo_iban(path: str) -> None:
    img = Image.new("RGB", (1200, 1600), (250, 248, 244))
    body = (
        "Banque Synthetique SA\n"
        "Releve de compte courant — 03.2026\n"
        "\n"
        f"Titulaire: {DUMMY_NAME_JULIEN}\n"
        f"IBAN: {DUMMY_IBAN}\n"
        f"No AVS: {DUMMY_AVS}\n"
        "\n"
        "Solde au 01.03.2026:     12'430.55 CHF\n"
        "Salaire credite mensuel:  8'000.00 CHF\n"
        "Loyer debite mensuel:     2'200.00 CHF\n"
        "\n"
        "(Fixture synthetique MINT — photo angle.)"
    )
    _draw_text(img, body, xy=(90, 140), fontsize=30)
    img = img.rotate(-8, resample=Image.BICUBIC, fillcolor=(252, 250, 246))
    img.save(path, "JPEG", quality=70, optimize=True)


# ---------------------------------------------------------------------------
# 9. Mobile banking screenshot (PNG, iPhone aspect)
# ---------------------------------------------------------------------------


def build_mobile_banking_screenshot(path: str) -> None:
    img = Image.new("RGB", (750, 1334), (248, 250, 252))
    # Top bar
    draw = ImageDraw.Draw(img)
    draw.rectangle([0, 0, 750, 120], fill=(16, 32, 72))
    _draw_text(img, "Mobile Banking", xy=(30, 42), fontsize=30, fill=(255, 255, 255))
    body_top = (
        "Compte courant\n"
        "Solde disponible:\n"
        "CHF 4'523.50\n"
    )
    _draw_text(img, body_top, xy=(30, 170), fontsize=26)
    body_mid = (
        "Dernieres transactions\n"
        "---------------------------------\n"
        f"IBAN: {DUMMY_IBAN}\n"
        "\n"
        "-03.04  Loyer                 -2'200.00\n"
        "-02.04  Supermarche             -124.85\n"
        "-01.04  Salaire credite      +4'900.00\n"
        "-29.03  Assurance LAMal        -312.40\n"
        "-28.03  Cafe & restaurant       -48.20\n"
    )
    _draw_text(img, body_mid, xy=(30, 360), fontsize=22)
    _draw_text(
        img,
        "(Fixture synthetique MINT — capture d'ecran.)",
        xy=(30, 1240), fontsize=18, fill=(120, 130, 140),
    )
    img.save(path, "PNG", optimize=True)


# ---------------------------------------------------------------------------
# 10. German insurance letter (PDF)
# ---------------------------------------------------------------------------


def build_german_insurance_letter(path: str) -> None:
    body = (
        "Swiss Synthetic Lebensversicherung AG\n"
        "Zurich, 01.03.2026\n"
        "\n"
        f"Versicherter: {DUMMY_NAME_JULIEN}\n"
        f"AHV-Nummer: {DUMMY_AVS}\n"
        "\n"
        "Sehr geehrte Damen und Herren,\n"
        "\n"
        "hiermit bestaetigen wir die Fortfuehrung Ihrer\n"
        "Lebensversicherung (gemischte Versicherung, Saeule 3b).\n"
        "\n"
        "Jahresprämie:       1'200 CHF\n"
        "Versicherungssumme: 150'000 CHF\n"
        "Ablaufdatum:        31.12.2045\n"
        "Rueckkaufswert 2026:  8'450 CHF\n"
        "\n"
        "Mit freundlichen Gruessen\n"
        "Swiss Synthetic Lebensversicherung AG\n"
        "\n"
        "(Synthetische MINT-Fixture — keine echten Daten.)"
    )
    doc = _new_doc({"title": "Lebensversicherung Bestaetigung"})
    page = doc.new_page(width=595, height=842)
    _write_block(page, body, y0=60, fontsize=10)
    doc.save(path)
    doc.close()


# ---------------------------------------------------------------------------
# Orchestration
# ---------------------------------------------------------------------------


_BUILDERS: dict[str, Callable[[str], None]] = {
    "cpe_plan_maxi_julien.pdf": build_cpe_plan_maxi_julien,
    "hotela_lauren.pdf": build_hotela_lauren,
    "avs_ik_extract.pdf": build_avs_ik_extract,
    "salary_certificate_afc.pdf": build_salary_certificate_afc,
    "tax_declaration_vs_julien.pdf": build_tax_declaration_vs_julien,
    "us_w2_lauren.pdf": build_us_w2_lauren,
    "crumpled_scan.jpg": build_crumpled_scan,
    "angled_photo_iban.jpg": build_angled_photo_iban,
    "mobile_banking_screenshot.png": build_mobile_banking_screenshot,
    "german_insurance_letter.pdf": build_german_insurance_letter,
}


MAX_SIZE_BYTES = 200 * 1024  # 200 KB


def generate_all(target_dir: str = FIXTURE_DIR) -> list[tuple[str, int]]:
    out: list[tuple[str, int]] = []
    for name, builder in _BUILDERS.items():
        path = os.path.join(target_dir, name)
        builder(path)
        size = os.path.getsize(path)
        out.append((name, size))
    return out


def verify(target_dir: str = FIXTURE_DIR) -> int:
    missing = []
    oversized = []
    for name in PRIMARY_FIXTURES:
        path = os.path.join(target_dir, name)
        if not os.path.exists(path):
            missing.append(name)
            continue
        size = os.path.getsize(path)
        if size > MAX_SIZE_BYTES:
            oversized.append((name, size))
    if missing:
        print(f"MISSING ({len(missing)}): {missing}", file=sys.stderr)
    if oversized:
        print(f"OVERSIZED (> {MAX_SIZE_BYTES} B): {oversized}", file=sys.stderr)
    if missing or oversized:
        return 1
    print(f"OK — {len(PRIMARY_FIXTURES)} fixtures present, all < 200 KB")
    return 0


def main(argv: list[str]) -> int:
    if len(argv) > 1 and argv[1] == "--verify":
        return verify()
    results = generate_all()
    print(f"Generated {len(results)} fixtures in {FIXTURE_DIR}:")
    for name, size in results:
        marker = "!" if size > MAX_SIZE_BYTES else " "
        print(f"  {marker} {name:40s}  {size:>7} B")
    # Warn on oversized but do not fail — caller can tune content if needed.
    over = [r for r in results if r[1] > MAX_SIZE_BYTES]
    if over:
        print(f"WARNING: {len(over)} fixtures exceed 200 KB: {[n for n, _ in over]}",
              file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
