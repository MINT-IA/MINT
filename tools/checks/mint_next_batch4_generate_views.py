#!/usr/bin/env python3
"""Generate disposable human views from Batch 4 canonical YAML registries."""
from pathlib import Path
import yaml

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "product/mint_next/batch4"


def load(name):
    return yaml.safe_load((BASE / name).read_text(encoding="utf-8"))


def render():
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
    (BASE / "ONE-PAGE.md").write_text("\n".join(lines), encoding="utf-8")

    mermaid = ["flowchart TD"]
    for n in graph["nodes"]:
        mermaid.append(f"  {n['id']}[\"{n['purpose']}\"]")
    for e in graph["edges"]:
        mermaid.append(f"  {e['source']} -->|{e['visible_label_intent']}| {e['destination']}")
    (BASE / "views/experience-graph.mmd").write_text("\n".join(mermaid) + "\n", encoding="utf-8")


if __name__ == "__main__":
    render()
