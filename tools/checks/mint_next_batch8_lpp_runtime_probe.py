#!/usr/bin/env python3
"""Traverse the Batch 8 LPP slice through real Flutter Web semantics in Chrome."""

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
CAPTURES = ROOT / "product/mint_next/batch8/evidence/runtime"


class QuietHandler(SimpleHTTPRequestHandler):
    def log_message(self, format: str, *args: object) -> None:
        pass


def screenshot(browser: Target, path: Path) -> None:
    browser.call("Emulation.setDeviceMetricsOverride", {"width": 390, "height": 844, "deviceScaleFactor": 1, "mobile": True})
    browser.call("Emulation.setPageScaleFactor", {"pageScaleFactor": 1})
    browser.js("document.activeElement?.blur();document.querySelector('flutter-view')?.focus({preventScroll:true});scrollTo(0,0)")
    browser.js("new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)))")
    path.parent.mkdir(parents=True, exist_ok=True)
    result = browser.call(
        "Page.captureScreenshot",
        {"format": "png", "captureBeyondViewport": True, "clip": {"x": 0, "y": 0, "width": 390, "height": 844, "scale": 1}},
    )
    path.write_bytes(base64.b64decode(result["data"]))


def enable_semantics(browser: Target) -> None:
    for _ in range(60):
        if browser.js("!!document.querySelector('flt-semantics-placeholder')"):
            break
        time.sleep(.1)
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


def reach_lpp(browser: Target, url: str) -> None:
    browser.navigate(url)
    enable_semantics(browser)
    click_label(browser, "Comprendre")
    click_label(browser, "Continuer")
    year = datetime.now(ZoneInfo("Europe/Zurich")).year
    click_label(browser, f"Année en cours : {year}")
    click_label(browser, "Continuer")
    check("As-tu actuellement une caisse de pension ?" in text(browser), "LPP question reached")


def run(capture: bool) -> None:
    subprocess.run(
        ["flutter", "build", "web", "--release", "--no-web-resources-cdn", "--dart-define=MINT_LAB_LOCALE=fr"],
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
        browser.call("Emulation.setDeviceMetricsOverride", {"width": 390, "height": 844, "deviceScaleFactor": 1, "mobile": True})
        reach_lpp(browser, url)
        body = text(browser)
        check(all(label in body for label in ("Oui", "Non", "Je ne sais pas")), "three visible LPP choices")
        check(not any(token in body for token in ("CHF", "%", "7’", "36’")), "no amount or threshold on question")
        if capture:
            screenshot(browser, CAPTURES / "fr_lpp_question_chrome_390.png")

        click_label(browser, "Je ne sais pas")
        body = text(browser)
        check("MINT" in body and "Quitter" in body, "unknown keeps global header and safe exit")
        check("Tu peux le vérifier sans deviner." in body, "unknown help is plain-language content")
        check(all(part in body for part in ("fiche de salaire", "certificat de prévoyance", "employeur")), "unknown verification paths")
        check("Bientôt disponible" in body, "unknown persistence is visibly unavailable")
        if capture:
            screenshot(browser, CAPTURES / "fr_lpp_unknown_chrome_390.png")
        click_label(browser, "Revenir à la question")
        selected = browser.js("(()=>{const e=" + button_expression("Je ne sais pas") + ";return e&&e.outerHTML})()")
        check(selected and 'aria-current="true"' in selected, f"unknown selection restored on Back: {selected}")

        reach_lpp(browser, url)
        click_label(browser, "Non")
        body = text(browser)
        check("MINT" in body and "Quitter" in body, "no-LPP keeps global header and safe exit")
        check("ne signifie pas que tu n’as pas droit au 3a" in body, "no-LPP boundary avoids false exclusion")
        check(not any(token in body for token in ("CHF", "%", "indépendant")), "no-LPP boundary remains calculation-free")
        if capture:
            screenshot(browser, CAPTURES / "fr_without_lpp_chrome_390.png")
        click_label(browser, "Corriger ma réponse")
        selected = browser.js("(()=>{const e=" + button_expression("Non") + ";return e&&e.getAttribute('aria-current')})()")
        check(selected == "true", "no selection restored on Back")

        reach_lpp(browser, url)
        click_label(browser, "Oui")
        check("Ton affiliation est claire." in text(browser), "yes reaches fact_contribution boundary")
        click_label(browser, "Retour")
        selected = browser.js("(()=>{const e=" + button_expression("Oui") + ";return e&&e.getAttribute('aria-current')})()")
        check(selected == "true", "yes selection restored on Back")

        click_label(browser, "Quitter")
        check("Tu veux t’arrêter ici ?" in text(browser), "safe exit opened")
        check("Repère local — bientôt disponible" in text(browser), "disabled local reference remains explicit")
        click_label(browser, "Continuer ici")
        selected = browser.js("(()=>{const e=" + button_expression("Oui") + ";return e&&e.getAttribute('aria-current')})()")
        check(selected == "true", "safe exit Resume preserves the selected answer")

        click_label(browser, "Quitter")
        click_label(browser, "Quitter sans enregistrer")
        check("Parcours fermé" in text(browser), "leave without saving reaches dismissed boundary")
        click_label(browser, "Comprendre")
        click_label(browser, "Comprendre")
        click_label(browser, "Continuer")
        check(not browser.js(f"!!({button_expression('Continuer')})"), "tax year was purged on leave without saving")
        year = datetime.now(ZoneInfo("Europe/Zurich")).year
        click_label(browser, f"Année en cours : {year}")
        click_label(browser, "Continuer")
        selected_count = browser.js(
            "[...document.querySelectorAll('flt-semantics[role=button][aria-current=true]')]"
            ".filter(e=>['Oui','Non','Je ne sais pas'].includes(e.innerText.trim())).length"
        )
        check(selected_count == 0, "LPP choice was purged on leave without saving")
        resources = browser.js("performance.getEntriesByType('resource').map(entry=>entry.name)")
        check(not any(str(item).startswith("https://") for item in resources), f"runtime has no external network resource: {resources}")
        print("OK mint_next_batch8_lpp_runtime_probe: real Chrome traversed yes/no/unknown, Back, safe-exit Resume/purge, honest boundaries and zero external runtime calls.")
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
        print("ERROR mint_next_batch8_lpp_runtime_probe: Chrome required")
        return 1
    try:
        run(args.capture)
        return 0
    except Exception as exc:
        print(f"ERROR mint_next_batch8_lpp_runtime_probe: {exc}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
