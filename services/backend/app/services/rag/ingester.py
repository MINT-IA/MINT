"""
Markdown ingestion for the MINT knowledge base.

Parses education insert markdown files, extracts metadata and sections,
splits into meaningful chunks, and adds them to the vector store.
"""

from __future__ import annotations

import hashlib
import logging
import re
from pathlib import Path
from typing import Optional

from app.services.rag.vector_store import MintVectorStore

logger = logging.getLogger(__name__)


class MarkdownIngester:
    """Ingest education inserts and other markdown content into the vector store."""

    # Sections we extract from each markdown file
    SECTIONS = [
        "Trigger",
        "Inputs",
        "Outputs",
        "Hypothèses",
        "Limites",
        "Disclaimer",
        "Action",
        "Reminder",
        "Safe Mode",
    ]

    def __init__(self, vector_store: MintVectorStore):
        """
        Initialize the ingester.

        Args:
            vector_store: The MintVectorStore to add documents to.
        """
        self.vector_store = vector_store

    def ingest_directory(
        self,
        directory: str,
        language: Optional[str] = None,
    ) -> int:
        """
        Ingest all markdown files from a directory.

        Args:
            directory: Path to the directory containing .md files.
            language: Override language for all files. If None, auto-detected
                      from filename suffix (_de, _it, etc.; default is "fr").

        Returns:
            Total number of document chunks ingested.
        """
        dir_path = Path(directory)
        if not dir_path.exists():
            logger.error("Directory does not exist: %s", directory)
            return 0

        total_ingested = 0
        md_files = sorted(dir_path.glob("*.md"))

        for filepath in md_files:
            # Skip README files
            if filepath.name.lower() == "readme.md":
                continue

            # Auto-detect language from filename
            file_language = language or self._detect_language(filepath.name)

            count = self.ingest_file(str(filepath), language=file_language)
            total_ingested += count

        logger.info(
            "Ingested %d chunks from %d files in %s",
            total_ingested,
            len(md_files),
            directory,
        )
        return total_ingested

    def ingest_file(self, filepath: str, language: str = "fr") -> int:
        """
        Parse and ingest a single markdown file.

        Args:
            filepath: Path to the .md file.
            language: Language code ("fr", "de", "en", "it").

        Returns:
            Number of document chunks added.
        """
        file_path = Path(filepath)
        if not file_path.exists():
            logger.warning("File not found: %s", filepath)
            return 0

        content = file_path.read_text(encoding="utf-8")

        # Extract metadata
        metadata = self._extract_metadata(content)
        question_id = metadata.get("questionId", file_path.stem)

        # Extract title from first heading
        title = self._extract_title(content)

        # Parse sections into chunks (includes Niveau 0/1 sections)
        sections = self._extract_sections(content)

        # Detect bi-niveau structure: look for "Niveau 0" and "Niveau 1" section headings.
        # If bi-niveau sections exist, each gets its own level tag.
        # Otherwise the whole document defaults to level 1.
        has_niveau_0 = "Niveau 0" in sections
        has_niveau_1 = "Niveau 1" in sections
        has_bi_niveau = has_niveau_0 or has_niveau_1

        # Default document-level literacy level (used when no bi-niveau sections exist)
        default_level = 1

        documents = []

        # Add the full document as one chunk
        doc_id = self._make_id(filepath, "full")
        documents.append({
            "id": doc_id,
            "text": content,
            "metadata": {
                "source": file_path.name,
                "filepath": str(file_path),
                "language": language,
                "category": "education_insert",
                "question_id": question_id,
                "title": title,
                "section": "full",
                "phase": metadata.get("phase", ""),
                "status": metadata.get("status", ""),
                "level": default_level,
            },
        })

        # Add each section as a separate chunk
        for section_name, section_text in sections.items():
            if not section_text.strip():
                continue

            # Determine the literacy level for this section chunk.
            # Bi-niveau section headings set their own level; all others inherit default.
            if section_name == "Niveau 0":
                section_level = 0
            elif section_name == "Niveau 1":
                section_level = 1
            elif has_bi_niveau:
                # Non-niveau sections in a bi-niveau doc: use default level
                section_level = default_level
            else:
                section_level = default_level

            doc_id = self._make_id(filepath, section_name)
            documents.append({
                "id": doc_id,
                "text": f"[{title}] {section_name}:\n{section_text}",
                "metadata": {
                    "source": file_path.name,
                    "filepath": str(file_path),
                    "language": language,
                    "category": "education_insert",
                    "question_id": question_id,
                    "title": title,
                    "section": section_name,
                    "phase": metadata.get("phase", ""),
                    "status": metadata.get("status", ""),
                    "level": section_level,
                },
            })

        return self.vector_store.add_documents(documents)

    def _extract_metadata(self, content: str) -> dict:
        """Extract YAML metadata from the ## Metadata section."""
        metadata = {}
        # Look for ```yaml ... ``` block inside ## Metadata section
        pattern = r"## Metadata\s*\n```yaml\s*\n(.*?)```"
        match = re.search(pattern, content, re.DOTALL)
        if match:
            yaml_text = match.group(1)
            for line in yaml_text.strip().split("\n"):
                if ":" in line:
                    key, value = line.split(":", 1)
                    metadata[key.strip()] = value.strip().strip('"').strip("'")
        return metadata

    def _extract_title(self, content: str) -> str:
        """Extract the title from the first # heading."""
        match = re.match(r"^#\s+(.+?)$", content, re.MULTILINE)
        if match:
            return match.group(1).strip()
        return "Untitled"

    def _extract_sections(self, content: str) -> dict[str, str]:
        """Extract named sections from the markdown content."""
        sections = {}
        # Split by ## headings
        parts = re.split(r"^## (.+?)$", content, flags=re.MULTILINE)

        # parts[0] is content before first ##
        # parts[1], parts[2] = heading, content
        # parts[3], parts[4] = heading, content ...
        for i in range(1, len(parts) - 1, 2):
            heading = parts[i].strip()
            body = parts[i + 1].strip() if i + 1 < len(parts) else ""
            # Skip Metadata section (already extracted)
            if heading.lower() == "metadata":
                continue
            sections[heading] = body

        return sections

    def _detect_language(self, filename: str) -> str:
        """Detect language from filename suffix (_de, _it, _en)."""
        stem = Path(filename).stem
        if stem.endswith("_de"):
            return "de"
        elif stem.endswith("_it"):
            return "it"
        elif stem.endswith("_en"):
            return "en"
        return "fr"

    def _make_id(self, filepath: str, section: str) -> str:
        """Create a stable document ID from filepath and section."""
        raw = f"{filepath}:{section}"
        return hashlib.sha256(raw.encode()).hexdigest()[:16]
