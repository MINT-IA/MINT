from __future__ import annotations

import importlib.util
import plistlib
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
SCRIPT = REPO_ROOT / "tools" / "checks" / "ios_universal_links_release_gate.py"


def _load_module():
    spec = importlib.util.spec_from_file_location(
        "ios_universal_links_release_gate", SCRIPT
    )
    assert spec is not None
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def _write_plist(path: Path, data: dict[str, object]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("wb") as fh:
        plistlib.dump(data, fh)


def _patch_paths(monkeypatch, module, tmp_path: Path) -> tuple[Path, Path]:
    runner_dir = tmp_path / "apps" / "mobile" / "ios" / "Runner"
    info_plist = runner_dir / "Info.plist"
    entitlements = runner_dir / "Runner.entitlements"
    monkeypatch.setattr(module, "INFO_PLIST", info_plist)
    monkeypatch.setattr(module, "ENTITLEMENTS", entitlements)
    return info_plist, entitlements


def _valid_info_plist() -> dict[str, object]:
    return {
        "FlutterDeepLinkingEnabled": True,
        "CFBundleURLTypes": [
            {
                "CFBundleURLName": "ch.mint.app.scheme",
                "CFBundleURLSchemes": ["mintapp"],
            }
        ],
    }


def _valid_entitlements() -> dict[str, object]:
    return {
        "com.apple.developer.associated-domains": [
            "applinks:mint-ai.ch",
            "applinks:www.mint-ai.ch",
        ]
    }


def test_local_gate_passes_when_plist_and_entitlements_are_release_ready(
    tmp_path, monkeypatch
):
    module = _load_module()
    info_plist, entitlements = _patch_paths(monkeypatch, module, tmp_path)
    _write_plist(info_plist, _valid_info_plist())
    _write_plist(entitlements, _valid_entitlements())

    assert module.run_gate(live=False, timeout=0.1) == []


def test_local_gate_fails_when_associated_domains_are_absent(tmp_path, monkeypatch):
    module = _load_module()
    info_plist, entitlements = _patch_paths(monkeypatch, module, tmp_path)
    _write_plist(info_plist, _valid_info_plist())
    _write_plist(entitlements, {"com.apple.developer.applesignin": ["Default"]})

    failures = module.run_gate(live=False, timeout=0.1)

    assert failures == [
        "Runner.entitlements must declare com.apple.developer.associated-domains"
    ]


def test_local_gate_requires_both_product_domains(tmp_path, monkeypatch):
    module = _load_module()
    info_plist, entitlements = _patch_paths(monkeypatch, module, tmp_path)
    _write_plist(info_plist, _valid_info_plist())
    _write_plist(
        entitlements,
        {"com.apple.developer.associated-domains": ["applinks:mint-ai.ch"]},
    )

    failures = module.run_gate(live=False, timeout=0.1)

    assert failures == [
        "Runner.entitlements is missing associated domain(s): "
        "applinks:www.mint-ai.ch"
    ]


def test_aasa_payload_must_match_mint_app_and_routes():
    module = _load_module()

    failures = module._validate_aasa_payload(
        {
            "applinks": {
                "apps": [],
                "details": [
                    {
                        "appID": "7F5UDGYS5H.ch.mint.app",
                        "paths": [
                            "/home",
                            "/anonymous/chat",
                            "/coach/chat",
                            "/explore",
                            "/explore/*",
                        ],
                    }
                ],
            }
        }
    )

    assert failures == []


def test_aasa_payload_rejects_non_mint_or_empty_details():
    module = _load_module()

    assert module._validate_aasa_payload(
        {"applinks": {"apps": [], "details": []}}
    ) == ["AASA applinks.details must be a non-empty list"]
    assert module._validate_aasa_payload(
        {
            "applinks": {
                "apps": [],
                "details": [{"appID": "OTHER.app", "paths": []}],
            }
        }
    ) == ["AASA details must include appID=7F5UDGYS5H.ch.mint.app"]


def test_aasa_payload_rejects_missing_or_unexpected_paths():
    module = _load_module()

    failures = module._validate_aasa_payload(
        {
            "applinks": {
                "apps": [],
                "details": [
                    {
                        "appID": "7F5UDGYS5H.ch.mint.app",
                        "paths": ["/home", "/aujourd-hui", "/explorer/*"],
                    }
                ],
            }
        }
    )

    assert (
        "AASA is missing path(s): /anonymous/chat, /coach/chat, /explore, /explore/*"
        in failures
    )
    assert "AASA contains unexpected path(s): /aujourd-hui, /explorer/*" in failures


class _FakeResponse:
    status = 200
    url = "https://cdn.example.invalid/.well-known/apple-app-site-association"
    headers = {"content-type": "application/json"}

    def __enter__(self):
        return self

    def __exit__(self, *args):
        return False

    def read(self):
        return b'{"applinks":{"apps":[],"details":[]}}'


def test_fetch_json_rejects_redirected_final_url(monkeypatch):
    module = _load_module()
    monkeypatch.setattr(module, "_open_url", lambda request, timeout: _FakeResponse())

    payload, failures = module._fetch_json(
        "https://mint-ai.ch/.well-known/apple-app-site-association",
        timeout=0.1,
    )

    assert payload == {"applinks": {"apps": [], "details": []}}
    assert failures == [
        "https://mint-ai.ch/.well-known/apple-app-site-association redirected "
        "to https://cdn.example.invalid/.well-known/apple-app-site-association; "
        "redirects are not allowed"
    ]
