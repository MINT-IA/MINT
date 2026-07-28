"""Vocabulaire canonique des prescriptions de produit — ADR 2026-07-28.

Un vocabulaire, deux points d'application :
- authoring-time : ``tools/checks/product_prescription_lint.py`` CHARGE ce
  module (jamais l'inverse — le build Railway/Docker n'embarque que
  ``services/backend/``, un import runtime depuis ``tools/`` casserait en
  production ; classe d'échec documentée dans ``runtime_verb_gate.py``) ;
- runtime : le Layer 2 de ``compliance_guard`` peut importer
  ``PRESCRIPTION_MOTIFS`` pour couvrir les sorties LLM.

La ligne éditoriale (ADR 2026-07-28-prescriptions-ligne-et-mecanisme) :
l'impératif d'achat — a fortiori assorti d'un prix nu ou d'un paramètre de
contrat — est à réécrire en description conditionnelle sourcée. Ce module
n'encode que les MOTIFS ; la politique vit dans l'ADR.

Les regex sont appliquées après normalisation NFKC, en case-insensitive,
sur des lignes uniques.
"""
from __future__ import annotations

# (nom, regex) — le nom apparaît dans les sorties du lint et les entrées
# de baseline ``chemin::nom``. Ne pas renommer sans migrer la baseline.
PRESCRIPTION_MOTIFS: tuple[tuple[str, str], ...] = (
    # Impératif de souscription : « Souscris / Souscrire / Souscrivez … ».
    # L'alternance exige s|re|vez puis une frontière de mot :
    # « la souscription » ne matche pas.
    ("souscrire-imperatif", r"\bsouscri(?:s|re|vez)\b"),
    # Impératif d'ouverture d'un véhicule, ancré sur le nom du véhicule
    # pour éviter les faux positifs hors finance (« ouvre une porte »).
    ("ouvrir-vehicule", r"\bouvr(?:e|ez|ir)\s+un(?:e)?\s+(?:compte|3\s*e?\s*pilier|pilier)\b"),
    # Impératif de versement au plafond.
    ("verser-le-maximum", r"\bvers(?:e|ez|er)\s+le\s+maximum\b"),
)

# Prix mensuel nu — n'est un motif QUE co-occurrent d'un motif 1-3 sur la
# même ligne : « dès CHF 45/mois » attaché à un impératif d'achat est la
# classe la plus au-delà de la ligne (P + prix). Seul, un prix est une
# information de marché légitime.
PRIX_MENSUEL_RE: str = r"(?:d[eè]s|~|environ)?\s*CHF\s*\d[\d'’]*\s*/\s*mois"
