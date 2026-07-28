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

MULTILINGUE (revue adversariale 2026-07-28 P1-3) : la surface est en 6
langues — les motifs non-fr sont dérivés des TRADUCTIONS RÉELLES des ARB
(« open a pillar 3a », « Säule 3a eröffnen », « abrir o 3º pilar »,
« Take out … insurance »), pas d'un espace linguistique hypothétique.

Les regex sont appliquées après normalisation NFKC, en case-insensitive,
sur des lignes uniques (le découpage multi-lignes est une limite assumée,
documentée dans le lint).
"""
from __future__ import annotations

# (nom, regex) — le nom apparaît dans les sorties du lint et les entrées de
# baseline ``chemin::nom::compte``. Ne pas renommer sans migrer la baseline.
PRESCRIPTION_MOTIFS: tuple[tuple[str, str], ...] = (
    # ── Français ────────────────────────────────────────────────────
    # « Souscris / Souscrire / Souscrivez … » — l'alternance exige
    # s|re|vez puis une frontière : « la souscription » ne matche pas.
    ("souscrire-imperatif", r"\bsouscri(?:s|re|vez)\b"),
    # Ouverture d'un VÉHICULE FINANCIER seulement — « compte » nu retiré
    # (il attrapait la création de compte applicatif) ; variantes ème /
    # troisième / possessifs (revue adversariale P2-3).
    (
        "ouvrir-vehicule",
        r"\bouvr(?:e|ez|ir)\s+(?:(?:un|une|ton|ta|votre|le|la)\s+)?"
        r"(?:compte\s*3a|3\s*(?:e|ème|eme)?\s*pilier|troisi[eè]me\s+pilier)\b",
    ),
    # « Verse(z)(-y) le (montant) max(imum) ».
    (
        "verser-le-maximum",
        r"\bvers(?:e|ez|er)(?:-y)?\s+le\s+(?:montant\s+)?max(?:imum)?\b",
    ),
    # Véhicule-D'ABORD (revue Codex 2026-07-28) : les CTA canoniques du
    # produit (« PILIER 3A — À OUVRIR MAINTENANT », « PILLAR 3A — OPEN
    # NOW », …) mettent le véhicule avant le verbe — dérivés des 6
    # traductions réelles de firstJob3aHeader.
    (
        "vehicule-puis-ouvrir",
        r"\b(?:pilier|compte|pillar|pilastro|pilar|s[äa]ule)\s*3a?\b"
        r"[^.\n]{0,30}\b(?:à\s+ouvrir|ouvrir|open|er[öo]ffnen|abrir|(?:da\s+)?aprire)\b",
    ),
    # ── English ─────────────────────────────────────────────────────
    ("en-take-out-insurance", r"\btake\s+out\b[^.\n]{0,60}\binsurance\b"),
    (
        "en-open-pillar",
        r"\bopen\s+(?:(?:a|an|your|multiple)\s+)?(?:pillar\s*3a?|3a\s+accounts?|third\s+pillar)\b",
    ),
    ("en-pay-the-max", r"\b(?:pay|contribute)\s+(?:in\s+)?the\s+max(?:imum)?\b"),
    # ── Deutsch ─────────────────────────────────────────────────────
    (
        "de-saeule-eroeffnen",
        r"\b(?:s[äa]ule\s*3a|3a[- ]?konto)\s+er[öo]ffnen\b"
        r"|\ber[öo]ffne\s+(?:ein|dein|ihr)e?\s+(?:s[äa]ule\s*3a|3a[- ]?konto)\b",
    ),
    (
        "de-versicherung-abschliessen",
        r"\bversicherung\s+abschlie(?:ss|ß)en\b"
        r"|\bschlie(?:ss|ß)e?\s+eine\s+versicherung\s+ab\b",
    ),
    # ── Italiano ────────────────────────────────────────────────────
    (
        "it-apri-pilastro",
        r"\bapri(?:re)?\s+(?:(?:un|una|il)\s+)?(?:pilastro\s*3a?|terzo\s+pilastro|conto\s*3a)\b",
    ),
    ("it-stipula-assicurazione", r"\bstipula(?:re)?\s+(?:un[’']?\s*)?assicurazione\b"),
    # ── Español ─────────────────────────────────────────────────────
    (
        "es-abre-pilar",
        r"\babr(?:e|ir|a)\s+(?:(?:un|una|tu)\s+)?(?:pilar\s*3a?|tercer\s+pilar|cuenta\s*3a)\b",
    ),
    ("es-contrata-seguro", r"\bcontrata(?:r)?\s+(?:un\s+)?seguro\b"),
    # ── Português ───────────────────────────────────────────────────
    (
        "pt-abre-pilar",
        r"\babr(?:e|ir|a)\s+(?:(?:um|uma|o|a)\s+)?(?:3\.?\s*[ºo°]?\s*pilar|terceiro\s+pilar|conta\s*3a)\b",
    ),
    ("pt-contrate-seguro", r"\bcontrat(?:e|ar)\s+(?:um\s+)?seguro\b"),
)

# Prix mensuel nu — n'est un motif QUE co-occurrent d'un motif ci-dessus sur
# la même ligne : « dès CHF 45/mois » attaché à un impératif d'achat est la
# classe la plus au-delà de la ligne (P + prix). Seul, un prix est une
# information de marché légitime.
PRIX_MENSUEL_RE: str = (
    r"(?:d[eè]s|~|environ|from|ab|desde|da)?\s*CHF\s*\d[\d'’]*\s*/\s*"
    r"(?:mois|month|monat|mese|mes|m[êe]s)"
)
