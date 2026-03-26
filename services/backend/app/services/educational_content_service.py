"""
Educational Content Service — Contenu pedagogique pour les inserts du wizard.

Sert le contenu educatif (chiffre choc, objectifs d'apprentissage, disclaimer,
sources legales) pour chaque question du wizard MINT.

Sources:
    - LPP (Loi sur la prevoyance professionnelle)
    - LAVS (Loi sur l'AVS)
    - OPP3 (Ordonnance sur le 3e pilier)
    - LIFD (Loi sur l'impot federal direct)
    - LHID (Loi sur l'harmonisation des impots directs)
    - CC (Code civil suisse)
    - LSFin (Loi sur les services financiers)
    - LAA (Loi sur l'assurance-accidents)
    - LACI (Loi sur l'assurance-chomage)
    - FINMA (Autorite federale de surveillance des marches financiers)
    - LPart (Loi sur le partenariat enregistre)

Ethical requirements:
    - Educational tone, never prescriptive
    - Gender-neutral language (un-e specialiste)
    - No banned terms: garanti, certain, assure, sans risque, optimal, meilleur, parfait
    - Disclaimer on every insert
"""

from dataclasses import dataclass
from typing import Dict, List, Optional


# ══════════════════════════════════════════════════════════════════════════════
# Constants
# ══════════════════════════════════════════════════════════════════════════════

DISCLAIMER: str = (
    "Ceci est un outil educatif et ne constitue pas un conseil financier "
    "personnalise au sens de la LSFin. Les informations fournies sont indicatives "
    "et basees sur la legislation suisse en vigueur. Consulte un-e specialiste "
    "pour un conseil adapte a ta situation."
)

BANNED_TERMS: List[str] = [
    "garanti", "certain", "assure", "sans risque",
    "optimal", "meilleur", "parfait",
]


# ══════════════════════════════════════════════════════════════════════════════
# Data classes
# ══════════════════════════════════════════════════════════════════════════════

@dataclass
class InsertContent:
    """Educational insert content for a wizard question.

    Fields:
        question_id: Unique identifier matching the wizard question.
        title: Display title in French.
        chiffre_choc: Impactful number/statistic with explanatory text.
        learning_goals: List of learning objectives for the user.
        disclaimer: Legal disclaimer (mentions outil educatif and LSFin).
        sources: List of Swiss law references.
        action_label: Call-to-action button label.
        action_route: GoRouter route path (must start with /).
        phase: Wizard phase level (e.g., "Niveau 0", "Niveau 1", "Niveau 2").
        safe_mode: Safe mode behavior description.
    """
    question_id: str
    title: str
    chiffre_choc: str
    learning_goals: List[str]
    disclaimer: str
    sources: List[str]
    action_label: str
    action_route: str
    phase: str
    safe_mode: str


# ══════════════════════════════════════════════════════════════════════════════
# Insert data — 16 inserts (8 original + 8 new from S25)
# ══════════════════════════════════════════════════════════════════════════════

_INSERTS: Dict[str, InsertContent] = {}


def _register(insert: InsertContent) -> None:
    """Register an insert in the internal dictionary."""
    _INSERTS[insert.question_id] = insert


# --- Original 8 inserts (Niveau 0 + Niveau 1) ---

_register(InsertContent(
    question_id="q_financial_stress_check",
    title="Ton stress financier, en clair",
    chiffre_choc=(
        "La complexite financiere est la 1ere source de charge mentale "
        "pour les 22-45 ans en Suisse. En 30 secondes, identifie ton "
        "levier n-1 pour retrouver ton souffle."
    ),
    learning_goals=[
        "Identifier le type de stress financier predominant (budget, dette, impots, retraite).",
        "Comprendre que la charge mentale financiere peut etre reduite par un seul levier prioritaire.",
        "Decouvrir les 4 piliers d'action MINT : budget, dette, fiscalite, prevoyance.",
    ],
    disclaimer=DISCLAIMER,
    sources=[
        "LAVS (1er pilier)",
        "LPP (2e pilier)",
        "LIFD (impot federal direct)",
    ],
    action_label="Choisir mon levier n-1",
    action_route="/simulators/just_available",
    phase="Niveau 0",
    safe_mode="Toujours actif. C'est le point d'entree.",
))

_register(InsertContent(
    question_id="q_has_pension_fund",
    title="Affiliation LPP : es-tu couvert-e ?",
    chiffre_choc=(
        "Le seuil d'entree LPP est de 22'680 CHF/an. En dessous, "
        "tu n'es pas affilie-e au 2e pilier — et ton plafond 3a passe "
        "de 7'258 a 36'288 CHF/an."
    ),
    learning_goals=[
        "Comprendre le seuil d'entree LPP (22'680 CHF/an, LPP art. 7).",
        "Savoir que le statut LPP determine le plafond 3a (petit vs grand).",
        "Decouvrir que seule l'attestation de prevoyance fait foi pour le statut.",
    ],
    disclaimer=DISCLAIMER,
    sources=[
        "LPP art. 7 (seuil d'entree)",
        "LPP art. 2 (assujettissement)",
        "OPP3 art. 7 (plafond 3a)",
    ],
    action_label="Confirmer mon statut",
    action_route="/check/lpp-status",
    phase="Niveau 1",
    safe_mode="Informationnel uniquement.",
))

_register(InsertContent(
    question_id="q_has_3a",
    title="Pilier 3a : ton potentiel d'economie",
    chiffre_choc=(
        "Un-e salarie-e qui verse le maximum 3a (7'258 CHF) peut "
        "economiser entre 1'500 et 2'800 CHF d'impots par an selon "
        "le canton — de l'argent que tu laisses a l'Etat chaque annee sans 3a."
    ),
    learning_goals=[
        "Comprendre que le 3a est deductible du revenu imposable (LIFD art. 33).",
        "Savoir que l'economie fiscale depend du taux marginal d'imposition (canton).",
        "Decouvrir que l'eligibilite au 3a requiert un revenu soumis a l'AVS.",
    ],
    disclaimer=DISCLAIMER,
    sources=[
        "LIFD art. 33 (deduction 3a)",
        "OPP3 art. 7 (plafond annuel)",
        "LAVS art. 3 (revenu soumis AVS)",
    ],
    action_label="Voir mon potentiel d'economie",
    action_route="/simulators/tax_impact_3a",
    phase="Niveau 1",
    safe_mode="Masque si dette critique detectee.",
))

_register(InsertContent(
    question_id="q_3a_annual_amount",
    title="Economie fiscale 3a : combien tu gagnes",
    chiffre_choc=(
        "Ton versement 3a reduit directement ton revenu imposable. "
        "Sur 30 ans, la difference entre verser le maximum et ne rien "
        "verser peut depasser 100'000 CHF en economies d'impots cumulees."
    ),
    learning_goals=[
        "Comprendre le calcul de l'economie fiscale (montant verse x taux marginal).",
        "Savoir que l'effort d'epargne net est inferieur au montant verse (versement - economie fiscale).",
        "Decouvrir l'effet cumule sur 20-30 ans (interets composes + economies fiscales).",
    ],
    disclaimer=DISCLAIMER,
    sources=[
        "LIFD art. 33 (deduction 3a)",
        "OPP3 art. 7 (plafond annuel)",
    ],
    action_label="Simuler la croissance",
    action_route="/simulators/3a-growth",
    phase="Niveau 1",
    safe_mode="Desactive si dettes detectees (priorite au remboursement).",
))

_register(InsertContent(
    question_id="q_mortgage_type",
    title="Hypotheque : fixe, SARON ou mixte ?",
    chiffre_choc=(
        "Sur un pret de 600'000 CHF, la difference entre un taux fixe "
        "a 2.5% et un SARON a 1.5% represente 6'000 CHF/an — mais le "
        "SARON peut monter. Stabilite vs economie : un choix de tolerance au risque."
    ),
    learning_goals=[
        "Comprendre la difference entre taux fixe (stabilite) et SARON (variabilite).",
        "Savoir que le choix depend de la tolerance au risque et de l'horizon.",
        "Decouvrir que le renouvellement se negocie 12-18 mois avant l'echeance.",
    ],
    disclaimer=DISCLAIMER,
    sources=[
        "FINMA circ. 2017/7 (normes minimales hypothecaires)",
        "ASB (directives sur les financements hypothecaires)",
    ],
    action_label="Comparer les strategies",
    action_route="/simulators/mortgage-comparison",
    phase="Niveau 1",
    safe_mode="Priorite a la stabilite (taux fixe suggere) si budget tendu.",
))

_register(InsertContent(
    question_id="q_has_consumer_credit",
    title="Credit a la consommation : le cout reel",
    chiffre_choc=(
        "Un credit de 10'000 CHF a 9.9% sur 3 ans coute environ "
        "1'600 CHF d'interets — soit 16% du montant emprunte. "
        "Chaque mois, une partie de tes mensualites ne rembourse "
        "que les interets."
    ),
    learning_goals=[
        "Comprendre le TAEG (taux annuel effectif global) et son impact sur le cout total.",
        "Savoir que le remboursement anticipe est possible sans penalite (LCC art. 17).",
        "Decouvrir que le credit a la consommation est prioritaire a rembourser avant toute epargne.",
    ],
    disclaimer=DISCLAIMER,
    sources=[
        "LCC art. 17 (remboursement anticipe)",
        "LCC art. 30 (calcul du TAEG)",
        "LIFD (non-deductibilite des interets de credit conso)",
    ],
    action_label="Calculer le cout reel de mon credit",
    action_route="/simulators/consumer-credit-cost",
    phase="Niveau 1",
    safe_mode="Si credit detecte : active Safe Mode et priorise le remboursement.",
))

_register(InsertContent(
    question_id="q_has_leasing",
    title="Leasing : achat deguise ou flexibilite ?",
    chiffre_choc=(
        "Un leasing auto de 500 CHF/mois sur 4 ans coute 24'000 CHF — "
        "et a la fin tu ne possedes rien. L'achat d'un vehicule "
        "equivalent d'occasion pourrait couter 15'000 CHF au total."
    ),
    learning_goals=[
        "Comprendre que le leasing est une dette (mensualite fixe sans propriete a terme).",
        "Savoir que le leasing reduit la capacite d'emprunt hypothecaire (charges mensuelles).",
        "Decouvrir la comparaison financiere pure : leasing vs achat (cout total de detention).",
    ],
    disclaimer=DISCLAIMER,
    sources=[
        "CO art. 226a-226m (vente a temperament / leasing)",
        "FINMA (ratio d'endettement maximal)",
    ],
    action_label="Comparer Achat vs Leasing",
    action_route="/simulators/leasing-vs-buy",
    phase="Niveau 1",
    safe_mode="Considere comme dette si ratio d'endettement > 33%.",
))

_register(InsertContent(
    question_id="q_emergency_fund",
    title="Fonds d'urgence : ton filet de securite",
    chiffre_choc=(
        "3 a 6 mois de charges fixes : c'est le filet de securite "
        "recommande. En Suisse, un-e salarie-e sur trois n'a pas "
        "d'epargne de precaution suffisante pour tenir 3 mois."
    ),
    learning_goals=[
        "Comprendre le concept de fonds d'urgence (3-6 mois de charges fixes).",
        "Savoir que les charges fixes representent environ 50% du revenu si non detaillees.",
        "Decouvrir que le fonds d'urgence est la priorite n-1 avant toute epargne ou investissement.",
    ],
    disclaimer=DISCLAIMER,
    sources=[
        "Bonne pratique financiere (recommandation standard)",
        "LACI art. 8 (droit aux indemnites de chomage — delai de carence)",
    ],
    action_label="Definir mon objectif d'epargne",
    action_route="/budget/emergency-fund",
    phase="Niveau 1",
    safe_mode="Toujours actif. C'est la priorite numero 1.",
))

# --- New 8 inserts (S25 — Niveau 1 + Niveau 2) ---

_register(InsertContent(
    question_id="q_civil_status",
    title="Etat civil : impact financier et patrimonial",
    chiffre_choc=(
        "Un couple marie peut economiser jusqu'a 6'000 CHF/an d'impots "
        "par rapport a deux concubins selon le canton — mais ailleurs "
        "c'est l'inverse (penalite du mariage)."
    ),
    learning_goals=[
        "Comprendre que le mariage implique un regime matrimonial (participation aux acquets par defaut, CC art. 181).",
        "Savoir que le concubinage n'offre aucune protection legale automatique (pas de part reservataire).",
        "Decouvrir que le divorce entraine un partage du 2e pilier impose par la loi (LPP art. 22).",
        "Comprendre l'impact fiscal du mariage : imposition commune (LIFD art. 9 al. 1).",
        "Savoir que le PACS donne les memes droits fiscaux et successoraux que le mariage (LPart art. 1).",
    ],
    disclaimer=DISCLAIMER,
    sources=[
        "CC art. 159-251 (regime matrimonial)",
        "CC art. 470-471 (reserves hereditaires, revision 2023)",
        "LPP art. 22 (partage LPP en cas de divorce)",
        "LIFD art. 9 al. 1 (imposition commune des epoux)",
        "LPart art. 1ss (partenariat enregistre)",
    ],
    action_label="Simuler l'impact financier de mon etat civil",
    action_route="/simulators/civil-status-impact",
    phase="Niveau 1",
    safe_mode="Si dette critique detectee : priorite au desendettement.",
))

_register(InsertContent(
    question_id="q_employment_status",
    title="Statut professionnel : tes droits et couvertures",
    chiffre_choc=(
        "Un independant sans LPP volontaire peut cotiser jusqu'a "
        "36'288 CHF/an au 3a — soit 5x plus qu'un salarie (7'258 CHF). "
        "Mais il perd l'assurance invalidite LPP."
    ),
    learning_goals=[
        "Comprendre les 3 regimes : salarie, independant, sans activite lucrative.",
        "Savoir que le salarie beneficie automatiquement de l'AVS (LAVS art. 3), du LPP (LPP art. 2) et de la LAA (LAA art. 1a).",
        "Decouvrir que l'independant doit tout organiser lui-meme : AVS, LPP volontaire, IJM, assurance accident.",
        "Comprendre que le chomage donne droit a l'AC (LACI art. 8) et maintient la couverture LPP pendant 2 ans max.",
        "Savoir que le sans-activite lucrative cotise quand meme a l'AVS (LAVS art. 10).",
    ],
    disclaimer=DISCLAIMER,
    sources=[
        "LAVS art. 3, 10 (cotisations AVS)",
        "LPP art. 2, 4, 7 (assujettissement LPP)",
        "LAA art. 1a (assurance accident)",
        "LACI art. 8 (droit aux indemnites de chomage)",
        "OPP3 art. 7 (3a independant sans LPP)",
    ],
    action_label="Explorer les outils adaptes a mon statut",
    action_route="/segments/employment-status",
    phase="Niveau 1",
    safe_mode="Si dette critique detectee : priorite au desendettement.",
))

_register(InsertContent(
    question_id="q_housing_status",
    title="Logement : locataire ou proprietaire",
    chiffre_choc=(
        "En Suisse, seuls 36% des menages sont proprietaires — le taux "
        "le plus bas d'Europe. Pourtant, un proprietaire paie en moyenne "
        "15-25% de moins par mois qu'un locataire equivalent apres 15 ans "
        "d'amortissement."
    ),
    learning_goals=[
        "Comprendre que la propriete en Suisse implique un apport minimum de 20% (FINMA circ. 2017/7).",
        "Savoir que le proprietaire paie l'impot sur la valeur locative (LIFD art. 21 al. 1 let. b) mais peut deduire les interets hypothecaires.",
        "Decouvrir le mecanisme de l'EPL : retrait LPP + 3a pour financer l'apport (LPP art. 30c).",
        "Comprendre le calcul de la capacite d'emprunt : charges max 1/3 du revenu brut, au taux theorique de 5%.",
        "Savoir que le locataire conserve sa flexibilite et sa liquidite.",
    ],
    disclaimer=DISCLAIMER,
    sources=[
        "FINMA circ. 2017/7 (normes minimales hypothecaires)",
        "LIFD art. 21 al. 1 let. b (valeur locative)",
        "LIFD art. 32 (deduction des frais d'entretien)",
        "LPP art. 30c (EPL)",
        "OPP2 art. 30d-30g (modalites EPL)",
    ],
    action_label="Simuler ma capacite d'emprunt",
    action_route="/mortgage/affordability",
    phase="Niveau 1",
    safe_mode="Si dette critique detectee : priorite au desendettement avant tout projet immobilier.",
))

_register(InsertContent(
    question_id="q_canton",
    title="Canton de residence : ton premier levier fiscal",
    chiffre_choc=(
        "Pour un revenu de 100'000 CHF, l'impot varie de ~8% a Zoug "
        "a ~30% a Geneve — soit une difference de plus de 22'000 CHF "
        "par an. Ton canton est le premier levier fiscal en Suisse."
    ),
    learning_goals=[
        "Comprendre que la Suisse a 3 niveaux d'imposition : federal (fixe), cantonal et communal (variables).",
        "Savoir que le taux effectif d'imposition varie enormement d'un canton a l'autre.",
        "Decouvrir que les deductions (3a, LPP, frais medicaux, enfants) varient aussi par canton.",
        "Comprendre que la fortune est imposee annuellement au niveau cantonal (pas federal).",
        "Savoir que les 26 cantons ont leurs propres baremes, allocations familiales et primes LAMal.",
    ],
    disclaimer=DISCLAIMER,
    sources=[
        "LIFD (impot federal direct)",
        "LHID (loi sur l'harmonisation des impots directs)",
        "Lois cantonales sur les impots directs (26 lois)",
        "OFS Statistique fiscale de la Suisse",
    ],
    action_label="Comparer la fiscalite des 26 cantons",
    action_route="/fiscal/canton-comparison",
    phase="Niveau 1",
    safe_mode="Si dette critique detectee : la fiscalite est un levier, mais priorite au desendettement.",
))

_register(InsertContent(
    question_id="q_lpp_buyback_available",
    title="Rachat LPP : un rendement fiscal immediat",
    chiffre_choc=(
        "Un rachat LPP de 20'000 CHF peut te faire economiser entre "
        "5'000 et 8'000 CHF d'impots l'annee meme — c'est un rendement "
        "fiscal immediat de 25 a 40%."
    ),
    learning_goals=[
        "Comprendre que le rachat LPP est deductible a 100% du revenu imposable (LPP art. 79b).",
        "Savoir que le montant maximum de rachat figure sur le certificat de prevoyance.",
        "Decouvrir la strategie d'echelonnement : repartir les rachats sur 3-5 ans pour la progressivite.",
        "Comprendre le blocage EPL : apres un rachat, pas de retrait EPL pendant 3 ans (LPP art. 79b al. 3).",
        "Savoir que le rachat augmente aussi ta rente future (ou ton capital de retrait).",
    ],
    disclaimer=DISCLAIMER,
    sources=[
        "LPP art. 79b (rachat de prestations)",
        "LPP art. 79b al. 3 (blocage EPL 3 ans)",
        "LIFD art. 33 al. 1 let. d (deduction des cotisations LPP)",
        "OPP2 art. 60a (calcul du potentiel de rachat)",
    ],
    action_label="Simuler l'economie fiscale de mon rachat",
    action_route="/simulators/lpp-buyback",
    phase="Niveau 2",
    safe_mode="Si dette critique detectee : priorite au desendettement. Le rachat bloque la liquidite.",
))

_register(InsertContent(
    question_id="q_3a_accounts_count",
    title="Nombre de comptes 3a : la strategie d'echelonnement",
    chiffre_choc=(
        "Avec 5 comptes 3a retires sur 5 ans au lieu d'un seul, tu "
        "peux economiser entre 8'000 et 25'000 CHF d'impots sur le "
        "retrait — car chaque retrait est impose separement a un taux plus bas."
    ),
    learning_goals=[
        "Comprendre que le retrait du 3a est impose comme un revenu (taux progressif, LIFD art. 38).",
        "Savoir que les retraits de la meme annee sont additionnes pour le calcul du taux.",
        "Decouvrir la strategie d'echelonnement : ouvrir 4-5 comptes et les retirer sur 4-5 annees differentes.",
        "Comprendre que les retraits 3a et LPP en capital de la meme annee se cumulent pour l'imposition.",
        "Savoir que l'age de retrait anticipe est 5 ans avant l'age de reference AVS : 60 ans (hommes), 59 ans (femmes nees avant 1964) ou 60 ans (femmes nees des 1964) — OPP3 art. 3 al. 1.",
    ],
    disclaimer=DISCLAIMER,
    sources=[
        "OPP3 art. 3 (retrait du 3a)",
        "LIFD art. 38 (imposition separee des prestations en capital)",
        "Lois cantonales sur l'imposition des prestations en capital",
        "OPP3 art. 2 (plafond annuel 3a)",
    ],
    action_label="Simuler l'economie avec l'echelonnement 3a",
    action_route="/simulators/3a-staggering",
    phase="Niveau 2",
    safe_mode="Si dette critique detectee : priorite au desendettement.",
))

_register(InsertContent(
    question_id="q_has_investments",
    title="Placements : le regime fiscal suisse",
    chiffre_choc=(
        "En Suisse, les gains en capital prives sont exoneres d'impot "
        "(LIFD art. 16 al. 3) — mais les dividendes et interets sont "
        "imposes a 100%. Placer 100'000 CHF en valeurs mobilieres peut "
        "generer 3'000 a 5'000 CHF/an de rendement supplementaire."
    ),
    learning_goals=[
        "Comprendre que les gains en capital prives ne sont PAS imposes en Suisse (LIFD art. 16 al. 3).",
        "Savoir que les dividendes et interets sont imposables comme revenu ordinaire (LIFD art. 20).",
        "Decouvrir que la fortune est imposee chaque annee (impot cantonal sur la fortune).",
        "Comprendre le concept de risque vs rendement : les valeurs mobilieres suisses (SPI) ont rendu ~7%/an sur 20 ans.",
        "Savoir que MINT ne donne pas de conseil en investissement (LSFin art. 3).",
    ],
    disclaimer=DISCLAIMER,
    sources=[
        "LIFD art. 16 al. 3 (exoneration gains en capital prives)",
        "LIFD art. 20 (imposition des rendements de fortune)",
        "LSFin art. 3 (conseil en investissement)",
        "FINMA circ. 2018/3 (regles de conduite)",
    ],
    action_label="Decouvrir les bases de la diversification",
    action_route="/learn/investments-basics",
    phase="Niveau 2",
    safe_mode="Si dette critique detectee : priorite au desendettement avant tout investissement.",
))

_register(InsertContent(
    question_id="q_real_estate_project",
    title="Projet immobilier : capacite d'emprunt et apport",
    chiffre_choc=(
        "Pour un bien a 800'000 CHF, il te faut 160'000 CHF d'apport "
        "personnel — dont maximum 80'000 CHF de ton 2e pilier. Tes charges "
        "mensuelles theoriques seront d'environ 4'670 CHF, soit un revenu "
        "brut minimum de 14'000 CHF/mois."
    ),
    learning_goals=[
        "Comprendre la regle des 20% d'apport : minimum 10% en cash ou 3a, max 10% du 2e pilier (FINMA circ. 2017/7).",
        "Savoir calculer la capacite d'emprunt : charges (5% + 1% + 1%) max 1/3 du revenu brut.",
        "Decouvrir les 3 sources d'apport : epargne, 3a (retrait integral), LPP (EPL, LPP art. 30c).",
        "Comprendre la difference entre hypotheque 1er rang (max 65%) et 2e rang (a amortir en 15 ans).",
        "Savoir que l'achat declenche des frais uniques : notaire (~1-3%), droits de mutation, frais bancaires.",
    ],
    disclaimer=DISCLAIMER,
    sources=[
        "FINMA circ. 2017/7 (normes minimales hypothecaires)",
        "ASB Directives sur les financements hypothecaires",
        "LPP art. 30c (EPL — encouragement a la propriete)",
        "OPP2 art. 30d-30g (modalites EPL)",
        "LIFD art. 21 al. 1 let. b (valeur locative)",
    ],
    action_label="Simuler ma capacite d'emprunt",
    action_route="/mortgage/affordability",
    phase="Niveau 2",
    safe_mode="Si dette critique detectee : priorite au desendettement avant tout projet immobilier.",
))


# ══════════════════════════════════════════════════════════════════════════════
# Service
# ══════════════════════════════════════════════════════════════════════════════

class EducationalContentService:
    """Serve educational insert content for wizard questions.

    Provides educational inserts keyed by question_id. Each insert includes
    a chiffre choc, learning goals, disclaimer, and Swiss law sources.

    Compliance:
        - NEVER use banned terms (garanti, certain, assure, sans risque,
          optimal, meilleur, parfait)
        - Disclaimer must mention "outil educatif" and "LSFin"
        - Sources must be real Swiss law references
        - Educational tone, never prescriptive
    """

    def get_insert(self, question_id: str) -> Optional[InsertContent]:
        """Return the educational insert for a given question ID.

        Args:
            question_id: The wizard question identifier (e.g., "q_has_3a").

        Returns:
            InsertContent if found, None otherwise.
        """
        return _INSERTS.get(question_id)

    def get_all_inserts(self) -> List[InsertContent]:
        """Return all educational inserts.

        Returns:
            List of all 16 InsertContent instances.
        """
        return list(_INSERTS.values())

    def get_inserts_by_phase(self, phase: str) -> List[InsertContent]:
        """Return all educational inserts for a given phase.

        Args:
            phase: The wizard phase (e.g., "Niveau 0", "Niveau 1", "Niveau 2").

        Returns:
            List of InsertContent matching the phase.
        """
        return [
            insert for insert in _INSERTS.values()
            if insert.phase == phase
        ]
