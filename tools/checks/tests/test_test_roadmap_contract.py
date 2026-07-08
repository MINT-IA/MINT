from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
ROADMAP = ROOT / "TEST_ROADMAP.md"


def test_test_roadmap_defines_patrol_maestro_and_flutter_split() -> None:
    text = ROADMAP.read_text(encoding="utf-8").casefold()
    section = text[text.index("## 10. répartition patrol / maestro / flutter") :]
    for needle in (
        "répartition patrol / maestro / flutter",
        "patrol = white-box",
        "maestro = black-box",
        "flutter widget tests",
        "p0 input proof",
        "intégration native",
        "runtime proof",
    ):
        assert needle.casefold() in section
