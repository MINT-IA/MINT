#!/usr/bin/env python3
"""Exercise Batch 1 browser behavior instead of trusting static HTML tokens."""
from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from urllib.parse import urlencode


HTML = Path("product/mint_next/batch1/prototype/index.html")
CASES = [
    ({"direction": "a", "step": 3}, ["4 / 6", "CHF 1’500", "B1-FX-01", "non personnelle", "pas un conseil"]),
    ({"direction": "b", "step": 3}, ["4 / 6", "CHF 1’500", "non personnelle", "Léa ne décide rien à partir de ces montants"]),
    ({"direction": "c", "step": 3}, ["4 / 6", "CHF 1’500", "B1-FX-01", "non personnelle", "pas un conseil"]),
    ({"direction": "a", "probe": "correction"}, ["2 / 6", "Nyon", "Valeur corrigée", 'aria-pressed="true"']),
    ({"direction": "a", "probe": "correction_journey"}, ["5 / 6", "Nyon", 'aria-pressed="true"']),
    ({"direction": "b", "probe": "back"}, ["4 / 6", "Deux chemins, aucun montant recommandé"]),
    ({"direction": "c", "probe": "explain"}, ["5 / 6", "Corriger avant de calculer"]),
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
    with tempfile.TemporaryDirectory(prefix="mint-b1-chrome-") as temp_root:
        profile = Path(temp_root) / "saved-profile"
        reload_profile = Path(temp_root) / "reload-profile"
        base = [chrome, "--headless=new", "--disable-gpu", "--no-first-run", "--no-default-browser-check", "--dump-dom"]
        saved = subprocess.run(base + [f"--user-data-dir={profile}", f"{source}?direction=a&probe=save"], capture_output=True, text=True, timeout=30)
        shutil.copytree(profile, reload_profile, ignore=shutil.ignore_patterns("Singleton*"))
        reloaded = subprocess.run(base + [f"--user-data-dir={reload_profile}", f"{source}?direction=a"], capture_output=True, text=True, timeout=30)
        expected = ["6 / 6", "Cap enregistré localement", "Cap enregistré"]
        missing = [value for value in expected if value not in reloaded.stdout]
        if saved.returncode or reloaded.returncode or missing:
            print(f"ERROR mint_next_batch1_runtime_probe: persisted reload missing={missing}", file=sys.stderr)
            return 1
        print("PASS persisted save across browser reload")
    print("OK mint_next_batch1_runtime_probe: render, correction, back, explain, and save behavior executed.", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
