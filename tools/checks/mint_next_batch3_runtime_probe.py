#!/usr/bin/env python3
"""Drive Batch 3 through a real Chrome target and inspect rendered, scoped state."""
from __future__ import annotations

import argparse
import json
import shutil
import socket
import subprocess
import tempfile
import time
from pathlib import Path
from urllib.parse import quote
from urllib.request import Request, urlopen

import websocket

HTML = Path("product/mint_next/batch3/prototype/index.html")
FORBIDDEN = ("B1-FX-01", "CHF 1’500", "108’000", "2’400", "Léa", "Reçu officiel indicatif")


def chrome() -> str | None:
    for candidate in (
        shutil.which("google-chrome"), shutil.which("chromium"),
        "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    ):
        if candidate and Path(candidate).exists():
            return str(candidate)
    return None


def free_port() -> int:
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return int(sock.getsockname()[1])


class Target:
    def __init__(self, url: str, width: int = 1280):
        self.profile = tempfile.TemporaryDirectory(prefix="mint-b3-chrome-")
        self.port = free_port()
        binary = chrome()
        if not binary:
            raise RuntimeError("Chrome required")
        self.proc = subprocess.Popen([
            binary, "--headless=new", "--disable-gpu", "--no-first-run",
            "--no-default-browser-check", "--remote-allow-origins=*",
            f"--remote-debugging-port={self.port}", f"--user-data-dir={self.profile.name}",
            f"--window-size={width},760", "about:blank",
        ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        base = f"http://127.0.0.1:{self.port}"
        for _ in range(80):
            try:
                request = Request(f"{base}/json/new?{quote(url, safe=':/?=&%')}", method="PUT")
                meta = json.load(urlopen(request, timeout=1)); break
            except Exception:
                time.sleep(.05)
        else:
            self.close(); raise RuntimeError("Chrome DevTools target unavailable")
        self.ws = websocket.create_connection(meta["webSocketDebuggerUrl"], timeout=10)
        self.seq = 0
        self.call("Runtime.enable")
        self.call("Emulation.setDeviceMetricsOverride", {
            "width": width, "height": 760, "deviceScaleFactor": 1, "mobile": width <= 500,
        })
        self.wait_ready()

    def call(self, method: str, params: dict | None = None) -> dict:
        self.seq += 1; wanted = self.seq
        self.ws.send(json.dumps({"id": wanted, "method": method, "params": params or {}}))
        while True:
            message = json.loads(self.ws.recv())
            if message.get("id") == wanted:
                if "error" in message: raise RuntimeError(str(message["error"]))
                return message.get("result", {})

    def js(self, expression: str):
        result = self.call("Runtime.evaluate", {"expression": expression, "returnByValue": True,
                                                  "awaitPromise": True})["result"]
        if result.get("subtype") == "error": raise RuntimeError(result.get("description", "JS error"))
        return result.get("value")

    def wait_ready(self):
        for _ in range(100):
            try:
                if self.js("document.readyState") == "complete":
                    self.js("new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)))")
                    return
            except Exception: pass
            time.sleep(.03)
        raise RuntimeError("page did not settle")

    def navigate(self, url: str):
        self.call("Page.navigate", {"url": url}); self.wait_ready()

    def click(self, selector: str):
        rect = self.js(f"(()=>{{const e=document.querySelector({json.dumps(selector)});e.scrollIntoView({{block:'center',inline:'center'}});const r=e.getBoundingClientRect();return {{x:r.left+r.width/2,y:r.top+r.height/2}}}})()")
        for event in ("mousePressed", "mouseReleased"):
            self.call("Input.dispatchMouseEvent", {"type": event, "x": rect["x"], "y": rect["y"], "button": "left", "clickCount": 1})
        self.js("new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)))")

    def key(self, key: str, modifiers: int = 0):
        self.call("Input.dispatchKeyEvent", {"type": "keyDown", "key": key, "modifiers": modifiers})
        self.call("Input.dispatchKeyEvent", {"type": "keyUp", "key": key, "modifiers": modifiers})

    def close(self):
        try: self.ws.close()
        except Exception: pass
        try: self.proc.terminate(); self.proc.wait(timeout=3)
        except Exception:
            try: self.proc.kill()
            except Exception: pass
        self.profile.cleanup()


def check(condition, label: str):
    if not condition: raise AssertionError(label)


def main() -> int:
    parser = argparse.ArgumentParser(); parser.add_argument("--root", type=Path, default=Path.cwd())
    args = parser.parse_args(); source = (args.root.resolve() / HTML).as_uri()
    if not chrome():
        print("ERROR mint_next_batch3_runtime_probe: Chrome required"); return 1
    browser = None
    try:
        browser = Target(source + "?direction=a&step=1", width=320)
        check(browser.js("innerWidth===320&&document.documentElement.clientWidth===320"), "true 320px viewport")
        # Physically select every direction and advance through all six rendered states.
        seen = []
        expected_result_step = {"a": "4", "b": "3", "c": "4"}
        for direction in "abc":
            browser.navigate(source + "?direction=a&step=1")
            browser.click(f"[data-direction={direction}]")
            check(browser.js(f"document.querySelector('[data-direction={direction}]').getAttribute('aria-pressed')") == "true", f"direction {direction} not selected")
            check(browser.js("phone.dataset.resultStep") == expected_result_step[direction], f"direction {direction} result-step mapping")
            for state_number in range(1, 7):
                snapshot = browser.js("({step:step.textContent,h:content.querySelector('h2')?.textContent||'',w:document.documentElement.scrollWidth,c:document.documentElement.clientWidth})")
                check(snapshot["step"] == f"{state_number} / 6" and snapshot["h"], f"{direction} state {state_number} render")
                check(snapshot["w"] <= snapshot["c"], f"{direction} state {state_number} horizontal overflow {snapshot}")
                seen.append((direction, state_number, snapshot["h"]))
                if state_number == int(expected_result_step[direction]):
                    check(browser.js("!!content.querySelector('.amount')&&content.textContent.includes(FACT.amount)&&content.textContent.includes(FACT.id)"), f"{direction} scoped result")
                if state_number < 6: browser.click("#next")
        check(len(seen) == 18, "18-state traversal")

        # Disclosure: click open/close, Escape, Tab loop, background isolation and focus restore.
        browser.navigate(source + "?direction=a&step=1")
        browser.js("disclose.focus()"); browser.click("#disclose")
        check(browser.js("!overlay.classList.contains('hidden')&&app.inert&&app.getAttribute('aria-hidden')==='true'&&document.activeElement.id==='close-overlay'"), "modal open/isolation/focus")
        browser.click("#close-overlay")
        check(browser.js("overlay.classList.contains('hidden')&&!app.inert&&!app.hasAttribute('aria-hidden')&&document.activeElement===disclose"), "modal close/focus restore: "+str(browser.js("({hidden:overlay.classList.contains('hidden'),inert:app.inert,aria:app.hasAttribute('aria-hidden'),active:document.activeElement.id})")))
        browser.click("#disclose"); browser.key("Escape")
        check(browser.js("overlay.classList.contains('hidden')&&document.activeElement===disclose"), "modal Escape")
        browser.click("#disclose"); browser.js("document.querySelector('#close-overlay').focus()"); browser.key("Tab")
        check(browser.js("document.activeElement.matches('#disclosure a[href]')"), "modal Tab loop")
        browser.click("#close-overlay")

        for direction in "abc":
            browser.navigate(source + f"?direction={direction}&step=1")
            browser.click("#disclose")
            check(browser.js("!overlay.classList.contains('hidden')&&overlay.getBoundingClientRect().width>0&&overlay.scrollWidth<=document.documentElement.clientWidth"), f"{direction} visible disclosure")
            browser.click("#close-overlay")

        # Correction remains across Back; only physically clicking the same row reverts it.
        for direction in "abc":
            browser.navigate(source + f"?direction={direction}&step=5")
            browser.click("[data-critical-edit]"); browser.click("#next")
            check(browser.js("index===5&&!!content.querySelector('#invalidated')&&!content.textContent.includes(FACT.amount)"), f"{direction} invalidation")
            browser.click("#back")
            check(browser.js("index===4&&content.querySelector('[data-critical-edit]').getAttribute('aria-pressed')==='true'"), f"{direction} Back preserves edit")
            browser.click("[data-critical-edit]"); browser.click("#next")
            check(browser.js("index===5&&!content.querySelector('#invalidated')&&content.textContent.includes(FACT.amount)"), f"{direction} explicit revert restores fixture")

        # C's two chips are real controls.
        browser.navigate(source + "?direction=c&step=1")
        browser.click("[data-question]")
        check(browser.js("index===1"), "C question chip")
        browser.navigate(source + "?direction=c&step=1")
        browser.click("[data-disclosure]")
        check(browser.js("!overlay.classList.contains('hidden')"), "C disclosure chip")
        browser.click("#close-overlay")

        # Save by traversing/clicking, then perform an actual navigation reload into saved state 6.
        for direction in "abc":
            browser.navigate(source + f"?direction={direction}&step=1")
            for _ in range(6): browser.click("#next")
            check(browser.js(f"JSON.parse(localStorage.getItem('mint-b3-{direction}')).saved===true"), f"{direction} save")
            browser.navigate(source + f"?direction={direction}")
            check(browser.js("index===5&&step.textContent==='6 / 6'&&content.textContent.includes('Cap enregistré')"), f"{direction} actual reload return")

        # Reset is physically clicked and clears every namespaced record and returns to state 1.
        browser.call("Emulation.setDeviceMetricsOverride", {"width": 1280, "height": 900, "deviceScaleFactor": 1, "mobile": False})
        browser.click("#reset")
        check(browser.js("index===0&&['a','b','c'].every(d=>localStorage.getItem('mint-b3-'+d)===null)"), "reset")
        html = browser.js("document.documentElement.outerHTML")
        check(not any(word in html for word in FORBIDDEN), "forbidden legacy/endorsement wording")
        print("OK mint_next_batch3_runtime_probe: CDP input exercised 18 states, direction controls, scoped results, modal keyboard/isolation, correction/revert/back, C chips, save/reload, reset, and true 320px layout.")
        return 0
    except Exception as exc:
        print(f"ERROR mint_next_batch3_runtime_probe: {exc}"); return 1
    finally:
        if browser: browser.close()


if __name__ == "__main__": raise SystemExit(main())
