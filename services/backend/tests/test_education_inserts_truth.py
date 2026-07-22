"""Véracité des inserts éducatifs RAG (beads MINT_nosync-5ba, audit T15-F23/F24).

Ces fichiers sont ingérés (category=education_insert) et servis aux
utilisateurs — les nombres doivent coller aux Mémentos officiels.
Doctrine 2025/2026 (OFAS/AFC, vérifiée 2026-07-22) :
  - LPP : limite supérieure 90'720, coordonné max 64'260 (identiques 25/26).
  - Donations descendants directs : taxées UNIQUEMENT dans AI (1%),
    NE (3%, franchise 10k/an) et VD (au-delà de 300k/an/enfant/parent).
"""
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
LPP = REPO / "services" / "backend" / "education_inserts" / "concepts" / "lpp_salaire_coordonne.md"
DON = REPO / "services" / "backend" / "education_inserts" / "concepts" / "donation_entre_vifs.md"


def test_lpp_coordonne_max_is_2025_doctrine():
    t = LPP.read_text(encoding="utf-8")
    assert "64'260" in t, "coordonné max 2025 = 90'720 - 26'460 = 64'260"
    assert "90'720" in t
    assert "36'015" not in t, "ancien calcul auto-contradictoire (62'475-26'460)"
    assert "62'475" not in t
    assert "88'200" not in t, "88'200 = limite supérieure 2024, périmée"


def test_donation_direct_line_taxing_cantons():
    t = DON.read_text(encoding="utf-8")
    low = t.lower()
    # Les 3 cantons taxant la ligne directe doivent être présentés comme tels.
    for canton in ("AI", "NE", "VD"):
        assert canton in t
    # NE et VD ne doivent PAS figurer dans une liste « sans impôt descendants ».
    import re
    m = re.search(r"sans imp[oô]t sur donation aux descendants\s*:\s*([^\n]+)", low)
    if m:
        exempt_list = m.group(1).upper()
        for canton in ("NE", "VD", "AI"):
            assert canton not in exempt_list, f"{canton} taxe la ligne directe"


def test_copies_are_synced():
    for name in ("lpp_salaire_coordonne.md", "donation_entre_vifs.md"):
        a = (REPO / "services" / "backend" / "education_inserts" / "concepts" / name).read_bytes()
        b = (REPO / "education" / "inserts" / "concepts" / name).read_bytes()
        assert a == b, f"copies désynchronisées: {name}"
