"""
Pydantic v2 schemas for the Mortgage & Real Estate module.

Sprint S17 — Mortgage & Real Estate.
API convention: camelCase field names, ConfigDict.

Covers:
    - Affordability (Tragbarkeitsrechnung)
    - SARON vs Fixed rate comparison
    - Imputed rental value (Eigenmietwert)
    - Direct vs indirect amortization
    - Combined EPL (3a + LPP) for housing equity
"""

from pydantic import BaseModel, Field, ConfigDict
from typing import List, Optional, Dict


# ===========================================================================
# Shared sub-schemas
# ===========================================================================

class PremierEclairageResponse(BaseModel):
    """Shock figure with amount and text."""

    model_config = ConfigDict(populate_by_name=True)

    montant: float = Field(..., description="Montant du premier éclairage (CHF)")
    texte: str = Field(..., description="Texte explicatif")


class DecompositionChargesResponse(BaseModel):
    """Breakdown of theoretical monthly housing costs."""

    model_config = ConfigDict(populate_by_name=True)

    interets: float = Field(..., description="Interets theoriques mensuels (CHF)")
    amortissement: float = Field(..., description="Amortissement mensuel (CHF)")
    fraisAccessoires: float = Field(
        ..., alias="fraisAccessoires",
        description="Frais accessoires mensuels (CHF)"
    )


# ===========================================================================
# Affordability Schemas
# ===========================================================================

class MortgageAffordabilityRequest(BaseModel):
    """Request for mortgage affordability calculation."""

    model_config = ConfigDict(populate_by_name=True)

    revenuBrutAnnuel: float = Field(
        ..., alias="revenuBrutAnnuel",
        description="Revenu brut annuel du menage (CHF)", ge=0
    )
    epargneDisponible: float = Field(
        ..., alias="epargneDisponible",
        description="Epargne disponible / cash (CHF)", ge=0
    )
    avoir3a: float = Field(
        0, alias="avoir3a",
        description="Avoir 3a disponible pour EPL (CHF)", ge=0
    )
    avoirLpp: float = Field(
        0, alias="avoirLpp",
        description="Avoir LPP disponible pour EPL (CHF)", ge=0
    )
    prixAchat: float = Field(
        0, alias="prixAchat",
        description="Prix d'achat cible (CHF). 0 = calculer le max.", ge=0
    )
    canton: str = Field(
        "ZH", description="Code canton (ex: ZH, VD, GE)",
        min_length=2, max_length=2
    )


class MortgageAffordabilityResponse(BaseModel):
    """Full response for mortgage affordability calculation."""

    model_config = ConfigDict(populate_by_name=True)

    # Max price
    prixMaxAccessible: float = Field(
        ..., alias="prixMaxAccessible",
        description="Prix max accessible selon revenu et fonds propres (CHF)"
    )

    # Equity
    fondsPropresTotalNet: float = Field(
        ..., alias="fondsPropresTotalNet",
        description="Total fonds propres (CHF)"
    )
    fondsPropresSuffisants: bool = Field(
        ..., alias="fondsPropresSuffisants",
        description="Les fonds propres couvrent-ils 20%?"
    )
    detailFondsPropres: Dict[str, float] = Field(
        ..., alias="detailFondsPropres",
        description="Detail des fonds propres par source"
    )

    # Charges
    chargesMensuellesTheoriques: float = Field(
        ..., alias="chargesMensuellesTheoriques",
        description="Charges mensuelles theoriques (CHF)"
    )
    ratioCharges: float = Field(
        ..., alias="ratioCharges",
        description="Ratio charges / revenu (0-1)"
    )
    capaciteOk: bool = Field(
        ..., alias="capaciteOk",
        description="Le ratio est-il <= 33%?"
    )
    decompositionCharges: DecompositionChargesResponse = Field(
        ..., alias="decompositionCharges",
        description="Detail des charges mensuelles"
    )

    # Mortgage
    montantHypothecaire: float = Field(
        ..., alias="montantHypothecaire",
        description="Montant de l'hypotheque (CHF)"
    )

    # Metadata
    prixAchat: float = Field(..., alias="prixAchat")
    revenuBrutAnnuel: float = Field(..., alias="revenuBrutAnnuel")
    canton: str

    # Compliance
    premierEclairage: PremierEclairageResponse = Field(
        ..., alias="premierEclairage",
        description="Chiffre choc"
    )
    checklist: List[str] = Field(default_factory=list)
    alertes: List[str] = Field(default_factory=list)
    sources: List[str] = Field(default_factory=list)
    disclaimer: str = Field(..., description="Avertissement legal")


# ===========================================================================
# SARON vs Fixed Schemas
# ===========================================================================

class SaronVsFixedRequest(BaseModel):
    """Request for SARON vs Fixed rate comparison."""

    model_config = ConfigDict(populate_by_name=True)

    montantHypothecaire: float = Field(
        ..., alias="montantHypothecaire",
        description="Montant de l'hypotheque (CHF)", ge=0
    )
    dureeAns: int = Field(
        10, alias="dureeAns",
        description="Duree en annees", ge=1, le=30
    )
    tauxSaronActuel: Optional[float] = Field(
        None, alias="tauxSaronActuel",
        description="Taux SARON compose actuel (ex: 0.0125 pour 1.25%)"
    )
    margeBanque: Optional[float] = Field(
        None, alias="margeBanque",
        description="Marge banque sur SARON (ex: 0.008 pour 0.8%)"
    )
    tauxFixe: Optional[float] = Field(
        None, alias="tauxFixe",
        description="Taux fixe pour comparaison (ex: 0.025 pour 2.5%)"
    )


class GrapheEntryResponse(BaseModel):
    """Single year in the comparison chart."""

    model_config = ConfigDict(populate_by_name=True)

    annee: int
    mensualiteFixe: float = Field(..., alias="mensualiteFixe")
    mensualiteSaron: float = Field(..., alias="mensualiteSaron")


class ScenarioResultResponse(BaseModel):
    """Result for a single SARON scenario."""

    model_config = ConfigDict(populate_by_name=True)

    nom: str
    label: str
    coutTotalInterets: float = Field(
        ..., alias="coutTotalInterets",
        description="Cout total des interets (CHF)"
    )
    mensualiteMoyenne: float = Field(..., alias="mensualiteMoyenne")
    mensualiteMin: float = Field(..., alias="mensualiteMin")
    mensualiteMax: float = Field(..., alias="mensualiteMax")
    differenceVsFixe: float = Field(
        ..., alias="differenceVsFixe",
        description="Difference vs taux fixe (CHF, negatif = moins cher)"
    )
    grapheData: List[GrapheEntryResponse] = Field(
        ..., alias="grapheData"
    )


class SaronVsFixedResponse(BaseModel):
    """Full response for SARON vs Fixed comparison."""

    model_config = ConfigDict(populate_by_name=True)

    # Fixed rate
    tauxFixe: float = Field(..., alias="tauxFixe")
    coutTotalFixe: float = Field(
        ..., alias="coutTotalFixe",
        description="Cout total interets taux fixe (CHF)"
    )
    mensualiteFixe: float = Field(
        ..., alias="mensualiteFixe",
        description="Mensualite taux fixe (CHF)"
    )

    # Scenarios
    scenarios: List[ScenarioResultResponse]

    # Best
    meilleurScenario: str = Field(..., alias="meilleurScenario")
    economieMax: float = Field(
        ..., alias="economieMax",
        description="Economie max vs fixe (CHF)"
    )

    # Metadata
    montantHypothecaire: float = Field(..., alias="montantHypothecaire")
    dureeAns: int = Field(..., alias="dureeAns")
    tauxSaronActuel: float = Field(..., alias="tauxSaronActuel")
    margeBanque: float = Field(..., alias="margeBanque")

    # Compliance
    premierEclairage: PremierEclairageResponse = Field(
        ..., alias="premierEclairage",
        description="Chiffre choc"
    )
    sources: List[str] = Field(default_factory=list)
    disclaimer: str = Field(..., description="Avertissement legal")


# ===========================================================================
# Imputed Rental Value Schemas
# ===========================================================================

class ImputedRentalRequest(BaseModel):
    """Request for imputed rental value calculation."""

    model_config = ConfigDict(populate_by_name=True)

    valeurVenale: float = Field(
        ..., alias="valeurVenale",
        description="Valeur venale du bien (CHF)", ge=0
    )
    canton: str = Field(
        "ZH", description="Code canton",
        min_length=2, max_length=2
    )
    interetsHypothecairesAnnuels: float = Field(
        0, alias="interetsHypothecairesAnnuels",
        description="Interets hypothecaires annuels payes (CHF)", ge=0
    )
    fraisEntretienAnnuels: float = Field(
        0, alias="fraisEntretienAnnuels",
        description="Frais d'entretien reels annuels (CHF)", ge=0
    )
    primeAssuranceBatiment: float = Field(
        0, alias="primeAssuranceBatiment",
        description="Prime d'assurance batiment annuelle (CHF)", ge=0
    )
    ageBienAns: int = Field(
        5, alias="ageBienAns",
        description="Age du bien en annees", ge=0
    )
    tauxMarginalImposition: float = Field(
        0.30, alias="tauxMarginalImposition",
        description="Taux marginal d'imposition (0-0.5)", ge=0, le=0.5
    )


class ImputedRentalResponse(BaseModel):
    """Full response for imputed rental value calculation."""

    model_config = ConfigDict(populate_by_name=True)

    # Imputed rental value
    valeurLocative: float = Field(
        ..., alias="valeurLocative",
        description="Valeur locative annuelle (CHF)"
    )
    tauxValeurLocative: float = Field(
        ..., alias="tauxValeurLocative",
        description="Taux de valeur locative utilise"
    )

    # Deductions
    deductionInterets: float = Field(
        ..., alias="deductionInterets",
        description="Deduction interets hypothecaires (CHF)"
    )
    deductionEntretien: float = Field(
        ..., alias="deductionEntretien",
        description="Deduction frais entretien (CHF)"
    )
    deductionAssurance: float = Field(
        ..., alias="deductionAssurance",
        description="Deduction assurance batiment (CHF)"
    )
    deductionsTotal: float = Field(
        ..., alias="deductionsTotal",
        description="Total deductions (CHF)"
    )

    # Net impact
    impactRevenuImposable: float = Field(
        ..., alias="impactRevenuImposable",
        description="Impact net sur le revenu imposable (CHF)"
    )
    impactFiscalNet: float = Field(
        ..., alias="impactFiscalNet",
        description="Impact fiscal net annuel (CHF)"
    )
    estAvantageFiscal: bool = Field(
        ..., alias="estAvantageFiscal",
        description="Les deductions depassent-elles la valeur locative?"
    )

    # Maintenance recommendation
    forfaitEntretienApplicable: float = Field(
        ..., alias="forfaitEntretienApplicable",
        description="Forfait entretien applicable (10% ou 20%)"
    )
    forfaitEntretienMontant: float = Field(
        ..., alias="forfaitEntretienMontant",
        description="Montant du forfait entretien (CHF)"
    )
    recommandationForfaitVsReel: str = Field(
        ..., alias="recommandationForfaitVsReel",
        description="Recommandation: forfait ou reel"
    )

    # Metadata
    valeurVenale: float = Field(..., alias="valeurVenale")
    canton: str
    ageBienAns: int = Field(..., alias="ageBienAns")
    tauxMarginalImposition: float = Field(..., alias="tauxMarginalImposition")

    # Compliance
    premierEclairage: PremierEclairageResponse = Field(
        ..., alias="premierEclairage",
        description="Chiffre choc"
    )
    sources: List[str] = Field(default_factory=list)
    disclaimer: str = Field(..., description="Avertissement legal")


# ===========================================================================
# Amortization Comparison Schemas
# ===========================================================================

class AmortizationComparisonRequest(BaseModel):
    """Request for direct vs indirect amortization comparison."""

    model_config = ConfigDict(populate_by_name=True)

    montantHypothecaire: float = Field(
        ..., alias="montantHypothecaire",
        description="Montant de l'hypotheque (CHF)", ge=0
    )
    tauxInteret: float = Field(
        ..., alias="tauxInteret",
        description="Taux d'interet hypothecaire (0-0.10)", ge=0, le=0.10
    )
    dureeAns: int = Field(
        15, alias="dureeAns",
        description="Duree en annees", ge=1, le=40
    )
    versementAnnuelAmortissement: float = Field(
        0, alias="versementAnnuelAmortissement",
        description="Versement annuel d'amortissement (CHF)", ge=0
    )
    tauxMarginalImposition: float = Field(
        0.30, alias="tauxMarginalImposition",
        description="Taux marginal d'imposition (0-0.5)", ge=0, le=0.5
    )
    rendement3a: float = Field(
        0.02, alias="rendement3a",
        description="Rendement attendu du 3a (0-0.10)", ge=-0.05, le=0.10
    )
    canton: str = Field(
        "ZH", description="Code canton",
        min_length=2, max_length=2
    )


class AmortDirectResponse(BaseModel):
    """Result for direct amortization."""

    model_config = ConfigDict(populate_by_name=True)

    detteFinale: float = Field(
        ..., alias="detteFinale",
        description="Dette restante a la fin (CHF)"
    )
    interetsPayesTotal: float = Field(
        ..., alias="interetsPayesTotal",
        description="Total interets payes (CHF)"
    )
    deductionFiscaleCumulee: float = Field(
        ..., alias="deductionFiscaleCumulee",
        description="Total deductions fiscales (CHF)"
    )
    coutNetTotal: float = Field(
        ..., alias="coutNetTotal",
        description="Cout net total (CHF)"
    )


class AmortIndirectResponse(BaseModel):
    """Result for indirect amortization."""

    model_config = ConfigDict(populate_by_name=True)

    detteFinale: float = Field(
        ..., alias="detteFinale",
        description="Dette restante (constante) (CHF)"
    )
    interetsPayesTotal: float = Field(
        ..., alias="interetsPayesTotal",
        description="Total interets payes (CHF)"
    )
    deductionFiscaleCumulee: float = Field(
        ..., alias="deductionFiscaleCumulee",
        description="Total deductions fiscales (interets + 3a) (CHF)"
    )
    capital3aCumule: float = Field(
        ..., alias="capital3aCumule",
        description="Capital 3a cumule (CHF)"
    )
    coutNetTotal: float = Field(
        ..., alias="coutNetTotal",
        description="Cout net total (CHF)"
    )


class AmortGrapheEntryResponse(BaseModel):
    """Single year in the amortization comparison chart."""

    model_config = ConfigDict(populate_by_name=True)

    annee: int
    detteDirect: float = Field(..., alias="detteDirect")
    detteIndirect: float = Field(..., alias="detteIndirect")
    capital3a: float = Field(..., alias="capital3a")
    coutCumuleDirect: float = Field(..., alias="coutCumuleDirect")
    coutCumuleIndirect: float = Field(..., alias="coutCumuleIndirect")


class AmortizationComparisonResponse(BaseModel):
    """Full response for direct vs indirect amortization comparison."""

    model_config = ConfigDict(populate_by_name=True)

    # Direct
    direct: AmortDirectResponse

    # Indirect
    indirect: AmortIndirectResponse

    # Difference
    differenceNette: float = Field(
        ..., alias="differenceNette",
        description="Difference nette en faveur de la methode avantageuse (CHF)"
    )
    methodeAvantageuse: str = Field(
        ..., alias="methodeAvantageuse",
        description="Methode la plus avantageuse: direct ou indirect"
    )

    # Graph
    grapheData: List[AmortGrapheEntryResponse] = Field(
        ..., alias="grapheData"
    )

    # Metadata
    montantHypothecaire: float = Field(..., alias="montantHypothecaire")
    tauxInteret: float = Field(..., alias="tauxInteret")
    dureeAns: int = Field(..., alias="dureeAns")
    versementAnnuel: float = Field(..., alias="versementAnnuel")
    tauxMarginalImposition: float = Field(..., alias="tauxMarginalImposition")
    rendement3a: float = Field(..., alias="rendement3a")
    canton: str

    # Compliance
    premierEclairage: PremierEclairageResponse = Field(
        ..., alias="premierEclairage",
        description="Chiffre choc"
    )
    sources: List[str] = Field(default_factory=list)
    disclaimer: str = Field(..., description="Avertissement legal")


# ===========================================================================
# EPL Combined Schemas
# ===========================================================================

class EplCombinedRequest(BaseModel):
    """Request for combined EPL (3a + LPP) equity calculation."""

    model_config = ConfigDict(populate_by_name=True)

    avoir3a: float = Field(
        0, alias="avoir3a",
        description="Avoir 3a total (CHF)", ge=0
    )
    avoirLppTotal: float = Field(
        0, alias="avoirLppTotal",
        description="Avoir LPP total (CHF)", ge=0
    )
    avoirObligatoire: float = Field(
        0, alias="avoirObligatoire",
        description="Part obligatoire LPP (CHF)", ge=0
    )
    avoirSurobligatoire: float = Field(
        0, alias="avoirSurobligatoire",
        description="Part surobligatoire LPP (CHF)", ge=0
    )
    age: int = Field(
        35, description="Age actuel", ge=18, le=70
    )
    canton: str = Field(
        "ZH", description="Code canton",
        min_length=2, max_length=2
    )
    epargneCash: float = Field(
        0, alias="epargneCash",
        description="Epargne cash (CHF)", ge=0
    )
    prixCible: float = Field(
        0, alias="prixCible",
        description="Prix cible du bien (CHF, 0 = pas de cible)", ge=0
    )
    aRacheteRecemment: bool = Field(
        False, alias="aRacheteRecemment",
        description="Rachat LPP effectue recemment?"
    )
    anneesDernierRachat: Optional[int] = Field(
        None, alias="anneesDernierRachat",
        description="Annees depuis le dernier rachat LPP"
    )
    avoirLppA50Ans: Optional[float] = Field(
        None, alias="avoirLppA50Ans",
        description="Avoir LPP a 50 ans (si connu, CHF)"
    )


class DetailFondsPropresMixResponse(BaseModel):
    """Breakdown of combined equity sources."""

    model_config = ConfigDict(populate_by_name=True)

    cash: float
    retrait3a: float = Field(..., alias="retrait3a")
    retraitLpp: float = Field(..., alias="retraitLpp")
    impot3a: float = Field(..., alias="impot3a")
    impotLpp: float = Field(..., alias="impotLpp")
    net3a: float = Field(..., alias="net3a")
    netLpp: float = Field(..., alias="netLpp")
    totalBrut: float = Field(..., alias="totalBrut")
    totalNet: float = Field(..., alias="totalNet")


class EplCombinedResponse(BaseModel):
    """Full response for combined EPL calculation."""

    model_config = ConfigDict(populate_by_name=True)

    # Total equity
    totalFondsPropres: float = Field(
        ..., alias="totalFondsPropres",
        description="Total fonds propres nets d'impots (CHF)"
    )

    # Detail
    detail: DetailFondsPropresMixResponse

    # Coverage
    prixCible: float = Field(..., alias="prixCible")
    pourcentagePrixCouvert: float = Field(
        ..., alias="pourcentagePrixCouvert",
        description="Pourcentage du prix couvert par les fonds propres"
    )

    # Optimal mix
    mixOptimal: List[str] = Field(
        ..., alias="mixOptimal",
        description="Recommandation d'ordre de mobilisation"
    )

    # Compliance
    premierEclairage: PremierEclairageResponse = Field(
        ..., alias="premierEclairage",
        description="Chiffre choc"
    )
    alertes: List[str] = Field(default_factory=list)
    sources: List[str] = Field(default_factory=list)
    disclaimer: str = Field(..., description="Avertissement legal")
