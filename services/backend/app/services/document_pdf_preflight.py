"""PDF preflight — route encrypted/scanned/digital/AcroForm before Vision.

v2.7 Phase 28 / DOC-08.

Branches:
    1. encrypted_needs_password → return early, prompt user for password
    2. acroform                 → extract via doc.get_form_text_fields(), Vision SKIPPED (cost=0)
    3. digital  (page_count<=4) → send full PDF to Claude Vision document block
    4. scanned OR page_count>4  → keyword-based page selection (top N pages)

Failure mode: if pymupdf is unavailable at runtime (e.g. CI without
the dep), preflight_pdf returns status="digital" with page_count=None
so the caller falls back to sending the full file to Vision (current
legacy behaviour).
"""
from __future__ import annotations

import logging
from typing import Any, Dict, List, Optional

logger = logging.getLogger(__name__)

# Financial keywords used to score pages when scanned/long PDFs need
# selection. Multilingual (fr/de/it) — we route to French first per
# canton config but the scoring is union of all languages so a German
# CPE certificate scanned by a Romand user still scores correctly.
_FINANCIAL_KEYWORDS = [
    # French
    "total", "avoir", "rente", "impôt", "impot",
    "salaire assuré", "salaire assure",
    "rachat", "bonification", "capital", "prévoyance", "prevoyance",
    # German
    "kapital", "lohn", "imposable", "altersguthaben",
    "umwandlungssatz", "einkauf", "vorsorge",
    # Italian
    "salario assicurato", "rendita", "imposta", "previdenza",
]


def preflight_pdf(pdf_bytes: bytes) -> Dict[str, Any]:
    """Inspect a PDF and return routing metadata.

    Returns dict with keys:
        status: "encrypted_needs_password" | "acroform" | "scanned" | "digital"
        page_count: int | None
        has_acroform: bool
        text_extractable: int (raw text length across all pages)
        acroform_fields: dict[str, str] (only when has_acroform)
    """
    try:
        import pymupdf  # type: ignore
    except ImportError:  # pragma: no cover — soft dep
        logger.warning("pymupdf not installed — preflight degraded")
        return {
            "status": "digital",
            "page_count": None,
            "has_acroform": False,
            "text_extractable": 0,
            "acroform_fields": {},
        }

    try:
        doc = pymupdf.open(stream=pdf_bytes, filetype="pdf")
    except Exception as exc:
        logger.warning("preflight_pdf: open failed err=%s", exc)
        return {
            "status": "digital",
            "page_count": None,
            "has_acroform": False,
            "text_extractable": 0,
            "acroform_fields": {},
        }

    if doc.is_encrypted:
        # Try empty password (some "encrypted" PDFs are unlocked-with-empty)
        try:
            unlocked = doc.authenticate("") != 0
        except Exception:
            unlocked = False
        if not unlocked:
            page_count = doc.page_count
            try:
                doc.close()
            except Exception:
                pass
            return {
                "status": "encrypted_needs_password",
                "page_count": page_count,
                "has_acroform": False,
                "text_extractable": 0,
                "acroform_fields": {},
            }

    raw_text_len = 0
    for page in doc:
        try:
            raw_text_len += len(page.get_text() or "")
        except Exception:
            continue

    acroform_fields: Dict[str, str] = {}
    try:
        if getattr(doc, "is_form_pdf", False):
            for page in doc:
                try:
                    widgets = page.widgets() or []
                except Exception:
                    widgets = []
                for w in widgets:
                    name = getattr(w, "field_name", None)
                    value = getattr(w, "field_value", None)
                    if name and value is not None and str(value) != "":
                        acroform_fields[str(name)] = str(value)
    except Exception:
        acroform_fields = {}

    has_acroform = bool(acroform_fields)
    page_count = doc.page_count

    if has_acroform:
        status = "acroform"
    elif raw_text_len < 50:
        status = "scanned"
    else:
        status = "digital"

    try:
        doc.close()
    except Exception:
        pass

    return {
        "status": status,
        "page_count": page_count,
        "has_acroform": has_acroform,
        "text_extractable": raw_text_len,
        "acroform_fields": acroform_fields,
    }


def select_pages_for_vision(
    pdf_bytes: bytes,
    max_pages: int = 3,
    keywords: Optional[List[str]] = None,
) -> List[int]:
    """Return page indices (0-based) most likely to contain financial data.

    Strategy: per-page keyword hit count, return top `max_pages` indices.
    If pymupdf unavailable or fewer pages than max → return [0..page_count-1].
    """
    kw = [k.lower() for k in (keywords or _FINANCIAL_KEYWORDS)]
    try:
        import pymupdf  # type: ignore
    except ImportError:  # pragma: no cover
        return list(range(max_pages))

    try:
        doc = pymupdf.open(stream=pdf_bytes, filetype="pdf")
    except Exception:
        return list(range(max_pages))

    page_count = doc.page_count
    if page_count <= max_pages:
        try:
            doc.close()
        except Exception:
            pass
        return list(range(page_count))

    scored: List[tuple[int, int]] = []
    for idx, page in enumerate(doc):
        try:
            text = (page.get_text() or "").lower()
        except Exception:
            text = ""
        score = sum(text.count(k) for k in kw)
        scored.append((idx, score))

    try:
        doc.close()
    except Exception:
        pass

    # Sort by score desc, then by page index asc (stable for ties)
    scored.sort(key=lambda t: (-t[1], t[0]))
    chosen = sorted(idx for idx, _ in scored[:max_pages])
    return chosen


__all__ = ["preflight_pdf", "select_pages_for_vision"]
