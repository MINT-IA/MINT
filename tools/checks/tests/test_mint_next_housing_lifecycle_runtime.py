from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
FLOW = ROOT / (
    "tools/simulator/flows/maestro-perfect-set/"
    "flow_mint_next_housing_lifecycle.yaml"
)
RUNNER = ROOT / "tools/runtime/mint_next_housing_lifecycle.sh"


def test_flow_proves_the_ordered_owned_fact_lifecycle() -> None:
    flow = FLOW.read_text(encoding="utf-8")

    ordered_markers = [
        'id: "action:fact_logement.continue"',
        'text: "Enregistrer ces informations"',
        'notVisible:\n      id: "node:housing_tenant_boundary"',
        "- stopApp",
        'id: "node:housing_saved_summary"',
        'id: "mon_argent_housing_fact"',
        'id: "action:mon_argent.housing.edit"',
        'id: "choice:fact_logement.other"',
        'id: "action:mon_argent.housing.delete"',
        'text: "^Supprimer$"',
        'notVisible: "Supprimer les informations logement ?"',
        "05-delete-survives-relaunch",
    ]
    cursor = 0
    for marker in ordered_markers:
        cursor = flow.index(marker, cursor) + len(marker)
    assert "clearState: true" in flow
    assert flow.count("Source : saisi par toi dans MINT · mise à jour le .+") >= 2
    assert "/tmp/mint-housing-lifecycle" not in flow
    assert flow.count("${OUTPUT_DIR}") == 5
    assert 'visible: "Ouvrir"' in flow
    assert 'visible: "Open"' not in flow
    assert "storage=(secureSeal|debugPlainFallback)" in flow
    assert "storage=secureSeal.*" not in flow


def test_runner_binds_clean_git_device_binary_flow_and_receipt() -> None:
    runner = RUNNER.read_text(encoding="utf-8")

    for marker in (
        "--runtime-commit",
        "status --porcelain",
        "simctl create",
        "Mint Housing Proof-",
        "simctl delete",
        "AppleLocale fr_CH",
        "flutter build ios --simulator --debug",
        'codesign --verify --deep --strict "$APP"',
        'APP_SIGNATURE="$(printf',
        '"app_signature": os.environ["APP_SIGNATURE"]',
        '"app_cdhash": os.environ["APP_CDHASH"]',
        '"device_name": os.environ["DEVICE_NAME"]',
        "MINT_E2E_MINT_NEXT_HOUSING=true",
        "maestro --device",
        "runtime.json",
        "git_dirty",
        "flow_sha256",
        "app_sha256",
        "maestro_version",
        "runtime_identifier",
        "runtime_version",
        "device_type",
        'STAGING="$PHASE_EVIDENCE.staging.$$"',
        "checkout changed outside runtime evidence",
    ):
        assert marker in runner
    assert "simctl erase" not in runner
    assert "--no-codesign" not in runner
    assert '"device_inventory"' not in runner
    assert "DEVICE_INFO" not in runner
    assert "status --porcelain --untracked-files=all | assert_status_is_evidence_only" in runner
    assert "--dart-define=MINT_NEXT_HOUSING_ENABLED=true" not in runner


def test_runner_self_test_exercises_failure_and_cleanup_transactions() -> None:
    import subprocess

    completed = subprocess.run(
        ["bash", str(RUNNER), "--self-test"],
        check=False,
        capture_output=True,
        text=True,
    )
    assert completed.returncode == 0, completed.stderr
    assert "OK mint_next_housing_lifecycle self-test" in completed.stdout
