"""Le vocabulaire des prescriptions est valide et discriminant.

Sans ce test, le module (donnée pure consommée par
``tools/checks/product_prescription_lint.py``, hors périmètre de couverture
backend) n'était exécuté par aucun test backend : une regex invalide ou un
motif renommé shippait vert côté backend et ne cassait qu'au lint.
"""
from __future__ import annotations

import re
import unicodedata

from app.services.coach.prescription_vocab import (
    PRESCRIPTION_MOTIFS,
    PRIX_MENSUEL_RE,
)


def _match(nom: str, texte: str) -> bool:
    rx = dict(PRESCRIPTION_MOTIFS)[nom]
    nfkc = unicodedata.normalize("NFKC", texte)
    return re.search(rx, nfkc, re.IGNORECASE) is not None


class TestVocabulaire:
    def test_motifs_non_vides_et_noms_uniques(self):
        assert PRESCRIPTION_MOTIFS
        noms = [n for n, _ in PRESCRIPTION_MOTIFS]
        assert len(noms) == len(set(noms)), "noms de motifs dupliqués"

    def test_toutes_les_regex_compilent(self):
        for nom, rx in PRESCRIPTION_MOTIFS:
            re.compile(rx, re.IGNORECASE)
        re.compile(PRIX_MENSUEL_RE, re.IGNORECASE)

    def test_souscrire_imperatif_discrimine(self):
        assert _match("souscrire-imperatif", "Souscris une APG privée")
        assert not _match(
            "souscrire-imperatif", "la souscription d'une assurance est un contrat"
        )

    def test_vehicule_puis_ouvrir_matche_le_header_reel(self):
        assert _match("vehicule-puis-ouvrir", "PILIER 3A — À OUVRIR MAINTENANT")
        assert not _match("vehicule-puis-ouvrir", "PILIER 3A — À ENVISAGER")

    def test_prix_mensuel_co_occurrent(self):
        assert re.search(PRIX_MENSUEL_RE, "dès CHF 45/mois", re.IGNORECASE)
        assert not re.search(PRIX_MENSUEL_RE, "CHF 45 par an", re.IGNORECASE)
