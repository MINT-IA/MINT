#!/usr/bin/env python3
"""Génère les cartes de navigation PAR THÈME depuis le CODE ACTUEL.

Mécanique, zéro invention : les routes viennent de app.dart, les arêtes d'un grep
littéral `context.go/push('...')`, l'atteignabilité dynamique du ScreenRegistry.
Le découpage thématique vient de l'audit 2026-07-23 (clusters.json) ; toute route
non classée atterrit dans « non-classe » plutôt que d'être silencieusement omise.

Usage: python3 tools/checks/generate_theme_maps.py [--check]
  --check : ne réécrit rien, sort 1 si les cartes sont périmées (gate CI possible).
"""
import json, re, subprocess, sys
from pathlib import Path
from collections import defaultdict

ROOT = Path(__file__).resolve().parents[2]
MOBILE = ROOT / "apps/mobile"
PARTS = ROOT / ".planning/audit-etat-des-lieux-2026-07/routemap-parts"
OUT = ROOT / ".planning/architecture/themes"

def routes_from_app_dart() -> dict:
    """path -> screen class, via le parse à pile d'imbrication de app.dart."""
    src = (MOBILE / "lib/app.dart").read_text(encoding="utf-8")
    routes, stack, depth = {}, [], 0
    for line in src.split("\n"):
        pm = re.search(r"path:\s*'([^']+)'", line)
        if pm:
            p = pm.group(1)
            full = p if p.startswith("/") else "/".join(
                [stack[-1].rstrip("/")] + [p]) if stack else "/" + p
            stack.append(full)
            routes[full] = None
        bm = re.search(r"builder:\s*\(context,\s*state\)\s*=>\s*const\s+(\w+)", line)
        if bm and stack:
            routes[stack[-1]] = bm.group(1)
    return routes

def literal_edges() -> dict:
    """route cible -> [écrans sources] (grep littéral, déterministe)."""
    out = subprocess.run(
        ["grep", "-rn", "-E", r"context\.(go|push|replace)\('(/[^']*)'", "lib/screens", "lib/widgets"],
        cwd=MOBILE, capture_output=True, text=True).stdout
    edges = defaultdict(set)
    for line in out.split("\n"):
        if not line.strip():
            continue
        f = line.split(":")[0]
        for m in re.finditer(r"context\.(?:go|push|replace)\('(/[^']*)'", line):
            edges[m.group(1).split("?")[0]].add(Path(f).stem)
    return {k: sorted(v) for k, v in edges.items()}

def registry_routes() -> set:
    p = MOBILE / "lib/services/navigation/screen_registry.dart"
    if not p.exists():
        return set()
    return set(re.findall(r"'(/[^']+)'", p.read_text(encoding="utf-8")))

def main() -> int:
    routes = routes_from_app_dart()
    edges = literal_edges()
    reg = registry_routes()
    clusters = json.loads((PARTS / "clusters.json").read_text(encoding="utf-8"))

    theme_of = {r: t for t, rs in clusters.items() for r in rs}
    by_theme = defaultdict(list)
    for r in routes:
        by_theme[theme_of.get(r, "non-classe")].append(r)

    def klass(r):
        if edges.get(r):
            return "🟢 câblée"
        if r in reg:
            return "🟡 séquence"
        return "🔴 île"

    index_rows, changed = [], False
    for theme in sorted(by_theme):
        rs = sorted(by_theme[theme])
        cab = [r for r in rs if edges.get(r)]
        seq = [r for r in rs if not edges.get(r) and r in reg]
        isl = [r for r in rs if not edges.get(r) and r not in reg]
        # Verdict honnête : un thème n'est un voyage que si l'utilisateur peut
        # réellement le parcourir en cliquant. Une seule porte sur 33 écrans
        # n'est pas un voyage — c'est une porte devant un couloir fermé.
        ratio = len(cab) / len(rs) if rs else 0
        verdict = ("AUCUNE PORTE" if not cab else
                   "PARCOURABLE" if ratio >= 0.5 and not isl else
                   "PORTE UNIQUE" if len(cab) <= 2 else
                   "PARTIELLE")

        L = [
            "---",
            f'description: "Carte de navigation du thème {theme} — {len(rs)} routes : '
            f'{len(cab)} câblées (lien cliquable), {len(seq)} atteignables seulement par '
            f'séquence/registre, {len(isl)} îles. Verdict : {verdict}."',
            "---", "",
            f"# Thème « {theme} » — carte de navigation", "",
            "> Généré mécaniquement par `tools/checks/generate_theme_maps.py` "
            "depuis `app.dart`, un grep littéral des `context.go/push`, et le "
            "`ScreenRegistry`. Aucune donnée saisie à la main.", "",
            "## TLDR", "",
            f"| | Routes | Signification |", "|---|---:|---|",
            f"| 🟢 câblée | {len(cab)} | un lien cliquable y mène depuis un écran |",
            f"| 🟡 séquence | {len(seq)} | atteignable seulement via le registre / le coach |",
            f"| 🔴 île | {len(isl)} | aucun chemin détecté |",
            f"| **Total** | **{len(rs)}** | **verdict : {verdict}** "
            f"({len(cab)}/{len(rs)} = {round(ratio*100)} % cliquables) |", "",
        ]
        if isl or not cab:
            L += ["## ⚠️ Portes manquantes", "",
                  "Ces routes n'ont **aucun lien cliquable**. Un utilisateur qui explore "
                  "l'app ne peut pas les atteindre : elles dépendent d'une décision du "
                  "coach ou d'une séquence.", ""]
            for r in (isl or seq):
                L.append(f"- `{r}` — {routes.get(r) or '?'}")
            L.append("")
        L += ["## Inventaire", "",
              "| Route | Écran | Classe | Entrées (écrans qui y mènent) | Registre |",
              "|---|---|---|---|---|"]
        for r in rs:
            src = ", ".join(f"`{s}`" for s in edges.get(r, [])) or "—"
            L.append(f"| `{r}` | {routes.get(r) or '?'} | {klass(r)} | {src} | "
                     f"{'oui' if r in reg else 'non'} |")
        L.append("")
        inner = [(s, r) for r in rs for s in edges.get(r, [])]
        if inner:
            L += ["## Graphe des entrées", "", "```mermaid", "graph LR"]
            for s, r in inner[:40]:
                L.append(f'  {re.sub(r"[^A-Za-z0-9]","_",s)}["{s}"] --> {re.sub(r"[^A-Za-z0-9]","_",r)}["{r}"]')
            L += ["```", ""]

        text = "\n".join(L)
        f = OUT / f"{theme}.md"
        if not f.exists() or f.read_text(encoding="utf-8") != text:
            changed = True
            if "--check" not in sys.argv:
                f.write_text(text, encoding="utf-8")
        index_rows.append((theme, len(rs), len(cab), len(seq), len(isl), verdict))

    idx = ["---",
           'description: "Index des cartes de navigation par thème — une carte par '
           'univers de vie, générée mécaniquement depuis le code. Sert de feuille de '
           'route pour rendre chaque thème réellement parcourable."', "---", "",
           "# Architecture de navigation — cartes par thème", "",
           "> Généré par `tools/checks/generate_theme_maps.py`. "
           "Relancer après tout changement de navigation.", "",
           "| Thème | Routes | 🟢 câblées | 🟡 séquence | 🔴 îles | Verdict |",
           "|---|---:|---:|---:|---:|---|"]
    for t, n, c, s, i, v in sorted(index_rows, key=lambda x: (-x[4], -x[1])):
        idx.append(f"| [{t}](themes/{t}.md) | {n} | {c} | {s} | {i} | {v} |")
    tot = [sum(r[k] for r in index_rows) for k in (1, 2, 3, 4)]
    idx += [f"| **Total** | **{tot[0]}** | **{tot[1]}** | **{tot[2]}** | **{tot[3]}** | |", "",
            "## Comment lire", "",
            "- **🟢 câblée** : un `context.go/push` littéral y mène depuis un écran — "
            "l'utilisateur peut y arriver en cliquant.",
            "- **🟡 séquence** : la route n'existe que dans le `ScreenRegistry` — "
            "atteignable si le coach ou une séquence décide d'y aller, jamais en explorant.",
            "- **🔴 île** : aucun chemin détecté.", "",
            "Un thème n'est un **voyage** que s'il est parcourable : une porte d'entrée "
            "visible, puis des liens entre ses écrans.", ""]
    itext = "\n".join(idx)
    ifile = OUT.parent / "README.md"
    if not ifile.exists() or ifile.read_text(encoding="utf-8") != itext:
        changed = True
        if "--check" not in sys.argv:
            ifile.write_text(itext, encoding="utf-8")

    if "--check" in sys.argv:
        print("PÉRIMÉ — relancer le générateur" if changed else "OK cartes à jour")
        return 1 if changed else 0
    print(f"OK — {len(index_rows)} cartes générées dans {OUT.relative_to(ROOT)}")
    return 0

if __name__ == "__main__":
    sys.exit(main())
