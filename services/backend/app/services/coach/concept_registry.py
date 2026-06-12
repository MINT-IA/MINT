"""Curated Swiss concept registry — closed-world definition pages (WS-B).

Phase: mint-grounded-coach-m1 / Plan 04 (audit 04 §3.a — « registre de
connaissances suisses curé, wiki pas vector-soup »).

This is the SINGLE source of canonical Swiss financial definitions for the
coach. It mirrors the frozen-Mapping shape of `citation_registry.py`
(`MappingProxyType` + a frozen dataclass + a `resolve()` lookup), but where the
citation registry holds dated regulatory VALUES (a number + a legal article),
the concept registry holds the canonical MEANING of a concept: a human-validated
FR definition, its legal source, the common counter-senses (« ce que ce n'est
PAS »), and named links to related concepts.

Why a separate registry (audit 04 §1.1): every existing grounding layer
(citation gate, hallucination detector, ComplianceGuard L1-L3) inspects numbers.
A definitional inversion (« un rachat LPP, c'est sortir ton capital ») carries no
number and no banned term, so it traverses every numeric gate intact. The
claim-checker (`claim_checker.py`) closes that hole by checking definitional
assertions against THIS closed world.

Design notes:
- `ConceptPage` is a frozen dataclass — runtime mutation raises (schema drift
  fails fast). `CONCEPT_REGISTRY` is a `MappingProxyType` — insertion raises.
- `known_inversions` = full inverted sentences (the deliberately wrong
  educational counter-examples, mirrored from the Plan 01 eval fixtures so the
  claim-checker maps every fixture to a page).
- `not_this_fr` = the short lexical markers that signal the inverted meaning
  (the substrings the claim-checker scans for in a definitional context).
- All FR strings carry correct accents and contain no banned LSFin term — the
  registry is the text a user reads (CLAUDE.md TOP rule 1).
- `avs_age_femmes`: the conceptual page text says « 64 ans et demi en 2026 »
  (AVS21 transition). The registry VALUE fix in the constants store
  (`registry.py:504`, 65.0 → 64.5) lands in Plan 06; here it is the prose.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from types import MappingProxyType
from typing import Mapping, Optional


@dataclass(frozen=True)
class ConceptPage:
    """One curated page in the closed-world Swiss concept registry.

    Args:
        concept_key: short stable identifier (matches the Plan 01 fixture key).
        canonical_fr: human-validated canonical FR definition (correct accents,
            no banned LSFin term).
        source_title: exact legal source (« LPP art. 79b », « LIFD art. 38 »).
        source_url: optional URL to the official source.
        known_inversions: full inverted sentences — common counter-senses, used
            by the claim-checker as the closed-world inversion set.
        not_this_fr: short lexical markers of the inverted meaning (« retirer »,
            « sortir ton capital ») — the substrings the checker scans for.
        related: named links to related concept_keys (wiki traversal).
    """

    concept_key: str
    canonical_fr: str
    source_title: str
    source_url: str = ""
    known_inversions: tuple[str, ...] = field(default_factory=tuple)
    not_this_fr: tuple[str, ...] = field(default_factory=tuple)
    related: tuple[str, ...] = field(default_factory=tuple)


# ---------------------------------------------------------------------------
# P0 closed-world set — superset of the 18 Plan 01 inversion fixture keys.
# Curated 2026-06-12 against Swiss 2026 law (LPP / LIFD / LAVS / AVS21).
# ---------------------------------------------------------------------------

_REGISTRY: dict[str, ConceptPage] = {
    "rachat_lpp": ConceptPage(
        concept_key="rachat_lpp",
        canonical_fr=(
            "Un rachat LPP, c'est verser de l'argent dans ta caisse de pension "
            "pour combler une lacune de prévoyance ; le versement est déductible "
            "de ton revenu imposable l'année où tu le fais."
        ),
        source_title="LPP art. 79b",
        source_url="https://www.fedlex.admin.ch/eli/cc/1983/797_797_797/fr#art_79_b",
        known_inversions=(
            "Un rachat LPP, c'est sortir ton capital du 2e pilier avant l'heure.",
            "Faire un rachat LPP revient à retirer de l'argent de ta caisse de pension.",
            "Un rachat LPP te permet de récupérer ton argent du 2e pilier.",
            "Le rachat LPP, c'est un retrait anticipé de ta prévoyance.",
        ),
        not_this_fr=(
            "sortir ton capital",
            "retirer de l'argent de ta caisse",
            "récupérer ton argent du 2e pilier",
            "retrait anticipé de ta prévoyance",
            "retirer",
            "sortir",
            "retrait",
        ),
        related=("rachat_deductibilite", "epl_blocage_3ans", "lacunes_prevoyance"),
    ),
    "epl": ConceptPage(
        concept_key="epl",
        canonical_fr=(
            "L'EPL (encouragement à la propriété du logement), c'est un retrait "
            "anticipé du 2e pilier pour devenir propriétaire de ton logement "
            "principal."
        ),
        source_title="LPP art. 30c",
        source_url="https://www.fedlex.admin.ch/eli/cc/1983/797_797_797/fr#art_30_c",
        known_inversions=(
            "L'EPL, c'est mettre de l'argent supplémentaire dans ton 2e pilier.",
            "L'encouragement à la propriété, c'est un versement vers ta caisse de pension.",
        ),
        not_this_fr=(
            "mettre de l'argent supplémentaire dans ton 2e pilier",
            "versement vers ta caisse",
        ),
        related=("rachat_lpp", "epl_blocage_3ans"),
    ),
    "rente_imposition": ConceptPage(
        concept_key="rente_imposition",
        canonical_fr=(
            "La rente du 2e pilier est imposée comme un revenu, chaque année, "
            "au barème ordinaire."
        ),
        source_title="LIFD art. 22",
        source_url="https://www.fedlex.admin.ch/eli/cc/1991/1184_1184_1184/fr#art_22",
        known_inversions=(
            "La rente du 2e pilier n'est pas imposée comme un revenu.",
            "La rente de prévoyance est exonérée d'impôt sur le revenu.",
        ),
        not_this_fr=(
            "n'est pas imposée comme un revenu",
            "exonérée d'impôt sur le revenu",
            "exonérée",
        ),
        related=("capital_imposition", "taux_conversion"),
    ),
    "capital_imposition": ConceptPage(
        concept_key="capital_imposition",
        canonical_fr=(
            "Le capital de prévoyance est imposé une seule fois, séparément du "
            "revenu, à un taux réduit, l'année du versement."
        ),
        source_title="LIFD art. 38",
        source_url="https://www.fedlex.admin.ch/eli/cc/1991/1184_1184_1184/fr#art_38",
        known_inversions=(
            "Le capital de prévoyance est imposé chaque année comme un revenu ordinaire.",
            "Le capital du 2e pilier est ajouté à ton revenu imposable annuel.",
        ),
        not_this_fr=(
            "imposé chaque année comme un revenu",
            "ajouté à ton revenu imposable annuel",
        ),
        related=("rente_imposition", "pilier_3a_retrait"),
    ),
    "pilier_3a": ConceptPage(
        concept_key="pilier_3a",
        canonical_fr=(
            "Les versements au pilier 3a (prévoyance liée) sont déductibles de ton "
            "revenu imposable, dans une limite annuelle fixée par la loi."
        ),
        source_title="LIFD art. 33 let. e / OPP3 art. 7",
        source_url="https://www.fedlex.admin.ch/eli/cc/1985/1778_1778_1778/fr",
        known_inversions=(
            "Les versements au pilier 3a ne sont pas déductibles de tes impôts.",
            "Le pilier 3a est un compte sans aucun avantage fiscal.",
        ),
        not_this_fr=(
            "ne sont pas déductibles",
            "sans aucun avantage fiscal",
        ),
        related=("pilier_3b", "pilier_3a_retrait"),
    ),
    "pilier_3b": ConceptPage(
        concept_key="pilier_3b",
        canonical_fr=(
            "Le pilier 3b est une prévoyance libre, sans déduction fiscale au "
            "niveau fédéral, avec un accès souple à ton épargne."
        ),
        source_title="LCA / droit cantonal (prévoyance libre)",
        source_url="",
        known_inversions=(
            "Le pilier 3b est une prévoyance liée avec déduction fiscale plafonnée.",
            "Le pilier 3b te donne la même déduction d'impôt que le pilier 3a.",
        ),
        not_this_fr=(
            "prévoyance liée avec déduction",
            "même déduction d'impôt que le pilier 3a",
        ),
        related=("pilier_3a",),
    ),
    "taux_conversion": ConceptPage(
        concept_key="taux_conversion",
        canonical_fr=(
            "Le taux de conversion sert à transformer ton capital LPP en rente "
            "annuelle au moment de la retraite."
        ),
        source_title="LPP art. 14 / taux de conversion 2026",
        source_url="https://www.fedlex.admin.ch/eli/cc/1983/797_797_797/fr#art_14",
        known_inversions=(
            "Le taux de conversion sert à calculer le montant de ton rachat.",
            "Le taux de conversion détermine le rendement annuel de ton 3a.",
        ),
        not_this_fr=(
            "calculer le montant de ton rachat",
            "rendement annuel de ton 3a",
        ),
        related=("rente_imposition", "capital_imposition"),
    ),
    "lacunes_prevoyance": ConceptPage(
        concept_key="lacunes_prevoyance",
        canonical_fr=(
            "Une lacune de prévoyance, c'est un manque de cotisations qui réduit "
            "ta future rente."
        ),
        source_title="LPP art. 79b (combler par rachat)",
        source_url="https://www.fedlex.admin.ch/eli/cc/1983/797_797_797/fr#art_79_b",
        known_inversions=(
            "Une lacune de prévoyance, c'est un excédent de cotisations versées en trop.",
            "Une lacune de prévoyance augmente ta future rente.",
        ),
        not_this_fr=(
            "excédent de cotisations versées en trop",
            "augmente ta future rente",
        ),
        related=("rachat_lpp",),
    ),
    "coordination_lpp": ConceptPage(
        concept_key="coordination_lpp",
        canonical_fr=(
            "La déduction de coordination réduit la part du salaire prise en compte "
            "par le 2e pilier, pour tenir compte de l'AVS."
        ),
        source_title="OPP2 art. 3-4 (déduction de coordination)",
        source_url="https://www.fedlex.admin.ch/eli/cc/1984/543_543_543/fr",
        known_inversions=(
            "La déduction de coordination augmente la part de ton salaire couverte "
            "par le 2e pilier.",
            "La déduction de coordination ajoute un bonus à ton salaire pris en "
            "compte par la LPP.",
        ),
        not_this_fr=(
            "augmente la part de ton salaire couverte par le 2e pilier",
            "ajoute un bonus à ton salaire",
        ),
        related=("bonifications_vieillesse",),
    ),
    "libre_passage": ConceptPage(
        concept_key="libre_passage",
        canonical_fr=(
            "Un compte de libre passage sert à garder ton avoir LPP quand tu "
            "quittes un emploi sans nouvelle caisse de pension."
        ),
        source_title="LFLP (loi sur le libre passage)",
        source_url="https://www.fedlex.admin.ch/eli/cc/1994/2386_2386_2386/fr",
        known_inversions=(
            "Un compte de libre passage sert à verser tes cotisations 3a annuelles.",
            "Le libre passage, c'est un compte bancaire ordinaire pour tes dépenses "
            "courantes.",
        ),
        not_this_fr=(
            "verser tes cotisations 3a",
            "compte bancaire ordinaire pour tes dépenses",
        ),
        related=("pilier_3a", "rachat_lpp"),
    ),
    "splitting_avs": ConceptPage(
        concept_key="splitting_avs",
        canonical_fr=(
            "Le splitting AVS, c'est le partage des revenus du couple pendant le "
            "mariage, réparti à parts égales entre les deux conjoints."
        ),
        source_title="LAVS art. 29quinquies (splitting)",
        source_url="https://www.fedlex.admin.ch/eli/cc/63/837_843_843/fr",
        known_inversions=(
            "Le splitting AVS, c'est diviser ta rente de moitié en cas de retraite "
            "anticipée.",
            "Le splitting AVS réduit de moitié ta rente si tu travailles à temps "
            "partiel.",
        ),
        not_this_fr=(
            "diviser ta rente de moitié en cas de retraite anticipée",
            "réduit de moitié ta rente si tu travailles",
        ),
        related=("avs_age_femmes",),
    ),
    "bonifications_vieillesse": ConceptPage(
        concept_key="bonifications_vieillesse",
        canonical_fr=(
            "Les bonifications de vieillesse LPP sont les cotisations qui augmentent "
            "par paliers avec l'âge, de 7% à 18% du salaire coordonné."
        ),
        source_title="LPP art. 16 (bonifications de vieillesse)",
        source_url="https://www.fedlex.admin.ch/eli/cc/1983/797_797_797/fr#art_16",
        known_inversions=(
            "Les bonifications de vieillesse LPP diminuent quand l'âge augmente.",
            "Les bonifications de vieillesse sont les mêmes à tout âge, autour de 10%.",
        ),
        not_this_fr=(
            "diminuent quand l'âge augmente",
            "les mêmes à tout âge",
        ),
        related=("coordination_lpp",),
    ),
    "frontalier": ConceptPage(
        concept_key="frontalier",
        canonical_fr=(
            "Un frontalier qui travaille en Suisse cotise à l'AVS et à la LPP "
            "suisses sur son salaire suisse."
        ),
        source_title="ALCP / coordination de sécurité sociale CH-UE",
        source_url="",
        known_inversions=(
            "Un frontalier cotise uniquement à la prévoyance de son pays de résidence.",
            "Un frontalier n'a droit à aucune prévoyance suisse.",
        ),
        not_this_fr=(
            "uniquement à la prévoyance de son pays",
            "aucune prévoyance suisse",
        ),
        related=("fatca",),
    ),
    "fatca": ConceptPage(
        concept_key="fatca",
        canonical_fr=(
            "FATCA est un accord qui oblige les banques suisses à déclarer les "
            "comptes des personnes US au fisc américain."
        ),
        source_title="Accord FATCA CH-US",
        source_url="",
        known_inversions=(
            "FATCA est un accord qui exonère les ressortissants américains de toute "
            "déclaration.",
            "FATCA interdit aux personnes US d'ouvrir un compte en Suisse.",
        ),
        not_this_fr=(
            "exonère les ressortissants américains",
            "interdit aux personnes US d'ouvrir un compte",
        ),
        related=("frontalier",),
    ),
    "epl_blocage_3ans": ConceptPage(
        concept_key="epl_blocage_3ans",
        canonical_fr=(
            "Après un rachat LPP, tout retrait en capital est bloqué pendant 3 ans, "
            "et ce blocage porte sur la totalité du capital de retraite "
            "(TF 26.02.2026, LPP art. 79b al. 3)."
        ),
        source_title="LPP art. 79b al. 3 (TF 26.02.2026)",
        source_url="https://www.fedlex.admin.ch/eli/cc/1983/797_797_797/fr#art_79_b",
        known_inversions=(
            "Après un rachat, seul le montant racheté est bloqué pendant 3 ans, le "
            "reste reste disponible.",
            "Le blocage de 3 ans concerne uniquement le retrait pour le logement, "
            "pas la retraite.",
        ),
        not_this_fr=(
            "seul le montant racheté est bloqué",
            "uniquement le retrait pour le logement",
        ),
        related=("rachat_lpp", "epl"),
    ),
    "avs_age_femmes": ConceptPage(
        concept_key="avs_age_femmes",
        canonical_fr=(
            "En 2026, l'âge de référence AVS pour les femmes est de 64 ans et demi "
            "pendant la transition AVS21, avant d'atteindre 65 ans en 2028."
        ),
        source_title="LAVS art. 21 (transition AVS21)",
        source_url="https://www.fedlex.admin.ch/eli/cc/63/837_843_843/fr#art_21",
        known_inversions=(
            "En 2026, l'âge de référence AVS des femmes est déjà fixé à 65 ans.",
            "Les femmes touchent leur rente AVS complète dès 63 ans en 2026.",
        ),
        not_this_fr=(
            "déjà fixé à 65 ans",
            "dès 63 ans en 2026",
        ),
        related=("splitting_avs", "pilier_3a_retrait"),
    ),
    "rachat_deductibilite": ConceptPage(
        concept_key="rachat_deductibilite",
        canonical_fr=(
            "Un rachat LPP est déductible de ton revenu imposable l'année où tu le "
            "verses, ce qui réduit ta charge fiscale."
        ),
        source_title="LIFD art. 33 let. d",
        source_url="https://www.fedlex.admin.ch/eli/cc/1991/1184_1184_1184/fr#art_33",
        known_inversions=(
            "Un rachat LPP n'a aucun effet sur tes impôts.",
            "Un rachat LPP augmente ton revenu imposable l'année du versement.",
        ),
        not_this_fr=(
            "aucun effet sur tes impôts",
            "augmente ton revenu imposable l'année du versement",
        ),
        related=("rachat_lpp",),
    ),
    "pilier_3a_retrait": ConceptPage(
        concept_key="pilier_3a_retrait",
        canonical_fr=(
            "Le pilier 3a peut être retiré au plus tôt 5 ans avant l'âge de "
            "référence AVS, ou plus tôt pour un logement, le départ de Suisse ou le "
            "passage à l'indépendance."
        ),
        source_title="OPP3 art. 3 (retrait anticipé 3a)",
        source_url="https://www.fedlex.admin.ch/eli/cc/1985/1778_1778_1778/fr#art_3",
        known_inversions=(
            "Le pilier 3a est disponible à tout moment, comme un compte d'épargne "
            "classique.",
            "Tu peux retirer ton pilier 3a chaque année sans condition.",
        ),
        not_this_fr=(
            "disponible à tout moment, comme un compte d'épargne",
            "retirer ton pilier 3a chaque année sans condition",
        ),
        related=("pilier_3a", "avs_age_femmes"),
    ),
}


# Frozen view — runtime mutation raises TypeError.
CONCEPT_REGISTRY: Mapping[str, ConceptPage] = MappingProxyType(_REGISTRY)


def resolve(concept_key: str) -> Optional[ConceptPage]:
    """Resolve a concept_key to its curated page.

    Args:
        concept_key: registry key (e.g. ``rachat_lpp``).

    Returns:
        The ``ConceptPage`` if the key exists, else ``None``.
    """
    return CONCEPT_REGISTRY.get(concept_key)


__all__ = ["CONCEPT_REGISTRY", "ConceptPage", "resolve"]
