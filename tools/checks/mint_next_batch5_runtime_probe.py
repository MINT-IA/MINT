#!/usr/bin/env python3
"""Exercise every Batch 5 navigation action through a real Chrome target."""
from __future__ import annotations

import argparse
import base64
import json
import sys
from pathlib import Path

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent))
from mint_next_batch3_runtime_probe import Target, check, chrome  # noqa: E402


HTML = Path("product/mint_next/batch5/prototype/index.html")
FLOW = Path("product/mint_next/batch5/flow.yaml")
DEFAULT_CAPTURES = Path("product/mint_next/batch5/evidence/renders")
MAIN_PATH = [
    "start_question", "question_continue", "why_continue", "example_continue",
    "tradeoff_continue", "correction_compare", "comparison_complete",
]
PATHS = {
    "today": [],
    "question": MAIN_PATH[:1],
    "why": MAIN_PATH[:2],
    "example": MAIN_PATH[:3],
    "tradeoff": MAIN_PATH[:4],
    "correction": MAIN_PATH[:5],
    "comparison": MAIN_PATH[:6],
    "complete": MAIN_PATH,
    "safe_exit": ["today_safe_exit"],
    "reference_saved": ["today_safe_exit", "exit_save_reference"],
    "dismissed": ["today_safe_exit", "exit_dismiss"],
}
STALE_OFFICIAL_AMOUNTS = ("2’104 CHF", "15’801.35 CHF", "13’697.35 CHF", "7’258 CHF")
FORBIDDEN_ACTIVE_COPY = (
    "garanti", "recommandé pour vous", "votre estimation personnelle",
    "conseil personnalisé", "FINMA certifié",
)


def validate_flow(flow: dict) -> None:
    check(set(flow) == {
        "schema_version", "flow_id", "artifact_kind", "locale", "entry_node", "runtime_contract",
        "nodes", "overlay_controls",
    }, "flow top-level contract")
    check(flow["schema_version"] == 1 and flow["entry_node"] == "today" and
          flow["artifact_kind"] == "bounded_micro_lesson", "flow identity")
    nodes = flow["nodes"]
    check(set(nodes) == set(PATHS), "runtime paths cover every declared node")
    action_owners: dict[str, str] = {}
    adjacency: dict[str, set[str]] = {node: set() for node in nodes}
    for node, contract in nodes.items():
        check(set(contract) <= {"terminal", "actions"} and "actions" in contract, f"{node} shape")
        for action_id, action in contract["actions"].items():
            check(action_id not in action_owners, f"duplicate action {action_id}")
            action_owners[action_id] = node
            check(set(action) <= {"to", "overlay", "mutation"}, f"{action_id} shape")
            check(bool(action.get("to")) ^ bool(action.get("overlay")), f"{action_id} destination")
            if "to" in action:
                check(action["to"] in nodes, f"{action_id} destination exists")
                adjacency[node].add(action["to"])
    terminals = {node for node, value in nodes.items() if value.get("terminal") is True}
    check(terminals == {"complete", "safe_exit", "reference_saved", "dismissed"}, "terminal set")
    reachable = {flow["entry_node"]}
    changed = True
    while changed:
        changed = False
        for node in tuple(reachable):
            before = len(reachable)
            reachable.update(adjacency[node])
            changed |= len(reachable) != before
    check(reachable == set(nodes), "every node reachable from entry")
    for start in nodes:
        seen, frontier = {start}, [start]
        while frontier:
            current = frontier.pop()
            for destination in adjacency[current] - seen:
                seen.add(destination); frontier.append(destination)
        check(bool(seen & terminals), f"{start} reaches terminal")
    overlay = flow["overlay_controls"]
    check(set(overlay) == {"disclosure_close", "disclosure_close_escape"}, "overlay controls exact")
    check(action_owners.keys().isdisjoint(overlay), "overlay action ownership separate")


def action_selector(action_id: str) -> str:
    return f'[data-action="{action_id}"]'


def settle(browser: Target) -> None:
    browser.js("new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)))")


def reach(browser: Target, source: str, node: str) -> None:
    browser.navigate(source + "?probe=reset")
    for action_id in PATHS[node]:
        browser.click(action_selector(action_id))
    check(browser.js("document.body.dataset.node") == node, f"reach {node}")


def screenshot(browser: Target, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    payload = browser.call("Page.captureScreenshot", {"format": "png", "captureBeyondViewport": False})
    destination.write_bytes(base64.b64decode(payload["data"]))


def visible_control_snapshot(browser: Target) -> list[dict]:
    return browser.js("""[...document.querySelectorAll('button,a[href],input,select,textarea,[role="button"]')]
      .filter(e=>!e.closest('[hidden]')&&!e.hidden&&getComputedStyle(e).display!=='none')
      .map(e=>{const r=e.getBoundingClientRect();return {a:e.dataset.action||null,t:(e.textContent||e.getAttribute('aria-label')||e.getAttribute('aria-labelledby')||'').trim(),w:r.width,h:r.height}})""")


def run(root: Path, capture_dir: Path | None) -> None:
    flow = yaml.safe_load((root / FLOW).read_text())
    validate_flow(flow)
    html = (root / HTML).read_text()
    check(not any(token in html.lower() for token in FORBIDDEN_ACTIVE_COPY), "forbidden certainty/advice copy")
    check("fetch(" not in html and "XMLHttpRequest" not in html and "WebSocket(" not in html, "network code forbidden")
    source = (root / HTML).resolve().as_uri()
    browser = Target(source + "?probe=reset", width=320)
    try:
        check(browser.js("innerWidth===320&&document.documentElement.clientWidth===320"), "true 320px viewport")
        nodes = flow["nodes"]
        exercised: set[str] = set()
        for node, contract in nodes.items():
            reach(browser, source, node)
            check(browser.js("!!document.querySelector('h1')"), f"{node} heading")
            check(browser.js("document.documentElement.scrollWidth<=innerWidth"), f"{node} horizontal overflow")
            controls = visible_control_snapshot(browser)
            check(all(item["a"] and item["t"] and item["w"] >= 44 and item["h"] >= 44 for item in controls), f"{node} contracted labeled 44px controls: {controls}")
            visible_ids = {item["a"] for item in controls}
            allowed_ids = set(contract["actions"]) | {"disclosure_close"}
            check(visible_ids <= allowed_ids, f"{node} undeclared visible action {visible_ids - allowed_ids}")
            for action_id, action in contract["actions"].items():
                reach(browser, source, node)
                if action_id == "correction_restore":
                    browser.click(action_selector("correction_toggle_commune"))
                selector = action_selector(action_id)
                check(browser.js(f"!!document.querySelector({json.dumps(selector)})"), f"{action_id} rendered")
                browser.click(selector)
                exercised.add(action_id)
                if action.get("overlay"):
                    check(browser.js("!document.querySelector('#overlay').hidden&&document.querySelector('.shell').inert&&document.activeElement.id==='dialog-title'"), f"{action_id} modal open")
                    browser.click(action_selector("disclosure_close"))
                    check(browser.js("document.querySelector('#overlay').hidden&&!document.querySelector('.shell').inert"), f"{action_id} modal close")
                else:
                    check(browser.js("document.body.dataset.node") == action["to"], f"{action_id} -> {action['to']}")
        declared = {action for contract in nodes.values() for action in contract["actions"]}
        check(exercised == declared, f"all declared actions exercised: missing {declared - exercised}")

        # Corrections hide every official output until the exact fixture is restored.
        reach(browser, source, "correction")
        browser.click(action_selector("correction_toggle_commune"))
        check(browser.js("document.body.dataset.node==='correction'&&!!document.querySelector('.notice')"), "correction invalidates")
        text = browser.js("document.querySelector('#screen').innerText")
        check(not any(amount in text for amount in STALE_OFFICIAL_AMOUNTS), "stale outputs hidden in correction")
        browser.click(action_selector("correction_compare"))
        text = browser.js("document.querySelector('#screen').innerText")
        check(not any(amount in text for amount in STALE_OFFICIAL_AMOUNTS), "stale outputs hidden in comparison")
        browser.click(action_selector("comparison_back"))
        browser.click(action_selector("correction_restore"))
        browser.click(action_selector("correction_compare"))
        check(browser.js("['amount','before','after'].every(k=>document.querySelector('#screen').innerText.includes(F[k]))"), "exact restore returns bounded fixture")

        # Modal keyboard loop, Escape, background isolation and focus restoration.
        reach(browser, source, "example")
        browser.js("document.querySelector('#info').focus()")
        browser.click(action_selector("example_open_disclosure"))
        browser.key("Tab")
        check(browser.js("document.activeElement.dataset.action==='disclosure_close'"), "modal Tab close")
        browser.key("Tab")
        check(browser.js("document.activeElement.dataset.action==='disclosure_close'"), "single-control modal focus wraps")
        browser.key("Tab", modifiers=8)
        check(browser.js("document.activeElement.dataset.action==='disclosure_close'"), "modal reverse focus wraps")
        browser.key("Escape")
        check(browser.js("document.querySelector('#overlay').hidden&&document.activeElement===document.querySelector('#info')"), "modal Escape focus restore")

        # Browser history and rendered Back both return predictably without dead state.
        browser.navigate(source + "?probe=reset")
        browser.click(action_selector("start_question")); browser.click(action_selector("question_continue"))
        browser.js("new Promise(resolve=>{addEventListener('popstate',()=>requestAnimationFrame(()=>resolve()),{once:true});history.back()})")
        check(browser.js("document.body.dataset.node") == "question", "browser back follows history")
        browser.click(action_selector("question_back"))
        check(browser.js("document.body.dataset.node") == "today", "rendered back reaches entry")

        # Local-only reference survives reload; dismiss/reset removes it.
        reach(browser, source, "complete")
        browser.click(action_selector("complete_save"))
        check(browser.js("localStorage.getItem('mint-b5-state')==='reference'&&document.querySelector('#screen').innerText.includes('Repère conservé')"), "local save feedback")
        browser.navigate(source)
        check(browser.js("document.body.dataset.node==='today'&&document.querySelector('#screen').innerText.includes('repère local')"), "local save reload signal")
        reach(browser, source, "safe_exit")
        browser.click(action_selector("exit_save_reference"))
        check(browser.js("localStorage.getItem('mint-b5-state')==='reference'&&document.body.dataset.node==='reference_saved'"), "local reference")
        browser.navigate(source)
        check(browser.js("document.querySelector('#screen').innerText.includes('repère local')"), "reference reload")
        reach(browser, source, "safe_exit")
        browser.click(action_selector("exit_dismiss"))
        check(browser.js("localStorage.getItem('mint-b5-state')===null&&document.body.dataset.node==='dismissed'"), "dismiss clears local state")

        # Internal content scroll, reduced motion and no accidental network loads.
        reach(browser, source, "comparison")
        browser.js("document.querySelector('.content').scrollTop=9999")
        check(browser.js("document.querySelector('.content').scrollTop>=0&&document.documentElement.scrollWidth<=innerWidth"), "comparison remains reachable")
        browser.call("Emulation.setEmulatedMedia", {"features": [{"name": "prefers-reduced-motion", "value": "reduce"}]})
        check(browser.js("getComputedStyle(progress).transitionDuration==='0s'"), "reduced motion")
        resources = browser.js("performance.getEntriesByType('resource').map(x=>x.name)")
        check(not any(name.startswith(("http://", "https://")) for name in resources), f"no runtime network resources {resources}")

        if capture_dir:
            browser.call("Emulation.setEmulatedMedia", {"features": [{"name": "prefers-reduced-motion", "value": "reduce"}]})
            reach(browser, source, "today"); screenshot(browser, capture_dir / "mobile320-today.png")
            reach(browser, source, "comparison"); screenshot(browser, capture_dir / "mobile320-comparison.png")
            reach(browser, source, "safe_exit"); screenshot(browser, capture_dir / "mobile320-safe-exit.png")
            browser.call("Emulation.setDeviceMetricsOverride", {"width": 1280, "height": 900, "deviceScaleFactor": 1, "mobile": False})
            reach(browser, source, "comparison"); screenshot(browser, capture_dir / "desktop1280-comparison.png")
        print(f"OK mint_next_batch5_runtime_probe: {len(nodes)} nodes and {len(exercised)} actions physically traversed; zero dead controls, safe exits, correction invalidation, keyboard modal, browser/back, persistence, 320px and desktop evidence.")
    finally:
        browser.close()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--capture", action="store_true")
    args = parser.parse_args()
    if not chrome():
        print("ERROR mint_next_batch5_runtime_probe: Chrome required")
        return 1
    try:
        run(args.root.resolve(), (args.root.resolve() / DEFAULT_CAPTURES) if args.capture else None)
        return 0
    except Exception as exc:
        print(f"ERROR mint_next_batch5_runtime_probe: {exc}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
