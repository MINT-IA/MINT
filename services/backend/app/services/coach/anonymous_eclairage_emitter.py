"""
Phase 81 — Deterministic Premier Éclairage emitter (anti phantom contract C2).

When the anonymous chat endpoint is called with:
    - `archetype` body field set to one of the 4 v2.10 slugs, AND
    - the coach turn is the 2nd anonymous message (i.e. session.message_count == 1
      pre-increment), AND
    - either `MINT_E2E_FORCE_ECLAIRAGE_KIND` env var OR the request body
      `forced_eclairage_kind` field pins the kind,

…this module returns a deterministic `EclairageSchema` payload. Otherwise the
orchestrator falls back to free-form LLM prose (status quo).

LSFin compliance (locked, ECLB-04):
    - Never absolute CHF — always conditional range (low + high).
    - LSFin disclaimer always present.
    - Banned-terms list expanded (3-piliers panel) — emitter aborts if any
      template renders a banned term.

Banned terms (Phase 81, panel-locked superset):
    Legacy V1: garanti / garantie / garantis / garantito / guaranteed / optimal /
    optimale / parfait / parfaite / certain (context-aware) / assuré / assurée /
    sans risque
    3-piliers expansion: idéal / idéale / il faut / vous économiserez /
    rentable / profiter de / opportunité / sûr (context-aware) / avantage fiscal seul

References:
    - .planning/REQUIREMENTS.md §ECLB-01..05
    - .planning/ROADMAP.md §Phase 81
"""

from __future__ import annotations

import os
import unicodedata
from typing import Optional

from app.schemas.anonymous_chat import (
    ArchetypeSlug,
    EclairageKind,
    EclairageSchema,
)


# ---------------------------------------------------------------------------
# Banned-terms (ECLB-04) — emitter-side enforcement
# ---------------------------------------------------------------------------

# Stored in normalized (NFC, lowercase) form. `_normalize` applies the same
# transform before substring search to avoid accent/case bypasses.
BANNED_TERMS_ECLAIRAGE: tuple[str, ...] = (
    # Legacy V1 (LSFin top-3)
    "garanti",
    "garantie",
    "garantis",
    "garanties",
    "garantito",
    "guaranteed",
    "optimal",
    "optimale",
    "optimaux",
    "optimales",
    "parfait",
    "parfaite",
    "parfaits",
    "parfaites",
    "assuré",
    "assurée",
    "assurés",
    "assurées",
    "sans risque",
    "meilleur",
    "meilleure",
    "meilleurs",
    "meilleures",
    # 3-piliers expansion (Phase 81 panel-locked)
    "idéal",
    "idéale",
    "idéaux",
    "idéales",
    "il faut",
    "vous économiserez",
    "tu économiseras",
    "rentable",
    "profiter de",
    "opportunité",
    "avantage fiscal seul",
)


def _normalize(text: str) -> str:
    """Lowercase + NFC-normalize a string for banned-term substring search."""
    return unicodedata.normalize("NFC", text).lower()


class BannedTermLeak(ValueError):
    """Raised when a deterministic eclairage template renders a banned term."""

    def __init__(self, term: str, field: str, content: str) -> None:
        self.term = term
        self.field = field
        super().__init__(
            f"banned term '{term}' detected in eclairage.{field}: {content!r}"
        )


def _assert_clean(value: str, field: str) -> None:
    """Assert ECLB-04 — no banned term in `value`. Raise BannedTermLeak otherwise."""
    haystack = _normalize(value)
    for term in BANNED_TERMS_ECLAIRAGE:
        if _normalize(term) in haystack:
            raise BannedTermLeak(term=term, field=field, content=value)


# ---------------------------------------------------------------------------
# Deterministic templates
# ---------------------------------------------------------------------------

# Templates are LSFin-compliant by construction: every CHF reference is a
# range (low+high), every payload carries the standard discovery disclaimer.
# Headlines ≤ 80, body ≤ 240, soft_account_hint ≤ 80 enforced by the
# `EclairageSchema` Pydantic validator.

_LSFIN_DISCLAIMER_FR = (
    "Information éducative uniquement. Ne constitue pas un conseil financier "
    "personnalisé (LSFin art. 3). Les montants dépendent de ta situation."
)


def _template_fiscal_margin_3a() -> EclairageSchema:
    """Deterministic template for `fiscal_margin_3a`.

    3-piliers panel verdict: default insight when archetype == julien_swiss
    or any archetype lacking an emitter pin.
    """
    payload = EclairageSchema(
        kind="fiscal_margin_3a",
        headline="Une marge fiscale 3a souvent invisible",
        body=(
            "Verser sur un 3a peut faire baisser ton revenu imposable cette "
            "année. Selon ton revenu et ton canton, l'économie d'impôt "
            "pourrait s'inscrire dans une fourchette annuelle conditionnelle."
        ),
        chf_range_low=600,
        chf_range_high=2_400,
        chf_range_period="year",
        soft_account_hint="Crée un compte pour estimer ta fourchette personnelle.",
        lsfin_disclaimer=_LSFIN_DISCLAIMER_FR,
    )
    _validate_payload(payload)
    return payload


def _template_lpp_rachat_3a_nantissement() -> EclairageSchema:
    """Deterministic template for `lpp_rachat_3a_nantissement`.

    Used by archetype `cadre_40_55_lpp_rachat` and explicit pin.
    """
    payload = EclairageSchema(
        kind="lpp_rachat_3a_nantissement",
        headline="Rachat LPP + 3a nantissement, l'angle mort",
        body=(
            "Un rachat LPP combiné à un 3a nanti pourrait, dans certains cas, "
            "changer la fenêtre fiscale d'une année donnée. L'impact dépend "
            "de ton 2e pilier, ton revenu et ton canton."
        ),
        chf_range_low=1_500,
        chf_range_high=12_000,
        chf_range_period="year",
        soft_account_hint="Ouvre un compte pour cadrer la fenêtre.",
        lsfin_disclaimer=_LSFIN_DISCLAIMER_FR,
    )
    _validate_payload(payload)
    return payload


_TEMPLATES = {
    "fiscal_margin_3a": _template_fiscal_margin_3a,
    "lpp_rachat_3a_nantissement": _template_lpp_rachat_3a_nantissement,
}


# ---------------------------------------------------------------------------
# Archetype → default kind mapping
# ---------------------------------------------------------------------------

# When the request carries an archetype but no explicit emitter pin (env or
# body), this map decides which deterministic kind to emit. v2.11 ships
# `fiscal_margin_3a` for 3 of 4 archetypes (3-piliers panel verdict —
# the « default insight » that surprises a new visitor) and the bespoke
# rachat-LPP template for the cadre_40_55 archetype.
_ARCHETYPE_DEFAULT_KIND: dict[ArchetypeSlug, EclairageKind] = {
    "julien_swiss": "fiscal_margin_3a",
    "couple_acheteurs_lausanne": "fiscal_margin_3a",
    "jeune_diplome_zurich": "fiscal_margin_3a",
    "cadre_40_55_lpp_rachat": "lpp_rachat_3a_nantissement",
}


# ---------------------------------------------------------------------------
# Public API — called by the anonymous_chat endpoint
# ---------------------------------------------------------------------------


def resolve_pinned_kind(
    forced_eclairage_kind_body: Optional[str],
) -> Optional[EclairageKind]:
    """Resolve the emitter pin from request body OR env var.

    Body field takes precedence over env (matches Flutter client semantics
    where dart-define and runtime override coexist). Returns None when neither
    is set OR when the value is not a recognized kind.
    """
    if forced_eclairage_kind_body and forced_eclairage_kind_body in _TEMPLATES:
        return forced_eclairage_kind_body  # type: ignore[return-value]
    env_value = os.environ.get("MINT_E2E_FORCE_ECLAIRAGE_KIND")
    if env_value and env_value in _TEMPLATES:
        return env_value  # type: ignore[return-value]
    return None


def should_emit(
    *,
    archetype: Optional[ArchetypeSlug],
    pre_increment_count: int,
    pinned_kind: Optional[EclairageKind],
) -> bool:
    """Phase 81 ECLB-03 gate.

    Emit deterministic payload only when:
        1. archetype is set (one of the 4 v2.10 slugs), AND
        2. the request is the 2nd anonymous message — `pre_increment_count == 1`
           (0-based: 0 = turn 1, 1 = turn 2), AND
        3. the emitter is pinned via env or body.
    """
    if archetype is None:
        return False
    if pre_increment_count != 1:
        return False
    if pinned_kind is None:
        return False
    return True


def build_payload(
    *,
    archetype: ArchetypeSlug,
    pinned_kind: Optional[EclairageKind] = None,
) -> EclairageSchema:
    """Build the deterministic eclairage payload.

    Resolution order for `kind`:
        1. explicit `pinned_kind` (env or body) if provided.
        2. archetype default from `_ARCHETYPE_DEFAULT_KIND`.

    LSFin enforcement (ECLB-04) is performed inside each template via
    `_validate_payload`. A banned-term leak raises `BannedTermLeak` which the
    endpoint promotes to a 500 (panel-locked: a leak is a server bug, not a
    client error).
    """
    if pinned_kind is not None:
        kind: EclairageKind = pinned_kind
    else:
        kind = _ARCHETYPE_DEFAULT_KIND[archetype]
    builder = _TEMPLATES[kind]
    return builder()


def _validate_payload(payload: EclairageSchema) -> None:
    """ECLB-04 enforcement — assert no banned term in any user-visible text."""
    _assert_clean(payload.headline, "headline")
    _assert_clean(payload.body, "body")
    _assert_clean(payload.soft_account_hint, "soft_account_hint")
    _assert_clean(payload.lsfin_disclaimer, "lsfin_disclaimer")
