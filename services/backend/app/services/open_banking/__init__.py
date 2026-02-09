"""
Open Banking module for MINT (Sprint S14).

bLink/SFTI connector infrastructure — feature-gated until FINMA consultation completes.
All operations are read-only. No write/transfer/payment functionality.

Components:
    - BLinkConnector: bLink API abstraction (sandbox mode)
    - TransactionCategorizer: Swiss-specific auto-categorization
    - ConsentManager: nLPD-compliant consent management
    - AccountAggregator: Multi-bank account aggregation
"""

from app.services.open_banking.blink_connector import BLinkConnector
from app.services.open_banking.transaction_categorizer import TransactionCategorizer
from app.services.open_banking.consent_manager import ConsentManager
from app.services.open_banking.account_aggregator import AccountAggregator

__all__ = [
    "BLinkConnector",
    "TransactionCategorizer",
    "ConsentManager",
    "AccountAggregator",
]
