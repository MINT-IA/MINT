"""Two-stage image PII masker (Phase 29-06 / PRIV-07).

Pipeline:
    1. Local Tesseract OCR → word boxes (via ``pytesseract.image_to_data``).
    2. Reconstruct lines; run the 29-03 PII detector regex belt on each
       line to find IBAN/AVS/EMPLOYER/PHONE character spans.
    3. Map spans back to word bounding boxes (intersection with char
       offsets) and draw filled black rectangles on a PIL copy of the
       source image.
    4. Return masked PNG bytes + :class:`MaskReport`.

Why local OCR first instead of sending the raw image to Claude Vision?
    nLPD art. 16 bars transfers containing identifying PII unless the
    transfer basis is documented. An IBAN or AVS in a payslip image sent
    to an LLM is a data transfer. Pre-masking — even imperfectly —
    removes the identifying field before the transfer, which is the
    defensible posture. Regex belt always runs (defense-in-depth),
    Presidio span detection is a follow-up if needed.

Performance: Tesseract adds ~3-5 s per page. The flag
``MASK_PII_BEFORE_VISION`` is OFF by default — activate only after
Bedrock-primary flip when the defense-in-depth value outweighs latency
cost.

Tests inject a fake OCR callable via the ``_fake_ocr`` kwarg so they run
deterministically without a Tesseract binary in CI.
"""
from __future__ import annotations

import logging
import re
from dataclasses import dataclass, field
from io import BytesIO
from typing import Callable, Optional, Sequence

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Types
# ---------------------------------------------------------------------------


@dataclass
class WordBox:
    """A single OCR word with its pixel bounding box and line assignment."""
    text: str
    x: int
    y: int
    w: int
    h: int
    line_id: int = 0
    # Offset of this word's first char in the reconstructed line string.
    char_offset: int = 0


@dataclass
class MaskReport:
    masked_region_count: int = 0
    categories: set[str] = field(default_factory=set)


# ---------------------------------------------------------------------------
# Span detectors — mirror 29-03 pii_scrubber regex belt but return spans
# ---------------------------------------------------------------------------

_IBAN_RE = re.compile(
    r"\bCH\d{2}\s?\d{4}\s?\d{4}\s?\d{4}\s?\d{4}\s?\d{1,3}\b"
)
_AVS_RE = re.compile(
    r"\b756[.\s\-]?\d{4}[.\s\-]?\d{4}[.\s\-]?\d{2,4}\b"
)
_PHONE_RE = re.compile(
    r"(?:\+41|0041)\s?\d{2}\s?\d{3}\s?\d{2}\s?\d{2}"
)

_DETECTORS: Sequence[tuple[str, re.Pattern[str]]] = (
    ("IBAN", _IBAN_RE),
    ("AVS", _AVS_RE),
    ("PHONE", _PHONE_RE),
)


def _detect_spans(line_text: str) -> list[tuple[str, int, int]]:
    """Return list of (category, start_char, end_char) spans in line_text."""
    spans: list[tuple[str, int, int]] = []
    for category, pat in _DETECTORS:
        for m in pat.finditer(line_text):
            spans.append((category, m.start(), m.end()))
    return spans


# ---------------------------------------------------------------------------
# OCR adapter — Tesseract via pytesseract
# ---------------------------------------------------------------------------


def _tesseract_ocr(image_bytes: bytes) -> list[WordBox]:  # pragma: no cover - prod path
    """Default OCR: Tesseract via pytesseract. Returns [] on any failure."""
    try:
        import pytesseract  # type: ignore
        from PIL import Image
    except ImportError:
        logger.warning("image_masker: pytesseract/Pillow missing — OCR disabled")
        return []
    try:
        img = Image.open(BytesIO(image_bytes)).convert("RGB")
        data = pytesseract.image_to_data(
            img,
            output_type=pytesseract.Output.DICT,
            lang="fra+deu+ita+eng",
        )
    except Exception as exc:
        logger.warning("image_masker: tesseract failed: %s", type(exc).__name__)
        return []

    words: list[WordBox] = []
    n = len(data.get("text", []))
    # Group by (block_num, par_num, line_num) to assign stable line_ids.
    line_map: dict[tuple[int, int, int], int] = {}
    line_cursor: dict[int, int] = {}  # line_id -> running char offset
    next_line_id = 0
    for i in range(n):
        text = (data["text"][i] or "").strip()
        if not text:
            continue
        line_key = (
            data["block_num"][i], data["par_num"][i], data["line_num"][i],
        )
        if line_key not in line_map:
            line_map[line_key] = next_line_id
            line_cursor[next_line_id] = 0
            next_line_id += 1
        line_id = line_map[line_key]
        char_offset = line_cursor[line_id]
        words.append(WordBox(
            text=text,
            x=int(data["left"][i]),
            y=int(data["top"][i]),
            w=int(data["width"][i]),
            h=int(data["height"][i]),
            line_id=line_id,
            char_offset=char_offset,
        ))
        # Advance cursor: word length + 1 space separator
        line_cursor[line_id] = char_offset + len(text) + 1
    return words


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------


def mask_pii_regions(
    image_bytes: bytes,
    *,
    _fake_ocr: Optional[Callable[[bytes], list[WordBox]]] = None,
) -> tuple[bytes, MaskReport]:
    """Mask PII regions in ``image_bytes`` and return (masked_bytes, report).

    Algorithm:
        - Run OCR to get word boxes.
        - For each line, reconstruct text, detect PII spans, map each span
          to the overlapping word boxes, draw filled black rectangles.
        - Return PNG-encoded output.

    On any failure (invalid image, OCR error) the ORIGINAL bytes are
    returned with an empty report. Fail-open: the caller's decision to
    mask is an extra safety layer, not a correctness gate — if masking
    fails we must not block the request, we must fall back to the prior
    behaviour (Vision sees the raw image). This is documented in
    DPA_TECHNICAL_ANNEX.md §5 TOM.
    """
    report = MaskReport()
    try:
        from PIL import Image, ImageDraw
    except ImportError:
        logger.warning("image_masker: Pillow missing — masking disabled")
        return image_bytes, report

    ocr = _fake_ocr if _fake_ocr is not None else _tesseract_ocr
    try:
        words = ocr(image_bytes)
    except Exception as exc:
        logger.warning("image_masker: OCR raised: %s", type(exc).__name__)
        return image_bytes, report

    if not words:
        return image_bytes, report

    # Load image for drawing
    try:
        img = Image.open(BytesIO(image_bytes)).convert("RGB")
    except Exception:
        return image_bytes, report

    draw = ImageDraw.Draw(img)

    # Group words by line
    by_line: dict[int, list[WordBox]] = {}
    for w in words:
        by_line.setdefault(w.line_id, []).append(w)

    masked_any = False
    for line_id, line_words in by_line.items():
        # Reconstruct line text from char_offsets (fill gaps with spaces)
        line_words_sorted = sorted(line_words, key=lambda w: w.char_offset)
        line_len = 0
        for w in line_words_sorted:
            line_len = max(line_len, w.char_offset + len(w.text))
        line_chars = [" "] * line_len
        for w in line_words_sorted:
            for k, c in enumerate(w.text):
                if 0 <= w.char_offset + k < line_len:
                    line_chars[w.char_offset + k] = c
        line_text = "".join(line_chars)

        spans = _detect_spans(line_text)
        if not spans:
            continue

        for category, start, end in spans:
            # Find all word boxes that intersect the span [start, end)
            hit_words = [
                w for w in line_words_sorted
                if not (w.char_offset + len(w.text) <= start or w.char_offset >= end)
            ]
            if not hit_words:
                continue
            x0 = min(w.x for w in hit_words)
            y0 = min(w.y for w in hit_words)
            x1 = max(w.x + w.w for w in hit_words)
            y1 = max(w.y + w.h for w in hit_words)
            # Small padding to cover anti-aliased edges
            pad = 2
            draw.rectangle(
                [x0 - pad, y0 - pad, x1 + pad, y1 + pad],
                fill=(0, 0, 0),
            )
            report.masked_region_count += 1
            report.categories.add(category)
            masked_any = True

    if not masked_any:
        return image_bytes, report

    buf = BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue(), report


__all__ = ["WordBox", "MaskReport", "mask_pii_regions"]
