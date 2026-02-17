"""
PDF document parser for MINT Docling pipeline.

Uses pdfplumber for lightweight, reliable text and table extraction from PDF files.
Designed for Swiss financial documents (LPP certificates, salary slips, etc.).
"""

from __future__ import annotations

import io
import logging
from dataclasses import dataclass, field

try:
    import pdfplumber

    PDFPLUMBER_AVAILABLE = True
except ImportError:
    PDFPLUMBER_AVAILABLE = False

logger = logging.getLogger(__name__)


@dataclass
class PageContent:
    """Extracted content from a single PDF page."""

    page_number: int
    text: str
    tables: list[list[list[str]]] = field(default_factory=list)


@dataclass
class ParsedDocument:
    """Result of parsing a PDF document."""

    pages: list[PageContent] = field(default_factory=list)
    full_text: str = ""
    metadata: dict = field(default_factory=dict)


class DocumentParser:
    """
    PDF document parser using pdfplumber.

    Extracts text and tables from PDF files, handling errors gracefully
    for corrupted or empty documents.
    """

    # Maximum file size: 20 MB (reasonable for certificates)
    MAX_FILE_SIZE = 20 * 1024 * 1024
    # Maximum pages to parse (avoid DoS with huge PDFs)
    MAX_PAGES = 50

    def __init__(self):
        """Initialize the document parser."""
        if not PDFPLUMBER_AVAILABLE:
            raise ImportError(
                "pdfplumber is not installed. Install with: pip install -e '.[docling]'"
            )

    def parse_pdf(self, file_bytes: bytes) -> ParsedDocument:
        """
        Parse a PDF file from raw bytes.

        Extracts text and tables from each page, concatenates full text,
        and collects metadata (page count, file size).

        Args:
            file_bytes: Raw PDF file content as bytes.

        Returns:
            ParsedDocument with extracted pages, full text, and metadata.

        Raises:
            ValueError: If the file is empty, too large, or not a valid PDF.
        """
        if not file_bytes:
            raise ValueError("Empty file provided")

        if len(file_bytes) > self.MAX_FILE_SIZE:
            raise ValueError(
                f"File size ({len(file_bytes)} bytes) exceeds maximum "
                f"({self.MAX_FILE_SIZE} bytes)"
            )

        # Quick PDF header check
        if not file_bytes[:5] == b"%PDF-":
            raise ValueError("File does not appear to be a valid PDF (missing %PDF- header)")

        pages: list[PageContent] = []
        full_text_parts: list[str] = []

        try:
            with pdfplumber.open(io.BytesIO(file_bytes)) as pdf:
                page_count = len(pdf.pages)

                if page_count == 0:
                    raise ValueError("PDF contains no pages")

                if page_count > self.MAX_PAGES:
                    logger.warning(
                        "PDF has %d pages, truncating to %d",
                        page_count,
                        self.MAX_PAGES,
                    )

                for i, page in enumerate(pdf.pages[: self.MAX_PAGES]):
                    page_number = i + 1

                    # Extract text
                    try:
                        text = page.extract_text() or ""
                    except Exception as e:
                        logger.warning(
                            "Failed to extract text from page %d: %s",
                            page_number,
                            e,
                        )
                        text = ""

                    # Extract tables
                    tables: list[list[list[str]]] = []
                    try:
                        raw_tables = page.extract_tables() or []
                        for table in raw_tables:
                            if table:
                                # Normalize None values to empty strings
                                cleaned = [
                                    [str(cell) if cell is not None else "" for cell in row]
                                    for row in table
                                    if row is not None
                                ]
                                if cleaned:
                                    tables.append(cleaned)
                    except Exception as e:
                        logger.warning(
                            "Failed to extract tables from page %d: %s",
                            page_number,
                            e,
                        )

                    page_content = PageContent(
                        page_number=page_number,
                        text=text,
                        tables=tables,
                    )
                    pages.append(page_content)
                    if text:
                        full_text_parts.append(text)

                metadata = {
                    "page_count": page_count,
                    "file_size_bytes": len(file_bytes),
                    "parsed_pages": len(pages),
                }

        except ValueError:
            # Re-raise our own validation errors
            raise
        except Exception as e:
            raise ValueError(f"Failed to parse PDF: {str(e)}")

        full_text = "\n\n".join(full_text_parts)

        return ParsedDocument(
            pages=pages,
            full_text=full_text,
            metadata=metadata,
        )
