"""
Job Change / LPP Plan Comparator Service.

Compares two employment situations focusing on the 'invisible salary' (LPP).
Swiss workers change jobs 5-7 times in their career. They compare gross salary
and forget the LPP plan -- which can be worth 10-30% of salary in real value.

Sources:
    - LPP art. 7-8 (salaire coordonne, deduction de coordination)
    - LPP art. 15-16 (cotisations, taux selon age)
    - LPP art. 14 al. 2 (taux de conversion 6.8%)
    - OPP2 art. 1 (seuil d'entree, salaire coordonne maximum)
"""

from dataclasses import dataclass, field
from typing import Optional, List


@dataclass
class LPPPlanData:
    """Data from an LPP pension fund plan."""
    salaire_brut: float                     # Gross annual salary
    salaire_assure: Optional[float] = None  # Insured salary (if known)
    deduction_coordination: float = 25725.0 # Default: fixed coordination deduction
    deduction_coordination_type: str = "fixed"  # "fixed" or "proportional"

    # Contributions
    taux_cotisation_employe: float = 0.0    # Employee contribution rate (%)
    taux_cotisation_employeur: float = 0.0  # Employer contribution rate (%)
    part_employeur_pct: float = 50.0        # Employer share (min 50%, can be 60-65%)

    # Capital & conversion
    avoir_vieillesse: float = 0.0           # Current old-age savings
    taux_conversion_obligatoire: float = 6.8  # Mandatory conversion rate (%)
    taux_conversion_surobligatoire: Optional[float] = None  # Super-mandatory rate
    taux_conversion_enveloppe: Optional[float] = None  # Envelope rate (if applicable)

    # Risk coverage
    rente_invalidite_pct: float = 0.0       # Disability pension as % of insured salary
    capital_deces: float = 0.0              # Death capital

    # Buyback
    rachat_maximum: float = 0.0             # Maximum buyback amount

    # Other benefits
    has_ijm: bool = True                    # Collective daily sickness benefit
    ijm_taux: float = 80.0                 # IJM rate (typically 80%)
    ijm_duree_jours: int = 720             # IJM duration (typically 720 days)


@dataclass
class JobComparisonResult:
    """Result of comparing two jobs/LPP plans."""

    # Net salary comparison
    salaire_net_actuel: float
    salaire_net_nouveau: float
    delta_salaire_net: float

    # LPP contribution comparison
    cotisation_employe_actuel: float
    cotisation_employe_nouveau: float
    delta_cotisation: float

    # Projected retirement capital (at age 65)
    capital_retraite_actuel: float
    capital_retraite_nouveau: float
    delta_capital: float

    # Monthly pension comparison
    rente_mensuelle_actuel: float
    rente_mensuelle_nouveau: float
    delta_rente: float

    # Risk coverage
    couverture_deces_actuel: float
    couverture_deces_nouveau: float
    delta_deces: float

    couverture_invalidite_actuel: float
    couverture_invalidite_nouveau: float
    delta_invalidite: float

    # Buyback potential
    rachat_max_actuel: float
    rachat_max_nouveau: float
    delta_rachat: float

    # IJM coverage
    has_ijm_actuel: bool
    has_ijm_nouveau: bool

    # Overall assessment
    verdict: str              # "actuel_meilleur", "nouveau_meilleur", "comparable"
    verdict_details: str      # Human-readable explanation
    annual_pension_delta: float  # Annual pension difference (key metric)
    lifetime_pension_delta: float  # Over 20 years of retirement

    # Alerts
    alerts: list = field(default_factory=list)  # Warning messages

    # Checklist items
    checklist: list = field(default_factory=list)  # Action items


class JobComparator:
    """Compare two employment situations focusing on the 'invisible salary' (LPP).

    The core insight: a higher gross salary with a worse LPP plan
    can cost hundreds of thousands of CHF over a career.
    """

    RETIREMENT_AGE = 65
    RETIREMENT_DURATION_YEARS = 20  # Average life expectancy post-retirement

    # Age-based LPP contribution rates (BVG minimum, LPP art. 16)
    LPP_RATES = {
        (25, 34): 7.0,    # 3.5% employee + 3.5% employer (minimum)
        (35, 44): 10.0,
        (45, 54): 15.0,
        (55, 64): 18.0,
    }

    # Coordination deduction (2024/2025 values, OPP2 art. 1)
    COORDINATION_DEDUCTION = 25725.0
    ENTRY_THRESHOLD = 22050.0
    MAX_INSURED_SALARY = 88200.0

    # Conservative projected return for capital projection
    PROJECTED_ANNUAL_RETURN = 0.015  # 1.5%

    # Minimum insured salary (LPP art. 8 al. 2)
    MIN_INSURED_SALARY = 3675.0

    # Social charges employee share (AVS 5.3% + AI 0.7% + AC 1.1% = ~6.4%)
    # These are deducted from gross to get net salary.
    SOCIAL_CHARGES_EMPLOYEE_PCT = 6.4

    def compare(
        self,
        current: LPPPlanData,
        new: LPPPlanData,
        age: int,
        years_to_retirement: Optional[int] = None,
    ) -> JobComparisonResult:
        """Compare current job vs new job opportunity.

        Args:
            current: Current job's LPP plan data.
            new: New job offer's LPP plan data.
            age: Worker's current age.
            years_to_retirement: Override for years until retirement (default: 65 - age).

        Returns:
            JobComparisonResult with full comparison on 7 axes.
        """
        if years_to_retirement is None:
            years_to_retirement = max(0, self.RETIREMENT_AGE - age)

        # 1. Calculate insured salaries
        sal_assure_current = self._calc_insured_salary(current)
        sal_assure_new = self._calc_insured_salary(new)

        # 2. Calculate contributions
        cotis_current = self._calc_contributions(current, sal_assure_current, age)
        cotis_new = self._calc_contributions(new, sal_assure_new, age)

        # 3. Net salary (gross - social charges - LPP employee contribution)
        # Social charges: AVS 5.3% + AI 0.7% + AC 1.1% = 6.4% employee share
        social_current = current.salaire_brut * self.SOCIAL_CHARGES_EMPLOYEE_PCT / 100
        social_new = new.salaire_brut * self.SOCIAL_CHARGES_EMPLOYEE_PCT / 100
        net_current = current.salaire_brut - social_current - cotis_current["employee_annual"]
        net_new = new.salaire_brut - social_new - cotis_new["employee_annual"]

        # 4. Project retirement capital
        capital_current = self._project_capital(
            current.avoir_vieillesse,
            cotis_current["total_annual"],
            years_to_retirement,
        )
        capital_new = self._project_capital(
            current.avoir_vieillesse,  # Same starting point
            cotis_new["total_annual"],
            years_to_retirement,
        )

        # 5. Calculate monthly pension
        taux_current = self._effective_conversion_rate(current)
        taux_new = self._effective_conversion_rate(new)
        rente_annual_current = capital_current * taux_current / 100
        rente_annual_new = capital_new * taux_new / 100

        # 6. Risk coverage
        invalidite_current = sal_assure_current * current.rente_invalidite_pct / 100
        invalidite_new = sal_assure_new * new.rente_invalidite_pct / 100

        # 7. Build alerts
        alerts = self._generate_alerts(
            current, new, age,
            net_current, net_new,
            rente_annual_current, rente_annual_new,
            invalidite_current, invalidite_new,
        )

        # 8. Build checklist
        checklist = self._generate_checklist(current, new)

        # 9. Determine verdict
        annual_pension_delta = rente_annual_new - rente_annual_current
        lifetime_pension_delta = annual_pension_delta * self.RETIREMENT_DURATION_YEARS

        # Verdict logic
        salary_gain = net_new - net_current
        pension_loss = annual_pension_delta  # negative = loss

        if salary_gain > 0 and pension_loss >= 0:
            verdict = "nouveau_meilleur"
            verdict_details = (
                f"Le nouveau poste est meilleur sur tous les axes : "
                f"+{salary_gain:.0f} CHF/an de salaire net et "
                f"+{annual_pension_delta:.0f} CHF/an de rente."
            )
        elif salary_gain > 0 and pension_loss < 0:
            # Key insight: is the salary gain worth the pension loss?
            if abs(lifetime_pension_delta) > salary_gain * 5:
                verdict = "actuel_meilleur"
                verdict_details = (
                    f"Le nouveau salaire est +{salary_gain:.0f} CHF/an, "
                    f"mais la perte de rente est de {abs(annual_pension_delta):.0f} CHF/an, "
                    f"soit {abs(lifetime_pension_delta):.0f} CHF sur 20 ans de retraite."
                )
            else:
                verdict = "comparable"
                verdict_details = (
                    f"Gain salarial de +{salary_gain:.0f} CHF/an, "
                    f"mais perte de rente de {abs(annual_pension_delta):.0f} CHF/an. "
                    f"A evaluer selon tes priorites."
                )
        elif salary_gain <= 0 and pension_loss > 0:
            verdict = "comparable"
            verdict_details = (
                f"Le salaire baisse de {abs(salary_gain):.0f} CHF/an, "
                f"mais la rente augmente de {annual_pension_delta:.0f} CHF/an."
            )
        else:
            verdict = "actuel_meilleur"
            verdict_details = (
                f"Le nouveau poste est moins favorable : "
                f"salaire {salary_gain:.0f} CHF/an et rente {annual_pension_delta:.0f} CHF/an."
            )

        return JobComparisonResult(
            salaire_net_actuel=round(net_current, 2),
            salaire_net_nouveau=round(net_new, 2),
            delta_salaire_net=round(net_new - net_current, 2),
            cotisation_employe_actuel=round(cotis_current["employee_annual"], 2),
            cotisation_employe_nouveau=round(cotis_new["employee_annual"], 2),
            delta_cotisation=round(
                cotis_new["employee_annual"] - cotis_current["employee_annual"], 2
            ),
            capital_retraite_actuel=round(capital_current, 2),
            capital_retraite_nouveau=round(capital_new, 2),
            delta_capital=round(capital_new - capital_current, 2),
            rente_mensuelle_actuel=round(rente_annual_current / 12, 2),
            rente_mensuelle_nouveau=round(rente_annual_new / 12, 2),
            delta_rente=round((rente_annual_new - rente_annual_current) / 12, 2),
            couverture_deces_actuel=current.capital_deces,
            couverture_deces_nouveau=new.capital_deces,
            delta_deces=new.capital_deces - current.capital_deces,
            couverture_invalidite_actuel=round(invalidite_current, 2),
            couverture_invalidite_nouveau=round(invalidite_new, 2),
            delta_invalidite=round(invalidite_new - invalidite_current, 2),
            rachat_max_actuel=current.rachat_maximum,
            rachat_max_nouveau=new.rachat_maximum,
            delta_rachat=new.rachat_maximum - current.rachat_maximum,
            has_ijm_actuel=current.has_ijm,
            has_ijm_nouveau=new.has_ijm,
            verdict=verdict,
            verdict_details=verdict_details,
            annual_pension_delta=round(annual_pension_delta, 2),
            lifetime_pension_delta=round(lifetime_pension_delta, 2),
            alerts=alerts,
            checklist=checklist,
        )

    def _calc_insured_salary(self, plan: LPPPlanData) -> float:
        """Compute insured salary from gross salary and coordination deduction.

        LPP art. 7-8: The insured salary is the gross salary minus the
        coordination deduction, bounded by the minimum insured salary
        and the maximum insured salary.

        Fixed deduction: gross - 25'725 (standard for full-time employees).
        Proportional deduction: gross - (gross * proportion), used for part-time.

        If the plan specifies salaire_assure directly, use that.

        Returns:
            Insured salary in CHF, or 0 if below entry threshold.
        """
        # If insured salary is explicitly specified, use it
        if plan.salaire_assure is not None:
            return max(0.0, plan.salaire_assure)

        # Below entry threshold: no LPP coverage
        if plan.salaire_brut < self.ENTRY_THRESHOLD:
            return 0.0

        # Calculate coordination deduction
        if plan.deduction_coordination_type == "proportional":
            # Proportional: deduction scales with salary (common for part-time)
            # Typically proportional to activity rate, approximated as ratio
            deduction = plan.salaire_brut * (plan.deduction_coordination / self.COORDINATION_DEDUCTION)
            if deduction > plan.deduction_coordination:
                deduction = plan.deduction_coordination
        else:
            # Fixed: standard coordination deduction
            deduction = plan.deduction_coordination

        insured = plan.salaire_brut - deduction

        # Apply minimum insured salary (LPP art. 8 al. 2)
        insured = max(insured, self.MIN_INSURED_SALARY)

        # Cap at maximum insured salary
        max_insured = self.MAX_INSURED_SALARY - deduction
        if max_insured > 0:
            insured = min(insured, max_insured)

        return max(0.0, round(insured, 2))

    def _calc_contributions(
        self, plan: LPPPlanData, insured_salary: float, age: int
    ) -> dict:
        """Calculate employee and employer annual contributions.

        If the plan specifies explicit contribution rates (taux_cotisation_employe,
        taux_cotisation_employeur), use those. Otherwise, use the BVG minimum
        rates based on age bracket, split according to part_employeur_pct.

        Args:
            plan: LPP plan data.
            insured_salary: Computed insured salary.
            age: Worker's current age.

        Returns:
            dict with employee_annual, employer_annual, total_annual.
        """
        if insured_salary <= 0:
            return {
                "employee_annual": 0.0,
                "employer_annual": 0.0,
                "total_annual": 0.0,
            }

        # If explicit rates are provided, use them
        if plan.taux_cotisation_employe > 0 or plan.taux_cotisation_employeur > 0:
            employee_annual = insured_salary * plan.taux_cotisation_employe / 100
            employer_annual = insured_salary * plan.taux_cotisation_employeur / 100
        else:
            # Use BVG minimum rates based on age bracket
            total_rate = self._get_lpp_rate_for_age(age)
            total_annual = insured_salary * total_rate / 100

            # Split according to employer share (min 50%)
            employer_pct = max(50.0, plan.part_employeur_pct) / 100
            employer_annual = total_annual * employer_pct
            employee_annual = total_annual * (1 - employer_pct)

        return {
            "employee_annual": round(employee_annual, 2),
            "employer_annual": round(employer_annual, 2),
            "total_annual": round(employee_annual + employer_annual, 2),
        }

    def _get_lpp_rate_for_age(self, age: int) -> float:
        """Get the BVG minimum total contribution rate for a given age.

        LPP art. 16: contribution rates increase with age.

        Args:
            age: Worker's current age.

        Returns:
            Total contribution rate as percentage (e.g. 7.0 for 7%).
        """
        for (min_age, max_age), rate in self.LPP_RATES.items():
            if min_age <= age <= max_age:
                return rate
        # Below 25 or above 64: return 0 (not covered by BVG mandatory)
        if age < 25:
            return 0.0
        # 65+: use the last bracket
        return 18.0

    def _project_capital(
        self,
        current_capital: float,
        annual_contribution: float,
        years: int,
    ) -> float:
        """Project retirement capital with compound interest.

        Uses a conservative 1.5% annual return (LPP minimum interest rate
        has historically been 1-1.25%, but funds typically return slightly more).

        Args:
            current_capital: Current old-age savings (avoir de vieillesse).
            annual_contribution: Total annual contribution (employee + employer).
            years: Number of years to project.

        Returns:
            Projected capital at retirement in CHF.
        """
        if years <= 0:
            return current_capital

        r = self.PROJECTED_ANNUAL_RETURN
        capital = current_capital

        for _ in range(years):
            capital = capital * (1 + r) + annual_contribution

        return round(capital, 2)

    def _effective_conversion_rate(self, plan: LPPPlanData) -> float:
        """Determine the effective conversion rate.

        If an envelope rate is specified (taux_conversion_enveloppe), use it.
        Otherwise, use the mandatory rate (6.8% LPP minimum).
        If a surobligatory rate is specified, use a weighted average
        (simplified: we use the envelope or mandatory rate).

        In practice, most Swiss pension funds apply an "envelope" rate
        to the total capital, which is lower than the 6.8% mandatory rate.

        Args:
            plan: LPP plan data.

        Returns:
            Effective conversion rate as percentage (e.g. 6.8 for 6.8%).
        """
        if plan.taux_conversion_enveloppe is not None:
            return plan.taux_conversion_enveloppe

        if plan.taux_conversion_surobligatoire is not None:
            # Simplified: average of mandatory and surobligatory
            # In reality, this depends on the split of capital
            return (plan.taux_conversion_obligatoire + plan.taux_conversion_surobligatoire) / 2

        return plan.taux_conversion_obligatoire

    def _generate_alerts(
        self,
        current: LPPPlanData,
        new: LPPPlanData,
        age: int,
        net_current: float,
        net_new: float,
        rente_current: float,
        rente_new: float,
        invalidite_current: float,
        invalidite_new: float,
    ) -> List[str]:
        """Generate warning messages for critical changes between plans.

        Alerts are in French, matching the app's primary language.

        Returns:
            List of alert strings.
        """
        alerts: List[str] = []

        # IJM loss alert
        if current.has_ijm and not new.has_ijm:
            alerts.append(
                "CRITIQUE: Le nouveau poste n'a pas d'IJM collective. "
                "En cas de maladie longue, vous n'aurez aucune couverture "
                "apres la periode employeur (CO art. 324a)."
            )

        # Pension drop > salary gain
        salary_gain = net_new - net_current
        pension_drop = rente_current - rente_new
        if pension_drop > 0 and salary_gain > 0:
            lifetime_loss = pension_drop * self.RETIREMENT_DURATION_YEARS
            if lifetime_loss > salary_gain * 5:
                alerts.append(
                    f"ATTENTION: La perte de rente ({pension_drop:.0f} CHF/an) "
                    f"represente {lifetime_loss:.0f} CHF sur 20 ans de retraite, "
                    f"soit plus de 5x le gain salarial annuel."
                )

        # Lower conversion rate
        taux_current = self._effective_conversion_rate(current)
        taux_new = self._effective_conversion_rate(new)
        if taux_new < taux_current:
            alerts.append(
                f"Le taux de conversion baisse de {taux_current:.1f}% a {taux_new:.1f}%. "
                f"A capital egal, votre rente sera plus basse."
            )

        # Disability coverage drop
        if invalidite_new < invalidite_current and invalidite_current > 0:
            drop_pct = (invalidite_current - invalidite_new) / invalidite_current * 100
            if drop_pct > 10:
                alerts.append(
                    f"La couverture invalidite baisse de {drop_pct:.0f}% "
                    f"({invalidite_current:.0f} -> {invalidite_new:.0f} CHF/an)."
                )

        # Death capital drop
        if new.capital_deces < current.capital_deces and current.capital_deces > 0:
            alerts.append(
                f"Le capital deces baisse de {current.capital_deces:.0f} "
                f"a {new.capital_deces:.0f} CHF."
            )

        # Below entry threshold
        if new.salaire_brut < self.ENTRY_THRESHOLD:
            alerts.append(
                f"CRITIQUE: Le nouveau salaire ({new.salaire_brut:.0f} CHF) "
                f"est sous le seuil d'entree LPP ({self.ENTRY_THRESHOLD:.0f} CHF). "
                f"Aucune couverture 2e pilier."
            )

        # Employer share below average
        if new.part_employeur_pct < current.part_employeur_pct:
            alerts.append(
                f"La part employeur LPP baisse de {current.part_employeur_pct:.0f}% "
                f"a {new.part_employeur_pct:.0f}%."
            )

        # Near retirement: short projection makes differences less impactful
        years_to_retirement = max(0, self.RETIREMENT_AGE - age)
        if years_to_retirement <= 5 and years_to_retirement > 0:
            alerts.append(
                f"A {years_to_retirement} ans de la retraite, "
                f"la projection est limitee. Verifiez le certificat de prevoyance."
            )

        # IJM duration difference
        if new.has_ijm and current.has_ijm and new.ijm_duree_jours < current.ijm_duree_jours:
            alerts.append(
                f"La duree IJM baisse de {current.ijm_duree_jours} "
                f"a {new.ijm_duree_jours} jours."
            )

        return alerts

    def _generate_checklist(
        self, current: LPPPlanData, new: LPPPlanData
    ) -> List[str]:
        """Generate the 'before you sign' checklist items.

        Returns:
            List of checklist strings.
        """
        checklist: List[str] = []

        # Always ask for the certificate
        checklist.append(
            "Demander le certificat de prevoyance (certificat LPP) du nouvel employeur."
        )

        # Check conversion rate
        checklist.append(
            "Verifier le taux de conversion (obligatoire et surobligatoire)."
        )

        # Check employer share
        checklist.append(
            "Verifier la part employeur (minimum legal 50%, certains paient 60-65%)."
        )

        # Check IJM
        if current.has_ijm:
            checklist.append(
                "Confirmer la presence d'une IJM collective (assurance perte de gain maladie)."
            )

        # Check buyback potential
        checklist.append(
            "Demander le montant de rachat maximum possible dans la nouvelle caisse."
        )

        # Check disability coverage
        checklist.append(
            "Verifier les prestations invalidite (rente et exoneration de cotisations)."
        )

        # Check death capital
        checklist.append(
            "Verifier le capital deces et les beneficiaires."
        )

        # Libre passage: transfer the capital
        checklist.append(
            "Organiser le transfert du libre passage vers la nouvelle caisse de pension."
        )

        # Check coordination deduction type
        checklist.append(
            "Verifier le type de deduction de coordination (fixe vs proportionnelle)."
        )

        # If different IJM
        if current.has_ijm and not new.has_ijm:
            checklist.append(
                "URGENT: Souscrire une IJM individuelle si le nouvel employeur n'en a pas."
            )

        # If near max insured salary
        if new.salaire_brut > self.MAX_INSURED_SALARY:
            checklist.append(
                "Verifier si le plan surobligatoire couvre le salaire au-dela du maximum LPP."
            )

        return checklist
