import importlib.util
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
SCRIPT = ROOT / "tools/checks/no_hardcoded_fr.py"

spec = importlib.util.spec_from_file_location("no_hardcoded_fr", SCRIPT)
assert spec is not None and spec.loader is not None
no_hardcoded_fr = importlib.util.module_from_spec(spec)
spec.loader.exec_module(no_hardcoded_fr)


def test_file_mode_respects_l10n_generated_exclusion() -> None:
    result = subprocess.run(
        [
            sys.executable,
            str(SCRIPT),
            "--file",
            "apps/mobile/lib/l10n/app_localizations.dart",
        ],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )

    assert result.returncode == 0, result.stdout + result.stderr


def test_diff_mode_only_scans_default_flutter_lib_scope() -> None:
    diff = """diff --git a/tools/dev.dart b/tools/dev.dart
--- a/tools/dev.dart
+++ b/tools/dev.dart
@@ -0,0 +1 @@
+const copy = 'épargne disponible';
diff --git a/apps/mobile/lib/screens/demo.dart b/apps/mobile/lib/screens/demo.dart
--- a/apps/mobile/lib/screens/demo.dart
+++ b/apps/mobile/lib/screens/demo.dart
@@ -0,0 +1 @@
+const copy = 'épargne disponible';
"""

    added = no_hardcoded_fr._added_lines(diff, no_hardcoded_fr.DEFAULT_SCOPE)

    assert list(added) == [Path("apps/mobile/lib/screens/demo.dart")]
