"""
Consent Manager — Sprint S40.

Manages granular consent for data flows (nLPD compliant).

3 independent consents:
    1. BYOK data sharing — sending CoachContext to LLM provider
    2. Snapshot storage — longitudinal tracking
    3. Notifications — personalized push notifications

Each consent: independent, revocable immediately, OFF by default.

Sources:
    - LPD art. 6 (principes de traitement)
    - nLPD art. 5 let. f (profilage)
    - LSFin art. 3 (information financiere)
"""

from app.services.reengagement.reengagement_models import (
    ConsentDashboard,
    ConsentState,
    ConsentType,
)


class ConsentManager:
    """Manages granular consent for data flows.

    3 independent consents (LPD/nLPD compliant):
    1. BYOK data sharing — sending CoachContext to LLM provider
    2. Snapshot storage — longitudinal tracking
    3. Notifications — personalized push notifications

    Each consent: independent, revocable immediately.
    """

    # Fields sent to LLM provider when BYOK consent is ON
    BYOK_SENT_FIELDS = [
        "firstName",
        "archetype",
        "age",
        "canton",
        "friTotal",
        "friDelta",
        "replacementRatio",
        "monthsLiquidity",
        "taxSavingPotential",
        "confidenceScore",
        "daysSinceLastVisit",
        "fiscalSeason",
    ]

    # Fields NEVER sent to LLM provider (regardless of consent)
    BYOK_NEVER_SENT_FIELDS = [
        "exact salary",
        "exact savings",
        "exact debt",
        "bank names",
        "employer name",
        "NPA/address",
        "family names",
    ]

    def get_default_dashboard(self) -> ConsentDashboard:
        """Return consent dashboard with all consents OFF by default.

        nLPD requires opt-in (not opt-out), so every consent starts OFF.
        """
        consents = [
            ConsentState(
                consent_type=ConsentType.byok_data_sharing,
                enabled=False,
                label="Partage de donnees avec le coach IA",
                detail=(
                    "Envoie ton contexte anonymise (archetype, age, canton, "
                    "scores) au fournisseur LLM pour personnaliser les reponses."
                ),
                never_sent=(
                    "Jamais envoye : salaire exact, epargne exacte, dettes, "
                    "noms de banques, employeur, adresse, noms de famille."
                ),
                revocable=True,
            ),
            ConsentState(
                consent_type=ConsentType.snapshot_storage,
                enabled=False,
                label="Suivi longitudinal de ton profil",
                detail=(
                    "Sauvegarde periodique de tes scores (FRI, ratio de "
                    "remplacement, liquidite) pour mesurer ta progression."
                ),
                never_sent=(
                    "Jamais stocke : montants exacts, releves bancaires, "
                    "donnees d'employeur, informations familiales nominatives."
                ),
                revocable=True,
            ),
            ConsentState(
                consent_type=ConsentType.notifications,
                enabled=False,
                label="Notifications personnalisees",
                detail=(
                    "Recois des rappels lies au calendrier fiscal suisse "
                    "(3a, declaration, deadlines) avec tes chiffres personnels."
                ),
                never_sent=(
                    "Jamais partage : tes donnees ne quittent pas l'appareil "
                    "pour generer les notifications. Calcul 100%% local."
                ),
                revocable=True,
            ),
        ]

        return ConsentDashboard(consents=consents)

    def get_byok_detail(self) -> dict:
        """Return exactly which fields are sent to LLM provider.

        Sent: firstName, archetype, age, canton, friTotal, friDelta,
              replacementRatio, monthsLiquidity, taxSavingPotential,
              confidenceScore, daysSinceLastVisit, fiscalSeason

        NEVER sent: exact salary, exact savings, exact debt,
                    bank names, employer name, NPA/address, family names

        Returns:
            dict with keys: sent_fields, never_sent_fields, disclaimer, sources
        """
        return {
            "sent_fields": list(self.BYOK_SENT_FIELDS),
            "never_sent_fields": list(self.BYOK_NEVER_SENT_FIELDS),
            "disclaimer": (
                "Outil educatif simplifie. Ne constitue pas un conseil "
                "financier (LSFin). Tes donnees t'appartiennent et chaque "
                "consentement est revocable a tout moment (nLPD art. 6)."
            ),
            "sources": [
                "LPD art. 6 (principes de traitement)",
                "nLPD art. 5 let. f (profilage)",
                "LSFin art. 3 (information financiere)",
            ],
        }
