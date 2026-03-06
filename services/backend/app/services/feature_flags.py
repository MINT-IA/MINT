"""
Server-side feature flags (INV-10).
Source of truth for client feature toggles.
"""

import os
from typing import Dict


def _env_bool(key: str, default: bool) -> bool:
    """Read a boolean from an environment variable with a safe default."""
    val = os.environ.get(key, "").lower()
    if val in ("1", "true", "yes"):
        return True
    if val in ("0", "false", "no"):
        return False
    return default


class FeatureFlags:
    # P6: Couple+ tier in the paywall
    enable_couple_plus_tier: bool = True

    # P3: SLM narratives enabled by default for TestFlight/internal builds
    enable_slm_narratives: bool = True

    # P4.5: Decision scaffold enabled by default
    enable_decision_scaffold: bool = True

    # P2: housing model reform toggle (off by default)
    valeur_locative_2028_reform: bool = False

    # P7: degraded safe-mode fallback (off by default)
    safe_mode_degraded: bool = False

    # P7: external API connectors (off by default until FINMA consultation)
    enable_blink_production: bool = False
    enable_caisse_pension_api: bool = False
    enable_avs_institutional: bool = False

    @classmethod
    def get_flags(cls) -> Dict[str, bool]:
        """Resolve current flag values from env vars."""
        return {
            "enable_couple_plus_tier": _env_bool(
                "FF_ENABLE_COUPLE_PLUS_TIER", cls.enable_couple_plus_tier
            ),
            "enable_slm_narratives": _env_bool(
                "FF_ENABLE_SLM_NARRATIVES", cls.enable_slm_narratives
            ),
            "enable_decision_scaffold": _env_bool(
                "FF_ENABLE_DECISION_SCAFFOLD", cls.enable_decision_scaffold
            ),
            "valeur_locative_2028_reform": _env_bool(
                "FF_VALEUR_LOCATIVE_2028_REFORM", cls.valeur_locative_2028_reform
            ),
            "safe_mode_degraded": _env_bool(
                "FF_SAFE_MODE_DEGRADED", cls.safe_mode_degraded
            ),
            "enable_blink_production": _env_bool(
                "FF_ENABLE_BLINK_PRODUCTION", cls.enable_blink_production
            ),
            "enable_caisse_pension_api": _env_bool(
                "FF_ENABLE_CAISSE_PENSION_API", cls.enable_caisse_pension_api
            ),
            "enable_avs_institutional": _env_bool(
                "FF_ENABLE_AVS_INSTITUTIONAL", cls.enable_avs_institutional
            ),
        }
