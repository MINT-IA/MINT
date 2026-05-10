"""BundleBase — Pydantic v2 frozen + extra=forbid.

Phase 93.5 Wave 0 (Plan 93.5-01). Pattern source : extractor_schema.py:103
(`{"extra": "forbid", "frozen": True}`) — Phase 91 precedent.

CONTEXT decisions encoded :
- D-05/D-06 : pure Python module per bundle, exposing a Pydantic v2
  `BaseModel` with frozen config (rejects YAML+Markdown / hybrid formats).
- D-07 : no sibling `.md` files — half-measure that pays both costs.
- D-08 : shared base class enforces the contract with frozen=True +
  extra="forbid".

Threat T-93.5-01 mitigation : tests in
`tests/bundles/test_bundle_contract.py` (`test_all_bundles_are_frozen`,
`test_all_bundles_forbid_extra`) verify the config is honored at every
subclass instantiation.
"""
from __future__ import annotations

from pydantic import BaseModel, ConfigDict


class BundleBase(BaseModel):
    """Base class for all 6 skill bundles (Phase 93.5).

    Subclasses MUST declare `name`, `prompt_fragment`, `allowed_tools`,
    `citation_allowlist`. The shared `model_config` enforces immutability
    (`frozen=True`) and rejects unknown fields (`extra="forbid"`).

    The compiler (Plan 93.5-02) consumes a list of `BundleBase` instances
    and emits one composed prompt + union'd tool allowlist + union'd
    citation allowlist per request.
    """

    model_config = ConfigDict(frozen=True, extra="forbid")

    name: str
    prompt_fragment: str
    allowed_tools: list[str]
    citation_allowlist: list[str]


__all__ = ["BundleBase"]
