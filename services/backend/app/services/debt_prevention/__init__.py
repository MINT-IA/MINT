"""
Debt Prevention module for MINT (Sprint S16).

Gap G6: "Prevention dette" — debt ratio assessment, repayment planning,
and links to professional help resources.

Components:
    - DebtRatioService: Calculate debt-to-income ratio and assess risk
    - RepaymentService: Plan debt repayment (avalanche vs snowball)
    - ResourcesService: Professional help resources by canton

Sources:
    - LP art. 93 (minimum vital insaisissable)
    - SchKG / LP (Loi sur la poursuite et faillite)
    - Dettes Conseils Suisse (organisation faitiere)
"""

from app.services.debt_prevention.debt_ratio_service import DebtRatioService
from app.services.debt_prevention.repayment_service import RepaymentService
from app.services.debt_prevention.resources_service import ResourcesService

__all__ = [
    "DebtRatioService",
    "RepaymentService",
    "ResourcesService",
]
