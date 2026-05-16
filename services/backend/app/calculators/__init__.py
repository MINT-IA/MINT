"""Phase mint-calc-engine-v1 Plan 05 — D-CE-11 calc registry.

AUTO-GENERATED registry. Do NOT edit ``_registry.py`` manually.

Regenerate :
    python3 tools/generate_calc_registry.py

Freshness check (exit 1 on drift) :
    python3 tools/generate_calc_registry.py --check
"""
from app.calculators._registry import (
    REGISTRY,
    REVERSE_DEP_MAP,
    CalculatorMetadata,
    get_calculator,
    get_reverse_deps,
)

__all__ = [
    "REGISTRY",
    "REVERSE_DEP_MAP",
    "CalculatorMetadata",
    "get_calculator",
    "get_reverse_deps",
]
