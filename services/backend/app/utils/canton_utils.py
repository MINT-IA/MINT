"""
Canton validation utility.

Provides a single, reusable canton validation helper for all backend services.
Ensures consistent handling of null/invalid canton codes across the codebase.

Source: Swiss Federal Constitution, 26 cantons.
"""

from typing import Optional, Tuple

VALID_CANTONS = {
    "ZH", "BE", "LU", "UR", "SZ", "OW", "NW", "GL",
    "ZG", "FR", "SO", "BS", "BL", "SH", "AR", "AI",
    "SG", "GR", "AG", "TG", "TI", "VD", "VS", "NE",
    "GE", "JU",
}


def validate_canton(
    canton: Optional[str], default: str = "ZH"
) -> Tuple[str, Optional[str]]:
    """Validate and normalize a canton code.

    Returns:
        Tuple of (validated_canton, warning_or_none).
        If canton is valid, warning is None.
        If canton is None or invalid, default is used and a warning is returned.
    """
    if not canton or canton.upper().strip() not in VALID_CANTONS:
        warning = (
            f"Canton '{canton}' non reconnu \u2014 {default} utilis\u00e9 par d\u00e9faut."
            if canton
            else f"Canton non sp\u00e9cifi\u00e9 \u2014 {default} utilis\u00e9 par d\u00e9faut."
        )
        return default, warning
    return canton.upper().strip(), None
