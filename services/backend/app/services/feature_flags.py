"""
Server-side feature flags (INV-10).
Source of truth for client feature toggles.
"""

import os
from typing import Dict

from fastapi import HTTPException, status


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

    # P7: Expert tier (human specialist marketplace, off by default)
    enable_expert_tier: bool = False

    # Admin screens: observability, analytics (off by default)
    enable_admin_screens: bool = False

    # Diagnostic onboarding wedge (off by default until rollout)
    enable_mvp_wedge_onboarding: bool = False

    # Phase 02 Plan 02-03 PR-1 (D-05) — dual-write SnapshotModel -> fact_event.
    # OFF in dev/staging/prod by default ; flipped ON on staging only during
    # the PR-3a backfill + soak window ; removed entirely in PR-4 decommission.
    # Helper : is_fact_event_dual_write_enabled() module-level for the
    # snapshot_service writer (Karpathy #3 — match existing
    # os.environ.get('FF_FACT_CURRENT_READ', ...) pattern from Plan 02-02
    # rather than introducing a third resolution shape).
    fact_event_dual_write: bool = False

    @classmethod
    def require_flag(cls, flag_name: str) -> None:
        """Raise HTTP 403 if the given feature flag is disabled.

        Usage in endpoints:
            FeatureFlags.require_flag("enable_blink_production")
        """
        flags = cls.get_flags()
        if not flags.get(flag_name, False):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Feature '{flag_name}' is not enabled",
            )

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
            "enable_expert_tier": _env_bool(
                "FF_ENABLE_EXPERT_TIER", cls.enable_expert_tier
            ),
            "enable_admin_screens": _env_bool(
                "FF_ENABLE_ADMIN_SCREENS", cls.enable_admin_screens
            ),
            "enable_mvp_wedge_onboarding": _env_bool(
                "FF_ENABLE_MVP_WEDGE_ONBOARDING",
                cls.enable_mvp_wedge_onboarding,
            ),
            "fact_event_dual_write": _env_bool(
                "FF_FACT_EVENT_DUAL_WRITE", cls.fact_event_dual_write
            ),
        }


def is_fact_event_dual_write_enabled() -> bool:
    """Module-level helper for the snapshot_service writer (Plan 02-03 PR-1, D-05).

    Reads the FF_FACT_EVENT_DUAL_WRITE env var (truthy values : '1', 'true',
    'yes'). Default False — dev/staging/prod all start with dual-write OFF.

    Matches the existing Plan 02-02 module-level pattern :
    `read_monthly_gross_income(...)` in snapshot_service.py uses the same
    `os.environ.get('FF_FACT_CURRENT_READ', '').lower()` shape. Keeping the
    same shape avoids introducing a third feature-flag resolution path
    (Karpathy #3 — surgical changes ; one pattern, one env-var prefix).

    PR-1 lands the helper + default-OFF behaviour.
    PR-2 wires the helper into snapshot_service.create_snapshot() under a
    feature-flag-gated dual-write branch.
    PR-4 removes the helper + the writer branch (post-cutover decommission).
    """
    val = os.environ.get("FF_FACT_EVENT_DUAL_WRITE", "").lower()
    return val in ("1", "true", "yes")
