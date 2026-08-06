"""Normalisation canonique de l'état civil pour le traitement fiscal.

Source UNIQUE de la liste des statuts « mariés ». Imposition commune (LIFD
art. 9 al. 1 / al. 1bis) : mariage ET partenariat enregistré sont taxés
conjointement ; concubinage, divorce et veuvage restent une taxation séparée
(identique au célibataire).

Ce module existe pour que le service de sensibilité 3a
(``fiscal.sensibilite_3a_service``) ET le coach (``coaching_engine``) partagent
EXACTEMENT la même définition de « qui est marié ». Deux copies divergentes de
cette liste rejoueraient le vice « un seul taux marginal » (#1061/#1062) : le
coach servirait un taux marginal célibataire à un marié pendant que le service
appliquerait le splitting.
"""
from __future__ import annotations

# Imposition commune (LIFD art. 9 al. 1 / al. 1bis) : mariage ET partenariat
# enregistré sont taxés conjointement. Le concubinage reste une taxation séparée
# (identique au célibataire) — il n'appartient donc PAS à cet ensemble.
MARRIED_CIVIL_STATUSES = frozenset(
    {
        "marie",
        "marié",
        "marie_pacse",
        "marié_pacsé",
        "marie_pacsé",
        "pacse",
        "pacsé",
        "partenariat",
        "partenariat_enregistre",
        "partenariat_enregistré",
        "registered_partnership",
    }
)


def is_married_civil_status(etat_civil: str | None) -> bool:
    """True si l'état civil relève de l'imposition commune (LIFD art. 9 al. 1bis).

    Casse, accents et espaces sont normalisés. Tout statut inconnu — y compris
    ``divorce`` et ``veuf`` — retombe sur ``False`` (taxation séparée, hypothèse
    conservatrice : pas d'agrégation de ménage fabriquée).
    """
    return (etat_civil or "").strip().lower() in MARRIED_CIVIL_STATUSES
