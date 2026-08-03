#!/usr/bin/env python3
"""Exercise the Batch 12 single-provider amount path in real Flutter Web."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import threading
import time
from datetime import datetime
from functools import partial
from http.server import ThreadingHTTPServer
from pathlib import Path
from zoneinfo import ZoneInfo

sys.path.insert(0, str(Path(__file__).resolve().parent))
from mint_next_batch10_contribution_runtime_probe import (  # noqa: E402
    QuietHandler,
    Target,
    ax_focused_name,
    ax_nodes,
    ax_role,
    ax_reading_names,
    check,
    chrome,
    click_label,
    enable_semantics,
    screenshot,
    text,
)

ROOT = Path(__file__).resolve().parents[2]
LAB = Path(
    os.environ.get(
        "MINT_BATCH12_LAB",
        ROOT / "product/mint_next/batch7/design_lab",
    )
).resolve()
CAPTURES = ROOT / "product/mint_next/batch12/evidence/runtime"


def semantic_expression(role: str, label_prefix: str) -> str:
    selector_json = json.dumps(f'flt-semantics[role="{role}"]')
    label_json = json.dumps(label_prefix)
    return (
        "[...document.querySelectorAll("
        + selector_json
        + ")].find(e=>(e.getAttribute('aria-label')||e.innerText||'').trim().startsWith("
        + label_json
        + "))"
    )


def focus_textbox(browser: Target, label_prefix: str) -> str:
    label_json = json.dumps(label_prefix)
    expression = (
        "[...document.querySelectorAll('input,textarea,[role=\"textbox\"]')].find("
        "e=>(e.getAttribute('aria-label')||e.getAttribute('placeholder')||e.innerText||'')"
        f".trim().startsWith({label_json}))"
    )
    check(
        browser.js(f"!!({expression})"),
        f"semantic textbox: {label_prefix}; nodes="
        + repr(
            browser.js(
                "[...document.querySelectorAll('flt-semantics')].map(e=>({role:e.getAttribute('role'),label:e.getAttribute('aria-label'),text:e.innerText}))"
            )
        ),
    )
    if not str(
        browser.js("document.activeElement?.getAttribute('aria-label')||''")
    ).startswith(label_prefix):
        rect = browser.js(
            f"(()=>{{const e=({expression});e.scrollIntoView({{block:'center'}});"
            "const r=e.getBoundingClientRect();return {x:r.left+r.width/2,y:r.top+r.height/2};})()"
        )
        for event in ("mousePressed", "mouseReleased"):
            browser.call(
                "Input.dispatchMouseEvent",
                {
                    "type": event,
                    "x": rect["x"],
                    "y": rect["y"],
                    "button": "left",
                    "clickCount": 1,
                },
            )
        browser.js(f"({expression}).focus()")
    check(
        browser.js("document.activeElement?.getAttribute('aria-label')||''").startswith(label_prefix),
        f"textbox focus: {label_prefix}",
    )
    browser.js("new Promise(resolve=>setTimeout(resolve,150))")
    return expression


def enter_text(browser: Target, label_prefix: str, value: str) -> None:
    expression = focus_textbox(browser, label_prefix)
    for character in value:
        browser.call(
            "Input.dispatchKeyEvent",
            {
                "type": "keyDown",
                "key": character,
                "text": character,
                "unmodifiedText": character,
            },
        )
        browser.call(
            "Input.dispatchKeyEvent",
            {"type": "keyUp", "key": character},
        )
    browser.js("new Promise(resolve=>setTimeout(resolve,250))")
    check(
        browser.js(f"({expression}).value") == value,
        f"textbox exact value: {label_prefix}",
    )


def click_checkbox(browser: Target, label_prefix: str) -> None:
    expression = semantic_expression("checkbox", label_prefix)
    check(browser.js(f"!!({expression})"), f"semantic checkbox: {label_prefix}")
    browser.js(f"({expression}).click()")
    browser.js("new Promise(resolve=>setTimeout(resolve,250))")


def input_values(browser: Target) -> list[str]:
    return list(
        browser.js("[...document.querySelectorAll('input,textarea')].map(e=>e.value)")
    )


def ax_textbox_values(browser: Target) -> list[str]:
    values: list[str] = []
    for node in ax_nodes(browser):
        if ax_role(node) in {"textbox", "textField"}:
            values.append(str(dict(node.get("value", {})).get("value", "")))
    return values


def reach_amount(browser: Target, url: str) -> int:
    browser.navigate(url)
    enable_semantics(browser)
    click_label(browser, "Comprendre")
    click_label(browser, "Continuer")
    year = datetime.now(ZoneInfo("Europe/Zurich")).year
    click_label(browser, f"Année en cours : {year}")
    click_label(browser, "Continuer")
    click_label(browser, "Oui")
    click_label(browser, "Oui, un nouveau versement a été reçu")
    check(
        f"Combien tes 3a ont-ils reçu au total en {year} ?" in text(browser),
        "single-provider amount builder reached",
    )
    return year


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
    server = ThreadingHTTPServer(
        ("127.0.0.1", 0),
        partial(QuietHandler, directory=str(LAB / "build/web")),
    )
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    browser = Target(f"http://127.0.0.1:{server.server_port}/", width=390)
    try:
        browser.call(
            "Emulation.setDeviceMetricsOverride",
            {"width": 390, "height": 844, "deviceScaleFactor": 1, "mobile": True},
        )
        url = f"http://127.0.0.1:{server.server_port}/"
        year = reach_amount(browser, url)
        body = text(browser)
        accessible_text = body + "\n" + "\n".join(ax_reading_names(browser))
        for fragment in (
            "Prestataire 3a",
            f"Montant ordinaire crédité confirmé · {year}",
            f"Je n’ai qu’un seul prestataire 3a et j’ai vérifié son total pour {year}",
            "Ce total n’est pas encore un résultat fiscal",
        ):
            check(fragment in accessible_text, f"amount builder exposes: {fragment}")
        check("Ajouter un prestataire" not in body, "single-provider slice has no add control")
        check("Supprimer" not in body, "single-provider slice has no remove control")
        check(
            ax_focused_name(browser) == f"Combien tes 3a ont-ils reçu au total en {year} ?",
            "real Chrome AX focus reaches amount heading",
        )
        check(
            f"Combien tes 3a ont-ils reçu au total en {year} ?" in ax_reading_names(browser),
            "real Chrome AX tree exposes amount heading",
        )
        if capture:
            screenshot(browser, CAPTURES / "fr_amount_empty_chrome_390.png")

        click_label(browser, "Où trouver le montant ?")
        disclosure = semantic_expression("button", "Où trouver le montant ?")
        check(
            browser.js(f"({disclosure}).getAttribute('aria-expanded')") == "true",
            "disclosure exposes expanded state",
        )
        disclosure_text = text(browser) + "\n" + "\n".join(ax_reading_names(browser))
        check("une seule fois" in disclosure_text, f"provider total once guidance is visible: {disclosure_text!r}")
        check("plusieurs contrats" in disclosure_text, "multi-contract warning is visible")
        if capture:
            browser.call(
                "Input.dispatchMouseEvent",
                {
                    "type": "mouseWheel",
                    "x": 195,
                    "y": 520,
                    "deltaX": 0,
                    "deltaY": 620,
                },
            )
            browser.js("new Promise(resolve=>setTimeout(resolve,350))")
            screenshot(browser, CAPTURES / "fr_amount_disclosure_chrome_390.png")

        enter_text(browser, "Prestataire 3a", "VIAC")
        browser.key("Tab")
        browser.js("new Promise(resolve=>setTimeout(resolve,150))")
        enter_text(
            browser,
            f"Montant ordinaire crédité confirmé · {year}",
            "7258.50",
        )
        click_label(browser, "Continuer")
        check(
            ax_focused_name(browser).startswith("Je n’ai qu’un seul prestataire 3a"),
            "missing review moves AX focus to the checkbox",
        )
        check(
            any("Confirme" in name for name in ax_reading_names(browser)),
            "missing review error is exposed in the AX tree",
        )
        check(
            "J’ai plusieurs prestataires 3a" in text(browser),
            "positive draft switches to partial action; inputs="
            + repr(browser.js("[...document.querySelectorAll('input,textarea')].map(e=>({value:e.value,label:e.getAttribute('aria-label')}))"))
            + "; body="
            + repr(text(browser)),
        )
        click_label(browser, "J’ai plusieurs prestataires 3a")
        check(
            "Ce premier parcours ne peut pas encore additionner plusieurs prestataires"
            in text(browser),
            "honest multi-provider holding route reached",
        )
        check("7258.50" not in text(browser), "partial help does not render personal amount")
        if capture:
            screenshot(browser, CAPTURES / "fr_amount_partial_help_chrome_390.png")
        click_label(browser, "Revenir à la saisie sans confirmer")
        check(
            ax_focused_name(browser).startswith(
                f"Montant ordinaire crédité confirmé · {year}"
            ),
            "partial-help return restores amount focus",
        )
        focus_textbox(browser, "Prestataire 3a")
        browser.key("Tab")
        browser.js("new Promise(resolve=>setTimeout(resolve,150))")
        restored = input_values(browser)
        restored_ax = ax_textbox_values(browser)
        check(
            restored == ["VIAC", "7258.50"] or restored_ax == ["VIAC", "7258.50"],
            f"partial help restores draft: dom={restored}, ax={restored_ax}",
        )

        checkbox = semantic_expression("checkbox", "Je n’ai qu’un seul prestataire 3a")
        check(
            browser.js(f"({checkbox}).getAttribute('aria-checked')") == "false",
            "single-provider confirmation starts unchecked",
        )
        click_checkbox(browser, "Je n’ai qu’un seul prestataire 3a")
        check(
            browser.js(f"({checkbox}).getAttribute('aria-checked')") == "true",
            "single-provider confirmation exposes checked state",
        )
        click_label(browser, "Continuer")
        check("Aucun résultat fiscal n’est encore calculé" in text(browser), "complete amount reaches honest canton boundary")
        check(
            f"Ton montant ordinaire pour {year} est prêt." in text(browser),
            "positive path keeps the contribution fact",
        )
        check(
            "aucun versement ordinaire" not in text(browser),
            "positive path never inverts the contribution fact",
        )
        check("7258.50" not in text(browser), "canton boundary does not repeat personal amount")
        if capture:
            screenshot(browser, CAPTURES / "fr_amount_complete_boundary_chrome_390.png")
        click_label(browser, "Corriger mes montants")
        focus_textbox(browser, "Prestataire 3a")
        browser.key("Tab")
        browser.js("new Promise(resolve=>setTimeout(resolve,150))")
        check(input_values(browser) == ["VIAC", "7258.50"], "canton Back restores exact draft")

        resources = browser.js("performance.getEntriesByType('resource').map(entry=>entry.name)")
        check(
            not any(str(item).startswith("https://") for item in resources),
            f"runtime has no external network resource: {resources}",
        )
        print(
            "OK mint_next_batch12_amount_runtime_probe: real Chrome traversed empty, disclosure, partial help, exact draft restoration and complete canton boundary."
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
        print("ERROR mint_next_batch12_amount_runtime_probe: Chrome required")
        return 1
    try:
        run(args.capture)
        return 0
    except Exception as exc:
        print(f"ERROR mint_next_batch12_amount_runtime_probe: {exc}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
