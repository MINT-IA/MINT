"""Véracité des inserts éducatifs RAG (beads MINT_nosync-5ba, audit T15-F23/F24).

Ces fichiers sont ingérés (category=education_insert) et servis aux
utilisateurs — les nombres doivent coller aux Mémentos officiels.
Doctrine 2025/2026 (OFAS/AFC + ai.ch/ne.ch/vd.ch/ge.ch, vérifiée 2026-07-22) :
  - LPP : limite supérieure 90'720, coordonné max 64'260 (identiques 25/26).
  - Donations descendants directs : barème UNIQUEMENT dans AI (1 %, franchise
    300k/enfant), NE (3 %, franchise 10k/an) et VD (au-delà de 300k/an/enfant/
    parent, depuis 2025) ; à GE l'exonération tombe pour l'imposition d'après
    la dépense (forfait fiscal). Un don de 100k n'est donc taxé qu'à NE.
Les assertions verrouillent les faits individuels (taux, franchises, listes),
pas la seule présence de tokens — mutation d'un chiffre = test rouge.
"""
import re
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
LPP = REPO / "services" / "backend" / "education_inserts" / "concepts" / "lpp_salaire_coordonne.md"
DON = REPO / "services" / "backend" / "education_inserts" / "concepts" / "donation_entre_vifs.md"

NBSP = " "


def test_lpp_coordonne_max_is_2025_doctrine():
    t = LPP.read_text(encoding="utf-8")
    assert "64'260" in t, "coordonné max 2025 = 90'720 - 26'460 = 64'260"
    assert "90'720" in t
    assert "36'015" not in t, "ancien calcul auto-contradictoire (62'475-26'460)"
    assert "62'475" not in t
    assert "88'200" not in t, "88'200 = limite supérieure 2024, périmée"


def test_donation_taxing_line_locks_rates_and_franchises():
    t = DON.read_text(encoding="utf-8")
    m = re.search(r"Cantons qui IMPOSENT[^\n]+", t)
    assert m, "ligne des cantons taxants absente"
    taxing = m.group(0)
    for fact in (
        f"AI (1{NBSP}%",
        "CHF 300'000 par enfant",
        f"NE (3{NBSP}%",
        "CHF 10'000 par an et par donataire",
        "VD (imposé au-delà de CHF 300'000 par an, par enfant et par parent, depuis 2025",
    ):
        assert fact in taxing, f"fait manquant dans la ligne taxante : {fact!r}"


def test_donation_exempt_line_excludes_taxing_cantons():
    t = DON.read_text(encoding="utf-8")
    m = re.search(r"autres cantons exon[eè]rent[^\n]+", t)
    assert m, "ligne d'exonération absente"
    exempt = m.group(0)
    for canton in ("AI", "NE", "VD"):
        assert not re.search(rf"\b{canton}\b", exempt), (
            f"{canton} listé comme exonéré alors qu'il taxe la ligne directe"
        )


def test_donation_geneva_expenditure_caveat_present():
    t = DON.read_text(encoding="utf-8")
    assert "d'après la dépense" in t, (
        "caveat GE manquant : l'exonération ligne directe tombe pour "
        "l'imposition d'après la dépense (forfait fiscal)"
    )
    assert "forfait fiscal" in t


def test_donation_eclairage_not_overbroad():
    t = DON.read_text(encoding="utf-8")
    # L'ancien éclairage prétendait « exonérée dans 23 cantons » alors qu'un
    # don de 100k reste sous les franchises AI (300k) et VD (300k) : seule NE
    # le taxerait. Le comptage de cantons est banni de l'éclairage.
    assert "23 cantons" not in t
    eclairage = t.split("## Premier Éclairage", 1)[1].split("##", 1)[0]
    assert "Neuchâtel" in eclairage
    assert "CHF 10'000" in eclairage
    assert "CHF 300'000" in eclairage


def test_copies_are_synced():
    for name in ("lpp_salaire_coordonne.md", "donation_entre_vifs.md"):
        a = (REPO / "services" / "backend" / "education_inserts" / "concepts" / name).read_bytes()
        b = (REPO / "education" / "inserts" / "concepts" / name).read_bytes()
        assert a == b, f"copies désynchronisées: {name}"
