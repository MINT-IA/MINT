#!/usr/bin/env python3
"""WCAG 2.1 AA hardcoded-color gate (Phase 12 / Plan 12-02 / ACCESS-03 / D-04).

Lighter-weight Python complement to the Dart `meetsGuideline` widget test
at `apps/mobile/test/accessibility/wcag_aa_all_touched_test.dart`.

Catches the anti-pattern where a developer hardcodes a hex color via
`Color(0xFF...)` (instead of `MintColors.*`) in a context that suggests
TEXT usage on a known light surface (craie #FCFBF8 or white #FFFFFF).
If the resulting contrast falls below WCAG AA 4.5:1, the gate fails.

Scope:
  - Scans `apps/mobile/lib/` recursively for `.dart` files.
  - Excludes `lib/theme/colors.dart` (the source of truth for tokens).
  - Excludes generated files (`*.g.dart`, `*.freezed.dart`).
  - Excludes test files.
  - For each `Color(0xFFRRGGBB)` literal, if the same line (or the
    previous 2 lines) contains a "text-context" hint (`Text(`, `style:`,
    `TextStyle`, `color:` inside a TextStyle, `foregroundColor`,
    `labelStyle`), compute contrast against BOTH craie and white and
    fail if BOTH are below 4.5:1.

This is a soft net — the strict bar is the Dart `meetsGuideline` test.
But a hardcoded `Color(0xFF888888)` in a Text style would slip past
that test (since it doesn't import the screen) and is exactly what
this gate catches.

Exit 0 on pass, exit 1 with line-level diagnostics on fail.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
LIB = REPO / "apps" / "mobile" / "lib"

# Backgrounds we know v2.2 surfaces sit on (from D-04 + theme/colors.dart).
CRAIE = (0xFC, 0xFB, 0xF8)
WHITE = (0xFF, 0xFF, 0xFF)

# Hex literal: Color(0xFFRRGGBB) or Color(0xAARRGGBB) — we keep RGB only.
HEX_RE = re.compile(r"Color\(0x([0-9A-Fa-f]{8})\)")

# A line is "text context" if it contains any of these markers.
TEXT_CONTEXT_RE = re.compile(
    r"\b(Text\(|TextStyle|textStyle|labelStyle|foregroundColor|TextSpan|"
    r"DefaultTextStyle|titleStyle|subtitleStyle|hintStyle)\b"
)

# `color:` line that lives inside a TextStyle / Text — heuristic via prev lines.
COLOR_FIELD_RE = re.compile(r"\bcolor\s*:")

EXCLUDE_PATH_PARTS = {
    "theme/colors.dart",
}
EXCLUDE_SUFFIXES = (".g.dart", ".freezed.dart")


def _linearize(channel: int) -> float:
    c = channel / 255.0
    return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4


def _luminance(rgb: tuple[int, int, int]) -> float:
    r, g, b = rgb
    return 0.2126 * _linearize(r) + 0.7152 * _linearize(g) + 0.0722 * _linearize(b)


def contrast(fg: tuple[int, int, int], bg: tuple[int, int, int]) -> float:
    l1, l2 = _luminance(fg), _luminance(bg)
    lighter, darker = max(l1, l2), min(l1, l2)
    return (lighter + 0.05) / (darker + 0.05)


def _parse_hex(hex8: str) -> tuple[int, int, int]:
    # 0xAARRGGBB → drop AA
    return int(hex8[2:4], 16), int(hex8[4:6], 16), int(hex8[6:8], 16)


def _is_text_context(lines: list[str], idx: int) -> bool:
    """True if line idx (or one of the previous 2 lines) hints at text use."""
    window = lines[max(0, idx - 2) : idx + 1]
    joined = "\n".join(window)
    if TEXT_CONTEXT_RE.search(joined):
        return True
    # `color: Color(0xFF...)` directly inside a TextStyle block — accept if
    # any of the previous 4 lines contains TextStyle / Text(.
    if COLOR_FIELD_RE.search(lines[idx]):
        wider = "\n".join(lines[max(0, idx - 4) : idx])
        if TEXT_CONTEXT_RE.search(wider):
            return True
    return False


def _iter_dart_files() -> list[Path]:
    out: list[Path] = []
    for p in LIB.rglob("*.dart"):
        rel = p.relative_to(REPO).as_posix()
        if any(part in rel for part in EXCLUDE_PATH_PARTS):
            continue
        if p.name.endswith(EXCLUDE_SUFFIXES):
            continue
        out.append(p)
    return out


def main() -> int:
    failures: list[str] = []
    scanned = 0
    hardcoded_total = 0

    for path in _iter_dart_files():
        scanned += 1
        try:
            text = path.read_text(encoding="utf-8")
        except Exception as exc:  # pragma: no cover
            print(f"::warning::wcag_aa_all_touched: cannot read {path}: {exc}")
            continue
        lines = text.splitlines()
        for i, line in enumerate(lines):
            for match in HEX_RE.finditer(line):
                hardcoded_total += 1
                if not _is_text_context(lines, i):
                    continue
                rgb = _parse_hex(match.group(1))
                ratio_craie = contrast(rgb, CRAIE)
                ratio_white = contrast(rgb, WHITE)
                if ratio_craie < 4.5 and ratio_white < 4.5:
                    rel = path.relative_to(REPO).as_posix()
                    failures.append(
                        f"{rel}:{i + 1}: hardcoded Color(0x{match.group(1)}) "
                        f"in text context fails WCAG AA "
                        f"(craie={ratio_craie:.2f}:1, white={ratio_white:.2f}:1) "
                        f"— migrate to MintColors.* token (e.g. textPrimary, "
                        f"textSecondaryAaa)."
                    )

    if failures:
        print(
            "::error::wcag_aa_all_touched gate failed "
            f"({len(failures)} hardcoded text colors below AA):"
        )
        for f in failures:
            print(f)
        return 1

    print(
        f"OK wcag_aa_all_touched: scanned {scanned} dart files, "
        f"{hardcoded_total} hardcoded Color() literals, "
        f"0 text-context AA violations."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
