#!/usr/bin/env python3
"""Soft design lint: prefer Mint color tokens over raw Flutter colors."""

from __future__ import annotations

import argparse
import re
import sys

from _staged_diff import existing_files


PATTERN = re.compile(r"\b(?:Colors\.|Color\(0x|Color\.fromARGB\()", re.IGNORECASE)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--file", nargs="*", action="append", default=[])
    args = parser.parse_args()
    paths = existing_files([item for group in args.file for item in group])
    for path in paths:
        if path.suffix != ".dart":
            continue
        for lineno, line in enumerate(path.read_text(encoding="utf-8", errors="ignore").splitlines(), 1):
            if PATTERN.search(line):
                print(f"{path}:{lineno}: prefer Mint color token", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
