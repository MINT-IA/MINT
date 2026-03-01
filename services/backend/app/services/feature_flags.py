"""
Server-side feature flags (INV-10).
Source of truth for client feature toggles.
"""


class FeatureFlags:
    # P6: Couple+ tier in the paywall
    enable_couple_plus_tier: bool = True
