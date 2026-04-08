"""
Service de conformite nLPD (nouvelle Loi sur la Protection des Donnees, 1er sept. 2023).

Fonctions pures pour:
    - Export des donnees personnelles (nLPD art. 25 — droit d'acces / portabilite)
    - Suppression des donnees (nLPD art. 32 — droit a l'effacement)
    - Gestion des consentements (nLPD art. 6 — principes de traitement)

Sources:
    - nLPD (RS 235.1) — Loi federale sur la protection des donnees, revisee 2020, en vigueur 1.9.2023
    - OPDo (RS 235.11) — Ordonnance sur la protection des donnees
    - nLPD art. 6 — Principes de traitement
    - nLPD art. 7 — Protection des donnees des la conception et par defaut
    - nLPD art. 19 — Devoir d'informer lors de la collecte
    - nLPD art. 25 — Droit d'acces de la personne concernee
    - nLPD art. 28 — Droit a la remise ou a la transmission des donnees (portabilite)
    - nLPD art. 32 — Motifs justificatifs (base pour la suppression)
    - nLPD art. 60-66 — Dispositions penales
"""

from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from typing import Dict, List, Optional


# ===========================================================================
# Constants
# ===========================================================================

DISCLAIMER = (
    "Outil educatif de gestion de tes donnees personnelles. "
    "Ne constitue pas un avis juridique. "
    "Tes droits sont regis par la nLPD (RS 235.1) en vigueur depuis le 1er septembre 2023. "
    "Pour toute question, contacte un ou une specialiste en protection des donnees."
)

# Delai de grace par defaut pour la suppression (en jours)
GRACE_PERIOD_DAYS = 30

# Responsable du traitement
RESPONSABLE_TRAITEMENT = "MINT SA — Application d'education financiere suisse"

# Durees de conservation par categorie
RETENTION_POLICIES: Dict[str, str] = {
    "core_profile": "Duree du contrat + 10 ans (CO art. 127 — prescription)",
    "analytics": "12 mois apres la derniere interaction",
    "coaching_notifications": "Duree du consentement, max 24 mois",
    "open_banking": "Duree du consentement, donnees supprimees a la revocation",
    "document_upload": "Duree du consentement, max 24 mois",
    "rag_queries": "Duree du consentement, donnees supprimees a la revocation (BYOK)",
}

# Categories de consentement avec leurs bases legales et descriptions
CONSENT_CATEGORIES: Dict[str, Dict] = {
    "core_profile": {
        "nom_affiche": "Profil de base",
        "description": (
            "Donnees necessaires au fonctionnement de l'application : "
            "age, canton, situation professionnelle, etat civil."
        ),
        "base_legale": "contract",
        "est_obligatoire": True,
        "peut_etre_retire": False,
        "impact_retrait": (
            "Le retrait n'est pas possible car ce traitement est necessaire "
            "a l'execution du service (nLPD art. 6 al. 6)."
        ),
    },
    "analytics": {
        "nom_affiche": "Statistiques d'utilisation",
        "description": (
            "Collecte anonymisee de donnees d'utilisation pour ameliorer "
            "l'experience (pages visitees, temps passe, fonctionnalites utilisees)."
        ),
        "base_legale": "consent",
        "est_obligatoire": False,
        "peut_etre_retire": True,
        "impact_retrait": (
            "Tu peux retirer ton consentement a tout moment. "
            "L'application continuera de fonctionner normalement, "
            "mais nous ne pourrons plus personnaliser ton experience."
        ),
    },
    "coaching_notifications": {
        "nom_affiche": "Notifications de coaching",
        "description": (
            "Envoi de rappels proactifs personnalises : echeances fiscales, "
            "versements 3a, renouvellement LAMal, etc."
        ),
        "base_legale": "consent",
        "est_obligatoire": False,
        "peut_etre_retire": True,
        "impact_retrait": (
            "Tu ne recevras plus de rappels personnalises. "
            "Tu peux toujours consulter manuellement les echeances dans l'app."
        ),
    },
    "open_banking": {
        "nom_affiche": "Connexion bancaire (Open Banking)",
        "description": (
            "Acces en lecture seule a tes comptes bancaires via bLink/SFTI "
            "pour categoriser automatiquement tes depenses."
        ),
        "base_legale": "explicit_consent",
        "est_obligatoire": False,
        "peut_etre_retire": True,
        "impact_retrait": (
            "La connexion a tes comptes bancaires sera desactivee. "
            "Toutes les donnees bancaires importees seront supprimees sous 30 jours. "
            "Tu peux continuer a saisir manuellement tes depenses."
        ),
    },
    "document_upload": {
        "nom_affiche": "Upload de documents",
        "description": (
            "Stockage securise de tes documents (certificat de salaire, "
            "attestation LPP, declaration fiscale) pour analyse."
        ),
        "base_legale": "consent",
        "est_obligatoire": False,
        "peut_etre_retire": True,
        "impact_retrait": (
            "Tous les documents uploades seront supprimes sous 30 jours. "
            "Les analyses deja generees restent disponibles."
        ),
    },
    "rag_queries": {
        "nom_affiche": "Questions IA (RAG)",
        "description": (
            "Utilisation de l'IA pour repondre a tes questions financieres "
            "a partir de tes documents et de sources legales suisses. BYOK possible."
        ),
        "base_legale": "consent",
        "est_obligatoire": False,
        "peut_etre_retire": True,
        "impact_retrait": (
            "Tu ne pourras plus poser de questions a l'IA. "
            "L'historique de tes questions sera supprime. "
            "Toutes les autres fonctionnalites restent disponibles."
        ),
    },
}

# Sources legales
SOURCES_EXPORT = [
    "nLPD art. 25 (droit d'acces de la personne concernee)",
    "nLPD art. 28 (droit a la remise ou a la transmission des donnees — portabilite)",
    "nLPD art. 19 (devoir d'informer lors de la collecte)",
    "OPDo art. 16-19 (modalites du droit d'acces)",
]

SOURCES_DELETION = [
    "nLPD art. 6 al. 4 (les donnees sont detruites ou anonymisees des qu'elles ne sont plus necessaires)",
    "nLPD art. 32 (motifs justificatifs — obligation legale de conservation)",
    "CO art. 127 (delai de prescription general de 10 ans)",
    "OPDo art. 20-22 (modalites de l'effacement)",
]

SOURCES_CONSENT = [
    "nLPD art. 6 al. 1 (principes de licite, bonne foi, proportionnalite)",
    "nLPD art. 6 al. 6 (consentement requis pour le traitement)",
    "nLPD art. 6 al. 7 (le consentement doit etre libre, eclaire et univoque)",
    "nLPD art. 7 (protection des donnees des la conception — Privacy by Design)",
]


# ===========================================================================
# Dataclasses (internal models)
# ===========================================================================

@dataclass
class DataCategoryInfo:
    """Information sur une categorie de donnees exportees."""
    categorie: str
    nombre_enregistrements: int
    description: str
    base_legale: str
    duree_conservation: str


@dataclass
class ExportResult:
    """Resultat de l'export des donnees personnelles."""
    profile_id: str
    date_export: str
    format_donnees: str
    categories: List[DataCategoryInfo]
    donnees_profil: Dict
    donnees_sessions: List[Dict]
    donnees_rapports: List[Dict]
    donnees_documents: List[Dict]
    donnees_analytics: List[Dict]
    politique_conservation: Dict[str, str]
    responsable_traitement: str
    premier_eclairage: str
    disclaimer: str
    sources: List[str] = field(default_factory=list)


@dataclass
class DeletionCategoryInfo:
    """Detail de la suppression par categorie."""
    categorie: str
    nombre_supprime: int
    statut: str
    motif_conservation: Optional[str] = None


@dataclass
class DeletionResult:
    """Resultat de la suppression des donnees."""
    profile_id: str
    mode: str
    date_demande: str
    date_suppression_effective: str
    delai_grace_jours: int
    categories_traitees: List[DeletionCategoryInfo]
    total_enregistrements_supprimes: int
    donnees_conservees_obligation_legale: bool
    explication_conservation: Optional[str]
    premier_eclairage: str
    disclaimer: str
    sources: List[str] = field(default_factory=list)
    alertes: List[str] = field(default_factory=list)


@dataclass
class ConsentCategoryInfo:
    """Statut d'un consentement pour une categorie."""
    categorie: str
    nom_affiche: str
    description: str
    base_legale: str
    est_obligatoire: bool
    est_actif: bool
    date_consentement: Optional[str]
    peut_etre_retire: bool
    impact_retrait: str


@dataclass
class ConsentStatusResult:
    """Resultat de la verification des consentements."""
    profile_id: str
    date_verification: str
    consentements: List[ConsentCategoryInfo]
    nb_consentements_actifs: int
    nb_consentements_optionnels: int
    premier_eclairage: str
    disclaimer: str
    sources: List[str] = field(default_factory=list)


@dataclass
class ConsentUpdateResult:
    """Resultat de la mise a jour d'un consentement."""
    profile_id: str
    categorie: str
    est_actif: bool
    date_modification: str
    message: str
    disclaimer: str
    sources: List[str] = field(default_factory=list)


# ===========================================================================
# Service class
# ===========================================================================

class PrivacyService:
    """Service de conformite nLPD — fonctions pures pour la protection des donnees.

    Principes cles (nLPD art. 6-7):
    - Transparence: l'utilisateur sait quelles donnees sont collectees et pourquoi
    - Finalite: les donnees ne sont utilisees que pour la finalite declaree
    - Proportionnalite: seules les donnees necessaires sont collectees
    - Exactitude: les donnees sont tenues a jour
    - Limitation de la conservation: suppression des qu'elles ne sont plus necessaires
    - Privacy by Design: protection des la conception (nLPD art. 7)
    """

    def export_user_data(
        self,
        profile_id: str,
        profile_data: Optional[Dict] = None,
        sessions_data: Optional[List[Dict]] = None,
        reports_data: Optional[List[Dict]] = None,
        documents_data: Optional[List[Dict]] = None,
        analytics_data: Optional[List[Dict]] = None,
        include_sessions: bool = True,
        include_reports: bool = True,
        include_documents: bool = True,
        include_analytics: bool = True,
    ) -> ExportResult:
        """Exporte toutes les donnees personnelles d'un utilisateur.

        Conforme a nLPD art. 25 (droit d'acces) et art. 28 (portabilite).

        Le format est JSON lisible par machine pour permettre la portabilite
        vers un autre service (nLPD art. 28).

        Args:
            profile_id: Identifiant unique du profil.
            profile_data: Donnees du profil (dictionnaire). None = profil vide.
            sessions_data: Historique des sessions. None = pas de sessions.
            reports_data: Rapports generes. None = pas de rapports.
            documents_data: Documents uploades. None = pas de documents.
            analytics_data: Evenements analytics. None = pas d'analytics.
            include_sessions: Inclure les sessions dans l'export.
            include_reports: Inclure les rapports dans l'export.
            include_documents: Inclure les documents dans l'export.
            include_analytics: Inclure les analytics dans l'export.

        Returns:
            ExportResult avec toutes les donnees et les metadonnees.
        """
        now = datetime.now(timezone.utc).isoformat()

        # Prepare data with defaults
        _profile = profile_data or {}
        _sessions = sessions_data if include_sessions and sessions_data else []
        _reports = reports_data if include_reports and reports_data else []
        _documents = documents_data if include_documents and documents_data else []
        _analytics = analytics_data if include_analytics and analytics_data else []

        # Build category info
        categories: List[DataCategoryInfo] = []

        categories.append(DataCategoryInfo(
            categorie="core_profile",
            nombre_enregistrements=1 if _profile else 0,
            description="Donnees de profil : age, canton, situation professionnelle, etat civil",
            base_legale="Execution du contrat (nLPD art. 6 al. 6)",
            duree_conservation=RETENTION_POLICIES["core_profile"],
        ))

        if include_sessions:
            categories.append(DataCategoryInfo(
                categorie="sessions",
                nombre_enregistrements=len(_sessions),
                description="Historique des sessions du wizard financier",
                base_legale="Execution du contrat",
                duree_conservation="Duree du contrat + 10 ans",
            ))

        if include_reports:
            categories.append(DataCategoryInfo(
                categorie="rapports",
                nombre_enregistrements=len(_reports),
                description="Rapports financiers generes (circle score, recommandations)",
                base_legale="Execution du contrat",
                duree_conservation="Duree du contrat + 10 ans",
            ))

        if include_documents:
            categories.append(DataCategoryInfo(
                categorie="documents",
                nombre_enregistrements=len(_documents),
                description="Documents uploades (certificat de salaire, attestation LPP)",
                base_legale="Consentement (nLPD art. 6 al. 6)",
                duree_conservation=RETENTION_POLICIES["document_upload"],
            ))

        if include_analytics:
            categories.append(DataCategoryInfo(
                categorie="analytics",
                nombre_enregistrements=len(_analytics),
                description="Evenements d'utilisation anonymises",
                base_legale="Consentement (nLPD art. 6 al. 6)",
                duree_conservation=RETENTION_POLICIES["analytics"],
            ))

        # Count total records
        total_records = sum(c.nombre_enregistrements for c in categories)

        premier_eclairage = (
            f"Ton profil MINT contient {total_records} enregistrement(s) "
            f"repartis en {len(categories)} categorie(s) de donnees. "
            f"Chaque categorie a une base legale et une duree de conservation definies "
            f"conformement a la nLPD."
        )

        return ExportResult(
            profile_id=profile_id,
            date_export=now,
            format_donnees="JSON",
            categories=categories,
            donnees_profil=_profile,
            donnees_sessions=_sessions,
            donnees_rapports=_reports,
            donnees_documents=_documents,
            donnees_analytics=_analytics,
            politique_conservation=RETENTION_POLICIES,
            responsable_traitement=RESPONSABLE_TRAITEMENT,
            premier_eclairage=premier_eclairage,
            disclaimer=DISCLAIMER,
            sources=SOURCES_EXPORT,
        )

    def delete_user_data(
        self,
        profile_id: str,
        mode: str = "grace_period",
        nb_sessions: int = 0,
        nb_reports: int = 0,
        nb_documents: int = 0,
        nb_analytics: int = 0,
        raison: Optional[str] = None,
    ) -> DeletionResult:
        """Supprime les donnees personnelles d'un utilisateur.

        Conforme a nLPD art. 6 al. 4 (destruction des donnees non necessaires)
        et art. 32 (motifs justificatifs pour la conservation).

        Note: certaines donnees peuvent etre conservees si une obligation legale
        l'exige (CO art. 127 — prescription de 10 ans pour les donnees comptables).

        Args:
            profile_id: Identifiant unique du profil.
            mode: "immediate" ou "grace_period" (defaut: 30 jours).
            nb_sessions: Nombre de sessions a supprimer.
            nb_reports: Nombre de rapports a supprimer.
            nb_documents: Nombre de documents a supprimer.
            nb_analytics: Nombre d'analytics a supprimer.
            raison: Raison de la suppression (facultative).

        Returns:
            DeletionResult avec le detail de la suppression.
        """
        now = datetime.now(timezone.utc)

        is_immediate = mode == "immediate"
        grace_days = 0 if is_immediate else GRACE_PERIOD_DAYS

        if is_immediate:
            effective_date = now
            statut_donnees = "supprime"
        else:
            effective_date = now + timedelta(days=grace_days)
            statut_donnees = "marque_pour_suppression"

        # Build deletion detail per category
        categories_traitees: List[DeletionCategoryInfo] = []

        # Profile: minimal data may be kept for legal obligations
        categories_traitees.append(DeletionCategoryInfo(
            categorie="core_profile",
            nombre_supprime=1,
            statut="conserve_obligation_legale",
            motif_conservation=(
                "Un identifiant anonymise est conserve pendant 10 ans "
                "pour les obligations legales (CO art. 127). "
                "Toutes les donnees personnelles identifiantes sont supprimees."
            ),
        ))

        # Sessions
        categories_traitees.append(DeletionCategoryInfo(
            categorie="sessions",
            nombre_supprime=nb_sessions,
            statut=statut_donnees,
        ))

        # Reports
        categories_traitees.append(DeletionCategoryInfo(
            categorie="rapports",
            nombre_supprime=nb_reports,
            statut=statut_donnees,
        ))

        # Documents
        categories_traitees.append(DeletionCategoryInfo(
            categorie="documents",
            nombre_supprime=nb_documents,
            statut=statut_donnees,
        ))

        # Analytics
        categories_traitees.append(DeletionCategoryInfo(
            categorie="analytics",
            nombre_supprime=nb_analytics,
            statut=statut_donnees,
        ))

        total_supprime = nb_sessions + nb_reports + nb_documents + nb_analytics + 1

        # Build alertes
        alertes: List[str] = []
        if not is_immediate:
            alertes.append(
                f"Tes donnees seront supprimees definitivement dans {grace_days} jours. "
                f"Tu peux annuler cette demande avant le {effective_date.strftime('%d.%m.%Y')}."
            )
        if nb_documents > 0:
            alertes.append(
                f"{nb_documents} document(s) seront definitivement supprimes. "
                f"Pense a les telecharger avant si tu en as besoin."
            )

        explication_conservation = (
            "Un identifiant anonymise minimal est conserve conformement "
            "aux obligations legales suisses (CO art. 127 — delai de prescription de 10 ans). "
            "Aucune donnee personnelle identifiable n'est conservee au-dela de la suppression."
        )

        premier_eclairage = (
            f"{total_supprime} enregistrement(s) "
            f"{'supprime(s) immediatement' if is_immediate else f'marque(s) pour suppression dans {grace_days} jours'}. "
            f"La nLPD te donne le droit de demander la suppression de tes donnees a tout moment."
        )

        return DeletionResult(
            profile_id=profile_id,
            mode=mode,
            date_demande=now.isoformat(),
            date_suppression_effective=effective_date.isoformat(),
            delai_grace_jours=grace_days,
            categories_traitees=categories_traitees,
            total_enregistrements_supprimes=total_supprime,
            donnees_conservees_obligation_legale=True,
            explication_conservation=explication_conservation,
            premier_eclairage=premier_eclairage,
            disclaimer=DISCLAIMER,
            sources=SOURCES_DELETION,
            alertes=alertes,
        )

    def get_consent_status(
        self,
        profile_id: str,
        current_consents: Optional[Dict[str, bool]] = None,
        consent_dates: Optional[Dict[str, str]] = None,
    ) -> ConsentStatusResult:
        """Retourne le statut actuel de tous les consentements.

        Conforme a nLPD art. 6 (principes de traitement) et art. 7 (Privacy by Design).

        Chaque categorie de traitement a:
        - Une base legale (contrat, consentement, consentement explicite)
        - Un statut (actif/inactif)
        - Une description claire de l'impact du retrait

        Args:
            profile_id: Identifiant unique du profil.
            current_consents: Dict {categorie: bool} des consentements actuels.
                             Si None, seul core_profile est actif par defaut (Privacy by Design).
            consent_dates: Dict {categorie: date_iso} des dates de consentement.

        Returns:
            ConsentStatusResult avec le detail de chaque consentement.
        """
        now = datetime.now(timezone.utc).isoformat()

        # Default: only core_profile is active (Privacy by Design — nLPD art. 7)
        _consents = current_consents or {"core_profile": True}
        _dates = consent_dates or {}

        consentements: List[ConsentCategoryInfo] = []
        nb_actifs = 0
        nb_optionnels = 0

        for cat_key, cat_config in CONSENT_CATEGORIES.items():
            est_actif = _consents.get(cat_key, cat_config["est_obligatoire"])
            date_consentement = _dates.get(cat_key, None)

            if est_actif:
                nb_actifs += 1
            if not cat_config["est_obligatoire"]:
                nb_optionnels += 1

            consentements.append(ConsentCategoryInfo(
                categorie=cat_key,
                nom_affiche=cat_config["nom_affiche"],
                description=cat_config["description"],
                base_legale=cat_config["base_legale"],
                est_obligatoire=cat_config["est_obligatoire"],
                est_actif=est_actif,
                date_consentement=date_consentement,
                peut_etre_retire=cat_config["peut_etre_retire"],
                impact_retrait=cat_config["impact_retrait"],
            ))

        premier_eclairage = (
            f"Tu as {nb_actifs} traitement(s) actif(s) sur {len(CONSENT_CATEGORIES)}. "
            f"{nb_optionnels} sont optionnels et tu peux les desactiver a tout moment. "
            f"La nLPD te donne un controle total sur tes donnees."
        )

        return ConsentStatusResult(
            profile_id=profile_id,
            date_verification=now,
            consentements=consentements,
            nb_consentements_actifs=nb_actifs,
            nb_consentements_optionnels=nb_optionnels,
            premier_eclairage=premier_eclairage,
            disclaimer=DISCLAIMER,
            sources=SOURCES_CONSENT,
        )

    def update_consent(
        self,
        profile_id: str,
        categorie: str,
        est_actif: bool,
    ) -> ConsentUpdateResult:
        """Met a jour un consentement pour une categorie de traitement.

        Le retrait du consentement est un droit fondamental (nLPD art. 6 al. 7).
        Il ne peut pas etre retire pour les categories obligatoires (contrat).

        Args:
            profile_id: Identifiant unique du profil.
            categorie: Categorie de traitement a modifier.
            est_actif: True pour consentir, False pour retirer.

        Returns:
            ConsentUpdateResult avec le detail de la modification.

        Raises:
            ValueError: Si la categorie est obligatoire et que le retrait est demande.
            ValueError: Si la categorie n'existe pas.
        """
        if categorie not in CONSENT_CATEGORIES:
            raise ValueError(
                f"Categorie '{categorie}' inconnue. "
                f"Categories disponibles: {list(CONSENT_CATEGORIES.keys())}"
            )

        cat_config = CONSENT_CATEGORIES[categorie]

        if cat_config["est_obligatoire"] and not est_actif:
            raise ValueError(
                f"Le traitement '{cat_config['nom_affiche']}' est requis pour le "
                f"fonctionnement du service (nLPD art. 6 al. 6 — base contractuelle). "
                f"Tu ne peux pas le desactiver. Pour cesser ce traitement, "
                f"tu peux demander la suppression de ton compte."
            )

        now = datetime.now(timezone.utc).isoformat()

        if est_actif:
            message = (
                f"Consentement accorde pour '{cat_config['nom_affiche']}'. "
                f"Tu peux le retirer a tout moment depuis les parametres de confidentialite."
            )
        else:
            message = (
                f"Consentement retire pour '{cat_config['nom_affiche']}'. "
                f"{cat_config['impact_retrait']}"
            )

        return ConsentUpdateResult(
            profile_id=profile_id,
            categorie=categorie,
            est_actif=est_actif,
            date_modification=now,
            message=message,
            disclaimer=DISCLAIMER,
            sources=SOURCES_CONSENT,
        )
