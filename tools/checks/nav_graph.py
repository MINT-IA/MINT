#!/usr/bin/env python3
"""Graphe de navigation MINT — parsing STRUCTUREL et atteignabilité réelle.

Remplace l'heuristique ligne-à-ligne de `generate_theme_maps.py`, dont l'audit
Codex a montré qu'elle inventait six routes profil (concaténation abusive de la
pile d'imbrication) et en omettait six autres.

Ce que ce module corrige, point par point :

1. **Parsing structurel** — chaque `GoRoute(` / `ScopedGoRoute(` est délimité par
   équilibrage de parenthèses. Un enfant n'est un enfant que s'il est
   syntaxiquement DANS le `routes: [...]` de son parent : les frères ne
   s'empilent plus.
2. **Nature d'une route** — `redirect-only` (redirect sans builder),
   `conditionnel` (les deux) ou `écran` (builder). Le troisième cas était traité
   comme une redirection.
3. **Atteignabilité, pas arêtes entrantes** — une arête entrante ne prouve rien
   si sa source est elle-même inatteignable. On fait un PARCOURS depuis les
   vraies racines : `initialLocation` + les branches du StatefulShellRoute.
4. **`preferFromChat`** — être dans le `ScreenRegistry` ne prouve pas que le
   coach y mène ; seul ce drapeau le fait.

LIMITE ASSUMÉE (audit Codex du 2026-07-26) : les DÉCLARATIONS sont fiables
(158 routes, 110 écrans, 48 redirections, natures) ; l'ATTEIGNABILITÉ ne l'est
pas. Un modèle correct exigerait des actions de navigation typées avec leurs
préconditions (auth, feature flag, shell, `extra`) et des scénarios séparés
(visiteur / authentifié / admin). Les compteurs `atteignables` et `orphelins`
sont donc INDICATIFS : ils servent à repérer des candidats à vérifier
manuellement, jamais à affirmer qu'un écran est mort.

Usage : `python3 tools/checks/nav_graph.py [--json]`
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
from collections import defaultdict, deque
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MOBILE = ROOT / "apps/mobile"
APP = MOBILE / "lib/app.dart"


# ── 1. Parsing structurel des GoRoute ────────────────────────────────────────

def _balanced(src: str, open_at: int) -> int:
    """Index du caractère suivant la parenthèse fermante appariée à `open_at`.

    Ignore les parenthèses à l'intérieur des chaînes et des commentaires de
    ligne, sinon un `'('` dans un libellé fausse tout le découpage.
    """
    depth, i, n = 0, open_at, len(src)
    while i < n:
        c = src[i]
        if c in "'\"":
            quote, i = c, i + 1
            while i < n and src[i] != quote:
                i += 2 if src[i] == "\\" else 1
        elif c == "/" and i + 1 < n and src[i + 1] == "/":
            while i < n and src[i] != "\n":
                i += 1
        elif c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
            if depth == 0:
                return i + 1
        i += 1
    return n


def _field(block: str, name: str) -> str | None:
    """Valeur littérale d'un champ `name: '...'` au premier niveau du bloc."""
    m = re.search(rf"\b{name}:\s*'([^']*)'", block)
    return m.group(1) if m else None


def _children_span(block: str) -> tuple[int, int] | None:
    """Bornes du `routes: [ ... ]` de ce bloc, s'il en a un."""
    m = re.search(r"\broutes:\s*\[", block)
    if not m:
        return None
    i, depth = m.end() - 1, 0
    while i < len(block):
        if block[i] == "[":
            depth += 1
        elif block[i] == "]":
            depth -= 1
            if depth == 0:
                return (m.end(), i)
        i += 1
    return None


def parse_routes() -> list[dict]:
    """Toutes les routes, avec chemin complet résolu par imbrication réelle."""
    src = APP.read_text(encoding="utf-8")
    out: list[dict] = []

    def walk(segment: str, parent_path: str, offset: int) -> None:
        for m in re.finditer(r"\b(?:Scoped)?GoRoute\s*\(", segment):
            start = m.end() - 1
            end = _balanced(segment, start)
            block = segment[start:end]
            path = _field(block, "path")
            if path is None:
                continue
            full = path if path.startswith("/") else (
                parent_path.rstrip("/") + "/" + path)
            has_builder = bool(re.search(r"\b(builder|pageBuilder):", block))
            has_redirect = bool(re.search(r"\bredirect:", block))
            out.append({
                "path": full,
                "screen": (re.search(r"=>\s*(?:const\s+)?([A-Z]\w+)", block) or
                           [None, None])[1] if has_builder else None,
                "kind": ("ecran" if has_builder and not has_redirect else
                         "conditionnel" if has_builder and has_redirect else
                         "redirect" if has_redirect else "inconnu"),
                "redirect_to": _field(block, "to") or (
                    (re.search(r"return\s+'([^']+)'", block) or [None, None])[1]),
            })
            span = _children_span(block)
            if span:
                walk(block[span[0]:span[1]], full, offset + start + span[0])
            # Ne pas redescendre dans ce bloc : ses enfants sont traités ci-dessus.
            segment = segment[:start] + " " * (end - start) + segment[end:]

    walk(src, "", 0)
    # dédoublonnage en gardant la première occurrence
    seen, uniq = set(), []
    for r in out:
        if r["path"] not in seen:
            seen.add(r["path"])
            uniq.append(r)
    return uniq


# ── 2. Arêtes cliquables (les 4 mécanismes) ──────────────────────────────────

def click_edges() -> dict[str, set[str]]:
    """source(fichier/mécanisme) -> routes atteignables en cliquant."""
    edges: dict[str, set[str]] = defaultdict(set)

    out = subprocess.run(
        ["grep", "-rn", "-E", r"context\.(go|push|replace)\('(/[^']*)'",
         "lib/screens", "lib/widgets"],
        cwd=MOBILE, capture_output=True, text=True).stdout
    for line in out.splitlines():
        f = Path(line.split(":")[0]).stem
        for m in re.finditer(r"context\.(?:go|push|replace)\('(/[^']*)'", line):
            edges[f].add(m.group(1).split("?")[0])

    src = APP.read_text(encoding="utf-8")
    for m in re.finditer(r"path:\s*'(/explore/[^']*)'", src):
        tail = src[m.end():m.end() + 3000]
        stop = tail.find("path: '/explore/")
        for rm in re.finditer(r"route:\s*'(/[^']+)'", tail[:stop if stop > 0 else len(tail)]):
            edges[f"hub:{m.group(1)}"].add(rm.group(1))

    for f, name in ((MOBILE / "lib/screens/explore/explorer_screen.dart", "explorer_screen"),
                    (MOBILE / "lib/widgets/coach/chat_drawer_host.dart", "drawer:coach"),
                    (MOBILE / "lib/widgets/coach/lightning_menu.dart", "lightning:coach")):
        if f.exists():
            for m in re.finditer(r"'(/[a-z0-9/_:-]+)'", f.read_text(encoding="utf-8")):
                edges[name].add(m.group(1))
    return edges


def coach_routes() -> set[str]:
    """Routes que le coach peut ouvrir : `preferFromChat` VRAI, pas la seule
    présence au registre (l'audit Codex a montré que c'est déterminant)."""
    f = MOBILE / "lib/services/navigation/screen_registry.dart"
    if not f.exists():
        return set()
    src = f.read_text(encoding="utf-8")
    out = set()
    for m in re.finditer(r"ScreenEntry\s*\(", src):
        block = src[m.end() - 1:_balanced(src, m.end() - 1)]
        route = _field(block, "route")
        if route and "preferFromChat: false" not in block:
            out.add(route)
    return out


# ── 3. Atteignabilité par parcours, pas par arête entrante ───────────────────

def reachable(routes: list[dict], edges: dict[str, set[str]]) -> set[str]:
    """BFS depuis les vraies racines, en suivant les redirections."""
    paths = {r["path"] for r in routes}
    redirect = {r["path"]: r["redirect_to"] for r in routes
                if r["kind"] == "redirect" and r["redirect_to"]}
    screen_of = {r["path"]: r["screen"] for r in routes if r["screen"]}
    by_screen: dict[str, str] = {}
    for p, s in screen_of.items():
        by_screen.setdefault(_snake(s), p)

    roots = {"/"}
    src = APP.read_text(encoding="utf-8")
    m = re.search(r"initialLocation:\s*'([^']+)'", src)
    if m:
        roots.add(m.group(1))
    sh = re.search(r"StatefulShellRoute\.indexedStack", src)
    if sh:
        for bm in re.finditer(r"path:\s*'(/[^']*)'", src[sh.end():sh.end() + 6000]):
            roots.add(bm.group(1))

    seen, q = set(), deque(r for r in roots if r in paths)
    seen.update(q)
    while q:
        cur = q.popleft()
        if cur in redirect and redirect[cur] in paths and redirect[cur] not in seen:
            seen.add(redirect[cur]); q.append(redirect[cur])
        src_keys = {k for k in edges if k == by_screen.get(cur, "") or
                    (k.startswith(("hub:", "drawer:", "lightning:", "explorer"))) or
                    k == _snake(screen_of.get(cur, ""))}
        for k in src_keys:
            for tgt in edges[k]:
                if tgt in paths and tgt not in seen:
                    seen.add(tgt); q.append(tgt)
    return seen


def _snake(name: str | None) -> str:
    if not name:
        return ""
    return re.sub(r"(?<!^)(?=[A-Z])", "_", name).lower()


def main() -> int:
    routes = parse_routes()
    edges = click_edges()
    coach = coach_routes()
    reach = reachable(routes, edges)
    incoming: dict[str, list[str]] = defaultdict(list)
    for s, ts in edges.items():
        for t in ts:
            incoming[t].append(s)

    screens = [r for r in routes if r["kind"] in ("ecran", "conditionnel")]
    redirects = [r for r in routes if r["kind"] == "redirect"]
    clickable = [r for r in screens if incoming.get(r["path"])]
    walkable = [r for r in screens if r["path"] in reach]
    coach_only = [r for r in screens
                  if r["path"] not in reach and r["path"] in coach]
    orphan = [r for r in screens
              if r["path"] not in reach and r["path"] not in coach]

    data = {
        "routes_total": len(routes),
        "ecrans": len(screens),
        "redirects": len(redirects),
        "avec_arete_entrante": len(clickable),
        "atteignables_par_parcours": len(walkable),
        "coach_seulement": len(coach_only),
        "orphelins": sorted(r["path"] for r in orphan),
    }
    if "--json" in sys.argv:
        print(json.dumps(data, ensure_ascii=False, indent=2))
    else:
        print(f"routes déclarées        : {data['routes_total']}")
        print(f"  dont écrans réels     : {data['ecrans']}")
        print(f"  dont redirections     : {data['redirects']}")
        print(f"écrans avec une arête   : {data['avec_arete_entrante']}")
        print(f"écrans atteignables ~   : {data['atteignables_par_parcours']} "
              f"(INDICATIF — voir la limite en tête de fichier)")
        print(f"coach seulement         : {data['coach_seulement']}")
        print(f"candidats orphelins ~   : {len(data['orphelins'])} (à VÉRIFIER un par un)")
        for p in data["orphelins"][:20]:
            print(f"   - {p}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
