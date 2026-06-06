#!/usr/bin/env python3
"""CJT-015 iOS Universal Links release gate.

This check is intentionally stricter than simulator deeplink tests. A simulator
can prove route handling, but CJT-015 closes only when the signed iOS build has
Associated Domains and the production host serves MINT's AASA payload.
"""
from __future__ import annotations

import argparse
import json
import plistlib
import socket
import ssl
import sys
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any

REPO = Path(__file__).resolve().parents[2]
INFO_PLIST = REPO / "apps" / "mobile" / "ios" / "Runner" / "Info.plist"
ENTITLEMENTS = REPO / "apps" / "mobile" / "ios" / "Runner" / "Runner.entitlements"

APP_ID = "7F5UDGYS5H.ch.mint.app"
PRODUCT_HOSTS = ("mint-ai.ch", "www.mint-ai.ch")
EXPECTED_ASSOCIATED_DOMAINS = tuple(f"applinks:{host}" for host in PRODUCT_HOSTS)
EXPECTED_AASA_PATHS = (
    "/home",
    "/anonymous/chat",
    "/coach/chat",
    "/explore",
    "/explore/*",
)
AASA_PATH = "/.well-known/apple-app-site-association"


def _load_plist(path: Path) -> dict[str, Any]:
    with path.open("rb") as fh:
        data = plistlib.load(fh)
    if not isinstance(data, dict):
        raise ValueError(f"{path} is not a plist dict")
    return data


def _check_info_plist(info_plist: Path) -> list[str]:
    failures: list[str] = []
    data = _load_plist(info_plist)

    if data.get("FlutterDeepLinkingEnabled") is not True:
        failures.append("Info.plist must set FlutterDeepLinkingEnabled=true")

    schemes: set[str] = set()
    for entry in data.get("CFBundleURLTypes", []):
        if isinstance(entry, dict):
            for scheme in entry.get("CFBundleURLSchemes", []):
                if isinstance(scheme, str):
                    schemes.add(scheme)
    if "mintapp" not in schemes:
        failures.append("Info.plist must declare the mintapp:// custom scheme")

    return failures


def _check_entitlements(entitlements: Path) -> list[str]:
    failures: list[str] = []
    data = _load_plist(entitlements)
    domains = data.get("com.apple.developer.associated-domains")
    if not isinstance(domains, list):
        return [
            "Runner.entitlements must declare "
            "com.apple.developer.associated-domains"
        ]

    declared = {domain for domain in domains if isinstance(domain, str)}
    missing = sorted(set(EXPECTED_ASSOCIATED_DOMAINS) - declared)
    if missing:
        failures.append(
            "Runner.entitlements is missing associated domain(s): "
            + ", ".join(missing)
        )
    return failures


def _validate_aasa_payload(payload: Any) -> list[str]:
    failures: list[str] = []
    if not isinstance(payload, dict):
        return ["AASA payload must be a JSON object"]

    applinks = payload.get("applinks")
    if not isinstance(applinks, dict):
        return ["AASA payload must contain an applinks object"]

    details = applinks.get("details")
    if not isinstance(details, list) or not details:
        return ["AASA applinks.details must be a non-empty list"]

    matching_details = [
        detail
        for detail in details
        if isinstance(detail, dict) and detail.get("appID") == APP_ID
    ]
    if not matching_details:
        failures.append(f"AASA details must include appID={APP_ID}")
        return failures

    declared_paths: set[str] = set()
    for detail in matching_details:
        paths = detail.get("paths")
        if isinstance(paths, list):
            declared_paths.update(path for path in paths if isinstance(path, str))

    missing_paths = sorted(set(EXPECTED_AASA_PATHS) - declared_paths)
    if missing_paths:
        failures.append("AASA is missing path(s): " + ", ".join(missing_paths))

    unexpected_paths = sorted(declared_paths - set(EXPECTED_AASA_PATHS))
    if unexpected_paths:
        failures.append(
            "AASA contains unexpected path(s): " + ", ".join(unexpected_paths)
        )
    return failures


def _fetch_json(url: str, timeout: float) -> tuple[Any | None, list[str]]:
    request = urllib.request.Request(url, headers={"User-Agent": "mint-cjt-015-gate"})
    try:
        with _open_url(request, timeout) as response:
            status = response.status
            content_type = response.headers.get("content-type", "")
            final_url = response.url
            body = response.read()
    except urllib.error.HTTPError as exc:
        return None, [f"{url} returned HTTP {exc.code}; redirects are not allowed"]
    except (urllib.error.URLError, socket.timeout, TimeoutError) as exc:
        return None, [f"{url} is not reachable: {exc}"]

    failures: list[str] = []
    if final_url != url:
        failures.append(f"{url} redirected to {final_url}; redirects are not allowed")
    if status != 200:
        failures.append(f"{url} returned HTTP {status}, expected 200")
    if "application/json" not in content_type.lower():
        failures.append(
            f"{url} content-type is {content_type!r}, expected application/json"
        )

    try:
        payload = json.loads(body.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        return None, failures + [f"{url} did not return valid JSON: {exc}"]
    return payload, failures


class _NoRedirectHandler(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args: Any, **kwargs: Any) -> None:
        return None


def _open_url(request: urllib.request.Request, timeout: float) -> Any:
    opener = urllib.request.build_opener(
        _NoRedirectHandler,
        urllib.request.HTTPSHandler(context=ssl.create_default_context()),
    )
    return opener.open(
        request,
        timeout=timeout,
    )


def _check_live_aasa(hosts: tuple[str, ...], timeout: float) -> list[str]:
    failures: list[str] = []
    for host in hosts:
        url = f"https://{host}{AASA_PATH}"
        payload, fetch_failures = _fetch_json(url, timeout)
        failures.extend(fetch_failures)
        if payload is not None:
            failures.extend(
                f"{host}: {failure}" for failure in _validate_aasa_payload(payload)
            )
    return failures


def run_gate(*, live: bool, timeout: float) -> list[str]:
    failures: list[str] = []
    failures.extend(_check_info_plist(INFO_PLIST))
    failures.extend(_check_entitlements(ENTITLEMENTS))
    if live:
        failures.extend(_check_live_aasa(PRODUCT_HOSTS, timeout))
    return failures


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--live",
        action="store_true",
        help="Also probe production AASA URLs over HTTPS.",
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=10.0,
        help="Per-request timeout in seconds for --live probes.",
    )
    args = parser.parse_args(argv)

    failures = run_gate(live=args.live, timeout=args.timeout)
    if failures:
        for failure in failures:
            print(
                f"::error::ios_universal_links_release_gate: {failure}",
                file=sys.stderr,
            )
        return 1

    live_suffix = " + live AASA" if args.live else ""
    print(f"[OK] iOS Universal Links release gate passed{live_suffix}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
