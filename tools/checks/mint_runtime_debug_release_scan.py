#!/usr/bin/env python3
"""Release/profile leakage scan for Mint Runtime Debug Tooling."""

from __future__ import annotations

import argparse
import base64
import re
import sys
import zipfile
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


PROD_WORKFLOWS = (
    Path(".github/workflows/testflight.yml"),
    Path(".github/workflows/play-store.yml"),
)

ARCHIVE_SUFFIXES = {".ipa", ".aab", ".apk", ".zip"}

DEFINE_ASSIGNMENT_RE = re.compile(
    rb"""["']?(ENABLE_ADMIN|ENABLE_DEBUG_TOOLS)["']?\s*[:=]\s*["']?([^"'\s,}\]\)]+)""",
    re.I,
)
STATIC_DISABLED_VALUES = {b"0", b"false"}
STATIC_ENABLED_VALUES = {b"1", b"true"}

ARTIFACT_PATTERNS = (
    ("/admin/debug-spine", re.compile(rb"/admin/debug-spine", re.I)),
    ("Debug Spine label", re.compile(rb"Debug[ _]Spine")),
    ("debug-spine snapshot id", re.compile(rb"debug-spine-(?:before_reset|after_reset|after_relaunch)", re.I)),
    ("mint runtime debug evidence", re.compile(rb"mint-runtime-debug(?:-evidence|-tooling)?", re.I)),
    ("MINT_RUNTIME_DEBUG flag", re.compile(rb"MINT_RUNTIME_DEBUG[A-Z_]*", re.I)),
    ("ENABLE_ADMIN", re.compile(rb"ENABLE_ADMIN", re.I)),
    ("ENABLE_DEBUG_TOOLS", re.compile(rb"ENABLE_DEBUG_TOOLS", re.I)),
    ("/admin/routes", re.compile(rb"/admin/routes", re.I)),
    ("admin route registry label", re.compile(rb"Routes owned by|Registry not generated|tools/mint-routes", re.I)),
)


@dataclass(frozen=True)
class ScanFinding:
    path: Path
    label: str
    sample: str

    def format(self, root: Path) -> str:
        try:
            display_path = self.path.relative_to(root)
        except ValueError:
            display_path = self.path
        return f"{display_path}: {self.label}: {self.sample}"


def _strip_comment_lines(text: str) -> str:
    lines = [line for line in text.splitlines() if not line.lstrip().startswith("#")]
    return "\n".join(lines) + "\n"


def _samples_from(pattern: re.Pattern[bytes], data: bytes) -> Iterable[str]:
    for match in pattern.finditer(data):
        sample = match.group(0)[:160].decode("utf-8", errors="replace")
        yield sample


def _scan_bytes(path: Path, data: bytes, patterns: Iterable[tuple[str, re.Pattern[bytes]]]) -> list[ScanFinding]:
    findings: list[ScanFinding] = []
    for label, pattern in patterns:
        for sample in _samples_from(pattern, data):
            findings.append(ScanFinding(path=path, label=label, sample=sample))
    return findings


def _encoded_enable_patterns() -> tuple[tuple[str, re.Pattern[bytes]], ...]:
    raw_values = (
        b"ENABLE_ADMIN=1",
        b"ENABLE_ADMIN=true",
        b"ENABLE_DEBUG_TOOLS=1",
        b"ENABLE_DEBUG_TOOLS=true",
    )
    patterns = []
    for raw in raw_values:
        encoded = base64.b64encode(raw).decode("ascii")
        patterns.append((f"base64 {raw.decode('ascii')}", re.compile(re.escape(encoded).encode("ascii"))))
    return tuple(patterns)


def _scan_define_assignments(path: Path, data: bytes) -> list[ScanFinding]:
    findings: list[ScanFinding] = []
    for match in DEFINE_ASSIGNMENT_RE.finditer(data):
        name = match.group(1).decode("ascii").upper()
        raw_value = match.group(2).strip().strip(b'"\'')
        value = raw_value.lower()
        if value in STATIC_DISABLED_VALUES:
            continue
        if value in STATIC_ENABLED_VALUES:
            label = f"{name}=true"
            sample = raw_value.decode("utf-8", errors="replace")
        else:
            label = f"{name}=dynamic"
            sample = "<dynamic>"
        findings.append(ScanFinding(path=path, label=label, sample=sample))
    return findings


def _dart_define_from_file_refs(workflow_text: str) -> list[str]:
    refs = []
    pattern = re.compile(r"--dart-define-from-file(?:=|\s+)(?P<path>[^\s\\]+)")
    for match in pattern.finditer(workflow_text):
        refs.append(match.group("path").strip("'\""))
    return refs


def _resolve_define_file(root: Path, ref: str) -> Path | None:
    if "${{" in ref or "$" in ref:
        return None

    raw = Path(ref)
    candidates = []
    if raw.is_absolute():
        candidates.append(raw)
    else:
        candidates.extend((root / raw, root / "apps/mobile" / raw))
    for candidate in candidates:
        if candidate.is_file():
            return candidate
    return None


def scan_release_workflows(root: Path) -> list[ScanFinding]:
    findings: list[ScanFinding] = []
    for workflow in PROD_WORKFLOWS:
        path = root / workflow
        if not path.exists():
            continue
        text = _strip_comment_lines(path.read_text(encoding="utf-8", errors="ignore"))
        data = text.encode("utf-8", errors="ignore")
        findings.extend(_scan_define_assignments(path, data))
        findings.extend(_scan_bytes(path, data, _encoded_enable_patterns()))

        for ref in _dart_define_from_file_refs(text):
            define_file = _resolve_define_file(root, ref)
            if define_file is None:
                findings.append(
                    ScanFinding(
                        path=path,
                        label="unresolved --dart-define-from-file",
                        sample=ref,
                    )
                )
                continue
            findings.extend(_scan_define_assignments(define_file, define_file.read_bytes()))
    return findings


def _iter_artifact_files(paths: Iterable[Path]) -> Iterable[Path]:
    for path in paths:
        if path.is_dir():
            yield from (item for item in path.rglob("*") if item.is_file())
        elif path.is_file():
            yield path


def scan_artifacts(paths: Iterable[Path]) -> list[ScanFinding]:
    findings: list[ScanFinding] = []
    for path in _iter_artifact_files(paths):
        if path.suffix.lower() in ARCHIVE_SUFFIXES:
            try:
                with zipfile.ZipFile(path) as archive:
                    for info in archive.infolist():
                        if info.is_dir():
                            continue
                        entry_path = Path(f"{path}!{info.filename}")
                        findings.extend(_scan_bytes(entry_path, archive.read(info), ARTIFACT_PATTERNS))
                continue
            except zipfile.BadZipFile:
                findings.append(ScanFinding(path=path, label="zip_read_error", sample="not a valid ZIP archive"))
                continue
            except OSError as exc:
                findings.append(ScanFinding(path=path, label="zip_read_error", sample=str(exc)))
                continue
        try:
            data = path.read_bytes()
        except OSError as exc:
            findings.append(ScanFinding(path=path, label="read_error", sample=str(exc)))
            continue
        findings.extend(_scan_bytes(path, data, ARTIFACT_PATTERNS))
    return findings


def _print_findings(root: Path, title: str, findings: list[ScanFinding]) -> int:
    if not findings:
        print(f"[OK] {title}: no debug leakage found")
        return 0
    print(f"[FAIL] {title}: {len(findings)} finding(s)")
    for finding in findings:
        print(finding.format(root))
    return 1


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--workflows-only", action="store_true")
    parser.add_argument("--artifacts", nargs="*", type=Path, default=[])
    args = parser.parse_args(argv)

    root = args.root.resolve()
    status = 0
    workflow_findings = scan_release_workflows(root)
    status |= _print_findings(root, "production workflow scan", workflow_findings)

    if args.artifacts:
        artifact_paths = [path if path.is_absolute() else root / path for path in args.artifacts]
        missing = [path for path in artifact_paths if not path.exists()]
        if missing:
            print("[FAIL] release/profile artifact scan: missing artifact path(s)")
            for path in missing:
                print(path)
            status = 1
        else:
            artifact_findings = scan_artifacts(artifact_paths)
            status |= _print_findings(root, "release/profile artifact scan", artifact_findings)
    elif not args.workflows_only:
        print("[FAIL] release/profile artifact scan: no artifact path supplied")
        status = 1

    return status


if __name__ == "__main__":
    sys.exit(main())
