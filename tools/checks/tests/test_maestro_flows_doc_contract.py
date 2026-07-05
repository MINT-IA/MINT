import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
DOC = ROOT / "docs/codex/MAESTRO_FLOWS.md"
MAESTRO_DIR = ROOT / "apps/mobile/.maestro"
IOS_PLIST = ROOT / "apps/mobile/ios/Runner/Info.plist"
ANDROID_MANIFEST = ROOT / "apps/mobile/android/app/src/main/AndroidManifest.xml"


def test_maestro_flows_doc_matches_current_ios_runtime_contract() -> None:
    text = DOC.read_text(encoding="utf-8")

    obsolete_claims = [
        "there is NO Maestro setup yet",
        "No `.maestro/` folder exists",
        "Deep links do NOT work yet",
        "appId: ch.mint.coach",
        'openLink: "mint://data-block',
        'openLink: "mint://hypotheque',
        'openLink: "mint://succession',
        'openLink: "mint://retraite',
        'openLink: "mint://coach/chat',
        'openLink: "mint://divorce',
    ]
    offenders = [claim for claim in obsolete_claims if claim in text]
    assert not offenders, (
        "MAESTRO_FLOWS.md must describe the current checked-in Maestro "
        f"contract, not old setup tasks: {offenders}"
    )

    assert "apps/mobile/.maestro/" in text
    assert "appId: ch.mint.app" in text
    assert "mint:///" in text
    assert "iOS" in text
    assert "docs/codex/ANDROID_RUNTIME_BLOCKERS.md" in text


def test_checked_in_maestro_flows_use_app_id_and_absolute_deep_links() -> None:
    flows = sorted(MAESTRO_DIR.glob("*.yaml"))
    assert flows, "apps/mobile/.maestro/ must contain checked-in flows"

    bad_app_ids: list[str] = []
    bad_links: list[str] = []
    for flow in flows:
        body = flow.read_text(encoding="utf-8")
        if not body.startswith("appId: ch.mint.app\n"):
            bad_app_ids.append(str(flow.relative_to(ROOT)))
        if re.search(r"openLink:.*mint://[^/]", body):
            bad_links.append(str(flow.relative_to(ROOT)))

    assert not bad_app_ids, f"Maestro flows must target ch.mint.app: {bad_app_ids}"
    assert not bad_links, (
        "Maestro flows must use mint:///absolute-path deep links: "
        f"{bad_links}"
    )


def test_documented_live_maestro_files_exist() -> None:
    text = DOC.read_text(encoding="utf-8")
    live_files = re.findall(r"File: `([^`]*apps/mobile/\.maestro/[^`]+\.yaml)`", text)
    missing = [path for path in live_files if not (ROOT / path).exists()]

    assert not missing, (
        "MAESTRO_FLOWS.md must reserve `File:` for checked-in executable "
        f"flows. Use `Blocked flow path:` for backlog sketches: {missing}"
    )


def test_r4_persistence_flow_is_documented_as_live() -> None:
    text = DOC.read_text(encoding="utf-8")
    flow = MAESTRO_DIR / "r4_persistence.yaml"

    assert flow.exists(), "R-4 restart persistence flow must stay checked in"
    assert "File: `apps/mobile/.maestro/r4_persistence.yaml`" in text
    assert "future R-4 restart runtime YAML" not in text
    flow_text = flow.read_text(encoding="utf-8")
    assert 'text: "Revenu brut annuel"' in flow_text
    assert 'id: "mortgage_afford_result"' in flow_text
    assert 'id: "mortgage_data_quest_next_ask"' in flow_text
    assert 'text: "next_ask_value: patrimoine.epargneLiquide"' in flow_text


def test_deep_link_registration_split_is_explicit() -> None:
    doc = DOC.read_text(encoding="utf-8")
    ios = IOS_PLIST.read_text(encoding="utf-8")
    android = ANDROID_MANIFEST.read_text(encoding="utf-8")

    assert "CFBundleURLSchemes" in ios
    assert "<string>mint</string>" in ios
    assert 'android:scheme="mint"' not in android
    assert "Android" in doc
    assert "compatibility" in doc
    assert "docs/codex/ANDROID_RUNTIME_BLOCKERS.md" in doc
