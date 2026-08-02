#!/usr/bin/env python3
"""Generate or verify disposable views from Batch 4 canonical registries."""
import argparse
import sys
from pathlib import Path
import yaml

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "product/mint_next/batch4"


def load(name):
    return yaml.safe_load((BASE / name).read_text(encoding="utf-8"))


def render() -> dict[Path, str]:
    decisions = load("decisions.yaml")["decisions"]
    graph = load("experience_graph.yaml")
    legacy = load("legacy_reuse.yaml")["assets"]
    lines = [
        "# MINT Next — carte d'architecture (vue générée)", "",
        "> Ne pas éditer. Source: registres YAML de `product/mint_next/batch4/`.", "",
        "## Promesse", "",
        "Une question humaine à la fois, un exemple en CHF, puis une action — avec calcul, limites et sources à portée d'un geste.", "",
        "## Règles qui empêchent de reconstruire le chaos", "",
        "- La vie financière est routée par événements et données, jamais par une frise d'âge.",
        "- Sécurité et liquidité avant fiscalité, prévoyance bloquée ou investissement.",
        "- Décision, concept, état, écran et route sont des objets distincts.",
        "- Le chat n'invente ni route, ni chiffre, ni état: il utilise les mêmes actions enregistrées.",
        "- L'ancien MINT reste intact; toute réutilisation passe par une classification et un adaptateur prouvé.", "",
        f"## Couverture: {len(decisions)} décisions", "",
    ]
    lines += [f"- **{d['id']}** — {d['human_question']}" for d in decisions]
    lines += ["", "## Réutilisation legacy", ""]
    lines += [f"- `{a['id']}`: **{a['disposition']}** — {a['status']}" for a in legacy]
    lines += ["", "## Statut", "", "**DRAFT / NON PROUVÉ.** Aucun écran produit ni UX winner n'est déclaré.", ""]
    one_page = "\n".join(lines)

    mermaid = ["flowchart TD"]
    for n in graph["nodes"]:
        mermaid.append(f"  {n['id']}[\"{n['purpose']}\"]")
    for e in graph["edges"]:
        mermaid.append(f"  {e['source']} -->|{e['visible_label_intent']}| {e['destination']}")
    return {
        BASE / "ONE-PAGE.md": one_page,
        BASE / "views/experience-graph.mmd": "\n".join(mermaid) + "\n",
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    outputs = render()
    if args.check:
        drift = [path for path, expected in outputs.items() if not path.is_file() or path.read_text(encoding="utf-8") != expected]
        if drift:
            for path in drift:
                print(f"ERROR generated view drift: {path.relative_to(ROOT)}", file=sys.stderr)
            raise SystemExit(1)
        print("OK Batch 4 generated views match canonical registries.", file=sys.stderr)
    else:
        for path, content in outputs.items():
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content, encoding="utf-8")
