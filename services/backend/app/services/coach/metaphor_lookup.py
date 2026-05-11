"""Phase 96 D-18 — Python metaphor resolver, mirrors the Dart side.

Loads `services/backend/app/data/metaphors.toml` at module import.
Mobile + backend parity is enforced by `tools/checks/metaphor_parity.py`
(byte-equal sha256, plus LSFin + PII scan of every metaphor value).

Read-only post-import — no mutation API, no async loader. The narrator
prompt-injection path (Plan 96-02 `_render_source_card_block` extension
in Plan 96-03+) imports this module once and reuses ``lookup()`` per
turn.
"""
from __future__ import annotations

from pathlib import Path

try:
    import tomllib  # Python 3.11+
except ModuleNotFoundError:  # pragma: no cover — runtime is 3.12 (Railway)
    import tomli as tomllib  # type: ignore[no-redef,import-not-found]


# ``__file__`` = services/backend/app/services/coach/metaphor_lookup.py
# parents : [coach, services, app, backend, services-dir-or-root, …]
# We want services/backend/app/data/metaphors.toml — 3 levels up from
# ``coach/``.
_DATA_PATH = (
    Path(__file__).resolve().parent.parent.parent / "data" / "metaphors.toml"
)


def _load_metaphors() -> dict:
    try:
        with _DATA_PATH.open("rb") as fp:
            return tomllib.load(fp)
    except FileNotFoundError:
        # Defensive : in environments without the data file (e.g. early
        # test scaffolding), fall back to an empty map so lookups return
        # the empty-string contract. The parity lint is the canonical
        # supply-chain guard.
        return {}


_METAPHORS: dict = _load_metaphors()


def lookup(archetype: str, canton: str, life_event: str) -> str:
    """Return the metaphor string for the triplet, or "" on miss.

    Mirror of ``apps/mobile/lib/services/metaphor_lookup.dart#lookup``.
    """
    arch = _METAPHORS.get(archetype)
    if not isinstance(arch, dict):
        return ""
    cant = arch.get(canton)
    if not isinstance(cant, dict):
        return ""
    evt = cant.get(life_event)
    if not isinstance(evt, dict):
        return ""
    m = evt.get("metaphor", "")
    return m if isinstance(m, str) else ""
