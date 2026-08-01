#!/usr/bin/env python3
"""Exercise Batch 1 browser behavior instead of trusting static HTML tokens."""
from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from pathlib import Path
from urllib.parse import urlencode


HTML = Path("product/mint_next/batch1/prototype/index.html")
CASES = [
    ({"direction": "a", "step": 3}, ["4 / 6", "CHF X–Y", "Vérifier les données manquantes"]),
    ({"direction": "b", "step": 3}, ["4 / 6", "CHF X–Y", "MINT compare. Léa décide."]),
    ({"direction": "c", "step": 3}, ["4 / 6", "AUCUN MOTEUR BRANCHÉ", "Vérifier les données manquantes"]),
    ({"direction": "a", "probe": "correction"}, ["2 / 6", "Nyon", "Valeur corrigée", 'aria-pressed="true"']),
    ({"direction": "b", "probe": "back"}, ["4 / 6", "Deux chemins, aucun montant recommandé"]),
    ({"direction": "c", "probe": "explain"}, ["5 / 6", "Corriger avant de calculer"]),
    ({"direction": "a", "probe": "save"}, ["6 / 6", "Cap enregistré localement", "Cap enregistré"]),
]


def chrome_binary() -> str | None:
    candidates = [
        shutil.which("google-chrome"),
        shutil.which("google-chrome-stable"),
        shutil.which("chromium"),
        "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    ]
    return next((candidate for candidate in candidates if candidate and Path(candidate).exists()), None)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path.cwd())
    args = parser.parse_args()
    root = args.root.resolve()
    chrome = chrome_binary()
    if chrome is None:
        print("ERROR mint_next_batch1_runtime_probe: Chrome/Chromium is required", file=sys.stderr)
        return 1
    source = (root / HTML).resolve().as_uri()
    for query, expected in CASES:
        proc = subprocess.run(
            [chrome, "--headless=new", "--disable-gpu", "--dump-dom", f"{source}?{urlencode(query)}"],
            capture_output=True,
            text=True,
            timeout=30,
        )
        missing = [value for value in expected if value not in proc.stdout]
        if proc.returncode or missing:
            print(f"ERROR mint_next_batch1_runtime_probe: query={query} missing={missing} stderr={proc.stderr[-400:]}", file=sys.stderr)
            return 1
        print(f"PASS query={query}")
    print("OK mint_next_batch1_runtime_probe: render, correction, back, explain, and save behavior executed.", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
