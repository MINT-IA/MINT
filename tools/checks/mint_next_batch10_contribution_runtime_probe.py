#!/usr/bin/env python3
"""Traverse the accepted Batch 9 contribution contract in real Flutter Web."""

from __future__ import annotations

import argparse
import base64
import json
import subprocess
import sys
import threading
import time
from datetime import datetime
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from zoneinfo import ZoneInfo

sys.path.insert(0, str(Path(__file__).resolve().parent))
from mint_next_batch3_runtime_probe import Target, check, chrome  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
LAB = ROOT / "product/mint_next/batch7/design_lab"
CAPTURES = ROOT / "product/mint_next/batch10/evidence/runtime"


class QuietHandler(SimpleHTTPRequestHandler):
    def log_message(self, format: str, *args: object) -> None:
        pass


def screenshot(browser: Target, path: Path) -> None:
    browser.call(
        "Emulation.setDeviceMetricsOverride",
        {"width": 390, "height": 844, "deviceScaleFactor": 1, "mobile": True},
    )
    browser.call("Emulation.setPageScaleFactor", {"pageScaleFactor": 1})
    browser.js("document.activeElement?.blur();document.querySelector('flutter-view')?.focus({preventScroll:true});scrollTo(0,0)")
    browser.js("new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)))")
    path.parent.mkdir(parents=True, exist_ok=True)
    result = browser.call(
        "Page.captureScreenshot",
        {
            "format": "png",
            "captureBeyondViewport": True,
            "clip": {"x": 0, "y": 0, "width": 390, "height": 844, "scale": 1},
        },
    )
    path.write_bytes(base64.b64decode(result["data"]))


def enable_semantics(browser: Target) -> None:
    for _ in range(60):
        if browser.js("!!document.querySelector('flt-semantics-placeholder')"):
            break
        time.sleep(0.1)
    else:
        check(False, "Flutter semantics placeholder")
    browser.js("document.querySelector('flt-semantics-placeholder').click()")
    browser.js("new Promise(resolve=>setTimeout(resolve,300))")


def button_expression(label: str) -> str:
    encoded = json.dumps(label)
    return f"[...document.querySelectorAll('flt-semantics[role=button]')].find(e=>e.innerText.trim()==={encoded})"


def click_label(browser: Target, label: str) -> None:
    expression = button_expression(label)
    check(browser.js(f"!!({expression})"), f"visible semantic button: {label}")
    browser.js(f"({expression}).click()")
    browser.js("new Promise(resolve=>setTimeout(resolve,350))")


def text(browser: Target) -> str:
    return str(browser.js("document.body.innerText"))


def scroll_text_into_view(browser: Target, fragment: str) -> None:
    encoded = json.dumps(fragment)
    expression = (
        "[...document.querySelectorAll('flt-semantics')]"
        f".filter(e=>e.innerText.includes({encoded}))"
        ".sort((a,b)=>a.innerText.length-b.innerText.length)[0]"
    )
    check(browser.js(f"!!({expression})"), f"semantic text to scroll: {fragment}")
    browser.js(f"({expression}).scrollIntoView({{block:'center'}})")
    browser.js("new Promise(resolve=>setTimeout(resolve,250))")


def reach_contribution(browser: Target, url: str) -> int:
    browser.navigate(url)
    enable_semantics(browser)
    click_label(browser, "Comprendre")
    click_label(browser, "Continuer")
    year = datetime.now(ZoneInfo("Europe/Zurich")).year
    click_label(browser, f"Année en cours : {year}")
    click_label(browser, "Continuer")
    click_label(browser, "Oui")
    check(
        f"En {year}, l’un de tes 3a a-t-il reçu un nouveau versement ?" in text(browser),
        "contribution question reached",
    )
    return year


def selected(browser: Target, label: str) -> bool:
    value = browser.js(
        "(()=>{const e="
        + button_expression(label)
        + ";return e&&e.getAttribute('aria-current')})()"
    )
    return value == "true"


def run(capture: bool) -> None:
    subprocess.run(
        [
            "flutter",
            "build",
            "web",
            "--release",
            "--no-web-resources-cdn",
            "--dart-define=MINT_LAB_LOCALE=fr",
        ],
        cwd=LAB,
        check=True,
        stdout=subprocess.DEVNULL,
    )
    handler = partial(QuietHandler, directory=str(LAB / "build/web"))
    server = ThreadingHTTPServer(("127.0.0.1", 0), handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    url = f"http://127.0.0.1:{server.server_port}/"
    browser = Target(url, width=390)
    try:
        browser.call(
            "Emulation.setDeviceMetricsOverride",
            {"width": 390, "height": 844, "deviceScaleFactor": 1, "mobile": True},
        )
        year = reach_contribution(browser, url)
        body = text(browser)
        check(
            all(
                label in body
                for label in (
                    "Oui, un nouveau versement a été reçu",
                    "Non, aucun nouveau versement",
                    "Je ne sais pas",
                )
            ),
            "three visible contribution choices",
        )
        check("transfert, un rendement ou un remboursement de frais" in body, "always-visible exclusions")
        check(not any(token in body for token in ("CHF", "%", "7’", "36’")), "question has no amount or threshold")
        if capture:
            screenshot(browser, CAPTURES / "fr_contribution_question_chrome_390.png")

        click_label(browser, "Ce qui compte — et ce qui ne compte pas")
        body = text(browser)
        check(
            all(
                fragment in body
                for fragment in (
                    "transfert entre deux 3a",
                    "rachat pour une année passée",
                    "remboursement partiel",
                    "rendements ou les intérêts",
                    "remboursement de frais",
                )
            ),
            "same-node disclosure classifies neighboring movements",
        )
        if capture:
            scroll_text_into_view(browser, "rendements ou les intérêts")
            screenshot(browser, CAPTURES / "fr_contribution_disclosure_chrome_390.png")

        click_label(browser, "Je ne sais pas")
        body = text(browser)
        check("Tu peux vérifier sans additionner toi-même." in body, "unknown help reached")
        check("N’additionne jamais un transfert" in body, "unknown help prevents double counting")
        if capture:
            screenshot(browser, CAPTURES / "fr_contribution_unknown_chrome_390.png")
        click_label(browser, "Revenir à la question")
        check(selected(browser, "Je ne sais pas"), "unknown selection restored on Back")
        check("rendements ou les intérêts" in text(browser), "disclosure state preserved on Back")

        click_label(browser, "Non, aucun nouveau versement")
        body = text(browser)
        check("Aucun résultat fiscal n’est encore calculé" in body, "no boundary remains calculation-free")
        if capture:
            screenshot(browser, CAPTURES / "fr_contribution_no_boundary_chrome_390.png")
        click_label(browser, "Corriger ma réponse")
        check(selected(browser, "Non, aucun nouveau versement"), "no selection restored on Back")

        click_label(browser, "Oui, un nouveau versement a été reçu")
        body = text(browser)
        check("aucun montant n’est connu ni calculé" in body, "yes boundary does not invent an amount")
        if capture:
            screenshot(browser, CAPTURES / "fr_contribution_yes_boundary_chrome_390.png")
        click_label(browser, "Corriger ma réponse")
        check(selected(browser, "Oui, un nouveau versement a été reçu"), "yes selection restored on Back")

        click_label(browser, "Quitter ce parcours")
        check("Tu veux t’arrêter ici ?" in text(browser), "safe exit opened")
        click_label(browser, "Continuer ici")
        check(selected(browser, "Oui, un nouveau versement a été reçu"), "Resume preserves contribution status")

        click_label(browser, "Quitter ce parcours")
        click_label(browser, "Quitter sans enregistrer")
        check("Parcours fermé" in text(browser), "leave reaches dismissed boundary")
        click_label(browser, "Comprendre")
        click_label(browser, "Comprendre")
        click_label(browser, "Continuer")
        check(not browser.js(f"!!({button_expression('Continuer')})"), "tax year purged on leave")
        click_label(browser, f"Année en cours : {year}")
        click_label(browser, "Continuer")
        click_label(browser, "Oui")
        selected_count = browser.js(
            "[...document.querySelectorAll('flt-semantics[role=button][aria-current=true]')]"
            ".filter(e=>['Oui, un nouveau versement a été reçu','Non, aucun nouveau versement','Je ne sais pas'].includes(e.innerText.trim())).length"
        )
        check(selected_count == 0, "contribution status purged on leave")
        check("rendements ou les intérêts" not in text(browser), "disclosure collapsed after purge")
        resources = browser.js("performance.getEntriesByType('resource').map(entry=>entry.name)")
        check(
            not any(str(item).startswith("https://") for item in resources),
            f"runtime has no external network resource: {resources}",
        )
        print(
            "OK mint_next_batch10_contribution_runtime_probe: real Chrome traversed contribution yes/no/unknown, disclosure, Back, safe-exit Resume/purge and honest boundaries."
        )
    finally:
        browser.close()
        server.shutdown()
        server.server_close()
        thread.join(timeout=2)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--capture", action="store_true")
    args = parser.parse_args()
    if not chrome():
        print("ERROR mint_next_batch10_contribution_runtime_probe: Chrome required")
        return 1
    try:
        run(args.capture)
        return 0
    except Exception as exc:
        print(f"ERROR mint_next_batch10_contribution_runtime_probe: {exc}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
