#!/usr/bin/env python3
"""Offline, deterministic provenance extractor for frozen Swiss 3a sources.

The tool never calculates tax and never downloads at product runtime. It accepts
an ephemeral directory containing the eight authority files, verifies their
committed byte hashes, extracts a small reviewed token from each, and emits
canonical JSON. PDF text extraction is delegated to a pinned external binary
whose version is recorded in the output.
"""
from __future__ import annotations

import argparse
import hashlib
import html
import json
import re
import subprocess
import tempfile
from pathlib import Path

import yaml

VERSION = "1.0.0"
ROOT = Path(__file__).resolve().parents[2]
ANNEX = ROOT / ".planning/phases/mint-next-vertical01-3a-20260802/annexes"
RECEIPTS = ANNEX / "authority-receipts.yaml"
OUTPUT = ANNEX / "source-extractions.json"

# source_id: (kind, stable pattern, normalized claim id, normalized value, unit)
SPECS = {
    "ofas_contribution_page": ("html", r"maximum\s+7\s*258\s+francs", "ordinary_cap_web", 7258, "CHF"),
    "ofas_amounts_2026": ("pdf", r"Avec affiliation à une institution de prévoyance du 2e pilier\s+7['’]258 fr\.", "ordinary_cap_table", 7258, "CHF"),
    "afc_circular_18a": ("pdf", r"au plus tard le 31 décembre de l'année concernée", "credit_deadline", "31_december", "date_rule"),
    "vd_income_scale_2026": ("pdf", r"72['’]700\s+5['’]603\.00[\s\S]{0,3000}?80['’]000\s+6['’]389\.00", "vd_scale_anchor", "72700:5603.00|80000:6389.00", "CHF_pairs"),
    "vd_deductions_2026": ("pdf", r"coefficients annuels cantonal \(155\.0% en 2026\)", "vd_coefficient", 155.0, "percent"),
    "vd_cantonal_reduction_2026": ("html", r"Pour l’année 2026, une réduction de 5% de l’impôt cantonal", "vd_reduction", 5.0, "percent"),
    "lausanne_tax_decree_2025_2029": ("pdf", r"perçus à raison de 78\.5 % de l'impôt cantonal de base", "lausanne_coefficient", 78.5, "percent"),
    "ifd_scale_2026": ("pdf", r"Tableau servant à calculer l impôt fédéral direct[\s\S]{0,160}?valables dès 2026", "ifd_single_scale", "form_58c_2026", "table"),
}


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def canonical(data: dict) -> bytes:
    return (json.dumps(data, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode()


def pdf_text(path: Path) -> tuple[str, str]:
    version = subprocess.run(["pdftotext", "-v"], check=True, capture_output=True, text=True)
    version_line = (version.stderr or version.stdout).splitlines()[0]
    with tempfile.TemporaryDirectory() as directory:
        target = Path(directory) / "source.txt"
        subprocess.run(["pdftotext", "-layout", str(path), str(target)], check=True, capture_output=True)
        return target.read_text(encoding="utf-8", errors="strict"), version_line


def html_text(raw: bytes) -> str:
    text = raw.decode("utf-8", errors="strict")
    return re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", html.unescape(text)))


def locate(text: str, pattern: str) -> tuple[re.Match[str], int, int]:
    match = re.search(pattern, text, re.MULTILINE)
    if not match:
        raise ValueError(f"reviewed token not found: {pattern}")
    page = text.count("\f", 0, match.start()) + 1
    line = text.count("\n", 0, match.start()) + 1
    return match, page, line


def derive_claims(extractions: list[dict]) -> dict:
    values = {item["claim_id"]: item["normalized"]["value"] for item in extractions}
    if values["ordinary_cap_web"] != values["ordinary_cap_table"]:
        raise ValueError("ordinary cap authorities diverged")
    return {
        "credit_deadline": values["credit_deadline"],
        "employee_with_lpp_ordinary_cap_chf": values["ordinary_cap_web"],
        "ifd_single_scale": values["ifd_single_scale"],
        "lausanne_income_tax_coefficient_percent": values["lausanne_coefficient"],
        "vd_cantonal_income_tax_coefficient_percent": values["vd_coefficient"],
        "vd_cantonal_income_tax_reduction_percent": values["vd_reduction"],
        "vd_income_scale_anchor": values["vd_scale_anchor"],
    }


def build(source_dir: Path) -> dict:
    receipts = yaml.safe_load(RECEIPTS.read_text(encoding="utf-8"))["receipts"]
    by_id = {receipt["id"]: receipt for receipt in receipts}
    if set(by_id) != set(SPECS):
        raise ValueError("source inventory drift")
    extractions = []
    pdftotext_version = None
    for source_id in sorted(SPECS):
        receipt = by_id[source_id]
        source = source_dir / f"{source_id}.bin"
        raw = source.read_bytes()
        if len(raw) != receipt["bytes"] or sha(raw) != receipt["sha256"]:
            raise ValueError(f"source bytes mismatch: {source_id}")
        kind, pattern, claim_id, value, unit = SPECS[source_id]
        if kind == "pdf":
            text, current_version = pdf_text(source)
            pdftotext_version = pdftotext_version or current_version
            if current_version != pdftotext_version:
                raise ValueError("pdftotext version changed during run")
        else:
            text = html_text(raw)
        match, page, line = locate(text, pattern)
        token = re.sub(r"\s+", " ", match.group(0)).strip()
        extractions.append({
            "claim_id": claim_id,
            "document_sha256": receipt["sha256"],
            "locator": {"line": line, "page": page, "pattern_sha256": sha(pattern.encode())},
            "normalized": {"unit": unit, "value": value},
            "source_id": source_id,
            "token_sha256": sha(token.encode("utf-8")),
        })
    return {
        "extractions": extractions,
        "normalized_claims": derive_claims(extractions),
        "parser": {"id": "three_a_authority_normalizer", "pdftotext": pdftotext_version, "version": VERSION},
        "prohibitions": ["advice", "engine_valid", "phase_passed", "product_activation", "tax_output"],
        "schema_version": 1,
        "source_receipts_sha256": sha(RECEIPTS.read_bytes()),
        "status": "mechanically_extracted_pending_independent_content_review",
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-dir", type=Path, required=True)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--output", type=Path, default=OUTPUT)
    args = parser.parse_args()
    rendered = canonical(build(args.source_dir))
    if args.check:
        if args.output.read_bytes() != rendered:
            raise SystemExit("committed source extractions drifted")
    else:
        args.output.write_bytes(rendered)
    print("OK three_a_authority_normalizer offline provenance")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
