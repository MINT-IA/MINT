"""
Scenario Narration + Annual Refresh — Sprint S37.

Provides:
    - ScenarioNarratorService: narrates 3 retirement projections as educational text
    - AnnualRefreshService: detects stale profiles and generates refresh questions

Sources:
    - LSFin art. 3 (information financiere)
    - LPP art. 14-16 (prevoyance professionnelle)
    - LAVS art. 21-40 (AVS)
"""

from app.services.scenario.scenario_models import (
    ScenarioInput,
    NarratedScenario,
    ScenarioNarrationResult,
    RefreshQuestion,
    AnnualRefreshResult,
)
from app.services.scenario.scenario_narrator_service import ScenarioNarratorService
from app.services.scenario.annual_refresh_service import AnnualRefreshService

__all__ = [
    "ScenarioInput",
    "NarratedScenario",
    "ScenarioNarrationResult",
    "RefreshQuestion",
    "AnnualRefreshResult",
    "ScenarioNarratorService",
    "AnnualRefreshService",
]
