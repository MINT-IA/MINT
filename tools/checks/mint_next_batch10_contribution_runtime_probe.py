#!/usr/bin/env python3
"""Traverse the accepted Batch 9 contribution contract in real Flutter Web."""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
import re
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
LAB = Path(
    os.environ.get(
        "MINT_BATCH10_LAB",
        ROOT / "product/mint_next/batch7/design_lab",
    )
).resolve()
CAPTURES = ROOT / "product/mint_next/batch10/evidence/runtime"
FORBIDDEN_PERSONAL_CLAIMS = (
    "Tu économiseras",
    "tu économiseras",
    "Tu gagneras",
    "tu gagneras",
    "marge 3a restante",
    "recommandons",
    "garanti",
)

CONTRIBUTION_COPY_SHA256 = {
    "fr": "8f57592fb6d01218aa90e093c1574efc49ef4506f8887f523252aee832da1485",
    "en": "dd74bb2b65b6212c5482a8b8485a6b78939b8395635a71d939ecb151fb4425af",
    "de": "e14466dc86b19437478d5a68b3f50fcf433c61bb312c369063629cb016fd0b54",
    "it": "a043b8a41d7485c089f75631bcc31885ac3303164012aec1432726e0bc524a4f",
    "es": "d039368b56b007b58eb91f19179911b6ece9d394b26efb593e3044d078a4f160",
    "pt": "7eddcfe5d4300ce4a41b1d34a6fddf60b748b5e9d79f0d786f822032807e991a",
}

LOCALIZATION_PIPELINE_SHA256 = {
    "pubspec.yaml": "f910eea0fd3d1f9d2b9d57c8995f3d0505f5da2efa2381859eb326b4b3be88e5",
    "l10n.yaml": "0879c4e81347d78e3551434c75ad282aa818efe28ede77d63326dd8b8d4201be",
    "lib/l10n/generated/mint_next_localizations.dart": "09f915ce4cd18205eba4d55697bdca859227a6770e89eb090cd733424b90d552",
    "lib/l10n/generated/mint_next_localizations_de.dart": "4b689023ed3bad3b952841fedbac44990c95470e57683c199d37e576faf7ad26",
    "lib/l10n/generated/mint_next_localizations_en.dart": "bfd9cc4c2b34169a97fe38adb06a80356516e29c828d57319b18daab844fa115",
    "lib/l10n/generated/mint_next_localizations_es.dart": "02c4b7d93c0024cb045cb851f16ec3970b0eb9068309c6e07f2cdeb8bc2af2ca",
    "lib/l10n/generated/mint_next_localizations_fr.dart": "4bcac7e19ece107a5295ee7c24ce13a27a0ab5fba6b900fcb58d28a9d99e495b",
    "lib/l10n/generated/mint_next_localizations_it.dart": "3beb668c58695f0bcc57fab11ecf951cef437a8bf2a9033ca3748e6bba282b54",
    "lib/l10n/generated/mint_next_localizations_pt.dart": "4aad23764c8281662232b1499ecd64a7f122f2aae5c89f60e06f1fc6117e2e26",
}


def assert_reviewed_contribution_copy() -> None:
    """Bind every reviewed contribution value and its generation metadata in all six locales."""
    for locale, expected in CONTRIBUTION_COPY_SHA256.items():
        source = json.loads((LAB / "lib" / "l10n" / f"app_{locale}.arb").read_text())
        contribution_copy = {
            key: value
            for key, value in source.items()
            if key.startswith("contribution") or key.startswith("@contribution")
        }
        encoded = json.dumps(
            contribution_copy,
            ensure_ascii=False,
            sort_keys=True,
            separators=(",", ":"),
        ).encode()
        actual = hashlib.sha256(encoded).hexdigest()
        check(
            actual == expected,
            f"{locale} reviewed contribution copy is exact ({actual})",
        )


def assert_reviewed_localization_pipeline() -> None:
    """Reject stale or bypassed generated localization inputs before rendering."""
    for relative, expected in LOCALIZATION_PIPELINE_SHA256.items():
        path = LAB / relative
        actual = hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else "missing"
        check(actual == expected, f"localization pipeline bytes are exact: {relative} ({actual})")


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
            "captureBeyondViewport": False,
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


def ax_nodes(browser: Target) -> list[dict[str, object]]:
    return list(browser.call("Accessibility.getFullAXTree").get("nodes", []))


def ax_name(node: dict[str, object]) -> str:
    return str(dict(node.get("name", {})).get("value", ""))


def ax_role(node: dict[str, object]) -> str:
    return str(dict(node.get("role", {})).get("value", ""))


def ax_focused_name(browser: Target) -> str:
    for node in ax_nodes(browser):
        properties = {
            str(item.get("name")): dict(item.get("value", {})).get("value")
            for item in node.get("properties", [])
        }
        if properties.get("focused") is True and ax_role(node) != "RootWebArea":
            return ax_name(node)
    return ""


def ax_reading_names(browser: Target) -> list[str]:
    nodes = ax_nodes(browser)
    by_id = {str(node.get("nodeId")): node for node in nodes}
    names: list[str] = []

    def visit(node_id: str) -> None:
        node = by_id[node_id]
        name = ax_name(node)
        if name:
            names.append(name)
        for child_id in node.get("childIds", []):
            child = str(child_id)
            if child in by_id:
                visit(child)

    if nodes:
        visit(str(nodes[0].get("nodeId")))
    return names


def assert_exact_ax_text(browser: Target, expected: str, state: str) -> None:
    check(expected in ax_reading_names(browser), f"{state} exact reviewed copy")


def assert_question_accessibility(browser: Target, year: int) -> None:
    names = ax_reading_names(browser)
    expected = [
        "MINT",
        "Quitter ce parcours",
        f"En {year}, l’un de tes 3a a-t-il reçu un nouveau versement ?",
        "Réponds pour tous tes 3a, y compris une assurance 3a.",
        f"Compte seulement l’argent neuf reçu pour {year}. Un paiement seulement envoyé ou débité ne compte pas encore ; un transfert, un rendement ou un remboursement de frais non plus.",
        "Pas besoin de connaître le total maintenant. On te le demandera seulement si tu réponds oui.",
        "Ce qui compte — et ce qui ne compte pas",
        "Oui, un nouveau versement a été reçu",
        "Non, aucun nouveau versement",
        "Je ne sais pas",
        "Retour",
    ]
    positions = []
    for label in expected:
        check(label in names, f"AX tree exposes {label}")
        positions.append(names.index(label))
    check(positions == sorted(positions), f"AX reading order follows written contract: {positions}")
    check(
        ax_focused_name(browser) == expected[2],
        "route change moves real Chrome AX focus to question heading",
    )


def assert_safe_exit_keyboard(browser: Target, year: int) -> None:
    click_label(browser, "Quitter ce parcours")
    modal_names = [ax_name(node) for node in ax_nodes(browser)]
    check("Tu veux t’arrêter ici ?" in modal_names, "safe exit heading in AX tree")
    check(
        f"En {year}, l’un de tes 3a a-t-il reçu un nouveau versement ?" not in modal_names,
        "safe exit isolates the background AX tree",
    )
    check(
        ax_focused_name(browser) == "Tu veux t’arrêter ici ?",
        "safe exit gives real Chrome AX focus to its heading",
    )
    allowed = {
        "Tu veux t’arrêter ici ?",
        "Continuer ici",
        "Quitter sans enregistrer",
        "Fond",
    }
    for _ in range(10):
        browser.key("Tab")
        browser.js("new Promise(resolve=>requestAnimationFrame(resolve))")
        focused = ax_focused_name(browser)
        check(focused in allowed, f"safe exit focus remains trapped: {focused!r}")
    browser.key("Escape")
    browser.js("new Promise(resolve=>setTimeout(resolve,300))")
    check("Tu veux t’arrêter ici ?" not in text(browser), "Escape dismisses safe exit")
    check(
        ax_focused_name(browser) == "Quitter ce parcours",
        "Escape returns real Chrome AX focus to the trigger",
    )


def assert_no_personal_result(browser: Target, state: str) -> None:
    body = text(browser)
    check(
        not any(fragment in body for fragment in FORBIDDEN_PERSONAL_CLAIMS),
        f"{state} has no personal promise or recommendation",
    )
    check(
        re.search(r"(?:CHF|Fr\.)\s*[0-9]|[0-9]+(?:[.,][0-9]+)?\s*%", body) is None,
        f"{state} has no amount, threshold or percentage",
    )


def reach_lpp(browser: Target, url: str) -> int:
    browser.navigate(url)
    enable_semantics(browser)
    click_label(browser, "Comprendre")
    click_label(browser, "Continuer")
    year = datetime.now(ZoneInfo("Europe/Zurich")).year
    click_label(browser, f"Année en cours : {year}")
    click_label(browser, "Continuer")
    check("As-tu actuellement une caisse de pension ?" in text(browser), "LPP question reached")
    return year


def reach_contribution(browser: Target, url: str) -> int:
    year = reach_lpp(browser, url)
    click_label(browser, "Oui")
    check(
        f"En {year}, l’un de tes 3a a-t-il reçu un nouveau versement ?" in text(browser),
        "contribution question reached",
    )
    click_label(browser, "Retour")
    check(selected(browser, "Oui"), "LPP yes selection restored from contribution Back")
    click_label(browser, "Quitter ce parcours")
    check("Tu veux t’arrêter ici ?" in text(browser), "LPP safe exit opens")
    click_label(browser, "Continuer ici")
    check(selected(browser, "Oui"), "LPP safe-exit Resume preserves yes")
    click_label(browser, "Oui")
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
        year = reach_lpp(browser, url)
        body = text(browser)
        check(all(label in body for label in ("Oui", "Non", "Je ne sais pas")), "three visible LPP choices")
        check(
            not any(token in body for token in ("CHF", "%", "7’", "36’")),
            "LPP question has no amount or threshold",
        )
        click_label(browser, "Je ne sais pas")
        body = text(browser)
        check("MINT" in body and "Quitter" in body, "LPP unknown keeps header and exit")
        check("Tu peux le vérifier sans deviner." in body, "LPP unknown help remains live")
        check(
            all(fragment in body for fragment in ("fiche de salaire", "certificat de prévoyance", "employeur")),
            "all LPP unknown verification paths remain live",
        )
        check("Bientôt disponible" in body, "LPP unknown local reference remains explicit")
        click_label(browser, "Revenir à la question")
        check(selected(browser, "Je ne sais pas"), "LPP unknown selection restored on Back")

        reach_lpp(browser, url)
        click_label(browser, "Non")
        body = text(browser)
        check("MINT" in body and "Quitter" in body, "LPP no boundary keeps header and exit")
        check(
            "ne signifie pas que tu n’as pas droit au 3a" in body,
            "LPP no boundary remains honest",
        )
        check(
            not any(token in body for token in ("CHF", "%", "indépendant")),
            "LPP no boundary remains calculation-free",
        )
        click_label(browser, "Corriger ma réponse")
        check(selected(browser, "Non"), "LPP no selection restored on Back")

        year = reach_contribution(browser, url)
        assert_question_accessibility(browser, year)
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
        assert_no_personal_result(browser, "question")
        assert_exact_ax_text(
            browser,
            f"Compte seulement l’argent neuf reçu pour {year}. Un paiement seulement envoyé ou débité ne compte pas encore ; un transfert, un rendement ou un remboursement de frais non plus.",
            "question credited note",
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
        assert_no_personal_result(browser, "disclosure")
        if capture:
            browser.call(
                "Input.dispatchTouchEvent",
                {
                    "type": "touchStart",
                    "touchPoints": [{"x": 195, "y": 520}],
                },
            )
            for y in (480, 440, 400, 360, 320, 280, 240, 200, 160, 120):
                time.sleep(0.04)
                browser.call(
                    "Input.dispatchTouchEvent",
                    {
                        "type": "touchMove",
                        "touchPoints": [{"x": 195, "y": y}],
                    },
                )
            time.sleep(0.04)
            browser.call(
                "Input.dispatchTouchEvent",
                {"type": "touchEnd", "touchPoints": []},
            )
            browser.js("new Promise(resolve=>setTimeout(resolve,250))")
            check(
                "Quitter ce parcours" in text(browser)
                and "Je ne sais pas" in text(browser),
                "disclosure keeps a semantic exit and answer path",
            )
            screenshot(browser, CAPTURES / "fr_contribution_disclosure_chrome_390.png")

        click_label(browser, "Je ne sais pas")
        body = text(browser)
        check("Tu peux vérifier sans additionner toi-même." in body, "unknown help reached")
        check("N’additionne jamais un transfert" in body, "unknown help prevents double counting")
        assert_no_personal_result(browser, "unknown help")
        assert_exact_ax_text(
            browser,
            f"Cherche si une cotisation ordinaire a été créditée pour {year} sur chacun de tes 3a. Si un transfert, un rachat ou un remboursement rend la réponse incertaine, garde « Je ne sais pas ».",
            "unknown help body",
        )
        if capture:
            screenshot(browser, CAPTURES / "fr_contribution_unknown_chrome_390.png")
        click_label(browser, "Revenir à la question")
        check(selected(browser, "Je ne sais pas"), "unknown selection restored on Back")
        check("rendements ou les intérêts" in text(browser), "disclosure state preserved on Back")

        click_label(browser, "Non, aucun nouveau versement")
        body = text(browser)
        check("Aucun résultat fiscal n’est encore calculé" in body, "no boundary remains calculation-free")
        assert_no_personal_result(browser, "no boundary")
        assert_exact_ax_text(
            browser,
            "Aucun résultat fiscal n’est encore calculé. L’étape suivante demandera ton canton.",
            "no boundary body",
        )
        if capture:
            screenshot(browser, CAPTURES / "fr_contribution_no_boundary_chrome_390.png")
        click_label(browser, "Corriger ma réponse")
        check(selected(browser, "Non, aucun nouveau versement"), "no selection restored on Back")

        click_label(browser, "Oui, un nouveau versement a été reçu")
        body = text(browser)
        check("aucun montant n’est connu ni calculé" in body, "yes boundary does not invent an amount")
        assert_no_personal_result(browser, "yes boundary")
        assert_exact_ax_text(
            browser,
            "Le total devra couvrir tous tes comptes et polices 3a. Après un remboursement partiel, tu pourras utiliser le montant net confirmé par le prestataire. Pour l’instant, aucun montant n’est connu ni calculé.",
            "yes boundary body",
        )
        if capture:
            screenshot(browser, CAPTURES / "fr_contribution_yes_boundary_chrome_390.png")
        click_label(browser, "Corriger ma réponse")
        check(selected(browser, "Oui, un nouveau versement a été reçu"), "yes selection restored on Back")

        assert_safe_exit_keyboard(browser, year)
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
            "OK mint_next_batch10_contribution_runtime_probe: real Chrome traversed contribution yes/no/unknown, disclosure, Back, honest boundaries, AX reading/focus order, modal isolation, keyboard trap, Escape focus return and safe-exit Resume/purge."
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
    try:
        assert_reviewed_contribution_copy()
        assert_reviewed_localization_pipeline()
        if not chrome():
            print("ERROR mint_next_batch10_contribution_runtime_probe: Chrome required")
            return 1
        run(args.capture)
        return 0
    except Exception as exc:
        print(f"ERROR mint_next_batch10_contribution_runtime_probe: {exc}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
